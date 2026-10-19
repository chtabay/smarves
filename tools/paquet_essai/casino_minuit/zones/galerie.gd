extends RefCounted
## Lot A, zone M-GALERIE (js/zones/a-galerie.js) : la galerie en balcon de la mezzanine (y = 6), ouverte sur
## la nef. Dalles : nord [-18, 18] × [-30 ; -25,5] · ouest [-18, -14] × [-25,5 ; 12] · est [14, 18] × [-25,5 ; 12]
## · pont sud [-14, 14] × [9, 12]. Le vide sur la nef n'a pas de dalle. La zone bâtit aussi le plafond de la
## nef (y 13, caissons de 4 × 4 m) et les garde-corps. Les salles de la mezzanine (jardin d'hiver, lounge,
## restaurant, boutiques) viendront avec les lots B et C : leurs baies sont fermées.

const Y := 6.0
const H := 7.0


static func construire(K) -> void:
	K.zone_debut("M-GALERIE")

	# --- dalles (avec leur épaisseur, vue d'en bas), tapis de circulation ---
	for d in [[-18.0, 18.0, -30.0, -25.5], [-18.0, -14.0, -25.5, 12.0], [14.0, 18.0, -25.5, 12.0], [-14.0, 14.0, 9.0, 12.0]]:
		K.plan("marbre_creme", d[0], d[1], d[2], d[3], Y)
		K.dalle(d[0], d[1], d[2], d[3], Y)
	# Les têtes d'escalier arrivent dans la dalle nord : on y passe, la dalle commence à z = -25,5.
	for d in [[-17.0, 17.0, -28.7, -26.7], [-17.0, -15.0, -26.7, 11.3], [15.0, 17.0, -26.7, 11.3], [-15.0, 15.0, 9.7, 11.3]]:
		K.plan("moquette", d[0], d[1], d[2], d[3], Y + 0.004)

	# --- rive de dalle autour du vide (y 5,4 → 6), garde-corps de verre et de laiton ---
	for sg in [-1.0, 1.0]:
		K.box("marbre_creme", 0.24, 0.62, 34.5, sg * 13.88, Y - 0.31, -8.25)
		K.box("or", 0.27, 0.05, 34.5, sg * 13.88, Y - 0.03, -8.25)
		K.box("or", 0.27, 0.05, 34.5, sg * 13.88, Y - 0.595, -8.25)
		K.garde_corps(sg * 13.95, -25.55, sg * 13.95, 9.05, Y)
		K.garde_corps(sg * 13.95, -25.55, sg * 11.1, -25.55, Y)
	K.box("marbre_creme", 27.52, 0.62, 0.24, 0, Y - 0.31, 9.12)
	K.box("or", 27.52, 0.05, 0.27, 0, Y - 0.03, 9.12)
	K.garde_corps(-13.95, 9.05, 13.95, 9.05, Y)
	K.garde_corps(-6.9, -25.55, 6.9, -25.55, Y)
	# Entre la tête d'escalier et le bassin (x de 6,9 à 7 et de 11 à 11,1), la balustrade des limons ferme.

	# --- murs périphériques : pierre ombrée, lambris, corniche à gorge ; baies des salles à venir, fermées ---
	K.mur(-17.9, -30, -17.9, 12, H, 1, 0, [{"at": 11.0, "w": 6.0, "h": 4.2}, {"at": 28.5, "w": 15.0, "h": 5.0}, {"at": 40.5, "w": 1.6, "h": 2.4}], "pierre_haute", 1.2, true, Y)
	K.mur(17.9, -30, 17.9, 12, H, -1, 0, [{"at": 11.0, "w": 4.0, "h": 3.2}, {"at": 30.0, "w": 12.0, "h": 5.0}, {"at": 40.5, "w": 1.6, "h": 2.4}], "pierre_haute", 1.2, true, Y)
	K.mur(-18, -29.9, 18, -29.9, H, 0, 1, [], "pierre_haute", 1.2, true, Y)
	K.mur(-18, 11.9, 18, 11.9, H, 0, -1, [{"at": 18.0, "w": 6.0, "h": 4.0}], "pierre_haute", 1.2, true, Y)
	# Les baies : arche à treillage du jardin d'hiver, travées du lounge, porte vitrée du restaurant, boutiques.
	_ferme(K, -18.0, -19.0, 6.0, 4.2, -1.0)
	K.texte("JARDIN D'HIVER", 2.6, 0.32, -17.76, Y + 4.75, -19, PI / 2.0)
	_ferme(K, -18.0, -1.5, 15.0, 5.0, -1.0)
	for z in [-4.0, 1.0]:
		K.colonne(-18, z, 0.5, 5.0, false, true, Y)
	K.texte("LOUNGE", 2.6, 0.5, -17.76, Y + 5.6, -1.5, PI / 2.0, "neon")
	_ferme(K, 18.0, -19.0, 4.0, 3.2, 1.0)
	K.texte("LE LUCULLUS", 3.0, 0.5, 17.76, Y + 3.75, -19, -PI / 2.0, "neon")
	_ferme(K, 18.0, 0.0, 12.0, 5.0, 1.0)
	for z in [-2.0, 2.0]:
		K.colonne(18, z, 0.5, 5.0, false, true, Y)
	K.texte("LES BOUTIQUES", 3.2, 0.36, 17.76, Y + 5.6, 0, -PI / 2.0)
	for sg in [-1.0, 1.0]:
		# Les portes des ascenseurs, en attendant leurs cabines.
		K.box("or", 0.08, 2.4, 1.6, sg * 17.85, Y + 1.2, 10.5)
		K.box("laque_noire", 0.06, 2.3, 1.5, sg * 17.82, Y + 1.15, 10.5)
	# La baie de vue sur la rotonde (M13) : une arche, un garde-corps qu'on ne franchit pas.
	K.arche(0, 12, 0, 6, 4.0, Y)
	K.garde_corps(-3, 11.7, 3, 11.7, Y)
	# Les pilastres à lanterne, un tous les 4 à 5 m.
	for z in [-27.6, -24.0, -15.0, -10.0, 7.4]:
		_pilastre(K, -17.8, z, PI / 2.0)
	for z in [-27.6, -23.5, -15.0, -9.0, 7.4]:
		_pilastre(K, 17.8, z, -PI / 2.0)
	for x in [-16.8, -13.0, -7.2, 7.2, 13.0, 16.8]:
		_pilastre(K, x, -29.8, 0.0)
	for x in [-15.5, -9.5, -4.6, 4.6, 9.5, 15.5]:
		_pilastre(K, x, 11.8, PI)

	# --- le fond de la nef, au-dessus de la cascade : grand panneau d'onyx, enseigne « LE MINUIT » ---
	K.box("onyx", 12, 4.9, 0.08, 0, Y + 2.95, -29.76)
	K.box("or", 12.4, 0.14, 0.16, 0, Y + 5.47, -29.74)
	K.box("or", 12.4, 0.14, 0.16, 0, Y + 0.43, -29.74)
	for x in [-6.13, 6.13]:
		K.box("or", 0.14, 5.04, 0.16, x, Y + 2.95, -29.74)
	K.box("laque_noire", 8.6, 1.7, 0.06, 0, Y + 3.1, -29.7)
	K.texte("LE MINUIT", 7.6, 1.38, 0, Y + 3.1, -29.66, 0, "neon")

	# --- le plafond de la nef (y 13) : caissons réels de 4 × 4 m, coupole plate dorée au-dessus du lustre ---
	var yc := Y + H + 0.3
	for r in [[-18.0, 18.0, -28.0, -4.0], [-18.0, 18.0, 4.0, 12.0], [-18.0, -6.0, -4.0, 4.0], [6.0, 18.0, -4.0, 4.0]]:
		_caissons(K, r[0], r[1], r[2], r[3], yc)
	K.plan("plafond_bas", -18, 18, -30, -28, yc, false)
	for j in 6:
		var f0 := j * PI / 12.0
		var f1 := (j + 1) * PI / 12.0
		K.bande("or", 0, 0, [6.0 * cos(f0), 4.0 * cos(f0), Y + H + 1.8 * sin(f0)], [6.0 * cos(f1), 4.0 * cos(f1), Y + H + 1.8 * sin(f1)], 0.0, TAU, "down")
	K.bande("gorge", 0, 0, [5.8, 3.8, Y + H + 0.1], [5.7, 3.7, Y + H + 0.16], 0.0, TAU, "down", 0.0, 0.1)
	# La collerette entre la coupole ovale et les caissons.
	K.plan("pierre_haute", -6, 6, -4, -3.99, Y + H, false)

	# --- lanternes (une tous les 6 m) et deux ancres lumineuses ---
	for sg in [-1.0, 1.0]:
		for z in [-21.0, -15.0, -9.0, -3.0, 3.0, 9.0]:
			K.lanterne(sg * 16, Y + 3.3, z, 1.0, 3.0)
	for x in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		K.lanterne(x, Y + 3.3, -27.75, 1.0, 3.0)
	K.lumiere(0, Y + 4.4, -27.4, K.pal.lumiere, 1.8, 16.0)
	K.lumiere(0, Y + 4.2, 10.5, K.pal.lumiere, 1.8, 16.0)
	for sg in [-1.0, 1.0]:
		K.lumiere(sg * 16, Y + 3.0, -8, K.pal.ambre, 1.2, 14.0)
	K.zone_fin()


