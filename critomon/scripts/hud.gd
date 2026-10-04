class_name HUD
extends CanvasLayer
## What you see while walking around: your goal, the "talk" prompt, your
## lead Crito Mon, little pop-up messages and screen fades / battle wipes.

var goal_box: PanelContainer
var goal: Label
var prompt: PanelContainer
var prompt_label: Label
var lead_box: PanelContainer
var lead_name: Label
var lead_hp: ProgressBar
var balls: Control
var toast_box: PanelContainer
var toast_label: Label
var fade: ColorRect
var turn_hint: PanelContainer
var wipe: Control
var _wipe_t := -1.0
var _toast_tw: Tween


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	goal_box = UI.panel()
	goal_box.position = Vector2(20, 18)
	goal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(goal_box)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", -4)
	goal_box.add_child(gv)
	gv.add_child(UI.label("GOAL", 20, UI.RED))
	goal = UI.label("", 26)
	gv.add_child(goal)

	lead_box = UI.panel()
	lead_box.anchor_left = 1.0
	lead_box.anchor_right = 1.0
	lead_box.offset_left = -330
	lead_box.offset_right = -20
	lead_box.offset_top = 18
	lead_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lead_box)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	lead_box.add_child(lv)
	lead_name = UI.label("", 26)
	lv.add_child(lead_name)
	lead_hp = hp_bar(260)
	lv.add_child(lead_hp)
	balls = Control.new()
	balls.custom_minimum_size = Vector2(260, 30)
	balls.draw.connect(_draw_balls)
	lv.add_child(balls)

	prompt = UI.panel(UI.GOLD)
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_left = -120
	prompt.offset_right = 120
	prompt.offset_top = -120
	prompt.offset_bottom = -60
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt)
	prompt_label = UI.label("", 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(prompt_label)
	prompt.visible = false

	toast_box = UI.panel()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.offset_left = -300
	toast_box.offset_right = 300
	toast_box.offset_top = 110
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	toast_label = UI.label("", 30)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_box.add_child(toast_label)
	toast_box.visible = false

	wipe = Control.new()
	wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe.draw.connect(_draw_wipe)
	root.add_child(wipe)

	turn_hint = UI.panel(UI.GOLD)
	turn_hint.set_anchors_preset(Control.PRESET_CENTER)
	turn_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := UI.label("Turn your phone sideways!", 64)
	turn_hint.add_child(tl)
	root.add_child(turn_hint)
	turn_hint.visible = false

	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	Game.party_changed.connect(refresh)
	refresh()


static func hp_bar(w: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, 18)
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.3, 0.28, 0.35)
	bg.set_corner_radius_all(9)
	bg.set_border_width_all(3)
	bg.border_color = UI.INK
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.3, 0.85, 0.35)
	fg.set_corner_radius_all(9)
	fg.set_border_width_all(3)
	fg.border_color = UI.INK
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


static func set_hp(b: ProgressBar, hp: float, mx: float) -> void:
	b.max_value = mx
	b.value = hp
	var fg := b.get_theme_stylebox("fill") as StyleBoxFlat
	fg.bg_color = UI.hp_color(hp / maxf(mx, 1.0))


func set_goal(t: String) -> void:
	goal.text = t
	goal_box.visible = t != ""


func show_prompt(t: String) -> void:
	prompt.visible = t != ""
	var key := "A" if Game.touch_mode else "E"
	prompt_label.text = "%s  %s" % [key, t]


func refresh() -> void:
	var m := Game.lead()
	lead_box.visible = not m.is_empty()
	if m.is_empty():
		return
	lead_name.text = "%s  Lv%d" % [Dex.mon_name(m), m.lv]
	set_hp(lead_hp, m.hp, Dex.max_hp(m))
	balls.queue_redraw()


func _draw_balls() -> void:
	for i in Game.MAX_PARTY:
		if i < Game.party.size():
			UI.draw_ball(balls, Vector2(14 + i * 40, 16), 11, Game.party[i].hp <= 0)
		else:
			balls.draw_circle(Vector2(14 + i * 40, 16), 5, Color(0.7, 0.7, 0.75))


func toast(t: String, secs := 2.2) -> void:
	toast_label.text = t
	toast_box.visible = true
	toast_box.modulate.a = 1.0
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(secs)
	_toast_tw.tween_property(toast_box, "modulate:a", 0.0, 0.3)
	_toast_tw.tween_callback(func() -> void: toast_box.visible = false)


func fade_out(t := 0.3) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, t)
	await tw.finished


func fade_in(t := 0.3) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, t)
	await tw.finished


## The battle-start effect: flashes, then black stripes sweep in.
func battle_wipe() -> void:
	for i in 3:
		fade.color = Color(1, 1, 1, 0.8)
		await get_tree().create_timer(0.06).timeout
		fade.color = Color(1, 1, 1, 0.0)
		await get_tree().create_timer(0.06).timeout
	_wipe_t = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_wipe_t", 1.0, 0.55)
	await tw.finished
	fade.color = Color(0, 0, 0, 1)
	_wipe_t = -1.0
	wipe.queue_redraw()


func _process(_delta: float) -> void:
	if _wipe_t >= 0.0:
		wipe.queue_redraw()
	var sz := get_viewport().get_visible_rect().size
	turn_hint.visible = Game.touch_mode and sz.y > sz.x * 1.1
	if turn_hint.visible:
		turn_hint.position = (sz - turn_hint.size) * 0.5


func _draw_wipe() -> void:
	if _wipe_t < 0.0:
		return
	var sz := wipe.size
	var n := 10
	var h := sz.y / n
	for i in n:
		var t := clampf(_wipe_t * 1.6 - i * 0.06, 0.0, 1.0)
		var w := sz.x * t
		if i % 2 == 0:
			wipe.draw_rect(Rect2(0, i * h, w, h + 1), Color.BLACK)
		else:
			wipe.draw_rect(Rect2(sz.x - w, i * h, w, h + 1), Color.BLACK)


func set_visible_all(on: bool) -> void:
	goal_box.visible = on and goal.text != ""
	lead_box.visible = on and not Game.lead().is_empty()
	if not on:
		prompt.visible = false
