class_name Stade
extends "res://scripts/shop_interior.gd"
## Le stade d'une commune, à la première personne, derrière son seuil (docs/SUITE.md, section 6) : la scène
## est au socle, la même pour toute commune qui déclare un terrain (« terrain_foot ») ; le nom du club, son
## sigle, ses couleurs, le nom du stade et la porte du retour viennent de cette structure, le président du
## lieu qui la porte (champ « hote »). Smarves y joue l'Étoile ; une autre commune l'ouvre par
## Football.ouvrir_stade(id), et sa sortie ramène dans sa scène, à la porte « lot » du terrain.
## La pelouse sous les projecteurs, la tribune couverte du club, le tableau d'affichage, et le match
## du dimanche qui se joue minute par minute sur la pelouse (FootMatch, le même état que la feuille du
## café) : les vingt-deux joueurs suivent le ballon, chaque action se joue en scènes (la construction dans
## son couloir, le centre de l'ailier, le corner tiré du poteau, le coup franc, le tir qui finit au fond,
## dans les gants ou sur le poteau), le commentateur parle en bas de l'écran, le tableau tient le score. Avant la première journée, l'Étoile s'entraîne et le tableau donne le coup d'envoi.
## L'interface, la capture et les petits outils viennent de l'intérieur des vendeurs (shop_interior.gd).
## Capture : godot --path . res://scenes/stade.tscn -- --capture=sortie.png [--at=x,z,lacet,tangage] [--won=…] [--journee=n] [--minute=m] [--commune=id]

## La pelouse : sa longueur (x) et sa largeur (z), et l'échelle des joueurs.
const L := 36.0
const P := 22.0
## Une minute de match par seconde ; Espace passe à quatre.
const COURSE := 4.2

var _etat := {}
var _joueurs := {}
var _hasard: Hasard
var _rencontre := {}
## Les joueurs sur la pelouse : id → son habitant, et où il va.
var _acteurs := {}
var _cibles := {}
var _ballon: MeshInstance3D
var _cible_ballon := Vector3.ZERO
## Les scènes d'une minute de match, jouées l'une après l'autre : {ballon, duree, porteur, vitesse, vol, action}.
## Le moteur dit ce qui arrive (le couloir, le centre, le corner, le tir) ; la pelouse le montre.
var _scenes: Array = []
var _scene_t := 0.0
var _vitesse_ballon := 14.0
var _vol := 0.0
var _depart_ballon := Vector3.ZERO
var _chrono := 0.0
var _possession := [0, 0]
var _score: Label3D
## Le bandeau du direct, en haut de l'écran : le score, la minute, le dernier fait (point UX des activités).
var _bandeau: PanelContainer
var _bandeau_score: Label
var _bandeau_fait: Label
var _bandeau_tween: Tween
var _horloge: Label3D
var _affiche: Label3D
var _supporters: Array = []
## Les minutes déjà jouées depuis le coup d'envoi réel, et le dernier match fini (son état complet).
var _pas := 0
var _resultat := {}
const MI_TEMPS := 15 * 60
const TABLEAU := preload("res://scripts/socle/foot_tableau.gd")
## Le président Chauvin, et sa causerie (les consignes du prochain match) quand elle est ouverte.
const CAUSERIE := preload("res://scripts/socle/foot_causerie.gd")
const MERCATO := preload("res://scripts/socle/foot_mercato.gd")
const OBLIGATIONS := preload("res://scripts/socle/foot_obligations.gd")
const LOCAUX := preload("res://scripts/socle/foot_locaux.gd")
const PANNEAU := preload("res://scripts/socle/foot_panneau.gd")
## L'intérieur du siège, hors les murs du stade : on y entre par la porte du siège, on en sort par la sienne.
var _siege_interieur := Vector3.ZERO
var _siege_porte := Vector3.ZERO
const BUREAU := "res://scripts/socle/bureau.gd"
var _president: Node3D
var _causerie: PanelContainer
## La commune dont c'est le stade, posée par ouvrir() avant le changement de scène (Smarves sinon), son
## terrain au registre, et son club dans la pyramide ("" tant qu'il attend la saison prochaine).
static var prochaine_commune := ""
var commune := ""
var _terrain := {}
var _club := ""
## Le décor du stade quand le terrain en nomme un (socle 1.13, champ « modele ») : une brique de la
## bibliothèque (« stade-de-campagne@1 ») ou une scène de la commune, branchée par ses ancres
## (scripts/socle/ancres.gd) ; null pour le stade du socle.
var _modele: Node3D


## Ouvre le stade d'une commune : la scène du socle, habillée de son terrain, ou la scène du stade que la
## commune a bâtie (socle 1.8, champ « scene » du terrain : son script hérite de celui-ci). La sortie
## ramène à sa scène.
static func ouvrir(id: String) -> void:
	prochaine_commune = id
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(Engine.get_main_loop() as SceneTree).change_scene_to_file(scene_de(id))


## La scène du stade d'une commune : celle de son terrain (champ « scene ») si elle existe, sinon celle du socle.
static func scene_de(id: String) -> String:
	for e in Registre.de_commune(id):
		if e.type == "terrain_foot":
			var sc := str(e.get("champs", {}).get("scene", ""))
			if sc != "" and ResourceLoader.exists(sc):
				return sc
	return "res://scenes/stade.tscn"


func _ready() -> void:
	commune = prochaine_commune if prochaine_commune != "" else Communes.origine().id
	prochaine_commune = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--commune="):
			commune = arg.trim_prefix("--commune=")
	if Football.niveaux.is_empty():
		Football.actualiser()
	for e in Registre.de_commune(commune):
		if e.type == "terrain_foot":
			_terrain = e
	_club = _club_de_la_commune()
	_serif = Polices.texte()
	_modele = _charger_modele()
	# Avec un décor, le sol du socle s'arrête aux abords du terrain (main courante, bancs, pylônes).
	W = L + 20.0 if _modele == null else L + 10.0
	D = P + 24.0 if _modele == null else P + 8.0
	_environment()
	_nuit()
	_pelouse()
	if _modele == null:
		_tribune()
		_entree()
		_siege()
		_tableau_affichage()
		_habillage()
		_le_president()
	else:
		_depuis_ancres()
	_build_ui()
	_bandeau_du_direct()
	player = PLAYER.new()
	player.position = Vector3(0, 0, -P / 2.0 - 4.0)
	player.rotation.y = PI
	var arrivee := Ancres.trouver(_modele, "Arrivee")
	if arrivee:
		player.position = arrivee.global_position
		player.rotation.y = arrivee.global_rotation.y + PI
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("village")
	_rencontre = _choisir()
	_composer()
	_maybe_capture()


func _place_name() -> String:
	var n := _nom_stade()
	return n.left(1).to_upper() + n.substr(1) if n != "le stade" else "Le stade municipal"


# --- Le terrain -----------------------------------------------------------------------------------

## La nuit du dimanche : un ciel sombre, une lune, et les quatre projecteurs qui font le jour sur la pelouse.
func _nuit() -> void:
	var we: WorldEnvironment = null
	for c in get_children():
		if c is WorldEnvironment:
			we = c
	if we:
		we.environment.background_color = Color(0.03, 0.04, 0.09)
		we.environment.ambient_light_color = Color(0.45, 0.5, 0.6)
		we.environment.ambient_light_energy = 0.5
		we.environment.sdfgi_enabled = false
		we.environment.ssil_enabled = false
		we.environment.fog_enabled = true
		we.environment.fog_light_color = Color(0.08, 0.1, 0.16)
		we.environment.fog_density = 0.004
	var lune := DirectionalLight3D.new()
	lune.light_color = Color(0.6, 0.7, 0.9)
	lune.light_energy = 0.25
	lune.rotation_degrees = Vector3(-55, 30, 0)
	add_child(lune)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pied := Vector3(sx * (L / 2.0 + 2.5), 0, sz * (P / 2.0 + 2.5))
			_cyl(0.12, 14.0, pied + Vector3(0, 7.0, 0), _std(Color(0.5, 0.52, 0.55), 0.6, 0.4))
			_box(Vector3(1.6, 0.8, 0.3), pied + Vector3(0, 14.2, 0), _std(Color(0.25, 0.25, 0.28), 0.6)).look_at_from_position(pied + Vector3(0, 14.2, 0), Vector3(0, 0.5, 0), Vector3.UP)
			var spot := SpotLight3D.new()
			spot.light_color = Color(1.0, 0.98, 0.9)
			spot.light_energy = 9.0
			spot.spot_range = 50.0
			spot.spot_angle = 50.0
			spot.shadow_enabled = sz < 0.0 and sx < 0.0
			add_child(spot)
			spot.position = pied + Vector3(0, 14.0, 0)
			spot.look_at(Vector3(sx * L / 6.0, 0, sz * P / 6.0), Vector3.UP)


