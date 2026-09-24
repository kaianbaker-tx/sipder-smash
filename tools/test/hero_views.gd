extends Node3D
var frames := 0
func _ready() -> void:
	var tex: Texture2D = load(OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://tools/test/uvgrid.png")
	for i in 2:
		pass
		var ch: Node3D = (load("res://assets/hero/characterMedium.fbx") as PackedScene).instantiate()
		add_child(ch); ch.scale = Vector3.ONE * 0.5; ch.position = Vector3(-1.1 + i * 2.2, 0, 0); ch.rotation_degrees.y = [0, 180, 90][i]
		var mi: MeshInstance3D = ch.find_child("characterMedium", true, false)
		var m := StandardMaterial3D.new(); m.albedo_texture = tex; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
	var cam := Camera3D.new(); add_child(cam); cam.position = Vector3(0, 1.15, 3.2); cam.look_at(Vector3(0, 1.15, 0)); cam.fov = 45
func _process(_d: float) -> void:
	frames += 1
	if frames == 6:
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-user-sipder-smash/a2a12b10-57b3-5066-938b-7aa665ee9353/scratchpad/hero_views.png")
		get_tree().quit()
