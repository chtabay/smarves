extends RefCounted
## Le façadier lyonnais : un immeuble de la Presqu'île ou du Vieux-Lyon composé par type et graine. Le type
## fixe la silhouette (les étages, la largeur, le toit, le rez-de-chaussée) ; la graine tire le reste (l'enduit
## ocre, rose ou pierre dorée, les persiennes, les garde-corps, les balcons filants, les fleurs, la vigne, les
## souches de cheminée). Repère : façade vers +Z, origine au pied de la façade, au milieu, le corps vers −Z ;
## en mètres. L'immeuble d'angle a une seconde façade vers +X.
##   load("res://bibliotheque/facadier-lyonnais/1/facadier.gd").maison(parent, Vector3.ZERO, "bourgeois", 4)
const Outils := preload("res://bibliotheque/facadier-lyonnais/1/outils.gd")

## Les types : la maison de deux étages, l'immeuble classique (3), la maison basse à arcades, l'immeuble de
## quatre étages, la maison étroite, l'immeuble bourgeois (5 et sa mansarde d'ardoise), la façade à traboule,
## le café lyonnais, l'hôtel particulier, l'immeuble d'angle et la chapelle.
const TYPES := ["maison", "classique", "arcades", "immeuble", "etroite", "bourgeois", "traboule", "cafe", "hotel", "angle", "chapelle"]
## Pour chaque type : niveaux au-dessus du rez-de-chaussée, largeur (min, max), toit, rez-de-chaussée.
const GABARITS := {
	"maison": [2, 7.5, 9.0, "tuile", "logis"],
	"classique": [3, 9.0, 11.0, "tuile", "boutique"],
	"arcades": [1, 10.0, 12.0, "tuile", "arcades"],
	"immeuble": [4, 10.0, 12.0, "tuile", "boutique"],
	"etroite": [3, 4.6, 5.6, "tuile", "logis"],
	"bourgeois": [4, 12.0, 14.0, "mansarde", "arcades"],
	"traboule": [3, 9.0, 10.5, "tuile", "passage"],
	"cafe": [4, 10.0, 11.5, "tuile", "cafe"],
	"hotel": [3, 11.0, 13.0, "tuile", "pierre"],
	"angle": [4, 11.0, 12.0, "tuile", "boutique"],
}
const ENDUITS := {"ocre": "d99c45", "beige": "e0c48e", "rose": "d6826c", "saumon": "cc6f4c", "creme": "ead7ab",
	"jaune": "e5b54a", "pierre_doree": "c99a58", "gris": "c6bca3", "terre": "c27a4e"}
const TOITS := {"tuile": ["d9733f", "b85b30"], "ardoise": ["5a6170", "485060"]}
const PERSIENNES := ["8f9e8c", "b9b2a0", "6f7f8f", "e8e0cc", "9a6a4a"]
const DEVANTURES := ["7a2a2a", "2f4f3f", "2e3f5f", "5a3a28", "1f2a2a"]
const TOILES := [["b8322c", "b8322c"], ["b8322c", "f3ead6"], ["2f5f8f", "f3ead6"], ["e0a93a", "f3ead6"], ["2f5a3a", "2f5a3a"]]
const FLEURS := ["d04a8a", "b06ad0", "e0605a", "f2c14e", "f4f0e6"]
const PIERRE := Color("e7d6b0")
const PIERRE_SOMBRE := Color("c9b48a")
const VERRE := Color("4a5f78")
const FER := Color("2a2d30")
const SOMBRE := Color("2b2a2c")
const VERT := Color("5f9e33")

const RDC := 4.2
const ETAGE := 3.3


