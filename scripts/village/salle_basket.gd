class_name SalleBasket
extends "res://scripts/shop_interior.gd"
## La salle de basket d'une commune, à la première personne : une arène comme celles de la NBA, pas un
## gymnase municipal (demande de Guillaume du 19 octobre 2026 : « une salle type NBA, sur le modèle du
## stade de football de Casino Minuit »). Smarves l'a d'abord : le Clain Garden, où l'on descend du car.
## La fiche est au dossier du projet, basket/salle/fiche-salle.md.
## Le parvis (l'arrêt du car, le tapis rouge, les projecteurs, la statue de Big Héron, la façade de diodes),
## le hall (la boutique, la buvette, les trophées), la salle (le parquet, deux étages de gradins, l'anneau de
## diodes, le cube d'écrans, les bannières), et le bureau du club au pied des gradins nord.
## Le club, son sigle, ses couleurs et le nom de la salle viennent de la structure « gymnase » de la commune
## (fil « Basket sur les résultats réels ») ; le président, du lieu du manifeste de même id. Le match vient de
## ce même fil : ouvrir(commune, match) ou charger_match(match) ; sans match, le club s'entraîne.
## Capture : godot --path . res://scenes/salle_basket.tscn -- --capture=sortie.png [--at=x,z,lacet,tangage] [--won=…] [--commune=id] [--match]

## Le terrain (x : longueur, z : largeur), aux mesures de la FIBA, et le bord de parquet autour.
const L := 28.0
const P := 15.0
const BORD_X := 18.0
const BORD_Z := 11.5
## Les gradins : rangs du bas, rangs du haut, profondeur et hauteur d'un rang, hauteur où commence le haut.
const RANGS_BAS := 14
const RANGS_HAUT := 12
const RANG := 0.85
const MARCHE := 0.42
const MARCHE_HAUT := 0.55
const HAUT_Y := 8.6
## Le vomitoire sud, par où l'on entre du hall dans la salle : sa demi-largeur.
const VOMITOIRE := 2.6
## Le hall et le parvis, au sud de la salle (z croissant).
const HALL_Z := 23.0
const FACADE_Z := 37.0
const ARRET_Z := 64.0
const TOIT_Y := 27.0
const ECHELLE_JOUEUR := 3.0
## Le club et la salle de secours, tant que la commune n'a pas de structure « gymnase ».
const CLUB_SECOURS := "Les Hérons du Clain"
const COURT_SECOURS := "HCL"
const SALLE_SECOURS := "le Clain Garden"
const COULEURS_SECOURS := ["#14213d", "#d4a93a"]
## Les écrans du club, du fil basket : ouverts dès qu'ils existent.
const PANNEAU_BASKET := "res://scripts/socle/basket_panneau.gd"
const BUREAU_BASKET := "res://scripts/socle/basket_bureau.gd"

## La commune et son match, posés par ouvrir() avant le changement de scène.
static var prochaine_commune := ""
static var prochain_match := {}
var commune := ""
var _gymnase := {}
var _match := {}
## Les écrans qui disent le score : les quatre faces du cube, la façade, le bandeau.
var _cube: Array[Label3D] = []
var _cube_titre: Array[Label3D] = []
var _facade: Label3D
var _defile: Label3D
var _defile_textes: Array = []
var _defile_t := 0.0
var _bandeau: PanelContainer
var _bandeau_score: Label
var _bandeau_fait: Label
## La foule, en un seul maillage multiple, et ceux qui vivent : les joueurs, l'entraîneur, la mascotte.
var _foule: MultiMeshInstance3D
var _places: Array = []
var _joueurs: Array = []
var _parcours_t := 0.0
var _ballon: MeshInstance3D
var _heron: Node3D
var _danseuses: Array = []
var _faisceaux: Array = []
var _president: Node3D
var _ecran: Control
var _anneau: StandardMaterial3D


## Ouvre la salle d'une commune. match : celui que le fil basket veut voir (vide : l'entraînement).
static func ouvrir(id: String, match := {}) -> void:
	prochaine_commune = id
	prochain_match = match
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/salle_basket.tscn")


## La structure « gymnase » d'une commune au registre ({} : aucune).
static func gymnase_de(id: String) -> Dictionary:
	for e in Registre.de_commune(id):
		if e.type == "gymnase":
			return e
	return {}


## Le car s'arrête-t-il à la salle de cette commune ? Celles qui déclarent un gymnase, et Smarves d'abord.
static func desservie(id: String) -> bool:
	return id == Communes.ORIGINE or not gymnase_de(id).is_empty()


## Le lieu du manifeste qui porte la salle : même id que le gymnase, « gymnase » à défaut.
static func lieu_de(id: String) -> Dictionary:
	var c: Commune = Communes.commune(id)
	if c == null:
		return {}
	var g := gymnase_de(id)
	var cle := str(g.get("id", "gymnase")) if not g.is_empty() else "gymnase"
	for l in c.lieux():
		if l.id == cle:
			return l
	return {}


## Le seuil de la salle (crédits gagnés) : celui de son lieu, 0 s'il n'en a pas.
static func seuil_de(id: String) -> int:
	return int(lieu_de(id).get("seuil", 0))


static func ouverte(id: String) -> bool:
	return Game.won >= seuil_de(id)


func _ready() -> void:
	commune = prochaine_commune if prochaine_commune != "" else Communes.origine().id
	prochaine_commune = ""
	_match = prochain_match
	prochain_match = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--commune="):
			commune = arg.trim_prefix("--commune=")
		elif arg == "--match":
			_match = {"dom": _nom_club(), "ext": "Les Aigles de Chauvigny", "score": [98, 94], "quarts": [[24, 22], [27, 25], [21, 26], [26, 21]], "fini": true}
	_gymnase = gymnase_de(commune)
	_serif = Polices.texte()
	_environment()
	_nuit()
	_parquet()
	_paniers()
	_gradins()
	_toit()
	_cube_ecrans()
	_bancs()
	_bureau_du_club()
	_hall()
	_facade_et_parvis()
	_heron_geant()
	_vivants()
	_build_ui()
	_bandeau_du_direct()
	player = PLAYER.new()
	player.position = Vector3(0, 0, ARRET_Z - 2.0)
	player.rotation.y = 0.0
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("casino")
	if _match.is_empty():
		jouer_entrainement()
	else:
		charger_match(_match)
	_maybe_capture()


func _place_name() -> String:
	var n := _nom_salle()
	return n.left(1).to_upper() + n.substr(1)


# --- Ce que la structure dit du club ---------------------------------------------------------------

func _champs() -> Dictionary:
	return _gymnase.get("champs", {})


func _nom_club() -> String:
	return str(_champs().get("club", CLUB_SECOURS))


func _court() -> String:
	return str(_champs().get("court", COURT_SECOURS))


## Le nom de la salle : celui de la structure « gymnase », sinon celui de son lieu, le Clain Garden à défaut.
func _nom_salle() -> String:
	var s := str(_gymnase.get("nom", "")) if not _gymnase.is_empty() else ""
	if s == "":
		var lieu := lieu_de(commune)
		s = str(lieu.get("name", SALLE_SECOURS)) if not lieu.is_empty() else SALLE_SECOURS
	return s


func _couleurs() -> Array:
	var c: Array = _champs().get("couleurs", [])
	return c if c.size() >= 2 else COULEURS_SECOURS


func _c1() -> Color:
	return Color.from_string(str(_couleurs()[0]), Color(0.08, 0.15, 0.31))


func _c2() -> Color:
	return Color.from_string(str(_couleurs()[1]), Color(0.91, 0.72, 0.29))


func _nom_president() -> String:
	var h := str(lieu_de(commune).get("host", ""))
	return h if h != "" else "Le président"


