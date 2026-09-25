class_name Dimension
extends Node3D
## A pocket world you reach through a portal. Each dimension lives far away
## from the home city and brings its own colours (shader globals), bots and
## places to respawn. Subclasses fill in build() and the settings below.

const CITY := "res://assets/city/"
const ROADS := "res://assets/roads/"
const IND := "res://assets/industrial/"
const SUB := "res://assets/suburban/"
const CARS := "res://assets/cars/"

var title := ""                       # shown on the chapter card, e.g. "NOIR-VERSE"
var intro: Array = []                 # narration lines when you arrive
var music := "city"
var palette := {}                     # shader global name -> value
var bot_plan: Array = []              # [["normal", 10], ["speedy", 3], ["big", 2]]
var radius := 160.0                   # webs stick to the sky only inside this circle
var sky_ceil := 110.0                 # ...and only up to this height (local)
var fall_y := -1.8                    # falling below this (local) sends you back
var fall_word := "WHOOPS!"
var start_pos := Vector3.ZERO         # local
var start_look := Vector3.FORWARD     # which way the camera faces on arrival
var arena := Vector3.ZERO             # local; the boss fights here (Glitch-Verse)
var bot_spots: Array[Vector3] = []    # local points in the air for bots
var safe_spots: Array[Vector3] = []   # local points on solid ground
var gate_spots: Array[Vector3] = []   # local open ground a portal fits on
var built := false

var rng := RandomNumberGenerator.new()
var _mm := {}
var _mm_opts := {}
var _mm_path := {}
var _tex_cache := {}
var _bodies: Node3D


func ensure_built() -> void:
	if built:
		return
	built = true
	_bodies = Node3D.new()
	_bodies.name = "Colliders"
	add_child(_bodies)
	build()
	_flush()
	if gate_spots.is_empty():
		gate_spots = safe_spots.duplicate()


## Subclasses make the place here.
func build() -> void:
	pass


## Nearest safe ground to a (global) point, in global space.
func safe_spot(near: Vector3) -> Vector3:
	var best := start_pos
	var bd := INF
	for s in safe_spots:
		var g := to_global(s)
		var d := Vector2(g.x - near.x, g.z - near.z).length()
		if d < bd:
			bd = d
			best = s
	return to_global(best) + Vector3(0, 1.5, 0)


func global_bot_spots() -> Array:
	var out := []
	for s in bot_spots:
		out.append(to_global(s))
	return out


# ------------------------------------------------------------------ kit

## Queue a Kenney model instance (batched into one MultiMesh per model).
func add_model(path: String, xf: Transform3D, opts := {}, custom := Color(1, 1, 1, 0)) -> void:
	var key := path + str(opts)
	if not _mm.has(key):
		_mm[key] = []
		_mm_opts[key] = opts
		_mm_path[key] = path
	(_mm[key] as Array).append([xf, custom])


func _flush() -> void:
	for key in _mm:
		var xfs: Array = _mm[key]
		var path: String = _mm_path[key]
		var mesh := Toon.merged_mesh(path)
		var opts: Dictionary = _mm_opts[key]
		if not opts.is_empty():
			mesh = mesh.duplicate() as ArrayMesh
			var tex: Texture2D = (mesh.surface_get_material(0) as ShaderMaterial).get_shader_parameter("albedo_tex")
			mesh.surface_set_material(0, Toon.material(tex, opts))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = opts.get("use_custom", 0.0) > 0.0
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for k in xfs.size():
			var e: Array = xfs[k]
			mm.set_instance_transform(k, e[0])
			if mm.use_custom_data:
				mm.set_instance_custom_data(k, e[1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = path.get_file().get_basename()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_mm.clear()


## Solid boxes (model space) placed with xf. Returns local AABBs.
func add_colliders(boxes: Array, xf: Transform3D) -> Array:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = xf
	var out := []
	for b in boxes:
		var bx := b as AABB
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bx.size
		cs.shape = sh
		cs.position = bx.get_center()
		body.add_child(cs)
		out.append(xf * bx)
	_bodies.add_child(body)
	return out


## A Kenney building with real collision. Returns {top, box} in local space.
func add_building(path: String, pos: Vector3, yaw: float, scale: Vector3, opts := {}, custom := Color(1, 1, 1, 0)) -> Dictionary:
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), pos)
	add_model(path, xf, opts, custom)
	var boxes := Toon.box_stack(Toon.merged_mesh(path))
	var local := add_colliders(boxes, xf)
	var top := -INF
	var main: AABB
	var base_area := 0.0
	for lb in local:
		var a := (lb as AABB).size.x * (lb as AABB).size.z
		if base_area == 0.0:
			base_area = a
		if (lb as AABB).end.y > top and a > base_area * 0.3:
			top = (lb as AABB).end.y
			main = lb
	return {"top": top, "box": main}


## A flat-coloured toon texture (cached).
func color_tex(c: Color) -> Texture2D:
	var key := c.to_html()
	if not _tex_cache.has(key):
		var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
		img.fill(c)
		_tex_cache[key] = ImageTexture.create_from_image(img)
	return _tex_cache[key]


## A solid coloured block (platform, wall, pillar).
func add_block(size: Vector3, pos: Vector3, col: Color, collide := true, tex: Texture2D = null, rot := Basis()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Toon.material(tex if tex else color_tex(col))
	mi.transform = Transform3D(rot, pos)
	add_child(mi)
	if collide:
		add_colliders([AABB(-size * 0.5, size)], Transform3D(rot, pos))
	return mi


## A round platform: top at pos.y, with a collider.
func add_disc(radius_m: float, height: float, pos: Vector3, col: Color, tex: Texture2D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius_m
	cm.bottom_radius = radius_m * 0.82
	cm.height = height
	cm.radial_segments = 32
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = Toon.material(tex if tex else color_tex(col))
	mi.position = pos - Vector3(0, height * 0.5, 0)
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius_m
	sh.height = height
	cs.shape = sh
	body.add_child(cs)
	body.position = mi.position
	_bodies.add_child(body)
	return mi


## A tall pole you can web-swing from.
func add_pole(pos: Vector3, height: float, radius_m: float, tex: Texture2D) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius_m
	cm.bottom_radius = radius_m
	cm.height = height
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = Toon.material(tex)
	mi.position = pos + Vector3(0, height * 0.5, 0)
	add_child(mi)
	add_colliders([AABB(Vector3(-radius_m, -height * 0.5, -radius_m), Vector3(radius_m * 2, height, radius_m * 2))], Transform3D(Basis(), mi.position))


## A sea far below (reuses the comic water shader with new colours).
func add_sea(y: float, deep: Color, shallow: Color, size := 2600.0) -> void:
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	sea.mesh = pm
	sea.position = Vector3(0, y, 0)
	var wm := ShaderMaterial.new()
	wm.shader = preload("res://shaders/water.gdshader")
	wm.set_shader_parameter("deep", deep)
	wm.set_shader_parameter("shallow", shallow)
	sea.material_override = wm
	add_child(sea)
