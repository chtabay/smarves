class_name Commerce
extends "res://scripts/village/salle.gd"
## Un commerce d'une commune, prêté par le socle : la structure « commerce » du manifeste (socle 1.4,
## docs/COMMUNE.md, « Les structures »). La commune nomme son commerçant et ses articles ; le socle
## construit la boutique, pose le commerçant derrière son comptoir, met les articles en vitrine et ouvre
## le bon de commande (scripts/shop_panel.gd), le même qu'au village. Trois genres, ceux de Smarves :
## « tenue » (on n'en porte qu'une, comme chez Raymonde), « vehicule » (on n'en conduit qu'un, comme au
## garage Fradin), « meuble » (il se pose chez soi, comme chez Ginette Boutin). Les articles entrent au
## catalogue de Biens sous « <commune>/<id> » et se financent à la banque de la commune.
## La commune ouvre son commerce depuis sa scène par Commerce.ouvrir("<commune>", "<id de la structure>").
## Capture : godot --path . res://scenes/commerce.tscn -- --commune=<id> --commerce=<id> --capture=sortie.png [--vitrine]

const PANNEAU := preload("res://scripts/shop_panel.gd")
const NOTAIRE := preload("res://scripts/socle/notaire.gd")
const REPLIQUES := ["« Faites le tour, tout est à vendre. Enfin, presque tout. »",
	"« Ce qui est en vitrine, je l'ai. Ce qui n'y est pas, je l'aurai. »",
	"« On paie comptant, ou la banque paie pour vous. Elle aime ça. »"]

## Ce que la prochaine boutique doit ouvrir (posé par ouvrir(), lu au _ready).
static var _prochaine: Array = []

var commune := ""
var structure: Dictionary = {}


## Ouvre le commerce « id » de la commune. Rend false sans rien faire si la structure n'existe pas.
static func ouvrir(id_commune: String, id: String) -> bool:
	if _entree(id_commune, id).is_empty():
		return false
	_prochaine = [id_commune, id]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(Engine.get_main_loop() as SceneTree).change_scene_to_file("res://scenes/commerce.tscn")
	return true


static func _entree(id_commune: String, id: String) -> Dictionary:
	var c: Commune = Communes.commune(id_commune)
	if c == null:
		return {}
	for s in Structures.nettoyer(c.data.get("structures")):
		if s.type == "commerce" and s.id == id:
			return s
	return {}


func _ready() -> void:
	shop = "commerce"
	if _prochaine.size() == 2:
		commune = _prochaine[0]
		structure = _entree(_prochaine[0], _prochaine[1])
		_prochaine = []
	var id := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--commune="):
			commune = arg.trim_prefix("--commune=")
		elif arg.begins_with("--commerce="):
			id = arg.trim_prefix("--commerce=")
	if id != "":
		# En capture, une commune en clair sous communes/ (le SDK, un clone) se greffe d'elle-même.
		if Communes.commune(commune) == null and FileAccess.file_exists("res://communes/%s/commune.json" % commune):
			Communes.charger_dossier("res://communes/" + commune)
		structure = _entree(commune, id)
	var tenancier := str(structure.get("tenancier", "Le commerçant"))
	var lignes: Array = structure.get("repliques", [])
	_salle = {"name": str(structure.get("nom", "La boutique")), "host": tenancier, "jeu": "E : voir la vitrine",
		"sortie": "E : sortir", "lines": lignes if not lignes.is_empty() else REPLIQUES}
	_serif = Polices.texte()
	var genre := str(structure.get("genre", "tenue"))
	W = 12.0 if genre == "vehicule" else 9.0
	D = 10.0 if genre == "vehicule" else 8.0
	H = 3.6
	_environment()
	match genre:
		"vehicule":
			_room(_flagstones(), _std(Color(0.86, 0.83, 0.74), 0.85), Color(0.78, 0.78, 0.75), Color(0.25, 0.35, 0.4))
		"meuble":
			_room(_wood_floor(Color(0.5, 0.36, 0.24)), _wallpaper(Color(0.66, 0.58, 0.4), Color(0.72, 0.64, 0.46)), Color(0.9, 0.86, 0.78), Color(0.3, 0.22, 0.15))
		_:
			_room(_wood_floor(Color(0.72, 0.56, 0.4)), _wallpaper(Color(0.78, 0.66, 0.7), Color(0.86, 0.76, 0.78)), Color(0.98, 0.95, 0.92))
	_comptoir(tenancier, int(structure.get("graine", 0)))
	_vitrine(genre)
	_label3d(str(structure.get("enseigne", _salle.name)), Vector3(0, H - 0.45, -D / 2.0 + 0.12), 72, Color(0.35, 0.18, 0.1))
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
	_capture_commerce()