static func _enseigne(nom: String) -> String:
	var n := nom.strip_edges()
	for a in ["Le ", "La ", "Les ", "L'", "L’", "le ", "la ", "les "]:
		if n.begins_with(a):
			n = n.substr(a.length())
			break
	return n.to_upper()


func _neon(c: Color, energie := 2.5) -> StandardMaterial3D:
	var m := _std(c, 0.4)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energie
	return m


# --- La salle -------------------------------------------------------------------------------------

## Le soir : un ciel d'encre au-dehors, une ambiance sombre, et la salle éclairée par ses rampes.
func _nuit() -> void:
	for c in get_children():
		if c is WorldEnvironment:
			var env: Environment = c.environment
			env.background_color = Color(0.02, 0.025, 0.06)
			env.ambient_light_color = Color(0.5, 0.5, 0.62)
			env.ambient_light_energy = 0.55
			env.sdfgi_enabled = false
			env.ssil_enabled = false
			env.glow_intensity = 0.7
			env.glow_bloom = 0.05
	var lune := DirectionalLight3D.new()
	lune.light_color = Color(0.6, 0.68, 0.9)
	lune.light_energy = 0.3
	lune.rotation_degrees = Vector3(-50, 25, 0)
	add_child(lune)
	# Les rampes du toit : quatre grands projecteurs sur le parquet, deux plus doux sur les gradins.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var spot := SpotLight3D.new()
			spot.light_color = Color(1.0, 0.97, 0.92)
			spot.light_energy = 14.0
			spot.spot_range = 45.0
			spot.spot_angle = 38.0
			spot.shadow_enabled = sx < 0.0 and sz < 0.0
			add_child(spot)
			spot.position = Vector3(sx * 9.0, TOIT_Y - 3.0, sz * 6.0)
			spot.look_at(Vector3(sx * 6.0, 0, sz * 3.0), Vector3.UP)
	for sz: float in [-1.0, 1.0]:
		var spot := SpotLight3D.new()
		spot.light_color = Color(0.95, 0.9, 1.0)
		spot.light_energy = 6.0
		spot.spot_range = 50.0
		spot.spot_angle = 60.0
		add_child(spot)
		spot.position = Vector3(0, TOIT_Y - 4.0, sz * 4.0)
		spot.look_at(Vector3(0, 6.0, sz * 26.0), Vector3.UP)


## Le parquet ciré, ses lignes, les raquettes et le rond central aux couleurs du club, le nom au milieu.
func _parquet() -> void:
	var bois := _wood_floor(Color(0.86, 0.64, 0.4))
	_box(Vector3(BORD_X * 2.0, 0.2, BORD_Z * 2.0), Vector3(0, -0.1, 0), _std(Color(0.12, 0.12, 0.14), 0.6), true)
	_box(Vector3(L + 4.0, 0.04, P + 4.0), Vector3(0, 0.02, 0), _std(_c1().darkened(0.2), 0.4))
	_box(Vector3(L, 0.04, P), Vector3(0, 0.03, 0), bois)
	var blanc := _std(Color(0.97, 0.97, 0.95), 0.5)
	var y := 0.055
	# Le cadre, la ligne médiane, le rond central.
	for s: float in [-1.0, 1.0]:
		_box(Vector3(L, 0.01, 0.05), Vector3(0, y, s * P / 2.0), blanc)
		_box(Vector3(0.05, 0.01, P), Vector3(s * L / 2.0, y, 0), blanc)
	_box(Vector3(0.05, 0.01, P), Vector3(0, y, 0), blanc)
	_anneau_sol(Vector3(0, y, 0), 1.8, blanc)
	var rond := _cyl(1.78, 0.01, Vector3(0, y - 0.004, 0), _std(_c1(), 0.4))
	rond.name = "RondCentral"
	var nom := _label3d(_court(), Vector3(0, y + 0.01, 0), 220, _c2())
	nom.rotation_degrees.x = -90
	nom.pixel_size = 0.006
	var raquette := _std(_c1().lerp(Color(0.86, 0.64, 0.4), 0.15), 0.4)
	for s: float in [-1.0, 1.0]:
		var fond := s * L / 2.0
		# La raquette (5,8 m sur 4,9 m), la ligne et le cercle des lancers francs.
		_box(Vector3(5.8, 0.012, 4.9), Vector3(fond - s * 2.9, y - 0.002, 0), raquette)
		for k: float in [-1.0, 1.0]:
			_box(Vector3(5.8, 0.01, 0.05), Vector3(fond - s * 2.9, y + 0.004, k * 2.45), blanc)
		_box(Vector3(0.05, 0.01, 4.9), Vector3(fond - s * 5.8, y + 0.004, 0), blanc)
		_anneau_sol(Vector3(fond - s * 5.8, y + 0.004, 0), 1.8, blanc)
		# La ligne à trois points : deux droites le long des touches, puis l'arc de 6,75 m.
		var panier := fond - s * 1.575
		for k: float in [-1.0, 1.0]:
			_box(Vector3(2.99, 0.01, 0.05), Vector3(fond - s * 1.495, y + 0.004, k * 6.6), blanc)
		var n := 36
		var a0 := asin(6.6 / 6.75)
		for i in n:
			var a := lerpf(-a0, a0, (i + 0.5) / n)
			var p := Vector3(panier - s * 6.75 * cos(a), y + 0.004, 6.75 * sin(a))
			var seg := _box(Vector3(0.05, 0.01, 2.0 * a0 * 6.75 / n + 0.02), p, blanc)
			seg.rotation.y = -s * a
		# Le nom du club, en grand, sous chaque panier, tourné vers le terrain.
		var club := _label3d(_enseigne(_nom_club()), Vector3(fond + s * 1.0, y + 0.01, 0), 120, _c2())
		club.rotation_degrees = Vector3(-90, -s * 90.0, 0)
		club.pixel_size = 0.005


## Un cercle de segments posé au sol.
func _anneau_sol(centre: Vector3, r: float, mat: Material) -> void:
	var n := 40
	for i in n:
		var a := TAU * i / n
		var seg := _box(Vector3(0.05, 0.01, TAU * r / n + 0.02), centre + Vector3(r * cos(a), 0, r * sin(a)), mat)
		seg.rotation.y = -a


