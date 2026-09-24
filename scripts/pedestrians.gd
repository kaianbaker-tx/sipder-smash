extends Node3D
## City folks walking the sidewalks. They panic near Glitch-Bots
## and cheer when the spider hero swings by.

const SKINS := ["skaterMaleA", "skaterFemaleA", "criminalMaleA", "cyborgFemaleA"]
const CHEERS := ["GO SPIDEY!", "WOW!", "MY HERO!", "SO COOL!", "THANKS!", "YEAH!"]
const SCREAMS := ["AAAH!", "EEK!", "RUN!", "HELP!"]

var rng := RandomNumberGenerator.new()
var people: Array = []
var player: Player


class Person:
	var model: HeroModel
	var corners: Array = []
	var leg := 0
	var t := 0.0
	var speed := 2.4
	var cheer_cd := 0.0
	var shout_cd := 0.0
	var cheering := 0.0


func _ready() -> void:
	rng.seed = 5
	var skins := []
	for s in SKINS:
		skins.append(load("res://assets/hero/skins/%s.png" % s))
	for i in 18:
		var p := Person.new()
		p.model = HeroModel.new()
		p.model.skin = skins[i % skins.size()]
		p.model.height = rng.randf_range(1.6, 1.85)
		add_child(p.model)
		# a loop around a random block, on the sidewalk
		var bx := rng.randi_range(0, 5)
		var bz := rng.randi_range(0, 5)
		var c := Vector3((-10 + bx * 4) * 16.0, 0.32, (-10 + bz * 4) * 16.0)
		var h := 16.0 * 1.5 - 1.7
		p.corners = [c + Vector3(-h, 0, -h), c + Vector3(h, 0, -h), c + Vector3(h, 0, h), c + Vector3(-h, 0, h)]
		if rng.randf() < 0.5:
			p.corners.reverse()
		p.leg = rng.randi_range(0, 3)
		p.t = rng.randf()
		p.speed = rng.randf_range(1.8, 3.0)
		people.append(p)


func _physics_process(delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player") as Player
	var bots := get_tree().get_nodes_in_group("enemies")
	for p in people:
		var per := p as Person
		per.cheer_cd -= delta
		per.shout_cd -= delta
		var a: Vector3 = per.corners[per.leg]
		var b: Vector3 = per.corners[(per.leg + 1) % 4]
		var pos := a.lerp(b, per.t)
		# danger?
		var scared := false
		for e in bots:
			if (e as Node3D).global_position.distance_to(pos) < 22.0:
				scared = true
				break
		var near_hero := player and player.global_position.distance_to(pos) < 7.0 and player.velocity.length() < 16.0
		if near_hero and per.cheer_cd <= 0.0 and not scared:
			per.cheering = 2.2
			per.cheer_cd = 12.0
			per.model.restart("jump")
			Fx.word(CHEERS[rng.randi() % CHEERS.size()], pos + Vector3(0, 2.4, 0), "small", Color(1, 1, 1))
		if per.cheering > 0.0:
			per.cheering -= delta
			if player:
				var to := player.global_position - pos
				to.y = 0
				if to.length() > 0.1:
					per.model.global_transform = Transform3D(Basis.looking_at(to.normalized(), Vector3.UP), pos)
			if fmod(per.cheering, 0.7) < delta:
				per.model.restart("jump")
			continue
		var spd := per.speed * (2.6 if scared else 1.0)
		if scared and per.shout_cd <= 0.0 and rng.randf() < 0.01:
			per.shout_cd = 6.0
			Fx.word(SCREAMS[rng.randi() % SCREAMS.size()], pos + Vector3(0, 2.3, 0), "small", Color(1, 0.6, 0.7))
		per.t += spd * delta / a.distance_to(b)
		if per.t >= 1.0:
			per.t = 0.0
			per.leg = (per.leg + 1) % 4
		var dir := (b - a).normalized()
		per.model.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), pos)
		per.model.play("run", 0.15, spd / 6.0 + 0.25)
