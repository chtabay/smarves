extends RefCounted
## Le façadier toulousain : une maison ou un immeuble du centre de Toulouse composé par type et graine. Le type
## fixe la silhouette (les étages, la largeur, le toit, le rez-de-chaussée, le parement) ; la graine tire le reste
## (le ton de la brique foraine, les briques sombres mêlées, les persiennes, les balconnets, les fleurs, la vigne,
## les cheminées). Repère : façade vers +Z, origine au pied de la façade, au milieu, le corps vers −Z ; en mètres.
## L'immeuble d'angle et celui de la place Wilson ont une seconde façade vers +X.
##   load("res://bibliotheque/facadier-toulousain/1/facadier.gd").maison(parent, Vector3.ZERO, "moyenne", 4)
## Palette tirée des planches de la place Saint-Georges : brique rose orangé (#C8653F à #E08A5E) aux joints clairs
## (#E9D9C2) mêlée de briques sombres (#9E4A2E), pierre presque blanche (#EFE6D4), persiennes gris vert, crème ou
## gris bleu, tuile canal à 25° sur génoise à trois rangs.
const Outils := preload("res://bibliotheque/facadier-toulousain/1/outils.gd")

## Les types : l'atelier (rez-de-chaussée seul), la maison étroite, la façade moyenne, l'immeuble, l'immeuble
## d'angle, l'immeuble à arcades, le café, le commerce, le restaurant, l'hôtel particulier enduit, l'hôtel à
## avant-corps et fronton (l'hôtel de Lafage), l'immeuble XIXe à angle courbe et mansarde (place Wilson) et la
## maison à pans de bois.
const TYPES := ["atelier", "etroite", "moyenne", "immeuble", "angle", "arcades", "cafe", "commerce", "restaurant", "hotel", "lafage", "wilson", "colombages"]
## Pour chaque type : niveaux au-dessus du rez-de-chaussée, largeur (min, max), toit, rez-de-chaussée, parement.
const GABARITS := {
	"atelier": [0, 6.0, 8.0, "deux_pans", "commerce", "brique"],
	"etroite": [2, 4.4, 5.4, "deux_pans", "logis", "brique"],
	"moyenne": [3, 7.0, 9.0, "deux_pans", "commerce", "brique"],
	"immeuble": [4, 9.0, 11.0, "deux_pans", "commerce", "brique"],
	"angle": [4, 10.0, 11.0, "quatre_pans", "cafe", "brique"],
	"arcades": [3, 10.0, 12.0, "deux_pans", "arcades", "brique"],
	"cafe": [3, 8.0, 10.0, "deux_pans", "cafe", "brique"],
	"commerce": [3, 7.0, 9.0, "deux_pans", "commerce", "brique"],
	"restaurant": [3, 8.0, 10.0, "deux_pans", "restaurant", "brique"],
	"hotel": [3, 12.0, 14.0, "quatre_pans", "porche", "enduit"],
	"lafage": [3, 24.0, 28.0, "quatre_pans", "arcades", "enduit"],
	"wilson": [4, 13.0, 15.0, "mansarde", "arcades", "brique"],
	"colombages": [2, 6.0, 8.0, "deux_pans", "logis", "pans_de_bois"],
}
const BRIQUES := {"rose": "c8653f", "orange": "d47248", "saumon": "e08a5e", "brune": "b85a3a", "claire": "dc8a62"}
const ENDUITS := {"rose_poudre": "e9c6b2", "creme": "efe2c8", "blanc": "f1ebde", "ocre_rose": "e2b08f"}
const PERSIENNES := ["9daa92", "e8dfc8", "8fa0ad", "b9b6a6", "a8b8a0"]
const DEVANTURES := ["2f5a3a", "3a2a24", "6e1f22", "2b3e5c", "5a3a28"]
const TOILES := [["2f6a4a", "f3ead6"], ["f0e3c4", "f0e3c4"], ["8a2a2e", "8a2a2e"], ["2f6a4a", "2f6a4a"], ["c9a24a", "f3ead6"]]
const FLEURS := ["d04a6a", "e0605a", "f2c14e", "f4f0e6", "c05ac0"]
const JOINT := Color("e9d9c2")
const BRIQUE_SOMBRE := Color("9e4a2e")
const PIERRE := Color("efe6d4")
const PIERRE_SOMBRE := Color("d6c9ae")
const TUILE := [Color("d9733f"), Color("b85b30"), Color("c76a45")]
const ARDOISE := [Color("5a6170"), Color("485060")]
const VERRE := Color("3f5468")
const FER := Color("26292c")
const SOMBRE := Color("2b2622")
const VERT := Color("5f9e33")

const RDC := 4.0
const ETAGE := 3.2


