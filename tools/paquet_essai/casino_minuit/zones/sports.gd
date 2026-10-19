extends RefCounted
## Lot C, zone R-SPORTS (js/zones/c-sports.js) : les paris sportifs et le keno [22, 40] × [-30, -12],
## rez-de-chaussée. Le mur d'écrans de 12 × 3,2 m (mur nord) où défilent les rencontres, le keno et les
## cotes ; vingt-quatre fauteuils en quatre rangs ; trois guichets de paris (mur est) ; le bar adossé au mur
## sud ; quatre mange-debout. Au mur est, la porte du stade de la Fortune : le Racing Club Minuit y joue le
## dimanche, comme à Smarves (minuit.gd, « stade »). Liaison : la baie du foyer (ouest).

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const LOT_C := "res://communes/casino_minuit/zones/lot_c.gd"
const H := 5.4
const B := {"x0": 22.0, "x1": 40.0, "z0": -30.0, "z1": -12.0}
const OUV := {"west": [{"at": -20.0, "w": 6.0, "h": 3.6}], "east": [{"at": -14.6, "w": 2.0, "h": 2.8}]}
const ZS := -29.7
const MATCHS := [["FOOTBALL · LIGUE DES NUITS", "PARIS", "LYON"], ["BASKET · FINALE OUEST", "VEGAS", "RENO"], ["BOXE · POIDS MOYENS", "MOREAU", "DIAZ"]]
const COTES := ["Paris – Lyon  1,85  3,40  4,20", "Marseille – Lille  2,10  3,20  3,55", "Vegas – Reno  1,45  2,70",
	"Moreau – Diaz  1,60  12,0  2,30", "Nice – Nantes  2,45  3,10  2,95", "Prix de Minuit · Éclair  4,50", "KENO · TIRAGE TOUTES LES 5 MINUTES", "JOUEZ AVEC MODÉRATION"]


