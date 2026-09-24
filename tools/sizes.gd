extends SceneTree
func merged_aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D: t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var a: AABB = t * (n as MeshInstance3D).get_aabb()
		if acc.is_empty(): acc.append(a)
		else: acc[0] = (acc[0] as AABB).merge(a)
	for c in n.get_children(): merged_aabb(c, t, acc)
func _init() -> void:
	for dir in OS.get_cmdline_user_args():
		var d := DirAccess.open(dir)
		for f in d.get_files():
			if not f.ends_with(".glb"): continue
			var inst: Node = (load(dir + "/" + f) as PackedScene).instantiate()
			var acc := []
			merged_aabb(inst, Transform3D.IDENTITY, acc)
			var a: AABB = acc[0]
			print("%-36s pos=(%.2f,%.2f,%.2f) size=(%.2f,%.2f,%.2f)" % [dir.get_file() + "/" + f, a.position.x, a.position.y, a.position.z, a.size.x, a.size.y, a.size.z])
			inst.free()
	quit()
