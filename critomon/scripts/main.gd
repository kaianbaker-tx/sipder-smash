extends Node3D
## Runs Crito Mon: the title, the story, walking around, talking, doors,
## wild Crito Mon in tall grass, trainers, battles and Connect Four.
##
## Story: 1) walk to Prof. Birch's Lab, 2) pick EMBERPUP, BUBBLOO or
## SPROUTLE at the table, 3) JAX challenges you to Connect Four,
## 4) explore Route 1 (trainers, Connect Four players, wild Crito Mon),
## 5) beat JAX at The Arena to become the Route 1 Champion.

const RIVAL_PICK := {"emberpup": "bubbloo", "bubbloo": "sproutle", "sproutle": "emberpup"}
const EXIT_GATE_Z := -31.0

var look: Look
var world: World
var lab: Lab
var stage: BattleStage
var player: Player
var rig: CamRig
var hud: HUD
var dialog: Dialog
var battle: Battle
var c4: ConnectFour
var menu: PauseMenu
var touch: TouchControls
var title: TitleScreen
var npcs: Array[NPC] = []
var prof: NPC
var rival: NPC
var gate: StaticBody3D
var area := "town"
var busy := true                 # a cutscene, battle or menu is running
var _grass_d := 0.0
var _safe_t := 0.0
var _target = null               # what E would talk to right now
var _in_grass := false


func _ready() -> void:
	look = Look.new()
	add_child(look)
	world = World.new()
	add_child(world)
	world.build()
	lab = Lab.new()
	add_child(lab)
	lab.build()
	stage = BattleStage.new()
	add_child(stage)
	stage.build()
	player = Player.new()
	add_child(player)
	rig = CamRig.new()
	add_child(rig)
	rig.target = player
	player.rig = rig
	look.attach(rig.cam)
	player.moved.connect(_on_moved)
	_make_gate()
	_make_npcs()
	hud = HUD.new()
	add_child(hud)
	dialog = Dialog.new()
	add_child(dialog)
	battle = Battle.new()
	battle.stage = stage
	battle.dialog = dialog
	battle.rig = rig
	battle.hud = hud
	add_child(battle)
	c4 = ConnectFour.new()
	c4.rig = rig
	c4.dialog = dialog
	add_child(c4)
	menu = PauseMenu.new()
	menu.main = self
	add_child(menu)
	touch = TouchControls.new()
	touch.main = self
	add_child(touch)
	title = TitleScreen.new()
	title.main = self
	add_child(title)
	var auto := Game.args.has("autoplay")
	dialog.auto = auto
	battle.auto = auto
	c4.auto = auto
	player.visible = false
	hud.visible = false
	if auto:
		var ap: Node = load("res://tools/autoplay.gd").new()
		ap.set("main", self)
		add_child(ap)
	else:
		title.show_title()


# ------------------------------------------------------------------ setup

func _make_gate() -> void:
	# JAX blocks the way north until you have a Crito Mon
	gate = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(12, 3, 1)
	cs.shape = b
	cs.position = Vector3(0, 1.5, EXIT_GATE_Z - 1.2)
	gate.add_child(cs)
	add_child(gate)


func _npc(d: Dictionary) -> NPC:
	var n := NPC.make(d)
	add_child(n)
	npcs.append(n)
	return n


