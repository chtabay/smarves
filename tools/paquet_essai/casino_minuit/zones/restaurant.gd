extends RefCounted
## Lot C, zone M-RESTAURANT (js/zones/c-restaurant.js) : le restaurant « Le Lucullus » [18, 40] × [-30, -12],
## à la mezzanine (y = 6), 5 m sous plafond. Douze tables dressées (huit de quatre couverts, quatre de deux
## sur la banquette capitonnée du mur nord), le pupitre du maître d'hôtel, la cave à vin rétroéclairée, la
## cuisine ouverte (passe-plats, hotte dorée, piano à flammes). On y dîne au-delà du seuil du lieu : un cordon
## de velours, posé par minuit.gd, ferme ses deux portes (galerie à l'ouest, boutiques au sud) jusque-là.
## La zone est bâtie à plat puis posée à y = 6 ; les places des figurants sont rendues à leur vraie hauteur.

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const LOT_C := "res://communes/casino_minuit/zones/lot_c.gd"
const Y := 6.0
const H := 5.0
const B := {"x0": 18.0, "x1": 40.0, "z0": -30.0, "z1": -12.0}
const OUV := {"west": [{"at": -19.0, "w": 4.0, "h": 3.2}], "south": [{"at": 20.0, "w": 3.0, "h": 3.2}]}
const ZC := -21.0


