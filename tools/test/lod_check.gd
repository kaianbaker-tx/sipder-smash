extends SceneTree
func _init() -> void:
	for p in ["res://assets/city/building-skyscraper-d.glb", "res://assets/city/building-a.glb", "res://assets/cars/taxi.glb", "res://assets/roads/road-straight.glb"]:
		var m := Toon.merged_mesh(p)
		print(p.get_file(), " surfaces=", m.get_surface_count(), " lods(sfc0)=", m.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3, " class=", m.get_class(), " lod count: ", m.call("surface_get_lods", 0) if m.has_method("surface_get_lods") else "?")
	quit()
