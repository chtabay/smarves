class_name House
## Assemble une maison de village avec les modules du Fantasy Town Kit (murs d'un mètre, toits à deux pans).
## La façade regarde +Z ; l'origine est au centre de l'emprise, au sol.

const T := "res://assets/kenney/town/"

## Rotation (degrés) qui tourne le +X local d'un module vers chaque côté de la maison.
const FACING := {"front": -90.0, "back": 90.0, "right": 0.0, "left": 180.0}


static func build(parent: Node3D, pos: Vector3, rot_y: float, w: int, d: int, floors: int,
		ground_front: Array = [], upper := "wall-window-shutters", side := "wall-window-small") -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	parent.add_child(root)
	for y in floors:
		for i in w:
			var x := i - (w - 1) / 2.0
			# Façade : au rez-de-chaussée, ce que demande l'appelant (porte, vitrine…).
			var front: String = upper
			if y == 0:
				front = ground_front[i] if i < ground_front.size() else "wall"
			_mod(root, front, Vector3(x, y, (d - 1) / 2.0), "front")
			_mod(root, "wall" if (i + y) % 2 == 0 else "wall-window-small", Vector3(x, y, -(d - 1) / 2.0), "back")
		for j in d:
			var z := j - (d - 1) / 2.0
			_mod(root, side if (y > 0 and j == d / 2) else "wall", Vector3(-(w - 1) / 2.0, y, z), "left")
			_mod(root, side if (y > 0 and j == d / 2) else "wall", Vector3((w - 1) / 2.0, y, z), "right")
	# Toit à deux pans, faîtage le long de X.
	for i in w:
		var x := i - (w - 1) / 2.0
		for j in d:
			var z := j - (d - 1) / 2.0
			var dir := "front" if z > 0 else "back"
			_mod(root, "roof-high", Vector3(x, floors, z), dir, 180.0)
	# Pignons sous le toit.
	for j in d:
		var z := j - (d - 1) / 2.0
		_mod(root, "wall-slope", Vector3(-(w - 1) / 2.0, floors, z), "left", 0.0, z < 0)
		_mod(root, "wall-slope", Vector3((w - 1) / 2.0, floors, z), "right", 0.0, z > 0)
	var chimney := _mod(root, "chimney", Vector3((w - 1) / 2.0 - 0.6, floors + 0.5, -0.3), "right")
	chimney.scale = Vector3(1, 1, 1)
	return root


static func _mod(root: Node3D, name: String, at: Vector3, side: String, extra := 0.0, mirror := false) -> Node3D:
	var n: Node3D = load(T + name + ".glb").instantiate()
	n.position = at
	n.rotation_degrees.y = FACING[side] + extra
	if mirror:
		n.scale.z = -1.0
	root.add_child(n)
	# Fenêtres allumées : un panneau lumineux juste derrière la vitre, une fois sur trois éteint.
	if name.contains("window") or name.contains("doorway-square-wide"):
		if randf() < 0.72:
			var glow := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.9, 0.9)
			glow.mesh = q
			glow.material_override = _window_glow()
			glow.position = Vector3(0.38, 0.5, 0.0)
			glow.rotation_degrees.y = 90.0
			n.add_child(glow)
	return n


static var _glow_mat: StandardMaterial3D


static func _window_glow() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.albedo_color = Color(1.0, 0.72, 0.38)
		_glow_mat.emission_enabled = true
		_glow_mat.emission = Color(1.0, 0.62, 0.28)
		_glow_mat.emission_energy_multiplier = 2.2
		_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _glow_mat
