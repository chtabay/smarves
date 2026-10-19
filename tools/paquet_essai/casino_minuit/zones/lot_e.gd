extends RefCounted
## Lot E « dehors » (js/zones/e-0-commun.js, e-strip.js) : les briques communes aux zones du Strip, devant le
## casino. Le moteur web fusionnait tout en atlas (façades, enseignes, écrans, ampoules) ; ici chaque famille
## est un matériau du kit qui se calcule dans son shader, et les formes s'y fusionnent zone par zone :
## façades (facade), écrans (led), guirlandes (ampoules), voitures et foule instanciées (vehicule, foule).
## Repère du lot : x vers l'est, z vers le sud (le boulevard), ry = 0 regarde +z (vers la rue depuis le casino).

## Le plan du Strip (e-strip.js, LAY), en mètres monde.
const LAY := {
	"X0": -120.0, "X1": 120.0, "XEND": 118.0,
	"FACADE": 30.0, "CASINO": 60.0, "PAV": 16.0, "PAV_Z": 31.8, "DOOR": 3.0,
	"DRIVE0": 33.2, "DRIVE1": 40.0, "DRIVE_X": 16.0,
	"LAKE0": 40.0, "LAKE1": 46.8, "LAKE_IN": 8.0, "LAKE_OUT": 58.0,
	"WALK0": 46.8, "CURB0": 52.0, "MED0": 62.0, "MED1": 66.0, "CURB1": 76.0, "OPP": 89.6, "ARENA": 90.0,
	"CROSS": 3.0, "ROAD_Y": -0.15,
}
## Les six voies du boulevard : [z, sens] (−1 vers l'ouest, côté casino ; +1 vers l'est).
const VOIES := [[53.67, -1.0], [57.0, -1.0], [60.33, -1.0], [67.67, 1.0], [71.0, 1.0], [74.33, 1.0]]
## La marquise géante du casino, dans le bassin ouest (E.MARQ).
const MARQ := Vector2(-31.0, 44.0)

## Les styles de façade (shaders/facade.gdshader, COLOR.a en dixièmes).
const HOTEL := 0
const VERRE := 1
const DORE := 2
const BALCONS := 3
const DEVANTURES := 4
const TOUR := 5
const ARDOISE := 6
const BETON := 7
const PARKING := 8
const CHAPELLE := 9

## Les palettes des écrans (shaders/led.gdshader).
const LED_ROUGE := 0
const LED_CYAN := 1
const LED_REVUE := 2
const LED_BLEU := 3
const LED_MINUIT := 4
const LED_EAU := 5
const LED_ROSE := 6

## Les voitures (e-boulevard.js, DIMS) : longueur, largeur, hauteur, vitesse de croisière (m/s).
const DIMS := {
	"berline": [4.7, 1.86, 1.45, 14.0], "taxi": [4.7, 1.86, 1.62, 13.0], "suv": [4.95, 1.98, 1.82, 13.5],
	"sport": [4.45, 1.95, 1.18, 16.0], "limo": [8.6, 1.98, 1.48, 11.5], "bus": [12.2, 2.55, 3.25, 10.5],
}
const PEINTURES := {
	"berline": ["#0E0E12", "#E8E8E4", "#8A9098", "#6A0E16", "#16264A", "#B8A27A", "#2E3238"], "taxi": ["#F2C12E"],
	"suv": ["#0E0E12", "#EDEAE2", "#3A3E44", "#1E2A3A"], "sport": ["#B3121F", "#F2C12E", "#0E0E12", "#2A5AC8"],
	"limo": ["#0B0B0E", "#F0EEE8"], "bus": ["#E8E8E4"],
}

static var _cache := {}


# --- Surfaces colorées (façades, écrans, ampoules) ------------------------------------------------

## Un triangle coloré, tourné du côté de la normale n (Godot : sens des aiguilles d'une montre).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, col: Color) -> void:
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
		st.set_normal(n)
		st.add_vertex(p[0])


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, col: Color) -> void:
	_tri(st, a, b, c, n, ua, ub, uc, col)
	_tri(st, a, c, d, n, ua, uc, ud, col)


