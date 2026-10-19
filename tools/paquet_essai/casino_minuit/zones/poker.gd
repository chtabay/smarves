extends RefCounted
## Lot B, zone R-POKER (js/zones/b-poker.js) : la salle de poker. Rectangle [-40, -26] × [-30, -12],
## rez-de-chaussée ; on y entre par les machines (liaison L24, au sud). Cinq tables ovales de huit places,
## trois ouvertes avec leur croupier, deux sous housse ; elles sont du décor. Pièce maîtresse : le mur des
## tournois, au nord, dans l'axe de l'entrée.

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const H := 5.4
const B := {"x0": -40.0, "x1": -26.0, "z0": -30.0, "z1": -12.0}
const OUV := {"south": [{"at": -33.0, "w": 4.0, "h": 3.4}], "north": [], "east": [], "west": []}
const ANG := [-140, -100, -60, -20, 20, 60, 100, 140]
## Les tables : x, z, sous housse.
const TABLES := [[-36.2, -17.2, false], [-29.8, -17.2, true], [-33.0, -21.6, false], [-36.2, -26.0, true], [-29.8, -26.0, false]]
const TOURNOIS := [["Le Minuit Classic", "250", "64", "TABLE FINALE"], ["Hold'em des Noctambules", "100", "118", "EN COURS"],
	["Omaha du Croupier", "150", "42", "EN COURS"], ["Sit & Go Turbo", "50", "7", "INSCRIPTIONS"], ["Grand Prix de la Fortune", "1 000", "23", "INSCRIPTIONS"],
	["Satellite du Jeudi", "25", "90", "COMPLET"]]


static func construire(K) -> void:
	var L = load(LOT_B)
	K.zone_debut("R-POKER")
	K.plan("moquette_c", B.x0, B.x1, B.z0, B.z1, 0)
	K.dalle(B.x0, B.x1, B.z0, B.z1)
	K.plan("plafond_bas", B.x0, B.x1, B.z0, B.z1, H, false)
	L.coque(K, B, H, "bois_laque", OUV)
	L.habille(K, B, H, OUV, {"socle": "marbre_noir", "pil": 4.4, "pil_mat": "laque_noire", "applique": "alt", "gorge": "neon_cyan",
		"skip": {"north": [{"at": -33.0, "w": 9.4}]}})
	# Les panneaux de velours bleu nuit entre les pilastres des murs est et ouest.
	for i in 4:
		var z := -27.6 + i * 4.42
		for q in [[-39.77, PI / 2.0], [-26.23, -PI / 2.0]]:
			L.panneau(K, q[0], 2.75, z, q[1], 2.5, 2.5, "bleu_nuit")
			L.octa(K, ["laque_rouge", "or"][(i + int(q[0] > -30)) % 2], K.xf(q[0] + sin(q[1]) * 0.08, 2.75, z, 0, q[1], 0, 0.35, 0.5, 0.06))

	# --- le mur des tournois (mur nord) : un tableau de 8 × 3 m sous ses filets de néon cyan ---
	K.box("laque_noire", 8.5, 3.5, 0.1, -33, 2.95, -29.76)
	K.box("bleu_nuit", 8.0, 3.0, 0.02, -33, 2.95, -29.7)
	for q in [[8.6, 0.1, 0.0, 1.75], [8.6, 0.1, 0.0, -1.75], [0.1, 3.6, 4.25, 0.0], [0.1, 3.6, -4.25, 0.0]]:
		K.box("or", q[0], q[1], 0.14, -33 + q[2], 2.95 + q[3], -29.74)
	for y in [4.85, 1.05]:
		K.box("neon_cyan", 8.3, 0.04, 0.04, -33, y, -29.66)
	K.texte("TOURNOIS DU MINUIT", 6.0, 0.42, -33, 4.15, -29.66, 0, "neon", L.NEON.cyan)
	K.box("or", 7.6, 0.03, 0.02, -33, 3.82, -29.67)
	var cols := [[-35.4, 3.6], [-31.6, 1.0], [-30.6, 1.0], [-29.3, 1.8]]
	for c in 4:
		K.texte(["TOURNOI", "ENTRÉE", "JOUEURS", "STATUT"][c], cols[c][1], 0.14, cols[c][0], 3.62, -29.67, 0, "grave")
	for i in TOURNOIS.size():
		var r: Array = TOURNOIS[i]
		for c in 4:
			var coul: Color = L.NEON.ivoire
			if c == 3:
				coul = L.NEON.vert if r[3] == "INSCRIPTIONS" else (L.NEON.rouge if r[3] == "COMPLET" else L.NEON.cyan)
			K.texte(r[c], cols[c][1], 0.17, cols[c][0], 3.3 - i * 0.36, -29.67, 0, "neon" if c == 3 else "grave", coul if c == 3 else Color())
	K.lumiere(-33, 3.6, -27.2, Color("#D6ECFF"), 1.4, 13.0)

	# --- les cinq tables : croupier au nord, joueurs face au mur des tournois ---
	var tables := []
	for t in TABLES:
		var d: Dictionary = L.table_jeu(K, t[0], t[1], 0.0, {"a": 1.3, "b": 0.7, "angles": ANG, "felt": "feutre_bleu", "rim": "capiton_rouge", "chaise": "cuir_noir", "closed": t[2]})
		if not t[2]:
			L.suspension(K, t[0], t[1], H, 2.3, 0.5)
			tables.append(d)
	K.places["poker"] = tables
	K.lumiere(-33, 2.6, -21.6, K.pal.lumiere, 1.6, 12.0)
	for q in [[-33.0, -15.2], [-36.4, -21.6], [-29.6, -21.6], [-33.0, -26.4]]:
		K.lanterne(q[0], 3.25, q[1], 0.85, H - 3.86)

	# --- le pupitre de la liste d'attente, à droite en entrant ; bancs, palmiers ---
	K.box("laque_noire", 0.9, 1.1, 0.5, -29.4, 0.55, -13.6)
	K.box("or", 0.96, 0.04, 0.56, -29.4, 1.12, -13.6)
	K.box("onyx", 0.7, 0.6, 0.02, -29.4, 0.6, -13.34)
	L.lampe(K, -29.05, 1.14, -13.7, 0.8)
	K.obstacle(-29.86, -28.94, -13.86, -13.34)
	K.cyl("or", 0.015, 0.015, 0.5, -29.4, 1.38, -13.5, 5)
	L.enseigne(K, "Liste d'attente", -29.4, 1.75, -13.5, 0, 1.2, 0.3, "plaque", "ambre", true)
	K.places["poker_pupitre"] = [[Vector3(-29.4, 0, -14.35), PI]]
	var bancs := []
	for z in [-20.6, -23.2]:
		bancs.append_array(L.salon(K, -26.75, z, PI / 2.0, [{"k": "banc", "x": 0.0, "z": 0.0, "f": 0.0, "n": 2, "w": 1.7}], {"banc_mat": "marbre_noir"}))
	K.places["poker_bancs"] = bancs
	for q in [[-39.2, -12.8, 21], [-26.8, -12.8, 22], [-39.2, -29.2, 23], [-26.8, -29.2, 24]]:
		L.palmier(K, q[0], q[1], {"h": 3.3 if q[1] > -20 else 3.1, "seed": q[2]})
	K.zone_fin()
