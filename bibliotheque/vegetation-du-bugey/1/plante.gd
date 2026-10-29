extends Node3D
## Une plante du décor du Bugey, posée telle quelle : on règle plante, graine et options avant de l'ajouter à la
## scène, elle se bâtit à son entrée dans l'arbre de scène. Le pied est à l'origine, sur un sol plat à y = 0 ; une
## rangée (la haie, la vigne) file le long de x ; en mètres (une commune à l'échelle du village de Smarves, 1 unité
## = 2,4 m, la pose à l'échelle 1/2,4).
##   var v = load(Bibliotheque.scene("vegetation-du-bugey@1", "decor")).instantiate()
##   v.plante = "chene" ; v.graine = 7
##   add_child(v)
## Après la construction, le nœud porte ses métadonnées : plante, graine, hauteur, couronne (le rayon de la
## couronne, pour espacer une rangée).
## Ces essences complètent celles des autres briques sans les doubler : le tilleul et le bouleau de la place sont
## dans arbres-de-place@1, le cyprès et la vigne grimpante dans vegetation-lyonnaise@1 ; une scène du Bugey les y
## prend.
const Outils := preload("res://bibliotheque/vegetation-du-bugey/1/outils.gd")

## Les plantes : le chêne, le charme, le cerisier (en fleurs ou en fruits), le cèdre, la haie basse taillée,
## l'arbuste fleuri, le rang de vigne sur ses échalas et les fleurs de village en pots.
const PLANTES := ["chene", "charme", "cerisier", "cedre", "haie", "arbuste_fleuri", "vigne_rang", "fleurs"]

const VERTS := {
	"chene": ["7fae45", "6a9a3a", "577f30", "456a28"],
	"charme": ["9ccc52", "86b845", "6fa23a", "5a8a30"],
	"cerisier": ["8cc04a", "78ac3e", "639634", "50802b"],
	"cedre": ["7fa276", "6a9064", "587e54", "486c46"],
	"haie": ["6aa83c", "5a9634", "4c842e", "3f7228"],
	"arbuste_fleuri": ["7cba42", "68a638", "579230", "487e2a"],
	"vigne_rang": ["8cc646", "76b23a", "5f9a30", "4f8a2a"],
	"fleurs": ["7cc23c", "69b032", "5a9c30", "4b8a2a"],
}
const FLEURS := ["e0605a", "f2c14e", "d04a8a", "b06ad0", "f4f0e6", "e8823a", "8a6ad0"]
const TERRE := Color("6b4f36")
const TERRE_CUITE := Color("b8643f")

## La plante (voir PLANTES).
@export var plante := "chene"
## La graine : deux plantes de même nom et de graines différentes ne se ressemblent pas.
@export var graine := 1
## Les options, toutes facultatives : hauteur (en mètres), fleurs (un hexa : l'arbuste, les fleurs), longueur (la
## haie, le rang de vigne), vent (0 à 1, l'amplitude du souffle), saison (le cerisier : « fleurs » ou « fruits »),
## raisin (false : la vigne sans ses grappes).
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
		nom = "chene"
	var o := Outils.new(g * 7919 + PLANTES.find(nom) * 17)
	var verts: Array = VERTS[nom].map(func(h): return Color(h))
	var mesures: Vector2 = Callable(_Plantes, nom).call(o, p, verts, opt)
	o.construire(parent, nom.capitalize())
	return {"plante": nom, "graine": g, "hauteur": mesures.x, "couronne": mesures.y}


