class_name GlitchBot
extends Node3D
## A Glitch-Bot from another dimension. Hovers, flickers, shoots energy bolts,
## gets webbed, and blows up into a pile of cubes when smashed.

signal died(bot: GlitchBot)

const MODEL := preload("res://assets/enemy/enemy-flying.glb")

@export var big := false
@export var speedy := false
var hp := 3
var max_hp := 3
var dead := false
var home := Vector3.ZERO
var player: Player
var vel := Vector3.ZERO
var aggro_range := 55.0
var fire_cd := 2.0
var webbed_t := 0.0
var stun_t := 0.0
var mat: ShaderMaterial
var body: Node3D
var cocoon: MeshInstance3D
var _t := 0.0
var _orbit := 0.0
var _orbit_r := 12.0
var _glitch_t := 0.0
var _flash := 0.0
var _awake := false


func _ready() -> void:
	add_to_group("enemies")
	max_hp = 8 if big else (1 if speedy else 3)
	hp = max_hp
	body = MODEL.instantiate()
	add_child(body)
	var s := 4.2 if big else (1.5 if speedy else 2.2)
	body.scale = Vector3.ONE * s
	body.position = Vector3(0, -0.45 * s, 0)
	var tex: Texture2D = null
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_active_material(0)
		if m is BaseMaterial3D:
			tex = (m as BaseMaterial3D).albedo_texture
			break
	mat = Toon.unique_material(tex, {"character": 1.0, "palette_shift": 0.55 if big else (0.3 if speedy else 0.0)})
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cocoon = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = s * 0.55
	sm.height = s * 1.0
	sm.radial_segments = 10
	sm.rings = 5
	cocoon.mesh = sm
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = Color(1, 1, 1, 0.85)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cocoon.material_override = cm
	cocoon.visible = false
	add_child(cocoon)
	home = global_position
	_orbit = randf() * TAU
	# arrive with a glitchy pop
	body.scale = Vector3.ONE * 0.01
	var tw := create_tween()
	tw.tween_property(body, "scale", Vector3.ONE * s, 0.35).set_trans(Tween.TRANS_BACK)
	Fx.burst.call_deferred(global_position, Color(0.2, 1, 1), 8, 6.0, 0.25)
	Fx.burst.call_deferred(global_position, Color(1, 0.2, 0.7), 8, 6.0, 0.25)
	_orbit_r = randf_range(7.0, 11.0)
	fire_cd = randf_range(1.5, 3.5)
	_t = randf() * 10.0


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if not player:
			return
	var to_p := player.center() - global_position
	var dist := to_p.length()
	var sight := aggro_range * (0.6 if Game.suit == "midnight" else 1.0)
	if not _awake and dist < sight:
		_awake = true
		Fx.word("!", global_position + Vector3(0, 2.5, 0), "small", Color(1, 0.9, 0.2))
	# flicker
	_glitch_t -= delta
	if _glitch_t <= 0.0:
		_glitch_t = randf_range(0.6, 2.5)
		mat.set_shader_parameter("glitch", 1.0)
		get_tree().create_timer(0.12, false).timeout.connect(func() -> void:
			if is_instance_valid(self) and mat: mat.set_shader_parameter("glitch", 0.25 if big else 0.0))
	_flash = move_toward(_flash, 0.0, delta * 5.0)
	mat.set_shader_parameter("flash", _flash)

	if webbed_t > 0.0:
		webbed_t -= delta
		vel.y -= 18.0 * delta
		vel.x *= 0.95
		vel.z *= 0.95
		_move(delta, true)
		if webbed_t <= 0.0:
			cocoon.visible = false
			Fx.word("BZZT!", global_position + Vector3(0, 1, 0), "small", Color(0.3, 1, 1))
		return
	if stun_t > 0.0:
		stun_t -= delta
		vel *= 0.9
		_move(delta, false)
		return

	var goal: Vector3
	if _awake:
		_orbit += delta * (0.35 if not big else 0.2) * (2.2 if speedy else 1.0)
		var off := Vector3(cos(_orbit), 0, sin(_orbit)) * _orbit_r
		goal = player.center() + off + Vector3(0, 3.5 + sin(_t * 0.7) * 2.0, 0)
		if dist > aggro_range * 1.6:
			_awake = false
	else:
		goal = home + Vector3(cos(_t * 0.5) * 4.0, sin(_t * 1.3) * 1.5, sin(_t * 0.5) * 4.0)
	var want := (goal - global_position)
	var spd := 16.0 if big else (32.0 if speedy else 20.0)
	var desired := want.limit_length(spd)
	# climb over buildings in the way
	if want.length() > 3.0:
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + want.normalized() * 6.0, 1)
		if get_world_3d().direct_space_state.intersect_ray(q):
			desired.y = spd
	vel = vel.lerp(desired, 1.0 - exp(-delta * 2.0))
	_move(delta, false)
	# face the player (or the way we're going)
	var face := to_p if _awake else vel
	if Vector2(face.x, face.z).length() > 0.1:
		var yaw := atan2(face.x, face.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 6.0))
	body.rotation.z = sin(_t * 2.0) * 0.12
	# shoot
	if _awake and dist < 42.0:
		fire_cd -= delta
		if fire_cd <= 0.0:
			fire_cd = randf_range(2.2, 3.6) if not big else randf_range(1.6, 2.4)
			if speedy:
				fire_cd *= 1.8
			_fire()


