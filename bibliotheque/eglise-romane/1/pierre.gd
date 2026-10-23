extends RefCounted
## Les primitives de pierre de Chauvigny 0.2.2 (Le duke, MIT ; adaptées de l'atelier de Civaux, MIT) :
## la palette et la matière commune (matieres.gdshader), les blocs, cylindres, arcs, toits, pignons, dalles,
## extrusions et révolutions, les fenêtres et portes, les tours, donjons, murailles et créneaux, les murs
## ruinés, rochers, voûtes, portes de ville, escaliers, rampes et soutènements aux collisions justes, les
## arbres, buissons et lanternes, la fusion par genre de matière. Unités en mètres ; un bâtiment regarde
## vers +Z avant rotation. Sans le terrain de Chauvigny : ce qui suit un sol le reçoit de l'appelant.
const SURFACE := preload("res://bibliotheque/eglise-romane/1/matieres.gdshader")
const FEUILLAGE := preload("res://bibliotheque/eglise-romane/1/feuillage.gdshader")
const ECHELLE_FIGURANT := 2.6

const PALETTE := {
	# la pierre de Chauvigny : calcaire clair et chaud ; ruine et falaise plus grises
	"calcaire": "d6cbae", "calcaire_clair": "e2d8bd", "calcaire_sombre": "c4b793", "pierre": "b9ad92", "mortier": "8c8571",
	"taille": "dcd1b5", "ruine": "b4a88d", "ruine_sombre": "9d937d", "moellon": "ad9f84", "falaise": "bfb49a", "granit": "3b3d42",
	# enduits
	"enduit": "dccfb4", "enduit_sable": "cdb995", "enduit_rose": "cfb8a6", "enduit_blanc": "e6e0cf", "enduit_gris": "c5c0b4",
	# toitures
	"tuile": "a56b4f", "tuile_sombre": "8f5a46", "tuile_claire": "b8805f", "ardoise": "4a5560", "zinc": "7f8784", "tole": "9aa0a0",
	# bois et métal
	"bois": "74543f", "chene": "72543e", "bois_use": "8a7861", "bois_sombre": "534638", "bois_peint": "5f7380", "bois_clair": "b48a5a",
	"vert_bouteille": "3f5a4a", "rouge_sombre": "7a3b32",
	"fer": "2a2c2e", "acier": "8a9196", "galva": "9ea5a8", "rouille": "8a5a3a", "laiton": "b89c61", "cuivre": "b1845b",
	# béton et sols
	"beton": "b5b0a3", "beton_sombre": "9d9a90", "goudron": "4a4b4a", "goudron_clair": "6a6b68",
	"pave": "b8ac92", "gravier": "b9b09c", "terre": "8b7956", "herbe": "7a8a5d", "herbe_seche": "a6a06c",
	# verre, toile, signalétique
	"verre": "789598", "verre_nuit": "284851", "toile": "e7dcbf", "toile_verte": "5f7a5a", "toile_rouge": "9a3b32",
	"blanc": "f2efe6", "noir": "202224", "rouge": "984e3f", "bleu": "477080", "vert": "596f59",
	"creme": "e8dec7", "sombre": "283e3e", "jaune": "d9b73a", "neon": "f0b94a", "bordeaux": "8a2e2e",
	# vivant et matières
	"feuillage_sombre": "2f4a2a", "tronc": "4e4236", "tronc_clair": "8a8070", "eau": "2a4e48", "mousse": "6a7a4c",
	"vigne": "9c5a33", "buis": "2f4a2a", "plume": "5a3f2b", "porcelaine": "eef0ee", "biscuit": "e6dcc8",
}
static var _matieres: Dictionary = {}

## Le genre de surface d'une teinte de la palette (voir matieres.gdshader).
static func _genre(nom: String) -> int:
	if nom in ["calcaire", "calcaire_clair", "calcaire_sombre", "pierre", "mortier", "granit"]: return 1
	if nom.begins_with("enduit"): return 2
	if nom.begins_with("tuile"): return 3
	if nom in ["bois", "chene", "bois_use", "bois_sombre", "bois_peint", "bois_clair", "tronc", "tronc_clair", "vert_bouteille", "rouge_sombre"]: return 4
	if nom == "pave": return 5
	if nom.begins_with("beton"): return 6
	if nom == "moellon": return 7
	if nom in ["zinc", "tole", "galva", "acier"]: return 8
	if nom == "ardoise": return 9
	if nom == "mousse": return 10
	if nom.begins_with("goudron"): return 12
	if nom in ["gravier", "terre"]: return 13
	if nom in ["ruine", "ruine_sombre", "falaise"]: return 14
	if nom == "taille": return 15
	return 0

## La matière d'une teinte de la palette (« calcaire »), d'une couleur (Color) ou d'un hexa (« a56b4f »).
static func mat(cle: Variant) -> Material:
	if cle is Material: return cle
	var nom := str(cle)
	if _matieres.has(nom): return _matieres[nom]
	var couleur: Color = cle if cle is Color else Color(PALETTE.get(nom, nom))
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("teinte", couleur)
	m.set_shader_parameter("genre", _genre(nom))
	var metal := nom in ["fer", "acier", "galva", "laiton", "cuivre", "zinc", "tole", "rouille"]
	m.set_shader_parameter("rugosite", .35 if metal or nom.begins_with("verre") else (.6 if nom == "granit" else .88))
	m.set_shader_parameter("metal", .6 if metal else 0.0)
	_matieres[nom] = m
	return m

