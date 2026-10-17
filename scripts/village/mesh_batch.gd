extends RefCounted
## Assemble des centaines de petites pièces (murs, volets, tuiles, bordures) en quelques maillages,
## un par matériau : une rue entière se dessine en une poignée d'appels de dessin.
## Chaque sommet porte sa couleur, si bien qu'un seul matériau sert à toutes les teintes de pierre.

const _DIRS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]

var _tools := {}
var _count := {}


func _st(key: String) -> SurfaceTool:
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
		_count[key] = 0
	return _tools[key]


## Un quadrilatère p0..p3 (dans l'ordre du pourtour), tourné vers n. Les UV sont en mètres.
func quad(key: String, xf: Transform3D, p: Array, n: Vector3, color: Color, uv: Array = []) -> void:
	var st := _st(key)
	var w := [xf * p[0], xf * p[1], xf * p[2], xf * p[3]]
	var nn := (xf.basis * n).normalized()
	var uvs: Array = uv if uv.size() == 4 else [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	# Godot dessine les faces avant dans le sens des aiguilles d'une montre.
	var order := [0, 1, 2, 0, 2, 3]
	if (w[1] - w[0]).cross(w[2] - w[0]).dot(nn) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		st.set_color(color)
		st.set_normal(nn)
		st.set_uv(uvs[i])
		st.add_vertex(w[i])
	_count[key] += 1


func tri(key: String, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, n: Vector3, color: Color, uv: Array = []) -> void:
	var st := _st(key)
	var w := [xf * a, xf * b, xf * c]
	var nn := (xf.basis * n).normalized()
	var uvs: Array = uv if uv.size() == 3 else [Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)]
	var order := [0, 1, 2]
	if (w[1] - w[0]).cross(w[2] - w[0]).dot(nn) > 0.0:
		order = [0, 2, 1]
	for i in order:
		st.set_color(color)
		st.set_normal(nn)
		st.set_uv(uvs[i])
		st.add_vertex(w[i])


## Une boîte de taille size centrée en center (repère local xf). skip_bottom : on ne voit jamais le dessous.
func box(key: String, xf: Transform3D, center: Vector3, size: Vector3, color: Color, skip_bottom := true) -> void:
	var h := size / 2.0
	for n in _DIRS:
		if skip_bottom and n == Vector3.DOWN:
			continue
		var u: Vector3 = Vector3.UP if absf(n.y) < 0.5 else Vector3.BACK
		var v: Vector3 = n.cross(u)
		var c: Vector3 = center + n * h
		var hu: Vector3 = u * h
		var hv: Vector3 = v * h
		var su := absf(u.dot(size))
		var sv := absf(v.dot(size))
		quad(key, xf, [c - hu - hv, c - hu + hv, c + hu + hv, c + hu - hv], n, color,
			[Vector2(0, 0), Vector2(sv, 0), Vector2(sv, su), Vector2(0, su)])


## Une boîte tournée autour de l'axe X local (pour les pans de toit, les auvents).
func box_tilted(key: String, xf: Transform3D, center: Vector3, size: Vector3, angle_x: float, color: Color) -> void:
	var t := xf * Transform3D(Basis(Vector3.RIGHT, angle_x), center)
	box(key, t, Vector3.ZERO, size, color, false)


## Un cylindre grossier (poteaux, boules de pilier, colonnes), à facettes : ça reste du jouet.
func cylinder(key: String, xf: Transform3D, base: Vector3, radius: float, height: float, color: Color, sides := 8) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := base + Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var p1 := base + Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		var n := Vector3(cos((a0 + a1) / 2.0), 0, sin((a0 + a1) / 2.0))
		quad(key, xf, [p0, p1, p1 + Vector3.UP * height, p0 + Vector3.UP * height], n, color)
		tri(key, xf, base + Vector3.UP * height, p0 + Vector3.UP * height, p1 + Vector3.UP * height, Vector3.UP, color)


## Pose les maillages assemblés sous parent, un MeshInstance3D par matériau.
func commit(parent: Node3D, materials: Dictionary, label := "Lot") -> void:
	for key in _tools:
		var st: SurfaceTool = _tools[key]
		var mesh := st.commit()
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "%s_%s" % [label, key]
		mi.mesh = mesh
		mi.material_override = materials.get(key)
		parent.add_child(mi)
	_tools.clear()
