extends Node3D
var f := 0
var w: WebLine
func _ready() -> void:
	var cam := Camera3D.new(); add_child(cam); cam.position = Vector3(0, 2, 8); cam.look_at(Vector3(0, 3, 0))
	w = WebLine.new(); add_child(w)
	w.shoot(Vector3(-2, 0, 0), Vector3(3, 8, -2))
func _process(_d: float) -> void:
	f += 1
	if f == 20:
		print("web visible=", w.visible, " aabb=", w.get_aabb(), " surfaces=", w.mesh.get_surface_count())
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-user-sipder-smash/a2a12b10-57b3-5066-938b-7aa665ee9353/scratchpad/web.png")
		get_tree().quit()
