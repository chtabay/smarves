extends RefCounted
## Lot F, la salle de concert « Minuit Live » (js/zones/f-concert.js), derrière le foyer du théâtre,
## x ∈ [4 ; 40], z ∈ [-70 ; -30], au rez-de-chaussée. Deux zones :
##  F-CONCERT      la salle (H 13) : la scène sur l'estrade (y = 1,2) sous son cadre laqué, l'écran LED de fond,
##                 les ponts lumière et leurs lyres, la sonorisation suspendue, la fosse et son public, la
##                 barrière, la régie, les gradins est, le balcon et les loges (décor), le bar et la boutique
##                 sous le balcon, les issues ; les musiciens sur le plateau ;
##  F-CONCERT-SAS  le sas d'entrée [14 ; 22] × [-38 ; -30] sous le balcon : les portes du foyer au sud (x = 16,05
##                 et 19,95), deux sorties latérales vers la salle.
## Les vantaux du foyer sont posés par la scène (minuit.gd) : clos tant que le lieu n'est pas ouvert, ouverts
## en grand au-delà. Le show tourne seul : des morceaux à leur tempo, l'entracte entre deux.

const LOT_E := "res://communes/casino_minuit/zones/lot_e.gd"
const LOT_F := "res://communes/casino_minuit/zones/lot_f.gd"
const H := 13.0
const X0 := 4.0
const X1 := 40.0
const Z0 := -70.0
const Z1 := -30.0
const SC := {"x0": 4.2, "x1": 39.8, "z0": -69.6, "zf": -57.6}
const PRO := {"x0": 10.5, "x1": 33.5, "top": 9.5, "z": -57.9}
const BAL := {"z": -40.5, "y": 4.2, "rows": 9, "d": 0.98, "r": 0.42}
const SAS := {"x0": 14.0, "x1": 22.0, "z0": -38.0, "z1": -30.0, "h": 4.0, "plafond": 3.0, "ex": -36.3, "ew": 2.0}
const REG := {"x0": 18.0, "x1": 23.0, "z0": -44.6, "z1": -41.2}
const GR := {"x": 33.6, "z": -47.5, "w": 13.0, "rows": 7}
const LED := {"x0": 11.0, "x1": 33.0, "y0": 0.45, "y1": 7.7, "z": -69.25}
const SCENE := Vector2(22, -61)
const MUSICIENS := {"chant": [22.0, -59.5, PI], "guitare": [16.4, -60.6, PI + 0.2], "basse": [27.6, -60.6, PI - 0.2],
	"batterie": [22.0, -65.6, PI], "claviers": [31.4, -63.4, PI - 0.7]}
## Le programme du soir : titre, tempo (battements par minute), couleurs.
const MORCEAUX := [["NUIT BLANCHE", 124.0, "#FF4D8D", "#3DE0E0"], ["LE STRIP", 132.0, "#FFB347", "#4D7BFF"],
	["MINUIT PILE", 96.0, "#B04DFF", "#FF3348"], ["DERNIÈRE MAIN", 70.0, "#FFD9A8", "#4D7BFF"]]
const DUREE := 150.0
const ENTRACTE := 20.0


static func construire(K) -> void:
	var E = load(LOT_E)
	var F = load(LOT_F)
	_salle(K, E, F)
	_sas(K, E)


static func _salle(K, E, F) -> void:
	K.zone_debut("F-CONCERT")
	var sy: float = F.Y_ESTRADE
	var zf: float = SC.zf
	# Le sol de béton noir, praticable de la scène au mur du foyer ; le plafond étoilé, les cintres noirs.
	K.dalle(4.2, 39.8, -57.4, -30.2, 0.0)
	K.plan("beton_noir", X0, X1, zf, Z1, 0.0)
	K.plan("noir_mat", X0, X1, -57.9, Z1, H, false)
	K.box("noir_mat", X1 - X0, 0.2, 12.2, (X0 + X1) / 2.0, H + 0.1, -63.9)
	var h := RandomNumberGenerator.new()
	h.seed = 5
	for i in 160:
		K.sph("lumiere" if h.randf() < 0.6 else "ambre_lum", 0.025 + h.randf() * 0.02, h.randf_range(X0 + 0.5, X1 - 0.5), H - 0.03, h.randf_range(-57.5, -40.6))
	# Les murs acoustiques : ouest, est, nord ; au sud, le sas ouvre sur le foyer (le haut du mur reste plein).
	for m in [[4.1, Z0, 4.1, Z1], [39.9, Z0, 39.9, Z1]]:
		K.box("acoustique", 0.2, H, Z1 - Z0, m[0], H / 2.0, (Z0 + Z1) / 2.0)
		K.solide(0.2, H, Z1 - Z0, m[0], H / 2.0, (Z0 + Z1) / 2.0)
	K.box("acoustique", X1 - X0, H, 0.2, (X0 + X1) / 2.0, H / 2.0, -69.9)
	K.solide(X1 - X0, H, 0.2, (X0 + X1) / 2.0, H / 2.0, -69.9)
	for p in [[X0, SAS.x0], [SAS.x1, X1]]:
		K.box("acoustique", p[1] - p[0], H, 0.2, (p[0] + p[1]) / 2.0, H / 2.0, -30.1)
		K.solide(p[1] - p[0], H, 0.2, (p[0] + p[1]) / 2.0, H / 2.0, -30.1)
	K.box("acoustique", SAS.x1 - SAS.x0, H - SAS.h, 0.2, (SAS.x0 + SAS.x1) / 2.0, (H + SAS.h) / 2.0, -30.1)
	for r in [[4.2, 1.0], [39.8, -1.0]]:
		var x: float = r[0]
		var s: float = r[1]
		K.box("noir_satin", 0.06, 1.1, 27.4, x + s * 0.03, 0.55, -43.8)
		var z := -55.0
		while z <= -34.0:
			K.box("or", 0.06, 0.06, 0.3, x + s * 0.04, 1.12, z)
			K.box("ambre_lum", 0.03, H - 4.2, 0.04, x + s * 0.05, 1.2 + (H - 4.2) / 2.0, z + 1.5)
			z += 3.0
		K.box("laque_noire", 0.3, 0.5, 39.6, x + s * 0.15, H - 0.25, -50)
		K.box("or", 0.34, 0.05, 39.6, x + s * 0.17, H - 0.52, -50)
	_scene(K, E, F, sy, zf)
	_ponts(K, E, F, sy)
	_regie_gradins(K, E, F)
	_balcon(K, E, F)
	_dessous(K, E, F)
	_fosse(K, E, F, sy)
	K.zone_fin()


