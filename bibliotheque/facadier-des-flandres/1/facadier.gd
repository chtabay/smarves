extends RefCounted
## Le façadier des Flandres : une maison de ville du nord composée par type et graine. Le type est la forme du
## pignon ; la graine tire le reste (l'enduit, le toit, les fenêtres, le rez-de-chaussée, les balcons, les
## fleurs, le lierre, les cheminées), deux voisines jamais pareilles. Repère : façade vers +Z, origine au pied
## de la façade, au milieu, le corps s'étend vers −Z ; en mètres.
##   load("res://bibliotheque/facadier-des-flandres/1/facadier.gd").maison(parent, Vector3.ZERO, "cloche", 4, {"w": 7.5})
const Outils := preload("res://bibliotheque/facadier-des-flandres/1/outils.gd")

## Les six pignons : à volutes (le cou étroit entre deux enroulements), à gradins, en cloche, à pointe,
## arrondi, et la maison mansardée sans pignon, sa corniche droite et ses lucarnes.
const TYPES := ["volutes", "gradins", "cloche", "pointe", "arrondi", "mansarde"]
## Les enduits de la place : moutarde, saumon, bleu, gris vert, sauge, ardoise, rose, ocre, crème.
const ENDUITS := {"jaune": "d9b45a", "saumon": "cf7a62", "bleu": "86a3c0", "gris_vert": "7f8a78", "sauge": "a3ad8f",
	"ardoise": "6d7380", "rose": "dca092", "ocre": "c99a52", "creme": "e6d6b0"}
const TOITS := {"tuile": ["e0773a", "c4622c"], "ardoise": ["5b6472", "4a5260"]}
const DEVANTURES := ["2f5a4a", "7a2f35", "2e4466", "5a3a28", "3f6b6e"]
const TOILES := [["c8463c", "f3ead6"], ["3f6fa0", "f3ead6"], ["7a3f6e", "e9d9b8"], ["4f7f4a", "f3ead6"], ["d9a53a", "f3ead6"]]
const FLEURS := ["b06ad0", "9a5bc4", "e88aa8", "e0605a", "f4f0e6"]
const CREME := Color("f1e7cf")
const PIERRE := Color("dccaa0")
const PIERRE_SOMBRE := Color("b9ab90")
const VERRE := Color("4d6a86")
const FER := Color("2c3033")
const SOMBRE := Color("2a2b30")
const VERT := Color("5f9e33")

const RDC := 4.0
const ETAGE := 3.2


