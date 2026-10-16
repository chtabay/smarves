extends Node3D
## Smarves : la place de la Mairie au crépuscule, et le Café de la Place où l'on joue.

const ORBIT := preload("res://scripts/orbit_camera.gd")
const VILLAGER := preload("res://scripts/villager.gd")
const SLOT := preload("res://scripts/slot_machine.gd")
const LOAN := preload("res://scripts/loan_panel.gd")
const RACE := preload("res://scripts/race_panel.gd")
const LOTO := preload("res://scripts/loto_panel.gd")
const ROULETTE := preload("res://scripts/roulette_panel.gd")
const WHEEL := preload("res://scripts/wheel_panel.gd")
const BLACKJACK := preload("res://scripts/blackjack_panel.gd")
const POKER := preload("res://scripts/poker_panel.gd")
const OUTSKIRTS := preload("res://scripts/outskirts.gd")

## Où regarde la caméra quand on joue dans chaque lieu de la place : [cible, distance, lacet, tangage].
const FOCUS := {
	"petanque": [Vector3(4.5, 0.6, 3.0), 7.0, 0.0, -30.0],
	"boulangerie": [Vector3(7.0, 1.0, -1.0), 6.0, -90.0, -18.0],
	"rabelais": [Vector3(-7.4, 1.2, 4.4), 6.5, 90.0, -18.0],
	"eglise": [Vector3(2.6, 1.0, -3.4), 6.0, 0.0, -14.0],
	"zebres": [Vector3(64.0, 0.8, 3.5), 9.0, 0.0, -24.0],
	"moulin": [Vector3(-72.0, 1.4, 0.5), 9.0, 0.0, -18.0],
	"passelourdin": [Vector3(0.0, 1.0, -71.0), 6.0, 0.0, -24.0],
}

## Les panneaux de la place, vers les environs : [lieu, position, rotation, texte].
const SIGNPOSTS := [
	["bois", Vector3(10.4, 0, 5.6), -90.0, "Bois de Saint-Pierre  →"],
	["moulin", Vector3(-10.4, 0, 5.6), 90.0, "←  Moulin des Dames"],
	["passelourdin", Vector3(-6.8, 0, -3.4), 0.0, "Rochers de Passelourdin  ↑"],
]
const KN := "res://assets/kenney/nature/"
const KS := "res://assets/kenney/survival/"
const KD := "res://assets/kenney/dungeon/"
const KC := "res://assets/kenney/characters/"


## Les lieux du village, dans l'ordre où ils s'ouvrent. Le seuil porte sur le total gagné au jeu.
const PLACES := [
	{"id": "cafe", "name": "Le Café de la Place", "game": "La Smarvoise", "seuil": 0, "host": "Josiane"},
	{"id": "casino", "name": "Le Casino de Smarves", "game": "salles de jeu", "seuil": 0, "host": "Monsieur Armand"},
	{"id": "banque", "name": "Le Crédit Smarvois", "game": "prêts pour investir", "seuil": 0, "host": "M. Brunet"},
	{"id": "petanque", "name": "La pétanque de la place", "game": "les paris de Lucien", "seuil": 1000, "host": "Lucien"},
	{"id": "boulangerie", "name": "La boulangerie", "game": "la roulette du comptoir", "seuil": 5000, "host": "Mme Ferrand"},
	{"id": "rabelais", "name": "La salle François-Rabelais", "game": "le grand loto", "seuil": 20000, "host": "Le président du comité"},
	{"id": "eglise", "name": "Le parvis Saint-Félix", "game": "la roue de la kermesse", "seuil": 60000, "host": "Le comité des fêtes"},
	{"id": "zebres", "name": "L'allée des trois zèbres", "game": "la course des zèbres", "seuil": 150000, "host": "Le gardien du bois"},
	{"id": "moulin", "name": "Le Moulin des Dames", "game": "le blackjack de l'arrière-salle", "seuil": 400000, "host": "Le meunier"},
	{"id": "passelourdin", "name": "Les rochers de Passelourdin", "game": "la partie de poker", "seuil": 1000000, "host": "Quelqu'un"},
]

var shown_credits := float(Game.credits)

var stone_material: StandardMaterial3D
var pave_material: StandardMaterial3D
var bulb_material: StandardMaterial3D
var window_material: StandardMaterial3D
var serif: SystemFont

var camera: Camera3D
var villagers: Array[Node3D] = []
var place_signs := {}
var _credits_label: Label
var _won_label: Label
var _places_box: VBoxContainer
var _banner: Label
var _slot: PanelContainer
var _hint: Label
var _back: Button
var area := ""
var moving_cars: Array[Node3D] = []


