extends RefCounted
## Les routes de la campagne, hors du bourg : les tronçons réels de la BD TOPO (relief/routes.json, relevés par
## tools/routes_reelles.py), maillés en rubans posés sur le sol tel qu'il est maillé, avec leur marquage comme sur
## la seconde planche : l'axe en tirets blancs, les rives d'un trait continu. Les chemins empierrés et les chemins
## de terre sont des rubans plus étroits, sans peinture. Le tout par lots, qui s'éteignent au loin.

const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const DONNEES := "res://communes/belley/relief/routes.json"

## Un gris chaud, écrit plus sombre qu'à l'écran : l'étalonnage de belley.gd tirait l'ancien (6c6f72) au
## bleu-gris (#8796A7 au rendu, verdict n° 30), puis 57544f à #6B7177 ; visé #6E6C66.
const ENROBE := Color("5a4f3e", 0.85)
const EMPIERRE := Color("c7b796", 0.95)
const TERRE := Color("b39f7b", 0.95)
const PEINTURE := Color("eeeee6", 0.9)
const LOT := 400.0
## Au-delà, la route n'est plus qu'un fil dans le paysage : on l'éteint.
const PORTEE := 1800.0
## Les carrés où le sol est maillé fin (le bourg, le relais) : la route y suit le sol tous les 5 m.
const FINS := [[-800.0, -800.0, 800.0, 800.0], [7035.0, 510.0, 7335.0, 810.0]]

var hauteur: Callable
var lots := {}


func _init(sol: Callable) -> void:
	hauteur = sol


func batir(parent: Node3D) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	var n := Node3D.new()
	n.name = "Routes"
	parent.add_child(n)
	var k := 0
	for r in d.routes:
		var pts := PackedVector2Array()
		var p: Array = r.p
		for i in range(0, p.size(), 2):
			pts.append(Vector2(p[i], p[i + 1]))
		# Le marquage dès 4 m de chaussée, et l'accotement revêtu d'un mètre : la route du pont de Lucey, sur la
		# planche, a son axe en tirets et ses rives.
		var g := int(r.g)
		var l := float(r.l)
		var marque := 1 if g == 0 and l >= 4.0 else int(r.m)
		var large := l + (1.0 if g == 0 else 0.0)
		# Hors du bourg, les départementales du Bugey : 5 m, l'axe en tirets, sans ligne de rive (verdict n° 30).
		if g == 0 and not _fin(pts[0]):
			large = minf(large, 5.0)
			marque = 2 if marque == 1 else marque
		_route(_echantillonner(pts), large, g, marque, k)
		k += 1
	for cle in lots:
		var mi: MeshInstance3D = lots[cle].construire(n, "Route")
		if mi == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = PORTEE
		mi.visibility_range_end_margin = 100.0


func _fin(v: Vector2) -> bool:
	for c in FINS:
		if v.x > c[0] and v.x < c[2] and v.y > c[1] and v.y < c[3]:
			return true
	return false


## Des points assez serrés pour suivre le sol : tous les 5 m (à 10 m, le sol maillé au pas de 15 m perçait la
## chaussée entre deux points, vu du vélo).
func _echantillonner(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var pas := 5.0
		var n := maxi(int(ceil(a.distance_to(b) / pas)), 1)
		for j in range(1, n + 1):
			out.append(a.lerp(b, float(j) / n))
	return out


func _outils(v: Vector2) -> RefCounted:
	var cle := Vector2i(int(floor(v.x / LOT)), int(floor(v.y / LOT)))
	if not lots.has(cle):
		lots[cle] = OUTILS.new(cle.x * 31 + cle.y)
	return lots[cle]


## Le point du sol décalé de dx sur la normale nrm, relevé de dy.
func _p(c: Vector2, nrm: Vector2, dx: float, dy: float) -> Vector3:
	var v := c + nrm * dx
	return Vector3(v.x, hauteur.call(v.x, v.y) + dy, v.y)


func _route(pts: PackedVector2Array, l: float, genre: int, marque: int, k: int) -> void:
	if pts.size() < 2:
		return
	var col := ENROBE if genre == 0 else (EMPIERRE if genre == 1 else TERRE)
	# Deux rubans qui se croisent ne sont pas au même niveau : pas de scintillement aux carrefours.
	var y := 0.1 + float(k % 5) * 0.012
	var nrms := PackedVector2Array()
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		nrms.append(Vector2(-t.y, t.x))
	var h := l * 0.5
	var abscisse := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var na := nrms[i]
		var nb := nrms[i + 1]
		var o: RefCounted = _outils(a)
		# En deux bandes, l'axe posé sur le sol lui aussi : le pli du sol sous une chaussée large ne la perce plus.
		# Hors des carrés fins, la chaussée est un peu plus relevée (le pli y est plus grand).
		var ya := y + (0.0 if _fin(a) else 0.2)
		o.quad(_p(a, na, -h, ya), _p(b, nb, -h, ya), _p(b, nb, 0.0, ya), _p(a, na, 0.0, ya), Vector3.UP, col, OUTILS.PEINT)
		o.quad(_p(a, na, 0.0, ya), _p(b, nb, 0.0, ya), _p(b, nb, h, ya), _p(a, na, h, ya), Vector3.UP, col, OUTILS.PEINT)
		var seg := a.distance_to(b)
		if marque == 1 or marque == 2:
			# Les rives : un trait continu à 0,3 m du bord (pas sur les départementales).
			for s: float in ([-1.0, 1.0] if marque == 1 else []):
				var e := s * (h - 0.3)
				o.quad(_p(a, na, e - 0.06, ya + 0.03), _p(b, nb, e - 0.06, ya + 0.03), _p(b, nb, e + 0.06, ya + 0.03), _p(a, na, e + 0.06, ya + 0.03), Vector3.UP, PEINTURE, OUTILS.PEINT)
			# L'axe : des tirets de 3 m tous les 9 m.
			var t0 := abscisse
			while t0 < abscisse + seg:
				var debut := fposmod(t0, 9.0)
				if debut < 3.0:
					var u0 := (t0 - abscisse) / seg
					var u1 := minf((t0 + 3.0 - debut - abscisse) / seg, 1.0)
					var c0 := a.lerp(b, u0)
					var c1 := a.lerp(b, u1)
					var nn := na.lerp(nb, (u0 + u1) * 0.5).normalized()
					o.quad(_p(c0, nn, -0.07, ya + 0.03), _p(c1, nn, -0.07, ya + 0.03), _p(c1, nn, 0.07, ya + 0.03), _p(c0, nn, 0.07, ya + 0.03), Vector3.UP, PEINTURE, OUTILS.PEINT)
					t0 += 3.0 - debut + 6.0
				else:
					t0 += 9.0 - debut
		abscisse += seg
