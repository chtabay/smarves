extends Node3D
## Une plante du décor lyonnais, posée telle quelle : on règle plante, graine et options avant de l'ajouter à la
## scène, elle se bâtit à son entrée dans l'arbre de scène. Le pied est à l'origine, sur un sol plat à y = 0 ;
## la vigne grimpe contre un mur placé derrière elle (le mur en z = 0, elle pousse vers +Z) ; en mètres (une
## commune à l'échelle du village de Smarves, 1 unité = 2,4 m, la pose à l'échelle 1/2,4).
##   var v = load(Bibliotheque.scene("vegetation-lyonnaise@1", "decor")).instantiate()
##   v.plante = "platane" ; v.graine = 7 ; v.options = {"pied": "grille"}
##   add_child(v)
## Après la construction, le nœud porte ses métadonnées : plante, graine, hauteur, couronne (le rayon de la
## couronne, pour espacer une rangée).
const Outils := preload("res://bibliotheque/vegetation-lyonnaise/1/outils.gd")

## Les plantes : le grand platane des quais à l'écorce tachée, l'arbre d'alignement taillé, l'oranger en caisse,
## le cyprès, le bac fleuri, la vigne grimpante sur son treillage, le massif, le buisson et l'herbe (une nappe de
## touffes en cartes, à la place d'un gazon en aplat ; revue de Sathonay n° 4).
const PLANTES := ["platane", "alignement", "oranger", "cypres", "bac_fleuri", "vigne", "massif", "buisson", "herbe"]

const VERTS := {
	"platane": ["94c44c", "7cb23f", "679d35", "548829"],
	"alignement": ["8fc24a", "78b03d", "659c34", "52882b"],
	"oranger": ["5f9a34", "4f8a2c", "437a26", "386a20"],
	"cypres": ["4c7f36", "41722f", "376528", "2d5622"],
	"vigne": ["8cc646", "76b23a", "5f9a30", "4f8a2a"],
	"massif": ["7cc23c", "69b032", "5a9c30", "4b8a2a"],
	"buisson": ["86c445", "72b23a", "5f9a30", "4f8a2a"],
	"bac_fleuri": ["7cc23c", "69b032", "5a9c30", "4b8a2a"],
	"herbe": ["9ccf4e", "7fb83c", "63a030", "4a8428"],
}
const FLEURS := ["e0605a", "f2c14e", "d04a8a", "b06ad0", "f4f0e6", "e8823a", "8a6ad0"]
const TERRE := Color("6b4f36")
const PIERRE := Color("e9dcbc")
const PIERRE_SOMBRE := Color("cdbb92")

## La plante (voir PLANTES).
@export var plante := "platane"
## La graine : deux plantes de même nom et de graines différentes ne se ressemblent pas.
@export var graine := 1
## Les options, toutes facultatives : hauteur (en mètres), pied (les arbres : « » la terre, « grille » une grille
## de fonte, « bordure » une bordure de pierre), fleurs (un hexa), longueur (le bac, la vigne, le massif, l'herbe),
## vent (0 à 1, l'amplitude du souffle), fruits (false : l'oranger sans ses oranges) ; l'herbe : largeur, points (le
## contour de la nappe en mètres, à la place de longueur × largeur), densite (un multiplicateur des touffes, 1 par
## défaut), plafond (2 500 touffes au plus par défaut : au-delà elles grossissent au lieu de se multiplier).
@export var options := {}

var fait := false


func _ready() -> void:
	if fait:
		return
	fait = true
	var m := pousser(self, Vector3.ZERO, plante, graine, options)
	for k in m:
		set_meta(k, m[k])


## Les plantes, pour une commune qui les passe en revue.
static func noms() -> Array:
	return PLANTES.duplicate()