func _make_npcs() -> void:
	var L := Lab.ORIGIN
	prof = _npc({"id": "prof", "title": "PROF. BIRCH", "skin": "prof", "kind": "prof", "pos": L + Lab.TABLE + Vector3(0, 0, -2.2), "yaw": PI})
	_npc({"id": "aide", "title": "LAB AIDE", "skin": "aide", "gear": {"glasses": true}, "pos": L + Vector3(-5.8, 0, 7.0), "yaw": -PI / 2,
		"lines": ["The Professor studies how Crito Mon live in the wild.", "Tip: if your Crito Mon get tired, use the HEAL machine over there!"]})
	_npc({"id": "mom", "title": "MOM", "skin": "mom", "kind": "mom", "pos": Vector3(-12.5, 0, 9.5), "yaw": 0.0})
	_npc({"id": "kid", "title": "KID", "skin": "kid", "gear": {"cap": Color(0.25, 0.55, 0.95), "cap2": Color(0.95, 0.95, 0.3)}, "pos": Vector3(5.5, 0, -2.5), "yaw": PI / 2,
		"lines": ["Wild Crito Mon hide in the TALL GRASS!", "When a wild Crito Mon is weak, throw a CRITO BALL to catch it!"]})
	rival = _npc({"id": "rival", "title": "JAX", "skin": "rival", "kind": "rival", "pos": Vector3(0, 0, EXIT_GATE_Z - 0.2), "yaw": PI,
		"sight": 9.0, "intro": "You made it! Now let's have a REAL Crito Mon battle!",
		"lose_line": "No way! You beat me! You're the ROUTE 1 CHAMPION!", "after": "I'll train really hard. Next time I'll win!"})
	_npc({"id": "tim", "title": "YOUNGSTER TIM", "skin": "youngster", "gear": {"cap": Color(1.0, 0.8, 0.2), "cap2": Color(0.2, 0.4, 0.9)}, "kind": "mon", "pos": Vector3(12.5, 0, -68), "yaw": PI / 2, "sight": 9.0,
		"team": [["zappit", 4]], "intro": "Hey, you look new! Let's battle!", "lose_line": "Aww, I lost! You're really good!",
		"after": "I'm going to train in the tall grass some more.", "reward": {"potion": 1}})
	_npc({"id": "mia", "title": "LASS MIA", "skin": "lass", "kind": "mon", "pos": Vector3(-7.0, 0, -90), "yaw": -PI / 2, "sight": 10.0,
		"team": [["fluffle", 5], ["buzzlet", 4]], "intro": "Are your Crito Mon cute AND strong? Let's see!", "lose_line": "My cute team lost...",
		"after": "FLUFFLE loves floating on the wind.", "reward": {"ball": 2}})
	_npc({"id": "ben", "title": "BUG CATCHER BEN", "skin": "bugcatcher", "gear": {"hat": Color(0.95, 0.85, 0.5), "hat2": Color(0.3, 0.6, 0.3)}, "kind": "mon", "pos": Vector3(-10, 0, -114), "yaw": -PI / 2, "sight": 8.0,
		"team": [["buzzlet", 5], ["buzzlet", 6]], "intro": "My bug Crito Mon are the best! Bzzzz!", "lose_line": "My bugs got squashed!",
		"after": "FIRE moves are super strong against BUG Crito Mon. Shh!", "reward": {"potion": 1}})
	_npc({"id": "dot", "title": "PUZZLE KID DOT", "skin": "c4kid", "gear": {"glasses": true}, "kind": "c4", "c4_level": 2, "pos": Vector3(15.6, 0, -140), "yaw": PI / 2, "sight": 7.0,
		"intro": "I don't battle with Crito Mon. I battle with... CONNECT FOUR! Get four in a row to win!", "lose_line": "Whoa! You connected four! You're smart!",
		"after": "Try to make TWO ways to win at once. That's my secret!", "reward": {"ball": 3}})
	_npc({"id": "pearl", "title": "NURSE PEARL", "skin": "nurse", "kind": "heal", "pos": Vector3(21.5, 0, -145.5), "yaw": PI / 2,
		"lines": ["Welcome to CAMP CRITO!"]})
	_npc({"id": "hank", "title": "HIKER HANK", "skin": "hiker", "gear": {"hat": Color(0.55, 0.38, 0.22), "hat2": Color(0.3, 0.22, 0.15)}, "kind": "mon", "pos": Vector3(-8.5, 0, -160), "yaw": -PI / 2, "sight": 9.0,
		"team": [["pebblit", 6], ["zappit", 6]], "intro": "Hup hup! Rocks are tough! Want to see?", "lose_line": "Ha ha! You smashed my rocks!",
		"after": "WATER and GRASS moves beat ROCK Crito Mon.", "reward": {"potion": 2}})
	_npc({"id": "connie", "title": "GRANDMA CONNIE", "skin": "grandma", "gear": {"glasses": true}, "kind": "c4", "c4_level": 3, "pos": Vector3(9.5, 0, -181), "yaw": PI / 2, "sight": 11.0,
		"intro": "Oh, a young trainer! I've played CONNECT FOUR for 70 years. Let's play, dear!", "lose_line": "My my! You beat Grandma Connie! What a clever kid!",
		"after": "Always block your friend's three in a row, dear.", "reward": {"potion": 3, "ball": 2}})
	world.picnic_table(Vector3(12.4, 0, -181), PI / 2)


