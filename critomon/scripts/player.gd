class_name Player
extends CharacterBody3D
## You! Walk (or hold RUN), talk to people and walk through tall grass.
## Your first Crittermon follows you around.

signal moved(dist: float)

const WALK := 5.5
const RUN := 9.5
const GRAV := 25.0

var rig: CamRig
var model: Person
var partner: CritterModel
var frozen := false
var touch_move := Vector2.ZERO      # from the touch joystick
var touch_run := false
var auto_move := Vector3.ZERO       # autoplay / cutscene walking
var _trail: Array[Vector3] = []
var _step_d := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	model = Person.new("res://assets/chars/skins/player.png", 1.7, {"cap": Color(0.92, 0.18, 0.2), "cap2": Color(1, 1, 1), "bag": Color(0.2, 0.55, 0.95)})
	add_child(model)
	add_to_group("player")


func move_input() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	if touch_move.length() > v.length():
		v = Vector2(touch_move.x, -touch_move.y)
	if v.length() > 1.0:
		v = v.normalized()
	if rig == null:
		return Vector3(v.x, 0, -v.y)
	return rig.right() * v.x + rig.forward() * v.y


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	var speed := WALK
	if auto_move != Vector3.ZERO:
		dir = auto_move
	elif not frozen:
		dir = move_input()
		if Input.is_action_pressed("run") or touch_run or dir.length() > 0.98 and Game.touch_mode:
			speed = RUN
	var want := dir * speed
	velocity.x = move_toward(velocity.x, want.x, 60.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 60.0 * delta)
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAV * delta
	var before := global_position
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	var moved_d := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if flat.length() > 0.5:
		var yaw := atan2(-flat.x, -flat.y)
		model.rotation.y = lerp_angle(model.rotation.y, yaw, 1.0 - exp(-delta * 14.0))
	model.move_speed(moved_d / maxf(delta, 0.0001))
	if moved_d > 0.001:
		moved.emit(moved_d)
		_step_d += moved_d
		if _step_d > 1.6:
			_step_d = 0.0
			Sfx.play("step", 0.15, -14.0)
	_follow_partner(delta)


func face(yaw: float) -> void:
	model.rotation.y = yaw


func face_point(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		model.rotation.y = atan2(-d.x, -d.z)


func facing() -> Vector3:
	return Vector3(-sin(model.rotation.y), 0, -cos(model.rotation.y))


func teleport(pos: Vector3, yaw := 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	model.rotation.y = yaw
	_trail.clear()
	if partner:
		partner.global_position = pos - facing() * 1.4
		partner.rotation.y = yaw


## Walk to a spot (cutscenes). Await it.
func walk_to(p: Vector3, speed := 1.0) -> void:
	var t := 0.0
	while t < 8.0:
		var d := p - global_position
		d.y = 0
		if d.length() < 0.25:
			break
		auto_move = d.normalized() * speed
		t += get_physics_process_delta_time()
		await get_tree().physics_frame
	auto_move = Vector3.ZERO


# ------------------------------------------------------------------ partner

## Your lead Crittermon walks behind you ("" hides it).
func set_partner(species: String) -> void:
	if partner and partner.species == species:
		return
	if partner:
		partner.queue_free()
		partner = null
	if species == "":
		return
	partner = CritterModel.new(species)
	partner.scale = Vector3.ONE * 0.62
	get_parent().add_child(partner)
	partner.global_position = global_position - facing() * 1.4
	_trail.clear()


func _follow_partner(delta: float) -> void:
	if partner == null or not partner.visible:
		return
	if _trail.is_empty() or _trail[-1].distance_to(global_position) > 0.25:
		_trail.append(global_position)
		if _trail.size() > 40:
			_trail.pop_front()
	# aim for a trail point about 1.5 m behind
	var target := partner.global_position
	var acc := 0.0
	for i in range(_trail.size() - 1, 0, -1):
		acc += _trail[i].distance_to(_trail[i - 1])
		if acc >= 1.5:
			target = _trail[i - 1]
			break
	var d := target - partner.global_position
	d.y = 0
	var spd := d.length() / maxf(delta, 0.001)
	if d.length() > 0.02:
		partner.global_position += d * minf(1.0, delta * 8.0)
		var yaw := atan2(-d.x, -d.z)
		partner.rotation.y = lerp_angle(partner.rotation.y, yaw, 1.0 - exp(-delta * 10.0))
	partner.moving = clampf(spd * 0.05, 0.0, 1.0) if d.length() > 0.05 else move_toward(partner.moving, 0.0, delta * 4.0)
	if global_position.distance_to(partner.global_position) > 8.0:
		partner.global_position = global_position - facing() * 1.4