## Bâtit un immeuble sous parent, le pied de sa façade en p. Options, toutes facultatives : w et d (largeur et
## profondeur), niveaux, enduit (un nom d'ENDUITS ou un hexa), toit (« tuile », « mansarde »), rdc (« boutique »,
## « cafe », « arcades », « passage », « logis », « pierre »), persiennes (vrai, faux ou un hexa), balcons (vrai
## ou faux : les balcons filants), fleurs, vigne, enseigne (le texte de l'enseigne du café ou de la boutique),
## toile (deux hexas : le store ; deux fois le même, une toile unie), avancee (l'avancée des stores en mètres, 2 au
## café et 1,3 à la boutique par défaut), tuile (un hexa : la teinte des tuiles canal, le rouge orangé lyonnais sinon),
## pente (en degrés, 24 par défaut), chassis (0 à 3 fenêtres de toit sur le pan côté rue, 0 par défaut), souches
## (« grosses » : des souches plus larges et plus hautes, à quatre mitrons), store (faux : la boutique ou le café
## sans store banne ; vrai par défaut), grain (0 à 2, 0 par défaut : le grain des pans de tuile lisible de loin, un
## rang sur quatre assombri de moitié et des plaques de tuiles plus neuves ou plus passées de ± 32 %, sur à peu
## près six tuiles sur cinq rangs, neuf dixièmes de la surface ; à 1, l'écart-type de luminance des toits vus de
## 70 m passe de 33 à 40 sur la planche toits, ce que demandait le verdict n° 32 de Sathonay).
## Rend le nœud de l'immeuble ; ses métadonnées : type, graine, w, d, hauteur (au faîte), porte (le seuil).
static func maison(parent: Node3D, p: Vector3, type: String, graine: int, opt := {}) -> Node3D:
	if not type in TYPES:
		type = "classique"
	var o := Outils.new(graine * 2654435 + TYPES.find(type) * 13)
	var r := o.rng
	var n := Node3D.new()
	n.name = "Immeuble"
	n.position = p
	parent.add_child(n)
	if type == "chapelle":
		return _chapelle(o, n, graine, opt)
	var g: Array = GABARITS[type]
	var w := float(opt.get("w", r.randf_range(g[1], g[2])))
	var d := float(opt.get("d", w if type == "angle" else r.randf_range(10.0, 13.0)))
	var niveaux := clampi(int(opt.get("niveaux", g[0])), 1, 6)
	var nom := str(opt.get("enduit", ENDUITS.keys()[r.randi() % ENDUITS.size()] if type != "bourgeois" else ["creme", "pierre_doree", "beige"][r.randi() % 3]))
	var enduit := Color(str(ENDUITS.get(nom, nom)))
	var toit := str(opt.get("toit", g[3]))
	var rdc := str(opt.get("rdc", g[4]))
	var H := RDC + niveaux * ETAGE
	var style := {
		"enduit": enduit,
		"persiennes": _persiennes(opt, r),
		"balcons": bool(opt.get("balcons", r.randf() < 0.6 or type == "bourgeois")),
		"fleurs": bool(opt.get("fleurs", true)),
		"fleur": Color(FLEURS[r.randi() % FLEURS.size()]),
		"cintre": r.randf() < 0.35,
		"chaines": r.randf() < 0.6 or type in ["bourgeois", "hotel"],
		"toile": opt.get("toile", TOILES[r.randi() % TOILES.size()]),
		"enseigne": str(opt.get("enseigne", "")),
		"bois": Color(DEVANTURES[r.randi() % DEVANTURES.size()]),
		"avancee": float(opt.get("avancee", 0.0)),
		"toile_choisie": opt.has("toile"),
		"store": bool(opt.get("store", true)),
	}
	# le corps, enduit, le dos un peu plus sombre
	o.boite(Transform3D(Basis(), Vector3(0, H * 0.5, -d * 0.5)), Vector3(w, H, d), [enduit.darkened(0.06), enduit.darkened(0.06), enduit, enduit, enduit, enduit.darkened(0.1)], Outils.DUR, true)
	# le soubassement, enterré de 30 cm pour asseoir l'immeuble sur un sol inégal
	o.boite(Transform3D(Basis(), Vector3(0, -0.15, -d * 0.5)), Vector3(w, 0.32, d), PIERRE_SOMBRE)
	var porte := _facade(o, Transform3D(), w, niveaux, rdc, type, style, n)
	if type == "angle":
		# la seconde façade, tournée vers +X ; un pan coupé ferme l'angle
		var b := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0))
		_facade(o, Transform3D(b, Vector3(w * 0.5, 0, -d * 0.5)), d, niveaux, "boutique", "angle", style, n)
		o.boite(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(w * 0.5 - 0.35, H * 0.5, -0.35)), Vector3(1.4, H, 0.3), PIERRE)
	if opt.get("vigne", r.randf() < 0.3):
		_vigne(o, w, H, r)
	var faite := H
	if toit == "mansarde":
		faite = _mansarde(o, w, d, H, r)
	else:
		faite = _quatre_pans(o, w, d, H, r, _tuile(opt), float(opt.get("pente", 24.0)), int(opt.get("chassis", 0)), clampf(float(opt.get("grain", 0.0)), 0.0, 2.0))
	# les souches de cheminée, massives, enduites, sur le versant arrière ; les grosses souches des immeubles
	# lyonnais montent plus haut et portent quatre mitrons de terre cuite
	var grosses := str(opt.get("souches", "")) == "grosses"
	var sw := 1.6 if grosses else 1.1
	var sh := 4.0 if grosses else 3.0
	var sd := 0.95 if grosses else 0.6
	var nm := 4 if grosses else 3
	var nc := 2 + (1 if w > 10.0 else 0)
	for i in nc:
		var x := lerpf(-w * 0.4, w * 0.4, float(i) / maxf(1, nc - 1)) + r.randf_range(-0.4, 0.4)
		var z := -d * r.randf_range(0.45, 0.7)
		var y := H + (faite - H) * 0.5
		o.boite(Transform3D(Basis(), Vector3(x, y + sh * 0.5 - 0.5, z)), Vector3(sw, sh, sd), enduit.lightened(0.05))
		o.boite(Transform3D(Basis(), Vector3(x, y + sh - 0.45, z)), Vector3(sw + 0.15, 0.16, sd + 0.15), PIERRE_SOMBRE)
		if grosses:
			o.boite(Transform3D(Basis(), Vector3(x, y + sh - 0.75, z)), Vector3(sw + 0.08, 0.1, sd + 0.08), PIERRE)
		for k in nm:
			var xm := x - (nm - 1) * 0.5 * (sw / nm) + k * (sw / nm)
			if grosses:
				o.cylindre(Transform3D(Basis(), Vector3(xm, y + sh - 0.37, z)), 0.15, 0.12, 0.5, 8, Color("b86a45"))
				o.cylindre(Transform3D(Basis(), Vector3(xm, y + sh + 0.13, z)), 0.13, 0.14, 0.06, 8, Color("a85c3a"))
			else:
				o.cylindre(Transform3D(Basis(), Vector3(xm, y + sh - 0.37, z)), 0.09, 0.08, 0.32, 6, Color("b86a45"))
	o.construire(n, "Corps")
	n.set_meta("type", type)
	n.set_meta("graine", graine)
	n.set_meta("w", w)
	n.set_meta("d", d)
	n.set_meta("hauteur", faite)
	n.set_meta("porte", porte)
	return n


## Les deux teintes des tuiles : le pan et les rangs, l'option tuile (un hexa) ou le rouge orangé lyonnais.
static func _tuile(opt: Dictionary) -> Array:
	if opt.has("tuile"):
		var t := Color(str(opt["tuile"]))
		return [t, t.darkened(0.15)]
	return TOITS.tuile.map(func(h): return Color(h))


static func _persiennes(opt: Dictionary, r: RandomNumberGenerator) -> Color:
	var v = opt.get("persiennes", r.randf() < 0.55)
	if v is String:
		return Color(v)
	if v:
		return Color(PERSIENNES[r.randi() % PERSIENNES.size()])
	return Color(0, 0, 0, 0)


