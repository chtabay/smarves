class_name Lointain
extends RefCounted
## Les objets vus de loin en version simplifiée, sans que les lieux aient rien à faire : Chargement
## l'applique à chaque scène qui arrive, une fois bâtie (docs/LENTEUR.md, « Les objets lointains »).
##
## 1. Les primitives (sphères, cylindres, capsules, tores) sont très fines par défaut : une perle de
##    lustre de 3 cm en sphère 64 × 32, c'est 4 000 triangles, et le casino en a trois cents. On ramène
##    leurs segments à ce que l'œil voit à leur taille réelle (la plus grande de leurs instances).
## 2. Les gros maillages (dix mille triangles et plus) reçoivent des niveaux de détail automatiques
##    (ImporterMesh.generate_lods, meshoptimizer) : le moteur dessine le niveau dont l'erreur reste sous
##    un pixel à l'écran. Le calcul se fait dans un fil, le maillage est remplacé quand il est prêt ;
##    de près, c'est le même maillage. Les maillages à os (figurines) ont les leurs (CritterMesh).
## 3. Les arbres des multimaillages, au-delà de IMPOSTEUR_DES mètres, deviennent des imposteurs : une
##    image de l'arbre, prise une fois au chargement, sur un panneau tourné vers la caméra. Le multimaillage
##    est découpé en cellules de CELLULE mètres, que le moteur passe de l'arbre à l'image selon la
##    distance ; de près, rien ne change. Sans rendu (--headless), il n'y a rien à photographier : rien ne
##    change non plus.

const TRIANGLES_MIN := 10_000
## Angles de generate_lods : les normales plus proches que le premier se fondent, plus écartées que le
## second font une arête vive.
const FUSION := 25.0
const ARETE := 60.0

## Les calculs de niveaux en cours (maillages), pour les tests.
static var en_cours := 0


static func appliquer(racine: Node) -> void:
	if not is_instance_valid(racine) or not racine.is_inside_tree():
		return
	simplifier(racine)
	niveaux(racine)
	imposteurs(racine)


# --- Les primitives ---------------------------------------------------------------------------

## Ramène les primitives de la scène aux segments de leur taille vue. Renvoie le nombre de maillages touchés.
static func simplifier(racine: Node) -> int:
	var rayons := {}
	for mi in racine.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is PrimitiveMesh and _rayon(mi.mesh) > 0.0:
			var r: float = _rayon(mi.mesh) * _echelle(mi.global_transform.basis)
			rayons[mi.mesh] = maxf(rayons.get(mi.mesh, 0.0), r)
	for mm in racine.find_children("*", "MultiMeshInstance3D", true, false):
		var m: MultiMesh = mm.multimesh
		if m == null or not m.mesh is PrimitiveMesh or _rayon(m.mesh) <= 0.0:
			continue
		var e := _echelle(mm.global_transform.basis)
		var e_max := 0.0
		for i in mini(m.instance_count, 64):
			e_max = maxf(e_max, _echelle(m.get_instance_transform(i).basis))
		if m.instance_count == 0:
			e_max = 1.0
		rayons[m.mesh] = maxf(rayons.get(m.mesh, 0.0), _rayon(m.mesh) * e * e_max)
	var n := 0
	for mesh in rayons:
		if simplifier_primitive(mesh, rayons[mesh]):
			n += 1
	return n


## Les segments d'une primitive pour un rayon vu de `rayon` mètres ; vrai si le maillage a changé.
static func simplifier_primitive(mesh: PrimitiveMesh, rayon: float) -> bool:
	var seg := 12 if rayon < 0.12 else (20 if rayon < 0.4 else 32)
	var avant := [mesh.get("radial_segments"), mesh.get("rings"), mesh.get("ring_segments")]
	if mesh is SphereMesh:
		mesh.radial_segments = mini(mesh.radial_segments, seg)
		mesh.rings = mini(mesh.rings, seg / 2)
	elif mesh is CylinderMesh:
		mesh.rings = 0
		mesh.radial_segments = mini(mesh.radial_segments, seg)
	elif mesh is CapsuleMesh:
		mesh.radial_segments = mini(mesh.radial_segments, seg)
		mesh.rings = mini(mesh.rings, maxi(2, seg / 4))
	elif mesh is TorusMesh:
		mesh.rings = mini(mesh.rings, 24 if rayon >= 0.4 else 16)
		mesh.ring_segments = mini(mesh.ring_segments, 8 if rayon < 0.12 else 12)
	else:
		return false
	return avant != [mesh.get("radial_segments"), mesh.get("rings"), mesh.get("ring_segments")]


