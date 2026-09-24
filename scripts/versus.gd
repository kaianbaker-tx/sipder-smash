extends CanvasLayer
## A comic-book "VERSUS" splash: two live panels (hero and boss close-ups)
## slam in from the sides with a big VS starburst in the middle.

signal finished

var _vps: Array[SubViewport] = []
var _root: Control


func play(world: World3D, hero_pos: Vector3, hero_fwd: Vector3, boss_pos: Vector3, post: ShaderMaterial, seconds := 2.8) -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := UiKit.dim()
	_root.add_child(dim)
	var vp_size := get_viewport().get_visible_rect().size
	var pw := vp_size.x * 0.46
	var ph := vp_size.y * 0.78
	# hero panel (left), boss panel (right)
	var hero_cam_pos := hero_pos + Vector3(0, 1.4, 0) + hero_fwd * 2.6 + hero_fwd.cross(Vector3.UP) * 0.6
	var shots := [
		[hero_cam_pos, hero_pos + Vector3(0, 1.2, 0), "OUR HERO", Color(1, 0.9, 0.2), -1.0, 50.0],
		[boss_pos + (hero_pos - boss_pos).normalized() * 16.0 + Vector3(0, 2, 0), boss_pos + Vector3(0, 1, 0), "THE GLITCH KING", Color(1, 0.3, 0.6), 1.0, 45.0],
	]
	for i in 2:
		var s: Array = shots[i]
		var sv := SubViewport.new()
		sv.size = Vector2i(int(pw), int(ph))
		sv.world_3d = world
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		_vps.append(sv)
		var cam := Camera3D.new()
		cam.fov = s[5]
		cam.near = 0.3
		cam.far = 900.0
		sv.add_child(cam)
		cam.global_position = s[0]
		cam.look_at(s[1])
		cam.current = true
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2, 2)
		q.mesh = qm
		q.material_override = post
		q.extra_cull_margin = 16384.0
		cam.add_child(q)
		q.position = Vector3(0, 0, -0.6)
		# the panel
		var panel := Control.new()
		panel.size = Vector2(pw, ph)
		panel.pivot_offset = Vector2(pw, ph) * 0.5
		var x0 := vp_size.x * (0.03 if i == 0 else 0.51)
		panel.position = Vector2(x0, vp_size.y * 0.1)
		panel.rotation = (-0.04 if i == 0 else 0.04)
		_root.add_child(panel)
		var border := ColorRect.new()
		border.color = UiKit.INK
		border.position = Vector2(-10, -10)
		border.size = Vector2(pw + 20, ph + 20)
		panel.add_child(border)
		var shadow := ColorRect.new()
		shadow.color = s[3]
		shadow.position = Vector2(4, 4) + Vector2(10, 10)
		shadow.size = Vector2(pw + 20, ph + 20)
		shadow.show_behind_parent = true
		border.add_child(shadow)
		var tex := TextureRect.new()
		tex.texture = sv.get_texture()
		tex.size = Vector2(pw, ph)
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		panel.add_child(tex)
		var name := UiKit.label(s[2], 48, s[3], UiKit.BANGERS, 14)
		name.position = Vector2(20, ph - 80)
		panel.add_child(name)
		# slam in from the side
		var from_x := -pw * 1.3 if i == 0 else vp_size.x + pw * 0.3
		var target_x := panel.position.x
		panel.position.x = from_x
		var tw := panel.create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_property(panel, "position:x", target_x, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# VS starburst
	var vs := Control.new()
	vs.position = vp_size * 0.5 + Vector2(0, -10)
	_root.add_child(vs)
	var pts := PackedVector2Array()
	for i in 28:
		var a := i * PI / 14.0
		var rr := 115.0 if i % 2 == 0 else 70.0
		pts.append(Vector2(cos(a), sin(a)) * rr)
	var sh := Polygon2D.new()
	sh.polygon = pts
	sh.color = Color(0.1, 0.9, 1)
	sh.position = Vector2(8, 8)
	vs.add_child(sh)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = Color(1, 0.9, 0.2)
	vs.add_child(poly)
	var ol := Line2D.new()
	var lp := pts.duplicate()
	lp.append(pts[0])
	ol.points = lp
	ol.width = 7
	ol.default_color = UiKit.INK
	vs.add_child(ol)
	var vl := UiKit.label("VS", 96, Color(1, 0.2, 0.45), UiKit.BANGERS, 16)
	vl.position = Vector2(-52, -66)
	vs.add_child(vl)
	vs.scale = Vector2.ZERO
	var tw2 := vs.create_tween()
	tw2.tween_interval(0.4)
	tw2.tween_property(vs, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK)
	tw2.tween_property(vs, "scale", Vector2(1, 1), 0.1)
	tw2.tween_callback(func() -> void: Sfx.play("punch_big"))
	var end := create_tween()
	end.tween_interval(seconds)
	end.tween_property(_root, "modulate:a", 0.0, 0.25)
	end.tween_callback(func() -> void:
		finished.emit()
		queue_free())
