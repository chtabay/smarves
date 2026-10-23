extends RefCounted
## Les jardins du Clain : derrière la rangée sud de la rue du Clain, le bourg descend vers le bief du
## Moulin des Dames en terrasses tenues par des murs de pierre. On y entre par la venelle, en face du
## porche (« venelle » dans SOUTH_ROW), qui descend en marches entre deux murs de jardin ; on remonte par
## l'escalier de la placette, au bout de la rue. Note d'intentions : communes/smarves/INTENTIONS.md.
##
## Le socle va de la rue du Clain (z = 15,3) au pré d'en face (z = 36), sur toute la longueur de la rue.
## Repères : +X à l'est (la place), -X à l'ouest (le moulin) ; on descend vers +Z, vers la caméra.

const X0 := -11.3
const X1 := -58.9
const Z0 := 15.3
const Z1 := 36.0
## Les terrasses, du haut vers le bas : [z du début, hauteur du sol]. Le mur de soutènement de chacune
## est à son z de début ; la berge est la dernière, puis l'eau, puis le pré d'en face.
const TERRASSES := [[Z0, 0.0], [19.0, -0.45], [23.5, -0.9], [27.5, -1.2]]
const EAU_Z0 := 30.0
const EAU_Z1 := 33.5
const EAU_Y := -1.5
const PRE_Y := -1.2
## La venelle (au droit du « jardin » devenu passage, entre Fleurs Odette et la brocante) et l'escalier
## de la placette, qui ramène au bout de la rue.
const VENELLE_X := -28.8
const VENELLE_W := 1.5
const ESCALIER_X := -53.4
const ESCALIER_W := 1.2
## La passerelle de planches vers le pré, et le ponton du pêcheur.
const PASSERELLE_X := -38.0
const PONTON_X := -46.5

const PIERRE := Color(0.8, 0.75, 0.64)
const PIERRE_SOMBRE := Color(0.62, 0.58, 0.5)
const BOIS_GRIS := Color(0.5, 0.48, 0.42)
const BOIS_VERT := Color(0.25, 0.36, 0.28)
const VEGETAL := Color(0.37, 0.54, 0.24)
const LIERRE := Color(0.18, 0.29, 0.16)

var v: Node3D
var f: RefCounted
var KM: String


func build(village: Node3D) -> void:
	v = village
	KM = v.KK + "medieval_decoration/"
	f = v.FACADES.new(v, v.main.serif, 2026)
	if not v.mats.has("vitre"):
		# Le verre de la serre et le grillage du poulailler : la teinte et la transparence au sommet.
		var vitre := StandardMaterial3D.new()
		vitre.vertex_color_use_as_albedo = true
		vitre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		vitre.roughness = 0.2
		vitre.cull_mode = BaseMaterial3D.CULL_DISABLED
		v.mats.vitre = vitre
	_socle()
	_terrasses()
	_venelle()
	_escalier_placette()
	_parcelles()
	_rompre()
	_berge()
	_bief()
	_pre()
	v._glass.append(f.commit(v.mats, v.mats.glass, "JardinsDuClain"))
	_figurants()


## Le sol d'une terrasse à un z donné.
static func sol(z: float) -> float:
	var y := 0.0
	for t in TERRASSES:
		if z >= t[0]:
			y = t[1]
	if z >= EAU_Z0 and z < EAU_Z1:
		return EAU_Y
	if z >= EAU_Z1:
		return PRE_Y
	return y


# --- Le socle et ses terrasses -----------------------------------------------------------------

func _socle() -> void:
	var cx := (X0 + X1) / 2.0
	var sx := absf(X0 - X1)
	var sz := Z1 - Z0
	# Le bois du socle, en gradins sous chaque terrasse : la maquette descend jusqu'à l'eau.
	var bas := -2.6
	var marches := []
	for i in TERRASSES.size():
		var z1: float = TERRASSES[i + 1][0] if i + 1 < TERRASSES.size() else EAU_Z0
		marches.append([TERRASSES[i][0], z1, TERRASSES[i][1]])
	marches.append([EAU_Z0, EAU_Z1, EAU_Y - 0.5])
	marches.append([EAU_Z1, Z1, PRE_Y])
	for m in marches:
		var haut: float = m[2] - 0.1
		v.main._box(Vector3(sx, haut - bas, m[1] - m[0]), Vector3(cx, (haut + bas) / 2.0, (m[0] + m[1]) / 2.0), v.mats.walnut, v)
	var plaque := Label3D.new()
	plaque.text = "LES JARDINS DU CLAIN"
	plaque.font = v.main.serif
	plaque.font_size = 80
	plaque.pixel_size = 0.004
	plaque.modulate = Color(0.95, 0.75, 0.4)
	plaque.position = Vector3(cx, -2.1, Z1 + 0.01)
	v.add_child(plaque)
	# Les bords invisibles : à l'est, à l'ouest et au sud (le bord nord est celui de la rue, percé).
	v.main._solid_box(Vector3(0.2, 4.0, sz), Vector3(X0 + 0.1, 0.0, (Z0 + Z1) / 2.0))
	v.main._solid_box(Vector3(0.2, 4.0, sz), Vector3(X1 - 0.1, 0.0, (Z0 + Z1) / 2.0))
	v.main._solid_box(Vector3(sx, 4.0, 0.2), Vector3(cx, 0.0, Z1 + 0.1))


func _terrasses() -> void:
	var cx := (X0 + X1) / 2.0
	var sx := absf(X0 - X1)
	for i in TERRASSES.size():
		var z0: float = TERRASSES[i][0]
		var y: float = TERRASSES[i][1]
		var z1: float = TERRASSES[i + 1][0] if i + 1 < TERRASSES.size() else EAU_Z0
		var mat: Material = v.mats.grass
		v.main._box(Vector3(sx, 0.1, z1 - z0), Vector3(cx, y - 0.05, (z0 + z1) / 2.0), mat, v)
		v.main._solid_box(Vector3(sx, 0.4, z1 - z0), Vector3(cx, y - 0.2, (z0 + z1) / 2.0))
		if i == 0:
			continue
		var haut: float = TERRASSES[i - 1][1]
		_soutenement(z0, haut, y, i)


