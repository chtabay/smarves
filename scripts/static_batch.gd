extends RefCounted
## Regroupe les maillages immobiles d'une scène construite dans le code : un maillage par matériau
## et par case de CELL mètres, au lieu de milliers de petites pièces (balustres, caissons, moulures).
## On ne touche qu'à ce qui ne bouge jamais : rien sous un nœud qui a un script ou des métadonnées
## (tables, machines, barrières, habitants), rien de transparent ni de relief en carte de normales.
## La collision n'est pas concernée : les corps restent où ils sont.

const CELL := 8.0


## Regroupe sous root ; skip : nœuds dont tout le sous-arbre reste tel quel. Renvoie le nombre de pièces fondues.
static func bake(root: Node3D, skip: Array = []) -> int:
	var excluded := {}
	for n in skip:
		if is_instance_valid(n):
			excluded[n] = true
	var groups := {}
	var cache := {}
	var merged: Array[MeshInstance3D] = []
	var inv := root.global_transform.affine_inverse()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not _static(mi, root, excluded):
			continue
		# Deux boîtes de même taille ont les mêmes sommets : on ne les génère qu'une fois.
		var ck = _shape_key(mi.mesh)
		var surfaces: Array = cache.get(ck, [])
		if not cache.has(ck):
			surfaces = _surfaces(mi.mesh)
			cache[ck] = surfaces
		if surfaces.is_empty():
			continue
		var xf: Transform3D = inv * mi.global_transform
		var cell: Vector3 = (xf.origin / CELL).floor()
		var mats := []
		var ok := true
		for s in surfaces.size():
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = surfaces[s].mat
			if mat == null or not _mergeable(mat):
				ok = false
				break
			mats.append(mat)
		if not ok:
			continue
		var nxf := Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO)
		for s in surfaces.size():
			var sf: Dictionary = surfaces[s]
			var key := "%d|%s|%d|%d|%s" % [mats[s].get_instance_id(), sf.color, mi.cast_shadow, mi.layers, str(cell)]
			if not groups.has(key):
				groups[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
					"c": PackedColorArray(), "i": PackedInt32Array(), "mat": mats[s], "color": sf.color,
					"shadow": mi.cast_shadow, "layers": mi.layers}
			var g: Dictionary = groups[key]
			var base: int = g.v.size()
			g.v.append_array(xf * (sf.v as PackedVector3Array))
			g.n.append_array(nxf * (sf.n as PackedVector3Array))
			g.uv.append_array(sf.uv)
			if sf.color:
				g.c.append_array(sf.c)
			var idx: PackedInt32Array = sf.i
			for k in idx.size():
				g.i.append(idx[k] + base)
		merged.append(mi)
	for key in groups:
		var g: Dictionary = groups[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.v
		arrays[Mesh.ARRAY_NORMAL] = g.n
		arrays[Mesh.ARRAY_TEX_UV] = g.uv
		if g.color:
			arrays[Mesh.ARRAY_COLOR] = g.c
		arrays[Mesh.ARRAY_INDEX] = g.i
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var out := MeshInstance3D.new()
		out.name = "Lot"
		out.mesh = am
		out.material_override = g.mat
		out.cast_shadow = g.shadow
		out.layers = g.layers
		root.add_child(out)
	for mi in merged:
		# Un nœud qui porte d'autres choses (un corps de collision, une lumière) reste, sans son dessin.
		if mi.get_child_count() > 0:
			mi.mesh = null
		else:
			mi.queue_free()
	return merged.size()


## Les surfaces d'un maillage en tableaux simples (sommets, normales, UV, couleurs, indices), ou [] si
## le maillage a autre chose que des triangles.
static func _surfaces(mesh: Mesh) -> Array:
	var out := []
	var list := []
	_simplify(mesh)
	if mesh is PrimitiveMesh:
		list.append([(mesh as PrimitiveMesh).get_mesh_arrays(), (mesh as PrimitiveMesh).material])
	elif mesh is ArrayMesh:
		for s in mesh.get_surface_count():
			if (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				return []
			list.append([mesh.surface_get_arrays(s), mesh.surface_get_material(s)])
	else:
		return []
	for e in list:
		var a: Array = e[0]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n = a[Mesh.ARRAY_NORMAL]
		var uv = a[Mesh.ARRAY_TEX_UV]
		var c = a[Mesh.ARRAY_COLOR]
		var idx = a[Mesh.ARRAY_INDEX]
		if n == null or (n as PackedVector3Array).size() != v.size():
			return []
		if uv == null or (uv as PackedVector2Array).size() != v.size():
			uv = PackedVector2Array()
			uv.resize(v.size())
		if idx == null or (idx as PackedInt32Array).is_empty():
			idx = PackedInt32Array(range(v.size()))
		var has_c: bool = c != null and (c as PackedColorArray).size() == v.size()
		out.append({"v": v, "n": n, "uv": uv, "c": c if has_c else PackedColorArray(), "color": has_c, "i": idx, "mat": e[1]})
	return out


## Une clé qui ne dépend que de la forme : la même pour deux primitives aux mêmes dimensions.
static func _shape_key(mesh: Mesh) -> Variant:
	if mesh is BoxMesh:
		var b := mesh as BoxMesh
		return "box%s|%d" % [b.size, b.material.get_instance_id() if b.material else 0]
	if mesh is SphereMesh or mesh is CylinderMesh or mesh is TorusMesh:
		_simplify(mesh)
		var props := []
		for p in mesh.get_property_list():
			if p.usage & PROPERTY_USAGE_STORAGE and p.name != "resource_name" and p.name != "resource_path":
				var v = mesh.get(p.name)
				props.append(v.get_instance_id() if v is Object else v)
		return mesh.get_class() + str(props)
	return mesh


## Les primitives de Godot sont très fines par défaut : une perle de lustre de 3 cm en sphère 64 × 32,
## c'est 4 000 triangles. On garde ce que l'œil voit à cette taille.
static func _simplify(mesh: Mesh) -> void:
	if mesh is SphereMesh:
		var sm := mesh as SphereMesh
		var seg := 12 if sm.radius < 0.12 else (20 if sm.radius < 0.4 else 32)
		sm.radial_segments = mini(sm.radial_segments, seg)
		sm.rings = mini(sm.rings, seg / 2)
	elif mesh is CylinderMesh:
		var cm := mesh as CylinderMesh
		cm.rings = 0
		var r := maxf(cm.top_radius, cm.bottom_radius)
		cm.radial_segments = mini(cm.radial_segments, 12 if r < 0.08 else (20 if r < 0.3 else 32))
	elif mesh is TorusMesh:
		var tm := mesh as TorusMesh
		tm.rings = mini(tm.rings, 24)
		tm.ring_segments = mini(tm.ring_segments, 8)


static func _static(mi: MeshInstance3D, root: Node, excluded: Dictionary) -> bool:
	if mi.mesh == null or mi.get_script() != null or not mi.is_visible_in_tree() or mi.skeleton != NodePath(""):
		return false
	if mi.material_overlay != null or not mi.get_meta_list().is_empty():
		return false
	var n: Node = mi.get_parent()
	while n != null and n != root:
		if excluded.has(n) or n.get_script() != null or not n.get_meta_list().is_empty():
			return false
		if n is SubViewport or n is CanvasItem:
			return false
		n = n.get_parent()
	return n == root


## Ce qu'on laisse à part : le transparent (trié objet par objet), les mélanges, le relief en carte de
## normales (il faudrait les tangentes), et les shaders qui dépendent de la position de l'objet.
static func _mergeable(mat: Material) -> bool:
	if mat is BaseMaterial3D:
		var b := mat as BaseMaterial3D
		if b.blend_mode != BaseMaterial3D.BLEND_MODE_MIX or b.normal_enabled or b.heightmap_enabled:
			return false
		return not b.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]
	if mat is ShaderMaterial:
		var sh: Shader = (mat as ShaderMaterial).shader
		if sh == null:
			return false
		for word in ["ALPHA", "blend_", "MODEL_MATRIX", "NODE_POSITION", "VERTEX +=", "VERTEX =", "NORMAL_MAP", "TANGENT"]:
			if word in sh.code:
				return false
		return true
	return false
