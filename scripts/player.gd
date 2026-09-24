class_name Player
extends CharacterBody3D
## The spider hero: run, jump, flip, web-swing, wall-climb, web-zip,
## smash combos and web shots.

signal health_changed(hp: int, max_hp: int)
signal knocked_out

enum State { GROUND, AIR, SWING, WALL, ZIP, LUNGE, SLAM }

const RUN := 12.0
const ACCEL := 80.0
const AIR_ACCEL := 26.0
const GRAV := 30.0
const JUMP := 13.5
const FLIP_JUMP := 12.0
const MAX_FALL := 60.0
const SWING_PUMP := 16.0
const MAX_SPEED := 52.0
const CLIMB := 11.0
const ZIP_SPEED := 58.0
const MAX_HP := 6
const SKY_CEIL := 125.0

var rig: CamRig
var model: HeroModel
var web: WebLine
var state := State.AIR
var hp := MAX_HP
var invuln := 0.0
var spider_sense := 0.0
var enabled := true

var _coyote := 0.0
var _jump_buffer := 0.0
var _can_flip := true
var _flip_t := 0.0
var _anchor := Vector3.ZERO
var _rope := 20.0
var _swing_t := 0.0
var _wall_n := Vector3.ZERO
var _wall_t := 0.0
var _zip_to := Vector3.ZERO
var _zip_n := Vector3.UP
var _zip_t := 0.0
var _zip_enemy: Node3D
var _lunge_target: Node3D
var _lunge_t := 0.0
var _combo_step := 0
var _combo_t := 0.0
var _punch_t := 0.0
var _land_t := 0.0
var _regen_t := 0.0
var _last_safe := Vector3.ZERO
var _facing := Vector3.FORWARD
var _visual_basis := Basis()
var _fall_peak := 0.0
var _web_cd := 0.0
var _smash_cd := 0.0
var _no_wall_t := 0.0
var _fall_top := 0.0
var _leap_said := false
var _step_d := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	model = HeroModel.new()
	model.skin = Game.suit_texture()
	add_child(model)
	model.top_level = true
	web = WebLine.new()
	add_child(web)
	_last_safe = global_position
	Game.suit_changed.connect(func(_s: String) -> void: model.set_skin(Game.suit_texture()))
	add_to_group("player")


# ------------------------------------------------------------------ helpers

func move_input() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	if not rig:
		return Vector3(v.x, 0, -v.y)
	return rig.right() * v.x + rig.forward() * v.y


func _space() -> PhysicsDirectSpaceState3D:
	return get_world_3d().direct_space_state


func _ray(from: Vector3, to: Vector3, mask := 1) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.exclude = [get_rid()]
	return _space().intersect_ray(q)


func is_swinging() -> bool:
	return state == State.SWING


func center() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)


# ------------------------------------------------------------------ main loop

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	invuln = maxf(0.0, invuln - delta)
	_combo_t -= delta
	if _combo_t <= 0.0 and _combo_step > 0:
		_combo_step = 0
	if _combo_t < -1.2:
		Game.end_combo()
	_web_cd -= delta
	_smash_cd -= delta
	_no_wall_t -= delta
	_jump_buffer -= delta
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.15
	_regen(delta)

	match state:
		State.GROUND:
			_ground(delta)
		State.AIR:
			_air(delta)
		State.SWING:
			_swing(delta)
		State.WALL:
			_wall(delta)
		State.ZIP:
			_zip(delta)
		State.LUNGE:
			_lunge(delta)
		State.SLAM:
			_slam(delta)

	if Input.is_action_just_pressed("smash") and _smash_cd <= 0.0 and state != State.LUNGE and state != State.SLAM:
		_smash()
	if Input.is_action_just_pressed("web") and _web_cd <= 0.0:
		_web_shot()
	if Input.is_action_just_pressed("zip") and state != State.ZIP:
		_start_zip()

	_check_hazards()
	_update_visual(delta)


func _regen(delta: float) -> void:
	if hp < MAX_HP:
		_regen_t += delta
		if _regen_t > (3.5 if Game.suit == "classic" else 5.0):
			_regen_t = 2.5 if Game.suit == "classic" else 3.5
			hp += 1
			health_changed.emit(hp, MAX_HP)


