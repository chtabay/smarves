extends RefCounted
## Lot B, zone R-LOBBY (js/zones/b-lobby.js) : la réception et la conciergerie de l'hôtel. Rectangle
## [-30, -10] × [12, 30], rez-de-chaussée, 5,4 m sous plafond. On y entre par la rotonde (portail ouest) et
## par l'atrium (arche « Hôtel · Réception »). Pièce maîtresse : le plafond de fleurs de verre au-dessus
## d'une borne capitonnée ; le comptoir de réception est adossé au mur sud.
## Liaisons : vers les machines (nord), le salon (ouest, rideaux) et les toilettes ouest (porte).

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const H := 5.4
const B := {"x0": -30.0, "x1": -10.0, "z0": 12.0, "z1": 30.0}
const OUV := {"north": [{"at": -25.0, "w": 6.0, "h": 3.6}, {"at": -14.0, "w": 5.0, "h": 4.6}], "east": [{"at": 21.0, "w": 5.0, "h": 4.6}],
	"west": [{"at": 16.5, "w": 5.0, "h": 3.4}, {"at": 25.5, "w": 1.6, "h": 2.3}], "south": []}
const FX := -20.0
const FZ := 19.5
const TEINTES := ["#FFB347", "#FF5A2A", "#F2CF7A", "#FF4D8D", "#2FA8A0", "#F3EAD7", "#B3121F", "#FF8A2A"]