func _ready() -> void:
	randomize()
	_make_materials()
	_build_environment()
	_build_plinth()
	_build_square()
	_build_buildings()
	_build_trees_and_lights()
	_build_villagers()
	var outskirts := OUTSKIRTS.new()
	add_child(outskirts)
	outskirts.build(self)
	_build_signposts()
	_build_ui()
	camera = Camera3D.new()
	camera.set_script(ORBIT)
	add_child(camera)
	camera.make_current()
	_refresh_places()
	Sfx.set_ambience("village")
	_maybe_capture()


# --- Matériaux -----------------------------------------------------------------

func _noise_tex(normal: bool, freq: float, dark: Color) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = 3.0
	else:
		var g := Gradient.new()
		g.set_color(0, dark)
		g.set_color(1, Color.WHITE)
		t.color_ramp = g
	return t


func _make_materials() -> void:
	# Pierre calcaire du Poitou : blanc crème, un peu tachée.
	stone_material = StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.86, 0.8, 0.68)
	stone_material.albedo_texture = _noise_tex(false, 0.05, Color(0.82, 0.78, 0.7))
	stone_material.normal_enabled = true
	stone_material.normal_texture = _noise_tex(true, 0.09, Color.BLACK)
	stone_material.uv1_triplanar = true
	stone_material.roughness = 0.9

	pave_material = StandardMaterial3D.new()
	pave_material.albedo_color = Color(0.55, 0.52, 0.48)
	pave_material.albedo_texture = _noise_tex(false, 0.12, Color(0.7, 0.68, 0.66))
	pave_material.normal_enabled = true
	pave_material.normal_texture = _noise_tex(true, 0.2, Color.BLACK)
	pave_material.uv1_triplanar = true
	pave_material.uv1_scale = Vector3.ONE * 0.6
	pave_material.roughness = 0.75

	bulb_material = StandardMaterial3D.new()
	bulb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_material.albedo_color = Color(1.0, 0.85, 0.55)
	bulb_material.emission_enabled = true
	bulb_material.emission = Color(1.0, 0.72, 0.38)
	bulb_material.emission_energy_multiplier = 5.0

	window_material = StandardMaterial3D.new()
	window_material.albedo_color = Color(1.0, 0.78, 0.45)
	window_material.emission_enabled = true
	window_material.emission = Color(1.0, 0.68, 0.32)
	window_material.emission_energy_multiplier = 2.5

	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"])


func _place(path: String, pos: Vector3, scale := 1.0, rot_y := 0.0, parent: Node = self) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scale
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	return n


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


# --- Ambiance : le crépuscule du Poitou ------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/night_sky.gdshader")
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.4
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.ssao_enabled = true
	env.ssao_intensity = 2.0
	env.ssil_enabled = true
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.45, 0.45, 0.6)
	env.volumetric_fog_gi_inject = 0.3
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Dernière lueur du couchant, rasante et violette, et la lune qui monte.
	var dusk := DirectionalLight3D.new()
	dusk.light_color = Color(0.95, 0.55, 0.6)
	dusk.light_energy = 0.35
	dusk.rotation_degrees = Vector3(-12, 120, 0)
	dusk.light_volumetric_fog_energy = 0.0
	add_child(dusk)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.5
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-50, -35, 0)
	moon.light_volumetric_fog_energy = 0.1
	add_child(moon)


# --- Le socle et la place --------------------------------------------------------

func _build_plinth() -> void:
	var walnut := StandardMaterial3D.new()
	walnut.albedo_color = Color(0.17, 0.09, 0.05)
	walnut.roughness = 0.4
	_box(Vector3(22.6, 0.8, 16.6), Vector3(0, -0.5, 0), walnut)
	var plaque := Label3D.new()
	plaque.text = "SMARVES  ·  VIENNE"
	plaque.font = serif
	plaque.font_size = 80
	plaque.pixel_size = 0.004
	plaque.modulate = Color(0.95, 0.75, 0.4)
	plaque.position = Vector3(0, -0.5, 8.31)
	add_child(plaque)


func _build_square() -> void:
	# La place pavée et la route devant.
	_box(Vector3(22, 0.1, 16), Vector3(0, -0.05, 0), pave_material)
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.09, 0.09, 0.1)
	asphalt.roughness = 0.3  # bitume humide : il reflète les ampoules
	_box(Vector3(22, 0.11, 2.4), Vector3(0, -0.04, 6.4), asphalt)
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(0.85, 0.85, 0.8)
	for x in range(-10, 11, 2):
		_box(Vector3(0.9, 0.12, 0.08), Vector3(x, -0.035, 6.4), line)

	# Le terrain de pétanque, en sable clair, bordé de planches.
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.7, 0.6, 0.45)
	sand.albedo_texture = _noise_tex(false, 0.3, Color(0.8, 0.75, 0.7))
	sand.uv1_triplanar = true
	sand.roughness = 1.0
	_box(Vector3(5.0, 0.12, 2.4), Vector3(4.5, -0.03, 3.0), sand)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.22, 0.12)
	_box(Vector3(5.1, 0.16, 0.08), Vector3(4.5, 0.02, 1.8), wood)
	_box(Vector3(5.1, 0.16, 0.08), Vector3(4.5, 0.02, 4.2), wood)

	# Le monument aux morts et l'érable rouge de 1986.
	_box(Vector3(0.9, 0.25, 0.9), Vector3(-1.6, 0.12, -0.6), stone_material)
	_box(Vector3(0.35, 1.6, 0.35), Vector3(-1.6, 1.0, -0.6), stone_material)
	var maple := _place(KN + "tree_detailed_fall.glb", Vector3(0.6, 0, -0.4), 2.2, 20.0)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.65, 0.1, 0.06)
	red.roughness = 0.85
	for mi in maple.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m and m.resource_name.begins_with("leafs"):
				mi.set_surface_override_material(i, red)


