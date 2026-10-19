extends RefCounted
## Le kit de construction de Casino Minuit, porté du moteur web (js/kit.js, js/zones/a-0-commun.js) :
## les mêmes briques avec les mêmes cotes, en mètres. Chaque zone (zones/*.gd) bâtit avec lui : les
## formes sont rangées par matériau et fusionnées à la fin (un maillage par matériau et par zone, comme
## le « put » du moteur web), les volumes qu'on ne traverse pas sont des StaticBody3D.
## Repère du moteur web conservé : x vers l'est, z vers le sud (le nord est -Z), y en haut.
## Angles « boussole » des zones : b = 0 regarde au nord, b = π/2 à l'est ; point(b, R) = (cx + R sin b, cz - R cos b).

const BASE := "res://communes/casino_minuit/"

## La palette de la direction artistique de Minuit (K.pal).
const PAL := {
	"rouge_laque": Color("#B3121F"), "rouge_profond": Color("#7A0E18"), "or": Color("#D9A441"), "or_clair": Color("#F2CF7A"),
	"or_sombre": Color("#8F6C2C"), "laque_noire": Color("#0E0C10"), "ivoire": Color("#F3EAD7"), "marbre_creme": Color("#E9DFCB"),
	"marbre_veine": Color("#B79E7A"), "marbre_noir": Color("#17141A"), "marbre_rouge": Color("#7E2A22"), "ambre": Color("#FFB347"),
	"ambre_chaud": Color("#FF8A2A"), "lumiere": Color("#FFD9A8"), "feutre": Color("#0D5C3F"),
}

## La palette, pour les zones (K.pal.or).
var pal: Dictionary = PAL
var racine: Node3D
## La zone en cours : un nœud par zone, sous la racine.
var zone: Node3D
var _lots := {}
var _mats := {}
var _meshes := {}
var _indexees := {}
var _anim: Array = []
## Les places que les zones laissent aux figurants (sièges, postes, comptoirs), par nom, en coordonnées du casino.
var places := {}


func _init(r: Node3D) -> void:
	racine = r


# --- Zones ----------------------------------------------------------------------------------------

## Ouvre une zone : tout ce qui suit est rangé sous un nœud de ce nom, jusqu'à fin_zone().
func zone_debut(nom: String) -> void:
	zone = Node3D.new()
	zone.name = nom
	racine.add_child(zone)
	_lots = {}


## Ferme la zone : un MeshInstance3D par matériau, toutes les formes fusionnées.
func zone_fin() -> void:
	for cle in _lots:
		var lot: Array = _lots[cle]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for e in lot:
			var m: Mesh = _indexee(e[0])
			for s in m.get_surface_count():
				st.append_from(m, s, e[1])
		var mi := MeshInstance3D.new()
		mi.name = "lot_" + str(cle)
		mi.mesh = st.commit()
		mi.material_override = _mats[cle]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		zone.add_child(mi)
	_lots = {}
	# Les formes d'une zone vivent jusqu'ici : passé la zone, un identifiant peut resservir.
	_indexees = {}


## La forme avec un tableau d'indices : append_from n'ajoute des triangles que par les indices de la
## source, et les primitives de Godot en ont quand les formes du kit (SurfaceTool) n'en ont pas.
func _indexee(m: Mesh) -> Mesh:
	var k := m.get_instance_id()
	if not _indexees.has(k):
		var st := SurfaceTool.new()
		var out := ArrayMesh.new()
		for s in m.get_surface_count():
			st.create_from(m, s)
			st.index()
			st.commit(out)
		_indexees[k] = out
	return _indexees[k]


## Ce qui bouge (fontaines, lustre, porte-tambour) : rappelé à chaque image par la scène.
func chaque_image(f: Callable) -> void:
	_anim.append(f)


func animer(dt: float, t: float) -> void:
	for f in _anim:
		f.call(dt, t)


# --- Matériaux ------------------------------------------------------------------------------------

