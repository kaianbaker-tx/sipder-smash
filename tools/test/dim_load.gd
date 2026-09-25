extends SceneTree
func _init() -> void:
	printerr("A load")
	var sc: GDScript = load("res://scripts/dim_noir.gd")
	printerr("B new")
	var d = sc.new()
	printerr("C done ", d.title)
	quit()
