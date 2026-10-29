extends Node3D
## Un module des sols et des quais lyonnais, posé tel quel : on règle module, graine et options avant de
## l'ajouter à la scène, il se bâtit à son entrée dans l'arbre de scène. Les modules se posent bout à bout sur
## une trame de 4 m : le sol de la ville est à y = 0, le module est centré sur l'origine, son devant (le
## parement d'un mur, le pied d'un escalier, la bordure du trottoir) regarde +Z ; en mètres (une commune à
## l'échelle du village de Smarves, 1 unité = 2,4 m, la pose à l'échelle 1/2,4).
##   var m = load(Bibliotheque.scene("quais-lyonnais@1", "decor")).instantiate()
##   m.module = "mur_quai_haut" ; m.options = {"eau": true}
##   add_child(m)
## Après la construction, le nœud porte ses métadonnées : module, graine, emprise (Vector2, la taille au sol),
## haut (la hauteur du niveau supérieur où il mène : 0 pour un sol, la terrasse d'un escalier ou d'une arche).
## Le quai haut et le pont descendent jusqu'à l'eau, 3,4 m sous la ville.
const Outils := preload("res://bibliotheque/quais-lyonnais/1/outils.gd")

## Les modules : les pavés en rangs et en éventail, la dalle de quai, la bordure de trottoir, l'escalier bas et
## l'escalier haut, l'arche simple, l'arche dans son mur de soutènement, le passage voûté avec son escalier, le
## mur de quai bas (un parapet) et le mur de quai haut (qui tombe dans la rivière), le pont à trois arches.
const MODULES := ["paves", "paves_eventail", "dalle", "bordure", "escalier_bas", "escalier_haut", "arche",
	"arche_mur", "passage_escalier", "mur_quai_bas", "mur_quai_haut", "pont"]

const TRAME := 4.0
const EAU := -3.4
const PIERRE := Color("dcc391")
const PIERRE_CLAIRE := Color("e8d6ad")
const PIERRE_SOMBRE := Color("bfa676")
const JOINT := Color("8f8370")
const PAVES := ["a99d88", "b5a993", "9c917e", "c0b49e", "a3967f"]
const DALLES := ["c9bda4", "bfb399", "d3c8b0", "b8ac92"]
const RIVIERE := Color("4f8399")
const FER := Color("2a2d30")
const SOMBRE := Color("3a3430")

## Le module (voir MODULES).
@export var module := "paves"
## La graine : la teinte de chaque pavé, de chaque dalle, de chaque bloc.
@export var graine := 1
## Les options, toutes facultatives : eau (vrai : le mur de quai haut et le pont avec leur bout de rivière),
## largeur (les murs, les sols, le passage : en mètres, 4 par défaut), parapet (faux : l'arche dans son mur sans
## le garde-corps de la terrasse).
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
		nom = "paves"
	var o := Outils.new(g * 15485863 + MODULES.find(nom) * 7)
	var mesures: Vector3 = Callable(_Modules, nom).call(o, p, opt)
	o.construire(parent, nom.capitalize())
	return {"module": nom, "graine": g, "emprise": Vector2(mesures.x, mesures.y), "haut": mesures.z}


