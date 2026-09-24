extends Node
## Sets up the Spider-Verse look: comic sky, environment and the full-screen
## comic pass (ink lines, misprint, speed lines, impact frames).
## Other scripts poke `post` (the ShaderMaterial) to trigger effects.

var post: ShaderMaterial
var quad: MeshInstance3D
var env: Environment
var _time := 0.0
var _impact := 0.0
var _glitch := 0.0
var _hurt := 0.0
var speed := 0.0


func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/sky.gdshader")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.4, 0.7)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)

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


## Put the comic pass in front of a camera.
func attach(cam: Camera3D) -> void:
	if quad.get_parent():
		quad.get_parent().remove_child(quad)
	cam.add_child(quad)
	quad.position = Vector3(0, 0, -cam.near * 2.0)


func impact(strength := 1.0) -> void:
	_impact = maxf(_impact, strength)


func glitch(strength := 1.0) -> void:
	_glitch = maxf(_glitch, strength)


func hurt(strength := 1.0) -> void:
	_hurt = maxf(_hurt, strength)


func set_noir(on: bool) -> void:
	RenderingServer.global_shader_parameter_set("noir", 1.0 if on else 0.0)


func _process(delta: float) -> void:
	_time += delta
	RenderingServer.global_shader_parameter_set("world_time", _time)
	var vp := get_viewport().get_visible_rect().size
	RenderingServer.global_shader_parameter_set("dot_size", maxf(3.0, vp.y / 150.0))
	# impact frames are short and hard: hold for two frames then snap off
	post.set_shader_parameter("impact", 1.0 if _impact > 0.5 else 0.0)
	_impact = maxf(0.0, _impact - delta * 12.0)
	post.set_shader_parameter("glitch", _glitch)
	_glitch = move_toward(_glitch, 0.0, delta * 2.5)
	post.set_shader_parameter("hurt", _hurt)
	_hurt = move_toward(_hurt, 0.0, delta * 2.0)
	post.set_shader_parameter("speed", speed)
