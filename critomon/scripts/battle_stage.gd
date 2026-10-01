class_name BattleStage
extends Builder
## The place battles happen: a grassy clearing far from town with two round
## battle pads. Your Crito Mon stands on the near pad, the other one far.

const ORIGIN := Vector3(0, 0, 560)
const MY_PAD := Vector3(-1.7, 0.45, 3.6)
const FOE_PAD := Vector3(1.9, 0.45, -4.2)
const MY_TRAINER := Vector3(-3.4, 0.0, 6.6)
const FOE_TRAINER := Vector3(4.3, 0.0, -7.2)
const CAM_POS := Vector3(1.6, 2.7, 11.0)
const CAM_LOOK := Vector3(0.2, 1.1, -1.2)


func build() -> void:
	position = ORIGIN
	seed(11)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	g.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	mat.set_shader_parameter("map_tex", ImageTexture.create_from_image(img))
	g.material_override = mat
	add_child(g)
	for pad in [MY_PAD, FOE_PAD]:
		var p := Toon.model("res://assets/platformer/platform-grass-large-round.glb", {"rim": 0.2})
		p.scale = Vector3(0.85, 0.9, 0.85)
		p.position = pad - Vector3(0, 0.45, 0)
		add_child(p)
	# a ring of trees, flowers and a few rocks round the clearing
	for i in 46:
		var a := i * TAU / 46.0 + randf_range(-0.05, 0.05)
		var r := randf_range(20, 30)
		tree(Vector3(cos(a) * r, 0, sin(a) * r), -1, randf_range(1.0, 1.5), false)
	for i in 30:
		var a := randf() * TAU
		var r := randf_range(34, 60)
		tree(Vector3(cos(a) * r, 0, sin(a) * r), -1, randf_range(1.1, 1.6), false)
	flowers(Vector3(-6, 0, 0), 3.0, 30)
	flowers(Vector3(7, 0, 2), 3.0, 30)
	flowers(Vector3(-2, 0, -12), 4.0, 40)
	var grass_mesh := Toon.mesh("res://assets/platformer/grass.glb")
	var tex := Toon._find_texture(grass_mesh.surface_get_material(0))
	var gmat := Toon.material(tex, {"wind": 0.09, "rim": 0.15, "use_custom": true})
	for i in 70:
		var a := randf() * TAU
		var r := randf_range(7, 18)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		batch("tallgrass", grass_mesh, Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * randf_range(2.6, 3.2)), p), gmat, Color(0.78, 1.0, 0.62).lerp(Color(0.62, 0.9, 0.5), randf()))
	flush_batches()


func w(p: Vector3) -> Vector3:
	return ORIGIN + p