# ------------------------------------------------------------------ ground

func _ground(delta: float) -> void:
	var inp := move_input()
	var target := inp * RUN
	var hv := Vector3(velocity.x, 0, velocity.z)
	var accel := ACCEL if inp.length() > 0.1 else ACCEL * 0.8
	# keep swing momentum for a moment after landing, bleed it off
	if hv.length() > RUN + 0.5:
		hv = hv.move_toward(target, accel * 0.35 * delta)
	else:
		hv = hv.move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = -2.0
	move_and_slide()
	_land_t -= delta
	if not is_on_floor():
		_coyote = 0.12
		_set_state(State.AIR)
		return
	_last_safe = global_position
	_can_flip = true
	if _jump_buffer > 0.0:
		_do_jump()
		return
	if Input.is_action_just_pressed("swing"):
		_do_jump()
		return
	# run into a tall wall: start climbing
	if is_on_wall() and inp.length() > 0.3 and _no_wall_t <= 0.0:
		var n := get_wall_normal()
		if absf(n.y) < 0.3 and inp.dot(-n) > 0.5:
			var hit := _ray(center() + Vector3(0, 1.2, 0), center() + Vector3(0, 1.2, 0) - n * 1.5)
			if hit:
				_enter_wall(n)
				return
	var spd := hv.length()
	_step_d += spd * delta
	if _step_d > 2.4:
		_step_d = 0.0
		Sfx.play("step", 0.15, -10.0)
	if _land_t > 0.0:
		model.play("idle")
	elif spd > 0.8:
		model.play("run", 0.1, clampf(spd / 10.0, 0.7, 1.6))
	else:
		model.play("idle")


func _do_jump() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	velocity.y = JUMP
	_set_state(State.AIR)
	model.restart("jump")
	Sfx.play("jump", 0.1)


# ------------------------------------------------------------------ air

func _air(delta: float) -> void:
	_coyote -= delta
	var inp := move_input()
	var hv := Vector3(velocity.x, 0, velocity.z)
	var add := inp * AIR_ACCEL * delta
	# add control but never slow a fast hero down to run speed
	var nh := hv + add
	if nh.length() > maxf(hv.length(), RUN):
		nh = nh.normalized() * maxf(hv.length(), RUN)
	hv = nh
	hv *= 1.0 - 0.15 * delta
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = maxf(velocity.y - GRAV * delta, -MAX_FALL)
	_fall_peak = minf(_fall_peak, velocity.y)
	if velocity.y > 0.0:
		_fall_top = global_position.y
		_leap_said = false
	elif not _leap_said and _fall_top - global_position.y > 45.0 and velocity.y < -20.0:
		_leap_said = true
		Fx.word("LEAP OF FAITH!", center() + Vector3(0, 2.5, 0), "big", Color(0.3, 0.95, 1.0))
		Sfx.play("whoosh", 0.0)
	move_and_slide()
	if _flip_t > 0.0:
		_flip_t -= delta

	if is_on_floor():
		_land()
		return
	if _jump_buffer > 0.0:
		if _coyote > 0.0:
			_do_jump()
			return
		if _can_flip:
			_jump_buffer = 0.0
			_can_flip = false
			velocity.y = maxf(velocity.y, FLIP_JUMP)
			_flip_t = 0.45
			Sfx.play("flip", 0.1)
	if Input.is_action_pressed("swing") and _swing_t <= -0.12:
		_start_swing()
		return
	_swing_t -= delta
	# touch a wall mid-air: stick to it
	if is_on_wall() and _no_wall_t <= 0.0:
		var n := get_wall_normal()
		if absf(n.y) < 0.3 and velocity.dot(-n) > -2.0:
			_enter_wall(n)
			return
	model.tuck = move_toward(model.tuck, 0.0, delta * 4.0)
	var falling_fast := velocity.y < -16.0
	model.spread = move_toward(model.spread, 1.0 if falling_fast else 0.0, delta * 3.0)
	model.play("jump", 0.15)