## Un mur de soutènement en moellons à z, du sol haut au sol bas, avec son chaperon et un muret au-dessus,
## percé aux escaliers. Les pierres ne sont pas toutes de la même teinte, le lierre tombe par endroits.
func _soutenement(z: float, haut: float, bas: float, rang: int) -> void:
	var xf := Transform3D()
	var h := haut - bas
	var trous := [[VENELLE_X - VENELLE_W / 2.0 - 0.15, VENELLE_X + VENELLE_W / 2.0 + 0.15], [ESCALIER_X - ESCALIER_W / 2.0 - 0.15, ESCALIER_X + ESCALIER_W / 2.0 + 0.15]]
	# Le parement : des assises de moellons de longueurs variées.
	var rng := f.rng as RandomNumberGenerator
	var assises := maxi(2, int(h / 0.15))
	for a in assises:
		var y0 := bas + h * a / assises
		var ah := h / assises
		var x := X1
		while x < X0:
			var lw := rng.randf_range(0.35, 0.8)
			var x2 := minf(X0, x + lw)
			var teinte := PIERRE.darkened(rng.randf_range(0.0, 0.18)) if rng.randf() < 0.85 else PIERRE_SOMBRE
			f.batch.box("wall", xf, Vector3((x + x2) / 2.0, y0 + ah / 2.0, z - 0.02), Vector3(x2 - x - 0.03, ah - 0.025, 0.3), teinte)
			x = x2
	# Les joints, en retrait derrière les pierres.
	f.batch.box("wall", xf, Vector3((X0 + X1) / 2.0, bas + h / 2.0, z + 0.03), Vector3(absf(X0 - X1), h, 0.3), PIERRE_SOMBRE.darkened(0.25))
	# Le chaperon, et le muret au-dessus, sauf aux escaliers.
	var segs := _hors(trous)
	for s in segs:
		var len: float = s[1] - s[0]
		var mid: float = (s[0] + s[1]) / 2.0
		var muret := 0.28 if rang < TERRASSES.size() - 1 else 0.18
		f.batch.box("wall", xf, Vector3(mid, haut + muret / 2.0, z - 0.05), Vector3(len, muret, 0.22), PIERRE.lightened(0.05))
		f.batch.box("trim", xf, Vector3(mid, haut + muret + 0.03, z - 0.05), Vector3(len + 0.02, 0.06, 0.28), Color(0.84, 0.5, 0.32))
		v.main._solid_box(Vector3(len, 1.4, 0.3), Vector3(mid, haut + 0.5, z - 0.05))
	# Le lierre qui tombe du chaperon, en rideaux irréguliers ; les coulures sombres sous les barbacanes.
	for i in 9:
		var lx := rng.randf_range(X1 + 1.0, X0 - 1.0)
		if absf(lx - VENELLE_X) < 1.5 or absf(lx - ESCALIER_X) < 1.5:
			continue
		var lw2 := rng.randf_range(0.5, 1.6)
		var lh := rng.randf_range(0.4, 1.0) * h
		f.batch.box("trim", xf, Vector3(lx, haut - lh / 2.0, z + 0.14), Vector3(lw2, lh, 0.05), LIERRE.lightened(rng.randf() * 0.15))
	var bx := X1 + 2.0
	while bx < X0 - 1.0:
		f.batch.box("trim", xf, Vector3(bx, bas + h * 0.35, z + 0.13), Vector3(0.07, 0.07, 0.04), Color(0.15, 0.13, 0.12))
		f.batch.box("trim", xf, Vector3(bx, bas + h * 0.18, z + 0.135), Vector3(0.09, h * 0.3, 0.02), PIERRE_SOMBRE.darkened(0.15))
		bx += rng.randf_range(2.6, 4.2)


## Les intervalles de [X1, X0] hors des trous [[a, b], …].
func _hors(trous: Array) -> Array:
	var segs := [[X1, X0]]
	for t in trous:
		var nxt := []
		for s in segs:
			if t[1] <= s[0] or t[0] >= s[1]:
				nxt.append(s)
				continue
			if t[0] > s[0]:
				nxt.append([s[0], t[0]])
			if t[1] < s[1]:
				nxt.append([t[1], s[1]])
		segs = nxt
	return segs


## Un escalier de pierre qui descend vers +Z : de (x, haut) en z_haut à bas, en marches de n.
func _marches(x: float, w: float, z_haut: float, haut: float, bas: float, n: int, giron := 0.32) -> void:
	var xf := Transform3D()
	var dh := (haut - bas) / n
	for i in n:
		var top := haut - dh * (i + 1)
		var z := z_haut + giron * i
		var teinte := PIERRE.darkened(0.06 * (i % 2))
		var hh := top - (bas - 0.1)
		f.batch.box("wall", xf, Vector3(x, (top + bas - 0.1) / 2.0, z + giron / 2.0), Vector3(w, hh, giron), teinte)
		# Le nez de marche, plus clair, usé au milieu.
		f.batch.box("trim", xf, Vector3(x, top + 0.005, z + 0.03), Vector3(w, 0.02, 0.06), PIERRE.lightened(0.12))
		f.batch.box("trim", xf, Vector3(x, top + 0.008, z + giron / 2.0), Vector3(w * 0.4, 0.012, giron * 0.8), PIERRE_SOMBRE.lightened(0.1))
		v.main._solid_box(Vector3(w, hh, giron), Vector3(x, (top + bas - 0.1) / 2.0, z + giron / 2.0))


# --- La venelle --------------------------------------------------------------------------------

## La venelle des jardins : entre deux murs hauts au départ de la rue, puis des murs qui s'abaissent par
## paliers ; trois volées de marches aux murs de soutènement.
func _venelle() -> void:
	var w := VENELLE_W
	var xf := Transform3D()
	# Le sol : des dalles usées au milieu, de la rue jusqu'à la berge.
	for i in TERRASSES.size():
		var z0: float = TERRASSES[i][0]
		var z1: float = TERRASSES[i + 1][0] if i + 1 < TERRASSES.size() else EAU_Z0 - 0.6
		var y: float = TERRASSES[i][1]
		v.main._box(Vector3(w, 0.04, z1 - z0), Vector3(VENELLE_X, y + 0.02, (z0 + z1) / 2.0), v.mats.slabs, v)
	# Les marches, posées devant chaque mur de soutènement.
	for i in range(1, TERRASSES.size()):
		var z: float = TERRASSES[i][0]
		var haut: float = TERRASSES[i - 1][1]
		var bas: float = TERRASSES[i][1]
		var n := maxi(2, int(round((haut - bas) / 0.15)))
		_marches(VENELLE_X, w, z - 0.15, haut, bas, n)
		# La main courante de fer, côté est.
		var rx := VENELLE_X + w / 2.0 - 0.06
		var z_bas := z - 0.15 + 0.32 * n
		f.batch.box("trim", xf, Vector3(rx, (haut + bas) / 2.0 + 0.5, (z - 0.15 + z_bas) / 2.0), Vector3(0.03, 0.03, z_bas - z + 0.15), Color(0.18, 0.2, 0.2))
		for pz in [z - 0.1, z_bas - 0.05]:
			var py := haut if pz < z else bas
			f.batch.box("trim", xf, Vector3(rx, py + 0.25, pz), Vector3(0.03, 0.5, 0.03), Color(0.18, 0.2, 0.2))
	# Les murs de la venelle : hauts entre les jardins des maisons, puis plus bas à chaque terrasse.
	var hauteurs := [1.05, 0.75, 0.55, 0.35]
	for s in [-1.0, 1.0]:
		var wx: float = VENELLE_X + s * (w / 2.0 + 0.1)
		for i in TERRASSES.size():
			var z0: float = TERRASSES[i][0] + (0.0 if i == 0 else 0.2)
			var z1: float = TERRASSES[i + 1][0] - 0.2 if i + 1 < TERRASSES.size() else EAU_Z0 - 1.2
			var y: float = TERRASSES[i][1]
			if i == TERRASSES.size() - 1:
				break
			f.garden_wall(Vector3(wx, y, z0), Vector3(wx, y, z1), hauteurs[i], Color(0.9, 0.84, 0.72))
			v.main._solid_box(Vector3(0.18, 1.6, z1 - z0), Vector3(wx, y + 0.8, (z0 + z1) / 2.0))
	# Dans le mur haut, à l'ouest, une porte de jardin peinte, et la boîte aux lettres de la maison d'à côté.
	var porte := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(VENELLE_X - w / 2.0 - 0.02, 0.0, 17.2))
	f.batch.box("trim", porte, Vector3(0, 0.45, 0), Vector3(0.62, 0.9, 0.05), BOIS_VERT)
	f.batch.box("trim", porte, Vector3(0, 0.93, 0), Vector3(0.74, 0.06, 0.08), PIERRE.lightened(0.1))
	f.batch.box("trim", porte, Vector3(0.22, 0.45, 0.03), Vector3(0.05, 0.05, 0.03), Color(0.75, 0.6, 0.25))


