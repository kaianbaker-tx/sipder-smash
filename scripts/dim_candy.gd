extends Dimension
## DIMENSION 2: the CANDY-VERSE. Floating islands of pastel houses over a
## sea of pink clouds, with candy-cane poles to swing from and a rainbow.

const HOUSES := ["a", "b", "c", "d", "e", "f", "g", "h", "k", "l", "o", "p", "q", "r", "s", "t", "u"]
const TOPS := [Color(0.55, 0.95, 0.7), Color(1.0, 0.7, 0.85), Color(1.0, 0.95, 0.6), Color(0.7, 0.85, 1.0), Color(0.85, 0.7, 1.0)]
const WALLS := [Color(1, 0.8, 0.9), Color(0.8, 1, 0.9), Color(1, 1, 0.75), Color(0.85, 0.85, 1), Color(1, 0.88, 0.75)]

var islands: Array = []   # [local centre (top), radius]


func _init() -> void:
	title = "CANDY-VERSE"
	intro = ["Sweet! A world of floating candy islands!", "Swing from the candy poles. Don't fall in the clouds!"]
	music = "city"
	bot_plan = [["speedy", 8], ["normal", 8], ["big", 2]]
	radius = 200.0
	sky_ceil = 120.0
	fall_y = -45.0
	fall_word = "BOING!"
	start_pos = Vector3(0, 1.0, 18)
	start_look = Vector3(0, 0, -1)
	palette = {
		"sun_dir": Vector3(0.5, 0.65, 0.55).normalized(),
		"sun_color": Color(1, 0.97, 0.9),
		"shade_color": Color(0.62, 0.5, 0.9),
		"rim_color": Color(1, 1, 1),
		"rim_color_b": Color(1, 0.45, 0.75),
		"fog_color": Color(1, 0.78, 0.9),
		"fog_color_high": Color(0.72, 0.85, 1),
		"sky_top": Color(0.35, 0.68, 1.0),
		"sky_mid": Color(0.82, 0.66, 1.0),
		"sky_horizon": Color(1.0, 0.82, 0.62),
		"fog_start": 150.0,
		"fog_end": 620.0,
		"noir": 0.0,
		"noir_keep": 0.0,
		"portal_power": 0.0,
	}


