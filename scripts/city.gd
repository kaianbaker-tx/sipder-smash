extends Node3D
## Builds the whole comic-book city from Kenney kits:
## a 6x6 grid of blocks, streets, skyscrapers, rooftop junk, lamps,
## a park, a construction site, the Glitch Tower, water and a far skyline.

const U := 16.0            # one road tile = 16 m
const NB := 6              # blocks per side
const HALF := 12           # cells from the centre to the edge
const BS := 14.5           # building scale
const GROUND_Y := 0.32     # top of the road tiles

const CITY := "res://assets/city/"
const ROADS := "res://assets/roads/"
const IND := "res://assets/industrial/"
const SUB := "res://assets/suburban/"

var rng := RandomNumberGenerator.new()
var buildings: Array = []          # {pos, top, rect(Rect2 xz), boxes: [AABB world]}
var roof_spots: Array = []         # Vector3 points on roofs (tokens, bots)
var street_nodes: Array = []       # intersection centres (Vector3)
var tower_top := Vector3.ZERO
var tower_pos := Vector3.ZERO
var lamp_heads: Array = []

var _mm := {}                      # key -> Array[Transform3D]
var _mm_opts := {}
var _mm_path := {}
var _body_root: Node3D


func _ready() -> void:
	rng.seed = 7
	_body_root = Node3D.new()
	_body_root.name = "Colliders"
	add_child(_body_root)
	_build_ground()
	_build_streets()
	_build_blocks()
	_build_tower()
	_build_skyline()
	_build_signs()
	_flush_multimeshes()
	_build_lamp_glows()
	_build_steam()


# --------------------------------------------------------------------------- utils

func cell_pos(i: int, j: int) -> Vector3:
	return Vector3(i * U, 0.0, j * U)


func is_road(i: int) -> bool:
	return posmod(i, 4) == 0


# small props vanish far away; everything is batched per 3x3 city chunk so
# the GPU can skip chunks that are off screen
const SMALL := ["light-square", "traffic-light", "detail-tank", "chimney-small", "solar-panel-flat", "planter", "construction-cone", "construction-barrier", "construction-light", "tree-small", "tree-large", "shipping-container-a", "shipping-container-b", "shipping-container-c"]


func _chunk(p: Vector3) -> String:
	if p.length() > 260.0:
		return "far"
	var cx := clampi(int(floor((p.x + 210.0) / 140.0)), 0, 2)
	var cz := clampi(int(floor((p.z + 210.0) / 140.0)), 0, 2)
	return "%d_%d" % [cx, cz]


func _add(path: String, xf: Transform3D, opts := {}) -> void:
	var key := path + str(opts) + _chunk(xf.origin)
	if not _mm.has(key):
		_mm[key] = []
		_mm_opts[key] = opts
		_mm_path[key] = path
	(_mm[key] as Array).append(xf)


