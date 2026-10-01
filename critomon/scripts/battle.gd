class_name Battle
extends CanvasLayer
## A Crito Mon battle: pick FIGHT, BAG, CRITO MON or RUN each turn.
## Wild Crito Mon can be caught with Crito Balls. Trainers send out their
## whole team. Returns "win", "lose", "run" or "caught".

signal _choice(c: Dictionary)

var stage: BattleStage
var dialog: Dialog
var rig: CamRig
var auto := false                 # autoplay: pick moves by itself

var foe_team: Array = []
var trainer_name := ""
var trainer_skin := ""
var trainer_gear := {}
var wild := true
var my_i := 0
var foe_i := 0
var my_model: CritterModel
var foe_model: CritterModel
var my_person: Person
var foe_person: Person
var stages := {}
var fought := {}                  # party indexes that took part (share XP)

# UI
var foe_box: PanelContainer
var foe_name: Label
var foe_hp: ProgressBar
var foe_caught: Control
var my_box: PanelContainer
var my_name: Label
var my_hp: ProgressBar
var my_hp_text: Label
var my_xp: ProgressBar
var menu_title: PanelContainer
var menu_title_label: Label
var menu: HBoxContainer
var _shake := 0.0


func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# the other Crito Mon (top left)
	foe_box = UI.panel()
	foe_box.position = Vector2(36, 30)
	foe_box.custom_minimum_size = Vector2(420, 0)
	root.add_child(foe_box)
	var fv := VBoxContainer.new()
	foe_box.add_child(fv)
	var fh := HBoxContainer.new()
	fv.add_child(fh)
	foe_name = UI.label("", 32)
	foe_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(foe_name)
	foe_caught = Control.new()
	foe_caught.custom_minimum_size = Vector2(30, 30)
	foe_caught.draw.connect(func() -> void: UI.draw_ball(foe_caught, Vector2(15, 17), 10))
	fh.add_child(foe_caught)
	foe_hp = HUD.hp_bar(370)
	fv.add_child(foe_hp)
	# your Crito Mon (right, above the menu)
	my_box = UI.panel()
	my_box.anchor_left = 1.0
	my_box.anchor_right = 1.0
	my_box.anchor_top = 1.0
	my_box.anchor_bottom = 1.0
	my_box.offset_left = -470
	my_box.offset_right = -36
	my_box.offset_top = -370
	my_box.offset_bottom = -230
	root.add_child(my_box)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 2)
	my_box.add_child(mv)
	my_name = UI.label("", 32)
	mv.add_child(my_name)
	my_hp = HUD.hp_bar(390)
	mv.add_child(my_hp)
	my_hp_text = UI.label("", 24)
	my_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mv.add_child(my_hp_text)
	my_xp = ProgressBar.new()
	my_xp.custom_minimum_size = Vector2(390, 8)
	my_xp.show_percentage = false
	var xbg := StyleBoxFlat.new()
	xbg.bg_color = Color(0.8, 0.8, 0.85)
	var xfg := StyleBoxFlat.new()
	xfg.bg_color = Color(0.3, 0.65, 1.0)
	my_xp.add_theme_stylebox_override("background", xbg)
	my_xp.add_theme_stylebox_override("fill", xfg)
	mv.add_child(my_xp)
	# the choice buttons along the bottom
	menu_title = UI.panel(UI.GOLD)
	menu_title.anchor_left = 0.5
	menu_title.anchor_right = 0.5
	menu_title.anchor_top = 1.0
	menu_title.anchor_bottom = 1.0
	menu_title.offset_left = -560
	menu_title.offset_top = -214
	menu_title.offset_bottom = -160
	root.add_child(menu_title)
	menu_title_label = UI.label("", 28)
	menu_title.add_child(menu_title_label)
	menu = HBoxContainer.new()
	menu.anchor_left = 0.5
	menu.anchor_right = 0.5
	menu.anchor_top = 1.0
	menu.anchor_bottom = 1.0
	menu.offset_left = -560
	menu.offset_right = 560
	menu.offset_top = -150
	menu.offset_bottom = -30
	menu.add_theme_constant_override("separation", 14)
	root.add_child(menu)
	_show_menu(false)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and menu.visible and event.is_action_pressed("ui_cancel"):
		_choice.emit({"kind": "back"})
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ helpers

