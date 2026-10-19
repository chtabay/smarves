extends RefCounted
## Lot E « dehors », zone X-ENFACE (js/zones/e-enface.js) : le trottoir d'en face (bancs, poubelles, bouches
## d'incendie, vendeur de hot-dogs), les façades d'hôtels et de commerces à néons et écrans géants sur z = 89,6,
## le fronton de l'arène (porte de 6 m centrée en x = 0 : marquise « FIGHT NIGHT », écran géant, affiches du
## combat, projecteurs de ciel), les voisins du casino côté nord, l'avenue qui se prolonge jusqu'au brouillard et
## les tours lointaines. La porte de l'arène reste libre ici : la scène la ferme tant que le lieu n'est pas ouvert.

const LOT_E := "res://communes/casino_minuit/zones/lot_e.gd"
const FZ := 89.6
const AZ := 89.6
const AH := 21.0
const MUR := Color("#2C2620")


static func construire(K) -> void:
	var E = load(LOT_E)
	var L: Dictionary = E.LAY
	K.zone_debut("X-ENFACE")
	_arene(K, E)
	_facades(K, E, L)
	_voisins(K, E, L)
	_lointain(K, E, L)
	_trottoir(K, E, L)
	K.zone_fin()


## Un immeuble côté sud (sa face nord sur la rue) : un rez-de-chaussée de devantures sous un auvent, les étages.
static func _bloc_sud(K, E, x0: float, x1: float, zf: float, prof: float, h: float, style: int, teinte := MUR) -> void:
	E.face(K, x1, zf, x0, zf, 0, 6, E.DEVANTURES, teinte)
	E.bloc(K, x0, x1, zf, zf + prof, 6, h, style, "neo", teinte)
	E.face(K, x0, zf, x0, zf + prof, 0, 6, E.BETON, teinte)
	E.face(K, x1, zf + prof, x1, zf, 0, 6, E.BETON, teinte)
	K.box("laque_noire", x1 - x0, 0.5, 1.2, (x0 + x1) / 2.0, 6.25, zf - 0.6)
	K.box("or", x1 - x0, 0.06, 0.06, (x0 + x1) / 2.0, 6.02, zf - 1.18)


## Un immeuble côté nord (sa face sud sur la rue, à côté du casino).
static func _bloc_nord(K, E, x0: float, x1: float, zf: float, prof: float, h: float, style: int, teinte := MUR) -> void:
	E.face(K, x0, zf, x1, zf, 0, 6, E.DEVANTURES, teinte)
	E.bloc(K, x0, x1, zf - prof, zf, 6, h, style, "seo", teinte)
	K.box("laque_noire", x1 - x0, 0.5, 1.2, (x0 + x1) / 2.0, 6.25, zf + 0.6)


# --- Le fronton de l'arène (x ∈ [-30, 30]) : la porte x ∈ [-3, 3], haute de 4,6, reste libre ------------------

