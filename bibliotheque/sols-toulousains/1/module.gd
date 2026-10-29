extends Node3D
## Un module des sols des places toulousaines, posé tel quel : on règle module, graine et options avant de
## l'ajouter à la scène, il se bâtit à son entrée dans l'arbre de scène. Les modules se posent bout à bout sur
## une trame de 4 m : le sol de la place est à y = 0, le module est centré sur l'origine, son devant (le
## parement d'un muret, le pied d'un emmarchement, la bordure du trottoir) regarde +Z ; en mètres (une commune à
## l'échelle du village de Smarves, 1 unité = 2,4 m, la pose à l'échelle 1/2,4).
##   var m = load(Bibliotheque.scene("sols-toulousains@1", "decor")).instantiate()
##   m.module = "brique_epi" ; m.graine = 3
##   add_child(m)
## Après la construction, le nœud porte ses métadonnées : module, graine, emprise (Vector2, la taille au sol),
## haut (la hauteur du dessus du module : 0 pour un sol, le haut d'un emmarchement ou d'un muret).
## Palette des planches de la place Saint-Georges : la brique rose des pavages, la pierre claire des bordures.
const Outils := preload("res://bibliotheque/sols-toulousains/1/outils.gd")

## Les modules : la brique rose posée en épi (le grand tapis de la place), la brique en rangs (la variante des
## terrasses), les dalles de pierre claire, les galets de Garonne, la bordure de trottoir et son caniveau sur la
## chaussée, la fosse d'arbre grillagée dans la brique, le rond de place en pavés rayonnants (8 m), l'emmarchement,
## le muret de brique et pierre (le bord d'un jardin) et le muret à grille.
const MODULES := ["brique_epi", "brique_rangs", "dalles", "galets", "bordure", "fosse_arbre", "rond", "emmarchement",
	"muret", "muret_grille"]

const TRAME := 4.0
const BRIQUES := ["c46a4a", "b95d40", "cf7a58", "a95238", "d48a68", "bf6648", "b0583f"]
const JOINT := Color("a88a72")
const DALLES := ["e3d8c2", "d9cdb4", "ece2cf", "cfc2a8"]
const GALETS := ["b8ad9c", "a89e8e", "c9bfae", "9a9183", "d2c8b7"]
const PIERRE := Color("efe6d4")
const PIERRE_SOMBRE := Color("cfc2a6")
const ENROBE := Color("5a585a")
const FER := Color("26292c")
const TERRE := Color("6b4f36")
const VERT := Color("5f9e33")
const BRIQUE := Color("c8653f")

## Le module (voir MODULES).
@export var module := "brique_epi"
## La graine : la teinte de chaque brique, de chaque dalle, de chaque galet.
@export var graine := 1
## Les options, toutes facultatives : largeur (les sols, les murets, l'emmarchement : en mètres, 4 par défaut ;
## le rond : son diamètre, 8 par défaut), marches (l'emmarchement : 3 par défaut), plantes (faux : le muret sans
## sa plate-bande).
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
		nom = "brique_epi"
	var o := Outils.new(g * 15485863 + MODULES.find(nom) * 11)
	var mesures: Vector3 = Callable(_Modules, nom).call(o, p, opt)
	o.construire(parent, nom.capitalize())
	return {"module": nom, "graine": g, "emprise": Vector2(mesures.x, mesures.y), "haut": mesures.z}


