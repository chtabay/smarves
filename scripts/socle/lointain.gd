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
## 4. Un quartier qu'une commune désigne (Lointain.quartier, ou la méta « lointain » sur son nœud) a une
##    version lointaine : ses maillages fixes fondus en un seul par matière, qui reçoit ses niveaux de détail
##    comme un gros maillage (2.), sans ombre. Au-delà de la distance du quartier, le moteur dessine cette
##    version au lieu des centaines de petits maillages qui, chacun sous TRIANGLES_MIN, n'avaient pas de
##    niveaux (retour de l'auteur de Chauvigny : 581 613 triangles vus d'un point haut).

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
	for q in racine.find_children("*", "Node3D", true, false):
		if q.has_meta("lointain"):
			quartier(q, float(q.get_meta("lointain")))
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
	if not _taches.has(mesh):
		return
	en_cours -= 1
	_en_cours.erase(mesh)
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


## Le jeu qui se ferme (Chargement, en quittant l'arbre) attend les calculs lancés et oublie ceux en file :
## Godot ne s'arrête pas si une tâche du WorkerThreadPool est encore en file ou en cours quand il quitte,
## le fil principal attend des fils de travail endormis (Lyon : 16 maillages en calcul, fenêtre figée).
static func finir() -> void:
	_file.clear()
	for mesh in _taches:
		WorkerThreadPool.wait_for_task_completion(_taches[mesh])
	_taches.clear()
	_en_cours.clear()
	en_cours = 0


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


# --- Les quartiers lointains ---------------------------------------------------------------------

## La distance par défaut d'un quartier, en mètres, comptée du centre de sa boîte : un quartier de village
## fait 100 à 200 m de large.
const QUARTIER_DES := 150.0
## Les surfaces d'un maillage fondu : au-delà, un second maillage prend la suite.
const SURFACES_MAX := 64
## La version légère (quartier(q, des, true)) : en dessous de cette taille, en mètres, un maillage disparaît ;
## au-dessus de ce nombre de sommets, il devient sa boîte.
const LEGER_MIN := 1.0
const LEGER_SOMMETS := 2_000
## Au-delà de cette taille, en mètres, un maillage lourd n'est pas mis en boîte (ce n'est pas un objet, c'est
## un pan de quartier fondu) : il reste tel quel.
const LEGER_BOITE_MAX := 60.0
## La part des triangles qu'un maillage simplifié garde au moins (le niveau le plus grossier au-dessus).
const LEGER_PART := 0.1
## La teinte des boîtes dont la matière ne se lit pas (un shader) : un enduit moyen.
const ENDUIT_BOITE := Color("#d2c2a0")


