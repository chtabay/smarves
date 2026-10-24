extends SceneTree
## Capture de « Mes clubs » et de « Ma carrière » :
## godot --path . --resolution 1600x900 -s tools/capture_mes_clubs.gd -- --sortie=<dossier/>
## Images : club.png (la page de l'Étoile, journée 5 jouée), gerer.png (son bureau ouvert par-dessus le
## carnet, sur la tactique), boite.png (les messages, la carte du club et ses actions), calendrier.png (la dernière page de Mes
## clubs), carriere.png (la saison 1 close : la courbe de la fortune, le palmarès).

const TMP := "user://capture_mes_clubs/"
var t := 0


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/mes_clubs/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
	DirAccess.make_dir_recursive_absolute(sortie)
	DirAccess.make_dir_recursive_absolute(TMP)
	var carriere: GDScript = load("res://scripts/socle/carriere.gd")
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.won = 4000
	var avis: Node = root.get_node("Avis")
	var foot: Node = root.get_node("Football")
	avis.dossier = TMP
	avis.effacer()
	foot.dossier = TMP
	foot.effacer()
	carriere.dossier = TMP
	carriere.effacer()
	t = foot.coup_envoi(1, 5) + 26 * 3600
	foot.regler_horloge(func(): return t)
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	foot.forcer_porteurs("vous:3", "smarves")
	avis.verifier()
	avis.set("_file", [])
	var carnet: Node = root.get_node("Carnet")
	carnet.ouvrir_club("smarves")
	await _photo(sortie + "club.png")
	# « Gérer » : le bureau du club par-dessus le carnet, sur la tactique.
	carnet.gerer("football", "smarves", "tactique")
	await _photo(sortie + "gerer.png")
	carnet.fermer_gestion()
	carnet.ouvrir_onglet("boite")
	await _photo(sortie + "boite.png")
	carnet.ouvrir_onglet("calendrier")
	await _photo(sortie + "calendrier.png")
	carnet.toggle()
	t = foot.coup_envoi(2, 1) - 3600
	foot.actualiser()
	var f := [800, 1200, 950, 1600, 2100, 1850, 2600, 3100]
	for i in f.size():
		carriere.noter(f[i], t - (f.size() - i) * 7 * 86400, false)
	carnet.ouvrir_sur("carriere")
	await _photo(sortie + "carriere.png")
	carriere.effacer()
	avis.effacer()
	foot.effacer()
	quit()


func _photo(chemin: String) -> void:
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(chemin)