static func _arene(K, E) -> void:
	for p in [[-30.0, -3.0, 0.0], [3.0, 30.0, 0.0], [-3.0, 3.0, 4.6]]:
		K.box("beton_e", p[1] - p[0], AH - p[2], 0.4, (p[0] + p[1]) / 2.0, (p[2] + AH) / 2.0, AZ + 0.2)
	K.obstacle(-30, -3, AZ, AZ + 0.4, 0.0, 8.0)
	K.obstacle(3, 30, AZ, AZ + 0.4, 0.0, 8.0)
	# Les ailerons rouges lumineux.
	var x := -28.0
	while x <= 28.1:
		if absf(x) >= 16.0:
			K.box("rouge_sombre", 0.5, AH - 2, 0.6, x, (AH - 2) / 2.0 + 1, AZ - 0.3)
			K.box("rouge_lum", 0.08, AH - 2.4, 0.08, x, (AH - 2) / 2.0 + 1, AZ - 0.62)
		x += 4.0
	# L'encadrement de porte, chrome et or ; les affiches rétroéclairées du combat.
	K.box("chrome", 6.6, 0.3, 0.6, 0, 4.75, AZ - 0.1)
	for s in [-1.0, 1.0]:
		K.box("chrome", 0.3, 4.6, 0.6, s * 3.15, 2.3, AZ - 0.1)
		var px: float = s * 10.5
		K.box("laque_noire", 9.4, 5.2, 0.3, px, 3.2, AZ - 0.15)
		E.ecran(K, px, 3.2, AZ - 0.31, 9, 4.8, PI, E.LED_ROUGE, 1.0 + s)
		E.cadre_ampoules(K, px, 3.2, AZ - 0.33, 9.1, 4.9, PI, 0.2)
	K.box("or", 6.2, 0.02, 0.4, 0, 0.012, AZ - 0.2)
	# La marquise « FIGHT NIGHT » en porte-à-faux sur le trottoir.
	var mz0 := AZ - 6.2
	var my0 := 5.2
	var my1 := 6.6
	var mym := (my0 + my1) / 2.0
	K.box("laque_noire", 24, my1 - my0, AZ - mz0, 0, mym, (AZ + mz0) / 2.0)
	K.box("rouge_e", 24.3, 1.5, 0.3, 0, mym, mz0 - 0.1)
	for s in [-1.0, 1.0]:
		K.box("rouge_e", 0.3, 1.5, AZ - mz0, s * 12.1, mym, (AZ + mz0) / 2.0)
		E.enseigne(K, "CE SOIR 22 H", "#FFE2B4", 5, 0.9, s * 12.27, mym, (AZ + mz0) / 2.0, s * PI / 2.0, "bloc")
		K.cyl("chrome", 0.05, 0.05, 2.6, s * 11.5, my1 + 1.3, mz0 + 0.4, 6)
		K.beam("chrome", Vector3(s * 11.5, my1 + 2.6, mz0 + 0.4), Vector3(s * 11.5, my1 + 2.6, AZ - 0.3), 0.05, 0.05)
	E.enseigne(K, "FIGHT NIGHT", "#FF2A3A", 15, 1.3, 0, mym, mz0 - 0.27, PI)
	E.ampoules(K, Vector3(-12, my1 + 0.25, mz0 - 0.28), Vector3(12, my1 + 0.25, mz0 - 0.28), 0.28, PI)
	E.ampoules(K, Vector3(-12, my0 - 0.25, mz0 - 0.28), Vector3(12, my0 - 0.25, mz0 - 0.28), 0.28, PI)
	var lx := -10.5
	while lx <= 10.6:
		var z := mz0 + 1.0
		while z < AZ - 0.5:
			K.cyl("lumiere", 0.2, 0.2, 0.04, lx, my0 - 0.03, z, 8)
			z += 2.4
		lx += 3.0
	K.lumiere(0, 4.6, AZ - 3.2, Color("#FFD8C0"), 1.6, 12.0)
	K.lumiere(0, 11, AZ - 7, Color("#FF4050"), 1.1, 18.0)
	# L'écran géant et la couronne « ARÈNE », les enseignes verticales « BOXE ».
	K.box("laque_noire", 27, 11, 0.6, 0, 12.6, AZ - 0.25)
	E.ecran(K, 0, 12.6, AZ - 0.57, 26, 10, PI, E.LED_ROUGE, 0.0)
	E.cadre_ampoules(K, 0, 12.6, AZ - 0.6, 26.6, 10.6, PI, 0.3)
	K.box("laque_noire", 30, 2.6, 0.5, 0, AH - 1.0, AZ - 0.15)
	E.enseigne(K, "ARÈNE", "#FF3348", 13, 2.4, 0, AH - 1.0, AZ - 0.42, PI)
	K.box("or", 60.4, 0.3, 0.7, 0, AH + 0.15, AZ - 0.05)
	for s in [-1.0, 1.0]:
		K.box("laque_noire", 1.8, 12, 1.0, s * 22, 11, AZ - 1.0)
		E.enseigne(K, "BOXE", "#FFC24A", 1.5, 9.5, s * 22, 11, AZ - 1.52, PI, "neon", true)
		# La file d'attente, entre les cordons de part et d'autre de l'accès.
		E.cordons(K, s * 4.6, [AZ - 4.6, AZ - 3.2, AZ - 1.8, AZ - 0.6])
	var file := []
	for i in 6:
		file.append([Vector3(-6.2, 0, AZ - 1.2 - i * 0.9), PI])
	K.places["e_file_arene"] = file
	var ecran := []
	for i in 8:
		ecran.append([Vector3(-9 + i * 2.6, 0, 80.2 + (i % 2) * 0.8), PI])
	K.places["e_ecran_arene"] = ecran
	K.places["e_videur_arene"] = [[Vector3(3.9, 0, AZ - 0.9), 0.0]]
	K.places["e_bavards_enface"] = [[Vector3(8.6, 0, 85.6), -PI / 2.0], [Vector3(9.6, 0, 85.6), PI / 2.0], [Vector3(-14.5, 0, 83.2), -PI / 2.0], [Vector3(-13.5, 0, 83.2), PI / 2.0]]
	# Les projecteurs de ciel : deux sur l'arène, deux sur le Palais Lune, qui balaient la nuit.
	var faisceaux := []
	for b in [[-16.0, AZ + 0.2, AH + 1.4, 0.0], [16.0, AZ + 0.2, AH + 1.4, 2.1], [70.0, FZ + 6, 15.4, 1.0], [104.0, FZ + 6, 15.4, 3.0]]:
		K.cyl("acier_sombre", 0.8, 1.0, 1.2, b[0], b[2] - 0.6, b[1], 10)
		var mi: MeshInstance3D = E.faisceau(K, Color("#8FA8C8"), 0.55, 170.0, 4.5, 0.35)
		var pivot := mi.get_parent() as Node3D
		pivot.position = Vector3(b[0], b[2], b[1])
		mi.extra_cull_margin = 200.0
		faisceaux.append([pivot, b[3]])
	K.chaque_image(func(_dt: float, t: float) -> void:
		for f in faisceaux:
			var p: float = f[1]
			(f[0] as Node3D).basis = Basis.from_euler(Vector3(0.42 + 0.12 * sin(t * 0.21 + p), t * 0.25 + p, 0), EULER_ORDER_YXZ) * Basis(Vector3.RIGHT, PI))


