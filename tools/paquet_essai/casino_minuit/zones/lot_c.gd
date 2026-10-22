extends RefCounted
## Les briques communes du lot C « L'est » (js/zones/c-0-commun.js) : sols et plafonds troués de trémies,
## voiles courbes (écoinçons d'arche, jouées d'escalator), encadrements de baie, registres de mur, petit
## mobilier (chaises, fauteuils, potelets, bancs, mange-debout), tables de jeu de la fosse (blackjack,
## roulette, roue de la fortune), rampes d'escalator. Toutes bâtissent avec le kit (K) dans la zone en cours ;
## les palmiers, topiaires, enseignes et salons viennent du lot B (lot_b.gd).
## Orientation d'une personne (« f ») : elle regarde vers (-sin f, -cos f), comme un nœud Godot tourné de f.

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"


static func B():
	return load(LOT_B)


# --- Sols, plafonds -----------------------------------------------------------------------------------

## Les cellules d'un rectangle découpé autour de trémies {x0, x1, z0, z1} : [[x0, x1, z0, z1]].
static func cellules(x0: float, x1: float, z0: float, z1: float, trous: Array) -> Array:
	var xs := [x0, x1]
	var zs := [z0, z1]
	for h in trous:
		for v in [h.x0, h.x1]:
			if v > x0 + 1e-6 and v < x1 - 1e-6:
				xs.append(v)
		for v in [h.z0, h.z1]:
			if v > z0 + 1e-6 and v < z1 - 1e-6:
				zs.append(v)
	xs.sort()
	zs.sort()
	var out := []
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			var a: float = xs[i]
			var b: float = xs[i + 1]
			var c: float = zs[j]
			var d: float = zs[j + 1]
			if b - a < 1e-4 or d - c < 1e-4:
				continue
			var cx := (a + b) / 2.0
			var cz := (c + d) / 2.0
			var dedans := false
			for h in trous:
				if cx > h.x0 and cx < h.x1 and cz > h.z0 and cz < h.z1:
					dedans = true
			if not dedans:
				out.append([a, b, c, d])
	return out


## Un sol (plan de la matière donnée et dalle où l'on marche), troué des trémies ; marche : false pour un
## sol qu'on voit sans y marcher.
static func sol(K, nom_mat: String, x0: float, x1: float, z0: float, z1: float, y := 0.0, trous := [], marche := true) -> void:
	for c in cellules(x0, x1, z0, z1, trous):
		K.plan(nom_mat, c[0], c[1], c[2], c[3], y)
		if marche:
			K.dalle(c[0], c[1], c[2], c[3], y)


static func plafond(K, nom_mat: String, x0: float, x1: float, z0: float, z1: float, y: float, trous := []) -> void:
	for c in cellules(x0, x1, z0, z1, trous):
		K.plan(nom_mat, c[0], c[1], c[2], c[3], y, false)


# --- Voiles courbes ------------------------------------------------------------------------------------

