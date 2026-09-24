extends Node3D
var frames := 0
func _ready() -> void:
	var cam := Camera3D.new(); add_child(cam); cam.position = Vector3(0, 1.2, 4); cam.look_at(Vector3(0, 1, 0))
	var l := DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-45, 30, 0)
	var ch: Node3D = (load("res://assets/hero/characterMedium.fbx") as PackedScene).instantiate()
	add_child(ch); ch.scale = Vector3.ONE * 0.48
	var b: Node3D = (load("res://assets/city/building-skyscraper-a.glb") as PackedScene).instantiate()
	add_child(b); b.position = Vector3(3, 0, -4)
	print("renderer: ", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_current_rendering_method())
func _process(_d: float) -> void:
	frames += 1
	if frames == 10:
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-user-sipder-smash/a2a12b10-57b3-5066-938b-7aa665ee9353/scratchpad/test.png")
		get_tree().quit()
