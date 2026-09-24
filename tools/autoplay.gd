extends Node
## Test driver: presses buttons on a timeline and saves screenshots.
## godot res://scenes/main.tscn -- --autoplay=swing --shots=dir

var main: Node
var t := 0.0
var shots_dir := "/tmp/claude-0/-home-user-sipder-smash/a2a12b10-57b3-5066-938b-7aa665ee9353/scratchpad/auto"
var script_name := "swing"
var _next_shot := 0
var timeline := []
var shot_times := []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	script_name = Game.args.get("autoplay", "swing")
	if Game.args.has("shots"):
		shots_dir = Game.args["shots"]
	DirAccess.make_dir_recursive_absolute(shots_dir)
	match script_name:
		"swing":
			timeline = [
				[0.5, "press", "move_forward"],
				[1.0, "press", "jump"], [1.1, "release", "jump"],
				[1.3, "press", "swing"],
				[2.6, "release", "swing"],
				[2.9, "press", "swing"],
				[4.2, "release", "swing"],
				[4.5, "press", "swing"],
				[5.8, "release", "swing"],
				[7.0, "release", "move_forward"],
				[8.0, "quit", ""],
			]
			shot_times = [0.8, 1.6, 2.2, 3.2, 3.8, 4.8, 5.4, 6.3, 7.5]
		"fight":
			timeline = [
				[0.5, "press", "move_forward"],
				[1.0, "release", "move_forward"],
				[1.2, "tap", "zip"],
				[2.0, "tap", "smash"],
				[2.4, "tap", "smash"],
				[2.8, "tap", "smash"],
				[3.3, "tap", "web"],
				[4.0, "tap", "smash"],
				[4.4, "tap", "smash"],
				[6.0, "quit", ""],
			]
			shot_times = [0.9, 1.5, 2.05, 2.45, 2.85, 3.4, 4.1, 4.5, 5.5]
		"climb":
			timeline = [
				[0.3, "press", "move_forward"],
				[5.5, "release", "move_forward"],
				[6.0, "quit", ""],
			]
			shot_times = [1.0, 2.0, 3.0, 4.0, 5.0]
		"auto":
			var secs := float(Game.args.get("secs", "60"))
			timeline = [[secs, "quit", ""]]
			var every := float(Game.args.get("every", "5"))
			var k := every
			while k < secs:
				shot_times.append(k)
				k += every
		"race":
			timeline = [[0.2, "press", "swing"], [1.4, "release", "swing"], [1.6, "press", "swing"], [2.8, "release", "swing"], [4.0, "quit", ""]]
			shot_times = [0.6, 1.5, 3.0]
		"slam":
			timeline = [[0.4, "tap", "smash"], [4.0, "quit", ""]]
			shot_times = [0.5, 0.9, 1.3, 1.5, 1.8, 2.5]
		"boss":
			timeline = [[9.0, "quit", ""]]
			shot_times = [3.0, 3.6, 4.4, 6.0, 8.0]
		"cover":
			timeline = [[2.0, "tap", "cover"], [4.0, "quit", ""]]
			shot_times = [3.5]
		"pause":
			timeline = [[1.0, "tap", "pause"], [3.0, "quit", ""]]
			shot_times = [2.5]
		"title":
			timeline = [[4.0, "quit", ""]]
			shot_times = [1.5, 3.5]
		"story":
			timeline = [[12.0, "quit", ""]]
			shot_times = [1.0, 3.5, 6.0, 9.0, 10.5, 11.5]
		_:
			timeline = [[4.0, "quit", ""]]
			shot_times = [1.0, 3.0]


var _ai_t := 0.0
var _practice := 0


func _autopilot(delta: float) -> void:
	# a tiny robot player: face the nearest bot, zip to it, smash it
	_ai_t -= delta
	var p: Player = main.player
	var rig: CamRig = main.rig
	var best: Node3D = null
	var bd := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := (e as Node3D).global_position.distance_to(p.center())
		if d < bd:
			bd = d
			best = e
	if best:
		var to := best.global_position - rig.cam.global_position
		rig.yaw = atan2(-to.x, -to.z)
		rig.pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 0.8)
	if _ai_t > 0.0:
		return
	_ai_t = 0.35
	var act := ""
	var clear := false
	if best:
		var q := PhysicsRayQueryParameters3D.create(p.center(), best.global_position, 1)
		clear = p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	Input.action_release("move_forward")
	Input.action_release("swing")
	if best and bd < 15.0:
		act = "smash" if randf() < 0.8 else "web"
	elif best and clear and bd < 75.0:
		act = "zip"
	elif best:
		# no line of sight: travel toward it
		Input.action_press("move_forward")
		if p.state == Player.State.GROUND:
			act = "jump"
		elif p.state == Player.State.AIR:
			Input.action_press("swing")
	else:
		# nothing to fight: practise swinging and zipping
		Input.action_press("move_forward")
		_practice += 1
		if p.state == Player.State.GROUND:
			act = "jump"
		elif p.state == Player.State.AIR and _practice % 6 != 5:
			Input.action_press("swing")
		elif _practice % 6 == 5:
			rig.pitch = 0.25
			act = "zip"
	if act != "":
		Input.action_press(act)
		get_tree().create_timer(0.06).timeout.connect(func() -> void: Input.action_release(act))


func _process(delta: float) -> void:
	t += delta
	if script_name == "auto" and main.mode == 1:
		_autopilot(delta)
	while not timeline.is_empty() and t >= timeline[0][0]:
		var ev: Array = timeline.pop_front()
		match ev[1]:
			"press":
				Input.action_press(ev[2])
			"release":
				Input.action_release(ev[2])
			"tap":
				Input.action_press(ev[2])
				get_tree().create_timer(0.05).timeout.connect(func() -> void: Input.action_release(ev[2]))
			"quit":
				get_tree().quit()
	if _next_shot < shot_times.size() and t >= shot_times[_next_shot]:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%02d.png" % [shots_dir, script_name, _next_shot])
		var p: Node = main.player
		print("shot ", _next_shot, " t=", snappedf(t, 0.01), " ch=", main.chapter, " state=", p.state, " hp=", p.hp, " pos=", p.global_position.snapped(Vector3.ONE * 0.1), " bots=", get_tree().get_nodes_in_group("enemies").size(), " score=", Game.score, " fps=", Engine.get_frames_per_second(), " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " objs=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		_next_shot += 1