## Les matériaux de la DA, par nom (K.da) ; un nom inconnu est une erreur du portage.
func mat(nom: String) -> Material:
	if _mats.has(nom):
		return _mats[nom]
	var m: Material
	# « lueur#RRGGBB » : une matière qui luit de cette couleur, vue des deux côtés (fleurs de verre, carpes).
	if nom.begins_with("lueur#"):
		var l := _lueur(Color(nom.substr(5)), 1.4)
		l.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[nom] = l
		return l
	# « aplat#RRGGBB » : une pastille de peinture mate (les aplats de l'atlas du lot D : signalétique,
	# mobilier technique, effets du personnel).
	if nom.begins_with("aplat#"):
		_mats[nom] = _std(Color(nom.substr(5)), 0.62, 0.05)
		return _mats[nom]
	match nom:
		"pierre": m = _marbre(Color("#CBBCA2"), Color("#B3A386"), 0.75, 0.3)
		"pierre_haute": m = _marbre(Color("#8E8371"), Color("#7C715F"), 0.9, 0.3)
		"marbre_creme": m = _marbre(PAL.marbre_creme, PAL.marbre_veine, 0.18)
		"marbre_noir": m = _marbre(PAL.marbre_noir, Color("#6E6878"), 0.12)
		"marbre_rouge": m = _marbre(PAL.marbre_rouge, Color("#D9B8A0"), 0.2)
		"damier":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://shaders/marble_checker.gdshader")
			sm.set_shader_parameter("tile", 1.0)
			m = sm
		"moquette":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://shaders/carpet.gdshader")
			sm.set_shader_parameter("base_col", Color("#4A0C16"))
			sm.set_shader_parameter("motif_col", Color("#8F6C2C"))
			sm.set_shader_parameter("scale", 1.0)
			m = sm
		"or": m = _std(PAL["or"], 0.32, 0.85)
		"or_brosse": m = _std(PAL["or"], 0.5, 0.7)
		"statue_or": m = _std(Color("#C99A3E"), 0.28, 0.9)
		"laque_noire": m = _std(PAL.laque_noire, 0.25, 0.0)
		"laque_rouge": m = _std(PAL.rouge_laque, 0.3, 0.0)
		"coussin": m = _std(PAL.rouge_profond, 0.85, 0.0)
		"bois_laque": m = _std(Color("#2A110B"), 0.4, 0.05)
		"plafond_bas": m = _std(Color("#3A2A22"), 0.8, 0.0)
		"feutre": m = _std(PAL.feutre, 0.95, 0.0)
		"verre":
			var v := _std(Color(0.75, 0.85, 0.85, 0.18), 0.05, 0.1)
			v.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			v.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = v
		"lanterne": m = _lueur(Color("#D2522A"), 1.6)
		"ampoule": m = _lueur(Color("#FFE2B4"), 3.0)
		"gorge": m = _lueur(Color("#C27A30"), 1.4)
		"pendeloque": m = _lueur(Color("#FFE2B4"), 2.2)
		"onyx": m = _shader("onyx")
		"eau": m = _shader("eau")
		"jet": m = _shader("jet")
		"strip": m = _shader("strip")
		"coupole": m = _shader("coupole")
		"rosace": m = _shader("rosace")
		# Le lot B (js/zones/b-0-commun.js) : ses étoffes, ses cuirs, son jardin, ses néons.
		"bois_clair": m = _std(Color("#8A5A32"), 0.45, 0.05)
		"velours": m = _std(Color("#5A0F1C"), 0.9, 0.0)
		"capiton_rouge": m = _std(Color("#7A0E18"), 0.7, 0.0)
		"moquette_b": m = _moquette(Color("#141A3A"), Color("#3A2A5E"))
		"moquette_c": m = _moquette(Color("#1A1430"), Color("#6A5A2A"))
		"moquette_d": m = _moquette(Color("#3A0C14"), Color("#B8893A"))
		"moquette_e": m = _moquette(Color("#170A20"), Color("#7A2A50"))
		"mosaique": m = _marbre(Color("#C8B38A"), Color("#7E2A22"), 0.5, 0.25)
		"dallage": m = _marbre(Color("#C4B08C"), Color("#8E7C5E"), 0.6, 0.4)
		"feutre_hl": m = _std(Color("#6E1423"), 0.95, 0.0)
		"feutre_bleu": m = _std(Color("#1C2C6A"), 0.96, 0.0)
		"housse": m = _std(Color("#3C4560"), 0.92, 0.0)
		"cuir": m = _std(Color("#6A3A1F"), 0.5, 0.0)
		"cuir_noir": m = _std(Color("#1C1618"), 0.42, 0.0)
		"cuir_vert": m = _std(Color("#1F4A38"), 0.5, 0.0)
		"velours_prune": m = _std(Color("#5A1E3C"), 0.9, 0.0)
		"bleu_nuit": m = _std(Color("#1A2452"), 0.85, 0.0)
		"vert_jardin": m = _std(Color("#1D4A30"), 0.9, 0.0)
		"feuille", "feuille_sombre":
			var f := _std(Color("#2F7A48") if nom == "feuille" else Color("#1D5232"), 0.7, 0.0)
			f.cull_mode = BaseMaterial3D.CULL_DISABLED
			f.emission_enabled = true
			f.emission = Color("#0A2412")
			m = f
		"lotus": m = _lueur(Color("#FF8FB3"), 0.6)
		"terre": m = _std(Color("#B5673C"), 0.8, 0.0)
		"tronc": m = _std(Color("#5A4630"), 0.9, 0.0)
		"porcelaine": m = _std(Color("#F3EAD7"), 0.22, 0.0)
		"miroir": m = _std(Color("#D4DCDF"), 0.03, 1.0)
		"faience": m = _std(Color("#EFE4CC"), 0.35, 0.0)
		"ciel_nuit": m = _shader("ciel")
		"treillis": m = _shader("treillis")
		"flamme":
			var f := StandardMaterial3D.new()
			f.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			f.albedo_color = Color(1.0, 0.55, 0.15, 0.85)
			f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			f.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			f.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = f
		"neon_rose": m = _lueur(Color("#D2477E"), 3.0)
		"neon_cyan": m = _lueur(Color("#2EAAB2"), 3.0)
		"neon_ambre": m = _lueur(Color("#DDA03E"), 3.0)
		"neon_rouge": m = _lueur(Color("#D23444"), 3.0)
		"neon_vert": m = _lueur(Color("#3ECF84"), 3.0)
		"ecran": m = _lueur(Color("#3A6AB8"), 1.6)
		"ecran_rose": m = _lueur(Color("#B83A78"), 1.6)
		"ecran_or": m = _lueur(Color("#C89A3A"), 1.6)
		# Le lot C (js/zones/c-0-commun.js) : nappes, cuirs bleus, acier de cuisine, jetons, vitrines, écrans des paris.
		"nappe": m = _std(Color("#F3EAD7"), 0.9, 0.0)
		"creme": m = _std(Color("#E9DFCB"), 0.35, 0.0)
		"noir_poli": m = _std(Color("#1B171F"), 0.2, 0.1)
		"satin": m = _std(Color("#141117"), 0.6, 0.05)
		"bordeaux": m = _std(Color("#4A0C16"), 0.85, 0.0)
		"cuir_bleu": m = _std(Color("#1A2548"), 0.6, 0.0)
		"tissu_bleu": m = _std(Color("#24306A"), 0.85, 0.0)
		"acier": m = _std(Color("#9A9AA0"), 0.3, 0.9)
		"pierre_sombre": m = _std(Color("#A89878"), 0.85, 0.0)
		"ardoise": m = _std(Color("#4A4650"), 0.7, 0.0)
		"jeton_vert": m = _std(Color("#0D5C3F"), 0.5, 0.0)
		"jeton_bleu": m = _std(Color("#24306A"), 0.5, 0.0)
		"jeton_ivoire": m = _std(Color("#F3EAD7"), 0.5, 0.0)
		"ecran_vert": m = _lueur(Color("#4DFF9A"), 1.8)
		"ecran_bleu": m = _lueur(Color("#7FA8FF"), 1.4)
		"gorge_douce": m = _lueur(Color("#B8742E"), 1.0)
		# Le lot D (js/zones/d-commun.js) : le béton peint des coulisses, le béton brut, le lino, le blindage du coffre.
		"beton": m = _std(Color("#B9BDB6"), 0.88, 0.0)
		"brut": m = _std(Color("#878A8F"), 0.92, 0.0)
		"lino": m = _std(Color("#3F5A52"), 0.55, 0.0)
		"blindage":
			var bl := _std(Color("#B0B8C0"), 0.42, 0.75)
			bl.emission_enabled = true
			bl.emission = Color("#15171b")
			m = bl
		"sol_coffre": m = _std(Color("#565C63"), 0.32, 0.25)
		"vitrine":
			var v := _std(Color(0.81, 0.89, 0.92, 0.16), 0.03, 0.0)
			v.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			v.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = v
		# Le lot E, dehors (js/zones/e-0-commun.js, E.M) : la rue, ses métaux, ses lumineux ; les façades, les écrans,
		# les ampoules, le ciel et les voitures sont des shaders, chacun un seul matériau pour tout le Strip.
		"asphalte": m = _marbre(Color("#2A2A2F"), Color("#3A3A40"), 0.75, 0.9)
		"trottoir": m = _marbre(Color("#77777C"), Color("#5A5B61"), 0.82, 0.5)
		"granit": m = _marbre(Color("#2C2930"), Color("#4A4450"), 0.45, 0.35)
		"bordure": m = _std(Color("#A8A49C"), 0.85, 0.0)
		"beton_e": m = _std(Color("#55565C"), 0.92, 0.0)
		"acier_sombre": m = _std(Color("#3A3E44"), 0.45, 0.7)
		"chrome": m = _std(Color("#C8CCD2"), 0.2, 0.9)
		"verre_sombre":
			var vs := _std(Color("#141A26"), 0.08, 0.6)
			vs.emission_enabled = true
			vs.emission = Color("#05070C")
			m = vs
		"pneu": m = _std(Color("#141414"), 0.9, 0.0)
		"blanc": m = _std(Color("#E8E8E4"), 0.6, 0.0)
		"jaune": m = _std(Color("#E8C21A"), 0.6, 0.0)
		"marine": m = _std(Color("#1A2240"), 0.5, 0.0)
		"tapis_rouge": m = _std(Color("#8A1020"), 0.95, 0.0)
		"rouge_sombre": m = _std(Color("#5A0A12"), 0.5, 0.0)
		"rouge_e": m = _std(Color("#B3121F"), 0.25, 0.1)
		"terre_e": m = _std(Color("#2A2018"), 1.0, 0.0)
		"lumiere": m = _lueur(Color("#FFE2B4"), 2.6)
		"fenetre": m = _lueur(Color("#FFD08A"), 1.3)
		"blanc_froid": m = _lueur(Color("#EAF2FF"), 2.2)
		"rouge_lum": m = _lueur(Color("#FF3348"), 2.6)
		"vert_lum": m = _lueur(Color("#4DFF9A"), 2.2)
		"ambre_lum": m = _lueur(Color("#FFB347"), 2.2)
		"cyan_lum": m = _lueur(Color("#3DE0E0"), 2.2)
		"bleu_lum": m = _lueur(Color("#4D7BFF"), 2.2)
		"rose_lum": m = _lueur(Color("#FF4D8D"), 2.4)
		"eau_nuit":
			var en := _shader("eau")
			en.set_shader_parameter("fond", Color("#06141E"))
			en.set_shader_parameter("clair", Color("#1F5A78"))
			m = en
		"facade", "led", "ampoules", "nuit", "faisceau", "vehicule", "foule": m = _shader(nom)
		"palmier":
			var pm := StandardMaterial3D.new()
			pm.vertex_color_use_as_albedo = true
			pm.vertex_color_is_srgb = true
			pm.roughness = 0.85
			pm.cull_mode = BaseMaterial3D.CULL_DISABLED
			pm.emission_enabled = true
			pm.emission = Color("#081208")
			m = pm
		# Le lot F, l'arène et la salle de concert (js/zones/f-0-commun.js, F.mat) : la salle dans le noir.
		"acoustique": m = _std(Color("#2A2630"), 0.92, 0.0)
		"acoustique_bleu": m = _std(Color("#1A2440"), 0.9, 0.0)
		"beton_noir": m = _marbre(Color("#1A1A1E"), Color("#26262C"), 0.8, 0.5)
		"noir_mat": m = _std(Color("#0C0C0E"), 0.95, 0.0)
		"noir_satin": m = _std(Color("#161618"), 0.5, 0.1)
		"alu": m = _std(Color("#B8BCC4"), 0.35, 0.85)
		"gris": m = _std(Color("#4A4C52"), 0.6, 0.4)
		"rouge_ring": m = _std(Color("#B3121F"), 0.6, 0.0)
		"bleu_ring": m = _std(Color("#1D3F8A"), 0.6, 0.0)
		"blanc_ring": m = _std(Color("#EDEDE8"), 0.6, 0.0)
		"tapis_ring": m = _std(Color("#22407A"), 0.85, 0.0)
		"plancher": m = _std(Color("#3A2A1E"), 0.6, 0.0)
		_:
			push_error("Casino Minuit : matériau inconnu « %s »" % nom)
			m = _std(Color.MAGENTA, 1.0, 0.0)
	_mats[nom] = m
	return m