## La scène : le nez de scène et ses caissons de basses, le plancher, l'escalier côté jardin, le cadre laqué et
## doré, les rideaux relevés, les pendrillons, l'écran LED de fond, les instruments.
static func _scene(K, E, F, sy: float, zf: float) -> void:
	var cxs: float = (SC.x0 + SC.x1) / 2.0
	K.box("noir_satin", SC.x1 - SC.x0, sy, 0.3, cxs, sy / 2.0, zf + 0.15)
	var x := 12.5
	while x <= 31.5:
		K.box("gris", 1.9, 0.78, 0.02, x, 0.55, zf + 0.31)
		K.box("noir_mat", 1.7, 0.66, 0.02, x, 0.55, zf + 0.315)
		x += 2.38
	K.box("ambre_lum", SC.x1 - SC.x0, 0.03, 0.04, cxs, sy - 0.03, zf + 0.31)
	K.box("plancher", SC.x1 - SC.x0, 0.06, zf - SC.z0, cxs, sy - 0.03, (SC.z0 + zf) / 2.0)
	K.box("noir_mat", SC.x1 - SC.x0, sy - 0.06, zf - SC.z0 - 0.3, cxs, (sy - 0.06) / 2.0, (SC.z0 + zf) / 2.0 - 0.15)
	K.obstacle(SC.x0, SC.x1, Z0, zf, 0.0, 2.6)
	# L'escalier côté jardin (réservé au personnel), la barrière anti-écrasement.
	for k in 4:
		var t := (k + 0.5) / 4.0
		var hh := sy * (k + 1) / 5.0
		K.box("noir_satin", 1.5, hh, 0.5, 4.95, hh / 2.0, lerpf(-53.4, -57.4, 1.0 - t))
	var barriere := func(ax: float, az: float, bx: float, bz: float) -> void:
		K.beam("alu", Vector3(ax, 1.12, az), Vector3(bx, 1.12, bz), 0.07, 0.07)
		K.beam("noir_satin", Vector3(ax, 0.62, az), Vector3(bx, 0.62, bz), 0.04, 0.95)
		K.beam("gris", Vector3(ax, 0.04, az), Vector3(bx, 0.04, bz), 0.6, 0.06)
		K.segment(ax, az, bx, bz, 0.12, 0.0, 1.3)
	barriere.call(7.6, -55.8, 36.4, -55.8)
	barriere.call(7.6, -55.8, 7.6, -47.0)
	barriere.call(36.4, -55.8, 36.4, -54.2)
	K.texte("ACCÈS SCÈNE · PERSONNEL", 1.6, 0.14, 7.66, 1.42, -50.5, PI / 2.0)
	K.places["f_vigiles_fosse"] = [[Vector3(6.2, 0, -48.2), PI / 2.0], [Vector3(12.5, 0, -56.6), PI], [Vector3(22, 0, -56.6), PI], [Vector3(31.5, 0, -56.6), PI]]
	# Le cadre de scène : murs noirs de part et d'autre, linteau, pilastres laqués rouges, bandeau « MINUIT LIVE ».
	var pz: float = PRO.z
	var top: float = PRO.top
	for p in [[X0, PRO.x0], [PRO.x1, X1]]:
		K.box("noir_mat", p[1] - p[0], H, 0.2, (p[0] + p[1]) / 2.0, H / 2.0, pz)
	K.box("noir_mat", PRO.x1 - PRO.x0, H - top, 0.2, 22, (H + top) / 2.0, pz)
	K.obstacle(X0, 4.2, pz - 0.1, pz + 0.1)
	K.obstacle(PRO.x1, X1, pz - 0.1, pz + 0.1)
	for px in [PRO.x0 - 0.55, PRO.x1 + 0.55]:
		K.box("laque_rouge", 1.1, top - sy + 0.6, 0.36, px, sy + (top - sy + 0.6) / 2.0, pz + 0.3)
		K.box("or", 1.24, 0.16, 0.44, px, sy + 0.08, pz + 0.3)
		var y := sy + 0.8
		while y < top:
			K.box("or", 0.9, 0.05, 0.38, px, y, pz + 0.32)
			y += 1.1
		K.box("or", 1.3, 0.4, 0.5, px, top + 0.5, pz + 0.3)
	K.box("laque_rouge", PRO.x1 - PRO.x0 + 2.2, 1.5, 0.36, 22, top + 0.75, pz + 0.3)
	K.box("or", PRO.x1 - PRO.x0 + 2.4, 0.12, 0.46, 22, top + 0.06, pz + 0.3)
	K.box("or", PRO.x1 - PRO.x0 + 2.4, 0.12, 0.46, 22, top + 1.5, pz + 0.3)
	K.texte("MINUIT LIVE", 6.4, 1.0, 22, top + 0.78, pz + 0.5, 0, "neon", Color("#FFE2B4"))
	# Le rideau à l'italienne relevé (deux pans drapés), le lambrequin, les pendrillons et la frise.
	for s in [-1.0, 1.0]:
		var rx: float = PRO.x0 + 1.3 if s < 0 else PRO.x1 - 1.3
		for k in 5:
			K.box("velours", 0.5, top - sy, 0.16, rx + s * (k - 2) * 0.48, sy + (top - sy) / 2.0, pz - 0.25 + (k % 2) * 0.08)
	K.box("velours", PRO.x1 - PRO.x0, 1.6, 0.12, 22, top - 0.8, pz - 0.18)
	var fx: float = PRO.x0 + 1.6
	while fx < PRO.x1 - 1.0:
		K.sph("velours", 0.9, fx, top - 1.6, pz - 0.2, 0.45)
		fx += 3.3
	K.box("or", PRO.x1 - PRO.x0, 0.05, 0.06, 22, top - 0.02, pz - 0.26)
	for p in [[SC.x0 + 2.3, 4.6], [SC.x1 - 2.3, 4.6]]:
		K.box("noir_mat", p[1], H - sy, 0.08, p[0], sy + (H - sy) / 2.0, -60.4)
	K.box("noir_mat", 30, 1.6, 0.08, 22, top + 0.4, -60.6)
	# Les ampoules du cadre (le chenillard est dans le matériau).
	E.ampoules(K, Vector3(PRO.x0 - 0.1, sy + 0.35, pz + 0.52), Vector3(PRO.x0 - 0.1, top - 0.1, pz + 0.52), 0.11, 0)
	E.ampoules(K, Vector3(PRO.x1 + 0.1, sy + 0.35, pz + 0.52), Vector3(PRO.x1 + 0.1, top - 0.1, pz + 0.52), 0.11, 0)
	E.ampoules(K, Vector3(PRO.x0 + 0.1, top - 0.12, pz + 0.52), Vector3(PRO.x1 - 0.1, top - 0.12, pz + 0.52), 0.11, 0)
	# L'écran LED de fond de scène et son titre.
	var lw: float = LED.x1 - LED.x0
	var lh: float = LED.y1 - LED.y0
	var ly: float = sy + (LED.y0 + LED.y1) / 2.0
	K.box("noir_satin", lw + 0.4, lh + 0.4, 0.3, 22, ly, LED.z - 0.17)
	K.box("noir_satin", lw + 0.6, LED.y0, 0.6, 22, sy + LED.y0 / 2.0, LED.z - 0.1)
	E.ecran(K, 22, ly, LED.z, lw, lh, 0, E.LED_ROSE, 0.0)
	var titre: Label3D = K.texte(MORCEAUX[0][0], lw * 0.8, 1.3, 22, ly, LED.z + 0.04, 0, "neon", Color("#FFF6E2"))
	K.places["f_concert_titre"] = titre
	# Les instruments : la batterie sur son praticable, les amplis, les claviers, les pieds de micro.
	var b: Array = MUSICIENS.batterie
	K.box("noir_satin", 3.6, 0.4, 2.8, b[0], sy + 0.2, b[1] + 0.2)
	for t in [[-0.6, -0.5, 0.28], [0.6, -0.5, 0.25], [0.0, 0.1, 0.36], [-1.1, 0.1, 0.22], [1.1, 0.1, 0.22]]:
		K.cyl("rouge_e", t[2], t[2], 0.3, b[0] + t[0], sy + 0.4 + 0.45, b[1] + t[1] - 0.9, 14)
		K.cyl("chrome", t[2] + 0.01, t[2] + 0.01, 0.02, b[0] + t[0], sy + 0.4 + 0.61, b[1] + t[1] - 0.9, 14)
	for c in [[-1.3, -1.5], [1.3, -1.5], [0.9, -0.2]]:
		K.cyl("chrome", 0.012, 0.012, 1.1, b[0] + c[0], sy + 0.95, b[1] + c[1], 5)
		K.cyl("or", 0.32, 0.32, 0.01, b[0] + c[0], sy + 1.5, b[1] + c[1], 16)
	for a in [[14.2, -63.0], [17.6, -63.0], [26.4, -63.0], [29.8, -63.0]]:
		K.box("noir_satin", 1.4, 1.6, 0.7, a[0], sy + 0.8, a[1])
		K.box("gris", 1.3, 1.1, 0.02, a[0], sy + 0.95, a[1] + 0.36)
	var kb: Array = MUSICIENS.claviers
	K.box("noir_satin", 1.4, 0.08, 0.4, kb[0] - 0.4, sy + 0.95, kb[1] - 0.45)
	K.box("blanc_ring", 1.3, 0.02, 0.18, kb[0] - 0.4, sy + 1.0, kb[1] - 0.55)
	K.cyl("chrome", 0.02, 0.02, 0.9, kb[0] - 0.4, sy + 0.45, kb[1] - 0.45, 5)
	for m in [MUSICIENS.chant, MUSICIENS.guitare, MUSICIENS.basse]:
		K.cyl("chrome", 0.012, 0.012, 1.5, m[0] + sin(m[2]) * 0.55, sy + 0.75, m[1] + cos(m[2]) * 0.55, 5)
		K.sph("noir_satin", 0.04, m[0] + sin(m[2]) * 0.5, sy + 1.55, m[1] + cos(m[2]) * 0.5)
		K.box("noir_satin", 0.5, 0.3, 0.4, m[0] + sin(m[2]) * 1.4, sy + 0.15, m[1] + cos(m[2]) * 1.4, m[2])
	var musiciens := {}
	for nom in MUSICIENS:
		var mu: Array = MUSICIENS[nom]
		musiciens[nom] = [Vector3(mu[0], sy + (0.4 if nom == "batterie" else 0.0), mu[1]), mu[2] + PI]
	K.places["f_musiciens"] = musiciens


