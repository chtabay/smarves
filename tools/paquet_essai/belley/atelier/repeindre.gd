extends RefCounted
## Les arbres en dentelle de la bibliothèque (arbres-d-ombriere@1), repeints du vert posé des
## planches : leur contre-jour rend le vert citron à la lumière de Belley (verdicts du juge n° 1 et 2). En attendant
## une option de la brique, le feuillage prend la copie de Belley (atelier/feuillage_ombriere.gdshader).
##   REPEINDRE.feuillage(arbre)  # après add_child : l'arbre se bâtit en entrant dans l'arbre de scène

static var _pose: ShaderMaterial


static func feuillage(arbre: Node3D) -> void:
	if _pose == null:
		_pose = ShaderMaterial.new()
		_pose.shader = load("res://communes/belley/atelier/feuillage_ombriere.gdshader")
	for mi: MeshInstance3D in arbre.find_children("*", "MeshInstance3D", true, false):
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(i)
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader and (mat as ShaderMaterial).shader.resource_path == "res://bibliotheque/arbres-d-ombriere/1/feuillage.gdshader":
				mi.set_surface_override_material(i, _pose)