## Bâtit une maison sous parent, le pied de sa façade en p. Options, toutes facultatives : w et d (largeur et
## profondeur), niveaux (0 à 6), brique (un nom de BRIQUES ou un hexa), enduit (un nom d'ENDUITS ou un hexa ; il
## donne un parement enduit à chaînes de brique), parement (« brique », « enduit », « pans_de_bois »), toit
## (« deux_pans », « quatre_pans », « mansarde »), rdc (« commerce », « cafe », « restaurant », « arcades »,
## « porche », « logis »), persiennes (vrai, faux ou un hexa), balconnets (vrai ou faux), fleurs, vigne, enseigne (le
## texte de la devanture), toile (deux hexas : le store).
## Rend le nœud de la maison ; ses métadonnées : type, graine, w, d, hauteur (au faîte), porte (le seuil).
static func maison(parent: Node3D, p: Vector3, type: String, graine: int, opt := {}) -> Node3D:
	if not type in TYPES:
		type = "moyenne"
	var o := Outils.new(graine * 2654435 + TYPES.find(type) * 17 + 5)
	var r := o.rng
	var n := Node3D.new()
	n.name = "Maison"
	n.position = p
	parent.add_child(n)
	var g: Array = GABARITS[type]
	var w := float(opt.get("w", r.randf_range(g[1], g[2])))
	var d := float(opt.get("d", w if type in ["angle", "wilson"] else r.randf_range(10.0, 13.0)))
	var niveaux := clampi(int(opt.get("niveaux", g[0])), 0, 6)
	var parement := str(opt.get("parement", "enduit" if opt.has("enduit") else g[5]))
	var nb := str(opt.get("brique", BRIQUES.keys()[r.randi() % BRIQUES.size()]))
	var brique := Color(str(BRIQUES.get(nb, nb)))
	var ne := str(opt.get("enduit", ENDUITS.keys()[r.randi() % ENDUITS.size()] if type != "lafage" else "blanc"))
	var enduit := Color(str(ENDUITS.get(ne, ne)))
	var mur := enduit if parement == "enduit" else brique
	var toit := str(opt.get("toit", g[3]))
	var rdc := str(opt.get("rdc", g[4]))
	var H := RDC + niveaux * ETAGE
	var s := {
		"parement": parement,
		"mur": mur,
		"brique": brique,
		"cadre": brique.darkened(0.08) if parement == "enduit" else PIERRE,
		"persiennes": _persiennes(opt, r),
		"balconnets": bool(opt.get("balconnets", r.randf() < 0.6 or type in ["hotel", "lafage", "wilson"])),
		"fleurs": bool(opt.get("fleurs", true)),
		"fleur": Color(FLEURS[r.randi() % FLEURS.size()]),
		"arc": r.randf() < 0.55 and parement == "brique",
		"toile": opt.get("toile", TOILES[r.randi() % TOILES.size()]),
		"toile_donnee": opt.has("toile"),
		"enseigne": str(opt.get("enseigne", "")),
		"bois": Color(DEVANTURES[r.randi() % DEVANTURES.size()]),
		"fronton": type in ["hotel", "lafage"],
	}
	var R := 3.2 if type == "wilson" else 0.0
	# le corps ; l'immeuble de la place Wilson a l'angle arrondi : deux blocs et un quart de tour
	if R > 0.0:
		o.boite(Transform3D(Basis(), Vector3(-R * 0.5, H * 0.5, -d * 0.5)), Vector3(w - R, H, d), mur, Outils.DUR, true)
		o.boite(Transform3D(Basis(), Vector3(0, H * 0.5, -(d + R) * 0.5)), Vector3(w, H, d - R), mur, Outils.DUR, true)
		o.cylindre(Transform3D(Basis(), Vector3(w * 0.5 - R, 0, -R)), R, R, H, 16, mur)
	else:
		o.boite(Transform3D(Basis(), Vector3(0, H * 0.5, -d * 0.5)), Vector3(w, H, d), [mur.darkened(0.06), mur.darkened(0.06), mur, mur, mur, mur.darkened(0.1)], Outils.DUR, true)
	# le soubassement, enterré de 30 cm pour asseoir la maison sur un sol inégal
	o.boite(Transform3D(Basis(), Vector3(0, -0.15, -d * 0.5)), Vector3(w, 0.32, d), PIERRE_SOMBRE)
	var porte := Vector3(0, 0, 0.6)
	match type:
		"lafage":
			porte = _lafage(o, w, niveaux, s, n)
		"wilson":
			porte = _facade(o, Transform3D(Basis(), Vector3(-R * 0.5, 0, 0)), w - R, niveaux, rdc, s, n, [false, true])
			var b := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))
			_facade(o, Transform3D(b, Vector3(w * 0.5, 0, -(d + R) * 0.5)), d - R, niveaux, "commerce", s, n, [true, false])
			_courbe(o, Vector3(w * 0.5 - R, 0, -R), R, niveaux, s)
		_:
			porte = _facade(o, Transform3D(), w, niveaux, rdc, s, n, [false, false])
			if type == "angle":
				var b := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))
				_facade(o, Transform3D(b, Vector3(w * 0.5, 0, -d * 0.5)), d, niveaux, "commerce", s, n, [false, false])
				_chaine(o, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(w * 0.5 - 0.1, 0, -0.1)), H, s, 0.0)
	if parement == "pans_de_bois":
		_pans_de_bois(o, w, niveaux, s)
	if opt.get("vigne", r.randf() < 0.25 and type != "lafage"):
		_vigne(o, w, H, r)
	var faite := H
	match toit:
		"mansarde":
			faite = _mansarde(o, w, d, H, R)
		"quatre_pans":
			faite = _quatre_pans(o, w, d, H, s)
		_:
			faite = _deux_pans(o, w, d, H, s)
	if niveaux > 0 or toit != "deux_pans":
		_genoise(o, w, d, H, toit, R)
	# les souches de cheminée en brique, hautes, couronnées d'un chapeau
	var nc := 1 + (1 if w > 7.0 else 0) + (1 if w > 14.0 else 0)
	for i in nc:
		var x := lerpf(-w * 0.35, w * 0.35, float(i) / maxf(1, nc - 1)) + r.randf_range(-0.4, 0.4)
		if nc == 1:
			x = r.randf_range(-w * 0.25, w * 0.25)
		var z := -d * r.randf_range(0.42, 0.62)
		var y := lerpf(H, faite, 0.6)
		o.boite(Transform3D(Basis(), Vector3(x, y + 0.9, z)), Vector3(0.9, 2.8, 0.55), brique.darkened(0.05))
		o.boite(Transform3D(Basis(), Vector3(x, y + 2.35, z)), Vector3(1.05, 0.14, 0.7), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), Vector3(x, y + 2.55, z)), Vector3(0.7, 0.26, 0.4), brique.darkened(0.12))
	o.construire(n, "Corps")
	n.set_meta("type", type)
	n.set_meta("graine", graine)
	n.set_meta("w", w)
	n.set_meta("d", d)
	n.set_meta("hauteur", faite)
	n.set_meta("porte", porte)
	return n


static func _persiennes(opt: Dictionary, r: RandomNumberGenerator) -> Color:
	var v = opt.get("persiennes", r.randf() < 0.85)
	if v is String:
		return Color(v)
	if v:
		return Color(PERSIENNES[r.randi() % PERSIENNES.size()])
	return Color(0, 0, 0, 0)


## Une façade de largeur w dans le repère t (x en travers, y vers le haut, z vers la rue) : le soubassement, le
## rez-de-chaussée, les bandeaux, les chaînes, les travées et le parement de brique foraine autour des baies.
## sans_chaine : [gauche, droite], les côtés où ne pas poser de chaîne (le raccord d'un angle courbe).
## Rend le seuil de la porte.
static func _facade(o: Outils, t: Transform3D, w: float, niveaux: int, rdc: String, s: Dictionary, n: Node3D, sans_chaine: Array) -> Vector3:
	var H := RDC + niveaux * ETAGE
	var trous := []
	# le soubassement de pierre
	o.boite(t * Transform3D(Basis(), Vector3(0, 0.3, 0.07)), Vector3(w + 0.02, 0.6, 0.14), PIERRE_SOMBRE)
	var porte := Vector3(0, 0, 0.6)
	match rdc:
		"arcades":
			porte = _arcades(o, t, w, s)
			trous.append(Rect2(-w * 0.5, 0, w, RDC))
		"cafe", "commerce", "restaurant":
			porte = _devanture(o, t, w, s, rdc, n)
			trous.append(Rect2(-w * 0.5, 0, w, RDC))
		"porche":
			porte = _logis(o, t, w, s, true, trous)
		_:
			porte = _logis(o, t, w, s, false, trous)
	if niveaux > 0:
		# le bandeau du premier étage, et un cordon à chaque étage
		o.boite(t * Transform3D(Basis(), Vector3(0, RDC + 0.04, 0.12)), Vector3(w + 0.06, 0.24, 0.24), s.cadre)
		for i in range(1, niveaux):
			o.boite(t * Transform3D(Basis(), Vector3(0, RDC + i * ETAGE - 0.04, 0.05)), Vector3(w + 0.02, 0.12, 0.1), s.cadre.lightened(0.03))
	# les chaînes d'angle harpées : pierre sur la brique, brique sur l'enduit
	for k in 2:
		if not sans_chaine[k]:
			var cote := -1.0 if k == 0 else 1.0
			_chaine(o, t * Transform3D(Basis(), Vector3(cote * (w * 0.5 - 0.3), 0, 0)), H, s, cote)
	# les travées : des fenêtres hautes, plus courtes en montant
	var nf := clampi(int(round((w - 1.0) / 2.0)), 1, 7)
	var pas := (w - 1.2) / nf
	for e in niveaux:
		var y0 := RDC + e * ETAGE + 0.6
		var haute := 2.1 if e < 2 else (1.9 if e < niveaux - 1 else 1.6)
		for i in nf:
			var x := -w * 0.5 + 0.6 + pas * (i + 0.5)
			if absf(x) < float(s.get("evite", 0.0)):
				continue
			_fenetre(o, t, Vector3(x, y0, 0), 1.0, haute, s, s.balconnets and e == 0, s.fronton and e == 0)
			trous.append(Rect2(x - 1.05, y0 - 0.25, 2.1, haute + 0.75))
	if s.parement == "brique":
		_parement(o, t, -w * 0.5 + 0.1, w * 0.5 - 0.1, 0.62, H - 0.2, trous, s)
	return t * porte


