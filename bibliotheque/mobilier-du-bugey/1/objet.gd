extends Node3D
## Un objet du mobilier du Bugey, posé tel quel : on règle objet, graine et options avant de l'ajouter à la scène,
## il se bâtit à son entrée dans l'arbre de scène. Le pied est à l'origine, sur un sol plat à y = 0, le devant
## (l'assise d'un banc, l'étal d'un marchand, le bec d'une fontaine) regarde +Z ; en mètres (une commune à
## l'échelle du village de Smarves, 1 unité = 2,4 m, la pose à l'échelle 1/2,4).
##   var o = load(Bibliotheque.scene("mobilier-du-bugey@1", "decor")).instantiate()
##   o.objet = "fontaine_statue" ; o.graine = 3
##   add_child(o)
## Après la construction, le nœud porte ses métadonnées : objet, graine, emprise (la taille au sol, Vector2).
const Outils := preload("res://bibliotheque/mobilier-du-bugey/1/outils.gd")

## Les objets : la fontaine ronde à la statue de bronze, la fontaine à vasque, le bachal (la fontaine-abreuvoir
## de pierre), l'étal de marché, la charrette, les tonneaux, les caisses, le banc de bois et le banc à pieds de
## fer, le panneau d'affichage, le puits, la jardinière de place, l'enseigne forgée sur son poteau, le lampadaire
## à deux lanternes, la tonnelle de vigne, le muret de pierre et la table de terrasse.
const OBJETS := ["fontaine_statue", "fontaine", "bachal", "etal", "charrette", "tonneaux", "caisses", "banc", "banc_fer",
	"panneau", "puits", "jardiniere", "enseigne", "lampadaire", "tonnelle", "muret", "table"]

const PIERRE := Color("e3d5b2")
const PIERRE_SOMBRE := Color("c6b48c")
const MOELLON := Color("d6c59c")
const BRONZE := Color("55625a")
const BRONZE_CLAIR := Color("6f7e72")
const BOIS := Color("9a6a3e")
const BOIS_SOMBRE := Color("6b4a32")
const FER := Color("2a2d30")
const TERRE := Color("6b4f36")
const VERT := Color("5f9e33")
const EAU := Color("5b9bb3")
const TUILE := Color("c8583b")
const FLEURS := ["e0605a", "f2c14e", "d04a8a", "b06ad0", "f4f0e6", "e8823a"]
const TOILES := [["b8322c", "f3ead6"], ["4f8a4a", "f3ead6"], ["2f5f8f", "f3ead6"], ["d08a3a", "f3ead6"], ["b8322c", "b8322c"]]
const PRIMEURS := ["e0605a", "f2a23a", "f2d14e", "8cc63f", "b06ad0", "d9473b", "7a4f2a", "4f8f30"]
## Ce que vend l'étal : les primeurs, les fromages (la tomme, le bleu), les fleurs, le vin du Bugey.
const MARCHANDISES := ["primeurs", "fromages", "fleurs", "vin"]

## L'objet (voir OBJETS).
@export var objet := "fontaine_statue"
## La graine : la toile d'un étal, ce qu'il vend, les fleurs d'une jardinière, la charge d'une charrette.
@export var graine := 1
## Les options, toutes facultatives : fleurs (un hexa), toile (deux hexas : les bandes d'un store), marchandise
## (l'étal : un nom de MARCHANDISES), allume (false : les lanternes éteintes), longueur (le banc, la jardinière, le
## muret : en mètres), eau (false : la fontaine à sec).
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


