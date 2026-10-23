class_name CarteVienne
extends Control
## La carte des communes de la Vienne, à leur vraie place (Vienne, communes/vienne.json) : Smarves en
## or, les communes publiées sur le portail en vert d'eau (plus vif quand elles sont installées), les
## autres en filigrane. La bienvenue la montre telle quelle ; l'écran de la carte (autoload Carte) la
## rend navigable (interactive) : molette ou pincer pour zoomer, glisser pour déplacer, survoler et
## toucher une commune, avec le Clain et la Vienne, Poitiers dans la brume, et les communes qui
## s'allument quand elles arrivent. Au niveau « france », la même carte montre les départements
## (France, communes/france.json) : la Vienne en or, l'épingle sur la commune où l'on est, les régions
## cernées d'un trait franc et nommées, quelques grandes villes pour se repérer ; dézoomer encore sur le
## département entier y mène (recul). La carte montre de même, commune par commune, tout département
## dont le jeu connaît les communes (Departements : ceux de la Nouvelle-Aquitaine).

## Le joueur survole une commune (« » : plus aucune).
signal survol(insee: String)
## Le joueur a touché ou cliqué une commune (« » : à côté du département).
signal choix(insee: String)
## Le joueur zoome encore alors que la carte est au plus près : il veut entrer dans cette commune.
signal plongee(insee: String)
## Le joueur dézoome encore alors que le département entier est à l'écran : il veut voir la France.
signal recul
## Sur la France, le joueur a dézoomé assez pour quitter la région qu'il regardait.
signal region_quittee

## Smarves, au centre de tout.
const ORIGINE_INSEE := "86263"
const POITIERS_INSEE := "86194"
const OR := Color(0.96, 0.8, 0.45)
const EAU := Color(0.35, 0.8, 0.75)
const FOND := Color(1, 1, 1, 0.06)
const FILET := Color(1, 1, 1, 0.16)
const RIVIERE := Color(0.42, 0.62, 0.86, 0.55)
const BRUME := Color(0.78, 0.8, 0.84)
## La longitude se resserre à la latitude de la Vienne (cos 46,5°).
const RESSERRE := 0.69
const ZOOM_MAX := 8.0
## Sur la France, on zoome jusqu'à ce que la Vienne remplisse l'écran.
const ZOOM_MAX_FRANCE := 6.0
## Le tracé approché des rivières, d'une commune riveraine à l'autre (longitude, latitude), de
## l'amont vers l'aval : assez juste à l'échelle du département, pas une carte d'état-major.
const RIVIERES := {
	"la Vienne": [[0.66, 46.12], [0.698, 46.238], [0.66, 46.3], [0.715, 46.35], [0.73, 46.405], [0.668, 46.442],
		[0.645, 46.5], [0.672, 46.556], [0.61, 46.62], [0.566, 46.68], [0.541, 46.72], [0.529, 46.762],
		[0.553, 46.816], [0.593, 46.874], [0.608, 46.927], [0.622, 46.965], [0.598, 47.01]],
	"le Clain": [[0.29, 46.2], [0.262, 46.3], [0.2408, 46.3653], [0.2568, 46.4122], [0.2918, 46.4851],
		[0.3, 46.522], [0.335, 46.545], [0.352, 46.575], [0.3619, 46.6518], [0.3657, 46.7157],
		[0.43, 46.75], [0.4946, 46.7723], [0.529, 46.762]],
}

## Codes INSEE à marquer : publiées (installables) et installées.
var publiees: Array = []
var installees: Array = []
## Les villes installées dont une version plus récente est publiée : code INSEE -> version.
var a_jour := {}
## Les lignes du car : des tirets d'or de la commune « ici » vers chacune de ces communes (codes INSEE).
var lignes: Array = []
## Le trajet vers la commune choisie : des tirets blancs depuis « ici » (code INSEE, « » : aucun).
var trajet := ""
## La carte navigable (l'écran Carte) ; sinon un dessin fixe (la bienvenue).
var interactive := false
## « departement » : les communes du département ; « france » : les départements et les régions.
var niveau := "departement":
	set(v):
		if v == niveau:
			return
		niveau = v
		_refaire()