## Une chaîne d'angle harpée, de bas en haut ; cote dit vers où sont les grandes pierres (0 : centrée).
static func _chaine(o: Outils, t: Transform3D, H: float, s: Dictionary, cote: float) -> void:
	var y := 0.6
	var k := 0
	var col: Color = s.cadre
	while y < H - 0.3:
		var large := 0.62 if k % 2 == 0 else 0.4
		var x := cote * (0.3 - large * 0.5) if cote != 0.0 else 0.0
		o.boite(t * Transform3D(Basis(), Vector3(x, y + 0.18, 0.05)), Vector3(large, 0.32, 0.1), col.lightened(0.02 if k % 2 == 0 else 0.0))
		y += 0.36
		k += 1


## Le parement de brique foraine : des assises que l'on devine par leurs joints clairs, et des briques plus
## sombres ou plus claires semées au hasard, sauf dans les baies et leurs encadrements.
static func _parement(o: Outils, t: Transform3D, x0: float, x1: float, y0: float, y1: float, trous: Array, s: Dictionary) -> void:
	var r := o.rng
	var brique: Color = s.brique
	var y := y0 + 0.3
	while y < y1:
		# les joints : un trait clair par bande, interrompu aux baies
		var x := x0
		while x < x1:
			var fin := x1
			for tr in trous:
				var rc: Rect2 = tr
				if y > rc.position.y and y < rc.end.y and rc.end.x > x:
					fin = minf(fin, maxf(rc.position.x, x))
			if fin - x > 0.2:
				o.boite(t * Transform3D(Basis(), Vector3((x + fin) * 0.5, y, 0.006)), Vector3(fin - x, 0.025, 0.012), JOINT.lerp(brique, 0.35))
			var suite := x1
			for tr in trous:
				var rc: Rect2 = tr
				if y > rc.position.y and y < rc.end.y and rc.position.x <= fin + 0.01 and rc.end.x > fin:
					suite = minf(suite, rc.end.x)
			x = suite if suite > fin else x1
		y += 0.6
	var nb := int((x1 - x0) * (y1 - y0) * 1.6)
	for i in nb:
		var q := Vector2(r.randf_range(x0 + 0.25, x1 - 0.25), r.randf_range(y0, y1))
		var dedans := false
		for tr in trous:
			if (tr as Rect2).grow(0.08).has_point(q):
				dedans = true
				break
		if dedans:
			continue
		var c := BRIQUE_SOMBRE.lerp(brique, r.randf_range(0.0, 0.5)) if r.randf() < 0.6 else brique.lightened(r.randf_range(0.08, 0.18))
		o.boite(t * Transform3D(Basis(), Vector3(q.x, q.y, 0.008)), Vector3(0.42 if r.randf() < 0.75 else 0.2, 0.1, 0.016), c)


## Une fenêtre toulousaine : haute, l'encadrement de pierre (ou de brique sur l'enduit), l'arc surbaissé de
## briques à clé de pierre au-dessus, l'appui saillant, les persiennes ouvertes, le balconnet de fonte au premier.
static func _fenetre(o: Outils, t: Transform3D, p: Vector3, l: float, h: float, s: Dictionary, balconnet: bool, fronton: bool) -> void:
	var tf := t * Transform3D(Basis(), p)
	var pts := _baie(l, h, "droite")
	o.profil(tf, pts, -0.02, 0.02, VERRE)
	_cadre(o, tf, pts, 0.14, 0.0, 0.18, s.cadre, s.cadre.darkened(0.14))
	o.boite(tf * Transform3D(Basis(), Vector3(0, h * 0.5, 0.05)), Vector3(0.06, h, 0.05), Color("f2ede2"))
	for k in 2:
		o.boite(tf * Transform3D(Basis(), Vector3(0, h * (0.36 + k * 0.32), 0.05)), Vector3(l, 0.05, 0.05), Color("f2ede2"))
	o.boite(tf * Transform3D(Basis(), Vector3(0, -0.07, 0.14)), Vector3(l + 0.4, 0.1, 0.28), PIERRE_SOMBRE.lightened(0.08))
	if s.arc:
		# l'arc surbaissé de briques posées en rayons, la clé de pierre au milieu
		var R := 1.1
		var c := Vector2(0, h + 0.14 - R)
		var a := asin((l * 0.5 + 0.2) / R)
		var nv := 9
		for i in nv:
			var ang := PI * 0.5 - a + 2.0 * a * (i + 0.5) / nv
			var q := c + Vector2(cos(ang), sin(ang)) * (R + 0.14)
			var col: Color = PIERRE if i == nv / 2 else (BRIQUE_SOMBRE if i % 2 == 0 else (s.brique as Color).darkened(0.1))
			var hh := 0.38 if i == nv / 2 else 0.3
			o.boite(tf * Transform3D(Basis(Vector3.BACK, ang - PI * 0.5), Vector3(q.x, q.y, 0.07)), Vector3(0.11 if i != nv / 2 else 0.2, hh, 0.12), col)
	elif fronton:
		# le linteau à corniche des étages nobles
		o.boite(tf * Transform3D(Basis(), Vector3(0, h + 0.3, 0.16)), Vector3(l + 0.6, 0.14, 0.32), s.cadre)
		o.boite(tf * Transform3D(Basis(), Vector3(0, h + 0.17, 0.1)), Vector3(l + 0.36, 0.14, 0.2), s.cadre.darkened(0.06))
	if balconnet:
		# le balconnet de fonte sur sa dalle de pierre
		var z := 0.42
		o.boite(tf * Transform3D(Basis(), Vector3(0, -0.12, 0.24)), Vector3(l + 0.5, 0.12, 0.5), PIERRE)
		o.boite(tf * Transform3D(Basis(), Vector3(0, 0.9, z)), Vector3(l + 0.4, 0.05, 0.05), FER)
		o.boite(tf * Transform3D(Basis(), Vector3(0, 0.04, z)), Vector3(l + 0.4, 0.04, 0.04), FER)
		var nb := 11
		for i in nb:
			o.boite(tf * Transform3D(Basis(), Vector3(-(l + 0.4) * 0.5 + (i + 0.5) * (l + 0.4) / nb, 0.47, z)), Vector3(0.02, 0.84, 0.02), FER)
		for cote in [-1.0, 1.0]:
			o.boite(tf * Transform3D(Basis(), Vector3(cote * (l * 0.5 + 0.2), 0.47, 0.22)), Vector3(0.03, 0.86, 0.42), FER)
		o.anneau(tf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.47, z)), 0.16, 0.2, 0.02, 10, FER)
		if s.fleurs and o.rng.randf() < 0.6:
			for i in 3:
				var q := Vector3(-l * 0.32 + i * l * 0.32, 0.98, z + 0.04)
				o.boule(tf * q, Vector3(0.2, 0.14, 0.13), VERT, 0.25, Outils.FEUILLE, 0.06, 0.2)
				o.boule(tf * (q + Vector3(0, 0.07, 0.06)), Vector3(0.13, 0.08, 0.09), s.fleur, 0.3, Outils.FEUILLE, 0.08, 0.2)
	elif s.fleurs and o.rng.randf() < 0.2:
		# une jardinière sur l'appui
		o.boite(tf * Transform3D(Basis(), Vector3(0, 0.08, 0.2)), Vector3(l - 0.1, 0.2, 0.2), Color("8a5a3a"))
		o.boule(tf * Vector3(0, 0.26, 0.22), Vector3(l * 0.5, 0.16, 0.14), VERT, 0.25, Outils.FEUILLE, 0.06, 0.2)
		o.boule(tf * Vector3(0, 0.32, 0.26), Vector3(l * 0.42, 0.1, 0.1), s.fleur, 0.3, Outils.FEUILLE, 0.08, 0.2)
	var per: Color = s.persiennes
	if per.a > 0.0:
		for cote in [-1.0, 1.0]:
			var x: float = cote * (l * 0.5 + 0.14 + 0.27)
			o.boite(tf * Transform3D(Basis(), Vector3(x, h * 0.5, 0.04)), Vector3(0.52, h, 0.05), per)
			for k in int(h / 0.15):
				o.boite(tf * Transform3D(Basis(), Vector3(x, 0.1 + k * 0.15, 0.075)), Vector3(0.46, 0.03, 0.02), per.darkened(0.14))


