extends "res://scripts/shop_interior.gd"
## L'Épicerie du Bourg, rue du Clain : un intérieur de décor, sans jeu ni vente (communes/smarves/
## INTENTIONS.md, scène 3). Mme Pineau au comptoir, la balance Roberval et les bocaux de bonbons, les
## rayons pleins jusqu'au plafond, le néon un peu vert, la cliente qui compte sa monnaie ; derrière le
## rideau de perles, l'arrière-boutique et la porte de la cour, où l'on décharge les lots du loto.
## Capture : godot --path . res://scenes/epicerie.tscn -- --capture=sortie.png [--at=x,z,lacet,tangage]

const BATCH := preload("res://scripts/village/mesh_batch.gd")

const NOM := "L'Épicerie du Bourg"
const HOTE := "Mme Pineau"
const LIGNES := [
	"« Le jambon du gros lot, c'est moi qui l'ai fourni. Je n'ai pas pris de carton : je l'ai déjà vendu. »",
	"« Un litre de rouge, une boîte de sardines et un ticket à gratter : le panier du samedi. »",
	"« Je fais crédit, comme M. Brunet. Sauf que moi, je note au crayon, et je n'oublie jamais. »",
	"« La vitrine réfrigérée, c'est le Crédit Smarvois qui me l'a avancée. Elle ne marche pas encore, mais elle est à moi. »",
	"« Les gens disent que le loto, c'est du hasard. Moi, je vends les cartons de bingo à côté des lentilles : c'est de la gestion. »",
]
## La cloison entre la boutique et l'arrière-boutique, et la baie du rideau de perles.
const CLOISON_Z := -1.6
const BAIE_X := 2.6

var _b := BATCH.new()
var _mats := {}


func _ready() -> void:
	shop = "epicerie"
	_serif = Polices.texte()
	W = 8.0
	D = 9.0
	H = 3.0
	_environment()
	var lino := _checker(Color(0.86, 0.82, 0.72), Color(0.72, 0.66, 0.56))
	_room(lino, _std(Color(0.9, 0.86, 0.74), 0.85), Color(0.95, 0.94, 0.9), Color(0.48, 0.58, 0.5))
	_mats = {"vrac": _vertex_mat(0.6), "brillant": _vertex_mat(0.25)}
	_cloison()
	_comptoir()
	_rayons()
	_gondole()
	_primeurs()
	_entree()
	_arriere_boutique()
	_lumieres()
	_b.commit(self, _mats, "Epicerie")
	_door()
	for a in find_children("*", "Area3D", true, false):
		if a.get_meta("interact", "") == "exit":
			a.set_meta("prompt", "E : sortir dans la rue du Clain")
	_gens()
	_build_ui()
	player = PLAYER.new()
	player.position = Vector3(0, 0, D / 2.0 - 1.2)
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("village")
	_maybe_capture()


func _vertex_mat(rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	return m


func _checker(a: Color, b: Color) -> StandardMaterial3D:
	# Le lino à damier, usé devant le comptoir.
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, a)
	img.set_pixel(1, 1, a)
	img.set_pixel(1, 0, b)
	img.set_pixel(0, 1, b)
	var m := _std(Color.WHITE, 0.45)
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(2.0, 2.0, 2.0)
	return m


func _place_name() -> String:
	return NOM


func say(text: String) -> void:
	_speech.text = "%s : %s" % [HOTE, text]
	_speech.modulate.a = 1.0
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = create_tween()
	_speech_tween.tween_interval(4.0 + text.length() * 0.04)
	_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.8)


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			Game.return_point = "epicerie"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Chargement.changer("res://scenes/main.tscn")
		"keeper":
			say(LIGNES.pick_random())
			var c: Node = _keeper.get_child(0)
			if c.has_method("gesture"):
				c.gesture("talk")
				c.talk(2.5)
		"cour":
			_speech.text = "La porte de la cour est calée ouverte : le livreur décharge les lots du loto, un jambon, une cocotte, un téléviseur."
			_speech.modulate.a = 1.0
			if _speech_tween:
				_speech_tween.kill()
			_speech_tween = create_tween()
			_speech_tween.tween_interval(6.0)
			_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.8)


