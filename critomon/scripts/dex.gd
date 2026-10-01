class_name Dex
## Every Crito Mon, every move, the type chart and the battle maths.
## A Crito Mon in your party is a Dictionary:
##   {"sp": "emberpup", "lv": 5, "xp": 100, "hp": 19, "moves": ["scratch", "growl"]}

const TYPES := {
	"normal": {"name": "NORMAL", "color": Color(0.72, 0.7, 0.62)},
	"fire": {"name": "FIRE", "color": Color(1.0, 0.45, 0.2)},
	"water": {"name": "WATER", "color": Color(0.3, 0.6, 1.0)},
	"grass": {"name": "GRASS", "color": Color(0.35, 0.8, 0.35)},
	"electric": {"name": "ZAP", "color": Color(1.0, 0.82, 0.15)},
	"rock": {"name": "ROCK", "color": Color(0.7, 0.6, 0.4)},
	"bug": {"name": "BUG", "color": Color(0.62, 0.78, 0.15)},
	"flying": {"name": "FLYING", "color": Color(0.6, 0.62, 1.0)},
}

# attacker type -> {defender type: multiplier}
const CHART := {
	"normal": {"rock": 0.5},
	"fire": {"grass": 2.0, "bug": 2.0, "fire": 0.5, "water": 0.5, "rock": 0.5},
	"water": {"fire": 2.0, "rock": 2.0, "water": 0.5, "grass": 0.5},
	"grass": {"water": 2.0, "rock": 2.0, "fire": 0.5, "grass": 0.5, "bug": 0.5, "flying": 0.5},
	"electric": {"water": 2.0, "flying": 2.0, "grass": 0.5, "electric": 0.5, "rock": 0.5},
	"rock": {"fire": 2.0, "flying": 2.0, "bug": 2.0},
	"bug": {"grass": 2.0, "fire": 0.5, "flying": 0.5},
	"flying": {"grass": 2.0, "bug": 2.0, "electric": 0.5, "rock": 0.5},
}

# fx: which effect battle.gd plays. effect: "atk-1" lowers the target's
# attack, "def+1" raises your own defence, and so on.
const MOVES := {
	"tackle": {"name": "TACKLE", "type": "normal", "power": 40, "acc": 100, "fx": "hit"},
	"scratch": {"name": "SCRATCH", "type": "normal", "power": 40, "acc": 100, "fx": "slash"},
	"quick_attack": {"name": "QUICK ATTACK", "type": "normal", "power": 40, "acc": 100, "fx": "hit", "first": true},
	"headbutt": {"name": "HEADBUTT", "type": "normal", "power": 60, "acc": 100, "fx": "hit"},
	"growl": {"name": "GROWL", "type": "normal", "power": 0, "acc": 100, "fx": "shout", "effect": "atk-1"},
	"tail_whip": {"name": "TAIL WHIP", "type": "normal", "power": 0, "acc": 100, "fx": "shout", "effect": "def-1"},
	"ember": {"name": "EMBER", "type": "fire", "power": 40, "acc": 100, "fx": "shoot"},
	"flame_wheel": {"name": "FLAME WHEEL", "type": "fire", "power": 60, "acc": 100, "fx": "hit"},
	"bubble": {"name": "BUBBLE", "type": "water", "power": 40, "acc": 100, "fx": "shoot"},
	"water_gun": {"name": "WATER GUN", "type": "water", "power": 60, "acc": 100, "fx": "shoot"},
	"vine_whip": {"name": "VINE WHIP", "type": "grass", "power": 45, "acc": 100, "fx": "slash"},
	"razor_leaf": {"name": "RAZOR LEAF", "type": "grass", "power": 60, "acc": 95, "fx": "shoot"},
	"thunder_shock": {"name": "THUNDER SHOCK", "type": "electric", "power": 40, "acc": 100, "fx": "zap"},
	"spark": {"name": "SPARK", "type": "electric", "power": 60, "acc": 100, "fx": "hit"},
	"rock_throw": {"name": "ROCK THROW", "type": "rock", "power": 50, "acc": 90, "fx": "shoot"},
	"defense_curl": {"name": "DEFENSE CURL", "type": "normal", "power": 0, "acc": 100, "fx": "buff", "effect": "def+1"},
	"bug_bite": {"name": "BUG BITE", "type": "bug", "power": 50, "acc": 100, "fx": "hit"},
	"string_shot": {"name": "STRING SHOT", "type": "bug", "power": 0, "acc": 95, "fx": "shoot", "effect": "spd-1"},
	"peck": {"name": "PECK", "type": "flying", "power": 35, "acc": 100, "fx": "hit"},
	"gust": {"name": "GUST", "type": "flying", "power": 45, "acc": 100, "fx": "shoot"},
	"wing_attack": {"name": "WING ATTACK", "type": "flying", "power": 60, "acc": 100, "fx": "hit"},
}

