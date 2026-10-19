extends RefCounted
## Lot E « dehors », zone X-FACADE (js/zones/e-casino.js) : la façade extérieure du Casino Minuit sur z = 30
## (ailes à arcades, avant-corps central, portail d'entrée, attique « CASINO MINUIT », horloge de minuit), la
## porte-cochère (voiturier, portiers, chariot à bagages ; les voitures de luxe à l'arrêt sont garées par le
## boulevard), la tour de l'hôtel au-dessus de la nef, la terrasse des ailes et la marquise géante à écrans.
## Règle du moteur web : derrière z = 30, rien sous y = 18 sauf les combles ; la tour commence à y = 19,5
## (la coupole de la rotonde culmine à 17 m). Le pupitre du voiturier appelle le taxi de l'aéroport.

const LOT_E := "res://communes/casino_minuit/zones/lot_e.gd"
const W0 := 30.0
const PZ := 31.8
const PH := 21.5


static func construire(K) -> void:
	var E = load(LOT_E)
	var L: Dictionary = E.LAY
	K.zone_debut("X-FACADE")
	_ailes(K, E, L)
	_avant_corps(K, E, L)
	_tour(K, E)
	_parvis(K, E, L)
	_cochere(K, E, L)
	_voiturier(K, E)
	_terrasse(K, E)
	_marquise(K, E)
	K.zone_fin()


## Une fenêtre cintrée d'onyx lumineux de largeur w (rectangle de y0 à y1, cintre au-dessus), face +z au plan z,
## dans son cadre d'or (A.arched du moteur web).
static func _cintree(K, x: float, z: float, w: float, y0: float, y1: float) -> void:
	K.put("onyx", _onyx(w, y0, y1), K.xf(x, 0, z))
	K.put("or", K._arc_or(w / 2.0, w / 2.0 + 0.16, 0.18, 14), K.xf(x, y1, z + 0.06))
	for s in [-1.0, 1.0]:
		K.box("or", 0.16, y1 - y0, 0.18, x + s * (w / 2.0 + 0.08), (y0 + y1) / 2.0, z + 0.06)
	K.box("or", w, 0.08, 0.1, x, y0 + (y1 - y0) * 0.62, z + 0.04)
	K.box("or", 0.07, y1 - y0 + w / 2.0 - 0.1, 0.1, x, (y0 + y1 + w / 2.0) / 2.0, z + 0.04)
	K.box("or", w + 0.5, 0.16, 0.36, x, y0 - 0.08, z + 0.12)


