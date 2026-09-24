extends Node3D
## Golden spider tokens hidden on rooftops and floating over the streets.
## Collect 25 to unlock the GOLDEN suit.

const TEX := preload("res://assets/ui/token.png")

var tokens: Array[Sprite3D] = []
var total := 0
var player: Player
var _t := 0.0


func setup(city: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var spots: Array = city.roof_spots.duplicate()
	spots.shuffle()
	var count := 0
	for s in spots:
		if count >= 30:
			break
		_add((s as Vector3) + Vector3(0, 1.2, 0))
		count += 1
	# floating trails over the avenues, great to swing through
	for k in 14:
		var along_x := k % 2 == 0
		var lane := (rng.randi_range(-3, 3)) * 64.0
		var start := rng.randf_range(-150.0, 110.0)
		var h := rng.randf_range(18.0, 34.0)
		for j in 3:
			var p := Vector3(start + j * 9.0, h + sin(j) * 2.0, lane) if along_x else Vector3(lane, h + sin(j) * 2.0, start + j * 9.0)
			_add(p)


func _add(p: Vector3) -> void:
	var s := Sprite3D.new()
	s.texture = TEX
	s.pixel_size = 0.0075
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.position = p
	s.set_meta("base", p)
	add_child(s)
	tokens.append(s)
	total += 1
	Game.token_total = total


func _process(delta: float) -> void:
	_t += delta
	if not player:
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return
	var c := player.center()
	for i in range(tokens.size() - 1, -1, -1):
		var s := tokens[i]
		var base: Vector3 = s.get_meta("base")
		s.position = base + Vector3(0, sin(_t * 2.0 + i) * 0.35, 0)
		# fake spin by squashing
		s.scale = Vector3(absf(cos(_t * 2.5 + i * 0.7)) * 0.8 + 0.2, 1, 1)
		if s.position.distance_to(c) < 2.6:
			Game.add_token()
			Sfx.play("token", 0.05)
			Fx.word("+50", s.position + Vector3(0, 1, 0), "small", Color(1, 0.85, 0.2))
			Fx.burst(s.position, Color(1, 0.8, 0.2), 10, 6.0, 0.2)
			s.queue_free()
			tokens.remove_at(i)