## Les ponts lumière, les lyres et leurs faisceaux, la sonorisation suspendue, les lumières du show et son
## animation (morceaux, tempo, entracte).
static func _ponts(K, E, F, sy: float) -> void:
	F.ligne_son(K, 8.4, 10.6, -57.2, 0.22, 9)
	F.ligne_son(K, 35.6, 10.6, -57.2, -0.22, 9)
	for x in [7.6, 36.4]:
		K.beam("gris", Vector3(x, 11.6, -57.2), Vector3(x, H, -57.2), 0.03, 0.03)
	F.treillis(K, Vector3(9, 9.8, -62.2), Vector3(35, 9.8, -62.2))
	F.treillis(K, Vector3(9, 9.8, -67.4), Vector3(35, 9.8, -67.4))
	F.treillis(K, Vector3(8, 10.4, -56.4), Vector3(36, 10.4, -56.4))
	for p in [[9.0, -62.2, 9.8], [35.0, -62.2, 9.8], [9.0, -67.4, 9.8], [35.0, -67.4, 9.8], [8.0, -56.4, 10.4], [36.0, -56.4, 10.4]]:
		K.beam("gris", Vector3(p[0], p[2] + 0.2, p[1]), Vector3(p[0], H, p[1]), 0.025, 0.025)
	var lyres := []
	for x in [12.0, 16.4, 20.2, 23.8, 27.6, 32.0]:
		lyres.append([Vector3(x, 9.42, -62.2), 0])
	for x in [13.0, 18.5, 25.5, 31.0]:
		lyres.append([Vector3(x, 9.42, -67.4), 1])
	for x in [11.0, 16.5, 27.5, 33.0]:
		lyres.append([Vector3(x, 10.02, -56.4), 2])
	var faisceaux := []
	for i in lyres.size():
		var p: Vector3 = lyres[i][0]
		K.box("noir_satin", 0.34, 0.14, 0.3, p.x, p.y + 0.3, p.z)
		for s in [-1.0, 1.0]:
			K.box("noir_satin", 0.04, 0.34, 0.08, p.x + s * 0.17, p.y + 0.12, p.z)
		K.box("noir_satin", 0.28, 0.32, 0.28, p.x, p.y, p.z)
		K.cyl("blanc_froid", 0.09, 0.09, 0.02, p.x, p.y - 0.17, p.z, 10)
		var mi: MeshInstance3D = E.faisceau(K, Color.WHITE, 0.3, 16.0, 1.4, 0.1)
		var pivot := mi.get_parent() as Node3D
		pivot.position = p - Vector3(0, 0.18, 0)
		faisceaux.append([pivot, mi.material_override, lyres[i][1], p])
	# Les aveuglants du pont avant, les poursuites du balcon.
	for x in [14.5, 19.5, 24.5, 29.5]:
		K.box("noir_satin", 0.9, 0.36, 0.2, x, 9.95, -56.2)
		for dx in [-0.22, 0.22]:
			K.cyl("ambre_lum", 0.1, 0.1, 0.02, x + dx, 9.95, -56.09, 10, PI / 2.0)
	var poursuites := []
	for x in [12.5, 31.5]:
		var y: float = BAL.y + 1.05
		K.cyl("noir_satin", 0.17, 0.2, 0.9, x, y + 0.1, -40.3, 10, PI / 2.0 - 0.2)
		K.cyl("gris", 0.03, 0.05, 1.0, x, y - 0.6, -40.2, 6)
		var m: Array = MUSICIENS.chant
		var cible := Vector3(m[0], sy + 0.9, m[1])
		var src := Vector3(x, y + 0.2, -40.7)
		var mi: MeshInstance3D = E.faisceau(K, Color("#FFF0DC"), 0.22, src.distance_to(cible), 0.6, 0.06)
		var pivot := mi.get_parent() as Node3D
		pivot.position = src
		pivot.basis = Basis(Quaternion(Vector3.DOWN, (cible - src).normalized()))
		poursuites.append(mi)
	# Les lumières réelles : trois lavis sur le plateau, la lumière de salle.
	var lavis := []
	for x in [14.0, 22.0, 30.0]:
		lavis.append(K.lumiere(x, sy + 6.5, -62, Color("#FF4D8D"), 2.2, 16.0))
	var salle: OmniLight3D = K.lumiere(22, 9, -46, Color("#6A5AFF"), 1.0, 26.0)
	# Le show.
	var titre: Label3D = K.places.get("f_concert_titre")
	var etat := {"morceau": 0, "debut": 0.0}
	K.places["f_concert_etat"] = etat
	K.chaque_image(func(_dt: float, t: float) -> void:
		var tau: float = t - etat.debut
		if tau > DUREE + ENTRACTE:
			etat.morceau = (etat.morceau + 1) % MORCEAUX.size()
			etat.debut = t
			tau = 0.0
		var M: Array = MORCEAUX[etat.morceau]
		var joue := tau < DUREE
		var bpm: float = M[1]
		var bp := tau * bpm / 60.0
		var ph := bp - floorf(bp)
		var pouls := pow(1.0 - ph, 2.2)
		var en := (0.6 + 0.4 * sin(tau * 0.07)) if joue else 0.05
		var cA := Color(M[2])
		var cB := Color(M[3])
		var pat := int(bp / 32.0) % 4
		var txt: String = M[0] if joue else "ENTRACTE"
		if titre and titre.text != txt:
			titre.text = txt
		if titre:
			titre.visible = not joue or int(bp / 4.0) % 16 < 3
		for i in faisceaux.size():
			var f: Array = faisceaux[i]
			var p: Vector3 = f[3]
			var k := float(i) / faisceaux.size()
			var cible := Vector3()
			match pat:
				0: cible = Vector3(22 + sin(t * 0.9 + k * 6) * 14, 0, -48 + cos(t * 0.6 + k * 4) * 6)
				1: cible = Vector3(p.x + (p.x - 22) * 0.6 * pouls * en, sy, -52 - pouls * 4 if f[2] == 2 else -60.0)
				2: cible = Vector3(22 - (p.x - 22) * 1.3 + sin(t * 1.3) * 2, 0, -47 + (f[2] - 1) * 4)
				_: cible = Vector3(p.x + sin(t * 2.1 + i * 1.7) * 5, 0, -50 + cos(t * 1.7 + i * 1.3) * 6)
			(f[0] as Node3D).basis = Basis(Quaternion(Vector3.DOWN, (cible - p).normalized()))
			var c := cA if (int(bp / 2.0) + i) % 2 else cB
			var br := en * (0.35 + 0.65 * (pouls if pat == 1 else 0.6 + 0.4 * pouls))
			(f[1] as ShaderMaterial).set_shader_parameter("couleur", c)
			(f[1] as ShaderMaterial).set_shader_parameter("gain", 0.3 * br)
		for mi in poursuites:
			(mi as MeshInstance3D).visible = joue
		for i in lavis.size():
			var l: OmniLight3D = lavis[i]
			l.light_color = cB if i == 1 else cA
			l.light_energy = (1.4 + 3.6 * en * (0.55 + 0.45 * pouls)) * (1.0 if joue else 0.35)
		salle.light_energy = 0.8 if joue else 1.6
		var foule: ShaderMaterial = K.places.get("f_concert_foule")
		if foule:
			foule.set_shader_parameter("tempo", bpm / 60.0 if joue else 0.3)
			foule.set_shader_parameter("saut", maxf(0.0, en - 0.45) * 0.32 if joue else 0.0)
			foule.set_shader_parameter("balance", 0.5 + en * 0.5 if joue else 0.2))


