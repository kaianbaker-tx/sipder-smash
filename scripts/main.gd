extends Node3D
## Spideys of the Multiverse director: builds the world, runs the title screen,
## the story chapters, the trips through the portals to other dimensions, the
## boss fight in the Glitch-Verse and the win screen.

enum Mode { TITLE, PLAY, WIN }

var look: Node
var city: Node3D
var traffic: Node3D
var people: Node3D
var tokens: Node3D
var portal: Node3D
var player: Player
var rig: CamRig
var hud: Hud
var title_ui: CanvasLayer
var menus: CanvasLayer
var touch: CanvasLayer
var title_cam: Camera3D
var boss: GlitchKing
var cover: CanvasLayer
var race: Node3D
var birds: Node3D
var dims: Array = [null, null, null]   # built the first time you visit
var dim: Dimension                     # where we are now (null = home city)
var gate: Gate                         # the open portal, if any
var _gate_to := -1                     # which dimension it leads to (-1 = home)
var _home_nodes: Array = []
var _roam_next := 0
var _dims_visited := 0

var mode := Mode.TITLE
var chapter := 0
var step := 0
var objective_bots: Array = []
var _obj_total := 0
var _swings := 0
var _zips := 0
var _title_t := 0.0
var _title_spot := Vector3.ZERO
var _title_look := Vector3.ZERO
var _play_time := 0.0
var _free_roam := false
var _roam_t := 0.0
var _last_state := -1
var _chapter_wait := 0.0
var _boss_started := false
var _was_captured := false

const START := Vector3(8, 1, 40)
const DIM_SCRIPTS := ["res://scripts/dim_noir.gd", "res://scripts/dim_candy.gd", "res://scripts/dim_glitch.gd"]
# each dimension sits far away from the city (and from each other)
const DIM_POS := [Vector3(4000, 0, 0), Vector3(0, 0, 4000), Vector3(-4000, 0, 0)]
const DIM_NAMES := ["NOIR-VERSE", "CANDY-VERSE", "GLITCH-VERSE"]


