class_name SalleJeu
extends "res://scripts/village/salle.gd"
## La salle de jeu d'une commune, prêtée par le socle : la structure « salle_jeu » du manifeste
## (docs/COMMUNE.md, « Les structures »). La commune déclare son tenancier, ses jeux, son décor et ses
## répliques ; le socle construit la pièce, pose une table ou une machine par jeu, et fait tourner les
## jeux de Smarves (les mêmes panneaux qu'au casino, la même bourse, le même total gagné). La commune
## ouvre sa salle depuis sa scène par SalleJeu.ouvrir("<commune>", "<id de la structure>"). Avec
## « guichet » (socle 1.2), le banquier de la commune tient un bureau près de la porte : le prêt pour jouer,
## au nom de la banque du manifeste (scripts/loan_panel.gd, de_commune).
## Avec « modele » (socle 1.22), la salle se pose sur un décor de la bibliothèque ou de la commune, branché par
## ses ancres (Ancres.SALLE_JEU) : le socle n'y bâtit plus sa pièce.
## Avec « paris » (socle 1.26), le tenancier prend aussi les paris du championnat de la Vienne, comme Josiane au
## café de Smarves : le même comptoir (FootParis), les mêmes cotes, les mêmes tickets (autoload Paris).
## Capture : godot --path . res://scenes/salle_jeu.tscn -- --commune=<id> --salle=<id> --capture=sortie.png

## Les jeux du socle, par nom de manifeste : le panneau, ce que dit l'invite, l'enseigne de la table.
const JEUX := {
	"machine": {"panneau": "res://scripts/slot_machine.gd", "invite": "jouer à la machine", "titre": "La machine à sous"},
	"loto": {"panneau": "res://scripts/loto_panel.gd", "invite": "prendre un carton de loto", "titre": "Le loto"},
	"blackjack": {"panneau": "res://scripts/blackjack_panel.gd", "invite": "s'asseoir au blackjack", "titre": "Blackjack"},
	"roulette": {"panneau": "res://scripts/roulette_panel.gd", "invite": "miser à la roulette", "titre": "Roulette"},
	"craps": {"panneau": "res://scripts/craps_panel.gd", "invite": "lancer les dés au craps", "titre": "Craps"},
	"baccara": {"panneau": "res://scripts/baccara_panel.gd", "invite": "s'asseoir au baccara", "titre": "Baccara"},
	"poker": {"panneau": "res://scripts/poker_panel.gd", "invite": "s'asseoir à la table de poker", "titre": "Poker"},
	"des": {"panneau": "res://scripts/dice_panel.gd", "invite": "jouer aux dés", "titre": "Les dés"},
	"roue": {"panneau": "res://scripts/wheel_panel.gd", "invite": "faire tourner la roue", "titre": "La roue de la fortune"},
	"courses": {"panneau": "res://scripts/race_panel.gd", "invite": "parier sur les courses", "titre": "Les courses"},
}
## Les décors : la pièce et ses matières. « cafe » : carrelage et papier peint ; « salle » : parquet et
## murs clairs, une salle des fêtes ; « cave » : dalles et pierre, une arrière-salle.
const DECORS := ["cafe", "salle", "cave"]
## La grille des tables : trois par rang, une case de 4,2 sur 4 chacune (la table du casino et la place
## du joueur devant elle).
const COLONNES := 3
const CASE := Vector2(4.2, 4.0)
const REPLIQUES := ["« Installez-vous. Ici, la chance n'a pas de préférence. »",
	"« On mise, on perd, on remise. C'est ce qui fait tourner la maison. »",
	"« Les gens d'ici disent que la table porte bonheur le jeudi. On est jeudi tous les jours. »"]

## Ce que la prochaine salle doit ouvrir (posé par ouvrir(), lu au _ready).
static var _prochaine: Array = []

## La commune et sa structure (l'entrée du registre) ; le lieu du manifeste qui la garde, s'il y en a un.
var commune := ""
var structure: Dictionary = {}
var _jeu_ouvert := ""
## Les tables 3D de la salle, par jeu (la première de chaque jeu) ; celle où l'on vient de demander à
## jouer, et celle où le joueur est assis.
var _tables3d := {}
var _table_choisie: Node3D
## La table où l'on est assis. Un nom qu'une salle de commune n'emploie pas : celles qui étendent
## SalleJeu ont leurs propres membres (le salon de Saint-Savin a déjà son « _assis »), et deux membres
## du même nom empêchent leur script de compiler.
var _table_assise: Node3D