func _land() -> void:
	var hard := _fall_peak < -26.0
	_fall_top = global_position.y
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() is AnimatableBody3D and col.get_normal().y > 0.6:
			Sfx.play("honk", 0.08)
			Fx.word("HONK!", global_position + Vector3(0, 1.5, 0), "small", Color(1, 0.9, 0.2))
			break
	_fall_peak = 0.0
	_set_state(State.GROUND)
	model.spread = 0.0
	model.tuck = 0.0
	if hard:
		_land_t = 0.35
		model.crouch = 1.0
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(model, "crouch", 0.0, 0.2)
		Fx.ring(global_position + Vector3(0, 0.3, 0), Color(1, 1, 1, 0.9), 5.0)
		Fx.burst(global_position + Vector3(0, 0.3, 0), Color(0.85, 0.8, 0.95), 14, 7.0, 0.3)
		Fx.shake(0.6)
		Fx.word("THOOM!", global_position + Vector3(0, 0.5, 0), "small", Color(1, 1, 1))
		Sfx.play("land_hard", 0.05)
		velocity.x *= 0.3
		velocity.z *= 0.3
	else:
		Sfx.play("land", 0.1)


# ------------------------------------------------------------------ swing

func find_anchor() -> Dictionary:
	var pos := center()
	var fwd := rig.forward() if rig else Vector3.FORWARD
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() > 6.0:
		fwd = (fwd * 0.6 + hv.normalized() * 0.4).normalized()
	var best := {}
	var best_score := -INF
	for side in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for elev in [0.95, 1.2, 1.4]:
			var dir := fwd.rotated(Vector3.UP, side * 0.7)
			dir = (dir * cos(elev) + Vector3.UP * sin(elev)).normalized()
			var hit := _ray(pos, pos + dir * 75.0)
			if hit.is_empty():
				continue
			var p: Vector3 = hit.position
			var h := p.y - pos.y
			if h < 6.0:
				continue
			var d := p.distance_to(pos)
			var flat := Vector3(p.x - pos.x, 0, p.z - pos.z)
			var ahead := flat.dot(fwd)
			var score := minf(h, 30.0) + dir.dot(fwd) * 10.0 - absf(d - 26.0) * 0.35 - absf(side) * 1.0
			if ahead < 6.0:
				score -= (6.0 - ahead) * 4.0
			# a wall that faces us head-on means we'd swing straight into it
			var n: Vector3 = hit.normal
			score -= maxf(0.0, n.dot(-fwd)) * 9.0 * (1.0 if absf(side) < 0.3 else 0.4)
			if score > best_score:
				best_score = score
				best = {"pos": p + (hit.normal as Vector3) * 0.3, "sky": false}
	if best.is_empty():
		# no building close enough: webs still stick to the comic sky,
		# but only up to about rooftop height (no swinging to the moon!)
		var ceil_y := SKY_CEIL
		var city := get_tree().get_first_node_in_group("city")
		if city and "tower_top" in city:
			var tt: Vector3 = city.tower_top
			if Vector2(tt.x - pos.x, tt.z - pos.z).length() < 70.0:
				ceil_y = maxf(ceil_y, tt.y + 30.0)
		var p := pos + fwd * 20.0 + Vector3.UP * 26.0
		p.y = minf(p.y, ceil_y)
		if p.y < pos.y + 6.0:
			return {}
		best = {"pos": p, "sky": true}
	return best


func _start_swing() -> void:
	var a := find_anchor()
	if a.is_empty():
		_swing_t = 0.3
		return
	_anchor = a.pos
	var d := center().distance_to(_anchor)
	_rope = clampf(d * 0.92, 9.0, 60.0)
	_swing_t = 0.0
	_set_state(State.SWING)
	web.shoot(model.hand_position(true), _anchor)
	Fx.word("THWIP!", model.hand_position(true).lerp(_anchor, 0.25), "web", Color(1, 1, 1))
	Sfx.play("thwip", 0.12)
	# a little tug toward the anchor so the swing starts with energy
	var to := (_anchor - center()).normalized()
	velocity += to * 3.0
	model.restart("jump")