## Une plaque de rue émaillée bleue, posée sur un mur (xf : son centre, +Z vers le lecteur).
func _plaque_emaillee(xf: Transform3D, texte: String) -> void:
	var largeur := 0.12 + texte.length() * 0.055
	f.batch.box("trim", xf, Vector3.ZERO, Vector3(largeur, 0.26, 0.03), Color(0.95, 0.95, 0.92))
	f.batch.box("trim", xf, Vector3(0, 0, 0.005), Vector3(largeur - 0.05, 0.2, 0.03), Color(0.14, 0.26, 0.6))
	var l := Label3D.new()
	l.text = texte
	l.font = v.main.serif
	l.font_size = 40
	l.pixel_size = 0.0019
	l.modulate = Color(0.97, 0.97, 0.95)
	l.outline_size = 0
	l.transform = xf * Transform3D(Basis(), Vector3(0, 0, 0.03))
	v.add_child(l)


## L'escalier de la placette : du bout de la rue (la placette) à la berge, le long du mur ouest.
func _escalier_placette() -> void:
	var w := ESCALIER_W
	for i in TERRASSES.size():
		var z0: float = TERRASSES[i][0]
		var z1: float = TERRASSES[i + 1][0] if i + 1 < TERRASSES.size() else EAU_Z0 - 0.6
		var y: float = TERRASSES[i][1]
		v.main._box(Vector3(w, 0.04, z1 - z0), Vector3(ESCALIER_X, y + 0.02, (z0 + z1) / 2.0), v.mats.gravel, v)
	for i in range(1, TERRASSES.size()):
		var z: float = TERRASSES[i][0]
		var haut: float = TERRASSES[i - 1][1]
		var bas: float = TERRASSES[i][1]
		_marches(ESCALIER_X, w, z - 0.15, haut, bas, maxi(2, int(round((haut - bas) / 0.15))), 0.3)
	# Une rampe de bois le long du chemin, côté ouest, et la haie de buis de l'autre côté.
	for i in TERRASSES.size() - 1:
		var y: float = TERRASSES[i][1]
		var z0: float = TERRASSES[i][0] + 0.3
		var z1: float = TERRASSES[i + 1][0] - 0.3
		v.main._box(Vector3(0.45, 0.45, z1 - z0), Vector3(ESCALIER_X + w / 2.0 + 0.3, y + 0.22, (z0 + z1) / 2.0), _buis(), v)
		v.main._solid_box(Vector3(0.45, 1.0, z1 - z0), Vector3(ESCALIER_X + w / 2.0 + 0.3, y + 0.5, (z0 + z1) / 2.0))


var _buis_mat: StandardMaterial3D


func _buis() -> StandardMaterial3D:
	if _buis_mat == null:
		_buis_mat = StandardMaterial3D.new()
		_buis_mat.albedo_color = Color(0.2, 0.34, 0.17)
		_buis_mat.albedo_texture = v.main._noise_tex(false, 0.7, Color(0.75, 0.85, 0.7))
		_buis_mat.uv1_triplanar = true
		_buis_mat.roughness = 0.95
	return _buis_mat


# --- Les parcelles -----------------------------------------------------------------------------

## Chaque terrasse est partagée en parcelles qui ne se ressemblent pas : le potager du boucher, les
## fleurs d'Odette, le verger, le poulailler, la cabane à outils, le carré de vigne. Les clôtures
## (murets, piquets, haies) se posent entre elles, pas partout.
func _parcelles() -> void:
	var t1: float = TERRASSES[1][1]
	var t2: float = TERRASSES[2][1]
	# Terrasse haute (z 15,3 à 19) : les jardins des maisons continuent, chacun à son usage.
	_fleurs_odette(-24.6, -27.8, 15.7, 18.6)
	_potager(-13.0, -20.0, 15.8, 18.5, 0.0, 4)
	_tas_de_bois(Vector3(-21.4, 0, 16.2))
	_cabane(Vector3(-23.0, 0, 18.1), 0.0, 1.4, 1.1, Color(0.42, 0.34, 0.26))
	_verger(-31.0, -40.0, 15.9, 18.6, 0.0, 4)
	_etendoir(Vector3(-42.5, 0, 17.0), 2.6)
	_potager(-44.5, -52.0, 15.8, 18.5, 0.0, 5)
	_cabane(Vector3(-57.0, 0, 17.4), PI / 2.0, 1.6, 1.2, Color(0.55, 0.42, 0.3))
	_cloture_piquets(-41.0, 15.6, 18.8, 0.0)
	# Terrasse du milieu (z 19 à 23,5) : le verger du presbytère d'autrefois, le poulailler, la serre.
	_verger(-12.5, -22.5, 19.6, 23.0, t1, 6)
	_poulailler(Vector3(-25.2, t1, 21.6))
	_serre(Vector3(-33.0, t1, 21.2))
	_potager(-36.0, -44.0, 19.6, 22.8, t1, 5)
	_vigne(-45.5, -52.4, 19.7, 22.9, t1)
	_ruches(Vector3(-56.4, t1, 21.0))
	_cabane(Vector3(-35.0, t1, 22.9), PI, 1.2, 1.0, BOIS_GRIS)
	# Terrasse basse (z 23,5 à 27,5) : les jardins des bords d'eau, plus libres, et les grands arbres.
	_potager(-13.0, -19.0, 24.0, 26.8, t2, 4)
	_compost(Vector3(-20.6, t2, 26.6))
	v._tree(Vector3(-23.6, t2, 25.3), "tree_detailed_fall", 1.9)
	_banc(Vector3(-26.4, t2, 26.9), 0.0)
	_pelouse_fleurie(-31.0, -36.5, 24.0, 27.0, t2)
	_tonnelle(Vector3(-38.6, t2, 25.4))
	_belvedere(Vector3(-31.4, t1, 22.75))
	_potager(-42.0, -50.0, 24.0, 26.8, t2, 4)
	v._tree(Vector3(-56.5, t2, 25.2), "tree_oak_fall", 1.8)
	v._place(KM + "props/wheelbarrow.gltf", Vector3(-41.2, t2, 26.9), 1.4, 120.0)


