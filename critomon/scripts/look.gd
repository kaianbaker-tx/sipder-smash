class_name Look
extends Node
## The sunny cartoon look: sky, sun with shadows, soft fog and the ink-line
## pass that sits in front of the camera.

var env: Environment
var sun: DirectionalLight3D
var post: ShaderMaterial
var quad: MeshInstance3D
var sky_mat: ShaderMaterial
# auto quality: draw the 3D smaller (and drop shadows) on slow computers
var scale_3d := 1.0
var _fps_t := 0.0
var _frames := 0
var _slow := 0
var _testing := "--autoplay" in OS.get_cmdline_user_args()


func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.6, 0.78)
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.75, 0.9, 1.0)
	env.fog_depth_begin = 70.0
	env.fog_depth_end = 170.0
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 0.52
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 55.0
	sun.shadow_blur = 0.6
	add_child(sun)
	var to_sun := Vector3(0.45, 0.8, 0.55).normalized()
	sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
	sky_mat.set_shader_parameter("sun_dir", to_sun)

	post = ShaderMaterial.new()
	post.shader = preload("res://shaders/post.gdshader")
	quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2, 2)
	quad.mesh = qm
	quad.material_override = post
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.sorting_offset = 1000.0


## Put the ink-line pass in front of a camera.
func attach(cam: Camera3D) -> void:
	if quad.get_parent():
		quad.get_parent().remove_child(quad)
	cam.add_child(quad)
	quad.position = Vector3(0, 0, -cam.near * 2.0)


## Indoors: no fog, softer light.
func set_indoor(on: bool) -> void:
	env.fog_enabled = not on
	env.ambient_light_color = Color(0.66, 0.64, 0.76) if on else Color(0.56, 0.6, 0.78)
	post.set_shader_parameter("far_start", 20.0 if on else 45.0)


func shadows(on: bool) -> void:
	sun.shadow_enabled = on


func _process(delta: float) -> void:
	var vp := get_viewport()
	# never draw 3D taller than 900 pixels (sharp phone screens), then adapt
	var cap := minf(1.0, 900.0 / maxf(float(vp.size.y), 1.0))
	var want := minf(cap, scale_3d)
	if absf(vp.scaling_3d_scale - want) > 0.01:
		vp.scaling_3d_scale = want
	if _testing:
		return
	_fps_t += delta
	_frames += 1
	if _fps_t < 2.0:
		return
	var fps := _frames / _fps_t
	_fps_t = 0.0
	_frames = 0
	if fps < 40.0 and scale_3d > 0.55:
		_slow += 1
		if _slow >= 2:
			_slow = 0
			scale_3d -= 0.15
			if scale_3d < 0.75:
				shadows(false)
	else:
		_slow = 0