# --- Les façades d'en face (z = 89,6) hors de l'arène -----------------------------------------------------

static func _facades(K, E, L: Dictionary) -> void:
	# Le Saphir (x ∈ [-118, -84]) : un hôtel de verre bleu, sa tour au loin.
	_bloc_sud(K, E, -118, -84, FZ, 18, 16, E.VERRE, Color("#1A2234"))
	E.bloc(K, -116, -88, FZ + 14, FZ + 36, 16, 92, E.VERRE, "neo", Color("#1A2234"))
	K.box("laque_noire", 29, 5, 23, -102, 94.5, FZ + 25)
	E.enseigne(K, "LE SAPHIR", "#4D9BFF", 24, 3.6, -102, 94.5, FZ + 13.4, PI)
	K.box("laque_noire", 1.4, 11, 2.2, -86.5, 12.5, FZ - 1.1)
	E.enseigne(K, "SAPHIR", "#3DE0E0", 1.3, 9, -86.5, 12.5, FZ - 2.22, PI, "neon", true)
	E.enseigne(K, "CASINO · HÔTEL", "#CFE4FF", 10, 0.9, -101, 6.45, FZ - 1.22, PI, "bloc")
	E.enseigne(K, "BOUTIQUES", "#FFE2B4", 6, 0.7, -110, 6.45, FZ - 1.22, PI, "bloc")
	E.ecran(K, -101, 11.2, FZ - 0.02, 14, 7, PI, E.LED_BLEU, 1.3)
	# La chapelle des amoureux (x ∈ [-84, -62]).
	E.face(K, -62, FZ, -84, FZ, 0, 6, E.CHAPELLE, Color("#E9DFCB"))
	E.face(K, -62, FZ + 10, -62, FZ, 0, 6, E.CHAPELLE, Color("#E9DFCB"))
	E.face(K, -84, FZ, -84, FZ + 10, 0, 6, E.CHAPELLE, Color("#E9DFCB"))
	K.box("creme", 22.4, 0.6, 10.4, -73, 6.3, FZ + 5)
	E.prisme(K, "creme", [[-75, FZ + 1], [-71, FZ + 1], [-71, FZ + 5], [-75, FZ + 5]], 6.6, 13)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.9
	cone.height = 5.0
	cone.radial_segments = 4
	cone.rings = 1
	K.put("rouge_sombre", cone, K.xf(-73, 15.5, FZ + 3, 0, PI / 4.0, 0))
	K.cyl("or", 0.05, 0.05, 1.6, -73, 18.8, FZ + 3, 4)
	K.box("or", 0.7, 0.08, 0.08, -73, 19.1, FZ + 3)
	E.enseigne(K, "CHAPELLE DES AMOUREUX", "#FF4D8D", 14, 1.2, -73, 7.6, FZ - 0.02, PI)
	E.enseigne(K, "♥", "#FF4D8D", 2.6, 2.6, -73, 10.5, FZ + 0.98, PI)
	E.enseigne(K, "MARIAGES 24 H / 24", "#FFFFFF", 6, 0.7, -73, 5.2, FZ - 0.05, PI, "bloc")
	E.ecran(K, -79.5, 3.4, FZ - 0.05, 3.6, 1.8, PI, E.LED_ROSE, 0.5)
	# Les commerces et l'écran géant (x ∈ [-62, -30]).
	_bloc_sud(K, E, -62, -30, FZ, 14, 11, E.BALCONS)
	E.enseigne(K, "SOUVENIRS", "#FFC24A", 7, 1.0, -55.5, 6.45, FZ - 1.22, PI)
	E.enseigne(K, "PHARMACIE", "#4DFF9A", 6, 0.9, -45.5, 6.45, FZ - 1.22, PI, "bloc")
	E.enseigne(K, "STEAKHOUSE", "#FF3348", 7.5, 1.0, -35.5, 6.45, FZ - 1.22, PI)
	K.box("acier_sombre", 0.4, 10, 0.4, -54, 16, FZ + 2)
	K.box("acier_sombre", 0.4, 10, 0.4, -38, 16, FZ + 2)
	K.box("laque_noire", 18.6, 9.4, 0.6, -46, 17, FZ + 1.9)
	E.ecran(K, -46, 17, FZ + 1.58, 18, 9, PI, E.LED_REVUE, 0.6)
	# Le diner et le bar à huîtres (x ∈ [30, 56]).
	_bloc_sud(K, E, 30, 56, FZ, 12, 9, E.BALCONS, Color("#3A2A24"))
	K.box("laque_noire", 9, 2.0, 0.4, 37, 10.6, FZ - 0.2)
	E.enseigne(K, "DINER 1957", "#3DE0E0", 8.6, 1.8, 37, 10.6, FZ - 0.42, PI)
	E.enseigne(K, "BAR À HUÎTRES", "#FF8A3A", 9, 1.0, 49, 6.45, FZ - 1.22, PI)
	E.enseigne(K, "OUVERT", "#FF3348", 2.4, 0.6, 33, 3.2, FZ - 0.05, PI, "bloc")
	# Le Palais Lune (x ∈ [56, 118]) : socle doré, écran géant, tour d'or, croissant de lune.
	_bloc_sud(K, E, 56, 118, FZ, 22, 14, E.DORE, Color("#3A2A14"))
	E.bloc(K, 62, 112, FZ + 18, FZ + 40, 14, 108, E.DORE, "neo", Color("#3A2A14"))
	K.box("or", 51, 1.2, 23, 87, 108.6, FZ + 29)
	K.tore("lumiere", 6.0, 0.7, K.xf(87, 118, FZ + 18, PI / 2.0, 0, -PI * 0.6), 24)
	E.enseigne(K, "PALAIS LUNE", "#F2CF7A", 34, 4.4, 87, 102, FZ + 17.9, PI)
	K.box("laque_noire", 27, 14, 0.6, 77, 27.5, FZ + 17.6)
	E.ecran(K, 77, 27.5, FZ + 17.28, 26, 13, PI, E.LED_MINUIT, 2.1)
	E.cadre_ampoules(K, 77, 27.5, FZ + 17.25, 26.5, 13.5, PI, 0.3)
	K.box("laque_noire", 1.6, 10, 1.4, 58.2, 13, FZ - 0.7)
	E.enseigne(K, "LUNE", "#F2CF7A", 1.4, 8, 58.2, 13, FZ - 1.42, PI, "neon", true)
	E.enseigne(K, "CASINO · SPECTACLES", "#F2CF7A", 14, 1.0, 92, 6.45, FZ - 1.22, PI, "bloc")
	# Les barrières de chantier au bout des trottoirs.
	for s in [-1.0, 1.0]:
		for p in [[L.WALK0, L.CURB0], [L.CURB1, FZ], [L.FACADE, L.WALK0]]:
			var x: float = s * (L.XEND + 0.3)
			var z: float = p[0] + 0.6
			while z < p[1] - 0.3:
				K.box("blanc", 0.15, 0.25, 2.0, x, 0.85, z + 1.0)
				K.box("rouge_e", 0.16, 0.12, 2.0, x, 0.85, z + 1.0)
				for d in [0.1, 1.9]:
					K.box("acier_sombre", 0.08, 0.9, 0.08, x, 0.45, z + d)
				K.sph("ambre_lum", 0.07, x, 1.05, z + 1)
				z += 2.2


