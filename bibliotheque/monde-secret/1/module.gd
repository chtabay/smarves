extends Node3D
## Le monde secret sous les cartes (Guillaume, 2 novembre 2026) : ce qu'on découvre en tombant très loin sous
## n'importe quelle carte. Un disque posé sur le dos de quatre éléphants debout sur la carapace d'une tortue
## géante. La brique bâtit les trois corps, module par module ; le socle (autoload Dessous, fil « Créer le monde
## secret sous les cartes ») les assemble, y ajoute la lanterne (le petit soleil), le ciel et le mécanisme de
## chute et de retour. Pas de nom de Pratchett : la tortue est Akoupara, les éléphants Airâvata, Vâmana, Anjana
## et Sârvabhauma (cosmologie indienne).
## On règle module, graine et options avant d'ajouter le nœud à la scène ; il se bâtit à son entrée dans l'arbre.
##   var m = load(Bibliotheque.scene("monde-secret@1", "decor")).instantiate()
##   m.module = "elephant" ; m.options = {"hauteur": 19.0}
##   add_child(m)
## Les mesures sont en unités du jeu telles que le socle les pose (sans échelle) : l'habitant fait 0,7. Les
## valeurs par défaut sont celles du monde secret du socle.
## Après la construction, le nœud porte ses métadonnées : module, graine, et selon le module :
##   disque   : rayon, ile (le rayon du dessus plat marchable, à y = 0), epaisseur (rien ne descend sous y = -epaisseur)
##   elephant : hauteur, dos (Vector3 : le point d'appui sur le dos, où poser le disque), longueur
##   tortue   : dessus (la hauteur du sommet de la carapace au-dessus de l'origine, le centre de la carapace),
##              demi_axes (Vector3 : large, haut, long), hauteur_a (une fonction d'un rayon r du centre vers la
##              hauteur de la carapace en r : dessus × sqrt(1 - (r / large)²))
const Outils := preload("res://bibliotheque/monde-secret/1/outils.gd")

## Les modules : le disque du monde (l'île d'herbe au milieu, l'eau qui en fait le tour et tombe en cascade sur
## tout le bord), l'éléphant porteur (debout, la tête vers +Z, les pieds à l'origine) et la tortue (la carapace
## centrée à l'origine, la tête vers +Z).
const MODULES := ["disque", "elephant", "tortue"]

const HERBE := Color("6f9c3a")
const HERBE_SOMBRE := Color("4f7a2a")
const TERRE := Color("7a5a3c")
const ROCHE := Color("5a4a3e")
const ROCHE_SOMBRE := Color("3e332c")
const EAU := Color("3f8fb8")
const EAU_CLAIRE := Color("7dc3de")
const ECUME := Color("eaf6fb")
const GRIS := Color("8f8a86")
const GRIS_SOMBRE := Color("6a6562")
const IVOIRE := Color("f1e9d4")
const CARAPACE := Color("5d6b3a")
const CARAPACE_CLAIRE := Color("7b8a4a")
const PEAU_TORTUE := Color("8a9a5c")
const OEIL := Color("1a1816")

## Le module (voir MODULES).
@export var module := "disque"
## La graine : la place des écailles de la carapace, l'ondulation des oreilles, le dessin de l'écume.
@export var graine := 1
## Les options, toutes facultatives :
##   disque   : rayon (30), ile (22 : le rayon de l'herbe), epaisseur (4), herbe / eau (des hexas)
##   elephant : hauteur (19 : du sol au dos), peau (un hexa)
##   tortue   : demi_axes ([55, 22, 62] : large, haut, long), carapace (un hexa)
@export var options := {}

var fait := false


func _ready() -> void:
	if fait:
		return
	fait = true
	var m := poser(self, Vector3.ZERO, module, graine, options)
	for k in m:
		set_meta(k, m[k])


## Les modules, pour une commune qui les passe en revue.
static func noms() -> Array:
	return MODULES.duplicate()


## Bâtit un module sous parent, son origine en p (sans rotation : tourner le parent). Rend les métadonnées.
static func poser(parent: Node3D, p: Vector3, nom: String, g: int, opt := {}) -> Dictionary:
	if not nom in MODULES:
		nom = "disque"
	var o := Outils.new(g * 104729 + MODULES.find(nom) * 31 + 5)
	var m: Dictionary = Callable(_Modules, nom).call(o, p, opt)
	o.construire(parent, nom.capitalize())
	m["module"] = nom
	m["graine"] = g
	return m


