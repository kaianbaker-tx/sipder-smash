extends SceneTree
func _init() -> void:
	var inst: Node = (load("res://assets/hero/characterMedium.fbx") as PackedScene).instantiate()
	var mi: MeshInstance3D = inst.find_child("characterMedium", true, false)
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var arr := mi.mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var skin := mi.skin
	var bpv := bones.size() / uv.size()
	print("verts ", uv.size(), " tris ", idx.size() / 3, " bones/vert ", bpv, " skin binds ", skin.get_bind_count() if skin else -1)
	var out := {"uv": [], "bone": [], "idx": Array(idx), "pos": [], "nrm": []}
	for i in uv.size():
		var best := 0; var bw := -1.0
		for k in bpv:
			if weights[i * bpv + k] > bw: bw = weights[i * bpv + k]; best = bones[i * bpv + k]
		var bname: String = ""
		if skin and skin.get_bind_name(best) != &"":
			bname = skin.get_bind_name(best)
		elif skin:
			bname = sk.get_bone_name(skin.get_bind_bone(best))
		else:
			bname = sk.get_bone_name(best)
		out.uv.append([uv[i].x, uv[i].y]); out.bone.append(bname)
		out.pos.append([verts[i].x, verts[i].y, verts[i].z]); out.nrm.append([nrm[i].x, nrm[i].y, nrm[i].z])
	var f := FileAccess.open("res://tools/uv.json", FileAccess.WRITE); f.store_string(JSON.stringify(out)); f.close()
	inst.free(); quit()