## Le rez-de-chaussée en arcades de brique : arcs en plein cintre sur piliers à impostes de pierre, les
## boutiques vitrées dans le fond ; l'arc du milieu, plus haut, est un passage ouvert quand le nombre est impair.
static func _arcades(o: Outils, t: Transform3D, w: float, s: Dictionary) -> Vector3:
	var n := clampi(int(round(w / 3.0)), 2, 9)
	var pas := w / n
	var l := pas - 0.8
	var brique: Color = s.brique
	# le rez-de-chaussée est toujours de brique, même sous une façade enduite
	o.boite(t * Transform3D(Basis(), Vector3(0, RDC * 0.5, 0.06)), Vector3(w + 0.02, RDC, 0.12), brique)
	for i in n:
		var x := -w * 0.5 + pas * (i + 0.5)
		var passage := n % 2 == 1 and i == n / 2
		var h := 3.5
		var pts := _baie(l, h, "plein_cintre")
		var tf := t * Transform3D(Basis(), Vector3(x, 0.0, 0.12))
		o.profil(tf, pts, -0.02, 0.02, SOMBRE if passage else s.bois)
		if not passage:
			o.profil(tf * Transform3D(Basis(), Vector3(0, 0.55, 0.0)), _baie(l - 0.3, h - 0.7, "plein_cintre"), 0.02, 0.04, VERRE.lightened(0.15))
			o.boite(tf * Transform3D(Basis(), Vector3(0, 0.27, 0.03)), Vector3(l - 0.1, 0.54, 0.04), (s.bois as Color).darkened(0.15))
		# l'archivolte de briques en rayons, la clé de pierre
		var nv := 15
		for k in nv:
			var ang := PI * k / (nv - 1)
			var q := Vector2(0, h - l * 0.5) + Vector2(cos(ang), sin(ang)) * (l * 0.5 + 0.17)
			var col: Color = PIERRE if k == nv / 2 else (BRIQUE_SOMBRE if k % 2 == 0 else brique.darkened(0.08))
			o.boite(tf * Transform3D(Basis(Vector3.BACK, ang - PI * 0.5), Vector3(q.x, q.y, 0.1)), Vector3(0.13, 0.34, 0.16), col)
		for cote in [-1.0, 1.0]:
			o.boite(tf * Transform3D(Basis(), Vector3(cote * (l * 0.5 + 0.12), h - l * 0.5, 0.1)), Vector3(0.36, 0.14, 0.2), PIERRE)
	for i in n + 1:
		var x := clampf(-w * 0.5 + pas * i, -w * 0.5 + 0.22, w * 0.5 - 0.22)
		o.boite(t * Transform3D(Basis(), Vector3(x, 1.7, 0.2)), Vector3(0.44, 3.4, 0.2), brique.lightened(0.03))
		o.boite(t * Transform3D(Basis(), Vector3(x, 0.3, 0.24)), Vector3(0.5, 0.6, 0.26), PIERRE_SOMBRE)
	var mid := 0.0 if n % 2 == 1 else -w * 0.5 + pas * (n / 2 - 0.5)
	return Vector3(mid, 0, 0.6)