## Le comptoir au fond, et le commerçant derrière : un habitant tiré de la graine de la structure.
func _comptoir(tenancier: String, graine: int) -> void:
	var bois := _std(Color(0.4, 0.26, 0.15), 0.55)
	var bz := -D / 2.0 + 1.8
	_box(Vector3(2.8, 0.9, 0.7), Vector3(0, 0.45, bz), bois, true)
	_box(Vector3(2.9, 0.05, 0.8), Vector3(0, 0.92, bz), _std(Color(0.28, 0.18, 0.1), 0.35))
	_keeper = Node3D.new()
	_keeper.position = Vector3(0, 0, -D / 2.0 + 0.9)
	add_child(_keeper)
	var f := CRITTER.new()
	f.randomize_look(graine)
	f.idle_anim = "stand_table"
	f.scale = Vector3.ONE * PEOPLE_SCALE
	_keeper.add_child(f)
	_interactive(_keeper, "keeper", "E : voir la vitrine de %s" % tenancier, Vector3(2.8, 2.2, 1.8), Vector3(0, 1.1, 0.9))
	_lamp(Vector3(0, 1.8, bz), Color(1.0, 0.85, 0.6), 1.0, 4.0)


## Les articles en vitrine, le long des murs : une silhouette à la couleur de chaque tenue, chaque véhicule
## à l'échelle de la pièce, chaque meuble posé (au mur pour un tableau). Six au plus ; le bon de commande
## a tout.
func _vitrine(genre: String) -> void:
	var c: Commune = Communes.commune(commune)
	var articles: Array = structure.get("articles", [])
	var n := mini(articles.size(), 6)
	for i in n:
		var it: Dictionary = Biens.item(NOTAIRE.cle(c, str(articles[i].id)))
		if it.is_empty():
			continue
		var gauche := i % 2 == 0
		var x := (-W / 2.0 + 1.4) if gauche else (W / 2.0 - 1.4)
		var z := -D / 2.0 + 3.2 + int(i / 2) * (2.6 if genre == "vehicule" else 1.6)
		var p := Vector3(x, 0, z)
		var objet: Node3D
		match genre:
			"vehicule":
				objet = Biens.build_vehicle(str(it.id))
				objet.scale = Vector3.ONE * 3.6
				objet.rotation_degrees.y = 90.0 if gauche else -90.0
			"meuble":
				objet = MEUBLES.build(str(it.id))
				if str(it.get("slot", "")) == "mur":
					p = Vector3((-W / 2.0 + 0.08) if gauche else (W / 2.0 - 0.08), 1.5, z)
					objet.rotation_degrees.y = 90.0 if gauche else -90.0
			_:
				objet = _silhouette(it.color)
		objet.position = p
		add_child(objet)
		var etiquette := Vector3(x + (1.0 if gauche else -1.0), 2.1, z + (1.4 if genre == "vehicule" else 0.0))
		_label3d("%s\n%s crédits" % [it.name, Game.fmt(int(it.price))], etiquette, 30, Color(0.15, 0.15, 0.2)).shaded = false


## Un mannequin de couturière : un pied, un buste à la couleur de la tenue.
func _silhouette(couleur: Color) -> Node3D:
	var n := Node3D.new()
	var bois := _std(Color(0.3, 0.2, 0.12), 0.5)
	var drap := _std(couleur, 0.85)
	var pied := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 1.0
	pied.mesh = cyl
	pied.material_override = bois
	pied.position.y = 0.5
	n.add_child(pied)
	var buste := MeshInstance3D.new()
	var b := CapsuleMesh.new()
	b.radius = 0.19
	b.height = 0.75
	buste.mesh = b
	buste.material_override = drap
	buste.position.y = 1.3
	n.add_child(buste)
	return n


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			_sortir()
		"keeper":
			say((_salle.lines as Array).pick_random())
			open_vitrine()
		_:
			super(target)


func open_vitrine() -> void:
	if _game != null:
		return
	var p: PanelContainer = PANNEAU.new()
	p.seller = "commerce"
	p.commune = commune
	p.boutique = str(structure.get("id", ""))
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


## La porte ramène dans la commune, devant la boutique (lot, sinon l'id de la structure).
func _sortir() -> void:
	Game.return_point = str(structure.get("lot", "")) if str(structure.get("lot", "")) != "" else str(structure.get("id", ""))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var c: Commune = Communes.commune(commune)
	Chargement.changer(str(c.data.scene) if c else "res://scenes/main.tscn")


func _capture_commerce() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if "--vitrine" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		open_vitrine()
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
