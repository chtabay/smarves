class_name Prestation
extends "res://scripts/village/salle.gd"
## Une boutique où l'on se fait retoucher (Avatar, fiche docs/AVATAR.md) : la coiffeuse, le chirurgien, la
## salle de sport, le restaurant. Une pièce meublée selon le métier, le prestataire au fond ; on lui parle
## (E) et il ouvre son panneau (scripts/socle/relooking_panel.gd). La porte ramène devant la boutique.
##
## Smarves en a quatre, derrière des façades de la place et de la route du Bois (SMARVES, ouvertes par
## Prestation.smarves(id)) ; Raymonde et les commerces de tenues ouvrent la cabine d'essayage depuis leur
## vitrine. Une commune ouvre les siennes depuis sa scène, sans rien déclarer au manifeste :
##   Prestation.ouvrir("restaurant", {"commune": "<id>", "lot": "<porte>", "nom": "Chez Mémé",
##       "tenancier": "Mémé Roux", "graine": 4, "tarif": 1.5, "formules": [{"nom": …, "prix": …, "poids": 1, "dit": …}]})
## ou pose le panneau seul dans sa propre pièce : Prestation.panneau("coiffure", {…}).
## Capture : godot --path . res://scenes/prestation.tscn -- --prestation=coiffure --capture=sortie.png [--open] [--won=…]

const PANNEAU := preload("res://scripts/socle/relooking_panel.gd")
const SCENE := "res://scenes/prestation.tscn"

## Les quatre maisons de Smarves : leur métier, leur nom, qui les tient (fiche de Cast.NAMED), leur seuil
## (total gagné au jeu) et ce qu'on y entend.
const SMARVES := {
	"coiffure": {"metier": "coiffure", "nom": "Gisèle Coiffure", "tenancier": "Gisèle", "who": "gisele", "seuil": 0,
		"enseigne": "Gisèle Coiffure", "sous": "Dames · Messieurs · Mise en plis",
		"repliques": ["« Asseyez-vous, mon chou. Une coupe, c'est comme une martingale : il faut savoir s'arrêter. »",
			"« Josiane est passée ce matin. Elle a tout raconté, mais je ne répète rien. Presque rien. »",
			"« Au Salon privé, ils regardent les mains et les cheveux. Les mains, je ne peux rien pour vous. »"]},
	"chirurgie": {"metier": "chirurgie", "nom": "Le cabinet du docteur Maupas", "tenancier": "Le docteur Maupas", "who": "maupas", "seuil": 3000,
		"lot": "pharmacie", "enseigne": "Dr Maupas", "sous": "Chirurgie esthétique · au-dessus de la pharmacie",
		"repliques": ["« Docteur Maupas. Je refais les nez, les teints, les silhouettes. Les fortunes, c'est au casino. »",
			"« Une petite retouche, et l'inspecteur de salle ne vous reconnaîtra plus. C'est très demandé. »",
			"« J'ai opéré la moitié des Salons particuliers. L'autre moitié n'a pas encore gagné assez. »"]},
	"sport": {"metier": "sport", "nom": "Smarves Forme", "tenancier": "Jojo", "who": "jojo", "seuil": 1000,
		"lot": "lot_bois", "enseigne": "Smarves Forme", "sous": "Culture physique · Haltères · Sauna",
		"repliques": ["« Jojo, champion du Poitou de lutte, 1971. Allez, on enlève la veste et on soulève. »",
			"« Un joueur en forme tient la table plus longtemps. C'est scientifique. »",
			"« Les petits-fours du casino, c'est mon fonds de commerce. Merci Monsieur Armand. »"]},
	"restaurant": {"metier": "restaurant", "nom": "La Pizzeria du Clain", "tenancier": "Tonio", "who": "tonio", "seuil": 0,
		"lot": "pizzeria", "enseigne": "Pizzeria du Clain", "sous": "Pizzas au feu de bois",
		"repliques": ["« Tonio ! Le four est chaud depuis midi. Assis, assis, je vous apporte la carte. »",
			"« Une pizza avant le casino, c'est la chance qui tient au ventre. »",
			"« Le samedi, c'est complet. Pour vous, je trouve toujours une table. »"]},
}