## Une façade de largeur w dans le repère t (x en travers, y vers le haut, z vers la rue) : le rez-de-chaussée,
## les bandeaux, les chaînes d'angle, les étages et leurs fenêtres, la corniche. Rend le seuil de la porte.
static func _facade(o: Outils, t: Transform3D, w: float, niveaux: int, rdc: String, type: String, s: Dictionary, n: Node3D) -> Vector3:
	var r := o.rng
	var H := RDC + niveaux * ETAGE
	var enduit: Color = s.enduit
	# le soubassement et le rez-de-chaussée de pierre de taille, à refends
	o.boite(t * Transform3D(Basis(), Vector3(0, RDC * 0.5, 0.06)), Vector3(w + 0.02, RDC, 0.12), PIERRE)
	var y := 0.55
	while y < RDC - 0.3:
		o.boite(t * Transform3D(Basis(), Vector3(0, y, 0.125)), Vector3(w + 0.02, 0.04, 0.02), PIERRE_SOMBRE)
		y += 0.55
	o.boite(t * Transform3D(Basis(), Vector3(0, 0.25, 0.14)), Vector3(w + 0.04, 0.5, 0.2), PIERRE_SOMBRE)
	var porte := Vector3(0, 0, 0.3)
	match rdc:
		"arcades":
			porte = _arcades(o, t, w, s, false)
		"passage":
			porte = _arcades(o, t, w, s, true)
		"cafe":
			porte = _devanture(o, t, w, s, true, n)
		"boutique":
			porte = _devanture(o, t, w, s, false, n)
		_:
			porte = _logis(o, t, w, s, rdc == "pierre")
	# le bandeau du premier étage, saillant, et la corniche à denticules
	o.boite(t * Transform3D(Basis(), Vector3(0, RDC + 0.05, 0.18)), Vector3(w + 0.08, 0.26, 0.36), PIERRE)
	o.boite(t * Transform3D(Basis(), Vector3(0, RDC - 0.15, 0.12)), Vector3(w + 0.04, 0.12, 0.24), PIERRE_SOMBRE)
	for i in range(1, niveaux):
		o.boite(t * Transform3D(Basis(), Vector3(0, RDC + i * ETAGE - 0.05, 0.08)), Vector3(w + 0.02, 0.14, 0.16), PIERRE.lightened(0.04))
	o.boite(t * Transform3D(Basis(), Vector3(0, H - 0.3, 0.1)), Vector3(w + 0.06, 0.16, 0.2), PIERRE)
	o.boite(t * Transform3D(Basis(), Vector3(0, H - 0.08, 0.24)), Vector3(w + 0.22, 0.24, 0.48), PIERRE)
	var dents := int(w / 0.32)
	for i in dents:
		o.boite(t * Transform3D(Basis(), Vector3(-w * 0.5 + (i + 0.5) * w / dents, H - 0.3, 0.24)), Vector3(0.14, 0.14, 0.16), PIERRE_SOMBRE)
	# les chaînes d'angle, en pierre, harpées
	if s.chaines:
		for cote in [-1.0, 1.0]:
			var yy := RDC + 0.2
			var k := 0
			while yy < H - 0.5:
				var large := 0.7 if k % 2 == 0 else 0.45
				o.boite(t * Transform3D(Basis(), Vector3(cote * (w * 0.5 - large * 0.5 + 0.02), yy + 0.21, 0.07)), Vector3(large, 0.38, 0.14), PIERRE)
				yy += 0.44
				k += 1
	# les travées : des fenêtres hautes à encadrement de pierre, garde-corps de fonte, persiennes
	var nf := clampi(int(round((w - 1.2) / 2.1)), 1, 6)
	var pas := (w - 1.4) / nf
	for e in niveaux:
		var y0 := RDC + e * ETAGE + 0.55
		var haute := 2.1 if e < 2 else (1.9 if e < niveaux - 1 else 1.7)
		var filant: bool = s.balcons and (e == 1 or (e == niveaux - 1 and niveaux >= 4)) and nf >= 2
		if filant:
			_balcon_filant(o, t, Vector3(0, y0, 0), w - 0.9, s)
		for i in nf:
			var x := -w * 0.5 + 0.7 + pas * (i + 0.5)
			_fenetre(o, t, Vector3(x, y0, 0), 1.0, haute, s, not filant, e == 0 and type in ["bourgeois", "hotel"])
	return t * porte


## Une fenêtre lyonnaise : haute, en retrait dans un encadrement de pierre, l'appui saillant, le garde-corps de
## fonte au tiers de la hauteur, les persiennes ouvertes contre le mur.
static func _fenetre(o: Outils, t: Transform3D, p: Vector3, l: float, h: float, s: Dictionary, garde_corps: bool, fronton: bool) -> void:
	var pts := _baie(l, h, "cintree" if s.cintre else "droite")
	var tf := t * Transform3D(Basis(), p)
	o.profil(tf, pts, -0.02, 0.02, VERRE)
	_cadre(o, tf, pts, 0.16, 0.0, 0.22, PIERRE, PIERRE.darkened(0.12))
	o.boite(tf * Transform3D(Basis(), Vector3(0, h * 0.5, 0.05)), Vector3(0.06, h, 0.05), Color("f2ede2"))
	for k in 2:
		o.boite(tf * Transform3D(Basis(), Vector3(0, h * (0.36 + k * 0.32), 0.05)), Vector3(l, 0.05, 0.05), Color("f2ede2"))
	o.boite(tf * Transform3D(Basis(), Vector3(0, -0.08, 0.18)), Vector3(l + 0.44, 0.12, 0.36), PIERRE_SOMBRE.lightened(0.1))
	if s.cintre:
		o.boite(tf * Transform3D(Basis(), Vector3(0, h + 0.05, 0.18)), Vector3(0.26, 0.36, 0.14), PIERRE_SOMBRE.lightened(0.05))
	if fronton:
		o.boite(tf * Transform3D(Basis(), Vector3(0, h + 0.32, 0.2)), Vector3(l + 0.7, 0.16, 0.4), PIERRE)
		for cote in [-1.0, 1.0]:
			o.boite(tf * Transform3D(Basis(), Vector3(cote * (l * 0.5 + 0.22), h + 0.12, 0.16)), Vector3(0.14, 0.26, 0.3), PIERRE_SOMBRE)
	if garde_corps:
		# le garde-corps de fonte : main courante, lisse basse, barreaux et un motif en losange au milieu
		var z := 0.3
		o.boite(tf * Transform3D(Basis(), Vector3(0, 0.92, z)), Vector3(l + 0.1, 0.05, 0.05), FER)
		o.boite(tf * Transform3D(Basis(), Vector3(0, 0.1, z)), Vector3(l + 0.1, 0.04, 0.04), FER)
		var nb := 9
		for i in nb:
			o.boite(tf * Transform3D(Basis(), Vector3(-l * 0.5 + (i + 0.5) * l / nb, 0.5, z)), Vector3(0.022, 0.8, 0.022), FER)
		o.boite(tf * Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0, 0.5, z + 0.01)), Vector3(0.36, 0.36, 0.02), FER)
		if s.fleurs and o.rng.randf() < 0.35:
			for i in 3:
				var q := Vector3(-l * 0.3 + i * l * 0.3, 0.95, z + 0.05)
				o.boule(tf * q, Vector3(0.2, 0.14, 0.13), VERT, 0.25, Outils.FEUILLE, 0.06, 0.2)
				o.boule(tf * (q + Vector3(0, 0.07, 0.06)), Vector3(0.13, 0.08, 0.09), s.fleur, 0.3, Outils.FEUILLE, 0.08, 0.2)
	var per: Color = s.persiennes
	if per.a > 0.0:
		# les persiennes repliées contre le mur, à lames
		for cote in [-1.0, 1.0]:
			var x: float = cote * (l * 0.5 + 0.16 + 0.27)
			o.boite(tf * Transform3D(Basis(), Vector3(x, h * 0.5, 0.05)), Vector3(0.52, h, 0.05), per)
			for k in int(h / 0.16):
				o.boite(tf * Transform3D(Basis(), Vector3(x, 0.1 + k * 0.16, 0.08)), Vector3(0.46, 0.03, 0.02), per.darkened(0.15))


