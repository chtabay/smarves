extends SceneTree
## Captures de Casino Minuit (tools/paquet_essai/casino_minuit/, emballé ici comme dans test_ailleurs.gd) :
## godot --path . -s tools/capture_minuit.gd -- --capture=sortie.png [--table=bj-1] [--at=x,z,lacet] [--dessus]
## Sans --table, le visiteur à l'arrivée (ou à --at) ; avec, assis à cette table, son panneau ouvert.

const SOURCE := "res://tools/paquet_essai/casino_minuit/"
const TMP := "user://capture_minuit/"


func _init() -> void:
	await process_frame
	var chemin := "minuit.png"
	var table := ""
	var at := PackedFloat64Array()
	var dessus := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			chemin = a.trim_prefix("--capture=")
		elif a.begins_with("--table="):
			table = a.trim_prefix("--table=")
		elif a.begins_with("--at="):
			at = a.trim_prefix("--at=").split_floats(",")
		elif a == "--dessus":
			dessus = true
	var communes: Node = root.get_node("Communes")
	DirAccess.make_dir_recursive_absolute(TMP)
	communes.dossier_greffes = TMP
	var pck := TMP + "casino_minuit.pck"
	var pk := PCKPacker.new()
	pk.pck_start(pck)
	_emballer(pk, SOURCE, SOURCE)
	pk.flush()
	if communes.charger_pack(pck) != "casino_minuit":
		push_error("Casino Minuit ne se greffe pas : %s" % str(communes.refus))
		quit(1)
		return
	root.get_node("Game").welcomed = true
	var carte: Node = root.get_node("Carte")
	carte.duree_vol = 0.2
	carte.voler("casino_minuit")
	await create_timer(2.0, true).timeout
	var s: Node = current_scene
	var p: CharacterBody3D = s.player
	if at.size() >= 3:
		p.global_position = Vector3(at[0], 0.05, at[1])
		p.rotation.y = deg_to_rad(at[2])
	if dessus:
		root.get_node("Vue").basculer(s)
	await create_timer(1.0, true).timeout
	if table != "":
		var t: Node = s.find_child("table_" + table, true, false)
		if t == null:
			push_error("pas de table « %s »" % table)
			quit(1)
			return
		p.interact.emit(t)
		await create_timer(2.5, true).timeout
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(chemin)
	print("capture : ", chemin, "  souris : ", Input.mouse_mode)
	quit()


func _emballer(pk: PCKPacker, dossier: String, racine: String) -> void:
	var d := DirAccess.open(dossier)
	for f in d.get_files():
		if not f.ends_with(".uid"):
			pk.add_file("res://communes/casino_minuit/" + (dossier + f).trim_prefix(racine), dossier + f)
	for sous in d.get_directories():
		_emballer(pk, dossier + sous + "/", racine)