## Les deux paniers : le pied rembourré aux couleurs du club, le bras, la planche de verre, le cercle orange.
func _paniers() -> void:
	var verre := _std(Color(0.85, 0.92, 1.0, 0.25), 0.05)
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cadre := _std(Color(0.95, 0.95, 0.95), 0.4)
	var orange := _std(Color(0.95, 0.4, 0.1), 0.4, 0.5)
	var pied := _std(_c1(), 0.6)
	for s: float in [-1.0, 1.0]:
		var fond := s * L / 2.0
		_box(Vector3(1.6, 1.0, 1.4), Vector3(fond + s * 1.9, 0.5, 0), pied, true)
		_box(Vector3(0.35, 2.6, 0.35), Vector3(fond + s * 2.0, 2.3, 0), pied)
		var bras := _box(Vector3(2.4, 0.22, 0.22), Vector3(fond + s * 0.9, 3.55, 0), cadre)
		bras.rotation.z = s * 0.25
		_label3d(_court(), Vector3(fond + s * 1.9, 0.6, 0.71), 60, _c2())
		_box(Vector3(0.04, 1.05, 1.8), Vector3(fond - s * 1.2, 3.35, 0), verre)
		_box(Vector3(0.05, 0.45, 0.59), Vector3(fond - s * 1.21, 3.25, 0), _std(Color(1, 1, 1), 0.4)).transparency = 0.6
		var cercle := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.215
		t.outer_radius = 0.24
		cercle.mesh = t
		cercle.material_override = orange
		cercle.position = Vector3(fond - s * 1.575, 3.05, 0)
		add_child(cercle)
		# Le filet : un cône blanc ajouré sous le cercle.
		var filet := _cyl(0.22, 0.42, Vector3(fond - s * 1.575, 2.83, 0), _std(Color(1, 1, 1, 0.55), 0.8), self, 0.14)
		(filet.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		(filet.mesh as CylinderMesh).top_radius = 0.23
		(filet.mesh as CylinderMesh).bottom_radius = 0.14


## Les gradins tout autour : quatorze rangs en bas, douze en haut, un anneau de diodes entre les deux, la
## foule assise. Le côté sud laisse le vomitoire, par où l'on entre du hall.
func _gradins() -> void:
	var beton := _std(Color(0.18, 0.18, 0.2), 0.8)
	var siege := _std(_c1().darkened(0.15), 0.6)
	var siege_haut := _std(_c1().darkened(0.35), 0.6)
	for cote: String in ["n", "s", "e", "o"]:
		for i in RANGS_BAS + RANGS_HAUT:
			var haut := i >= RANGS_BAS
			var d := i * RANG + (2.4 if haut else 0.0)
			var h := (HAUT_Y + (i - RANGS_BAS) * MARCHE_HAUT) if haut else (0.3 + i * MARCHE)
			var bas := (HAUT_Y - 0.4) if haut else 0.0
			_rang(cote, d, h, bas, beton, siege_haut if haut else siege)
	# Le mur du fond du bas, au sud, entre la salle et le hall, et la dalle du haut qui couvre le hall.
	var dz := BORD_Z + RANGS_BAS * RANG
	_box(Vector3(BORD_X * 2.0 + 2.0 * dz, 8.2, 0.4), Vector3(0, 4.1, dz + 0.2), beton, true).name = "MurDuHall"
	# Les bandeaux de l'anneau : une rampe de diodes sur le devant du haut, tout autour.
	_anneau = _neon(_c2(), 2.2)
	var ry := HAUT_Y - 0.9
	var ex := BORD_X + RANGS_BAS * RANG + 2.2
	var ez := BORD_Z + RANGS_BAS * RANG + 2.2
	_box(Vector3(ex * 2.0, 0.9, 0.12), Vector3(0, ry, -ez), _anneau)
	_box(Vector3(ex * 2.0, 0.9, 0.12), Vector3(0, ry, ez), _anneau)
	_box(Vector3(0.12, 0.9, ez * 2.0), Vector3(-ex, ry, 0), _anneau)
	_box(Vector3(0.12, 0.9, ez * 2.0), Vector3(ex, ry, 0), _anneau)
	var bande := "%s  ·  %s  ·  " % [_enseigne(_nom_salle()), _enseigne(_nom_club())]
	_label3d(bande + bande, Vector3(0, ry, -ez + 0.08), 110, _c1().darkened(0.4))
	_label3d(bande + bande, Vector3(ex - 0.08, ry, 0), 110, _c1().darkened(0.4), -90)
	_label3d(bande + bande, Vector3(-ex + 0.08, ry, 0), 110, _c1().darkened(0.4), 90)
	_label3d(bande + bande, Vector3(0, ry, ez - 0.08), 110, _c1().darkened(0.4), 180)
	_foule_assise()


## Un rang d'un côté : la marche (béton) et sa rangée de sièges, et les places qu'y prendra la foule.
func _rang(cote: String, d: float, h: float, bas: float, beton: Material, siege: Material) -> void:
	var hz := h - bas
	match cote:
		"n", "s":
			var s := -1.0 if cote == "n" else 1.0
			var z := s * (BORD_Z + d + RANG / 2.0)
			var lx := BORD_X + d + RANG
			if cote == "s" and bas == 0.0:
				# Le vomitoire coupe le bas en deux.
				for k: float in [-1.0, 1.0]:
					var w := lx - VOMITOIRE
					_box(Vector3(w, hz, RANG), Vector3(k * (VOMITOIRE + w / 2.0), bas + hz / 2.0, z), beton, true)
					_box(Vector3(w, 0.12, RANG * 0.5), Vector3(k * (VOMITOIRE + w / 2.0), h + 0.06, z - s * RANG * 0.15), siege)
			else:
				_box(Vector3(lx * 2.0, hz, RANG), Vector3(0, bas + hz / 2.0, z), beton, true)
				_box(Vector3(lx * 2.0, 0.12, RANG * 0.5), Vector3(0, h + 0.06, z - s * RANG * 0.15), siege)
			var n := int(lx * 2.0 / 0.6)
			for k in n:
				var x := -lx + (k + 0.5) * lx * 2.0 / n
				if cote == "s" and bas == 0.0 and absf(x) < VOMITOIRE:
					continue
				_places.append(Transform3D(Basis(Vector3.UP, 0.0 if s < 0.0 else PI), Vector3(x, h + 0.12, z)))
		"e", "o":
			var s := 1.0 if cote == "e" else -1.0
			var x := s * (BORD_X + d + RANG / 2.0)
			var lz := BORD_Z + d
			_box(Vector3(RANG, hz, lz * 2.0), Vector3(x, bas + hz / 2.0, 0), beton, true)
			_box(Vector3(RANG * 0.5, 0.12, lz * 2.0), Vector3(x - s * RANG * 0.15, h + 0.06, 0), siege)
			var n := int(lz * 2.0 / 0.6)
			for k in n:
				var z := -lz + (k + 0.5) * lz * 2.0 / n
				_places.append(Transform3D(Basis(Vector3.UP, -s * PI / 2.0), Vector3(x, h + 0.12, z)))


## La foule : une silhouette par place prise, en un seul maillage multiple (des milliers sans peser).
func _foule_assise() -> void:
	var corps := CapsuleMesh.new()
	corps.radius = 0.2
	corps.height = 0.85
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	corps.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = corps
	mm.instance_count = _places.size()
	var h := Hasard.depuis(4242)
	var teintes := [_c1(), _c2(), Color(0.85, 0.85, 0.85), Color(0.2, 0.2, 0.22), Color(0.6, 0.15, 0.15), Color(0.25, 0.35, 0.55)]
	for i in _places.size():
		var t: Transform3D = _places[i]
		t.origin.y += 0.42
		mm.set_instance_transform(i, t)
		var c: Color = teintes[0] if h.suivant() < 0.35 else teintes[h.entier(0, teintes.size() - 1)]
		mm.set_instance_color(i, c.darkened(h.suivant() * 0.3))
	_foule = MultiMeshInstance3D.new()
	_foule.multimesh = mm
	_foule.name = "Foule"
	add_child(_foule)


## Le toit : la charpente noire, les bannières des maillots retirés, la passerelle des projecteurs.
func _toit() -> void:
	var ex := BORD_X + RANGS_BAS * RANG + 2.4 + RANGS_HAUT * RANG + 1.0
	var ez := BORD_Z + RANGS_BAS * RANG + 2.4 + RANGS_HAUT * RANG + 1.0
	var noir := _std(Color(0.05, 0.05, 0.07), 0.9)
	_box(Vector3(ex * 2.0, 0.4, ez * 2.0), Vector3(0, TOIT_Y, 0), noir)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(ex * 2.0, TOIT_Y, 0.5), Vector3(0, TOIT_Y / 2.0, s * ez), noir, true)
		_box(Vector3(0.5, TOIT_Y, ez * 2.0), Vector3(s * ex, TOIT_Y / 2.0, 0), noir, true)
	var acier := _std(Color(0.25, 0.26, 0.3), 0.5, 0.6)
	for k in range(-4, 5):
		_box(Vector3(0.3, 0.9, ez * 2.0), Vector3(k * ex / 4.5, TOIT_Y - 0.7, 0), acier)
	_box(Vector3(ex * 2.0, 0.9, 0.3), Vector3(0, TOIT_Y - 0.7, 0), acier)
	# Les bannières : les maillots retirés et les titres du club, côté nord.
	var bannieres := [["1", "LE FONDATEUR"], ["7", "LE CAPITAINE"], ["23", "LE DUNKEUR"], ["CHAMPION", "DE LA VIENNE"], ["33", "LE PIVOT"]]
	for i in bannieres.size():
		var x := (i - 2) * 5.0
		var z := -BORD_Z - 10.0
		_box(Vector3(2.4, 3.6, 0.05), Vector3(x, 19.5, z), _std(_c1(), 0.7))
		_box(Vector3(2.4, 0.25, 0.06), Vector3(x, 21.2, z), _std(_c2(), 0.5))
		_label3d(str(bannieres[i][0]), Vector3(x, 19.9, z + 0.05), 150 if bannieres[i][0].length() < 3 else 60, _c2())
		_label3d(str(bannieres[i][1]), Vector3(x, 18.4, z + 0.05), 34, Color(0.95, 0.95, 0.9))