static func _rayon(mesh: Mesh) -> float:
	if mesh is SphereMesh:
		return mesh.radius
	if mesh is CylinderMesh:
		return maxf(mesh.top_radius, mesh.bottom_radius)
	if mesh is CapsuleMesh:
		return mesh.radius
	if mesh is TorusMesh:
		return mesh.outer_radius
	return 0.0


static func _echelle(b: Basis) -> float:
	var s := b.get_scale()
	return maxf(absf(s.x), maxf(absf(s.y), absf(s.z)))


# --- Les niveaux de détail -----------------------------------------------------------------------

## Donne des niveaux de détail aux gros maillages de la scène : un maillage par image est lu sur le fil
## principal (les maisons d'Availles, 1,6 million de triangles, demanderaient 0,6 s d'un coup), puis ses
## niveaux se calculent dans un fil. Renvoie le nombre de maillages mis en file.
static func niveaux(racine: Node) -> int:
	var par_maillage := {}
	for mi in racine.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		if not mesh is ArrayMesh or mi.skeleton != NodePath("") or mesh.get_surface_count() == 0:
			continue
		if par_maillage.has(mesh):
			par_maillage[mesh].append(weakref(mi))
			continue
		if _en_cours.has(mesh) or _triangles(mesh) < TRIANGLES_MIN or _a_des_niveaux(mesh) or _a_des_os(mesh):
			continue
		par_maillage[mesh] = [weakref(mi)]
	for mesh in par_maillage:
		_en_cours[mesh] = true
		_file.append([mesh, par_maillage[mesh]])
	en_cours += par_maillage.size()
	if not par_maillage.is_empty():
		_suivant()
	return par_maillage.size()


static var _file: Array = []
## Les maillages en file ou en calcul : une scène qui arrive deux fois ne les remet pas en file.
static var _en_cours := {}
## La tâche de chaque maillage en calcul : le fil la garde (avec ses tableaux) tant qu'on ne l'a pas relevée.
static var _taches := {}


## Lit le prochain maillage de la file et lance le calcul de ses niveaux ; le suivant à l'image d'après.
static func _suivant() -> void:
	if _file.is_empty():
		return
	var e: Array = _file.pop_front()
	var mesh: ArrayMesh = e[0]
	var surfaces := []
	for s in mesh.get_surface_count():
		surfaces.append({"prim": mesh.surface_get_primitive_type(s), "arrays": mesh.surface_get_arrays(s), "mat": mesh.surface_get_material(s)})
	_taches[mesh] = WorkerThreadPool.add_task(_calculer.bind(mesh, surfaces, e[1]), false, "Niveaux de détail")
	if not _file.is_empty():
		Engine.get_main_loop().process_frame.connect(_suivant, CONNECT_ONE_SHOT)


## Dans un fil : indexe les surfaces qui ne le sont pas, calcule leurs niveaux, puis remet la main au fil
## principal pour poser le maillage.
static func _calculer(mesh: ArrayMesh, surfaces: Array, instances: Array) -> void:
	for sf in surfaces:
		var arrays: Array = sf.arrays
		var idx = arrays[Mesh.ARRAY_INDEX]
		if sf.prim == Mesh.PRIMITIVE_TRIANGLES and (idx == null or (idx as PackedInt32Array).is_empty()):
			var st := SurfaceTool.new()
			st.create_from_arrays(arrays)
			st.index()
			arrays = st.commit_to_arrays()
			sf.arrays = arrays
		var im := ImporterMesh.new()
		im.add_surface(sf.prim, arrays)
		im.generate_lods(FUSION, ARETE, [])
		var lods := {}
		for l in im.get_surface_lod_count(0):
			lods[im.get_surface_lod_size(0, l)] = im.get_surface_lod_indices(0, l)
		sf.lods = lods
	Callable(Lointain, "_poser").call_deferred(mesh, surfaces, instances)


static func _poser(mesh: ArrayMesh, surfaces: Array, instances: Array) -> void:
	en_cours -= 1
	_en_cours.erase(mesh)
	if _taches.has(mesh):
		WorkerThreadPool.wait_for_task_completion(_taches[mesh])
		_taches.erase(mesh)
	var nouveau := ArrayMesh.new()
	for sf in surfaces:
		nouveau.add_surface_from_arrays(sf.prim, sf.arrays, [], sf.lods)
		if sf.mat != null:
			nouveau.surface_set_material(nouveau.get_surface_count() - 1, sf.mat)
	for w in instances:
		var mi = w.get_ref()
		if mi != null and is_instance_valid(mi) and mi.mesh == mesh:
			mi.mesh = nouveau


