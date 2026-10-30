extends RefCounted
## Les bords de la route à vélo, de la ville au banc puis du banc au relais (relief/parcours.json, le plus court
## chemin sur les routes réelles) : des haies de bocage libres, par tronçons, et des arbres isolés ou en rideau,
## comme sur la route du pont de Lucey de la seconde planche. Hors du bourg seulement, qui a ses jardins.
##   BORDS.new(hauteur).batir(parent)

const HAIE := preload("res://communes/belley/atelier/haie_bocage.gd")
const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const FACADIER := preload("res://bibliotheque/facadier-du-bugey/1/facadier.gd")
const BOIS_POTEAU := Color("6b5844", 0.9)
const PIERRE_PONT := Color("c9b994", 0.0)
## Le pont du canal : le tronçon du parcours, en mètres depuis la ville, où l'eau borde la route (couverture.json).
const PONT := [3690.0, 3790.0]
## Les vignes de la descente vers le Rhône : [tronçon, abscisse, côté] des parcelles au bord du parcours.
## L'épingle des lacets de la montée au banc : [début, fin] en mètres depuis la ville, et le centre du virage.
const EPINGLE := [5630.0, 5760.0]
const CENTRE_EPINGLE := Vector2(2793.0, 1012.0)
const VIGNES := [[1, 560.0, 1.0], [1, 640.0, -1.0], [1, 1160.0, 1.0]]
## Les verts de la vigne fin septembre, qui tournent déjà au jaune par endroits.
const VERTS_VIGNE := ["b8b24e", "9cac44", "86983c", "6f8234", "5a6c2c"]
const REPEINDRE := preload("res://communes/belley/atelier/repeindre.gd")
const DONNEES := "res://communes/belley/relief/parcours.json"

const ESSENCES := ["platane", "marronnier", "jeune_platane"]
## Pas de haie ni d'arbre dans le bourg (jardins.gd), ni autour du banc et du relais (leurs scènes).
const LIBRES := [[Vector2(0, 0), 870.0], [Vector2(4200, 2160), 60.0], [Vector2(7180, 650), 170.0]]
const LOT := 500.0
const PORTEE := 1100.0

var hauteur: Callable
var lots := {}
## Les poteaux, le panneau et ce qui est posé au bord de la route, par lots comme les haies.
var objets := {}
var tablier := PackedVector2Array()
## Les ancres des parcelles de vigne : [point, direction, côté].
var ancres: Array = []
## Les points du parcours dans l'épingle des lacets, pour son muret.
var epingle := PackedVector2Array()


func _init(sol: Callable) -> void:
	hauteur = sol


func batir(parent: Node3D) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	var n := Node3D.new()
	n.name = "BordsDeRoute"
	parent.add_child(n)
	var ombriere: PackedScene = load(Bibliotheque.scene("arbres-d-ombriere@1", "decor"))
	var t := 0
	for tr in d.troncons:
		var p: Array = tr
		var pts := PackedVector2Array()
		for i in range(0, p.size(), 2):
			pts.append(Vector2(p[i], p[i + 1]))
		_longer(n, ombriere, pts, t)
		t += 1
	_sortie_de_ville(n)
	_pont()
	_muret_epingle()
	for an in ancres:
		_vigne(n, an[0], an[1], an[2])
	for cle in objets:
		var mo: MeshInstance3D = objets[cle].construire(n, "Bords")
		mo.visibility_range_end = PORTEE
		mo.visibility_range_end_margin = 100.0
	for cle in lots:
		var h: Node3D = lots[cle].construire(n, "Haies")
		for mi: MeshInstance3D in h.find_children("*", "MeshInstance3D", true, false):
			mi.visibility_range_end = PORTEE
			mi.visibility_range_end_margin = 100.0


func _libre(v: Vector2) -> bool:
	for l in LIBRES:
		if v.distance_to(l[0]) < l[1]:
			return false
	return true


