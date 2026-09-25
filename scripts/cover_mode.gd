extends CanvasLayer
## COMIC COVER mode: press C to freeze the action and frame it like the
## cover of a comic book. Great for screenshots to show friends!

signal closed

const LOGO := preload("res://assets/ui/logo.png")
const BLURBS := [
	"THE AMAZING SPIDEYS!",
	"WEB-SLINGING ACTION!",
	"THE GLITCH KING STRIKES!",
	"SMASH-TASTIC ADVENTURES!",
	"ACROSS THE MULTIVERSE!",
	"NO BOT IS SAFE!",
]
const BURSTS := ["NEW!", "1ST ISSUE!", "COLLECTOR'S EDITION!", "WOW!"]

var _root: Control
var _blurb: Label
var _burst_lbl: Label
var _issue: Label
var _hint: Label
var _flash: ColorRect


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# thick frame
	for side in 4:
		var r := ColorRect.new()
		r.color = UiKit.INK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match side:
			0:
				r.set_anchors_preset(Control.PRESET_TOP_WIDE)
				r.custom_minimum_size = Vector2(0, 14)
			1:
				r.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
				r.custom_minimum_size = Vector2(0, 14)
				r.position.y = -14
			2:
				r.set_anchors_preset(Control.PRESET_LEFT_WIDE)
				r.custom_minimum_size = Vector2(14, 0)
			3:
				r.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
				r.custom_minimum_size = Vector2(14, 0)
				r.position.x = -14
		_root.add_child(r)

	# masthead band
	var band := PanelContainer.new()
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.custom_minimum_size = Vector2(0, 150)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.88, 0.15)
	sb.border_color = UiKit.INK
	sb.set_border_width_all(10)
	band.add_theme_stylebox_override("panel", sb)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(band)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.position = Vector2(150, 8)
	logo.size = Vector2(300, 180)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(logo)
	var by := UiKit.label("STARRING THE HERO OF KAIAN'S CITY!", 30, Color(1, 1, 1), UiKit.LUCKY, 9)
	by.position = Vector2(470, 40)
	_root.add_child(by)

	# price box (top left)
	var price := PanelContainer.new()
	price.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1), 6, Color(1, 0.2, 0.6)))
	price.position = Vector2(26, 22)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pv := VBoxContainer.new()
	price.add_child(pv)
	_issue = UiKit.label("#1", 52, Color(1, 0.2, 0.5), UiKit.BANGERS, 0)
	_issue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_issue)
	var c := UiKit.label("25¢", 30, UiKit.INK, UiKit.BANGERS, 0)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(c)
	_root.add_child(price)

	# starburst (top right)
	var burst := Control.new()
	burst.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	burst.position = Vector2(-150, 150)
	burst.rotation = 0.2
	_root.add_child(burst)
	var pts := PackedVector2Array()
	for i in 32:
		var a := i * PI / 16.0
		var rr := 120.0 if i % 2 == 0 else 86.0
		pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.8))
	var shadow := Polygon2D.new()
	shadow.polygon = pts
	shadow.color = Color(0.1, 0.9, 1)
	shadow.position = Vector2(8, 8)
	burst.add_child(shadow)
	var poly := Polygon2D.new()
	poly.polygon = pts
	poly.color = Color(1, 0.25, 0.5)
	burst.add_child(poly)
	var ol := Line2D.new()
	var lp := pts.duplicate()
	lp.append(pts[0])
	ol.points = lp
	ol.width = 6
	ol.default_color = UiKit.INK
	burst.add_child(ol)
	_burst_lbl = UiKit.label("NEW!", 34, Color(1, 1, 1), UiKit.BANGERS, 10)
	_burst_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_burst_lbl.position = Vector2(-100, -26)
	_burst_lbl.custom_minimum_size = Vector2(200, 0)
	burst.add_child(_burst_lbl)

	# blurb caption (bottom left)
	var cap := PanelContainer.new()
	cap.add_theme_stylebox_override("panel", UiKit.box(Color(1, 0.92, 0.3), 6))
	cap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	cap.position = Vector2(40, -130)
	cap.rotation = -0.03
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blurb = UiKit.label("", 44, UiKit.INK, UiKit.BANGERS, 0)
	cap.add_child(_blurb)
	_root.add_child(cap)

	# barcode (bottom right)
	var bc := Control.new()
	bc.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bc.position = Vector2(-190, -130)
	_root.add_child(bc)
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1)
	bg.size = Vector2(150, 100)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bc.add_child(bg)
	var x := 10.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	while x < 138.0:
		var w := float(rng.randi_range(1, 4))
		var bar := ColorRect.new()
		bar.color = UiKit.INK
		bar.position = Vector2(x, 8)
		bar.size = Vector2(w, 64)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bc.add_child(bar)
		x += w + rng.randi_range(1, 3)
	var num := UiKit.label("0 12345 KAIAN 1", 14, UiKit.INK, UiKit.LUCKY, 0)
	num.position = Vector2(12, 74)
	bc.add_child(num)

	_hint = UiKit.label("COVER MODE!  Take a screenshot!  (press C to go back)", 22, Color(1, 1, 1), UiKit.LUCKY, 8)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-330, -56)
	_root.add_child(_hint)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func open() -> void:
	visible = true
	_blurb.text = BLURBS[randi() % BLURBS.size()]
	_burst_lbl.text = BURSTS[randi() % BURSTS.size()]
	_issue.text = "#%d" % randi_range(1, 99)
	_hint.modulate.a = 1.0
	_flash.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35)
	var tw2 := create_tween()
	tw2.tween_interval(2.5)
	tw2.tween_property(_hint, "modulate:a", 0.0, 0.5)
	Sfx.play("click")
	Sfx.play("select", 0.0, -4.0)


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _flash.color.a > 0.5:
		return
	var tap := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if event.is_action_pressed("cover") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or tap:
		get_viewport().set_input_as_handled()
		close()