## La pelouse rayée, ses lignes, ses buts, la main courante et le gravier des abords.
func _pelouse() -> void:
	_box(Vector3(W, 0.2, D), Vector3(0, -0.1, 0), _std(Color(0.42, 0.4, 0.34), 0.95), true)
	var bandes := 12
	for i in bandes:
		var c := Color(0.27, 0.5, 0.2) if i % 2 == 0 else Color(0.32, 0.56, 0.24)
		_box(Vector3((L + 4.0) / bandes, 0.04, P + 4.0), Vector3(-(L + 4.0) / 2.0 + (i + 0.5) * (L + 4.0) / bandes, 0.02, 0), _std(c, 1.0))
	var craie := _std(Color(0.96, 0.96, 0.94), 0.9)
	var lw := 0.12
	for seg in [[Vector3(0, 0, -P / 2.0), Vector3(L, 0.01, lw)], [Vector3(0, 0, P / 2.0), Vector3(L, 0.01, lw)],
			[Vector3(-L / 2.0, 0, 0), Vector3(lw, 0.01, P)], [Vector3(L / 2.0, 0, 0), Vector3(lw, 0.01, P)], [Vector3(0, 0, 0), Vector3(lw, 0.01, P)]]:
		_box(seg[1], seg[0] + Vector3(0, 0.045, 0), craie)
	for s in [-1.0, 1.0]:
		var gx: float = s * L / 2.0
		_box(Vector3(lw, 0.01, 11.0), Vector3(gx - s * 5.5, 0.045, 0), craie)
		_box(Vector3(5.5, 0.01, lw), Vector3(gx - s * 2.75, 0.045, -5.5), craie)
		_box(Vector3(5.5, 0.01, lw), Vector3(gx - s * 2.75, 0.045, 5.5), craie)
		_box(Vector3(0.2, 0.01, 0.2), Vector3(gx - s * 3.6, 0.045, 0), craie)
	for i in 28:
		var a := TAU * i / 28.0
		var b := _box(Vector3(lw, 0.01, 0.65), Vector3(cos(a), 0.045, sin(a)) * 2.9, craie)
		b.rotation.y = -a
	_box(Vector3(0.2, 0.01, 0.2), Vector3(0, 0.045, 0), craie)
	# Les buts et leurs filets.
	var blanc := _std(Color(0.95, 0.95, 0.93), 0.4)
	var filet := _std(Color(0.85, 0.88, 0.9, 0.55), 0.9)
	filet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for s in [-1.0, 1.0]:
		var gx: float = s * L / 2.0
		for zz in [-1.9, 1.9]:
			_cyl(0.06, 1.6, Vector3(gx, 0.8, zz), blanc)
			_box(Vector3(1.4, 0.03, 0.03), Vector3(gx + s * 0.7, 1.6, zz), filet)
		_cyl(0.06, 3.9, Vector3(gx, 1.6, 0), blanc).rotation_degrees.x = 90.0
		_box(Vector3(0.03, 1.6, 3.8), Vector3(gx + s * 1.4, 0.8, 0), filet)
		_box(Vector3(1.4, 0.03, 3.8), Vector3(gx + s * 0.7, 1.6, 0), filet)
		for zz in [-1.9, 1.9]:
			_box(Vector3(1.4, 1.6, 0.03), Vector3(gx + s * 0.7, 0.8, zz), filet)
	# La main courante, le gravier derrière, et les bancs de touche côté tribune.
	var barre := _std(Color(0.85, 0.85, 0.88), 0.3, 0.8)
	for s in [-1.0, 1.0]:
		_box(Vector3(L + 8.0, 0.05, 0.05), Vector3(0, 1.0, s * (P / 2.0 + 3.0)), barre)
		_box(Vector3(0.05, 0.05, P + 6.0), Vector3(s * (L / 2.0 + 4.0), 1.0, 0), barre)
		for k in 15:
			_cyl(0.025, 1.0, Vector3(-L / 2.0 - 4.0 + k * (L + 8.0) / 14.0, 0.5, s * (P / 2.0 + 3.0)), barre)
	for s in [-1.0, 1.0]:
		var bx: float = s * 7.0
		_box(Vector3(4.0, 0.08, 0.5), Vector3(bx, 0.5, -P / 2.0 - 2.0), _std(Color(0.55, 0.36, 0.22), 0.7))
		_box(Vector3(4.0, 0.9, 0.08), Vector3(bx, 0.95, -P / 2.0 - 2.3), _std(Color(0.2, 0.3, 0.45), 0.6))
		_box(Vector3(4.2, 0.06, 1.2), Vector3(bx, 1.5, -P / 2.0 - 1.9), _std(Color(0.2, 0.3, 0.45), 0.6))
	# Le ballon.
	_ballon = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	_ballon.mesh = sm
	_ballon.material_override = _std(Color(0.97, 0.97, 0.95), 0.5)
	_ballon.position = Vector3(0, 0.22, 0)
	add_child(_ballon)


## La tribune couverte, derrière la ligne de touche nord : trois rangs de gradins, le toit, les supporters,
## la grille et l'arche par où l'on est entré.
func _tribune() -> void:
	var beton := _std(Color(0.75, 0.73, 0.7), 0.9)
	var bois := _std(Color(0.55, 0.36, 0.22), 0.7)
	var bleu := _std(_couleur(), 0.6)
	var tz := -P / 2.0 - 4.0
	var tw := 22.0
	for i in 4:
		_box(Vector3(tw, 0.4 + i * 0.4, 1.0), Vector3(0, 0.2 + i * 0.2, tz - 0.5 - i * 1.0), beton, true)
		_box(Vector3(tw - 0.2, 0.08, 0.5), Vector3(0, 0.44 + i * 0.4, tz - 0.6 - i * 1.0), bois)
	_box(Vector3(tw + 1.0, 4.0, 0.3), Vector3(0, 2.8, tz - 4.6), _std(Color(0.92, 0.88, 0.8), 0.9), true)
	for px in [-tw / 2.0 + 0.3, -tw / 4.0, 0.0, tw / 4.0, tw / 2.0 - 0.3]:
		_box(Vector3(0.15, 4.2, 0.15), Vector3(px, 2.4, tz + 0.2), bleu)
	var toit := _box(Vector3(tw + 1.0, 0.12, 5.6), Vector3(0, 4.6, tz - 2.2), bleu)
	toit.rotation_degrees.x = -6.0
	_box(Vector3(tw + 1.0, 0.5, 0.08), Vector3(0, 4.3, tz + 0.25), _std(Color(0.97, 0.95, 0.9), 0.6))
	_label3d("%s  ·  %s" % [_enseigne(_nom_club()), _enseigne(_nom_stade())], Vector3(0, 4.3, tz + 0.3), 64, _couleur().darkened(0.1))
	# Les supporters, assis en tribune : ils se lèvent au but.
	var graine := 70
	for i in 4:
		for k in 7:
			if (i + k) % 3 == 1:
				continue
			graine += 1
			var c := CRITTER.new()
			c.randomize_look(graine)
			if graine % 2 == 0:
				c.look["top_color"] = _couleurs()[0]
			c.scale = Vector3.ONE * PEOPLE_SCALE
			c.position = Vector3(-tw / 2.0 + 1.5 + k * (tw - 3.0) / 6.0 + (i % 2) * 0.8, 0.4 + i * 0.4, tz - 0.3 - i * 1.0)
			add_child(c)
			c.debug_anim("sit")
			_supporters.append(c)
	# Un muret ferme le reste, et la buvette dans l'angle.
	var pierre := _std(Color(0.9, 0.86, 0.76), 0.9)
	_box(Vector3(W, 1.2, 0.3), Vector3(0, 0.6, -D / 2.0 + 0.2), pierre, true)
	_box(Vector3(0.3, 1.2, D), Vector3(-W / 2.0 + 0.2, 0.6, 0), pierre, true)
	_box(Vector3(0.3, 1.2, D), Vector3(W / 2.0 - 0.2, 0.6, 0), pierre, true)
	_box(Vector3(W, 1.2, 0.3), Vector3(0, 0.6, D / 2.0 - 0.2), pierre, true)
	var buvette := Node3D.new()
	buvette.position = Vector3(tw / 2.0 + 3.0, 0, tz - 1.0)
	add_child(buvette)
	_box(Vector3(3.0, 2.4, 2.0), Vector3.ZERO + Vector3(0, 1.2, 0), _std(Color(0.9, 0.85, 0.7), 0.8), true, buvette)
	_box(Vector3(3.2, 0.1, 1.2), Vector3(0, 2.45, 1.2), bleu, false, buvette)
	_box(Vector3(2.4, 0.08, 0.5), Vector3(0, 1.05, 1.2), bois, false, buvette)
	_label3d("BUVETTE", Vector3(0, 2.0, 1.02), 44, Color(0.95, 0.85, 0.6)).position += buvette.position
	_lamp(buvette.position + Vector3(0, 2.2, 1.6), Color(1.0, 0.8, 0.5), 1.2, 6.0)
	_interactive(buvette, "buvette", "E : un café à la buvette", Vector3(3.4, 2.4, 2.0), Vector3(0, 1.2, 1.8))
	# Les locaux du club, de l'autre côté de la tribune : le siège, où l'on gère le club comme avec le président.
	var locaux := Node3D.new()
	locaux.position = Vector3(-tw / 2.0 - 3.0, 0, tz - 1.0)
	add_child(locaux)
	_box(Vector3(3.2, 2.6, 2.2), Vector3(0, 1.3, 0), _std(Color(0.86, 0.82, 0.7), 0.8), true, locaux)
	_box(Vector3(3.4, 0.12, 2.5), Vector3(0, 2.62, 0.1), bleu, false, locaux)
	_box(Vector3(0.9, 2.0, 0.08), Vector3(0.4, 1.0, 1.12), bois, false, locaux)
	_box(Vector3(0.7, 0.6, 0.06), Vector3(-0.8, 1.6, 1.12), _std(Color(0.55, 0.7, 0.85), 0.3), false, locaux)
	_label3d("LE SIÈGE DU CLUB", Vector3(0, 2.25, 1.14), 36, Color(0.95, 0.85, 0.6)).position += locaux.position
	_lamp(locaux.position + Vector3(0, 2.3, 1.6), Color(1.0, 0.85, 0.6), 1.1, 6.0)
	_interactive(locaux, "locaux", "E : entrer au siège du club", Vector3(3.6, 2.6, 2.2), Vector3(0, 1.3, 1.6))
	_siege_porte = locaux.position + Vector3(0.4, 0, 2.4)