## Le département montré commune par commune (Departements.connu).
var departement := France.VIENNE:
	set(v):
		if v == departement:
			return
		departement = v
		if niveau == "departement":
			_refaire()
## Sur la France : la région regardée (« » : la France entière, où l'on désigne les régions).
var region := ""
## Sur la France : les départements où une ville est ouverte ou à télécharger, hors de la Vienne.
var actifs: Array = []
var brume := false
var rivieres := false
## Où est le joueur (code INSEE, « » : nulle part) : une épingle le montre.
var ici := ""
## La commune choisie, entourée de blanc.
var choisie := ""
## Le vide laissé autour du département, en pixels.
var marge := 0.0
## La vue : le point de la carte au centre (coordonnées de la carte à zoom 1) et le zoom.
var zoom := 1.0
var foyer := Vector2.ZERO

var _formes := []  # [insee, [PackedVector2Array…], centre, nom, Rect2, population]
var _par_insee := {}
var _pour := Vector2.ZERO
var _maillage: ArrayMesh
var _maillage_pour := ""
var _bords := PackedVector2Array()
var _cours := {}  # nom -> PackedVector2Array lissé
var _survolee := ""
var _regions := []  # [code, [PackedVector2Array…], centre, nom]
## Les communes qui s'allument : insee -> instant de départ (secondes).
var _allumage := {}
var _temps := 0.0
var _tirer := false
var _tire := false
var _appui := Vector2.ZERO
var _doigts := {}
var _ecart := 0.0
var _tween: Tween
## Les dézooms poussés contre la vue d'ensemble de la Vienne, cumulés : assez, et c'est la France.
var _pousse := 1.0
## La projection : coin bas-gauche (longitude, latitude), échelle et décalage en pixels.
var _lo := Vector2.ZERO
var _hi := Vector2.ZERO
var _sc := 1.0
var _dec := Vector2.ZERO
## Sur la France : les repères [nom, point de la carte].
var _reperes := []


func _refaire() -> void:
	_pour = Vector2.ZERO
	_formes = []
	_survolee = ""
	_pousse = 1.0
	queue_redraw()


func _ready() -> void:
	resized.connect(func():
		var avant := _pour
		_projeter()
		if zoom <= 1.0 or avant.x <= 0.0 or avant.y <= 0.0:
			foyer = size / 2.0
		elif avant != size:
			foyer = foyer * (size / avant)
		queue_redraw())
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE


## Recadre la vue sur tout le département.
func cadrer_tout(duree := 0.0) -> void:
	_projeter()
	aller_a(size / 2.0, 1.0, duree)


## Recadre la vue sur une commune, à ce zoom.
func cadrer(insee: String, z: float, duree := 0.0) -> void:
	_projeter()
	aller_a(centre_de(insee), z, duree)


func aller_a(point: Vector2, z: float, duree := 0.0) -> void:
	if _tween:
		_tween.kill()
	z = clampf(z, 1.0, zoom_max() * 1.6)
	if duree <= 0.0:
		zoom = z
		foyer = _borner(point, z)
		queue_redraw()
		return
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "zoom", z, duree)
	_tween.tween_property(self, "foyer", _borner(point, z), duree)
	_tween.finished.connect(func(): _tween = null)


## Que ces communes s'allument maintenant, l'une après l'autre.
func allumer(insees: Array) -> void:
	_allumage = {}
	var t := _temps + 0.5
	for i in insees:
		_allumage[i] = t
		t += 0.35
	queue_redraw()


func s_allume() -> bool:
	return not _allumage.is_empty()


## Le centre d'une commune sur la carte (coordonnées à zoom 1).
func centre_de(insee: String) -> Vector2:
	_projeter()
	return _formes[_par_insee[insee]][2] if _par_insee.has(insee) else size / 2.0


func nom_de(insee: String) -> String:
	_projeter()
	return _formes[_par_insee[insee]][3] if _par_insee.has(insee) else ""


func zoom_max() -> float:
	return ZOOM_MAX_FRANCE if niveau == "france" else ZOOM_MAX


