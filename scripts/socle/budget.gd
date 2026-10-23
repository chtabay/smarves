class_name Budget
extends RefCounted
## Le budget d'un lieu : ce qu'une scène demande à la carte graphique et au processeur une fois bâtie,
## et les seuils au-delà desquels un téléphone peine. Mesuré par `tools/budget_lieu.gd` sur les lieux
## du jeu et par l'emballeur sur chaque lieu d'un paquet (rangé dans le paquet, communes/<id>/budget.json,
## que le portail lit) ; rien ne refuse un lieu, on dit ce qui dépasse, dans les mots des auteurs.
##
## Les seuils (docs/LENTEUR.md, « Le budget par lieu ») : le casino de Smarves, le lieu le plus chargé
## qui tourne sur téléphone, sert de mesure ; un lieu qui le dépasse nettement y ramera.
##
## Les triangles et les surfaces sont ceux que la carte graphique dessine vraiment : d'un point de vue,
## seul ce qui entre dans le champ de la caméra, rien au-delà de sa distance de visibilité, et un maillage
## à niveaux de détail au niveau que le moteur choisit à cette distance (Lointain, CritterMesh). Les
## points de vue sont ceux où le joueur se tient : la caméra du lieu et ses zones d'interaction (portes,
## tables, habitants), regardant tout autour d'eux en DIRECTIONS directions ; le lieu compte pour le
## regard le plus chargé. « triangles_pleins » garde
## l'ancien compte : tout, partout, au niveau le plus fin. Comparé au moteur regard par regard, le compte
## reste un peu au-dessus de ce qu'il dessine (docs/LENTEUR.md), jamais en dessous. Sans rendu (--headless),
## le moteur oublie les instances des multimaillages : ils sont alors comptés en entier, partout.

const SEUILS := {
	"triangles": 600_000,     # triangles dessinés au regard le plus chargé, maillages fondus compris
	"surfaces": 2_500,        # surfaces dessinées (un appel de rendu chacune, à peu près)
	"lumieres": 80,           # lampes visibles
	"ombres": 8,              # lampes à ombres (chacune redessine la scène)
	"textures_mo": 96,        # textures uniques, en mémoire de la carte graphique
	"noeuds": 8_000,
	"actifs": 250,            # nœuds à script qui tournent à chaque image
	"etiquettes": 250,        # Label3D (une texture et un appel chacun)
}

## L'écran de référence pour les niveaux de détail : 1920 pixels de large, la caméra de Godot par défaut
## (75° de champ vertical) en 16:9. Le moteur garde le niveau dont l'erreur reste sous un pixel
## (rendering/mesh_lod/lod_change/threshold_pixels).
const ECRAN_PX := 1920.0
const CHAMP := 75.0
const ASPECT := 16.0 / 9.0
## Au plus tant de points de vue, et pas deux à moins de tant de mètres.
const POINTS_MAX := 48
const ECART_POINTS := 6.0
## Les directions où l'on regarde depuis chaque point (un tour complet).
const DIRECTIONS := 8

const NOMS := {
	"triangles": "triangles", "surfaces": "surfaces dessinées", "lumieres": "lampes", "ombres": "lampes à ombres",
	"textures_mo": "Mo de textures", "noeuds": "nœuds", "actifs": "scripts actifs", "etiquettes": "étiquettes",
}