# --- Les voisins du casino, côté nord (z ≤ 30, |x| ≥ 60) ----------------------------------------------------

static func _voisins(K, E, L: Dictionary) -> void:
	var f: float = L.FACADE
	# L'Étoile d'Orient, à l'ouest.
	_bloc_nord(K, E, -118, -62, f, 30, 18, E.BALCONS, Color("#2E2A22"))
	E.bloc(K, -112, -72, f - 52, f - 22, 18, 84, E.HOTEL, "seo")
	E.enseigne(K, "ÉTOILE D'ORIENT", "#3DE0E0", 30, 3.8, -92, 78, f - 21.9, 0)
	var oct := SphereMesh.new()
	oct.radius = 3.2
	oct.height = 6.4
	oct.radial_segments = 4
	oct.rings = 2
	K.put("lumiere", oct, K.xf(-92, 92, f - 37, 0, 0.4, 0))
	E.enseigne(K, "HÔTEL · CASINO", "#CFE4FF", 10, 0.9, -90, 6.45, f + 1.22, 0, "bloc")
	E.enseigne(K, "BAZAR", "#FFC24A", 5, 0.8, -70, 6.45, f + 1.22, 0)
	K.box("laque_noire", 22, 3, 0.4, -90, 11, f + 0.25)
	E.enseigne(K, "ÉTOILE D'ORIENT", "#3DE0E0", 20, 2.4, -90, 11, f + 0.47, 0)
	# À l'est, le Bayou Club, la galerie des artistes, le parking.
	_bloc_nord(K, E, 62, 118, f, 30, 8, E.PARKING, Color("#3A3A40"))
	E.bloc(K, 62, 118, f - 30, f, 8, 20, E.PARKING, "seo", Color("#3A3A40"))
	E.bloc(K, 72, 112, f - 56, f - 30, 20, 76, E.VERRE, "seo", Color("#1A2234"))
	E.enseigne(K, "BAYOU CLUB", "#B25CFF", 12, 1.6, 76, 10.2, f + 0.1, 0)
	E.enseigne(K, "JAZZ · BLUES · 23 H", "#FFE2B4", 7, 0.7, 76, 6.45, f + 1.22, 0, "bloc")
	E.enseigne(K, "GALERIE DES ARTISTES", "#FFC24A", 12, 0.9, 102, 6.45, f + 1.22, 0, "bloc")
	E.enseigne(K, "PARKING", "#4D7BFF", 6, 1.0, 112, 15, f + 0.05, 0, "bloc")
	E.ecran(K, 92, 14, f + 0.06, 12, 6, 0, E.LED_CYAN, 3.3)
	K.obstacle(-L.XEND, -L.CASINO, f, f + 1.3, 0.0, 8.0)
	K.obstacle(L.CASINO, L.XEND, f, f + 1.3, 0.0, 8.0)


