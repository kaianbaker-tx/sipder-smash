class_name DimWorld
extends Dimension
## A dimension built from a recipe in verses.gd. One builder, many shapes:
## city grids, floating islands, towers in a sea, rings, floating cubes, a
## canyon, giant things, a hedge maze, a spiral tower, birthday cakes and
## dominoes. Colours, props, weather and sky extras come from the recipe.

const NATURE := "res://assets/nature/"
const PLAT := "res://assets/platformer/"
const DIRS := {"car": CARS, "plat": PLAT, "city": CITY, "ind": IND, "sub": SUB, "roads": ROADS}
const KITS := {
	"city": ["building-a", "building-b", "building-c", "building-d", "building-f", "building-g", "building-h", "building-i", "building-l", "building-m"],
	"tall": ["building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c", "building-skyscraper-d", "building-skyscraper-e"],
	"old": ["building-a", "building-b", "building-c", "building-d", "building-f", "building-g", "building-h", "building-i", "building-l"],
	"sub": ["building-type-a", "building-type-b", "building-type-c", "building-type-d", "building-type-e", "building-type-f", "building-type-g", "building-type-h", "building-type-k", "building-type-l", "building-type-o", "building-type-p", "building-type-q", "building-type-r", "building-type-s", "building-type-t", "building-type-u"],
	"ind": ["building-a", "building-c", "building-f", "building-m"],
}
const KIT_DIR := {"city": CITY, "tall": CITY, "old": CITY, "sub": SUB, "ind": IND}
# footprint in metres, then the range of extra height stretch
const KIT_SIZE := {"city": [14.0, 1.0, 1.6], "tall": [14.0, 1.0, 1.25], "old": [14.0, 1.0, 1.5], "sub": [15.0, 1.0, 1.0], "ind": [18.0, 1.0, 1.5]}
const QUADS := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
const BRIGHT := [Color(1, 0.25, 0.35), Color(1, 0.6, 0.15), Color(1, 0.9, 0.2), Color(0.3, 0.9, 0.4), Color(0.25, 0.6, 1), Color(0.7, 0.35, 1), Color(1, 0.4, 0.8)]

var theme: Dictionary = {}
var _sea_y := -2.5
var _void_y := -40.0
var _has_sea := false
var _pat := {}
var _boxes := {}          # texture id -> [texture, [Transform3D]]
var _solid: Array = []    # axis-aligned boxes for one big collider
var _weather: CPUParticles3D
var _weather_up := 24.0
var _bob: Array = []      # [node, base y, phase] things that float up and down
var _t := 0.0
var _flash_t := 5.0
var _flash := -1.0


func setup(t: Dictionary) -> void:
	theme = t
	title = t.name
	intro = t.get("intro", [])
	music = t.get("music", "city")
	bot_plan = t.get("bots", [["normal", 8]])
	fall_word = t.get("fall", "WHOOPS!")
	gravity = t.get("gravity", 1.0)
	radius = 195.0
	sky_ceil = 125.0
	start_pos = Vector3(0, 0.6, 16)
	start_look = Vector3(0, 0, -1)
	surface_opts = {"world_uv": 1.0 / 32.0}
	var sky: Array = t.sky
	var fog: Array = t.get("fog", [sky[2], sky[1]])
	var rim: Array = t.get("rim", ["#33f2ff", "#ff40b3"])
	palette = {
		"sun_dir": Vector3(0.5, 0.62, 0.6).normalized(),
		"sun_color": Color.html(t.get("sun", "#ffffff")),
		"shade_color": Color.html(t.get("shade", "#5a4a9a")),
		"rim_color": Color.html(rim[0]),
		"rim_color_b": Color.html(rim[1]),
		"fog_color": Color.html(fog[0]),
		"fog_color_high": Color.html(fog[1]),
		"sky_top": Color.html(sky[0]),
		"sky_mid": Color.html(sky[1]),
		"sky_horizon": Color.html(sky[2]),
		"fog_start": float(t.get("fog_start", 110.0)),
		"fog_end": float(t.get("fog_end", 520.0)),
		"noir": float(t.get("noir", 0.0)),
		"noir_keep": float(t.get("noir_keep", 0.0)),
		"portal_power": 0.0,
	}
	# the painted sky: cloud colours, and a moon / stars only at night
	var night := Color.html(sky[0]).get_luminance() < 0.08
	var clouds: Array = t.get("clouds", [Color.html(sky[2]).lerp(Color.WHITE, 0.55).to_html(), Color.html(sky[1]).lerp(Color.WHITE, 0.35).to_html()])
	palette["cloud_low"] = Color.html(clouds[0])
	palette["cloud_high"] = Color.html(clouds[1])
	palette["cloud_amount"] = float(t.get("cloud_amount", 0.0 if night else 1.0))
	palette["moon_power"] = 1.0 if t.get("extra", "") == "moon" else 0.0
	palette["star_power"] = 1.0 if night else 0.0


func build() -> void:
	rng.seed = hash(title)
	_has_sea = not theme.has("sea") or (theme.sea as Array).size() == 2
	match theme.get("layout", "grid"):
		"grid":
			_grid()
		"islands":
			_islands()
		"pillars":
			_pillars()
		"rings":
			_rings()
		"stacks":
			_stacks()
		"canyon":
			_canyon()
		"giants":
			_giants()
		"maze":
			_maze()
		"spiral":
			_spiral()
		"cake":
			_cake()
		"dominoes":
			_dominoes()
	if _has_sea:
		var sea: Array = theme.get("sea", [])
		if sea.is_empty():
			var fog: Array = theme.get("fog", ["#808080", "#404040"])
			sea = [Color.html(fog[1]).darkened(0.45).to_html(), Color.html(fog[0]).to_html()]
		add_sea(_sea_y, Color.html(sea[0]), Color.html(sea[1]))
		fall_y = _sea_y + 0.6
	else:
		fall_y = _void_y
	# a few bots hang in the open air too
	for k in 10:
		var a := rng.randf() * TAU
		var r := rng.randf_range(20.0, 130.0)
		bot_spots.append(Vector3(cos(a) * r, rng.randf_range(18.0, 42.0), sin(a) * r))
	if safe_spots.is_empty():
		safe_spots.append(start_pos)
	_flush_boxes()
	var extra: String = theme.get("extra", "")
	if extra != "":
		_extra(extra)
	var weather: String = theme.get("weather", "")
	if weather == "stars":
		_stars()
	elif weather != "":
		_make_weather(weather)


# ------------------------------------------------------------------ helpers

func _c(key: String, fallback := "#808080") -> Color:
	return Color.html(theme.get(key, fallback))


func _ground() -> Color:
	return _c("ground", "#808080")


func _ground2() -> Color:
	return _c("ground2", _ground().darkened(0.25).to_html())


## The theme's ground pattern (or a flat colour).
func _surface() -> Texture2D:
	var kind: String = theme.get("tex", "plain")
	if kind == "plain":
		return color_tex(_ground())
	return _pattern(kind, _ground(), _ground2())


