extends SceneTree
## How long does the Connect Four computer take to think?
## godot --headless -s res://tools/test/c4_bench.gd -- 1 3 5

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var c := ConnectFour.new()
	root.add_child(c)
	c.grid.resize(42)
	c.grid.fill(0)
	# a few discs in the middle, like a real game
	for m in [[3, 1], [3, 2], [2, 1], [4, 2]]:
		var r := ConnectFour._open_row(c.grid, m[0])
		c.grid[r * 7 + m[0]] = m[1]
	for a in OS.get_cmdline_user_args():
		var t := Time.get_ticks_usec()
		var col: int = await c._ai_move(int(a), 2)
		print("depth ", a, ": ", (Time.get_ticks_usec() - t) / 1000.0, " ms over 7 frames -> column ", col)
	quit()
