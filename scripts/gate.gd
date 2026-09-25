class_name Gate
extends Node3D
## A walk-through dimension portal: a swirling disc with a comic sign over
## it. Emits `entered` once when the hero runs, swings or falls into it.

signal entered

const FONT := preload("res://assets/fonts/bangers.ttf")

var label_text := "PORTAL"
var size := 7.0
var armed := true
var _disc: MeshInstance3D
var _sign: Label3D
var _t := 0.0
var _cool := 0.8


func _ready() -> void:
	_disc = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	_disc.mesh = qm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/portal.gdshader")
	_disc.material_override = mat
	_disc.position = Vector3(0, size, 0)
	add_child(_disc)
	_sign = Label3D.new()
	_sign.text = label_text
	_sign.font = FONT
	_sign.font_size = 120
	_sign.outline_size = 28
	_sign.modulate = Color(1, 0.92, 0.25)
	_sign.outline_modulate = Color(0.05, 0.0, 0.08)
	_sign.pixel_size = 0.02
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.no_depth_test = true
	_sign.fixed_size = false
	_sign.position = Vector3(0, size * 2.0 + 2.5, 0)
	add_child(_sign)
	var sparks := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.35
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	bm.material = sm
	sparks.mesh = bm
	sparks.amount = 40
	sparks.lifetime = 1.6
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = size
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 3.0
	sparks.gravity = Vector3.ZERO
	var g := Gradient.new()
	g.set_color(0, Color(0.2, 1, 1))
	g.set_color(1, Color(1, 0.2, 0.7))
	sparks.color_ramp = g
	sparks.position = Vector3(0, size, 0)
	add_child(sparks)
	# pop open
	scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK)


func centre() -> Vector3:
	return global_position + Vector3(0, size, 0)


func _process(delta: float) -> void:
	_t += delta
	_cool -= delta
	var s := size * 2.0 * (1.0 + sin(_t * 3.0) * 0.04)
	_disc.scale = Vector3(s, s, 1)
	_sign.position.y = size * 2.0 + 2.5 + sin(_t * 2.0) * 0.4
	if not armed or _cool > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	var p := player.global_position + Vector3(0, 1.0, 0)
	var c := centre()
	if Vector2(p.x - c.x, p.z - c.z).length() < size * 0.8 and absf(p.y - c.y) < size:
		armed = false
		entered.emit()