## La mesure d'une scène déjà bâtie et dans l'arbre (quelques images après son arrivée, pour ce qu'elle
## remet à plus tard). Les clés sont celles de SEUILS, plus quelques détails.
## points : les points de vue (voir points_de_vue), directions : les regards à prendre (0 à DIRECTIONS - 1) ;
## par défaut, tous.
static func mesurer(racine: Node, points: Array = [], directions: Array = []) -> Dictionary:
	var m := {"triangles": 0, "surfaces": 0, "lumieres": 0, "ombres": 0, "textures_mo": 0.0, "noeuds": 0, "actifs": 0,
		"etiquettes": 0, "maillages": 0, "textures": 0, "particules": 0, "vues": 0, "triangles_pleins": 0,
		"surfaces_pleines": 0, "points_de_vue": 0, "point_le_plus_charge": [], "multimaillages_entiers": 0}
	var textures := {}
	var maillages := {}
	var dessins: Array = []
	var noeuds: Array = racine.find_children("*", "", true, false)
	noeuds.append(racine)
	m.noeuds = noeuds.size()
	for n in noeuds:
		if n.get_script() != null and (n.is_processing() or n.is_physics_processing()) and n.can_process():
			m.actifs += 1
		if n is MeshInstance3D and n.visible and n.is_visible_in_tree() and n.mesh != null:
			m.maillages += 1
			var tri := _triangles(n.mesh, maillages)
			m.triangles_pleins += tri
			m.surfaces_pleines += n.mesh.get_surface_count()
			dessins.append(_dessin(n, n.mesh, 1, tri))
			for s in n.mesh.get_surface_count():
				var mat: Material = n.get_active_material(s)
				_textures(mat, textures)
		elif n is MultiMeshInstance3D and n.is_visible_in_tree() and n.multimesh != null and n.multimesh.mesh != null:
			var k: int = n.multimesh.visible_instance_count if n.multimesh.visible_instance_count >= 0 else n.multimesh.instance_count
			m.maillages += 1
			m.triangles_pleins += _triangles(n.multimesh.mesh, maillages) * k
			m.surfaces_pleines += n.multimesh.mesh.get_surface_count()
			var dm := _dessin(n, n.multimesh.mesh, k, _triangles(n.multimesh.mesh, maillages))
			if dm.partout:
				m.multimaillages_entiers += 1
			dessins.append(dm)
			for s in n.multimesh.mesh.get_surface_count():
				_textures(n.material_override if n.material_override else n.multimesh.mesh.surface_get_material(s), textures)
		elif n is Light3D and n.is_visible_in_tree():
			m.lumieres += 1
			if n.shadow_enabled:
				m.ombres += 1
		elif n is Label3D and n.is_visible_in_tree():
			m.etiquettes += 1
			m.surfaces_pleines += 1
			dessins.append({"aabb": AABB(n.global_position, Vector3.ZERO), "debut": n.visibility_range_begin, "fin": n.visibility_range_end, "surfaces": [], "fois": 1, "tri": 0, "nb": 1, "partout": false})
		elif n is Sprite3D and n.is_visible_in_tree():
			m.surfaces_pleines += 1
			dessins.append({"aabb": AABB(n.global_position, Vector3.ZERO), "debut": n.visibility_range_begin, "fin": n.visibility_range_end, "surfaces": [], "fois": 1, "tri": 0, "nb": 1, "partout": false})
			_texture(n.texture, textures)
		elif n is GPUParticles3D or n is CPUParticles3D:
			m.particules += 1
		elif n is SubViewport:
			m.vues += 1
	# Ce qui est dessiné du regard le plus chargé.
	if points.is_empty():
		points = points_de_vue(racine)
	m.points_de_vue = points.size()
	var seuil := float(ProjectSettings.get_setting("rendering/mesh_lod/lod_change/threshold_pixels", 1.0)) / ECRAN_PX
	var mult := 2.0 * tan(deg_to_rad(CHAMP) / 2.0) * ASPECT
	var demi_v := deg_to_rad(CHAMP) / 2.0
	var demi_h := atan(tan(demi_v) * ASPECT)
	for pv in points:
		var p: Vector3 = pv[0]
		var vus: Array = []
		for d in dessins:
			var vu := _dessine(d, p, seuil, mult)
			if vu.y > 0:
				vus.append([d.aabb, vu, d.partout])
		for k in (directions if not directions.is_empty() else range(DIRECTIONS)):
			var b := Basis.from_euler(Vector3(pv[1], TAU * k / DIRECTIONS, 0.0))
			var plans := _champ(b, demi_h, demi_v)
			var tri := 0
			var surf := 0
			for v in vus:
				if v[2] or _dans_le_champ(v[0], p, plans):
					tri += v[1].x
					surf += v[1].y
			if tri > m.triangles or m.point_le_plus_charge.is_empty():
				m.triangles = tri
				m.surfaces = surf
				m.point_le_plus_charge = [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1), k * 360 / DIRECTIONS]
	var octets := 0
	for t in textures:
		octets += textures[t]
	m.textures = textures.size()
	m.textures_mo = snappedf(octets / 1048576.0, 0.1)
	return m


