class_name HeroModel
extends Node3D
## The Kenney animated character, dressed in a painted spider suit.
## Animates "on twos" (12 poses a second) like Into the Spider-Verse,
## with procedural poses layered on top: web swing arm, punches, skydive.

const MODEL := preload("res://assets/hero/characterMedium.fbx")
const ANIMS := {
	"idle": "res://assets/hero/idle.fbx",
	"run": "res://assets/hero/run.fbx",
	"jump": "res://assets/hero/jump.fbx",
}

@export var skin: Texture2D
@export var on_twos := true
@export var height := 1.8

var skeleton: Skeleton3D
var anim: AnimationPlayer
var material: ShaderMaterial
var mesh: MeshInstance3D
var pivot: Node3D

# procedural pose inputs (set by the player every frame)
var aim_right := Vector3.ZERO     # world direction for the right arm (web)
var aim_right_w := 0.0
var aim_left := Vector3.ZERO
var aim_left_w := 0.0
var punch := 0.0                  # 0..1 punch extension
var punch_side := 1               # 1 right, -1 left
var kick := 0.0
var spread := 0.0                 # skydive: arms and legs out
var tuck := 0.0                   # knees up (swinging, flipping)
var crouch := 0.0                 # superhero landing
var anim_speed := 1.0

var _acc := 0.0
var _bones := {}
var _axis := {}
var _current := ""