## Le cube d'écrans au-dessus du rond central : le score sur quatre faces, l'anneau lumineux dessous.
func _cube_ecrans() -> void:
	var y := 15.5
	var noir := _std(Color(0.03, 0.03, 0.04), 0.4)
	_box(Vector3(7.6, 4.4, 7.6), Vector3(0, y, 0), noir)
	var ecran := _neon(Color(0.08, 0.1, 0.18), 1.0)
	for i in 4:
		var a := i * PI / 2.0
		var dir := Vector3(sin(a), 0, cos(a))
		var face := _box(Vector3(7.0, 3.8, 0.05), Vector3(0, y, 0) + dir * 3.83, ecran)
		face.rotation.y = a
		var titre := _label3d("", Vector3(0, y + 1.35, 0) + dir * 3.88, 70, _c2(), rad_to_deg(a))
		_cube_titre.append(titre)
		var score := _label3d("", Vector3(0, y - 0.25, 0) + dir * 3.88, 200, Color(1, 1, 1), rad_to_deg(a))
		score.line_spacing = -20
		_cube.append(score)
	_cyl(4.4, 0.5, Vector3(0, y - 2.5, 0), _neon(_c2(), 3.0), self, 4.4)
	_cyl(3.2, 1.2, Vector3(0, y + 2.9, 0), noir)
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		_box(Vector3(0.06, TOIT_Y - y - 2.2, 0.06), Vector3(cos(a) * 3.0, (TOIT_Y + y + 2.2) / 2.0, sin(a) * 3.0), _std(Color(0.3, 0.3, 0.32), 0.5, 0.7))


## Les bancs des deux équipes et la table de marque, au nord ; les sièges du bord du terrain, au sud.
func _bancs() -> void:
	var table := _std(Color(0.05, 0.05, 0.06), 0.4)
	_box(Vector3(9.0, 0.9, 0.8), Vector3(0, 0.45, -P / 2.0 - 2.2), table, true)
	var bandeau := _box(Vector3(9.0, 0.6, 0.04), Vector3(0, 0.55, -P / 2.0 - 1.78), _neon(_c1(), 1.6))
	bandeau.name = "TableDeMarque"
	_label3d("%s  ·  %s" % [_enseigne(_nom_salle()), _court()], Vector3(0, 0.55, -P / 2.0 - 1.75), 64, _c2())
	var chaise := _std(_c1().darkened(0.2), 0.6)
	for s: float in [-1.0, 1.0]:
		for k in 8:
			var x := s * (6.5 + k * 0.75)
			_box(Vector3(0.6, 0.5, 0.55), Vector3(x, 0.25, -P / 2.0 - 2.1), chaise, true)
			_box(Vector3(0.6, 0.6, 0.1), Vector3(x, 0.75, -P / 2.0 - 2.35), chaise)
	# Le bord du terrain, côté sud : deux rangs de fauteuils, laissant l'allée du vomitoire.
	var cuir := _std(Color(0.08, 0.08, 0.1), 0.5)
	for rangee in 2:
		for k in 24:
			var x := -13.0 + k * 1.13
			if absf(x) < VOMITOIRE + 0.3:
				continue
			_box(Vector3(0.6, 0.45 + rangee * 0.25, 0.6), Vector3(x, 0.225 + rangee * 0.125, P / 2.0 + 1.6 + rangee * 0.9), cuir, true)


## Le bureau du club, au pied des gradins nord : la porte du couloir des vestiaires, et le président devant.
## E à la porte ouvre le bureau du club (scripts/socle/basket_bureau.gd, du fil basket) ; au président, il parle.
func _bureau_du_club() -> void:
	var z := -BORD_Z + 0.05
	var x := 10.0
	var porte := Node3D.new()
	porte.position = Vector3(x, 0, z)
	porte.name = "BureauDuClub"
	add_child(porte)
	_box(Vector3(3.0, 2.8, 0.1), Vector3(0, 1.4, -0.05), _std(Color(0.04, 0.04, 0.05), 0.5), false, porte)
	_box(Vector3(1.4, 2.3, 0.06), Vector3(0, 1.15, 0.02), _std(Color(0.55, 0.36, 0.2), 0.5), false, porte)
	_box(Vector3(3.0, 0.4, 0.08), Vector3(0, 2.6, 0.05), _neon(_c2(), 1.8), false, porte)
	var l := _label3d("VESTIAIRES  ·  BUREAU DU CLUB", Vector3(x, 2.6, z + 0.1), 34, _c1().darkened(0.5))
	l.name = "EnseigneBureau"
	_lamp(Vector3(x, 2.4, z + 1.2), Color(1.0, 0.85, 0.6), 1.2, 6.0)
	_interactive(porte, "bureau", "E : entrer au bureau du club", Vector3(2.6, 2.6, 1.8), Vector3(0, 1.3, 0.9))
	_president = CRITTER.new()
	_president.randomize_look(311)
	_president.look["top_color"] = "#1a1a1e"
	_president.scale = Vector3.ONE * PEOPLE_SCALE
	_president.position = Vector3(x - 2.6, 0, z + 1.0)
	add_child(_president)
	_interactive(_president, "president", "E : parler %s" % _a(_nom_president()), Vector3(0.8, 1.0, 0.8), Vector3(0, 0.4, 0))


static func _a(nom: String) -> String:
	if nom.begins_with("Le "):
		return "au " + nom.substr(3)
	if nom.begins_with("La "):
		return "à la " + nom.substr(3)
	return "à " + nom


# --- Le hall --------------------------------------------------------------------------------------

