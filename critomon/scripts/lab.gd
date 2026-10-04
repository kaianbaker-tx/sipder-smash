class_name Lab
extends Builder
## Inside Professor Birch's Lab, built far away from town (walls only show
## from the inside, so the camera can sit "outside" and still see in).
## The big table in the middle holds three Critter Balls: pick your first
## Crittermon here!

const ORIGIN := Vector3(400, 0, 0)
const HALF := Vector2(9, 11)          # room half size (x, z)
const TABLE := Vector3(0, 0, -2)       # table centre (local)
const EXIT := Vector3(0, 0, 10.3)      # stand here to leave
const SPAWN := Vector3(0, 0, 8.6)      # where you appear coming in

var balls: Array[CritterBall] = []       # one per starter, same order as Dex.STARTERS
var stands: Array[Node3D] = []
var _t := 0.0


func build() -> void:
	position = ORIGIN
	seed(3)
	_room()
	_table()
	_shelves()
	_machines()
	flush_batches()


func to_world(p: Vector3) -> Vector3:
	return ORIGIN + p


func ball_pos(i: int) -> Vector3:
	return to_world(TABLE + Vector3((i - 1) * 1.5, 1.32, 0))


func _wall(center: Vector3, size: Vector2, yaw: float, col: Color, opts := {}) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = Toon.color(col, opts)
	mi.position = center
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _checker(a: Color, b: Color) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var edge := x % 32 == 0 or y % 32 == 0
			var c := a if (x / 32 + y / 32) % 2 == 0 else b
			img.set_pixel(x, y, c.darkened(0.08) if edge else c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _room() -> void:
	var w := HALF.x
	var d := HALF.y
	var h := 5.0
	# floor: big cream and blue tiles
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w * 2, d * 2)
	floor.mesh = pm
	floor.material_override = Toon.material(_checker(Color(0.93, 0.88, 0.76), Color(0.62, 0.78, 0.94)), {"uv_scale": Vector2(w, d) / 1.5, "rim": 0.0})
	add_child(floor)
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	statics.add_child(cs)
	var cream := Color(0.98, 0.95, 0.86)
	var trim := Color(0.35, 0.62, 0.72)
	# walls face inwards (you can't see them from outside)
	_wall(Vector3(0, h / 2, -d), Vector2(w * 2, h), 0.0, cream)
	_wall(Vector3(0, h / 2, d), Vector2(w * 2, h), PI, cream)
	_wall(Vector3(w, h / 2, 0), Vector2(d * 2, h), -PI / 2, cream)
	_wall(Vector3(-w, h / 2, 0), Vector2(d * 2, h), PI / 2, cream)
	_wall(Vector3(0, 0.6, -d + 0.02), Vector2(w * 2, 1.2), 0.0, trim)
	_wall(Vector3(0, 0.6, d - 0.02), Vector2(w * 2, 1.2), PI, trim)
	_wall(Vector3(w - 0.02, 0.6, 0), Vector2(d * 2, 1.2), -PI / 2, trim)
	_wall(Vector3(-w + 0.02, 0.6, 0), Vector2(d * 2, 1.2), PI / 2, trim)
	_wall(Vector3(0, h, 0), Vector2(w * 2, d * 2), 0.0, cream)  # ceiling is never seen; keeps shadows sane
	get_child(get_child_count() - 1).rotation = Vector3(PI / 2, 0, 0)
	for z in [-d - 0.5, d + 0.5]:
		box_wall(Vector3(0, h / 2, z), Vector3(w * 2 + 2, h, 1))
	for x in [-w - 0.5, w + 0.5]:
		box_wall(Vector3(x, h / 2, 0), Vector3(1, h, d * 2 + 2))
	# windows on the back wall and a poster
	for x in [-3.4, 3.4]:
		box(Vector3(3.0, 1.8, 0.1), Vector3(x, 2.9, -d + 0.06), Color(0.6, 0.85, 1.0), 0.0, null, {"emission": 0.45})
		box(Vector3(3.2, 0.14, 0.2), Vector3(x, 1.95, -d + 0.1), Color.WHITE)
		box(Vector3(0.1, 1.8, 0.14), Vector3(x, 2.9, -d + 0.1), Color.WHITE)
	box(Vector3(3.4, 1.6, 0.06), Vector3(0, 3.1, -d + 0.05), Color(1.0, 0.85, 0.3))
	var p := words("CRITTERMON\nCATCH 'EM!", Vector3(0, 3.1, -d + 0.1), 0.0, 44, Color(0.93, 0.25, 0.25), Color.WHITE)
	p.double_sided = false
	# door and mat
	box(Vector3(2.4, 3.0, 0.1), Vector3(0, 1.5, d - 0.06), Color(0.5, 0.78, 1.0), 0.0, null, {"emission": 0.3})
	var mat := box(Vector3(3.0, 0.03, 1.6), Vector3(0, 0.015, d - 1.2), Color(0.85, 0.3, 0.3))
	mat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rug := disc(3.6, 0.02, TABLE + Vector3(0, 0.01, 0), Color(0.93, 0.35, 0.35))
	rug.scale = Vector3(1.3, 1, 1)
	var rug2 := disc(3.2, 0.022, TABLE + Vector3(0, 0.012, 0), Color(1.0, 0.85, 0.4))
	rug2.scale = Vector3(1.3, 1, 1)