## L'entrée du stade, à part de la tribune pour qu'un stade qui la surcharge garde ou refasse la sienne :
## le portail (la sortie, dite et éclairée), la grille jusqu'au muret, le gravier, et le panneau du club.
func _entree() -> void:
	var bois := _std(Color(0.55, 0.36, 0.22), 0.7)
	var bleu := _std(_couleur(), 0.6)
	var tz := -P / 2.0 - 4.0
	var tw := 22.0
	# Derrière la tribune : la grille, et le portail de l'entrée, par où l'on sort sur la route du Bois.
	# Deux piliers, un fronton éclairé qui dit SORTIE, les deux vantaux ouverts, et le gravier qui y mène.
	var pierre := _std(Color(0.9, 0.86, 0.76), 0.9)
	var fer := _std(Color(0.18, 0.2, 0.22), 0.5, 0.6)
	var gx := -tw / 2.0 - 1.0
	var gz := tz + 1.0
	for s in [-1.0, 1.0]:
		_box(Vector3(0.4, 2.8, 0.4), Vector3(gx + s * 1.3, 1.4, gz), pierre, true)
		_box(Vector3(0.5, 0.12, 0.5), Vector3(gx + s * 1.3, 2.86, gz), pierre)
		# Les vantaux, ouverts vers l'intérieur du stade.
		var vantail := _box(Vector3(0.06, 1.9, 1.15), Vector3(gx + s * 1.1, 0.95, gz + 0.62), fer)
		vantail.rotation.y = s * 0.35
		for k in 5:
			_box(Vector3(0.06, 0.06, 1.15), Vector3(gx + s * 1.1, 0.25 + k * 0.4, gz + 0.62), fer).rotation.y = s * 0.35
	_box(Vector3(3.2, 0.5, 0.2), Vector3(gx, 3.0, gz), bleu)
	_label3d("SORTIE  ·  ROUTE DU BOIS" if commune == Communes.ORIGINE else "SORTIE", Vector3(gx, 3.0, gz + 0.12), 40, Color(1.0, 0.9, 0.55))
	_label3d(_enseigne(_nom_stade()), Vector3(gx, 3.0, gz - 0.12), 36, Color(1.0, 0.9, 0.55), PI)
	_lamp(Vector3(gx, 3.3, gz + 0.8), Color(1.0, 0.75, 0.45), 2.2, 9.0)
	_lamp(Vector3(gx, 3.3, gz - 0.8), Color(1.0, 0.75, 0.45), 1.6, 7.0)
	# La grille, du portail au muret ouest et le long de la tribune : la seule ouverture, c'est le portail.
	for px in [gx - 2.4, gx - 4.0, gx - 5.6, gx - 7.2]:
		_box(Vector3(0.08, 1.9, 0.08), Vector3(px, 0.95, gz), fer)
	_box(Vector3(gx - 1.6 - (-W / 2.0 + 0.4), 0.05, 0.05), Vector3((gx - 1.6 + (-W / 2.0 + 0.4)) / 2.0, 1.85, gz), fer)
	_box(Vector3(gx - 1.6 - (-W / 2.0 + 0.4), 0.05, 0.05), Vector3((gx - 1.6 + (-W / 2.0 + 0.4)) / 2.0, 1.0, gz), fer)
	# Le gravier, du portail au bord de la pelouse.
	var bord := -P / 2.0 - 3.2
	_box(Vector3(2.6, 0.02, bord - gz), Vector3(gx, 0.015, (gz + bord) / 2.0), _std(Color(0.62, 0.58, 0.5), 1.0))
	var sortie := Node3D.new()
	sortie.position = Vector3(gx, 0, gz)
	add_child(sortie)
	_interactive(sortie, "exit", "E : sortir sur la route du Bois" if commune == Communes.ORIGINE else "E : sortir du stade", Vector3(2.6, 2.6, 2.4), Vector3(0, 1.2, 0))
	# Le panneau du club, juste passé le portail : l'essentiel du club et le registre des obligations,
	# pour qui entre, qu'il dirige le club ou non (demande de Guillaume du 19 octobre 2026).
	var panneau := Node3D.new()
	panneau.position = Vector3(gx + 3.6, 0, gz + 0.3)
	add_child(panneau)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.1, 2.3, 0.1), Vector3(s * 0.95, 1.15, 0), bois, false, panneau)
	_box(Vector3(2.1, 1.3, 0.08), Vector3(0, 1.75, 0), _std(Color(0.16, 0.22, 0.2), 0.9), true, panneau)
	_box(Vector3(2.2, 0.1, 0.5), Vector3(0, 2.45, 0.1), bleu, false, panneau)
	_label3d("LE PANNEAU DU CLUB", Vector3(0, 2.15, 0.06), 30, Color(1.0, 0.9, 0.55)).position += panneau.position
	_label3d(_enseigne(_nom_club()), Vector3(0, 1.75, 0.06), 34, Color(0.95, 0.95, 0.9)).position += panneau.position
	_label3d("Classement  ·  Prochain match  ·  Les obligations", Vector3(0, 1.4, 0.06), 20, Color(0.75, 0.8, 0.78)).position += panneau.position
	_lamp(panneau.position + Vector3(0, 2.6, 0.9), Color(1.0, 0.85, 0.6), 1.0, 5.0)
	_interactive(panneau, "panneau", "E : lire le panneau du club", Vector3(2.4, 2.4, 1.6), Vector3(0, 1.2, 0.8))

## L'intérieur du siège (demande de Guillaume du 19 octobre 2026 : « le bureau du stade possède un intérieur
## où on peut faire la gestion ») : une pièce hors les murs du stade, où la porte du siège mène. Le bureau
## du président, sa chaise, l'étagère aux coupes, la fenêtre sur la nuit ; E au bureau ouvre la page de
## gestion (open_locaux), la porte ramène devant le siège.
func _siege() -> void:
	var tz := -P / 2.0 - 4.0
	_siege_interieur = Vector3(-W / 2.0 - 10.0, 0, tz - 1.0)
	var piece := Node3D.new()
	piece.name = "Siege"
	piece.position = _siege_interieur
	add_child(piece)
	var mur := _std(Color(0.88, 0.84, 0.72), 0.9)
	var parquet := _std(Color(0.5, 0.34, 0.2), 0.7)
	var bois := _std(Color(0.42, 0.28, 0.16), 0.6)
	var bleu := _std(_couleur(), 0.6)
	var lx := 7.0
	var lz := 5.0
	var h := 2.8
	_box(Vector3(lx, 0.2, lz), Vector3(0, -0.1, 0), parquet, true, piece)
	_box(Vector3(lx, 0.1, lz), Vector3(0, h + 0.05, 0), _std(Color(0.95, 0.93, 0.88), 0.9), false, piece)
	_box(Vector3(lx, h, 0.2), Vector3(0, h / 2.0, -lz / 2.0), mur, true, piece)
	_box(Vector3(lx, h, 0.2), Vector3(0, h / 2.0, lz / 2.0), mur, true, piece)
	_box(Vector3(0.2, h, lz), Vector3(-lx / 2.0, h / 2.0, 0), mur, true, piece)
	_box(Vector3(0.2, h, lz), Vector3(lx / 2.0, h / 2.0, 0), mur, true, piece)
	# La fenêtre sur la nuit, côté ouest, et la porte au sud.
	_box(Vector3(0.06, 1.2, 1.8), Vector3(-lx / 2.0 + 0.12, 1.6, 0), _std(Color(0.3, 0.42, 0.6), 0.2), false, piece)
	var porte := Node3D.new()
	porte.position = Vector3(1.6, 0, lz / 2.0 - 0.12)
	piece.add_child(porte)
	_box(Vector3(1.0, 2.1, 0.08), Vector3(0, 1.05, 0), bois, false, porte)
	_box(Vector3(0.08, 0.08, 0.08), Vector3(0.38, 1.0, -0.06), _std(Color(0.85, 0.75, 0.4), 0.3, 0.8), false, porte)
	_interactive(porte, "sortir_siege", "E : ressortir au stade", Vector3(1.4, 2.2, 1.2), Vector3(0, 1.1, -0.5))
	# Le bureau du président, face à la porte : la table, la chaise, la lampe, le fanion du club.
	var bureau := Node3D.new()
	bureau.position = Vector3(0, 0, -lz / 2.0 + 1.4)
	piece.add_child(bureau)
	_box(Vector3(2.2, 0.08, 1.0), Vector3(0, 0.78, 0), bois, true, bureau)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.5, 0.74, 0.9), Vector3(s * 0.8, 0.37, 0), bois, false, bureau)
	_box(Vector3(0.5, 0.06, 0.5), Vector3(0, 0.5, -0.8), bois, false, bureau)
	_box(Vector3(0.5, 0.6, 0.06), Vector3(0, 0.8, -1.05), bois, false, bureau)
	_box(Vector3(0.4, 0.04, 0.3), Vector3(-0.6, 0.84, 0), _std(Color(0.9, 0.9, 0.86), 0.9), false, bureau)
	_box(Vector3(0.3, 0.28, 0.3), Vector3(0.7, 0.98, -0.2), _std(Color(0.96, 0.9, 0.7), 0.5), false, bureau)
	_label3d("LE BUREAU", Vector3(0, 2.1, -1.3), 30, Color(1.0, 0.9, 0.55)).position += piece.position + bureau.position
	_interactive(bureau, "bureau", "E : s'asseoir au bureau, la gestion du club", Vector3(2.6, 2.0, 2.0), Vector3(0, 1.0, 0.9))
	# L'étagère aux coupes, le tableau du club, le fanion.
	var etagere := Node3D.new()
	etagere.position = Vector3(lx / 2.0 - 0.35, 0, -0.6)
	piece.add_child(etagere)
	for k in 3:
		_box(Vector3(0.4, 0.04, 2.2), Vector3(0, 0.8 + k * 0.6, 0), bois, false, etagere)
	for k in 5:
		_cyl(0.07, 0.3, Vector3(0, 0.98 + (k % 3) * 0.6, -0.8 + k * 0.4), _std(Color(0.9, 0.78, 0.4), 0.3, 0.9), etagere)
	_box(Vector3(0.06, 0.9, 1.6), Vector3(-lx / 2.0 + 0.14, 1.7, -lz / 2.0 + 1.4), bleu, false, piece)
	_label3d(_enseigne(_nom_club()), Vector3(-lx / 2.0 + 0.2, 1.7, -lz / 2.0 + 1.4), 30, Color(0.98, 0.95, 0.85), PI / 2.0).position += piece.position
	_box(Vector3(1.4, 0.9, 0.06), Vector3(-1.8, 1.8, -lz / 2.0 + 0.14), _std(Color(0.2, 0.26, 0.24), 0.9), false, piece)
	_label3d("%s\n%s" % [_enseigne(_nom_club()), _enseigne(_nom_stade())], Vector3(-1.8, 1.8, -lz / 2.0 + 0.18), 22, Color(0.95, 0.95, 0.9)).position += piece.position
	_lamp(piece.position + Vector3(0, h - 0.3, 0), Color(1.0, 0.86, 0.62), 2.0, 8.0)


