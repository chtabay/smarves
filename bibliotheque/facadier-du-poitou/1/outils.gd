extends RefCounted
## Les outils du façadier : la palette, la matière commune (matieres.gdshader), les collisions partagées,
## la fusion par genre de matière, l'escalier et la rampe. Extraits de l'atelier de Chauvigny (MIT, lui-même
## adapté de celui de Civaux), sans ce qui tient au terrain de Chauvigny. Unités en mètres ; un bâtiment
## regarde vers +Z avant rotation.
const SURFACE := preload("res://bibliotheque/facadier-du-poitou/1/matieres.gdshader")
const FEUILLAGE := preload("res://bibliotheque/facadier-du-poitou/1/feuillage.gdshader")

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