## Put things where the story says they should be (after loading too).
func apply_story() -> void:
	if Game.flag("starter") and not Game.flag("rival_c4"):
		# the game was saved in the middle of the lab scene: skip ahead
		Game.set_flag("rival_c4")
		Game.set_flag("rival_starter", RIVAL_PICK[Game.flags.starter])
		Game.give("ball", 5)
		Game.give("potion", 3)
	var has := Game.flag("starter")
	gate.process_mode = Node.PROCESS_MODE_DISABLED if has else Node.PROCESS_MODE_INHERIT
	(gate.get_child(0) as CollisionShape3D).disabled = has
	if has and Game.flag("rival_c4"):
		rival.global_position = Vector3(0, 0, -206)
		rival.person.rotation.y = PI
		rival.visible = true
		rival.body.process_mode = Node.PROCESS_MODE_INHERIT
	for i in 3:
		var sp: String = Dex.STARTERS[i]
		var taken: bool = Game.flag("starter") and (Game.flags.starter == sp or RIVAL_PICK[Game.flags.starter] == sp)
		lab.balls[i].visible = not taken
	player.set_partner(Game.lead().get("sp", "") if not Game.lead().is_empty() else "")
	_update_goal()


func _update_goal() -> void:
	if not Game.flag("starter"):
		hud.set_goal("Go to PROF. BIRCH'S LAB" if area == "town" else "Pick a Crito Mon at the table!")
	elif not Game.flag("champion"):
		hud.set_goal("Go north on ROUTE 1 and beat JAX at THE ARENA!")
	else:
		hud.set_goal("You're the Route 1 Champion! Catch more Crito Mon!")


## Start playing (from the title screen).
func begin(new_game: bool) -> void:
	if new_game or not Game.load_game():
		Game.new_game()
	player.visible = true
	hud.visible = true
	var sp: Dictionary = Game.spawn
	_enter_area(sp.area, sp.pos, sp.yaw)
	apply_story()
	await hud.fade_in(0.5)
	busy = false
	if new_game:
		busy = true
		await dialog.say("Welcome to the world of CRITO MON!")
		await dialog.say("Today is a big day. PROFESSOR BIRCH is going to give you your very first Crito Mon!")
		await dialog.say("His lab is the big white building with the red roof. Walk there and go inside!")
		busy = false


func _enter_area(a: String, pos: Vector3, yaw: float) -> void:
	area = a
	player.teleport(pos, yaw)
	var indoor := a == "lab"
	look.set_indoor(indoor)
	rig.set_indoor(indoor)
	rig.bounds = AABB(Lab.ORIGIN + Vector3(-Lab.HALF.x + 0.6, 0.5, -Lab.HALF.y + 0.6), Vector3(Lab.HALF.x * 2 - 1.2, 4.0, Lab.HALF.y * 2 - 1.2)) if indoor else AABB()
	rig.yaw = 0.0
	rig.snap()
	Sfx.music("lab" if indoor else ("town" if pos.z > -36.0 else "route"))
	_update_goal()