## Bâtit une maison sous parent, le pied de sa façade en p. Options, toutes facultatives : w et d (largeur et
## profondeur), niveaux (les étages au-dessus du rez-de-chaussée, 1 à 4), enduit (un nom d'ENDUITS ou un hexa),
## toit (« tuile » ou « ardoise »), rdc (« boutique », « logis », « passage » sous une voûte, « pierre »),
## fenetres (« droite », « cintree », « plein_cintre »), balcons, lierre, banniere, fleurs (vrai ou faux),
## fumee (faux par défaut : de petites volutes blanches au-dessus des cheminées).
## Rend le nœud de la maison ; ses métadonnées : type, graine, w, d, hauteur (au faîte), porte (le seuil).
static func maison(parent: Node3D, p: Vector3, type: String, graine: int, opt := {}) -> Node3D:
	if not type in TYPES:
		type = "pointe"
	var o := Outils.new(graine * 15485863 + TYPES.find(type) * 7)
	var r := o.rng
	var n := Node3D.new()
	n.name = "Maison"
	n.position = p
	parent.add_child(n)
	var w := float(opt.get("w", r.randf_range(6.5, 8.5)))
	var d := float(opt.get("d", r.randf_range(9.0, 12.0)))
	var niveaux := clampi(int(opt.get("niveaux", 2 + (1 if r.randf() < 0.45 else 0))), 1, 4)
	var nom_enduit := str(opt.get("enduit", ENDUITS.keys()[r.randi() % ENDUITS.size()]))
	var enduit := Color(str(ENDUITS.get(nom_enduit, nom_enduit)))
	var toit: Array = TOITS[str(opt.get("toit", "tuile" if r.randf() < 0.65 else "ardoise"))].map(func(h): return Color(h))
	var rdc := str(opt.get("rdc", ["boutique", "boutique", "logis", "pierre", "logis"][r.randi() % 5]))
	var forme := str(opt.get("fenetres", ["droite", "cintree", "cintree", "plein_cintre"][r.randi() % 4]))
	var fleur := Color(FLEURS[r.randi() % FLEURS.size()])
	var avec_fleurs: bool = opt.get("fleurs", true)
	var H := RDC + niveaux * ETAGE
	# le corps : le mur de façade et ses flancs, tous enduits ; le dos un peu plus sombre
	o.boite(Transform3D(Basis(), Vector3(0, H * 0.5, -d * 0.5)), Vector3(w, H, d), [enduit.darkened(0.06), enduit.darkened(0.06), enduit, enduit, enduit, enduit.darkened(0.1)], Outils.DUR, true)
	# le soubassement de pierre
	o.boite(Transform3D(Basis(), Vector3(0, 0.3, 0.05)), Vector3(w + 0.02, 0.6, 0.12), PIERRE_SOMBRE)
	# le rez-de-chaussée
	var porte := Vector3(0, 0, 0.1)
	match rdc:
		"boutique":
			porte = _boutique(o, w, opt)
		"passage":
			porte = _passage(o, w)
		_:
			porte = _logis(o, w, rdc == "pierre", forme, enduit)
	# les bandeaux entre les niveaux et la corniche
	o.boite(Transform3D(Basis(), Vector3(0, RDC, 0.08)), Vector3(w + 0.04, 0.2, 0.18), CREME)
	for i in range(1, niveaux):
		o.boite(Transform3D(Basis(), Vector3(0, RDC + i * ETAGE, 0.06)), Vector3(w + 0.02, 0.12, 0.13), CREME)
	o.boite(Transform3D(Basis(), Vector3(0, H - 0.14, 0.12)), Vector3(w + 0.16, 0.28, 0.26), CREME)
	o.boite(Transform3D(Basis(), Vector3(0, H + 0.04, 0.2)), Vector3(w + 0.3, 0.12, 0.42), CREME.darkened(0.04))
	# les chaînes d'angle, harpées
	for cote in [-1.0, 1.0]:
		var y := 0.6 if rdc != "pierre" else RDC
		var k := 0
		while y < H - 0.5:
			var large := 0.62 if k % 2 == 0 else 0.4
			o.boite(Transform3D(Basis(), Vector3(cote * (w * 0.5 - large * 0.5 + 0.01), y + 0.21, 0.04)), Vector3(large, 0.38, 0.1), PIERRE)
			y += 0.44
			k += 1
	# les étages et leurs fenêtres
	var nf := clampi(int(round((w - 1.4) / 2.0)), 2, 4)
	var pas := (w - 1.6) / nf
	var balcon := r.randf() < 0.55 if not opt.has("balcons") else bool(opt.balcons)
	for e in niveaux:
		var y0 := RDC + e * ETAGE + 0.75
		var haute := 1.85 if e == 0 else (1.7 if e < niveaux - 1 else 1.5)
		for i in nf:
			var x := -w * 0.5 + 0.8 + pas * (i + 0.5)
			_fenetre(o, Vector3(x, y0, 0), 0.95, haute, forme)
			if e == 0 and balcon and (nf <= 2 or i in [1, nf - 2]):
				_balcon(o, Vector3(x, y0, 0), 1.5, fleur if avec_fleurs else Color(), r)
			elif avec_fleurs and r.randf() < 0.4:
				_jardiniere(o, Vector3(x, y0, 0.12), 1.0, fleur, r)
	# le lierre qui monte d'un angle, la bannière à la console
	if opt.get("lierre", r.randf() < 0.3):
		var cote := -1.0 if r.randf() < 0.5 else 1.0
		var hl := r.randf_range(RDC, H - 1.0)
		var y := 0.4
		while y < hl:
			var s := r.randf_range(0.32, 0.5)
			o.boule(Vector3(cote * (w * 0.5 - 0.45) + r.randf_range(-0.25, 0.3), y, 0.12), Vector3(s, s, 0.22), VERT.lightened(r.randf_range(-0.05, 0.15)), 0.25, Outils.FEUILLE, 0.08, 0.2)
			y += r.randf_range(0.35, 0.6)
		for i in 4:
			o.boule(Vector3(cote * (w * 0.5 - 0.45) - cote * r.randf_range(0.3, 1.4), hl - r.randf_range(0, 1.0), 0.12), Vector3(0.42, 0.32, 0.2), VERT.lightened(0.1), 0.25, Outils.FEUILLE, 0.08, 0.2)
	if opt.get("banniere", r.randf() < 0.3):
		var cote := -1.0 if r.randf() < 0.5 else 1.0
		var x := cote * (w * 0.5 - 0.35)
		var y := RDC + ETAGE * 0.85
		var drap := Color(["9a2a2a", "2e4f86", "2f6a3a"][r.randi() % 3])
		o.boite(Transform3D(Basis(), Vector3(x, y + 0.1, 0.45)), Vector3(0.05, 0.05, 0.9), FER)
		o.boite(Transform3D(Basis(), Vector3(x, y - 0.75, 0.82)), Vector3(0.05, 1.6, 0.55), drap)
		o.boite(Transform3D(Basis(), Vector3(x, y - 0.75, 0.82)), Vector3(0.06, 1.5, 0.12), Color("e2b94a"))
		o.profil(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(x, y - 1.55, 0.82)), PackedVector2Array([Vector2(-0.275, 0), Vector2(0.275, 0), Vector2(0, -0.3)]), -0.025, 0.025, drap)
	# le haut : le pignon et le toit, ou la mansarde
	var faite := H
	if type == "mansarde":
		faite = _mansarde(o, w, d, H, toit, enduit, r)
	else:
		faite = _pignon(o, type, w, d, H, toit, enduit, r)
	# les cheminées, sur les rampants
	var nc := 1 + (1 if r.randf() < 0.5 else 0)
	var fumees := []
	for i in nc:
		var x := (w * 0.5 - 0.6) * (-1.0 if i == 0 else 1.0) * (1.0 if r.randf() < 0.5 else 0.6)
		var z := -d * r.randf_range(0.35, 0.75)
		var y := H + (faite - H) * 0.55
		o.boite(Transform3D(Basis(), Vector3(x, y + 0.9, z)), Vector3(0.7, 2.6, 0.55), CREME.darkened(0.05))
		o.boite(Transform3D(Basis(), Vector3(x, y + 2.25, z)), Vector3(0.85, 0.16, 0.7), PIERRE_SOMBRE)
		for k in 2:
			o.cylindre(Transform3D(Basis(), Vector3(x - 0.15 + k * 0.3, y + 2.33, z)), 0.1, 0.09, 0.3, 6, Color("b86a45"))
		fumees.append(Vector3(x, y + 2.7, z))
	if opt.get("fumee", false):
		for f in fumees:
			for k in 4:
				o.boule(f + Vector3(k * 0.12, k * 0.55, -k * 0.05), Vector3.ONE * (0.18 + k * 0.08), Color(1, 1, 1), 0.2, Outils.FEUILLE, 0.0, 0.0)
	o.construire(n, "Corps")
	n.set_meta("type", type)
	n.set_meta("graine", graine)
	n.set_meta("w", w)
	n.set_meta("d", d)
	n.set_meta("hauteur", faite)
	n.set_meta("porte", porte)
	return n


