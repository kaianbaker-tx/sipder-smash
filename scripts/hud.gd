class_name Hud
extends CanvasLayer
## Comic HUD: spider-mask health, score, combo, tokens, yellow captions,
## objective box, enemy arrows, reticle, spider-sense and chapter cards.

const BANGERS := preload("res://assets/fonts/bangers.ttf")
const LUCKY := preload("res://assets/fonts/luckiest-guy.ttf")
const HP_FULL := preload("res://assets/ui/hp_full.png")
const HP_EMPTY := preload("res://assets/ui/hp_empty.png")
const TOKEN := preload("res://assets/ui/token.png")
const RETICLE := preload("res://assets/ui/reticle.png")

var player: Player
var rig: CamRig
var track: Array = []           # enemies to point at
var boss: Node3D

var _hearts: Array[TextureRect] = []
var _score: Label
var _tokens: Label
var _combo: Label
var _combo_box: Control
var _objective: Label
var _obj_panel: PanelContainer
var _caption: Label
var _caption_panel: PanelContainer
var _captions: Array = []
var _caption_t := 0.0
var _message: Label
var _message_t := 0.0
var _reticle: TextureRect
var _overlay: Control
var _boss_bar: ProgressBar
var _boss_box: VBoxContainer
var _hint: Label
var _click: Label
var _card: Control
var _root: Control


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_root.add_child(_overlay)

	# health
	var hb := HBoxContainer.new()
	hb.position = Vector2(18, 14)
	hb.add_theme_constant_override("separation", 2)
	_root.add_child(hb)
	for i in Player.MAX_HP:
		var t := TextureRect.new()
		t.texture = HP_FULL
		t.custom_minimum_size = Vector2(46, 46)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(t)
		_hearts.append(t)

	# objective box (yellow caption style)
	_obj_panel = _caption_box(Color(1.0, 0.92, 0.3), 3)
	_obj_panel.position = Vector2(18, 70)
	_obj_panel.rotation = -0.02
	_root.add_child(_obj_panel)
	_objective = _label("", LUCKY, 22, Color(0.08, 0.02, 0.1), 0)
	_obj_panel.add_child(_objective)
	_obj_panel.visible = false

	# score + tokens (top right)
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-270, 8)
	right.custom_minimum_size = Vector2(250, 0)
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(right)
	_score = _label("0", BANGERS, 52, Color(1, 0.95, 0.3), 12)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score.add_theme_color_override("font_shadow_color", Color(1, 0.2, 0.6))
	_score.add_theme_constant_override("shadow_offset_x", 4)
	_score.add_theme_constant_override("shadow_offset_y", 4)
	right.add_child(_score)
	var tk := HBoxContainer.new()
	tk.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(tk)
	var ti := TextureRect.new()
	ti.texture = TOKEN
	ti.custom_minimum_size = Vector2(36, 36)
	ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tk.add_child(ti)
	_tokens = _label("0/%d" % Game.token_total, BANGERS, 34, Color(1, 1, 1), 9)
	tk.add_child(_tokens)

	# combo
	_combo_box = Control.new()
	_combo_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_combo_box.position = Vector2(-360, -140)
	_root.add_child(_combo_box)
	_combo = _label("", BANGERS, 64, Color(0.2, 0.95, 1.0), 14)
	_combo.add_theme_color_override("font_shadow_color", Color(1, 0.2, 0.6))
	_combo.add_theme_constant_override("shadow_offset_x", 5)
	_combo.add_theme_constant_override("shadow_offset_y", 5)
	_combo_box.add_child(_combo)
	_combo_box.rotation = 0.08

	# narration caption (top centre)
	_caption_panel = _caption_box(Color(1.0, 0.9, 0.25), 4)
	_caption_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_caption_panel.position = Vector2(-300, 104)
	_caption_panel.custom_minimum_size = Vector2(600, 0)
	_root.add_child(_caption_panel)
	_caption = _label("", LUCKY, 26, Color(0.08, 0.02, 0.1), 0)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_panel.add_child(_caption)
	_caption_panel.visible = false

	# big message
	_message = _label("", BANGERS, 72, Color(1, 0.95, 0.3), 16)
	_message.set_anchors_preset(Control.PRESET_CENTER)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_shadow_color", Color(0, 0.85, 1))
	_message.add_theme_constant_override("shadow_offset_x", 6)
	_message.add_theme_constant_override("shadow_offset_y", 6)
	_message.position = Vector2(-500, -170)
	_message.custom_minimum_size = Vector2(1000, 0)
	_message.visible = false
	_root.add_child(_message)

	# reticle
	_reticle = TextureRect.new()
	_reticle.texture = RETICLE
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.custom_minimum_size = Vector2(34, 34)
	_reticle.size = Vector2(34, 34)
	_reticle.position = Vector2(-17, -17)
	_reticle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reticle.modulate = Color(1, 1, 1, 0.75)
	_root.add_child(_reticle)

	# boss bar
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.position = Vector2(-320, 16)
	_boss_box.custom_minimum_size = Vector2(640, 0)
	_boss_box.visible = false
	_root.add_child(_boss_box)
	var bl := _label("THE GLITCH KING", BANGERS, 36, Color(1, 0.3, 0.6), 10)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(bl)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(640, 26)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.02, 0.15)
	bg.border_color = Color(0.02, 0, 0.04)
	bg.set_border_width_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(1, 0.2, 0.55)
	fg.border_color = Color(0.02, 0, 0.04)
	fg.set_border_width_all(4)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fg)
	_boss_box.add_child(_boss_bar)

	# controls hint
	_hint = _label("", LUCKY, 17, Color(1, 1, 1), 6)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(18, -120)
	_root.add_child(_hint)
	set_hint_visible(true)

	_click = _label("CLICK TO PLAY!", BANGERS, 44, Color(1, 1, 1), 12)
	_click.set_anchors_preset(Control.PRESET_CENTER)
	_click.position = Vector2(-160, 60)
	_click.visible = false
	_root.add_child(_click)

	Game.score_changed.connect(_on_score)
	Game.tokens_changed.connect(func(t: int) -> void: _tokens.text = "%d/%d" % [t, Game.token_total]; _pop(_tokens))
	Game.combo_changed.connect(_on_combo)
	Game.message.connect(show_message)


