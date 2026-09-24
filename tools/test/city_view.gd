extends Node3D
## Renders the city from a few viewpoints: godot res://tools/test/city_view.tscn -- out_prefix
var frames := 0
var cam: Camera3D
var look: Node
var shots := [
	[Vector3(60, 45, 150), Vector3(0, 30, 0)],
	[Vector3(-8, 3, 30), Vector3(-8, 10, -40)],
	[Vector3(150, 120, 150), Vector3(0, 0, 0)],
	[Vector3(20, 60, 20), Vector3(-32, 120, -32)],
]
var idx := 0
var prefix := "/tmp/claude-0/-home-user-sipder-smash/a2a12b10-57b3-5066-938b-7aa665ee9353/scratchpad/city"
func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	look = load("res://scripts/comic_look.gd").new(); add_child(look)
	var city: Node3D = load("res://scripts/city.gd").new(); add_child(city)
	print("city built in ", Time.get_ticks_msec() - t0, " ms, buildings ", city.buildings.size(), " roof spots ", city.roof_spots.size())
	cam = Camera3D.new(); add_child(cam); cam.near = 0.3; cam.far = 900; cam.fov = 70
	look.attach(cam)
	_set_shot()
func _set_shot() -> void:
	cam.position = shots[idx][0]; cam.look_at(shots[idx][1])
func _process(_d: float) -> void:
	frames += 1
	if frames % 8 == 0:
		get_viewport().get_texture().get_image().save_png(prefix + str(idx) + ".png")
		idx += 1
		if idx >= shots.size(): get_tree().quit(); return
		_set_shot()