## Un point (longitude, latitude) sur la carte (coordonnées à zoom 1).
func vers_plan(lonlat: Vector2) -> Vector2:
	_projeter()
	return _plan(lonlat)


func _plan(p: Vector2) -> Vector2:
	return _dec + Vector2((p.x - _lo.x) * RESSERRE, _hi.y - p.y) * _sc


func vers_ecran(p: Vector2) -> Vector2:
	return (p - foyer) * zoom + size / 2.0


func vers_carte(e: Vector2) -> Vector2:
	return (e - size / 2.0) / zoom + foyer


## La commune sous ce point de l'écran, ou « ».
func commune_sous(e: Vector2) -> String:
	_projeter()
	var p := vers_carte(e)
	for f in _formes:
		if not (f[4] as Rect2).has_point(p):
			continue
		for pts in f[1]:
			if Geometry2D.is_point_in_polygon(p, pts):
				return f[0]
	return ""


func survolee() -> String:
	return _survolee


func _projeter() -> void:
	if _pour == size and not _formes.is_empty():
		return
	if _pour == Vector2.ZERO:
		foyer = size / 2.0
	_pour = size
	_formes = []
	_par_insee = {}
	_maillage_pour = ""
	var source: Array = France.departements() if niveau == "france" else Departements.communes(departement)
	_lo = Vector2(INF, INF)
	_hi = Vector2(-INF, -INF)
	for c in source:
		for anneau in c.contour:
			for p in anneau:
				_lo = Vector2(minf(_lo.x, p[0]), minf(_lo.y, p[1]))
				_hi = Vector2(maxf(_hi.x, p[0]), maxf(_hi.y, p[1]))
	var w := (_hi.x - _lo.x) * RESSERRE
	var h := _hi.y - _lo.y
	var dispo := (size - Vector2(marge, marge) * 2.0).max(Vector2(1, 1))
	_sc = minf(dispo.x / w, dispo.y / h)
	_dec = (size - Vector2(w, h) * _sc) / 2.0
	var proj := func(p) -> Vector2: return _plan(Vector2(p[0], p[1]))
	_bords = PackedVector2Array()
	for c in source:
		var anneaux := []
		var boite := Rect2()
		for anneau in c.contour:
			var pts := PackedVector2Array()
			for p in anneau:
				pts.append(proj.call(p))
			anneaux.append(pts)
			for i in pts.size():
				_bords.append(pts[i])
				_bords.append(pts[(i + 1) % pts.size()])
			var r := Rect2(pts[0], Vector2.ZERO)
			for p in pts:
				r = r.expand(p)
			boite = r if boite.size == Vector2.ZERO else boite.merge(r)
		var id := str(c.get("insee", c.get("code", "")))
		_par_insee[id] = _formes.size()
		_formes.append([id, anneaux, proj.call(c.centre), str(c.nom), boite, int(c.get("population", 0))])
	_cours = {}
	_reperes = []
	_regions = []
	if niveau == "france":
		for v in France.villes():
			_reperes.append([str(v[0]), _plan(Vector2(v[1], v[2]))])
		for r in France.regions():
			var anneaux := []
			for anneau in r.contour:
				var pts := PackedVector2Array()
				for p in anneau:
					pts.append(proj.call(p))
				pts.append(pts[0])
				anneaux.append(pts)
			_regions.append([str(r.code), anneaux, proj.call(r.centre), str(r.nom)])
		return
	if departement != France.VIENNE:
		return
	for nom in RIVIERES:
		var pts := PackedVector2Array()
		for p in RIVIERES[nom]:
			pts.append(proj.call(p))
		_cours[nom] = _lisser(pts)


## Catmull-Rom : la rivière passe par chaque point, sans angles.
static func _lisser(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for s in 8:
			var t := s / 8.0
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[-1])
	return out


