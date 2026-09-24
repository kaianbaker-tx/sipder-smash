extends SceneTree
func _init() -> void:
	var inst: Node = (load("res://assets/cars/taxi.glb") as PackedScene).instantiate()
	for n in inst.find_children("*", "Node3D", true, false):
		print(n.name, " ", (n as Node3D).position)
	inst.free()
	quit()