# --- La pièce -----------------------------------------------------------------------------------

## La cloison de planches peintes, percée d'une baie à rideau de perles, et l'affiche du loto.
func _cloison() -> void:
	var t := 0.12
	var peint := _std(Color(0.84, 0.8, 0.66), 0.7)
	var g0 := BAIE_X - 0.5
	var g1 := BAIE_X + 0.5
	_box(Vector3(g0 + W / 2.0, H, t), Vector3((-W / 2.0 + g0) / 2.0, H / 2.0, CLOISON_Z), peint, true)
	_box(Vector3(W / 2.0 - g1, H, t), Vector3((g1 + W / 2.0) / 2.0, H / 2.0, CLOISON_Z), peint, true)
	_box(Vector3(1.0, H - 2.1, t), Vector3(BAIE_X, 2.1 + (H - 2.1) / 2.0, CLOISON_Z), peint)
	# Le rideau de perles : des fils de couleur, qu'on traverse.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := g0 + 0.04
	while x < g1 - 0.02:
		var c: Color = [Color(0.85, 0.3, 0.2), Color(0.95, 0.75, 0.2), Color(0.3, 0.55, 0.75), Color(0.9, 0.9, 0.85)][rng.randi() % 4]
		_b.box("brillant", Transform3D(), Vector3(x, 1.08, CLOISON_Z), Vector3(0.025, 2.0, 0.025), c)
		x += 0.06
	# L'affiche du grand loto, punaisée, et le calendrier du club de foot.
	var aff := Transform3D(Basis(), Vector3(BAIE_X + 0.78, 1.6, CLOISON_Z + 0.07))
	_b.box("vrac", aff, Vector3.ZERO, Vector3(0.62, 0.86, 0.01), Color(0.98, 0.9, 0.3))
	_b.box("vrac", aff, Vector3(0, 0.22, 0.004), Vector3(0.56, 0.2, 0.01), Color(0.75, 0.1, 0.1))
	_label3d("GRAND LOTO", aff.origin + Vector3(0, 0.22, 0.02), 34, Color(1, 0.95, 0.85))
	_label3d("Samedi 20 h 30\nSalle François-Rabelais\n1er lot : un jambon\net un téléviseur couleur", aff.origin + Vector3(0, -0.12, 0.02), 16, Color(0.2, 0.12, 0.08))