func _flush_multimeshes() -> void:
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
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for k in xfs.size():
			mm.set_instance_transform(k, xfs[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = path.get_file().get_basename()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if SMALL.has(mmi.name):
			mmi.visibility_range_end = 230.0
		add_child(mmi)
	_mm.clear()


func _static_boxes(boxes: Array, xf: Transform3D, layer := 1) -> Array:
	## Make a StaticBody3D from model-space AABBs, return world AABBs.
	var body := StaticBody3D.new()
	body.collision_layer = layer
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
	_body_root.add_child(body)
	return out


# --------------------------------------------------------------------------- ground

func _build_ground() -> void:
	# island slab
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	var ext := (HALF + 1.5) * U * 2.0
	sh.size = Vector3(ext, 10.0, ext)
	cs.shape = sh
	cs.position = Vector3(0, GROUND_Y - 5.0, 0)
	body.add_child(cs)
	_body_root.add_child(body)
	# promenade ring outside the outer road
	var tile := ROADS + "tile-low.glb"
	for i in range(-HALF - 1, HALF + 2):
		for j in range(-HALF - 1, HALF + 2):
			if absi(i) == HALF + 1 or absi(j) == HALF + 1:
				_add(tile, Transform3D(Basis.from_scale(Vector3(U, 1.0, U)), cell_pos(i, j)))
	# sea wall: a dark box around the island
	var wall := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(ext, 6.0, ext)
	wall.mesh = bm
	wall.position = Vector3(0, -3.05, 0)
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(0.42, 0.36, 0.6))
	wall.material_override = Toon.material(ImageTexture.create_from_image(img))
	add_child(wall)
	# water
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	pm.subdivide_depth = 0
	water.mesh = pm
	water.position = Vector3(0, -2.5, 0)
	var wm := ShaderMaterial.new()
	wm.shader = preload("res://shaders/water.gdshader")
	water.material_override = wm
	add_child(water)


# --------------------------------------------------------------------------- streets

func _build_streets() -> void:
	var straight := ROADS + "road-straight.glb"
	var cross := ROADS + "road-crossroad-path.glb"
	var crossing := ROADS + "road-crossing.glb"
	for i in range(-HALF, HALF + 1):
		for j in range(-HALF, HALF + 1):
			var ri := is_road(i)
			var rj := is_road(j)
			var p := cell_pos(i, j)
			var sc := Basis.from_scale(Vector3(U, 1.0, U))
			if ri and rj:
				_add(cross, Transform3D(sc, p))
				street_nodes.append(p)
			elif ri:
				# road runs along Z at this x
				var near_cross := is_road(j - 1) or is_road(j + 1)
				var b := Basis(Vector3.UP, 0.0) * sc
				_add(crossing if (near_cross and rng.randf() < 0.0) else straight, Transform3D(b, p))
			elif rj:
				var b2 := Basis(Vector3.UP, PI * 0.5) * sc
				_add(straight, Transform3D(b2, p))
	# traffic lights on intersection corners
	var tl := ROADS + "traffic-light.glb"
	for n in street_nodes:
		var np := n as Vector3
		if absf(np.x) > HALF * U - 1 or absf(np.z) > HALF * U - 1:
			continue
		for k in 4:
			var ang := k * PI * 0.5
			var corner := np + Vector3(cos(ang + PI / 4), 0, sin(ang + PI / 4)) * (U * 0.62)
			if rng.randf() < 0.5:
				var b := Basis(Vector3.UP, -ang + PI) * Basis.from_scale(Vector3.ONE * 16.0)
				_add(tl, Transform3D(b, corner + Vector3(0, GROUND_Y, 0)))


# --------------------------------------------------------------------------- blocks

const DOWNTOWN := ["building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c", "building-skyscraper-d", "building-skyscraper-e", "building-m", "building-l"]
const MIDTOWN := ["building-l", "building-m", "building-i", "building-f", "building-g", "building-skyscraper-a", "building-skyscraper-e", "building-n"]
const OUTER := ["building-a", "building-b", "building-c", "building-d", "building-f", "building-g", "building-h", "building-i"]
const WIDE := ["building-j", "building-k", "building-e"]

var special_blocks := {
	Vector2i(2, 2): "tower",
	Vector2i(4, 1): "park",
	Vector2i(1, 4): "construction",
	Vector2i(3, 4): "plaza",
}


func _build_blocks() -> void:
	var pave := ROADS + "tile-low.glb"
	for bx in NB:
		for bz in NB:
			var ci := -10 + bx * 4
			var cj := -10 + bz * 4
			var c := cell_pos(ci, cj)
			# block pavement as one big tile
			_add(pave, Transform3D(Basis.from_scale(Vector3(U * 3.0, 1.0, U * 3.0)), c))
			var kind: String = special_blocks.get(Vector2i(bx, bz), "city")
			var d := Vector2(bx - 2.5, bz - 2.5).length() / 3.54   # 0 centre .. 1 corner
			match kind:
				"tower":
					tower_pos = c
				"park":
					_build_park(c)
				"construction":
					_build_construction(c)
				"plaza":
					_build_plaza(c)
				_:
					_build_city_block(c, d)
			_build_block_edge(c)


func _pick(list: Array) -> String:
	return list[rng.randi() % list.size()]


func _build_city_block(c: Vector3, d: float) -> void:
	var q := 11.0       # quadrant centre offset
	var quads := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	var used := [false, false, false, false]
	# sometimes a wide building takes two quadrants
	if d > 0.55 and rng.randf() < 0.45:
		var name := _pick(WIDE)
		var along_x := rng.randf() < 0.5
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var pos := c + (Vector3(0, 0, side * q) if along_x else Vector3(side * q, 0, 0))
		var face := Vector3(0, 0, side) if along_x else Vector3(side, 0, 0)
		_place_building(name, pos, face, 1.0)
		if along_x:
			used[0 if side < 0 else 2] = true
			used[1 if side < 0 else 3] = true
		else:
			used[0 if side < 0 else 1] = true
			used[2 if side < 0 else 3] = true
	for k in 4:
		if used[k]:
			continue
		var qv: Vector2 = quads[k]
		var pos := c + Vector3(qv.x * q, 0, qv.y * q)
		var list: Array = DOWNTOWN if d < 0.4 else (MIDTOWN if d < 0.75 else OUTER)
		var name := _pick(list)
		# face the street on the longer open side
		var face := Vector3(qv.x, 0, 0) if rng.randf() < 0.5 else Vector3(0, 0, qv.y)
		var hs := 1.0
		if name.begins_with("building-skyscraper"):
			hs = rng.randf_range(1.0, 1.35) * (1.25 if d < 0.3 else 1.0)
		_place_building(name, pos, face, hs)


func _place_building(name: String, pos: Vector3, face: Vector3, hscale: float) -> void:
	var path := CITY + name + ".glb"
	var mesh := Toon.merged_mesh(path)
	var yaw := atan2(face.x, face.z)
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(BS, BS * hscale, BS))
	var xf := Transform3D(basis, pos + Vector3(0, GROUND_Y - 0.02, 0))
	_add_building_mesh(path, xf, rng.randi() % LOOKS.size())
	var boxes := Toon.box_stack(mesh)
	var world_boxes := _static_boxes(boxes, xf)
	var top := -INF
	var main_box: AABB
	var base_area := 0.0
	for wb in world_boxes:
		var a := (wb as AABB).size.x * (wb as AABB).size.z
		if base_area == 0.0:
			base_area = a
		if (wb as AABB).end.y > top and a > base_area * 0.3:
			top = (wb as AABB).end.y
			main_box = wb
	var info := {"pos": pos, "top": top, "box": main_box, "boxes": world_boxes, "name": name, "face": face}
	buildings.append(info)
	_decorate_roof(info)


