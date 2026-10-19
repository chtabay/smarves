extends RefCounted
## Lot F, l'arène de boxe « Minuit Arena » (js/zones/f-arene.js), soirée de gala, en face du casino de l'autre
## côté du Strip (x ∈ [-25 ; 25], z ∈ [90 ; 149,5]). Deux zones :
##  F-ARENE        le hall [-18 ; 18] × [90 ; 104] : la porte de 6 m sur le trottoir (x = 0), la billetterie,
##                 le contrôle (six tourniquets), la vitrine de la ceinture, le bar, les affiches ; deux portes
##                 (x = ±12) vers la salle ;
##  F-ARENE-SALLE  la salle (H 16) : le ring au centre (0, 127) sur l'estrade (y = 1,2), le bord de ring (juges,
##                 presse, chronométreur et sa cloche), les chaises, les gradins sur quatre côtés et leur public,
##                 l'écran suspendu à quatre faces, le pont d'éclairage, le ruban LED, les bannières.
## La porte du trottoir est fermée par la scène (minuit.gd) tant que le lieu n'est pas ouvert : on voit le hall à
## travers ses vantaux de verre. La cloche du chronométreur est interactive : elle lance et clôt les rounds.

const LOT_E := "res://communes/casino_minuit/zones/lot_e.gd"
const LOT_F := "res://communes/casino_minuit/zones/lot_f.gd"
const RC := Vector2(0, 127)
const HALF := 3.65
const POST := 3.35
const CORDE := 3.05
const HALL := {"x0": -18.0, "x1": 18.0, "z0": 90.0, "z1": 104.0, "h": 6.0, "porte": 6.0, "portails": [-12.0, 12.0], "pw": 3.6, "ph": 3.3}
const SAL := {"x0": -25.0, "x1": 25.0, "z0": 104.0, "z1": 149.5, "h": 16.0}
const ECRAN := {"y": 11.6, "w": 5.2, "h": 2.9}
## Le combat : douze rounds de 3 min, une minute de repos ; la cloche fait passer de l'un à l'autre.
const ROUNDS := 12
const ROUND := 180.0
const REPOS := 60.0


static func construire(K) -> void:
	var E = load(LOT_E)
	var F = load(LOT_F)
	_hall(K, E, F)
	_salle(K, E, F)


## L'orientation de qui, en (x, z), regarde le ring.
static func _face(x: float, z: float) -> float:
	return atan2(x - RC.x, z - RC.y)


# --- F-ARENE : le hall --------------------------------------------------------------------------------

