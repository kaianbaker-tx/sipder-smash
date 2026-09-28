extends Dimension
## THE GLITCH-VERSE: home of the Glitch-Bots. A glowing arena floats in a
## dark void under a giant swirling portal, with glitching towers on floating
## blocks, data bridges, and upside-down skyscrapers hanging from the sky.

const TOWERS := ["building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c", "building-skyscraper-e", "building-m", "building-l"]

var _cubes: MultiMesh
var _cube_data: Array = []   # [pos, axis, speed, size]
var _t := 0.0


func _init() -> void:
	title = "THE GLITCH-VERSE"
	intro = ["This is where the Glitch-Bots come from!", "Smash every bot... then the GLITCH KING has to come out!"]
	music = "boss"
	bot_plan = [["normal", 8], ["speedy", 4], ["big", 2]]
	radius = 200.0
	sky_ceil = 140.0
	fall_y = -60.0
	fall_word = "ZAP!"
	start_pos = Vector3(0, 1.0, 26)
	start_look = Vector3(0, 0, -1)
	arena = Vector3(0, 0, 0)
	palette = {
		"sun_dir": Vector3(0.3, 0.8, 0.45).normalized(),
		"sun_color": Color(0.78, 1, 1),
		"shade_color": Color(0.32, 0.14, 0.52),
		"rim_color": Color(0, 1, 1),
		"rim_color_b": Color(1, 0.1, 0.8),
		"fog_color": Color(0.2, 0.03, 0.32),
		"fog_color_high": Color(0.06, 0.0, 0.14),
		"sky_top": Color(0.02, 0.0, 0.05),
		"sky_mid": Color(0.15, 0.0, 0.3),
		"sky_horizon": Color(0.85, 0.1, 0.6),
		"fog_start": 90.0,
		"fog_end": 480.0,
		"noir": 0.0,
		"noir_keep": 0.0,
		"portal_power": 1.0,
		"portal_dir": Vector3(0.0, 0.8, -0.6).normalized(),
		"portal_size": 0.55,
	}


func _grid_tex() -> Texture2D:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color(0.16, 0.05, 0.3))
	for i in 256:
		for w in 3:
			var k := (i + w) % 256
			if i % 32 == 0:
				for j in 256:
					img.set_pixel(k, j, Color(0.1, 0.95, 1.0))
					img.set_pixel(j, k, Color(0.1, 0.95, 1.0))
	for y in range(16, 256, 32):
		for x in range(16, 256, 32):
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if dx * dx + dy * dy <= 9:
						img.set_pixel(x + dx, y + dy, Color(1.0, 0.2, 0.7))
	return ImageTexture.create_from_image(img)