func _couleur(insee: String) -> Color:
	if niveau == "france":
		if insee == France.VIENNE:
			return Color(OR, 0.55)
		if actifs.has(insee):
			return Color(EAU, 0.45)
		return Color(EAU, 0.13) if France.region_de(insee) == France.REGION else FOND
	if insee == ORIGINE_INSEE:
		return OR
	if installees.has(insee):
		return EAU
	if publiees.has(insee):
		return Color(EAU, 0.55)
	if brume and insee == POITIERS_INSEE:
		return Color(BRUME, 0.5)
	return FOND


## Toutes les communes en un seul maillage, refait seulement quand une couleur change.
func _remailler() -> void:
	var cle := "%s|%s|%s|%s|%s|%s|%s" % [niveau, departement, publiees, installees, _allumage.keys(), brume, actifs]
	if cle == _maillage_pour and _maillage != null:
		return
	_maillage_pour = cle
	var sommets := PackedVector2Array()
	var couleurs := PackedColorArray()
	for f in _formes:
		var col := FOND if _allumage.has(f[0]) else _couleur(f[0])
		for pts in f[1]:
			if pts.size() < 3:
				continue
			var tri := Geometry2D.triangulate_polygon(pts)
			for k in tri:
				sommets.append(pts[k])
				couleurs.append(col)
	_maillage = ArrayMesh.new()
	if sommets.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sommets
	arrays[Mesh.ARRAY_COLOR] = couleurs
	_maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _process(delta: float) -> void:
	_temps += delta
	for i in _allumage.keys():
		if _temps - _allumage[i] > 1.4:
			_allumage.erase(i)
	if brume or not _allumage.is_empty() or _tween != null or niveau == "france":
		queue_redraw()