## Les points où le joueur se tient dans le lieu : la caméra en cours si elle en fait partie, les autres
## caméras, et ses zones d'interaction (Area3D : portes, tables, habitants), à hauteur d'yeux ; pas deux à
## moins de ECART_POINTS mètres, au plus POINTS_MAX. Sans rien de cela, le centre du lieu.
## Chaque point est [position, inclinaison du regard] : celle de la caméra pour une caméra (une vue de
## dessus regarde vers le sol), à l'horizontale ailleurs.
static func points_de_vue(racine: Node) -> Array:
	var bruts: Array = []
	var cam: Camera3D = racine.get_viewport().get_camera_3d() if racine.is_inside_tree() else null
	var cameras: Array = racine.find_children("*", "Camera3D", true, false)
	if cam != null and (cam == racine or racine.is_ancestor_of(cam)):
		cameras.erase(cam)
		cameras.push_front(cam)
	for c in cameras:
		if c.is_inside_tree():
			bruts.append([c.global_position, c.global_rotation.x])
	for a in racine.find_children("*", "Area3D", true, false):
		if a.is_inside_tree():
			bruts.append([a.global_position + Vector3(0, 1.6, 0), 0.0])
	var out: Array = []
	for p in bruts:
		var loin := true
		for q in out:
			if p[0].distance_to(q[0]) < ECART_POINTS:
				loin = false
				break
		if loin:
			out.append(p)
	if out.size() > POINTS_MAX:
		var pris: Array = []
		for i in POINTS_MAX:
			pris.append(out[i * out.size() / POINTS_MAX])
		out = pris
	if out.is_empty():
		out.append([racine.global_position if racine is Node3D and racine.is_inside_tree() else Vector3.ZERO, 0.0])
	return out


## Les quatre côtés du champ d'une caméra orientée par b (normales vers l'intérieur).
static func _champ(b: Basis, demi_h: float, demi_v: float) -> Array:
	var avant := -b.z
	return [
		(b.x * cos(demi_h) + avant * sin(demi_h)).normalized(),
		(-b.x * cos(demi_h) + avant * sin(demi_h)).normalized(),
		(b.y * cos(demi_v) + avant * sin(demi_v)).normalized(),
		(-b.y * cos(demi_v) + avant * sin(demi_v)).normalized(),
	]


## Vrai si la boîte entre, même en partie, dans le champ vu de p.
static func _dans_le_champ(aabb: AABB, p: Vector3, plans: Array) -> bool:
	if aabb.has_point(p):
		return true
	for n in plans:
		var coin := aabb.position + Vector3(aabb.size.x if n.x > 0.0 else 0.0, aabb.size.y if n.y > 0.0 else 0.0, aabb.size.z if n.z > 0.0 else 0.0)
		if n.dot(coin - p) < 0.0:
			return false
	return true


## Ce qu'il faut savoir d'un objet dessiné pour dire, d'un point de vue, combien il coûte : sa boîte, sa
## distance de visibilité, et pour chaque surface ses niveaux de détail (erreur, triangles).
static func _dessin(n: GeometryInstance3D, mesh: Mesh, fois: int, tri: int) -> Dictionary:
	var surfaces: Array = []
	if mesh is ArrayMesh:
		for s in mesh.get_surface_count():
			var d: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), s)
			var niveaux: Array = d.get("lods", [])
			if niveaux.is_empty():
				continue
			var ic: int = int(d.get("index_count", 0))
			var octets: int = (d.get("index_data") as PackedByteArray).size() / ic if ic > 0 else 4
			var base: int = ic / 3
			var l: Array = []
			for nv in niveaux:
				l.append([float(nv.edge_length), (nv.index_data as PackedByteArray).size() / octets / 3])
			surfaces.append({"base": base, "niveaux": l})
	var echelle := n.global_transform.basis.get_scale()
	# Sans rendu (--headless), le moteur ne garde pas les instances d'un multimaillage : sa boîte est vide.
	# On le compte alors en entier, partout et au niveau le plus fin.
	var partout := n is MultiMeshInstance3D and n.get_aabb().size == Vector3.ZERO
	var d := {"aabb": n.global_transform * n.get_aabb(), "debut": n.visibility_range_begin, "fin": n.visibility_range_end,
		"surfaces": [] if partout else surfaces, "fois": fois, "tri": tri, "nb": mesh.get_surface_count(), "partout": partout,
		"echelle": maxf(absf(echelle.x), maxf(absf(echelle.y), absf(echelle.z))) * n.lod_bias}
	# Un parent de visibilité (la version lointaine d'un quartier, Lointain.quartier) : l'objet n'est dessiné
	# que plus près du centre du parent que le début de sa distance.
	var parent := n.get_node_or_null(n.visibility_parent) as GeometryInstance3D if n.visibility_parent != NodePath("") else null
	if parent != null and parent.visibility_range_begin > 0.0:
		d.parent = [(parent.global_transform * parent.get_aabb()).get_center(), parent.visibility_range_begin]
	return d


