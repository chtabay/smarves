class_name Etude
extends "res://scripts/village/salle.gd"
## L'étude du notaire d'une commune, prêtée par le socle : le champ « notaire » du manifeste
## (docs/COMMUNE.md, « Le notaire »). La commune donne son notaire, son étude et son registre ; le socle
## construit la pièce, assoit le notaire derrière son bureau (un habitant tiré de « graine ») et ouvre le
## registre de la commune, le même plan qu'à Smarves (scripts/shop_panel.gd, carte_biens.gd). Ce qu'on y
## achète entre au catalogue de Biens sous « <commune>/<id> », et se finance à la banque de la commune.
## La commune ouvre son étude depuis sa scène par Etude.ouvrir("<commune>").
## Avec « notaire.modele » (socle 1.21), l'étude se pose sur un décor de la bibliothèque ou de la commune, branché
## par ses ancres (Ancres.ETUDE) : le socle n'y bâtit plus sa pièce.
## Capture : godot --path . res://scenes/etude.tscn -- --commune=<id> --capture=sortie.png [--registre-ouvert]

const PANNEAU := preload("res://scripts/shop_panel.gd")
const NOTAIRE := preload("res://scripts/socle/notaire.gd")
const REPLIQUES := ["« Un bien, c'est un placement qui a des murs. Le reste n'est que du jeu. »",
	"« Tout ce qui se vend ici est sur le plan. Ce qui n'y est pas ne se vend pas, ou pas encore. »",
	"« Signez où il y a une croix. Il y en a plusieurs, c'est normal. »"]

## La commune que la prochaine étude doit ouvrir (posée par ouvrir(), lue au _ready).
static var _prochaine := ""

var commune := ""
var notaire: Dictionary = {}


## Ouvre l'étude de la commune. Rend false sans rien faire si la commune n'est pas inscrite ou n'a pas
## de notaire.
static func ouvrir(id_commune: String) -> bool:
	var c: Commune = Communes.commune(id_commune)
	if c == null or not c.data.has("notaire"):
		return false
	_prochaine = id_commune
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Chargement.lieu("res://scenes/etude.tscn")
	return true


func _ready() -> void:
	shop = "etude"
	commune = _prochaine
	_prochaine = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--commune="):
			commune = arg.trim_prefix("--commune=")
	# En capture, une commune en clair sous communes/ (le SDK, un clone) se greffe d'elle-même.
	if Communes.commune(commune) == null and FileAccess.file_exists("res://communes/%s/commune.json" % commune):
		Communes.charger_dossier("res://communes/" + commune)
	var c: Commune = Communes.commune(commune)
	notaire = c.data.get("notaire", {}) if c else {}
	var e := NOTAIRE.etude(c)
	var lignes: Array = notaire.get("repliques", [])
	_salle = {"name": e.etude, "host": e.nom, "jeu": "E : consulter le registre", "sortie": "E : sortir",
		"lines": lignes if not lignes.is_empty() else REPLIQUES}
	_serif = Polices.texte()
	W = 8.0
	D = 7.0
	H = 3.2
	var modele := _charger_decor(str(notaire.get("modele", "")), "etude", "Étude")
	if modele:
		_brancher_decor(modele, c, e)
	else:
		_environment()
		_room(_wood_floor(Color(0.45, 0.3, 0.18)), _wallpaper(Color(0.42, 0.46, 0.38), Color(0.47, 0.5, 0.42)), Color(0.92, 0.9, 0.84), Color(0.3, 0.2, 0.12))
		_bureau(e.nom, int(notaire.get("graine", 0)))
		_label3d(e.etude, Vector3(0, H - 0.45, -D / 2.0 + 0.12), 64, Color(0.95, 0.88, 0.7)).shaded = false
		_bulb(Vector3(0, H - 0.7, 0.4), Color(0.95, 0.85, 0.6))
		_door()
	for a in find_children("*", "Area3D", true, false):
		if a.get_meta("interact", "") == "exit":
			a.set_meta("prompt", _salle.sortie)
	_build_ui()
	player = PLAYER.new()
	player.position = Vector3(0, 0, D / 2.0 - 1.2)
	var arrivee := Ancres.trouver(modele, "Arrivee") if modele else null
	if arrivee:
		player.position = arrivee.global_position
		player.rotation.y = arrivee.global_rotation.y + PI
	add_child(player)
	player.interact.connect(_on_interact)
	_capture_etude()


## Le bureau au fond, le registre ouvert dessus, et le notaire derrière.
func _bureau(nom: String, graine: int) -> void:
	var bois := _std(Color(0.32, 0.18, 0.09), 0.45)
	var bz := -D / 2.0 + 1.8
	_box(Vector3(2.4, 0.78, 1.0), Vector3(0, 0.39, bz), bois, true)
	_box(Vector3(0.7, 0.06, 0.5), Vector3(0.2, 0.81, bz), _std(Color(0.92, 0.88, 0.76), 0.9))
	_keeper = Node3D.new()
	_keeper.position = Vector3(0, 0, -D / 2.0 + 0.9)
	add_child(_keeper)
	var f := CRITTER.new()
	f.randomize_look(graine)
	f.idle_anim = "stand_table"
	f.scale = Vector3.ONE * PEOPLE_SCALE
	_keeper.add_child(f)
	_interactive(_keeper, "keeper", "E : consulter le registre de %s" % nom, Vector3(2.4, 2.2, 1.8), Vector3(0, 1.1, 0.9))
	_lamp(Vector3(-0.8, 1.2, bz), Color(1.0, 0.85, 0.55), 0.9, 3.0)


# --- Le décor d'une brique (socle 1.21) -------------------------------------------------------------