## Donne au quartier (un nœud et tout ce qu'il porte) sa version lointaine : un nœud « <nom>_loin », enfant
## du quartier, dessiné au-delà de `des` mètres, quand ses maillages ne le sont plus. Ne sont pris que les
## maillages fixes et visibles : pas ceux à os, ni ceux qui ont déjà leur distance, ni ceux d'une branche
## marquée « sans_lointain » (une porte qui s'ouvre, une enseigne qui clignote). Renvoie le nombre de
## maillages fondus (0 : rien à faire, ou quartier déjà traité).
static func quartier(q: Node3D, des := QUARTIER_DES, leger := false) -> int:
	if not is_instance_valid(q) or q.has_meta("lointain_fait"):
		return 0
	q.set_meta("lointain_fait", true)
	var par_matiere := {}
	var pris: Array[MeshInstance3D] = []
	var repere := q.global_transform.affine_inverse()
	for mi: MeshInstance3D in q.find_children("*", "MeshInstance3D", true, false):
		if not _fondable(mi, q, leger):
			continue
		var t := repere * mi.global_transform
		if leger and mi.visibility_range_begin > 0.0:
			# Le niveau de détail lointain d'une brique (option « lod » du façadier) : c'est lui qu'on garde, tel quel.
			for s in mi.mesh.get_surface_count():
				var mat_l: Material = mi.material_override
				if mat_l == null:
					mat_l = mi.get_surface_override_material(s)
				if mat_l == null:
					mat_l = mi.mesh.surface_get_material(s)
				if not par_matiere.has(mat_l):
					par_matiere[mat_l] = []
				par_matiere[mat_l].append([mi.mesh, s, t])
			pris.append(mi)
			continue
		if leger:
			# La version légère d'un quartier de ville (socle 1.29) : ce qui fait moins de LEGER_MIN m ne se
			# voit pas d'un autre quartier et disparaît ; un maillage lourd (une façade ouvragée, un massif de
			# plantes) devient sa boîte, dans la matière de sa plus grande surface.
			var boite_mi := mi.mesh.get_aabb()
			if boite_mi.get_longest_axis_size() * t.basis.get_scale().x < LEGER_MIN:
				continue
			if _sommets(mi.mesh) > LEGER_SOMMETS:
				# Un maillage lourd est simplifié (le niveau le plus grossier de meshoptimizer), dans sa matière :
				# il garde sa silhouette, son toit et ses fenêtres. Une boîte, à défaut, si rien ne se simplifie.
				var simple := _simplifie(mi.mesh)
				if simple != null:
					for s in simple.get_surface_count():
						var mat_s: Material = mi.material_override
						if mat_s == null:
							mat_s = mi.get_surface_override_material(int(simple.surface_get_name(s)))
						if mat_s == null:
							mat_s = simple.surface_get_material(s)
						if not par_matiere.has(mat_s):
							par_matiere[mat_s] = []
						par_matiere[mat_s].append([simple, s, t])
					pris.append(mi)
					continue
				if boite_mi.get_longest_axis_size() * t.basis.get_scale().x <= LEGER_BOITE_MAX:
					var box := BoxMesh.new()
					box.size = boite_mi.size
					var mat := _matiere_boite(_matiere_principale(mi))
					if not par_matiere.has(mat):
						par_matiere[mat] = []
					par_matiere[mat].append([box, 0, t * Transform3D(Basis(), boite_mi.get_center())])
					pris.append(mi)
					continue
		for s in mi.mesh.get_surface_count():
			if mi.mesh is ArrayMesh and mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if not par_matiere.has(mat):
				par_matiere[mat] = []
			par_matiere[mat].append([mi.mesh, s, t])
		pris.append(mi)
	if pris.size() < 2:
		return 0
	var matieres := par_matiere.keys()
	var maillages: Array[ArrayMesh] = []
	var boite := AABB()
	for debut in range(0, matieres.size(), SURFACES_MAX):
		var am := ArrayMesh.new()
		for mat in matieres.slice(debut, debut + SURFACES_MAX):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for e in par_matiere[mat]:
				st.append_from(e[0], e[1], e[2])
			st.commit(am)
			am.surface_set_material(am.get_surface_count() - 1, mat)
		boite = am.get_aabb() if maillages.is_empty() else boite.merge(am.get_aabb())
		maillages.append(am)
	# La distance se mesure au centre de la boîte : tous les morceaux prennent celle du quartier entier.
	var premier: MeshInstance3D = null
	for am in maillages:
		am.custom_aabb = boite
		var loin := MeshInstance3D.new()
		loin.name = "%s_loin" % q.name
		loin.mesh = am
		loin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		loin.visibility_range_begin = des
		loin.visibility_range_begin_margin = MARGE
		loin.set_meta("lointain_quartier", true)
		q.add_child(loin, true)
		if premier == null:
			premier = loin
	# Le moteur montre chaque maillage d'origine tant qu'on est plus près que `des` du quartier (son parent
	# de visibilité), et la version lointaine au-delà : jamais les deux, jamais aucun.
	for mi in pris:
		mi.visibility_parent = mi.get_path_to(premier)
	return pris.size()