## Le comptoir de bois en L, le dessus de formica, la caisse, la balance, les bocaux, et Mme Pineau.
func _comptoir() -> void:
	var x0 := -W / 2.0 + 0.9
	var x1 := -0.9
	var z := -0.2
	var bois := Color(0.48, 0.3, 0.18)
	var xf := Transform3D()
	_b.box("vrac", xf, Vector3((x0 + x1) / 2.0, 0.48, z), Vector3(x1 - x0, 0.96, 0.6), bois)
	_b.box("brillant", xf, Vector3((x0 + x1) / 2.0, 0.98, z), Vector3(x1 - x0 + 0.06, 0.04, 0.66), Color(0.82, 0.84, 0.8))
	for i in int((x1 - x0) / 0.5):
		_b.box("vrac", xf, Vector3(x0 + 0.25 + i * 0.5, 0.48, z + 0.305), Vector3(0.42, 0.8, 0.01), bois.lightened(0.08))
	_b.box("vrac", xf, Vector3(x1 + 0.3, 0.48, z - 0.6), Vector3(0.6, 0.96, 1.8), bois)
	_b.box("brillant", xf, Vector3(x1 + 0.3, 0.98, z - 0.6), Vector3(0.66, 0.04, 1.86), Color(0.82, 0.84, 0.8))
	_solid_box_at(Vector3(x1 - x0 + 0.6, 1.0, 0.7), Vector3((x0 + x1 + 0.6) / 2.0, 0.5, z))
	_solid_box_at(Vector3(0.7, 1.0, 1.9), Vector3(x1 + 0.3, 0.5, z - 0.6))
	# La balance Roberval : le fléau, les deux plateaux de cuivre, les poids en rang.
	var bal := Transform3D(Basis(), Vector3(-2.0, 1.0, z))
	_b.box("brillant", bal, Vector3(0, 0.06, 0), Vector3(0.36, 0.12, 0.16), Color(0.85, 0.85, 0.82))
	for s in [-1.0, 1.0]:
		_b.cylinder("brillant", bal, Vector3(s * 0.14, 0.13, 0), 0.1, 0.02, Color(0.8, 0.55, 0.3), 12)
	for i in 5:
		_b.cylinder("brillant", bal, Vector3(0.28 + i * 0.05, 0.0, 0.05), 0.012 + i * 0.004, 0.03 + i * 0.01, Color(0.55, 0.5, 0.42), 6)
	# La caisse enregistreuse et son tiroir, le carnet de crédit au crayon.
	var caisse := Transform3D(Basis(Vector3.UP, 0.2), Vector3(-1.25, 1.0, z - 0.05))
	_b.box("brillant", caisse, Vector3(0, 0.12, 0), Vector3(0.4, 0.24, 0.34), Color(0.3, 0.3, 0.32))
	_b.box_tilted("brillant", caisse, Vector3(0, 0.26, 0.08), Vector3(0.38, 0.03, 0.18), 0.5, Color(0.86, 0.84, 0.78))
	_b.box("vrac", caisse, Vector3(0, 0.33, -0.1), Vector3(0.22, 0.12, 0.04), Color(0.1, 0.1, 0.1))
	_b.box("vrac", Transform3D(Basis(Vector3.UP, -0.3), Vector3(-2.7, 1.005, z + 0.1)), Vector3.ZERO, Vector3(0.18, 0.012, 0.24), Color(0.25, 0.42, 0.7))
	# Les bocaux de bonbons, couvercles rouges, sur le bord du comptoir.
	var bonbons := [Color(0.95, 0.35, 0.5), Color(0.95, 0.85, 0.25), Color(0.4, 0.8, 0.45), Color(0.98, 0.6, 0.2), Color(0.55, 0.35, 0.8)]
	for i in 5:
		var p := Transform3D(Basis(), Vector3(-3.25 + i * 0.22, 1.0, z + 0.18))
		_b.cylinder("brillant", p, Vector3.ZERO, 0.075, 0.18, bonbons[i], 10)
		_b.cylinder("brillant", p, Vector3(0, 0.18, 0), 0.06, 0.04, Color(0.75, 0.12, 0.1), 10)
	# Derrière, les étagères du tabac et des alcools, la pendule.
	var mur := -W / 2.0 + 0.2
	for k in 4:
		var y := 1.0 + k * 0.42
		_b.box("vrac", xf, Vector3(mur, y, -0.85), Vector3(0.32, 0.03, 2.6), bois.darkened(0.2))
		for i in 13:
			var c: Color = [Color(0.2, 0.42, 0.18), Color(0.55, 0.12, 0.12), Color(0.85, 0.8, 0.55), Color(0.35, 0.22, 0.12)][(i + k) % 4]
			if k < 2:
				_b.cylinder("brillant", xf, Vector3(mur, y + 0.015, -2.0 + i * 0.19), 0.04, 0.3, c, 6)
			else:
				_b.box("vrac", xf, Vector3(mur, y + 0.09, -2.0 + i * 0.19), Vector3(0.18, 0.17, 0.15), c.lightened(0.2))
	var pendule := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(mur + 0.02, 2.75, -0.8))
	_b.cylinder("vrac", pendule * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO), Vector3.ZERO, 0.17, 0.04, Color(0.96, 0.94, 0.88), 16)
	# Mme Pineau, derrière son comptoir.
	_keeper = Node3D.new()
	_keeper.position = Vector3(-2.0, 0, -1.0)
	add_child(_keeper)
	var c := CRITTER.new()
	c.randomize_look(1958)
	c.idle_anim = "attentive"
	c.scale = Vector3.ONE * PEOPLE_SCALE
	_keeper.add_child(c)
	_interactive(_keeper, "keeper", "E : parler à %s" % HOTE, Vector3(1.6, 2.2, 1.8), Vector3(0, 1.1, 1.2))


