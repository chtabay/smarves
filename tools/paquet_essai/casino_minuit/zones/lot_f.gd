extends RefCounted
## Lot F « La salle de concert et l'arène de boxe » (js/zones/f-0-commun.js) : les briques communes à l'arène
## (arene.gd) et à Minuit Live (concert.gd). Les gradins (rangs le long de x local, qui montent vers +z local ;
## le public regarde vers −z local, ou vers un point), les sièges instanciés (un appel de rendu par zone), la
## poutre-treillis des ponts lumière, la ligne de sonorisation suspendue. La foule est celle du lot E
## (lot_e.gd, foule : silhouettes basses instanciées, animées dans leur shader).

const Y_ESTRADE := 1.2


## L'orientation de qui, en (x, z), regarde le point (lx, lz) (figurants et foule regardent −z à 0).
static func vers(x: float, z: float, lx: float, lz: float) -> float:
	return atan2(x - lx, z - lz)


## Des gradins. o : x, z, rot, width, rows, depth (0,9), rise (0,42), y (0), aisles (allées en x local),
## look (Vector2, ce que le public regarde), seed, nez (matériau du nez lumineux), places (rangs à places
## notées, 1), occupation (0,8), collision (true), fond (true), bouts (true). Les sièges vont dans sieges
## (des Transform3D, posés ensuite par sieges()) ; renvoie {places: [[pos, ry]…], foule: [[x, y, z, ry]…]}.
static func gradins(K, o: Dictionary, sieges: Array) -> Dictionary:
	var by: float = o.get("y", 0.0)
	var rot: float = o.get("rot", 0.0)
	var W: float = o.width
	var n: int = o.rows
	var d: float = o.get("depth", 0.9)
	var r: float = o.get("rise", 0.42)
	var aw := 1.1
	var allees: Array = o.get("aisles", [])
	var nez: String = o.get("nez", "ambre_lum")
	var look: Vector2 = o.get("look", Vector2.ZERO)
	var b := Basis(Vector3.UP, rot)
	var origine := Vector3(o.x, by, o.z)
	var loc := func(lx: float, y: float, lz: float) -> Vector3: return origine + b * Vector3(lx, y, lz)
	var pave := func(nom: String, w: float, h: float, dd: float, lx: float, y: float, lz: float) -> void:
		K.put(nom, K._box_mesh(w, h, dd), Transform3D(b, loc.call(lx, y, lz)))
	for k in range(1, n):
		var z0 := (k - 0.5) * d
		var h := k * r
		pave.call("noir_mat", W, h, d, 0.0, h / 2.0, z0 + d / 2.0)
		pave.call("noir_satin", W, 0.02, d - 0.04, 0.0, h + 0.01, z0 + d / 2.0)
		pave.call(nez, W, 0.025, 0.03, 0.0, h - 0.06, z0 - 0.005)
		for a in allees:
			pave.call("noir_satin", aw, 0.02, d / 2.0, a, h - r / 2.0 + 0.01, z0 + d / 4.0)
			pave.call("noir_mat", aw, r / 2.0, d / 2.0 - 0.01, a, h - r * 0.75, z0 + d / 4.0 + 0.005)
			pave.call(nez, aw, 0.02, 0.03, a, h - r / 2.0 - 0.04, z0 - 0.005)
		if o.get("bouts", true):
			for sd in [-1.0, 1.0]:
				pave.call("noir_mat", 0.2, k * r + 1.0, d, sd * (W / 2.0 + 0.1), (k * r + 1.0) / 2.0, (k - 0.5) * d + d / 2.0)
	if o.get("fond", true):
		pave.call("noir_mat", W, n * r + 1.2, 0.3, 0.0, (n * r + 1.2) / 2.0, (n - 0.5) * d + 0.15)
	# Les places : un siège par pas de 0,56 m, hors des allées ; les premiers rangs notés, le public au-delà.
	var h_rng := RandomNumberGenerator.new()
	h_rng.seed = o.get("seed", 3)
	var pas := 0.56
	var npr := int(floor(W / pas))
	var x0 := -((npr - 1) * pas) / 2.0
	var places := []
	var foule := []
	var notes: int = o.get("places", 1)
	var occ: float = o.get("occupation", 0.8)
	for k in n:
		var elev := k * r
		for i in npr:
			var lx := x0 + i * pas
			var dans_allee := false
			for a in allees:
				if absf(lx - a) < aw / 2.0 + 0.2:
					dans_allee = true
			if dans_allee:
				continue
			var wp: Vector3 = loc.call(lx, elev, k * d)
			var fa := vers(wp.x, wp.z, look.x, look.y) if o.has("look") else rot
			sieges.append(Transform3D(Basis(Vector3.UP, fa), wp))
			if k < notes:
				places.append([Vector3(wp.x, wp.y + 0.45, wp.z), fa])
			elif h_rng.randf() < occ:
				foule.append([wp.x, wp.y + 0.02, wp.z, fa])
	if o.get("collision", true):
		var lz0 := -0.38
		var lz1 := (n - 0.5) * d + 0.3
		var c: Vector3 = loc.call(0.0, 0.0, (lz0 + lz1) / 2.0)
		var hh := n * r + 1.2
		K.solide(W + 0.4, hh, lz1 - lz0, c.x, by + hh / 2.0, c.z, rot)
	return {"places": places, "foule": foule}


