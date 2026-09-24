extends Node3D
var h: HeroModel
var f := 0
func _ready() -> void:
	h = HeroModel.new(); h.skin = load("res://assets/hero/suits/noir.png"); add_child(h)
	h.aim_right = Vector3(0, 1, 0); h.aim_right_w = 1.0
func _process(_d: float) -> void:
	f += 1
	if f == 10:
		var sk := h.skeleton
		for b in ["RightArm", "RightForeArm", "RightHand", "LeftHand"]:
			var i := sk.find_bone(b)
			print(b, " world pos ", sk.global_transform * sk.get_bone_global_pose(i).origin)
		get_tree().quit()
