extends SceneTree
## A picture of the battle stage from the battle camera, with two Crito Mon.
## tools/show.sh -s res://tools/test/battle_view.gd -- --out=/tmp/b.png --me=emberpup --foe=pebblit

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var stage := BattleStage.new()
	root.add_child(stage)
	stage.build()
	var look := Look.new()
	root.add_child(look)
	var cam := Camera3D.new()
	cam.fov = 52
	root.add_child(cam)
	look.attach(cam)
	var me := CritterModel.new(args.get("me", "emberpup"))
	stage.add_child(me)
	me.position = BattleStage.MY_PAD
	me.scale = Vector3.ONE * 1.45
	var d := BattleStage.FOE_PAD - BattleStage.MY_PAD
	me.rotation.y = atan2(-d.x, -d.z)
	var foe := CritterModel.new(args.get("foe", "pebblit"))
	stage.add_child(foe)
	foe.position = BattleStage.FOE_PAD
	foe.scale = Vector3.ONE * 1.45
	foe.rotation.y = atan2(d.x, d.z)
	var p := Person.new("res://assets/chars/skins/player.png", 1.7, {"cap": Color(0.92, 0.18, 0.2), "cap2": Color(1, 1, 1)})
	stage.add_child(p)
	p.position = BattleStage.MY_TRAINER
	var e := BattleStage.FOE_PAD - BattleStage.MY_TRAINER
	p.rotation.y = atan2(-e.x, -e.z)
	var t := Person.new("res://assets/chars/skins/hiker.png", 1.72, {"hat": Color(0.55, 0.38, 0.22)})
	stage.add_child(t)
	t.position = BattleStage.FOE_TRAINER
	var f := BattleStage.MY_PAD - BattleStage.FOE_TRAINER
	t.rotation.y = atan2(-f.x, -f.z)
	cam.global_position = stage.to_global(BattleStage.CAM_POS)
	cam.look_at(stage.to_global(BattleStage.CAM_LOOK))
	for i in 12:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	# draw where the UI boxes go so the framing can be judged
	img.fill_rect(Rect2i(36, 30, 420, 90), Color(1, 1, 1, 0.6))
	img.fill_rect(Rect2i(1280 - 470, 720 - 350, 434, 124), Color(1, 1, 1, 0.6))
	img.fill_rect(Rect2i(80, 720 - 214, 1120, 184), Color(1, 1, 1, 0.6))
	img.save_png(args.get("out", "/tmp/b.png"))
	quit()
