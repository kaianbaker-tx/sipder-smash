extends SceneTree
func _init() -> void:
	var f := FileAccess.open("res://tools/test/bisect.log", FileAccess.WRITE)
	for p in OS.get_cmdline_user_args():
		f.store_line("try " + p); f.flush()
		var sc: GDScript = load(p)
		f.store_line("  loaded"); f.flush()
		var d = sc.new()
		f.store_line("  new ok"); f.flush()
	quit()