## La régie (consoles son et lumière, deux techniciens) et les gradins est.
static func _regie_gradins(K, E, F) -> void:
	var rx: float = (REG.x0 + REG.x1) / 2.0
	var rz: float = (REG.z0 + REG.z1) / 2.0
	K.box("noir_satin", REG.x1 - REG.x0, 0.3, REG.z1 - REG.z0, rx, 0.15, rz)
	K.box("ambre_lum", REG.x1 - REG.x0, 0.025, 0.03, rx, 0.29, REG.z0 - 0.01)
	for s in [[REG.x0, REG.z0, REG.x1, REG.z0], [REG.x0, REG.z0, REG.x0, REG.z1], [REG.x1, REG.z0, REG.x1, REG.z1], [REG.x0, REG.z1, rx - 1.25, REG.z1], [rx + 1.25, REG.z1, REG.x1, REG.z1]]:
		K.beam("alu", Vector3(s[0], 1.3, s[1]), Vector3(s[2], 1.3, s[3]), 0.05, 0.05)
		K.cyl("alu", 0.025, 0.025, 1.0, s[0], 0.8, s[1], 6)
		K.cyl("alu", 0.025, 0.025, 1.0, s[2], 0.8, s[3], 6)
	var techniciens := []
	for i in 2:
		var x: float = rx - 1.2 if i == 0 else rx + 1.2
		K.box("noir_satin", 2.0, 0.85, 0.8, x, 0.72, REG.z0 + 0.75)
		K.box("gris", 2.0, 0.06, 0.95, x, 1.18, REG.z0 + 0.8)
		for j in 14:
			K.box("cyan_lum" if i else "ambre_lum", 0.025, 0.012, 0.18, x - 0.9 + j * 0.13, 1.23, REG.z0 + 0.84)
		for ox in [-0.45, 0.45]:
			K.box("noir_satin", 0.62, 0.42, 0.04, x + ox, 1.5, REG.z0 + 0.42)
			K.box("ecran_bleu" if i else "ecran_or", 0.56, 0.36, 0.01, x + ox, 1.5, REG.z0 + 0.447)
		techniciens.append([Vector3(x, 0.3, REG.z0 + 1.8), 0.0])
	K.places["f_regie"] = techniciens
	K.obstacle(REG.x0 - 0.05, REG.x1 + 0.05, REG.z0 - 0.05, REG.z0 + 1.2, 0.0, 1.4)
	K.obstacle(REG.x0 - 0.05, rx - 1.25, REG.z1 - 0.2, REG.z1 + 0.05, 0.0, 1.4)
	K.obstacle(rx + 1.25, REG.x1 + 0.05, REG.z1 - 0.2, REG.z1 + 0.05, 0.0, 1.4)
	K.obstacle(REG.x0 - 0.05, REG.x0 + 0.1, REG.z0, REG.z1, 0.0, 1.4)
	K.obstacle(REG.x1 - 0.1, REG.x1 + 0.05, REG.z0, REG.z1, 0.0, 1.4)
	var sieges := []
	var g: Dictionary = F.gradins(K, {"x": GR.x, "z": GR.z, "rot": PI / 2.0, "width": GR.w, "rows": GR.rows, "depth": 0.88, "rise": 0.42,
		"aisles": [0.0], "look": SCENE, "seed": 11, "places": 2, "occupation": 0.82, "nez": "ambre_lum"}, sieges)
	K.places["f_concert_gradins"] = g.places
	K.places["f_concert_public"] = g.foule
	K.places["f_concert_sieges"] = sieges


