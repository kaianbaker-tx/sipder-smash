class_name SpriteBatch
extends MultiMeshInstance3D
## Many camera-facing sprites in one draw call.

var count := 0


func setup(tex: Texture2D, size: Vector2, n: int) -> void:
	var qm := QuadMesh.new()
	qm.size = size
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/billboard.gdshader")
	mat.set_shader_parameter("tex", tex)
	qm.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = qm
	multimesh.instance_count = n
	count = n
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 2000.0


func put(i: int, pos: Vector3, scale := Vector2.ONE) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(scale.x, scale.y, 1.0)), pos))


func hide_one(i: int) -> void:
	multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(0.0001, 0.0001, 1.0)), Vector3(0, -1000, 0)))