## Bâtit une plante sous parent, son pied en p. Rend plante, graine, hauteur, couronne.
static func pousser(parent: Node3D, p: Vector3, nom: String, g: int, opt := {}) -> Dictionary:
	if not nom in PLANTES:
		nom = "platane"
	var o := Outils.new(g * 7919 + PLANTES.find(nom) * 17)
	var verts: Array = VERTS[nom].map(func(h): return Color(h))
	var mesures: Vector2 = Callable(_Plantes, nom).call(o, p, verts, opt)
	_pied(o, p, str(opt.get("pied", "")), opt)
	o.construire(parent, nom.capitalize())
	return {"plante": nom, "graine": g, "hauteur": mesures.x, "couronne": mesures.y}


static func _pied(o: Outils, p: Vector3, pied: String, opt: Dictionary) -> void:
	var t := Transform3D(Basis(), p)
	if pied == "grille":
		o.cylindre(t, 0.72, 0.72, 0.03, 16, Color("2c2f30"))
		for i in 16:
			var a := TAU * i / 16.0
			var b := Basis(Vector3.UP, -a)
			o.boite(Transform3D(b, p + Vector3(cos(a), 0, sin(a)) * 0.48 + Vector3(0, 0.04, 0)), Vector3(0.42, 0.02, 0.03), Color("1f2223"))
		o.anneau(t, 0.72, 0.84, 0.05, 16, PIERRE_SOMBRE)
	elif pied == "bordure":
		o.anneau(t, 0.95, 1.15, 0.26, 4, PIERRE)
		o.cylindre(t, 0.95, 0.95, 0.18, 4, TERRE)
		var fleur := Color(str(opt.get("fleurs", FLEURS[o.rng.randi() % FLEURS.size()])))
		for i in 8:
			var a := TAU * i / 8.0 + o.rng.randf() * 0.3
			var q := p + Vector3(cos(a), 0, sin(a)) * o.rng.randf_range(0.45, 0.62) + Vector3(0, 0.24, 0)
			o.boule(q, Vector3(0.2, 0.13, 0.2), Color("5f9e33"), 0.2, Outils.FEUILLE, 0.05, 0.2)
			o.boule(q + Vector3(0, 0.08, 0), Vector3(0.13, 0.07, 0.13), fleur, 0.3, Outils.FEUILLE, 0.1, 0.2)


