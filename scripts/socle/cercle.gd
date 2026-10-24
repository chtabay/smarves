class_name Cercle
extends "res://scripts/village/salle.gd"
## Le Cercle Philidor, la salle des jeux de réflexion du casino de Smarves, prêtée aux communes (la brique
## « plateaux », scripts/plateaux/plateaux.gd) : on y monte par la porte du Bar du Fumoir, derrière son
## seuil. Lambris, tapis vert, lampes basses ; on y marche à la première personne comme dans les salles
## du village.
##
## Les tables d'échecs sont celles du serveur (fonction casino, smarves-plateaux.js) :
## - au fond, les tables où un robot est installé, assis, qui attend : on s'assied en face pour jouer
##   seul contre lui ;
## - devant, les tables vides, pour deux joueurs réels : le premier s'assied, le second le rejoint.
##   Le nom de ceux qui y sont assis flotte au-dessus de la table, et un joueur qui attend y est assis.
##
## Une commune ouvre son Cercle par Cercle.ouvrir(casino, scène de retour, point de retour) ; ses tables
## sont celles de son casino chez le serveur (« cercle:… » pour Smarves).
## Capture : godot --path . res://scenes/cercle.tscn -- --capture=sortie.png [--at=x,z,lacet,tangage] [--open=cercle:echecs-1]

const PANNEAU := preload("res://scripts/plateaux/echecs_panel.gd")
const TABLE := preload("res://scripts/plateaux/table_echecs_3d.gd")
const RELIRE_SALLE := 3.0

## Les tables de Smarves, comme le serveur les connaît, et leur place dans la salle : au fond, les cinq
## robots, du plus tendre au plus fort (leur force en mots, comme au serveur) ; devant, trois tables à deux.
const TABLES := [
	{"id": "cercle:echecs-pierrot", "pos": Vector3(-4.4, 0, -3.2), "robot": "Pierrot", "force": "Novice", "graine": 71},
	{"id": "cercle:echecs-basile", "pos": Vector3(-2.2, 0, -3.2), "robot": "Basile", "force": "Débutant", "graine": 72},
	{"id": "cercle:echecs-ferrand", "pos": Vector3(0.0, 0, -3.2), "robot": "Madame Ferrand", "force": "Amateur", "graine": 73},
	{"id": "cercle:echecs-ostrowski", "pos": Vector3(2.2, 0, -3.2), "robot": "Le docteur Ostrowski", "force": "Confirmé", "graine": 74},
	{"id": "cercle:echecs-lacroix", "pos": Vector3(4.4, 0, -3.2), "robot": "Madame Lacroix", "force": "Expert", "graine": 75},
	{"id": "cercle:echecs-1", "pos": Vector3(-2.6, 0, 0.8), "nom": "Table 1"},
	{"id": "cercle:echecs-2", "pos": Vector3(0.0, 0, 0.8), "nom": "Table 2"},
	{"id": "cercle:echecs-3", "pos": Vector3(2.6, 0, 0.8), "nom": "Table 3"},
]
const REPLIQUES := ["« Au fond, nos cinq joueurs attendent qu'on s'assoie en face d'eux, de Pierrot à Madame Lacroix. Devant, les tables sont pour jouer entre vous. »",
	"« Philidor jouait ici de tête, trois parties à la fois, les yeux bandés. Enfin, ici : dans un café comme celui-ci. »",
	"« On mise avant la partie, si l'on veut. Contre Madame Lacroix, une victoire rend cinq fois la mise : on ne la voit pas souvent. »",
	"« Cinq minutes à la pendule, c'est la cadence de la maison. Le temps de réfléchir, pas de rêver. »"]

static var _prochaine: Array = []

var casino := "smarves"
var retour_scene := "res://scenes/casino.tscn"
var retour_point := "cercle"
var _tables := {}
var _invites := {}
var _salle_minuteur: Timer


## Ouvre le Cercle d'un casino ; la porte ramène à `scene`, au point `point` (Game.return_point).
static func ouvrir(id_casino := "smarves", scene := "res://scenes/casino.tscn", point := "cercle") -> void:
	_prochaine = [id_casino, scene, point]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Chargement.lieu("res://scenes/cercle.tscn")