## Ce que la prochaine boutique doit ouvrir (posé par ouvrir(), lu au _ready).
static var _prochaine: Dictionary = {}

var metier := "coiffure"
var options := {}


## Ouvre une boutique du métier (« couture », « coiffure », « chirurgie », « sport », « restaurant ») :
## options {commune, lot, nom, tenancier, graine, tarif, formules, enseigne, sous, repliques}. Rend false
## sans rien faire si le métier est inconnu.
static func ouvrir(metier_: String, options_ := {}) -> bool:
	if not Avatar.METIERS.has(metier_):
		return false
	_prochaine = {"metier": metier_, "options": options_.duplicate(true)}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(Engine.get_main_loop() as SceneTree).change_scene_to_file(SCENE)
	return true


## Ouvre une des maisons de Smarves, si son seuil est passé ; rend false sinon.
static func smarves(id: String) -> bool:
	var m: Dictionary = SMARVES.get(id, {})
	if m.is_empty() or Game.won < int(m.seuil):
		return false
	var o := m.duplicate(true)
	o.commune = "smarves"
	if not o.has("lot"):
		o.lot = id
	return ouvrir(str(m.metier), o)


## Le panneau seul, pour une commune qui a sa propre pièce : il émet spoke(texte) et closed.
static func panneau(metier_: String, options_ := {}) -> PanelContainer:
	var p: PanelContainer = PANNEAU.new()
	p.metier = metier_ if Avatar.METIERS.has(metier_) else "couture"
	p.options = options_.duplicate(true)
	return p


func _ready() -> void:
	shop = "prestation"
	if not _prochaine.is_empty():
		metier = str(_prochaine.metier)
		options = _prochaine.options
		_prochaine = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prestation="):
			var id := arg.trim_prefix("--prestation=")
			metier = str(SMARVES.get(id, {}).get("metier", id))
			options = SMARVES.get(id, {}).duplicate(true)
		elif arg.begins_with("--won="):
			Game.won = int(arg.trim_prefix("--won="))
			Game.credits += Game.won / 2
	var tenancier := str(options.get("tenancier", "La maison"))
	var lignes: Array = options.get("repliques", [])
	_salle = {"name": str(options.get("nom", Avatar.METIERS[metier].nom)), "host": tenancier,
		"sortie": "E : sortir", "lines": lignes if not lignes.is_empty() else ["« Bienvenue. Prenez votre temps, on ne paie que ce qu'on garde. »"]}
	_serif = Polices.texte()
	W = 10.0 if metier in ["sport", "restaurant"] else 8.0
	D = 9.0 if metier in ["sport", "restaurant"] else 8.0
	H = 3.4
	_environment()
	match metier:
		"coiffure":
			_room(_checker(Color(0.95, 0.93, 0.9), Color(0.2, 0.18, 0.22)), _wallpaper(Color(0.92, 0.66, 0.74), Color(0.97, 0.8, 0.84)), Color(0.98, 0.95, 0.94))
			_coiffure()
		"chirurgie":
			_room(_checker(Color(0.93, 0.95, 0.93), Color(0.78, 0.86, 0.82)), _std(Color(0.82, 0.9, 0.86), 0.8), Color(0.97, 0.98, 0.97), Color(0.6, 0.72, 0.68))
			_chirurgie()
		"sport":
			_room(_wood_floor(Color(0.7, 0.52, 0.32)), _std(Color(0.88, 0.86, 0.8), 0.85), Color(0.92, 0.92, 0.9), Color(0.25, 0.35, 0.55))
			_sport()
		"restaurant":
			_room(_checker(Color(0.92, 0.9, 0.85), Color(0.62, 0.14, 0.12)), _wallpaper(Color(0.86, 0.78, 0.6), Color(0.9, 0.83, 0.66)), Color(0.95, 0.92, 0.86), Color(0.2, 0.4, 0.24))
			_restaurant()
		_:
			_room(_wood_floor(Color(0.72, 0.56, 0.4)), _wallpaper(Color(0.78, 0.66, 0.7), Color(0.86, 0.76, 0.78)), Color(0.98, 0.95, 0.92))
	_comptoir(tenancier)
	_label3d(str(options.get("enseigne", _salle.name)), Vector3(0, H - 0.45, -D / 2.0 + 0.12), 72, Color(0.35, 0.18, 0.1))
	if str(options.get("sous", "")) != "":
		_label3d(str(options.sous), Vector3(0, H - 0.75, -D / 2.0 + 0.12), 30, Color(0.4, 0.28, 0.2))
	_bulb(Vector3(-W / 4.0, H - 0.7, 0.4), Color(0.95, 0.85, 0.6))
	_bulb(Vector3(W / 4.0, H - 0.7, 0.4), Color(0.95, 0.85, 0.6))
	_door()
	for a in find_children("*", "Area3D", true, false):
		if a.get_meta("interact", "") == "exit":
			a.set_meta("prompt", _salle.sortie)
	_build_ui()
	player = PLAYER.new()
	player.position = Vector3(0, 0, D / 2.0 - 1.2)
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("village")
	_capture_prestation()