class _Plantes:
	## Une touffe de feuilles semée de fleurs, centrée en c, de rayon r.
	## Des feuilles sur une masse : des cartes de 6 à 11 cm posées sur l'ellipsoïde de centre c et de rayons r,
	## tournées au hasard, un peu relevées, plus nombreuses vers le haut ; on lit des feuilles, pas des facettes
	## (celles des buissons du bac toulousain, demandées pour Sathonay par la revue n° 4).
	static func _feuilles(o: Outils, c: Vector3, r: Vector3, col: Color, n: int) -> void:
		for i in n:
			var th := o.rng.randf() * TAU
			var y := o.rng.randf_range(-0.3, 1.0)
			var s := sqrt(maxf(0.0, 1.0 - y * y))
			var d := Vector3(cos(th) * s, y, sin(th) * s)
			var q := c + Vector3(d.x * r.x, d.y * r.y, d.z * r.z)
			var nrm := Vector3(d.x / r.x, d.y / r.y, d.z / r.z).normalized()
			var t := nrm.cross(Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT).normalized()
			var b2 := nrm.cross(t)
			var rot := o.rng.randf() * TAU
			var u := (t * cos(rot) + b2 * sin(rot))
			var v := (b2 * cos(rot) - t * sin(rot))
			var l := o.rng.randf_range(0.06, 0.11)
			var w := l * 0.6
			var p0 := q - u * w * 0.5
			var p1 := q + u * w * 0.5
			var p2 := q + u * w * 0.3 + v * l + nrm * l * 0.35
			var p3 := q - u * w * 0.3 + v * l + nrm * l * 0.35
			var teinte := col.lightened(o.rng.randf_range(-0.08, 0.12))
			o.quad(p0, p1, p2, p3, nrm, teinte, Outils.FEUILLE)

	## Une masse de feuillage couverte de ses feuilles : la boule un peu réduite et assombrie, les cartes dessus.
	static func _masse(o: Outils, c: Vector3, r: Vector3, col: Color, vent: float) -> void:
		o.boule(c, r * 0.92, col.darkened(0.05), 0.18, Outils.FEUILLE, 0.05, vent)
		_feuilles(o, c, r, col, int(clampf(r.x * r.y * 400.0, 14.0, 90.0)))

	## Des fleurs posées sur une masse de feuilles : des boules sur le dessus de l'ellipsoïde (centre c, rayons r),
	## un peu au-dessus des cartes pour qu'elles restent visibles (le verdict n° 29 de Sathonay : Blandan avait perdu
	## ses fleurs, enterrées sous les feuilles fines).
	static func _fleurs(o: Outils, c: Vector3, r: Vector3, fleur: Color, n: int, taille: float, vent: float) -> void:
		for i in n:
			var a := o.rng.randf() * TAU
			var y := o.rng.randf_range(0.15, 0.9)
			var s := sqrt(1.0 - y * y)
			var d := Vector3(cos(a) * s, y, sin(a) * s)
			var q := c + Vector3(d.x * r.x, d.y * r.y, d.z * r.z) + Vector3(d.x / r.x, d.y / r.y, d.z / r.z).normalized() * taille * 0.6
			o.boule(q, Vector3.ONE * taille, fleur.lightened(o.rng.randf_range(-0.08, 0.1)), 0.2, Outils.FEUILLE, 0.05, vent)

	static func _touffe(o: Outils, c: Vector3, r: float, vert: Color, fleur: Color, n_fleurs := 6) -> void:
		_masse(o, c, Vector3(r, r * 0.75, r), vert, 0.3)
		_fleurs(o, c, Vector3(r, r * 0.75, r), fleur, n_fleurs, r * 0.22, 0.3)

	## Une couronne de touffes sur l'ellipsoïde de centre c et de rayons R, le dessus plus clair.
	static func _couronne(o: Outils, c: Vector3, R: Vector3, verts: Array, n: int, vent: float, taille := Vector2(0.36, 0.52)) -> void:
		var r := o.rng
		o.boule(c, R * 0.8, verts[3], 0.1, Outils.FEUILLE, 0.04, vent * 0.5)
		for i in n:
			var y := r.randf_range(-0.5, 1.0)
			var a := r.randf() * TAU
			var rr := sqrt(maxf(0.0, 1.0 - y * y))
			var d := Vector3(cos(a) * rr, y, sin(a) * rr)
			var s := r.randf_range(taille.x, taille.y)
			var teinte: Color = verts[clampi(int((1.0 - (y * 0.5 + 0.5)) * 3.0 + r.randf_range(-0.6, 0.6)), 0, 3)]
			o.boule(c + Vector3(d.x * R.x, d.y * R.y, d.z * R.z) * 0.62, R * s, teinte, 0.16, Outils.FEUILLE, 0.06, vent)

	static func platane(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var vent := float(opt.get("vent", 1.0))
		var h := float(opt.get("hauteur", 12.0 * r.randf_range(0.9, 1.1)))
		var k := h / 12.0
		var fut := h * 0.32
		var rt := 0.26 * k
		var ec := Color("ad9f80")
		# le fût clair, marbré de plaques d'écorce olive et grise
		o.branche(p + Vector3(0, -0.2, 0), p + Vector3(0, fut, 0), rt * 1.15, rt, ec, 10)
		o.cylindre(Transform3D(Basis(), p), rt * 1.7, rt * 1.15, 0.4, 10, ec.darkened(0.12), Outils.DUR, false)
		var plaques := [Color("9a9a78"), Color("b3a98a"), Color("8a8c70"), Color("ddd3b6")]
		for i in 18:
			var y := r.randf_range(0.3, fut)
			var a := r.randf() * TAU
			var b := Basis(Vector3.UP, a)
			var rr := lerpf(rt * 1.15, rt, y / fut) + 0.005
			o.boite(Transform3D(b, p + Vector3(0, y, 0) + b * Vector3(0, 0, rr)), Vector3(rr * r.randf_range(0.5, 1.0), r.randf_range(0.2, 0.5), 0.02), plaques[r.randi() % plaques.size()])
		# trois ou quatre charpentières qui s'ouvrent en V, chacune portant sa couronne
		var n := 3 + r.randi() % 2
		var R := Vector3(h * 0.36, h * 0.28, h * 0.36)
		var c := p + Vector3(0, fut + R.y * 1.1, 0)
		for i in n:
			var a := TAU * i / n + r.randf() * 0.6
			var d := Vector3(cos(a), 0, sin(a))
			var m := p + Vector3(0, fut + h * 0.18, 0) + d * h * 0.16
			var bout := c + d * R.x * 0.5 + Vector3(0, r.randf_range(-0.1, 0.4) * R.y, 0)
			o.branche(p + Vector3(0, fut - 0.1, 0), m, rt * 0.75, rt * 0.55, ec, 7)
			o.branche(m, bout, rt * 0.55, rt * 0.2, ec.lightened(0.04), 6)
			o.branche(m, m + (bout - m).rotated(Vector3.UP, 0.9) * 0.7, rt * 0.35, rt * 0.12, ec, 5)
		_couronne(o, c, R, verts, 18 + r.randi() % 5, vent, Vector2(0.32, 0.46))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.4, 0)), Vector3(0.7, 2.8, 0.7) * k])
		return Vector2(h, maxf(R.x, R.z))

	static func alignement(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var vent := float(opt.get("vent", 1.0))
		var h := float(opt.get("hauteur", 7.0 * r.randf_range(0.92, 1.08)))
		var k := h / 7.0
		var fut := h * 0.38
		var rt := 0.13 * k
		var ec := Color("7a6450")
		# un tronc droit, une couronne taillée en ovale régulier, comme en rideau le long d'un cours
		o.branche(p + Vector3(0, -0.2, 0), p + Vector3(0, fut, 0), rt * 1.2, rt, ec, 8)
		var R := Vector3(h * 0.27, h * 0.33, h * 0.27)
		var c := p + Vector3(0, fut + R.y * 0.95, 0)
		for i in 4:
			var a := TAU * i / 4.0 + r.randf() * 0.5
			o.branche(p + Vector3(0, fut, 0), c + Vector3(cos(a) * R.x * 0.5, r.randf_range(-0.2, 0.3) * R.y, sin(a) * R.z * 0.5), rt * 0.7, rt * 0.25, ec, 5)
		_couronne(o, c, R, verts, 12 + r.randi() % 4, vent * 0.6, Vector2(0.42, 0.56))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.2, 0)), Vector3(0.4, 2.4, 0.4) * k])
		return Vector2(h, R.x)

	static func oranger(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var h := float(opt.get("hauteur", 2.6))
		var k := h / 2.6
		# la caisse de Versailles : quatre montants à boule, des panneaux blancs, une ceinture verte
		var l := 0.9 * k
		var blanc := Color("f1ede2")
		var vert_caisse := Color("2e5a3e")
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.45 * k, 0)), Vector3(l - 0.06, 0.7 * k, l - 0.06), blanc)
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				var q := p + Vector3(cx * l * 0.5, 0, cz * l * 0.5)
				o.boite(Transform3D(Basis(), q + Vector3(0, 0.4 * k, 0)), Vector3(0.1, 0.9 * k, 0.1) * Vector3(k, 1, k), vert_caisse)
				o.boule(q + Vector3(0, 0.9 * k, 0), Vector3.ONE * 0.08 * k, vert_caisse, 0.0, Outils.DUR, 0.0)
		for i in 4:
			var b := Basis(Vector3.UP, PI * 0.5 * i)
			o.boite(Transform3D(b, p + b * Vector3(0, 0.45 * k, l * 0.47)), Vector3(l * 0.8, 0.06 * k, 0.03), vert_caisse)
			o.boite(Transform3D(b * Basis(Vector3.BACK, 0.7), p + b * Vector3(0, 0.45 * k, l * 0.475)), Vector3(l * 0.95, 0.03 * k, 0.02), vert_caisse)
			o.boite(Transform3D(b * Basis(Vector3.BACK, -0.7), p + b * Vector3(0, 0.45 * k, l * 0.475)), Vector3(l * 0.95, 0.03 * k, 0.02), vert_caisse)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.81 * k, 0)), Vector3(l - 0.1, 0.03, l - 0.1), TERRE)
		# la tige et la boule sombre, piquée d'oranges
		var fut := 1.35 * k
		o.branche(p + Vector3(0, 0.8 * k, 0), p + Vector3(0, fut + 0.2, 0), 0.05 * k, 0.04 * k, Color("6e5a48"), 6)
		var R := 0.62 * k
		var c := p + Vector3(0, fut + R * 0.85, 0)
		o.boule(c, Vector3(R, R * 0.92, R), verts[1], 0.06, Outils.FEUILLE, 0.04, 0.3)
		for i in 7:
			var a := TAU * i / 7.0 + r.randf()
			var y := r.randf_range(-0.3, 0.7)
			o.boule(c + Vector3(cos(a) * R * 0.45, y * R * 0.5, sin(a) * R * 0.45), Vector3.ONE * R * 0.58, verts[r.randi() % 4], 0.1, Outils.FEUILLE, 0.04, 0.3)
		if opt.get("fruits", true):
			for i in 16:
				var y := r.randf_range(-0.5, 0.85)
				var a := r.randf() * TAU
				var rr := sqrt(maxf(0.0, 1.0 - y * y))
				o.boule(c + Vector3(cos(a) * rr, y * 0.92, sin(a) * rr) * R * 1.02, Vector3.ONE * 0.065 * k, Color("f08a1c").lightened(r.randf_range(-0.05, 0.1)), 0.0, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5 * k, 0)), Vector3(l, 1.0 * k, l)])
		return Vector2(h, R)

	static func cypres(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var vent := float(opt.get("vent", 1.0))
		var h := float(opt.get("hauteur", 8.0 * r.randf_range(0.88, 1.12)))
		var k := h / 8.0
		o.branche(p + Vector3(0, -0.2, 0), p + Vector3(0, 0.8, 0), 0.14 * k, 0.12 * k, Color("6e5040"), 6)
		# la flamme : des touffes serrées, un fuseau qui s'effile vers la pointe
		var n := 11
		for i in n:
			var f := float(i) / (n - 1)
			var rr := h * 0.12 * sin(PI * clampf(f * 0.85 + 0.12, 0.0, 1.0)) * (1.0 - f * 0.35) + 0.12
			var c := p + Vector3(r.randf_range(-0.05, 0.05), 0.7 + f * (h - 1.2), r.randf_range(-0.05, 0.05))
			o.boule(c, Vector3(rr, h * 0.09, rr), verts[clampi(int(f * 3.5 + r.randf_range(-0.5, 0.5)), 0, 3)].lightened(0.05 * (1.0 - f)), 0.14, Outils.FEUILLE, 0.05, vent * 0.25 * f)
		o.boule(p + Vector3(0, h - 0.25, 0), Vector3(0.18, 0.45, 0.18), verts[3], 0.1, Outils.FEUILLE, 0.04, vent * 0.3)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, h * 0.4, 0)), Vector3(h * 0.2, h * 0.8, h * 0.2)])
		return Vector2(h, h * 0.13)

	static func bac_fleuri(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var l := float(opt.get("longueur", 1.6))
		# un bac de bois à lattes sur pieds, débordant de fleurs mêlées et de retombées
		var bois := Color("8a5f32")
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				o.boite(Transform3D(Basis(), p + Vector3(cx * (l * 0.5 - 0.04), 0.25, cz * 0.24)), Vector3(0.08, 0.7, 0.08), bois.darkened(0.15))
		for i in 4:
			var y := 0.18 + i * 0.12
			o.boite(Transform3D(Basis(), p + Vector3(0, y, 0)), Vector3(l, 0.1, 0.5), bois.lightened(0.04 * (i % 2)))
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.62, 0)), Vector3(l + 0.06, 0.04, 0.56), bois.darkened(0.1))
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.6, 0)), Vector3(l - 0.08, 0.03, 0.42), TERRE)
		var n := int(l / 0.3)
		for i in n:
			var x := -l * 0.5 + 0.18 + i * (l - 0.36) / maxf(1, n - 1)
			var fleur := Color(str(opt.get("fleurs", FLEURS[r.randi() % FLEURS.size()])))
			_touffe(o, p + Vector3(x, 0.8, r.randf_range(-0.08, 0.08)), r.randf_range(0.2, 0.27), verts[r.randi() % 3], fleur, 7)
		for i in n:
			var x := -l * 0.5 + 0.2 + i * (l - 0.4) / maxf(1, n - 1)
			o.boule(p + Vector3(x, 0.45, 0.3), Vector3(0.1, 0.22, 0.08), verts[2], 0.25, Outils.FEUILLE, 0.05, 0.4)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.35, 0)), Vector3(l, 0.7, 0.55)])
		return Vector2(1.0, l * 0.5)

	static func vigne(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var vent := float(opt.get("vent", 1.0))
		var l := float(opt.get("longueur", 2.4))
		var h := float(opt.get("hauteur", 4.5))
		# le treillage de bois vert contre le mur, en losanges
		var tr := Color("3f5f46")
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.05, 0.25)), Vector3(l * 0.5, 0.2, 0.4), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.06, 0.25)), Vector3(l * 0.5 - 0.06, 0.04, 0.32), TERRE)
		var nx := maxi(2, int(l / 0.5))
		for i in nx + 1:
			var x := -l * 0.5 + i * l / nx
			o.boite(Transform3D(Basis(), p + Vector3(x, h * 0.5 + 0.15, 0.04)), Vector3(0.03, h - 0.3, 0.03), tr)
		var ny := maxi(2, int(h / 0.5))
		for i in ny + 1:
			var y := 0.3 + i * (h - 0.3) / ny
			o.boite(Transform3D(Basis(), p + Vector3(0, y, 0.07)), Vector3(l, 0.03, 0.03), tr)
		# le cep tortueux qui monte et ses sarments qui courent, chargés de feuilles et de grappes
		var cep := Color("6a4a32")
		var a := p + Vector3(0, 0.0, 0.25)
		var b := p + Vector3(r.randf_range(-0.2, 0.2), h * 0.45, 0.18)
		var c := p + Vector3(r.randf_range(-0.3, 0.3), h * 0.8, 0.15)
		o.branche(a, b, 0.07, 0.05, cep, 6)
		o.branche(b, c, 0.05, 0.035, cep, 6)
		for i in 5:
			var y := r.randf_range(0.35, 0.95) * h
			var cote := -1.0 if i % 2 == 0 else 1.0
			o.branche(p + Vector3(0, y, 0.18), p + Vector3(cote * l * r.randf_range(0.3, 0.48), y + r.randf_range(-0.3, 0.4), 0.15), 0.025, 0.015, cep, 4)
		var n := int(l * h * 3.2)
		for i in n:
			var y := sqrt(r.randf()) * 0.85 + 0.15
			var etal := l * 0.5 * (0.3 + 0.7 * y)
			var q := p + Vector3(r.randf_range(-etal, etal), y * h, r.randf_range(0.12, 0.28))
			o.boule(q, Vector3(r.randf_range(0.26, 0.38), r.randf_range(0.2, 0.3), 0.13), verts[r.randi() % 4], 0.25, Outils.FEUILLE, 0.06, vent * 0.4)
		for i in 6:
			var q := p + Vector3(r.randf_range(-l * 0.35, l * 0.35), r.randf_range(0.4, 0.8) * h, 0.32)
			o.cylindre(Transform3D(Basis(Vector3.RIGHT, PI), q), 0.08, 0.02, 0.22, 6, Color("5a3a6a"))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.1, 0.25)), Vector3(l * 0.5, 0.2, 0.4)])
		return Vector2(h, l * 0.5)

	static func massif(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var l := float(opt.get("longueur", 3.0))
		var fleur := Color(str(opt.get("fleurs", FLEURS[r.randi() % FLEURS.size()])))
		var fleur2 := Color(FLEURS[(FLEURS.find(fleur.to_html(false)) + 2 + r.randi() % 3) % FLEURS.size()])
		# une bordure de buis taillé autour d'un parterre : arbustes au fond, fleurs devant
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(0, 0.2, cote * 0.7)), Vector3(l, 0.38, 0.26), verts[2])
			o.boite(Transform3D(Basis(), p + Vector3(cote * l * 0.5, 0.2, 0)), Vector3(0.26, 0.38, 1.66), verts[2])
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.05, 0)), Vector3(l - 0.2, 0.12, 1.2), TERRE)
		var n := int(l / 0.5)
		for i in n:
			var x := -l * 0.5 + 0.35 + i * (l - 0.7) / maxf(1, n - 1)
			_masse(o, p + Vector3(x, 0.6, -0.3), Vector3(0.36, 0.42, 0.3), verts[r.randi() % 2 + 1], 0.3)
			_touffe(o, p + Vector3(x + r.randf_range(-0.1, 0.1), 0.38, 0.2), r.randf_range(0.22, 0.28), verts[0], fleur if i % 2 == 0 else fleur2, 7)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.3, 0)), Vector3(l, 0.6, 1.6)])
		return Vector2(0.9, l * 0.5)

	static func buisson(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var vent := float(opt.get("vent", 1.0))
		var h := float(opt.get("hauteur", 1.2 * r.randf_range(0.85, 1.15)))
		# trois à cinq boules mêlées, posées de travers, quelques fleurs blanches
		var n := 3 + r.randi() % 3
		var masses: Array = []
		for i in n:
			var a := TAU * i / n + r.randf()
			var d := r.randf_range(0.2, 0.55) * h
			var s := h * r.randf_range(0.45, 0.6)
			masses.append([p + Vector3(cos(a) * d, s * 0.8, sin(a) * d), Vector3(s, s * 0.85, s)])
			_masse(o, masses[i][0], masses[i][1], verts[r.randi() % 4], vent * 0.4)
		# les fleurs, sur le dessus des masses : toujours quand on les demande (fleurs), six fois sur dix sinon
		if opt.has("fleurs") or r.randf() < 0.6:
			var fleur := Color(str(opt.get("fleurs", ["f4f0e6", "f2c14e", "d04a8a"][r.randi() % 3])))
			for i in int(9 + h * 5):
				var m: Array = masses[r.randi() % n]
				_fleurs(o, m[0], m[1], fleur, 1, 0.07, vent * 0.4)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, h * 0.5, 0)), Vector3(h * 1.4, h, h * 1.4)])
		return Vector2(h, h * 0.9)

	## L'herbe : une nappe de touffes en cartes sur un fond de vert sombre, à la place d'un gazon en aplat. Le
	## contour : longueur × largeur (centré sur l'origine), ou points (en mètres). Chaque touffe est quatre brins
	## triangulaires écartés, sombres au pied et clairs à la pointe, qui frémissent au vent ; semées selon l'aire,
	## 45 par m² (densite) jusqu'au plafond, puis elles grossissent au lieu de se multiplier.
	static func herbe(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var vent := float(opt.get("vent", 1.0))
		var l := float(opt.get("longueur", 4.0))
		var w := float(opt.get("largeur", 2.0))
		var pts := PackedVector2Array()
		if opt.has("points") and opt["points"] is Array and (opt["points"] as Array).size() >= 3:
			for q in opt["points"]:
				pts.append(q if q is Vector2 else Vector2(float(q[0]), float(q[1])))
		else:
			pts = PackedVector2Array([Vector2(-l * 0.5, -w * 0.5), Vector2(l * 0.5, -w * 0.5), Vector2(l * 0.5, w * 0.5), Vector2(-l * 0.5, w * 0.5)])
		var mini := pts[0]
		var maxi := pts[0]
		var aire := 0.0
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			aire += a.x * b.y - b.x * a.y
			mini = Vector2(minf(mini.x, a.x), minf(mini.y, a.y))
			maxi = Vector2(maxf(maxi.x, a.x), maxf(maxi.y, a.y))
		aire = absf(aire) * 0.5
		# le fond : le contour en vert sombre, à peine au-dessus du sol
		var sol := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
		o.profil(Transform3D(sol, p), pts, -0.012, 0.0, (verts[3] as Color).darkened(0.25), Outils.DUR)
		var voulu := aire * 45.0 * float(opt.get("densite", 1.0))
		var n := mini(int(voulu), int(opt.get("plafond", 2500)))
		var grossir := clampf(sqrt(voulu / maxf(1.0, n)), 1.0, 1.6)
		var cadre := (maxi.x - mini.x) * (maxi.y - mini.y)
		var essais := 0
		var semees := 0
		var essais_max := n * 8 * int(clampf(cadre / maxf(aire, 0.1), 1.0, 50.0))
		while semees < n and essais < essais_max:
			essais += 1
			var q := Vector2(r.randf_range(mini.x, maxi.x), r.randf_range(mini.y, maxi.y))
			if not Geometry2D.is_point_in_polygon(q, pts):
				continue
			semees += 1
			var h := r.randf_range(0.09, 0.19) * grossir * float(opt.get("hauteur", 1.0))
			var pied_col: Color = verts[3]
			var pointe: Color = (verts[r.randi() % 2] as Color).lightened(r.randf_range(-0.05, 0.1))
			# quatre brins par touffe, écartés d'une dizaine de centimètres, penchés chacun à sa guise
			for brin in 4:
				var ecart := Vector2(r.randf_range(-0.1, 0.1), r.randf_range(-0.1, 0.1)) * grossir
				var pied := p + Vector3(q.x + ecart.x, 0.0, q.y + ecart.y)
				var a := TAU * brin / 4.0 + r.randf() * TAU
				var u := Vector3(cos(a), 0, sin(a))
				var hb := h * r.randf_range(0.7, 1.2)
				var larg := hb * r.randf_range(0.22, 0.32)
				var penche := Vector3(r.randf_range(-0.4, 0.4), 0, r.randf_range(-0.4, 0.4)) * hb
				var haut := pied + Vector3(0, hb, 0) + penche
				_brin(o, pied - u * larg * 0.5, pied + u * larg * 0.5, haut, u.cross(Vector3.UP), pied_col, pointe, vent)
		# pas d'obstacle : on marche dans l'herbe ; le corps, une plaque sous le sol, ne fait que tenir le contrat
		o.collisions.append([Transform3D(Basis(), p + Vector3((mini.x + maxi.x) * 0.5, -0.06, (mini.y + maxi.y) * 0.5)), Vector3(maxi.x - mini.x, 0.02, maxi.y - mini.y)])
		return Vector2(0.26, maxf(maxi.x - mini.x, maxi.y - mini.y) * 0.5)

	## Un brin d'herbe : un triangle du pied a-b à la pointe c, sombre au pied, clair à la pointe (la pointe seule
	## bouge au vent).
	static func _brin(o: Outils, a: Vector3, b: Vector3, c: Vector3, n: Vector3, pied: Color, pointe: Color, vent: float) -> void:
		var st := o._s(Outils.FEUILLE)
		var nn := n.normalized()
		var sommets := [[a, pied, 0.0], [b, pied, 0.0], [c, pointe, vent]]
		if (b - a).cross(c - a).dot(nn) > 0.0:
			sommets = [sommets[0], sommets[2], sommets[1]]
		for sommet in sommets:
			var col: Color = sommet[1]
			col.a = clampf(float(sommet[2]), 0.0, 1.0)
			st.set_color(col)
			st.set_normal(nn)
			st.add_vertex(sommet[0])