## Vrai tant que des niveaux restent à lire ou à calculer, ou des imposteurs à photographier (tests,
## captures : attendre image par image).
static func en_travail() -> bool:
	return en_cours > 0 or not _file.is_empty() or _photos > 0


static func _triangles(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var d: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), s)
		n += int(d.get("index_count", 0)) / 3 if int(d.get("index_count", 0)) > 0 else int(d.get("vertex_count", 0)) / 3
	return n


static func _a_des_niveaux(mesh: Mesh) -> bool:
	return RenderingServer.mesh_get_surface(mesh.get_rid(), 0).has("lods")


static func _a_des_os(mesh: Mesh) -> bool:
	return mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES


# --- Les arbres lointains ------------------------------------------------------------------------

## Au-delà de cette distance (au centre de sa cellule), un arbre se dessine en image.
const IMPOSTEUR_DES := 120.0
const CELLULE := 30.0
## Marge autour de la distance de bascule, pour que l'arbre ne clignote pas quand on s'y tient.
const MARGE := 4.0
## Hauteur de la photo d'un arbre, en pixels (à 120 m, un arbre de 10 m en fait une soixantaine à l'écran).
const PHOTO_PX := 256
## Ce qui est un arbre ou un buisson : au moins HAUTEUR_MIN mètres de haut, TRIANGLES_ARBRE triangles (en
## deçà, le panneau ne gagne presque rien), une emprise à peu près ronde (une haie, une rangée de vigne, un mur
## ne tournent pas avec la caméra).
const HAUTEUR_MIN := 0.5
const TRIANGLES_ARBRE := 48
const EMPRISE := 2.0

## Les photos en cours (une par maillage d'arbre).
static var _photos := 0


## Remplace au loin les arbres des multimaillages de la scène par leurs imposteurs. Renvoie le nombre de
## multimaillages pris ; les photos se font aux images suivantes, puis les cellules se posent.
static func imposteurs(racine: Node) -> int:
	if DisplayServer.get_name() == "headless":
		return 0
	var par_maillage := {}
	for mm in racine.find_children("*", "MultiMeshInstance3D", true, false):
		if _arbre(mm):
			mm.set_meta("lointain_imposteur", true)
			var cle := [mm.multimesh.mesh, mm.material_override]
			if not par_maillage.has(cle):
				par_maillage[cle] = []
			par_maillage[cle].append(weakref(mm))
	for cle in par_maillage:
		_photographier(cle[0], cle[1], par_maillage[cle])
	return par_maillage.values().reduce(func(a, l): return a + l.size(), 0)


## Vrai si ce multimaillage est une plantation d'arbres que rien d'autre ne règle déjà.
static func _arbre(mm: MultiMeshInstance3D) -> bool:
	var m := mm.multimesh
	if m == null or m.mesh == null or m.instance_count == 0 or m.transform_format != MultiMesh.TRANSFORM_3D:
		return false
	if mm.has_meta("lointain_imposteur") or mm.visibility_range_end > 0.0 or mm.visibility_range_begin > 0.0 or not mm.visible:
		return false
	# Un multimaillage qu'un script tient (une foule qui se lève, des instances comptées, des données par
	# instance pour un shader) n'est pas une plantation : on n'y touche pas. Les capsules non plus : ce sont
	# les gens des foules.
	if m.visible_instance_count >= 0 or m.use_custom_data or m.mesh is CapsuleMesh or mm.get_script() != null:
		return false
	if m.mesh.get_surface_count() == 0 or (m.mesh is ArrayMesh and _a_des_os(m.mesh)):
		return false
	var a := m.mesh.get_aabb()
	var e := _echelle(mm.global_transform.basis) * _echelle(m.get_instance_transform(0).basis)
	var large := maxf(a.size.x, a.size.z)
	if a.size.y * e < HAUTEUR_MIN or minf(a.size.x, a.size.z) <= 0.0 or _triangles(m.mesh) < TRIANGLES_ARBRE:
		return false
	return large / minf(a.size.x, a.size.z) <= EMPRISE


