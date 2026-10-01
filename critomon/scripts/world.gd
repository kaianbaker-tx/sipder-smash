class_name World
extends Builder
## The outside world, built in code. North is -Z.
##   Birchwood Town (around 0, 0): your house, the rival's house, the fountain
##   and Professor Birch's Lab.
##   Route 1 (z -36 to -200): a winding path, tall grass, a pond, a camp and
##   trainers.
##   The Arena (0, -212): where the rival waits for the big battle.

const MAP_RECT := Rect2(-60, -235, 120, 280)   # x, z, width, depth
const PX := 2.0                                  # map pixels per metre
const LAB_DOOR := Vector3(12, 0, -10.2)
const LAB_POS := Vector3(12, 0, -16)

# tall grass: centre and half size (x, z), and who lives there
const GRASS := [
	{"c": Vector2(-12, -58), "h": Vector2(7, 6), "mons": [["zappit", 3, 4], ["fluffle", 3, 4], ["buzzlet", 2, 4]]},
	{"c": Vector2(20, -72), "h": Vector2(6, 8), "mons": [["buzzlet", 3, 5], ["zappit", 3, 5], ["fluffle", 4, 5]]},
	{"c": Vector2(-16, -106), "h": Vector2(8, 7), "mons": [["pebblit", 4, 6], ["fluffle", 4, 6], ["buzzlet", 4, 5]]},
	{"c": Vector2(1, -144), "h": Vector2(10, 5), "mons": [["pebblit", 5, 7], ["zappit", 5, 7], ["fluffle", 5, 7]]},
	{"c": Vector2(-18, -180), "h": Vector2(7, 6), "mons": [["pebblit", 6, 8], ["zappit", 6, 8], ["buzzlet", 6, 8]]},
]

const ROUTE := [Vector2(0, -6), Vector2(0, -36), Vector2(0, -48), Vector2(8, -60), Vector2(8, -82),
	Vector2(-4, -98), Vector2(-4, -120), Vector2(6, -134), Vector2(6, -156), Vector2(-2, -172),
	Vector2(0, -190), Vector2(0, -204)]

var map_img: Image
var ground: MeshInstance3D
var clouds: Array[Node3D] = []


func build() -> void:
	seed(7)
	_paint_map()
	_make_ground()
	_town()
	_route()
	_arena()
	_borders()
	_clouds()
	flush_batches()


# ------------------------------------------------------------------ map

func _px(p: Vector2) -> Vector2:
	return (p - MAP_RECT.position) * PX


## Paint into one colour channel (0 r path, 1 g dark grass, 2 b sand).
func _paint_seg(a: Vector2, b: Vector2, r: float, ch: int) -> void:
	var pa := _px(a)
	var pb := _px(b)
	var rp := r * PX
	var soft := 1.2 * PX
	var lo := pa.min(pb) - Vector2.ONE * (rp + soft)
	var hi := pa.max(pb) + Vector2.ONE * (rp + soft)
	var w := map_img.get_width()
	var h := map_img.get_height()
	for y in range(maxi(0, int(lo.y)), mini(h, int(hi.y) + 1)):
		for x in range(maxi(0, int(lo.x)), mini(w, int(hi.x) + 1)):
			var p := Vector2(x + 0.5, y + 0.5)
			var d := Geometry2D.get_closest_point_to_segment(p, pa, pb).distance_to(p)
			var v := clampf((rp + soft - d) / (2.0 * soft), 0.0, 1.0)
			if v <= 0.0:
				continue
			var c := map_img.get_pixel(x, y)
			c[ch] = maxf(c[ch], v)
			map_img.set_pixel(x, y, c)


func _paint_rect(c: Vector2, half: Vector2, ch: int) -> void:
	# a rounded rectangle: a fat segment through the middle
	var r := minf(half.x, half.y)
	if half.x > half.y:
		_paint_seg(c - Vector2(half.x - r, 0), c + Vector2(half.x - r, 0), r, ch)
	else:
		_paint_seg(c - Vector2(0, half.y - r), c + Vector2(0, half.y - r), r, ch)