func _swing(delta: float) -> void:
	_swing_t += delta
	var inp := move_input()
	velocity.y -= GRAV * delta
	var rope := center() - _anchor
	var rn := rope.normalized()
	var tang := inp - rn * inp.dot(rn)
	var pump := SWING_PUMP * (1.3 if Game.suit == "ghost" else 1.0)
	velocity += tang * pump * delta
	# natural forward pump: speed up at the bottom of the arc
	var below := clampf(-rn.y, 0.0, 1.0)
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() > 1.0:
		velocity += hv.normalized() * 7.0 * below * delta
	# reel the rope in a bit at the start for a snappy swing
	if _swing_t < 0.5:
		_rope = maxf(_rope - 8.0 * delta, 9.0)
	velocity = velocity.limit_length(MAX_SPEED * (1.15 if Game.suit == "ghost" else 1.0))
	move_and_slide()
	# rope constraint
	var d := center() - _anchor
	if d.length() > _rope:
		var n := d.normalized()
		global_position = _anchor + n * _rope - Vector3(0, 1.0, 0)
		var radial := velocity.dot(n)
		if radial > 0.0:
			velocity -= n * radial
	web.update_ends(model.hand_position(true), _anchor)
	model.aim_right = (_anchor - model.hand_position(true)).normalized()
	model.aim_right_w = 1.0
	model.tuck = move_toward(model.tuck, 0.7, delta * 4.0)
	model.spread = 0.0
	model.play("jump", 0.1)

	var released := not Input.is_action_pressed("swing")
	var jumped := _jump_buffer > 0.0
	if released or jumped:
		_release_swing(jumped)
		return
	if center().y > _anchor.y - 1.5 or _swing_t > 5.0:
		_release_swing(false)
		return
	if is_on_floor():
		web.release()
		model.aim_right_w = 0.0
		_land()
		return
	if is_on_wall():
		var n := get_wall_normal()
		if absf(n.y) < 0.3:
			web.release()
			model.aim_right_w = 0.0
			_enter_wall(n)


func _release_swing(jumped: bool) -> void:
	web.release()
	model.aim_right_w = 0.0
	var hv := Vector3(velocity.x, 0, velocity.z)
	var fwd := hv.normalized() if hv.length() > 1.0 else (rig.forward() if rig else Vector3.FORWARD)
	velocity += fwd * 4.0 + Vector3.UP * (9.0 if jumped else 6.0)
	if jumped:
		_jump_buffer = 0.0
		_flip_t = 0.45
		Sfx.play("flip", 0.1)
	_swing_t = 0.0
	_can_flip = true
	_set_state(State.AIR)


# ------------------------------------------------------------------ wall

func _enter_wall(n: Vector3) -> void:
	_wall_n = Vector3(n.x, 0, n.z).normalized()
	_wall_t = 0.0
	_set_state(State.WALL)
	web.release()
	velocity = Vector3.ZERO
	_can_flip = true
	Sfx.play("stick", 0.1)


func _wall(delta: float) -> void:
	_wall_t += delta
	var inp := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var side := _wall_n.cross(Vector3.UP).normalized()
	# forward on the stick climbs; sideways moves along the wall
	var cam_side := rig.right() if rig else side
	var lat := inp.x * signf(cam_side.dot(side) if absf(cam_side.dot(side)) > 0.1 else 1.0)
	var climb := inp.y
	if inp.length() < 0.1:
		climb = 0.0
	velocity = Vector3.UP * climb * CLIMB + side * lat * 7.0 - _wall_n * 3.0
	move_and_slide()
	if climb > 0.3 and is_on_ceiling():
		# a ledge sticks out above us: hop out and around it
		velocity = _wall_n * 7.0 + Vector3.UP * 11.0
		_no_wall_t = 0.3
		_set_state(State.AIR)
		model.restart("jump")
		return
	# still on the wall?
	var chest := center() + Vector3(0, 0.2, 0)
	var hit := _ray(chest + _wall_n * 0.3, chest - _wall_n * 1.4)
	if hit.is_empty():
		# climbed over the top: vault onto the roof
		velocity = Vector3.UP * 9.0 - _wall_n * 7.0
		_set_state(State.AIR)
		_no_wall_t = 0.4
		model.restart("jump")
		Sfx.play("jump", 0.1)
		return
	_wall_n = Vector3((hit.normal as Vector3).x, 0, (hit.normal as Vector3).z).normalized()
	if _jump_buffer > 0.0:
		_jump_buffer = 0.0
		velocity = _wall_n * 12.0 + Vector3.UP * 10.0
		_no_wall_t = 0.35
		_flip_t = 0.45
		_set_state(State.AIR)
		Sfx.play("flip", 0.1)
		return
	if Input.is_action_just_pressed("swing"):
		velocity = _wall_n * 9.0 + Vector3.UP * 8.0
		_no_wall_t = 0.3
		_set_state(State.AIR)
		_swing_t = -1.0
		_start_swing()
		return
	if inp.y < -0.5 and _wall_t > 0.3:
		# pull down and away to let go
		velocity = _wall_n * 5.0
		_no_wall_t = 0.5
		_set_state(State.AIR)
		return
	if is_on_floor() and climb <= 0.0:
		_set_state(State.GROUND)
		return
	if absf(climb) > 0.1 or absf(lat) > 0.1:
		model.play("run", 0.1, 1.3)
	else:
		model.play("idle", 0.2)