## Photographie l'arbre (sa couleur propre, sans lumière : le panneau est éclairé par la scène), puis pose
## les imposteurs de chaque multimaillage qui le porte.
static func _photographier(mesh: Mesh, matiere: Material, porteurs: Array) -> void:
	_photos += 1
	var a := mesh.get_aabb()
	var large := maxf(a.size.x, a.size.z)
	var vp := SubViewport.new()
	vp.size = Vector2i(maxi(16, int(PHOTO_PX * large / a.size.y)), PHOTO_PX)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.world_3d = World3D.new()
	vp.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = matiere
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = a.size.y
	cam.near = 0.05
	cam.far = a.size.z + 2.0 * large + 2.0
	cam.position = Vector3(a.get_center().x, a.get_center().y, a.end.z + large + 1.0)
	vp.add_child(cam)
	var arbre := Engine.get_main_loop() as SceneTree
	arbre.root.add_child.call_deferred(vp)
	await arbre.process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	_photos -= 1
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_RGBA8)
	img.fix_alpha_edges()
	img.generate_mipmaps()
	var panneau := QuadMesh.new()
	panneau.size = Vector2(large, a.size.y)
	# Le panneau tourne autour de son centre : chaque instance le pose au centre de son arbre (_morceau).
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	# Le panneau est éclairé comme une boule (une couronne d'arbre), pas comme une feuille de papier.
	mat.normal_enabled = true
	mat.normal_texture = _boule()
	panneau.material = mat
	for w in porteurs:
		var mm = w.get_ref()
		if mm != null and is_instance_valid(mm) and mm.is_inside_tree() and mm.multimesh != null and mm.multimesh.mesh == mesh:
			_decouper(mm, panneau)


static var _normales_boule: Texture2D


## La carte de normales d'une demi-boule, vue de face : le panneau prend la lumière d'un côté, l'ombre de l'autre.
static func _boule() -> Texture2D:
	if _normales_boule == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		for y in n:
			for x in n:
				var v := Vector2((x + 0.5) / n * 2.0 - 1.0, 1.0 - (y + 0.5) / n * 2.0) * 0.8
				if v.length() > 0.95:
					v = v.normalized() * 0.95
				var z := sqrt(1.0 - v.length_squared())
				img.set_pixel(x, y, Color(v.x * 0.5 + 0.5, v.y * 0.5 + 0.5, z * 0.5 + 0.5))
		img.generate_mipmaps()
		_normales_boule = ImageTexture.create_from_image(img)
	return _normales_boule


## Range les arbres du multimaillage par cellules : pour chacune, les arbres jusqu'à IMPOSTEUR_DES mètres
## et leurs panneaux au-delà. Le multimaillage d'origine reste, caché.
static func _decouper(mm: MultiMeshInstance3D, panneau: Mesh) -> void:
	var m := mm.multimesh
	var cellules := {}
	for i in m.instance_count:
		var p: Vector3 = mm.global_transform * m.get_instance_transform(i).origin
		var k := Vector2i(floori(p.x / CELLULE), floori(p.z / CELLULE))
		if not cellules.has(k):
			cellules[k] = []
		cellules[k].append(i)
	var parent := mm.get_parent()
	for k in cellules:
		var pres := _morceau(mm, m.mesh, cellules[k], "pres")
		pres.cast_shadow = mm.cast_shadow
		pres.material_override = mm.material_override
		pres.visibility_range_end = IMPOSTEUR_DES
		pres.visibility_range_end_margin = MARGE
		parent.add_child(pres, true)
		var loin := _morceau(mm, panneau, cellules[k], "loin", m.mesh.get_aabb().get_center())
		loin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		loin.visibility_range_begin = IMPOSTEUR_DES
		loin.visibility_range_begin_margin = MARGE
		parent.add_child(loin, true)
	mm.visible = false


## Un multimaillage des instances indices de mm, portant mesh ; centre : là où poser un panneau dans le
## repère de l'arbre (le centre de sa boîte), qui tourne sur lui-même au lieu de tourner autour du pied.
static func _morceau(mm: MultiMeshInstance3D, mesh: Mesh, indices: Array, quoi: String, centre = null) -> MultiMeshInstance3D:
	var m := mm.multimesh
	var n := MultiMesh.new()
	n.transform_format = MultiMesh.TRANSFORM_3D
	n.use_colors = m.use_colors
	n.use_custom_data = m.use_custom_data
	n.mesh = mesh
	n.instance_count = indices.size()
	for j in indices.size():
		var i: int = indices[j]
		var t := m.get_instance_transform(i)
		if centre != null:
			t.origin = t * centre
		n.set_instance_transform(j, t)
		if m.use_colors:
			n.set_instance_color(j, m.get_instance_color(i))
		if m.use_custom_data:
			n.set_instance_custom_data(j, m.get_instance_custom_data(i))
	var out := MultiMeshInstance3D.new()
	out.name = "%s_%s" % [mm.name, quoi]
	out.multimesh = n
	out.transform = mm.transform
	out.layers = mm.layers
	out.set_meta("lointain_imposteur", true)
	return out