## La devanture : une boutique en applique de bois peint, vitrine et porte, le bandeau d'enseigne, le store.
## Le café a son store crème en avancée et ses lettres, le commerce son store rayé vert et blanc, le restaurant
## sa façade bleu nuit et son enseigne dorée.
static func _devanture(o: Outils, t: Transform3D, w: float, s: Dictionary, genre: String, n: Node3D) -> Vector3:
	var bois: Color = s.bois
	var toile: Array = (s.toile as Array).map(func(h): return Color(str(h)))
	var texte: String = s.enseigne
	match genre:
		"cafe":
			bois = Color("3a2a24")
			if not s.toile_donnee:
				toile = [Color("f0e3c4"), Color("f0e3c4")]
			if texte == "":
				texte = "CAFÉ SAINT-GEORGES"
		"commerce":
			if not s.toile_donnee:
				toile = [Color("2f6a4a"), Color("f3ead6")]
		"restaurant":
			bois = Color("1f2f4a")
			if texte == "":
				texte = "RESTAURANT"
	var l := w - 1.0
	# le rez-de-chaussée de brique autour de la devanture
	o.boite(t * Transform3D(Basis(), Vector3(0, RDC * 0.5, 0.05)), Vector3(w + 0.02, RDC, 0.1), s.mur)
	o.boite(t * Transform3D(Basis(), Vector3(0, 1.8, 0.16)), Vector3(l + 0.3, 3.3, 0.14), bois)
	for cote in [-1.0, 1.0]:
		o.boite(t * Transform3D(Basis(), Vector3(cote * (l * 0.5 + 0.08), 1.9, 0.28)), Vector3(0.32, 3.8, 0.26), bois.darkened(0.12))
	o.boite(t * Transform3D(Basis(), Vector3(0, 3.82, 0.34)), Vector3(l + 0.66, 0.16, 0.46), bois.darkened(0.25))
	var baies := maxi(1, int(l / 1.8))
	var lb := l / baies
	var x_porte := -l * 0.5 + lb * (baies / 2 + 0.5)
	for i in baies:
		var x := -l * 0.5 + lb * (i + 0.5)
		if absf(x - x_porte) < 0.01:
			o.boite(t * Transform3D(Basis(), Vector3(x, 1.3, 0.24)), Vector3(1.15, 2.5, 0.03), bois.darkened(0.2))
			o.boite(t * Transform3D(Basis(), Vector3(x, 1.55, 0.26)), Vector3(0.8, 1.6, 0.02), VERRE.lightened(0.2))
		else:
			o.boite(t * Transform3D(Basis(), Vector3(x, 1.9, 0.24)), Vector3(lb - 0.25, 2.0, 0.03), VERRE.lightened(0.2))
			o.boite(t * Transform3D(Basis(), Vector3(x, 0.45, 0.26)), Vector3(lb - 0.2, 0.7, 0.05), bois.darkened(0.15))
			for k in 2:
				o.boite(t * Transform3D(Basis(), Vector3(x - (lb - 0.25) * 0.5 + (k + 1) * (lb - 0.25) / 3.0, 1.9, 0.27)), Vector3(0.04, 2.0, 0.03), bois.darkened(0.2))
	var bandeau: Color = Color("c9a24a") if genre == "restaurant" else (Color("efe4c8") if genre == "commerce" else bois.lightened(0.05))
	o.boite(t * Transform3D(Basis(), Vector3(0, 3.33, 0.26)), Vector3(l - 0.3, 0.5, 0.06), bois if genre == "restaurant" else bandeau)
	if texte != "":
		var lab := Label3D.new()
		lab.text = texte
		lab.font_size = 72
		lab.pixel_size = 0.0062
		lab.modulate = Color("e8c86a") if genre == "restaurant" else (Color("f3e6c0") if genre == "cafe" else bois)
		lab.outline_size = 0
		lab.transform = t * Transform3D(Basis(), Vector3(0, 3.33, 0.3))
		n.add_child(lab)
	if genre != "restaurant":
		# le store en avancée et son lambrequin
		var bandes := int(l / 0.5)
		var lt := l / bandes
		var avance := 2.2 if genre == "cafe" else 1.4
		var pente := 0.34
		for i in bandes:
			var c: Color = toile[i % 2]
			var x := -l * 0.5 + (i + 0.5) * lt
			o.boite(t * Transform3D(Basis(Vector3.RIGHT, pente), Vector3(x, 3.0 - sin(pente) * avance * 0.5, 0.3 + cos(pente) * avance * 0.5)), Vector3(lt, 0.04, avance), c)
			o.boite(t * Transform3D(Basis(), Vector3(x, 3.0 - sin(pente) * avance - 0.1, 0.3 + cos(pente) * avance)), Vector3(lt, 0.22, 0.02), c)
	else:
		# les deux lanternes de part et d'autre
		for cote in [-1.0, 1.0]:
			var q := Vector3(cote * (l * 0.5 + 0.1), 2.9, 0.55)
			o.boite(t * Transform3D(Basis(), q), Vector3(0.22, 0.34, 0.22), Color("f6d98a"), Outils.LUEUR)
			o.boite(t * Transform3D(Basis(), q + Vector3(0, 0.22, 0)), Vector3(0.28, 0.06, 0.28), FER)
	if genre == "cafe":
		for cote in [-1.0, 1.0]:
			var q := Vector3(x_porte + cote * 1.0, 0, 0.6)
			o.boite(t * Transform3D(Basis(), q + Vector3(0, 0.3, 0)), Vector3(0.5, 0.6, 0.5), Color("8a5a3a"))
			o.boule(t * (q + Vector3(0, 0.95, 0)), Vector3(0.36, 0.45, 0.36), VERT, 0.15, Outils.FEUILLE, 0.06, 0.3)
	return Vector3(x_porte, 0, 0.6)


## Un rez-de-chaussée d'habitation : la porte à imposte et ses fenêtres grillagées ; avec porche, la grande
## porte cochère en plein cintre au milieu, à encadrement de pierre.
static func _logis(o: Outils, t: Transform3D, w: float, s: Dictionary, porche: bool, trous: Array) -> Vector3:
	var r := o.rng
	var x_porte := 0.0 if w < 6.0 or porche else (w * 0.5 - 1.5) * (1.0 if r.randf() < 0.5 else -1.0)
	var lp := 2.6 if porche else 1.3
	var hp := 3.5 if porche else 2.9
	var pts := _baie(lp, hp, "plein_cintre" if porche or s.arc else "droite")
	var tp := t * Transform3D(Basis(), Vector3(x_porte, 0.12, 0.12))
	o.profil(tp, pts, -0.02, 0.02, s.bois)
	if not porche:
		o.profil(tp * Transform3D(Basis(), Vector3(0, 2.2, 0)), _baie(1.1, 0.62, "droite"), 0.02, 0.04, VERRE)
	else:
		o.boite(tp * Transform3D(Basis(), Vector3(0, 1.4, 0.04)), Vector3(0.05, 2.8, 0.04), (s.bois as Color).darkened(0.25))
	_cadre(o, tp, pts, 0.3 if porche else 0.2, 0.0, 0.28, PIERRE, PIERRE.darkened(0.14))
	o.boite(tp * Transform3D(Basis(), Vector3(0.4, 1.15, 0.06)), Vector3(0.07, 0.07, 0.06), Color("c9a64a"))
	o.boite(t * Transform3D(Basis(), Vector3(x_porte, 0.07, 0.5)), Vector3(lp + 0.8, 0.14, 0.6), PIERRE_SOMBRE)
	trous.append(Rect2(x_porte - lp * 0.5 - 0.4, 0, lp + 0.8, hp + 0.6))
	var xs := []
	var x := x_porte - (2.6 if porche else 2.0)
	while x > -w * 0.5 + 0.8:
		xs.append(x)
		x -= 2.0
	x = x_porte + (2.6 if porche else 2.0)
	while x < w * 0.5 - 0.8:
		xs.append(x)
		x += 2.0
	for xf in xs:
		var tf := t * Transform3D(Basis(), Vector3(xf, 1.0, 0.1))
		var pf := _baie(1.0, 2.1, "droite")
		o.profil(tf, pf, -0.02, 0.02, VERRE)
		_cadre(o, tf, pf, 0.14, 0.0, 0.2, s.cadre, (s.cadre as Color).darkened(0.12))
		for k in 5:
			o.boite(tf * Transform3D(Basis(), Vector3(-0.4 + k * 0.2, 1.05, 0.08)), Vector3(0.025, 2.1, 0.025), FER)
		o.boite(tf * Transform3D(Basis(), Vector3(0, -0.07, 0.14)), Vector3(1.36, 0.1, 0.28), PIERRE_SOMBRE.lightened(0.08))
		trous.append(Rect2(xf - 0.75, 0.75, 1.5, 2.6))
	return Vector3(x_porte, 0, 0.8)