## Une fenêtre : l'encadrement blanc, le verre, la croisée, l'appui. p est le bas de la baie, au nu du mur.
static func _fenetre(o: Outils, p: Vector3, l: float, h: float, forme: String) -> void:
	var pts := _baie(l, h, forme)
	var t := Transform3D(Basis(), p)
	o.profil(t, Outils.grossir(pts, 0.13), 0.0, 0.07, CREME)
	o.profil(t, pts, 0.0, 0.085, VERRE)
	# la croisée : un meneau, une traverse aux deux tiers
	o.boite(Transform3D(Basis(), p + Vector3(0, h * 0.5, 0.1)), Vector3(0.06, h, 0.03), CREME)
	o.boite(Transform3D(Basis(), p + Vector3(0, h * 0.66, 0.1)), Vector3(l, 0.06, 0.03), CREME)
	o.boite(Transform3D(Basis(), p + Vector3(0, -0.1, 0.1)), Vector3(l + 0.42, 0.1, 0.22), CREME.darkened(0.03))
	if forme != "droite":
		o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.08, 0.1)), Vector3(0.2, 0.3, 0.08), PIERRE)


## Le contour d'une baie de largeur l et de hauteur h (au sommet), droite, cintrée ou en plein cintre.
static func _baie(l: float, h: float, forme: String) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(l * 0.5, 0)])
	match forme:
		"plein_cintre":
			var r := l * 0.5
			pts.append(Vector2(l * 0.5, h - r))
			pts.append_array(Outils.arc(Vector2(0, h - r), r, 0.0, PI, 10))
			pts.append(Vector2(-l * 0.5, h - r))
		"cintree":
			# un arc segmentaire : flèche de 0,22 m
			var f := 0.22
			var R := (l * l * 0.25 + f * f) / (2.0 * f)
			var c := Vector2(0, h - R)
			var a := asin(l * 0.5 / R)
			pts.append(Vector2(l * 0.5, h - f))
			pts.append_array(Outils.arc(c, R, PI * 0.5 - a, PI * 0.5 + a, 8))
		_:
			pts.append(Vector2(l * 0.5, h))
			pts.append(Vector2(-l * 0.5, h))
	pts.append(Vector2(-l * 0.5, 0))
	return pts


