extends RefCounted
## Lot D, zone R-SERVICE (js/zones/d-r-service.js) : le couloir du personnel du rez-de-chaussée, [36, 40] ×
## [-4 ; 26,5], derrière le mur est de la fosse. Au nord la cage de l'escalier du personnel (escalier_staff.gd),
## au sud l'ascenseur de service ASC-S (portes closes). Les portes : L25 vers la fosse (posée par minuit.gd,
## close sous le seuil des coulisses), L15 vers l'arrière-caisse (posée par arriere.gd). Côté couloir, le
## rappel de scène, le miroir et la pointeuse ; les casiers des extras, le portant des vestes, les chariots.

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"
const ASC := "res://communes/casino_minuit/zones/couloir.gd"


static func construire(K) -> void:
	var D = load(LOT_D)
	var H: float = D.H
	K.zone_debut("R-SERVICE")

	# --- enveloppe ---
	K.plan("lino", 36, 40, -4, 26.5, 0.0)
	K.dalle(36, 40, -4, 26.5, 0.0)
	K.plan("brut", 36, 40, -4, 26.5, H, false)
	D.mur_d(K, 36.1, -4, 36.1, 26.5, H, 1, 0, [{"at": 2.0, "w": 1.4}, {"at": 24.0, "w": 1.4}], -4.0)
	D.mur_d(K, 39.9, -4, 39.9, 26.5, H, -1, 0, [], -4.0)
	D.mur_d(K, 36, -3.9, 40, -3.9, H, 0, 1, [{"at": 38.0, "w": 1.8, "h": 2.3}], 36.0)
	D.mur_d(K, 36, 26.4, 40, 26.4, H, 0, -1, [{"at": 38.0, "w": 2.04, "h": 2.42}], 36.0, "beton", false)
	load(ASC).ascenseur(K, D, "RDC")

	# --- côté couloir de L25 : le rappel de scène, le miroir, la pointeuse, le planning ---
	D.plaque(K, "perso", 35.775, 1.62, 2, -PI / 2.0, 0.5)
	D.plaque(K, "scene", 36.212, 2.5, 2, PI / 2.0, 1.5)
	K.box("miroir", 0.012, 1.5, 0.55, 36.212, 1.35, 0.55)
	D.bx(K, "grisC", 0.03, 1.56, 0.61, 36.205, 1.35, 0.55)
	D.bx(K, "gris", 0.1, 0.36, 0.3, 36.26, 1.35, 3.6)
	D.bx(K, "ecranCompte", 0.006, 0.1, 0.22, 36.312, 1.42, 3.6)
	D.cy(K, "blanc", 0.18, 0.18, 0.02, 36.22, 2.05, 3.6, 16, 0, PI / 2.0)
	D.affiche(K, "affiche", "bleu", 1.1, 0.82, 36.212, 1.6, 5.2, PI / 2.0)
	D.affiche(K, "liege", "", 1.1, 0.82, 36.212, 1.6, 6.6, PI / 2.0)
	D.pochoir(K, "SALLE DE JEU", 36.212, 2.5, 4.9, PI / 2.0, 0.24)
	D.pochoir(K, "ARRIÈRE-CAISSE", 36.212, 2.55, 24, PI / 2.0, 0.24)
	D.plaque(K, "acces", 36.212, 1.75, 22.75, PI / 2.0, 0.6)
	D.plaque(K, "badge", 36.212, 1.6, 22.75, PI / 2.0, 0.6)
	D.bx(K, "ledV", 0.02, 0.18, 0.12, 36.212, 1.3, 23.05)
	D.place(K, "d_service", 36.75, 0.0, 0.55, PI / 2.0, 0.0)

	# --- réseaux, réglettes, lumière ---
	D.reseaux(K, "z", 36.75, -3.7, 26.2)
	for z in [-1.5, 3.5, 8.5, 13.5, 18.5, 23.5]:
		D.neon(K, 38.25, z)
	K.lumiere(38, 3.0, 3, Color("#cfe4ff"), 1.2, 12.0)
	K.lumiere(38, 3.0, 20, Color("#cfe4ff"), 1.2, 12.0)

	# --- marquages au sol : la voie jaune du chariot de fonds, les zébras ---
	D.ligne(K, "jaune", 36.25, 2, 38, 2, 0.1)
	D.ligne(K, "jaune", 38, 1.95, 38, 24.6, 0.1)
	D.ligne(K, "jaune", 36.25, 24, 37.95, 24, 0.1)
	D.hachure_sol(K, 2.3, 0.14, 12, 38, 24.65)
	D.hachure_sol(K, 1.8, 0.14, 10, 38, -3.6)
	D.pochoir_sol(K, "ASCENSEUR", 38, 21.6, PI, 0.42)
	D.pochoir_sol(K, "ESCALIER", 38, 0.2, 0, 0.36)
	D.sortie(K, 38, 2.6, -3.778, 0)
	D.pochoir(K, "ESCALIER", 36.85, 2.0, -3.788, 0, 0.2)
	D.pochoir(K, "MEZZANINE", 39.25, 2.2, -3.788, 0, 0.16)
	D.pochoir(K, "B1", 39.25, 1.9, -3.788, 0, 0.2)
	D.pochoir(K, "RDC", 36.212, 2.0, 25.55, PI / 2.0, 0.4)

	# --- pare-chocs, mobilier technique ---
	for s in [[-3.8, 1.2], [2.8, 23.2], [24.8, 26.3]]:
		D.bx(K, "caout", 0.05, 0.16, s[1] - s[0], 36.225, 0.85, (s[0] + s[1]) / 2.0)
	D.bx(K, "caout", 0.05, 0.16, 30.1, 39.775, 0.85, 11.25)
	D.chariot(K, 39.3, 8.2, 0, "linge")
	D.chariot(K, 39.3, 17.6, 0, "plateau", [["blanc", 0.5, 0.06, 0.7, 0, 1.03, 0], ["grisC", 0.3, 0.16, 0.3, 0.1, 1.11, -0.2], ["carton", 0.4, 0.3, 0.5, 0, 0.73, 0.2], ["carton", 0.36, 0.26, 0.4, 0.05, 0.71, -0.3]])
	D.extincteur(K, 39.79, 0.4, -PI / 2.0)
	D.extincteur(K, 39.79, 15.4, -PI / 2.0)
	D.armoire(K, 39.8, 11.4, -PI / 2.0)
	D.armoire(K, 39.8, 12.2, -PI / 2.0, 0.6, 0.8)
	D.affiche(K, "affiche", "vert", 0.6, 0.6, 39.788, 1.6, 2.4, -PI / 2.0)
	# Les casiers des extras (mur est), le banc, le portant des vestes.
	D.casiers(K, 39.55, 5.4, -PI / 2.0, 8)
	D.place(K, "d_service", 38.7, 0.0, 5.0, -PI / 2.0, 0.0)
	D.bx(K, "bois", 0.36, 0.05, 1.5, 36.42, 0.45, 10.2)
	for dz in [-0.6, 0.6]:
		K.box("acier", 0.3, 0.43, 0.04, 36.42, 0.215, 10.2 + dz)
	K.obstacle(36.2, 36.6, 9.45, 10.95, 0.0, 0.5)
	D.place(K, "d_service_assis", 36.5, 0.47, 9.8, -PI / 2.0, 0.0)
	K.box("acier", 0.03, 0.03, 1.8, 36.5, 1.75, 16.2)
	for z in [15.35, 17.05]:
		K.box("acier", 0.03, 1.75, 0.03, 36.5, 0.875, z)
	var vestes := ["bordeaux", "bordeaux", "noir", "bordeaux", "blanc", "bordeaux", "noir", "bordeaux"]
	for i in vestes.size():
		D.bx(K, vestes[i], 0.42, 0.8 + (i % 3) * 0.1, 0.06, 36.5, 1.33 - (i % 3) * 0.05, 15.5 + i * 0.2)
	K.obstacle(36.25, 36.75, 15.3, 17.1)
	D.plaque(K, "chariots", 39.788, 2.0, 14.2, -PI / 2.0, 0.9)
	D.bx(K, "blanc", 0.34, 1.0, 0.34, 39.6, 0.5, 20.6)
	D.cy(K, "bleu", 0.13, 0.13, 0.36, 39.6, 1.2, 20.6, 10)
	K.obstacle(39.4, 39.8, 20.4, 20.8)
	D.dome(K, 38, H, 14)
	D.dome(K, 37, H, 25.2)
	K.zone_fin()
	# Le croupier qui va prendre son service : de la pointeuse à la porte de la fosse, et retour.
	K.places["d_service_tour"] = [Vector3(37.4, 0, 22.0), Vector3(37.4, 0, 3.0), Vector3(37.0, 0, 0.9), Vector3(37.4, 0, 3.0)]
