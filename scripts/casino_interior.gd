extends Node3D
## L'intérieur du Casino de Smarves, sur le modèle d'Addict : sas, hall d'honneur avec réception et
## vestiaire, bar Le Nocturne, salle des jeux ; la Salle des Ambassadeurs et le salon privé s'ouvrent
## par des seuils de gains. On y marche à la première personne. 1 unité = 1 mètre.

const PLAYER := preload("res://scripts/fp_player.gd")
const VILLAGER := preload("res://scripts/villager.gd")
const SLOT := preload("res://scripts/slot_machine.gd")
const ROULETTE := preload("res://scripts/roulette_panel.gd")
const BLACKJACK := preload("res://scripts/blackjack_panel.gd")
const BACCARA := preload("res://scripts/baccara_panel.gd")
const DICE := preload("res://scripts/dice_panel.gd")
const CRAPS := preload("res://scripts/craps_panel.gd")
const WHEEL := preload("res://scripts/wheel_panel.gd")
const POKER := preload("res://scripts/poker_panel.gd")
## Niveau du plancher de l'étage.
const UP := 6.1
const KC := "res://assets/kenney/characters/"
const KK := "res://assets/kaykit/"
const WALL_H := 6.0
## Les petits habitants de Smarves, grandis à taille humaine (1,7 m).
const PEOPLE_SCALE := 2.6

## Pièces fermées par un seuil sur le total gagné au jeu (comme dans Addict, tuning.js).
const LOCKS := [
	{"id": "ambassadeurs", "name": "La Salle des Ambassadeurs", "seuil": 500, "host": "L'inspecteur de salle"},
	{"id": "salon", "name": "Le Salon privé", "seuil": 5000, "host": "Monsieur Armand"},
	{"id": "loggia", "name": "La Loggia", "seuil": 2000, "host": "Le chef de partie"},
	{"id": "musique", "name": "Le Salon de musique", "seuil": 10000, "host": "Le pianiste"},
	{"id": "fetes", "name": "La Salle des fêtes", "seuil": 50000, "on": "staked", "host": "Le maître de cérémonie"},
	{"id": "particuliers", "name": "Les Salons particuliers", "seuil": 100000, "host": "Monsieur Castel"},
]

## Les pièces, pour afficher leur nom quand on y entre : [nom, x0, x1, z0, z1].
const ROOMS := [
	["Le sas", -3.0, 3.0, 18.0, 22.0],
	["Le Hall d'honneur", -10.0, 10.0, 6.0, 18.0],
	["Le Nocturne", 10.0, 20.0, 6.0, 18.0],
	["La Salle des jeux", -14.0, 14.0, -14.0, 6.0],
	["La Salle des Ambassadeurs", 14.0, 26.0, -14.0, 6.0],
	["Le Salon privé", -26.0, -14.0, -14.0, 0.0],
	["La Galerie de la Verrière", -7.0, 7.0, -9.0, 6.0, 1],
	["Le Bar du Fumoir", -14.0, -7.0, -14.0, 6.0, 1],
	["Restaurant Le Lustre", -7.0, 7.0, -14.0, -9.0, 1],
	["La Loggia", 7.0, 14.0, -2.0, 6.0, 1],
	["La galerie du hall", -10.0, 10.0, 6.0, 18.0, 1],
	["La Salle des fêtes", 14.0, 26.0, -14.0, -7.0, 1],
	["Le Salon de musique", 14.0, 26.0, -7.0, -1.0, 1],
	["Les Salons particuliers", 14.0, 26.0, -1.0, 6.0, 1],
]

var serif: SystemFont
var gold: StandardMaterial3D
var wood: StandardMaterial3D
var dark_wood: StandardMaterial3D
var marble_white: StandardMaterial3D
var felt: StandardMaterial3D
var velvet: StandardMaterial3D
var brass_glow: StandardMaterial3D
var chrome: StandardMaterial3D
var floor_marble: ShaderMaterial
var carpet: ShaderMaterial
var carpet_blue: ShaderMaterial
var damask: ShaderMaterial
var ceiling: StandardMaterial3D

var player: CharacterBody3D
var barriers := {}
var _panel_layer: CenterContainer
var _active_panel: Control
var _credits_label: Label
var _won_label: Label
var _prompt: Label
var _banner: Label
var _room_label: Label
var _current_room := ""
var _shown := 0.0


func _ready() -> void:
	randomize()
	_materials()
	_environment()
	_build_shell()
	_build_hall()
	_build_bar()
	_build_games_room()
	_build_ambassadeurs()
	_build_salon()
	_build_upper()
	_build_ui()
	player = PLAYER.new()
	player.position = Vector3(0, 0, 20.5)
	player.rotation.y = 0.0
	add_child(player)
	player.interact.connect(_on_interact)
	_shown = Game.credits
	_refresh_locks(true)
	_maybe_capture()


# --- Matériaux ------------------------------------------------------------------

func _std(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _shader(path: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _materials() -> void:
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"])
	gold = _std(Color(1.0, 0.76, 0.36), 0.28, 1.0)
	chrome = _std(Color(0.85, 0.85, 0.88), 0.15, 1.0)
	# Acajou : un bruit étiré en long fait le fil du bois.
	var n := FastNoiseLite.new()
	n.frequency = 0.02
	n.fractal_octaves = 3
	var grain := NoiseTexture2D.new()
	grain.width = 512
	grain.height = 64
	grain.seamless = true
	grain.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.6, 0.6))
	g.set_color(1, Color(1, 1, 1))
	grain.color_ramp = g
	wood = _std(Color(0.42, 0.17, 0.08), 0.35)
	wood.albedo_texture = grain
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(0.5, 4.0, 0.5)
	dark_wood = wood.duplicate()
	dark_wood.albedo_color = Color(0.22, 0.09, 0.05)
	marble_white = _std(Color(0.92, 0.9, 0.86), 0.12)
	felt = _std(Color(0.03, 0.3, 0.16), 1.0)
	velvet = _std(Color(0.5, 0.03, 0.08), 0.85)
	brass_glow = _std(Color(1.0, 0.85, 0.6), 0.3)
	brass_glow.emission_enabled = true
	brass_glow.emission = Color(1.0, 0.72, 0.4)
	brass_glow.emission_energy_multiplier = 5.0
	floor_marble = _shader("res://shaders/marble_checker.gdshader", {"tile": 1.0})
	carpet = _shader("res://shaders/carpet.gdshader")
	carpet_blue = _shader("res://shaders/carpet.gdshader", {"base_col": Color(0.05, 0.08, 0.25), "deep_col": Color(0.02, 0.03, 0.1)})
	damask = _shader("res://shaders/damask.gdshader")
	ceiling = _std(Color(0.16, 0.07, 0.05), 0.6)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.015, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.38, 0.25)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 1.2
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.9, 0.8, 0.7)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# --- Briques de construction -------------------------------------------------------