func me() -> Dictionary:
	return Game.party[my_i]


func foe() -> Dictionary:
	return foe_team[foe_i]


func _say(t: String, wait := 1.3) -> void:
	await dialog.say(t, "", 0.3 if auto else wait)


func _wait(t: float) -> void:
	await get_tree().create_timer(0.05 if auto else t).timeout


func _update_boxes(animate := false) -> void:
	var f := foe()
	foe_name.text = "%s  Lv%d" % [Dex.mon_name(f), f.lv]
	foe_caught.visible = wild and Game.caught.has(f.sp)
	var m := me()
	my_name.text = "%s  Lv%d" % [Dex.mon_name(m), m.lv]
	my_hp_text.text = "%d / %d" % [maxi(0, m.hp), Dex.max_hp(m)]
	my_xp.min_value = Dex.xp_for(m.lv)
	my_xp.max_value = Dex.xp_for(m.lv + 1)
	my_xp.value = m.xp
	if animate:
		var tw := create_tween().set_parallel()
		tw.tween_method(func(v: float) -> void: HUD.set_hp(foe_hp, v, Dex.max_hp(f)), foe_hp.value, float(maxi(0, f.hp)), 0.5)
		tw.tween_method(func(v: float) -> void: HUD.set_hp(my_hp, v, Dex.max_hp(m)), my_hp.value, float(maxi(0, m.hp)), 0.5)
		await tw.finished
	else:
		HUD.set_hp(foe_hp, maxi(0, f.hp), Dex.max_hp(f))
		HUD.set_hp(my_hp, maxi(0, m.hp), Dex.max_hp(m))


func _process(delta: float) -> void:
	if _shake > 0.0 and rig and rig.locked:
		_shake = maxf(0.0, _shake - delta * 3.0)
		rig.cam.h_offset = randf_range(-1, 1) * _shake * 0.15
		rig.cam.v_offset = randf_range(-1, 1) * _shake * 0.15
	elif rig:
		rig.cam.h_offset = 0.0
		rig.cam.v_offset = 0.0


func _model_for(mon: Dictionary, pad: Vector3, face: Vector3) -> CritterModel:
	var c := CritterModel.new(mon.sp)
	stage.add_child(c)
	c.position = pad
	c.scale = Vector3.ONE * (1.45 if mon.sp != "fluffle" else 1.3)
	var d := face - pad
	c.rotation.y = atan2(-d.x, -d.z)
	c.visible = false
	return c


func _send_out(side: String) -> void:
	var person := my_person if side == "me" else foe_person
	var pad := BattleStage.MY_PAD if side == "me" else BattleStage.FOE_PAD
	var other := BattleStage.FOE_PAD if side == "me" else BattleStage.MY_PAD
	var mon := me() if side == "me" else foe()
	if side == "me":
		if my_model:
			my_model.queue_free()
		my_model = _model_for(mon, pad, other)
		stages["me"] = {"atk": 0, "def": 0, "spd": 0}
		fought[my_i] = true
	else:
		if foe_model:
			foe_model.queue_free()
		foe_model = _model_for(mon, pad, other)
		stages["foe"] = {"atk": 0, "def": 0, "spd": 0}
	var model := my_model if side == "me" else foe_model
	if person:
		await _throw_anim(person, stage.to_global(pad + Vector3(0, 0.4, 0)), false)
	Sfx.play("pop")
	FX.burst(stage, pad + Vector3(0, 0.8, 0), Color(1, 1, 1), 20, 4.0, 0.16)
	model.appear()
	Sfx.cry(mon.sp)
	await _wait(0.4)


