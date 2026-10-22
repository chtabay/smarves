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


## Vrai tant que des niveaux restent à lire ou à calculer (tests, captures : attendre image par image).
static func en_travail() -> bool:
	return en_cours > 0 or not _file.is_empty()


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