## Une matière de verre ou de toile un peu transparente (StandardMaterial3D) : vitrines, serre, brume.
static func verre(couleur := Color(.62, .74, .75, .55)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = couleur
	m.roughness = .15
	m.metallic = .1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Une matière émissive simple (fenêtres allumées, enseignes, feux).
## Partagée entre tous ceux qui ont la même couleur et la même énergie, pour que la fusion les regroupe.
static var _lumieres: Dictionary = {}
static func lumiere(couleur: Color, energie := 1.6) -> StandardMaterial3D:
	var cle := "%s:%s" % [couleur.to_html(), energie]
	if _lumieres.has(cle): return _lumieres[cle]
	var m := StandardMaterial3D.new()
	_lumieres[cle] = m
	m.albedo_color = couleur
	m.emission_enabled = true
	m.emission = couleur
	m.emission_energy_multiplier = energie
	return m

static func groupe(r: Node3D, nom: String, p := Vector3.ZERO, ry := 0.0) -> Node3D:
	var g := Node3D.new()
	g.name = nom
	g.position = p
	g.rotation.y = ry
	r.add_child(g)
	return g

## Une boîte ; solide = avec collision. c : une teinte de la palette, une Color ou un Material.
static func bloc(r: Node3D, p: Vector3, taille: Vector3, c: Variant = "calcaire", solide := false, ry := 0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = taille
	n.mesh = mesh
	n.material_override = mat(c)
	n.position = p
	n.rotation.y = ry
	r.add_child(n)
	if solide: collision(r, p, taille, Vector3(0, ry, 0))
	return n

## Les collisions d'un groupe partagent un seul corps : une forme par obstacle, posée par son
## propriétaire de formes, sans nœud à elle (les troncs des bois en faisaient plus de huit mille).
static func corps(r: Node3D) -> StaticBody3D:
	if r.has_meta("corps"):
		var b = r.get_meta("corps")
		if is_instance_valid(b) and b.get_parent() == r:
			return b
	var nb := StaticBody3D.new()
	nb.name = "Collisions"
	r.add_child(nb)
	r.set_meta("corps", nb)
	return nb

static func _forme(r: Node3D, xf: Transform3D, s: Shape3D) -> StaticBody3D:
	var b := corps(r)
	var id := b.create_shape_owner(b)
	b.shape_owner_add_shape(id, s)
	b.shape_owner_set_transform(id, xf)
	return b

static func collision(r: Node3D, p: Vector3, taille: Vector3, rotation := Vector3.ZERO) -> StaticBody3D:
	var box := BoxShape3D.new()
	box.size = taille
	return _forme(r, Transform3D(Basis.from_euler(rotation), p), box)

## Une collision cylindrique (troncs, piliers, tours).
static func collision_cyl(r: Node3D, p: Vector3, rayon: float, hauteur: float) -> StaticBody3D:
	var s := CylinderShape3D.new()
	s.radius = rayon
	s.height = hauteur
	return _forme(r, Transform3D(Basis(), p), s)

static func cyl(r: Node3D, p: Vector3, rayon: float, hauteur: float, c: Variant = "calcaire", sommet := -1.0, segments := 24, solide := false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = rayon
	mesh.top_radius = rayon if sommet < 0 else sommet
	mesh.height = hauteur
	mesh.radial_segments = segments
	mesh.rings = 0
	n.mesh = mesh
	n.material_override = mat(c)
	n.position = p
	r.add_child(n)
	if solide: collision_cyl(r, p, maxf(rayon, sommet), hauteur)
	return n

static func boule(r: Node3D, p: Vector3, taille: Vector3, c: Variant = "calcaire", segments := 16) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = segments
	mesh.rings = maxi(4, segments / 2)
	n.mesh = mesh
	n.scale = taille
	n.position = p
	n.material_override = mat(c)
	r.add_child(n)
	return n

## Une barre entre deux points (poutres, câbles, rampes, montants).
static func barre(r: Node3D, a: Vector3, b: Vector3, rayon: float, c: Variant = "bois", segments := 10) -> MeshInstance3D:
	var n := cyl(r, (a + b) * .5, rayon, a.distance_to(b), c, -1, segments)
	var axe := (b - a).normalized()
	if absf(axe.dot(Vector3.UP)) < .9999:
		n.quaternion = Quaternion(Vector3.UP, axe)
	elif axe.y < 0:
		n.rotation.x = PI
	return n

## Un mur droit entre deux points au sol, de hauteur h, d'épaisseur e, posé à y.
static func mur(r: Node3D, a: Vector3, b: Vector3, h: float, e: float, c: Variant = "calcaire", solide := true) -> MeshInstance3D:
	var d := b - a
	var l := Vector2(d.x, d.z).length()
	var ry := atan2(d.x, d.z) + PI * .5
	return bloc(r, (a + b) * .5 + Vector3(0, h * .5, 0), Vector3(l, h, e), c, solide, ry)

## Un arc en plein cintre (ou en segment), dans le plan XY local, de rayon intérieur donné.
static func arc(r: Node3D, p: Vector3, rayon: float, epaisseur: float, profondeur: float, c: Variant = "calcaire", debut := 0.0, fin := PI, segments := 20) -> Node3D:
	var g := groupe(r, "Arc", p)
	for i in segments:
		var angle := lerpf(debut, fin, (float(i) + .5) / segments)
		var largeur := (rayon + epaisseur * .5) * (fin - debut) / segments * 1.015
		var voussoir := bloc(g, Vector3(cos(angle), sin(angle), 0) * (rayon + epaisseur * .5), Vector3(largeur, epaisseur, profondeur), c)
		voussoir.rotation.z = angle - PI / 2
	return g

## Un toit à deux pans (faîte le long de Z), posé à p (le bas des pans), largeur en X.
static func toit(r: Node3D, p: Vector3, largeur: float, profondeur: float, hauteur: float, c: Variant = "tuile", debord := .3) -> Node3D:
	var g := groupe(r, "Toit", p)
	var pente := atan2(hauteur, largeur * .5)
	for s in [-1.0, 1.0]:
		var pan := bloc(g, Vector3(s * largeur * .25, hauteur * .5, 0), Vector3(sqrt(largeur * largeur * .25 + hauteur * hauteur) + debord, .16, profondeur + debord * 1.5), c)
		pan.rotation.z = -s * pente
	bloc(g, Vector3(0, hauteur + .07, 0), Vector3(.22, .16, profondeur + debord * 1.6), c)
	return g

## Un toit à quatre pans (croupe), largeur w en X, profondeur d en Z, posé à y local, hauteur h.
static func croupe(r: Node3D, p: Vector3, w: float, d: float, h: float, c: Variant = "tuile", debord := .25) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := w * .5 + debord
	var z := d * .5 + debord
	var fa := maxf(.15, x - minf(z * .75, x * .8))
	var pts := [Vector3(-x, 0, -z), Vector3(x, 0, -z), Vector3(x, 0, z), Vector3(-x, 0, z), Vector3(-fa, h, 0), Vector3(fa, h, 0)]
	if d > w:
		fa = maxf(.15, z - minf(x * .75, z * .8))
		pts[4] = Vector3(0, h, -fa)
		pts[5] = Vector3(0, h, fa)
		for tri in [[0, 1, 4], [1, 5, 4], [1, 2, 5], [2, 3, 5], [3, 4, 5], [3, 0, 4]]:
			for i in tri: st.add_vertex(pts[i])
	else:
		for tri in [[0, 5, 4], [0, 1, 5], [1, 2, 5], [2, 4, 5], [2, 3, 4], [3, 0, 4]]:
			for i in tri: st.add_vertex(pts[i])
	# le dessous, pour les débords vus d'en bas
	for tri in [[0, 2, 1], [0, 3, 2]]:
		for i in tri: st.add_vertex(pts[i])
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat(c)
	m.position = p
	r.add_child(m)
	return m

## Un pignon triangulaire (mur sous un toit à deux pans), dans le plan XY local, largeur w, hauteur h.
static func pignon(r: Node3D, p: Vector3, w: float, h: float, e: float, c: Variant = "enduit") -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-w * .5, 0, 0)
	var b := Vector3(w * .5, 0, 0)
	var s := Vector3(0, h, 0)
	var dz := Vector3(0, 0, e * .5)
	for tri in [[a + dz, b + dz, s + dz], [b - dz, a - dz, s - dz], [a - dz, a + dz, s + dz], [a - dz, s + dz, s - dz], [b + dz, b - dz, s - dz], [b + dz, s - dz, s + dz]]:
		for v in tri: st.add_vertex(v)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat(c)
	m.position = p
	r.add_child(m)
	return m

## Un polygone plat (sol, dalle, place) posé à y, points en XZ, triangulé en éventail (polygone convexe ou presque).
static func dalle(r: Node3D, points: Array, y: float, c: Variant = "pave", epaisseur := 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: PackedVector2Array = []
	for p in points: pts.append(Vector2(p.x, p.y) if p is Vector2 else Vector2(p.x, p.z))
	var idx := Geometry2D.triangulate_polygon(pts)
	for i in range(0, idx.size(), 3):
		# les deux faces : le polygone se voit de dessus quel que soit le sens des points
		for k in [idx[i], idx[i + 2], idx[i + 1], idx[i], idx[i + 1], idx[i + 2]]:
			st.add_vertex(Vector3(pts[k].x, y, pts[k].y))
	if epaisseur > 0.0:
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			var v := [Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(b.x, y - epaisseur, b.y), Vector3(a.x, y - epaisseur, a.y)]
			for k in [0, 2, 1, 0, 3, 2]: st.add_vertex(v[k])
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat(c)
	r.add_child(m)
	return m

## Un volume extrudé d'un polygone XZ (bâtiment à plan irrégulier), de y0 à y1 ; solide : des collisions par arête.
static func extrusion(r: Node3D, points: Array, y0: float, y1: float, c: Variant = "enduit", solide := true, toit_c: Variant = "") -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: PackedVector2Array = []
	for p in points: pts.append(Vector2(p.x, p.y) if p is Vector2 else Vector2(p.x, p.z))
	if Geometry2D.is_polygon_clockwise(pts): pts.reverse()
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var v := [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y)]
		for k in [0, 1, 2, 0, 2, 3]: st.add_vertex(v[k])
		if solide:
			var e := Vector3(b.x - a.x, 0, b.y - a.y)
			collision(r, Vector3((a.x + b.x) * .5, (y0 + y1) * .5, (a.y + b.y) * .5), Vector3(e.length(), y1 - y0, .3), Vector3(0, atan2(e.x, e.z) + PI * .5, 0))
	var idx := Geometry2D.triangulate_polygon(pts)
	for i in range(0, idx.size(), 3):
		for k in [idx[i], idx[i + 2], idx[i + 1]]: st.add_vertex(Vector3(pts[k].x, y1, pts[k].y))
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat(c)
	r.add_child(m)
	return m

## Un solide de révolution autour de Y : profil = liste de Vector2(rayon, y), du bas vers le haut.
## Tours, dômes, clochers, bassins, cheminées. interieur : normales vers l'intérieur (on est dedans).
static func revolution(r: Node3D, p: Vector3, profil: Array, c: Variant = "beton", segments := 48, interieur := false, fermer_bas := false, fermer_haut := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profil.size()
	for j in n - 1:
		var a: Vector2 = profil[j]
		var b: Vector2 = profil[j + 1]
		for i in segments:
			var t0 := TAU * float(i) / segments
			var t1 := TAU * float(i + 1) / segments
			var p00 := Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x)
			var p10 := Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x)
			var p01 := Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)
			var p11 := Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x)
			var u0 := float(i) / segments
			var u1 := float(i + 1) / segments
			var quad := [[p00, Vector2(u0, a.y)], [p01, Vector2(u0, b.y)], [p11, Vector2(u1, b.y)], [p10, Vector2(u1, a.y)]]
			var ordre := [0, 2, 1, 0, 3, 2] if not interieur else [0, 1, 2, 0, 2, 3]
			for k in ordre:
				st.set_uv(quad[k][1])
				st.add_vertex(quad[k][0])
	if fermer_bas or fermer_haut:
		for cap in [[fermer_bas, profil[0], not interieur], [fermer_haut, profil[n - 1], interieur]]:
			if not cap[0] or cap[1].x <= 0.0: continue
			var c0: Vector2 = cap[1]
			for i in segments:
				var t0 := TAU * float(i) / segments
				var t1 := TAU * float(i + 1) / segments
				var centre := Vector3(0, c0.y, 0)
				var pa := Vector3(cos(t0) * c0.x, c0.y, sin(t0) * c0.x)
				var pb := Vector3(cos(t1) * c0.x, c0.y, sin(t1) * c0.x)
				var tri := [centre, pb, pa] if cap[2] else [centre, pa, pb]
				for v in tri: st.add_vertex(v)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat(c)
	m.position = p
	r.add_child(m)
	return m