func _ready() -> void:
	shop = "cercle"
	if _prochaine.size() == 3:
		casino = _prochaine[0]
		retour_scene = _prochaine[1]
		retour_point = _prochaine[2]
		_prochaine = []
	_salle = {"name": "Le Cercle Philidor", "host": "Monsieur Vautrin", "jeu": "", "sortie": "E : redescendre au Fumoir",
		"lines": REPLIQUES}
	_serif = Polices.texte()
	W = 12.0
	D = 11.0
	H = 3.4
	_environment()
	_room(_wood_floor(Color(0.42, 0.26, 0.15)), _wallpaper(Color(0.16, 0.26, 0.2), Color(0.19, 0.3, 0.23)), Color(0.86, 0.82, 0.72), Color(0.32, 0.2, 0.11))
	# Le tapis vert sous les tables.
	_box(Vector3(10.6, 0.01, 7.0), Vector3(0, 0.005, -1.2), _std(Color(0.1, 0.24, 0.15), 0.95))
	_secretaire()
	for t in TABLES:
		_table(t)
	_label3d("CERCLE PHILIDOR", Vector3(0, H - 0.5, -D / 2.0 + 0.12), 80, Color(0.95, 0.85, 0.6)).shaded = false
	_label3d("Les échecs, depuis 1747", Vector3(0, H - 0.82, -D / 2.0 + 0.12), 34, Color(0.85, 0.75, 0.55)).shaded = false
	_door()
	for a in find_children("*", "Area3D", true, false):
		if a.get_meta("interact", "") == "exit":
			a.set_meta("prompt", _salle.sortie)
	_build_ui()
	_panel_layer.get_parent().theme = Tables.theme()
	player = PLAYER.new()
	player.position = Vector3(0, 0, D / 2.0 - 1.2)
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("casino")
	_salle_minuteur = Timer.new()
	_salle_minuteur.wait_time = RELIRE_SALLE
	_salle_minuteur.autostart = true
	_salle_minuteur.timeout.connect(_relire_salle)
	add_child(_salle_minuteur)
	_relire_salle()
	_capture_cercle()


func _place_name() -> String:
	return _salle.name


## Le secrétaire du Cercle, à son pupitre près de la porte : il tient le registre et parle de la maison.
func _secretaire() -> void:
	var p := Vector3(-W / 2.0 + 1.2, 0, D / 2.0 - 2.0)
	_box(Vector3(0.7, 1.0, 1.2), p + Vector3(0.4, 0.5, 0), _std(Color(0.28, 0.16, 0.08), 0.5), true)
	_box(Vector3(0.5, 0.03, 0.4), p + Vector3(0.4, 1.02, 0), _std(Color(0.9, 0.86, 0.75), 0.9))
	_keeper = Node3D.new()
	_keeper.position = p + Vector3(-0.2, 0, 0)
	_keeper.rotation.y = PI / 2.0
	add_child(_keeper)
	var c := CRITTER.new()
	c.randomize_look(1681)
	c.idle_anim = "stand_table"
	c.scale = Vector3.ONE * PEOPLE_SCALE
	_keeper.add_child(c)
	_interactive(_keeper, "keeper", "E : parler à Monsieur Vautrin", Vector3(1.6, 2.0, 1.8), Vector3(0.6, 1.0, 0))
	_lamp(p + Vector3(0.4, 1.7, 0), Color(1.0, 0.8, 0.55), 0.8, 3.0)


## Une table d'échecs : le guéridon et son échiquier, deux chaises, la lampe, l'enseigne, et le robot
## assis côté -z s'il y en a un.
func _table(t: Dictionary) -> void:
	var p: Vector3 = t.pos
	var spot := Node3D.new()
	spot.position = p
	add_child(spot)
	var tb: Node3D = TABLE.new()
	spot.add_child(tb)
	_solid_box_at(Vector3(0.8, 0.8, 0.8), p + Vector3(0, 0.4, 0))
	_place(KK + "furniture/chair_A_wood.gltf", p + Vector3(0, 0, 0.62), 0.6, 180.0)
	_place(KK + "furniture/chair_A_wood.gltf", p + Vector3(0, 0, -0.62), 0.6, 0.0)
	var robot := str(t.get("robot", ""))
	if robot != "":
		_regular(p + Vector3(0, 0, -0.85), 0.0, int(t.graine))
	_lamp(p + Vector3(0, 1.9, 0), Color(1.0, 0.82, 0.55), 1.3, 3.2)
	var titre := robot if robot != "" else str(t.get("nom", "Table"))
	# Les enseignes des tables de devant, plus proches, sont plus basses et plus petites.
	var y := 2.0 if robot != "" else 1.45
	var enseigne := _label3d(titre, p + Vector3(0, y, 0), 40 if robot != "" else 30, Color(1.0, 0.85, 0.6))
	enseigne.shaded = false
	enseigne.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	var sous := _label3d(str(t.force) if robot != "" else "une partie à deux", p + Vector3(0, y - 0.16, 0), 26 if robot != "" else 20, Color(0.85, 0.8, 0.7))
	sous.shaded = false
	sous.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	var invite := "E : jouer contre %s (%s)" % [robot, str(t.force).to_lower()] if robot != "" else "E : s'asseoir à la %s (contre un autre joueur)" % str(t.nom).to_lower()
	var a := _interactive(spot, "plateau", invite, Vector3(1.4, 1.8, 2.2), Vector3(0, 0.9, 0.5))
	a.set_meta("table", t.id)
	a.set_meta("titre", ("Échecs contre %s" % robot) if robot != "" else "Échecs · %s" % str(t.nom))
	_tables[t.id] = {"table3d": tb, "sous": sous, "pos": p, "robot": robot != ""}