func _ready() -> void:
	look = load("res://scripts/comic_look.gd").new()
	look.name = "Look"
	add_child(look)
	city = load("res://scripts/city.gd").new()
	city.name = "City"
	city.add_to_group("city")
	add_child(city)
	traffic = load("res://scripts/traffic.gd").new()
	traffic.name = "Traffic"
	add_child(traffic)
	people = load("res://scripts/pedestrians.gd").new()
	people.name = "People"
	add_child(people)
	tokens = load("res://scripts/tokens.gd").new()
	tokens.name = "Tokens"
	add_child(tokens)
	tokens.setup(city)
	birds = load("res://scripts/birds.gd").new()
	birds.name = "Birds"
	add_child(birds)
	race = load("res://scripts/ring_rush.gd").new()
	race.name = "RingRush"
	add_child(race)
	race.setup(city)
	portal = load("res://scripts/portal.gd").new()
	portal.name = "Portal"
	add_child(portal)
	portal.global_position = city.tower_top + Vector3(0, 60, 0)
	RenderingServer.global_shader_parameter_set("portal_power", 0.0)
	_home_nodes = [city, traffic, people, tokens, birds, race, portal]

	player = Player.new()
	player.name = "Player"
	add_child(player)
	rig = CamRig.new()
	rig.target = player
	add_child(rig)
	player.rig = rig
	title_cam = Camera3D.new()
	title_cam.near = 0.3
	title_cam.far = 1200.0
	title_cam.fov = 55.0
	add_child(title_cam)
	Fx.setup(self, rig, look)

	hud = Hud.new()
	add_child(hud)
	Game.tokens_changed.emit(Game.tokens)
	hud.bind(player, rig)
	hud.radar_things = _radar_things
	race.status.connect(func(t: String) -> void: hud.set_race(t))
	menus = load("res://scripts/menus.gd").new()
	add_child(menus)
	menus.resume.connect(_resume)
	menus.quit_to_title.connect(_to_title)
	menus.keep_playing.connect(_keep_playing)
	touch = load("res://scripts/touch_controls.gd").new()
	add_child(touch)
	touch.rig = rig
	touch.pause_pressed = func() -> void: _set_paused(true)
	touch.cover_pressed = func() -> void: _open_cover()
	cover = load("res://scripts/cover_mode.gd").new()
	add_child(cover)
	cover.closed.connect(_close_cover)
	title_ui = load("res://scripts/title_ui.gd").new()
	add_child(title_ui)
	title_ui.play_pressed.connect(_start_game)
	title_ui.suit_preview.connect(func(s: String) -> void:
		player.model.set_skin(load(Game.SUITS[s].tex))
		look.set_noir(s == "noir"))
	Game.suit_changed.connect(func(s: String) -> void: look.set_noir(s == "noir"))
	player.knocked_out.connect(func() -> void: Game.end_combo())

	if Game.args.has("suit"):
		Game.suit = Game.args.suit
	if Game.args.has("touch"):
		Game.enable_touch()
		touch.visible = true
	if Game.args.has("autoplay"):
		var ap: Node = load("res://tools/autoplay.gd").new()
		ap.main = self
		add_child(ap)
		if Game.args.autoplay == "title":
			_to_title()
			match Game.args.get("panel", ""):
				"suits":
					title_ui._toggle_suits()
					title_ui._cycle(1)
				"help":
					title_ui._help.visible = true
		else:
			_start_game()
			if Game.args.has("chapter"):
				_skip_to(Game.args.chapter.to_int())
			if Game.args.has("dim"):
				_travel(_get_dim(Game.args.dim.to_int()))
			if Game.args.autoplay == "race":
				hud._captions.clear()
				_chapter_wait = 0.0
				player.respawn(race.start_ring.global_position + Vector3(0, -1, 0))
				var d: Vector3 = race.rings[0].global_position - race.start_ring.global_position
				rig.yaw = atan2(-d.x, -d.z)
				rig.pitch = -0.1
			if Game.args.autoplay == "street":
				hud._captions.clear()
				_chapter_wait = 0.0
				player.respawn(Vector3(58, 0.5, 58))
				rig.yaw = PI * 0.75
				rig.pitch = -0.05
			if Game.args.autoplay == "slam":
				hud._captions.clear()
				_chapter_wait = 0.0
				player.respawn(Vector3(8, 70, 30))
				rig.yaw = 0.0
				rig.pitch = -0.9
				for i in 3:
					var b := GlitchBot.new()
					add_child(b)
					b.global_position = Vector3(4 + i * 4, 4, 30 - i * 3)
					b.home = b.global_position
	else:
		_to_title()


# ------------------------------------------------------------------ title

func _pick_title_spot() -> void:
	# a roof edge on the far side from the tower: the camera floats past the
	# edge and looks back at the hero, with the tower and portal behind
	var best: Dictionary = {}
	var bd := INF
	for b in city.buildings:
		var info := b as Dictionary
		if info.name == "tower":
			continue
		var top: float = info.top
		if top < 28.0 or top > 70.0:
			continue
		var d := (info.pos as Vector3).distance_to(city.tower_pos)
		if d < 110.0 or d > 190.0:
			continue
		if d < bd:
			bd = d
			best = info
	if best.is_empty():
		_title_spot = START
		_title_look = Vector3(0, 0, 1)
		return
	var box: AABB = best.box
	var c := Vector3(box.get_center().x, best.top, box.get_center().z)
	var away: Vector3 = c - (city.tower_pos as Vector3)
	away.y = 0
	away = away.normalized()
	# snap to the box face that points most away from the tower
	var axis := Vector3(signf(away.x), 0, 0) if absf(away.x) > absf(away.z) else Vector3(0, 0, signf(away.z))
	var half := absf(axis.x) * box.size.x * 0.5 + absf(axis.z) * box.size.z * 0.5
	_title_spot = c + axis * (half - 1.2)
	_title_look = axis


