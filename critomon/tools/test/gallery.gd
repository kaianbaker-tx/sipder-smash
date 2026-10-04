extends SceneTree
## Renders every model in a folder into a labelled grid picture.
## xvfb-run godot --rendering-driver opengl3 -s res://tools/test/gallery.gd -- --dir=res://assets/platformer --out=/tmp/g.png

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var dir: String = args.get("dir", "res://assets/platformer")
	var out: String = args.get("out", "/tmp/gallery.png")
	var files: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb") or f.ends_with(".fbx"):
			files.append(f)
	var cols := 6
	var cell := 200
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.85, 0.9, 1.0))
	var vp := SubViewport.new()
	vp.size = Vector2i(cell, cell)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.8, 0.88, 1.0)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.7)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	vp.add_child(cam)
	var font := ThemeDB.fallback_font
	for i in files.size():
		var inst: Node3D = (load(dir + "/" + files[i]) as PackedScene).instantiate()
		vp.add_child(inst)
		var aabb := _aabb(inst)
		var c := aabb.get_center()
		var r := aabb.size.length() * 0.5 + 0.01
		cam.position = c + Vector3(1, 0.8, 1.3).normalized() * r * 2.6
		cam.look_at(c)
		await process_frame
		await process_frame
		await process_frame
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, cell, cell), Vector2i((i % cols) * cell, (i / cols) * cell))
		print(i, " ", files[i], " size ", aabb.size)
		inst.queue_free()
	sheet.save_png(out)
	quit()


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
