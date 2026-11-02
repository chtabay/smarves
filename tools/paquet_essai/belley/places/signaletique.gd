extends RefCounted
## Se repérer dans Belley (Guillaume, 31 octobre 2026 : « y a-t-il de quoi s'y retrouver et trouver la course ? »).
## Rien ne le disait : l'habitant arrive place de la Victoire, la place de la Cathédrale et l'arrivée du Grand Prix
## sont à 500 m au sud derrière les maisons, la route de la course part à 900 m, à la sortie sud, et monte 10 km
## jusqu'au banc d'Au Replat avant de redescendre 4 km jusqu'au Relais des Lônes.
##
## - le plan de la ville, à l'arrivée : le pays de Belley au Rhône, la route du Grand Prix, et la légende ;
## - les poteaux indicateurs du bourg, blancs, à chaque carrefour de la ville au départ de la route ;
## - le chevalet du Grand Prix, à l'entrée de la place de la Cathédrale, sous la banderole ;
## - les poteaux jaunes du Grand Prix, à chaque carrefour de la route (relief/carrefours.json, relevés par
##   tools/carrefours_parcours.py) : la course est balisée la veille, comme il se doit.
##
## Tout ce qui s'y lit est écrit (Label3D) : un joueur le lit en s'approchant, un pensionnaire aussi (le pilote lit
## les écrits à 25 m, scripts/socle/pilote.gd). Chaque lame dit sa direction en mots (« vers le sud »), puisque le
## pilote ne voit pas où pointe une flèche. Aucun jeu n'est touché ; rien n'arrête le pas (pas de collision).
##   SIGNALETIQUE.new(hauteur).batir(parent)

const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const CARREFOURS := "res://communes/belley/relief/carrefours.json"
const PARCOURS := "res://communes/belley/relief/parcours.json"

## Le plan, à 13 m devant l'habitant qui arrive (repère « Arrivee », belley.gd), sur le terre-plein au-delà de la
## chaussée du boulevard de Verdun, tourné vers lui.
const PLAN := Vector2(49.2, -10.8)
const ARRIVEE := Vector2(40.0, -20.0)
## Les poteaux du bourg, de l'arrivée à la sortie sud : [x, z, [[cap (degrés depuis le nord, vers l'est), lieu,
## mètres par la rue, rue], …]]. Plantés hors des chaussées et des maisons de bourg.json, au coin où on les voit en
## arrivant ; les distances suivent les rues.
const POTEAUX := [
	# Sur le terre-plein de la place des Terreaux, au bout du boulevard de Verdun.
	[12.0, 72.0, [
		[180.0, "Place de la Cathédrale", 370.0, "rue de la République"],
		[180.0, "Route du Grand Prix", 790.0, "rue de la République"],
		[17.0, "Place de la Victoire", 100.0, "boulevard de Verdun"]]],
	# Au coin de la rue des Barons, qui monte à la place de la Cathédrale.
	[12.0, 275.0, [
		[84.0, "Place de la Cathédrale", 160.0, "rue des Barons"],
		[181.0, "Route du Grand Prix", 580.0, "rue de la République"],
		[0.0, "Place de la Victoire", 320.0, "rue de la République"]]],
	# Au bout de la rue de la République.
	[4.8, 630.3, [
		[76.0, "Route du Grand Prix", 240.0, "rue du Bon Repos"],
		[0.0, "Place de la Cathédrale", 510.0, "rue de la République"]]],
	# Où la rue du Mont quitte la rue du Bon Repos.
	[100.0, 653.9, [
		[210.0, "Route du Grand Prix", 140.0, "rue du Mont"],
		[284.0, "Place de la Cathédrale", 600.0, "rue du Bon Repos"]]],
	# La fourche de la rue du Mont et de la rue Marcel-Duchamp.
	[71.1, 712.2, [
		[160.0, "Route du Grand Prix", 70.0, "rue Marcel-Duchamp"],
		[22.0, "Place de la Cathédrale", 670.0, "rue du Mont"]]],
]
## Le chevalet, sur le trottoir nord de la rue des Barons, où elle débouche sur la place (vie_place.gd, BARONS),
## hors du chemin des passants ; ses deux faces regardent la rue et la place.
const CHEVALET := Vector2(163.3, 310.8)
const CHEVALET_RUE := Vector2(0.912, 0.412)