## La forme d'un fauteuil de gradin (assise et dossier ; on s'y assied vers −z, l'assise à 0,45).
static func forme_siege(chaise := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts := [[Vector3(0.46, 0.09, 0.44), Vector3(0, 0.44, -0.02)], [Vector3(0.46, 0.5, 0.08), Vector3(0, 0.74, 0.21)]]
	if chaise:
		parts = [[Vector3(0.44, 0.06, 0.42), Vector3(0, 0.46, 0)], [Vector3(0.42, 0.34, 0.04), Vector3(0, 0.8, 0.2)],
			[Vector3(0.025, 0.46, 0.025), Vector3(-0.2, 0.23, -0.17)], [Vector3(0.025, 0.46, 0.025), Vector3(0.2, 0.23, -0.17)],
			[Vector3(0.025, 0.9, 0.025), Vector3(-0.2, 0.45, 0.19)], [Vector3(0.025, 0.9, 0.025), Vector3(0.2, 0.45, 0.19)]]
	else:
		parts.append([Vector3(0.05, 0.62, 0.46), Vector3(-0.25, 0.32, 0.02)])
		parts.append([Vector3(0.05, 0.62, 0.46), Vector3(0.25, 0.32, 0.02)])
	for p in parts:
		var bm := BoxMesh.new()
		bm.size = p[0]
		st.append_from(bm, 0, Transform3D(Basis(), p[1]))
	return st.commit()


## Les sièges d'une zone, instanciés (un appel de rendu).
static func sieges(K, liste: Array, nom_mat := "capiton_rouge", chaise := false, nom := "sieges") -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = forme_siege(chaise)
	mm.instance_count = liste.size()
	for i in liste.size():
		mm.set_instance_transform(i, liste[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = nom
	mi.multimesh = mm
	mi.material_override = K.mat(nom_mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.zone.add_child(mi)
	return mi


## Une poutre-treillis carrée (quatre membrures et des diagonales sur les quatre faces) de A à B (F.truss).
static func treillis(K, a: Vector3, b: Vector3, taille := 0.4, pas := 0.6, nom_mat := "alu") -> void:
	var s := taille / 2.0
	var l := a.distance_to(b)
	var n := maxi(1, roundi(l / pas))
	var u := (b - a).normalized()
	var v := Vector3.RIGHT if absf(u.y) > 0.9 else Vector3.UP
	var w := u.cross(v).normalized()
	v = w.cross(u).normalized()
	var cs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var P := func(t: float, c: Vector2) -> Vector3: return a + (b - a) * t + (v * c.x + w * c.y) * s
	for c in cs:
		K.beam(nom_mat, P.call(0.0, c), P.call(1.0, c), 0.05, 0.05)
	for f in 4:
		var c0: Vector2 = cs[f]
		var c1: Vector2 = cs[(f + 1) % 4]
		for k in n:
			K.beam(nom_mat, P.call(float(k) / n, c0 if k % 2 else c1), P.call(float(k + 1) / n, c1 if k % 2 else c0), 0.025, 0.025)


## Une ligne de sonorisation suspendue (F.lineArray) : bumper et n enceintes en J, face vers ry ; y le haut.
static func ligne_son(K, x: float, y: float, z: float, ry: float, n: int) -> void:
	var sx := sin(ry)
	var cz := cos(ry)
	var yy := y - 0.12
	var tilt := 0.0
	var zz := 0.0
	K.box("gris", 1.25, 0.12, 0.8, x, y, z, ry)
	for dx in [-0.5, 0.5]:
		K.beam("gris", Vector3(x + dx, y, z), Vector3(x + dx, y + 3, z), 0.02, 0.02)
	for i in n:
		tilt += 0.012 + i * 0.018
		var h := 0.34
		K.put("noir_satin", K._box_mesh(1.15, h, 0.6), K.xf(x + sx * zz, yy - h / 2.0, z + cz * zz, -tilt, ry, 0))
		yy -= h * cos(tilt)
		zz += h * sin(tilt) * 0.5


## Une porte de secours dans un mur (F.issue) : (x, z) le milieu, ry la direction d'où on la voit.
static func issue(K, x: float, z: float, ry: float) -> void:
	var sx := sin(ry)
	var cz := cos(ry)
	K.box("noir_satin", 1.8, 2.3, 0.08, x + sx * 0.04, 1.15, z + cz * 0.04, ry)
	K.box("laque_noire", 2.0, 0.1, 0.12, x + sx * 0.06, 2.35, z + cz * 0.06, ry)
	K.box("vert_lum", 0.84, 0.32, 0.03, x + sx * 0.08, 2.72, z + cz * 0.08, ry)
	K.texte("SORTIE", 0.7, 0.2, x + sx * 0.1, 2.72, z + cz * 0.1, ry, "grave", Color("#F2FFF6"))