## On entre au siège : l'habitant passe dans la pièce, face au bureau.
func _entrer_siege() -> void:
	if _sans_club():
		return
	player.position = _siege_interieur + Vector3(1.6, 0, 1.2)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	_dire("Le siège du club. Au bureau, la gestion : l'effectif, la tactique, le championnat.")


## On ressort du siège : devant sa porte, face à la pelouse.
func _sortir_siege() -> void:
	player.position = _siege_porte
	player.rotation.y = PI
	player.velocity = Vector3.ZERO


## Le décor du stade que nomme le terrain (socle 1.13, champ « modele ») : la scène d'une brique de la
## bibliothèque (« stade-de-campagne@1 ») ou celle de la commune (res://communes/<id>/….tscn), sans
## héritage ; posée sous le stade, elle doit tenir le contrat d'ancres du stade. Un décor introuvable ou
## qui ne le tient pas est laissé : le stade du socle prend sa place, et le journal dit pourquoi.
func _charger_modele() -> Node3D:
	return _charger_decor(str(_terrain.get("champs", {}).get("modele", "")), "stade", "Stade")


## Ce que le socle pose sur les ancres du décor : le tableau d'affichage, le président, le bureau, le
## panneau du club, la sortie, et, si le décor les a, le fronton de la tribune et la buvette. La pelouse et
## le match sont déjà là (_pelouse) ; il n'y a pas de siège à part : la gestion est au bureau.
func _depuis_ancres() -> void:
	var t := Ancres.trouver(_modele, "Tableau")
	var lacet := rad_to_deg(t.global_rotation.y)
	_score = _label3d("0 - 0", _vers(t, Vector3(0, 0.4, 0.05)), 160, Color(1.0, 0.85, 0.3), lacet)
	_horloge = _label3d("", _vers(t, Vector3(0, -0.35, 0.05)), 48, Color(0.95, 0.95, 0.9), lacet)
	_affiche = _label3d("", _vers(t, Vector3(0, -0.85, 0.05)), 34, Color(0.8, 0.85, 0.95), lacet)
	for l in [_score, _horloge, _affiche]:
		l.shaded = false
	_lamp(_vers(t, Vector3(0, 0.7, 1.5)), Color(1.0, 0.9, 0.7), 1.0, 6.0)
	var feuille := _pied(t, Vector3(0, -t.global_position.y, 1.0))
	_interactive(feuille, "feuille", "E : lire la feuille du dernier match", Vector3(7.0, 2.5, 2.0), Vector3(0, 1.2, 0))
	var p := Ancres.trouver(_modele, "President")
	_poser_president(to_local(p.global_position), p.global_rotation.y, rad_to_deg(p.global_rotation.y))
	_interactive(_pied(Ancres.trouver(_modele, "Bureau")), "bureau", "E : le bureau du président, la gestion du club", Vector3(2.0, 2.0, 2.0), Vector3(0, 1.0, 0.6))
	var pn := Ancres.trouver(_modele, "Panneau")
	var lp := rad_to_deg(pn.global_rotation.y)
	_label3d("LE PANNEAU DU CLUB", _vers(pn, Vector3(0, 2.15, 0.06)), 30, Color(1.0, 0.9, 0.55), lp)
	_label3d(_enseigne(_nom_club()), _vers(pn, Vector3(0, 1.75, 0.06)), 34, Color(0.95, 0.95, 0.9), lp)
	_label3d("Classement  ·  Prochain match  ·  Les obligations", _vers(pn, Vector3(0, 1.4, 0.06)), 20, Color(0.75, 0.8, 0.78), lp)
	_lamp(_vers(pn, Vector3(0, 2.6, 0.9)), Color(1.0, 0.85, 0.6), 1.0, 5.0)
	_interactive(_pied(pn), "panneau", "E : lire le panneau du club", Vector3(2.4, 2.4, 1.6), Vector3(0, 1.2, 0.8))
	var origine := commune == Communes.ORIGINE
	_interactive(_pied(Ancres.trouver(_modele, "Sortie")), "exit", "E : sortir sur la route du Bois" if origine else "E : sortir du stade", Vector3(2.6, 2.6, 2.4), Vector3(0, 1.2, 0))
	var f := Ancres.trouver(_modele, "TribuneClub")
	if f:
		_label3d("%s  ·  %s" % [_enseigne(_nom_club()), _enseigne(_nom_stade())], _vers(f, Vector3.ZERO), 64, _couleur().darkened(0.1), rad_to_deg(f.global_rotation.y))
	var b := Ancres.trouver(_modele, "Buvette")
	if b:
		_interactive(_pied(b), "buvette", "E : un café à la buvette", Vector3(3.4, 2.4, 2.0), Vector3(0, 1.2, 0.4))


## L'habillage de la commune (socle 1.6, champ « habillage » du terrain) : sa scène, posée autour de la
## pelouse ; la pelouse, la tribune, le tableau et le match restent ceux du socle. La scène lit le club
## par son parent (le stade : _nom_club(), _couleurs()…) si elle en a besoin.
func _habillage() -> void:
	var chemin := str(_terrain.get("champs", {}).get("habillage", ""))
	if chemin == "" or not ResourceLoader.exists(chemin):
		return
	var scene := load(chemin) as PackedScene
	if scene:
		var n := scene.instantiate()
		n.name = "Habillage"
		add_child(n)


## Le tableau d'affichage, derrière la touche sud, face à la tribune.
## Le président du club (l'hôte du lieu qui porte le terrain), debout au bord de la pelouse devant sa
## tribune : E ouvre la causerie.
func _le_president() -> void:
	_poser_president(Vector3(9.0, 0, -P / 2.0 - 2.4), PI * 0.75, 180.0)


## Le président à cette place, tourné de ce lacet (le personnage regarde son +Z), avec son nom (tourné de
## nom_y degrés, face au visiteur) et sa causerie.
func _poser_president(pos: Vector3, lacet: float, nom_y: float) -> void:
	var c := CRITTER.new()
	c.randomize_look(1987)
	c.look["top"] = "veste"
	c.look["top_color"] = "#2b2f3a"
	c.look["legs"] = "pantalon"
	c.look["legs_color"] = "#3a3a44"
	c.look["hat"] = "casquette"
	c.look["hat_color"] = _couleurs()[0]
	c.look.erase("prop_r")
	c.look.erase("apron")
	c.scale = Vector3.ONE * PEOPLE_SCALE
	c.position = pos
	c.rotation.y = lacet
	add_child(c)
	_president = c
	_label3d(_nom_president(), c.position + Vector3(0, 2.3, 0), 22, Color(0.95, 0.85, 0.6), nom_y)
	_interactive(c, "president", "E : parler %s" % _a(_nom_president()), Vector3(1.2, 1.0, 1.2), Vector3(0, 0.4, 0))


