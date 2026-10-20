extends Node3D
## Une table d'échecs du Cercle en 3D : un guéridon carré de bois, l'échiquier marqueté posé dessus, et
## les pièces tournées (pied, corps, tête) qui montrent la position. La place du joueur est du côté +z,
## les blancs devant lui ; l'adversaire (robot ou joueur) est assis du côté -z. Les salles la posent,
## puis appellent montrer() avec le plateau du serveur (64 caractères, a1 en 0) quand il change.

const HAUT := 0.76
const CASE := 0.055
const CLAIR := Color("#ebecd0")
const FONCE := Color("#739552")

## Les noirs devant le joueur (la table tourne l'échiquier, pas elle-même).
var retourne := false
var _pieces: Node3D
var _mat_blanc: StandardMaterial3D
var _mat_noir: StandardMaterial3D
var _formes := {}


func _ready() -> void:
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.3, 0.17, 0.09)
	bois.roughness = 0.45
	_boite(Vector3(0.8, 0.04, 0.8), Vector3(0, HAUT - 0.02, 0), bois)
	_boite(Vector3(0.09, HAUT - 0.04, 0.09), Vector3(0, (HAUT - 0.04) / 2.0, 0), bois)
	_boite(Vector3(0.5, 0.03, 0.5), Vector3(0, 0.015, 0), bois)
	# Le cadre de l'échiquier, puis ses cases, vernies.
	var cadre := StandardMaterial3D.new()
	cadre.albedo_color = Color(0.2, 0.11, 0.06)
	cadre.roughness = 0.3
	_boite(Vector3(CASE * 8 + 0.04, 0.02, CASE * 8 + 0.04), Vector3(0, HAUT + 0.01, 0), cadre)
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for x in 8:
		for y in 8:
			img.set_pixel(x, y, CLAIR if (x + y) % 2 == 0 else FONCE)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.25
	var plan := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(CASE * 8, CASE * 8)
	plan.mesh = pm
	plan.material_override = m
	plan.position = Vector3(0, HAUT + 0.0205, 0)
	add_child(plan)
	_mat_blanc = StandardMaterial3D.new()
	_mat_blanc.albedo_color = Color(0.93, 0.9, 0.82)
	_mat_blanc.roughness = 0.3
	_mat_noir = StandardMaterial3D.new()
	_mat_noir.albedo_color = Color(0.12, 0.1, 0.09)
	_mat_noir.roughness = 0.25
	_pieces = Node3D.new()
	add_child(_pieces)
	montrer("RNBQKBNRPPPPPPPP" + ".".repeat(32) + "pppppppprnbqkbnr")


func _boite(s: Vector3, p: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = s
	mi.mesh = b
	mi.material_override = m
	mi.position = p
	add_child(mi)


## La forme d'une pièce, faite une fois : un pied, un corps qui s'amincit, une tête selon la pièce.
func _forme(k: String) -> Mesh:
	if _formes.has(k):
		return _formes[k]
	var h: float = {"p": 0.036, "n": 0.05, "b": 0.056, "r": 0.046, "q": 0.064, "k": 0.07}[k]
	var r := 0.016 if k != "p" else 0.013
	var st := SurfaceTool.new()
	var corps := CylinderMesh.new()
	corps.top_radius = r * 0.45
	corps.bottom_radius = r
	corps.height = h * 0.75
	corps.radial_segments = 14
	corps.rings = 1
	st.append_from(corps, 0, Transform3D(Basis(), Vector3(0, h * 0.375, 0)))
	var pied := CylinderMesh.new()
	pied.top_radius = r * 1.1
	pied.bottom_radius = r * 1.2
	pied.height = 0.008
	pied.radial_segments = 14
	pied.rings = 1
	st.append_from(pied, 0, Transform3D(Basis(), Vector3(0, 0.004, 0)))
	var tete: Mesh
	match k:
		"r":
			var c := CylinderMesh.new()
			c.top_radius = r * 0.9
			c.bottom_radius = r * 0.8
			c.height = h * 0.22
			c.radial_segments = 8
			tete = c
		"n":
			var b := BoxMesh.new()
			b.size = Vector3(r * 0.9, h * 0.3, r * 1.7)
			tete = b
		_:
			var s := SphereMesh.new()
			s.radius = r * (0.62 if k in ["q", "k"] else 0.55)
			s.height = s.radius * 2.0
			s.radial_segments = 12
			s.rings = 6
			tete = s
	st.append_from(tete, 0, Transform3D(Basis(), Vector3(0, h * 0.85, 0)))
	if k == "k":
		var croix := BoxMesh.new()
		croix.size = Vector3(0.006, 0.018, 0.006)
		st.append_from(croix, 0, Transform3D(Basis(), Vector3(0, h + 0.008, 0)))
	var mesh := st.commit()
	_formes[k] = mesh
	return mesh


## Montre une position du serveur (64 caractères, a1 en 0).
func montrer(plateau: String) -> void:
	if _pieces == null or plateau.length() != 64:
		return
	for c in _pieces.get_children():
		c.queue_free()
	for s in 64:
		var p := plateau[s]
		if p == ".":
			continue
		var f := s & 7
		var r := s >> 3
		# Les blancs du côté +z (le joueur), a1 à sa gauche.
		var x := (f - 3.5) * CASE
		var z := (3.5 - r) * CASE
		if retourne:
			x = -x
			z = -z
		var mi := MeshInstance3D.new()
		mi.mesh = _forme(p.to_lower())
		var blanc := p == p.to_upper()
		mi.material_override = _mat_blanc if blanc else _mat_noir
		mi.position = Vector3(x, HAUT + 0.021, z)
		# Le cavalier regarde l'adversaire.
		if p.to_lower() == "n":
			mi.rotation.y = 0.0 if blanc != retourne else PI
		_pieces.add_child(mi)