# wall tint + accent hue shift: gives the white Kenney buildings Spider-Verse colours
const LOOKS := [
	[Color(1.0, 0.93, 0.88), 0.0],
	[Color(1.0, 0.62, 0.66), 0.9],
	[Color(0.72, 0.7, 1.0), 0.5],
	[Color(0.62, 0.95, 0.9), 0.08],
	[Color(1.0, 0.8, 0.5), 0.8],
]


func _add_building_mesh(path: String, xf: Transform3D, look: int) -> void:
	var l: Array = LOOKS[look]
	_add(path, xf, {"windows": 1.0, "wall_tint": l[0], "palette_shift": l[1]})


func _decorate_roof(info: Dictionary) -> void:
	var box: AABB = info.box
	var top: float = info.top
	var inner := box.grow(-2.2)
	if inner.size.x < 3.0 or inner.size.z < 3.0:
		return
	var spots := []
	for k in 6:
		var p := Vector3(rng.randf_range(inner.position.x, inner.end.x), top, rng.randf_range(inner.position.z, inner.end.z))
		if _roof_clear(info, p):
			spots.append(p)
	var n := 0
	for p in spots:
		var sp := p as Vector3
		var r := rng.randf()
		var yaw := rng.randi_range(0, 3) * PI * 0.5
		if n == 0 and r < 0.35 and info.name.begins_with("building-") and not info.name.begins_with("building-skyscraper"):
			_add(IND + "water-tower.glb", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * 5.5), sp))
		elif r < 0.55:
			_add(IND + "detail-tank.glb", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * 4.0), sp))
		elif r < 0.7:
			_add(IND + "chimney-small.glb", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * 4.0), sp))
		elif r < 0.82:
			_add(IND + "solar-panel-flat.glb", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * 6.0), sp))
		else:
			roof_spots.append(sp + Vector3(0, 1.5, 0))
		n += 1
		if n >= 2:
			break
	roof_spots.append(Vector3(box.get_center().x, top + 1.5, box.get_center().z))


