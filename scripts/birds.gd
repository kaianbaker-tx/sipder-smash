extends Node3D
## Flocks of pigeons circling over the rooftops. They scatter when the hero
## zooms through them.

const TEX := preload("res://assets/ui/bird.png")

var flocks: Array = []
var _t := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for f in 6:
		var centre := Vector3(rng.randf_range(-150, 150), rng.randf_range(45, 80), rng.randf_range(-150, 150))
		var birds: Array[Sprite3D] = []
		for b in 9:
			var s := Sprite3D.new()
			s.texture = TEX
			s.pixel_size = 0.03
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.shaded = false
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			add_child(s)
			birds.append(s)
		flocks.append({"centre": centre, "birds": birds, "r": rng.randf_range(14, 26), "speed": rng.randf_range(0.25, 0.45), "phase": rng.randf() * TAU, "scatter": 0.0})


func _process(delta: float) -> void:
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for f in flocks:
		var fl := f as Dictionary
		var c: Vector3 = fl.centre
		if player and player.global_position.distance_to(c) < 20.0 and fl.scatter <= 0.0:
			fl.scatter = 3.0
		fl.scatter = maxf(0.0, fl.scatter - delta)
		var spread: float = 1.0 + fl.scatter * 2.5
		var birds: Array = fl.birds
		for i in birds.size():
			var b := birds[i] as Sprite3D
			var a: float = _t * fl.speed + fl.phase + i * 0.35
			var r: float = fl.r * spread + sin(_t * 0.7 + i) * 3.0
			b.position = c + Vector3(cos(a) * r, sin(_t * 1.3 + i * 0.8) * 2.0 + i * 0.4 + fl.scatter * 3.0, sin(a) * r)
			# flap
			b.scale = Vector3(1.0, 0.4 + 0.6 * absf(sin(_t * 9.0 + i)), 1.0)