## Le long d'un tronçon, tous les 12 m : un bout de haie d'un côté ou de l'autre selon un bruit lent (le bocage
## s'ouvre et se ferme), et tous les 130 m environ un arbre sur la haie (plus serrés, ils épuisaient les variables d'instance des
## feuillages, plafonnées à 4 096).
func _longer(n: Node3D, ombriere: PackedScene, pts: PackedVector2Array, t: int) -> void:
	var s := 0.0
	var prochain_arbre := 70.0
	var prochain_poteau := 15.0
	var prochaine_ferme := 600.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.5:
			continue
		var dir := (b - a) / seg
		var nrm := Vector2(-dir.y, dir.x)
		var u := fposmod(-s, 12.0)
		while u < seg:
			var c := a + dir * u
			var abs_s := s + u
			var h := absi(hash(Vector2i(int(abs_s), t)))
			for vg in VIGNES:
				if t == vg[0] and abs_s >= vg[1] and abs_s < vg[1] + 12.0:
					ancres.append([c, dir, vg[2]])
			if t == 0 and abs_s >= EPINGLE[0] and abs_s <= EPINGLE[1]:
				epingle.append(c)
			var sur_pont: bool = t == 0 and abs_s >= PONT[0] and abs_s <= PONT[1]
			if sur_pont:
				tablier.append(c)
			# Ni haie, ni arbre, ni poteau sur le pont et à ses abords.
			var abords: bool = t == 0 and abs_s >= PONT[0] - 15.0 and abs_s <= PONT[1] + 15.0
			# La ligne du téléphone, sur des poteaux de bois tous les 50 m, du côté droit.
			if abs_s > prochain_poteau and not abords:
				_poteau(c + nrm * 3.4)
				prochain_poteau = abs_s + 50.0
			# Une ferme tous les deux kilomètres environ, en retrait de la route.
			if abs_s > prochaine_ferme and _libre(c):
				var cf := -1.0 if h % 2 == 0 else 1.0
				var pf := c + nrm * cf * 22.0
				var mf: Node3D = FACADIER.maison(n, Vector3(pf.x, hauteur.call(pf.x, pf.y) - 0.2, pf.y), "r1" if h % 3 else "r2", h % 991, {"w": 12.0, "d": 8.0, "mur": "enduit", "enduit": ["d2be98", "cdb894", "d8c6a2"][h % 3], "couverture": "tuile_vieillie", "volets": "bois", "fleurs": false, "vigne": false})
				mf.rotation.y = atan2(-nrm.x * cf, -nrm.y * cf)
				for mi: GeometryInstance3D in mf.find_children("*", "GeometryInstance3D", true, false):
					mi.visibility_range_end = PORTEE
				prochaine_ferme = abs_s + 1700.0 + float(h % 800)
			if _libre(c) and not abords:
				for cote: float in [-1.0, 1.0]:
					# Chaque côté a sa haie par tronçons de 100 à 200 m, avec des trouées (les entrées de champ).
					if sin(abs_s * 0.011 + cote * 1.7 + t * 2.3) + sin(abs_s * 0.037 + cote) * 0.5 > 0.1:
						_haie(c + nrm * cote * (5.5 + float(h % 3) * 0.5), dir, h)
				if abs_s > prochain_arbre:
					var cote2 := 1.0 if h % 2 == 0 else -1.0
					var q := c + nrm * cote2 * (7.0 + float(h % 4))
					var m: Node3D = ombriere.instantiate()
					m.set("arbre", ESSENCES[h % ESSENCES.size()])
					m.set("graine", h % 9973)
					m.set("options", {"hauteur": 10.0 + float(h % 7), "densite": 0.6})
					m.position = Vector3(q.x, hauteur.call(q.x, q.y) - 0.1, q.y)
					m.rotation.y = float(h % 628) / 100.0
					n.add_child(m)
					REPEINDRE.feuillage(m)
					for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
						mi.visibility_range_end = PORTEE
						mi.visibility_range_end_margin = 100.0
					prochain_arbre = abs_s + 90.0 + float(h % 80)
			u += 12.0
		s += seg


## Un bout de haie de 12 m centré sur c, bout à bout avec ses voisins : la haie est continue.
func _haie(c: Vector2, dir: Vector2, graine: int) -> void:
	var cle := Vector2i(int(floor(c.x / LOT)), int(floor(c.y / LOT)))
	if not lots.has(cle):
		lots[cle] = HAIE.new(hauteur, cle.x * 37 + cle.y)
	lots[cle].troncon(c - dir * 6.0, c + dir * 6.0, graine)


func _objets(v: Vector2) -> RefCounted:
	var cle := Vector2i(int(floor(v.x / LOT)), int(floor(v.y / LOT)))
	if not objets.has(cle):
		objets[cle] = OUTILS.new(cle.x * 41 + cle.y)
	return objets[cle]