## Le prestataire au fond : sa fiche s'il en a une (Cast.NAMED), sinon un habitant tiré de la graine.
func _comptoir(tenancier: String) -> void:
	var bz := -D / 2.0 + 1.8
	if metier in ["coiffure", "chirurgie", "restaurant"]:
		var bois := _std(Color(0.4, 0.26, 0.15), 0.55) if metier != "chirurgie" else _std(Color(0.92, 0.94, 0.93), 0.4)
		_box(Vector3(2.4, 0.9, 0.6), Vector3(W / 2.0 - 2.0, 0.45, bz), bois, true)
	_keeper = Node3D.new()
	_keeper.position = Vector3(W / 2.0 - 2.0 if metier in ["coiffure", "chirurgie", "restaurant"] else 0.0, 0, -D / 2.0 + 0.9)
	add_child(_keeper)
	var f := CRITTER.new()
	var who := str(options.get("who", ""))
	if Cast.NAMED.has(who):
		f.look = Cast.NAMED[who].duplicate(true)
	else:
		f.randomize_look(int(options.get("graine", 0)))
	f.idle_anim = "attentive"
	f.scale = Vector3.ONE * PEOPLE_SCALE
	_keeper.add_child(f)
	_interactive(_keeper, "keeper", "E : parler à %s" % tenancier, Vector3(2.4, 2.2, 1.8), Vector3(0, 1.1, 0.9))
	_lamp(Vector3(_keeper.position.x, 1.8, bz), Color(1.0, 0.85, 0.6), 1.0, 4.0)


# --- Les pièces -----------------------------------------------------------------------------------

## Deux fauteuils face aux miroirs, le séchoir à casque, les flacons.
func _coiffure() -> void:
	var cuir := _std(Color(0.55, 0.12, 0.18), 0.45)
	var chrome := _std(Color(0.8, 0.8, 0.82), 0.2, 0.9)
	var miroir := _std(Color(0.75, 0.82, 0.88), 0.05, 0.6)
	for z in [-0.6, 1.2]:
		var x := -W / 2.0 + 0.9
		_box(Vector3(0.05, 1.1, 0.9), Vector3(-W / 2.0 + 0.04, 1.55, z), miroir)
		_box(Vector3(0.4, 0.04, 1.0), Vector3(-W / 2.0 + 0.22, 0.95, z), _std(Color(0.95, 0.95, 0.95), 0.3))
		_cyl(0.06, 0.4, Vector3(x, 0.2, z), chrome)
		_box(Vector3(0.55, 0.12, 0.55), Vector3(x, 0.46, z), cuir, true)
		_box(Vector3(0.12, 0.6, 0.55), Vector3(x + 0.26, 0.82, z), cuir)
		for k in 4:
			_cyl(0.03, 0.14, Vector3(-W / 2.0 + 0.2, 1.04, z - 0.3 + k * 0.2), _std([Color(0.9, 0.5, 0.6), Color(0.4, 0.6, 0.9), Color(0.95, 0.85, 0.4), Color(0.6, 0.85, 0.6)][k], 0.2))
	# Le séchoir à casque, dans le coin.
	var sx := W / 2.0 - 0.9
	_cyl(0.05, 1.1, Vector3(sx, 0.55, 1.6), chrome)
	var casque := _cyl(0.28, 0.3, Vector3(sx, 1.25, 1.45), _std(Color(0.95, 0.88, 0.9), 0.3), self, 0.22)
	casque.rotation_degrees.x = -20.0
	_box(Vector3(0.55, 0.45, 0.55), Vector3(sx, 0.22, 1.9), cuir, true)