func _std(c: Color, rugosite: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugosite
	m.metallic = metal
	return m


func _lueur(c: Color, energie: float) -> StandardMaterial3D:
	var m := _std(c, 0.6, 0.0)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energie
	return m


func _moquette(fond: Color, motif: Color) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/carpet.gdshader")
	sm.set_shader_parameter("base_col", fond)
	sm.set_shader_parameter("motif_col", motif)
	sm.set_shader_parameter("scale", 1.0)
	return sm


func _marbre(fond: Color, veine: Color, poli: float, echelle := 0.6) -> ShaderMaterial:
	var m := _shader("marbre")
	m.set_shader_parameter("fond", fond)
	m.set_shader_parameter("veine", veine)
	m.set_shader_parameter("poli", poli)
	m.set_shader_parameter("echelle", echelle)
	return m


func _shader(nom: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(BASE + "shaders/%s.gdshader" % nom)
	return m


# --- Formes (fusionnées par matériau) --------------------------------------------------------------

## Une forme dans le lot de son matériau, à la transformation donnée (repère monde).
func put(nom_mat: String, m: Mesh, t := Transform3D.IDENTITY) -> void:
	mat(nom_mat)
	if not _lots.has(nom_mat):
		_lots[nom_mat] = []
	_lots[nom_mat].append([m, t])


## xf(x, y, z, rx, ry, rz, sx, sy, sz) du moteur web : translation, rotation (ordre XYZ), échelle.
static func xf(x: float, y: float, z: float, rx := 0.0, ry := 0.0, rz := 0.0, sx := 1.0, sy := 1.0, sz := 1.0) -> Transform3D:
	var b := Basis.from_euler(Vector3(rx, ry, rz), EULER_ORDER_XYZ).scaled_local(Vector3(sx, sy, sz))
	return Transform3D(b, Vector3(x, y, z))


func _box_mesh(sx: float, sy: float, sz: float) -> Mesh:
	var k := "b%.3f|%.3f|%.3f" % [sx, sy, sz]
	if not _meshes.has(k):
		var b := BoxMesh.new()
		b.size = Vector3(sx, sy, sz)
		_meshes[k] = b
	return _meshes[k]


## Un pavé w × h × d centré en (x, y, z), tourné de ry autour de la verticale.
func box(nom_mat: String, w: float, h: float, d: float, x: float, y: float, z: float, ry := 0.0) -> void:
	put(nom_mat, _box_mesh(w, h, d), xf(x, y, z, 0, ry))


## Un cylindre (rayons haut et bas, hauteur) centré en (x, y, z) ; rx, rz le couchent.
func cyl(nom_mat: String, r_haut: float, r_bas: float, h: float, x: float, y: float, z: float, seg := 12, rx := 0.0, rz := 0.0) -> void:
	var k := "c%.3f|%.3f|%.3f|%d" % [r_haut, r_bas, h, seg]
	if not _meshes.has(k):
		var c := CylinderMesh.new()
		c.top_radius = r_haut
		c.bottom_radius = r_bas
		c.height = h
		c.radial_segments = maxi(seg, 3)
		c.rings = 1
		_meshes[k] = c
	put(nom_mat, _meshes[k], xf(x, y, z, rx, 0, rz))


## Une sphère de rayon r ; sy l'étire en hauteur.
func sph(nom_mat: String, r: float, x: float, y: float, z: float, sy := 1.0) -> void:
	var k := "s%.3f" % r
	if not _meshes.has(k):
		var s := SphereMesh.new()
		s.radius = r
		s.height = 2.0 * r
		s.radial_segments = 10
		s.rings = 6
		_meshes[k] = s
	put(nom_mat, _meshes[k], xf(x, y, z, 0, 0, 0, 1, sy, 1))


## Un tore couché à plat (dans le plan horizontal), de rayon r et d'épaisseur e.
func tore(nom_mat: String, r: float, e: float, t: Transform3D, seg := 24) -> void:
	var k := "t%.3f|%.3f|%d" % [r, e, seg]
	if not _meshes.has(k):
		var m := TorusMesh.new()
		m.inner_radius = r - e
		m.outer_radius = r + e
		m.rings = seg
		m.ring_segments = 6
		_meshes[k] = m
	put(nom_mat, _meshes[k], t)


## Une poutre de section w × h, de A à B.
func beam(nom_mat: String, a: Vector3, b: Vector3, w: float, h: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 1e-4:
		return
	var z := d / l
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	put(nom_mat, _box_mesh(w, h, l), Transform3D(Basis(x, y, z), (a + b) / 2.0))


## Un tour (révolution autour de y) d'un profil [rayon, hauteur], comme LatheGeometry.
func lathe(profil: Array, seg := 12) -> ArrayMesh:
	var k := "l" + str(profil) + str(seg)
	if _meshes.has(k):
		return _meshes[k]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for j in profil.size() - 1:
			var p: Array = profil[j]
			var q: Array = profil[j + 1]
			var v := [Vector3(p[0] * sin(a0), p[1], p[0] * cos(a0)), Vector3(p[0] * sin(a1), p[1], p[0] * cos(a1)),
				Vector3(q[0] * sin(a1), q[1], q[0] * cos(a1)), Vector3(q[0] * sin(a0), q[1], q[0] * cos(a0))]
			_quad(st, v[0], v[1], v[2], v[3], Vector3(sin((a0 + a1) / 2.0), 0, cos((a0 + a1) / 2.0)))
	st.generate_normals()
	var m := st.commit()
	_meshes[k] = m
	return m


## Un quadrilatère, ses faces tournées du côté de la normale de référence n (orientées pour Godot).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, ud := Vector2.ZERO) -> void:
	_tri(st, a, b, c, n, ua, ub, uc)
	_tri(st, a, c, d, n, ua, uc, ud)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	# Godot dessine le devant d'un triangle dont les sommets tournent dans le sens des aiguilles d'une montre.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	for p in [[a, ua], [b, ub], [c, uc]]:
		st.set_uv(p[1])
		st.set_normal(n.normalized() if n.length() > 0.0 else Vector3.UP)
		st.add_vertex(p[0])


## Une bande de révolution (cercle ou ellipse) entre deux bords e = [rx, rz, y], de l'angle a0 à a1
## (A.bande). face : « in » (vue du centre), « out », « up », « down ». u01 : n répétitions de UV sur l'arc.
func bande(nom_mat: String, cx: float, cz: float, e0: Array, e1: Array, a0 := 0.0, a1 := TAU, face := "in", u01 := 0.0, pas := 0.13) -> void:
	var n := maxi(1, ceili(absf(a1 - a0) / pas))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var P := func(e: Array, b: float) -> Vector3: return Vector3(cx + e[0] * sin(b), e[2], cz - e[1] * cos(b))
	var rm: float = (e0[0] + e0[1] + e1[0] + e1[1]) / 4.0
	for i in n:
		var b0 := a0 + (a1 - a0) * i / n
		var b1 := a0 + (a1 - a0) * (i + 1) / n
		var bm := (b0 + b1) / 2.0
		var p0: Vector3 = P.call(e0, b0)
		var p1: Vector3 = P.call(e0, b1)
		var p2: Vector3 = P.call(e1, b1)
		var p3: Vector3 = P.call(e1, b0)
		var radial := Vector3(sin(bm), 0, -cos(bm))
		var ref := Vector3.UP if face == "up" else (Vector3.DOWN if face == "down" else (-radial if face == "in" else radial))
		var u0 := (b0 - a0) / (a1 - a0) * u01 if u01 > 0.0 else rm * b0 / 2.0
		var u1 := (b1 - a0) / (a1 - a0) * u01 if u01 > 0.0 else rm * b1 / 2.0
		var v0: float = e0[2] / 2.0
		var v1: float = e1[2] / 2.0 if u01 <= 0.0 else 1.0
		if u01 > 0.0:
			v0 = 1.0
			v1 = 0.0
		_quad(st, p0, p1, p2, p3, ref, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1))
	put(nom_mat, st.commit())


## Une paroi cylindrique verticale de rayon r, de a0 à a1, entre y0 et y1 (A.arc).
func arc(nom_mat: String, cx: float, cz: float, r: float, a0: float, a1: float, y0: float, y1: float, face := "in", u01 := 0.0) -> void:
	bande(nom_mat, cx, cz, [r, r, y0], [r, r, y1], a0, a1, face, u01)


## Un anneau plat entre les rayons r0 et r1, à la hauteur y (A.anneau).
func anneau(nom_mat: String, cx: float, cz: float, r0: float, r1: float, y: float, a0 := 0.0, a1 := TAU, dessus := true) -> void:
	bande(nom_mat, cx, cz, [r0, r0, y], [r1, r1, y], a0, a1, "up" if dessus else "down")


## Un plan horizontal (sol ou plafond) de x0 à x1 et de z0 à z1, à la hauteur y.
func plan(nom_mat: String, x0: float, x1: float, z0: float, z1: float, y: float, dessus := true) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP if dessus else Vector3.DOWN,
		Vector2(x0, z0) / 2.0, Vector2(x1, z0) / 2.0, Vector2(x1, z1) / 2.0, Vector2(x0, z1) / 2.0)
	put(nom_mat, st.commit())


## Un disque horizontal de rayon r (la rosace, l'eau d'un bassin rond), UV de 0 à 1.
func disque(nom_mat: String, cx: float, cz: float, r: float, y: float, seg := 64) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := Vector3(cx + r * sin(a0), y, cz - r * cos(a0))
		var p1 := Vector3(cx + r * sin(a1), y, cz - r * cos(a1))
		_tri(st, Vector3(cx, y, cz), p0, p1, Vector3.UP, Vector2(0.5, 0.5), Vector2(0.5 + 0.5 * sin(a0), 0.5 - 0.5 * cos(a0)), Vector2(0.5 + 0.5 * sin(a1), 0.5 - 0.5 * cos(a1)))
	put(nom_mat, st.commit())


# --- Volumes qu'on ne traverse pas ---------------------------------------------------------------

## Un pavé de collision w × h × d centré en (x, y, z).
func solide(w: float, h: float, d: float, x: float, y: float, z: float, ry := 0.0) -> void:
	var corps := StaticBody3D.new()
	corps.position = Vector3(x, y, z)
	corps.rotation.y = ry
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(w, h, d)
	f.shape = b
	corps.add_child(f)
	zone.add_child(corps)


## Un rectangle au sol qu'on ne traverse pas (addBox du moteur web), haut de h.
func obstacle(x0: float, x1: float, z0: float, z1: float, y := 0.0, h := 2.4) -> void:
	solide(absf(x1 - x0), h, absf(z1 - z0), (x0 + x1) / 2.0, y + h / 2.0, (z0 + z1) / 2.0)


## Un cylindre qu'on ne traverse pas (addCircle).
func rond(x: float, z: float, r: float, y := 0.0, h := 2.4) -> void:
	var corps := StaticBody3D.new()
	corps.position = Vector3(x, y + h / 2.0, z)
	var f := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	f.shape = c
	corps.add_child(f)
	zone.add_child(corps)


## Un segment qu'on ne traverse pas, d'épaisseur e (addSeg : garde-corps, tambour).
func segment(ax: float, az: float, bx: float, bz: float, e := 0.12, y := 0.0, h := 2.4) -> void:
	var l := Vector2(bx - ax, bz - az).length()
	solide(l, h, e, (ax + bx) / 2.0, y + h / 2.0, (az + bz) / 2.0, atan2(-(bz - az), bx - ax))


## Une dalle où l'on marche (addWalkable) : sa face du dessus à la hauteur y.
func dalle(x0: float, x1: float, z0: float, z1: float, y := 0.0) -> void:
	solide(absf(x1 - x0), 0.3, absf(z1 - z0), (x0 + x1) / 2.0, y - 0.15, (z0 + z1) / 2.0)


## Une rampe de collision sous une volée de marches (addLink 'stairs') : de (x, y0, z0) à (x, y1, z1).
func rampe(x: float, largeur: float, z0: float, y0: float, z1: float, y1: float) -> void:
	var dz := z1 - z0
	var dy := y1 - y0
	var l := Vector2(dz, dy).length()
	var corps := StaticBody3D.new()
	corps.position = Vector3(x, (y0 + y1) / 2.0 - 0.15, (z0 + z1) / 2.0)
	corps.rotation.x = atan2(dy, -dz) if dz < 0.0 else -atan2(dy, dz)
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(largeur, 0.3, l)
	f.shape = b
	corps.add_child(f)
	zone.add_child(corps)


# --- Lumière, textes ------------------------------------------------------------------------------

## Une lumière ponctuelle (addLight). Le rendu Mobile n'en prend que huit par objet : les zones en
## posent peu, et la lumière de la salle vient surtout des matériaux qui luisent.
func lumiere(x: float, y: float, z: float, c: Color, energie: float, portee: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = Vector3(x, y, z)
	l.light_color = c
	l.light_energy = energie
	l.omni_range = portee
	l.omni_attenuation = 1.4
	zone.add_child(l)
	return l


## Une inscription (« grave » : lettres d'or gravées) ou une enseigne (« neon » : ivoire à halo ambre),
## de largeur w et de hauteur h, lue depuis la direction ry.
func texte(t: String, w: float, h: float, x: float, y: float, z: float, ry: float, style := "grave", couleur := Color()) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = Polices.titre() if style == "neon" else Polices.gras()
	l.font_size = 96
	l.pixel_size = h / 96.0 * 0.95
	l.width = 4000
	l.position = Vector3(x, y, z)
	l.rotation.y = ry
	l.double_sided = false
	l.shaded = false
	if style == "neon":
		l.modulate = couleur if couleur != Color() else PAL.ivoire
		l.outline_modulate = Color(PAL.ambre_chaud, 0.85)
		l.outline_size = 22
	else:
		l.modulate = couleur if couleur != Color() else PAL.or_clair
		l.outline_modulate = Color("#5A4318")
		l.outline_size = 6
	# La largeur demandée est un maximum : un texte trop long est réduit pour y tenir.
	var f: Font = l.font
	var largeur := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size
	if largeur > w:
		l.pixel_size *= w / largeur
	zone.add_child(l)
	return l


## Un objet qu'on regarde en appuyant sur E : une zone d'interaction (fp_player cherche « interact »).
func interaction(id: String, invite: String, x: float, y: float, z: float, taille: Vector3) -> Area3D:
	var a := Area3D.new()
	a.name = id
	a.position = Vector3(x, y, z)
	a.set_meta("interact", id)
	a.set_meta("prompt", invite)
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = taille
	f.shape = b
	a.add_child(f)
	zone.add_child(a)
	return a


# --- Pièces du décor (kit.js et a-0-commun.js) ----------------------------------------------------

## Colonne (K.colonne) : socle de marbre rouge, fût galbé crème, tores et chapiteau d'or. o : D, H, colossale.
func colonne(x: float, z: float, D := 0.5, H := 4.6, colossale := false, collision := true, y := 0.0) -> void:
	var R := D / 2.0
	var k := D / 1.1
	var seg := 16 if colossale else 12
	var hs := 0.5 * k + 0.1
	var hc := 0.9 * k
	var y0 := hs + 0.3 * k
	var y1 := H - hc - 0.2 * k
	var fut := []
	for t in [0.0, 0.12, 0.33, 0.5, 0.66, 0.82, 0.94, 1.0]:
		fut.append([R * (1.0 + 0.02 * t / 0.33 if t < 0.33 else 1.02 - 0.165 * (t - 0.33) / 0.67), t * (y1 - y0)])
	var chap := []
	for p in [[0.855, 0.0], [0.9, 0.25], [1.1, 0.6], [1.45, 0.9], [1.45, 1.0]]:
		chap.append([R * p[0], hc * p[1]])
	box("marbre_rouge", 1.6 * k, hs, 1.6 * k, x, y + hs / 2.0, z)
	put("marbre_creme", lathe(fut, seg), xf(x, y + y0, z))
	for p in [[0.62, hs + 0.06 * k], [0.58, hs + 0.2 * k]]:
		tore("or", p[0] * k, 0.07 * k, xf(x, y + p[1], z), seg)
	put("or", lathe(chap, seg), xf(x, y + y1, z))
	box("or", 1.7 * k, 0.2 * k, 1.7 * k, x, y + H - 0.1 * k, z)
	if colossale:
		for i in 8:
			var a := i * PI / 4.0
			put("or_brosse", _box_mesh(0.18 * k, 0.5 * k, 0.05), xf(x + sin(a) * R * 1.25, y + y1 + hc * 0.55, z + cos(a) * R * 1.25, 0, a, -0.35))
	if collision:
		rond(x, z, 0.8 * k + 0.02, y)


## Pilastre contre un mur (K.pilastre) : (x, z) au pied de la face collée, ry = la direction où il regarde.
func pilastre(x: float, z: float, ry: float, h: float, w := 0.6, d := 0.15) -> void:
	var px := x + sin(ry) * d / 2.0
	var pz := z + cos(ry) * d / 2.0
	box("marbre_creme", w, h, d, px, h / 2.0, pz, ry)
	box("or", w + 0.08, 0.12, d + 0.06, px, 0.06, pz, ry)
	box("or", w + 0.08, 0.14, d + 0.06, px, h - 0.4, pz, ry)


## Lanterne rouge (A.lanterne) : le bas à y ; s l'échelle, cord la tige qui la pend.
func lanterne(x: float, y: float, z: float, s := 1.0, cord := 0.0) -> void:
	var n := 6 if s < 0.7 else 8
	put("lanterne", lathe([[0.26, 0.0], [0.38, 0.16], [0.42, 0.35], [0.38, 0.54], [0.26, 0.7]], n), xf(x, y, z, 0, 0, 0, s, s, s))
	cyl("or", 0.28 * s, 0.28 * s, 0.05 * s, x, y, z, n)
	cyl("or", 0.28 * s, 0.28 * s, 0.05 * s, x, y + 0.7 * s, z, n)
	cyl("or", 0.025 * s, 0.05 * s, 0.22 * s, x, y - 0.13 * s, z, 4)
	if cord > 0.0:
		cyl("or", 0.011, 0.011, cord, x, y + 0.72 * s + cord / 2.0, z, 3)


## Statue drapée sur socle (K.statue). attribut : « roue », « amphore », « corne » ou « ».
func statue(x: float, z: float, h := 2.2, socle := 0.5, ry := 0.0, nom_mat := "marbre_creme", attribut := "") -> void:
	var s := h / 2.2
	var sx := sin(ry)
	var cz := cos(ry)
	if socle > 0.0:
		box("marbre_rouge", 0.9 * s, socle, 0.9 * s, x, socle / 2.0, z, ry)
	put(nom_mat, lathe([[0.36, 0.0], [0.3, 0.3], [0.24, 0.7], [0.2, 1.0], [0.22, 1.2], [0.16, 1.35]], 10), xf(x, socle, z, 0, 0, 0, s, s, s))
	cyl(nom_mat, 0.14 * s, 0.2 * s, 0.45 * s, x, socle + 1.55 * s, z, 10)
	sph(nom_mat, 0.14 * s, x, socle + 1.95 * s, z, 1.15)
	beam(nom_mat, Vector3(x + cz * 0.2 * s, socle + 1.7 * s, z - sx * 0.2 * s), Vector3(x + cz * 0.34 * s + sx * 0.3 * s, socle + 1.25 * s, z - sx * 0.34 * s + cz * 0.3 * s), 0.09 * s, 0.09 * s)
	beam(nom_mat, Vector3(x - cz * 0.2 * s, socle + 1.7 * s, z + sx * 0.2 * s), Vector3(x - cz * 0.45 * s, socle + 2.15 * s, z + sx * 0.45 * s), 0.09 * s, 0.09 * s)
	var ax := x - cz * 0.5 * s
	var az := z + sx * 0.5 * s
	var ay := socle + 2.3 * s
	match attribut:
		"roue": tore(nom_mat, 0.3 * s, 0.035 * s, xf(ax, ay, az, PI / 2.0, ry, 0), 18)
		"amphore": cyl(nom_mat, 0.07 * s, 0.14 * s, 0.4 * s, ax, ay, az, 8)
		"corne": cyl(nom_mat, 0.14 * s, 0.02, 0.5 * s, ax, ay, az, 8, 0, 0.5)


## Garde-corps de verre et de laiton (K.gardeCorps), avec sa collision.
func garde_corps(x0: float, z0: float, x1: float, z1: float, y := 0.0, h := 1.1) -> void:
	var l := Vector2(x1 - x0, z1 - z0).length()
	var n := maxi(1, roundi(l / 2.0))
	beam("verre", Vector3(x0, y + h / 2.0, z0), Vector3(x1, y + h / 2.0, z1), 0.02, h - 0.1)
	beam("or", Vector3(x0, y + h, z0), Vector3(x1, y + h, z1), 0.06, 0.06)
	beam("laque_noire", Vector3(x0, y + 0.04, z0), Vector3(x1, y + 0.04, z1), 0.08, 0.08)
	for i in n + 1:
		var t := float(i) / n
		cyl("or", 0.025, 0.025, h, lerpf(x0, x1, t), y + h / 2.0, lerpf(z0, z1, t), 8)
	segment(x0, z0, x1, z1, 0.1, y, 1.3)


## Une ligne de balustres (A.balustres) : socle et main courante, balustres tournés tous les 0,52 m.
func balustres(a: Vector3, b: Vector3, nom_mat := "marbre_creme", collision := false) -> void:
	var l := Vector2(b.x - a.x, b.z - a.z).length()
	var n := maxi(1, roundi(l / 0.52))
	beam(nom_mat, a + Vector3(0, 0.075, 0), b + Vector3(0, 0.075, 0), 0.22, 0.15)
	beam(nom_mat, a + Vector3(0, 0.95, 0), b + Vector3(0, 0.95, 0), 0.2, 0.1)
	var tourne := lathe([[0.06, 0.0], [0.095, 0.12], [0.05, 0.3], [0.085, 0.5], [0.05, 0.68], [0.075, 0.75]], 6)
	for i in n:
		var t := (i + 0.5) / n
		put(nom_mat, tourne, xf(lerpf(a.x, b.x, t), lerpf(a.y, b.y, t) + 0.15, lerpf(a.z, b.z, t)))
	if collision:
		segment(a.x, a.z, b.x, b.z, 0.22, minf(a.y, b.y), 1.3)


## Mur de la nef (A.mur) : pierre, lambris de marbre de 1,2 m, filets d'or, corniche. openings : [{at, w, h}]
## en mètres depuis (x0, z0) ; (nx, nz) la normale côté salle.
func mur(x0: float, z0: float, x1: float, z1: float, h: float, nx: float, nz: float, openings := [], pierre := "pierre", lambris := 1.2, corniche := true, y := 0.0) -> void:
	var l := Vector2(x1 - x0, z1 - z0).length()
	var ux := (x1 - x0) / l
	var uz := (z1 - z0) / l
	var ry := atan2(-uz, ux)
	var ops := openings.duplicate()
	ops.sort_custom(func(a, b): return a.at < b.at)
	# Les trumeaux pleins, et au-dessus de chaque baie, le linteau jusqu'en haut.
	var s := 0.0
	var pleins := []
	for op in ops:
		pleins.append([s, maxf(0.0, op.at - op.w / 2.0)])
		var m: float = op.at
		if h - op.h > 0.02:
			box(pierre, op.w, h - op.h, 0.2, x0 + ux * m, y + (op.h + h) / 2.0, z0 + uz * m, ry)
		s = minf(l, op.at + op.w / 2.0)
	pleins.append([s, l])
	for p in pleins:
		var a: float = p[0]
		var b: float = p[1]
		if b - a < 0.05:
			continue
		var m := (a + b) / 2.0
		var px := x0 + ux * m
		var pz := z0 + uz * m
		box(pierre, b - a, h, 0.2, px, y + h / 2.0, pz, ry)
		solide(b - a, h, 0.2, px, y + h / 2.0, pz, ry)
		if lambris > 0.0:
			var lx := px + nx * 0.125
			var lz := pz + nz * 0.125
			box("marbre_creme", b - a, lambris, 0.05, lx, y + lambris / 2.0, lz, ry)
			box("or", b - a, 0.05, 0.07, lx, y + lambris + 0.025, lz, ry)
			box("or", b - a, 0.1, 0.07, lx, y + 0.05, lz, ry)
	if corniche:
		var cx := (x0 + x1) / 2.0 + nx * 0.2
		var cz := (z0 + z1) / 2.0 + nz * 0.2
		box(pierre, l, 0.3, 0.3, cx, y + h - 0.15, cz, ry)
		box("or", l, 0.05, 0.36, cx, y + h - 0.325, cz, ry)
		box("gorge", l, 0.04, 0.05, (x0 + x1) / 2.0 + nx * 0.37, y + h - 0.37, (z0 + z1) / 2.0 + nz * 0.37, ry)


## Arche plein cintre (A.arche) sur une baie déjà percée : tympan, archivolte d'or, clé, impostes.
## (x, z) le centre de la baie, ry = 0 pour un mur le long de x, π/2 le long de z ; cle : hauteur de la clé.
func arche(x: float, z: float, ry: float, w: float, cle: float, y := 0.0, d := 0.42) -> void:
	var r := w / 2.0
	var naissance := y + cle - r
	var c := cos(ry)
	var s := sin(ry)
	# Le tympan : ce qui est hors du demi-cercle, entre la naissance et le haut de la baie.
	var n := 9
	for i in n:
		var t0 := PI * i / (2 * n)
		var t1 := PI * (i + 1) / (2 * n)
		var hx := r * cos(t1)
		var w0 := r * (cos(t0) - cos(t1))
		var y0 := r * sin(t0)
		for sg in [-1.0, 1.0]:
			var lx: float = sg * (hx + w0 / 2.0)
			box("pierre", w0, r - y0, d, x + c * lx, naissance + (r + y0) / 2.0, z - s * lx, ry)
	put("or", _arc_or(r - 0.04, r + 0.16, d + 0.1, 20), xf(x, naissance, z, 0, ry))
	box("or", 0.34, 0.46, d + 0.16, x, naissance + r + 0.04, z, ry)
	for sg in [-1.0, 1.0]:
		box("or", 0.3, 0.14, d + 0.14, x + c * sg * (r + 0.09), naissance - 0.07, z - s * sg * (r + 0.09), ry)


## L'archivolte : un demi-anneau plat (dans le plan x, y local) d'épaisseur d.
func _arc_or(r0: float, r1: float, d: float, n: int) -> ArrayMesh:
	var k := "a%.3f|%.3f|%.3f" % [r0, r1, d]
	if _meshes.has(k):
		return _meshes[k]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var t0 := PI * i / n
		var t1 := PI * (i + 1) / n
		var a0 := Vector3(r0 * cos(t0), r0 * sin(t0), 0)
		var a1 := Vector3(r0 * cos(t1), r0 * sin(t1), 0)
		var b0 := Vector3(r1 * cos(t0), r1 * sin(t0), 0)
		var b1 := Vector3(r1 * cos(t1), r1 * sin(t1), 0)
		var dz := Vector3(0, 0, d / 2.0)
		_quad(st, a0 + dz, a1 + dz, b1 + dz, b0 + dz, Vector3.BACK)
		_quad(st, a0 - dz, a1 - dz, b1 - dz, b0 - dz, Vector3.FORWARD)
		_quad(st, a0 - dz, a1 - dz, a1 + dz, a0 + dz, -Vector3(cos((t0 + t1) / 2.0), sin((t0 + t1) / 2.0), 0))
		_quad(st, b0 - dz, b1 - dz, b1 + dz, b0 + dz, Vector3(cos((t0 + t1) / 2.0), sin((t0 + t1) / 2.0), 0))
	var m := st.commit()
	_meshes[k] = m
	return m


## Cadre d'or d'une baie rectangulaire sur l'épaisseur du mur (A.cadre).
func cadre(x: float, z: float, ry: float, w: float, h: float, d := 0.46, t := 0.14) -> void:
	box("or", w + 2 * t, t, d, x, h - t / 2.0, z, ry)
	for sg in [-1.0, 1.0]:
		box("or", t, h - t, d, x + cos(ry) * sg * (w / 2.0 - t / 2.0), (h - t) / 2.0, z - sin(ry) * sg * (w / 2.0 - t / 2.0), ry)


## Seuil (A.seuil) : une frise d'or de 0,25 m posée au sol de A à B.
func seuil(x0: float, z0: float, x1: float, z1: float, y := 0.0) -> void:
	var l := Vector2(x1 - x0, z1 - z0).length()
	box("or_brosse", l, 0.006, 0.25, (x0 + x1) / 2.0, y + 0.004, (z0 + z1) / 2.0, atan2(-(z1 - z0), x1 - x0))


## Entablement de la nef (A.entablement) : architrave, frise d'or, corniche et gorge, base à y, haut de 1,5 m.
func entablement(x0: float, z0: float, x1: float, z1: float, y: float, w := 1.1, pierre := "pierre") -> void:
	var mx := (x0 + x1) / 2.0
	var mz := (z0 + z1) / 2.0
	var l := Vector2(x1 - x0, z1 - z0).length()
	var ry := atan2(-(z1 - z0), x1 - x0)
	box(pierre, l, 0.45, w, mx, y + 0.225, mz, ry)
	box("or", l, 0.5, w - 0.12, mx, y + 0.7, mz, ry)
	box(pierre, l, 0.2, w + 0.2, mx, y + 1.05, mz, ry)
	box(pierre, l, 0.35, w + 0.55, mx, y + 1.325, mz, ry)
	var ox := -(z1 - z0) / l
	var oz := (x1 - x0) / l
	for sg in [-1.0, 1.0]:
		box("gorge", l, 0.04, 0.05, mx + ox * sg * (w / 2.0 + 0.2), y + 1.13, mz + oz * sg * (w / 2.0 + 0.2), ry)


## Coupole (K.dome) vue de dessous : une calotte de rayon r, haute de h, ouverte d'un oculus.
func coupole(cx: float, y: float, cz: float, r: float, h: float, oculus: float, nom_mat := "coupole", seg := 40) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rangs := 10
	var tmax := acos(clampf(oculus / r, 0.0, 1.0))
	for j in rangs:
		var t0 := tmax * j / rangs
		var t1 := tmax * (j + 1) / rangs
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var P := func(a: float, t: float) -> Vector3: return Vector3(cx + r * cos(t) * sin(a), y + h * sin(t), cz - r * cos(t) * cos(a))
			var c := Vector3(cx, y, cz)
			var p0: Vector3 = P.call(a0, t0)
			var p1: Vector3 = P.call(a1, t0)
			var p2: Vector3 = P.call(a1, t1)
			var p3: Vector3 = P.call(a0, t1)
			# Vue de dessous : les faces regardent le centre de la coupole ; le shader peint la face arrière (cull_front).
			_quad(st, p0, p1, p2, p3, ((p0 + p2) / 2.0 - c).normalized(),
				Vector2(float(i) / seg, float(j) / rangs), Vector2(float(i + 1) / seg, float(j) / rangs),
				Vector2(float(i + 1) / seg, float(j + 1) / rangs), Vector2(float(i) / seg, float(j + 1) / rangs))
	put(nom_mat, st.commit())
	var ox := oculus
	tore("or", ox, 0.06, xf(cx, y + h * sin(tmax), cz), 32)


## Lustre à deux anneaux (K.lustreAnneau) : le bas à y, R le rayon, cord la tige.
func lustre_anneau(x: float, y: float, z: float, R := 1.2, cord := 0.0) -> void:
	for p in [[R, 0.0, 10], [R * 0.58, 0.45 * R, 6]]:
		tore("or", p[0], 0.04 * R, xf(x, y + p[1], z), 28)
		for i in p[2]:
			var a: float = TAU * i / p[2]
			sph("ampoule", 0.07 * R, x + cos(a) * p[0], y + p[1] - 0.08 * R, z + sin(a) * p[0], 1.25)
	if cord > 0.0:
		cyl("or", 0.02, 0.02, cord, x, y + 0.45 * R + cord / 2.0, z, 6)


## Urne tournée (K.urne).
func urne(x: float, z: float, h := 1.1) -> void:
	var s := h / 1.1
	put("marbre_creme", lathe([[0.2, 0.0], [0.16, 0.06], [0.08, 0.2], [0.1, 0.32], [0.3, 0.55], [0.36, 0.8], [0.28, 0.98], [0.34, 1.1]], 12), xf(x, 0, z, 0, 0, 0, s, s, s))
	rond(x, z, 0.38 * s)


## Jets d'eau verticaux animés : une colonne par jet, sa hauteur suivie par anim(i, t) entre 0 et 1.
func jets(liste: Array, y: float, anim: Callable) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var c := CylinderMesh.new()
	c.top_radius = 0.4
	c.bottom_radius = 1.0
	c.height = 1.0
	c.radial_segments = 6
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	mm.mesh = c
	mm.instance_count = liste.size()
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat("jet")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(mi)
	chaque_image(func(_dt, t):
		for i in liste.size():
			var j: Dictionary = liste[i]
			var hh: float = maxf(0.02, j.h * anim.call(i, t))
			var r: float = j.get("r", 0.05)
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(r, hh, r)), Vector3(j.x, y + hh / 2.0, j.z))))


