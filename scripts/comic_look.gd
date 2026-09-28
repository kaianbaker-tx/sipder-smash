extends Node
## Sets up the Spider-Verse look: comic sky, environment, the 3D ink-line
## pass (`post`) and the 2D finishing pass (`fx`: misprint, speed lines,
## impact frames, glitch). Other scripts call impact(), glitch(), hurt().

var post: ShaderMaterial
var fx: ShaderMaterial
var quad: MeshInstance3D
var env: Environment
var _time := 0.0
var _impact := 0.0
var _glitch := 0.0
var _hurt := 0.0
var speed := 0.0
# auto quality: render the 3D view smaller on slow computers
var scale_3d := 1.0
var _fps_t := 0.0
var _fps_frames := 0
var _slow := 0
# the home city's colours (from project.godot) and noir switches
var home_palette := {}
var _suit_noir := false
var _palette_noir := 0.0


func _ready() -> void:
	for prop in ProjectSettings.get_property_list():
		var n: String = prop.name
		if n.begins_with("shader_globals/"):
			var key := n.trim_prefix("shader_globals/")
			if key in ["world_time", "dot_size", "noir"]:
				continue
			home_palette[key] = (ProjectSettings.get_setting(n) as Dictionary).value
	home_palette["portal_power"] = 0.0
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

	# the 2D finishing pass sits under all the HUD layers
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx = ShaderMaterial.new()
	fx.shader = preload("res://shaders/screen_fx.gdshader")
	rect.material = fx
	layer.add_child(rect)


## Put the comic pass in front of a camera.
func attach(cam: Camera3D) -> void:
	if quad.get_parent():
		quad.get_parent().remove_child(quad)
	cam.add_child(quad)
	quad.position = Vector3(0, 0, -cam.near * 2.0)


func _auto_quality(delta: float) -> void:
	if Engine.time_scale < 0.9 or get_tree().paused or Game.args.has("autoplay"):
		return
	_fps_t += delta
	_fps_frames += 1
	if _fps_t < 2.0:
		return
	var fps := _fps_frames / _fps_t
	_fps_t = 0.0
	_fps_frames = 0
	if fps < 42.0 and scale_3d > 0.55:
		_slow += 1
		if _slow >= 2:
			_slow = 0
			scale_3d = maxf(0.5, scale_3d - 0.15)
			print("auto quality: 3D scale ", scale_3d, " (fps ", int(fps), ")")
	else:
		_slow = 0


func impact(strength := 1.0) -> void:
	_impact = maxf(_impact, strength)


func glitch(strength := 1.0) -> void:
	_glitch = maxf(_glitch, strength)


func hurt(strength := 1.0) -> void:
	_hurt = maxf(_hurt, strength)


## The black-and-white Noir suit.
func set_noir(on: bool) -> void:
	_suit_noir = on
	_apply_noir()


## Switch every world colour at once (a dimension's palette, or {} for home).
func apply_palette(p: Dictionary) -> void:
	for k in home_palette:
		RenderingServer.global_shader_parameter_set(k, p.get(k, home_palette[k]))
	_palette_noir = p.get("noir", 0.0)
	_apply_noir()


func _apply_noir() -> void:
	RenderingServer.global_shader_parameter_set("noir", maxf(_palette_noir, 1.0 if _suit_noir else 0.0))


func _process(delta: float) -> void:
	_time += delta
	RenderingServer.global_shader_parameter_set("world_time", _time)
	var vp := get_viewport()
	var h := float(vp.size.y)
	# never render 3D taller than 900 px (retina screens), then adapt to speed
	var cap := minf(1.0, 900.0 / maxf(h, 1.0))
	var want := minf(cap, scale_3d)
	if absf(vp.scaling_3d_scale - want) > 0.01:
		vp.scaling_3d_scale = want
	RenderingServer.global_shader_parameter_set("dot_size", maxf(3.0, h * vp.scaling_3d_scale / 150.0))
	_auto_quality(delta)
	# impact frames are short and hard: hold for two frames then snap off
	fx.set_shader_parameter("impact", 1.0 if _impact > 0.5 else 0.0)
	_impact = maxf(0.0, _impact - delta * 12.0)
	fx.set_shader_parameter("glitch", _glitch)
	_glitch = move_toward(_glitch, 0.0, delta * 2.5)
	fx.set_shader_parameter("hurt", _hurt)
	_hurt = move_toward(_hurt, 0.0, delta * 2.0)
	fx.set_shader_parameter("speed", speed)