## La table d'examen, le scialytique, le paravent, les diplômes.
func _chirurgie() -> void:
	var blanc := _std(Color(0.95, 0.96, 0.95), 0.4)
	var chrome := _std(Color(0.8, 0.8, 0.82), 0.2, 0.9)
	_box(Vector3(0.8, 0.7, 1.9), Vector3(-W / 2.0 + 1.2, 0.35, 0.2), blanc, true)
	_box(Vector3(0.75, 0.08, 1.85), Vector3(-W / 2.0 + 1.2, 0.74, 0.2), _std(Color(0.55, 0.75, 0.7), 0.5))
	_cyl(0.03, 2.0, Vector3(-W / 2.0 + 1.9, 1.0, -0.6), chrome)
	var lampe := _cyl(0.32, 0.12, Vector3(-W / 2.0 + 1.4, 2.05, 0.1), chrome, self, 0.18)
	lampe.rotation_degrees.z = 15.0
	var verre := _std(Color(1.0, 1.0, 0.95), 0.1)
	verre.emission_enabled = true
	verre.emission = Color(1.0, 0.98, 0.9)
	verre.emission_energy_multiplier = 2.0
	_cyl(0.26, 0.02, Vector3(-W / 2.0 + 1.4, 1.98, 0.1), verre)
	# Le paravent à trois panneaux, les diplômes au mur.
	for i in 3:
		var p := _box(Vector3(0.6, 1.6, 0.03), Vector3(W / 2.0 - 1.2 + i * 0.0, 0.85, 0.6 + i * 0.58), _std(Color(0.9, 0.93, 0.9), 0.7))
		p.rotation_degrees.y = 90.0 + (i - 1) * 25.0
	for k in 3:
		_box(Vector3(0.03, 0.4, 0.5), Vector3(-W / 2.0 + 0.03, 1.8, -1.8 + k * 0.7), _std(Color(0.95, 0.92, 0.8), 0.6))
	_label3d("Faculté de médecine de Poitiers", Vector3(-W / 2.0 + 0.06, 2.15, -1.1), 22, Color(0.3, 0.3, 0.35), 90.0)


## Les bancs, les haltères sur leur râtelier, les espaliers.
func _sport() -> void:
	var fonte := _std(Color(0.12, 0.12, 0.14), 0.35, 0.6)
	var cuir := _std(Color(0.2, 0.22, 0.3), 0.5)
	for x in [-2.6, 0.0, 2.6]:
		_box(Vector3(0.4, 0.42, 1.4), Vector3(x, 0.21, 0.6), cuir, true)
		_cyl(0.02, 1.6, Vector3(x, 1.0, 0.25), _std(Color(0.8, 0.8, 0.82), 0.2, 0.9)).rotation_degrees.z = 90.0
		for s in [-0.7, 0.7]:
			_cyl(0.2, 0.06, Vector3(x + s, 1.0, 0.25), fonte).rotation_degrees.z = 90.0
	# Le râtelier d'haltères le long du mur est.
	_box(Vector3(0.5, 0.7, 2.4), Vector3(W / 2.0 - 0.4, 0.35, 0.5), _std(Color(0.3, 0.2, 0.12), 0.6), true)
	for k in 6:
		var z := -0.5 + k * 0.4
		_cyl(0.07, 0.3, Vector3(W / 2.0 - 0.4, 0.78, z), fonte).rotation_degrees.x = 90.0
	# Les espaliers du mur ouest.
	var bois := _std(Color(0.75, 0.58, 0.35), 0.5)
	for k in 10:
		_cyl(0.02, 1.4, Vector3(-W / 2.0 + 0.12, 0.25 + k * 0.24, 0.5), bois).rotation_degrees.x = 90.0
	_box(Vector3(0.06, 2.6, 0.06), Vector3(-W / 2.0 + 0.12, 1.3, -0.2), bois)
	_box(Vector3(0.06, 2.6, 0.06), Vector3(-W / 2.0 + 0.12, 1.3, 1.2), bois)
	_label3d("Un esprit sain dans un corps qui gagne", Vector3(-W / 2.0 + 0.06, 2.9, 0.5), 30, Color(0.25, 0.35, 0.55), 90.0)