func _ready() -> void:
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	# Kenney characters face +Z, Godot faces -Z: turn around
	pivot.rotation.y = PI
	var inst: Node3D = MODEL.instantiate()
	pivot.add_child(inst)
	var s := height / 3.76
	inst.scale = Vector3.ONE * s
	skeleton = inst.find_child("Skeleton3D", true, false)
	mesh = inst.find_child("characterMedium", true, false)
	material = Toon.unique_material(skin, {"character": 1.0})
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for b in ["LeftArm", "LeftForeArm", "RightArm", "RightForeArm", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "Spine", "Chest", "Head", "Hips", "HipsCtrl", "LeftHand", "RightHand"]:
		var i := skeleton.find_bone(b)
		_bones[b] = i
	for b in ["LeftArm", "LeftForeArm", "RightArm", "RightForeArm", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg"]:
		var i: int = _bones[b]
		var child := -1
		for c in skeleton.get_bone_children(i):
			child = c
			break
		_axis[b] = skeleton.get_bone_rest(child).origin.normalized() if child >= 0 else Vector3.UP

	anim = AnimationPlayer.new()
	inst.add_child(anim)
	anim.root_node = NodePath("..")
	var lib := AnimationLibrary.new()
	for key in ANIMS:
		var src: Node = (load(ANIMS[key]) as PackedScene).instantiate()
		var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
		for n in ap.get_animation_list():
			if n.contains("Targeting"):
				continue
			var a: Animation = ap.get_animation(n).duplicate()
			a.loop_mode = Animation.LOOP_LINEAR if key != "jump" else Animation.LOOP_NONE
			lib.add_animation(key, a)
		src.free()
	anim.add_animation_library("", lib)
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	play("idle")


func set_skin(tex: Texture2D) -> void:
	skin = tex
	if material:
		material.set_shader_parameter("albedo_tex", tex)


func play(name: String, blend := 0.12, speed := 1.0) -> void:
	anim_speed = speed
	if name == _current:
		return
	_current = name
	anim.play(name, blend)


func restart(name: String) -> void:
	_current = name
	anim.play(name, 0.05)
	anim.seek(0.0, true)


func hand_position(right := true) -> Vector3:
	var b: int = _bones["RightHand" if right else "LeftHand"]
	return skeleton.global_transform * skeleton.get_bone_global_pose(b).origin


func _process(delta: float) -> void:
	_acc += delta * anim_speed
	var step := 1.0 / 12.0 if on_twos else 0.0
	if _acc < step:
		return
	skeleton.reset_bone_poses()
	anim.advance(_acc)
	_acc = 0.0
	_apply_overlays()


func _aim(bone: String, dir_world: Vector3, weight: float) -> void:
	if weight <= 0.001 or dir_world.length_squared() < 0.0001:
		return
	var i: int = _bones[bone]
	var inv := skeleton.global_transform.basis.inverse()
	var d := (inv * dir_world).normalized()
	var g := skeleton.get_bone_global_pose(i)
	var axis_g := (g.basis * (_axis[bone] as Vector3)).normalized()
	var q := Quaternion(axis_g, d)
	q = Quaternion.IDENTITY.slerp(q, clampf(weight, 0.0, 1.0))
	skeleton.set_bone_global_pose(i, Transform3D(Basis(q) * g.basis, g.origin))


func _apply_overlays() -> void:
	var gb := global_transform.basis
	var fwd := -gb.z.normalized()
	var up := gb.y.normalized()
	var right := gb.x.normalized()
	if spread > 0.01:
		_aim("RightArm", (right * 1.0 + up * 0.35 + fwd * 0.2).normalized(), spread)
		_aim("RightForeArm", (right + up * 0.5).normalized(), spread)
		_aim("LeftArm", (-right * 1.0 + up * 0.35 + fwd * 0.2).normalized(), spread)
		_aim("LeftForeArm", (-right + up * 0.5).normalized(), spread)
		_aim("RightUpLeg", (-up + right * 0.35 - fwd * 0.3).normalized(), spread)
		_aim("LeftUpLeg", (-up - right * 0.35 - fwd * 0.3).normalized(), spread)
		_aim("RightLeg", (-up - fwd * 0.8).normalized(), spread * 0.8)
		_aim("LeftLeg", (-up - fwd * 0.2).normalized(), spread * 0.8)
	if tuck > 0.01:
		_aim("RightUpLeg", (fwd * 0.9 - up * 0.4 + right * 0.15).normalized(), tuck)
		_aim("LeftUpLeg", (fwd * 0.9 - up * 0.4 - right * 0.15).normalized(), tuck)
		_aim("RightLeg", (-up - fwd * 0.3).normalized(), tuck)
		_aim("LeftLeg", (-up - fwd * 0.3).normalized(), tuck)
	if crouch > 0.01:
		_aim("RightUpLeg", (fwd * 0.8 - up * 0.3 + right * 0.3).normalized(), crouch)
		_aim("LeftUpLeg", (fwd * 0.2 - up * 0.9 - right * 0.4).normalized(), crouch)
		_aim("RightLeg", (-up).normalized(), crouch)
		_aim("LeftLeg", (-fwd * 0.9 - up * 0.3).normalized(), crouch)
		_aim("RightArm", (-up * 0.9 + fwd * 0.3 + right * 0.2).normalized(), crouch)
		_aim("LeftArm", (-right * 1.0 + up * 0.4 - fwd * 0.3).normalized(), crouch)
	if aim_right_w > 0.0:
		_aim("RightArm", aim_right, aim_right_w)
		_aim("RightForeArm", aim_right, aim_right_w)
	if aim_left_w > 0.0:
		_aim("LeftArm", aim_left, aim_left_w)
		_aim("LeftForeArm", aim_left, aim_left_w)
	if punch > 0.01:
		var arm := "RightArm" if punch_side > 0 else "LeftArm"
		var fore := "RightForeArm" if punch_side > 0 else "LeftForeArm"
		var tgt := (fwd + up * 0.1 + right * 0.08 * -punch_side).normalized()
		_aim(arm, tgt, punch)
		_aim(fore, tgt, punch)
		# the other fist guards the chin
		var g_arm := "LeftArm" if punch_side > 0 else "RightArm"
		var g_fore := "LeftForeArm" if punch_side > 0 else "RightForeArm"
		_aim(g_arm, (fwd * 0.3 - up * 0.7 - right * punch_side * 0.4).normalized(), punch * 0.8)
		_aim(g_fore, (fwd * 0.6 + up * 0.8).normalized(), punch * 0.8)
	if kick > 0.01:
		_aim("RightUpLeg", (fwd + up * 0.35).normalized(), kick)
		_aim("RightLeg", (fwd + up * 0.25).normalized(), kick)
		_aim("LeftUpLeg", (-up - fwd * 0.2).normalized(), kick * 0.6)

