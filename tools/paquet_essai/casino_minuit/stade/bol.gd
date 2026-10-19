extends RefCounted
## Le plan du stade de la Fortune : un rectangle aux coins arrondis autour de la pelouse du socle, et tout ce
## qui en suit le pourtour (les gradins, la promenade, les loges, la façade). Une forme se décrit par son
## profil, une suite de points [d, y] : d est l'écart compté depuis le pied du mur de la pelouse, vers le
## dehors, y la hauteur. Chaque point du pourtour est un centre (fixe pour un côté droit, le centre de l'arrondi
## pour un coin) et une normale vers le dehors : le point d'écart d est centre + normale × (R + d).
## Repère du stade : x le long de la pelouse, z en travers, le sud (z < 0) du côté du parvis.

## Le mur de la pelouse : x = ±A, z = ±B, coins de rayon R (centres en ±CX, ±CZ).
const A := 23.0
const B := 16.0
const R := 6.0
const CX := A - R
const CZ := B - R
## Les arrondis en huit pas.
const PAS_COIN := 8

static var _ech: Array = []


## Le pourtour, dans l'ordre : [centre (Vector2 x, z), normale (Vector2)]. Les côtés droits ont des points
## intermédiaires, aux x et z où les étages s'ouvrent (l'escalier du hall entre x = -3 et 3).
static func echantillons() -> Array:
	if not _ech.is_empty():
		return _ech
	var out: Array = []
	for x in [-10.0, -3.0, 3.0, 10.0]:
		out.append([Vector2(x, -CZ), Vector2(0, -1)])
	_coin(out, Vector2(CX, -CZ), 0.0)
	for z in [-3.3333, 3.3333]:
		out.append([Vector2(CX, z), Vector2(1, 0)])
	_coin(out, Vector2(CX, CZ), 90.0)
	for x in [10.0, 3.0, -3.0, -10.0]:
		out.append([Vector2(x, CZ), Vector2(0, 1)])
	_coin(out, Vector2(-CX, CZ), 180.0)
	for z in [3.3333, -3.3333]:
		out.append([Vector2(-CX, z), Vector2(-1, 0)])
	_coin(out, Vector2(-CX, -CZ), 270.0)
	_ech = out
	return out


static func _coin(out: Array, c: Vector2, a0: float) -> void:
	for i in PAS_COIN + 1:
		var a := deg_to_rad(a0 + 90.0 * i / PAS_COIN)
		out.append([c, Vector2(sin(a), -cos(a))])


## Le point d'écart d, à la hauteur y, d'un échantillon.
static func pt(e: Array, d: float, y: float) -> Vector3:
	var c: Vector2 = e[0]
	var n: Vector2 = e[1]
	return Vector3(c.x + n.x * (R + d), y, c.y + n.y * (R + d))


## Le côté d'un segment du pourtour : « S », « E », « N », « O » pour les côtés droits, « coin » sinon.
static func cote(a: Array, b: Array) -> String:
	var na: Vector2 = a[1]
	var nb: Vector2 = b[1]
	if na.distance_to(nb) > 0.01:
		return "coin"
	if na.y < -0.5:
		return "S"
	if na.x > 0.5:
		return "E"
	if na.y > 0.5:
		return "N"
	return "O"


## Le milieu d'un segment, au centre (pour savoir s'il tombe dans l'ouverture de l'escalier).
static func milieu(a: Array, b: Array) -> Vector2:
	return ((a[0] as Vector2) + (b[0] as Vector2)) / 2.0


## Une surface qui suit le pourtour selon un profil [Vector2(d, y)…] : chaque tronçon du profil fait une bande,
## tournée du côté où le profil monte et s'éloigne (le dessus d'une marche, le devant d'une contremarche).
## garder(cote, milieu) dit quels segments du pourtour poser ; couleur va aux sommets (écrans « led »).
static func anneau(K, nom_mat: String, profil: Array, garder := Callable(), couleur := Color.WHITE, retourner := false) -> void:
	var st := _bande(profil, garder, couleur, retourner, null)
	if st != null:
		K.put(nom_mat, st.commit())


## La même surface, en volume qu'on ne traverse pas (une pente sous les marches, un sol, un mur).
static func collision(K, profil: Array, garder := Callable()) -> void:
	# Un Array, que _bande remplit (un PackedVector3Array y serait recopié).
	var faces := []
	_bande(profil, garder, Color.WHITE, false, faces)
	if faces.is_empty():
		return
	var forme := ConcavePolygonShape3D.new()
	forme.backface_collision = true
	forme.set_faces(PackedVector3Array(faces))
	var corps := StaticBody3D.new()
	var f := CollisionShape3D.new()
	f.shape = forme
	corps.add_child(f)
	K.zone.add_child(corps)