## L'hôtel de Lafage : la longue façade enduite de blanc à chaînes et cordons de brique, le rez-de-chaussée en
## arcades de brique, l'avant-corps central en saillie couronné d'un fronton triangulaire percé d'un oculus.
static func _lafage(o: Outils, w: float, niveaux: int, s: Dictionary, n: Node3D) -> Vector3:
	var H := RDC + niveaux * ETAGE
	var la := 8.2
	var saillie := 0.6
	# la façade de part et d'autre de l'avant-corps, sans fenêtre derrière lui
	s["evite"] = la * 0.5 + 0.9
	var porte := _facade(o, Transform3D(), w, niveaux, "arcades", s, n, [false, false])
	s["evite"] = 0.0
	# l'avant-corps : un bloc en saillie, sa propre façade et ses chaînes
	o.boite(Transform3D(Basis(), Vector3(0, H * 0.5, saillie * 0.5)), Vector3(la, H, saillie), s.mur, Outils.DUR, true)
	_facade(o, Transform3D(Basis(), Vector3(0, 0, saillie)), la, niveaux, "arcades", s, n, [false, false])
	# le fronton, sa corniche et son oculus
	var hf := 2.6
	var tri := PackedVector2Array([Vector2(-la * 0.5 - 0.3, 0), Vector2(la * 0.5 + 0.3, 0), Vector2(0, hf)])
	var tf := Transform3D(Basis(), Vector3(0, H + 0.15, 0))
	o.profil(tf, tri, -1.0, saillie + 0.05, s.mur)
	o.profil(tf, Outils.grossir(tri, 0.22), saillie - 0.1, saillie + 0.2, s.cadre)
	o.boite(Transform3D(Basis(), Vector3(0, H + 0.08, saillie * 0.5)), Vector3(la + 0.8, 0.22, saillie + 0.5), s.cadre)
	var rond := Outils.arc(Vector2.ZERO, 0.55, 0.0, TAU, 18)
	var to := Transform3D(Basis(), Vector3(0, H + 1.05, saillie + 0.07))
	o.profil(to, rond, -0.02, 0.02, VERRE)
	_cadre(o, to, rond, 0.18, 0.0, 0.2, PIERRE, PIERRE.darkened(0.12))
	# le toit de l'avant-corps, qui monte derrière le fronton
	var pente := atan2(hf, la * 0.5)
	var long := sqrt(hf * hf + la * la * 0.25) + 0.4
	for cote in [-1.0, 1.0]:
		var b := Basis(Vector3.BACK, -cote * pente)
		o.boite(Transform3D(b, Vector3(cote * la * 0.25, H + 0.15 + hf * 0.5, -1.5 + saillie * 0.5) + b * Vector3(0, 0.12, 0)), Vector3(long, 0.18, 3.2 + saillie), TUILE[0])
	return porte + Vector3(0, 0, saillie)


## Les fenêtres de l'angle courbe (place Wilson) : le parement suit le quart de tour, une fenêtre au milieu de
## l'arc à chaque étage, la boutique en bas.
static func _courbe(o: Outils, c: Vector3, R: float, niveaux: int, s: Dictionary) -> void:
	var H := RDC + niveaux * ETAGE
	var ang := PI * 0.25
	var dir := Vector3(sin(ang), 0, cos(ang))
	var b := Basis(Vector3.UP, ang)
	var tf := Transform3D(b, c + dir * R)
	# la vitrine du rez-de-chaussée et ses deux pilastres
	o.boite(tf * Transform3D(Basis(), Vector3(0, 1.9, 0.08)), Vector3(1.9, 2.8, 0.06), VERRE.lightened(0.2))
	o.boite(tf * Transform3D(Basis(), Vector3(0, 3.5, 0.1)), Vector3(2.3, 0.4, 0.1), s.bois)
	for e in niveaux:
		var y0 := RDC + e * ETAGE + 0.6
		_fenetre(o, tf, Vector3(0, y0, 0.02), 1.0, 2.0 if e < niveaux - 1 else 1.6, s, s.balconnets, false)
	# les cordons d'étage qui suivent la courbe
	for e in niveaux + 1:
		var y := RDC + e * ETAGE - (0.04 if e > 0 else -0.04)
		if e == niveaux:
			y = H - 0.2
		o.anneau(Transform3D(Basis(), c + Vector3(0, y - 0.06, 0)), R - 0.05, R + 0.12, 0.12, 16, s.cadre)


## Les pans de bois des étages : poteaux, sablières et décharges sombres sur un hourdis enduit, chaque étage en
## léger encorbellement sur le précédent.
static func _pans_de_bois(o: Outils, w: float, niveaux: int, s: Dictionary) -> void:
	var bois := Color("4a3426")
	var hourdis := Color("eadcc0")
	for e in niveaux:
		var y0 := RDC + e * ETAGE
		var z := 0.1 + (e + 1) * 0.22
		o.boite(Transform3D(Basis(), Vector3(0, y0 + ETAGE * 0.5, z * 0.5)), Vector3(w, ETAGE, z), hourdis)
		o.boite(Transform3D(Basis(), Vector3(0, y0 + 0.1, z + 0.02)), Vector3(w + 0.1, 0.2, 0.08), bois)
		o.boite(Transform3D(Basis(), Vector3(0, y0 + ETAGE - 0.1, z + 0.02)), Vector3(w + 0.1, 0.18, 0.08), bois)
		var np := int(w / 0.9)
		for i in np + 1:
			var x := -w * 0.5 + 0.08 + i * (w - 0.16) / np
			o.boite(Transform3D(Basis(), Vector3(x, y0 + ETAGE * 0.5, z + 0.03)), Vector3(0.14, ETAGE - 0.2, 0.08), bois)
			if i < np and i % 2 == 0:
				var dx := (w - 0.16) / np
				var a := atan2(ETAGE - 0.4, dx)
				o.boite(Transform3D(Basis(Vector3.BACK, a), Vector3(x + dx * 0.5, y0 + ETAGE * 0.5, z + 0.035)), Vector3(sqrt(dx * dx + 2.8 * 2.8) * 0.92, 0.1, 0.06), bois)
		# l'encorbellement : les abouts de solives sous chaque étage
		for i in int(w / 0.5):
			o.boite(Transform3D(Basis(), Vector3(-w * 0.5 + 0.25 + i * 0.5, y0 - 0.02, z - 0.05)), Vector3(0.12, 0.14, 0.3), bois)
		var nf := clampi(int(round((w - 1.0) / 2.0)), 1, 5)
		var pas := (w - 1.2) / nf
		for i in nf:
			var x := -w * 0.5 + 0.6 + pas * (i + 0.5)
			var tf := Transform3D(Basis(), Vector3(x, y0 + 0.8, z + 0.02))
			var pts := _baie(0.9, 1.6, "droite")
			o.profil(tf, pts, 0.0, 0.04, VERRE)
			_cadre(o, tf, pts, 0.1, 0.0, 0.08, bois, bois.darkened(0.2))


## La vigne qui grimpe d'un pied de façade jusqu'au premier étage et file sous le bandeau.
static func _vigne(o: Outils, w: float, H: float, r: RandomNumberGenerator) -> void:
	var cote := -1.0 if r.randf() < 0.5 else 1.0
	var x0 := cote * (w * 0.5 - 0.6)
	var haut := minf(H - 1.0, RDC + ETAGE * r.randf_range(0.6, 1.6))
	var y := 0.3
	while y < haut:
		var t := r.randf_range(0.3, 0.46)
		o.boule(Vector3(x0 + r.randf_range(-0.25, 0.25), y, 0.38), Vector3(t, t, 0.22), VERT.lightened(r.randf_range(-0.05, 0.15)), 0.25, Outils.FEUILLE, 0.08, 0.2)
		if r.randf() < 0.25:
			o.boule(Vector3(x0 + r.randf_range(-0.3, 0.3), y, 0.52), Vector3(0.12, 0.12, 0.1), Color("d04a8a"), 0.2, Outils.FEUILLE, 0.08, 0.2)
		y += r.randf_range(0.3, 0.5)
	var x := x0
	for i in int(w * 0.35):
		x -= cote * r.randf_range(0.35, 0.6)
		if absf(x) > w * 0.5 - 0.4:
			break
		o.boule(Vector3(x, haut - r.randf_range(0.0, 0.5), 0.38), Vector3(0.42, 0.3, 0.2), VERT.lightened(0.08), 0.25, Outils.FEUILLE, 0.08, 0.2)


