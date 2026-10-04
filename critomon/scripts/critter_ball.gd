class_name CritterBall
extends Node3D
## A green and white Critter Ball. The top can pop open. About 0.3 m across at
## scale 1. The hinge is at the back (+Z).

var top: Node3D
var glow := 0.0:
	set(v):
		glow = v
		if _top:
			_top.set_shader_parameter("emission", 0.15 + v)
			_white.set_shader_parameter("emission", v)

var _top: ShaderMaterial
var _white: ShaderMaterial

static var _half: SphereMesh
static var _band: CylinderMesh
static var _button: CylinderMesh


func _ready() -> void:
	if _half == null:
		_half = SphereMesh.new()
		_half.radius = 0.15
		_half.height = 0.15
		_half.is_hemisphere = true
		_half.radial_segments = 20
		_half.rings = 6
		_band = CylinderMesh.new()
		_band.top_radius = 0.153
		_band.bottom_radius = 0.153
		_band.height = 0.03
		_band.radial_segments = 20
		_band.rings = 1
		_button = CylinderMesh.new()
		_button.top_radius = 0.045
		_button.bottom_radius = 0.045
		_button.height = 0.03
		_button.radial_segments = 12
		_button.rings = 1
	_top = Toon.unique(Color(0.16, 0.74, 0.3))
	_top.set_shader_parameter("rim", 0.6)
	_top.set_shader_parameter("emission", 0.15)
	_top.next_pass = Toon.outline()
	_white = Toon.unique(Color(0.97, 0.97, 0.97))
	_white.set_shader_parameter("rim", 0.5)
	_white.next_pass = Toon.outline()
	var ink := Toon.color(Color(0.15, 0.12, 0.2))
	var bottom := MeshInstance3D.new()
	bottom.mesh = _half
	bottom.material_override = _white
	bottom.rotation.x = PI
	add_child(bottom)
	var band := MeshInstance3D.new()
	band.mesh = _band
	band.material_override = ink
	add_child(band)
	# the top hinges open around the back edge
	var hinge := Node3D.new()
	hinge.position = Vector3(0, 0, 0.15)
	add_child(hinge)
	top = hinge
	var t := MeshInstance3D.new()
	t.mesh = _half
	t.material_override = _top
	t.position = Vector3(0, 0, -0.15)
	hinge.add_child(t)
	var ring := MeshInstance3D.new()
	ring.mesh = _button
	ring.material_override = ink
	ring.scale = Vector3(1.5, 1, 1.5)
	ring.rotation.x = PI / 2
	ring.position = Vector3(0, 0, -0.15)
	add_child(ring)
	var btn := MeshInstance3D.new()
	btn.mesh = _button
	btn.material_override = _white
	btn.rotation.x = PI / 2
	btn.position = Vector3(0, 0, -0.16)
	add_child(btn)


func open(on := true) -> void:
	var tw := create_tween()
	tw.tween_property(top, "rotation:x", -1.2 if on else 0.0, 0.18).set_trans(Tween.TRANS_BACK)


## Shake side to side (catching). Await it.
func wobble() -> void:
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.45, 0.12)
	tw.tween_property(self, "rotation:z", -0.45, 0.2)
	tw.tween_property(self, "rotation:z", 0.0, 0.12)
	await tw.finished