func _draw() -> void:
	_projeter()
	_remailler()
	var tr := Transform2D(0.0, Vector2(zoom, zoom), 0.0, size / 2.0 - foyer * zoom)
	draw_set_transform_matrix(tr)
	if _maillage and _maillage.get_surface_count() > 0:
		draw_mesh(_maillage, null)
	draw_multiline(_bords, FILET, -1.0)
	var fin := 1.0 / zoom
	if rivieres:
		for nom in _cours:
			draw_polyline(_cours[nom], RIVIERE, 2.2 * fin, true)
	if ici != "" and _par_insee.has(ici) and niveau == "departement":
		var depart: Vector2 = _formes[_par_insee[ici]][2]
		for i in lignes:
			if _par_insee.has(i) and i != ici:
				draw_dashed_line(depart, _formes[_par_insee[i]][2], Color(OR, 0.75), 2.0 * fin, 7.0 * fin, true, true)
		if trajet != "" and trajet != ici and _par_insee.has(trajet) and not lignes.has(trajet):
			draw_dashed_line(depart, _formes[_par_insee[trajet]][2], Color(1, 1, 1, 0.8), 2.0 * fin, 5.0 * fin, true, true)
	if niveau == "france":
		for r in _regions:
			for pts in r[1]:
				draw_polyline(pts, Color(1, 1, 1, 0.42), 1.6 * fin, true)
	for i in _allumage:
		var k := clampf((_temps - _allumage[i]) / 1.2, 0.0, 1.0)
		if k <= 0.0 or not _par_insee.has(i):
			continue
		var f: Array = _formes[_par_insee[i]]
		var col := _couleur(i).lerp(Color.WHITE, (1.0 - k) * 0.6)
		col.a *= k
		for pts in f[1]:
			if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
				draw_colored_polygon(pts, col)
		draw_arc(f[2], (8.0 + 40.0 * k) * fin, 0.0, TAU, 40, Color(_couleur(i), 0.8 * (1.0 - k)), 2.0 * fin, true)
	if brume and niveau == "departement" and departement == France.VIENNE:
		_brume()
	var origine := France.VIENNE if niveau == "france" else ORIGINE_INSEE
	for insee in ([origine, choisie, _survolee] if interactive else []):
		if insee == "" or not _par_insee.has(insee):
			continue
		var c := OR if insee == origine and insee != _survolee and insee != choisie else Color.WHITE
		# Sur la France entière, on désigne une région : c'est elle qu'on cerne.
		var anneaux: Array = _formes[_par_insee[insee]][1]
		if niveau == "france" and region == "" and insee != origine:
			var r := _region_formes(France.region_de(insee))
			anneaux = r[1] if not r.is_empty() else anneaux
		for pts in anneaux:
			var ferme: PackedVector2Array = pts.duplicate()
			ferme.append(pts[0])
			draw_polyline(ferme, Color(c, 0.9), (2.4 if anneaux != _formes[_par_insee[insee]][1] else 1.8) * fin, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if niveau == "france":
		_france()
		return
	_noms()
	if ici != "" and _par_insee.has(ici):
		_epingle(vers_ecran(_formes[_par_insee[ici]][2]))


## Une région sur la France : son centre (coordonnées à zoom 1) et le zoom qui la montre entière.
func cadre_region(code: String) -> Array:
	_projeter()
	var r := _region_formes(code)
	if r.is_empty():
		return [size / 2.0, 1.0]
	var boite := Rect2((r[1][0] as PackedVector2Array)[0], Vector2.ZERO)
	for pts in r[1]:
		for p in pts:
			boite = boite.expand(p)
	var z := minf((size.x - marge * 2.0) / maxf(boite.size.x, 1.0), (size.y - marge * 2.0) / maxf(boite.size.y, 1.0)) * 0.85
	return [boite.get_center(), clampf(z, 1.0, zoom_max())]


func _region_formes(code: String) -> Array:
	for r in _regions:
		if r[0] == code:
			return r
	return []


## Sur la France : les repères, le nom des régions de loin et des départements en zoomant, la Vienne, et l'épingle sur la
## commune où l'on est, cerclée d'or qui bat doucement pour qu'on la trouve d'un coup d'œil.
func _france() -> void:
	var police := Polices.gras()
	var fine := Polices.texte()
	var poses: Array[Rect2] = []
	var lieu := Departements.centre(ici if ici != "" else ORIGINE_INSEE)
	var at := vers_ecran(_plan(lieu))
	var k := fmod(_temps * 0.6, 1.0)
	draw_arc(at, 6.0 + 26.0 * k, 0.0, TAU, 40, Color(OR, 0.7 * (1.0 - k)), 2.0, true)
	poses.append(Rect2(at - Vector2(8, 34), Vector2(16, 34)))
	var nom := str(Departements.commune(ici).get("nom", "")) if ici != "" else "Smarves"
	var t := 17 if zoom < 3.0 else 19
	var w := police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x
	var o := at + Vector2(12, -8)
	poses.append(Rect2(o - Vector2(0, 14), Vector2(w, 18)))
	draw_string_outline(police, o, nom, HORIZONTAL_ALIGNMENT_LEFT, -1, t, 5, Color(0, 0, 0, 0.8))
	draw_string(police, o, nom, HORIZONTAL_ALIGNMENT_LEFT, -1, t, OR)
	if _par_insee.has(France.VIENNE):
		# Sous le département, pour ne pas croiser l'épingle.
		var f: Array = _formes[_par_insee[France.VIENNE]]
		var v := Vector2(vers_ecran(f[2]).x, vers_ecran((f[4] as Rect2).end).y + 17)
		var wv := fine.get_string_size("la Vienne", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var r := Rect2(v - Vector2(wv / 2.0, 13), Vector2(wv, 17))
		if poses.all(func(p): return not p.intersects(r)):
			poses.append(r)
			draw_string_outline(fine, v - Vector2(wv / 2.0, 0), "la Vienne", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.7))
			draw_string(fine, v - Vector2(wv / 2.0, 0), "la Vienne", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(OR, 0.9))
	# De loin, le nom des régions, en capitales espacées, avant les villes repères.
	if zoom < 1.8:
		for r in _regions:
			var nr: String = str(r[3]).to_upper()
			var tr := 12
			var wr := fine.get_string_size(nr, HORIZONTAL_ALIGNMENT_LEFT, -1, tr).x
			var c := vers_ecran(r[2]) + Vector2(0, 16)
			var rr := Rect2(c - Vector2(wr / 2.0, 12), Vector2(wr, 15))
			if not poses.all(func(q): return not q.intersects(rr)):
				continue
			poses.append(rr)
			var encre := Color(EAU, 0.95) if r[0] == France.REGION else Color(1, 1, 1, 0.55)
			draw_string_outline(fine, c - Vector2(wr / 2.0, 0), nr, HORIZONTAL_ALIGNMENT_LEFT, -1, tr, 4, Color(0, 0, 0, 0.7))
			draw_string(fine, c - Vector2(wr / 2.0, 0), nr, HORIZONTAL_ALIGNMENT_LEFT, -1, tr, encre)
	for rep in _reperes:
		var p := vers_ecran(rep[1])
		var tt := 13 if zoom < 3.0 else 15
		var wr := fine.get_string_size(rep[0], HORIZONTAL_ALIGNMENT_LEFT, -1, tt).x
		var r := Rect2(p + Vector2(6, -11), Vector2(wr, 15))
		draw_circle(p, 2.5, Color(1, 1, 1, 0.75), true, -1.0, true)
		if poses.all(func(q): return not q.intersects(r)):
			poses.append(r)
			draw_string_outline(fine, p + Vector2(6, 0), rep[0], HORIZONTAL_ALIGNMENT_LEFT, -1, tt, 4, Color(0, 0, 0, 0.7))
			draw_string(fine, p + Vector2(6, 0), rep[0], HORIZONTAL_ALIGNMENT_LEFT, -1, tt, Color(1, 1, 1, 0.75))
	if interactive and (zoom >= 1.8 or _survolee != ""):
		var vue := Rect2(Vector2.ZERO, size)
		for f in _formes:
			if f[0] == France.VIENNE or (zoom < 1.8 and f[0] != _survolee):
				continue
			var c := vers_ecran(f[2])
			if not vue.has_point(c):
				continue
			var tn := 13 if zoom < 3.0 else 14
			var wn := fine.get_string_size(f[3], HORIZONTAL_ALIGNMENT_CENTER, -1, tn).x
			var r := Rect2(c - Vector2(wn / 2.0 + 3, 12), Vector2(wn + 6, 16))
			if not poses.all(func(q): return not q.intersects(r)):
				continue
			poses.append(r)
			draw_string(fine, c + Vector2(-wn / 2.0, 0), f[3], HORIZONTAL_ALIGNMENT_LEFT, -1, tn, Color(1, 1, 1, 0.42 if f[0] != _survolee else 0.9))
	_epingle(at)


## Poitiers dans la brume : des nappes pâles qui dérivent lentement et débordent un peu.
func _brume() -> void:
	if not _par_insee.has(POITIERS_INSEE):
		return
	var f: Array = _formes[_par_insee[POITIERS_INSEE]]
	var r: Rect2 = f[4]
	var rayon := r.size.length() * 0.22
	for n in 12:
		var a := float(n) * 2.399 + _temps * (0.05 + 0.02 * (n % 3))
		var d := 0.18 + 0.27 * fmod(float(n) * 0.618, 1.0)
		var p: Vector2 = f[2] + Vector2(cos(a) * r.size.x * d, sin(a * 1.3) * r.size.y * d * 0.8)
		var rr := rayon * (0.65 + 0.35 * sin(_temps * 0.3 + n))
		for k in 4:
			draw_circle(p, rr * (1.0 - k * 0.2), Color(BRUME, 0.07), true, -1.0, true)


func _epingle(at: Vector2) -> void:
	var haut := at - Vector2(0, 26)
	draw_line(at, haut, Color.WHITE, 2.0, true)
	draw_circle(haut, 7.0, Color.WHITE, true, -1.0, true)
	draw_circle(haut, 3.5, Color(0.08, 0.1, 0.14), true, -1.0, true)
	draw_circle(at, 2.5, Color.WHITE, true, -1.0, true)


# Les noms : ceux des communes marquées toujours, à gauche ou à droite pour ne pas se chevaucher ;
# en zoomant, les autres en filigrane, là où il reste de la place.
func _noms() -> void:
	var police := Polices.gras()
	var fine := Polices.texte()
	var poses: Array[Rect2] = []
	var vus := []
	for f in _formes:
		if _marquee(f[0]):
			vus.append(f)
			poses.append(Rect2(vers_ecran(f[2]) - Vector2(6, 6), Vector2(12, 12)))
	if ici != "" and _par_insee.has(ici):
		poses.append(Rect2(vers_ecran(_formes[_par_insee[ici]][2]) - Vector2(8, 34), Vector2(16, 34)))
	var t15 := 15 if not interactive else 17
	for f in vus:
		var at := vers_ecran(f[2])
		var t: String = f[3]
		var w := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, t15).x
		# Une ville à mettre à jour porte sa pastille sous son nom : l'étiquette est plus haute.
		var maj := "mise à jour %s" % a_jour[f[0]] if a_jour.has(f[0]) else ""
		var taille := Vector2(maxf(w, Polices.gras().get_string_size(maj, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12), 16 + (21 if maj != "" else 0))
		var choix := [Vector2(9, 5), Vector2(-11 - w, 5), Vector2(9, -9), Vector2(-11 - w, -9), Vector2(9, 19), Vector2(-11 - w, 19), Vector2(9, -23), Vector2(-11 - w, -23)]
		var o: Vector2 = choix[0]
		for c in choix:
			var r := Rect2(at + c - Vector2(0, 13), taille)
			if poses.all(func(p): return not p.intersects(r)):
				o = c
				break
		poses.append(Rect2(at + o - Vector2(0, 13), taille))
		if f[0] != POITIERS_INSEE:
			draw_circle(at, 4.0, Color.WHITE)
		var encre := OR if f[0] == ORIGINE_INSEE else Color(0.86, 0.88, 0.92) if f[0] == POITIERS_INSEE else Color.WHITE
		draw_string_outline(police if f[0] != POITIERS_INSEE else fine, at + o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, t15, 5, Color(0, 0, 0, 0.8))
		draw_string(police if f[0] != POITIERS_INSEE else fine, at + o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, t15, encre)
		if maj != "":
			_pastille(at + o + Vector2(0, 20), maj)
	if not interactive:
		return
	if rivieres:
		for nom in _cours:
			var pts: PackedVector2Array = _cours[nom]
			var at := vers_ecran(pts[int(pts.size() * (0.3 if nom == "la Vienne" else 0.22))])
			draw_string_outline(fine, at + Vector2(8, 0), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.6))
			draw_string(fine, at + Vector2(8, 0), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(RIVIERE, 0.95))
	if zoom < 2.2:
		# Hors de la Vienne, où rien n'est encore allumé, les plus grandes villes servent de repères.
		if departement != France.VIENNE:
			var grandes := _formes.filter(func(f): return not _marquee(f[0]))
			grandes.sort_custom(func(a, b): return a[5] > b[5])
			for f in grandes.slice(0, 8):
				var at := vers_ecran(f[2])
				var w := fine.get_string_size(f[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				var r := Rect2(at + Vector2(6, -12), Vector2(w, 16))
				if not poses.all(func(p): return not p.intersects(r)):
					continue
				poses.append(r)
				draw_circle(at, 2.5, Color(1, 1, 1, 0.7), true, -1.0, true)
				draw_string_outline(fine, at + Vector2(6, 0), f[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.7))
				draw_string(fine, at + Vector2(6, 0), f[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
		return
	var vue := Rect2(Vector2.ZERO, size)
	var t12 := 13 if zoom < 4.0 else 14
	for f in _formes:
		if _marquee(f[0]):
			continue
		var at := vers_ecran(f[2])
		if not vue.has_point(at):
			continue
		var t: String = f[3]
		var w := fine.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, t12).x
		var r := Rect2(at - Vector2(w / 2.0 + 3, 12), Vector2(w + 6, 16))
		if not poses.all(func(p): return not p.intersects(r)):
			continue
		poses.append(r)
		draw_string(fine, at + Vector2(-w / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, t12, Color(1, 1, 1, 0.42 if f[0] != _survolee else 0.9))


## Une pastille d'or après le nom : une version plus récente attend au portail.
func _pastille(at: Vector2, t: String) -> void:
	var police := Polices.gras()
	var w := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var r := Rect2(at + Vector2(0, -13), Vector2(w + 12, 17))
	var k := 0.75 + 0.25 * sin(_temps * 3.0)
	draw_rect(r, Color(OR, k), true)
	draw_string(police, at + Vector2(6, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.12, 0.08, 0.02))


func _marquee(insee: String) -> bool:
	return _couleur(insee) != FOND


# --- Le geste ------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventScreenTouch:
		_toucher(event)
	elif event is InputEventScreenDrag:
		_glisser(event)
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return  # le toucher imité en souris : déjà traité ci-dessus
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoomer(1.25, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoomer(0.8, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_tirer = true
				_tire = false
				_appui = event.position
			else:
				_tirer = false
				if not _tire:
					choix.emit(commune_sous(event.position))
		accept_event()
	elif event is InputEventMouseMotion:
		if _tirer and (_tire or event.position.distance_to(_appui) > 6.0):
			_tire = true
			_deplacer(event.relative)
		_survoler(commune_sous(event.position))
	elif event is InputEventMagnifyGesture:
		_zoomer(event.factor, event.position)
	elif event is InputEventPanGesture:
		_deplacer(-event.delta * 8.0)


func _toucher(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_doigts[e.index] = {"depart": e.position, "pos": e.position, "tire": false}
		if _doigts.size() == 2:
			_ecart = _ecart_doigts()
	elif _doigts.has(e.index):
		var d: Dictionary = _doigts[e.index]
		_doigts.erase(e.index)
		if not d.tire and _doigts.is_empty() and _ecart <= 0.0:
			var i := commune_sous(e.position)
			_survoler(i)
			choix.emit(i)
		if _doigts.is_empty():
			_ecart = 0.0
	accept_event()


func _glisser(e: InputEventScreenDrag) -> void:
	if not _doigts.has(e.index):
		return
	var d: Dictionary = _doigts[e.index]
	d.pos = e.position
	if _doigts.size() >= 2:
		var ecart := _ecart_doigts()
		var milieu: Vector2 = (_doigts.values()[0].pos + _doigts.values()[1].pos) / 2.0
		if _ecart > 0.0 and ecart > 0.0:
			_zoomer(ecart / _ecart, milieu)
		_ecart = ecart
		for o in _doigts.values():
			o.tire = true
	elif d.tire or e.position.distance_to(d.depart) > 14.0:
		d.tire = true
		_deplacer(e.relative)
	accept_event()


func _ecart_doigts() -> float:
	var v: Array = _doigts.values()
	return (v[0].pos as Vector2).distance_to(v[1].pos) if v.size() >= 2 else 0.0


func _zoomer(facteur: float, autour: Vector2) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if facteur > 1.0 and zoom >= zoom_max() - 0.01:
		plongee.emit(commune_sous(autour))
		return
	# Contre la vue d'ensemble du département, un dézoom de plus (deux crans de molette) montre la France.
	if facteur < 1.0 and zoom <= 1.001 and niveau == "departement":
		_pousse *= facteur
		if _pousse < 0.7:
			_pousse = 1.0
			recul.emit()
		return
	_pousse = 1.0
	var avant := vers_carte(autour)
	zoom = clampf(zoom * facteur, 1.0, zoom_max())
	foyer = _borner(avant - (autour - size / 2.0) / zoom, zoom)
	if niveau == "france" and region != "" and facteur < 1.0 and zoom < 1.5:
		region = ""
		region_quittee.emit()
	queue_redraw()


func _deplacer(rel: Vector2) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	foyer = _borner(foyer - rel / zoom, zoom)
	queue_redraw()


## On ne perd jamais le département de vue : le centre reste sur la carte.
func _borner(p: Vector2, z: float) -> Vector2:
	if z <= 1.0:
		return size / 2.0
	var lo := Vector2(marge, marge)
	var hi := size - Vector2(marge, marge)
	return p.clamp(lo.min(size / 2.0), hi.max(size / 2.0))


func _survoler(i: String) -> void:
	if i == _survolee:
		return
	_survolee = i
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if i != "" else Control.CURSOR_ARROW
	survol.emit(i)
	queue_redraw()
