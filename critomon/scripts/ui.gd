class_name UI
## Shared look for menus and boxes: round white panels with a thick dark
## border, like the classic handheld games.

const FONT := preload("res://assets/fonts/lilita_one_regular.ttf")
const INK := Color(0.16, 0.12, 0.26)
const PAPER := Color(1.0, 0.99, 0.95)
const RED := Color(0.93, 0.25, 0.25)
const BLUE := Color(0.25, 0.5, 0.95)
const GOLD := Color(1.0, 0.82, 0.2)
const BALL_GREEN := Color(0.18, 0.74, 0.32)


static func box_style(bg := PAPER, border := INK, radius := 18, bw := 5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 6)
	return s


static func panel(bg := PAPER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_style(bg))
	return p


static func label(text: String, size := 30, col := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func outlined(text: String, size := 40, col := Color.WHITE, outline := INK) -> Label:
	var l := label(text, size, col)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", int(size * 0.3))
	return l


static func button(text: String, size := 30, bg := PAPER, fg := INK) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", size)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_stylebox_override("normal", box_style(bg, INK, 16, 4))
	b.add_theme_stylebox_override("hover", box_style(bg.lightened(0.15), INK, 16, 4))
	b.add_theme_stylebox_override("pressed", box_style(bg.darkened(0.12), INK, 16, 4))
	var f := box_style(bg.lightened(0.1), GOLD, 16, 7)
	b.add_theme_stylebox_override("focus", f)
	b.focus_mode = Control.FOCUS_ALL
	return b


## A health bar: green, yellow when low, red when very low.
static func hp_color(frac: float) -> Color:
	if frac > 0.5:
		return Color(0.3, 0.85, 0.35)
	if frac > 0.2:
		return Color(1.0, 0.8, 0.15)
	return Color(0.95, 0.3, 0.25)


## Draw a little Critter Ball (for menus).
static func draw_ball(ci: CanvasItem, c: Vector2, r: float, empty := false) -> void:
	ci.draw_circle(c, r + 2.5, INK)
	if empty:
		ci.draw_circle(c, r, Color(0.7, 0.7, 0.75))
		return
	ci.draw_circle(c, r, Color(0.98, 0.98, 0.98))
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + i * PI / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, BALL_GREEN)
	ci.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), INK, maxf(2.0, r * 0.18))
	ci.draw_circle(c, r * 0.32, INK)
	ci.draw_circle(c, r * 0.2, Color(0.98, 0.98, 0.98))
