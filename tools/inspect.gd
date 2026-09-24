extends SceneTree

func dump(n: Node, depth: int) -> void:
	var s := "  ".repeat(depth) + n.name + " (" + n.get_class() + ")"
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		s += " aabb=" + str(mi.get_aabb()) + " surfaces=" + str(mi.mesh.get_surface_count())
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			s += " mat" + str(i) + "=" + (str(m.resource_name) + ":" + m.get_class() if m else "null")
			if m is StandardMaterial3D:
				s += " tex=" + str((m as StandardMaterial3D).albedo_texture.resource_path if (m as StandardMaterial3D).albedo_texture else "none")
	if n is Node3D:
		s += " pos=" + str((n as Node3D).position) + " scale=" + str((n as Node3D).scale)
	if n is Skeleton3D:
		var sk := n as Skeleton3D
		s += " bones=" + str(sk.get_bone_count())
		for b in sk.get_bone_count():
			s += "\n" + "  ".repeat(depth + 2) + str(b) + ":" + sk.get_bone_name(b) + " parent=" + str(sk.get_bone_parent(b)) + " rest_o=" + str(sk.get_bone_global_rest(b).origin)
	if n is AnimationPlayer:
		var ap := n as AnimationPlayer
		for a in ap.get_animation_list():
			var an := ap.get_animation(a)
			s += "\n" + "  ".repeat(depth + 2) + "anim " + a + " len=" + str(an.length) + " tracks=" + str(an.get_track_count())
			for t in min(4, an.get_track_count()):
				s += "\n" + "  ".repeat(depth + 3) + str(an.track_get_path(t)) + " type=" + str(an.track_get_type(t))
	print(s)
	for c in n.get_children():
		dump(c, depth + 1)

func _init() -> void:
	for p in OS.get_cmdline_user_args():
		print("=== ", p)
		var sc: PackedScene = load(p)
		var inst := sc.instantiate()
		dump(inst, 0)
		inst.free()
	quit()
