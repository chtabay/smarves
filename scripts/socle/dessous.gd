extends CanvasLayer
## Le Dessous, le niveau secret sous toutes les cartes (autoload « Dessous », socle 1.32 ; Guillaume,
## 2 novembre 2026 : « quand un joueur tombe sous la map très bas en dessous, il existe un monde »).
## Les jointures des cartes laissent parfois passer l'habitant à travers le sol : au lieu de tomber sans
## fin, il arrive au Dessous (scenes/dessous.tscn, scripts/socle/dessous_monde.gd), le même monde sous
## toutes les communes : un disque posé sur le dos de quatre éléphants, eux-mêmes debout sur la carapace
## d'Akoupara, la tortue qui nage dans les étoiles, avec sa Lanterne, le petit soleil qui en fait le tour.
## La Porte des Joints, sur le disque, le ramène là où il est tombé, sur le dernier sol ferme.
##
## Le paquet d'une commune n'a rien à coder : le socle suit le corps qu'on dirige (`player` de la scène,
## sinon le groupe « player » de scripts/fp_player.gd), retient où il a eu les pieds sur un sol, et quand il
## tombe très loin sous ce sol (PROFONDEUR fois sa taille, au moins PROFONDEUR_MIN), il passe au Dessous.
## La scène quittée est gardée (Chargement.garder) : au retour, elle reprend telle qu'on l'a laissée.
## Une scène qui a de vrais précipices (un puits de mine, une falaise) peut s'en retirer : la méta
## « sans_dessous » sur sa racine, ou `var dessous := false`.

const SCENE := "res://scenes/dessous.tscn"
## Sous le dernier sol touché, en tailles d'habitant : un homme de 1,70 m passe au bout de 60 m de chute,
## un petit Smarvois de 0,7 au bout de PROFONDEUR_MIN (25 unités, deux secondes et quelque).
const PROFONDEUR := 35.0
const PROFONDEUR_MIN := 25.0
## Les images de chute d'affilée sous le seuil avant de passer : un habitant qu'on déplace d'un coup plus
## bas (un test, une capture, un voyage) retrouve un sol tout de suite et ne passe pas.
const IMAGES_DE_CHUTE := 12
## Le sol ferme se relève toutes les DEMI secondes ; au retour, on reprend l'avant-dernier relevé, pris au
## moins une demi-seconde avant la chute, loin du bord du trou par où l'on est passé.
const DEMI := 0.5
const NUIT := Color(0.02, 0.02, 0.05)
const OR := Color(0.96, 0.8, 0.45)

## Le passage est-il permis (les outils de mesure peuvent le couper) ?
var permis := true
## D'où l'on est tombé : chemin de la scène, corps, sol ferme, nom du lieu, musique, coin des communes.
## Vide quand on n'est pas au Dessous.
var origine := {}
## Combien de fois on est passé au Dessous dans cette partie (pour les contenus à venir).
var passages := 0

var _scene: Node = null
var _corps: CharacterBody3D = null
var _ref_y := INF
var _sol_recent := Transform3D()
var _sol_ancien := Transform3D()
var _a_un_sol := false
var _horloge := 0.0
var _chute := 0
var _en_cours := false

var _voile: ColorRect
var _texte: Label


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_voile = ColorRect.new()
	_voile.color = NUIT
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_voile)
	_texte = Label.new()
	_texte.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texte.add_theme_font_size_override("font_size", 26)
	_texte.add_theme_color_override("font_color", OR)
	var police := Polices.titre()
	if police:
		_texte.add_theme_font_override("font", police)
	_voile.add_child(_texte)


## Est-on au Dessous ?
func au_dessous() -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path == SCENE


func _physics_process(delta: float) -> void:
	if _en_cours or not permis:
		return
	var tree := get_tree()
	var s := tree.current_scene
	if s != _scene:
		_scene = s
		_oublier()
	if s == null or not s is Node3D or s.scene_file_path == SCENE or tree.paused:
		return
	if s.has_meta("sans_dessous") or s.get("dessous") == false:
		return
	if Chargement.actif():
		return
	var ch = s.get("chargement")
	if ch is float and ch < 1.0:
		return
	var p := corps(s)
	if p == null:
		return
	if p != _corps:
		_corps = p
		_oublier()
		_corps = p
	if not _a_un_sol and _ref_y == INF:
		# Jamais posé encore (une arrivée au-dessus d'un trou) : on part d'où il est apparu.
		_ref_y = p.global_position.y
		_sol_recent = p.global_transform
		_sol_ancien = p.global_transform
	if p.is_on_floor():
		_ref_y = p.global_position.y
		_horloge += delta
		if not _a_un_sol or _horloge >= DEMI:
			_horloge = 0.0
			_sol_ancien = _sol_recent if _a_un_sol else p.global_transform
			_sol_recent = p.global_transform
			_a_un_sol = true
		_chute = 0
		return
	var taille := float(p.get("body_height")) if p.get("body_height") != null else 1.7
	if p.global_position.y < _ref_y - maxf(PROFONDEUR_MIN, PROFONDEUR * taille) and p.velocity.y < 0.0:
		_chute += 1
		if _chute >= IMAGES_DE_CHUTE:
			tomber()
	else:
		_chute = 0


