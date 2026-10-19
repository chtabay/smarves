extends RefCounted
## Lot B, zone R-MACHINES (js/zones/b-machines.js) : la forêt de machines à sous. Rectangle [-40, -18] ×
## [-12, 12], rez-de-chaussée, 5,4 m sous plafond, ouverte sur l'atrium par la colonnade de 21 m.
## Quarante-huit machines en huit carrousels de six, sous des dais à néons ; elles sont du décor (on y
## jouera plus tard). Pièce maîtresse : le totem « Jackpot » et son kiosque de change.
## Liaisons : vers le poker (nord), le salon (sud-ouest) et le lobby (sud).

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const H := 5.4
const B := {"x0": -40.0, "x1": -18.0, "z0": -12.0, "z1": 12.0}
const OUV := {"north": [{"at": -33.0, "w": 4.0, "h": 3.4}], "south": [{"at": -35.0, "w": 3.0, "h": 3.0}, {"at": -25.0, "w": 6.0, "h": 3.6}],
	"west": [], "east": [{"at": -1.5, "w": 21.0, "h": 5.4}, {"at": 10.5, "w": 1.6, "h": 2.3}]}
const NEONS := ["neon_rose", "neon_cyan", "neon_ambre"]
const CAR := [[-23.5, -7.5], [-23.5, 0.0], [-23.5, 7.5], [-30.0, -7.5], [-30.0, 7.5], [-36.5, -7.5], [-36.5, 0.0], [-36.5, 7.5]]
const TX := -30.0
const TZ := 0.0