func _box(size: Vector3, pos: Vector3, mat: Material, collide := false, parent: Node = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		m.add_child(body)
	return m


func _cyl(r: float, h: float, pos: Vector3, mat: Material, parent: Node = self, r_top := -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r if r_top < 0.0 else r_top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 32
	m.mesh = c
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


func _bill(l: Label3D) -> Label3D:
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	return l


func _label(text: String, pos: Vector3, rot_y: float, size := 64, color := Color(1.0, 0.85, 0.5), parent: Node = self) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = serif
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.position = pos
	l.rotation_degrees.y = rot_y
	parent.add_child(l)
	return l


func _place(path: String, pos: Vector3, scale := 1.0, rot_y := 0.0) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scale
	n.rotation_degrees.y = rot_y
	add_child(n)
	return n


func _interactive(node: Node3D, kind: String, prompt: String, size: Vector3, offset := Vector3.ZERO) -> Area3D:
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = offset
	a.add_child(cs)
	a.set_meta("interact", kind)
	a.set_meta("prompt", prompt)
	node.add_child(a)
	return a


func _person(model: String, pos: Vector3, rot_y: float, pose := "idle", acc := "") -> Node3D:
	var v: Node3D = VILLAGER.new()
	v.accessory = acc
	v.model_path = KC + model
	v.pose = pose
	v.position = pos
	v.rotation_degrees.y = rot_y
	v.scale = Vector3.ONE * PEOPLE_SCALE
	add_child(v)
	return v


## Un mur avec lambris d'acajou en bas, tenture damassée au-dessus, plinthe et corniche dorées.
## Les ouvertures sont données comme [centre le long du mur, largeur, hauteur].
func _wall(a: Vector3, b: Vector3, openings: Array = [], h := WALL_H, y0 := 0.0) -> void:
	var length := a.distance_to(b)
	var dir := (b - a).normalized()
	var normal_rot := atan2(dir.x, dir.z)
	var cuts := openings.duplicate()
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var start := 0.0
	var pieces := []
	for o in cuts:
		pieces.append([start, o[0] - o[1] / 2.0, h, 0.0])
		pieces.append([o[0] - o[1] / 2.0, o[0] + o[1] / 2.0, h - o[2], o[2]])  # linteau au-dessus de l'ouverture
		start = o[0] + o[1] / 2.0
	pieces.append([start, length, h, 0.0])
	for p in pieces:
		var w: float = p[1] - p[0]
		if w <= 0.01 or p[2] <= 0.01:
			continue
		var mid: float = (p[0] + p[1]) / 2.0
		var base: float = p[3]
		var center := a + dir * mid
		var seg := Node3D.new()
		seg.position = center + Vector3(0, y0, 0)
		seg.rotation.y = normal_rot + PI / 2.0
		add_child(seg)
		_box(Vector3(w, p[2], 0.2), Vector3(0, base + p[2] / 2.0, 0), damask, true, seg)
		if base == 0.0:
			for side in [-1.0, 1.0]:
				_box(Vector3(w, 1.15, 0.06), Vector3(0, 0.575, side * 0.13), wood, false, seg)
				_box(Vector3(w, 0.05, 0.08), Vector3(0, 1.17, side * 0.14), gold, false, seg)
				_box(Vector3(w, 0.14, 0.08), Vector3(0, 0.07, side * 0.14), dark_wood, false, seg)
		for side in [-1.0, 1.0]:
			_box(Vector3(w, 0.22, 0.1), Vector3(0, h - 0.11, side * 0.14), gold, false, seg)
	# Encadrements dorés des ouvertures.
	for o in cuts:
		var c := a + dir * float(o[0])
		var frame := Node3D.new()
		frame.position = c + Vector3(0, y0, 0)
		frame.rotation.y = normal_rot + PI / 2.0
		add_child(frame)
		for s in [-1.0, 1.0]:
			_box(Vector3(0.16, o[2], 0.3), Vector3(s * (o[1] / 2.0 + 0.08), o[2] / 2.0, 0), dark_wood, false, frame)
		_box(Vector3(o[1] + 0.32, 0.18, 0.32), Vector3(0, o[2] + 0.09, 0), gold, false, frame)


func _floor(x0: float, x1: float, z0: float, z1: float, mat: Material, h := WALL_H) -> void:
	_box(Vector3(x1 - x0, 0.1, z1 - z0), Vector3((x0 + x1) / 2.0, -0.05, (z0 + z1) / 2.0), mat, true)
	_box(Vector3(x1 - x0, 0.1, z1 - z0), Vector3((x0 + x1) / 2.0, h + 0.05, (z0 + z1) / 2.0), ceiling, false)
	# Caissons dorés au plafond.
	var step := 2.5
	var x := x0 + step
	while x < x1 - 0.5:
		_box(Vector3(0.12, 0.18, z1 - z0), Vector3(x, h - 0.09, (z0 + z1) / 2.0), gold)
		x += step
	var z := z0 + step
	while z < z1 - 0.5:
		_box(Vector3(x1 - x0, 0.16, 0.1), Vector3((x0 + x1) / 2.0, h - 0.08, z), gold)
		z += step


## Un lustre : couronnes dorées, pampilles lumineuses, et une vraie lumière chaude.
func _chandelier(pos: Vector3, size := 1.0, shadows := false) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_cyl(0.02, 1.0 * size, Vector3(0, 0.5 * size, 0), gold, root)
	for ring in 3:
		var r := (0.9 - ring * 0.25) * size
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.03
		tm.outer_radius = r
		t.mesh = tm
		t.material_override = gold
		t.position.y = -ring * 0.28 * size
		root.add_child(t)
		var count := 12 - ring * 3
		for k in count:
			var a := TAU * k / count
			var bulb := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.05 * size
			sm.height = 0.13 * size
			bulb.mesh = sm
			bulb.material_override = brass_glow
			bulb.position = Vector3(cos(a) * r, -ring * 0.28 * size + 0.08, sin(a) * r)
			root.add_child(bulb)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.52)
	light.light_energy = 4.0 * size
	light.omni_range = 11.0 * size
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.6
	light.position.y = -0.4 * size
	root.add_child(light)


func _sconce(pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	add_child(root)
	_box(Vector3(0.18, 0.3, 0.06), Vector3(0, 0, 0), gold, false, root)
	_cyl(0.07, 0.16, Vector3(0, 0.15, 0.12), brass_glow, root, 0.1)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.45)
	l.light_energy = 0.9
	l.omni_range = 3.5
	l.position = Vector3(0, 0.2, 0.3)
	root.add_child(l)


# --- La coque : sols, murs, plafonds ---------------------------------------------------

func _build_shell() -> void:
	_floor(-3, 3, 18, 22, floor_marble, 4.0)
	_floor(-10, 10, 6, 18, floor_marble, 10.0)
	_floor(10, 20, 6, 18, carpet, 4.5)
	_floor(-14, 14, -14, 6, carpet)
	_floor(14, 26, -14, 6, carpet_blue)
	_floor(-26, -14, -14, 0, carpet_blue, 5.0)

	# Sas et façade.
	_wall(Vector3(-3, 0, 22), Vector3(3, 0, 22), [[3.0, 2.2, 3.0]], 4.0)
	_wall(Vector3(-3, 0, 18), Vector3(-3, 0, 22), [], 4.0)
	_wall(Vector3(3, 0, 18), Vector3(3, 0, 22), [], 4.0)
	# Hall.
	_wall(Vector3(-10, 0, 18), Vector3(10, 0, 18), [[10.0, 3.4, 3.4]])
	# Le hall monte sur deux niveaux.
	_wall(Vector3(-10, 0, 18), Vector3(10, 0, 18), [], 4.0, 6.0)
	_wall(Vector3(-10, 0, 6), Vector3(-10, 0, 18), [], 4.0, 6.0)
	_wall(Vector3(10, 0, 6), Vector3(10, 0, 18), [], 4.0, 6.0)
	_wall(Vector3(-10, 0, 6), Vector3(-10, 0, 18))
	_wall(Vector3(10, 0, 6), Vector3(10, 0, 18), [[6.0, 4.0, 3.6]])
	# Bar.
	_wall(Vector3(10, 0, 18), Vector3(20, 0, 18), [], 4.5)
	_wall(Vector3(20, 0, 6), Vector3(20, 0, 18), [], 4.5)
	# Mur commun hall et bar / salles de jeu, avec la porte vitrée de la salle 1 et la porte du fond du bar.
	_wall(Vector3(-14, 0, 6), Vector3(26, 0, 6), [[14.0, 3.4, 3.4], [29.0, 2.0, 2.8]])
	# Salle des jeux, Ambassadeurs, salon.
	_wall(Vector3(-14, 0, -14), Vector3(-14, 0, 6), [[7.0, 2.0, 2.8]])
	_wall(Vector3(14, 0, -14), Vector3(14, 0, 6), [[10.0, 5.0, 3.8]])
	_wall(Vector3(-26, 0, -14), Vector3(26, 0, -14))
	_wall(Vector3(26, 0, -14), Vector3(26, 0, 6))
	_wall(Vector3(-26, 0, -14), Vector3(-26, 0, 0), [], 5.0)
	_wall(Vector3(-26, 0, 0), Vector3(-14, 0, 0), [], 5.0)

	# Porte à tambour vers la place du village.
	var door := Node3D.new()
	door.position = Vector3(0, 0, 21.8)
	add_child(door)
	_cyl(1.0, 2.8, Vector3(0, 1.4, 0), _glass(), door)
	_cyl(1.05, 0.12, Vector3(0, 2.86, 0), gold, door)
	_label("Sortie · Place de la Mairie", Vector3(0, 3.3, -0.3), 180.0, 48, Color(1.0, 0.85, 0.5), door)
	_interactive(door, "exit", "E : sortir sur la place", Vector3(2.0, 2.8, 0.6), Vector3(0, 1.4, -0.8))


func _glass() -> StandardMaterial3D:
	var m := _std(Color(0.8, 0.9, 0.95, 0.25), 0.05)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.3
	return m


# --- Le hall d'honneur -------------------------------------------------------------------

func _build_hall() -> void:
	# Tapis rouge de l'entrée à la salle des jeux.
	var runner := _shader("res://shaders/carpet.gdshader", {"scale": 0.6})
	_box(Vector3(2.4, 0.02, 16.0), Vector3(0, 0.01, 14.0), runner)
	_chandelier(Vector3(0, 9.8, 13.0), 2.0)
	_chandelier(Vector3(0, 3.0, 20.0), 0.6)
	# Colonnes de marbre à chapiteaux dorés.
	for x in [-5.0, 5.0]:
		for z in [9.0, 15.0]:
			_cyl(0.32, WALL_H - 0.6, Vector3(x, (WALL_H - 0.6) / 2.0, z), marble_white)
			_cyl(0.45, 0.3, Vector3(x, 0.15, z), gold)
			_cyl(0.32, 0.45, Vector3(x, WALL_H - 0.4, z), gold, self, 0.5)
	# La réception : comptoir de marbre et deux hôtesses.
	_box(Vector3(0.9, 1.1, 4.0), Vector3(7.6, 0.55, 12.0), marble_white, true)
	_box(Vector3(1.0, 0.08, 4.1), Vector3(7.6, 1.14, 12.0), gold)
	_box(Vector3(0.05, 0.9, 3.8), Vector3(7.13, 0.5, 12.0), dark_wood)
	_label("Réception", Vector3(7.12, 1.6, 12.0), -90.0, 72)
	_person("hotesse-1", Vector3(8.6, 0, 11.0), -90.0, "idle", "collier")
	_person("hotesse-2", Vector3(8.6, 0, 13.0), -90.0, "idle", "collier")
	var desk := Node3D.new()
	desk.position = Vector3(7.6, 0, 12.0)
	add_child(desk)
	_interactive(desk, "reception", "E : parler à la réception", Vector3(1.6, 2.0, 4.0), Vector3(-0.6, 1.0, 0))
	# Le vestiaire.
	_box(Vector3(3.0, 1.1, 0.8), Vector3(-5.0, 0.55, 16.8), dark_wood, true)
	_box(Vector3(3.1, 0.06, 0.9), Vector3(-5.0, 1.13, 16.8), gold)
	_label("Vestiaire", Vector3(-5.0, 1.6, 16.38), 180.0, 64)
	_person("character-male-d.glb", Vector3(-5.0, 0, 17.6), 180.0)
	# Banquettes de velours et plantes.
	for p in [Vector3(4.0, 0, 17.2), Vector3(6.4, 0, 17.2)]:
		_banquette(p, 180.0)
	for p in [Vector3(-6.8, 0, 7.0), Vector3(9.3, 0, 7.0), Vector3(-2.8, 0, 17.3), Vector3(9.3, 0, 17.3)]:
		_place("res://assets/kenney/furniture/pottedPlant.glb", p, 3.0)
	for x in [-7.0, 7.0]:
		_sconce(Vector3(x, 2.6, 17.85), 180.0)
	_label("CASINO DE SMARVES", Vector3(0, 4.6, 6.15), 0.0, 120)
	_label("Le jeu est un investissement", Vector3(0, 4.0, 6.15), 0.0, 56, Color(0.9, 0.82, 0.65))
	_label("Salle des jeux", Vector3(0, 3.7, 5.86), 180.0, 64)
	# Clients qui conversent.
	_person("character-male-b.glb", Vector3(-5.0, 0, 11.5), 60.0)
	_person("character-female-a.glb", Vector3(-4.2, 0, 12.2), -120.0)


func _banquette(pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	add_child(root)
	_box(Vector3(1.8, 0.45, 0.7), Vector3(0, 0.23, 0), velvet, true, root)
	_box(Vector3(1.8, 0.7, 0.18), Vector3(0, 0.6, -0.3), velvet, false, root)
	_box(Vector3(1.9, 0.08, 0.75), Vector3(0, 0.04, 0), dark_wood, false, root)


# --- Le Nocturne --------------------------------------------------------------------------

func _build_bar() -> void:
	_box(Vector3(0.8, 1.1, 8.0), Vector3(18.4, 0.55, 12.0), dark_wood, true)
	_box(Vector3(1.0, 0.07, 8.1), Vector3(18.3, 1.13, 12.0), marble_white)
	_box(Vector3(0.05, 0.06, 8.0), Vector3(17.95, 1.0, 12.0), gold)
	# Étagères de bouteilles lumineuses.
	_box(Vector3(0.3, 2.0, 7.0), Vector3(19.8, 2.2, 12.0), dark_wood)
	var bottle_mat := _std(Color(0.4, 0.8, 0.5, 0.8), 0.1)
	bottle_mat.emission_enabled = true
	bottle_mat.emission = Color(0.9, 0.6, 0.2)
	bottle_mat.emission_energy_multiplier = 1.4
	for shelf in 3:
		for k in 14:
			var c := Color.from_hsv(randf_range(0.0, 0.15), 0.7, 0.8)
			var m := bottle_mat.duplicate()
			m.albedo_color = c
			_cyl(0.06, 0.32, Vector3(19.6, 1.55 + shelf * 0.6, 8.8 + k * 0.48), m)
	for z in [9.0, 10.5, 12.0, 13.5, 15.0]:
		_cyl(0.2, 0.08, Vector3(17.5, 0.8, z), velvet)
		_cyl(0.04, 0.8, Vector3(17.5, 0.4, z), gold)
	_person("barman-nocturne", Vector3(19.2, 0, 12.0), -90.0, "idle", "noeud")
	_label("Le Nocturne", Vector3(17.9, 3.4, 12.0), -90.0, 96, Color(0.6, 0.85, 1.0))
	# Fauteuils club autour de guéridons.
	for p in [Vector3(13.0, 0, 9.0), Vector3(13.0, 0, 14.5)]:
		_cyl(0.4, 0.7, p + Vector3(0, 0.35, 0), dark_wood)
		_cyl(0.45, 0.04, p + Vector3(0, 0.72, 0), marble_white)
		for a in [0.0, 120.0, 240.0]:
			var off := Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a))) * 1.0
			var chair := _place(KK + "furniture/armchair.gltf", p + off, 0.9, a + 180.0)
			_tint(chair, Color(0.35, 0.12, 0.06))
	_person("character-female-d.glb", Vector3(13.8, 0, 9.6), -120.0, "sit")
	_chandelier(Vector3(15.0, 4.2, 12.0), 0.9)
	_sconce(Vector3(10.15, 2.4, 9.0), -90.0)
	_sconce(Vector3(10.15, 2.4, 15.5), -90.0)


