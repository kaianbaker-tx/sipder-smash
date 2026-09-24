extends CanvasLayer
## Pause menu and the "CITY SAVED!" win screen.

signal resume
signal quit_to_title
signal keep_playing

var _pause: Control
var _win: Control
var _win_stats: Label
var _music_btn: Button
var _suit_btn: Button
var _invert_btn: Button


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pause()
	_build_win()


func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	_pause.add_child(UiKit.dim())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-200, -260)
	v.custom_minimum_size = Vector2(400, 0)
	v.add_theme_constant_override("separation", 14)
	_pause.add_child(v)
	var t := UiKit.label("PAUSED", 90, Color(1, 0.9, 0.2), UiKit.BANGERS, 16)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color(1, 0.2, 0.6))
	t.add_theme_constant_override("shadow_offset_x", 6)
	t.add_theme_constant_override("shadow_offset_y", 6)
	v.add_child(t)
	var r := UiKit.button("KEEP SMASHING!", 44)
	r.pressed.connect(func() -> void: resume.emit())
	v.add_child(r)
	_suit_btn = UiKit.button("", 32, Color(0.3, 0.9, 1.0))
	_suit_btn.pressed.connect(_next_suit)
	v.add_child(_suit_btn)
	_music_btn = UiKit.button("", 32, Color(0.3, 0.9, 1.0))
	_music_btn.pressed.connect(func() -> void: Sfx.set_muted(not Sfx.muted); _refresh())
	v.add_child(_music_btn)
	_invert_btn = UiKit.button("", 32, Color(0.3, 0.9, 1.0))
	_invert_btn.pressed.connect(func() -> void: Game.invert_y = not Game.invert_y; Game._save(); _refresh())
	v.add_child(_invert_btn)
	var q := UiKit.button("MAIN MENU", 32, Color(1, 0.6, 0.7))
	q.pressed.connect(func() -> void: quit_to_title.emit())
	v.add_child(q)
	_refresh()


func _build_win() -> void:
	_win = Control.new()
	_win.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win.visible = false
	add_child(_win)
	_win.add_child(UiKit.dim())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-420, -300)
	v.custom_minimum_size = Vector2(840, 0)
	v.add_theme_constant_override("separation", 12)
	_win.add_child(v)
	var t := UiKit.label("THE CITY IS SAVED!", 96, Color(1, 0.9, 0.2), UiKit.BANGERS, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color(0.1, 0.9, 1))
	t.add_theme_constant_override("shadow_offset_x", 7)
	t.add_theme_constant_override("shadow_offset_y", 7)
	v.add_child(t)
	var p := UiKit.panel(Color(1, 0.95, 0.8))
	v.add_child(p)
	_win_stats = UiKit.label("", 34, Color(0.1, 0.02, 0.15), UiKit.LUCKY, 0)
	_win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(_win_stats)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	v.add_child(row)
	var k := UiKit.button("KEEP SWINGING!", 44)
	k.pressed.connect(func() -> void: _win.visible = false; keep_playing.emit())
	row.add_child(k)
	var m := UiKit.button("MAIN MENU", 44, Color(0.3, 0.9, 1.0))
	m.pressed.connect(func() -> void: _win.visible = false; quit_to_title.emit())
	row.add_child(m)


func _refresh() -> void:
	_music_btn.text = "SOUND: " + ("OFF" if Sfx.muted else "ON")
	_invert_btn.text = "INVERT LOOK: " + ("ON" if Game.invert_y else "OFF")
	var s: Dictionary = Game.SUITS[Game.suit]
	_suit_btn.text = "SUIT: " + s.name


func _next_suit() -> void:
	var keys: Array = Game.SUITS.keys()
	var i := keys.find(Game.suit)
	for n in keys.size():
		i = (i + 1) % keys.size()
		if keys[i] != "gold" or Game.gold_unlocked:
			break
	Game.set_suit(keys[i])
	_refresh()


func show_pause(on: bool) -> void:
	_pause.visible = on
	if on:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _pause.visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		resume.emit()


func is_paused_open() -> bool:
	return _pause.visible


func show_win(time_s: float) -> void:
	var m := int(time_s) / 60
	var s := int(time_s) % 60
	_win_stats.text = "SCORE: %d\nBOTS SMASHED: %d\nBEST COMBO: x%d\nSPIDER TOKENS: %d\nTIME: %d:%02d" % [Game.score, Game.bots_smashed, Game.best_combo, Game.tokens, m, s]
	_win.visible = true