static func construire(K) -> void:
	var L = load(LOT_B)
	K.zone_debut("R-LOBBY")

	# --- enveloppe : marbre crème, boiserie claire, pilastres de marbre à appliques ---
	K.plan("marbre_creme", B.x0, B.x1, B.z0, B.z1, 0)
	K.dalle(B.x0, B.x1, B.z0, B.z1)
	K.plan("plafond_bas", B.x0, B.x1, B.z0, B.z1, H, false)
	L.coque(K, B, H, "bois_clair", OUV)
	L.habille(K, B, H, OUV, {"socle": "marbre_rouge", "pil": 4.4, "applique": "alt",
		"skip": {"south": [{"at": -22.0, "w": 11.0}, {"at": -13.9, "w": 3.0}], "east": [{"at": 26.6, "w": 3.0}]}})
	L.encadre(K, "z", 12, -25, 6, 3.6, {"fronton": 0.9})
	L.enseigne(K, "MACHINES À SOUS", -25, 4.22, 12.245, 0, 4.6, 0.62, "neon", "rose")
	L.enseigne(K, "HÔTEL · RÉCEPTION", -25, 4.22, 11.755, PI, 4.6, 0.56, "neon", "ambre")
	L.encadre(K, "x", -30, 16.5, 5, 3.4, {"rideaux": "velours", "fronton": 0.8})
	L.enseigne(K, "LE SALON", -29.755, 3.96, 16.5, PI / 2.0, 2.6, 0.52, "neon", "ambre")
	L.encadre(K, "x", -30, 25.5, 1.6, 2.3)
	L.porte_ouverte(K, -30.2, 25.5, 1, 0, 1.44, 2.22)
	L.enseigne(K, "Toilettes", -29.74, 2.78, 25.5, PI / 2.0, 1.2, 0.3, "plaque")

	# --- le plafond de fleurs de verre : un caisson d'onyx de 8 × 5 m, 170 corolles qui luisent ---
	K.plan("onyx", FX - 4, FX + 4, FZ - 2.5, FZ + 2.5, H - 0.04, false)
	for q in [[8.6, 0.3, FX, FZ - 2.65], [8.6, 0.3, FX, FZ + 2.65], [0.3, 5.0, FX - 4.15, FZ], [0.3, 5.0, FX + 4.15, FZ]]:
		K.box("laque_noire", q[0], 0.42, q[1], q[2], H - 0.21, q[3])
		K.box("or", q[0] if q[0] > 1 else 0.36, 0.05, q[1] if q[1] > 1 else 0.36, q[2], H - 0.44, q[3])
	var corolle = K.lathe([[0.03, 0.0], [0.24, -0.2], [0.5, -0.3]], 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 170:
		var sc := 0.42 + rng.randf() * 0.5
		var x := FX - 3.8 + rng.randf() * 7.6
		var y := H - 0.12 - rng.randf() * 0.75 * (0.4 + absf(sin(i * 1.7)))
		var z := FZ - 2.3 + rng.randf() * 4.6
		var t: Transform3D = K.xf(x, y, z, (rng.randf() - 0.5) * 0.7, rng.randf() * TAU, (rng.randf() - 0.5) * 0.7, sc, sc * (0.8 + rng.randf() * 0.6), sc)
		K.put("lueur" + TEINTES[rng.randi() % TEINTES.size()], corolle, t)
	K.lumiere(FX, 4.1, FZ, K.pal.lumiere, 1.3, 15.0)
	# Le tapis à médaillons sous les fleurs, bordé d'or.
	K.plan("moquette_d", -24.6, -15.4, 16.3, 22.7, 0.006)
	for q in [[9.3, 0.09, FX, 16.3], [9.3, 0.09, FX, 22.7], [0.09, 6.5, -24.6, FZ], [0.09, 6.5, -15.4, FZ]]:
		K.box("or", q[0], 0.012, q[1], q[2], 0.008, q[3])
	# La borne capitonnée ronde et son palmier : quatre places, dos au centre.
	L.disque(K, "laque_noire", FX, 0.06, FZ, 1.22, 0.12, 1.22)
	L.disque(K, "or", FX, 0.13, FZ, 1.3, 0.03, 1.3)
	L.disque(K, "velours", FX, 0.3, FZ, 1.3, 0.3, 1.3)
	K.cyl("velours", 0.42, 0.62, 0.62, FX, 0.76, FZ, 16)
	L.disque(K, "or", FX, 1.09, FZ, 0.46, 0.04, 0.46)
	L.palmier(K, FX, FZ, {"h": 3.5, "seed": 7, "collide": false, "pot": "marbre_rouge"})
	K.rond(FX, FZ, 1.32, 0.0, 1.0)
	var places := []
	for i in 4:
		var a := i * PI / 2.0 + PI / 4.0
		places.append([Vector3(FX + sin(a) * 1.0, 0.45, FZ + cos(a) * 1.0), a + PI])
	# Trois salons adossés aux murs : canapé, fauteuil, table basse à lampe.
	for s in [[-29.15, 21.8, -PI / 2.0, 1.0], [-19.25, 12.85, PI, 1.0], [-10.85, 16.1, PI / 2.0, -1.0]]:
		var k: float = s[3]
		places.append_array(L.salon(K, s[0], s[1], s[2], [{"k": "sofa", "x": 0.0, "z": 0.0, "f": 0.0, "n": 2}, {"k": "fauteuil", "x": 1.75 * k, "z": -1.15, "f": k * PI / 2.0}],
			{"mat": "velours", "table": [0.1 * k, -1.4, 0.4], "lampe": true}))
	for q in [[-28.0, 21.9, 2.6, 3.6], [-19.3, 13.9, 3.8, 2.6], [-12.0, 16.2, 2.6, 3.8]]:
		K.plan("moquette_d", q[0] - q[2] / 2.0, q[0] + q[2] / 2.0, q[1] - q[3] / 2.0, q[1] + q[3] / 2.0, 0.006)
	K.places["lobby_salons"] = places

	# --- la réception : comptoir de 10 m, mur d'onyx et lettres découpées, trois guichets, file de cordons ---
	K.box("laque_noire", 10, 1.04, 0.7, -22, 0.52, 27.6)
	K.box("marbre_rouge", 10.3, 0.06, 0.92, -22, 1.07, 27.56)
	K.box("gorge", 9.9, 0.05, 0.04, -22, 0.07, 27.23)
	for i in 5:
		K.box("onyx", 1.72, 0.66, 0.03, -26 + i * 2, 0.56, 27.24)
		K.box("or", 1.8, 0.03, 0.04, -26 + i * 2, 0.92, 27.235)
	K.obstacle(-27.05, -16.95, 27.22, 27.98)
	K.box("onyx", 9.0, 2.2, 0.02, -22, 2.55, 29.78)
	for y in [3.7, 1.4]:
		K.box("or", 9.2, 0.1, 0.08, -22, y, 29.76)
	for x in [-26.75, -17.25]:
		K.box("gorge", 1.3, 2.3, 0.02, x, 2.55, 29.78)
		K.box("treillis", 1.3, 2.3, 0.01, x, 2.55, 29.72)
		for sg in [-1.0, 1.0]:
			K.box("laque_noire", 0.12, 2.4, 0.1, x + sg * 0.71, 2.55, 29.74)
	L.enseigne(K, "RÉCEPTION", -22, 2.6, 29.7, PI, 5.6, 1.05, "neon", "ivoire")
	K.box("laque_noire", 9.4, 0.9, 0.32, -22, 0.45, 29.62)
	K.obstacle(-26.7, -17.3, 29.46, 29.8)
	var reception := []
	for x in [-25.0, -22.0, -19.0]:
		K.box("or", 0.34, 0.02, 0.24, x, 1.11, 27.4)
		K.cyl("or", 0.05, 0.07, 0.05, x - 0.5, 1.125, 27.45, 8)
		L.lampe(K, x + 0.95, 1.1, 27.65, 0.8)
		reception.append([Vector3(x, 0, 28.5), 0.0])
	K.places["lobby_reception"] = reception
	for x in [-22.75, -21.25]:
		for z in [25.6, 23.6, 21.6]:
			K.cyl("or", 0.15, 0.17, 0.03, x, 0.015, z, 8)
			K.cyl("or", 0.022, 0.022, 0.95, x, 0.49, z, 6)
			L.octa(K, "or", K.xf(x, 1.0, z, 0, 0, 0, 0.05, 0.05, 0.05))
		K.box("laque_rouge", 0.045, 0.045, 3.92, x, 0.84, 23.6)
		K.segment(x, 21.55, x, 25.65, 0.05, 0.0, 1.0)
	K.urne(-27.6, 26.2, 1.2)
	K.urne(-16.4, 26.2, 1.2)
	K.lumiere(-22, 3.3, 26.2, K.pal.lumiere, 1.1, 13.0)

	# --- la conciergerie et le voiturier : pupitre, tableau de clés ---
	K.box("laque_noire", 0.7, 1.02, 2.0, -12.25, 0.51, 26.6)
	K.box("marbre_rouge", 0.86, 0.05, 2.16, -12.25, 1.045, 26.6)
	K.box("onyx", 0.03, 0.62, 1.7, -12.615, 0.56, 26.6)
	K.obstacle(-12.62, -11.9, 25.58, 27.62)
	L.lampe(K, -12.25, 1.07, 25.9, 0.9)
	L.panneau(K, -10.2, 2.45, 26.6, -PI / 2.0, 2.6, 1.5, "laque_noire")
	for j in 4:
		for i in 9:
			if (i * 3 + j * 5) % 7:
				K.box("or", 0.02, 0.1, 0.035, -10.28, 2.0 + j * 0.3, 25.6 + i * 0.25)
	L.enseigne(K, "CONCIERGERIE · VOITURIER", -10.24, 3.52, 26.6, -PI / 2.0, 3.0, 0.4, "or")
	K.places["lobby_concierge"] = [[Vector3(-11.15, 0, 26.6), PI / 2.0]]
	# Les distributeurs de billets, au mur sud.
	for x in [-14.6, -13.2]:
		K.box("laque_noire", 0.92, 2.1, 0.5, x, 1.05, 29.55)
		K.box("or", 0.96, 0.05, 0.54, x, 2.12, 29.55)
		K.box("onyx", 0.8, 0.3, 0.02, x, 1.85, 29.29)
		K.box("ampoule", 0.5, 0.36, 0.02, x, 1.35, 29.29)
		K.box("or", 0.56, 0.42, 0.015, x, 1.35, 29.295)
		K.box("or", 0.5, 0.04, 0.2, x, 1.02, 29.24)
		K.obstacle(x - 0.47, x + 0.47, 29.28, 29.8)
	L.enseigne(K, "Distributeurs", -13.9, 2.45, 29.76, PI, 1.5, 0.3, "plaque")

	# --- lustres, palmiers ---
	L.lustre(K, -13.6, 3.75, 21, H, 0.95, 10, 0.9)
	L.lustre(K, -26.4, 3.75, 21.2, H, 0.95, 10, 0.9)
	L.palmier(K, -29.2, 29.2, {"h": 3.4, "seed": 2, "pot": "marbre_rouge"})
	L.palmier(K, -10.8, 29.2, {"h": 3.6, "seed": 3, "pot": "marbre_rouge"})
	L.palmier(K, -29.2, 12.8, {"h": 3.2, "seed": 4, "pot": "marbre_rouge"})
	K.zone_fin()