## The trainer throws a Crito Ball at a spot. Returns the ball if keep.
func _throw_anim(person: Person, target: Vector3, keep: bool) -> CritoBall:
	var tw := create_tween()
	tw.tween_property(person, "throw", 1.0, 0.45)
	tw.tween_property(person, "throw", 0.0, 0.01)
	await get_tree().create_timer(0.3 if not auto else 0.02).timeout
	Sfx.play("throw")
	var ball := CritoBall.new()
	stage.add_child(ball)
	var a := person.global_position + Vector3(0, 1.8, 0)
	ball.global_position = a
	var mid := (a + target) * 0.5 + Vector3(0, 2.2, 0)
	var bt := create_tween()
	bt.tween_method(func(t: float) -> void:
		ball.global_position = a.lerp(mid, t).lerp(mid.lerp(target, t), t)
		ball.rotation.x -= 0.4, 0.0, 1.0, 0.45 if not auto else 0.05)
	await bt.finished
	if keep:
		return ball
	ball.open()
	await _wait(0.12)
	ball.queue_free()
	return null


# ------------------------------------------------------------------ start

## Run a whole battle. foe_team: Array of mons. Pass trainer info for
## trainer battles: {"name": "YOUNGSTER TIM", "skin": "youngster", "gear": {}}
func run(team: Array, trainer := {}) -> String:
	foe_team = team
	wild = trainer.is_empty()
	trainer_name = trainer.get("name", "")
	trainer_skin = trainer.get("skin", "")
	trainer_gear = trainer.get("gear", {})
	foe_i = 0
	fought = {}
	my_i = Game.party.find(Game.lead())
	for f in foe_team:
		Game.seen[f.sp] = true
	visible = true
	foe_box.visible = false
	my_box.visible = false
	_show_menu(false)
	my_person = Person.new("res://assets/chars/skins/player.png", 1.7, {"cap": Color(0.92, 0.18, 0.2), "cap2": Color(1, 1, 1), "bag": Color(0.2, 0.55, 0.95)})
	stage.add_child(my_person)
	my_person.position = BattleStage.MY_TRAINER
	_face(my_person, BattleStage.MY_TRAINER, BattleStage.FOE_PAD)
	if not wild:
		foe_person = Person.new("res://assets/chars/skins/%s.png" % trainer_skin, 1.72, trainer_gear)
		stage.add_child(foe_person)
		foe_person.position = BattleStage.FOE_TRAINER
		_face(foe_person, BattleStage.FOE_TRAINER, BattleStage.MY_PAD)
	# swoop in
	rig.shot(stage.to_global(Vector3(-7, 4.5, -2)), stage.to_global(BattleStage.FOE_PAD), 0.0)
	rig.shot(stage.to_global(BattleStage.CAM_POS), stage.to_global(BattleStage.CAM_LOOK), 1.4 if not auto else 0.05)
	Sfx.music("rival" if trainer.get("rival", false) else "battle")
	if wild:
		foe_model = _model_for(foe(), BattleStage.FOE_PAD, BattleStage.MY_PAD)
		stages["foe"] = {"atk": 0, "def": 0, "spd": 0}
		foe_model.appear()
		Sfx.cry(foe().sp)
		await _wait(0.6)
		await _say("A wild %s appeared!" % Dex.mon_name(foe()))
	else:
		await _wait(0.8)
		await _say("%s wants to battle!" % trainer_name)
		await _say("%s sent out %s!" % [trainer_name, Dex.mon_name(foe())], 0.6)
		await _send_out("foe")
	foe_box.visible = true
	_update_boxes()
	await _say("Go! %s!" % Dex.mon_name(me()), 0.6)
	await _send_out("me")
	my_box.visible = true
	_update_boxes()
	var result := ""
	while result == "":
		var c := await _choose()
		result = await _turn(c)
	await _end(result)
	return result


func _face(n: Node3D, from: Vector3, to: Vector3) -> void:
	var d := to - from
	n.rotation.y = atan2(-d.x, -d.z)