## Les rayons du mur est, jusqu'au plafond : conserves, lessive, pâtes, café, biscuits, bouteilles.
func _rayons() -> void:
	var x := W / 2.0 - 0.25
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	var bois := Color(0.55, 0.4, 0.26)
	# Le rayon s'arrête avant la fenêtre (z de -0,5 à 1,3) : les primeurs sont dessous.
	for seg in [[CLOISON_Z + 0.15, -0.6], [1.4, D / 2.0 - 0.9]]:
		var z0: float = seg[0]
		var z1: float = seg[1]
		_b.box("vrac", Transform3D(), Vector3(x + 0.1, H / 2.0, (z0 + z1) / 2.0), Vector3(0.06, H, z1 - z0), bois.darkened(0.3))
		for k in 6:
			var y := 0.25 + k * 0.45
			_b.box("vrac", Transform3D(), Vector3(x - 0.05, y, (z0 + z1) / 2.0), Vector3(0.45, 0.03, z1 - z0), bois)
			_rangee(Vector3(x - 0.05, y + 0.015, z0 + 0.12), Vector3(0, 0, 1), z1 - z0 - 0.2, k, rng)
		_solid_box_at(Vector3(0.5, H, z1 - z0), Vector3(x, H / 2.0, (z0 + z1) / 2.0))
	# Le long de la cloison, côté boutique : les gros paquets, la lessive en barils.
	var zc := CLOISON_Z + 0.3
	for k in 4:
		var y := 0.25 + k * 0.5
		_b.box("vrac", Transform3D(), Vector3(-0.9 + 1.3, y, zc), Vector3(3.6, 0.03, 0.42), bois)
		_rangee(Vector3(-0.9 - 0.4, y + 0.015, zc), Vector3(1, 0, 0), 3.4, k + 3, rng)
	_solid_box_at(Vector3(3.6, 2.2, 0.45), Vector3(0.4, 1.1, zc))


## Une rangée de marchandises le long de dir, sur une longueur : la famille change d'une étagère à l'autre.
func _rangee(depart: Vector3, dir: Vector3, longueur: float, famille: int, rng: RandomNumberGenerator) -> void:
	var t := 0.0
	var xf := Transform3D()
	match famille % 6:
		0:  # Conserves : petites boîtes rondes, étiquettes vives.
			while t < longueur:
				var c: Color = [Color(0.85, 0.15, 0.12), Color(0.2, 0.45, 0.75), Color(0.95, 0.8, 0.2), Color(0.25, 0.6, 0.3)][rng.randi() % 4]
				for e in 2:
					_b.cylinder("brillant", xf, depart + dir * t + Vector3(0, e * 0.12, 0), 0.05, 0.11, c, 8)
				t += 0.11
		1:  # Paquets de pâtes et de café : des boîtes hautes.
			while t < longueur:
				var c2: Color = [Color(0.15, 0.3, 0.6), Color(0.9, 0.85, 0.75), Color(0.6, 0.15, 0.15), Color(0.95, 0.65, 0.2)][rng.randi() % 4]
				_b.box("vrac", xf, depart + dir * t + Vector3(0, 0.13, 0), Vector3(0.12 if dir.x != 0 else 0.22, 0.26, 0.22 if dir.x != 0 else 0.12), c2)
				t += 0.14
		2:  # Bouteilles : vin en litre étoilé, eau, sirops.
			while t < longueur:
				var c3: Color = [Color(0.18, 0.32, 0.15), Color(0.75, 0.85, 0.9), Color(0.85, 0.2, 0.3), Color(0.95, 0.75, 0.25)][rng.randi() % 4]
				_b.cylinder("brillant", xf, depart + dir * t, 0.04, 0.34, c3, 6)
				t += 0.1
		3:  # Lessive en barils.
			while t < longueur:
				_b.cylinder("vrac", xf, depart + dir * t + Vector3(0, 0, 0), 0.12, 0.34, [Color(0.95, 0.5, 0.15), Color(0.2, 0.5, 0.85)][rng.randi() % 2], 10)
				t += 0.28
		4:  # Biscuits, paquets plats et colorés.
			while t < longueur:
				_b.box("vrac", xf, depart + dir * t + Vector3(0, 0.09, 0), Vector3(0.2, 0.18, 0.2), [Color(0.95, 0.85, 0.5), Color(0.8, 0.35, 0.2), Color(0.35, 0.6, 0.85)][rng.randi() % 3])
				t += 0.22
		_:  # Sacs de farine et de sucre.
			while t < longueur:
				_b.box("vrac", xf, depart + dir * t + Vector3(0, 0.12, 0), Vector3(0.22, 0.24, 0.16), Color(0.94, 0.93, 0.88))
				_b.box("vrac", xf, depart + dir * t + Vector3(0, 0.15, 0.081), Vector3(0.16, 0.06, 0.01), Color(0.2, 0.35, 0.65))
				t += 0.25


