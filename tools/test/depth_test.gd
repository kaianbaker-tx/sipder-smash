extends Node3D
var frames := 0
func _ready() -> void:
	var cam := Camera3D.new(); add_child(cam); cam.position = Vector3(0, 12, 40); cam.look_at(Vector3(0, 10, 0)); cam.far = 1000
	for i in 5:
		var b: Node3D = (load("res://assets/city/building-skyscraper-%s.glb" % "abcde"[i]) as PackedScene).instantiate()
		add_child(b); b.position = Vector3(-40 + i * 20, 0, -i * 8); b.scale = Vector3.ONE * 14
	var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(2, 2); q.mesh = qm
	var sm := ShaderMaterial.new(); sm.shader = load("res://tools/test/depth_test.gdshader"); q.material_override = sm
	q.extra_cull_margin = 16384; cam.add_child(q)
	var l := DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-45, 30, 0)
func _process(_d: float) -> void:
	frames += 1
	if frames == 10:
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-user-sipder-smash/a2a12b10-57b3-5066-938b-7aa665ee9353/scratchpad/depth.png")
		get_tree().quit()
