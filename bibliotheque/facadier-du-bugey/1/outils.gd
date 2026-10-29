extends RefCounted
## Le petit atelier des briques de la place du nord (arbres, mobilier, façadier des Flandres) : on empile des
## formes simples colorées par sommet (boîtes, cylindres, anneaux, profils extrudés, boules de feuillage),
## puis on fusionne le tout en trois surfaces au plus (le dur, le feuillage qui bouge au vent, ce qui luit)
## et un seul corps de collision. Unités en mètres. Chaque brique en garde sa copie, pour se suffire.
##   var o = Outils.new()
##   o.boite(Transform3D(Basis(), Vector3(0, 0.5, 0)), Vector3(1, 1, 1), Color("d9b45a"))
##   o.construire(parent, "Banc")
const FEUILLAGE := preload("res://bibliotheque/facadier-du-bugey/1/feuillage.gdshader")
const LUMIERE := preload("res://bibliotheque/facadier-du-bugey/1/lumiere.gdshader")

## Les trois genres de surface.
const DUR := 0
const FEUILLE := 1
const LUEUR := 2

var _st := {}
## Les boîtes de collision : [Transform3D, Vector3 taille].
var collisions: Array = []
## Le hasard de la brique : réglé par la graine, il rend deux constructions de même graine identiques.
var rng := RandomNumberGenerator.new()

static var _materiaux := {}


func _init(graine := 1) -> void:
	rng.seed = hash(graine)


func _s(genre: int) -> SurfaceTool:
	if not _st.has(genre):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[genre] = st
	return _st[genre]


## Un triangle, tourné de lui-même pour que sa face regarde n (le sens des sommets n'a pas d'importance).
## a sert de poids au vent pour le feuillage.
func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color, genre := DUR) -> void:
	var st := _s(genre)
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	n = n.normalized()
	for p in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color, genre := DUR) -> void:
	tri(a, b, c, n, col, genre)
	tri(a, c, d, n, col, genre)


