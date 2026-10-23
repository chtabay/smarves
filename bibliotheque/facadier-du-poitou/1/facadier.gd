extends RefCounted
## Le façadier du Poitou, venu de Chauvigny 0.2.2 (Le duke, MIT) : une maison composée à partir d'un type et
## d'une graine. Les communes le prennent par la scène de la brique (maison.tscn) ou directement :
## load(<dossier de la brique> + "facadier.gd").maison(parent, position, type, graine, options).
## Chaque maison a un âge, un métier et une transformation, lisibles sur quatre axes à la fois :
## la silhouette (niveaux, faîtage, tourelle, lucarnes, souches), la matière (pierre de taille, moellon,
## enduits, pan de bois, brique ; tuile canal, tuile plate, ardoise), la décoration (encadrements,
## corniches, génoises, menuiseries et leurs couleurs par quartier) et l'habillage végétal (vigne vierge,
## lierre, treille, glycine, rosiers, jardinières, pots, herbes).
##
## Repère : façade vers +Z avant rotation, origine au pied de la façade au milieu (le corps s'étend vers
## -Z sur la profondeur d), en mètres. La géométrie s'accumule dans un « chantier » (un maillage par
## teinte), passe par A.mat et finit par A.fusionner : une surface par genre de matière (au plus quatre
## genres par maison), plus le feuillage (un maillage, teinte par sommet) et les fenêtres allumées.
const A := preload("res://bibliotheque/facadier-du-poitou/1/outils.gd")

const TYPES := ["medievale", "echoppe", "balet", "vigneron", "notable", "tailleur", "grange", "quai", "ouvriere", "forte"]
const QUARTIERS := ["cite", "basse", "quai", "montee"]

## Les genres de surface de matieres.gdshader.
const G_PLAT := 0
const G_CALC := 1
const G_ENDUIT := 2
const G_TUILE := 3
const G_BOIS := 4
const G_MOELLON := 7
const G_ARDOISE := 9
const G_TAILLE := 15
const LUM := "LUM"

## Les menuiseries par quartier : la cité en teintes sourdes, la ville basse franches, le quai en
## couleurs de bateau, la montée entre les deux.
const MENUISERIES := {
	"cite": ["c9c7bf", "dedad0", "b9c0bd", "a8b4b4", "8e5646", "c4bba8", "8a9a8a"],  # (0.2, d'après photos : surtout gris perle et blanc cassé)
	"montee": ["8e6a4e", "92a486", "7890a0", "984c40", "7e4652", "a8966a", "6e8268"],
	"basse": ["3e7458", "8e3040", "3a78a2", "bcc0ba", "58705c", "b08a3a", "2e5a7c"],
	"quai": ["3a76c8", "92cab8", "cc3e34", "e4b444", "4aa8ac", "f0eadc", "2e8c70"],
}
const ENDUITS := ["e0d4b8", "d3be98", "d6b6a2", "cbc7bc", "e8e2d2", "d8bf92", "dccab0"]
const ENDUITS_CHAUX := ["ece7d9", "e6dcc4", "e9e0cc", "e4d2ad", "e8d3c6", "dde3dc"]
const MOELLONS := ["c2b597", "cbbea0", "b9ab8e", "c6b99c", "bdb093"]
const TAILLES := ["dcd1b5", "e2d8be", "d5c9ab", "d9cfb6"]
const BRIQUES := ["a8553a", "9a4c35", "b0603f", "9e5a40"]
const TUILES_CANAL := ["9c6a55", "a8785f", "8f5f4d", "ad7f63", "986550", "885a4b"]  # (0.2 : un brun-rouge vieilli, moins orangé)
const TUILES_PLATES := ["8e5a45", "7f5040", "93614a", "865746"]
const ARDOISES := ["4a5560", "434d57", "525c66", "3e4750"]
const PUBLICITES := [
	["QUINQUINA DU POITOU", "TONIQUE · APÉRITIF"],
	["CHOCOLAT LA VIENNE", "LE DÉJEUNER DES ENFANTS SAGES"],
	["CHICORÉE LA BARONNIE", "EN VENTE PARTOUT"],
	["APÉRITIF L'ÉPERON", "AU VIN DE LA MONTÉE"],
	["CIRAGE LE HÉRON", "BRILLE COMME LA VIENNE"],
	["GRANDS MAGASINS DU MARCHÉ", "NOUVEAUTÉS · CONFECTION"],
]
const ENSEIGNES := ["VINS", "PAIN", "SABOTS", "BARBIER", "TABAC", "AU FAUCON", "CORDONNIER", "ÉPICERIE", "AU HÉRON", "MERCERIE"]


## Le chantier d'une maison : la géométrie s'y accumule par teinte avant d'être confiée à l'atelier.
class Chantier:
	extends RefCounted
	var g: Node3D
	var lots := {}
	var feuil: SurfaceTool = null
	var genres := {}
	var rng := RandomNumberGenerator.new()
	var S := {}


static var _mats := {}

## Une clé de matière : une teinte hexa et un genre de surface (« a99a80:7 »).
static func k(hex: String, genre: int) -> String:
	return "%s:%d" % [hex, genre]

## La matière d'une clé : la matière commune de la commune, avec un genre choisi (A.mat la reçoit telle
## quelle ; A.fusionner en tire la teinte par sommet et regroupe tout ce qui a le même genre).
static func matiere(cle: String) -> Material:
	if cle == LUM: return A.lumiere(Color("f3d398"), 1.35)
	if _mats.has(cle): return _mats[cle]
	var parts := cle.split(":")
	var m := ShaderMaterial.new()
	m.shader = A.SURFACE
	m.set_shader_parameter("teinte", Color(parts[0]))
	m.set_shader_parameter("genre", int(parts[1]))
	m.set_shader_parameter("rugosite", .88)
	m.set_shader_parameter("metal", 0.0)
	_mats[cle] = m
	return A.mat(m)

static func _genre_de(cle: String) -> int:
	return int(cle.split(":")[1]) if cle != LUM else -1

## Le chantier d'un nœud (pour les fonctions publiques appelées hors d'une maison) ou celui en cours.
static func chantier(r: Node3D, graine := 0) -> Chantier:
	var c := Chantier.new()
	c.g = r
	c.rng.seed = graine
	return c

## Au plus quatre genres par maison (plus le feuillage et les fenêtres allumées = six surfaces) :
## une teinte d'un cinquième genre se range dans le genre le plus proche déjà employé.
static func _st(c: Chantier, cle: String) -> SurfaceTool:
	if cle != LUM:
		var genre := _genre_de(cle)
		if not c.genres.has(genre):
			if c.genres.size() >= 4:
				var remplace := -1
				for g2 in [G_TAILLE, G_ENDUIT, G_MOELLON, G_CALC, G_BOIS, G_TUILE, G_ARDOISE, G_PLAT]:
					if c.genres.has(g2):
						remplace = g2
						break
				cle = k(cle.split(":")[0], remplace)
			else:
				c.genres[genre] = true
	if not c.lots.has(cle):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		c.lots[cle] = st
	return c.lots[cle]

## Confie la géométrie du chantier à son nœud : un maillage par teinte (A.fusionner les regroupera par genre)
## et le feuillage en un seul maillage animé.
static func livrer(c: Chantier, fusion := true) -> void:
	for cle in c.lots:
		var mi := MeshInstance3D.new()
		mi.name = "Pan"
		mi.mesh = c.lots[cle].commit()
		mi.material_override = matiere(cle)
		c.g.add_child(mi)
	c.lots.clear()
	if c.feuil != null:
		var fm := MeshInstance3D.new()
		fm.name = "Feuillage"
		fm.mesh = c.feuil.commit()
		var sm := ShaderMaterial.new()
		sm.shader = A.FEUILLAGE
		sm.set_shader_parameter("souffle", .05)
		fm.material_override = sm
		fm.set_meta("anime", true)
		c.g.add_child(fm)
		c.feuil = null
	if fusion: A.fusionner(c.g)


# --- primitives de maillage -----------------------------------------------------------------------

## Un triangle de normale n (l'ordre des sommets est remis dans le sens que Godot dessine).
static func _tri(c: Chantier, cle: String, a: Vector3, b: Vector3, d: Vector3, n: Vector3) -> void:
	var st := _st(c, cle)
	if (b - a).cross(d - a).dot(n) > 0.0:
		var t := b
		b = d
		d = t
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(d)

static func _quad(c: Chantier, cle: String, a: Vector3, b: Vector3, d: Vector3, e: Vector3, n: Vector3) -> void:
	_tri(c, cle, a, b, d, n)
	_tri(c, cle, a, d, e, n)

## Une boîte (centre, taille, orientation) ; faces : masque des faces dessinées
## (1 +X, 2 -X, 4 +Y, 8 -Y, 16 +Z, 32 -Z).
static func _boite(c: Chantier, cle: String, ce: Vector3, t: Vector3, b := Basis(), faces := 63) -> void:
	var ax := b.x * t.x * .5
	var ay := b.y * t.y * .5
	var az := b.z * t.z * .5
	var liste := [[ax, ay, az, 1], [-ax, ay, az, 2], [ay, ax, az, 4], [-ay, ax, az, 8], [az, ax, ay, 16], [-az, ax, ay, 32]]
	for f in liste:
		if not (faces & int(f[3])): continue
		var nn: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var fc: Vector3 = ce + nn
		_quad(c, cle, fc - u - v, fc + u - v, fc + u + v, fc - u + v, nn.normalized())

## Une boîte alignée posée sur la façade (z0 = plan du mur), sans face arrière.
static func _saillie(c: Chantier, cle: String, x: float, y: float, w: float, h: float, z0: float, ep: float) -> void:
	_boite(c, cle, Vector3(x, y, z0 + ep * .5), Vector3(w, h, ep), Basis(), 31)

## Une plaque épaisse d'un polygone plan convexe (pans de toit) ; haut : vers où regarde le dessus.
static func _plaque(c: Chantier, cle: String, pts: Array, ep: float, haut := Vector3.UP, dessous := true) -> void:
	var n: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	if n.dot(haut) < 0.0: n = -n
	var centre := Vector3.ZERO
	for p in pts: centre += p
	centre /= pts.size()
	for i in range(1, pts.size() - 1):
		_tri(c, cle, pts[0], pts[i], pts[i + 1], n)
		if dessous: _tri(c, cle, pts[0] - n * ep, pts[i] - n * ep, pts[i + 1] - n * ep, -n)
	for i in pts.size():
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		var sortie := (b - a).cross(n).normalized()
		if sortie.dot((a + b) * .5 - centre) < 0.0: sortie = -sortie
		_quad(c, cle, a, b, b - n * ep, a - n * ep, sortie)

## Un polygone du plan de façade (x, y), extrudé de z0 à z1 (face avant et côtés).
static func _relief(c: Chantier, cle: String, pts: PackedVector2Array, z0: float, z1: float, cotes := true) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	for i in range(0, idx.size(), 3):
		var a := pts[idx[i]]
		var b := pts[idx[i + 1]]
		var d := pts[idx[i + 2]]
		_tri(c, cle, Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z1), Vector3(d.x, d.y, z1), Vector3.BACK)
	if not cotes or absf(z1 - z0) < .005: return
	var horaire := Geometry2D.is_polygon_clockwise(pts)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var e := b - a
		var sortie := Vector3(e.y, -e.x, 0).normalized() if not horaire else Vector3(-e.y, e.x, 0).normalized()
		_quad(c, cle, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1), sortie)

## Une bande (encadrement) le long d'une ligne ouverte du plan de façade, vers l'extérieur (à gauche du
## sens de parcours : la ligne monte à gauche, passe en haut, redescend à droite), de z0 à z1.
static func _bande(c: Chantier, cle: String, pts: PackedVector2Array, larg: float, z0: float, z1: float, tableau := true) -> void:
	var n := pts.size()
	var normales: Array[Vector2] = []
	for i in n:
		var avant := pts[i] - pts[maxi(i - 1, 0)] if i > 0 else pts[1] - pts[0]
		var apres := pts[mini(i + 1, n - 1)] - pts[i] if i < n - 1 else pts[n - 1] - pts[n - 2]
		var na := Vector2(-avant.y, avant.x).normalized()
		var nb := Vector2(-apres.y, apres.x).normalized()
		var m := (na + nb).normalized()
		var cosv := maxf(.5, m.dot(nb))
		normales.append(m / cosv)
	for i in n - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var ao := a + normales[i] * larg
		var bo := b + normales[i + 1] * larg
		_quad(c, cle, Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z1), Vector3(bo.x, bo.y, z1), Vector3(ao.x, ao.y, z1), Vector3.BACK)
		var e := (b - a).normalized()
		var dehors := Vector3(-e.y, e.x, 0)
		_quad(c, cle, Vector3(ao.x, ao.y, z0), Vector3(bo.x, bo.y, z0), Vector3(bo.x, bo.y, z1), Vector3(ao.x, ao.y, z1), dehors)
		if tableau:
			_quad(c, cle, Vector3(a.x, a.y, z0 - .06), Vector3(b.x, b.y, z0 - .06), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1), -dehors)

## Un prisme vertical à n pans (tour, tourelle, souche) de y0 à y1 ; avant_seul : seulement les pans
## qui regardent la rue (une tour engagée dans la façade).
static func _fut(c: Chantier, cle: String, centre: Vector3, r: float, y0: float, y1: float, n: int, a0 := 0.0, avant_seul := false, r_haut := -1.0) -> void:
	var rh := r if r_haut < 0.0 else r_haut
	for i in n:
		var t0 := a0 + TAU * i / n
		var t1 := a0 + TAU * (i + 1) / n
		var tm := (t0 + t1) * .5
		var nn := Vector3(sin(tm), (r - rh) / maxf(.01, y1 - y0), cos(tm)).normalized()
		if avant_seul and nn.z < -.35: continue
		var p0 := centre + Vector3(sin(t0) * r, y0, cos(t0) * r)
		var p1 := centre + Vector3(sin(t1) * r, y0, cos(t1) * r)
		var p2 := centre + Vector3(sin(t1) * rh, y1, cos(t1) * rh)
		var p3 := centre + Vector3(sin(t0) * rh, y1, cos(t0) * rh)
		_quad(c, cle, p0, p1, p2, p3, nn)

## Un cône ou une pyramide (toit de tourelle) posé à y, de rayon r et de hauteur h, avec son dessous.
static func _cone(c: Chantier, cle: String, centre: Vector3, r: float, y: float, h: float, n: int, a0 := 0.0) -> void:
	var s := centre + Vector3(0, y + h, 0)
	for i in n:
		var t0 := a0 + TAU * i / n
		var t1 := a0 + TAU * (i + 1) / n
		var p0 := centre + Vector3(sin(t0) * r, y, cos(t0) * r)
		var p1 := centre + Vector3(sin(t1) * r, y, cos(t1) * r)
		var nn := (p1 - p0).cross(s - p0).normalized()
		if nn.y < 0.0: nn = -nn
		_tri(c, cle, p0, p1, s, nn)
		_tri(c, cle, p0, p1, centre + Vector3(0, y, 0), Vector3.DOWN)

## Un texte gravé ou peint, en géométrie (TextMesh), posé sur un mur qui regarde vers +Z (ou tourné de ry).
static func _texte(c: Chantier, cle: String, t: String, p: Vector3, hauteur: float, ry := 0.0) -> void:
	var tm := TextMesh.new()
	tm.text = t
	tm.font = Polices.gras()
	tm.font_size = 32
	tm.pixel_size = hauteur / 24.0
	tm.depth = 0.0
	tm.curve_step = 3.0
	var arr := tm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx = arr[Mesh.ARRAY_INDEX]
	var b := Basis(Vector3.UP, ry)
	var nn := b * Vector3.BACK
	var liste: PackedInt32Array = idx if idx != null and not (idx as PackedInt32Array).is_empty() else PackedInt32Array(range(v.size()))
	for i in range(0, liste.size(), 3):
		var a := p + b * v[liste[i]]
		var bb := p + b * v[liste[i + 1]]
		var d := p + b * v[liste[i + 2]]
		_tri(c, cle, a, bb, d, nn)


# --- ouvertures ---------------------------------------------------------------------------------

## Le contour d'une ouverture de largeur w et de hauteur h (au sommet), de (-w/2, 0) à (w/2, 0) en passant
## par le haut. forme : droit, plein (cintre), surbaisse, anse (de panier), brise (arc brisé).
static func contour(forme: String, w: float, h: float, n := 7) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := w * .5
	match forme:
		"plein":
			var yn := maxf(.1, h - r)
			pts.append(Vector2(-r, 0))
			for i in n + 1:
				var a := PI - PI * i / n
				pts.append(Vector2(cos(a) * r, yn + sin(a) * r))
			pts.append(Vector2(r, 0))
		"surbaisse", "anse":
			var f := w * (.17 if forme == "surbaisse" else .3)
			var yn := maxf(.1, h - f)
			pts.append(Vector2(-r, 0))
			if forme == "anse":
				for i in n + 1:
					var a := PI - PI * i / n
					pts.append(Vector2(cos(a) * r, yn + sin(a) * f))
			else:
				var R := (r * r + f * f) / (2.0 * f)
				var cy := h - R
				var a0 := atan2(yn - cy, -r)
				var a1 := atan2(yn - cy, r)
				for i in n + 1:
					var a := lerpf(a0, a1, float(i) / n)
					pts.append(Vector2(cos(a) * R, cy + sin(a) * R))
			pts.append(Vector2(r, 0))
		"brise":
			var f := minf(w * .75, h * .5)
			var yn := h - f
			var cx := (f * f - r * r) / w
			var R := cx + r
			pts.append(Vector2(-r, 0))
			var m := maxi(3, n / 2 + 1)
			var a_fin := atan2(f, -cx)
			for i in m + 1:
				var a := lerpf(PI, a_fin, float(i) / m)
				pts.append(Vector2(cx + cos(a) * R, yn + sin(a) * R))
			for i in range(m - 1, -1, -1):
				var a := lerpf(PI, a_fin, float(i) / m)
				pts.append(Vector2(-(cx + cos(a) * R), yn + sin(a) * R))
			pts.append(Vector2(r, 0))
		_:
			pts.append_array([Vector2(-r, 0), Vector2(-r, h), Vector2(r, h), Vector2(r, 0)])
	return pts