## Un voile vertical d'épaisseur t entre deux courbes y = bas(a) et y = haut(a), sur le plan x = fixe
## (axe « x », a = z) ou z = fixe (axe « z », a = x) (L.voile). o : n (16), t (0,2), dessous, dessus.
static func voile(K, nom_mat: String, axe: String, fixe: float, a0: float, a1: float, bas: Callable, haut: Callable, o := {}) -> void:
	var n: int = o.get("n", 16)
	var t: float = o.get("t", 0.2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var P := func(a: float, y: float, off: float) -> Vector3:
		return Vector3(fixe + off, y, a) if axe == "x" else Vector3(a, y, fixe + off)
	var nf := Vector3(1, 0, 0) if axe == "x" else Vector3(0, 0, 1)
	var vide := true
	for i in n:
		var al := a0 + (a1 - a0) * i / n
		var ar := a0 + (a1 - a0) * (i + 1) / n
		var l0: float = bas.call(al)
		var l1: float = bas.call(ar)
		var h0: float = maxf(l0, haut.call(al))
		var h1: float = maxf(l1, haut.call(ar))
		if h0 - l0 < 1e-4 and h1 - l1 < 1e-4:
			continue
		vide = false
		for f in [[t / 2.0, nf], [-t / 2.0, -nf]]:
			K._quad(st, P.call(al, l0, f[0]), P.call(ar, l1, f[0]), P.call(ar, h1, f[0]), P.call(al, h0, f[0]), f[1])
		if o.get("dessous", false) and t > 0.0:
			K._quad(st, P.call(al, l0, -t / 2.0), P.call(ar, l1, -t / 2.0), P.call(ar, l1, t / 2.0), P.call(al, l0, t / 2.0), Vector3.DOWN)
		if o.get("dessus", false) and t > 0.0:
			K._quad(st, P.call(al, h0, -t / 2.0), P.call(ar, h1, -t / 2.0), P.call(ar, h1, t / 2.0), P.call(al, h0, t / 2.0), Vector3.UP)
	if not vide:
		K.put(nom_mat, st.commit())


## Les écoinçons d'une arche plein cintre dans une baie rectangulaire w × cle (L.ecoincons).
static func ecoincons(K, nom_mat: String, axe: String, fixe: float, c: float, w: float, cle: float) -> void:
	var r := w / 2.0
	var naissance := cle - r
	voile(K, nom_mat, axe, fixe, c - r, c + r, func(a: float) -> float: return naissance + sqrt(maxf(0.0, r * r - (a - c) * (a - c))),
		func(_a: float) -> float: return cle, {"n": 20, "dessous": true})


# --- Enveloppe ------------------------------------------------------------------------------------------

## L'encadrement d'une baie à linteau droit sur toute l'épaisseur du mur, et sa frise de seuil (L.baie).
## o : axe (« x » : plan x = at, la baie court le long de z ; « z »), at, c, w, h, mat, trim, prof (0,46),
## jamb (0,28), gorge (true), frise (true).
static func baie(K, o: Dictionary) -> void:
	var m: String = o.get("mat", "laque_noire")
	var trim: String = o.get("trim", "or")
	var d: float = o.get("prof", 0.46)
	var j: float = o.get("jamb", 0.28)
	var h: float = o.h
	var w: float = o.w
	var c: float = o.c
	var at: float = o.at
	var ax: bool = o.get("axe", "z") == "x"
	var bx := func(nm: String, wa: float, hh: float, dd: float, a: float, y: float):
		if ax:
			K.box(nm, dd, hh, wa, at, y, a)
		else:
			K.box(nm, wa, hh, dd, a, y, at)
	for s in [-1.0, 1.0]:
		var a: float = c + s * (w / 2.0 + j / 2.0)
		bx.call(m, j, h + 0.02, d, a, (h + 0.02) / 2.0)
		bx.call(trim, j + 0.06, 0.1, d + 0.06, a, 0.05)
		bx.call(trim, j + 0.06, 0.07, d + 0.06, a, h - 0.12)
	bx.call(m, w + 2.0 * j + 0.12, 0.34, d + 0.04, c, h + 0.17)
	bx.call(trim, w + 2.0 * j + 0.24, 0.06, d + 0.1, c, h + 0.37)
	bx.call(trim, w + 2.0 * j + 0.16, 0.03, d + 0.07, c, h + 0.015)
	if o.get("gorge", true):
		bx.call("gorge", w - 0.08, 0.035, 0.12, c, h - 0.018)
	if o.get("frise", true):
		if ax:
			K.seuil(at, c - w / 2.0, at, c + w / 2.0)
		else:
			K.seuil(c - w / 2.0, at, c + w / 2.0, at)


## Les registres d'un mur le long de sa face intérieure A → B (L.registres) : plinthe, soubassement saillant
## et cimaise d'or, corniche en ressaut et gorge lumineuse, pilastres. o : n [nx, nz] (vers la pièce), h,
## base (matière du soubassement, aucune sinon), bh (0,95), skip [[s0, s1]] (mètres depuis A : les baies),
## pil [s], applique (true), corniche (true), corniche_mat, gorge (true ou une matière), pil_mat.
static func registres(K, ax: float, az: float, bx: float, bz: float, o: Dictionary) -> void:
	var H: float = o.get("h", 5.4)
	var lg := Vector2(bx - ax, bz - az).length()
	var ux := (bx - ax) / lg
	var uz := (bz - az) / lg
	var n: Array = o.n
	var nx: float = n[0]
	var nz: float = n[1]
	var ry := atan2(-uz, ux)
	var bh: float = o.get("bh", 0.95)
	var sauts: Array = o.get("skip", []).duplicate()
	sauts.sort_custom(func(p, q): return p[0] < q[0])
	var pleins := []
	var s := 0.0
	for k in sauts:
		if k[0] - s > 0.02:
			pleins.append([s, k[0]])
		s = maxf(s, k[1])
	if lg - s > 0.02:
		pleins.append([s, lg])
	var barre := func(nm: String, s0: float, s1: float, hh: float, dd: float, y: float):
		var mid := (s0 + s1) / 2.0
		K.box(nm, s1 - s0, hh, dd, ax + ux * mid + nx * dd / 2.0, y, az + uz * mid + nz * dd / 2.0, ry)
	for p in pleins:
		barre.call("laque_noire", p[0], p[1], 0.12, 0.05, 0.06)
		if o.has("base") and bh > 0.0:
			barre.call(o.base, p[0], p[1], bh, 0.04, 0.12 + bh / 2.0)
			barre.call("or", p[0], p[1], 0.045, 0.065, 0.12 + bh + 0.022)
	if o.get("corniche", true):
		var cm: String = o.get("corniche_mat", "laque_noire")
		K.box(cm, lg, 0.22, 0.16, ax + ux * lg / 2.0 + nx * 0.08, H - 0.11, az + uz * lg / 2.0 + nz * 0.08, ry)
		K.box("or", lg, 0.04, 0.2, ax + ux * lg / 2.0 + nx * 0.1, H - 0.25, az + uz * lg / 2.0 + nz * 0.1, ry)
		var g = o.get("gorge", true)
		if not (g is bool and not g):
			K.box(g if g is String else "gorge", lg, 0.04, 0.1, ax + ux * lg / 2.0 + nx * 0.05, H - 0.31, az + uz * lg / 2.0 + nz * 0.05, ry)
	var hp := H - (0.0 if not o.get("corniche", true) else 0.33)
	for sp in o.get("pil", []):
		var px: float = ax + ux * sp
		var pz: float = az + uz * sp
		var pry := atan2(nx, nz)
		B().pilastre(K, px, pz, pry, hp, o.get("pil_mat", "marbre_creme"))
		if o.get("applique", true):
			K.lanterne(px + nx * 0.31, 2.6, pz + nz * 0.31, 0.4)


# --- Petit mobilier --------------------------------------------------------------------------------------

## Une chaise (L.chaise) : f l'orientation de la personne assise. Rend sa place [Vector3 assise, f].
static func chaise(K, x: float, z: float, f: float, o := {}) -> Array:
	var sh: float = o.get("h", 0.46)
	var sx := sin(f)
	var cz := cos(f)
	var cx := cos(f)
	var fr: String = o.get("cadre", "laque_noire")
	var cu: String = o.get("coussin", "capiton_rouge")
	for s in [-1.0, 1.0]:
		K.box(fr, 0.04, sh - 0.07, 0.42, x + cx * s * 0.2, (sh - 0.07) / 2.0, z - sx * s * 0.2, f)
	K.box(cu, 0.46, 0.09, 0.46, x, sh - 0.035, z, f)
	K.box(cu, 0.42, 0.4, 0.07, x + sx * 0.225, sh + 0.34, z + cz * 0.225, f)
	K.box(fr, 0.47, 0.04, 0.06, x + sx * 0.26, sh + 0.58, z + cz * 0.26, f)
	if o.get("collision", true):
		K.rond(x, z, 0.22, 0.0, 1.0)
	return [Vector3(x, sh + 0.04, z), f]


## Un fauteuil club (L.fauteuil, assise 0,42). Rend sa place [Vector3 assise, f].
static func fauteuil(K, x: float, z: float, f: float, nom_mat := "capiton_rouge", k := 1.0, collision := true) -> Array:
	var sx := sin(f)
	var cz := cos(f)
	var at := func(lx: float, lz: float) -> Vector2: return Vector2(x + cos(f) * lx + sx * lz, z - sin(f) * lx + cz * lz)
	K.box("laque_noire", 0.66 * k, 0.1, 0.66 * k, x, 0.05, z, f)
	K.box(nom_mat, 0.7 * k, 0.32, 0.7 * k, x, 0.26, z, f)
	var p: Vector2 = at.call(0, 0.32 * k)
	K.box(nom_mat, 0.7 * k, 0.5, 0.16, p.x, 0.62, p.y, f)
	for s in [-1.0, 1.0]:
		p = at.call(s * 0.33 * k, 0.02)
		K.box(nom_mat, 0.12, 0.22, 0.6 * k, p.x, 0.5, p.y, f)
	if collision:
		K.rond(x, z, 0.3 * k, 0.0, 1.0)
	return [Vector3(x, 0.46, z), f]


## Des potelets d'or et leurs cordons de velours le long d'une polyligne [[x, z]] (L.potelets) ; trous :
## les indices des travées sans cordon.
static func potelets(K, pts: Array, trous := [], y := 0.0) -> void:
	for p in pts:
		K.cyl("or", 0.15, 0.17, 0.03, p[0], y + 0.015, p[1], 12)
		K.cyl("or", 0.022, 0.022, 0.95, p[0], y + 0.49, p[1], 8)
		K.sph("or", 0.05, p[0], y + 0.99, p[1])
	for i in pts.size() - 1:
		if i in trous:
			continue
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		K.beam("coussin", Vector3(a[0], y + 0.84, a[1]), Vector3(b[0], y + 0.84, b[1]), 0.045, 0.045)
		K.segment(a[0], a[1], b[0], b[1], 0.07, y, 1.0)


## Une colonne courante (L.colonne) : socle noir, fût crème, chapiteau d'or.
static func colonne(K, x: float, z: float, D := 0.44, H := 5.4, collision := true, y := 0.0) -> void:
	var R := D / 2.0
	K.box("noir_poli", D * 1.5, 0.3, D * 1.5, x, y + 0.15, z)
	K.cyl("or", R * 1.25, R * 1.3, 0.08, x, y + 0.34, z, 12)
	K.cyl("creme", R * 0.86, R, H - 0.78, x, y + 0.38 + (H - 0.78) / 2.0, z, 12)
	K.cyl("or", R * 1.45, R * 0.9, 0.26, x, y + H - 0.27, z, 12)
	K.box("or", D * 1.55, 0.14, D * 1.55, x, y + H - 0.07, z)
	if collision:
		K.rond(x, z, R + 0.08, y)


## Un banc rembourré à n places (L.banc), f l'orientation des personnes assises. Rend les places.
static func banc(K, x: float, z: float, f: float, n: int, o := {}) -> Array:
	var r := [x, z, f]
	var w := n * 0.62 + 0.2
	var m: String = o.get("mat", "marbre_creme")
	var cu: String = o.get("coussin", "capiton_rouge")
	var L = B()
	L.rbox(K, r, m, w, 0.36, 0.5, 0, 0.18, 0)
	L.rbox(K, r, cu, w - 0.08, 0.1, 0.46, 0, 0.41, 0)
	if o.get("dossier", true):
		L.rbox(K, r, m, w, 0.5, 0.1, 0, 0.6, 0.27)
		L.rbox(K, r, cu, w - 0.14, 0.34, 0.04, 0, 0.66, 0.21)
	for s in [-1.0, 1.0]:
		L.rbox(K, r, "or", 0.06, 0.5, 0.5, s * (w / 2.0 + 0.03), 0.25, 0)
	L.rsolide(K, r, w + 0.12, 0.7, 0.55, 0, 0.05)
	var places := []
	for i in n:
		var p: Vector2 = L.loc(r, (i - (n - 1) / 2.0) * 0.62, -0.02)
		places.append([Vector3(p.x, 0.48, p.y), f])
	return places


## Une table haute « mange-debout » (L.mangeDebout). Rend les places debout autour [Vector3, f].
static func mange_debout(K, x: float, z: float, n: int, rot := 0.0, y := 0.0) -> Array:
	K.cyl("marbre_noir", 0.36, 0.36, 0.05, x, y + 1.1, z, 20)
	K.cyl("or", 0.035, 0.045, 1.06, x, y + 0.54, z, 8)
	K.cyl("laque_noire", 0.26, 0.3, 0.04, x, y + 0.02, z, 16)
	K.cyl("gorge", 0.3, 0.3, 0.02, x, y + 1.065, z, 20)
	K.rond(x, z, 0.3, y, 1.2)
	var places := []
	for i in n:
		var a := rot + i * TAU / n
		places.append([Vector3(x + sin(a) * 0.72, y, z + cos(a) * 0.72), a])
	return places


## Une plaque de table sur pied (le « plaque » de la fosse) : mise minimale, lue depuis ry.
static func plaque(K, t: String, x: float, z: float, ry: float) -> void:
	K.cyl("or", 0.018, 0.018, 1.15, x, 0.575, z, 6)
	K.cyl("or", 0.12, 0.14, 0.03, x, 0.015, z, 10)
	K.box("laque_noire", 0.48, 0.17, 0.03, x, 1.24, z, ry)
	K.texte(t, 0.44, 0.07, x + sin(ry) * 0.02, 1.24, z + cos(ry) * 0.02, ry)
	K.rond(x, z, 0.1, 0.0, 1.2)


# --- Tables de la fosse ----------------------------------------------------------------------------------

## Une table de blackjack en demi-lune (K.blackjackTable) : le croupier côté -z local, sept places sur
## l'arc, côté +z. Rend {sieges: [[Vector3, f]], croupier: [Vector3, f]}.
static func blackjack(K, x: float, z: float, rot: float) -> Dictionary:
	var L = B()
	var g := [x, z, rot]
	var R := 1.25
	var top := 0.88
	# Le plateau : la demi-lune (un disque coupé par le bord du croupier), le boudin de cuir, le feutre.
	var demi := func(nom_mat: String, r: float, y: float, h: float):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 16
		for i in n:
			var a0 := -PI / 2.0 + PI * i / n
			var a1 := -PI / 2.0 + PI * (i + 1) / n
			var p0 := Vector3(sin(a0) * r, 0, cos(a0) * r - 0.35)
			var p1 := Vector3(sin(a1) * r, 0, cos(a1) * r - 0.35)
			var c := Vector3(0, 0, -0.35)
			K._tri(st, c + Vector3(0, h, 0), p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
			K._quad(st, p0, p1, p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0), Vector3(sin((a0 + a1) / 2.0), 0, cos((a0 + a1) / 2.0)))
		K._quad(st, Vector3(-r, 0, -0.35), Vector3(r, 0, -0.35), Vector3(r, h, -0.35), Vector3(-r, h, -0.35), Vector3.FORWARD)
		var p: Vector2 = L.loc(g, 0, 0)
		K.put(nom_mat, st.commit(), K.xf(p.x, y, p.y, 0, rot))
	demi.call("cuir_noir", R + 0.12, top - 0.1, 0.1)
	demi.call("feutre", R - 0.04, top - 0.1, 0.12)
	L.rbox(K, g, "or", 2.0 * R, 0.03, 0.05, 0, top - 0.11, -0.35)
	# Le sabot, le rack à jetons du croupier, le pied.
	L.rbox(K, g, "bois_laque", 0.6, 0.06, 0.18, 0, top + 0.05, -0.22)
	for k in 5:
		L.rbox(K, g, ["laque_rouge", "jeton_vert", "jeton_bleu", "jeton_ivoire", "laque_noire"][k], 0.08, 0.04, 0.14, -0.2 + k * 0.1, top + 0.1, -0.22)
	L.rbox(K, g, "laque_rouge", 0.1, 0.08, 0.14, 0.42, top + 0.06, -0.16)
	L.rbox(K, g, "laque_noire", 1.6, top - 0.1, 0.5, 0, (top - 0.1) / 2.0, -0.1)
	L.rsolide(K, g, 2.0 * R + 0.2, 1.0, R + 0.5, 0, 0.15)
	var sieges := []
	for i in 7:
		var t: float = deg_to_rad(-72.0 + i * 24.0)
		var r: Array = L.sous(g, sin(t) * (R + 0.5), cos(t) * (R + 0.5) - 0.35, t)
		L.tabouret(K, r[0], r[1], 0.72, "coussin")
		sieges.append([Vector3(r[0], 0.76, r[1]), r[2]])
	var c: Vector2 = L.loc(g, 0, -0.85)
	return {"sieges": sieges, "croupier": [Vector3(c.x, 0, c.y), rot + PI]}


## Un disque de secteurs alternés qui tourne (cylindre de roulette, roue de la fortune) : un nœud à part,
## animé par la scène. axe_h : true couche le disque à plat (roulette), false le dresse (roue).
static func roue(K, x: float, y: float, z: float, ry: float, r: float, ep: float, mats: Array, n: int, vitesse: float, a_plat: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, y, z)
	pivot.rotation.y = ry
	K.zone.add_child(pivot)
	# Dressé, le disque tourne autour de sa propre normale : l'inclinaison et la rotation sont deux nœuds.
	var incline := Node3D.new()
	if not a_plat:
		incline.rotation.x = PI / 2.0
	pivot.add_child(incline)
	var disque := Node3D.new()
	incline.add_child(disque)
	for m in mats.size():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in n:
			if i % mats.size() != m:
				continue
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var p0 := Vector3(sin(a0) * r, 0, cos(a0) * r)
			var p1 := Vector3(sin(a1) * r, 0, cos(a1) * r)
			for f in [ep / 2.0, -ep / 2.0]:
				K._tri(st, Vector3(0, f, 0), p0 + Vector3(0, f, 0), p1 + Vector3(0, f, 0), Vector3.UP if f > 0.0 else Vector3.DOWN, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
			K._quad(st, p0 + Vector3(0, -ep / 2.0, 0), p1 + Vector3(0, -ep / 2.0, 0), p1 + Vector3(0, ep / 2.0, 0), p0 + Vector3(0, ep / 2.0, 0), Vector3(sin((a0 + a1) / 2.0), 0, cos((a0 + a1) / 2.0)))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = K.mat(mats[m])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disque.add_child(mi)
	var moyeu := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r * 0.3
	c.bottom_radius = r * 0.3
	c.height = ep + 0.02
	c.radial_segments = 16
	moyeu.mesh = c
	moyeu.material_override = K.mat("or")
	disque.add_child(moyeu)
	K.chaque_image(func(_dt, t): disque.rotation.y = t * vitesse)
	return pivot


## Une table de roulette (la fosse) : plateau de bois, tapis, cylindre qui tourne au bout wend (±1), six
## tabourets côté +z local. Rend {sieges, croupier}.
static func roulette(K, x: float, z: float, rot: float, wend: float) -> Dictionary:
	var L = B()
	var g := [x, z, rot]
	L.rbox(K, g, "bois_clair", 2.96, 0.09, 1.5, 0, 0.855, 0)
	L.rbox(K, g, "bois_laque", 2.7, 0.2, 1.24, 0, 0.72, 0)
	for s in [-1.0, 1.0]:
		L.rbox(K, g, "cuir_noir", 3.02, 0.06, 0.07, 0, 0.9, s * 0.745)
		L.rbox(K, g, "cuir_noir", 0.07, 0.06, 1.5, s * 1.475, 0.9, 0)
		L.rcyl(K, g, "bois_laque", 0.16, 0.2, 0.64, s * 0.9, 0.32, 0, 12)
	L.rbox(K, g, "feutre", 1.92, 0.01, 1.3, -wend * 0.42, 0.905, 0)
	# Les cases du tapis : trois rangées rouge et noir, filets d'ivoire.
	for i in 12:
		for r in 3:
			L.rbox(K, g, "laque_rouge" if (i + r) % 2 else "laque_noire", 0.1, 0.004, 0.24, -wend * (0.95 - i * 0.12) - wend * 0.0, 0.912, -0.3 + r * 0.27)
	var wx := wend * 1.02
	L.rcyl(K, g, "bois_laque", 0.5, 0.44, 0.13, wx, 0.955, 0, 24)
	var pw: Vector2 = L.loc(g, wx, 0)
	K.tore("or", 0.47, 0.02, K.xf(pw.x, 1.025, pw.y), 28)
	roue(K, pw.x, 1.03, pw.y, rot, 0.4, 0.03, ["laque_rouge", "laque_noire"], 36, 1.4 + 0.2 * absf(x), true)
	K.cyl("or", 0.03, 0.05, 0.14, pw.x, 1.1, pw.y, 8)
	L.rsolide(K, g, 3.05, 1.0, 1.56, 0, 0)
	var sieges := []
	for i in 6:
		var sx := -1.25 + i * 0.5
		var p: Vector2 = L.loc(g, sx, 1.17)
		L.tabouret(K, p.x, p.y, 0.72, "coussin")
		sieges.append([Vector3(p.x, 0.76, p.y), rot])
	var c: Vector2 = L.loc(g, -wend * 0.3, -1.2)
	return {"sieges": sieges, "croupier": [Vector3(c.x, 0, c.y), rot + PI]}


# --- Ascenseur, escalators ----------------------------------------------------------------------------------

## La gaine de l'ascenseur panoramique est (L.gaineAscB, ASC-B) : [18, 21] × [9, 12], vitrée au sud et à
## l'est, porte sur x = 18. La cabine, sa porte et ses parois : ascenseurs.gd. y : le sol du niveau.
static func gaine_b(K, H: float, y := 0.0, etage := "Casino") -> void:
	for p in [[18.06, 9.06], [20.94, 9.06], [18.06, 11.74], [20.94, 11.74]]:
		K.box("or", 0.12, H, 0.12, p[0], y + H / 2.0, p[1])
	K.box("verre", 2.76, H, 0.03, 19.5, y + H / 2.0, 9.04)
	K.box("verre", 0.03, H, 2.66, 20.96, y + H / 2.0, 10.41)
	for yy in [1.05, 2.75, H - 0.06]:
		K.box("or", 2.8, 0.06, 0.06, 19.5, y + yy, 9.04)
		K.box("or", 0.06, 0.06, 2.7, 20.96, y + yy, 10.4)
	K.box("verre", 0.03, H, 0.5, 18.03, y + H / 2.0, 9.4)
	K.box("verre", 0.03, H, 0.34, 18.03, y + H / 2.0, 11.58)
	K.box("verre", 0.03, H - 2.45, 1.9, 18.03, y + 2.45 + (H - 2.45) / 2.0, 10.5)
	K.box("or", 0.07, 0.07, 1.9, 18.03, y + 2.45, 10.5)
	K.box("laque_noire", 0.05, 2.4, 1.86, 18.05, y + 1.2, 10.5)
	K.box("or", 0.06, 0.05, 1.9, 18.0, y + 1.2, 10.5)
	K.box("onyx", 2.6, H - 0.3, 0.02, 19.5, y + H / 2.0, 11.8)
	K.box("gorge", 2.5, 0.03, 0.04, 19.5, y + H - 0.12, 9.1)
	B().enseigne(K, "Ascenseur · " + etage, 17.985, y + 3.0, 10.5, -PI / 2.0, 1.2, 0.26, "plaque")


## Les escalators ESC (L.ESC) : deux voies de 1 m entre z = -11,725 et -9,15, du pied (x 23,2, y 0) à la
## tête (x 31,8, y 6) ; la trémie [23,2 ; 31,8] × [-12, -9] traverse le plafond de la fosse.
const ESC := {"x0": 23.2, "x1": 31.8, "voies": [-11.15, -9.8], "w": 1.0, "rise": 6.0, "limons": [[-11.725, 0.15], [-10.475, 0.35], [-9.15, 0.3]]}

## Un volume de collision incliné le long de x, posé sur la pente de (x0, y0) à (x1, y1), centré sur z, de
## largeur w et haut de h (au-dessus de la pente si h > 0, en dessous sinon).
static func pente_solide(K, x0: float, y0: float, x1: float, y1: float, z: float, w: float, h: float) -> void:
	var th := atan2(y1 - y0, x1 - x0)
	var l := Vector2(x1 - x0, y1 - y0).length()
	var nrm := Vector3(-sin(th), cos(th), 0)
	var b := BoxShape3D.new()
	b.size = Vector3(l, absf(h), w)
	K.forme(Transform3D(Basis(Vector3.BACK, th), Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, z) + nrm * (h / 2.0)), b)


## La volée d'un escalator, qu'on gravit à pied (le tapis ne l'entraîne pas) : une rampe sous la pente.
static func rampe_x(K, x0: float, y0: float, x1: float, y1: float, z: float, w: float) -> void:
	pente_solide(K, x0, y0, x1, y1, z, w, -0.3)


## Les marches d'une voie d'escalator, qui défilent (vers le haut si sens > 0) : un nœud à part que la scène
## fait glisser le long de la pente, d'un pas de 0,4 m.
static func marches(K, x0: float, y0: float, x1: float, y1: float, z: float, w: float, sens: float) -> void:
	var d := Vector3(x1 - x0, y1 - y0, 0)
	var l := d.length()
	var u := d / l
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(l / 0.4)
	for i in range(1, n):
		var c := Vector3(x0, y0, z) + u * (i * 0.4)
		var a := c + Vector3(0, 0.035, -w / 2.0)
		var b := c + Vector3(0, 0.035, w / 2.0)
		K._quad(st, a, b, b + Vector3(0.05, 0, 0), a + Vector3(0.05, 0, 0), Vector3.UP)
		K._quad(st, a - Vector3(0, 0.03, 0), b - Vector3(0, 0.03, 0), b, a, Vector3(-u.y, u.x, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = K.mat("or_brosse")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.zone.add_child(mi)
	K.chaque_image(func(_dt, t): mi.position = u * (fposmod(t * 0.45 * sens, 0.4) - 0.2))