## Un balcon filant sur toute la largeur : la dalle de pierre sur ses consoles et la rampe de fonte.
static func _balcon_filant(o: Outils, t: Transform3D, p: Vector3, l: float, s: Dictionary) -> void:
	var tf := t * Transform3D(Basis(), p)
	o.boite(tf * Transform3D(Basis(), Vector3(0, -0.12, 0.38)), Vector3(l, 0.16, 0.76), PIERRE)
	var nc := int(l / 1.6) + 1
	for i in nc:
		var x := -l * 0.5 + 0.2 + i * (l - 0.4) / maxf(1, nc - 1)
		o.profil(tf * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(x, -0.2, 0)), PackedVector2Array([Vector2(0, 0), Vector2(0.66, 0), Vector2(0, -0.55)]), -0.08, 0.08, PIERRE_SOMBRE)
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0.95, 0.74)), Vector3(l, 0.06, 0.06), FER)
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0.08, 0.74)), Vector3(l, 0.04, 0.04), FER)
	var nb := int(l / 0.13)
	for i in nb + 1:
		o.boite(tf * Transform3D(Basis(), Vector3(-l * 0.5 + i * l / nb, 0.5, 0.74)), Vector3(0.022, 0.86, 0.022), FER)
	for cote in [-1.0, 1.0]:
		o.boite(tf * Transform3D(Basis(), Vector3(cote * l * 0.5, 0.5, 0.38)), Vector3(0.04, 0.9, 0.72), FER)
	if s.fleurs:
		var nf := int(l / 1.1)
		for i in nf:
			if o.rng.randf() < 0.55:
				var q := Vector3(-l * 0.5 + (i + 0.5) * l / nf, 1.0, 0.7)
				o.boule(tf * q, Vector3(0.26, 0.17, 0.15), VERT, 0.25, Outils.FEUILLE, 0.06, 0.2)
				o.boule(tf * (q + Vector3(0, 0.08, 0.07)), Vector3(0.17, 0.1, 0.1), s.fleur.lightened(o.rng.randf_range(-0.1, 0.1)), 0.3, Outils.FEUILLE, 0.08, 0.2)
				o.boule(tf * (q + Vector3(0.1, -0.35, 0.04)), Vector3(0.1, 0.32, 0.08), VERT.darkened(0.08), 0.3, Outils.FEUILLE, 0.05, 0.3)


## Le rez-de-chaussée en arcades : des arcs en plein cintre sur piliers, boutiques vitrées dans le fond ; avec
## traboule, l'arc du milieu est un passage voûté sombre, plus haut, sous son mascaron.
static func _arcades(o: Outils, t: Transform3D, w: float, s: Dictionary, traboule: bool) -> Vector3:
	var n := clampi(int(round(w / 2.9)), 2, 5)
	if traboule and n % 2 == 0:
		n += 1
	var pas := w / n
	var l := pas - 0.7
	for i in n:
		var x := -w * 0.5 + pas * (i + 0.5)
		var milieu := traboule and i == n / 2
		var h := 3.6 if milieu else 3.3
		var pts := _baie(l, h, "plein_cintre")
		var tf := t * Transform3D(Basis(), Vector3(x, 0.0, 0.12))
		o.profil(tf, pts, -0.02, 0.02, SOMBRE if milieu else s.bois)
		if not milieu:
			# la vitrine dans le fond de l'arc, et sa porte
			o.profil(tf * Transform3D(Basis(), Vector3(0, 0.5, 0.0)), _baie(l - 0.3, h - 0.65, "plein_cintre"), 0.02, 0.04, VERRE.lightened(0.12))
			o.boite(tf * Transform3D(Basis(), Vector3(0, 0.25, 0.03)), Vector3(l - 0.1, 0.5, 0.04), s.bois.darkened(0.15))
		_cadre(o, tf, pts, 0.32, 0.0, 0.3, PIERRE, PIERRE.darkened(0.14))
		o.boite(tf * Transform3D(Basis(), Vector3(0, h + 0.1, 0.24)), Vector3(0.36, 0.44, 0.16), PIERRE_SOMBRE)
	# les piliers, entre les arcs, saillants
	for i in n + 1:
		var x := -w * 0.5 + pas * i
		o.boite(t * Transform3D(Basis(), Vector3(clampf(x, -w * 0.5 + 0.2, w * 0.5 - 0.2), 1.6, 0.24)), Vector3(0.42, 3.2, 0.26), PIERRE.lightened(0.03))
	return Vector3(0, 0, 0.5)


## La devanture : une boutique en applique, bois peint, vitrine et porte, l'enseigne, le store ; celle du café
## a son store rouge en avancée et ses lettres.
static func _devanture(o: Outils, t: Transform3D, w: float, s: Dictionary, cafe: bool, n: Node3D) -> Vector3:
	var r := o.rng
	var bois: Color = Color("6e1f22") if cafe else s.bois
	var l := w - 1.2
	var tf := t
	o.boite(tf * Transform3D(Basis(), Vector3(0, 1.85, 0.16)), Vector3(l + 0.3, 3.4, 0.14), bois)
	for cote in [-1.0, 1.0]:
		o.boite(tf * Transform3D(Basis(), Vector3(cote * (l * 0.5 + 0.08), 1.95, 0.28)), Vector3(0.34, 3.9, 0.26), bois.darkened(0.12))
	o.boite(tf * Transform3D(Basis(), Vector3(0, 3.95, 0.34)), Vector3(l + 0.7, 0.18, 0.46), bois.darkened(0.25))
	var baies := int(l / 1.9)
	var lb := l / baies
	var x_porte := -l * 0.5 + lb * (baies / 2 + 0.5)
	for i in baies:
		var x := -l * 0.5 + lb * (i + 0.5)
		if absf(x - x_porte) < 0.01:
			o.boite(tf * Transform3D(Basis(), Vector3(x, 1.3, 0.24)), Vector3(1.15, 2.5, 0.03), bois.darkened(0.2))
			o.boite(tf * Transform3D(Basis(), Vector3(x, 1.55, 0.26)), Vector3(0.8, 1.6, 0.02), VERRE.lightened(0.15))
		else:
			o.boite(tf * Transform3D(Basis(), Vector3(x, 1.95, 0.24)), Vector3(lb - 0.25, 2.0, 0.03), VERRE.lightened(0.15))
			o.boite(tf * Transform3D(Basis(), Vector3(x, 0.45, 0.26)), Vector3(lb - 0.2, 0.7, 0.05), bois.darkened(0.15))
			for k in 3:
				o.boite(tf * Transform3D(Basis(), Vector3(x - (lb - 0.25) * 0.5 + (k + 1) * (lb - 0.25) / 4.0, 1.95, 0.27)), Vector3(0.04, 2.0, 0.03), bois.darkened(0.2))
	# l'enseigne : un bandeau clair, ses lettres
	o.boite(tf * Transform3D(Basis(), Vector3(0, 3.42, 0.26)), Vector3(l - 0.3, 0.55, 0.06), Color("efe4c8") if not cafe else bois)
	var texte: String = s.enseigne
	if texte == "" and cafe:
		texte = "CAFÉ DES CANUTS"
	if texte != "":
		var lab := Label3D.new()
		lab.text = texte
		lab.font_size = 72
		lab.pixel_size = 0.0065
		lab.modulate = Color("f3e6c0") if cafe else bois
		lab.outline_size = 0
		lab.transform = t * Transform3D(Basis(), Vector3(0, 3.42, 0.3))
		n.add_child(lab)
	# un store banne par travée de vitrine, au-dessus de l'enseigne basse
	var toile: Array = [Color("b8322c"), Color("b8322c")] if cafe and not s.toile_choisie else (s.toile as Array).map(func(h): return Color(str(h)))
	var avancee := float(s.avancee) if float(s.avancee) > 0.0 else (2.0 if cafe else 1.3)
	for i in (baies if s.store else 0):
		var x := -l * 0.5 + lb * (i + 0.5)
		_store(o, tf * Transform3D(Basis(), Vector3(x, 3.0, 0.3)), lb - 0.12, avancee, toile, texte if cafe and i == baies / 2 else "", n)
	if cafe:
		# les plantes en bac de part et d'autre de la porte
		for cote in [-1.0, 1.0]:
			var q := Vector3(x_porte + cote * 1.0, 0, 0.6)
			o.boite(tf * Transform3D(Basis(), q + Vector3(0, 0.3, 0)), Vector3(0.5, 0.6, 0.5), Color("8a5a3a"))
			o.boule(tf * (q + Vector3(0, 0.95, 0)), Vector3(0.36, 0.45, 0.36), VERT, 0.15, Outils.FEUILLE, 0.06, 0.3)
	return Vector3(x_porte, 0, 0.6)