## Un arc d'eau parabolique de (x0, y0, z0) à (x1, y0, z1), de flèche H (A.jetArc).
func jet_arc(x0: float, y0: float, z0: float, x1: float, z1: float, H: float, r := 0.035) -> void:
	var seg := 12
	var cotes := 5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var l := Vector2(x1 - x0, z1 - z0).length()
	var ux := (x1 - x0) / l
	var uz := (z1 - z0) / l
	var anneaux := []
	for i in seg + 1:
		var s := float(i) / seg
		var c := Vector3(lerpf(x0, x1, s), y0 + 4.0 * H * s * (1.0 - s), lerpf(z0, z1, s))
		var tw := r * (0.7 + 1.1 * s)
		var a := []
		for k in cotes + 1:
			var ang := TAU * k / cotes
			a.append(c + Vector3(-uz * cos(ang) * tw, sin(ang) * tw, ux * cos(ang) * tw))
		anneaux.append([a, c])
	for i in seg:
		for k in cotes:
			var p: Array = anneaux[i][0]
			var q: Array = anneaux[i + 1][0]
			var n: Vector3 = (p[k] + q[k + 1]) / 2.0 - (anneaux[i][1] + anneaux[i + 1][1]) / 2.0
			_quad(st, p[k], p[k + 1], q[k + 1], q[k], n, Vector2(float(k) / cotes, i * 3.0 / seg), Vector2(float(k + 1) / cotes, i * 3.0 / seg),
				Vector2(float(k + 1) / cotes, (i + 1) * 3.0 / seg), Vector2(float(k) / cotes, (i + 1) * 3.0 / seg))
	put("jet", st.commit())
