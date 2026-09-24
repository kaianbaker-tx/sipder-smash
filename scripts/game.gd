extends Node
## Global game state: controls, score, suits, settings and test hooks.

signal score_changed(score: int)
signal combo_changed(combo: int)
signal tokens_changed(tokens: int)
signal suit_changed(suit: String)
signal message(text: String, seconds: float)

const SUITS := {
	"classic": {"name": "CLASSIC", "tex": "res://assets/hero/suits/classic.png", "desc": "The one and only! Extra health."},
	"midnight": {"name": "MIDNIGHT", "tex": "res://assets/hero/suits/midnight.png", "desc": "Stealthy: bots spot you later!"},
	"ghost": {"name": "GHOST", "tex": "res://assets/hero/suits/ghost.png", "desc": "Hood up. Swings super fast!"},
	"noir": {"name": "NOIR", "tex": "res://assets/hero/suits/noir.png", "desc": "Black & white world. Hits harder!"},
	"gold": {"name": "GOLDEN", "tex": "res://assets/hero/suits/gold.png", "desc": "DOUBLE POINTS! Collect 25 tokens to unlock."},
}
const GOLD_TOKENS := 25

var score := 0
var combo := 0
var best_combo := 0
var tokens := 0
var token_total := 0
var bots_smashed := 0
var suit := "classic"
var gold_unlocked := false
var mouse_sens := 0.0025
var invert_y := false
var touch_mode := false
var playing := false

# command line test hooks: -- --autoplay --shot=path --frames=N
var args := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_setup_input()
	_load()
	# phones and tablets start in touch mode; laptops switch on first touch
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		enable_touch()


## Phones and tablets: taps must not count as mouse punches.
func enable_touch() -> void:
	touch_mode = true
	for a in ["smash", "swing"]:
		for e in InputMap.action_get_events(a):
			if e is InputEventMouseButton:
				InputMap.action_erase_event(a, e)


func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
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


func _mouse(action: String, btn: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	InputMap.action_add_event(action, e)


func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("jump", [KEY_SPACE])
	_key("swing", [KEY_SHIFT])
	_key("smash", [KEY_J])
	_key("web", [KEY_F, KEY_K])
	_key("zip", [KEY_E, KEY_L])
	_key("pause", [KEY_ESCAPE, KEY_P])
	_key("ui_help", [KEY_H])
	_key("cover", [KEY_C])
	_key("cam_left", [])
	_key("cam_right", [])
	_key("cam_up", [])
	_key("cam_down", [])
	_mouse("smash", MOUSE_BUTTON_LEFT)
	_mouse("swing", MOUSE_BUTTON_RIGHT)
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_pad_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_pad_axis("cam_left", JOY_AXIS_RIGHT_X, -1.0)
	_pad_axis("cam_right", JOY_AXIS_RIGHT_X, 1.0)
	_pad_axis("cam_up", JOY_AXIS_RIGHT_Y, -1.0)
	_pad_axis("cam_down", JOY_AXIS_RIGHT_Y, 1.0)
	_pad_axis("swing", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_pad_button("jump", JOY_BUTTON_A)
	_pad_button("smash", JOY_BUTTON_X)
	_pad_button("web", JOY_BUTTON_Y)
	_pad_button("zip", JOY_BUTTON_B)
	_pad_button("zip", JOY_BUTTON_LEFT_SHOULDER)
	_pad_button("swing", JOY_BUTTON_RIGHT_SHOULDER)
	_pad_button("pause", JOY_BUTTON_START)
	_pad_button("cover", JOY_BUTTON_BACK)


func reset_run() -> void:
	score = 0
	combo = 0
	best_combo = 0
	tokens = 0
	bots_smashed = 0
	score_changed.emit(score)
	tokens_changed.emit(tokens)


func add_score(points: int) -> void:
	score += points * maxi(1, 1 + combo / 5) * (2 if suit == "gold" else 1)
	score_changed.emit(score)


func add_combo() -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	combo_changed.emit(combo)


func end_combo() -> void:
	if combo != 0:
		combo = 0
		combo_changed.emit(combo)


func add_token() -> void:
	tokens += 1
	tokens_changed.emit(tokens)
	add_score(50)
	if tokens >= GOLD_TOKENS and not gold_unlocked:
		gold_unlocked = true
		_save()
		message.emit("GOLDEN SUIT UNLOCKED!", 3.0)


func set_suit(s: String) -> void:
	suit = s
	suit_changed.emit(s)
	_save()


func suit_texture() -> Texture2D:
	return load(SUITS[suit].tex)


func say(text: String, seconds := 2.5) -> void:
	message.emit(text, seconds)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://spider_smash.cfg")  # keep other sections (race record)
	cfg.set_value("game", "suit", suit)
	cfg.set_value("game", "gold", gold_unlocked)
	cfg.set_value("game", "invert_y", invert_y)
	cfg.set_value("game", "mouse_sens", mouse_sens)
	cfg.save("user://spider_smash.cfg")


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://spider_smash.cfg") == OK:
		suit = cfg.get_value("game", "suit", "classic")
		gold_unlocked = cfg.get_value("game", "gold", false)
		invert_y = cfg.get_value("game", "invert_y", false)
		mouse_sens = cfg.get_value("game", "mouse_sens", 0.0025)
	if suit == "gold" and not gold_unlocked:
		suit = "classic"