func _table() -> void:
	var t := TABLE
	var white := Color(0.97, 0.97, 0.98)
	var blue := Color(0.25, 0.5, 0.9)
	box(Vector3(5.2, 0.22, 1.9), t + Vector3(0, 1.0, 0), white)
	box(Vector3(5.3, 0.08, 2.0), t + Vector3(0, 0.88, 0), blue)
	box(Vector3(4.8, 0.8, 1.5), t + Vector3(0, 0.45, 0), Color(0.82, 0.84, 0.9))
	box_wall(t + Vector3(0, 0.6, 0), Vector3(5.3, 1.2, 2.0))
	for i in 3:
		var sp := t + Vector3((i - 1) * 1.5, 1.11, 0)
		var stand := Node3D.new()
		stand.position = sp
		add_child(stand)
		var ring := disc(0.32, 0.08, Vector3.ZERO, Color(0.6, 0.9, 1.0), stand, {"emission": 0.6})
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc(0.22, 0.1, Vector3(0, 0.02, 0), Color(0.3, 0.35, 0.45), stand)
		stands.append(stand)
		var b := CritterBall.new()
		b.position = sp + Vector3(0, 0.21, 0)
		b.scale = Vector3.ONE * 1.1
		add_child(b)
		balls.append(b)
	# little name cards in front of each ball
	var cols := [Color(1.0, 0.5, 0.2), Color(0.3, 0.6, 1.0), Color(0.35, 0.8, 0.35)]
	for i in 3:
		box(Vector3(0.6, 0.3, 0.05), t + Vector3((i - 1) * 1.5, 1.25, 0.8), cols[i])
		var tag := words(["FIRE", "WATER", "GRASS"][i], t + Vector3((i - 1) * 1.5, 1.25, 0.83), 0.0, 22)
		tag.pixel_size = 0.008


func _shelves() -> void:
	var book_cols := [Color(0.9, 0.3, 0.3), Color(0.3, 0.5, 0.9), Color(0.95, 0.8, 0.25), Color(0.4, 0.75, 0.4), Color(0.7, 0.45, 0.85), Color(1.0, 0.6, 0.3)]
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	var book_mat := Toon.color(Color.WHITE, {"use_custom": true, "rim": 0.1})
	for side in [-1.0, 1.0]:
		for k in 1:
			var c := Vector3(side * 6.6, 0, -HALF.y + 0.55)
			box(Vector3(2.2, 3.4, 0.9), c + Vector3(0, 1.7, 0), Color(0.62, 0.42, 0.28))
			box(Vector3(2.0, 3.2, 0.1), c + Vector3(0, 1.7, 0.4), Color(0.45, 0.3, 0.2))
			for shelf in 4:
				var y := 0.35 + shelf * 0.8
				box(Vector3(2.0, 0.06, 0.8), c + Vector3(0, y, 0.05), Color(0.7, 0.5, 0.34))
				var bx := -0.92
				while bx < 0.9:
					var bw := randf_range(0.12, 0.2)
					var bh := randf_range(0.45, 0.62)
					var xf := Transform3D(Basis().scaled(Vector3(bw, bh, 0.5)).rotated(Vector3.FORWARD, randf_range(-0.06, 0.06)), c + Vector3(bx + bw * 0.5, y + bh * 0.5 + 0.03, 0.12))
					batch("books", bm, xf, book_mat, book_cols[randi() % book_cols.size()])
					bx += bw + 0.02
			box_wall(c + Vector3(0, 1.7, 0), Vector3(2.2, 3.4, 0.9))


