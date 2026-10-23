extends RefCounted
## La menuiserie du bar de Selim (Cloué 1.6.2, MIT) : géométrie répétée regroupée par matériau, une
## instanciation par forme et par matière (achever). L'étude en hérite pour sa palette et son mobilier.
const MATIERES := preload("res://bibliotheque/etude-de-notaire/1/bar_matieres.gdshader")
var racine: Node3D
var mat: Dictionary = {}
var lots: Dictionary = {}
var _unit_box := BoxMesh.new()
var _unit_cyl := CylinderMesh.new()
var _unit_cone := CylinderMesh.new()
var _soft_box: ArrayMesh

func _init(parent: Node3D) -> void:
	racine = parent
	_unit_box.size = Vector3.ONE
	_unit_cyl.top_radius = 0.5
	_unit_cyl.bottom_radius = 0.5
	_unit_cyl.height = 1.0
	_unit_cyl.radial_segments = 20
	_unit_cone.top_radius = 0.26
	_unit_cone.bottom_radius = 0.5
	_unit_cone.height = 1.0
	_unit_cone.radial_segments = 20
	_soft_box = _coussin_arrondi()
	for fiche in [
		["bois", "58331e", 1, 0.54], ["chene", "9f6638", 1, 0.62],
		["parquet", "986039", 0, 0.57], ["brique", "664135", 2, 0.91],
		["cuir", "502027", 3, 0.72], ["cuir_vert", "193c35", 3, 0.76]]:
		var m := ShaderMaterial.new()
		m.shader = MATIERES
		m.set_shader_parameter("teinte", Color(fiche[1]))
		m.set_shader_parameter("motif", fiche[2])
		m.set_shader_parameter("rugosite", fiche[3])
		mat[fiche[0]] = m
	for fiche in [
		["acier", "161c1c", 0.48, 0.65], ["plafond", "151b1d", 0.92, 0.0],
		["laiton", "ad8950", 0.34, 0.72], ["cuivre", "77533a", 0.46, 0.55],
		["pierre", "292d2c", 0.5, 0.0], ["creme", "d7cfb1", 0.76, 0.0],
		["vert", "1c3e35", 0.65, 0.0], ["feutre", "174b41", 0.97, 0.0],
		["bleu", "24394a", 0.65, 0.0], ["rouge", "953c38", 0.61, 0.0],
		["verre", "506c61", 0.2, 0.25], ["ambre", "986026", 0.21, 0.2],
		["bouteille", "294d31", 0.24, 0.1], ["chrome", "8d999a", 0.23, 0.8]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(fiche[1])
		m.roughness = fiche[2]
		m.metallic = fiche[3]
		mat[fiche[0]] = m
	for fiche in [["led", "ffc27a"], ["ecran", "628f9f"], ["sortie", "b8d6b2"]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(fiche[1])
		m.emission_enabled = true
		m.emission = Color(fiche[1])
		m.emission_energy_multiplier = 1.3
		mat[fiche[0]] = m

func b(p: Vector3, s: Vector3, m: String, rotation := Vector3.ZERO) -> void:
	_ajouter("b", p, s, m, rotation)

func doux(p: Vector3, s: Vector3, m: String, rotation := Vector3.ZERO) -> void:
	_ajouter("soft", p, s, m, rotation)

func _coussin_arrondi() -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grille := [-0.5, -0.486, -0.455, -0.41, 0.41, 0.455, 0.486, 0.5]
	for face in [[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP]]:
		# Chaque face est subdivisée seulement près de son bord ; centre plan, angles doux.
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		# S'assurer que le repère donne le front conventionnel Godot (triangles horaires).
		if u.cross(v).dot(normal) < 0: u = -u
		for i in grille.size() - 1:
			for j in grille.size() - 1:
				for coin in [Vector2i(i,j), Vector2i(i,j+1), Vector2i(i+1,j), Vector2i(i+1,j), Vector2i(i,j+1), Vector2i(i+1,j+1)]:
					var origine := normal * 0.5 + u * float(grille[coin.x]) + v * float(grille[coin.y])
					var coeur := origine.clamp(Vector3.ONE * -0.41, Vector3.ONE * 0.41)
					var n := (origine - coeur).normalized()
					outil.set_normal(n)
					outil.set_uv(Vector2(float(grille[coin.x]) + 0.5, float(grille[coin.y]) + 0.5))
					outil.add_vertex(coeur + n * 0.09)
	return outil.commit()

func c(p: Vector3, diametre: float, hauteur: float, m: String, rotation := Vector3.ZERO, cone := false) -> void:
	_ajouter("cone" if cone else "c", p, Vector3(diametre, hauteur, diametre), m, rotation)

func _ajouter(forme: String, p: Vector3, s: Vector3, m: String, rotation: Vector3) -> void:
	var cle := forme + ":" + m
	if not lots.has(cle): lots[cle] = []
	lots[cle].append(Transform3D(Basis.from_euler(rotation).scaled(s), p))

func solide(p: Vector3, s: Vector3, nom := "Mobilier") -> void:
	var n := StaticBody3D.new()
	n.name = nom
	n.position = p
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = s
	col.shape = box
	n.add_child(col)
	racine.add_child(n)

func texte(t: String, p: Vector3, taille := 0.004, angle := 0.0, couleur := Color("e1c99e")) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = Polices.gras()
	l.font_size = 48
	l.pixel_size = taille
	l.outline_size = 0
	l.modulate = couleur
	l.position = p
	l.rotation.y = angle
	l.shaded = false
	racine.add_child(l)
	return l

func achever() -> void:
	var total := 0
	for cle: String in lots:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var forme := cle.get_slice(":", 0)
		mm.mesh = _unit_box if forme == "b" else (_soft_box if forme == "soft" else (_unit_cone if forme == "cone" else _unit_cyl))
		mm.instance_count = lots[cle].size()
		for i in mm.instance_count: mm.set_instance_transform(i, lots[cle][i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Lot_" + cle.replace(":", "_")
		instance.multimesh = mm
		instance.material_override = mat[cle.get_slice(":", 1)]
		racine.add_child(instance)
		total += mm.instance_count
	racine.set_meta("decor_instances", total)
	racine.set_meta("decor_lots", lots.size())
	lots.clear()

func lumiere(p: Vector3, energie: float, portee: float, couleur := Color("ffc58d"), ombre := false) -> void:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = couleur
	l.light_energy = energie
	l.omni_range = portee
	l.omni_attenuation = 1.65
	l.shadow_enabled = ombre
	racine.add_child(l)

func suspension(p: Vector3, rayon := 0.42, fil := 0.6) -> void:
	c(p + Vector3(0, fil * 0.5 + 0.16, 0), 0.026, fil, "acier")
	c(p, rayon * 2, 0.32, "vert", Vector3.ZERO, true)
	c(p + Vector3(0, -0.17, 0), rayon * 1.85, 0.026, "laiton")
	c(p + Vector3(0, -0.186, 0), rayon * 1.63, 0.012, "led")

func verre(p: Vector3, biere := false) -> void:
	c(p + Vector3(0, 0.11, 0), 0.14, 0.22, "ambre" if biere else "verre")
	c(p + Vector3(0, 0.224, 0), 0.142, 0.013, "creme" if biere else "chrome")
	c(p + Vector3(0, 0.015, 0), 0.155, 0.025, "chrome")

func bouteille(p: Vector3, index: int) -> void:
	var m: String = ["bouteille", "ambre", "verre"][index % 3]
	c(p + Vector3(0, 0.14, 0), 0.13, 0.28, m)
	c(p + Vector3(0, 0.3, 0), 0.13, 0.07, m, Vector3.ZERO, true)
	c(p + Vector3(0, 0.38, 0), 0.055, 0.12, m)
	c(p + Vector3(0, 0.443, 0), 0.06, 0.035, "laiton")
	c(p + Vector3(0, 0.15, 0), 0.132, 0.1, "creme")

func tabouret(p: Vector3, angle := 0.0, haut := 0.74) -> void:
	var rot := Vector3(0, angle, 0)
	c(p + Vector3(0, haut, 0), 0.52, 0.13, "cuir")
	c(p + Vector3(0, haut - 0.095, 0), 0.48, 0.06, "bois")
	for x in [-0.17, 0.17]:
		for z in [-0.17, 0.17]:
			b(p + Vector3(x, haut * 0.44, z).rotated(Vector3.UP, angle), Vector3(0.04, haut * 0.88, 0.04), "acier", rot)
	for x in [-0.18, 0.18]: b(p + Vector3(x, 0.25, 0).rotated(Vector3.UP, angle), Vector3(0.032, 0.032, 0.39), "laiton", rot)
	doux(p + Vector3(0, haut + 0.24, -0.2).rotated(Vector3.UP, angle), Vector3(0.46, 0.34, 0.06), "cuir", rot)
	solide(p + Vector3(0, haut * 0.65, 0), Vector3(0.48, haut * 1.3, 0.48), "Tabouret")

func fauteuil(p: Vector3, angle: float) -> void:
	var rot := Vector3(0, angle, 0)
	for x in [-0.31, 0.31]:
		for z in [-0.28, 0.28]: b(p + Vector3(x, 0.18, z).rotated(Vector3.UP, angle), Vector3(0.055, 0.36, 0.055), "bois", rot)
	doux(p + Vector3(0, 0.43, 0), Vector3(0.76, 0.16, 0.7), "cuir_vert", rot)
	doux(p + Vector3(0, 0.81, -0.3).rotated(Vector3.UP, angle), Vector3(0.74, 0.64, 0.12), "cuir_vert", rot)
	for x in [-0.35, 0.35]: b(p + Vector3(x, 0.65, 0).rotated(Vector3.UP, angle), Vector3(0.055, 0.055, 0.65), "bois", rot)
	solide(p + Vector3(0, 0.48, 0), Vector3(0.72, 0.96, 0.72), "Fauteuil")

func chaise_casino(p: Vector3, angle: float) -> void:
	# Même dessin et proportions que CasinoInterior._chair : acajou, velours et fil d'or.
	var rot := Vector3(0, angle, 0)
	var base := Basis.from_euler(rot)
	for x in [-0.2, 0.2]:
		for z in [-0.2, 0.2]: c(p + base * Vector3(x, 0.23, z), 0.05, 0.46, "bois")
	doux(p + Vector3(0, 0.5, 0), Vector3(0.48, 0.09, 0.48), "cuir_vert", rot)
	b(p + Vector3(0, 0.455, 0), Vector3(0.5, 0.03, 0.5), "bois", rot)
	doux(p + base * Vector3(0, 0.82, 0.21), Vector3(0.46, 0.52, 0.07), "cuir_vert", rot)
	b(p + base * Vector3(0, 1.1, 0.21), Vector3(0.5, 0.05, 0.09), "bois", rot)
	for x in [-0.23, 0.23]: b(p + base * Vector3(x, 0.8, 0.22), Vector3(0.04, 0.6, 0.06), "bois", rot)
	b(p + base * Vector3(0, 0.555, -0.24), Vector3(0.48, 0.02, 0.02), "laiton", rot)
	solide(p + Vector3(0, 0.5, 0), Vector3(0.52, 1.0, 0.52), "ChaiseCasino")

func banquette(p: Vector3, longueur: float, angle: float, vert := false) -> void:
	var rot := Vector3(0, angle, 0)
	var m := "cuir_vert" if vert else "cuir"
	var basis := Basis.from_euler(rot)
	b(p + basis * Vector3(0, 0.18, 0), Vector3(longueur, 0.34, 0.88), "bois", rot)
	doux(p + basis * Vector3(0, 0.46, 0.04), Vector3(longueur - 0.05, 0.2, 0.85), m, rot)
	doux(p + basis * Vector3(0, 0.97, -0.35), Vector3(longueur, 0.94, 0.17), m, rot)
	b(p + basis * Vector3(0, 1.46, -0.35), Vector3(longueur + 0.05, 0.055, 0.19), "bois", rot)
	b(p + basis * Vector3(0, 0.08, 0.47), Vector3(longueur, 0.035, 0.035), "laiton", rot)
	var n := maxi(2, int(longueur / 0.28))
	for i in range(1, n):
		var x := -longueur / 2.0 + i * longueur / n
		b(p + basis * Vector3(x, 0.97, -0.257), Vector3(0.014, 0.82, 0.008), "cuivre", rot)
	for x in [-longueur * 0.5, longueur * 0.5]:
		doux(p + basis * Vector3(x, 0.7, 0), Vector3(0.12, 0.42, 0.94), m, rot)
	var dimensions := Vector3(longueur + 0.15, 1.5, 0.98)
	if abs(sin(angle)) > 0.5: dimensions = Vector3(dimensions.z, dimensions.y, dimensions.x)
	solide(p + Vector3(0, 0.75, 0), dimensions, "Banquette")

func table_basse(p: Vector3, taille := Vector2(1.6, 0.95), hauteur := 0.76) -> void:
	doux(p + Vector3(0, hauteur, 0), Vector3(taille.x, 0.095, taille.y), "chene")
	b(p + Vector3(0, hauteur - 0.06, 0), Vector3(taille.x - 0.15, 0.055, taille.y - 0.15), "laiton")
	for x in [-taille.x * 0.33, taille.x * 0.33]:
		b(p + Vector3(x, hauteur * 0.45, 0), Vector3(0.09, hauteur * 0.9, 0.09), "acier")
		b(p + Vector3(x, 0.06, 0), Vector3(0.55, 0.08, taille.y * 0.74), "acier")
	solide(p + Vector3(0, hauteur * 0.5, 0), Vector3(taille.x, hauteur, taille.y), "Table")
	verre(p + Vector3(-taille.x * 0.24, hauteur + 0.05, 0.19), true)
	verre(p + Vector3(taille.x * 0.27, hauteur + 0.05, -0.16))
	b(p + Vector3(0.1, hauteur + 0.065, 0.1), Vector3(0.24, 0.018, 0.18), "creme")