## Un poteau de bois de 7 m, sa traverse et ses deux isolateurs.
func _poteau(v: Vector2) -> void:
	var o: RefCounted = _objets(v)
	var y: float = hauteur.call(v.x, v.y)
	o.cylindre(Transform3D(Basis(), Vector3(v.x, y - 0.3, v.y)), 0.13, 0.1, 7.3, 6, BOIS_POTEAU, OUTILS.PEINT)
	o.boite(Transform3D(Basis(), Vector3(v.x, y + 6.6, v.y)), Vector3(0.9, 0.1, 0.1), BOIS_POTEAU, OUTILS.PEINT)
	for dx: float in [-0.35, 0.35]:
		o.cylindre(Transform3D(Basis(), Vector3(v.x + dx, y + 6.65, v.y)), 0.04, 0.03, 0.14, 6, Color("e6e2d8"), OUTILS.PEINT)


## La sortie de ville, au bout de la Grande Rue (le départ du parcours) : les deux dernières maisons de Belley
## et leurs murs de clôture, le trottoir qui s'arrête avec elles, puis le panneau d'entrée d'agglomération au nom
## de la ville, barré de rouge pour qui sort, sur ses deux poteaux (verdict n° 31).
func _sortie_de_ville(n: Node3D) -> void:
	var o: RefCounted = _objets(Vector2(98.0, 820.0))
	# Les deux maisons, de part et d'autre, pignon sur la route.
	for m: Array in [[Vector2(84.0, 806.0), "r2", 3, -1.0], [Vector2(113.0, 800.0), "r1", 4, 1.0]]:
		var pm: Vector2 = m[0]
		var mf: Node3D = FACADIER.maison(n, Vector3(pm.x, hauteur.call(pm.x, pm.y) - 0.2, pm.y), m[1], 801 + int(m[2]), {"w": 10.0, "d": 8.0, "mur": "enduit", "enduit": ["d2be98", "cdb894"][int(m[2]) % 2], "couverture": "tuile_vieillie", "volets": "bois", "fleurs": true, "vigne": int(m[2]) == 3})
		mf.rotation.y = PI * 0.5 * float(m[3])
	# Les murs de clôture des jardins, le long de la route, jusqu'au bout du trottoir ; un portail dans chacun.
	for cote: Array in [[93.6, -1.0], [103.4, 1.0]]:
		var x: float = cote[0]
		var z := 786.0
		while z < 820.0:
			if absf(z - 806.0) > 1.6:
				var v := Vector2(x, z + 1.0)
				var y: float = hauteur.call(v.x, v.y)
				o.boite(Transform3D(Basis(), Vector3(v.x, y + 0.6, v.y)), Vector3(0.45, 1.6, 2.02), Color("a99d80", 0.0))
				o.boite(Transform3D(Basis(), Vector3(v.x, y + 1.45, v.y)), Vector3(0.6, 0.1, 2.02), Color("b3a88f", 0.0))
			z += 2.0
		# Le trottoir, bordé, qui finit avec le mur.
		var x0: float = x - float(cote[1]) * 1.9
		o.quad(_sur(Vector2(x0, 786.0), 0.15), _sur(Vector2(x0, 820.0), 0.15), _sur(Vector2(x, 820.0), 0.15), _sur(Vector2(x, 786.0), 0.15), Vector3.UP, Color("a89c84", 0.95), OUTILS.PEINT)
		o.boite(Transform3D(Basis(), _sur(Vector2(x0, 803.0), 0.07)), Vector3(0.15, 0.2, 34.0), Color("c8bfae", 0.0))
	var v := Vector2(95.0, 838.0)
	var y: float = hauteur.call(v.x, v.y)
	for dx: float in [-0.45, 0.45]:
		o.cylindre(Transform3D(Basis(), Vector3(v.x + dx, y - 0.2, v.y)), 0.035, 0.035, 2.6, 6, Color("8a8d90"), OUTILS.PEINT)
	# Le panneau regarde qui sort de la ville, vers le nord.
	o.boite(Transform3D(Basis(), Vector3(v.x, y + 2.05, v.y)), Vector3(1.3, 0.55, 0.04), Color("b8322c"), OUTILS.PEINT)
	o.boite(Transform3D(Basis(), Vector3(v.x, y + 2.05, v.y - 0.025)), Vector3(1.2, 0.45, 0.02), Color("f3efe6"), OUTILS.PEINT)
	var nom := Label3D.new()
	nom.text = "BELLEY"
	nom.font_size = 64
	nom.pixel_size = 0.0045
	nom.modulate = Color("1c1c1c")
	nom.outline_size = 0
	nom.position = Vector3(v.x, y + 2.05, v.y - 0.04)
	nom.rotation.y = PI
	n.add_child(nom)
	# La barre rouge en travers.
	o.boite(Transform3D(Basis(Vector3.BACK, 0.32), Vector3(v.x, y + 2.05, v.y - 0.045)), Vector3(1.25, 0.05, 0.01), Color("b8322c"), OUTILS.PEINT)