func build() -> void:
	rng.seed = 77
	var grid := _grid_tex()
	# the arena where the Glitch King waits
	add_disc(34.0, 10.0, arena, Color.WHITE, grid)
	safe_spots.append(arena + Vector3(0, 0.2, 18))
	for k in 6:
		gate_spots.append(arena + Vector3(cos(k * TAU / 6.0) * 20.0, 0.2, sin(k * TAU / 6.0) * 20.0))
	# glowing pylons around the arena rim
	for k in 8:
		var a := k * TAU / 8.0
		add_pole(Vector3(cos(a) * 31.0, 0, sin(a) * 31.0), 14.0 + (k % 2) * 8.0, 1.0, color_tex(Color(0.1, 0.95, 1.0) if k % 2 == 0 else Color(1, 0.2, 0.7)))
	# floating data-blocks with glitching towers, joined to the arena by bridges
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		var r := rng.randf_range(88.0, 104.0)
		var top := rng.randf_range(10.0, 42.0)
		var c := Vector3(cos(a) * r, top, sin(a) * r)
		add_block(Vector3(24, 6, 24), c - Vector3(0, 3, 0), Color.WHITE, true, grid)
		safe_spots.append(c + Vector3(6, 0.2, 6))
		gate_spots.append(c + Vector3(6, 0.2, 6))
		var tower: String = TOWERS[rng.randi() % TOWERS.size()]
		var hs := rng.randf_range(0.8, 1.2)
		var shift: float = [0.5, 0.82, 0.9, 0.3][k % 4]
		var info := add_building(CITY + tower + ".glb", c + Vector3(-4, 0, -4), a + PI, Vector3(12, 12 * hs, 12), {"windows": 1.0, "use_custom": 1.0, "glitch": 0.3}, Color(0.75, 0.7, 1.0, shift))
		var roof: Vector3 = Vector3((info.box as AABB).get_center().x, info.top, (info.box as AABB).get_center().z)
		bot_spots.append(c + Vector3(6, rng.randf_range(8, 14), 6))
		bot_spots.append(roof + Vector3(0, 10, 0))
		# a sloping bridge from the arena edge up to the block
		var from := Vector3(cos(a) * 32.0, -0.5, sin(a) * 32.0)
		var to := c + Vector3(-cos(a) * 12.0, -0.5, -sin(a) * 12.0)
		var mid := (from + to) * 0.5
		var length := from.distance_to(to)
		var dir := (to - from).normalized()
		var basis := Basis.looking_at(dir, Vector3.UP)
		add_block(Vector3(5.0, 1.0, length), mid, Color(0.1, 0.9, 1.0), true, null, basis)
	# upside-down skyscrapers hanging from the sky (great for swinging!)
	for k in 12:
		var a := rng.randf() * TAU
		var r := rng.randf_range(45.0, 170.0)
		var tower: String = TOWERS[rng.randi() % TOWERS.size()]
		var s := rng.randf_range(11.0, 15.0)
		var pos := Vector3(cos(a) * r, rng.randf_range(150.0, 185.0), sin(a) * r)
		var xf := Transform3D(Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s, s)), pos)
		add_model(CITY + tower + ".glb", xf, {"windows": 1.0, "use_custom": 1.0, "glitch": 0.2}, Color(0.8, 0.7, 1.0, 0.82))
		add_colliders(Toon.box_stack(Toon.merged_mesh(CITY + tower + ".glb")), xf)
	# more bots in the air between everything
	for k in 8:
		var a := rng.randf() * TAU
		bot_spots.append(Vector3(cos(a) * rng.randf_range(40, 80), rng.randf_range(15, 45), sin(a) * rng.randf_range(40, 80)))
	# floating glitch cubes
	_cubes = MultiMesh.new()
	_cubes.transform_format = MultiMesh.TRANSFORM_3D
	_cubes.use_colors = true
	var bm := BoxMesh.new()
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.vertex_color_use_as_albedo = true
	bm.material = cm
	_cubes.mesh = bm
	_cubes.instance_count = 90
	var cols := [Color(1, 0.2, 0.7), Color(0.1, 0.95, 1), Color(1, 0.9, 0.2), Color(0.6, 0.3, 1)]
	for i in 90:
		var p := Vector3(rng.randf_range(-260, 260), rng.randf_range(-50, 140), rng.randf_range(-260, 260))
		if Vector2(p.x, p.z).length() < 45.0:
			p.x += 90.0
		_cube_data.append([p, Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf_range(0.3, 1.5), rng.randf_range(1.5, 6.0)])
		_cubes.set_instance_color(i, cols[i % cols.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _cubes
	mmi.extra_cull_margin = 400.0
	add_child(mmi)
	add_sea(-80.0, Color(0.05, 0.0, 0.14), Color(0.1, 0.45, 0.65))


func _process(delta: float) -> void:
	_t += delta
	if not _cubes:
		return
	for i in _cube_data.size():
		var d: Array = _cube_data[i]
		var b := Basis(d[1] as Vector3, _t * (d[2] as float)).scaled(Vector3.ONE * (d[3] as float))
		_cubes.set_instance_transform(i, Transform3D(b, (d[0] as Vector3) + Vector3(0, sin(_t * 0.6 + i) * 3.0, 0)))
