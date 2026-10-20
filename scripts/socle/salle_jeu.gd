class_name SalleJeu
extends "res://scripts/village/salle.gd"
## La salle de jeu d'une commune, prêtée par le socle : la structure « salle_jeu » du manifeste
## (docs/COMMUNE.md, « Les structures »). La commune déclare son tenancier, ses jeux, son décor et ses
## répliques ; le socle construit la pièce, pose une table ou une machine par jeu, et fait tourner les
## jeux de Smarves (les mêmes panneaux qu'au casino, la même bourse, le même total gagné). La commune
## ouvre sa salle depuis sa scène par SalleJeu.ouvrir("<commune>", "<id de la structure>"). Avec
## « guichet » (socle 1.2), le banquier de la commune tient un bureau près de la porte : le prêt pour jouer,
## au nom de la banque du manifeste (scripts/loan_panel.gd, de_commune).
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
var _assis: Node3D


## Ouvre la salle de jeu « id » de la commune. Rend false sans rien faire si la structure n'existe pas,
## ou si le lieu du manifeste qui porte le même id n'est pas encore ouvert (son seuil de gagné au jeu).
static func ouvrir(id_commune: String, id: String) -> bool:
	if not ouverte(id_commune, id):
		return false
	_prochaine = [id_commune, id]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/salle_jeu.tscn")
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
	_environment()
	match decor:
		"salle":
			_room(_wood_floor(Color(0.62, 0.45, 0.28)), _std(Color(0.8, 0.82, 0.74), 0.85), Color(0.95, 0.94, 0.9), Color(0.5, 0.38, 0.28))
		"cave":
			_room(_flagstones(), _stone(), Color(0.5, 0.42, 0.34))
		_:
			_room(_checker(Color(0.86, 0.82, 0.74), Color(0.3, 0.2, 0.14)), _wallpaper(Color(0.62, 0.48, 0.32), Color(0.68, 0.54, 0.36)), Color(0.9, 0.84, 0.7), Color(0.3, 0.17, 0.1))
	_comptoir(tenancier, int(champs.get("graine", 0)))
	_tables(jeux)
	if champs.get("guichet", false):
		_guichet()
	var enseigne := str(champs.get("enseigne", _salle.name))
	_label3d(enseigne, Vector3(0, H - 0.45, -D / 2.0 + 0.12), 80, Color(0.95, 0.85, 0.6)).shaded = false
	_bulb(Vector3(-W / 4.0, H - 0.7, 0.4), Color(0.85, 0.55, 0.3))
	_bulb(Vector3(W / 4.0, H - 0.7, 0.4), Color(0.85, 0.55, 0.3))
	_door()
	for a in find_children("*", "Area3D", true, false):
		if a.get_meta("interact", "") == "exit":
			a.set_meta("prompt", _salle.sortie)
	_build_ui()
	# Les panneaux s'habillent comme au casino de Smarves.
	_panel_layer.get_parent().theme = Tables.theme()
	player = PLAYER.new()
	player.position = Vector3(0, 0, D / 2.0 - 1.2)
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("casino")
	_capture_commune()


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
	var feutre := _std(Color(0.05, 0.3, 0.16), 0.95)
	var bois := _std(Color(0.28, 0.17, 0.09), 0.6)
	var n := jeux.size()
	for i in n:
		var jeu := str(jeux[i])
		if not JEUX.has(jeu):
			continue
		var rang := i / COLONNES
		var dans_le_rang := mini(n - rang * COLONNES, COLONNES)
		var x := ((i % COLONNES) - (dans_le_rang - 1) / 2.0) * CASE.x
		var p := Vector3(x, 0, -D / 2.0 + 3.6 + rang * CASE.y)
		var spot := Node3D.new()
		spot.position = p
		add_child(spot)
		var e := Vector2(1.7, 0.9)
		var t := Tables.table(jeu)
		if t:
			# La lampe de la salle éclaire la table (plus bas) : celle de la table, un projecteur, ne passe pas
			# partout (le rendu web et mobile en compte peu par objet).
			e = Tables.EMPRISE[jeu]
			t.with_lamp = false
			spot.add_child(t)
			spot.set_meta("table3d", t)
			_tables3d[jeu] = _tables3d.get(jeu, t)
			_solid_box_at(Vector3(e.x, 3.0 if jeu == "roue" else 1.0, e.y), p + Vector3(0, 1.5 if jeu == "roue" else 0.5, 0))
			if jeu in ["blackjack", "roulette", "baccara", "des", "poker"]:
				# Pas de chaise au milieu : c'est la place du joueur, d'où la caméra regarde le tapis.
				for dx in [-0.9, 0.9]:
					_place(KK + "furniture/chair_A_wood.gltf", p + Vector3(dx, 0, e.y / 2.0 + 0.45), 0.8, 180.0)
			if jeu != "machine" and jeu != "roue":
				_regular(p + Vector3(0.55, 0, -e.y / 2.0 - 0.45), 0.0, 60 + i)
		else:
			_box(Vector3(1.9, 0.06, 1.1), p + Vector3(0, 0.78, 0), feutre)
			_box(Vector3(2.0, 0.06, 1.2), p + Vector3(0, 0.73, 0), bois)
			_box(Vector3(1.7, 0.7, 0.9), p + Vector3(0, 0.35, 0), bois, true)
			for dx in [-0.5, 0.5]:
				_place(KK + "furniture/chair_A_wood.gltf", p + Vector3(dx, 0, 0.85), 0.8, 180.0)
			_regular(p + Vector3(0.55, 0, -0.85), 0.0, 60 + i)
		if jeu == "machine":
			_lamp(p + Vector3(0, 1.8, 0.6), Color(1.0, 0.45, 0.75), 0.6, 2.5)
		elif t == null:
			_lamp(p + Vector3(0, 1.9, 0), Color(1.0, 0.8, 0.5), 1.4, 3.5, i == 0)
		else:
			_lamp(p + Vector3(0, 2.2, 0.2), Color(1.0, 0.82, 0.55), 1.8, 4.0, i == 0)
		# L'enseigne de la table, suspendue au-dessus : on lit le jeu en entrant.
		var haut: float = {"machine": 2.55, "roue": H - 0.35}.get(jeu, 2.15)
		_label3d(str(JEUX[jeu].titre), p + Vector3(0, haut, 0), 40, Color(1.0, 0.85, 0.6)).shaded = false
		var a := _interactive(spot, "jeu", "E : %s" % JEUX[jeu].invite, Vector3(maxf(e.x, 1.2) + 0.6, 1.8, e.y + 1.6), Vector3(0, 0.9, 0.5))
		a.set_meta("jeu", jeu)


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
	get_tree().change_scene_to_file(str(c.data.scene) if c else "res://scenes/main.tscn")


