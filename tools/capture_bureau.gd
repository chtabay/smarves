extends SceneTree
## Captures du bureau du club, le mercredi de la troisième journée à 21 h, l'Étoile dirigée par vous :
## godot --path . --resolution 1600x900 -s tools/capture_bureau.gd -- --sortie=<fichier.png> [--bureau-page=tactique]
##   [--bureau-onglet=buteurs] [--base=600] (--base=600 et --resolution 1067x600 imitent un téléphone, comme Tactile).

const TMP := "user://capture_bureau/"


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/bureau.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
	var foot: Node = root.get_node("Football")
	var m: Node = root.get_node("Mercato")
	DirAccess.make_dir_recursive_absolute(TMP)
	foot.dossier = TMP
	m.dossier = TMP
	foot.effacer()
	m.effacer()
	var t: int = foot.coup_envoi(1, 3) + 3 * 86400 + 6 * 3600
	foot.regler_horloge(func(): return t)
	# Deux clubs inscrits au moins : le championnat en veut deux.
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	var club := "smarves"
	foot.forcer_porteurs("vous:2", club)
	root.get_node("Game").credits = 12500
	# Chargées ici, une fois les autoloads posés (Game, Football, Mercato).
	load("res://scripts/socle/foot_mercato.gd").demo(m, club)
	# Le crochet des renforts se pose en différé au démarrage : ici, tout de suite.
	foot.renforts = m.renforts
	foot.oublier_effectifs()
	var fond := ColorRect.new()
	fond.color = Color(0.05, 0.07, 0.08)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fond)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var b: Control = load("res://scripts/socle/bureau.gd").new()
	b.set("club", club)
	centre.add_child(b)
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(sortie)
	foot.effacer()
	m.effacer()
	quit()