## Comic patterns made in code: grid, checker, stripes, dots, bricks.
func _pattern(kind: String, a: Color, b: Color) -> Texture2D:
	var key := kind + a.to_html() + b.to_html()
	if _pat.has(key):
		return _pat[key]
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(a)
	match kind:
		"grid":
			for i in range(0, n, 32):
				img.fill_rect(Rect2i(i, 0, 3, n), b)
				img.fill_rect(Rect2i(0, i, n, 3), b)
		"checker":
			for y in range(0, n, 32):
				for x in range(0, n, 32):
					if ((x >> 5) + (y >> 5)) % 2 == 1:
						img.fill_rect(Rect2i(x, y, 32, 32), b)
		"stripes":
			# diagonal bands: each row is the row above shifted by one pixel
			for y in n:
				var x0 := -(y % 64)
				while x0 < n:
					img.fill_rect(Rect2i(x0 + 32, y, 32, 1).intersection(Rect2i(0, 0, n, n)), b)
					x0 += 64
		"dots":
			for cy in range(16, n, 32):
				for cx in range(16, n, 32):
					var ox := 16 if (cy >> 5) % 2 == 1 else 0
					for dy in range(-7, 8):
						for dx in range(-7, 8):
							if dx * dx + dy * dy <= 45:
								img.set_pixel((cx + ox + dx) % n, cy + dy, b)
		"bricks":
			for row in range(0, n, 16):
				img.fill_rect(Rect2i(0, row, n, 2), b)
				var off := 16 if (row >> 4) % 2 == 1 else 0
				for x in range(off, n + 32, 32):
					img.fill_rect(Rect2i(x % n, row, 2, 16), b)
	var tex := ImageTexture.create_from_image(img)
	_pat[key] = tex
	return tex


func _path(name: String) -> String:
	if name.begins_with("@"):
		var parts := name.substr(1).split(":")
		return DIRS[parts[0]] + parts[1] + ".glb"
	return NATURE + name + ".glb"


## How big (largest side, metres) a scattered prop should be.
func _prop_size(name: String) -> Vector2:
	var n := name.get_slice(":", 1) if name.begins_with("@") else name
	if n.begins_with("tree"):
		return Vector2(9, 15)
	if n.begins_with("cloud"):
		return Vector2(18, 32)
	if n.begins_with("statue"):
		return Vector2(5, 10)
	if n.begins_with("cactus"):
		return Vector2(4, 8)
	if n.begins_with("tent") or n.begins_with("log") or n.begins_with("detail-tank") or n.begins_with("solar"):
		return Vector2(5, 8)
	if n.begins_with("plant_flatTall") or n.begins_with("hanging"):
		return Vector2(4, 8)
	if n.begins_with("flower") or n.begins_with("grass") or n.begins_with("mushroom"):
		return Vector2(2, 4)
	if n.begins_with("crop") or n.begins_with("pot") or n.begins_with("campfire") or n.begins_with("coin") or n.begins_with("planter"):
		return Vector2(2.5, 4)
	if n.begins_with("flag") or n.begins_with("fence") or n.begins_with("chimney"):
		return Vector2(4, 6)
	if n.begins_with("construction"):
		return Vector2(1.5, 2)
	return Vector2(3.5, 5)


## Collision boxes for a model, sliced to fit tiny models (mushrooms) too.
func _stack(mesh: Mesh) -> Array:
	var ab := mesh.get_aabb()
	var big := maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
	if big < 0.9:
		return Toon.box_stack(mesh, ab.size.y / 24.0, big * 0.1)
	return Toon.box_stack(mesh)


func _tint_of(path: String) -> Color:
	var hue: float = theme.get("prop_hue", theme.get("hue", 0.0))
	if path.begins_with(NATURE) or path.begins_with(PLAT):
		return Color(1, 1, 1, hue)
	return Color(1, 1, 1, 0.0)


func _place(path: String, xf: Transform3D) -> void:
	var tint := _tint_of(path)
	if tint.a != 0.0:
		add_model(path, xf, {"use_custom": 1.0}, tint)
	else:
		add_model(path, xf)


## A scattered decoration standing on the ground at pos.
func _prop(name: String, pos: Vector3, collide := false) -> void:
	var path := _path(name)
	var mesh := Toon.merged_mesh(path)
	var ab := mesh.get_aabb()
	var sz := _prop_size(name)
	var s := rng.randf_range(sz.x, sz.y) / maxf(maxf(ab.size.x, ab.size.y), ab.size.z)
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s), pos - Vector3(0, ab.position.y * s, 0))
	_place(path, xf)
	if collide:
		add_colliders(_stack(mesh), xf)


func _near_start(pos: Vector3, r := 12.0) -> bool:
	return Vector2(pos.x - start_pos.x, pos.z - start_pos.z).length() < r and absf(pos.y - start_pos.y) < 8.0


func _random_prop(pos: Vector3, collide := false) -> void:
	if _near_start(pos):
		return
	var props: Array = theme.get("props", [])
	if not props.is_empty():
		_prop(props[rng.randi() % props.size()], pos, collide)


## A giant thing (tree, mushroom, toy car...) height metres tall.
## Returns {top, radius} (local).
func _giant(name: String, pos: Vector3, height: float) -> Dictionary:
	var path := _path(name)
	var mesh := Toon.merged_mesh(path)
	var ab := mesh.get_aabb()
	var s := height / maxf(ab.size.y, 0.05)
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s), pos - Vector3(0, ab.position.y * s, 0))
	var tint := _tint_of(path)
	if path.begins_with(SUB):
		var wall := _c("wall", "#ffffff")
		add_model(path, xf, {"windows": 1.0, "use_custom": 1.0}, Color(wall.r, wall.g, wall.b, tint.a))
	elif tint.a != 0.0:
		add_model(path, xf, {"use_custom": 1.0}, tint)
	else:
		add_model(path, xf)
	add_colliders(_stack(mesh), xf)
	return {"top": pos.y + ab.size.y * s, "radius": maxf(ab.size.x, ab.size.z) * s * 0.5}


func _giant_radius(name: String, height: float) -> float:
	var ab := Toon.merged_mesh(_path(name)).get_aabb()
	return maxf(ab.size.x, ab.size.z) * height / maxf(ab.size.y, 0.05) * 0.5


## A building from the theme's kit, with a wall tint and hue from the recipe.
func _building(kit: String, pos: Vector3, yaw: float, footprint := 0.0, stretch := 1.0) -> Dictionary:
	var names: Array = KITS[kit]
	var path: String = KIT_DIR[kit] + names[rng.randi() % names.size()] + ".glb"
	var ks: Array = KIT_SIZE[kit]
	var ab := Toon.merged_mesh(path).get_aabb()
	var s: float = (footprint if footprint > 0.0 else ks[0]) / maxf(ab.size.x, ab.size.z)
	var hs := rng.randf_range(ks[1], ks[2]) * stretch
	var wall := _c("wall", "#ffffff")
	var v := rng.randf_range(0.72, 1.0)
	var hue: float = theme.get("hue", 0.0)
	if theme.get("rainbow", false):
		hue = rng.randf()
		wall = BRIGHT[rng.randi() % BRIGHT.size()].lerp(Color.WHITE, 0.4)
	return add_building(path, pos, yaw, Vector3(s, s * hs, s), {"windows": 1.0, "use_custom": 1.0}, Color(wall.r * v, wall.g * v, wall.b * v, hue))


## Queue a box (batched into one MultiMesh per texture, one collider body).
func _box(size: Vector3, centre: Vector3, tex: Texture2D, rot := Basis(), collide := true) -> void:
	var key := str(tex.get_rid())
	if not _boxes.has(key):
		_boxes[key] = [tex, []]
	((_boxes[key] as Array)[1] as Array).append(Transform3D(rot * Basis.from_scale(size), centre))
	if not collide:
		return
	if rot == Basis():
		_solid.append(AABB(centre - size * 0.5, size))
	else:
		add_colliders([AABB(-size * 0.5, size)], Transform3D(rot, centre))