## Ouvre la salle de jeu « id » de la commune. Rend false sans rien faire si la structure n'existe pas,
## ou si le lieu du manifeste qui porte le même id n'est pas encore ouvert (son seuil de gagné au jeu).
static func ouvrir(id_commune: String, id: String) -> bool:
	if not ouverte(id_commune, id):
		return false
	_prochaine = [id_commune, id]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Chargement.lieu("res://scenes/salle_jeu.tscn")
	return true


## La salle existe et son seuil est atteint (sans lieu du même id dans le manifeste, elle est ouverte).
static func ouverte(id_commune: String, id: String) -> bool:
	if _entree(id_commune, id).is_empty():
		return false
	return Game.won >= seuil(id_commune, id)


## Le seuil de gagné au jeu qui ouvre la salle : celui du lieu de même id, sinon 0.
static func seuil(id_commune: String, id: String) -> int:
	var c: Commune = Communes.commune(id_commune)
	if c == null:
		return 0
	for l in c.lieux():
		if str(l.get("id", "")) == id:
			return int(l.get("seuil", 0))
	return 0


static func _entree(id_commune: String, id: String) -> Dictionary:
	for e in Registre.de_commune(id_commune):
		if e.type == "salle_jeu" and e.id == id:
			return e
	return {}


func _ready() -> void:
	shop = "salle_jeu"
	if _prochaine.size() == 2:
		commune = _prochaine[0]
		structure = _entree(_prochaine[0], _prochaine[1])
		_prochaine = []
	var id := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--commune="):
			commune = arg.trim_prefix("--commune=")
		elif arg.begins_with("--salle="):
			id = arg.trim_prefix("--salle=")
	if id != "":
		# En capture, une commune en clair sous communes/ (le SDK, un clone) se greffe d'elle-même.
		if Communes.commune(commune) == null and FileAccess.file_exists("res://communes/%s/commune.json" % commune):
			Communes.charger_dossier("res://communes/" + commune)
		structure = _entree(commune, id)
	var champs: Dictionary = structure.get("champs", {})
	var jeux: Array = champs.get("jeux", ["machine"])
	var tenancier := str(champs.get("tenancier", "Le tenancier"))
	_salle = {"name": str(structure.get("nom", "La salle de jeu")), "host": tenancier,
		"jeu": "E : jouer", "sortie": "E : sortir",
		"lines": champs.get("repliques", REPLIQUES) if not (champs.get("repliques", []) as Array).is_empty() else REPLIQUES}
	_serif = Polices.texte()
	var decor := str(champs.get("decor", "cafe"))
	# Les tables en rangs de trois au plus, chacune dans une case de 3,4 sur 3 ; le comptoir au fond.
	var colonnes := clampi(jeux.size(), 1, COLONNES)
	var rangs := ceili(jeux.size() / float(COLONNES))
	W = maxf(8.0, colonnes * CASE.x + 1.6)
	D = rangs * CASE.y + 4.6
	H = 3.6 if decor == "salle" else 3.1
	if "roue" in jeux:
		# La grande roue du casino monte à trois mètres.
		H = maxf(H, 4.2)
	var modele := _charger_decor(str(champs.get("modele", "")), "salle_jeu", "Salle de jeu")
	if modele:
		_brancher_decor(modele, jeux, tenancier, champs)
	else:
		_batir(jeux, tenancier, champs, decor)
	for a in find_children("*", "Area3D", true, false):
		if a.get_meta("interact", "") == "exit":
			a.set_meta("prompt", _salle.sortie)
	_build_ui()
	# Les panneaux s'habillent comme au casino de Smarves.
	_panel_layer.get_parent().theme = Tables.theme()
	player = PLAYER.new()
	player.position = Vector3(0, 0, D / 2.0 - 1.2)
	var arrivee := Ancres.trouver(modele, "Arrivee") if modele else null
	if arrivee:
		player.position = arrivee.global_position
		player.rotation.y = arrivee.global_rotation.y + PI
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("casino")
	if champs.get("paris", false):
		_annoncer_paris.call_deferred()
	_capture_commune()


