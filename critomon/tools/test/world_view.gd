extends SceneTree
## Pictures of the world from a few camera spots.
## tools/show.sh -s res://tools/test/world_view.gd -- --out=/tmp/w

const SHOTS := {
	"town": [Vector3(0, 30, 45), Vector3(0, 0, -2)],
	"square": [Vector3(-6, 6, 22), Vector3(6, 1, -8)],
	"route": [Vector3(0, 22, -30), Vector3(0, 0, -80)],
	"grass": [Vector3(-2, 4, -45), Vector3(-12, 0, -58)],
	"camp": [Vector3(2, 8, -128), Vector3(20, 0, -145)],
	"arena": [Vector3(0, 10, -190), Vector3(0, 1, -212)],
}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var out: String = args.get("out", "/tmp/w")
	var only: String = args.get("only", "")
	var t0 := Time.get_ticks_msec()
	var w := World.new()
	root.add_child(w)
	w.build()
	print("world built in ", Time.get_ticks_msec() - t0, " ms")
	var look := Look.new()
	root.add_child(look)
	var cam := Camera3D.new()
	cam.fov = 60
	cam.far = 400
	root.add_child(cam)
	look.attach(cam)
	for k in SHOTS:
		if only != "" and k != only:
			continue
		cam.position = SHOTS[k][0]
		cam.look_at(SHOTS[k][1])
		for f in 6:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, k])
	quit()