func _paint_line(pts: Array, r: float) -> void:
	for i in pts.size() - 1:
		_paint_seg(pts[i], pts[i + 1], r, 0)


func _paint_map() -> void:
	map_img = Image.create(int(MAP_RECT.size.x * PX), int(MAP_RECT.size.y * PX), false, Image.FORMAT_RGB8)
	map_img.fill(Color.BLACK)
	# town paths
	_paint_line([Vector2(-16, 13), Vector2(-16, 7), Vector2(-7, 3)], 1.6)
	_paint_line([Vector2(16, 13), Vector2(16, 7), Vector2(7, 3)], 1.6)
	_paint_seg(Vector2(0, 2), Vector2(0, 2), 8.5, 0)
	_paint_line([Vector2(4, -4), Vector2(12, -9), Vector2(12, -11)], 2.0)
	_paint_line([Vector2(-17, -11), Vector2(-17, -7), Vector2(-7, -3)], 1.4)
	_paint_line([Vector2(-26, -1), Vector2(-8, 1)], 1.4)
	_paint_line([Vector2(26, -1), Vector2(8, 1)], 1.4)
	# Route 1
	_paint_line(ROUTE, 2.1)
	_paint_line([Vector2(6, -146), Vector2(20, -146)], 1.6)
	for g in GRASS:
		_paint_rect(g.c, g.h + Vector2(0.6, 0.6), 1)
	# pond sand and arena floor
	_paint_seg(Vector2(22, -108), Vector2(22, -108), 9.5, 2)
	_paint_seg(Vector2(-4, -212), Vector2(4, -212), 12.0, 2)
	_paint_seg(Vector2(22, -146), Vector2(22, -146), 7.0, 2)


func _make_ground() -> void:
	var tex := ImageTexture.create_from_image(map_img)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	mat.set_shader_parameter("map_tex", tex)
	mat.set_shader_parameter("map_rect", Vector4(MAP_RECT.position.x, MAP_RECT.position.y, MAP_RECT.size.x, MAP_RECT.size.y))
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(MAP_RECT.size.x + 200, MAP_RECT.size.y + 200)
	ground.mesh = pm
	ground.position = Vector3(MAP_RECT.get_center().x, 0, MAP_RECT.get_center().y)
	ground.material_override = mat
	add_child(ground)
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	statics.add_child(cs)


# ------------------------------------------------------------------ town

func _house(path: String, pos: Vector3, yaw: float, scl: float, roof := 0.0, text := "", walls := Color.WHITE) -> void:
	prop(path, pos, yaw, scl, {"roof_hue": roof, "warm_tint": walls, "rim": 0.2})
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var depth := Toon.mesh(path).get_aabb().size.z * scl
	var door := pos + fwd * (depth * 0.5 + 0.8)
	if text != "":
		interactables.append({"pos": door, "r": 1.8, "label": "KNOCK", "text": text})
	# a mailbox by the path
	var side := Vector3(fwd.z, 0, -fwd.x)
	var mb := pos + fwd * (depth * 0.5 + 2.6) + side * 2.6
	box(Vector3(0.1, 1.0, 0.1), mb + Vector3(0, 0.5, 0), Color(0.5, 0.35, 0.25))
	box(Vector3(0.35, 0.3, 0.55), mb + Vector3(0, 1.1, 0), Color(0.3, 0.5, 0.95), yaw)