func _roof_clear(info: Dictionary, p: Vector3) -> bool:
	for b in info.boxes:
		var bb := b as AABB
		if bb.end.y > info.top + 0.5 and p.x > bb.position.x - 2 and p.x < bb.end.x + 2 and p.z > bb.position.z - 2 and p.z < bb.end.z + 2:
			return false
	return true


func _build_block_edge(c: Vector3) -> void:
	# street lamps around the block, arms over the road
	var lamp := ROADS + "light-square.glb"
	var half := U * 1.5 - 0.8
	for side in 4:
		var ang := side * PI * 0.5
		var out := Vector3(sin(ang), 0, cos(ang))
		var along := Vector3(out.z, 0, -out.x)
		for k: int in [-1, 1]:
			var p := c + out * half + along * (k * U * 0.8)
			# the lamp arm points along -Z, so turn -Z toward the street
			var b := Basis(Vector3.UP, ang + PI) * Basis.from_scale(Vector3.ONE * 14.0)
			_add(lamp, Transform3D(b, p + Vector3(0, GROUND_Y, 0)))
			lamp_heads.append(p + out * 2.6 + Vector3(0, GROUND_Y + 8.1, 0))


func _build_park(c: Vector3) -> void:
	# grass patch
	var grass := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(U * 2.6, 0.3, U * 2.6)
	grass.mesh = bm
	grass.position = c + Vector3(0, GROUND_Y + 0.1, 0)
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(0.35, 0.78, 0.45))
	grass.material_override = Toon.material(ImageTexture.create_from_image(img))
	add_child(grass)
	for k in 22:
		var p := c + Vector3(rng.randf_range(-18, 18), GROUND_Y + 0.2, rng.randf_range(-18, 18))
		if p.distance_to(c) < 6.0:
			continue
		var t := SUB + ("tree-large.glb" if rng.randf() < 0.6 else "tree-small.glb")
		_add(t, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * rng.randf_range(13, 17)), p))
	for k in 6:
		var ang := k * TAU / 6.0
		_add(SUB + "planter.glb", Transform3D(Basis(Vector3.UP, ang) * Basis.from_scale(Vector3.ONE * 7.0), c + Vector3(cos(ang), 0, sin(ang)) * 4.5 + Vector3(0, GROUND_Y + 0.2, 0)))
	roof_spots.append(c + Vector3(0, 3, 0))


