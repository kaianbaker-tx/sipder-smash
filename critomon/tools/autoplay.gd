extends Node
## Plays Crito Mon by itself, for testing. Dialogs, battles and Connect Four
## go on automatically. Takes a picture every so often with --shots=folder.
##   tools/show.sh res://scenes/main.tscn -- --autoplay --shots=/tmp/ap
##   --start=route   skip the lab (get EMBERPUP and go straight to Route 1)
##   --until=lab     stop after the lab scene

var main: Node
var shots := ""
var _shot_t := 0.0
var _n := 0
var _t := 0.0


func _ready() -> void:
	shots = Game.args.get("shots", "")
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	_run()


func _process(delta: float) -> void:
	_t += delta
	_shot_t += delta
	if shots != "" and _shot_t > float(Game.args.get("every", "1.5")):
		_shot_t = 0.0
		shot("auto")
	if _t > float(Game.args.get("timeout", "900")):
		print("AUTOPLAY: timeout")
		get_tree().quit(1)


func shot(tag: String) -> void:
	if shots == "":
		return
	_n += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%03d_%s.png" % [shots, _n, tag])


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


## Walk to a spot, pausing whenever something else (a battle, a talk) is
## going on. Stops early if a door takes you somewhere else.
func walk(p: Vector3) -> void:
	var area: String = main.area
	var stuck := 0.0
	var last: Vector3 = main.player.global_position
	while main.area == area:
		await get_tree().physics_frame
		if main.busy:
			main.player.auto_move = Vector3.ZERO
			continue
		var d: Vector3 = p - main.player.global_position
		d.y = 0
		if d.length() < 0.6:
			break
		main.player.auto_move = d.normalized() * 1.6
		stuck += get_physics_process_delta_time()
		if stuck > 2.0:
			if main.player.global_position.distance_to(last) < 0.5:
				print("AUTOPLAY: stuck at ", main.player.global_position, " going to ", p)
				# step sideways for a moment
				main.player.auto_move = Vector3(-d.z, 0, d.x).normalized() * 1.6
				await get_tree().create_timer(0.4).timeout
			stuck = 0.0
			last = main.player.global_position
	main.player.auto_move = Vector3.ZERO


func idle() -> void:
	while main.busy:
		await get_tree().process_frame


func _run() -> void:
	await get_tree().process_frame
	var start: String = Game.args.get("start", "")
	await main.begin(true)
	await idle()
	shot("start")
	if start == "route":
		Game.set_flag("met_prof")
		Game.set_flag("starter", "emberpup")
		Game.add_mon(Dex.make("emberpup", 6))
		Game.give("ball", 5)
		Game.give("potion", 3)
		main.apply_story()
		main.player.teleport(Vector3(0, 0, -30), 0.0)
		main.rig.snap()
	else:
		# walk to the lab and go in
		for p in [Vector3(-12, 0, 6), Vector3(-6, 0, -4), Vector3(6, 0, -7), Vector3(12, 0, -8.5), Vector3(12, 0, -10.4)]:
			await walk(p)
		await idle()
		shot("lab")
		# walk up to the table and look at the first ball
		var bp: Vector3 = main.lab.ball_pos(0)
		await walk(Vector3(bp.x, 0, bp.z + 1.7))
		await idle()
		shot("table")
		main.busy = true
		await main._interact({"starter": 0})
		main.busy = false
		shot("chosen")
		print("AUTOPLAY: starter ", Game.flags.get("starter"), " party ", Game.party.size(), " balls ", Game.bag.ball)
		if Game.args.get("until", "") == "lab":
			get_tree().quit(0)
			return
		await walk(Lab.ORIGIN + Lab.EXIT)
		await idle()
		await _wait(0.5)
	# up Route 1, through tall grass, past the trainers
	var path := [Vector3(0, 0, -40), Vector3(-8, 0, -52), Vector3(-15, 0, -60), Vector3(-6, 0, -62), Vector3(8, 0, -62),
		Vector3(8, 0, -80), Vector3(-4, 0, -98), Vector3(-12, 0, -104), Vector3(-4, 0, -110), Vector3(-4, 0, -120),
		Vector3(6, 0, -134), Vector3(6, 0, -146), Vector3(12, 0, -146), Vector3(19, 0, -144), Vector3(6, 0, -146),
		Vector3(6, 0, -156), Vector3(-2, 0, -172), Vector3(0, 0, -190), Vector3(0, 0, -202)]
	for p in path:
		await walk(p)
		print("AUTOPLAY: at ", p, " party ", _party_text(), " beaten ", _beaten())
		if not Game.can_battle():
			await idle()
	await idle()
	await _wait(1.0)
	shot("end")
	print("AUTOPLAY: done. champion=", Game.flag("champion"), " party ", _party_text(), " caught ", Game.caught.keys())
	get_tree().quit(0)


func _party_text() -> String:
	var t := []
	for m in Game.party:
		t.append("%s L%d %d/%d" % [m.sp, m.lv, m.hp, Dex.max_hp(m)])
	return ", ".join(t)


func _beaten() -> Array:
	var b := []
	for k in Game.flags:
		if String(k).begins_with("beat_"):
			b.append(k)
	return b
