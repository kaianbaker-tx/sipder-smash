class_name CritterModel
extends Node3D
## A Crittermon built out of round shapes, with cartoon shading and ink
## outlines. It bobs, hops, lunges, flashes when hit and fades when it faints.
## Faces -Z like everything else in Godot. About 1 metre tall at scale 1.

signal done

var species := "emberpup"
var body: Node3D
var moving := 0.0           # 0..1 walking bounce (overworld)
var shiny_rim := 0.45

var _mats := {}
var _t := 0.0
var _flames: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _tail: Node3D
var _hop := 0.0
var _hop_h := 0.0

static var _sphere: SphereMesh
static var _cone: CylinderMesh
static var _cyl: CylinderMesh
static var _box: BoxMesh


func _init(sp := "emberpup") -> void:
	species = sp


func _ready() -> void:
	_t = randf() * 10.0
	body = Node3D.new()
	add_child(body)
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 18
		_sphere.rings = 9
		_cone = CylinderMesh.new()
		_cone.top_radius = 0.0
		_cone.bottom_radius = 1.0
		_cone.height = 1.0
		_cone.radial_segments = 12
		_cone.rings = 1
		_cyl = CylinderMesh.new()
		_cyl.top_radius = 1.0
		_cyl.bottom_radius = 1.0
		_cyl.height = 1.0
		_cyl.radial_segments = 10
		_cyl.rings = 1
		_box = BoxMesh.new()
	call("_build_" + species)


# ------------------------------------------------------------------ parts

func _mat(c: Color, glow := 0.0) -> ShaderMaterial:
	var key := str(c) + str(glow)
	if _mats.has(key):
		return _mats[key]
	var m := Toon.unique(c)
	m.set_shader_parameter("rim", shiny_rim)
	m.set_shader_parameter("emission", glow)
	m.next_pass = Toon.outline()
	_mats[key] = m
	return m


func _flat_mat(c: Color) -> ShaderMaterial:
	# small details (eyes, cheeks) have no outline of their own
	var key := "flat" + str(c)
	if _mats.has(key):
		return _mats[key]
	var m := Toon.unique(c)
	m.set_shader_parameter("rim", 0.0)
	_mats[key] = m
	return m


