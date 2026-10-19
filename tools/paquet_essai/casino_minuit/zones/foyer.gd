extends RefCounted
## Lot C, zone R-FOYER (js/zones/c-foyer.js) : le foyer du théâtre. Rectangle [14, 22] × [-30, -12], rez-de-
## chaussée, 5,4 m sous plafond. La façade du « Minuit Showroom » sous sa marquise à ampoules (la salle de
## concert viendra avec le lot F : ses portes sont closes), la billetterie à deux guichets, trois affiches
## éclairées, deux banquettes. Liaisons : vers l'atrium et la fosse (sud), vers les paris sportifs (est) ;
## à l'ouest, une porte du stade de la Fortune, qui mène au stade comme celle du grand escalier.

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const LOT_C := "res://communes/casino_minuit/zones/lot_c.gd"
const H := 5.4
const B := {"x0": 14.0, "x1": 22.0, "z0": -30.0, "z1": -12.0}
const OUV := {"north": [{"at": 16.05, "w": 1.9, "h": 2.7}, {"at": 19.95, "w": 1.9, "h": 2.7}], "west": [],
	"south": [{"at": 16.0, "w": 3.6, "h": 3.6}, {"at": 20.0, "w": 3.6, "h": 3.6}], "east": [{"at": -20.0, "w": 6.0, "h": 3.6}]}
const ZF := -29.8