# --- Les bâtiments ------------------------------------------------------------------

const KK := "res://assets/kaykit/"
const KA := "res://assets/kenney/arcade/"
const BUILDING_SCALE := 3.2


func _kaykit(name: String, color: String, pos: Vector3, rot_y: float, scale := BUILDING_SCALE) -> Node3D:
	return _place(KK + "medieval_buildings/%s/building_%s_%s.gltf" % [color, name, color], pos, scale, rot_y)


func _building(id: String, name: String, color: String, pos: Vector3, rot_y: float, scale := BUILDING_SCALE) -> Node3D:
	var b := _kaykit(name, color, pos, rot_y, scale)
	if id != "":
		var aabb := _aabb_of(b)
		_add_place_marker(id, b, Vector3(0, aabb.size.y / scale + 0.25, 0), aabb.size / scale)
	return b


func _aabb_of(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return AABB(box.position * n.scale, box.size * n.scale)


func _build_buildings() -> void:
	# Le fond de la place : maisons, mairie, église, salle Rabelais.
	_building("", "home_B", "green", Vector3(-8.6, 0, -5.6), 0.0)
	_building("mairie", "home_B", "blue", Vector3(-4.6, 0, -5.8), 0.0, 3.6)
	_building("eglise", "church", "yellow", Vector3(0.4, 0, -6.0), 0.0, 3.6)
	var casino := CasinoExterior.build(self, Vector3(6.4, 0, -6.0), 0.0, serif)
	_add_place_marker("casino", casino, Vector3(0, 5.6, 0), Vector3(CasinoExterior.W, 3.5, CasinoExterior.D))
	# À gauche, le Café de la Place ; à droite, la boulangerie et le Crédit Smarvois.
	_building("cafe", "tavern", "red", Vector3(-8.8, 0, -0.6), 90.0)
	_building("rabelais", "market", "red", Vector3(-9.0, 0, 4.4), 90.0, 2.6)
	_building("boulangerie", "home_A", "yellow", Vector3(9.0, 0, -1.2), -90.0)
	_building("banque", "home_B", "red", Vector3(9.0, 0, 3.8), -90.0)
	_build_gambling()


## Une enseigne au néon : du texte qui brille, et une lumière colorée qui déborde sur la façade.
func _neon(text: String, pos: Vector3, rot_y: float, color: Color, size := 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = serif
	l.font_size = size
	l.pixel_size = 0.009
	l.modulate = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2)
	l.outline_size = 18
	l.outline_modulate = Color(color.r, color.g, color.b, 0.35)
	l.shaded = false
	l.position = pos
	l.rotation_degrees.y = rot_y
	add_child(l)
	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 1.4
	glow.omni_range = 3.0
	glow.position = pos + Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, 0, 0.6)
	add_child(glow)
	return l