## Les tuiles canal d'un pan : des rangs de couvrants qui descendent la pente, du faîte à l'égout.
static func _canaux(o: Outils, bas_a: Vector3, bas_b: Vector3, haut_a: Vector3, haut_b: Vector3, nrm: Vector3) -> void:
	var long := bas_a.distance_to(bas_b)
	var nb := int(long / 0.32)
	var nn := nrm.normalized()
	for i in nb:
		var f := (i + 0.5) / nb
		var a := bas_a.lerp(bas_b, f)
		var b := haut_a.lerp(haut_b, f)
		var col: Color = TUILE[1] if i % 3 != 1 else TUILE[2]
		o.branche(a + nn * 0.04, b + nn * 0.04, 0.07, 0.07, col, 4)


## Le toit à deux pans en tuile canal, faîtage parallèle à la rue, pignons de brique sur les côtés ; rend le faîte.
static func _deux_pans(o: Outils, w: float, d: float, H: float, s: Dictionary) -> float:
	var e := 0.5
	var pente := deg_to_rad(25.0)
	var y0 := H + 0.3
	var hr := (d * 0.5 + e) * tan(pente)
	var sommet := y0 + hr
	var zc := -d * 0.5
	var x0 := -w * 0.5 - 0.15
	var x1 := w * 0.5 + 0.15
	for cote in [1.0, -1.0]:
		var zb: float = zc + cote * (d * 0.5 + e)
		var a := Vector3(x0, y0, zb)
		var b := Vector3(x1, y0, zb)
		var c := Vector3(x1, sommet, zc)
		var dd := Vector3(x0, sommet, zc)
		var nrm := (b - a).cross(c - a)
		if nrm.y < 0.0:
			nrm = -nrm
		o.quad(a, b, c, dd, nrm, TUILE[0])
		o.quad(a - Vector3(0, 0.1, 0), b - Vector3(0, 0.1, 0), c - Vector3(0, 0.1, 0), dd - Vector3(0, 0.1, 0), -nrm, Color("8a5a3a"))
		_canaux(o, a, b, dd, c, nrm)
	# les pignons de brique, sous les rives
	for cote in [-1.0, 1.0]:
		var pg := PackedVector2Array([Vector2(-d * 0.5, 0), Vector2(d * 0.5, 0), Vector2(0, hr + 0.3 - e * tan(pente))])
		var b := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
		o.profil(Transform3D(b, Vector3(cote * w * 0.5, H, zc)), pg, -0.12, 0.12, s.mur.darkened(0.05) if s.parement != "enduit" else (s.brique as Color))
	o.branche(Vector3(x0 - 0.05, sommet + 0.06, zc), Vector3(x1 + 0.05, sommet + 0.06, zc), 0.12, 0.12, TUILE[1], 6)
	return sommet + 0.1


## Le toit à quatre pans en tuile canal, à 25°, sur sa génoise ; rend le faîte.
static func _quatre_pans(o: Outils, w: float, d: float, H: float, s: Dictionary) -> float:
	var e := 0.5
	var pente := deg_to_rad(25.0)
	var x0 := -w * 0.5 - e
	var x1 := w * 0.5 + e
	var z0 := e
	var z1 := -d - e
	var demi := minf(x1 - x0, z0 - z1) * 0.5
	var hr := demi * tan(pente)
	var y0 := H + 0.3
	var sommet := y0 + hr
	var cz := (z0 + z1) * 0.5
	var a: Vector3
	var b: Vector3
	if x1 - x0 >= z0 - z1:
		a = Vector3(x0 + demi, sommet, cz)
		b = Vector3(x1 - demi, sommet, cz)
	else:
		a = Vector3(0, sommet, z0 - demi)
		b = Vector3(0, sommet, z1 + demi)
	var c00 := Vector3(x0, y0, z0)
	var c10 := Vector3(x1, y0, z0)
	var c11 := Vector3(x1, y0, z1)
	var c01 := Vector3(x0, y0, z1)
	var pans := []
	if x1 - x0 >= z0 - z1:
		pans = [[c00, c10, b, a], [c11, c01, a, b], [c10, c11, b], [c01, c00, a]]
	else:
		pans = [[c00, c10, a], [c11, c01, b], [c10, c11, b, a], [c01, c00, a, b]]
	for pan in pans:
		var nrm: Vector3 = (pan[1] - pan[0]).cross(pan[2] - pan[0])
		if nrm.y < 0.0:
			nrm = -nrm
		if pan.size() == 4:
			o.quad(pan[0], pan[1], pan[2], pan[3], nrm, TUILE[0])
			o.quad(pan[0] - Vector3(0, 0.1, 0), pan[1] - Vector3(0, 0.1, 0), pan[2] - Vector3(0, 0.1, 0), pan[3] - Vector3(0, 0.1, 0), -nrm, Color("8a5a3a"))
			_canaux(o, pan[0], pan[1], pan[3], pan[2], nrm)
		else:
			o.tri(pan[0], pan[1], pan[2], nrm, TUILE[0])
			o.tri(pan[0] - Vector3(0, 0.1, 0), pan[1] - Vector3(0, 0.1, 0), pan[2] - Vector3(0, 0.1, 0), -nrm, Color("8a5a3a"))
			_canaux(o, pan[0], pan[1], pan[2], pan[2], nrm)
	if a.distance_to(b) > 0.01:
		o.branche(a + Vector3(0, 0.06, 0), b + Vector3(0, 0.06, 0), 0.12, 0.12, TUILE[1], 6)
	for c in [c00, c10, c11, c01]:
		o.branche(c, a if c.distance_to(a) < c.distance_to(b) else b, 0.09, 0.09, TUILE[1], 5)
	return sommet + 0.1


## La génoise toulousaine : trois rangs de tuiles en encorbellement sous l'égout, liés au mortier clair, en
## façade et au revers (et le long de la seconde façade d'un angle).
static func _genoise(o: Outils, w: float, d: float, H: float, toit: String, R: float) -> void:
	if toit == "mansarde":
		return
	for k in 3:
		var ek := 0.12 + k * 0.14
		var y := H + 0.22 - k * 0.13
		o.boite(Transform3D(Basis(), Vector3(0, y, ek * 0.5)), Vector3(w + ek * 2.0, 0.08, ek), TUILE[2].darkened(k * 0.06))
		o.boite(Transform3D(Basis(), Vector3(0, y - 0.065, ek * 0.5 - 0.01)), Vector3(w + ek * 2.0 - 0.02, 0.05, ek - 0.02), JOINT)
		o.boite(Transform3D(Basis(), Vector3(0, y, -d - ek * 0.5)), Vector3(w + ek * 2.0, 0.08, ek), TUILE[2].darkened(k * 0.06))
		if toit == "quatre_pans":
			for cote in [-1.0, 1.0]:
				o.boite(Transform3D(Basis(), Vector3(cote * (w * 0.5 + ek * 0.5), y, -d * 0.5)), Vector3(ek, 0.08, d + ek * 2.0), TUILE[2].darkened(k * 0.06))
				o.boite(Transform3D(Basis(), Vector3(cote * (w * 0.5 + ek * 0.5 - 0.01), y - 0.065, -d * 0.5)), Vector3(ek - 0.02, 0.05, d + ek * 2.0 - 0.02), JOINT)