## Le hall, sous les gradins du haut : marbre noir veiné d'or, la boutique, la buvette, les trophées.
func _hall() -> void:
	var dz := BORD_Z + RANGS_BAS * RANG + 0.4
	var hw := 22.0
	var marbre := _std(Color(0.06, 0.06, 0.07), 0.15, 0.2)
	marbre.albedo_texture = _noise(0.05, Vector2(1, 3), Color(0.5, 0.45, 0.3))
	marbre.uv1_triplanar = true
	marbre.uv1_scale = Vector3(0.15, 0.15, 0.15)
	_box(Vector3(hw * 2.0, 0.2, FACADE_Z - dz), Vector3(0, -0.1, (FACADE_Z + dz) / 2.0), marbre, true)
	var plafond := _std(Color(0.08, 0.07, 0.06), 0.6)
	_box(Vector3(hw * 2.0, 0.3, FACADE_Z - dz), Vector3(0, 7.4, (FACADE_Z + dz) / 2.0), plafond)
	var or_ := _std(_c2(), 0.3, 0.8)
	_box(Vector3(hw * 2.0, 0.12, 0.12), Vector3(0, 7.2, dz + 0.3), or_)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.4, 7.4, FACADE_Z - dz), Vector3(s * hw, 3.7, (FACADE_Z + dz) / 2.0), _std(Color(0.1, 0.09, 0.08), 0.6), true)
	# Le passage du vomitoire, éclairé, avec son linteau : « LA SALLE ».
	_box(Vector3(VOMITOIRE * 2.0 + 0.6, 0.6, 0.5), Vector3(0, 4.3, dz), or_)
	_label3d("LA SALLE", Vector3(0, 4.3, dz + 0.27), 60, Color(0.08, 0.06, 0.03), 180)
	_label3d("LA SALLE", Vector3(0, 4.3, dz + 0.27), 60, Color(0.08, 0.06, 0.03))
	_lamp(Vector3(0, 4.0, dz + 1.5), Color(1.0, 0.85, 0.6), 2.0, 9.0)
	# Les lustres en ballons d'or empilés.
	for x: float in [-11.0, 0.0, 11.0]:
		var c := Vector3(x, 6.2, (FACADE_Z + dz) / 2.0)
		for k in 3:
			var b := _cyl(0.35, 0.7, c + Vector3(0, -k * 0.55, 0), _neon(Color(1.0, 0.75, 0.35), 1.6))
			b.mesh = SphereMesh.new()
			(b.mesh as SphereMesh).radius = 0.32
			(b.mesh as SphereMesh).height = 0.64
		_lamp(c + Vector3(0, -1.6, 0), Color(1.0, 0.82, 0.55), 2.2, 12.0)
	# La boutique du club, à l'ouest : un comptoir, deux portants de maillots aux couleurs du club.
	var boutique := Node3D.new()
	boutique.position = Vector3(-15.0, 0, dz + 4.5)
	add_child(boutique)
	_box(Vector3(5.0, 1.0, 1.0), Vector3(0, 0.5, 0), _std(Color(0.1, 0.1, 0.12), 0.4), true, boutique)
	_box(Vector3(5.2, 0.08, 1.1), Vector3(0, 1.04, 0), or_, false, boutique)
	_box(Vector3(6.0, 1.0, 0.1), Vector3(0, 4.8, -1.8), _neon(_c1(), 1.4), false, boutique)
	_label3d("LA BOUTIQUE DU CLUB", boutique.position + Vector3(0, 4.8, -1.72), 60, _c2())
	for k in 6:
		var maillot := _box(Vector3(0.7, 0.85, 0.08), Vector3(-2.0 + k * 0.8, 2.6, -1.7), _std(_c1() if k % 2 == 0 else _c2(), 0.7), false, boutique)
		maillot.name = "Maillot%d" % k
		_label3d(str([1, 7, 23, 33, 9, 11][k]), boutique.position + Vector3(-2.0 + k * 0.8, 2.6, -1.64), 60, _c2() if k % 2 == 0 else _c1())
	_interactive(boutique, "boutique", "E : la boutique du club", Vector3(5.4, 2.4, 2.0), Vector3(0, 1.2, 1.2))
	# La buvette, à l'est : hot-dogs et bière du Clain.
	var buvette := Node3D.new()
	buvette.position = Vector3(15.0, 0, dz + 4.5)
	add_child(buvette)
	_box(Vector3(5.0, 1.0, 1.0), Vector3(0, 0.5, 0), _std(Color(0.1, 0.1, 0.12), 0.4), true, buvette)
	_box(Vector3(5.2, 0.08, 1.1), Vector3(0, 1.04, 0), or_, false, buvette)
	_box(Vector3(6.0, 1.0, 0.1), Vector3(0, 4.8, -1.8), _neon(Color(0.9, 0.25, 0.15), 1.6), false, buvette)
	_label3d("HOT-DOGS  ·  BIÈRE DU CLAIN", buvette.position + Vector3(0, 4.8, -1.72), 54, Color(1, 0.95, 0.8))
	_interactive(buvette, "buvette", "E : un hot-dog à la buvette", Vector3(5.4, 2.4, 2.0), Vector3(0, 1.2, 1.2))
	# La vitrine des trophées, au milieu du hall, face aux portes.
	var vitrine := Node3D.new()
	vitrine.position = Vector3(-6.5, 0, dz + 7.0)
	add_child(vitrine)
	_box(Vector3(2.4, 0.9, 1.0), Vector3(0, 0.45, 0), _std(Color(0.08, 0.08, 0.09), 0.4), true, vitrine)
	var vitre := _std(Color(0.8, 0.9, 1.0, 0.18), 0.05)
	vitre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(Vector3(2.4, 1.4, 1.0), Vector3(0, 1.6, 0), vitre, false, vitrine)
	for k in 3:
		_cyl(0.12, 0.6 + k * 0.15, Vector3(-0.7 + k * 0.7, 1.2 + k * 0.075, 0), or_, vitrine, 0.2)
	_label3d("LES TROPHÉES", vitrine.position + Vector3(0, 2.5, 0.0), 40, _c2())
	_lamp(vitrine.position + Vector3(0, 2.8, 0.8), Color(1.0, 0.9, 0.7), 1.2, 4.0)
	_interactive(vitrine, "trophees", "E : regarder les trophées", Vector3(2.8, 2.4, 2.0), Vector3(0, 1.2, 0.9))


# --- Dehors ---------------------------------------------------------------------------------------

## La façade de diodes aux couleurs du club, les portes, le parvis, le tapis rouge, les projecteurs qui
## balaient le ciel, les guichets, le panneau du club et l'arrêt du car.
func _facade_et_parvis() -> void:
	var largeur := 90.0
	var hauteur := 24.0
	var peau := _neon(_c1().darkened(0.25), 1.3)
	peau.albedo_texture = _noise(0.25, Vector2.ONE, Color(0.4, 0.4, 0.45))
	peau.emission_texture = peau.albedo_texture
	peau.uv1_triplanar = true
	peau.uv1_scale = Vector3(0.5, 0.5, 0.5)
	for s: float in [-1.0, 1.0]:
		var w := largeur / 2.0 - 3.2
		_box(Vector3(w, hauteur, 0.6), Vector3(s * (3.2 + w / 2.0), hauteur / 2.0, FACADE_Z), peau, true)
	_box(Vector3(6.4, hauteur - 5.0, 0.6), Vector3(0, 5.0 + (hauteur - 5.0) / 2.0, FACADE_Z), peau)
	var or_ := _std(_c2(), 0.3, 0.8)
	for y: float in [5.0, 12.0, hauteur]:
		_box(Vector3(largeur, 0.45, 0.9), Vector3(0, y, FACADE_Z + 0.2), _neon(_c2(), 1.8))
	_facade = _label3d(_enseigne(_nom_salle()), Vector3(0, 17.5, FACADE_Z + 0.4), 900, Color(1, 0.96, 0.85))
	_facade.pixel_size = 0.01
	_facade.name = "EnseigneFacade"
	_defile = _label3d("", Vector3(0, 8.5, FACADE_Z + 0.4), 500, _c2())
	_defile.pixel_size = 0.008
	_defile.name = "Defile"
	# Les portes vitrées, éclairées.
	var vitre := _neon(Color(1.0, 0.85, 0.6), 0.8)
	vitre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vitre.albedo_color.a = 0.35
	for k in 4:
		_box(Vector3(1.4, 4.4, 0.06), Vector3(-2.4 + k * 1.6, 2.2, FACADE_Z + 0.32), vitre)
	_lamp(Vector3(0, 4.5, FACADE_Z + 2.5), Color(1.0, 0.85, 0.6), 3.0, 12.0)
	# Le parvis : l'asphalte, le tapis rouge de l'arrêt aux portes, les bordures dorées.
	var parvis_l := ARRET_Z + 8.0 - FACADE_Z
	_box(Vector3(largeur, 0.2, parvis_l), Vector3(0, -0.1, FACADE_Z + parvis_l / 2.0), _std(Color(0.1, 0.1, 0.12), 0.85), true)
	_box(Vector3(4.0, 0.03, ARRET_Z - FACADE_Z - 1.5), Vector3(0, 0.015, (ARRET_Z + FACADE_Z) / 2.0), _std(Color(0.55, 0.04, 0.06), 0.9))
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.12, 0.05, ARRET_Z - FACADE_Z - 1.5), Vector3(s * 2.06, 0.025, (ARRET_Z + FACADE_Z) / 2.0), or_)
	# Les potelets dorés et leurs cordons rouges le long du tapis.
	var corde := _std(Color(0.6, 0.05, 0.08), 0.6)
	for k in 8:
		var z := FACADE_Z + 4.0 + k * 2.6
		for s: float in [-1.0, 1.0]:
			_cyl(0.05, 1.0, Vector3(s * 2.6, 0.5, z), or_)
			if k < 7:
				_box(Vector3(0.04, 0.04, 2.6), Vector3(s * 2.6, 0.85, z + 1.3), corde)
	# Les projecteurs qui balaient le ciel, de part et d'autre du parvis.
	var faisceau := StandardMaterial3D.new()
	faisceau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	faisceau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	faisceau.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	faisceau.albedo_color = Color(0.5, 0.55, 0.7, 0.12)
	faisceau.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 6:
		var pied := Vector3((-1.0 if k % 2 == 0 else 1.0) * (12.0 + (k / 2) * 9.0), 0, FACADE_Z + 6.0 + (k / 2) * 6.0)
		_cyl(0.7, 0.8, pied + Vector3(0, 0.4, 0), _std(Color(0.15, 0.15, 0.17), 0.5, 0.5))
		var pivot := Node3D.new()
		pivot.position = pied + Vector3(0, 0.9, 0)
		add_child(pivot)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 2.5
		cm.bottom_radius = 0.4
		cm.height = 70.0
		cm.cap_top = false
		cm.cap_bottom = false
		cone.mesh = cm
		cone.material_override = faisceau
		cone.position.y = 35.0
		pivot.add_child(cone)
		_faisceaux.append(pivot)
	# Les guichets de la billetterie, de part et d'autre des portes.
	for s: float in [-1.0, 1.0]:
		var g := Node3D.new()
		g.position = Vector3(s * 9.0, 0, FACADE_Z + 2.5)
		add_child(g)
		_box(Vector3(3.6, 2.8, 1.6), Vector3(0, 1.4, 0), _std(Color(0.08, 0.08, 0.1), 0.4), true, g)
		_box(Vector3(2.4, 0.9, 0.05), Vector3(0, 1.6, 0.81), _neon(Color(1.0, 0.85, 0.55), 0.9), false, g)
		_box(Vector3(3.8, 0.3, 1.8), Vector3(0, 2.95, 0), or_, false, g)
		_label3d("BILLETTERIE", g.position + Vector3(0, 2.4, 0.83), 40, _c2())
	_panneau_du_club()
	_arret_du_car()