## Vu de haut, les murets filaient droit d'un bout à l'autre : des touffes de buis, de laurier et de
## sureau débordent du chaperon par endroits, et trois arbres de plus cassent la grille des parcelles.
func _rompre() -> void:
	var rng := f.rng as RandomNumberGenerator
	for i in range(1, TERRASSES.size()):
		var z: float = TERRASSES[i][0]
		var haut: float = TERRASSES[i - 1][1]
		var x := X1 + rng.randf_range(1.0, 3.0)
		while x < X0 - 1.0:
			if absf(x + 0.9 - VENELLE_X) > 2.9 and absf(x + 0.9 - ESCALIER_X) > 2.9:
				for k in rng.randi_range(2, 3):
					var m: String = ["plant_bushLarge", "plant_bushDetailed", "plant_bush"][rng.randi() % 3]
					var at := Vector3(x + k * rng.randf_range(0.5, 0.9), haut, z - rng.randf_range(0.3, 0.8))
					v._place(v.KN + m + ".glb", at, rng.randf_range(3.5, 5.0), rng.randf() * 360.0)
			x += rng.randf_range(3.5, 8.0)
	var t1: float = TERRASSES[1][1]
	var t2: float = TERRASSES[2][1]
	v._tree(Vector3(-35.9, t2, 24.5), "tree_fat_fall", 1.6)
	v._tree(Vector3(-44.9, t1, 21.3), "tree_default_fall", 1.4)
	v._tree(Vector3(-53.6, 0.0, 16.6), "tree_blocks_fall", 1.3)


## Un potager en rangs de x0 à x1 (vers l'ouest), rangs perpendiculaires à la pente, avec ses rames.
func _potager(x0: float, x1: float, z0: float, z1: float, y: float, rangs: int) -> void:
	var rng := f.rng as RandomNumberGenerator
	var xf := Transform3D()
	var terre := Color(0.34, 0.23, 0.15)
	f.batch.box("trim", xf, Vector3((x0 + x1) / 2.0, y + 0.02, (z0 + z1) / 2.0), Vector3(absf(x1 - x0), 0.04, z1 - z0), terre)
	for r in rangs:
		var z := z0 + (z1 - z0) * (r + 0.5) / rangs
		var kind := rng.randi() % 4
		f.batch.box("trim", xf, Vector3((x0 + x1) / 2.0, y + 0.06, z), Vector3(absf(x1 - x0) - 0.3, 0.06, 0.22), terre.darkened(0.15))
		var x := minf(x0, x1) + 0.4
		while x < maxf(x0, x1) - 0.3:
			match kind:
				0:  # Choux et salades, en boules.
					f.batch.box("trim", xf, Vector3(x, y + 0.13, z), Vector3(0.2, 0.14, 0.2), VEGETAL.lightened(rng.randf() * 0.2))
				1:  # Haricots à rames.
					f.batch.box("trim", xf, Vector3(x, y + 0.35, z), Vector3(0.03, 0.62, 0.03), BOIS_GRIS)
					f.batch.box("trim", xf, Vector3(x, y + 0.3, z), Vector3(0.12, 0.42, 0.12), VEGETAL.darkened(0.1))
				2:  # Poireaux.
					f.batch.box("trim", xf, Vector3(x, y + 0.14, z), Vector3(0.05, 0.2, 0.05), Color(0.6, 0.72, 0.45))
				_:  # Tomates sur tuteurs, quelques fruits rouges.
					f.batch.box("trim", xf, Vector3(x, y + 0.28, z), Vector3(0.14, 0.42, 0.14), VEGETAL)
					if rng.randf() < 0.6:
						f.batch.box("trim", xf, Vector3(x + 0.06, y + 0.22, z + 0.07), Vector3(0.05, 0.05, 0.05), Color(0.82, 0.16, 0.1))
			x += 0.32 if kind != 1 else 0.45
	# Un arrosoir et une citrouille au bout d'un rang.
	v._place(KM + "props/bucket_water.gltf", Vector3(minf(x0, x1) + 0.3, y, z1 - 0.2), 1.3, rng.randf() * 360.0)
	if rng.randf() < 0.5:
		v._place(v.KN + "crop_pumpkin.glb", Vector3(maxf(x0, x1) - 0.4, y, z0 + 0.3), 1.2, rng.randf() * 360.0)


## Les fleurs d'Odette : la fleuriste cultive derrière sa boutique ce qu'elle vend devant.
func _fleurs_odette(x0: float, x1: float, z0: float, z1: float) -> void:
	var xf := Transform3D()
	var couleurs := [Color(0.9, 0.2, 0.3), Color(0.98, 0.8, 0.2), Color(0.95, 0.95, 0.9), Color(0.6, 0.35, 0.75), Color(0.98, 0.5, 0.2)]
	var rangs := 5
	for r in rangs:
		var z := z0 + (z1 - z0) * (r + 0.5) / rangs
		var c: Color = couleurs[r % couleurs.size()]
		f.batch.box("trim", xf, Vector3((x0 + x1) / 2.0, 0.05, z), Vector3(absf(x1 - x0) - 0.4, 0.06, 0.3), Color(0.3, 0.2, 0.13))
		var x := minf(x0, x1) + 0.35
		while x < maxf(x0, x1) - 0.3:
			f.batch.box("trim", xf, Vector3(x, 0.14, z), Vector3(0.12, 0.14, 0.14), VEGETAL.darkened(0.1))
			f.batch.box("trim", xf, Vector3(x, 0.23, z), Vector3(0.14, 0.06, 0.14), c)
			x += 0.24
	# Les seaux de zinc où trempent les fleurs coupées, près de la porte de derrière.
	for i in 3:
		v._place(KM + "props/bucket_empty.gltf", Vector3(x0 - 0.3 - i * 0.35, 0, z0 + 0.15), 1.1)


func _verger(x0: float, x1: float, z0: float, z1: float, y: float, n: int) -> void:
	var rng := f.rng as RandomNumberGenerator
	for i in n:
		var x := lerpf(x0, x1, (i + 0.5) / n) + rng.randf_range(-0.4, 0.4)
		var z := lerpf(z0, z1, 0.3 + 0.4 * (i % 2)) + rng.randf_range(-0.3, 0.3)
		v._tree(Vector3(x, y, z), ["tree_default_fall", "tree_fat_fall", "tree_blocks_fall"][i % 3], rng.randf_range(1.1, 1.4))
	# Les pommes tombées, et une échelle contre un arbre.
	var xf := Transform3D()
	for k in 14:
		f.batch.box("trim", xf, Vector3(rng.randf_range(minf(x0, x1), maxf(x0, x1)), y + 0.04, rng.randf_range(z0, z1)), Vector3(0.06, 0.06, 0.06), Color(0.75, 0.2, 0.12) if k % 3 else Color(0.8, 0.7, 0.2))
	var echelle: Node3D = v._place(KM + "props/ladder.gltf", Vector3(lerpf(x0, x1, 0.5 / n) + 0.4, y, lerpf(z0, z1, 0.3)), 1.4, 20.0)
	echelle.rotation_degrees.x = -15.0


func _tas_de_bois(at: Vector3) -> void:
	v._place(v.KN + "log_stack.glb", at, 1.0, 0.0)
	v._place(v.KN + "log_stack.glb", at + Vector3(0.9, 0, 0), 1.0, 0.0)
	v._place(v.KN + "stump_round.glb", at + Vector3(0.4, 0, 0.7), 1.0)