func _town() -> void:
	# your house and the rival's house face the square
	_house("res://assets/suburban/building-type-a.glb", Vector3(-16, 0, 17), PI, 6.5, 0.0, "MOM: Go see Professor Birch at his Lab! He has a surprise for you!")
	_house("res://assets/suburban/building-type-e.glb", Vector3(16, 0, 17), PI, 6.5, 0.4, "It's JAX's house. Nobody is home.", Color(1.0, 0.95, 0.85))
	_house("res://assets/suburban/building-type-k.glb", Vector3(-17, 0, -15), 0.0, 6.5, -0.28, "A sign says: GONE FISHING.", Color(0.95, 1.0, 0.95))
	_house("res://assets/suburban/building-type-c.glb", Vector3(-31, 0, -1), PI / 2, 6.0, 0.6, "Nobody answers. You hear snoring inside.", Color(1.05, 1.0, 0.8))
	_house("res://assets/suburban/building-type-u.glb", Vector3(31, 0, -1), -PI / 2, 6.0, 0.15, "A voice says: Crito Mon grow stronger when they battle!", Color(1.0, 0.92, 0.95))
	_lab()
	# fountain in the square
	prop("res://assets/builder/pavement-fountain.glb", Vector3(0, 0, 2), 0.0, 7.0, {}, "")
	cyl_wall(Vector3(0, 0, 2), 2.9, 2.0)
	# yard fences and flowers
	fence_line(Vector3(-24, 0, 11), Vector3(-19.5, 0, 11))
	fence_line(Vector3(-12.5, 0, 11), Vector3(-8, 0, 11))
	fence_line(Vector3(8, 0, 11), Vector3(12.5, 0, 11))
	fence_line(Vector3(19.5, 0, 11), Vector3(24, 0, 11))
	flowers(Vector3(-21.5, 0, 12.5), 1.6, 26)
	flowers(Vector3(-10.5, 0, 12.5), 1.6, 26)
	flowers(Vector3(10.5, 0, 12.5), 1.6, 26)
	flowers(Vector3(21.5, 0, 12.5), 1.6, 26)
	flowers(Vector3(0, 0, 2), 8.8, 0)
	for a in 8:
		var ang := a * TAU / 8.0 + 0.2
		flowers(Vector3(cos(ang) * 10.5, 0, 2 + sin(ang) * 10.5), 1.0, 10)
	prop("res://assets/suburban/planter.glb", Vector3(-5, 0, -8), 0.0, 3.0, {}, "box")
	prop("res://assets/suburban/planter.glb", Vector3(5, 0, 12), 0.0, 3.0, {}, "box")
	signpost(Vector3(-5, 0, 7), 0.4, "BIRCHWOOD TOWN\nA town where new adventures begin!")
	signpost(Vector3(-3.5, 0, -30), 0.0, "ROUTE 1 is north!\nWatch out: wild Crito Mon live in the tall grass.")
	# town trees
	for p in [Vector3(-8, 0, 22), Vector3(8, 0, 23), Vector3(-26, 0, 22), Vector3(26, 0, 24), Vector3(-28, 0, -20),
			Vector3(28, 0, -24), Vector3(-8, 0, -24), Vector3(26, 0, 10), Vector3(-26, 0, 10), Vector3(-34, 0, -26), Vector3(34, 0, 14)]:
		tree(p)