# ------------------------------------------------------------------ zip

func _start_zip() -> void:
	if not rig:
		return
	var cam := rig.cam
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	# enemies near the aim line get a web-strike
	var enemy := _aim_enemy(dir, 85.0, 0.93)
	if enemy:
		_zip_enemy = enemy
		_zip_to = enemy.global_position
	else:
		var hit := _ray(from, from + dir * 95.0)
		if hit.is_empty() or (hit.position as Vector3).distance_to(center()) < 4.0:
			Fx.word("?", center() + Vector3(0, 1.5, 0), "small", Color(1, 1, 1))
			return
		_zip_enemy = null
		_zip_to = hit.position
		_zip_n = hit.normal
	_zip_t = 0.0
	_set_state(State.ZIP)
	web.shoot(model.hand_position(true), _zip_to)
	Fx.word("THWIP!", model.hand_position(true).lerp(_zip_to, 0.2), "web", Color(1, 1, 1))
	Sfx.play("zip", 0.08)
	model.restart("jump")


func _zip(delta: float) -> void:
	_zip_t += delta
	if _zip_enemy and is_instance_valid(_zip_enemy):
		_zip_to = _zip_enemy.global_position
	var to := _zip_to - center()
	var dist := to.length()
	velocity = to.normalized() * ZIP_SPEED
	move_and_slide()
	web.update_ends(model.hand_position(true), _zip_to)
	model.aim_right = to.normalized()
	model.aim_right_w = 1.0
	model.aim_left = to.normalized()
	model.aim_left_w = 0.8
	model.play("jump", 0.1)
	if _zip_enemy and is_instance_valid(_zip_enemy) and dist < 2.4:
		var target := _zip_enemy
		_end_zip()
		_hit_enemy(target, 3, true)
		velocity = -to.normalized() * 4.0 + Vector3.UP * 9.0
		return
	if dist < 1.6 or _zip_t > 1.6 or (get_slide_collision_count() > 0 and _zip_t > 0.1):
		_end_zip()
		if _zip_n.y > 0.6:
			velocity = Vector3.UP * 4.0
		elif absf(_zip_n.y) < 0.3 and not _zip_enemy:
			_enter_wall(_zip_n)
			return
		else:
			velocity = Vector3.UP * 8.0
		_set_state(State.AIR)


func _end_zip() -> void:
	web.release()
	model.aim_right_w = 0.0
	model.aim_left_w = 0.0
	_zip_enemy = null
	_set_state(State.AIR)


# ------------------------------------------------------------------ combat

func _aim_enemy(dir: Vector3, max_dist: float, min_dot: float) -> Node3D:
	var best: Node3D = null
	var best_score := -INF
	var from := rig.cam.global_position if rig else center()
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		if not en.visible or ("dead" in en and en.dead):
			continue
		var to := en.global_position - from
		var d := to.length()
		if d > max_dist + 8.0:
			continue
		var dt := to.normalized().dot(dir)
		if dt < min_dot:
			continue
		var s := dt * 10.0 - d * 0.1
		if s > best_score:
			best_score = s
			best = en
	return best


func _nearest_enemy(max_dist: float) -> Node3D:
	var best: Node3D = null
	var bd := max_dist
	var fwd := rig.forward() if rig else _facing
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		if not en.visible or ("dead" in en and en.dead):
			continue
		var to := en.global_position - center()
		var d := to.length()
		# prefer enemies in front
		var eff := d - to.normalized().dot(fwd) * 3.0
		if d < max_dist and eff < bd:
			bd = eff
			best = en
	return best


