extends RefCounted
## Les briques communes du lot B « L'ouest » (js/zones/b-0-commun.js) : l'enveloppe des salles (cloisons
## percées, habillage en trois registres, encadrements des liaisons), les enseignes, le mobilier (canapés,
## bancs, chaises, tables de jeu de décor), la végétation, les luminaires, les machines à sous, le bar,
## les toilettes. Toutes bâtissent avec le kit (K) dans la zone en cours.
## Un repère (« frame » du moteur web) est un tableau [x, z, rot] : un point local (lx, lz) y est en
## (x + lx cos rot + lz sin rot, z - lx sin rot + lz cos rot), comme un nœud tourné de rot autour de y ;
## un occupant assis regarde vers le -z local de son siège, comme un nœud Godot.

## Les néons adoucis du lot (B.NEON_DOUX), pour les enseignes.
const NEON := {"rose": Color("#FF6FA8"), "cyan": Color("#5FE6EE"), "ambre": Color("#FFC56A"), "rouge": Color("#FF5A6A"), "vert": Color("#6FFFAE"), "ivoire": Color("#FFE2B4")}
## Le côté d'une cloison : sa coordonnée fixe et la direction de son parement, dans les limites b.
const EP := 0.2

static var _formes := {}


# --- Formes de base ----------------------------------------------------------------------------------

## Un cylindre unité (rayon 1, haut de 1), qu'on étire en disque ou en plateau ovale (B.g.disc).
static func _disque() -> Mesh:
	if not _formes.has("disque"):
		var c := CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = 24
		c.rings = 1
		_formes["disque"] = c
	return _formes["disque"]