## Un store banne dans le repère t (son coffre à l'origine, contre le mur, z vers la rue), large de l, avancé de
## av : la toile tendue qui fléchit un peu entre le coffre et la barre de charge, ses rayures qui suivent la courbe,
## le dessous plus sombre, les joues triangulaires, les bras articulés de fer noir, le lambrequin festonné qui pend
## librement et, sur celui du café, l'enseigne peinte.
static func _store(o: Outils, t: Transform3D, l: float, av: float, toile: Array, texte: String, n: Node3D) -> void:
	var raye: bool = (toile[0] as Color) != (toile[1] as Color)
	var chute := av * 0.42
	var pas := 10
	var courbe := PackedVector2Array()
	for k in pas + 1:
		var u := float(k) / pas
		courbe.append(Vector2(u * av, -u * chute - sin(PI * u) * 0.05 * av))
	var bandes := maxi(2, int(round(l / 0.3)))
	var lbd := l / bandes
	for i in bandes:
		var c: Color = toile[i % 2] if raye else (toile[0] as Color).lightened(0.04 * float(i % 2))
		var x0 := -l * 0.5 + i * lbd
		for k in pas:
			var a := courbe[k]
			var b := courbe[k + 1]
			var p0 := t * Vector3(x0, a.y, a.x)
			var p1 := t * Vector3(x0 + lbd, a.y, a.x)
			var p2 := t * Vector3(x0 + lbd, b.y, b.x)
			var p3 := t * Vector3(x0, b.y, b.x)
			var e := b - a
			var nrm := t.basis * Vector3(0, e.x, -e.y).normalized()
			o.quad(p0, p1, p2, p3, nrm, c)
			o.quad(p0 + nrm * -0.012, p1 + nrm * -0.012, p2 + nrm * -0.012, p3 + nrm * -0.012, -nrm, c.darkened(0.38))
	var bout := courbe[pas]
	# les joues : le triangle de toile sous la courbe, de chaque côté
	var joue := PackedVector2Array(courbe)
	joue.append(Vector2(0.0, bout.y))
	var cote := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	for sx in [-1.0, 1.0]:
		o.profil(t * Transform3D(cote, Vector3(sx * l * 0.5, 0, 0)), joue, -0.006, 0.006, [toile[0], (toile[0] as Color).darkened(0.2)])
	# le coffre, la barre de charge
	o.boite(t * Transform3D(Basis(), Vector3(0, 0.06, 0.02)), Vector3(l + 0.08, 0.2, 0.2), (toile[0] as Color).darkened(0.45))
	o.boite(t * Transform3D(Basis(), Vector3(0, bout.y - 0.02, bout.x)), Vector3(l + 0.04, 0.07, 0.07), FER)
	# les bras articulés, repliés en V sous la toile : de la console du mur au coude, du coude à la barre
	for sx in [-1.0, 1.0]:
		var x: float = sx * (l * 0.5 - 0.18)
		var pied := t * Vector3(x, -0.42, 0.04)
		var barre := t * Vector3(x, bout.y - 0.03, bout.x)
		var coude := t * Vector3(x - sx * 0.25, lerpf(-0.42, bout.y, 0.5) - 0.12, bout.x * 0.48)
		o.boite(t * Transform3D(Basis(), Vector3(x, -0.42, 0.03)), Vector3(0.1, 0.16, 0.06), FER)
		o.branche(pied, coude, 0.022, 0.02, FER, 5)
		o.branche(coude, barre, 0.02, 0.018, FER, 5)
		o.boule(coude, Vector3.ONE * 0.035, FER, 0.0, Outils.DUR, 0.0)
	# le lambrequin festonné, qui pend de la barre ; un lisere clair au-dessus des festons
	var haut := 0.2
	var feston := 0.26
	var nf := maxi(2, int(round(l / feston)))
	var lf := l / nf
	var lam := PackedVector2Array([Vector2(l * 0.5, 0.0), Vector2(-l * 0.5, 0.0)])
	for j in nf:
		var cx := -l * 0.5 + lf * (j + 0.5)
		lam.append_array(Outils.arc(Vector2(cx, -haut), lf * 0.5, PI, TAU, 6))
	var tl := t * Transform3D(Basis(), Vector3(0, bout.y - 0.05, bout.x + 0.045))
	o.profil(tl, lam, -0.008, 0.008, [toile[0], (toile[0] as Color).darkened(0.25)])
	var lisere := Color("f2ead6") if (toile[0] as Color).get_luminance() < 0.6 else (toile[0] as Color).darkened(0.45)
	o.boite(tl * Transform3D(Basis(), Vector3(0, -haut + 0.025, 0.012)), Vector3(l, 0.025, 0.006), lisere)
	if raye:
		for j in nf:
			if j % 2 == 1:
				var cx := -l * 0.5 + lf * (j + 0.5)
				o.profil(tl * Transform3D(Basis(), Vector3(0, 0, 0.011)), Outils.arc(Vector2(cx, -haut), lf * 0.5, PI, TAU, 6), -0.002, 0.002, toile[1])
	if texte != "":
		var lab := Label3D.new()
		lab.text = texte
		lab.font_size = 72
		lab.pixel_size = minf(0.0042, (l - 0.3) / (maxf(texte.length(), 1.0) * 72.0 * 0.6))
		lab.modulate = lisere
		lab.outline_size = 0
		lab.transform = tl * Transform3D(Basis(), Vector3(0, -haut * 0.42, 0.014))
		n.add_child(lab)