const VENTS := ["le nord", "le nord-est", "l'est", "le sud-est", "le sud", "le sud-ouest", "l'ouest", "le nord-ouest"]
const POTEAU := Color("6e7276", 0.5)
const LAME_VILLE := Color("f1eee6", 0.7)
const ENCRE_VILLE := Color("1d2a3a")
const LAME_COURSE := Color("f2c600", 0.6)
const ENCRE_COURSE := Color("1e1e20")
const BOIS := Color("6b4a30", 0.8)
const ARDOISE := Color("2d3631", 0.9)
const CRAIE := Color("efe9da")
const CRAIE_ROUGE := Color("e0705a")
## Les écrits s'éteignent au-delà (on ne les lit pas de plus loin), les poteaux un peu après.
const ECRITS_PORTEE := 70.0
const POTEAUX_PORTEE := 260.0

## Le plan : le pays, de la ville au Rhône, à l'échelle de la carte, et ses couleurs.
const PAYS := Rect2(-200.0, -300.0, 7650.0, 2600.0)
const PLAN_CENTRE_Y := 1.86
const PAPIER := Color("ece5cf", 0.9)
const PRE := Color("cdd6ad", 0.9)
const BOURG := Color("d7b9a0", 0.9)
const ICI := Color("c8322c", 0.7)
const CATHEDRALE := Color("f6f3ea", 0.7)
const RUES := Color("e2852f", 0.7)
const ROUTE := Color("f2c600", 0.7)
const REPLAT := Color("4f8a3a", 0.7)
const RELAIS := Color("8a5a3a", 0.7)
const RHONE := Color("5e8db0", 0.7)

var hauteur: Callable


func _init(sol: Callable) -> void:
	hauteur = sol


func batir(parent: Node3D) -> void:
	var n := Node3D.new()
	n.name = "Signaletique"
	parent.add_child(n)
	_plan(n)
	for p: Array in POTEAUX:
		var lames := []
		for l: Array in p[2]:
			lames.append([l[0], "%s  %s\n%s, %s" % [l[1], distance(l[2]), vers(l[0]), l[3]]])
		_poteau(n, Vector2(p[0], p[1]), lames, LAME_VILLE, ENCRE_VILLE, "poteau indicateur")
	_chevalet(n)
	var d = JSON.parse_string(FileAccess.get_file_as_string(CARREFOURS))
	if d is Array:
		for p: Dictionary in d:
			var lames := []
			for l: Dictionary in p.lames:
				lames.append([float(l.cap), "Grand Prix de la Louve\n%s  %s\n%s" % [l.vers, distance(float(l.m)), vers(float(l.cap))]])
			_poteau(n, Vector2(float(p.x), float(p.z)), lames, LAME_COURSE, ENCRE_COURSE, "poteau du Grand Prix")


## « vers le sud », « vers l'est » : la rose à huit vents, le nord vers les z négatifs.
static func vers(cap: float) -> String:
	return "vers " + VENTS[int(round(fposmod(cap, 360.0) / 45.0)) % 8]


## « 70 m », « 0,6 km », « 10 km ».
static func distance(m: float) -> String:
	if m < 300.0:
		return "%d m" % int(snappedf(m, 10.0))
	if m >= 9950.0:
		return "%d km" % int(round(m / 1000.0))
	return ("%.1f km" % snappedf(m / 1000.0, 0.1)).replace(".", ",")


## La direction d'un cap dans le plan (x vers l'est, z vers le sud).
static func _dir(cap: float) -> Vector2:
	var a := deg_to_rad(cap)
	return Vector2(sin(a), -cos(a))