## Une face d'immeuble de A à B, vue du côté de la normale (−dz, dx) (de gauche à droite pour qui la regarde),
## de y0 à y1, au style donné ; UV en mètres, v à la hauteur réelle (les étages s'alignent d'une face à l'autre).
static func face(K, ax: float, az: float, bx: float, bz: float, y0: float, y1: float, style: int, teinte := Color("#2C2620")) -> void:
	var l := Vector2(bx - ax, bz - az).length()
	if l < 0.01:
		return
	var n := Vector3(-(bz - az), 0, bx - ax).normalized()
	var col := Color(teinte.r, teinte.g, teinte.b, style / 10.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, Vector3(ax, y1, az), Vector3(bx, y1, bz), Vector3(bx, y0, bz), Vector3(ax, y0, az), n,
		Vector2(0, y1), Vector2(l, y1), Vector2(l, y0), Vector2(0, y0), col)
	K.put("facade", st.commit())


## Un pan de façade quelconque : origine o, vecteurs unitaires u (largeur) et v (montée), longueurs lu × lv.
static func pan(K, o: Vector3, u: Vector3, v: Vector3, lu: float, lv: float, style: int, teinte: Color) -> void:
	var n := u.cross(v).normalized()
	var col := Color(teinte.r, teinte.g, teinte.b, style / 10.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, o + v * lv, o + u * lu + v * lv, o + u * lu, o, n, Vector2(0, lv), Vector2(lu, lv), Vector2(lu, 0), Vector2(0, 0), col)
	K.put("facade", st.commit())


## Un bloc d'immeuble : ses faces visibles (s = +z, n = −z, e = +x, o = −x) et son toit de béton.
static func bloc(K, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, style: int, faces := "sneo", teinte := Color("#2C2620"), toit := true) -> void:
	if faces.contains("s"):
		face(K, x0, z1, x1, z1, y0, y1, style, teinte)
	if faces.contains("n"):
		face(K, x1, z0, x0, z0, y0, y1, style, teinte)
	if faces.contains("e"):
		face(K, x1, z1, x1, z0, y0, y1, style, teinte)
	if faces.contains("o"):
		face(K, x0, z0, x0, z1, y0, y1, style, teinte)
	if toit:
		K.box("beton_e", x1 - x0, 0.4, z1 - z0, (x0 + x1) / 2.0, y1 + 0.2, (z0 + z1) / 2.0)


## Un écran LED w × h centré en (x, y, z), tourné vers ry (E.led) : palette, déphasage (s).
static func ecran(K, x: float, y: float, z: float, w: float, h: float, ry: float, palette: int, phase := 0.0) -> void:
	var n := Vector3(sin(ry), 0, cos(ry))
	var r := Vector3(cos(ry), 0, -sin(ry))
	var c := Vector3(x, y, z) + n * 0.02
	var col := Color(palette / 8.0, fmod(phase, 10.0) / 10.0, minf(w / h, 9.9) / 10.0, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := r * w / 2.0
	var hh := Vector3.UP * h / 2.0
	_quad(st, c - hw + hh, c + hw + hh, c + hw - hh, c - hw - hh, n, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), col)
	K.put("led", st.commit())


## Une rangée d'ampoules « chenillard » de A à B, bande de largeur h tournée vers ry (E.bulbs.line).
static func ampoules(K, a: Vector3, b: Vector3, h: float, ry := 0.0) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.05:
		return
	var n := Vector3(sin(ry), 0, cos(ry))
	var up := n.cross(d / l).normalized() * h / 2.0
	var o := n * 0.03
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, a + up + o, b + up + o, b - up + o, a - up + o, n, Vector2(0, 1), Vector2(l, 1), Vector2(l, 0), Vector2(0, 0), Color.WHITE)
	K.put("ampoules", st.commit())