func _flush_boxes() -> void:
	var unit := BoxMesh.new()
	for key in _boxes:
		var e: Array = _boxes[key]
		var xfs: Array = e[1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = xfs.size()
		for k in xfs.size():
			mm.set_instance_transform(k, xfs[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Toon.material(e[0] as Texture2D, surface_opts)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_boxes.clear()
	if not _solid.is_empty():
		add_colliders(_solid, Transform3D.IDENTITY)
	_solid.clear()


## A flat plank from a to b (both are points on top of the plank).
func _bridge(a: Vector3, b: Vector3, width: float, tex: Texture2D) -> void:
	var mid := (a + b) * 0.5 - Vector3(0, 0.5, 0)
	var dir := (b - a).normalized()
	_box(Vector3(width, 1.0, a.distance_to(b)), mid, tex, Basis.looking_at(dir, Vector3.UP))


## Open ground: points on a grid that stay clear of the given circles.
func _open_spots(circles: Array, max_r: float, step: float, y: float) -> void:
	var x := -max_r
	while x <= max_r:
		var z := -max_r
		while z <= max_r:
			var p := Vector3(x, y, z)
			var ok := Vector2(x, z).length() < max_r
			for c in circles:
				var cc: Vector3 = c[0]
				if Vector2(x - cc.x, z - cc.z).length() < (c[1] as float) + 9.0:
					ok = false
					break
			if ok:
				gate_spots.append(p + Vector3(0, 0.2, 0))
				safe_spots.append(p + Vector3(0, 0.2, 0))
			z += step
		x += step


# ------------------------------------------------------------------ layouts

## A city grid like the Noir-Verse, but any kit and colour.
func _grid() -> void:
	const U := 16.0
	const HALF := 8
	start_pos = Vector3(0, 0.6, 128)
	var roads := not theme.has("tex")
	var ext := (HALF + 1) * U * 2.0
	_solid.append(AABB(Vector3(-ext * 0.5, -10, -ext * 0.5), Vector3(ext, 10.05, ext)))
	add_block(Vector3(ext, 6, ext), Vector3(0, -3.0, 0), _ground(), false, null if roads else _surface())
	_sea_y = -2.5
	for i in range(-HALF, HALF + 1):
		for j in range(-HALF, HALF + 1):
			var p := Vector3(i * U, 0.0, j * U)
			var ri := posmod(i, 4) == 0
			var rj := posmod(j, 4) == 0
			if not (ri or rj):
				continue
			if roads:
				var sc := Basis.from_scale(Vector3(U, 1.0, U))
				if ri and rj:
					add_model(ROADS + "road-crossroad-line.glb", Transform3D(sc, p))
				elif ri:
					add_model(ROADS + "road-straight.glb", Transform3D(sc, p))
				else:
					add_model(ROADS + "road-straight.glb", Transform3D(Basis(Vector3.UP, PI * 0.5) * sc, p))
			gate_spots.append(p + Vector3(0, 0.1, 0))
			if ri and rj:
				safe_spots.append(p + Vector3(0, 0.1, 0))
	var kit: String = theme.get("kit", "city")
	for bx in 4:
		for bz in 4:
			var c := Vector3((-6 + bx * 4) * U, 0.0, (-6 + bz * 4) * U)
			if roads:
				add_model(ROADS + "tile-low.glb", Transform3D(Basis.from_scale(Vector3(U * 3.0, 1.0, U * 3.0)), c))
			for k in 4:
				var qv: Vector2 = QUADS[k]
				var pos := c + Vector3(qv.x * 11.0, 0.02, qv.y * 11.0)
				var face := Vector3(qv.x, 0, 0) if rng.randf() < 0.5 else Vector3(0, 0, qv.y)
				var info := _building(kit, pos, atan2(face.x, face.z))
				var box: AABB = info.box
				var roof := Vector3(box.get_center().x, info.top, box.get_center().z)
				safe_spots.append(roof + Vector3(0, 0.2, 0))
				bot_spots.append(roof + Vector3(0, rng.randf_range(8.0, 16.0), 0))
			# street lamps and props along the block edges
			for side in 4:
				var ang := side * PI * 0.5
				var out := Vector3(sin(ang), 0, cos(ang))
				var along := Vector3(out.z, 0, -out.x)
				add_model(ROADS + "light-curved.glb", Transform3D(Basis(Vector3.UP, ang + PI) * Basis.from_scale(Vector3.ONE * 14.0), c + out * (U * 1.5 - 0.8)))
				if theme.has("props"):
					for n in 2:
						_random_prop(c + out * (U * 1.5 - 2.5) + along * rng.randf_range(-19.0, 19.0))
	if theme.get("flip", false):
		_ceiling_city()


## Upside-down towers hanging in the sky, on a grid so none overlap.
func _ceiling_city() -> void:
	sky_ceil = 150.0
	var wall := _c("wall", "#ffffff")
	var hue: float = theme.get("hue", 0.0)
	for gi in range(-3, 4):
		for gj in range(-3, 4):
			if rng.randf() < 0.45 or Vector2(gi, gj).length() > 3.6:
				continue
			_hanging_tower(Vector3(gi * 34.0, 0, gj * 34.0), wall, hue)


func _hanging_tower(at: Vector3, wall: Color, hue: float) -> void:
	var names: Array = KITS["tall"]
	var path: String = CITY + names[rng.randi() % names.size()] + ".glb"
	var ab := Toon.merged_mesh(path).get_aabb()
	var s := 13.0 / maxf(ab.size.x, ab.size.z)
	var p := Vector3(at.x, rng.randf_range(172.0, 188.0), at.z)
	var xf := Transform3D(Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s), p)
	add_model(path, xf, {"windows": 1.0, "use_custom": 1.0}, Color(wall.r, wall.g, wall.b, hue + 0.5))
	add_colliders(Toon.box_stack(Toon.merged_mesh(path)), xf)
	bot_spots.append(p - Vector3(0, ab.size.y * s + 8.0, 0))


## Floating islands over a sea (or the void), like the Candy-Verse.
func _islands() -> void:
	start_pos = Vector3(0, 1.0, 21)
	_sea_y = -9.0
	_void_y = -45.0
	var top := _ground()
	var tex := _surface()
	var under := color_tex(_ground2().darkened(0.3))
	var pole_tex := _pattern("stripes", _ground2().lightened(0.2), Color.WHITE)
	var kit: String = theme.get("kit", "none")
	var list := [[Vector3(0, 0, 0), 30.0]]
	for k in 8:
		var a := k * TAU / 8.0 + 0.2
		var r := rng.randf_range(72.0, 95.0)
		list.append([Vector3(cos(a) * r, rng.randf_range(2.0, 26.0), sin(a) * r), rng.randf_range(15.0, 21.0)])
	for k in 5:
		var a := k * TAU / 5.0 + 0.6
		var r := rng.randf_range(140.0, 165.0)
		list.append([Vector3(cos(a) * r, rng.randf_range(12.0, 40.0), sin(a) * r), rng.randf_range(13.0, 17.0)])
	for i in list.size():
		var c: Vector3 = list[i][0]
		var r: float = list[i][1]
		add_disc(r, 12.0, c, top, tex)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r * 0.8
		cm.bottom_radius = 0.5
		cm.height = r * 0.9
		cm.radial_segments = 16
		cone.mesh = cm
		cone.material_override = Toon.material(under)
		cone.position = c - Vector3(0, 12.0 + r * 0.45, 0)
		add_child(cone)
		# houses (small islands keep one side free to land on)
		var free_dir := Vector3.ZERO
		if kit != "none":
			var n := 1 if r < 18.0 else (2 if i > 0 else 4)
			for h in n:
				var a := rng.randf() * TAU
				var d := r * 0.45 + rng.randf_range(0.0, 3.0)
				if n == 1:
					d = r * 0.35
					free_dir = -Vector3(cos(a), 0, sin(a))
				if i == 0:
					a = h * TAU / n + PI * 0.25
					d = 17.0
				_building(kit, c + Vector3(cos(a) * d, 0, sin(a) * d), a + PI, 11.0)
		var spot := c + free_dir * r * 0.5 + Vector3(0, 0.2, 0)
		safe_spots.append(spot)
		gate_spots.append(spot)
		for t in int(r / 3.5):
			var a2 := rng.randf() * TAU
			_random_prop(c + Vector3(cos(a2), 0, sin(a2)) * rng.randf_range(r * 0.55, r * 0.9))
		for p in (1 if r < 18.0 else 2):
			var a3 := rng.randf() * TAU
			var pp := c + Vector3(cos(a3), 0, sin(a3)) * (r * 0.7)
			if _near_start(pp, 10.0):
				pp = c - Vector3(cos(a3), 0, sin(a3)) * (r * 0.7)
			add_pole(pp, rng.randf_range(24.0, 36.0), 0.9, pole_tex)
		bot_spots.append(c + Vector3(rng.randf_range(-6, 6), rng.randf_range(10, 18), rng.randf_range(-6, 6)))
	# stepping stones between the islands
	for k in 14:
		var a4 := rng.randf() * TAU
		var r4 := rng.randf_range(42.0, 130.0)
		var gp := Vector3(cos(a4) * r4, rng.randf_range(0.0, 36.0), sin(a4) * r4)
		if _near_start(gp, 16.0):
			continue
		add_disc(rng.randf_range(4.0, 6.5), 4.0, gp, _ground2(), null)
		safe_spots.append(gp + Vector3(0, 0.2, 0))
		if k % 2 == 0:
			add_pole(gp, rng.randf_range(18.0, 28.0), 0.7, pole_tex)
		bot_spots.append(gp + Vector3(0, rng.randf_range(8, 14), 0))


## Towers of rock (or crystal, or cheese) rising out of a sea, with bridges.
func _pillars() -> void:
	start_pos = Vector3(0, 0.6, 16)
	_sea_y = -2.0
	_void_y = -40.0
	var tex := _surface()
	var plank := color_tex(_ground2().lightened(0.15))
	var kit: String = theme.get("kit", "none")
	var giants: Array = theme.get("giants", [])
	add_disc(28.0, 8.0, Vector3.ZERO, _ground(), tex)
	for k in 6:
		var p := Vector3(cos(k * TAU / 6.0) * 15.0, 0.2, sin(k * TAU / 6.0) * 15.0)
		gate_spots.append(p)
		safe_spots.append(p)
	var tops: Array = []
	var tries := 0
	while tops.size() < 30 and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(46.0, 172.0)
		var w := rng.randf_range(12.0, 22.0)
		var c := Vector3(cos(a) * r, 0, sin(a) * r)
		var ok := true
		for t in tops:
			if Vector2(c.x - (t[0] as Vector3).x, c.z - (t[0] as Vector3).z).length() < (w + (t[1] as float)) * 0.5 + 12.0:
				ok = false
				break
		if not ok:
			continue
		c.y = clampf(rng.randf_range(4.0, 22.0) + (r - 40.0) * rng.randf_range(0.08, 0.32), 4.0, 70.0)
		var h := c.y - _sea_y + 30.0
		if rng.randf() < 0.5:
			_box(Vector3(w, h, w), c - Vector3(0, h * 0.5, 0), tex)
		else:
			add_disc(w * 0.5, h, c, _ground(), tex)
		tops.append([c, w])
		var roll := rng.randf()
		if kit != "none" and roll < 0.5:
			var info := _building(kit, c + Vector3(0, 0.02, 0), rng.randf() * TAU, w * 0.7)
			var box: AABB = info.box
			safe_spots.append(Vector3(box.get_center().x, info.top + 0.2, box.get_center().z))
			bot_spots.append(Vector3(c.x, info.top + rng.randf_range(8, 14), c.z))
		else:
			if not giants.is_empty() and roll < 0.75:
				var g := _giant(giants[rng.randi() % giants.size()], c + Vector3(w * 0.25, 0, w * 0.25), rng.randf_range(12.0, 26.0))
				bot_spots.append(Vector3(c.x, g.top + 8.0, c.z))
			else:
				for n in rng.randi_range(1, 3):
					_random_prop(c + Vector3(rng.randf_range(-w, w) * 0.35, 0, rng.randf_range(-w, w) * 0.35))
				bot_spots.append(c + Vector3(0, rng.randf_range(10, 18), 0))
			safe_spots.append(c + Vector3(0, 0.2, 0))
			if w >= 15.0:
				gate_spots.append(c + Vector3(0, 0.2, 0))
	# planks between near neighbours (and from the plaza to the closest)
	var from_list: Array = tops.duplicate()
	from_list.append([Vector3.ZERO, 50.0])
	for i in from_list.size():
		var a: Vector3 = from_list[i][0]
		var best := -1
		var bd := INF
		for j in tops.size():
			var b: Vector3 = tops[j][0]
			var d := Vector2(a.x - b.x, a.z - b.z).length()
			if d > 1.0 and d < bd:
				bd = d
				best = j
		if best < 0 or bd > 62.0:
			continue
		var b2: Vector3 = tops[best][0]
		if absf(b2.y - a.y) > bd * 0.55:
			continue   # too steep to walk up
		var dir := Vector3(b2.x - a.x, 0, b2.z - a.z).normalized()
		var ra := (from_list[i][1] as float) * 0.45 if i < tops.size() else 27.0
		var rb := (tops[best][1] as float) * 0.45
		_bridge(a + dir * ra, b2 - dir * rb, 4.0, plank)


## A plaza with a giant monument, rings of towers and floating platforms.
func _rings() -> void:
	start_pos = Vector3(0, 0.6, 40)
	_sea_y = -3.0
	_void_y = -40.0
	var tex := _surface()
	var kit: String = theme.get("kit", "none")
	var giants: Array = theme.get("giants", [])
	add_disc(176.0, 8.0, Vector3.ZERO, _ground(), tex)
	var circles: Array = []
	var centre_top := 60.0
	if not giants.is_empty():
		var cs: Array = theme.get("centre_size", [62.0, 80.0])
		var g := _giant(giants[0], Vector3.ZERO, rng.randf_range(cs[0], cs[1]))
		circles.append([Vector3.ZERO, g.radius])
		centre_top = g.top
	elif kit != "none":
		var info := _building(kit, Vector3.ZERO, 0.0, 26.0, 1.5)
		circles.append([Vector3.ZERO, 16.0])
		centre_top = info.top
	var ring1: Array = []
	for k in 8:
		var a := k * TAU / 8.0 + TAU / 16.0
		var p := Vector3(cos(a) * 58.0, 0, sin(a) * 58.0)
		var top := 0.0
		if kit != "none":
			var info := _building(kit, p, a + PI, 16.0, 1.2)
			top = info.top
		elif not giants.is_empty():
			top = _giant(giants[k % giants.size()], p, rng.randf_range(30.0, 48.0)).top
		circles.append([p, 12.0])
		ring1.append(p + Vector3(0, top, 0))
		bot_spots.append(p + Vector3(0, top + 10.0, 0))
	# floating platforms on striped posts
	var post := _pattern("stripes", _ground2(), Color.WHITE)
	for k in 12:
		var a := k * TAU / 12.0 + 0.26
		var r := rng.randf_range(94.0, 108.0)
		var p := Vector3(cos(a) * r, rng.randf_range(10.0, 36.0), sin(a) * r)
		add_disc(rng.randf_range(7.0, 10.0), 3.0, p, _ground2(), null)
		add_pole(Vector3(p.x, 0, p.z), p.y - 3.0, 0.8, post)
		_random_prop(p + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)))
		safe_spots.append(p + Vector3(0, 0.2, 0))
		bot_spots.append(p + Vector3(0, rng.randf_range(8, 14), 0))
		circles.append([Vector3(p.x, 0, p.z), 2.0])
	for k in 12:
		var a := k * TAU / 12.0 + rng.randf_range(-0.1, 0.1)
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(140.0, 158.0)
		var top := 0.0
		if kit != "none":
			top = _building(kit, p, a + PI, 18.0).top
		elif not giants.is_empty():
			top = _giant(giants[rng.randi() % giants.size()], p, rng.randf_range(25.0, 45.0)).top
		circles.append([p, 12.0])
		bot_spots.append(p + Vector3(0, top + 8.0, 0))
	for k in 40:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(34.0, 170.0)
		var clear := true
		for c in circles:
			if Vector2(p.x - (c[0] as Vector3).x, p.z - (c[0] as Vector3).z).length() < (c[1] as float) + 3.0:
				clear = false
				break
		if clear:
			_random_prop(p)
	_open_spots(circles, 168.0, 24.0, 0.0)
	if theme.get("webs", false):
		var silk := color_tex(Color(0.95, 0.95, 1.0))
		for k in ring1.size():
			var a: Vector3 = ring1[k]
			var b: Vector3 = ring1[(k + 1) % ring1.size()]
			_bridge(a - Vector3(0, 2, 0), b - Vector3(0, 2, 0), 0.9, silk)
			_bridge(a - Vector3(0, 2, 0), Vector3(0, centre_top - 4.0, 0), 0.9, silk)


