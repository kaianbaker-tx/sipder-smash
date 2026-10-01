class_name Dialog
extends CanvasLayer
## The talking box at the bottom of the screen.
##   await dialog.say("Hello!", "PROF. BIRCH")
##   var pick: int = await dialog.ask("Choose it?", ["YES", "NO"])
## Press E / Space / Enter / A, click or tap to go on.

signal _picked(i: int)

var auto := false               # autoplay: go on by itself
var auto_picks: Array = []      # autoplay: answers for ask()
var box: PanelContainer
var text: Label
var name_tag: PanelContainer
var name_label: Label
var arrow: Label
var choices: VBoxContainer
var is_open := false
var _typing := false
var _shown := 0.0
var _open_t := 0.0
var _clicked := false
var _asking := false
var _go := false
var _hide_pending := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	box = UI.panel()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -560
	box.offset_right = 560
	box.offset_top = -190
	box.offset_bottom = -24
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(box)
	text = UI.label("", 34)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text.custom_minimum_size = Vector2(1000, 120)
	box.add_child(text)
	arrow = UI.outlined("v", 34, UI.RED, UI.PAPER)
	root.add_child(arrow)
	name_tag = UI.panel(UI.GOLD)
	name_tag.anchor_left = 0.5
	name_tag.anchor_right = 0.5
	name_tag.anchor_top = 1.0
	name_tag.anchor_bottom = 1.0
	name_tag.offset_left = -540
	name_tag.offset_top = -236
	name_tag.offset_bottom = -180
	root.add_child(name_tag)
	name_label = UI.label("", 28)
	name_tag.add_child(name_label)
	choices = VBoxContainer.new()
	choices.anchor_left = 1.0
	choices.anchor_right = 1.0
	choices.anchor_top = 1.0
	choices.anchor_bottom = 1.0
	choices.offset_left = -380
	choices.offset_right = -60
	choices.offset_bottom = -210
	choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	choices.add_theme_constant_override("separation", 10)
	root.add_child(choices)
	box.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_clicked = true)
	hide_now()


## Hide the box next frame, unless something else is said right away
## (so battle messages don't flicker).
func _close() -> void:
	is_open = false
	choices.visible = false
	_hide_pending = true


func hide_now() -> void:
	is_open = false
	box.visible = false
	name_tag.visible = false
	choices.visible = false
	arrow.visible = false


## Say something and wait for the player to read it. With wait > 0 it
## also goes on by itself after that many seconds (battle messages).
func say(t: String, who := "", wait := 0.0) -> void:
	await _show(t, who)
	if auto:
		wait = 0.25
	var left := wait
	_go = false
	while not _go and (wait <= 0.0 or left > 0.0):
		await get_tree().process_frame
		left -= get_process_delta_time()
	if _go:
		Sfx.play("blip", 0.0, -6.0)
	_close()


## Ask a question with buttons. Returns the index picked.
func ask(t: String, options: Array, who := "") -> int:
	await _show(t, who)
	for c in choices.get_children():
		c.queue_free()
	var btns: Array[Button] = []
	for i in options.size():
		var b := UI.button(options[i], 32)
		b.custom_minimum_size = Vector2(300, 64)
		b.pressed.connect(func() -> void: _picked.emit(i))
		choices.add_child(b)
		btns.append(b)
	choices.visible = true
	arrow.visible = false
	_asking = true
	btns[0].grab_focus.call_deferred()
	var pick := 0
	if auto:
		await get_tree().create_timer(0.25).timeout
		pick = auto_picks.pop_front() if not auto_picks.is_empty() else 0
	else:
		pick = await _picked
	_asking = false
	Sfx.play("select")
	for c in choices.get_children():
		c.queue_free()
	_close()
	return pick


func _show(t: String, who: String) -> void:
	is_open = true
	box.visible = true
	name_tag.visible = who != ""
	name_label.text = who
	text.text = t
	text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_open_t = 0.0
	_clicked = false
	arrow.visible = false
	while _typing:
		await get_tree().process_frame


func _input(event: InputEvent) -> void:
	if not is_open or _asking:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		_clicked = true


func _process(delta: float) -> void:
	if _hide_pending and not is_open:
		hide_now()
	_hide_pending = false
	if not is_open:
		return
	_open_t += delta
	var go := _open_t > 0.15 and (Input.is_action_just_pressed("interact") or _clicked)
	_clicked = false
	if _typing:
		_shown += delta * 55.0
		text.visible_characters = int(_shown)
		if go or auto or text.visible_characters >= text.get_total_character_count():
			text.visible_characters = -1
			_typing = false
		return
	if _asking:
		return
	arrow.visible = true
	arrow.position = box.position + box.size - Vector2(58, 62 - sin(_open_t * 8.0) * 5.0)
	if go:
		_go = true