func _oublier() -> void:
	_corps = null
	_ref_y = INF
	_a_un_sol = false
	_horloge = 0.0
	_chute = 0


## Le corps qu'on dirige dans la scène `s` : son `player`, sinon le premier du groupe « player » sous elle.
func corps(s: Node) -> CharacterBody3D:
	var p = s.get("player")
	if p is CharacterBody3D and is_instance_valid(p) and p.is_inside_tree():
		return p
	for n in get_tree().get_nodes_in_group("player"):
		if n is CharacterBody3D and s.is_ancestor_of(n):
			return n
	return null


## Le sol ferme où l'on reviendra (voir DEMI).
func sol_ferme() -> Transform3D:
	return _sol_ancien if _a_un_sol else _sol_recent


## Le nom du lieu d'où l'on vient, pour les textes du Dessous.
func nom_du_lieu(chemin: String) -> String:
	if chemin.begins_with("res://communes/"):
		var c: Commune = Communes.commune(chemin.trim_prefix("res://communes/").get_slice("/", 0))
		if c != null:
			return c.nom
	if chemin == "res://scenes/casino.tscn":
		return "Casino de Smarves"
	var o: Commune = Communes.origine()
	return o.nom if o != null else "Smarves"


## Passe au Dessous depuis la scène en cours : l'habitant tombé est remis sur son sol ferme, la scène est
## gardée telle quelle, et le Dessous se charge derrière un voile.
func tomber() -> void:
	var tree := get_tree()
	var s := tree.current_scene
	if _en_cours or s == null or s.scene_file_path == SCENE:
		return
	_en_cours = true
	var p := corps(s)
	var xf := sol_ferme()
	passages += 1
	var coin = Communes.get("_retour")
	origine = {"chemin": s.scene_file_path, "corps": p, "sol": xf, "lieu": nom_du_lieu(s.scene_file_path),
		"musique": str(Sfx.get("musique_courante")), "coin": coin != null and coin.visible,
		"gele": p != null and p.get("frozen") == true}
	print("[dessous] chute sous %s (y = %.1f) : passage n° %d" % [s.scene_file_path, p.global_position.y if p else 0.0, passages])
	if p != null:
		p.velocity = Vector3.ZERO
		if "frozen" in p:
			p.frozen = true
	await _voiler(1.0, 0.8, "Le sol cède…\nvous tombez à travers %s." % origine.lieu)
	if p != null and is_instance_valid(p):
		p.global_transform = xf
		p.velocity = Vector3.ZERO
		if "frozen" in p:
			p.frozen = origine.gele
	if origine.coin:
		Communes._bouton_retour(false)
	if s.scene_file_path != "":
		Chargement.garder()
	tree.change_scene_to_file(SCENE)
	await tree.process_frame
	await tree.process_frame
	_scene = tree.current_scene
	_oublier()
	await _voiler(0.0, 0.6)
	_en_cours = false


## Remonte par la Porte des Joints là où l'on est tombé, sur le sol ferme ; à Smarves si l'on est arrivé au
## Dessous autrement (une capture, un test).
func remonter() -> void:
	if _en_cours:
		return
	_en_cours = true
	var tree := get_tree()
	var o := origine
	var chemin := str(o.get("chemin", ""))
	if chemin == "":
		var c: Commune = Communes.origine()
		chemin = str(c.data.scene) if c != null else "res://scenes/main.tscn"
	await _voiler(1.0, 0.7, "Vous remontez vers %s…" % str(o.get("lieu", nom_du_lieu(chemin))))
	Chargement.changer(chemin)
	await tree.process_frame
	await tree.process_frame
	# Une commune en paquet qui n'a pas pu être gardée se rebâtit derrière l'écran de chargement.
	while Chargement.actif():
		await tree.process_frame
	var p = o.get("corps")
	if p is CharacterBody3D and is_instance_valid(p) and p.is_inside_tree() and tree.current_scene != null \
			and tree.current_scene.is_ancestor_of(p):
		p.global_transform = o.sol
		p.velocity = Vector3.ZERO
		if "frozen" in p:
			p.frozen = o.gele
	if o.get("coin", false) and Communes.get("actuelle_apres") != "":
		Communes._bouton_retour(true)
	var m := str(o.get("musique", ""))
	if m != "":
		Sfx.musique(m)
	origine = {}
	_scene = tree.current_scene
	_oublier()
	await _voiler(0.0, 0.6)
	_en_cours = false


func _voiler(alpha: float, duree: float, texte := "") -> void:
	if alpha > 0.0:
		_texte.text = texte
		_voile.modulate.a = 0.0 if not visible else _voile.modulate.a
		visible = true
	var tw := create_tween()
	tw.tween_property(_voile, "modulate:a", alpha, duree)
	if alpha > 0.0:
		tw.tween_interval(0.5)
	await tw.finished
	if alpha <= 0.0:
		visible = false