static func construire(K) -> void:
	var LB = load(LOT_B)
	var L = load(LOT_C)
	K.zone_debut("R-SPORTS")

	# --- enveloppe : salle sombre aux écrans, filets de néon vert ---
	L.sol(K, "moquette_c", B.x0, B.x1, B.z0, B.z1)
	L.plafond(K, "plafond_bas", B.x0, B.x1, B.z0, B.z1, H)
	LB.coque(K, B, H, "laque_noire", OUV)
	var reg := {"base": "cuir", "gorge": "neon_vert", "pil_mat": "laque_noire", "applique": false}
	L.registres(K, 22.2, -29.8, 22.2, -12.2, _avec(reg, {"n": [1.0, 0.0], "skip": [[6.8, 12.8]], "pil": [3.3, 6.35, 13.25, 15.6]}))
	L.registres(K, 39.8, -29.8, 39.8, -12.2, _avec(reg, {"n": [-1.0, 0.0], "skip": [[2.7, 10.7], [14.1, 16.3]], "pil": [1.3, 12.2]}))
	L.registres(K, 22.2, -12.2, 39.8, -12.2, _avec(reg, {"n": [0.0, -1.0], "skip": [[4.4, 13.2]], "pil": [2.2, 15.4]}))
	L.registres(K, 22.2, -29.8, 39.8, -29.8, _avec(reg, {"n": [0.0, 1.0], "bh": 0.0}))
	LB.enseigne(K, "PARIS SPORTIFS", 22.27, 4.42, -20, PI / 2.0, 4.3, 0.75, "neon", "vert")
	for p in [[22.36, -26.5], [22.36, -14.2], [39.64, -17.6], [24.4, -12.36], [37.6, -12.36]]:
		K.box("neon_vert", 0.03, 3.6, 0.03, p[0], 2.6, p[1])
	for x in [25.5, 29.0, 32.5]:
		K.box("laque_noire", 0.5, 0.2, 9, x, H - 0.1, -22.6)
		K.box("neon_vert", 0.04, 0.03, 8.6, x, H - 0.21, -22.6)

	# --- le mur d'écrans (pièce maîtresse) : trois rencontres, le keno et les cotes, un bandeau qui défile ---
	K.box("laque_noire", 12.5, 4.2, 0.12, 29, 2.75, -29.74)
	for y in [4.87, 0.66]:
		K.box("or", 12.6, 0.06, 0.16, 29, y, -29.72)
	for x in [26.0, 32.0]:
		K.box("bleu_nuit", 5.97, 3.2, 0.02, x, 3.1, ZS + 0.02)
		K.box("ecran_bleu" if x < 29.0 else "ecran_vert", 5.97, 0.03, 0.025, x, 4.69, ZS + 0.03)
	K.box("laque_noire", 0.06, 3.3, 0.06, 29, 3.1, ZS + 0.04)
	var ecrans := []
	for k in 3:
		var x0 := 23.0 + k * 2.0
		K.box("feutre" if k < 2 else "bleu_nuit", 1.8, 1.2, 0.01, x0 + 1.0, 3.2, ZS + 0.04)
		K.box("creme", 0.02, 1.1, 0.012, x0 + 1.0, 3.2, ZS + 0.045)
		K.texte(MATCHS[k][0], 1.9, 0.11, x0 + 1.0, 4.45, ZS + 0.05, 0, "grave", K.pal.or_clair)
		K.texte(MATCHS[k][1] + "   " + MATCHS[k][2], 1.9, 0.13, x0 + 1.0, 2.36, ZS + 0.05, 0, "grave", K.pal.ivoire)
		ecrans.append(K.texte("0 – 0", 1.0, 0.24, x0 + 1.0, 2.05, ZS + 0.05, 0, "neon", Color("#4DFF9A")))
	var keno: Label3D = K.texte("KENO", 2.8, 0.2, 30.5, 4.3, ZS + 0.05, 0, "neon", K.pal.or_clair)
	var tirage: Label3D = K.texte("", 2.8, 0.16, 30.5, 3.85, ZS + 0.05, 0, "grave", K.pal.ivoire)
	K.texte("COTES EN DIRECT", 2.6, 0.18, 33.6, 4.3, ZS + 0.05, 0, "neon", Color("#4DFF9A"))
	var cotes := []
	for j in 6:
		cotes.append(K.texte(COTES[j], 2.8, 0.13, 33.6, 3.9 - j * 0.3, ZS + 0.05, 0, "grave", K.pal.or_clair if j % 2 else K.pal.ivoire))
	K.box("laque_noire", 12, 0.36, 0.02, 29, 1.12, ZS + 0.04)
	var bandeau: Label3D = K.texte(COTES[0], 11.6, 0.22, 29, 1.12, ZS + 0.06, 0, "grave", Color("#4DFF9A"))
	K.chaque_image(func(_dt, t):
		var cran := int(t * 2.0)
		for k in 3:
			var tt: float = t + k * 17.0
			var m: Label3D = ecrans[k]
			if k == 2:
				m.text = "R%d" % (1 + int(tt / 30.0) % 12)
			else:
				m.text = "%d – %d" % [int(tt / 41.0) % 4 + (61 if k == 1 else 0), int(tt / 67.0) % 3 + (58 if k == 1 else 0)]
		var n := mini(20, int(fmod(t, 40.0) / 1.4))
		var tir := int(t / 40.0)
		var nums := []
		for i in n:
			nums.append(str(1 + (tir * 37 + i * 23) % 80))
		keno.text = "KENO · Tirage n° %d · %d / 20" % [4120 + tir, n]
		tirage.text = " ".join(nums.slice(maxi(0, n - 10)))
		for j in 6:
			var c: Label3D = cotes[j]
			c.modulate = Color("#4DFF9A") if (int(t / 5.0) + j) % 3 == 0 else (K.pal.or_clair if j % 2 else K.pal.ivoire)
		bandeau.text = COTES[(cran / 8) % COTES.size()]
		bandeau.position.x = 29.0 + 4.0 - fmod(t * 0.8, 8.0))
	K.lumiere(29, 3.2, -27.2, Color("#BFD4FF"), 1.7, 15.0)
	# Les écrans secondaires : au-dessus du bar (mur sud) et des guichets (mur est).
	for x in [27.6, 31.0, 34.4]:
		K.box("laque_noire", 2.5, 1.2, 0.08, x, 4.2, -12.3)
		K.box("bleu_nuit", 2.36, 1.06, 0.02, x, 4.2, -12.35)
		K.box("feutre", 2.0, 0.7, 0.01, x, 4.25, -12.365)
		K.texte(MATCHS[int(x) % 3][1] + " – " + MATCHS[int(x) % 3][2], 2.0, 0.14, x, 3.8, -12.37, PI, "grave", K.pal.ivoire)
	for z in [-25.4, -20.9]:
		K.box("laque_noire", 0.08, 1.25, 3.3, 39.74, 4.15, z)
		K.box("bleu_nuit", 0.02, 1.1, 3.1, 39.69, 4.15, z)
		K.texte("COTES EN DIRECT", 2.6, 0.2, 39.67, 4.45, z, -PI / 2.0, "neon", Color("#4DFF9A"))
		K.texte(COTES[0] if z < -23.0 else COTES[1], 2.9, 0.13, 39.67, 4.05, z, -PI / 2.0, "grave", K.pal.or_clair)

	# --- vingt-quatre fauteuils en quatre rangs face au mur d'écrans, pupitres de mise filants ---
	var parieurs := []
	for z in [-26.0, -23.75, -21.5, -19.25]:
		K.box("laque_noire", 8.7, 0.72, 0.28, 29, 0.36, z - 0.74)
		K.box("or", 8.76, 0.03, 0.32, 29, 0.735, z - 0.74)
		K.box("neon_vert", 8.5, 0.02, 0.02, 29, 0.1, z - 0.885)
		K.obstacle(24.65, 33.35, z - 0.88, z - 0.6, 0.0, 0.8)
		for k in 6:
			var x := 25.25 + k * 1.5
			parieurs.append(L.fauteuil(K, x, z, 0.0, "cuir"))
			K.box("ecran_vert", 0.26, 0.012, 0.16, x, 0.756, z - 0.74)
	K.places["sports_fauteuils"] = parieurs

	# --- trois guichets de paris et keno (mur est) ---
	K.box("laque_noire", 0.5, 1.06, 8.0, 38.1, 0.53, -23.3)
	K.box("marbre_noir", 0.66, 0.06, 8.1, 38.07, 1.09, -23.3)
	K.box("neon_vert", 0.02, 0.03, 7.8, 37.84, 0.13, -23.3)
	K.box("laque_noire", 1.6, 0.5, 8.2, 38.95, 3.2, -23.3)
	for y in [3.47, 2.94]:
		K.box("or", 1.66, 0.05, 8.26, 38.95, y, -23.3)
	LB.enseigne(K, "PARIS · KENO", 38.13, 3.2, -23.3, -PI / 2.0, 3.6, 0.62, "neon", "vert")
	K.obstacle(37.85, 40.0, -27.35, -19.25, 0.0, 2.4)
	var guichetiers := []
	var clients := []
	for i in 3:
		var z: float = [-25.9, -23.3, -20.7][i]
		for s in [-1.0, 1.0]:
			K.box("or", 0.07, 1.86, 0.07, 37.95, 2.03, z + s * 1.25)
		K.box("verre", 0.02, 1.4, 2.4, 37.95, 1.82, z)
		K.box("or", 0.36, 0.012, 0.28, 38.05, 1.127, z)
		K.box("ecran_vert", 0.02, 0.2, 0.3, 38.3, 1.3, z + 0.6)
		K.texte("GUICHET %d" % (i + 1), 0.6, 0.14, 37.9, 2.72, z, -PI / 2.0)
		guichetiers.append([Vector3(39.05, 0, z), PI / 2.0])
		clients.append([Vector3(37.27, 0, z), -PI / 2.0])
	K.places["sports_guichetiers"] = guichetiers
	K.places["sports_guichets"] = clients
	K.interaction("paris", "Les guichets de paris", 37.4, 1.3, -23.3, Vector3(1.0, 2.6, 7.8))

	# --- le bar, adossé au mur sud, ses clients tournés vers les écrans ---
	var bar: Dictionary = LB.bar(K, 31, -15.8, PI, 5.0, H)
	var tabourets := []
	for p in bar.tabourets:
		tabourets.append([Vector3(p.x, 0.76, p.y), PI])
	K.places["sports_bar"] = {"tabourets": tabourets, "barman": bar.barman}
	LB.enseigne(K, "BAR", 31, 3.28, -12.3, PI, 1.5, 0.66, "neon", "rose")
	K.lumiere(31, 3.0, -16.2, K.pal.lumiere, 1.6, 12.0)

	# --- la porte du stade de la Fortune (mur est) ---
	L.baie(K, {"axe": "x", "at": 40.0, "c": -14.6, "w": 2.0, "h": 2.8, "mat": "laque_rouge"})
	K.box("vert_jardin", 0.04, 2.8, 2.0, 40.06, 1.4, -14.6)
	K.box("laque_noire", 0.04, 2.6, 0.06, 39.98, 1.3, -14.6)
	K.solide(0.3, 2.8, 2.0, 40.1, 1.4, -14.6)
	LB.enseigne(K, "STADE DE LA FORTUNE", 39.74, 3.7, -14.6, -PI / 2.0, 2.6, 0.4, "neon", "rouge")
	LB.enseigne(K, "Racing Club Minuit · le dimanche", 39.74, 3.25, -14.6, -PI / 2.0, 2.2, 0.26, "plaque")
	K.interaction("stade", "Le stade de la Fortune", 39.3, 1.3, -14.6, Vector3(1.2, 2.6, 2.4))

	# --- quatre mange-debout, plantes ---
	var debout := []
	var md := [[24.3, -14.7], [36.0, -17.6], [23.9, -27.9], [36.6, -28.5]]
	for i in md.size():
		debout.append_array(L.mange_debout(K, md[i][0], md[i][1], 3, i * 0.7))
	K.places["sports_debout"] = debout
	var regards := []
	for p in [[24.2, -24.5], [24.2, -22.0], [34.6, -25.5], [35.2, -18.4], [23.6, -18.2]]:
		regards.append([Vector3(p[0], 0, p[1]), atan2(-(29.0 - p[0]), -(-29.7 - p[1]))])
	K.places["sports_regards"] = regards
	LB.palmier(K, 22.9, -12.9, {"seed": 3, "pot": "laque_noire"})
	LB.palmier(K, 39.1, -12.9, {"seed": 14, "pot": "laque_noire"})
	K.lumiere(31, 3.3, -22, Color("#9FB8FF"), 1.0, 12.0)
	K.zone_fin()


static func _avec(a: Dictionary, b: Dictionary) -> Dictionary:
	var o := a.duplicate()
	o.merge(b, true)
	return o