## Le balcon (décor) : ses gradins et leur public, son bandeau laqué, son garde-corps, et les loges des murs.
static func _balcon(K, E, F) -> void:
	var sieges: Array = K.places.get("f_concert_sieges", [])
	var public: Array = K.places.get("f_concert_public", [])
	var by: float = BAL.y
	var bz: float = BAL.z
	var g: Dictionary = F.gradins(K, {"x": 22.0, "z": bz + 0.42, "rot": 0.0, "y": by, "width": 35.4, "rows": BAL.rows, "depth": BAL.d, "rise": BAL.r,
		"aisles": [-9.5, 9.5], "look": SCENE, "seed": 12, "places": 0, "occupation": 0.78, "collision": false, "bouts": false, "nez": "ambre_lum"}, sieges)
	public.append_array(g.foule)
	K.box("noir_mat", 35.6, 0.25, 10.4, 22, by - 0.12, -35.3)
	K.box("laque_rouge", 35.6, 1.3, 0.22, 22, by + 0.05, bz - 0.08)
	K.box("or", 35.7, 0.07, 0.3, 22, by + 0.72, bz - 0.08)
	K.box("or", 35.7, 0.07, 0.3, 22, by - 0.6, bz - 0.08)
	K.box("ambre_lum", 35.6, 0.035, 0.04, 22, by - 0.66, bz - 0.2)
	K.beam("or", Vector3(4.2, by + 1.05, bz + 0.05), Vector3(39.8, by + 1.05, bz + 0.05), 0.06, 0.06)
	var x := 5.0
	while x < 39.6:
		K.cyl("or", 0.02, 0.02, 0.36, x, by + 0.86, bz + 0.05, 6)
		x += 1.6
	K.texte("M I N U I T   L I V E", 6.5, 0.5, 22, by + 0.1, bz - 0.2, PI)
	# La sous-face : plafond bas, spots encastrés.
	K.plan("plafond_bas", 4.2, 39.8, bz, -30.2, SAS.h, false)
	x = 6.0
	while x < 39.0:
		var z := -39.2
		while z < -31.0:
			if not (x > SAS.x0 - 0.5 and x < SAS.x1 + 0.5):
				K.cyl("blanc_froid", 0.09, 0.09, 0.02, x, SAS.h - 0.01, z, 10)
			z += 3.4
		x += 3.2
	# Les loges suspendues sur les murs latéraux.
	var loges := []
	var lg := [[5.3, -51.5, 1.0], [5.3, -45.5, 1.0], [38.7, -53.0, -1.0], [38.7, -46.5, -1.0]]
	for i in lg.size():
		var l: Array = lg[i]
		var y := 4.6 if i < 2 else 5.0
		var s: float = l[2]
		var ry := -PI / 2.0 if s > 0 else PI / 2.0
		K.box("noir_mat", 2.2, 0.25, 3.4, l[0], y - 0.12, l[1])
		K.box("laque_rouge", 0.12, 1.05, 3.4, l[0] + s * 1.1, y + 0.5, l[1])
		K.box("or", 0.2, 0.07, 3.5, l[0] + s * 1.12, y + 1.05, l[1])
		K.box("or", 0.16, 0.06, 3.5, l[0] + s * 1.12, y - 0.02, l[1])
		K.box("ambre_lum", 0.04, 0.03, 3.3, l[0] + s * 1.18, y - 0.1, l[1])
		K.box("capiton_rouge", 0.06, 2.4, 3.4, l[0] - s * 1.05, y + 1.2, l[1])
		K.lanterne(l[0] - s * 0.9, y + 1.8, l[1], 0.35)
		for j in 3:
			if (i + j) % 3 != 2:
				loges.append([l[0] + s * 0.55, y, l[1] + (j - 1) * 0.9, ry])
	K.places["f_concert_loges"] = loges
	F.sieges(K, sieges, "capiton_rouge", false, "sieges_concert")