func _to_title() -> void:
	mode = Mode.TITLE
	if dim:
		_travel(null)
	_close_gate()
	Sfx.set_wind(0.0)
	Game.playing = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	menus.show_pause(false)
	_clear_bots()
	if boss and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	hud.visible = false
	hud.set_boss(null)
	hud.set_objective("")
	hud._captions.clear()
	_chapter_wait = 0.0
	_free_roam = false
	chapter = 0
	_dims_visited = 0
	title_ui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pick_title_spot()
	player.respawn(_title_spot + Vector3(0, 0.5, 0))
	player.enabled = false
	player.velocity = Vector3.ZERO
	player.global_position = _title_spot
	player.model.set_skin(Game.suit_texture())
	player.model.play("idle")
	player.model.global_transform = Transform3D(Basis.looking_at(_title_look, Vector3.UP), _title_spot)
	look.attach(title_cam)
	title_cam.current = true
	# light the hero from the front for the poster shot
	var side := _title_look.cross(Vector3.UP)
	RenderingServer.global_shader_parameter_set("sun_dir", (_title_look * 0.8 + Vector3.UP * 0.5 + side * 0.4).normalized())
	look.set_noir(Game.suit == "noir")
	portal.visible = true
	portal.closing = false
	portal.disc.scale = Vector3(90, 90, 1)
	Sfx.music("title")


func _start_game() -> void:
	if mode == Mode.PLAY:
		return
	mode = Mode.PLAY
	if _title_spot == Vector3.ZERO:
		_pick_title_spot()
	Game.reset_run()
	tokens.reset()
	Game.tokens_changed.emit(0)
	Game.playing = true
	title_ui.visible = false
	hud.visible = true
	player.model.set_skin(Game.suit_texture())
	look.set_noir(Game.suit == "noir")
	player.enabled = true
	player.respawn(_title_spot - _title_look * 2.0 + Vector3(0, 0.5, 0))
	player.invuln = 0.0
	rig.yaw = atan2(_title_look.x, _title_look.z)
	rig.pitch = -0.1
	look.attach(rig.cam)
	rig.cam.current = true
	look.apply_palette({})
	_capture()
	_play_time = 0.0
	_free_roam = false
	_boss_started = false
	Sfx.music("city")
	chapter = 0
	hud.narrate([
		"Okay. Let's do this one more time...",
		"A GLITCH PORTAL just ripped open above the city!",
		"Robots from other DIMENSIONS are pouring out...",
		"Only one spider can chase them across the multiverse. YOU!",
	], 2.4)
	_chapter_wait = 9.8


func _skip_to(n: int) -> void:
	hud._captions.clear()
	_chapter_wait = 0.1
	chapter = n - 1


# ------------------------------------------------------------------ chapters

func _next_chapter() -> void:
	chapter += 1
	step = 0
	match chapter:
		1:
			hud.chapter_card("CHAPTER 1", "WEB-SLINGER 101")
			hud.set_hint_visible(true)
			_swings = 0
			_zips = 0
			hud.narrate(["Jump, then HOLD right mouse (or SHIFT) to swing!"], 3.5)
			hud.set_objective("SWING 3 TIMES  (0/3)")
		2:
			hud.chapter_card("CHAPTER 2", "BOT BLITZ!")
			hud.narrate(["Glitch-Bots are ALL OVER the city!", "Follow the pink arrows. Smash 'em!", "Watch out for SPEEDY bots and MEGA-BOTS!"], 2.6)
			_spawn_group([["normal", 14], ["speedy", 5], ["big", 3]], null)
			hud.set_hint_visible(false)
		3, 4, 5:
			_enter_dimension(chapter - 3)


