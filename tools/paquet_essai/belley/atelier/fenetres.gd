extends RefCounted
## Les fenêtres maillées, au niveau des façadiers de la bibliothèque (facadier-du-bugey@1, _fenetre) : la vitre au
## fond de son tableau, l'encadrement de pierre de taille qui fait saillie, l'appui et le linteau, la croisée
## blanche, les volets de bois ouverts contre le mur (ou fermés), la jardinière de géraniums ; au rez-de-chaussée,
## une porte sur trois ou quatre, de chêne, sous son linteau, sur sa marche. On les pose devant un mur dont le
## shader ne dessine plus les fenêtres (outils.mur, maillee) ; elles suivent le même rythme de travées.
##   FENETRES.facade(o, a, b, y0, h, n, graine)

const OUTILS := preload("res://communes/belley/atelier/outils.gd")

const TRAVEE := 3.3
const RDC := 3.4
const ETAGE := 3.0
const TAILLE := Color("e8dbb8")
const TAILLE_SOMBRE := Color("cdbf9c")
const VERRE := Color("33404c", 0.1)
const BLANC := Color("efe9dc", 0.9)
const FER := Color("2a2d30", 0.6)
const TERRE_CUITE := Color("b8643f", 0.9)
const FEUILLES := Color("4f8a2e")
const FLEURS := [Color("d8343a"), Color("e0605a"), Color("d04a8a"), Color("f4f0e6")]
## Les volets du Bugey : vert d'eau, gris bleu, bois, gris perle, vert sapin, lie-de-vin (ceux du shader).
const VOLETS := [Color("7d918c", 0.6), Color("8fa3b2", 0.6), Color("9e6b4d", 0.6), Color("ccc7b3", 0.6), Color("6b8066", 0.6), Color("8c5c54", 0.6)]
const PORTES := [Color("6b4a32", 0.7), Color("5a3a28", 0.7), Color("4f6f8f", 0.6), Color("7a2f2a", 0.6), Color("5f7d5a", 0.6)]


## Les fenêtres d'un mur de a à b (au pied, à y0), haut de h, sa normale n vers la rue. Rend le nombre de baies.
static func facade(o: RefCounted, a: Vector3, b: Vector3, h: float, n: Vector3, graine: int) -> int:
	var l := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	var nb := int(floor((l - 1.2) / TRAVEE))
	if nb <= 0:
		return 0
	var pas := (l - 1.2) / nb
	var d := (b - a).normalized()
	d.y = 0.0
	d = d.normalized()
	var base := Basis(d, Vector3.UP, n)
	var volet: Color = VOLETS[graine % VOLETS.size()]
	var porte: Color = PORTES[graine % PORTES.size()]
	var compte := 0
	for i in nb:
		var x := 0.6 + (i + 0.5) * pas
		var niv := 0
		var y := 0.0
		while true:
			var haut_niv := RDC if niv == 0 else ETAGE
			if y + haut_niv > h - 0.9 + 0.01 and niv > 0:
				break
			var g := absi(hash(Vector3i(graine, i, niv)))
			var pied := a + d * x + Vector3(0, y, 0)
			var t := Transform3D(base, pied)
			if niv == 0 and g % 100 < 28:
				_porte(o, t, porte, g)
			else:
				var hf := 2.3 if niv == 0 else 1.7
				var bas := 0.9 if niv == 0 else 0.95
				_fenetre(o, t * Transform3D(Basis(), Vector3(0, bas, 0)), 1.24, hf, volet, g, niv > 0 and g % 100 < 30)
			compte += 1
			y += haut_niv
			niv += 1
			if y > h - 0.9:
				break
	return compte


