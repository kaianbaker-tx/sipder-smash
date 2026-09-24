class_name GlitchKing
extends Node3D
## THE GLITCH KING: a giant Glitch-Bot on top of Glitch Tower.
## Phase 1: bolt fans and dive slams. Phase 2: calls minions and charges.
## Phase 3: teleports around and fires bolt rings.

signal defeated
signal wants_minions(count: int, around: Vector3)

const MODEL := preload("res://assets/enemy/enemy-flying.glb")

var hp := 110
var max_hp := 110
var dead := false
var arena := Vector3.ZERO     # tower top centre
var player: Player
var mat: ShaderMaterial
var body: Node3D
var vel := Vector3.ZERO
var phase := 1
var _t := 0.0
var _fire_t := 2.5
var _slam_t := 7.0
var _minion_t := 3.0
var _blink_t := 4.0
var _orbit := 0.0
var _slamming := 0.0
var _slam_target := Vector3.ZERO
var _stun := 0.0
var _flash := 0.0
var _intro := 2.5


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	body = MODEL.instantiate()
	add_child(body)
	body.scale = Vector3.ONE * 9.0
	body.position = Vector3(0, -4.0, 0)
	var tex: Texture2D = null
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_active_material(0)
		if m is BaseMaterial3D:
			tex = (m as BaseMaterial3D).albedo_texture
			break
	mat = Toon.unique_material(tex, {"character": 1.0, "palette_shift": 0.72, "glitch": 0.35})
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	# a crown of glitch cubes
	for k in 5:
		var cube := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * 1.6
		cube.mesh = bm
		var cm := StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.albedo_color = [Color(1, 0.2, 0.6), Color(0.1, 0.95, 1), Color(1, 0.9, 0.2)][k % 3]
		cube.material_override = cm
		cube.name = "Crown%d" % k
		add_child(cube)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	if not player:
		player = get_tree().get_first_node_in_group("player") as Player
		return
	for k in 5:
		var c := get_node("Crown%d" % k) as Node3D
		var a := _t * 1.5 + k * TAU / 5.0
		c.position = Vector3(cos(a) * 3.2, 5.0 + sin(_t * 3.0 + k) * 0.5, sin(a) * 3.2)
		c.rotation = Vector3(_t * 2.0 + k, _t * 3.0, 0)
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	mat.set_shader_parameter("flash", _flash)
	var new_phase := 1 if hp > max_hp * 0.6 else (2 if hp > max_hp * 0.25 else 3)
	if new_phase != phase:
		phase = new_phase
		Fx.word("PHASE %d!" % phase, global_position + Vector3(0, 6, 0), "big", Color(1, 0.3, 0.6))
		Sfx.play("boss_roar")
		Fx.glitch(1.0)
		Fx.shake(1.0)
		mat.set_shader_parameter("glitch", 0.35 + 0.3 * (phase - 1))
	if _intro > 0.0:
		_intro -= delta
		_hover(delta, arena + Vector3(0, 16, 0))
		return
	if _stun > 0.0:
		_stun -= delta
		vel = vel.move_toward(Vector3.ZERO, delta * 20.0)
		global_position += vel * delta
		return
	if _slamming > 0.0:
		_slam(delta)
		return
	# orbit the tower top
	_orbit += delta * (0.35 + phase * 0.1)
	var goal := arena + Vector3(cos(_orbit) * 20.0, 14.0 + sin(_t * 0.8) * 3.0, sin(_orbit) * 20.0)
	_hover(delta, goal)
	var to_p := player.center() - global_position
	rotation.y = lerp_angle(rotation.y, atan2(to_p.x, to_p.z), 1.0 - exp(-delta * 4.0))
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = [3.0, 2.3, 1.8][phase - 1]
		if phase == 3:
			_ring_shot()
		else:
			_fan_shot(5 if phase == 1 else 7)
	_slam_t -= delta
	if _slam_t <= 0.0 and player.global_position.distance_to(arena) < 40.0:
		_slam_t = [8.0, 6.5, 5.5][phase - 1]
		_slamming = 1.6
		_slam_target = player.global_position
		Fx.word("INCOMING!", global_position + Vector3(0, 5, 0), "hit", Color(1, 0.5, 0.2))
		Sfx.play("alarm", 0.0, -6.0)
		player.spider_sense = 1.0
	if phase >= 2:
		_minion_t -= delta
		if _minion_t <= 0.0:
			_minion_t = 16.0
			wants_minions.emit(2 if phase == 2 else 3, global_position)
	if phase == 3:
		_blink_t -= delta
		if _blink_t <= 0.0:
			_blink_t = 5.0
			_blink()