static func _jardiniere(o: Outils, p: Vector3, l: float, fleur: Color, r: RandomNumberGenerator) -> void:
	o.boite(Transform3D(Basis(), p + Vector3(0, 0.06, 0.1)), Vector3(l, 0.22, 0.25), Color("8a5a3a"))
	for i in 4:
		var q := p + Vector3(-l * 0.38 + i * l * 0.25, 0.28, 0.12)
		o.boule(q, Vector3(0.22, 0.17, 0.16), VERT, 0.25, Outils.FEUILLE, 0.06, 0.2)
		o.boule(q + Vector3(r.randf_range(-0.05, 0.05), 0.08, 0.08), Vector3(0.13, 0.09, 0.1), fleur.lightened(r.randf_range(-0.1, 0.1)), 0.3, Outils.FEUILLE, 0.08, 0.2)
	# une tige qui retombe
	o.boule(p + Vector3(l * 0.3, -0.2, 0.2), Vector3(0.12, 0.28, 0.1), VERT.darkened(0.1), 0.3, Outils.FEUILLE, 0.05, 0.3)


## Un balcon de fer forgé sur sa dalle, fleuri si fleur a une couleur.
static func _balcon(o: Outils, p: Vector3, l: float, fleur: Color, r: RandomNumberGenerator) -> void:
	o.boite(Transform3D(Basis(), p + Vector3(0, -0.12, 0.35)), Vector3(l, 0.14, 0.7), CREME.darkened(0.04))
	o.boite(Transform3D(Basis(), p + Vector3(0, 0.9, 0.68)), Vector3(l, 0.05, 0.05), FER)
	o.boite(Transform3D(Basis(), p + Vector3(0, 0.12, 0.68)), Vector3(l, 0.04, 0.04), FER)
	for cote in [-1.0, 1.0]:
		o.boite(Transform3D(Basis(), p + Vector3(cote * l * 0.5, 0.9, 0.35)), Vector3(0.05, 0.05, 0.66), FER)
		o.boite(Transform3D(Basis(), p + Vector3(cote * l * 0.5, 0.45, 0.35)), Vector3(0.04, 0.9, 0.04), FER)
	var n := int(l / 0.12)
	for i in n + 1:
		o.boite(Transform3D(Basis(), p + Vector3(-l * 0.5 + i * l / n, 0.5, 0.68)), Vector3(0.025, 0.8, 0.025), FER)
	if fleur.a > 0.0:
		for i in 3:
			var q := p + Vector3(-l * 0.33 + i * l * 0.33, 0.95, 0.66)
			o.boule(q, Vector3(0.24, 0.16, 0.14), VERT, 0.25, Outils.FEUILLE, 0.06, 0.2)
			o.boule(q + Vector3(0, 0.07, 0.06), Vector3(0.15, 0.1, 0.1), fleur.lightened(r.randf_range(-0.1, 0.1)), 0.3, Outils.FEUILLE, 0.08, 0.2)
			o.boule(q + Vector3(0.08, -0.3, 0.05), Vector3(0.1, 0.3, 0.08), VERT.darkened(0.08), 0.3, Outils.FEUILLE, 0.05, 0.3)