## Une boîte de taille s centrée sur l'origine de t. col peut être une couleur, ou six (±x, ±y, ±z).
func boite(t: Transform3D, s: Vector3, col, genre := DUR, collision := false) -> void:
	var h := s * 0.5
	var faces := [
		[Vector3(1, 0, 0), [Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z)]],
		[Vector3(-1, 0, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
		[Vector3(0, 1, 0), [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, -1, 0), [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
		[Vector3(0, 0, 1), [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3(0, 0, -1), [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)]],
	]
	for i in faces.size():
		var f: Array = faces[i]
		var c: Color = col[i] if col is Array else col
		if c.a <= 0.0:
			continue
		var p: Array = f[1]
		quad(t * p[0], t * p[1], t * p[2], t * p[3], t.basis * f[0], c, genre)
	if collision:
		collisions.append([t, s])


## Une boîte posée : son pied au point p, tournée de lacet (radians) autour de y.
func pave(p: Vector3, s: Vector3, col, lacet := 0.0, collision := false) -> void:
	boite(Transform3D(Basis(Vector3.UP, lacet), p + Vector3(0, s.y * 0.5, 0)), s, col, DUR, collision)


## Un cylindre ou un tronc de cône d'axe y, le pied à l'origine de t ; cotes faces ; chapeaux fermés.
func cylindre(t: Transform3D, r_bas: float, r_haut: float, h: float, cotes: int, col: Color, genre := DUR, chapeaux := true) -> void:
	var pente := (r_bas - r_haut) / maxf(h, 0.001)
	for i in cotes:
		var a0 := TAU * i / cotes
		var a1 := TAU * (i + 1) / cotes
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var dm := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		var n := t.basis * (dm + Vector3(0, pente, 0))
		quad(t * (d0 * r_bas), t * (d1 * r_bas), t * (d1 * r_haut + Vector3(0, h, 0)), t * (d0 * r_haut + Vector3(0, h, 0)), n, col, genre)
		if chapeaux:
			if r_haut > 0.0:
				tri(t * Vector3(0, h, 0), t * (d0 * r_haut + Vector3(0, h, 0)), t * (d1 * r_haut + Vector3(0, h, 0)), t.basis * Vector3.UP, col, genre)
			if r_bas > 0.0:
				tri(t * Vector3.ZERO, t * (d0 * r_bas), t * (d1 * r_bas), t.basis * Vector3.DOWN, col, genre)


## Un anneau d'axe y (la margelle d'un bassin, un cerclage de tonneau) : rayons intérieur et extérieur.
func anneau(t: Transform3D, r_int: float, r_ext: float, h: float, cotes: int, col: Color) -> void:
	for i in cotes:
		var a0 := TAU * i / cotes
		var a1 := TAU * (i + 1) / cotes
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var dm := (d0 + d1) * 0.5
		var up := Vector3(0, h, 0)
		quad(t * (d0 * r_ext), t * (d1 * r_ext), t * (d1 * r_ext + up), t * (d0 * r_ext + up), t.basis * dm, col)
		quad(t * (d0 * r_int), t * (d1 * r_int), t * (d1 * r_int + up), t * (d0 * r_int + up), t.basis * -dm, col)
		quad(t * (d0 * r_int + up), t * (d1 * r_int + up), t * (d1 * r_ext + up), t * (d0 * r_ext + up), t.basis * Vector3.UP, col)


## Un profil plan (des points (x, y), dans n'importe quel sens) extrudé selon z, de z0 à z1, dans le repère t :
## un pignon, un arc, une volute. Les côtés et les deux faces.
func profil(t: Transform3D, points: PackedVector2Array, z0: float, z1: float, col, genre := DUR) -> void:
	if points.size() < 3:
		return
	if Geometry2D.is_polygon_clockwise(points):
		points.reverse()
	var c_face: Color = col[0] if col is Array else col
	var c_cote: Color = col[1] if col is Array else col
	var idx := Geometry2D.triangulate_polygon(points)
	for k in range(0, idx.size(), 3):
		var a := points[idx[k]]
		var b := points[idx[k + 1]]
		var c := points[idx[k + 2]]
		tri(t * Vector3(a.x, a.y, z1), t * Vector3(b.x, b.y, z1), t * Vector3(c.x, c.y, z1), t.basis * Vector3(0, 0, 1), c_face, genre)
		tri(t * Vector3(a.x, a.y, z0), t * Vector3(b.x, b.y, z0), t * Vector3(c.x, c.y, z0), t.basis * Vector3(0, 0, -1), c_face, genre)
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		var e := q - p
		if e.length_squared() < 1e-8:
			continue
		var n := Vector3(e.y, -e.x, 0)
		quad(t * Vector3(p.x, p.y, z0), t * Vector3(q.x, q.y, z0), t * Vector3(q.x, q.y, z1), t * Vector3(p.x, p.y, z1), t.basis * n, c_cote, genre)


## Le même profil, grossi de marge (Geometry2D.offset_polygon) : le liseré d'un pignon, l'encadrement d'une baie.
static func grossir(points: PackedVector2Array, marge: float) -> PackedVector2Array:
	var r := Geometry2D.offset_polygon(points, marge, Geometry2D.JOIN_MITER)
	return r[0] if r.size() > 0 else points


## Un arc (un demi-cercle ou moins) de centre c, rayon r, de l'angle a0 à a1 (radians), en n pas.
static func arc(c: Vector2, r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## Une boule de feuillage bosselée (ou d'autre chose : genre DUR) : rayons r selon x, y, z ; bosse en part du
## rayon. Les normales restent celles de la boule lisse, pour une ombre douce de dessin animé.
func boule(centre: Vector3, r: Vector3, col: Color, bosse := 0.18, genre := FEUILLE, variation := 0.06, vent := 1.0) -> void:
	var anneaux := 8
	var cotes := 12
	var pts := []
	var dec := rng.randf() * TAU
	for j in anneaux + 1:
		var ligne := []
		var phi := PI * j / anneaux
		for i in cotes:
			var th := TAU * i / cotes + dec + (0.5 if j % 2 == 1 else 0.0) * TAU / cotes
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var k := 1.0 + (rng.randf() - 0.5) * 2.0 * bosse if j > 0 and j < anneaux else 1.0
			ligne.append(d * k)
		pts.append(ligne)
	var st := _s(genre)
	for j in anneaux:
		for i in cotes:
			var quatre := [pts[j][i], pts[j][(i + 1) % cotes], pts[j + 1][(i + 1) % cotes], pts[j + 1][i]]
			for tr in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = quatre[tr[0]]
				var b: Vector3 = quatre[tr[1]]
				var c: Vector3 = quatre[tr[2]]
				var m := (a + b + c).normalized()
				if (b - a).cross(c - a).dot(m) > 0.0:
					var x := b
					b = c
					c = x
				for p in [a, b, c]:
					var v: Vector3 = p
					# éclaircie vers le haut, assombrie dessous : la masse se lit de loin
					var teinte := col.lightened(clampf(v.y * 0.12, 0.0, 0.2)).darkened(clampf(-v.y * 0.22, 0.0, 0.3))
					teinte = teinte.lightened((rng.randf() - 0.5) * variation) if variation > 0.0 else teinte
					teinte.a = clampf(vent * (0.4 + 0.6 * (v.y * 0.5 + 0.5)), 0.0, 1.0)
					st.set_color(teinte)
					st.set_normal((v.normalized() + Vector3(0, 0.35, 0)).normalized())
					st.add_vertex(centre + Vector3(v.x * r.x, v.y * r.y, v.z * r.z))


## Une branche ou un tronc : un cylindre de a à b, de rayons ra et rb.
func branche(a: Vector3, b: Vector3, ra: float, rb: float, col: Color, cotes := 6) -> void:
	var dir := b - a
	if dir.length() < 0.001:
		return
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	cylindre(Transform3D(Basis(x, y, z), a), ra, rb, dir.length(), cotes, col, DUR, false)


## Le matériau d'un genre de surface, partagé par toutes les briques qui l'emploient.
static func materiau(genre: int) -> Material:
	if _materiaux.has(genre):
		return _materiaux[genre]
	var m: Material
	if genre == FEUILLE:
		m = ShaderMaterial.new()
		m.shader = FEUILLAGE
	elif genre == LUEUR:
		m = ShaderMaterial.new()
		m.shader = LUMIERE
	else:
		var s := StandardMaterial3D.new()
		s.vertex_color_use_as_albedo = true
		s.vertex_color_is_srgb = true
		s.roughness = 0.88
		s.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		m = s
	_materiaux[genre] = m
	return m


## Fusionne ce qui a été empilé en un seul maillage (une surface par genre) sous parent, avec un seul corps de
## collision s'il y en a. Rend le MeshInstance3D.
func construire(parent: Node3D, nom: String) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for genre in [DUR, FEUILLE, LUEUR]:
		if not _st.has(genre):
			continue
		var st: SurfaceTool = _st[genre]
		st.index()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materiau(genre))
	_st.clear()
	var mi := MeshInstance3D.new()
	mi.name = nom
	mi.mesh = mesh
	parent.add_child(mi)
	if not collisions.is_empty():
		var corps := StaticBody3D.new()
		corps.name = nom + "Corps"
		for c in collisions:
			var forme := CollisionShape3D.new()
			var b := BoxShape3D.new()
			b.size = c[1]
			forme.shape = b
			forme.transform = c[0]
			corps.add_child(forme)
		parent.add_child(corps)
		collisions.clear()
	return mi
