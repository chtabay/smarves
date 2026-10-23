extends Node3D
## Un habitant de Smarves, un adulte de bande dessinée en ligne claire (voir docs/PERSONNAGES.md).
## Le corps vient de sa fiche (Cast, CritterMesh), les mouvements de la bibliothèque commune (CritterAnims) ;
## le visage (clignements, sourire, moue, bouche qui parle, sourcils) et le regard sont tenus ici, par le code.
## Il regarde +Z ; environ 0,7 de haut à l'échelle 1.

enum Pose { IDLE, WALK, SIT, CHEER, SULK }

## Sa fiche (voir Cast) ; vide = tirée au hasard.
var look: Dictionary = {}
## La pose de fond au repos et assis (voir CritterAnims.BASE).
var idle_anim := "idle"
var sit_anim := "sit"
## Vitesse de marche de référence (unités par seconde à l'échelle 1) et seuil de course.
var walk_speed := 0.6
var run_speed := 1.1

var pose := Pose.IDLE:
	set = set_pose

var skeleton: Skeleton3D
var body: MeshInstance3D
var tree: AnimationTree
var height := 0.75

var _rest: Array = []
var _hip_y := 0.18
## La taille du visage (les sourcils bougent moins sur une petite tête) et la hauteur d'assise.
var _face_scale := 1.0
var _seat := 0.09
var _look_mod: LookAtModifier3D
var _look_target: Marker3D
var _look_weight := 0.0
var _look_goal := 0.0
var _base := ""
var _speed := 0.0
var _last_pos := Vector3.INF
var _sit := 0.0
var _seed := 0
var _forced := ""

# Le visage.
var _blink := 0.0
var _blink_wait := 3.0
var _expr := "neutre"
var _expr_time := 0.0
var _talk := 0.0
var _face := {"smile": 1.0, "frown": 0.0, "mouth": 0.0, "brow": 0.0, "brow_up": 0.0, "eye": 1.0}
var _t := 0.0

# Mise à jour économe : plus loin, moins souvent ; hors champ, presque jamais.
var _lod_wait := 0.0
var _step := 1
var _frame := 0
var _acc := 0.0
var _on_screen := true

const EXPRESSIONS := {
	"neutre": {"smile": 1.0, "frown": 0.0, "mouth": 0.0, "brow": 0.0, "brow_up": 0.0, "eye": 1.0},
	"joie": {"smile": 1.3, "frown": 0.0, "mouth": 0.8, "brow": 0.1, "brow_up": 0.012, "eye": 0.72},
	"depit": {"smile": 0.0, "frown": 1.0, "mouth": 0.0, "brow": -0.4, "brow_up": 0.005, "eye": 0.82},
	"surprise": {"smile": 0.15, "frown": 0.0, "mouth": 1.0, "brow": 0.15, "brow_up": 0.02, "eye": 1.15},
	"attention": {"smile": 0.7, "frown": 0.0, "mouth": 0.0, "brow": 0.18, "brow_up": -0.003, "eye": 0.95},
}


## Tire un habitant au hasard, à partir d'une graine (pour qu'un même nom donne toujours le même).
func randomize_look(seed_value: int) -> void:
	_seed = seed_value
	look = Cast.resolve("", "habitant", "", seed_value, "idle", false).look


func _ready() -> void:
	if look.is_empty():
		randomize_look(randi())
	_t = randf() * 10.0
	_blink_wait = randf_range(1.0, 4.0)
	_build()


## Change d'habit (le joueur au vestiaire, par exemple) sans perdre sa pose.
func set_look(l: Dictionary) -> void:
	look = l
	if skeleton:
		# Retirés de l'arbre tout de suite : les mouvements visent « Skeleton3D » par son nom, et le nouveau
		# squelette, posé à côté de l'ancien encore là, s'appellerait autrement et resterait raide, debout
		# même assis (retour de l'auteur de Chauvigny).
		for n in [skeleton, tree, _look_target]:
			remove_child(n)
			n.queue_free()
		skeleton = null
		_base = ""
		_build()