## Une cabane à outils en planches, toit à un pan, porte entrebâillée.
func _cabane(at: Vector3, rot: float, w: float, d: float, bois: Color) -> void:
	var xf := Transform3D(Basis(Vector3.UP, rot), at)
	var h := 1.0
	f.batch.box("wall", xf, Vector3(0, h / 2.0, 0), Vector3(w, h, d), bois)
	for i in int(w / 0.18):
		f.batch.box("trim", xf, Vector3(-w / 2.0 + 0.09 + i * 0.18, h / 2.0, d / 2.0 + 0.005), Vector3(0.02, h, 0.01), bois.darkened(0.3))
	f.batch.quad("roof", xf, [Vector3(-w / 2.0 - 0.1, h + 0.25, -d / 2.0 - 0.1), Vector3(w / 2.0 + 0.1, h + 0.25, -d / 2.0 - 0.1), Vector3(w / 2.0 + 0.1, h, d / 2.0 + 0.15), Vector3(-w / 2.0 - 0.1, h, d / 2.0 + 0.15)],
		Vector3(0, 0.97, 0.24), Color(0.48, 0.5, 0.52), [Vector2(0, 0), Vector2(w, 0), Vector2(w, d), Vector2(0, d)])
	f.batch.box("trim", xf, Vector3(w * 0.15, 0.4, d / 2.0 + 0.02), Vector3(0.45, 0.8, 0.02), Color(0.06, 0.05, 0.04))
	var porte := xf * Transform3D(Basis(Vector3.UP, -0.7), Vector3(w * 0.15 - 0.22, 0, d / 2.0 + 0.02))
	f.batch.box("trim", porte, Vector3(0.22, 0.4, 0), Vector3(0.45, 0.8, 0.03), bois.lightened(0.1))
	v.main._solid_box(Vector3(w, 1.2, d), at + Vector3(0, 0.6, 0))


## Le linge qui sèche : deux poteaux, un fil, des draps et des chemises dans un seul vent (vers l'est).
func _etendoir(at: Vector3, len: float) -> void:
	var xf := Transform3D(Basis(), at)
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(s * len / 2.0, 0.6, 0), Vector3(0.05, 1.2, 0.05), BOIS_GRIS)
	f.batch.box("trim", xf, Vector3(0, 1.17, 0), Vector3(len, 0.012, 0.012), Color(0.85, 0.85, 0.82))
	var pieces := [[0.6, 0.55, Color(0.96, 0.95, 0.9)], [0.3, 0.35, Color(0.35, 0.5, 0.78)], [0.6, 0.6, Color(0.95, 0.92, 0.85)], [0.28, 0.32, Color(0.85, 0.3, 0.3)], [0.24, 0.3, Color(0.96, 0.95, 0.9)]]
	var x := -len / 2.0 + 0.2
	for p in pieces:
		var pw: float = p[0]
		var ph: float = p[1]
		var px := xf * Transform3D(Basis(Vector3.UP, 0.12), Vector3(x + pw / 2.0, 1.16 - ph / 2.0, 0))
		f.batch.box("trim", px, Vector3.ZERO, Vector3(pw, ph, 0.015), p[2])
		x += pw + 0.08
	v._place(v.KN + "pot_large.glb", at + Vector3(len / 2.0 + 0.3, 0, 0.4), 0.9)


func _cloture_piquets(x: float, z0: float, z1: float, y: float) -> void:
	var xf := Transform3D()
	var z := z0
	while z < z1:
		f.batch.box("trim", xf, Vector3(x, y + 0.3, z), Vector3(0.05, 0.6, 0.05), BOIS_GRIS)
		z += 0.4
	for hh in [0.2, 0.45]:
		f.batch.box("trim", xf, Vector3(x, y + hh, (z0 + z1) / 2.0), Vector3(0.015, 0.015, z1 - z0), Color(0.55, 0.55, 0.52))


func _poulailler(at: Vector3) -> void:
	_cabane(at + Vector3(-0.8, 0, -0.6), 0.0, 1.2, 0.9, Color(0.62, 0.35, 0.22))
	# Le parc grillagé devant, et les poules.
	var xf := Transform3D(Basis(), at)
	var w := 2.6
	var d := 1.6
	for s in [-1.0, 1.0]:
		f.batch.box("vitre", xf, Vector3(s * w / 2.0, 0.3, 0.3), Vector3(0.02, 0.6, d), Color(0.7, 0.72, 0.7, 0.3))
	f.batch.box("vitre", xf, Vector3(0, 0.3, 0.3 + d / 2.0), Vector3(w, 0.6, 0.02), Color(0.7, 0.72, 0.7, 0.3))
	for c in [[-0.3, 0.6], [0.4, 0.9], [0.9, 0.4], [-0.9, 0.95]]:
		var poule := xf * Transform3D(Basis(Vector3.UP, c[0] * 3.0), Vector3(c[0], 0, c[1]))
		f.batch.box("trim", poule, Vector3(0, 0.1, 0), Vector3(0.14, 0.12, 0.2), Color(0.55, 0.3, 0.15) if c[0] > 0 else Color(0.95, 0.93, 0.88))
		f.batch.box("trim", poule, Vector3(0, 0.19, 0.08), Vector3(0.07, 0.08, 0.07), Color(0.95, 0.93, 0.88))
		f.batch.box("trim", poule, Vector3(0, 0.24, 0.09), Vector3(0.02, 0.03, 0.04), Color(0.85, 0.12, 0.1))
	v.main._solid_box(Vector3(w, 0.8, d), at + Vector3(0, 0.4, 0.3))


## La serre de verre et de fer : des carreaux blancs sur un châssis vert, des semis dedans.
func _serre(at: Vector3) -> void:
	var xf := Transform3D(Basis(), at)
	var w := 2.4
	var d := 1.5
	var h := 0.9
	var fer := Color(0.22, 0.34, 0.27)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			f.batch.box("trim", xf, Vector3(sx * w / 2.0, h / 2.0, sz * d / 2.0), Vector3(0.04, h, 0.04), fer)
	f.batch.box("trim", xf, Vector3(0, h + 0.35, 0), Vector3(w, 0.04, 0.04), fer)
	for s in [-1.0, 1.0]:
		f.batch.box_tilted("vitre", xf, Vector3(0, h + 0.17, s * d / 4.0), Vector3(w, 0.02, d / 2.0 + 0.1), s * deg_to_rad(-25.0), Color(0.85, 0.92, 0.9, 0.35))
		f.batch.box("vitre", xf, Vector3(0, h / 2.0, s * d / 2.0), Vector3(w, h, 0.02), Color(0.85, 0.92, 0.9, 0.35))
		f.batch.box("vitre", xf, Vector3(s * w / 2.0, h / 2.0, 0), Vector3(0.02, h, d), Color(0.85, 0.92, 0.9, 0.35))
	for i in 6:
		f.batch.box("trim", xf, Vector3(-w / 2.0 + 0.3 + i * 0.36, 0.42, 0), Vector3(0.28, 0.06, d * 0.7), Color(0.4, 0.3, 0.2))
		f.batch.box("trim", xf, Vector3(-w / 2.0 + 0.3 + i * 0.36, 0.5, 0), Vector3(0.24, 0.08, d * 0.6), VEGETAL.lightened(0.2))
	v.main._solid_box(Vector3(w, 1.4, d), at + Vector3(0, 0.7, 0))


