extends SceneTree
var f: FileAccess
func log_line(s: String) -> void:
	f.store_line(s); f.flush()
func _init() -> void:
	f = FileAccess.open("res://tools/test/suspects.log", FileAccess.WRITE)
	for p in ["res://assets/industrial/building-a.glb", "res://assets/industrial/building-c.glb", "res://assets/industrial/building-f.glb", "res://assets/industrial/building-m.glb", "res://assets/city/building-i.glb", "res://assets/roads/road-crossroad-line.glb", "res://assets/roads/light-curved.glb", "res://assets/cars/truck.glb"]:
		log_line("mesh " + p)
		var m := Toon.merged_mesh(p)
		log_line("  boxes")
		var b := Toon.box_stack(m)
		log_line("  ok " + str(b.size()))
	log_line("load noir")
	var sc: GDScript = load("res://scripts/dim_noir.gd")
	log_line("new noir")
	var d = sc.new()
	log_line("done " + str(d.title))
	quit()