# look: which body parts critter_model.gd builds and their colours.
const SPECIES := {
	"emberpup": {
		"name": "EMBERPUP", "type": "fire", "hp": 45, "atk": 56, "def": 42, "spd": 62, "xp": 64, "catch": 45,
		"about": "A fire puppy. Its tail flame gets bigger when it is happy!",
		"learn": {1: ["scratch", "growl"], 5: ["ember"], 9: ["quick_attack"], 13: ["flame_wheel"]},
		"cry": 1.25,
	},
	"bubbloo": {
		"name": "BUBBLOO", "type": "water", "hp": 50, "atk": 50, "def": 50, "spd": 46, "xp": 64, "catch": 45,
		"about": "A water buddy with frilly pink gills. It loves blowing bubbles.",
		"learn": {1: ["tackle", "tail_whip"], 5: ["bubble"], 9: ["headbutt"], 13: ["water_gun"]},
		"cry": 0.9,
	},
	"sproutle": {
		"name": "SPROUTLE", "type": "grass", "hp": 46, "atk": 52, "def": 50, "spd": 56, "xp": 64, "catch": 45,
		"about": "A grass lizard. The sprout on its head grows in the sun.",
		"learn": {1: ["tackle", "growl"], 5: ["vine_whip"], 9: ["quick_attack"], 13: ["razor_leaf"]},
		"cry": 1.05,
	},
	"zappit": {
		"name": "ZAPPIT", "type": "electric", "hp": 38, "atk": 50, "def": 36, "spd": 78, "xp": 56, "catch": 190,
		"about": "A zappy bunny. Its cheeks crackle when it gets excited.",
		"learn": {1: ["quick_attack", "tail_whip"], 4: ["thunder_shock"], 10: ["spark"]},
		"cry": 1.6,
	},
	"fluffle": {
		"name": "FLUFFLE", "type": "flying", "hp": 44, "atk": 44, "def": 40, "spd": 58, "xp": 52, "catch": 200,
		"about": "A puffy bird that floats on the wind like a cloud.",
		"learn": {1: ["tackle", "growl"], 3: ["peck"], 7: ["gust"], 12: ["wing_attack"]},
		"cry": 1.45,
	},
	"pebblit": {
		"name": "PEBBLIT", "type": "rock", "hp": 46, "atk": 58, "def": 72, "spd": 24, "xp": 60, "catch": 170,
		"about": "A tough little rock. It naps in the sun on the side of the road.",
		"learn": {1: ["tackle", "defense_curl"], 7: ["rock_throw"], 11: ["headbutt"]},
		"cry": 0.65,
	},
	"buzzlet": {
		"name": "BUZZLET", "type": "bug", "hp": 40, "atk": 46, "def": 40, "spd": 50, "xp": 50, "catch": 220,
		"about": "A buzzy bug. It hides in tall grass and loves flowers.",
		"learn": {1: ["tackle", "string_shot"], 4: ["bug_bite"], 10: ["quick_attack"]},
		"cry": 1.9,
	},
}

const STARTERS := ["emberpup", "bubbloo", "sproutle"]
const MAX_LEVEL := 50


static func species(mon: Dictionary) -> Dictionary:
	return SPECIES[mon.sp]


static func mon_name(mon: Dictionary) -> String:
	return SPECIES[mon.sp].name


static func type_of(mon: Dictionary) -> String:
	return SPECIES[mon.sp].type


static func stat(base: int, lv: int) -> int:
	return int(base * 2 * lv / 100.0) + 5


static func max_hp(mon: Dictionary) -> int:
	var s: Dictionary = SPECIES[mon.sp]
	return int(s.hp * 2 * mon.lv / 100.0) + mon.lv + 10