## La boutique : une devanture de bois peint, sa vitrine et sa porte, l'enseigne et le store à bandes.
static func _boutique(o: Outils, w: float, opt: Dictionary) -> Vector3:
	var r := o.rng
	var bois := Color(DEVANTURES[r.randi() % DEVANTURES.size()])
	var toile: Array = opt.get("toile", TOILES[r.randi() % TOILES.size()])
	var l := w - 1.4
	o.boite(Transform3D(Basis(), Vector3(0, 1.75, 0.08)), Vector3(l + 0.3, 3.1, 0.16), bois)
	var x_porte := (l * 0.5 - 0.75) * (1.0 if r.randf() < 0.5 else -1.0)
	# la vitrine, en deux ou trois baies, et la porte vitrée
	var baies := 2 if l < 6.0 else 3
	var lv := (l - 1.7) / baies
	var x := -l * 0.5 + 0.1 if x_porte > 0 else -l * 0.5 + 1.6
	for i in baies:
		o.boite(Transform3D(Basis(), Vector3(x + lv * 0.5, 1.95, 0.17)), Vector3(lv - 0.16, 2.1, 0.02), VERRE.lightened(0.12))
		o.boite(Transform3D(Basis(), Vector3(x + lv * 0.5, 0.45, 0.18)), Vector3(lv - 0.1, 0.6, 0.04), bois.darkened(0.15))
		x += lv
	o.boite(Transform3D(Basis(), Vector3(x_porte, 1.25, 0.17)), Vector3(1.1, 2.4, 0.02), bois.darkened(0.2))
	o.boite(Transform3D(Basis(), Vector3(x_porte, 1.55, 0.185)), Vector3(0.75, 1.4, 0.02), VERRE.lightened(0.12))
	o.boite(Transform3D(Basis(), Vector3(x_porte + 0.35, 1.1, 0.21)), Vector3(0.05, 0.05, 0.06), Color("c9a64a"))
	# l'enseigne : un bandeau crème cerné de la couleur de la devanture
	o.boite(Transform3D(Basis(), Vector3(0, 3.48, 0.18)), Vector3(l - 0.4, 0.42, 0.06), CREME)
	o.boite(Transform3D(Basis(), Vector3(0, 3.48, 0.2)), Vector3(l - 1.4, 0.12, 0.04), bois.darkened(0.1))
	# le store, ses bandes et ses festons
	var bandes := int(l / 0.45)
	var lb := l / bandes
	for i in bandes:
		var c := Color(str(toile[i % 2]))
		var xb := -l * 0.5 + (i + 0.5) * lb
		o.boite(Transform3D(Basis(Vector3.RIGHT, 0.42), Vector3(xb, 3.0, 0.65)), Vector3(lb, 0.04, 1.2), c)
		var pts := Outils.arc(Vector2(0, 0), lb * 0.5, PI, TAU, 6)
		o.profil(Transform3D(Basis(), Vector3(xb, 2.75, 1.2)), pts, -0.01, 0.01, c)
	for cote in [-1.0, 1.0]:
		o.boite(Transform3D(Basis(), Vector3(cote * l * 0.5, 2.9, 0.7)), Vector3(0.03, 0.03, 1.1), FER)
	# des cagettes ou des pots devant la vitrine
	if r.randf() < 0.6:
		for i in 3:
			var q := Vector3(-l * 0.25 + i * 0.6 + (0.0 if x_porte > 0 else 1.2), 0, 0.55)
			o.boite(Transform3D(Basis(), q + Vector3(0, 0.25, 0)), Vector3(0.5, 0.5, 0.4), Color("b88a52"))
			o.boule(q + Vector3(0, 0.55, 0), Vector3(0.22, 0.12, 0.17), Color(["e0605a", "f2a23a", "8cc63f", "f2d14e"][r.randi() % 4]), 0.15, Outils.DUR, 0.05)
	return Vector3(x_porte, 0, 0.2)


