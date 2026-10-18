extends SceneTree
## Le test minimal d'une commune en paquet : le pack s'ouvre comme chez un joueur, la scène expose
## l'habitant et la caméra que le jeu attend (vue, tactile, carte), l'habitant se pose au sol et marche.
##   godot --headless --path . -s tools/test_commune.gd -- <id>   la commune de res://communes/<id>/
##   --depuis=res://chemin/   un autre dossier source (comme tools/emballer_commune.gd)
##   --pck=chemin.pck         un paquet déjà emballé (build/<id>.pck), tel quel
##   sans id                  le kit de départ lui-même (tools/kit/), rempli pour La Villedieu-du-Clain
## Le contrat est dans docs/COMMUNE.md, section « Le kit de départ ».

const TMP := "user://test_commune/"
const KIT := "res://tools/kit/"
const KIT_COMMUNE := {"id": "la_villedieu_du_clain", "nom": "La Villedieu-du-Clain", "insee": "86290"}

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var id := ""
	var depuis := ""
	var deja := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pck="):
			deja = a.trim_prefix("--pck=")
		elif a.begins_with("--depuis="):
			depuis = a.trim_prefix("--depuis=")
		elif not a.begins_with("--"):
			id = a
	DirAccess.make_dir_recursive_absolute(TMP)
	var pck := TMP + "%s.pck" % id
	if deja != "":
		DirAccess.copy_absolute(deja, pck)
	elif id == "":
		id = KIT_COMMUNE.id
		# Les champs facultatifs du manifeste : absents, des valeurs par défaut ; mal typés, un refus.
		check(Commune.verifier_facultatifs({}).is_empty(), "un manifeste sans champs facultatifs reste valide")
		check(Commune.verifier_facultatifs({"auteur": 3, "arrivee": {"nom": 1}, "population": -2, "sources": [1]}).size() == 4,
			"un champ facultatif mal typé est refusé")
		depuis = _remplir_kit()
	elif depuis == "":
		depuis = "res://communes/%s/" % id
	if deja == "":
		if not depuis.ends_with("/"):
			depuis += "/"
		if not FileAccess.file_exists(depuis + "commune.json"):
			printerr("Pas de manifeste %scommune.json" % depuis)
			quit(2)
			return
		# Le pack, rangé comme le fait tools/emballer_commune.gd.
		pck = TMP + "%s.pck" % id
		var fichiers := {}
		_parcourir(depuis, depuis, "res://communes/%s/" % id, fichiers)
		var pk := PCKPacker.new()
		pk.pck_start(pck)
		for cible in fichiers:
			pk.add_file(cible, fichiers[cible])
		pk.flush()

	var communes: Node = root.get_node("Communes")
	communes.dossier_greffes = TMP
	check(communes.charger_pack(pck) == id, "le pack de « %s » se greffe %s" % [id, str(communes.refus) if not communes.refus.is_empty() else ""])
	var c: Commune = communes.commune(id)
	if c == null:
		_fin()
		return
	check(c.valide(), "le manifeste est valide %s" % str(c.erreurs))
	print("        %s, par « %s », %d habitants, version %s" % [c.nom, c.auteur(), c.population(), c.data.get("version", "?")])
	check(communes.ouvrir(id), "le pack s'ouvre et la scène est là")
	change_scene_to_file(str(c.data.scene))
	await process_frame
	await process_frame
	var s: Node = current_scene
	check(s != null and s.scene_file_path == str(c.data.scene), "on est dans la commune (%s)" % c.nom)
	if s == null:
		_fin()
		return

	# Ce que le jeu lit dans la scène pour la vue, le tactile et la carte.
	var p = s.get("player")
	var cam = s.get("camera")
	check(p is CharacterBody3D and "follow_camera" in p, "la scène expose « player », un habitant fp_player.gd")
	check(cam is Camera3D and cam.has_method("use_notches") and cam.has_signal("au_dela"), "la scène expose « camera », une caméra orbit_camera.gd")
	if not (p is CharacterBody3D):
		_fin()
		return

	# L'habitant se pose au sol, sans passer au travers.
	var y0: float = p.global_position.y
	await create_timer(1.5, true).timeout
	check(p.is_on_floor() and p.global_position.y > y0 - 3.0, "l'habitant est posé au sol (y %.2f)" % p.global_position.y)

	# Il marche : au moins une des quatre directions est libre.
	var loin := 0.0
	for d in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var depart: Vector3 = p.global_position
		p.auto_move = d
		await create_timer(1.5, true).timeout
		p.auto_move = Vector3.ZERO
		loin = maxf(loin, Vector2(p.global_position.x - depart.x, p.global_position.z - depart.z).length())
		if loin > 1.0:
			break
	check(loin > 1.0, "l'habitant marche (%.1f unités)" % loin)
	check(p.is_on_floor(), "et reste au sol")
	_fin()


func _fin() -> void:
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


## Le kit de départ rempli pour une commune, comme le portail le donne.
func _remplir_kit() -> String:
	var dossier := TMP + "kit/"
	DirAccess.make_dir_recursive_absolute(dossier)
	for f in ["commune.json", "commune.tscn", "commune.gd"]:
		var t := FileAccess.get_file_as_string(KIT + f)
		for k in KIT_COMMUNE:
			t = t.replace("__%s__" % k.to_upper(), KIT_COMMUNE[k])
		var out := FileAccess.open(dossier + f, FileAccess.WRITE)
		out.store_string(t)
		out.close()
	return dossier


func _parcourir(dossier: String, racine: String, cible: String, out: Dictionary) -> void:
	var d := DirAccess.open(dossier)
	for f in d.get_files():
		var chemin := dossier + f
		var dans_le_paquet := cible + chemin.trim_prefix(racine)
		if f.ends_with(".import"):
			out[dans_le_paquet] = chemin
			var cfg := ConfigFile.new()
			if cfg.load(chemin) == OK and cfg.has_section("remap"):
				for k in cfg.get_section_keys("remap"):
					var importe := str(cfg.get_value("remap", k))
					if k.begins_with("path") and FileAccess.file_exists(importe):
						out[importe] = importe
		elif not FileAccess.file_exists(chemin + ".import"):
			out[dans_le_paquet] = chemin
	for sub in d.get_directories():
		_parcourir(dossier + sub + "/", racine, cible, out)
