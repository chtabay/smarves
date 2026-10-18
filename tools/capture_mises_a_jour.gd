extends SceneTree
## Captures des écrans de mises à jour, chaque état posé à la main :
## godot --path . -s tools/capture_mises_a_jour.gd -- --greffes=<dossier> --sortie=<dossier> --ecran=accueil|liste|carte|effacer

func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp"
	var ecran := "accueil"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
		elif arg.begins_with("--ecran="):
			ecran = arg.trim_prefix("--ecran=")
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	var communes: Node = root.get_node("Communes")
	var version: Node = root.get_node("Version")
	version.etat = "nouvelle"
	version.nouveautes.assign(["Mises à jour : une seule place, des états clairs", "Football de la Vienne : la pyramide qui lit les terrains"])
	communes.catalogue.append({"insee": "86082", "id": "croutelle", "nom": "Croutelle", "auteur": "Claude", "version": "0.1.0",
		"description": "", "paquet": "https://example.invalid/c.pck", "taille": 3_400_000, "sha256": "", "publie_le": ""})
	communes.catalogue_etat = "lu"
	communes.installations["liguge"] = "0.2.0"
	communes.echecs["croutelle"] = "Croutelle n'a pas pu être téléchargée : pas de réponse du serveur."
	communes.en_cours = "la_villedieu_du_clain"
	communes.etat_change.emit("liguge")
	if ecran == "carte":
		root.get_node("Carte").ouvrir()
		await create_timer(1.5).timeout
		var c = root.get_node("Carte").get("_carte")
		c.choix.emit("86133")
	else:
		var bienvenue: Node = root.get_node("Bienvenue")
		bienvenue.ouvrir(ecran == "liste")
		if ecran == "effacer":
			bienvenue.set("_effacer", true)
			bienvenue.call("_remplir")
	await create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(sortie.path_join(ecran + ".png"))
	quit()