static func _hall(K, E, F) -> void:
	K.zone_debut("F-ARENE")
	var H: float = HALL.h
	var x0: float = HALL.x0
	var x1: float = HALL.x1
	var z0: float = HALL.z0
	var z1: float = HALL.z1
	K.dalle(x0, x1, z0, z1, 0.0)
	K.plan("marbre_noir", x0, x1, z0, z1, 0.0)
	K.plan("tapis_rouge", -1.6, 1.6, 90.2, 97.6, 0.006)
	for s in [-1.6, 1.6]:
		K.beam("or", Vector3(s, 0.008, 90.2), Vector3(s, 0.008, 97.6), 0.08, 0.012)
	# Le plafond à caissons bas.
	K.plan("plafond_bas", x0, x1, z0, z1, H, false)
	var x := x0 + 4.0
	while x < x1 - 0.1:
		K.box("laque_noire", 0.36, 0.3, z1 - z0, x, H - 0.15, (z0 + z1) / 2.0)
		x += 4.0
	var z := z0 + 4.0
	while z < z1 - 0.1:
		K.box("laque_noire", x1 - x0, 0.3, 0.36, 0, H - 0.15, z)
		z += 4.0
	# Les murs capitonnés : la façade sur le trottoir (porte de 6 m, haute de 4,2), les côtés, le fond.
	var pd: float = HALL.porte / 2.0
	for p in [[x0, -pd], [pd, x1]]:
		var a: float = p[0]
		var b: float = p[1]
		K.box("capiton_rouge", b - a, H, 0.2, (a + b) / 2.0, H / 2.0, 90.2)
		K.solide(b - a, H, 0.2, (a + b) / 2.0, H / 2.0, 90.2)
	K.box("capiton_rouge", HALL.porte, H - 4.2, 0.2, 0, (H + 4.2) / 2.0, 90.2)
	for s in [-1.0, 1.0]:
		K.box("capiton_rouge", 0.2, H, z1 - z0, s * (x1 - 0.1), H / 2.0, (z0 + z1) / 2.0)
		K.solide(0.2, H, z1 - z0, s * (x1 - 0.1), H / 2.0, (z0 + z1) / 2.0)
		K.box("marbre_noir", 0.06, 1.1, z1 - z0 - 0.4, s * (x1 - 0.23), 0.55, (z0 + z1) / 2.0)
		K.box("or", 0.07, 0.05, z1 - z0 - 0.4, s * (x1 - 0.23), 1.12, (z0 + z1) / 2.0)
	# Le fond du hall : le mur bleu de la salle, percé des portes A et B, parementé côté hall.
	var pw: float = HALL.pw
	var ph: float = HALL.ph
	var trumeaux := [[x0, -12.0 - pw / 2.0], [-12.0 + pw / 2.0, 12.0 - pw / 2.0], [12.0 + pw / 2.0, x1]]
	for t in trumeaux:
		var a: float = t[0]
		var b: float = t[1]
		K.box("capiton_rouge", b - a, H, 0.04, (a + b) / 2.0, H / 2.0, 103.83)
		K.solide(b - a, H, 0.3, (a + b) / 2.0, H / 2.0, 103.95)
	for px in HALL.portails:
		K.box("capiton_rouge", pw, H - ph, 0.04, px, (H + ph) / 2.0, 103.83)
		K.box("laque_noire", pw + 0.3, 0.15, 0.2, px, ph + 0.07, 103.8)
		for s in [-1.0, 1.0]:
			K.box("laque_noire", 0.15, ph, 0.2, px + s * (pw / 2.0 + 0.07), ph / 2.0, 103.8)
		E.enseigne(K, "← PORTE A · RING" if px < 0 else "PORTE B · RING →", "#3DE0E0", 3.6, 0.5, px, ph + 0.75, 103.78, PI)
	# La porte du Strip : encadrement laqué et or, vantaux de verre coulissés de part et d'autre, l'enseigne.
	K.box("laque_noire", HALL.porte + 0.4, 0.2, 0.3, 0, 4.3, 90.3)
	for s in [-1.0, 1.0]:
		K.box("laque_noire", 0.2, 4.2, 0.3, s * (pd + 0.1), 2.1, 90.3)
		K.box("verre", 1.5, 3.9, 0.04, s * (pd + 0.8), 1.95, 90.35)
		K.box("or", 1.56, 0.06, 0.08, s * (pd + 0.8), 3.92, 90.35)
		K.box("or", 0.05, 3.9, 0.08, s * (pd + 1.55), 1.95, 90.35)
	E.enseigne(K, "MINUIT ARENA", "#FFF3D6", 5.6, 0.8, 0, 4.85, 90.32, 0, "bloc")
	# La billetterie, à l'ouest avant le contrôle.
	K.box("laque_noire", 0.7, 1.08, 5.6, -15.55, 0.54, 94)
	K.box("marbre_creme", 0.84, 0.06, 5.7, -15.5, 1.11, 94)
	K.box("verre", 0.03, 1.4, 5.4, -15.7, 1.86, 94)
	K.box("or", 0.08, 0.06, 5.6, -15.7, 2.58, 94)
	K.box("ambre_lum", 0.03, 0.03, 5.4, -15.18, 0.13, 94)
	K.box("laque_rouge", 2.6, 0.6, 6.0, -16.6, 3.2, 94)
	K.box("or", 2.65, 0.05, 6.05, -16.6, 3.52, 94)
	E.enseigne(K, "BILLETTERIE", "#FFB347", 3.4, 0.5, -15.28, 3.2, 94, PI / 2.0)
	K.obstacle(-17.9, -15.15, 91.15, 96.85, 0.0, 2.6)
	var guichetiers := []
	var file := []
	for gz in [92.2, 94.0, 95.8]:
		guichetiers.append([Vector3(-16.75, 0, gz), -PI / 2.0])
		for r in 2:
			file.append([Vector3(-14.5 + r * 0.8, 0, gz), PI / 2.0])
	K.places["f_billetterie"] = guichetiers
	K.places["f_billetterie_file"] = file
	# Le contrôle des billets : six tourniquets, les potelets de part et d'autre.
	var zc := 97.0
	var tq := [-6.25, -3.75, -1.25, 1.25, 3.75, 6.25]
	for i in tq.size():
		var tx: float = tq[i]
		K.box("noir_satin", 0.34, 1.0, 1.0, tx, 0.5, zc)
		K.box("alu", 0.38, 0.05, 1.04, tx, 1.02, zc)
		K.box("cyan_lum" if i % 2 else "vert_lum", 0.14, 0.02, 0.1, tx, 1.06, zc - 0.32)
		for k in 3:
			var a := k * TAU / 3.0
			K.beam("alu", Vector3(tx + 0.17, 0.95, zc), Vector3(tx + 0.17 + cos(a) * 0.35, 0.95 + sin(a) * 0.35, zc - 0.1), 0.035, 0.035)
		K.obstacle(tx - 0.2, tx + 0.2, zc - 0.52, zc + 0.52, 0.0, 1.2)
	for s in [-1.0, 1.0]:
		E.cordons(K, zc, [s * 6.45, s * 8.35, s * 10.7, s * 13.05, s * 15.4], "x")
	K.box("laque_noire", 7.6, 0.6, 0.12, 0, 2.6, zc + 0.05)
	K.texte("CONTRÔLE DES BILLETS · PRÉPAREZ VOTRE BILLET", 7.2, 0.3, 0, 2.6, zc - 0.03, PI, "grave", Color("#F3EAD7"))
	K.beam("or", Vector3(-3.8, 2.3, zc - 0.02), Vector3(3.8, 2.3, zc - 0.02), 0.04, 0.04)
	for s in [-3.6, 3.6]:
		K.beam("alu", Vector3(s, 2.9, zc + 0.05), Vector3(s, H, zc + 0.05), 0.02, 0.02)
	K.places["f_controle"] = [[Vector3(-1.25, 0, zc + 0.95), 0.0], [Vector3(1.25, 0, zc + 0.95), 0.0]]
	var queue := []
	for sx in [-2.5, 2.5]:
		for r in 4:
			queue.append([Vector3(sx, 0, zc - 1.3 - r * 0.8), PI])
	K.places["f_controle_file"] = queue
	# La vitrine de la ceinture de champion.
	var vz := 100.9
	K.box("marbre_noir", 1.4, 1.0, 1.0, 0, 0.5, vz)
	K.box("or", 1.48, 0.06, 1.08, 0, 1.0, vz)
	K.box("velours", 1.2, 0.04, 0.8, 0, 1.05, vz)
	K.box("laque_noire", 0.9, 0.06, 0.14, 0, 1.12, vz + 0.12)
	K.cyl("or", 0.2, 0.2, 0.03, 0, 1.2, vz + 0.08, 18, PI / 2.0 - 0.5)
	K.cyl("laque_rouge", 0.12, 0.12, 0.035, 0, 1.2, vz + 0.085, 14, PI / 2.0 - 0.5)
	for o in [-0.3, 0.3]:
		K.cyl("or", 0.09, 0.09, 0.025, o, 1.15, vz + 0.1, 12, PI / 2.0 - 0.5)
	K.box("verre", 1.24, 0.8, 0.84, 0, 1.46, vz)
	K.box("or", 1.28, 0.04, 0.88, 0, 1.87, vz)
	K.rond(0, vz, 0.85)
	K.texte("CEINTURE MONDIALE · POIDS MOYENS", 1.1, 0.08, 0, 0.6, vz + 0.52, 0)
	K.lumiere(0, 3.4, vz, Color("#FFE2B4"), 1.5, 8.0)
	K.places["f_vitrine"] = [[Vector3(0, 0, vz - 1.5), F.vers(0, vz - 1.5, 0, vz)], [Vector3(1.4, 0, vz + 0.6), F.vers(1.4, vz + 0.6, 0, vz)]]
	# Le bar du ring, à l'est après le contrôle.
	K.box("bois_laque", 0.8, 1.1, 4.4, 13.8, 0.55, 100.3)
	K.box("marbre_noir", 1.0, 0.06, 4.6, 13.8, 1.13, 100.3)
	K.box("rouge_lum", 0.03, 0.03, 4.4, 13.38, 0.1, 100.3)
	K.box("laque_noire", 0.5, 2.6, 4.4, 17.55, 1.3, 100.3)
	for k in 4:
		K.box("verre", 0.4, 0.02, 4.2, 17.4, 1.2 + k * 0.45, 100.3)
	K.obstacle(13.4, 14.2, 98.1, 102.5, 0.0, 1.3)
	E.enseigne(K, "BAR DU RING", "#FF3348", 3.6, 0.6, 17.72, 3.9, 100.3, -PI / 2.0)
	var tabourets := []
	for o in [-1.6, -0.55, 0.55, 1.6]:
		K.cyl("laque_noire", 0.2, 0.2, 0.06, 12.9, 0.75, 100.3 + o, 12)
		K.cyl("or", 0.03, 0.03, 0.72, 12.9, 0.38, 100.3 + o, 6)
		tabourets.append([Vector3(12.9, 0.78, 100.3 + o), -PI / 2.0])
	K.places["f_bar"] = {"barman": [Vector3(15.4, 0, 98.6), Vector3(15.4, 0, 102.0)], "tabourets": tabourets}
	# Les mange-debout ; les affiches éclairées du combat.
	var duos := []
	for m in [[8.4, 99.6], [7.6, 101.9], [-6.5, 101.2], [-11.2, 93.6]]:
		K.cyl("marbre_noir", 0.35, 0.35, 0.04, m[0], 1.08, m[1], 16)
		K.cyl("or", 0.04, 0.04, 1.06, m[0], 0.53, m[1], 6)
		K.cyl("or", 0.25, 0.28, 0.03, m[0], 0.015, m[1], 12)
		K.rond(m[0], m[1], 0.4)
		duos.append([Vector3(m[0] - 0.7, 0, m[1]), -PI / 2.0])
		duos.append([Vector3(m[0] + 0.7, 0, m[1]), PI / 2.0])
	K.places["f_hall_duos"] = duos
	var affiches := [[-9.5, 2.9, 90.32, 0.0, 3.2, 4.2, "KANE\ncontre\nMORALES"], [9.5, 2.9, 90.32, 0.0, 3.2, 4.2, "CE SOIR\n12 ROUNDS\nTITRE MONDIAL"],
		[-17.78, 2.6, 100.6, PI / 2.0, 2.2, 3.0, "MINUIT\nFIGHT\nNIGHT"], [17.78, 2.6, 93.4, -PI / 2.0, 2.2, 3.0, "POIDS\nMOYENS"]]
	for i in affiches.size():
		var a: Array = affiches[i]
		var sx := sin(a[3])
		var cz := cos(a[3])
		K.box("laque_noire", a[4] + 0.24, a[5] + 0.24, 0.14, a[0], a[1], a[2], a[3])
		E.ecran(K, a[0] + sx * 0.08, a[1], a[2] + cz * 0.08, a[4], a[5], a[3], E.LED_ROUGE, i * 0.7)
		K.box("or", a[4] + 0.3, 0.06, 0.18, a[0], a[1] + a[5] / 2.0 + 0.15, a[2], a[3])
		K.box("or", a[4] + 0.3, 0.06, 0.18, a[0], a[1] - a[5] / 2.0 - 0.15, a[2], a[3])
		var l: Label3D = K.texte(a[6], a[4] * 0.9, a[5] * 0.22, a[0] + sx * 0.12, a[1], a[2] + cz * 0.12, a[3], "neon", Color("#FFF3D6"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	K.places["f_affiches"] = [[Vector3(-9.5, 0, 92.4), 0.0], [Vector3(9.5, 0, 92.4), 0.0], [Vector3(-15.6, 0, 100.6), PI / 2.0], [Vector3(15.6, 0, 93.4), -PI / 2.0]]
	# La banquette, les palmiers en pot, les lustres.
	var banc := []
	for k in 3:
		var bz := 100.6 + k * 0.6
		K.box("capiton_rouge", 0.5, 0.45, 0.58, -16.9, 0.23, bz)
		banc.append([Vector3(-16.85, 0.45, bz), -PI / 2.0])
	K.box("laque_noire", 0.2, 0.8, 1.9, -17.2, 0.6, 101.2)
	K.obstacle(-17.3, -16.6, 100.2, 102.1, 0.0, 1.0)
	K.places["f_hall_banc"] = banc
	for p in [[-16.6, 103.0], [16.6, 91.2]]:
		K.cyl("laque_noire", 0.32, 0.26, 0.6, p[0], 0.3, p[1], 12)
		E.palmiers(K, [[p[0], p[1], 0.3, 0.32, 0.6]])
		K.rond(p[0], p[1], 0.4)
	for lx in [-7.5, 7.5]:
		K.lustre_anneau(lx, 4.3, 97.0, 1.3, 1.0)
		K.lumiere(lx, 4.0, 97.0, Color("#FFD9A8"), 1.6, 6.5)
	K.lustre_anneau(0, 4.4, 100.9, 0.9, 1.0)
	K.zone_fin()


# --- F-ARENE-SALLE : la salle -------------------------------------------------------------------------

static func _salle(K, E, F) -> void:
	K.zone_debut("F-ARENE-SALLE")
	var Hs: float = SAL.h
	var x0: float = SAL.x0
	var x1: float = SAL.x1
	var z0: float = SAL.z0
	var z1: float = SAL.z1
	var zm := (z0 + z1) / 2.0
	var y: float = F.Y_ESTRADE
	var cx := RC.x
	var cz := RC.y
	K.dalle(x0, x1, z0, z1, 0.0)
	K.plan("beton_noir", x0, x1, z0, z1, 0.0)
	K.plan("moquette_c", -11, 11, 115.5, 138.5, 0.006)
	# L'enveloppe : les murs acoustiques bleus (le mur du hall porte les portes A et B), le plafond noir.
	K.box("acoustique_bleu", x1 - x0, Hs, 0.2, 0, Hs / 2.0, 104.07)
	for s in [-1.0, 1.0]:
		K.box("acoustique_bleu", 0.2, Hs, z1 - z0, s * (x1 - 0.1), Hs / 2.0, zm)
		K.solide(0.2, Hs, z1 - z0, s * (x1 - 0.1), Hs / 2.0, zm)
	K.box("acoustique_bleu", x1 - x0, Hs, 0.2, 0, Hs / 2.0, z1 - 0.1)
	K.solide(x1 - x0, Hs, 0.2, 0, Hs / 2.0, z1 - 0.1)
	K.box("noir_mat", x1 - x0, 0.2, z1 - z0, 0, Hs + 0.1, zm)
	# Le mur du hall vu de la salle : percé des deux portes (le parement rouge est du côté du hall).
	for px in HALL.portails:
		K.box("noir_mat", HALL.pw, HALL.ph, 0.1, px, HALL.ph / 2.0, 104.2)
	# Les ponts du plafond, les rubans bleus des murs.
	for tx in [-8.0, 0.0, 8.0]:
		F.treillis(K, Vector3(tx, 14.2, z0 + 1), Vector3(tx, 14.2, z1 - 1), 0.5, 1.0, "gris")
	for tz in [112.0, 127.0, 142.0]:
		F.treillis(K, Vector3(x0 + 1, 14.2, tz), Vector3(x1 - 1, 14.2, tz), 0.5, 1.0, "gris")
	for s in [-1.0, 1.0]:
		var z := 108.0
		while z < 148.0:
			K.box("bleu_lum", 0.04, Hs - 7, 0.05, s * (x1 - 0.24), 7 + (Hs - 7) / 2.0, z)
			z += 4.0
	var bx := -22.0
	while bx <= 22.0:
		K.box("bleu_lum", 0.05, Hs - 5, 0.04, bx, 5 + (Hs - 5) / 2.0, z1 - 0.22)
		bx += 4.0
	_ring(K, F, y, cx, cz)
	_bord_ring(K, E, F, cx, cz)
	_gradins(K, E, F, cx, cz)
	_ecran(K, E, F, y, cx, cz, Hs)
	# Les dégagements des portes A et B : appliques, plaques, placeurs, spectateurs debout.
	var placeurs := []
	var debout := []
	for p in [[-17.5, 1.0], [17.5, -1.0]]:
		var px: float = p[0]
		var s: float = p[1]
		for lz in [106.5, 112.0]:
			K.lanterne(px - s * 7.3, 2.6, lz, 0.45)
		K.texte("PORTE A · BLOCS OUEST ET NORD" if s > 0 else "PORTE B · BLOCS EST ET NORD", 3.2, 0.24, px, 3.4, 104.2, 0)
		placeurs.append([Vector3(px + s * 3.2, 0, 106.2), PI])
		for w in [[px + s * 4.8, 114.6], [px + s * 6.8, 115.2], [px + s * 2.6, 113.4]]:
			debout.append([Vector3(w[0], 0, w[1]), _face(w[0], w[1])])
	for w in [[-11.6, 133.5], [11.6, 133.5]]:
		debout.append([Vector3(w[0], 0, w[1]), _face(w[0], w[1])])
	K.places["f_placeurs"] = placeurs
	K.places["f_arene_debout"] = debout
	K.places["f_vigiles_ring"] = [[Vector3(-4.4, 0, 133.6), _face(-4.4, 133.6) + PI], [Vector3(4.4, 0, 120.4), _face(4.4, 120.4) + PI]]
	# Les lumières : deux ancres blanches sur le ring, quatre lavis bleutés sur les gradins (la salle est dans
	# le noir, le public s'y devine).
	K.lumiere(cx - 1.5, 6.5, cz, Color("#EEF2FF"), 2.6, 15.0)
	K.lumiere(cx + 1.5, 6.5, cz, Color("#EEF2FF"), 2.6, 15.0)
	for l in [[-17.0, 127.0], [17.0, 127.0], [0.0, 109.5], [0.0, 144.5]]:
		K.lumiere(l[0], 10.5, l[1], Color("#8A98D8"), 0.9, 15.0)
	F.issue(K, -24.78, 141, PI / 2.0)
	F.issue(K, 24.78, 141, -PI / 2.0)
	K.zone_fin()


## Le ring : le tapis sur l'estrade, sa jupe, les poteaux, les protections de coin, les cordes, les marches.
static func _ring(K, F, y: float, cx: float, cz: float) -> void:
	K.box("noir_satin", 2 * HALF - 0.1, y - 0.04, 2 * HALF - 0.1, cx, (y - 0.04) / 2.0, cz)
	K.box("tapis_ring", 2 * HALF, 0.04, 2 * HALF, cx, y - 0.02, cz)
	K.box("blanc_ring", 2.2, 0.005, 2.2, cx, y + 0.003, cz)
	K.box("tapis_ring", 2.0, 0.006, 2.0, cx, y + 0.004, cz)
	K.box("or", 2 * HALF + 0.04, 0.05, 2 * HALF + 0.04, cx, y - 0.05, cz)
	for a in [0.0, PI / 2.0, PI, -PI / 2.0]:
		K.box("rouge_sombre", 2 * HALF, y - 0.06, 0.02, cx + sin(a) * (HALF + 0.005), (y - 0.06) / 2.0, cz + cos(a) * (HALF + 0.005), a)
		K.texte("MINUIT ARENA", 3.4, 0.32, cx + sin(a) * (HALF + 0.03), (y - 0.06) / 2.0, cz + cos(a) * (HALF + 0.03), a, "grave", Color("#F3EAD7"))
	var hauteurs := [0.45, 0.78, 1.1, 1.38]
	var coins := [[-1.0, 1.0, "rouge_ring"], [1.0, -1.0, "bleu_ring"], [-1.0, -1.0, "blanc_ring"], [1.0, 1.0, "blanc_ring"]]
	for c in coins:
		var px: float = cx + c[0] * POST
		var pz: float = cz + c[1] * POST
		K.cyl("alu", 0.07, 0.07, 1.55, px, y + 0.77, pz, 10)
		K.box(c[2], 0.22, 1.18, 0.22, px - c[0] * 0.1, y + 0.86, pz - c[1] * 0.1, PI / 4.0)
	var mats := ["rouge_ring", "blanc_ring", "blanc_ring", "bleu_ring"]
	for c in [[-1.0, -1.0, 1.0, -1.0], [1.0, -1.0, 1.0, 1.0], [1.0, 1.0, -1.0, 1.0], [-1.0, 1.0, -1.0, -1.0]]:
		var r := CORDE + 0.02
		for i in hauteurs.size():
			K.beam(mats[i], Vector3(cx + c[0] * r, y + hauteurs[i], cz + c[1] * r), Vector3(cx + c[2] * r, y + hauteurs[i], cz + c[3] * r), 0.045, 0.045)
		for t in [-0.33, 0.33]:
			var mx: float = cx + (c[0] + c[2]) / 2.0 * (CORDE + 0.03) + (c[2] - c[0]) * t * CORDE
			var mz: float = cz + (c[1] + c[3]) / 2.0 * (CORDE + 0.03) + (c[3] - c[1]) * t * CORDE
			K.box("blanc_ring", 0.06, 1.0, 0.06, mx, y + 0.92, mz)
	K.obstacle(cx - HALF - 0.08, cx + HALF + 0.08, cz - HALF - 0.08, cz + HALF + 0.08, 0.0, 2.8)
	# Les marches des coins rouge (sud-ouest) et bleu (nord-est).
	for m in [[-2.3, 132.8, 129.55, "rouge_ring"], [2.3, 121.2, 124.45, "bleu_ring"]]:
		var n := 4
		for k in n:
			var t := (k + 0.5) / n
			var mz: float = lerpf(m[1], m[2], t * 0.6)
			var h := y * (k + 1) / (n + 1)
			K.box("noir_satin", 1.2, h, 0.32, m[0], h / 2.0, mz)
			K.box(m[3], 1.2, 0.02, 0.3, m[0], h + 0.01, mz)
	# Les seaux, tabourets de soigneur, serviettes, bouteilles.
	for c in [[-4.35, 131.4, "rouge_ring"], [4.35, 122.6, "bleu_ring"]]:
		K.cyl("alu", 0.17, 0.14, 0.32, c[0], 0.16, c[1], 12)
		K.cyl("alu", 0.13, 0.11, 0.26, c[0] + 0.4, 0.13, c[1], 12)
		K.cyl(c[2], 0.2, 0.18, 0.05, c[0] - 0.45, 0.48, c[1], 12)
		K.cyl("alu", 0.02, 0.02, 0.46, c[0] - 0.45, 0.23, c[1], 5)
		K.box("blanc_ring", 0.35, 0.06, 0.25, c[0] + 0.4, 0.29, c[1])
		for k in 3:
			K.cyl("cyan_lum", 0.035, 0.035, 0.22, c[0] + 0.1 + k * 0.08, 0.11, c[1] + 0.3, 6)
		K.rond(c[0], c[1], 0.62)
	# Sur le ring : les deux boxeurs à leur coin, l'arbitre au centre ; les soigneurs au pied des marches.
	K.places["f_ring"] = {
		"rouge": [Vector3(cx - 1.4, y, cz + 1.0), F.vers(-1.4, cz + 1.0, 1.4, cz - 1.0)],
		"bleu": [Vector3(cx + 1.4, y, cz - 1.0), F.vers(1.4, cz - 1.0, -1.4, cz + 1.0)],
		"arbitre": [Vector3(cx + 1.6, y, cz + 1.4), F.vers(1.6, cz + 1.4, 0, cz)],
		"soigneurs": [[Vector3(-5.0, 0, 132.6), _face(-5.0, 132.6)], [Vector3(5.0, 0, 121.4), _face(5.0, 121.4)]],
	}


## Le bord de ring : les tables des juges, du chronométreur et de la presse, la cloche, les chaises.
static func _bord_ring(K, E, F, cx: float, cz: float) -> void:
	var table := func(x: float, z: float, w: float, d: float, ry: float) -> void:
		K.box("noir_mat", w, 0.74, d, x, 0.37, z, ry)
		K.box("laque_noire", w + 0.04, 0.04, d + 0.04, x, 0.76, z, ry)
		K.solide(w, 0.8, d, x, 0.4, z, ry)
	var chaises := []
	var juges := []
	for j in [[-5.6, 127.0, -PI / 2.0], [5.6, 127.0, PI / 2.0], [-0.6, 120.9, PI]]:
		var f: float = j[2]
		table.call(j[0] - sin(f) * 0.62, j[1] - cos(f) * 0.62, 1.4, 0.55, f)
		chaises.append(Transform3D(Basis(Vector3.UP, f), Vector3(j[0], 0, j[1])))
		juges.append([Vector3(j[0], 0.47, j[1]), f])
	# Le chronométreur et le superviseur, la cloche.
	table.call(2.7, 133.25, 3.4, 0.6, 0.0)
	K.box("noir_satin", 0.4, 0.25, 0.3, 3.6, 0.9, 133.25)
	K.box("rouge_lum", 0.32, 0.12, 0.01, 3.6, 0.92, 133.09)
	for p in [[1.8, 133.9], [3.6, 133.9]]:
		chaises.append(Transform3D(Basis(), Vector3(p[0], 0, p[1])))
		juges.append([Vector3(p[0], 0.47, p[1]), 0.0])
	var bx := 1.1
	var bz := 133.25
	K.box("bois_laque", 0.34, 0.42, 0.06, bx, 0.97, bz + 0.12)
	K.sph("or", 0.14, bx, 1.04, bz + 0.03, 0.8)
	K.places["f_juges"] = juges
	K.interaction("cloche", "La cloche du chronométreur", bx, 1.0, bz - 0.4, Vector3(1.4, 1.6, 1.0))
	# La presse : longue table, ordinateurs (écrans lumineux).
	table.call(6.7, 125.6, 0.6, 11.0, 0.0)
	var pz := 120.6
	while pz <= 130.61:
		K.box("noir_satin", 0.3, 0.02, 0.22, 6.72, 0.77, pz)
		K.box("cyan_lum" if int(pz * 4) % 2 else "blanc_froid", 0.02, 0.16, 0.24, 6.86, 0.86, pz)
		pz += 1.25
	K.texte("PRESSE", 1.2, 0.2, 6.38, 0.5, 125.6, -PI / 2.0)
	# Les chaises de bord de ring : le premier rang (juges, presse, invités) noté, le public derrière.
	var h := RandomNumberGenerator.new()
	h.seed = 41
	var invites := []
	var public := []
	var rang := func(pts: Array, note: bool) -> void:
		for p in pts:
			var f := _face(p[0], p[1])
			chaises.append(Transform3D(Basis(Vector3.UP, f), Vector3(p[0], 0, p[1])))
			if note:
				invites.append([Vector3(p[0], 0.47, p[1]), f])
			elif h.randf() < 0.78:
				public.append([p[0], 0.02, p[1], f])
	var le_long := func(fixe: float, a0: float, a1: float, axe: String, saut: Vector2) -> Array:
		var out := []
		var a := a0
		while a <= a1 + 1e-6:
			if not (a > saut.x and a < saut.y):
				out.append([fixe, a] if axe == "z" else [a, fixe])
			a += 0.62
		return out
	rang.call(le_long.call(-7.1, 117.4, 131.0, "z", Vector2(1e9, 1e9)), true)
	for fx in [-8.2, -9.3, -10.4]:
		rang.call(le_long.call(fx, 117.4, 131.0, "z", Vector2(1e9, 1e9)), false)
	rang.call(le_long.call(7.45, 120.8, 130.4, "z", Vector2(1e9, 1e9)), true)
	for fx in [9.6, 10.7]:
		rang.call(le_long.call(fx, 117.4, 131.0, "z", Vector2(1e9, 1e9)), false)
	rang.call(le_long.call(119.3, -4.8, 5.0, "x", Vector2(1.2, 3.4)), true)
	for fz in [118.2, 117.1, 116.0]:
		rang.call(le_long.call(fz, -4.8, 5.0, "x", Vector2(1.2, 3.4)), false)
	rang.call(le_long.call(135.2, -5.0, 4.8, "x", Vector2(-3.4, -1.2)), true)
	for fz in [136.3, 137.4, 138.5]:
		rang.call(le_long.call(fz, -5.0, 4.8, "x", Vector2(-3.4, -1.2)), false)
	for o in [[-10.75, -6.8, 117.1, 131.3], [7.2, 7.75, 120.5, 130.7], [9.3, 11.05, 117.1, 131.3], [-5.1, 1.15, 115.7, 119.58],
			[3.45, 5.3, 115.7, 119.58], [-5.3, -3.45, 134.92, 138.8], [-1.15, 5.1, 134.92, 138.8]]:
		K.obstacle(o[0], o[1], o[2], o[3], 0.0, 1.0)
	F.sieges(K, chaises, "noir_satin", true, "chaises_ring")
	E.foule(K, public, "assis", 70, "foule_ring")
	K.places["f_invites"] = invites


## Les gradins : quatre blocs (le premier rang noté, le public au-delà), le ruban LED, les bannières, les
## plates-formes de télévision, les poursuites.
static func _gradins(K, E, F, cx: float, cz: float) -> void:
	var blocs := [
		{"x": -13.45, "z": 127.0, "rot": -PI / 2.0, "width": 22.0, "rows": 10, "aisles": [-6.0, 6.0]},
		{"x": 13.45, "z": 127.0, "rot": PI / 2.0, "width": 22.0, "rows": 10, "aisles": [-6.0, 6.0]},
		{"x": 0.0, "z": 112.55, "rot": PI, "width": 19.0, "rows": 8, "aisles": [0.0]},
		{"x": 0.0, "z": 141.45, "rot": 0.0, "width": 19.0, "rows": 8, "aisles": [0.0]}]
	var sieges := []
	var public := []
	var places := []
	for i in blocs.size():
		var o: Dictionary = blocs[i]
		o.merge({"depth": 0.9, "rise": 0.46, "look": RC, "seed": 50 + i, "nez": "bleu_lum", "occupation": 0.84})
		var g: Dictionary = F.gradins(K, o, sieges)
		places.append_array(g.places)
		public.append_array(g.foule)
	F.sieges(K, sieges, "capiton_rouge", false, "sieges_gradins")
	E.foule(K, public, "assis", 60, "foule_gradins")
	K.places["f_gradins"] = places
	# Le ruban LED en haut des gradins.
	for r in [[-22.15, 127.0, PI / 2.0, 22.4, 6.3], [22.15, 127.0, -PI / 2.0, 22.4, 6.3], [0.0, 105.65, 0.0, 19.4, 5.4], [0.0, 148.35, PI, 19.4, 5.4]]:
		K.box("noir_satin", r[3] + 0.2, 1.0, 0.3, r[0], r[4], r[1], r[2])
		E.ecran(K, r[0] + sin(r[2]) * 0.17, r[4], r[1] + cos(r[2]) * 0.17, r[3], 0.7, r[2], E.LED_BLEU, r[0] * 0.1)
	# Les bannières des champions suspendues.
	var noms := ["KANE", "MORALES", "OKAFOR", "DUVAL", "IBARRA", "SATO"]
	var bn := [[-24.6, 112.0, PI / 2.0], [-24.6, 122.0, PI / 2.0], [-24.6, 132.0, PI / 2.0], [24.6, 112.0, -PI / 2.0], [24.6, 122.0, -PI / 2.0], [24.6, 132.0, -PI / 2.0]]
	for i in bn.size():
		var b: Array = bn[i]
		K.box("gris", 0.05, 0.05, 2.2, b[0], 13.6, b[1])
		K.box("rouge_sombre" if i % 2 == 0 else "marine", 0.03, 4.2, 1.7, b[0], 11.4, b[1])
		K.box("or", 0.04, 0.06, 1.74, b[0], 13.5, b[1])
		var l: Label3D = K.texte("CHAMPION\n" + noms[i], 1.5, 0.22, b[0] + sin(b[2]) * 0.03, 11.6, b[1], b[2], "grave", Color("#F3EAD7"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Les coins sud : plates-formes des caméras de télévision, lignes de son.
	var tech := []
	for c in [[-19.0, 144.5, 1.0], [19.0, 144.5, -1.0]]:
		var x: float = c[0]
		var z: float = c[1]
		K.box("noir_satin", 5, 2.4, 4, x, 1.2, z)
		K.box("alu", 5.1, 0.06, 4.1, x, 2.42, z)
		K.cyl("gris", 0.03, 0.03, 1.4, x, 3.1, z, 5)
		K.box("noir_satin", 0.32, 0.36, 0.7, x, 3.95, z - 0.1, _face(x, z) + PI)
		K.box("rouge_lum", 0.05, 0.03, 0.02, x, 4.16, z - 0.42)
		K.obstacle(x - 2.5, x + 2.5, z - 2, z + 2, 0.0, 2.4)
		tech.append([x + 0.5 * c[2], 2.44, z + 0.3, _face(x, z)])
		F.ligne_son(K, x + c[2] * 3.5, 9.5, z - 3.5, _face(x + c[2] * 3.5, z - 3.5) + PI, 6)
	for p in [[-6.5, 7.8, 149.0], [6.5, 7.8, 149.0]]:
		K.box("noir_satin", 1.2, 0.1, 1.2, p[0], p[1] - 0.6, p[2])
		K.cyl("noir_satin", 0.17, 0.2, 0.9, p[0], p[1], p[2] - 0.2, 10, PI / 2.0 + 0.35)
		tech.append([p[0] + 0.5, p[1] - 0.55, p[2] - 0.2, _face(p[0], p[2])])
	E.foule(K, tech, "debout", 71, "foule_technique")


## L'écran suspendu à quatre faces (le chrono du round), le pont d'éclairage du ring et ses faisceaux,
## l'animation du combat (rounds, repos, cloche) et du public.
static func _ecran(K, E, F, y: float, cx: float, cz: float, Hs: float) -> void:
	var sw: float = ECRAN.w
	var sh: float = ECRAN.h
	var sy: float = ECRAN.y
	var textes := []
	for a in [0.0, PI / 2.0, PI, -PI / 2.0]:
		var d := sw / 2.0 + 0.06
		E.ecran(K, cx + sin(a) * d, sy, cz + cos(a) * d, sw, sh, a, E.LED_BLEU, a)
		var l: Label3D = K.texte("ROUND 1\n3:00", sw * 0.8, 0.8, cx + sin(a) * (d + 0.02), sy, cz + cos(a) * (d + 0.02), a, "neon", Color("#FFF6E2"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		textes.append(l)
	K.box("noir_satin", sw + 0.1, sh + 0.3, sw + 0.1, cx, sy, cz)
	K.box("noir_satin", sw + 0.5, 0.35, sw + 0.5, cx, sy + sh / 2.0 + 0.3, cz)
	for a in [0.0, PI / 2.0, PI, -PI / 2.0]:
		var d := sw / 2.0 + 0.12
		K.box("bleu_lum", sw + 0.36, 0.12, 0.06, cx + sin(a) * d, sy - sh / 2.0 - 0.12, cz + cos(a) * d, a)
	K.box("noir_satin", sw + 0.2, 0.06, sw + 0.2, cx, sy - sh / 2.0 - 0.1, cz)
	for c in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
		K.beam("gris", Vector3(cx + c[0] * 2.4, sy + sh / 2.0 + 0.45, cz + c[1] * 2.4), Vector3(cx + c[0] * 3.5, Hs, cz + c[1] * 3.5), 0.025, 0.025)
	# Le pont d'éclairage du ring (carré de 10 m), seize projecteurs et leurs faisceaux.
	var T := 5.0
	var ty := 8.6
	for c in [[-T, -T, T, -T], [T, -T, T, T], [T, T, -T, T], [-T, T, -T, -T]]:
		F.treillis(K, Vector3(cx + c[0], ty, cz + c[1]), Vector3(cx + c[2], ty, cz + c[3]), 0.4, 0.7, "alu")
	for c in [[-T, -T], [T, -T], [T, T], [-T, T]]:
		K.beam("gris", Vector3(cx + c[0], ty + 0.2, cz + c[1]), Vector3(cx + c[0] * 1.3, Hs, cz + c[1] * 1.3), 0.025, 0.025)
	var faisceaux := []
	for i in 4:
		for k in 4:
			var t := -3.6 + k * 2.4
			var sd: Array = [[t, -T], [T, t], [-t, T], [-T, -t]][i]
			var p := Vector3(cx + sd[0], ty - 0.35, cz + sd[1])
			K.cyl("noir_satin", 0.14, 0.16, 0.42, p.x, p.y + 0.1, p.z, 10)
			K.cyl("blanc_froid", 0.12, 0.12, 0.02, p.x, p.y - 0.12, p.z, 10)
			if k % 2 == 0:
				var cible := Vector3(cx + sd[0] * 0.35, y, cz + sd[1] * 0.35)
				var l := p.distance_to(cible)
				var mi: MeshInstance3D = E.faisceau(K, Color("#DDE6FF"), 0.16, l, 1.1, 0.12)
				var pivot := mi.get_parent() as Node3D
				pivot.position = p
				# Le cône descend de la pointe : on l'oriente vers sa cible.
				var dir := (cible - p).normalized()
				pivot.basis = Basis(Quaternion(Vector3.DOWN, dir))
				faisceaux.append(mi)
	# Le combat : la cloche lance le round, puis le chrono le mène jusqu'au repos.
	var etat := {"round": 1, "en_cours": true, "reste": ROUND}
	var foules := []
	for nom in ["foule_gradins", "foule_ring"]:
		var f := K.zone.get_node_or_null(nom) as MultiMeshInstance3D
		if f:
			var m: ShaderMaterial = (f.material_override as ShaderMaterial).duplicate()
			f.material_override = m
			foules.append(m)
	K.chaque_image(func(dt: float, _t: float) -> void:
		etat.reste -= dt
		if etat.reste <= 0.0:
			_cloche(etat)
		var r: float = maxf(0.0, etat.reste)
		var txt := "%s\n%d:%02d" % ["ROUND %d" % etat.round if etat.en_cours else "REPOS", int(r) / 60, int(r) % 60]
		if (textes[0] as Label3D).text != txt:
			for l in textes:
				(l as Label3D).text = txt
		for m in foules:
			(m as ShaderMaterial).set_shader_parameter("saut", 0.04 if etat.en_cours else 0.0)
			(m as ShaderMaterial).set_shader_parameter("tempo", 1.6 if etat.en_cours else 0.6)
		for mi in faisceaux:
			(mi as MeshInstance3D).visible = etat.en_cours)
	var a := K.zone.find_child("cloche", false, false) as Area3D
	if a:
		a.set_meta("etat", etat)


## Un coup de cloche : la fin du round (le repos), ou la reprise au round suivant.
static func _cloche(etat: Dictionary) -> void:
	if etat.en_cours:
		etat.en_cours = false
		etat.reste = REPOS
	else:
		etat.round = 1 if etat.round >= ROUNDS else etat.round + 1
		etat.en_cours = true
		etat.reste = ROUND
