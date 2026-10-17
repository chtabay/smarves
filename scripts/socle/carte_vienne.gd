class_name CarteVienne
extends Control
## La carte des communes de la Vienne, à leur vraie place (Vienne, communes/vienne.json) : Smarves en
## or, les communes publiées sur le portail en vert d'eau (plus vif quand elles sont installées), les
## autres en filigrane. C'est l'amorce de la carte du département ; la bienvenue la montre.

## Smarves, au centre de tout.
const ORIGINE_INSEE := "86263"
const OR := Color(0.96, 0.8, 0.45)
const EAU := Color(0.35, 0.8, 0.75)
const FOND := Color(1, 1, 1, 0.06)
const FILET := Color(1, 1, 1, 0.16)
## La longitude se resserre à la latitude de la Vienne (cos 46,5°).
const RESSERRE := 0.69

## Codes INSEE à marquer : publiées (installables) et installées.
var publiees: Array = []
var installees: Array = []

var _formes := []  # [insee, [PackedVector2Array…]] en coordonnées de la carte
var _pour := Vector2.ZERO


func _ready() -> void:
	resized.connect(queue_redraw)


func _projeter() -> void:
	if _pour == size and not _formes.is_empty():
		return
	_pour = size
	_formes = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in Vienne.communes():
		for anneau in c.contour:
			for p in anneau:
				lo = Vector2(minf(lo.x, p[0]), minf(lo.y, p[1]))
				hi = Vector2(maxf(hi.x, p[0]), maxf(hi.y, p[1]))
	var w := (hi.x - lo.x) * RESSERRE
	var h := hi.y - lo.y
	var sc := minf(size.x / w, size.y / h)
	var dec := (size - Vector2(w, h) * sc) / 2.0
	for c in Vienne.communes():
		var anneaux := []
		for anneau in c.contour:
			var pts := PackedVector2Array()
			for p in anneau:
				pts.append(dec + Vector2((p[0] - lo.x) * RESSERRE, hi.y - p[1]) * sc)
			anneaux.append(pts)
		var ct: Array = c.centre
		_formes.append([str(c.insee), anneaux, dec + Vector2((ct[0] - lo.x) * RESSERRE, hi.y - ct[1]) * sc, str(c.nom)])


func _couleur(insee: String) -> Color:
	if insee == ORIGINE_INSEE:
		return OR
	if installees.has(insee):
		return EAU
	if publiees.has(insee):
		return Color(EAU, 0.55)
	return FOND


func _draw() -> void:
	_projeter()
	for f in _formes:
		var col := _couleur(f[0])
		for pts in f[1]:
			if pts.size() < 3:
				continue
			if not Geometry2D.triangulate_polygon(pts).is_empty():
				draw_polygon(pts, PackedColorArray([col]))
			var ferme: PackedVector2Array = pts.duplicate()
			ferme.append(pts[0])
			draw_polyline(ferme, FILET, 1.0, true)
	# Les noms des communes marquées, à gauche ou à droite pour ne pas se chevaucher.
	var police := Polices.gras()
	var poses: Array[Rect2] = []
	for f in _formes:
		if _couleur(f[0]) != FOND:
			poses.append(Rect2(f[2] - Vector2(6, 6), Vector2(12, 12)))
	for f in _formes:
		if _couleur(f[0]) == FOND:
			continue
		var at: Vector2 = f[2]
		var t: String = f[3]
		var w := police.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var choix := [Vector2(9, 5), Vector2(-11 - w, 5), Vector2(9, -9), Vector2(-11 - w, -9), Vector2(9, 19), Vector2(-11 - w, 19), Vector2(9, -23), Vector2(-11 - w, -23)]
		var o: Vector2 = choix[0]
		for c in choix:
			var r := Rect2(at + c - Vector2(0, 13), Vector2(w, 16))
			if poses.all(func(p): return not p.intersects(r)):
				o = c
				break
		poses.append(Rect2(at + o - Vector2(0, 13), Vector2(w, 16)))
		draw_circle(at, 4.0, Color.WHITE)
		draw_string_outline(police, at + o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.8))
		draw_string(police, at + o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, OR if f[0] == ORIGINE_INSEE else Color.WHITE)