## Floating cubes in a grid, all at different heights.
func _stacks() -> void:
	start_pos = Vector3(0, 0.6, 6)
	_sea_y = -40.0
	_void_y = -45.0
	const CELL := 34.0
	var tex := _surface()
	var tex2 := _pattern(theme.get("tex", "checker") if theme.get("tex", "plain") != "plain" else "checker", _ground2(), _ground())
	for i in range(-4, 5):
		for j in range(-4, 5):
			var centre := i == 0 and j == 0
			if not centre and rng.randf() < 0.28:
				continue
			var w := 20.0 if centre else rng.randf_range(11.0, 20.0)
			var y := 0.0 if centre else rng.randf_range(-6.0, 10.0) + Vector2(i, j).length() * rng.randf_range(2.0, 6.5)
			var thick := rng.randf_range(5.0, 10.0)
			var p := Vector3(i * CELL, y, j * CELL)
			if not centre:
				p += Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
			_box(Vector3(w, thick, w), p - Vector3(0, thick * 0.5, 0), tex)
			safe_spots.append(p + Vector3(0, 0.2, 0))
			if w >= 14.0:
				gate_spots.append(p + Vector3(0, 0.2, 0))
			if not centre:
				for n in rng.randi_range(0, 2):
					_random_prop(p + Vector3(rng.randf_range(-1, 1) * w * 0.35, 0, rng.randf_range(-1, 1) * w * 0.35))
			bot_spots.append(p + Vector3(0, rng.randf_range(8, 16), 0))
			if rng.randf() < 0.3:
				var q := p + Vector3(rng.randf_range(-5, 5), rng.randf_range(16, 26), rng.randf_range(-5, 5))
				_box(Vector3(w * 0.6, 4.0, w * 0.6), q - Vector3(0, 2.0, 0), tex2)
				safe_spots.append(q + Vector3(0, 0.2, 0))


