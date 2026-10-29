extends Node3D
## Un objet du mobilier des places toulousaines, posé tel quel : on règle objet, graine et options avant de
## l'ajouter à la scène, il se bâtit à son entrée dans l'arbre de scène. Le pied est à l'origine, sur un sol plat à
## y = 0, le devant regarde +Z ; en mètres (une commune à l'échelle du village de Smarves, 1 unité = 2,4 m, la pose
## à l'échelle 1/2,4).
##   var o = load(Bibliotheque.scene("mobilier-toulousain@1", "decor")).instantiate()
##   o.objet = "carrousel" ; o.graine = 3
##   add_child(o)
## Après la construction, le nœud porte ses métadonnées : objet, graine, emprise (la taille au sol, Vector2).
## Ce que les autres mobiliers ont déjà ne se refait pas ici : le banc, la corbeille, l'étal et le garde-corps se
## prennent à mobilier-lyonnais@1, les arbres aux briques de végétation.
const Outils := preload("res://bibliotheque/mobilier-toulousain/1/outils.gd")

## Les objets : la terrasse de café (tables rondes et chaises de rotin), le parasol rond, le grand parasol carré
## et ses tables, le store de terrasse sur pieds, le chevalet du menu, le potelet de fonte, l'appui-vélo, le
## lampadaire toulousain, le bac de bois fleuri, le bac végétal maçonné, le jardin d'enfants et le carrousel.
const OBJETS := ["terrasse", "parasol", "grand_parasol", "store_terrasse", "chevalet", "potelet", "appui_velo",
	"lampadaire", "bac_bois", "bac_vegetal", "jardin_enfants", "carrousel"]

const FONTE := Color("23272a")
const FONTE_CLAIRE := Color("3a3f44")
const OR := Color("c9a24a")
const ROTIN := Color("c39a5e")
const ROTIN_SOMBRE := Color("8a6436")
const BOIS := Color("9a6a3e")
const BOIS_CLAIR := Color("c9935a")
const NAPPE := Color("f4efe2")
const CREME := Color("f0e3c4")
const BORDEAUX := Color("8a2a2e")
const VERT_STORE := Color("2f6a4a")
const PIERRE := Color("efe6d4")
const BRIQUE := Color("c8653f")
const TERRE := Color("6b4f36")
const VERT := Color("5f9e33")
const FLEURS := ["e0605a", "f2c14e", "d04a6a", "f4f0e6", "e8823a", "c05ac0"]
const TOILES := [["f0e3c4", "f0e3c4"], ["8a2a2e", "8a2a2e"], ["f0e3c4", "8a2a2e"]]

## L'objet (voir OBJETS).
@export var objet := "terrasse"
## La graine : la toile d'un parasol, les fleurs d'un bac, les chevaux du carrousel, le menu du chevalet.
@export var graine := 1
## Les options, toutes facultatives : toile (deux hexas : un parasol, un store), fleurs (un hexa), allume (false :
## la lanterne éteinte), longueur (le bac, l'appui-vélo : en mètres), tables (la terrasse : 1 à 4), tourne (false :
## le carrousel à l'arrêt). Le bac végétal : forme (« rectangle », « L » ou « polygone »), longueur et largeur (le
## rectangle, le L), retour (la branche du L), points (le polygone : des Vector2 ou des paires [x, z], en mètres,
## le contour extérieur), hauteur (le muret, 0,5 m), terre (de la terre au rebord, 0,12 m), plantation (« dense »,
## « fleurie » ou « buis »).
@export var options := {}

var fait := false
var _manege: Node3D


func _ready() -> void:
	if fait:
		return
	fait = true
	var m := poser(self, Vector3.ZERO, objet, graine, options)
	for k in m:
		set_meta(k, m[k])
	if objet == "carrousel" and options.get("tourne", true):
		_manege = get_child(0) as Node3D
		set_process(true)


func _process(delta: float) -> void:
	if _manege != null:
		_manege.rotate_y(delta * 0.45)


## Les objets, pour une commune qui les passe en revue.
static func objets() -> Array:
	return OBJETS.duplicate()


## Les mêmes, sous le nom commun aux autres briques.
static func noms() -> Array:
	return objets()


## Bâtit un objet sous parent, son pied en p (sans rotation : tourner le parent). Rend objet, graine, emprise.
static func poser(parent: Node3D, p: Vector3, nom: String, g: int, opt := {}) -> Dictionary:
	if not nom in OBJETS:
		nom = "terrasse"
	var o := Outils.new(g * 104729 + OBJETS.find(nom) * 37)
	var emprise: Vector2 = Callable(_Objets, nom).call(o, p, opt)
	o.construire(parent, nom.capitalize())
	return {"objet": nom, "graine": g, "emprise": emprise}