func _build_gambling() -> void:
	# Les machines à sous alignées sous la façade du café.
	for z in [-2.6, -1.8, 1.0, 1.8]:
		_place(KA + "gambling-machine.glb", Vector3(-6.7, 0, z), 1.0, 90.0)
	var cafe_glow := OmniLight3D.new()
	cafe_glow.light_color = Color(1.0, 0.75, 0.3)
	cafe_glow.light_energy = 2.0
	cafe_glow.omni_range = 4.0
	cafe_glow.position = Vector3(-6.0, 1.0, -0.6)
	add_child(cafe_glow)
	_neon("JACKPOT", Vector3(-6.3, 3.4, -0.6), 90.0, Color(1.0, 0.3, 0.7), 96)
	_neon("Café de la Place · Tabac · Jeux", Vector3(-6.3, 2.75, -0.6), 90.0, Color(1.0, 0.8, 0.4), 40)

	# La roue de la kermesse sur le parvis, la boulangerie qui vend des grilles avec le pain.
	_place(KA + "prize-wheel.glb", Vector3(2.6, 0.3, -3.4), 1.6, -20.0)
	_neon("ROUE DE LA FORTUNE", Vector3(0.4, 4.9, -4.1), 0.0, Color(0.6, 0.9, 1.0), 56)
	_place("res://assets/kenney/market/display-bread.glb", Vector3(7.0, 0, -1.6), 1.2, -90.0)
	_place(KA + "claw-machine.glb", Vector3(7.0, 0, -0.4), 1.1, -90.0)
	_neon("PAIN · LOTO · GRATTAGE", Vector3(6.6, 2.5, -1.2), -90.0, Color(0.5, 1.0, 0.6), 44)
	_neon("LOTO CE SOIR", Vector3(-7.4, 2.6, 4.4), 90.0, Color(1.0, 0.85, 0.3), 56)
	_neon("CRÉDIT SMARVOIS", Vector3(6.7, 3.1, 3.8), -90.0, Color(0.4, 0.6, 1.0), 52)
	_neon("Investissez dans votre avenir", Vector3(6.7, 2.55, 3.8), -90.0, Color(0.4, 0.6, 1.0), 34)
	_neon("MAIRIE", Vector3(-4.6, 3.2, -3.6), 0.0, Color(1.0, 0.95, 0.85), 48)

	# La terrasse du café.
	for t in [Vector3(-5.4, 0, -2.2), Vector3(-5.4, 0, 1.4)]:
		_place(KK + "furniture/table_small.gltf", t, 0.32)
		_place(KK + "furniture/chair_A.gltf", t + Vector3(-0.45, 0, 0), 0.3, 90.0)
		_place(KK + "furniture/chair_A.gltf", t + Vector3(0.45, 0, 0), 0.3, -90.0)

	# Le tableau des cotes de la pétanque, et le banc de celui qui a tout misé.
	_neon("COTES DU JOUR\nLucien 3 contre 1\nles Rabelais 7 contre 2", Vector3(4.5, 1.4, 4.4), 0.0, Color(1.0, 1.0, 0.9), 30)
	_place(KK + "city/bench.gltf", Vector3(-2.0, 0, 4.6), 2.6, 180.0)


func _add_place_marker(id: String, parent: Node3D, at: Vector3, size: Vector3) -> void:
	if _place_info(id).is_empty():
		return
	var label := Label3D.new()
	label.font = serif
	label.font_size = 48
	label.pixel_size = 0.007 / parent.scale.x
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = at
	parent.add_child(label)
	place_signs[id] = label
	# Zone cliquable autour du bâtiment.
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size + Vector3(0.6, 0.6, 0.6)
	shape.shape = b
	shape.position = Vector3(0, size.y / 2.0, 0)
	area.add_child(shape)
	area.set_meta("place", id)
	parent.add_child(area)


func _place_info(id: String) -> Dictionary:
	for p in PLACES:
		if p.id == id:
			return p
	return {}


# --- Arbres, guirlandes, fleurs ---------------------------------------------------

func _build_trees_and_lights() -> void:
	# Les platanes le long de la route.
	var planes := [Vector3(-7.0, 0, 5.0), Vector3(-2.5, 0, 5.0), Vector3(2.0, 0, 5.0), Vector3(6.5, 0, 5.0)]
	for p in planes:
		_place(KK + "medieval_decoration/nature/tree_single_A.gltf", p, 2.8, randf() * 360.0)
	for i in planes.size() - 1:
		_garland(planes[i] + Vector3(0, 2.4, 0), planes[i + 1] + Vector3(0, 2.4, 0), 0.8)
		_bunting(planes[i] + Vector3(0, 2.0, 0.1), planes[i + 1] + Vector3(0, 2.0, 0.1), 0.6)
	# Fanions en cartes à jouer à travers la place.
	_bunting(Vector3(-6.8, 3.0, -2.8), Vector3(0.4, 3.4, -1.2), 0.9)
	_bunting(Vector3(0.4, 3.4, -1.2), Vector3(7.2, 2.8, -2.4), 0.9)
	_garland(Vector3(-6.8, 2.7, 1.6), Vector3(-2.5, 2.4, 5.0), 0.6)
	_garland(Vector3(-6.8, 2.7, -2.8), Vector3(0.6, 3.0, -1.4), 0.7)
	# Réverbères.
	for p in [Vector3(-4.0, 0, -3.6), Vector3(3.0, 0, -3.6), Vector3(-4.2, 0, 3.6), Vector3(3.8, 0, 0.6), Vector3(7.0, 0, 4.9)]:
		_place(KK + "city/streetlight.gltf", p, 2.2, 180.0)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.45)
		l.light_energy = 1.8
		l.omni_range = 4.5
		l.light_volumetric_fog_energy = 1.2
		l.position = p + Vector3(0.45, 2.0, 0)
		add_child(l)
	# Massifs et tonneaux.
	for p in [Vector3(-2.8, 0, -3.8), Vector3(-1.6, 0, -3.8)]:
		_place(KK + "city/bush.gltf", p, 2.5)
	for p in [Vector3(-7.0, 0, 3.0), Vector3(7.2, 0, 1.4), Vector3(7.4, 0, 1.8)]:
		_place(KK + "medieval_decoration/props/barrel.gltf", p, 2.4, randf() * 360.0)
	# Les voitures qui passent sur la route, phares allumés.
	for k in 2:
		var car := _place(KK + "city/%s.gltf" % ["car_taxi", "car_stationwagon"][k], Vector3(-11.0 + k * 12.0, 0, 6.0 if k == 0 else 6.9), 1.9, 90.0 if k == 0 else -90.0)
		for side in [-0.12, 0.12]:
			var beam := SpotLight3D.new()
			beam.light_color = Color(1.0, 0.92, 0.75)
			beam.light_energy = 3.0
			beam.spot_range = 6.0
			beam.spot_angle = 30.0
			beam.position = Vector3(side, 0.18, 0.5)
			beam.rotation_degrees.x = -8.0
			beam.rotation_degrees.y = 180.0
			car.add_child(beam)
		moving_cars.append(car)
	# Les voitures garées.
	_place(KK + "city/car_sedan.gltf", Vector3(-5.0, 0, 6.1), 1.9, 90.0)
	_place(KK + "city/car_hatchback.gltf", Vector3(4.5, 0, 6.7), 1.9, -90.0)