func _build_construction(c: Vector3) -> void:
	# a half-built skyscraper (industrial building) plus containers and cones
	_place_building("building-skyscraper-a", c + Vector3(-12, 0, -12), Vector3(0, 0, 1), 0.7)
	for k in 9:
		var p := c + Vector3(rng.randf_range(-4, 18), GROUND_Y, rng.randf_range(-4, 18))
		var name: String = ["shipping-container-a", "shipping-container-b", "shipping-container-c"][k % 3]
		var yaw := rng.randi_range(0, 1) * PI * 0.5
		var stack := 1 + int(rng.randf() < 0.4)
		for s in stack:
			var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * 8.0), p + Vector3(0, s * 2.8, 0))
			_add(IND + name + ".glb", xf)
			var bx := AABB(Vector3(-0.19, 0, -0.41), Vector3(0.37, 0.35, 0.82))
			_static_boxes([bx], xf)
	for k in 14:
		var p := c + Vector3(rng.randf_range(-22, 22), GROUND_Y, rng.randf_range(-22, 22))
		var name: String = ["construction-cone", "construction-barrier", "construction-light"][k % 3]
		_add(ROADS + name + ".glb", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * 11.0), p))


func _build_plaza(c: Vector3) -> void:
	# a big open plaza with a fountain-like tank and two short towers
	_place_building("building-n", c + Vector3(-10, 0, 12), Vector3(0, 0, -1), 1.0)
	_add(IND + "detail-tank-large.glb", Transform3D(Basis.from_scale(Vector3.ONE * 5.0), c + Vector3(8, GROUND_Y, -8)))
	_static_boxes([AABB(Vector3(-0.75, 0, -0.89), Vector3(1.51, 0.96, 1.65))], Transform3D(Basis.from_scale(Vector3.ONE * 5.0), c + Vector3(8, GROUND_Y, -8)))
	for k in 8:
		var p := c + Vector3(rng.randf_range(-20, 20), GROUND_Y + 0.2, rng.randf_range(-20, 0))
		_add(SUB + "tree-large.glb", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * 14.0), p))
	roof_spots.append(c + Vector3(0, 3, -10))


# --------------------------------------------------------------------------- tower

func _build_tower() -> void:
	# The Glitch Tower: the tallest thing in town, home of the boss.
	var c := tower_pos
	var path := CITY + "building-skyscraper-d.glb"
	var xf := Transform3D(Basis.from_scale(Vector3(22.0, 30.0, 22.0)), c + Vector3(0, GROUND_Y, 0))
	_add_building_mesh(path, xf, 2)
	var boxes := Toon.box_stack(Toon.merged_mesh(path))
	var wb := _static_boxes(boxes, xf)
	var top := -INF
	var main: AABB
	for b in wb:
		if (b as AABB).end.y > top and (b as AABB).size.x > 10:
			top = (b as AABB).end.y
			main = b
	tower_top = Vector3(c.x, top, c.z)
	buildings.append({"pos": c, "top": top, "box": main, "boxes": wb, "name": "tower"})
	# helipad ring on the roof
	var pad := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 9.0
	cyl.bottom_radius = 9.0
	cyl.height = 0.6
	pad.mesh = cyl
	pad.position = tower_top + Vector3(0, 0.3, 0)
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(1.0, 0.85, 0.2))
	pad.material_override = Toon.material(ImageTexture.create_from_image(img))
	add_child(pad)
	# a giant spider emblem painted on the helipad
	var emblem := MeshInstance3D.new()
	var em := PlaneMesh.new()
	em.size = Vector2(13, 13)
	emblem.mesh = em
	var emat := StandardMaterial3D.new()
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.albedo_texture = preload("res://assets/ui/token.png")
	emat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	emblem.material_override = emat
	emblem.position = tower_top + Vector3(0, 0.64, 0)
	add_child(emblem)
	var pb := StaticBody3D.new()
	var pcs := CollisionShape3D.new()
	var psh := CylinderShape3D.new()
	psh.radius = 9.0
	psh.height = 0.6
	pcs.shape = psh
	pb.add_child(pcs)
	pb.position = pad.position
	_body_root.add_child(pb)
	# the four corner skyscrapers around the tower
	for k in 4:
		var ang := k * PI * 0.5 + PI * 0.25
		var p := c + Vector3(cos(ang), 0, sin(ang)) * 17.0
		if k % 2 == 0:
			_place_building("building-skyscraper-b", p, (p - c).normalized(), 0.7)


