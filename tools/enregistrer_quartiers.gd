extends SceneTree
## Enregistre d'avance les quartiers d'une commune (socle 1.21, scripts/socle/quartiers.gd) : chaque quartier
## que le manifeste nomme (champ « quartiers ») est bâti par son script, puis rangé en scène .scn compressée
## là où le manifeste le dit. Le jeu lit ensuite ces scènes dans un fil au lieu de tout rebâtir.
##   godot --headless --path . -s tools/enregistrer_quartiers.gd -- <id> [--quartier=<nom>]
## Depuis le socle 1.29, chaque quartier est aussi rangé en version lointaine (quartiers/<nom>_loin.scn).
## À relancer après chaque changement d'un script « batir » : la scène enregistrée garde ce qu'il a bâti.
## Le mode d'emploi est dans docs/COMMUNE.md, « Les quartiers enregistrés ».

## Les images laissées au quartier pour finir de se bâtir (textures de bruit, maillages faits dans un fil).
const IMAGES := 4


func _init() -> void:
	await process_frame
	var id := ""
	var seul := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quartier="):
			seul = a.trim_prefix("--quartier=")
		elif not a.begins_with("--"):
			id = a
	var c := Commune.lire("res://communes/%s/commune.json" % id) if id != "" else null
	if c == null or not c.valide():
		printerr("Pas de commune « %s » valide sous res://communes/ %s" % [id, str(c.erreurs) if c else ""])
		quit(1)
		return
	var quartiers := Quartiers.de(c)
	if quartiers.is_empty():
		printerr("Le manifeste de %s ne nomme pas de quartiers (champ « quartiers »)." % id)
		quit(1)
		return
	# Le quartier part tel qu'il est bâti : Chargement ne lui donne pas ses objets lointains ici, le jeu
	# le fera en le posant.
	root.get_node("Chargement").set_meta("sans_lointain", true)
	var fautes := 0
	for nom in quartiers:
		if seul != "" and nom != seul:
			continue
		var q: Dictionary = quartiers[nom]
		var n := Node3D.new()
		n.name = nom
		root.add_child(n)
		var t0 := Time.get_ticks_msec()
		await load(q.batir).batir(n)
		for i in IMAGES:
			await process_frame
		var bati := Time.get_ticks_msec() - t0
		var e := Quartiers.enregistrer(n, q.scene)
		if e != OK:
			printerr("%s : enregistrement impossible (%s)" % [nom, error_string(e)])
			fautes += 1
		else:
			var o := FileAccess.get_file_as_bytes(q.scene).size()
			print("%s : %d nœuds bâtis en %.1f s, %s (%.1f Mo)" % [nom, n.find_children("*", "", true, false).size() + 1,
				bati / 1000.0, q.scene, o / 1048576.0])
			# Sa version lointaine (socle 1.29) : les maillages fixes fondus par matière, pour la veille des sas.
			var el := Quartiers.enregistrer_lointain(n, q.lointain)
			if el == ERR_SKIP:
				print("%s : rien à fondre pour une version lointaine" % nom)
			elif el != OK:
				printerr("%s : version lointaine impossible (%s)" % [nom, error_string(el)])
				fautes += 1
			else:
				print("%s : version lointaine %s (%.2f Mo)" % [nom, q.lointain, FileAccess.get_file_as_bytes(q.lointain).size() / 1048576.0])
		n.free()
	quit(1 if fautes > 0 else 0)
