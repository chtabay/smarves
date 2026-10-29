extends Node3D
## Un module des terrains du Bugey, posé tel quel : on règle module, graine et options avant de l'ajouter à la
## scène, il se bâtit à son entrée dans l'arbre de scène. Les modules se posent bout à bout sur une trame de 8 m :
## le sol est à y = 0, le module est centré sur l'origine, son devant (le parement d'un mur, le pied d'un coteau,
## la rive d'une rivière) regarde +Z ; un chemin, une route file le long de z, un mur et une rivière le long de x ;
## en mètres (une commune à l'échelle du village de Smarves, 1 unité = 2,4 m, la pose à l'échelle 1/2,4).
##   var m = load(Bibliotheque.scene("terrains-du-bugey@1", "decor")).instantiate()
##   m.module = "vigne_coteau" ; m.graine = 3
##   add_child(m)
## Après la construction, le nœud porte ses métadonnées : module, graine, emprise (Vector2, la taille au sol),
## haut (la hauteur atteinte : le haut du coteau, du talus, de la falaise ; 0 pour un sol).
const Outils := preload("res://bibliotheque/terrains-du-bugey/1/outils.gd")

## Les modules : la prairie fleurie, le champ de blé, le champ de maïs, la vigne en coteau sur ses terrasses, le
## chemin de terre, la route bordée de murets, le mur de pierre sèche, le talus rocheux calcaire, la rivière, et
## la falaise calcaire qui ferme l'horizon.
const MODULES := ["prairie", "ble", "mais", "vigne_coteau", "chemin", "route_murets", "mur_pierre_seche", "talus", "riviere", "falaise"]

const TRAME := 8.0
const HERBE := Color("8dbb4c")
const HERBE_SOMBRE := Color("6f9e3c")
const TERRE := Color("8a6a46")
const TERRE_CLAIRE := Color("b89a6a")
const CALCAIRE := Color("cdc5ae")
const CALCAIRE_SOMBRE := Color("a9a08a")
const MOELLON := Color("cfc09a")
const BLE := Color("d9b64a")
const VERT := Color("5f9e33")
const EAU := Color("5592ab")
const FLEURS := ["f4f0e6", "f2c14e", "b06ad0", "e0605a", "8a9ae0"]

## Le module (voir MODULES).
@export var module := "prairie"
## La graine : la place de chaque touffe, de chaque pierre, de chaque fleur.
@export var graine := 1
## Les options, toutes facultatives : largeur (le long du module, en mètres : 8 par défaut ; la falaise : 30),
## hauteur (le mur, le talus, la falaise), fleurs (faux : la prairie sans fleurs).
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


## Bâtit un module sous parent, centré en p. Rend module, graine, emprise, haut.
static func poser(parent: Node3D, p: Vector3, nom: String, g: int, opt := {}) -> Dictionary:
	if not nom in MODULES:
		nom = "prairie"
	var o := Outils.new(g * 15485863 + MODULES.find(nom) * 7)
	var mesures: Vector3 = Callable(_Modules, nom).call(o, p, opt)
	o.construire(parent, nom.capitalize())
	return {"module": nom, "graine": g, "emprise": Vector2(mesures.x, mesures.y), "haut": mesures.z}


