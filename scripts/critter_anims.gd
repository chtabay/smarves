class_name CritterAnims
extends RefCounted
## Les animations des habitants, écrites une fois pour toute la famille : une bibliothèque et un arbre de mélange
## partagés par tous (chaque habitant n'a que ses paramètres). Angles en degrés ; un bras qui part vers l'avant
## tourne en X négatif, et z positif écarte le bras gauche (le droit est déduit en miroir).
##
## Trois couches : la pose de fond (repos, marche, assis…), un geste du haut du corps par-dessus (parler, miser,
## donner une carte…) et un geste du corps entier (saut de joie, dépit qui tape du pied).

const SKEL := "Skeleton3D:"

## Poses de fond (en boucle).
const BASE := ["idle", "attentive", "stand_table", "behind_back", "bar", "sing", "walk", "run", "sit", "sit_table", "piano"]
## Gestes du haut du corps (une fois).
const GESTURES := ["talk", "wave", "cheer", "sulk", "shrug", "clap", "bet", "deal", "spin", "rake", "pay", "nod", "bow",
	"scratch", "look_watch", "drink", "point", "facepalm"]
## Gestes du corps entier (une fois, debout).
const FULL := ["jump", "stomp"]

const UPPER := ["spine", "chest", "head", "arm_l", "arm_r", "forearm_l", "forearm_r", "hand_l", "hand_r", "ear_l", "ear_r"]
const PAIRS := ["arm", "forearm", "hand", "thigh", "shin", "foot", "ear"]

static var _lib: AnimationLibrary
static var _tree: AnimationNodeBlendTree


static func library() -> AnimationLibrary:
	if _lib == null:
		_lib = AnimationLibrary.new()
		var all := _specs()
		for name in all:
			_lib.add_animation(name, _make(all[name], name in BASE))
	return _lib


static func tree_root() -> AnimationNodeBlendTree:
	if _tree != null:
		return _tree
	var bt := AnimationNodeBlendTree.new()
	var base := AnimationNodeTransition.new()
	base.xfade_time = 0.3
	base.allow_transition_to_self = false
	bt.add_node("base", base)
	for i in BASE.size():
		base.add_input(BASE[i])
		var an := AnimationNodeAnimation.new()
		an.animation = BASE[i]
		bt.add_node("a_" + BASE[i], an)
		bt.connect_node("base", i, "a_" + BASE[i])
	var seek := AnimationNodeTimeSeek.new()
	bt.add_node("seek", seek)
	bt.connect_node("seek", 0, "base")
	var speed := AnimationNodeTimeScale.new()
	bt.add_node("speed", speed)
	bt.connect_node("speed", 0, "seek")
	var gest := AnimationNodeTransition.new()
	gest.xfade_time = 0.0
	gest.allow_transition_to_self = true
	bt.add_node("gest", gest)
	for i in GESTURES.size():
		gest.add_input(GESTURES[i])
		var an := AnimationNodeAnimation.new()
		an.animation = GESTURES[i]
		bt.add_node("g_" + GESTURES[i], an)
		bt.connect_node("gest", i, "g_" + GESTURES[i])
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.22
	shot.fadeout_time = 0.35
	shot.filter_enabled = true
	for b in UPPER:
		shot.set_filter_path(NodePath(SKEL + b), true)
	bt.add_node("shot", shot)
	bt.connect_node("shot", 0, "speed")
	bt.connect_node("shot", 1, "gest")
	var fullg := AnimationNodeTransition.new()
	fullg.xfade_time = 0.0
	fullg.allow_transition_to_self = true
	bt.add_node("fullg", fullg)
	for i in FULL.size():
		fullg.add_input(FULL[i])
		var an := AnimationNodeAnimation.new()
		an.animation = FULL[i]
		bt.add_node("f_" + FULL[i], an)
		bt.connect_node("fullg", i, "f_" + FULL[i])
	var full := AnimationNodeOneShot.new()
	full.fadein_time = 0.12
	full.fadeout_time = 0.3
	bt.add_node("full", full)
	bt.connect_node("full", 0, "shot")
	bt.connect_node("full", 1, "fullg")
	bt.connect_node("output", 0, "full")
	_tree = bt
	return bt


# --- Fabrication ---------------------------------------------------------------------------