# --------------------------------------------------------------------------- skyline

func _build_skyline() -> void:
	# a ring of far-away towers across the river, lost in the pink haze
	var names := ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "l", "m", "wide-a", "wide-b"]
	for k in 150:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(330.0, 470.0)
		var p := Vector3(cos(ang) * r, -2.0, sin(ang) * r)
		var n: String = names[rng.randi() % names.size()]
		var s := rng.randf_range(34.0, 52.0)
		var h := rng.randf_range(0.7, 1.6)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * h, s)), p)
		_add(CITY + "low-detail-building-" + n + ".glb", xf)


# --------------------------------------------------------------------------- signs

var _sign_xf := {}   # texture path -> Array[Transform3D]


func _sign(tex: String, xf: Transform3D) -> void:
	if not _sign_xf.has(tex):
		_sign_xf[tex] = []
	(_sign_xf[tex] as Array).append(xf)


func _build_signs() -> void:
	var frame_img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	frame_img.fill(Color(0.2, 0.14, 0.3))
	var frame_mat := Toon.material(ImageTexture.create_from_image(frame_img))
	var frames: Array = []
	var n_sign := 0
	for b in buildings:
		var info := b as Dictionary
		if info.name == "tower" or not info.has("face"):
			continue
		var face: Vector3 = info.face
		var base: AABB = info.boxes[0]
		var side := Vector3(face.z, 0, -face.x)
		var half_d := absf(face.x) * base.size.x * 0.5 + absf(face.z) * base.size.z * 0.5
		var half_w := absf(side.x) * base.size.x * 0.5 + absf(side.z) * base.size.z * 0.5
		var front := Vector3(base.get_center().x, 0, base.get_center().z) + face * (half_d + 0.25)
		var yaw := atan2(face.x, face.z)
		# shop sign above the ground floor
		if rng.randf() < 0.55 and half_w > 5.0:
			var w := minf(half_w * 1.2, 9.0)
			var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(w, w * 0.375, 1)), front + Vector3(0, 7.2, 0) + side * rng.randf_range(-2.0, 2.0))
			_sign("res://assets/ui/sign_%d.png" % (n_sign % 10), xf)
			n_sign += 1
		# graffiti on a side wall, down low
		if rng.randf() < 0.35:
			var gside := side if rng.randf() < 0.5 else -side
			var gd := absf(gside.x) * base.size.x * 0.5 + absf(gside.z) * base.size.z * 0.5
			var gp := Vector3(base.get_center().x, 0, base.get_center().z) + gside * (gd + 0.2) + face * rng.randf_range(-4.0, 4.0)
			var gyaw := atan2(gside.x, gside.z)
			var xf2 := Transform3D(Basis(Vector3.UP, gyaw) * Basis.from_scale(Vector3(7.0, 3.5, 1)), gp + Vector3(0, 2.6, 0))
			_sign("res://assets/ui/graffiti_%d.png" % rng.randi_range(0, 4), xf2)
		# rooftop billboard on low buildings
		var top: float = info.top
		if top < 45.0 and rng.randf() < 0.4:
			var box: AABB = info.box
			var bd := absf(face.x) * box.size.x * 0.5 + absf(face.z) * box.size.z * 0.5
			var bp := Vector3(box.get_center().x, top, box.get_center().z) + face * (bd - 2.0)
			var bw := 12.0
			var bxf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(bw, bw * 0.375, 1)), bp + Vector3(0, 5.2, 0) + face * 0.35)
			_sign("res://assets/ui/sign_%d.png" % (n_sign % 10), bxf)
			n_sign += 1
			frames.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(bw + 0.8, bw * 0.375 + 0.8, 0.6)), bp + Vector3(0, 5.2, 0)))
			for k: int in [-1, 1]:
				frames.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(0.5, 3.4, 0.5)), bp + side * (k * bw * 0.35) + Vector3(0, 1.7, 0)))
	# the signs: one multimesh per picture
	var sh: Shader = preload("res://shaders/sign.gdshader")
	for tex in _sign_xf:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("tex", load(tex))
		mat.set_shader_parameter("flicker", 0.0 if (tex as String).contains("graffiti") else 1.0)
		var qm := QuadMesh.new()
		qm.size = Vector2(1, 1)
		qm.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = qm
		var xs: Array = _sign_xf[tex]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
	# billboard frames
	if not frames.is_empty():
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		bm.material = frame_mat
		var fm := MultiMesh.new()
		fm.transform_format = MultiMesh.TRANSFORM_3D
		fm.mesh = bm
		fm.instance_count = frames.size()
		for i in frames.size():
			fm.set_instance_transform(i, frames[i])
		var fmi := MultiMeshInstance3D.new()
		fmi.multimesh = fm
		add_child(fmi)


