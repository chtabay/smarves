extends RefCounted
## Les meubles de la brocante en 3D, à l'échelle d'un intérieur (le mètre) : un modèle KayKit mis à la
## bonne taille, ou un meuble dessiné ici quand les packs n'en ont pas (le téléviseur à pieds, le juke-box,
## la table de jeu, la machine à sous de salon, le billard). Pied au sol, face vers +z.
## Servent à la vitrine de Ginette Boutin et aux intérieurs des logements.

## L'échelle des meubles KayKit : leur fauteuil mesure 1,8 de large, un vrai en fait un peu plus d'un mètre.
const KK_SCALE := {
	"tableau_marine": 0.6, "lampe_salon": 0.45, "lit_cuivre": 0.62, "fauteuil_club": 0.6,
	"buffet_henri2": 0.65, "canape_velours": 0.62, "salon_jardin": 0.6,
}


static func build(id: String) -> Node3D:
	var it: Dictionary = Biens.item(id)
	if it.is_empty():
		return _souvenir(id)
	var model := str(it.get("model", ""))
	if model != "":
		var n: Node3D = load(model).instantiate()
		n.scale = Vector3.ONE * float(KK_SCALE.get(id, 0.6))
		var root := Node3D.new()
		root.name = id
		root.add_child(n)
		return root
	match id:
		"tele_pieds":
			return _tele()
		"juke_box":
			return _juke_box()
		"table_jeu":
			return _table_jeu()
		"machine_salon":
			return _machine()
		"billard":
			return _billard()
	return Node3D.new()