## Un cadre d'ampoules autour d'un rectangle vertical w × h centré en (x, y, z), tourné vers ry (E.bulbs.frame).
static func cadre_ampoules(K, x: float, y: float, z: float, w: float, h: float, ry := 0.0, taille := 0.22) -> void:
	var r := Vector3(cos(ry), 0, -sin(ry))
	var c := Vector3(x, y, z)
	var a := c - r * w / 2.0 + Vector3.UP * h / 2.0
	var b := c + r * w / 2.0 + Vector3.UP * h / 2.0
	var cc := c + r * w / 2.0 - Vector3.UP * h / 2.0
	var d := c - r * w / 2.0 - Vector3.UP * h / 2.0
	ampoules(K, a, b, taille, ry)
	ampoules(K, d, cc, taille, ry)
	ampoules(K, d, a, taille, ry)
	ampoules(K, cc, b, taille, ry)


## Un plan vertical w × h centré en (x, y, z), face vers ry (E.quad).
static func plaque(K, nom_mat: String, w: float, h: float, x: float, y: float, z: float, ry := 0.0) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	K.put(nom_mat, q, K.xf(x, y, z, 0, ry, 0))


## Un prisme droit : polygone convexe [[x, z]…] extrudé de y0 à y1 (E.prism).
static func prisme(K, nom_mat: String, pts: Array, y0: float, y1: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var cx := 0.0
	var cz := 0.0
	for p in pts:
		cx += p[0] / n
		cz += p[1] / n
	for i in n:
		var a: Array = pts[i]
		var b: Array = pts[(i + 1) % n]
		var A0 := Vector3(a[0], y0, a[1])
		var B0 := Vector3(b[0], y0, b[1])
		var A1 := Vector3(a[0], y1, a[1])
		var B1 := Vector3(b[0], y1, b[1])
		var no := Vector3((a[0] + b[0]) / 2.0 - cx, 0, (a[1] + b[1]) / 2.0 - cz).normalized()
		K._quad(st, A1, B1, B0, A0, no)
		K._tri(st, Vector3(cx, y1, cz), A1, B1, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		K._tri(st, Vector3(cx, y0, cz), A0, B0, Vector3.DOWN, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	K.put(nom_mat, st.commit())


# --- Enseignes -------------------------------------------------------------------------------------

## Une enseigne au néon (E.signs.add) de largeur w et hauteur h, lue depuis ry : « neon » (tube de couleur au
## cœur clair), « bloc » (lettres bâton éclairées), « grave » (lettres d'or) ; vertical : lettres empilées.
static func enseigne(K, t: String, couleur: String, w: float, h: float, x: float, y: float, z: float, ry := 0.0, style := "neon", vertical := false) -> Label3D:
	var c := Color(couleur)
	var l := Label3D.new()
	var texte := t
	var lignes := 1
	if vertical:
		var lettres := []
		for ch in t:
			if ch != " ":
				lettres.append(ch)
		texte = "\n".join(lettres)
		lignes = lettres.size()
	l.text = texte
	l.font = Polices.titre() if style == "neon" else Polices.gras()
	l.font_size = 96
	l.line_spacing = -18.0 if vertical else 0.0
	l.width = 4000
	l.position = Vector3(x, y, z) + Vector3(sin(ry), 0, cos(ry)) * 0.03
	l.rotation.y = ry
	l.double_sided = false
	l.shaded = false
	l.no_depth_test = false
	if style == "grave":
		l.modulate = c
		l.outline_modulate = Color("#3A2A10")
		l.outline_size = 6
	else:
		l.modulate = Color(c.lerp(Color.WHITE, 0.55 if style == "neon" else 0.3), 1.0) * 1.6
		l.outline_modulate = Color(c * 1.3, 0.9)
		l.outline_size = 20 if style == "neon" else 10
	var f: Font = l.font
	if vertical:
		l.pixel_size = h / (lignes * (96.0 + l.line_spacing) * 1.1)
		var lw := 0.0
		for ch in texte.split("\n"):
			lw = maxf(lw, f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x * l.pixel_size)
		if lw > w:
			l.pixel_size *= w / lw
	else:
		l.pixel_size = h / 96.0 * 0.95
		var largeur := f.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x * l.pixel_size
		if largeur > w:
			l.pixel_size *= w / largeur
	K.zone.add_child(l)
	return l


# --- Mobilier de la rue ----------------------------------------------------------------------------

## Une file de potelets dorés et de cordons rouges, de point en point (K.ropeLine), le long de x ou de z.
static func cordons(K, fixe: float, pas: Array, axe := "z", collision := true) -> void:
	var pts := []
	for a in pas:
		pts.append(Vector2(fixe, a) if axe == "z" else Vector2(a, fixe))
	for p in pts:
		K.cyl("or", 0.15, 0.17, 0.04, p.x, 0.02, p.y, 10)
		K.cyl("or", 0.025, 0.025, 0.95, p.x, 0.5, p.y, 6)
		K.sph("or", 0.055, p.x, 1.0, p.y)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		K.beam("coussin", Vector3(a.x, 0.84, a.y), Vector3(b.x, 0.84, b.y), 0.045, 0.045)
		if collision:
			K.segment(a.x, a.y, b.x, b.y, 0.08, 0.0, 1.0)


## Un lampadaire de rue (e-boulevard.js, lamp) : mât d'acier de 9 m, une ou deux crosses vers dz.
static func lampadaire(K, x: float, z: float, bras: Array, y := 0.0) -> void:
	K.cyl("acier_sombre", 0.09, 0.14, 9.2, x, y + 4.6, z, 8)
	K.cyl("acier_sombre", 0.22, 0.26, 0.6, x, y + 0.3, z, 8)
	for dz in bras:
		K.beam("acier_sombre", Vector3(x, y + 8.9, z), Vector3(x, y + 9.3, z + dz * 2.2), 0.08, 0.08)
		K.box("acier_sombre", 0.5, 0.16, 0.9, x, y + 9.25, z + dz * 2.6)
		K.box("blanc_froid", 0.36, 0.03, 0.7, x, y + 9.16, z + dz * 2.6)


## Un banc de rue à deux places, le dossier du côté local +z : assis, on regarde vers (−sin ry, −cos ry).
static func banc(K, x: float, z: float, ry: float, assise := "laque_noire", pied := "or") -> Array:
	var c := cos(ry)
	var s := sin(ry)
	K.box(pied, 2.2, 0.08, 0.5, x, 0.45, z, ry)
	K.box(assise, 2.2, 0.05, 0.46, x, 0.5, z, ry)
	K.box(assise, 2.2, 0.45, 0.06, x + s * 0.24, 0.75, z + c * 0.24, ry)
	for k in [-1.0, 1.0]:
		K.box(pied, 0.06, 0.45, 0.5, x + c * k * 1.05, 0.22, z - s * k * 1.05, ry)
	K.solide(2.3, 1.0, 0.55, x, 0.5, z, ry)
	var places := []
	for lx in [-0.5, 0.5]:
		places.append([Vector3(x + c * lx, 0.48, z - s * lx), ry])
	return places


# --- Palmiers --------------------------------------------------------------------------------------

## Le palmier du Strip (E.palmGeo) : tronc courbe annelé, neuf palmes doubles ; une forme en couleurs de
## sommet, instanciée partout.
static func forme_palmier() -> ArrayMesh:
	if _cache.has("palmier"):
		return _cache.palmier
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var H := 9.0
	var n := 6
	var ecorce := [Color("#6A5038"), Color("#4A3626")]
	var palme := [Color("#2F6A3C"), Color("#3E7E44")]
	var P := func(t: float) -> Vector3: return Vector3(0.9 * t * t, H * t, 0)
	for i in n:
		var a: Vector3 = P.call(float(i) / n)
		var b: Vector3 = P.call(float(i + 1) / n)
		var r0 := 0.24 - 0.08 * i / n
		var r1 := 0.24 - 0.08 * (i + 1) / n
		for k in 6:
			var a0 := TAU * k / 6.0
			var a1 := TAU * (k + 1) / 6.0
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			_quad(st, a + d0 * r0, a + d1 * r0, b + d1 * r1, b + d0 * r1, (d0 + d1).normalized(), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, ecorce[i % 2])
	var top: Vector3 = P.call(1.0)
	for f in 9:
		var a := f * TAU / 9.0 + (f % 2) * 0.12
		var lf := 3.4 + (f % 3) * 0.35
		var rise := 0.75 if f % 2 else 1.05
		var dx := cos(a)
		var dz := sin(a)
		var px := -dz
		var pz := dx
		var pt := func(t: float) -> Vector3: return Vector3(top.x + dx * lf * t, top.y + 0.1 + lf * (rise * t - 1.25 * t * t), top.z + dz * lf * t)
		for i in 4:
			var t0 := i / 4.0
			var t1 := (i + 1) / 4.0
			var w0 := 0.62 * sin(PI * minf(1.0, t0 * 1.15)) + 0.04
			var w1 := 0.62 * sin(PI * minf(1.0, t1 * 1.15)) + 0.04
			var c0: Vector3 = pt.call(t0)
			var c1: Vector3 = pt.call(t1)
			var L0 := c0 + Vector3(px * w0 / 2.0, -w0 * 0.25, pz * w0 / 2.0)
			var R0 := c0 + Vector3(-px * w0 / 2.0, -w0 * 0.25, -pz * w0 / 2.0)
			var L1 := c1 + Vector3(px * w1 / 2.0, -w1 * 0.25, pz * w1 / 2.0)
			var R1 := c1 + Vector3(-px * w1 / 2.0, -w1 * 0.25, -pz * w1 / 2.0)
			var col: Color = palme[f % 2]
			_quad(st, L0, c0, c1, L1, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col)
			_quad(st, c0, R0, R1, c1, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col)
	st.generate_normals()
	var m := st.commit()
	_cache.palmier = m
	return m


## Des palmiers instanciés (un appel de rendu) : [[x, z, ry, échelle, y]…].
static func palmiers(K, liste: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = forme_palmier()
	mm.instance_count = liste.size()
	for i in liste.size():
		var p: Array = liste[i]
		var b := Basis.from_euler(Vector3(0, p[2], 0)).scaled(Vector3.ONE * p[3])
		mm.set_instance_transform(i, Transform3D(b, Vector3(p[0], p[4] if p.size() > 4 else 0.0, p[1])))
	var mi := MultiMeshInstance3D.new()
	mi.name = "palmiers"
	mi.multimesh = mm
	mi.material_override = K.mat("palmier")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.zone.add_child(mi)
	return mi


# --- Voitures --------------------------------------------------------------------------------------

## Un pavé coloré (une pièce de voiture) : transformation, teinte, carrosserie (peinte par instance), lueur, poli.
static func _piece(st: SurfaceTool, t: Transform3D, col: Color, peinte := false, lueur := 0.0, poli := 0.5) -> void:
	var c := Color(col.srgb_to_linear(), 1.0 if peinte else 0.0)
	var u := Vector2(lueur, poli)
	var s := [Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, 0.5, -0.5), Vector3(-0.5, 0.5, -0.5),
		Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, 0.5, 0.5), Vector3(-0.5, 0.5, 0.5)]
	var v := []
	for p in s:
		v.append(t * p)
	_faces(st, v, c, u)


## Les six faces d'un hexaèdre (8 sommets dans l'ordre du pavé unité) : tronc de pyramide, pavé.
static func _faces(st: SurfaceTool, v: Array, c: Color, u: Vector2) -> void:
	var centre := Vector3.ZERO
	for p in v:
		centre += p / 8.0
	for f in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		var a: Vector3 = v[f[0]]
		var b: Vector3 = v[f[1]]
		var cc: Vector3 = v[f[2]]
		var d: Vector3 = v[f[3]]
		var n := (a + b + cc + d) / 4.0 - centre
		_quad(st, a, b, cc, d, n.normalized(), u, u, u, u, c)


## Un tronc de pyramide le long de x (E.frustum) : base L × W à y0, sommet (L − fa − fb) × Wt à y1, décalé de dx.
static func _tronc(st: SurfaceTool, L: float, W: float, Wt: float, y0: float, y1: float, fa: float, fb: float, dx: float, col: Color, peinte: bool, poli := 0.5) -> void:
	var x0 := -L / 2.0 + dx
	var x1 := L / 2.0 + dx
	var u0 := x0 + fb
	var u1 := x1 - fa
	var v := [Vector3(x0, y0, -W / 2.0), Vector3(x1, y0, -W / 2.0), Vector3(u1, y1, -Wt / 2.0), Vector3(u0, y1, -Wt / 2.0),
		Vector3(x0, y0, W / 2.0), Vector3(x1, y0, W / 2.0), Vector3(u1, y1, Wt / 2.0), Vector3(u0, y1, Wt / 2.0)]
	_faces(st, v, Color(col.srgb_to_linear(), 1.0 if peinte else 0.0), Vector2(0, poli))


static func _bx(st: SurfaceTool, w: float, h: float, d: float, x: float, y: float, z: float, col: Color, peinte := false, lueur := 0.0, poli := 0.5) -> void:
	_piece(st, Transform3D(Basis.from_scale(Vector3(w, h, d)), Vector3(x, y, z)), col, peinte, lueur, poli)


## La forme d'une voiture du type donné, l'avant vers +x (E.vehicleGeo) ; couleurs de sommet, carrosserie peinte.
static func forme_voiture(type: String) -> ArrayMesh:
	if _cache.has("v_" + type):
		return _cache["v_" + type]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d: Array = DIMS[type]
	var L: float = d[0]
	var W: float = d[1]
	var top: float = d[2]
	var verre := Color("#0E1420")
	var garni := Color("#121214")
	var phare := Color("#FFF4DC")
	var feu := Color("#FF1A1A")
	var pneu := Color("#111111")
	var jante := Color("#8A9098")
	var feux := func(yh: float, yt: float, hw: float, tw: float) -> void:
		for s in [-1.0, 1.0]:
			_bx(st, 0.06, 0.13, hw, L / 2.0 + 0.01, yh, s * (W / 2.0 - hw / 2.0 - 0.12), phare, false, 1.0)
			_bx(st, 0.06, 0.12, tw, -L / 2.0 - 0.01, yt, s * (W / 2.0 - tw / 2.0 - 0.1), feu, false, 0.8)
		_bx(st, 0.05, 0.12, 0.42, -L / 2.0 - 0.02, yt - 0.18, 0, Color("#E8E8E0"), false, 0.1)
	var roues := func(r: float, xs: Array) -> void:
		for x in xs:
			for s in [-1.0, 1.0]:
				_bx(st, r * 2.0, r * 2.0, 0.26, x, r, s * (W / 2.0 - 0.12), pneu, false, 0.0, 0.0)
				_bx(st, r * 1.2, r * 1.2, 0.04, x, r, s * W / 2.0, jante, false, 0.0, 0.9)
	if type == "bus":
		_tronc(st, L, W, W - 0.08, 0.45, 1.25, 0.05, 0.05, 0, Color.WHITE, true)
		_tronc(st, L - 0.1, W - 0.04, W - 0.1, 1.25, 2.55, 0.15, 0.02, 0, verre, false, 0.9)
		_bx(st, L - 1.2, 1.0, W - 0.18, -0.3, 1.88, 0, Color("#5A4020"), false, 0.5)
		_tronc(st, L - 0.2, W - 0.1, W - 0.3, 2.55, 3.2, 0.3, 0.1, 0, Color("#EDEDE8"), false)
		var x := -L / 2.0 + 1.4
		while x < L / 2.0 - 1.0:
			_bx(st, 0.08, 1.25, W - 0.02, x, 1.9, 0, garni)
			x += 1.6
		_bx(st, 0.05, 0.3, 1.6, L / 2.0 + 0.02, 2.75, 0, Color("#FF8A2A"), false, 1.0)
		_bx(st, L + 0.06, 0.22, W + 0.04, 0, 0.5, 0, garni)
		feux.call(0.85, 1.1, 0.34, 0.2)
		roues.call(0.5, [L / 2.0 - 2.4, -L / 2.0 + 2.8])
	else:
		var lo := 0.28 if type == "sport" else (0.42 if type == "suv" else 0.32)
		var belt := 0.78 if type == "sport" else (1.12 if type == "suv" else 0.88)
		var cab := L - 2.6 if type == "limo" else (L * 0.6 if type == "suv" else (L * 0.42 if type == "sport" else L * 0.5))
		var cab_x := -0.25 if type == "sport" else (-0.35 if type == "limo" else -0.2)
		_tronc(st, L, W, W - 0.06, lo, belt, 0.18, 0.12, 0, Color.WHITE, true, 0.9)
		_tronc(st, cab + (0.4 if type == "suv" else 0.9), W - 0.14, W - 0.42, belt, top, 0.4 if type == "suv" else 0.62, 0.12 if type == "suv" else 0.4, cab_x, verre, false, 0.95)
		_tronc(st, cab - 0.25, W - 0.4, W - 0.44, top - 0.06, top, 0.05, 0.05, cab_x - 0.05, Color.WHITE, true, 0.9)
		_bx(st, 0.12, lo + 0.06, W - 0.04, L / 2.0 - 0.02, lo / 2.0 + 0.06, 0, garni)
		_bx(st, 0.12, lo + 0.06, W - 0.04, -L / 2.0 + 0.02, lo / 2.0 + 0.06, 0, garni)
		_bx(st, 0.04, 0.2, 0.7, L / 2.0 + 0.04, lo + 0.26, 0, Color("#C8CCD2"), false, 0.0, 1.0)
		feux.call(lo + 0.32, lo + 0.36, 0.36, 0.3)
		if type == "taxi":
			_bx(st, 0.9, 0.22, 0.3, cab_x, top + 0.11, 0, Color("#FFD870"), false, 0.9)
		var r := 0.4 if type == "suv" else (0.34 if type == "sport" else 0.33)
		roues.call(r, [L / 2.0 - 1.3, -L / 2.0 + 1.3] if type == "limo" else [L / 2.0 - 1.0, -L / 2.0 + 1.05])
	var m := st.commit()
	_cache["v_" + type] = m
	return m


## Les voitures d'un type, instanciées (un appel de rendu) ; set_instance_custom_data porte leur peinture.
static func flotte(K, type: String, n: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = forme_voiture(type)
	mm.instance_count = n
	for i in n:
		mm.set_instance_color(i, Color.WHITE)
	var mi := MultiMeshInstance3D.new()
	mi.name = "voitures_" + type
	mi.multimesh = mm
	mi.material_override = K.mat("vehicule")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.zone.add_child(mi)
	return mm


## Une voiture garée (sous la porte-cochère) : sa place dans la flotte, sa peinture, et l'obstacle qu'elle fait.
static func garer(K, mm: MultiMesh, i: int, type: String, x: float, z: float, cap: float, couleur: String) -> void:
	mm.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(0, cap, 0)), Vector3(x, 0, z)))
	mm.set_instance_custom_data(i, Color(Color(couleur).srgb_to_linear(), 0.0))
	var d: Array = DIMS[type]
	if absf(sin(cap)) < 0.01:
		K.obstacle(x - d[0] / 2.0, x + d[0] / 2.0, z - d[1] / 2.0, z + d[1] / 2.0, 0.0, 1.6)
	else:
		K.solide(d[0], 1.6, d[1], x, 0.8, z, cap)


