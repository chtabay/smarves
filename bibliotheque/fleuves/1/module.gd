extends Node3D
## Un module des fleuves, posé tel quel : on règle module, graine et options avant de l'ajouter à la scène, il se
## bâtit à son entrée dans l'arbre de scène. Le fleuve coule le long de x, vers +x ; les modules se posent bout à
## bout le long du courant (20 m par défaut). Le sol des rives est à y = 0, l'eau à NIVEAU (−1,4 m), le fond à
## FOND (−3,5 m). Un module est centré sur l'origine ; une berge a la terre derrière elle (−Z) et l'eau devant
## (+Z) : celle d'en face se pose tournée d'un demi-tour. En mètres.
##   var m = load(Bibliotheque.scene("fleuves@1", "decor")).instantiate()
##   m.module = "berge_galets" ; m.graine = 3
##   add_child(m)
## Pour un fleuve de 100 m entre deux berges de galets : le module fleuve (largeur 100) en z = 0, une berge en
## z = −(50 + 10 − EAU_BERGE) tournée de 0, l'autre en z = +(50 + 10 − EAU_BERGE) tournée de PI ; l'eau du fleuve
## mord sur le bas des berges, qui s'enfoncent sous elle.
## Après la construction, le nœud porte ses métadonnées : module, graine, emprise (Vector2, la taille au sol),
## haut (le plus haut du module au-dessus de y = 0).
## Tiré de la note d'intentions de la carte de Belley : le Rhône et ses lônes, la Garonne à Toulouse, la Saône à
## Lyon ; berges de galets et de roseaux, digue de pierre, bras morts, pontons et barques.
const Outils := preload("res://bibliotheque/fleuves/1/outils.gd")

## Les modules : le fleuve (l'eau qui file et son lit), la berge de galets, la berge de roseaux, la digue de pierre,
## la lône (le bras mort, l'eau qui dort, les nénuphars), l'île de galets, le ponton de bois et la barque.
const MODULES := ["fleuve", "berge_galets", "berge_roseaux", "digue", "lone", "ile", "ponton", "barque"]

const LONGUEUR := 20.0
const NIVEAU := -1.4
const FOND := -3.5
## Une berge a 20 m de profondeur ; son eau commence à EAU_BERGE m de son devant.
const PROFONDEUR := 20.0
const EAU_BERGE := 8.0
## Les couleurs de l'eau : le Rhône vert glacier, la Garonne brun-vert, la Saône vert-gris.
const EAUX := {"rhone": "3f7a72", "garonne": "76704c", "saone": "56756c"}
const HERBE := Color("8dbb4c")
const HERBE_SOMBRE := Color("6f9e3c")
const TERRE := Color("8a6a46")
const VASE := Color("6e6048")
const GALETS := ["cfc6b4", "bab09c", "a69d89", "d9d1c1", "988f7d", "c4b89e"]
const LIT := Color("4c5a4e")
const BOIS := Color("8a6a46")
const BOIS_GRIS := Color("a39a88")
const PIERRE := Color("c9bfa6")
const ROSEAU := Color("8aa648")
const ROSEAU_SEC := Color("c2ad6a")

## Le module (voir MODULES).
@export var module := "fleuve"
## La graine : la place de chaque galet, de chaque roseau, de chaque planche.
@export var graine := 1
## Les options, toutes facultatives : longueur (le long du courant, en mètres : 20 par défaut), largeur (le fleuve :
## la largeur d'eau, 100 m par défaut ; l'île : sa longueur, 30 m), eau (« rhone », « garonne », « saone » ou un hexa),
## barque (faux : le ponton sans sa barque).
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
		nom = "fleuve"
	var o := Outils.new(g * 15485863 + MODULES.find(nom) * 11)
	# le feuillage porte des UV (l'eau s'y reconnaît) : on les déclare avant le premier sommet
	o._s(Outils.FEUILLE).set_uv(Vector2.ZERO)
	var mesures: Vector3 = Callable(_Modules, nom).call(o, p, opt)
	o.construire(parent, nom.capitalize())
	return {"module": nom, "graine": g, "emprise": Vector2(mesures.x, mesures.y), "haut": mesures.z}