func _smash() -> void:
	_smash_cd = 0.18
	var reach := 14.0 if state == State.GROUND else 18.0
	var t := _nearest_enemy(reach)
	_combo_step = (_combo_step % 3) + 1
	_combo_t = 0.9
	model.punch_side = 1 if _combo_step != 2 else -1
	if t:
		_lunge_target = t
		_lunge_t = 0.0
		web.release()
		model.aim_right_w = 0.0
		_set_state(State.LUNGE)
	elif state == State.AIR and _height_above_ground() > 7.0:
		_start_slam()
	else:
		_punch_anim()
		Sfx.play("whoosh", 0.15)
		var hv := _facing * 4.0
		velocity.x += hv.x
		velocity.z += hv.z


func _height_above_ground() -> float:
	var hit := _ray(global_position, global_position + Vector3.DOWN * 200.0)
	if hit.is_empty():
		return 200.0
	return global_position.y - (hit.position as Vector3).y


func _start_slam() -> void:
	_set_state(State.SLAM)
	web.release()
	model.aim_right_w = 0.0
	velocity = Vector3(velocity.x * 0.3, -48.0, velocity.z * 0.3)
	Fx.word("SPIDER SLAM!", center() + Vector3(0, 2, 0), "hit", Color(1, 0.35, 0.55))
	Sfx.play("whoosh", 0.05)


func _slam(_delta: float) -> void:
	velocity.y = -52.0
	move_and_slide()
	model.punch = 1.0
	model.punch_side = 1
	model.aim_right = Vector3.DOWN
	model.aim_right_w = 1.0
	model.aim_left = Vector3.DOWN
	model.aim_left_w = 1.0
	if is_on_floor() or get_slide_collision_count() > 0:
		model.aim_right_w = 0.0
		model.aim_left_w = 0.0
		model.punch = 0.0
		var p := global_position
		Fx.word("KRA-KOOM!!", p + Vector3(0, 1.5, 0), "big", Color(1, 0.9, 0.2))
		Fx.ring(p + Vector3(0, 0.4, 0), Color(1, 1, 1, 0.95), 14.0)
		Fx.ring(p + Vector3(0, 0.4, 0), Color(1, 0.3, 0.6, 0.9), 9.0)
		Fx.burst(p, Color(0.9, 0.85, 1.0), 26, 12.0, 0.4)
		Fx.shake(1.3)
		Fx.impact(1.0)
		Fx.hitstop(0.08)
		Sfx.play("land_hard")
		Sfx.play("punch_big", 0.05)
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Node3D
			var off := en.global_position - p
			var flat := Vector2(off.x, off.z).length()
			if flat < 18.0 and off.y < 26.0 and en.has_method("take_hit"):
				en.take_hit(2, (en.global_position - p).normalized() + Vector3.UP, true)
				Game.add_combo()
				Game.add_score(40)
		_fall_peak = 0.0
		_land_t = 0.4
		model.crouch = 1.0
		var tw := create_tween()
		tw.tween_interval(0.35)
		tw.tween_property(model, "crouch", 0.0, 0.2)
		velocity = Vector3.ZERO
		_set_state(State.GROUND if is_on_floor() else State.AIR)


func _punch_anim() -> void:
	var tw := create_tween()
	if _combo_step == 3:
		tw.tween_property(model, "kick", 1.0, 0.06)
		tw.tween_interval(0.12)
		tw.tween_property(model, "kick", 0.0, 0.15)
	else:
		tw.tween_property(model, "punch", 1.0, 0.05)
		tw.tween_interval(0.1)
		tw.tween_property(model, "punch", 0.0, 0.12)


func _lunge(delta: float) -> void:
	_lunge_t += delta
	if not is_instance_valid(_lunge_target) or ("dead" in _lunge_target and _lunge_target.dead):
		_set_state(State.AIR)
		return
	var to := _lunge_target.global_position - center()
	var d := to.length()
	velocity = to.normalized() * 36.0
	_facing = Vector3(to.x, 0, to.z).normalized() if Vector2(to.x, to.z).length() > 0.1 else _facing
	move_and_slide()
	if d < 2.3:
		_punch_anim()
		_hit_enemy(_lunge_target, 2 if _combo_step == 3 else 1, _combo_step == 3)
		# bounce so we can keep juggling flying bots
		velocity = -to.normalized() * 3.0 + Vector3.UP * (8.0 if not is_on_floor() else 4.0)
		_set_state(State.AIR if not is_on_floor() else State.GROUND)
		_can_flip = true
		return
	if _lunge_t > 0.6:
		_set_state(State.AIR)