func _tint(node: Node, c: Color) -> void:
	var m := _std(c, 0.55)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			mi.set_surface_override_material(i, m)


# --- La salle des jeux -----------------------------------------------------------------

func _build_games_room() -> void:
	_chandelier(Vector3(-7.0, 5.9, -3.0), 1.2, true)
	_chandelier(Vector3(7.0, 5.9, -3.0), 1.2, true)
	_chandelier(Vector3(0.0, 5.9, -9.0), 1.0)
	_chandelier(Vector3(0.0, 5.9, 2.0), 1.0)
	for z in [-10.0, -4.0, 2.0]:
		_sconce(Vector3(-13.85, 2.6, z), 90.0)
		_sconce(Vector3(13.85, 2.6, z), -90.0)
	# Dix-sept machines à sous : neuf au fond, deux îlots de quatre.
	var names := ["La Smarvoise", "Le Clain", "Le Miosson", "Saint-Félix", "L'Érable", "Passelourdin", "Le Moulin", "Les Zèbres", "La Rabelais"]
	for i in 9:
		_slot_machine(Vector3(-8.0 + i * 2.0, 0, -13.2), 0.0, names[i])
	for side in [-1.0, 1.0]:
		for k in 4:
			var x: float = side * 9.5 + (k % 2) * side * 1.0
			var z: float = -8.5 + (k / 2) * 1.6
			_slot_machine(Vector3(x - side * 0.5, 0, z), 90.0 * side, "")
	_roulette_table(Vector3(-7.0, 0, -2.5))
	_blackjack_table(Vector3(7.0, 0, -2.5))
	_craps_table(Vector3(0.0, 0, -5.5))
	# La caisse, près du hall.
	_box(Vector3(3.0, 1.15, 0.8), Vector3(-9.0, 0.575, 4.6), dark_wood, true)
	_box(Vector3(3.1, 0.06, 0.9), Vector3(-9.0, 1.18, 4.6), marble_white)
	for k in 8:
		_cyl(0.015, 1.0, Vector3(-10.4 + k * 0.4, 1.7, 4.6), gold)
	_box(Vector3(3.0, 0.08, 0.1), Vector3(-9.0, 2.22, 4.6), gold)
	_label("Caisse", Vector3(-9.0, 2.6, 4.15), 180.0, 64)
	_person("caissier", Vector3(-9.0, 0, 5.4), 180.0, "idle", "noeud")
	var cage := Node3D.new()
	cage.position = Vector3(-9.0, 0, 4.6)
	add_child(cage)
	_interactive(cage, "cashier", "E : passer à la caisse", Vector3(3.0, 2.0, 1.4), Vector3(0, 1.0, -0.6))
	# Clients aux tables et aux machines.
	_person("character-male-f.glb", Vector3(-5.6, 0, -1.0), -130.0)
	_person("character-female-b.glb", Vector3(5.6, 0, -1.4), 130.0)
	_person("character-male-e.glb", Vector3(-2.0, 0, -12.2), 180.0)
	_person("character-female-f.glb", Vector3(4.0, 0, -12.2), 180.0)
	_person("character-male-b.glb", Vector3(1.6, 0, -3.6), 180.0)
	_person("character-female-a.glb", Vector3(-1.4, 0, -7.4), 0.0)


