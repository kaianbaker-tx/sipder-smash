class_name BotBolt
extends Node3D
## A glowing glitch bolt fired by Glitch-Bots. Slow enough to dodge.

var dir := Vector3.FORWARD
var speed := 22.0
var life := 3.0
var target: Player
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.38
	sm.height = 0.76
	sm.radial_segments = 8
	sm.rings = 4
	_mesh.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.25, 0.75)
	_mesh.material_override = m
	add_child(_mesh)
	var core := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.2
	cs.height = 0.4
	cs.radial_segments = 6
	cs.rings = 3
	core.mesh = cs
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1, 1, 0.8)
	cm.no_depth_test = true
	core.material_override = cm
	add_child(core)


func launch(d: Vector3, s: float, t: Player) -> void:
	dir = d
	speed = s
	target = t


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_mesh.scale = Vector3.ONE * (1.0 + 0.25 * sin(life * 40.0))
	var step := dir * speed * delta
	if target and is_instance_valid(target):
		if target.center().distance_to(global_position) < 1.25:
			target.take_hit(1, global_position)
			Fx.burst(global_position, Color(1, 0.3, 0.7), 8, 6.0, 0.2)
			queue_free()
			return
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		Fx.burst(hit.position, Color(1, 0.3, 0.7), 6, 5.0, 0.2)
		queue_free()
		return
	global_position += step
