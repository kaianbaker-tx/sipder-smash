extends Node3D
## City traffic: Kenney cars drive the street grid, turn at intersections
## and keep their distance. You can land on their roofs!

const CARS := ["taxi", "taxi", "taxi", "police", "sedan", "sedan-sports", "suv", "van", "hatchback-sports", "delivery", "truck", "ambulance", "garbage-truck", "suv-luxury"]
const STEP := 64.0          # distance between intersections
const N := 3                # intersections from the centre (-3..3)
const LANE := 3.6
const CAR_SCALE := 1.45

var cars: Array = []
var rng := RandomNumberGenerator.new()


class Car:
	var node: AnimatableBody3D
	var from := Vector2i.ZERO   # intersection we left
	var dir := Vector2i(1, 0)   # grid direction
	var next_dir := Vector2i(1, 0)
	var s := 0.0                # distance along the current piece
	var piece := 0              # 0 straight, 1 turn
	var speed := 12.0
	var cruise := 12.0
	var p0 := Vector3.ZERO
	var p1 := Vector3.ZERO
	var p2 := Vector3.ZERO
	var length := 1.0
	var lights: MeshInstance3D


func _ready() -> void:
	rng.seed = 21
	for i in 26:
		_spawn(i)


func _node_pos(n: Vector2i) -> Vector3:
	return Vector3(n.x * STEP, 0.32, n.y * STEP)


func _right(d: Vector2i) -> Vector3:
	# right-hand side of travel direction
	return Vector3(-d.y, 0, d.x)


func _v3(d: Vector2i) -> Vector3:
	return Vector3(d.x, 0, d.y)


func _spawn(i: int) -> void:
	var c := Car.new()
	var kind: String = CARS[i % CARS.size()]
	c.node = AnimatableBody3D.new()
	c.node.collision_layer = 1
	c.node.collision_mask = 0
	c.node.sync_to_physics = false
	var mi := MeshInstance3D.new()
	mi.mesh = Toon.merged_mesh("res://assets/cars/%s.glb" % kind)
	mi.scale = Vector3.ONE * CAR_SCALE
	mi.rotation.y = PI
	c.node.add_child(mi)
	var aabb := mi.mesh.get_aabb()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = aabb.size * CAR_SCALE * Vector3(0.95, 0.9, 0.95)
	cs.shape = sh
	cs.position = Vector3(0, aabb.size.y * CAR_SCALE * 0.45, 0)
	c.node.add_child(cs)
	if kind == "police" or kind == "ambulance":
		c.lights = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 0.25, 0.4)
		c.lights.mesh = bm
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(1, 0.1, 0.2)
		c.lights.material_override = lm
		c.lights.position = Vector3(0, aabb.end.y * CAR_SCALE + 0.1, 0)
		c.node.add_child(c.lights)
	add_child(c.node)
	c.from = Vector2i(rng.randi_range(-N, N), rng.randi_range(-N, N))
	var dirs := _valid_dirs(c.from, Vector2i.ZERO)
	c.dir = dirs[rng.randi() % dirs.size()]
	c.cruise = rng.randf_range(10.0, 15.0)
	c.speed = c.cruise
	_begin_straight(c)
	c.s = rng.randf_range(0.0, c.length * 0.8)
	cars.append(c)


func _valid_dirs(n: Vector2i, came: Vector2i) -> Array:
	var out := []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var m: Vector2i = n + d
		if absi(m.x) > N or absi(m.y) > N:
			continue
		if d == -came and came != Vector2i.ZERO:
			continue
		out.append(d)
	if out.is_empty():
		out.append(-came)
	return out


func _begin_straight(c: Car) -> void:
	c.piece = 0
	c.s = 0.0
	var a := _node_pos(c.from) + _v3(c.dir) * 9.0 + _right(c.dir) * LANE
	var b := _node_pos(c.from + c.dir) - _v3(c.dir) * 9.0 + _right(c.dir) * LANE
	c.p0 = a
	c.p2 = b
	c.length = a.distance_to(b)


func _begin_turn(c: Car) -> void:
	c.piece = 1
	c.s = 0.0
	var node := c.from + c.dir
	var dirs := _valid_dirs(node, c.dir)
	# prefer going straight
	if dirs.has(c.dir) and rng.randf() < 0.55:
		c.next_dir = c.dir
	else:
		c.next_dir = dirs[rng.randi() % dirs.size()]
	var center := _node_pos(node)
	c.p0 = center - _v3(c.dir) * 9.0 + _right(c.dir) * LANE
	c.p2 = center + _v3(c.next_dir) * 9.0 + _right(c.next_dir) * LANE
	if c.next_dir == c.dir:
		c.p1 = (c.p0 + c.p2) * 0.5
	elif c.next_dir == -c.dir:
		c.p1 = center + _right(c.dir) * LANE * 3.0
	else:
		# corner point where the two lanes cross
		c.p1 = Vector3(c.p0.x if c.dir.x == 0 else c.p2.x, 0.32, c.p0.z if c.dir.y == 0 else c.p2.z)
	c.length = maxf(4.0, c.p0.distance_to(c.p1) + c.p1.distance_to(c.p2))


func _bez(c: Car, t: float) -> Vector3:
	var a := c.p0.lerp(c.p1, t)
	var b := c.p1.lerp(c.p2, t)
	return a.lerp(b, t)


func _car_pos(c: Car) -> Vector3:
	var t := clampf(c.s / c.length, 0.0, 1.0)
	if c.piece == 0:
		return c.p0.lerp(c.p2, t)
	return _bez(c, t)


func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for c in cars:
		var car := c as Car
		var pos := car.node.global_position
		var fwd := -car.node.global_transform.basis.z
		# slow down behind another car
		var want := car.cruise
		for o in cars:
			if o == c:
				continue
			var to := (o as Car).node.global_position - pos
			var ahead := to.dot(fwd)
			if ahead > 0.0 and ahead < 13.0 and absf(to.dot(fwd.cross(Vector3.UP))) < 2.2:
				want = minf(want, maxf(0.0, (ahead - 7.0) * 1.8))
		car.speed = move_toward(car.speed, want, delta * 14.0)
		car.s += car.speed * delta
		if car.s >= car.length:
			if car.piece == 0:
				_begin_turn(car)
			else:
				car.from = car.from + car.dir
				car.dir = car.next_dir
				_begin_straight(car)
		var p := _car_pos(car)
		var ahead_p := _car_pos_at(car, car.s + 1.5)
		var d := ahead_p - p
		var basis := car.node.global_transform.basis
		if d.length() > 0.05:
			basis = Basis.looking_at(d.normalized(), Vector3.UP)
		car.node.global_transform = Transform3D(basis, p)
		if car.lights:
			var on := fmod(t * 4.0, 1.0) < 0.5
			(car.lights.material_override as StandardMaterial3D).albedo_color = Color(1, 0.1, 0.2) if on else Color(0.1, 0.4, 1.0)


func _car_pos_at(c: Car, s: float) -> Vector3:
	if s <= c.length:
		var t := clampf(s / c.length, 0.0, 1.0)
		return c.p0.lerp(c.p2, t) if c.piece == 0 else _bez(c, t)
	# peek into the next piece: just continue straight
	var end := c.p2
	var dir := (c.p2 - (c.p1 if c.piece == 1 else c.p0)).normalized()
	return end + dir * (s - c.length)