## Une fenêtre dans le repère t (x le long du mur, y vers le haut, z hors du mur), son pied au milieu de l'appui.
## Sans volets (volets faux) : la fenêtre d'une lucarne, étroite sous son fronton.
static func _fenetre(o: RefCounted, t: Transform3D, l: float, hf: float, volet: Color, g: int, jardiniere: bool, volets := true) -> void:
	var e := 0.14
	# La vitre, au fond du tableau, et la croisée.
	o.quad(t * Vector3(-l * 0.5, 0, 0.012), t * Vector3(l * 0.5, 0, 0.012), t * Vector3(l * 0.5, hf, 0.012), t * Vector3(-l * 0.5, hf, 0.012), t.basis.z, VERRE, OUTILS.VITRE)
	o.saillie(t * Transform3D(Basis(), Vector3(0, hf * 0.5, 0.04)), Vector3(0.06, hf, 0.04), BLANC, OUTILS.PEINT)
	o.saillie(t * Transform3D(Basis(), Vector3(0, hf * 0.62, 0.04)), Vector3(l, 0.05, 0.04), BLANC, OUTILS.PEINT)
	for s: float in [-1.0, 1.0]:
		o.saillie(t * Transform3D(Basis(), Vector3(s * (l * 0.5 - 0.03), hf * 0.5, 0.035)), Vector3(0.06, hf, 0.05), BLANC, OUTILS.PEINT)
	# L'encadrement de pierre de taille, qui fait saillie : la vitre paraît au fond de son tableau.
	for s: float in [-1.0, 1.0]:
		o.saillie(t * Transform3D(Basis(), Vector3(s * (l * 0.5 + e * 0.5), hf * 0.5, 0.06)), Vector3(e, hf + 0.02, 0.12), TAILLE, OUTILS.PIERRE)
	o.saillie(t * Transform3D(Basis(), Vector3(0, hf + 0.13, 0.07)), Vector3(l + e * 2.0 + 0.1, 0.26, 0.14), TAILLE, OUTILS.PIERRE)
	o.saillie(t * Transform3D(Basis(), Vector3(0, -0.05, 0.13)), Vector3(l + e * 2.0 + 0.16, 0.1, 0.26), TAILLE_SOMBRE.lightened(0.08), OUTILS.PIERRE)
	# Les volets de bois, à barres et écharpe : ouverts contre le mur, ou fermés (un sur cinq).
	var lv := l * 0.5
	if not volets:
		pass
	elif g % 5 == 0:
		for s: float in [-1.0, 1.0]:
			var xv := s * lv * 0.5
			o.saillie(t * Transform3D(Basis(), Vector3(xv, hf * 0.5, 0.05)), Vector3(lv - 0.01, hf, 0.04), volet, OUTILS.PEINT)
			for yb in [hf * 0.2, hf * 0.8]:
				o.plat(t, Vector3(xv, yb, 0.072), lv - 0.06, 0.08, volet.darkened(0.12))
	else:
		for s: float in [-1.0, 1.0]:
			var xv := s * (l * 0.5 + e + 0.02 + lv * 0.5)
			o.saillie(t * Transform3D(Basis(), Vector3(xv, hf * 0.5, 0.03)), Vector3(lv, hf, 0.04), volet, OUTILS.PEINT)
			for yb in [hf * 0.2, hf * 0.8]:
				o.plat(t, Vector3(xv, yb, 0.052), lv - 0.05, 0.08, volet.darkened(0.12))
			var diag := Vector2(lv - 0.08, hf * 0.6)
			o.plat(t * Transform3D(Basis(Vector3.BACK, atan2(diag.y, diag.x) * s), Vector3(xv, hf * 0.5, 0.052)), Vector3.ZERO, diag.length(), 0.07, volet.darkened(0.12))
	if jardiniere:
		o.saillie(t * Transform3D(Basis(), Vector3(0, 0.08, 0.36)), Vector3(l * 0.85, 0.2, 0.22), TERRE_CUITE, OUTILS.PEINT)
		var fleur: Color = FLEURS[g % FLEURS.size()]
		for k in 2:
			var q := Vector3(-l * 0.2 + k * l * 0.4, 0.24, 0.37)
			o.boule(t * q, Vector3(0.3, 0.13, 0.14), FEUILLES, 0.25, OUTILS.FEUILLE, 0.06, 0.2, 3, 5)
			o.boule(t * (q + Vector3(0, 0.08, 0.05)), Vector3(0.2, 0.08, 0.1), fleur, 0.3, OUTILS.FEUILLE, 0.08, 0.2, 3, 5)


## Une porte de chêne à panneaux, son encadrement et son linteau de pierre, sa marche.
static func _porte(o: RefCounted, t: Transform3D, bois: Color, g: int) -> void:
	var l := 1.1
	var hp := 2.3
	var y0 := 0.55
	o.saillie(t * Transform3D(Basis(), Vector3(0, y0 + hp * 0.5, 0.02)), Vector3(l, hp, 0.04), bois, OUTILS.PEINT)
	for k in 2:
		for s: float in [-1.0, 1.0]:
			o.saillie(t * Transform3D(Basis(), Vector3(s * l * 0.22, y0 + 0.35 + k * 1.0 + 0.4, 0.045)), Vector3(l * 0.32, 0.8, 0.02), bois.lightened(0.08), OUTILS.PEINT)
	o.saillie(t * Transform3D(Basis(), Vector3(l * 0.36, y0 + 1.1, 0.07)), Vector3(0.05, 0.05, 0.05), Color("c9b26a", 0.3), OUTILS.PEINT)
	for s: float in [-1.0, 1.0]:
		o.saillie(t * Transform3D(Basis(), Vector3(s * (l * 0.5 + 0.09), y0 + hp * 0.5, 0.07)), Vector3(0.18, hp, 0.14), TAILLE, OUTILS.PIERRE)
	o.saillie(t * Transform3D(Basis(), Vector3(0, y0 + hp + 0.15, 0.08)), Vector3(l + 0.56, 0.3, 0.16), TAILLE, OUTILS.PIERRE)
	if g % 3 == 0:
		# Une imposte vitrée au-dessus, sous le linteau.
		o.saillie(t * Transform3D(Basis(), Vector3(0, y0 + hp - 0.25, 0.05)), Vector3(l - 0.14, 0.34, 0.02), VERRE, OUTILS.VITRE)
	o.saillie(t * Transform3D(Basis(), Vector3(0, y0 - 0.08, 0.25)), Vector3(l + 0.5, 0.16, 0.5), TAILLE_SOMBRE, OUTILS.PIERRE)