static func texte(r: Node3D, t: String, p: Vector3, pixel := .004, ry := 0.0, c := Color("e8dec7"), taille := 42) -> Label3D:
	var n := Label3D.new()
	n.text = t
	n.font = Polices.gras()
	n.font_size = taille
	n.pixel_size = pixel
	n.modulate = c
	n.outline_size = 0
	# en rendu Compatibility, un Label3D transparent vu en biais derrière l'eau ou la brume devenait un
	# rectangle blanc : la prépasse opaque le dessine comme un objet plein
	n.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	n.position = p
	n.rotation.y = ry
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_child(n)
	return n

## Une fenêtre à volets dans un mur orienté vers +Z (à poser à la surface du mur) ; ry oriente.
static func fenetre(r: Node3D, p: Vector3, w: float, h: float, volets: Variant = "bois_peint", allumee := false, ry := 0.0, ouverts := true) -> Node3D:
	var g := groupe(r, "Fenetre", p, ry)
	bloc(g, Vector3(0, 0, .02), Vector3(w + .3, h + .3, .1), "calcaire_clair")
	bloc(g, Vector3(0, 0, .06), Vector3(w, h, .04), lumiere(Color("f4dfa6"), 1.2) if allumee else "verre_nuit")
	bloc(g, Vector3(0, 0, .085), Vector3(.05, h, .03), "blanc")
	bloc(g, Vector3(0, h * .1, .085), Vector3(w, .05, .03), "blanc")
	bloc(g, Vector3(0, -h * .5 - .1, .1), Vector3(w + .4, .1, .3), "calcaire_clair")
	if ouverts:
		for s in [-1.0, 1.0]:
			bloc(g, Vector3(s * (w * .5 + w * .26), 0, .08), Vector3(w * .48, h, .05), volets)
	else:
		bloc(g, Vector3(0, 0, .09), Vector3(w, h, .05), volets)
	return g

## Une porte dans un mur orienté vers +Z (le seuil au niveau de p.y).
static func porte(r: Node3D, p: Vector3, w: float, h: float, c: Variant = "bois_sombre", ry := 0.0, imposte := false) -> Node3D:
	var g := groupe(r, "Porte", p, ry)
	bloc(g, Vector3(0, h * .5, .02), Vector3(w + .3, h + .15, .12), "calcaire_clair")
	bloc(g, Vector3(0, h * .5, .07), Vector3(w, h, .06), c)
	bloc(g, Vector3(w * .3, h * .5, .11), Vector3(.05, .05, .05), "laiton")
	bloc(g, Vector3(0, -.02, .25), Vector3(w + .3, .06, .6), "calcaire_clair")
	if imposte: bloc(g, Vector3(0, h + .25, .07), Vector3(w, .4, .06), "verre_nuit")
	return g

## Une maison de bourg du Poitou, façade vers +Z, origine au pied de la façade au milieu.
## spec : w (largeur), d (profondeur), floors (1..3), wall, roof (tuile/ardoise), roof_kind (gable/hip),
## door (left/center/right), shop ({name, color, ink}), shutters (teinte), lit (0..1), chimney, dormer,
## closed (volets fermés), back (dessiner l'arrière avec fenêtres), graine.
static func maison(r: Node3D, p: Vector3, spec: Dictionary, ry := 0.0) -> Node3D:
	var w: float = spec.get("w", 7.0)
	var d: float = spec.get("d", 8.0)
	var floors: int = spec.get("floors", 2)
	var etage := 2.9
	var h := floors * etage + .3
	var wall: Variant = spec.get("wall", "enduit")
	var roof: Variant = spec.get("roof", "tuile")
	var volets: Variant = spec.get("shutters", "bois_peint")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("graine", int(p.x * 7 + p.z * 13)))
	var g := groupe(r, "Maison", p, ry)
	# le corps, creux : quatre murs (les intérieurs sont des scènes du socle)
	bloc(g, Vector3(0, h * .5, -d * .5 + .15), Vector3(w, h, .3), wall, true)
	bloc(g, Vector3(0, h * .5, d * .5 - .15), Vector3(w, h, .3), wall, true)
	for s in [-1.0, 1.0]:
		bloc(g, Vector3(s * (w * .5 - .15), h * .5, 0), Vector3(.3, h, d - .6), wall, true)
	bloc(g, Vector3(0, h - .04, 0), Vector3(w, .08, d), wall)
	# chaînes d'angle et soubassement
	for s in [-1.0, 1.0]:
		bloc(g, Vector3(s * (w * .5 - .1), h * .5, d * .5 + .02), Vector3(.5, h, .08), "calcaire")
	bloc(g, Vector3(0, .35, d * .5 + .03), Vector3(w, .7, .06), "pierre")
	bloc(g, Vector3(0, h - .15, d * .5 + .04), Vector3(w + .1, .18, .2), "calcaire_clair")
	# toit
	var th: float = spec.get("roof_h", w * .28 if roof is String and str(roof) == "tuile" else w * .42)
	if spec.get("roof_kind", "gable") == "hip":
		croupe(g, Vector3(0, h, 0), w, d, th, roof)
	else:
		var t := toit(g, Vector3(0, h, 0), w, d, th, roof)
		pignon(g, Vector3(0, h, -d * .5 + .15), w, th, .3, wall)
		pignon(g, Vector3(0, h, d * .5 - .15), w, th, .3, wall)
	if spec.get("chimney", true):
		bloc(g, Vector3(rng.randf_range(-w * .3, w * .3), h + th * .55, rng.randf_range(-d * .3, d * .3)), Vector3(.7, th * .6 + .9, .9), wall)
	# les ouvertures de la façade (+Z) et de l'arrière si demandé
	var faces := [[d * .5, 0.0]]
	if spec.get("back", false): faces.append([-d * .5, PI])
	var lit: float = spec.get("lit", .55)  # 0.2 : le soir, une fenêtre sur deux est allumée
	var closed: bool = spec.get("closed", false)
	var nb := maxi(1, int((w - 1.4) / 2.2))
	var pas := w / nb
	var porte_pos: String = spec.get("door", "center")
	var ip := 0 if porte_pos == "left" else (nb - 1 if porte_pos == "right" else nb / 2)
	var shop: Dictionary = spec.get("shop", {})
	for face in faces:
		var z: float = face[0]
		var fry: float = face[1]
		for f in floors:
			for i in nb:
				var x := -w * .5 + pas * (i + .5)
				var y := f * etage + 1.6
				if f == 0 and i == ip and z > 0:
					if shop.is_empty():
						porte(g, Vector3(x, 0, z), 1.0, 2.2, "bois_sombre", fry, true)
					continue
				if f == 0 and z > 0 and not shop.is_empty():
					continue
				var allumee := rng.randf() < lit
				fenetre(g, Vector3(x, y, z), 1.0, 1.35 if f > 0 else 1.5, volets, allumee, fry, not closed)
		if spec.get("dormer", false) and z > 0:
			var x := rng.randf_range(-w * .3, w * .3)
			bloc(g, Vector3(x, h + .8, d * .5 - .9), Vector3(1.2, 1.4, 1.6), wall)
			fenetre(g, Vector3(x, h + .85, d * .5 - .1), .6, .8, volets, false, 0.0, false)
			var mini := toit(g, Vector3(x, h + 1.5, d * .5 - .9), 1.5, 1.8, .6, roof, .1)
	# les pignons et les murs de côté ont aussi leurs fenêtres (une maison n'est pas un décor de face)
	if spec.get("sides", true):
		for sx in [-1.0, 1.0]:
			for f in floors:
				if rng.randf() < .65:
					var zf := rng.randf_range(-d * .2, d * .2)
					fenetre(g, Vector3(sx * w * .5, f * etage + 1.6, zf), .8, 1.1, volets, rng.randf() < lit * .6, sx * PI * .5, not closed)
			if spec.get("roof_kind", "gable") != "hip" and rng.randf() < .5:
				# un oculus dans le pignon
				var oc := cyl(g, Vector3(0, h + th * .35, sx * (d * .5 + .02)), .28, .12, "calcaire_clair", -1, 12)
				oc.rotation.x = PI * .5
				var vi := cyl(g, Vector3(0, h + th * .35, sx * (d * .5 + .06)), .18, .06, "verre_nuit", -1, 12)
				vi.rotation.x = PI * .5
	if not shop.is_empty():
		var vw := w - 1.2
		bloc(g, Vector3(0, 1.35, d * .5 + .05), Vector3(vw, 2.3, .1), "verre_nuit")
		bloc(g, Vector3(0, 1.35, d * .5 + .09), Vector3(vw + .25, 2.5, .08), shop.get("color", "vert"))
		bloc(g, Vector3(0, 1.35, d * .5 + .12), Vector3(vw - .1, 2.1, .06), "verre_nuit")
		bloc(g, Vector3(0, .25, d * .5 + .14), Vector3(vw - .1, .5, .08), shop.get("color", "vert"))
		bloc(g, Vector3(0, 2.85, d * .5 + .12), Vector3(vw + .3, .5, .12), shop.get("color", "vert"))
		texte(g, str(shop.get("name", "")), Vector3(0, 2.85, d * .5 + .19), .0075, 0.0, Color(str(shop.get("ink", "f0ead6"))), 30)
		var pw := 1.0
		var px := -vw * .5 + .9 if porte_pos == "left" else (vw * .5 - .9 if porte_pos == "right" else 0.0)
		bloc(g, Vector3(px, 1.1, d * .5 + .15), Vector3(pw, 2.2, .06), shop.get("color", "vert"))
		bloc(g, Vector3(px, 1.2, d * .5 + .19), Vector3(pw - .2, 1.6, .02), "verre_nuit")
	return g