## Une copie simplifiée d'un maillage lourd : chaque surface de triangles au niveau de détail le plus grossier
## que meshoptimizer en tire (ImporterMesh.generate_lods), recompactée ; les surfaces gardent leur matière et
## portent en nom l'indice de la surface d'origine. null si rien ne se simplifie.
static func _simplifie(m: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	var avant := 0
	var apres := 0
	for s in m.get_surface_count():
		if m is ArrayMesh and (m as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := m.surface_get_arrays(s)
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var idx = arrays[Mesh.ARRAY_INDEX]
		if idx == null or (idx as PackedInt32Array).is_empty() or arrays[Mesh.ARRAY_NORMAL] == null:
			var st0 := SurfaceTool.new()
			st0.create_from_arrays(arrays)
			if arrays[Mesh.ARRAY_NORMAL] == null:
				st0.generate_normals()
			st0.index()
			arrays = st0.commit_to_arrays()
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		im.generate_lods(FUSION, ARETE, [])
		var n := im.get_surface_lod_count(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		# Le niveau le plus grossier qui garde au moins LEGER_PART des triangles, sinon le plus fin : au-delà,
		# la silhouette d'un bâtiment se perd.
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for l in n:
			var cand := im.get_surface_lod_indices(0, l)
			if cand.size() >= (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() * LEGER_PART or l == 0:
				indices = cand
		avant += verts.size()
		var normales = arrays[Mesh.ARRAY_NORMAL]
		var couleurs = arrays[Mesh.ARRAY_COLOR]
		var uv = arrays[Mesh.ARRAY_TEX_UV]
		var uv2 = arrays[Mesh.ARRAY_TEX_UV2]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in indices:
			if normales != null:
				st.set_normal(normales[i])
			if couleurs != null:
				st.set_color(couleurs[i])
			if uv != null:
				st.set_uv(uv[i])
			if uv2 != null:
				st.set_uv2(uv2[i])
			st.add_vertex(verts[i])
		st.index()
		st.commit(out)
		var k := out.get_surface_count() - 1
		out.surface_set_name(k, str(s))
		out.surface_set_material(k, m.surface_get_material(s))
		apres += out.surface_get_array_len(k)
	if out.get_surface_count() == 0 or apres * 2 > avant:
		return null
	return out


## Le nombre de sommets d'un maillage, toutes surfaces confondues.
static func _sommets(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		if m is ArrayMesh:
			n += (m as ArrayMesh).surface_get_array_len(s)
		else:
			var a := m.surface_get_arrays(s)
			if a.size() > Mesh.ARRAY_VERTEX and a[Mesh.ARRAY_VERTEX] != null:
				n += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n


## La matière d'une boîte : celle du maillage si elle est simple (BaseMaterial3D, éclairée), sinon un enduit
## moyen qui prend la lumière. Les boîtes d'une même teinte partagent leur matière.
static var _boites := {}
static func _matiere_boite(mat: Material) -> Material:
	if mat is BaseMaterial3D:
		return mat
	var c := ENDUIT_BOITE
	if mat is ShaderMaterial:
		for nom in ["teinte", "couleur", "albedo", "enduit"]:
			var v = (mat as ShaderMaterial).get_shader_parameter(nom)
			if v is Color:
				c = v
				break
	if not _boites.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_boites[c] = m
	return _boites[c]


## La matière de la plus grande surface d'un maillage (celle qui a le plus de sommets), résolue comme le moteur :
## la surcharge du nœud, puis celle de la surface, puis la matière du maillage.
static func _matiere_principale(mi: MeshInstance3D) -> Material:
	if mi.material_override != null:
		return mi.material_override
	var m := mi.mesh
	var meilleur := 0
	var taille := -1
	for s in m.get_surface_count():
		var n := (m as ArrayMesh).surface_get_array_len(s) if m is ArrayMesh else 1
		if n > taille:
			taille = n
			meilleur = s
	var mat: Material = mi.get_surface_override_material(meilleur)
	return mat if mat != null else m.surface_get_material(meilleur)


## En version légère, un maillage qui a déjà sa distance est pris s'il est le niveau lointain (il commence au
## loin) et laissé s'il est le niveau de près (il finit à une distance) : la brique a fait le travail.
static func _fondable(mi: MeshInstance3D, q: Node, leger := false) -> bool:
	if mi.mesh == null or mi.mesh.get_surface_count() == 0 or not mi.is_visible_in_tree():
		return false
	if mi.skeleton != NodePath(""):
		return false
	if mi.has_meta("lointain_quartier"):
		return false
	if leger:
		if (mi.visibility_range_end > 0.0 and mi.visibility_range_begin <= 0.0) or (mi.visibility_parent != NodePath("") and mi.visibility_range_begin <= 0.0):
			return false
	elif mi.visibility_range_end > 0.0 or mi.visibility_range_begin > 0.0 or mi.visibility_parent != NodePath(""):
		return false
	var n: Node = mi
	while n != null and n != q:
		if n.has_meta("sans_lointain"):
			return false
		n = n.get_parent()
	return true