func _process(delta: float) -> void:
	if mode == Mode.TITLE:
		_title_t += delta
		var a := sin(_title_t * 0.2) * 0.35
		var dir := _title_look.rotated(Vector3.UP, a + 0.3)
		title_cam.global_position = _title_spot + dir * 6.5 + Vector3(0, 0.6, 0)
		title_cam.look_at(_title_spot + Vector3(0, 2.2, 0) + dir.cross(Vector3.UP) * 2.4)
		return
	if mode != Mode.PLAY:
		return
	look.speed = clampf((player.velocity.length() - 24.0) / 22.0, 0.0, 1.0)
	Sfx.set_wind(clampf((player.velocity.length() - 12.0) / 30.0, 0.0, 1.0) if not get_tree().paused else 0.0)
	_play_time += delta
	if Input.is_action_just_pressed("pause") or (menus.is_paused_open() and Input.is_action_just_pressed("ui_cancel")):
		_set_paused(not get_tree().paused)
	if Input.is_action_just_pressed("cover") and not get_tree().paused:
		_open_cover()
	# the browser lets go of the mouse when Esc is pressed: open the pause menu
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _was_captured and not captured and not get_tree().paused and not Game.touch_mode:
		_set_paused(true)
	_was_captured = captured
	# count swings / zips for the tutorial
	if player.state != _last_state:
		if player.state == Player.State.SWING:
			_swings += 1
		if player.state == Player.State.ZIP:
			_zips += 1
		_last_state = player.state
	if _chapter_wait > 0.0:
		_chapter_wait -= delta
		if _chapter_wait <= 0.0:
			_next_chapter()
		return
	match chapter:
		1:
			_chapter1()
		2, 3, 4, 5:
			_wave_progress()
	if _free_roam:
		_roam(delta)
	hud.track = [gate] if gate else objective_bots


var _hint_t := 0.0


func _chapter1() -> void:
	# repeat the tip if the player seems stuck
	_hint_t += get_process_delta_time()
	if _hint_t > 16.0 and step < 2 and not hud.captions_busy():
		_hint_t = 0.0
		if step == 0:
			hud.narrate(["TIP: jump off the roof, then HOLD right mouse / SHIFT!"], 3.5)
		else:
			hud.narrate(["TIP: point the web at a building and press E!"], 3.5)
	match step:
		0:
			hud.set_objective("SWING 3 TIMES  (%d/3)" % mini(_swings, 3))
			if _swings >= 3:
				step = 1
				_hint_t = 0.0
				Game.say("NICE SWINGING!", 1.6)
				hud.narrate(["Now aim at a rooftop and press E to WEB-ZIP!"], 3.5)
		1:
			hud.set_objective("WEB-ZIP ONCE  (press E)")
			if _zips >= 1:
				step = 2
				Game.say("THWIP-TASTIC!", 1.6)
				hud.narrate(["Here they come! LEFT CLICK to SMASH. F shoots web!"], 3.5)
				_spawn_wave(6, false, true, player.global_position)
		2:
			_wave_progress()


func _wave_progress() -> void:
	var alive := []
	for b in objective_bots:
		if is_instance_valid(b) and not b.dead:
			alive.append(b)
	objective_bots = alive
	var done := _obj_total - alive.size()
	if _obj_total > 0:
		var where := dim.title if dim else "CITY"
		hud.set_objective("%s: SMASH THE BOTS  (%d/%d)" % [where, done, _obj_total])
	if alive.is_empty() and _obj_total > 0:
		_obj_total = 0
		hud.set_objective("")
		Sfx.play("cheer")
		Game.say(["AMAZING!", "SPECTACULAR!", "SPIDER-TASTIC!"][chapter % 3], 2.0)
		match chapter:
			1:
				_chapter_wait = 2.5
			2, 3, 4:
				# the bots came from somewhere... follow them!
				get_tree().create_timer(1.6).timeout.connect(func() -> void:
					if mode == Mode.PLAY and not _free_roam:
						_open_gate(chapter - 2))
			5:
				hud.narrate(["The ground is shaking...", "HERE COMES THE GLITCH KING!"], 1.8)
				get_tree().create_timer(3.4).timeout.connect(_start_boss)


