extends RefCounted
## Les arbres de la ville à leur place réelle (bourg.json) : des tilleuls et des platanes en boules de feuillage
## tendre, comme sur la planche de la place. Quatre silhouettes, posées en MultiMesh (un appel de dessin par
## silhouette), chaque arbre tourné et mis à l'échelle à sa façon.

const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const DOSSIER := "res://communes/belley/"
const UNITE := 2.4

const VERTS := [Color("7fae3e"), Color("8cbb48"), Color("6f9e36"), Color("98c050")]
const ECORCE := Color("6b5a48", 0.9)


static func silhouette(graine: int, detail := true) -> ArrayMesh:
	var o := OUTILS.new(graine)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var h := rng.randf_range(4.2, 5.2)
	o.branche(Vector3.ZERO, Vector3(0, h, 0), 0.28, 0.2, ECORCE)
	var vert: Color = VERTS[graine % VERTS.size()]
	# Les charpentières, puis le houppier : beaucoup de petites touffes sur une ellipsoïde, plus claires au
	# soleil (en haut), la masse sombre au cœur.
	o.boule(Vector3(0, h + 2.2, 0), Vector3(2.9, 2.4, 2.9), vert.darkened(0.25), 0.1, OUTILS.FEUILLE, 0.04, 1.0, 5, 8)
	var n := 16 if detail else 5
	for k in n:
		var a := TAU * k * 0.618 + rng.randf_range(-0.2, 0.2)
		var u := rng.randf_range(-0.55, 0.95)
		var rr := sqrt(1.0 - u * u)
		var p := Vector3(cos(a) * rr * 2.7, h + 2.2 + u * 2.2, sin(a) * rr * 2.7)
		if k < 5:
			o.branche(Vector3(0, h - 0.6, 0), p * Vector3(0.6, 1, 0.6) + Vector3(0, -0.4, 0), 0.13, 0.06, ECORCE)
		var s := rng.randf_range(1.0, 1.4) if detail else rng.randf_range(1.6, 2.0)
		o.boule(p, Vector3(s, s * 0.82, s), vert.lightened(0.1 * u + rng.randf_range(-0.04, 0.06)), 0.14, OUTILS.FEUILLE, 0.07, 1.0, 5 if detail else 4, 8 if detail else 6)
	var tmp := Node3D.new()
	var mi: MeshInstance3D = o.construire(tmp, "Arbre")
	var m: ArrayMesh = mi.mesh
	tmp.free()
	return m


## Plante les arbres par lots de 200 m : de près la silhouette fine, de loin une silhouette à cinq touffes.
const PRES := 220.0


static func planter(parent: Node3D, points: Array, hauteur: Callable) -> void:
	var fines := []
	var simples := []
	for g in 4:
		fines.append(silhouette(101 + g, true))
		simples.append(silhouette(101 + g, false))
	var lots := {}
	for p in points:
		var x: float = p[0]
		var z: float = p[1]
		var g := absi(hash(Vector2(x, z))) % 4
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2(z, x))
		var s := rng.randf_range(0.85, 1.2)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.1), s)), Vector3(x, hauteur.call(x, z) - 0.1, z))
		var cle := Vector3i(floori(x / 200.0), floori(z / 200.0), g)
		if not lots.has(cle):
			lots[cle] = []
		lots[cle].append(t)
	for cle in lots:
		var centre := Vector3((cle.x + 0.5) * 200.0, 0, (cle.y + 0.5) * 200.0)
		for fin in [true, false]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = fines[cle.z] if fin else simples[cle.z]
			mm.instance_count = lots[cle].size()
			for i in lots[cle].size():
				var t: Transform3D = lots[cle][i]
				mm.set_instance_transform(i, Transform3D(t.basis, t.origin - centre))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Arbres_%d_%d_%d_%s" % [cle.x, cle.y, cle.z, "fin" if fin else "loin"]
			mmi.multimesh = mm
			mmi.position = centre
			# Le lot change de silhouette à PRES mètres de son centre (un lot fait 200 m).
			if fin:
				mmi.visibility_range_end = PRES
			else:
				mmi.visibility_range_begin = PRES
			parent.add_child(mmi)