## A long canyon with cliffs, ledges and bridges (and maybe a river).
func _canyon() -> void:
	const L := 360.0
	var river := _has_sea
	var bank := 17.0 if river else 0.0
	start_pos = Vector3(-bank, 0.6, 150)
	_sea_y = -2.0
	_void_y = -30.0
	var tex := _surface()
	var cliff := _pattern("stripes", _ground2(), _ground2().darkened(0.18))
	var plank := color_tex(_ground2().darkened(0.35))
	if river:
		_box(Vector3(22, 10, L), Vector3(-17, -5, 0), tex)
		_box(Vector3(22, 10, L), Vector3(17, -5, 0), tex)
		for z in range(-160, 170, 22):
			add_disc(2.8, 3.0, Vector3(0, 0.3, z), _ground2(), null)
	else:
		_box(Vector3(56, 10, L), Vector3(0, -5, 0), tex)
	for side in [-1.0, 1.0]:
		var z := -L * 0.5
		while z < L * 0.5:
			var w := rng.randf_range(18.0, 34.0)
			var h := rng.randf_range(34.0, 80.0)
			var d := rng.randf_range(24.0, 40.0)
			var x: float = side * (28.0 + d * 0.5)
			var zc := z + w * 0.5
			_box(Vector3(d, h + 10.0, w), Vector3(x, h * 0.5 - 5.0, zc), cliff)
			var top := Vector3(x, h, zc)
			safe_spots.append(top + Vector3(0, 0.2, 0))
			bot_spots.append(top + Vector3(0, rng.randf_range(8, 14), 0))
			_random_prop(top + Vector3(rng.randf_range(-d, d) * 0.3, 0, rng.randf_range(-w, w) * 0.3))
			if rng.randf() < 0.6:
				var lh := rng.randf_range(10.0, h - 10.0)
				var ledge := Vector3(side * 24.0, lh, zc)
				_box(Vector3(8.0, 2.0, w * 0.6), ledge - Vector3(0, 1.0, 0), tex)
				safe_spots.append(ledge + Vector3(0, 0.2, 0))
				bot_spots.append(ledge + Vector3(0, 6.0, 0))
			z += w
	for zb in range(-140, 160, 55):
		var y := rng.randf_range(18.0, 44.0)
		var zz := zb + rng.randf_range(-8.0, 8.0)
		_bridge(Vector3(-32, y, zz), Vector3(32, y, zz), 5.0, plank)
		safe_spots.append(Vector3(0, y + 0.2, zz))
		bot_spots.append(Vector3(0, y + 10.0, zz))
	for k in 28:
		var sx := -1.0 if rng.randf() < 0.5 else 1.0
		var px := sx * rng.randf_range(9.0, 25.0) if river else rng.randf_range(-24.0, 24.0)
		_random_prop(Vector3(px, 0, rng.randf_range(-170.0, 170.0)))
	var z2 := -160.0
	while z2 <= 160.0:
		for sx in ([-bank, bank] if river else [0.0]):
			gate_spots.append(Vector3(sx, 0.2, z2))
			safe_spots.append(Vector3(sx, 0.2, z2))
		z2 += 32.0


