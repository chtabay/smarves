extends Node3D
## Un objet du matériel de course cycliste, posé tel quel : on règle objet, graine et options avant de l'ajouter à
## la scène, il se bâtit à son entrée dans l'arbre de scène. Le pied est à l'origine, sur un sol plat à y = 0 ; la
## route file le long de z (le sens de la course, vers +Z) et une arche, une banderole, une ligne la traversent le
## long de x ; en mètres.
##   var o = load(Bibliotheque.scene("course-cycliste@1", "decor")).instantiate()
##   o.objet = "arche" ; o.options = {"texte": "ARRIVÉE"}
##   add_child(o)
## Après la construction, le nœud porte ses métadonnées : objet, graine, emprise (la taille au sol, Vector2).
## La voiture suiveuse se prend à voitures-des-annees-80@1 (« suiveuse »), les arbres et le mobilier aux autres
## décors. Demandé par la carte de Belley, dans l'esprit des arrivées d'étape des années 1980.
const Outils := preload("res://bibliotheque/course-cycliste/1/outils.gd")

## Les objets : l'arche gonflable (d'arrivée ou de départ), la flamme rouge du dernier kilomètre, la banderole
## tendue au-dessus de la route, les fanions, la ligne d'arrivée peinte, les barrières de foule, le podium, l'estrade
## du speaker et ses haut-parleurs, le vélo de course, le râtelier de vélos et le panneau des kilomètres.
const OBJETS := ["arche", "flamme_rouge", "banderole", "fanions", "ligne", "barrieres", "podium", "estrade", "velo", "ratelier", "panneau_km"]

## Les couleurs des partenaires, des maillots et des cadres.
const COULEURS := ["d22a2a", "f2c600", "1f4fa0", "1f8a4c", "f4f1ea", "e86a1a"]
const FER := Color("9aa0a6")
const FER_SOMBRE := Color("3a3d40")
const BLANC := Color("f4f1ea")
const NOIR := Color("1e1e20")
const BOIS := Color("9a6a3e")
const PNEU := Color("26272a")

## L'objet (voir OBJETS).
@export var objet := "arche"
## La graine : les couleurs des partenaires, des cadres.
@export var graine := 1
## Les options, toutes facultatives : texte (l'arche, la banderole, le podium, le panneau : ARRIVÉE, DÉPART, 5 KM…),
## couleur (un hexa : l'arche, la banderole, le vélo), largeur (l'arche, la banderole, les fanions, la ligne : la
## largeur de la route, 10 m par défaut ; les barrières : leur longueur, 10 m), velos (le râtelier : 1 à 5).
@export var options := {}

var fait := false


func _ready() -> void:
	if fait:
		return
	fait = true
	var m := poser(self, Vector3.ZERO, objet, graine, options)
	for k in m:
		set_meta(k, m[k])


## Les objets, pour une commune qui les passe en revue.
static func objets() -> Array:
	return OBJETS.duplicate()


## Les mêmes, sous le nom commun aux autres briques.
static func noms() -> Array:
	return objets()


## Bâtit un objet sous parent, son pied en p (sans rotation : tourner le parent). Rend objet, graine, emprise.
static func poser(parent: Node3D, p: Vector3, nom: String, g: int, opt := {}) -> Dictionary:
	if not nom in OBJETS:
		nom = "arche"
	var o := Outils.new(g * 104729 + OBJETS.find(nom) * 41)
	var textes := []
	var emprise: Vector2 = Callable(_Objets, nom).call(o, p, opt, textes)
	var n := Node3D.new()
	n.name = nom.capitalize()
	parent.add_child(n)
	o.construire(n, nom.capitalize())
	# les inscriptions : [Transform3D, texte, couleur, taille d'un pixel]
	for t in textes:
		var l := Label3D.new()
		l.text = t[1]
		l.font_size = 96
		l.pixel_size = t[3]
		l.modulate = t[2]
		l.outline_size = 0
		l.double_sided = false
		l.transform = t[0]
		n.add_child(l)
	return {"objet": nom, "graine": g, "emprise": emprise}