class _Modules:
	## Le disque du monde : un plateau de roche sombre dont le dessous est à -epaisseur, l'île d'herbe au milieu
	## (dessus plat à y = 0 sur le rayon ile, où le socle pose sa collision), l'eau qui en fait le tour un peu
	## plus bas et qui tombe en cascade sur tout le bord, en rideaux bleus et blancs.
	static func disque(o: Outils, p: Vector3, opt: Dictionary) -> Dictionary:
		var R := maxf(float(opt.get("rayon", 30.0)), 2.0)
		var ile := clampf(float(opt.get("ile", R * 22.0 / 30.0)), 1.0, R - 0.5)
		var ep := maxf(float(opt.get("epaisseur", 4.0)), 0.5)
		var herbe := Color(str(opt.get("herbe", HERBE.to_html(false))))
		var eau := Color(str(opt.get("eau", EAU.to_html(false))))
		var r := o.rng
		var cotes := 64
		# le plateau : la roche, de -0.3 jusqu'aux trois quarts de l'épaisseur, un peu plus étroit sous l'eau ;
		# tout le module tient entre y = 0 et y = -epaisseur (la cascade et la brume descendent jusque là)
		var fond := ep * 0.72
		o.cylindre(Transform3D(Basis(), p + Vector3(0, -fond, 0)), R * 0.9, R - 0.05, fond - 0.3, cotes, ROCHE, Outils.DUR, true)
		# la collision du plateau : une boîte invisible dans la roche (demi-largeur 0.6 R, dessus à -0.6) ; l'île
		# marchable n'a pas de collision ici, c'est au socle de la poser (un cylindre de rayon ile, dessus à 0)
		o.boite(Transform3D(Basis(), p + Vector3(0, -(fond + 0.6) * 0.5, 0)), Vector3(R * 1.2, fond - 0.6, R * 1.2), Color(0, 0, 0, 0), Outils.DUR, true)
		# la nappe d'eau, à -0.25, jusqu'au bord
		o.cylindre(Transform3D(Basis(), p + Vector3(0, -0.5, 0)), R, R, 0.25, cotes, eau, Outils.DUR, true)
		# l'île : la terre sous l'herbe, l'herbe à plat à y = 0, le bord de l'île en talus d'herbe sombre
		o.cylindre(Transform3D(Basis(), p + Vector3(0, -0.5, 0)), ile + 0.4, ile + 0.2, 0.3, cotes, TERRE, Outils.DUR, true)
		o.cylindre(Transform3D(Basis(), p + Vector3(0, -0.2, 0)), ile + 0.2, ile, 0.2, cotes, herbe, Outils.DUR, true)
		# quelques touffes et pierres sur l'île, pour que le sol ne soit pas un aplat
		for i in int(ile * ile * 0.12):
			var a := r.randf() * TAU
			var d := sqrt(r.randf()) * (ile - 0.6)
			var q := p + Vector3(cos(a) * d, 0.0, sin(a) * d)
			if r.randf() < 0.85:
				o.boule(q, Vector3(0.25, 0.12, 0.25) * r.randf_range(0.7, 1.4), HERBE_SOMBRE.lightened(r.randf_range(-0.05, 0.1)), 0.2, Outils.DUR, 0.04, 1.0, 3, 5)
			else:
				o.boule(q + Vector3(0, 0.08, 0), Vector3(0.3, 0.18, 0.25) * r.randf_range(0.6, 1.3), GRIS.darkened(0.1), 0.25, Outils.DUR, 0.05, 1.0, 3, 6)
		# la cascade : des rideaux d'eau et d'écume tout autour, de la nappe au dessous du plateau et un peu plus bas
		var n := int(TAU * R / 1.0)
		for i in n:
			var a := TAU * i / n
			var b := Basis(Vector3.UP, -a)
			var ecume := r.randf() < 0.22
			var col: Color = ECUME.lerp(EAU_CLAIRE, r.randf_range(0.0, 0.35)) if ecume else eau.lerp(EAU_CLAIRE, r.randf_range(-0.1, 0.45))
			var h := fond - 0.25 + r.randf_range(0.0, ep - fond - 0.15) * (0.6 if ecume else 1.0)
			o.boite(Transform3D(b, p + b * Vector3(R + 0.05 + (0.12 if ecume else 0.0), -0.25 - h * 0.5, 0)), Vector3(0.12 if ecume else 0.08, h, r.randf_range(0.7, 1.15)), col)
		# la brume d'écume sous le bord
		for i in n / 2:
			var a := TAU * (i + 0.5) / (n / 2)
			var k := r.randf_range(0.7, 1.3)
			o.boule(p + Vector3(cos(a) * (R + 0.4), -ep + 0.6 * k + 0.1 + r.randf_range(0.0, ep - fond - 0.4), sin(a) * (R + 0.4)), Vector3(1.4, 0.6, 1.4) * k, ECUME.darkened(0.05), 0.3, Outils.DUR, 0.04, 1.0, 3, 6)
		return {"rayon": R, "ile": ile, "epaisseur": ep}

	## L'éléphant porteur : debout, les pieds à l'origine, la tête vers +Z, le dos à hauteur ; le disque se pose
	## sur le méta « dos ». Le corps en masses pleines, les oreilles en voiles, les défenses d'ivoire, la trompe
	## qui pend en s'enroulant un peu.
	static func elephant(o: Outils, p: Vector3, opt: Dictionary) -> Dictionary:
		var H := maxf(float(opt.get("hauteur", 19.0)), 1.0)
		var peau := Color(str(opt.get("peau", GRIS.to_html(false))))
		var r := o.rng
		var L := H * 0.42  # la hauteur des pattes
		var cc := p + Vector3(0, L + H * 0.28, 0)  # le centre du corps
		var Rc := Vector3(H * 0.26, H * 0.30, H * 0.40)
		# le corps, l'échine un peu relevée
		o.boule(cc, Rc, peau, 0.05, Outils.DUR, 0.02, 1.0, 10, 16)
		o.boite(Transform3D(Basis(), cc), Rc * 1.1, Color(0, 0, 0, 0), Outils.DUR, true)  # la collision du corps
		o.boule(cc + Vector3(0, H * 0.12, -H * 0.05), Vector3(Rc.x * 0.8, Rc.y * 0.7, Rc.z * 0.75), peau.lightened(0.02), 0.04, Outils.DUR, 0.02, 1.0, 8, 12)
		# les pattes : des colonnes qui s'évasent au pied, les ongles en pastilles claires
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var q := p + Vector3(sx * H * 0.15, 0, sz * H * 0.24)
				o.cylindre(Transform3D(Basis(), q), H * 0.085, H * 0.07, L + H * 0.1, 12, peau.darkened(0.08), Outils.DUR, true)
				o.boite(Transform3D(Basis(), q + Vector3(0, L * 0.5, 0)), Vector3(H * 0.1, L, H * 0.1), Color(0, 0, 0, 0), Outils.DUR, true)  # la collision de la patte
				for k in 3:
					var a := (k - 1) * 0.5 + (PI if sz < 0.0 else 0.0)
					o.boule(q + Vector3(sin(a) * H * 0.075, H * 0.012, cos(a) * H * 0.075 * sz), Vector3(H * 0.018, H * 0.012, H * 0.014), IVOIRE.darkened(0.08), 0.0, Outils.DUR, 0.0, 1.0, 3, 6)
		# la tête, le front bombé, les yeux
		var ct := cc + Vector3(0, H * 0.14, Rc.z + H * 0.02)
		o.boule(ct, Vector3(H * 0.15, H * 0.16, H * 0.15), peau, 0.04, Outils.DUR, 0.02, 1.0, 8, 12)
		for sx in [-1.0, 1.0]:
			o.boule(ct + Vector3(sx * H * 0.09, -H * 0.01, H * 0.115), Vector3(H * 0.016, H * 0.016, H * 0.01), OEIL, 0.0, Outils.DUR, 0.0, 1.0, 3, 6)
		# les oreilles : deux voiles minces, un peu écartées du crâne, légèrement ondulées par la graine
		for sx in [-1.0, 1.0]:
			var b := Basis(Vector3.UP, sx * r.randf_range(0.25, 0.4)) * Basis(Vector3.RIGHT, r.randf_range(-0.1, 0.1))
			o.boite(Transform3D(b, ct + Vector3(sx * H * 0.165, -H * 0.02, -H * 0.03)), Vector3(H * 0.015, H * 0.24, H * 0.2), [peau.darkened(0.08), peau.darkened(0.08), peau.darkened(0.03), peau.darkened(0.03), peau.lightened(0.02), peau.darkened(0.15)])
		# la trompe : des segments qui descendent en s'affinant, le bout qui se recourbe vers l'avant
		var pts := []
		var q0 := ct + Vector3(0, -H * 0.04, H * 0.13)
		var courbe := [Vector3(0, -0.12, 0.05), Vector3(0, -0.14, 0.02), Vector3(0, -0.14, -0.01), Vector3(0, -0.12, 0.0), Vector3(0, -0.07, 0.04), Vector3(0, -0.01, 0.05)]
		pts.append(q0)
		for c in courbe:
			pts.append(pts[-1] + c * H)
		for i in pts.size() - 1:
			var ra := H * lerpf(0.06, 0.025, float(i) / (pts.size() - 1))
			var rb := H * lerpf(0.06, 0.025, float(i + 1) / (pts.size() - 1))
			o.branche(pts[i], pts[i + 1], ra, rb, peau.darkened(0.04), 10)
		# les défenses, d'ivoire, qui partent sous les yeux et se relèvent
		for sx in [-1.0, 1.0]:
			var d0 := ct + Vector3(sx * H * 0.06, -H * 0.08, H * 0.1)
			var d1 := d0 + Vector3(sx * H * 0.02, -H * 0.06, H * 0.12)
			var d2 := d1 + Vector3(sx * H * 0.01, H * 0.03, H * 0.09)
			o.branche(d0, d1, H * 0.022, H * 0.016, IVOIRE, 8)
			o.branche(d1, d2, H * 0.016, H * 0.006, IVOIRE, 8)
		# la queue, et sa houppe
		var t0 := cc + Vector3(0, H * 0.05, -Rc.z + H * 0.02)
		var t1 := t0 + Vector3(0, -H * 0.22, -H * 0.03)
		o.branche(t0, t1, H * 0.018, H * 0.01, peau.darkened(0.1), 6)
		o.boule(t1, Vector3(H * 0.02, H * 0.035, H * 0.02), GRIS_SOMBRE, 0.1, Outils.DUR, 0.0, 1.0, 3, 6)
		return {"hauteur": H, "dos": Vector3(0, H, 0), "longueur": Rc.z * 2.0 + H * 0.3}

	## La tortue géante : la carapace, un ellipsoïde centré à l'origine (le sommet à y = haut), semée d'écailles
	## un peu plus claires ; dessous le plastron ; la tête tendue vers +Z, quatre nageoires, une courte queue.
	static func tortue(o: Outils, p: Vector3, opt: Dictionary) -> Dictionary:
		var da: Array = opt.get("demi_axes", [55.0, 22.0, 62.0])
		var A := Vector3(maxf(float(da[0]), 1.0), maxf(float(da[1]), 0.5), maxf(float(da[2]), 1.0))
		var carapace := Color(str(opt.get("carapace", CARAPACE.to_html(false))))
		var r := o.rng
		# la carapace, et dessous le plastron, plus plat et plus clair
		o.boule(p, A, carapace, 0.02, Outils.DUR, 0.02, 1.0, 16, 28)
		o.boite(Transform3D(Basis(), p), A * 1.1, Color(0, 0, 0, 0), Outils.DUR, true)  # la collision de la carapace
		o.boule(p + Vector3(0, -A.y * 0.35, 0), Vector3(A.x * 0.92, A.y * 0.55, A.z * 0.92), PEAU_TORTUE.darkened(0.1), 0.02, Outils.DUR, 0.02, 1.0, 10, 20)
		# les écailles : des plaques à sept côtés plaquées sur la carapace (un éventail de triangles posé sur
		# l'ellipsoïde, un peu en saillie), en couronnes autour du sommet, plus claires que le fond
		var couronnes := [[0.0, 1, 0.22], [0.26, 6, 0.2], [0.5, 11, 0.19], [0.72, 16, 0.17]]
		for c in couronnes:
			var u: float = c[0]
			var n: int = c[1]
			var rho: float = c[2]
			for i in n:
				var a := TAU * i / n + (0.5 * TAU / n if n > 1 and int(u * 100) % 2 == 1 else 0.0) + r.randf_range(-0.04, 0.04)
				var phi := u * PI * 0.5 + r.randf_range(-0.02, 0.02)
				var dir := Vector3(sin(phi) * cos(a), cos(phi), sin(phi) * sin(a))
				var col := CARAPACE_CLAIRE.lightened(r.randf_range(-0.04, 0.06))
				_ecaille(o, p, A, dir, rho * r.randf_range(0.9, 1.05), col)
		# le cou et la tête, tendus vers +Z, les yeux, le bec
		var c0 := p + Vector3(0, -A.y * 0.15, A.z * 0.92)
		var c1 := c0 + Vector3(0, A.y * 0.05, A.x * 0.3)
		o.branche(c0, c1, A.x * 0.12, A.x * 0.1, PEAU_TORTUE, 12)
		var ct := c1 + Vector3(0, A.y * 0.03, A.x * 0.1)
		o.boule(ct, Vector3(A.x * 0.13, A.x * 0.1, A.x * 0.17), PEAU_TORTUE.lightened(0.04), 0.03, Outils.DUR, 0.02, 1.0, 8, 12)
		o.boule(ct + Vector3(0, -A.x * 0.03, A.x * 0.14), Vector3(A.x * 0.07, A.x * 0.05, A.x * 0.06), PEAU_TORTUE.darkened(0.15), 0.0, Outils.DUR, 0.0, 1.0, 4, 8)
		for sx in [-1.0, 1.0]:
			o.boule(ct + Vector3(sx * A.x * 0.1, A.x * 0.03, A.x * 0.08), Vector3(A.x * 0.02, A.x * 0.02, A.x * 0.012), OEIL, 0.0, Outils.DUR, 0.0, 1.0, 3, 6)
		# les nageoires : quatre pales plates, un peu tombantes, vers l'avant devant et vers l'arrière derrière
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var q := p + Vector3(sx * A.x * 0.8, -A.y * 0.45, sz * A.z * 0.5)
				var b := Basis(Vector3.UP, -sx * sz * 0.5) * Basis(Vector3.FORWARD, sx * 0.25)
				var cn := q + b * Vector3(sx * A.x * 0.3, 0, 0)
				o.boule(cn, Vector3(A.x * 0.36, A.y * 0.08, A.z * 0.16), PEAU_TORTUE.darkened(0.05), 0.03, Outils.DUR, 0.02, 1.0, 5, 10)
		# la queue
		var q0 := p + Vector3(0, -A.y * 0.3, -A.z * 0.9)
		o.branche(q0, q0 + Vector3(0, -A.y * 0.1, -A.x * 0.22), A.x * 0.05, A.x * 0.015, PEAU_TORTUE, 8)
		return {"dessus": A.y, "demi_axes": A, "hauteur_a": func(rr: float) -> float: return A.y * sqrt(maxf(1.0 - (rr / A.x) * (rr / A.x), 0.0))}

	## Une écaille : un éventail de sept triangles dont les sommets sont posés sur l'ellipsoïde (centre p,
	## demi-axes A) autour de la direction dir, à rho radians d'ouverture, poussés d'un pour cent vers le dehors.
	static func _ecaille(o: Outils, p: Vector3, A: Vector3, dir: Vector3, rho: float, col: Color) -> void:
		var t1 := dir.cross(Vector3.FORWARD).normalized() if absf(dir.dot(Vector3.FORWARD)) < 0.9 else dir.cross(Vector3.RIGHT).normalized()
		var t2 := dir.cross(t1).normalized()
		var sur := func(d: Vector3) -> Vector3:
			return p + Vector3(d.x * A.x, d.y * A.y, d.z * A.z) * 1.012
		var centre: Vector3 = sur.call(dir)
		var nrm := Vector3(dir.x / A.x, dir.y / A.y, dir.z / A.z).normalized()
		var pts := []
		for k in 7:
			var th := TAU * k / 7.0
			pts.append(sur.call((dir + (t1 * cos(th) + t2 * sin(th)) * rho).normalized()))
		for k in 7:
			var b: Vector3 = pts[k]
			var c: Vector3 = pts[(k + 1) % 7]
			if (b - centre).cross(c - centre).dot(nrm) < 0.0:
				var x := b
				b = c
				c = x
			o.tri(centre, b, c, nrm, col)