static func _make(spec: Dictionary, loop: bool) -> Animation:
	var a := Animation.new()
	var length: float = spec.len
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var rot: Dictionary = spec.get("rot", {})
	for bone in rot:
		if bone in PAIRS:
			_rot_track(a, bone + "_l", rot[bone], length, 1.0, loop)
			_rot_track(a, bone + "_r", rot[bone], length, -1.0, loop)
		else:
			_rot_track(a, bone, rot[bone], length, 1.0, loop)
	var pos: Dictionary = spec.get("pos", {})
	for bone in pos:
		var t := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(t, NodePath(SKEL + bone))
		for key in _closed(pos[bone], length, Vector3.ZERO, loop):
			a.position_track_insert_key(t, key[0], key[1])
	var scl: Dictionary = spec.get("scale", {})
	for bone in scl:
		var t := a.add_track(Animation.TYPE_SCALE_3D)
		a.track_set_path(t, NodePath(SKEL + bone))
		for key in _closed(scl[bone], length, Vector3.ONE, loop):
			a.scale_track_insert_key(t, key[0], key[1])
	return a


static func _rot_track(a: Animation, bone: String, keys: Array, length: float, side: float, loop: bool) -> void:
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, NodePath(SKEL + bone))
	# Lisse en boucle ; linéaire pour les gestes, où la courbe cubique déborde.
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC if loop else Animation.INTERPOLATION_LINEAR)
	for key in _closed(keys, length, Vector3.ZERO, loop):
		var e: Vector3 = key[1]
		if side < 0.0:
			e = Vector3(e.x, -e.y, -e.z)
		a.rotation_track_insert_key(t, key[0], Quaternion.from_euler(e * (PI / 180.0)))


## Les clés d'un geste commencent et finissent au neutre si l'auteur ne l'a pas dit ; une boucle se referme.
static func _closed(keys: Array, length: float, neutral: Vector3, loop: bool) -> Array:
	var out := keys.duplicate()
	if out[0][0] > 0.0:
		out.push_front([0.0, out[-1][1] if loop else neutral])
	if out[-1][0] < length:
		out.append([length, out[0][1] if loop else neutral])
	return out


## Une marche plus rapide et plus ample, tirée d'une autre.
static func _scaled(spec: Dictionary, time_k: float, angle_k: float, pos_k: float) -> Dictionary:
	var out := {"len": spec.len * time_k, "rot": {}, "pos": {}}
	for b in spec.rot:
		out.rot[b] = spec.rot[b].map(func(k): return [k[0] * time_k, k[1] * angle_k])
	for b in spec.get("pos", {}):
		out.pos[b] = spec.pos[b].map(func(k): return [k[0] * time_k, k[1] * pos_k])
	return out


static func V(x: float, y := 0.0, z := 0.0) -> Vector3:
	return Vector3(x, y, z)


# --- Les mouvements ------------------------------------------------------------------------

