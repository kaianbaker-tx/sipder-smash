class_name Toon
## Helpers that turn Kenney models into comic-book (toon shader) meshes.

const SHADER := preload("res://shaders/toon.gdshader")

static var _mat_cache := {}
static var _mesh_cache := {}
static var _boxes_cache := {}


## A toon material for a texture. Materials are shared so the GPU can batch.
static func material(tex: Texture2D, opts := {}) -> ShaderMaterial:
	var key := str(tex.get_rid()) + str(opts)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo_tex", tex)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	_mat_cache[key] = m
	return m


## A fresh (unshared) material, for things that flash or glitch on their own.
static func unique_material(tex: Texture2D, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo_tex", tex)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	return m


static func _find_texture(mat: Material) -> Texture2D:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_texture
	if mat is ShaderMaterial:
		return (mat as ShaderMaterial).get_shader_parameter("albedo_tex")
	return null


## Swap every material under `root` for the toon version.
static func apply(root: Node, opts := {}) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src := m.get_active_material(s)
			var tex := _find_texture(src)
			if tex:
				m.set_surface_override_material(s, material(tex, opts))
	if root is MeshInstance3D:
		var m := root as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var tex := _find_texture(m.get_active_material(s))
			if tex:
				m.set_surface_override_material(s, material(tex, opts))


## Load a Kenney scene and merge all its meshes into one ArrayMesh (one draw call).
static func merged_mesh(path: String) -> ArrayMesh:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var inst: Node = (load(path) as PackedScene).instantiate()
	# a single mesh with no offset: keep it as-is so Godot's automatic
	# level-of-detail versions survive (far buildings get cheaper)
	var mis := inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		mis.append(inst)
	if mis.size() == 1:
		var only := mis[0] as MeshInstance3D
		var xf0 := _xform_to(only, inst) if only != inst else Transform3D.IDENTITY
		if xf0.is_equal_approx(Transform3D.IDENTITY) and only.mesh.get_surface_count() == 1:
			var m0 := only.mesh.duplicate() as ArrayMesh
			var t0 := _find_texture(only.get_active_material(0))
			if t0:
				m0.surface_set_material(0, material(t0))
			inst.free()
			_mesh_cache[path] = m0
			return m0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tex: Texture2D = null
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf := _xform_to(mi, inst)
		for s in mi.mesh.get_surface_count():
			st.append_from(mi.mesh, s, xf)
			if tex == null:
				tex = _find_texture(mi.get_active_material(s))
	var mesh := st.commit()
	if tex:
		mesh.surface_set_material(0, material(tex))
	inst.free()
	_mesh_cache[path] = mesh
	return mesh


static func _xform_to(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Approximate a building mesh with a stack of boxes (for collision and roofs).
## Returns an Array of AABBs in model space, bottom to top.
static func box_stack(mesh: Mesh, slice := 0.04, min_size := 0.12) -> Array:
	var key := mesh.get_rid()
	if _boxes_cache.has(key):
		return _boxes_cache[key]
	var faces := mesh.get_faces()
	var aabb := mesh.get_aabb()
	var n_slices := int(ceil(aabb.size.y / slice)) + 1
	var mins: Array[Vector2] = []
	var maxs: Array[Vector2] = []
	for i in n_slices:
		mins.append(Vector2(INF, INF))
		maxs.append(Vector2(-INF, -INF))
	for t in range(0, faces.size(), 3):
		var a := faces[t]
		var b := faces[t + 1]
		var c := faces[t + 2]
		var y0 := minf(a.y, minf(b.y, c.y)) - aabb.position.y
		var y1 := maxf(a.y, maxf(b.y, c.y)) - aabb.position.y
		var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
		var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
		# skip flat faces spanning big areas at one height only if they are tiny in y (roof caps count)
		var i0 := clampi(int(floor(y0 / slice)), 0, n_slices - 1)
		var i1 := clampi(int(ceil(y1 / slice)) - 1, i0, n_slices - 1)
		for i in range(i0, i1 + 1):
			mins[i] = mins[i].min(lo)
			maxs[i] = maxs[i].max(hi)
	# merge similar slices into boxes
	var boxes: Array = []
	var cur_lo := Vector2.ZERO
	var cur_hi := Vector2.ZERO
	var cur_y0 := 0.0
	var open := false
	for i in n_slices:
		var valid := mins[i].x < INF and (maxs[i] - mins[i]).x > min_size and (maxs[i] - mins[i]).y > min_size
		var y := aabb.position.y + i * slice
		if not valid:
			if open:
				boxes.append(AABB(Vector3(cur_lo.x, cur_y0, cur_lo.y), Vector3(cur_hi.x - cur_lo.x, y - cur_y0, cur_hi.y - cur_lo.y)))
				open = false
			continue
		if open and (mins[i] - cur_lo).length() < 0.06 and (maxs[i] - cur_hi).length() < 0.06:
			cur_lo = cur_lo.min(mins[i])
			cur_hi = cur_hi.max(maxs[i])
			continue
		if open:
			boxes.append(AABB(Vector3(cur_lo.x, cur_y0, cur_lo.y), Vector3(cur_hi.x - cur_lo.x, y - cur_y0, cur_hi.y - cur_lo.y)))
		cur_lo = mins[i]
		cur_hi = maxs[i]
		cur_y0 = y
		open = true
	if open:
		var ytop := aabb.position.y + aabb.size.y
		boxes.append(AABB(Vector3(cur_lo.x, cur_y0, cur_lo.y), Vector3(cur_hi.x - cur_lo.x, ytop - cur_y0, cur_hi.y - cur_lo.y)))
	# drop very thin top slivers (antennas, railings)
	var out: Array = []
	for bx in boxes:
		if (bx as AABB).size.y > 0.02:
			out.append(bx)
	_boxes_cache[key] = out
	return out