func _build() -> void:
	var data := CritterMesh.build(look)
	_rest = data.rest
	height = data.height
	_hip_y = _rest[CritterMesh.HIPS].y
	_face_scale = data.get("face", 1.0)
	_seat = maxf(0.09, lerpf(0.09, float(data.leg) * 0.5 + 0.02, 0.5))
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	for i in CritterMesh.BONES.size():
		skeleton.add_bone(CritterMesh.BONES[i][0])
	for i in CritterMesh.BONES.size():
		var parent: int = CritterMesh.BONES[i][1]
		skeleton.set_bone_parent(i, parent)
		var local: Vector3 = _rest[i] - (_rest[parent] if parent >= 0 else Vector3.ZERO)
		skeleton.set_bone_rest(i, Transform3D(Basis(), local))
	skeleton.reset_bone_poses()
	add_child(skeleton)
	body = MeshInstance3D.new()
	body.mesh = data.mesh
	body.skin = data.skin
	skeleton.add_child(body)
	body.skeleton = NodePath("..")
	for b in [CritterMesh.FROWN, CritterMesh.MOUTH]:
		skeleton.set_bone_pose_scale(b, Vector3.ONE * 0.001)
	# Le regard : la tête se tourne vers un point, en douceur et sans dévisser.
	_look_target = Marker3D.new()
	_look_target.top_level = true
	add_child(_look_target)
	_look_mod = LookAtModifier3D.new()
	_look_mod.bone_name = "head"
	_look_mod.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	_look_mod.primary_rotation_axis = Vector3.AXIS_Y
	_look_mod.use_angle_limitation = true
	_look_mod.symmetry_limitation = true
	_look_mod.primary_limit_angle = deg_to_rad(150.0)
	_look_mod.primary_damp_threshold = 0.6
	_look_mod.secondary_limit_angle = deg_to_rad(70.0)
	_look_mod.secondary_damp_threshold = 0.6
	_look_mod.duration = 0.35
	_look_mod.transition_type = Tween.TRANS_SINE
	_look_mod.ease_type = Tween.EASE_IN_OUT
	_look_mod.influence = 0.0
	skeleton.add_child(_look_mod)
	_look_mod.target_node = _look_mod.get_path_to(_look_target)
	tree = AnimationTree.new()
	tree.add_animation_library("", CritterAnims.library())
	tree.tree_root = CritterAnims.tree_root()
	tree.deterministic = false
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(tree)
	tree.active = true
	_play_base(_wanted_base(), true)
	tree.set("parameters/seek/seek_request", randf() * 3.0)
	tree.advance(0.0)


# --- Poses et gestes -------------------------------------------------------------------------

func set_pose(p: Pose) -> void:
	match p:
		Pose.CHEER:
			cheer()
			return
		Pose.SULK:
			gesture("sulk")
			set_expression("depit", 1.6)
			return
	pose = p


func _wanted_base() -> String:
	if _forced != "":
		return _forced
	match pose:
		Pose.SIT:
			return sit_anim
		Pose.WALK:
			if _speed > run_speed:
				return "run"
			if _speed > 0.05:
				return "walk"
	return idle_anim


func _play_base(name: String, now := false) -> void:
	if name == _base or tree == null:
		return
	_base = name
	tree.set("parameters/base/transition_request", name)
	if now:
		tree.advance(0.31)