func _slot_machine(pos: Vector3, rot_y: float, title: String) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	add_child(root)
	_box(Vector3(0.8, 1.05, 0.7), Vector3(0, 0.525, 0), dark_wood, true, root)
	_box(Vector3(0.84, 0.05, 0.74), Vector3(0, 1.07, 0), gold, false, root)
	_box(Vector3(0.74, 0.7, 0.5), Vector3(0, 1.45, -0.08), dark_wood, false, root)
	# Fenêtre des rouleaux, éclairée.
	var screen := _std(Color(0.97, 0.94, 0.85), 0.3)
	screen.emission_enabled = true
	screen.emission = Color(1.0, 0.9, 0.7)
	screen.emission_energy_multiplier = 0.9
	_box(Vector3(0.6, 0.3, 0.02), Vector3(0, 1.45, 0.18), screen, false, root)
	var reels := _label("7  ★  ♣", Vector3(0, 1.45, 0.2), 0.0, 52, Color(0.7, 0.05, 0.1), root)
	reels.outline_size = 0
	_box(Vector3(0.66, 0.36, 0.03), Vector3(0, 1.45, 0.175), gold, false, root)
	# Fronton lumineux en arc.
	var top := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.37
	cm.bottom_radius = 0.37
	cm.height = 0.5
	top.mesh = cm
	var lamp := _std(Color(0.8, 0.1, 0.15), 0.3)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.25, 0.3)
	lamp.emission_energy_multiplier = 1.6
	top.material_override = lamp
	top.rotation_degrees.x = 90
	top.position = Vector3(0, 1.85, -0.08)
	root.add_child(top)
	if title != "":
		var l := _label(title, Vector3(0, 1.95, 0.18), 0.0, 36, Color(1.0, 0.95, 0.8), root)
		l.outline_size = 4
	# Bras et tabouret.
	_cyl(0.03, 0.5, Vector3(0.46, 1.35, 0.0), chrome, root)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	knob.mesh = sm
	knob.material_override = _std(Color(0.8, 0.05, 0.08), 0.2)
	knob.position = Vector3(0.46, 1.62, 0.0)
	root.add_child(knob)
	_cyl(0.2, 0.08, Vector3(0, 0.72, 0.75), velvet, root)
	_cyl(0.03, 0.7, Vector3(0, 0.35, 0.75), chrome, root)
	_interactive(root, "slot", "E : jouer à %s" % (title if title != "" else "la machine"), Vector3(0.9, 2.0, 1.2), Vector3(0, 1.0, 0.3))
	root.set_meta("name", title if title != "" else "Machine de la salle")


func _table_base(root: Node3D, size: Vector3) -> void:
	_box(Vector3(size.x - 0.3, 0.75, size.z - 0.3), Vector3(0, 0.38, 0), dark_wood, true, root)
	_box(Vector3(size.x, 0.12, size.z), Vector3(0, 0.81, 0), wood, false, root)
	_box(Vector3(size.x - 0.24, 0.02, size.z - 0.24), Vector3(0, 0.875, 0), felt, false, root)
	_box(Vector3(size.x + 0.04, 0.03, size.z + 0.04), Vector3(0, 0.76, 0), gold, false, root)