# --- La foule --------------------------------------------------------------------------------------

## Une silhouette basse de la foule (F.crowd) : jambes, tronc peint par instance, bras, tête ; debout, bras
## levés ou assis. Les pieds à y = 0, le visage vers −z.
static func forme_silhouette(pose: String) -> ArrayMesh:
	if _cache.has("f_" + pose):
		return _cache["f_" + pose]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bas := Color("#1E1E26")
	var peau := Color("#C89A78")
	var y0 := 0.0
	if pose == "assis":
		_bx(st, 0.34, 0.14, 0.5, 0, 0.42, -0.18, bas)
		_bx(st, 0.3, 0.42, 0.14, 0, 0.21, -0.4, bas)
		y0 = 0.45
	else:
		for s in [-1.0, 1.0]:
			_bx(st, 0.14, 0.82, 0.16, s * 0.1, 0.41, 0, bas)
		y0 = 0.82
	_bx(st, 0.42, 0.6, 0.24, 0, y0 + 0.3, 0, Color.WHITE, true)
	for s in [-1.0, 1.0]:
		if pose == "bras":
			_bx(st, 0.1, 0.6, 0.1, s * 0.27, y0 + 0.82, -0.04, Color.WHITE, true)
		else:
			_bx(st, 0.1, 0.56, 0.1, s * 0.27, y0 + 0.3, 0, Color.WHITE, true)
	_bx(st, 0.2, 0.24, 0.22, 0, y0 + 0.74, 0, peau)
	_bx(st, 0.21, 0.08, 0.23, 0, y0 + 0.88, 0.01, Color("#2A1A12"))
	var m := st.commit()
	_cache["f_" + pose] = m
	return m


