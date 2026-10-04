class_name TouchControls
extends CanvasLayer
## Phone and tablet controls: a joystick on the left, A / RUN / MENU buttons
## on the right, and drag anywhere else on the right to turn the camera.
## Shows up by itself the first time the screen is touched.

var main: Node
var _draw: Control
var _stick_id := -1
var _stick_center := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _buttons := {}
var _run_on := false


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
	var s := clampf(vp.y / 720.0, 0.8, 1.6)
	_buttons = {
		"interact": {"pos": Vector2(vp.x - 120 * s, vp.y - 130 * s), "r": 70 * s, "label": "A"},
		"run": {"pos": Vector2(vp.x - 280 * s, vp.y - 90 * s), "r": 50 * s, "label": "RUN"},
		"menu": {"pos": Vector2(vp.x - 70 * s, 190 * s), "r": 42 * s, "label": "MENU"},
	}
	_stick_center = Vector2(170 * s, vp.y - 170 * s)


func _active() -> bool:
	return main and not main.busy and main.player.visible


## Battles, Connect Four and the title have their own big buttons.
func _hidden() -> bool:
	return main == null or main.battle.visible or main.c4.visible or main.title.visible or main.menu.is_open or not main.player.visible


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not Game.touch_mode:
			Game.touch_mode = true
		visible = true
	if not visible or _hidden():
		return
	_layout()
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			for a in _buttons:
				var b: Dictionary = _buttons[a]
				if e.position.distance_to(b.pos) < (b.r as float) * 1.2:
					if a == "run":
						_run_on = not _run_on
						main.player.touch_run = _run_on
					elif a == "menu":
						if _active():
							main.menu.open()
					else:
						Input.action_press("interact")
						get_tree().create_timer(0.1).timeout.connect(func() -> void: Input.action_release("interact"))
					_draw.queue_redraw()
					return
			if not _active():
				return
			if e.position.x < _draw.size.x * 0.45 and _stick_id < 0:
				_stick_id = e.index
				_stick_center = e.position
				_stick_vec = Vector2.ZERO
			elif _look_id < 0:
				_look_id = e.index
				_look_last = e.position
		else:
			if e.index == _stick_id:
				_stick_id = -1
				_stick_vec = Vector2.ZERO
				main.player.touch_move = Vector2.ZERO
			if e.index == _look_id:
				_look_id = -1
		_draw.queue_redraw()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _stick_id:
			var d := e.position - _stick_center
			var r := 90.0 * clampf(_draw.size.y / 720.0, 0.8, 1.6)
			_stick_vec = d.limit_length(r) / r
			main.player.touch_move = _stick_vec
			_draw.queue_redraw()
		elif e.index == _look_id:
			main.rig.turn((e.position - _look_last) * 0.008)
			_look_last = e.position


func _process(_delta: float) -> void:
	if visible and main and main.busy and _stick_id >= 0:
		_stick_id = -1
		main.player.touch_move = Vector2.ZERO
	_draw.visible = visible and not _hidden()


func _on_draw() -> void:
	_layout()
	var s := clampf(_draw.size.y / 720.0, 0.8, 1.6)
	var font := UI.FONT
	if main and not main.busy:
		var c := _stick_center if _stick_id >= 0 else Vector2(170 * s, _draw.size.y - 170 * s)
		_draw.draw_circle(c, 90 * s, Color(1, 1, 1, 0.18))
		_draw.draw_arc(c, 90 * s, 0, TAU, 40, Color(1, 1, 1, 0.5), 4)
		_draw.draw_circle(c + _stick_vec * 90 * s, 40 * s, Color(1, 1, 1, 0.6))
	for a in _buttons:
		var b: Dictionary = _buttons[a]
		var col := Color(1, 1, 1, 0.35)
		if a == "interact":
			col = Color(0.95, 0.3, 0.3, 0.75)
		elif a == "run" and _run_on:
			col = Color(1.0, 0.8, 0.2, 0.8)
		_draw.draw_circle(b.pos, b.r, col)
		_draw.draw_arc(b.pos, b.r, 0, TAU, 40, Color(1, 1, 1, 0.8), 4)
		var fs := int(24 * s) if a != "interact" else int(48 * s)
		var tw := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		_draw.draw_string(font, b.pos + Vector2(-tw.x * 0.5, fs * 0.35), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