const QUIPS := ["Too easy!", "Beep boop, you're OUT!", "Web-tastic!", "Is that all you got?", "Swing and a HIT!", "Bots, meet webs!", "Nailed it!", "Back to your dimension!"]
var _quip_n := 0


func _hit_enemy(e: Node3D, dmg: int, big: bool) -> void:
	var dir := (e.global_position - center()).normalized()
	if Game.suit == "noir":
		dmg += 1
	if e.has_method("take_hit"):
		e.take_hit(dmg, dir, big)
	var words := ["POW!", "BAM!", "WHAM!", "BOOF!", "KRAK!", "THWACK!", "SMASH!", "BONK!"]
	var colors := [Color(1, 0.92, 0.15), Color(1, 0.3, 0.55), Color(0.2, 0.95, 1.0), Color(1, 0.55, 0.1)]
	Fx.word(words[randi() % words.size()] if not big else "SMASH!!", e.global_position + Vector3(0, 0.6, 0), "big" if big else "hit", colors[randi() % colors.size()])
	Fx.burst(e.global_position, Color(1, 0.95, 0.4), 10, 8.0, 0.25)
	Fx.shake(0.9 if big else 0.5)
	Fx.hitstop(0.09 if big else 0.05)
	if big:
		Fx.impact(1.0)
		Fx.ring(e.global_position, Color(1, 1, 1, 0.9), 4.0, -dir)
	Sfx.play("punch_big" if big else "punch", 0.12)
	Game.add_combo()
	Game.add_score(25 if not big else 60)
	_combo_t = 0.9
	if "dead" in e and e.dead:
		_quip_n += 1
		if _quip_n % 4 == 1:
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and not hud.captions_busy():
				hud.narrate([QUIPS[randi() % QUIPS.size()]], 1.8)
	if Game.combo > 0 and Game.combo % 10 == 0:
		# every 10 hits: a dramatic slow-motion beat
		Fx.slowmo(0.9)
		Fx.word("x%d!!" % Game.combo, center() + Vector3(0, 3, 0), "big", Color(0.3, 0.95, 1.0))


func _web_shot() -> void:
	_web_cd = 0.35
	var dir := -rig.cam.global_transform.basis.z if rig else _facing
	var t := _aim_enemy(dir, 60.0, 0.9)
	if not t:
		t = _nearest_enemy(30.0)
	var from := model.hand_position(false)
	var ball := WebBall.new()
	get_parent().add_child(ball)
	ball.global_position = from
	ball.launch(t, dir)
	Fx.word("THWIP!", from + dir * 1.5, "web", Color(1, 1, 1))
	Sfx.play("thwip", 0.15)
	model.aim_left = (t.global_position - from).normalized() if t else dir
	model.aim_left_w = 1.0
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(model, "aim_left_w", 0.0, 0.15)


# ------------------------------------------------------------------ damage

func take_hit(dmg: int, from: Vector3) -> void:
	if invuln > 0.0 or not enabled:
		return
	hp -= dmg
	invuln = 1.0
	_regen_t = 0.0
	health_changed.emit(hp, MAX_HP)
	var away := (global_position - from)
	away.y = 0
	velocity = away.normalized() * 9.0 + Vector3.UP * 6.0
	if state == State.SWING or state == State.WALL or state == State.ZIP:
		web.release()
		model.aim_right_w = 0.0
		_set_state(State.AIR)
	Fx.hurt(1.0)
	Fx.shake(0.7)
	Fx.word(["OOF!", "OW!", "YIKES!"][randi() % 3], center() + Vector3(0, 1, 0), "small", Color(1, 0.3, 0.4))
	Sfx.play("hurt", 0.1)
	var tw := create_tween()
	for i in 4:
		tw.tween_callback(func() -> void: model.material.set_shader_parameter("flash", 0.8))
		tw.tween_interval(0.06)
		tw.tween_callback(func() -> void: model.material.set_shader_parameter("flash", 0.0))
		tw.tween_interval(0.08)
	if hp <= 0:
		_knock_out()