## You are tiny: giant trees / mushrooms / toys / houses on a big plain.
func _giants() -> void:
	start_pos = Vector3(0, 0.6, 12)
	_sea_y = -3.0
	_void_y = -30.0
	add_disc(182.0, 8.0, Vector3.ZERO, _ground(), _surface())
	var list: Array = theme.get("giants", ["tree_default"])
	var size: Array = theme.get("giant_size", [25.0, 45.0])
	var circles: Array = []
	var tries := 0
	var n := 0
	while n < 26 and tries < 800:
		tries += 1
		var name: String = list[n % list.size()]
		var hgt := rng.randf_range(size[0], size[1])
		var rad := _giant_radius(name, hgt)
		var a := rng.randf() * TAU
		var r := rng.randf_range(30.0 + rad, 172.0 - rad)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var ok := true
		for c in circles:
			if Vector2(p.x - (c[0] as Vector3).x, p.z - (c[0] as Vector3).z).length() < rad + (c[1] as float) + 10.0:
				ok = false
				break
		if not ok:
			continue
		var g := _giant(name, p, hgt)
		circles.append([p, rad])
		bot_spots.append(p + Vector3(0, g.top + rng.randf_range(6, 12), 0))
		bot_spots.append(p + Vector3(rad + 6.0, g.top * 0.5, 0))
		n += 1
	for k in 70:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(12.0, 175.0)
		var clear := true
		for c in circles:
			if Vector2(p.x - (c[0] as Vector3).x, p.z - (c[0] as Vector3).z).length() < (c[1] as float) + 2.0:
				clear = false
				break
		if clear:
			_random_prop(p)
	_open_spots(circles, 170.0, 26.0, 0.0)


## A hedge maze. The walls are climbable, so it is never a trap.
func _maze() -> void:
	const N := 11
	const CELL := 26.0
	const H := 12.0
	var half := N * CELL * 0.5
	start_pos = Vector3(0, 0.6, half + 12.0)
	_sea_y = -3.0
	_void_y = -30.0
	var ext := N * CELL + 50.0
	_box(Vector3(ext, 6, ext), Vector3(0, -3, 0), _surface())
	var hedge := _pattern("dots", _ground2(), _ground2().lightened(0.25))
	# carve the maze (depth-first), remembering open walls
	var open := {}
	var seen := {}
	var mid := int(N * 0.5)
	var stack: Array = [Vector2i(mid, N - 1)]
	seen[stack[0]] = true
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var next: Array = []
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb := cur + d
			if nb.x >= 0 and nb.y >= 0 and nb.x < N and nb.y < N and not seen.has(nb):
				next.append(nb)
		if next.is_empty():
			stack.pop_back()
			continue
		var nb2: Vector2i = next[rng.randi() % next.size()]
		open[_wall_key(cur, nb2)] = true
		seen[nb2] = true
		stack.append(nb2)
	# a few extra openings make loops (more fun, less stuck)
	for k in 14:
		var a := Vector2i(rng.randi_range(0, N - 2), rng.randi_range(0, N - 2))
		open[_wall_key(a, a + (Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1)))] = true
	for i in N:
		for j in N:
			var c := Vector3(-half + (i + 0.5) * CELL, 0, -half + (j + 0.5) * CELL)
			if i < N - 1 and not open.has(_wall_key(Vector2i(i, j), Vector2i(i + 1, j))):
				_box(Vector3(3, H, CELL + 3), c + Vector3(CELL * 0.5, H * 0.5, 0), hedge)
			if j < N - 1 and not open.has(_wall_key(Vector2i(i, j), Vector2i(i, j + 1))):
				_box(Vector3(CELL + 3, H, 3), c + Vector3(0, H * 0.5, CELL * 0.5), hedge)
			gate_spots.append(c + Vector3(0, 0.2, 0))
			safe_spots.append(c + Vector3(0, 0.2, 0))
			if (i + j) % 3 == 0:
				bot_spots.append(c + Vector3(0, rng.randf_range(5, 10), 0))
			if rng.randf() < 0.35:
				_random_prop(c + Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)))
	# the outer wall, with a way in at the front
	for i in N:
		var x := -half + (i + 0.5) * CELL
		_box(Vector3(CELL + 3, H, 3), Vector3(x, H * 0.5, -half), hedge)
		if i != mid:
			_box(Vector3(CELL + 3, H, 3), Vector3(x, H * 0.5, half), hedge)
		_box(Vector3(3, H, CELL + 3), Vector3(-half, H * 0.5, x), hedge)
		_box(Vector3(3, H, CELL + 3), Vector3(half, H * 0.5, x), hedge)
	# lookout towers in the corners (good web anchors)
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		var p: Vector3 = corner * (half + 14.0)
		_box(Vector3(10, 44, 10), p + Vector3(0, 22, 0), _pattern("bricks", _ground(), _ground().darkened(0.3)))
		safe_spots.append(p + Vector3(0, 44.2, 0))


func _wall_key(a: Vector2i, b: Vector2i) -> String:
	var lo := a if (a.x < b.x or (a.x == b.x and a.y < b.y)) else b
	var hi := b if lo == a else a
	return "%d,%d-%d,%d" % [lo.x, lo.y, hi.x, hi.y]


## A giant tower with a spiral path of platforms all the way up.
func _spiral() -> void:
	start_pos = Vector3(0, 0.6, 50)
	_sea_y = -3.0
	_void_y = -30.0
	sky_ceil = 195.0
	add_disc(80.0, 8.0, Vector3.ZERO, _ground(), _surface())
	var stripes := _pattern("stripes", _ground(), _ground2())
	var step_tex := color_tex(_ground2())
	add_pole(Vector3.ZERO, 172.0, 13.0, stripes)
	for k in 50:
		var a := k * 0.42
		var y := 3.0 + k * 3.3
		var p := Vector3(cos(a) * 24.0, y, sin(a) * 24.0)
		_box(Vector3(12.0, 1.6, 9.0), p - Vector3(0, 0.8, 0), step_tex, Basis(Vector3.UP, -a))
		safe_spots.append(p + Vector3(0, 0.2, 0))
		if k % 4 == 2:
			bot_spots.append(p + Vector3(cos(a) * 10.0, 6.0, sin(a) * 10.0))
	add_disc(24.0, 4.0, Vector3(0, 176, 0), _ground2(), stripes)
	safe_spots.append(Vector3(0, 176.2, 0))
	gate_spots.append(Vector3(0, 176.2, 0))
	for k in 8:
		var p := Vector3(cos(k * TAU / 8.0) * 50.0, 0.2, sin(k * TAU / 8.0) * 50.0)
		gate_spots.append(p)
		safe_spots.append(p)
		_random_prop(p * 1.3)
	# little towers around it
	for k in 7:
		var a := k * TAU / 7.0 + 0.3
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(110.0, 150.0)
		var h := rng.randf_range(30.0, 100.0)
		add_disc(9.0, h + 30.0, p + Vector3(0, h, 0), _ground(), stripes)
		safe_spots.append(p + Vector3(0, h + 0.2, 0))
		bot_spots.append(p + Vector3(0, h + 10.0, 0))


## A party table with giant layer cakes, candles and presents.
func _cake() -> void:
	start_pos = Vector3(0, 0.6, 72)
	_sea_y = -3.0
	_void_y = -30.0
	add_disc(176.0, 6.0, Vector3.ZERO, Color.WHITE, _pattern("checker", Color.WHITE, Color.html("#ff7ab0")))
	_cake_at(Vector3.ZERO, [[46.0, 20.0], [32.0, 18.0], [18.0, 16.0]])
	var circles: Array = [[Vector3.ZERO, 46.0]]
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		var p := Vector3(cos(a), 0, sin(a)) * 118.0
		_cake_at(p, [[17.0, 12.0], [10.0, 10.0]])
		circles.append([p, 17.0])
	for k in 18:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(60.0, 168.0)
		if _near_start(p, 18.0):
			continue
		var s := rng.randf_range(5.0, 11.0)
		var col: Color = BRIGHT[rng.randi() % BRIGHT.size()]
		_box(Vector3(s, s, s), p + Vector3(0, s * 0.5, 0), _pattern("stripes", col, Color.WHITE), Basis(Vector3.UP, rng.randf() * TAU))
		circles.append([p, s])
		safe_spots.append(p + Vector3(0, s + 0.2, 0))
	_open_spots(circles, 168.0, 26.0, 0.0)