## Un rez-de-chaussée d'habitation : la porte d'entrée à imposte, ses fenêtres grillagées ; en pierre, des
## baies en plein cintre et des refends plus marqués.
static func _logis(o: Outils, t: Transform3D, w: float, s: Dictionary, pierre: bool) -> Vector3:
	var r := o.rng
	var x_porte := 0.0 if w < 6.0 else (w * 0.5 - 1.6) * (1.0 if r.randf() < 0.5 else -1.0)
	if pierre:
		x_porte = 0.0
	var forme := "plein_cintre" if pierre or s.cintre else "droite"
	var pts := _baie(1.4, 3.0, forme)
	var tp := t * Transform3D(Basis(), Vector3(x_porte, 0.12, 0.12))
	o.profil(tp, pts, -0.02, 0.02, s.bois)
	o.profil(tp * Transform3D(Basis(), Vector3(0, 2.25, 0)), _baie(1.2, 0.7, forme), 0.02, 0.04, VERRE)
	_cadre(o, tp, pts, 0.24, 0.0, 0.32, PIERRE, PIERRE.darkened(0.14))
	o.boite(tp * Transform3D(Basis(), Vector3(0, 2.2, 0.05)), Vector3(1.4, 0.08, 0.06), s.bois.darkened(0.2))
	o.boite(tp * Transform3D(Basis(), Vector3(0.45, 1.15, 0.06)), Vector3(0.07, 0.07, 0.06), Color("c9a64a"))
	o.boite(t * Transform3D(Basis(), Vector3(x_porte, 0.08, 0.5)), Vector3(2.0, 0.16, 0.6), PIERRE_SOMBRE)
	var xs := []
	var x := x_porte - 2.2
	while x > -w * 0.5 + 0.8:
		xs.append(x)
		x -= 2.1
	x = x_porte + 2.2
	while x < w * 0.5 - 0.8:
		xs.append(x)
		x += 2.1
	for xf in xs:
		var tf := t * Transform3D(Basis(), Vector3(xf, 1.0, 0.12))
		var pf := _baie(1.0, 2.2, forme)
		o.profil(tf, pf, -0.02, 0.02, VERRE)
		_cadre(o, tf, pf, 0.16, 0.0, 0.24, PIERRE, PIERRE.darkened(0.12))
		# la grille de défense
		for k in 5:
			o.boite(tf * Transform3D(Basis(), Vector3(-0.4 + k * 0.2, 1.0, 0.1)), Vector3(0.025, 2.0, 0.025), FER)
		o.boite(tf * Transform3D(Basis(), Vector3(0, -0.08, 0.18)), Vector3(1.4, 0.12, 0.36), PIERRE_SOMBRE.lightened(0.1))
	return Vector3(x_porte, 0, 0.8)


## La vigne qui grimpe d'un pied de façade jusqu'au premier ou au deuxième étage, et file sous un bandeau.
static func _vigne(o: Outils, w: float, H: float, r: RandomNumberGenerator) -> void:
	var cote := -1.0 if r.randf() < 0.5 else 1.0
	var x0 := cote * (w * 0.5 - 0.5)
	var haut := minf(H - 1.0, RDC + ETAGE * r.randf_range(0.8, 1.8))
	var y := 0.3
	while y < haut:
		var s := r.randf_range(0.3, 0.48)
		o.boule(Vector3(x0 + r.randf_range(-0.25, 0.25), y, 0.35), Vector3(s, s, 0.22), VERT.lightened(r.randf_range(-0.05, 0.15)), 0.25, Outils.FEUILLE, 0.08, 0.2)
		if r.randf() < 0.3:
			o.boule(Vector3(x0 + r.randf_range(-0.3, 0.3), y, 0.5), Vector3(0.12, 0.12, 0.1), Color("d04a8a"), 0.2, Outils.FEUILLE, 0.08, 0.2)
		y += r.randf_range(0.3, 0.5)
	var x := x0
	for i in int(w * 0.35):
		x -= cote * r.randf_range(0.35, 0.6)
		if absf(x) > w * 0.5 - 0.4:
			break
		o.boule(Vector3(x, haut - r.randf_range(0.0, 0.5), 0.35), Vector3(0.42, 0.3, 0.2), VERT.lightened(0.08), 0.25, Outils.FEUILLE, 0.08, 0.2)


## Le toit lyonnais à quatre pans, en tuile canal, peu pentu (24° ou degres), sur sa génoise, et ses châssis de
## toit côté rue ; rend le faîte.
static func _quatre_pans(o: Outils, w: float, d: float, H: float, r: RandomNumberGenerator, tuile: Array, degres := 24.0, chassis := 0, grain := 0.0) -> float:
	var e := 0.55
	var pente := deg_to_rad(clampf(degres, 15.0, 45.0))
	var x0 := -w * 0.5 - e
	var x1 := w * 0.5 + e
	var z0 := e
	var z1 := -d - e
	var demi := minf(x1 - x0, z0 - z1) * 0.5
	var hr := demi * tan(pente)
	var y0 := H + 0.25
	var sommet := y0 + hr
	var cz := (z0 + z1) * 0.5
	var cx := 0.0
	var a: Vector3
	var b: Vector3
	if x1 - x0 >= z0 - z1:
		a = Vector3(x0 + demi, sommet, cz)
		b = Vector3(x1 - demi, sommet, cz)
	else:
		a = Vector3(cx, sommet, z0 - demi)
		b = Vector3(cx, sommet, z1 + demi)
	var c00 := Vector3(x0, y0, z0)
	var c10 := Vector3(x1, y0, z0)
	var c11 := Vector3(x1, y0, z1)
	var c01 := Vector3(x0, y0, z1)
	# les quatre pans : devant, derrière, et les deux croupes
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
			o.quad(pan[0], pan[1], pan[2], pan[3], nrm, tuile[0])
			o.quad(pan[0] - Vector3(0, 0.12, 0), pan[1] - Vector3(0, 0.12, 0), pan[2] - Vector3(0, 0.12, 0), pan[3] - Vector3(0, 0.12, 0), -nrm, Color("8a5a3a"))
		else:
			o.tri(pan[0], pan[1], pan[2], nrm, tuile[0])
			o.tri(pan[0] - Vector3(0, 0.12, 0), pan[1] - Vector3(0, 0.12, 0), pan[2] - Vector3(0, 0.12, 0), -nrm, Color("8a5a3a"))
		# les rangs de tuiles canal, parallèles à l'égout
		var bas: Vector3 = (pan[0] + pan[1]) * 0.5
		var haut: Vector3 = pan[2] if pan.size() == 3 else (pan[2] + pan[3]) * 0.5
		var long: float = (pan[1] - pan[0]).length()
		var dir: Vector3 = (pan[1] - pan[0]).normalized()
		var monte: Vector3 = haut - bas
		var rangs := int(monte.length() / 0.45)
		for k in rangs:
			var f := (k + 0.5) / rangs
			var lk: float = long * (1.0 - f) if pan.size() == 3 else lerpf(long, (pan[2] - pan[3]).length(), f)
			var centre: Vector3 = bas + monte * f + nrm.normalized() * 0.03
			var bb := Basis(dir, nrm.normalized(), dir.cross(nrm.normalized()))
			o.boite(Transform3D(bb.orthonormalized(), centre), Vector3(lk, 0.05, 0.08), tuile[1])
		if grain > 0.0:
			_grain(o, r, bas, monte, dir, long, 0.0 if pan.size() == 3 else (pan[2] - pan[3]).length(), nrm.normalized(), rangs, tuile[0], grain)
	# les châssis de toit, posés dans le pan côté rue : un cadre clair, la vitre, le rejingot qui la protège
	if chassis > 0:
		var avant: Array = pans[0]
		var nf: Vector3 = (avant[1] - avant[0]).cross(avant[2] - avant[0]).normalized()
		if nf.y < 0.0:
			nf = -nf
		var monte_f: Vector3 = ((avant[2] if avant.size() == 3 else (avant[2] + avant[3]) * 0.5) - (avant[0] + avant[1]) * 0.5)
		var f := 0.38
		var largeur := (x1 - x0) * 0.5 * (1.0 - f if avant.size() == 3 or x1 - x0 < z0 - z1 else 1.0) - 0.9
		var bc := Basis(Vector3.RIGHT, nf, Vector3.RIGHT.cross(nf)).orthonormalized()
		var nb := clampi(chassis, 1, 3)
		for i in nb:
			var x := 0.0 if nb == 1 else lerpf(-largeur, largeur, float(i) / (nb - 1)) * 0.7
			var c := Vector3(x, y0, z0) + monte_f * f + nf * 0.05
			o.boite(Transform3D(bc, c), Vector3(0.78, 0.07, 0.98), Color("ece4d2"))
			o.boite(Transform3D(bc, c + nf * 0.01), Vector3(0.6, 0.07, 0.78), VERRE.darkened(0.1))
			o.boite(Transform3D(bc, c + nf * 0.04 + bc.z * -0.5), Vector3(0.86, 0.05, 0.08), Color("8a8f94"))
	# l'arêtier et le faîtage
	if a.distance_to(b) > 0.01:
		o.branche(a, b, 0.1, 0.1, tuile[1], 6)
	for c in [c00, c10, c11, c01]:
		o.branche(c, a if c.distance_to(a) < c.distance_to(b) else b, 0.08, 0.08, tuile[1], 5)
	# la génoise : trois rangs de tuiles en encorbellement sous l'égout
	for k in 3:
		var ek := 0.1 + k * 0.15
		o.boite(Transform3D(Basis(), Vector3(0, H + 0.2 - k * 0.12, ek * 0.5)), Vector3(w + ek * 2.0, 0.08, ek), Color("e6dcc6").darkened(k * 0.05))
		o.boite(Transform3D(Basis(), Vector3(0, H + 0.2 - k * 0.12, -d - ek * 0.5)), Vector3(w + ek * 2.0, 0.08, ek), Color("e6dcc6").darkened(k * 0.05))
	return sommet


