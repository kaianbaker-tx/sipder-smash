class_name WebLine
extends MeshInstance3D
## The web rope: a white ribbon that shoots out, then stays taut.

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _grow := 1.0
var _active := false
var _im: ImmediateMesh
var _splat: Sprite3D


func _ready() -> void:
	top_level = true
	_im = ImmediateMesh.new()
	mesh = _im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.97, 0.97, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 1000.0
	_splat = Sprite3D.new()
	_splat.texture = preload("res://assets/ui/web_splat.png")
	_splat.pixel_size = 0.018
	_splat.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_splat.shaded = false
	_splat.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_splat.visible = false
	add_child(_splat)


func shoot(from: Vector3, to: Vector3) -> void:
	_from = from
	_to = to
	_grow = 0.0
	_active = true
	visible = true


func update_ends(from: Vector3, to: Vector3) -> void:
	_from = from
	_to = to


func release() -> void:
	_active = false
	visible = false
	_splat.visible = false


func _process(delta: float) -> void:
	if not _active:
		return
	_grow = minf(1.0, _grow + delta * 9.0)
	_splat.visible = _grow >= 1.0
	_splat.global_position = _to
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	global_transform = Transform3D.IDENTITY
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var end := _from.lerp(_to, _grow)
	var segs := 10
	var sag := (1.0 - _grow) * 1.5
	for i in segs + 1:
		var t := float(i) / segs
		var p := _from.lerp(end, t) + Vector3.DOWN * sin(t * PI) * sag
		var view := (cam.global_position - p).normalized()
		var dir := (end - _from).normalized()
		var side := dir.cross(view).normalized() * lerpf(0.07, 0.13, t)
		_im.surface_add_vertex(p - side)
		_im.surface_add_vertex(p + side)
	_im.surface_end()