class _Modules:
	## La dalle de terre du module, enterrée de 40 cm, son dessus (col) à y = 0 ; avec son corps de collision.
	static func _dalle(o: Outils, p: Vector3, l: float, d: float, col: Color) -> void:
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.2, 0)), Vector3(l, 0.4, d), [TERRE, TERRE, col, TERRE, TERRE, TERRE], Outils.DUR, true)

	## Des taches d'herbe plus claire et plus sombre sur le dessus d'un sol.
	static func _taches(o: Outils, p: Vector3, l: float, d: float, n: int, base: Color) -> void:
		var r := o.rng
		for i in n:
			var c := p + Vector3(r.randf_range(-l * 0.45, l * 0.45), 0.004 + i * 0.0004, r.randf_range(-d * 0.45, d * 0.45))
			var s := Vector2(r.randf_range(0.6, 1.6), r.randf_range(0.6, 1.6))
			var b := Basis(Vector3.UP, r.randf() * PI)
			o.quad(c + b * Vector3(-s.x, 0, -s.y), c + b * Vector3(s.x, 0, -s.y), c + b * Vector3(s.x, 0, s.y), c + b * Vector3(-s.x, 0, s.y), Vector3.UP, base.lightened(r.randf_range(-0.1, 0.1)))

	## Une touffe d'herbe, posée en c, de rayon s.
	static func _touffe(o: Outils, c: Vector3, s: float, col := HERBE_SOMBRE) -> void:
		o.boule(c + Vector3(0, s * 0.3, 0), Vector3(s, s * 0.6, s), col.lightened(o.rng.randf_range(-0.06, 0.08)), 0.35, Outils.FEUILLE, 0.1, 0.4)

	## Une pierre calcaire anguleuse : une boîte tournée au hasard, la face du dessus plus claire.
	static func _roche(o: Outils, c: Vector3, s: Vector3, col: Color) -> void:
		var r := o.rng
		var b := Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(-0.25, 0.25)) * Basis(Vector3.BACK, r.randf_range(-0.25, 0.25))
		var c2 := col.lightened(r.randf_range(-0.08, 0.06))
		o.boite(Transform3D(b, c), s, [c2.darkened(0.08), c2.darkened(0.12), c2.lightened(0.08), c2.darkened(0.3), c2, c2.darkened(0.15)])

	## Un mur de pierre sèche de a à b (au sol), haut de h, épais de e : des pierres plates empilées sans mortier, les
	## joints creux et sombres, le couronnement de pierres dressées.
	static func _pierre_seche(o: Outils, a: Vector3, b: Vector3, h: float, e: float) -> void:
		var r := o.rng
		var dir := b - a
		var l := dir.length()
		var bb := Basis(Vector3.UP, atan2(-dir.z, dir.x))
		var c := (a + b) * 0.5
		o.boite(Transform3D(bb, c + Vector3(0, h * 0.5 - 0.12, 0)), Vector3(l, h + 0.1, e - 0.08), Color("5a5246"), Outils.DUR, true)
		var y := -0.1
		while y < h - 0.3:
			var hh := r.randf_range(0.1, 0.22)
			var x := -l * 0.5
			while x < l * 0.5 - 0.08:
				var lx := minf(r.randf_range(0.2, 0.55), l * 0.5 - x)
				var col := CALCAIRE_SOMBRE.lightened(r.randf_range(-0.12, 0.14))
				if r.randf() < 0.15:
					col = col.lerp(Color("c9b48a"), 0.4)
				var recul := e * 0.5 * (1.0 - (y / h) * 0.12)
				for cote in [-1.0, 1.0]:
					o.boite(Transform3D(bb, c + bb * Vector3(x + lx * 0.5, y + hh * 0.5, cote * (recul - 0.06))), Vector3(lx - 0.03, hh - 0.025, 0.18 + r.randf_range(0.0, 0.08)), col)
				x += lx
			y += hh
		# le couronnement : des pierres de chant, serrées
		var x := -l * 0.5 + 0.06
		while x < l * 0.5 - 0.06:
			var lx := r.randf_range(0.08, 0.16)
			var hh := r.randf_range(0.26, 0.38)
			o.boite(Transform3D(bb * Basis(Vector3.BACK, r.randf_range(-0.12, 0.12)), c + bb * Vector3(x + lx * 0.5, h - 0.3 + hh * 0.5, 0)), Vector3(lx - 0.02, hh, e * 0.85), CALCAIRE_SOMBRE.lightened(r.randf_range(-0.1, 0.1)))
			x += lx

	## Un rang de vigne le long de x, de longueur l, le pied en c : les échalas, le fil, les ceps, les feuilles.
	static func _rang(o: Outils, c: Vector3, l: float) -> void:
		var r := o.rng
		var bois := Color("8a7458")
		o.branche(c + Vector3(-l * 0.5, 0.95, 0), c + Vector3(l * 0.5, 0.95, 0), 0.008, 0.008, Color("4a4a4a"), 3)
		var n := int(l / 0.9)
		for i in n:
			var x := -l * 0.5 + (i + 0.5) * l / n
			o.branche(c + Vector3(x + 0.1, -0.1, 0), c + Vector3(x + 0.1, 1.15, 0), 0.02, 0.02, bois, 4)
			o.branche(c + Vector3(x, -0.05, 0), c + Vector3(x + r.randf_range(-0.06, 0.06), 0.45, 0), 0.035, 0.03, Color("5a4434"), 5)
			# la haie de feuilles palissée, du cep au-dessus du fil
			for j in 8:
				o.boule(c + Vector3(x - 0.33 + (j % 4) * 0.22 + r.randf_range(-0.05, 0.05), 0.58 + (j / 4) * 0.36 + r.randf_range(-0.04, 0.06), r.randf_range(-0.03, 0.03)), Vector3(0.17, 0.2, 0.13), Color("7fb840").lightened(r.randf_range(-0.12, 0.1)), 0.3, Outils.FEUILLE, 0.1, 0.4)
			if r.randf() < 0.6:
				o.boule(c + Vector3(x + r.randf_range(-0.3, 0.3), 0.62, r.randf_range(-0.15, 0.15)), Vector3(0.07, 0.12, 0.07), Color("4a2e5a"), 0.3, Outils.FEUILLE, 0.05, 0.2)

	static func prairie(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("largeur", TRAME))
		_dalle(o, p, l, TRAME, HERBE)
		_taches(o, p, l, TRAME, 10, HERBE)
		for i in 40:
			_touffe(o, p + Vector3(r.randf_range(-l * 0.48, l * 0.48), 0, r.randf_range(-3.9, 3.9)), r.randf_range(0.12, 0.28), HERBE_SOMBRE if r.randf() < 0.5 else HERBE)
		if opt.get("fleurs", true):
			# les fleurs des champs, par plaques : marguerites, boutons-d'or, sauges, coquelicots, bleuets
			for k in 8:
				var cc := p + Vector3(r.randf_range(-l * 0.42, l * 0.42), 0, r.randf_range(-3.4, 3.4))
				var col := Color(FLEURS[r.randi() % FLEURS.size()])
				for i in 14:
					var q := cc + Vector3(r.randf_range(-0.9, 0.9), r.randf_range(0.12, 0.3), r.randf_range(-0.9, 0.9))
					o.branche(Vector3(q.x, 0, q.z), q, 0.008, 0.008, HERBE_SOMBRE, 3)
					o.boule(q, Vector3(0.05, 0.035, 0.05), col.lightened(r.randf_range(-0.05, 0.1)), 0.1, Outils.FEUILLE, 0.04, 0.6)
		return Vector3(l, TRAME, 0.0)

	static func ble(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("largeur", TRAME))
		_dalle(o, p, l, TRAME, TERRE.lightened(0.1))
		# les rangs de blé mûr, serrés, leurs épis ; des coquelicots et des bleuets en lisière
		var n := 15
		for i in n:
			var z := -TRAME * 0.5 + 0.3 + i * (TRAME - 0.6) / (n - 1)
			var hh := r.randf_range(0.8, 0.95)
			o.boite(Transform3D(Basis(), p + Vector3(0, hh * 0.5, z)), Vector3(l - 0.3, hh, 0.36), BLE.darkened(0.12), Outils.FEUILLE)
			var ne := int(l / 0.22)
			for k in ne:
				var x := -l * 0.5 + 0.2 + k * (l - 0.4) / ne
				o.boite(Transform3D(Basis(Vector3.BACK, r.randf_range(-0.2, 0.2)), p + Vector3(x, hh + 0.06, z + r.randf_range(-0.1, 0.1))), Vector3(0.08, 0.16, 0.08), BLE.lightened(r.randf_range(0.0, 0.15)), Outils.FEUILLE)
		for i in 18:
			var q := p + Vector3(r.randf_range(-l * 0.48, l * 0.48), r.randf_range(0.7, 1.0), TRAME * 0.5 - r.randf_range(0.05, 0.4))
			o.boule(q, Vector3(0.07, 0.05, 0.07), Color("d9302a") if r.randf() < 0.7 else Color("5a7ad0"), 0.1, Outils.FEUILLE, 0.04, 0.6)
		return Vector3(l, TRAME, 0.0)

	static func mais(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("largeur", TRAME))
		_dalle(o, p, l, TRAME, TERRE)
		# des rangs de maïs hauts : la tige, les longues feuilles arquées, l'épi dans sa gaine, la panicule
		var nz := 9
		var nx := int(l / 0.6)
		for i in nz:
			var z := -TRAME * 0.5 + 0.45 + i * (TRAME - 0.9) / (nz - 1)
			for k in nx:
				var x := -l * 0.5 + 0.3 + k * (l - 0.6) / (nx - 1) + r.randf_range(-0.08, 0.08)
				var h := r.randf_range(1.9, 2.4)
				var q := p + Vector3(x, 0, z)
				o.branche(q, q + Vector3(0, h, 0), 0.03, 0.02, Color("8aa84a"), 4)
				for j in 4:
					var a := r.randf() * TAU
					var y := h * (0.25 + j * 0.17)
					var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.9)
					o.boite(Transform3D(b, q + Vector3(0, y, 0) + b * Vector3(0, 0.32, 0)), Vector3(0.09, 0.7, 0.015), Color("6fa23a").lightened(r.randf_range(-0.06, 0.1)), Outils.FEUILLE)
				if r.randf() < 0.7:
					o.boule(q + Vector3(0.06, h * 0.55, 0), Vector3(0.05, 0.13, 0.05), Color("c9c46a"), 0.1, Outils.FEUILLE, 0.04, 0.3)
				o.boule(q + Vector3(0, h + 0.1, 0), Vector3(0.05, 0.14, 0.05), Color("c9a85a"), 0.2, Outils.FEUILLE, 0.05, 0.6)
		return Vector3(l, TRAME, 2.3)

	static func vigne_coteau(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("largeur", TRAME))
		var marche := 1.1
		var nt := 3
		var s := TRAME / nt
		# trois terrasses qui montent vers le fond, tenues par leurs murs de pierre sèche, deux rangs de vigne chacune
		for i in nt:
			var z1 := TRAME * 0.5 - i * s
			var z0 := z1 - s
			var y := i * marche
			o.boite(Transform3D(Basis(), p + Vector3(0, (y - 0.4) * 0.5, (z0 + z1) * 0.5)), Vector3(l, y + 0.4, s), [TERRE, TERRE, TERRE.lightened(0.12), TERRE, TERRE, TERRE], Outils.DUR, true)
			_taches(o, p + Vector3(0, y, (z0 + z1) * 0.5), l, s * 0.8, 3, HERBE.lerp(TERRE, 0.5))
			if i > 0:
				_pierre_seche(o, p + Vector3(-l * 0.5, (i - 1) * marche, z1 + 0.25), p + Vector3(l * 0.5, (i - 1) * marche, z1 + 0.25), marche + 0.25, 0.5)
			for k in 2:
				_rang(o, p + Vector3(0, y, z1 - s * (0.3 + k * 0.4)), l - 0.6)
			for k in 6:
				_touffe(o, p + Vector3(r.randf_range(-l * 0.48, l * 0.48), y, z1 - r.randf_range(0.1, s - 0.1)), r.randf_range(0.1, 0.2))
		return Vector3(l, TRAME, (nt - 1) * marche)

	static func chemin(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("largeur", TRAME))
		_dalle(o, p, l, TRAME, HERBE)
		_taches(o, p, l, TRAME, 6, HERBE)
		# la bande de terre battue qui file le long de z, ses deux ornières, l'herbe du milieu, les cailloux
		var lc := 2.6
		var n := 8
		for i in n:
			var z0 := -TRAME * 0.5 + i * TRAME / n
			var z1 := z0 + TRAME / n
			var dx0 := sin(z0 * 0.4 + 1.0) * 0.3
			var dx1 := sin(z1 * 0.4 + 1.0) * 0.3
			o.quad(p + Vector3(dx0 - lc * 0.5, 0.01, z0), p + Vector3(dx0 + lc * 0.5, 0.01, z0), p + Vector3(dx1 + lc * 0.5, 0.01, z1), p + Vector3(dx1 - lc * 0.5, 0.01, z1), Vector3.UP, TERRE_CLAIRE)
			for cote in [-1.0, 1.0]:
				o.quad(p + Vector3(dx0 + cote * 0.6 - 0.15, 0.014, z0), p + Vector3(dx0 + cote * 0.6 + 0.15, 0.014, z0), p + Vector3(dx1 + cote * 0.6 + 0.15, 0.014, z1), p + Vector3(dx1 + cote * 0.6 - 0.15, 0.014, z1), Vector3.UP, TERRE_CLAIRE.darkened(0.15))
			o.quad(p + Vector3(dx0 - 0.2, 0.016, z0), p + Vector3(dx0 + 0.2, 0.016, z0), p + Vector3(dx1 + 0.2, 0.016, z1), p + Vector3(dx1 - 0.2, 0.016, z1), Vector3.UP, HERBE.lerp(TERRE_CLAIRE, 0.4))
		for i in 26:
			var z := r.randf_range(-3.9, 3.9)
			var dx := sin(z * 0.4 + 1.0) * 0.3
			o.boule(p + Vector3(dx + r.randf_range(-1.2, 1.2), 0.02, z), Vector3(0.06, 0.04, 0.05) * r.randf_range(0.8, 1.6), CALCAIRE.darkened(r.randf_range(0.0, 0.2)), 0.2, Outils.DUR, 0.04)
		for i in 30:
			var z := r.randf_range(-3.9, 3.9)
			var dx := sin(z * 0.4 + 1.0) * 0.3
			var cote := -1.0 if r.randf() < 0.5 else 1.0
			_touffe(o, p + Vector3(dx + cote * r.randf_range(1.35, 2.2), 0, z), r.randf_range(0.12, 0.3))
		return Vector3(l, TRAME, 0.0)

	static func route_murets(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("largeur", TRAME))
		_dalle(o, p, l, TRAME, HERBE)
		# la route empierrée le long de z, son bombé de gravier, ses bas-côtés ; les deux murets de moellons qui la bordent
		var lr := 4.4
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.015, 0)), Vector3(lr, 0.03, TRAME), Color("a89c84"))
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.03, 0)), Vector3(lr - 1.4, 0.02, TRAME), Color("b3a78e"))
		for i in 60:
			o.boite(Transform3D(Basis(Vector3.UP, r.randf() * PI), p + Vector3(r.randf_range(-lr * 0.45, lr * 0.45), 0.04, r.randf_range(-3.9, 3.9))), Vector3(0.1, 0.02, 0.07), Color("a89c82").lightened(r.randf_range(-0.1, 0.1)))
		for cote in [-1.0, 1.0]:
			var x: float = cote * (lr * 0.5 + 0.55)
			var a := p + Vector3(x, 0, -TRAME * 0.5)
			var b := p + Vector3(x, 0, TRAME * 0.5)
			var dir := b - a
			var bb := Basis(Vector3.UP, atan2(-dir.z, dir.x))
			var c := (a + b) * 0.5
			o.boite(Transform3D(bb, c + Vector3(0, 0.4, 0)), Vector3(TRAME, 0.9, 0.42), MOELLON.darkened(0.15), Outils.DUR, true)
			var y := -0.02
			while y < 0.7:
				var hh := r.randf_range(0.16, 0.24)
				var z := -TRAME * 0.5
				while z < TRAME * 0.5 - 0.1:
					var lz := minf(r.randf_range(0.25, 0.6), TRAME * 0.5 - z)
					var col := MOELLON.lightened(r.randf_range(-0.12, 0.1))
					for s in [-1.0, 1.0]:
						o.boite(Transform3D(Basis(), p + Vector3(x + s * 0.22, y + hh * 0.5, z + lz * 0.5)), Vector3(0.04, hh - 0.04, lz - 0.04), col)
					z += lz
				y += hh
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.9, 0)), Vector3(0.54, 0.12, TRAME), CALCAIRE)
			for i in 8:
				_touffe(o, p + Vector3(x - cote * r.randf_range(0.35, 0.6), 0, r.randf_range(-3.8, 3.8)), r.randf_range(0.1, 0.22))
				_touffe(o, p + Vector3(x + cote * r.randf_range(0.35, 1.0), 0, r.randf_range(-3.8, 3.8)), r.randf_range(0.14, 0.3))
		return Vector3(l, TRAME, 0.0)

	static func mur_pierre_seche(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("largeur", TRAME))
		var h := float(opt.get("hauteur", 1.3))
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.15, 0)), Vector3(l, 0.3, 1.6), [TERRE, TERRE, HERBE, TERRE, TERRE, TERRE])
		_pierre_seche(o, p + Vector3(-l * 0.5, 0, 0), p + Vector3(l * 0.5, 0, 0), h, 0.7)
		for i in 16:
			var cote := -1.0 if r.randf() < 0.5 else 1.0
			_touffe(o, p + Vector3(r.randf_range(-l * 0.48, l * 0.48), 0, cote * r.randf_range(0.4, 0.7)), r.randf_range(0.12, 0.28))
		for i in 4:
			o.boule(p + Vector3(r.randf_range(-l * 0.4, l * 0.4), h - 0.05, 0), Vector3(0.35, 0.12, 0.3), Color("6f9a4a"), 0.3, Outils.FEUILLE, 0.08, 0.2)
		return Vector3(l, 1.6, h)

	static func talus(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("largeur", TRAME))
		var h := float(opt.get("hauteur", 3.2))
		_dalle(o, p, l, TRAME, HERBE)
		# le talus rocheux qui monte vers le fond : un cœur de terre, des blocs de calcaire anguleux, gris et blancs,
		# des buis et des touffes dans les fissures
		var coeur := PackedVector2Array([Vector2(-1.2, -0.1), Vector2(TRAME * 0.5, -0.1), Vector2(TRAME * 0.5, h * 0.85), Vector2(TRAME * 0.5 - 1.5, h * 0.9)])
		o.profil(Transform3D(Basis(Vector3.UP, PI * 0.5), p), coeur, -l * 0.5, l * 0.5, [TERRE, HERBE_SOMBRE.lerp(TERRE, 0.3)])
		for i in 34:
			var u := r.randf()
			var z := lerpf(1.0, -TRAME * 0.5 + 0.6, u)
			var y := lerpf(0.0, h * 0.75, u) + r.randf_range(-0.2, 0.3)
			var s := Vector3(r.randf_range(0.6, 1.6), r.randf_range(0.5, 1.3), r.randf_range(0.6, 1.4)) * lerpf(0.7, 1.2, u)
			_roche(o, p + Vector3(r.randf_range(-l * 0.48, l * 0.48), y, z), s, CALCAIRE if r.randf() < 0.6 else CALCAIRE_SOMBRE)
		for i in 10:
			_roche(o, p + Vector3(r.randf_range(-l * 0.45, l * 0.45), 0.1, r.randf_range(1.2, 3.5)), Vector3(0.4, 0.3, 0.35) * r.randf_range(0.7, 1.3), CALCAIRE)
		for i in 16:
			var u := r.randf()
			var z := lerpf(1.2, -TRAME * 0.5 + 0.5, u)
			o.boule(p + Vector3(r.randf_range(-l * 0.48, l * 0.48), lerpf(0.0, h * 0.8, u) + 0.3, z), Vector3(0.45, 0.35, 0.45) * r.randf_range(0.6, 1.3), Color("4f7a36").lightened(r.randf_range(-0.05, 0.1)), 0.3, Outils.FEUILLE, 0.08, 0.3)
		for i in 20:
			_touffe(o, p + Vector3(r.randf_range(-l * 0.48, l * 0.48), 0, r.randf_range(0.8, 3.9)), r.randf_range(0.12, 0.28))
		return Vector3(l, TRAME, h)

	static func riviere(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("largeur", TRAME))
		var lit := -0.9
		var bord := 2.7
		var fond := 1.7
		# les deux berges d'herbe, leurs pentes de terre et de galets, le lit, l'eau claire qui court le long de x
		for cote in [-1.0, 1.0]:
			var zc: float = cote * (bord + (TRAME * 0.5 - bord) * 0.5)
			o.boite(Transform3D(Basis(), p + Vector3(0, -0.2, zc)), Vector3(l, 0.4, TRAME * 0.5 - bord), [TERRE, TERRE, HERBE, TERRE, TERRE, TERRE], Outils.DUR, true)
			var a := p + Vector3(-l * 0.5, 0.0, cote * bord)
			var b := p + Vector3(l * 0.5, 0.0, cote * bord)
			var c := p + Vector3(l * 0.5, lit, cote * fond)
			var d := p + Vector3(-l * 0.5, lit, cote * fond)
			o.quad(a, b, c, d, Vector3(0, 1, cote * -1.0), TERRE.lerp(HERBE_SOMBRE, 0.3))
			for i in 18:
				var t := r.randf()
				o.boule(p + Vector3(r.randf_range(-l * 0.48, l * 0.48), lerpf(0.0, lit, t) + 0.02, cote * lerpf(bord, fond, t)), Vector3(0.14, 0.08, 0.12) * r.randf_range(0.7, 1.8), CALCAIRE.darkened(r.randf_range(0.0, 0.25)), 0.2, Outils.DUR, 0.04)
			# les roseaux et les iris le long de l'eau
			for i in 10:
				var q := p + Vector3(r.randf_range(-l * 0.48, l * 0.48), lit + 0.3, cote * r.randf_range(fond + 0.1, fond + 0.5))
				for k in 5:
					var top := q + Vector3(r.randf_range(-0.15, 0.15), r.randf_range(0.6, 1.2), r.randf_range(-0.1, 0.1))
					o.branche(q - Vector3(0, 0.3, 0), top, 0.015, 0.006, Color("7a9a3a"), 3)
				if r.randf() < 0.4:
					o.boule(q + Vector3(0, 0.9, 0), Vector3(0.04, 0.14, 0.04), Color("6a4a30"), 0.1, Outils.FEUILLE, 0.03, 0.5)
			for i in 10:
				_touffe(o, p + Vector3(r.randf_range(-l * 0.48, l * 0.48), 0, cote * r.randf_range(bord + 0.1, TRAME * 0.5 - 0.2)), r.randf_range(0.14, 0.3))
		o.boite(Transform3D(Basis(), p + Vector3(0, lit - 0.2, 0)), Vector3(l, 0.4, fond * 2.0 + 0.2), Color("7a6a50"))
		o.boite(Transform3D(Basis(), p + Vector3(0, lit + 0.32, 0)), Vector3(l, 0.04, (fond + 0.35) * 2.0), EAU)
		# quelques rochers qui affleurent, l'écume à leur pied
		for i in 4:
			var q := p + Vector3(r.randf_range(-l * 0.4, l * 0.4), lit + 0.2, r.randf_range(-1.2, 1.2))
			_roche(o, q, Vector3(0.6, 0.5, 0.5) * r.randf_range(0.6, 1.2), CALCAIRE_SOMBRE)
			o.boule(q + Vector3(0, 0.14, 0), Vector3(0.45, 0.03, 0.38), Color("e6f2f4"), 0.2, Outils.DUR, 0.02)
		return Vector3(l, TRAME, 0.0)

	static func falaise(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("largeur", 30.0))
		var h := float(opt.get("hauteur", 22.0))
		# la falaise calcaire du Bugey : de hauts piliers de roche claire en gradins, striés, des vires où s'accrochent
		# les buis et les pins, l'éboulis au pied, la forêt sur la crête
		o.boite(Transform3D(Basis(), p + Vector3(0, h * 0.45, -5.0)), Vector3(l, h * 0.9 + 1.0, 6.0), CALCAIRE_SOMBRE.darkened(0.1), Outils.DUR, true)
		var x := -l * 0.5
		while x < l * 0.5 - 0.5:
			var lw := minf(r.randf_range(1.6, 3.8), l * 0.5 - x)
			var hh := h * r.randf_range(0.6, 1.0)
			var avance := r.randf_range(-1.2, 1.0)
			var col := CALCAIRE.lerp(Color("b4ab94"), r.randf_range(0.0, 0.5))
			if r.randf() < 0.3:
				col = col.lerp(Color("c2ae88"), 0.35)
			var penche := Basis(Vector3.BACK, r.randf_range(-0.04, 0.04)) * Basis(Vector3.RIGHT, r.randf_range(-0.06, 0.02))
			o.boite(Transform3D(penche, p + Vector3(x + lw * 0.5, hh * 0.5 - 0.5, -2.0 + avance)), Vector3(lw + 0.1, hh + 1.0, 2.2), [col.darkened(0.15), col.darkened(0.22), col.lightened(0.04), col, col, col])
			# les bancs de la roche : des assises horizontales qui débordent ou rentrent
			var yb := r.randf_range(0.5, 2.0)
			while yb < hh - 1.0:
				var eb := r.randf_range(0.6, 1.8)
				o.boite(Transform3D(penche, p + Vector3(x + lw * 0.5, yb + eb * 0.5, -0.86 + avance + r.randf_range(-0.12, 0.1))), Vector3(lw + r.randf_range(-0.3, 0.2), eb - 0.08, 0.3), col.lightened(r.randf_range(-0.1, 0.06)))
				yb += eb
			# les stries verticales, plus sombres, et les vires horizontales
			for k in 2 + r.randi() % 3:
				var xs := x + r.randf_range(0.2, lw - 0.2)
				var hs := hh * r.randf_range(0.3, 0.8)
				o.boite(Transform3D(Basis(), p + Vector3(xs, hh - hs * 0.5 - r.randf_range(0.0, 2.0), -0.88 + avance)), Vector3(r.randf_range(0.06, 0.18), hs, 0.04), col.darkened(r.randf_range(0.15, 0.3)))
			for k in 2:
				var yv := hh * r.randf_range(0.25, 0.85)
				o.boite(Transform3D(Basis(), p + Vector3(x + lw * 0.5, yv, -0.8 + avance)), Vector3(lw * r.randf_range(0.5, 0.95), 0.18, 0.3), col.lightened(0.08))
				if r.randf() < 0.55:
					o.boule(p + Vector3(x + lw * r.randf_range(0.3, 0.7), yv + 0.35, -0.65 + avance), Vector3(0.6, 0.4, 0.4), Color("4f7a36").lightened(r.randf_range(-0.05, 0.08)), 0.3, Outils.FEUILLE, 0.08, 0.2)
			# la crête boisée
			for k in 2:
				var q := p + Vector3(x + lw * r.randf_range(0.2, 0.8), hh - 0.3, -2.5 + avance)
				o.boule(q + Vector3(0, 1.4, 0), Vector3(1.6, 1.5, 1.6) * r.randf_range(0.8, 1.3), Color("4f7f36").lightened(r.randf_range(-0.06, 0.1)), 0.25, Outils.FEUILLE, 0.08, 0.2)
			x += lw
		# l'éboulis au pied, et la pente d'herbe
		o.boite(Transform3D(Basis(Vector3.RIGHT, -0.5), p + Vector3(0, 0.6, 0.5)), Vector3(l, 0.4, 4.0), HERBE_SOMBRE.lerp(CALCAIRE_SOMBRE, 0.35))
		for i in int(l * 1.2):
			_roche(o, p + Vector3(r.randf_range(-l * 0.5, l * 0.5), r.randf_range(0.0, 1.0), r.randf_range(-0.6, 2.4)), Vector3(0.5, 0.4, 0.45) * r.randf_range(0.6, 1.8), CALCAIRE if r.randf() < 0.6 else CALCAIRE_SOMBRE)
		for i in int(l * 0.4):
			o.boule(p + Vector3(r.randf_range(-l * 0.5, l * 0.5), 0.6, r.randf_range(0.4, 2.6)), Vector3(0.7, 0.5, 0.7) * r.randf_range(0.6, 1.4), Color("5a8a3a").lightened(r.randf_range(-0.05, 0.1)), 0.3, Outils.FEUILLE, 0.08, 0.3)
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.2, -1.0)), Vector3(l, 0.4, 8.0), TERRE)
		return Vector3(l, 8.0, h)