func _cake_at(c: Vector3, tiers: Array) -> void:
	var y := 0.0
	var k := 0
	for t in tiers:
		var r: float = t[0]
		var h: float = t[1]
		var col: Color = BRIGHT[rng.randi() % BRIGHT.size()].lerp(Color.WHITE, 0.55)
		add_disc(r, h, c + Vector3(0, y + h, 0), col, _pattern("stripes", col, Color.WHITE))
		y += h
		safe_spots.append(c + Vector3(r * 0.8, y + 0.2, 0))
		bot_spots.append(c + Vector3(0, y + rng.randf_range(8, 14), r))
		k += 1
	var top_r: float = (tiers.back() as Array)[0]
	var candle := _pattern("stripes", Color.html("#ff5a8a"), Color.WHITE)
	for n in 5:
		var a := n * TAU / 5.0
		var p := c + Vector3(cos(a) * top_r * 0.55, y, sin(a) * top_r * 0.55)
		add_pole(p, 9.0, 0.9, candle)
		var flame := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.1
		sm.height = 2.8
		flame.mesh = sm
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(1, 0.75, 0.2)
		flame.material_override = fm
		flame.position = p + Vector3(0, 10.4, 0)
		add_child(flame)
	safe_spots.append(c + Vector3(0, y + 0.2, 0))
	gate_spots.append(c + Vector3(0, y + 0.2, 0))


## Giant dominoes standing in a spiral.
func _dominoes() -> void:
	start_pos = Vector3(0, 0.6, 6)
	_sea_y = -3.0
	_void_y = -30.0
	add_disc(180.0, 6.0, Vector3.ZERO, _ground(), _surface())
	var pips := _pattern("dots", Color.html("#15151a"), Color.WHITE)
	var t := 0.0
	var r := 30.0
	var k := 0
	while r < 166.0:
		var p := Vector3(cos(t) * r, 0, sin(t) * r)
		var tangent := Vector3(-sin(t), 0, cos(t))
		var h := rng.randf_range(24.0, 34.0)
		var b := Basis.looking_at(tangent, Vector3.UP)
		if rng.randf() < 0.07:
			# a fallen one makes a ramp
			b = b * Basis(Vector3.RIGHT, -1.25)
		_box(Vector3(13.0, h, 3.0), p + b * Vector3(0, h * 0.5, 0), pips, b)
		if k % 5 == 0:
			bot_spots.append(p + Vector3(0, h + rng.randf_range(6, 12), 0))
		t += 10.5 / r
		r = 30.0 + t * 24.0 / TAU
		k += 1
	for n in 6:
		var p := Vector3(cos(n * TAU / 6.0) * 13.0, 0.2, sin(n * TAU / 6.0) * 13.0)
		gate_spots.append(p)
		safe_spots.append(p)
	for n in 12:
		var p := Vector3(cos(n * TAU / 12.0) * 174.0, 0.2, sin(n * TAU / 12.0) * 174.0)
		safe_spots.append(p)


# ------------------------------------------------------------------ sky extras

func _sky_ball(pos: Vector3, r: float, col: Color, tex: Texture2D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 32
	sm.rings = 16
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	if tex:
		m.albedo_texture = tex
	m.disable_fog = true
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _extra(kind: String) -> void:
	match kind:
		"moon":
			pass   # the painted sky draws the moon (moon_power)
		"earth":
			var img := Image.create(128, 64, false, Image.FORMAT_RGB8)
			img.fill(Color(0.15, 0.4, 0.95))
			for n in 26:
				img.fill_rect(Rect2i(rng.randi_range(0, 120), rng.randi_range(4, 56), rng.randi_range(6, 22), rng.randi_range(4, 12)), Color(0.25, 0.8, 0.35))
			for n in 10:
				img.fill_rect(Rect2i(rng.randi_range(0, 120), rng.randi_range(0, 60), rng.randi_range(8, 30), 2), Color.WHITE)
			_sky_ball(Vector3(260, 240, -620), 90.0, Color.WHITE, ImageTexture.create_from_image(img))
		"planet":
			var p := _sky_ball(Vector3(300, 250, -700), 150.0, Color.html("#e8b87a"), _pattern("stripes", Color.html("#e8b87a"), Color.html("#c88a5a")))
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 200.0
			tm.outer_radius = 270.0
			tm.rings = 64
			tm.ring_segments = 4
			ring.mesh = tm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.95, 0.85, 0.65, 0.75)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.disable_fog = true
			ring.material_override = m
			ring.transform = Transform3D(Basis(Vector3(1, 0, 0.3).normalized(), 0.45) * Basis.from_scale(Vector3(1, 0.04, 1)), p.position)
			add_child(ring)
		"sun":
			var dir: Vector3 = (palette.sun_dir as Vector3)
			var at := Vector3(dir.x, maxf(dir.y * 0.45, 0.18), dir.z).normalized() * 700.0
			_sky_ball(at, 70.0, (palette.sun_color as Color).lerp(Color(1, 0.95, 0.7), 0.5))
			var halo := _sky_ball(at * 1.01, 100.0, Color(1, 0.9, 0.6, 0.3))
			(halo.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"rainbow":
			var cols := [Color(1, 0.25, 0.3), Color(1, 0.6, 0.2), Color(1, 0.92, 0.3), Color(0.35, 0.9, 0.45), Color(0.3, 0.6, 1.0), Color(0.65, 0.4, 1.0)]
			for n in cols.size():
				var ring := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 190.0 + n * 8.0
				tm.outer_radius = 198.0 + n * 8.0
				tm.rings = 64
				tm.ring_segments = 6
				ring.mesh = tm
				var m := StandardMaterial3D.new()
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.albedo_color = cols[cols.size() - 1 - n]
				m.disable_fog = true
				ring.material_override = m
				ring.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -40, -380))
				add_child(ring)
		"clouds":
			for n in 18:
				var a := rng.randf() * TAU
				var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(90.0, 420.0) + Vector3(0, rng.randf_range(85.0, 170.0), 0)
				var s := rng.randf_range(24.0, 44.0)
				_place(PLAT + "cloud.glb", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * 0.6, s)), p))
		"volcano":
			var v := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 26.0
			cm.bottom_radius = 150.0
			cm.height = 170.0
			cm.radial_segments = 24
			v.mesh = cm
			v.material_override = Toon.material(_pattern("stripes", Color.html("#3a2a2e"), Color.html("#2a1a20")), surface_opts)
			v.position = Vector3(250, 80, -420)
			add_child(v)
			var lava := _sky_ball(Vector3(250, 166, -420), 27.0, Color(1, 0.45, 0.1))
			_bob.append([lava, 166.0, 0.0])
		"balloons":
			var string_mat := StandardMaterial3D.new()
			string_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			string_mat.albedo_color = Color(1, 1, 1)
			for n in 26:
				var a := rng.randf() * TAU
				var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(30.0, 165.0) + Vector3(0, rng.randf_range(26.0, 70.0), 0)
				var b := Node3D.new()
				b.position = p
				add_child(b)
				var ball := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 3.4
				sm.height = 8.0
				sm.radial_segments = 16
				sm.rings = 8
				ball.mesh = sm
				ball.material_override = Toon.material(color_tex(BRIGHT[n % BRIGHT.size()]), {"character": 1.0})
				b.add_child(ball)
				var line := MeshInstance3D.new()
				var lm := BoxMesh.new()
				lm.size = Vector3(0.08, 12.0, 0.08)
				line.mesh = lm
				line.material_override = string_mat
				line.position = Vector3(0, -10.0, 0)
				b.add_child(line)
				var body := StaticBody3D.new()
				body.collision_layer = 1
				body.collision_mask = 0
				var cs := CollisionShape3D.new()
				var sh := SphereShape3D.new()
				sh.radius = 3.6
				cs.shape = sh
				body.add_child(cs)
				b.add_child(body)
				_bob.append([b, p.y, rng.randf() * TAU])
				bot_spots.append(p + Vector3(0, 8, 0))


