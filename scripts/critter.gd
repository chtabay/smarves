extends Node3D
## Un habitant de Smarves, façon Happy Tree Friends : grosse tête ronde, grands yeux brillants,
## petit corps fin, oreilles d'animal. Animé par le code (respiration, marche, assis, joie, dépit).
## Il regarde +Z ; hauteur totale environ 0,72 à l'échelle 1.

enum Pose { IDLE, WALK, SIT, CHEER, SULK }

const SPECIES := ["ours", "lapin", "chat", "souris", "renard", "castor"]
const FURS := [Color(0.98, 0.72, 0.42), Color(0.72, 0.85, 1.0), Color(1.0, 0.78, 0.86), Color(0.8, 0.95, 0.7),
	Color(0.85, 0.75, 1.0), Color(1.0, 0.92, 0.55), Color(0.95, 0.55, 0.45), Color(0.75, 0.62, 0.5)]
const OUTFITS := [Color(0.85, 0.15, 0.2), Color(0.15, 0.3, 0.75), Color(0.12, 0.12, 0.16), Color(0.95, 0.95, 0.92),
	Color(0.2, 0.55, 0.35), Color(0.55, 0.2, 0.6), Color(0.95, 0.6, 0.15)]

@export var species := "ours"
@export var fur := Color(0.98, 0.72, 0.42)
@export var outfit := Color(0.85, 0.15, 0.2)
## "", "noeud" (croupier), "cravate" (banquier), "chapeau", "collier"
@export var accessory := ""

var pose := Pose.IDLE
var _t := randf() * 10.0
var _body: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _cheer_time := 0.0