func open_game() -> void:
	if _game != null:
		return
	var p: PanelContainer = load(JEUX.get(_jeu_ouvert, JEUX.machine).panneau).new()
	if "game" in p:
		p.game = self
	if "title" in p:
		p.title = "%s : %s" % [_salle.name, JEUX.get(_jeu_ouvert, JEUX.machine).titre]
	p.played.connect(_on_played)
	var t: Node3D = _table_choisie if _table_choisie else _tables3d.get(_jeu_ouvert, null)
	_table_choisie = null
	_ouvrir_panneau(p, t)


## Ouvre un panneau ; avec une table 3D, comme au casino : on s'y assoit, la caméra glisse jusqu'à la
## place et le panneau devient la barre basse (Tables.asseoir). Sans table, il s'ouvre au milieu.
func _ouvrir_panneau(p: PanelContainer, t: Node3D = null) -> void:
	if _game != null:
		return
	p.closed.connect(func():
		if _assis:
			Tables.lever(_assis)
			_assis = null
		p.queue_free()
		_game = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if t:
		_assis = t
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
			_note("%s vous fait signe : %s ouvre ce soir." % [l.host, l.name.substr(0, 1).to_lower() + l.name.substr(1)])


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
		else:
			_jeu_ouvert = jeu
			open_game()
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
