extends Node3D
## Un objet du mobilier de la place du nord, posé tel quel : on règle objet, graine et options avant de l'ajouter
## à la scène, il se bâtit à son entrée dans l'arbre de scène. Le pied est à l'origine, sur un sol plat à y = 0,
## le devant (l'assise d'un banc, l'étal d'un marchand) regarde +Z ; en mètres (une commune à l'échelle du
## village de Smarves, 1 unité = 2,4 m, le pose à l'échelle 1/2,4).
##   var o = load(Bibliotheque.scene("mobilier-de-place@1", "decor")).instantiate()
##   o.objet = "fontaine" ; o.graine = 3
##   add_child(o)
## Après la construction, le nœud porte ses métadonnées : objet, graine, emprise (la taille au sol, Vector2).
const Outils := preload("res://bibliotheque/mobilier-de-place/1/outils.gd")

## Les objets : le mobilier, puis les plantes.
const OBJETS := ["fontaine", "banc", "lampadaire", "etal", "charrette", "tonneaux", "caisses", "terrasse",
	"corbeille", "poteau", "jardiniere", "pot", "massif"]

const PIERRE := Color("e8dfc8")
const PIERRE_SOMBRE := Color("cfc2a2")
const BRONZE := Color("41574f")
const BOIS := Color("a06e40")
const BOIS_SOMBRE := Color("6e4a2c")
const FER := Color("2c3033")
const TERRE := Color("6b4f36")
const VERT := Color("5f9e33")
const FLEURS := ["e88aa8", "b06ad0", "9a5bc4", "f2c14e", "f4f0e6", "e0605a"]
const TOILES := [["c8463c", "f3ead6"], ["3f6fa0", "f3ead6"], ["7a3f6e", "e9d9b8"], ["4f7f4a", "f3ead6"]]
const PRIMEURS := ["e0605a", "f2a23a", "f2d14e", "8cc63f", "b06ad0", "d9473b", "7a4f2a"]

## L'objet (voir OBJETS).
@export var objet := "banc"
## La graine : la couleur d'une toile, les fleurs d'une jardinière, ce que porte la charrette.
@export var graine := 1
## Les options, toutes facultatives : fleurs (un hexa : la couleur des fleurs), toile (deux hexas : les bandes
## d'un store ou d'un parasol), statue (false : la fontaine sans sa statue), allume (false : les lanternes et le
## globe éteints), longueur (le banc, la jardinière, le massif : en mètres).
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