## Un écrit plat, d'un seul côté (le dos se lit par un second écrit tourné).
func _ecrit(parent: Node3D, texte: String, t: Transform3D, taille: int, pixel: float, encre: Color, largeur := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = texte
	l.font_size = taille
	l.pixel_size = pixel
	l.modulate = encre
	l.outline_size = 0
	l.double_sided = false
	l.transform = t
	l.visibility_range_end = ECRITS_PORTEE
	if largeur > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = largeur / pixel
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	parent.add_child(l)
	return l


## Un poteau et ses lames, de haut en bas : [cap, texte]. Chaque lame pointe vers son cap, sa pointe au bout ; le
## texte se lit des deux côtés, à une taille qui tient dans la lame.
func _poteau(parent: Node3D, at: Vector2, lames: Array, fond: Color, encre: Color, libelle: String) -> void:
	var n := Node3D.new()
	n.name = "Poteau"
	n.set_meta("libelle", libelle)
	n.position = Vector3(at.x, hauteur.call(at.x, at.y), at.y)
	parent.add_child(n)
	var o := OUTILS.new(hash(at))
	var y := 2.55
	for lame: Array in lames:
		var texte: String = lame[1]
		var lignes := texte.split("\n")
		var plus := 0
		for li in lignes:
			plus = maxi(plus, li.length())
		var long := 1.3 if lignes.size() < 3 else 1.45
		var taille := 40
		var pixel := minf(0.0034, long * 0.86 / (maxf(plus, 1.0) * taille * 0.56))
		var haut := maxf(0.2, lignes.size() * taille * pixel * 1.3 + 0.05)
		y -= haut * 0.5
		var b := Basis(Vector3.UP, deg_to_rad(90.0 - float(lame[0])))
		var c := b * Vector3(0.07 + long * 0.5, y, 0.0)
		o.boite(Transform3D(b, c), Vector3(long, haut, 0.03), fond, OUTILS.PEINT)
		# La pointe : un carré tourné d'un huitième de tour, à moitié dans la lame.
		var pointe := b * Basis(Vector3.BACK, PI * 0.25)
		o.boite(Transform3D(pointe, b * Vector3(0.07 + long, y, 0.0)), Vector3(haut * 0.7071, haut * 0.7071, 0.03), fond, OUTILS.PEINT)
		# Le liseré sombre en haut et en bas de la lame.
		for s: float in [-1.0, 1.0]:
			o.boite(Transform3D(b, c + Vector3(0, s * (haut * 0.5 - 0.012), 0)), Vector3(long, 0.016, 0.034), encre.lerp(fond, 0.35), OUTILS.PEINT)
		_ecrit(n, texte, Transform3D(b, c + b * Vector3(0, 0, 0.018)), taille, pixel, encre)
		_ecrit(n, texte, Transform3D(b * Basis(Vector3.UP, PI), c - b * Vector3(0, 0, 0.018)), taille, pixel, encre)
		y -= haut * 0.5 + 0.04
	o.cylindre(Transform3D(Basis(), Vector3(0, -0.4, 0)), 0.045, 0.04, 3.1, 8, POTEAU, OUTILS.PEINT)
	o.cylindre(Transform3D(Basis(), Vector3(0, 2.7, 0)), 0.055, 0.0, 0.08, 8, POTEAU, OUTILS.PEINT)
	var mi := o.construire(n, "Lames")
	mi.visibility_range_end = POTEAUX_PORTEE


## Le plan de la ville sur ses deux poteaux, sous un auvent : le pays en haut, la légende en dessous.
func _plan(parent: Node3D) -> void:
	var n := Node3D.new()
	n.name = "PlanDeLaVille"
	n.set_meta("libelle", "plan de la ville")
	n.position = Vector3(PLAN.x, hauteur.call(PLAN.x, PLAN.y), PLAN.y)
	# Sa face (+Z) regarde l'habitant qui arrive.
	var vers_arrivee := ARRIVEE - PLAN
	n.rotation.y = atan2(vers_arrivee.x, vers_arrivee.y)
	parent.add_child(n)
	var o := OUTILS.new(1037)
	for s: float in [-1.0, 1.0]:
		o.boite(Transform3D(Basis(), Vector3(s * 1.04, 1.0, 0)), Vector3(0.08, 2.6, 0.08), BOIS, OUTILS.PEINT)
	# Le panneau, son cadre et l'auvent.
	o.boite(Transform3D(Basis(), Vector3(0, 1.55, 0)), Vector3(2.0, 1.5, 0.04), PAPIER, OUTILS.PEINT)
	for v: float in [0.79, 2.31]:
		o.boite(Transform3D(Basis(), Vector3(0, v, 0.01)), Vector3(2.04, 0.04, 0.05), BOIS, OUTILS.PEINT)
	for s: float in [-1.0, 1.0]:
		o.boite(Transform3D(Basis(), Vector3(s * 1.0, 1.55, 0.01)), Vector3(0.04, 1.56, 0.05), BOIS, OUTILS.PEINT)
	o.boite(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 2.36, 0.08)), Vector3(2.3, 0.04, 0.36), BOIS.darkened(0.2), OUTILS.PEINT)
	# Le pays, de la ville au Rhône, le nord en haut ; chaque couche un peu devant la précédente (la face du
	# panneau est à 0,02).
	o.boite(Transform3D(Basis(), Vector3(0, PLAN_CENTRE_Y, 0.024)), Vector3(1.82, PAYS.size.y * _echelle() + 0.02, 0.002), PRE, OUTILS.PEINT)
	# Le Rhône, au nord-est du relais, du nord vers le sud-est.
	_trait(o, [_au_plan(6700.0, -280.0), _au_plan(7230.0, 520.0), _au_plan(7440.0, 900.0)], 0.014, RHONE)
	# La ville : la tache de ses toits, puis ses rues jusqu'au départ.
	var b0 := _au_plan(-150.0, -120.0)
	var b1 := _au_plan(320.0, 850.0)
	o.boite(Transform3D(Basis(), (b0 + b1) * 0.5), Vector3(absf(b1.x - b0.x), absf(b1.y - b0.y), 0.002), BOURG, OUTILS.PEINT)
	var rues := [Vector2(40, -20), Vector2(27, 43), Vector2(12, 82), Vector2(8, 279), Vector2(6, 626), Vector2(99, 650), Vector2(74, 713), Vector2(96, 798)]
	var pts := []
	for r: Vector2 in rues:
		pts.append(_au_plan(r.x, r.y, 0.003))
	_trait(o, pts, 0.006, RUES)
	_trait(o, [_au_plan(8.0, 279.0, 0.003), _au_plan(182.0, 329.0, 0.003)], 0.006, RUES)
	# La route du Grand Prix, un point tous les 100 m.
	var par = JSON.parse_string(FileAccess.get_file_as_string(PARCOURS))
	if par is Dictionary:
		for t: Array in par.troncons:
			var ligne := []
			var dernier := Vector2(INF, INF)
			for i in range(0, t.size(), 2):
				var p := Vector2(float(t[i]), float(t[i + 1]))
				if p.distance_to(dernier) >= 100.0 or i >= t.size() - 2:
					ligne.append(_au_plan(p.x, p.y, 0.005))
					dernier = p
			_trait(o, ligne, 0.012, ROUTE)
	# Les lieux : la même couleur que leur pastille dans la légende.
	_pastille(o, _au_plan(40.0, -20.0, 0.008), 0.032, ICI)
	_pastille(o, _au_plan(182.0, 329.0, 0.008), 0.026, CATHEDRALE)
	_pastille(o, _au_plan(4200.0, 2160.0, 0.008), 0.04, REPLAT, true)
	_pastille(o, _au_plan(7150.0, 640.0, 0.008), 0.036, RELAIS)
	# La flèche du nord, en haut à droite.
	var nord := Vector3(0.84, 2.08, 0.036)
	o.tri(nord + Vector3(0, 0.05, 0), nord + Vector3(-0.025, -0.04, 0), nord + Vector3(0.025, -0.04, 0), Vector3.BACK, ENCRE_VILLE, OUTILS.PEINT)
	var mi := o.construire(n, "Panneau")
	mi.visibility_range_end = POTEAUX_PORTEE
	_ecrit(n, "BELLEY · PLAN DE LA VILLE", Transform3D(Basis(), Vector3(0, 2.22, 0.03)), 48, 0.0018, ENCRE_VILLE)
	# La légende, en deux colonnes : la pastille, puis le texte (un écrit par lieu, moins de 240 signes : le pilote
	# n'en lit pas plus d'un coup).
	var legende := [
		[ICI, "Vous êtes ici : place de la Victoire. La Mobylette bleue garée à côté mène plus vite au bout des routes."],
		[CATHEDRALE, "Place de la Cathédrale, arrivée du Grand Prix de la Louve : 0,5 km au sud, par le boulevard de Verdun et la rue de la République, puis à gauche la rue des Barons."],
		[RUES, "Route du Grand Prix : départ à la sortie sud de la ville, à 0,9 km, au bout de la rue de la République, puis par les rues du Bon Repos, du Mont et Marcel-Duchamp."],
		[ROUTE, "Sur la route, un poteau jaune du Grand Prix à chaque carrefour montre le chemin."],
		[REPLAT, "Au Replat, le banc face à la Dent du Chat, sur la Montagne de Parves : 11 km par la route du Grand Prix, au sud-est."],
		[RELAIS, "Relais des Lônes, au bord du Rhône : 15 km, au bout de la route du Grand Prix, à l'est."],
	]
	var o2 := OUTILS.new(1038)
	for i in legende.size():
		var colonne := -0.94 if i < 3 else 0.06
		var v := 1.46 - (i % 3) * 0.2
		_pastille(o2, Vector3(colonne + 0.02, v - 0.018, 0.025), 0.026, legende[i][0])
		# Aligné à gauche, l'écrit part de son origine.
		_ecrit(n, legende[i][1], Transform3D(Basis(), Vector3(colonne + 0.06, v, 0.03)), 26, 0.0011, ENCRE_VILLE, 0.82)
	var pastilles := o2.construire(n, "Pastilles")
	pastilles.visibility_range_end = POTEAUX_PORTEE


