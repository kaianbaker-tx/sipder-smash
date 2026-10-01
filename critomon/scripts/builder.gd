class_name Builder
extends Node3D
## Shared tools for building places in code: Kenney props with colliders,
## round cartoon trees, fences, signs, walls and MultiMesh batches.
## world.gd (outside), lab.gd (inside the lab) and battle_stage.gd use it.

var statics: StaticBody3D
# things you can talk to or look at: {"pos", "r", "call", "label"}
var interactables: Array = []
var _batches := {}           # mesh key -> {"mesh", "xforms", "customs", "mat"}

static var _tree_meshes: Array = []


func _init() -> void:
	statics = StaticBody3D.new()
	statics.collision_layer = 1
	statics.collision_mask = 0
	add_child(statics)


# ------------------------------------------------------------------ colliders

func box_wall(center: Vector3, size: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = center
	cs.rotation.y = yaw
	statics.add_child(cs)


func cyl_wall(center: Vector3, r: float, h := 3.0) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	cs.position = center + Vector3(0, h * 0.5, 0)
	statics.add_child(cs)


# ------------------------------------------------------------------ props

## A Kenney model with the cartoon look. collide: "box", "cyl" or "".
func prop(path: String, pos: Vector3, yaw := 0.0, scl := 1.0, opts := {}, collide := "box", parent: Node3D = null) -> MeshInstance3D:
	var mi := Toon.model(path, opts)
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * scl
	(parent if parent else self).add_child(mi)
	if collide != "":
		var a := mi.mesh.get_aabb()
		var c := a.get_center() * scl
		var sz := a.size * scl
		c = c.rotated(Vector3.UP, yaw)
		if collide == "cyl":
			cyl_wall(pos + Vector3(c.x, 0, c.z), maxf(sz.x, sz.z) * 0.45, sz.y)
		else:
			box_wall(pos + c, sz * Vector3(0.96, 1, 0.96), yaw)
	return mi


## Add a copy of a mesh to a MultiMesh batch (drawn together at the end).
func batch(key: String, mesh: Mesh, xf: Transform3D, mat: Material = null, custom := Color.WHITE) -> void:
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "xforms": [], "customs": [], "mat": mat}
	_batches[key].xforms.append(xf)
	_batches[key].customs.append(custom)


func flush_batches() -> void:
	for key in _batches:
		var b: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = b.mesh
		mm.instance_count = b.xforms.size()
		for i in b.xforms.size():
			mm.set_instance_transform(i, b.xforms[i])
			mm.set_instance_custom_data(i, b.customs[i])
			mm.set_instance_color(i, Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if b.mat:
			mmi.material_override = b.mat
		add_child(mmi)
	_batches.clear()


# ------------------------------------------------------------------ trees

## Round cartoon trees: a trunk and a puffy crown, one mesh with vertex colours.
static func tree_mesh(kind: int) -> ArrayMesh:
	if _tree_meshes.is_empty():
		for k in 3:
			_tree_meshes.append(_make_tree(k))
	return _tree_meshes[kind % 3]


static func _add_shape(st: SurfaceTool, m: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arr := m.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var base := Basis(xf.basis).inverse().transposed()
	for i in idx:
		st.set_color(col)
		st.set_normal((base * norms[i]).normalized())
		st.add_vertex(xf * verts[i])


static func _make_tree(kind: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.32
	trunk.height = 2.2
	trunk.radial_segments = 8
	trunk.rings = 1
	var bark := Color(0.55, 0.36, 0.24)
	_add_shape(st, trunk, Transform3D(Basis(), Vector3(0, 1.1, 0)), bark)
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 14
	ball.rings = 7
	var g1 := Color(0.33, 0.72, 0.36)
	var g2 := Color(0.42, 0.8, 0.38)
	var g3 := Color(0.28, 0.62, 0.34)
	match kind:
		0:  # big round oak
			_add_shape(st, ball, Transform3D(Basis().scaled(Vector3(1.9, 1.6, 1.9)), Vector3(0, 3.3, 0)), g1)
			_add_shape(st, ball, Transform3D(Basis().scaled(Vector3(1.2, 1.1, 1.2)), Vector3(0.9, 4.2, 0.3)), g2)
			_add_shape(st, ball, Transform3D(Basis().scaled(Vector3(1.1, 1.0, 1.1)), Vector3(-0.8, 3.9, -0.5)), g2)
		1:  # tall layered pine
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.0
			cone.height = 1.0
			cone.radial_segments = 10
			cone.rings = 1
			for i in 3:
				var s := 2.1 - i * 0.55
				_add_shape(st, cone, Transform3D(Basis().scaled(Vector3(s, 2.0, s)), Vector3(0, 2.4 + i * 1.25, 0)), g3.lerp(g2, i * 0.3))
		2:  # bushy two-ball tree
			_add_shape(st, ball, Transform3D(Basis().scaled(Vector3(1.6, 1.4, 1.6)), Vector3(0, 2.9, 0)), g2)
			_add_shape(st, ball, Transform3D(Basis().scaled(Vector3(1.2, 1.1, 1.2)), Vector3(0.2, 4.1, 0.1)), g1)
	return st.commit()


static func tree_material() -> ShaderMaterial:
	return Toon.color(Color.WHITE, {"use_vcol": true, "use_custom": true, "rim": 0.25})


## A round tree. solid: add a collider.
func tree(pos: Vector3, kind := -1, scl := 1.0, solid := true) -> void:
	if kind < 0:
		kind = randi() % 3
	var yaw := randf() * TAU
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scl), pos)
	var tint := Color(1, 1, 1).lerp(Color(0.85, 1.0, 0.8), randf())
	batch("tree%d" % kind, tree_mesh(kind), xf, tree_material(), tint)
	if solid:
		cyl_wall(pos, 0.5 * scl, 4.0)


## A row of trees from a to b (a forest edge), with a wall behind it.
func tree_row(a: Vector3, b: Vector3, spacing := 3.2, depth := 2, wall := true) -> void:
	var d := b - a
	var n := int(d.length() / spacing) + 1
	var side := Vector3(-d.z, 0, d.x).normalized()
	for row in depth:
		for i in n:
			var t := (i + (0.5 if row % 2 == 1 else 0.0)) / maxf(1.0, n - 1)
			if t > 1.0:
				continue
			var p := a.lerp(b, t) + side * row * 2.8 + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
			tree(p, -1, randf_range(0.85, 1.25), false)
	if wall:
		var c := (a + b) * 0.5 + side * (depth - 1) * 1.4
		box_wall(c + Vector3(0, 2, 0), Vector3(d.length() + 2.0, 4, depth * 2.8 + 1.0), atan2(-d.z, d.x))


# ------------------------------------------------------------------ bits

func fence_line(a: Vector3, b: Vector3, low := true, solid := true) -> void:
	var path := "res://assets/suburban/fence-low.glb" if low else "res://assets/suburban/fence.glb"
	var m := Toon.mesh(path)
	var scl := 3.2
	var seg := m.get_aabb().size.x * scl
	var d := b - a
	var n := maxi(1, int(round(d.length() / seg)))
	var yaw := atan2(-d.z, d.x)
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		batch(path, m, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scl), p))
	if solid:
		box_wall((a + b) * 0.5 + Vector3(0, 0.6, 0), Vector3(d.length(), 1.2, 0.4), yaw)