## Sous le balcon : le bar de salle (ouest), la boutique officielle et les mange-debout (est), les issues.
static func _dessous(K, E, F) -> void:
	K.box("bois_laque", 7.0, 1.1, 0.8, 8.7, 0.55, -33.6)
	K.box("marbre_noir", 7.2, 0.06, 1.0, 8.7, 1.13, -33.6)
	K.box("rose_lum", 7.0, 0.03, 0.03, 8.7, 0.1, -34.02)
	K.box("laque_noire", 7.0, 2.6, 0.5, 8.7, 1.3, -30.5)
	for k in 4:
		K.box("verre", 6.8, 0.02, 0.4, 8.7, 1.2 + k * 0.45, -30.7)
	K.obstacle(5.2, 12.2, -34.0, -33.2, 0.0, 1.3)
	E.enseigne(K, "BAR", "#FF4D8D", 2.2, 0.8, 8.7, 3.45, -30.78, PI)
	var tabourets := []
	for o in [-2.8, -1.7, -0.6, 0.5, 1.6, 2.7]:
		K.cyl("laque_noire", 0.2, 0.2, 0.06, 8.7 + o, 0.75, -34.5, 12)
		K.cyl("or", 0.03, 0.03, 0.72, 8.7 + o, 0.38, -34.5, 6)
		tabourets.append([Vector3(8.7 + o, 0.78, -34.5), 0.0])
	K.places["f_concert_bar"] = {"barman": [Vector3(6.0, 0, -32.2), Vector3(11.4, 0, -32.2)], "tabourets": tabourets}
	K.lumiere(8.7, 3.3, -35.5, Color("#FFB070"), 1.4, 5.5)
	var bx := 32.5
	var bz := -31.3
	K.box("laque_noire", 6, 1.05, 0.7, bx, 0.52, bz - 0.9)
	K.box("marbre_noir", 6.1, 0.05, 0.8, bx, 1.07, bz - 0.9)
	K.box("ambre_lum", 5.8, 0.03, 0.03, bx, 0.12, bz - 1.26)
	K.box("noir_satin", 6.4, 3.2, 0.1, bx, 1.9, -30.25)
	for i in 5:
		var tx := bx - 2.4 + i * 1.2
		K.box("laque_rouge" if i % 2 else "noir_mat", 0.7, 0.85, 0.02, tx, 2.2, -30.18)
		K.box("or", 0.03, 0.03, 0.5, tx, 2.66, -30.3)
	E.enseigne(K, "BOUTIQUE OFFICIELLE", "#3DE0E0", 4.2, 0.55, bx, 3.55, -30.18, PI)
	K.obstacle(bx - 3.05, bx + 3.05, bz - 1.28, bz - 0.52, 0.0, 1.2)
	K.places["f_concert_boutique"] = {"vendeur": [Vector3(bx, 0, bz + 0.2), PI], "clients": [[Vector3(bx - 1.0, 0, bz - 1.85), 0.0], [Vector3(bx + 0.8, 0, bz - 1.85), 0.0]]}
	var duos := []
	for m in [[26.2, -36.2], [29.4, -37.6], [33.6, -36.4], [36.8, -38.2]]:
		K.cyl("marbre_noir", 0.35, 0.35, 0.04, m[0], 1.08, m[1], 16)
		K.cyl("or", 0.04, 0.04, 1.06, m[0], 0.53, m[1], 6)
		K.rond(m[0], m[1], 0.4)
		duos.append([Vector3(m[0] - 0.7, 0, m[1]), -PI / 2.0])
		duos.append([Vector3(m[0] + 0.7, 0, m[1]), PI / 2.0])
	K.places["f_concert_duos"] = duos
	for i in [[4.22, -44.6, PI / 2.0], [4.22, -38.9, PI / 2.0], [39.78, -37.2, -PI / 2.0], [39.78, -55.6, -PI / 2.0]]:
		F.issue(K, i[0], i[1], i[2])
	for x in [4.6, 39.4]:
		for k in 6:
			K.box("vert_lum", 0.12, 0.012, 0.04, x, 0.01, -48 + k * 1.6)