static func construire(K) -> void:
	var LB = load(LOT_B)
	var L = load(LOT_C)
	K.zone_debut("R-FOYER")

	# --- enveloppe : marbre crème, tapis bordé d'or, boiseries claires ---
	L.sol(K, "marbre_creme", B.x0, B.x1, B.z0, B.z1)
	K.plan("moquette_d", 16, 20, -28, -14, 0.006)
	for s in [[16.0, -28.0, 20.0, -28.0], [16.0, -14.0, 20.0, -14.0], [16.0, -28.0, 16.0, -14.0], [20.0, -28.0, 20.0, -14.0]]:
		K.beam("or", Vector3(s[0], 0.008, s[1]), Vector3(s[2], 0.008, s[3]), 0.09, 0.012)
	L.plafond(K, "plafond_bas", B.x0, B.x1, B.z0, B.z1, H)
	LB.coque(K, B, H, "bois_clair", OUV)
	L.registres(K, 14.2, -29.8, 14.2, -12.2, {"n": [1.0, 0.0], "base": "marbre_rouge", "skip": [[11.5, 14.1]], "pil": [9.35, 16.25]})
	L.registres(K, 21.8, -29.8, 21.8, -12.2, {"n": [-1.0, 0.0], "base": "marbre_rouge", "skip": [[6.8, 12.8]], "pil": [0.6, 6.35, 13.25]})
	L.registres(K, 14.2, -12.2, 21.8, -12.2, {"n": [0.0, -1.0], "bh": 0.0, "skip": [[0.0, 7.6]]})
	# La baie des paris sportifs, encadrée ici ; vers l'atrium et la fosse, des plaques.
	L.baie(K, {"axe": "x", "at": 22.0, "c": -20.0, "w": 6.0, "h": 3.6})
	LB.enseigne(K, "PARIS SPORTIFS", 21.72, 4.42, -20, -PI / 2.0, 4.3, 0.75, "neon", "vert")
	LB.enseigne(K, "Tables · Atrium", 18, 4.3, -12.26, PI, 1.6, 0.38, "plaque")
	# De ce côté aussi, une porte du stade de la Fortune (le couloir et sa porte sont au grand escalier) :
	# deux vantaux verts sous un fronton rouge, qui s'ouvrent au seuil du lieu (minuit.gd, « stade »).
	L.baie(K, {"axe": "x", "at": 14.26, "c": -17.0, "w": 2.4, "h": 3.0, "mat": "laque_rouge", "prof": 0.1, "frise": false})
	for s in [-1.0, 1.0]:
		K.box("vert_jardin", 0.04, 2.95, 1.18, 14.23, 1.475, -17.0 + s * 0.6)
		K.box("or", 0.06, 0.5, 0.05, 14.27, 1.25, -17.0 + s * 0.1)
	LB.enseigne(K, "STADE DE LA FORTUNE", 14.26, 4.05, -17, PI / 2.0, 3.6, 0.42, "neon", "rouge")
	LB.enseigne(K, "Racing Club Minuit · le dimanche", 14.26, 3.55, -17, PI / 2.0, 2.4, 0.26, "plaque")
	K.interaction("stade", "Le stade de la Fortune", 14.6, 1.3, -17, Vector3(1.0, 2.6, 2.8))

	# --- la façade du théâtre « Le Minuit Showroom » : marquise à ampoules, portes closes, affiche ---
	K.box("laque_rouge", 7.3, 0.55, 1.75, 18, 3.78, ZF + 0.875)
	for y in [4.08, 3.48]:
		K.box("or", 7.4, 0.06, 1.82, 18, y, ZF + 0.9)
	K.box("gorge", 6.9, 0.02, 1.4, 18, 3.445, ZF + 0.85)
	for i in 7:
		for j in 2:
			K.sph("ampoule", 0.06, 15 + i, 3.42, ZF + 0.45 + j * 0.8)
	# Le chenillard de la marquise : soixante ampoules sur le chant, une sur trois allumée.
	for i in 60:
		var x: float
		var y: float
		if i < 26:
			x = 14.5 + i * 0.28
			y = 4.0
		elif i < 30:
			x = 21.56
			y = 3.94 - (i - 26) * 0.1
		elif i < 56:
			x = 21.5 - (i - 30) * 0.28
			y = 3.56
		else:
			x = 14.44
			y = 3.62 + (i - 56) * 0.1
		K.sph("ampoule" if i % 3 == 0 else "gorge", 0.05, x, y, ZF + 1.78)
	K.texte("LE MINUIT SHOWROOM", 6.2, 0.44, 18, 3.78, ZF + 1.765, 0, "neon")
	K.box("onyx", 7.3, 1.0, 0.04, 18, 4.72, ZF + 0.03)
	K.texte("T H É Â T R E", 3.4, 0.48, 18, 4.72, ZF + 0.06, 0, "grave", K.pal.laque_noire)
	for s in [-1.0, 1.0]:
		K.box("or", 0.1, 1.0, 0.1, 18 + s * 3.7, 4.72, ZF + 0.05)
		L.colonne(K, 18 + s * 3.45, ZF + 1.55, 0.34, 3.45)
	for x in [16.05, 19.95]:
		for s in [-1.0, 1.0]:
			K.box("laque_noire", 0.1, 2.75, 0.14, x + s * 1.0, 1.375, ZF + 0.07)
			# Les vantaux, clos jusqu'à la saison du théâtre (lot F).
			K.box("laque_rouge", 0.93, 2.6, 0.06, x + s * 0.48, 1.3, ZF + 0.02)
			K.box("or", 0.04, 0.4, 0.08, x + s * 0.1, 1.1, ZF + 0.06)
		K.box("or", 2.2, 0.06, 0.16, x, 2.78, ZF + 0.08)
	K.box("gorge", 1.36, 1.96, 0.02, 18, 1.75, ZF + 0.04)
	K.box("laque_rouge", 1.24, 1.86, 0.02, 18, 1.75, ZF + 0.055)
	K.texte("LES NUITS DE MINUIT", 1.1, 0.16, 18, 1.2, ZF + 0.07, 0, "neon")
	K.texte("Revue · tous les soirs", 1.0, 0.08, 18, 1.02, ZF + 0.07, 0)
	K.sph("statue_or", 0.22, 18, 2.05, ZF + 0.07, 1.0)
	for y in [2.76, 0.74]:
		K.box("or", 1.46, 0.06, 0.06, 18, y, ZF + 0.05)
	K.box("or", 0.9, 0.2, 0.03, 18, 0.48, ZF + 0.05)
	K.texte("RELÂCHE CE SOIR", 0.8, 0.09, 18, 0.48, ZF + 0.07, 0, "grave", K.pal.laque_noire)
	L.potelets(K, [[14.9, ZF + 0.95], [16.6, ZF + 0.95], [18.0, ZF + 0.95], [19.4, ZF + 0.95], [21.1, ZF + 0.95]], [0, 3])
	K.obstacle(14.2, 21.8, ZF, ZF + 0.3, 0.0, 2.8)
	K.interaction("theatre", "Le Minuit Showroom", 18, 1.3, ZF + 0.6, Vector3(5.0, 2.6, 0.8))

	# --- la billetterie (mur ouest) : deux guichets sous un dais laqué ---
	K.box("laque_noire", 0.42, 1.06, 4.5, 15.38, 0.53, -25.4)
	K.box("marbre_noir", 0.6, 0.06, 4.6, 15.36, 1.09, -25.4)
	for z in [-27.6, -25.4, -23.2]:
		K.box("or", 0.09, 1.5, 0.09, 15.5, 1.87, z)
	for z in [-26.4, -24.4]:
		K.box("onyx", 0.02, 0.7, 1.5, 15.595, 0.56, z)
		K.box("verre", 0.02, 1.45, 1.55, 15.5, 1.85, z)
		K.box("or", 0.4, 0.012, 0.3, 15.36, 1.127, z)
	K.box("laque_rouge", 1.5, 0.45, 4.9, 14.95, 2.85, -25.4)
	for y in [3.1, 2.62]:
		K.box("or", 1.56, 0.05, 4.96, 14.95, y, -25.4)
	K.box("gorge", 1.3, 0.02, 4.6, 14.95, 2.6, -25.4)
	LB.enseigne(K, "BILLETTERIE", 15.71, 2.86, -25.4, PI / 2.0, 3.4, 0.6, "neon", "ambre")
	K.obstacle(15.16, 15.6, -27.7, -23.1, 0.0, 1.2)
	var guichetiers := []
	for z in [-26.4, -24.4]:
		guichetiers.append([Vector3(14.72, 0, z), -PI / 2.0])
	K.places["foyer_guichetiers"] = guichetiers

	# --- trois affiches éclairées (mur est), qu'on s'arrête regarder ---
	var affiches := [["JAZZ À MINUIT", "Trio · en mezzanine", "bleu_nuit"], ["LE GRAND ILLUSIONNISTE", "Dès vendredi", "bordeaux"], ["LA PLUIE D'OR", "Le spectacle d'eau", "jeton_vert"]]
	var regards := []
	for i in affiches.size():
		var a: Array = affiches[i]
		var z := -28.2 + i * 1.75
		K.box("laque_noire", 0.06, 2.0, 1.4, 21.76, 2.0, z)
		K.box("gorge", 0.02, 1.9, 1.3, 21.725, 2.0, z)
		K.box(a[2], 0.02, 1.8, 1.2, 21.71, 2.0, z)
		for y in [3.02, 0.98]:
			K.box("or", 0.08, 0.05, 1.5, 21.74, y, z)
		K.sph("statue_or", 0.2, 21.69, 2.25, z, 1.0)
		K.texte(a[0], 1.1, 0.13, 21.69, 1.45, z, -PI / 2.0, "neon")
		K.texte(a[1], 1.0, 0.07, 21.69, 1.25, z, -PI / 2.0)
		regards.append([Vector3(20.55, 0, z), -PI / 2.0])
	regards.append([Vector3(18.6, 0, -27.5), 0.0])
	K.places["foyer_affiches"] = regards

	# --- banquettes, plantes, lustres, lumière ---
	var bancs: Array = L.banc(K, 18.9, -22.4, 0.0, 3)
	bancs.append_array(L.banc(K, 21.38, -14.65, PI / 2.0, 3))
	K.places["foyer_bancs"] = bancs
	LB.palmier(K, 14.85, -13.0, {"seed": 9})
	LB.topiaire(K, 21.2, -23.7, 2.0)
	LB.topiaire(K, 21.2, -16.4, 2.0)
	K.lustre_anneau(18, 3.5, -18.5, 1.35, 1.3)
	K.lustre_anneau(18, 3.9, -25.2, 0.9, 1.0)
	K.places["foyer_duos"] = _duos([[17.2, -21.3, 0.9], [18.6, -15.6, 2.3]])
	K.lumiere(18, 3.4, -18.5, K.pal.lumiere, 1.6, 12.0)
	K.lumiere(18, 3.2, -27.0, K.pal.ambre, 1.4, 9.0)
	K.zone_fin()


## Des paires qui bavardent face à face, à 1,1 m (L.duo) : [x, z, a] → les places debout [Vector3, f].
static func _duos(liste: Array) -> Array:
	var out := []
	for d in liste:
		var dx: float = sin(d[2]) * 0.55
		var dz: float = cos(d[2]) * 0.55
		out.append([Vector3(d[0] - dx, 0, d[1] - dz), d[2] + PI])
		out.append([Vector3(d[0] + dx, 0, d[1] + dz), d[2]])
	return out
