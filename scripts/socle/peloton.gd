class_name Peloton
extends Node3D
## Le direct d'une course cycliste dans la scène de sa commune (socle 1.28, autoload Cyclisme) : les coureurs
## sur leur vélo, posés à chaque instant où le résultat commun les met, le long du parcours que la course
## déclare (« parcours », les noms des repères de la scène, dans l'ordre). Vingt minutes avant le départ, ils
## s'alignent derrière la ligne ; pendant la course, ils roulent ; à l'arrivée, ils restent un moment sur la
## ligne, puis rentrent. Un bandeau en haut de l'écran dit ce que la scène ne montre pas de loin : le tour, la
## tête, l'écart.
##
## La commune le pose depuis sa scène, une fois : Peloton.poser(self, "<commune>", "<id de la course>"). Une
## scène dont les figurants ne sont pas à l'échelle 1 donne la sienne (echelle). Le parcours se mesure en
## unités de la scène (1 unité = 2,4 m à l'échelle 1) ; s'il s'écarte de plus d'un quart de la « distance »
## déclarée, un avertissement le dit, et les coureurs gardent la vitesse de la course.

const CRITTER := preload("res://scripts/critter.gd")
## Une unité de scène, en mètres, à l'échelle 1 des figurants (docs/COMMUNE.md, « Les autres joueurs »).
const METRES_PAR_UNITE := 2.4
## Les coureurs paraissent avant le départ, et restent après l'arrivée du dernier, en secondes.
const ECHAUFFEMENT := 20 * 60
const APRES := 5 * 60
## L'écart entre deux coureurs de front, et entre deux rangs à l'alignement, en mètres.
const DE_FRONT := 1.1
const RANG := 2.2
## Le dessus de la selle du vélo de course (Biens.DEUX_ROUES, « velo_course »), à l'échelle 1.
const SELLE := 0.24 * 0.72

var commune := ""
var course_id := ""
var echelle := 1.0
## La course (l'entrée du registre, Cyclisme.course).
var course: Dictionary = {}
var _points := PackedVector3Array()
var _cumul := PackedFloat32Array()
## La longueur du parcours, en mètres, et s'il revient au départ.
var _longueur := 0.0
var _boucle := false
var _coureurs := {}
var _depart := -1
var _bandeau: Label
var _couche: CanvasLayer
var _attente := 0.0
## L'horloge, en secondes locales ; un essai la remplace.
var horloge := Callable()


## Pose le peloton d'une course dans une scène ; null si la course n'existe pas ou si son parcours n'y est pas.
static func poser(scene: Node, id_commune: String, id: String, echelle_scene := 1.0) -> Peloton:
	var p := Peloton.new()
	p.name = "Peloton_%s" % id
	p.commune = id_commune
	p.course_id = id
	p.echelle = echelle_scene
	scene.add_child(p)
	if p.course.is_empty() or p._points.size() < 2:
		p.queue_free()
		return null
	return p


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	course = _cyclisme().course(commune, course_id)
	if course.is_empty():
		push_warning("Peloton : pas de course « %s » à %s" % [course_id, commune])
		return
	_tracer()
	_couche = CanvasLayer.new()
	_couche.layer = 6
	add_child(_couche)
	_bandeau = Label.new()
	_bandeau.name = "Bandeau"
	_bandeau.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bandeau.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_bandeau.position.y = 14
	_bandeau.add_theme_font_override("font", Polices.gras())
	_bandeau.add_theme_font_size_override("font_size", 18)
	_bandeau.add_theme_color_override("font_color", Color(0.96, 0.8, 0.45))
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.08, 0.1, 0.1, 0.82)
	fond.set_corner_radius_all(6)
	fond.set_content_margin_all(8)
	fond.content_margin_left = 18
	fond.content_margin_right = 18
	_bandeau.add_theme_stylebox_override("normal", fond)
	_bandeau.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bandeau.visible = false
	_couche.add_child(_bandeau)
	actualiser()