## La fosse : le public dense contre la barrière, les danseurs derrière, et toute la foule d'imposteurs de la
## salle (fosse, gradins hauts, balcon, loges) en un seul lot.
static func _fosse(K, E, F, sy: float) -> void:
	var public: Array = K.places.get("f_concert_public", [])
	var h := RandomNumberGenerator.new()
	h.seed = 21
	var debout := []
	var z := -55.3
	while z <= -50.6:
		var x := 8.1
		while x <= 31.7:
			if h.randf() >= 0.12:
				var px := x + (h.randf() - 0.5) * 0.3
				var pz := z + (h.randf() - 0.5) * 0.24
				debout.append([px, 0.0, pz, F.vers(px, pz, SCENE.x, SCENE.y) + (h.randf() - 0.5) * 0.4])
			x += 0.5
		z += 0.52
	K.obstacle(7.9, 32.0, -55.6, -50.35, 0.0, 1.8)
	var danse := []
	var r := 0
	z = -49.6
	while z <= -41.5:
		var x: float = 9.2 + (r % 2) * 0.8
		while x <= 32.2:
			if not (x > REG.x0 - 1 and x < REG.x1 + 1 and z > REG.z0 - 1.2) and x <= GR.x - 1.3:
				danse.append([Vector3(x, 0, z), F.vers(x, z, SCENE.x, SCENE.y)])
			x += 1.9
		z += 1.62
		r += 1
	K.places["f_concert_danse"] = danse
	K.places["f_concert_regards"] = [[Vector3(12, 0, -40.5), F.vers(12, -40.5, SCENE.x, SCENE.y)], [Vector3(15.5, 0, -39.4), F.vers(15.5, -39.4, SCENE.x, SCENE.y)],
		[Vector3(27, 0, -40.2), F.vers(27, -40.2, SCENE.x, SCENE.y)], [Vector3(29.8, 0, -39), F.vers(29.8, -39, SCENE.x, SCENE.y)]]
	var assis: MultiMeshInstance3D = E.foule(K, public, "assis", 31, "foule_concert_assis")
	var fosse: MultiMeshInstance3D = E.foule(K, debout, "bras", 32, "foule_concert_fosse")
	var loges: MultiMeshInstance3D = E.foule(K, K.places.get("f_concert_loges", []), "debout", 33, "foule_concert_loges")
	# Un seul matériau pour toute la foule de la salle : le show le pilote (tempo, saut, balancement).
	var m: ShaderMaterial = (K.mat("foule") as ShaderMaterial).duplicate()
	for mi in [assis, fosse, loges]:
		(mi as MultiMeshInstance3D).material_override = m
	K.places["f_concert_foule"] = m