## Le panneau du club, juste avant les portes, comme au stade : le club, son classement, son prochain match.
func _panneau_du_club() -> void:
	var panneau := Node3D.new()
	panneau.position = Vector3(-5.0, 0, FACADE_Z + 6.0)
	panneau.rotation.y = deg_to_rad(20.0)
	panneau.name = "PanneauDuClub"
	add_child(panneau)
	var or_ := _std(_c2(), 0.3, 0.8)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.12, 2.4, 0.12), Vector3(s * 1.05, 1.2, 0), or_, false, panneau)
	_box(Vector3(2.3, 1.4, 0.1), Vector3(0, 1.8, 0), _neon(_c1().darkened(0.3), 0.8), true, panneau)
	for t in [["LE PANNEAU DU CLUB", 2.25, 28, _c2()], [_enseigne(_nom_club()), 1.85, 34, Color(1, 1, 1)], ["Classement  ·  Prochain match", 1.45, 20, Color(0.8, 0.82, 0.9)]]:
		var l := Label3D.new()
		l.text = t[0]
		l.font = _serif
		l.font_size = t[2]
		l.pixel_size = 0.004
		l.modulate = t[3]
		l.outline_size = 0
		l.position = Vector3(0, t[1], 0.06)
		panneau.add_child(l)
	_interactive(panneau, "panneau", "E : lire le panneau du club", Vector3(2.4, 2.4, 1.6), Vector3(0, 1.2, 0.8))


## L'arrêt du car départemental, au bout du tapis rouge : le car ramène à la place de la commune.
func _arret_du_car() -> void:
	var arret := Node3D.new()
	arret.position = Vector3(5.0, 0, ARRET_Z)
	arret.rotation.y = PI
	arret.name = "ArretDuCar"
	add_child(arret)
	var verre := _std(Color(0.7, 0.85, 0.95, 0.3), 0.1)
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var vert := _std(Color(0.12, 0.32, 0.26), 0.6)
	_box(Vector3(3.6, 0.12, 1.6), Vector3(0, 2.5, 0), vert, false, arret)
	_box(Vector3(3.6, 2.4, 0.05), Vector3(0, 1.2, -0.75), verre, false, arret)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.08, 2.5, 0.08), Vector3(s * 1.75, 1.25, 0.7), vert, false, arret)
		_box(Vector3(0.08, 2.5, 0.08), Vector3(s * 1.75, 1.25, -0.75), vert, false, arret)
	_box(Vector3(2.4, 0.08, 0.4), Vector3(0, 0.5, -0.5), _std(Color(0.4, 0.3, 0.2), 0.7), false, arret)
	_cyl(0.04, 2.8, Vector3(-2.3, 1.4, 0.6), vert, arret)
	_cyl(0.34, 0.04, Vector3(-2.3, 2.7, 0.6), _std(Color(0.96, 0.8, 0.3), 0.6), arret)
	var nom := Label3D.new()
	nom.text = "CAR DÉPARTEMENTAL  ·  ARRÊT %s" % _enseigne(_nom_salle())
	nom.font = _serif
	nom.font_size = 36
	nom.pixel_size = 0.004
	nom.modulate = Color(0.95, 0.92, 0.82)
	nom.outline_size = 0
	nom.position = Vector3(0, 2.25, 0.82)
	arret.add_child(nom)
	_lamp(arret.position + Vector3(0, 2.3, -0.4), Color(1.0, 0.9, 0.7), 1.2, 6.0)
	_interactive(arret, "exit", "E : reprendre le car pour %s" % _place_commune(), Vector3(4.0, 2.6, 2.4), Vector3(0, 1.2, 0.4))


func _place_commune() -> String:
	var c: Commune = Communes.commune(commune)
	return "la place de %s" % (c.nom if c else "Smarves")