## Le passage voûté sous la maison : l'arc sombre et ses claveaux de pierre.
static func _passage(o: Outils, w: float) -> Vector3:
	var l := minf(w - 2.2, 3.6)
	var pts := _baie(l, 3.6, "plein_cintre")
	var t := Transform3D(Basis(), Vector3.ZERO)
	o.profil(t, Outils.grossir(pts, 0.35), 0.0, 0.12, PIERRE)
	o.profil(t, pts, 0.0, 0.14, SOMBRE)
	o.boite(Transform3D(Basis(), Vector3(0, 3.75, 0.16)), Vector3(0.5, 0.6, 0.1), PIERRE_SOMBRE)
	# les claveaux : de fines joies sombres dans la pierre de l'arc
	for i in 9:
		var a := PI * (i + 0.5) / 9.0
		var c := Vector2(0, 3.6 - l * 0.5)
		var q := c + Vector2(cos(a), sin(a)) * (l * 0.5 + 0.17)
		o.boite(Transform3D(Basis(Vector3.BACK, a - PI * 0.5), Vector3(q.x, q.y, 0.125)), Vector3(0.025, 0.36, 0.01), PIERRE_SOMBRE)
	return Vector3(0, 0, 0.2)


## Un rez-de-chaussée d'habitation : la porte d'entrée et ses fenêtres, enduit ou en pierre à bossages.
static func _logis(o: Outils, w: float, pierre: bool, forme: String, enduit: Color) -> Vector3:
	var r := o.rng
	if pierre:
		o.boite(Transform3D(Basis(), Vector3(0, RDC * 0.5, 0.03)), Vector3(w + 0.02, RDC - 0.1, 0.06), PIERRE)
		var y := 0.9
		while y < RDC - 0.2:
			o.boite(Transform3D(Basis(), Vector3(0, y, 0.065)), Vector3(w + 0.02, 0.04, 0.02), PIERRE_SOMBRE)
			y += 0.5
	var x_porte := (w * 0.5 - 1.4) * (1.0 if r.randf() < 0.5 else -1.0) if w > 6.0 else 0.0
	var pts := _baie(1.25, 2.7, "plein_cintre" if forme != "droite" else "droite")
	o.profil(Transform3D(Basis(), Vector3(x_porte, 0.15, 0.06)), Outils.grossir(pts, 0.16), 0.0, 0.08, CREME)
	o.profil(Transform3D(Basis(), Vector3(x_porte, 0.15, 0.06)), pts, 0.0, 0.1, Color(DEVANTURES[r.randi() % DEVANTURES.size()]))
	o.boite(Transform3D(Basis(), Vector3(x_porte, 0.07, 0.3)), Vector3(1.7, 0.14, 0.5), PIERRE_SOMBRE)
	o.boite(Transform3D(Basis(), Vector3(x_porte + 0.4, 1.2, 0.18)), Vector3(0.06, 0.06, 0.06), Color("c9a64a"))
	# les fenêtres de part et d'autre de la porte
	var n := 1 if w < 7.5 else 2
	for i in n:
		var cote := -signf(x_porte) if x_porte != 0.0 else (-1.0 if i == 0 else 1.0)
		var x := x_porte + cote * (1.9 + i * 1.9)
		if absf(x) > w * 0.5 - 0.9:
			continue
		_fenetre(o, Vector3(x, 1.2, 0.06 if pierre else 0.0), 1.0, 2.0, forme)
	return Vector3(x_porte, 0, 0.35)