## Tire un habitant au hasard, à partir d'une graine (pour qu'un même nom donne toujours le même).
func randomize_look(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	species = SPECIES[rng.randi() % SPECIES.size()]
	fur = FURS[rng.randi() % FURS.size()]
	outfit = OUTFITS[rng.randi() % OUTFITS.size()]


func _ready() -> void:
	var fur_m := _mat(fur, 0.65)
	var light_fur := _mat(fur.lerp(Color.WHITE, 0.55), 0.7)
	var cloth := _mat(outfit, 0.55)
	var dark := _mat(Color(0.08, 0.06, 0.08), 0.3)
	var white := _mat(Color(1, 1, 1), 0.15)
	var pink := _mat(Color(1.0, 0.55, 0.65), 0.8)

	_body = Node3D.new()
	add_child(_body)
	# Jambes fines et petites chaussures.
	_leg_l = _limb(_body, Vector3(-0.045, 0.2, 0), 0.026, 0.19, fur_m)
	_leg_r = _limb(_body, Vector3(0.045, 0.2, 0), 0.026, 0.19, fur_m)
	for leg in [_leg_l, _leg_r]:
		var shoe := _sphere(leg, Vector3(0, -0.19, 0.02), Vector3(0.045, 0.03, 0.065), dark)
		shoe.name = "Shoe"
	# Le corps : un petit tronc en poire habillé.
	_sphere(_body, Vector3(0, 0.3, 0), Vector3(0.085, 0.12, 0.07), cloth)
	_sphere(_body, Vector3(0, 0.25, 0.0), Vector3(0.095, 0.07, 0.08), cloth)
	# Bras fins, mains rondes.
	_arm_l = _limb(_body, Vector3(-0.085, 0.38, 0), 0.02, 0.17, cloth)
	_arm_r = _limb(_body, Vector3(0.085, 0.38, 0), 0.02, 0.17, cloth)
	for arm in [_arm_l, _arm_r]:
		_sphere(arm, Vector3(0, -0.18, 0), Vector3(0.03, 0.03, 0.03), fur_m)
	# La tête : grosse, ronde, un museau clair, des joues roses.
	_head = Node3D.new()
	_head.position = Vector3(0, 0.56, 0)
	_body.add_child(_head)
	_sphere(_head, Vector3(0, 0, 0), Vector3(0.165, 0.155, 0.15), fur_m)
	_sphere(_head, Vector3(0, -0.05, 0.11), Vector3(0.07, 0.05, 0.05), light_fur)
	_sphere(_head, Vector3(0, -0.025, 0.155), Vector3(0.018, 0.014, 0.012), dark)
	for s in [-1.0, 1.0]:
		_sphere(_head, Vector3(s * 0.1, -0.05, 0.105), Vector3(0.025, 0.015, 0.01), pink)
		# Grands yeux : blanc, pupille, reflet.
		_sphere(_head, Vector3(s * 0.058, 0.02, 0.118), Vector3(0.048, 0.058, 0.03), white)
		_sphere(_head, Vector3(s * 0.054, 0.012, 0.142), Vector3(0.028, 0.036, 0.012), dark)
		var glint := _sphere(_head, Vector3(s * 0.045 + 0.008, 0.03, 0.152), Vector3(0.009, 0.009, 0.004), white)
		glint.material_override = _glow()
	# La bouche : un petit sourire.
	var smile := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.018
	tm.outer_radius = 0.024
	tm.rings = 12
	smile.mesh = tm
	smile.material_override = dark
	smile.position = Vector3(0, -0.075, 0.143)
	smile.rotation_degrees = Vector3(90, 0, 0)
	smile.scale = Vector3(1, 1, 0.4)
	_head.add_child(smile)
	_ears(fur_m, pink)
	_accessory(dark, cloth)


func _ears(fur_m: Material, pink: Material) -> void:
	match species:
		"lapin":
			for s in [-1.0, 1.0]:
				var e := _sphere(_head, Vector3(s * 0.06, 0.2, -0.01), Vector3(0.035, 0.11, 0.025), fur_m)
				e.rotation_degrees.z = s * -12.0
				_sphere(e, Vector3(0, 0, 0.6), Vector3(0.55, 0.8, 0.3), pink)
		"chat", "renard":
			for s in [-1.0, 1.0]:
				var e := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.0
				c.bottom_radius = 0.06
				c.height = 0.11 if species == "chat" else 0.14
				c.radial_segments = 4
				e.mesh = c
				e.material_override = fur_m
				e.position = Vector3(s * 0.1, 0.14, 0)
				e.rotation_degrees = Vector3(0, 45, s * -22.0)
				_head.add_child(e)
		"souris":
			for s in [-1.0, 1.0]:
				var e := _sphere(_head, Vector3(s * 0.13, 0.12, -0.02), Vector3(0.075, 0.075, 0.02), fur_m)
				_sphere(e, Vector3(0, 0, 0.6), Vector3(0.7, 0.7, 0.4), pink)
		"castor":
			for s in [-1.0, 1.0]:
				_sphere(_head, Vector3(s * 0.12, 0.11, 0), Vector3(0.035, 0.035, 0.02), fur_m)
			var teeth := _sphere(_head, Vector3(0, -0.09, 0.15), Vector3(0.022, 0.02, 0.008), _mat(Color.WHITE, 0.3))
			teeth.name = "Teeth"
		_:
			for s in [-1.0, 1.0]:
				_sphere(_head, Vector3(s * 0.115, 0.12, -0.01), Vector3(0.05, 0.05, 0.03), fur_m)


func _accessory(dark: Material, cloth: Material) -> void:
	match accessory:
		"noeud":
			for s in [-1.0, 1.0]:
				var b := _sphere(_body, Vector3(s * 0.022, 0.415, 0.062), Vector3(0.022, 0.016, 0.01), dark)
				b.rotation_degrees.z = s * 20.0
		"cravate":
			_sphere(_body, Vector3(0, 0.36, 0.07), Vector3(0.012, 0.05, 0.008), _mat(Color(0.75, 0.1, 0.15), 0.4))
		"chapeau":
			var brim := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.16
			c.bottom_radius = 0.16
			c.height = 0.01
			brim.mesh = c
			brim.material_override = dark
			brim.position = Vector3(0, 0.12, 0)
			_head.add_child(brim)
			var top := MeshInstance3D.new()
			var t := CylinderMesh.new()
			t.top_radius = 0.09
			t.bottom_radius = 0.1
			t.height = 0.12
			top.mesh = t
			top.material_override = dark
			top.position = Vector3(0, 0.18, 0)
			_head.add_child(top)
		"collier":
			for k in 9:
				var a := PI * (k / 8.0)
				_sphere(_body, Vector3(cos(a) * 0.06, 0.415 - sin(a) * 0.03, 0.04 + sin(a) * 0.02), Vector3(0.008, 0.008, 0.008), _mat(Color(0.98, 0.95, 0.9), 0.1))


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.25
	return m


var _glint_mat: StandardMaterial3D


func _glow() -> StandardMaterial3D:
	if _glint_mat == null:
		_glint_mat = StandardMaterial3D.new()
		_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glint_mat.albedo_color = Color(1, 1, 1)
	return _glint_mat


func _sphere(parent: Node3D, pos: Vector3, radii: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 20
	s.rings = 10
	m.mesh = s
	m.scale = radii
	m.position = pos
	m.material_override = mat
	parent.add_child(m)
	return m


## Un membre qui pivote à son attache (épaule, hanche) : l'origine est en haut.
func _limb(parent: Node3D, pivot: Vector3, r: float, length: float, mat: Material) -> Node3D:
	var root := Node3D.new()
	root.position = pivot
	parent.add_child(root)
	var m := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = length
	c.radial_segments = 10
	m.mesh = c
	m.material_override = mat
	m.position = Vector3(0, -length / 2.0, 0)
	root.add_child(m)
	return root


func cheer(duration := 1.6) -> void:
	_cheer_time = duration


func _process(delta: float) -> void:
	_t += delta
	var swing := 0.0
	_body.position = Vector3.ZERO
	_head.rotation = Vector3.ZERO
	match pose:
		Pose.WALK:
			swing = sin(_t * 9.0) * 0.6
			_body.position.y = absf(sin(_t * 9.0)) * 0.015
			_leg_l.rotation.x = swing
			_leg_r.rotation.x = -swing
			_arm_l.rotation = Vector3(-swing * 0.8, 0, -0.12)
			_arm_r.rotation = Vector3(swing * 0.8, 0, 0.12)
		Pose.SIT:
			_body.position.y = -0.11
			_leg_l.rotation.x = -1.45
			_leg_r.rotation.x = -1.45
			_arm_l.rotation = Vector3(-0.6, 0, -0.1)
			_arm_r.rotation = Vector3(-0.6 + sin(_t * 1.3) * 0.15, 0, 0.1)
			_head.rotation.z = sin(_t * 0.7) * 0.06
		Pose.SULK:
			_head.rotation.x = 0.35
			_arm_l.rotation = Vector3(0, 0, -0.05)
			_arm_r.rotation = Vector3(0, 0, 0.05)
			_leg_l.rotation.x = 0.0
			_leg_r.rotation.x = 0.0
		_:
			_body.position.y = sin(_t * 2.0) * 0.004
			_head.rotation.z = sin(_t * 0.9) * 0.05
			_head.rotation.x = sin(_t * 0.6) * 0.04
			_leg_l.rotation.x = 0.0
			_leg_r.rotation.x = 0.0
			_arm_l.rotation = Vector3(sin(_t * 1.1) * 0.05, 0, -0.15)
			_arm_r.rotation = Vector3(-sin(_t * 1.1) * 0.05, 0, 0.15)
	if _cheer_time > 0.0:
		_cheer_time -= delta
		var hop := absf(sin(_cheer_time * 10.0))
		_arm_l.rotation = Vector3(0, 0, -2.6 - hop * 0.3)
		_arm_r.rotation = Vector3(0, 0, 2.6 + hop * 0.3)
		if pose != Pose.SIT:
			_body.position.y += hop * 0.05