static func construire(K) -> void:
	var LB = load(LOT_B)
	var L = load(LOT_C)
	K.zone_debut("M-RESTAURANT")
	K.zone.position.y = Y

	# --- enveloppe : moquette, damier de la cuisine, laque, capitons ---
	K.plan("moquette_d", B.x0, 35.3, B.z0, B.z1, 0)
	K.plan("damier", 35.3, B.x1, B.z0, B.z1, 0)
	K.dalle(B.x0, B.x1, B.z0, B.z1)
	L.plafond(K, "plafond_bas", B.x0, B.x1, B.z0, B.z1, H)
	LB.coque(K, B, H, "bois_laque", OUV)
	L.registres(K, 18.2, -29.8, 35.0, -29.8, {"h": H, "n": [0.0, 1.0], "base": "capiton_rouge", "bh": 1.55, "pil": [0.6, 16.3], "pil_mat": "laque_noire"})
	L.registres(K, 18.2, -29.8, 18.2, -12.2, {"h": H, "n": [1.0, 0.0], "base": "capiton_rouge", "bh": 1.0, "skip": [[8.8, 12.8]], "pil": [8.4, 13.2], "pil_mat": "laque_noire"})
	L.registres(K, 18.2, -12.2, 35.0, -12.2, {"h": H, "n": [0.0, -1.0], "base": "capiton_rouge", "bh": 1.0, "skip": [[0.3, 3.3]], "pil": [3.75, 7.0, 10.25, 13.5, 16.6], "pil_mat": "laque_noire"})
	L.registres(K, 35.0, -29.8, 39.8, -29.8, {"h": H, "n": [0.0, 1.0], "bh": 0.0})
	L.registres(K, 35.0, -12.2, 39.8, -12.2, {"h": H, "n": [0.0, -1.0], "bh": 0.0})
	L.registres(K, 39.8, -29.8, 39.8, -12.2, {"h": H, "n": [-1.0, 0.0], "bh": 0.0})
	L.baie(K, {"axe": "z", "at": -12.0, "c": 20.0, "w": 3.0, "h": 3.2})
	LB.enseigne(K, "Le Lucullus", 20, 3.75, -11.76, 0, 2.0, 0.4, "plaque")
	# Les miroirs fumés entre les pilastres du mur sud.
	for x in [23.6, 26.85, 30.1, 33.3]:
		K.box("miroir", 2.5, 2.3, 0.03, x, 2.5, -12.24)
		for y in [3.68, 1.32]:
			K.box("or", 2.62, 0.05, 0.06, x, y, -12.26)
		for s in [-1.0, 1.0]:
			K.box("or", 0.05, 2.36, 0.06, x + s * 1.28, 2.5, -12.26)
	# La cave à vin rétroéclairée, au mur ouest.
	K.box("laque_noire", 0.3, 2.9, 3.9, 18.35, 1.75, -14.65)
	K.box("gorge_douce", 0.02, 2.5, 3.5, 18.51, 1.75, -14.65)
	K.box("or", 0.34, 0.05, 4.0, 18.35, 3.22, -14.65)
	for r in 6:
		K.box("laque_noire", 0.2, 0.03, 3.5, 18.56, 0.62 + r * 0.42, -14.65)
		for k in 12:
			K.box(["laque_rouge", "vert_jardin", "or", "neon_ambre"][(k + r * 3) % 4], 0.08, 0.3, 0.08, 18.6, 0.8 + r * 0.42, -16.25 + k * 0.29)
	K.obstacle(18.2, 18.72, -16.65, -12.65, 0.0, 3.2)

	# --- les tables dressées : huit de quatre couverts, en quinconce ---
	var dineurs := []
	var service := []
	for p in [[22.6, -24.5], [27.0, -24.5], [31.4, -24.5], [24.9, -20.4], [29.5, -20.4], [23.2, -16.3], [27.6, -16.3], [32.0, -16.3]]:
		var t: Dictionary = _table(K, L, p[0], p[1], PI / 4.0, 4)
		dineurs.append_array(t.sieges)
		service.append(t.service)
	# La banquette capitonnée du mur nord : quatre tables de deux (banquette et chaise).
	K.box("capiton_rouge", 12.4, 0.12, 0.62, 25.5, 0.42, -29.45)
	K.box("laque_noire", 12.4, 0.36, 0.6, 25.5, 0.18, -29.46)
	K.box("or", 12.4, 0.03, 0.03, 25.5, 0.35, -29.15)
	K.box("capiton_rouge", 12.4, 0.8, 0.12, 25.5, 0.9, -29.74)
	K.obstacle(19.3, 31.7, -29.8, -29.13, 0.0, 1.0)
	for x in [21.0, 24.0, 27.0, 30.0]:
		_nappe(K, x, -28.45, 0.4)
		_couvert(K, x, -28.65, PI)
		_couvert(K, x, -28.25, 0.0)
		dineurs.append([Vector3(x, 0.48 + Y, -29.35), PI])
		dineurs.append(_monte(L.chaise(K, x, -27.62, 0.0)))
		service.append([Vector3(x - 1.0, Y, -27.9), -PI / 2.0])
	K.places["resto_dineurs"] = dineurs
	K.places["resto_service"] = service

	# --- le pupitre d'accueil du maître d'hôtel ---
	K.box("laque_noire", 0.5, 1.12, 0.7, 20.6, 0.56, -22.4)
	K.box("or", 0.58, 0.04, 0.78, 20.6, 1.14, -22.4)
	K.box("or", 0.54, 0.05, 0.74, 20.6, 0.03, -22.4)
	K.cyl("or", 0.012, 0.012, 0.3, 20.75, 1.3, -22.65, 5)
	K.box("ampoule", 0.05, 0.05, 0.22, 20.7, 1.45, -22.65)
	K.texte("LE LUCULLUS", 0.62, 0.11, 20.34, 0.72, -22.4, -PI / 2.0, "neon")
	K.obstacle(20.33, 20.87, -22.77, -22.03, 0.0, 1.2)
	LB.enseigne(K, "Veuillez patienter, un hôte vous placera", 18.26, 1.75, -23.6, PI / 2.0, 1.5, 0.23, "plaque")
	K.places["resto_maitre"] = [Vector3(21.45, Y, -22.4), -PI / 2.0 + PI]

	# --- la cuisine ouverte (pièce maîtresse) : passe-plats, hotte dorée, piano à flammes ---
	K.box("laque_noire", 0.5, 1.04, 8.2, 35.05, 0.52, ZC)
	K.box("marbre_noir", 0.72, 0.07, 8.4, 35.03, 1.075, ZC)
	for i in 5:
		K.box("onyx", 0.02, 0.72, 1.5, 34.795, 0.56, ZC - 3.28 + i * 1.64)
	K.box("gorge", 0.03, 0.04, 8.2, 34.79, 0.14, ZC)
	K.box("or", 0.04, 0.035, 8.2, 34.785, 0.97, ZC)
	K.obstacle(34.78, 35.32, ZC - 4.12, ZC + 4.12, 0.0, 1.2)
	for i in 6:
		var z := ZC - 3.4 + i * 1.36
		K.cyl("porcelaine", 0.15, 0.11, 0.02, 35, 1.12, z, 10)
		if i % 2:
			K.sph("or", 0.11, 35, 1.2, z, 0.8)
		K.cyl("or", 0.008, 0.008, 1.1, 35.05, 2.4, z + 0.3, 4)
		K.cyl("or", 0.05, 0.14, 0.14, 35.05, 1.82, z + 0.3, 8)
		K.cyl("ampoule", 0.1, 0.1, 0.01, 35.05, 1.745, z + 0.3, 8)
	K.box("or_brosse", 2.0, 0.9, 8.8, 36.0, 3.4, ZC)
	for y in [2.95, 3.86]:
		K.box("or", 2.08, 0.07, 8.88, 36.0, y, ZC)
	K.box("gorge", 1.7, 0.02, 8.4, 36.0, 2.905, ZC)
	K.box("or_brosse", 1.2, H - 3.9, 3.0, 36.3, (H + 3.9) / 2.0, ZC)
	K.texte("LE LUCULLUS", 4.6, 0.6, 34.98, 3.4, ZC, -PI / 2.0, "grave", K.pal.laque_noire)
	K.box("acier", 0.9, 0.9, 7.4, 37.6, 0.45, ZC)
	K.box("laque_noire", 0.92, 0.04, 7.42, 37.6, 0.92, ZC)
	K.obstacle(37.13, 38.07, ZC - 3.72, ZC + 3.72, 0.0, 1.0)
	var flammes := []
	for i in 6:
		var z := ZC - 3.1 + i * 1.24
		K.cyl("laque_noire", 0.17, 0.17, 0.03, 37.5, 0.955, z, 10)
		flammes.append(Vector3(37.5, 0.97, z))
		if i % 3 != 1:
			K.cyl("acier" if i % 2 else "or", 0.16, 0.14, 0.2, 37.5, 1.1, z, 10)
			K.box("laque_noire", 0.3, 0.02, 0.03, 37.25, 1.16, z)
	K.box("marbre_creme", 0.06, 2.0, 9.0, 39.74, 1.9, ZC)
	for y in [1.7, 2.3]:
		K.box("acier", 0.34, 0.03, 7.6, 39.55, y, ZC)
		for k in 9:
			K.cyl(["or", "acier", "laque_rouge"][k % 3], 0.1, 0.09, 0.16 + (k % 2) * 0.06, 39.55, y + 0.1, ZC - 3.4 + k * 0.85, 8)
	K.box("acier", 0.7, 0.9, 2.2, 39.4, 0.45, -27.6)
	K.box("acier", 0.7, 1.9, 1.6, 39.4, 0.95, -14.2)
	K.obstacle(39.05, 39.8, -28.7, -26.5, 0.0, 1.0)
	K.obstacle(39.05, 39.8, -15, -13.4, 0.0, 2.0)
	_flammes(K, flammes)
	K.lumiere(36.3, 2.7, ZC, Color("#FFE2B4"), 1.9, 13.0)
	K.places["resto_brigade"] = [[Vector3(35.85, Y, ZC), PI / 2.0], [Vector3(36.72, Y, ZC - 2.4), -PI / 2.0], [Vector3(36.72, Y, ZC + 2.4), -PI / 2.0]]
	K.places["resto_passe"] = [[Vector3(34.25, Y, -23.4), -PI / 2.0], [Vector3(34.25, Y, ZC), -PI / 2.0], [Vector3(34.25, Y, -18.6), -PI / 2.0]]

	# --- lumière et décor ---
	K.lustre_anneau(24.9, 3.4, -22.5, 1.2, 1.1)
	K.lustre_anneau(30.6, 3.4, -22.5, 1.2, 1.1)
	K.lustre_anneau(27.6, 3.5, -16.3, 1.0, 1.0)
	K.lumiere(27.6, 3.0, -22.5, Color("#FFC878"), 1.6, 13.0)
	K.lumiere(27.6, 3.0, -16.3, Color("#FFC878"), 1.2, 10.0)
	K.lumiere(22.0, 2.8, -27.8, Color("#FFC878"), 1.0, 8.0)
	LB.palmier(K, 18.85, -29.2, {"seed": 5})
	LB.topiaire(K, 18.85, -21.75, 1.9)
	LB.topiaire(K, 18.85, -16.9, 1.9)
	LB.palmier(K, 34.3, -12.9, {"seed": 17})
	LB.palmier(K, 34.3, -29.1, {"seed": 26})
	K.zone_fin()