class _Modules:
	## Un pavé : sa seule face de dessus, à peine bombée en teinte, posée sur le lit de joints.
	static func _pave(o: Outils, c: Vector3, a: float, sx: float, sz: float, col: Color) -> void:
		var b := Basis(Vector3.UP, a)
		var hx := b * Vector3(sx * 0.5, 0, 0)
		var hz := b * Vector3(0, 0, sz * 0.5)
		o.quad(c - hx - hz, c + hx - hz, c + hx + hz, c - hx + hz, Vector3.UP, col)

	static func _teinte(o: Outils, liste: Array) -> Color:
		return Color(liste[o.rng.randi() % liste.size()]).lightened(o.rng.randf_range(-0.04, 0.05))

	## Le lit de joints et l'épaisseur du sol sous un carré de pavés.
	static func _lit(o: Outils, p: Vector3, w: float, d: float, col := JOINT) -> void:
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.16, 0)), Vector3(w, 0.3, d), [col.darkened(0.2), col.darkened(0.2), col, col.darkened(0.3), col.darkened(0.1), col.darkened(0.1)])
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, -0.16, 0)), Vector3(w, 0.3, d)])

	## Des pavés en rangs décalés sur w × d, la face à y (dans le repère de p).
	static func _rangs(o: Outils, p: Vector3, w: float, d: float, y := 0.0) -> void:
		var pas := 0.22
		var nz := int(d / pas)
		for j in nz:
			var z := -d * 0.5 + (j + 0.5) * d / nz
			var dec := 0.11 if j % 2 == 1 else 0.0
			var x := -w * 0.5 + dec
			while x < w * 0.5 - 0.02:
				var l := minf(o.rng.randf_range(0.22, 0.3), w * 0.5 - x)
				if l > 0.06:
					_pave(o, p + Vector3(x + l * 0.5, y, z), 0.0, l - 0.025, d / nz - 0.025, _teinte(o, PAVES))
				x += l

	static func paves(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		_lit(o, p, w, TRAME)
		_rangs(o, p, w, TRAME)
		return Vector3(w, TRAME, 0.0)

	static func paves_eventail(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		_lit(o, p, w, TRAME)
		# les pavés posés en arcs de cercle, les éventails en quinconce, un rang par rayon
		var R := 1.0
		var rangee := 0
		var z := TRAME * 0.5 + R * 0.5
		while z > -TRAME * 0.5 - R:
			var cx := -w * 0.5 - R + (R if rangee % 2 == 1 else 0.0)
			while cx < w * 0.5 + R:
				for k in 5:
					var r := R * (k + 0.5) / 5.0
					var n := maxi(2, int(PI * 0.5 * r / 0.2))
					for i in n:
						var a := PI * 0.25 + PI * 0.5 * (i + 0.5) / n
						var q := Vector3(cx + cos(a) * r, 0, z - sin(a) * r)
						if absf(q.x) < w * 0.5 - 0.1 and absf(q.z) < TRAME * 0.5 - 0.1:
							_pave(o, p + q, -a + PI * 0.5, PI * 0.5 * r / n - 0.025, R / 5.0 - 0.025, _teinte(o, PAVES))
				cx += R * 2.0
			z -= R * 0.5
			rangee += 1
		return Vector3(w, TRAME, 0.0)

	static func dalle(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		_lit(o, p, w, TRAME, Color("a89c86"))
		# de grandes dalles de pierre claire en rangs de largeurs inégales
		var z := -TRAME * 0.5
		var j := 0
		while z < TRAME * 0.5 - 0.05:
			var d := minf([0.8, 0.6, 1.0][j % 3], TRAME * 0.5 - z)
			var x := -w * 0.5
			if j % 2 == 1:
				x -= 0.5
			while x < w * 0.5:
				var l := o.rng.randf_range(0.9, 1.4)
				var x0 := maxf(x, -w * 0.5)
				var x1 := minf(x + l, w * 0.5)
				if x1 - x0 > 0.1:
					_pave(o, p + Vector3((x0 + x1) * 0.5, 0, z + d * 0.5), 0.0, x1 - x0 - 0.02, d - 0.02, _teinte(o, DALLES))
				x += l
			z += d
			j += 1
		return Vector3(w, TRAME, 0.0)

	static func bordure(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		# au fond le trottoir de dalles, relevé de 15 cm ; la bordure de granit ; le caniveau ; la chaussée pavée
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.08, -1.0)), Vector3(w, 0.46, 2.0), Color("a89c86"))
		var x := -w * 0.5
		while x < w * 0.5 - 0.05:
			var l := minf(0.6, w * 0.5 - x)
			for k in 3:
				_pave(o, p + Vector3(x + l * 0.5, 0.155, -1.85 + k * 0.6 + 0.3), 0.0, l - 0.02, 0.58, _teinte(o, DALLES))
			x += l
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.0, -0.08)), Vector3(w, 0.36, 0.2), [PIERRE_SOMBRE, PIERRE_SOMBRE, Color("b4ab9c"), Color("b4ab9c"), Color("a39a8a"), Color("a39a8a")])
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.15, -0.02)), Vector3(w, 0.04, 0.1), Color("c2b9a9"))
		_lit(o, p + Vector3(0, 0, 1.0), w, 2.0)
		# le caniveau : deux rangs de pavés en léger creux
		for k in 2:
			var xx := -w * 0.5
			while xx < w * 0.5 - 0.02:
				_pave(o, p + Vector3(xx + 0.11, -0.03, 0.12 + k * 0.2), 0.0, 0.2, 0.18, _teinte(o, PAVES).darkened(0.08))
				xx += 0.22
		_rangs(o, p + Vector3(0, 0, 1.25), w, 1.5)
		return Vector3(w, TRAME, 0.15)

	## Une volée de n marches, du pied (z0, y0) en montant vers −Z, de giron g et de hauteur hm, de largeur l.
	static func _volee(o: Outils, p: Vector3, l: float, n: int, z0: float, y0: float, g: float, hm: float) -> void:
		for i in n:
			var z := z0 - i * g
			var y := y0 + (i + 1) * hm
			o.boite(Transform3D(Basis(), p + Vector3(0, (y - 0.1 + y0 - 0.25) * 0.5, z - g * 0.5)), Vector3(l, y - y0 + 0.15, g), [PIERRE_SOMBRE, PIERRE_SOMBRE, PIERRE_CLAIRE, PIERRE_SOMBRE, PIERRE, PIERRE_SOMBRE])
			o.boite(Transform3D(Basis(), p + Vector3(0, y - 0.025, z - 0.03)), Vector3(l + 0.02, 0.05, 0.08), PIERRE_CLAIRE.lightened(0.03))

	## Un mur d'échiffre plein, de profil donné (x le long de −Z, y la hauteur), d'épaisseur e, en x.
	static func _echiffre(o: Outils, p: Vector3, x: float, pts: PackedVector2Array, e: float) -> void:
		o.profil(Transform3D(Basis(Vector3.UP, PI * 0.5), p + Vector3(x - e * 0.5, 0, 0)), pts, 0.0, e, [PIERRE, PIERRE_SOMBRE])

	static func escalier_bas(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		var l := w - 0.8
		# six marches qui montent d'un mètre, puis le palier ; deux murets à couronnement
		var n := 6
		var hm := 1.0 / n
		var g := 0.36
		_volee(o, p, l, n, TRAME * 0.5, 0.0, g, hm)
		var zp := TRAME * 0.5 - n * g
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.45, (zp - TRAME * 0.5) * 0.5)), Vector3(l, 1.1, zp + TRAME * 0.5), PIERRE_SOMBRE)
		_rangs(o, p + Vector3(0, 0, (zp - TRAME * 0.5) * 0.5), l, zp + TRAME * 0.5, 1.0)
		for cote in [-1.0, 1.0]:
			var x: float = cote * (w * 0.5 - 0.2)
			var pts := PackedVector2Array([Vector2(-TRAME * 0.5, -0.1), Vector2(-TRAME * 0.5, 0.5), Vector2(-zp, 1.5), Vector2(TRAME * 0.5, 1.5), Vector2(TRAME * 0.5, -0.1)])
			_echiffre(o, p, x, pts, 0.4)
			o.boite(Transform3D(Basis(), p + Vector3(x, 1.55, (zp - TRAME * 0.5) * 0.5)), Vector3(0.5, 0.1, zp + TRAME * 0.5), PIERRE_CLAIRE)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(w, 1.0, TRAME)])
		return Vector3(w, TRAME, 1.0)

	static func escalier_haut(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		var l := w - 0.8
		var d := 6.0
		# deux volées de huit marches et un palier pour monter de trois mètres, la rampe de fer sur les murs
		var n := 8
		var hm := 3.0 / (n * 2)
		var g := 0.3
		var z1 := d * 0.5 - n * g
		_volee(o, p, l, n, d * 0.5, 0.0, g, hm)
		o.boite(Transform3D(Basis(), p + Vector3(0, n * hm * 0.5 - 0.1, z1 - 0.5)), Vector3(l, n * hm + 0.2, 1.0), PIERRE_SOMBRE)
		_rangs(o, p + Vector3(0, 0, z1 - 0.5), l, 1.0, n * hm)
		_volee(o, p, l, n, z1 - 1.0, n * hm, g, hm)
		var z2 := z1 - 1.0 - n * g
		if z2 > -d * 0.5:
			o.boite(Transform3D(Basis(), p + Vector3(0, 1.4, (z2 - d * 0.5) * 0.5)), Vector3(l, 3.2, z2 + d * 0.5), PIERRE_SOMBRE)
			_rangs(o, p + Vector3(0, 0, (z2 - d * 0.5) * 0.5), l, z2 + d * 0.5, 3.0)
		for cote in [-1.0, 1.0]:
			var x: float = cote * (w * 0.5 - 0.2)
			var pts := PackedVector2Array([Vector2(-d * 0.5, -0.1), Vector2(-d * 0.5, 0.6), Vector2(-z1, n * hm + 0.6), Vector2(-z1 + 1.0, n * hm + 0.6), Vector2(-z2, 3.6), Vector2(d * 0.5, 3.6), Vector2(d * 0.5, -0.1)])
			_echiffre(o, p, x, pts, 0.4)
			# la main courante qui suit les deux volées
			var rampe := [Vector3(x, 1.5, d * 0.5 - 0.1), Vector3(x, n * hm + 1.5, z1), Vector3(x, n * hm + 1.5, z1 - 1.0), Vector3(x, 3.0 + 1.5, z2)]
			for k in 3:
				var a: Vector3 = p + rampe[k]
				var b: Vector3 = p + rampe[k + 1]
				o.branche(a, b, 0.03, 0.03, FER, 6)
				var m := int(a.distance_to(b) / 0.5)
				for i in m:
					var q := a.lerp(b, float(i) / m)
					o.branche(q - Vector3(0, 0.55, 0), q, 0.015, 0.015, FER, 4)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.5, 0)), Vector3(w, 3.0, d)])
		return Vector3(w, d, 3.0)

	## Le profil d'un mur de largeur w et de hauteur h, percé en bas d'une arche de demi-largeur r, sur pieds droits
	## de hauteur hp.
	static func _mur_arche(w: float, h: float, r: float, hp: float) -> PackedVector2Array:
		var pts := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(-r, 0), Vector2(-r, hp)])
		for i in range(1, 16):
			var a := PI - PI * i / 16.0
			pts.append(Vector2(cos(a) * r, hp + sin(a) * r))
		pts.append_array(PackedVector2Array([Vector2(r, hp), Vector2(r, 0), Vector2(w * 0.5, 0), Vector2(w * 0.5, h), Vector2(-w * 0.5, h)]))
		return pts

	## Les claveaux de l'arche, en saillie sur le parement à z, la clef plus haute ; et les impostes.
	static func _claveaux(o: Outils, p: Vector3, r: float, hp: float, z: float, e: float) -> void:
		var n := 13
		for i in n:
			var a0 := PI - PI * i / n
			var a1 := PI - PI * (i + 1) / n
			var clef := i == n / 2
			var r1 := r + (0.62 if clef else 0.45) + (0.06 if i % 2 == 0 else 0.0)
			var pts := PackedVector2Array([Vector2(cos(a0), sin(a0)) * r, Vector2(cos(a0), sin(a0)) * r1, Vector2(cos(a1), sin(a1)) * r1, Vector2(cos(a1), sin(a1)) * r])
			for k in pts.size():
				pts[k] += Vector2(0, hp)
			o.profil(Transform3D(Basis(), p), pts, z, z + e, [PIERRE_CLAIRE if i % 2 == 0 else PIERRE, PIERRE_SOMBRE])
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * (r + 0.2), hp - 0.08, z + e * 0.5)), Vector3(0.6, 0.16, e + 0.08), PIERRE_CLAIRE)

	## Des bossages en assises sur un parement de largeur w, de y0 à y1, en z, sauf dans l'arche.
	static func _assises(o: Outils, p: Vector3, w: float, y0: float, y1: float, z: float, r: float, hp: float) -> void:
		var y := y0
		var j := 0
		while y < y1 - 0.1:
			var h := minf(0.5, y1 - y)
			var x := -w * 0.5 + (0.0 if j % 2 == 0 else 0.45)
			while x < w * 0.5 - 0.05:
				var l := minf(o.rng.randf_range(0.8, 1.2), w * 0.5 - x)
				var cx := x + l * 0.5
				var dedans := absf(cx) < r + 0.55 and y < hp + r + 0.6
				if not dedans and l > 0.15:
					o.boite(Transform3D(Basis(), p + Vector3(cx, y + h * 0.5, z + 0.02)), Vector3(l - 0.04, h - 0.04, 0.04), _teinte(o, ["dcc391", "d3b986", "e2cb9c", "cfb37e"]))
				x += l
			y += h
			j += 1

	static func arche(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		var e := 1.0
		var r := 1.2
		var hp := 2.4
		var h := 4.5
		# un arc en plein cintre sur deux piles, à claveaux, imposte et corniche
		o.profil(Transform3D(Basis(), p), _mur_arche(w, h, r, hp), -e * 0.5, e * 0.5, [PIERRE, PIERRE_SOMBRE])
		for s in [-1.0, 1.0]:
			_claveaux(o, p, r, hp, s * e * 0.5 - (0.05 if s < 0 else 0.0), 0.05)
			o.boite(Transform3D(Basis(), p + Vector3(0, h - 0.4, s * (e * 0.5 + 0.04))), Vector3(w, 0.12, 0.08), PIERRE_CLAIRE)
			for cote in [-1.0, 1.0]:
				o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 - 0.3), 0.25, s * (e * 0.5 + 0.03))), Vector3(0.62, 0.5, 0.06), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.08, 0)), Vector3(w + 0.2, 0.16, e + 0.25), PIERRE_CLAIRE)
		for cote in [-1.0, 1.0]:
			o.collisions.append([Transform3D(Basis(), p + Vector3(cote * (w * 0.5 + r) * 0.5, h * 0.5, 0)), Vector3(w * 0.5 - r, h, e)])
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, (hp + r + h) * 0.5, 0)), Vector3(w, h - hp - r, e)])
		return Vector3(w, e, h)

	static func arche_mur(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		var h := 4.0
		var r := 1.1
		var hp := 1.6
		# le mur de soutènement en bossages, une arche aveugle fermée d'une grille sur une cave sombre ; au-dessus,
		# la terrasse pavée et son parapet
		o.profil(Transform3D(Basis(), p), _mur_arche(w, h, r, hp), -0.7, 0.0, [PIERRE, PIERRE_SOMBRE])
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.1, -0.9)), Vector3(2.0 * r + 0.2, 0.2, 1.6), SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.6, -1.55)), Vector3(2.0 * r + 0.2, 3.4, 0.1), SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, hp + r + 0.15, -1.1)), Vector3(2.0 * r + 0.2, 0.3, 1.0), SOMBRE.lightened(0.1))
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * (r + 0.05), 1.4, -1.1)), Vector3(0.1, 2.8, 0.9), SOMBRE.lightened(0.05))
		for i in 9:
			var x := -r + (i + 0.5) * 2.0 * r / 9
			var top := hp + sqrt(maxf(0.0, r * r - x * x)) - 0.05
			o.boite(Transform3D(Basis(), p + Vector3(x, top * 0.5, -0.35)), Vector3(0.03, top, 0.03), FER)
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.2, -0.35)), Vector3(2.0 * r, 0.05, 0.04), FER)
		_assises(o, p, w, 0.0, h - 0.4, 0.0, r, hp)
		_claveaux(o, p, r, hp, 0.0, 0.08)
		o.boite(Transform3D(Basis(), p + Vector3(0, h - 0.2, 0.06)), Vector3(w, 0.4, 0.14), PIERRE_CLAIRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, h - 0.43, 0.04)), Vector3(w, 0.06, 0.1), PIERRE_SOMBRE)
		# la terrasse au niveau haut, de 3 m de fond, et le garde-corps
		o.boite(Transform3D(Basis(), p + Vector3(0, h * 0.5 - 0.1, -2.2)), Vector3(w, h - 0.2, 3.0), PIERRE_SOMBRE)
		_rangs(o, p + Vector3(0, 0, -2.2), w, 3.0, h)
		if opt.get("parapet", true):
			o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.08, -0.2)), Vector3(w, 0.16, 0.4), PIERRE_CLAIRE)
			o.boite(Transform3D(Basis(), p + Vector3(0, h + 1.0, -0.2)), Vector3(w, 0.06, 0.08), FER)
			var m := int(w / 0.14)
			for i in m + 1:
				o.boite(Transform3D(Basis(), p + Vector3(-w * 0.5 + i * w / m, h + 0.58, -0.2)), Vector3(0.02, 0.84, 0.02), FER)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, h * 0.5, -1.85)), Vector3(w, h, 3.7)])
		return Vector3(w, 3.7, h)

	static func passage_escalier(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		var h := 4.0
		var r := 1.0
		var hp := 2.2
		var d := 8.0
		# un passage voûté dans le mur, puis l'escalier à ciel ouvert entre deux murs, jusqu'à la terrasse haute
		o.profil(Transform3D(Basis(), p), _mur_arche(w, h + 0.4, r, hp), -2.0, 0.0, [PIERRE, PIERRE_SOMBRE])
		_assises(o, p, w, 0.0, h, 0.0, r, hp)
		_claveaux(o, p, r, hp, 0.0, 0.08)
		o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.1, 0.06)), Vector3(w, 0.2, 0.14), PIERRE_CLAIRE)
		var n := 22
		var hm := h / n
		var g := (d - 0.6) / n
		_volee(o, p, 2.0 * r, n, 0.0, 0.0, g, hm)
		for cote in [-1.0, 1.0]:
			var x: float = cote * (r + 0.3)
			var pts := PackedVector2Array([Vector2(2.0, -0.1), Vector2(2.0, h + 0.4), Vector2(d - 0.6, h + 0.9), Vector2(d, h + 0.9), Vector2(d, -0.1)])
			_echiffre(o, p, x, pts, 0.6)
		# le palier haut et sa lanterne d'applique sous la voûte
		o.boite(Transform3D(Basis(), p + Vector3(0, h * 0.5, -d + 0.3)), Vector3(2.0 * r, h, 0.6), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, hp + r - 0.25, -1.0)), Vector3(0.18, 0.28, 0.18), Color("ffe2a0"), Outils.LUEUR)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, h * 0.5, -d * 0.5)), Vector3(w, h, d)])
		return Vector3(w, d, h)

	static func mur_quai_bas(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		# le parapet de quai : un mur bas en pierre dorée, son couronnement débordant et des dés tous les 4 m
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.38, 0)), Vector3(w, 0.95, 0.5), PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.05, 0)), Vector3(w, 0.25, 0.62), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.92, 0)), Vector3(w, 0.14, 0.66), PIERRE_CLAIRE)
		var x := -w * 0.5
		var j := 0
		while x < w * 0.5 - 0.05:
			var l := minf(o.rng.randf_range(0.7, 1.1), w * 0.5 - x)
			for s in [-1.0, 1.0]:
				o.boite(Transform3D(Basis(), p + Vector3(x + l * 0.5, 0.52, s * 0.255)), Vector3(l - 0.03, 0.56, 0.02), _teinte(o, ["dcc391", "d3b986", "e2cb9c"]))
			x += l
			j += 1
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 - 0.3), 0.6, 0)), Vector3(0.6, 1.3, 0.72), PIERRE_CLAIRE)
			o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 - 0.3), 1.28, 0)), Vector3(0.7, 0.1, 0.8), PIERRE_SOMBRE)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(w, 1.0, 0.66)])
		return Vector3(w, 0.8, 0.0)

	static func mur_quai_haut(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		var w := float(opt.get("largeur", TRAME))
		var bas := EAU - 0.4
		# le mur du quai, un peu en fruit, qui tombe dans la rivière : assises de pierre, couronnement, un anneau
		# d'amarrage et une échelle de fer
		var pts := PackedVector2Array([Vector2(-1.0, bas), Vector2(0.3, bas), Vector2(0.0, 0.0), Vector2(-1.0, 0.0)])
		o.profil(Transform3D(Basis(Vector3.UP, -PI * 0.5), p + Vector3(w * 0.5, 0, 0)), pts, 0.0, w, [PIERRE_SOMBRE, PIERRE])
		var y := bas
		var j := 0
		while y < -0.3:
			var h := 0.45
			var x := -w * 0.5 + (0.0 if j % 2 == 0 else 0.4)
			var z := (y + h * 0.5) / bas * 0.3 * -1.0
			while x < w * 0.5 - 0.05:
				var l := minf(o.rng.randf_range(0.7, 1.1), w * 0.5 - x)
				var col := _teinte(o, ["c9b07c", "bfa676", "d3b986", "b39c6e"])
				if y + h < EAU + 0.5:
					col = col.darkened(0.25)
				o.boite(Transform3D(Basis(Vector3.RIGHT, -0.08), p + Vector3(x + l * 0.5, y + h * 0.5, -z + 0.02)), Vector3(l - 0.03, h - 0.03, 0.04), col)
				x += l
			y += h
			j += 1
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.12, 0.05)), Vector3(w, 0.3, 0.3), PIERRE_CLAIRE)
		_lit(o, p + Vector3(0, 0, -1.2), w, 1.4, Color("a89c86"))
		var x := -w * 0.5
		while x < w * 0.5 - 0.05:
			_pave(o, p + Vector3(x + 0.5, 0, -1.2), 0.0, 0.98, 1.38, _teinte(o, DALLES))
			x += 1.0
		# l'anneau d'amarrage et l'échelle
		o.anneau(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(-0.8, -1.4, 0.17)), 0.12, 0.16, 0.04, 10, FER)
		o.boite(Transform3D(Basis(), p + Vector3(-0.8, -1.25, 0.12)), Vector3(0.08, 0.1, 0.1), FER)
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(1.0 + cote * 0.22, (EAU - 0.2) * 0.5, 0.16)), Vector3(0.04, -EAU + 0.2, 0.04), FER)
		var k := 0
		var yy := -0.2
		while yy > EAU - 0.2:
			o.boite(Transform3D(Basis(), p + Vector3(1.0, yy, 0.16)), Vector3(0.44, 0.03, 0.03), FER)
			yy -= 0.3
			k += 1
		if opt.get("eau", false):
			o.quad(p + Vector3(-w * 0.5, EAU, 0.3), p + Vector3(w * 0.5, EAU, 0.3), p + Vector3(w * 0.5, EAU, TRAME), p + Vector3(-w * 0.5, EAU, TRAME), Vector3.UP, RIVIERE)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, -0.5, -0.5)), Vector3(w, 1.0, 1.0)])
		return Vector3(w, 2.0, 0.0)

	## Une voûte surbaissée (une demi-ellipse) de centre cx, de demi-ouverture s et de flèche f, sur l'eau.
	static func _arc_pont(cx: float, s: float, f: float, y0: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 17:
			var a := PI - PI * i / 16.0
			pts.append(Vector2(cx + cos(a) * s, y0 + sin(a) * f))
		return pts

	static func pont(o: Outils, p: Vector3, opt: Dictionary) -> Vector3:
		# le pont de pierre à trois arches surbaissées, sa corniche, ses avant-becs et ses parapets
		var L := 24.0
		var e := 3.0
		var fond := EAU - 0.4
		var travees := [[-7.6, 3.0, 2.5], [0.0, 3.5, 2.8], [7.6, 3.0, 2.5]]
		var pts := PackedVector2Array([Vector2(-L * 0.5, fond)])
		for t in travees:
			var cx: float = t[0]
			var s: float = t[1]
			pts.append(Vector2(cx - s, fond))
			pts.append_array(_arc_pont(cx, s, t[2], EAU))
			pts.append(Vector2(cx + s, fond))
		pts.append_array(PackedVector2Array([Vector2(L * 0.5, fond), Vector2(L * 0.5, 0.0), Vector2(-L * 0.5, 0.0)]))
		o.profil(Transform3D(Basis(), p), pts, -e, e, [PIERRE, PIERRE_SOMBRE])
		# les claveaux en saillie autour de chaque voûte, sur les deux têtes
		for t in travees:
			var cx: float = t[0]
			var s: float = t[1]
			var f: float = t[2]
			for zs in [-1.0, 1.0]:
				var n := 15
				for i in n:
					var a0 := PI - PI * i / n
					var a1 := PI - PI * (i + 1) / n
					var ep := 0.55 + (0.12 if i % 2 == 0 else 0.0)
					var q := PackedVector2Array([
						Vector2(cx + cos(a0) * s, EAU + sin(a0) * f), Vector2(cx + cos(a0) * (s + ep), EAU + sin(a0) * (f + ep)),
						Vector2(cx + cos(a1) * (s + ep), EAU + sin(a1) * (f + ep)), Vector2(cx + cos(a1) * s, EAU + sin(a1) * f)])
					var z0: float = zs * e if zs > 0 else -e - 0.06
					o.profil(Transform3D(Basis(), p), q, z0, z0 + 0.06, [PIERRE_CLAIRE if i % 2 == 0 else PIERRE, PIERRE_SOMBRE])
		# les avant-becs triangulaires des deux piles, en amont et en aval, avec leur chapeau
		for i in 2:
			var cx: float = (travees[i][0] + travees[i][1] + travees[i + 1][0] - travees[i + 1][1]) * 0.5
			var lp: float = (travees[i + 1][0] - travees[i + 1][1]) - (travees[i][0] + travees[i][1])
			# un losange étiré qui déborde des deux têtes, en pointe vers l'amont et l'aval
			var rz := e + lp * 1.1
			var etire := Basis.from_scale(Vector3(lp * 0.62 / rz, 1.0, 1.0))
			var hb := EAU + 1.5 - fond
			o.cylindre(Transform3D(etire, p + Vector3(cx, fond, 0)), rz, rz, hb, 4, PIERRE_SOMBRE)
			o.cylindre(Transform3D(etire, p + Vector3(cx, fond + hb, 0)), rz, rz * 0.4, 0.7, 4, PIERRE)
		# la corniche, le tablier pavé, les parapets pleins à couronnement
		for zs in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(0, -0.25, zs * (e + 0.12))), Vector3(L, 0.22, 0.24), PIERRE_CLAIRE)
			o.boite(Transform3D(Basis(), p + Vector3(0, 0.5, zs * (e - 0.25))), Vector3(L, 1.0, 0.5), PIERRE)
			o.boite(Transform3D(Basis(), p + Vector3(0, 1.05, zs * (e - 0.25))), Vector3(L + 0.1, 0.12, 0.62), PIERRE_CLAIRE)
		_rangs(o, p + Vector3(0, 0.0, 0), L, 2.0 * e - 1.0, 0.01)
		if opt.get("eau", false):
			o.quad(p + Vector3(-L * 0.5, EAU, -e - 4.0), p + Vector3(L * 0.5, EAU, -e - 4.0), p + Vector3(L * 0.5, EAU, e + 4.0), p + Vector3(-L * 0.5, EAU, e + 4.0), Vector3.UP, RIVIERE)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, -0.4, 0)), Vector3(L, 0.8, 2.0 * e)])
		for zs in [-1.0, 1.0]:
			o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.55, zs * (e - 0.25))), Vector3(L, 1.1, 0.5)])
		return Vector3(L, 2.0 * e, 0.0)