static func _mat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _glow(c: Color, energy := 1.5) -> StandardMaterial3D:
	var m := _mat(c, 0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _legs(parent: Node3D, w: float, d: float, h: float, mat: Material, t := 0.06) -> void:
	for x in [-w / 2.0 + t, w / 2.0 - t]:
		for z in [-d / 2.0 + t, d / 2.0 - t]:
			_box(parent, Vector3(t, h, t), Vector3(x, h / 2.0, z), mat)


## Le téléviseur à pieds : une caisse en noyer, l'écran bombé, deux boutons.
static func _tele() -> Node3D:
	var root := Node3D.new()
	var wood := _mat(Color(0.38, 0.22, 0.12), 0.45)
	_legs(root, 0.7, 0.45, 0.35, _mat(Color(0.2, 0.15, 0.1), 0.5), 0.03)
	_box(root, Vector3(0.8, 0.6, 0.5), Vector3(0, 0.65, 0), wood)
	_box(root, Vector3(0.52, 0.42, 0.02), Vector3(-0.08, 0.66, 0.255), _glow(Color(0.55, 0.62, 0.68), 0.4))
	for y in [0.75, 0.6]:
		_cyl(root, 0.03, 0.03, Vector3(0.3, y, 0.26), _mat(Color(0.8, 0.75, 0.6), 0.3, 0.8)).rotation_degrees.x = 90.0
	_cyl(root, 0.005, 0.4, Vector3(0.15, 1.13, 0), _mat(Color(0.8, 0.8, 0.8), 0.2, 1.0)).rotation_degrees.z = 25.0
	_cyl(root, 0.005, 0.4, Vector3(-0.15, 1.13, 0), _mat(Color(0.8, 0.8, 0.8), 0.2, 1.0)).rotation_degrees.z = -25.0
	return root


## Le juke-box : la caisse, le dôme de lumières, la vitrine des disques.
static func _juke_box() -> Node3D:
	var root := Node3D.new()
	var body := _mat(Color(0.55, 0.12, 0.1), 0.35)
	_box(root, Vector3(0.9, 1.1, 0.6), Vector3(0, 0.55, 0), body)
	var dome := _cyl(root, 0.45, 0.6, Vector3(0, 1.1, 0), _glow(Color(1.0, 0.65, 0.25), 1.2))
	dome.rotation_degrees.x = 90.0
	dome.scale = Vector3(1, 1, 1)
	_box(root, Vector3(0.6, 0.35, 0.02), Vector3(0, 0.8, 0.31), _glow(Color(0.85, 0.9, 1.0), 0.5))
	_box(root, Vector3(0.7, 0.08, 0.02), Vector3(0, 0.45, 0.31), _mat(Color(0.85, 0.8, 0.6), 0.25, 1.0))
	var blink := Blinker.new()
	blink.colors = [Color(1.0, 0.3, 0.2), Color(0.3, 0.8, 1.0), Color(1.0, 0.85, 0.2)]
	blink.period = 0.6
	_box(blink, Vector3(0.92, 0.05, 0.62), Vector3(0, 0.2, 0), _glow(Color(1.0, 0.3, 0.2)))
	root.add_child(blink)
	return root


## La table de jeu : feutre vert, rebord de bois, quatre pieds tournés.
static func _table_jeu() -> Node3D:
	var root := Node3D.new()
	var wood := _mat(Color(0.32, 0.17, 0.08), 0.4)
	_legs(root, 1.1, 1.1, 0.72, wood)
	_box(root, Vector3(1.2, 0.06, 1.2), Vector3(0, 0.75, 0), wood)
	_box(root, Vector3(1.08, 0.02, 1.08), Vector3(0, 0.79, 0), _mat(Color(0.1, 0.42, 0.22), 0.95))
	for i in 4:
		var stack := _cyl(root, 0.04, 0.05 + i * 0.02, Vector3(-0.3 + i * 0.18, 0.82 + i * 0.01, 0.2), _mat([Color(0.8, 0.1, 0.1), Color(0.1, 0.2, 0.7), Color(0.95, 0.95, 0.9), Color(0.1, 0.1, 0.1)][i], 0.5))
		stack.name = "jetons_%d" % i
	return root


## La machine à sous de salon : elle ne se joue pas, elle clignote.
static func _machine() -> Node3D:
	var root := Node3D.new()
	var chrome := _mat(Color(0.85, 0.85, 0.88), 0.2, 1.0)
	_box(root, Vector3(0.6, 0.8, 0.5), Vector3(0, 0.4, 0), _mat(Color(0.12, 0.12, 0.14), 0.5))
	_box(root, Vector3(0.62, 0.9, 0.52), Vector3(0, 1.25, 0), _mat(Color(0.75, 0.1, 0.12), 0.3, 0.2))
	_box(root, Vector3(0.45, 0.22, 0.02), Vector3(0, 1.25, 0.27), _mat(Color(0.97, 0.95, 0.9), 0.4))
	for i in 3:
		_box(root, Vector3(0.1, 0.14, 0.01), Vector3(-0.14 + i * 0.14, 1.25, 0.285), _mat([Color(0.9, 0.1, 0.1), Color(0.95, 0.75, 0.1), Color(0.2, 0.5, 0.2)][i], 0.5))
	_cyl(root, 0.015, 0.35, Vector3(0.36, 1.3, 0), chrome)
	_cyl(root, 0.045, 0.09, Vector3(0.36, 1.5, 0), _mat(Color(0.8, 0.1, 0.1), 0.3))
	var blink := Blinker.new()
	blink.colors = [Color(1.0, 0.85, 0.2), Color(1.0, 0.3, 0.15)]
	blink.period = 0.4
	_box(blink, Vector3(0.62, 0.12, 0.52), Vector3(0, 1.76, 0), _glow(Color(1.0, 0.85, 0.2), 2.0))
	root.add_child(blink)
	return root


## Le billard français : sans trous, trois billes, un drap vert tendu.
static func _billard() -> Node3D:
	var root := Node3D.new()
	var wood := _mat(Color(0.3, 0.15, 0.07), 0.35)
	for x in [-1.0, 1.0]:
		for z in [-0.5, 0.5]:
			_cyl(root, 0.08, 0.7, Vector3(x, 0.35, z), wood)
	_box(root, Vector3(2.6, 0.12, 1.45), Vector3(0, 0.76, 0), wood)
	_box(root, Vector3(2.4, 0.04, 1.25), Vector3(0, 0.84, 0), _mat(Color(0.08, 0.45, 0.25), 0.95))
	for b in [[Color(0.95, 0.95, 0.9), Vector3(-0.6, 0.89, 0.1)], [Color(0.95, 0.85, 0.2), Vector3(0.3, 0.89, -0.2)], [Color(0.8, 0.1, 0.1), Vector3(0.7, 0.89, 0.3)]]:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.03
		sm.height = 0.06
		s.mesh = sm
		s.material_override = _mat(b[0], 0.15)
		s.position = b[1]
		root.add_child(s)
	var cue := _cyl(root, 0.012, 1.4, Vector3(0, 0.9, 0.5), _mat(Color(0.75, 0.6, 0.4), 0.4))
	cue.rotation_degrees = Vector3(0, 15, 88)
	return root


## Une trouvaille posée : un cadre au mur ou un petit objet sur un guéridon.
static func _souvenir(id: String) -> Node3D:
	var root := Node3D.new()
	if Biens.genre_of(id) == "mur":
		_box(root, Vector3(0.5, 0.65, 0.04), Vector3(0, 0.33, 0), _mat(Color(0.75, 0.6, 0.3), 0.3, 0.8))
		_box(root, Vector3(0.42, 0.56, 0.01), Vector3(0, 0.33, 0.022), _mat(Color(0.95, 0.92, 0.85), 0.7))
	else:
		_box(root, Vector3(0.15, 0.02, 0.1), Vector3(0, 0.01, 0), _mat(Color(0.9, 0.8, 0.5), 0.5))
	return root


## Ce qui clignote : il passe d'une couleur à l'autre, sans fin.
class Blinker extends Node3D:
	var colors: Array = [Color.WHITE]
	var period := 0.5
	var _t := 0.0
	var _i := 0

	func _process(delta: float) -> void:
		_t += delta
		if _t < period:
			return
		_t = 0.0
		_i = (_i + 1) % colors.size()
		for c in get_children():
			if c is MeshInstance3D and c.material_override is StandardMaterial3D:
				var m: StandardMaterial3D = c.material_override
				m.albedo_color = colors[_i]
				m.emission = colors[_i]