# --- L'avenue qui continue (|x| > 120) et les tours lointaines ---------------------------------------------

static func _lointain(K, E, L: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var styles := [E.HOTEL, E.VERRE, E.DORE, E.BALCONS, E.BETON]
	var mots_sud := ["MOTEL", "BAR", "CASINO", "BIJOUX", "PIZZA", "SALOON", "DISCOUNT", "TATOUAGES"]
	var mots_nord := ["HÔTEL", "CASINO", "BUFFET", "CHAPELLE", "SOUVENIRS"]
	var couleurs := ["#FF4D8D", "#3DE0E0", "#FFC24A", "#4DFF9A", "#FF3348", "#B25CFF"]
	for s in [-1.0, 1.0]:
		var x := 122.0
		while x < 320.0:
			var w := 18.0 + r.randf() * 26.0
			var h1 := 10.0 + r.randf() * 30.0
			var x0: float = x if s > 0 else -x - w
			var x1: float = x + w if s > 0 else -x
			E.bloc(K, x0, x1, L.CURB1 + 10, L.CURB1 + 30, 0, h1, styles[r.randi() % styles.size()], "neo")
			if r.randf() < 0.6:
				E.enseigne(K, mots_sud[r.randi() % mots_sud.size()], couleurs[r.randi() % 5], 8, 1.4, (x0 + x1) / 2.0, minf(h1 - 1.5, 8.0), L.CURB1 + 9.9, PI)
			var w2 := 18.0 + r.randf() * 26.0
			var h2 := 10.0 + r.randf() * 26.0
			var y0: float = x if s > 0 else -x - w2
			var y1: float = x + w2 if s > 0 else -x
			E.bloc(K, y0, y1, L.CURB0 - 30, L.CURB0 - 8, 0, h2, styles[r.randi() % styles.size()], "seo")
			if r.randf() < 0.5:
				E.enseigne(K, mots_nord[r.randi() % mots_nord.size()], couleurs[r.randi() % 4], 8, 1.4, (y0 + y1) / 2.0, minf(h2 - 1.5, 8.0), L.CURB0 - 7.9, 0)
			x += maxf(w, w2) + 4.0 + r.randf() * 6.0
	var neons := ["rouge_lum", "cyan_lum", "ambre_lum", "rose_lum"]
	for i in 14:
		var x := -260.0 + i * 40.0 + r.randf() * 20.0
		var z := 170.0 + r.randf() * 90.0
		var w := 22.0 + r.randf() * 26.0
		var d := 18.0 + r.randf() * 16.0
		var h := 50.0 + r.randf() * 110.0
		E.bloc(K, x - w / 2.0, x + w / 2.0, z, z + d, 0, h, styles[r.randi() % 4], "neo")
		if r.randf() < 0.5:
			K.box(neons[i % 4], w + 0.4, 0.5, 0.2, x, h - 1, z - 0.15)
	for i in 8:
		var x := -230.0 + i * 62.0 + r.randf() * 20.0
		var z := -60.0 - r.randf() * 80.0
		var w := 24.0 + r.randf() * 20.0
		var h := 60.0 + r.randf() * 90.0
		if absf(x) < 70.0:
			continue
		E.bloc(K, x - w / 2.0, x + w / 2.0, z - 20.0, z, 0, h, styles[r.randi() % 4], "seo")


# --- Le trottoir d'en face : bancs, poubelles, bouches d'incendie, kiosques, vendeur de hot-dogs ---------------

static func _trottoir(K, E, L: Dictionary) -> void:
	var bancs := []
	for x in [-100.0, -66.0, 22.0, 48.0, 88.0]:
		bancs.append_array(E.banc(K, x, FZ - 1.6, 0.0, "bois_laque", "acier_sombre"))
	K.places["e_bancs_enface"] = bancs
	for x in [-92.0, -52.0, -20.0, 18.0, 58.0, 100.0]:
		K.cyl("acier_sombre", 0.32, 0.3, 0.95, x, 0.475, L.CURB1 + 1.0, 10)
		K.cyl("or", 0.34, 0.34, 0.05, x, 0.95, L.CURB1 + 1.0, 10)
		K.rond(x, L.CURB1 + 1.0, 0.36)
	for x in [-74.0, -16.0, 30.0, 76.0]:
		K.cyl("rouge_e", 0.13, 0.15, 0.6, x, 0.3, L.CURB1 + 0.7, 8)
		K.sph("rouge_e", 0.15, x, 0.62, L.CURB1 + 0.7)
		K.box("rouge_e", 0.42, 0.1, 0.1, x, 0.42, L.CURB1 + 0.7)
		K.rond(x, L.CURB1 + 0.7, 0.2)
	for x in [-26.0, 70.0]:
		K.box("marine", 0.5, 1.1, 0.45, x, 0.55, L.CURB0 - 2.4)
		K.rond(x, L.CURB0 - 2.4, 0.35)
	# Le chariot à hot-dogs : caisse inox, parasol rayé, ampoules.
	var x := 24.0
	var z := 84.6
	K.box("acier", 1.9, 0.9, 0.9, x, 0.75, z, 0.2)
	K.box("rouge_e", 1.95, 0.18, 0.95, x, 1.24, z, 0.2)
	for k in [-1.0, 1.0]:
		K.cyl("pneu", 0.3, 0.3, 0.1, x + k * 0.7, 0.3, z + 0.5, 10, PI / 2.0)
	K.cyl("acier_sombre", 0.025, 0.025, 1.6, x, 2.0, z, 5)
	K.cyl("rouge_e", 0.0, 1.4, 0.55, x, 2.85, z, 8)
	K.cyl("jaune", 0.0, 1.42, 0.2, x, 3.0, z, 8)
	K.sph("lumiere", 0.08, x - 0.6, 2.5, z + 0.5)
	K.sph("lumiere", 0.08, x + 0.6, 2.5, z + 0.5)
	E.enseigne(K, "HOT-DOGS", "#FFC24A", 1.6, 0.36, x + 0.08, 1.24, z + 0.5, 0.2, "bloc")
	K.rond(x, z, 1.0)
	K.places["e_hotdog"] = [[Vector3(x - 0.2, 0, z - 1.6), PI], [Vector3(x + 0.3, 0, z + 1.3), 0.0], [Vector3(x + 1.3, 0, z + 1.5), 0.0]]