static func _decale(pts: PackedVector2Array, x: float, y: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts: out.append(p + Vector2(x, y))
	return out

## Un volet (un vantail) : plein, barres (à barres et écharpe), persienne ; centre, taille, plan z.
static func _volet(c: Chantier, cle: String, x: float, y: float, w: float, h: float, z: float, genre: String, miroir := 1.0) -> void:
	match genre:
		"persienne":
			_boite(c, cle, Vector3(x, y, z + .015), Vector3(w, h, .03), Basis(), 31)
			var nb := clampi(int(h / .22), 4, 9)
			var pas := (h - .12) / nb
			for i in nb:
				var yy := y - h * .5 + .06 + pas * (i + .5)
				var a := Vector3(x - w * .5 + .04, yy + pas * .45, z + .03)
				var b := Vector3(x + w * .5 - .04, yy + pas * .45, z + .03)
				var nn := Vector3(0, .6, .8)
				_quad(c, cle, a, b, b + Vector3(0, -pas * .85, .035), a + Vector3(0, -pas * .85, .035), nn.normalized())
		"plein":
			_boite(c, cle, Vector3(x, y, z + .02), Vector3(w, h, .04), Basis(), 31)
			_boite(c, cle, Vector3(x, y, z + .045), Vector3(w * .7, h * .38, .012), Basis(), 31)
		_:
			_boite(c, cle, Vector3(x, y, z + .02), Vector3(w, h, .04), Basis(), 31)
			for t in [-.36, .36]:
				_boite(c, cle, Vector3(x, y + h * t, z + .048), Vector3(w * .92, .09, .02), Basis(), 31)
			var diag := Vector2(w * .8, h * .72)
			var ang := atan2(diag.y, diag.x) * miroir
			_boite(c, cle, Vector3(x, y, z + .05), Vector3(diag.length(), .08, .02), Basis(Vector3.BACK, ang), 31)

## Une fenêtre au pied (appui) en (x, y) sur un mur de plan z0, largeur w, hauteur h. o :
## forme, cadre (clé ou ""), larg (encadrement), meneaux (croisee, demi, ""), carreaux [colonnes, rangs],
## dormant (clé), volets (plein, barres, persienne, ""), couleur (clé), ouverture (1 ouverts, 0 fermés,
## .5 un seul), allumee, appui (bool), accolade, cle_voute (bool), garde_corps (clé ou ""), z.
static func fenetre(c: Chantier, x: float, y: float, w: float, h: float, o := {}) -> void:
	var z0: float = o.get("z", 0.0)
	var forme: String = o.get("forme", "droit")
	var cadre: String = o.get("cadre", "")
	var larg: float = o.get("larg", .16)
	var ct := contour(forme, w, h)
	var fond: String = LUM if o.get("allumee", false) else str(o.get("verre", k(_p(c, ["4a5a64", "52626a", "44545e", "5a6870"]), G_BOIS)))
	_relief(c, fond, _decale(ct, x, y), z0, z0 + .006, false)
	if fond != LUM and not o.has("verre") and w > .45 and c.rng.randf() < .45:
		# un voilage derrière la vitre
		var hv2 := (h if forme == "droit" else h - w * .5) * c.rng.randf_range(.55, .95)
		_saillie(c, k(_p(c, ["a8a296", "b4ad9e", "9c978c"]), G_BOIS), x, y + hv2 * .5 + .02, w - .04, hv2, z0 + .006, .002)
	if fond == LUM and c.rng.randf() < .45:
		# un rideau tiré à moitié, qui dessine la lumière
		var cote := -1.0 if c.rng.randf() < .5 else 1.0
		_saillie(c, k("d9cbb0", G_BOIS), x + cote * w * .3, y + h * .45, w * .38, h * .85, z0 + .006, .004)
	if cadre != "":
		_bande(c, cadre, _decale(ct, x, y), larg, z0, z0 + float(o.get("saillie", .06)))
		if o.get("cle_voute", false):
			_saillie(c, cadre, x, y + h + larg * .45, .24, larg * 1.25, z0, .09)
		if o.get("accolade", false):
			var pa := PackedVector2Array([Vector2(x - w * .5, y + h + larg * .55), Vector2(x - .12, y + h + larg * .55), Vector2(x, y + h + larg * .55 + .28), Vector2(x + .12, y + h + larg * .55), Vector2(x + w * .5, y + h + larg * .55), Vector2(x + w * .5, y + h + larg * .9), Vector2(x - w * .5, y + h + larg * .9)])
			_relief(c, cadre, pa, z0, z0 + .085)
	if o.get("appui", true):
		_saillie(c, str(o.get("cadre_appui", cadre if cadre != "" else k("d6cbb0", G_TAILLE))), x, y - .045, w + .22, .09, z0, .14)
	var dormant: String = o.get("dormant", k("e6e0d0", G_BOIS))
	var meneaux: String = o.get("meneaux", "")
	var pierre: String = cadre if cadre != "" else k("d6cbb0", G_TAILLE)
	var h_droit := h if forme == "droit" else h - w * .5
	if meneaux == "croisee" or meneaux == "demi":
		if meneaux == "croisee":
			_saillie(c, pierre, x, y + h * .5, .11, h, z0, .05)
		_saillie(c, pierre, x, y + h * .62, w, .11, z0, .05)
	else:
		var car: Array = o.get("carreaux", [2, 3])
		if int(car[0]) > 1:
			for i in int(car[0]) - 1:
				_saillie(c, dormant, x - w * .5 + w * (i + 1) / int(car[0]), y + h_droit * .5, .035, h_droit, z0, .025)
		for j in int(car[1]) - 1:
			_saillie(c, dormant, x, y + h_droit * (j + 1) / int(car[1]), w, .035, z0, .025)
		_bande(c, dormant, _decale(ct, x, y), -.045, z0, z0 + .02, false)
	var gc: String = o.get("garde_corps", "")
	if gc != "":
		_saillie(c, gc, x, y + .9, w + .1, .04, z0, .05)
		var nb := maxi(3, int(w / .12))
		for i in nb + 1:
			_saillie(c, gc, x - w * .5 + w * i / nb, y + .45, .018, .9, z0 + .02, .02)
	var volets: String = o.get("volets", "")
	if volets == "": return
	var coul: String = o.get("couleur", k("5f7380", G_BOIS))
	var ouv: float = o.get("ouverture", 1.0)
	var hv := h_droit
	var yv := y + hv * .5
	var lw := w * .5
	for s in [-1.0, 1.0]:
		var ouvert: bool = ouv > .75 or (ouv > .25 and s > 0.0)
		if ouvert:
			_volet(c, coul, x + s * (w * .5 + larg * .35 + lw * .5), yv, lw, hv, z0, volets, s)
		else:
			_volet(c, coul, x + s * lw * .5, yv, lw - .01, hv, z0 + .02, volets, -s)

## Une porte au seuil (x, y) : o : forme, cadre, larg, couleur, vantaux (1, 2), imposte (bool),
## style (planches, panneaux), heurtoir, seuil (bool), ouvert (un vantail entrebâillé : 0..1), z.
static func porte(c: Chantier, x: float, y: float, w: float, h: float, o := {}) -> void:
	var z0: float = o.get("z", 0.0)
	var forme: String = o.get("forme", "droit")
	var cadre: String = o.get("cadre", "")
	var larg: float = o.get("larg", .2)
	var coul: String = o.get("couleur", k("534638", G_BOIS))
	var ct := contour(forme, w, h)
	var h_droit := h if forme == "droit" else h - (w * .5 if forme == "plein" else (w * .17 if forme == "surbaisse" else (w * .3 if forme == "anse" else minf(w * .75, h * .5))))
	var imposte: bool = o.get("imposte", false)
	var h_porte := h_droit - (.5 if imposte and forme == "droit" else 0.0)
	var sombre := k("1e1c1a", G_BOIS)
	_relief(c, sombre, _decale(ct, x, y), z0, z0 + .004, false)
	if imposte:
		var haut := PackedVector2Array()
		for p in ct:
			if p.y >= h_porte - .01: haut.append(p + Vector2(x, y))
		if forme == "droit": haut = PackedVector2Array([Vector2(x - w * .5, y + h_porte), Vector2(x - w * .5, y + h), Vector2(x + w * .5, y + h), Vector2(x + w * .5, y + h_porte)])
		else:
			haut.insert(0, Vector2(x - w * .5, y + h_porte))
			haut.append(Vector2(x + w * .5, y + h_porte))
		_relief(c, LUM if o.get("allumee", false) else k("2c3a40", G_BOIS), haut, z0, z0 + .01, false)
		_saillie(c, coul, x, y + h_porte + .04, w, .08, z0, .05)
		if forme != "droit":
			for i in 3:
				var a := PI * (i + 1) / 4.0
				var bout := Vector3(x + cos(a) * w * .45, y + h_porte + sin(a) * (h - h_porte) * .9, z0 + .03)
				var pied := Vector3(x, y + h_porte, z0 + .03)
				_boite(c, coul, (bout + pied) * .5, Vector3(.03, pied.distance_to(bout), .02), Basis(Vector3.BACK, -(PI * .5 - a)), 31)
	var vant: int = o.get("vantaux", 1)
	var ouvert: float = o.get("ouvert", 0.0)
	var feuille := PackedVector2Array()
	if imposte or forme == "droit":
		feuille = PackedVector2Array([Vector2(-w * .5 + .03, 0), Vector2(-w * .5 + .03, h_porte), Vector2(w * .5 - .03, h_porte), Vector2(w * .5 - .03, 0)])
	else:
		feuille = contour(forme, w - .06, h - .03)
	var style: String = o.get("style", "planches")
	for v in vant:
		var x0 := -w * .5 + w * v / vant
		var x1 := -w * .5 + w * (v + 1) / vant
		if ouvert > 0.0 and v == vant - 1:
			# le vantail entrebâillé : on voit le noir du dedans et le chant du bois
			var lw := x1 - x0
			var ang := ouvert * 1.3
			var piv := Vector3(x + x1, y + h_porte * .5, z0 + .02)
			var centre := piv + Vector3(-cos(ang) * lw * .5, 0, sin(ang) * lw * .5)
			_boite(c, coul, centre, Vector3(lw, h_porte - .02, .06), Basis(Vector3.UP, ang))
			continue
		var bande := PackedVector2Array([Vector2(x0 + .008, -1), Vector2(x0 + .008, h + 1), Vector2(x1 - .008, h + 1), Vector2(x1 - .008, -1)])
		for morceau in Geometry2D.intersect_polygons(feuille, bande):
			_relief(c, coul, _decale(morceau, x, y), z0, z0 + .05)
		if style == "panneaux":
			var pw := (x1 - x0) * .62
			for t in [.3, .72]:
				_saillie(c, coul, x + (x0 + x1) * .5, y + h_porte * t, pw, h_porte * .3, z0 + .05, .02)
		else:
			var nb := maxi(2, int((x1 - x0) / .16))
			for i in nb - 1:
				_saillie(c, sombre, x + x0 + (x1 - x0) * (i + 1) / nb, y + h_porte * .48, .012, h_porte * .9, z0 + .05, .004)
	if cadre != "":
		_bande(c, cadre, _decale(ct, x, y), larg, z0, z0 + float(o.get("saillie", .07)))
		if o.get("cle_voute", false) and forme != "droit":
			_saillie(c, cadre, x, y + h + larg * .45, .3, larg * 1.25, z0, .1)
	if o.get("heurtoir", true) and ouvert == 0.0:
		_saillie(c, k("2a2622", G_BOIS), x + w * .28, y + 1.1, .07, .07, z0 + .05, .04)
	if o.get("seuil", true):
		_saillie(c, str(o.get("cadre_seuil", cadre if cadre != "" else k("cfc3a6", G_TAILLE))), x, y - .07, w + .3, .14, z0, .32)

## Une arcade de boutique : o.mode : boutique (devanture de bois vitrée), muree (murée à moitié, devenue
## fenêtre), ouverte (le noir de l'échoppe et son étal).
static func arcade(c: Chantier, x: float, y: float, w: float, h: float, o := {}) -> void:
	var z0: float = o.get("z", 0.0)
	var forme: String = o.get("forme", "surbaisse")
	var cadre: String = o.get("cadre", k("d8ccad", G_TAILLE))
	var ct := contour(forme, w, h)
	var mode: String = o.get("mode", "boutique")
	var bois: String = o.get("couleur", k("4a5a48", G_BOIS))
	_relief(c, k("1b1917", G_BOIS), _decale(ct, x, y), z0, z0 + .003, false)
	_bande(c, cadre, _decale(ct, x, y), float(o.get("larg", .32)), z0, z0 + .08)
	var h_droit := h - (w * .17 if forme == "surbaisse" else (w * .5 if forme == "plein" else minf(w * .75, h * .5)))
	match mode:
		"muree":
			var hm: float = o.get("hauteur_muree", 1.1 + c.rng.randf() * .4)
			var mur: String = o.get("remplissage", k("a89a80", G_TAILLE))
			_relief(c, mur, _decale(ct, x, y), z0, z0 + .012)
			# la baie devenue fenêtre, avec son petit bois, dans le remplissage
			var fw := minf(w * .5, 1.15)
			fenetre(c, x, y + hm, fw, minf(h_droit - hm - .1, 1.5), {"z": z0 + .012, "cadre": cadre, "larg": .12, "carreaux": [2, 2], "allumee": o.get("allumee", false), "volets": ""})
		"ouverte":
			_saillie(c, bois, x, y + .85, w - .1, .07, z0, .55)
			_saillie(c, bois, x, y + .42, w - .2, .8, z0 - .01, .03)
			for i in 3:
				var cx := x - w * .35 + w * .3 * i + c.rng.randf_range(-.1, .1)
				_boite(c, k(["8a6a3a", "6a7a3a", "9a4a2a"][i], G_BOIS), Vector3(cx, y + 1.0, z0 + .3), Vector3(.45, .22, .32))
		_:
			_saillie(c, bois, x, y + .45, w - .04, .9, z0 - .01, .06)
			var dw := minf(1.0, w * .36)
			var dx: float = x + w * .5 - dw * .5 - .05 if o.get("porte_droite", true) else x - w * .5 + dw * .5 + .05
			_relief(c, LUM if o.get("allumee", false) else k("2a3a40", G_BOIS), PackedVector2Array([Vector2(x - w * .5, y + .9), Vector2(x - w * .5, y + h_droit), Vector2(x + w * .5, y + h_droit), Vector2(x + w * .5, y + .9)]), z0 - .01, z0, false)
			for t in [.33, .66]:
				_saillie(c, bois, x - w * .5 + w * t, y + (h_droit + .9) * .5, .06, h_droit - .9, z0, .05)
			_saillie(c, bois, x, y + h_droit - .02, w, .1, z0, .06)
			porte(c, dx, y, dw, h_droit - .05, {"z": z0 + .01, "couleur": bois, "style": "panneaux", "seuil": false, "heurtoir": false})


# --- le corps -------------------------------------------------------------------------------------

## Le sol sous la façade, à l'abscisse x (la pente court de gauche à droite).
static func _sol(S: Dictionary, x: float) -> float:
	return lerpf(S.sg, S.sd, clampf((x + S.w * .5) / S.w, 0.0, 1.0))

## Les volumes des étages (une boîte par matière), le soubassement, les chaînes et les bandeaux.
static func _corps(c: Chantier) -> void:
	var S := c.S
	var w: float = S.w
	var d: float = S.d
	for i in S.etages.size():
		var e: Dictionary = S.etages[i]
		var y0: float = S.bas if i == 0 else e.y
		var y1: float = e.y + e.h
		var bas_arriere: float = S.bas - float(S.get("flanc", 0.0))
		if i == 0 and S.get("flanc", 0.0) > 0.0:
			# la maison à flanc : l'arrière descend vers le jardin
			_boite(c, e.mur, Vector3(0, (bas_arriere + y1) * .5, -d * .75), Vector3(w, y1 - bas_arriere, d * .5), Basis(), 1 | 2 | 32)
			_boite(c, e.mur, Vector3(0, (y0 + y1) * .5, -d * .25), Vector3(w, y1 - y0, d * .5), Basis(), 1 | 2 | 16)
		elif i > 0 and S.avance > 0.0:
			var av: float = S.avance
			_boite(c, e.mur, Vector3(0, (y0 + y1) * .5, (av - d) * .5), Vector3(w, y1 - y0, d + av), Basis(), 1 | 2 | 16 | 32 | (8 if i == 1 else 0))
		else:
			_boite(c, e.mur, Vector3(0, (y0 + y1) * .5, -d * .5), Vector3(w, y1 - y0, d), Basis(), 1 | 2 | 16 | 32)
	A.collision(c.g, Vector3(0, (S.bas + S.hc) * .5, -d * .5), Vector3(w, S.hc - S.bas, d))
	# le soubassement, de pierre ou d'un enduit plus sombre, horizontal même sur la pente
	var sh: float = S.y0 + float(S.soub_h)
	if S.soub != "":
		_boite(c, S.soub, Vector3(0, (S.bas + sh) * .5, .02), Vector3(w + .06, sh - S.bas, .04), Basis(), 1 | 2 | 4 | 16)
		for s in [-1.0, 1.0]:
			_boite(c, S.soub, Vector3(s * (w * .5 + .02), (S.bas + sh) * .5, -d * .5), Vector3(.04, sh - S.bas, d), Basis(), (1 if s > 0 else 2) | 4)
	if S.chaine != "":
		for s in [-1.0, 1.0]:
			_chaine(c, s * w * .5, s, maxf(sh, S.y0), S.hc - (.1 if S.corniche != "" else 0.0), S.get("chaine_cle", S.pierre), S.chaine == "harpe")
	if S.bandeau:
		for i in range(1, S.etages.size()):
			var e: Dictionary = S.etages[i]
			if e.get("comble", false): continue
			_saillie(c, S.pierre, 0, e.y + .06, w + .04, .18, 0.0, .07)

## Une chaîne d'angle : des blocs de pierre de taille, en harpe (alternés long / court) ou droits.
static func _chaine(c: Chantier, x: float, s: float, y0: float, y1: float, cle: String, harpe: bool) -> void:
	var nb := maxi(1, int((y1 - y0) / .36))
	var hb := (y1 - y0) / nb
	for i in nb:
		var long := harpe and i % 2 == 0
		var wf := .48 if long else (.3 if harpe else .38)
		var ws := .3 if long else (.48 if harpe else .38)
		var y := y0 + hb * (i + .5)
		var ce := Vector3(x - s * wf * .5 + s * .0125, y, -ws * .5 + .0125)
		_boite(c, cle, ce, Vector3(wf + .025, hb - .012, ws + .025), Basis(), 16 | (1 if s > 0 else 2) | 4 | 8)


# --- les toits ------------------------------------------------------------------------------------

## Les rangs de tuiles canal en relief (le pan e0-e1 à l'égout, r0-r1 au faîtage), et quelques
## plaques de mousse ; tuiles plates et ardoises : des rangs horizontaux.
static func _couverture(c: Chantier, e0: Vector3, e1: Vector3, r1: Vector3, r0: Vector3) -> void:
	var S := c.S
	var n := (e1 - e0).cross(r0 - e0).normalized()
	if n.y < 0.0: n = -n
	var vars: Array = S.toit_vars
	var style: String = S.style_toit
	if style == "canal":
		var nb := maxi(2, int(e0.distance_to(e1) / .22))
		var u := (e1 - e0) / nb
		for i in nb:
			var t := (i + .5) / nb
			var a := e0.lerp(e1, t) + n * .005
			var b := r0.lerp(r1, t) + n * .005
			if a.distance_to(b) < .2: continue
			var cle: String = vars[c.rng.randi() % vars.size()] if c.rng.randf() < .55 else S.toit
			var demi := u.normalized() * minf(.1, u.length() * .48)
			var haut := n * .065
			_quad(c, cle, a - demi, b - demi, b + haut, a + haut, (n - u.normalized()).normalized())
			_quad(c, cle, a + haut, b + haut, b + demi, a + demi, (n + u.normalized()).normalized())
		# le bout des tuiles à l'égout, un peu plus sombre
	else:
		var pas := .19 if style == "plate" else .15
		var long := ((e0 + e1) * .5).distance_to((r0 + r1) * .5)
		var nb := maxi(2, int(long / pas))
		for j in range(1, nb):
			var t := float(j) / nb
			var a := e0.lerp(r0, t) + n * .004
			var b := e1.lerp(r1, t) + n * .004
			var cle: String = vars[c.rng.randi() % vars.size()] if c.rng.randf() < .35 else S.toit
			var aval := ((e0 + e1) * .5 - (r0 + r1) * .5).normalized()
			_quad(c, cle, a, b, b + n * .03 + aval * .01, a + n * .03 + aval * .01, (aval + n * .4).normalized())
	# la mousse et les tuiles changées : des plaques plus sombres ou plus vives
	var mousses: int = c.rng.randi_range(2, 7) if S.get("vieux", true) else 1
	for i in mousses:
		var tu := c.rng.randf_range(.05, .9)
		var tv := c.rng.randf_range(0.0, .7)
		var p := e0.lerp(e1, tu).lerp(r0.lerp(r1, tu), tv) + n * .075
		var du := (e1 - e0).normalized() * c.rng.randf_range(.3, .9)
		var dv := (r0 - e0).normalized() * c.rng.randf_range(.25, .7)
		var cle := k(["6f6a44", "7d7650", "5f5a3e", "8a6e52", "b48662"][c.rng.randi() % 5], _genre_de(S.toit))
		_quad(c, cle, p, p + du, p + du + dv, p + dv, n)

static func _pan(c: Chantier, e0: Vector3, e1: Vector3, r1: Vector3, r0: Vector3, couvrir := true) -> void:
	var pts := [e0, e1, r1, r0] if r0.distance_to(r1) > .01 else [e0, e1, r1]
	_plaque(c, c.S.toit, pts, .14)
	if couvrir: _couverture(c, e0, e1, r1, r0)

## Le toit de la maison selon sa forme : gouttereau (faîtage parallèle à la rue), pignon (sur rue),
## croupe, pavillon, brisis (à la Mansart), appentis.
static func _toit(c: Chantier) -> void:
	var S := c.S
	var w: float = S.w
	var d: float = S.d
	var hc: float = S.hc
	var tp := tan(deg_to_rad(S.pente))
	var de: float = S.debord
	var rd: float = S.rive_d
	var zf: float = S.avance
	match S.forme:
		"gouttereau":
			var hf := (d + zf) * .5 * tp
			var zm := (zf - d) * .5
			S.faite = hc + hf
			var ye := hc - de * tp
			var x0 := -w * .5 - rd
			var x1 := w * .5 + rd
			_pan(c, Vector3(x0, ye, zf + de), Vector3(x1, ye, zf + de), Vector3(x1, hc + hf, zm), Vector3(x0, hc + hf, zm))
			_pan(c, Vector3(x1, ye, -d - de), Vector3(x0, ye, -d - de), Vector3(x0, hc + hf, zm), Vector3(x1, hc + hf, zm))
			_boite(c, S.toit, Vector3(0, hc + hf + .06, zm), Vector3(w + rd * 2 + .05, .14, .26))
			for s in [-1.0, 1.0]:
				var a := Vector3(s * w * .5, hc, zf)
				var b := Vector3(s * w * .5, hc, -d)
				var t := Vector3(s * w * .5, hc + hf, zm)
				_tri(c, S.mur_pignon, a, b, t, Vector3(s, 0, 0))
				if S.rive == "maconnee":
					_rampant(c, a, t, s)
					_rampant(c, b, t, s)
		"pignon":
			var hf := w * .5 * tp
			S.faite = hc + hf
			var ye := hc - de * tp
			var z0 := zf + rd
			var z1 := -d - rd
			if S.rive == "maconnee":
				z0 = zf - .02
				z1 = -d + .02
			_pan(c, Vector3(-w * .5 - de, ye, z1), Vector3(-w * .5 - de, ye, z0), Vector3(0, hc + hf, z0), Vector3(0, hc + hf, z1))
			_pan(c, Vector3(w * .5 + de, ye, z0), Vector3(w * .5 + de, ye, z1), Vector3(0, hc + hf, z1), Vector3(0, hc + hf, z0))
			_boite(c, S.toit, Vector3(0, hc + hf + .06, (z0 + z1) * .5), Vector3(.26, .14, z0 - z1 + .04))
			for zz in [zf, -d]:
				var nz := 1.0 if zz == zf else -1.0
				var a := Vector3(-w * .5, hc, zz)
				var b := Vector3(w * .5, hc, zz)
				var t := Vector3(0, hc + hf, zz)
				_tri(c, S.mur_pignon, a, b, t, Vector3(0, 0, nz))
				if S.rive == "maconnee":
					_rampant_z(c, a, t, nz)
					_rampant_z(c, b, t, nz)
				elif zz == zf:
					# la rive de bois qui déborde, vue de la rue
					for s in [-1.0, 1.0]:
						var e := Vector3(s * (w * .5 + de), ye, z0 + .01)
						var f := Vector3(0, hc + hf, z0 + .01)
						var m := (e + f) * .5
						_boite(c, S.bois_rive, m - Vector3(0, .1, 0), Vector3(e.distance_to(f), .2, .04), Basis(Vector3.BACK, atan2(f.y - e.y, f.x - e.x)), 31)
		"croupe", "pavillon":
			var W := w + de * 2
			var D := d + de * 2
			var ye := hc - de * tp
			var zc := -d * .5
			var hf := minf(W, D) * .5 * tp
			S.faite = ye + hf
			var eFL := Vector3(-W * .5, ye, de)
			var eFR := Vector3(W * .5, ye, de)
			var eBR := Vector3(W * .5, ye, -d - de)
			var eBL := Vector3(-W * .5, ye, -d - de)
			if W >= D:
				var l := maxf(.05, (W - D) * .5)
				var rL := Vector3(-l, ye + hf, zc)
				var rR := Vector3(l, ye + hf, zc)
				_pan(c, eFL, eFR, rR, rL)
				_pan(c, eBR, eBL, rL, rR)
				_pan(c, eFR, eBR, rR, rR)
				_pan(c, eBL, eFL, rL, rL)
				_boite(c, S.toit, Vector3(0, ye + hf + .05, zc), Vector3(l * 2 + .2, .12, .22))
			else:
				var l := maxf(.05, (D - W) * .5)
				var rF := Vector3(0, ye + hf, zc + l)
				var rB := Vector3(0, ye + hf, zc - l)
				_pan(c, eFL, eFR, rF, rF)
				_pan(c, eBR, eBL, rB, rB)
				_pan(c, eFR, eBR, rB, rF)
				_pan(c, eBL, eFL, rF, rB)
		"brisis":
			var hb: float = S.get("h_brisis", 2.2)
			var ins := hb * .34
			var ye := hc
			var W := w + .3
			var D := d + .3
			var b0 := [Vector3(-W * .5, ye, .15), Vector3(W * .5, ye, .15), Vector3(W * .5, ye, -d - .15), Vector3(-W * .5, ye, -d - .15)]
			var b1 := [Vector3(-W * .5 + ins, ye + hb, .15 - ins), Vector3(W * .5 - ins, ye + hb, .15 - ins), Vector3(W * .5 - ins, ye + hb, -d - .15 + ins), Vector3(-W * .5 + ins, ye + hb, -d - .15 + ins)]
			for i in 4:
				_pan(c, b0[i], b0[(i + 1) % 4], b1[(i + 1) % 4], b1[i])
			# le terrasson, presque plat, et le petit bourrelet de zinc entre les deux
			var W2 := W - ins * 2
			var D2 := D - ins * 2
			var h2 := minf(W2, D2) * .5 * .32
			var l := maxf(.05, (W2 - D2) * .5)
			var zc := -d * .5
			var yy := ye + hb
			S.faite = yy + h2
			var rL := Vector3(-l, yy + h2, zc)
			var rR := Vector3(l, yy + h2, zc)
			_pan(c, b1[0], b1[1], rR, rL, false)
			_pan(c, b1[2], b1[3], rL, rR, false)
			_pan(c, b1[1], b1[2], rR, rR, false)
			_pan(c, b1[3], b1[0], rL, rL, false)
			_boite(c, k("7d8482", G_BOIS), Vector3(0, yy + .02, .15 - ins), Vector3(W2 + .04, .05, .06))
		"appentis":
			var hf := d * tp
			S.faite = hc + hf
			var ye := hc - de * tp
			_pan(c, Vector3(-w * .5 - rd, ye, de), Vector3(w * .5 + rd, ye, de), Vector3(w * .5 + rd, hc + hf, -d), Vector3(-w * .5 - rd, hc + hf, -d))
			for s in [-1.0, 1.0]:
				_tri(c, S.mur_pignon, Vector3(s * w * .5, hc, 0), Vector3(s * w * .5, hc, -d), Vector3(s * w * .5, hc + hf, -d), Vector3(s, 0, 0))
			_boite(c, S.mur_pignon, Vector3(0, hc + hf * .5, -d), Vector3(w, hf, .02), Basis(), 32)

## Le rampant d'un pignon maçonné qui dépasse du toit (gouttereau : pignons à x = ±w/2).
static func _rampant(c: Chantier, a: Vector3, t: Vector3, s: float) -> void:
	var m := (a + t) * .5 + Vector3(0, .12, 0)
	var l := a.distance_to(t)
	var ang := atan2(t.y - a.y, t.z - a.z)
	_boite(c, c.S.pierre, m + Vector3(-s * .12, 0, 0), Vector3(.38, .18, l + .1), Basis(Vector3.RIGHT, -ang))

static func _rampant_z(c: Chantier, a: Vector3, t: Vector3, nz: float) -> void:
	var m := (a + t) * .5 + Vector3(0, .12, 0)
	var l := a.distance_to(t)
	var ang := atan2(t.y - a.y, t.x - a.x)
	_boite(c, c.S.pierre, m + Vector3(0, 0, -nz * .14), Vector3(l + .1, .18, .4), Basis(Vector3.BACK, ang))
	# la crossette au pied du rampant
	_boite(c, c.S.pierre, a + Vector3(signf(a.x) * -.15, .12, -nz * .14), Vector3(.45, .3, .44))

## L'égout de la façade : génoise (deux ou trois rangs de tuiles), corniche moulurée, simple
## bandeau, ou chevrons apparents sous le débord, et parfois la gouttière et sa descente.
static func _egout(c: Chantier) -> void:
	var S := c.S
	var w: float = S.w
	var hc: float = S.hc
	var zf: float = S.avance
	if S.forme == "pignon":
		if S.corniche == "moulure" or S.corniche == "simple":
			_saillie(c, S.pierre, 0, hc - .08, w + .1, .16, zf, .12)
		return
	match S.corniche:
		"brique":
			var bc: String = S.get("brique_claire", S.pierre)
			_saillie(c, bc, 0, hc - .45, w + .02, .12, zf, .03)
			_saillie(c, bc, 0, hc - .12, w + .06, .24, zf, .1)
			var nb := int(w / .3)
			for i in nb:
				_saillie(c, S.mur, -w * .5 + .15 + i * (w - .3) / maxf(1, nb - 1), hc - .3, .12, .1, zf, .07)
		"genoise2", "genoise3":
			var rangs := 3 if S.corniche == "genoise3" else 2
			var mortier := k("ddd3bd", G_ENDUIT)
			for i in rangs:
				var y := hc - .1 - .13 * (rangs - 1 - i)
				var pr := .09 * (i + 1)
				_saillie(c, mortier, 0, y + .055, w + .02, .03, zf, pr - .02)
				_saillie(c, S.toit_vars[i % S.toit_vars.size()], 0, y, w + .02, .09, zf, pr)
		"moulure":
			_saillie(c, S.pierre, 0, hc - .3, w + .05, .1, zf, .06)
			_saillie(c, S.pierre, 0, hc - .2, w + .1, .1, zf, .13)
			_saillie(c, S.pierre, 0, hc - .08, w + .18, .16, zf, .25)
		"simple":
			_saillie(c, S.pierre, 0, hc - .1, w + .06, .2, zf, .1)
		"chevrons":
			var nb := maxi(3, int(w / .62))
			for i in nb + 1:
				var x := -w * .5 + w * i / nb
				_boite(c, S.bois_rive, Vector3(x, hc - .05, zf + S.debord * .5), Vector3(.09, .12, S.debord), Basis(), 1 | 2 | 8 | 16)
			_saillie(c, S.bois_rive, 0, hc - .02, w, .1, zf, .04)
	if S.get("gouttiere", false):
		var tp := tan(deg_to_rad(S.pente))
		var ye: float = hc - S.debord * tp
		var zinc := k("80878a", G_BOIS)
		_boite(c, zinc, Vector3(0, ye - .06, S.debord - .02), Vector3(w + S.rive_d * 2, .11, .13))
		var xd: float = (w * .5 - .25) * (1.0 if c.rng.randf() < .5 else -1.0)
		var bas := _sol(S, xd)
		_boite(c, zinc, Vector3(xd, (bas + ye) * .5, .07), Vector3(.08, ye - bas, .08), Basis(), 1 | 2 | 16)
		_boite(c, zinc, Vector3(xd, ye - .12, (S.debord + .07) * .5), Vector3(.08, .08, S.debord), Basis(), 1 | 2 | 8 | 16)


# --- souches et lucarnes -------------------------------------------------------------------------

## Une souche de cheminée : un corps de pierre ou de brique, un chapeau, des mitrons de terre cuite.
static func souche(c: Chantier, x: float, z: float, y0: float, y1: float, sw: float, sd: float, cle: String) -> void:
	_boite(c, cle, Vector3(x, (y0 + y1) * .5, z), Vector3(sw, y1 - y0, sd), Basis(), 63 - 8)
	_boite(c, c.S.pierre, Vector3(x, y1 + .05, z), Vector3(sw + .12, .1, sd + .12), Basis(), 63 - 8)
	var nb := c.rng.randi_range(0, 2)
	for i in nb:
		var px := x + (i - (nb - 1) * .5) * sw * .45
		_boite(c, k("a66a4c", c.S.get("genre_mitron", G_TUILE)), Vector3(px, y1 + .28, z), Vector3(.16, .36, .16), Basis(), 63 - 8)

## Le toit à la hauteur z sur le pan avant (maisons gouttereau, croupe, brisis).
static func _y_toit(S: Dictionary, z: float) -> float:
	var tp := tan(deg_to_rad(S.pente))
	if S.forme == "brisis":
		return S.hc + minf(-z, .7) / .34
	return S.hc + maxf(0.0, -z) * tp

## Une lucarne sur le pan avant : fronton (pierre, à fronton triangulaire), passante (dans le plan de la
## façade, coupe la corniche), capucine (toit à croupe), pignon (à deux pans), gerbiere (à poulie).
static func lucarne(c: Chantier, x: float, style: String, lw: float, lh: float, o := {}) -> void:
	var S := c.S
	var dans_facade := style in ["fronton", "passante", "gerbiere"]
	var zf: float = 0.0 if dans_facade else -float(o.get("retrait", .6))
	if S.forme == "brisis": zf = -.25 if not dans_facade else 0.0
	var ys: float = (S.hc - .35) if dans_facade else _y_toit(S, zf) + .12
	var mur: String = S.pierre if style in ["fronton", "passante"] else str(o.get("mur", S.mur_haut))
	var jw := lw + (.5 if dans_facade else .34)
	var top := ys + lh + .25
	var tp := tan(deg_to_rad(maxf(S.pente, 20.0)))
	var zb := -maxf(1.0, (top + .4 - S.hc) / tp)
	if S.forme == "brisis": zb = -1.4
	_boite(c, mur, Vector3(x, (ys - .3 + top) * .5, (zf + zb) * .5), Vector3(jw, top - ys + .3, zf - zb), Basis(), 1 | 2 | 16)
	if style == "gerbiere":
		porte(c, x, ys, lw, lh, {"z": zf, "couleur": S.bois_vieux, "seuil": false, "heurtoir": false, "ouvert": .4 if c.rng.randf() < .5 else 0.0})
	else:
		fenetre(c, x, ys, lw, lh, {"z": zf, "forme": "plein" if style == "oeil" else "droit", "cadre": S.pierre if style != "pignon" else "", "larg": .12,
			"carreaux": [2, 2], "volets": "" if style != "capucine" else S.volets, "couleur": S.menuis, "allumee": c.rng.randf() < S.lumiere * .7,
			"appui": style != "passante", "dormant": S.dormant})
	var rk: String = S.toit
	var hw := jw * .5 + .12
	match style:
		"capucine":
			var a := Vector3(x - hw, top, zf + .2)
			var b := Vector3(x + hw, top, zf + .2)
			var s := Vector3(x, top + hw * .9, zf - hw * .5)
			_plaque(c, rk, [a, b, s], .08)
			for sx in [-1.0, 1.0]:
				_plaque(c, rk, [Vector3(x + sx * hw, top, zf + .2), Vector3(x + sx * hw, top, zb), Vector3(x, top + hw * .9, zb), s], .08)
		"fronton", "oeil":
			var hp := hw * .55
			var tri := PackedVector2Array([Vector2(x - hw, top - .05), Vector2(x, top + hp), Vector2(x + hw, top - .05)])
			_relief(c, S.pierre, tri, zf - .05, zf + .12)
			_saillie(c, S.pierre, x, top - .08, jw + .2, .1, zf, .14)
			for sx in [-1.0, 1.0]:
				_plaque(c, rk, [Vector3(x + sx * (hw - .02), top - .05, zf), Vector3(x + sx * (hw - .02), top - .05, zb), Vector3(x, top + hp, zb), Vector3(x, top + hp, zf)], .07)
		_:
			var hp := hw * (.9 if style == "gerbiere" else .75)
			var zfr := zf + (.35 if style == "gerbiere" else .15)
			for sx in [-1.0, 1.0]:
				_plaque(c, rk, [Vector3(x + sx * hw, top, zfr), Vector3(x + sx * hw, top, zb), Vector3(x, top + hp, zb), Vector3(x, top + hp, zfr)], .08)
			_tri(c, mur, Vector3(x - hw + .1, top, zf), Vector3(x + hw - .1, top, zf), Vector3(x, top + hp - .05, zf), Vector3.BACK)
			if style == "gerbiere":
				# la poutre et sa poulie, la corde qui pend
				_boite(c, S.bois_vieux, Vector3(x, top + hp * .45, zf + .45), Vector3(.14, .16, 1.1))
				_boite(c, k("2a2826", G_BOIS), Vector3(x, top + hp * .45 - .18, zf + .9), Vector3(.06, .22, .22))
				_boite(c, k("8a7a5a", G_BOIS), Vector3(x, top - lh * .5, zf + .95), Vector3(.025, lh + .6, .025))


# --- le plan : un type, une graine, des bornes ----------------------------------------------------

static func _p(c: Chantier, arr: Array) -> Variant:
	return arr[c.rng.randi() % arr.size()]

static func _r(c: Chantier, a: float, b: float) -> float:
	return c.rng.randf_range(a, b)

static func _ch(c: Chantier, p: float) -> bool:
	return c.rng.randf() < p

const QUARTIER_DU_TYPE := {"medievale": "cite", "echoppe": "cite", "balet": "montee", "vigneron": "montee", "notable": "basse",
	"tailleur": "quai", "grange": "cite", "quai": "quai", "ouvriere": "basse", "forte": "cite"}

static func _plan(c: Chantier, type: String, o: Dictionary) -> Dictionary:
	var S := {}
	c.S = S
	S.type = type
	S.q = str(o.get("quartier", QUARTIER_DU_TYPE.get(type, "cite")))
	if not MENUISERIES.has(S.q): S.q = "cite"
	var pal: Array = MENUISERIES[S.q]
	var i1 := c.rng.randi() % pal.size()
	S.menuis = k(pal[i1], G_BOIS)
	S.porte_c = k(Color(pal[(i1 + c.rng.randi_range(1, 3)) % pal.size()]).lightened(.12).to_html(false) if _ch(c, .55) else _p(c, ["94785a", "a08462", "86705a", "aa8e6a", "8e7c68"]), G_BOIS)
	S.dormant = k(_p(c, ["ebe6da", "e2dccb", "d8cfba"]) if _ch(c, .7) else pal[i1], G_BOIS)
	S.bois_vieux = k(_p(c, ["9c8c76", "8e826e", "a69680", "84786a"]), G_BOIS)
	S.bois_rive = k(_p(c, ["5a4a3a", "4a3e32", "6a5a48"]), G_BOIS)
	S.lumiere = float(o.get("lumiere", .3))
	var pente: float = o.get("pente", 0.0)
	S.sg = -pente * .5
	S.sd = pente * .5
	S.vieux = true
	S.compo = []
	S.lucarnes = []
	S.souches = []
	S.chaine = ""
	S.bandeau = false
	S.corniche = ""
	S.debord = .35
	S.rive = "debord"
	S.rive_d = .3
	S.soub = ""
	S.soub_h = .5
	S.gouttiere = false
	S.volets = "barres"
	S.pierre_vue = false
	S.avance = 0.0
	S.flanc = 0.0
	S.rehausse = .08
	S.cote = 1.0 if _ch(c, .5) else -1.0
	if o.has("_cote"): S.cote = float(o._cote)
	S.pierre = k(_p(c, TAILLES), G_TAILLE)
	S.toit_vars = []
	S.traces = []
	S.histoire = o.get("histoire", null)
	match type:
		"medievale": _t_medievale(c, o)
		"echoppe": _t_echoppe(c, o)
		"balet": _t_balet(c, o)
		"vigneron": _t_vigneron(c, o)
		"notable": _t_notable(c, o)
		"tailleur": _t_tailleur(c, o)
		"grange": _t_grange(c, o)
		"quai": _t_quai(c, o)
		"ouvriere": _t_ouvriere(c, o)
		_: _t_forte(c, o)
	return S

## Les traces d'histoire tirées pour ce type (ou imposées par options.histoire : une liste, ou false).
static func _traces(c: Chantier, probas: Dictionary) -> void:
	var S := c.S
	for nom in probas:
		var tire := c.rng.randf() < float(probas[nom])
		if S.histoire is Array: tire = (S.histoire as Array).has(nom)
		elif S.histoire is bool and not S.histoire: tire = false
		if tire: S.traces.append(nom)

static func _a(c: Chantier, nom: String) -> bool:
	return (c.S.traces as Array).has(nom)

## Le toit : canal (pente douce), plate (moyenne à raide), ardoise (raide), meca (tuile mécanique).
static func _couvrir(c: Chantier, style: String, pente: float) -> void:
	var S := c.S
	S.style_toit = style
	S.pente = pente
	var liste: Array = TUILES_CANAL if style == "canal" else (TUILES_PLATES if style == "plate" else (ARDOISES if style == "ardoise" else ["a85a3c", "b0603e", "9c5238"]))
	var genre := G_ARDOISE if style == "ardoise" else G_TUILE
	S.toit = k(_p(c, liste), genre)
	S.toit_vars = []
	for i in 3: S.toit_vars.append(k(_p(c, liste), genre))
	S.genre_terre = G_TUILE if genre == G_TUILE else G_BOIS
	S.genre_mitron = G_TUILE if genre == G_TUILE else G_BOIS

## Les étages : hauteurs (du rez au dernier), le mur, le mur du dernier niveau (surélévation), le surcroît.
static func _niveaux(c: Chantier, hs: Array, mur: String, surcroit := 0.0) -> void:
	var S := c.S
	S.y0 = maxf(S.sg, S.sd) + float(S.rehausse)
	S.bas = minf(S.sg, S.sd) - 2.0
	var y: float = S.y0
	S.etages = []
	for i in hs.size():
		var h: float = hs[i]
		if i == hs.size() - 1: h += surcroit
		S.etages.append({"y": y, "h": h, "mur": mur})
		y += h
	S.hc = y
	S.surcroit = surcroit
	S.mur = mur
	S.mur_haut = mur
	S.mur_pignon = mur

## La surélévation : le dernier niveau d'une autre matière, plus récent (brique, autre enduit, moellon chaulé).
static func _surelever(c: Chantier) -> void:
	var S := c.S
	if not _a(c, "surelevation") or S.etages.size() < 2: return
	var g := _genre_de(S.mur)
	var neuf := ""
	if g == G_ENDUIT: neuf = k(_p(c, ["e9e3d3", "d9c9a6", "cfc6b8", "e0c9b2"]), G_ENDUIT)
	elif g == G_TAILLE: neuf = k(_p(c, BRIQUES), G_TAILLE)
	else: neuf = k(_p(c, BRIQUES), G_TAILLE) if _ch(c, .5) else k(_p(c, ["d8d0bc", "cfc5ae"]), G_MOELLON)
	var e: Dictionary = S.etages[S.etages.size() - 1]
	e.mur = neuf
	S.mur_haut = neuf
	S.mur_pignon = neuf
	S.surel_y = e.y

static func _fen(c: Chantier, et: int, x: float, w: float, h: float, dy: float, o := {}) -> void:
	var e: Dictionary = c.S.etages[mini(et, c.S.etages.size() - 1)]
	c.S.compo.append({"k": "fenetre", "x": x, "y": e.y + dy, "w": w, "h": h, "o": o, "et": et})

static func _porte(c: Chantier, et: int, x: float, w: float, h: float, o := {}, principale := false) -> void:
	var e: Dictionary = c.S.etages[mini(et, c.S.etages.size() - 1)]
	c.S.compo.append({"k": "porte", "x": x, "y": e.y + float(o.get("dy", 0.0)), "w": w, "h": h, "o": o, "et": et, "principale": principale})
	if principale:
		c.S.porte_x = x
		c.S.porte_y = e.y + float(o.get("dy", 0.0))

## L'abscisse de la porte principale : celle du type, ou celle que demande options.porte.
static func _x_porte(c: Chantier, o: Dictionary, defaut: float, w_porte: float) -> float:
	var v = o.get("porte", null)
	var lim: float = c.S.w * .5 - w_porte * .5 - .35
	if v == null: return clampf(defaut, -lim, lim)
	if v is String:
		match v:
			"gauche": return -lim + .2
			"droite": return lim - .2
			_: return 0.0
	return clampf(float(v), -lim, lim)

## Des abscisses de baies dans [x0, x1] : n baies, régulières (jeu 0) ou irrégulières (jeu > 0).
static func _baies(c: Chantier, x0: float, x1: float, n: int, jeu := 0.0) -> Array:
	var out := []
	if n <= 0: return out
	var pas := (x1 - x0) / n
	for i in n:
		out.append(x0 + pas * (i + .5) + _r(c, -jeu, jeu) * pas)
	return out


# --- les dix types --------------------------------------------------------------------------------

## Maison médiévale à tourelle (cité) : pignon sur rue, tour d'escalier en vis hors-œuvre, croisées.
static func _t_medievale(c: Chantier, o: Dictionary) -> void:
	var S := c.S
	S.w = float(o.get("w", _r(c, 6.2, 8.4)))
	S.d = float(o.get("d", _r(c, 8.0, 10.0)))
	var n: int = o.get("niveaux", 2 if _ch(c, .5) else 3)
	n = clampi(n, 2, 3)
	_traces(c, {"boulin": .45, "muree": .4, "niche": .35, "date": .3, "surelevation": .25 if n == 3 else 0.0, "ecaille": .5, "ancres": .35, "humidite": .3, "publicite": .08})
	S.forme = "pignon" if _ch(c, .72) else "gouttereau"
	if _ch(c, .3): _couvrir(c, "ardoise", _r(c, 54, 60) if S.forme == "pignon" else _r(c, 46, 50))
	else: _couvrir(c, "plate", _r(c, 50, 56) if S.forme == "pignon" else _r(c, 44, 48))
	S.pierre_vue = _ch(c, .55)
	var mur := k(_p(c, ["d6c6a6", "cdb995", "d2bfa0", "c9c4b6", "d6bca6"]), G_ENDUIT) if S.pierre_vue else k(_p(c, MOELLONS), G_MOELLON)
	var hs := [_r(c, 3.0, 3.3)]
	for i in n - 1: hs.append(_r(c, 2.7, 2.9))
	_niveaux(c, hs, mur, _r(c, 0.0, .4))
	_surelever(c)
	S.soub = k(_p(c, MOELLONS), G_TAILLE) if S.pierre_vue else ""
	S.soub_h = .4
	S.rive = "maconnee" if _ch(c, .55) else "debord"
	S.rive_d = .25
	S.debord = .3
	S.corniche = "simple" if S.forme == "gouttereau" else ""
	S.chaine = "harpe" if S.pierre_vue and _ch(c, .45) else ""
	S.bandeau = _ch(c, .5)
	S.volets = "barres"
	var cote: float = S.cote
	# la tour d'escalier, hors-œuvre, d'un côté de la façade
	var ronde := _ch(c, .55)
	var rt := _r(c, 1.05, 1.35)
	S.tourelle = {"x": cote * (S.w * .5 - rt - _r(c, .15, .55)), "z": rt * .45, "r": rt, "ronde": ronde,
		"pans": 12 if ronde else _p(c, [6, 8]), "haut": S.hc + _r(c, 1.8, 3.2), "chambre": _ch(c, .4)}
	var tx: float = S.tourelle.x
	# le reste de la façade, de l'autre côté de la tour
	var lib0: float = -S.w * .5 + .5 if cote > 0 else tx + rt + .4
	var lib1: float = tx - rt - .4 if cote > 0 else S.w * .5 - .5
	var pw := _r(c, 1.05, 1.25)
	var px := _x_porte(c, o, lerpf(lib0, lib1, .3 if cote > 0 else .7), pw)
	_porte(c, 0, px, pw, _r(c, 2.45, 2.7), {"forme": "brise", "cadre": S.pierre, "larg": .24, "couleur": S.porte_c, "style": "planches"}, true)
	if lib1 - lib0 > 3.2:
		var fx := lerpf(lib0, lib1, .85 if cote > 0 else .15)
		_fen(c, 0, fx, .7, .85, 1.35, {"volets": "barres", "carreaux": [1, 2]})
	var span := lib1 - lib0
	var acc := _ch(c, .5)
	var nc := 2 if span > 4.4 else 1
	for x in _baies(c, lib0, lib1, nc, .12):
		_fen(c, 1, x, _r(c, 1.1, 1.3), _r(c, 1.9, 2.15), .8, {"meneaux": "croisee", "accolade": acc, "volets": ""})
	if n == 3:
		var nd := 1 if span < 3.6 or _ch(c, .4) else 2
		for x in _baies(c, lib0 + .3, lib1 - .3, nd, .2):
			_fen(c, 2, x + _r(c, -.4, .4), _r(c, .9, 1.05), _r(c, 1.25, 1.45), .75, {"meneaux": "demi", "volets": "barres" if _ch(c, .5) else ""})
	if S.forme == "pignon":
		var hf: float = S.w * .5 * tan(deg_to_rad(S.pente))
		S.compo.append({"k": "fenetre", "x": _r(c, -.3, .3), "y": S.hc + hf * .3, "w": .55, "h": .75, "o": {"volets": "barres", "carreaux": [1, 2]}, "et": 9})
	else:
		S.lucarnes.append([lerpf(lib0, lib1, .5), "pignon", .7, .9])
	S.souches.append([cote * -1.0 * (S.w * .5 - .5), -S.d * .55, .8, .6, false])
	S.date = str(_p(c, ["1487", "1512", "1534", "1561", "1578"]))

## Échoppe (cité, rue des Puys) : une ou deux larges arcades de boutique, étage en encorbellement.
static func _t_echoppe(c: Chantier, o: Dictionary) -> void:
	var S := c.S
	S.w = float(o.get("w", _r(c, 4.8, 7.0)))
	S.d = float(o.get("d", _r(c, 7.0, 9.0)))
	var n: int = clampi(int(o.get("niveaux", 2 if _ch(c, .6) else 3)), 2, 3)
	_traces(c, {"enseigne": .65, "date": .15, "ecaille": .45, "surelevation": .2 if n == 3 else 0.0, "humidite": .25, "publicite": .12, "niche": .15})
	S.forme = "pignon" if _ch(c, .6) else "gouttereau"
	if S.forme == "pignon": _couvrir(c, "plate", _r(c, 46, 54))
	else: _couvrir(c, "canal", _r(c, 18, 22))
	var encorb := _ch(c, .65)
	S.pan_bois = encorb and _ch(c, .78)
	var mur_rez := k(_p(c, MOELLONS), G_MOELLON) if _ch(c, .45) else k(_p(c, ENDUITS), G_ENDUIT)
	var hs := [_r(c, 3.3, 3.6)]
	for i in n - 1: hs.append(_r(c, 2.6, 2.8))
	_niveaux(c, hs, mur_rez, _r(c, 0.0, .3))
	var mur_haut := k(_p(c, ["e3d8bf", "ddd0b2", "e6dcc8", "d9c7a8"]), G_ENDUIT) if S.pan_bois else (mur_rez if _ch(c, .5) else k(_p(c, ENDUITS), G_ENDUIT))
	for i in range(1, S.etages.size()):
		S.etages[i].mur = mur_haut
	S.mur_haut = mur_haut
	S.mur_pignon = mur_haut
	_surelever(c)
	S.avance = _r(c, .35, .55) if encorb else 0.0
	S.bois_pan = k(_p(c, ["4a3a2c", "5a4634", "3e3530", "604a38"]), G_BOIS)
	S.debord = .3
	S.rive_d = .35
	S.corniche = "chevrons" if S.forme == "gouttereau" else ""
	S.soub = ""
	S.volets = "barres"
	var cite: bool = S.q == "cite"
	var formes := ["brise", "surbaisse", "plein"] if cite else ["surbaisse", "surbaisse", "plein"]
	var deux: bool = S.w > 6.1 and _ch(c, .6)
	var ha := minf(hs[0] - .35, _r(c, 2.6, 3.0))
	var fa: String = _p(c, formes)
	var cadre := k(_p(c, TAILLES), G_TAILLE)
	var modes := ["boutique", "ouverte"]
	if deux:
		var wa: float = (S.w - 1.7) * .5
		var xs := [-S.w * .5 + .6 + wa * .5, S.w * .5 - .6 - wa * .5]
		var m0: String = _p(c, modes)
		S.compo.append({"k": "arcade", "x": xs[0], "y": S.y0, "w": wa, "h": ha, "o": {"forme": fa, "cadre": cadre, "mode": m0, "couleur": S.menuis}, "et": 0})
		var m1: String = "muree" if _ch(c, .45) else ("ouverte" if m0 == "boutique" else "boutique")
		S.compo.append({"k": "arcade", "x": xs[1], "y": S.y0, "w": wa, "h": ha, "o": {"forme": fa, "cadre": cadre, "mode": m1, "couleur": S.menuis, "remplissage": k(_p(c, MOELLONS), G_TAILLE)}, "et": 0})
		S.porte_x = xs[0]
		S.porte_y = S.y0
	else:
		var wa := minf(3.2, S.w - 2.0)
		var cote: float = S.cote
		var ax: float = cote * (S.w * .5 - .45 - wa * .5)
		var m: String = "muree" if _ch(c, .3) else _p(c, modes)
		S.compo.append({"k": "arcade", "x": ax, "y": S.y0, "w": wa, "h": ha, "o": {"forme": fa, "cadre": cadre, "mode": m, "couleur": S.menuis, "remplissage": k(_p(c, MOELLONS), G_TAILLE)}, "et": 0})
		var px := _x_porte(c, o, -cote * (S.w * .5 - .85), .85)
		_porte(c, 0, px, .85, 2.2, {"forme": "droit" if not cite else "surbaisse", "cadre": cadre, "larg": .16, "couleur": S.porte_c}, true)
	var nf := 2 if S.w < 5.8 else 3
	for et in range(1, n):
		var xs := _baies(c, -S.w * .5 + .4, S.w * .5 - .4, nf, .08 if S.pan_bois else .15)
		for x in xs:
			_fen(c, et, x, _r(c, .72, .88), _r(c, 1.05, 1.3) - (et - 1) * .12, .85, {"carreaux": [2, 3], "volets": "" if _ch(c, .55) else "barres", "cadre": "" if S.pan_bois else cadre, "z": S.avance})
	if S.forme == "pignon":
		var hf: float = S.w * .5 * tan(deg_to_rad(S.pente))
		S.compo.append({"k": "fenetre", "x": 0.0, "y": S.hc + hf * .22, "w": .6, "h": .8, "o": {"volets": "", "carreaux": [1, 2], "z": S.avance}, "et": 9})
	S.souches.append([S.cote * (S.w * .5 - .45), -S.d * .6, .6, .5, false])

## Maison à balet (montée, ville basse) : l'escalier extérieur de pierre, le palier couvert d'un auvent
## sur poteaux, la cave sous l'escalier.
static func _t_balet(c: Chantier, o: Dictionary) -> void:
	var S := c.S
	S.w = float(o.get("w", _r(c, 6.8, 9.0)))
	S.d = float(o.get("d", _r(c, 7.0, 9.0)))
	_traces(c, {"muree": .3, "porte_fenetre": .2, "date": .35, "ecaille": .55, "surelevation": .2, "humidite": .4, "ancres": .25, "niche": .12, "publicite": .1})
	S.forme = "gouttereau"
	_couvrir(c, "canal", _r(c, 16, 20))
	var enduit := _ch(c, .7)
	var mur := k(_p(c, ENDUITS), G_ENDUIT) if enduit else k(_p(c, MOELLONS), G_MOELLON)
	var rez := _r(c, 2.45, 2.7)
	var surc := _r(c, 0.0, .65)
	_niveaux(c, [rez, _r(c, 2.8, 3.0)], mur, surc)
	_surelever(c)
	S.soub = k(_p(c, MOELLONS), G_TAILLE) if enduit else ""
	S.soub_h = .5
	S.corniche = "genoise2" if _ch(c, .7) else "chevrons"
	S.debord = .3 if S.corniche == "genoise2" else .45
	S.chaine = "droite" if enduit and _ch(c, .4) else ""
	S.volets = "barres" if _ch(c, .6) else "plein"
	var cote: float = S.cote
	var y_pal: float = S.etages[1].y
	var x_dep: float = cote * (S.w * .5 - .15)
	var sol_dep := _sol(S, x_dep)
	var course := (y_pal - sol_dep) / .17 * .27
	var pal_w := _r(c, 1.3, 1.6)
	var x_haut := x_dep - cote * course
	var xpo := x_haut - cote * pal_w * .5
	S.balet = {"x_dep": x_dep, "x_haut": x_haut, "pal_w": pal_w, "pal_d": _r(c, 1.25, 1.45), "y": y_pal, "larg": 1.0}
	_porte(c, 1, xpo, .9, 2.1, {"forme": "droit", "imposte": _ch(c, .4), "cadre": S.pierre, "larg": .16, "couleur": S.porte_c, "style": "panneaux" if _ch(c, .5) else "planches", "seuil": false}, true)
	# la cave, sous le palier
	_porte(c, 0, xpo, _r(c, 1.0, 1.2), minf(y_pal - S.y0 - .45, 1.85), {"forme": _p(c, ["plein", "surbaisse"]), "cadre": S.pierre, "larg": .2, "couleur": S.bois_vieux, "vantaux": 2, "heurtoir": false, "seuil": false})
	var reste0: float = -S.w * .5 + .5 if cote > 0 else xpo + pal_w * .5 + .5
	var reste1: float = xpo - pal_w * .5 - .5 if cote > 0 else S.w * .5 - .5
	var nf := 2 if absf(reste1 - reste0) > 2.8 else 1
	var wf := _r(c, .9, 1.05)
	var hf := _r(c, 1.35, 1.55)
	for x in _baies(c, reste0, reste1, nf, .06):
		_fen(c, 1, x, wf, hf, .9, {"cadre": S.pierre, "larg": .14})
		if _ch(c, .6): _fen(c, 0, x + _r(c, -.2, .2), .55, .5, 1.2, {"cadre": S.pierre, "larg": .12, "carreaux": [1, 1], "volets": "", "appui": false, "verre": k("1c1a18", G_BOIS)})
	if course > 2.4 and _ch(c, .55):
		_fen(c, 1, lerpf(x_dep, x_haut, .5), wf * .85, hf * .85, 1.0, {"cadre": S.pierre, "larg": .14})
	if surc > .45:
		for x in _baies(c, -S.w * .5 + .6, S.w * .5 - .6, 2, .1):
			S.compo.append({"k": "fenetre", "x": x, "y": S.hc - surc + .02 + (surc - .45) * .3, "w": .5, "h": .4, "o": {"carreaux": [1, 1], "volets": "", "appui": false, "cadre": S.pierre, "larg": .1}, "et": 9})
	S.souches.append([-cote * (S.w * .5 - .6), -S.d * .5, .7, .55, false])
	S.date = str(_p(c, ["1698", "1712", "1742", "1765", "1777"]))

## Maison de vigneron à flanc (montée) : deux niveaux côté rue, trois côté jardin ; la porte de cave en
## plein cintre ; le grenier sous un surcroît ; la treille.
static func _t_vigneron(c: Chantier, o: Dictionary) -> void:
	var S := c.S
	S.w = float(o.get("w", _r(c, 6.8, 9.0)))
	S.d = float(o.get("d", _r(c, 8.0, 10.0)))
	_traces(c, {"muree": .3, "porte_fenetre": .25, "date": .35, "ecaille": .6, "humidite": .45, "boulin": .25, "surelevation": .15, "ancres": .3, "publicite": .08})
	S.forme = "gouttereau" if _ch(c, .8) else "croupe"
	_couvrir(c, "canal", _r(c, 16, 20))
	S.pierre_vue = _ch(c, .6)
	var mur := k(_p(c, ["d8c8a8", "cdb995", "d6c3a0", "d2c4aa"]), G_ENDUIT) if S.pierre_vue else k(_p(c, MOELLONS), G_MOELLON)
	var surc := _r(c, .8, 1.2)
	_niveaux(c, [_r(c, 2.75, 3.0), _r(c, 2.7, 2.9)], mur, surc)
	_surelever(c)
	S.flanc = float(o.get("flanc", 2.6))
	S.soub = k(_p(c, MOELLONS), G_TAILLE) if S.pierre_vue else ""
	S.soub_h = _r(c, .6, 1.0)
	S.corniche = "genoise3" if _ch(c, .3) else "genoise2"
	S.debord = .28
	S.volets = "barres" if _ch(c, .55) else "plein"
	var cote: float = S.cote
	var wc := _r(c, 1.8, 2.2)
	var xc: float = cote * (S.w * .5 - .6 - wc * .5)
	S.cave = {"x": xc, "w": wc}
	_porte(c, 0, xc, wc, _r(c, 2.3, 2.6), {"forme": "plein", "cadre": S.pierre, "larg": .26, "couleur": S.bois_vieux, "vantaux": 2, "heurtoir": false, "ouvert": .5 if _ch(c, .3) else 0.0, "cle_voute": _ch(c, .5)})
	var px := _x_porte(c, o, -cote * _r(c, .2, .9), .95)
	var forme_p: String = "surbaisse" if _ch(c, .4) else "droit"
	_porte(c, 0, px, .95, 2.15, {"forme": forme_p, "imposte": forme_p == "droit" and _ch(c, .5), "cadre": S.pierre, "larg": .17, "couleur": S.porte_c}, true)
	if S.w > 7.4: _fen(c, 0, -cote * (S.w * .5 - .7), .6, .7, 1.3, {"cadre": S.pierre, "larg": .12, "carreaux": [1, 2], "volets": "barres"})
	var nf := 3 if S.w > 8.2 and _ch(c, .5) else 2
	for x in _baies(c, -S.w * .5 + .5, S.w * .5 - .5, nf, .18):
		_fen(c, 1, x, _r(c, .9, 1.0), _r(c, 1.3, 1.5), .9, {"cadre": S.pierre, "larg": .15})
	if _ch(c, .45):
		S.lucarnes.append([xc, "gerbiere", .9, 1.1])
	else:
		for x in _baies(c, -S.w * .5 + .8, S.w * .5 - .8, 2, .15):
			S.compo.append({"k": "fenetre", "x": x, "y": S.hc - surc + .1, "w": .55, "h": .42, "o": {"carreaux": [1, 1], "volets": "", "appui": false, "cadre": S.pierre, "larg": .1}, "et": 9})
	S.souches.append([-cote * (S.w * .5 - .55), -S.d * .5, .75, .55, false])
	S.date = str(_p(c, ["1789", "1803", "1811", "1826", "1834"]))
	if _ch(c, .4) and not o.has("w"):
		# le chai en appentis, accolé du côté de la cave
		S.w_at = _r(c, 2.6, 3.4)
		S.w_tot = S.w + S.w_at
		S.atelier = {"cote": cote, "h": _r(c, 3.0, 3.4), "baie_w": _r(c, 1.6, 1.9), "baie_h": _r(c, 2.1, 2.4), "baie_forme": "plein", "mur": k(_p(c, MOELLONS), G_MOELLON) if _ch(c, .6) else mur, "blocs": false}

## Maison de notable (XVIIIe-XIXe, place du Marché, quai) : symétrie, pierre de taille, ardoise à
## croupes ou à brisis, lucarnes, corniche moulurée, porte à imposte sur perron ou porte cochère.
static func _t_notable(c: Chantier, o: Dictionary) -> void:
	var S := c.S
	S.w = float(o.get("w", _r(c, 10.4, 13.4)))
	S.d = float(o.get("d", _r(c, 9.0, 11.0)))
	var n: int = clampi(int(o.get("niveaux", 2 if _ch(c, .55) else 3)), 2, 3)
	_traces(c, {"date": .45, "marquise": .3, "cadran": .1, "publicite": 0.0, "ecaille": .2, "humidite": .2})
	var f := c.rng.randf()
	S.forme = "croupe" if f < .45 else ("brisis" if f < .8 else "gouttereau")
	if _ch(c, .85): _couvrir(c, "ardoise", _r(c, 38, 45) if S.forme != "gouttereau" else _r(c, 40, 46))
	else: _couvrir(c, "plate", _r(c, 40, 46))
	S.h_brisis = _r(c, 2.1, 2.5)
	var taille := _ch(c, .7)
	var mur := k(_p(c, TAILLES), G_TAILLE) if taille else k(_p(c, ["e6e0cf", "e2d9c3", "ddd3bf", "e4d6be"]), G_ENDUIT)
	var cochere := _ch(c, .4)
	S.rehausse = .12 if cochere else _r(c, .45, .6)
	var hs := [_r(c, 3.5, 3.8), _r(c, 3.2, 3.5)]
	if n == 3: hs.append(_r(c, 2.7, 2.9))
	_niveaux(c, hs, mur)
	S.pierre = k(_p(c, ["e2d8be", "dcd1b5", "d9cfb6"]), G_TAILLE)
	S.soub = k(_p(c, ["c9bea2", "cfc4a8"]), G_TAILLE)
	S.soub_h = .7
	S.corniche = "moulure"
	S.bandeau = true
	S.chaine = "" if taille else "harpe"
	S.debord = .2 if S.forme != "brisis" else .15
	S.volets = _p(c, ["persienne", "persienne", "persienne", "plein", ""])
	S.vieux = false
	S.refends = taille and _ch(c, .5)
	S.pilastres = taille and _ch(c, .45)
	var nt := 5 if S.w > 11.6 else 3
	var marge := _r(c, 1.25, 1.6)
	var xs := []
	for i in nt: xs.append(lerpf(-S.w * .5 + marge, S.w * .5 - marge, float(i) / (nt - 1)))
	var mil := nt / 2
	var cintre := _ch(c, .4)
	var o_rez := {"forme": "surbaisse" if cintre else "droit", "cadre": S.pierre, "larg": .18, "cle_voute": true, "carreaux": [2, 4]}
	var o_1 := {"cadre": S.pierre, "larg": .2, "cle_voute": not cintre, "carreaux": [2, 4], "forme": "surbaisse" if cintre and _ch(c, .5) else "droit"}
	var balcon := _ch(c, .6)
	for i in nt:
		var x: float = xs[i]
		if cochere and i == nt - 1:
			_porte(c, 0, _x_porte(c, o, x, 2.8), _r(c, 2.6, 2.9), _r(c, 3.4, 3.7), {"forme": "anse", "cadre": S.pierre, "larg": .3, "couleur": S.porte_c, "vantaux": 2, "style": "panneaux", "cle_voute": true, "dy": -S.rehausse + .05}, true)
		elif not cochere and i == mil:
			_porte(c, 0, _x_porte(c, o, x, 1.4), _r(c, 1.3, 1.5), _r(c, 2.9, 3.1), {"forme": "plein" if _ch(c, .5) else "droit", "imposte": true, "cadre": S.pierre, "larg": .22, "couleur": S.porte_c, "vantaux": 2, "style": "panneaux", "cle_voute": true}, true)
		else:
			_fen(c, 0, x, _r(c, 1.1, 1.2), 2.05, .75, o_rez)
		if i == mil and balcon:
			_fen(c, 1, x, 1.25, 2.6, .06, o_1.merged({"balcon": true, "appui": false}))
		else:
			_fen(c, 1, x, 1.2, 2.25, .55, o_1.merged({"garde_corps": k("2a2c2e", G_BOIS) if _ch(c, .15) else ""}))
		if n == 3: _fen(c, 2, x, 1.05, 1.5, .55, {"cadre": S.pierre, "larg": .16, "carreaux": [2, 3]})
	var styles := ["fronton", "oeil", "capucine"]
	var sl: String = _p(c, styles)
	if S.forme == "brisis":
		for i in nt: S.lucarnes.append([xs[i], sl if i != mil else "fronton", .9, 1.3])
	else:
		if nt == 5 and _ch(c, .5):
			for i in [1, 3]: S.lucarnes.append([xs[i], sl, .85, 1.2])
		S.lucarnes.append([xs[mil], "fronton" if sl != "oeil" else "oeil", .95, 1.3])
	for s in [-1.0, 1.0]: S.souches.append([s * (S.w * .5 - .55), -S.d * .5, 1.3, .6, true])
	S.date = str(_p(c, ["1752", "1768", "1786", "1807", "1831", "1846"]))

## Maison de tailleur de pierre (quai sud, chantier) : façade de pierre de taille d'une seule venue,
## atelier attenant à grande baie sous un appentis, blocs devant, une chèvre.
static func _t_tailleur(c: Chantier, o: Dictionary) -> void:
	var S := c.S
	var w_tot := float(o.get("w", _r(c, 9.2, 11.6)))
	S.w_tot = w_tot
	S.w = w_tot * _r(c, .56, .63)
	S.w_at = w_tot - S.w
	S.d = float(o.get("d", _r(c, 8.0, 9.6)))
	_traces(c, {"date": .7, "ancres": .15, "humidite": .2, "publicite": .1})
	S.forme = "gouttereau"
	if _ch(c, .55): _couvrir(c, "canal", _r(c, 17, 20))
	else: _couvrir(c, "ardoise", _r(c, 38, 44))
	var mur := k(_p(c, ["e3dac2", "ddd3ba", "e6ddc6"]), G_TAILLE)
	_niveaux(c, [_r(c, 3.1, 3.3), _r(c, 2.9, 3.1)], mur)
	S.pierre = k(_p(c, ["e9e1cc", "d8ceb4"]), G_TAILLE)
	S.soub = k(_p(c, ["cbbfa3", "c4b89c"]), G_TAILLE)
	S.soub_h = .45
	S.corniche = "moulure" if _ch(c, .5) else "simple"
	if S.style_toit == "canal" and _ch(c, .5): S.corniche = "genoise2"
	S.bandeau = _ch(c, .5)
	S.debord = .25
	S.volets = "plein" if _ch(c, .5) else "persienne"
	S.vieux = false
	var cote: float = S.cote
	S.atelier = {"cote": cote, "h": _r(c, 4.2, 4.7), "baie_w": _r(c, 2.6, 3.1), "baie_h": _r(c, 2.9, 3.3), "baie_forme": "surbaisse" if _ch(c, .6) else "droit",
		"mur": k(_p(c, MOELLONS), G_MOELLON) if _ch(c, .5) else mur}
	var px := _x_porte(c, o, -cote * _r(c, .3, .9), 1.0)
	_porte(c, 0, px, 1.0, 2.3, {"forme": "droit", "imposte": true, "cadre": S.pierre, "larg": .2, "couleur": S.porte_c, "style": "panneaux"}, true)
	var xf: float = cote * (S.w * .5 - 1.0) if absf(px - cote * (S.w * .5 - 1.0)) > 1.4 else -px
	_fen(c, 0, xf, 1.0, 1.6, .9, {"cadre": S.pierre, "larg": .17, "carreaux": [2, 3]})
	var nf := 3 if S.w > 6.2 else 2
	for x in _baies(c, -S.w * .5 + .5, S.w * .5 - .5, nf, 0.0):
		_fen(c, 1, x, 1.0, 1.6, .8, {"cadre": S.pierre, "larg": .17, "carreaux": [2, 3]})
	S.souches.append([-cote * (S.w * .5 - .5), -S.d * .5, .8, .55, true])
	S.date = str(_p(c, ["1851", "1858", "1864", "1872", "1889"]))

## Grange ou remise (cours de la cité, ville basse, Montléon) : porte charretière en arc surbaissé,
## moellon non enduit, peu d'ouvertures, gerbière à poulie.
static func _t_grange(c: Chantier, o: Dictionary) -> void:
	var S := c.S
	S.w = float(o.get("w", _r(c, 7.6, 10.8)))
	S.d = float(o.get("d", _r(c, 8.0, 11.0)))
	_traces(c, {"boulin": .55, "ancres": .3, "publicite": .25, "surelevation": 0.0, "muree": .2})
	S.forme = "gouttereau" if _ch(c, .7) else "pignon"
	if S.forme == "pignon": _couvrir(c, "plate" if _ch(c, .5) else "canal", _r(c, 40, 46) if _ch(c, .5) else _r(c, 24, 28))
	else: _couvrir(c, "canal" if _ch(c, .75) else "plate", _r(c, 17, 22))
	if S.style_toit == "plate" and S.pente < 30.0: S.pente = _r(c, 38, 44)
	var mur := k(_p(c, MOELLONS), G_MOELLON)
	_niveaux(c, [_r(c, 4.8, 5.8)], mur)
	S.chaine = "droite" if _ch(c, .6) else ""
	S.corniche = _p(c, ["genoise2", "chevrons", "chevrons", ""])
	S.debord = .4
	S.rive = "debord"
	S.soub = ""
	var cote: float = S.cote
	var wc := _r(c, 3.2, 3.8)
	var xc := _x_porte(c, o, cote * _r(c, 0.0, S.w * .5 - wc * .5 - .7), wc)
	var fc: String = _p(c, ["surbaisse", "surbaisse", "anse", "droit"])
	_porte(c, 0, xc, wc, _r(c, 3.5, 4.1), {"forme": fc, "cadre": S.pierre if fc != "droit" else S.bois_vieux, "larg": .32 if fc != "droit" else .24,
		"couleur": S.bois_vieux, "vantaux": 2, "heurtoir": false, "ouvert": .55 if _ch(c, .35) else 0.0, "cle_voute": fc != "droit" and _ch(c, .4)}, true)
	var reste: float = S.w * .5 - absf(xc) - wc * .5
	if _ch(c, .5) and reste > 1.6:
		_porte(c, 0, -signf(xc + .001) * (S.w * .5 - .9), .9, 2.0, {"forme": "droit", "cadre": S.pierre, "larg": .15, "couleur": S.bois_vieux})
	for i in c.rng.randi_range(1, 3):
		_fen(c, 0, _r(c, -S.w * .4, S.w * .4), .16, .75, _r(c, 2.6, 3.4), {"cadre": S.pierre, "larg": .1, "appui": false, "carreaux": [1, 1], "volets": "", "verre": k("181614", G_BOIS)})
	if S.forme == "gouttereau":
		if _ch(c, .75): S.lucarnes.append([xc + _r(c, -.5, .5), "gerbiere", 1.1, 1.3])
	elif not _a(c, "publicite"):
		S.gerbiere_pignon = true
	S.foin = _ch(c, .6)

## Maison basse de quai (quai, ville basse nord) : un niveau et un comble, enduite à la chaux, volets
## peints vifs, banc devant.
static func _t_quai(c: Chantier, o: Dictionary) -> void:
	var S := c.S
	S.w = float(o.get("w", _r(c, 5.2, 7.4)))
	S.d = float(o.get("d", _r(c, 6.0, 7.5)))
	_traces(c, {"porte_fenetre": .2, "muree": .15, "ecaille": .4, "humidite": .5, "date": .2, "publicite": .1})
	S.forme = "gouttereau" if _ch(c, .8) else "croupe"
	_couvrir(c, "canal", _r(c, 16, 20))
	var mur := k(_p(c, ENDUITS_CHAUX), G_ENDUIT)
	var surc := _r(c, .5, 1.0)
	_niveaux(c, [_r(c, 3.0, 3.3)], mur, surc)
	var peint := _ch(c, .5)
	S.pierre = k(_p(c, ["f0ece2", "dcd8cc", "e6e0d2"]), G_ENDUIT) if peint else k(_p(c, TAILLES), G_TAILLE)
	S.soub = k(_p(c, ["5a5650", "4f4c48"]), G_ENDUIT) if _ch(c, .35) else k(_p(c, ["b8b2a4", "c2b8a2"]), G_ENDUIT)
	S.soub_h = .55
	S.corniche = "genoise2" if _ch(c, .65) else "chevrons"
	S.debord = .3
	S.volets = "plein" if _ch(c, .55) else "barres"
	S.gouttiere = S.corniche == "chevrons" and _ch(c, .6)
	var cote: float = S.cote
	var wf := _r(c, .9, 1.0)
	var hf := _r(c, 1.3, 1.5)
	var o_f := {"cadre": S.pierre, "larg": .15, "carreaux": [2, 3]}
	if _ch(c, .6) and S.w > 5.8:
		var px := _x_porte(c, o, 0.0, .9)
		_porte(c, 0, px, .9, 2.15, {"forme": "droit", "imposte": _ch(c, .4), "cadre": S.pierre, "larg": .15, "couleur": S.porte_c, "style": "panneaux"}, true)
		for s in [-1.0, 1.0]: _fen(c, 0, px + s * _r(c, 1.55, 1.85), wf, hf, .95, o_f)
	else:
		var px := _x_porte(c, o, cote * (S.w * .5 - .9), .9)
		_porte(c, 0, px, .9, 2.15, {"forme": "droit", "imposte": _ch(c, .4), "cadre": S.pierre, "larg": .15, "couleur": S.porte_c}, true)
		for x in _baies(c, -S.w * .5 + .4 if cote > 0 else px + .8, px - .8 if cote > 0 else S.w * .5 - .4, 2 if S.w > 6.0 else 1, .05):
			_fen(c, 0, x, wf, hf, .95, o_f)
	if surc > .7 and _ch(c, .6):
		for x in _baies(c, -S.w * .5 + .8, S.w * .5 - .8, 2, .1):
			S.compo.append({"k": "fenetre", "x": x, "y": S.hc - surc + .12, "w": .5, "h": .42, "o": {"carreaux": [1, 1], "volets": "", "appui": false, "cadre": S.pierre, "larg": .1}, "et": 9})
	elif _ch(c, .5):
		S.lucarnes.append([_r(c, -.6, .6), "passante" if _ch(c, .4) else "pignon", .7, .85])
	S.souches.append([cote * -1.0 * (S.w * .5 - .5), -S.d * .5, .65, .5, false])
	S.banc = _ch(c, .85)
	S.date = str(_p(c, ["1838", "1846", "1852", "1867"]))

## Maison ouvrière en brique (la cité de la porcelaine) : brique, bandes de brique claire, linteaux de
## pierre, numéro peint.
static func _t_ouvriere(c: Chantier, o: Dictionary) -> void:
	var S := c.S
	S.w = float(o.get("w", _r(c, 5.0, 6.4)))
	S.d = float(o.get("d", _r(c, 7.0, 8.4)))
	var n: int = clampi(int(o.get("niveaux", 1 if _ch(c, .45) else 2)), 1, 2)
	_traces(c, {"date": .25, "marquise": .3, "humidite": .25, "publicite": .1})
	S.forme = "gouttereau" if _ch(c, .85) else "pignon"
	if _ch(c, .6): _couvrir(c, "meca", _r(c, 30, 36))
	else: _couvrir(c, "ardoise", _r(c, 36, 40))
	var brique := k(_p(c, BRIQUES), G_TAILLE)
	var hs := [_r(c, 2.9, 3.1)]
	if n == 2: hs.append(_r(c, 2.75, 2.9))
	_niveaux(c, hs, brique, _r(c, .3, .6))
	S.brique_claire = k(_p(c, ["d2ae84", "dcc29a", "c99a70"]), G_TAILLE)
	S.pierre = k(_p(c, ["dcd2b8", "d4c8aa"]), G_TAILLE)
	S.soub = k(_p(c, ["8a4634", "7e4232"]), G_TAILLE)
	S.soub_h = .45
	S.chaine = "harpe" if _ch(c, .5) else ""
	S.chaine_cle = S.brique_claire
	S.corniche = "brique"
	S.debord = .35
	S.rive = "debord"
	S.volets = _p(c, ["persienne", "persienne", "plein", ""])
	S.vieux = false
	S.gouttiere = true
	var cote: float = S.cote
	var px := _x_porte(c, o, cote * (S.w * .5 - .95), .9)
	var o_f := {"cadre": "", "linteau": S.pierre, "carreaux": [2, 3], "cadre_appui": S.pierre}
	_porte(c, 0, px, .9, 2.2, {"forme": "droit", "imposte": _ch(c, .6), "cadre": "", "linteau": S.pierre, "couleur": S.porte_c, "style": "panneaux"}, true)
	var xf := px - cote * _r(c, 1.8, 2.3)
	_fen(c, 0, xf, 1.0, 1.45, .9, o_f)
	if n == 2:
		_fen(c, 1, px, .9, 1.3, .85, o_f)
		_fen(c, 1, xf, .9, 1.3, .85, o_f)
	elif _ch(c, .65):
		S.lucarnes.append([(px + xf) * .5, "passante", .7, .85])
		S.lucarne_mur = brique
	S.numero = str(c.rng.randi_range(2, 48))
	S.souches.append([-cote * (S.w * .5 - .4), -S.d * .5, .55, .45, false])
	S.genre_souche = brique
	S.date = str(_p(c, ["1908", "1912", "1921", "1926"]))

## Maison forte (cité) : haute, peu d'ouvertures, une échauguette ou une tourelle d'angle.
static func _t_forte(c: Chantier, o: Dictionary) -> void:
	var S := c.S
	S.w = float(o.get("w", _r(c, 7.0, 9.0)))
	S.d = float(o.get("d", _r(c, 7.2, 8.6)))
	var n: int = clampi(int(o.get("niveaux", 3 if _ch(c, .55) else 4)), 3, 4)
	_traces(c, {"boulin": .55, "ancres": .5, "muree": .35, "niche": .2, "surelevation": .12, "date": .15})
	S.forme = "pavillon" if _ch(c, .55) else "gouttereau"
	if _ch(c, .5): _couvrir(c, "ardoise", _r(c, 54, 60))
	else: _couvrir(c, "plate", _r(c, 50, 55))
	var mur := k(_p(c, ["b4a78c", "baad92", "aea186", "b0a48a"]), G_MOELLON)
	var hs := [_r(c, 3.2, 3.5)]
	for i in n - 1: hs.append(_r(c, 3.0, 3.2))
	_niveaux(c, hs, mur)
	_surelever(c)
	S.chaine = "harpe" if _ch(c, .7) else ""
	S.corniche = "simple" if _ch(c, .5) else ""
	S.corbeaux = _ch(c, .45)
	S.rive = "maconnee"
	S.rive_d = 0.0
	S.debord = .35
	S.volets = "barres"
	var cote: float = S.cote
	var px := _x_porte(c, o, cote * _r(c, .4, 1.6), 1.1)
	_porte(c, 0, px, _r(c, 1.0, 1.15), _r(c, 2.3, 2.5), {"forme": _p(c, ["plein", "brise"]), "cadre": S.pierre, "larg": .26, "couleur": S.porte_c, "style": "planches"}, true)
	for i in c.rng.randi_range(1, 2):
		_fen(c, 0, -cote * _r(c, .8, S.w * .4), .14, 1.0, 1.2, {"cadre": S.pierre, "larg": .14, "appui": false, "carreaux": [1, 1], "verre": k("161412", G_BOIS)})
	_fen(c, 1, _r(c, -S.w * .3, S.w * .3), .65, .85, 1.1, {"cadre": S.pierre, "larg": .16, "carreaux": [1, 2]})
	_fen(c, 1, -cote * S.w * .35, .14, .9, 1.1, {"cadre": S.pierre, "larg": .12, "appui": false, "carreaux": [1, 1], "verre": k("161412", G_BOIS)})
	_fen(c, 2, _r(c, -S.w * .2, S.w * .2), _r(c, 1.1, 1.25), _r(c, 1.85, 2.0), .8, {"meneaux": "croisee", "cadre": S.pierre, "larg": .2, "accolade": _ch(c, .4)})
	if n == 4:
		for x in _baies(c, -S.w * .5 + .8, S.w * .5 - .8, c.rng.randi_range(1, 2), .2):
			_fen(c, 3, x, .9, 1.3, .8, {"meneaux": "demi", "cadre": S.pierre, "larg": .17})
	if _ch(c, .35): S.lucarnes.append([_r(c, -S.w * .25, S.w * .25), "passante", .7, .95])
	S.echauguette = _ch(c, .6)
	S.angle = {"cote": -cote if absf(px) < S.w * .3 else signf(-px + .001), "r": _r(c, .7, .85) if S.echauguette else _r(c, 1.5, 1.9)}
	S.breteche = _ch(c, .3)
	S.souches.append([cote * (S.w * .5 - .6), -S.d * .6, .9, .6, false])
	S.date = str(_p(c, ["1453", "1478", "1502"]))


# --- la pose des ouvertures -----------------------------------------------------------------------

## Les marches devant un seuil plus haut que le sol (la pente, le perron) ; une rampe de collision.
static func _marches(c: Chantier, x: float, w: float, y_sol: float, y_seuil: float, z0 := 0.0, cle := "") -> void:
	var n := ceili((y_seuil - y_sol) / .17)
	if n <= 0: return
	var hm := (y_seuil - y_sol) / n
	var m: String = cle if cle != "" else c.S.pierre
	for i in n:
		var haut := y_sol + hm * (i + 1)
		var prof := (n - i) * .3
		_boite(c, m, Vector3(x, (y_sol - .3 + haut) * .5, z0 + prof * .5), Vector3(w, haut - y_sol + .3, prof), Basis(), 1 | 2 | 4 | 16)
	A.rampe(c.g, Vector3(x, y_sol, z0 + n * .3 + .05), Vector3(x, y_seuil, z0), w)

static func _remplissage(c: Chantier) -> String:
	var g := _genre_de(c.S.mur)
	if g == G_ENDUIT:
		var col := Color(str(c.S.mur).split(":")[0]).darkened(.07).lerp(Color("bba98c"), .25)
		return k(col.to_html(false), G_ENDUIT)
	return k(_p(c, ["9a8c74", "b2a68e", "a69a82"]), G_TAILLE)

static func _ouvrir(c: Chantier) -> void:
	var S := c.S
	var lum: float = S.lumiere
	# les traces qui transforment une baie : une fenêtre murée, une porte devenue fenêtre
	if _a(c, "muree"):
		var cand := []
		for e in S.compo:
			if e.k == "fenetre" and e.w > .45 and not e.o.has("meneaux"): cand.append(e)
		if not cand.is_empty(): _p(c, cand)["muree"] = true
	if _a(c, "porte_fenetre"):
		for e in S.compo:
			if e.k == "fenetre" and e.et == 0 and e.w > .55 and not e.get("muree", false):
				e.k = "porte_fenetre"
				break
	var px = S.get("porte_x", null)
	for e in S.compo:
		var o: Dictionary = (e.o as Dictionary).duplicate()
		var x: float = e.x
		var y: float = e.y
		var w: float = e.w
		var h: float = e.h
		if px != null and e.et == 0 and e.k in ["fenetre", "porte_fenetre"] and not e.get("principale", false) and absf(x - float(px)) < w * .5 + 1.0 and y < S.y0 + 2.5:
			continue
		match e.k:
			"fenetre", "porte_fenetre":
				if not o.has("cadre"): o.cadre = ""
				if not o.has("volets"): o.volets = S.volets if _ch(c, .85) else ""
				o.couleur = o.get("couleur", S.menuis)
				o.dormant = o.get("dormant", S.dormant)
				o.allumee = lum > 0.0 and c.rng.randf() < lum and w > .3
				var t := c.rng.randf()
				o.ouverture = 1.0 if t < .55 else (0.0 if t < .8 else .5)
				if o.allumee and o.ouverture < .25: o.ouverture = 1.0
				if e.k == "porte_fenetre":
					_porte_fenetre(c, x, y, w, h, o)
				elif e.get("muree", false):
					_muree(c, x, y, w, h, o)
				else:
					fenetre(c, x, y, w, h, o)
					if o.get("linteau", "") != "":
						_saillie(c, o.linteau, x, y + h + .11, w + .34, .22, float(o.get("z", 0.0)), .05)
					if o.get("balcon", false): _balcon(c, x, y, w)
					if e.et >= 1 and e.et < 9 and w > .6: S.get_or_add("fenetres_hautes", []).append([x, y, w, float(o.get("z", 0.0))])
			"porte":
				o.allumee = lum > 0.0 and c.rng.randf() < lum * .5
				porte(c, x, y, w, h, o)
				if o.get("linteau", "") != "":
					_saillie(c, o.linteau, x, y + h + .11, w + .34, .22, 0.0, .05)
				if e.et == 0 and not o.get("pas_de_marches", false):
					var ys := _sol(S, x)
					if y - ys > .1: _marches(c, x, w + .3, ys, y, 0.0)
				if e.get("principale", false):
					S.porte_haut = y + h
					S.porte_w = w
			"arcade":
				o.allumee = lum > 0.0 and c.rng.randf() < lum * 1.4
				arcade(c, x, y, w, h, o)

## Une baie murée : l'encadrement resté, le remplissage d'une autre pierre ou d'un enduit plus terne.
static func _muree(c: Chantier, x: float, y: float, w: float, h: float, o: Dictionary) -> void:
	var z0: float = o.get("z", 0.0)
	var ct := _decale(contour(o.get("forme", "droit"), w, h), x, y)
	_relief(c, _remplissage(c), ct, z0, z0 + .012)
	var cadre: String = o.cadre if o.cadre != "" else c.S.pierre
	_bande(c, cadre, ct, float(o.get("larg", .15)), z0, z0 + .05, false)
	_saillie(c, cadre, x, y - .045, w + .2, .09, z0, .1)
	if _ch(c, .3): _saillie(c, k("1c1a18", G_BOIS), x, y + h * .55, .12, h * .35, z0 + .012, .004)

## Une porte devenue fenêtre : l'encadrement descend jusqu'au sol, l'allège est murée.
static func _porte_fenetre(c: Chantier, x: float, y: float, w: float, h: float, o: Dictionary) -> void:
	var S := c.S
	var ys := _sol(S, x) + .02
	var ct := _decale(contour("droit", w + .1, y + h - ys), x, ys)
	_bande(c, S.pierre, ct, .17, 0.0, .06, false)
	_relief(c, _remplissage(c), PackedVector2Array([Vector2(x - w * .5 - .05, ys), Vector2(x - w * .5 - .05, y), Vector2(x + w * .5 + .05, y), Vector2(x + w * .5 + .05, ys)]), 0.0, .014)
	o.cadre = ""
	o.cadre_appui = S.pierre
	fenetre(c, x, y, w, h, o)

## Un balcon de fer forgé sur une dalle de pierre et ses consoles.
static func _balcon(c: Chantier, x: float, y: float, w: float) -> void:
	var S := c.S
	var fer := k("2a2c2e", G_BOIS)
	var bw := w + 1.0
	_boite(c, S.pierre, Vector3(x, y - .08, .32), Vector3(bw, .14, .64))
	for s in [-1.0, 1.0]:
		_boite(c, S.pierre, Vector3(x + s * (bw * .5 - .2), y - .35, .18), Vector3(.18, .4, .36))
	_boite(c, fer, Vector3(x, y + .92, .62), Vector3(bw, .05, .05))
	for s in [-1.0, 1.0]: _boite(c, fer, Vector3(x + s * bw * .5, y + .92, .32), Vector3(.05, .05, .6))
	var nb := int(bw / .13)
	for i in nb + 1:
		_boite(c, fer, Vector3(x - bw * .5 + bw * i / nb, y + .46, .62), Vector3(.018, .9, .018), Basis(), 1 | 2 | 16 | 32)
	for i in int(bw / .5):
		var cx := x - bw * .5 + .25 + i * .5
		_boite(c, fer, Vector3(cx, y + .5, .625), Vector3(.3, .3, .012), Basis(Vector3.BACK, PI * .25), 16 | 32)


# --- ce qui fait chaque type ----------------------------------------------------------------------

static func _extras(c: Chantier) -> void:
	var S := c.S
	match S.type:
		"medievale": _tourelle(c)
		"echoppe": _encorbellement(c)
		"balet": _balet(c)
		"vigneron":
			_chai(c)
			if S.has("atelier"): _atelier(c)
		"notable": _notable(c)
		"tailleur": _atelier(c)
		"grange": _grange(c)
		"quai": _devant_quai(c)
		"ouvriere": _brique(c)
		"forte": _forte(c)

## La tour d'escalier en vis : fût rond ou polygonal, petites baies qui tournent, toit pointu, porte.
static func _tourelle(c: Chantier) -> void:
	var S := c.S
	var t: Dictionary = S.tourelle
	var ce := Vector3(t.x, 0, t.z)
	var n: int = t.pans
	var a0 := -PI / n
	var rt: float = t.r
	A.collision_cyl(c.g, Vector3(t.x, (S.bas + t.haut) * .5, t.z), t.r, t.haut - S.bas)
	if t.get("chambre", false):
		# la chambre haute, portée sur une couronne de corbeaux : la tour s'élargit sous son toit
		var yc: float = t.haut - 2.3
		_fut(c, S.mur, ce, t.r, S.bas, yc, n, a0, true)
		_fut(c, S.pierre, ce, t.r, yc - .45, yc, n, a0, false, t.r + .32)
		rt = t.r + .32
		_fut(c, S.mur_haut, ce, rt, yc, t.haut, n, a0, false)
		_saillie(c, S.pierre, t.x, yc + 1.1, .6, .8, t.z + rt * cos(PI / n) - .02, .06)
		_saillie(c, LUM if c.rng.randf() < S.lumiere else k("4a5a64", G_BOIS), t.x, yc + 1.1, .36, .56, t.z + rt * cos(PI / n) + .03, .01)
	else:
		_fut(c, S.mur, ce, t.r, S.bas, t.haut, n, a0, true)
	_fut(c, S.pierre, ce, rt + .07, t.haut - .25, t.haut, n, a0, not t.get("chambre", false))
	_cone(c, S.toit, ce, rt + .3, t.haut, rt * (2.6 if t.ronde else 2.2), n, a0)
	_boite(c, k("2a2826", G_BOIS), ce + Vector3(0, t.haut + t.r * 2.6 + .3, 0), Vector3(.04, .7, .04))
	porte(c, t.x, S.y0, .8, 2.05, {"z": t.z + t.r * cos(PI / n) - .01, "forme": "brise" if S.q == "cite" else "plein", "cadre": S.pierre, "larg": .16, "couleur": S.porte_c, "seuil": true})
	var y: float = S.y0 + 2.9
	var a := -.5 if S.cote > 0 else .5
	while y < t.haut - (2.6 if t.get("chambre", false) else 1.0):
		if cos(a) > .05:
			var p: Vector3 = ce + Vector3(sin(a) * (t.r + .02), y, cos(a) * (t.r + .02))
			var b := Basis(Vector3.UP, a)
			_boite(c, S.pierre, p, Vector3(.42, .85, .08), b)
			_boite(c, LUM if c.rng.randf() < S.lumiere * .5 else k("1a1816", G_BOIS), p + b * Vector3(0, 0, .045), Vector3(.2, .6, .02), b)
		y += 1.15
		a += .95 * S.cote

## L'étage en encorbellement : sablière, abouts de solives, et le pan de bois sur l'enduit.
static func _encorbellement(c: Chantier) -> void:
	var S := c.S
	if S.etages.size() < 2: return
	var av: float = S.avance
	var y1: float = S.etages[1].y
	var bois: String = S.bois_pan
	if av > 0.0:
		_boite(c, bois, Vector3(0, y1 - .12, av * .5), Vector3(S.w + .02, .24, av + .02), Basis(), 63 - 32)
		var nb := int(S.w / .45)
		for i in nb:
			_boite(c, bois, Vector3(-S.w * .5 + .22 + i * (S.w - .44) / maxf(1, nb - 1), y1 - .3, av * .5), Vector3(.12, .14, av + .08), Basis(), 1 | 2 | 8 | 16)
		for s in [-1.0, 1.0]:
			# les aisseliers sous les angles de l'encorbellement
			var p := Vector3(s * (S.w * .5 - .15), y1 - .55, av * .45)
			_boite(c, bois, p, Vector3(.12, .75, .12), Basis(Vector3.RIGHT, -.6))
	if not S.pan_bois: return
	for i in range(1, S.etages.size()):
		var e: Dictionary = S.etages[i]
		var y0: float = e.y
		var h: float = e.h - (S.surcroit if i == S.etages.size() - 1 else 0.0)
		var z := av + .005
		_saillie(c, bois, 0, y0 + .08, S.w, .16, z, .05)
		_saillie(c, bois, 0, y0 + h - .08, S.w, .16, z, .05)
		var baies := []
		for f in S.compo:
			if f.k == "fenetre" and f.et == i: baies.append(f)
		var poteaux := []
		var nb := int(S.w / .62)
		for j in nb + 1:
			poteaux.append(-S.w * .5 + .07 + (S.w - .14) * j / nb)
		for f in baies:
			poteaux.append(f.x - f.w * .5 - .07)
			poteaux.append(f.x + f.w * .5 + .07)
		for xp in poteaux:
			var dans := false
			for f in baies:
				if xp > f.x - f.w * .5 - .02 and xp < f.x + f.w * .5 + .02: dans = true
			if dans: continue
			_saillie(c, bois, xp, y0 + h * .5, .13, h - .3, z, .045)
		# l'allège et ses croix, les écharpes des panneaux pleins
		_saillie(c, bois, 0, y0 + .82, S.w, .12, z, .04)
		for j in nb:
			var xa: float = -S.w * .5 + .07 + (S.w - .14) * j / nb
			var xb: float = -S.w * .5 + .07 + (S.w - .14) * (j + 1) / nb
			var xm: float = (xa + xb) * .5
			var libre := true
			for f in baies:
				if absf(xm - f.x) < f.w * .5 + .3: libre = false
			var dx: float = xb - xa
			if libre:
				var hh := h - 1.05
				var ang := atan2(hh, dx) * (1.0 if j % 2 == 0 else -1.0)
				_boite(c, bois, Vector3(xm, y0 + .88 + hh * .5, z + .02), Vector3(sqrt(dx * dx + hh * hh), .11, .04), Basis(Vector3.BACK, ang), 31)
			elif j % 2 == 0:
				for sg in [1.0, -1.0]:
					_boite(c, bois, Vector3(xm, y0 + .45, z + .02), Vector3(sqrt(dx * dx + .5), .09, .035), Basis(Vector3.BACK, sg * atan2(.7, dx)), 31)

## Le balet : l'escalier de pierre le long de la façade, son parapet, le palier sur un arc, l'auvent.
static func _balet(c: Chantier) -> void:
	var S := c.S
	var b: Dictionary = S.balet
	var cote: float = S.cote
	var zl: float = b.larg * .5 + .08
	var y: float = b.y
	var sol0 := _sol(S, b.x_dep)
	A.escalier(c.g, Vector3(b.x_dep, sol0, zl), Vector3(b.x_haut, y, zl), b.larg, matiere(S.pierre))
	# le parapet qui suit la pente
	var pa := Vector3(b.x_dep, sol0 + .55, b.larg + .2)
	var pb := Vector3(b.x_haut, y + .75, b.larg + .2)
	var mil := (pa + pb) * .5
	var ang := atan2(pb.y - pa.y, (pb.x - pa.x))
	_boite(c, S.mur if _genre_de(S.mur) != G_TAILLE else S.pierre, mil - Vector3(0, .45, 0), Vector3(pa.distance_to(pb) + .1, 1.0, .22), Basis(Vector3.BACK, ang))
	A.collision(c.g, mil - Vector3(0, .3, 0), Vector3(pa.distance_to(pb), 1.3, .22), Vector3(0, 0, ang))
	_boite(c, S.pierre, mil + Vector3(0, .08, 0), Vector3(pa.distance_to(pb) + .12, .07, .3), Basis(Vector3.BACK, ang))
	# le palier sur son arc, la cave dessous
	var xp: float = b.x_haut - cote * b.pal_w * .5
	var pd: float = b.pal_d
	_boite(c, S.pierre, Vector3(xp, y - .12, pd * .5), Vector3(b.pal_w + .05, .24, pd))
	A.collision(c.g, Vector3(xp, y - .15, pd * .5), Vector3(b.pal_w, .3, pd))
	for s in [-1.0, 1.0]:
		_boite(c, S.pierre, Vector3(xp + s * (b.pal_w * .5 - .14), (S.bas + y - .24) * .5, pd - .14), Vector3(.28, y - .24 - S.bas, .28), Basis(), 63 - 8 - 4)
	_boite(c, S.pierre, Vector3(xp, y - .38, pd - .14), Vector3(b.pal_w, .3, .3), Basis(), 63 - 4)
	# la balustrade de bois du palier
	var bois: String = S.bois_vieux
	_boite(c, bois, Vector3(xp, y + .9, pd - .05), Vector3(b.pal_w, .07, .07))
	for i in 5:
		_boite(c, bois, Vector3(xp - b.pal_w * .5 + .1 + i * (b.pal_w - .2) / 4.0, y + .45, pd - .05), Vector3(.05, .9, .05), Basis(), 63 - 4 - 8)
	# l'auvent sur deux poteaux
	var ht := y + 2.25
	var hm := y + 2.75
	for s in [-1.0, 1.0]:
		_boite(c, bois, Vector3(xp + s * (b.pal_w * .5 + .1), (y + ht) * .5, pd - .05), Vector3(.13, ht - y, .13), Basis(), 63 - 4 - 8)
	_boite(c, bois, Vector3(xp, ht + .07, pd - .05), Vector3(b.pal_w + .45, .15, .15))
	var aw: float = b.pal_w + .8
	var e0 := Vector3(xp - aw * .5, ht + .1, pd + .35)
	var e1 := Vector3(xp + aw * .5, ht + .1, pd + .35)
	var r1 := Vector3(xp + aw * .5, hm, 0.0)
	var r0 := Vector3(xp - aw * .5, hm, 0.0)
	_plaque(c, S.toit, [e0, e1, r1, r0], .1)
	_couverture(c, e0, e1, r1, r0)

## La maison de notable : les refends du rez-de-chaussée (bossage), les pilastres d'angle.
static func _notable(c: Chantier) -> void:
	var S := c.S
	var joint := k(Color(str(S.mur).split(":")[0]).darkened(.22).to_html(false), G_TAILLE)
	if S.get("refends", false):
		var y: float = S.y0 + float(S.soub_h) + .36
		while y < S.etages[1].y - .1:
			_saillie(c, joint, 0, y, S.w - .02, .035, 0.0, .004)
			y += .4
	if S.get("pilastres", false):
		for s in [-1.0, 1.0]:
			var y0: float = S.etages[1].y if S.get("refends", false) else S.y0 + float(S.soub_h)
			_saillie(c, S.pierre, s * (S.w * .5 - .32), (y0 + S.hc - .3) * .5, .62, S.hc - .3 - y0, 0.0, .07)
			_saillie(c, S.pierre, s * (S.w * .5 - .32), S.hc - .45, .76, .22, 0.0, .1)

## Le chai du vigneron : les tonneaux devant la porte de cave, et l'arrière qui descend au jardin.
static func _chai(c: Chantier) -> void:
	var S := c.S
	var cv: Dictionary = S.cave
	var fer := k("2a2826", G_BOIS)
	for i in c.rng.randi_range(1, 3):
		var x: float = cv.x + (cv.w * .5 + .5 + i * .72) * (-1.0 if cv.x > 0 else 1.0)
		var sol := _sol(S, x)
		var ce := Vector3(x, sol, .55 + c.rng.randf() * .3)
		var r := _r(c, .3, .36)
		var hh := r * 2.4
		_fut(c, k(_p(c, ["9a7a58", "a8865e", "8e7052"]), G_BOIS), ce, r * .86, 0.0, hh * .5, 8, 0.0, false, r)
		_fut(c, k(_p(c, ["9a7a58", "a8865e"]), G_BOIS), ce, r, hh * .5, hh, 8, 0.0, false, r * .86)
		for yy in [hh * .2, hh * .8]:
			_fut(c, fer, ce, r * .97 + .01, yy - .03, yy + .03, 8)
		_cone(c, k("8e7052", G_BOIS), ce, r * .86, hh, .01, 8)
		A.collision_cyl(c.g, ce + Vector3(0, hh * .5, 0), r, hh)
	# côté jardin, le niveau bas : une porte et deux fenêtres sur l'arrière
	var fl: float = S.flanc
	if fl <= 0.5: return
	var yb: float = S.y0 - fl
	var zb: float = -S.d
	for i in 3:
		var x: float = lerpf(-S.w * .32, S.w * .32, i * .5)
		var b := Basis(Vector3.UP, PI)
		var p := Vector3(x, yb + (0.0 if i == 1 else 1.0), zb - .01)
		var hh := 2.1 if i == 1 else 1.1
		var ww := .95 if i == 1 else .8
		_boite(c, S.pierre, p + Vector3(0, hh * .5, -.03), Vector3(ww + .3, hh + .2, .06), b)
		_boite(c, k("1c1a18", G_BOIS) if i == 1 else k("27363c", G_BOIS), p + Vector3(0, hh * .5, -.065), Vector3(ww, hh, .02), b)

## L'atelier du tailleur : un volume plus bas, son appentis, la grande baie ouverte, les blocs, la chèvre.
static func _atelier(c: Chantier) -> void:
	var S := c.S
	var at: Dictionary = S.atelier
	var s: float = at.cote
	var wa: float = S.w_at
	var xa: float = s * (S.w * .5 + wa * .5)
	var ha: float = at.h
	var mur: String = at.mur
	_boite(c, mur, Vector3(xa, (S.bas + ha) * .5, -S.d * .5), Vector3(wa, ha - S.bas, S.d - .4), Basis(), 1 | 2 | 16 | 32)
	A.collision(c.g, Vector3(xa, (S.bas + ha) * .5, -S.d * .5), Vector3(wa, ha - S.bas, S.d - .4))
	_chaine(c, s * (S.w * .5 + wa), s, S.y0, ha, S.pierre, false)
	# l'appentis, adossé au mur de la maison
	var hr := minf(S.hc - ha - .3, wa * .45)
	var xi: float = s * S.w * .5
	var xo: float = s * (S.w * .5 + wa + .35)
	var e0 := Vector3(xo, ha - .12, .4)
	var e1 := Vector3(xo, ha - .12, -S.d + .0)
	var r1 := Vector3(xi, ha + hr, -S.d + .0)
	var r0 := Vector3(xi, ha + hr, .4)
	_plaque(c, S.toit, [e0, e1, r1, r0], .12)
	_couverture(c, e0, e1, r1, r0)
	_tri(c, mur, Vector3(xi, ha, -.0), Vector3(s * (S.w * .5 + wa), ha, 0.0), Vector3(xi, ha + hr, 0.0), Vector3.BACK)
	# la grande baie
	var bw: float = at.baie_w
	var bh: float = at.baie_h
	var ys := _sol(S, xa) + .03
	var blocs: bool = at.get("blocs", true)
	porte(c, xa, ys, bw, bh, {"forme": at.baie_forme, "cadre": S.pierre if at.baie_forme != "droit" else S.bois_vieux, "larg": .3, "couleur": S.bois_vieux, "vantaux": 2, "ouvert": .9 if blocs else 0.0, "heurtoir": false})
	if not blocs: return
	# les blocs devant, équarris ou à peine dégrossis, et l'établi
	var tailles := ["ddd3b9", "d4c9ad", "e2d9c0", "cdc1a4"]
	var nb := c.rng.randi_range(2, 4)
	for i in nb:
		var t := Vector3(_r(c, .6, 1.3), _r(c, .45, .9), _r(c, .5, .9))
		var p := Vector3(xa + _r(c, -wa * .55, wa * .55), 0, _r(c, .7, 1.7))
		p.y = _sol(S, clampf(p.x, -S.w_tot * .5, S.w_tot * .5)) + t.y * .5 - .02
		var b := Basis(Vector3.UP, _r(c, -.4, .4))
		_boite(c, k(_p(c, tailles), G_TAILLE), p, t, b, 63 - 8)
		A.collision(c.g, p, t, Vector3(0, b.get_euler().y, 0))
		if i == 0 and _ch(c, .6):
			var t2 := t * Vector3(.7, .8, .8)
			_boite(c, k(_p(c, tailles), G_TAILLE), p + Vector3(.05, t.y * .5 + t2.y * .5, 0), t2, Basis(Vector3.UP, _r(c, -.5, .5)), 63 - 8)
	var xe: float = xa - s * wa * .35
	var ye := _sol(S, xe)
	for dx in [-.6, .6]:
		_boite(c, k("cdc1a4", G_TAILLE), Vector3(xe + dx, ye + .35, .55), Vector3(.35, .7, .4), Basis(), 63 - 8)
	_boite(c, S.bois_vieux, Vector3(xe, ye + .74, .55), Vector3(1.7, .08, .5))
	if _ch(c, .55):
		# la chèvre : trois perches liées en tête, une poulie, une chaîne
		var tete := Vector3(xa + s * wa * .3, _sol(S, xa) + 3.2, 1.3)
		for a in [0.3, 2.4, 4.4]:
			var pied := Vector3(tete.x + cos(a) * .9, _sol(S, xa) - .05, tete.z + sin(a) * .9)
			var m := (pied + tete) * .5
			var dir := (tete - pied).normalized()
			var b := Basis(Quaternion(Vector3.UP, dir))
			_boite(c, S.bois_vieux, m, Vector3(.09, pied.distance_to(tete) + .2, .09), b, 63 - 4 - 8)
		_boite(c, k("2a2826", G_BOIS), tete - Vector3(0, .25, 0), Vector3(.18, .24, .08))
		_boite(c, k("2a2826", G_BOIS), tete - Vector3(0, 1.1, 0), Vector3(.025, 1.5, .025), Basis(), 1 | 2 | 16 | 32)

## La grange : la gerbière dans le pignon, le foin qui dépasse, les herbes.
static func _grange(c: Chantier) -> void:
	var S := c.S
	if S.get("gerbiere_pignon", false):
		var y: float = S.hc + .25
		porte(c, 0.0, y, 1.1, 1.4, {"couleur": S.bois_vieux, "cadre": S.bois_vieux, "larg": .14, "seuil": false, "heurtoir": false, "ouvert": .6 if S.foin else 0.0})
		_boite(c, S.bois_vieux, Vector3(0, y + 2.0, .5), Vector3(.15, .17, 1.2))
		_boite(c, k("2a2826", G_BOIS), Vector3(0, y + 1.8, 1.0), Vector3(.06, .2, .2))
		_boite(c, k("8a7a5a", G_BOIS), Vector3(0, y + .7, 1.02), Vector3(.025, 2.0, .025))
		if S.foin: _boite(c, k("c4ae66", G_BOIS), Vector3(-.15, y + .35, -.05), Vector3(.7, .6, .2))

## Devant la maison de quai : le banc de pierre et de planche.
static func _devant_quai(c: Chantier) -> void:
	var S := c.S
	if not S.get("banc", false): return
	var px: float = S.get("porte_x", 0.0)
	var x := px + (1.3 if px < S.w * .5 - 2.2 else -1.3) + _r(c, -.2, .2)
	if absf(x) > S.w * .5 - .9: x = -px * .8
	var y := _sol(S, x)
	for dx in [-.6, .6]:
		_boite(c, S.pierre if _genre_de(S.pierre) == G_TAILLE else k("cfc4a8", G_TAILLE), Vector3(x + dx, y + .21, .32), Vector3(.18, .42, .34), Basis(), 63 - 8)
	_boite(c, S.bois_vieux, Vector3(x, y + .45, .3), Vector3(1.6, .07, .38))
	A.collision(c.g, Vector3(x, y + .3, .3), Vector3(1.6, .6, .4))

## La maison de brique : bandes de brique claire, frise sous l'égout, numéro émaillé.
static func _brique(c: Chantier) -> void:
	var S := c.S
	var bc: String = S.brique_claire
	for i in range(1, S.etages.size()):
		_saillie(c, bc, 0, S.etages[i].y + .02, S.w + .02, .2, 0.0, .03)
	_saillie(c, bc, 0, S.y0 + 2.45, S.w + .01, .07, 0.0, .02)
	if S.has("porte_x"):
		var px: float = S.porte_x
		var y: float = S.y0 + 2.55
		var xn := px + (.85 if px < 0 else -.85)
		_saillie(c, k("1f3f78", G_BOIS), xn, y, .34, .24, 0.0, .02)
		_saillie(c, k("e8e6de", G_BOIS), xn, y, .3, .2, .02, .004)
		_saillie(c, k("1f3f78", G_BOIS), xn, y, .27, .17, .024, .002)
		_texte(c, k("f2f0ea", G_BOIS), S.numero, Vector3(xn, y, .03), .15)

## La maison forte : échauguette en encorbellement ou tourelle d'angle, bretèche, corbeaux.
static func _forte(c: Chantier) -> void:
	var S := c.S
	var an: Dictionary = S.angle
	var s: float = an.cote
	var r: float = an.r
	if S.echauguette:
		var ce := Vector3(s * (S.w * .5 + .05), 0, .15 - r * .2)
		var y0: float = S.hc - 3.0
		var y1: float = S.hc + .4
		_fut(c, S.pierre, ce, .12, y0 - 1.1, y0, 8, 0.0, false, r + .05)
		_fut(c, S.mur, ce, r, y0, y1, 8)
		_fut(c, S.pierre, ce, r + .06, y1 - .2, y1, 8)
		_cone(c, S.toit, ce, r + .2, y1, r * 2.7, 8)
		for a in [0.0, s * 1.2]:
			var p := ce + Vector3(sin(a) * (r + .02), y0 + 1.6, cos(a) * (r + .02))
			_boite(c, k("161412", G_BOIS), p, Vector3(.12, .6, .06), Basis(Vector3.UP, a))
	else:
		var ce := Vector3(s * (S.w * .5 + r * .25), 0, -r * .35)
		var ht: float = S.hc + _r(c, 1.6, 2.6)
		_fut(c, S.mur, ce, r, S.bas, ht, 12, 0.0, false)
		A.collision_cyl(c.g, ce + Vector3(0, (S.bas + ht) * .5, 0), r, ht - S.bas)
		_fut(c, S.pierre, ce, r + .08, ht - .3, ht, 12)
		_cone(c, S.toit, ce, r + .3, ht, r * 2.4, 12)
		for i in 3:
			var a := s * (.4 + i * .35)
			var p := ce + Vector3(sin(a) * (r + .02), S.y0 + 3.0 + i * 3.1, cos(a) * (r + .02))
			_boite(c, S.pierre, p, Vector3(.4, .9, .06), Basis(Vector3.UP, a))
			_boite(c, k("161412", G_BOIS), p + Basis(Vector3.UP, a) * Vector3(0, 0, .035), Vector3(.16, .65, .02), Basis(Vector3.UP, a))
	if S.breteche and S.has("porte_x"):
		var px: float = S.porte_x
		var y: float = S.etages[1].y + .4
		_boite(c, S.mur, Vector3(px, y + .6, .35), Vector3(1.4, 1.2, .7), Basis(), 63 - 32)
		for dx in [-.55, 0.0, .55]:
			_boite(c, S.pierre, Vector3(px + dx, y - .2, .3), Vector3(.18, .4, .6), Basis(), 63 - 32)
		_plaque(c, S.toit, [Vector3(px - .8, y + 1.2, .8), Vector3(px + .8, y + 1.2, .8), Vector3(px + .8, y + 1.7, 0), Vector3(px - .8, y + 1.7, 0)], .08)
		_saillie(c, k("161412", G_BOIS), px, y + .7, .12, .5, .7, .004)
	if S.corbeaux:
		var nb := int(S.w / .55)
		for i in nb:
			_boite(c, S.pierre, Vector3(-S.w * .5 + .3 + i * (S.w - .6) / maxf(1, nb - 1), S.hc - .25, .12), Vector3(.2, .3, .24), Basis(), 63 - 32)
		_saillie(c, S.pierre, 0, S.hc - .05, S.w + .1, .12, 0, .26)


# --- souches, lucarnes ----------------------------------------------------------------------------

static func _y_sur_toit(S: Dictionary, x: float, z: float) -> float:
	var tp := tan(deg_to_rad(S.pente))
	match S.forme:
		"pignon": return S.hc + maxf(0.0, S.w * .5 - absf(x)) * tp
		"gouttereau", "appentis": return S.hc + maxf(0.0, S.d * .5 - absf(z + S.d * .5)) * tp
		_: return S.faite

static func _couronner(c: Chantier) -> void:
	var S := c.S
	for sc in S.souches:
		var x: float = sc[0]
		var z: float = sc[1]
		var massive: bool = sc[4]
		if massive and S.forme in ["croupe", "pavillon"]:
			x = signf(x) * maxf(.3, (S.w - S.d) * .5 - .2)
		var cle: String = S.get("genre_souche", S.pierre if massive else S.mur_haut)
		var y1 := maxf(_y_sur_toit(S, x, z), _y_sur_toit(S, x, z - sc[3] * .5)) + (.9 if massive else _r(c, .55, 1.1))
		souche(c, x, z, S.hc - .3, y1, sc[2], sc[3], cle)
	if S.forme in ["gouttereau", "croupe", "brisis", "pavillon"]:
		for l in S.lucarnes:
			lucarne(c, l[0], l[1], l[2], l[3], {"mur": S.get("lucarne_mur", S.mur_haut)})


## L'arrière : une ou deux baies simples par niveau, volets souvent clos ; une porte de jardin.
static func _arriere(c: Chantier) -> void:
	var S := c.S
	var b := Basis(Vector3.UP, PI)
	var vitre := k("3e4a52", G_BOIS)
	for i in S.etages.size():
		var e: Dictionary = S.etages[i]
		var nb := c.rng.randi_range(1, 2 if S.w > 6.5 else 1)
		if S.type == "grange": nb = 1 if i == 0 else 0
		for j in nb:
			var x := _r(c, -S.w * .5 + 1.0, S.w * .5 - 1.0)
			var w := _r(c, .7, .95)
			var h := _r(c, 1.0, 1.35) if i > 0 or S.type != "grange" else 2.0
			var y: float = e.y + (.95 if not (i == 0 and j == 0) else 0.0)
			if i == 0 and j == 0: h = 2.05
			var p := Vector3(x, y + h * .5, -S.d - .01)
			_boite(c, S.pierre, p + Vector3(0, 0, -.02), Vector3(w + .26, h + .22, .05), b, 16)
			_boite(c, vitre if not (i == 0 and j == 0) else S.bois_vieux, p + Vector3(0, 0, -.05), Vector3(w, h, .02), b, 16)
			if i > 0 or j > 0:
				var clos := c.rng.randf() < .5
				for s in [-1.0, 1.0]:
					var px: float = x + s * (w * .25 if clos else w * .75 + .1)
					_boite(c, S.menuis, Vector3(px, y + h * .5, -S.d - .08), Vector3(w * .5 - .01, h, .04), b, 16 | 1 | 2)


# --- les traces de l'histoire ---------------------------------------------------------------------

## Un éclat irrégulier sur la façade (enduit tombé, pierre vue) : un polygone de rayon r.
static func _eclat(c: Chantier, cle: String, x: float, y: float, rx: float, ry: float, z: float, n := 6) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n + _r(c, -.3, .3)
		var rr := _r(c, .6, 1.15)
		pts.append(Vector2(x + cos(a) * rx * rr, y + sin(a) * ry * rr))
	_relief(c, cle, pts, z - .005, z, false)

static func _histoire(c: Chantier) -> void:
	var S := c.S
	var w: float = S.w
	var gm := _genre_de(S.mur)
	var zf := 0.0
	if S.pierre_vue:
		# l'enduit « à pierre vue » : les têtes des moellons affleurent
		var nb := int(w * (S.hc - S.y0) * .9)
		for i in mini(nb, 90):
			var x := _r(c, -w * .5 + .2, w * .5 - .2)
			var y := _r(c, S.y0 + .5, S.hc - .3)
			_eclat(c, k(_p(c, ["d2cab6", "c9c0aa", "dad2bf", "c4baa4"]), G_TAILLE), x, y, _r(c, .09, .17), _r(c, .06, .1), .006, 5)
	if _a(c, "ecaille") and gm == G_ENDUIT:
		for i in c.rng.randi_range(3, 6):
			var x := _r(c, -w * .5 + .4, w * .5 - .4)
			var y: float = S.y0 + _r(c, .45, 1.3)
			_eclat(c, k(_p(c, ["c2b8a0", "b8ad94", "cbc1aa"]), G_TAILLE), x, y, _r(c, .18, .5), _r(c, .12, .32), .007, 10)
		for i in c.rng.randi_range(1, 2):
			var x := (w * .5 - _r(c, .3, .9)) * (1.0 if _ch(c, .5) else -1.0)
			_eclat(c, k(_p(c, ["c2b8a0", "cbc1aa"]), G_TAILLE), x, _r(c, S.y0 + 2.0, S.hc - .6), _r(c, .2, .45), _r(c, .25, .5), .007, 7)
	if _a(c, "humidite") and gm == G_ENDUIT:
		var pts := PackedVector2Array([Vector2(w * .5, S.y0 - .1), Vector2(-w * .5, S.y0 - .1)])
		var nb := int(w / .5)
		for i in nb + 1:
			pts.append(Vector2(-w * .5 + w * i / nb, S.y0 + .55 + sin(i * 1.7) * .12 + _r(c, -.12, .18)))
		var col := Color(str(S.mur).split(":")[0]).darkened(.12).lerp(Color("8a8270"), .2)
		_relief(c, k(col.to_html(false), G_ENDUIT), pts, .0, .004, false)
	if _a(c, "boulin") and gm in [G_MOELLON, G_ENDUIT]:
		for e in S.etages.slice(1):
			var pas := _r(c, .9, 1.3)
			var x := -w * .5 + _r(c, .3, .7)
			while x < w * .5 - .3:
				_saillie(c, k("221f1b", G_BOIS), x, e.y - .2, .15, .15, 0.0, .003)
				x += pas
	if _a(c, "ancres") and S.etages.size() > 1:
		var fer := k("2c2824", G_BOIS)
		for x in [-w * .5 + .55, w * .5 - .55] + ([0.0] if w > 8.0 else []):
			var y: float = S.etages[1].y - .1
			for a in [PI * .25, -PI * .25]:
				_boite(c, fer, Vector3(x, y, .03), Vector3(.5, .045, .03), Basis(Vector3.BACK, a), 31)
	if _a(c, "date") and S.has("porte_haut") and S.has("date"):
		_texte(c, k("9c907a", _genre_de(S.pierre)), S.date, Vector3(S.porte_x, S.porte_haut + .1, .085), .13)
	if _a(c, "niche") and S.etages.size() > 1:
		var x: float = -S.cote * (w * .5 - .75)
		var y: float = S.etages[1].y + 1.0
		var ct := _decale(contour("plein", .5, .95), x, y)
		_relief(c, k("6a6252", G_TAILLE), ct, 0.0, .004, false)
		_bande(c, S.pierre, ct, .1, 0.0, .07, false)
		_boite(c, S.pierre, Vector3(x, y - .06, .1), Vector3(.62, .12, .2))
		var blanc := k("e6dfcc", G_TAILLE)
		_boite(c, blanc, Vector3(x, y + .05, .07), Vector3(.2, .1, .14))
		_fut(c, blanc, Vector3(x, 0, .07), .09, y + .1, y + .55, 6, 0.0, false, .06)
		_boite(c, blanc, Vector3(x, y + .62, .07), Vector3(.1, .12, .1))
	if _a(c, "enseigne") and S.etages.size() > 1:
		var x: float = S.cote * (w * .5 - .35)
		var y: float = S.etages[1].y + .55
		var z0: float = S.avance
		var fer := k("26282a", G_BOIS)
		_boite(c, fer, Vector3(x, y, z0 + .5), Vector3(.04, .04, 1.0))
		_boite(c, fer, Vector3(x, y - .25, z0 + .3), Vector3(.03, .03, .7), Basis(Vector3.RIGHT, .62))
		var coul := k(_p(c, MENUISERIES[S.q]), G_BOIS)
		_boite(c, fer, Vector3(x, y - .08, z0 + .7), Vector3(.02, .14, .02))
		_boite(c, coul, Vector3(x, y - .42, z0 + .7), Vector3(.05, .55, .72))
		var t: String = _p(c, ENSEIGNES)
		var ht := minf(.16, .62 / maxf(1, t.length()) * 1.7)
		_texte(c, k("e2d2a2", G_BOIS), t, Vector3(x + .03, y - .42, z0 + .7), ht, PI * .5)
		_texte(c, k("e2d2a2", G_BOIS), t, Vector3(x - .03, y - .42, z0 + .7), ht, -PI * .5)
	if _a(c, "publicite"):
		_publicite(c)
	if _a(c, "cadran") and S.etages.size() > 1:
		var x: float = S.cote * (w * .5 - 1.0)
		var y: float = S.hc - 1.2
		_saillie(c, k("e9e2cf", gm if gm in [G_ENDUIT, G_TAILLE] else G_TAILLE), x, y, .9, 1.0, 0.0, .006)
		var noir := k("4a443a", G_BOIS)
		for i in 7:
			var a := PI * (i + 1) / 8.0
			_boite(c, noir, Vector3(x + cos(a) * .3, y + .2 - sin(a) * .3, .009), Vector3(.62, .015, .002), Basis(Vector3.BACK, -a), 16)
		_boite(c, noir, Vector3(x, y + .1, .12), Vector3(.02, .02, .25), Basis(Vector3.RIGHT, -.6))
	if _a(c, "marquise") and S.has("porte_haut"):
		var px: float = S.porte_x
		var y: float = S.porte_haut + .35
		var mw: float = S.get("porte_w", 1.0) + .9
		var fer := k("23272a", G_BOIS)
		_boite(c, k("9fb4b2", G_BOIS), Vector3(px, y + .08, .5), Vector3(mw, .03, 1.0), Basis(Vector3.RIGHT, .16))
		_boite(c, fer, Vector3(px, y, 1.0), Vector3(mw + .04, .1, .04))
		for s in [-1.0, 1.0]:
			_boite(c, fer, Vector3(px + s * mw * .5, y + .08, .5), Vector3(.04, .06, 1.02), Basis(Vector3.RIGHT, .16))
			_boite(c, fer, Vector3(px + s * (mw * .5 - .1), y - .3, .3), Vector3(.03, .03, .8), Basis(Vector3.RIGHT, .8))
		for i in 3:
			_boite(c, fer, Vector3(px - mw * .3 + i * mw * .3, y + .08, .5), Vector3(.025, .04, 1.0), Basis(Vector3.RIGHT, .16))

## Le mur d'un côté de la maison, pour la publicité et l'habillage : face, gauche ou droite.
## {o : coin bas-gauche vu du dehors, u : vers la droite, n : normale sortante, l, h, pignon, trous}.
static func mur_de(c: Chantier, cote: String) -> Dictionary:
	var S := c.S
	var tp := tan(deg_to_rad(S.pente))
	var y0: float = S.y0
	match cote:
		"gauche":
			return {"o": Vector3(-S.w * .5 - .005, y0, -S.d), "u": Vector3.BACK, "n": Vector3.LEFT, "l": S.d, "h": S.hc - y0,
				"pignon": S.d * .5 * tp if S.forme == "gouttereau" else 0.0, "trous": []}
		"droite":
			return {"o": Vector3(S.w * .5 + .005, y0, 0.0), "u": Vector3.FORWARD, "n": Vector3.RIGHT, "l": S.d, "h": S.hc - y0,
				"pignon": S.d * .5 * tp if S.forme == "gouttereau" else 0.0, "trous": []}
	var trous := []
	for e in S.compo:
		trous.append(Rect2(e.x - e.w * .5 + S.w * .5 - .2, e.y - y0 - .2, e.w + .4, e.h + .45))
	return {"o": Vector3(-S.w * .5, y0, S.avance + .005), "u": Vector3.RIGHT, "n": Vector3.BACK, "l": S.w, "h": S.hc - y0,
		"pignon": S.w * .5 * tp if S.forme == "pignon" else 0.0, "trous": trous}

## La publicité murale peinte, effacée : sur le pignon sur rue, ou sur un mur de côté (là où la voisine
## est plus basse). Un fond passé, un cadre, deux lignes de lettres pâles.
static func _publicite(c: Chantier) -> void:
	var S := c.S
	var cote: String = S.get("pub_cote", "")
	if cote == "": cote = "face" if S.forme == "pignon" else ("gauche" if _ch(c, .5) else "droite")
	var m := mur_de(c, cote)
	var gm := _genre_de(S.mur_pignon)
	if gm not in [G_ENDUIT, G_TAILLE, G_MOELLON]: gm = G_ENDUIT
	var textes: Array = _p(c, PUBLICITES)
	var l: float = m.l
	var pw := minf(l * .86, 7.2)
	var ph := pw * .3
	var v0: float = m.h - ph - .4 if cote != "face" else maxf(m.h - ph * .55, m.h - .8)
	if cote == "face" and S.get("gerbiere_pignon", false): v0 = m.h - ph - .35
	if cote == "face": pw = minf(pw, S.w * .62)
	var fond_c := Color(str(S.mur_pignon).split(":")[0]).lerp(Color(_p(c, ["b27a46", "9a5a48", "6f8590", "6a7a5c", "a8823e"])), .42)
	var u: Vector3 = m.u
	var n: Vector3 = m.n
	var centre: Vector3 = m.o + u * l * .5 + Vector3.UP * (v0 + ph * .5) + n * .006
	var b := Basis(u, Vector3.UP, n)
	_boite(c, k(fond_c.to_html(false), gm), centre, Vector3(pw, ph, .004), b, 16)
	var cadre := fond_c.lerp(Color("e8dcc0"), .35)
	for s in [-1.0, 1.0]:
		_boite(c, k(cadre.to_html(false), gm), centre + Vector3.UP * s * (ph * .5 - .08) + n * .002, Vector3(pw - .1, .05, .004), b, 16)
	var lettre := fond_c.lerp(Color("eee4c8"), .55)
	var ry := atan2(n.x, n.z)
	var t1: String = textes[0]
	var h1 := minf(ph * .36, pw / maxf(6.0, t1.length()) * 1.25)
	_texte(c, k(lettre.to_html(false), gm), t1, centre + Vector3.UP * ph * .1 + n * .004, h1, ry)
	var t2: String = textes[1]
	_texte(c, k(lettre.lerp(fond_c, .25).to_html(false), gm), t2, centre - Vector3.UP * ph * .25 + n * .004, minf(ph * .14, pw / maxf(8.0, t2.length()) * 1.3), ry)
	# les lettres s'en vont avec l'enduit : quelques éclats du mur par-dessus
	for i in c.rng.randi_range(2, 5):
		var p: Vector3 = centre + u * _r(c, -pw * .45, pw * .45) + Vector3.UP * _r(c, -ph * .4, ph * .4) + n * .008
		_boite(c, k(str(S.mur_pignon).split(":")[0], gm), p, Vector3(_r(c, .2, .6), _r(c, .12, .3), .003), b, 16)


# --- la maison --------------------------------------------------------------------------------------

## La maison composée d'un type (TYPES) et d'une graine, façade vers +Z avant rotation, origine au pied de
## la façade au milieu, posée à p.y. options : w, d, niveaux, quartier (cite, basse, quai, montee),
## porte (x local ou gauche / centre / droite), vegetal (true, false, un nom ou une liste : vigne, lierre,
## treille, glycine, rosier, jardinieres, pots, herbes, figuier), vigne_mur (face, gauche, droite),
## lumiere (part des fenêtres allumées), pente (dénivelé sous la façade, de gauche à droite), ry,
## histoire (liste de traces imposées, ou false), pub_cote, flanc (vigneron : chute derrière).
## Métadonnées du nœud rendu : type, graine, w, d, faite, porte (seuil de la porte principale, local).
static func maison(r: Node3D, p: Vector3, type: String, graine: int, options := {}) -> Node3D:
	if type not in TYPES: type = "quai"
	var g := A.groupe(r, "Maison_%s_%d" % [type, graine], p, float(options.get("ry", 0.0)))
	var c := Chantier.new()
	var germe := absi(graine * 7919 + type.hash() % 100003)
	c.rng.seed = germe
	_plan(c, type, options)
	# sur la pente, la porte principale va du côté haut (sauf si on l'a placée)
	var pente: float = options.get("pente", 0.0)
	if absf(pente) > .35 and not options.has("porte") and c.S.has("porte_x") and signf(float(c.S.porte_x)) * signf(pente) < 0.0 and absf(float(c.S.porte_x)) > .3:
		var o2 := options.duplicate()
		o2["_cote"] = -float(c.S.cote)
		c = Chantier.new()
		c.rng.seed = germe
		_plan(c, type, o2)
		options = o2
	var corps := g
	if c.S.has("w_at"):
		# la façade entière (maison et annexe) est centrée sur l'origine
		corps = A.groupe(g, "Corps", Vector3(-float(c.S.atelier.cote) * c.S.w_at * .5, 0, 0))
	c.g = corps
	var S := c.S
	S.graine = graine
	_corps(c)
	_toit(c)
	_egout(c)
	_extras(c)
	_ouvrir(c)
	_couronner(c)
	_arriere(c)
	_histoire(c)
	_vegetal(c, options)
	livrer(c, false)
	A.fusionner(g)
	g.set_meta("type", type)
	g.set_meta("graine", graine)
	g.set_meta("w", float(S.get("w_tot", S.w)))
	g.set_meta("d", float(S.d))
	g.set_meta("faite", float(S.get("faite", S.hc)))
	g.set_meta("vegetal", S.get("vegetal", []))
	g.set_meta("traces", S.traces)
	var dx: float = corps.position.x if corps != g else 0.0  # (le décalage du corps quand un atelier est accolé ; sinon rien)
	if S.has("porte_x"): g.set_meta("porte", Vector3(float(S.porte_x) + dx, float(S.get("porte_y", S.y0)), 0))
	return g


# --- l'habillage végétal --------------------------------------------------------------------------
# Des petites masses de feuillage (six triangles chacune, un dôme aplati contre le mur), toutes dans un
# seul maillage par maison, la couleur dans les sommets (feuillage.gdshader). Chaque fonction reçoit un
# nœud (elle y pose son propre maillage) ou le chantier d'une maison.

static func _chantier_de(r: Object, graine: int) -> Chantier:
	if r is Chantier: return r
	return chantier(r as Node3D, graine)

static func _fin(r: Object, c: Chantier) -> void:
	if not (r is Chantier): livrer(c, false)

## Une masse de feuillage : une rosette de cinq feuilles (un triangle chacune, à jours), de rayon ru × rv
## dans le plan (u, v), soulevée de prof vers n ; chaque feuille a sa nuance et sa normale.
static func _masse(c: Chantier, ce: Vector3, u: Vector3, v: Vector3, n: Vector3, ru: float, rv: float, prof: float, col: Color, souffle := .2) -> void:
	if c.feuil == null:
		c.feuil = SurfaceTool.new()
		c.feuil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st := c.feuil
	var a0 := c.rng.randf() * TAU
	for i in 5:
		# une feuille : un large coin depuis le cœur de la masse, qui chevauche ses voisines
		var a := a0 + TAU * i / 5.0 + c.rng.randf_range(-.3, .3)
		var ouv := c.rng.randf_range(.62, .95)
		var p1 := ce + u * cos(a - ouv) * ru * c.rng.randf_range(.7, 1.15) + v * sin(a - ouv) * rv * c.rng.randf_range(.7, 1.15) + n * c.rng.randf_range(0.0, prof * .4)
		var p2 := ce + u * cos(a + ouv) * ru * c.rng.randf_range(.7, 1.15) + v * sin(a + ouv) * rv * c.rng.randf_range(.7, 1.15) + n * c.rng.randf_range(0.0, prof * .4)
		var base := ce + (u * cos(a) * ru + v * sin(a) * rv) * c.rng.randf_range(-.2, .05) + n * prof * c.rng.randf_range(.6, 1.0)
		var nn := (n + (u * cos(a) + v * sin(a)) * c.rng.randf_range(.2, .8)).normalized()
		var tc := Color.from_hsv(fposmod(col.h + c.rng.randf_range(-.018, .018), 1.0), clampf(col.s * c.rng.randf_range(.88, 1.08), 0.0, 1.0), clampf(col.v * c.rng.randf_range(.82, 1.15), 0.0, 1.0))
		var sombre := tc.darkened(.25)
		st.set_normal(nn)
		st.set_color(Color(sombre.r, sombre.g, sombre.b, souffle * .5))
		st.add_vertex(base)
		st.set_color(Color(tc.r, tc.g, tc.b, souffle))
		st.add_vertex(p1)
		st.add_vertex(p2)

## Un tapis de feuillage sur un mur (vigne vierge, lierre) : des masses tirées sur une grille, gardées là
## où un bruit, la distance aux pieds et la hauteur le veulent ; les bords en petites masses, des vrilles.
static func _tapis(c: Chantier, mur: Dictionary, graine: int, couverture: float, pas: float, teinte: Callable, biais_bas: float, options: Dictionary) -> void:
	var o: Vector3 = mur.o
	var u: Vector3 = mur.u
	var n: Vector3 = mur.n
	var v := Vector3.UP
	var l: float = mur.l
	var h: float = minf(float(mur.h), float(options.get("hauteur", 99.0)))
	var pg: float = mur.get("pignon", 0.0) if h >= float(mur.h) - .01 else 0.0
	var trous: Array = mur.get("trous", [])
	var nz := FastNoiseLite.new()
	nz.seed = graine
	nz.frequency = .3
	nz.fractal_octaves = 3
	var racines: Array = options.get("racines", [])
	if racines.is_empty():
		racines.append(l * c.rng.randf_range(.12, .4) if c.rng.randf() < .5 else l * c.rng.randf_range(.6, .88))
		if c.rng.randf() < .4: racines.append(l * c.rng.randf_range(.1, .9))
	var htot := h + pg
	var cases := []
	var nu := maxi(1, int(l / pas))
	var nv := maxi(1, int(htot / pas))
	for i in nu:
		for j in nv:
			var uu := (i + .5 + c.rng.randf_range(-.3, .3)) * l / nu
			var vv := (j + .5 + c.rng.randf_range(-.3, .3)) * pas
			var hmax := h + pg * (1.0 - absf(uu / l * 2.0 - 1.0))
			if vv > hmax - pas * .35: continue
			var dans := false
			for t in trous:
				if (t as Rect2).has_point(Vector2(uu, vv)): dans = true
			if dans: continue
			var dr := 99.0
			for rx in racines: dr = minf(dr, absf(uu - float(rx)) / l)
			var f := nz.get_noise_2d(uu * 1.3, vv * 1.3) * .9 + (1.0 - dr * 1.8) * .6 - (vv / htot) * biais_bas
			cases.append([f, uu, vv, i, j])
	cases.sort_custom(func(a, b): return a[0] > b[0])
	var nb := mini(int(cases.size() * couverture), int(options.get("masses", 160)))
	var garde := {}
	for i in nb: garde[Vector2i(cases[i][3], cases[i][4])] = cases[i]
	for cle in garde:
		var cs: Array = garde[cle]
		var vois := 0
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if garde.has(cle + dd): vois += 1
		var bord := vois < 4
		var ru := pas * (c.rng.randf_range(.5, .75) if bord else c.rng.randf_range(.72, .98))
		var t: float = cs[2] / htot
		var p := o + u * float(cs[1]) + v * float(cs[2]) + n * .025
		_masse(c, p, u, v, n, ru, ru * c.rng.randf_range(.8, 1.1), c.rng.randf_range(.1, .2), teinte.call(t, c.rng.randf()), .22)
		if bord and vois <= 2 and c.rng.randf() < .35:
			# une vrille qui part en avant de la masse
			var q := p
			var dir := Vector3(c.rng.randf_range(-.6, .6), 1.0, 0)
			for k2 in c.rng.randi_range(2, 4):
				q += u * dir.x * pas * .6 + v * pas * .55
				if (q - o).dot(v) > htot - .1: break
				_masse(c, q, u, v, n, pas * .3, pas * .3, .07, teinte.call(t + .1, c.rng.randf()), .3)
	# les pieds : des troncs tors qui sortent du sol
	for rx in racines:
		var pied := o + u * float(rx) + n * .06
		var a := pied
		for s in 3:
			var b := a + v * .45 + u * c.rng.randf_range(-.12, .12)
			_boite(c, k("4a3628", G_BOIS), (a + b) * .5, Vector3(.05, a.distance_to(b) + .04, .05), Basis(Quaternion(Vector3.UP, (b - a).normalized())), 63 - 4 - 8)
			a = b

static func _rouge_octobre(t: float, x: float) -> Color:
	if x < .05: return Color("8a8a3c")
	if x < .1: return Color("e8b040")
	var bas := Color("a82a32").lerp(Color("bc3030"), x)
	var mil := Color("cc3a28").lerp(Color("dc4c2c"), x)
	var haut := Color("e4622e").lerp(Color("ec8034"), x)
	return bas.lerp(mil, clampf(t * 2.0, 0.0, 1.0)) if t < .5 else mil.lerp(haut, clampf(t * 2.0 - 1.0, 0.0, 1.0))

static func _vert_lierre(t: float, x: float) -> Color:
	if x < .1: return Color("6a8a42")
	return Color("34502a").lerp(Color("4a6a36"), x).lerp(Color("3e5a30"), t * .4)

## La vigne vierge d'octobre, rouge, qui mange une partie d'un mur ou d'un pignon (masses irrégulières).
## mur : {o, u, n, l, h, pignon, trous} (voir mur_de) ; couverture : la part du mur couverte.
static func vigne_vierge(r: Object, mur: Dictionary, graine := 0, couverture := .55, options := {}) -> void:
	var c := _chantier_de(r, graine)
	_tapis(c, mur, graine, couverture, float(options.get("pas", .34)), _rouge_octobre, .4, options)
	_fin(r, c)

## Le lierre sombre d'un mur de jardin ou du bas d'un pignon.
static func lierre(r: Object, mur: Dictionary, graine := 0, couverture := .5, options := {}) -> void:
	var c := _chantier_de(r, graine)
	_tapis(c, mur, graine, couverture, float(options.get("pas", .3)), _vert_lierre, .9, options)
	_fin(r, c)

## Une treille de vigne aux feuilles jaunes : un pied tors, un fil de fer porté par des consoles, les
## feuilles en bande le long du fil, quelques grappes oubliées. a, b : le fil (contre le mur, normale n).
static func treille(r: Object, a: Vector3, b: Vector3, graine := 0, options := {}) -> void:
	var c := _chantier_de(r, graine)
	var n: Vector3 = options.get("n", Vector3.BACK)
	var sol: float = options.get("sol", a.y - 2.5)
	var avant := n * .32
	var fer := k("2c2a26", G_BOIS)
	var l := a.distance_to(b)
	var u := (b - a).normalized()
	_boite(c, fer, (a + b) * .5 + avant, Vector3(.025, .025, .025) + u.abs() * l, Basis(), 63)
	var nb := maxi(2, int(l / 1.6) + 1)
	for i in nb:
		var p := a.lerp(b, float(i) / (nb - 1))
		_boite(c, fer, p + avant * .5, Vector3(.025, .025, .025) + n.abs() * .34, Basis(), 63)
		_boite(c, fer, p + avant * .5 - Vector3(0, .17, 0), Vector3(.02, .38, .02) + n.abs() * .0, Basis(Vector3(-n.z, 0, n.x).normalized() if n.length() > 0 else Vector3.RIGHT, .7), 63)
	# le pied, tors, qui monte au fil
	var pied: Vector3 = options.get("pied", a + avant * .4 + u * .3)
	var q := Vector3(pied.x, sol, pied.z)
	var cible := Vector3(pied.x, a.y, pied.z) + avant * .6
	for s in 4:
		var t := float(s + 1) / 4.0
		var nq := q.lerp(cible, 1.0 / (4 - s)) + u * c.rng.randf_range(-.12, .12)
		if s == 3: nq = cible
		_boite(c, k("5a4430", G_BOIS), (q + nq) * .5, Vector3(.07, q.distance_to(nq) + .05, .07), Basis(Quaternion(Vector3.UP, (nq - q).normalized())), 63 - 4 - 8)
		q = nq
	var jaunes := [Color("cfa83c"), Color("c09030"), Color("d8b84e"), Color("a8822c"), Color("9c9a3c"), Color("b8742a")]
	var x := 0.0
	var long_f: float = l * float(options.get("part", .9))
	while x < long_f:
		var p := a + u * x + avant + n * c.rng.randf_range(-.15, .2)
		for k2 in c.rng.randi_range(1, 2):
			var ce := p + Vector3(0, c.rng.randf_range(-.25, .3), 0) + u * c.rng.randf_range(-.1, .1)
			var ru := c.rng.randf_range(.22, .36)
			_masse(c, ce, u, Vector3.UP, (n + Vector3.UP * .5).normalized(), ru, ru * .8, .14, jaunes[c.rng.randi() % jaunes.size()], .35)
		if c.rng.randf() < .18:
			_masse(c, p - Vector3(0, .28, 0) + n * .1, u, Vector3.UP, n, .07, .12, .06, Color("3e2440"), .4)
		x += c.rng.randf_range(.24, .38)
	_fin(r, c)

## Une glycine sur une marquise ou au-dessus d'une porte : un tronc tors, des feuilles qui jaunissent,
## qui retombent. a, b : la branche horizontale (contre le mur), pied : où le tronc sort du sol.
static func glycine(r: Object, a: Vector3, b: Vector3, pied: Vector3, graine := 0, options := {}) -> void:
	var c := _chantier_de(r, graine)
	var n: Vector3 = options.get("n", Vector3.BACK)
	var q := pied
	var haut := Vector3(pied.x, a.y, pied.z)
	for s in 5:
		var nq := q.lerp(haut, 1.0 / (5 - s)) + Vector3(c.rng.randf_range(-.08, .08), 0, 0)
		if s == 4: nq = haut
		_boite(c, k("8e7e68", G_BOIS), (q + nq) * .5, Vector3(.075, q.distance_to(nq) + .05, .075), Basis(Quaternion(Vector3.UP, (nq - q).normalized())), 63 - 4 - 8)
		q = nq
	for e in [a, b]:
		_boite(c, k("8e7e68", G_BOIS), (haut + e) * .5 + n * .1, Vector3(haut.distance_to(e), .07, .07), Basis(Vector3.BACK, atan2(e.y - haut.y, e.x - haut.x)), 63)
	var teintes := [Color("b5a845"), Color("c4b25a"), Color("9c9a3c"), Color("a89a40"), Color("6e7a3a"), Color("d0b85a")]
	var u := (b - a).normalized()
	var l := a.distance_to(b)
	var x := 0.0
	while x < l:
		var p := a + u * x + n * c.rng.randf_range(.12, .35)
		var ce := p + Vector3(0, c.rng.randf_range(-.1, .25), 0)
		var ru := c.rng.randf_range(.22, .34)
		_masse(c, ce, u, Vector3.UP, n, ru, ru * .9, .16, teintes[c.rng.randi() % teintes.size()], .4)
		if c.rng.randf() < .6:
			# ce qui retombe
			var hh := c.rng.randf_range(.25, .6)
			_masse(c, ce - Vector3(0, hh, 0) + n * .05, u, Vector3.UP, n, .12, hh * .6, .08, teintes[c.rng.randi() % teintes.size()].darkened(.05), .5)
		x += c.rng.randf_range(.2, .32)
	_fin(r, c)

## Un rosier remontant contre une porte : des tiges en éventail, des feuilles, quelques roses d'octobre.
static func rosier(r: Object, pied: Vector3, graine := 0, hauteur := 2.2, options := {}) -> void:
	var c := _chantier_de(r, graine)
	var n: Vector3 = options.get("n", Vector3.BACK)
	var u := Vector3(n.z, 0, -n.x)
	var tiges := c.rng.randi_range(3, 5)
	var verts := [Color("3c5a2c"), Color("46602f"), Color("2f4a26"), Color("52683a")]
	var fleurs := [Color("d88a9a"), Color("b02a3a"), Color("e8c0c8"), Color("c84a5a")]
	for i in tiges:
		var dx := (float(i) / maxf(1, tiges - 1) - .5) * c.rng.randf_range(.8, 1.4)
		var bout := pied + u * dx + Vector3.UP * hauteur * c.rng.randf_range(.65, 1.0) + n * .05
		_boite(c, k("4e5a32", G_BOIS), (pied + bout) * .5, Vector3(.03, pied.distance_to(bout), .03), Basis(Quaternion(Vector3.UP, (bout - pied).normalized())), 63 - 4 - 8)
		var m := c.rng.randi_range(4, 6)
		for j in m:
			var t := (j + 1.0) / m
			var p := pied.lerp(bout, t) + n * c.rng.randf_range(.06, .18) + u * c.rng.randf_range(-.12, .12)
			var ru := c.rng.randf_range(.14, .22) * (1.2 - t * .4)
			_masse(c, p, u, Vector3.UP, n, ru, ru, .1, verts[c.rng.randi() % verts.size()], .3)
			if c.rng.randf() < .3:
				_masse(c, p + n * .12 + Vector3.UP * .05, u, Vector3.UP, n, .06, .06, .05, fleurs[c.rng.randi() % fleurs.size()], .3)
	_fin(r, c)

## Des jardinières de géraniums sous des fenêtres : fenetres = [[x, y_appui, largeur, z_mur], …] (mur +Z).
static func jardinieres(r: Object, fenetres: Array, graine := 0, options := {}) -> void:
	var c := _chantier_de(r, graine)
	var caisse: String = options.get("caisse", k(_p(c, ["a85a3a", "5f7380", "3f5a4a", "8a6a4a"]), G_BOIS))
	var fleurs := [Color("c8282a"), Color("e04050"), Color("d84a7a"), Color("e86a5a"), Color("f0eadc")]
	for f in fenetres:
		var x: float = f[0]
		var y: float = f[1]
		var w: float = f[2]
		var z: float = f[3]
		_boite(c, caisse, Vector3(x, y + .1, z + .2), Vector3(w + .1, .2, .2))
		for s in [-1.0, 1.0]:
			_boite(c, k("2c2a26", G_BOIS), Vector3(x + s * w * .4, y - .02, z + .12), Vector3(.025, .025, .24))
		var nb := int(w / .16) + 1
		var fleur: Color = fleurs[c.rng.randi() % fleurs.size()]
		for i in nb:
			var p := Vector3(x - w * .5 + w * (i + .5) / nb, y + .26, z + .22 + c.rng.randf_range(-.05, .05))
			_masse(c, p, Vector3.RIGHT, Vector3.UP, (Vector3.BACK + Vector3.UP).normalized(), .12, .1, .1, Color("3e5e2e").lerp(Color("4f6e34"), c.rng.randf()), .3)
			if c.rng.randf() < .7:
				_masse(c, p + Vector3(c.rng.randf_range(-.05, .05), .1, .06), Vector3.RIGHT, Vector3.UP, Vector3.BACK, .055, .05, .05, fleur.lightened(c.rng.randf_range(-.1, .1)), .3)
			if c.rng.randf() < .35:
				_masse(c, p + Vector3(0, -.28, .08), Vector3.RIGHT, Vector3.UP, Vector3.BACK, .08, .14, .06, Color("456432"), .4)
	_fin(r, c)

## Des pots de terre cuite (sur des marches, devant une porte) avec ce qui y pousse encore.
static func pots(r: Object, positions: Array, graine := 0, options := {}) -> void:
	var c := _chantier_de(r, graine)
	var genre: int = options.get("genre", G_BOIS)
	for p in positions:
		var rr := c.rng.randf_range(.12, .2)
		var hh := rr * c.rng.randf_range(1.2, 1.6)
		_fut(c, k(_p(c, ["a8603e", "b46a46", "9a5838"]), genre), p, rr * .8, 0.0, hh, 6, c.rng.randf(), false, rr)
		_fut(c, k("b87250", genre), p, rr + .015, hh - .04, hh + .01, 6)
		var plante: Color = [Color("3e5e2e"), Color("4a6a32"), Color("6a7a3a"), Color("2f4a28")][c.rng.randi() % 4]
		for i in c.rng.randi_range(1, 3):
			var q: Vector3 = p + Vector3(c.rng.randf_range(-.05, .05), hh + rr * .5, c.rng.randf_range(-.05, .05))
			_masse(c, q, Vector3.RIGHT, Vector3.BACK, Vector3.UP, rr * 1.1, rr * 1.1, rr * 1.4, plante, .4)
		if c.rng.randf() < .4:
			_masse(c, p + Vector3(0, hh + rr * 1.2, .05), Vector3.RIGHT, Vector3.UP, Vector3.BACK, .06, .06, .05, [Color("d84a5a"), Color("e8d050"), Color("c86a2a")][c.rng.randi() % 3], .4)
		if r is Chantier: A.collision_cyl((r as Chantier).g, p + Vector3(0, hh * .5, 0), rr, hh)
	_fin(r, c)

## Des herbes au pied d'un mur, de a à b (au sol), normale n : touffes vertes et sèches, irrégulières.
static func herbes_pied_de_mur(r: Object, a: Vector3, b: Vector3, n: Vector3, graine := 0, densite := 1.0) -> void:
	var c := _chantier_de(r, graine)
	var u := (b - a).normalized()
	var l := a.distance_to(b)
	var teintes := [Color("6a7a3a"), Color("7a8a40"), Color("8a8a4a"), Color("5a6a30"), Color("a09a5a"), Color("b0a060")]
	var x := c.rng.randf_range(0.0, .5)
	while x < l:
		var p := a.lerp(b, x / l) + n * c.rng.randf_range(.03, .14)
		for i in c.rng.randi_range(1, 3):
			var ru := c.rng.randf_range(.06, .16)
			_masse(c, p + u * c.rng.randf_range(-.1, .1) + Vector3(0, ru * .4, 0), u, Vector3.UP, n, ru, ru * c.rng.randf_range(.6, 1.4), .06, teintes[c.rng.randi() % teintes.size()], .5)
		x += c.rng.randf_range(.25, 1.1) / maxf(.2, densite)
	_fin(r, c)

## Un figuier dans l'angle d'une cour : un tronc gris, de larges masses vert sombre.
static func figuier(r: Object, p: Vector3, graine := 0, taille := 1.0) -> void:
	var c := _chantier_de(r, graine)
	for i in 3:
		var a := TAU * i / 3.0 + c.rng.randf()
		var b := p + Vector3(cos(a) * .5, 1.4, sin(a) * .5) * taille
		_boite(c, k("8a8478", G_BOIS), (p + b) * .5, Vector3(.1, p.distance_to(b), .1) * Vector3(taille, 1, taille), Basis(Quaternion(Vector3.UP, (b - p).normalized())), 63 - 4 - 8)
	for i in 9:
		var a := c.rng.randf() * TAU
		var ce := p + Vector3(cos(a) * c.rng.randf_range(.2, .9), c.rng.randf_range(1.3, 2.4), sin(a) * c.rng.randf_range(.2, .9)) * taille
		var nn := (ce - p - Vector3(0, 1.2, 0)).normalized()
		var tu := nn.cross(Vector3.UP).normalized() if absf(nn.y) < .95 else Vector3.RIGHT
		_masse(c, ce, tu, nn.cross(tu).normalized(), nn, .55 * taille, .5 * taille, .35 * taille, Color("3a5a2a").lerp(Color("5a7a34"), c.rng.randf()), .4)
	_fin(r, c)

## L'habillage d'une maison : une sur trois environ porte un habillage marquant (plus sur la montée), le
## vigneron a toujours sa treille ; des herbes au pied des vieux murs, des pots devant les seuils.
static func _vegetal(c: Chantier, o: Dictionary) -> void:
	var S := c.S
	var v = o.get("vegetal", null)
	var genres := []
	if v is bool and not v:
		S.vegetal = []
		return
	if v is String: genres = [v]
	elif v is Array: genres = (v as Array).duplicate()
	else:
		var p_hab: float = {"cite": .3, "montee": .5, "basse": .3, "quai": .42}.get(S.q, .33)
		if S.type == "vigneron": genres.append("treille")
		if (v is bool and v) or c.rng.randf() < p_hab:
			var poids := {"vigne": 3.0, "lierre": 1.4, "glycine": 1.0, "rosier": 2.0, "jardinieres": 2.0, "treille": .6}
			if S.type in ["notable", "ouvriere", "quai"]: poids.glycine = 2.0
			if S.type in ["echoppe", "forte", "notable", "grange"]: poids.treille = 0.0
			if S.type in ["grange", "forte"]: poids.jardinieres = 0.0
			if S.type in ["grange", "forte", "medievale"]: poids.lierre = 2.6
			for tirage in (2 if c.rng.randf() < .3 else 1):
				var tot := 0.0
				for kk in poids: tot += poids[kk]
				var x := c.rng.randf() * tot
				for kk in poids:
					x -= poids[kk]
					if x <= 0.0:
						if kk not in genres: genres.append(kk)
						poids[kk] = 0.0
						break
		if S.vieux and c.rng.randf() < .55: genres.append("herbes")
		if (S.type in ["balet", "quai"] and c.rng.randf() < .65) or c.rng.randf() < .12: genres.append("pots")
	# un seul tapis de feuillage par maison, et moins de vigne là où il y a déjà une treille
	if genres.has("vigne") and genres.has("lierre"): genres.erase("lierre")
	S.vegetal = genres
	var graine: int = int(S.graine) * 31 + 7
	var masses: int = o.get("masses", 130 if genres.has("treille") or genres.has("glycine") else (150 if S.type in ["notable", "forte"] else 200))
	var px: float = S.get("porte_x", 0.0)
	var pw: float = S.get("porte_w", 1.0)
	var ph: float = S.get("porte_haut", S.y0 + 2.2)
	for gv in genres:
		match gv:
			"vigne":
				var cote: String = o.get("vigne_mur", "face" if S.forme == "pignon" else ("gauche" if c.rng.randf() < .5 else "droite"))
				var m := mur_de(c, cote)
				vigne_vierge(c, m, graine, float(o.get("couverture", .5 if cote == "face" else .62)), {"masses": masses})
			"lierre":
				var cote: String = o.get("lierre_mur", "gauche" if c.rng.randf() < .5 else "droite")
				var m := mur_de(c, cote)
				lierre(c, m, graine + 3, .55, {"hauteur": c.rng.randf_range(2.5, 5.5), "masses": 120})
			"treille":
				if S.etages.size() < 2 and S.type != "quai": continue
				var y: float = S.etages[1].y + .1 if S.etages.size() > 1 else S.hc - .45
				var x0: float = -S.w * .5 + .4
				var x1: float = S.w * .5 - .4
				var pied_x := x1 - .2 if px < 0 else x0 + .2
				treille(c, Vector3(x0, y, 0), Vector3(x1, y, 0), graine + 5, {"sol": _sol(S, pied_x), "pied": Vector3(pied_x, 0, .12), "part": c.rng.randf_range(.7, 1.0)})
			"glycine":
				var cote := 1.0 if px < S.w * .25 else -1.0
				var pied := Vector3(px + cote * (pw * .5 + .35), _sol(S, px + cote * (pw * .5 + .35)), .14)
				var y := ph + .45
				glycine(c, Vector3(maxf(-S.w * .5 + .3, px - 2.0), y, 0), Vector3(minf(S.w * .5 - .3, px + 2.0), y, 0), pied, graine + 7)
			"rosier":
				var cote := -1.0 if c.rng.randf() < .5 else 1.0
				var x := clampf(px + cote * (pw * .5 + .4), -S.w * .5 + .3, S.w * .5 - .3)
				rosier(c, Vector3(x, _sol(S, x), .08), graine + 9, c.rng.randf_range(1.8, 2.5))
			"jardinieres":
				var fh: Array = S.get("fenetres_hautes", [])
				if fh.is_empty(): continue
				fh = fh.duplicate()
				fh.shuffle()
				jardinieres(c, fh.slice(0, c.rng.randi_range(1, mini(3, fh.size()))), graine + 11)
			"pots":
				var pos := []
				if S.has("balet"):
					var b: Dictionary = S.balet
					var sol0 := _sol(S, b.x_dep)
					for i in c.rng.randi_range(2, 4):
						var t := c.rng.randf_range(.15, .95)
						pos.append(Vector3(lerpf(b.x_dep, b.x_haut, t), lerpf(sol0, b.y, t) + .02, .25))
				else:
					for i in c.rng.randi_range(2, 3):
						var x := px + (pw * .5 + .3 + i * .35) * (1.0 if i % 2 == 0 else -1.0)
						pos.append(Vector3(x, _sol(S, x), .35 + c.rng.randf_range(0, .2)))
				pots(c, pos, graine + 13, {"genre": S.get("genre_terre", G_BOIS)})
			"herbes":
				herbes_pied_de_mur(c, Vector3(-S.w * .5, S.sg, .02), Vector3(S.w * .5, S.sd, .02), Vector3.BACK, graine + 17, .8)
				if str(S.corniche).begins_with("genoise"):
					herbes_pied_de_mur(c, Vector3(-S.w * .5, S.hc - .05, .2), Vector3(S.w * .5, S.hc - .05, .2), Vector3.UP, graine + 19, .25)
			"figuier":
				figuier(c, Vector3(S.cote * (S.w * .5 + 1.2), _sol(S, S.cote * S.w * .5), -1.0), graine + 23)