## Le four à bois au fond, les tables nappées, des habitués qui dînent.
func _restaurant() -> void:
	var brique := _std(Color(0.62, 0.3, 0.2), 0.85)
	_box(Vector3(1.8, 1.6, 1.0), Vector3(-W / 2.0 + 1.4, 0.8, -D / 2.0 + 0.6), brique, true)
	var feu := _std(Color(1.0, 0.5, 0.2), 0.5)
	feu.emission_enabled = true
	feu.emission = Color(1.0, 0.45, 0.15)
	feu.emission_energy_multiplier = 3.0
	_box(Vector3(0.7, 0.4, 0.05), Vector3(-W / 2.0 + 1.4, 0.75, -D / 2.0 + 1.11), feu)
	_lamp(Vector3(-W / 2.0 + 1.4, 0.8, -D / 2.0 + 1.6), Color(1.0, 0.55, 0.25), 1.2, 4.0)
	var nappe := _std(Color(0.95, 0.94, 0.9), 0.8)
	var seat := 41
	for p in [Vector3(-2.4, 0, 0.6), Vector3(0.0, 0, 1.4), Vector3(2.6, 0, 0.4), Vector3(-1.0, 0, 3.0)]:
		_cyl(0.55, 0.04, p + Vector3(0, 0.76, 0), nappe)
		_cyl(0.05, 0.74, p + Vector3(0, 0.37, 0), _std(Color(0.2, 0.15, 0.1), 0.5))
		_solid_box_at(Vector3(1.0, 0.8, 1.0), p + Vector3(0, 0.4, 0))
		_cyl(0.13, 0.02, p + Vector3(0.2, 0.79, 0.1), _std(Color(0.9, 0.62, 0.28), 0.6))
		_place(KK + "furniture/chair_A_wood.gltf", p + Vector3(-0.75, 0, 0), 0.8, 90.0)
		_place(KK + "furniture/chair_A_wood.gltf", p + Vector3(0.75, 0, 0), 0.8, -90.0)
		if seat < 44:
			_regular(p + Vector3(-0.6, 0, 0), 90.0, seat)
		seat += 1


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			_sortir()
		"keeper":
			say((_salle.lines as Array).pick_random())
			var c := _keeper.get_child(0)
			if c.has_method("gesture"):
				c.gesture("talk")
				c.talk(2.5)
			ouvrir_panneau()
		_:
			super(target)


func ouvrir_panneau() -> void:
	if _game != null:
		return
	var p := panneau(metier, options)
	p.spoke.connect(say)
	p.closed.connect(func():
		p.queue_free()
		_game = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_game = p


## La porte ramène dans la commune, devant la boutique.
func _sortir() -> void:
	Game.return_point = str(options.get("lot", ""))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var c: Commune = Communes.commune(str(options.get("commune", "smarves")))
	Chargement.changer(str(c.data.scene) if c else "res://scenes/main.tscn")


func _capture_prestation() -> void:
	var path := ""
	var ouvert := false
	var essais: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg == "--open":
			ouvert = true
		elif arg.begins_with("--essai="):
			# Des essais dans le panneau, pas encore payés : « sexe,peau,peau » avance chaque champ d'un cran.
			essais = arg.trim_prefix("--essai=").split(",")
		elif arg.begins_with("--avatar="):
			# Des retouches déjà faites, par leur code (Avatar.code).
			Biens.avatar = Avatar.decoder(arg.trim_prefix("--avatar="))
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
			if v.size() > 3:
				player.camera.rotation.x = deg_to_rad(v[3])
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ouvert:
		await get_tree().create_timer(1.0).timeout
		say((_salle.lines as Array)[0])
		ouvrir_panneau()
		for e in essais:
			if _game.has_method("essayer"):
				_game.essayer(e, 1)
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
