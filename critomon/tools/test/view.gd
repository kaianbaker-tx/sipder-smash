extends SceneTree
## Takes a picture of Crito Mon and people for checking how they look.
## tools/show.sh -s res://tools/test/view.gd -- --what=critters --out=/tmp/v.png

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var what: String = args.get("what", "critters")
	var out: String = args.get("out", "/tmp/view.png")
	var w := Node3D.new()
	root.add_child(w)
	var look := Look.new()
	w.add_child(look)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	ground.material_override = Toon.color(Color(0.5, 0.8, 0.4))
	w.add_child(ground)
	var cam := Camera3D.new()
	w.add_child(cam)
	look.attach(cam)
	if what == "critters":
		var i := 0
		for sp in Dex.SPECIES:
			var c := CritterModel.new(sp)
			w.add_child(c)
			c.position = Vector3((i % 4) * 1.4 - 2.1, 0, (i / 4) * 1.6)
			c.rotation.y = PI + 0.5
			i += 1
		cam.position = Vector3(0, 2.6, 5.6)
		cam.look_at(Vector3(0, 0.5, 0.6))
		cam.fov = 50
	elif what == "people":
		var skins := ["skaterMaleA", "criminalMaleA", "skaterFemaleA", "cyborgFemaleA"]
		var gears := [{"cap": Color(0.9, 0.15, 0.15), "cap2": Color.WHITE, "bag": Color(0.2, 0.5, 0.9)}, {}, {"hat": Color(0.95, 0.85, 0.5)}, {"glasses": true}]
		for i in 4:
			var p := Person.new("res://assets/chars/skins/%s.png" % skins[i], 1.75, gears[i])
			w.add_child(p)
			p.position = Vector3(i * 1.3 - 2.0, 0, 0)
			p.rotation.y = PI + 0.3
		cam.position = Vector3(0, 1.6, 4.6)
		cam.look_at(Vector3(0, 1.0, 0))
		cam.fov = 50
	for f in 20:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	quit()
