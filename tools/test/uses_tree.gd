extends Node

func f() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	print(p)