class _Objets:
	static func _couleur(o: Outils, opt: Dictionary) -> Color:
		return Color(str(opt.get("couleur", COULEURS[o.rng.randi() % COULEURS.size()])))

	## Un tube gonflé le long des points pts, de rayon r, aux couleurs alternées ; des boules aux jointures.
	static func _boudin(o: Outils, pts: Array, r: float, cols: Array) -> void:
		for i in pts.size() - 1:
			var col: Color = cols[i % cols.size()]
			o.branche(pts[i], pts[i + 1], r, r, col, 12)
			o.boule(pts[i + 1], Vector3.ONE * r, col, 0.0, Outils.DUR, 0.0)
		o.boule(pts[0], Vector3.ONE * r, cols[0], 0.0, Outils.DUR, 0.0)

	## La taille d'un pixel de texte pour que texte tienne dans w × h (au plus taille).
	static func _ajuste(texte: String, w: float, h: float, taille: float) -> float:
		return minf(taille, minf(w * 0.88 / (maxf(texte.length(), 1.0) * 96.0 * 0.6), h * 0.62 / 96.0))

	## Un panneau plat de largeur w et de hauteur h centré en c, face vers +Z, et son texte des deux côtés, à sa taille.
	static func _panneau(o: Outils, c: Vector3, w: float, h: float, fond: Color, texte: String, encre: Color, textes: Array, taille := 0.016) -> void:
		o.boite(Transform3D(Basis(), c), Vector3(w, h, 0.06), fond)
		if texte != "":
			var t := _ajuste(texte, w, h, taille)
			textes.append([Transform3D(Basis(), c + Vector3(0, 0, 0.035)), texte, encre, t])
			textes.append([Transform3D(Basis(Vector3.UP, PI), c - Vector3(0, 0, 0.035)), texte, encre, t])

	static func arche(o: Outils, p: Vector3, opt: Dictionary, textes: Array) -> Vector2:
		var w := float(opt.get("largeur", 10.0))
		var col := _couleur(o, opt)
		var r := 0.55
		var pieds := 4.2
		# deux jambes droites, une voûte aplatie : le boudin gonflé fait d'une seule pièce
		var pts := []
		for k in 4:
			pts.append(p + Vector3(-w * 0.5, k * pieds / 3.0, 0))
		for k in range(1, 12):
			var t := PI - PI * k / 12.0
			pts.append(p + Vector3(cos(t) * w * 0.5, pieds + sin(t) * 1.6, 0))
		for k in 4:
			pts.append(p + Vector3(w * 0.5, pieds - k * pieds / 3.0, 0))
		_boudin(o, pts, r, [col, col, col.lightened(0.15)])
		# le bandeau sous la voûte, ses inscriptions ; les lests de sable aux pieds, à demi enterrés
		_panneau(o, p + Vector3(0, pieds + 0.25, 0), w * 0.62, 1.1, BLANC, str(opt.get("texte", "ARRIVÉE")), col.darkened(0.2), textes, 0.022)
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * w * 0.5, 0.05, 0)), Vector3(1.4, 0.4, 1.4), FER_SOMBRE, Outils.DUR, true)
			for k in 4:
				var a := TAU * k / 4.0 + 0.4
				o.boule(p + Vector3(cote * w * 0.5 + cos(a) * 0.9, 0.1, sin(a) * 0.9), Vector3(0.3, 0.15, 0.2), Color("c9b48a"), 0.15, Outils.DUR, 0.04)
			o.branche(p + Vector3(cote * w * 0.5, 4.0, 0), p + Vector3(cote * (w * 0.5 + 1.6), 0.0, 0), 0.01, 0.01, NOIR, 3)
		return Vector2(w + 3.0, 1.6)

	static func flamme_rouge(o: Outils, p: Vector3, opt: Dictionary, textes: Array) -> Vector2:
		var w := float(opt.get("largeur", 10.0))
		var h := 5.0
		for cote in [-1.0, 1.0]:
			o.cylindre(Transform3D(Basis(), p + Vector3(cote * w * 0.5, -0.4, 0)), 0.09, 0.08, h + 0.4, 8, FER, Outils.DUR)
			o.cylindre(Transform3D(Basis(), p + Vector3(cote * w * 0.5, 0, 0)), 0.35, 0.35, 0.12, 10, FER_SOMBRE)
			o.collisions.append([Transform3D(Basis(), p + Vector3(cote * w * 0.5, h * 0.5, 0)), Vector3(0.3, h, 0.3)])
		o.branche(p + Vector3(-w * 0.5, h, 0), p + Vector3(w * 0.5, h, 0), 0.06, 0.06, FER, 6)
		# la flamme : un grand triangle rouge pointe en bas, sous la traverse, et son liseré blanc
		var rouge := Color("d81e1e")
		var a := p + Vector3(-1.1, h - 0.05, 0)
		var b := p + Vector3(1.1, h - 0.05, 0)
		var c := p + Vector3(0, h - 1.9, 0)
		o.tri(a, b, c, Vector3.BACK, rouge)
		o.tri(a, c, b, Vector3.FORWARD, rouge)
		textes.append([Transform3D(Basis(), p + Vector3(0, h - 0.6, 0.02)), str(opt.get("texte", "1 KM")), BLANC, 0.009])
		textes.append([Transform3D(Basis(Vector3.UP, PI), p + Vector3(0, h - 0.6, -0.02)), str(opt.get("texte", "1 KM")), BLANC, 0.009])
		return Vector2(w + 1.0, 0.8)

	static func banderole(o: Outils, p: Vector3, opt: Dictionary, textes: Array) -> Vector2:
		var w := float(opt.get("largeur", 10.0))
		var col := _couleur(o, opt)
		var h := 4.6
		for cote in [-1.0, 1.0]:
			o.cylindre(Transform3D(Basis(), p + Vector3(cote * w * 0.5, -0.4, 0)), 0.07, 0.06, h + 1.0, 7, BOIS)
			o.collisions.append([Transform3D(Basis(), p + Vector3(cote * w * 0.5, h * 0.5, 0)), Vector3(0.2, h, 0.2)])
			o.branche(p + Vector3(cote * w * 0.5, h + 0.6, 0), p + Vector3(cote * (w * 0.5 + 1.5), 0, 0), 0.008, 0.008, NOIR, 3)
		# la toile tendue entre les mâts, ses œillets et ses cordes
		var tw := w - 0.6
		_panneau(o, p + Vector3(0, h, 0), tw, 1.0, col, str(opt.get("texte", "ALLEZ LES GARS !")), BLANC if col.get_luminance() < 0.6 else NOIR, textes, 0.02)
		o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.53, 0)), Vector3(tw, 0.06, 0.07), BLANC)
		o.boite(Transform3D(Basis(), p + Vector3(0, h - 0.53, 0)), Vector3(tw, 0.06, 0.07), BLANC)
		for cote in [-1.0, 1.0]:
			for dy in [-0.45, 0.45]:
				o.branche(p + Vector3(cote * tw * 0.5, h + dy, 0), p + Vector3(cote * w * 0.5, h + dy * 0.6, 0), 0.008, 0.008, NOIR, 3)
		return Vector2(w + 3.0, 0.4)

	static func fanions(o: Outils, p: Vector3, opt: Dictionary, textes: Array) -> Vector2:
		var w := float(opt.get("largeur", 10.0))
		var h := 5.0
		for cote in [-1.0, 1.0]:
			o.cylindre(Transform3D(Basis(), p + Vector3(cote * w * 0.5, -0.4, 0)), 0.06, 0.05, h + 0.6, 7, BOIS)
			o.collisions.append([Transform3D(Basis(), p + Vector3(cote * w * 0.5, h * 0.5, 0)), Vector3(0.2, h, 0.2)])
		# la guirlande pend en chaînette ; un fanion tous les 40 cm, aux couleurs en ronde
		var n := int(w / 0.4)
		var prec := p + Vector3(-w * 0.5, h, 0)
		for k in range(1, n + 1):
			var t := float(k) / n
			var x := lerpf(-w * 0.5, w * 0.5, t)
			var y := h - sin(t * PI) * w * 0.06
			var q := p + Vector3(x, y, 0)
			o.branche(prec, q, 0.006, 0.006, NOIR, 3)
			if k < n:
				var col := Color(COULEURS[(k + o.rng.randi() % 2) % COULEURS.size()])
				var a := q + Vector3(-0.14, 0, 0)
				var b := q + Vector3(0.14, 0, 0)
				var c := q + Vector3(0, -0.36, 0.02)
				o.tri(a, b, c, Vector3.BACK, col, Outils.FEUILLE)
				o.tri(a, c, b, Vector3.FORWARD, col, Outils.FEUILLE)
			prec = q
		return Vector2(w, 0.4)

	static func ligne(o: Outils, p: Vector3, opt: Dictionary, textes: Array) -> Vector2:
		var w := float(opt.get("largeur", 10.0))
		# la bande blanche, le damier noir et blanc juste avant, le mot ARRIVÉE peint sur la chaussée
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.05, 0)), Vector3(w, 0.12, 0.6), BLANC, Outils.DUR, true)
		var cases := int(w / 0.3)
		for i in cases:
			for j in 2:
				var col := NOIR if (i + j) % 2 == 0 else BLANC
				o.quad(p + Vector3(-w * 0.5 + i * 0.3, 0.012, -0.3 - j * 0.3), p + Vector3(-w * 0.5 + (i + 1) * 0.3, 0.012, -0.3 - j * 0.3),
					p + Vector3(-w * 0.5 + (i + 1) * 0.3, 0.012, -0.6 - j * 0.3), p + Vector3(-w * 0.5 + i * 0.3, 0.012, -0.6 - j * 0.3), Vector3.UP, col)
		# le mot se lit en arrivant : le haut des lettres vers la ligne
		var mot := str(opt.get("texte", "ARRIVÉE"))
		textes.append([Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI * 0.5), p + Vector3(0, 0.015, -2.2)), mot, BLANC, _ajuste(mot, w * 0.8, 2.4, 0.03)])
		return Vector2(w, 3.2)

	static func barrieres(o: Outils, p: Vector3, opt: Dictionary, textes: Array) -> Vector2:
		var l := float(opt.get("largeur", 10.0))
		var n := maxi(1, int(round(l / 2.1)))
		var col := _couleur(o, opt)
		for i in n:
			var x := -l * 0.5 + (i + 0.5) * l / n
			var c := p + Vector3(x, 0, 0)
			var lw := l / n - 0.08
			# le cadre de tube galvanisé, les barreaux, les pieds plats, la bâche du partenaire
			for cote in [-1.0, 1.0]:
				o.branche(c + Vector3(cote * lw * 0.5, 0.05, 0), c + Vector3(cote * lw * 0.5, 1.1, 0), 0.022, 0.022, FER, 6)
				o.boite(Transform3D(Basis(), c + Vector3(cote * lw * 0.45, 0.02, 0)), Vector3(0.06, 0.04, 0.7), FER)
			o.branche(c + Vector3(-lw * 0.5, 1.1, 0), c + Vector3(lw * 0.5, 1.1, 0), 0.022, 0.022, FER, 6)
			o.branche(c + Vector3(-lw * 0.5, 0.2, 0), c + Vector3(lw * 0.5, 0.2, 0), 0.02, 0.02, FER, 6)
			var nb := int(lw / 0.13)
			for k in range(1, nb):
				var bx := -lw * 0.5 + k * lw / nb
				o.branche(c + Vector3(bx, 0.2, 0), c + Vector3(bx, 1.1, 0), 0.008, 0.008, FER, 4)
			var bache := col if i % 2 == 0 else BLANC
			o.boite(Transform3D(Basis(), c + Vector3(0, 0.72, 0.03)), Vector3(lw - 0.06, 0.6, 0.012), bache)
			if i % 2 == 1 and opt.has("texte"):
				textes.append([Transform3D(Basis(), c + Vector3(0, 0.72, 0.04)), str(opt["texte"]), col, _ajuste(str(opt["texte"]), lw - 0.1, 0.6, 0.006)])
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.55, 0)), Vector3(l, 1.1, 0.25)])
		return Vector2(l, 0.7)

	static func podium(o: Outils, p: Vector3, opt: Dictionary, textes: Array) -> Vector2:
		var col := _couleur(o, opt)
		# les trois marches, 2 – 1 – 3, leurs numéros ; la toile de fond et son inscription
		var marches := [[-1.25, 0.55, "2"], [0.0, 0.85, "1"], [1.25, 0.38, "3"]]
		for m in marches:
			var x: float = m[0]
			var h: float = m[1]
			o.boite(Transform3D(Basis(), p + Vector3(x, h * 0.5 - 0.05, 0)), Vector3(1.24, h + 0.1, 1.0), BLANC, Outils.DUR, true)
			o.boite(Transform3D(Basis(), p + Vector3(x, h + 0.005, 0)), Vector3(1.24, 0.02, 1.0), col.lightened(0.2))
			textes.append([Transform3D(Basis(), p + Vector3(x, h * 0.5, 0.505)), m[2], col.darkened(0.2), 0.008])
		_panneau(o, p + Vector3(0, 2.2, -0.9), 4.6, 2.4, col, str(opt.get("texte", "PODIUM")), BLANC, textes, 0.014)
		for cote in [-1.0, 1.0]:
			o.cylindre(Transform3D(Basis(), p + Vector3(cote * 2.25, 0, -0.95)), 0.05, 0.05, 3.4, 6, FER)
			o.cylindre(Transform3D(Basis(), p + Vector3(cote * 2.25, 0, -0.95)), 0.3, 0.3, 0.06, 8, FER_SOMBRE)
			# les bouquets des vainqueurs, dans leurs seaux
			o.cylindre(Transform3D(Basis(), p + Vector3(cote * 2.1, 0, 0.6)), 0.16, 0.2, 0.32, 8, BLANC.darkened(0.1))
			for k in 6:
				var a := TAU * k / 6.0
				o.boule(p + Vector3(cote * 2.1 + cos(a) * 0.1, 0.45 + o.rng.randf_range(0.0, 0.1), 0.6 + sin(a) * 0.1), Vector3.ONE * 0.08, Color(["f2c14e", "e0605a", "f4f0e6"][k % 3]), 0.2, Outils.FEUILLE, 0.05, 0.3)
		return Vector2(5.0, 2.2)

	static func estrade(o: Outils, p: Vector3, opt: Dictionary, textes: Array) -> Vector2:
		# le plancher sur tréteaux, la rambarde, la table du speaker et son micro ; le mât des haut-parleurs
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.8, 0)), Vector3(2.4, 0.1, 2.0), BOIS, Outils.DUR, true)
		for dx in [-1.1, 1.1]:
			for dz in [-0.9, 0.9]:
				o.boite(Transform3D(Basis(), p + Vector3(dx, 0.37, dz)), Vector3(0.08, 0.8, 0.08), FER_SOMBRE)
		for k in 3:
			o.boite(Transform3D(Basis(), p + Vector3(0, 0.45 + k * 0.12, 1.0)), Vector3(2.3, 0.08, 0.02), BOIS.lightened(0.08))
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.25, 0.3)), Vector3(1.6, 0.05, 0.7), BLANC)
		for dx in [-0.75, 0.75]:
			o.boite(Transform3D(Basis(), p + Vector3(dx, 1.05, 0.3)), Vector3(0.05, 0.4, 0.6), FER_SOMBRE)
		o.branche(p + Vector3(0.2, 1.28, 0.4), p + Vector3(0.3, 1.5, 0.5), 0.01, 0.01, NOIR, 4)
		o.boule(p + Vector3(0.3, 1.52, 0.5), Vector3.ONE * 0.03, NOIR, 0.0, Outils.DUR, 0.0)
		var col := _couleur(o, opt)
		_panneau(o, p + Vector3(0, 1.05, 0.66), 1.55, 0.3, col, str(opt.get("texte", "RADIO TOUR")), BLANC, textes, 0.005)
		var mat := p + Vector3(1.4, 0, -1.2)
		o.cylindre(Transform3D(Basis(), mat), 0.05, 0.04, 5.5, 6, FER)
		for k in 3:
			var a := TAU * k / 3.0
			o.branche(mat + Vector3(0, 1.5, 0), mat + Vector3(cos(a) * 0.9, 0, sin(a) * 0.9), 0.02, 0.02, FER, 4)
		for k in 2:
			var a := PI * 0.5 + (k - 0.5) * 1.2
			var d := Vector3(cos(a), -0.15, sin(a)).normalized()
			var b := Basis.looking_at(-d, Vector3.UP)
			o.cylindre(Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), mat + Vector3(0, 5.2, 0) + d * 0.1), 0.08, 0.28, 0.5, 10, Color("d9d4c4"))
		o.collisions.append([Transform3D(Basis(), mat + Vector3(0, 2.75, 0)), Vector3(0.2, 5.5, 0.2)])
		return Vector2(3.4, 3.2)

	## Un vélo de course dans le repère t (roues au sol, l'avant vers +Z) : cadre en losange de tubes fins, cintre de
	## route, selle étroite, roues à jantes hautes et pneus de boyau, plateau et chaîne.
	static func _velo(o: Outils, t: Transform3D, col: Color) -> void:
		var rr := 0.34
		var ar := t * Vector3(0, rr, -0.5)
		var av := t * Vector3(0, rr, 0.5)
		var pedalier := t * Vector3(0, 0.29, -0.06)
		var selle := t * Vector3(0, 0.86, -0.22)
		var tete := t * Vector3(0, 0.84, 0.36)
		var douille := t * Vector3(0, 0.7, 0.4)
		var roue := Basis(Vector3.BACK, -PI * 0.5)
		for c in [ar, av]:
			var tr := Transform3D(t.basis * roue, c - t.basis * Vector3(0.012, 0, 0))
			o.anneau(tr, rr - 0.025, rr, 0.024, 20, PNEU)
			o.anneau(tr, rr - 0.06, rr - 0.025, 0.02, 20, Color("c8ccd0"))
			o.cylindre(Transform3D(t.basis * roue, c - t.basis * Vector3(0.05, 0, 0)), 0.025, 0.025, 0.1, 6, FER)
			for k in 8:
				var a := TAU * k / 8.0
				o.branche(c, c + t.basis * Vector3(0, cos(a), sin(a)) * (rr - 0.05), 0.003, 0.003, FER, 3)
		var tube := 0.016
		o.branche(pedalier, selle, tube, tube, col, 5)
		o.branche(pedalier, douille, tube * 1.1, tube, col, 5)
		o.branche(selle, tete, tube, tube, col, 5)
		o.branche(tete, douille, tube * 1.2, tube * 1.2, col, 5)
		for cote in [-0.05, 0.05]:
			var dc := t.basis * Vector3(cote, 0, 0)
			o.branche(pedalier + dc, ar + dc, 0.01, 0.01, col, 4)
			o.branche(selle + dc * 0.4, ar + dc, 0.009, 0.009, col, 4)
			o.branche(douille + dc * 0.6, av + dc, 0.011, 0.009, col.darkened(0.1), 4)
		# la selle, la tige ; le cintre et ses cocottes ; le plateau, les manivelles, la chaîne
		o.branche(selle, selle + t.basis * Vector3(0, 0.1, -0.02), 0.012, 0.012, FER, 4)
		o.boite(Transform3D(t.basis, selle + t.basis * Vector3(0, 0.12, 0)), Vector3(0.12, 0.04, 0.27), NOIR)
		var potence := tete + t.basis * Vector3(0, 0.06, 0.08)
		o.branche(tete, potence, 0.012, 0.012, FER, 4)
		o.branche(potence + t.basis * Vector3(-0.2, 0, 0), potence + t.basis * Vector3(0.2, 0, 0), 0.012, 0.012, NOIR, 5)
		for cote in [-0.2, 0.2]:
			var b0 := potence + t.basis * Vector3(cote, 0, 0)
			var b1 := b0 + t.basis * Vector3(0, -0.02, 0.1)
			var b2 := b1 + t.basis * Vector3(0, -0.12, 0.0)
			var b3 := b2 + t.basis * Vector3(0, -0.02, -0.1)
			o.branche(b0, b1, 0.012, 0.012, NOIR, 4)
			o.branche(b1, b2, 0.012, 0.012, NOIR, 4)
			o.branche(b2, b3, 0.012, 0.012, NOIR, 4)
		var pl := Transform3D(t.basis * roue, pedalier + t.basis * Vector3(0.05, 0, 0))
		o.anneau(pl, 0.07, 0.11, 0.008, 16, Color("c8ccd0"))
		o.branche(pedalier + t.basis * Vector3(0.06, 0, 0), pedalier + t.basis * Vector3(0.06, -0.15, 0.06), 0.01, 0.01, Color("c8ccd0"), 4)
		o.branche(pedalier + t.basis * Vector3(-0.06, 0, 0), pedalier + t.basis * Vector3(-0.06, 0.15, -0.06), 0.01, 0.01, Color("c8ccd0"), 4)
		for dy in [0.1, -0.1]:
			o.branche(pedalier + t.basis * Vector3(0.05, dy, 0), ar + t.basis * Vector3(0.05, dy * 0.4, 0), 0.004, 0.004, NOIR, 3)

	static func velo(o: Outils, p: Vector3, opt: Dictionary, textes: Array) -> Vector2:
		# le vélo debout sur son pied d'atelier, pour une vitrine ou un départ
		_velo(o, Transform3D(Basis(), p), _couleur(o, opt))
		o.branche(p + Vector3(0, 0.34, -0.5), p + Vector3(0.25, -0.05, -0.62), 0.012, 0.012, FER_SOMBRE, 4)
		o.branche(p + Vector3(0, 0.34, -0.5), p + Vector3(-0.25, -0.05, -0.62), 0.012, 0.012, FER_SOMBRE, 4)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(0.45, 1.0, 1.7)])
		return Vector2(0.5, 1.7)

	static func ratelier(o: Outils, p: Vector3, opt: Dictionary, textes: Array) -> Vector2:
		var n := clampi(int(opt.get("velos", 3)), 1, 5)
		var l := n * 0.7 + 0.4
		# la barre d'appui sur ses deux chevalets ; les vélos posés contre elle, chacun penché d'un rien
		for cote in [-1.0, 1.0]:
			var c := p + Vector3(cote * l * 0.5, 0, -0.65)
			o.branche(c + Vector3(0, 0, -0.35), c + Vector3(0, 1.05, 0), 0.025, 0.025, FER, 5)
			o.branche(c + Vector3(0, 0, 0.35), c + Vector3(0, 1.05, 0), 0.025, 0.025, FER, 5)
		o.branche(p + Vector3(-l * 0.5, 1.05, -0.65), p + Vector3(l * 0.5, 1.05, -0.65), 0.03, 0.03, FER, 6)
		for i in n:
			var x := -l * 0.5 + 0.55 + i * 0.7
			var b := Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, o.rng.randf_range(0.06, 0.12))
			_velo(o, Transform3D(b, p + Vector3(x, 0, 0)), Color(COULEURS[(i + o.rng.randi()) % COULEURS.size()]))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.55, -0.2)), Vector3(l, 1.1, 1.4)])
		return Vector2(l, 1.6)

	static func panneau_km(o: Outils, p: Vector3, opt: Dictionary, textes: Array) -> Vector2:
		for cote in [-0.5, 0.5]:
			o.cylindre(Transform3D(Basis(), p + Vector3(cote, -0.4, 0)), 0.04, 0.04, 2.6, 6, FER)
		_panneau(o, p + Vector3(0, 1.75, 0), 1.4, 0.9, BLANC, str(opt.get("texte", "5 KM")), NOIR, textes, 0.009)
		o.boite(Transform3D(Basis(), p + Vector3(0, 2.25, 0)), Vector3(1.4, 0.12, 0.07), Color("d22a2a"))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.1, 0)), Vector3(1.4, 2.2, 0.15)])
		return Vector2(1.5, 0.3)