static func _cyclisme() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Cyclisme")


## Le parcours : les repères de la scène, dans l'ordre ; refermé sur le départ pour une course en plusieurs tours.
func _tracer() -> void:
	var racine: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not racine.is_ancestor_of(self) and racine != get_parent():
		racine = get_parent()
	for nom in course.get("champs", {}).get("parcours", []):
		var n := racine.find_child(str(nom), true, false) as Node3D
		if n == null:
			push_warning("Peloton : le repère « %s » du parcours n'est pas dans la scène" % nom)
			continue
		_points.append(n.global_position)
	_boucle = int(_cyclisme().champ(course, "tours")) > 1
	if _boucle and _points.size() > 2 and _points[0].distance_to(_points[-1]) > 0.01:
		_points.append(_points[0])
	_cumul.append(0.0)
	for i in range(1, _points.size()):
		_cumul.append(_cumul[-1] + _points[i - 1].distance_to(_points[i]) * METRES_PAR_UNITE / echelle)
	_longueur = _cumul[-1] if not _cumul.is_empty() else 0.0
	var declaree := float(_cyclisme().champ(course, "distance"))
	if _longueur > 0.0 and (_longueur / declaree < 0.75 or _longueur / declaree > 1.33):
		push_warning("Peloton : le parcours de « %s » mesure %d m dans la scène, la course en déclare %d" % [course.get("nom", course_id), int(_longueur), int(declaree)])


## La longueur du parcours dans la scène, en mètres.
func longueur() -> float:
	return _longueur


## Le point du parcours à s mètres du départ (dans un tour), et la direction de la route.
func point(s: float) -> Array:
	if _points.size() < 2:
		return [Vector3.ZERO, Vector3.FORWARD]
	s = clampf(s, 0.0, _longueur)
	var i := 1
	while i < _cumul.size() - 1 and _cumul[i] < s:
		i += 1
	var a := _points[i - 1]
	var b := _points[i]
	var k := (s - _cumul[i - 1]) / maxf(0.001, _cumul[i] - _cumul[i - 1])
	var dir := (b - a)
	dir.y = 0.0
	return [a.lerp(b, k), dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD]


func maintenant() -> float:
	if horloge.is_valid():
		return float(horloge.call())
	return float(_cyclisme().maintenant()) + fmod(Time.get_unix_time_from_system(), 1.0)


func _process(delta: float) -> void:
	_attente -= delta
	if _attente > 0.0 or course.is_empty():
		return
	_attente = 0.05
	actualiser()


## Pose les coureurs et écrit le bandeau pour l'instant présent.
func actualiser() -> void:
	var cy := _cyclisme()
	var t := maintenant()
	var depart: int = cy.edition(course, int(t))
	var fin: int = cy.fin(course, depart)
	var visible_ := t >= depart - ECHAUFFEMENT and t < fin + APRES
	if not visible_:
		for c in _coureurs.values():
			c.visible = false
		_bandeau.visible = false
		return
	if depart != _depart:
		_former(depart)
	var tours := int(cy.champ(course, "tours"))
	var declaree := float(cy.champ(course, "distance"))
	var res: Dictionary = cy.resultat(course, depart)
	for num in _coureurs:
		var c: Node3D = _coureurs[num]
		var rang := int(num) - 1
		var s: float
		var de_cote := (rang % 4 - 1.5) * DE_FRONT
		if t < depart:
			# L'alignement : par rangs de quatre derrière la ligne.
			s = -RANG * (rang / 4 + 1)
		else:
			var d: float = cy.position(course, depart, int(num), t)
			if d < 0.0:
				c.visible = false
				continue
			if d >= tours * declaree - 0.01:
				# Arrivé : sur la ligne, rangé dans l'ordre d'arrivée, un peu après.
				var place: int = res.ordre.find(int(num))
				s = _longueur + RANG * (1 + place / 4)
				de_cote = (place % 4 - 1.5) * DE_FRONT
			else:
				s = fmod(d / declaree, 1.0) * _longueur
		c.visible = true
		_placer(c, s, de_cote)
	_bandeau.visible = true
	_bandeau.text = bandeau(t, depart)