# ------------------------------------------------------------------ bots

func _spawn_wave(count: int, big: bool, objective := true, near := Vector3.INF, speedy := 0) -> void:
	var spots: Array = city.roof_spots.duplicate()
	spots.shuffle()
	var from := portal.global_position
	if objective:
		_obj_total = count
		objective_bots = []
	for i in count:
		var home: Vector3
		if near != Vector3.INF:
			var a := i * TAU / count
			home = near + Vector3(cos(a) * 16.0, 10.0 + i * 1.5, sin(a) * 16.0)
		else:
			# spread over the city, prefer the middle
			var s: Vector3 = spots[i % spots.size()]
			if s.length() > 170.0:
				s = spots[(i + 7) % spots.size()]
			home = s + Vector3(0, 8.0 + randf() * 8.0, 0)
		var b := GlitchBot.new()
		b.big = big
		b.speedy = i < speedy
		add_child(b)
		# they come flying out of the portal
		b.global_position = from.lerp(home, 0.75 if near == Vector3.INF else 0.92) + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
		b.home = home
		if objective:
			objective_bots.append(b)
	Fx.glitch(0.5)
	Sfx.play("glitch", 0.1)


## A big mixed group of objective bots: plan = [["normal", 10], ["speedy", 3], ["big", 2]].
## d = the dimension to fill, or null for the home city.
func _spawn_group(plan: Array, d: Dimension) -> void:
	var spots: Array = d.global_bot_spots() if d else _city_spots()
	spots.shuffle()
	var from := d.to_global(Vector3(0, 90, 0)) if d else portal.global_position
	objective_bots = []
	var i := 0
	for entry in plan:
		for k in (entry[1] as int):
			var b := GlitchBot.new()
			b.big = entry[0] == "big"
			b.speedy = entry[0] == "speedy"
			add_child(b)
			var home: Vector3 = (spots[i % spots.size()] as Vector3) + Vector3(randf_range(-5, 5), randf_range(0, 5), randf_range(-5, 5))
			b.global_position = from.lerp(home, 0.8) + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			b.home = home
			objective_bots.append(b)
			i += 1
	_obj_total = i
	Fx.glitch(0.6)
	Sfx.play("glitch", 0.1)


func _city_spots() -> Array:
	var out := []
	for s in city.roof_spots:
		if (s as Vector3).length() < 170.0:
			out.append((s as Vector3) + Vector3(0, 8.0 + randf() * 8.0, 0))
	return out


func _clear_bots() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Node).queue_free()
	objective_bots.clear()
	_obj_total = 0


func _roam(delta: float) -> void:
	_roam_t -= delta
	if _roam_t <= 0.0:
		_roam_t = 15.0
		if get_tree().get_nodes_in_group("enemies").size() < 12:
			if dim:
				var spots := dim.global_bot_spots()
				for i in 4:
					var b := GlitchBot.new()
					b.speedy = randf() < 0.3
					b.big = randf() < 0.15
					add_child(b)
					b.global_position = spots[randi() % spots.size()]
					b.home = b.global_position
			else:
				_spawn_wave(5, randf() < 0.25, false)
	var where := dim.title if dim else "THE CITY"
	hud.set_objective("FREE ROAM in %s!  Tokens: %d   Bots: %d" % [where, Game.tokens, Game.bots_smashed])


# ------------------------------------------------------------------ dimensions

func _get_dim(i: int) -> Dimension:
	if dims[i] == null:
		var d: Dimension = load(DIM_SCRIPTS[i]).new()
		d.name = DIM_NAMES[i]
		add_child(d)
		d.position = DIM_POS[i]
		d.ensure_built()
		d.visible = false
		d.process_mode = Node.PROCESS_MODE_DISABLED
		dims[i] = d
	return dims[i]


