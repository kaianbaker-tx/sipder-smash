class_name TitleScreen
extends CanvasLayer
## The title: the camera circles Birchwood Town while the three starter
## Crittermon bounce by the fountain. NEW GAME or CONTINUE.

var main: Node
var root: Control
var starters: Array[CritterModel] = []
var _t := 0.0
var _on := false


func _ready() -> void:
	layer = 30
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.anchor_left = 0.5
	logo.anchor_right = 0.5
	logo.offset_left = -430
	logo.offset_right = 430
	logo.offset_top = 16
	logo.offset_bottom = 300
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo)
	var by := UI.outlined("A GAME BY KAIAN", 30, UI.GOLD)
	by.anchor_left = 0.5
	by.anchor_right = 0.5
	by.offset_left = -300
	by.offset_right = 300
	by.offset_top = 292
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(by)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -200
	box.offset_right = 200
	box.offset_top = -50
	box.offset_bottom = -50
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.add_theme_constant_override("separation", 16)
	root.add_child(box)
	var new_btn := UI.button("NEW GAME", 40, UI.RED, Color.WHITE)
	new_btn.custom_minimum_size = Vector2(400, 84)
	new_btn.pressed.connect(_start.bind(true))
	var cont := UI.button("CONTINUE", 40, UI.BLUE, Color.WHITE)
	cont.custom_minimum_size = Vector2(400, 84)
	cont.pressed.connect(_start.bind(false))
	if Game.has_save():
		box.add_child(cont)
	box.add_child(new_btn)
	(box.get_child(0) as Button).grab_focus.call_deferred()
	var credit := UI.outlined("3D art: Kenney.nl (CC0)   Font: Lilita One (OFL)   Made with Godot and Claude", 16, Color(1, 1, 1, 0.9))
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_left = 20
	credit.offset_top = -36
	root.add_child(credit)
	visible = false


func show_title() -> void:
	visible = true
	_on = true
	Sfx.music("title")
	for i in 3:
		var c := CritterModel.new(Dex.STARTERS[i])
		main.add_child(c)
		c.position = Vector3((i - 1) * 1.8, 0, 8.4)
		c.rotation.y = PI
		c.scale = Vector3.ONE * 1.1
		starters.append(c)


func _process(delta: float) -> void:
	if not _on:
		return
	_t += delta
	var a := _t * 0.12
	var focus := Vector3(0, 1.2, 6.0)
	main.rig.shot(focus + Vector3(sin(a) * 7.0, 2.6 + sin(_t * 0.3) * 0.3, cos(a) * 7.0 + 3.0), focus, 0.0)
	for i in starters.size():
		if fmod(_t + i * 0.6, 2.2) < delta:
			starters[i].hop(0.35)
			if randf() < 0.3:
				Sfx.cry(starters[i].species)


func _start(new_game: bool) -> void:
	if not _on:
		return
	_on = false
	Sfx.play("select")
	await main.hud.fade_out(0.4)
	for c in starters:
		c.queue_free()
	starters.clear()
	visible = false
	main.rig.release()
	main.begin(new_game)
