extends Node3D
## Les environs de Smarves, chacun sur son propre socle, à l'écart de la place : le bois de Saint-Pierre
## et ses trois zèbres en béton, le Moulin des Dames sur le Miosson, les rochers de Passelourdin.
## On s'y rend depuis les panneaux de la place ; la caméra voyage d'un socle à l'autre.

const KK := "res://assets/kaykit/"
const KN := "res://assets/kenney/nature/"

const AREAS := {
	"bois": {"name": "Le bois de Saint-Pierre", "center": Vector3(70, 0, 0), "place": "zebres"},
	"moulin": {"name": "Le Moulin des Dames", "center": Vector3(-70, 0, 0), "place": "moulin"},
	"passelourdin": {"name": "Les rochers de Passelourdin", "center": Vector3(0, 0, -70), "place": "passelourdin"},
}

var main: Node3D
var grass: StandardMaterial3D
var gravel: StandardMaterial3D
var walnut: StandardMaterial3D


func build(m: Node3D) -> void:
	main = m
	grass = StandardMaterial3D.new()
	grass.albedo_color = Color(0.2, 0.32, 0.16)
	grass.albedo_texture = main._noise_tex(false, 0.08, Color(0.75, 0.8, 0.7))
	grass.uv1_triplanar = true
	grass.roughness = 1.0
	gravel = StandardMaterial3D.new()
	gravel.albedo_color = Color(0.72, 0.66, 0.55)
	gravel.albedo_texture = main._noise_tex(false, 0.4, Color(0.75, 0.72, 0.68))
	gravel.uv1_triplanar = true
	gravel.roughness = 1.0
	walnut = StandardMaterial3D.new()
	walnut.albedo_color = Color(0.17, 0.09, 0.05)
	walnut.roughness = 0.4
	_bois(AREAS.bois.center)
	_moulin(AREAS.moulin.center)
	_passelourdin(AREAS.passelourdin.center)
	for k in AREAS:
		_home_sign(AREAS[k].center)


func _plinth(c: Vector3, title: String, ground: Material) -> void:
	main._box(Vector3(22.6, 0.8, 16.6), c + Vector3(0, -0.5, 0), walnut)
	main._box(Vector3(22, 0.1, 16), c + Vector3(0, -0.05, 0), ground)
	var plaque := Label3D.new()
	plaque.text = title.to_upper()
	plaque.font = main.serif
	plaque.font_size = 80
	plaque.pixel_size = 0.004
	plaque.modulate = Color(0.95, 0.75, 0.4)
	plaque.position = c + Vector3(0, -0.5, 8.31)
	main.add_child(plaque)


func _p(path: String, pos: Vector3, scale := 1.0, rot := 0.0) -> Node3D:
	var n: Node3D = main._place(path, pos, scale, rot)
	# Bâtiments, rochers et arbres font obstacle quand on se promène à pied ; les arbres par leur tronc.
	if path.contains("building") or path.contains("wall_") or path.contains("mountain"):
		main._solid(n, 0.85)
	elif path.contains("tree") or path.contains("rock_single"):
		main._solid(n, 0.3)
	return n


## Le panneau du chemin du retour, à l'arrivée sur chaque socle.
func _home_sign(c: Vector3) -> void:
	var root := Node3D.new()
	root.position = c + Vector3(1.4, 0, 7.2)
	main.add_child(root)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.28, 0.14)
	main._box(Vector3(0.08, 1.2, 0.08), Vector3(0, 0.6, 0), wood, root)
	main._box(Vector3(1.4, 0.3, 0.06), Vector3(0, 1.05, 0), wood, root)
	var l := Label3D.new()
	l.text = "Place de la Mairie  ↓"
	l.font = main.serif
	l.font_size = 40
	l.pixel_size = 0.003
	l.modulate = Color(1.0, 0.92, 0.75)
	l.outline_size = 0
	l.position = Vector3(0, 1.05, 0.04)
	l.double_sided = true
	root.add_child(l)
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.6, 1.4, 0.6)
	cs.shape = b
	cs.position.y = 0.7
	a.add_child(cs)
	a.set_meta("travel", "place")
	a.set_meta("interact", "travel")
	a.set_meta("prompt", "E : rentrer sur la place de la Mairie")
	root.add_child(a)