func _lab() -> void:
	# a big white lab with a red roof, blue windows and a sign
	var root := Node3D.new()
	root.position = LAB_POS
	add_child(root)
	var white := Color(0.97, 0.96, 0.93)
	var red := Color(0.92, 0.28, 0.25)
	box(Vector3(15, 5.4, 10), Vector3(0, 2.7, 0), white, 0.0, root)
	box(Vector3(15.8, 0.5, 10.8), Vector3(0, 5.6, 0), red, 0.0, root)
	box(Vector3(12.5, 0.9, 8.5), Vector3(0, 6.3, 0), red.darkened(0.1), 0.0, root)
	box(Vector3(15.2, 0.4, 10.2), Vector3(0, 0.2, 0), Color(0.6, 0.62, 0.7), 0.0, root)
	# windows along the front
	for x in [-5.5, -2.8, 2.8, 5.5]:
		box(Vector3(1.9, 1.7, 0.12), Vector3(x, 3.1, 5.02), Color(0.55, 0.82, 1.0), 0.0, root, {"emission": 0.25})
		box(Vector3(2.1, 0.18, 0.2), Vector3(x, 2.2, 5.05), white.darkened(0.15), 0.0, root)
	# glass doors with a frame and a step
	box(Vector3(2.6, 3.0, 0.14), Vector3(0, 1.9, 5.03), Color(0.5, 0.78, 1.0), 0.0, root, {"emission": 0.3})
	box(Vector3(0.1, 3.0, 0.2), Vector3(0, 1.9, 5.08), white.darkened(0.3), 0.0, root)
	box(Vector3(3.0, 0.2, 0.25), Vector3(0, 3.45, 5.08), red, 0.0, root)
	box(Vector3(3.6, 0.25, 1.4), Vector3(0, 0.12, 5.6), Color(0.72, 0.72, 0.78), 0.0, root)
	# rooftop satellite dish
	var dish := disc(1.1, 0.25, Vector3(5.2, 7.4, -1.5), Color(0.85, 0.87, 0.92), root)
	dish.rotation = Vector3(0.6, 0.4, 0)
	box(Vector3(0.2, 1.0, 0.2), Vector3(5.2, 6.9, -1.5), Color(0.6, 0.6, 0.66), 0.0, root)
	var sign := words("PROF. BIRCH'S LAB", Vector3(0, 4.5, 5.12), 0.0, 90, Color(1.0, 0.85, 0.25))
	remove_child(sign)
	root.add_child(sign)
	box_wall(LAB_POS + Vector3(0, 3, 0), Vector3(15.2, 6, 10.2))
	flowers(LAB_POS + Vector3(-5.2, 0, 6.3), 1.2, 14)
	flowers(LAB_POS + Vector3(5.2, 0, 6.3), 1.2, 14)


# ------------------------------------------------------------------ route

func _route() -> void:
	var grass_mesh := Toon.mesh("res://assets/platformer/grass.glb")
	var tex := Toon._find_texture(grass_mesh.surface_get_material(0))
	var gmat := Toon.material(tex, {"wind": 0.09, "rim": 0.15, "use_custom": true})
	for g in GRASS:
		var c: Vector2 = g.c
		var h: Vector2 = g.h
		var x := -h.x
		while x <= h.x:
			var z := -h.y
			while z <= h.y:
				var p := Vector3(c.x + x + randf_range(-0.35, 0.35), 0, c.y + z + randf_range(-0.35, 0.35))
				var xf := Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(1, randf_range(0.9, 1.25), 1) * randf_range(2.7, 3.3)), p)
				batch("tallgrass", grass_mesh, xf, gmat, Color(0.78, 1.0, 0.62).lerp(Color(0.62, 0.9, 0.5), randf()))
				z += 0.95
			x += 0.95
	# the pond with rocks and lily pads
	var pond := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 7.0
	pm.bottom_radius = 7.0
	pm.height = 0.1
	pm.radial_segments = 40
	pond.mesh = pm
	var wm := ShaderMaterial.new()
	wm.shader = preload("res://shaders/water.gdshader")
	pond.material_override = wm
	pond.position = Vector3(22, 0.02, -108)
	add_child(pond)
	cyl_wall(Vector3(22, 0, -108), 6.6, 2.0)
	for i in 5:
		var a := i * 1.3 + 0.4
		var pad := disc(0.55, 0.05, Vector3(22 + cos(a) * 4.0, 0.09, -108 + sin(a) * 3.5), Color(0.35, 0.75, 0.35))
		pad.scale = Vector3(1, 1, 0.8)
	for i in 7:
		var a := i * 0.9
		_rock(Vector3(22 + cos(a) * 7.4, 0, -108 + sin(a) * 7.4), randf_range(0.5, 0.9))
	# the camp: tents, a healer and a Connect Four table
	prop("res://assets/racing/decoration-tents.glb", Vector3(24, 0.03, -150), -0.3, 1.0, {"rim": 0.2}, "")
	box_wall(Vector3(24, 1.5, -151), Vector3(7, 3, 5), -0.3)
	picnic_table(Vector3(18, 0, -140), 0.0)
	# scattered trees and rocks along the route
	for p in [Vector3(-14, 0, -42), Vector3(14, 0, -46), Vector3(22, 0, -52), Vector3(-24, 0, -72), Vector3(-2, 0, -70),
			Vector3(-20, 0, -90), Vector3(14, 0, -92), Vector3(24, 0, -122), Vector3(10, 0, -114), Vector3(-24, 0, -130),
			Vector3(18, 0, -168), Vector3(-10, 0, -150), Vector3(24, 0, -186), Vector3(-26, 0, -160), Vector3(12, 0, -196)]:
		tree(p)
	for p in [Vector3(-6, 0, -44), Vector3(15, 0, -60), Vector3(-10, 0, -126), Vector3(14, 0, -168), Vector3(-12, 0, -194)]:
		_rock(p, randf_range(0.6, 1.1))
	flowers(Vector3(-6, 0, -78), 3.0, 30)
	flowers(Vector3(14, 0, -100), 2.5, 22)
	flowers(Vector3(-12, 0, -140), 3.0, 30)
	flowers(Vector3(12, 0, -176), 3.0, 30)
	signpost(Vector3(3.5, 0, -40), 0.0, "ROUTE 1\nBirchwood Town  <->  The Arena")
	signpost(Vector3(10, 0, -143), 0.0, "CAMP CRITO\nRest here! Nurse Pearl heals Crito Mon for free.")


