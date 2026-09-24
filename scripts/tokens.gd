extends Node3D
## Golden spider tokens hidden on rooftops and floating over the streets.
## Collect 25 to unlock the GOLDEN suit. All tokens draw in one batch.

const TEX := preload("res://assets/ui/token.png")

var spots: Array[Vector3] = []
var taken: Array[bool] = []
var total := 0
var player: Player
var batch: SpriteBatch
var _t := 0.0
var _city: Node


## Put every token back (new game).
func reset() -> void:
	for i in taken.size():
		taken[i] = false


func setup(city: Node) -> void:
	_city = city
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var roofs: Array = city.roof_spots.duplicate()
	roofs.shuffle()
	var count := 0
	for s in roofs:
		if count >= 30:
			break
		spots.append((s as Vector3) + Vector3(0, 1.2, 0))
		count += 1
	# floating trails over the avenues, great to swing through
	for k in 14:
		var along_x := k % 2 == 0
		var lane := (rng.randi_range(-3, 3)) * 64.0
		var start := rng.randf_range(-150.0, 110.0)
		var h := rng.randf_range(18.0, 34.0)
		for j in 3:
			var p := Vector3(start + j * 9.0, h + sin(j) * 2.0, lane) if along_x else Vector3(lane, h + sin(j) * 2.0, start + j * 9.0)
			spots.append(p)
	for i in spots.size():
		taken.append(false)
	total = spots.size()
	Game.token_total = total
	batch = SpriteBatch.new()
	add_child(batch)
	batch.setup(TEX, Vector2(1.9, 1.9), total)


func _process(delta: float) -> void:
	_t += delta
	if not player:
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return
	var c := player.center()
	for i in spots.size():
		if taken[i]:
			batch.hide_one(i)
			continue
		var p := spots[i] + Vector3(0, sin(_t * 2.0 + i) * 0.35, 0)
		# fake spin by squashing
		batch.put(i, p, Vector2(absf(cos(_t * 2.5 + i * 0.7)) * 0.8 + 0.2, 1.0))
		if Game.playing and p.distance_to(c) < 2.6:
			taken[i] = true
			Game.add_token()
			Sfx.play("token", 0.05)
			Fx.word("+50", p + Vector3(0, 1, 0), "small", Color(1, 0.85, 0.2))
			Fx.burst(p, Color(1, 0.8, 0.2), 10, 6.0, 0.2)