func _end(result: String) -> void:
	_show_menu(false)
	if not wild and result == "win":
		Sfx.music("victory")
		await _say("You beat %s!" % trainer_name)
	await _wait(0.3)
	for n in [my_model, foe_model, my_person, foe_person]:
		if n and is_instance_valid(n):
			n.queue_free()
	my_model = null
	foe_model = null
	my_person = null
	foe_person = null
	visible = false
	Game.party_changed.emit()


# ------------------------------------------------------------------ menus

func _show_menu(on: bool, title := "") -> void:
	menu.visible = on
	menu_title.visible = on and title != ""
	menu_title_label.text = title


func _buttons(items: Array) -> void:
	for c in menu.get_children():
		c.queue_free()
	var first: Button = null
	for it in items:
		var b := UI.button(it.text, 30 if it.text.length() < 13 else 24, it.get("bg", UI.PAPER), it.get("fg", UI.INK))
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = it.get("off", false)
		var c: Dictionary = it.choice
		b.pressed.connect(func() -> void:
			Sfx.play("select")
			_choice.emit(c))
		menu.add_child(b)
		if first == null and not b.disabled:
			first = b
	if first:
		first.grab_focus.call_deferred()


## Ask what to do this turn.
func _choose() -> Dictionary:
	if auto:
		await _wait(0.1)
		return {"kind": "move", "move": _best_move(me(), foe(), "me")}
	while true:
		_show_menu(true, "What will %s do?" % Dex.mon_name(me()))
		_buttons([
			{"text": "FIGHT", "bg": Color(0.95, 0.4, 0.35), "fg": Color.WHITE, "choice": {"kind": "fight"}},
			{"text": "BAG", "bg": Color(1.0, 0.8, 0.3), "choice": {"kind": "bag"}},
			{"text": "CRITO MON", "bg": Color(0.45, 0.8, 0.45), "fg": Color.WHITE, "choice": {"kind": "party"}},
			{"text": "RUN", "bg": Color(0.4, 0.6, 1.0), "fg": Color.WHITE, "choice": {"kind": "run"}},
		])
		var c: Dictionary = await _choice
		match c.kind:
			"fight":
				var items := []
				for mv in me().moves:
					var m: Dictionary = Dex.MOVES[mv]
					var tc: Color = Dex.TYPES[m.type].color
					items.append({"text": m.name, "bg": tc, "fg": Color.WHITE, "choice": {"kind": "move", "move": mv}})
				items.append({"text": "BACK", "choice": {"kind": "back"}})
				_show_menu(true, "Pick a move!")
				_buttons(items)
				var c2: Dictionary = await _choice
				if c2.kind == "move":
					_show_menu(false)
					return c2
			"bag":
				var items := [
					{"text": "POTION x%d" % Game.bag.get("potion", 0), "off": Game.bag.get("potion", 0) <= 0 or me().hp >= Dex.max_hp(me()), "choice": {"kind": "potion"}},
					{"text": "CRITO BALL x%d" % Game.bag.get("ball", 0), "off": Game.bag.get("ball", 0) <= 0 or not wild, "choice": {"kind": "ball"}},
					{"text": "BACK", "choice": {"kind": "back"}},
				]
				_show_menu(true, "Your bag" if wild else "Your bag (no catching other trainers' Crito Mon!)")
				_buttons(items)
				var c2: Dictionary = await _choice
				if c2.kind != "back":
					_show_menu(false)
					return c2
			"party":
				var c2 := await _pick_party(false)
				if c2.kind != "back":
					_show_menu(false)
					return c2
			"run":
				_show_menu(false)
				return c
	return {}


