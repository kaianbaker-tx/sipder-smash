extends Node3D
## Spider Smash main scene: builds the world and runs the story.

var look: Node
var city: Node3D
var player: Player
var rig: CamRig
var world: Node3D


func _ready() -> void:
	world = self
	look = load("res://scripts/comic_look.gd").new()
	look.name = "Look"
	add_child(look)
	city = load("res://scripts/city.gd").new()
	city.name = "City"
	city.add_to_group("city")
	add_child(city)
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(8, 1, 40)
	rig = CamRig.new()
	rig.target = player
	add_child(rig)
	player.rig = rig
	look.attach(rig.cam)
	Fx.setup(self, rig, look)
	if Game.args.has("autoplay"):
		var ap: Node = load("res://tools/autoplay.gd").new()
		ap.main = self
		add_child(ap)
	_spawn_test_bots()
	match Game.args.get("autoplay", ""):
		"fight":
			var b := GlitchBot.new()
			add_child(b)
			b.global_position = player.global_position + Vector3(0, 3.5, -9)
			b.home = b.global_position
		"climb":
			player.global_position = Vector3(40, 0.5, 72)


func _spawn_test_bots() -> void:
	for i in 5:
		var b := GlitchBot.new()
		add_child(b)
		b.global_position = Vector3(-10 + i * 6, 14 + i, -10)
		b.home = b.global_position


func _process(_delta: float) -> void:
	look.speed = clampf((player.velocity.length() - 22.0) / 25.0, 0.0, 1.0)