## Un arbre procédural : tronc, branches et masses de feuillage (couleurs en vertex color, shader feuillage).
## genre : chene (bronze d'automne), peuplier (jaune, élancé), platane (large, clair), sequoia (conique, sombre),
## if (sombre, dense), saule (gris-vert, tombant), nu (sans feuilles). rayon : la masse de feuillage.
static func arbre(r: Node3D, p: Vector3, genre := "chene", graine := 0, echelle := 1.0, leger := false) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine * 7919 + int(p.x * 13.0 + p.z * 29.0)
	var g := groupe(r, "Arbre_" + genre, p, rng.randf() * TAU)
	var ht := 0.0
	var couleur := Color("6b6a3a")
	var masses := 5
	var large := 1.0
	match genre:
		"chene": ht = 7.5 * echelle; couleur = Color("4a5e30"); masses = 8; large = 1.15
		"peuplier": ht = 16.0 * echelle; couleur = Color("c2a13e"); masses = 12; large = .42
		"platane": ht = 9.0 * echelle; couleur = Color("5a6a36"); masses = 8; large = 1.3
		"sequoia": ht = 30.0 * echelle; couleur = Color("3a5a36"); masses = 9; large = .55
		"if": ht = 5.0 * echelle; couleur = Color("2f4a2a"); masses = 5; large = .8
		"saule": ht = 7.0 * echelle; couleur = Color("8a9a6a"); masses = 6; large = 1.2
		"nu": ht = 7.0 * echelle; couleur = Color("5a4a3a"); masses = 0; large = 1.0
		_: ht = 7.0 * echelle
	# Les grands bois (leger) sont vus de loin : tronc à cinq pans, branches sous le feuillage omises
	# (sauf aux arbres nus, qui ne sont que branches), feuillage en sphères 5 × 2.
	var tronc := cyl(g, Vector3(0, ht * .28, 0), .22 * echelle * (1.5 if genre == "sequoia" else 1.0), ht * .56, "tronc" if genre != "platane" else "tronc_clair", .14 * echelle, 5 if leger else 8)
	collision_cyl(g, Vector3(0, ht * .3, 0), .3 * echelle, ht * .6)
	# branches
	var nb_branches := 0 if genre in ["peuplier", "sequoia", "if"] else 3 + (2 if genre == "nu" else 0)
	if leger and genre != "nu": nb_branches = 0
	for i in nb_branches:
		var a := rng.randf() * TAU
		var y0 := ht * rng.randf_range(.35, .55)
		var fin := Vector3(cos(a) * ht * .22 * large, y0 + ht * .22, sin(a) * ht * .22 * large)
		barre(g, Vector3(0, y0, 0), fin, .07 * echelle, "tronc", 4 if leger else 6)
	if masses == 0: return g
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sph := SphereMesh.new()
	sph.radial_segments = 5 if leger else 7
	sph.rings = 2 if leger else 4
	if leger and masses > 0: masses = maxi(3, int(masses * .6))
	# append_from ne porte pas set_color : on copie les sommets de la sphère à la main, avec leur couleur.
	var sph_arrays := sph.get_mesh_arrays()
	var sph_v: PackedVector3Array = sph_arrays[Mesh.ARRAY_VERTEX]
	var sph_n: PackedVector3Array = sph_arrays[Mesh.ARRAY_NORMAL]
	var sph_i: PackedInt32Array = sph_arrays[Mesh.ARRAY_INDEX]
	for i in masses:
		var t := float(i) / maxf(1.0, masses - 1)
		var a := rng.randf() * TAU
		var rayon_masse: float
		var centre: Vector3
		if genre == "sequoia":
			rayon_masse = ht * (.16 - t * .11)
			centre = Vector3(0, ht * (.35 + t * .62), 0)
		elif genre == "peuplier":
			rayon_masse = ht * (.115 - absf(t - .45) * .09)
			centre = Vector3(cos(a) * .35, ht * (.32 + t * .62), sin(a) * .35)
		else:
			rayon_masse = ht * rng.randf_range(.20, .27) * large
			var spread := ht * .17 * large
			centre = Vector3(cos(a) * spread * rng.randf_range(.3, 1.0), ht * rng.randf_range(.55, .80), sin(a) * spread * rng.randf_range(.3, 1.0))
			if i == 0: centre = Vector3(0, ht * .68, 0); rayon_masse = ht * .30 * large
		var nuance := couleur.lightened(rng.randf_range(-.12, .12))
		var etire := rng.randf_range(1.4, 1.8) if genre == "peuplier" else rng.randf_range(.7, 1.0)
		var xf := Transform3D(Basis().scaled(Vector3(rayon_masse, rayon_masse * etire, rayon_masse)), centre)
		var souffle := .3 + t * .7
		st.set_color(Color(nuance.r, nuance.g, nuance.b, souffle))
		for k in sph_i:
			st.set_normal((xf.basis * sph_n[k]).normalized())
			st.add_vertex(xf * sph_v[k])
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var fm := ShaderMaterial.new()
	fm.shader = FEUILLAGE
	m.material_override = fm
	m.set_meta("anime", true)
	g.add_child(m)
	return g