func _pick_party(forced: bool) -> Dictionary:
	var items := []
	for i in Game.party.size():
		var m: Dictionary = Game.party[i]
		var t := "%s\nLv%d  %d/%d" % [Dex.mon_name(m), m.lv, maxi(0, m.hp), Dex.max_hp(m)]
		items.append({"text": t, "off": m.hp <= 0 or (i == my_i and not forced) or (i == my_i and me().hp <= 0), "bg": Dex.TYPES[Dex.type_of(m)].color.lightened(0.4), "choice": {"kind": "switch", "index": i}})
	if not forced:
		items.append({"text": "BACK", "choice": {"kind": "back"}})
	_show_menu(true, "Who should battle?" if not forced else "Pick your next Crito Mon!")
	_buttons(items)
	while true:
		var c: Dictionary = await _choice
		if c.kind == "back" and forced:
			continue
		return c
	return {}


# ------------------------------------------------------------------ turns

func _speed(side: String) -> float:
	var mon := me() if side == "me" else foe()
	return Dex.stats(mon).spd * Dex.stage_mult(stages[side].spd)


func _best_move(att: Dictionary, tgt: Dictionary, side: String) -> String:
	var best := ""
	var best_d := -1.0
	for mv in att.moves:
		var m: Dictionary = Dex.MOVES[mv]
		var d := 0.0
		if m.power > 0:
			d = Dex.damage(att, tgt, mv, stages[side].atk, stages["foe" if side == "me" else "me"].def, false).damage * m.acc / 100.0
		else:
			d = 1.0 if randf() < 0.15 else 0.0
		if d > best_d:
			best_d = d
			best = mv
	return best


func _foe_move() -> String:
	var f := foe()
	if wild or randf() < 0.3:
		return f.moves[randi() % f.moves.size()]
	return _best_move(f, me(), "foe")


func _turn(c: Dictionary) -> String:
	var acts := []
	match c.kind:
		"run":
			if not wild:
				await _say("You can't run from a trainer battle!")
				return ""
			Sfx.play("flee")
			await _say("You got away safely!")
			return "run"
		"potion":
			Game.use_item("potion")
			var m := me()
			var before: int = m.hp
			m.hp = mini(Dex.max_hp(m), m.hp + 20)
			Sfx.play("heal")
			FX.sparkle(stage, BattleStage.MY_PAD + Vector3(0, 0.6, 0), Color(0.5, 1.0, 0.6))
			await _update_boxes(true)
			await _say("%s got back %d HP!" % [Dex.mon_name(m), m.hp - before])
		"ball":
			var r := await _catch()
			if r != "":
				return r
		"switch":
			await _say("Come back, %s!" % Dex.mon_name(me()), 0.6)
			my_model.shrink_to(my_person.global_position + Vector3(0, 1.2, 0))
			await _wait(0.4)
			my_i = c.index
			_update_boxes()
			await _say("Go! %s!" % Dex.mon_name(me()), 0.6)
			await _send_out("me")
			_update_boxes()
		"move":
			acts.append({"side": "me", "move": c.move})
	acts.append({"side": "foe", "move": _foe_move()})
	if acts.size() == 2:
		var a0: Dictionary = acts[0]
		var a1: Dictionary = acts[1]
		var p0 := 1 if Dex.MOVES[a0.move].get("first", false) else 0
		var p1 := 1 if Dex.MOVES[a1.move].get("first", false) else 0
		if p1 > p0 or (p1 == p0 and (_speed("foe") > _speed("me") or (_speed("foe") == _speed("me") and randf() < 0.5))):
			acts = [a1, a0]
	for a in acts:
		var mon := me() if a.side == "me" else foe()
		if mon.hp <= 0:
			continue
		await _use_move(a.side, a.move)
		var someone_fainted: bool = me().hp <= 0 or foe().hp <= 0
		var r := await _check_faint()
		if r != "":
			return r
		if someone_fainted:
			break
	return ""