## A ball part. r = radius on each axis.
func _ball(c: Color, pos: Vector3, r: Vector3, rot := Vector3.ZERO, parent: Node3D = null, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = _mat(c, glow)
	mi.position = pos
	mi.rotation = rot
	mi.scale = r
	(parent if parent else body).add_child(mi)
	return mi


## A cone part pointing up its own +Y. r = base radius, h = height.
func _spike(c: Color, pos: Vector3, r: float, h: float, rot := Vector3.ZERO, parent: Node3D = null, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _cone
	mi.material_override = _mat(c, glow)
	mi.position = pos
	mi.rotation = rot
	mi.scale = Vector3(r, h, r)
	(parent if parent else body).add_child(mi)
	return mi


func _eyes(y: float, z: float, spread: float, size := 1.0, parent: Node3D = null, angry := false) -> void:
	var black := _flat_mat(Color(0.08, 0.05, 0.12))
	var white := _flat_mat(Color(1, 1, 1))
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		e.mesh = _sphere
		e.material_override = black
		e.position = Vector3(spread * sx, y, z)
		e.scale = Vector3(0.062, 0.085, 0.04) * size
		e.rotation.y = -0.35 * sx
		(parent if parent else body).add_child(e)
		var h := MeshInstance3D.new()
		h.mesh = _sphere
		h.material_override = white
		h.position = Vector3(spread * sx - 0.018 * size * sx, y + 0.03 * size, z - 0.03 * size)
		h.scale = Vector3.ONE * 0.026 * size
		(parent if parent else body).add_child(h)
		if angry:
			var b := MeshInstance3D.new()
			b.mesh = _box
			b.material_override = black
			b.position = Vector3(spread * sx, y + 0.1 * size, z - 0.01)
			b.scale = Vector3(0.14, 0.035, 0.04) * size
			b.rotation.z = 0.45 * sx
			(parent if parent else body).add_child(b)


func _dot(c: Color, pos: Vector3, r: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere
	mi.material_override = _flat_mat(c)
	mi.position = pos
	mi.scale = r
	(parent if parent else body).add_child(mi)
	return mi


func _pivot(pos: Vector3, parent: Node3D = null) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	(parent if parent else body).add_child(p)
	return p


# ------------------------------------------------------------------ species
# Faces -Z: "front" parts have negative z.

func _build_emberpup() -> void:
	var orange := Color(1.0, 0.5, 0.16)
	var cream := Color(1.0, 0.9, 0.7)
	var brown := Color(0.5, 0.22, 0.12)
	_ball(orange, Vector3(0, 0.36, 0.05), Vector3(0.3, 0.27, 0.38))
	_ball(cream, Vector3(0, 0.34, -0.14), Vector3(0.2, 0.2, 0.2))
	var head := _pivot(Vector3(0, 0.72, -0.2))
	_ball(orange, Vector3.ZERO, Vector3(0.33, 0.3, 0.3), Vector3.ZERO, head)
	_ball(cream, Vector3(0, -0.08, -0.25), Vector3(0.14, 0.1, 0.11), Vector3.ZERO, head)
	_dot(brown, Vector3(0, -0.04, -0.36), Vector3(0.05, 0.04, 0.035), head)
	_eyes(0.04, -0.25, 0.14, 1.0, head)
	for sx in [-1.0, 1.0]:
		var ear := _pivot(Vector3(0.17 * sx, 0.22, 0.02), head)
		_spike(orange, Vector3(0, 0.12, 0), 0.12, 0.3, Vector3(0, 0, -0.35 * sx), ear)
		_spike(brown, Vector3(0.06 * sx, 0.26, 0), 0.05, 0.1, Vector3(0, 0, -0.35 * sx), ear)
		_ears.append(ear)
		_ball(cream, Vector3(0.24 * sx, -0.1, -0.12), Vector3(0.09, 0.07, 0.08), Vector3.ZERO, head)
		for fz in [-0.2, 0.26]:
			_ball(orange.darkened(0.1), Vector3(0.17 * sx, 0.13, fz), Vector3(0.09, 0.13, 0.09))
			_ball(cream, Vector3(0.17 * sx, 0.04, fz - 0.03), Vector3(0.085, 0.05, 0.1))
	_tail = _pivot(Vector3(0, 0.42, 0.42))
	_ball(orange, Vector3(0, 0.02, 0.02), Vector3(0.1, 0.1, 0.13), Vector3.ZERO, _tail)
	var flame := _pivot(Vector3(0, 0.12, 0.1), _tail)
	_spike(Color(1.0, 0.35, 0.1), Vector3(0, 0.12, 0), 0.15, 0.4, Vector3(0.3, 0, 0), flame, 0.5)
	_spike(Color(1.0, 0.7, 0.15), Vector3(0, 0.1, -0.02), 0.1, 0.3, Vector3(0.3, 0, 0), flame, 0.7)
	_spike(Color(1.0, 0.95, 0.5), Vector3(0, 0.07, -0.03), 0.05, 0.18, Vector3(0.3, 0, 0), flame, 0.9)
	_flames.append(flame)


func _build_bubbloo() -> void:
	var blue := Color(0.38, 0.68, 1.0)
	var pale := Color(0.82, 0.93, 1.0)
	var pink := Color(1.0, 0.5, 0.72)
	var fin := Color(0.6, 0.86, 1.0)
	_ball(blue, Vector3(0, 0.3, 0.05), Vector3(0.34, 0.26, 0.42))
	_ball(pale, Vector3(0, 0.24, -0.08), Vector3(0.26, 0.18, 0.28))
	var head := _pivot(Vector3(0, 0.6, -0.22))
	_ball(blue, Vector3.ZERO, Vector3(0.38, 0.3, 0.3), Vector3.ZERO, head)
	_eyes(0.06, -0.25, 0.17, 1.0, head)
	_ball(fin, Vector3(0, 0.28, 0.06), Vector3(0.04, 0.12, 0.2), Vector3.ZERO, head)
	for sx in [-1.0, 1.0]:
		_dot(pink, Vector3(0.23 * sx, -0.06, -0.21), Vector3(0.06, 0.04, 0.03), head)
		var gill := _pivot(Vector3(0.33 * sx, 0.02, 0.02), head)
		for i in 3:
			var a := -0.6 + i * 0.6
			_ball(pink, Vector3(0.1 * sx * cos(a), 0.1 * sin(a) + 0.02, 0), Vector3(0.14, 0.04, 0.045), Vector3(0, 0, a * sx), gill)
		_ears.append(gill)
		for fz in [-0.22, 0.3]:
			_ball(blue.darkened(0.1), Vector3(0.24 * sx, 0.08, fz), Vector3(0.1, 0.08, 0.11))
	_tail = _pivot(Vector3(0, 0.34, 0.5))
	_ball(fin, Vector3(0, 0, 0.12), Vector3(0.05, 0.18, 0.28), Vector3.ZERO, _tail)


func _build_sproutle() -> void:
	var green := Color(0.42, 0.8, 0.34)
	var belly := Color(0.93, 0.96, 0.58)
	var dark := Color(0.2, 0.52, 0.25)
	var leaf := Color(0.55, 0.92, 0.3)
	_ball(green, Vector3(0, 0.4, 0), Vector3(0.3, 0.33, 0.3))
	_ball(belly, Vector3(0, 0.38, -0.14), Vector3(0.22, 0.25, 0.18))
	var head := _pivot(Vector3(0, 0.84, -0.08))
	_ball(green, Vector3.ZERO, Vector3(0.33, 0.28, 0.3), Vector3.ZERO, head)
	_eyes(0.04, -0.25, 0.15, 1.1, head)
	_dot(Color(1.0, 0.55, 0.55), Vector3(0.2, -0.08, -0.22), Vector3(0.05, 0.035, 0.03), head)
	_dot(Color(1.0, 0.55, 0.55), Vector3(-0.2, -0.08, -0.22), Vector3(0.05, 0.035, 0.03), head)
	var sprout := _pivot(Vector3(0, 0.26, 0.02), head)
	var stem := MeshInstance3D.new()
	stem.mesh = _cyl
	stem.material_override = _mat(dark)
	stem.scale = Vector3(0.025, 0.16, 0.025)
	stem.position = Vector3(0, 0.06, 0)
	sprout.add_child(stem)
	_ball(leaf, Vector3(0.12, 0.16, 0), Vector3(0.14, 0.03, 0.075), Vector3(0, 0, 0.5), sprout)
	_ball(leaf, Vector3(-0.12, 0.16, 0), Vector3(0.14, 0.03, 0.075), Vector3(0, 0, -0.5), sprout)
	_ears.append(sprout)
	for sx in [-1.0, 1.0]:
		_ball(green.darkened(0.08), Vector3(0.16 * sx, 0.07, -0.06), Vector3(0.11, 0.07, 0.15))
		_ball(green, Vector3(0.28 * sx, 0.46, -0.1), Vector3(0.07, 0.1, 0.07), Vector3(0, 0, 0.4 * sx))
	for i in 3:
		_spike(dark, Vector3(0, 0.66 - i * 0.14, 0.24 + i * 0.05), 0.05, 0.12, Vector3(1.1, 0, 0))
	_tail = _pivot(Vector3(0, 0.26, 0.3))
	_ball(green, Vector3(0, 0, 0.06), Vector3(0.12, 0.1, 0.18), Vector3.ZERO, _tail)
	_ball(green, Vector3(0, 0.05, 0.28), Vector3(0.08, 0.07, 0.14), Vector3(-0.3, 0, 0), _tail)
	_ball(leaf, Vector3(0, 0.14, 0.44), Vector3(0.12, 0.03, 0.1), Vector3(-0.6, 0, 0), _tail)


func _build_zappit() -> void:
	var yellow := Color(1.0, 0.86, 0.25)
	var tip := Color(0.3, 0.22, 0.2)
	_ball(yellow, Vector3(0, 0.32, 0), Vector3(0.26, 0.28, 0.24))
	_ball(Color(1.0, 0.96, 0.75), Vector3(0, 0.3, -0.12), Vector3(0.17, 0.19, 0.14))
	var head := _pivot(Vector3(0, 0.72, -0.05))
	_ball(yellow, Vector3.ZERO, Vector3(0.3, 0.27, 0.27), Vector3.ZERO, head)
	_eyes(0.06, -0.22, 0.12, 1.0, head)
	_dot(Color(1.0, 0.5, 0.6), Vector3(0, -0.03, -0.27), Vector3(0.035, 0.025, 0.025), head)
	for sx in [-1.0, 1.0]:
		_ball(Color(1.0, 0.25, 0.2), Vector3(0.2 * sx, -0.08, -0.18), Vector3(0.07, 0.07, 0.035), Vector3(0, -0.5 * sx, 0), head, 0.25)
		var ear := _pivot(Vector3(0.12 * sx, 0.2, 0.03), head)
		_ball(yellow, Vector3(0.03 * sx, 0.28, 0), Vector3(0.07, 0.3, 0.05), Vector3(0, 0, -0.2 * sx), ear)
		_ball(tip, Vector3(0.1 * sx, 0.52, 0), Vector3(0.055, 0.08, 0.045), Vector3(0, 0, -0.2 * sx), ear)
		_ears.append(ear)
		_ball(yellow, Vector3(0.13 * sx, 0.05, -0.05), Vector3(0.09, 0.05, 0.15))
		_ball(yellow, Vector3(0.22 * sx, 0.36, -0.12), Vector3(0.06, 0.08, 0.06))
	_tail = _pivot(Vector3(0, 0.3, 0.22))
	var bolt := Color(1.0, 0.8, 0.1)
	for i in 3:
		var b := MeshInstance3D.new()
		b.mesh = _box
		b.material_override = _mat(bolt, 0.35)
		b.position = Vector3(0.05 * (1 if i % 2 == 0 else -1), 0.08 + i * 0.13, 0.05 + i * 0.03)
		b.rotation.z = 0.7 * (1 if i % 2 == 0 else -1)
		b.scale = Vector3(0.07, 0.2, 0.08)
		_tail.add_child(b)


func _build_fluffle() -> void:
	var pink := Color(1.0, 0.68, 0.84)
	var pale := Color(1.0, 0.88, 0.94)
	var tuft := Color(0.75, 0.5, 0.95)
	_ball(pink, Vector3(0, 0.48, 0), Vector3(0.4, 0.38, 0.38))
	_ball(pale, Vector3(0, 0.5, -0.2), Vector3(0.28, 0.26, 0.2))
	_eyes(0.62, -0.33, 0.13)
	_spike(Color(1.0, 0.6, 0.15), Vector3(0, 0.5, -0.4), 0.06, 0.14, Vector3(-PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		var w := _pivot(Vector3(0.36 * sx, 0.5, 0.02))
		_ball(pale, Vector3(0.05 * sx, -0.02, 0.04), Vector3(0.06, 0.2, 0.26), Vector3(0, 0, 0.3 * sx), w)
		_wings.append(w)
		_ball(Color(1.0, 0.6, 0.15), Vector3(0.12 * sx, 0.06, -0.05), Vector3(0.05, 0.05, 0.08))
		_dot(Color(1.0, 0.45, 0.6), Vector3(0.22 * sx, 0.5, -0.31), Vector3(0.05, 0.035, 0.03))
	var top := _pivot(Vector3(0, 0.84, 0))
	for i in 3:
		_spike(tuft, Vector3((i - 1) * 0.06, 0.02, 0), 0.05, 0.18, Vector3(0, 0, (1 - i) * 0.45), top)
	_ears.append(top)


func _build_pebblit() -> void:
	var grey := Color(0.64, 0.62, 0.6)
	var dark := Color(0.5, 0.48, 0.47)
	_ball(grey, Vector3(0, 0.36, 0), Vector3(0.38, 0.34, 0.34))
	_ball(dark, Vector3(0.2, 0.55, 0.1), Vector3(0.18, 0.16, 0.18))
	_ball(dark, Vector3(-0.22, 0.5, 0.12), Vector3(0.16, 0.15, 0.16))
	_ball(grey, Vector3(0, 0.62, 0.16), Vector3(0.2, 0.17, 0.2))
	_eyes(0.44, -0.29, 0.13, 1.0, null, true)
	_spike(Color(0.88, 0.76, 0.55), Vector3(0, 0.66, -0.12), 0.08, 0.22, Vector3(-0.3, 0, 0))
	for sx in [-1.0, 1.0]:
		var arm := _pivot(Vector3(0.38 * sx, 0.3, -0.05))
		_ball(dark, Vector3(0.04 * sx, 0, 0), Vector3(0.12, 0.1, 0.1), Vector3.ZERO, arm)
		_ears.append(arm)
		_ball(dark, Vector3(0.17 * sx, 0.05, -0.06), Vector3(0.11, 0.06, 0.12))


func _build_buzzlet() -> void:
	var yellow := Color(1.0, 0.85, 0.3)
	var lime := Color(0.62, 0.86, 0.22)
	var stripe := Color(0.3, 0.24, 0.2)
	_ball(yellow, Vector3(0, 0.36, 0.25), Vector3(0.24, 0.22, 0.3))
	_ball(stripe, Vector3(0, 0.36, 0.2), Vector3(0.245, 0.225, 0.04))
	_ball(stripe, Vector3(0, 0.36, 0.35), Vector3(0.22, 0.2, 0.04))
	_ball(lime, Vector3(0, 0.4, -0.05), Vector3(0.2, 0.2, 0.2))
	var head := _pivot(Vector3(0, 0.58, -0.25))
	_ball(lime, Vector3.ZERO, Vector3(0.22, 0.2, 0.2), Vector3.ZERO, head)
	_eyes(0.04, -0.16, 0.1, 1.1, head)
	for sx in [-1.0, 1.0]:
		var ant := _pivot(Vector3(0.08 * sx, 0.16, -0.05), head)
		var stalk := MeshInstance3D.new()
		stalk.mesh = _cyl
		stalk.material_override = _mat(stripe)
		stalk.scale = Vector3(0.015, 0.26, 0.015)
		stalk.position = Vector3(0.04 * sx, 0.12, -0.03)
		stalk.rotation = Vector3(-0.3, 0, -0.3 * sx)
		ant.add_child(stalk)
		_ball(yellow, Vector3(0.08 * sx, 0.25, -0.07), Vector3.ONE * 0.045, Vector3.ZERO, ant)
		_ears.append(ant)
		var w := _pivot(Vector3(0.12 * sx, 0.58, 0.05))
		_ball(Color(0.8, 0.95, 1.0), Vector3(0.12 * sx, 0.12, 0.12), Vector3(0.04, 0.16, 0.26), Vector3(0.5, 0, 0.5 * sx), w, 0.2)
		_wings.append(w)
		for fz in [-0.12, 0.05, 0.22]:
			_ball(stripe, Vector3(0.17 * sx, 0.12, fz), Vector3(0.04, 0.12, 0.04), Vector3(0, 0, 0.4 * sx))


# ------------------------------------------------------------------ motion

func _process(delta: float) -> void:
	_t += delta
	var bob := sin(_t * 3.2) * 0.02
	var squash := 1.0 + sin(_t * 3.2) * 0.025
	if moving > 0.01:
		var ph := fmod(_t * 7.0, PI)
		bob += sin(ph) * 0.12 * moving
		squash += (sin(ph * 2.0) * 0.06) * moving
	if _hop > 0.0:
		_hop = maxf(0.0, _hop - delta * 2.6)
		bob += sin((1.0 - _hop) * PI) * _hop_h
	if species == "fluffle":
		bob += 0.12 + sin(_t * 2.0) * 0.06
	body.position.y = bob
	body.scale = Vector3(1.0 / sqrt(squash), squash, 1.0 / sqrt(squash))
	for f in _flames:
		f.scale = Vector3(1.0 + sin(_t * 21.0) * 0.08, 1.0 + sin(_t * 17.0) * 0.15 + sin(_t * 31.0) * 0.07, 1.0)
	for i in _wings.size():
		var w := _wings[i]
		var sx := -1.0 if i % 2 == 0 else 1.0
		var spd := 28.0 if species == "buzzlet" else 9.0
		w.rotation.z = sin(_t * spd) * 0.5 * sx
	for i in _ears.size():
		_ears[i].rotation.x = sin(_t * 2.3 + i) * 0.08
	if _tail:
		_tail.rotation.y = sin(_t * 4.0) * 0.25


func hop(h := 0.35) -> void:
	_hop = 1.0
	_hop_h = h


func set_param(p: String, v: Variant) -> void:
	for k in _mats:
		(_mats[k] as ShaderMaterial).set_shader_parameter(p, v)


## Flash white a few times (got hit).
func hurt() -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_callback(set_param.bind("flash", 0.9))
		tw.tween_interval(0.07)
		tw.tween_callback(set_param.bind("flash", 0.0))
		tw.tween_interval(0.07)
	var base := body.position.x
	var tw2 := create_tween()
	for i in 4:
		tw2.tween_property(body, "position:x", base + (0.08 if i % 2 == 0 else -0.08), 0.04)
	tw2.tween_property(body, "position:x", base, 0.04)


## Dash toward a point (world space) and come back.
func lunge(target: Vector3, dist := 0.8) -> void:
	var home := position
	var dir := (target - global_position)
	dir.y = 0
	dir = dir.normalized()
	var tw := create_tween()
	tw.tween_property(self, "position", home - dir * 0.2, 0.12)
	tw.tween_property(self, "position", home + dir * dist, 0.1)
	tw.tween_property(self, "position", home, 0.2)


## Fall over and fade away.
func faint() -> void:
	var tw := create_tween()
	tw.tween_property(body, "position:y", -0.6, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(func(f: float) -> void: set_param("fade", f), 0.0, 1.0, 0.5)
	tw.tween_callback(func() -> void:
		visible = false
		done.emit())


## Pop out of a Critter Ball: grow from nothing with a white flash.
func appear() -> void:
	visible = true
	set_param("fade", 0.0)
	set_param("flash", 1.0)
	var s := scale
	scale = s * 0.05
	var tw := create_tween()
	tw.tween_property(self, "scale", s * 1.15, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", s, 0.1)
	tw.parallel().tween_method(func(f: float) -> void: set_param("flash", f), 1.0, 0.0, 0.3)
	tw.tween_callback(func() -> void: done.emit())


## Turn red and shrink into a point (going back into a ball).
func shrink_to(world_point: Vector3) -> void:
	var s := scale
	set_param("flash_color", Color(0.4, 1.0, 0.5))
	var tw := create_tween()
	tw.tween_method(func(f: float) -> void: set_param("flash", f), 0.0, 1.0, 0.15)
	tw.tween_property(self, "scale", s * 0.05, 0.25)
	tw.parallel().tween_property(self, "global_position", world_point, 0.25)
	tw.tween_callback(func() -> void:
		visible = false
		scale = s
		set_param("flash", 0.0)
		set_param("flash_color", Color.WHITE)
		done.emit())