## Des fanions en cartes à jouer qui pendent entre deux points.
func _bunting(a: Vector3, b: Vector3, sag: float) -> void:
	var n := int(a.distance_to(b) / 0.35)
	var suits := ["♥", "♠", "♦", "♣"]
	var flag := PrismMesh.new()
	flag.size = Vector3(0.24, 0.3, 0.01)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.93, 0.88)
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.15, 0.15)
	red.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(1, n):
		var t := float(i) / n
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var m := MeshInstance3D.new()
		m.mesh = flag
		m.material_override = white if i % 2 == 0 else red
		m.position = p - Vector3(0, 0.15, 0)
		m.rotation = Vector3(PI, atan2(b.x - a.x, b.z - a.z) + PI / 2.0, 0)
		add_child(m)
		var l := Label3D.new()
		l.text = suits[i % 4]
		l.font_size = 48
		l.pixel_size = 0.002
		l.modulate = Color(0.1, 0.1, 0.1) if i % 2 == 0 else Color(1, 1, 1)
		l.double_sided = true
		l.position = Vector3(0, 0.03, 0.01)
		l.rotation = Vector3(PI, 0, 0)
		m.add_child(l)


## Une guirlande d'ampoules qui pend entre deux points.
func _garland(a: Vector3, b: Vector3, sag: float) -> void:
	var n := int(a.distance_to(b) / 0.45)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.1
	s.material = bulb_material
	mm.mesh = s
	mm.instance_count = n + 1
	var wire := PackedVector3Array()
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		mm.set_instance_transform(i, Transform3D(Basis(), p))
		wire.append(p)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	# Une lumière toutes les quatre ampoules, pour que la guirlande éclaire vraiment.
	for i in range(2, n, 4):
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.4)
		l.light_energy = 0.6
		l.omni_range = 2.6
		l.light_volumetric_fog_energy = 1.5
		l.position = wire[i]
		add_child(l)


# --- Les habitants ---------------------------------------------------------------------

func _villager(model: String, pos: Vector3, rot_y: float, pose := "idle", route: Array = [], acc := "", spk := "habitant") -> Node3D:
	var v: Node3D = VILLAGER.new()
	v.accessory = acc
	v.speaker = spk
	v.model_path = KC + model
	v.pose = pose
	v.route.assign(route)
	v.position = pos
	v.rotation_degrees.y = rot_y
	add_child(v)
	villagers.append(v)
	return v


func _build_villagers() -> void:
	# En terrasse.
	_villager("character-male-b.glb", Vector3(-5.85, 0.07, -2.2), 90.0, "sit", [], "", "dede")
	_villager("character-female-c.glb", Vector3(-4.95, 0.07, -2.2), -90.0, "sit", [], "collier", "josiane")
	_villager("character-male-d.glb", Vector3(-4.95, 0.07, 1.4), -90.0, "sit")
	# Les boulistes.
	_villager("character-male-f.glb", Vector3(2.6, 0, 3.0), 90.0, "idle", [], "chapeau", "lucien")
	_villager("character-male-a.glb", Vector3(3.0, 0, 2.3), 70.0)
	_villager("character-female-a.glb", Vector3(6.6, 0, 3.4), -100.0)
	# Les spectateurs et les passants.
	_villager("character-female-e.glb", Vector3(2.8, 0, 4.6), 160.0)
	_villager("character-male-e.glb", Vector3(-2.0, 0, 1.0), 0.0, "idle",
		[Vector3(-2.0, 0, 1.0), Vector3(2.0, 0, 0.6), Vector3(5.6, 0, -1.0), Vector3(1.0, 0, -3.0)])
	_villager("m-brunet", Vector3(7.2, 0, 3.0), -90.0, "idle", [], "cravate", "brunet")
	_villager("character-female-b.glb", Vector3(-3.0, 0, -3.2), 0.0, "idle",
		[Vector3(-3.0, 0, -3.2), Vector3(-4.2, 0, 3.4), Vector3(0.0, 0, 3.6)])


