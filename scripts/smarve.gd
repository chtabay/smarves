extends Node3D
## Un smarve : va au filon, pioche, rapporte le minerai à la caisse du Seuil.

signal delivered(amount: int, at: Vector3)

enum State { TO_ORE, MINING, TO_CRATE, UNLOADING }

const WALK_SPEED := 1.4
const MINE_TIME := 2.4
const UNLOAD_TIME := 0.8

var game: Node
var model_path := "res://assets/kenney/characters/character-male-b.glb"
var lane_z := -0.5

var state := State.TO_ORE
var ore: Node3D
var target := Vector3.ZERO
var timer := 0.0
var carrying := 0
var anim: AnimationPlayer
var sack: Node3D


func _ready() -> void:
	var model: Node3D = load(model_path).instantiate()
	# Plus trapu qu'un humain : c'est un nain.
	model.scale = Vector3(1.2, 1.0, 1.2)
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	for a in ["walk", "idle", "attack-melee-right", "pick-up"]:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR if a != "pick-up" else Animation.LOOP_NONE

	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var hand := BoneAttachment3D.new()
	hand.bone_name = "arm-right"
	skel.add_child(hand)
	var pick: Node3D = load("res://assets/kenney/survival/tool-pickaxe.glb").instantiate()
	pick.scale = Vector3.ONE * 1.6
	pick.position = Vector3(-0.05, -0.12, 0.08)
	pick.rotation_degrees = Vector3(90, 0, 0)
	hand.add_child(pick)

	# Lanterne au casque : la seule lumière qu'un smarve emporte.
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.68, 0.35)
	lantern.light_energy = 0.7
	lantern.omni_range = 1.8
	lantern.position = Vector3(0, 0.95, 0.25)
	lantern.light_volumetric_fog_energy = 0.6
	add_child(lantern)

	# Le sac de minerai, visible seulement au retour.
	sack = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.22
	sack.mesh = sm
	sack.material_override = game.ore_material
	sack.position = Vector3(0, 0.55, -0.2)
	sack.visible = false
	add_child(sack)

	_go_to_ore()


func _go_to_ore() -> void:
	ore = game.pick_ore()
	target = Vector3(ore.position.x + randf_range(-0.35, 0.35), 0, lane_z)
	state = State.TO_ORE
	_play("walk")


func _process(delta: float) -> void:
	match state:
		State.TO_ORE, State.TO_CRATE:
			var to := target - position
			to.y = 0
			if to.length() < 0.05:
				_arrive()
			else:
				var step := minf(WALK_SPEED * delta, to.length())
				position += to.normalized() * step
				rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 10.0 * delta)
		State.MINING:
			timer -= delta
			rotation.y = lerp_angle(rotation.y, PI, 8.0 * delta)
			if timer <= 0.0:
				carrying = game.pick_power()
				game.on_ore_hit(ore, false)
				sack.visible = true
				target = game.crate_drop_point(lane_z)
				state = State.TO_CRATE
				_play("walk")
		State.UNLOADING:
			timer -= delta
			if timer <= 0.0:
				delivered.emit(carrying, global_position + Vector3(0, 1, 0))
				carrying = 0
				sack.visible = false
				_go_to_ore()


func _arrive() -> void:
	if state == State.TO_ORE:
		state = State.MINING
		timer = MINE_TIME * randf_range(0.85, 1.15)
		_play("attack-melee-right")
	else:
		state = State.UNLOADING
		timer = UNLOAD_TIME
		_play("pick-up")


func _play(a: String) -> void:
	if anim and anim.has_animation(a):
		anim.play(a, 0.15)
