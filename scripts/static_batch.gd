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
		if not cache.has(ck):
			cache[ck] = {"mesh": mi.mesh, "surfaces": _surfaces(mi.mesh)}
		var mesh: Mesh = cache[ck].mesh
		var surfaces: Array = cache[ck].surfaces
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
		for s in surfaces.size():
			var sf: Dictionary = surfaces[s]
			var key := "%d|%s|%s|%s|%d|%d|%s" % [mats[s].get_instance_id(), sf.color, sf.uv, sf.idx, mi.cast_shadow, mi.layers, str(cell)]
			if not groups.has(key):
				groups[key] = {"pieces": [], "mat": mats[s], "shadow": mi.cast_shadow, "layers": mi.layers}
			groups[key].pieces.append([mesh, s, xf])
		merged.append(mi)
	# La fonte elle-même se fait dans le moteur (SurfaceTool.append_from : sommets, normales, UV, couleurs
	# et indices transformés en C++) : en GDScript, sommet par sommet, le casino y passait 0,65 s.
	for key in groups:
		var g: Dictionary = groups[key]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for piece in g.pieces:
			st.append_from(piece[0], piece[1], piece[2])
		var out := MeshInstance3D.new()
		out.name = "Lot"
		out.mesh = st.commit()
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


## Ce qu'il faut savoir de chaque surface d'un maillage pour la fondre (matériau, couleurs par sommet,
## UV), ou [] si le maillage n'est pas fait de triangles avec leurs normales.
static func _surfaces(mesh: Mesh) -> Array:
	var out := []
	_simplify(mesh)
	if not (mesh is PrimitiveMesh or mesh is ArrayMesh):
		return []
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return []
		var a: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n = a[Mesh.ARRAY_NORMAL]
		if n == null or (n as PackedVector3Array).size() != v.size():
			return []
		var uv = a[Mesh.ARRAY_TEX_UV]
		var c = a[Mesh.ARRAY_COLOR]
		var has_c: bool = c != null and (c as PackedColorArray).size() == v.size()
		var has_uv: bool = uv != null and (uv as PackedVector2Array).size() == v.size()
		var idx = a[Mesh.ARRAY_INDEX]
		var has_i: bool = idx != null and not (idx as PackedInt32Array).is_empty()
		# Couleurs, UV, indices : un lot ne mêle pas des surfaces qui n'ont pas les mêmes tableaux.
		out.append({"color": has_c, "uv": has_uv, "idx": has_i, "mat": mesh.surface_get_material(s)})
	return out


## Une clé qui ne dépend que de la forme : la même pour deux primitives aux mêmes dimensions.
static func _shape_key(mesh: Mesh) -> Variant:
	var props := []
	if mesh is BoxMesh:
		props = [(mesh as BoxMesh).size, mesh.subdivide_width, mesh.subdivide_height, mesh.subdivide_depth]
	elif mesh is SphereMesh:
		props = [mesh.radius, mesh.height, mesh.radial_segments, mesh.rings, mesh.is_hemisphere]
	elif mesh is CylinderMesh:
		props = [mesh.top_radius, mesh.bottom_radius, mesh.height, mesh.radial_segments, mesh.rings, mesh.cap_top, mesh.cap_bottom]
	elif mesh is TorusMesh:
		props = [mesh.inner_radius, mesh.outer_radius, mesh.rings, mesh.ring_segments]
	else:
		return mesh
	var pm := mesh as PrimitiveMesh
	props.append(pm.material.get_instance_id() if pm.material else 0)
	props.append(pm.flip_faces)
	props.append(pm.add_uv2)
	return mesh.get_class() + str(props)


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
