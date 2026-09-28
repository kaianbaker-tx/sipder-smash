extends CanvasLayer
## Title screen: logo, PLAY, suit picker and how-to-play.

signal play_pressed
signal suit_preview(suit: String)

const LOGO := preload("res://assets/ui/logo.png")

var _main_box: VBoxContainer
var _suits: Control
var _help: Control
var _suit_name: Label
var _suit_desc: Label
var _wear: Button
var _suit_keys: Array = []
var _suit_i := 0
var _play: Button


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.position = Vector2(30, 14)
	logo.size = Vector2(560, 380)
	logo.rotation = -0.04
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo)
	logo.pivot_offset = Vector2(280, 190)
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "scale", Vector2(1.03, 1.03), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)

	var by := UiKit.label("A GAME BY KAIAN", 34, Color(1, 1, 1), UiKit.LUCKY, 10)
	by.position = Vector2(70, 398)
	by.rotation = -0.04
	by.add_theme_color_override("font_shadow_color", Color(1, 0.2, 0.6))
	by.add_theme_constant_override("shadow_offset_x", 4)
	by.add_theme_constant_override("shadow_offset_y", 4)
	root.add_child(by)

	_main_box = VBoxContainer.new()
	_main_box.position = Vector2(70, 452)
	_main_box.add_theme_constant_override("separation", 16)
	root.add_child(_main_box)
	_play = UiKit.button("PLAY!", 64)
	_play.custom_minimum_size = Vector2(300, 0)
	_play.pressed.connect(func() -> void: play_pressed.emit())
	_main_box.add_child(_play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_main_box.add_child(row)
	var sb := UiKit.button("SUITS", 36, Color(0.3, 0.9, 1.0))
	sb.pressed.connect(_toggle_suits)
	row.add_child(sb)
	var hb := UiKit.button("HOW TO PLAY", 36, Color(0.3, 0.9, 1.0))
	hb.pressed.connect(func() -> void: _help.visible = not _help.visible; _suits.visible = false)
	row.add_child(hb)

	var credit := UiKit.label("3D art: Kenney.nl (CC0)   Fonts: Bangers & Luckiest Guy (OFL)   Made with Godot", 16, Color(1, 1, 1, 0.85), UiKit.LUCKY, 5)
	credit.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	credit.position = Vector2(20, -34)
	root.add_child(credit)
	var hint := UiKit.label("PRESS ENTER TO PLAY", 26, Color(1, 0.95, 0.3), UiKit.BANGERS, 8)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.position = Vector2(-280, -50)
	root.add_child(hint)
	if Game.touch_mode:
		hint.text = "TAP PLAY!"
	var tw2 := hint.create_tween().set_loops()
	tw2.tween_property(hint, "modulate:a", 0.3, 0.6)
	tw2.tween_property(hint, "modulate:a", 1.0, 0.6)

	_build_suits(root)
	_build_help(root)
	_play.grab_focus.call_deferred()


func _build_suits(root: Control) -> void:
	_suits = UiKit.panel(Color(1, 0.95, 0.8))
	_suits.position = Vector2(410, 385)
	_suits.custom_minimum_size = Vector2(400, 0)
	_suits.visible = false
	root.add_child(_suits)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_suits.add_child(v)
	v.add_child(UiKit.label("PICK YOUR SUIT", 34, Color(1, 0.3, 0.55)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var prev := UiKit.button("<", 40, Color(0.3, 0.9, 1.0))
	prev.pressed.connect(func() -> void: _cycle(-1))
	row.add_child(prev)
	_suit_name = UiKit.label("", 48, Color(1, 0.9, 0.2))
	_suit_name.custom_minimum_size = Vector2(220, 0)
	_suit_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_suit_name)
	var nxt := UiKit.button(">", 40, Color(0.3, 0.9, 1.0))
	nxt.pressed.connect(func() -> void: _cycle(1))
	row.add_child(nxt)
	_suit_desc = UiKit.label("", 22, Color(0.1, 0.02, 0.15), UiKit.LUCKY, 0)
	_suit_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_suit_desc.custom_minimum_size = Vector2(360, 60)
	_suit_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_suit_desc)
	_wear = UiKit.button("WEAR IT!", 38)
	_wear.pressed.connect(_wear_it)
	v.add_child(_wear)
	_suit_keys = Game.SUITS.keys()
	_suit_i = maxi(0, _suit_keys.find(Game.suit))
	_show_suit()


func _build_help(root: Control) -> void:
	_help = UiKit.panel(Color(1, 0.95, 0.8))
	_help.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_help.position = Vector2(-640, -300)
	_help.custom_minimum_size = Vector2(600, 0)
	_help.visible = false
	root.add_child(_help)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_help.add_child(v)
	v.add_child(UiKit.label("HOW TO PLAY", 40, Color(1, 0.3, 0.55)))
	var lines := [
		["MOVE", "W A S D  /  left stick"],
		["LOOK", "mouse  /  right stick"],
		["JUMP", "SPACE (again in the air = FLIP!)"],
		["SWING", "hold RIGHT MOUSE or SHIFT in the air"],
		["SMASH", "LEFT CLICK / J  (auto-aims at bots!)"],
		["WEB SHOT", "F / K  (sticks bots in place)"],
		["WEB ZIP", "E / L  (zip where you aim)"],
		["CLIMB", "run into any wall"],
		["SLAM", "SMASH while falling from high up!"],
		["COVER", "C = freeze it as a comic cover"],
		["PAUSE", "ESC / P"],
	]
	for l in lines:
		var h := HBoxContainer.new()
		var a := UiKit.label(l[0], 28, Color(0.1, 0.6, 1.0), UiKit.BANGERS, 0)
		a.custom_minimum_size = Vector2(150, 0)
		h.add_child(a)
		h.add_child(UiKit.label(l[1], 22, Color(0.1, 0.02, 0.15), UiKit.LUCKY, 0))
		v.add_child(h)
	v.add_child(UiKit.label("Smash the Glitch-Bots, jump through the portals\nto other dimensions, and beat THE GLITCH KING\nin the Glitch-Verse to save the city!", 20, Color(1, 0.3, 0.55), UiKit.LUCKY, 0))


func _toggle_suits() -> void:
	_suits.visible = not _suits.visible
	_help.visible = false


func _cycle(d: int) -> void:
	_suit_i = posmod(_suit_i + d, _suit_keys.size())
	_show_suit()


func _show_suit() -> void:
	var key: String = _suit_keys[_suit_i]
	var s: Dictionary = Game.SUITS[key]
	_suit_name.text = s.name
	var locked := key == "gold" and not Game.gold_unlocked
	_suit_desc.text = ("LOCKED! " if locked else "") + s.desc
	_wear.disabled = locked
	_wear.text = "WORN!" if key == Game.suit else "WEAR IT!"
	if not locked:
		suit_preview.emit(key)


func _wear_it() -> void:
	Game.set_suit(_suit_keys[_suit_i])
	_show_suit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			play_pressed.emit()
			get_viewport().set_input_as_handled()