class _Modules:
	static func _couleur_eau(opt: Dictionary) -> Color:
		var e := str(opt.get("eau", "rhone"))
		return Color(EAUX.get(e, e))

	## Une nappe d'eau de x0 à x1 (le long du courant) et de z0 à z1, à la hauteur y, maillée tous les 2,5 m pour
	## onduler ; plus claire sur ses bords, où l'eau est basse. dort : l'eau d'une lône.
	static func _eau(o: Outils, p: Vector3, x0: float, x1: float, z0: float, z1: float, y: float, col: Color, dort := false, bords := 6.0) -> void:
		var st := o._s(Outils.FEUILLE)
		var nx := maxi(1, int(ceilf((x1 - x0) / 2.5)))
		var nz := maxi(1, int(ceilf((z1 - z0) / 2.5)))
		var marque := 4000.0 if dort else 1000.0
		for i in nx:
			for j in nz:
				var xa := lerpf(x0, x1, float(i) / nx)
				var xb := lerpf(x0, x1, float(i + 1) / nx)
				var za := lerpf(z0, z1, float(j) / nz)
				var zb := lerpf(z0, z1, float(j + 1) / nz)
				var coins := [Vector2(xa, za), Vector2(xb, za), Vector2(xb, zb), Vector2(xa, zb)]
				for t in [[0, 2, 1], [0, 3, 2]]:
					for k in t:
						var c: Vector2 = coins[k]
						var bord := minf(c.y - z0, z1 - c.y)
						var teinte := col.lightened(clampf(1.0 - bord / bords, 0.0, 1.0) * 0.18)
						teinte.a = 0.0
						st.set_color(teinte)
						st.set_normal(Vector3.UP)
						st.set_uv(Vector2(0.0, marque))
						st.add_vertex(p + Vector3(c.x, y, c.y))
		st.set_uv(Vector2.ZERO)

	## Le profil d'une berge le long de x, de longueur l : pts sont des (z, y), cols la couleur de chaque pan ;
	## chaque pan a sa dalle de collision.
	static func _profil(o: Outils, p: Vector3, l: float, pts: Array, cols: Array) -> void:
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var col: Color = cols[mini(i, cols.size() - 1)]
			var n := Vector3(0, b.x - a.x, -(b.y - a.y)).normalized()
			o.quad(p + Vector3(-l * 0.5, a.y, a.x), p + Vector3(l * 0.5, a.y, a.x), p + Vector3(l * 0.5, b.y, b.x), p + Vector3(-l * 0.5, b.y, b.x), n, col)
			var m := (a + b) * 0.5
			var d := b - a
			var bb := Basis(Vector3.RIGHT, -atan2(d.y, d.x))
			o.collisions.append([Transform3D(bb, p + Vector3(0, m.y, m.x) - bb * Vector3(0, 0.25, 0)), Vector3(l, 0.5, d.length())])

	## La hauteur du profil en z.
	static func _haut(pts: Array, z: float) -> float:
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if z >= a.x and z <= b.x:
				return lerpf(a.y, b.y, (z - a.x) / maxf(b.x - a.x, 0.001))
		return (pts[pts.size() - 1] as Vector2).y

	static func _galet(o: Outils, c: Vector3, s: float) -> void:
		var r := o.rng
		o.boule(c + Vector3(0, s * 0.25, 0), Vector3(s, s * 0.5, s * r.randf_range(0.7, 1.0)), Color(GALETS[r.randi() % GALETS.size()]), 0.12, Outils.DUR, 0.05)

	static func _touffe(o: Outils, c: Vector3, s: float, col := HERBE_SOMBRE) -> void:
		o.boule(c + Vector3(0, s * 0.3, 0), Vector3(s, s * 0.6, s), col.lightened(o.rng.randf_range(-0.06, 0.08)), 0.35, Outils.FEUILLE, 0.1, 0.4)

	## Une touffe de roseaux en q : des tiges fines qui s'écartent, des feuilles en lame, parfois des massettes.
	static func _roseaux(o: Outils, q: Vector3, n: int, h: float) -> void:
		var r := o.rng
		var st := o._s(Outils.FEUILLE)
		for k in n:
			var pied := q + Vector3(r.randf_range(-0.35, 0.35), 0, r.randf_range(-0.35, 0.35))
			var haut := pied + Vector3(r.randf_range(-0.3, 0.3), h * r.randf_range(0.7, 1.15), r.randf_range(-0.3, 0.3))
			var col := ROSEAU.lerp(ROSEAU_SEC, r.randf_range(0.0, 0.45))
			var lame := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized() * 0.05
			for v in [[pied - lame, 0.0], [pied + lame, 0.0], [haut, 1.0]]:
				var c := col.lightened((v[1] as float) * 0.12)
				c.a = v[1]
				st.set_color(c)
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
			if r.randf() < 0.12:
				o.boule(haut - Vector3(0, 0.25, 0), Vector3(0.05, 0.18, 0.05), Color("6a4a30"), 0.1, Outils.FEUILLE, 0.03, 0.8)

	## Un tronc flotté, blanchi, couché en c.
	static func _bois_flotte(o: Outils, c: Vector3, l: float) -> void:
		var r := o.rng
		var d := Vector3(cos(r.randf() * TAU), r.randf_range(-0.05, 0.05), sin(r.randf() * TAU)).normalized()
		o.branche(c - d * l * 0.5, c + d * l * 0.5, 0.16 * l / 3.0, 0.09 * l / 3.0, BOIS_GRIS.lightened(r.randf_range(0.0, 0.15)), 6)
		o.branche(c + d * l * 0.2, c + d * l * 0.2 + d.rotated(Vector3.UP, 0.8) * l * 0.3 + Vector3(0, 0.15, 0), 0.05, 0.02, BOIS_GRIS, 4)

	## Le fleuve : la nappe qui file, le lit de vase et de graviers au fond, quelques remous.
	static func fleuve(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var l := float(opt.get("longueur", LONGUEUR))
		var w := float(opt.get("largeur", 100.0))
		var col := _couleur_eau(opt)
		var tout := w + EAU_BERGE * 2.0
		o.boite(Transform3D(Basis(), p + Vector3(0, FOND - 0.2, 0)), Vector3(l, 0.4, tout), LIT, Outils.DUR, true)
		var r := o.rng
		for i in int(l * w / 60.0):
			o.boule(p + Vector3(r.randf_range(-l * 0.5, l * 0.5), FOND + 0.15, r.randf_range(-w * 0.5, w * 0.5)), Vector3(1.0, 0.25, 0.8) * r.randf_range(0.6, 2.0), LIT.lightened(r.randf_range(0.0, 0.2)), 0.2, Outils.DUR, 0.04)
		_eau(o, p, -l * 0.5, l * 0.5, -tout * 0.5, tout * 0.5, NIVEAU, col, false, EAU_BERGE + 4.0)
		return Vector3(l, tout, 0.0)

	## La berge de galets : l'herbe de la rive, la grève de galets en pente douce où l'on descend, les troncs
	## flottés, quelques roseaux au bord de l'eau, puis la pente sous l'eau jusqu'au fond.
	static func berge_galets(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("longueur", LONGUEUR))
		var D := PROFONDEUR * 0.5
		var pts := [Vector2(-D, 0.0), Vector2(-D + 4.0, 0.0), Vector2(-D + 5.5, -0.35), Vector2(D - EAU_BERGE, NIVEAU + 0.05), Vector2(D - 4.0, -2.6), Vector2(D, FOND)]
		_profil(o, p, l, pts, [HERBE, TERRE.lerp(HERBE_SOMBRE, 0.4), Color(GALETS[2]).darkened(0.12), Color(GALETS[4]).darkened(0.15), LIT])
		for i in int(l * 18):
			var z := r.randf_range(-D + 4.8, D - EAU_BERGE + 1.0)
			var y := _haut(pts, z)
			_galet(o, p + Vector3(r.randf_range(-l * 0.5, l * 0.5), y, z), r.randf_range(0.06, 0.22) * (1.4 if r.randf() < 0.1 else 1.0))
		for i in int(l / 8.0) + 1:
			var z := r.randf_range(-D + 6.0, D - EAU_BERGE - 0.5)
			_bois_flotte(o, p + Vector3(r.randf_range(-l * 0.45, l * 0.45), _haut(pts, z) + 0.08, z), r.randf_range(1.5, 3.5))
		for i in int(l / 2.5):
			var z := D - EAU_BERGE + r.randf_range(-0.6, 0.4)
			_roseaux(o, p + Vector3(r.randf_range(-l * 0.5, l * 0.5), _haut(pts, z), z), 6 + r.randi() % 6, r.randf_range(1.0, 1.6))
		for i in int(l * 0.8):
			_touffe(o, p + Vector3(r.randf_range(-l * 0.5, l * 0.5), 0, r.randf_range(-D + 0.2, -D + 4.5)), r.randf_range(0.15, 0.35))
		return Vector3(l, PROFONDEUR, 0.0)

	## La berge de roseaux : la rive basse et vaseuse, la roselière dense au bord de l'eau, les iris jaunes, les
	## saules buissonnants.
	static func berge_roseaux(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("longueur", LONGUEUR))
		var D := PROFONDEUR * 0.5
		var pts := [Vector2(-D, 0.0), Vector2(-D + 6.0, -0.3), Vector2(D - EAU_BERGE - 2.0, NIVEAU + 0.2), Vector2(D - EAU_BERGE + 2.0, NIVEAU - 0.4), Vector2(D - 3.0, -3.0), Vector2(D, FOND)]
		_profil(o, p, l, pts, [HERBE, HERBE_SOMBRE.lerp(VASE, 0.4), VASE, VASE.darkened(0.15), LIT])
		# la roselière : des touffes serrées sur une bande de cinq mètres, plus hautes vers l'eau
		for i in int(l * 4.0):
			var z := r.randf_range(D - EAU_BERGE - 4.0, D - EAU_BERGE + 1.5)
			_roseaux(o, p + Vector3(r.randf_range(-l * 0.5, l * 0.5), _haut(pts, z), z), 5 + r.randi() % 5, lerpf(1.2, 2.2, clampf((z - (D - EAU_BERGE - 4.0)) / 5.5, 0.0, 1.0)))
		for i in int(l / 2.0):
			var z := r.randf_range(D - EAU_BERGE - 3.0, D - EAU_BERGE)
			var q := p + Vector3(r.randf_range(-l * 0.5, l * 0.5), _haut(pts, z), z)
			o.boule(q + Vector3(0, 0.35, 0), Vector3(0.25, 0.4, 0.25), Color("5f9a34"), 0.3, Outils.FEUILLE, 0.06, 0.5)
			o.boule(q + Vector3(0, 0.78, 0), Vector3(0.09, 0.07, 0.09), Color("f2d040"), 0.25, Outils.FEUILLE, 0.05, 0.5)
		# les saules buissonnants sur la rive
		for i in int(l / 9.0) + 1:
			var z := r.randf_range(-D + 1.0, -D + 6.0)
			var q := p + Vector3(r.randf_range(-l * 0.45, l * 0.45), _haut(pts, z), z)
			for k in 4:
				var top := q + Vector3(r.randf_range(-0.8, 0.8), r.randf_range(1.8, 3.0), r.randf_range(-0.8, 0.8))
				o.branche(q, top, 0.07, 0.03, Color("7a6a50"), 5)
				o.boule(top, Vector3(1.1, 0.9, 1.1) * r.randf_range(0.8, 1.2), Color("9ab56a").lerp(Color("7a9a50"), r.randf()), 0.25, Outils.FEUILLE, 0.08, 0.7)
		for i in int(l * 0.8):
			_touffe(o, p + Vector3(r.randf_range(-l * 0.5, l * 0.5), 0, r.randf_range(-D + 0.2, -D + 5.0)), r.randf_range(0.15, 0.35))
		return Vector3(l, PROFONDEUR, 0.0)

	## La digue : le chemin de halage gravillonné en crête, le perré de pierres maçonnées qui plonge dans l'eau,
	## un escalier de pierre qui descend au fleuve, les bornes d'amarrage.
	static func digue(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("longueur", LONGUEUR))
		var D := PROFONDEUR * 0.5
		var pied := D - EAU_BERGE + 1.5
		var pts := [Vector2(-D, 0.0), Vector2(-D + 3.0, 0.0), Vector2(-D + 7.0, 0.0), Vector2(pied - 4.0 + 1.5, -0.1), Vector2(pied + 2.6, FOND + 0.3), Vector2(D, FOND)]
		_profil(o, p, l, pts, [HERBE, Color("cbbf9e"), Color("d6cbae"), PIERRE, LIT])
		# les pierres du perré, posées en rangs suivant la pente
		var a: Vector2 = pts[3]
		var b: Vector2 = pts[4]
		var pente := b - a
		var bb := Basis(Vector3.RIGHT, -atan2(pente.y, pente.x))
		var rangs := int(pente.length() / 0.45)
		for j in rangs:
			var t := (j + 0.5) / rangs
			var c := a.lerp(b, t)
			var x := -l * 0.5 + (0.3 if j % 2 == 1 else 0.0)
			while x < l * 0.5 - 0.1:
				var lx := minf(r.randf_range(0.5, 0.9), l * 0.5 - x)
				o.boite(Transform3D(bb, p + Vector3(x + lx * 0.5, c.y, c.x) + bb * Vector3(0, 0.05, 0)), Vector3(lx - 0.05, 0.12, 0.4), PIERRE.lightened(r.randf_range(-0.1, 0.08)))
				x += lx
		# le couronnement de pierre de taille au bord du chemin
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.1, a.x - 0.25)), Vector3(l, 0.25, 0.5), PIERRE.lightened(0.06))
		# l'escalier qui descend au fleuve, au milieu du module
		var marches := 10
		for k in marches:
			var t := (k + 0.5) / marches
			var c := a.lerp(b.lerp(a, 0.45), t)
			o.boite(Transform3D(Basis(), p + Vector3(0, c.y + 0.12, c.x)), Vector3(2.2, 0.3, 0.5), PIERRE.darkened(0.05), Outils.DUR, true)
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(bb, p + Vector3(cote * 1.25, a.lerp(b, 0.28).y + 0.2, a.lerp(b, 0.28).x)), Vector3(0.3, 0.5, pente.length() * 0.56), PIERRE.darkened(0.1))
		# les bornes d'amarrage et quelques touffes sur le chemin de halage
		for x in [-l * 0.35, l * 0.35]:
			o.cylindre(Transform3D(Basis(), p + Vector3(x, 0, a.x - 0.8)), 0.16, 0.13, 0.6, 8, Color("3a3d40"))
			o.cylindre(Transform3D(Basis(), p + Vector3(x, 0.6, a.x - 0.8)), 0.2, 0.2, 0.08, 8, Color("3a3d40"))
		for i in int(l * 0.6):
			_touffe(o, p + Vector3(r.randf_range(-l * 0.5, l * 0.5), 0, r.randf_range(-D + 0.2, -D + 2.8)), r.randf_range(0.15, 0.3))
		return Vector3(l, PROFONDEUR, 0.6)

	## La lône : un bras mort du fleuve, l'eau verte qui dort entre deux rives d'herbe et de roseaux, les nénuphars,
	## un tronc tombé. Le bras file le long de x ; module de 24 m en travers.
	static func lone(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("longueur", LONGUEUR))
		var D := 12.0
		var eau := -0.7
		var pts := [Vector2(-D, 0.0), Vector2(-6.5, -0.1), Vector2(-4.5, eau + 0.1), Vector2(-3.0, -1.6), Vector2(3.0, -1.6), Vector2(4.5, eau + 0.1), Vector2(6.5, -0.1), Vector2(D, 0.0)]
		_profil(o, p, l, pts, [HERBE, HERBE_SOMBRE.lerp(VASE, 0.5), VASE, VASE.darkened(0.25), VASE, HERBE_SOMBRE.lerp(VASE, 0.5), HERBE])
		var col := Color("4f7a4a")
		for cote in [-1.0, 1.0]:
			for i in int(l * 1.6):
				var z: float = cote * r.randf_range(3.8, 6.0)
				_roseaux(o, p + Vector3(r.randf_range(-l * 0.5, l * 0.5), _haut(pts, z), z), 5 + r.randi() % 5, r.randf_range(1.2, 2.0))
			for i in int(l * 0.6):
				_touffe(o, p + Vector3(r.randf_range(-l * 0.5, l * 0.5), 0, cote * r.randf_range(7.0, D - 0.3)), r.randf_range(0.15, 0.35))
		# les nénuphars : des feuilles rondes échancrées posées sur l'eau, quelques fleurs blanches
		for i in int(l * 1.5):
			var c := p + Vector3(r.randf_range(-l * 0.5, l * 0.5), eau + 0.03, r.randf_range(-3.0, 3.0))
			var s := r.randf_range(0.18, 0.35)
			var a0 := r.randf() * TAU
			var pts_f := Outils.arc(Vector2.ZERO, s, a0 + 0.35, a0 + TAU - 0.05, 9)
			for k in pts_f.size() - 1:
				o.tri(c, c + Vector3(pts_f[k].x, 0, pts_f[k].y), c + Vector3(pts_f[k + 1].x, 0, pts_f[k + 1].y), Vector3.UP, Color("5e9a3a").lightened(r.randf_range(-0.08, 0.1)))
			if r.randf() < 0.2:
				o.boule(c + Vector3(0, 0.05, 0), Vector3(0.08, 0.05, 0.08), Color("f6f2ea"), 0.3, Outils.DUR, 0.03)
		_bois_flotte(o, p + Vector3(r.randf_range(-l * 0.3, l * 0.3), eau + 0.05, r.randf_range(-1.5, 1.5)), 4.0)
		_eau(o, p, -l * 0.5, l * 0.5, -4.7, 4.7, eau, col, true, 1.5)
		return Vector3(l, D * 2.0, 0.0)

	## L'île : un banc de galets au milieu du fleuve, une touffe de saules et de roseaux, des troncs échoués. Elle se
	## pose sur le module fleuve ; son dos dépasse de l'eau d'un mètre.
	static func ile(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var l := float(opt.get("largeur", 30.0))
		var w := l * 0.32
		var dos := NIVEAU + 1.0
		# un dôme aplati, en anneaux de plus en plus petits vers le haut
		var anneaux := [[1.15, FOND + 0.2, LIT], [1.0, NIVEAU - 0.3, Color(GALETS[4])], [0.85, NIVEAU + 0.25, Color(GALETS[1])], [0.55, dos, Color(GALETS[0])]]
		for k in anneaux.size():
			var a: Array = anneaux[k]
			var s: float = a[0]
			var y: float = a[1]
			o.boule(p + Vector3(0, y - 0.4, 0), Vector3(l * 0.5 * s, 0.6, w * 0.5 * s), a[2], 0.06, Outils.DUR, 0.03)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, (FOND + dos) * 0.5, 0)), Vector3(l * 0.7, dos - FOND, w * 0.6)])
		for i in int(l * 10):
			var a := r.randf() * TAU
			var t := sqrt(r.randf()) * 0.85
			var q := Vector3(cos(a) * l * 0.5 * t, 0, sin(a) * w * 0.5 * t)
			_galet(o, p + q + Vector3(0, lerpf(dos + 0.15, NIVEAU + 0.05, t * t), 0), r.randf_range(0.06, 0.2))
		for i in 6:
			var q := p + Vector3(r.randf_range(-l * 0.18, l * 0.18), dos, r.randf_range(-w * 0.12, w * 0.12))
			for k in 3:
				var top := q + Vector3(r.randf_range(-0.6, 0.6), r.randf_range(1.6, 2.6), r.randf_range(-0.6, 0.6))
				o.branche(q, top, 0.06, 0.03, Color("7a6a50"), 5)
				o.boule(top, Vector3(0.9, 0.75, 0.9) * r.randf_range(0.8, 1.2), Color("9ab56a").lerp(Color("7a9a50"), r.randf()), 0.25, Outils.FEUILLE, 0.08, 0.7)
		for i in 10:
			var a := r.randf() * TAU
			_roseaux(o, p + Vector3(cos(a) * l * 0.36, NIVEAU + 0.2, sin(a) * w * 0.36), 6, r.randf_range(1.0, 1.6))
		for i in 3:
			_bois_flotte(o, p + Vector3(r.randf_range(-l * 0.3, l * 0.3), NIVEAU + 0.5, r.randf_range(-w * 0.3, w * 0.3)), r.randf_range(2.5, 4.5))
		return Vector3(l, w, dos + 3.0)

	## Le ponton : une passerelle descend de la rive (y = 0, en z = 0) au platelage posé sur ses pieux au-dessus de
	## l'eau, vers +Z ; les bittes d'amarrage, l'échelle, la barque amarrée à son flanc.
	static func ponton(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var r := o.rng
		var long := 12.0
		var y := NIVEAU + 0.55
		var w := 2.2
		# la passerelle, en pente douce de la rive au platelage
		var rampe := 3.5
		var d := Vector2(rampe, y)
		var bb := Basis(Vector3.RIGHT, -atan2(d.y, d.x))
		o.boite(Transform3D(bb, p + Vector3(0, y * 0.5, rampe * 0.5)), Vector3(1.4, 0.08, d.length()), BOIS.lightened(0.05), Outils.DUR, true)
		for k in int(d.length() / 0.4):
			o.boite(Transform3D(bb, p + Vector3(0, y * 0.5, rampe * 0.5) + bb * Vector3(0, 0.05, -d.length() * 0.5 + 0.2 + k * 0.4)), Vector3(1.4, 0.03, 0.05), BOIS.darkened(0.15))
		for cote in [-0.75, 0.75]:
			o.branche(p + Vector3(cote, 0.9, 0.0), p + Vector3(cote, y + 0.9, rampe), 0.03, 0.03, BOIS.darkened(0.1), 5)
		# le platelage : des planches en travers, un peu disjointes, de teintes inégales
		var z0 := rampe
		o.boite(Transform3D(Basis(), p + Vector3(0, y - 0.12, z0 + long * 0.5)), Vector3(w, 0.16, long), BOIS.darkened(0.2), Outils.DUR, true)
		var z := z0
		while z < z0 + long - 0.05:
			o.boite(Transform3D(Basis(), p + Vector3(r.randf_range(-0.03, 0.03), y, z + 0.12)), Vector3(w + r.randf_range(-0.05, 0.05), 0.05, 0.2), BOIS.lightened(r.randf_range(-0.1, 0.12)))
			z += 0.24
		# les pieux, plantés jusqu'au fond
		for k in 4:
			for cote in [-1.0, 1.0]:
				var q := p + Vector3(cote * (w * 0.5 + 0.08), 0, z0 + 0.4 + k * (long - 0.8) / 3.0)
				o.cylindre(Transform3D(Basis(), q + Vector3(0, FOND, 0)), 0.13, 0.12, y - FOND + 0.25, 7, BOIS.darkened(0.3))
		# les bittes, l'échelle au bout
		for k in 2:
			o.cylindre(Transform3D(Basis(), p + Vector3(w * 0.5 - 0.2, y, z0 + 2.5 + k * 6.0)), 0.07, 0.07, 0.35, 6, Color("3a3d40"))
		for k in 5:
			o.boite(Transform3D(Basis(), p + Vector3(0, y - 0.3 - k * 0.3, z0 + long + 0.05)), Vector3(0.5, 0.04, 0.06), Color("3a3d40"))
		for cote in [-0.25, 0.25]:
			o.boite(Transform3D(Basis(), p + Vector3(cote, y - 0.6, z0 + long + 0.05)), Vector3(0.04, 1.4, 0.04), Color("3a3d40"))
		if opt.get("barque", true):
			_barque(o, p + Vector3(w * 0.5 + 1.0, NIVEAU, z0 + long * 0.55), PI * 0.5 + r.randf_range(-0.08, 0.08), 3)
			o.branche(p + Vector3(w * 0.5 - 0.2, y + 0.3, z0 + 8.5), p + Vector3(w * 0.5 + 0.6, NIVEAU + 0.5, z0 + long * 0.55 + 1.6), 0.015, 0.015, Color("d9c9a0"), 3)
		return Vector3(w + 3.0, z0 + long, y + 1.0)

	## La barque seule, flottant à la surface du fleuve : son origine est la ligne d'eau (posez-la à y = NIVEAU).
	static func barque(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		_barque(o, p, 0.0, o.rng.randi() % 4)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.2, 0)), Vector3(1.4, 0.6, 4.2)])
		return Vector3(1.5, 4.4, 0.6)

	## Une barque de bois à fond plat, longue de 4 m, la proue vers +Z (tournée de lacet), sa couleur tirée parmi
	## quatre ; deux bancs, deux rames.
	static func _barque(o: Outils, c: Vector3, lacet: float, teinte: int) -> void:
		var coques := [Color("2f5a7a"), Color("2f6a4a"), Color("8a2a2e"), Color("e8e0cc")]
		var coque: Color = coques[teinte % coques.size()]
		var b := Basis(Vector3.UP, lacet)
		var demi := 2.0
		var pts := []
		for k in 9:
			var t := float(k) / 8.0
			var z := lerpf(-demi, demi, t)
			var large := 0.68 * (1.0 - pow(absf(t - 0.42) / 0.58, 2.2) * 0.85)
			pts.append([z, maxf(large, 0.06)])
		for k in pts.size() - 1:
			var a: Array = pts[k]
			var n: Array = pts[k + 1]
			var za: float = a[0]
			var zb: float = n[0]
			var la: float = a[1]
			var lb: float = n[1]
			var ha := 0.55 + (0.12 if k >= 6 else 0.0)
			var hb := 0.55 + (0.12 if k + 1 >= 6 else 0.0)
			for cote in [-1.0, 1.0]:
				var q0 := c + b * Vector3(cote * la * 0.75, -0.2, za)
				var q1 := c + b * Vector3(cote * lb * 0.75, -0.2, zb)
				var q2 := c + b * Vector3(cote * lb, hb - 0.2, zb)
				var q3 := c + b * Vector3(cote * la, ha - 0.2, za)
				o.quad(q0, q1, q2, q3, b * Vector3(cote, -0.2, 0), coque)
				# le liseré blanc du plat-bord
				o.quad(q3, q2, q2 + Vector3(0, -0.06, 0), q3 + Vector3(0, -0.06, 0), b * Vector3(cote, 0, 0), Color("f2eadb") if teinte != 3 else Color("2f5a7a"))
			o.quad(c + b * Vector3(-la * 0.75, -0.2, za), c + b * Vector3(la * 0.75, -0.2, za), c + b * Vector3(lb * 0.75, -0.2, zb), c + b * Vector3(-lb * 0.75, -0.2, zb), Vector3.DOWN, coque.darkened(0.3))
			# le plancher intérieur
			o.quad(c + b * Vector3(-la * 0.7, -0.1, za), c + b * Vector3(la * 0.7, -0.1, za), c + b * Vector3(lb * 0.7, -0.1, zb), c + b * Vector3(-lb * 0.7, -0.1, zb), Vector3.UP, BOIS.lightened(0.1))
		for z in [-0.7, 0.5]:
			o.boite(Transform3D(b, c + b * Vector3(0, 0.15, z)), Vector3(1.15, 0.05, 0.28), BOIS.lightened(0.15))
		for cote in [-1.0, 1.0]:
			o.branche(c + b * Vector3(cote * 0.3, 0.22, -0.4), c + b * Vector3(cote * 0.45, 0.25, 1.4), 0.025, 0.025, BOIS.lightened(0.2), 4)
			o.boite(Transform3D(b, c + b * Vector3(cote * 0.46, 0.25, 1.55)), Vector3(0.12, 0.02, 0.45), BOIS.lightened(0.2))
