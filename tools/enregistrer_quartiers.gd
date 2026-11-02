extends SceneTree
## Enregistre d'avance les quartiers d'une commune (socle 1.21, scripts/socle/quartiers.gd) : chaque quartier
## que le manifeste nomme (champ « quartiers ») est bâti par son script, puis rangé en scène .scn compressée
## là où le manifeste le dit. Le jeu lit ensuite ces scènes dans un fil au lieu de tout rebâtir.
##   godot --headless --path . -s tools/enregistrer_quartiers.gd -- <id> [--quartier=<nom>] [--sous-commune]
## --sous-commune : chaque quartier est bâti sous la scène de la commune, instanciée (sous son nœud « Quartiers »
## s'il existe), pour les quartiers qui lisent le relief par la commune (Lyon : hauteur(x, z) de lyon.gd). La
## scène se bâtit sans joueur ni veille : la commune n'est pas inscrite au registre, et une scène de ville ne
## lance sa veille que si elle l'est.
## Depuis le socle 1.29, chaque quartier est aussi rangé en version lointaine (quartiers/<nom>_loin.scn).
## À relancer après chaque changement d'un script « batir » : la scène enregistrée garde ce qu'il a bâti.
## Le mode d'emploi est dans docs/COMMUNE.md, « Les quartiers enregistrés ».

## Les images laissées au quartier pour finir de se bâtir (textures de bruit, maillages faits dans un fil).
const IMAGES := 4


func _init() -> void:
	await process_frame
	var id := ""
	var seul := ""
	var sous_commune := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quartier="):
			seul = a.trim_prefix("--quartier=")
		elif a == "--sous-commune":
			sous_commune = true
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
	var accroche: Node = root
	var commune_scene: Node
	if sous_commune:
		var ps: PackedScene = load(str(c.data.get("scene", "")))
		if ps == null:
			printerr("Pas de scène de commune à instancier (champ « scene » du manifeste)")
			quit(1)
			return
		var t0 := Time.get_ticks_msec()
		commune_scene = ps.instantiate()
		root.add_child(commune_scene)
		for i in IMAGES:
			await process_frame
		accroche = commune_scene.get_node_or_null("Quartiers")
		if accroche == null:
			accroche = commune_scene
		print("%s : la scène de la commune est bâtie en %.1f s ; les quartiers se bâtissent sous « %s »" % [id, (Time.get_ticks_msec() - t0) / 1000.0, accroche.name])
	var fautes := 0
	for nom in quartiers:
		if seul != "" and nom != seul:
			continue
		var q: Dictionary = quartiers[nom]
		var n := Node3D.new()
		n.name = nom
		accroche.add_child(n)
		var t0 := Time.get_ticks_msec()
		await load(q.batir).batir(n)
		for i in IMAGES:
			await process_frame
		var bati := Time.get_ticks_msec() - t0
		# L'échelle cumulée de la racine : celle de son parent, et rien de plus (Quartiers.enregistrer refuse
		# une racine réduite par le quartier lui-même).
		print("%s : racine à l'échelle %.4f, %.4f dans la scène" % [nom, n.scale.x, n.global_transform.basis.get_scale().x])
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
	if commune_scene != null:
		commune_scene.free()
	quit(1 if fautes > 0 else 0)