# --- Économie -----------------------------------------------------------------------

func spend(amount: int) -> bool:
	return Game.spend(amount)


func _on_slot_played(bet: int, payout: int) -> void:
	Sfx.result(bet, payout)
	var before := Game.won
	Game.cash_in(payout)
	for v in villagers:
		if v.position.x < -4.0 and randf() < 0.6:
			v.react("win" if payout >= bet * 10 else "lose")
	if payout >= bet * 20:
		_announce("Jackpot ! Toute la terrasse se lève.")
	_check_unlocks(before)
	if Game.advance_if_broke(SLOT.BETS[0]):
		_announce("Josiane vous avance %d crédits. « Un placement, ça se soutient. »" % Game.ADVANCE)


func _check_unlocks(before: int) -> void:
	for p in PLACES:
		if p.seuil > 0 and before < p.seuil and Game.won >= p.seuil:
			_announce("%s vous fait signe : %s est ouvert." % [p.host, p.name])
	_refresh_places()


func is_open(id: String) -> bool:
	var p := _place_info(id)
	return not p.is_empty() and Game.won >= p.seuil


# --- Interaction ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _slot.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var from := camera.project_ray_origin(event.position)
		var q := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(event.position) * 200.0)
		q.collide_with_areas = true
		q.collide_with_bodies = false
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit and hit.collider.has_meta("talk"):
			var v: Node = hit.collider.get_parent()
			v.say(Lines.line(v.speaker))
		elif hit and hit.collider.has_meta("travel"):
			travel(hit.collider.get_meta("travel"))
		elif hit and hit.collider.has_meta("place"):
			_enter(hit.collider.get_meta("place"))


func _enter(id: String) -> void:
	var p := _place_info(id)
	if p.is_empty():
		return
	if not is_open(id):
		_announce("%s : encore fermé. Il faut avoir gagné %s crédits au jeu." % [p.name, _fmt(p.seuil)])
		return
	if id == "banque":
		camera.focus(Vector3(7.6, 1.6, 3.8), 5.5, deg_to_rad(-90.0), deg_to_rad(-28.0))
		var loan: PanelContainer = LOAN.new()
		loan.closed.connect(func():
			loan.queue_free()
			_hint.visible = true
			camera.release())
		_slot.get_parent().add_child(loan)
		_hint.visible = false
		return
	if id == "casino":
		get_tree().change_scene_to_file("res://scenes/casino.tscn")
		return
	if id != "cafe":
		var panel := _game_panel(id)
		if panel == null:
			_announce("%s est ouvert, mais %s n'est pas encore installé." % [p.name, p.game])
			return
		if FOCUS.has(id):
			var f: Array = FOCUS[id]
			camera.focus(f[0], f[1], deg_to_rad(f[2]), deg_to_rad(f[3]))
		panel.played.connect(_on_game_played)
		panel.closed.connect(func():
			panel.queue_free()
			_hint.visible = true
			camera.release())
		_slot.get_parent().add_child(panel)
		_hint.visible = false
		return
	camera.focus(Vector3(-6.7, 0.8, -2.2), 5.0, deg_to_rad(70.0), deg_to_rad(-14.0))
	_slot.visible = true
	_hint.visible = false


func _build_signposts() -> void:
	for sp in SIGNPOSTS:
		var root := Node3D.new()
		root.position = sp[1]
		root.rotation_degrees.y = sp[2]
		add_child(root)
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.45, 0.28, 0.14)
		_box(Vector3(0.12, 2.2, 0.12), Vector3(0, 1.1, 0), wood, root)
		_box(Vector3(2.6, 0.5, 0.08), Vector3(0, 1.9, 0), wood, root)
		var l := Label3D.new()
		l.text = sp[3]
		l.font = serif
		l.font_size = 44
		l.pixel_size = 0.005
		l.modulate = Color(1.0, 0.92, 0.75)
		l.outline_size = 0
		l.position = Vector3(0, 1.9, 0.05)
		root.add_child(l)
		var back_l := l.duplicate()
		back_l.position.z = -0.05
		back_l.rotation_degrees.y = 180
		root.add_child(back_l)
		var area3 := Area3D.new()
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(2.8, 2.4, 0.8)
		cs.shape = b
		cs.position.y = 1.2
		area3.add_child(cs)
		area3.set_meta("travel", sp[0])
		root.add_child(area3)


