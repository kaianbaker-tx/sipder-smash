extends SceneTree
## Pictures of one model from the front (+Z), right (+X), back (-Z) and left (-X).
## tools/show.sh -s res://tools/test/sides.gd -- --model=res://assets/suburban/building-type-a.glb --out=/tmp/s.png

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var cell := 320
	var sheet := Image.create(cell * 4, cell, false, Image.FORMAT_RGBA8)
	var vp := SubViewport.new()
	vp.size = Vector2i(cell, cell)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var look := Look.new()
	vp.add_child(look)
	var inst := Toon.model(args.get("model", "res://assets/suburban/building-type-a.glb"))
	vp.add_child(inst)
	var aabb := inst.get_aabb()
	var c := aabb.get_center()
	var r := aabb.size.length() * 1.3
	var cam := Camera3D.new()
	vp.add_child(cam)
	var dirs := [Vector3(0, 0.5, 1), Vector3(1, 0.5, 0), Vector3(0, 0.5, -1), Vector3(-1, 0.5, 0)]
	for i in 4:
		cam.position = c + (dirs[i] as Vector3).normalized() * r
		cam.look_at(c)
		for f in 4:
			await process_frame
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, cell, cell), Vector2i(i * cell, 0))
	sheet.save_png(args.get("out", "/tmp/sides.png"))
	quit()
