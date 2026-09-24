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
		_:
			timeline = [[4.0, "quit", ""]]
			shot_times = [1.0, 3.0]


func _process(delta: float) -> void:
	t += delta
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
		print("shot ", _next_shot, " t=", snappedf(t, 0.01), " state=", p.state, " pos=", p.global_position.snapped(Vector3.ONE * 0.1), " vel=", p.velocity.snapped(Vector3.ONE * 0.1))
		_next_shot += 1