## Jump to a dimension (or home when d is null): swap the visible world,
## the colours and the music, and drop the hero at the start.
func _travel(d: Dimension) -> void:
	Fx.glitch(1.0)
	Fx.impact(1.0)
	Sfx.play("zip")
	Sfx.play("glitch")
	_clear_bots()
	_close_gate()
	hud.set_race("")
	var home := d == null
	for n in _home_nodes:
		(n as Node3D).visible = home
		(n as Node).process_mode = Node.PROCESS_MODE_INHERIT if home else Node.PROCESS_MODE_DISABLED
	for other in dims:
		if other:
			(other as Dimension).visible = other == d
			(other as Dimension).process_mode = Node.PROCESS_MODE_INHERIT if other == d else Node.PROCESS_MODE_DISABLED
	dim = d
	player.area = d
	look.apply_palette(d.palette if d else {})
	if d:
		player.respawn(d.to_global(d.start_pos))
		rig.yaw = atan2(-d.start_look.x, -d.start_look.z)
		rig.pitch = -0.1
		Sfx.music(d.music)
	else:
		Sfx.music("city")
	rig.snap()


func _enter_dimension(i: int) -> void:
	var d := _get_dim(i)
	_travel(d)
	hud.clear_captions()
	_dims_visited = maxi(_dims_visited, i + 1)
	hud.chapter_card("DIMENSION %d" % (i + 1) if i < 2 else "THE FINAL DIMENSION", d.title)
	hud.narrate(d.intro, 2.6)
	if i == 2 and Game.args.has("boss"):
		get_tree().create_timer(1.0).timeout.connect(_start_boss)
		return
	_spawn_group(d.bot_plan, d)


## Open a portal a few steps in front of the hero, on open ground.
func _open_gate(to: int) -> void:
	_close_gate()
	gate = Gate.new()
	gate.label_text = ("TO THE %s!" % DIM_NAMES[to]) if to >= 0 else "BACK HOME!"
	add_child(gate)
	var place := _gate_spot()
	gate.global_position = place
	_gate_to = to
	gate.entered.connect(_on_gate)
	hud.goal = gate
	if not _free_roam:
		hud.set_objective("JUMP INTO THE PORTAL!")
		Game.say("A PORTAL OPENED!", 2.0)
		hud.narrate(["The bots came from ANOTHER DIMENSION!", "Jump into the portal and go after them!"] if to >= 0 else ["Portal home is open!"], 2.4)
	Sfx.play("glitch")
	Fx.glitch(0.5)


## Somewhere solid and easy to reach for a new portal: flat ground a few
## steps from the hero if there is some, else the nearest open street/island.
func _gate_spot() -> Vector3:
	var me := player.global_position
	var space := get_world_3d().direct_space_state
	# the ground under the hero (they may still be swinging)
	var q0 := PhysicsRayQueryParameters3D.create(me + Vector3(0, 1, 0), me + Vector3(0, -80, 0), 1)
	q0.exclude = [player.get_rid()]
	var under := space.intersect_ray(q0)
	if under:
		var feet: Vector3 = under.position
		for dir: Vector3 in [rig.forward(), rig.right(), -rig.right(), -rig.forward()]:
			dir.y = 0.0
			dir = dir.normalized()
			if _walkable(space, feet, dir, 14.0):
				return _ground_at(space, feet + dir * 14.0, feet.y)
	# no room here: the nearest open spot the place offers
	var spots: Array = []
	if dim:
		for sp in dim.gate_spots:
			spots.append(dim.to_global(sp))
	else:
		for n in city.street_nodes:
			spots.append((n as Vector3) + Vector3(6, 0.3, 6))
	var best: Vector3 = spots[0]
	var bd := INF
	for g: Vector3 in spots:
		var d := g.distance_to(me)
		if d >= 10.0 and d < bd:
			bd = d
			best = g
	return best