## Big Héron en statue de huit mètres, sur son socle au milieu du parvis : un héron cendré en maillot du
## club, le bec pointé vers les portes, les yeux d'or allumés.
func _heron_geant() -> void:
	var heron := Node3D.new()
	heron.position = Vector3(-14.0, 0, FACADE_Z + 16.0)
	heron.rotation.y = deg_to_rad(-150.0)
	heron.name = "StatueBigHeron"
	add_child(heron)
	var pierre := _std(Color(0.12, 0.12, 0.14), 0.4, 0.3)
	_box(Vector3(4.0, 1.4, 4.0), Vector3(0, 0.7, 0), pierre, true, heron)
	_box(Vector3(4.2, 0.15, 4.2), Vector3(0, 1.45, 0), _std(_c2(), 0.3, 0.8), false, heron)
	var gris := _std(Color(0.62, 0.66, 0.7), 0.6)
	var orange := _std(Color(0.95, 0.65, 0.2), 0.5)
	for s: float in [-1.0, 1.0]:
		_cyl(0.12, 3.2, Vector3(s * 0.45, 3.1, 0), orange, heron)
	var corps := _sphere(1.3, Vector3(0, 5.2, 0), _std(_c1(), 0.6), heron)
	corps.scale = Vector3(1.0, 0.9, 1.5)
	var cou := _cyl(0.32, 2.6, Vector3(0, 7.0, 0.9), gris, heron)
	cou.rotation.x = 0.35
	_sphere(0.55, Vector3(0, 8.4, 1.35), gris, heron)
	var bec := _cyl(0.0, 1.8, Vector3(0, 8.35, 2.6), orange, heron, 0.0)
	(bec.mesh as CylinderMesh).top_radius = 0.0
	(bec.mesh as CylinderMesh).bottom_radius = 0.18
	bec.rotation.x = PI / 2.0
	for s: float in [-1.0, 1.0]:
		_sphere(0.12, Vector3(s * 0.38, 8.55, 1.6), _neon(_c2(), 4.0), heron)
		var aile := _box(Vector3(0.25, 1.6, 2.6), Vector3(s * 1.35, 5.3, -0.2), gris, false, heron)
		aile.rotation.z = s * 0.25
	var maillot := Label3D.new()
	maillot.text = _court()
	maillot.font = _serif
	maillot.font_size = 160
	maillot.pixel_size = 0.006
	maillot.modulate = _c2()
	maillot.outline_size = 0
	maillot.position = Vector3(0, 5.3, 1.97)
	heron.add_child(maillot)
	var plaque := Label3D.new()
	plaque.text = "BIG HÉRON"
	plaque.font = _serif
	plaque.font_size = 60
	plaque.pixel_size = 0.005
	plaque.modulate = _c2()
	plaque.outline_size = 0
	plaque.position = Vector3(0, 0.8, 2.03)
	heron.add_child(plaque)
	_lamp(heron.position + Vector3(0, 1.8, 0) + heron.basis * Vector3(0, 0, 3.5), Color(1.0, 0.85, 0.6), 4.0, 14.0)


func _sphere(r: float, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


# --- La vie de la salle ---------------------------------------------------------------------------

## Les joueurs à l'entraînement, l'entraîneur, la mascotte sur l'autre panier, les danseuses qui répètent.
func _vivants() -> void:
	for k in 5:
		var c := CRITTER.new()
		c.randomize_look(500 + k)
		c.look["top_color"] = _couleurs()[0]
		c.scale = Vector3.ONE * ECHELLE_JOUEUR
		add_child(c)
		c.pose = c.Pose.WALK
		_joueurs.append(c)
	_ballon = _sphere(0.12, Vector3(0, 0.12, 0), _std(Color(0.85, 0.42, 0.12), 0.7))
	_ballon.name = "Ballon"
	var coach := CRITTER.new()
	coach.randomize_look(588)
	coach.look["top_color"] = "#202024"
	coach.scale = Vector3.ONE * PEOPLE_SCALE
	coach.position = Vector3(-5.0, 0, -P / 2.0 - 0.6)
	coach.rotation.y = PI * 0.15
	add_child(coach)
	# Big Héron, la mascotte : un habitant en costume gris, la tête trop grande, le maillot du club.
	_heron = CRITTER.new()
	_heron.randomize_look(777)
	_heron.look["top_color"] = _couleurs()[0]
	_heron.scale = Vector3.ONE * ECHELLE_JOUEUR * 1.1
	_heron.position = Vector3(L / 2.0 - 4.0, 0, 2.0)
	_heron.rotation.y = -PI / 2.0
	add_child(_heron)
	var bec := _cyl(0.0, 0.5, Vector3(0, 0.66, 0.16), _std(Color(0.95, 0.65, 0.2), 0.5), _heron, 0.0)
	(bec.mesh as CylinderMesh).bottom_radius = 0.04
	bec.rotation.x = PI / 2.0
	for k in 6:
		var d := CRITTER.new()
		d.randomize_look(900 + k)
		d.look["top_color"] = _couleurs()[1]
		d.scale = Vector3.ONE * PEOPLE_SCALE
		d.position = Vector3(-L / 2.0 + 3.0 + (k % 3) * 1.4, 0, -3.0 + (k / 3) * 2.0)
		d.rotation.y = PI / 2.0
		add_child(d)
		_danseuses.append(d)


## Le club s'entraîne : la salle clairsemée, les joueurs tournent et tirent, le cube annonce le prochain match.
func jouer_entrainement() -> void:
	_match = {}
	_remplir(0.12)
	for c in _joueurs:
		c.visible = true
	_ballon.visible = true
	var titre := "ENTRAÎNEMENT"
	var texte := "%s\nSAMEDI 20 H" % _court()
	_ecrire_cube(titre, texte)
	_defile_textes = [_enseigne(_nom_salle()), "%s  ·  ENTRAÎNEMENT" % _enseigne(_nom_club()), "PROCHAIN MATCH SAMEDI 20 H"]
	if _bandeau:
		_bandeau.visible = false


## Le match que le fil basket donne à voir : {dom, ext, score: [a, b], quarts: [[a, b]…], feuilles, fini, quand}.
## Le cube, la façade et le bandeau le disent ; la salle est comble.
func charger_match(match: Dictionary) -> void:
	if match.is_empty():
		jouer_entrainement()
		return
	_match = match
	_remplir(0.92)
	for c in _joueurs:
		c.visible = false
	_ballon.visible = false
	var dom := str(match.get("dom", _nom_club()))
	var ext := str(match.get("ext", "Les visiteurs"))
	var score: Array = match.get("score", [])
	if score.size() >= 2:
		var periode := "FIN" if bool(match.get("fini", false)) else "Q%d" % maxi(1, (match.get("quarts", []) as Array).size())
		afficher_score(dom, ext, int(score[0]), int(score[1]), periode, "")
	else:
		_ecrire_cube("PROCHAIN MATCH", "%s\n%s" % [_court_de(dom), str(match.get("quand", "SAMEDI 20 H"))])
		_defile_textes = ["%s  —  %s" % [_enseigne(dom), _enseigne(ext)], str(match.get("quand", "SAMEDI 20 H")).to_upper()]


## Le score sur le cube, la façade et le bandeau. periode : « Q1 »… « FIN » ; chrono : « 07:42 » ou « ».
func afficher_score(dom: String, ext: String, pts_dom: int, pts_ext: int, periode: String, chrono: String) -> void:
	_ecrire_cube("%s  %s" % [periode, chrono], "%s %d\n%s %d" % [_court_de(dom), pts_dom, _court_de(ext), pts_ext])
	_defile_textes = ["%s %d  —  %d %s" % [_court_de(dom), pts_dom, pts_ext, _court_de(ext)], "%s  ·  %s" % [_enseigne(_nom_salle()), periode]]
	_bandeau_score.text = "%s  %d  —  %d  %s     %s %s" % [dom, pts_dom, pts_ext, ext, periode, chrono]
	_bandeau.visible = true


## Un fait de match dans le bandeau (« Jones, trois points ! »).
func afficher_fait(texte: String) -> void:
	_bandeau_fait.text = texte
	_bandeau.visible = true


## Le sigle d'une équipe pour les écrans : celui du club de la salle, sinon les initiales du nom.
func _court_de(nom: String) -> String:
	if nom == _nom_club():
		return _court()
	var mots := []
	for m in _enseigne(nom).split(" ", false):
		if m.length() > 2:
			mots.append(m.left(1))
	return "".join(mots).left(3) if mots.size() > 1 else _enseigne(nom).left(3)


func _ecrire_cube(titre: String, texte: String) -> void:
	for l in _cube_titre:
		l.text = titre
	for l in _cube:
		l.text = texte


## Une part des places prises : la foule se montre ou se cache, place par place, toujours les mêmes.
func _remplir(part: float) -> void:
	var mm := _foule.multimesh
	var h := Hasard.depuis(77)
	var n := 0
	for i in _places.size():
		var t: Transform3D = _places[i]
		t.origin.y += 0.42
		if h.suivant() < part:
			n += 1
		else:
			t = t.scaled_local(Vector3.ZERO)
		mm.set_instance_transform(i, t)
	_foule.set_meta("prises", n)
	for d in _danseuses:
		d.debug_anim("idle")


func _process(delta: float) -> void:
	super._process(delta)
	var t := Time.get_ticks_msec() / 1000.0
	for i in _faisceaux.size():
		var p: Node3D = _faisceaux[i]
		p.rotation = Vector3(0.35 * sin(t * 0.4 + i), 0, 0.45 * sin(t * 0.3 + i * 1.7))
	if _anneau:
		_anneau.emission_energy_multiplier = 1.8 + 0.6 * sin(t * 2.0)
	_defile_t -= delta
	if _defile_t <= 0.0 and not _defile_textes.is_empty():
		_defile_t = 3.0
		_defile.text = _defile_textes[int(t / 3.0) % _defile_textes.size()]
	if _match.is_empty():
		_entrainement(delta)
	if _president and player:
		var d := player.global_position - _president.global_position
		_president.rotation.y = lerp_angle(_president.rotation.y, atan2(d.x, d.z), 0.05)


## Les cinq tournent en huit dans la moitié ouest et tirent au panier à tour de rôle ; la mascotte saute.
func _entrainement(delta: float) -> void:
	_parcours_t += delta
	var panier := Vector3(-L / 2.0 + 1.575, 3.05, 0)
	for k in _joueurs.size():
		var c: Node3D = _joueurs[k]
		var a := _parcours_t * 0.55 + k * TAU / _joueurs.size()
		var p := Vector3(-L / 2.0 + 7.0 + 3.2 * sin(a), 0, 4.0 * sin(a * 2.0) * 0.8)
		var d := p - c.position
		if d.length() > 0.01:
			c.rotation.y = atan2(d.x, d.z)
		c.position = p
	# Le ballon : du tireur du moment au cercle, en cloche, une fois toutes les trois secondes.
	var tireur: Node3D = _joueurs[int(_parcours_t / 3.0) % _joueurs.size()]
	var f := fmod(_parcours_t, 3.0) / 3.0
	var depart := tireur.position + Vector3(0, 2.2, 0)
	if f < 0.6:
		var u := f / 0.6
		_ballon.position = depart.lerp(panier, u) + Vector3(0, 3.0 * sin(PI * u), 0)
	else:
		var u := (f - 0.6) / 0.4
		_ballon.position = panier.lerp(Vector3(panier.x + 1.2, 0.12, 0.5), u) + Vector3(0, 1.2 * sin(PI * u), 0)
	if _heron:
		_heron.position.y = maxf(0.0, sin(_parcours_t * 2.2)) * 1.2


# --- Interface ------------------------------------------------------------------------------------

## Le bandeau du direct, en haut de l'écran, comme au stade : le score, la période, le dernier fait.
func _bandeau_du_direct() -> void:
	_bandeau = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.07, 0.14, 0.9)
	st.border_color = _c2()
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	_bandeau.add_theme_stylebox_override("panel", st)
	_bandeau.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bandeau.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bandeau.position.y = 18
	_bandeau.visible = false
	_bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	_bandeau.add_child(v)
	_bandeau_score = Label.new()
	_bandeau_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bandeau_score.add_theme_font_override("font", _serif)
	_bandeau_score.add_theme_font_size_override("font_size", 24)
	_bandeau_score.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	v.add_child(_bandeau_score)
	_bandeau_fait = Label.new()
	_bandeau_fait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bandeau_fait.add_theme_font_size_override("font_size", 16)
	_bandeau_fait.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	v.add_child(_bandeau_fait)
	_panel_layer.get_parent().add_child(_bandeau)


