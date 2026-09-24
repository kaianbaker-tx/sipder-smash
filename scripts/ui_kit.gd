class_name UiKit
## Comic-book styled buttons, panels and labels.

const BANGERS := preload("res://assets/fonts/bangers.ttf")
const LUCKY := preload("res://assets/fonts/luckiest-guy.ttf")
const INK := Color(0.05, 0.0, 0.08)


static func box(col: Color, border := 5, shadow := Color(1, 0.2, 0.6)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = INK
	sb.set_border_width_all(border)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = shadow
	sb.shadow_offset = Vector2(7, 7)
	sb.shadow_size = 1
	return sb


static func button(text: String, size := 44, col := Color(1, 0.9, 0.2)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", BANGERS)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", box(col))
	b.add_theme_stylebox_override("hover", box(Color(1, 0.25, 0.55), 5, Color(0.1, 0.9, 1.0)))
	b.add_theme_stylebox_override("focus", box(Color(1, 0.25, 0.55), 5, Color(0.1, 0.9, 1.0)))
	b.add_theme_stylebox_override("pressed", box(Color(0.2, 0.8, 1.0), 5, Color(1, 0.9, 0.2)))
	b.add_theme_stylebox_override("disabled", box(Color(0.5, 0.45, 0.55)))
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func() -> void: Sfx.play("click", 0.2, -6.0))
	b.pressed.connect(func() -> void: Sfx.play("select", 0.05))
	return b


static func label(text: String, size := 30, col := Color(1, 1, 1), fnt: Font = null, outline := 10) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", fnt if fnt else BANGERS)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel(col := Color(1, 0.95, 0.85)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(col, 6)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	p.add_theme_stylebox_override("panel", sb)
	return p


static func dim() -> ColorRect:
	var c := ColorRect.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/comic_panel.gdshader")
	sm.set_shader_parameter("col_a", Color(0.3, 0.05, 0.4))
	sm.set_shader_parameter("col_b", Color(0.08, 0.0, 0.15))
	sm.set_shader_parameter("dot_col", Color(1, 0.2, 0.6))
	sm.set_shader_parameter("burst", 0.6)
	c.material = sm
	return c