# --- Les tables du serveur -------------------------------------------------------------------------

## Qui est assis aux tables à deux, relu sur le serveur : leur nom au-dessus de la table, et un joueur
## qui attend, assis à la chaise d'en face.
func _relire_salle() -> void:
	if not Compte.connecte() or _game != null:
		return
	var r: Dictionary = await Compte.casino("plateau.salle", {"casino": casino})
	if not is_inside_tree() or r.code != 200 or not r.corps is Dictionary:
		return
	montrer_salle(r.corps)


## Pose la salle du serveur (smarves-plateaux.js, salleSmarvesPlateaux).
func montrer_salle(s: Dictionary) -> void:
	for t in s.get("tables", []):
		var info: Dictionary = _tables.get(str(t.id), {})
		if info.is_empty() or info.robot:
			continue
		var noms: Array = t.get("joueurs", [])
		info.sous.text = "une partie à deux" if noms.is_empty() else ("%s attend un adversaire" % noms[0] if noms.size() == 1 else "%s et %s jouent" % [noms[0], noms[1]])
		var veut: bool = noms.size() > 0 and not t.get("moi", false)
		if veut and not _invites.has(t.id):
			var c := CRITTER.new()
			c.randomize_look(hash(str(noms[0])))
			c.scale = Vector3.ONE * PEOPLE_SCALE
			c.position = info.pos + Vector3(0, 0, -0.85)
			add_child(c)
			c.debug_anim("sit_table")
			_invites[t.id] = c
		elif not veut and _invites.has(t.id):
			_invites[t.id].queue_free()
			_invites.erase(t.id)


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			Game.return_point = retour_point
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Chargement.changer(retour_scene)
		"plateau":
			ouvrir_table(str(target.get_meta("table")), str(target.get_meta("titre", "")))
		_:
			super(target)


## S'asseoir à une table : le panneau de la partie s'ouvre par-dessus la salle.
func ouvrir_table(id: String, titre := "", hors_ligne := false) -> Control:
	if _game != null:
		return null
	if not hors_ligne and not Compte.connecte():
		say("« Le Cercle joue sur le registre du casino : connectez-vous à votre compte, dans les réglages. »")
		return null
	var p: PanelContainer = PANNEAU.new()
	p.table_id = id
	p.title = titre
	p.hors_ligne = hors_ligne
	p.closed.connect(func():
		p.queue_free()
		_game = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_relire_salle())
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_game = p
	# La table 3D suit la partie qu'on y joue.
	var info: Dictionary = _tables.get(id, {})
	if not info.is_empty():
		p.set_meta("table3d", info.table3d)
	return p


func _process(d: float) -> void:
	super(d)
	if _game != null and _game.has_meta("table3d") and _game.get("vue") is Dictionary:
		var pt = _game.vue.get("partie")
		if pt is Dictionary:
			var tb: Node3D = _game.get_meta("table3d")
			tb.retourne = _game.echiquier.retourne
			if tb.get_meta("montre", "") != str(pt.plateau) + str(tb.retourne):
				tb.set_meta("montre", str(pt.plateau) + str(tb.retourne))
				tb.montrer(str(pt.plateau))


func _capture_cercle() -> void:
	var path := ""
	var table := ""
	var vue := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--open="):
			table = arg.trim_prefix("--open=")
		elif arg.begins_with("--vue="):
			vue = arg.trim_prefix("--vue=")
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
			if v.size() > 3:
				player.camera.rotation.x = deg_to_rad(v[3])
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if table != "":
		await get_tree().create_timer(0.5).timeout
		var p := ouvrir_table(table, "Échecs contre Madame Lacroix" if table.ends_with("lacroix") else "Échecs · Table 1", true)
		if vue != "" and p:
			p.appliquer(JSON.parse_string(FileAccess.get_file_as_string(vue)))
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
