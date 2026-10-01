class_name ConnectFour
extends CanvasLayer
## A game of Connect Four on a 3D board against a trainer.
## You are RED and go first. Get four in a row across, up or diagonal!
## Move with A / D or the arrows, drop with E / Space. Or click / tap a column.
## level 1 = easy (makes silly moves), 2 = good, 3 = very tricky.

signal _dropped(col: int)

const COLS := 7
const ROWS := 6

var board: ConnectFourBoard
var rig: CamRig
var dialog: Dialog
var auto := false
var level := 1
var foe_name := ""
var grid := PackedByteArray()      # 0 empty, 1 you, 2 them. index = row * 7 + col
var col := 3
var my_turn := false
var _windows: Array = []
var banner: PanelContainer
var banner_label: Label
var hint: Label


func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	banner = UI.panel(UI.GOLD)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -220
	banner.offset_right = 220
	banner.offset_top = 22
	root.add_child(banner)
	banner_label = UI.label("", 36)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_child(banner_label)
	hint = UI.outlined("", 26)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -400
	hint.offset_right = 400
	hint.offset_top = -64
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	visible = false
	# every line of four on the board
	for r in ROWS:
		for c in COLS:
			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var cells := []
				for k in 4:
					var cc: int = c + d.x * k
					var rr: int = r + d.y * k
					if cc < 0 or cc >= COLS or rr < 0 or rr >= ROWS:
						break
					cells.append(rr * COLS + cc)
				if cells.size() == 4:
					_windows.append(cells)


## Play one game. Returns "win", "lose" or "draw".
func play() -> String:
	grid.resize(COLS * ROWS)
	grid.fill(0)
	board.clear()
	visible = true
	col = 3
	var turn := 1
	var result := ""
	hint.text = "Tap a column to drop your disc!" if Game.touch_mode else "A / D  or  arrows to move,  E  or  SPACE  to drop.  Or click a column!"
	Sfx.music("c4")
	while result == "":
		if turn == 1:
			banner_label.text = "YOUR TURN"
			banner_label.add_theme_color_override("font_color", Color(0.85, 0.12, 0.12))
			my_turn = true
			board.show_hover(col, ConnectFourBoard.RED)
			var c: int
			if auto:
				await get_tree().create_timer(0.05).timeout
				c = _ai_move(3 if randf() < 0.8 else 1, 1)
			else:
				c = await _dropped
			my_turn = false
			board.show_hover(-1, ConnectFourBoard.RED)
			await _drop(c, 1)
		else:
			banner_label.text = "%s'S TURN" % foe_name
			banner_label.add_theme_color_override("font_color", Color(0.6, 0.45, 0.0))
			await get_tree().create_timer(0.05 if auto else randf_range(0.5, 0.9)).timeout
			var depth: int = [1, 1, 3, 5][clampi(level, 0, 3)]
			var silly: float = [0.0, 0.35, 0.1, 0.0][clampi(level, 0, 3)]
			var c := _ai_move(depth, 2) if randf() >= silly else _random_move()
			await _drop(c, 2)
		var w := _winner(grid)
		if w.who != 0:
			board.celebrate(w.cells)
			result = "win" if w.who == 1 else "lose"
		elif not grid.has(0):
			result = "draw"
		turn = 3 - turn
	banner_label.text = {"win": "YOU WIN!", "lose": "%s WINS!" % foe_name, "draw": "IT'S A DRAW!"}[result]
	Sfx.play("win" if result == "win" else ("lose" if result == "lose" else "bump"))
	await get_tree().create_timer(0.3 if auto else 1.6).timeout
	visible = false
	return result


func _drop(c: int, who: int) -> void:
	var r := _open_row(grid, c)
	if r < 0:
		return
	grid[r * COLS + c] = who
	var tw := board.drop(c, r, ConnectFourBoard.RED if who == 1 else ConnectFourBoard.YELLOW)
	await tw.finished
	Sfx.play("drop", 0.08)


static func _open_row(g: PackedByteArray, c: int) -> int:
	for r in ROWS:
		if g[r * COLS + c] == 0:
			return r
	return -1