# --- F-CONCERT-SAS : le sas entre le foyer et la salle ------------------------------------------------

static func _sas(K, E) -> void:
	K.zone_debut("F-CONCERT-SAS")
	var x0: float = SAS.x0
	var x1: float = SAS.x1
	var z0: float = SAS.z0
	var z1: float = SAS.z1
	var hp: float = SAS.plafond
	K.dalle(x0, x1, z0, z1, 0.0)
	K.plan("moquette_e", x0, x1, z0, z1, 0.004)
	K.plan("plafond_bas", x0, x1, z0, z1, hp, false)
	# Les murs : sorties latérales vers la salle (ouest, est), nord plein.
	var ew: float = SAS.ew
	var ex: float = SAS.ex
	for s in [[x0 + 0.1, 1.0], [x1 - 0.1, -1.0]]:
		var x: float = s[0]
		for p in [[z0, ex - ew / 2.0], [ex + ew / 2.0, z1]]:
			K.box("acoustique", 0.2, SAS.h, p[1] - p[0], x, SAS.h / 2.0, (p[0] + p[1]) / 2.0)
			K.solide(0.2, SAS.h, p[1] - p[0], x, SAS.h / 2.0, (p[0] + p[1]) / 2.0)
		K.box("acoustique", 0.2, SAS.h - 2.7, ew, x, (SAS.h + 2.7) / 2.0, ex)
		for k in [-1.0, 1.0]:
			K.box("or", 0.3, 2.8, 0.08, x + s[1] * 0.12, 1.4, ex + k * (ew / 2.0 + 0.04))
			K.box("velours", 0.1, 2.7, 0.34, x + s[1] * 0.2, 1.35, ex + k * (ew / 2.0 - 0.12))
		K.box("or", 0.3, 0.08, ew + 0.2, x + s[1] * 0.12, 2.74, ex)
	K.box("acoustique", x1 - x0, SAS.h, 0.2, (x0 + x1) / 2.0, SAS.h / 2.0, z0 + 0.1)
	K.solide(x1 - x0, SAS.h, 0.2, (x0 + x1) / 2.0, SAS.h / 2.0, z0 + 0.1)
	# Le parement côté sas du mur du foyer, les encadrements de ses portes.
	for p in [[x0, 15.1], [17.0, 19.0], [20.9, x1]]:
		K.box("capiton_rouge", p[1] - p[0], hp, 0.04, (p[0] + p[1]) / 2.0, hp / 2.0, -30.23)
	for x in [16.05, 19.95]:
		K.box("or", 2.0, 0.1, 0.12, x, 2.72, -30.27)
		for s in [-1.0, 1.0]:
			K.box("or", 0.08, 2.72, 0.12, x + s * 0.98, 1.36, -30.27)
	K.texte("← SALLE · FOSSE ET GRADINS", 3.0, 0.22, (x0 + x1) / 2.0, 2.4, z0 + 0.22, 0)
	for i in 3:
		K.cyl("blanc_froid", 0.09, 0.09, 0.02, 16 + i * 2.0, hp - 0.01, -34, 10)
	K.places["f_ouvreurs"] = [[Vector3(15.2, 0, -36.3), -PI / 2.0], [Vector3(20.8, 0, -36.3), PI / 2.0]]
	K.zone_fin()