class _Modules:
	## Une brique ou un pavé : sa seule face de dessus, posée sur le lit de joints.
	static func _pave(o: Outils, c: Vector3, a: float, sx: float, sz: float, col: Color) -> void:
		var b := Basis(Vector3.UP, a)
		var hx := b * Vector3(sx * 0.5, 0, 0)
		var hz := b * Vector3(0, 0, sz * 0.5)
		o.quad(c - hx - hz, c + hx - hz, c + hx + hz, c - hx + hz, Vector3.UP, col)

	static func _teinte(o: Outils, liste: Array) -> Color:
		return Color(liste[o.rng.randi() % liste.size()]).lightened(o.rng.randf_range(-0.04, 0.05))

	## Le lit de joints et l'épaisseur du sol sous un carré de w × d.
	static func _lit(o: Outils, p: Vector3, w: float, d: float, col := JOINT) -> void:
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.16, 0)), Vector3(w, 0.3, d), [col.darkened(0.2), col.darkened(0.2), col, col.darkened(0.3), col.darkened(0.1), col.darkened(0.1)])
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, -0.16, 0)), Vector3(w, 0.3, d)])

	## La brique en épi : des briques à 45°, deux à deux en chevrons. Le motif revient tous les 4/13 m en x comme
	## en z : deux modules de 4 m posés bout à bout se raccordent sans couture. Une brique appartient au module
	## qui contient son centre ; au bord d'un module seul, les briques dépassent un peu, comme sur un vrai pavage.
	## decale : le centre du rectangle par rapport à l'origine du module, pour que le motif reste celui du module.
	static func _epi(o: Outils, p: Vector3, w: float, d: float, y := 0.0, decale := Vector2.ZERO) -> void:
		var l := TRAME / (13.0 * 2.0 * sqrt(2.0))
		var L := l * 2.0
		var s := sqrt(0.5)
		var u := Vector2(s, s)
		var v := Vector2(-s, s)
		var nmax := int((w + d + 2.0 * (absf(decale.x) + absf(decale.y))) / l) + 4
		for i in range(-nmax, nmax):
			for j in range(-nmax / 2, nmax / 2):
				for k in 2:
					# deux briques par motif : l'une couchée selon u, l'autre selon v, décalées d'une demi-brique
					var base := u * (i * l) + v * (j * L) + (v * (l * 0.5) if k == 1 else Vector2.ZERO)
					var c := base + (u * (L * 0.5) if k == 0 else v * (L * 0.5) + u * (l * 0.5)) - decale
					var cx := c.x + 0.0001
					var cy := c.y + 0.0001
					if cx < -w * 0.5 or cx >= w * 0.5 or cy < -d * 0.5 or cy >= d * 0.5:
						continue
					var a := -PI * 0.25 if k == 0 else PI * 0.25
					_pave(o, p + Vector3(c.x, y, c.y), a, L - 0.02, l - 0.02, _teinte(o, BRIQUES))

	## Des briques en rangs décalés (ou des dalles, des galets) sur w × d.
	static func _rangs(o: Outils, p: Vector3, w: float, d: float, pas: float, long: Vector2, liste: Array, y := 0.0) -> void:
		var nz := int(d / pas)
		for j in nz:
			var z := -d * 0.5 + (j + 0.5) * d / nz
			var x := -w * 0.5 + (long.x * 0.5 if j % 2 == 1 else 0.0)
			while x < w * 0.5 - 0.02:
				var lg := minf(o.rng.randf_range(long.x, long.y), w * 0.5 - x)
				if lg > 0.05:
					_pave(o, p + Vector3(x + lg * 0.5, y, z), 0.0, lg - 0.02, d / nz - 0.02, _teinte(o, liste))
				x += lg

	static func brique_epi(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		_lit(o, p, w, TRAME)
		_epi(o, p, w, TRAME)
		return Vector3(w, TRAME, 0.0)

	static func brique_rangs(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		_lit(o, p, w, TRAME, JOINT.lightened(0.1))
		# la variante des terrasses : de plus grands carreaux de brique en rangs, plus clairs
		_rangs(o, p, w, TRAME, 0.2, Vector2(0.36, 0.42), BRIQUES.map(func(h): return Color(h).lightened(0.12).to_html(false)))
		return Vector3(w, TRAME, 0.0)

	static func dalles(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		_lit(o, p, w, TRAME, Color("b2a68e"))
		var z := -TRAME * 0.5
		var j := 0
		while z < TRAME * 0.5 - 0.05:
			var dz := minf([0.6, 0.45, 0.8][j % 3], TRAME * 0.5 - z)
			_rangs(o, p + Vector3(0, 0, z + dz * 0.5), w, dz, dz, Vector2(0.6, 1.0), DALLES)
			z += dz
			j += 1
		return Vector3(w, TRAME, 0.0)

	static func galets(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		_lit(o, p, w, TRAME, Color("8f8577"))
		# les galets de Garonne : petits, ronds, en rangs serrés, chacun bombé
		var pas := 0.16
		var nz := int(TRAME / pas)
		for j in nz:
			var z := -TRAME * 0.5 + (j + 0.5) * pas
			var x := -w * 0.5 + 0.08 + (0.08 if j % 2 == 1 else 0.0)
			while x < w * 0.5 - 0.08:
				var r := o.rng.randf_range(0.055, 0.075)
				o.cylindre(Transform3D(Basis(), p + Vector3(x, -0.02, z)), r, r * 0.6, 0.05, 5, _teinte(o, GALETS))
				x += 0.16
		return Vector3(w, TRAME, 0.0)

	static func bordure(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		# au fond le trottoir de dalles claires, relevé de 15 cm ; la bordure de pierre ; le caniveau ; l'enrobé
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.08, -1.0)), Vector3(w, 0.46, 2.0), Color("b2a68e"))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, -0.08, -1.0)), Vector3(w, 0.46, 2.0)])
		var x := -w * 0.5
		while x < w * 0.5 - 0.05:
			var l := minf(0.5, w * 0.5 - x)
			for k in 4:
				_pave(o, p + Vector3(x + l * 0.5, 0.155, -1.9 + k * 0.45 + 0.225), 0.0, l - 0.02, 0.43, _teinte(o, DALLES))
			x += l
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.0, -0.08)), Vector3(w, 0.36, 0.2), [PIERRE_SOMBRE, PIERRE_SOMBRE, PIERRE, PIERRE_SOMBRE, PIERRE_SOMBRE, PIERRE_SOMBRE])
		# le caniveau : deux rangs de pavés de pierre en creux, une grille d'avaloir
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.16, 1.0)), Vector3(w, 0.3, 2.0), ENROBE.darkened(0.2))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, -0.16, 1.0)), Vector3(w, 0.3, 2.0)])
		for k in 2:
			var xx := -w * 0.5
			while xx < w * 0.5 - 0.02:
				_pave(o, p + Vector3(xx + 0.15, -0.03, 0.11 + k * 0.2), 0.0, 0.28, 0.18, _teinte(o, DALLES).darkened(0.15))
				xx += 0.3
		o.boite(Transform3D(Basis(), p + Vector3(w * 0.25, -0.02, 0.22)), Vector3(0.6, 0.02, 0.36), FER)
		for k in 6:
			o.boite(Transform3D(Basis(), p + Vector3(w * 0.25 - 0.25 + k * 0.1, -0.005, 0.22)), Vector3(0.03, 0.02, 0.34), Color("3a3d40"))
		# la chaussée d'enrobé, et son marquage usé
		o.quad(p + Vector3(-w * 0.5, -0.01, 0.42), p + Vector3(w * 0.5, -0.01, 0.42), p + Vector3(w * 0.5, -0.01, 2.0), p + Vector3(-w * 0.5, -0.01, 2.0), Vector3.UP, ENROBE)
		for i in 30:
			var q := Vector3(o.rng.randf_range(-w * 0.48, w * 0.48), -0.005, o.rng.randf_range(0.5, 1.9))
			_pave(o, p + q, o.rng.randf() * PI, o.rng.randf_range(0.08, 0.3), o.rng.randf_range(0.06, 0.2), ENROBE.lightened(o.rng.randf_range(-0.08, 0.1)))
		return Vector3(w, TRAME, 0.15)

	static func fosse_arbre(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		_lit(o, p, w, TRAME)
		# la brique en épi autour, la fosse carrée de 1,8 m bordée de pierre, sa grille de fonte rayonnante
		var f := 0.9
		_epi_hors(o, p, w, f + 0.12)
		for cote in 4:
			var b := Basis(Vector3.UP, PI * 0.5 * cote)
			o.boite(Transform3D(b, p + b * Vector3(0, 0.01, f + 0.06)), Vector3(f * 2.0 + 0.24, 0.06, 0.12), PIERRE)
		o.quad(p + Vector3(-f, -0.06, -f), p + Vector3(f, -0.06, -f), p + Vector3(f, -0.06, f), p + Vector3(-f, -0.06, f), Vector3.UP, TERRE)
		o.anneau(Transform3D(Basis(), p + Vector3(0, -0.03, 0)), 0.32, 0.4, 0.04, 16, FER)
		o.anneau(Transform3D(Basis(), p + Vector3(0, -0.03, 0)), f - 0.12, f - 0.04, 0.04, 20, FER)
		for i in 24:
			var a := TAU * i / 24.0
			var c := Vector3(cos(a), 0, sin(a)) * ((0.4 + f - 0.12) * 0.5)
			o.boite(Transform3D(Basis(Vector3.UP, -a), p + c + Vector3(0, -0.03, 0)), Vector3(f - 0.52, 0.03, 0.04), FER)
		for k in 4:
			var b := Basis(Vector3.UP, PI * 0.5 * k + PI * 0.25)
			o.boite(Transform3D(b, p + b * Vector3(0, -0.03, (f - 0.08) * 1.25)), Vector3(0.3, 0.03, 0.05), FER)
		return Vector3(w, TRAME, 0.0)

	## La brique en épi tout autour d'un carré central de demi-côté f.
	static func _epi_hors(o: Outils, p: Vector3, w: float, f: float) -> void:
		var bandes := [[Vector3(0, 0, -(TRAME * 0.25 + f * 0.5)), Vector2(w, TRAME * 0.5 - f)], [Vector3(0, 0, TRAME * 0.25 + f * 0.5), Vector2(w, TRAME * 0.5 - f)],
			[Vector3(-(w * 0.25 + f * 0.5), 0, 0), Vector2(w * 0.5 - f, f * 2.0)], [Vector3(w * 0.25 + f * 0.5, 0, 0), Vector2(w * 0.5 - f, f * 2.0)]]
		for bd in bandes:
			var c: Vector3 = bd[0]
			var t: Vector2 = bd[1]
			_epi(o, p + c, t.x, t.y, 0.0, Vector2(c.x, c.z))

	static func rond(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var D := float(opt.get("largeur", 8.0))
		var R := D * 0.5
		_lit(o, p, D, D)
		# les pavés de pierre claire en anneaux concentriques autour d'un médaillon, entourés de brique
		_rangs(o, p, D, D, 0.12, Vector2(0.24, 0.24), BRIQUES)
		o.cylindre(Transform3D(Basis(), p + Vector3(0, -0.01, 0)), R - 0.1, R - 0.1, 0.012, 40, JOINT)
		var r := 0.6
		while r < R - 0.2:
			var n := int(TAU * r / 0.2)
			for i in n:
				var a := TAU * (i + 0.5 * ((int(r * 10)) % 2)) / n
				_pave(o, p + Vector3(cos(a) * r, 0.005, sin(a) * r), -a, 0.17, 0.15, _teinte(o, DALLES if int(r / 0.18) % 6 != 0 else BRIQUES))
			r += 0.18
		o.cylindre(Transform3D(Basis(), p + Vector3(0, -0.005, 0)), 0.6, 0.6, 0.02, 20, PIERRE)
		o.cylindre(Transform3D(Basis(), p + Vector3(0, -0.004, 0)), 0.36, 0.36, 0.025, 16, BRIQUE)
		o.anneau(Transform3D(Basis(), p + Vector3(0, -0.01, 0)), R - 0.22, R - 0.08, 0.025, 48, PIERRE)
		return Vector3(D, D, 0.0)

	static func emmarchement(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		var n := int(opt.get("marches", 3))
		var hm := 0.15
		var g := TRAME / (n + 1)
		# des marches basses de pierre claire qui montent vers −Z, le palier de brique en haut
		for i in n:
			var z := TRAME * 0.5 - (i + 1) * g
			var y := (i + 1) * hm
			o.boite(Transform3D(Basis(), p + Vector3(0, (y - 0.3) * 0.5, z + g * 0.5)), Vector3(w, y + 0.3, g), [PIERRE_SOMBRE, PIERRE_SOMBRE, PIERRE, PIERRE_SOMBRE, PIERRE, PIERRE_SOMBRE], Outils.DUR, true)
			o.boite(Transform3D(Basis(), p + Vector3(0, y - 0.02, z + g - 0.04)), Vector3(w + 0.02, 0.04, 0.08), PIERRE.lightened(0.04))
		var yh := n * hm
		o.boite(Transform3D(Basis(), p + Vector3(0, (yh - 0.3) * 0.5, -TRAME * 0.5 + g * 0.5)), Vector3(w, yh + 0.3, g), JOINT, Outils.DUR, true)
		_rangs(o, p + Vector3(0, 0, -TRAME * 0.5 + g * 0.5), w, g, 0.11, Vector2(0.22, 0.22), BRIQUES, yh + 0.001)
		# le pied, un lit de brique sous la première marche
		_lit(o, p + Vector3(0, 0, TRAME * 0.5 - g * 0.5), w, g)
		_epi(o, p + Vector3(0, 0, TRAME * 0.5 - g * 0.5), w, g, 0.0, Vector2(0, TRAME * 0.5 - g * 0.5))
		return Vector3(w, TRAME, yh)

	## Un muret de brique foraine à chaperon de pierre, de longueur w et de hauteur h, centré en p.
	static func _muret(o: Outils, p: Vector3, w: float, h: float, e: float) -> void:
		o.boite(Transform3D(Basis(), p + Vector3(0, (h - 0.3) * 0.5, 0)), Vector3(w, h + 0.3, e), BRIQUE, Outils.DUR, true)
		var y := 0.1
		var k := 0
		while y < h - 0.1:
			var x := -w * 0.5 + (0.11 if k % 2 == 1 else 0.0)
			while x < w * 0.5 - 0.1:
				if o.rng.randf() < 0.35:
					var c := Color(BRIQUES[o.rng.randi() % BRIQUES.size()])
					for cote in [-1.0, 1.0]:
						o.boite(Transform3D(Basis(), p + Vector3(x + 0.11, y, cote * (e * 0.5 + 0.004))), Vector3(0.2, 0.06, 0.01), c)
				x += 0.22
			y += 0.075
			k += 1
		o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.04, 0)), Vector3(w + 0.04, 0.08, e + 0.1), PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.08, 0)), Vector3(w + 0.02, 0.16, e + 0.04), PIERRE_SOMBRE)

	static func muret(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		_lit(o, p, w, TRAME)
		_epi(o, p + Vector3(0, 0, 1.0), w, 2.0, 0.0, Vector2(0, 1.0))
		# le muret de séparation, et derrière lui la plate-bande d'un jardin, plus haute
		_muret(o, p + Vector3(0, 0, -0.1), w, 0.55, 0.3)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.2, -1.1)), Vector3(w, 0.5, 1.7), TERRE)
		if opt.get("plantes", true):
			var x := -w * 0.5 + 0.4
			while x < w * 0.5 - 0.3:
				var r := o.rng.randf_range(0.3, 0.5)
				o.boule(p + Vector3(x, 0.5 + r * 0.5, o.rng.randf_range(-1.6, -0.6)), Vector3(r, r * 0.8, r), VERT.lightened(o.rng.randf_range(-0.08, 0.12)), 0.22, Outils.FEUILLE, 0.06, 0.4)
				if o.rng.randf() < 0.5:
					o.boule(p + Vector3(x + 0.1, 0.65 + r, o.rng.randf_range(-1.4, -0.8)), Vector3(0.14, 0.1, 0.14), Color(["e0605a", "f2c14e", "f4f0e6", "d04a8a"][o.rng.randi() % 4]), 0.3, Outils.FEUILLE, 0.08, 0.3)
				x += o.rng.randf_range(0.4, 0.7)
		return Vector3(w, TRAME, 0.55)

	static func muret_grille(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		_lit(o, p, w, TRAME)
		_epi(o, p + Vector3(0, 0, 1.0), w, 2.0, 0.0, Vector2(0, 1.0))
		_epi(o, p + Vector3(0, 0, -1.2), w, 1.6, 0.0, Vector2(0, -1.2))
		# le muret bas et sa grille de fer forgé à pointes, entre deux piliers de brique à chapeau de pierre
		_muret(o, p, w, 0.4, 0.3)
		for cote in [-1.0, 1.0]:
			var q := p + Vector3(cote * (w * 0.5 - 0.2), 0, 0)
			o.boite(Transform3D(Basis(), q + Vector3(0, 0.6, 0)), Vector3(0.4, 1.2, 0.4), BRIQUE.darkened(0.04), Outils.DUR, true)
			o.boite(Transform3D(Basis(), q + Vector3(0, 1.25, 0)), Vector3(0.5, 0.1, 0.5), PIERRE)
			o.cylindre(Transform3D(Basis(), q + Vector3(0, 1.3, 0)), 0.14, 0.02, 0.24, 6, PIERRE)
		var l := w - 0.8
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.55, 0)), Vector3(l, 0.04, 0.04), FER)
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.0, 0)), Vector3(l, 0.04, 0.04), FER)
		var nb := int(l / 0.12)
		for i in nb + 1:
			var x := -l * 0.5 + i * l / nb
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.78, 0)), Vector3(0.02, 0.8, 0.02), FER)
			o.cylindre(Transform3D(Basis(), p + Vector3(x, 1.17, 0)), 0.025, 0.0, 0.08, 4, FER)
		for i in int(l / 0.6):
			o.anneau(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(-l * 0.5 + 0.3 + i * 0.6, 0.78, 0)), 0.12, 0.15, 0.02, 10, FER)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.6, 0)), Vector3(w, 1.2, 0.3)])
		return Vector3(w, TRAME, 1.2)
