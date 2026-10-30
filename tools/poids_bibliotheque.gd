extends SceneTree
## Le poids des briques : pour une brique (--ref=facadier-lyonnais@1, --cle=type) et chacun de ses noms (ou
## --nom=classique), les sommets et les triangles de chaque maillage, par surface, et avec --options={...}.
##   godot --headless --path . -s tools/poids_bibliotheque.gd -- --ref=facadier-lyonnais@1 --cle=type [--nom=cafe] [--options={"grain":1}]
## Les sommets sont ceux du maillage indexé ; les triangles, ce que le GPU dessine.
const Bibliotheque := preload("res://scripts/socle/bibliotheque.gd")


func _init() -> void:
	var ref := "facadier-lyonnais@1"
	var cle := "type"
	var seul := ""
	var options := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ref="):
			ref = a.trim_prefix("--ref=")
		elif a.begins_with("--cle="):
			cle = a.trim_prefix("--cle=")
		elif a.begins_with("--nom="):
			seul = a.trim_prefix("--nom=")
		elif a.begins_with("--options="):
			var j := JSON.new()
			if j.parse(a.trim_prefix("--options=")) == OK:
				options = j.data
	var paquet: PackedScene = load(Bibliotheque.scene(ref, "decor"))
	var liste := paquet.instantiate()
	var noms: Array = liste.call({"type": "types", "objet": "objets", "plante": "noms", "module": "noms"}[cle]) if seul == "" else [seul]
	liste.free()
	for nom in noms:
		var d: Node3D = paquet.instantiate()
		d.set(cle, nom)
		d.graine = 3
		d.options = options
		root.add_child(d)
		await process_frame
		var lignes := []
		var total := 0
		var tris := 0
		for mi in d.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = mi.mesh
			if mesh == null:
				continue
			var parts := []
			for si in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(si)
				var nv: int = arr[Mesh.ARRAY_VERTEX].size()
				var ni: int = arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else nv
				parts.append("%d/%d" % [nv, ni / 3])
				total += nv
				tris += ni / 3
			var portee := ""
			if mi.visibility_range_begin > 0.0 or mi.visibility_range_end > 0.0:
				portee = " [%d–%d m]" % [int(mi.visibility_range_begin), int(mi.visibility_range_end)]
			lignes.append("%s%s %s" % [mi.name, portee, " ".join(parts)])
		print("%-14s %7d sommets %7d triangles   %s" % [nom, total, tris, " | ".join(lignes)])
		d.free()
	quit()
