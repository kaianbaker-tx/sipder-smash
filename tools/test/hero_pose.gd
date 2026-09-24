extends Node3D
var frames := 0
var heroes := []
func _ready() -> void:
	var look: Node = load("res://scripts/comic_look.gd").new(); add_child(look)
	var floor_m := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); floor_m.mesh = pm
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8); img.fill(Color(0.7, 0.65, 0.8))
	floor_m.material_override = Toon.material(ImageTexture.create_from_image(img)); add_child(floor_m)
	var suits := ["classic", "midnight", "ghost", "noir", "gold", "classic"]
	for i in 6:
		var h := HeroModel.new()
		h.skin = load("res://assets/hero/suits/%s.png" % suits[i])
		add_child(h)
		h.position = Vector3(-5 + i * 2.0, 0, 0)
		h.rotation.y = deg_to_rad(160)
		heroes.append(h)
	heroes[1].play("run")
	heroes[2].spread = 1.0
	heroes[3].aim_right = Vector3(0.4, 1, -0.3).normalized(); heroes[3].aim_right_w = 1.0; heroes[3].tuck = 0.8
	heroes[4].punch = 1.0; heroes[4].punch_side = 1
	heroes[5].crouch = 1.0
	var cam := Camera3D.new(); add_child(cam); cam.position = Vector3(0, 1.4, 6.0); cam.look_at(Vector3(0, 1.0, 0)); cam.fov = 60; cam.near = 0.3
	look.attach(cam)
func _process(_d: float) -> void:
	frames += 1
	if frames == 30:
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-user-sipder-smash/a2a12b10-57b3-5066-938b-7aa665ee9353/scratchpad/poses.png")
		get_tree().quit()
