class_name WebBall
extends Node3D
## A glob of web. Homes in on a Glitch-Bot and wraps it up.

var target: Node3D
var dir := Vector3.FORWARD
var speed := 65.0
var life := 1.4


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1)
	mi.material_override = m
	add_child(mi)


func launch(t: Node3D, d: Vector3) -> void:
	target = t
	dir = d.normalized()


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if target and is_instance_valid(target) and not ("dead" in target and target.dead):
		var to := target.global_position - global_position
		if to.length() < 1.3:
			if target.has_method("webbed"):
				target.webbed()
			Fx.word("SPLAT!", global_position, "small", Color(1, 1, 1))
			Fx.burst(global_position, Color(1, 1, 1), 8, 5.0, 0.2)
			Sfx.play("splat", 0.1)
			queue_free()
			return
		dir = dir.slerp(to.normalized(), minf(1.0, delta * 10.0))
	var step := dir * speed * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		Fx.burst(hit.position, Color(1, 1, 1), 6, 4.0, 0.18)
		queue_free()
		return
	global_position += step