## A dome of little stars (for space, the moon and the night).
func _stars() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 0.92)
	m.disable_fog = true
	bm.material = m
	mm.mesh = bm
	mm.instance_count = 520
	for n in 520:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.06, 1.0), rng.randf_range(-1, 1)).normalized()
		var s := rng.randf_range(0.8, 2.6)
		mm.set_instance_transform(n, Transform3D(Basis(d.cross(Vector3.UP).normalized() if absf(d.y) < 0.99 else Vector3.RIGHT, rng.randf()) * Basis.from_scale(Vector3.ONE * s), d * 900.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 1000.0
	add_child(mmi)


# ------------------------------------------------------------------ weather

func _make_weather(kind: String) -> void:
	var p := CPUParticles3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	var mesh: PrimitiveMesh = BoxMesh.new()
	var size := Vector3(0.2, 0.2, 0.2)
	var ramp: Array = [Color.WHITE]
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(38, 1, 38)
	p.visibility_aabb = AABB(Vector3(-80, -80, -80), Vector3(160, 160, 160))
	p.direction = Vector3.DOWN
	p.gravity = Vector3.ZERO
	match kind:
		"rain":
			size = Vector3(0.05, 1.6, 0.05)
			ramp = [Color(0.85, 0.88, 0.95, 0.55)]
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			p.amount = 420
			p.lifetime = 0.8
			p.direction = Vector3(0.08, -1, 0)
			p.spread = 2.0
			p.initial_velocity_min = 45.0
			p.initial_velocity_max = 55.0
			p.gravity = Vector3(0, -20, 0)
			_weather_up = 26.0
		"snow":
			size = Vector3(0.22, 0.22, 0.22)
			p.amount = 380
			p.lifetime = 7.0
			p.spread = 25.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 4.0
			p.gravity = Vector3(0.3, -0.6, 0)
			_weather_up = 22.0
		"embers", "pixels", "bubbles":
			if kind == "embers":
				ramp = [Color(1, 0.8, 0.2), Color(1, 0.4, 0.1), Color(1, 0.2, 0.1)]
			elif kind == "pixels":
				ramp = BRIGHT
				size = Vector3(0.45, 0.45, 0.45)
			else:
				mesh = SphereMesh.new()
				(mesh as SphereMesh).radial_segments = 8
				(mesh as SphereMesh).rings = 4
				(mesh as SphereMesh).radius = 0.25
				(mesh as SphereMesh).height = 0.5
				ramp = [Color(0.8, 0.95, 1.0, 0.65), Color(0.9, 1, 1, 0.5)]
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			p.amount = 170
			p.lifetime = 5.0
			p.emission_box_extents = Vector3(40, 10, 40)
			p.direction = Vector3.UP
			p.spread = 20.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 5.0
			_weather_up = -6.0
		"leaves", "petals", "confetti":
			size = Vector3(0.45, 0.05, 0.32)
			if kind == "leaves":
				ramp = [Color(1, 0.55, 0.1), Color(0.95, 0.3, 0.1), Color(1, 0.8, 0.2), Color(0.5, 0.8, 0.2)]
			elif kind == "petals":
				ramp = [Color(1, 0.7, 0.85), Color(1, 0.85, 0.92), Color(1, 0.55, 0.75)]
			else:
				ramp = BRIGHT
				size = Vector3(0.4, 0.04, 0.4)
			p.amount = 240
			p.lifetime = 7.0
			p.spread = 40.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.0
			p.gravity = Vector3(0.4, -0.8, 0.2)
			p.particle_flag_rotate_y = true
			p.angular_velocity_min = 90.0
			p.angular_velocity_max = 260.0
			_weather_up = 20.0
		"ash":
			size = Vector3(0.14, 0.14, 0.14)
			ramp = [Color(0.6, 0.55, 0.55, 0.8), Color(0.4, 0.38, 0.4, 0.8)]
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			p.amount = 260
			p.lifetime = 7.0
			p.spread = 60.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.5
			p.gravity = Vector3(0.6, -0.4, 0)
			_weather_up = 18.0
		"sparks", "fireflies":
			if kind == "sparks":
				ramp = [Color(1, 1, 0.7), Color(1, 0.9, 0.3), Color(0.6, 1, 1)]
				size = Vector3(0.12, 0.12, 0.12)
				p.lifetime = 1.4
				p.initial_velocity_min = 1.0
				p.initial_velocity_max = 4.0
			else:
				mesh = SphereMesh.new()
				(mesh as SphereMesh).radial_segments = 6
				(mesh as SphereMesh).rings = 3
				(mesh as SphereMesh).radius = 0.14
				(mesh as SphereMesh).height = 0.28
				ramp = [Color(0.85, 1, 0.4), Color(1, 0.95, 0.4)]
				p.lifetime = 4.0
				p.initial_velocity_min = 0.3
				p.initial_velocity_max = 1.2
			p.amount = 140
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 30.0
			p.spread = 180.0
			_weather_up = 3.0
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	mesh.material = mat
	p.mesh = mesh
	var g := Gradient.new()
	g.set_color(0, ramp[0])
	g.set_color(1, ramp[ramp.size() - 1])
	for n in range(1, ramp.size() - 1):
		g.add_point(float(n) / (ramp.size() - 1), ramp[n])
	p.color_initial_ramp = g
	p.preprocess = minf(p.lifetime, 3.0)
	_weather = p
	add_child(p)


func _process(delta: float) -> void:
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and _weather:
		_weather.global_position = player.global_position + Vector3(0, _weather_up, 0)
	for b in _bob:
		var n := b[0] as Node3D
		n.position.y = (b[1] as float) + sin(_t * 0.9 + (b[2] as float)) * 1.5
	if not theme.get("lightning", false):
		return
	# lightning: two quick sky flashes, then thunder
	_flash_t -= delta
	if _flash_t <= 0.0:
		_flash_t = rng.randf_range(6.0, 11.0)
		_flash = 0.0
	if _flash < 0.0:
		return
	_flash += delta
	var on := _flash < 0.07 or (_flash > 0.15 and _flash < 0.2)
	RenderingServer.global_shader_parameter_set("sky_horizon", Color(1, 1, 1) if on else palette["sky_horizon"])
	RenderingServer.global_shader_parameter_set("sky_mid", Color(0.9, 0.9, 0.95) if _flash < 0.07 else palette["sky_mid"])
	if _flash > 0.6:
		_flash = -1.0
		Sfx.play("thunder", 0.15)
