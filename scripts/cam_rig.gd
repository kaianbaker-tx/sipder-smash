class_name CamRig
extends Node3D
## Third-person comic camera: follows the hero, widens and pulls back when
## swinging fast, tilts into turns, shakes on big hits.

@export var target: Node3D
var yaw := 0.0
var pitch := -0.25
var arm: SpringArm3D
var cam: Camera3D
var base_len := 5.2
var _shake := 0.0
var _roll := 0.0
var _idle_look := 0.0
var _follow := Vector3.ZERO
var _look_input := Vector2.ZERO


func _ready() -> void:
	top_level = true
	arm = SpringArm3D.new()
	arm.spring_length = base_len
	arm.collision_mask = 1
	var sh := SphereShape3D.new()
	sh.radius = 0.35
	arm.shape = sh
	arm.margin = 0.2
	add_child(arm)
	cam = Camera3D.new()
	cam.near = 0.3
	cam.far = 1200.0
	cam.fov = 70.0
	arm.add_child(cam)
	cam.current = true
	if target:
		_follow = target.global_position
		global_position = _follow


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func add_look(delta: Vector2) -> void:
	yaw -= delta.x
	pitch = clampf(pitch - delta.y * (-1.0 if Game.invert_y else 1.0), -1.35, 0.9)
	_idle_look = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		add_look(m.relative * Game.mouse_sens)


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


func _process(delta: float) -> void:
	if not target:
		return
	var pad := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if pad.length() > 0.1:
		add_look(pad * delta * 2.6)
	_idle_look += delta
	var vel := Vector3.ZERO
	if "velocity" in target:
		vel = target.velocity
	var hs := Vector2(vel.x, vel.z).length()
	var spd := vel.length()
	# gently turn behind the hero when moving fast and the player is not steering the camera
	if _idle_look > 1.2 and hs > 8.0 and not Game.touch_mode:
		var want := atan2(-vel.x, -vel.z)
		yaw = lerp_angle(yaw, want, delta * 0.8)
	var goal := target.global_position + Vector3(0, 2.1, 0)
	# don't let the pivot poke into a ledge above the hero
	var q := PhysicsRayQueryParameters3D.create(target.global_position + Vector3(0, 1.0, 0), goal + Vector3(0, 0.4, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		goal.y = minf(goal.y, (hit.position as Vector3).y - 0.45)
	var k := 1.0 - exp(-delta * (14.0 if spd < 20.0 else 9.0))
	_follow = _follow.lerp(goal, k)
	global_position = _follow
	# swing roll: lean into lateral motion
	var lat := vel.dot(right())
	_roll = lerpf(_roll, clampf(-lat * 0.006, -0.2, 0.2), delta * 3.0)
	var t := clampf((spd - 10.0) / 30.0, 0.0, 1.0)
	arm.spring_length = lerpf(arm.spring_length, base_len + t * 3.5, delta * 3.0)
	cam.fov = lerpf(cam.fov, 70.0 + t * 20.0, delta * 4.0)
	rotation = Vector3(pitch, yaw, _roll)
	# shake
	_shake = move_toward(_shake, 0.0, delta * 3.0)
	var s := _shake * _shake
	cam.h_offset = randf_range(-1, 1) * s * 0.5
	cam.v_offset = randf_range(-1, 1) * s * 0.5 + 0.45
