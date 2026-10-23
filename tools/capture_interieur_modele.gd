extends SceneTree
## Capture d'un intérieur du socle sur un décor de la bibliothèque (ou de la commune), pour vérifier une brique
## de salle de jeu ou d'étude : la commune d'essai (tools/fixtures/salle_jeu/) prête son tripot ou son notaire.
## godot --path . -s tools/capture_interieur_modele.gd -- --modele=bar-des-sports@1 --capture=sortie.png
##   [--at=x,z,lacet] [--jeux=poker,machine,…]
## Le genre de la brique choisit la scène (salle_jeu.tscn ou etude.tscn), qui prend la capture elle-même.

const ESSAI := "res://tools/fixtures/salle_jeu/"
const TMP := "user://capture_interieur/"


func _init() -> void:
	await process_frame
	var modele := "bar-des-sports@1"
	var jeux := ["poker", "machine", "blackjack", "roulette"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--modele="):
			modele = arg.trim_prefix("--modele=")
		elif arg.begins_with("--jeux="):
			jeux = Array(arg.trim_prefix("--jeux=").split(","))
	root.get_node("Game").welcomed = true
	root.get_node("Game").saving_enabled = false
	var communes := root.get_node("Communes")
	if communes.commune("essai_salle") == null:
		# La commune d'essai se greffe comme un paquet, sous res://communes/essai_salle/.
		DirAccess.make_dir_recursive_absolute(TMP)
		var pk := PCKPacker.new()
		pk.pck_start(TMP + "essai_salle.pck")
		pk.add_file("res://communes/essai_salle/commune.json", ESSAI + "commune.json")
		pk.add_file("res://communes/essai_salle/commune.tscn", ESSAI + "commune.tscn")
		pk.flush()
		communes.dossier_greffes = TMP
		communes.charger_pack(TMP + "essai_salle.pck")
	var genre := str(Bibliotheque.brique(modele).get("genre", "salle_jeu")) if Bibliotheque.est_reference(modele) else ("etude" if "etude" in modele else "salle_jeu")
	if genre == "etude":
		communes.commune("essai_salle").data.notaire.modele = modele
		load("res://scripts/socle/etude.gd")._prochaine = "essai_salle"
		change_scene_to_file("res://scenes/etude.tscn")
	else:
		var s: Dictionary = root.get_node("Registre").structure("essai_salle/tripot")
		s.champs.modele = modele
		s.champs.jeux = jeux
		load("res://scripts/socle/salle_jeu.gd")._prochaine = ["essai_salle", "tripot"]
		change_scene_to_file("res://scenes/salle_jeu.tscn")
