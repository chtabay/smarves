class_name CasinoExterior
## La façade du Casino de Smarves : un petit pavillon Belle Époque en jouet, dôme vert-de-gris,
## marquise à ampoules et enseigne au néon. La façade regarde +Z ; l'origine est au sol, au centre.

const W := 6.0   # largeur
const D := 3.6   # profondeur
const H := 2.6   # hauteur des murs


static func build(parent: Node3D, pos: Vector3, rot_y: float, font: Font) -> Node3D:
	var root := Node3D.new()
	root.name = "Casino"
	root.position = pos
	root.rotation_degrees.y = rot_y
	parent.add_child(root)

	var cream := _mat(Color(0.95, 0.88, 0.74), 0.8)
	var gold := _mat(Color(0.95, 0.72, 0.3), 0.35, 0.8)
	var verdigris := _mat(Color(0.38, 0.72, 0.62), 0.45, 0.3)
	var wine := _mat(Color(0.55, 0.08, 0.14), 0.6)
	var glass := _mat(Color(1.0, 0.78, 0.42), 0.2)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.65, 0.3)
	glass.emission_energy_multiplier = 2.4

	# Socle en marches, corps du pavillon, corniche dorée.
	_box(root, Vector3(W + 0.6, 0.18, D + 0.6), Vector3(0, 0.09, 0), cream)
	_box(root, Vector3(W + 0.3, 0.14, D + 0.3), Vector3(0, 0.25, 0), cream)
	_box(root, Vector3(W, H, D), Vector3(0, 0.32 + H / 2.0, 0), cream)
	_box(root, Vector3(W + 0.25, 0.18, D + 0.25), Vector3(0, 0.32 + H + 0.09, 0), gold)
	_box(root, Vector3(W - 0.4, 0.35, D - 0.4), Vector3(0, 0.32 + H + 0.35, 0), cream)

	# Colonnes, grandes fenêtres cintrées éclairées, porte à tambour.
	for i in 6:
		var x := -W / 2.0 + 0.35 + i * (W - 0.7) / 5.0
		_cyl(root, 0.12, H - 0.1, Vector3(x, 0.32 + (H - 0.1) / 2.0, D / 2.0 + 0.1), cream)
		_cyl(root, 0.17, 0.12, Vector3(x, 0.38, D / 2.0 + 0.1), gold)
		_cyl(root, 0.17, 0.12, Vector3(x, 0.32 + H - 0.12, D / 2.0 + 0.1), gold)
	for i in 5:
		var x := -W / 2.0 + 0.35 + (i + 0.5) * (W - 0.7) / 5.0
		if i == 2:
			continue
		_box(root, Vector3(0.62, 1.15, 0.04), Vector3(x, 1.2, D / 2.0 + 0.01), glass)
		var arch := _cyl(root, 0.31, 0.04, Vector3(x, 1.78, D / 2.0 + 0.01), glass)
		arch.rotation_degrees.x = 90
		_box(root, Vector3(0.62, 0.03, 0.06), Vector3(x, 1.2, D / 2.0 + 0.03), gold)
	_box(root, Vector3(1.0, 1.55, 0.05), Vector3(0, 1.1, D / 2.0 + 0.01), glass)
	_box(root, Vector3(1.1, 0.08, 0.1), Vector3(0, 1.9, D / 2.0 + 0.05), gold)

	# Marquise de fer et de verre, bordée d'ampoules.
	_box(root, Vector3(2.6, 0.08, 1.2), Vector3(0, 2.05, D / 2.0 + 0.6), wine)
	_box(root, Vector3(2.7, 0.12, 0.06), Vector3(0, 2.0, D / 2.0 + 1.2), gold)
	var bulb := _mat(Color(1, 0.9, 0.6), 0.2)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.8, 0.45)
	bulb.emission_energy_multiplier = 6.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var s := SphereMesh.new()
	s.radius = 0.035
	s.height = 0.07
	s.material = bulb
	mm.mesh = s
	mm.instance_count = 13
	for i in 13:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(-1.3 + i * 2.6 / 12.0, 1.93, D / 2.0 + 1.22)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)
	for x in [-1.0, 1.0]:
		_cyl(root, 0.04, 2.0, Vector3(x * 1.2, 1.0, D / 2.0 + 1.15), gold)

	# Le dôme vert-de-gris, son lanternon et sa flèche dorée.
	_cyl(root, 1.05, 0.5, Vector3(0, 0.32 + H + 0.75, 0), cream)
	var dome := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 1.6
	sph.is_hemisphere = true
	dome.mesh = sph
	dome.material_override = verdigris
	dome.position = Vector3(0, 0.32 + H + 1.0, 0)
	root.add_child(dome)
	_cyl(root, 0.18, 0.35, Vector3(0, 0.32 + H + 1.95, 0), gold)
	_cyl(root, 0.03, 0.5, Vector3(0, 0.32 + H + 2.35, 0), gold)
	for x in [-1.0, 1.0]:
		var small := MeshInstance3D.new()
		var ss := SphereMesh.new()
		ss.radius = 0.38
		ss.height = 0.6
		ss.is_hemisphere = true
		small.mesh = ss
		small.material_override = verdigris
		small.position = Vector3(x * (W / 2.0 - 0.45), 0.32 + H + 0.18, D / 2.0 - 0.45)
		root.add_child(small)

	# L'enseigne au néon, verticale et horizontale.
	var neon := Label3D.new()
	neon.text = "CASINO"
	neon.font = font
	neon.font_size = 120
	neon.pixel_size = 0.008
	neon.modulate = Color(3.0, 1.9, 0.7)
	neon.outline_size = 22
	neon.outline_modulate = Color(1.0, 0.5, 0.1, 0.4)
	neon.shaded = false
	neon.position = Vector3(0, 0.32 + H + 0.42, D / 2.0 - 0.18)
	root.add_child(neon)
	var sub := Label3D.new()
	sub.text = "de Smarves  ·  jeux  ·  restaurant  ·  avenir"
	sub.font = font
	sub.font_size = 40
	sub.pixel_size = 0.006
	sub.modulate = Color(1.8, 1.4, 1.0)
	sub.shaded = false
	sub.position = Vector3(0, 2.18, D / 2.0 + 1.24)
	root.add_child(sub)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 3.0
	light.omni_range = 6.0
	light.position = Vector3(0, 1.6, D / 2.0 + 1.6)
	root.add_child(light)
	return root


static func _mat(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 24
	m.mesh = c
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m