func _move(delta: float, fall: bool) -> void:
	var step := vel * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step + step.normalized() * 1.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		if fall and (hit.normal as Vector3).y > 0.6:
			global_position = (hit.position as Vector3) + Vector3(0, 1.0, 0)
			vel = Vector3.ZERO
			return
		vel = vel.bounce(hit.normal) * 0.4
		return
	global_position += step


func _fire() -> void:
	var shots := 3 if big else 1
	for i in shots:
		var b := BotBolt.new()
		get_parent().add_child(b)
		var muzzle := global_position + Vector3(0, -0.2, 0) + global_transform.basis.z * 1.2
		b.global_position = muzzle
		var aim := player.center() + player.velocity * 0.35
		var dir := (aim - muzzle).normalized()
		if shots > 1:
			dir = dir.rotated(Vector3.UP, (i - 1) * 0.18)
		b.launch(dir, 22.0 if not big else 19.0, player)
	Sfx.play("bot_shoot", 0.1, -6.0)
	if global_position.distance_to(player.global_position) < 30.0:
		player.spider_sense = 1.0


func take_hit(dmg: int, dir: Vector3, big_hit: bool) -> void:
	if dead:
		return
	var d := dmg * (2 if webbed_t > 0.0 else 1)
	hp -= d
	_flash = 0.7
	_awake = true
	stun_t = 0.45
	vel = dir * (14.0 if big_hit else 8.0) + Vector3.UP * 3.0
	if big:
		vel *= 0.4
	Fx.glitch(0.25)
	Sfx.play("bot_hurt", 0.1)
	if hp <= 0:
		_die(dir)


func webbed() -> void:
	if dead:
		return
	webbed_t = 4.0 if not big else 2.0
	cocoon.visible = true
	_awake = true
	vel = Vector3.ZERO
	Game.add_score(10)


func _die(dir: Vector3) -> void:
	dead = true
	remove_from_group("enemies")
	Game.bots_smashed += 1
	Game.add_score(150 if big else 100)
	Fx.word("KA-BOOM!" if big else ["KRAK!", "BLAM!", "KZZT!", "BOOM!"][randi() % 4], global_position + Vector3(0, 1.2, 0), "big", Color(1, 0.55, 0.1))
	Fx.burst(global_position, Color(1.0, 0.85, 0.2), 18, 12.0, 0.45)
	Fx.burst(global_position, Color(0.2, 0.95, 1.0), 12, 10.0, 0.35)
	Fx.burst(global_position, Color(1.0, 0.25, 0.6), 12, 10.0, 0.3)
	Fx.ring(global_position, Color(1, 0.9, 0.3, 0.9), 6.0 if not big else 12.0)
	Fx.shake(1.0 if big else 0.6)
	Sfx.play("explode", 0.1, -2.0)
	Sfx.play("bot_die", 0.1)
	died.emit(self)
	# tumble away, then vanish
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", global_position + dir * 4.0 + Vector3.UP * 2.0, 0.3)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3).set_delay(0.05)
	tw.chain().tween_callback(queue_free)