func _lamp(pos: Vector3, energy := 1.6, color := Color(1.0, 0.75, 0.45), range_m := 4.5) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.light_volumetric_fog_energy = 1.2
	l.position = pos
	main.add_child(l)


## Une zone cliquable qui ouvre le jeu du lieu.
func _attraction(place_id: String, at: Vector3, size: Vector3, sign_at: Vector3) -> void:
	var n := Node3D.new()
	n.position = at
	main.add_child(n)
	main._add_place_marker(place_id, n, sign_at - at, size)


# --- Le bois de Saint-Pierre --------------------------------------------------------------

func _bois(c: Vector3) -> void:
	_plinth(c, "Bois de Saint-Pierre", grass)
	# L'allée du château, en gravier, bordée de lanternes.
	main._box(Vector3(3.0, 0.11, 15.0), c + Vector3(0, -0.04, 0.0), gravel)
	for z in [-5.0, -1.0, 3.0]:
		for x in [-1.9, 1.9]:
			_p(KK + "city/streetlight.gltf", c + Vector3(x, 0, z), 2.0, 0.0 if x < 0 else 180.0)
			_lamp(c + Vector3(x * 0.8, 1.9, z))
	# Le château en ruine au bout de l'allée.
	_p(KK + "medieval_buildings/neutral/building_destroyed.gltf", c + Vector3(0, 0, -6.2), 3.6)
	_p(KK + "medieval_buildings/neutral/wall_straight_gate.gltf", c + Vector3(-4.0, 0, -6.6), 2.2)
	_p(KK + "medieval_buildings/neutral/wall_straight.gltf", c + Vector3(4.0, 0, -6.6), 2.2)
	# Les trois zèbres de béton peint, et leur piste de course.
	main._box(Vector3(9.0, 0.12, 3.0), c + Vector3(-6.0, -0.03, 3.5), gravel)
	var zebra := ShaderMaterial.new()
	zebra.shader = load("res://shaders/zebra.gdshader")
	for i in 3:
		_zebra(c + Vector3(-9.5, 0, 2.5 + i * 1.0), zebra, 90.0)
		main._box(Vector3(0.05, 0.13, 3.0), c + Vector3(-1.6, -0.02, 3.5), main.pave_material)
	for i in 4:
		main._box(Vector3(9.0, 0.13, 0.04), c + Vector3(-6.0, -0.02, 2.0 + i * 1.0), main.bulb_material)
	main._neon("COURSE DES ZÈBRES", c + Vector3(-6.0, 2.4, 1.6), 0.0, Color(1.0, 0.95, 0.8), 56)
	main._neon("Paris à la cote · départ toutes les cinq minutes", c + Vector3(-6.0, 1.9, 1.6), 0.0, Color(1.0, 0.8, 0.4), 30)
	_attraction("zebres", c + Vector3(-6.0, 0, 3.5), Vector3(9.0, 2.0, 3.2), c + Vector3(-6.0, 3.6, 3.5))
	# Arbres serrés tout autour.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1983
	for k in 26:
		var p := Vector3(rng.randf_range(-10.5, 10.5), 0, rng.randf_range(-7.5, 7.5))
		if absf(p.x) < 2.6 or (p.x < -1.0 and p.z > 1.0 and p.z < 6.0):
			continue
		var model: String = ["trees_A_large", "trees_A_medium", "trees_B_large", "trees_B_medium", "tree_single_A", "tree_single_B"][rng.randi() % 6]
		_p(KK + "medieval_decoration/nature/%s.gltf" % model, c + p, rng.randf_range(2.0, 2.8), rng.randf() * 360.0)
	# Le gardien du bois et les parieurs.
	main._villager("gardien-du-bois", c + Vector3(-1.2, 0, 4.6), -100.0, "idle", [], "chapeau", "gardien")
	main._villager("parieur-bois-1", c + Vector3(-4.0, 0, 5.6), 180.0)
	main._villager("parieur-bois-2", c + Vector3(-7.5, 0, 5.4), 160.0)
	main._villager("promeneuse-bois", c + Vector3(0.5, 0, 2.0), 0.0, "idle", [c + Vector3(0.5, 0, 2.0), c + Vector3(-0.5, 0, -4.5)])


