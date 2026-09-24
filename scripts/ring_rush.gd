extends Node3D
## RING RUSH: a swinging race. Fly through the big glowing START ring over
## the park, then hit every ring before the clock runs out.

signal status(text: String)

const TIME_LIMIT := 75.0

var rings: Array[MeshInstance3D] = []
var start_ring: MeshInstance3D
var active := false
var next := 0
var time_left := 0.0
var best := 0.0
var player: Player
var _mat_next: StandardMaterial3D
var _mat_idle: StandardMaterial3D
var _mat_start: StandardMaterial3D
var _t := 0.0
var _cool := 0.0


func setup(city: Node) -> void:
	_mat_next = _mat(Color(1, 0.9, 0.15))
	_mat_idle = _mat(Color(0.35, 0.9, 1.0))
	_mat_start = _mat(Color(1, 0.25, 0.6))
	# a loop through downtown, rising and falling between the towers
	var route := [
		Vector3(96, 22, -64), Vector3(64, 30, -32), Vector3(32, 38, 0), Vector3(0, 30, 32),
		Vector3(-32, 42, 64), Vector3(-64, 34, 32), Vector3(-64, 28, 0), Vector3(-64, 46, -32),
		Vector3(-32, 55, -64), Vector3(0, 40, -96), Vector3(32, 30, -128), Vector3(64, 24, -128),
	]
	for i in route.size():
		var r := _ring(6.0)
		var p: Vector3 = route[i]
		var nxt: Vector3 = route[(i + 1) % route.size()]
		r.position = p
		_face(r, (nxt - p).normalized())
		r.visible = false
		rings.append(r)
	start_ring = _ring(8.0)
	start_ring.material_override = _mat_start
	var park := Vector3(96, 0, -96)
	start_ring.position = park + Vector3(0, 16, 0)
	_face(start_ring, (rings[0].position - start_ring.position).normalized())
	var cfg := ConfigFile.new()
	if cfg.load("user://spider_smash.cfg") == OK:
		best = cfg.get_value("race", "best", 0.0)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _ring(r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.7
	tm.outer_radius = r
	tm.rings = 32
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = _mat_idle
	add_child(mi)
	return mi


func _face(r: Node3D, dir: Vector3) -> void:
	# torus lies flat in XZ; stand it up facing along dir
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD
	r.basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI * 0.5)


func _process(delta: float) -> void:
	_t += delta
	_cool -= delta
	if not player:
		player = get_tree().get_first_node_in_group("player") as Player
		return
	if not Game.playing:
		return
	var c := player.center()
	start_ring.visible = not active
	start_ring.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.05)
	if not active:
		if _cool <= 0.0 and c.distance_to(start_ring.global_position) < 8.5:
			_start()
		return
	time_left -= delta
	for i in rings.size():
		rings[i].visible = i >= next
		rings[i].material_override = _mat_next if i == next else _mat_idle
	if next < rings.size():
		var r := rings[next]
		r.scale = Vector3.ONE * (1.0 + sin(_t * 8.0) * 0.08)
		if c.distance_to(r.global_position) < 6.5:
			next += 1
			Sfx.play("token", 0.0)
			Fx.ring(r.global_position, Color(1, 0.9, 0.2, 0.9), 9.0, (r.global_basis.y).normalized())
			Fx.word("%d/%d" % [next, rings.size()], r.global_position + Vector3(0, 3, 0), "small", Color(1, 0.9, 0.2))
			if next >= rings.size():
				_finish()
				return
	status.emit("RING RUSH  %d/%d   %0.1f s" % [next, rings.size(), maxf(time_left, 0.0)])
	if time_left <= 0.0:
		active = false
		_cool = 3.0
		Game.say("TIME UP! TRY AGAIN!", 2.5)
		Sfx.play("hurt")
		_hide_rings()
		status.emit("")


func _start() -> void:
	active = true
	next = 0
	time_left = TIME_LIMIT
	Game.say("RING RUSH! GO GO GO!", 2.0)
	Sfx.play("chapter")
	Fx.word("GO!", start_ring.global_position, "big", Color(1, 0.9, 0.2))


func _finish() -> void:
	active = false
	_cool = 5.0
	var used := TIME_LIMIT - time_left
	var record := best <= 0.0 or used < best
	if record:
		best = used
		var cfg := ConfigFile.new()
		cfg.load("user://spider_smash.cfg")
		cfg.set_value("race", "best", best)
		cfg.save("user://spider_smash.cfg")
	Game.add_score(2000)
	Game.say(("NEW RECORD! " if record else "FINISHED! ") + "%0.1f s" % used, 3.5)
	Sfx.play("win")
	Sfx.play("cheer")
	_hide_rings()
	status.emit("")


func _hide_rings() -> void:
	for r in rings:
		r.visible = false
