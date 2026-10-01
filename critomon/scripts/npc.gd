class_name NPC
extends Node3D
## Someone in the world: a trainer, a Connect Four player, a helper or just
## a friendly face. main.gd decides what happens when you talk to them.
##   kind "talk"  - says their lines
##   kind "mon"   - a Crito Mon trainer (team: [["zappit", 4], ...])
##   kind "c4"    - challenges you to Connect Four (c4_level 1..3)
##   kind "heal"  - heals your Crito Mon
## Trainers with sight > 0 spot you when you walk in front of them.

var id := ""
var title := ""
var skin := "kid"
var gear := {}
var kind := "talk"
var lines: Array = []
var intro := ""
var lose_line := ""
var after := ""
var team: Array = []
var c4_level := 1
var sight := 0.0
var reward := {}
var home_yaw := 0.0

var person: Person
var body: StaticBody3D
var bubble: Label3D
var busy := false


static func make(d: Dictionary) -> NPC:
	var n := NPC.new()
	for k in d:
		if k == "pos" or k == "yaw":
			continue
		n.set(k, d[k])
	n.position = d.get("pos", Vector3.ZERO)
	n.home_yaw = d.get("yaw", 0.0)
	return n


func _ready() -> void:
	person = Person.new("res://assets/chars/skins/%s.png" % skin, 1.72 if skin != "c4kid" and skin != "youngster" and skin != "kid" else 1.45, gear)
	add_child(person)
	person.rotation.y = home_yaw
	body = StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	body.add_child(cs)
	add_child(body)
	bubble = Label3D.new()
	bubble.text = "!"
	bubble.font = preload("res://assets/fonts/lilita_one_regular.ttf")
	bubble.font_size = 160
	bubble.outline_size = 40
	bubble.modulate = Color(1, 0.25, 0.2)
	bubble.outline_modulate = Color(1, 1, 1)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.pixel_size = 0.005
	bubble.position = Vector3(0, 2.5, 0)
	bubble.visible = false
	add_child(bubble)


func beaten() -> bool:
	return Game.flag("beat_" + id)


func is_trainer() -> bool:
	return kind == "mon" or kind == "c4"


func facing() -> Vector3:
	var y := person.rotation.y
	return Vector3(-sin(y), 0, -cos(y))


func face_point(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		var yaw := atan2(-d.x, -d.z)
		var tw := create_tween()
		tw.tween_method(func(a: float) -> void: person.rotation.y = a, person.rotation.y, _near_angle(person.rotation.y, yaw), 0.18)


func _near_angle(from: float, to: float) -> float:
	return from + wrapf(to - from, -PI, PI)


## Can this trainer see a spot? (in front, close, nothing in the way)
func can_see(p: Vector3) -> bool:
	if sight <= 0.0 or busy or beaten():
		return false
	var d := p - global_position
	d.y = 0
	var along := d.dot(facing())
	if along < 0.5 or along > sight:
		return false
	var side := (d - facing() * along).length()
	if side > 1.3:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), p + Vector3(0, 1.0, 0), 1)
	q.exclude = [body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty()


func alert() -> void:
	bubble.visible = true
	bubble.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(bubble, "scale", Vector3.ONE * 1.2, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(bubble, "scale", Vector3.ONE, 0.08)
	tw.tween_interval(0.7)
	tw.tween_callback(func() -> void: bubble.visible = false)


## Walk until next to a spot. Await it.
func walk_to(p: Vector3, stop_at := 1.5, speed := 4.5) -> void:
	var t := 0.0
	face_point(p)
	while t < 10.0:
		var d := p - global_position
		d.y = 0
		if d.length() <= stop_at:
			break
		var step := minf(speed * get_process_delta_time(), d.length() - stop_at)
		global_position += d.normalized() * step
		person.move_speed(speed)
		t += get_process_delta_time()
		await get_tree().process_frame
	person.move_speed(0.0)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var far := cam.global_position.distance_to(global_position) > 60.0
		person.awake = not far
