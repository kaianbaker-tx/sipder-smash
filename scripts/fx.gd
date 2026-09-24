extends Node
## Comic effects: onomatopoeia bursts ("THWIP!", "POW!"), debris, rings,
## camera shake, hit-stop and impact frames.

const FONT := preload("res://assets/fonts/bangers.ttf")

var rig: CamRig
var look: Node
var layer: CanvasLayer
var world: Node3D
var _pops: Array = []
var _stop_until := 0
var _particle_mat: StandardMaterial3D
var _cube: BoxMesh


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_particle_mat = StandardMaterial3D.new()
	_particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_particle_mat.vertex_color_use_as_albedo = true
	_particle_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_cube = BoxMesh.new()
	_cube.size = Vector3(0.35, 0.35, 0.35)


func setup(p_world: Node3D, p_rig: CamRig, p_look: Node) -> void:
	world = p_world
	rig = p_rig
	look = p_look


func clear() -> void:
	for p in _pops:
		var nv: Variant = p.node
		if is_instance_valid(nv):
			(nv as Node).queue_free()
	_pops.clear()


# ------------------------------------------------------------------ onomatopoeia

## Pop a comic word at a 3D point. style: "hit", "web", "big", "small"
func word(text: String, pos: Vector3, style := "hit", color := Color(1, 0.9, 0.1)) -> void:
	if not rig:
		return
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var size := 64
	match style:
		"big":
			size = 110
		"small":
			size = 40
		"web":
			size = 50
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.08))
	lbl.add_theme_constant_override("outline_size", maxi(8, size / 5))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.85, 1.0, 0.9) if style != "web" else Color(1.0, 0.2, 0.6, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", size / 14)
	lbl.add_theme_constant_override("shadow_offset_y", size / 14)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsize := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	lbl.position = -tsize * 0.5 - Vector2(0, size * 0.1)
	if style == "hit" or style == "big":
		var burst := _starburst(tsize.x * 0.75 + 20.0, tsize.y * 0.8 + 14.0, Color(1, 1, 1) if color.r > 0.9 and color.g > 0.8 else Color(1, 0.95, 0.4))
		root.add_child(burst)
	root.add_child(lbl)
	root.rotation = randf_range(-0.25, 0.25)
	root.scale = Vector2(0.2, 0.2)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2(1.25, 1.25), 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(root, "scale", Vector2(1.0, 1.0), 0.08)
	tw.tween_interval(0.35 if style != "big" else 0.7)
	tw.tween_property(root, "scale", Vector2(0.0, 0.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	_pops.append({"node": root, "pos": pos, "drift": Vector2(randf_range(-30, 30), -40)})


func _starburst(rx: float, ry: float, col: Color) -> Node2D:
	var n := Node2D.new()
	var pts := PackedVector2Array()
	var spikes := 14
	for i in spikes * 2:
		var a := i * PI / spikes
		var r := 1.0 if i % 2 == 0 else randf_range(0.58, 0.72)
		pts.append(Vector2(cos(a) * rx * r, sin(a) * ry * r))
	var shadow := Polygon2D.new()
	shadow.polygon = pts
	shadow.color = Color(1.0, 0.2, 0.55)
	shadow.position = Vector2(7, 7)
	n.add_child(shadow)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = col
	n.add_child(poly)
	var line := Line2D.new()
	var lp := pts.duplicate()
	lp.append(pts[0])
	line.points = lp
	line.width = 5.0
	line.default_color = Color(0.05, 0.0, 0.08)
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	n.add_child(line)
	return n


# ------------------------------------------------------------------ particles

func burst(pos: Vector3, color: Color, amount := 16, speed := 9.0, size := 0.35) -> void:
	if not world:
		return
	var p := CPUParticles3D.new()
	var m := _cube.duplicate() as BoxMesh
	m.size = Vector3.ONE * size
	m.material = _particle_mat
	p.mesh = m
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -22, 0)
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, color.darkened(0.4))
	p.color_ramp = g
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5, false).timeout.connect(p.queue_free)


func ring(pos: Vector3, color: Color, radius := 4.0, up := Vector3.UP) -> void:
	if not world:
		return
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.8
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	mi.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	world.add_child(mi)
	mi.global_position = pos
	if absf(up.dot(Vector3.UP)) < 0.99:
		mi.look_at(pos + up, Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	mi.scale = Vector3.ONE * 0.3
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.4, radius), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)


# ------------------------------------------------------------------ camera

func shake(amount: float) -> void:
	if rig:
		rig.shake(amount)


func hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	_stop_until = Time.get_ticks_msec() + int(seconds * 1000.0)


var _slow_until := 0


## A short dramatic slow-motion moment (real seconds).
func slowmo(seconds: float) -> void:
	Engine.time_scale = 0.35
	_slow_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	impact(1.0)


func impact(strength := 1.0) -> void:
	if look:
		look.impact(strength)


func glitch(strength := 1.0) -> void:
	if look:
		look.glitch(strength)


func hurt(strength := 1.0) -> void:
	if look:
		look.hurt(strength)


func _process(_delta: float) -> void:
	if _stop_until > 0 and Time.get_ticks_msec() >= _stop_until:
		_stop_until = 0
		if not get_tree().paused:
			Engine.time_scale = 0.35 if _slow_until > Time.get_ticks_msec() else 1.0
	if _slow_until > 0 and Time.get_ticks_msec() >= _slow_until:
		_slow_until = 0
		if not get_tree().paused and _stop_until == 0:
			Engine.time_scale = 1.0
	if not rig or not rig.cam:
		return
	var cam := rig.cam
	var keep: Array = []
	for p in _pops:
		var nv: Variant = p.node
		if not is_instance_valid(nv):
			continue
		var n := nv as Control
		keep.append(p)
		var wp: Vector3 = p.pos
		if cam.is_position_behind(wp):
			n.visible = false
			continue
		n.visible = true
		p.drift = (p.drift as Vector2) * 0.97
		n.position = cam.unproject_position(wp) + (p.drift as Vector2) * 0.3
	_pops = keep