## Le pignon sur rue et le toit derrière lui ; rend la hauteur du faîte.
static func _pignon(o: Outils, type: String, w: float, d: float, H: float, toit: Array, enduit: Color, r: RandomNumberGenerator) -> float:
	var hw := w * 0.5
	var hg := w * 0.62
	var pts := PackedVector2Array()
	match type:
		"pointe":
			hg = w * 0.62
			pts = PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0), Vector2(0, hg)])
		"gradins":
			hg = w * 0.72
			var marches := 4 if w < 7.5 else 5
			var top := w * 0.14
			var droite := PackedVector2Array([Vector2(hw, 0)])
			for i in range(1, marches + 1):
				var y := hg * i / float(marches + 1)
				droite.append(Vector2(lerpf(hw, top, float(i - 1) / marches), y))
				droite.append(Vector2(lerpf(hw, top, float(i) / marches), y))
			droite.append(Vector2(top, hg))
			pts = droite.duplicate()
			for i in range(droite.size() - 1, -1, -1):
				pts.append(Vector2(-droite[i].x, droite[i].y))
		"cloche":
			hg = w * 0.8
			var cou := w * 0.2
			pts.append(Vector2(-hw, 0))
			pts.append(Vector2(hw, 0))
			pts.append(Vector2(hw, 0.35))
			# l'épaule convexe puis la gorge concave, jusqu'au cou
			for i in range(1, 10):
				var t := float(i) / 10.0
				var x := lerpf(hw, cou, smoothstep(0.0, 1.0, t))
				pts.append(Vector2(x, 0.35 + t * (hg * 0.68 - 0.35)))
			pts.append_array(Outils.arc(Vector2(0, hg * 0.68), cou, 0.0, PI, 8))
			for i in range(9, 0, -1):
				var t := float(i) / 10.0
				var x := lerpf(hw, cou, smoothstep(0.0, 1.0, t))
				pts.append(Vector2(-x, 0.35 + t * (hg * 0.68 - 0.35)))
			pts.append(Vector2(-hw, 0.35))
			hg = hg * 0.68 + cou
		"volutes":
			hg = w * 0.78
			var cou := w * 0.24
			var epaule := hg * 0.38
			pts.append(Vector2(-hw, 0))
			pts.append(Vector2(hw, 0))
			# l'enroulement : un quart de cercle concave de l'épaule au cou
			var rv := hw - cou
			pts.append_array(Outils.arc(Vector2(hw, epaule * 0.4 + rv), rv, -PI * 0.5, -PI, 8))
			pts.append(Vector2(cou, hg - 0.9))
			pts.append(Vector2(cou + 0.2, hg - 0.9))
			pts.append(Vector2(0, hg))
			pts.append(Vector2(-cou - 0.2, hg - 0.9))
			pts.append(Vector2(-cou, hg - 0.9))
			var gauche := Outils.arc(Vector2(-hw, epaule * 0.4 + rv), rv, 0.0, -PI * 0.5, 8)
			pts.append_array(gauche)
		"arrondi":
			hg = w * 0.5
			pts.append(Vector2(-hw, 0))
			pts.append(Vector2(hw, 0))
			pts.append(Vector2(hw, 0.5))
			for i in range(1, 16):
				var a := PI * i / 16.0
				pts.append(Vector2(cos(a) * hw, 0.5 + sin(a) * (hg - 0.5)))
			pts.append(Vector2(-hw, 0.5))
	# le toit, derrière le pignon : à deux pans, son faîte sous la pointe, ses rangs de tuiles
	var ht := hg * (0.92 if type in ["pointe", "arrondi"] else 0.82)
	var pente := atan2(ht, hw)
	var long := sqrt(ht * ht + hw * hw) + 0.35
	for cote in [-1.0, 1.0]:
		var b := Basis(Vector3.BACK, -cote * pente)
		var c := Vector3(cote * hw * 0.5, H + ht * 0.5, -d * 0.5 - 0.2) + b * Vector3(0, 0.12, 0)
		o.boite(Transform3D(b, c), Vector3(long, 0.22, d + 0.1), toit[0])
		var rangs := int(long / 0.55)
		for k in rangs:
			var s := -long * 0.5 + (k + 0.5) * long / rangs
			o.boite(Transform3D(b, c + b * Vector3(s, 0.12, 0)), Vector3(0.06, 0.04, d + 0.1), toit[1])
	o.boite(Transform3D(Basis(), Vector3(0, H + ht + 0.12, -d * 0.5 - 0.2)), Vector3(0.3, 0.2, d + 0.1), toit[1])
	o.profil(Transform3D(Basis(), Vector3(0, H, -d)), PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0), Vector2(0, ht)]), -0.1, 0.0, enduit.darkened(0.1))
	# le pignon et son liseré de pierre crème
	var base := Transform3D(Basis(), Vector3(0, H, 0))
	o.profil(base, pts, -0.4, 0.12, enduit)
	o.profil(base, Outils.grossir(pts, 0.16), -0.3, 0.06, CREME)
	# l'oculus ou la petite baie du grenier
	var y_oc := hg * (0.42 if type != "arrondi" else 0.45)
	if r.randf() < 0.6 or type == "pointe":
		var rond := Outils.arc(Vector2(0, 0), 0.5, 0.0, TAU, 16)
		o.profil(Transform3D(Basis(), Vector3(0, H + y_oc, 0)), Outils.grossir(rond, 0.14), 0.0, 0.2, CREME)
		o.profil(Transform3D(Basis(), Vector3(0, H + y_oc, 0)), rond, 0.0, 0.21, VERRE)
		o.boite(Transform3D(Basis(), Vector3(0, H + y_oc, 0.23)), Vector3(1.0, 0.05, 0.02), CREME)
		o.boite(Transform3D(Basis(), Vector3(0, H + y_oc, 0.23)), Vector3(0.05, 1.0, 0.02), CREME)
	else:
		_fenetre(o, Vector3(0, H + y_oc - 0.7, 0.12), 0.8, 1.35, "plein_cintre")
	# les pinacles aux épaules d'un pignon à volutes ou en cloche
	if type in ["volutes", "cloche", "gradins"]:
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), Vector3(cote * (hw - 0.15), H + 0.55, 0.0)), Vector3(0.35, 0.5, 0.35), CREME)
			o.boule(Vector3(cote * (hw - 0.15), H + 0.98, 0.0), Vector3.ONE * 0.17, CREME, 0.0, Outils.DUR, 0.0)
	return H + maxf(hg, ht)