## Part en promenade vers un des environs (ou revient sur la place avec « place »).
func travel(where: String) -> void:
	area = where
	if where == "place":
		camera.go_to(Vector3(0, 0.3, 0))
		_back.visible = false
		_announce("La place de la Mairie.")
		return
	var a: Dictionary = OUTSKIRTS.AREAS[where]
	camera.go_to(a.center + Vector3(0, 0.3, 0))
	_back.visible = true
	_announce("%s." % a.name)


## Le jeu de chaque lieu du village, sur les règles du casino.
func _game_panel(id: String) -> Control:
	match id:
		"petanque":
			var r: PanelContainer = RACE.new()
			r.title = "Les paris de Lucien"
			r.subtitle = "Partie en 13 points sur la place  ·  cotes à la craie"
			r.verb = "gagne la partie"
			r.runners = [["Lucien et Dédé", 1.5], ["Les Rabelais", 3.0], ["Les jeunes du Clain", 5.0]]
			return r
		"boulangerie":
			var ro: PanelContainer = ROULETTE.new()
			ro.title = "La roulette du comptoir"
			return ro
		"rabelais":
			return LOTO.new()
		"eglise":
			var w: PanelContainer = WHEEL.new()
			w.mode = "roue"
			w.title = "La roue de la kermesse"
			return w
		"zebres":
			var z: PanelContainer = RACE.new()
			z.title = "La course des trois zèbres"
			z.subtitle = "Allée du château, bois de Saint-Pierre  ·  paris à la cote"
			z.verb = "franchit la ligne"
			z.runners = [["Zébulon", 2.0], ["Zéphyr", 3.0], ["Zoé", 4.0]]
			return z
		"passelourdin":
			var pk: PanelContainer = POKER.new()
			pk.title = "La partie des rochers de Passelourdin"
			pk.regulars = [["le Notaire", 0.6, 0.6], ["la Meunière", 0.3, 0.4], ["Gégé", 0.2, 0.9], ["l'Inconnu", 0.8, 0.7], ["le Docteur", 0.45, 0.3]]
			return pk
		"moulin":
			var b: PanelContainer = BLACKJACK.new()
			b.title = "Le blackjack du Moulin des Dames"
			return b
	return null


func _on_game_played(bet: int, payout: int) -> void:
	_on_slot_played(bet, payout)


func _leave_slot() -> void:
	_slot.visible = false
	_hint.visible = true
	camera.release()


# --- Interface -------------------------------------------------------------------------

func _fmt(n: int) -> String:
	return Game.fmt(n)


func _list_enter(id: String) -> void:
	for key in OUTSKIRTS.AREAS:
		if OUTSKIRTS.AREAS[key].place == id and area != key:
			travel(key)
			return
	if area != "" and area != "place" and not FOCUS.has(id) and id != "cafe" and id != "banque" and id != "casino":
		travel("place")
	_enter(id)


func _refresh_places() -> void:
	for c in _places_box.get_children():
		c.queue_free()
	for p in PLACES:
		var open: bool = Game.won >= p.seuil
		# Chaque ligne est un bouton : on peut aller jouer dans les lieux hors de la place.
		var l := Button.new()
		l.flat = true
		l.alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.add_theme_font_size_override("font_size", 15)
		if open:
			l.text = "●  %s  —  %s" % [p.name, p.game]
			l.add_theme_color_override("font_color", Color(0.96, 0.82, 0.5))
			l.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
		else:
			l.text = "○  %s  —  %s gagnés" % [p.name, _fmt(p.seuil)]
			l.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		l.pressed.connect(_list_enter.bind(p.id))
		_places_box.add_child(l)
		if place_signs.has(p.id):
			var s: Label3D = place_signs[p.id]
			s.text = p.name if open else "%s\nfermé · %s" % [p.name, _fmt(p.seuil)]
			s.modulate = Color(1.0, 0.85, 0.5) if open else Color(0.7, 0.72, 0.8, 0.85)


func _announce(text: String) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(_banner, "modulate:a", 0.0, 1.0)


var _bark_timer := 3.0


## De temps en temps, un habitant près de la caméra dit quelque chose : souvent une rumeur.
func _bark(delta: float) -> void:
	_bark_timer -= delta
	if _bark_timer > 0.0:
		return
	_bark_timer = randf_range(9.0, 16.0)
	var near: Array[Node3D] = []
	for v in villagers:
		if v.global_position.distance_to(camera.target) < 13.0:
			near.append(v)
	if near.is_empty():
		return
	var v: Node3D = near.pick_random()
	if randf() < 0.45:
		# Une rumeur sur le prochain lieu à ouvrir, ou sur un lieu déjà ouvert.
		var next := ""
		for p in PLACES:
			if Game.won < p.seuil:
				next = p.id
				break
		var pool: Array = [next] if next != "" else []
		for p in PLACES:
			if Game.won >= p.seuil and Lines.RUMORS.has(p.id):
				pool.append(p.id)
		var key: String = pool.pick_random() if not pool.is_empty() else "casino"
		if Lines.RUMORS.has(key):
			v.say(Lines.RUMORS[key])
			return
	v.say(Lines.line(v.speaker))