## La gondole du milieu : deux faces de rayons bas, et le présentoir à cartes postales au bout.
func _gondole() -> void:
	var cx := 1.0
	var z0 := 0.6
	var z1 := 2.6
	var bois := Color(0.75, 0.75, 0.72)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1986
	_b.box("vrac", Transform3D(), Vector3(cx, 0.65, (z0 + z1) / 2.0), Vector3(0.06, 1.3, z1 - z0), bois.darkened(0.2))
	for s in [-1.0, 1.0]:
		for k in 3:
			var y := 0.15 + k * 0.42
			_b.box("vrac", Transform3D(), Vector3(cx + s * 0.22, y, (z0 + z1) / 2.0), Vector3(0.4, 0.03, z1 - z0), bois)
			_rangee(Vector3(cx + s * 0.22, y + 0.015, z0 + 0.1), Vector3(0, 0, 1), z1 - z0 - 0.15, k + (0 if s < 0 else 1) * 2, rng)
	_solid_box_at(Vector3(0.9, 1.3, z1 - z0), Vector3(cx, 0.65, (z0 + z1) / 2.0))
	# Le tourniquet des cartes postales de Smarves.
	var p := Transform3D(Basis(Vector3.UP, 0.4), Vector3(cx, 0, z1 + 0.45))
	_b.cylinder("brillant", p, Vector3.ZERO, 0.02, 1.6, Color(0.6, 0.6, 0.6), 6)
	for k in 4:
		for side in 4:
			var a := side * PI / 2.0
			var q := p * Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * 0.1, 0.55 + k * 0.28, cos(a) * 0.1))
			_b.box("vrac", q, Vector3.ZERO, Vector3(0.16, 0.11, 0.005), [Color(0.4, 0.62, 0.85), Color(0.85, 0.75, 0.45), Color(0.45, 0.65, 0.35)][(k + side) % 3])
	_solid_box_at(Vector3(0.4, 1.6, 0.4), Vector3(cx, 0.8, z1 + 0.45))


## Les primeurs sous la fenêtre : cagettes en gradins, pommes, poireaux, pommes de terre.
func _primeurs() -> void:
	var x := W / 2.0 - 0.5
	var fruits := [Color(0.8, 0.15, 0.1), Color(0.95, 0.75, 0.15), Color(0.55, 0.72, 0.3), Color(0.62, 0.45, 0.25), Color(0.95, 0.5, 0.12)]
	for i in 5:
		var z := -0.35 + i * 0.36
		for g in 2:
			var cx := x - g * 0.45
			var y := 0.55 - g * 0.25
			_b.box("vrac", Transform3D(), Vector3(cx, y - 0.06, z), Vector3(0.42, 0.12, 0.32), Color(0.78, 0.66, 0.46))
			_b.box("vrac", Transform3D(), Vector3(cx, y + 0.02, z), Vector3(0.38, 0.06, 0.28), fruits[(i + g * 2) % fruits.size()])
	_b.box("vrac", Transform3D(), Vector3(x - 0.22, 0.25, 0.37), Vector3(0.95, 0.5, 1.9), Color(0.5, 0.36, 0.22))
	_label3d("Pommes du pays", Vector3(x - 0.7, 0.75, 0.37), 22, Color(0.15, 0.12, 0.1), -90.0)
	_solid_box_at(Vector3(1.0, 0.8, 1.9), Vector3(x - 0.25, 0.4, 0.37))