## Is there flat, open ground from `feet` along `dir` for `dist` metres?
func _walkable(space: PhysicsDirectSpaceState3D, feet: Vector3, dir: Vector3, dist: float) -> bool:
	for h in [1.5, 7.0, 13.0]:
		var a := feet + Vector3(0, h, 0)
		var q := PhysicsRayQueryParameters3D.create(a, a + dir * (dist + 6.0), 1)
		q.exclude = [player.get_rid()]
		if not space.intersect_ray(q).is_empty():
			return false
	var s := 2.0
	while s <= dist + 4.0:
		var y := _ground_at(space, feet + dir * s, feet.y).y
		if absf(y - feet.y) > 1.2:
			return false
		s += 2.0
	return true


## The ground under a point, looking a little above and below `y`.
func _ground_at(space: PhysicsDirectSpaceState3D, p: Vector3, y: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, y + 3.0, p.z), Vector3(p.x, y - 6.0, p.z), 1)
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.position if hit else Vector3(p.x, y - 100.0, p.z)


func _close_gate() -> void:
	if gate and is_instance_valid(gate):
		gate.queue_free()
	gate = null
	hud.goal = null


func _on_gate() -> void:
	var to := _gate_to
	_close_gate()
	if _free_roam:
		if to < 0:
			_travel(null)
			player.respawn(_title_spot - _title_look * 2.0 + Vector3(0, 0.5, 0))
			rig.yaw = atan2(_title_look.x, _title_look.z)
			rig.snap()
			hud.chapter_card("BACK HOME", "THE CITY")
			_roam_next = (_roam_next + 1) % 3
			get_tree().create_timer(2.5).timeout.connect(func() -> void:
				if _free_roam and not dim:
					_open_gate(_roam_next))
		else:
			var d := _get_dim(to)
			_travel(d)
			hud.chapter_card("FREE ROAM", d.title)
			_roam_t = 1.0
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				if _free_roam and dim == d:
					_open_gate(-1))
		return
	_next_chapter()


# ------------------------------------------------------------------ boss

func _start_boss() -> void:
	if mode != Mode.PLAY or chapter != 5 or _boss_started or not dim:
		return
	_boss_started = true
	var arena := dim.to_global(dim.arena)
	Fx.impact(1.0)
	player.respawn(arena + Vector3(0, 1.5, 14))
	rig.yaw = 0.0
	rig.snap()
	Sfx.music("boss")
	boss = GlitchKing.new()
	add_child(boss)
	boss.arena = arena
	boss.global_position = arena + Vector3(0, 16, -6)
	boss.defeated.connect(_boss_defeated)
	boss.wants_minions.connect(func(n: int, at: Vector3) -> void:
		for i in n:
			var b := GlitchBot.new()
			add_child(b)
			b.global_position = at + Vector3(randf_range(-6, 6), 2, randf_range(-6, 6))
			b.home = boss.arena + Vector3(randf_range(-18, 18), 8, randf_range(-18, 18)))
	hud.set_boss(boss)
	hud.set_objective("DEFEAT THE GLITCH KING!")
	Sfx.play("boss_roar")
	Fx.word("ROOOAAR!", boss.global_position, "big", Color(1, 0.3, 0.6))
	# face off: comic VERSUS panels
	var to_boss := boss.global_position - player.global_position
	to_boss.y = 0
	var fwd := to_boss.normalized()
	player.model.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), player.global_position)
	boss.rotation.y = atan2(-fwd.x, -fwd.z)
	rig.yaw = atan2(-fwd.x, -fwd.z)
	var vs: CanvasLayer = load("res://scripts/versus.gd").new()
	add_child(vs)
	get_tree().paused = true
	hud.visible = false
	vs.play(get_world_3d(), player.global_position, fwd, boss.global_position, look.post)
	vs.finished.connect(func() -> void:
		get_tree().paused = false
		hud.visible = true
		hud.narrate(["Smash him when he's DIZZY after a slam!", "Web-zip (E) at him to fly in!"], 3.0))


func _celebrate(seconds: float) -> void:
	# fireworks over the city and the whole street cheers
	var n := int(seconds * 2.5)
	for i in n:
		get_tree().create_timer(i * 0.4 + randf() * 0.3).timeout.connect(func() -> void:
			var c := player.global_position
			var p := c + Vector3(randf_range(-70, 70), randf_range(35, 80), randf_range(-70, 70))
			Fx.firework(p))
	people.cheer_all(seconds)