## Un zèbre de béton peint, à la manière des statues de 1983 de l'allée du château.
func _zebra(pos: Vector3, mat: Material, rot: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot
	main.add_child(root)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 0.85
	body.mesh = cap
	body.rotation_degrees.x = 90
	body.position = Vector3(0, 0.62, 0)
	body.material_override = mat
	root.add_child(body)
	var neck := MeshInstance3D.new()
	var nc := CapsuleMesh.new()
	nc.radius = 0.09
	nc.height = 0.45
	neck.mesh = nc
	neck.rotation_degrees.x = 35
	neck.position = Vector3(0, 0.88, 0.36)
	neck.material_override = mat
	root.add_child(neck)
	var head := MeshInstance3D.new()
	var hc := CapsuleMesh.new()
	hc.radius = 0.08
	hc.height = 0.3
	head.mesh = hc
	head.rotation_degrees.x = 100
	head.position = Vector3(0, 1.05, 0.56)
	head.material_override = mat
	root.add_child(head)
	for e in [-0.05, 0.05]:
		var ear := MeshInstance3D.new()
		var ec := CylinderMesh.new()
		ec.top_radius = 0.0
		ec.bottom_radius = 0.03
		ec.height = 0.1
		ear.mesh = ec
		ear.position = Vector3(e, 1.16, 0.5)
		ear.material_override = mat
		root.add_child(ear)
	for x in [-0.11, 0.11]:
		for z in [-0.25, 0.25]:
			var leg := MeshInstance3D.new()
			var lc := CapsuleMesh.new()
			lc.radius = 0.05
			lc.height = 0.5
			leg.mesh = lc
			leg.position = Vector3(x, 0.25, z)
			leg.material_override = mat
			root.add_child(leg)


# --- Le Moulin des Dames ---------------------------------------------------------------------

func _moulin(c: Vector3) -> void:
	_plinth(c, "Moulin des Dames", grass)
	# Le Miosson qui traverse le socle.
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	main._box(Vector3(22, 0.1, 3.4), c + Vector3(0, -0.02, 3.2), water)
	var bank := StandardMaterial3D.new()
	bank.albedo_color = Color(0.3, 0.24, 0.18)
	for z in [1.45, 4.95]:
		main._box(Vector3(22, 0.16, 0.2), c + Vector3(0, 0.0, z), bank)
	# Le moulin, sa roue dans le bief, un pont de bois.
	_p(KK + "medieval_buildings/blue/building_watermill_blue.gltf", c + Vector3(-2.0, 0, -1.0), 4.6)
	main._place(KK + "medieval_buildings/neutral/building_bridge_A.gltf", c + Vector3(5.5, 0.12, 3.2), 2.0, 90.0)
	# On ne traverse le Miosson que par le pont.
	main._solid_box(Vector3(15.5, 2.0, 3.4), c + Vector3(-3.3, 1.0, 3.2))
	main._solid_box(Vector3(4.2, 2.0, 3.4), c + Vector3(8.9, 1.0, 3.2))
	for x in [-6.0, -0.4]:
		var win: MeshInstance3D = main._box(Vector3(0.6, 0.6, 0.05), c + Vector3(x * 0.5 - 1.6, 1.6, 1.25), main.window_material)
		win.name = "Fenetre"
	_lamp(c + Vector3(-2.0, 1.4, 2.0), 3.5, Color(1.0, 0.75, 0.45), 7.0)
	_lamp(c + Vector3(4.0, 2.0, 0.0), 1.8, Color(0.6, 0.7, 1.0), 9.0)
	main._neon("BLACKJACK · arrière-salle", c + Vector3(-2.0, 6.2, 0.8), 0.0, Color(1.0, 0.8, 0.4), 44)
	_attraction("moulin", c + Vector3(-2.0, 0, -1.0), Vector3(5.0, 5.5, 5.0), c + Vector3(-2.0, 7.2, 0.8))
	# Les berges : arbres, roseaux, nénuphars.
	var rng := RandomNumberGenerator.new()
	rng.seed = 962
	for k in 16:
		var p := Vector3(rng.randf_range(-10.5, 10.5), 0, rng.randf_range(-7.5, 7.5))
		if p.z > 0.8 and p.z < 5.6:
			continue
		if absf(p.x + 2.0) < 3.0 and p.z > -3.5:
			continue
		_p(KK + "medieval_decoration/nature/%s.gltf" % ["tree_single_A", "tree_single_B", "trees_B_medium"][rng.randi() % 3], c + p, rng.randf_range(2.2, 2.8), rng.randf() * 360.0)
	for k in 10:
		var x := rng.randf_range(-10.0, 10.0)
		_p(KK + "medieval_decoration/nature/waterlily_%s.gltf" % ["A", "B"][rng.randi() % 2], c + Vector3(x, 0.04, rng.randf_range(2.2, 4.3)), 1.6, rng.randf() * 360.0)
		_p(KK + "medieval_decoration/nature/waterplant_%s.gltf" % ["A", "B", "C"][rng.randi() % 3], c + Vector3(rng.randf_range(-10.0, 10.0), 0, [1.6, 4.8][rng.randi() % 2]), 2.0)
	main._villager("meunier", c + Vector3(1.0, 0, 0.6), -60.0, "idle", [], "chapeau", "meunier")
	main._villager("joueuse-moulin", c + Vector3(-4.6, 0, 0.9), 30.0)


# --- Les rochers de Passelourdin ------------------------------------------------------------

func _passelourdin(c: Vector3) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.32, 0.3, 0.3)
	stone.albedo_texture = main._noise_tex(false, 0.15, Color(0.7, 0.7, 0.72))
	stone.uv1_triplanar = true
	_plinth(c, "Rochers de Passelourdin", stone)
	# Les rochers en cercle, et l'abri où se tient la partie.
	var rng := RandomNumberGenerator.new()
	rng.seed = 86
	for k in 9:
		var a := TAU * k / 9.0 + 0.3
		if absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.5:
			continue  # l'ouverture vers le spectateur
		var p := Vector3(cos(a) * 6.5, 0, sin(a) * 4.8 - 0.5)
		_p(KK + "medieval_decoration/nature/%s.gltf" % ["mountain_A", "mountain_B", "mountain_C", "mountain_A_grass", "mountain_B_grass_trees"][rng.randi() % 5], c + p, rng.randf_range(2.6, 3.6), rng.randf() * 360.0)
	for k in 14:
		_p(KK + "medieval_decoration/nature/rock_single_%s.gltf" % ["A", "B", "C", "D", "E"][rng.randi() % 5], c + Vector3(rng.randf_range(-9.5, 9.5), 0, rng.randf_range(-6.5, 7.0)), rng.randf_range(3.0, 6.0), rng.randf() * 360.0)
	# La table clandestine : feutre usé, bougies, lanterne.
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color(0.05, 0.25, 0.14)
	main._box(Vector3(2.0, 0.08, 1.2), c + Vector3(0, 0.75, -1.0), felt)
	main._box(Vector3(1.9, 0.72, 1.1), c + Vector3(0, 0.36, -1.0), walnut)
	for x in [-0.6, 0.6]:
		var candle: MeshInstance3D = main._box(Vector3(0.05, 0.16, 0.05), c + Vector3(x, 0.87, -1.4), main.bulb_material)
		candle.name = "Bougie"
	_lamp(c + Vector3(0, 1.4, -1.0), 2.2, Color(1.0, 0.6, 0.3), 5.0)
	var mist := FogVolume.new()
	mist.size = Vector3(16.0, 2.0, 12.0)
	mist.position = c + Vector3(0, 0.6, 0)
	var fm := FogMaterial.new()
	fm.density = 0.25
	fm.albedo = Color(0.6, 0.65, 0.8)
	mist.material = fm
	main.add_child(mist)
	main._neon("PARTIE PRIVÉE", c + Vector3(0, 2.4, -2.2), 0.0, Color(0.8, 0.2, 0.25), 48)
	_attraction("passelourdin", c + Vector3(0, 0, -1.0), Vector3(3.0, 2.0, 2.4), c + Vector3(0, 3.1, -1.0))
	for k in 5:
		var a := PI + PI * k / 4.0
		main._villager("passelourdin-%d" % k, c + Vector3(cos(a) * 1.5, 0, -1.0 + sin(a) * 1.0), rad_to_deg(a) + 90.0, "idle", [], "chapeau" if k == 2 else "", "inconnu" if k == 2 else "habitant")
