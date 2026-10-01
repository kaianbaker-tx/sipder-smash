class_name FX
## Little battle effects: bursts of bits, flying shots, lightning, rings and
## sparkles. Everything cleans itself up.

const TYPE_FX := {
	"normal": {"color": Color(1, 1, 1), "sound": "hit"},
	"fire": {"color": Color(1.0, 0.5, 0.15), "sound": "fire"},
	"water": {"color": Color(0.35, 0.7, 1.0), "sound": "water"},
	"grass": {"color": Color(0.45, 0.9, 0.35), "sound": "leaf"},
	"electric": {"color": Color(1.0, 0.9, 0.25), "sound": "zap"},
	"rock": {"color": Color(0.7, 0.62, 0.5), "sound": "rock"},
	"bug": {"color": Color(0.7, 0.9, 0.3), "sound": "hit"},
	"flying": {"color": Color(0.85, 0.9, 1.0), "sound": "wind"},
}

static var _bit: SphereMesh
static var _cube: BoxMesh


static func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.vertex_color_use_as_albedo = true
	m.billboard_keep_scale = true
	return m


static func _meshes() -> void:
	if _bit:
		return
	_bit = SphereMesh.new()
	_bit.radius = 0.5
	_bit.height = 1.0
	_bit.radial_segments = 8
	_bit.rings = 4
	_cube = BoxMesh.new()


## A one-shot burst of little balls (or cubes for rocks / leaves).
static func burst(parent: Node, pos: Vector3, c: Color, amount := 24, speed := 5.0, size := 0.16, cubes := false) -> void:
	_meshes()
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 0.95
	var m: Mesh = (_cube if cubes else _bit).duplicate()
	(m as PrimitiveMesh).material = _glow(c)
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.angle_min = 0
	p.angle_max = 360
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## Hit sparks: a white star flash plus coloured bits.
static func hit(parent: Node, pos: Vector3, move_type: String, big := false) -> void:
	var c: Color = TYPE_FX.get(move_type, TYPE_FX.normal).color
	burst(parent, pos, c, 30 if big else 18, 6.0 if big else 4.5, 0.2 if big else 0.15, move_type in ["rock", "grass"])
	burst(parent, pos, Color(1, 1, 1), 10, 3.0, 0.12)
	var star := MeshInstance3D.new()
	_meshes()
	star.mesh = _bit
	star.material_override = _glow(Color(1, 1, 0.9))
	star.position = pos
	star.scale = Vector3.ONE * 0.2
	parent.add_child(star)
	var tw := star.create_tween()
	tw.tween_property(star, "scale", Vector3.ONE * (1.4 if big else 1.0), 0.08)
	tw.tween_property(star, "scale", Vector3.ONE * 0.01, 0.12)
	tw.tween_callback(star.queue_free)


## A ball of energy flying from a to b. Await the returned signal.
static func shot(parent: Node, a: Vector3, b: Vector3, move_type: String, time := 0.35) -> Signal:
	_meshes()
	var c: Color = TYPE_FX.get(move_type, TYPE_FX.normal).color
	var ball := MeshInstance3D.new()
	ball.mesh = _cube if move_type in ["rock", "grass"] else _bit
	ball.material_override = _glow(c)
	ball.scale = Vector3.ONE * 0.45
	ball.position = a
	parent.add_child(ball)
	var trail := CPUParticles3D.new()
	trail.amount = 24
	trail.lifetime = 0.25
	var tm: Mesh = _bit.duplicate()
	(tm as PrimitiveMesh).material = _glow(c.lightened(0.3))
	trail.mesh = tm
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.6
	trail.spread = 180
	trail.scale_amount_min = 0.12
	trail.scale_amount_max = 0.22
	trail.local_coords = false
	ball.add_child(trail)
	var tw := ball.create_tween()
	var mid := (a + b) * 0.5 + Vector3(0, 1.2, 0)
	tw.tween_method(func(t: float) -> void:
		ball.position = a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		ball.rotation += Vector3(0.3, 0.4, 0.2), 0.0, 1.0, time)
	tw.tween_callback(ball.queue_free)
	return tw.finished


## A zig-zag lightning bolt from the sky onto a spot.
static func lightning(parent: Node, pos: Vector3) -> void:
	_meshes()
	var mat := _glow(Color(1.0, 0.95, 0.4))
	var root := Node3D.new()
	parent.add_child(root)
	var p := pos + Vector3(0, 6, 0)
	for i in 7:
		var q := pos.lerp(pos + Vector3(0, 6, 0), 1.0 - (i + 1) / 7.0) + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.3, 0.3))
		if i == 6:
			q = pos
		var seg := MeshInstance3D.new()
		seg.mesh = _cube
		seg.material_override = mat
		var mid := (p + q) * 0.5
		seg.position = mid
		seg.scale = Vector3(0.12, p.distance_to(q), 0.12)
		seg.basis = Basis(Quaternion(Vector3.UP, (p - q).normalized())) * Basis().scaled(Vector3(0.14, p.distance_to(q), 0.14))
		root.add_child(seg)
		p = q
	var tw := root.create_tween()
	for k in 3:
		tw.tween_property(root, "visible", false, 0.05)
		tw.tween_property(root, "visible", true, 0.05)
	tw.tween_callback(root.queue_free)


## An expanding ring on the ground (shouts, stat changes).
static func ring(parent: Node, pos: Vector3, c: Color, up := false) -> void:
	var r := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.8
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 6
	r.mesh = tm
	r.material_override = _glow(c)
	r.position = pos
	r.scale = Vector3.ONE * 0.3
	parent.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "scale", Vector3(2.2, 1, 2.2), 0.45)
	if up:
		tw.parallel().tween_property(r, "position:y", pos.y + 1.6, 0.45)
	tw.tween_callback(r.queue_free)


## Sparkles rising (level up, healing, buffs).
static func sparkle(parent: Node, pos: Vector3, c := Color(1.0, 0.95, 0.5)) -> void:
	_meshes()
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 26
	p.lifetime = 1.0
	p.explosiveness = 0.6
	var m: Mesh = _bit.duplicate()
	(m as PrimitiveMesh).material = _glow(c)
	p.mesh = m
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.7
	p.direction = Vector3.UP
	p.spread = 25
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(1.6).timeout.connect(p.queue_free)
