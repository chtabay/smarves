extends Node3D
## Un objet du mobilier lyonnais, posé tel quel : on règle objet, graine et options avant de l'ajouter à la
## scène, il se bâtit à son entrée dans l'arbre de scène. Le pied est à l'origine, sur un sol plat à y = 0, le
## devant (l'assise d'un banc, l'étal d'un marchand, la volée d'un escalier) regarde +Z ; en mètres (une commune
## à l'échelle du village de Smarves, 1 unité = 2,4 m, la pose à l'échelle 1/2,4).
##   var o = load(Bibliotheque.scene("mobilier-lyonnais@1", "decor")).instantiate()
##   o.objet = "fontaine" ; o.graine = 3
##   add_child(o)
## Après la construction, le nœud porte ses métadonnées : objet, graine, emprise (la taille au sol, Vector2).
const Outils := preload("res://bibliotheque/mobilier-lyonnais/1/outils.gd")

## Les objets : la fontaine monumentale au lion, les bancs, les lampadaires, les bornes, les jardinières, l'étal
## du marché, la terrasse de bistrot, la corbeille, l'escalier urbain, le garde-corps, le kiosque et la colonne
## d'affiches.
const OBJETS := ["fontaine", "banc", "banc_pierre", "lampadaire", "candelabre", "borne", "jardiniere", "vasque",
	"etal", "terrasse", "corbeille", "escalier", "garde_corps", "kiosque", "colonne"]

const PIERRE := Color("e9dcbc")
const PIERRE_SOMBRE := Color("cdbb92")
const FONTE := Color("2e4537")
const FONTE_SOMBRE := Color("223228")
const OR := Color("c9a24a")
const BRONZE := Color("6b5a3a")
const BOIS := Color("a8743f")
const TERRE := Color("6b4f36")
const VERT := Color("5f9e33")
const EAU := Color("4f93ad")
const FLEURS := ["e0605a", "f2c14e", "d04a8a", "b06ad0", "f4f0e6", "e8823a"]
const TOILES := [["b8322c", "f3ead6"], ["2f5f8f", "f3ead6"], ["2f5a3a", "f3ead6"], ["b8322c", "b8322c"], ["e0a93a", "f3ead6"]]
const PRIMEURS := ["e0605a", "f2a23a", "f2d14e", "8cc63f", "b06ad0", "d9473b", "7a4f2a", "4f8f30"]

## L'objet (voir OBJETS).
@export var objet := "banc"
## La graine : la couleur d'une toile, les fleurs d'une jardinière, les primeurs de l'étal, les affiches.
@export var graine := 1
## Les options, toutes facultatives : fleurs (un hexa), toile (deux hexas : les bandes d'un store ou d'un
## parasol), parasol (la terrasse : vrai pour son parasol carré, faux par défaut), allume (false : les lanternes éteintes), longueur (le banc, la jardinière, le garde-corps : en
## mètres), marches (l'escalier : le nombre de marches), eau (false : la fontaine à sec).
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


## Les mêmes, sous le nom commun aux briques lyonnaises.
static func noms() -> Array:
	return objets()


## Bâtit un objet sous parent, son pied en p (sans rotation : tourner le parent). Rend objet, graine, emprise.
static func poser(parent: Node3D, p: Vector3, nom: String, g: int, opt := {}) -> Dictionary:
	if not nom in OBJETS:
		nom = "banc"
	var o := Outils.new(g * 104729 + OBJETS.find(nom) * 31)
	var emprise: Vector2 = Callable(_Objets, nom).call(o, p, opt)
	o.construire(parent, nom.capitalize())
	return {"objet": nom, "graine": g, "emprise": emprise}


