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
const REPEINDRE := preload("res://communes/belley/atelier/repeindre.gd")
const DONNEES := "res://communes/belley/relief/parcours.json"

const ESSENCES := ["platane", "marronnier", "jeune_platane"]
## Pas de haie ni d'arbre dans le bourg (jardins.gd), ni autour du banc et du relais (leurs scènes).
const LIBRES := [[Vector2(0, 0), 750.0], [Vector2(4200, 2160), 60.0], [Vector2(7180, 650), 170.0]]
const LOT := 500.0
const PORTEE := 1100.0

var hauteur: Callable
var lots := {}
## Les poteaux, le panneau et ce qui est posé au bord de la route, par lots comme les haies.
var objets := {}
var tablier := PackedVector2Array()


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


## La sortie de ville, au bout de la Grande Rue (le départ du parcours) : le panneau d'entrée d'agglomération au
## nom de la ville, barré de rouge pour qui sort, sur ses deux poteaux.
func _sortie_de_ville(n: Node3D) -> void:
	var v := Vector2(91.5, 838.0)
	var y: float = hauteur.call(v.x, v.y)
	var o: RefCounted = _objets(v)
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


## Le pont du canal, sur le tablier relevé au fil du parcours : un tablier droit d'une rive à l'autre, ses
## parapets de pierre, ses piles. La route drapée passe dessous, cachée.
func _pont() -> void:
	if tablier.size() < 2:
		return
	var o: RefCounted = _objets(tablier[0])
	var ya: float = hauteur.call(tablier[0].x, tablier[0].y)
	var yb: float = hauteur.call(tablier[-1].x, tablier[-1].y)
	var l := 0.0
	for i in tablier.size() - 1:
		l += tablier[i].distance_to(tablier[i + 1])
	var s := 0.0
	for i in tablier.size() - 1:
		var a := tablier[i]
		var b := tablier[i + 1]
		var seg := a.distance_to(b)
		var dir := (b - a) / seg
		var nrm := Vector2(-dir.y, dir.x)
		var y0 := lerpf(ya, yb, s / l) + 0.45 + 0.6 * sin(PI * s / l)
		var y1 := lerpf(ya, yb, (s + seg) / l) + 0.45 + 0.6 * sin(PI * (s + seg) / l)
		var h := 2.7
		var q := func(v: Vector2, y: float) -> Vector3: return Vector3(v.x, y, v.y)
		# Le tablier : la chaussée, et sa tranche de pierre.
		o.quad(q.call(a - nrm * h, y0), q.call(b - nrm * h, y1), q.call(b + nrm * h, y1), q.call(a + nrm * h, y0), Vector3.UP, Color("5a4f3e", 0.85), OUTILS.PEINT)
		for cote: float in [-1.0, 1.0]:
			var e := nrm * cote * (h + 0.25)
			o.quad(q.call(a + nrm * cote * h, y0 - 1.1), q.call(b + nrm * cote * h, y1 - 1.1), q.call(b + nrm * cote * h, y1), q.call(a + nrm * cote * h, y0), Vector3(nrm.x * cote, 0, nrm.y * cote), PIERRE_PONT, OUTILS.PIERRE)
			# Le parapet : un muret de 0,5 m d'épaisseur, haut de 0,9 m, son chaperon plus clair.
			var m := (a + b) * 0.5 + e
			var bas := (y0 + y1) * 0.5
			var bm := Basis(Vector3.UP, atan2(-dir.y, dir.x))
			o.boite(Transform3D(bm, Vector3(m.x, bas + 0.45, m.y)), Vector3(seg + 0.02, 0.9, 0.5), PIERRE_PONT)
			o.boite(Transform3D(bm, Vector3(m.x, bas + 0.95, m.y)), Vector3(seg + 0.02, 0.1, 0.62), Color("ddd1b4", 0.0))
		s += seg
	# Les piles, tous les 20 m, jusque dans l'eau.
	var t := 20.0
	var acc := 0.0
	for i in tablier.size() - 1:
		var a := tablier[i]
		var b := tablier[i + 1]
		var seg := a.distance_to(b)
		while t < acc + seg and t < l - 5.0:
			var v := a.lerp(b, (t - acc) / seg)
			var y := lerpf(ya, yb, t / l) + 0.45 + 0.6 * sin(PI * t / l)
			var bm := Basis(Vector3.UP, atan2(-(b - a).y, (b - a).x))
			o.boite(Transform3D(bm, Vector3(v.x, y - 4.0, v.y)), Vector3(1.6, 6.0, 6.2), PIERRE_PONT)
			t += 20.0
		acc += seg