func _process(delta: float) -> void:
	_bark(delta)
	for i in moving_cars.size():
		var car := moving_cars[i]
		var dir := 1.0 if i == 0 else -1.0
		car.position.x += dir * (2.2 + i * 0.6) * delta
		if car.position.x > 12.5:
			car.position.x = -12.5
		elif car.position.x < -12.5:
			car.position.x = 12.5
	shown_credits = lerpf(shown_credits, Game.credits, 1.0 - exp(-10.0 * delta))
	if absf(shown_credits - Game.credits) < 0.5:
		shown_credits = Game.credits
	_credits_label.text = "%s crédits" % _fmt(roundi(shown_credits))
	_won_label.text = "Gagné au jeu : %s" % _fmt(Game.won) + ("
Dette au Crédit Smarvois : %s" % _fmt(Game.debt) if Game.debt > 0 else "")


func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font = serif
	theme.default_font_size = 20
	var gold_col := Color(0.96, 0.8, 0.45)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.04, 0.045, 0.07, 0.8)
	panel.border_color = Color(0.8, 0.6, 0.3, 0.55)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(16)
	theme.set_stylebox("panel", "PanelContainer", panel)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color(0.12, 0.08, 0.04, 0.9), "hover": Color(0.25, 0.16, 0.06, 0.95),
			"pressed": Color(0.35, 0.22, 0.08, 1.0), "disabled": Color(0.07, 0.07, 0.09, 0.8),
			"focus": Color(0, 0, 0, 0)}[st]
		b.border_color = Color(0.85, 0.62, 0.3, 0.25 if st == "disabled" else 0.8)
		b.set_border_width_all(1)
		b.set_corner_radius_all(3)
		b.content_margin_left = 16
		b.content_margin_right = 16
		b.content_margin_top = 8
		b.content_margin_bottom = 8
		if st == "focus":
			b.draw_center = false
			b.border_color = Color(0, 0, 0, 0)
		theme.set_stylebox(st, "Button", b)
	theme.set_color("font_color", "Button", gold_col)
	theme.set_color("font_hover_color", "Button", Color(1, 0.92, 0.7))
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.42))
	theme.set_color("font_color", "Label", Color(0.88, 0.85, 0.8))

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
	title.text = "S M A R V E S"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.7, 0.62, 0.5))
	v.add_child(title)
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 40)
	_credits_label.add_theme_color_override("font_color", gold_col)
	v.add_child(_credits_label)
	_won_label = Label.new()
	_won_label.add_theme_font_size_override("font_size", 16)
	v.add_child(_won_label)

	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.position += Vector2(-28, 24)
	root.add_child(right)
	var rv := VBoxContainer.new()
	right.add_child(rv)
	var rt := Label.new()
	rt.text = "Le village"
	rt.add_theme_font_size_override("font_size", 18)
	rt.add_theme_color_override("font_color", gold_col)
	rv.add_child(rt)
	_places_box = VBoxContainer.new()
	rv.add_child(_places_box)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.position.y += 150
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 24)
	_banner.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	_hint = Label.new()
	_hint.text = "Cliquer sur un lieu ouvert pour y jouer   ·   Clic droit : tourner   ·   Molette : zoomer"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 0.85))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.position.y -= 22
	root.add_child(_hint)

	_back = Button.new()
	_back.text = "←  Retour sur la place"
	_back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_back.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_back.position += Vector2(28, -60)
	_back.visible = false
	_back.pressed.connect(travel.bind("place"))
	root.add_child(_back)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_slot = SLOT.new()
	_slot.game = self
	_slot.visible = false
	_slot.played.connect(_on_slot_played)
	_slot.closed.connect(_leave_slot)
	center.add_child(_slot)


# --- Capture d'écran : godot -- --capture=chemin.png [--open=cafe] [--view=d,x,y] ---

func _maybe_capture() -> void:
	var path := ""
	var open := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--open="):
			open = arg.trim_prefix("--open=")
		elif arg.begins_with("--travel="):
			await get_tree().process_frame
			travel(arg.trim_prefix("--travel="))
		elif arg.begins_with("--won="):
			Game.won = int(arg.trim_prefix("--won="))
			Game.credits += 2000
			_refresh_places()
	if path == "":
		return
	if open != "":
		await get_tree().create_timer(1.0).timeout
		_enter(open)
		await get_tree().create_timer(1.5).timeout
		if open == "cafe":
			_slot.spin()
		elif open == "banque":
			for c in _slot.get_parent().get_children():
				if c.has_method("_borrow"):
					c._borrow(500)
					c._borrow(1000)
	await get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
