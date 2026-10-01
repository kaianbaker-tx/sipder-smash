class_name Person
extends Node3D
## A Kenney animated character with a painted outfit (skin) and optional
## cap, hat or glasses. Used for you, the professor and every trainer.
## Arm poses (wave, throw, point) are layered on top of idle / run.

const MODEL := preload("res://assets/chars/characterMedium.fbx")
const ANIMS := {
	"idle": "res://assets/chars/idle.fbx",
	"run": "res://assets/chars/run.fbx",
	"jump": "res://assets/chars/jump.fbx",
}

var skin: Texture2D
var height := 1.75
# {"cap": Color, "cap2": Color, "hat": Color, "glasses": true, "bag": Color}
var gear := {}

var skeleton: Skeleton3D
var anim: AnimationPlayer
var material: ShaderMaterial
var pivot: Node3D
var wave := 0.0            # 0..1 right arm waving
var throw := 0.0           # 0..1 right arm throwing forward
var point := 0.0           # 0..1 right arm pointing forward
var think := 0.0           # 0..1 hand on chin
var awake := true          # far away people stop animating

var _current := ""
var _bones := {}
var _axis := {}
var _t := 0.0

static var _lib: AnimationLibrary


func _init(skin_path := "", h := 1.75, g := {}) -> void:
	if skin_path != "":
		skin = load(skin_path)
	height = h
	gear = g


func _ready() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	# Kenney characters face +Z, Godot faces -Z: turn around
	pivot.rotation.y = PI
	var inst: Node3D = MODEL.instantiate()
	pivot.add_child(inst)
	inst.scale = Vector3.ONE * (height / 3.76)
	skeleton = inst.find_child("Skeleton3D", true, false)
	var mesh: MeshInstance3D = inst.find_child("characterMedium", true, false)
	material = Toon.unique(Color.WHITE, skin)
	material.set_shader_parameter("rim", 0.6)
	material.next_pass = Toon.outline()
	mesh.material_override = material
	for b in ["RightArm", "RightForeArm", "LeftArm", "LeftForeArm", "Head", "RightHand"]:
		_bones[b] = skeleton.find_bone(b)
	for b in ["RightArm", "RightForeArm", "LeftArm", "LeftForeArm"]:
		var i: int = _bones[b]
		var child := -1
		for c in skeleton.get_bone_children(i):
			child = c
			break
		_axis[b] = skeleton.get_bone_rest(child).origin.normalized() if child >= 0 else Vector3.UP
	anim = AnimationPlayer.new()
	inst.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", _library())
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	play("idle")
	anim.seek(randf() * 2.0, true)
	_add_gear()


static func _library() -> AnimationLibrary:
	if _lib:
		return _lib
	_lib = AnimationLibrary.new()
	for key in ANIMS:
		var src: Node = (load(ANIMS[key]) as PackedScene).instantiate()
		var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
		for n in ap.get_animation_list():
			if n.contains("Targeting"):
				continue
			var a: Animation = ap.get_animation(n).duplicate()
			a.loop_mode = Animation.LOOP_LINEAR if key != "jump" else Animation.LOOP_NONE
			_lib.add_animation(key, a)
		src.free()
	return _lib


func play(name: String, speed := 1.0, blend := 0.15) -> void:
	anim.speed_scale = speed
	if name == _current:
		return
	_current = name
	anim.play(name, blend)


## Walk / run animation from a ground speed in metres per second.
func move_speed(v: float) -> void:
	if v < 0.3:
		play("idle")
	else:
		play("run", clampf(v / 7.5, 0.55, 1.45))


func set_flash(f: float) -> void:
	material.set_shader_parameter("flash", f)


func _process(delta: float) -> void:
	if not awake:
		return
	_t += delta
	skeleton.reset_bone_poses()
	anim.advance(delta)
	_apply_poses()


func _aim(bone: String, dir_world: Vector3, weight: float) -> void:
	if weight <= 0.001:
		return
	var i: int = _bones[bone]
	var inv := skeleton.global_transform.basis.inverse()
	var d := (inv * dir_world).normalized()
	var g := skeleton.get_bone_global_pose(i)
	var axis_g := (g.basis * (_axis[bone] as Vector3)).normalized()
	var q := Quaternion(axis_g, d)
	q = Quaternion.IDENTITY.slerp(q, clampf(weight, 0.0, 1.0))
	skeleton.set_bone_global_pose(i, Transform3D(Basis(q) * g.basis, g.origin))