static func construire(K) -> void:
	var L = load(LOT_B)
	K.zone_debut("R-MACHINES")

	# --- enveloppe : moquette « confettis », laque noire, filets de néon ---
	K.plan("moquette_e", B.x0, B.x1, B.z0, B.z1, 0)
	K.dalle(B.x0, B.x1, B.z0, B.z1)
	K.plan("plafond_bas", B.x0, B.x1, B.z0, B.z1, H, false)
	L.coque(K, B, H, "laque_noire", OUV)
	var pil: Array = L.habille(K, B, H, OUV, {"east": false, "socle": "laque_noire", "cimaise": "neon_rose", "gorge": "neon_rose", "pil": 4.4,
		"pil_mat": "laque_noire", "applique": false, "skip": {"west": [{"at": 0.0, "w": 9.6}, {"at": -9.5, "w": 3.0}, {"at": 9.5, "w": 3.0}], "south": [{"at": -19.5, "w": 3.4}]}})
	for i in pil.size():
		var p: Dictionary = pil[i]
		K.box(NEONS[i % 3], 0.05, 3.3, 0.05, p.x + p.nx * 0.2, 2.9, p.z + p.nz * 0.2)
	L.encadre(K, "z", -12, -33, 4, 3.4, {"fronton": 1.0})
	L.enseigne(K, "POKER", -33, 4.12, -11.755, 0, 3.0, 0.72, "neon", "cyan")
	L.enseigne(K, "MACHINES À SOUS", -33, 4.1, -12.245, PI, 3.6, 0.5, "neon", "rose")
	L.encadre(K, "z", 12, -35, 3, 3, {"fronton": 0.8})
	L.enseigne(K, "LE SALON", -35, 3.58, 11.755, PI, 2.4, 0.5, "neon", "ambre")
	# La grande enseigne du mur ouest, dans son cadre d'or.
	K.box("laque_noire", 0.1, 1.7, 9.2, -39.74, 3.5, 0)
	for dy in [0.86, -0.86]:
		K.box("or", 0.12, 0.08, 9.3, -39.72, 3.5 + dy, 0)
	for z in [-4.65, 4.65]:
		K.box("or", 0.12, 1.8, 0.08, -39.72, 3.5, z)
	L.enseigne(K, "MACHINES À SOUS", -39.66, 3.5, 0, PI / 2.0, 8.6, 1.25, "neon", "rose")
	# Les arcs de néon entre les pilastres (le motif de Las Vegas).
	var arcs := [[-37.4, -11.78, 0.0], [-28.6, -11.78, 0.0], [-22.0, -11.78, 0.0], [-29.9, 11.78, PI], [-39.78, -6.6, PI / 2.0], [-39.78, 6.6, PI / 2.0]]
	for i in arcs.size():
		var q: Array = arcs[i]
		var c: String = NEONS[(i + 1) % 3]
		K.put(c, K._arc_or(1.12, 1.18, 0.05, 10), K.xf(q[0], 2.6, q[1], 0, q[2]))
		K.put(NEONS[i % 3], K._arc_or(0.76, 0.81, 0.05, 8), K.xf(q[0], 2.6, q[1], 0, q[2]))
		for s in [-1.0, 1.0]:
			K.box(c, 0.05, 1.3, 0.05, q[0] + cos(q[2]) * s * 1.15, 1.95, q[1] - sin(q[2]) * s * 1.15)

	# --- les huit carrousels : pilier, anneaux de néon, dais lumineux, six machines ---
	var joueurs := []
	for ci in CAR.size():
		var cx: float = CAR[ci][0]
		var cz: float = CAR[ci][1]
		var nm: String = NEONS[ci % 3]
		K.cyl("laque_noire", 0.46, 0.6, 2.7, cx, 1.35, cz, 12)
		K.cyl("or", 0.63, 0.63, 0.06, cx, 0.03, cz, 12)
		for q in [[0.6, 2.05], [0.66, 2.3], [0.72, 2.55]]:
			K.tore(nm, q[0], 0.035, K.xf(cx, q[1], cz), 18)
		L.disque(K, "laque_noire", cx, 2.92, cz, 2.05, 0.24, 2.05)
		K.tore("or", 2.06, 0.05, K.xf(cx, 2.81, cz), 32)
		K.tore(nm, 1.86, 0.045, K.xf(cx, 2.77, cz), 32)
		K.tore(nm, 1.2, 0.035, K.xf(cx, 2.78, cz), 24)
		K.tore(nm, 1.6, 0.04, K.xf(cx, 3.07, cz), 28)
		K.cyl("laque_noire", 0.22, 0.42, H - 3.04, cx, (H + 3.04) / 2.0, cz, 10)
		L.disque(K, "or", cx, H - 0.04, cz, 0.7, 0.08, 0.7)
		K.rond(cx, cz, 0.72)
		for k in 6:
			var a := k * PI / 3.0
			var x := cx + 1.1 * sin(a)
			var z := cz + 1.1 * cos(a)
			joueurs.append(L.machine(K, x, z, a, ["ecran", "ecran_rose", "ecran_or"][(k + ci) % 3], ["caisse_a", "caisse_b", "caisse_c"][(k + ci) % 3]))
			K.rond(x, z, 0.4)
	K.places["machines"] = joueurs

	# --- le totem « Jackpot » : socle, mât, trois couronnes d'ampoules, afficheur de cagnotte, étoile ---
	L.disque(K, "laque_noire", TX, 0.3, TZ, 0.74, 0.6, 0.74)
	L.disque(K, "or", TX, 0.62, TZ, 0.8, 0.05, 0.8)
	K.tore("neon_ambre", 0.78, 0.03, K.xf(TX, 0.12, TZ), 24)
	K.cyl("or", 0.13, 0.2, 4.0, TX, 2.6, TZ, 10)
	K.box("laque_noire", 1.02, 0.66, 1.02, TX, 2.05, TZ)
	K.box("or", 1.1, 0.06, 1.1, TX, 2.41, TZ)
	K.box("or", 1.1, 0.06, 1.1, TX, 1.69, TZ)
	for q in [[0.95, 3.0, 20], [0.72, 3.7, 16], [0.48, 4.3, 12]]:
		K.tore("or", q[0], 0.035, K.xf(TX, q[1], TZ), 24)
		for k in 4:
			var a := k * PI / 2.0 + PI / 4.0
			K.beam("or", Vector3(TX, q[1] - 0.25, TZ), Vector3(TX + cos(a) * q[0], q[1], TZ + sin(a) * q[0]), 0.03, 0.03)
		for k in q[2]:
			var a: float = float(k) / q[2] * TAU
			L.octa(K, "ampoule" if k % 2 else "neon_ambre", K.xf(TX + cos(a) * q[0], q[1] - 0.09, TZ + sin(a) * q[0], 0, 0, 0, 0.06, 0.085, 0.06))
	L.octa(K, "ampoule", K.xf(TX, 4.95, TZ, 0, 0.4, 0, 0.26, 0.4, 0.26))
	L.octa(K, "ampoule", K.xf(TX, 4.95, TZ, 0, 0, PI / 2.0, 0.14, 0.42, 0.14))
	var cagnotte := []
	for k in 4:
		var a := k * PI / 2.0
		K.texte("JACKPOT", 0.9, 0.2, TX + sin(a) * 0.52, 2.22, TZ + cos(a) * 0.52, a, "neon", L.NEON.rose)
		cagnotte.append(K.texte("1 284 560", 0.9, 0.2, TX + sin(a) * 0.52, 1.92, TZ + cos(a) * 0.52, a, "neon", L.NEON.ambre))
	var pot := [1284560, 0.0]
	K.chaque_image(func(dt, _t):
		pot[1] += dt
		if pot[1] > 1.0:
			pot[1] = 0.0
			pot[0] += 137 + randi() % 600
			for l in cagnotte:
				l.text = Game.fmt(pot[0]))
	K.rond(TX, TZ, 0.8)
	K.lumiere(TX, 4.2, TZ + 0.9, K.pal.lumiere, 1.9, 15.0)
	# Le kiosque de change, adossé au totem : le comptoir au sud, la caissière derrière.
	K.box("laque_noire", 2.5, 1.04, 0.5, TX, 0.52, 2.65)
	K.box("marbre_noir", 2.7, 0.06, 0.68, TX, 1.07, 2.65)
	K.box("onyx", 2.3, 0.66, 0.02, TX, 0.56, 2.91)
	K.box("gorge", 2.4, 0.05, 0.04, TX, 0.07, 2.92)
	K.obstacle(TX - 1.28, TX + 1.28, 2.38, 2.94)
	for q in [[-1.22, 2.84], [1.22, 2.84], [-1.22, 1.3], [1.22, 1.3]]:
		K.cyl("or", 0.03, 0.03, 2.5, TX + q[0], 1.25, q[1], 6)
	K.box("laque_noire", 2.7, 0.16, 1.8, TX, 2.58, 2.07)
	K.box("or", 2.76, 0.04, 1.86, TX, 2.48, 2.07)
	K.box("neon_ambre", 2.6, 0.04, 0.04, TX, 2.45, 2.98)
	K.box("laque_noire", 2.1, 0.6, 0.04, TX, 2.95, 2.86)
	L.enseigne(K, "CHANGE", TX, 2.95, 2.9, 0, 1.9, 0.5, "neon", "ambre", true)
	for dx in [-0.7, 0.7]:
		K.box("or", 0.3, 0.14, 0.22, TX + dx, 1.17, 2.6)
	K.interaction("change", "Le change du Minuit", TX, 1.2, 3.3, Vector3(2.6, 2.0, 1.0))
	K.places["machines_change"] = [[Vector3(TX, 0, 1.87), PI]]

	# --- bancs du mur ouest, ascenseur, lumières ---
	var bancs := []
	for z in [-3.75, 3.75]:
		bancs.append_array(L.salon(K, -39.3, z, -PI / 2.0, [{"k": "banc", "x": 0.0, "z": 0.0, "f": 0.0, "n": 2, "w": 1.7}], {"banc_mat": "marbre_noir"}))
	K.places["machines_bancs"] = bancs
	L.gaine(K, H)
	L.enseigne(K, "Ascenseur", -21.02, 3.1, 10.4, -PI / 2.0, 1.3, 0.3, "plaque")
	K.lumiere(-23.5, 3.5, -3.75, Color("#FFC9E0"), 1.5, 13.0)
	K.lumiere(-36.5, 3.5, 3.75, Color("#C9F2FF"), 1.4, 13.0)
	K.zone_fin()