func _stripes(a: Color, b: Color) -> Texture2D:
	var img := Image.create(64, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 64:
			img.set_pixel(x, y, a if int(floor(x / 16.0 + y / 16.0)) % 2 == 0 else b)
	return ImageTexture.create_from_image(img)


func build() -> void:
	rng.seed = 52
	var cane := _stripes(Color(1, 0.2, 0.35), Color(1, 1, 1))
	var mint := _stripes(Color(0.2, 0.85, 0.6), Color(1, 1, 1))
	# the islands: a big one in the middle, a ring, and far ones
	islands.append([Vector3(0, 0, 0), 30.0])
	for k in 8:
		var a := k * TAU / 8.0 + 0.2
		var r := rng.randf_range(72.0, 95.0)
		islands.append([Vector3(cos(a) * r, rng.randf_range(4.0, 34.0), sin(a) * r), rng.randf_range(15.0, 21.0)])
	for k in 5:
		var a := k * TAU / 5.0 + 0.6
		var r := rng.randf_range(140.0, 165.0)
		islands.append([Vector3(cos(a) * r, rng.randf_range(20.0, 50.0), sin(a) * r), rng.randf_range(13.0, 17.0)])
	for i in islands.size():
		var c: Vector3 = islands[i][0]
		var r: float = islands[i][1]
		add_disc(r, 12.0, c, TOPS[i % TOPS.size()])
		# a rocky candy underside
		var under := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r * 0.8
		cm.bottom_radius = 0.5
		cm.height = r * 0.9
		cm.radial_segments = 16
		under.mesh = cm
		under.material_override = Toon.material(color_tex(Color(0.95, 0.55, 0.75)))
		under.position = c - Vector3(0, 12.0 + r * 0.45, 0)
		add_child(under)
		safe_spots.append(c + Vector3(0, 0.2, 0))
		# houses on the island
		var n := 1 if r < 18.0 else (2 if i > 0 else 4)
		for h in n:
			var a := rng.randf() * TAU
			var d := r * (0.45 if n > 1 else 0.0) + rng.randf_range(0.0, 3.0)
			if i == 0:
				a = h * TAU / n + 0.4
				d = 17.0
			var hp := c + Vector3(cos(a) * d, 0, sin(a) * d)
			var wall: Color = WALLS[rng.randi() % WALLS.size()]
			var shift: float = [0.0, 0.5, 0.8, 0.3][rng.randi() % 4]
			var name: String = HOUSES[rng.randi() % HOUSES.size()]
			add_building(SUB + "building-type-%s.glb" % name, hp, a + PI, Vector3.ONE * 10.0, {"windows": 1.0, "use_custom": 1.0}, Color(wall.r, wall.g, wall.b, shift))
		# trees and a fence ring
		for t in int(r / 4.0):
			var a2 := rng.randf() * TAU
			var tp := c + Vector3(cos(a2), 0, sin(a2)) * rng.randf_range(r * 0.55, r * 0.9)
			add_model(SUB + ("tree-large.glb" if rng.randf() < 0.5 else "tree-small.glb"), Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * rng.randf_range(10, 14)), tp))
		# candy-cane poles to swing from
		var poles := 1 if r < 18.0 else 2
		for p in poles:
			var a3 := rng.randf() * TAU
			var pp := c + Vector3(cos(a3), 0, sin(a3)) * (r * 0.7)
			add_pole(pp, rng.randf_range(26.0, 38.0), 0.9, cane if (i + p) % 2 == 0 else mint)
		bot_spots.append(c + Vector3(rng.randf_range(-6, 6), rng.randf_range(10, 18), rng.randf_range(-6, 6)))
	# floating stepping-stone gumdrops between the islands
	for k in 14:
		var a4 := rng.randf() * TAU
		var r4 := rng.randf_range(40.0, 130.0)
		var gp := Vector3(cos(a4) * r4, rng.randf_range(0.0, 40.0), sin(a4) * r4)
		add_disc(rng.randf_range(4.0, 6.5), 4.0, gp, TOPS[rng.randi() % TOPS.size()])
		safe_spots.append(gp + Vector3(0, 0.2, 0))
		if k % 2 == 0:
			add_pole(gp, rng.randf_range(20.0, 30.0), 0.7, cane)
		bot_spots.append(gp + Vector3(0, rng.randf_range(8, 14), 0))
	# a rainbow rising out of the clouds
	var cols := [Color(1, 0.25, 0.3), Color(1, 0.6, 0.2), Color(1, 0.92, 0.3), Color(0.35, 0.9, 0.45), Color(0.3, 0.6, 1.0), Color(0.65, 0.4, 1.0)]
	for k in cols.size():
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 170.0 + k * 7.0
		tm.outer_radius = 177.0 + k * 7.0
		tm.rings = 64
		tm.ring_segments = 6
		ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = cols[cols.size() - 1 - k]
		ring.material_override = m
		ring.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -60, -330))
		add_child(ring)
	# bubbles of candy floating around
	for k in 30:
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var s := rng.randf_range(1.5, 4.0)
		sm.radius = s
		sm.height = s * 2.0
		sm.radial_segments = 12
		sm.rings = 6
		b.mesh = sm
		b.material_override = Toon.material(color_tex(TOPS[rng.randi() % TOPS.size()]), {"character": 1.0})
		b.position = Vector3(rng.randf_range(-220, 220), rng.randf_range(-20, 90), rng.randf_range(-220, 220))
		add_child(b)
	add_sea(-60.0, Color(1.0, 0.72, 0.86), Color(1.0, 0.9, 0.96))
