extends RefCounted
## Lot C, zone R-CLUB (js/zones/c-club.js) : le club de fidélité « Club Minuit » [10, 20] × [12, 30],
## rez-de-chaussée. Le comptoir adossé au mur sud devant le mur de cartes dorées (on s'y inscrit, au-delà
## d'un seuil : minuit.gd, « club_minuit »), trois distributeurs de billets (mur ouest), deux bornes (mur est),
## un salon de trois fauteuils. Liaisons : arches vers la rotonde (ouest) et l'atrium (nord), posées par le
## lot A ; baie vers la caisse et porte des toilettes (est).

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const LOT_C := "res://communes/casino_minuit/zones/lot_c.gd"
const H := 5.4
const B := {"x0": 10.0, "x1": 20.0, "z0": 12.0, "z1": 30.0}
const OUV := {"north": [{"at": 14.0, "w": 5.0, "h": 4.6}], "west": [{"at": 21.0, "w": 5.0, "h": 4.6}],
	"east": [{"at": 15.0, "w": 5.0, "h": 3.4}, {"at": 25.5, "w": 1.6, "h": 2.3}]}


static func construire(K) -> void:
	var LB = load(LOT_B)
	var L = load(LOT_C)
	K.zone_debut("R-CLUB")

	# --- enveloppe : marbre crème, tapis bordé d'or, boiseries claires ---
	L.sol(K, "marbre_creme", B.x0, B.x1, B.z0, B.z1)
	K.plan("moquette_d", 12, 18, 17, 25, 0.006)
	for s in [[12.0, 17.0, 18.0, 17.0], [12.0, 25.0, 18.0, 25.0], [12.0, 17.0, 12.0, 25.0], [18.0, 17.0, 18.0, 25.0]]:
		K.beam("or", Vector3(s[0], 0.008, s[1]), Vector3(s[2], 0.008, s[3]), 0.09, 0.012)
	L.plafond(K, "plafond_bas", B.x0, B.x1, B.z0, B.z1, H)
	LB.coque(K, B, H, "bois_clair", OUV)
	L.registres(K, 10.2, 12.2, 10.2, 29.8, {"n": [1.0, 0.0], "base": "marbre_rouge", "skip": [[6.3, 11.3]], "pil": [5.95, 11.65, 16.9]})
	L.registres(K, 10.2, 12.2, 19.8, 12.2, {"n": [0.0, 1.0], "base": "marbre_rouge", "skip": [[1.3, 6.3]], "pil": [0.95, 6.65]})
	L.registres(K, 19.8, 12.2, 19.8, 29.8, {"n": [-1.0, 0.0], "base": "marbre_rouge", "skip": [[0.3, 5.3], [12.5, 14.1]], "pil": [5.7, 11.2, 15.2]})
	L.registres(K, 10.2, 29.8, 19.8, 29.8, {"n": [0.0, -1.0], "base": "marbre_rouge", "pil": [5.9]})
	# La baie de la caisse, la porte des toilettes (battant ouvert vers le club).
	L.baie(K, {"axe": "x", "at": 20.0, "c": 15.0, "w": 5.0, "h": 3.4})
	LB.enseigne(K, "CAISSE", 19.74, 4.25, 15, -PI / 2.0, 2.6, 0.65, "neon", "ambre")
	L.baie(K, {"axe": "x", "at": 20.0, "c": 25.5, "w": 1.6, "h": 2.3, "jamb": 0.16, "gorge": false})
	LB.porte_ouverte(K, 19.9, 25.5, -1.0, 0.0, 1.6, 2.3)
	LB.enseigne(K, "Toilettes", 19.72, 2.95, 25.5, -PI / 2.0, 1.0, 0.3, "plaque")
	LB.enseigne(K, "Ascenseurs · Tables  ↑", 16.9, 4.25, 12.24, 0, 1.5, 0.36, "plaque")

	# --- le comptoir « Club Minuit » et le mur de cartes dorées (pièce maîtresse) ---
	K.box("laque_noire", 4.2, 1.02, 0.6, 13.1, 0.51, 27.9)
	K.box("marbre_noir", 4.44, 0.06, 0.84, 13.1, 1.05, 27.88)
	for i in 4:
		K.box("onyx", 0.93, 0.7, 0.02, 11.525 + i * 1.05, 0.55, 27.59)
	K.box("gorge", 4.2, 0.04, 0.03, 13.1, 0.14, 27.585)
	K.box("or", 4.3, 0.035, 0.05, 13.1, 0.96, 27.575)
	K.cyl("or", 0.02, 0.02, 4.0, 13.1, 0.22, 27.45, 8, 0, PI / 2.0)
	K.obstacle(10.95, 15.3, 27.5, 28.25, 0.0, 1.2)
	K.box("laque_rouge", 5.4, 2.5, 0.06, 13.3, 2.45, 29.77)
	for r in 6:
		for c in 13:
			var noir := (r * 5 + c * 3) % 11 == 0
			K.box("laque_noire" if noir else ("or_brosse" if (r + c) % 4 == 0 else "or"), 0.31, 0.2, 0.025, 10.98 + c * 0.387, 1.52 + r * 0.33, 29.72 - ((r + c) % 3) * 0.008, ((r * 7 + c) % 3 - 1) * 0.05)
	for y in [1.24, 3.66]:
		K.box("gorge", 5.5, 0.05, 0.04, 13.3, y, 29.73)
	K.texte("CLUB MINUIT", 3.6, 0.6, 13.3, 4.25, 29.68, PI, "neon", K.pal.or_clair)
	K.texte("Vos points valent de l'or", 2.4, 0.16, 13.3, 1.31, 27.57, PI)
	for x in [12.0, 14.2]:
		K.box("or", 0.28, 0.02, 0.2, x, 1.09, 27.8)
		K.box("laque_noire", 0.04, 0.26, 0.04, x + 0.5, 1.21, 27.95)
		K.box("gorge", 0.3, 0.2, 0.02, x + 0.5, 1.4, 27.95, 0.3)
	K.interaction("club_minuit", "Le comptoir du Club Minuit", 13.1, 1.2, 27.1, Vector3(4.2, 2.4, 1.0))
	K.places["club_hote"] = [Vector3(13.1, 0, 28.85), 0.0]
	K.places["club_comptoir"] = [[Vector3(12.0, 0, 26.92), PI], [Vector3(14.2, 0, 26.92), PI]]

	# --- trois distributeurs de billets, mur ouest ---
	var dab := []
	for z in [14.0, 15.3, 16.6]:
		var g := [10.76, z, PI / 2.0]
		LB.rbox(K, g, "laque_noire", 0.86, 2.05, 0.52, 0, 1.025, -0.26)
		LB.rbox(K, g, "or", 0.9, 0.05, 0.56, 0, 2.07, -0.26)
		LB.rbox(K, g, "or", 0.9, 0.08, 0.56, 0, 0.04, -0.26)
		LB.rbox(K, g, "or_brosse", 0.6, 0.05, 0.22, 0, 1.0, 0.06)
		LB.rbox(K, g, "acier", 0.34, 0.03, 0.02, 0, 0.82, 0.005)
		LB.rbox(K, g, "gorge", 0.7, 0.03, 0.02, 0, 1.95, 0.005)
		LB.rbox(K, g, "ecran_bleu", 0.52, 0.39, 0.02, 0, 1.42, 0.01)
		K.texte("BILLETS", 0.4, 0.07, 10.785, 1.54, z, PI / 2.0)
		K.texte("Retrait · Solde · Carte Club", 0.44, 0.045, 10.785, 1.4, z, PI / 2.0, "grave", K.pal.ivoire)
		LB.rsolide(K, g, 0.9, 2.1, 0.57, 0, -0.26)
		dab.append([Vector3(11.4, 0, z), -PI / 2.0 + PI])
	K.places["club_dab"] = dab
	K.interaction("distributeur", "Les distributeurs de billets", 11.1, 1.3, 15.3, Vector3(0.9, 2.4, 4.2))
	LB.enseigne(K, "BILLETS", 10.24, 2.75, 15.3, PI / 2.0, 1.9, 0.57, "neon", "ambre")

	# --- deux bornes du club, mur est ---
	var bornes := []
	for z in [19.9, 22.1]:
		var g := [19.42, z, -PI / 2.0]
		LB.rbox(K, g, "laque_noire", 0.5, 1.0, 0.3, 0, 0.5, -0.12)
		LB.rbox(K, g, "laque_noire", 0.56, 0.7, 0.08, 0, 1.3, -0.14)
		LB.rbox(K, g, "or", 0.6, 0.04, 0.34, 0, 1.0, -0.12)
		LB.rbox(K, g, "or", 0.56, 0.05, 0.3, 0, 0.03, -0.12)
		LB.rbox(K, g, "bordeaux", 0.42, 0.56, 0.02, 0, 1.3, -0.09)
		K.texte("CLUB MINUIT", 0.36, 0.06, 19.32, 1.42, z, -PI / 2.0, "neon")
		K.texte("Vos points", 0.3, 0.045, 19.32, 1.22, z, -PI / 2.0, "grave", K.pal.ivoire)
		LB.rsolide(K, g, 0.56, 1.7, 0.35, 0, -0.12)
		bornes.append([Vector3(18.87, 0, z), -PI / 2.0])
	K.places["club_bornes"] = bornes

	# --- le salon : trois fauteuils autour d'une table basse ---
	K.cyl("marbre_noir", 0.36, 0.36, 0.05, 17.7, 0.45, 27.7, 16)
	K.cyl("or", 0.06, 0.2, 0.42, 17.7, 0.21, 27.7, 10)
	K.rond(17.7, 27.7, 0.38, 0.0, 0.6)
	var salon := []
	for p in [[-0.65, 1.42, 0.0], [0.6, 1.42, 0.0], [1.55, 0.0, PI / 2.0]]:
		salon.append(L.fauteuil(K, 17.7 + p[0], 27.7 + p[1], p[2]))
	K.places["club_salon"] = salon

	# --- décor, lumière ---
	LB.palmier(K, 10.85, 24.4, {"seed": 4})
	LB.palmier(K, 19.15, 18.75, {"seed": 13})
	LB.topiaire(K, 10.8, 12.8, 2.0)
	K.statue(10.78, 29.2, 1.9, 0.7, PI, "statue_or", "corne")
	K.lustre_anneau(15, 3.5, 21, 1.35, 1.3)
	K.lustre_anneau(13.3, 3.7, 26.6, 0.8, 1.3)
	K.lumiere(15, 3.4, 21, K.pal.lumiere, 1.5, 13.0)
	K.lumiere(13.3, 3.2, 26.4, K.pal.ambre, 1.2, 8.0)
	var duos := []
	for d in [[14.2, 19.2, 0.6], [16.4, 23.3, 2.1]]:
		var dx: float = sin(d[2]) * 0.55
		var dz: float = cos(d[2]) * 0.55
		duos.append([Vector3(d[0] - dx, 0, d[1] - dz), d[2] + PI])
		duos.append([Vector3(d[0] + dx, 0, d[1] + dz), d[2]])
	K.places["club_duos"] = duos
	K.places["club_vigiles"] = [[Vector3(11.0, 0, 18.6), -PI / 2.0], [Vector3(16.9, 0, 12.9), PI]]
	K.zone_fin()