func _use_move(side: String, mv: String) -> void:
	var m: Dictionary = Dex.MOVES[mv]
	var att := me() if side == "me" else foe()
	var tgt := foe() if side == "me" else me()
	var other := "foe" if side == "me" else "me"
	var a_model := my_model if side == "me" else foe_model
	var t_model := foe_model if side == "me" else my_model
	var who := Dex.mon_name(att) if side == "me" else ("Wild " + Dex.mon_name(att) if wild else "%s's %s" % [trainer_name.get_slice(" ", trainer_name.get_slice_count(" ") - 1), Dex.mon_name(att)])
	await _say("%s used %s!" % [who, m.name], 0.5)
	var from := a_model.position + Vector3(0, 0.7, 0)
	var to := t_model.position + Vector3(0, 0.7, 0)
	if randi() % 100 >= m.acc:
		a_model.lunge(t_model.global_position, 0.5)
		await _wait(0.4)
		await _say("But it missed!")
		return
	# the move's animation
	var snd: String = FX.TYPE_FX.get(m.type, FX.TYPE_FX.normal).sound
	match m.fx:
		"hit", "slash":
			a_model.lunge(t_model.global_position, 2.2 if m.fx == "hit" else 1.6)
			await _wait(0.2)
		"shoot":
			a_model.hop(0.2)
			Sfx.play(snd, 0.1)
			await FX.shot(stage, from, to, m.type, 0.35 if not auto else 0.05)
		"zap":
			a_model.hop(0.25)
			Sfx.play("zap")
			FX.lightning(stage, t_model.position)
			await _wait(0.15)
		"shout":
			a_model.hop(0.3)
			Sfx.play("shout", 0.05)
			FX.ring(stage, a_model.position + Vector3(0, 0.6, 0), Color(1, 1, 1, 0.8))
			await _wait(0.4)
		"buff":
			Sfx.play("buff")
			FX.sparkle(stage, a_model.position + Vector3(0, 0.5, 0), Color(0.6, 0.85, 1.0))
			a_model.set_param("emission", 0.4)
			await _wait(0.5)
			a_model.set_param("emission", 0.0)
	if m.power > 0:
		var r := Dex.damage(att, tgt, mv, stages[side].atk, stages[other].def)
		tgt.hp = maxi(0, tgt.hp - int(r.damage))
		var big: bool = r.mult > 1.0 or r.crit
		Sfx.play("hit_super" if r.mult > 1.0 else ("hit_weak" if r.mult < 1.0 else "hit"), 0.08)
		if snd != "hit" and m.fx != "shoot":
			Sfx.play(snd, 0.1, -4.0)
		FX.hit(stage, to, m.type, big)
		t_model.hurt()
		_shake = 1.0 if big else 0.5
		await _update_boxes(true)
		if r.crit:
			await _say("A critical hit!", 0.9)
		if r.mult > 1.0:
			await _say("It's super effective!", 0.9)
		elif r.mult < 1.0:
			await _say("It's not very effective...", 0.9)
	if m.has("effect"):
		var e: String = m.effect
		var up := e.ends_with("+1")
		var stat := e.substr(0, 3)
		var target_side := side if up else other
		var tmon := att if up else tgt
		var s: int = stages[target_side][stat]
		var names := {"atk": "ATTACK", "def": "DEFENSE", "spd": "SPEED"}
		var tname := Dex.mon_name(tmon)
		if (up and s >= 6) or (not up and s <= -6):
			await _say("%s's %s won't go any %s!" % [tname, names[stat], "higher" if up else "lower"])
		else:
			stages[target_side][stat] = s + (1 if up else -1)
			var tm := a_model if up else t_model
			FX.ring(stage, tm.position + Vector3(0, 0.1, 0), Color(0.5, 0.8, 1.0) if not up else Color(1.0, 0.6, 0.3), up)
			Sfx.play("buff" if up else "shout", 0.0, 0.0, 1.2 if up else 0.8)
			await _say("%s's %s %s!" % [tname, names[stat], "rose" if up else "fell"])