## La causerie : les consignes de l'Étoile pour son prochain match, dans la même ardoise que le tableau du café.
func open_causerie() -> void:
	if _causerie != null:
		return
	if _sans_club():
		return
	var p: PanelContainer = CAUSERIE.new()
	p.club = _club
	p.closed.connect(func():
		p.queue_free()
		_causerie = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	p.bureau.connect(func():
		p.queue_free()
		_causerie = null
		open_locaux())
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_causerie = p


## Le mercato : les joueurs libres de la saison, et la recrue du club, dans la même ardoise.
func open_mercato() -> void:
	if _causerie != null:
		return
	if _sans_club():
		return
	var p: PanelContainer = MERCATO.new()
	p.club = _club
	p.closed.connect(func():
		p.queue_free()
		_causerie = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_causerie = p


## Les locaux du club : le siège. C'est le bureau du club (scripts/socle/bureau.gd, le fil « Bureau du club et
## mercato » : la page pleine écran façon Football Manager, var club et signal closed) dès qu'il existe ; en
## attendant, le petit panneau des locaux, d'où l'on ouvre la causerie, le mercato et le registre des obligations.
func open_locaux() -> void:
	if _causerie != null:
		return
	if _sans_club():
		return
	if ResourceLoader.exists(BUREAU):
		var b: Control = load(BUREAU).new()
		b.club = _club
		# Le bouton « Le registre des obligations » du bureau : on ferme la page, le registre s'ouvre à sa place.
		if b.has_signal("obligations"):
			b.obligations.connect(func():
				b.closed.emit()
				open_obligations.call_deferred())
		b.closed.connect(func():
			b.queue_free()
			_causerie = null
			player.frozen = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
		player.frozen = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_panel_layer.add_child(b)
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_causerie = b
		return
	var p: PanelContainer = LOCAUX.new()
	p.club = _club
	var fermer := func():
		p.queue_free()
		_causerie = null
	p.closed.connect(func():
		fermer.call()
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	p.causerie.connect(func():
		fermer.call()
		open_causerie())
	p.mercato.connect(func():
		fermer.call()
		open_mercato())
	p.obligations.connect(func():
		fermer.call()
		open_obligations())
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_causerie = p


## Ce que le parcours automatique (tools/smoke.gd) attend de tout intérieur : open_game() ouvre « le jeu »
## du lieu, _game est sa fenêtre. Au stade, le jeu, c'est le club : le siège, qui ouvre tout le reste.
var _game: Control:
	get:
		return _causerie


func open_game() -> void:
	open_locaux()


## Le panneau du club, à l'entrée : l'essentiel du club, ses porteurs d'obligations, et le registre.
func open_panneau() -> void:
	if _causerie != null:
		return
	var p: PanelContainer = PANNEAU.new()
	p.club = _club
	p.closed.connect(func():
		p.queue_free()
		_causerie = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_causerie = p


## Le registre des obligations du club, le même qu'à l'étude de Maître Garnier.
func open_obligations() -> void:
	if _causerie != null:
		return
	if _sans_club():
		return
	var p: PanelContainer = OBLIGATIONS.new()
	p.club = _club
	p.closed.connect(func():
		p.queue_free()
		_causerie = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_causerie = p


## Le club de la commune dans la pyramide (celui de son terrain), ou "" s'il attend la saison prochaine.
func _club_de_la_commune() -> String:
	for id in Football.clubs:
		if str(Football.clubs[id].get("commune", "")) == commune and not Football.clubs[id].get("invite", false):
			return id
	return ""


## Ce que la structure « terrain_foot » dit du club et du stade, avec le club de la pyramide en secours.
func _nom_club() -> String:
	var c: Dictionary = Football.clubs.get(_club, {})
	return str(_terrain.get("champs", {}).get("club", c.get("nom", "le club")))


func _nom_stade() -> String:
	var c: Dictionary = Football.clubs.get(_club, {})
	return str(_terrain.get("nom", c.get("stade", "le stade")))


func _couleurs() -> Array:
	var c: Array = _terrain.get("champs", {}).get("couleurs", Football.clubs.get(_club, {}).get("couleurs", []))
	return c if c.size() >= 2 else ["#1b3c8c", "#f2c94c"]


## La couleur du club pour les bancs, la tribune, les toits : la première, un peu éteinte.
func _couleur() -> Color:
	return Color.from_string(str(_couleurs()[0]), Color(0.2, 0.3, 0.45)).lerp(Color(0.2, 0.3, 0.45), 0.35)


## Le président : l'hôte du lieu du manifeste qui porte le terrain (même id, ou la porte « lot »).
func _nom_president() -> String:
	var c: Commune = Communes.commune(commune)
	if c:
		for l in c.lieux():
			if l.id == _terrain.get("id", "") or (l.id == _terrain.get("lot", "") and l.id != ""):
				return str(l.host) if str(l.host) != "" else "Le président"
	return "Le président"


## « Le stade municipal » → « STADE MUNICIPAL ».
static func _enseigne(nom: String) -> String:
	var n := nom.strip_edges()
	for a in ["Le ", "La ", "Les ", "L'", "L’"]:
		if n.begins_with(a):
			n = n.substr(a.length())
			break
	return n.to_upper()


## « Le président Chauvin » → « au président Chauvin » ; « Mme Rivière » → « à Mme Rivière ».
static func _a(nom: String) -> String:
	if nom.begins_with("Le "):
		return "au " + nom.substr(3)
	if nom.begins_with("La "):
		return "à la " + nom.substr(3)
	if nom.begins_with("L'") or nom.begins_with("L’"):
		return "à l'" + nom.substr(2)
	return "à " + nom


## La porte du village où l'on ressort : le « lot » du terrain, sinon son id (« stade » à Smarves).
func _lot() -> String:
	var lot := str(_terrain.get("lot", ""))
	return lot if lot != "" else str(_terrain.get("id", "stade"))


## Le club n'est pas encore dans la pyramide : rien à décider, le président le dit.
func _sans_club() -> bool:
	if _club != "":
		return false
	_dire("« %s entre dans le championnat à la saison prochaine. D'ici là, on s'entraîne. »" % _nom_club())
	return true


func _tableau_affichage() -> void:
	var z := P / 2.0 + 5.0
	var noir := _std(Color(0.08, 0.09, 0.1), 0.5)
	for x in [-3.2, 3.2]:
		_box(Vector3(0.2, 4.0, 0.2), Vector3(x, 2.0, z), _std(Color(0.4, 0.42, 0.45), 0.6, 0.4))
	_box(Vector3(7.4, 2.6, 0.3), Vector3(0, 4.3, z), noir)
	_box(Vector3(7.6, 0.2, 0.4), Vector3(0, 5.7, z), _std(Color(0.2, 0.3, 0.45), 0.6))
	_score = _label3d("0 - 0", Vector3(0, 4.7, z - 0.17), 160, Color(1.0, 0.85, 0.3), 180.0)
	_score.shaded = false
	_horloge = _label3d("", Vector3(0, 3.95, z - 0.17), 48, Color(0.95, 0.95, 0.9), 180.0)
	_horloge.shaded = false
	_affiche = _label3d("", Vector3(0, 3.45, z - 0.17), 34, Color(0.8, 0.85, 0.95), 180.0)
	_affiche.shaded = false
	_lamp(Vector3(0, 5.0, z - 1.5), Color(1.0, 0.9, 0.7), 1.0, 6.0)
	var feuille := Node3D.new()
	feuille.position = Vector3(0, 0, z - 1.0)
	add_child(feuille)
	_interactive(feuille, "feuille", "E : lire la feuille du dernier match", Vector3(7.0, 2.5, 2.0), Vector3(0, 1.2, 0))


# --- Le match -------------------------------------------------------------------------------------

## Le match du stade : celui de l'Étoile à la dernière journée dont le coup d'envoi est donné, sinon le
## premier match de la division suivie à la journée 1. Il ne se suit qu'en direct, à l'heure réelle du
## coup d'envoi (une minute de jeu par minute, un quart d'heure de mi-temps) ; avant, l'Étoile
## s'entraîne ; après, le tableau d'affichage garde le score et la feuille se lit au tableau.
func _choisir() -> Dictionary:
	if Football.niveaux.is_empty():
		Football.actualiser()
	var d: Array = Football.place_de(_club) if _club != "" else []
	if d.is_empty():
		var tableau: PanelContainer = FootTableau.new()
		d = tableau.division_suivie()
		tableau.free()
	var s: int = Football.saison
	var joues: int = Football.journee_jouee()
	var j: int = joues if joues > 0 else 1
	var matchs: Array = Football.journee(s, d[0], d[1], j, joues)
	if matchs.is_empty():
		# Un club seul dans sa division : pas de match, le championnat attend un deuxième club.
		return {}
	var choisi: Dictionary = matchs[0]
	for m in matchs:
		if _club != "" and (m.dom == _club or m.ext == _club):
			choisi = m
	return {"s": s, "j": j, "dom": choisi.dom, "ext": choisi.ext, "joue": joues > 0, "coup_envoi": Football.coup_envoi(s, j)}


## Les vingt-deux sur la pelouse, le tableau, et le match remis à l'heure réelle : en cours, il reprend
## à la minute où l'on en est ; fini, le tableau garde le score et l'Étoile s'entraîne ; pas commencé,
## l'Étoile s'entraîne et le tableau annonce le coup d'envoi.
func _composer() -> void:
	if _rencontre.is_empty():
		_attendre()
		return
	var r := _rencontre
	var cd: Dictionary = Football.clubs[r.dom]
	var ce: Dictionary = Football.clubs[r.ext]
	var direct: Dictionary = Football.rencontre_en_direct(r.s, r.j, r.dom, r.ext)
	_etat = direct.etat
	_joueurs = direct.joueurs
	_hasard = direct.hasard
	_pas = 0
	for i in 2:
		var eq: Dictionary = _etat.equipes[i]
		var club: Dictionary = cd if i == 0 else ce
		for e in eq.onze:
			_acteur(e.id, i, club.couleurs)
	_score.text = "%s  0 - 0  %s" % [cd.court, ce.court]
	_score.font_size = 110
	if r.joue:
		_horloge.text = "Journée %d  ·  0'" % r.j
		_affiche.text = "%s – %s  ·  %s" % [cd.nom, ce.nom, FootTableau.date(r.coup_envoi)]
		_synchroniser(true)
		if _etat.fini:
			_terminer()
		elif not _etat.evenements.is_empty():
			_dire(_etat.evenements[-1].texte)
	else:
		_entrainer()
		_note("%s s'entraîne sous les projecteurs. %s" % [_nom_club(), _affiche.text])
	_placer(true)


## Sans match (le club est seul dans sa division, ou la commune n'a pas de club) : le club de la commune
## s'entraîne, le tableau dit que le championnat attend un deuxième club.
func _attendre() -> void:
	_etat = {}
	_joueurs = {}
	var pj: Array = Football.prochaine_journee()
	var club: String = _club if _club != "" else (Football.niveaux[0][0][0] if not Football.niveaux[0][0].is_empty() else "")
	if club != "":
		_joueurs = Football.effectif(club, pj[0], pj[1])
		var c: Dictionary = Football.clubs[club]
		for id in FootMatch.compo_auto(_joueurs.keys(), _joueurs, "4-4-2"):
			if id != null:
				_acteur(id, 0, c.couleurs)
		_score.text = c.court
	else:
		_score.text = "—"
	_score.font_size = 110
	_horloge.text = "Entraînement"
	var nb := 0
	for n in Football.niveaux:
		for g in n:
			nb += g.size()
	_affiche.text = "Le championnat attend un deuxième club." if nb < 2 else "Pas de match pour %s cette saison." % _nom_club()
	_note("%s s'entraîne sous les projecteurs. %s" % [_nom_club(), _affiche.text])
	_placer(true)


## Remet le match à l'heure : une minute de jeu par minute réelle depuis le coup d'envoi, et un quart
## d'heure de mi-temps. Appelé à l'arrivée (d'un coup) puis à chaque image.
func _synchroniser(dun_coup := false) -> void:
	if _etat.is_empty():
		return
	var du: int = Football.maintenant() - int(_rencontre.coup_envoi)
	while not _etat.fini:
		var seuil: int = _pas * 60 + (MI_TEMPS if _etat.pause == "mi-temps" or _etat.periode == 2 else 0)
		if du < seuil:
			break
		_minute()
		_pas += 1
		if dun_coup:
			_scenes.clear()
			_vol = 0.0
			_vitesse_ballon = 14.0
			_placer(true)


## Le match est fini (à l'arrivée ou sous nos yeux) : le tableau garde le score, la feuille se lit au
## tableau d'affichage, et l'Étoile revient s'entraîner.
func _terminer() -> void:
	_resultat = _etat
	if _bandeau != null and _bandeau.visible:
		_afficher_bandeau(_score_bandeau(), "Terminé, la feuille au tableau.")
		_effacer_bandeau(8.0)
	_score.text = "%s  %d - %d  %s" % [Football.clubs[_rencontre.dom].court, _etat.score[0], _etat.score[1], Football.clubs[_rencontre.ext].court]
	_horloge.text = "Journée %d  ·  terminé" % _rencontre.j
	_affiche.text = "%s – %s  ·  la feuille de match au tableau (E)" % [Football.clubs[_rencontre.dom].nom, Football.clubs[_rencontre.ext].nom]
	_entrainer()


## L'Étoile s'entraîne : plus de match sur la pelouse, le tableau annonce le prochain coup d'envoi.
func _entrainer() -> void:
	_etat = {}
	var pce: Array = Football.prochain_coup_envoi(Football.maintenant())
	var quand := "%s à %d h" % [FootTableau.date(pce[2]), Football.HEURE_COUP_ENVOI]
	if _resultat.is_empty():
		_horloge.text = "Entraînement"
		_affiche.text = "Journée %d : coup d'envoi %s" % [pce[1], quand]
	else:
		_affiche.text += "\nProchain coup d'envoi : %s" % quand


## La feuille du dernier match, sur l'ardoise du tableau du dimanche.
func open_feuille() -> void:
	if _causerie != null:
		return
	if _resultat.is_empty():
		_dire("« Pas de feuille à lire : le match n'est pas joué. Reviens dimanche à %d h. »" % Football.HEURE_COUP_ENVOI)
		return
	var p: PanelContainer = TABLEAU.new()
	p.closed.connect(func():
		p.queue_free()
		_causerie = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	p.ouvrir_feuille(_rencontre.s, _rencontre.j, _rencontre.dom, _rencontre.ext)
	_causerie = p


## Un joueur sur la pelouse, aux couleurs de son club, au banc d'abord.
func _acteur(id: String, equipe: int, couleurs: Array) -> Node3D:
	if _acteurs.has(id):
		return _acteurs[id]
	var j: Dictionary = _joueurs[id]
	var c := CRITTER.new()
	c.randomize_look(Hasard.graine(id))
	c.look["top"] = "pull"
	c.look["top_color"] = str(couleurs[0])
	c.look["legs"] = "pantalon"
	c.look["legs_color"] = str(couleurs[1]) if couleurs.size() > 1 else "#ffffff"
	c.look["shoes"] = "#1a1a1a"
	c.look.erase("hat")
	c.look.erase("prop_r")
	c.look.erase("apron")
	if j.poste == "G":
		c.look["top_color"] = "#2a8f3a" if str(couleurs[0]).to_lower() != "#0f6b3f" else "#d98f2a"
	c.scale = Vector3.ONE * PEOPLE_SCALE
	c.walk_speed = 1.0
	c.run_speed = 1.6
	c.position = Vector3((-7.0 if equipe == 0 else 7.0), 0, -P / 2.0 - 1.6)
	add_child(c)
	_acteurs[id] = c
	_cibles[id] = c.position
	return c


## Où chaque joueur doit être : sa case de formation, l'équipe glissant vers le ballon. L'équipe à domicile
## défend le but ouest (x < 0) et attaque vers l'est.
func _placer(dun_coup := false) -> void:
	var etat: Dictionary = _etat if not _etat.is_empty() else _entrainement()
	for i in etat.equipes.size():
		var eq: Dictionary = etat.equipes[i]
		var cases: Array = FootMatch.FORMATIONS.get(eq.formation, FootMatch.FORMATIONS["4-4-2"])
		var sens := 1.0 if i == 0 else -1.0
		var glisse := clampf(_cible_ballon.x * 0.35, -6.0, 6.0)
		var glisse_z := clampf(_cible_ballon.z * 0.25, -3.0, 3.0)
		var prises: Array = []
		for e in eq.onze:
			# Sa case : celle de son poste encore libre, sinon la première libre.
			var cs: Array = []
			for k in cases.size():
				if not (k in prises) and cases[k][0] == e.poste:
					cs = cases[k]
					prises.append(k)
					break
			if cs.is_empty():
				for k in cases.size():
					if not (k in prises):
						cs = cases[k]
						prises.append(k)
						break
			if cs.is_empty():
				cs = cases[-1]
			var along: float = (50.0 - cs[3]) / 50.0 * (L / 2.0 * 0.88)
			var across: float = (cs[2] - 50.0) / 50.0 * (P / 2.0 * 0.85)
			var cible := Vector3(sens * along, 0, sens * across)
			if e.poste != "G":
				cible.x += glisse
				cible.z += glisse_z
				cible.x = clampf(cible.x, -L / 2.0 + 0.5, L / 2.0 - 0.5)
				cible.z = clampf(cible.z, -P / 2.0 + 0.5, P / 2.0 - 0.5)
			else:
				# Le gardien se décale vers le ballon sur sa ligne.
				cible.z = clampf(_cible_ballon.z * 0.3, -2.5, 2.5)
			_cibles[e.id] = cible
			if dun_coup and _acteurs.has(e.id):
				_acteurs[e.id].position = cible
	if dun_coup:
		_ballon.position = Vector3(_cible_ballon.x, 0.22, _cible_ballon.z)


## Deux lignes qui trottinent autour du rond central, avant la saison ; une seule quand le club n'a pas de match.
func _entrainement() -> Dictionary:
	var faux := {"equipes": []}
	if _rencontre.is_empty():
		if not _joueurs.is_empty():
			var onze: Array = []
			for id in FootMatch.compo_auto(_joueurs.keys(), _joueurs, "4-4-2"):
				if id != null:
					onze.append({"id": id, "poste": _joueurs[id].poste})
			faux.equipes.append({"onze": onze, "formation": "4-4-2"})
		return faux
	var direct: Dictionary = Football.rencontre_en_direct(_rencontre.s, _rencontre.j, _rencontre.dom, _rencontre.ext)
	for i in 2:
		faux.equipes.append({"onze": direct.etat.equipes[i].onze, "formation": direct.etat.equipes[i].formation})
	return faux


func _process(delta: float) -> void:
	_credits.text = "%s crédits" % Game.fmt(Game.credits)
	var t: Node = player.focus_target if player else null
	_prompt.visible = t != null
	if t != null:
		_prompt.text = str(t.get_meta("prompt", ""))
	# Le match suit l'heure réelle ; quand il finit, le tableau garde le score.
	if not _etat.is_empty() and not _etat.fini:
		_synchroniser()
		if _etat.fini:
			_terminer()
	if _etat.is_empty():
		# L'entraînement : le ballon se promène, les joueurs le suivent.
		_chrono += delta
		if _chrono > 2.5:
			_chrono = 0.0
			_cible_ballon = Vector3(randf_range(-L / 3.0, L / 3.0), 0, randf_range(-P / 3.0, P / 3.0))
			_placer()
	_animer(minf(delta, 0.1))


## Une image d'animation : la scène en cours, puis le ballon et les joueurs qui courent vers leur cible.
## Le pas est plafonné (un dixième de seconde) : une image lente ne téléporte personne.
func _animer(delta: float) -> void:
	_jouer_scenes(delta)
	var b := _ballon.position
	var vers := Vector3(_cible_ballon.x, 0.22, _cible_ballon.z)
	_ballon.position = b.move_toward(vers, delta * _vitesse_ballon)
	var reste := Vector2(_ballon.position.x - vers.x, _ballon.position.z - vers.z).length()
	if _vol > 0.0 and reste > 0.2:
		# Un ballon levé : une cloche entre son départ et sa cible.
		var total := maxf(Vector2(_depart_ballon.x - vers.x, _depart_ballon.z - vers.z).length(), 0.01)
		_ballon.position.y = 0.22 + _vol * sin(PI * clampf(1.0 - reste / total, 0.0, 1.0))
	else:
		_ballon.position.y = 0.22 + maxf(0.0, sin(Time.get_ticks_msec() / 90.0) * 0.08) * (1.0 if reste > 0.5 else 0.0)
	for id in _acteurs:
		var c: Node3D = _acteurs[id]
		var cible: Vector3 = _cibles.get(id, c.position)
		if c.position.distance_to(cible) > 0.15:
			var d := (cible - c.position)
			d.y = 0.0
			c.position = c.position.move_toward(cible, delta * COURSE)
			c.rotation.y = lerp_angle(c.rotation.y, atan2(d.x, d.z), 0.15)
		elif not _etat.is_empty():
			var vb := _ballon.position - c.position
			c.rotation.y = lerp_angle(c.rotation.y, atan2(vb.x, vb.z), 0.05)


## Une minute de match : les événements font bouger le ballon, parler le commentateur, tenir le tableau.
func _minute() -> void:
	var avant: Array = [_etat.stats[0].possession, _etat.stats[1].possession]
	var evenements: Array = FootMatch.avancer(_etat, _joueurs, _hasard)
	var qui: int = 0 if _etat.stats[0].possession > avant[0] else 1
	_horloge.text = "Journée %d  ·  %s" % [_rencontre.j, FootMatch.libelle_minute(_etat)]
	var fait := ""
	for ev in evenements:
		if ev.type in ["but", "carton", "remplacement", "penalty"]:
			fait = str(ev.texte)
	if _etat.pause == "mi-temps":
		_afficher_bandeau("%s  ·  Mi-temps" % _score_bandeau().split("  ·  ")[0])
	elif _etat.fini:
		# Au coup de sifflet final, le tableau affiche le score sans attendre la dernière scène.
		_score.text = "%s  %d - %d  %s" % [Football.clubs[_rencontre.dom].court, _etat.score[0], _etat.score[1], Football.clubs[_rencontre.ext].court]
		_afficher_bandeau(_score_bandeau(), "Terminé, la feuille au tableau.")
		_effacer_bandeau(8.0)
	elif fait != "" or _bandeau == null or not _bandeau.visible:
		_afficher_bandeau(_score_bandeau(), fait)
	else:
		_bandeau_score.text = _score_bandeau()
	var sens := 1.0 if qui == 0 else -1.0
	# La minute précédente est finie, même si sa dernière scène ne l'était pas.
	_scenes.clear()
	# Sans événement, le ballon circule dans le camp de celui qui l'a : deux passes, puis on temporise.
	if evenements.is_empty() or evenements.all(func(e): return e.type in ["ambiance", "info"]):
		var eq: Dictionary = _etat.equipes[qui]
		for k in 2:
			var e = eq.onze[randi() % eq.onze.size()] if not eq.onze.is_empty() else null
			_scene(Vector3(sens * randf_range(-4.0, 10.0), 0, randf_range(-P / 2.0 + 3.0, P / 2.0 - 3.0)), 3.0, e.id if e != null else null, 12.0)
	for ev in evenements:
		_evenement(ev)
	_placer()
	if _etat.pause == "mi-temps":
		_scenes.clear()
		_placer(true)


## Une scène de plus : le ballon va là, à cette vitesse, levé ou non, et ce joueur le rejoint.
func _scene(ballon: Vector3, duree: float, porteur = null, vitesse := 14.0, vol := 0.0, action := Callable()) -> void:
	_scenes.append({"ballon": ballon, "duree": duree, "porteur": porteur, "vitesse": vitesse, "vol": vol, "action": action, "lancee": false})


## Joue la scène en cours : au départ, le ballon reçoit sa cible et le porteur court la rejoindre ; au bout
## de sa durée, la suivante.
func _jouer_scenes(delta: float) -> void:
	if _scenes.is_empty():
		return
	var sc: Dictionary = _scenes[0]
	if not sc.lancee:
		sc.lancee = true
		_scene_t = 0.0
		_depart_ballon = _ballon.position
		_cible_ballon = sc.ballon
		_vitesse_ballon = sc.vitesse
		_vol = sc.vol
		_placer()
		if sc.porteur != null and _acteurs.has(sc.porteur):
			# Le porteur se poste un pas derrière le ballon, du côté de son but.
			var recul := -1.0 if _cibles.get(sc.porteur, Vector3.ZERO).x < sc.ballon.x else 1.0
			_cibles[sc.porteur] = sc.ballon + Vector3(recul * 0.6, 0, 0)
		if sc.action.is_valid():
			sc.action.call()
	_scene_t += delta
	if _scene_t >= sc.duree:
		_scenes.pop_front()
		# La suivante part tout de suite, sans image perdue.
		_jouer_scenes(0.0)


func _evenement(ev: Dictionary) -> void:
	var i: int = int(ev.equipe)
	var sens := 1.0 if i == 0 else -1.0
	# Le couloir de l'action : pour qui attaque vers l'est, la gauche est au nord (z < 0) ; l'inverse à l'ouest.
	var cote: float = _cote(str(ev.get("couloir", "centre"))) * sens
	var tireur = ev.get("joueur", null)
	var but := Vector3(sens * (L / 2.0), 0, 0)
	match str(ev.type):
		"occasion":
			match str(ev.get("phase", "jeu")):
				"corner":
					# Le tireur va au poteau de corner, lève le ballon, la tête le reprend aux six mètres.
					var coin := Vector3(sens * (L / 2.0 - 0.3), 0, (P / 2.0 - 0.3) * (cote if cote != 0.0 else 1.0))
					_scene(coin, 2.2, ev.get("tireur", null), 16.0)
					_scene(Vector3(sens * (L / 2.0 - 2.2), 0, randf_range(-2.5, 2.5)), 1.0, tireur, 18.0, 2.2)
				"coupFranc":
					# Le ballon posé à vingt mètres, le tireur prend son élan.
					_scene(Vector3(sens * (L / 2.0 - 8.0), 0, cote * 4.0 + randf_range(-1.0, 1.0)), 2.6, tireur, 16.0)
				"penalty":
					_scene(Vector3(sens * (L / 2.0 - 3.8), 0, 0), 2.6, tireur, 16.0)
				_:
					var passeur = ev.get("passeur", null)
					if ev.get("centre", false) and cote != 0.0:
						# L'ailier déborde jusqu'à la ligne et centre ; le buteur attend au point de penalty.
						_scene(Vector3(sens * (L / 2.0 - 10.0), 0, cote * 7.0), 1.6, passeur, 16.0)
						_scene(Vector3(sens * (L / 2.0 - 2.5), 0, cote * 8.5), 1.6, passeur, 16.0)
						_scene(Vector3(sens * (L / 2.0 - 4.0), 0, randf_range(-1.5, 1.5)), 0.9, tireur, 22.0, 1.4)
					else:
						# La construction dans le couloir, puis la passe au tireur à l'entrée de la surface.
						_scene(Vector3(sens * (L / 2.0 - 13.0), 0, cote * 6.0 + randf_range(-1.5, 1.5)), 1.8, passeur if passeur != null else tireur, 16.0)
						_scene(Vector3(sens * (L / 2.0 - 5.5), 0, cote * 5.0 + randf_range(-2.0, 2.0)), 1.2, tireur, 20.0)
		"but":
			_scene(but + Vector3(sens * 0.7, 0, randf_range(-1.2, 1.2)), 1.2, null, 32.0, 0.5)
			_scene(Vector3.ZERO, 4.0, null, 10.0, 0.0, _marquer.bind(i, ev))
		"arret":
			var g = _gardien(1 - i)
			_scene(but + Vector3(-sens * 0.5, 0, randf_range(-1.0, 1.0)), 0.9, g, 32.0, 0.4, _geste.bind(g, "jump"))
			_scene(Vector3(sens * (L / 2.0 - 9.0), 0, randf_range(-6.0, 6.0)), 2.0, null, 18.0, 1.8)
		"rate":
			_scene(but + Vector3(sens * 2.5, 0, (3.0 + randf() * 2.0) * (1.0 if randf() < 0.5 else -1.0)), 1.2, null, 30.0, 1.6, _geste.bind(tireur, "shrug"))
			_scene(but + Vector3(-sens * 2.0, 0, randf_range(-2.0, 2.0)), 2.2, _gardien(1 - i), 10.0)
		"poteau":
			var z := 1.7 * (1.0 if randf() < 0.5 else -1.0)
			_scene(but + Vector3(0, 0, z), 0.7, null, 32.0, 0.3, _geste.bind(tireur, "stomp"))
			_scene(but + Vector3(-sens * 4.0, 0, z * 1.5), 1.2, null, 18.0)
		"jaune", "rouge":
			if ev.type == "rouge" and _acteurs.has(tireur):
				_cibles[tireur] = Vector3(sens * 7.0, 0, -P / 2.0 - 1.6)
			_geste(tireur, "shrug" if ev.type == "jaune" else "sulk")
		"blessure":
			_geste(tireur, "sulk")
		"remplacement":
			var club: Dictionary = Football.clubs[_rencontre.dom if i == 0 else _rencontre.ext]
			_acteur(ev.entrant, i, club.couleurs)
			_cibles[ev.sortant] = Vector3((-7.0 if i == 0 else 7.0) + randf_range(-1.5, 1.5), 0, -P / 2.0 - 1.6)
		"reprise", "coupEnvoi":
			_scene(Vector3.ZERO, 1.5, null, 14.0)
	if ev.type != "info" or _etat.minute in [45, 90]:
		_dire(str(ev.texte))


## Le gardien d'une équipe sur la pelouse (son id), s'il y en a un.
func _gardien(i: int) -> Variant:
	for e in _etat.equipes[i].onze:
		if e.poste == "G":
			return e.id
	return null


## Un geste d'un joueur, s'il est sur la pelouse.
func _geste(id, nom: String) -> void:
	if id != null and _acteurs.has(id):
		_acteurs[id].gesture(nom)


## Le côté d'un couloir pour une équipe qui attaque vers l'est : -1 à gauche (nord), +1 à droite, 0 au centre.
static func _cote(couloir: String) -> float:
	return -1.0 if couloir == "gauche" else (1.0 if couloir == "droite" else 0.0)


## Le but : le tableau change, le buteur lève les bras, la tribune se lève.
func _marquer(i: int, ev: Dictionary) -> void:
	var cd: Dictionary = Football.clubs[_rencontre.dom]
	var ce: Dictionary = Football.clubs[_rencontre.ext]
	_score.text = "%s  %d - %d  %s" % [cd.court, _etat.score[0], _etat.score[1], ce.court]
	if _acteurs.has(ev.get("joueur", "")):
		_acteurs[ev.joueur].cheer(2.0)
	var chez_nous: bool = _club != "" and (_rencontre.dom if i == 0 else _rencontre.ext) == _club
	for s in _supporters:
		if chez_nous:
			s.cheer(2.4)
		elif randf() < 0.2:
			s.gesture("facepalm")
	Sfx.result(1, 50 if chez_nous else 0)


## Le bandeau du direct : l'ardoise en haut au centre, le score et la minute en grand, le dernier fait dessous.
func _bandeau_du_direct() -> void:
	_bandeau = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.17, 0.15, 0.9)
	st.border_color = Color(0.55, 0.42, 0.25)
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
	v.add_theme_constant_override("separation", 2)
	_bandeau.add_child(v)
	_bandeau_score = Label.new()
	_bandeau_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bandeau_score.add_theme_font_override("font", Polices.gras())
	_bandeau_score.add_theme_font_size_override("font_size", 26)
	_bandeau_score.add_theme_color_override("font_color", Color(0.95, 0.93, 0.85))
	v.add_child(_bandeau_score)
	_bandeau_fait = Label.new()
	_bandeau_fait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bandeau_fait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bandeau_fait.custom_minimum_size.x = 420
	_bandeau_fait.add_theme_font_override("font", _serif)
	_bandeau_fait.add_theme_font_size_override("font_size", 15)
	_bandeau_fait.add_theme_color_override("font_color", Color(0.96, 0.8, 0.45))
	v.add_child(_bandeau_fait)
	_speech.get_parent().add_child(_bandeau)


## Ce que dit le bandeau : le score et la minute, et le dernier fait s'il y en a un (deux lignes au plus).
func _afficher_bandeau(score: String, fait := "") -> void:
	if _bandeau == null:
		return
	if _bandeau_tween:
		_bandeau_tween.kill()
	_bandeau.modulate.a = 1.0
	_bandeau.visible = true
	_bandeau_score.text = score
	_bandeau_fait.text = fait
	_bandeau_fait.visible = fait != ""


## Le bandeau s'efface au bout d'un moment (le coup de sifflet final).
func _effacer_bandeau(apres: float) -> void:
	if _bandeau == null or not _bandeau.visible:
		return
	if _bandeau_tween:
		_bandeau_tween.kill()
	_bandeau_tween = create_tween()
	_bandeau_tween.tween_interval(apres)
	_bandeau_tween.tween_property(_bandeau, "modulate:a", 0.0, 1.0)
	_bandeau_tween.tween_callback(func(): _bandeau.visible = false)


## Le score du bandeau : « ESM 1 – 0 LVV · 63e ».
func _score_bandeau() -> String:
	return "%s  %d – %d  %s  ·  %s" % [Football.clubs[_rencontre.dom].court, _etat.score[0], _etat.score[1], Football.clubs[_rencontre.ext].court, FootMatch.libelle_minute(_etat)]


func _dire(texte: String) -> void:
	_speech.text = texte
	_show_speech()


func _note(texte: String) -> void:
	_dire(texte)


func _show_speech() -> void:
	_speech.modulate.a = 1.0
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = create_tween()
	_speech_tween.tween_interval(3.0 + _speech.text.length() * 0.03)
	_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.8)


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			Game.return_point = _lot()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var c: Commune = Communes.commune(commune)
			Chargement.changer(str(c.data.scene) if c else "res://scenes/main.tscn")
		"president":
			open_causerie()
		"locaux":
			_entrer_siege()
		"bureau":
			open_locaux()
		"sortir_siege":
			_sortir_siege()
		"panneau":
			open_panneau()
		"feuille":
			open_feuille()
		"buvette":
			_dire(["« Un café, un. C'est la femme du président qui tient la buvette, et elle ne fait pas crédit. »",
				"« Le chocolat chaud, c'est pour les moins de douze ans et les gardiens de but. »",
				"« %s dit que %s montera. Il le dit depuis 1987. »" % [_nom_president(), _nom_club()]].pick_random())


# --- Capture --------------------------------------------------------------------------------------

## --rejouer=but (ou arret, rate, poteau, corner, coupFranc, penalty) rejoue en scènes, pour la capture, la
## dernière minute déjà jouée où c'est arrivé ; --attendre=s prend la capture au bout de s secondes (6 sans).
func _maybe_capture() -> void:
	var path := ""
	var attente := 6.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
			if v.size() > 3:
				player.camera.rotation.x = deg_to_rad(v[3])
		elif arg.begins_with("--minute=") or arg.begins_with("--journee=") or arg == "--mercato" or arg.begins_with("--commune="):
			pass
		elif arg.begins_with("--actionnaires="):
			# Des obligations du club pour la capture : --actionnaires=vous:3+1,Lucien:5 (les rangs, avant --open=causerie).
			if _club != "":
				Football.forcer_porteurs(arg.trim_prefix("--actionnaires="), _club)
		elif arg == "--open=causerie":
			open_causerie()
		elif arg == "--open=mercato":
			open_mercato()
		elif arg == "--open=locaux":
			open_locaux()
		elif arg == "--open=obligations":
			open_obligations()
		elif arg.begins_with("--rejouer="):
			_rejouer(arg.trim_prefix("--rejouer="))
		elif arg.begins_with("--attendre="):
			attente = float(arg.trim_prefix("--attendre="))
		else:
			_capture_setup(arg)
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_chrono = -100.0
	await get_tree().create_timer(attente).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## Rejoue en scènes la dernière minute où un événement de ce type (ou une occasion de cette phase) est
## arrivé : rien ne change au match, seule la pelouse le remontre. « but@3.4 » avance aussitôt les scènes
## de 3,4 secondes, pour qu'une capture les prenne en plein vol quel que soit le rythme des images.
func _rejouer(quoi: String) -> void:
	if _etat.is_empty() and _resultat.is_empty():
		return
	var avance := 0.0
	if "@" in quoi:
		avance = float(quoi.get_slice("@", 1))
		quoi = quoi.get_slice("@", 0)
	var etat: Dictionary = _etat if not _etat.is_empty() else _resultat
	var minute := ""
	for k in range(etat.evenements.size() - 1, -1, -1):
		var ev: Dictionary = etat.evenements[k]
		if ev.type == quoi or (ev.type == "occasion" and ev.get("phase", "") == quoi):
			minute = ev.minute
			break
	if minute == "":
		return
	_scenes.clear()
	for ev in etat.evenements:
		if ev.minute == minute:
			_evenement(ev)
	for k in int(avance * 30.0):
		_animer(1.0 / 30.0)


## L'horloge du football, posée avant que la scène ne choisisse son match : --journee=n met l'horloge à
## la minute --minute=m (0 sans elle) de la journée n, mi-temps comprise.
func _init() -> void:
	var journee := 0
	var minute := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			Football.dossier = ""
		elif arg.begins_with("--journee="):
			journee = int(arg.trim_prefix("--journee="))
		elif arg.begins_with("--minute="):
			minute = int(arg.trim_prefix("--minute="))
		elif arg == "--mercato":
			# Le milieu de la semaine du mercato de la saison 1.
			journee = -1
	if journee > 0:
		var t: int = Football.coup_envoi(1, journee) + minute * 60 + (MI_TEMPS if minute > 45 else 0)
		Football.regler_horloge(func(): return t)
	elif journee < 0:
		var tm: int = Football.coup_envoi(1, 1) - 3 * 86400
		Football.regler_horloge(func(): return tm)
