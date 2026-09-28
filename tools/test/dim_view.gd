extends Node3D
## Renders a dimension from a few spots: godot res://tools/test/dim_view.tscn -- --dim=noir
var frames := 0
var cam: Camera3D
var shots := []
var idx := 0
var dim_name := "noir"
var prefix := "/tmp/claude-0/-home-user-sipder-smash/a2a12b10-57b3-5066-938b-7aa665ee9353/scratchpad/dim_"
var logf: FileAccess
func note(t: String) -> void:
	logf.store_line(t); logf.flush()
func _ready() -> void:
	logf = FileAccess.open("res://tools/test/dim_view.log", FileAccess.WRITE)
	dim_name = Game.args.get("dim", "noir")
	note("start " + dim_name)
	var look: Node = load("res://scripts/comic_look.gd").new(); add_child(look)
	var d: Dimension = load("res://scripts/dim_%s.gd" % dim_name).new()
	add_child(d)
	var t0 := Time.get_ticks_msec()
	d.ensure_built()
	note("built in %d ms" % (Time.get_ticks_msec() - t0))
	look.apply_palette(d.palette)
	var h := HeroModel.new(); h.skin = load("res://assets/hero/suits/classic.png"); add_child(h)
	h.position = d.start_pos
	for i in 3:
		var b := GlitchBot.new(); add_child(b); b.global_position = d.start_pos + Vector3(-4 + i * 4, 4, -10)
	cam = Camera3D.new(); add_child(cam); cam.near = 0.3; cam.far = 1200; cam.fov = 70
	look.attach(cam)
	shots = [
		[d.start_pos + Vector3(0, 4, 9), d.start_pos + Vector3(0, 6, -30)],
		[Vector3(120, 90, 160), Vector3(0, 20, 0)],
		[Vector3(0, 30, 60), Vector3(0, 120, -80)],
	]
	_frame_shot()
func _frame_shot() -> void:
	cam.position = shots[idx][0]; cam.look_at(shots[idx][1])
func _process(_d: float) -> void:
	frames += 1
	if frames % 10 == 0:
		note("shot %d frame %d" % [idx, frames])
		get_viewport().get_texture().get_image().save_png(prefix + dim_name + str(idx) + ".png")
		idx += 1
		if idx >= shots.size(): get_tree().quit(); return
		_frame_shot()
