class_name PauseMenu
extends CanvasLayer
## ESC / TAB / MENU: see your team, use potions, choose who goes first,
## read your Critter Dex, save, and turn sound on or off.

var main: Node
var root: Control
var panel: PanelContainer
var body: VBoxContainer
var title: Label
var is_open := false


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.03, 0.12, 0.55)
	root.add_child(dim)
	panel = UI.panel()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -320
	panel.offset_bottom = 320
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	title = UI.label("MENU", 44, UI.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if title.text == "MENU":
			close()
		else:
			_home()


func open() -> void:
	if is_open:
		return
	is_open = true
	main.busy = true
	visible = true
	Sfx.play("select")
	_home()


func close() -> void:
	is_open = false
	visible = false
	Sfx.play("back")
	# wait a frame so the key that closed the menu doesn't also open it again
	await get_tree().process_frame
	main.busy = false


func _clear(t: String) -> void:
	title.text = t
	for c in body.get_children():
		c.queue_free()


func _add_button(text: String, cb: Callable, bg := UI.PAPER, fg := UI.INK) -> Button:
	var b := UI.button(text, 32, bg, fg)
	b.custom_minimum_size = Vector2(0, 70)
	b.pressed.connect(func() -> void:
		Sfx.play("select")
		cb.call())
	body.add_child(b)
	return b


func _home() -> void:
	_clear("MENU")
	var first := _add_button("CRITTERMON TEAM", _team, Color(0.45, 0.8, 0.45), Color.WHITE)
	_add_button("BAG", _bag, Color(1.0, 0.8, 0.3))
	_add_button("CRITTER DEX", _dex, Color(0.4, 0.6, 1.0), Color.WHITE)
	_add_button("SAVE GAME", _save)
	_add_button("SOUND: %s" % ("OFF" if Sfx.muted else "ON"), _sound)
	_add_button("HOW TO PLAY", _help)
	_add_button("BACK TO GAME", close, UI.RED, Color.WHITE)
	first.grab_focus.call_deferred()


func _team() -> void:
	_clear("YOUR TEAM")
	if Game.party.is_empty():
		body.add_child(UI.label("No Crittermon yet! Visit PROF. BIRCH'S LAB.", 30))
	for i in Game.party.size():
		var m: Dictionary = Game.party[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		body.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var s: Dictionary = Dex.SPECIES[m.sp]
		info.add_child(UI.label("%s  Lv%d   %s%s" % [s.name, m.lv, Dex.TYPES[s.type].name, "   (LEADER)" if i == 0 else ""], 30))
		var bar := HUD.hp_bar(420)
		HUD.set_hp(bar, m.hp, Dex.max_hp(m))
		info.add_child(bar)
		var moves := []
		for mv in m.moves:
			moves.append(Dex.MOVES[mv].name)
		info.add_child(UI.label("HP %d/%d   Moves: %s" % [m.hp, Dex.max_hp(m), ", ".join(moves)], 20))
		if i > 0:
			var lead := UI.button("LEADER", 24)
			lead.pressed.connect(func() -> void:
				Game.party.remove_at(i)
				Game.party.insert(0, m)
				Game.party_changed.emit()
				main.player.set_partner(m.sp)
				Sfx.play("select")
				_team())
			row.add_child(lead)
		var pot := UI.button("POTION", 24, Color(0.7, 0.55, 0.95), Color.WHITE)
		pot.disabled = Game.bag.get("potion", 0) <= 0 or m.hp >= Dex.max_hp(m)
		pot.pressed.connect(func() -> void:
			Game.use_item("potion")
			m.hp = mini(Dex.max_hp(m), m.hp + 20)
			Game.party_changed.emit()
			Sfx.play("heal")
			_team())
		row.add_child(pot)
	if not Game.box.is_empty():
		body.add_child(UI.label("%d more Crittermon are resting at the lab." % Game.box.size(), 22))
	var back := _add_button("BACK", _home)
	back.grab_focus.call_deferred()


func _bag() -> void:
	_clear("BAG")
	body.add_child(UI.label("POTION  x%d   (heals 20 HP)" % Game.bag.get("potion", 0), 32))
	body.add_child(UI.label("CRITTER BALL  x%d   (catch wild Crittermon)" % Game.bag.get("ball", 0), 32))
	body.add_child(UI.label("Use potions from the TEAM page or in battle.", 22))
	_add_button("BACK", _home).grab_focus.call_deferred()


func _dex() -> void:
	_clear("CRITTER DEX  (%d / %d caught)" % [Game.caught.size(), Dex.SPECIES.size()])
	for sp in Dex.SPECIES:
		var s: Dictionary = Dex.SPECIES[sp]
		var t := "???"
		var col := Color(0.55, 0.55, 0.6)
		if Game.caught.has(sp):
			t = "%s  (%s)  CAUGHT - %s" % [s.name, Dex.TYPES[s.type].name, s.about]
			col = UI.INK
		elif Game.seen.has(sp):
			t = "%s  (%s)  seen" % [s.name, Dex.TYPES[s.type].name]
			col = Color(0.35, 0.35, 0.45)
		var l := UI.label(t, 24, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(880, 0)
		body.add_child(l)
	_add_button("BACK", _home).grab_focus.call_deferred()


func _save() -> void:
	main.save_spot()
	_clear("SAVED!")
	body.add_child(UI.label("Your game is saved. You can close the page and CONTINUE later.", 28))
	_add_button("BACK", _home).grab_focus.call_deferred()


func _sound() -> void:
	Sfx.set_muted(not Sfx.muted)
	_home()


func _help() -> void:
	_clear("HOW TO PLAY")
	var lines := [
		"MOVE: W A S D or arrow keys (hold SHIFT to run). On a phone: the joystick.",
		"TALK / PICK: E, SPACE or ENTER. On a phone: the A button.",
		"CAMERA: drag with the mouse, or Q and R. Scroll to zoom.",
		"MENU: ESC or TAB.",
		"Walk in TALL GRASS to meet wild Crittermon. Make them weak, then throw a CRITTER BALL!",
		"FIRE beats GRASS. GRASS beats WATER. WATER beats FIRE.",
		"CONNECT FOUR: drop discs and get four in a row across, up or slanted!",
	]
	for t in lines:
		var l := UI.label(t, 24)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(880, 0)
		body.add_child(l)
	_add_button("BACK", _home).grab_focus.call_deferred()