func _boss_defeated() -> void:
	hud.set_boss(null)
	hud.set_objective("")
	_clear_bots()
	Sfx.music("")
	Sfx.play("win")
	Game.say("YOU DID IT!!!", 3.0)
	hud.narrate(["The Glitch-Verse is falling apart!", "Time to go HOME!"], 1.6)
	# a few fireworks in the Glitch-Verse, then the trip home
	for i in 6:
		get_tree().create_timer(i * 0.3).timeout.connect(func() -> void:
			Fx.firework(player.global_position + Vector3(randf_range(-40, 40), randf_range(20, 50), randf_range(-40, 40))))
	get_tree().create_timer(3.4).timeout.connect(_come_home)


func _come_home() -> void:
	if mode != Mode.PLAY:
		return
	_travel(null)
	player.respawn(_title_spot - _title_look * 2.0 + Vector3(0, 0.5, 0))
	rig.yaw = atan2(_title_look.x, _title_look.z)
	rig.pitch = 0.15
	rig.snap()
	hud.chapter_card("BACK HOME", "THE CITY IS SAVED!")
	Sfx.music("")
	Sfx.play("cheer")
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		portal.close()
		Sfx.play("glitch")
		Game.say("THE PORTAL IS CLOSED!", 2.5))
	_celebrate(16.0)
	get_tree().create_timer(6.5).timeout.connect(func() -> void:
		if mode != Mode.PLAY:
			return
		mode = Mode.WIN
		player.enabled = false
		player.velocity = Vector3.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		menus.show_win(_play_time, _dims_visited))


func _keep_playing() -> void:
	mode = Mode.PLAY
	player.enabled = true
	_free_roam = true
	_roam_t = 3.0
	chapter = 99
	Sfx.music("city")
	_capture()
	hud.narrate(["The city is yours. Swing free, find every token!", "Jump in the portal to visit the other dimensions!", "Try RING RUSH: fly through the pink ring over the park!"], 3.0)
	_roam_next = 0
	_open_gate(0)


# ------------------------------------------------------------------ pause / input

func _set_paused(p: bool) -> void:
	if mode != Mode.PLAY:
		return
	get_tree().paused = p
	Engine.time_scale = 1.0
	menus.show_pause(p)
	_was_captured = false
	if p:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_capture()


func _radar_things() -> Array:
	var out: Array = []
	if gate:
		out.append([gate.global_position, Color(0.2, 1.0, 1.0), 7.0, true])
	if not dim:
		out.append([city.tower_pos, Color(0.7, 0.4, 1.0), 6.0, true])
		if race and not race.active:
			out.append([race.start_ring.global_position, Color(1, 0.3, 0.6), 5.0, false])
		var me := player.global_position
		for i in tokens.spots.size():
			if not tokens.taken[i] and tokens.spots[i].distance_to(me) < 150.0:
				out.append([tokens.spots[i], Color(1, 0.85, 0.2), 2.5, false])
	for e in get_tree().get_nodes_in_group("enemies"):
		var big: bool = e is GlitchKing or ("big" in e and e.big)
		out.append([(e as Node3D).global_position, Color(1, 0.2, 0.5), 5.0 if big else 3.5, true])
	return out


func _open_cover() -> void:
	get_tree().paused = true
	Engine.time_scale = 1.0
	hud.visible = false
	touch.visible = false
	cover.open()


func _close_cover() -> void:
	cover.visible = false
	hud.visible = true
	touch.visible = Game.touch_mode
	get_tree().paused = false
	_was_captured = false
	_capture()


func _resume() -> void:
	_set_paused(false)


func _capture() -> void:
	if not Game.touch_mode and not Game.args.has("autoplay"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.PLAY and not get_tree().paused and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Game.touch_mode:
			_capture()