## Le grain d'un pan de tuiles, lisible de loin (verdict n° 32 de Sathonay : vus de 70 m, les pans étaient presque
## unis) : des plaques de tuiles plus neuves ou plus passées (± 32 % × grain, six tuiles sur cinq rangs environ, neuf
## dixièmes de la surface), puis un rang sur quatre assombri (la moitié × grain) ; des quads à plat sur le pan, dont
## la largeur suit celle du pan (long en bas, long_haut en haut : 0 sur une croupe triangulaire). Les 25 % et ± 15 %
## demandés ne faisaient passer l'écart-type que de 33 à 34 : le ton mappé écrase les écarts d'albédo.
static func _grain(o: Outils, r: RandomNumberGenerator, bas: Vector3, monte: Vector3, dir: Vector3, long: float, long_haut: float, nrm: Vector3, rangs: int, col: Color, grain: float) -> void:
	var pt := func(f: float, u: float, z: float) -> Vector3: return bas + monte * f + dir * (u * lerpf(long, long_haut, f)) + nrm * z
	var hr := 5.0 / maxf(rangs, 1)
	var n := int(monte.length() * (long + long_haut) * 0.5 / 2.7 * 0.9)
	for i in n:
		var f0 := r.randf_range(0.0, maxf(0.0, 1.0 - hr))
		var f1 := minf(1.0, f0 + hr)
		var lk := lerpf(long, long_haut, f1)
		if lk < 1.3:
			continue
		var u0 := r.randf_range(-0.5, 0.5 - 1.2 / lk)
		var u1 := u0 + 1.2 / lk
		var k := r.randf_range(-0.32, 0.32) * grain
		var c := col.darkened(-k) if k < 0.0 else col.lightened(k)
		o.quad(pt.call(f0, u0, 0.012), pt.call(f0, u1, 0.012), pt.call(f1, u1, 0.012), pt.call(f1, u0, 0.012), nrm, c)
	var sombre := col.darkened(0.5 * grain)
	for k in rangs:
		if k % 4 != 1:
			continue
		var f0 := float(k) / rangs
		var f1 := float(k + 1) / rangs
		o.quad(pt.call(f0, -0.5, 0.02), pt.call(f0, 0.5, 0.02), pt.call(f1, 0.5, 0.02), pt.call(f1, -0.5, 0.02), nrm, sombre)


## La mansarde d'ardoise de l'immeuble bourgeois : le brisis raide et ses lucarnes à fronton, le terrasson ;
## rend le faîte.
static func _mansarde(o: Outils, w: float, d: float, H: float, r: RandomNumberGenerator) -> float:
	var ardoise: Array = TOITS.ardoise.map(func(h): return Color(h))
	var hb := 3.0
	var recul := 1.0
	var ht := 1.4
	var pts := PackedVector2Array([Vector2(0.4, H + 0.15), Vector2(-recul, H + hb), Vector2(-d * 0.5, H + hb + ht),
		Vector2(-d + recul, H + hb), Vector2(-d - 0.4, H + 0.15)])
	var b := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	o.profil(Transform3D(b, Vector3.ZERO), pts, -w * 0.5 - 0.1, w * 0.5 + 0.1, [ardoise[1], ardoise[0]])
	var pente := atan2(hb, recul + 0.4)
	var bb := Basis(Vector3.RIGHT, -(PI * 0.5 - pente))
	for k in 6:
		var f := (k + 0.5) / 6.0
		o.boite(Transform3D(bb, Vector3(0, H + 0.15 + f * hb, 0.4 - f * (recul + 0.4) + 0.03)), Vector3(w + 0.2, 0.04, 0.04), ardoise[1])
	# le zinc du brisis
	o.boite(Transform3D(Basis(), Vector3(0, H + hb + 0.02, -recul)), Vector3(w + 0.25, 0.08, 0.14), Color("9aa0a3"))
	var n := clampi(int(round((w - 1.2) / 2.1)), 2, 6)
	var pas := (w - 1.4) / n
	for i in n:
		var x := -w * 0.5 + 0.7 + pas * (i + 0.5)
		var y := H + 0.6
		o.boite(Transform3D(Basis(), Vector3(x, y + 0.95, -0.55)), Vector3(1.3, 1.9, 1.1), PIERRE)
		var pf := _baie(0.8, 1.35, "cintree")
		var tf := Transform3D(Basis(), Vector3(x, y + 0.35, 0.0))
		o.profil(tf, pf, -0.02, 0.02, VERRE)
		_cadre(o, tf, pf, 0.14, 0.0, 0.18, PIERRE, PIERRE.darkened(0.12))
		o.profil(Transform3D(Basis(), Vector3(x, y + 1.9, 0.12)), PackedVector2Array([Vector2(-0.8, 0), Vector2(0.8, 0), Vector2(0, 0.55)]), -1.2, 0.0, [PIERRE.darkened(0.04), ardoise[0]])
	# la balustrade de pierre devant le brisis
	for i in int(w / 0.32):
		o.cylindre(Transform3D(Basis(), Vector3(-w * 0.5 + 0.18 + i * 0.32, H + 0.15, 0.35)), 0.07, 0.07, 0.5, 6, PIERRE)
	o.boite(Transform3D(Basis(), Vector3(0, H + 0.7, 0.35)), Vector3(w + 0.1, 0.12, 0.26), PIERRE)
	return H + hb + ht


