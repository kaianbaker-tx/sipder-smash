extends Node3D
## Line-ups of the hero in every suit, 9 per picture:
## godot res://tools/test/suit_lineup.tscn -- --out=/some/dir
var frames := 0
var page := 0
var heroes: Array = []
var labels: Array = []
var out := "user://suits"
var keys: Array = []


func _ready() -> void:
	out = Game.args.get("out", out)
	DirAccess.make_dir_recursive_absolute(out)
	keys = Game.SUITS.keys()
	var look: Node = load("res://scripts/comic_look.gd").new()
	add_child(look)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.1, 5.3)
	cam.look_at(Vector3(0, 0.95, 0))
	cam.fov = 45
	look.attach(cam)
	RenderingServer.global_shader_parameter_set("sun_dir", Vector3(0.2, 0.6, 0.8).normalized())
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 20)
	floor_mi.mesh = pm
	floor_mi.material_override = Toon.material(load("res://tools/test/uvgrid.png"))
	add_child(floor_mi)
	for i in 9:
		var h := HeroModel.new()
		add_child(h)
		h.position = Vector3(-6.4 + i * 1.6, 0, 0)
		h.rotation.y = 0.0 if i % 3 != 2 else PI
		heroes.append(h)
		var l := Label3D.new()
		l.font_size = 64
		l.pixel_size = 0.004
		l.outline_size = 16
		l.position = Vector3(-6.4 + i * 1.6, 2.05, 0)
		add_child(l)
		labels.append(l)
	_show_page()


func _show_page() -> void:
	for i in 9:
		var n := page * 9 + i
		heroes[i].visible = n < keys.size()
		labels[i].visible = n < keys.size()
		if n < keys.size():
			heroes[i].set_skin(load(Game.SUITS[keys[n]].tex))
			labels[i].text = Game.SUITS[keys[n]].name
	frames = 0


func _process(_d: float) -> void:
	frames += 1
	if frames < 6:
		return
	get_viewport().get_texture().get_image().save_png("%s/suits_%d.png" % [out, page])
	page += 1
	if page * 9 >= keys.size():
		get_tree().quit()
		return
	_show_page()
