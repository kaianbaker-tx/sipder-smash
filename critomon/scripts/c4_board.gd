class_name ConnectFourBoard
extends Node3D
## A standing 3D Connect Four board: blue plates with holes, discs that drop
## in with a bounce. The origin is the middle of the bottom edge.
## Column 0 is on the left when you look at the front (+Z side).

const COLS := 7
const ROWS := 6
const CELL := 0.5
const MARGIN := Vector2(0.04, 0.05)
const RED := Color(0.95, 0.2, 0.2)
const YELLOW := Color(1.0, 0.82, 0.1)

var plate_size := Vector2.ZERO
var discs := {}                 # Vector2i(col, row) -> MeshInstance3D
var hover: MeshInstance3D
var _disc_mesh: CylinderMesh
var _mats := {}


func _ready() -> void:
	plate_size = Vector2(COLS * CELL / (1.0 - 2.0 * MARGIN.x), ROWS * CELL / (1.0 - 2.0 * MARGIN.y))
	var plate := QuadMesh.new()
	plate.size = plate_size
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/board.gdshader")
	mat.set_shader_parameter("margin", MARGIN)
	for z in [0.09, -0.09]:
		var p := MeshInstance3D.new()
		p.mesh = plate
		p.material_override = mat
		p.position = Vector3(0, plate_size.y * 0.5 + 0.3, z)
		add_child(p)
	# rails round the edge and feet
	var blue := Color(0.12, 0.34, 0.85)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.14, plate_size.y + 0.1, 0.3), Vector3(sx * (plate_size.x * 0.5 + 0.07), plate_size.y * 0.5 + 0.3, 0), blue)
		_box(Vector3(0.22, 0.12, 1.4), Vector3(sx * (plate_size.x * 0.5 + 0.07), 0.06, 0), blue.darkened(0.2))
		_box(Vector3(0.12, 0.3, 0.2), Vector3(sx * (plate_size.x * 0.5 + 0.07), 0.2, 0), blue.darkened(0.2))
	_box(Vector3(plate_size.x + 0.28, 0.12, 0.3), Vector3(0, 0.26, 0), blue)
	_disc_mesh = CylinderMesh.new()
	_disc_mesh.top_radius = CELL * 0.42
	_disc_mesh.bottom_radius = CELL * 0.42
	_disc_mesh.height = 0.13
	_disc_mesh.radial_segments = 20
	_disc_mesh.rings = 1
	hover = _new_disc(RED)
	hover.visible = false


func _box(size: Vector3, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Toon.color(col, {"rim": 0.3})
	mi.position = pos
	add_child(mi)


func _mat(col: Color) -> ShaderMaterial:
	var k := str(col)
	if not _mats.has(k):
		var m := Toon.color(col, {"rim": 0.4}).duplicate() as ShaderMaterial
		m.next_pass = Toon.outline()
		_mats[k] = m
	return _mats[k]


func _new_disc(col: Color) -> MeshInstance3D:
	var d := MeshInstance3D.new()
	d.mesh = _disc_mesh
	d.material_override = _mat(col)
	d.rotation.x = PI / 2
	add_child(d)
	return d


## Local position of a cell's centre.
func cell_pos(col: int, row: int) -> Vector3:
	var x := (col - (COLS - 1) * 0.5) * CELL
	var y := 0.3 + plate_size.y * MARGIN.y + (row + 0.5) * CELL
	return Vector3(x, y, 0)


func top_pos(col: int) -> Vector3:
	return cell_pos(col, ROWS) + Vector3(0, 0.25, 0)


func show_hover(col: int, color: Color) -> void:
	hover.visible = col >= 0
	if col < 0:
		return
	hover.material_override = _mat(color)
	hover.position = hover.position.lerp(top_pos(col), 0.5) if hover.visible else top_pos(col)


## Drop a disc into (col, row). Returns the tween so you can await it.
func drop(col: int, row: int, color: Color) -> Tween:
	var d := _new_disc(color)
	d.position = top_pos(col)
	discs[Vector2i(col, row)] = d
	var target := cell_pos(col, row)
	var tw := create_tween()
	var t := 0.12 + 0.05 * (ROWS - row)
	tw.tween_property(d, "position", target, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(d, "position", target + Vector3(0, 0.08, 0), 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "position", target, 0.06).set_ease(Tween.EASE_IN)
	return tw


## Make the four winning discs pulse.
func celebrate(cells: Array) -> void:
	for c in cells:
		var d: MeshInstance3D = discs.get(c)
		if d == null:
			continue
		var m := (d.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		d.material_override = m
		var tw := create_tween().set_loops(6)
		tw.tween_method(func(f: float) -> void: m.set_shader_parameter("emission", f), 0.0, 0.8, 0.2)
		tw.tween_method(func(f: float) -> void: m.set_shader_parameter("emission", f), 0.8, 0.0, 0.2)


func clear() -> void:
	for k in discs:
		(discs[k] as Node).queue_free()
	discs.clear()
