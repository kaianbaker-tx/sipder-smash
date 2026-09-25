extends SceneTree
func _init() -> void:
	var name: String = OS.get_cmdline_user_args()[0]
	var d: Dimension = load("res://scripts/dim_%s.gd" % name).new()
	root.add_child(d)
	var t0 := Time.get_ticks_msec()
	d.ensure_built()
	print("built ", name, " in ", Time.get_ticks_msec() - t0, " ms, children ", d.get_child_count(), " bots ", d.bot_spots.size(), " safe ", d.safe_spots.size())
	quit()