func _winner(g: PackedByteArray) -> Dictionary:
	for w in _windows:
		var a: int = g[w[0]]
		if a != 0 and g[w[1]] == a and g[w[2]] == a and g[w[3]] == a:
			var cells := []
			for i in w:
				cells.append(Vector2i(i % COLS, i / COLS))
			return {"who": a, "cells": cells}
	return {"who": 0, "cells": []}


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not my_turn:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_move(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_move(1)
	elif event.is_action_pressed("interact"):
		_try_drop(col)
	elif event is InputEventMouseMotion:
		var c := _column_at((event as InputEventMouseMotion).position)
		if c >= 0 and c != col:
			col = c
			board.show_hover(col, ConnectFourBoard.RED)
	elif (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		var c := _column_at(event.position)
		if c >= 0:
			col = c
			_try_drop(c)


func _move(d: int) -> void:
	col = clampi(col + d, 0, COLS - 1)
	board.show_hover(col, ConnectFourBoard.RED)
	Sfx.play("blip", 0.0, -8.0)


func _try_drop(c: int) -> void:
	if _open_row(grid, c) < 0:
		Sfx.play("bump")
		return
	_dropped.emit(c)


## Which column is under a screen point (or -1).
func _column_at(screen: Vector2) -> int:
	var cam := rig.cam
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var plane := Plane(board.global_transform.basis.z.normalized(), board.global_position)
	var hit = plane.intersects_ray(from, dir)
	if hit == null:
		return -1
	var local: Vector3 = board.to_local(hit)
	var c := int(round(local.x / ConnectFourBoard.CELL + (COLS - 1) * 0.5))
	var top := board.top_pos(0).y + 0.6
	if c < 0 or c >= COLS or local.y < 0.0 or local.y > top:
		return -1
	return c


# ------------------------------------------------------------------ thinking

func _random_move() -> int:
	var open := []
	for c in COLS:
		if _open_row(grid, c) >= 0:
			open.append(c)
	return open[randi() % open.size()]


## Look ahead `depth` moves (minimax with alpha-beta) and pick the best column.
func _ai_move(depth: int, me: int) -> int:
	var g := grid.duplicate()
	var order := [3, 2, 4, 1, 5, 0, 6]
	var best := -1
	var best_score := -INF
	for c in order:
		var r := _open_row(g, c)
		if r < 0:
			continue
		g[r * COLS + c] = me
		var s := _minimax(g, depth - 1, -INF, INF, false, me) + randf() * 0.5
		g[r * COLS + c] = 0
		if s > best_score:
			best_score = s
			best = c
	return best if best >= 0 else _random_move()


func _minimax(g: PackedByteArray, depth: int, alpha: float, beta: float, maxing: bool, me: int) -> float:
	var w := _winner_fast(g)
	if w == me:
		return 100000.0 + depth
	if w != 0:
		return -100000.0 - depth
	if depth <= 0 or not g.has(0):
		return _score(g, me)
	var order := [3, 2, 4, 1, 5, 0, 6]
	var who := me if maxing else 3 - me
	var v := -INF if maxing else INF
	for c in order:
		var r := _open_row(g, c)
		if r < 0:
			continue
		g[r * COLS + c] = who
		var s := _minimax(g, depth - 1, alpha, beta, not maxing, me)
		g[r * COLS + c] = 0
		if maxing:
			v = maxf(v, s)
			alpha = maxf(alpha, v)
		else:
			v = minf(v, s)
			beta = minf(beta, v)
		if alpha >= beta:
			break
	return v


func _winner_fast(g: PackedByteArray) -> int:
	for w in _windows:
		var a: int = g[w[0]]
		if a != 0 and g[w[1]] == a and g[w[2]] == a and g[w[3]] == a:
			return a
	return 0


func _score(g: PackedByteArray, me: int) -> float:
	var s := 0.0
	var them := 3 - me
	for r in ROWS:
		if g[r * COLS + 3] == me:
			s += 3.0
	for w in _windows:
		var mine := 0
		var theirs := 0
		for i in w:
			if g[i] == me:
				mine += 1
			elif g[i] == them:
				theirs += 1
		if theirs == 0:
			if mine == 3:
				s += 5.0
			elif mine == 2:
				s += 2.0
		elif mine == 0:
			if theirs == 3:
				s -= 4.5
			elif theirs == 2:
				s -= 1.5
	return s
