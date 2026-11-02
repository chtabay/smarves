extends SceneTree
## Le Dessous en images (scenes/dessous.tscn, scripts/socle/dessous_monde.gd) :
## xvfb-run godot --path . --rendering-driver opengl3 -s tools/capture_dessous.gd -- --sortie=dossier/
## L'arrivée figée à cinq instants (de loin, le bord, le pays, le Meru, la descente vers la clairière), la
## clairière en jeu, puis trois vues libres : le pays d'en haut, sous le disque, et le monde de nuit.

const PLANS := {"1-de-loin": 2.0, "2-par-dessus-le-bord": 5.8, "3-le-pays": 7.0, "4-sur-le-meru": 8.2,
	"5-vers-la-clairiere": 9.6}

## `--seulement=1,7` : les seules images dont le nom commence ainsi (pour aller vite).
var _seulement := PackedStringArray()


func _init() -> void:
	var sortie := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.trim_prefix("--sortie=")
		if a.begins_with("--seulement="):
			_seulement = a.trim_prefix("--seulement=").split(",")
	DirAccess.make_dir_recursive_absolute(sortie)
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true
	root.size = Vector2i(1600, 900)
	change_scene_to_file("res://scenes/dessous.tscn")
	await process_frame
	await process_frame
	var s: Node3D = current_scene
	for nom: String in PLANS:
		s.set("_figee", PLANS[nom])
		await _photo(sortie, nom)
	s.set("_figee", -1.0)
	s.call("_finir_arrivee")
	for _k in 120:
		await process_frame
	await _photo(sortie, "6-dans-la-clairiere")
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.far = 12000.0
	cam.near = 0.5
	root.add_child(cam)
	cam.make_current()
	var c0: Vector3 = s.CENTRE
	var vues := {
		"7-le-pays-d-en-haut": [c0 + Vector3(300, 900, 700), c0 + Vector3(0, -40, 40), 50.0, 0.0],
		"8-la-clairiere-et-le-meru": [Vector3(14, 9, 22), c0 + Vector3(0, 60, 0), 55.0, 0.0],
		"9-sous-le-disque": [c0 + Vector3(1200, -300, 950), c0 + Vector3(0, -240, 0), 50.0, 0.0],
		"10-de-nuit": [c0 + Vector3(-3000, 700, 2700), c0 + Vector3(0, -400, 0), 45.0, 170.0],
	}
	for nom: String in vues:
		var v: Array = vues[nom]
		s.set("_t", v[3])
		cam.fov = v[2]
		cam.look_at_from_position(v[0], v[1])
		await _photo(sortie, nom)
	quit()


func _photo(sortie: String, nom: String) -> void:
	if not _seulement.is_empty() and not _seulement.has(nom.get_slice("-", 0)):
		return
	for _k in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var f := sortie.path_join("%s.png" % nom)
	root.get_texture().get_image().save_png(f)
	print("capture : ", f)