func _rock(pos: Vector3, s: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = Toon.color(Color(0.66, 0.66, 0.7), {"rim": 0.2})
	mi.position = pos + Vector3(0, s * 0.35, 0)
	mi.scale = Vector3(1.2, 0.75, 1.0) * s
	mi.rotation.y = randf() * TAU
	add_child(mi)
	cyl_wall(pos, s * 1.0, s * 1.2)


## A picnic table with a Connect Four board on it. Returns the board centre.
func picnic_table(pos: Vector3, yaw: float) -> Vector3:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var wood := Color(0.7, 0.48, 0.3)
	box(Vector3(2.6, 0.12, 1.2), Vector3(0, 0.85, 0), wood, 0.0, root)
	for sx in [-1.1, 1.1]:
		box(Vector3(0.12, 0.85, 1.0), Vector3(sx, 0.42, 0), wood.darkened(0.2), 0.0, root)
	for sz in [-1.0, 1.0]:
		box(Vector3(2.6, 0.1, 0.35), Vector3(0, 0.5, sz), wood, 0.0, root)
	var b := ConnectFourBoard.new()
	b.position = Vector3(0, 0.91, 0)
	b.scale = Vector3.ONE * 0.22
	root.add_child(b)
	box_wall(pos + Vector3(0, 0.5, 0), Vector3(2.8, 1.0, 2.4), yaw)
	return pos + Vector3(0, 0.91, 0)


# ------------------------------------------------------------------ arena

func _arena() -> void:
	var c := Vector3(0, 0, -212)
	for ix in 5:
		for iz in 4:
			var p := c + Vector3((ix - 2) * 4.0, 0.0, (iz - 1.5) * 4.0)
			var path := "res://assets/arena/floor-detail.glb" if (ix + iz) % 2 == 0 else "res://assets/arena/floor.glb"
			batch(path, Toon.mesh(path), Transform3D(Basis().scaled(Vector3(4, 1, 4)), p + Vector3(0, 0.02, 0)))
	for side in [-1.0, 1.0]:
		for iz in 4:
			var p := c + Vector3(side * 11.0, 0, (iz - 1.5) * 4.2)
			prop("res://assets/arena/column.glb", p, 0.0, 3.2, {"rim": 0.25}, "cyl")
		prop("res://assets/arena/banner.glb", c + Vector3(side * 6.0, 0, -8.6), 0.0, 3.2, {"rim": 0.25}, "")
		prop("res://assets/arena/statue.glb", c + Vector3(side * 9.0, 0, -8.8), 0.0, 3.0, {"rim": 0.25}, "box")
	prop("res://assets/arena/block.glb", c + Vector3(0, 0, -9.0), 0.0, 2.4, {"rim": 0.25}, "box")
	var trophy := prop("res://assets/arena/trophy.glb", c + Vector3(0, 1.2, -9.0), 0.0, 2.2, {"rim": 0.5, "emission": 0.1}, "")
	trophy.name = "Trophy"
	for side in [-1.0, 1.0]:
		prop("res://assets/arena/stairs.glb", c + Vector3(side * 3.0, 0, 9.4), PI, 2.4, {"rim": 0.25}, "")
	words("THE ARENA", c + Vector3(0, 6.0, -9.2), 0.0, 120, Color(1.0, 0.85, 0.25))
	# a big battle circle painted on the floor
	var ring := disc(3.2, 0.03, c + Vector3(0, 0.08, 0), Color(0.95, 0.95, 0.95))
	ring.material_override = Toon.color(Color(0.95, 0.95, 0.95), {"rim": 0.0})
	disc(2.9, 0.035, c + Vector3(0, 0.085, 0), Color(0.86, 0.62, 0.45))


# ------------------------------------------------------------------ edges

func _borders() -> void:
	# town edges (with a gap to the north for Route 1)
	tree_row(Vector3(-44, 0, 40), Vector3(44, 0, 40), 3.4, 3)
	tree_row(Vector3(-42, 0, 40), Vector3(-42, 0, -38), 3.4, 3)
	tree_row(Vector3(42, 0, -38), Vector3(42, 0, 40), 3.4, 3)
	tree_row(Vector3(-42, 0, -38), Vector3(-6, 0, -38), 3.4, 2)
	tree_row(Vector3(6, 0, -38), Vector3(42, 0, -38), 3.4, 2)
	# route edges
	tree_row(Vector3(-32, 0, -38), Vector3(-32, 0, -228), 3.4, 3)
	tree_row(Vector3(32, 0, -228), Vector3(32, 0, -38), 3.4, 3)
	tree_row(Vector3(-32, 0, -226), Vector3(32, 0, -226), 3.4, 3)
	# thick forest outside so the world never looks empty
	for i in 520:
		var p := Vector3(randf_range(-95, 95), 0, randf_range(-290, 80))
		var inside_town := absf(p.x) < 47 and p.z > -42 and p.z < 45
		var inside_route := absf(p.x) < 37 and p.z < -30 and p.z > -232
		if inside_town or inside_route:
			continue
		tree(p, -1, randf_range(0.9, 1.5), false)


func _clouds() -> void:
	var m := Toon.mesh("res://assets/platformer/cloud.glb")
	var tex := Toon._find_texture(m.surface_get_material(0))
	var mat := Toon.material(tex, {"rim": 0.0, "emission": 0.35})
	for i in 14:
		var c := MeshInstance3D.new()
		c.mesh = m
		c.material_override = mat
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.position = Vector3(randf_range(-90, 90), randf_range(34, 52), randf_range(-260, 60))
		c.scale = Vector3(randf_range(12, 22), randf_range(6, 10), randf_range(9, 15))
		c.rotation.y = randf() * TAU
		add_child(c)
		clouds.append(c)


func _process(delta: float) -> void:
	for c in clouds:
		c.position.x += delta * 0.8
		if c.position.x > 100:
			c.position.x = -100


## Which tall grass patch (index) is at this spot, or -1.
func grass_at(p: Vector3) -> int:
	for i in GRASS.size():
		var g: Dictionary = GRASS[i]
		var d := Vector2(p.x, p.z) - (g.c as Vector2)
		if absf(d.x) <= (g.h as Vector2).x + 0.3 and absf(d.y) <= (g.h as Vector2).y + 0.3:
			return i
	return -1