func _roulette_table(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_table_base(root, Vector3(3.6, 0.9, 1.6))
	# Le cylindre : cuvette d'acajou, rotor à cases, tourelle dorée.
	var wheel := Node3D.new()
	wheel.position = Vector3(-1.2, 0.88, 0)
	root.add_child(wheel)
	_cyl(0.55, 0.16, Vector3(0, 0.08, 0), dark_wood, wheel, 0.6)
	var rotor := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.46
	rc.bottom_radius = 0.46
	rc.height = 0.04
	rc.radial_segments = 74
	rotor.mesh = rc
	var rm := _std(Color.WHITE, 0.3)
	rm.albedo_texture = _roulette_texture()
	rotor.material_override = rm
	rotor.position.y = 0.15
	wheel.add_child(rotor)
	_cyl(0.16, 0.06, Vector3(0, 0.19, 0), gold, wheel, 0.06)
	_cyl(0.02, 0.18, Vector3(0, 0.28, 0), gold, wheel)
	# Le tapis : numéros posés sur le feutre.
	for col in 12:
		for row in 3:
			var n := col * 3 + (3 - row)
			var red := n in ROULETTE.RED
			var l := Label3D.new()
			l.text = str(n)
			l.font = serif
			l.font_size = 40
			l.pixel_size = 0.0035
			l.modulate = Color(0.9, 0.15, 0.15) if red else Color(0.95, 0.95, 0.9)
			l.rotation_degrees.x = -90
			l.position = Vector3(-0.35 + col * 0.17, 0.89, -0.32 + row * 0.25)
			root.add_child(l)
	_person("croupier-roulette", Vector3(-0.2, 0, -1.25), 0.0, "idle", "noeud")
	_bill(_label("Roulette", Vector3(0, 2.6, 0), 0.0, 72, Color(1.0, 0.85, 0.5), root))
	_interactive(root, "roulette", "E : s'asseoir à la roulette", Vector3(3.8, 2.0, 2.6), Vector3(0, 1.0, 0.4))


func _roulette_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var d := Vector2(x, y) - c
			var r := d.length() / (size / 2.0)
			var col := Color(0.85, 0.66, 0.3)
			if r > 0.62 and r < 0.97:
				var a := fposmod(atan2(d.y, d.x) + PI / 37.0, TAU)
				var i := int(a / TAU * 37.0) % 37
				var n: int = ROULETTE.WHEEL[i]
				col = Color(0.05, 0.45, 0.2) if n == 0 else (Color(0.72, 0.08, 0.1) if n in ROULETTE.RED else Color(0.06, 0.06, 0.07))
			elif r <= 0.62:
				col = Color(0.35, 0.18, 0.08) if r > 0.25 else Color(0.85, 0.66, 0.3)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _blackjack_table(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	# Table en demi-lune : feutre, boudin de cuir, plateau d'acajou.
	var csg := CSGCombiner3D.new()
	csg.use_collision = true
	root.add_child(csg)
	var top := CSGCylinder3D.new()
	top.radius = 1.6
	top.height = 0.85
	top.sides = 48
	top.position.y = 0.425
	top.material = wood
	csg.add_child(top)
	var cut := CSGBox3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.size = Vector3(4, 2, 2)
	cut.position = Vector3(0, 0.4, -1.0)
	csg.add_child(cut)
	var cloth := CSGCombiner3D.new()
	root.add_child(cloth)
	var ft := CSGCylinder3D.new()
	ft.radius = 1.42
	ft.height = 0.02
	ft.sides = 48
	ft.position.y = 0.86
	ft.material = felt
	cloth.add_child(ft)
	var cut2 := CSGBox3D.new()
	cut2.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut2.size = Vector3(4, 1, 2)
	cut2.position = Vector3(0, 0.86, -0.98)
	cloth.add_child(cut2)
	var rail := CSGCombiner3D.new()
	root.add_child(rail)
	var torus := CSGTorus3D.new()
	torus.inner_radius = 1.42
	torus.outer_radius = 1.66
	torus.sides = 48
	torus.ring_sides = 12
	torus.position.y = 0.88
	torus.material = _std(Color(0.12, 0.05, 0.03), 0.4)
	rail.add_child(torus)
	var cut3 := CSGBox3D.new()
	cut3.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut3.size = Vector3(4, 1, 2)
	cut3.position = Vector3(0, 0.88, -1.0)
	rail.add_child(cut3)
	var text := _label("BLACKJACK PAIE 3 CONTRE 2", Vector3(0, 0.875, 0.55), 0.0, 40, Color(0.95, 0.85, 0.55), root)
	text.rotation_degrees.x = -90
	text.outline_size = 0
	_box(Vector3(0.5, 0.25, 0.3), Vector3(0.7, 1.0, -0.15), dark_wood, false, root)  # le sabot
	for k in 5:
		var a := deg_to_rad(-60.0 + k * 30.0)
		_cyl(0.22, 0.08, Vector3(sin(a) * 2.05, 0.72, cos(a) * 2.05), velvet, root)
		_cyl(0.03, 0.7, Vector3(sin(a) * 2.05, 0.35, cos(a) * 2.05), gold, root)
	_person("croupiere-blackjack", Vector3(0, 0, -0.55), 0.0, "idle", "noeud")
	_bill(_label("Blackjack", Vector3(0, 2.6, 0), 0.0, 72, Color(1.0, 0.85, 0.5), root))
	_interactive(root, "blackjack", "E : s'asseoir au blackjack", Vector3(3.6, 2.0, 2.6), Vector3(0, 1.0, 0.8))


func _craps_table(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_table_base(root, Vector3(4.6, 0.9, 2.2))
	_box(Vector3(4.6, 0.3, 0.12), Vector3(0, 1.0, -1.1), dark_wood, false, root)
	_box(Vector3(4.6, 0.3, 0.12), Vector3(0, 1.0, 1.1), dark_wood, false, root)
	var t := _label("PASS LINE", Vector3(0, 0.88, 0.6), 0.0, 48, Color(0.95, 0.95, 0.85), root)
	t.rotation_degrees.x = -90
	t.outline_size = 0
	var t2 := _label("FIELD  2 · 3 · 4 · 9 · 10 · 11 · 12", Vector3(0, 0.88, -0.1), 0.0, 36, Color(0.95, 0.85, 0.5), root)
	t2.rotation_degrees.x = -90
	t2.outline_size = 0
	_person("stickman", Vector3(0, 0, -1.7), 0.0, "idle", "noeud")
	_person("character-male-f.glb", Vector3(-1.4, 0, 1.6), 180.0)
	_person("character-female-c.glb", Vector3(1.2, 0, 1.6), 180.0)
	_bill(_label("Craps", Vector3(0, 2.6, 0), 0.0, 72, Color(1.0, 0.85, 0.5), root))
	_interactive(root, "craps", "E : jouer au craps", Vector3(4.8, 2.0, 3.0), Vector3(0, 1.0, 0.6))


# --- Les salles à seuils -------------------------------------------------------------

func _build_ambassadeurs() -> void:
	_chandelier(Vector3(20.0, 5.9, -4.0), 1.2)
	var poker := Node3D.new()
	poker.position = Vector3(20.0, 0, -4.0)
	add_child(poker)
	_cyl(1.0, 0.75, Vector3(0, 0.38, 0), dark_wood, poker, 0.7)
	_cyl(1.5, 0.1, Vector3(0, 0.8, 0), wood, poker)
	_cyl(1.36, 0.02, Vector3(0, 0.86, 0), felt, poker)
	var regulars := ["character-male-b.glb", "character-female-a.glb", "character-male-f.glb", "character-female-e.glb", "character-male-d.glb"]
	for k in 5:
		var a := TAU * k / 6.0
		_person(regulars[k], Vector3(20.0 + sin(a) * 1.9, 0, -4.0 + cos(a) * 1.9), rad_to_deg(a) + 180.0)
	_bill(_label("Poker des Ambassadeurs", Vector3(20.0, 2.8, -4.0), -90.0, 64))
	_interactive(poker, "poker", "E : prendre la chaise libre au poker", Vector3(4.0, 2.0, 4.0), Vector3(0, 1.0, 0))
	for z in [-10.0, 2.0]:
		_table_base(_node(Vector3(23.0, 0, z)), Vector3(3.0, 0.9, 1.6))
	_barrier("ambassadeurs", Vector3(14.0, 0, -4.0), 90.0, 5.0)


func _build_salon() -> void:
	_chandelier(Vector3(-20.0, 4.9, -7.0), 1.0)
	var baccara := _node(Vector3(-20.0, 0, -7.0))
	_table_base(baccara, Vector3(3.4, 0.9, 1.8))
	_bill(_label("Baccara", Vector3(0, 2.4, 0), 90.0, 64, Color(1.0, 0.85, 0.5), baccara))
	_interactive(baccara, "baccara", "E : s'asseoir au baccara", Vector3(3.6, 2.0, 2.8), Vector3(0, 1.0, 0.6))
	_person("mlle-solange", Vector3(-20.0, 0, -8.3), 0.0, "idle", "noeud")
	_person("character-male-c.glb", Vector3(-18.6, 0, -6.0), 135.0)
	# La porte capitonnée et son portier.
	_person("portier-salon", Vector3(-13.0, 0, -5.6), -90.0, "idle", "chapeau")
	_barrier("salon", Vector3(-14.0, 0, -7.0), 90.0, 2.0)


# --- L'étage : galerie du hall, Galerie de la Verrière, Bar du Fumoir, Le Lustre, Loggia ----

func _build_upper() -> void:
	# Le grand escalier contre le mur ouest du hall, de z = 17,2 (rez-de-chaussée) à z = 9,2 (galerie).
	var steps := 24
	for i in steps:
		var y := UP * (i + 1) / steps
		var z := 17.2 - 8.0 * (i + 0.5) / steps
		_box(Vector3(1.9, 0.08, 8.0 / steps + 0.02), Vector3(-8.95, y - 0.04, z), marble_white)
		_box(Vector3(1.4, 0.01, 8.0 / steps + 0.02), Vector3(-8.95, y + 0.005, z), carpet)
		_box(Vector3(1.9, y, 8.0 / steps), Vector3(-8.95, y / 2.0, z), dark_wood)
	var ramp := StaticBody3D.new()
	var rs := CollisionShape3D.new()
	var rb := BoxShape3D.new()
	var length := sqrt(8.0 * 8.0 + UP * UP)
	rb.size = Vector3(1.9, 0.1, length)
	rs.shape = rb
	ramp.add_child(rs)
	ramp.position = Vector3(-8.95, UP / 2.0, 13.2)
	ramp.rotation.x = atan2(UP, 8.0)
	add_child(ramp)
	# Rampe dorée côté hall.
	for i in 9:
		var t := i / 8.0
		_cyl(0.03, 1.0, Vector3(-7.95, UP * t + 0.5, 17.2 - 8.0 * t), gold)
	var rail := _cyl(0.04, length, Vector3(-7.95, UP / 2.0 + 1.0, 13.2), gold)
	rail.rotation.x = deg_to_rad(90) - atan2(UP, 8.0)
	_box(Vector3(0.1, 2.2, length), Vector3(-7.95, UP / 2.0 + 0.7, 13.2), _invisible(), true).rotation.x = atan2(UP, 8.0)

	# La galerie du hall, en balcon le long du mur nord, avec sa balustrade.
	_box(Vector3(20.0, 0.3, 3.4), Vector3(0, UP - 0.15, 7.7), dark_wood, true)
	_box(Vector3(19.8, 0.02, 3.3), Vector3(0, UP + 0.01, 7.7), carpet)
	_box(Vector3(2.4, 0.3, 0.6), Vector3(-8.8, UP - 0.15, 9.5), dark_wood, true)
	_box(Vector3(17.6, 0.12, 0.12), Vector3(1.2, UP + 1.0, 9.4), gold)
	_box(Vector3(17.6, 1.1, 0.1), Vector3(1.2, UP + 0.55, 9.4), _invisible(), true)
	for k in 30:
		_cyl(0.025, 1.0, Vector3(-7.6 + k * 0.6, UP + 0.5, 9.4), gold)
	_box(Vector3(20.0, 0.25, 0.2), Vector3(0, UP - 0.2, 9.4), gold)
	_label("Galerie de la Verrière", Vector3(0, UP + 3.4, 6.15), 0.0, 64)

	# Plancher de l'étage au-dessus de la salle des jeux, plafond à caissons et verrière.
	_box(Vector3(28.0, 0.1, 20.0), Vector3(0, UP + 0.0, -4.0), carpet, true)
	_box(Vector3(28.0, 0.1, 20.0), Vector3(0, UP + 4.55, -4.0), ceiling)
	var night := _std(Color(0.08, 0.12, 0.28), 0.1)
	night.emission_enabled = true
	night.emission = Color(0.06, 0.1, 0.25)
	night.emission_energy_multiplier = 1.2
	_box(Vector3(12.0, 0.05, 8.0), Vector3(0, UP + 4.48, -4.5), night)
	for k in 7:
		_box(Vector3(0.08, 0.1, 8.0), Vector3(-6.0 + k * 2.0, UP + 4.42, -4.5), gold)
	for k in 5:
		_box(Vector3(12.0, 0.1, 0.08), Vector3(0, UP + 4.42, -8.5 + k * 2.0), gold)

	# Les murs de l'étage.
	_wall(Vector3(-14, 0, 6), Vector3(14, 0, 6), [[14.0, 3.0, 3.0]], 4.5, UP)
	_wall(Vector3(-14, 0, -14), Vector3(14, 0, -14), [], 4.5, UP)
	_wall(Vector3(-14, 0, -14), Vector3(-14, 0, 6), [], 4.5, UP)
	_wall(Vector3(14, 0, -14), Vector3(14, 0, 6), [[3.5, 1.8, 2.6], [9.5, 1.8, 2.6], [16.0, 1.8, 2.6]], 4.5, UP)
	_wall(Vector3(-7, 0, -14), Vector3(-7, 0, 6), [[12.0, 3.0, 3.0]], 4.5, UP)
	_wall(Vector3(7, 0, -2), Vector3(7, 0, 6), [[4.0, 2.2, 2.8]], 4.5, UP)
	_wall(Vector3(7, 0, -2), Vector3(14, 0, -2), [], 4.5, UP)

	# La galerie : lustres, banquettes, et les portes des salles particulières, encore closes.
	_chandelier(Vector3(0, UP + 4.2, -4.0), 1.2)
	_chandelier(Vector3(-10.5, UP + 4.2, -4.0), 0.8)
	_chandelier(Vector3(10.5, UP + 4.2, -8.0), 0.8)
	for p in [Vector3(-4.0, UP, 1.0), Vector3(4.0, UP, 1.0)]:
		_banquette(p, 0.0)
	# Le Bar du Fumoir : comptoir, fauteuils de cuir, fumée bleutée.
	_box(Vector3(0.8, 1.1, 7.0), Vector3(-13.3, UP + 0.55, -5.0), dark_wood, true)
	_box(Vector3(1.0, 0.07, 7.1), Vector3(-13.2, UP + 1.13, -5.0), marble_white)
	_person("character-male-c.glb", Vector3(-13.9, UP, -5.0), 90.0)
	for p in [Vector3(-10.0, UP, -10.0), Vector3(-10.0, UP, 1.0)]:
		_cyl(0.4, 0.7, p + Vector3(0, 0.35, 0), dark_wood)
		for a in [0.0, 120.0, 240.0]:
			var off := Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a))) * 1.0
			var chair := _place(KK + "furniture/armchair.gltf", p + off, 0.9, a + 180.0)
			_tint(chair, Color(0.3, 0.13, 0.06))
	_person("character-male-b.glb", Vector3(-9.2, UP, -9.6), -120.0, "sit")
	var smoke := FogVolume.new()
	smoke.size = Vector3(7.0, 4.5, 20.0)
	smoke.position = Vector3(-10.5, UP + 2.25, -4.0)
	var fm := FogMaterial.new()
	fm.density = 0.12
	fm.albedo = Color(0.7, 0.75, 0.85)
	smoke.material = fm
	add_child(smoke)
	_label("Bar du Fumoir", Vector3(-7.15, UP + 3.4, 2.0), 90.0, 56)

	# Restaurant Le Lustre : nappes blanches et dîneurs.
	var cloth := _std(Color(0.96, 0.95, 0.92), 0.8)
	for x in [-4.5, 0.0, 4.5]:
		var t := Vector3(x, UP, -11.5)
		_cyl(0.06, 0.75, t + Vector3(0, 0.38, 0), gold)
		_cyl(0.8, 0.3, t + Vector3(0, 0.66, 0), cloth, self, 0.75)
		_cyl(0.04, 0.25, t + Vector3(0, 0.95, 0), brass_glow)
		_person(["character-female-a.glb", "character-male-f.glb", "character-female-d.glb"].pick_random(), t + Vector3(0, 0, 1.0), 180.0, "sit")
	_label("Restaurant Le Lustre", Vector3(0, UP + 3.6, -13.85), 0.0, 64)
	_chandelier(Vector3(0, UP + 4.2, -11.5), 0.9)

	# La Loggia et sa table de Grand Hasard.
	var hasard := _node(Vector3(10.5, UP, 2.0))
	_table_base(hasard, Vector3(2.4, 0.9, 1.4))
	for k in 3:
		var die := _box(Vector3(0.12, 0.12, 0.12), Vector3(-0.2 + k * 0.2, 0.95, 0.0), marble_white, false, hasard)
		die.rotation_degrees.y = randf() * 90.0
	_person("chef-de-partie", Vector3(10.5, UP, 0.9), 0.0, "idle", "noeud")
	_bill(_label("Le Grand Hasard", Vector3(0, 2.2, 0), 0.0, 56, Color(1.0, 0.85, 0.5), hasard))
	_interactive(hasard, "dice", "E : jouer au Grand Hasard", Vector3(2.6, 2.0, 2.4), Vector3(0, 1.0, 0.5))
	_chandelier(Vector3(10.5, UP + 4.2, 2.0), 0.7)
	_barrier("loggia", Vector3(7.0, UP, 2.0), 90.0, 2.2)
	_build_salons()