func _apply_poses() -> void:
	var gb := global_transform.basis.orthonormalized()
	var fwd := -gb.z
	var up := gb.y
	var right := gb.x
	if wave > 0.01:
		var s := sin(_t * 12.0) * 0.45
		_aim("RightArm", (right * 0.5 + up * 1.0).normalized(), wave)
		_aim("RightForeArm", (up + right * s + fwd * 0.2).normalized(), wave)
	if throw > 0.01:
		# wind up behind the head then fling forward
		var t := clampf(throw, 0.0, 1.0)
		var back := (up * 0.9 - fwd * 0.6 + right * 0.3).normalized()
		var front := (fwd * 1.0 + up * 0.15 + right * 0.1).normalized()
		var d := back.slerp(front, smoothstep(0.35, 0.8, t))
		var w := sin(t * PI) * 1.2
		_aim("RightArm", d, w)
		_aim("RightForeArm", d, w)
	if point > 0.01:
		var d2 := (fwd + up * 0.1 + right * 0.15).normalized()
		_aim("RightArm", d2, point)
		_aim("RightForeArm", d2, point)
	if think > 0.01:
		_aim("RightArm", (-up * 0.4 + fwd * 0.6 + right * 0.2).normalized(), think)
		_aim("RightForeArm", (up * 0.9 + fwd * 0.3 - right * 0.4).normalized(), think)


# ------------------------------------------------------------------ gear

func _part(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := Toon.color(col, {"rim": 0.5})
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _add_gear() -> void:
	if gear.is_empty():
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Head"
	skeleton.add_child(ba)
	# head space: +y up the neck, +z out of the face. Bones are in
	# centimetres, so scale gear made in model units (head ~1.1 wide).
	var head := Node3D.new()
	head.scale = Vector3.ONE * 0.01
	ba.add_child(head)
	var ol := Toon.outline()
	if gear.has("cap"):
		var dome := SphereMesh.new()
		dome.radius = 0.62
		dome.height = 0.62
		dome.is_hemisphere = true
		dome.radial_segments = 20
		dome.rings = 6
		var d := _part(head, dome, gear.cap, Vector3(0, 0.46, 0.0), Vector3.ZERO, Vector3(0.95, 0.72, 1.0))
		d.material_override = Toon.color(gear.cap, {"rim": 0.5}).duplicate()
		d.material_override.next_pass = ol
		var brim := CylinderMesh.new()
		brim.top_radius = 0.42
		brim.bottom_radius = 0.42
		brim.height = 0.05
		brim.radial_segments = 16
		_part(head, brim, gear.get("cap2", gear.cap), Vector3(0, 0.5, 0.5), Vector3(0.12, 0, 0), Vector3(1.0, 1, 0.85))
		var band := CylinderMesh.new()
		band.top_radius = 0.64
		band.bottom_radius = 0.66
		band.height = 0.12
		band.radial_segments = 20
		_part(head, band, gear.get("cap2", Color.WHITE), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(0.95, 1, 0.99))
	if gear.has("hat"):
		var crown := CylinderMesh.new()
		crown.top_radius = 0.5
		crown.bottom_radius = 0.6
		crown.height = 0.45
		crown.radial_segments = 16
		var c := _part(head, crown, gear.hat, Vector3(0, 0.7, 0))
		c.material_override = Toon.color(gear.hat, {"rim": 0.5}).duplicate()
		c.material_override.next_pass = ol
		var wide := CylinderMesh.new()
		wide.top_radius = 1.0
		wide.bottom_radius = 1.0
		wide.height = 0.05
		wide.radial_segments = 20
		_part(head, wide, gear.hat.darkened(0.1), Vector3(0, 0.5, 0.05))
		var ribbon := CylinderMesh.new()
		ribbon.top_radius = 0.585
		ribbon.bottom_radius = 0.6
		ribbon.height = 0.1
		ribbon.radial_segments = 16
		_part(head, ribbon, gear.get("hat2", Color(0.8, 0.2, 0.2)), Vector3(0, 0.57, 0))
	if gear.get("glasses", false):
		var lens := CylinderMesh.new()
		lens.top_radius = 0.14
		lens.bottom_radius = 0.14
		lens.height = 0.04
		lens.radial_segments = 14
		for sx in [-1.0, 1.0]:
			var l := _part(head, lens, Color(0.15, 0.1, 0.2), Vector3(0.19 * sx, 0.3, 0.46), Vector3(PI / 2, 0, 0))
			var inner := _part(head, lens, Color(0.75, 0.95, 1.0), Vector3(0.19 * sx, 0.3, 0.48), Vector3(PI / 2, 0, 0), Vector3(0.75, 1, 0.75))
			inner.material_override = Toon.color(Color(0.75, 0.95, 1.0), {"emission": 0.4})
			l.name = "lens"
	if gear.has("bag"):
		var bb := BoneAttachment3D.new()
		bb.bone_name = "Spine"
		skeleton.add_child(bb)
		var back := Node3D.new()
		back.scale = Vector3.ONE * 0.01
		bb.add_child(back)
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 0.9, 0.35)
		var b := _part(back, box, gear.bag, Vector3(0, 0.35, -0.45))
		b.material_override = Toon.color(gear.bag, {"rim": 0.4}).duplicate()
		b.material_override.next_pass = ol
		var flap := BoxMesh.new()
		flap.size = Vector3(0.82, 0.3, 0.37)
		_part(back, flap, gear.bag.darkened(0.25), Vector3(0, 0.72, -0.45))
