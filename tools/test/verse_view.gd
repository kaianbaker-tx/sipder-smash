extends Node3D
## Renders the generated verses one by one, two pictures each:
## godot res://tools/test/verse_view.tscn -- --from=0 --to=49 --out=/some/dir
var frames := 0
var cam: Camera3D
var look: Node
var d: DimWorld
var hero: Node3D
var bots: Array = []
var shots := []
var shot := 0
var idx := 0
var last := 49
var out := "user://verses"
var logf: FileAccess


func note(t: String) -> void:
	logf.store_line(t)
	logf.flush()


func _ready() -> void:
	idx = int(Game.args.get("from", "0"))
	last = mini(int(Game.args.get("to", str(Verses.count() - 1))), Verses.count() - 1)
	out = Game.args.get("out", out)
	DirAccess.make_dir_recursive_absolute(out)
	logf = FileAccess.open(out + "/log.txt", FileAccess.WRITE)
	look = load("res://scripts/comic_look.gd").new()
	add_child(look)
	cam = Camera3D.new()
	add_child(cam)
	cam.near = 0.3
	cam.far = 1200
	cam.fov = 70
	look.attach(cam)
	hero = HeroModel.new()
	hero.skin = load("res://assets/hero/suits/classic.png")
	add_child(hero)
	_load_verse()


func _load_verse() -> void:
	if d:
		d.queue_free()
	for b in bots:
		(b as Node).queue_free()
	bots.clear()
	d = DimWorld.new()
	d.setup(Verses.get_theme(idx))
	add_child(d)
	var t0 := Time.get_ticks_msec()
	d.ensure_built()
	note("%02d %s built in %d ms, safe %d gate %d bots %d" % [idx, d.title, Time.get_ticks_msec() - t0, d.safe_spots.size(), d.gate_spots.size(), d.bot_spots.size()])
	look.apply_palette(d.palette)
	hero.position = d.start_pos
	for i in 3:
		var b := GlitchBot.new()
		add_child(b)
		b.global_position = d.start_pos + Vector3(-4 + i * 4, 5, -12)
		bots.append(b)
	var s := d.start_pos
	shots = [
		[s + Vector3(0, 4, 9), s + Vector3(0, 7, -30)],
		[Vector3(150, 110, 190), Vector3(0, 15, 0)],
	]
	shot = 0
	frames = 0
	_frame_shot()


func _frame_shot() -> void:
	cam.position = shots[shot][0]
	cam.look_at(shots[shot][1])


func _process(_delta: float) -> void:
	frames += 1
	if frames < 8:
		return
	frames = 0
	get_viewport().get_texture().get_image().save_png("%s/v%02d_%d.png" % [out, idx, shot])
	shot += 1
	if shot < shots.size():
		_frame_shot()
		return
	idx += 1
	if idx > last:
		note("done")
		get_tree().quit()
		return
	_load_verse()