# --- Les salons de l'étage, au-dessus des Ambassadeurs ------------------------------------

func _build_salons() -> void:
	_box(Vector3(12.0, 0.1, 20.0), Vector3(20.0, UP, -4.0), carpet_blue, true)
	_box(Vector3(12.0, 0.1, 20.0), Vector3(20.0, UP + 4.55, -4.0), ceiling)
	_wall(Vector3(26, 0, -14), Vector3(26, 0, 6), [], 4.5, UP)
	_wall(Vector3(14, 0, -14), Vector3(26, 0, -14), [], 4.5, UP)
	_wall(Vector3(14, 0, 6), Vector3(26, 0, 6), [], 4.5, UP)
	_wall(Vector3(14, 0, -7), Vector3(26, 0, -7), [], 4.5, UP)
	_wall(Vector3(14, 0, -1), Vector3(26, 0, -1), [], 4.5, UP)
	_barrier("fetes", Vector3(14.0, UP, -10.5), 90.0, 1.8)
	_barrier("musique", Vector3(14.0, UP, -4.5), 90.0, 1.8)
	_barrier("particuliers", Vector3(14.0, UP, 2.0), 90.0, 1.8)

	# La Salle des fêtes : la grande roue de la fortune et ses guirlandes.
	_chandelier(Vector3(20.0, UP + 4.2, -10.5), 1.0)
	var wheel := _node(Vector3(24.5, UP, -10.5))
	_box(Vector3(0.6, 0.9, 1.2), Vector3(0, 0.45, 0), dark_wood, true, wheel)
	var disc := MeshInstance3D.new()
	var dc := CylinderMesh.new()
	dc.top_radius = 1.5
	dc.bottom_radius = 1.5
	dc.height = 0.12
	dc.radial_segments = 54
	disc.mesh = dc
	var dm := _std(Color.WHITE, 0.35)
	dm.albedo_texture = _prize_texture()
	disc.material_override = dm
	disc.rotation_degrees = Vector3(0, 0, 90)
	disc.position = Vector3(0, 2.5, 0)
	wheel.add_child(disc)
	var rim := MeshInstance3D.new()
	var rt := TorusMesh.new()
	rt.inner_radius = 1.48
	rt.outer_radius = 1.62
	rim.mesh = rt
	rim.material_override = gold
	rim.rotation_degrees = Vector3(0, 0, 90)
	rim.position = Vector3(0, 2.5, 0)
	wheel.add_child(rim)
	for k in 18:
		var a := TAU * k / 18.0
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		bulb.mesh = sm
		bulb.material_override = brass_glow
		bulb.position = Vector3(-0.08, 2.5 + sin(a) * 1.55, cos(a) * 1.55)
		wheel.add_child(bulb)
	_bill(_label("La Roue de la fortune", Vector3(0, 4.3, 0), 0.0, 56, Color(1.0, 0.85, 0.5), wheel))
	_interactive(wheel, "roue", "E : faire tourner la roue", Vector3(2.0, 4.0, 3.4), Vector3(-1.2, 2.0, 0))
	_person("maitre-ceremonie", Vector3(23.0, UP, -12.2), -60.0, "idle", "chapeau")
	_person("invitee-fetes", Vector3(19.0, UP, -9.0), 120.0)
	_person("invite-fetes", Vector3(18.0, UP, -12.0), 60.0)

	# Le Salon de musique : piano à queue et table de la Boule.
	_chandelier(Vector3(20.0, UP + 4.2, -4.0), 0.9)
	var piano := _node(Vector3(24.0, UP, -5.5))
	var black := _std(Color(0.02, 0.02, 0.025), 0.08)
	_box(Vector3(1.5, 0.3, 2.0), Vector3(0, 0.85, 0), black, true, piano)
	_cyl(0.75, 0.3, Vector3(0, 0.85, -1.0), black, piano)
	for x in [-0.6, 0.6]:
		_cyl(0.06, 0.7, Vector3(x, 0.35, 0.8), black, piano)
	_cyl(0.06, 0.7, Vector3(0, 0.35, -1.5), black, piano)
	_box(Vector3(1.4, 0.04, 0.22), Vector3(0, 0.82, 1.08), marble_white, false, piano)
	var lid := _box(Vector3(1.5, 0.03, 2.4), Vector3(-0.55, 1.45, -0.3), black, false, piano)
	lid.rotation_degrees.z = 40
	_person("pianiste", Vector3(24.0, UP, -4.1), 180.0, "sit", "noeud")
	var boule := _node(Vector3(18.5, UP, -4.0))
	_table_base(boule, Vector3(2.4, 0.9, 1.4))
	_bill(_label("La Boule", Vector3(0, 2.2, 0), 0.0, 56, Color(1.0, 0.85, 0.5), boule))
	_interactive(boule, "boule", "E : jouer à la Boule", Vector3(2.6, 2.0, 2.4), Vector3(0, 1.0, 0.4))
	_person("croupier-boule", Vector3(18.5, UP, -5.1), 0.0, "idle", "noeud")

	# Les Salons particuliers : le Banco, à l'abri des regards.
	_chandelier(Vector3(20.0, UP + 4.2, 2.5), 0.8)
	var banco := _node(Vector3(20.5, UP, 2.5))
	_table_base(banco, Vector3(3.0, 0.9, 1.6))
	_bill(_label("Banco", Vector3(0, 2.2, 0), 0.0, 56, Color(1.0, 0.85, 0.5), banco))
	_interactive(banco, "banco", "E : s'asseoir au Banco", Vector3(3.2, 2.0, 2.6), Vector3(0, 1.0, 0.5))
	_person("croupier-banco", Vector3(20.5, UP, 1.3), 0.0, "idle", "noeud")
	_person("baron", Vector3(22.4, UP, 3.2), -110.0, "idle", "chapeau")
	for p in [Vector3(25.0, UP, 0.5), Vector3(25.0, UP, 4.5)]:
		_banquette(p, -90.0)