## Une boule basse (B.g.boule) et un octaèdre (B.g.octa) : ampoules, pampilles, feuillage.
static func _boule() -> Mesh:
	if not _formes.has("boule"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 8
		s.rings = 4
		_formes["boule"] = s
	return _formes["boule"]


static func _octa() -> Mesh:
	if not _formes.has("octa"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 4
		s.rings = 2
		_formes["octa"] = s
	return _formes["octa"]


## Une palme : un ruban qui retombe le long de +z, long de 1 (B.g.palme), vue des deux côtés.
static func _palme() -> Mesh:
	if not _formes.has("palme"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 4
		var pt := func(i: int) -> Array:
			var t := float(i) / n
			return [0.16 * (1.0 - 0.75 * t * t) + 0.02, 0.55 * t - 0.95 * t * t, t]
		for i in n:
			var a: Array = pt.call(i)
			var b: Array = pt.call(i + 1)
			for v in [[-a[0], a[1], a[2]], [a[0], a[1], a[2]], [b[0], b[1], b[2]], [-a[0], a[1], a[2]], [b[0], b[1], b[2]], [-b[0], b[1], b[2]]]:
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(v[0], v[1] - absf(v[0]) * 0.35, v[2]))
		_formes["palme"] = st.commit()
	return _formes["palme"]


static func disque(K, nom_mat: String, x: float, y: float, z: float, sx: float, sy: float, sz: float, ry := 0.0) -> void:
	K.put(nom_mat, _disque(), K.xf(x, y, z, 0, ry, 0, sx, sy, sz))


static func boule(K, nom_mat: String, t: Transform3D) -> void:
	K.put(nom_mat, _boule(), t)


static func octa(K, nom_mat: String, t: Transform3D) -> void:
	K.put(nom_mat, _octa(), t)


# --- Repères ------------------------------------------------------------------------------------------

## Le point local (lx, lz) du repère r, en coordonnées de la zone.
static func loc(r: Array, lx: float, lz: float) -> Vector2:
	var c := cos(r[2])
	var s := sin(r[2])
	return Vector2(r[0] + lx * c + lz * s, r[1] - lx * s + lz * c)


## Un repère posé dans un autre, en (lx, lz), tourné de lf.
static func sous(r: Array, lx: float, lz: float, lf: float) -> Array:
	var p := loc(r, lx, lz)
	return [p.x, p.y, r[2] + lf]


static func rbox(K, r: Array, nom_mat: String, w: float, h: float, d: float, lx: float, y: float, lz: float, lry := 0.0) -> void:
	var p := loc(r, lx, lz)
	K.box(nom_mat, w, h, d, p.x, y, p.y, r[2] + lry)


static func rcyl(K, r: Array, nom_mat: String, rh: float, rb: float, h: float, lx: float, y: float, lz: float, seg := 12) -> void:
	var p := loc(r, lx, lz)
	K.cyl(nom_mat, rh, rb, h, p.x, y, p.y, seg)


static func rdisque(K, r: Array, nom_mat: String, lx: float, y: float, lz: float, sx: float, sy: float, sz: float) -> void:
	var p := loc(r, lx, lz)
	disque(K, nom_mat, p.x, y, p.y, sx, sy, sz, r[2])


## Un pavé de collision dans un repère.
static func rsolide(K, r: Array, w: float, h: float, d: float, lx: float, lz: float) -> void:
	var p := loc(r, lx, lz)
	K.solide(w, h, d, p.x, h / 2.0, p.y, r[2])


# --- Enveloppe ----------------------------------------------------------------------------------------

## Les quatre cloisons d'une salle (K.shell), de 20 cm, à l'intérieur de ses limites b {x0, x1, z0, z1} :
## ouv[côté] = [{at, w, h}] (at : x pour nord et sud, z pour ouest et est), absent : pleine, false : aucune.
static func coque(K, b: Dictionary, H: float, nom_mat: String, ouv: Dictionary) -> void:
	var e := EP / 2.0
	var cotes := {
		"north": [b.x0, b.z0 + e, b.x1, b.z0 + e, 0.0, 1.0, b.x0],
		"south": [b.x0, b.z1 - e, b.x1, b.z1 - e, 0.0, -1.0, b.x0],
		"west": [b.x0 + e, b.z0, b.x0 + e, b.z1, 1.0, 0.0, b.z0],
		"east": [b.x1 - e, b.z0, b.x1 - e, b.z1, -1.0, 0.0, b.z0],
	}
	for cote in cotes:
		var o = ouv.get(cote, [])
		if o is bool:
			continue
		var c: Array = cotes[cote]
		var ops := []
		for op in o:
			ops.append({"at": op.at - c[6], "w": op.w, "h": op.get("h", 2.4)})
		K.mur(c[0], c[1], c[2], c[3], H, c[4], c[5], ops, nom_mat, 0.0, false)


## Les intervalles pleins de [a0, a1] une fois retirées les ouvertures [{at, w}] (B.spans).
static func pleins(a0: float, a1: float, ops: Array, marge := 0.0) -> Array:
	var out := []
	var s := a0
	var tri := ops.duplicate()
	tri.sort_custom(func(p, q): return p.at < q.at)
	for op in tri:
		var a: float = op.at - op.w / 2.0 - marge
		var bb: float = op.at + op.w / 2.0 + marge
		if a > s:
			out.append([s, minf(a, a1)])
		s = maxf(s, bb)
	if s < a1:
		out.append([s, a1])
	return out.filter(func(q): return q[1] - q[0] > 0.05)


## L'habillage intérieur des cloisons, en trois registres (B.habille) : soubassement saillant et cimaise,
## corniche en ressaut avec sa gorge lumineuse, pilastres à applique. o : socle, socle_h (1), socle_d (0,06),
## cimaise (« or », false), corniche (true), gorge (« gorge »), pil (pas, 4,5 ; false), pil_mat, applique
## (true, false ou « alt »), skip {côté: [{at, w}]}. Rend les pilastres posés [{x, z, nx, nz}].
static func habille(K, b: Dictionary, H: float, ouv: Dictionary, o := {}) -> Array:
	var t := EP
	var hs: float = o.get("socle_h", 1.0)
	var sd: float = o.get("socle_d", 0.06)
	var S := {
		"north": {"a0": b.x0 + t, "a1": b.x1 - t, "fix": b.z0 + t, "d": 1.0, "ax": false, "ry": 0.0},
		"south": {"a0": b.x0 + t, "a1": b.x1 - t, "fix": b.z1 - t, "d": -1.0, "ax": false, "ry": PI},
		"west": {"a0": b.z0 + t, "a1": b.z1 - t, "fix": b.x0 + t, "d": 1.0, "ax": true, "ry": PI / 2.0},
		"east": {"a0": b.z0 + t, "a1": b.z1 - t, "fix": b.x1 - t, "d": -1.0, "ax": true, "ry": -PI / 2.0},
	}
	var poses := []
	for nom in S:
		var ops = ouv.get(nom, [])
		if ops is bool or o.get(nom, null) is bool:
			continue
		var s: Dictionary = S[nom]
		var pt := func(a: float, off: float) -> Vector2:
			return Vector2(s.fix + s.d * off, a) if s.ax else Vector2(a, s.fix + s.d * off)
		var barre := func(m: String, a0: float, a1: float, y: float, hh: float, dd: float, off := -1.0):
			var p: Vector2 = pt.call((a0 + a1) / 2.0, dd / 2.0 if off < 0.0 else off)
			if s.ax:
				K.box(m, dd, hh, a1 - a0, p.x, y, p.y)
			else:
				K.box(m, a1 - a0, hh, dd, p.x, y, p.y)
		if hs > 0.0:
			for q in pleins(s.a0, s.a1, ops):
				barre.call(o.get("socle", "marbre_noir"), q[0], q[1], hs / 2.0, hs, sd)
				if not (o.get("cimaise", "or") is bool):
					barre.call(o.get("cimaise", "or"), q[0], q[1], hs + 0.025, 0.05, sd + 0.025)
		if o.get("corniche", true):
			var hauts: Array = ops.filter(func(op): return op.get("h", 2.4) > H - 0.8)
			for q in pleins(s.a0, s.a1, hauts):
				barre.call("or", q[0], q[1], H - 0.1, 0.2, 0.3)
				barre.call("laque_noire", q[0], q[1], H - 0.31, 0.22, 0.16)
				barre.call(o.get("gorge", "gorge"), q[0], q[1], H - 0.45, 0.04, 0.04, 0.2)
		if o.get("pil", 4.5) is bool:
			continue
		var pas: float = o.get("pil", 4.5)
		var L: float = s.a1 - s.a0
		var n := maxi(1, roundi(L / pas))
		var liste := []
		var evite: Array = ops.duplicate()
		evite.append_array(o.get("skip", {}).get(nom, []))
		var libre := func(a: float) -> bool:
			if a < s.a0 + 0.2 or a > s.a1 - 0.2:
				return false
			for op in evite:
				if absf(a - op.at) < op.w / 2.0 + 0.38:
					return false
			for v in liste:
				if absf(v - a) < 1.3:
					return false
			return true
		for op in ops:
			for k in [-1.0, 1.0]:
				var a: float = op.at + k * (op.w / 2.0 + 0.5)
				if libre.call(a):
					liste.append(a)
		for i in n + 1:
			var a: float = s.a0 + 0.36 if i == 0 else (s.a1 - 0.36 if i == n else s.a0 + i * L / n)
			if libre.call(a):
				liste.append(a)
		var applique = o.get("applique", true)
		for i in liste.size():
			var p: Vector2 = pt.call(liste[i], 0.0)
			pilastre(K, p.x, p.y, s.ry, H - 0.42, o.get("pil_mat", "marbre_creme"))
			if applique is bool and applique or (applique is String and i % 2 == 0):
				K.lanterne(p.x + sin(s.ry) * 0.31, 2.6, p.y + cos(s.ry) * 0.31, 0.4)
			poses.append({"x": p.x, "z": p.y, "nx": s.d if s.ax else 0.0, "nz": 0.0 if s.ax else s.d})
	return poses


## Un pilastre de la matière donnée, contre une cloison : (x, z) au pied de la face collée, ry où il regarde.
static func pilastre(K, x: float, z: float, ry: float, h: float, nom_mat := "marbre_creme") -> void:
	var d := 0.15
	var px := x + sin(ry) * d / 2.0
	var pz := z + cos(ry) * d / 2.0
	K.box(nom_mat, 0.6, h, d, px, h / 2.0, pz, ry)
	K.box("or", 0.68, 0.12, d + 0.06, px, 0.06, pz, ry)
	K.box("or", 0.68, 0.14, d + 0.06, px, h - 0.4, pz, ry)


## L'encadrement d'une liaison sur l'épaisseur du mur double (B.encadre) : axis « z » (plan z = plane, baie
## le long de x) ou « x » ; tableaux et chambranles dorés des deux côtés, frise au sol, rideaux, fronton.
static func encadre(K, axis: String, plane: float, c: float, w: float, h: float, o := {}) -> void:
	var m: String = o.get("mat", "laque_noire")
	var za := axis == "z"
	var bx := func(nm: String, la: float, lh: float, lp: float, a: float, y: float, p: float):
		if za:
			K.box(nm, la, lh, lp, a, y, plane + p)
		else:
			K.box(nm, lp, lh, la, plane + p, y, a)
	for s in [-1.0, 1.0]:
		bx.call(m, 0.07, h, 0.42, c + s * (w / 2.0 - 0.035), h / 2.0, 0.0)
	bx.call(m, w, 0.07, 0.42, c, h - 0.035, 0.0)
	for f in [-1.0, 1.0]:
		for s in [-1.0, 1.0]:
			bx.call("or", 0.16, h + 0.16, 0.05, c + s * (w / 2.0 + 0.08), (h + 0.16) / 2.0, f * 0.215)
		bx.call("or", w + 0.32, 0.16, 0.05, c, h + 0.08, f * 0.215)
		if o.get("fronton", 0.0) > 0.0:
			var fr: float = o.fronton
			bx.call(m, w + 0.5, fr, 0.04, c, h + 0.16 + fr / 2.0, f * 0.21)
	if o.has("rideaux"):
		for s in [-1.0, 1.0]:
			for i in 3:
				bx.call(o.rideaux, 0.22, h - 0.1, 0.16 + i * 0.06, c + s * (w / 2.0 - 0.2 - i * 0.2), (h - 0.1) / 2.0, 0.0)
			bx.call("or", 0.7, 0.05, 0.3, c + s * (w / 2.0 - 0.36), h * 0.42, 0.0)
	if za:
		K.seuil(c - w / 2.0, plane, c + w / 2.0, plane)
	else:
		K.seuil(plane, c - w / 2.0, plane, c + w / 2.0)


## Une voûte en berceau vue de dessous (B.voute), l'axe le long de x, la portée le long de z ; y0 la naissance.
static func voute(K, nom_mat: String, x0: float, x1: float, z0: float, z1: float, y0: float, fleche: float, seg := 12) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := (z1 - z0) / 2.0
	var cz := (z0 + z1) / 2.0
	for i in seg:
		var a0 := PI * i / seg
		var a1 := PI * (i + 1) / seg
		var p := func(x: float, a: float) -> Vector3: return Vector3(x, y0 + fleche * sin(a), cz - r * cos(a))
		var n := Vector3(0, -sin((a0 + a1) / 2.0), cos((a0 + a1) / 2.0))
		# UV du berceau du moteur web (demi-cylindre) : u autour de l'arc, v le long de la voûte.
		var u0 := float(i) / seg
		var u1 := float(i + 1) / seg
		K._quad(st, p.call(x0, a0), p.call(x1, a0), p.call(x1, a1), p.call(x0, a1), n, Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0))
	K.put(nom_mat, st.commit())


## Une enseigne (E.add) : néon de couleur, lettres d'or (« or »), plaque laquée (« plaque ») ; ry : la
## direction d'où on la lit (0 = depuis +z) ; deux faces si two.
static func enseigne(K, t: String, x: float, y: float, z: float, ry: float, w: float, h: float, style := "neon", couleur := "ambre", two := false) -> void:
	for face in ([0.0, PI] if two else [0.0]):
		var a: float = ry + face
		if style == "neon":
			K.texte(t, w, h * 0.8, x, y, z, a, "neon", NEON.get(couleur, NEON.ambre))
		else:
			K.texte(t, w * 0.9, h * 0.7, x + sin(a) * 0.012, y, z + cos(a) * 0.012, a, "grave")
	if style == "plaque":
		K.box("laque_noire", w, h, 0.02, x, y, z, ry)


## Un panneau mural encadré d'or (K.wallPanel), (x, z) contre le mur, ry la direction où il regarde.
static func panneau(K, x: float, y: float, z: float, ry: float, w: float, h: float, fond: String, glow := false) -> void:
	var nx := sin(ry)
	var nz := cos(ry)
	K.box(fond, w, h, 0.03, x + nx * 0.02, y, z + nz * 0.02, ry)
	for s in [-1.0, 1.0]:
		K.box("or", w + 0.1, 0.05, 0.05, x + nx * 0.04, y + s * h / 2.0, z + nz * 0.04, ry)
		K.box("or", 0.05, h, 0.05, x + nx * 0.04 + cos(ry) * s * w / 2.0, y, z + nz * 0.04 - sin(ry) * s * w / 2.0, ry)
	if glow:
		K.box("gorge", w - 0.2, 0.03, 0.03, x + nx * 0.07, y - h / 2.0 + 0.08, z + nz * 0.07, ry)


## Une porte de toilettes battante, ouverte contre le tableau : (x, z) le milieu de la baie dans un mur
## de normale (nx, nz) côté salle ; le battant s'ouvre vers la salle.
static func porte_ouverte(K, x: float, z: float, nx: float, nz: float, w: float, h: float) -> void:
	var tx := -nz
	var tz := nx
	var cx := x + tx * w / 2.0 + nx * w / 2.0
	var cz := z + tz * w / 2.0 + nz * w / 2.0
	K.box("laque_rouge", 0.04, h, w, cx, h / 2.0, cz, atan2(nx, nz))
	K.box("or", 0.06, 0.12, 0.03, cx + nx * 0.1, 1.05, cz + nz * 0.1)


# --- Mobilier ----------------------------------------------------------------------------------------

## Canapé (w > 1,2) ou fauteuil (B.sofa), dans le repère r de l'occupant.
static func canape(K, r: Array, w: float, nom_mat: String) -> void:
	rbox(K, r, "laque_noire", w - 0.14, 0.1, 0.68, 0, 0.05, 0.02)
	rbox(K, r, "or", w + 0.02, 0.025, 0.86, 0, 0.112, 0)
	rbox(K, r, nom_mat, w, 0.32, 0.84, 0, 0.285, 0)
	rbox(K, r, nom_mat, w, 0.5, 0.2, 0, 0.69, 0.34)
	for k in [-1.0, 1.0]:
		rbox(K, r, nom_mat, 0.17, 0.24, 0.84, k * (w / 2.0 - 0.085), 0.565, 0)
	rsolide(K, r, w, 0.9, 0.8, 0, 0.05)


## Banc sans dossier (B.banc).
static func banc(K, r: Array, w: float, nom_mat := "marbre_creme") -> void:
	rbox(K, r, nom_mat, w, 0.1, 0.5, 0, 0.41, 0)
	for k in [-1.0, 1.0]:
		rbox(K, r, nom_mat, 0.14, 0.36, 0.42, k * (w / 2.0 - 0.2), 0.18, 0)
	rbox(K, r, "or", w - 0.5, 0.04, 0.05, 0, 0.3, 0)
	rsolide(K, r, w, 0.5, 0.5, 0, 0)


static func table_basse(K, x: float, z: float, r: float, nom_mat := "marbre_noir") -> void:
	disque(K, nom_mat, x, 0.44, z, r, 0.05, r)
	K.cyl("or", 0.05, 0.05, 0.4, x, 0.21, z, 8)
	disque(K, "or", x, 0.015, z, r * 0.6, 0.03, r * 0.6)
	K.rond(x, z, r * 0.75, 0.0, 0.5)


## Chaise de jeu (B.chaise), dans le repère r de l'occupant.
static func chaise(K, r: Array, nom_mat: String) -> void:
	rbox(K, r, nom_mat, 0.46, 0.09, 0.46, 0, 0.455, 0)
	rbox(K, r, nom_mat, 0.46, 0.5, 0.07, 0, 0.74, 0.22)
	rbox(K, r, "laque_noire", 0.34, 0.41, 0.34, 0, 0.205, 0)


## Tabouret de bar ou de machine (B.tabouret).
static func tabouret(K, x: float, z: float, h: float, nom_mat: String) -> void:
	K.cyl("laque_noire", 0.2, 0.22, 0.03, x, 0.015, z, 8)
	K.cyl("or", 0.03, 0.03, h - 0.1, x, (h - 0.1) / 2.0, z, 6)
	K.cyl(nom_mat, 0.2, 0.18, 0.09, x, h - 0.045, z, 10)


## Lampe de table : pied d'or, abat-jour lumineux (B.lampe).
static func lampe(K, x: float, y: float, z: float, s := 1.0) -> void:
	K.cyl("or", 0.03 * s, 0.07 * s, 0.3 * s, x, y + 0.15 * s, z, 6)
	K.cyl("gorge", 0.09 * s, 0.15 * s, 0.2 * s, x, y + 0.4 * s, z, 8)


## Un salon : des sièges autour d'une table basse (B.salon). items : [{k: sofa | fauteuil | banc, x, z, f, n, w}]
## en local ; o : mat, table [x, z, r], table_mat, banc_mat, lampe. Rend les places [[Vector3 assise, rot]].
static func salon(K, x: float, z: float, rot: float, items: Array, o := {}) -> Array:
	var g := [x, z, rot]
	var places := []
	for it in items:
		var n: int = it.get("n", 1)
		var f: float = it.get("f", 0.0)
		var w: float = it.get("w", 0.8 * n if it.k == "banc" else (0.72 * n + 0.36 if n > 1 else 0.92))
		var r := sous(g, it.x, it.z, f)
		if it.k == "banc":
			banc(K, r, w, o.get("banc_mat", "marbre_creme"))
		else:
			canape(K, r, w, o.get("mat", "cuir"))
		var pas: float = w / n if it.k == "banc" else (w - 0.36) / n
		for i in n:
			var p := loc(r, (i - (n - 1) / 2.0) * pas, 0.0)
			places.append([Vector3(p.x, 0.46 if it.k == "banc" else 0.45, p.y), r[2]])
	if o.has("table"):
		var t: Array = o.table
		var p := loc(g, t[0], t[1])
		table_basse(K, p.x, p.y, t[2], o.get("table_mat", "marbre_noir"))
		if o.get("lampe", false):
			lampe(K, p.x, 0.465, p.y, 0.8)
	return places


## Une table de jeu ovale de décor (B.tableJeu) : plateau a × b (demi-axes), sièges aux angles donnés (en
## degrés depuis +z local), croupier côté -z ; closed : sous housse. Rend {sieges: [[Vector3, rot]], croupier: [Vector3, rot]}.
static func table_jeu(K, x: float, z: float, rot: float, o: Dictionary) -> Dictionary:
	var g := [x, z, rot]
	var a: float = o.a
	var b: float = o.b
	var top: float = o.get("top", 0.78)
	var ferme: bool = o.get("closed", false)
	if ferme:
		rdisque(K, g, "housse", 0, top - 0.13, 0, a + 0.15, 0.42, b + 0.15)
		rdisque(K, g, "housse", 0, top + 0.1, 0, a + 0.05, 0.04, b + 0.05)
	else:
		rdisque(K, g, o.get("rim", "cuir"), 0, top - 0.035, 0, a + 0.12, 0.11, b + 0.12)
		rdisque(K, g, "or", 0, top - 0.11, 0, a + 0.03, 0.04, b + 0.03)
		rdisque(K, g, o.get("felt", "feutre_hl"), 0, top + 0.02, 0, a - 0.03, 0.012, b - 0.03)
		rbox(K, g, "or", 0.5, 0.03, 0.12, 0, top + 0.04, -b + 0.2)
	for s in [-1.0, 1.0]:
		rcyl(K, g, "laque_noire", 0.14, 0.22, top - 0.12, s * (a - b) * 0.85, (top - 0.12) / 2.0, 0, 8)
	rbox(K, g, "laque_noire", 2.0 * (a - b) + 0.7, 0.06, 0.55, 0, 0.03, 0)
	var sieges := []
	var angles: Array = o.angles
	for i in angles.size():
		var t: float = deg_to_rad(angles[i])
		if ferme and i % 2 == 1:
			continue
		var k := 0.18 if ferme else 0.5
		var r := sous(g, sin(t) * (a + k), cos(t) * (b + k), t)
		chaise(K, r, o.get("chaise", "cuir"))
		if not ferme:
			sieges.append([Vector3(r[0], 0.5, r[1]), r[2]])
	for k in [-1.0, 0.0, 1.0]:
		var p := loc(g, k * (a - b), 0)
		K.rond(p.x, p.y, b + 0.1, 0.0, 1.0)
	var c := loc(g, 0, -(b + 0.5))
	return {"sieges": sieges, "croupier": [Vector3(c.x, 0, c.y), rot + PI]}


# --- Végétation, luminaires ---------------------------------------------------------------------------

## Un palmier en pot (B.palmier). o : h (3), seed, pot (« or »), collide (true).
static func palmier(K, x: float, z: float, o := {}) -> void:
	var h: float = o.get("h", 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(o.get("seed", 1)) * 131
	K.cyl(o.get("pot", "or"), 0.34, 0.24, 0.6, x, 0.3, z, 10)
	K.cyl("terre", 0.3, 0.3, 0.04, x, 0.6, z, 10)
	var px := x
	var pz := z
	for i in 3:
		var sh := (h - 0.9) / 3.0
		K.cyl("tronc", 0.07 - i * 0.012, 0.09 - i * 0.012, sh, px, 0.6 + sh * (i + 0.5), pz, 6)
		px += (rng.randf() - 0.5) * 0.08
		pz += (rng.randf() - 0.5) * 0.08
	for i in 11:
		var a := i * TAU / 11.0 + rng.randf() * 0.4
		var L := 1.15 + rng.randf() * 0.5
		K.put("feuille" if i % 2 else "feuille_sombre", _palme(), K.xf(px, h - 0.32 + (i % 3) * 0.06, pz, -0.3 - (i % 3) * 0.2, a, 0, L * 0.95, L, L))
	if o.get("collide", true):
		K.rond(x, z, 0.4)


## Un arbre taillé en boules, en caisse (B.topiaire).
static func topiaire(K, x: float, z: float, h := 2.2, pot := "pierre") -> void:
	K.box(pot, 0.6, 0.55, 0.6, x, 0.275, z)
	K.box("or", 0.64, 0.05, 0.64, x, 0.5, z)
	K.cyl("tronc", 0.04, 0.05, h - 1.2, x, 0.55 + (h - 1.2) / 2.0, z, 6)
	boule(K, "feuille_sombre", K.xf(x, h - 0.75, z, 0, 0, 0, 0.5, 0.48, 0.5))
	boule(K, "feuille", K.xf(x, h - 0.22, z, 0, 0.6, 0, 0.3, 0.3, 0.3))
	K.rond(x, z, 0.42)


## Un lustre en anneau (B.lustre) : y le bas, R le rayon, n ampoules, cord la tige jusqu'au plafond H.
static func lustre(K, x: float, y: float, z: float, H: float, R := 1.0, n := 10, cord := 0.8) -> void:
	K.tore("or", R, 0.035 * R + 0.01, K.xf(x, y, z), 24)
	K.tore("or", R * 0.55, 0.035 * R + 0.01, K.xf(x, y + 0.4 * R, z), 18)
	for i in n:
		var a := float(i) / n * TAU
		octa(K, "ampoule", K.xf(x + cos(a) * R, y - 0.1, z + sin(a) * R, 0, a, 0, 0.07, 0.11, 0.07))
		if i % 2:
			octa(K, "ampoule", K.xf(x + cos(a) * R * 0.55, y + 0.4 * R - 0.09, z + sin(a) * R * 0.55, 0, a, 0, 0.06, 0.09, 0.06))
	for i in 3:
		var a := i * TAU / 3.0
		K.beam("or", Vector3(x + cos(a) * R, y, z + sin(a) * R), Vector3(x, y + cord, z), 0.015, 0.015)
	K.cyl("or", 0.015, 0.015, maxf(0.05, H - y - cord), x, (H + y + cord) / 2.0, z, 5)


## Une suspension de table (B.suspension) : cordon, abat-jour d'or, disque lumineux ; y le bas.
static func suspension(K, x: float, z: float, H: float, y := 2.3, r := 0.42) -> void:
	var cord := H - y - 0.16
	K.cyl("laque_noire", 0.01, 0.01, cord, x, y + 0.16 + cord / 2.0, z, 5)
	K.cyl("or", r * 0.25, r, 0.26, x, y + 0.05, z, 12)
	disque(K, "ampoule", x, y - 0.075, z, r * 0.86, 0.02, r * 0.86)


# --- Bar, machines, ascenseur, toilettes --------------------------------------------------------------

## Un bar droit (K.bar) : comptoir de laque et de marbre noir, arrière-bar aux bouteilles côté -z local,
## tabourets côté +z. Rend {tabourets: [Vector2], barman: [Vector3, Vector3]} (le va-et-vient du barman).
static func bar(K, x: float, z: float, rot: float, long: float, H: float) -> Dictionary:
	var g := [x, z, rot]
	rbox(K, g, "laque_noire", long, 1.05, 0.6, 0, 0.525, 0)
	rbox(K, g, "marbre_noir", long + 0.1, 0.06, 0.8, 0, 1.08, 0.05)
	rbox(K, g, "or", long, 0.05, 0.05, 0, 0.2, 0.42)
	rbox(K, g, "gorge", long - 0.1, 0.04, 0.04, 0, 0.05, 0.33)
	rsolide(K, g, long + 0.1, 1.1, 0.8, 0, 0.05)
	# L'arrière-bar : trois étagères de bouteilles qui luisent, un miroir, une corniche d'or.
	var dz := -2.9
	rbox(K, g, "bois_laque", long, 0.9, 0.5, 0, 0.45, dz)
	rbox(K, g, "miroir", long - 0.4, 1.6, 0.03, 0, 1.9, dz - 0.2)
	for j in 3:
		rbox(K, g, "or", long - 0.4, 0.03, 0.3, 0, 1.25 + j * 0.5, dz - 0.05)
		var i := 0
		var bx := -long / 2.0 + 0.4
		while bx < long / 2.0 - 0.4:
			rbox(K, g, ["neon_ambre", "lotus", "gorge", "ampoule"][(i + j) % 4], 0.07, 0.28, 0.07, bx, 1.4 + j * 0.5, dz - 0.05)
			bx += 0.16
			i += 1
	rbox(K, g, "or", long, 0.14, 0.6, 0, 2.85, dz)
	rsolide(K, g, long, 2.9, 0.6, 0, dz)
	var tabourets := []
	var n := int(long / 0.9)
	for i in n:
		var p := loc(g, (i - (n - 1) / 2.0) * 0.9, 0.85)
		tabourets.append(p)
		tabouret(K, p.x, p.y, 0.76, "coussin")
	var a := loc(g, -long / 2.0 + 0.8, -1.4)
	var b := loc(g, long / 2.0 - 0.8, -1.4)
	return {"tabourets": tabourets, "barman": [Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y)]}


## Une machine à sous de décor (K.slotMachine, K.slotDeco) : la face vers le +z local, son tabouret devant.
## ecran : « ecran », « ecran_rose » ou « ecran_or ». Rend la place du joueur [Vector3, rot].
static func machine(K, x: float, z: float, rot: float, ecran: String, caisse: String) -> Array:
	var g := [x, z, rot]
	rbox(K, g, "laque_noire", 0.66, 0.92, 0.56, 0, 0.46, 0)
	rbox(K, g, caisse, 0.64, 1.0, 0.5, 0, 1.42, -0.03)
	rbox(K, g, ecran, 0.5, 0.42, 0.02, 0, 1.52, 0.23)
	rbox(K, g, "or", 0.56, 0.05, 0.04, 0, 1.76, 0.23)
	rbox(K, g, "or", 0.56, 0.05, 0.04, 0, 1.28, 0.23)
	rbox(K, g, "or", 0.6, 0.06, 0.3, 0, 0.95, 0.3)
	rbox(K, g, ecran, 0.6, 0.32, 0.36, 0, 2.08, -0.03)
	rbox(K, g, "or", 0.64, 0.05, 0.4, 0, 2.26, -0.03)
	var p := loc(g, 0, 0.82)
	tabouret(K, p.x, p.y, 0.7, "coussin")
	return [Vector3(p.x, 0.7, p.y), rot]


## La gaine de l'ascenseur panoramique ouest (B.gaineA, ASC-A) : [-21, -18] × [9, 12], vitrée, porte
## sur x = -18. Les cabines viendront plus tard : les portes sont closes.
static func gaine(K, H: float) -> void:
	for p in [[-20.93, 9.07], [-18.27, 9.07], [-20.93, 11.73]]:
		K.box("or", 0.14, H, 0.14, p[0], H / 2.0, p[1])
	K.box("verre", 2.52, H - 0.78, 0.03, -19.6, 0.33 + (H - 0.78) / 2.0, 9.05)
	K.box("verre", 0.03, H - 0.78, 2.52, -20.95, 0.33 + (H - 0.78) / 2.0, 10.4)
	for q in [[2.66, 0.09, -19.6, 9.06], [0.09, 2.66, -20.94, 10.4]]:
		K.box("laque_noire", q[0], 0.33, q[1], q[2], 0.165, q[3])
		K.box("or", q[0], 0.05, q[1], q[2], 0.355, q[3])
		K.box("laque_noire", q[0], 0.45, q[1], q[2], H - 0.225, q[3])
	K.box("onyx", 2.5, H - 0.3, 0.02, -19.6, H / 2.0, 11.78)
	K.box("laque_noire", 0.06, 2.3, 1.5, -18.12, 1.15, 10.5)
	K.box("or", 0.08, 2.4, 1.6, -18.1, 1.2, 10.5)
	K.obstacle(-21, -18, 9, 12, 0.0, H)


## Des toilettes (B.toilettes) : repère à la porte, -z local entre dans la pièce. o : x, z, rot, W, D,
## cabins, sinks, open (cabines à porte ouverte), H. Mur-chicane derrière la porte, lavabos au revers,
## cabines au fond.
static func toilettes(K, o: Dictionary) -> void:
	var g := [o.x, o.z, o.rot]
	var W: float = o.W
	var D: float = o.D
	var H: float = o.H
	var n: int = o.cabins
	var cw := minf(1.35, (W - 0.6) / n)
	var cd := 1.65
	var zc := -D + 0.2 + cd
	var x0 := -n * cw / 2.0
	var zs := -1.9
	var sw := minf(W - 3.4, o.sinks * 1.25 + 0.4)
	rbox(K, g, "faience", sw, H, 0.2, 0, H / 2.0, zs)
	rsolide(K, g, sw, H, 0.2, 0, zs)
	rbox(K, g, "marbre_noir", sw + 0.06, 0.12, 0.26, 0, 0.06, zs)
	rbox(K, g, "marbre_noir", sw - 0.2, 0.08, 0.56, 0, 0.86, zs - 0.38)
	rbox(K, g, "laque_noire", sw - 0.4, 0.5, 0.4, 0, 0.5, zs - 0.34)
	rbox(K, g, "miroir", sw - 0.5, 1.25, 0.03, 0, 1.75, zs - 0.115)
	rbox(K, g, "or", sw - 0.4, 0.06, 0.05, 0, 2.42, zs - 0.12)
	rbox(K, g, "or", sw - 0.4, 0.06, 0.05, 0, 1.1, zs - 0.12)
	rbox(K, g, "gorge", sw - 0.6, 0.05, 0.06, 0, 2.52, zs - 0.13)
	rbox(K, g, "miroir", 1.1, 1.9, 0.03, 0, 1.45, zs + 0.115)
	rbox(K, g, "or", 1.24, 2.04, 0.02, 0, 1.45, zs + 0.105)
	rbox(K, g, "marbre_noir", 1.5, 0.06, 0.34, 0, 0.82, zs + 0.27)
	for i in o.sinks:
		var sx: float = (i - (o.sinks - 1) / 2.0) * ((sw - 0.6) / o.sinks)
		rdisque(K, g, "porcelaine", sx, 0.93, zs - 0.38, 0.22, 0.1, 0.17)
		rcyl(K, g, "or", 0.015, 0.02, 0.2, sx, 1.0, zs - 0.2, 6)
	for i in n + 1:
		rbox(K, g, "laque_noire", 0.05, 2.1, cd, x0 + i * cw, 1.15, zc - cd / 2.0)
		rsolide(K, g, 0.08, 2.2, cd, x0 + i * cw, zc - cd / 2.0)
	rbox(K, g, "or", n * cw + 0.1, 0.06, 0.08, 0, 2.23, zc)
	rbox(K, g, "laque_noire", n * cw + 0.05, 0.22, 0.05, 0, 2.37, zc)
	var ouvertes: Array = o.get("open", [])
	for i in n:
		var cx := x0 + (i + 0.5) * cw
		rbox(K, g, "laque_noire", 0.2, 2.1, 0.05, x0 + i * cw + 0.1, 1.15, zc)
		rbox(K, g, "laque_noire", 0.2, 2.1, 0.05, x0 + (i + 1) * cw - 0.1, 1.15, zc)
		if i in ouvertes:
			rbox(K, g, "laque_rouge", 0.04, 2.0, cw - 0.44, x0 + i * cw + 0.24, 1.15, zc - (cw - 0.44) / 2.0 - 0.02)
		else:
			rbox(K, g, "laque_rouge", cw - 0.42, 2.0, 0.04, cx, 1.15, zc)
			rbox(K, g, "or", 0.04, 0.12, 0.03, cx + cw / 2.0 - 0.3, 1.05, zc + 0.035)
			rsolide(K, g, cw - 0.4, 2.1, 0.06, cx, zc)
		rbox(K, g, "porcelaine", 0.38, 0.4, 0.5, cx, 0.2, zc - cd + 0.5)
		rbox(K, g, "porcelaine", 0.42, 0.5, 0.16, cx, 0.65, zc - cd + 0.2)
		rbox(K, g, "laque_noire", 0.4, 0.03, 0.46, cx, 0.415, zc - cd + 0.52)
