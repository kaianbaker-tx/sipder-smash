extends Node3D
func _ready() -> void:
	var city: Node3D = load("res://scripts/city.gd").new(); add_child(city)
	var traffic: Node3D = load("res://scripts/traffic.gd").new(); add_child(traffic)
	await get_tree().process_frame
	var rows := {}
	for n in find_children("*", "", true, false):
		var tris := 0
		var name: String = n.name
		if n is MultiMeshInstance3D:
			var mm := (n as MultiMeshInstance3D).multimesh
			for s in mm.mesh.get_surface_count():
				var arr := mm.mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3) * mm.instance_count
		elif n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
			var m := (n as MeshInstance3D).mesh
			for s in m.get_surface_count():
				var arr := m.surface_get_arrays(s)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			name = "car:" + str((m as Resource).resource_path.get_file()) if n.get_parent() is AnimatableBody3D else name
		else:
			continue
		rows[name] = rows.get(name, 0) + tris
	var keys := rows.keys()
	keys.sort_custom(func(a, b) -> bool: return rows[a] > rows[b])
	var total := 0
	for k in keys:
		total += rows[k]
	for k in keys.slice(0, 25):
		print("%-40s %8d" % [k, rows[k]])
	print("TOTAL ", total)
	get_tree().quit()