class _Objets:
	static func _fleur(o: Outils, opt: Dictionary) -> Color:
		return Color(str(opt.get("fleurs", FLEURS[o.rng.randi() % FLEURS.size()])))

	## Un bouquet de feuilles semé de fleurs, centré en c, de rayon r.
	static func _touffe(o: Outils, c: Vector3, r: float, fleur: Color, n_fleurs := 6) -> void:
		o.boule(c, Vector3(r, r * 0.7, r), VERT.lightened(o.rng.randf_range(-0.05, 0.12)), 0.22, Outils.FEUILLE, 0.06, 0.3)
		for i in n_fleurs:
			var a := o.rng.randf() * TAU
			var y := o.rng.randf_range(0.1, 0.65)
			var d := Vector3(cos(a) * sqrt(1.0 - y * y), y, sin(a) * sqrt(1.0 - y * y))
			o.boule(c + Vector3(d.x * r, d.y * r * 0.7, d.z * r) * 0.92, Vector3.ONE * r * 0.24, fleur.lightened(o.rng.randf_range(-0.08, 0.1)), 0.2, Outils.FEUILLE, 0.05, 0.3)

	## Un lion couché, sculpté, la tête haute, tourné vers +Z ; p est le dessous de son ventre, k son échelle.
	static func _lion(o: Outils, p: Vector3, k: float, col: Color) -> void:
		var crin := col.darkened(0.12)
		# le corps allongé, la croupe, les pattes arrière repliées
		o.boule(p + Vector3(0, 0.42, -0.1) * k, Vector3(0.42, 0.38, 0.85) * k, col, 0.04, Outils.DUR, 0.0)
		o.boule(p + Vector3(0, 0.4, -0.75) * k, Vector3(0.44, 0.4, 0.42) * k, col, 0.04, Outils.DUR, 0.0)
		for cote in [-1.0, 1.0]:
			o.boule(p + Vector3(cote * 0.34, 0.26, -0.68) * k, Vector3(0.18, 0.26, 0.38) * k, col.darkened(0.04), 0.0, Outils.DUR, 0.0)
			o.boule(p + Vector3(cote * 0.3, 0.1, -0.35) * k, Vector3(0.12, 0.1, 0.22) * k, col.darkened(0.04), 0.0, Outils.DUR, 0.0)
			# les pattes avant, allongées devant lui
			o.branche(p + Vector3(cote * 0.24, 0.3, 0.45) * k, p + Vector3(cote * 0.24, 0.1, 1.05) * k, 0.12 * k, 0.1 * k, col, 8)
			o.boule(p + Vector3(cote * 0.24, 0.09, 1.1) * k, Vector3(0.14, 0.09, 0.16) * k, col, 0.0, Outils.DUR, 0.0)
		# le poitrail, la crinière en collerette et la tête
		o.boule(p + Vector3(0, 0.62, 0.45) * k, Vector3(0.4, 0.45, 0.36) * k, crin, 0.0, Outils.DUR, 0.0)
		o.boule(p + Vector3(0, 1.0, 0.55) * k, Vector3(0.48, 0.5, 0.36) * k, crin, 0.22, Outils.DUR, 0.0)
		o.boule(p + Vector3(0, 1.0, 0.78) * k, Vector3(0.26, 0.28, 0.26) * k, col, 0.0, Outils.DUR, 0.0)
		o.boule(p + Vector3(0, 0.92, 0.98) * k, Vector3(0.15, 0.13, 0.14) * k, col.lightened(0.04), 0.0, Outils.DUR, 0.0)
		o.boule(p + Vector3(0, 0.97, 1.08) * k, Vector3(0.06, 0.05, 0.04) * k, col.darkened(0.35), 0.0, Outils.DUR, 0.0)
		for cote in [-1.0, 1.0]:
			o.boule(p + Vector3(cote * 0.18, 1.24, 0.72) * k, Vector3(0.07, 0.08, 0.05) * k, col, 0.0, Outils.DUR, 0.0)
			o.boule(p + Vector3(cote * 0.09, 1.06, 0.98) * k, Vector3(0.035, 0.03, 0.02) * k, col.darkened(0.45), 0.0, Outils.DUR, 0.0)
		# la queue qui s'enroule sur le flanc, la touffe au bout
		var q0 := p + Vector3(0.1, 0.5, -1.1) * k
		var q1 := p + Vector3(0.45, 0.12, -0.9) * k
		var q2 := p + Vector3(0.5, 0.08, -0.35) * k
		o.branche(q0, q1, 0.05 * k, 0.045 * k, col, 6)
		o.branche(q1, q2, 0.045 * k, 0.04 * k, col, 6)
		o.boule(q2 + Vector3(0, 0.02, 0.06) * k, Vector3(0.09, 0.08, 0.13) * k, crin, 0.15, Outils.DUR, 0.0)

	## Un mufle de lion en applique, crachant de l'eau vers d : au centre c, tourné selon la base b.
	static func _mufle(o: Outils, c: Vector3, b: Basis, col: Color, eau: bool, chute: float) -> void:
		o.boule(c, b * Vector3(0.22, 0.24, 0.1), col.darkened(0.1), 0.2, Outils.DUR, 0.0)
		o.boule(c + b * Vector3(0, -0.02, 0.08), Vector3(0.11, 0.12, 0.11), col, 0.0, Outils.DUR, 0.0)
		o.boite(Transform3D(b, c + b * Vector3(0, -0.07, 0.17)), Vector3(0.04, 0.04, 0.16), BRONZE)
		if eau:
			var a := c + b * Vector3(0, -0.07, 0.25)
			var m := a + b * Vector3(0, -chute * 0.35, 0.35)
			var f := a + b * Vector3(0, -chute, 0.55)
			o.branche(a, m, 0.035, 0.05, Color("cdeaf2"), 6)
			o.branche(m, f, 0.05, 0.08, Color("cdeaf2"), 6)

	static func fontaine(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var t := Transform3D(Basis(), p)
		var eau: bool = opt.get("eau", true)
		# le grand bassin octogonal : deux marches, la cuve moulurée, la margelle large, l'eau
		o.cylindre(t.translated(Vector3(0, -0.12, 0)), 5.6, 5.6, 0.3, 8, PIERRE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.18, 0)), 5.15, 5.15, 0.16, 8, PIERRE)
		o.cylindre(t.translated(Vector3(0, 0.34, 0)), 4.75, 4.6, 0.55, 8, PIERRE, Outils.DUR, false)
		o.anneau(t.translated(Vector3(0, 0.89, 0)), 4.1, 4.85, 0.14, 8, PIERRE_SOMBRE)
		o.anneau(t.translated(Vector3(0, 0.34, 0)), 4.08, 4.14, 0.56, 8, PIERRE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.34, 0)), 4.1, 4.1, 0.38 if eau else 0.05, 8, EAU if eau else PIERRE_SOMBRE)
		# des tables sculptées sur les huit pans de la cuve
		for i in 8:
			var a := TAU * (i + 0.5) / 8.0
			var b := Basis(Vector3.UP, -a + PI * 0.5)
			o.boite(Transform3D(b, p + b * Vector3(0, 0.62, 4.29)), Vector3(2.2, 0.3, 0.06), PIERRE_SOMBRE)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(9.6, 1.0, 9.6)])
		# la vasque intermédiaire portée par un fût, qui déborde en nappe
		var b0 := p + Vector3(0, 0.34, 0)
		o.cylindre(Transform3D(Basis(), b0), 1.25, 1.1, 0.5, 8, PIERRE_SOMBRE)
		o.cylindre(Transform3D(Basis(), b0 + Vector3(0, 0.5, 0)), 0.85, 0.85, 1.3, 8, PIERRE)
		o.cylindre(Transform3D(Basis(), b0 + Vector3(0, 1.8, 0)), 1.05, 1.05, 0.16, 8, PIERRE_SOMBRE)
		# les quatre mufles qui crachent dans le grand bassin
		for i in 4:
			var bb := Basis(Vector3.UP, PI * 0.5 * i)
			_mufle(o, b0 + bb * Vector3(0, 1.05, 0.88), bb, PIERRE, eau, 0.7)
		# la coupe large
		o.cylindre(Transform3D(Basis(), b0 + Vector3(0, 1.96, 0)), 0.5, 2.1, 0.45, 16, PIERRE)
		o.anneau(Transform3D(Basis(), b0 + Vector3(0, 2.41, 0)), 1.95, 2.2, 0.12, 16, PIERRE_SOMBRE)
		if eau:
			o.cylindre(Transform3D(Basis(), b0 + Vector3(0, 2.35, 0)), 1.96, 1.96, 0.12, 16, EAU)
		# le haut piédestal carré à corniche, et le lion couché au sommet
		var s := b0 + Vector3(0, 2.4, 0)
		o.boite(Transform3D(Basis(), s + Vector3(0, 0.12, 0)), Vector3(1.6, 0.24, 2.7), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), s + Vector3(0, 0.85, 0)), Vector3(1.3, 1.3, 2.4), PIERRE)
		o.boite(Transform3D(Basis(), s + Vector3(0, 0.85, 1.21)), Vector3(0.8, 0.75, 0.04), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), s + Vector3(0, 0.85, -1.21)), Vector3(0.8, 0.75, 0.04), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), s + Vector3(0, 1.58, 0)), Vector3(1.6, 0.18, 2.7), PIERRE_SOMBRE)
		_lion(o, s + Vector3(0, 1.67, -0.1), 1.1, Color("d8c9a4"))
		o.collisions.append([Transform3D(Basis(), b0 + Vector3(0, 2.4, 0)), Vector3(2.2, 4.8, 2.4)])
		return Vector2(11.2, 11.2)

	static func banc(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 2.0))
		# les deux flancs de fonte verte à volute, l'assise et le dossier galbés en lattes de bois
		for cote in [-1.0, 1.0]:
			var x: float = cote * (l * 0.5 - 0.1)
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.08, 0.15)), Vector3(0.07, 0.6, 0.08), FONTE)
			o.boite(Transform3D(Basis(Vector3.RIGHT, 0.25), p + Vector3(x, 0.15, -0.2)), Vector3(0.07, 0.75, 0.08), FONTE)
			o.boite(Transform3D(Basis(Vector3.RIGHT, -0.3), p + Vector3(x, 0.72, -0.28)), Vector3(0.07, 0.65, 0.07), FONTE)
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.4, -0.02)), Vector3(0.08, 0.07, 0.6), FONTE)
			o.branche(p + Vector3(x, 0.4, 0.26), p + Vector3(x, 0.62, 0.34), 0.03, 0.03, FONTE, 5)
			o.boule(p + Vector3(x, 0.66, 0.32), Vector3(0.05, 0.06, 0.07), FONTE, 0.0, Outils.DUR, 0.0)
		for i in 6:
			var z := 0.24 - i * 0.085
			var y := 0.44 + (0.03 if i == 0 else 0.0) - i * 0.006
			o.boite(Transform3D(Basis(), p + Vector3(0, y, z)), Vector3(l, 0.035, 0.07), BOIS)
		for i in 4:
			var y := 0.6 + i * 0.12
			o.boite(Transform3D(Basis(Vector3.RIGHT, -0.3), p + Vector3(0, y, -0.3 - (y - 0.6) * 0.31)), Vector3(l, 0.08, 0.03), BOIS)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, -0.05)), Vector3(l, 0.9, 0.65)])
		return Vector2(l, 0.75)

	static func banc_pierre(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 2.4))
		# deux dés de pierre et une tablette épaisse, les arêtes adoucies d'un chanfrein
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * (l * 0.5 - 0.3), 0.15, 0)), Vector3(0.4, 0.5, 0.42), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.45, 0)), Vector3(l, 0.12, 0.55), PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.52, 0)), Vector3(l - 0.06, 0.03, 0.49), PIERRE.lightened(0.04))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.25, 0)), Vector3(l, 0.5, 0.55)])
		return Vector2(l, 0.6)

	## La lanterne lyonnaise à pans, son chapeau et son fleuron ; c est le milieu du verre.
	static func _lanterne(o: Outils, c: Vector3, k: float, allume: bool) -> void:
		var lueur := Color("ffe2a0") if allume else Color("d8d4c4")
		o.cylindre(Transform3D(Basis(), c + Vector3(0, -0.28, 0) * k), 0.06 * k, 0.18 * k, 0.14 * k, 6, FONTE)
		o.cylindre(Transform3D(Basis(), c + Vector3(0, -0.16, 0) * k), 0.17 * k, 0.24 * k, 0.4 * k, 6, lueur, Outils.LUEUR if allume else Outils.DUR)
		for i in 6:
			var a := TAU * i / 6.0
			o.branche(c + Vector3(cos(a) * 0.17, -0.16, sin(a) * 0.17) * k, c + Vector3(cos(a) * 0.245, 0.25, sin(a) * 0.245) * k, 0.012 * k, 0.012 * k, FONTE, 4)
		o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.24, 0) * k), 0.3 * k, 0.3 * k, 0.04 * k, 6, FONTE)
		o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.28, 0) * k), 0.3 * k, 0.05 * k, 0.2 * k, 6, FONTE)
		o.boule(c + Vector3(0, 0.52, 0) * k, Vector3.ONE * 0.05 * k, OR, 0.0, Outils.DUR, 0.0)
		o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.46, 0) * k), 0.02 * k, 0.02 * k, 0.06 * k, 4, FONTE)

	## Le fût cannelé de fonte sur son socle à moulures, de hauteur h.
	static func _fut(o: Outils, p: Vector3, h: float) -> void:
		var t := Transform3D(Basis(), p)
		o.cylindre(t.translated(Vector3(0, -0.05, 0)), 0.3, 0.3, 0.12, 8, FONTE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.07, 0)), 0.26, 0.18, 0.6, 8, FONTE)
		o.anneau(t.translated(Vector3(0, 0.4, 0)), 0.15, 0.22, 0.08, 8, OR.darkened(0.2))
		o.cylindre(t.translated(Vector3(0, 0.67, 0)), 0.12, 0.08, h - 0.67, 12, FONTE)
		for i in 8:
			var a := TAU * i / 8.0
			o.branche(p + Vector3(cos(a) * 0.12, 0.8, sin(a) * 0.12), p + Vector3(cos(a) * 0.085, h - 0.1, sin(a) * 0.085), 0.014, 0.012, FONTE_SOMBRE, 4)
		o.anneau(t.translated(Vector3(0, h - 0.12, 0)), 0.07, 0.14, 0.12, 8, FONTE_SOMBRE)

	static func lampadaire(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		# le réverbère lyonnais : fût cannelé, une lanterne à pans au sommet, la barre d'échelle
		_fut(o, p, 3.3)
		o.boite(Transform3D(Basis(), p + Vector3(0, 3.0, 0)), Vector3(0.7, 0.04, 0.04), FONTE)
		for cote in [-1.0, 1.0]:
			o.boule(p + Vector3(cote * 0.36, 3.0, 0), Vector3.ONE * 0.04, OR, 0.0, Outils.DUR, 0.0)
		_lanterne(o, p + Vector3(0, 3.62, 0), 1.0, opt.get("allume", true))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.8, 0)), Vector3(0.4, 3.6, 0.4)])
		return Vector2(0.6, 0.6)

	static func candelabre(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		# le candélabre de place : un fût plus haut, trois crosses à volute et trois lanternes
		_fut(o, p, 4.0)
		o.boule(p + Vector3(0, 4.05, 0), Vector3(0.14, 0.1, 0.14), FONTE, 0.0, Outils.DUR, 0.0)
		for i in 3:
			var a := TAU * i / 3.0 + PI * 0.5
			var d := Vector3(cos(a), 0, sin(a))
			var m := p + Vector3(0, 4.15, 0) + d * 0.45
			o.branche(p + Vector3(0, 3.9, 0), m + Vector3(0, 0.15, 0), 0.04, 0.035, FONTE, 6)
			o.branche(m + Vector3(0, 0.15, 0), p + Vector3(0, 4.2, 0) + d * 0.7, 0.035, 0.03, FONTE, 6)
			o.branche(p + Vector3(0, 3.65, 0), m - Vector3(0, 0.05, 0), 0.02, 0.02, FONTE, 4)
			o.boule(m - Vector3(0, 0.05, 0), Vector3.ONE * 0.05, OR, 0.0, Outils.DUR, 0.0)
			_lanterne(o, p + Vector3(0, 4.5, 0) + d * 0.72, 0.8, opt.get("allume", true))
		_lanterne(o, p + Vector3(0, 4.62, 0), 0.75, opt.get("allume", true))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 2.2, 0)), Vector3(0.45, 4.4, 0.45)])
		return Vector2(1.8, 1.8)

	static func borne(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		# la borne de fonte verte : un fût galbé, deux bagues dorées, la boule au sommet
		var t := Transform3D(Basis(), p)
		o.cylindre(t.translated(Vector3(0, -0.04, 0)), 0.17, 0.15, 0.12, 10, FONTE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.08, 0)), 0.13, 0.1, 0.62, 10, FONTE)
		o.anneau(t.translated(Vector3(0, 0.18, 0)), 0.1, 0.145, 0.04, 10, OR)
		o.anneau(t.translated(Vector3(0, 0.66, 0)), 0.09, 0.13, 0.05, 10, OR)
		o.boule(p + Vector3(0, 0.82, 0), Vector3.ONE * 0.1, FONTE, 0.0, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, 0)), Vector3(0.3, 0.9, 0.3)])
		return Vector2(0.35, 0.35)

	static func jardiniere(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 1.8))
		var fleur := _fleur(o, opt)
		# un bac de pierre dorée à pieds et corniche, des géraniums qui débordent
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				o.boite(Transform3D(Basis(), p + Vector3(cx * (l * 0.5 - 0.1), 0.02, cz * 0.25)), Vector3(0.16, 0.2, 0.16), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.42, 0)), Vector3(l, 0.6, 0.62), PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.15, 0)), Vector3(l + 0.06, 0.07, 0.68), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.74, 0)), Vector3(l + 0.1, 0.07, 0.72), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.42, 0.315)), Vector3(l - 0.3, 0.34, 0.02), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.76, 0)), Vector3(l - 0.12, 0.04, 0.5), TERRE)
		var n := int(l / 0.38)
		for i in n:
			_touffe(o, p + Vector3(-l * 0.5 + 0.24 + i * (l - 0.48) / maxf(1, n - 1), 0.95, o.rng.randf_range(-0.1, 0.1)), o.rng.randf_range(0.24, 0.31), fleur, 7)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.4, 0)), Vector3(l, 0.8, 0.7)])
		return Vector2(l + 0.1, 0.75)

	static func vasque(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var fleur := _fleur(o, opt)
		# la vasque de fonte sur piédouche, en coupe, débordante de fleurs et de lierre
		var t := Transform3D(Basis(), p)
		o.cylindre(t.translated(Vector3(0, -0.04, 0)), 0.32, 0.32, 0.12, 4, PIERRE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.08, 0)), 0.2, 0.11, 0.3, 12, FONTE)
		o.cylindre(t.translated(Vector3(0, 0.38, 0)), 0.13, 0.13, 0.12, 12, FONTE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.5, 0)), 0.18, 0.55, 0.35, 16, FONTE)
		o.anneau(t.translated(Vector3(0, 0.83, 0)), 0.52, 0.6, 0.06, 16, OR.darkened(0.25))
		o.cylindre(t.translated(Vector3(0, 0.85, 0)), 0.5, 0.5, 0.02, 16, TERRE)
		_touffe(o, p + Vector3(0, 1.05, 0), 0.42, fleur, 10)
		for i in 5:
			var a := TAU * i / 5.0 + o.rng.randf() * 0.5
			var d := Vector3(cos(a), 0, sin(a))
			o.boule(p + d * 0.56 + Vector3(0, 0.72, 0), Vector3(0.12, 0.22, 0.12), VERT.darkened(0.12), 0.2, Outils.FEUILLE, 0.05, 0.4)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(1.0, 1.0, 1.0)])
		return Vector2(1.2, 1.2)

	static func etal(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var toile: Array = opt.get("toile", TOILES[o.rng.randi() % TOILES.size()])
		var c1 := Color(str(toile[0]))
		var c2 := Color(str(toile[1]))
		var l := 2.8
		# le banc de marché : quatre pieds, le plateau incliné de cagettes, le store à bandes et son lambrequin
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				o.boite(Transform3D(Basis(), p + Vector3(cx * (l * 0.5 - 0.05), 0.4, cz * 0.45)), Vector3(0.06, 0.9, 0.06), BOIS.darkened(0.25))
			o.boite(Transform3D(Basis(), p + Vector3(cx * (l * 0.5 - 0.05), 1.25, -0.5)), Vector3(0.05, 2.5, 0.05), BOIS.darkened(0.25))
			o.boite(Transform3D(Basis(), p + Vector3(cx * (l * 0.5 - 0.05), 1.95, 0.55)), Vector3(0.05, 1.1, 0.05), BOIS.darkened(0.25))
		o.boite(Transform3D(Basis(Vector3.RIGHT, 0.18), p + Vector3(0, 0.86, 0)), Vector3(l, 0.06, 1.0), BOIS)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.55, 0.5)), Vector3(l, 0.5, 0.03), c1.darkened(0.1))
		for i in 5:
			var x := -l * 0.5 + 0.3 + i * (l - 0.6) / 4.0
			var q := p + Vector3(x, 0.95 - 0.02, 0.0)
			var ca := Basis(Vector3.RIGHT, 0.18)
			o.boite(Transform3D(ca, q), Vector3(0.5, 0.12, 0.8), BOIS.lightened(0.15))
			var fruit := Color(PRIMEURS[o.rng.randi() % PRIMEURS.size()])
			for j in 7:
				var f := q + ca * Vector3(o.rng.randf_range(-0.18, 0.18), 0.1, o.rng.randf_range(-0.3, 0.3))
				o.boule(f, Vector3.ONE * o.rng.randf_range(0.07, 0.1), fruit.lightened(o.rng.randf_range(-0.08, 0.08)), 0.1, Outils.DUR, 0.05)
		# le store
		var n := 7
		for i in n:
			var x0 := -l * 0.5 - 0.1 + i * (l + 0.2) / n
			var x1 := x0 + (l + 0.2) / n
			var col := c1 if i % 2 == 0 else c2
			var a := p + Vector3(x0, 2.5, -0.55)
			var b := p + Vector3(x1, 2.5, -0.55)
			var c := p + Vector3(x1, 2.12, 0.75)
			var d := p + Vector3(x0, 2.12, 0.75)
			o.quad(a, b, c, d, Vector3(0, 1, 0.3), col)
			o.quad(a, b, c, d, Vector3(0, -1, -0.3), col.darkened(0.25))
			o.quad(d, c, c + Vector3(0, -0.22, 0), d + Vector3(0, -0.22, 0), Vector3.BACK, col)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(l, 1.0, 1.0)])
		return Vector2(l + 0.2, 1.4)

	## Une chaise bistrot posée en c, tournée de b (l'assise regarde +Z du repère b) : pieds de bois courbé, assise
	## ronde cannée, dossier en anneau et ses lattes de canne.
	static func _chaise(o: Outils, c: Vector3, b: Basis, bois: Color, canne: Color) -> void:
		var r := 0.2
		o.cylindre(Transform3D(b, c + Vector3(0, 0.44, 0)), r, r, 0.04, 14, canne)
		o.anneau(Transform3D(b, c + Vector3(0, 0.43, 0)), r - 0.01, r + 0.015, 0.06, 14, bois)
		for k in 4:
			o.anneau(Transform3D(b, c + Vector3(0, 0.481, 0)), r * (0.2 + 0.2 * k), r * (0.2 + 0.2 * k) + 0.008, 0.002, 12, canne.darkened(0.18))
		# les pieds évasés, le cercle d'entretoise
		for k in 4:
			var a := TAU * (k + 0.5) / 4.0
			var haut := c + b * Vector3(cos(a), 0, sin(a)) * (r * 0.8) + Vector3(0, 0.43, 0)
			var bas := c + b * Vector3(cos(a), 0, sin(a)) * (r * 1.12) + Vector3(0, -0.02, 0)
			o.branche(bas, haut, 0.016, 0.014, bois, 5)
		o.anneau(Transform3D(b, c + Vector3(0, 0.16, 0)), r * 0.88, r * 0.95, 0.015, 12, bois)
		# le dossier : les deux montants qui prolongent les pieds arrière, l'anneau courbe, les lattes cannées
		var arc := []
		for k in 9:
			var a := lerpf(PI * 1.12, PI * 1.88, k / 8.0)
			arc.append(Vector3(cos(a) * r * 0.95, 0, sin(a) * r * 0.95))
		for k in 8:
			o.branche(c + b * (arc[k] + Vector3(0, 0.86, -0.04)), c + b * (arc[k + 1] + Vector3(0, 0.86, -0.04)), 0.016, 0.016, bois, 5)
			o.branche(c + b * (arc[k] + Vector3(0, 0.62, -0.02)), c + b * (arc[k + 1] + Vector3(0, 0.62, -0.02)), 0.012, 0.012, bois, 4)
		for k in [0, 8]:
			o.branche(c + b * (arc[k] + Vector3(0, 0.44, 0)), c + b * (arc[k] + Vector3(0, 0.86, -0.04)), 0.016, 0.016, bois, 5)
		for k in range(2, 7):
			o.branche(c + b * (arc[k] + Vector3(0, 0.63, -0.02)), c + b * (arc[k] + Vector3(0, 0.85, -0.04)), 0.01, 0.01, canne, 3)

	## Une table bistrot ronde en c : le pied de fonte à trois griffes, la colonne, le plateau de marbre clair.
	static func _table(o: Outils, c: Vector3, marbre: Color) -> void:
		for k in 3:
			var a := TAU * k / 3.0
			var d := Vector3(cos(a), 0, sin(a))
			o.branche(c + Vector3(0, 0.16, 0), c + d * 0.2 + Vector3(0, 0.05, 0), 0.025, 0.02, FONTE_SOMBRE, 5)
			o.branche(c + d * 0.2 + Vector3(0, 0.05, 0), c + d * 0.27 + Vector3(0, 0.0, 0), 0.02, 0.022, FONTE_SOMBRE, 5)
		o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.12, 0)), 0.05, 0.035, 0.08, 8, FONTE_SOMBRE)
		o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.2, 0)), 0.028, 0.028, 0.48, 8, FONTE_SOMBRE)
		o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.66, 0)), 0.03, 0.12, 0.05, 8, FONTE_SOMBRE)
		o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.71, 0)), 0.32, 0.32, 0.03, 20, marbre)
		o.anneau(Transform3D(Basis(), c + Vector3(0, 0.705, 0)), 0.3, 0.325, 0.02, 20, FONTE_SOMBRE.lightened(0.15))
		# les veines grises du marbre
		for k in 3:
			var a := o.rng.randf() * TAU
			var u := Vector3(cos(a), 0, sin(a))
			o.boite(Transform3D(Basis(Vector3.UP, -a), c + Vector3(0, 0.7405, 0) + u.cross(Vector3.UP) * o.rng.randf_range(-0.15, 0.15)), Vector3(0.4, 0.001, 0.006), marbre.darkened(0.22))

	## Ce qu'on a servi sur une table ronde en c : verres à pied, carafe d'eau, tasse et soucoupe, pot de beaujolais.
	static func _service(o: Outils, c: Vector3) -> void:
		var verre := Color("d8e6e2")
		var dessus := c + Vector3(0, 0.74, 0)
		for k in 2:
			var a := o.rng.randf() * TAU
			var q := dessus + Vector3(cos(a), 0, sin(a)) * o.rng.randf_range(0.12, 0.2)
			o.cylindre(Transform3D(Basis(), q), 0.03, 0.03, 0.005, 8, verre)
			o.cylindre(Transform3D(Basis(), q), 0.005, 0.005, 0.07, 4, verre)
			o.cylindre(Transform3D(Basis(), q + Vector3(0, 0.07, 0)), 0.022, 0.035, 0.06, 8, verre)
			if o.rng.randf() < 0.6:
				o.cylindre(Transform3D(Basis(), q + Vector3(0, 0.072, 0)), 0.023, 0.03, 0.025, 8, Color("7a1f3a"))
		if o.rng.randf() < 0.5:
			# le pot lyonnais, à fond épais, de beaujolais
			o.cylindre(Transform3D(Basis(), dessus + Vector3(-0.04, 0, 0.05)), 0.045, 0.04, 0.03, 10, verre)
			o.cylindre(Transform3D(Basis(), dessus + Vector3(-0.04, 0.03, 0.05)), 0.04, 0.035, 0.13, 10, Color("6e1f34"))
		else:
			o.cylindre(Transform3D(Basis(), dessus + Vector3(-0.05, 0, 0.04)), 0.05, 0.04, 0.17, 10, Color("cfe3e6"))
			o.cylindre(Transform3D(Basis(), dessus + Vector3(-0.05, 0.17, 0.04)), 0.02, 0.025, 0.04, 8, Color("cfe3e6"))
		var t := dessus + Vector3(0.1, 0, -0.12)
		o.cylindre(Transform3D(Basis(), t), 0.06, 0.065, 0.008, 12, Color("f4f1ea"))
		o.cylindre(Transform3D(Basis(), t + Vector3(0, 0.008, 0)), 0.03, 0.035, 0.045, 10, Color("f4f1ea"))
		o.cylindre(Transform3D(Basis(), t + Vector3(0, 0.045, 0)), 0.03, 0.03, 0.002, 10, Color("3a2416"))

	static func terrasse(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var toile: Array = opt.get("toile", TOILES[o.rng.randi() % TOILES.size()])
		# deux tables bistrot rondes, deux ou trois chaises cannées chacune, tournées vers la rue ou l'une vers
		# l'autre ; ce qu'on y a servi ; les jardinières de buis taillé qui ferment la terrasse
		var bois := Color("3b2618") if o.rng.randf() < 0.6 else Color("2a2d2a")
		var canne := Color("cfa86a")
		var marbre := Color("ece6da")
		for k in 2:
			var c := p + Vector3(-0.9 + k * 1.8, 0, 0)
			_table(o, c, marbre)
			_service(o, c)
			var n := 2 + (1 if o.rng.randf() < 0.5 else 0)
			for i in n:
				var a := PI * 0.5 + TAU * i / n + o.rng.randf_range(-0.25, 0.25)
				var d := Vector3(cos(a), 0, sin(a))
				_chaise(o, c + d * 0.52, Basis(Vector3.UP, atan2(-d.x, -d.z)), bois, canne)
		for cote in [-1.0, 1.0]:
			var j := p + Vector3(cote * 2.05, 0, 0)
			o.boite(Transform3D(Basis(), j + Vector3(0, 0.25, 0)), Vector3(0.45, 0.5, 1.6), Color("2f4a3a"))
			o.boite(Transform3D(Basis(), j + Vector3(0, 0.51, 0)), Vector3(0.5, 0.04, 1.65), FONTE_SOMBRE)
			for i in 3:
				var q := j + Vector3(0, 0.78, -0.5 + i * 0.5)
				o.boule(q, Vector3(0.26, 0.28, 0.26), VERT.darkened(0.15).lightened(o.rng.randf_range(-0.05, 0.08)), 0.1, Outils.FEUILLE, 0.04, 0.15)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, 0)), Vector3(4.6, 0.9, 1.6)])
		if not bool(opt.get("parasol", false)):
			return Vector2(4.6, 1.7)
		# le parasol carré à quatre pans et son lambrequin, au milieu de la terrasse
		o.cylindre(Transform3D(Basis(), p), 0.3, 0.3, 0.1, 4, FONTE_SOMBRE)
		o.cylindre(Transform3D(Basis(), p), 0.035, 0.035, 2.5, 6, Color("efe8d8"))
		var haut := p + Vector3(0, 2.6, 0)
		var r := 1.75
		var coins := [Vector3(-r, 2.1, -r), Vector3(r, 2.1, -r), Vector3(r, 2.1, r), Vector3(-r, 2.1, r)]
		for i in 4:
			var a: Vector3 = p + coins[i]
			var b: Vector3 = p + coins[(i + 1) % 4]
			var col := Color(str(toile[i % 2]))
			o.tri(haut, a, b, Vector3.UP, col)
			o.tri(haut, a, b, Vector3.DOWN, col.darkened(0.25))
			var nn: Vector3 = ((a + b) * 0.5 - p).normalized()
			o.quad(a, b, b + Vector3(0, -0.2, 0), a + Vector3(0, -0.2, 0), Vector3(nn.x, 0, nn.z), Color(str(toile[0])))
		return Vector2(4.6, 3.6)

	static func corbeille(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		# la corbeille de fonte verte, ajourée de barreaux, sur son pied
		var t := Transform3D(Basis(), p)
		o.cylindre(t.translated(Vector3(0, -0.03, 0)), 0.16, 0.16, 0.08, 8, FONTE_SOMBRE)
		o.cylindre(t, 0.05, 0.05, 0.4, 6, FONTE)
		o.cylindre(t.translated(Vector3(0, 0.38, 0)), 0.2, 0.2, 0.04, 12, FONTE)
		o.cylindre(t.translated(Vector3(0, 0.42, 0)), 0.18, 0.18, 0.5, 12, Color("1f2a24"))
		for i in 12:
			var a := TAU * i / 12.0
			o.boite(Transform3D(Basis(Vector3.UP, -a), p + Vector3(cos(a) * 0.205, 0.67, sin(a) * 0.205)), Vector3(0.04, 0.55, 0.02), FONTE)
		o.anneau(t.translated(Vector3(0, 0.93, 0)), 0.18, 0.25, 0.05, 12, FONTE)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.48, 0)), Vector3(0.5, 0.96, 0.5)])
		return Vector2(0.5, 0.5)

	static func escalier(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		# l'escalier urbain des pentes : des marches de pierre entre deux murs d'échiffre, une rampe de fer
		var n := int(opt.get("marches", 8))
		var l := float(opt.get("longueur", 3.0))
		var g := 0.38
		var hm := 0.17
		var prof := n * g
		for i in n:
			var z := -i * g
			o.boite(Transform3D(Basis(), p + Vector3(0, (i + 1) * hm * 0.5 - 0.1, z - g * 0.5)), Vector3(l, (i + 1) * hm + 0.2, g), PIERRE_SOMBRE.lightened(0.03 * (i % 2)))
			o.boite(Transform3D(Basis(), p + Vector3(0, (i + 1) * hm - 0.02, z - 0.03)), Vector3(l, 0.04, 0.08), PIERRE)
		for cote in [-1.0, 1.0]:
			var x: float = cote * (l * 0.5 + 0.2)
			var pts := PackedVector2Array([Vector2(0.15, -0.1), Vector2(0.15, 0.55), Vector2(-prof, n * hm + 0.55), Vector2(-prof - 0.4, n * hm + 0.55), Vector2(-prof - 0.4, -0.1)])
			o.profil(Transform3D(Basis(Vector3.UP, -PI * 0.5), p + Vector3(x + 0.2, 0, 0)), pts, 0.0, 0.4, [PIERRE, PIERRE_SOMBRE])
			# la rampe : main courante et barreaux
			var a := p + Vector3(x, 0.55 + 0.95, 0.1)
			var b := p + Vector3(x, n * hm + 0.55 + 0.95, -prof)
			o.branche(a, b, 0.03, 0.03, FONTE, 6)
			for k in n + 1:
				var f := k / float(n)
				var q := a.lerp(b, f)
				o.branche(Vector3(q.x, q.y - 0.95, q.z), q, 0.012, 0.012, FONTE, 4)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, n * hm * 0.5, -prof * 0.5)), Vector3(l + 0.8, n * hm, prof)])
		return Vector2(l + 0.8, prof + 0.4)

	static func garde_corps(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 4.0))
		# un garde-corps de quai : deux dés de pierre, une lisse, des barreaux et une frise de cercles
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * (l * 0.5 - 0.2), 0.45, 0)), Vector3(0.4, 1.1, 0.4), PIERRE)
			o.boite(Transform3D(Basis(), p + Vector3(cote * (l * 0.5 - 0.2), 1.04, 0)), Vector3(0.48, 0.08, 0.48), PIERRE_SOMBRE)
		var li := l - 0.8
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.12, 0)), Vector3(li, 0.06, 0.06), FONTE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.98, 0)), Vector3(li, 0.07, 0.09), FONTE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.82, 0)), Vector3(li, 0.03, 0.03), FONTE)
		var n := int(li / 0.13)
		for i in n + 1:
			var x := -li * 0.5 + i * li / n
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.47, 0)), Vector3(0.022, 0.7, 0.022), FONTE)
		var m := int(li / 0.26)
		for i in m:
			var x := -li * 0.5 + (i + 0.5) * li / m
			o.anneau(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(x, 0.9, 0.015)), 0.045, 0.06, 0.03, 10, FONTE)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(l, 1.0, 0.3)])
		return Vector2(l, 0.5)

	static func kiosque(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		# le kiosque à journaux : un octogone de fonte verte, les vitrines et les affiches, le dôme et sa lanterne
		var t := Transform3D(Basis(), p)
		var r := 1.25
		o.cylindre(t.translated(Vector3(0, -0.06, 0)), r + 0.15, r + 0.15, 0.2, 8, PIERRE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.14, 0)), r, r, 0.75, 8, FONTE)
		o.cylindre(t.translated(Vector3(0, 0.89, 0)), r - 0.05, r - 0.05, 1.3, 8, Color("efe6cf"))
		var affiches := ["c8463c", "2f5f8f", "e0a93a", "f3ead6", "4f7f4a", "b06ad0"]
		for i in 8:
			var a := TAU * (i + 0.5) / 8.0
			var b := Basis(Vector3.UP, -a + PI * 0.5)
			var c := p + b * Vector3(0, 1.54, r * 0.924)
			o.boite(Transform3D(b, c), Vector3(0.8, 1.2, 0.03), Color(affiches[(i + o.rng.randi()) % affiches.size()]))
			o.boite(Transform3D(b, c + b * Vector3(0, 0.25, 0.02)), Vector3(0.6, 0.3, 0.02), Color("f4efe2"))
		for i in 8:
			var a := TAU * i / 8.0
			o.branche(p + Vector3(cos(a) * r, 0.9, sin(a) * r), p + Vector3(cos(a) * r, 2.25, sin(a) * r), 0.04, 0.04, FONTE, 6)
		o.cylindre(t.translated(Vector3(0, 2.2, 0)), r + 0.25, r + 0.25, 0.14, 8, FONTE)
		o.cylindre(t.translated(Vector3(0, 2.34, 0)), r + 0.35, r + 0.35, 0.05, 8, FONTE_SOMBRE)
		# le bandeau, le dôme et la lanterne
		o.cylindre(t.translated(Vector3(0, 2.39, 0)), r + 0.05, r + 0.05, 0.3, 8, FONTE)
		o.cylindre(t.translated(Vector3(0, 2.69, 0)), r + 0.25, 0.25, 0.85, 8, FONTE_SOMBRE.lightened(0.05))
		o.cylindre(t.translated(Vector3(0, 3.0, 0)), r * 0.62, 0.22, 0.4, 8, FONTE)
		o.cylindre(t.translated(Vector3(0, 3.5, 0)), 0.16, 0.16, 0.25, 8, OR)
		o.cylindre(t.translated(Vector3(0, 3.75, 0)), 0.26, 0.02, 0.4, 8, FONTE)
		o.boule(p + Vector3(0, 4.2, 0), Vector3.ONE * 0.06, OR, 0.0, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.3, 0)), Vector3(r * 2, 2.6, r * 2)])
		return Vector2(r * 2 + 0.5, r * 2 + 0.5)

	static func colonne(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		# la colonne d'affiches : socle, fût couvert d'affiches en bandes, corniche et petit dôme
		var t := Transform3D(Basis(), p)
		o.cylindre(t.translated(Vector3(0, -0.05, 0)), 0.72, 0.72, 0.25, 16, FONTE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.2, 0)), 0.6, 0.6, 2.2, 16, Color("efe6cf"))
		var affiches := ["c8463c", "2f5f8f", "e0a93a", "4f7f4a", "b06ad0", "f3ead6", "1f2a2a"]
		for i in 6:
			var a := TAU * i / 6.0 + o.rng.randf() * 0.2
			var b := Basis(Vector3.UP, -a + PI * 0.5)
			var h := o.rng.randf_range(0.7, 1.1)
			o.boite(Transform3D(b, p + b * Vector3(0, 0.45 + h * 0.5 + o.rng.randf_range(0.0, 0.6), 0.6)), Vector3(0.55, h, 0.02), Color(affiches[o.rng.randi() % affiches.size()]))
		o.cylindre(t.translated(Vector3(0, 2.4, 0)), 0.75, 0.75, 0.14, 16, FONTE)
		o.cylindre(t.translated(Vector3(0, 2.54, 0)), 0.65, 0.65, 0.2, 16, FONTE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 2.74, 0)), 0.7, 0.08, 0.55, 16, FONTE)
		o.boule(p + Vector3(0, 3.36, 0), Vector3.ONE * 0.09, OR, 0.0, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.4, 0)), Vector3(1.4, 2.8, 1.4)])
		return Vector2(1.5, 1.5)