## La pièce du socle, quand la salle ne nomme pas de décor : les murs de son décor, le comptoir, les tables en
## rangs de trois, le guichet, l'enseigne et la porte.
func _batir(jeux: Array, tenancier: String, champs: Dictionary, decor: String) -> void:
	_environment()
	match decor:
		"salle":
			_room(_wood_floor(Color(0.62, 0.45, 0.28)), _std(Color(0.8, 0.82, 0.74), 0.85), Color(0.95, 0.94, 0.9), Color(0.5, 0.38, 0.28))
		"cave":
			_room(_flagstones(), _stone(), Color(0.5, 0.42, 0.34))
		_:
			_room(_checker(Color(0.86, 0.82, 0.74), Color(0.3, 0.2, 0.14)), _wallpaper(Color(0.62, 0.48, 0.32), Color(0.68, 0.54, 0.36)), Color(0.9, 0.84, 0.7), Color(0.3, 0.17, 0.1))
	_comptoir(tenancier, int(champs.get("graine", 0)))
	if champs.get("paris", false):
		# Sur le zinc, à droite du tenancier.
		_carnet_paris(Transform3D(Basis(), Vector3(0.9, 1.1, -D / 2.0 + 1.82)))
	_tables(jeux)
	if champs.get("guichet", false):
		_guichet()
	var enseigne := str(champs.get("enseigne", _salle.name))
	_label3d(enseigne, Vector3(0, H - 0.45, -D / 2.0 + 0.12), 80, Color(0.95, 0.85, 0.6)).shaded = false
	_bulb(Vector3(-W / 4.0, H - 0.7, 0.4), Color(0.85, 0.55, 0.3))
	_bulb(Vector3(W / 4.0, H - 0.7, 0.4), Color(0.85, 0.55, 0.3))
	_door()


## Le comptoir au fond et le tenancier derrière, un habitant tiré de la graine de la structure.
func _comptoir(tenancier: String, graine: int) -> void:
	var bois := _std(Color(0.3, 0.16, 0.08), 0.45)
	var bz := -D / 2.0 + 1.7
	_box(Vector3(3.6, 1.05, 0.6), Vector3(0, 0.525, bz), bois, true)
	_box(Vector3(3.7, 0.05, 0.72), Vector3(0, 1.07, bz), _std(Color(0.72, 0.74, 0.76), 0.22, 0.85))
	_keeper = Node3D.new()
	_keeper.position = Vector3(0, 0, -D / 2.0 + 0.8)
	add_child(_keeper)
	var c := CRITTER.new()
	c.randomize_look(graine)
	c.idle_anim = "bar"
	c.scale = Vector3.ONE * PEOPLE_SCALE
	_keeper.add_child(c)
	_interactive(_keeper, "keeper", "E : parler à %s" % tenancier, Vector3(1.2, 2.2, 1.6), Vector3(0, 1.1, 0.9))
	_lamp(Vector3(0, 1.6, -D / 2.0 + 0.6), Color(1.0, 0.7, 0.4), 0.9, 4.0)


## Le bureau du banquier de la commune, contre le mur de gauche près de la porte.
func _guichet() -> void:
	var c: Commune = Communes.commune(commune)
	var b: Dictionary = c.banque() if c else {}
	var p := Vector3(-W / 2.0 + 1.1, 0, D / 2.0 - 2.2)
	_box(Vector3(0.8, 0.78, 1.5), p + Vector3(0.45, 0.39, 0), _std(Color(0.36, 0.24, 0.14), 0.5), true)
	var banquier := Node3D.new()
	banquier.position = p + Vector3(-0.2, 0, 0)
	banquier.rotation.y = PI / 2.0
	add_child(banquier)
	var f := CRITTER.new()
	f.randomize_look(hash(str(b.get("banquier", "banquier"))))
	f.idle_anim = "stand_table"
	f.scale = Vector3.ONE * PEOPLE_SCALE
	banquier.add_child(f)
	_label3d(str(b.get("nom", "La banque")), p + Vector3(0.45, 1.9, 0), 36, Color(0.7, 0.82, 1.0)).shaded = false
	_lamp(p + Vector3(0.4, 1.7, 0), Color(0.9, 0.95, 1.0), 0.8, 3.0)
	_interactive(banquier, "guichet", "E : voir %s" % str(b.get("banquier", "le banquier")), Vector3(1.6, 2.0, 1.8), Vector3(0.6, 1.0, 0))