func save_spot() -> void:
	Game.spawn = {"area": area, "pos": player.global_position, "yaw": player.model.rotation.y}
	Game.save()


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	if busy or not player.visible:
		hud.show_prompt("")
		player.frozen = true
		return
	player.frozen = false
	_safe_t = maxf(0.0, _safe_t - delta)
	# music follows where you are
	if area == "town":
		Sfx.music("town" if player.global_position.z > -36.0 else "route")
	# doors
	if area == "town" and player.global_position.distance_to(World.LAB_DOOR) < 1.3:
		_go_through("lab")
		return
	if area == "lab" and player.global_position.distance_to(Lab.ORIGIN + Lab.EXIT) < 1.0:
		_go_through("town")
		return
	# JAX stops you going north without a Crito Mon
	if area == "town" and not Game.flag("starter") and player.global_position.z < EXIT_GATE_Z + 2.0 and absf(player.global_position.x) < 6.0:
		_blocked()
		return
	# the lab event: the professor talks when you first come in
	if area == "lab" and not Game.flag("met_prof"):
		_meet_prof()
		return
	# trainers who can see you
	for n in npcs:
		if n.is_trainer() or (n == rival and Game.flag("rival_c4") and not Game.flag("champion")):
			if n.visible and not n.beaten() and n.can_see(player.global_position):
				_trainer(n, true)
				return
	# what can you talk to?
	_target = _find_target()
	var label := ""
	if _target is NPC:
		label = "TALK"
	elif _target is Dictionary:
		label = _target.get("label", "LOOK")
	hud.show_prompt(label)
	if Input.is_action_just_pressed("interact") and _target != null:
		_interact(_target)
	elif Input.is_action_just_pressed("menu"):
		menu.open()


func _find_target():
	var p := player.global_position
	var f := player.facing()
	var best = null
	var best_d := 99.0
	for n in npcs:
		if not n.visible or n.global_position.distance_to(p) > 2.3:
			continue
		var d := n.global_position - p
		d.y = 0
		var score := d.length() - d.normalized().dot(f)
		if score < best_d:
			best_d = score
			best = n
	var list: Array = world.interactables if area == "town" else lab.interactables
	for it in list:
		var ip: Vector3 = it.pos
		var d: Vector3 = ip - p
		d.y = 0
		if d.length() > it.r:
			continue
		var score := d.length() - d.normalized().dot(f)
		if score < best_d:
			best_d = score
			best = it
	# the three Crito Balls on the lab table
	if area == "lab" and not Game.flag("starter"):
		for i in 3:
			var bp := lab.ball_pos(i)
			var d := bp - p
			d.y = 0
			if d.length() < 2.4 and absf(d.x) < 0.8:
				var score := d.length() * 0.5 - 1.0
				if score < best_d:
					best_d = score
					best = {"label": "LOOK", "starter": i}
	return best


func _on_moved(d: float) -> void:
	if area != "town" or busy:
		return
	var g := world.grass_at(player.global_position)
	var inside := g >= 0
	if inside != _in_grass and inside:
		Sfx.play("grass", 0.1, -6.0)
	_in_grass = inside
	if not inside or not Game.can_battle() or _safe_t > 0.0:
		return
	_grass_d += d
	if _grass_d >= 1.0:
		_grass_d -= 1.0
		Sfx.play("grass", 0.2, -14.0)
		if randf() < 0.075:
			_wild(g)


# ------------------------------------------------------------------ talking

func _interact(t) -> void:
	busy = true
	if t is NPC:
		await _talk(t)
	elif t is Dictionary:
		if t.has("starter"):
			await _look_at_starter(t.starter)
		elif t.get("heal", false):
			await _heal("The HEAL machine hums...")
		elif t.has("text"):
			Sfx.play("blip")
			for line in (t.text as String).split("\n\n"):
				await dialog.say(line)
	busy = false


func _talk(n: NPC) -> void:
	n.busy = true
	n.face_point(player.global_position)
	player.face_point(n.global_position)
	match n.kind:
		"talk":
			for l in n.lines:
				await dialog.say(l, n.title)
		"mom":
			if not Game.flag("starter"):
				await dialog.say("Good morning, sweetie! PROFESSOR BIRCH is waiting at his lab.", n.title)
				await dialog.say("It's the big white building with the red roof. Go on!", n.title)
			else:
				await dialog.say("Your Crito Mon look like they need a rest.", n.title)
				await _heal("MOM gave your team a big hug!")
		"heal":
			for l in n.lines:
				await dialog.say(l, n.title)
			await _heal("NURSE PEARL healed your Crito Mon!")
		"prof":
			await _talk_prof()
		"rival":
			await _talk_rival()
		"mon", "c4":
			if n.beaten():
				await dialog.say(n.after, n.title)
			else:
				await _trainer(n, false)
	n.busy = false