## Words floating in the world (signs, lab name).
func words(text: String, pos: Vector3, yaw := 0.0, size := 64, col := Color.WHITE, outline := Color(0.1, 0.08, 0.2)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = preload("res://assets/fonts/lilita_one_regular.ttf")
	l.font_size = size
	l.outline_size = int(size * 0.22)
	l.modulate = col
	l.outline_modulate = outline
	l.pixel_size = 0.01
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = false
	l.shaded = false
	add_child(l)
	return l


## A little wooden sign post you can read.
func signpost(pos: Vector3, yaw: float, text: String) -> void:
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.18, 1.2, 0.18)
	post.mesh = pm
	post.material_override = Toon.color(Color(0.55, 0.36, 0.22))
	post.position = pos + Vector3(0, 0.6, 0)
	add_child(post)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.3, 0.75, 0.12)
	board.mesh = bm
	board.material_override = Toon.color(Color(0.86, 0.66, 0.42))
	board.position = pos + Vector3(0, 1.3, 0)
	board.rotation.y = yaw
	add_child(board)
	cyl_wall(pos, 0.35, 1.5)
	interactables.append({"pos": pos, "r": 1.6, "label": "READ", "text": text})


func box(size: Vector3, pos: Vector3, col: Color, yaw := 0.0, parent: Node3D = null, opts := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Toon.color(col, opts)
	mi.position = pos
	mi.rotation.y = yaw
	(parent if parent else self).add_child(mi)
	return mi


func disc(radius: float, height: float, pos: Vector3, col: Color, parent: Node3D = null, opts := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 24
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = Toon.color(col, opts)
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


## Little flowers dotted around a spot.
func flowers(center: Vector3, radius: float, count: int) -> void:
	var cols := [Color(1, 0.4, 0.5), Color(1, 0.85, 0.3), Color(1, 1, 1), Color(0.7, 0.5, 1.0), Color(1, 0.6, 0.2)]
	for i in count:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		var c: Color = cols[randi() % cols.size()]
		batch("flower", _flower_mesh(), Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * randf_range(0.8, 1.3)), p), Toon.color(Color.WHITE, {"use_vcol": true, "use_custom": true, "rim": 0.0}), c)


static var _flower: ArrayMesh


static func _flower_mesh() -> ArrayMesh:
	if _flower:
		return _flower
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.02
	stem.bottom_radius = 0.02
	stem.height = 0.3
	stem.radial_segments = 4
	stem.rings = 1
	# stems are green; the petals get the instance colour, so paint petals
	# white and the stem a green that the white tint leaves alone
	_add_shape(st, stem, Transform3D(Basis(), Vector3(0, 0.15, 0)), Color(0.35, 0.7, 0.3))
	var petal := SphereMesh.new()
	petal.radius = 1.0
	petal.height = 2.0
	petal.radial_segments = 6
	petal.rings = 3
	for i in 5:
		var a := i * TAU / 5.0
		_add_shape(st, petal, Transform3D(Basis().scaled(Vector3(0.07, 0.025, 0.07)), Vector3(cos(a) * 0.07, 0.32, sin(a) * 0.07)), Color.WHITE)
	_add_shape(st, petal, Transform3D(Basis().scaled(Vector3(0.045, 0.035, 0.045)), Vector3(0, 0.335, 0)), Color(1.0, 0.85, 0.2))
	_flower = st.commit()
	return _flower
