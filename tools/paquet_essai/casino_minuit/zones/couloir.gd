extends RefCounted
## Lot D, zone B-COULOIR (js/zones/d-b-couloir.js) : l'épine de service du sous-sol (y = -5), [32, 36] ×
## [-16, 30], avec le palier de l'escalier du personnel [36, 40] × [-4, 0] au nord-est et celui de
## l'ascenseur de service ASC-S [36, 40] × [22 ; 26,5] au sud-est (sa cabine : ascenseurs.gd).
## Le long du mur ouest, les portes du comptage (S03), la grille du sas du coffre (S04), la surveillance (S07)
## et les vestiaires (S09), ouvertes ; au nord, les lanières du quai (S10). Bandes de guidage au sol, une
## couleur par destination ; chariots, armoires, extincteurs et caméras le long du mur est.

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"


static func construire(K) -> void:
	var D = load(LOT_D)
	var H: float = D.H
	K.zone_debut("B-COULOIR")
	K.zone.position.y = D.Y

	# --- enveloppe ---
	for r in [[32.0, 36.0, -16.0, 30.0], [36.0, 40.0, -4.0, 0.0], [36.0, 40.0, 22.0, 26.5]]:
		K.plan("lino", r[0], r[1], r[2], r[3], 0.0)
		K.dalle(r[0], r[1], r[2], r[3], 0.0)
		K.plan("brut", r[0], r[1], r[2], r[3], H, false)
	D.mur_d(K, 32.1, -16, 32.1, 30, H, 1, 0, [{"at": -10.0, "w": 1.4}, {"at": 3.0, "w": 1.2}, {"at": 14.0, "w": 2.0, "h": 2.4}, {"at": 24.0, "w": 1.6}], -16.0)
	D.mur_d(K, 35.9, -16, 35.9, -4, H, -1, 0, [], -16.0)
	D.mur_d(K, 35.9, 0, 35.9, 22, H, -1, 0, [], 0.0)
	D.mur_d(K, 35.9, 26.5, 35.9, 30, H, -1, 0, [], 26.5)
	D.mur_d(K, 32, 29.9, 36, 29.9, H, 0, -1, [], 32.0)
	# Le palier de l'escalier : la baie de 1,8 m vers la cage, au nord.
	D.mur_d(K, 36, -3.9, 40, -3.9, H, 0, 1, [{"at": 38.0, "w": 1.8, "h": 2.3}], 36.0)
	D.mur_d(K, 39.9, -4, 39.9, 0, H, -1, 0, [], -4.0)
	D.mur_d(K, 36, -0.1, 40, -0.1, H, 0, -1, [], 36.0)
	# Le palier de l'ascenseur de service.
	D.mur_d(K, 36, 22.1, 40, 22.1, H, 0, 1, [], 36.0)
	D.mur_d(K, 39.9, 22, 39.9, 26.5, H, -1, 0, [], 22.0)
	D.mur_d(K, 36, 26.4, 40, 26.4, H, 0, -1, [{"at": 38.0, "w": 2.04, "h": 2.42}], 36.0, "beton", false)
	ascenseur(K, D, "B1")

	# --- les portes du mur ouest (ouvertes), les lanières du quai ---
	for id in ["S03", "S04", "S07", "S09"]:
		D.porte(K, id)
	K.box("acier", 3.6, 0.08, 0.1, 34, H - 0.2, -16)
	for i in 13:
		K.box("verre", 0.3, H - 0.3, 0.012, 32.32 + i * 0.28, (H - 0.3) / 2.0 + 0.06, -16 + (0.02 if i % 2 else -0.02))
	D.pochoir(K, "QUAI", 35.788, 2.3, -14.4, -PI / 2.0, 0.3)
	D.pochoir(K, "CUISINE", 35.788, 1.85, -14.4, -PI / 2.0, 0.3)

	# --- signalétique des portes (mur ouest, lue depuis l'est) ---
	var WX := 32.212
	var E := PI / 2.0
	D.pochoir(K, "COMPTAGE", WX, 2.72, 24, E, 0.26)
	D.plaque(K, "acces", WX, 1.78, 25.45, E, 0.62)
	D.plaque(K, "deux", WX, 1.64, 25.45, E, 0.62)
	D.bx(K, "ledV", 0.02, 0.18, 0.12, WX, 1.3, 25.2)
	D.pochoir(K, "COFFRE", WX, 2.95, 14, E, 0.3)
	D.pochoir(K, "SAS", WX, 2.0, 16.1, E, 0.42)
	D.plaque(K, "video", WX, 1.5, 16.1, E, 0.62)
	D.pochoir(K, "SURVEILLANCE", WX, 2.72, 3.6, E, 0.22)
	D.plaque(K, "badge", WX, 1.7, 4.3, E, 0.56)
	D.bx(K, "ledV", 0.02, 0.18, 0.12, WX, 1.3, 3.95)
	D.pochoir(K, "VESTIAIRES", WX, 2.72, -10, E, 0.24)
	D.pochoir(K, "PAUSE", WX, 2.0, -8.3, E, 0.24)
	# Le palier de l'ascenseur, le palier de l'escalier.
	D.pochoir(K, "B1", 38.6, 1.95, 22.212, 0, 1.0)
	D.pochoir(K, "COFFRE", 37.05, 2.25, 22.212, 0, 0.26)
	D.pochoir(K, "COMPTAGE", 37.05, 1.9, 22.212, 0, 0.2)
	D.extincteur(K, 39.79, 24.6, -PI / 2.0)
	D.pochoir(K, "ESCALIER", 36.85, 2.0, -3.788, 0, 0.2)
	D.pochoir(K, "RDC", 39.2, 2.0, -3.788, 0, 0.26)
	D.sortie(K, 38, 2.6, -3.778, 0)
	D.pochoir(K, "B1", 38, 1.9, -0.212, PI, 0.9)
	D.hachure_sol(K, 1.8, 0.14, 10, 38, -3.6)

	# --- réseaux et réglettes au plafond, lumière ---
	D.reseaux(K, "z", 32.78, -15.7, 29.6, H - 0.24, true)
	for z in [-13.0, -8.0, -3.0, 2.0, 7.0, 12.0, 17.0, 22.0, 27.0]:
		D.neon(K, 34.2, z)
	D.neon(K, 38, -2, "x")
	D.neon(K, 38, 24.2, "x")
	K.lumiere(34.4, 3.0, 20, Color("#cfe4ff"), 1.3, 14.0)
	K.lumiere(34.4, 3.0, 0, Color("#cfe4ff"), 1.3, 14.0)
	K.lumiere(34.4, 3.0, -12, Color("#cfe4ff"), 1.1, 10.0)

	# --- bandes de guidage au sol (jaune : comptage et coffre ; rouge : surveillance ; blanc : vestiaires ;
	# bleu : cuisine et quai) ---
	var L := func(k: String, pts: Array) -> void:
		for i in pts.size() - 1:
			D.ligne(K, k, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 0.09)
	L.call("jaune", [[37.4, 24.3], [33.45, 24.3], [33.45, 14], [32.3, 14]])
	L.call("jaune", [[33.45, 24], [32.3, 24]])
	L.call("rouge", [[37.4, 24.05], [33.7, 24.05], [33.7, 3], [32.3, 3]])
	L.call("blanc", [[37.4, 23.8], [33.95, 23.8], [33.95, -10], [32.3, -10]])
	L.call("bleu", [[37.4, 23.55], [34.2, 23.55], [34.2, -15.8]])
	L.call("blanc", [[37.4, -2.2], [33.95, -2.2]])
	L.call("bleu", [[37.4, -1.95], [34.2, -1.95]])
	D.hachure_sol(K, 2.3, 0.14, 12, 38, 24.65)
	D.hachure_sol(K, 2.3, 0.14, 12, 32.55, 14, PI / 2.0)
	D.pochoir_sol(K, "COFFRE", 33.05, 17.2, -PI / 2.0, 0.3)
	D.pochoir_sol(K, "COMPTAGE", 33.05, 21.6, -PI / 2.0, 0.26)

	# --- pare-chocs muraux ---
	for s in [[-15.8, -10.8], [-9.2, 2.3], [3.7, 12.9], [15.1, 23.1], [24.9, 29.7]]:
		D.bx(K, "caout", 0.05, 0.16, s[1] - s[0], 32.225, 0.85, (s[0] + s[1]) / 2.0)
	for s in [[-15.8, -4.1], [0.1, 21.9], [26.6, 29.7]]:
		D.bx(K, "caout", 0.05, 0.16, s[1] - s[0], 35.775, 0.85, (s[0] + s[1]) / 2.0)

	# --- mobilier technique le long du mur est ---
	D.chariot(K, 35.25, 19.3, 0, "fonds")
	D.chariot(K, 35.3, -12.6, 0, "linge")
	D.chariot(K, 35.3, -9.4, 0, "plateau", [["carton", 0.5, 0.34, 0.5, 0, 0.75, -0.25], ["carton", 0.46, 0.3, 0.44, 0.02, 0.73, 0.3], ["carton", 0.5, 0.3, 0.6, 0, 1.15, 0]])
	D.extincteur(K, 35.79, 10, -PI / 2.0)
	D.extincteur(K, 35.79, -6.2, -PI / 2.0)
	D.extincteur(K, 32.21, 20.6, PI / 2.0)
	D.armoire(K, 35.8, 5.6, -PI / 2.0)
	D.armoire(K, 35.8, 6.5, -PI / 2.0)
	D.armoire(K, 35.8, 7.3, -PI / 2.0, 0.55, 0.7, 1.45)
	D.affiche(K, "liege", "", 1.2, 0.9, 35.788, 1.55, 13.4, -PI / 2.0)
	D.affiche(K, "affiche", "bleu", 1.2, 0.9, 35.788, 1.55, 14.8, -PI / 2.0)
	D.plaque(K, "chariots", 35.788, 2.05, 17, -PI / 2.0, 0.9)
	D.plaque(K, "fumer", 35.788, 2.05, -11, -PI / 2.0, 0.7)
	D.bx(K, "vert", 0.56, 0.9, 0.7, 35.42, 0.5, -15.1)
	K.obstacle(35.1, 35.74, -15.5, -14.7)
	for i in 3:
		D.bx(K, "bleu", 0.4, 0.28, 0.4, 32.5, 0.14 + i * 0.29, -14.9)
	K.obstacle(32.3, 32.7, -15.1, -14.7)
	D.bx(K, "noir", 0.1, 0.24, 0.16, 35.75, 1.4, 21.2)
	for z in [24.0, 14.0, 3.0, -10.0]:
		D.dome(K, 34.9, H, z)
	K.zone_fin()

	# Le rondier de l'épine : du palier de l'ascenseur au quai, et retour.
	K.places["d_couloir_ronde"] = [Vector3(34.6, D.Y, 27.5), Vector3(34.6, D.Y, 0.0), Vector3(34.6, D.Y, -14.5), Vector3(34.6, D.Y, 0.0)]


## Le palier de l'ascenseur de service ASC-S (mur z = 26,4, porte centrée x = 38) : le chambranle, le bouton
## d'appel et l'indicateur d'étage ; la cabine monte les transports de fonds (ascenseurs.gd).
static func ascenseur(K, D, etage: String) -> void:
	for s in [-1.0, 1.0]:
		K.box("acier", 1.0, 2.42, 0.05, 38 + s * 0.5, 1.21, 26.32)
		K.box("acier", 0.09, 2.5, 0.2, 38 + s * 1.065, 1.25, 26.3)
	K.box("acier", 2.22, 0.09, 0.2, 38, 2.465, 26.3)
	D.bx(K, "grisF", 0.12, 0.24, 0.03, 39.3, 1.25, 26.29)
	D.cy(K, "ledA", 0.03, 0.03, 0.02, 39.3, 1.3, 26.27, 10, PI / 2.0)
	D.bx(K, "noir", 0.5, 0.2, 0.03, 38, 2.75, 26.29)
	K.texte(etage, 0.4, 0.14, 38, 2.75, 26.27, PI, "grave", Color("#FFB347"))
	D.hachure_sol(K, 2.3, 0.14, 12, 38, 26.15)