static func stats(mon: Dictionary) -> Dictionary:
	var s: Dictionary = SPECIES[mon.sp]
	return {"hp": max_hp(mon), "atk": stat(s.atk, mon.lv), "def": stat(s.def, mon.lv), "spd": stat(s.spd, mon.lv)}


## Total experience needed to reach a level (a bit quicker than the real games).
static func xp_for(lv: int) -> int:
	return int(lv * lv * lv * 0.8)


## A new Crito Mon with the best moves it knows at that level.
static func make(sp: String, lv: int) -> Dictionary:
	var mon := {"sp": sp, "lv": lv, "xp": xp_for(lv), "hp": 0, "moves": []}
	var learn: Dictionary = SPECIES[sp].learn
	var levels := learn.keys()
	levels.sort()
	for l in levels:
		if l <= lv:
			for m in learn[l]:
				_add_move(mon, m)
	mon.hp = max_hp(mon)
	return mon


## Learn a move. With four already, forget the weakest one. Returns the
## forgotten move or "".
static func _add_move(mon: Dictionary, move: String) -> String:
	var moves: Array = mon.moves
	if move in moves:
		return ""
	if moves.size() < 4:
		moves.append(move)
		return ""
	var worst := 0
	for i in moves.size():
		if MOVES[moves[i]].power < MOVES[moves[worst]].power:
			worst = i
	var old: String = moves[worst]
	moves[worst] = move
	return old


## Add experience. Returns a list of things that happened, like
## [{"level": 6}, {"learned": "ember", "forgot": ""}].
static func gain_xp(mon: Dictionary, amount: int) -> Array:
	var out := []
	if mon.lv >= MAX_LEVEL:
		return out
	mon.xp += amount
	while mon.lv < MAX_LEVEL and mon.xp >= xp_for(mon.lv + 1):
		var old_max := max_hp(mon)
		mon.lv += 1
		mon.hp += max_hp(mon) - old_max
		out.append({"level": mon.lv})
		var learn: Dictionary = SPECIES[mon.sp].learn
		if learn.has(mon.lv):
			for m in learn[mon.lv]:
				var forgot := _add_move(mon, m)
				out.append({"learned": m, "forgot": forgot})
	return out


static func xp_reward(foe: Dictionary, trainer: bool) -> int:
	var x := int(SPECIES[foe.sp].xp * foe.lv / 6.0)
	return int(x * 1.5) if trainer else x


static func effectiveness(move_type: String, target_type: String) -> float:
	return CHART.get(move_type, {}).get(target_type, 1.0)


static func stage_mult(stage: int) -> float:
	return (2.0 + stage) / 2.0 if stage >= 0 else 2.0 / (2.0 - stage)


## How much a move hurts. atk_stage / def_stage are -6..6.
## Returns {"damage": int, "mult": float, "crit": bool}
static func damage(attacker: Dictionary, target: Dictionary, move: String, atk_stage := 0, def_stage := 0, rng_on := true) -> Dictionary:
	var m: Dictionary = MOVES[move]
	if m.power <= 0:
		return {"damage": 0, "mult": 1.0, "crit": false}
	var a := stats(attacker)
	var d := stats(target)
	var atk: float = a.atk * stage_mult(atk_stage)
	var def: float = d.def * stage_mult(def_stage)
	var base := floorf(floorf((2.0 * attacker.lv / 5.0 + 2.0) * m.power * atk / def) / 50.0) + 2.0
	if m.type == type_of(attacker):
		base *= 1.5
	var mult := effectiveness(m.type, type_of(target))
	base *= mult
	var crit := rng_on and randf() < 1.0 / 16.0
	if crit:
		base *= 1.5
	if rng_on:
		base *= randf_range(0.85, 1.0)
	return {"damage": maxi(1, int(base)), "mult": mult, "crit": crit}


## Chance (0..1) that a Crito Ball catches this wild Crito Mon.
static func catch_chance(mon: Dictionary) -> float:
	var mh := float(max_hp(mon))
	var rate: float = SPECIES[mon.sp].catch
	var a: float = (3.0 * mh - 2.0 * mon.hp) * rate / (3.0 * mh)
	return clampf(a / 255.0 + 0.08, 0.05, 0.98)