## Un carré de vigne en rangs palissés, pour le vin de la maison.
func _vigne(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var xf := Transform3D()
	var rangs := 4
	for r in rangs:
		var z := z0 + (z1 - z0) * (r + 0.5) / rangs
		f.batch.box("trim", xf, Vector3((x0 + x1) / 2.0, y + 0.5, z), Vector3(absf(x1 - x0) - 0.4, 0.012, 0.012), Color(0.5, 0.5, 0.48))
		var x := minf(x0, x1) + 0.3
		while x < maxf(x0, x1) - 0.2:
			f.batch.box("trim", xf, Vector3(x, y + 0.25, z), Vector3(0.04, 0.5, 0.04), Color(0.35, 0.24, 0.16))
			f.batch.box("trim", xf, Vector3(x + 0.15, y + 0.45, z), Vector3(0.36, 0.18, 0.16), Color(0.78, 0.45, 0.12) if r % 2 else Color(0.62, 0.22, 0.1))
			x += 0.5


## Trois ruches peintes sur leurs parpaings, au fond, à l'abri du mur.
func _ruches(at: Vector3) -> void:
	var couleurs := [Color(0.95, 0.85, 0.45), Color(0.5, 0.7, 0.85), Color(0.92, 0.92, 0.88)]
	for i in 3:
		var xf := Transform3D(Basis(Vector3.UP, 0.1 * i), at + Vector3(0, 0, (i - 1) * 0.9))
		f.batch.box("trim", xf, Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.5), PIERRE_SOMBRE)
		f.batch.box("wall", xf, Vector3(0, 0.38, 0), Vector3(0.44, 0.44, 0.44), couleurs[i])
		f.batch.box("trim", xf, Vector3(0, 0.63, 0), Vector3(0.52, 0.06, 0.52), Color(0.45, 0.47, 0.48))
		f.batch.box("trim", xf, Vector3(0.23, 0.2, 0), Vector3(0.02, 0.03, 0.2), Color(0.1, 0.08, 0.05))
	v.main._solid_box(Vector3(0.6, 0.8, 2.6), at + Vector3(0, 0.4, 0))


func _compost(at: Vector3) -> void:
	var xf := Transform3D(Basis(), at)
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(s * 0.45, 0.25, 0), Vector3(0.04, 0.5, 0.9), BOIS_GRIS)
	f.batch.box("trim", xf, Vector3(0, 0.25, -0.43), Vector3(0.9, 0.5, 0.04), BOIS_GRIS)
	f.batch.box("trim", xf, Vector3(0, 0.15, 0), Vector3(0.86, 0.3, 0.86), Color(0.3, 0.22, 0.14))


func _banc(at: Vector3, rot: float) -> void:
	v._place(v.KK + "city/bench.gltf", at, 2.0, rad_to_deg(rot))


func _pelouse_fleurie(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var rng := f.rng as RandomNumberGenerator
	for i in 10:
		var model: String = ["flower_redA", "flower_yellowA", "flower_purpleA", "flower_yellowB", "grass_large"][i % 5]
		v._place(v.KN + model + ".glb", Vector3(rng.randf_range(minf(x0, x1), maxf(x0, x1)), y, rng.randf_range(z0, z1)), 1.2, rng.randf() * 360.0)


## La barque du pêcheur, amarrée au ponton : coque verte à l'extérieur, bois clair dedans, deux bancs.
func _barque(at: Vector3, rot: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, rot), at)
	var coque := Color(0.2, 0.4, 0.32)
	var dedans := Color(0.72, 0.62, 0.46)
	var l := 1.9
	var w := 0.62
	f.batch.box("trim", xf, Vector3(0, 0.05, 0), Vector3(l * 0.8, 0.22, w), coque)
	for s in [-1.0, 1.0]:
		# La proue et la poupe, qui se resserrent.
		f.batch.box("trim", xf * Transform3D(Basis(Vector3.UP, s * 0.5), Vector3(s * l * 0.42, 0.06, 0.12)), Vector3.ZERO, Vector3(0.36, 0.2, 0.06), coque)
		f.batch.box("trim", xf * Transform3D(Basis(Vector3.UP, -s * 0.5), Vector3(s * l * 0.42, 0.06, -0.12)), Vector3.ZERO, Vector3(0.36, 0.2, 0.06), coque)
	f.batch.box("trim", xf, Vector3(0, 0.09, 0), Vector3(l * 0.76, 0.16, w - 0.08), dedans)
	for bx in [-0.4, 0.35]:
		f.batch.box("trim", xf, Vector3(bx, 0.15, 0), Vector3(0.18, 0.03, w - 0.1), dedans.darkened(0.2))
	f.batch.box("trim", xf, Vector3(0.1, 0.19, 0.12), Vector3(1.2, 0.02, 0.03), dedans.darkened(0.3))
	f.batch.box("trim", Transform3D(), Vector3(at.x + 0.2, at.y + 0.3, at.z - 0.6), Vector3(0.01, 0.01, 0.9), Color(0.6, 0.55, 0.45))


## La tonnelle de vigne vierge, sa table de fer et ses trois chaises : on y prend l'apéritif l'été.
func _tonnelle(at: Vector3) -> void:
	var xf := Transform3D(Basis(), at)
	var fer := Color(0.22, 0.3, 0.26)
	for sx in [-1.1, 1.1]:
		for sz in [-0.8, 0.8]:
			f.batch.box("trim", xf, Vector3(sx, 0.75, sz), Vector3(0.05, 1.5, 0.05), fer)
	for sz in [-0.8, 0.0, 0.8]:
		f.batch.box("trim", xf, Vector3(0, 1.5, sz), Vector3(2.3, 0.04, 0.04), fer)
	var rng := f.rng as RandomNumberGenerator
	for i in 16:
		var p := Vector3(rng.randf_range(-1.1, 1.1), 1.55 + rng.randf() * 0.08, rng.randf_range(-0.85, 0.85))
		f.batch.box("trim", xf, p, Vector3(rng.randf_range(0.35, 0.6), 0.1, rng.randf_range(0.3, 0.5)), Color(0.62, 0.18, 0.12).lerp(Color(0.35, 0.45, 0.2), rng.randf()))
	for sx in [-1.1, 1.1]:
		f.batch.box("trim", xf, Vector3(sx, 0.9, 0.8), Vector3(0.18, 1.2, 0.12), Color(0.45, 0.2, 0.12))
	f.batch.cylinder("trim", xf, Vector3(0, 0.0, 0), 0.04, 0.38, fer, 6)
	f.batch.cylinder("trim", xf, Vector3(0, 0.38, 0), 0.38, 0.03, Color(0.92, 0.9, 0.84), 12)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var c := xf * Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * 0.62, 0, cos(a) * 0.62))
		f.batch.box("trim", c, Vector3(0, 0.22, 0), Vector3(0.3, 0.03, 0.3), fer)
		f.batch.box("trim", c, Vector3(0, 0.4, 0.14), Vector3(0.3, 0.35, 0.03), fer)
	# Une bouteille et deux verres, oubliés.
	f.batch.cylinder("trim", xf, Vector3(0.1, 0.41, 0.05), 0.035, 0.2, Color(0.15, 0.3, 0.12), 6)
	v.main._solid_box(Vector3(1.6, 0.6, 1.6), at + Vector3(0, 0.3, 0))


## Le banc du belvédère, au bord du mur : de là, on voit le bief, la passerelle et le pré.
func _belvedere(at: Vector3) -> void:
	_banc(at, PI)
	v._tree(at + Vector3(-1.4, 0, -0.6), "tree_default_fall", 1.5)


