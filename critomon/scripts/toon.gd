class_name Toon
## Helpers that turn Kenney models and plain shapes into cartoon meshes.

const SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")

static var _mat_cache := {}
static var _mesh_cache := {}
static var _outline: ShaderMaterial


## A shared cartoon material for a Kenney texture.
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


## A shared cartoon material that is just one colour.
static func color(c: Color, opts := {}) -> ShaderMaterial:
	var key := "c" + str(c) + str(opts)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("use_tex", false)
	m.set_shader_parameter("tint", c)
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	_mat_cache[key] = m
	return m


## A fresh material (for things that flash or fade on their own).
static func unique(c: Color, tex: Texture2D = null) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("use_tex", tex != null)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
	return m


## The dark ink outline pass for characters.
static func outline() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE
	return _outline


static func _find_texture(mat: Material) -> Texture2D:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_texture
	if mat is ShaderMaterial:
		return (mat as ShaderMaterial).get_shader_parameter("albedo_tex")
	return null


## Load a Kenney model and merge all its meshes into one mesh (one draw call).
static func mesh(path: String) -> ArrayMesh:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var inst: Node = (load(path) as PackedScene).instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tex: Texture2D = null
	var mis := inst.find_children("*", "MeshInstance3D", true, false)
	if inst is MeshInstance3D:
		mis.append(inst)
	for n in mis:
		var mi := n as MeshInstance3D
		var xf := _xform_to(mi, inst) if mi != inst else Transform3D.IDENTITY
		for s in mi.mesh.get_surface_count():
			st.append_from(mi.mesh, s, xf)
			if tex == null:
				tex = _find_texture(mi.get_active_material(s))
	var m := st.commit()
	if tex:
		m.surface_set_material(0, material(tex))
	inst.free()
	_mesh_cache[path] = m
	return m


static func _xform_to(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## A MeshInstance3D of a Kenney model with the cartoon look.
static func model(path: String, opts := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := mesh(path)
	mi.mesh = m
	if not opts.is_empty():
		var tex := _find_texture(m.surface_get_material(0))
		if tex:
			mi.material_override = material(tex, opts)
	return mi