static func _specs() -> Dictionary:
	var s := {}
	var breath := {"chest": [[0.0, V(1, 1, 1)], [1.8, V(1.02, 1.03, 1.02)], [3.6, V(1, 1, 1)]]}
	var idle_head := [[0.0, V(0)], [1.2, V(-2, 4, 2)], [2.4, V(1, -3, -1)], [3.6, V(0)]]
	var ear_flick := [[0.0, V(0)], [2.7, V(0)], [2.85, V(0, 0, -14)], [3.0, V(0)], [3.6, V(0)]]

	s.idle = {"len": 3.6, "rot": {
		"spine": [[0.0, V(2)], [1.8, V(3.5)], [3.6, V(2)]],
		"head": idle_head,
		"hips": [[0.0, V(0, 0, 1)], [1.8, V(0, 0, -1)], [3.6, V(0, 0, 1)]],
		"arm": [[0.0, V(-4, 0, 8)], [1.8, V(-6, 0, 10)], [3.6, V(-4, 0, 8)]],
		"forearm": [[0.0, V(-14)], [1.8, V(-18)], [3.6, V(-14)]],
		"thigh": [[0.0, V(0)]], "shin": [[0.0, V(0)]], "foot": [[0.0, V(0)]],
		"tail": [[0.0, V(-10, -12, 0)], [1.8, V(-10, 12, 0)], [3.6, V(-10, -12, 0)]],
		"ear": ear_flick,
	}, "scale": breath, "pos": {"root": [[0.0, V(0)]]}}

	s.attentive = {"len": 4.0, "rot": {
		"spine": [[0.0, V(0)], [2.0, V(1.5)], [4.0, V(0)]],
		"head": [[0.0, V(0)], [2.0, V(-2, 3, 0)], [4.0, V(0)]],
		"hips": [[0.0, V(0)]],
		"arm": [[0.0, V(-20, 0, -12)], [2.0, V(-22, 0, -12)], [4.0, V(-20, 0, -12)]],
		"forearm": [[0.0, V(-72, 0, -26)], [2.0, V(-74, 0, -26)], [4.0, V(-72, 0, -26)]],
		"thigh": [[0.0, V(0)]], "shin": [[0.0, V(0)]], "foot": [[0.0, V(0)]],
		"tail": [[0.0, V(-10, -6, 0)], [2.0, V(-10, 6, 0)], [4.0, V(-10, -6, 0)]],
		"ear": ear_flick,
	}, "scale": {"chest": [[0.0, V(1, 1, 1)], [2.0, V(1.015, 1.02, 1.015)], [4.0, V(1, 1, 1)]]}, "pos": {"root": [[0.0, V(0)]]}}

	s.stand_table = {"len": 4.0, "rot": {
		"spine": [[0.0, V(12)], [2.0, V(13.5)], [4.0, V(12)]],
		"head": [[0.0, V(-8)], [2.0, V(-6, 4, 0)], [4.0, V(-8)]],
		"hips": [[0.0, V(0)]],
		"arm": [[0.0, V(-40, 0, -6)], [2.0, V(-42, 0, -6)], [4.0, V(-40, 0, -6)]],
		"forearm": [[0.0, V(-30, 0, -10)], [2.0, V(-32, 0, -10)], [4.0, V(-30, 0, -10)]],
		"hand": [[0.0, V(20)]],
		"thigh": [[0.0, V(0)]], "shin": [[0.0, V(0)]], "foot": [[0.0, V(0)]],
		"tail": [[0.0, V(-10, -6, 0)], [2.0, V(-10, 6, 0)], [4.0, V(-10, -6, 0)]],
		"ear": ear_flick,
	}, "scale": {"chest": [[0.0, V(1, 1, 1)], [2.0, V(1.015, 1.02, 1.015)], [4.0, V(1, 1, 1)]]}, "pos": {"root": [[0.0, V(0)]]}}

	s.behind_back = {"len": 4.4, "rot": {
		"spine": [[0.0, V(-2)], [2.2, V(-1)], [4.4, V(-2)]],
		"head": [[0.0, V(-3)], [1.5, V(-3, 6, 0)], [3.0, V(-2, -5, 0)], [4.4, V(-3)]],
		"hips": [[0.0, V(0)]],
		"arm": [[0.0, V(24, 0, -6)], [2.2, V(25, 0, -6)], [4.4, V(24, 0, -6)]],
		"forearm": [[0.0, V(-70, 0, -24)]],
		"thigh": [[0.0, V(0)]], "shin": [[0.0, V(0)]], "foot": [[0.0, V(0)]],
		"tail": [[0.0, V(-10, -10, 0)], [2.2, V(-10, 10, 0)], [4.4, V(-10, -10, 0)]],
		"ear": ear_flick,
	}, "scale": {"chest": [[0.0, V(1, 1, 1)], [2.2, V(1.02, 1.025, 1.02)], [4.4, V(1, 1, 1)]]}, "pos": {"root": [[0.0, V(0)]]}}

	s.bar = {"len": 1.8, "rot": {
		"spine": [[0.0, V(8)]],
		"head": [[0.0, V(8, 10, 0)], [0.9, V(10, 8, 0)], [1.8, V(8, 10, 0)]],
		"hips": [[0.0, V(0)]],
		"arm_l": [[0.0, V(-40, 0, -10)]], "forearm_l": [[0.0, V(-78, 0, -22)]],
		"arm_r": [[0.0, V(-42, 0, 8)], [0.45, V(-48, -8, 4)], [0.9, V(-44, 0, 0)], [1.35, V(-38, 8, 4)], [1.8, V(-42, 0, 8)]],
		"forearm_r": [[0.0, V(-70, 0, 15)], [0.9, V(-76, 0, 18)], [1.8, V(-70, 0, 15)]],
		"thigh": [[0.0, V(0)]], "shin": [[0.0, V(0)]], "foot": [[0.0, V(0)]],
		"tail": [[0.0, V(-10, -6, 0)], [0.9, V(-10, 6, 0)], [1.8, V(-10, -6, 0)]],
	}, "pos": {"root": [[0.0, V(0)]]}}

	s.sing = {"len": 2.4, "rot": {
		"spine": [[0.0, V(-3)]],
		"hips": [[0.0, V(0, 0, 4)], [1.2, V(0, 0, -4)], [2.4, V(0, 0, 4)]],
		"head": [[0.0, V(-8, 8, 4)], [1.2, V(-6, -8, -4)], [2.4, V(-8, 8, 4)]],
		"arm_r": [[0.0, V(-72, 0, -32)], [1.2, V(-66, 0, -42)], [2.4, V(-72, 0, -32)]],
		"forearm_r": [[0.0, V(-15)], [1.2, V(-25)], [2.4, V(-15)]],
		"arm_l": [[0.0, V(-35, 0, -20)]], "forearm_l": [[0.0, V(-95, 0, -20)]],
		"thigh": [[0.0, V(0, 0, -4)], [1.2, V(0, 0, 4)], [2.4, V(0, 0, -4)]], "shin": [[0.0, V(0)]], "foot": [[0.0, V(0)]],
		"tail": [[0.0, V(-10, -12, 0)], [1.2, V(-10, 12, 0)], [2.4, V(-10, -12, 0)]],
	}, "pos": {"root": [[0.0, V(0)]]}}

	s.walk = {"len": 0.56, "rot": {
		"thigh_l": [[0.0, V(-26)], [0.14, V(-2)], [0.28, V(22)], [0.42, V(-2)], [0.56, V(-26)]],
		"thigh_r": [[0.0, V(22)], [0.14, V(-2)], [0.28, V(-26)], [0.42, V(-2)], [0.56, V(22)]],
		"shin_l": [[0.0, V(4)], [0.14, V(10)], [0.28, V(16)], [0.38, V(55)], [0.48, V(25)], [0.56, V(4)]],
		"shin_r": [[0.0, V(16)], [0.1, V(55)], [0.2, V(25)], [0.28, V(4)], [0.42, V(10)], [0.56, V(16)]],
		"foot_l": [[0.0, V(8)], [0.28, V(-10)], [0.38, V(-25)], [0.56, V(8)]],
		"foot_r": [[0.0, V(-10)], [0.1, V(-25)], [0.28, V(8)], [0.56, V(-10)]],
		"arm_l": [[0.0, V(20, 0, 6)], [0.28, V(-24, 0, 6)], [0.56, V(20, 0, 6)]],
		"arm_r": [[0.0, V(-24, 0, -6)], [0.28, V(20, 0, -6)], [0.56, V(-24, 0, -6)]],
		"forearm_l": [[0.0, V(-12)], [0.28, V(-32)], [0.56, V(-12)]],
		"forearm_r": [[0.0, V(-32)], [0.28, V(-12)], [0.56, V(-32)]],
		"hips": [[0.0, V(0, -7, 2)], [0.28, V(0, 7, -2)], [0.56, V(0, -7, 2)]],
		"spine": [[0.0, V(6, 5, 0)], [0.28, V(6, -5, 0)], [0.56, V(6, 5, 0)]],
		"head": [[0.0, V(-4, 0, -2)], [0.14, V(-2)], [0.28, V(-4, 0, 2)], [0.42, V(-2)], [0.56, V(-4, 0, -2)]],
		"tail": [[0.0, V(-15, -18, 0)], [0.28, V(-15, 18, 0)], [0.56, V(-15, -18, 0)]],
		"ear": [[0.0, V(0)], [0.14, V(-6)], [0.28, V(0)], [0.42, V(-6)], [0.56, V(0)]],
	}, "pos": {"root": [[0.0, V(0)], [0.14, V(0, 0.014, 0)], [0.28, V(0)], [0.42, V(0, 0.014, 0)], [0.56, V(0)]]}}

	s.run = _scaled(s.walk, 0.64, 1.6, 2.2)
	s.run.rot.forearm_l = [[0.0, V(-60)], [0.18, V(-80)], [0.36, V(-60)]]
	s.run.rot.forearm_r = [[0.0, V(-80)], [0.18, V(-60)], [0.36, V(-80)]]
	s.run.rot.spine = [[0.0, V(14, 6, 0)], [0.18, V(14, -6, 0)], [0.36, V(14, 6, 0)]]
	s.run.rot.head = [[0.0, V(-10, 0, -2)], [0.18, V(-10, 0, 2)], [0.36, V(-10, 0, -2)]]

	var sit_legs := {"thigh": [[0.0, V(-88, 0, 4)]], "shin": [[0.0, V(86)]], "foot": [[0.0, V(0)]], "hips": [[0.0, V(0)]],
		"tail": [[0.0, V(35, -8, 0)], [2.0, V(35, 8, 0)], [4.0, V(35, -8, 0)]]}
	s.sit = {"len": 4.0, "rot": sit_legs.merged({
		"spine": [[0.0, V(-2)], [2.0, V(-1)], [4.0, V(-2)]],
		"head": [[0.0, V(0)], [1.3, V(-2, 5, 3)], [2.7, V(2, -4, -2)], [4.0, V(0)]],
		"arm": [[0.0, V(-28, 0, 8)], [2.0, V(-30, 0, 8)], [4.0, V(-28, 0, 8)]],
		"forearm": [[0.0, V(-48, 0, -14)]],
		"hand": [[0.0, V(10)]],
		"ear": ear_flick,
	}), "scale": {"chest": [[0.0, V(1, 1, 1)], [2.0, V(1.02, 1.03, 1.02)], [4.0, V(1, 1, 1)]]}, "pos": {"root": [[0.0, V(0)]]}}

	s.sit_table = {"len": 4.0, "rot": sit_legs.merged({
		"spine": [[0.0, V(6)], [2.0, V(7)], [4.0, V(6)]],
		"head": [[0.0, V(-4)], [1.3, V(-4, 6, 3)], [2.7, V(-2, -5, -2)], [4.0, V(-4)]],
		"arm": [[0.0, V(-50, 0, 6)], [2.0, V(-52, 0, 6)], [4.0, V(-50, 0, 6)]],
		"forearm": [[0.0, V(-38, 0, -12)]],
		"hand": [[0.0, V(10)]],
		"ear": ear_flick,
	}), "scale": {"chest": [[0.0, V(1, 1, 1)], [2.0, V(1.02, 1.03, 1.02)], [4.0, V(1, 1, 1)]]}, "pos": {"root": [[0.0, V(0)]]}}

	s.piano = {"len": 1.0, "rot": sit_legs.merged({
		"tail": [[0.0, V(35)]],
		"spine": [[0.0, V(8)], [0.5, V(9)], [1.0, V(8)]],
		"head": [[0.0, V(4, -6, 3)], [0.5, V(6, 6, -3)], [1.0, V(4, -6, 3)]],
		"arm": [[0.0, V(-52, 0, 4)], [0.5, V(-50, 0, 8)], [1.0, V(-52, 0, 4)]],
		"forearm_l": [[0.0, V(-40, 0, -8)], [0.25, V(-46, 0, -8)], [0.5, V(-40, 0, -8)], [0.75, V(-44, 0, -8)], [1.0, V(-40, 0, -8)]],
		"forearm_r": [[0.0, V(-44, 0, 8)], [0.25, V(-40, 0, 8)], [0.5, V(-46, 0, 8)], [0.75, V(-40, 0, 8)], [1.0, V(-44, 0, 8)]],
		"hand": [[0.0, V(20)], [0.125, V(30)], [0.25, V(20)], [0.375, V(30)], [0.5, V(20)], [0.625, V(28)], [0.75, V(20)], [0.875, V(30)], [1.0, V(20)]],
	}), "pos": {"root": [[0.0, V(0)]]}}

	# --- Gestes du haut du corps.
	s.talk = {"len": 2.4, "rot": {
		"arm_r": [[0.0, V(-6, 0, -8)], [0.3, V(-35, 0, -14)], [0.9, V(-45, -10, -20)], [1.5, V(-30, 10, -12)], [2.0, V(-38, 0, -16)], [2.4, V(-6, 0, -8)]],
		"forearm_r": [[0.0, V(-14)], [0.3, V(-60, 0, 10)], [0.9, V(-45, 0, 20)], [1.5, V(-70, 0, 5)], [2.0, V(-55, 0, 15)], [2.4, V(-14)]],
		"hand_r": [[0.0, V(0)], [0.9, V(0, -30, 0)], [1.5, V(0, 20, 0)], [2.4, V(0)]],
		"arm_l": [[0.0, V(-4, 0, 8)], [0.6, V(-15, 0, 10)], [1.8, V(-18, 0, 12)], [2.4, V(-4, 0, 8)]],
		"forearm_l": [[0.0, V(-14)], [0.6, V(-35)], [1.8, V(-30)], [2.4, V(-14)]],
		"head": [[0.0, V(0)], [0.4, V(-4, 6, 3)], [0.9, V(4)], [1.4, V(-3, -6, -3)], [1.9, V(5)], [2.4, V(0)]],
		"chest": [[0.0, V(0)], [0.9, V(0, 6, 0)], [1.5, V(0, -5, 0)], [2.4, V(0)]],
	}}
	s.wave = {"len": 1.8, "rot": {
		"arm_r": [[0.0, V(0, 0, -8)], [0.3, V(22, 0, -118)], [1.5, V(22, 0, -118)], [1.8, V(0, 0, -8)]],
		"forearm_r": [[0.0, V(-10)], [0.3, V(0, 0, -35)], [0.55, V(0, 0, 5)], [0.8, V(0, 0, -35)], [1.05, V(0, 0, 5)], [1.3, V(0, 0, -35)], [1.8, V(-10)]],
		"head": [[0.0, V(0)], [0.3, V(0, -8, -8)], [1.5, V(0, -8, -8)], [1.8, V(0)]],
		"chest": [[0.0, V(0)], [0.3, V(0, 0, 6)], [1.5, V(0, 0, 6)], [1.8, V(0)]],
	}}
	s.cheer = {"len": 1.4, "rot": {
		"arm": [[0.0, V(0, 0, 8)], [0.2, V(18, 0, 128)], [0.45, V(18, 0, 112)], [0.7, V(18, 0, 132)], [0.95, V(18, 0, 112)], [1.2, V(18, 0, 128)], [1.4, V(0, 0, 8)]],
		"forearm": [[0.0, V(-10)], [0.2, V(0, 0, 25)], [1.2, V(0, 0, 25)], [1.4, V(-10)]],
		"head": [[0.0, V(0)], [0.2, V(-14)], [1.2, V(-14)], [1.4, V(0)]],
		"spine": [[0.0, V(0)], [0.2, V(-6)], [1.2, V(-6)], [1.4, V(0)]],
	}}
	s.sulk = {"len": 1.8, "rot": {
		"spine": [[0.0, V(2)], [0.35, V(8)], [1.3, V(7)], [1.8, V(2)]],
		"chest": [[0.0, V(0)], [0.35, V(4)], [1.3, V(4)], [1.8, V(0)]],
		"head": [[0.0, V(0)], [0.35, V(15)], [0.7, V(15, -14, 0)], [0.95, V(15, 14, 0)], [1.2, V(15, -8, 0)], [1.8, V(0)]],
		"arm": [[0.0, V(-4, 0, 8)], [0.35, V(4, 0, 2)], [1.3, V(4, 0, 2)], [1.8, V(-4, 0, 8)]],
		"forearm": [[0.0, V(-14)], [0.35, V(-4)], [1.3, V(-4)], [1.8, V(-14)]],
	}}
	s.shrug = {"len": 1.3, "rot": {
		"arm": [[0.0, V(0, 0, 8)], [0.3, V(-15, 0, 32)], [0.9, V(-15, 0, 32)], [1.3, V(0, 0, 8)]],
		"forearm": [[0.0, V(-14)], [0.3, V(-75, 30, 0)], [0.9, V(-75, 30, 0)], [1.3, V(-14)]],
		"head": [[0.0, V(0)], [0.3, V(0, 0, 12)], [0.9, V(0, 0, 12)], [1.3, V(0)]],
		"chest": [[0.0, V(0)], [0.3, V(-4)], [0.9, V(-4)], [1.3, V(0)]],
	}}
	var clap := [[0.0, V(-14)], [0.2, V(-55, 0, -30)]]
	for j in 7:
		clap.append([0.32 + j * 0.12, V(-55, 0, -48 if j % 2 == 0 else -30)])
	clap.append([1.6, V(-14)])
	s.clap = {"len": 1.6, "rot": {
		"arm": [[0.0, V(-4, 0, 8)], [0.2, V(-40, 0, -14)], [1.3, V(-40, 0, -14)], [1.6, V(-4, 0, 8)]],
		"forearm": clap,
		"head": [[0.0, V(0)], [0.2, V(-6)], [1.3, V(-6)], [1.6, V(0)]],
	}}
	s.bet = {"len": 1.6, "rot": {
		"spine": [[0.0, V(2)], [0.4, V(16)], [1.0, V(16)], [1.6, V(2)]],
		"arm_r": [[0.0, V(-5, 0, -8)], [0.4, V(-70)], [0.7, V(-78, 0, 4)], [1.0, V(-70)], [1.6, V(-5, 0, -8)]],
		"forearm_r": [[0.0, V(-14)], [0.4, V(-30)], [0.7, V(-12)], [1.0, V(-30)], [1.6, V(-14)]],
		"hand_r": [[0.0, V(0)], [0.4, V(0)], [0.7, V(30)], [1.0, V(0)]],
		"head": [[0.0, V(0)], [0.4, V(18)], [1.0, V(18)], [1.6, V(0)]],
	}}
	s.deal = {"len": 0.9, "rot": {
		"arm_r": [[0.0, V(-40, 0, -6)], [0.25, V(-55, 0, 10)], [0.5, V(-62, 0, -25)], [0.9, V(-40, 0, -6)]],
		"forearm_r": [[0.0, V(-30)], [0.25, V(-60, 0, 15)], [0.5, V(-15, 0, -10)], [0.9, V(-30)]],
		"hand_r": [[0.0, V(0)], [0.25, V(0)], [0.5, V(0, 0, -30)], [0.9, V(0)]],
		"head": [[0.0, V(-8)], [0.5, V(4, -10, 0)], [0.9, V(-8)]],
		"spine": [[0.0, V(12)], [0.5, V(16)], [0.9, V(12)]],
	}}
	s.spin = {"len": 1.3, "rot": {
		"arm_r": [[0.0, V(-40, 0, -6)], [0.35, V(-70, -15, 10)], [0.6, V(-65, 25, -15)], [1.3, V(-40, 0, -6)]],
		"forearm_r": [[0.0, V(-30)], [0.35, V(-80)], [0.6, V(-30)], [1.3, V(-30)]],
		"hand_r": [[0.0, V(0)], [0.35, V(0, 40, 0)], [0.6, V(0, -40, 0)], [1.3, V(0)]],
		"head": [[0.0, V(-8)], [0.6, V(6, -12, 0)], [1.3, V(-8)]],
		"spine": [[0.0, V(12)], [0.5, V(16)], [1.3, V(12)]],
	}}
	s.rake = {"len": 1.6, "rot": {
		"spine": [[0.0, V(12)], [0.5, V(22)], [1.1, V(10)], [1.6, V(12)]],
		"arm": [[0.0, V(-40, 0, -6)], [0.5, V(-80, 0, -4)], [1.1, V(-35, 0, -10)], [1.6, V(-40, 0, -6)]],
		"forearm": [[0.0, V(-30)], [0.5, V(-10)], [1.1, V(-50)], [1.6, V(-30)]],
		"head": [[0.0, V(-8)], [0.5, V(6)], [1.6, V(-8)]],
	}}
	# Distribuer les jetons : la main droite pousse une pile vers le gagnant, deux fois.
	s.pay = {"len": 1.5, "rot": {
		"spine": [[0.0, V(12)], [0.35, V(22)], [1.1, V(22)], [1.5, V(12)]],
		"arm_r": [[0.0, V(-40, 0, -6)], [0.35, V(-62, 0, 4)], [0.6, V(-82, 0, -14)], [0.8, V(-62, 0, 4)], [1.05, V(-84, 0, -20)], [1.5, V(-40, 0, -6)]],
		"forearm_r": [[0.0, V(-30)], [0.35, V(-45)], [0.6, V(-8)], [0.8, V(-45)], [1.05, V(-6)], [1.5, V(-30)]],
		"hand_r": [[0.0, V(0)], [0.35, V(-20)], [0.6, V(-20)], [1.05, V(-20)], [1.5, V(0)]],
		"head": [[0.0, V(-8)], [0.4, V(10, -8, 0)], [1.1, V(10, -8, 0)], [1.5, V(-8)]],
	}}
	s.nod = {"len": 1.0, "rot": {
		"head": [[0.0, V(0)], [0.3, V(16)], [0.6, V(0)], [1.0, V(0)]],
		"spine": [[0.0, V(0)], [0.3, V(6)], [0.6, V(0)], [1.0, V(0)]],
	}}
	s.bow = {"len": 1.6, "rot": {
		"spine": [[0.0, V(0)], [0.5, V(32)], [1.0, V(32)], [1.6, V(0)]],
		"head": [[0.0, V(0)], [0.5, V(10)], [1.0, V(10)], [1.6, V(0)]],
		"arm_r": [[0.0, V(-4, 0, -8)], [0.5, V(-45, 0, 25)], [1.0, V(-45, 0, 25)], [1.6, V(-4, 0, -8)]],
		"forearm_r": [[0.0, V(-14)], [0.5, V(-100)], [1.0, V(-100)], [1.6, V(-14)]],
	}}
	s.scratch = {"len": 2.0, "rot": {
		"arm_r": [[0.0, V(0, 0, -8)], [0.4, V(10, 0, -125)], [1.6, V(10, 0, -125)], [2.0, V(0, 0, -8)]],
		"forearm_r": [[0.0, V(-10)], [0.4, V(-110)], [0.7, V(-120)], [1.0, V(-105)], [1.3, V(-120)], [1.6, V(-110)], [2.0, V(-10)]],
		"head": [[0.0, V(0)], [0.4, V(-4, 0, -12)], [1.6, V(-4, 0, -12)], [2.0, V(0)]],
	}}
	s.look_watch = {"len": 1.8, "rot": {
		"arm_l": [[0.0, V(-4, 0, 8)], [0.4, V(-55, 0, -10)], [1.4, V(-55, 0, -10)], [1.8, V(-4, 0, 8)]],
		"forearm_l": [[0.0, V(-14)], [0.4, V(-95, -40, 0)], [1.4, V(-95, -40, 0)], [1.8, V(-14)]],
		"head": [[0.0, V(0)], [0.5, V(25, 20, 0)], [1.3, V(25, 20, 0)], [1.8, V(0)]],
	}}
	s.drink = {"len": 2.2, "rot": {
		"arm_r": [[0.0, V(0, 0, -8)], [0.5, V(-40, 0, 10)], [1.6, V(-45, 0, 12)], [2.2, V(0, 0, -8)]],
		"forearm_r": [[0.0, V(-12)], [0.5, V(-125)], [1.0, V(-135)], [1.6, V(-125)], [2.2, V(-12)]],
		"head": [[0.0, V(0)], [0.5, V(0)], [1.0, V(-18)], [1.5, V(-12)], [2.2, V(0)]],
	}}
	s.point = {"len": 1.4, "rot": {
		"arm_r": [[0.0, V(0, 0, -8)], [0.3, V(-80, 0, -20)], [1.1, V(-80, 0, -20)], [1.4, V(0, 0, -8)]],
		"forearm_r": [[0.0, V(-14)], [0.3, V(-5)], [1.1, V(-5)], [1.4, V(-14)]],
		"head": [[0.0, V(0)], [0.3, V(0, -10, 0)], [1.1, V(0, -10, 0)], [1.4, V(0)]],
	}}
	s.facepalm = {"len": 1.9, "rot": {
		"arm_r": [[0.0, V(0, 0, -8)], [0.4, V(-55, 0, 15)], [1.5, V(-55, 0, 15)], [1.9, V(0, 0, -8)]],
		"forearm_r": [[0.0, V(-14)], [0.4, V(-130, 0, 10)], [1.5, V(-130, 0, 10)], [1.9, V(-14)]],
		"head": [[0.0, V(0)], [0.4, V(22)], [0.9, V(22, -8, 0)], [1.2, V(22, 8, 0)], [1.5, V(22)], [1.9, V(0)]],
		"spine": [[0.0, V(0)], [0.4, V(10)], [1.5, V(10)], [1.9, V(0)]],
	}}

	# --- Gestes du corps entier.
	s.jump = {"len": 1.1, "rot": {
		"thigh": [[0.0, V(0)], [0.15, V(-35)], [0.4, V(-10, 0, 6)], [0.65, V(-20)], [0.78, V(-25)], [1.1, V(0)]],
		"shin": [[0.0, V(0)], [0.15, V(60)], [0.4, V(30)], [0.65, V(30)], [0.78, V(40)], [1.1, V(0)]],
		"foot": [[0.0, V(0)], [0.15, V(-25)], [0.4, V(20)], [0.65, V(-10)], [1.1, V(0)]],
		"spine": [[0.0, V(0)], [0.15, V(14)], [0.4, V(-8)], [1.1, V(0)]],
		"arm": [[0.0, V(0, 0, 8)], [0.15, V(20, 0, 10)], [0.4, V(18, 0, 132)], [0.8, V(18, 0, 122)], [1.1, V(0, 0, 8)]],
		"forearm": [[0.0, V(-10)], [0.4, V(0, 0, 25)], [0.8, V(0, 0, 25)], [1.1, V(-10)]],
		"head": [[0.0, V(0)], [0.4, V(-14)], [1.1, V(0)]],
		"hips": [[0.0, V(0)]],
		"tail": [[0.0, V(-10)], [0.4, V(-40)], [1.1, V(-10)]],
	}, "pos": {"root": [[0.0, V(0)], [0.15, V(0, -0.02, 0)], [0.4, V(0, 0.09, 0)], [0.65, V(0)], [0.78, V(0, -0.012, 0)], [1.1, V(0)]]}}
	s.stomp = {"len": 1.5, "rot": {
		"thigh_r": [[0.0, V(0)], [0.3, V(-45)], [0.45, V(0)], [1.5, V(0)]],
		"shin_r": [[0.0, V(0)], [0.3, V(60)], [0.45, V(0)], [1.5, V(0)]],
		"thigh_l": [[0.0, V(0)]], "shin_l": [[0.0, V(0)]],
		"arm": [[0.0, V(-4, 0, 8)], [0.3, V(10, 0, -4)], [0.45, V(16, 0, -2)], [1.2, V(10, 0, -2)], [1.5, V(0, 0, 8)]],
		"forearm": [[0.0, V(-14)], [0.45, V(-30)], [1.2, V(-30)], [1.5, V(-14)]],
		"spine": [[0.0, V(0)], [0.45, V(16)], [1.2, V(14)], [1.5, V(0)]],
		"head": [[0.0, V(0)], [0.45, V(20)], [0.7, V(20, -15, 0)], [0.95, V(20, 15, 0)], [1.2, V(20)], [1.5, V(0)]],
		"hips": [[0.0, V(0)]],
	}, "pos": {"root": [[0.0, V(0)], [0.3, V(0, 0.01, 0)], [0.45, V(0, -0.006, 0)], [0.6, V(0)], [1.5, V(0)]]}}
	return s