func bind(p: Player, r: CamRig) -> void:
	player = p
	rig = r
	player.health_changed.connect(_on_health)
	_on_health(player.hp, Player.MAX_HP)


func _label(text: String, fnt: Font, size: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", fnt)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0, 0.08))
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _caption_box(col: Color, border: int) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(0.05, 0, 0.08)
	sb.set_border_width_all(border)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(1, 0.2, 0.6, 0.9)
	sb.shadow_offset = Vector2(6, 6)
	sb.shadow_size = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _pop(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.3, 1.3), 0.06)
	tw.tween_property(c, "scale", Vector2(1, 1), 0.12)


func _on_score(s: int) -> void:
	_score.text = str(s)
	_pop(_score)


func _on_combo(c: int) -> void:
	if c >= 2:
		_combo.text = "x%d COMBO!" % c
		_combo.visible = true
		_combo.pivot_offset = _combo.size * 0.5
		var tw := _combo.create_tween()
		_combo.scale = Vector2(1.5, 1.5)
		tw.tween_property(_combo, "scale", Vector2(1, 1), 0.15).set_trans(Tween.TRANS_BACK)
		_combo.add_theme_color_override("font_color", [Color(0.2, 0.95, 1.0), Color(1, 0.95, 0.3), Color(1, 0.35, 0.6)][c % 3])
	else:
		_combo.visible = false


func _on_health(hp: int, max_hp: int) -> void:
	for i in _hearts.size():
		_hearts[i].texture = HP_FULL if i < hp else HP_EMPTY
	if hp < max_hp and hp >= 0 and hp < _hearts.size():
		_pop(_hearts[hp])


func set_objective(text: String) -> void:
	_objective.text = text
	_obj_panel.visible = text != ""
	if text != "":
		_pop(_obj_panel)


## Queue narration lines (Spider-Verse yellow caption boxes).
func narrate(lines: Array, seconds := 2.6) -> void:
	for l in lines:
		_captions.append([l, seconds])
	if _caption_t <= 0.0:
		_next_caption()


func _next_caption() -> void:
	if _captions.is_empty():
		_caption_panel.visible = false
		_caption_t = 0.0
		return
	var c: Array = _captions.pop_front()
	_caption.text = c[0]
	_caption_t = c[1]
	_caption_panel.visible = true
	_caption_panel.rotation = randf_range(-0.03, 0.03)
	_caption_panel.pivot_offset = Vector2(300, 30)
	_caption_panel.scale = Vector2(0.6, 0.6)
	var tw := _caption_panel.create_tween()
	tw.tween_property(_caption_panel, "scale", Vector2(1, 1), 0.15).set_trans(Tween.TRANS_BACK)
	Sfx.play("click", 0.1)


func captions_busy() -> bool:
	return _caption_t > 0.0 or not _captions.is_empty()


func show_message(text: String, seconds := 2.5) -> void:
	_message.text = text
	_message.visible = true
	_message_t = seconds
	_message.pivot_offset = Vector2(500, 40)
	_message.scale = Vector2(0.3, 0.3)
	var tw := _message.create_tween()
	tw.tween_property(_message, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_message, "scale", Vector2(1, 1), 0.1)


func set_boss(b: Node3D) -> void:
	boss = b
	_boss_box.visible = b != null


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and _hint.visible:
		_hint.visible = false


func set_hint_visible(v: bool) -> void:
	if Game.touch_mode:
		_hint.visible = false
		return
	_hint.visible = v
	_hint.text = "RIGHT MOUSE / SHIFT: SWING    SPACE: JUMP (x2 FLIP)\nLEFT CLICK: SMASH    F: WEB SHOT    E: WEB ZIP\nRUN INTO WALLS TO CLIMB    C: COMIC COVER    H: HIDE HELP"