## La mansarde d'ardoise de l'immeuble XIXe (place Wilson) : le brisis raide et ses lucarnes, le terrasson, sur
## la façade et la seconde façade ; un dôme d'ardoise coiffe l'angle courbe. Rend le faîte.
static func _mansarde(o: Outils, w: float, d: float, H: float, R: float) -> float:
	var hb := 2.8
	var recul := 1.0
	var ht := 1.3
	# la corniche de pierre qui fait le tour
	o.boite(Transform3D(Basis(), Vector3(-R * 0.5, H + 0.1, 0.2)), Vector3(w - R + 0.3, 0.26, 0.5), PIERRE)
	o.boite(Transform3D(Basis(), Vector3(w * 0.5 + 0.2, H + 0.1, -(d + R) * 0.5)), Vector3(0.5, 0.26, d - R + 0.3), PIERRE)
	var pts := PackedVector2Array([Vector2(0.3, H + 0.2), Vector2(-recul, H + hb), Vector2(-d * 0.5, H + hb + ht),
		Vector2(-d + recul, H + hb), Vector2(-d - 0.3, H + 0.2)])
	var b := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	o.profil(Transform3D(b, Vector3.ZERO), pts, -(w * 0.5 - R), w * 0.5 + 0.1, [ARDOISE[1], ARDOISE[0]])
	# la mansarde de la seconde façade, tournée vers +X
	var pts2 := PackedVector2Array([Vector2(0.3, H + 0.2), Vector2(-recul, H + hb), Vector2(-w * 0.5, H + hb + ht),
		Vector2(-w + recul, H + hb), Vector2(-w - 0.3, H + 0.2)])
	o.profil(Transform3D(Basis(), Vector3(w * 0.5, 0, 0)), pts2, -d - 0.1, -R, [ARDOISE[1], ARDOISE[0]])
	# le dôme de l'angle
	var c := Vector3(w * 0.5 - R, H + 0.2, -R)
	o.cylindre(Transform3D(Basis(), c), R + 0.3, R - 0.7, hb, 16, ARDOISE[0])
	o.cylindre(Transform3D(Basis(), c + Vector3(0, hb, 0)), R - 0.7, 0.3, ht + 0.6, 16, ARDOISE[1])
	o.cylindre(Transform3D(Basis(), c + Vector3(0, hb + ht + 0.6, 0)), 0.05, 0.05, 1.0, 4, FER)
	o.boite(Transform3D(Basis(), Vector3(-R * 0.5, H + hb + 0.02, -recul)), Vector3(w - R + 0.2, 0.08, 0.14), Color("9aa0a3"))
	# les lucarnes à fronton cintré, sur la façade et la seconde façade
	for face in 2:
		var long := (w - R) if face == 0 else (d - R)
		var nl := clampi(int(round((long - 1.2) / 2.2)), 1, 6)
		var pas := (long - 1.4) / nl
		for i in nl:
			var u := -long * 0.5 + 0.7 + pas * (i + 0.5)
			var t := Transform3D(Basis(), Vector3(u - R * 0.5, H + 0.7, 0.0))
			if face == 1:
				t = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w * 0.5, H + 0.7, -(d + R) * 0.5 - u))
			o.boite(t * Transform3D(Basis(), Vector3(0, 0.9, -0.55)), Vector3(1.3, 1.8, 1.1), PIERRE)
			var pf := _baie(0.8, 1.3, "plein_cintre")
			var tf := t * Transform3D(Basis(), Vector3(0, 0.3, 0.0))
			o.profil(tf, pf, -0.02, 0.02, VERRE)
			_cadre(o, tf, pf, 0.14, 0.0, 0.18, PIERRE, PIERRE.darkened(0.12))
			o.profil(t * Transform3D(Basis(), Vector3(0, 1.8, 0.1)), Outils.arc(Vector2.ZERO, 0.8, 0.0, PI, 8), -1.1, 0.0, [PIERRE.darkened(0.04), ARDOISE[0]])
	return H + hb + ht


## Le contour d'une baie de largeur l et de hauteur h (au sommet), droite, cintrée ou en plein cintre.
static func _baie(l: float, h: float, forme: String) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(l * 0.5, 0)])
	match forme:
		"plein_cintre":
			var r := l * 0.5
			pts.append(Vector2(l * 0.5, h - r))
			pts.append_array(Outils.arc(Vector2(0, h - r), r, 0.0, PI, 12))
			pts.append(Vector2(-l * 0.5, h - r))
		"cintree":
			var f := 0.2
			var R := (l * l * 0.25 + f * f) / (2.0 * f)
			var c := Vector2(0, h - R)
			var a := asin(l * 0.5 / R)
			pts.append(Vector2(l * 0.5, h - f))
			pts.append_array(Outils.arc(c, R, PI * 0.5 - a, PI * 0.5 + a, 8))
		_:
			pts.append(Vector2(l * 0.5, h))
			pts.append(Vector2(-l * 0.5, h))
	pts.append(Vector2(-l * 0.5, 0))
	return _sans_doublons(pts)


static func _sans_doublons(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		if out.is_empty() or out[out.size() - 1].distance_to(q) > 1e-4:
			out.append(q)
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) < 1e-4:
		out.remove_at(out.size() - 1)
	return out


## L'encadrement d'une baie (contour convexe pts) : une face de largeur e en avant, de z0 à z1, ses flancs
## extérieurs, et les tableaux intérieurs qui descendent jusqu'au verre (col_tableau, plus sombre).
static func _cadre(o: Outils, t: Transform3D, pts: PackedVector2Array, e: float, z0: float, z1: float, col: Color, col_tableau: Color) -> void:
	pts = _sans_doublons(pts)
	if Geometry2D.is_polygon_clockwise(pts):
		pts.reverse()
	var n := pts.size()
	var ext := PackedVector2Array()
	for i in n:
		var a := pts[(i - 1 + n) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		var n1 := Vector2(b.y - a.y, a.x - b.x).normalized()
		var n2 := Vector2(c.y - b.y, b.x - c.x).normalized()
		var m := (n1 + n2).normalized()
		ext.append(b + m * e / maxf(m.dot(n1), 0.35))
	for i in n:
		var j := (i + 1) % n
		var a := pts[i]
		var b := pts[j]
		var ea := ext[i]
		var eb := ext[j]
		var dehors := Vector3(b.y - a.y, a.x - b.x, 0)
		o.quad(t * Vector3(a.x, a.y, z1), t * Vector3(b.x, b.y, z1), t * Vector3(eb.x, eb.y, z1), t * Vector3(ea.x, ea.y, z1), t.basis * Vector3(0, 0, 1), col)
		o.quad(t * Vector3(ea.x, ea.y, z0), t * Vector3(eb.x, eb.y, z0), t * Vector3(eb.x, eb.y, z1), t * Vector3(ea.x, ea.y, z1), t.basis * dehors, col.darkened(0.04))
		o.quad(t * Vector3(a.x, a.y, z0), t * Vector3(b.x, b.y, z0), t * Vector3(b.x, b.y, z1), t * Vector3(a.x, a.y, z1), t.basis * -dehors, col_tableau)