func _hover(delta: float, goal: Vector3) -> void:
	var desired := (goal - global_position).limit_length(22.0)
	vel = vel.lerp(desired, 1.0 - exp(-delta * 1.5))
	global_position += vel * delta
	body.rotation.z = sin(_t * 1.3) * 0.1


func _slam(delta: float) -> void:
	_slamming -= delta
	if _slamming > 0.9:
		# rise and aim
		var up := _slam_target + Vector3(0, 22, 0)
		global_position = global_position.lerp(up, 1.0 - exp(-delta * 4.0))
		body.rotation.x = lerpf(body.rotation.x, 0.6, delta * 5.0)
	elif _slamming > 0.0:
		var to := _slam_target + Vector3(0, 3.5, 0) - global_position
		global_position += to.limit_length(70.0 * delta)
		if to.length() < 1.5:
			_slamming = 0.0
			_shockwave()
	if _slamming <= 0.0:
		body.rotation.x = 0.0


func _shockwave() -> void:
	Fx.word("KA-THOOM!", global_position, "big", Color(1, 0.6, 0.1))
	Fx.ring(global_position - Vector3(0, 3, 0), Color(1, 0.4, 0.8, 0.9), 18.0)
	Fx.ring(global_position - Vector3(0, 3, 0), Color(0.2, 0.9, 1.0, 0.9), 12.0)
	Fx.shake(1.5)
	Fx.impact(1.0)
	Sfx.play("land_hard")
	Sfx.play("explode", 0.1)
	var d := player.global_position.distance_to(global_position - Vector3(0, 3, 0))
	if d < 11.0 and player.is_on_floor():
		player.take_hit(1, global_position)
	_stun = 1.6   # tired after a slam: smash it now!
	vel = Vector3.ZERO
	Fx.word("DIZZY!", global_position + Vector3(0, 6, 0), "small", Color(1, 1, 0.4))


func _fan_shot(n: int) -> void:
	var muzzle := global_position + Vector3(0, -1, 0)
	var aim := (player.center() + player.velocity * 0.3 - muzzle).normalized()
	for i in n:
		var b := BotBolt.new()
		get_parent().add_child(b)
		b.global_position = muzzle
		b.launch(aim.rotated(Vector3.UP, (i - (n - 1) * 0.5) * 0.14), 20.0, player)
	Sfx.play("bot_shoot", 0.1)
	if player.center().distance_to(global_position) < 45.0:
		player.spider_sense = 1.0


func _ring_shot() -> void:
	var muzzle := global_position
	for i in 12:
		var a := i * TAU / 12.0
		var b := BotBolt.new()
		get_parent().add_child(b)
		b.global_position = muzzle
		var d := Vector3(cos(a), -0.35, sin(a)).normalized()
		b.launch(d, 16.0, player)
	Sfx.play("glitch")
	player.spider_sense = 1.0


func _blink() -> void:
	Fx.burst(global_position, Color(0.2, 1, 1), 16, 10.0, 0.5)
	Fx.glitch(0.8)
	Sfx.play("glitch")
	var a := randf() * TAU
	global_position = arena + Vector3(cos(a) * 18.0, 12.0, sin(a) * 18.0)
	Fx.burst(global_position, Color(1, 0.2, 0.7), 16, 10.0, 0.5)


func take_hit(dmg: int, dir: Vector3, big_hit: bool) -> void:
	if dead or _intro > 0.0:
		return
	hp -= dmg * (2 if _stun > 0.0 else 1)
	_flash = 0.55
	vel += dir * (6.0 if big_hit else 3.0)
	Fx.glitch(0.4)
	Sfx.play("bot_hurt", 0.1)
	if hp <= 0:
		_die()


func webbed() -> void:
	if dead:
		return
	_stun = maxf(_stun, 1.2)
	Fx.word("STUCK!", global_position + Vector3(0, 6, 0), "small", Color(1, 1, 1))


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	Game.add_score(5000)
	Sfx.play("boss_roar")
	Fx.impact(1.0)
	Fx.glitch(1.0)
	var tw := create_tween()
	for i in 8:
		tw.tween_callback(func() -> void:
			var p := global_position + Vector3(randf_range(-5, 5), randf_range(-3, 5), randf_range(-5, 5))
			Fx.burst(p, [Color(1, 0.8, 0.2), Color(0.2, 1, 1), Color(1, 0.2, 0.6)][randi() % 3], 20, 14.0, 0.6)
			Fx.ring(p, Color(1, 1, 1, 0.9), 10.0)
			Fx.shake(1.2)
			Sfx.play("explode", 0.15))
		tw.tween_interval(0.25)
	tw.tween_callback(func() -> void:
		Fx.word("KA-BLAMMO!!", global_position, "big", Color(1, 0.9, 0.2))
		Fx.impact(1.0)
		defeated.emit())
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(queue_free)