## Le pont du canal : un tablier en dos d'âne qui monte à 4 m au-dessus de l'eau, porté par trois arches de
## pierre au milieu, ses parapets de pierre à 1 m, ses culées et l'enrochement des berges (verdict n° 31). La
## route drapée passe dessous, cachée.
func _pont() -> void:
	if tablier.size() < 2:
		return
	var o: RefCounted = _objets(tablier[0])
	var ya: float = hauteur.call(tablier[0].x, tablier[0].y)
	var yb: float = hauteur.call(tablier[-1].x, tablier[-1].y)
	# L'axe du pont, droit d'une rive à l'autre, échantillonné tous les 2 m.
	var a0 := tablier[0]
	var a1 := tablier[-1]
	var l := a0.distance_to(a1)
	var dir := (a1 - a0) / l
	var nrm := Vector2(-dir.y, dir.x)
	var bm := Basis(Vector3.UP, atan2(-dir.y, dir.x))
	var eau := minf(ya, yb) - 0.6
	var y_de := func(t: float) -> float: return lerpf(ya, yb, t / l) + 0.3 + 3.7 * pow(sin(PI * t / l), 0.6)
	var h := 2.7
	var pas := 2.0
	var t := 0.0
	while t < l - 0.01:
		var t1 := minf(t + pas, l)
		var p0 := a0 + dir * t
		var p1 := a0 + dir * t1
		var y0: float = y_de.call(t)
		var y1: float = y_de.call(t1)
		o.quad(Vector3(p0.x - nrm.x * h, y0, p0.y - nrm.y * h), Vector3(p1.x - nrm.x * h, y1, p1.y - nrm.y * h), Vector3(p1.x + nrm.x * h, y1, p1.y + nrm.y * h), Vector3(p0.x + nrm.x * h, y0, p0.y + nrm.y * h), Vector3.UP, Color("5a4f3e", 0.85), OUTILS.PEINT)
		var m := (p0 + p1) * 0.5
		var ym := (y0 + y1) * 0.5
		var pente := Basis(Vector3.UP, atan2(-dir.y, dir.x)) * Basis(Vector3.BACK, atan2(y1 - y0, t1 - t))
		for cote: float in [-1.0, 1.0]:
			var e := m + nrm * cote * (h + 0.3)
			# Le parapet de pierre, haut de 1 m au-dessus de la chaussée, et son chaperon.
			o.boite(Transform3D(pente, Vector3(e.x, ym + 0.5, e.y)), Vector3(t1 - t + 0.05, 1.0, 0.45), Color("a69c86", 0.0))
			o.boite(Transform3D(pente, Vector3(e.x, ym + 1.05, e.y)), Vector3(t1 - t + 0.05, 0.12, 0.58), Color("b7ad97", 0.0))
			# Le tympan : le mur plein sous le parapet, jusqu'à l'intrados des arches ou jusqu'à l'eau.
			var dessous := _intrados(t + pas * 0.5, l, eau)
			var hm := ym - dessous
			if hm > 0.1:
				o.boite(Transform3D(bm, Vector3(e.x, dessous + hm * 0.5, e.y)), Vector3(t1 - t + 0.02, hm, 0.5), Color("9c917b", 0.0))
		# La voûte sous le tablier, entre les deux tympans.
		var di := _intrados(t + pas * 0.5, l, eau)
		if di > eau + 0.2:
			o.quad(Vector3(p0.x + nrm.x * h, di, p0.y + nrm.y * h), Vector3(p1.x + nrm.x * h, di, p1.y + nrm.y * h), Vector3(p1.x - nrm.x * h, di, p1.y - nrm.y * h), Vector3(p0.x - nrm.x * h, di, p0.y - nrm.y * h), Vector3.DOWN, Color("6f675a", 0.0), OUTILS.PEINT)
		t = t1
	# Les culées et l'enrochement des berges, aux deux bouts.
	for bout: float in [0.0, 1.0]:
		var c := a0.lerp(a1, bout)
		var vers := dir * (1.0 if bout == 0.0 else -1.0)
		var yc: float = hauteur.call(c.x, c.y)
		o.boite(Transform3D(bm, Vector3(c.x + vers.x * 3.0, yc - 1.0, c.y + vers.y * 3.0)), Vector3(6.0, 3.5, 7.0), Color("9c917b", 0.0))
		for k in 14:
			var hk := absi(hash(Vector2i(k, int(bout * 7.0) + 3)))
			var off := nrm * (float(hk % 180) / 10.0 - 9.0) + vers * (5.0 + float((hk / 180) % 40) / 10.0)
			var pr := c + off
			var r := 0.5 + float(hk % 5) * 0.15
			o.boule(Vector3(pr.x, minf(hauteur.call(pr.x, pr.y), eau + 0.6) + r * 0.3, pr.y), Vector3(r, r * 0.6, r * 0.8), Color("8f8a7e").lightened(float(hk % 7) * 0.02), 0.3, OUTILS.PIERRE, 0.1, 0.0, 4, 6)


