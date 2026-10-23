extends SceneTree
## Captures du courrier (autoload Avis), sur la place, avec un courrier d'essai : la fiche d'un match, la
## fiche qui résume l'absence, la pastille, l'onglet « Courrier » du carnet :
## godot --path . -s tools/capture_avis.gd -- --sortie=<dossier/> [--tactile --base=600]
## (fiche.png, absence.png, pastille.png, courrier.png ; --tactile --base=600 imite un téléphone.)

const TMP := "user://capture_avis/"


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/avis/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
	DirAccess.make_dir_recursive_absolute(sortie)
	DirAccess.make_dir_recursive_absolute(TMP)
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.won = 4000
	game.credits = 6400
	var avis: Node = root.get_node("Avis")
	avis.dossier = TMP
	avis.effacer()
	var t: int = avis.maintenant()
	var h := 3600
	var etoile := {"vers": "bureau", "club": "smarves", "page": "championnat"}
	for a in [
		{"id": "1", "quand": t - 50 * h, "genre": "biens", "importance": "discrete", "titre": "La recette : 420 versés, 85 de charges.", "lien": {"vers": "carnet", "onglet": "compte"}},
		{"id": "2", "quand": t - 30 * h, "genre": "ticket", "importance": "discrete", "titre": "Ticket de la journée 6 : perdu", "texte": "Mise 50, cote 2.35.", "lien": {"vers": "carnet", "onglet": "compte"}},
		{"id": "3", "quand": t - 26 * h, "genre": "rappel", "titre": "L'Étoile de Smarves : la composition de demain n'est pas posée", "texte": "Sans consigne, l'adjoint aligne l'équipe type en 4-4-2, mentalité équilibrée. Coup d'envoi demain à 15 h.", "lien": {"vers": "bureau", "club": "smarves", "page": "tactique"}},
	]:
		avis.publier(a)
	avis.tout_lu()
	for a in [
		{"id": "4", "quand": t - 5 * h, "genre": "match", "titre": "L'Étoile de Smarves : victoire 2-1 contre Ligugé", "texte": "Journée 7. 3e du groupe après la journée.", "lien": etoile},
		{"id": "5", "quand": t - 3 * h, "genre": "dividende", "montant": 380, "titre": "L'Étoile de Smarves : 380 crédits de dividende", "texte": "Journée 7.", "lien": {"vers": "carnet", "onglet": "compte"}},
		{"id": "6", "quand": t - 2 * h, "genre": "ticket", "titre": "Ticket de la journée 7 : gagné, 117 crédits", "texte": "Mise 50, cote 2.35.", "lien": {"vers": "carnet", "onglet": "compte"}},
		{"id": "7", "quand": t - h, "genre": "parts", "importance": "forte", "titre": "Lucien a pris l'obligation n° 5 de L'Étoile de Smarves", "lien": {"vers": "registre", "club": "smarves"}},
	]:
		avis.publier(a)
	avis.set("_file", [])
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	var carnet: Node = root.get_node("Carnet")
	# La fiche d'un avis seul, puis celle qui résume l'absence.
	avis.set("_file", [avis.liste[3]])
	avis.montrer_file()
	await _photo(sortie + "fiche.png", 1.2)
	avis.set("_absence", true)
	avis.set("_file", avis.non_lus())
	avis.montrer_file()
	await _photo(sortie + "absence.png", 1.2)
	# La fiche partie, la pastille reste.
	(carnet.get("_slip") as Control).visible = false
	await _photo(sortie + "pastille.png", 0.6)
	carnet.ouvrir_sur("courrier")
	await _photo(sortie + "courrier.png", 0.8)
	avis.effacer()
	quit()


func _photo(chemin: String, attente: float) -> void:
	await create_timer(attente).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(chemin)