static func _bande(profil: Array, garder: Callable, couleur: Color, retourner: bool, faces) -> SurfaceTool:
	var e := echantillons()
	var n := e.size()
	var st: SurfaceTool = null
	if faces == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Le long du pourtour, la longueur parcourue à chaque point du profil (les UV en mètres).
	var u := []
	u.resize(profil.size())
	u.fill(0.0)
	var v := [0.0]
	for j in range(1, profil.size()):
		v.append(v[j - 1] + (profil[j] as Vector2).distance_to(profil[j - 1]))
	var pose := 0
	for k in n:
		var a: Array = e[k]
		var b: Array = e[(k + 1) % n]
		var garde: bool = not garder.is_valid() or garder.call(cote(a, b), milieu(a, b))
		var nm: Vector2 = ((a[1] as Vector2) + (b[1] as Vector2)).normalized()
		for j in profil.size() - 1:
			var p: Vector2 = profil[j]
			var q: Vector2 = profil[j + 1]
			var lp := pt(a, p.x, p.y).distance_to(pt(b, p.x, p.y))
			var lq := pt(a, q.x, q.y).distance_to(pt(b, q.x, q.y))
			if garde and p.distance_to(q) > 0.0001:
				var dd := q - p
				var ref := Vector3(nm.x, 0, nm.y) * (-dd.y) + Vector3.UP * dd.x
				if retourner:
					ref = -ref
				var v0 := pt(a, p.x, p.y)
				var v1 := pt(b, p.x, p.y)
				var v2 := pt(b, q.x, q.y)
				var v3 := pt(a, q.x, q.y)
				if faces != null:
					faces.append_array([v0, v1, v2, v0, v2, v3])
				else:
					st.set_color(couleur)
					_quad(st, v0, v1, v2, v3, ref, Vector2(u[j], v[j]) / 2.0, Vector2(u[j] + lp, v[j]) / 2.0,
						Vector2(u[j + 1] + lq, v[j + 1]) / 2.0, Vector2(u[j + 1], v[j + 1]) / 2.0, couleur)
					pose += 1
			u[j] += lp
			if j == profil.size() - 2:
				u[j + 1] += lq
	if faces == null and pose == 0:
		return null
	return st


## Un panneau de diodes par segment du pourtour, à l'écart d, de y0 à y1 (la peau de la façade, l'anneau du
## balcon) : chacun a ses UV de 0 à 1, et sa diapositive décalée (COLOR.g) pour que les images courent autour.
static func ecrans(K, d: float, y0: float, y1: float, palette: int, garder := Callable(), dedans := false) -> void:
	var e := echantillons()
	var n := e.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := 0.0
	for k in n:
		var a: Array = e[k]
		var b: Array = e[(k + 1) % n]
		var v0 := pt(a, d, y0)
		var v1 := pt(b, d, y0)
		var l := v0.distance_to(v1)
		if not garder.is_valid() or garder.call(cote(a, b), milieu(a, b)):
			var nm: Vector2 = ((a[1] as Vector2) + (b[1] as Vector2)).normalized()
			var ref := Vector3(nm.x, 0, nm.y) * (-1.0 if dedans else 1.0)
			var col := Color(palette / 8.0, fmod(s * 0.06, 10.0) / 10.0, minf(l / (y1 - y0), 9.9) / 10.0, 1.0)
			# Vu du dehors, le panneau se lit de a vers b ; du dedans, à l'envers.
			var ua := 1.0 if dedans else 0.0
			_quad(st, v0, v1, pt(b, d, y1), pt(a, d, y1), ref, Vector2(ua, 0), Vector2(1.0 - ua, 0), Vector2(1.0 - ua, 1), Vector2(ua, 1), col)
		s += l
	K.put("led", st.commit())


## Les places d'une rangée à l'écart d et à la hauteur y, tous les pas mètres : [position, cap vers la pelouse].
## Une travée sur quatorze sièges reste vide (l'escalier de la travée).
static func places(d: float, y: float, pas := 0.6, garder := Callable(), travee := 14) -> Array:
	var e := echantillons()
	var n := e.size()
	var out := []
	var reste := 0.0
	var i := 0
	for k in n:
		var a: Array = e[k]
		var b: Array = e[(k + 1) % n]
		var p0 := pt(a, d, y)
		var p1 := pt(b, d, y)
		var l := p0.distance_to(p1)
		var garde: bool = not garder.is_valid() or garder.call(cote(a, b), milieu(a, b))
		var t := reste
		while t < l:
			var p := p0.lerp(p1, t / l)
			var nm: Vector2 = (a[1] as Vector2).lerp(b[1], t / l).normalized()
			if garde and i % travee < travee - 2:
				out.append([p, atan2(-nm.x, -nm.y)])
			i += 1
			t += pas
		reste = t - l
	return out


## Un quadrilatère tourné du côté de n, avec sa couleur de sommet (le kit, avec COLOR).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, col: Color) -> void:
	_tri(st, a, b, c, n, ua, ub, uc, col)
	_tri(st, a, c, d, n, ua, uc, ud, col)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, col: Color) -> void:
	# Godot dessine le devant d'un triangle dont les sommets tournent dans le sens des aiguilles d'une montre.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	for p in [[a, ua], [b, ub], [c, uc]]:
		st.set_color(col)
		st.set_uv(p[1])
		st.set_normal(n.normalized() if n.length() > 0.0 else Vector3.UP)
		st.add_vertex(p[0])