func _heal(msg: String) -> void:
	Game.heal_all()
	Sfx.play("heal")
	FX.sparkle(self, player.global_position + Vector3(0, 1, 0), Color(0.6, 1.0, 0.7))
	await dialog.say(msg)
	await dialog.say("Your Crito Mon are full of energy again!")
	save_spot()


func _talk_prof() -> void:
	if not Game.flag("starter"):
		await dialog.say("Walk up to the table and look at the Crito Balls. Pick the one you like best!", prof.title)
		return
	await dialog.say("How is %s doing? Let me check your team..." % Dex.mon_name(Game.party[0]), prof.title)
	await _heal("PROFESSOR BIRCH healed your Crito Mon!")
	var seen := Game.seen.size()
	var caught := Game.caught.size()
	await dialog.say("Your CRITO DEX: you've seen %d kinds and caught %d kinds of Crito Mon!" % [seen, caught], prof.title)
	if caught < Dex.SPECIES.size() - 2:
		await dialog.say("There are more out on ROUTE 1. Go catch them!", prof.title)


func _talk_rival() -> void:
	if not Game.flag("starter"):
		await dialog.say("Hey! Wait! It's dangerous to go in the tall grass without a Crito Mon!", rival.title)
		await dialog.say("My dad, PROFESSOR BIRCH, has some at his lab. Go get one!", rival.title)
	elif Game.flag("champion"):
		await dialog.say(rival.after, rival.title)
		var again := await dialog.ask("Want to have a rematch?", ["YES!", "NO"], rival.title)
		if again == 0:
			await _rival_battle()
	else:
		await _trainer(rival, false)


func _blocked() -> void:
	busy = true
	rival.face_point(player.global_position)
	await _talk_rival()
	await player.walk_to(player.global_position + Vector3(0, 0, 3.0))
	busy = false


# ------------------------------------------------------------------ doors

func _go_through(to: String) -> void:
	busy = true
	Sfx.play("door")
	await hud.fade_out(0.25)
	if to == "lab":
		_enter_area("lab", Lab.ORIGIN + Lab.SPAWN, 0.0)
	else:
		_enter_area("town", World.LAB_DOOR + Vector3(0, 0, 2.2), PI)
	await get_tree().process_frame
	await hud.fade_in(0.25)
	save_spot()
	busy = false


# ------------------------------------------------------------------ the lab

func _meet_prof() -> void:
	busy = true
	Game.set_flag("met_prof")
	await get_tree().create_timer(0.3).timeout
	var pp := prof.global_position
	rig.shot(pp + Vector3(1.8, 2.2, 4.5), pp + Vector3(0, 1.3, 0), 0.8)
	prof.person.wave = 1.0
	await dialog.say("Hello there! Welcome to my lab!", prof.title)
	prof.person.wave = 0.0
	await dialog.say("I'm PROFESSOR BIRCH. People call me the Crito Mon Professor!", prof.title)
	await dialog.say("This world is full of amazing creatures called CRITO MON.", prof.title)
	await dialog.say("Some are friends, some are pets, and some battle with their trainers!", prof.title)
	rig.shot(lab.to_world(Lab.TABLE + Vector3(0, 3.2, 5.0)), lab.to_world(Lab.TABLE + Vector3(0, 1.1, 0)), 0.8)
	await dialog.say("On this table are three Crito Balls. Each one has a Crito Mon inside!", prof.title)
	await dialog.say("Walk up to a ball and press %s to look inside. Then pick your partner!" % ("A" if Game.touch_mode else "E"), prof.title)
	rig.release()
	rig.snap()
	_update_goal()
	busy = false