## Bâtit un objet sous parent, son pied en p (sans rotation : tourner le parent). Rend objet, graine, emprise.
static func poser(parent: Node3D, p: Vector3, nom: String, g: int, opt := {}) -> Dictionary:
	if not nom in OBJETS:
		nom = "banc"
	var o := Outils.new(g * 104729 + OBJETS.find(nom))
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

	static func fontaine(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var t := Transform3D(Basis(), p)
		# deux marches rondes, le bassin et sa margelle, l'eau
		o.cylindre(t.translated(Vector3(0, -0.1, 0)), 4.6, 4.6, 0.26, 32, PIERRE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.16, 0)), 4.1, 4.1, 0.16, 32, PIERRE)
		o.anneau(t.translated(Vector3(0, 0.32, 0)), 2.85, 3.25, 0.5, 32, PIERRE)
		o.anneau(t.translated(Vector3(0, 0.82, 0)), 2.8, 3.35, 0.1, 32, PIERRE_SOMBRE)
		o.cylindre(t.translated(Vector3(0, 0.32, 0)), 2.86, 2.86, 0.32, 32, Color("4f8fa8"), Outils.DUR, true)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, 0)), Vector3(6.4, 0.9, 6.4)])
		# des pots fleuris sur la margelle
		var fleur := _fleur(o, opt)
		for i in 8:
			var a := TAU * i / 8.0 + PI / 8.0
			var q := p + Vector3(cos(a), 0, sin(a)) * 3.08 + Vector3(0, 0.92, 0)
			o.cylindre(Transform3D(Basis(), q), 0.17, 0.22, 0.22, 8, Color("c87850"))
			_touffe(o, q + Vector3(0, 0.3, 0), 0.24, fleur, 4)
		# le piédestal : un socle à moulures, un dé et une corniche
		var b := p + Vector3(0, 0.32, 0)
		o.cylindre(Transform3D(Basis(), b), 0.95, 0.95, 0.45, 16, PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), b + Vector3(0, 1.0, 0)), Vector3(1.15, 1.1, 1.15), PIERRE)
		o.boite(Transform3D(Basis(), b + Vector3(0, 0.5, 0)), Vector3(1.35, 0.14, 1.35), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), b + Vector3(0, 1.6, 0)), Vector3(1.4, 0.16, 1.4), PIERRE_SOMBRE)
		o.collisions.append([Transform3D(Basis(), b + Vector3(0, 1.4, 0)), Vector3(1.4, 2.8, 1.4)])
		# quatre becs qui crachent dans le bassin
		for i in 4:
			var bb := Basis(Vector3.UP, PI * 0.5 * i)
			o.boite(Transform3D(bb, b + bb * Vector3(0, 0.8, 0.68)), Vector3(0.12, 0.12, 0.24), BRONZE)
			o.boule(b + bb * Vector3(0, 0.25, 1.2), Vector3(0.14, 0.4, 0.14), Color("bfe6f2"), 0.05, Outils.DUR, 0.0)
		if opt.get("statue", true):
			# la statue encapuchonnée : une robe en cône, la cape, la capuche, les bras qui tiennent un globe
			var s := b + Vector3(0, 1.68, 0)
			o.cylindre(Transform3D(Basis(), s), 0.48, 0.3, 0.12, 12, BRONZE.darkened(0.15))
			o.cylindre(Transform3D(Basis(), s + Vector3(0, 0.12, 0)), 0.42, 0.22, 1.5, 12, BRONZE)
			o.cylindre(Transform3D(Basis(Vector3.RIGHT, -0.08), s + Vector3(0, 0.4, -0.08)), 0.46, 0.27, 1.25, 12, BRONZE.darkened(0.08), Outils.DUR, false)
			o.boule(s + Vector3(0, 1.72, 0), Vector3(0.3, 0.27, 0.28), BRONZE.darkened(0.05), 0.0, Outils.DUR, 0.0)
			o.cylindre(Transform3D(Basis(), s + Vector3(0, 1.55, 0)), 0.3, 0.12, 0.62, 10, BRONZE.darkened(0.1))
			o.boule(s + Vector3(0, 1.72, 0.12), Vector3(0.16, 0.18, 0.12), Color("1d2a27"), 0.0, Outils.DUR, 0.0)
			for cote in [-1.0, 1.0]:
				o.branche(s + Vector3(cote * 0.24, 1.38, 0.0), s + Vector3(cote * 0.14, 1.08, 0.32), 0.09, 0.08, BRONZE)
			var globe := Color("a8e4ff") if opt.get("allume", true) else Color("6f8f9a")
			o.boule(s + Vector3(0, 1.1, 0.42), Vector3.ONE * 0.17, globe, 0.0, Outils.LUEUR if opt.get("allume", true) else Outils.DUR, 0.0)
		return Vector2(9.2, 9.2)

	static func banc(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 1.9))
		# les deux flancs de fonte, l'assise de cinq lattes, le dossier de trois
		for cote in [-1.0, 1.0]:
			var x: float = cote * (l * 0.5 - 0.12)
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.2, 0.0)), Vector3(0.06, 0.5, 0.5), FER)
			o.boite(Transform3D(Basis(Vector3.RIGHT, -0.2), p + Vector3(x, 0.7, -0.24)), Vector3(0.06, 0.6, 0.06), FER)
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.62, 0.1)), Vector3(0.07, 0.05, 0.5), FER)
		for i in 5:
			o.boite(Transform3D(Basis(), p + Vector3(0, 0.45, -0.18 + i * 0.1)), Vector3(l, 0.04, 0.08), BOIS)
		for i in 3:
			var y := 0.62 + i * 0.13
			o.boite(Transform3D(Basis(Vector3.RIGHT, -0.2), p + Vector3(0, y, -0.25 - (y - 0.6) * 0.2)), Vector3(l, 0.09, 0.03), BOIS)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, -0.05)), Vector3(l, 0.9, 0.6)])
		return Vector2(l, 0.7)

	static func lampadaire(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var t := Transform3D(Basis(), p)
		o.cylindre(t, 0.24, 0.2, 0.35, 8, FER)
		o.cylindre(t.translated(Vector3(0, 0.35, 0)), 0.09, 0.06, 3.0, 8, FER)
		o.cylindre(t.translated(Vector3(0, 0.35, 0)), 0.13, 0.1, 0.5, 8, FER)
		o.boule(p + Vector3(0, 3.42, 0), Vector3.ONE * 0.09, FER, 0.0, Outils.DUR, 0.0)
		var lueur: Color = Color("ffe6a6") if opt.get("allume", true) else Color("d8d4c4")
		for cote in [-1.0, 1.0]:
			# la crosse et la lanterne à quatre vitres, son chapeau et sa pointe
			o.branche(p + Vector3(0, 3.0, 0), p + Vector3(cote * 0.35, 3.25, 0), 0.03, 0.03, FER, 5)
			o.branche(p + Vector3(cote * 0.35, 3.25, 0), p + Vector3(cote * 0.5, 3.22, 0), 0.03, 0.03, FER, 5)
			var c := p + Vector3(cote * 0.52, 2.95, 0)
			o.boite(Transform3D(Basis(), c), Vector3(0.2, 0.32, 0.2), lueur, Outils.LUEUR if opt.get("allume", true) else Outils.DUR)
			for dx in [-1.0, 1.0]:
				for dz in [-1.0, 1.0]:
					o.boite(Transform3D(Basis(), c + Vector3(dx * 0.11, 0, dz * 0.11)), Vector3(0.03, 0.34, 0.03), FER)
			o.boite(Transform3D(Basis(), c + Vector3(0, -0.18, 0)), Vector3(0.18, 0.04, 0.18), FER)
			o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.17, 0)), 0.19, 0.03, 0.16, 4, FER)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.7, 0)), Vector3(0.3, 3.4, 0.3)])
		return Vector2(0.5, 0.5)

	static func etal(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var toile: Array = opt.get("toile", TOILES[o.rng.randi() % TOILES.size()])
		var c1 := Color(str(toile[0]))
		var c2 := Color(str(toile[1]))
		# la table et ses tréteaux, quatre poteaux, le store à bandes en pente vers l'avant et son lambrequin
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.82, 0.1)), Vector3(2.4, 0.06, 1.0), BOIS)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.45, 0.1)), Vector3(2.3, 0.7, 0.9), Color(c2).darkened(0.08))
		for x in [-1.15, 1.15]:
			for z in [-0.45, 0.6]:
				o.boite(Transform3D(Basis(), p + Vector3(x, 1.2, z)), Vector3(0.07, 2.4, 0.07), BOIS_SOMBRE)
		var bandes := 7
		for i in bandes:
			var x := -1.25 + (i + 0.5) * 2.5 / bandes
			o.boite(Transform3D(Basis(Vector3.RIGHT, 0.32), p + Vector3(x, 2.42, 0.1)), Vector3(2.5 / bandes, 0.04, 1.5), c1 if i % 2 == 0 else c2)
			for k in 2:
				var pts := Outils.arc(Vector2(0, 0), 0.09, PI, TAU, 6)
				pts.append(Vector2(0.09, 0.06))
				pts.append(Vector2(-0.09, 0.06))
				o.profil(Transform3D(Basis(), p + Vector3(x - 2.5 / bandes * 0.25 + k * 2.5 / bandes * 0.5, 2.15, 0.84)), pts, -0.01, 0.01, c1 if i % 2 == 0 else c2)
		# les cagettes de primeurs, en gradins
		for rang in 2:
			for i in 4:
				var q := p + Vector3(-0.85 + i * 0.57, 0.85 + rang * 0.14, 0.38 - rang * 0.42)
				o.boite(Transform3D(Basis(), q + Vector3(0, 0.08 + rang * 0.06, 0)), Vector3(0.5, 0.16 + rang * 0.12, 0.38), BOIS.lightened(0.15))
				var fruit := Color(PRIMEURS[o.rng.randi() % PRIMEURS.size()])
				for f in 6:
					o.boule(q + Vector3(o.rng.randf_range(-0.17, 0.17), 0.2 + rang * 0.12, o.rng.randf_range(-0.12, 0.12)), Vector3.ONE * 0.075, fruit, 0.05, Outils.DUR, 0.08)
		# un panier et un sac au pied
		o.cylindre(Transform3D(Basis(), p + Vector3(1.55, 0, 0.6)), 0.2, 0.25, 0.32, 10, Color("c9a064"))
		o.boule(p + Vector3(-1.6, 0.25, 0.5), Vector3(0.25, 0.3, 0.22), Color("d8c49a"), 0.08, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.6, 0.1)), Vector3(2.5, 1.2, 1.1)])
		return Vector2(2.6, 1.6)

	static func charrette(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		# la caisse sur deux roues, les brancards, une béquille ; un tonneau, des caisses, une toile, des jarres
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.62, 0)), Vector3(1.0, 0.08, 1.6), BOIS)
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * 0.5, 0.78, 0)), Vector3(0.05, 0.28, 1.6), BOIS_SOMBRE)
			o.boite(Transform3D(Basis(), p + Vector3(cote * 0.38, 0.62, 1.25)), Vector3(0.06, 0.06, 1.1), BOIS_SOMBRE)
			var rt := Transform3D(Basis(Vector3.FORWARD, PI * 0.5), p + Vector3(cote * 0.62, 0.42, -0.15))
			o.anneau(rt.translated_local(Vector3(0, -0.04, 0)), 0.34, 0.42, 0.08, 16, BOIS_SOMBRE)
			o.cylindre(rt.translated_local(Vector3(0, -0.05, 0)), 0.07, 0.07, 0.1, 8, FER)
			for k in 4:
				o.boite(Transform3D(Basis(Vector3.RIGHT, PI * 0.25 * k), p + Vector3(cote * 0.62, 0.42, -0.15)), Vector3(0.04, 0.72, 0.04), BOIS_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.6, 1.8)), Vector3(0.82, 0.05, 0.05), BOIS_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.3, 0.6)), Vector3(0.05, 0.6, 0.05), BOIS_SOMBRE)
		_tonneau(o, p + Vector3(-0.2, 0.66, -0.4), 0.26, 0.6)
		o.boite(Transform3D(Basis(Vector3.UP, 0.2), p + Vector3(0.22, 0.85, -0.45)), Vector3(0.42, 0.38, 0.42), BOIS.lightened(0.18))
		o.boite(Transform3D(Basis(Vector3.UP, -0.1), p + Vector3(0.12, 1.22, -0.5)), Vector3(0.34, 0.3, 0.34), BOIS.lightened(0.1))
		o.boule(p + Vector3(0, 0.82, 0.35), Vector3(0.48, 0.18, 0.55), Color("e6cf9a"), 0.15, Outils.DUR, 0.0)
		for i in 5:
			var c := Color(PRIMEURS[o.rng.randi() % PRIMEURS.size()])
			var q := p + Vector3(o.rng.randf_range(-0.35, 0.35), 0.72, o.rng.randf_range(0.2, 0.7))
			o.cylindre(Transform3D(Basis(), q), 0.09, 0.07, 0.22, 8, Color("eadfca"))
			o.boule(q + Vector3(0, 0.24, 0), Vector3(0.08, 0.05, 0.08), c, 0.05, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.6, 0.2)), Vector3(1.4, 1.2, 2.6)])
		return Vector2(1.4, 2.8)

	static func _tonneau(o: Outils, p: Vector3, r: float, h: float) -> void:
		var t := Transform3D(Basis(), p)
		o.cylindre(t, r * 0.88, r, h * 0.5, 12, BOIS)
		o.cylindre(t.translated(Vector3(0, h * 0.5, 0)), r, r * 0.88, h * 0.5, 12, BOIS)
		for y in [0.12, 0.88]:
			o.anneau(t.translated(Vector3(0, h * y - 0.02, 0)), r * 0.9, r * 0.97, 0.05, 12, FER)

	static func tonneaux(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		_tonneau(o, p + Vector3(-0.35, 0, 0), 0.34, 0.85)
		_tonneau(o, p + Vector3(0.38, 0, 0.1), 0.34, 0.85)
		_tonneau(o, p + Vector3(0.0, 0, -0.55), 0.3, 0.75)
		# un tonneau couché
		var b := Basis(Vector3.FORWARD, PI * 0.5)
		o.cylindre(Transform3D(b, p + Vector3(0.5, 0.3, 0.75)), 0.27, 0.3, 0.38, 12, BOIS)
		o.cylindre(Transform3D(b, p + Vector3(0.12, 0.3, 0.75)), 0.3, 0.27, 0.38, 12, BOIS)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.42, 0)), Vector3(1.5, 0.85, 1.6)])
		return Vector2(1.5, 1.6)

	static func caisses(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		var piles := [[Vector3(-0.3, 0, 0), 0.6, 0.1], [Vector3(0.35, 0, 0.1), 0.55, -0.2], [Vector3(-0.25, 0.6, 0.02), 0.5, 0.35], [Vector3(0.05, 0, -0.6), 0.45, 0.0]]
		for c in piles:
			var s: float = c[1]
			var b := Basis(Vector3.UP, c[2])
			var q: Vector3 = p + c[0] + Vector3(0, s * 0.5, 0)
			o.boite(Transform3D(b, q), Vector3.ONE * s, BOIS.lightened(0.2))
			for k in 3:
				o.boite(Transform3D(b, q + b * Vector3(0, s * (-0.33 + k * 0.33), s * 0.5 + 0.005)), Vector3(s * 0.98, s * 0.06, 0.02), BOIS_SOMBRE)
			o.boite(Transform3D(b * Basis(Vector3.FORWARD, 0.78), q + b * Vector3(0, 0, s * 0.5 + 0.01)), Vector3(s * 1.3, s * 0.08, 0.02), BOIS_SOMBRE)
		# un sac de toile et quelques pommes tombées
		o.boule(p + Vector3(0.6, 0.25, -0.45), Vector3(0.22, 0.28, 0.2), Color("d8c49a"), 0.08, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.55, -0.1)), Vector3(1.3, 1.1, 1.3)])
		return Vector2(1.4, 1.4)

	static func terrasse(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var toile: Array = opt.get("toile", TOILES[o.rng.randi() % TOILES.size()])
		# une table ronde de bistrot, deux chaises de fonte, un parasol à bandes
		var t := Transform3D(Basis(), p)
		o.cylindre(t, 0.25, 0.25, 0.03, 12, FER)
		o.cylindre(t, 0.03, 0.03, 0.72, 6, FER)
		o.cylindre(t.translated(Vector3(0, 0.72, 0)), 0.38, 0.38, 0.03, 16, Color("efe8d8"))
		o.cylindre(t.translated(Vector3(0, 0.75, 0.1)), 0.04, 0.035, 0.12, 8, Color("f4f0e6"))
		for cote in [-1.0, 1.0]:
			var b := Basis(Vector3.UP, 0.0 if cote > 0 else PI)
			var c := p + b * Vector3(0, 0, 0.62)
			o.boite(Transform3D(b, c + Vector3(0, 0.46, 0)), Vector3(0.42, 0.04, 0.4), FER)
			for dx in [-0.18, 0.18]:
				for dz in [-0.17, 0.17]:
					o.boite(Transform3D(b, c + b * Vector3(dx, 0.23, dz)), Vector3(0.03, 0.46, 0.03), FER)
			o.boite(Transform3D(b * Basis(Vector3.RIGHT, -0.12), c + b * Vector3(0, 0.75, 0.2)), Vector3(0.4, 0.52, 0.03), FER)
		o.cylindre(t, 0.025, 0.025, 2.35, 6, Color("efe8d8"))
		var n := 8
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var haut := p + Vector3(0, 2.4, 0)
			var col := Color(str(toile[i % 2]))
			o.tri(haut, p + Vector3(cos(a0) * 1.25, 1.95, sin(a0) * 1.25), p + Vector3(cos(a1) * 1.25, 1.95, sin(a1) * 1.25), Vector3.UP, col)
			o.tri(haut, p + Vector3(cos(a0) * 1.25, 1.95, sin(a0) * 1.25), p + Vector3(cos(a1) * 1.25, 1.95, sin(a1) * 1.25), Vector3.DOWN, col.darkened(0.2))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, 0)), Vector3(0.9, 0.9, 1.6)])
		return Vector2(2.5, 2.5)

	static func corbeille(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		var t := Transform3D(Basis(), p)
		o.cylindre(t, 0.12, 0.12, 0.05, 8, FER)
		o.cylindre(t, 0.04, 0.04, 0.55, 6, FER)
		o.cylindre(t.translated(Vector3(0, 0.45, 0)), 0.2, 0.24, 0.55, 12, Color("2f3a36"))
		o.anneau(t.translated(Vector3(0, 0.98, 0)), 0.2, 0.26, 0.04, 12, FER)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(0.5, 1.0, 0.5)])
		return Vector2(0.5, 0.5)

	static func poteau(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		# le poteau indicateur de fonte et trois flèches de bois peint
		var t := Transform3D(Basis(), p)
		o.cylindre(t, 0.12, 0.1, 0.25, 8, FER)
		o.cylindre(t, 0.05, 0.045, 2.6, 8, FER)
		o.boule(p + Vector3(0, 2.66, 0), Vector3.ONE * 0.08, Color("b89c61"), 0.0, Outils.DUR, 0.0)
		var couleurs := [Color("efe3c6"), Color("e8d6a8"), Color("efe3c6")]
		for i in 3:
			var a: float = [0.3, 2.4, -1.1][i] + o.rng.randf_range(-0.2, 0.2)
			var b := Basis(Vector3.UP, a)
			var y := 2.2 - i * 0.32
			var fl := PackedVector2Array([Vector2(0.06, -0.11), Vector2(0.72, -0.11), Vector2(0.86, 0), Vector2(0.72, 0.11), Vector2(0.06, 0.11)])
			o.profil(Transform3D(b, p + Vector3(0, y, 0)), fl, -0.025, 0.025, [couleurs[i], BOIS_SOMBRE])
			o.profil(Transform3D(b, p + Vector3(0, y, 0)), PackedVector2Array([Vector2(0.14, -0.035), Vector2(0.66, -0.035), Vector2(0.66, 0.035), Vector2(0.14, 0.035)]), 0.025, 0.03, Color("3a3430"))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.3, 0)), Vector3(0.2, 2.6, 0.2)])
		return Vector2(0.4, 0.4)

	static func jardiniere(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 2.2))
		var fleur := _fleur(o, opt)
		# un bac de pierre à corniche, plein de terre, débordant de feuilles et de fleurs
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.3, 0)), Vector3(l, 0.6, 0.75), PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.62, 0)), Vector3(l + 0.1, 0.08, 0.85), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.05, 0)), Vector3(l + 0.08, 0.1, 0.83), PIERRE_SOMBRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.64, 0)), Vector3(l - 0.12, 0.06, 0.6), TERRE)
		var n := int(l / 0.4)
		for i in n:
			_touffe(o, p + Vector3(-l * 0.5 + 0.25 + i * (l - 0.5) / maxf(1, n - 1), 0.82, o.rng.randf_range(-0.12, 0.12)), o.rng.randf_range(0.26, 0.34), fleur, 6)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.35, 0)), Vector3(l, 0.7, 0.8)])
		return Vector2(l + 0.1, 0.85)

	static func pot(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		# un grand pot de terre cuite et un buis taillé en deux boules
		var t := Transform3D(Basis(), p)
		o.cylindre(t, 0.3, 0.4, 0.6, 12, Color("c87850"))
		o.anneau(t.translated(Vector3(0, 0.56, 0)), 0.34, 0.45, 0.1, 12, Color("b86a45"))
		o.cylindre(t.translated(Vector3(0, 0.6, 0)), 0.36, 0.36, 0.02, 12, TERRE)
		o.boule(p + Vector3(0, 1.05, 0), Vector3(0.42, 0.4, 0.42), Color("4f9a34"), 0.08, Outils.FEUILLE, 0.05, 0.2)
		o.boule(p + Vector3(0, 1.62, 0), Vector3(0.28, 0.27, 0.28), Color("5aa83a"), 0.08, Outils.FEUILLE, 0.05, 0.2)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(0.8, 1.0, 0.8)])
		return Vector2(0.9, 0.9)

	static func massif(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 4.0))
		var fleur := _fleur(o, opt)
		# une bordure basse de pierre, la terre, des rosiers en touffes et une petite haie de fond
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(0, 0.12, cote * 0.75)), Vector3(l, 0.24, 0.14), PIERRE)
			o.boite(Transform3D(Basis(), p + Vector3(cote * l * 0.5, 0.12, 0)), Vector3(0.14, 0.24, 1.64), PIERRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.1, 0)), Vector3(l - 0.1, 0.2, 1.4), TERRE)
		var n := int(l / 0.55)
		for i in n:
			var x := -l * 0.5 + 0.35 + i * (l - 0.7) / maxf(1, n - 1)
			o.boule(p + Vector3(x, 0.55, -0.4), Vector3(0.38, 0.38, 0.3), Color("4f8f30"), 0.15, Outils.FEUILLE, 0.05, 0.3)
			_touffe(o, p + Vector3(x + o.rng.randf_range(-0.1, 0.1), 0.42, 0.25), o.rng.randf_range(0.28, 0.36), fleur, 7)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.3, 0)), Vector3(l, 0.6, 1.6)])
		return Vector2(l + 0.14, 1.64)