func _echelle() -> float:
	return 1.8 / PAYS.size.x


## Un point du pays sur le plan (repère du panneau, sa face vers +Z), devant le pré de dz.
func _au_plan(x: float, z: float, dz := 0.0) -> Vector3:
	var c := PAYS.get_center()
	return Vector3((x - c.x) * _echelle(), PLAN_CENTRE_Y - (z - c.y) * _echelle(), 0.027 + dz)


## Un trait de couleur posé sur le plan, de point en point (largeur en mètres).
func _trait(o: OUTILS, pts: Array, large: float, col: Color) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var l := Vector2(b.x - a.x, b.y - a.y).length()
		if l < 0.0005:
			continue
		var t := Transform3D(Basis(Vector3.BACK, atan2(b.y - a.y, b.x - a.x)), (a + b) * 0.5)
		o.boite(t, Vector3(l + large, large, 0.002), col, OUTILS.PEINT)


## Une pastille carrée (ou en losange) posée sur le plan, bordée de sombre.
func _pastille(o: OUTILS, at: Vector3, cote: float, col: Color, losange := false) -> void:
	var b := Basis(Vector3.BACK, PI * 0.25) if losange else Basis()
	o.boite(Transform3D(b, at - Vector3(0, 0, 0.001)), Vector3(cote + 0.008, cote + 0.008, 0.003), ENCRE_VILLE, OUTILS.PEINT)
	o.boite(Transform3D(b, at), Vector3(cote, cote, 0.004), col, OUTILS.PEINT)


