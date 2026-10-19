extends SceneTree
## Emballe une commune en paquet pour le portail des développeurs, et le fait passer par les mêmes
## refus que le jeu : godot --headless --path . -s tools/emballer_commune.gd -- <id>
##   --depuis=res://chemin/  le dossier source (par défaut res://communes/<id>/) ; un dossier hors du
##                           projet (--depuis=/chemin/vers/vegas, le dépôt d'une commune) est d'abord
##                           recopié sous res://build/sources/<id>/ et importé, sans .git, tests/ ni .md
##   --sortie=chemin.pck     où écrire le paquet (par défaut build/<id>.pck)
## Tout est rangé sous res://communes/<id>/ dans le paquet. Une ressource importée (image, son,
## modèle) part sous sa forme importée (.godot/imported/), avec son fichier .import ; l'original ne
## part pas. Le contrat est dans docs/COMMUNE.md, section « Publier sa commune ».


func _init() -> void:
	await process_frame
	var id := ""
	var depuis := ""
	var sortie := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--depuis="):
			depuis = a.trim_prefix("--depuis=")
		elif a.begins_with("--sortie="):
			sortie = a.trim_prefix("--sortie=")
		elif not a.begins_with("--"):
			id = a
	if not id.is_valid_identifier() or id != id.to_lower():
		printerr("Usage : godot --headless --path . -s tools/emballer_commune.gd -- <id> [--depuis=res://…/] [--sortie=….pck]")
		quit(2)
		return
	if depuis == "":
		depuis = "res://communes/%s/" % id
	if not depuis.ends_with("/"):
		depuis += "/"
	if not depuis.begins_with("res://"):
		depuis = _recopier(depuis, id)
		if depuis == "":
			quit(1)
			return
	if sortie == "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/"))
		sortie = ProjectSettings.globalize_path("res://build/%s.pck" % id)
	if not FileAccess.file_exists(depuis + "commune.json"):
		printerr("Pas de manifeste %scommune.json" % depuis)
		quit(1)
		return

	var fichiers := {}
	_parcourir(depuis, depuis, "res://communes/%s/" % id, fichiers)
	var pk := PCKPacker.new()
	pk.pck_start(sortie)
	for cible in fichiers:
		pk.add_file(cible, fichiers[cible])
	pk.flush()
	print("%d fichiers emballés dans %s (%s)" % [fichiers.size(), sortie, Portail.taille(FileAccess.get_file_as_bytes(sortie).size())])

	# Les refus du jeu, tels qu'un joueur les rencontrerait en l'installant.
	var communes: Node = root.get_node("Communes")
	var copie := "user://emballage/%s.pck" % id
	DirAccess.make_dir_recursive_absolute("user://emballage/")
	DirAccess.copy_absolute(sortie, copie)
	var inscrit: String = communes.charger_pack(copie)
	if inscrit == "":
		printerr("REFUSÉ par le jeu : %s" % communes.refus[-1][1])
		quit(1)
		return
	var c: Commune = communes.commune(id)
	var ok: bool = communes.ouvrir(id)
	var scene: PackedScene = load(str(c.data.scene)) if ok else null
	var n: Node = scene.instantiate() if scene else null
	if n:
		n.free()
	else:
		printerr("La scène ne se charge pas : %s" % c.data.scene)
		quit(1)
		return
	if FileAccess.get_file_as_bytes(sortie).size() > Portail.TAILLE_MAX:
		printerr("Le paquet dépasse 32 Mo : le portail le refusera.")
		quit(1)
		return
	print("Accepté par le jeu : %s (%s), version %s. À déposer sur la page développeur." % [c.nom, c.ville() + ", " + c.pays() if c.lointaine() else c.insee, c.data.get("version", "?")])
	quit(0)


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


## Recopie le dossier d'un dépôt hors du projet sous res://build/sources/<id>/ (sans ce qui ne part pas
## dans un paquet), puis fait importer ses ressources par le moteur : « » si le dossier n'existe pas.
func _recopier(dehors: String, id: String) -> String:
	if not DirAccess.dir_exists_absolute(dehors):
		printerr("Pas de dossier %s" % dehors)
		return ""
	var dedans := "res://build/sources/%s/" % id
	_vider(ProjectSettings.globalize_path(dedans))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dedans))
	_copier(dehors, ProjectSettings.globalize_path(dedans))
	var sortie := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"], sortie, true)
	if code != 0:
		printerr("L'import des ressources a échoué (%d)" % code)
		return ""
	return dedans


func _copier(de: String, vers: String) -> void:
	var d := DirAccess.open(de)
	for f in d.get_files():
		if not f.ends_with(".md"):
			DirAccess.copy_absolute(de + f, vers + f)
	for sous in d.get_directories():
		if not sous.begins_with(".") and sous != "tests":
			DirAccess.make_dir_recursive_absolute(vers + sous)
			_copier(de + sous + "/", vers + sous + "/")


func _vider(dossier: String) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(dossier + f)
	for sous in d.get_directories():
		_vider(dossier + sous + "/")
		DirAccess.remove_absolute(dossier + sous)