# --------------------------------------------------------------------------- steam

func _build_steam() -> void:
	# manhole covers puffing comic steam clouds
	var cover_img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	cover_img.fill(Color(0.25, 0.2, 0.32))
	var cover_mat := Toon.material(ImageTexture.create_from_image(cover_img))
	var puff_mat := StandardMaterial3D.new()
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_mat.vertex_color_use_as_albedo = true
	var puff := SphereMesh.new()
	puff.radius = 0.7
	puff.height = 1.4
	puff.radial_segments = 8
	puff.rings = 4
	puff.material = puff_mat
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 1.0))
	grad.set_color(1, Color(0.8, 0.7, 0.95))
	for k in 16:
		var ri := rng.randi_range(-3, 3) * 4
		var along := rng.randi_range(-11, 11)
		if is_road(along):
			along += 1
		var p := cell_pos(ri, along) if k % 2 == 0 else cell_pos(along, ri)
		p += Vector3(rng.randf_range(-2.5, 2.5), GROUND_Y, rng.randf_range(-2.5, 2.5)) * Vector3(1, 1, 1)
		var cover := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.9
		cyl.bottom_radius = 0.9
		cyl.height = 0.08
		cyl.radial_segments = 16
		cover.mesh = cyl
		cover.material_override = cover_mat
		cover.position = p + Vector3(0, 0.02, 0)
		add_child(cover)
		var ps := CPUParticles3D.new()
		ps.mesh = puff
		ps.amount = 10
		ps.lifetime = 3.2
		ps.preprocess = 3.0
		ps.direction = Vector3.UP
		ps.spread = 12.0
		ps.initial_velocity_min = 1.5
		ps.initial_velocity_max = 2.6
		ps.gravity = Vector3(0.4, 0.2, 0)
		ps.scale_amount_min = 0.8
		ps.scale_amount_max = 1.8
		ps.scale_amount_curve = curve
		ps.color_ramp = grad
		ps.visibility_range_end = 160.0
		ps.position = p
		add_child(ps)


# --------------------------------------------------------------------------- lamp glows

func _build_lamp_glows() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
global uniform float dot_size;
uniform vec4 col : source_color = vec4(1.0, 0.72, 0.4, 1.0);
void vertex() {
	// billboard
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.12, 0.2, r);
	vec2 p = FRAGCOORD.xy / dot_size;
	p = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * p;
	float halo = 1.0 - smoothstep(0.2, 1.0, r);
	float d = 1.0 - step(sqrt(halo * 0.9 / 3.14159), length(fract(p) - 0.5));
	ALBEDO = col.rgb * (core * 1.2 + d * halo * 0.55);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var qm := QuadMesh.new()
	qm.size = Vector2(5.0, 5.0)
	qm.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = qm
	mm.instance_count = lamp_heads.size()
	for k in lamp_heads.size():
		mm.set_instance_transform(k, Transform3D(Basis(), lamp_heads[k]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "LampGlows"
	add_child(mmi)