func _prize_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var segs: Array = []
	for k in WHEEL.ROUE_COUNTS:
		for i in WHEEL.ROUE_COUNTS[k]:
			segs.append(k)
	var rng := RandomNumberGenerator.new()
	rng.seed = 54
	for i in range(segs.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = segs[i]
		segs[i] = segs[j]
		segs[j] = tmp
	var c := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var d := Vector2(x, y) - c
			var r := d.length() / (size / 2.0)
			var col := Color(0.85, 0.66, 0.3)
			if r > 0.2 and r < 0.98:
				var a := fposmod(atan2(d.y, d.x), TAU)
				var i := int(a / TAU * segs.size()) % segs.size()
				col = WHEEL.ROUE_COLORS[segs[i]]
				if fmod(a / TAU * segs.size(), 1.0) < 0.05:
					col = Color(0.85, 0.66, 0.3)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _invisible() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0)
	return m


func _node(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	return n


## Un cordon de velours entre deux poteaux dorés, avec le seuil affiché. Il bloque le passage.
func _barrier(id: String, pos: Vector3, rot_y: float, width: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	add_child(root)
	for s in [-1.0, 1.0]:
		_cyl(0.05, 1.0, Vector3(s * width / 2.0, 0.5, 0), gold, root)
		_cyl(0.12, 0.05, Vector3(s * width / 2.0, 0.03, 0), gold, root)
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		ball.mesh = sm
		ball.material_override = gold
		ball.position = Vector3(s * width / 2.0, 1.03, 0)
		root.add_child(ball)
	for k in 20:
		var t := (k + 0.5) / 20.0
		var x := -width / 2.0 + width * t
		var y := 0.95 - 0.25 * 4.0 * t * (1.0 - t)
		var seg := _cyl(0.03, width / 20.0 + 0.02, Vector3(x, y, 0), velvet, root)
		seg.rotation_degrees.z = 90
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(width, 2.5, 0.4)
	cs.shape = b
	cs.position.y = 1.25
	body.add_child(cs)
	root.add_child(body)
	var info := _lock_info(id)
	var seal := _label("%s\nouvre à %s crédits %s" % [info.name, Game.fmt(info.seuil), "misés" if info.get("on", "won") == "staked" else "gagnés"], Vector3(0, 1.5, 0.05), 0.0, 44, Color(1.0, 0.88, 0.6), root)
	seal.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	barriers[id] = root


func _lock_info(id: String) -> Dictionary:
	for l in LOCKS:
		if l.id == id:
			return l
	return {}


func _refresh_locks(silent := false) -> void:
	for l in LOCKS:
		var amount: int = Game.staked if l.get("on", "won") == "staked" else Game.won
		if barriers.has(l.id) and amount >= l.seuil:
			barriers[l.id].queue_free()
			barriers.erase(l.id)
			if not silent:
				_announce("%s vous ouvre %s." % [l.host, l.name])
				if l.id == "salon":
					Game.credits += 500
					Game.changed.emit()
					_announce("Monsieur Armand vous ouvre le salon et vous offre une plaque de 500. « Un client d'avenir. »")


# --- Jeux et interactions ----------------------------------------------------------------

func _on_interact(target: Node) -> void:
	var kind: String = target.get_meta("interact")
	match kind:
		"exit":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		"reception":
			_announce("« Bienvenue au Casino de Smarves. Ici, chaque mise prépare votre avenir. »")
		"cashier":
			if Game.advance_if_broke(5):
				_announce("La caisse vous avance %d crédits. « La maison croit en vous. »" % Game.ADVANCE)
			else:
				_announce("« Vos crédits sont bien placés. Revenez quand il vous en faudra plus. »")
		"slot":
			var p: PanelContainer = SLOT.new()
			p.game = Game
			p.title = target.get_parent().get_meta("name")
			p.subtitle = "Casino de Smarves  ·  salle des jeux"
			_open_panel(p)
		"roulette":
			var r: PanelContainer = ROULETTE.new()
			r.title = "Roulette européenne"
			_open_panel(r)
		"blackjack":
			var b: PanelContainer = BLACKJACK.new()
			_open_panel(b)
		"poker":
			var pk: PanelContainer = POKER.new()
			_open_panel(pk)
		"roue":
			var w: PanelContainer = WHEEL.new()
			w.mode = "roue"
			w.title = "La Roue de la fortune"
			_open_panel(w)
		"boule":
			var bo: PanelContainer = WHEEL.new()
			bo.mode = "boule"
			bo.title = "La Boule"
			_open_panel(bo)
		"banco":
			var bc: PanelContainer = BACCARA.new()
			bc.title = "Banco des Salons particuliers"
			bc.commission = false
			_open_panel(bc)
		"craps":
			var cp: PanelContainer = CRAPS.new()
			_open_panel(cp)
		"dice":
			var g: PanelContainer = DICE.new()
			_open_panel(g)
		"baccara":
			var c: PanelContainer = BACCARA.new()
			c.title = "Baccara du salon privé"
			_open_panel(c)


func _open_panel(p: Control) -> void:
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_prompt.visible = false
	_panel_layer.add_child(p)
	p.played.connect(_on_played)
	p.closed.connect(_close_panel)
	_active_panel = p


func _close_panel() -> void:
	if _active_panel:
		_active_panel.queue_free()
		_active_panel = null
	player.frozen = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_played(_bet: int, payout: int) -> void:
	Game.cash_in(payout)
	_refresh_locks()
	if Game.advance_if_broke(1):
		_announce("La caisse vous avance %d crédits. « Un placement, ça se soutient. »" % Game.ADVANCE)


# --- Interface ------------------------------------------------------------------------

func _announce(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(_banner, "modulate:a", 0.0, 1.0)


func _process(delta: float) -> void:
	_shown = lerpf(_shown, Game.credits, 1.0 - exp(-10.0 * delta))
	if absf(_shown - Game.credits) < 0.5:
		_shown = Game.credits
	_credits_label.text = "%s crédits" % Game.fmt(roundi(_shown))
	_won_label.text = "Gagné au jeu : %s" % Game.fmt(Game.won) + ("
Dette au Crédit Smarvois : %s" % Game.fmt(Game.debt) if Game.debt > 0 else "")
	if player:
		var t: Node = player.focus_target
		_prompt.visible = t != null and _active_panel == null
		if t:
			_prompt.text = t.get_meta("prompt")
		var room := ""
		for r in ROOMS:
			var level := 1 if player.position.y > 3.0 else 0
			if (r[5] if r.size() > 5 else 0) == level and player.position.x > r[1] and player.position.x < r[2] and player.position.z > r[3] and player.position.z < r[4]:
				room = r[0]
		if room != _current_room:
			_current_room = room
			_room_label.text = room
			_room_label.modulate.a = 1.0
			var tw := create_tween()
			tw.tween_interval(2.0)
			tw.tween_property(_room_label, "modulate:a", 0.0, 1.2)


func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font = serif
	theme.default_font_size = 20
	var gold_col := Color(0.96, 0.8, 0.45)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.05, 0.03, 0.03, 0.88)
	panel.border_color = Color(0.85, 0.65, 0.3, 0.7)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(18)
	theme.set_stylebox("panel", "PanelContainer", panel)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color(0.14, 0.07, 0.04, 0.95), "hover": Color(0.28, 0.15, 0.06, 0.95),
			"pressed": Color(0.38, 0.22, 0.08, 1.0), "disabled": Color(0.07, 0.06, 0.06, 0.8),
			"focus": Color(0, 0, 0, 0)}[st]
		b.border_color = Color(0.85, 0.62, 0.3, 0.25 if st == "disabled" else 0.8)
		b.set_border_width_all(1)
		b.set_corner_radius_all(3)
		b.content_margin_left = 14
		b.content_margin_right = 14
		b.content_margin_top = 7
		b.content_margin_bottom = 7
		if st == "focus":
			b.draw_center = false
			b.border_color = Color(0, 0, 0, 0)
		theme.set_stylebox(st, "Button", b)
	theme.set_color("font_color", "Button", gold_col)
	theme.set_color("font_hover_color", "Button", Color(1, 0.92, 0.7))
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.42))
	theme.set_color("font_color", "Label", Color(0.9, 0.86, 0.8))

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(28, 24)
	root.add_child(top)
	var v := VBoxContainer.new()
	top.add_child(v)
	var title := Label.new()
	title.text = "C A S I N O   D E   S M A R V E S"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.75, 0.62, 0.45))
	v.add_child(title)
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 38)
	_credits_label.add_theme_color_override("font_color", gold_col)
	v.add_child(_credits_label)
	_won_label = Label.new()
	_won_label.add_theme_font_size_override("font_size", 16)
	v.add_child(_won_label)

	var cross := Label.new()
	cross.text = "·"
	cross.add_theme_font_size_override("font_size", 40)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position -= Vector2(5, 28)
	root.add_child(cross)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position.y += 40
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 6)
	root.add_child(_prompt)
	_room_label = Label.new()
	_room_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_room_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_room_label.position.y += 40
	_room_label.add_theme_font_size_override("font_size", 34)
	_room_label.add_theme_color_override("font_color", gold_col)
	_room_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_room_label.add_theme_constant_override("outline_size", 8)
	root.add_child(_room_label)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_banner.position.y -= 90
	_banner.add_theme_font_size_override("font_size", 22)
	_banner.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	var hint := Label.new()
	hint.text = "ZQSD : marcher   ·   souris : regarder   ·   E : jouer   ·   Échap : libérer la souris"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6, 0.8))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.position.y -= 20
	root.add_child(hint)
	_panel_layer = CenterContainer.new()
	_panel_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel_layer)


# --- Capture : godot -- --capture=chemin.png [--at=x,z,lacet,tangage] [--open=roulette] ---

func _maybe_capture() -> void:
	var path := ""
	var open := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
			if v.size() > 3:
				player.camera.rotation.x = deg_to_rad(v[3])
			if v.size() > 4:
				player.position.y = v[4]
		elif arg.begins_with("--open="):
			open = arg.trim_prefix("--open=")
		elif arg.begins_with("--won="):
			Game.won = int(arg.trim_prefix("--won="))
			Game.staked = Game.won
			Game.credits += Game.won
			_refresh_locks(true)
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if open != "":
		await get_tree().create_timer(1.0).timeout
		var fake := Node.new()
		fake.set_meta("interact", open)
		add_child(fake)
		_on_interact(fake)
	await get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
