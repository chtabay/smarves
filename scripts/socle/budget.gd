class_name Budget
extends RefCounted
## Le budget d'un lieu : ce qu'une scène demande à la carte graphique et au processeur une fois bâtie,
## et les seuils au-delà desquels un téléphone peine. Mesuré par `tools/budget_lieu.gd` sur les lieux
## du jeu et par l'emballeur sur chaque lieu d'un paquet (rangé dans le paquet, communes/<id>/budget.json,
## que le portail lit) ; rien ne refuse un lieu, on dit ce qui dépasse, dans les mots des auteurs.
##
## Les seuils (docs/LENTEUR.md, « Le budget par lieu ») : le casino de Smarves, le lieu le plus chargé
## qui tourne sur téléphone, sert de mesure ; un lieu qui le dépasse nettement y ramera.

const SEUILS := {
	"triangles": 600_000,     # triangles visibles, maillages fondus compris
	"surfaces": 2_500,        # surfaces dessinées (un appel de rendu chacune, à peu près)
	"lumieres": 80,           # lampes visibles
	"ombres": 8,              # lampes à ombres (chacune redessine la scène)
	"textures_mo": 96,        # textures uniques, en mémoire de la carte graphique
	"noeuds": 8_000,
	"actifs": 250,            # nœuds à script qui tournent à chaque image
	"etiquettes": 250,        # Label3D (une texture et un appel chacun)
}

const NOMS := {
	"triangles": "triangles", "surfaces": "surfaces dessinées", "lumieres": "lampes", "ombres": "lampes à ombres",
	"textures_mo": "Mo de textures", "noeuds": "nœuds", "actifs": "scripts actifs", "etiquettes": "étiquettes",
}


## La mesure d'une scène déjà bâtie et dans l'arbre (quelques images après son arrivée, pour ce qu'elle
## remet à plus tard). Les clés sont celles de SEUILS, plus quelques détails.
static func mesurer(racine: Node) -> Dictionary:
	var m := {"triangles": 0, "surfaces": 0, "lumieres": 0, "ombres": 0, "textures_mo": 0.0, "noeuds": 0, "actifs": 0,
		"etiquettes": 0, "maillages": 0, "textures": 0, "particules": 0, "vues": 0}
	var textures := {}
	var maillages := {}
	var noeuds: Array = racine.find_children("*", "", true, false)
	noeuds.append(racine)
	m.noeuds = noeuds.size()
	for n in noeuds:
		if n.get_script() != null and (n.is_processing() or n.is_physics_processing()) and n.can_process():
			m.actifs += 1
		if n is MeshInstance3D and n.visible and n.is_visible_in_tree() and n.mesh != null:
			m.maillages += 1
			var tri := _triangles(n.mesh, maillages)
			m.triangles += tri
			m.surfaces += n.mesh.get_surface_count()
			for s in n.mesh.get_surface_count():
				var mat: Material = n.get_active_material(s)
				_textures(mat, textures)
		elif n is MultiMeshInstance3D and n.is_visible_in_tree() and n.multimesh != null and n.multimesh.mesh != null:
			var k: int = n.multimesh.visible_instance_count if n.multimesh.visible_instance_count >= 0 else n.multimesh.instance_count
			m.maillages += 1
			m.triangles += _triangles(n.multimesh.mesh, maillages) * k
			m.surfaces += n.multimesh.mesh.get_surface_count()
			for s in n.multimesh.mesh.get_surface_count():
				_textures(n.material_override if n.material_override else n.multimesh.mesh.surface_get_material(s), textures)
		elif n is Light3D and n.is_visible_in_tree():
			m.lumieres += 1
			if n.shadow_enabled:
				m.ombres += 1
		elif n is Label3D and n.is_visible_in_tree():
			m.etiquettes += 1
			m.surfaces += 1
		elif n is Sprite3D and n.is_visible_in_tree():
			m.surfaces += 1
			_texture(n.texture, textures)
		elif n is GPUParticles3D or n is CPUParticles3D:
			m.particules += 1
		elif n is SubViewport:
			m.vues += 1
	var octets := 0
	for t in textures:
		octets += textures[t]
	m.textures = textures.size()
	m.textures_mo = snappedf(octets / 1048576.0, 0.1)
	return m


## Ce qui dépasse, dans les mots d'un auteur, vide si rien.
static func depassements(m: Dictionary, seuils: Dictionary = SEUILS) -> PackedStringArray:
	var out := PackedStringArray()
	for k in seuils:
		if m.get(k, 0) > seuils[k]:
			out.append("%s %s (au plus %s)" % [_nombre(m[k]), NOMS.get(k, k), _nombre(seuils[k])])
	return out


## Une ligne de résumé : « 265 000 triangles, 1 200 surfaces, 48 lampes dont 3 à ombres, 24,5 Mo de textures ».
static func resume(m: Dictionary) -> String:
	return "%s triangles, %s surfaces, %s lampes dont %s à ombres, %s Mo de textures, %s nœuds dont %s actifs" % [
		_nombre(m.triangles), _nombre(m.surfaces), _nombre(m.lumieres), _nombre(m.ombres), str(m.textures_mo).replace(".", ","),
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