## Une table ou une machine par jeu, en rangs de trois depuis le comptoir, chacune sous sa lampe : les
## tables 3D du casino de Smarves (Tables, scripts/socle/tables.gd), la place du joueur face au comptoir.
## Le loto et les courses, qui n'ont pas de table au casino, gardent une table de café.
func _tables(jeux: Array) -> void:
	var n := jeux.size()
	for i in n:
		var rang := i / COLONNES
		var dans_le_rang := mini(n - rang * COLONNES, COLONNES)
		var x := ((i % COLONNES) - (dans_le_rang - 1) / 2.0) * CASE.x
		_poser_table(str(jeux[i]), Transform3D(Basis(), Vector3(x, 0, -D / 2.0 + 3.6 + rang * CASE.y)), i)


## Une table ou une machine, dans le repère « t » (au sol, au centre de la table, la place du joueur vers +Z),
## sous sa lampe et son enseigne, avec sa zone d'interaction : la grille de la salle du socle, ou l'ancre
## TableN d'un décor (socle 1.22).
func _poser_table(jeu: String, t: Transform3D, i: int) -> void:
	if Tables.fiche(jeu).is_empty():
		return
	var feutre := _std(Color(0.05, 0.3, 0.16), 0.95)
	var bois := _std(Color(0.28, 0.17, 0.09), 0.6)
	var cap := rad_to_deg(t.basis.get_euler().y)
	# Un quart de tour échange la largeur et la profondeur des collisions, qui restent alignées sur la salle.
	var travers := absf(sin(t.basis.get_euler().y)) > 0.5
	var spot := Node3D.new()
	spot.transform = t
	add_child(spot)
	var e := Vector2(1.7, 0.9)
	var table := Tables.table(jeu)
	if table:
		# La lampe de la salle éclaire la table (plus bas) : celle de la table, un projecteur, ne passe pas
		# partout (le rendu web et mobile en compte peu par objet).
		e = Tables.emprise(jeu)
		table.with_lamp = false
		spot.add_child(table)
		spot.set_meta("table3d", table)
		_tables3d[jeu] = _tables3d.get(jeu, table)
		var boite := Vector3(e.x, 3.0 if jeu == "roue" else 1.0, e.y)
		_solid_box_at(Vector3(boite.z, boite.y, boite.x) if travers else boite, t * Vector3(0, 1.5 if jeu == "roue" else 0.5, 0))
		if jeu in ["blackjack", "roulette", "baccara", "des", "poker"]:
			# Pas de chaise au milieu : c'est la place du joueur, d'où la caméra regarde le tapis.
			for dx in [-0.9, 0.9]:
				_place(KK + "furniture/chair_A_wood.gltf", t * Vector3(dx, 0, e.y / 2.0 + 0.45), 0.8, 180.0 + cap)
		if jeu != "machine" and jeu != "roue":
			_regular(t * Vector3(0.55, 0, -e.y / 2.0 - 0.45), cap, 60 + i)
	else:
		_box(Vector3(1.9, 0.06, 1.1), Vector3(0, 0.78, 0), feutre, false, spot)
		_box(Vector3(2.0, 0.06, 1.2), Vector3(0, 0.73, 0), bois, false, spot)
		_box(Vector3(1.7, 0.7, 0.9), Vector3(0, 0.35, 0), bois, false, spot)
		_solid_box_at(Vector3(0.9, 0.7, 1.7) if travers else Vector3(1.7, 0.7, 0.9), t * Vector3(0, 0.35, 0))
		for dx in [-0.5, 0.5]:
			_place(KK + "furniture/chair_A_wood.gltf", t * Vector3(dx, 0, 0.85), 0.8, 180.0 + cap)
		_regular(t * Vector3(0.55, 0, -0.85), cap, 60 + i)
	if jeu == "machine":
		_lamp(t * Vector3(0, 1.8, 0.6), Color(1.0, 0.45, 0.75), 0.6, 2.5)
	elif table == null:
		_lamp(t * Vector3(0, 1.9, 0), Color(1.0, 0.8, 0.5), 1.4, 3.5, i == 0)
	else:
		_lamp(t * Vector3(0, 2.2, 0.2), Color(1.0, 0.82, 0.55), 1.8, 4.0, i == 0)
	# L'enseigne de la table, suspendue au-dessus : on lit le jeu en entrant.
	var haut: float = {"machine": 2.55, "roue": H - 0.35}.get(jeu, 2.15)
	_label3d(str(Tables.fiche(jeu).titre), t * Vector3(0, haut, 0), 40, Color(1.0, 0.85, 0.6), cap).shaded = false
	var a := _interactive(spot, "jeu", "E : %s" % Tables.fiche(jeu).invite, Vector3(maxf(e.x, 1.2) + 0.6, 1.8, e.y + 1.6), Vector3(0, 0.9, 0.5))
	a.set_meta("jeu", jeu)