## Près de la porte : les casiers de consignes, les bonbonnes de gaz, le présentoir des journaux.
func _entree() -> void:
	var z := D / 2.0 - 0.6
	for i in 2:
		var p := Vector3(-W / 2.0 + 0.5 + i * 0.5, 0, z)
		_b.box("vrac", Transform3D(), p + Vector3(0, 0.15, 0), Vector3(0.44, 0.3, 0.34), Color(0.75, 0.2, 0.15))
		for k in 6:
			_b.cylinder("brillant", Transform3D(), p + Vector3(-0.15 + (k % 3) * 0.15, 0.3, -0.08 + (k / 3) * 0.16), 0.035, 0.2, Color(0.2, 0.35, 0.18), 6)
	for i in 3:
		_b.cylinder("brillant", Transform3D(), Vector3(W / 2.0 - 0.45 - i * 0.38, 0, z - 0.1), 0.15, 0.55, Color(0.2, 0.4, 0.8) if i != 1 else Color(0.85, 0.5, 0.1), 10)
	_label3d("BUTANE", Vector3(W / 2.0 - 0.83, 0.62, z + 0.08), 20, Color(1, 1, 1))
	_solid_box_at(Vector3(1.2, 0.6, 0.5), Vector3(W / 2.0 - 0.83, 0.3, z - 0.1))
	_solid_box_at(Vector3(1.0, 0.4, 0.4), Vector3(-W / 2.0 + 0.75, 0.2, z))
	# Le présentoir des journaux, la Nouvelle République pliée.
	var jx := -W / 2.0 + 0.35
	_b.box("vrac", Transform3D(), Vector3(jx, 0.7, 1.9), Vector3(0.3, 1.4, 0.8), Color(0.3, 0.3, 0.32))
	for k in 3:
		_b.box_tilted("vrac", Transform3D(), Vector3(jx + 0.12, 0.6 + k * 0.32, 1.9), Vector3(0.04, 0.28, 0.6), 0.0, Color(0.94, 0.93, 0.88))


