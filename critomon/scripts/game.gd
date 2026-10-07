extends Node
## Global game state: controls, your party, bag, story flags, saving and
## test hooks.

signal party_changed
signal bag_changed

const SAVE_PATH := "user://critomon.save"
const MAX_PARTY := 6

var player_name := "YOU"
var party: Array = []
var box: Array = []                 # extra Crittermon when the party is full
var bag := {"ball": 0, "potion": 0}
var flags := {}                     # story progress, beaten trainers
var seen := {}                      # Critter Dex: species seen / caught
var caught := {}
var spawn := {"area": "town", "pos": Vector3(-16, 0, 11.5), "yaw": 0.0}
var touch_mode := false
var mouse_sens := 0.006
var args := {}                      # command line test hooks: -- --autoplay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_setup_input()
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		touch_mode = true


func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _pad_button(action: String, btn: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = btn
	InputMap.action_add_event(action, e)


func _pad_axis(action: String, axis: JoyAxis, dir: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = dir
	InputMap.action_add_event(action, e)


func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("run", [KEY_SHIFT])
	_key("interact", [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	_key("back", [KEY_BACKSPACE, KEY_X])
	_key("menu", [KEY_ESCAPE, KEY_TAB, KEY_M])
	_key("cam_left", [KEY_Q])
	_key("cam_right", [KEY_R])
	_key("cam_up", [])
	_key("cam_down", [])
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_pad_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_pad_axis("cam_left", JOY_AXIS_RIGHT_X, -1.0)
	_pad_axis("cam_right", JOY_AXIS_RIGHT_X, 1.0)
	_pad_axis("cam_up", JOY_AXIS_RIGHT_Y, -1.0)
	_pad_axis("cam_down", JOY_AXIS_RIGHT_Y, 1.0)
	_pad_button("move_forward", JOY_BUTTON_DPAD_UP)
	_pad_button("move_back", JOY_BUTTON_DPAD_DOWN)
	_pad_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_pad_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_pad_button("interact", JOY_BUTTON_A)
	_pad_button("back", JOY_BUTTON_B)
	_pad_button("run", JOY_BUTTON_X)
	_pad_button("run", JOY_BUTTON_RIGHT_SHOULDER)
	_pad_button("menu", JOY_BUTTON_START)
	_pad_button("menu", JOY_BUTTON_Y)
	# menus: E picks, W / S move between buttons
	_key("ui_accept", [KEY_E])
	_key("ui_up", [KEY_W])
	_key("ui_down", [KEY_S])
	_key("ui_left", [KEY_A])
	_key("ui_right", [KEY_D])
	_key("ui_cancel", [KEY_BACKSPACE, KEY_X])


# ------------------------------------------------------------------ party

func add_mon(mon: Dictionary) -> String:
	seen[mon.sp] = true
	caught[mon.sp] = true
	if party.size() < MAX_PARTY:
		party.append(mon)
		party_changed.emit()
		return "party"
	box.append(mon)
	return "box"


func lead() -> Dictionary:
	for m in party:
		if m.hp > 0:
			return m
	return {} if party.is_empty() else party[0]


func can_battle() -> bool:
	for m in party:
		if m.hp > 0:
			return true
	return false


func heal_all() -> void:
	for m in party:
		m.hp = Dex.max_hp(m)
	party_changed.emit()


func give(item: String, n := 1) -> void:
	bag[item] = bag.get(item, 0) + n
	bag_changed.emit()


func use_item(item: String) -> bool:
	if bag.get(item, 0) <= 0:
		return false
	bag[item] -= 1
	bag_changed.emit()
	return true


func flag(f: String) -> bool:
	return flags.has(f) and not (flags[f] is bool and flags[f] == false)


func set_flag(f: String, v: Variant = true) -> void:
	flags[f] = v


# ------------------------------------------------------------------ saving

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save() -> void:
	if args.has("autoplay") and not args.has("save"):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_var({
		"v": 2, "name": player_name, "party": party, "box": box, "bag": bag,
		"flags": flags, "seen": seen, "caught": caught, "spawn": spawn,
	})


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = f.get_var()
	if not (d is Dictionary) or not d.has("party"):
		return false
	player_name = d.get("name", "YOU")
	party = d.party
	box = d.get("box", [])
	bag = d.get("bag", bag)
	flags = d.get("flags", {})
	seen = d.get("seen", {})
	caught = d.get("caught", {})
	spawn = d.get("spawn", spawn)
	# saves from before version 2 got the lab gifts with the Jax flag
	if d.get("v", 1) < 2 and flags.has("rival_c4"):
		flags["got_items"] = true
	party_changed.emit()
	return true


func new_game() -> void:
	player_name = "YOU"
	party = []
	box = []
	bag = {"ball": 0, "potion": 0}
	flags = {}
	seen = {}
	caught = {}
	spawn = {"area": "town", "pos": Vector3(-16, 0, 11.5), "yaw": 0.0}
	party_changed.emit()