func _dire(texte: String) -> void:
	_speech.text = texte
	_speech.modulate.a = 1.0
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = create_tween()
	_speech_tween.tween_interval(3.0 + texte.length() * 0.03)
	_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.8)


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			reprendre_le_car()
		"president":
			_dire("%s : « %s »" % [_nom_president(), [
				"Bienvenue au %s. Ici, on ne joue pas au basket : on donne un spectacle." % _enseigne(_nom_salle()).capitalize(),
				"Le samedi soir, vingt mille places, et pas une de libre. C'est ce que je dis aux banquiers.",
				"Big Héron a raté son dunk au trampoline la semaine dernière. Le public a adoré.",
			].pick_random()])
			if _president.has_method("gesture"):
				_president.gesture("talk")
		"bureau":
			open_bureau()
		"panneau":
			open_panneau()
		"boutique":
			_dire("« Le maillot de %s, cent vingt crédits. Le flocage est offert si on gagne samedi. »" % _nom_club())
		"buvette":
			_dire(["« Un hot-dog, moutarde de Dijon, oignons du Clain. »", "« La bière du Clain, à la pression. On rend la consigne du gobelet à la sortie. »"].pick_random())
		"trophees":
			_dire("La vitrine attend ses trophées : le premier sera celui du championnat de la Vienne.")


## Le car ramène à la place de la commune : à l'arrêt du car, devant le café à défaut.
func reprendre_le_car() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if commune == Communes.ORIGINE or Communes.commune(commune) == null:
		Game.return_point = "car"
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		Game.return_point = "car"
		get_tree().change_scene_to_file(str(Communes.commune(commune).data.scene))


## Les écrans du club, faits par le fil basket : la salle les ouvre dès qu'ils existent. En attendant, une
## petite affiche du club (son nom, sa salle, ce qui vient) tient leur place.
func _ouvrir_ecran(chemin: String, titre: String, sinon: String) -> void:
	if _ecran != null:
		return
	var p: Control
	if ResourceLoader.exists(chemin):
		p = load(chemin).new()
		if "commune" in p:
			p.commune = commune
	else:
		p = _affiche(titre, sinon)
	p.connect("closed", func():
		p.queue_free()
		_ecran = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_ecran = p


func open_bureau() -> void:
	_ouvrir_ecran(BUREAU_BASKET, "Le bureau du club", "%s : « Le bureau est encore en travaux. Le championnat de basket commence bientôt, et on y fera tout ici : l'effectif, le mercato, les comptes. »" % _nom_president())


func open_panneau() -> void:
	_ouvrir_ecran(PANNEAU_BASKET, "Le panneau du club", "Le classement et le prochain match seront affichés ici pour la première journée du championnat, le samedi à 20 h.")


## L'affiche qui tient la place des écrans du fil basket : un panneau qu'on ferme.
class Affiche extends PanelContainer:
	signal closed


## L'affiche du club, aux couleurs du club : le titre, le club et sa salle, un texte, et « Fermer ».
func _affiche(titre: String, texte: String) -> PanelContainer:
	var p := Affiche.new()
	p.name = "Affiche"
	var st := StyleBoxFlat.new()
	st.bg_color = _c1().darkened(0.55)
	st.border_color = _c2()
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(26)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(560, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	for t in [[titre.to_upper(), 14, _c2()], [_nom_club(), 34, Color(1, 0.97, 0.9)], ["%s  ·  %s" % [_court(), _place_name()], 16, Color(0.8, 0.82, 0.9)], [texte, 18, Color(0.92, 0.92, 0.95)]]:
		var l := Label.new()
		l.text = t[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_override("font", _serif)
		l.add_theme_font_size_override("font_size", t[1])
		l.add_theme_color_override("font_color", t[2])
		v.add_child(l)
	var b := Button.new()
	b.text = "Fermer"
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): p.closed.emit())
	v.add_child(b)
	return p


## Ce que le parcours automatique (tools/smoke.gd) attend de tout intérieur : open_game() et _game.
var _game: Control:
	get:
		return _ecran


func open_game() -> void:
	open_bureau()


# --- Capture --------------------------------------------------------------------------------------

func _maybe_capture() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], v[4] if v.size() > 4 else 0.0, v[1])
			player.rotation.y = deg_to_rad(v[2])
			if v.size() > 3:
				player.camera.rotation.x = deg_to_rad(v[3])
		elif arg.begins_with("--won="):
			Game.won = int(arg.trim_prefix("--won="))
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(5.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
