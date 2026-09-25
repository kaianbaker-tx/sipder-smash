extends Dimension
## DIMENSION 1: the NOIR-VERSE. A rainy black-and-white 1930s city with
## water towers, old cars and lightning. The heroes and bots stay in colour.

const U := 16.0
const HALF := 8
const BS := 14.5
const OLD := ["building-a", "building-b", "building-c", "building-d", "building-f", "building-g", "building-h", "building-i", "building-l"]
const WORKS := ["building-a", "building-c", "building-f", "building-m"]
# wall tints for the grey world: what matters here is light versus dark
const QUADS := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
const GREYS := [Color(1, 1, 1), Color(0.75, 0.75, 0.78), Color(0.55, 0.55, 0.6), Color(0.9, 0.85, 0.8)]

var _rain: CPUParticles3D
var _flash_t := 4.0
var _flash := -1.0   # seconds since the lightning started, -1 when calm


func _init() -> void:
	title = "NOIR-VERSE"
	intro = ["Whoa... everything went black and white!", "The bots stayed in COLOUR. Easy to spot. SMASH 'EM!"]
	music = "title"
	bot_plan = [["normal", 11], ["speedy", 2], ["big", 3]]
	radius = 175.0
	sky_ceil = 115.0
	fall_y = -1.8
	fall_word = "SPLOOSH!"
	start_pos = Vector3(0, 0.6, 128)
	start_look = Vector3(0, 0, -1)
	palette = {
		"sun_dir": Vector3(0.35, 0.7, 0.6).normalized(),
		"sun_color": Color(1, 1, 1),
		"shade_color": Color(0.28, 0.28, 0.32),
		"rim_color": Color(1, 1, 1),
		"rim_color_b": Color(0.85, 0.85, 0.9),
		"fog_color": Color(0.38, 0.38, 0.42),
		"fog_color_high": Color(0.22, 0.22, 0.26),
		"sky_top": Color(0.04, 0.04, 0.06),
		"sky_mid": Color(0.22, 0.22, 0.26),
		"sky_horizon": Color(0.55, 0.55, 0.6),
		"fog_start": 45.0,
		"fog_end": 260.0,
		"noir": 1.0,
		"noir_keep": 1.0,
		"portal_power": 0.0,
	}


func build() -> void:
	rng.seed = 31
	# ground and harbour
	var ext := (HALF + 1) * U * 2.0
	add_colliders([AABB(Vector3(-ext * 0.5, -10, -ext * 0.5), Vector3(ext, 10.05, ext))], Transform3D.IDENTITY)
	add_block(Vector3(ext, 6, ext), Vector3(0, -3.0, 0), Color(0.45, 0.45, 0.5), false)
	add_sea(-2.5, Color(0.1, 0.1, 0.14), Color(0.25, 0.25, 0.3))
	# streets
	for i in range(-HALF, HALF + 1):
		for j in range(-HALF, HALF + 1):
			var p := Vector3(i * U, 0.0, j * U)
			var sc := Basis.from_scale(Vector3(U, 1.0, U))
			var ri := posmod(i, 4) == 0
			var rj := posmod(j, 4) == 0
			if ri and rj:
				add_model(ROADS + "road-crossroad-line.glb", Transform3D(sc, p))
				safe_spots.append(p + Vector3(0, 0.1, 0))
			elif ri:
				add_model(ROADS + "road-straight.glb", Transform3D(sc, p))
			elif rj:
				add_model(ROADS + "road-straight.glb", Transform3D(Basis(Vector3.UP, PI * 0.5) * sc, p))
	# blocks of old buildings
	for bx in 4:
		for bz in 4:
			var c := Vector3((-6 + bx * 4) * U, 0.0, (-6 + bz * 4) * U)
			add_model(ROADS + "tile-low.glb", Transform3D(Basis.from_scale(Vector3(U * 3.0, 1.0, U * 3.0)), c))
			for k in 4:
				var qv: Vector2 = QUADS[k]
				var pos := c + Vector3(qv.x * 11.0, 0.02, qv.y * 11.0)
				var face := Vector3(qv.x, 0, 0) if rng.randf() < 0.5 else Vector3(0, 0, qv.y)
				var works := rng.randf() < 0.3
				var path: String = (IND + WORKS[rng.randi() % WORKS.size()] if works else CITY + OLD[rng.randi() % OLD.size()]) + ".glb"
				var hs := rng.randf_range(1.0, 1.7)
				var g: Color = GREYS[rng.randi() % GREYS.size()]
				var info := add_building(path, pos, atan2(face.x, face.z), Vector3(BS, BS * hs, BS), {"windows": 1.0, "use_custom": 1.0}, Color(g.r, g.g, g.b, 0.0))
				var box: AABB = info.box
				var top: float = info.top
				var roof := Vector3(box.get_center().x, top, box.get_center().z)
				safe_spots.append(roof + Vector3(0, 0.2, 0))
				if box.size.x > 7.0 and box.size.z > 7.0:
					# every noir roof needs a water tower
					var off := Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
					add_model(IND + "water-tower.glb", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * 5.0), roof + off))
					if rng.randf() < 0.5:
						add_model(IND + "chimney-small.glb", Transform3D(Basis.from_scale(Vector3.ONE * 4.0), roof + Vector3(-off.x * 1.5, 0, -off.z * 1.5)))
				bot_spots.append(roof + Vector3(0, rng.randf_range(8.0, 16.0), 0))
			# old street lamps and parked cars
			for side in 4:
				var ang := side * PI * 0.5
				var out := Vector3(sin(ang), 0, cos(ang))
				var along := Vector3(out.z, 0, -out.x)
				var lp := c + out * (U * 1.5 - 0.8)
				add_model(ROADS + "light-curved.glb", Transform3D(Basis(Vector3.UP, ang + PI) * Basis.from_scale(Vector3.ONE * 14.0), lp))
				if rng.randf() < 0.6:
					var car: String = ["sedan", "van", "truck", "police", "sedan"][rng.randi() % 5]
					var cp := c + out * (U * 1.5 + 5.2) + along * rng.randf_range(-12, 12)
					var cxf := Transform3D(Basis(Vector3.UP, ang + PI * 0.5) * Basis.from_scale(Vector3.ONE * 1.45), cp)
					add_model(CARS + car + ".glb", cxf)
					add_colliders([Toon.merged_mesh(CARS + car + ".glb").get_aabb().grow(-0.05)], cxf)
	# a few bots hang over the streets too
	for k in 8:
		bot_spots.append(Vector3(rng.randf_range(-110, 110), rng.randf_range(20, 40), rng.randf_range(-110, 110)))
	_make_rain()


func _make_rain() -> void:
	_rain = CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 1.6, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.85, 0.9, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = m
	_rain.mesh = bm
	_rain.amount = 420
	_rain.lifetime = 0.8
	_rain.preprocess = 1.0
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(34, 1, 34)
	_rain.direction = Vector3(0.08, -1, 0)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 45.0
	_rain.initial_velocity_max = 55.0
	_rain.gravity = Vector3(0, -20, 0)
	_rain.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	add_child(_rain)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and _rain:
		_rain.global_position = player.global_position + Vector3(0, 26, 0)
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