# --- La berge, le bief et le pré ---------------------------------------------------------------

func _berge() -> void:
	var y: float = TERRASSES[TERRASSES.size() - 1][1]
	var xf := Transform3D()
	# Le bord de la berge : de grosses pierres plates, un peu de travers, et l'herbe haute près de l'eau.
	var rng := f.rng as RandomNumberGenerator
	var x := X1
	while x < X0:
		var lw := rng.randf_range(0.5, 1.1)
		var bord := xf * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), Vector3(x + lw / 2.0, y - 0.08, EAU_Z0 - 0.15))
		f.batch.box("trim", bord, Vector3.ZERO, Vector3(lw - 0.04, 0.2, 0.4), PIERRE.darkened(rng.randf_range(0.05, 0.25)))
		x += lw
	for i in 22:
		var gx := rng.randf_range(X1 + 0.5, X0 - 0.5)
		if absf(gx - PASSERELLE_X) < 1.2 or absf(gx - PONTON_X) < 1.4:
			continue
		v._place(v.KN + ["grass_large", "plant_flatTall", "grass"][i % 3] + ".glb", Vector3(gx, y, EAU_Z0 - rng.randf_range(0.4, 0.9)), 1.3, rng.randf() * 360.0)
	# Le chemin de berge, de gravier, entre l'herbe du pied du mur et les joncs du bord de l'eau.
	v.main._box(Vector3(absf(X0 - X1), 0.04, 1.0), Vector3((X0 + X1) / 2.0, y + 0.01, 28.6), v.mats.gravel, v)
	# Les saules têtards : un tronc court et noueux, une boule de rameaux. Ils cadrent le bief sans le cacher.
	for sx in [-15.0, -24.6, -33.5, -43.0, -50.6, -57.2]:
		var s := Transform3D(Basis(Vector3.UP, sx), Vector3(sx, y, 29.55))
		f.batch.cylinder("trim", s, Vector3.ZERO, 0.16, 0.9, Color(0.36, 0.3, 0.24), 7)
		f.batch.cylinder("trim", s, Vector3(0, 0.9, 0), 0.24, 0.12, Color(0.32, 0.26, 0.2), 7)
		for k in 7:
			var a := TAU * k / 7.0
			f.batch.box("trim", s * Transform3D(Basis(Vector3(cos(a), 0, -sin(a)), 0.5), Vector3(sin(a) * 0.15, 1.0, cos(a) * 0.15)), Vector3(0, 0.35, 0), Vector3(0.22, 0.75, 0.22), Color(0.55, 0.62, 0.3).darkened(0.1 * (k % 3)))
		v.main._solid_box(Vector3(0.35, 1.2, 0.35), Vector3(sx, y + 0.6, 29.55))
	# Les rochers et les joncs qui cassent la ligne de la rive, des deux côtés.
	for i in 10:
		var rx := rng.randf_range(X1 + 1.0, X0 - 2.0)
		if absf(rx - PASSERELLE_X) < 1.2 or absf(rx - PONTON_X) < 1.2:
			continue
		var rz := EAU_Z0 + rng.randf_range(0.0, 0.4) if i % 2 else EAU_Z1 - rng.randf_range(0.0, 0.4)
		v._place(KM + "nature/rock_single_%s.gltf" % ["A", "C", "D", "E"][i % 4], Vector3(rx, EAU_Y - 0.05, rz), 1.3, rng.randf() * 360.0)
		v._place(v.KN + "plant_flatTall.glb", Vector3(rx + 0.5, EAU_Y, rz), 1.6, rng.randf() * 360.0)
	_barque(Vector3(PONTON_X + 1.3, EAU_Y + 0.02, EAU_Z0 + 1.0), 1.45)
	# On ne tombe pas à l'eau ; on passe sur la passerelle et sur le ponton.
	for s in _hors([[PASSERELLE_X - 0.5, PASSERELLE_X + 0.5], [PONTON_X - 0.7, PONTON_X + 0.7]]):
		v.main._solid_box(Vector3(s[1] - s[0], 1.4, 0.2), Vector3((s[0] + s[1]) / 2.0, y + 0.5, EAU_Z0 - 0.05))
	# Le ponton du pêcheur, sa chaise pliante, sa bourriche et ses cannes.
	var p := Transform3D(Basis(), Vector3(PONTON_X, y, EAU_Z0))
	for i in 7:
		f.batch.box("trim", p, Vector3(0, -0.02, 0.15 + i * 0.22), Vector3(1.4, 0.05, 0.2), BOIS_GRIS.lightened(0.05 * (i % 2)))
	for sx in [-0.65, 0.65]:
		for sz in [0.3, 1.5]:
			f.batch.box("trim", p, Vector3(sx, -0.25, sz), Vector3(0.08, 0.5, 0.08), BOIS_GRIS.darkened(0.3))
	f.batch.box("trim", p, Vector3(0.3, 0.6, 1.2), Vector3(0.015, 0.015, 2.6), Color(0.25, 0.2, 0.15))
	v._place(KM + "props/bucket_water.gltf", Vector3(PONTON_X - 0.45, y, EAU_Z0 + 0.4), 1.2)
	v.main._solid_box(Vector3(1.4, 0.4, 1.6), Vector3(PONTON_X, y - 0.2, EAU_Z0 + 0.8))
	v.main._solid_box(Vector3(0.1, 1.2, 1.6), Vector3(PONTON_X - 0.75, y + 0.5, EAU_Z0 + 0.8))
	v.main._solid_box(Vector3(0.1, 1.2, 1.6), Vector3(PONTON_X + 0.75, y + 0.5, EAU_Z0 + 0.8))
	v.main._solid_box(Vector3(1.6, 1.2, 0.1), Vector3(PONTON_X, y + 0.5, EAU_Z0 + 1.65))
	# Le battoir des laveuses : deux pierres inclinées vers l'eau, une caisse à genoux, un baquet.
	var b := Transform3D(Basis(), Vector3(-20.5, y, EAU_Z0 - 0.3))
	for i in 2:
		f.batch.box_tilted("trim", b, Vector3(-0.6 + i * 1.2, 0.05, 0.25), Vector3(1.0, 0.08, 0.5), deg_to_rad(14.0), PIERRE.lightened(0.08))
	f.batch.box("trim", b, Vector3(-0.6, 0.12, -0.25), Vector3(0.5, 0.24, 0.35), BOIS_GRIS)
	v._place(KM + "props/bucket_empty.gltf", Vector3(-19.4, y, EAU_Z0 - 0.7), 1.3)
	# La vanne, à l'est, d'où le bief arrive sous la route : deux montants, la crémaillère, le volant.
	var vn := Transform3D(Basis(), Vector3(X0 + 0.9, y, (EAU_Z0 + EAU_Z1) / 2.0))
	for s in [-1.0, 1.0]:
		f.batch.box("wall", vn, Vector3(0, -0.1, s * 1.9), Vector3(0.6, 0.9, 0.4), PIERRE)
	f.batch.box("trim", vn, Vector3(0, -0.15, 0), Vector3(0.12, 0.6, 3.5), Color(0.32, 0.25, 0.18))
	f.batch.box("trim", vn, Vector3(0, 0.45, 0), Vector3(0.18, 0.12, 3.9), Color(0.25, 0.27, 0.27))
	f.batch.box("trim", vn, Vector3(0, 0.75, 0), Vector3(0.05, 0.6, 0.05), Color(0.25, 0.27, 0.27))
	f.batch.cylinder("trim", vn, Vector3(0, 1.05, 0), 0.22, 0.04, Color(0.55, 0.12, 0.1), 10)