# --- Le décor d'une brique (socle 1.22) -------------------------------------------------------------

## La salle sur le décor que nomme « modele » : le socle n'y bâtit rien, il branche ses ancres (Ancres.SALLE_JEU).
## Le tenancier au comptoir, une table par ancre TableN dans l'ordre des jeux, le guichet, l'enseigne et la sortie.
func _brancher_decor(m: Node3D, jeux: Array, tenancier: String, champs: Dictionary) -> void:
	# Un décor apporte d'ordinaire sa lumière ; sans environnement à lui, il prend celui des salles du socle.
	if m.find_children("*", "WorldEnvironment", true, false).is_empty():
		_environment()
	var places := Ancres.tables(m)
	if jeux.size() > places.size():
		push_warning("Salle de jeu : le décor n'a que %d places de table pour %d jeux, les derniers ne sont pas posés" % [places.size(), jeux.size()])
	for i in mini(jeux.size(), places.size()):
		_poser_table(str(jeux[i]), _repere(places[i]), i)
	_keeper = _pied(Ancres.trouver(m, "Comptoir"))
	var c := CRITTER.new()
	c.randomize_look(int(champs.get("graine", 0)))
	c.idle_anim = "bar"
	c.scale = Vector3.ONE * PEOPLE_SCALE
	_keeper.add_child(c)
	# Le comptoir est entre le tenancier et le visiteur : la zone le déborde de son côté. Une salle qui prend les
	# paris sur un décor sans ancre « Paris » : c'est au tenancier lui-même qu'on parie.
	var carnet := Ancres.trouver(m, "Paris")
	if champs.get("paris", false) and carnet == null:
		_interactive(_keeper, "paris", "E : parier avec %s" % tenancier, Vector3(2.2, 2.2, 1.6), Vector3(0, 1.1, 2.2))
	else:
		_interactive(_keeper, "keeper", "E : parler à %s" % tenancier, Vector3(2.2, 2.2, 1.6), Vector3(0, 1.1, 2.2))
	if champs.get("paris", false) and carnet != null:
		_carnet_paris(_repere(carnet))
	if champs.get("guichet", false):
		var g := Ancres.trouver(m, "Guichet")
		if g:
			_guichet_sur(_pied(g))
		else:
			push_warning("Salle de jeu : le décor n'a pas d'ancre « Guichet », le banquier ne vient pas")
	var e := Ancres.trouver(m, "Enseigne")
	if e:
		_ecrire(e, str(champs.get("enseigne", _salle.name)))
	_interactive(_pied(Ancres.trouver(m, "Sortie")), "exit", _salle.sortie, Vector3(2.4, 2.6, 1.6), Vector3(0, 1.2, 0))


## Le carnet des paris posé sur le comptoir, dans le repère « t » (sur le zinc, lisible depuis son +Z) : E ouvre
## le comptoir des paris au nom du tenancier (socle 1.26).
func _carnet_paris(t: Transform3D) -> void:
	_carnet_pmu = Node3D.new()
	_carnet_pmu.name = "CarnetParis"
	_carnet_pmu.transform = t
	add_child(_carnet_pmu)
	_box(Vector3(0.36, 0.025, 0.26), Vector3.ZERO, _std(Color(0.16, 0.42, 0.2), 0.7), false, _carnet_pmu)
	_box(Vector3(0.3, 0.012, 0.2), Vector3(0, 0.018, 0), _std(Color(0.95, 0.93, 0.85), 0.9), false, _carnet_pmu)
	_cyl(0.008, 0.16, Vector3(0.12, 0.03, 0.02), _std(Color(0.12, 0.12, 0.3), 0.3), _carnet_pmu).rotation_degrees = Vector3(90, 0, 25)
	var l := _label3d("PARIS", Vector3.ZERO, 18, Color(0.95, 0.95, 0.9))
	l.reparent(_carnet_pmu, false)
	l.rotation_degrees.x = -90.0
	l.position = Vector3(0, 0.03, -0.05)
	_interactive(_carnet_pmu, "paris", "E : parier au comptoir", Vector3(1.0, 1.2, 1.2), Vector3(0, -0.3, 0.5))