## Le chevalet du Grand Prix : une ardoise à deux faces sur ses pieds de bois, écrite à la craie des deux côtés.
func _chevalet(parent: Node3D) -> void:
	var n := Node3D.new()
	n.name = "Chevalet"
	n.set_meta("libelle", "chevalet du Grand Prix")
	n.position = Vector3(CHEVALET.x, hauteur.call(CHEVALET.x, CHEVALET.y), CHEVALET.y)
	# Une face (+Z) regarde qui monte la rue des Barons, l'autre la place.
	n.rotation.y = atan2(-CHEVALET_RUE.x, -CHEVALET_RUE.y)
	parent.add_child(n)
	var o := OUTILS.new(1039)
	var titre := "GRAND PRIX DE LA LOUVE"
	var texte := "Dimanche, arrivée ici, sur la place.\nLa route de la course part de la sortie sud, à 0,6 km : rue des Barons vers l'ouest, puis rue de la République vers le sud.\nAu Replat 11 km, Relais des Lônes 15 km : suivre les poteaux jaunes."
	for s: float in [1.0, -1.0]:
		# Chaque face penche de 12° : les deux se rejoignent en haut.
		var b := Basis(Vector3.UP, 0.0 if s > 0.0 else PI) * Basis(Vector3.RIGHT, -0.21)
		var pied := Vector3(0, 0, s * 0.24)
		o.boite(Transform3D(b, pied + b * Vector3(0, 0.62, 0)), Vector3(0.74, 1.2, 0.03), BOIS, OUTILS.PEINT)
		o.boite(Transform3D(b, pied + b * Vector3(0, 0.66, 0.017)), Vector3(0.64, 0.98, 0.006), ARDOISE, OUTILS.PEINT)
		_ecrit(n, titre, Transform3D(b, pied + b * Vector3(0, 1.08, 0.022)), 40, 0.0011, CRAIE_ROUGE)
		# Aligné à gauche, l'écrit part de son origine : du bord gauche de l'ardoise.
		_ecrit(n, texte, Transform3D(b, pied + b * Vector3(-0.29, 1.0, 0.022)), 30, 0.00105, CRAIE, 0.58)
	var mi := o.construire(n, "Ardoise")
	mi.visibility_range_end = POTEAUX_PORTEE