## A full-screen comic chapter card.
func chapter_card(number: String, title: String) -> void:
	if _card:
		_card.queue_free()
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/comic_panel.gdshader")
	bg.material = sm
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-500, -120)
	box.custom_minimum_size = Vector2(1000, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(box)
	var n := _label(number, LUCKY, 40, Color(1, 1, 1), 10)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(n)
	var t := _label(title, BANGERS, 110, Color(1, 0.92, 0.25), 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color(1, 0.15, 0.5))
	t.add_theme_constant_override("shadow_offset_x", 8)
	t.add_theme_constant_override("shadow_offset_y", 8)
	box.add_child(t)
	_card.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	_card.scale = Vector2(1.4, 1.4)
	_card.rotation = -0.05
	_card.modulate.a = 0.0
	var tw := _card.create_tween().set_parallel(true)
	tw.tween_property(_card, "scale", Vector2(1, 1), 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_card, "rotation", 0.0, 0.25)
	tw.tween_property(_card, "modulate:a", 1.0, 0.12)
	tw.chain().tween_interval(1.8)
	tw.chain().tween_property(_card, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(_card.queue_free)
	Sfx.play("chapter")


func _process(delta: float) -> void:
	if _caption_t > 0.0:
		_caption_t -= delta
		if _caption_t <= 0.0:
			_next_caption()
	if _message_t > 0.0:
		_message_t -= delta
		if _message_t <= 0.0:
			_message.visible = false
	if boss and is_instance_valid(boss) and "hp" in boss:
		_boss_bar.max_value = boss.max_hp
		_boss_bar.value = boss.hp
	elif _boss_box.visible:
		_boss_box.visible = false
	_click.visible = Game.playing and not Game.touch_mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused
	if Input.is_action_just_pressed("ui_help"):
		set_hint_visible(not _hint.visible)
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	if not rig or not player:
		return
	var cam := rig.cam
	var vp := _overlay.size
	var font := BANGERS
	# enemy markers
	for e in track:
		if not is_instance_valid(e) or ("dead" in e and e.dead):
			continue
		var wp: Vector3 = (e as Node3D).global_position + Vector3(0, 2.2, 0)
		var dist := wp.distance_to(player.global_position)
		var behind := cam.is_position_behind(wp)
		var sp := cam.unproject_position(wp)
		var on := not behind and sp.x > 30 and sp.y > 30 and sp.x < vp.x - 30 and sp.y < vp.y - 30
		if on:
			if dist > 22.0:
				var s := 10.0
				var pts := PackedVector2Array([sp + Vector2(0, -s), sp + Vector2(s, 0), sp + Vector2(0, s), sp + Vector2(-s, 0)])
				_overlay.draw_colored_polygon(pts, Color(1, 0.2, 0.5))
				pts.append(pts[0])
				_overlay.draw_polyline(pts, Color(0.05, 0, 0.08), 3.0)
				_overlay.draw_string(font, sp + Vector2(-20, -16), "%dm" % int(dist), HORIZONTAL_ALIGNMENT_CENTER, 40, 18, Color(1, 1, 1))
		else:
			var c := vp * 0.5
			var dir := (sp - c)
			if behind:
				dir = -dir
			if dir.length() < 1.0:
				dir = Vector2(0, 1)
			dir = dir.normalized()
			var edge := c + Vector2(dir.x * vp.x * 0.44, dir.y * vp.y * 0.42)
			var a := dir.angle()
			var tri := PackedVector2Array([edge + Vector2(18, 0).rotated(a), edge + Vector2(-10, 12).rotated(a), edge + Vector2(-10, -12).rotated(a)])
			_overlay.draw_colored_polygon(tri, Color(1, 0.2, 0.5))
			tri.append(tri[0])
			_overlay.draw_polyline(tri, Color(0.05, 0, 0.08), 3.0)
	# spider-sense: wiggly lines around the hero's head
	if player.spider_sense > 0.05:
		var head := player.global_position + Vector3(0, 2.0, 0)
		if not cam.is_position_behind(head):
			var hp := cam.unproject_position(head)
			var t := Time.get_ticks_msec() / 1000.0
			for k in 7:
				var a := -PI * 0.5 + (k - 3) * 0.38
				var pts := PackedVector2Array()
				for j in 8:
					var r := 26.0 + j * 7.0
					var wig := sin(j * 2.2 + t * 30.0 + k) * 5.0
					pts.append(hp + Vector2(cos(a), sin(a)) * r + Vector2(-sin(a), cos(a)) * wig)
				_overlay.draw_polyline(pts, Color(0.05, 0, 0.08, player.spider_sense), 6.0)
				_overlay.draw_polyline(pts, Color(1, 0.95, 0.3, player.spider_sense), 3.0)