## L'étude sur le décor que nomme « modele » : le socle n'y bâtit rien, il branche ses ancres (Ancres.ETUDE). Le
## notaire à son bureau, le registre, l'enseigne, la plaque, le plan du registre et la sortie.
func _brancher_decor(m: Node3D, c: Commune, e: Dictionary) -> void:
	if m.find_children("*", "WorldEnvironment", true, false).is_empty():
		_environment()
	var ancre := Ancres.trouver(m, "Notaire")
	_keeper = _pied(ancre)
	var f := CRITTER.new()
	f.randomize_look(int(notaire.get("graine", 0)))
	f.scale = Vector3.ONE * PEOPLE_SCALE
	_keeper.add_child(f)
	if ancre.get_meta("assis", false):
		f.idle_anim = "sit_table"
		f.sit_anim = "sit_table"
		f.pose = 2
		# Le bassin sur l'assise d'un fauteuil (0,53 m), comme les figurants assis des communes.
		f.position.y = 0.53 - float(f.get("_seat")) * PEOPLE_SCALE + 0.04
	else:
		f.idle_anim = "stand_table"
	# Le bureau est entre le notaire et le visiteur : la zone le déborde de son côté.
	_interactive(_keeper, "keeper", "E : consulter le registre de %s" % e.nom, Vector3(2.4, 2.2, 1.6), Vector3(0, 1.1, 2.0))
	var r := Ancres.trouver(m, "Registre")
	if r:
		_interactive(_pied(r), "registre", "E : consulter le registre", Vector3(1.8, 2.0, 1.4), Vector3(0, 1.0, 0.6))
	for nom in ["Enseigne", "Plaque"]:
		var a := Ancres.trouver(m, nom)
		if a:
			_ecrire(a, e.etude if nom == "Enseigne" else e.nom, Color(0.95, 0.88, 0.7) if nom == "Enseigne" else Color(0.15, 0.23, 0.2))
	var p := Ancres.trouver(m, "Plan")
	if p:
		_plan(p, NOTAIRE.registre(c))
	_interactive(_pied(Ancres.trouver(m, "Sortie")), "exit", _salle.sortie, Vector3(2.0, 2.6, 1.6), Vector3(0, 1.2, 0))


## Un texte du socle sur une ancre, lisible depuis son +Z ; les métas de l'ancre « hauteur » et « largeur » (en
## mètres) le mesurent, « couleur » le teinte et « espace » l'écrit en capitales espacées.
func _ecrire(ancre: Node3D, texte: String, couleur: Color) -> void:
	# « espace » : en capitales espacées, comme une enseigne peinte sur un bandeau.
	if ancre.get_meta("espace", false):
		texte = " ".join(texte.to_upper().split(""))
	var l := _label3d(texte, Vector3.ZERO, 64, Color(ancre.get_meta("couleur", couleur)))
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


## Le premier quartier du registre dessiné sur un papier de 3,2 × 1,45 m centré sur l'ancre : les places et les
## jardins en aplats, les adresses en rouge, le nom du quartier en tête. Repris de l'étude de Cloué (MIT).
func _plan(ancre: Node3D, reg: Dictionary) -> void:
	if reg.get("quartiers", []).is_empty():
		return
	var q: Dictionary = reg.quartiers[0]
	var papier := Vector2(3.2, 1.45)
	var lin := _std(Color("c3b99e"), 0.85)
	var sauge := _std(Color("6b7963"), 0.85)
	var rouge := _std(Color("70463e"), 0.75)
	var vers := func(rect: Rect2) -> Array:
		var centre := rect.get_center()
		var taille := Vector2(rect.size.x / NOTAIRE.PAPIER.x * papier.x, rect.size.y / NOTAIRE.PAPIER.y * papier.y)
		return [Vector3((centre.x / NOTAIRE.PAPIER.x - 0.5) * papier.x, (0.5 - centre.y / NOTAIRE.PAPIER.y) * papier.y - 0.04, 0), taille]
	for d: Dictionary in q.get("decor", []):
		if str(d.get("forme", "")) == "rect":
			var v: Array = vers.call(d.rect)
			_box(Vector3(v[1].x, v[1].y, 0.009), v[0] + Vector3(0, 0, 0.005), sauge if str(d.get("teinte", "")) in ["jardin", "cour"] else lin, false, ancre)
	for a: Dictionary in reg.get("adresses", []):
		if str(a.get("quartier", "")) == str(q.get("id", "")):
			var v: Array = vers.call(a.rect)
			_box(Vector3(v[1].x, v[1].y, 0.012), v[0] + Vector3(0, 0, 0.012), rouge, false, ancre)
	var titre := _label3d(str(q.get("nom", "")).to_upper(), Vector3(0, papier.y / 2.0 + 0.1, 0.02), 40, Color("554c3b"))
	titre.shaded = false
	remove_child(titre)
	ancre.add_child(titre)


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			_sortir()
		"registre":
			open_registre()
		"keeper":
			say((_salle.lines as Array).pick_random())
			open_registre()
		_:
			super(target)


func open_registre() -> void:
	if _game != null:
		return
	var p: PanelContainer = PANNEAU.new()
	p.seller = "notaire"
	p.commune = commune
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


## La porte ramène dans la commune, devant l'étude (notaire.lot, sinon « notaire »).
func _sortir() -> void:
	Game.return_point = str(notaire.get("lot", "notaire"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var c: Commune = Communes.commune(commune)
	Chargement.changer(str(c.data.scene) if c else "res://scenes/main.tscn")


func _capture_etude() -> void:
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
	if "--registre-ouvert" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		open_registre()
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
