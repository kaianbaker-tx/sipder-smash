extends CanvasLayer
## On-screen controls for tablets and phones: a joystick on the left,
## action buttons on the right, drag anywhere else on the right to look.

var rig: CamRig
var _stick_id := -1
var _stick_center := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _buttons := {}           # action -> {pos, r, label, id}
var _draw: Control
var pause_pressed: Callable
var cover_pressed: Callable


func _ready() -> void:
	layer = 15
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)
	visible = Game.touch_mode


func _layout() -> void:
	var vp := _draw.size
	var s := clampf(vp.y / 720.0, 0.7, 1.6)
	var base := Vector2(vp.x - 120 * s, vp.y - 120 * s)
	_buttons = {
		"jump": {"pos": base, "r": 62 * s, "label": "JUMP"},
		"swing": {"pos": base + Vector2(-150, -40) * s, "r": 58 * s, "label": "SWING"},
		"smash": {"pos": base + Vector2(-20, -160) * s, "r": 56 * s, "label": "SMASH"},
		"web": {"pos": base + Vector2(-160, -175) * s, "r": 44 * s, "label": "WEB"},
		"zip": {"pos": base + Vector2(-270, -80) * s, "r": 42 * s, "label": "ZIP"},
		"pause": {"pos": Vector2(vp.x * 0.5 - 40 * s, 44 * s), "r": 30 * s, "label": "II"},
		"cover": {"pos": Vector2(vp.x * 0.5 + 40 * s, 44 * s), "r": 30 * s, "label": "PIC"},
	}
	_stick_center = Vector2(150 * s, vp.y - 150 * s)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not Game.touch_mode:
			Game.enable_touch()
		visible = true
	if not visible or not Game.playing:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_layout()
			for a in _buttons:
				var b: Dictionary = _buttons[a]
				if e.position.distance_to(b.pos) < (b.r as float) * 1.15:
					b["id"] = e.index
					if a == "pause":
						if pause_pressed.is_valid():
							pause_pressed.call()
					elif a == "cover":
						if cover_pressed.is_valid():
							cover_pressed.call()
					else:
						Input.action_press(a)
					get_viewport().set_input_as_handled()
					return
			if e.position.x < _draw.size.x * 0.45 and _stick_id == -1:
				_stick_id = e.index
				_stick_center = e.position
				_stick_vec = Vector2.ZERO
			elif _look_id == -1:
				_look_id = e.index
				_look_last = e.position
		else:
			for a in _buttons:
				var b: Dictionary = _buttons[a]
				if b.get("id", -2) == e.index:
					b["id"] = -2
					if a != "pause" and a != "cover":
						Input.action_release(a)
			if e.index == _stick_id:
				_stick_id = -1
				_stick_vec = Vector2.ZERO
				_apply_stick()
				_layout()
			if e.index == _look_id:
				_look_id = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_id:
			var v := (d.position - _stick_center) / (70.0 * clampf(_draw.size.y / 720.0, 0.7, 1.6))
			_stick_vec = v.limit_length(1.0)
			_apply_stick()
		elif d.index == _look_id and rig:
			rig.add_look((d.position - _look_last) * 0.006)
			_look_last = d.position


func _apply_stick() -> void:
	var v := _stick_vec
	_set_axis("move_right", maxf(v.x, 0.0))
	_set_axis("move_left", maxf(-v.x, 0.0))
	_set_axis("move_back", maxf(v.y, 0.0))
	_set_axis("move_forward", maxf(-v.y, 0.0))


func _set_axis(a: String, s: float) -> void:
	if s > 0.05:
		Input.action_press(a, s)
	else:
		Input.action_release(a)


func _process(_delta: float) -> void:
	if visible:
		_draw.queue_redraw()


func _on_draw() -> void:
	if not Game.playing:
		return
	if _buttons.is_empty():
		_layout()
	var ink := Color(0.05, 0, 0.08, 0.8)
	# joystick
	var sr := 70.0 * clampf(_draw.size.y / 720.0, 0.7, 1.6)
	_draw.draw_circle(_stick_center, sr, Color(1, 1, 1, 0.18))
	_draw.draw_arc(_stick_center, sr, 0, TAU, 40, ink, 4.0)
	_draw.draw_circle(_stick_center + _stick_vec * sr, sr * 0.45, Color(1, 0.25, 0.55, 0.75))
	_draw.draw_arc(_stick_center + _stick_vec * sr, sr * 0.45, 0, TAU, 24, ink, 4.0)
	var font := UiKit.BANGERS
	for a in _buttons:
		var b: Dictionary = _buttons[a]
		var held: bool = b.get("id", -2) != -2
		var col := Color(1, 0.9, 0.2, 0.8) if not held else Color(0.2, 0.9, 1.0, 0.95)
		if a == "swing":
			col = Color(1, 0.3, 0.55, 0.8) if not held else Color(0.2, 0.9, 1.0, 0.95)
		_draw.draw_circle(b.pos, b.r, col)
		_draw.draw_arc(b.pos, b.r, 0, TAU, 32, ink, 5.0)
		var fs := int((b.r as float) * 0.5)
		var tsz := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		_draw.draw_string(font, (b.pos as Vector2) + Vector2(-tsz.x * 0.5, fs * 0.35), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0, 0.08))