## Un geste par-dessus la pose de fond : talk, wave, cheer, sulk, shrug, clap, bet, deal, spin, rake, nod, bow,
## scratch, look_watch, drink, point, facepalm ; ou du corps entier, debout : jump, stomp.
func gesture(name: String) -> void:
	if tree == null:
		return
	if name in CritterAnims.FULL:
		if pose == Pose.SIT or _speed > 0.05:
			name = {"jump": "cheer", "stomp": "sulk"}[name]
		else:
			tree.set("parameters/fullg/transition_request", name)
			tree.set("parameters/full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			return
	if name in CritterAnims.GESTURES:
		tree.set("parameters/gest/transition_request", name)
		tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func is_busy() -> bool:
	return tree != null and (bool(tree.get("parameters/shot/active")) or bool(tree.get("parameters/full/active")))


## La joie : un saut debout, les bras levés assis.
func cheer(duration := 1.6) -> void:
	gesture("jump" if duration > 0.8 else "cheer")
	set_expression("joie", maxf(duration, 1.2))


func set_expression(name: String, duration := 0.0) -> void:
	_expr = name if EXPRESSIONS.has(name) else "neutre"
	_expr_time = duration


## La bouche bouge pendant qu'il parle.
func talk(duration: float) -> void:
	_talk = duration


## Tourne la tête vers un point (weight 0 à 1) ; weight 0 la ramène.
func look_at_point(p: Vector3, weight := 1.0) -> void:
	if _look_target:
		_look_target.global_position = p
	_look_goal = weight


func clear_look() -> void:
	_look_goal = 0.0


# --- Chaque image ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if tree == null:
		return
	_t += delta
	var gp := global_position
	var sc := maxf(0.01, global_basis.get_scale().y)
	if _last_pos != Vector3.INF and delta > 0.0:
		var d := gp - _last_pos
		d.y = 0.0
		_speed = lerpf(_speed, d.length() / delta / sc, 1.0 - exp(-12.0 * delta))
	_last_pos = gp
	_lod(delta, gp, sc)
	_frame += 1
	_acc += delta
	if (_frame % _step) != 0:
		return
	var dt := minf(_acc, 0.25)
	_acc = 0.0
	_play_base(_wanted_base())
	if _base == "walk":
		tree.set("parameters/speed/scale", clampf(_speed / walk_speed, 0.6, 1.6))
	elif _base == "run":
		tree.set("parameters/speed/scale", clampf(_speed / (walk_speed * 2.3), 0.8, 1.5))
	else:
		tree.set("parameters/speed/scale", 1.0)
	tree.advance(dt)
	# Assis : le corps descend sur la chaise.
	var sit_goal := (_hip_y - _seat) if pose == Pose.SIT else 0.0
	_sit = lerpf(_sit, sit_goal, 1.0 - exp(-8.0 * dt))
	skeleton.position.y = -_sit
	_look_weight = move_toward(_look_weight, _look_goal, dt * 2.5)
	_look_mod.influence = _look_weight
	_look_mod.active = _look_weight > 0.001
	if _step <= 2:
		_update_face(dt)


func _lod(delta: float, gp: Vector3, sc: float) -> void:
	_lod_wait -= delta
	if _lod_wait > 0.0:
		return
	_lod_wait = 0.3 + randf() * 0.1
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_step = 1
		return
	var dist := cam.global_position.distance_to(gp) / sc
	_on_screen = cam.is_position_in_frustum(gp + Vector3.UP * 0.4 * sc)
	if not _on_screen:
		_step = 8
	elif dist < 7.0:
		_step = 1
	elif dist < 16.0:
		_step = 2
	else:
		_step = 3


func _update_face(dt: float) -> void:
	if _expr_time > 0.0:
		_expr_time -= dt
		if _expr_time <= 0.0:
			_expr = "neutre"
	var goal: Dictionary = EXPRESSIONS[_expr]
	var k := 1.0 - exp(-10.0 * dt)
	for key in _face:
		_face[key] = lerpf(_face[key], goal[key], k)
	var mouth: float = _face.mouth
	if _talk > 0.0:
		_talk -= dt
		mouth = maxf(mouth, 0.2 + 0.65 * absf(sin(_t * 13.0) * sin(_t * 4.7 + 1.0)))
	# Les clignements.
	_blink_wait -= dt
	if _blink_wait <= 0.0:
		_blink = 0.13
		_blink_wait = randf_range(2.0, 5.5)
	var eye: float = _face.eye
	if _blink > 0.0:
		_blink -= dt
		eye = 0.08
	var S := CritterMesh
	skeleton.set_bone_pose_scale(S.SMILE, Vector3.ONE * maxf(0.001, _face.smile))
	skeleton.set_bone_pose_scale(S.FROWN, Vector3.ONE * maxf(0.001, _face.frown))
	skeleton.set_bone_pose_scale(S.MOUTH, Vector3(1.0, maxf(0.001, mouth), 1.0) * (0.001 if mouth < 0.02 else 1.0))
	for side in [1.0, -1.0]:
		skeleton.set_bone_pose_scale(S.EYE_L if side > 0 else S.EYE_R, Vector3(1.0, eye, 1.0))
		var b := S.BROW_L if side > 0 else S.BROW_R
		skeleton.set_bone_pose_rotation(b, Quaternion(Vector3.BACK, side * _face.brow))
		skeleton.set_bone_pose_position(b, skeleton.get_bone_rest(b).origin + Vector3(0, _face.brow_up * _face_scale, 0))


## Pour les planches et les captures : force une pose, un geste ou une expression.
func debug_anim(what: String) -> void:
	if what in CritterAnims.BASE:
		idle_anim = what
		sit_anim = what if what in ["sit", "sit_table", "piano"] else sit_anim
		if what in ["sit", "sit_table", "piano"]:
			pose = Pose.SIT
		_forced = what
		_play_base(what, true)
	elif what in EXPRESSIONS:
		set_expression(what, 100.0)
	else:
		gesture(what)