class _Objets:
	static func _fleur(o: Outils, opt: Dictionary) -> Color:
		return Color(str(opt.get("fleurs", FLEURS[o.rng.randi() % FLEURS.size()])))

	static func _toile(o: Outils, opt: Dictionary) -> Array:
		var t: Array = opt.get("toile", TOILES[o.rng.randi() % TOILES.size()])
		return t.map(func(h): return Color(str(h)))

	## Une table ronde de bistrot, plateau de marbre clair sur pied de fonte, et n chaises de rotin autour.
	static func _table(o: Outils, c: Vector3, n: int, a0: float) -> void:
		o.cylindre(Transform3D(Basis(), c), 0.24, 0.24, 0.03, 10, FONTE)
		o.cylindre(Transform3D(Basis(), c), 0.03, 0.03, 0.72, 6, FONTE)
		o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.72, 0)), 0.34, 0.34, 0.03, 16, Color("ece6d8"))
		o.cylindre(Transform3D(Basis(), c + Vector3(0.08, 0.75, 0.04)), 0.035, 0.03, 0.12, 8, Color("e8e2d0"))
		for i in n:
			var a := a0 + TAU * i / n
			_chaise(o, c + Vector3(sin(a), 0, cos(a)) * 0.62, a)

	## La chaise de rotin tressé : assise, dossier cintré à bandes, pieds de bambou.
	static func _chaise(o: Outils, c: Vector3, a: float) -> void:
		var b := Basis(Vector3.UP, a)
		o.cylindre(Transform3D(b, c + Vector3(0, 0.44, 0)), 0.22, 0.22, 0.05, 10, ROTIN)
		for dx in [-0.15, 0.15]:
			for dz in [-0.15, 0.15]:
				o.branche(c + b * Vector3(dx, 0, dz), c + b * Vector3(dx * 0.9, 0.45, dz * 0.9), 0.016, 0.016, ROTIN_SOMBRE, 4)
		for k in 3:
			var ang := -0.9 + k * 0.9
			var q := c + b * Vector3(sin(ang) * 0.2, 0.68, 0.17 + cos(ang) * 0.02)
			o.boite(Transform3D(b * Basis(Vector3.UP, ang), q), Vector3(0.16, 0.4, 0.03), ROTIN if k != 1 else ROTIN.lightened(0.08))
		o.branche(c + b * Vector3(-0.21, 0.88, 0.16), c + b * Vector3(0.21, 0.88, 0.16), 0.02, 0.02, ROTIN_SOMBRE, 4)
		for k in 3:
			o.boite(Transform3D(b, c + b * Vector3(0, 0.55 + k * 0.1, 0.2)), Vector3(0.42, 0.015, 0.02), ROTIN_SOMBRE)

	## Un parasol rond à huit pans sur son mât, de rayon r, en c.
	static func _parasol_rond(o: Outils, c: Vector3, r: float, toile: Array, h: float) -> void:
		o.cylindre(Transform3D(Basis(), c), 0.25, 0.25, 0.08, 10, FONTE)
		o.cylindre(Transform3D(Basis(), c), 0.03, 0.03, h + 0.1, 6, Color("efe8d8"))
		var haut := c + Vector3(0, h + 0.25, 0)
		var n := 8
		for i in n:
			var a := TAU * i / n
			var b := TAU * (i + 1) / n
			var pa := c + Vector3(cos(a) * r, h - 0.3, sin(a) * r)
			var pb := c + Vector3(cos(b) * r, h - 0.3, sin(b) * r)
			var col: Color = toile[i % 2]
			o.tri(haut, pa, pb, Vector3.UP, col)
			o.tri(haut, pb, pa, Vector3.DOWN, col.darkened(0.25))
			var m := ((pa + pb) * 0.5 - c)
			o.quad(pa, pb, pb - Vector3(0, 0.16, 0), pa - Vector3(0, 0.16, 0), Vector3(m.x, 0, m.z).normalized(), col)
		o.boule(haut + Vector3(0, 0.05, 0), Vector3.ONE * 0.06, Color("efe8d8"), 0.0, Outils.DUR, 0.0)

	static func terrasse(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var n := clampi(int(opt.get("tables", 3)), 1, 4)
		for k in n:
			var c := p + Vector3((k - (n - 1) * 0.5) * 1.6, 0, (0.25 if k % 2 == 0 else -0.25))
			_table(o, c, 2 + (k % 2), o.rng.randf_range(0.0, 0.6))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, 0)), Vector3(n * 1.6, 0.9, 1.4)])
		return Vector2(n * 1.6 + 0.4, 1.8)

	static func parasol(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		# le parasol rond de terrasse, sa table et ses trois chaises
		_parasol_rond(o, p, 1.5, _toile(o, opt), 2.3)
		_table(o, p + Vector3(0.0, 0, 0.0), 3, 0.4)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, 0)), Vector3(1.6, 0.9, 1.6)])
		return Vector2(3.0, 3.0)

	static func grand_parasol(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var toile: Array = _toile(o, opt) if opt.has("toile") else [CREME, CREME]
		# le grand parasol carré, toile crème à lambrequin, et deux tables dessous
		o.cylindre(Transform3D(Basis(), p), 0.35, 0.35, 0.12, 4, FONTE)
		o.cylindre(Transform3D(Basis(), p), 0.05, 0.05, 2.8, 6, BOIS_CLAIR)
		var haut := p + Vector3(0, 3.0, 0)
		var r := 2.0
		var coins := [Vector3(-r, 2.35, -r), Vector3(r, 2.35, -r), Vector3(r, 2.35, r), Vector3(-r, 2.35, r)]
		for i in 4:
			var a: Vector3 = p + coins[i]
			var b: Vector3 = p + coins[(i + 1) % 4]
			var col: Color = toile[i % 2]
			o.tri(haut, a, b, Vector3.UP, col)
			o.tri(haut, b, a, Vector3.DOWN, col.darkened(0.25))
			var m: Vector3 = ((a + b) * 0.5 - p)
			var nm := Vector3(m.x, 0, m.z).normalized()
			# le lambrequin festonné
			for k in 8:
				var q := a.lerp(b, (k + 0.5) / 8.0)
				o.quad(q - (b - a) / 16.0, q + (b - a) / 16.0, q + (b - a) / 16.0 - Vector3(0, 0.18, 0), q - (b - a) / 16.0 - Vector3(0, 0.24 if k % 2 == 0 else 0.16, 0), nm, col.darkened(0.04))
			o.branche(p + Vector3(0, 2.4, 0), a + Vector3(0, -0.02, 0), 0.015, 0.015, BOIS_CLAIR, 4)
		for k in 2:
			_table(o, p + Vector3(-0.95 + k * 1.9, 0, 0.4 - k * 0.8), 2, 0.3 + k)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, 0)), Vector3(3.0, 0.9, 2.2)])
		return Vector2(4.2, 4.2)

	static func store_terrasse(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var toile: Array = _toile(o, opt) if opt.has("toile") else [VERT_STORE, CREME]
		# le store rayé posé sur quatre poteaux de fer, en pente vers l'avant, deux tables dessous
		var w := 4.0
		var dz := 2.6
		for x in [-w * 0.5 + 0.1, w * 0.5 - 0.1]:
			o.boite(Transform3D(Basis(), p + Vector3(x, 1.25, -dz * 0.5 + 0.1)), Vector3(0.07, 2.5, 0.07), FONTE)
			o.boite(Transform3D(Basis(), p + Vector3(x, 1.05, dz * 0.5 - 0.1)), Vector3(0.07, 2.1, 0.07), FONTE)
			o.cylindre(Transform3D(Basis(), p + Vector3(x, 0, -dz * 0.5 + 0.1)), 0.12, 0.12, 0.05, 6, FONTE)
			o.cylindre(Transform3D(Basis(), p + Vector3(x, 0, dz * 0.5 - 0.1)), 0.12, 0.12, 0.05, 6, FONTE)
		var pente := atan2(0.4, dz)
		var bandes := 10
		var lt := w / bandes
		for i in bandes:
			var x := -w * 0.5 + (i + 0.5) * lt
			var col: Color = toile[i % 2]
			o.boite(Transform3D(Basis(Vector3.RIGHT, pente), p + Vector3(x, 2.32, 0)), Vector3(lt, 0.04, dz + 0.2), col)
			o.boite(Transform3D(Basis(), p + Vector3(x, 1.98, dz * 0.5 + 0.1)), Vector3(lt, 0.26, 0.02), col)
		for k in 2:
			_table(o, p + Vector3(-1.0 + k * 2.0, 0, 0.1), 2, 0.2 + k)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, 0)), Vector3(3.6, 0.9, 1.4)])
		return Vector2(w + 0.2, dz + 0.4)

	static func chevalet(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		# le chevalet d'ardoise du menu, en A, cadre de bois, lignes à la craie
		var a := 0.18
		for cote in [-1.0, 1.0]:
			var b := Basis(Vector3.RIGHT, cote * a)
			var c := p + Vector3(0, 0.5, cote * 0.1)
			o.boite(Transform3D(b, c), Vector3(0.6, 1.0, 0.04), BOIS)
			o.boite(Transform3D(b, c + b * Vector3(0, 0.03, cote * 0.025)), Vector3(0.5, 0.78, 0.01), Color("2c2f30"))
			for k in 6:
				var l := o.rng.randf_range(0.18, 0.38)
				o.boite(Transform3D(b, c + b * Vector3(-0.2 + l * 0.5, 0.3 - k * 0.11, cote * 0.032)), Vector3(l, 0.025, 0.005), Color("ecebe4"))
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.5, 0)), Vector3(0.6, 1.0, 0.4)])
		return Vector2(0.7, 0.5)

	static func potelet(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		# le potelet de fonte : fût galbé, deux bagues, la tête en dôme
		var t := Transform3D(Basis(), p)
		o.cylindre(t.translated(Vector3(0, -0.05, 0)), 0.1, 0.09, 0.15, 10, FONTE)
		o.cylindre(t.translated(Vector3(0, 0.1, 0)), 0.075, 0.06, 0.7, 10, FONTE)
		o.cylindre(t.translated(Vector3(0, 0.78, 0)), 0.08, 0.08, 0.04, 10, FONTE_CLAIRE)
		o.cylindre(t.translated(Vector3(0, 0.2, 0)), 0.085, 0.085, 0.04, 10, FONTE_CLAIRE)
		o.boule(p + Vector3(0, 0.86, 0), Vector3(0.075, 0.07, 0.075), FONTE, 0.0, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.45, 0)), Vector3(0.2, 0.9, 0.2)])
		return Vector2(0.25, 0.25)

	static func appui_velo(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 3.0))
		var n := maxi(1, int(l / 0.8))
		# des arceaux de fer en U renversé, scellés dans le sol
		for i in n:
			var x := -l * 0.5 + (i + 0.5) * l / n
			var pts := Outils.arc(Vector2(0, 0.55), 0.3, 0.0, PI, 8)
			var prev := Vector3(x, -0.05, 0.3)
			for q in pts:
				var cur := Vector3(x, q.y, q.x)
				o.branche(p + prev, p + cur, 0.025, 0.025, FONTE_CLAIRE, 5)
				prev = cur
			o.branche(p + prev, p + Vector3(x, -0.05, -0.3), 0.025, 0.025, FONTE_CLAIRE, 5)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.42, 0)), Vector3(l, 0.85, 0.12)])
		return Vector2(l, 0.7)

	static func lampadaire(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		# le lampadaire toulousain : socle mouluré, fût de fonte noire à bagues, crosse courte, lanterne à six pans
		var t := Transform3D(Basis(), p)
		o.cylindre(t.translated(Vector3(0, -0.05, 0)), 0.26, 0.22, 0.4, 8, FONTE)
		o.cylindre(t.translated(Vector3(0, 0.35, 0)), 0.18, 0.12, 0.3, 8, FONTE)
		o.cylindre(t.translated(Vector3(0, 0.65, 0)), 0.08, 0.06, 2.7, 8, FONTE)
		for y in [0.7, 1.6, 3.2]:
			o.cylindre(t.translated(Vector3(0, y, 0)), 0.1, 0.1, 0.06, 8, FONTE_CLAIRE)
		o.boite(Transform3D(Basis(), p + Vector3(0, 3.0, 0)), Vector3(0.6, 0.04, 0.04), FONTE)
		var c := p + Vector3(0, 3.38, 0)
		o.cylindre(Transform3D(Basis(), c), 0.12, 0.2, 0.08, 6, FONTE)
		var allume: bool = opt.get("allume", true)
		o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.08, 0)), 0.17, 0.22, 0.5, 6, Color("fff1c2") if allume else Color("cfd8dc"), Outils.LUEUR if allume else Outils.DUR)
		for i in 6:
			var a := TAU * i / 6.0
			o.branche(c + Vector3(cos(a) * 0.17, 0.08, sin(a) * 0.17), c + Vector3(cos(a) * 0.22, 0.58, sin(a) * 0.22), 0.012, 0.012, FONTE, 4)
		o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.58, 0)), 0.3, 0.06, 0.24, 6, FONTE)
		o.boule(c + Vector3(0, 0.86, 0), Vector3.ONE * 0.05, FONTE, 0.0, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.8, 0)), Vector3(0.45, 3.6, 0.45)])
		return Vector2(0.6, 0.6)

	static func bac_bois(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		var l := float(opt.get("longueur", 0.9))
		var fleur := _fleur(o, opt)
		# le bac de bois à lames, ses quatre pieds carrés, la terre et le massif fleuri
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.38, 0)), Vector3(l, 0.62, 0.9), BOIS_CLAIR)
		for k in 4:
			o.boite(Transform3D(Basis(), p + Vector3(0, 0.12 + k * 0.155, 0.452)), Vector3(l - 0.12, 0.02, 0.01), BOIS)
			o.boite(Transform3D(Basis(), p + Vector3(0, 0.12 + k * 0.155, -0.452)), Vector3(l - 0.12, 0.02, 0.01), BOIS)
		for dx in [-1.0, 1.0]:
			for dz in [-1.0, 1.0]:
				o.boite(Transform3D(Basis(), p + Vector3(dx * (l * 0.5 - 0.04), 0.36, dz * 0.41)), Vector3(0.1, 0.72, 0.1), BOIS)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.7, 0)), Vector3(l - 0.1, 0.02, 0.8), TERRE)
		var n := maxi(2, int(l / 0.35))
		for i in n:
			var q := p + Vector3(-l * 0.5 + 0.2 + i * (l - 0.4) / maxf(1, n - 1), 0.88, o.rng.randf_range(-0.2, 0.2))
			o.boule(q, Vector3(0.24, 0.24, 0.24), VERT.lightened(o.rng.randf_range(-0.06, 0.1)), 0.25, Outils.FEUILLE, 0.06, 0.4)
			for k in 4:
				o.boule(q + Vector3(o.rng.randf_range(-0.16, 0.16), 0.16, o.rng.randf_range(-0.16, 0.16)), Vector3.ONE * 0.07, fleur.lightened(o.rng.randf_range(-0.1, 0.1)), 0.2, Outils.FEUILLE, 0.06, 0.3)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.36, 0)), Vector3(l, 0.72, 0.9)])
		return Vector2(l, 0.9)

	## Le contour d'un bac végétal selon ses options, centré sur l'origine : (x, z) en mètres.
	static func _contour(opt: Dictionary) -> PackedVector2Array:
		var forme := str(opt.get("forme", "rectangle"))
		var l := float(opt.get("longueur", 4.0))
		var w := float(opt.get("largeur", 1.2))
		var pts := PackedVector2Array()
		if forme == "polygone" and opt.get("points", []) is Array and (opt["points"] as Array).size() >= 3:
			for q in opt["points"]:
				pts.append(q if q is Vector2 else Vector2(float(q[0]), float(q[1])))
		elif forme == "L":
			var retour := float(opt.get("retour", l * 0.6))
			pts = PackedVector2Array([Vector2(0, 0), Vector2(l, 0), Vector2(l, w), Vector2(w, w), Vector2(w, retour), Vector2(0, retour)])
		else:
			pts = PackedVector2Array([Vector2(0, 0), Vector2(l, 0), Vector2(l, w), Vector2(0, w)])
		var mini := pts[0]
		var maxi := pts[0]
		for q in pts:
			mini = Vector2(minf(mini.x, q.x), minf(mini.y, q.y))
			maxi = Vector2(maxf(maxi.x, q.x), maxf(maxi.y, q.y))
		var centre := (mini + maxi) * 0.5
		for i in pts.size():
			pts[i] -= centre
		if Geometry2D.is_polygon_clockwise(pts):
			pts.reverse()
		return pts

	static func bac_vegetal(o: Outils, p: Vector3, opt: Dictionary) -> Vector2:
		# le muret de brique foraine et ses joints, la couvertine de pierre, la terre à quelques centimètres sous le
		# rebord et la plantation : un massif dense, un massif fleuri, ou des buis taillés en boule
		var pts := _contour(opt)
		var h := float(opt.get("hauteur", 0.5))
		var terre := float(opt.get("terre", 0.12))
		var plantation := str(opt.get("plantation", "dense"))
		var ep := 0.22
		var brique := Color("c46a46")
		var couvertine := Color("d9cdb6")
		var mini := Vector2(INF, INF)
		var maxi := Vector2(-INF, -INF)
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			mini = Vector2(minf(mini.x, a.x), minf(mini.y, a.y))
			maxi = Vector2(maxf(maxi.x, a.x), maxf(maxi.y, a.y))
			var e := b - a
			var lg := e.length()
			if lg < 0.05:
				continue
			var u := e / lg
			# la normale vers l'intérieur (contour dans le sens direct)
			var dedans := Vector2(-u.y, u.x)
			var milieu := (a + b) * 0.5 + dedans * ep * 0.5
			var bs := Basis(Vector3.UP, -atan2(u.y, u.x))
			var c := p + Vector3(milieu.x, 0, milieu.y)
			o.boite(Transform3D(bs, c + Vector3(0, h * 0.5 - 0.05, 0)), Vector3(lg + ep * 0.5, h + 0.1, ep), brique, Outils.DUR, true)
			# les joints de mortier, tous les deux rangs, et quelques briques plus sombres
			var y := 0.1
			while y < h - 0.08:
				o.boite(Transform3D(bs, c + Vector3(0, y, 0) - bs.z * (ep * 0.5 + 0.003) * 1.0), Vector3(lg, 0.012, 0.006), Color("e6d6bc"))
				o.boite(Transform3D(bs, c + Vector3(0, y, 0) + bs.z * (ep * 0.5 + 0.003)), Vector3(lg, 0.012, 0.006), Color("e6d6bc"))
				y += 0.1
			var nb := int(lg / 0.5)
			for k in nb:
				var xk := -lg * 0.5 + (k + o.rng.randf()) * lg / maxf(1, nb)
				var yk := 0.05 + o.rng.randi_range(0, int((h - 0.2) / 0.05)) * 0.05
				o.boite(Transform3D(bs, c + bs.x * xk + Vector3(0, yk, 0) - bs.z * (ep * 0.5 + 0.004)), Vector3(0.22, 0.045, 0.006), brique.darkened(o.rng.randf_range(0.1, 0.22)))
			o.boite(Transform3D(bs, c + Vector3(0, h + 0.03, 0)), Vector3(lg + ep * 0.5 + 0.06, 0.06, ep + 0.07), couvertine)
		# la terre, au dedans du muret
		var dedans_pts := pts
		var r := Geometry2D.offset_polygon(pts, -ep + 0.01, Geometry2D.JOIN_MITER)
		if r.size() > 0:
			dedans_pts = r[0]
		var sol := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
		o.profil(Transform3D(sol, p), dedans_pts, -(h - terre), -(h - terre) + 0.3, TERRE)
		# la plantation, semée dans le dedans
		var aire := (maxi.x - mini.x) * (maxi.y - mini.y)
		var fleur := _fleur(o, opt)
		var n := int(aire * (2.2 if plantation == "buis" else 6.0))
		var faits := 0
		var essais := 0
		var haut := h - terre
		while faits < n and essais < n * 8:
			essais += 1
			var q := Vector2(o.rng.randf_range(mini.x, maxi.x), o.rng.randf_range(mini.y, maxi.y))
			if not Geometry2D.is_point_in_polygon(q, dedans_pts):
				continue
			var c := p + Vector3(q.x, haut, q.y)
			if plantation == "buis":
				var rb := o.rng.randf_range(0.2, 0.28)
				o.boule(c + Vector3(0, rb * 0.85, 0), Vector3(rb, rb * 0.95, rb), Color("355e2a").lightened(o.rng.randf_range(-0.04, 0.08)), 0.08, Outils.FEUILLE, 0.03, 0.15)
			else:
				var rv := o.rng.randf_range(0.18, 0.38)
				o.boule(c + Vector3(0, rv * 0.6, 0), Vector3(rv, rv * o.rng.randf_range(0.7, 1.3), rv), VERT.darkened(o.rng.randf_range(0.0, 0.25)).lightened(o.rng.randf_range(0.0, 0.08)), 0.25, Outils.FEUILLE, 0.06, 0.4)
				if plantation == "fleurie" or (plantation == "dense" and o.rng.randf() < 0.12):
					for k in 5:
						o.boule(c + Vector3(o.rng.randf_range(-rv, rv) * 0.7, rv * o.rng.randf_range(0.8, 1.3), o.rng.randf_range(-rv, rv) * 0.7), Vector3.ONE * 0.06, fleur.lightened(o.rng.randf_range(-0.1, 0.12)), 0.2, Outils.FEUILLE, 0.05, 0.3)
				if plantation == "dense" and o.rng.randf() < 0.18:
					# une graminée, plus haute, qui ondule
					for k in 6:
						var a := o.rng.randf() * TAU
						o.branche(c, c + Vector3(cos(a) * 0.18, o.rng.randf_range(0.5, 0.8), sin(a) * 0.18), 0.012, 0.004, Color("8fa65a"), 3)
			faits += 1
		return maxi - mini

	static func jardin_enfants(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		var w := 9.0
		var d := 7.0
		# le sol souple, cerné d'un muret bas de brique à chaperon de pierre et d'une grille, un portillon
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.1, 0)), Vector3(w, 0.24, d), Color("b98a5a"))
		for i in 40:
			o.boule(p + Vector3(o.rng.randf_range(-w * 0.45, w * 0.45), 0.02, o.rng.randf_range(-d * 0.45, d * 0.45)), Vector3(0.3, 0.02, 0.3), Color("a87a4c"), 0.1, Outils.DUR, 0.03)
		for cote in 4:
			var long := w if cote % 2 == 0 else d
			var b := Basis(Vector3.UP, PI * 0.5 * cote)
			var off := (d if cote % 2 == 0 else w) * 0.5
			var tm := Transform3D(b, p + b * Vector3(0, 0, off))
			if cote == 0:
				# le côté du portillon : deux bouts de muret
				for s in [-1.0, 1.0]:
					o.boite(tm * Transform3D(Basis(), Vector3(s * (long * 0.25 + 0.4), 0.22, 0)), Vector3(long * 0.5 - 0.8, 0.44, 0.3), BRIQUE)
					o.boite(tm * Transform3D(Basis(), Vector3(s * (long * 0.25 + 0.4), 0.47, 0)), Vector3(long * 0.5 - 0.76, 0.06, 0.36), PIERRE)
				o.boite(tm * Transform3D(Basis(), Vector3(0.0, 0.5, 0.05)), Vector3(1.4, 0.9, 0.04), FONTE)
			else:
				o.boite(tm * Transform3D(Basis(), Vector3(0, 0.22, 0)), Vector3(long, 0.44, 0.3), BRIQUE)
				o.boite(tm * Transform3D(Basis(), Vector3(0, 0.47, 0)), Vector3(long + 0.04, 0.06, 0.36), PIERRE)
			o.boite(tm * Transform3D(Basis(), Vector3(0, 1.1, 0)), Vector3(long, 0.04, 0.04), FONTE)
			var nb := int(long / 0.16)
			for i in nb:
				var x := -long * 0.5 + (i + 0.5) * long / nb
				if cote == 0 and absf(x) < 0.75:
					continue
				o.boite(tm * Transform3D(Basis(), Vector3(x, 0.8, 0)), Vector3(0.02, 0.6, 0.02), FONTE)
			o.collisions.append([tm * Transform3D(Basis(), Vector3(0, 0.55, 0)), Vector3(long, 1.1, 0.3)])
		# le portique des balançoires
		var bp := p + Vector3(-2.2, 0, -1.2)
		for s in [-1.0, 1.0]:
			for k in [-1.0, 1.0]:
				o.branche(bp + Vector3(s * 1.4 + k * 0.0, 0, k * 0.6), bp + Vector3(s * 1.4, 2.3, 0), 0.06, 0.05, BOIS_CLAIR, 6)
		o.branche(bp + Vector3(-1.5, 2.3, 0), bp + Vector3(1.5, 2.3, 0), 0.07, 0.07, BOIS_CLAIR, 6)
		for s in [-0.6, 0.6]:
			for k in [-0.22, 0.22]:
				o.branche(bp + Vector3(s + k, 2.28, 0), bp + Vector3(s + k, 0.5, 0), 0.01, 0.01, FONTE_CLAIRE, 3)
			o.boite(Transform3D(Basis(), bp + Vector3(s, 0.5, 0)), Vector3(0.5, 0.05, 0.22), Color("d9473b") if s < 0 else Color("2f6a9a"))
		# la tour et son toboggan
		var tp := p + Vector3(2.4, 0, -0.8)
		for dx in [-0.6, 0.6]:
			for dz in [-0.6, 0.6]:
				o.boite(Transform3D(Basis(), tp + Vector3(dx, 1.4, dz)), Vector3(0.12, 2.8, 0.12), BOIS_CLAIR)
		o.boite(Transform3D(Basis(), tp + Vector3(0, 1.4, 0)), Vector3(1.4, 0.1, 1.4), BOIS)
		o.profil(Transform3D(Basis(), tp + Vector3(0, 2.6, 0)), PackedVector2Array([Vector2(-0.85, 0), Vector2(0.85, 0), Vector2(0, 0.6)]), -0.85, 0.85, [Color("d9473b"), Color("b8322c")])
		for k in 4:
			o.boite(Transform3D(Basis(), tp + Vector3(0, 0.3 + k * 0.3, 0.75)), Vector3(0.6, 0.05, 0.12), BOIS)
		var pente := atan2(1.4, 2.4)
		o.boite(Transform3D(Basis(Vector3.RIGHT, pente), tp + Vector3(0, 0.75, -1.9)), Vector3(0.6, 0.06, 2.8), Color("e8e4dc"))
		for s in [-0.32, 0.32]:
			o.boite(Transform3D(Basis(Vector3.RIGHT, pente), tp + Vector3(s, 0.85, -1.9)), Vector3(0.04, 0.2, 2.8), Color("d9d4c8"))
		# un banc pour les parents, un jeu à ressort
		o.boite(Transform3D(Basis(), p + Vector3(-3.3, 0.45, 2.6)), Vector3(1.6, 0.06, 0.45), BOIS_CLAIR)
		o.boite(Transform3D(Basis(), p + Vector3(-3.3, 0.22, 2.6)), Vector3(1.4, 0.44, 0.06), FONTE)
		o.cylindre(Transform3D(Basis(), p + Vector3(0.6, 0, 2.0)), 0.08, 0.08, 0.4, 8, Color("e0a93a"))
		o.boule(p + Vector3(0.6, 0.6, 2.0), Vector3(0.4, 0.22, 0.18), Color("4f9a3a"), 0.0, Outils.DUR, 0.0)
		o.boule(p + Vector3(0.9, 0.78, 2.0), Vector3(0.14, 0.14, 0.12), Color("4f9a3a"), 0.0, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), tp + Vector3(0, 1.4, 0)), Vector3(1.4, 2.8, 1.4)])
		return Vector2(w, d)

	static func carrousel(o: Outils, p: Vector3, _opt: Dictionary) -> Vector2:
		var R := 3.2
		# le plancher sur son socle, les colonnes torsadées, les chevaux, le toit rayé crème et rouge à lambrequins
		o.cylindre(Transform3D(Basis(), p + Vector3(0, -0.1, 0)), R + 0.1, R + 0.1, 0.45, 24, Color("8a5a3a"))
		o.cylindre(Transform3D(Basis(), p + Vector3(0, 0.35, 0)), R, R, 0.06, 24, Color("c9935a"))
		o.anneau(Transform3D(Basis(), p + Vector3(0, 0.12, 0)), R - 0.02, R + 0.12, 0.22, 24, OR)
		o.cylindre(Transform3D(Basis(), p + Vector3(0, 0.4, 0)), 0.9, 0.9, 2.6, 12, Color("f3e2c0"))
		for i in 12:
			var a := TAU * i / 12.0
			o.boite(Transform3D(Basis(Vector3.UP, -a), p + Vector3(cos(a) * 0.91, 1.7, sin(a) * 0.91)), Vector3(0.05, 2.2, 0.28), Color("d9473b") if i % 2 == 0 else OR)
		var nchev := 8
		for i in nchev:
			var a := TAU * (i + 0.5) / nchev
			var c := p + Vector3(cos(a), 0, sin(a)) * (R - 0.7)
			o.cylindre(Transform3D(Basis(), c + Vector3(0, 0.4, 0)), 0.03, 0.03, 2.6, 6, OR)
			var b := Basis(Vector3.UP, -a)
			var y := 1.0 + 0.25 * sin(i * 1.7)
			var robe: Color = [Color("f4f0e6"), Color("6a4a30"), Color("2a2a2a"), Color("d9b98a")][i % 4]
			o.boule(c + Vector3(0, y, 0), b * Vector3(0.18, 0.2, 0.5) + Vector3(0, 0, 0), robe, 0.05, Outils.DUR, 0.02)
			o.boite(Transform3D(b, c + Vector3(0, y + 0.06, 0)), Vector3(0.36, 0.38, 0.9), robe)
			o.boite(Transform3D(b * Basis(Vector3.RIGHT, -0.6), c + b * Vector3(0, y + 0.42, 0.45)), Vector3(0.18, 0.5, 0.2), robe)
			o.boite(Transform3D(b, c + b * Vector3(0, y + 0.62, 0.62)), Vector3(0.16, 0.18, 0.34), robe)
			o.boite(Transform3D(b, c + b * Vector3(0, y + 0.3, -0.05)), Vector3(0.4, 0.06, 0.34), Color("b8322c"))
			for k in 4:
				var dx := -0.12 if k % 2 == 0 else 0.12
				var dz := -0.32 if k < 2 else 0.32
				o.boite(Transform3D(b * Basis(Vector3.RIGHT, 0.4 if k >= 2 else -0.3), c + b * Vector3(dx, y - 0.32, dz)), Vector3(0.07, 0.5, 0.07), robe)
		for i in 16:
			var a := TAU * i / 16.0
			o.cylindre(Transform3D(Basis(), p + Vector3(cos(a), 0, sin(a)) * (R - 0.12) + Vector3(0, 0.4, 0)), 0.06, 0.06, 2.6, 6, OR if i % 2 == 0 else Color("f3e2c0"))
		# le toit conique à seize pans rayés, son lambrequin, son mât à fanion
		var haut := p + Vector3(0, 4.4, 0)
		for i in 16:
			var a := TAU * i / 16.0
			var b := TAU * (i + 1) / 16.0
			var pa := p + Vector3(cos(a) * (R + 0.3), 3.0, sin(a) * (R + 0.3))
			var pb := p + Vector3(cos(b) * (R + 0.3), 3.0, sin(b) * (R + 0.3))
			var col := Color("f3ead6") if i % 2 == 0 else Color("c0302a")
			o.tri(haut, pa, pb, Vector3.UP, col)
			o.tri(haut, pb, pa, Vector3.DOWN, col.darkened(0.3))
			var m := (pa + pb) * 0.5 - p
			var nm := Vector3(m.x, 0, m.z).normalized()
			o.quad(pa, pb, pb - Vector3(0, 0.35, 0), pa - Vector3(0, 0.35, 0), nm, Color("c0302a") if i % 2 == 0 else Color("f3ead6"))
			o.profil(Transform3D(Basis(Vector3.UP, -(a + b) * 0.5 + PI * 0.5), (pa + pb) * 0.5 - Vector3(0, 0.35, 0)), Outils.arc(Vector2.ZERO, pa.distance_to(pb) * 0.5, PI, TAU, 6), -0.01, 0.01, OR)
		o.cylindre(Transform3D(Basis(), haut), 0.04, 0.04, 0.9, 6, OR)
		o.boite(Transform3D(Basis(), haut + Vector3(0.22, 0.75, 0)), Vector3(0.4, 0.22, 0.02), Color("c0302a"))
		o.boule(haut + Vector3(0, 0.95, 0), Vector3.ONE * 0.08, OR, 0.0, Outils.DUR, 0.0)
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 0.1, 0)), Vector3(R * 1.8, 0.5, R * 1.8)])
		o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.7, 0)), Vector3(1.8, 2.6, 1.8)])
		return Vector2(R * 2.0 + 0.6, R * 2.0 + 0.6)
