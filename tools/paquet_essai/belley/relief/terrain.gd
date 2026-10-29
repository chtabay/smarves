extends Node3D
## Le sol de Belley, maillé en carreaux du plus fin au plus large : le bourg au pas de 5 m, la ville,
## le canal, Parves et le Rhône au pas de 15 m, l'horizon de 36 km au pas de 75 m. Chaque anneau laisse un
## trou à la place du plus fin ; une jupe sous chaque bord cache les raccords. La collision suit le sol où
## l'on marche (le bourg et le proche).

const RELIEF := preload("res://communes/belley/relief/relief.gd")
const SHADER := preload("res://communes/belley/relief/terrain.gdshader")
const DOSSIER := "res://communes/belley/relief/"

## Les anneaux : [cadre [x0, z0, x1, z1], trous (les cadres des anneaux plus fins), pas, côté d'un carreau, collision].
## La crête du Mont du Chat a le sien, plus fin que l'horizon : ses barres et la Dent s'y dessinent.
const BOURG := [-800.0, -800.0, 800.0, 800.0]
const PROCHE := [-1590.0, -2590.0, 7990.0, 2390.0]
const CRETE := [8000.0, -6000.0, 13000.0, 15000.0]
## Le Relais des Lônes (places/relais.gd) a son carré fin, calé sur la grille du proche : sa cour et la route y
## épousent le sol.
const RELAIS := [7035.0, 510.0, 7335.0, 810.0]
const ANNEAUX := [
	[BOURG, [], 5.0, 200.0, true],
	[RELAIS, [], 5.0, 100.0, true],
	[PROCHE, [BOURG, RELAIS], 25.0, 600.0, true],
	[CRETE, [], 40.0, 1000.0, false],
	[[-18000.0, -18000.0, 18000.0, 18000.0], [PROCHE, CRETE], 150.0, 3000.0, false],
]
const JUPE := 25.0

var relief: RefCounted
var materiau: ShaderMaterial


func construire() -> void:
	relief = RELIEF.new()
	materiau = ShaderMaterial.new()
	materiau.shader = SHADER
	var proche = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "couverture.json"))
	var lointaine = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "couverture_lointaine.json"))
	materiau.set_shader_parameter("couverture", load(DOSSIER + "couverture.png"))
	materiau.set_shader_parameter("cadre", Vector4(proche.cadre[0], proche.cadre[1], proche.cadre[2], proche.cadre[3]))
	materiau.set_shader_parameter("couverture_loin", load(DOSSIER + "couverture_lointaine.png"))
	materiau.set_shader_parameter("cadre_loin", Vector4(lointaine.cadre[0], lointaine.cadre[1], lointaine.cadre[2], lointaine.cadre[3]))
	var pentes = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "pente_crete.json"))
	materiau.set_shader_parameter("pente_crete", load(DOSSIER + "pente_crete.png"))
	materiau.set_shader_parameter("cadre_crete", Vector4(pentes.cadre[0], pentes.cadre[1], pentes.cadre[2], pentes.cadre[3]))
	for a in ANNEAUX:
		_anneau(a[0], a[1], a[2], a[3], a[4])


func hauteur(x: float, z: float) -> float:
	return relief.hauteur(x, z)


## La hauteur du sol tel qu'il est maillé (le triangle du carreau sous le point) : ce qu'on pose dessus le touche
## sans flotter ni s'enfoncer, même là où le maillage est lâche.
func sol(x: float, z: float) -> float:
	for a in ANNEAUX:
		var c: Array = a[0]
		if x < c[0] or x > c[2] or z < c[1] or z > c[3]:
			continue
		var dedans := false
		for t in a[1]:
			if x > t[0] and x < t[2] and z > t[1] and z < t[3]:
				dedans = true
		if dedans:
			continue
		var pas: float = a[2]
		var cote: float = a[3]
		var x0: float = c[0] + floorf((x - c[0]) / cote) * cote
		var z0: float = c[1] + floorf((z - c[1]) / cote) * cote
		var x1 := minf(x0 + cote, c[2])
		var z1 := minf(z0 + cote, c[3])
		var px := (x1 - x0) / maxi(int(round((x1 - x0) / pas)), 1)
		var pz := (z1 - z0) / maxi(int(round((z1 - z0) / pas)), 1)
		var cx := x0 + floorf((x - x0) / px) * px
		var cz := z0 + floorf((z - z0) / pz) * pz
		var u := clampf((x - cx) / px, 0.0, 1.0)
		var v := clampf((z - cz) / pz, 0.0, 1.0)
		var ha := hauteur(cx, cz)
		var hb := hauteur(cx + px, cz)
		var hc := hauteur(cx, cz + pz)
		var hd := hauteur(cx + px, cz + pz)
		# Les deux triangles du carreau : (a, b, c) et (b, d, c), la diagonale de b à c.
		if u + v <= 1.0:
			return ha + (hb - ha) * u + (hc - ha) * v
		return hd + (hc - hd) * (1.0 - u) + (hb - hd) * (1.0 - v)
	return hauteur(x, z)