## Une baie fermée d'une salle à venir : un rideau de velours rouge tiré, qui arrête le pas.
static func _ferme(K, x: float, z: float, w: float, h: float, sg: float) -> void:
	K.box("coussin", 0.08, h, w, x + sg * 0.3, Y + h / 2.0, z)
	K.solide(0.3, h, w, x + sg * 0.3, Y + h / 2.0, z)
	K.box("or", 0.12, 0.12, w + 0.2, x + sg * 0.22, Y + h, z)


static func _pilastre(K, x: float, z: float, ry: float) -> void:
	var d := 0.15
	var px := x + sin(ry) * d / 2.0
	var pz := z + cos(ry) * d / 2.0
	K.box("marbre_creme", 0.6, H, d, px, Y + H / 2.0, pz, ry)
	K.box("or", 0.68, 0.12, d + 0.06, px, Y + 0.06, pz, ry)
	K.box("or", 0.68, 0.14, d + 0.06, px, Y + H - 0.4, pz, ry)
	K.lanterne(x + sin(ry) * 0.31, Y + 2.8, z + cos(ry) * 0.31, 0.45)


## Un plafond à caissons : une grille de poutres laquées sur un fond sombre.
static func _caissons(K, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	K.plan("plafond_bas", x0, x1, z0, z1, y, false)
	var x := x0
	while x <= x1 + 0.01:
		K.box("bois_laque", 0.42, 0.3, z1 - z0, x, y - 0.15, (z0 + z1) / 2.0)
		x += 4.0
	var z := z0
	while z <= z1 + 0.01:
		K.box("bois_laque", x1 - x0, 0.3, 0.42, (x0 + x1) / 2.0, y - 0.15, z)
		z += 4.0
