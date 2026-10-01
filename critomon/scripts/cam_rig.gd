class_name CamRig
extends Node3D
## Follows the player from above and behind. Drag the mouse, use the right
## stick, Q / R, or drag on the right side of a touch screen to turn it.
## Battles and cutscenes can take over with shot() and give it back with
## release().

var cam: Camera3D
var target: Node3D
var yaw := 0.0
var pitch := -0.62
var dist := 9.5
var height := 1.3
var indoor := false
var locked := false              # a cutscene shot is showing
var _shot_tw: Tween
var _dragging := false


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 52.0
	cam.near = 0.1
	cam.far = 420.0
	add_child(cam)
	cam.current = true


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


func set_indoor(on: bool) -> void:
	indoor = on
	dist = 8.0 if on else 9.5
	pitch = -0.78 if on else -0.62


func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_dragging = mb.pressed
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(4.5, dist - 0.6)
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(14.0, dist + 0.6)
	if event is InputEventMouseMotion and _dragging and not Game.touch_mode:
		var mm := event as InputEventMouseMotion
		turn(mm.relative * Game.mouse_sens)


func turn(d: Vector2) -> void:
	yaw -= d.x
	pitch = clampf(pitch - d.y * 0.6, -1.25, -0.25)


func _process(delta: float) -> void:
	if locked or target == null:
		return
	var look := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if look.length() > 0.1:
		turn(Vector2(look.x * 2.2, look.y * 1.2) * delta)
	var focus := target.global_position + Vector3(0, height, 0)
	var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	var want := focus + off
	# don't go through walls: pull in if something is in the way
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(focus, want, 1)
	var hit := space.intersect_ray(q)
	if hit and not indoor:
		want = focus + (want - focus).normalized() * maxf(1.5, focus.distance_to(hit.position) - 0.4)
	global_position = global_position.lerp(focus, 1.0 - exp(-delta * 10.0))
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-delta * 10.0))
	cam.look_at(global_position, Vector3.UP)


## Snap behind the target right away (after a door or a battle).
func snap() -> void:
	if target == null:
		return
	var focus := target.global_position + Vector3(0, height, 0)
	global_position = focus
	cam.global_position = focus + Vector3(0, 0, dist).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	cam.look_at(focus, Vector3.UP)


## Move the camera to a fixed spot looking at a point.
func shot(pos: Vector3, look_at_point: Vector3, time := 0.6) -> void:
	locked = true
	if _shot_tw:
		_shot_tw.kill()
	if time <= 0.0:
		cam.global_position = pos
		cam.look_at(look_at_point, Vector3.UP)
		return
	var from_pos := cam.global_position
	var from_q := cam.global_transform.basis.get_rotation_quaternion()
	var to_q := Basis.looking_at(look_at_point - pos, Vector3.UP).get_rotation_quaternion()
	_shot_tw = create_tween()
	_shot_tw.tween_method(func(t: float) -> void:
		cam.global_position = from_pos.lerp(pos, t)
		cam.global_transform.basis = Basis(from_q.slerp(to_q, t)), 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func release() -> void:
	locked = false
	if _shot_tw:
		_shot_tw.kill()