## Le comptoir des paris, au nom du tenancier de la salle.
func open_paris() -> void:
	if _game != null:
		return
	var p: PanelContainer = PARIS.new()
	p.teneur = _salle.host
	p.titre = "Le carnet des paris de %s" % _salle.host
	# Les courses cyclistes de la commune se jouent au même comptoir (socle 1.28).
	for e in Cyclisme.courses():
		if e.commune == commune and Cyclisme.ouverte(e):
			p.ailleurs.append(["La course : %s" % e.nom, func(): ouvrir_course(str(e.id))])
	_ouvrir_panneau(p)


## Le programme d'une course cycliste de la commune, au comptoir : on y parie gagnant ou placé (socle 1.28).
func ouvrir_course(id: String) -> void:
	if _game != null:
		return
	var p := CoursePanel.de(commune, id)
	if p == null:
		return
	p.teneur = _salle.host
	_ouvrir_panneau(p)


## Les tickets réglés depuis la dernière visite (le règlement tombe à l'heure, où que soit le joueur) : en entrant,
## le tenancier en dit un mot, comme Josiane au café.
func _annoncer_paris() -> void:
	Paris.regler()
	for t in Paris.non_vus():
		if t.etat == "gagne":
			_note("%s : « Votre ticket de la journée %d est bon : %s crédits. »" % [_salle.host, int(t.j), Game.fmt(int(t.gain))])
		else:
			_note("%s : « La journée %d, c'est pour la maison. Un autre ? »" % [_salle.host, int(t.j)])


## Le repère d'une ancre dans celui de la salle, sans échelle.
func _repere(ancre: Node3D) -> Transform3D:
	var t := global_transform.affine_inverse() * ancre.global_transform
	return Transform3D(t.basis.orthonormalized(), t.origin)


## Un texte du socle sur une ancre, lisible depuis son +Z ; les métas de l'ancre « hauteur » et « largeur » (en
## mètres) le mesurent, « couleur » le teinte et « espace » l'écrit en capitales espacées.
func _ecrire(ancre: Node3D, texte: String) -> void:
	# « espace » : en capitales espacées, comme une enseigne peinte sur un bandeau.
	if ancre.get_meta("espace", false):
		texte = " ".join(texte.to_upper().split(""))
	var l := _label3d(texte, Vector3.ZERO, 64, Color(ancre.get_meta("couleur", Color(0.95, 0.85, 0.6))))
	l.shaded = false
	# « hauteur » donne la taille des lettres, que « largeur » réduit si le texte est trop long.
	var hauteur := float(ancre.get_meta("hauteur", 0.0))
	if hauteur > 0.0:
		l.pixel_size = hauteur / 64.0
	var largeur := float(ancre.get_meta("largeur", 0.0))
	if largeur > 0.0:
		l.pixel_size = minf(l.pixel_size, largeur / maxf(1.0, texte.length() * 0.62 * 64))
	remove_child(l)
	ancre.add_child(l)


## Le banquier de la commune, debout à une ancre et tourné vers son +Z, sous son enseigne.
func _guichet_sur(pied: Node3D) -> void:
	var c: Commune = Communes.commune(commune)
	var b: Dictionary = c.banque() if c else {}
	var f := CRITTER.new()
	f.randomize_look(hash(str(b.get("banquier", "banquier"))))
	f.idle_anim = "stand_table"
	f.scale = Vector3.ONE * PEOPLE_SCALE
	pied.add_child(f)
	var l := _label3d(str(b.get("nom", "La banque")), Vector3(0, 2.3, 0), 36, Color(0.7, 0.82, 1.0))
	l.shaded = false
	remove_child(l)
	pied.add_child(l)
	_interactive(pied, "guichet", "E : voir %s" % str(b.get("banquier", "le banquier")), Vector3(1.8, 2.0, 1.8), Vector3(0, 1.0, 1.2))


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			_sortir()
		"jeu":
			_jeu_ouvert = str(target.get_meta("jeu", "machine"))
			_table_choisie = target.get_parent().get_meta("table3d", null)
			open_game()
		"guichet":
			_ouvrir_panneau(load("res://scripts/loan_panel.gd").de_commune(commune))
		_:
			super(target)