## Les mêmes, sous le nom commun aux briques du Bugey.
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

	## Un mur de moellons, de a à b (au sol), de hauteur h et d'épaisseur e, sous sa couvertine de pierre.
	static func _maconne(o: Outils, a: Vector3, b: Vector3, h: float, e: float) -> void:
		var r := o.rng
		var dir := b - a
		var l := dir.length()
		var bb := Basis(Vector3.UP, atan2(-dir.z, dir.x))
		var c := (a + b) * 0.5
		o.boite(Transform3D(bb, c + Vector3(0, (h - 0.1) * 0.5 - 0.05, 0)), Vector3(l, h, e), MOELLON.darkened(0.15), Outils.DUR, true)
		var y := -0.02
		while y < h - 0.25:
			var hh := r.randf_range(0.16, 0.26)
			var x := -l * 0.5
			while x < l * 0.5 - 0.1:
				var lx := minf(r.randf_range(0.25, 0.6), l * 0.5 - x)
				var col := MOELLON.lightened(r.randf_range(-0.12, 0.1))
				for cote in [-1.0, 1.0]:
					o.boite(Transform3D(bb, c + bb * Vector3(x + lx * 0.5, y + hh * 0.5, cote * (e * 0.5 + 0.015))), Vector3(lx - 0.04, hh - 0.04, 0.04), col)
				x += lx
			y += hh
		o.boite(Transform3D(bb, c + Vector3(0, h - 0.05, 0)), Vector3(l + 0.06, 0.12, e + 0.12), PIERRE)

	## Une statue de bronze sur son socle : un homme debout dans sa longue robe, un livre à la main, le regard au
	## loin ; p est le dessus du socle, k l'échelle.
	static func _statue(o: Outils, p: Vector3, k: float) -> void:
		var c := BRONZE
		var t := Transform3D(Basis(), p)
		# la robe qui tombe en cloche jusqu'au sol, ses plis
		o.cylindre(t, 0.42 * k, 0.24 * k, 1.25 * k, 12, c)
		for i in 6:
			var a := TAU * i / 6.0 + 0.3
			o.branche(p + Vector3(cos(a) * 0.38, 0.0, sin(a) * 0.38) * k, p + Vector3(cos(a) * 0.22, 1.1, sin(a) * 0.22) * k, 0.05 * k, 0.02 * k, c.darkened(0.08), 5)
		# le buste, les épaules, le col, la tête et le bonnet
		o.boule(p + Vector3(0, 1.4, 0) * k, Vector3(0.3, 0.32, 0.22) * k, c, 0.0, Outils.DUR, 0.0)
		o.boule(p + Vector3(0, 1.6, 0) * k, Vector3(0.34, 0.12, 0.2) * k, c.lightened(0.04), 0.0, Outils.DUR, 0.0)
		o.cylindre(Transform3D(Basis(), p + Vector3(0, 1.66, 0) * k), 0.1 * k, 0.09 * k, 0.12 * k, 8, c)
		o.boule(p + Vector3(0, 1.88, 0.02) * k, Vector3(0.14, 0.17, 0.15) * k, BRONZE_CLAIR, 0.0, Outils.DUR, 0.0)
		o.boule(p + Vector3(0, 1.88, 0.15) * k, Vector3(0.03, 0.04, 0.04) * k, BRONZE_CLAIR, 0.0, Outils.DUR, 0.0)
		o.cylindre(Transform3D(Basis(), p + Vector3(0, 1.99, -0.01) * k), 0.15 * k, 0.12 * k, 0.12 * k, 10, c.darkened(0.1))
		# le bras droit qui tient le livre ouvert, le bras gauche le long du corps, la main sur la robe
		o.branche(p + Vector3(0.28, 1.58, 0) * k, p + Vector3(0.32, 1.25, 0.12) * k, 0.08 * k, 0.07 * k, c, 6)
		o.branche(p + Vector3(0.32, 1.25, 0.12) * k, p + Vector3(0.14, 1.32, 0.34) * k, 0.07 * k, 0.06 * k, c, 6)
		o.boite(Transform3D(Basis(Vector3.RIGHT, -0.7), p + Vector3(0.05, 1.36, 0.38) * k), Vector3(0.34, 0.03, 0.24) * k, BRONZE_CLAIR)
		o.branche(p + Vector3(-0.28, 1.58, 0) * k, p + Vector3(-0.34, 1.2, 0.02) * k, 0.08 * k, 0.07 * k, c, 6)
		o.branche(p + Vector3(-0.34, 1.2, 0.02) * k, p + Vector3(-0.3, 0.95, 0.1) * k, 0.07 * k, 0.06 * k, c, 6)
		o.boule(p + Vector3(-0.29, 0.92, 0.12) * k, Vector3(0.06, 0.07, 0.05) * k, BRONZE_CLAIR, 0.0, Outils.DUR, 0.0)

	static func fontaine_statue(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var t := Transform3D(Basis(), p)
		var eau: bool = opt.get("eau", true)
		var fleur := _fleur(o, opt)
		# le parterre rond qui entoure le bassin, sa bordure de pierre, les fleurs
		o.cylindre(t.translated(Vector3(0, -0.2, 0)), 4.3, 4.3, 0.3, 24, PIERRE_SOMBRE)
		o.anneau(t.translated(Vector3(0, 0.0, 0)), 3.0, 4.1, 0.32, 24, PIERRE)
		o.anneau(t.translated(Vector3(0, 0.25, 0)), 3.15, 3.95, 0.1, 24, TERRE)
		for i in 26:
			var a := TAU * i / 26.0 + o.rng.randf_range(-0.05, 0.05)
			var rr := o.rng.randf_range(3.3, 3.8)
			var col := fleur if i % 3 != 0 else Color(FLEURS[o.rng.randi() % FLEURS.size()])
			_touffe(o, p + Vector3(cos(a) * rr, 0.42, sin(a) * rr), o.rng.randf_range(0.22, 0.32), col, 5)
		# le bassin rond : la cuve, la margelle, l'eau
		o.anneau(t, 2.55, 3.0, 0.62, 24, PIERRE)
		o.anneau(t.translated(Vector3(0, 0.62, 0)), 2.45, 3.08, 0.12, 24, PIERRE_SOMBRE.lightened(0.1))
		o.cylindre(t, 2.56, 2.56, 0.42 if eau else 0.05, 24, EAU if eau else PIERRE_SOMBRE)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.4, 0)), Vector3(6.0, 0.8, 6.0)])
		# le piédestal au milieu, ses quatre becs, la petite vasque
		o.cylindre(t, 0.95, 0.85, 0.8, 16, PIERRE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.8, 0)), 1.1, 1.1, 0.14, 16, PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.55, 0)), Vector3(0.95, 1.3, 0.95), PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 2.25, 0)), Vector3(1.15, 0.14, 1.15), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.0, 0)), Vector3(1.1, 0.14, 1.1), PIERRE_SOMBRE)
		for i in 4:
			var bb := Basis(Vector3.UP, PI * 0.5 * i)
			o.boite(Transform3D(bb, p + bb * Vector3(0, 1.6, 0.5)), Vector3(0.5, 0.6, 0.04), PIERRE_SOMBRE)
			o.cylindre(Transform3D(bb * Basis(Vector3.RIGHT, PI * 0.5), p + bb * Vector3(0, 1.35, 0.47)), 0.035, 0.035, 0.3, 6, BRONZE)
			if eau:
				o.branche(p + bb * Vector3(0, 1.35, 0.78), p + bb * Vector3(0, 0.95, 1.05), 0.03, 0.05, Color("cdeaf2"), 6)
				o.branche(p + bb * Vector3(0, 0.95, 1.05), p + bb * Vector3(0, 0.42, 1.2), 0.05, 0.07, Color("cdeaf2"), 6)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.2, 0)), Vector3(1.2, 2.4, 1.2)])
		_statue(o, p + Vector3(0, 2.32, 0), 1.2)
		return Vector2(8.6, 8.6)

	static func fontaine(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var t := Transform3D(Basis(), p)
		var eau: bool = opt.get("eau", true)
		# le bassin rond sur sa marche, la colonne, la vasque, le pommeau qui verse
		o.cylindre(t.translated(Vector3(0, -0.15, 0)), 2.1, 2.1, 0.27, 20, PIERRE_SOMBRE)
		o.anneau(t.translated(Vector3(0, 0.1, 0)), 1.55, 1.85, 0.55, 20, PIERRE)
		o.anneau(t.translated(Vector3(0, 0.65, 0)), 1.48, 1.92, 0.1, 20, PIERRE_SOMBRE.lightened(0.1))
		o.cylindre(t.translated(Vector3(0, 0.1, 0)), 1.56, 1.56, 0.4 if eau else 0.05, 20, EAU if eau else PIERRE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.1, 0)), 0.45, 0.35, 0.6, 10, PIERRE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.7, 0)), 0.22, 0.2, 1.1, 10, PIERRE)
		o.cylindre(t.translated(Vector3(0, 1.8, 0)), 0.2, 0.8, 0.3, 16, PIERRE)
		o.anneau(t.translated(Vector3(0, 2.1, 0)), 0.72, 0.85, 0.08, 16, PIERRE_SOMBRE)
		if eau:
			o.cylindre(t.translated(Vector3(0, 2.0, 0)), 0.73, 0.73, 0.12, 16, EAU)
		o.cylindre(t.translated(Vector3(0, 2.1, 0)), 0.1, 0.08, 0.35, 8, PIERRE)
		o.boule(p + Vector3(0, 2.55, 0), Vector3(0.15, 0.18, 0.15), PIERRE, 0.0, Outils.DUR, 0.0)
		if eau:
			for i in 4:
				var a := TAU * i / 4.0 + PI * 0.25
				var d := Vector3(cos(a), 0, sin(a))
				o.branche(p + Vector3(0, 2.15, 0) + d * 0.86, p + Vector3(0, 1.3, 0) + d * 1.0, 0.04, 0.06, Color("cdeaf2"), 6)
				o.branche(p + Vector3(0, 1.3, 0) + d * 1.0, p + Vector3(0, 0.5, 0) + d * 1.05, 0.06, 0.08, Color("cdeaf2"), 6)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.4, 0)), Vector3(3.7, 0.8, 3.7)])
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.3, 0)), Vector3(0.6, 2.6, 0.6)])
		return Vector2(4.2, 4.2)

	static func bachal(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var eau: bool = opt.get("eau", true)
		# le pilier de pierre à chapiteau, son bec de bronze ; l'auge monolithe longue, l'eau, le trop-plein
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.9, -0.85)), Vector3(0.6, 1.9, 0.5), PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.05, -0.85)), Vector3(0.75, 0.2, 0.65), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.9, -0.85)), Vector3(0.75, 0.14, 0.62), PIERRE_SOMBRE)
		o.cylindre(Transform3D(Basis(Vector3.UP, PI * 0.25), p + Vector3(0, 1.97, -0.85)), 0.42, 0.0, 0.4, 4, PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.3, -0.59)), Vector3(0.32, 0.32, 0.03), PIERRE_SOMBRE)
		o.cylindre(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0, 1.05, -0.6)), 0.035, 0.03, 0.3, 6, BRONZE)
		if eau:
			o.branche(p + Vector3(0, 1.05, -0.3), p + Vector3(0, 0.8, -0.16), 0.03, 0.04, Color("cdeaf2"), 6)
			o.branche(p + Vector3(0, 0.8, -0.16), p + Vector3(0, 0.6, -0.12), 0.04, 0.05, Color("cdeaf2"), 6)
		var l := float(opt.get("longueur", 2.6))
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.08, 0.2)), Vector3(l, 0.16, 1.0), PIERRE_SOMBRE)
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * (l * 0.5 - 0.09), 0.42, 0.2)), Vector3(0.18, 0.6, 1.0), PIERRE)
			o.boite(Transform3D(Basis(), p + Vector3(0, 0.42, 0.2 + cote * 0.41)), Vector3(l, 0.6, 0.18), PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.55 if eau else 0.2, 0.2)), Vector3(l - 0.36, 0.06, 0.64), EAU if eau else PIERRE_SOMBRE)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.36, 0.2)), Vector3(l, 0.72, 1.0)])
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.0, -0.85)), Vector3(0.6, 2.0, 0.5)])
		return Vector2(l, 2.0)

	## Un cageot de bois, sa charge : des fruits ronds, des fromages, des bouquets ou des bouteilles.
	static func _cageot(o: Outils, t: Transform3D, quoi: String) -> void:
		var r := o.rng
		o.boite(t * Transform3D(Basis(), Vector3(0, 0.06, 0)), Vector3(0.5, 0.12, 0.38), BOIS.lightened(0.15))
		match quoi:
			"fromages":
				for k in 3:
					var jaune := Color("e8c870") if r.randf() < 0.6 else Color("ece6d2")
					o.cylindre(t * Transform3D(Basis(), Vector3(-0.15 + k * 0.15, 0.12, 0)), 0.08, 0.08, 0.08 + k % 2 * 0.06, 10, jaune)
				o.cylindre(t * Transform3D(Basis(), Vector3(0, 0.12, -0.1)), 0.16, 0.16, 0.08, 14, Color("d9b45a"))
			"fleurs":
				for k in 4:
					var q := Vector3(-0.17 + k * 0.11, 0.25, r.randf_range(-0.08, 0.08))
					o.branche(t * Vector3(q.x, 0.1, q.z), t * q, 0.012, 0.01, VERT.darkened(0.2), 4)
					o.boule(t * q, Vector3(0.08, 0.07, 0.08), Color(FLEURS[r.randi() % FLEURS.size()]), 0.2, Outils.FEUILLE, 0.05, 0.3)
			"vin":
				for k in 6:
					var q := Vector3(-0.18 + (k % 3) * 0.18, 0.12, -0.08 + (k / 3) * 0.16)
					var verre := Color("2f4a2a") if k % 2 == 0 else Color("6a2a3a")
					o.cylindre(t * Transform3D(Basis(), q), 0.04, 0.04, 0.22, 8, verre)
					o.cylindre(t * Transform3D(Basis(), q + Vector3(0, 0.22, 0)), 0.04, 0.015, 0.1, 8, verre)
			_:
				var fruit := Color(PRIMEURS[r.randi() % PRIMEURS.size()])
				for j in 8:
					var f := Vector3(r.randf_range(-0.18, 0.18), 0.17, r.randf_range(-0.12, 0.12))
					o.boule(t * f, Vector3.ONE * r.randf_range(0.06, 0.09), fruit.lightened(r.randf_range(-0.08, 0.08)), 0.1, Outils.DUR, 0.05)

	static func etal(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var r := o.rng
		var toile: Array = opt.get("toile", TOILES[r.randi() % TOILES.size()])
		var c1 := Color(str(toile[0]))
		var c2 := Color(str(toile[1]))
		var quoi := str(opt.get("marchandise", MARCHANDISES[r.randi() % MARCHANDISES.size()]))
		var l := 2.4
		# le comptoir de planches sur ses tréteaux, le jupon de bois, les quatre montants
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.05, 0)), Vector3(l + 0.2, 0.12, 1.2), BOIS_SOMBRE.darkened(0.2))
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.45, 0.42)), Vector3(l, 0.8, 0.05), BOIS)
		for k in int(l / 0.2):
			o.boite(Transform3D(Basis(), p + Vector3(-l * 0.5 + (k + 0.5) * 0.2, 0.45, 0.45)), Vector3(0.02, 0.78, 0.02), BOIS_SOMBRE)
		o.boite(Transform3D(Basis(Vector3.RIGHT, 0.15), p + Vector3(0, 0.88, 0.05)), Vector3(l, 0.06, 0.9), BOIS.lightened(0.1))
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				o.boite(Transform3D(Basis(), p + Vector3(cx * (l * 0.5 - 0.05), 1.1, cz * 0.45)), Vector3(0.07, 2.2 + (0.25 if cz < 0 else 0.0), 0.07), BOIS_SOMBRE)
		for i in 4:
			var x := -l * 0.5 + 0.32 + i * (l - 0.64) / 3.0
			_cageot(o, Transform3D(Basis(Vector3.RIGHT, 0.15), p + Vector3(x, 0.92, 0.05)), quoi)
		# l'arrière : une étagère et des caisses
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.35, -0.4)), Vector3(l, 0.05, 0.3), BOIS)
		for i in 3:
			_cageot(o, Transform3D(Basis(), p + Vector3(-0.7 + i * 0.7, 1.38, -0.4)), quoi)
		# le toit de toile à bandes, à deux pentes inégales, et son lambrequin
		var n := 6
		for i in n:
			var x0 := -l * 0.5 - 0.1 + i * (l + 0.2) / n
			var x1 := x0 + (l + 0.2) / n
			var col := c1 if i % 2 == 0 else c2
			var a := p + Vector3(x0, 2.6, -0.6)
			var b := p + Vector3(x1, 2.6, -0.6)
			var c := p + Vector3(x1, 2.2, 0.7)
			var d := p + Vector3(x0, 2.2, 0.7)
			o.quad(a, b, c, d, Vector3(0, 1, 0.3), col)
			o.quad(a, b, c, d, Vector3(0, -1, -0.3), col.darkened(0.25))
			var xm := (x0 + x1) * 0.5
			o.profil(Transform3D(Basis(), p + Vector3(xm, 2.2, 0.7)), Outils.arc(Vector2.ZERO, (x1 - x0) * 0.5, PI, TAU, 6), -0.01, 0.01, col)
			o.boite(Transform3D(Basis(), p + Vector3(xm, 2.15, 0.7)), Vector3(x1 - x0, 0.1, 0.02), col)
		# l'ardoise du marchand, son prix à la craie
		o.boite(Transform3D(Basis(Vector3.RIGHT, -0.2), p + Vector3(l * 0.5 - 0.4, 0.35, 0.75)), Vector3(0.45, 0.6, 0.04), Color("2c2c2a"))
		o.boite(Transform3D(Basis(Vector3.RIGHT, -0.2), p + Vector3(l * 0.5 - 0.4, 0.4, 0.78)), Vector3(0.3, 0.04, 0.01), Color("e8e4d8"))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(l, 1.0, 1.0)])
		return Vector2(l + 0.2, 1.4)

	## Une roue de bois cerclée de fer : moyeu, rais, jante ; centre c, axe selon x.
	static func _roue(o: Outils, c: Vector3, rayon: float) -> void:
		var b := Basis(Vector3.BACK, PI * 0.5)
		o.anneau(Transform3D(b, c + Vector3(-0.05, 0, 0)), rayon - 0.08, rayon, 0.1, 18, BOIS_SOMBRE)
		o.anneau(Transform3D(b, c + Vector3(-0.055, 0, 0)), rayon - 0.005, rayon + 0.02, 0.11, 18, FER)
		o.cylindre(Transform3D(b, c + Vector3(-0.1, 0, 0)), 0.1, 0.1, 0.2, 10, BOIS_SOMBRE)
		for i in 10:
			var a := TAU * i / 10.0
			o.branche(c + Vector3(0, cos(a), sin(a)) * 0.08, c + Vector3(0, cos(a), sin(a)) * (rayon - 0.06), 0.025, 0.02, BOIS, 4)

	static func charrette(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var r := o.rng
		# la caisse de planches à ridelles, l'essieu, les deux grandes roues, les brancards qui reposent au sol
		var y := 0.85
		o.boite(Transform3D(Basis(), p + Vector3(0, y, 0)), Vector3(1.3, 0.08, 2.0), BOIS)
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * 0.65, y + 0.25, 0)), Vector3(0.05, 0.4, 2.0), BOIS.darkened(0.08))
			for k in 4:
				o.boite(Transform3D(Basis(), p + Vector3(cote * 0.68, y + 0.25, -0.9 + k * 0.6)), Vector3(0.05, 0.5, 0.06), BOIS_SOMBRE)
			o.boite(Transform3D(Basis(), p + Vector3(0, y + 0.25, cote * 1.0)), Vector3(1.3, 0.4, 0.05), BOIS.darkened(0.08))
			_roue(o, p + Vector3(cote * 0.82, 0.62, -0.1), 0.62)
			o.branche(p + Vector3(cote * 0.45, y - 0.05, 0.9), p + Vector3(cote * 0.35, 0.05, 2.5), 0.05, 0.045, BOIS_SOMBRE, 5)
		o.branche(p + Vector3(-0.82, 0.62, -0.1), p + Vector3(0.82, 0.62, -0.1), 0.05, 0.05, FER, 6)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.25, -0.9)), Vector3(0.08, 0.6, 0.08), BOIS_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.04, -0.9)), Vector3(0.3, 0.1, 0.3), PIERRE_SOMBRE)
		# la charge : des tonneaux couchés, des cageots, une botte de paille
		var charge := r.randi() % 3
		if charge == 0:
			for k in 2:
				o.cylindre(Transform3D(Basis(Vector3.BACK, PI * 0.5), p + Vector3(0.45, y + 0.33, -0.5 + k * 0.9)), 0.28, 0.28, 0.9, 10, Color("8a5a36"))
		elif charge == 1:
			for k in 4:
				_cageot(o, Transform3D(Basis(), p + Vector3(-0.3 + (k % 2) * 0.6, y + 0.05, -0.5 + (k / 2) * 0.9)), "primeurs")
		else:
			o.boite(Transform3D(Basis(), p + Vector3(0, y + 0.35, 0)), Vector3(1.1, 0.55, 1.6), Color("d9bf6a"))
			for k in 6:
				o.boite(Transform3D(Basis(), p + Vector3(0, y + 0.1 + k * 0.1, 0)), Vector3(1.12, 0.02, 1.62), Color("c4a752"))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.7, 0)), Vector3(1.8, 1.4, 2.2)])
		return Vector2(1.8, 4.0)

	## Un tonneau debout : les douelles bombées, les cercles de fer ; p le pied.
	static func _tonneau(o: Outils, p: Vector3, h: float) -> void:
		var rr := h * 0.36
		var t := Transform3D(Basis(), p)
		o.cylindre(t, rr * 0.86, rr, h * 0.5, 12, Color("8a5a36"))
		o.cylindre(t.translated(Vector3(0, h * 0.5, 0)), rr, rr * 0.86, h * 0.5, 12, Color("8a5a36"))
		for y in [0.1, 0.32, 0.68, 0.9]:
			var k := 1.0 - absf(y - 0.5) * 0.28
			o.cylindre(t.translated(Vector3(0, h * y - 0.025, 0)), rr * k + 0.012, rr * k + 0.012, 0.05, 12, FER, Outils.DUR, false)
		o.cylindre(t.translated(Vector3(0, h - 0.02, 0)), rr * 0.82, rr * 0.82, 0.03, 12, Color("6e4428"))

	static func tonneaux(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.04, 0)), Vector3(1.8, 0.1, 1.3), PIERRE_SOMBRE)
		_tonneau(o, p + Vector3(-0.45, 0, 0.1), 0.95)
		_tonneau(o, p + Vector3(0.45, 0, 0.15), 0.95)
		_tonneau(o, p + Vector3(0.0, 0, -0.45), 0.95)
		_tonneau(o, p + Vector3(0.0, 0.95, -0.2), 0.8)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.6, 0)), Vector3(1.6, 1.2, 1.2)])
		return Vector2(1.8, 1.4)

	static func caisses(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		var r := o.rng
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.04, 0)), Vector3(1.6, 0.1, 1.1), PIERRE_SOMBRE)
		# des caisses de planches empilées, de travers, un sac de grain
		var poses := [Vector3(-0.35, 0, 0), Vector3(0.35, 0, 0.05), Vector3(-0.3, 0.55, -0.02), Vector3(0.0, 0, -0.45)]
		for q in poses:
			var tq := Transform3D(Basis(Vector3.UP, r.randf_range(-0.2, 0.2)), p + q + Vector3(0, 0.27, 0))
			var bois := BOIS.lightened(r.randf_range(-0.05, 0.12))
			o.boite(tq, Vector3(0.62, 0.54, 0.5), bois)
			for k in 3:
				o.boite(tq * Transform3D(Basis(), Vector3(0, -0.18 + k * 0.18, 0.255)), Vector3(0.62, 0.03, 0.02), bois.darkened(0.2))
			o.boite(tq * Transform3D(Basis(Vector3.BACK, 0.7), Vector3(0, 0, 0.26)), Vector3(0.75, 0.06, 0.02), bois.darkened(0.12))
		o.boule(p + Vector3(0.5, 0.3, -0.4), Vector3(0.25, 0.3, 0.22), Color("cdb88a"), 0.08, Outils.DUR, 0.04)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(1.4, 1.0, 1.0)])
		return Vector2(1.6, 1.2)

	static func banc(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 1.9))
		# le banc de bois : quatre pieds massifs, l'assise de deux planches, le dossier sur ses montants
		for cote in [-1.0, 1.0]:
			var x: float = cote * (l * 0.5 - 0.15)
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.2, 0.12)), Vector3(0.09, 0.5, 0.09), BOIS_SOMBRE)
			o.boite(Transform3D(Basis(Vector3.RIGHT, 0.12), p + Vector3(x, 0.45, -0.18)), Vector3(0.09, 1.0, 0.09), BOIS_SOMBRE)
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.38, -0.02)), Vector3(0.08, 0.07, 0.5), BOIS_SOMBRE)
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.66, 0.0)), Vector3(0.08, 0.05, 0.5), BOIS_SOMBRE)
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.55, 0.22)), Vector3(0.06, 0.2, 0.06), BOIS_SOMBRE)
		for i in 2:
			o.boite(Transform3D(Basis(), p + Vector3(0, 0.45, 0.13 - i * 0.2)), Vector3(l, 0.05, 0.18), BOIS)
		for i in 2:
			o.boite(Transform3D(Basis(Vector3.RIGHT, 0.12), p + Vector3(0, 0.68 + i * 0.2, -0.22 - i * 0.025)), Vector3(l, 0.14, 0.04), BOIS)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, -0.05)), Vector3(l, 0.9, 0.6)])
		return Vector2(l, 0.7)

	static func banc_fer(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 1.8))
		# le banc public : deux flancs de fer forgé à volute, lattes de bois vernies
		for cote in [-1.0, 1.0]:
			var x: float = cote * (l * 0.5 - 0.1)
			o.boite(Transform3D(Basis(Vector3.RIGHT, -0.15), p + Vector3(x, 0.2, 0.15)), Vector3(0.05, 0.45, 0.05), FER)
			o.boite(Transform3D(Basis(Vector3.RIGHT, 0.2), p + Vector3(x, 0.45, -0.2)), Vector3(0.05, 0.95, 0.05), FER)
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.4, -0.02)), Vector3(0.05, 0.05, 0.5), FER)
			o.anneau(Transform3D(Basis(Vector3.BACK, PI * 0.5), p + Vector3(x - 0.02, 0.6, 0.2)), 0.05, 0.08, 0.04, 10, FER)
		for i in 5:
			o.boite(Transform3D(Basis(), p + Vector3(0, 0.44, 0.2 - i * 0.09)), Vector3(l, 0.035, 0.07), BOIS.lightened(0.05))
		for i in 3:
			o.boite(Transform3D(Basis(Vector3.RIGHT, 0.2), p + Vector3(0, 0.62 + i * 0.13, -0.24 - i * 0.026)), Vector3(l, 0.08, 0.03), BOIS.lightened(0.05))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, -0.05)), Vector3(l, 0.9, 0.6)])
		return Vector2(l, 0.7)

	static func panneau(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		var r := o.rng
		# le panneau d'affichage de la mairie : deux poteaux, le cadre, le petit toit de tuile, les affiches
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * 0.65, 1.0, 0)), Vector3(0.12, 2.3, 0.12), BOIS_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.45, 0)), Vector3(1.4, 1.2, 0.08), BOIS)
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.45, 0.045)), Vector3(1.2, 1.0, 0.02), Color("d9cfb4"))
		for k in 4:
			var q := Vector3(-0.32 + (k % 2) * 0.62, 1.7 - (k / 2) * 0.48, 0.06)
			var col := Color(["f3ead6", "f2d14e", "a9c8e8", "f0b0a0"][r.randi() % 4])
			o.boite(Transform3D(Basis(Vector3.BACK, r.randf_range(-0.06, 0.06)), p + q), Vector3(0.42, 0.38, 0.01), col)
			for j in 3:
				o.boite(Transform3D(Basis(), p + q + Vector3(0, 0.1 - j * 0.08, 0.006)), Vector3(0.3, 0.025, 0.005), Color("4a4a4a"))
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(Vector3.RIGHT, cote * 0.55), p + Vector3(0, 2.3, cote * 0.18)), Vector3(1.7, 0.05, 0.45), TUILE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 2.42, 0)), Vector3(1.75, 0.08, 0.08), TUILE.darkened(0.15))
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.05, 0)), Vector3(1.6, 0.12, 0.3), PIERRE_SOMBRE)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.2, 0)), Vector3(1.5, 2.4, 0.25)])
		return Vector2(1.8, 0.6)

	static func puits(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		var r := o.rng
		var t := Transform3D(Basis(), p)
		# la margelle ronde de moellons, l'eau noire au fond
		o.cylindre(t.translated(Vector3(0, -0.1, 0)), 1.0, 1.0, 0.15, 16, PIERRE_SOMBRE)
		o.anneau(t, 0.62, 0.9, 0.85, 16, MOELLON.darkened(0.1))
		for j in 4:
			for i in 12:
				var a := TAU * (i + 0.5 * (j % 2)) / 12.0
				var bb := Basis(Vector3.UP, -a + PI * 0.5)
				o.boite(Transform3D(bb, p + bb * Vector3(0, 0.12 + j * 0.2, 0.91)), Vector3(0.4, 0.17, 0.04), MOELLON.lightened(r.randf_range(-0.1, 0.1)))
		o.anneau(t.translated(Vector3(0, 0.85, 0)), 0.58, 0.96, 0.1, 16, PIERRE)
		o.cylindre(t.translated(Vector3(0, 0.3, 0)), 0.62, 0.62, 0.02, 16, Color("1e2a30"))
		# les deux montants, le toit de tuile à deux pans, le treuil et sa manivelle, le seau
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * 0.8, 1.55, 0)), Vector3(0.12, 1.5, 0.12), BOIS_SOMBRE)
			o.boite(Transform3D(Basis(Vector3.RIGHT, cote * 0.6), p + Vector3(0, 2.45, cote * 0.42)), Vector3(2.0, 0.06, 1.0), TUILE)
			for k in 3:
				o.boite(Transform3D(Basis(Vector3.RIGHT, cote * 0.6), p + Vector3(0, 2.5 - k * 0.14 * 0.82, cote * (0.18 + k * 0.28))), Vector3(2.02, 0.04, 0.06), TUILE.darkened(0.15))
		o.boite(Transform3D(Basis(), p + Vector3(0, 2.3, 0)), Vector3(1.75, 0.12, 0.12), BOIS_SOMBRE)
		o.cylindre(Transform3D(Basis(Vector3.BACK, PI * 0.5), p + Vector3(0.75, 1.75, 0)), 0.1, 0.1, 1.5, 10, BOIS)
		o.boite(Transform3D(Basis(), p + Vector3(0.9, 1.6, 0)), Vector3(0.05, 0.3, 0.05), FER)
		o.boite(Transform3D(Basis(), p + Vector3(0.95, 1.45, 0.08)), Vector3(0.04, 0.04, 0.18), FER)
		o.branche(p + Vector3(0, 1.72, 0), p + Vector3(0, 1.2, 0), 0.01, 0.01, Color("c9b98a"), 4)
		o.cylindre(t.translated(Vector3(0, 0.9, 0.0)), 0.13, 0.16, 0.28, 10, Color("8a5a36"))
		o.cylindre(t.translated(Vector3(0, 1.17, 0)), 0.165, 0.165, 0.03, 10, FER, Outils.DUR, false)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.6, 0)), Vector3(1.9, 1.2, 1.9)])
		return Vector2(2.2, 2.2)

	static func jardiniere(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 2.4))
		var fleur := _fleur(o, opt)
		# le bac de moellons sous sa couvertine, la terre, un massif de fleurs mêlées
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.25, 0)), Vector3(l, 0.6, 0.9), MOELLON.darkened(0.12), Outils.DUR, true)
		var r := o.rng
		for j in 3:
			var x := -l * 0.5
			while x < l * 0.5 - 0.1:
				var lx := minf(r.randf_range(0.25, 0.55), l * 0.5 - x)
				var col := MOELLON.lightened(r.randf_range(-0.1, 0.1))
				for cote in [-1.0, 1.0]:
					o.boite(Transform3D(Basis(), p + Vector3(x + lx * 0.5, 0.06 + j * 0.17, cote * 0.46)), Vector3(lx - 0.04, 0.14, 0.03), col)
				x += lx
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.6, 0)), Vector3(l + 0.08, 0.1, 1.0), PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.63, 0)), Vector3(l - 0.16, 0.06, 0.74), TERRE)
		for i in int(l / 0.4):
			var col := fleur if i % 2 == 0 else Color(FLEURS[r.randi() % FLEURS.size()])
			_touffe(o, p + Vector3(-l * 0.5 + 0.25 + i * 0.4, 0.82, r.randf_range(-0.15, 0.15)), r.randf_range(0.22, 0.3), col, 6)
		for i in 3:
			o.boule(p + Vector3(-l * 0.4 + i * l * 0.4, 0.55, 0.47), Vector3(0.12, 0.3, 0.08), VERT.darkened(0.06), 0.3, Outils.FEUILLE, 0.05, 0.3)
		return Vector2(l + 0.1, 1.0)

	static func enseigne(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		# l'enseigne forgée de l'auberge : le poteau de chêne, la potence à volutes, le panneau qui pend, la grappe
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.05, 0)), Vector3(0.45, 0.12, 0.45), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 1.4, 0)), Vector3(0.16, 2.9, 0.16), BOIS_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0.55, 2.6, 0)), Vector3(1.1, 0.05, 0.05), FER)
		o.branche(p + Vector3(0.08, 2.1, 0), p + Vector3(0.7, 2.58, 0), 0.02, 0.02, FER, 4)
		o.anneau(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0.3, 2.4, 0.02)), 0.1, 0.13, 0.04, 10, FER)
		o.anneau(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0.75, 2.75, 0.02)), 0.06, 0.09, 0.04, 10, FER)
		for k in 2:
			o.boite(Transform3D(Basis(), p + Vector3(0.35 + k * 0.5, 2.48, 0)), Vector3(0.015, 0.22, 0.015), FER)
		o.boite(Transform3D(Basis(), p + Vector3(0.6, 2.05, 0)), Vector3(0.75, 0.62, 0.05), BOIS)
		o.boite(Transform3D(Basis(), p + Vector3(0.6, 2.05, 0)), Vector3(0.62, 0.5, 0.06), Color("2e3f5f"))
		for k in 6:
			o.boule(p + Vector3(0.52 + (k % 3) * 0.08 + (0.04 if k >= 3 else 0.0), 2.16 - (k / 3) * 0.1, 0.04), Vector3.ONE * 0.05, Color("e0b040"), 0.0, Outils.DUR, 0.0)
		o.boule(p + Vector3(0.6, 1.94, 0.04), Vector3.ONE * 0.05, Color("e0b040"), 0.0, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.4, 0)), Vector3(0.3, 2.8, 0.3)])
		return Vector2(1.4, 0.5)

	static func _lanterne(o: Outils, c: Vector3, allume: bool) -> void:
		var lueur := Color("ffe2a0") if allume else Color("d8d4c4")
		o.cylindre(Transform3D(Basis(Vector3.UP, PI * 0.25), c + Vector3(0, -0.25, 0)), 0.08, 0.16, 0.08, 4, FER)
		o.boite(Transform3D(Basis(Vector3.UP, PI * 0.25), c + Vector3(0, -0.02, 0)), Vector3(0.24, 0.38, 0.24), lueur, Outils.LUEUR if allume else Outils.DUR)
		for i in 4:
			var a := TAU * i / 4.0
			o.boite(Transform3D(Basis(), c + Vector3(cos(a) * 0.17, -0.02, sin(a) * 0.17)), Vector3(0.025, 0.4, 0.025), FER)
		o.cylindre(Transform3D(Basis(Vector3.UP, PI * 0.25), c + Vector3(0, 0.17, 0)), 0.24, 0.03, 0.2, 4, FER)
		o.boule(c + Vector3(0, 0.4, 0), Vector3.ONE * 0.04, FER, 0.0, Outils.DUR, 0.0)

	static func lampadaire(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var allume: bool = opt.get("allume", true)
		# le lampadaire de place : le pied de pierre, le fût de fer, la crosse double et ses deux lanternes
		var t := Transform3D(Basis(), p)
		o.cylindre(t.translated(Vector3(0, -0.06, 0)), 0.32, 0.28, 0.4, 8, PIERRE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.34, 0)), 0.1, 0.07, 3.1, 8, FER)
		o.anneau(t.translated(Vector3(0, 0.5, 0)), 0.06, 0.13, 0.08, 8, FER)
		for cote in [-1.0, 1.0]:
			o.branche(p + Vector3(0, 3.0, 0), p + Vector3(cote * 0.5, 3.35, 0), 0.035, 0.03, FER, 5)
			o.anneau(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(cote * 0.25, 3.0, 0.02)), 0.08, 0.11, 0.04, 10, FER)
			_lanterne(o, p + Vector3(cote * 0.55, 3.1, 0), allume)
		o.boule(p + Vector3(0, 3.5, 0), Vector3.ONE * 0.07, FER, 0.0, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.7, 0)), Vector3(0.4, 3.4, 0.4)])
		return Vector2(1.4, 0.6)

	static func tonnelle(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		var r := o.rng
		var l := 3.0
		var pr := 2.4
		# quatre poteaux, deux sablières, les traverses ; la vigne qui couvre le dessus et pend, les grappes
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				o.boite(Transform3D(Basis(), p + Vector3(cx * l * 0.5, 1.1, cz * pr * 0.5)), Vector3(0.12, 2.5, 0.12), BOIS_SOMBRE)
				o.boite(Transform3D(Basis(), p + Vector3(cx * l * 0.5, -0.05, cz * pr * 0.5)), Vector3(0.3, 0.12, 0.3), PIERRE_SOMBRE)
			o.boite(Transform3D(Basis(), p + Vector3(cx * l * 0.5, 2.38, 0)), Vector3(0.12, 0.14, pr + 0.5), BOIS_SOMBRE)
		for k in 6:
			o.boite(Transform3D(Basis(), p + Vector3(0, 2.5, -pr * 0.5 - 0.1 + k * (pr + 0.2) / 5.0)), Vector3(l + 0.5, 0.1, 0.08), BOIS)
		for i in 46:
			var q := p + Vector3(r.randf_range(-l * 0.55, l * 0.55), r.randf_range(2.52, 2.7), r.randf_range(-pr * 0.55, pr * 0.55))
			if r.randf() < 0.25:
				q.y -= r.randf_range(0.2, 0.5)
			o.boule(q, Vector3(r.randf_range(0.25, 0.42), r.randf_range(0.12, 0.2), r.randf_range(0.25, 0.42)), VERT.lightened(r.randf_range(-0.08, 0.14)), 0.35, Outils.FEUILLE, 0.12, 0.3)
		for i in 8:
			var q := p + Vector3(r.randf_range(-l * 0.45, l * 0.45), 2.3, r.randf_range(-pr * 0.45, pr * 0.45))
			o.boule(q + Vector3(0, -0.15, 0), Vector3(0.1, 0.18, 0.1), Color("5a3a6a"), 0.25, Outils.FEUILLE, 0.05, 0.2)
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				o.branche(p + Vector3(cx * l * 0.5 + 0.1, 0, cz * pr * 0.5 + 0.1), p + Vector3(cx * l * 0.5 + 0.12, 2.4, cz * pr * 0.5 + 0.05), 0.05, 0.03, BOIS_SOMBRE.darkened(0.1), 5)
				for k in 6:
					o.boule(p + Vector3(cx * l * 0.5 + 0.15 + r.randf_range(-0.1, 0.1), 0.5 + k * 0.33, cz * pr * 0.5 + 0.1 + r.randf_range(-0.1, 0.1)), Vector3(0.15, 0.13, 0.14), VERT.lightened(r.randf_range(-0.05, 0.1)), 0.3, Outils.FEUILLE, 0.1, 0.3)
		o.collisions.append([Transform3D(Basis(), p + Vector3(-l * 0.5, 1.2, 0)), Vector3(0.15, 2.4, pr)])
		o.collisions.append([Transform3D(Basis(), p + Vector3(l * 0.5, 1.2, 0)), Vector3(0.15, 2.4, pr)])
		return Vector2(l + 0.6, pr + 0.6)

	static func muret(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 4.0))
		var r := o.rng
		# le muret de moellons sous sa couvertine, la touffe d'herbe et la fleur sauvage à son pied
		_maconne(o, p + Vector3(-l * 0.5, 0, 0), p + Vector3(l * 0.5, 0, 0), 0.95, 0.45)
		for i in int(l / 0.9):
			if r.randf() < 0.6:
				_touffe(o, p + Vector3(-l * 0.5 + 0.4 + i * 0.9, 0.12, 0.4), r.randf_range(0.18, 0.28), Color(FLEURS[r.randi() % FLEURS.size()]), 3)
		for i in 3:
			o.boule(p + Vector3(r.randf_range(-l * 0.4, l * 0.4), 0.95, r.randf_range(-0.1, 0.1)), Vector3(0.3, 0.12, 0.25), VERT.darkened(0.05), 0.3, Outils.FEUILLE, 0.08, 0.2)
		return Vector2(l, 0.6)

	static func table(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var r := o.rng
		# la table de bistrot de bois sur son pied de fer, deux chaises paillées, une carafe et deux verres
		o.cylindre(Transform3D(Basis(), p + Vector3(0, -0.03, 0)), 0.3, 0.25, 0.06, 10, FER)
		o.cylindre(Transform3D(Basis(), p + Vector3(0, 0.03, 0)), 0.04, 0.04, 0.7, 6, FER)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.75, 0)), Vector3(0.8, 0.05, 0.8), BOIS)
		o.cylindre(Transform3D(Basis(), p + Vector3(0.1, 0.78, 0.05)), 0.06, 0.04, 0.22, 8, Color("c9dde0"))
		for k in 2:
			o.cylindre(Transform3D(Basis(), p + Vector3(-0.15 + k * 0.1, 0.78, -0.15)), 0.035, 0.04, 0.1, 8, Color("8a2a3a"))
		for cote in [-1.0, 1.0]:
			var b := Basis(Vector3.UP, (PI if cote > 0 else 0.0) + r.randf_range(-0.2, 0.2))
			var c := p + b * Vector3(0, 0, 0.7)
			for cx in [-1.0, 1.0]:
				for cz in [-1.0, 1.0]:
					o.boite(Transform3D(b, c + b * Vector3(cx * 0.18, 0.22, cz * 0.18)), Vector3(0.04, 0.45, 0.04), BOIS_SOMBRE)
				o.boite(Transform3D(b, c + b * Vector3(cx * 0.18, 0.7, 0.18)), Vector3(0.04, 0.55, 0.04), BOIS_SOMBRE)
			o.boite(Transform3D(b, c + b * Vector3(0, 0.46, 0)), Vector3(0.42, 0.05, 0.42), Color("d9bf6a"))
			for k in 2:
				o.boite(Transform3D(b, c + b * Vector3(0, 0.7 + k * 0.18, 0.18)), Vector3(0.38, 0.06, 0.03), BOIS_SOMBRE)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.4, 0)), Vector3(0.8, 0.8, 0.8)])
		return Vector2(0.9, 2.0)