## Une place rendue à sa vraie hauteur (la zone est posée à y = 6).
static func _monte(p: Array) -> Array:
	return [p[0] + Vector3(0, Y, 0), p[1]]


static func _nappe(K, x: float, z: float, R: float) -> void:
	K.cyl("nappe", R, R, 0.04, x, 0.76, z, 16)
	K.cyl("nappe", R, R + 0.07, 0.5, x, 0.5, z, 16)
	K.cyl("laque_noire", 0.05, 0.2, 0.26, x, 0.13, z, 8)
	K.cyl("or", 0.03, 0.045, 0.1, x, 0.83, z, 6)
	K.cyl("ampoule", 0.016, 0.016, 0.12, x, 0.93, z, 5)
	K.rond(x, z, R + 0.04, 0.0, 0.9)


## Une assiette et un verre devant un convive tourné vers a.
static func _couvert(K, x: float, z: float, a: float) -> void:
	K.cyl("porcelaine", 0.13, 0.1, 0.015, x, 0.787, z, 12)
	K.cyl("verre", 0.03, 0.02, 0.14, x + cos(a) * 0.16, 0.85, z - sin(a) * 0.16, 6)


## Une table ronde de n couverts tournée de rot : nappe, bougeoir, chaises, couverts, son point de service.
static func _table(K, L, x: float, z: float, rot: float, n: int) -> Dictionary:
	var R := 0.6
	var sr := R + 0.42
	_nappe(K, x, z, R)
	var sieges := []
	for i in n:
		var a := rot + i * TAU / n
		var cx := x + sin(a) * sr
		var cz := z + cos(a) * sr
		sieges.append(_monte(L.chaise(K, cx, cz, a, {"cadre": "laque_noire", "coussin": "velours"})))
		_couvert(K, x + sin(a) * (R - 0.2), z + cos(a) * (R - 0.2), a)
	K.cyl("vert_jardin", 0.035, 0.04, 0.3, x + 0.16, 0.93, z - 0.12, 6)
	var sa := rot + 0.5 / n * TAU
	return {"sieges": sieges, "service": [Vector3(x + sin(sa) * (sr + 0.5), Y, z + cos(sa) * (sr + 0.5)), sa]}


## Les flammes du piano : des lames de feu croisées qui dansent.
static func _flammes(K, pts: Array) -> void:
	var noeuds := []
	for i in pts.size():
		var f := Node3D.new()
		f.position = pts[i]
		K.zone.add_child(f)
		for r in [0.0, PI / 2.0]:
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.22, 0.36)
			q.center_offset = Vector3(0, 0.18, 0)
			mi.mesh = q
			mi.rotation.y = r
			mi.material_override = K.mat("flamme")
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			f.add_child(mi)
		noeuds.append(f)
	K.chaque_image(func(_dt, t):
		for i in noeuds.size():
			var s := 0.75 + 0.35 * sin(t * 9.0 + i * 2.1) * sin(t * 5.3 + i)
			noeuds[i].scale = Vector3(0.9 + 0.2 * sin(t * 7.0 + i), s * (1.5 if i % 3 == 1 else 0.6), 0.9))