## La porte ramène dans la commune, devant la porte de la salle (lot, sinon l'id de la structure).
func _sortir() -> void:
	Game.return_point = str(structure.get("lot", "")) if str(structure.get("lot", "")) != "" else str(structure.get("id", ""))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var c: Commune = Communes.commune(commune)
	Chargement.changer(str(c.data.scene) if c else "res://scenes/main.tscn")


func open_game() -> void:
	if _game != null:
		return
	var f := Tables.fiche(_jeu_ouvert)
	if f.is_empty():
		f = JEUX.machine
	var p: PanelContainer
	if _jeu_ouvert == "poker" and Compte.connecte():
		# Connecté, on joue à plusieurs : chaque salle de jeu a sa table au serveur, aux tarifs des
		# Ambassadeurs (fonction casino du dépôt chtabay/addict, smarves-poker.js).
		# Le chemin écrit ici, pas en constante : une salle de commune qui étend celle-ci peut déjà
		# avoir sa constante POKER_MULTI (le Sport Bar de Cloué 1.6.2), et une seconde ne compilerait pas.
		p = load("res://scripts/jeux/poker_multi.gd").new()
		p.configurer_table(table_serveur(commune, str(structure.get("id", ""))), p.SB, p.BB, p.CAP)
	else:
		p = load(f.panneau).new()
	if "game" in p:
		p.game = self
	if "title" in p:
		p.title = "%s : %s" % [_salle.name, f.titre]
	p.played.connect(_on_played)
	var t: Node3D = _table_choisie if _table_choisie else _tables3d.get(_jeu_ouvert, null)
	_table_choisie = null
	_ouvrir_panneau(p, t)


## La table à plusieurs d'une salle, chez le serveur : « salle:<commune>:<salle> ».
static func table_serveur(id_commune: String, id_salle: String) -> String:
	return "salle:%s:%s" % [id_commune, id_salle]


## Ouvre un panneau ; avec une table 3D, comme au casino : on s'y assoit, la caméra glisse jusqu'à la
## place et le panneau devient la barre basse (Tables.asseoir). Sans table, il s'ouvre au milieu.
func _ouvrir_panneau(p: PanelContainer, t: Node3D = null) -> void:
	if _game != null:
		return
	p.closed.connect(func():
		if _table_assise:
			Tables.lever(_table_assise)
			_table_assise = null
		p.queue_free()
		_game = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if t:
		_table_assise = t
		Tables.asseoir(t, p, player.camera, _panel_layer.get_parent())
	else:
		_panel_layer.add_child(p)
	_game = p


## Le gain s'encaisse comme partout ; les lieux de la commune qui ouvrent avec lui font signe.
func _on_played(bet: int, payout: int) -> void:
	Sfx.result(bet, payout)
	var before := Game.won
	Game.cash_in(payout)
	if payout >= bet * 20:
		_note("Jackpot ! Toute la salle se retourne.")
	var c: Commune = Communes.commune(commune)
	for l in (c.lieux() if c else []):
		if l.seuil > 0 and before < l.seuil and Game.won >= l.seuil:
			_note("%s vous fait signe : %s %s ce soir." % [l.host, l.name.substr(0, 1).to_lower() + l.name.substr(1), "ouvrent" if l.name.begins_with("Les ") else "ouvre"])


func _capture_commune() -> void:
	var path := ""
	var jeu := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--open="):
			jeu = arg.trim_prefix("--open=")
		elif arg == "--guichet":
			jeu = "guichet"
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if jeu != "":
		await get_tree().create_timer(1.0).timeout
		if jeu == "guichet":
			_ouvrir_panneau(load("res://scripts/loan_panel.gd").de_commune(commune))
		elif jeu == "paris":
			open_paris()
		else:
			_jeu_ouvert = jeu
			open_game()
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