func _look_at_starter(i: int) -> void:
	var sp: String = Dex.STARTERS[i]
	var s: Dictionary = Dex.SPECIES[sp]
	var ball := lab.balls[i]
	var bp := lab.ball_pos(i)
	player.face_point(bp)
	rig.shot(bp + Vector3(0, 1.3, 3.2), bp + Vector3(0, 0.45, 0), 0.6)
	await get_tree().create_timer(0.5).timeout
	ball.open()
	Sfx.play("pop")
	var mon := CritterModel.new(sp)
	add_child(mon)
	mon.global_position = bp + Vector3(0, 0.1, 0)
	mon.rotation.y = PI
	mon.scale = Vector3.ONE * 0.7
	mon.appear()
	FX.burst(self, bp + Vector3(0, 0.4, 0), Color(1, 1, 1), 16, 3.0, 0.12)
	Sfx.cry(sp)
	await get_tree().create_timer(0.3).timeout
	mon.hop(0.3)
	await dialog.say("It's %s, the %s Crito Mon! %s" % [s.name, Dex.TYPES[s.type].name, s.about], prof.title)
	var pick := await dialog.ask("Do you want %s to be your partner?" % s.name, ["YES!", "NO"], prof.title)
	if pick != 0:
		mon.shrink_to(bp)
		await mon.done
		mon.queue_free()
		ball.open(false)
		rig.release()
		return
	# chosen!
	Sfx.play("levelup")
	mon.hop(0.5)
	FX.sparkle(self, bp + Vector3(0, 0.3, 0))
	Game.set_flag("starter", sp)
	Game.add_mon(Dex.make(sp, 5))
	Game.seen[sp] = true
	ball.visible = false
	await dialog.say("%s is now your partner! Take good care of it!" % s.name, prof.title)
	mon.queue_free()
	player.set_partner(sp)
	player.partner.global_position = Vector3(bp.x, 0, bp.z + 1.4)
	hud.refresh()
	await _rival_arrives()


func _rival_arrives() -> void:
	var door := Lab.ORIGIN + Lab.SPAWN
	rival.visible = true
	rival.global_position = door + Vector3(0, 0, 1.2)
	rival.person.rotation.y = 0.0
	Sfx.play("door")
	await dialog.say("DAD! I'm here!", "???")
	rig.shot(player.global_position + Vector3(-3.0, 3.0, 5.0), player.global_position + Vector3(0, 1.0, 1.0), 0.8)
	await rival.walk_to(player.global_position, 2.0)
	player.face_point(rival.global_position)
	await dialog.say("Whoa! You got a Crito Mon from my dad? Cool!", rival.title)
	await dialog.say("I'm JAX. PROFESSOR BIRCH is my dad!", rival.title)
	var mine: String = RIVAL_PICK[Game.flags.starter]
	var idx := Dex.STARTERS.find(mine)
	lab.balls[idx].visible = false
	Game.set_flag("rival_starter", mine)
	await dialog.say("Then I'll take %s! Dad said I could have one too." % Dex.SPECIES[mine].name, rival.title)
	await dialog.say("Now let's see who's smarter... I challenge you to CONNECT FOUR!", rival.title)
	await dialog.say("Drop your RED discs in the board. Get FOUR IN A ROW before JAX does!")
	var result := await _connect_four(rival, 1, Lab.ORIGIN + Vector3(0, 0, 3.6), Vector3(0, 0, 1))
	match result:
		"win":
			await dialog.say("WHAT?! You got four in a row! You're good at this!", rival.title)
		"lose":
			await dialog.say("Ha ha! I win! But you're not bad at all.", rival.title)
		_:
			await dialog.say("A draw?! The board is full! Nobody wins!", rival.title)
	await dialog.say("Next time, let's have a REAL Crito Mon battle!", rival.title)
	await dialog.say("Meet me at THE ARENA at the end of ROUTE 1. See ya!", rival.title)
	await rival.walk_to(Lab.ORIGIN + Lab.EXIT, 0.3, 5.5)
	Sfx.play("door")
	rival.visible = false
	rival.global_position = Vector3(0, 0, -206)
	rival.person.rotation.y = PI
	rival.visible = true
	Game.set_flag("rival_c4")
	rig.shot(prof.global_position + Vector3(1.5, 2.2, 4.5), prof.global_position + Vector3(0, 1.3, 0), 0.6)
	await dialog.say("Oh, that JAX! Always in a hurry.", prof.title)
	await dialog.say("Here, take these. They will help you on your adventure!", prof.title)
	Game.give("ball", 5)
	Game.give("potion", 3)
	Sfx.play("item")
	hud.toast("Got 5 CRITO BALLS and 3 POTIONS!")
	await dialog.say("You got 5 CRITO BALLS and 3 POTIONS!")
	await dialog.say("Wild Crito Mon live in the TALL GRASS on ROUTE 1. Make one weak, then throw a CRITO BALL to catch it!", prof.title)
	await dialog.say("Press %s any time to see your team and your bag. Good luck!" % ("MENU" if Game.touch_mode else "ESC or TAB"), prof.title)
	rig.release()
	apply_story()
	save_spot()