## La hauteur de l'intrados à t mètres du début du pont : trois arches en plein cintre surbaissé de 20 m au
## milieu, des piles entre elles ; ailleurs, le mur plein descend dans l'eau (les culées).
func _intrados(t: float, l: float, eau: float) -> float:
	var debut := l * 0.5 - 30.0
	var u := t - debut
	if u < 0.0 or u > 60.0:
		return eau
	var k := fposmod(u, 20.0)
	if k < 1.2 or k > 18.8:
		return eau
	var x := (k - 10.0) / 8.8
	return eau + 0.4 + 2.6 * sqrt(maxf(1.0 - x * x, 0.0))


## Une parcelle de vigne au bord de la route : des rangs palissés perpendiculaires à la route, tous les 2,2 m,
## sur 40 m de long, leur feuillage en cartes (une haie basse et étroite), un piquet de tête à chaque bout,
## et la terre nue entre les rangs.
func _vigne(n: Node3D, c: Vector2, dir: Vector2, cote: float) -> void:
	var nrm := Vector2(-dir.y, dir.x) * cote
	var feuilles := HAIE.new(hauteur, int(c.x) * 13 + int(c.y))
	var o: RefCounted = _objets(c)
	var k := -9
	while k <= 9:
		var base := c + dir * (float(k) * 2.2)
		var a := base + nrm * 7.0
		var b := base + nrm * 47.0
		feuilles.troncon_couleurs(a, b, VERTS_VIGNE, 1.25, 0.55)
		for v: Vector2 in [a, b]:
			o.cylindre(Transform3D(Basis(), Vector3(v.x, hauteur.call(v.x, v.y) - 0.2, v.y)), 0.06, 0.05, 1.8, 5, Color("8a7458", 0.9), OUTILS.PEINT)
		# La terre de l'interrang, griffée, sous le rang et de part et d'autre.
		var e := dir * 0.9
		var pas := 5.0
		var t := 0.0
		while t < 40.0:
			var p0 := a + nrm * t
			var p1 := a + nrm * minf(t + pas, 40.0)
			o.quad(_sur(p0 - e, 0.03), _sur(p1 - e, 0.03), _sur(p1 + e, 0.03), _sur(p0 + e, 0.03), Vector3.UP, Color("9a8662", 0.95), OUTILS.PEINT)
			t += pas
		k += 1
	var vn := feuilles.construire(n, "Vigne")
	for mi: MeshInstance3D in vn.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = PORTEE


func _sur(v: Vector2, dy: float) -> Vector3:
	return Vector3(v.x, hauteur.call(v.x, v.y) + dy, v.y)


## Le muret de pierre sèche à l'extérieur de l'épingle, côté vallée, avec son chaperon.
func _muret_epingle() -> void:
	if epingle.size() < 2:
		return
	var o: RefCounted = _objets(epingle[0])
	# Des points serrés le long du virage (ceux du parcours sont tous les 12 m).
	var pts := PackedVector2Array()
	for i in epingle.size() - 1:
		for k in 4:
			pts.append(epingle[i].lerp(epingle[i + 1], k / 4.0))
	pts.append(epingle[-1])
	for i in pts.size() - 1:
		var a := pts[i] + (pts[i] - CENTRE_EPINGLE).normalized() * 3.4
		var b := pts[i + 1] + (pts[i + 1] - CENTRE_EPINGLE).normalized() * 3.4
		var m := (a + b) * 0.5
		var y: float = hauteur.call(m.x, m.y)
		var bm := Basis(Vector3.UP, atan2(-(b - a).y, (b - a).x))
		o.boite(Transform3D(bm, Vector3(m.x, y + 0.35, m.y)), Vector3(a.distance_to(b) + 0.05, 0.9, 0.5), Color("a69c86", 0.0))
		o.boite(Transform3D(bm, Vector3(m.x, y + 0.84, m.y)), Vector3(a.distance_to(b) + 0.05, 0.1, 0.6), Color("b7ad97", 0.0))