class _Plantes:
	## Une touffe de feuilles semée de fleurs, centrée en c, de rayon r.
	static func _touffe(o: Outils, c: Vector3, r: float, vert: Color, fleur: Color, n_fleurs := 6) -> void:
		o.boule(c, Vector3(r, r * 0.75, r), vert, 0.22, Outils.FEUILLE, 0.06, 0.3)
		for i in n_fleurs:
			var a := o.rng.randf() * TAU
			var y := o.rng.randf_range(0.1, 0.7)
			var d := Vector3(cos(a) * sqrt(1.0 - y * y), y, sin(a) * sqrt(1.0 - y * y))
			o.boule(c + Vector3(d.x * r, d.y * r * 0.75, d.z * r) * 0.92, Vector3.ONE * r * 0.22, fleur.lightened(o.rng.randf_range(-0.08, 0.1)), 0.2, Outils.FEUILLE, 0.05, 0.3)

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

	static func chene(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var vent := float(opt.get("vent", 0.7))
		var h := float(opt.get("hauteur", 11.0 * r.randf_range(0.9, 1.1)))
		var k := h / 11.0
		var fut := h * 0.3
		var rt := 0.36 * k
		var ec := Color("6e5e4c")
		# le fût court et massif, l'empattement, l'écorce crevassée
		o.branche(p + Vector3(0, -0.3, 0), p + Vector3(0.15 * k, fut, 0), rt * 1.2, rt, ec, 10)
		o.cylindre(Transform3D(Basis(), p + Vector3(0, -0.1, 0)), rt * 1.9, rt * 1.2, 0.6, 10, ec.darkened(0.1), Outils.DUR, false)
		for i in 12:
			var a := r.randf() * TAU
			var y := r.randf_range(0.2, fut - 0.2)
			var b := Basis(Vector3.UP, a)
			o.boite(Transform3D(b, p + Vector3(0, y, 0) + b * Vector3(0, 0, rt * 1.05)), Vector3(0.05, r.randf_range(0.5, 1.2), 0.04), ec.darkened(0.25))
		# les charpentières tortueuses qui partent presque à l'horizontale, chacune sous une masse de feuillage
		var n := 4 + r.randi() % 2
		var cimes := []
		for i in n:
			var a := TAU * i / n + r.randf_range(-0.3, 0.3)
			var d := Vector3(cos(a), 0, sin(a))
			var m := p + Vector3(0, fut + h * 0.12, 0) + d * h * 0.18
			var bout := p + Vector3(0, fut + h * r.randf_range(0.3, 0.45), 0) + d * h * r.randf_range(0.28, 0.38)
			o.branche(p + Vector3(0, fut - 0.2, 0), m, rt * 0.7, rt * 0.5, ec, 7)
			o.branche(m, bout, rt * 0.5, rt * 0.18, ec.lightened(0.05), 6)
			cimes.append(bout)
		var R := Vector3(h * 0.42, h * 0.3, h * 0.42)
		var c := p + Vector3(0, fut + R.y * 1.05, 0)
		o.boule(c, R * 0.75, verts[3], 0.12, Outils.FEUILLE, 0.04, vent * 0.4)
		for q in cimes:
			var cq: Vector3 = q
			_couronne(o, cq + Vector3(0, h * 0.04, 0), Vector3(h * 0.2, h * 0.15, h * 0.2), verts, 5, vent, Vector2(0.5, 0.7))
		_couronne(o, c + Vector3(0, R.y * 0.3, 0), R * 0.7, verts, 8, vent, Vector2(0.4, 0.55))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.5, 0)), Vector3(0.9, 3.0, 0.9) * k])
		return Vector2(h, R.x)

	static func charme(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var vent := float(opt.get("vent", 0.8))
		var h := float(opt.get("hauteur", 9.0 * r.randf_range(0.92, 1.08)))
		var k := h / 9.0
		var fut := h * 0.22
		var rt := 0.17 * k
		var ec := Color("a7a59a")
		# le tronc gris, lisse et cannelé, la couronne ovoïde, dense, d'un vert tendre
		o.branche(p + Vector3(0, -0.2, 0), p + Vector3(0, fut + h * 0.3, 0), rt * 1.2, rt * 0.6, ec, 8)
		for i in 5:
			var a := TAU * i / 5.0
			o.branche(p + Vector3(cos(a) * rt, 0, sin(a) * rt), p + Vector3(cos(a) * rt * 0.6, fut, sin(a) * rt * 0.6), 0.04 * k, 0.03 * k, ec.darkened(0.08), 4)
		var R := Vector3(h * 0.26, h * 0.4, h * 0.26)
		var c := p + Vector3(0, fut + R.y * 0.95, 0)
		for i in 5:
			var a := TAU * i / 5.0 + r.randf() * 0.5
			o.branche(p + Vector3(0, fut, 0), c + Vector3(cos(a) * R.x * 0.45, r.randf_range(-0.3, 0.5) * R.y, sin(a) * R.z * 0.45), rt * 0.6, rt * 0.2, ec, 5)
		_couronne(o, c, R, verts, 20 + r.randi() % 5, vent, Vector2(0.3, 0.42))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.2, 0)), Vector3(0.45, 2.4, 0.45) * k])
		return Vector2(h, R.x)

	static func cerisier(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var vent := float(opt.get("vent", 0.8))
		var h := float(opt.get("hauteur", 5.5 * r.randf_range(0.9, 1.1)))
		var k := h / 5.5
		var fleurs := str(opt.get("saison", "fleurs" if r.randf() < 0.5 else "fruits")) == "fleurs"
		var fut := h * 0.3
		var rt := 0.12 * k
		var ec := Color("6a3f34")
		# le tronc brun rouge cerclé de lenticelles, trois branches en coupe, la couronne arrondie et basse
		o.branche(p + Vector3(0, -0.2, 0), p + Vector3(0, fut, 0), rt * 1.2, rt, ec, 8)
		for i in 6:
			o.cylindre(Transform3D(Basis(), p + Vector3(0, 0.3 + i * fut / 7.0, 0)), rt * 1.12, rt * 1.12, 0.03, 8, ec.lightened(0.2), Outils.DUR, false)
		var R := Vector3(h * 0.4, h * 0.3, h * 0.4)
		var c := p + Vector3(0, fut + R.y * 0.9, 0)
		for i in 3:
			var a := TAU * i / 3.0 + r.randf() * 0.5
			o.branche(p + Vector3(0, fut - 0.1, 0), c + Vector3(cos(a) * R.x * 0.6, r.randf_range(-0.1, 0.4) * R.y, sin(a) * R.z * 0.6), rt * 0.75, rt * 0.25, ec, 6)
		var vs := verts
		if fleurs:
			vs = [Color("fbe6ee"), Color("f6d0dc"), Color("eab8c8"), Color("d9a0b4")]
		_couronne(o, c, R, vs, 16 + r.randi() % 4, vent, Vector2(0.32, 0.46))
		if not fleurs:
			for i in 26:
				var y := r.randf_range(-0.4, 0.9)
				var a := r.randf() * TAU
				var rr := sqrt(maxf(0.0, 1.0 - y * y))
				o.boule(c + Vector3(cos(a) * rr * R.x, y * R.y, sin(a) * rr * R.z) * 0.95, Vector3.ONE * 0.07, Color("c0222c"), 0.0, Outils.FEUILLE, 0.05, vent)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.9, 0)), Vector3(0.3, 1.8, 0.3) * k])
		return Vector2(h, R.x)

	static func cedre(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var vent := float(opt.get("vent", 0.35))
		var h := float(opt.get("hauteur", 13.0 * r.randf_range(0.9, 1.1)))
		var k := h / 13.0
		var ec := Color("6a4c3a")
		# le tronc droit jusqu'à la flèche, des étages de rameaux en cônes aplatis, bleutés, de plus en plus petits
		o.branche(p + Vector3(0, -0.2, 0), p + Vector3(0, h * 0.92, 0), 0.3 * k, 0.05 * k, ec, 8)
		var etages := 6
		var R0 := h * 0.24
		for i in etages:
			var f := float(i) / etages
			var y := h * (0.18 + f * 0.7)
			var rr := R0 * (1.0 - f * 0.78) * r.randf_range(0.92, 1.08)
			var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU), p + Vector3(0, y, 0))
			# un plateau de rameaux : le dessous sombre, le dessus en coussins clairs qui débordent
			o.cylindre(t, rr, rr * 0.35, h * 0.07, 9, verts[3], Outils.FEUILLE, true)
			for j in 7:
				var a := TAU * j / 7.0 + r.randf() * 0.4
				o.boule(p + Vector3(cos(a) * rr * 0.72, y + h * 0.065, sin(a) * rr * 0.72), Vector3(rr * 0.34, h * 0.03, rr * 0.34), verts[clampi(1 - i / 4, 0, 3)].lightened(r.randf_range(-0.04, 0.06)), 0.25, Outils.FEUILLE, 0.05, vent)
			o.boule(p + Vector3(0, y + h * 0.07, 0), Vector3(rr * 0.5, h * 0.035, rr * 0.5), verts[1], 0.2, Outils.FEUILLE, 0.05, vent)
		o.cylindre(Transform3D(Basis(), p + Vector3(0, h * 0.86, 0)), h * 0.05, 0.0, h * 0.16, 8, verts[0], Outils.FEUILLE, true)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.4, 0)), Vector3(0.7, 2.8, 0.7) * k])
		return Vector2(h, R0)

	static func haie(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var l := float(opt.get("longueur", 3.0))
		var h := float(opt.get("hauteur", 1.1))
		# la haie basse taillée au carré : un cœur sombre, des touffes serrées qui débordent un peu, le dessus clair
		o.boite(Transform3D(Basis(), p + Vector3(0, h * 0.48, 0)), Vector3(l - 0.1, h * 0.92, 0.7), verts[3], Outils.FEUILLE)
		var n := int(l / 0.35)
		for i in n:
			var x := -l * 0.5 + (i + 0.5) * l / n
			for cote in [-1.0, 1.0]:
				o.boule(p + Vector3(x, h * r.randf_range(0.35, 0.6), cote * 0.32), Vector3(0.28, h * 0.42, 0.14), verts[2 if r.randf() < 0.5 else 1], 0.25, Outils.FEUILLE, 0.08, 0.2)
			o.boule(p + Vector3(x, h * 0.9, 0), Vector3(0.28, 0.14, 0.36), verts[0].lightened(r.randf_range(-0.04, 0.06)), 0.25, Outils.FEUILLE, 0.08, 0.2)
		o.boule(p + Vector3(0, -0.05, 0), Vector3(l * 0.5, 0.08, 0.35), TERRE, 0.1, Outils.DUR, 0.04)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, h * 0.5, 0)), Vector3(l, h, 0.7)])
		return Vector2(h, l * 0.5)

	static func arbuste_fleuri(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var h := float(opt.get("hauteur", 1.6 * r.randf_range(0.9, 1.15)))
		var fleur := Color(str(opt.get("fleurs", ["d04a8a", "b06ad0", "f4f0e6", "e0605a", "8a6ad0"][r.randi() % 5])))
		# l'arbuste en touffe ronde (le lilas, l'hortensia) : quelques tiges, des boules de feuilles, les grappes
		for i in 4:
			var a := TAU * i / 4.0
			o.branche(p + Vector3(0, -0.1, 0), p + Vector3(cos(a) * h * 0.2, h * 0.5, sin(a) * h * 0.2), 0.03, 0.02, Color("6a5a48"), 4)
		var R := Vector3(h * 0.55, h * 0.45, h * 0.55)
		var c := p + Vector3(0, h * 0.5, 0)
		_couronne(o, c, R, verts, 10, 0.4, Vector2(0.4, 0.55))
		for i in 18:
			var y := r.randf_range(-0.2, 1.0)
			var a := r.randf() * TAU
			var rr := sqrt(maxf(0.0, 1.0 - y * y))
			o.boule(c + Vector3(cos(a) * rr * R.x, y * R.y, sin(a) * rr * R.z) * 0.92, Vector3(0.14, 0.16, 0.14) * (h / 1.6), fleur.lightened(r.randf_range(-0.1, 0.12)), 0.25, Outils.FEUILLE, 0.06, 0.3)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, h * 0.4, 0)), Vector3(h * 0.8, h * 0.8, h * 0.8)])
		return Vector2(h, R.x)

	static func vigne_rang(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var l := float(opt.get("longueur", 6.0))
		var raisin: bool = opt.get("raisin", true)
		var bois := Color("8a7458")
		# le rang palissé : les piquets de tête, les échalas, deux fils de fer ; les ceps tordus, la feuille, les grappes
		for cote in [-1.0, 1.0]:
			o.branche(p + Vector3(cote * l * 0.5, -0.3, 0), p + Vector3(cote * l * 0.5, 1.5, 0), 0.06, 0.05, bois, 6)
		for y in [0.75, 1.25]:
			o.branche(p + Vector3(-l * 0.5, y, 0), p + Vector3(l * 0.5, y, 0), 0.008, 0.008, Color("4a4a4a"), 3)
		var n := int(l / 1.0)
		for i in n:
			var x := -l * 0.5 + (i + 0.5) * l / n
			o.branche(p + Vector3(x + 0.12, -0.2, 0), p + Vector3(x + 0.12, 1.35, 0), 0.02, 0.02, bois.lightened(0.1), 4)
			var tete := p + Vector3(x + r.randf_range(-0.06, 0.06), 0.55, 0)
			o.branche(p + Vector3(x, -0.1, 0), tete, 0.04, 0.035, Color("5a4434"), 5)
			for cote in [-1.0, 1.0]:
				o.branche(tete, tete + Vector3(cote * 0.45, 0.12, 0), 0.03, 0.02, Color("5a4434"), 4)
			for j in 8:
				o.boule(p + Vector3(x - 0.36 + (j % 4) * 0.24 + r.randf_range(-0.05, 0.05), 0.7 + (j / 4) * 0.4 + r.randf_range(-0.05, 0.08), r.randf_range(-0.04, 0.04)), Vector3(0.18, 0.22, 0.14), verts[r.randi() % 3].lightened(r.randf_range(-0.04, 0.08)), 0.3, Outils.FEUILLE, 0.1, 0.4)
			if raisin:
				for j in 2:
					var q := p + Vector3(x + r.randf_range(-0.35, 0.35), 0.72, r.randf_range(-0.2, 0.2))
					var noir := r.randf() < 0.6
					o.boule(q, Vector3(0.08, 0.14, 0.08), Color("4a2e5a") if noir else Color("c8c860"), 0.3, Outils.FEUILLE, 0.05, 0.2)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.6, 0)), Vector3(l, 1.2, 0.3)])
		return Vector2(1.5, l * 0.5)

	static func fleurs(o: Outils, p: Vector3, verts: Array, opt: Dictionary) -> Vector2:
		var r := o.rng
		var fleur := Color(str(opt.get("fleurs", FLEURS[r.randi() % FLEURS.size()])))
		# les fleurs de village : trois pots de terre cuite et une caisse de bois, géraniums, marguerites, lavande
		var pots := [[Vector3(-0.45, 0, 0.1), 0.24], [Vector3(0.05, 0, -0.15), 0.3], [Vector3(0.5, 0, 0.15), 0.2]]
		for q in pots:
			var c: Vector3 = p + q[0]
			var rr: float = q[1]
			o.cylindre(Transform3D(Basis(), c + Vector3(0, -0.04, 0)), rr * 0.75, rr, rr * 1.5, 10, TERRE_CUITE.lightened(r.randf_range(-0.06, 0.06)))
			o.anneau(Transform3D(Basis(), c + Vector3(0, rr * 1.4, 0)), rr * 0.95, rr * 1.08, 0.06, 10, TERRE_CUITE.darkened(0.1))
			var col := fleur if r.randf() < 0.5 else Color(FLEURS[r.randi() % FLEURS.size()])
			_touffe(o, c + Vector3(0, rr * 1.6 + rr * 0.4, 0), rr * 1.1, verts[r.randi() % 3], col, 8)
		# la caisse de lavande
		var cb := p + Vector3(-0.1, 0, 0.6)
		o.boite(Transform3D(Basis(), cb + Vector3(0, 0.15, 0)), Vector3(0.9, 0.3, 0.32), Color("9a6a3e"))
		for i in 7:
			var x := -0.38 + i * 0.127
			o.boule(cb + Vector3(x, 0.38, 0), Vector3(0.08, 0.12, 0.08), verts[2], 0.25, Outils.FEUILLE, 0.05, 0.3)
			for j in 3:
				var q := cb + Vector3(x + r.randf_range(-0.05, 0.05), 0.5 + j * 0.06, r.randf_range(-0.06, 0.06))
				o.boule(q, Vector3(0.025, 0.08, 0.025), Color("8a6ad0").lightened(r.randf_range(-0.05, 0.1)), 0.1, Outils.FEUILLE, 0.04, 0.5)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.25, 0.15)), Vector3(1.4, 0.5, 1.0)])
		return Vector2(0.9, 0.8)