## La mansarde : la corniche droite, le brisis raide et ses lucarnes, le terrasson presque plat ; rend le faîte.
static func _mansarde(o: Outils, w: float, d: float, H: float, toit: Array, enduit: Color, r: RandomNumberGenerator) -> float:
	var hb := 2.6
	var recul := 0.9
	var ht := 1.3
	# le profil dans le plan (z, y), extrudé selon x : le brisis, puis le terrasson jusqu'au faîte au milieu
	var pts := PackedVector2Array([Vector2(0.35, H + 0.1), Vector2(-recul, H + hb), Vector2(-d * 0.5, H + hb + ht),
		Vector2(-d + recul, H + hb), Vector2(-d - 0.35, H + 0.1)])
	var b := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	o.profil(Transform3D(b, Vector3.ZERO), pts, -w * 0.5 - 0.15, w * 0.5 + 0.15, [enduit.darkened(0.1), toit[0]])
	# les rangs d'ardoise ou de tuile sur le brisis
	var pente := atan2(hb, recul + 0.35)
	var bb := Basis(Vector3.RIGHT, -(PI * 0.5 - pente))
	for k in 5:
		var f := (k + 0.5) / 5.0
		o.boite(Transform3D(bb, Vector3(0, H + 0.1 + f * hb, 0.35 - f * (recul + 0.35) + 0.03)), Vector3(w + 0.3, 0.05, 0.04), toit[1])
	# les lucarnes
	var n := clampi(int(round((w - 1.4) / 2.0)), 2, 4)
	var pas := (w - 1.6) / n
	for i in n:
		var x := -w * 0.5 + 0.8 + pas * (i + 0.5)
		var z := -0.2
		var y := H + 0.6
		o.boite(Transform3D(Basis(), Vector3(x, y + 0.85, z - 0.45)), Vector3(1.3, 1.7, 1.0), CREME)
		_fenetre(o, Vector3(x, y + 0.25, z + 0.05), 0.75, 1.15, "cintree")
		o.profil(Transform3D(Basis(), Vector3(x, y + 1.7, z + 0.08)), PackedVector2Array([Vector2(-0.8, 0), Vector2(0.8, 0), Vector2(0, 0.7)]), -1.1, 0.0, [CREME.darkened(0.04), toit[0]])
	# une balustrade de pierre sur la corniche
	for i in int(w / 0.35):
		var x := -w * 0.5 + 0.2 + i * 0.35
		o.cylindre(Transform3D(Basis(), Vector3(x, H + 0.1, 0.25)), 0.07, 0.07, 0.45, 6, CREME)
	o.boite(Transform3D(Basis(), Vector3(0, H + 0.6, 0.25)), Vector3(w + 0.1, 0.1, 0.22), CREME)
	return H + hb + ht
