extends SceneTree
## Mesure l'arrivée à Casino Minuit depuis un paquet :
##   godot --headless --path . -s tools/mesure_minuit.gd -- --pck=/chemin/casino_minuit.pck
## Le vol part de Poitiers-Biard, comme pour le joueur, et l'écran de chargement (Chargement) écrit ses
## durées : la part du paquet lue pendant le vol, la scène, les premières images. --detail montre les images
## de plus de 150 ms sous l'écran ; --sans-vol entre sans trajet (le retour du stade). Avec --d-un-bloc, la
## scène s'ouvre sans l'écran (comme avant le socle 1.11), d'un seul bloc, pour comparer. Avec un affichage
## (sans --headless), la première image compte aussi les shaders et l'envoi des textures.

func _init() -> void:
	await process_frame
	var pck := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pck="):
			pck = a.trim_prefix("--pck=")
	var communes: Node = root.get_node("Communes")
	var chargement: Node = root.get_node("Chargement")
	DirAccess.make_dir_recursive_absolute("user://mesure/")
	communes.dossier_greffes = "user://mesure/"
	DirAccess.copy_absolute(pck, "user://mesure/casino_minuit.pck")
	if communes.charger_pack("user://mesure/casino_minuit.pck") == "":
		printerr("Paquet refusé : %s" % communes.refus[-1][1])
		quit(1)
		return
	var t0 := Time.get_ticks_msec()
	if "--d-un-bloc" in OS.get_cmdline_user_args():
		communes.ouvrir("casino_minuit")
		var n: Node = (load(str(communes.commune("casino_minuit").data.scene)) as PackedScene).instantiate()
		root.add_child(n)
		current_scene = n
		var t1 := Time.get_ticks_msec()
		await process_frame
		await process_frame
		print("d'un bloc : scène %d ms, premières images %d ms" % [t1 - t0, Time.get_ticks_msec() - t1])
		quit(0)
		return
	# Le vol, comme le joueur : l'avion vole pendant que le paquet se lit.
	var images := 0
	var pire := 0
	var avant := Time.get_ticks_msec()
	if "--sans-vol" in OS.get_cmdline_user_args():
		communes.ouvrir("casino_minuit")
		chargement.changer(str(communes.commune("casino_minuit").data.scene))
	else:
		root.get_node("Carte").voler("casino_minuit")
	var pire_vol := 0
	while not chargement.actif():
		await process_frame
		pire_vol = maxi(pire_vol, Time.get_ticks_msec() - avant)
		avant = Time.get_ticks_msec()
	print("pendant le vol, l'image la plus longue : %d ms" % pire_vol)
	avant = Time.get_ticks_msec()
	while chargement.actif():
		await process_frame
		images += 1
		pire = maxi(pire, Time.get_ticks_msec() - avant)
		if Time.get_ticks_msec() - avant > 150 and "--detail" in OS.get_cmdline_user_args():
			var sc = current_scene
			print("  image de %d ms, barre à %.2f, étape « %s »" % [Time.get_ticks_msec() - avant, chargement.progression(), sc.get("chargement_etape") if sc else ""])
		avant = Time.get_ticks_msec()
	print("arrivée en %d ms depuis le décollage (vol de %.1f s compris), %d images sous l'écran, la plus longue %d ms" % [
		Time.get_ticks_msec() - t0, root.get_node("Carte").duree_vol, images, pire])
	quit(0)