func _check_faint() -> String:
	if foe().hp <= 0:
		Sfx.cry(foe().sp, true)
		Sfx.play("faint")
		foe_model.faint()
		await _wait(0.5)
		await _say(("Wild %s fainted!" if wild else "The other %s fainted!") % Dex.mon_name(foe()))
		await _give_xp()
		if not wild and foe_i + 1 < foe_team.size():
			foe_i += 1
			await _say("%s sent out %s!" % [trainer_name, Dex.mon_name(foe())], 0.8)
			_update_boxes()
			await _send_out("foe")
			return ""
		return "win"
	if me().hp <= 0:
		Sfx.cry(me().sp, true)
		Sfx.play("faint")
		my_model.faint()
		await _wait(0.5)
		await _say("%s fainted!" % Dex.mon_name(me()))
		if not Game.can_battle():
			await _say("You have no Crito Mon left that can battle!")
			return "lose"
		var c := {}
		if auto:
			for i in Game.party.size():
				if Game.party[i].hp > 0:
					c = {"kind": "switch", "index": i}
					break
		else:
			c = await _pick_party(true)
		_show_menu(false)
		my_i = c.index
		_update_boxes()
		await _say("Go! %s!" % Dex.mon_name(me()), 0.6)
		await _send_out("me")
		_update_boxes()
	return ""


func _give_xp() -> void:
	var total := Dex.xp_reward(foe(), not wild)
	var who := []
	for i in fought:
		if i < Game.party.size() and Game.party[i].hp > 0:
			who.append(i)
	if who.is_empty():
		return
	var each := maxi(1, total / who.size())
	for i in who:
		var m: Dictionary = Game.party[i]
		await _say("%s got %d XP!" % [Dex.mon_name(m), each], 0.8)
		var events := Dex.gain_xp(m, each)
		if i == my_i:
			var tw := create_tween()
			tw.tween_property(my_xp, "value", minf(m.xp, my_xp.max_value), 0.5)
			await tw.finished
		for e in events:
			if e.has("level"):
				Sfx.play("levelup")
				if i == my_i:
					FX.sparkle(stage, BattleStage.MY_PAD + Vector3(0, 0.6, 0))
					my_model.hop(0.5)
				_update_boxes()
				await _say("%s grew to level %d!" % [Dex.mon_name(m), e.level])
			elif e.has("learned"):
				if e.forgot != "":
					await _say("%s forgot %s..." % [Dex.mon_name(m), Dex.MOVES[e.forgot].name], 0.9)
				await _say("%s learned %s!" % [Dex.mon_name(m), Dex.MOVES[e.learned].name])
	fought = {my_i: true}


func _catch() -> String:
	Game.use_item("ball")
	await _say("You threw a CRITO BALL!", 0.3)
	var target := foe_model.global_position + Vector3(0, 1.0, 0)
	var ball := await _throw_anim(my_person, target, true)
	ball.open()
	Sfx.play("pop")
	foe_model.shrink_to(ball.global_position)
	await _wait(0.45)
	ball.open(false)
	var tw := create_tween()
	tw.tween_property(ball, "global_position", foe_model.global_position + Vector3(0, 0.15, 0), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished
	var f := foe()
	var caught := randf() < Dex.catch_chance(f)
	var shakes := 3 if caught else randi_range(0, 2)
	for i in shakes:
		await _wait(0.35)
		Sfx.play("wobble")
		await ball.wobble()
	await _wait(0.3)
	if caught:
		Sfx.play("caught")
		FX.sparkle(stage, ball.position + Vector3(0, 0.2, 0), Color(1.0, 0.9, 0.3))
		ball.glow = 0.3
		await _say("Gotcha! %s was caught!" % Dex.mon_name(f))
		var mon := f.duplicate(true)
		var where := Game.add_mon(mon)
		if where == "box":
			await _say("Your team is full, so %s was sent to the lab." % Dex.mon_name(f))
		else:
			await _say("%s joined your team!" % Dex.mon_name(f))
		ball.queue_free()
		return "caught"
	ball.open()
	Sfx.play("pop")
	foe_model.appear()
	ball.queue_free()
	await _say(["Oh no! It broke free!", "Argh! So close!", "It popped right out!"][randi() % 3])
	return ""
