extends RefCounted
## Les arbres en dentelle de la bibliothèque (arbres-d-ombriere@1), repeints du vert posé des
## planches : leur contre-jour rend le vert citron à la lumière de Belley (verdicts du juge n° 1 et 2). En attendant
## une option de la brique, le feuillage prend la copie de Belley (atelier/feuillage_ombriere.gdshader).
##   REPEINDRE.feuillage(arbre)  # après add_child : l'arbre se bâtit en entrant dans l'arbre de scène

static var _pose: ShaderMaterial
static var _pose_platane: ShaderMaterial


static func feuillage(arbre: Node3D) -> void:
	# Les platanes de la bibliothèque sont presque noirs depuis la #299 (revue finale n° 1) : ils prennent eux
	# aussi le vert posé de Belley.
	if _pose == null:
		_pose = ShaderMaterial.new()
		_pose.shader = load("res://communes/belley/atelier/feuillage_ombriere.gdshader")
		_pose_platane = _pose.duplicate()
		_pose_platane.set_shader_parameter("eclat", 2.6)
	var pose := _pose_platane if str(arbre.get("arbre")) in ["platane", "jeune_platane"] else _pose
	for mi: MeshInstance3D in arbre.find_children("*", "MeshInstance3D", true, false):
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(i)
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader and (mat as ShaderMaterial).shader.resource_path == "res://bibliotheque/arbres-d-ombriere/1/feuillage.gdshader":
				mi.set_surface_override_material(i, pose)