func _bief() -> void:
	var cx := (X0 + X1) / 2.0
	var sx := absf(X0 - X1)
	var w := EAU_Z1 - EAU_Z0
	# Le fond et les berges du bief, puis l'eau.
	v.main._box(Vector3(sx, 0.4, w), Vector3(cx, EAU_Y - 0.35, (EAU_Z0 + EAU_Z1) / 2.0), v.mats.earth, v)
	var eau: MeshInstance3D = v.main._box(Vector3(sx, 0.06, w), Vector3(cx, EAU_Y - 0.03, (EAU_Z0 + EAU_Z1) / 2.0), v.mats.water, v)
	eau.name = "BiefDuMoulin"
	# Les nénuphars et les herbes d'eau, contre les berges.
	var rng := f.rng as RandomNumberGenerator
	for i in 14:
		var x := rng.randf_range(X1 + 1.0, X0 - 2.0)
		if absf(x - PASSERELLE_X) < 1.0:
			continue
		var z := EAU_Z0 + 0.3 if i % 2 else EAU_Z1 - 0.3
		v._place(KM + "nature/waterlily_%s.gltf" % ["A", "B"][i % 2], Vector3(x, EAU_Y + 0.01, z + rng.randf_range(-0.1, 0.4) * (1 if i % 2 else -1)), 1.3, rng.randf() * 360.0)
		if i % 3 == 0:
			v._place(KM + "nature/waterplant_%s.gltf" % ["A", "B", "C"][i % 3], Vector3(x + 0.6, EAU_Y, z), 1.5)
	# La passerelle de planches, avec sa rambarde d'un seul côté.
	var p := Transform3D(Basis(), Vector3(PASSERELLE_X, 0, 0))
	var y: float = TERRASSES[TERRASSES.size() - 1][1]
	var z0 := EAU_Z0 - 0.4
	var z1 := EAU_Z1 + 0.4
	var n := int((z1 - z0) / 0.2)
	for i in n:
		f.batch.box("trim", p, Vector3(0, y + 0.06, z0 + 0.1 + i * 0.2), Vector3(1.0, 0.05, 0.18), BOIS_GRIS.lightened(0.06 * (i % 3)))
	for sz in [EAU_Z0 + 0.2, (EAU_Z0 + EAU_Z1) / 2.0, EAU_Z1 - 0.2]:
		for sx2 in [-0.45, 0.45]:
			f.batch.box("trim", p, Vector3(sx2, (EAU_Y + y) / 2.0, sz), Vector3(0.1, y - EAU_Y + 0.2, 0.1), BOIS_GRIS.darkened(0.3))
		f.batch.box("trim", p, Vector3(-0.5, y + 0.4, sz), Vector3(0.05, 0.7, 0.05), BOIS_GRIS)
	f.batch.box("trim", p, Vector3(-0.5, y + 0.75, (z0 + z1) / 2.0), Vector3(0.05, 0.05, z1 - z0), BOIS_GRIS)
	v.main._solid_box(Vector3(1.0, 0.2, z1 - z0), Vector3(PASSERELLE_X, y - 0.04, (z0 + z1) / 2.0))
	for sx3 in [-0.55, 0.55]:
		v.main._solid_box(Vector3(0.1, 1.2, EAU_Z1 - EAU_Z0), Vector3(PASSERELLE_X + sx3, y + 0.5, (EAU_Z0 + EAU_Z1) / 2.0))


func _pre() -> void:
	var cx := (X0 + X1) / 2.0
	var sx := absf(X0 - X1)
	v.main._box(Vector3(sx, 0.1, Z1 - EAU_Z1), Vector3(cx, PRE_Y - 0.05, (EAU_Z1 + Z1) / 2.0), v.mats.grass, v)
	v.main._solid_box(Vector3(sx, 0.4, Z1 - EAU_Z1), Vector3(cx, PRE_Y - 0.2, (EAU_Z1 + Z1) / 2.0))
	for s in _hors([[PASSERELLE_X - 0.5, PASSERELLE_X + 0.5]]):
		v.main._solid_box(Vector3(s[1] - s[0], 1.4, 0.2), Vector3((s[0] + s[1]) / 2.0, PRE_Y + 0.5, EAU_Z1 + 0.05))
	# Les peupliers et les saules du pré, une meule, la clôture à vaches.
	var rng := f.rng as RandomNumberGenerator
	var x := X1 + 1.5
	while x < X0 - 1.0:
		if absf(x - PASSERELLE_X) > 1.5:
			v._tree(Vector3(x, PRE_Y, Z1 - 0.9 + rng.randf_range(-0.3, 0.3)), "tree_cone" if rng.randf() < 0.7 else "tree_default", rng.randf_range(1.8, 2.3))
		x += rng.randf_range(2.4, 3.6)
	var xf := Transform3D()
	var px := X1 + 0.5
	while px < X0 - 0.5:
		f.batch.box("trim", xf, Vector3(px, PRE_Y + 0.3, EAU_Z1 + 0.9), Vector3(0.06, 0.6, 0.06), BOIS_GRIS)
		px += 1.2
	for hh in [0.25, 0.5]:
		f.batch.box("trim", xf, Vector3(cx, PRE_Y + hh, EAU_Z1 + 0.9), Vector3(sx - 1.0, 0.012, 0.012), Color(0.5, 0.5, 0.48))
	var meule := Transform3D(Basis(), Vector3(-32.0, PRE_Y, 35.0))
	f.batch.cylinder("trim", meule, Vector3.ZERO, 0.55, 0.9, Color(0.86, 0.72, 0.36), 10)
	f.batch.cylinder("trim", meule, Vector3(0, 0.9, 0), 0.4, 0.2, Color(0.8, 0.66, 0.32), 10)


# --- La vie ------------------------------------------------------------------------------------

## Ce qu'on fait aux jardins un soir de veille de loto : le pêcheur qui ne rentre pas, le jardinier qui
## arrose avant la nuit, la voisine qui rentre le linge, le promeneur du chemin de berge.
func _figurants() -> void:
	var y_berge: float = TERRASSES[TERRASSES.size() - 1][1]
	v.main._villager("pecheur-du-bief", Vector3(PONTON_X + 0.3, y_berge + 0.06, EAU_Z0 + 0.9), 0.0, "sit")
	v.main._villager("jardinier-du-haut", Vector3(-16.0, 0.06, 17.6), 90.0, "idle",
		[Vector3(-14.0, 0.06, 17.6), Vector3(-19.0, 0.06, 17.6)])
	v.main._villager("voisine-au-linge", Vector3(-42.5, 0.06, 17.6), 180.0)
	v.main._villager("promeneur-de-berge", Vector3(-30.0, y_berge + 0.06, 28.6), -90.0, "idle",
		[Vector3(-29.0, y_berge + 0.06, 28.6), Vector3(-53.0, y_berge + 0.06, 28.6)])
	v.main._villager("cueilleuse-du-verger", Vector3(-17.0, TERRASSES[1][1] + 0.06, 20.6), 30.0)
