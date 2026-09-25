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