## Une foule instanciée : [[x, y, z, ry]…] dans la pose donnée ; les hauts sont tirés dans les teintes du jeu web.
static func foule(K, places: Array, pose: String, graine: int, nom := "foule") -> MultiMeshInstance3D:
	var hauts := ["#7a1f2b", "#1f3a5f", "#2f5d50", "#c9a24a", "#e8e2d0", "#4a2d5e", "#24242a", "#b5482f", "#3c6e8f", "#cfcfd6", "#8c2f5a", "#d98a9a"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = forme_silhouette(pose)
	mm.instance_count = places.size()
	var h := RandomNumberGenerator.new()
	h.seed = graine
	var t0s: Array[Transform3D] = []
	for i in places.size():
		var p: Array = places[i]
		var s := 0.92 + h.randf() * 0.16
		t0s.append(Transform3D(Basis.from_euler(Vector3(0, p[3], 0)).scaled(Vector3.ONE * s), Vector3(p[0], p[1], p[2])))
		mm.set_instance_transform(i, t0s[i])
		var c := Color(hauts[h.randi() % hauts.size()]).srgb_to_linear()
		mm.set_instance_custom_data(i, Color(c.r, c.g, c.b, h.randf()))
		mm.set_instance_color(i, Color.WHITE)
	var mi := MultiMeshInstance3D.new()
	mi.name = nom
	mi.multimesh = mm
	# les places d'origine, pour les figurants qui prennent le relais de près (pnj/vie.gd, swapper)
	mi.set_meta("t0s", t0s)
	mi.material_override = K.mat("foule")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.zone.add_child(mi)
	return mi


# --- Faisceaux ---------------------------------------------------------------------------------------

## Un cône de lumière additif, de la source (pointe) vers +y local, long de l, d'ouverture r au bout.
static func faisceau(K, couleur: Color, gain: float, l: float, r: float, r0 := 0.3) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r0
	c.bottom_radius = r
	c.height = l
	c.radial_segments = 12
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	var m: ShaderMaterial = (K.mat("faisceau") as ShaderMaterial).duplicate()
	m.set_shader_parameter("couleur", couleur)
	m.set_shader_parameter("gain", gain)
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# La pointe à l'origine du pivot : le cylindre descend de l (UV.y = 1 en haut, à la source).
	var pivot := Node3D.new()
	mi.position = Vector3(0, -l / 2.0, 0)
	pivot.add_child(mi)
	K.zone.add_child(pivot)
	return mi