## La chapelle : une nef de pierre dorée sous un toit de tuile, la façade à pignon, le portail en plein cintre et
## sa rose, le clocher carré à baies géminées sous sa flèche courte.
static func _chapelle(o: Outils, n: Node3D, graine: int, opt: Dictionary) -> Node3D:
	var r := o.rng
	var pierre := Color(str(ENDUITS.get(str(opt.get("enduit", "pierre_doree")), opt.get("enduit", "d6b27a"))))
	var w := float(opt.get("w", 9.0))
	var d := float(opt.get("d", 16.0))
	var H := 8.0
	var tuile := _tuile(opt)
	o.boite(Transform3D(Basis(), Vector3(0, H * 0.5, -d * 0.5)), Vector3(w, H, d), [pierre.darkened(0.06), pierre.darkened(0.06), pierre, pierre, pierre, pierre.darkened(0.1)], Outils.DUR, true)
	o.boite(Transform3D(Basis(), Vector3(0, -0.15, -d * 0.5)), Vector3(w, 0.32, d), PIERRE_SOMBRE)
	# le pignon de façade et le toit à deux pans
	var hg := w * 0.42
	var pignon := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), Vector2(0, hg)])
	o.profil(Transform3D(Basis(), Vector3(0, H, 0)), pignon, -0.4, 0.1, pierre)
	o.profil(Transform3D(Basis(), Vector3(0, H, 0)), Outils.grossir(pignon, 0.22), -0.3, 0.22, PIERRE)
	var pente := atan2(hg, w * 0.5)
	var long := sqrt(hg * hg + w * w * 0.25) + 0.5
	for cote in [-1.0, 1.0]:
		var b := Basis(Vector3.BACK, -cote * pente)
		o.boite(Transform3D(b, Vector3(cote * w * 0.25, H + hg * 0.5, -d * 0.5) + b * Vector3(0, 0.14, 0)), Vector3(long, 0.22, d + 0.4), tuile[0])
	# le portail : plein cintre à trois voussures, la porte de bois, l'emmarchement
	for k in 3:
		var pts := _baie(2.2 + k * 0.5, 4.2 + k * 0.25, "plein_cintre")
		o.profil(Transform3D(Basis(), Vector3(0, 0, 0.1 + (2 - k) * 0.12)), pts, 0.0, 0.12, PIERRE.darkened(k * 0.05))
	o.profil(Transform3D(Basis(), Vector3(0, 0, 0.44)), _baie(1.9, 3.9, "plein_cintre"), 0.0, 0.04, Color("5a3a28"))
	for k in 3:
		o.boite(Transform3D(Basis(), Vector3(0, 0.08 + k * 0.16, 1.2 - k * 0.3)), Vector3(4.6 - k * 0.6, 0.16, 0.6), PIERRE_SOMBRE)
	# la rose
	var rond := Outils.arc(Vector2.ZERO, 1.0, 0.0, TAU, 20)
	var tr := Transform3D(Basis(), Vector3(0, H + 0.4, 0.1))
	o.profil(tr, rond, -0.02, 0.02, VERRE)
	_cadre(o, tr, rond, 0.25, 0.0, 0.3, PIERRE, PIERRE.darkened(0.12))
	for k in 6:
		o.boite(tr * Transform3D(Basis(Vector3.BACK, PI * k / 6.0), Vector3(0, 0, 0.08)), Vector3(2.0, 0.07, 0.06), PIERRE)
	# les contreforts et les baies hautes de la nef
	for cote in [-1.0, 1.0]:
		for k in 4:
			var z := -2.0 - k * 4.0
			o.boite(Transform3D(Basis(), Vector3(cote * (w * 0.5 + 0.35), H * 0.45, z)), Vector3(0.7, H * 0.9, 0.9), PIERRE)
			if k < 3:
				var tf := Transform3D(Basis(Vector3.UP, cote * PI * 0.5), Vector3(cote * w * 0.5, 3.4, z - 2.0))
				var pf := _baie(1.0, 3.0, "plein_cintre")
				o.profil(tf, pf, -0.02, 0.02, VERRE)
				_cadre(o, tf, pf, 0.16, 0.0, 0.22, PIERRE, PIERRE.darkened(0.12))
	# le clocher, à droite de la façade
	var cx := w * 0.5 + 1.6
	var cz := -2.5
	var hc := 17.0
	o.boite(Transform3D(Basis(), Vector3(cx, hc * 0.5, cz)), Vector3(3.6, hc, 3.6), pierre, Outils.DUR, true)
	for k in 3:
		o.boite(Transform3D(Basis(), Vector3(cx, 6.0 + k * 4.0, cz)), Vector3(3.8, 0.2, 3.8), PIERRE)
	for i in 4:
		var bb := Basis(Vector3.UP, PI * 0.5 * i)
		for cote in [-1.0, 1.0]:
			var tf := Transform3D(bb, Vector3(cx, 0, cz) + bb * Vector3(cote * 0.55, 13.2, 1.8))
			var pf := _baie(0.7, 2.3, "plein_cintre")
			o.profil(tf, pf, -0.02, 0.02, SOMBRE)
			_cadre(o, tf, pf, 0.12, 0.0, 0.16, PIERRE, PIERRE.darkened(0.12))
	o.cylindre(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(cx, hc, cz)), 2.75, 0.0, 4.5, 4, tuile[0])
	o.cylindre(Transform3D(Basis(), Vector3(cx, hc + 4.5, cz)), 0.04, 0.04, 1.2, 4, FER)
	o.boite(Transform3D(Basis(), Vector3(cx, hc + 5.3, cz)), Vector3(0.6, 0.06, 0.06), FER)
	o.construire(n, "Corps")
	n.set_meta("type", "chapelle")
	n.set_meta("graine", graine)
	n.set_meta("w", w + 3.6)
	n.set_meta("d", d)
	n.set_meta("hauteur", hc + 5.5)
	n.set_meta("porte", Vector3(0, 0, 1.5))
	return n


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