## Triangles et surfaces dessinés d'un objet vu du point p, comme le moteur les choisit : hors de sa
## distance de visibilité (mesurée au centre de sa boîte), rien ; sinon, pour chaque surface à niveaux,
## le plus grossier dont l'erreur, rapportée à la distance de la boîte, reste sous le seuil d'un pixel.
static func _dessine(d: Dictionary, p: Vector3, seuil: float, mult: float) -> Vector2i:
	var aabb: AABB = d.aabb
	var centre := p.distance_to(aabb.get_center())
	if not d.partout and ((d.fin > 0.0 and centre > d.fin) or centre < d.debut):
		return Vector2i.ZERO
	if d.has("parent") and p.distance_to(d.parent[0]) >= d.parent[1]:
		return Vector2i.ZERO
	var tri: int = d.tri
	if not d.surfaces.is_empty():
		var dist := 0.0 if aabb.has_point(p) else p.distance_to(p.clamp(aabb.position, aabb.end))
		for s in d.surfaces:
			var garde: int = s.base
			if dist > 0.0:
				for nv in s.niveaux:
					if nv[0] * d.echelle / (dist * mult) > seuil:
						break
					garde = nv[1]
			tri -= s.base - garde
	return Vector2i(tri * d.fois, d.nb)


## Ce qui dépasse, dans les mots d'un auteur, vide si rien.
static func depassements(m: Dictionary, seuils: Dictionary = SEUILS) -> PackedStringArray:
	var out := PackedStringArray()
	for k in seuils:
		if m.get(k, 0) > seuils[k]:
			out.append("%s %s (au plus %s)" % [_nombre(m[k]), NOMS.get(k, k), _nombre(seuils[k])])
	return out


## Une ligne de résumé : « 265 000 triangles (410 000 au plus fin), 1 200 surfaces, 48 lampes dont 3 à ombres, 24,5 Mo de textures ».
static func resume(m: Dictionary) -> String:
	var pleins: int = m.get("triangles_pleins", 0)
	return "%s triangles%s, %s surfaces, %s lampes dont %s à ombres, %s Mo de textures, %s nœuds dont %s actifs" % [
		_nombre(m.triangles), " (%s au plus fin)" % _nombre(pleins) if pleins > m.triangles else "", _nombre(m.surfaces), _nombre(m.lumieres), _nombre(m.ombres), str(m.textures_mo).replace(".", ","),
		_nombre(m.noeuds), _nombre(m.actifs)]


static func _nombre(v) -> String:
	if v is float:
		return str(v).replace(".", ",")
	var s := str(int(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


static func _triangles(mesh: Mesh, cache: Dictionary) -> int:
	if cache.has(mesh):
		return cache[mesh]
	var n := 0
	for s in mesh.get_surface_count():
		var a: Array = mesh.surface_get_arrays(s)
		if a.is_empty() or a[Mesh.ARRAY_VERTEX] == null:
			continue
		var idx = a[Mesh.ARRAY_INDEX]
		var sommets: int = (idx as PackedInt32Array).size() if idx != null and not (idx as PackedInt32Array).is_empty() else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		n += sommets / 3
	cache[mesh] = n
	return n


static func _textures(mat: Material, textures: Dictionary) -> void:
	while mat != null:
		if mat is BaseMaterial3D:
			for p in mat.get_property_list():
				if p.name.ends_with("_texture") or p.name == "texture":
					var v = mat.get(p.name)
					if v is Texture2D:
						_texture(v, textures)
		elif mat is ShaderMaterial and mat.shader != null:
			for u in mat.shader.get_shader_uniform_list():
				var v = mat.get_shader_parameter(u.name)
				if v is Texture2D:
					_texture(v, textures)
		mat = mat.next_pass


static func _texture(t: Texture2D, textures: Dictionary) -> void:
	if t == null or textures.has(t):
		return
	var octets := 0
	if t is ViewportTexture:
		octets = t.get_width() * t.get_height() * 4
	else:
		var img := t.get_image()
		if img != null:
			octets = img.get_data().size()
			if not img.has_mipmaps():
				octets = int(octets * 1.33)
		else:
			octets = t.get_width() * t.get_height() * 4
	textures[t] = octets