func _machines() -> void:
	# computers along the west wall
	for i in 2:
		var c := Vector3(-HALF.x + 0.8, 0, 3.0 + i * 2.6)
		box(Vector3(1.2, 1.0, 2.0), c + Vector3(0, 0.5, 0), Color(0.85, 0.87, 0.92))
		box(Vector3(0.5, 0.8, 1.1), c + Vector3(0.1, 1.45, 0), Color(0.3, 0.32, 0.4))
		box(Vector3(0.05, 0.62, 0.9), c + Vector3(0.36, 1.45, 0), Color(0.3, 0.8, 1.0), 0.0, null, {"emission": 0.7})
		box_wall(c + Vector3(0, 0.9, 0), Vector3(1.2, 1.8, 2.0))
	interactables.append({"pos": to_world(Vector3(-HALF.x + 2.2, 0, 4.3)), "r": 1.8, "label": "LOOK", "text": "The computer shows a map. Route 1 goes north to THE ARENA!"})
	# healing machine on the east wall
	var hm := Vector3(HALF.x - 0.9, 0, 4.0)
	box(Vector3(1.4, 1.2, 2.4), hm + Vector3(0, 0.6, 0), Color(0.95, 0.95, 0.97))
	box(Vector3(1.2, 0.1, 2.2), hm + Vector3(0, 1.22, 0), Color(0.93, 0.3, 0.35))
	for j in 3:
		var b := CritterBall.new()
		b.position = hm + Vector3(0, 1.4, (j - 1) * 0.6)
		b.rotation.y = -PI / 2
		add_child(b)
	var glass := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	glass.mesh = sm
	glass.material_override = Toon.color(Color(0.6, 1.0, 0.8), {"emission": 0.6})
	glass.position = hm + Vector3(0, 2.0, 0)
	glass.scale = Vector3(0.8, 0.6, 1.6)
	add_child(glass)
	box_wall(hm + Vector3(0, 0.8, 0), Vector3(1.4, 1.6, 2.4))
	interactables.append({"pos": to_world(hm + Vector3(-1.6, 0, 0)), "r": 1.8, "label": "HEAL", "heal": true})
	# plants in the corners
	for p in [Vector3(-HALF.x + 0.9, 0, HALF.y - 0.9), Vector3(HALF.x - 0.9, 0, HALF.y - 0.9), Vector3(-HALF.x + 0.9, 0, -HALF.y + 2.2), Vector3(HALF.x - 0.9, 0, -HALF.y + 2.2)]:
		disc(0.4, 0.7, p + Vector3(0, 0.35, 0), Color(0.85, 0.5, 0.3))
		for k in 3:
			var leaf := MeshInstance3D.new()
			var lm := SphereMesh.new()
			lm.radius = 0.45
			lm.height = 0.9
			lm.radial_segments = 10
			lm.rings = 5
			leaf.mesh = lm
			leaf.material_override = Toon.color(Color(0.35, 0.72, 0.38), {"rim": 0.3})
			leaf.position = p + Vector3(randf_range(-0.2, 0.2), 1.0 + k * 0.35, randf_range(-0.2, 0.2))
			add_child(leaf)
		cyl_wall(p, 0.5, 1.6)


func _process(delta: float) -> void:
	_t += delta
	for i in balls.size():
		var b := balls[i]
		if b.visible:
			b.rotation.y = sin(_t * 1.2 + i) * 0.5
			b.position.y = TABLE.y + 1.32 + sin(_t * 2.0 + i * 1.3) * 0.04
