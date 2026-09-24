extends SceneTree
func _init() -> void:
	for p in OS.get_cmdline_user_args():
		var inst: Node = (load(p) as PackedScene).instantiate()
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		for a in ap.get_animation_list():
			if a.contains("Targeting"): continue
			var an := ap.get_animation(a)
			var names := []
			for t in an.get_track_count():
				names.append(str(an.track_get_path(t)).get_slice(":", 1) + ["","P","R","S"][an.track_get_type(t)] + str(an.track_get_key_count(t)))
			print(p.get_file(), " ", a, ": ", ", ".join(names))
		inst.free()
	quit()