func _knock_out() -> void:
	knocked_out.emit()
	Fx.word("KO!", center() + Vector3(0, 1.2, 0), "big", Color(1, 0.3, 0.4))
	respawn()


func respawn(to := Vector3.INF) -> void:
	var p := to
	if p == Vector3.INF:
		p = _safe_spot()
	global_position = p
	velocity = Vector3.ZERO
	hp = MAX_HP
	invuln = 2.0
	health_changed.emit(hp, MAX_HP)
	web.release()
	model.aim_right_w = 0.0
	model.aim_left_w = 0.0
	_set_state(State.AIR)


func _safe_spot() -> Vector3:
	var city := get_tree().get_first_node_in_group("city")
	if city and "roof_spots" in city:
		var best := _last_safe
		var bd := INF
		for s in city.roof_spots:
			var d := (s as Vector3).distance_to(global_position)
			if d < bd:
				bd = d
				best = s
		return best + Vector3(0, 1.0, 0)
	return _last_safe + Vector3(0, 2, 0)


func _check_hazards() -> void:
	if global_position.y < -1.8:
		Fx.word("SPLOOSH!", global_position + Vector3(0, 1.5, 0), "big", Color(0.3, 0.9, 1.0))
		Fx.burst(global_position, Color(0.5, 0.8, 1.0), 20, 10.0, 0.3)
		Sfx.play("splash", 0.1)
		respawn()


func _set_state(s: State) -> void:
	state = s
	floor_snap_length = 0.4 if s == State.GROUND else 0.0


# ------------------------------------------------------------------ visuals

func _update_visual(delta: float) -> void:
	model.global_position = global_position
	var hv := Vector3(velocity.x, 0, velocity.z)
	var up := Vector3.UP
	var fwd := _facing
	match state:
		State.GROUND, State.AIR, State.LUNGE, State.SLAM:
			var inp := move_input()
			if hv.length() > 1.0:
				fwd = hv.normalized()
			elif inp.length() > 0.2:
				fwd = inp.normalized()
			if state == State.AIR and velocity.y < -16.0:
				# skydive: tip forward
				var tip := clampf((-velocity.y - 16.0) / 20.0, 0.0, 0.9)
				up = (Vector3.UP * (1.0 - tip) - fwd * tip).normalized()
		State.SWING:
			up = (_anchor - center()).normalized()
			var t := velocity - up * velocity.dot(up)
			if t.length() > 0.5:
				fwd = t.normalized()
		State.WALL:
			up = _wall_n
			fwd = Vector3.UP
		State.ZIP:
			var to := (_zip_to - center()).normalized()
			fwd = to
			up = Vector3.UP if absf(to.y) < 0.9 else -_facing
	if state != State.WALL and state != State.ZIP and state != State.SWING:
		_facing = Vector3(fwd.x, 0, fwd.z).normalized() if Vector2(fwd.x, fwd.z).length() > 0.01 else _facing
	# build a basis: -Z = fwd, Y = up
	var z := -fwd
	z = (z - up * z.dot(up))
	if z.length() < 0.01:
		z = -_facing
	z = z.normalized()
	var x := up.cross(z).normalized()
	var want := Basis(x, up, z).orthonormalized()
	var k := 1.0 - exp(-delta * 16.0)
	_visual_basis = _visual_basis.slerp(want, k).orthonormalized()
	var b := _visual_basis
	if _flip_t > 0.0:
		var a := (1.0 - _flip_t / 0.45) * TAU
		b = b * Basis(Vector3.RIGHT, -a)
		model.tuck = 1.0
	var origin := global_position
	if _flip_t > 0.0:
		origin = global_position + Vector3.UP * 0.9 - b.y * 0.9
	model.global_transform = Transform3D(b, origin)
	# invulnerable blink
	model.visible = invuln <= 0.0 or fmod(invuln, 0.16) > 0.05 or hp == MAX_HP
	spider_sense = move_toward(spider_sense, 0.0, delta * 2.0)