## L'arrière-boutique : cartons, glacière, sacs, la table de Mme Pineau, la radio, la porte de la cour.
func _arriere_boutique() -> void:
	var z := (-D / 2.0 + CLOISON_Z) / 2.0
	var kk := "res://assets/kaykit/medieval_decoration/props/"
	for p in [[Vector3(-3.3, 0, -4.0), "crate_A_big"], [Vector3(-3.3, 0.66, -4.0), "crate_B_small"], [Vector3(-2.4, 0, -4.05), "crate_A_big"], [Vector3(-3.4, 0, -2.6), "sack"], [Vector3(-3.0, 0, -2.4), "sack"], [Vector3(1.0, 0, -4.0), "barrel"]]:
		_solid(_place(kk + p[1] + ".gltf", p[0], 2.0, randf() * 30.0))
	# La glacière blanche, le seau à glace.
	_b.box("brillant", Transform3D(), Vector3(-0.6, 0.45, -4.1), Vector3(1.0, 0.9, 0.55), Color(0.93, 0.94, 0.93))
	_b.box("vrac", Transform3D(), Vector3(-0.6, 0.92, -4.1), Vector3(1.02, 0.04, 0.57), Color(0.6, 0.62, 0.64))
	_solid_box_at(Vector3(1.0, 0.9, 0.6), Vector3(-0.6, 0.45, -4.1))
	# La table, la chaise, la radio, la tasse ; le calendrier des Postes au mur.
	var t := Transform3D(Basis(), Vector3(-1.4, 0, -2.4))
	_b.box("vrac", t, Vector3(0, 0.74, 0), Vector3(0.9, 0.04, 0.6), Color(0.6, 0.45, 0.3))
	for sx in [-0.4, 0.4]:
		for sz in [-0.25, 0.25]:
			_b.box("vrac", t, Vector3(sx, 0.36, sz), Vector3(0.04, 0.72, 0.04), Color(0.45, 0.32, 0.2))
	_b.box("brillant", t, Vector3(-0.15, 0.84, -0.1), Vector3(0.3, 0.16, 0.1), Color(0.35, 0.22, 0.15))
	_b.box("vrac", t, Vector3(-0.15, 0.84, -0.044), Vector3(0.12, 0.1, 0.01), Color(0.8, 0.75, 0.6))
	_b.cylinder("brillant", t, Vector3(0.25, 0.76, 0.1), 0.04, 0.08, Color(0.95, 0.95, 0.92), 8)
	_solid_box_at(Vector3(0.9, 0.8, 0.6), t.origin + Vector3(0, 0.4, 0))
	var cal := Transform3D(Basis(), Vector3(-1.4, 1.7, -D / 2.0 + 0.02))
	_b.box("vrac", cal, Vector3.ZERO, Vector3(0.36, 0.5, 0.01), Color(0.95, 0.95, 0.9))
	_b.box("vrac", cal, Vector3(0, 0.1, 0.004), Vector3(0.3, 0.2, 0.01), Color(0.4, 0.6, 0.35))
	_label3d("Almanach des PTT", cal.origin + Vector3(0, -0.12, 0.012), 14, Color(0.15, 0.2, 0.5))
	# La porte de la cour, calée ouverte : le soir, le livreur, la camionnette.
	var px := 2.6
	_b.box("vrac", Transform3D(), Vector3(px, 1.05, -D / 2.0 + 0.01), Vector3(1.0, 2.1, 0.02), Color(0.08, 0.1, 0.18))
	_b.box("vrac", Transform3D(Basis(Vector3.UP, 1.2), Vector3(px - 0.5, 0, -D / 2.0 + 0.03)), Vector3(0.48, 1.05, 0), Vector3(0.96, 2.08, 0.05), Color(0.36, 0.42, 0.36))
	var nuit := _std(Color(0.12, 0.16, 0.32), 1.0)
	nuit.emission_enabled = true
	nuit.emission = Color(0.1, 0.14, 0.34)
	_box(Vector3(1.0, 2.1, 0.02), Vector3(px, 1.05, -D / 2.0 - 0.3), nuit)
	var porte := Node3D.new()
	porte.position = Vector3(px, 0, -D / 2.0 + 0.4)
	add_child(porte)
	_interactive(porte, "cour", "E : regarder dans la cour", Vector3(1.2, 2.0, 0.8), Vector3(0, 1.0, 0))


func _lumieres() -> void:
	# Le néon de la boutique : un tube un peu vert, et sa lumière froide.
	var neon := _std(Color(0.85, 1.0, 0.92), 0.3)
	neon.emission_enabled = true
	neon.emission = Color(0.78, 1.0, 0.88)
	neon.emission_energy_multiplier = 2.5
	_box(Vector3(1.6, 0.05, 0.08), Vector3(0.3, H - 0.12, 1.4), neon)
	_lamp(Vector3(0.3, H - 0.4, 1.4), Color(0.85, 1.0, 0.9), 1.5, 7.0, true)
	_bulb(Vector3(-2.0, 2.3, -0.3), Color(0.85, 0.55, 0.3))
	# L'arrière-boutique, une ampoule nue, chaude.
	_lamp(Vector3(-1.0, 2.5, -3.2), Color(1.0, 0.72, 0.42), 1.4, 5.0)


## Une cliente qui compte sa monnaie au comptoir, un habitué qui lit le journal près de la porte.
func _gens() -> void:
	var c := CRITTER.new()
	c.randomize_look(4417)
	c.scale = Vector3.ONE * PEOPLE_SCALE
	c.position = Vector3(-2.2, 0, 0.75)
	c.rotation_degrees.y = 180.0
	add_child(c)
	var h := CRITTER.new()
	h.randomize_look(2290)
	h.scale = Vector3.ONE * PEOPLE_SCALE
	h.position = Vector3(-W / 2.0 + 1.1, 0, 1.9)
	h.rotation_degrees.y = -90.0
	add_child(h)


func _solid_box_at(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.position = pos
	add_child(body)