# ------------------------------------------------------------------ trainers

func _trainer(n: NPC, spotted: bool) -> void:
	busy = true
	n.busy = true
	if spotted:
		n.alert()
		Sfx.play("alert")
		await get_tree().create_timer(0.8).timeout
		await n.walk_to(player.global_position, 1.8)
	n.face_point(player.global_position)
	player.face_point(n.global_position)
	await dialog.say(n.intro, n.title)
	var won := false
	if n.kind == "c4":
		var r := await _connect_four(n, n.c4_level)
		won = r == "win"
		if r == "draw":
			await dialog.say("A draw! The board is full. Talk to me to play again!", n.title)
		elif not won:
			await dialog.say("I win! Talk to me again if you want a rematch!", n.title)
	else:
		var team := []
		for t in n.team:
			team.append(Dex.make(t[0], t[1]))
		if n == rival:
			team = [Dex.make(Game.flags.get("rival_starter", "bubbloo"), 9), Dex.make("fluffle", 7)]
		var r := await _battle(team, {"name": n.title, "skin": n.skin, "gear": n.gear, "rival": n == rival})
		won = r == "win"
		if not won:
			n.busy = false
			busy = false
			return
	if won:
		Game.set_flag("beat_" + n.id)
		await dialog.say(n.lose_line, n.title)
		for item in n.reward:
			Game.give(item, n.reward[item])
			var nice: String = {"potion": "POTION", "ball": "CRITO BALL"}[item]
			var cnt: int = n.reward[item]
			Sfx.play("item")
			await dialog.say("%s gave you %d %s%s!" % [n.title, cnt, nice, "S" if cnt > 1 else ""])
		if n == rival:
			await _champion()
		save_spot()
	n.busy = false
	busy = false


func _rival_battle() -> void:
	var team := [Dex.make(Game.flags.get("rival_starter", "bubbloo"), 12), Dex.make("zappit", 10), Dex.make("fluffle", 10)]
	var r := await _battle(team, {"name": rival.title, "skin": rival.skin, "gear": rival.gear, "rival": true})
	if r == "win":
		await dialog.say("You're still the champ! I'll get you next time!", rival.title)


func _champion() -> void:
	Game.set_flag("champion")
	Sfx.music("victory")
	var trophy := world.find_child("Trophy", true, false) as Node3D
	if trophy:
		rig.shot(trophy.global_position + Vector3(0, 1.5, 5.0), trophy.global_position + Vector3(0, 0.8, 0), 1.0)
		FX.sparkle(world, trophy.position + Vector3(0, 1.0, 0))
	await dialog.say("CONGRATULATIONS! You are the ROUTE 1 CHAMPION!")
	await dialog.say("You and %s make an awesome team!" % Dex.mon_name(Game.party[0]))
	await dialog.say("There are still more Crito Mon to catch. Keep exploring! TO BE CONTINUED...")
	rig.release()
	_update_goal()


