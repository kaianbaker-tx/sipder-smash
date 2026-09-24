extends Node3D
## The Glitch Portal above Glitch Tower, with orbiting glitch cubes.

var disc: MeshInstance3D
var mat: ShaderMaterial
var cubes: Array[MeshInstance3D] = []
var _t := 0.0
var closing := false


func _ready() -> void:
	disc = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	disc.mesh = qm
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/portal.gdshader")
	disc.material_override = mat
	disc.scale = Vector3(90, 90, 1)
	disc.extra_cull_margin = 200.0
	add_child(disc)
	var cols := [Color(1, 0.2, 0.6), Color(0.1, 0.95, 1), Color(1, 0.9, 0.2), Color(0.6, 0.3, 1)]
	for k in 18:
		var c := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * randf_range(2.0, 5.0)
		c.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = cols[k % cols.size()]
		c.material_override = m
		add_child(c)
		cubes.append(c)


func close() -> void:
	closing = true
	var tw := create_tween()
	tw.tween_property(disc, "scale", Vector3(110, 110, 1), 0.3)
	tw.tween_property(disc, "scale", Vector3(0.1, 0.1, 1), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	_t += delta
	for k in cubes.size():
		var a := _t * (0.3 + (k % 3) * 0.1) + k * TAU / cubes.size()
		var r := 55.0 + sin(_t + k) * 8.0
		if closing:
			r *= maxf(0.0, disc.scale.x / 90.0)
		cubes[k].position = Vector3(cos(a) * r, sin(_t * 0.7 + k) * 10.0, sin(a) * r)
		cubes[k].rotation = Vector3(_t + k, _t * 1.3, 0)