func _anneau(c: Array, trous: Array, pas: float, cote: float, collision: bool) -> void:
	var x := float(c[0])
	while x < c[2] - 0.01:
		var z := float(c[1])
		var xe := minf(x + cote, c[2])
		while z < c[3] - 0.01:
			var ze := minf(z + cote, c[3])
			var plein := false
			for t in trous:
				if x >= t[0] - 0.01 and xe <= t[2] + 0.01 and z >= t[1] - 0.01 and ze <= t[3] + 0.01:
					plein = true
			if not plein:
				_carreau(x, z, xe, ze, pas, trous, collision)
			z = ze
		x = xe


## Un carreau de sol, ses cellules dans le trou omises.
func _carreau(x0: float, z0: float, x1: float, z1: float, pas: float, trous: Array, collision: bool) -> void:
	var nx := int(round((x1 - x0) / pas))
	var nz := int(round((z1 - z0) / pas))
	var px := (x1 - x0) / nx
	var pz := (z1 - z0) / nz
	var pts := PackedVector3Array()
	var nor := PackedVector3Array()
	pts.resize((nx + 1) * (nz + 1))
	nor.resize(pts.size())
	for j in nz + 1:
		for i in nx + 1:
			var x := x0 + i * px
			var z := z0 + j * pz
			var y := hauteur(x, z)
			pts[j * (nx + 1) + i] = Vector3(x, y, z)
			var d := maxf(px, 4.0)
			var n := Vector3(hauteur(x - d, z) - hauteur(x + d, z), 2.0 * d, hauteur(x, z - d) - hauteur(x, z + d)).normalized()
			nor[j * (nx + 1) + i] = n
	var idx := PackedInt32Array()
	var col := PackedVector3Array()
	for j in nz:
		for i in nx:
			var cx := x0 + (i + 0.5) * px
			var cz := z0 + (j + 0.5) * pz
			var dedans := false
			for t in trous:
				if cx > t[0] and cx < t[2] and cz > t[1] and cz < t[3]:
					dedans = true
			if dedans:
				continue
			var a := j * (nx + 1) + i
			var b := a + 1
			var cc := a + nx + 1
			var d2 := cc + 1
			idx.append_array([a, b, cc, b, d2, cc])
	if idx.is_empty():
		return
	# La jupe : sous les quatre bords, un rideau qui descend de JUPE mètres.
	var bords := []
	for i in nx:
		bords.append([i, i + 1])
		bords.append([nz * (nx + 1) + i + 1, nz * (nx + 1) + i])
	for j in nz:
		bords.append([(j + 1) * (nx + 1), j * (nx + 1)])
		bords.append([j * (nx + 1) + nx, (j + 1) * (nx + 1) + nx])
	for e in bords:
		var p0: Vector3 = pts[e[0]]
		var p1: Vector3 = pts[e[1]]
		var k := pts.size()
		pts.append(p0 - Vector3(0, JUPE, 0))
		pts.append(p1 - Vector3(0, JUPE, 0))
		nor.append(nor[e[0]])
		nor.append(nor[e[1]])
		idx.append_array([e[0], e[1], k, e[1], k + 1, k])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_NORMAL] = nor
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, materiau)
	var mi := MeshInstance3D.new()
	mi.name = "Sol_%d_%d" % [int(x0), int(z0)]
	mi.mesh = mesh
	# Seul le sol du bourg porte des ombres : au-delà, l'ombre du soleil ne porte pas (220 m).
	if not collision or pas > 5.0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if collision:
		var corps := StaticBody3D.new()
		var forme := CollisionShape3D.new()
		var tris := PackedVector3Array()
		for t in range(0, idx.size() - bords.size() * 6, 1):
			tris.append(pts[idx[t]])
		var s := ConcavePolygonShape3D.new()
		s.set_faces(tris)
		forme.shape = s
		corps.add_child(forme)
		mi.add_child(corps)