## Le verre d'une baie cintrée (onyxGeo) : un rectangle et son demi-disque, UV en mètres.
static func _onyx(w: float, y0: float, y1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := w / 2.0
	var n := Vector3.BACK
	_q(st, Vector3(-r, y1, 0), Vector3(r, y1, 0), Vector3(r, y0, 0), Vector3(-r, y0, 0), n)
	for i in 14:
		var a0 := PI * i / 14.0
		var a1 := PI * (i + 1) / 14.0
		_t(st, Vector3(0, y1, 0), Vector3(r * cos(a0), y1 + r * sin(a0), 0), Vector3(r * cos(a1), y1 + r * sin(a1), 0), n)
	return st.commit()


static func _t(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for p in [a, b, c]:
		st.set_uv(Vector2(p.x, p.y))
		st.set_normal(n)
		st.add_vertex(p)


static func _q(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_t(st, a, b, c, n)
	_t(st, a, c, d, n)


## Un disque vertical face +z (cadran, médaillons), de rayon r, centré en (x, y, z).
static func _disque(K, nom_mat: String, x: float, y: float, z: float, r: float, seg := 40) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		_t(st, Vector3.ZERO, Vector3(r * cos(a0), r * sin(a0), 0), Vector3(r * cos(a1), r * sin(a1), 0), Vector3.BACK)
	K.put(nom_mat, st.commit(), K.xf(x, y, z))


# --- Les ailes (|x| ∈ [16, 60]) ----------------------------------------------------------------------

static func _ailes(K, E, L: Dictionary) -> void:
	for s in [-1.0, 1.0]:
		var xa: float = s * L.PAV
		var xb: float = s * L.CASINO
		var cx := (xa + xb) / 2.0
		var wd := absf(xb - xa)
		K.box("marbre_creme", wd, 14, 0.4, cx, 7, W0 + 0.2)
		K.box("marbre_noir", wd, 1.1, 0.3, cx, 0.55, W0 + 0.55)
		# Les combles d'ardoise (de y 14 à 20 en reculant de 5,2 m) et leurs lucarnes.
		var sl := Vector2(6, 5.2).length()
		E.pan(K, Vector3(minf(xa, xb), 14, W0 + 0.2), Vector3.RIGHT, Vector3(0, 6.0 / sl, -5.2 / sl), wd, sl, E.ARDOISE, Color("#1E2230"))
		var x: float = xa + s * 3.0
		while absf(x) < absf(xb) - 1.0:
			K.box("pierre", 1.7, 2.2, 1.4, x, 15.6, W0 - 0.5)
			K.box("laque_noire", 1.9, 0.25, 1.6, x, 16.8, W0 - 0.5)
			E.plaque(K, "fenetre", 1.0, 1.4, x, 15.5, W0 + 0.22)
			x += s * 6.0
		# Le pignon d'extrémité, triangle de la pente.
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var zz := W0 + 0.2
		_t(st, Vector3(xb, 14, zz), Vector3(xb, 20, zz - 5.2), Vector3(xb, 14, zz - 5.2), Vector3(s, 0, 0))
		K.put("pierre", st.commit())
		# Les travées : arcades lumineuses au rez-de-chaussée, fenêtres à balconnet à l'étage.
		for i in 7:
			var ax: float = s * (L.PAV + 3.0 + i * 6.0)
			_cintree(K, ax, W0 + 0.41, 3.2, 1.1, 4.6)
			var lit := (i * 7 + (3 if s > 0 else 0)) % 5
			E.plaque(K, "ambre_lum" if lit == 0 else ("verre_sombre" if lit == 3 else "fenetre"), 2.0, 2.6, ax, 8.6, W0 + 0.41)
			K.box("or", 2.4, 0.1, 0.2, ax, 7.25, W0 + 0.5)
			K.box("or", 2.4, 0.1, 0.12, ax, 10.0, W0 + 0.46)
			K.box("laque_noire", 2.6, 0.12, 0.7, ax, 7.2, W0 + 0.75)
			K.box("or", 2.6, 0.05, 0.05, ax, 7.95, W0 + 1.08)
			var b := -1.2
			while b <= 1.21:
				K.box("or", 0.03, 0.7, 0.03, ax + b, 7.6, W0 + 1.08)
				b += 0.3
		# Les pilastres colossaux.
		for i in 8:
			var px: float = s * (L.PAV + i * 6.0)
			if absf(px) < L.PAV + 0.1:
				continue
			K.box("creme", 0.9, 10.0, 0.4, px, 6.1, W0 + 0.6)
			K.box("marbre_noir", 1.15, 1.2, 0.6, px, 0.6, W0 + 0.6)
			K.box("or", 1.15, 0.35, 0.62, px, 11.2, W0 + 0.6)
			K.box("or", 1.0, 0.12, 0.5, px, 1.3, W0 + 0.6)
		# L'entablement, la frise, la corniche à gorge lumineuse, l'attique.
		K.box("pierre", wd, 1.0, 0.9, cx, 11.85, W0 + 0.45)
		K.box("or", wd, 0.36, 0.95, cx, 12.53, W0 + 0.48)
		K.box("pierre", wd, 0.4, 1.5, cx, 12.9, W0 + 0.75)
		K.box("gorge", wd, 0.05, 0.06, cx, 12.68, W0 + 1.5)
		K.box("pierre", wd, 1.0, 0.5, cx, 13.6, W0 + 0.45)
		K.box("or", wd, 0.06, 0.55, cx, 14.1, W0 + 0.47)


# --- L'avant-corps central (|x| ≤ 16, face en z = 31,8), le portail, l'enseigne, l'horloge --------------------

static func _avant_corps(K, E, L: Dictionary) -> void:
	for s in [-1.0, 1.0]:
		var xa: float = s * 4.5
		var xb: float = s * L.PAV
		var cx := (xa + xb) / 2.0
		var wd := absf(xb - xa)
		K.box("marbre_creme", wd, PH, PZ - W0, cx, PH / 2.0, (W0 + PZ) / 2.0)
		K.box("marbre_noir", wd, 1.1, 0.3, cx, 0.55, PZ + 0.15)
		for p in [5.6, 15.2]:
			var px: float = s * p
			K.box("creme", 1.2, 11.3, 0.45, px, 6.75, PZ + 0.22)
			K.box("marbre_noir", 1.5, 1.4, 0.7, px, 0.7, PZ + 0.3)
			K.box("or", 1.5, 0.45, 0.75, px, 12.2, PZ + 0.3)
		_cintree(K, s * 10.4, PZ + 0.01, 3.4, 1.4, 6.6)
		E.plaque(K, "fenetre", 2.4, 1.6, s * 10.4, 9.6, PZ + 0.01)
	# Au-dessus du portail : le bloc de y 11 à 21,5 ; dessous, les écoinçons du tympan autour du cintre.
	K.box("marbre_creme", 9, PH - 11, PZ - W0, 0, (PH + 11) / 2.0, (W0 + PZ) / 2.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 4.5
	for i in 14:
		var a0 := PI * i / 14.0
		var a1 := PI * (i + 1) / 14.0
		_q(st, Vector3(r * cos(a0), r * sin(a0), 0), Vector3(r * cos(a0), r, 0), Vector3(r * cos(a1), r, 0), Vector3(r * cos(a1), r * sin(a1), 0), Vector3.BACK)
	K.put("pierre", st.commit(), K.xf(0, 6.5, PZ + 0.002))
	# La voûte dorée du portail (un berceau vu du dessous) et l'archivolte.
	var v := SurfaceTool.new()
	v.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 20:
		var a0 := PI * i / 20.0
		var a1 := PI * (i + 1) / 20.0
		var n := -Vector3(cos((a0 + a1) / 2.0), sin((a0 + a1) / 2.0), 0)
		_q(v, Vector3(r * cos(a0), r * sin(a0), W0), Vector3(r * cos(a1), r * sin(a1), W0), Vector3(r * cos(a1), r * sin(a1), PZ), Vector3(r * cos(a0), r * sin(a0), PZ), n)
	K.put("or", v.commit(), K.xf(0, 6.5, 0))
	K.put("or", K._arc_or(4.5, 5.15, 0.5, 20), K.xf(0, 6.5, PZ + 0.1))
	K.box("or", 0.9, 1.3, 0.7, 0, 11.3, PZ + 0.2)
	for s in [-1.0, 1.0]:
		K.box("or", 0.7, 0.3, 0.6, s * 4.85, 6.5, PZ + 0.1)
		K.box("marbre_creme", 1.5, 3.6, 0.4, s * 3.75, 1.8, W0 + 0.2)
		K.box("or", 0.22, 3.6, 0.3, s * 3.11, 1.8, W0 + 0.5)
	# Le fond du portail : la porte de 6 × 3,6, le tympan d'onyx rétroéclairé, l'inscription gravée.
	K.put("onyx", _onyx(9, 3.6, 6.5), K.xf(0, 0, W0 + 0.41))
	K.texte("CASINO MINUIT", 6.4, 0.8, 0, 5.0, W0 + 0.45, 0, "grave")
	K.box("or", 6.5, 0.22, 0.3, 0, 3.71, W0 + 0.5)
	K.box("laque_noire", 9, 0.02, PZ - W0, 0, 0.012, (W0 + PZ) / 2.0)
	# Les collisions de la façade : la porte x ∈ [-3, 3] reste libre.
	for s in [-1.0, 1.0]:
		K.obstacle(s * L.PAV, s * L.CASINO, W0, W0 + 0.75, 0.0, 14.0)
		K.obstacle(s * 4.5, s * L.PAV, W0, PZ + 0.3, 0.0, 14.0)
		K.obstacle(s * 3.0, s * 4.5, W0, W0 + 0.5, 0.0, 6.0)
	K.obstacle(-4.5, 4.5, W0, PZ, 3.6, 18.0)

	# L'entablement et l'attique de l'avant-corps, l'enseigne « CASINO MINUIT » dans son cadre d'ampoules.
	K.box("pierre", 32.6, 1.6, 1.2, 0, 13.2, PZ + 0.5)
	K.box("or", 32.6, 0.4, 1.3, 0, 14.1, PZ + 0.55)
	K.box("gorge", 32.6, 0.05, 0.06, 0, 12.36, PZ + 1.1)
	K.box("rouge_sombre", 30, 5.6, 0.3, 0, 17.6, PZ + 0.16)
	E.cadre_ampoules(K, 0, 17.6, PZ + 0.32, 30.4, 5.9, 0, 0.3)
	E.enseigne(K, "CASINO MINUIT", "#FFB347", 28, 4.2, 0, 17.6, PZ + 0.36, 0)
	K.box("pierre", 32.6, 0.6, 1.0, 0, 20.75, PZ + 0.3)
	K.box("or", 32.8, 0.12, 1.05, 0, 21.1, PZ + 0.32)
	# L'horloge : socle, cadran d'onyx, lunette, aiguilles sur minuit, volutes, fanal.
	K.box("pierre", 9, 1.4, 1.6, 0, 21.9, PZ - 0.4)
	K.box("or", 9.2, 0.12, 1.7, 0, 22.62, PZ - 0.4)
	var cy := 25.6
	var cr := 2.8
	_disque(K, "onyx", 0, cy, PZ + 0.02, cr)
	K.box("marbre_creme", 2 * cr + 1.6, 2 * cr + 1.2, 1.2, 0, cy, PZ - 0.62)
	K.tore("or", cr + 0.12, 0.2, K.xf(0, cy, PZ + 0.1, PI / 2.0, 0, 0), 40)
	for i in 12:
		var a := i * TAU / 12.0
		var rr := cr - 0.42
		var fort := i % 3 == 0
		K.put("or" if fort else "laque_noire", K._box_mesh(0.22 if fort else 0.12, 0.62 if fort else 0.4, 0.06), K.xf(sin(a) * rr, cy + cos(a) * rr, PZ + 0.07, 0, 0, -a))
	K.box("laque_noire", 0.3, 2.2, 0.08, 0, cy + 1.0, PZ + 0.12)
	K.box("laque_noire", 0.18, 1.5, 0.08, 0, cy + 0.65, PZ + 0.18)
	K.cyl("or", 0.22, 0.22, 0.14, 0, cy, PZ + 0.2, 12, PI / 2.0)
	for s in [-1.0, 1.0]:
		K.tore("or", 1.1, 0.16, K.xf(s * (cr + 1.6), 23.3, PZ - 0.1, PI / 2.0, 0, 0), 16)
		K.sph("or", 0.35, s * (cr + 1.6), 24.5, PZ - 0.1)
	K.cyl("or", 0.12, 0.3, 1.6, 0, cy + cr + 0.9, PZ - 0.3, 8)
	K.sph("lumiere", 0.36, 0, cy + cr + 1.9, PZ - 0.3)
	# Le toit de l'avant-corps, vu de loin, et son acrotère.
	K.box("beton_e", 32, 0.3, 6.5, 0, PH - 0.15, W0 - 1.5)
	K.box("pierre", 32, 2.2, 0.4, 0, PH - 0.5, W0 - 1.8)


## La tour de l'hôtel (y ≥ 19,5, au-dessus de la nef) et sa couronne rouge « MINUIT ».
static func _tour(K, E) -> void:
	var tx := 28.0
	var z0 := -6.0
	var z1 := 10.0
	var y0 := 19.5
	var y1 := 100.0
	var zc := (z0 + z1) / 2.0
	E.bloc(K, -tx, tx, z0, z1, y0, y1, E.TOUR, "seo", Color("#1A0A0E"), false)
	K.box("laque_noire", 2 * tx + 1.2, 7, z1 - z0 + 1.2, 0, y1 + 3.5, zc)
	K.box("or", 2 * tx + 1.4, 0.4, z1 - z0 + 1.4, 0, y1 + 0.2, zc)
	K.box("or", 2 * tx + 1.4, 0.4, z1 - z0 + 1.4, 0, y1 + 6.8, zc)
	K.box("rouge_lum", 2 * tx + 1.3, 0.25, 0.1, 0, y1 + 1.0, z1 + 0.66)
	E.enseigne(K, "MINUIT", "#FF3348", 30, 5.2, 0, y1 + 3.6, z1 + 0.65, 0)
	for s in [-1.0, 1.0]:
		E.enseigne(K, "MINUIT", "#FFB347", 12, 2.6, s * (tx + 0.65), y1 + 3.6, zc, s * PI / 2.0)
		K.box("rouge_lum", 0.1, 0.25, z1 - z0 + 1.2, s * (tx + 0.66), y1 + 1.0, zc)
		K.box("or", 1.2, y1 - y0, 1.2, s * tx, (y0 + y1) / 2.0, z1)
	K.box("or", 0.6, 14, 0.6, 0, y1 + 13.5, zc)
	K.sph("rouge_lum", 0.5, 0, y1 + 20.8, zc)


# --- Le sol : parvis en damier, allée de granit, tapis rouge ---------------------------------------

static func _parvis(K, E, L: Dictionary) -> void:
	K.plan("damier", -L.CASINO, L.CASINO, W0, L.DRIVE0, 0.004)
	for s in [-1.0, 1.0]:
		K.plan("damier", minf(s * L.CASINO, s * L.DRIVE_X), maxf(s * L.CASINO, s * L.DRIVE_X), L.DRIVE0, L.DRIVE1, 0.004)
		K.box("or", 0.12, 0.02, L.DRIVE1 - L.DRIVE0, s * L.DRIVE_X, 0.012, (L.DRIVE0 + L.DRIVE1) / 2.0)
		K.box("or", 0.08, 0.025, L.DRIVE1 - W0 - 0.2, s * 1.54, 0.016, (W0 + L.DRIVE1) / 2.0 + 0.05)
		E.cordons(K, s * 2.1, [PZ + 0.6, PZ + 1.8])
	K.plan("damier", -L.LAKE_IN, L.LAKE_IN, L.DRIVE1, L.WALK0, 0.004)
	K.plan("granit", -L.DRIVE_X, L.DRIVE_X, L.DRIVE0, L.DRIVE1, 0.004)
	for z in [L.DRIVE0, L.DRIVE1 - 0.1]:
		K.box("or", 2 * L.DRIVE_X, 0.02, 0.12, 0, 0.012, z + 0.05)
	K.box("tapis_rouge", 3.0, 0.02, L.DRIVE1 - W0 - 0.2, 0, 0.014, (W0 + L.DRIVE1) / 2.0 + 0.05)


# --- La porte-cochère : un auvent à caissons sur quatre colonnes colossales ---------------------------------

static func _cochere(K, E, L: Dictionary) -> void:
	var cx := 12.5
	var cz0 := PZ
	var cz1 := 40.4
	var cy0 := 12.6
	var cy1 := 13.8
	var czm := (cz0 + cz1) / 2.0
	var cym := (cy0 + cy1) / 2.0
	K.box("laque_noire", 2 * cx, cy1 - cy0, cz1 - cz0, 0, cym, czm)
	K.box("rouge_e", 2 * cx + 0.2, 1.3, 0.3, 0, cym, cz1 + 0.1)
	for s in [-1.0, 1.0]:
		K.box("rouge_e", 0.3, 1.3, cz1 - cz0, s * (cx + 0.1), cym, czm)
	for y in [cy0 - 0.05, cy1 + 0.05]:
		K.box("or", 2 * cx + 0.5, 0.14, 0.4, 0, y, cz1 + 0.12)
		for s in [-1.0, 1.0]:
			K.box("or", 0.4, 0.14, cz1 - cz0, s * (cx + 0.12), y, czm)
	for y in [cy1 + 0.32, cy0 - 0.32]:
		E.ampoules(K, Vector3(-cx, y, cz1 + 0.3), Vector3(cx, y, cz1 + 0.3), 0.3)
		for s in [-1.0, 1.0]:
			E.ampoules(K, Vector3(s * (cx + 0.3), y, cz0), Vector3(s * (cx + 0.3), y, cz1), 0.3, s * PI / 2.0)
	E.enseigne(K, "CASINO MINUIT", "#FFC24A", 12, 1.05, 0, cym, cz1 + 0.27, 0)
	for s in [-1.0, 1.0]:
		E.enseigne(K, "VOITURIER", "#FFE2B4", 5, 0.9, s * (cx + 0.27), cym, czm, s * PI / 2.0, "bloc")
	# Les caissons : poutres d'or, fonds de laque rouge sombre, plafonniers.
	var cyu := cy0 - 0.02
	K.box("rouge_sombre", 2 * cx - 0.4, 0.04, cz1 - cz0 - 0.4, 0, cyu, czm)
	for i in 9:
		K.box("or", 0.22, 0.45, cz1 - cz0 - 0.4, -cx + 0.2 + i * (2 * cx - 0.4) / 8.0, cyu - 0.22, czm)
	for j in 4:
		K.box("or", 2 * cx - 0.4, 0.45, 0.22, 0, cyu - 0.22, cz0 + 0.2 + j * (cz1 - cz0 - 0.4) / 3.0)
	for i in 8:
		for j in 3:
			var x := -cx + 0.2 + (i + 0.5) * (2 * cx - 0.4) / 8.0
			var z := cz0 + 0.2 + (j + 0.5) * (cz1 - cz0 - 0.4) / 3.0
			K.cyl("lumiere", 0.28, 0.28, 0.04, x, cyu - 0.04, z, 10)
			K.cyl("or", 0.4, 0.4, 0.05, x, cyu - 0.02, z, 10)
	for x in [-5.2, 5.2]:
		K.lustre_anneau(x, 9.3, 36.2, 1.7, 2.6)
	for x in [-12.0, -6.2, 6.2, 12.0]:
		K.colonne(x, 39.4, 1.1, cy0, true)
	# Deux lumières sous l'auvent et dans le portail ; courtes, pour ne pas peser sur la rotonde.
	K.lumiere(0, 10.5, 37.0, K.pal.lumiere, 2.4, 13.0)
	K.lumiere(0, 5.5, 32.4, K.pal.ambre, 1.5, 9.0)


# --- Le voiturier, les portiers, le chariot à bagages ----------------------------------------------

static func _voiturier(K, E) -> void:
	# Le pupitre du voiturier : bois laqué, laiton, lampe ; l'armoire à clés contre la façade.
	K.box("bois_laque", 1.1, 1.05, 0.6, -9.6, 0.525, 33.9)
	K.box("or", 1.2, 0.05, 0.7, -9.6, 1.08, 33.9)
	K.box("laque_noire", 1.0, 0.12, 0.5, -9.6, 1.16, 33.85)
	K.cyl("or", 0.02, 0.02, 0.4, -9.95, 1.3, 33.75, 5)
	K.sph("lumiere", 0.09, -9.95, 1.52, 33.75)
	K.box("laque_noire", 1.4, 2.0, 0.35, -11.8, 1.0, PZ + 0.25)
	K.box("or", 1.3, 1.8, 0.02, -11.8, 1.0, PZ + 0.44)
	E.enseigne(K, "VOITURIER", "#FFC24A", 1.6, 0.3, -9.6, 0.8, 34.21, 0, "bloc")
	E.enseigne(K, "TAXI · AÉROPORT", "#FFE2B4", 1.6, 0.18, -9.6, 0.45, 34.21, 0, "bloc")
	K.obstacle(-10.2, -9.0, 33.6, 34.2, 0.0, 1.2)
	# Repartir : le voiturier appelle un taxi, pour l'aéroport (la carte et le vol du retour) ou le stade de la Fortune.
	K.interaction("sortie", "Le voiturier : un taxi pour l'aéroport ou le stade", -9.6, 1.1, 34.6, Vector3(2.4, 2.2, 1.6))
	K.places["e_voiturier"] = [[Vector3(-9.6, 0, 33.25), PI], [Vector3(-3.0, 0, 38.7), -PI / 2.0]]
	K.places["e_portiers"] = [[Vector3(-3.9, 0, 32.6), PI], [Vector3(3.9, 0, 32.6), PI]]
	K.places["e_cochere"] = [[Vector3(9.2, 0, 34.4), -PI / 2.0], [Vector3(10.3, 0, 34.4), PI / 2.0], [Vector3(3.2, 0, 34.6), -PI / 2.0], [Vector3(-2.6, 0, 35.2), PI / 2.0]]
	# Le chariot à bagages doré.
	var x := 7.6
	var z := 32.9
	K.box("rouge_sombre", 1.6, 0.06, 0.8, x, 0.32, z)
	K.box("or", 1.7, 0.05, 0.85, x, 0.3, z)
	for s in [-1.0, 1.0]:
		K.cyl("or", 0.03, 0.03, 1.7, x + s * 0.8, 1.15, z, 6)
		for dz in [0.3, -0.3]:
			K.cyl("pneu", 0.1, 0.1, 0.06, x + s * 0.7, 0.1, z + dz, 8, PI / 2.0)
	K.beam("or", Vector3(x - 0.8, 2.0, z), Vector3(x, 2.4, z), 0.05, 0.05)
	K.beam("or", Vector3(x, 2.4, z), Vector3(x + 0.8, 2.0, z), 0.05, 0.05)
	K.box("marine", 0.7, 0.5, 0.42, x - 0.35, 0.6, z)
	K.box("rouge_sombre", 0.55, 0.38, 0.3, x + 0.4, 0.54, z + 0.1)
	K.box("bois_laque", 0.5, 0.32, 0.36, x - 0.2, 1.0, z)
	K.box("creme", 0.36, 0.5, 0.2, x + 0.45, 0.98, z - 0.05)
	K.rond(x, z, 0.95)


# --- La terrasse des ailes : candélabres, bancs face aux bassins, jardinières -------------------------------

static func _terrasse(K, E) -> void:
	var bancs := []
	for s in [-1.0, 1.0]:
		for i in 4:
			var x: float = s * (20.0 + i * 11.5)
			K.box("laque_noire", 0.6, 0.6, 0.6, x, 0.3, 39.3)
			K.cyl("or", 0.08, 0.12, 4.0, x, 2.6, 39.3, 8)
			for k in [-1.0, 0.0, 1.0]:
				K.beam("or", Vector3(x, 4.2, 39.3), Vector3(x + k * 0.55, 4.5, 39.3), 0.05, 0.05)
				K.sph("lumiere", 0.24, x + k * 0.55, 4.75, 39.3)
			K.rond(x, 39.3, 0.4)
			if i < 3:
				bancs.append_array(E.banc(K, x + s * 5.75, 38.4, PI))
		for i in 6:
			var x: float = s * (19.0 + i * 6.0 + 3.0)
			K.box("laque_noire", 2.0, 0.7, 0.9, x, 0.35, 31.5)
			K.box("or", 2.05, 0.05, 0.95, x, 0.7, 31.5)
			for dx in [-0.5, 0.5]:
				K.sph("feuille", 0.45, x + dx, 1.05, 31.5, 0.9)
			K.obstacle(x - 1.0, x + 1.0, 31.05, 31.95, 0.0, 1.2)
	K.places["e_bancs_terrasse"] = bancs


# --- La marquise géante : pylône dans le bassin ouest, écrans LED en V, couronne « CASINO MINUIT » ------------

static func _marquise(K, E) -> void:
	var mx: float = E.MARQ.x
	var mz: float = E.MARQ.y
	K.box("marbre_noir", 4.6, 2.2, 4.6, mx, 1.1, mz)
	K.box("or", 4.8, 0.2, 4.8, mx, 2.2, mz)
	K.box("rouge_e", 2.6, 10, 2.6, mx, 7.2, mz)
	for c in [[-1.0, -1.0], [1.0, -1.0], [-1.0, 1.0], [1.0, 1.0]]:
		K.box("or", 0.25, 10, 0.25, mx + c[0] * 1.3, 7.2, mz + c[1] * 1.3)
	var y := 4.0
	while y < 12.0:
		K.box("or", 2.8, 0.12, 2.8, mx, y, mz)
		y += 2.5
	K.obstacle(mx - 2.3, mx + 2.3, mz - 2.3, mz + 2.3, 0.0, 3.0)
	# Le V : sommet vers la rue, deux écrans de 11 × 7 m tournés vers (±0,82 ; 0,57).
	var apex := Vector2(mx, mz + 2.6)
	var wv := 11.0
	var sy0 := 12.2
	var sy1 := 19.2
	var sy := (sy0 + sy1) / 2.0
	var bouts := []
	for s in [-1.0, 1.0]:
		var nx: float = s * 0.819
		var nz := 0.574
		var dx: float = s * 0.574
		var dz := -0.819
		var ry := atan2(nx, nz)
		var cx := apex.x + dx * wv / 2.0
		var cz := apex.y + dz * wv / 2.0
		bouts.append([apex.x + dx * wv, apex.y + dz * wv])
		K.box("laque_noire", wv + 0.4, sy1 - sy0 + 0.6, 0.5, cx - nx * 0.25, sy, cz - nz * 0.25, ry)
		E.ecran(K, cx + nx * 0.02, sy, cz + nz * 0.02, wv - 0.3, sy1 - sy0 - 0.4, ry, E.LED_MINUIT, 0.0 if s > 0 else 2.7)
		E.cadre_ampoules(K, cx + nx * 0.04, sy, cz + nz * 0.04, wv + 0.1, sy1 - sy0 + 0.2, ry, 0.25)
	var v := [[apex.x, apex.y], bouts[0], bouts[1]]
	E.prisme(K, "or", v, sy1 + 0.3, sy1 + 0.6)
	E.prisme(K, "laque_noire", v, sy0 - 0.6, sy0 - 0.3)
	# La couronne : caisson rouge, lettres au néon sur trois faces, médaillon d'or, flèche.
	var ky := 22.6
	K.box("rouge_e", 8.6, 5.6, 3.2, mx, ky, mz)
	K.box("or", 9.0, 0.3, 3.6, mx, ky - 2.95, mz)
	K.box("or", 9.0, 0.3, 3.6, mx, ky + 2.95, mz)
	for f in [[1.62, 0.0], [-1.62, PI]]:
		E.enseigne(K, "CASINO", "#FFC24A", 7.6, 2.0, mx, ky + 1.15, mz + f[0], f[1])
		E.enseigne(K, "MINUIT", "#FF4D60", 7.6, 2.2, mx, ky - 1.15, mz + f[0], f[1])
		E.cadre_ampoules(K, mx, ky, mz + f[0], 8.7, 5.7, f[1], 0.26)
	for s in [-1.0, 1.0]:
		E.enseigne(K, "MINUIT", "#FFB347", 2.2, 5.0, mx + s * 4.32, ky, mz, s * PI / 2.0, "neon", true)
	K.cyl("or", 1.6, 1.6, 0.4, mx, ky + 3.3, mz, 20, PI / 2.0)
	K.cyl("laque_noire", 1.25, 1.25, 0.45, mx, ky + 3.3, mz, 20, PI / 2.0)
	K.cyl("or", 0.2, 0.5, 4.5, mx, ky + 6.6, mz, 8)
	K.sph("lumiere", 0.45, mx, ky + 9.0, mz)
	K.lumiere(mx + 4, 15, mz + 5, Color("#FF9A6A"), 1.5, 16.0)