# ------------------------------------------------------------------ battles

func _wild(grass_index: int) -> void:
	var pool: Array = World.GRASS[grass_index].mons
	var pick: Array = pool[randi() % pool.size()]
	var mon := Dex.make(pick[0], randi_range(pick[1], pick[2]))
	busy = true
	await _battle([mon], {})
	busy = false


func _battle(team: Array, trainer: Dictionary) -> String:
	busy = true
	player.velocity = Vector3.ZERO
	var back_music := Sfx._music_name
	Sfx.play("battle")
	Sfx.music("")
	await hud.battle_wipe()
	hud.set_visible_all(false)
	look.set_indoor(false)
	var r := await battle.run(team, trainer)
	await hud.fade_out(0.3)
	rig.release()
	look.set_indoor(area == "lab")
	rig.snap()
	hud.set_visible_all(true)
	hud.refresh()
	if r == "lose":
		await _blackout()
		return r
	player.set_partner(Game.lead().sp)
	Sfx.music(back_music)
	await hud.fade_in(0.3)
	_safe_t = 3.0
	return r


func _blackout() -> void:
	Game.heal_all()
	_enter_area("lab", Lab.ORIGIN + Lab.TABLE + Vector3(0, 0, 2.0), 0.0)
	player.set_partner(Game.lead().sp)
	await hud.fade_in(0.4)
	await dialog.say("You hurried back to PROFESSOR BIRCH'S LAB...")
	await dialog.say("Don't worry! Your Crito Mon are all better now. Try again!", prof.title)
	save_spot()


## Play Connect Four next to someone. Returns "win", "lose" or "draw".
## spot / facing: put the board somewhere fixed (the lab) instead of
## next to the two players.
func _connect_four(n: NPC, level: int, spot := Vector3.INF, facing := Vector3.ZERO) -> String:
	await hud.fade_out(0.25)
	var a := player.global_position
	var b := n.global_position
	var mid := (a + b) * 0.5
	var along := (b - a)
	along.y = 0
	along = along.normalized() if along.length() > 0.1 else Vector3.RIGHT
	var side := Vector3(-along.z, 0, along.x)
	# put the board on the side with more room
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(mid + Vector3(0, 1, 0), mid + side * 4.0 + Vector3(0, 1, 0), 1)
	q.exclude = [n.body.get_rid()]
	if not space.intersect_ray(q).is_empty():
		side = -side
	if spot != Vector3.INF:
		mid = spot + facing * 2.2
		side = -facing
	var board := ConnectFourBoard.new()
	add_child(board)
	board.scale = Vector3.ONE * 0.62
	board.global_position = mid + side * 2.2
	board.look_at(board.global_position + side, Vector3.UP)   # -Z away, so the front (+Z) faces the players
	var front := side * -1.0
	var right := front.cross(Vector3.UP).normalized() * -1.0
	var bp := board.global_position
	player.teleport(bp + front * 1.2 - right * 1.9, 0.0)
	player.face_point(bp)
	n.global_position = bp + front * 1.2 + right * 1.9
	n.face_point(bp)
	if player.partner:
		player.partner.global_position = bp + front * 2.2 - right * 2.8
		player.partner.rotation.y = player.model.rotation.y
	var center := bp + Vector3(0, 1.2, 0)
	rig.shot(center + front * 5.8 + Vector3(0, 0.7, 0), center + Vector3(0, -0.15, 0), 0.0)
	await hud.fade_in(0.25)
	c4.board = board
	c4.level = level
	c4.foe_name = n.title.get_slice(" ", n.title.get_slice_count(" ") - 1)
	hud.set_visible_all(false)
	var r := await c4.play()
	hud.set_visible_all(true)
	await hud.fade_out(0.25)
	board.queue_free()
	rig.release()
	rig.snap()
	Sfx.music("lab" if area == "lab" else ("town" if player.global_position.z > -36.0 else "route"))
	await hud.fade_in(0.25)
	return r