## Un bosquet : des arbres du même genre, en MultiMesh (un seul appel de dessin pour tout le feuillage).
static func bosquet(r: Node3D, positions: Array, genre := "chene", graine := 1, echelle := 1.0) -> Node3D:
	var g := groupe(r, "Bosquet_" + genre)
	if positions.is_empty(): return g
	# un arbre modèle, fusionné en deux maillages (tronc, feuillage), puis instancié
	var modele := Node3D.new()
	g.add_child(modele)
	var variantes: Array = []
	for v in 3:
		var a := arbre(modele, Vector3.ZERO, genre, graine + v, echelle, positions.size() > 150)
		var tronc_st := SurfaceTool.new()
		tronc_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var feuille_mesh: Mesh = null
		for enfant in a.get_children():
			if enfant is MeshInstance3D:
				if enfant.get_meta("anime", false): feuille_mesh = enfant.mesh
				else: tronc_st.append_from(enfant.mesh, 0, enfant.transform)
		variantes.append([tronc_st.commit(), feuille_mesh])
	modele.queue_free()
	var mmt := []
	for v in 3:
		for k in 2:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = variantes[v][k]
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			if k == 0: mmi.material_override = mat("tronc")
			else:
				var fm := ShaderMaterial.new()
				fm.shader = FEUILLAGE
				mmi.material_override = fm
			mmi.set_meta("anime", true)
			g.add_child(mmi)
			mmt.append(mmi)
	var par_variante := [[], [], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	for p in positions:
		var v := rng.randi_range(0, 2)
		var s := rng.randf_range(.85, 1.2)
		par_variante[v].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
		collision_cyl(g, p + Vector3(0, 3, 0), .3 * echelle, 6)
	for v in 3:
		for k in 2:
			var mmi: MultiMeshInstance3D = mmt[v * 2 + k]
			if mmi.multimesh.mesh == null or par_variante[v].is_empty():
				# pas de feuillage (arbres nus) ou pas d'instance : on ne laisse pas de MultiMesh vide dans la scène
				mmi.queue_free()
				continue
			# les grands bois ne portent pas d'ombre : c'est le plus gros poste de la passe d'ombres
			if positions.size() > 150: mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.multimesh.instance_count = par_variante[v].size()
			for i in par_variante[v].size():
				mmi.multimesh.set_instance_transform(i, par_variante[v][i])
	return g

## Un figurant du socle (ligne claire), mis à l'échelle des mètres. pose : idle, sit, walk (route : des points).
static func figurant(r: Node3D, p: Vector3, graine := 1, pose := "idle", ry := 0.0, tenue := "village", route: Array[Vector3] = []) -> Node3D:
	var f := Atelier.figurant(graine, pose, tenue, route)
	f.scale = Vector3.ONE * ECHELLE_FIGURANT
	f.position = p
	f.rotation.y = ry
	f.set_meta("anime", true)
	if "speed" in f: f.speed = 1.1
	r.add_child(f)
	return f

## Un personnage 3D du socle (Quaternius, en mètres déjà) : client, croupier, barman, vigile, employe, livreur…
static func personnage(r: Node3D, p: Vector3, role := "client", graine := 1, ry := 0.0, geste := "idle") -> Node3D:
	var n := Atelier.personnage(role, graine)
	if n == null: return null
	n.position = p
	n.rotation.y = ry
	n.set_meta("anime", true)
	r.add_child(n)
	if n.has_method("jouer"): n.jouer(geste)
	return n


## Fusion des géométries statiques d'un groupe, par matière (et par cellule de taille donnée).
## Les nœuds marqués meta « anime » (figurants, feuillage, particules) sont laissés tels quels.
static func fusionner(r: Node3D, taille_cellule := 0.0) -> void:
	var sources: Array[MeshInstance3D] = []
	_meshes_statiques(r, sources)
	var lots: Dictionary = {}
	for n in sources:
		var transform := r.global_transform.affine_inverse() * n.global_transform
		var centre := transform * n.mesh.get_aabb().get_center()
		var cellule := Vector2i.ZERO
		if taille_cellule > 0.0:
			cellule = Vector2i(floori(centre.x / taille_cellule), floori(centre.z / taille_cellule))
		for i in n.mesh.get_surface_count():
			var m: Material = n.material_override
			if m == null: m = n.get_active_material(i)
			if m == null: continue
			# La matière commune ne diffère d'une teinte à l'autre que par sa couleur : la teinte passe dans
			# les sommets, et toutes les teintes d'un même genre se dessinent en un seul appel (sur téléphone,
			# le bourg passait de quelques dizaines à plus de mille appels de dessin).
			var teinte = null
			if m is ShaderMaterial and m.shader == SURFACE:
				teinte = m.get_shader_parameter("teinte")
				if teinte == null: teinte = Color(.8, .74, .62)
				m = _fondue(m)
			var id := "%s:%s:%s" % [m.get_instance_id(), cellule.x, cellule.y]
			if not lots.has(id):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(m)
				lots[id] = st
			var arrays := n.mesh.surface_get_arrays(i)
			var indices = arrays[Mesh.ARRAY_INDEX]
			if teinte != null:
				var couleurs := PackedColorArray()
				couleurs.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
				couleurs.fill(teinte)
				arrays[Mesh.ARRAY_COLOR] = couleurs
				var teinte_mesh := ArrayMesh.new()
				teinte_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				if indices == null or indices.is_empty():
					var indexed_t := SurfaceTool.new()
					indexed_t.create_from(teinte_mesh, 0)
					indexed_t.index()
					lots[id].append_from(indexed_t.commit(), 0, transform)
				else:
					lots[id].append_from(teinte_mesh, 0, transform)
			elif indices == null or indices.is_empty():
				var indexed := SurfaceTool.new()
				indexed.create_from(n.mesh, i)
				indexed.index()
				lots[id].append_from(indexed.commit(), 0, transform)
			else:
				lots[id].append_from(n.mesh, i, transform)
	for id in lots:
		var n := MeshInstance3D.new()
		n.name = "Geometrie"
		n.mesh = lots[id].commit()
		r.add_child(n)
	for n in sources:
		n.get_parent().remove_child(n)
		n.free()

static var _fondues: Dictionary = {}

## La matière commune d'un genre, sans teinte propre : la teinte vient des sommets (fusion).
static func _fondue(m: ShaderMaterial) -> ShaderMaterial:
	var genre = m.get_shader_parameter("genre")
	var rugosite = m.get_shader_parameter("rugosite")
	var metal = m.get_shader_parameter("metal")
	var cle := "%s:%s:%s" % [genre, rugosite, metal]
	if not _fondues.has(cle):
		var f := ShaderMaterial.new()
		f.shader = SURFACE
		f.set_shader_parameter("teinte", Color.WHITE)
		f.set_shader_parameter("teinte_sommets", true)
		if genre != null: f.set_shader_parameter("genre", genre)
		if rugosite != null: f.set_shader_parameter("rugosite", rugosite)
		if metal != null: f.set_shader_parameter("metal", metal)
		_fondues[cle] = f
	return _fondues[cle]

static func _meshes_statiques(n: Node, resultat: Array[MeshInstance3D]) -> void:
	for enfant in n.get_children():
		if enfant.get_meta("anime", false): continue
		if enfant is MeshInstance3D and enfant.mesh != null and enfant.skin == null and enfant.get_child_count() == 0 \
				and not (enfant.material_override is StandardMaterial3D and enfant.material_override.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
			resultat.append(enfant)
		else:
			_meshes_statiques(enfant, resultat)


# ---------------------------------------------------------------------------------------------
# Les primitives des châteaux et du relief (propres à Chauvigny)
# ---------------------------------------------------------------------------------------------

## Des merlons le long d'un segment au sol (a → b), posés à la hauteur y : un créneau = merlon + vide.
## e : épaisseur du mur ; hm : hauteur des merlons ; pas : merlon + vide.
static func creneaux(r: Node3D, a: Vector3, b: Vector3, y: float, e: float, c: Variant = "calcaire", hm := .9, pas := 1.6, graine := 0) -> void:
	var d := b - a
	d.y = 0.0
	var l := d.length()
	if l < .5: return
	var dir := d / l
	var ry := atan2(dir.x, dir.z) + PI * .5
	var n := maxi(1, int(l / pas))
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	for i in n:
		var t := (float(i) + .5) / n
		var p := a + dir * (t * l)
		var lm := pas * .55
		var h := hm
		if graine != 0:  # ruine : des merlons manquants ou cassés
			if rng.randf() < .3: continue
			h = hm * rng.randf_range(.4, 1.0)
		bloc(r, Vector3(p.x, y + h * .5, p.z), Vector3(lm, h, e), c, false, ry)

## Une muraille le long d'une polyligne au sol (y lu du terrain si les points ont y = -INF, sinon tel quel),
## de hauteur h, d'épaisseur e, avec un chemin de ronde et des créneaux côté « exterieur » (+1 : à gauche
## du sens de parcours, -1 : à droite, 0 : les deux). solide : collision du mur et du chemin de ronde.
static func muraille(r: Node3D, points: Array, h: float, e: float, c: Variant = "calcaire", exterieur := 1, creneaux_ := true, graine := 0) -> Node3D:
	var g := groupe(r, "Muraille")
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var ya := a.y
		var yb := b.y
		var base := minf(ya, yb)
		var haut := maxf(ya, yb) + h
		# le corps du mur, plus bas que le plus bas des deux points pour ne pas laisser de jour sous lui
		mur(g, Vector3(a.x, base - 2.0, a.z), Vector3(b.x, base - 2.0, b.z), haut - base + 2.0, e, c, true)
		# le chemin de ronde : une dalle au sommet, légèrement en retrait des parapets
		var d := b - a
		d.y = 0.0
		var dir := d.normalized()
		var perp := Vector3(-dir.z, 0, dir.x)
		if creneaux_:
			# (un ternaire de deux listes donne un Array non typé : on ne le force pas en Array[float], ça plantait)
			var cotes: Array = [-1.0, 1.0] if exterieur == 0 else [float(exterieur)]
			for cote: float in cotes:
				var o: Vector3 = perp * (cote * (e * .5 - .2))
				creneaux(g, a + o, b + o, haut, .4, c, .9, 1.6, graine + i * 7)
				# le parapet bas entre les merlons
				mur(g, a + o, b + o, .45, .4, c, false)
	return g

## Une tour ronde : fût (légèrement conique), cordon, créneaux ou toit en poivrière, collision.
## options : {"toit": "poivriere"|"creneaux"|"ruine"|"plat", "archeres": n, "cordon": true, "base": r_base}
static func tour(r: Node3D, p: Vector3, rayon: float, hauteur: float, c: Variant = "calcaire", options := {}) -> Node3D:
	var g := groupe(r, "Tour", p)
	var base: float = options.get("base", rayon * 1.12)
	var toit_genre: String = options.get("toit", "creneaux")
	var seg := 28
	# fût : talus en bas, fût droit ensuite
	var talus := minf(hauteur * .22, 4.0)
	revolution(g, Vector3.ZERO, [Vector2(base, -3.0), Vector2(base, 0.0), Vector2(rayon, talus), Vector2(rayon, hauteur)], c, seg, false, true, true)
	collision_cyl(g, Vector3(0, hauteur * .5 - 1.5, 0), rayon + .1, hauteur + 3.0)
	if options.get("cordon", true):
		revolution(g, Vector3.ZERO, [Vector2(rayon, hauteur - 1.4), Vector2(rayon + .25, hauteur - 1.2), Vector2(rayon + .25, hauteur - .95), Vector2(rayon, hauteur - .8)], "taille", seg)
	var n_arch: int = options.get("archeres", 3)
	for i in n_arch:
		var a := TAU * (float(i) + .3) / n_arch
		var y := hauteur * (.45 + .3 * fposmod(float(i) * .618, 1.0))
		var m := bloc(g, Vector3(cos(a) * (rayon + .02), y, sin(a) * (rayon + .02)), Vector3(.18, 1.1, .18), "noir")
		m.rotation.y = -a
	match toit_genre:
		"poivriere":
			# un cône d'ardoise sur un débord de pierre, et une girouette
			revolution(g, Vector3(0, hauteur, 0), [Vector2(rayon + .35, 0.0), Vector2(rayon + .35, .3), Vector2(.12, rayon * 1.9)], "ardoise", seg, false, true, true)
			cyl(g, Vector3(0, hauteur + rayon * 1.9 + .5, 0), .03, 1.0, "fer", -1, 6)
		"creneaux":
			# une couronne de merlons sur le sommet
			var pas := 1.5
			var nm := maxi(6, int(TAU * rayon / pas))
			for i in nm:
				var a := TAU * float(i) / nm
				var m := bloc(g, Vector3(cos(a) * (rayon - .25), hauteur + .5, sin(a) * (rayon - .25)), Vector3(pas * .55, 1.0, .5), c)
				m.rotation.y = -a + PI * .5
			# le sol de la plate-forme
			cyl(g, Vector3(0, hauteur - .1, 0), rayon - .05, .2, "pierre", -1, seg)
		"ruine":
			# un sommet déchiqueté : des pans qui montent à des hauteurs différentes
			var rng := RandomNumberGenerator.new()
			rng.seed = int(p.x * 3.0 + p.z * 7.0)
			var nm := maxi(8, int(TAU * rayon / 1.1))
			for i in nm:
				var a := TAU * float(i) / nm
				var hh := rng.randf_range(.3, 3.2)
				var m := bloc(g, Vector3(cos(a) * (rayon - .35), hauteur + hh * .5, sin(a) * (rayon - .35)), Vector3(1.15, hh, .7), "ruine")
				m.rotation.y = -a + PI * .5
		_:
			cyl(g, Vector3(0, hauteur - .1, 0), rayon + .3, .25, "taille", -1, seg)
	return g

## Une tour carrée (donjon) : corps, chaînes d'angle, contreforts plats, cordon, créneaux ou ruine.
## options : {"toit": "creneaux"|"ruine"|"ardoise"|"plat", "contreforts": true, "fenetres": n, "ouvert": "nord"|"" (un côté éventré)}
static func donjon(r: Node3D, p: Vector3, w: float, d: float, hauteur: float, c: Variant = "calcaire", options := {}) -> Node3D:
	var g := groupe(r, "Donjon", p)
	var ouvert: String = options.get("ouvert", "")
	var faces := {"sud": [Vector3(0, 0, d * .5), 0.0, w], "nord": [Vector3(0, 0, -d * .5), PI, w], "est": [Vector3(w * .5, 0, 0), PI * .5, d], "ouest": [Vector3(-w * .5, 0, 0), -PI * .5, d]}
	var ep := 1.6
	for nom in faces:
		var f: Array = faces[nom]
		var centre: Vector3 = f[0]
		var ry: float = f[1]
		var l: float = f[2]
		var hh := hauteur
		if nom == ouvert:
			hh = hauteur * .35  # le pan éventré ne garde que son bas
		var m := bloc(g, centre + Vector3(0, hh * .5 - 1.5, 0), Vector3(l, hh + 3.0, ep), c, true, ry)
		if options.get("contreforts", true) and nom != ouvert:
			# deux contreforts plats par face
			for s in [-.3, .3]:
				var o := Vector3(cos(ry) * s * l, 0, -sin(ry) * s * l)
				var cf := bloc(g, centre + o + Vector3(sin(ry) * .35, hh * .45, cos(ry) * .35), Vector3(1.4, hh * .9, .7), "taille", false, ry)
		# les ouvertures : archères en bas, fenêtres géminées en haut
		var nf: int = options.get("fenetres", 2)
		for i in nf:
			var t := (float(i) + .5) / nf - .5
			var o := Vector3(cos(ry) * t * l * .7, 0, -sin(ry) * t * l * .7)
			var devant := Vector3(sin(ry) * (ep * .5 + .02), 0, cos(ry) * (ep * .5 + .02))
			if nom != ouvert:
				var arch := bloc(g, centre + o + devant + Vector3(0, hauteur * .3, 0), Vector3(.2, 1.4, .1), "noir", false, ry)
				fenetre_romane(g, centre + o + devant + Vector3(0, hauteur * .68, 0), 1.1, 2.0, ry, true)
	# les chaînes d'angle
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			bloc(g, Vector3(sx * (w * .5 - .05), hauteur * .5 - 1.5, sz * (d * .5 - .05)), Vector3(1.0, hauteur + 3.0, 1.0), "taille")
	# cordon
	bloc(g, Vector3(0, hauteur - 1.2, 0), Vector3(w + .5, .35, d + .5), "taille")
	match options.get("toit", "creneaux"):
		"creneaux":
			for f in [[Vector3(-w * .5, 0, -d * .5), Vector3(w * .5, 0, -d * .5)], [Vector3(w * .5, 0, -d * .5), Vector3(w * .5, 0, d * .5)], [Vector3(w * .5, 0, d * .5), Vector3(-w * .5, 0, d * .5)], [Vector3(-w * .5, 0, d * .5), Vector3(-w * .5, 0, -d * .5)]]:
				creneaux(g, f[0], f[1], hauteur, .6, c, 1.0, 1.7)
			bloc(g, Vector3(0, hauteur - .15, 0), Vector3(w - .2, .3, d - .2), "pierre")
		"ruine":
			for f in [[Vector3(-w * .5, 0, -d * .5), Vector3(w * .5, 0, -d * .5), "nord"], [Vector3(w * .5, 0, -d * .5), Vector3(w * .5, 0, d * .5), "est"], [Vector3(w * .5, 0, d * .5), Vector3(-w * .5, 0, d * .5), "sud"], [Vector3(-w * .5, 0, d * .5), Vector3(-w * .5, 0, -d * .5), "ouest"]]:
				if f[2] == ouvert: continue
				creneaux(g, f[0], f[1], hauteur, .8, "ruine", 2.4, 1.3, int(p.x) + 11)
		"ardoise":
			croupe(g, Vector3(0, hauteur, 0), w, d, minf(w, d) * .6, "ardoise", .5)
		_:
			bloc(g, Vector3(0, hauteur - .15, 0), Vector3(w + .4, .3, d + .4), "taille")
	return g

## Une fenêtre romane (en plein cintre) dans un mur orienté vers +Z ; geminee : deux baies sous un arc.
static func fenetre_romane(r: Node3D, p: Vector3, w: float, h: float, ry := 0.0, geminee := false, allumee := false) -> Node3D:
	var g := groupe(r, "FenetreRomane", p, ry)
	var fond: Variant = lumiere(Color("f4dfa6"), 1.1) if allumee else "noir"
	# l'encadrement de pierre de taille
	bloc(g, Vector3(0, 0, .02), Vector3(w + .5, h + .3, .14), "taille")
	if geminee:
		for s in [-1.0, 1.0]:
			bloc(g, Vector3(s * w * .27, -h * .1, .08), Vector3(w * .38, h * .8, .06), fond)
			var arc_ := cyl(g, Vector3(s * w * .27, h * .3, .08), w * .19, .06, fond, -1, 12)
			arc_.rotation.x = PI * .5
		cyl(g, Vector3(0, -h * .1, .1), .07, h * .8, "taille", -1, 8)
	else:
		bloc(g, Vector3(0, -h * .1, .08), Vector3(w, h * .8, .06), fond)
		var arc_ := cyl(g, Vector3(0, h * .3, .08), w * .5, .06, fond, -1, 14)
		arc_.rotation.x = PI * .5
	return g

## Un pan de mur en ruine : entre a et b, la hauteur varie de h_min à h_max par morceaux, le sommet est déchiqueté.
static func mur_ruine(r: Node3D, a: Vector3, b: Vector3, h_min: float, h_max: float, e: float, c: Variant = "ruine", graine := 1, solide := true) -> Node3D:
	var g := groupe(r, "MurRuine")
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var d := b - a
	d.y = 0.0
	var l := d.length()
	var dir := d / maxf(l, .01)
	var n := maxi(2, int(l / 1.3))
	var pas := l / n
	var base := minf(a.y, b.y) - 1.5
	var h_prec := rng.randf_range(h_min, h_max)
	var ry := atan2(dir.x, dir.z) + PI * .5
	for i in n:
		var p := a + dir * ((float(i) + .5) * pas)
		var h := clampf(h_prec + rng.randf_range(-1.2, 1.2), h_min, h_max)
		h_prec = h
		var y1 := maxf(a.y, b.y) + h
		bloc(g, Vector3(p.x, (base + y1) * .5, p.z), Vector3(pas * 1.02, y1 - base, e), c, false, ry)
		# quelques pierres tombées au pied
		if rng.randf() < .25:
			var perp := Vector3(-dir.z, 0, dir.x) * (e * .5 + rng.randf_range(.3, 1.2)) * (1.0 if rng.randf() < .5 else -1.0)
			var q := p + perp
			rocher(g, Vector3(q.x, maxf(a.y, b.y) + .2, q.z), Vector3(.5, .35, .4) * rng.randf_range(.6, 1.3), "ruine_sombre", i + graine)
	if solide:
		collision(g, (a + b) * .5 + Vector3(0, (h_min + h_max) * .25 + .5, 0), Vector3(l, (h_min + h_max) * .5 + 1.0, e), Vector3(0, ry, 0))
	return g

## Un rocher : une sphère basse déformée (éboulis, blocs de carrière, pierres tombées).
static func rocher(r: Node3D, p: Vector3, taille: Vector3, c: Variant = "falaise", graine := 1) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var sph := SphereMesh.new()
	sph.radial_segments = 7
	sph.rings = 4
	var arr := sph.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		var q := v[i]
		var bump := 1.0 + rng.randf_range(-.18, .18)
		v[i] = Vector3(q.x * bump, q.y * (bump * .8 + .2), q.z * bump)
	arr[Mesh.ARRAY_VERTEX] = v
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.scale = taille
	m.position = p
	m.rotation.y = rng.randf() * TAU
	m.material_override = mat(c)
	r.add_child(m)
	return m

## Un bloc de pierre de taille équarri (le chantier, les carrières) : un parallélépipède à arêtes vives, posé.
static func bloc_taille(r: Node3D, p: Vector3, taille: Vector3, ry := 0.0, c: Variant = "taille") -> MeshInstance3D:
	return bloc(r, p + Vector3(0, taille.y * .5, 0), taille, c, true, ry)

## Un escalier droit de a (bas) à b (haut) au sol, de largeur w : des marches visibles et une rampe de
## collision continue (l'habitant la gravit sans buter). hauteur_marche ~ 0,17 m.
static func escalier(r: Node3D, a: Vector3, b: Vector3, w: float, c: Variant = "pierre", hauteur_marche := .17, solide := true) -> Node3D:
	var g := groupe(r, "Escalier")
	var d := b - a
	var plat := Vector3(d.x, 0, d.z)
	var l := plat.length()
	var dir := plat / maxf(l, .01)
	var ry := atan2(dir.x, dir.z) + PI * .5
	var n := maxi(1, int(round(absf(d.y) / hauteur_marche)))
	var hm := d.y / n
	var giron := l / n
	for i in n:
		var p := a + dir * ((float(i) + .5) * giron) + Vector3(0, (float(i) + .5) * hm, 0)
		# chaque marche descend jusqu'au sol de départ : pas de jour sous l'escalier
		var bas := a.y - .3
		var m := bloc(g, Vector3(p.x, (bas + p.y + hm * .5) * .5, p.z), Vector3(giron * 1.05, p.y + hm * .5 - bas, w), c, false, ry)
	if solide:
		var centre := (a + b) * .5
		var longueur := sqrt(l * l + d.y * d.y)
		var pente := atan2(d.y, l)
		var forme := BoxShape3D.new()
		forme.size = Vector3(longueur, .3, w)
		# (ry tourne le X local vers -dir : la pente se prend en négatif pour que la rampe monte de a vers b)
		var xf := Transform3D(Basis.from_euler(Vector3(0, ry, 0)) * Basis.from_euler(Vector3(0, 0, -pente)), centre + Vector3(0, -.12, 0))
		_forme(g, xf, forme)
	return g

## Une rampe de collision seule (pour un chemin dessiné dans le terrain ou un tablier incliné).
static func rampe(r: Node3D, a: Vector3, b: Vector3, w: float, epaisseur := .3) -> void:
	var d := b - a
	var plat := Vector3(d.x, 0, d.z)
	var l := plat.length()
	var ry := atan2(plat.x, plat.z) + PI * .5
	var pente := atan2(d.y, l)
	var forme := BoxShape3D.new()
	forme.size = Vector3(sqrt(l * l + d.y * d.y), epaisseur, w)
	_forme(r, Transform3D(Basis.from_euler(Vector3(0, ry, 0)) * Basis.from_euler(Vector3(0, 0, -pente)), (a + b) * .5 + Vector3(0, -epaisseur * .5, 0)), forme)

## Un mur de soutènement qui suit le terrain entre deux points : le haut suit la pente, le bas s'enfonce.
static func soutenement(r: Node3D, a: Vector3, b: Vector3, h: float, e := .6, c: Variant = "moellon", solide := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := b - a
	var plat := Vector3(d.x, 0, d.z).normalized()
	var perp := Vector3(-plat.z, 0, plat.x) * (e * .5)
	var bas := -2.0
	var pts := [a + perp + Vector3(0, bas, 0), b + perp + Vector3(0, bas, 0), b + perp + Vector3(0, h, 0), a + perp + Vector3(0, h, 0),
		a - perp + Vector3(0, bas, 0), b - perp + Vector3(0, bas, 0), b - perp + Vector3(0, h, 0), a - perp + Vector3(0, h, 0)]
	for tri in [[0, 2, 1], [0, 3, 2], [4, 5, 6], [4, 6, 7], [3, 7, 6], [3, 6, 2], [0, 1, 5], [0, 5, 4], [1, 2, 6], [1, 6, 5], [0, 4, 7], [0, 7, 3]]:
		for k in tri: st.add_vertex(pts[k])
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat(c)
	r.add_child(m)
	if solide:
		var l := Vector3(d.x, 0, d.z).length()
		var ry := atan2(plat.x, plat.z) + PI * .5
		var pente := atan2(d.y, l)
		var forme := BoxShape3D.new()
		forme.size = Vector3(sqrt(l * l + d.y * d.y), h - bas, e)
		_forme(r, Transform3D(Basis.from_euler(Vector3(0, ry, 0)) * Basis.from_euler(Vector3(0, 0, -pente)), (a + b) * .5 + Vector3(0, (h + bas) * .5, 0)), forme)
	return m

## Une lanterne de fer sur potence, allumée (chaud) ; avec une vraie lampe si lampe = true (à compter dans le budget).
static func lanterne(r: Node3D, p: Vector3, ry := 0.0, lampe := false, potence := .6) -> Node3D:
	var g := groupe(r, "Lanterne", p, ry)
	barre(g, Vector3(0, 0, 0), Vector3(0, 0, potence), .025, "fer", 6)
	bloc(g, Vector3(0, -.2, potence), Vector3(.28, .4, .28), lumiere(Color("f0b94a"), 2.2))
	bloc(g, Vector3(0, .03, potence), Vector3(.34, .06, .34), "fer")
	bloc(g, Vector3(0, -.42, potence), Vector3(.2, .05, .2), "fer")
	if lampe:
		var l := OmniLight3D.new()
		l.position = Vector3(0, -.3, potence)
		l.light_color = Color("ffc878")
		l.light_energy = 1.6
		l.omni_range = 9.0
		l.shadow_enabled = false
		g.add_child(l)
	return g

## Un banc de bois sur pieds de fer.
static func banc(r: Node3D, p: Vector3, ry := 0.0) -> Node3D:
	var g := groupe(r, "Banc", p, ry)
	for s in [-.7, .7]:
		bloc(g, Vector3(s, .22, 0), Vector3(.06, .44, .4), "fer")
	bloc(g, Vector3(0, .45, 0), Vector3(1.7, .05, .42), "bois_use")
	bloc(g, Vector3(0, .75, -.2), Vector3(1.7, .35, .05), "bois_use")
	collision(r, p + Vector3(0, .4, 0), Vector3(1.7, .8, .5), Vector3(0, ry, 0))
	return g

## Un arbre fruitier bas ou un buisson (figuier, buis, laurier) : une boule de feuillage sur un tronc court.
static func buisson(r: Node3D, p: Vector3, rayon := 1.0, c := Color("2f4a2a"), graine := 0, tronc_ := true) -> Node3D:
	var g := groupe(r, "Buisson", p)
	if tronc_: cyl(g, Vector3(0, rayon * .35, 0), .08, rayon * .7, "tronc", -1, 6)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine + int(p.x * 3.0 + p.z * 5.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sph := SphereMesh.new()
	sph.radial_segments = 6
	sph.rings = 3
	var arr := sph.get_mesh_arrays()
	var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var si: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in 4:
		var centre := Vector3(rng.randf_range(-.4, .4), rayon * .9 + rng.randf_range(-.2, .3), rng.randf_range(-.4, .4)) * rayon
		var rr := rayon * rng.randf_range(.55, .8)
		var xf := Transform3D(Basis().scaled(Vector3(rr, rr * .85, rr)), centre)
		var nuance := c.lightened(rng.randf_range(-.1, .12))
		st.set_color(Color(nuance.r, nuance.g, nuance.b, .5))
		for k in si:
			st.set_normal((xf.basis * sn[k]).normalized())
			st.add_vertex(xf * sv[k])
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	var fm := ShaderMaterial.new()
	fm.shader = FEUILLAGE
	m.material_override = fm
	m.set_meta("anime", true)
	g.add_child(m)
	return g

## Une voûte en berceau (un passage sous une porte, un porche) : l'intrados en demi-cylindre creux, vu de dessous.
## Axe du passage le long de Z local ; largeur w (diamètre), longueur l, à la hauteur y0 des naissances.
static func voute(r: Node3D, p: Vector3, w: float, l: float, y0: float, c: Variant = "calcaire", ry := 0.0, segments := 14) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rayon := w * .5
	for i in segments:
		var a0 := PI * float(i) / segments
		var a1 := PI * float(i + 1) / segments
		var p00 := Vector3(cos(a0) * rayon, y0 + sin(a0) * rayon, -l * .5)
		var p01 := Vector3(cos(a0) * rayon, y0 + sin(a0) * rayon, l * .5)
		var p10 := Vector3(cos(a1) * rayon, y0 + sin(a1) * rayon, -l * .5)
		var p11 := Vector3(cos(a1) * rayon, y0 + sin(a1) * rayon, l * .5)
		for v in [p00, p10, p11, p00, p11, p01]: st.add_vertex(v)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat(c)
	m.position = p
	m.rotation.y = ry
	r.add_child(m)
	return m

## Une porte de ville : deux tourelles et un passage voûté entre elles, dans un mur d'épaisseur e.
## Le passage est le long de Z local (on le traverse en marchant selon Z), largeur libre w.
static func porte_de_ville(r: Node3D, p: Vector3, w: float, e: float, hauteur: float, c: Variant = "calcaire", ry := 0.0, lanterne_ := true) -> Node3D:
	var g := groupe(r, "PorteDeVille", p, ry)
	var y_naiss := hauteur * .45
	# les piédroits, en pierre de taille
	for s in [-1.0, 1.0]:
		bloc(g, Vector3(s * (w * .5 + .5), hauteur * .5 - 1.0, 0), Vector3(1.0, hauteur + 2.0, e), "taille", true)
	# le mur au-dessus du passage (le corps de la porte), fermé derrière la voûte
	bloc(g, Vector3(0, (y_naiss + w * .5 + hauteur) * .5, 0), Vector3(w + 2.0, hauteur - (y_naiss + w * .5), e), c)
	# les écoinçons : ce qui reste entre la voûte et le mur, des deux côtés
	for s in [-1.0, 1.0]:
		arc(g, Vector3(0, y_naiss, s * (e * .5 - .15)), w * .5, .5, .3, "taille", 0.0, PI, 16)
	voute(g, Vector3.ZERO, w, e, y_naiss, c)
	# une collision au-dessus de la voûte pour ne pas passer à travers le mur depuis le chemin de ronde
	collision(g, Vector3(0, y_naiss + w * .5 + (hauteur - y_naiss - w * .5) * .5, 0), Vector3(w + 2.0, hauteur - y_naiss - w * .5, e))
	# les créneaux au sommet
	creneaux(g, Vector3(-w * .5 - 1.0, 0, e * .5 - .25), Vector3(w * .5 + 1.0, 0, e * .5 - .25), hauteur, .5, c)
	creneaux(g, Vector3(-w * .5 - 1.0, 0, -e * .5 + .25), Vector3(w * .5 + 1.0, 0, -e * .5 + .25), hauteur, .5, c)
	if lanterne_:
		lanterne(g, Vector3(w * .5 + .5, y_naiss - .4, e * .5 + .1), 0.0, true, .5)
	return g

## Une cabane de jardin ou un appentis en planches, avec un toit de tôle ou de tuile.
static func cabane(r: Node3D, p: Vector3, w := 2.4, d := 2.0, h := 2.1, ry := 0.0, c_toit: Variant = "tole") -> Node3D:
	var g := groupe(r, "Cabane", p, ry)
	bloc(g, Vector3(0, h * .5, 0), Vector3(w, h, d), "bois_use", true)
	for i in int(w / .3):
		bloc(g, Vector3(-w * .5 + .15 + i * .3, h * .5, d * .5 + .01), Vector3(.02, h, .02), "bois_sombre")
	var t := bloc(g, Vector3(0, h + .12, 0), Vector3(w + .4, .06, d + .5), c_toit)
	t.rotation.x = -.12
	bloc(g, Vector3(w * .2, h * .45, d * .5 + .03), Vector3(.7, h * .85, .05), "bois_sombre")
	return g

## Un mur percé d'arcs en plein cintre (les écoinçons sont pleins) : longueur l le long de +X local,
## hauteur h, épaisseur e ; ouvertures = [[x_centre, rayon, y_naissance], …]. Les deux faces sont
## dessinées, ainsi que l'intrados de chaque ouverture (double face, pour ne jamais voir le vide).
static func mur_perce(r: Node3D, p: Vector3, l: float, h: float, e: float, ouvertures: Array, c: Variant = "calcaire", ry := 0.0, segments := 12) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := e * .5
	var quads: Array = []  # [[x0, y0, x1, y1]] : des rectangles pleins du mur (x0 < x1, y0 < y1)
	var ouv: Array = ouvertures.duplicate()
	ouv.sort_custom(func(a, b): return a[0] < b[0])
	var x := 0.0
	for o in ouv:
		var xc: float = o[0]
		var ra: float = o[1]
		var yn: float = o[2]
		var xa := clampf(xc - ra, 0.0, l)
		var xb := clampf(xc + ra, 0.0, l)
		if xa > x: quads.append([x, 0.0, xa, h])
		# au-dessus de l'arc : des bandes verticales du bord de l'arc jusqu'au haut du mur
		for i in segments:
			var a0 := PI * float(i) / segments
			var a1 := PI * float(i + 1) / segments
			var x0 := clampf(xc + cos(a0) * ra, 0.0, l)
			var x1 := clampf(xc + cos(a1) * ra, 0.0, l)
			var y0 := minf(yn + sin(a0) * ra, h)
			var y1 := minf(yn + sin(a1) * ra, h)
			if absf(x1 - x0) < .001: continue
			# un trapèze (x0, y0)-(x1, y1)-(x1, h)-(x0, h), dessiné comme deux triangles sur chaque face
			var pf := [Vector3(x0, y0, z), Vector3(x0, h, z), Vector3(x1, h, z), Vector3(x1, y1, z)]
			if x1 < x0: pf = [Vector3(x1, y1, z), Vector3(x1, h, z), Vector3(x0, h, z), Vector3(x0, y0, z)]
			for k in [0, 1, 2, 0, 2, 3]: st.add_vertex(pf[k])
			var pb: Array = []
			for q in pf: pb.append(Vector3(q.x, q.y, -z))
			for k in [0, 2, 1, 0, 3, 2]: st.add_vertex(pb[k])
			# l'intrados, double face
			var i0 := Vector3(xc + cos(a0) * ra, yn + sin(a0) * ra, 0)
			var i1 := Vector3(xc + cos(a1) * ra, yn + sin(a1) * ra, 0)
			var iq := [i0 + Vector3(0, 0, z), i1 + Vector3(0, 0, z), i1 - Vector3(0, 0, z), i0 - Vector3(0, 0, z)]
			for k in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]: st.add_vertex(iq[k])
		# les piédroits (de 0 à la naissance), double face
		for sx in [xc - ra, xc + ra]:
			if sx < 0.0 or sx > l: continue
			var jq := [Vector3(sx, 0, z), Vector3(sx, yn, z), Vector3(sx, yn, -z), Vector3(sx, 0, -z)]
			for k in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]: st.add_vertex(jq[k])
		x = xb
	if x < l: quads.append([x, 0.0, l, h])
	for q in quads:
		var pf := [Vector3(q[0], q[1], z), Vector3(q[0], q[3], z), Vector3(q[2], q[3], z), Vector3(q[2], q[1], z)]
		for k in [0, 1, 2, 0, 2, 3]: st.add_vertex(pf[k])
		var pb: Array = []
		for v in pf: pb.append(Vector3(v.x, v.y, -z))
		for k in [0, 2, 1, 0, 3, 2]: st.add_vertex(pb[k])
	# le dessus et les deux bouts
	var top := [Vector3(0, h, z), Vector3(0, h, -z), Vector3(l, h, -z), Vector3(l, h, z)]
	for k in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]: st.add_vertex(top[k])
	for sx in [0.0, l]:
		var bq := [Vector3(sx, 0, z), Vector3(sx, h, z), Vector3(sx, h, -z), Vector3(sx, 0, -z)]
		for k in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]: st.add_vertex(bq[k])
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat(c)
	m.position = p
	m.rotation.y = ry
	r.add_child(m)
	return m


static var _cles: Dictionary = {}

## La matière d'une clé « teinte hexa:genre » (« cbc1a7:1 »), comme celles du façadier : la matière commune avec
## un genre de surface choisi.
static func matiere(cle: String) -> Material:
	if _cles.has(cle): return _cles[cle]
	var parts := cle.split(":")
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("teinte", Color(parts[0]))
	m.set_shader_parameter("genre", int(parts[1]) if parts.size() > 1 else 0)
	_cles[cle] = m
	return m