## Un point du parcours, prolongé avant le départ et après l'arrivée dans la direction de la route.
func _placer(c: Node3D, s: float, de_cote: float) -> void:
	var p: Array
	if s < 0.0:
		p = point(0.0)
		p[0] -= p[1] * (-s) / METRES_PAR_UNITE * echelle
	elif s > _longueur:
		p = point(_longueur)
		p[0] += p[1] * (s - _longueur) / METRES_PAR_UNITE * echelle
	else:
		p = point(s)
	var dir: Vector3 = p[1]
	var cote := dir.cross(Vector3.UP).normalized()
	c.global_position = p[0] + cote * de_cote / METRES_PAR_UNITE * echelle
	c.look_at(c.global_position + dir, Vector3.UP, true)


## Ce que dit le bandeau à l'instant t.
func bandeau(t: float, depart: int) -> String:
	var cy := _cyclisme()
	var nom := str(course.get("nom", "La course")).to_upper()
	if t < depart:
		var reste := int(depart - t)
		return "%s  ·  départ dans %d min  ·  %d coureurs alignés" % [nom, maxi(1, reste / 60), _coureurs.size()]
	var d: Dictionary = cy.en_direct(course, int(t))
	var par_num := {}
	for r in cy.engages(course, depart):
		par_num[int(r.num)] = r
	var tete: Dictionary = par_num.get(int(d.tete), {})
	if d.etat == "arrivee":
		return "%s  ·  arrivée  ·  vainqueur : n° %d %s" % [nom, int(d.tete), tete.get("nom", "")]
	var ecart := "  ·  le peloton à %d s" % int(d.ecart) if int(d.ecart) >= 3 else "  ·  peloton groupé"
	return "%s  ·  tour %d / %d  ·  en tête : n° %d %s%s" % [nom, int(d.tour), int(d.tours), int(d.tete), tete.get("nom", ""), ecart]


## Les coureurs d'une édition : chacun sur son vélo, le maillot à sa couleur.
func _former(depart: int) -> void:
	for c in _coureurs.values():
		c.queue_free()
	_coureurs = {}
	_depart = depart
	for r in _cyclisme().engages(course, depart):
		var c := coureur(str(r.maillot), Hasard.graine("%s/%s/%s" % [commune, course_id, r.nom]))
		c.name = "Coureur%d" % int(r.num)
		c.scale = Vector3.ONE * echelle
		c.visible = false
		add_child(c)
		_coureurs[int(r.num)] = c


## Un coureur sur son vélo de course, à l'échelle 1, qui regarde +Z : penché sur le guidon, il pédale.
static func coureur(maillot: String, graine: int) -> Node3D:
	var c := Node3D.new()
	var velo: Node3D = load("res://scripts/biens.gd")._deux_roues("velo_course")
	velo.scale = Vector3.ONE * 1.9
	c.add_child(velo)
	var homme: Node3D = CRITTER.new()
	homme.look = tenue(maillot, graine)
	homme.sit_anim = "velo"
	homme.pose = 2
	# Les hanches sur la selle, en arrière du pédalier, comme le joueur en selle (scripts/village/conduite.gd).
	homme.position = Vector3(0, SELLE * 1.9 - 0.09 * 0.55, -0.1)
	c.add_child(homme)
	return c


## La tenue d'un coureur : un jeune homme du village, maillot à la couleur de son dossard, cuissard noir et
## casquette de coton blanche.
static func tenue(maillot: String, graine: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var l: Dictionary = Cast._face(rng, false, false)
	l.merge({"build": {"belly": 0.86, "width": 0.94, "leg": 1.06}, "top": "pull", "top_color": maillot, "sleeves": "courtes",
		"legs": "short", "legs_color": "#16151b", "shoes": "#16151b", "hat": "casquette", "hat_color": "#f4f1ea"}, true)
	return l
