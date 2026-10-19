extends RefCounted
## Lot C, zone R-CAGE (js/zones/c-cage.js) : la caisse [20, 36] × [12, 21], rez-de-chaussée. La salle publique
## z ∈ [12, 18], la grille de caisse à cinq guichets sur z = 18 (arcades de laque noire, barreaux d'or,
## fronton à horloge sans aiguilles), les postes des caissiers derrière, la file serpentine entre potelets.
## On y change ses jetons (minuit.gd, « caisse ») : un jeton vaut un crédit. Liaisons : la fosse (nord), le
## club (ouest), la porte blindée du personnel L14 vers l'arrière-caisse (sud ; posée par minuit.gd, close
## sous le seuil des coulisses).

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const LOT_C := "res://communes/casino_minuit/zones/lot_c.gd"
const H := 5.4
const B := {"x0": 20.0, "x1": 36.0, "z0": 12.0, "z1": 21.0}
const OUV := {"north": [{"at": 28.0, "w": 8.0, "h": 3.6}], "west": [{"at": 15.0, "w": 5.0, "h": 3.4}], "south": [{"at": 31.5, "w": 1.2, "h": 2.2}]}
const XS := [22.8, 25.4, 28.0, 30.6, 33.2]
const ZG := 18.0


static func construire(K) -> void:
	var LB = load(LOT_B)
	var L = load(LOT_C)
	K.zone_debut("R-CAGE")

	# --- enveloppe ---
	L.sol(K, "damier", B.x0, B.x1, B.z0, B.z1)
	L.plafond(K, "plafond_bas", B.x0, B.x1, B.z0, B.z1, H)
	LB.coque(K, B, H, "laque_noire", OUV)
	L.registres(K, 20.2, 12.2, 35.8, 12.2, {"n": [0.0, 1.0], "base": "marbre_noir", "skip": [[3.8, 11.8]], "pil": [1.9, 13.7], "pil_mat": "laque_rouge"})
	L.registres(K, 35.8, 12.2, 35.8, 17.7, {"n": [-1.0, 0.0], "base": "marbre_noir", "pil": [0.45, 5.1], "pil_mat": "laque_rouge"})
	# Le claustra rétroéclairé du mur est.
	K.box("gorge", 0.02, 2.5, 3.6, 35.74, 2.55, 14.95)
	K.box("treillis", 0.02, 2.5, 3.6, 35.7, 2.55, 14.95)
	for y in [3.83, 1.27]:
		K.box("or", 0.1, 0.06, 3.72, 35.7, y, 14.95)

	# --- la grille de caisse (pièce maîtresse) ---
	K.box("marbre_noir", 13.4, 0.07, 0.6, 28, 1.045, ZG)
	K.box("laque_noire", 13.4, 1.0, 0.44, 28, 0.5, ZG)
	K.box("gorge", 13.0, 0.04, 0.03, 28, 0.13, ZG - 0.23)
	K.box("or", 13.4, 0.04, 0.05, 28, 0.95, ZG - 0.235)
	K.obstacle(20.2, 35.8, ZG - 0.3, ZG + 0.3, 0.0, H)
	for e in [20.75, 35.25]:
		K.box("laque_noire", 1.1, 2.75, 0.36, e, 1.375, ZG)
		K.box("gorge", 0.9, 1.5, 0.02, e, 1.85, ZG - 0.19)
		K.box("treillis", 0.9, 1.5, 0.02, e, 1.85, ZG - 0.22)
	for i in 6:
		var x := 21.5 + i * 2.6
		K.box("laque_noire", 0.4, 2.75, 0.4, x, 1.375, ZG)
		K.box("or", 0.48, 0.1, 0.48, x, 2.7, ZG)
		K.box("or", 0.46, 0.08, 0.46, x, 1.12, ZG)
		K.lanterne(x, 3.05, ZG - 0.42, 0.42)
	# Le tympan des arcades : un voile de laque percé de cinq demi-cercles.
	L.voile(K, "laque_noire", "z", ZG, 20.2, 35.8, func(a: float) -> float:
		var y := 2.75
		for xc in XS:
			var d: float = absf(a - xc)
			if d < 1.3:
				y = maxf(y, 2.75 + sqrt(1.69 - d * d))
		return y, func(_a: float) -> float: return H, {"n": 78, "t": 0.32, "dessous": true})
	for i in XS.size():
		var xc: float = XS[i]
		for k in range(1, 8):
			var a := k * PI / 8.0
			K.beam("or", Vector3(xc, 2.78, ZG), Vector3(xc + cos(a) * 1.05, 2.75 + sin(a) * 1.05, ZG), 0.025, 0.025)
		# L'archivolte d'or, en seize voussoirs.
		for k in 16:
			var a := k * PI / 16.0
			var b := (k + 1) * PI / 16.0
			K.beam("or", Vector3(xc + cos(a) * 1.075, 2.75 + sin(a) * 1.075, ZG), Vector3(xc + cos(b) * 1.075, 2.75 + sin(b) * 1.075, ZG), 0.42, 0.05)
		K.cyl("or", 0.16, 0.16, 0.05, xc, 2.78, ZG, 12, PI / 2.0)
		# Les barreaux ; les cinq du milieu s'arrêtent au-dessus du passe-monnaie.
		for b in range(-7, 8):
			var y0 := 1.5 if absi(b) <= 2 else 1.08
			K.cyl("or", 0.012, 0.012, 2.75 - y0, xc + b * 0.154, (2.75 + y0) / 2.0, ZG, 5)
		K.box("or", 2.2, 0.035, 0.035, xc, 2.74, ZG)
		K.box("or", 0.72, 0.035, 0.05, xc, 1.5, ZG)
		K.box("or", 2.2, 0.03, 0.03, xc, 2.12, ZG)
		K.box("onyx", 2.0, 0.66, 0.02, xc, 0.55, ZG - 0.23)
		K.box("or", 0.5, 0.012, 0.3, xc, 1.087, ZG)
		K.box("acier", 0.34, 0.16, 0.26, xc + 0.72, 1.16, ZG + 0.12)
		for k in 3:
			K.cyl(["laque_rouge", "jeton_vert", "jeton_bleu"][k], 0.03, 0.03, 0.05 + k * 0.03, xc - 0.7 + k * 0.08, 1.105 + k * 0.015, ZG + 0.1, 8)
		K.texte("GUICHET %d" % (5 - i), 0.62, 0.15, xc, 4.28, ZG - 0.2, PI)
		K.sph("ampoule", 0.07, xc, 3.5, ZG, 1.2)
		K.cyl("or", 0.006, 0.006, 0.5, xc, 3.8, ZG, 4)
	K.box("or", 15.6, 0.05, 0.06, 28, 4.12, ZG - 0.18)
	K.box("gorge", 15.6, 0.03, 0.03, 28, 4.06, ZG - 0.175)
	K.box("or", 15.6, 0.05, 0.06, 28, 5.24, ZG - 0.18)
	# Le fronton : une horloge sans aiguilles (pas d'heure au casino), les enseignes.
	var hz := ZG - 0.2
	K.cyl("creme", 0.5, 0.5, 0.03, 28, 4.72, hz, 32, PI / 2.0)
	K.tore("or", 0.5, 0.03, K.xf(28, 4.72, hz - 0.02, PI / 2.0), 32)
	for k in 12:
		var a := k * PI / 6.0
		K.texte(["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"][k], 0.14, 0.08, 28 - sin(a) * 0.33, 4.72 + cos(a) * 0.33, hz - 0.025, PI, "grave", K.pal.laque_noire)
	K.sph("or", 0.035, 28, 4.72, hz - 0.03)
	LB.enseigne(K, "CAISSE", 24.1, 4.78, ZG - 0.2, PI, 3.2, 0.8, "neon", "ambre")
	LB.enseigne(K, "CHANGE", 31.9, 4.78, ZG - 0.2, PI, 3.2, 0.8, "neon", "ambre")
	K.texte("1 jeton = 1 crédit", 1.8, 0.2, 28, 0.6, ZG - 0.245, PI, "neon", K.pal.or_clair)
	K.interaction("caisse", "La caisse : changer ses jetons", 28, 1.3, ZG - 0.75, Vector3(13.0, 2.6, 1.0))

	# --- derrière la grille : râteliers à jetons contre le mur sud, porte du personnel ---
	var mats := ["laque_rouge", "or", "jeton_vert", "jeton_bleu", "jeton_ivoire"]
	var xr := [22.6, 25.4, 28.2, 34.3]
	for g in xr.size():
		var x: float = xr[g]
		K.box("laque_noire", 2.3, 2.3, 0.3, x, 1.15, 20.63)
		K.box("or", 2.36, 0.05, 0.34, x, 2.32, 20.63)
		for r in 4:
			K.box("gorge", 2.1, 0.02, 0.02, x, 0.42 + r * 0.5, 20.47)
			for k in 9:
				K.box(mats[(k + r * 2 + g) % 5], 0.19, 0.2 + ((k * 3 + r) % 3) * 0.05, 0.14, x - 0.92 + k * 0.23, 0.55 + r * 0.5, 20.46)
	K.obstacle(21.4, 29.4, 20.45, 20.8, 0.0, 2.4)
	K.obstacle(33.1, 35.5, 20.45, 20.8, 0.0, 2.4)
	K.box("or", 1.3, 0.06, 0.08, 31.5, 2.23, 20.92)
	LB.enseigne(K, "RÉSERVÉ AU PERSONNEL", 31.5, 2.5, 20.88, PI, 0.9, 0.16, "plaque")
	K.lumiere(28, 3.3, 19.3, K.pal.lumiere, 1.5, 12.0)

	# --- salle publique : file serpentine entre potelets, banquette, vigile ---
	L.potelets(K, [[29.6, 13.3], [31.4, 13.3], [33.2, 13.3], [35.0, 13.3], [35.0, 14.75], [35.0, 16.2], [33.2, 16.2], [31.4, 16.2], [29.6, 16.2]])
	L.potelets(K, [[29.6, 14.75], [31.5, 14.75], [33.4, 14.75]])
	var file := []
	for q in [[30.0, 15.5, PI / 2.0], [30.8, 15.5, PI / 2.0], [31.6, 15.5, PI / 2.0], [32.4, 15.5, PI / 2.0], [33.2, 15.5, PI / 2.0], [34.35, 14.75, PI], [33.2, 14.0, -PI / 2.0], [32.4, 14.0, -PI / 2.0]]:
		file.append([Vector3(q[0], 0, q[1]), q[2]])
	K.places["cage_file"] = file
	LB.enseigne(K, "File d'attente  →", 29.52, 1.25, 14, -PI / 2.0, 0.62, 0.155, "plaque")
	K.box("or", 0.03, 1.1, 0.03, 29.6, 0.6, 14)
	var bancs: Array = L.banc(K, 22.1, 12.74, PI, 2, {"mat": "marbre_noir"})
	K.places["cage_bancs"] = bancs
	LB.topiaire(K, 35.2, 17.1, 1.8)
	LB.palmier(K, 20.9, 17.1, {"seed": 2})
	K.lustre_anneau(25, 3.6, 14.8, 1.3, 1.2)
	K.lanterne(32.3, 3.3, 12.9, 1.0, 1.4)
	K.lumiere(25, 3.4, 14.8, K.pal.lumiere, 1.3, 11.0)
	# Les places : un caissier derrière chaque guichet, un client devant, le vigile de la caisse.
	var caissiers := []
	var clients := []
	for xc in XS:
		caissiers.append([Vector3(xc, 0, ZG + 0.85), 0.0])
		clients.append([Vector3(xc, 0, ZG - 0.76), PI])
	K.places["cage_caissiers"] = caissiers
	K.places["cage_clients"] = clients
	K.places["cage_vigile"] = [Vector3(24, 0, 13.5), PI]
	K.places["cage_duos"] = [[Vector3(22.1, 0, 15.3), 1.2 + PI], [Vector3(23.1, 0, 15.9), 1.2]]
	K.zone_fin()
