extends SceneTree
## Emballe une commune en paquet pour le portail des développeurs, et le fait passer par les mêmes
## refus que le jeu : godot --headless --path . -s tools/emballer_commune.gd -- <id>
##   --depuis=res://chemin/  le dossier source (par défaut res://communes/<id>/) ; un autre dossier, dans
##                           le projet ou hors de lui (--depuis=/chemin/vers/vegas, le dépôt d'une
##                           commune), est d'abord recopié sous res://communes/<id>/, là où le jeu le
##                           chargera, et importé là (sans .git, tests/ ni .md), puis retiré après
##                           l'emballage : un modèle importé nomme ses textures par leur chemin, qui doit
##                           être celui du paquet
##   --sortie=chemin.pck     où écrire le paquet (par défaut build/<id>.pck)
## Tout est rangé sous res://communes/<id>/ dans le paquet. Une ressource importée (image, son,
## modèle) part sous sa forme importée (.godot/imported/), avec son fichier .import ; l'original ne
## part pas. Le contrat est dans docs/COMMUNE.md, section « Publier sa commune ».
## Les règles des paquets (tools/regles_paquet.gd) : à la recopie, une texture de plus de 256 px sans perte
## passe en WebP avec perte (sauf celles qu'emballage.json garde sans perte) ; ce qui pèse encore (textures,
## données non compressées, fichiers déjà dans le jeu) est dit à la fin, sans refuser le paquet.

const REGLES := preload("res://tools/regles_paquet.gd")


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
	var cible_id := "res://communes/%s/" % id
	var recopie := depuis != cible_id
	if recopie:
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
	_a_alleger = REGLES.rapport(depuis, REGLES.index_du_jeu())
	# Les briques proposées à la bibliothèque (dossier bibliotheque/<brique>/ et sa fiche brique.json) : une
	# fiche fautive arrête l'emballage, pour que la proposition arrive lisible au portail.
	var fautes := _propositions(depuis)
	fautes.append_array(REGLES.verifier_reglages(depuis))
	if not fautes.is_empty():
		if recopie:
			_retirer(id)
		printerr("Paquet refusé : %s" % " ; ".join(fautes))
		quit(1)
		return
	var pk := PCKPacker.new()
	pk.pck_start(sortie)
	for cible in fichiers:
		pk.add_file(cible, fichiers[cible])
	pk.flush()
	# Aucune ressource importée ne doit nommer un chemin hors du paquet : le jeu ne le trouverait pas.
	var hors := _chemins_hors(fichiers, id)
	if recopie:
		_retirer(id)
	if not hors.is_empty():
		printerr("Des ressources du paquet nomment des fichiers hors de res://communes/%s/ : %s" % [id, ", ".join(hors.slice(0, 5))])
		quit(1)
		return
	print("%d fichiers emballés dans %s (%s)" % [fichiers.size(), sortie, Portail.taille(FileAccess.get_file_as_bytes(sortie).size())])
	if _converties > 0:
		print("Règles des paquets : %d texture(s) passée(s) en WebP avec perte." % _converties)
	for l in _a_alleger:
		print("À alléger : %s" % l)

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
	if scene == null:
		printerr("La scène ne se charge pas : %s" % c.data.scene)
		quit(1)
		return
	# Le budget par lieu (Budget) : chaque scène du manifeste est bâtie, mesurée, et ce qui dépasse est dit ;
	# la mesure part dans le paquet (budget.json), que le portail lit.
	var budget := {"socle": Commune.SOCLE, "seuils": Budget.SEUILS, "lieux": {}}
	for chemin in _scenes_du_manifeste(c.data):
		var ps: PackedScene = load(chemin)
		var n: Node = ps.instantiate() if ps else null
		if n == null:
			printerr("La scène ne se charge pas : %s" % chemin)
			quit(1)
			return
		root.add_child(n)
		for i in 4:
			await process_frame
		var m := Budget.mesurer(n)
		var dep := Budget.depassements(m)
		budget.lieux[chemin] = {"mesure": m, "a_alleger": Array(dep)}
		print("Budget de %s : %s%s" % [chemin.trim_prefix("res://communes/%s/" % id), Budget.resume(m), "" if dep.is_empty() else "\n   À alléger : " + " ; ".join(dep)])
		root.remove_child(n)
		n.free()
	var fichier_budget := ProjectSettings.globalize_path("user://emballage/budget.json")
	var fb := FileAccess.open(fichier_budget, FileAccess.WRITE)
	fb.store_string(JSON.stringify(budget, "  "))
	fb.close()
	fichiers["res://communes/%s/budget.json" % id] = fichier_budget
	pk = PCKPacker.new()
	pk.pck_start(sortie)
	for cible in fichiers:
		pk.add_file(cible, fichiers[cible])
	pk.flush()
	if FileAccess.get_file_as_bytes(sortie).size() > Portail.TAILLE_MAX:
		printerr("Le paquet dépasse 32 Mo : le portail le refusera.")
		quit(1)
		return
	print("Accepté par le jeu : %s (%s), version %s. À déposer sur la page développeur." % [c.nom, c.ville() + ", " + c.pays() if c.lointaine() else c.insee, c.data.get("version", "?")])
	quit(0)


## Les scènes qu'un paquet ouvre : la sienne et celles de ses structures (scene, habillage, modele).
func _scenes_du_manifeste(data: Dictionary) -> Array:
	var out := [str(data.scene)]
	for s in data.get("structures", []):
		for champ in ["scene", "habillage", "modele"]:
			var v := str(s.get(champ, ""))
			if v.begins_with("res://") and not v in out:
				out.append(v)
	return out


func _parcourir(dossier: String, racine: String, cible: String, out: Dictionary) -> void:
	var d := DirAccess.open(dossier)
	for f in d.get_files():
		if f == TEMOIN or f == REGLES.REGLAGES:
			continue
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


const TEMOIN := ".emballage"
## Les textures converties à la recopie, et ce qui pèse encore (REGLES.rapport).
var _converties := 0
var _a_alleger := PackedStringArray()


## Dit les briques que la commune propose à la bibliothèque, et rend leurs fautes : la fiche, et pour un
## stade ou une salle le contrat d'ancres (docs/BIBLIOTHEQUE.md, « Proposer une brique »).
func _propositions(dossier: String) -> PackedStringArray:
	var fautes := PackedStringArray()
	for p in Bibliotheque.propositions(dossier):
		fautes.append_array(p.erreurs)
		if p.erreurs.is_empty() and Ancres.CONTRATS.has(p.fiche.genre):
			var n: Node3D = (load(p.dossier + str(p.fiche.scene)) as PackedScene).instantiate()
			root.add_child(n)
			for f in Ancres.verifier_genre(n, p.fiche.genre):
				fautes.append("brique %s : %s" % [p.id, f])
			n.free()
		if p.erreurs.is_empty():
			print("Proposée à la bibliothèque : %s (%s, %s), examinée à la main après le dépôt." % [p.id, p.fiche.genre, p.fiche.nom])
	return fautes


## Recopie le dossier source sous res://communes/<id>/ (sans ce qui ne part pas dans un paquet), puis
## fait importer ses ressources par le moteur : « » si le dossier n'existe pas, ou si une commune du
## projet occupe déjà ce chemin.
func _recopier(source: String, id: String) -> String:
	var dehors := ProjectSettings.globalize_path(source) if source.begins_with("res://") else source
	if not dehors.ends_with("/"):
		dehors += "/"
	if not DirAccess.dir_exists_absolute(dehors):
		printerr("Pas de dossier %s" % dehors)
		return ""
	var dedans := "res://communes/%s/" % id
	var dossier := ProjectSettings.globalize_path(dedans)
	if DirAccess.dir_exists_absolute(dossier) and not FileAccess.file_exists(dossier + TEMOIN):
		printerr("%s existe déjà dans le projet : emballez-le sans --depuis" % dedans)
		return ""
	_vider(dossier)
	DirAccess.make_dir_recursive_absolute(dossier)
	FileAccess.open(dossier + TEMOIN, FileAccess.WRITE).store_string("recopie de %s par tools/emballer_commune.gd\n" % source)
	_copier(dehors, dossier, dehors, REGLES.reglages(dehors))
	var sortie := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"], sortie, true)
	if code != 0:
		printerr("L'import des ressources a échoué (%d)" % code)
		return ""
	return dedans


## La recopie d'un dossier ; une texture de plus de 256 px sans perte y passe en WebP avec perte (réglée par son
## .import, que l'import suit), sauf si les réglages r de la commune la gardent sans perte.
func _copier(de: String, vers: String, racine: String, r: Dictionary) -> void:
	var d := DirAccess.open(de)
	for f in d.get_files():
		if f.ends_with(".md") or f.ends_with(".uid"):
			continue
		if f.ends_with(".import"):
			# les réglages d'import suivent, pas l'identifiant : la copie reçoit le sien
			var t := FileAccess.get_file_as_string(de + f)
			var lignes := Array(t.split("\n")).filter(func(l): return not l.begins_with("uid=") and not l.begins_with("source_file=") and not l.begins_with("dest_files=") and not l.begins_with("path"))
			t = "\n".join(lignes)
			var image := f.trim_suffix(".import")
			if _a_convertir(de + image, (de + image).trim_prefix(racine), t, r):
				t = REGLES.import_avec_perte(t)
			FileAccess.open(vers + f, FileAccess.WRITE).store_string(t)
		else:
			DirAccess.copy_absolute(de + f, vers + f)
			if not FileAccess.file_exists(de + f + ".import") and _a_convertir(de + f, (de + f).trim_prefix(racine), "", r):
				FileAccess.open(vers + f + ".import", FileAccess.WRITE).store_string(REGLES.import_avec_perte(""))
	for sous in d.get_directories():
		if not sous.begins_with(".") and sous != "tests":
			DirAccess.make_dir_recursive_absolute(vers + sous)
			_copier(de + sous + "/", vers + sous + "/", racine, r)


func _a_convertir(image: String, relatif: String, texte_import: String, r: Dictionary) -> bool:
	if not REGLES.est_image(image) or REGLES.sans_perte(relatif, r) or not REGLES.trop_lourde(REGLES.cote(image), texte_import):
		return false
	_converties += 1
	return true


func _vider(dossier: String) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		DirAccess.remove_absolute(dossier + f)
	for sous in d.get_directories():
		_vider(dossier + sous + "/")
		DirAccess.remove_absolute(dossier + sous)


## La recopie retirée du projet, et ce que son import a laissé.
func _retirer(id: String) -> void:
	var dossier := ProjectSettings.globalize_path("res://communes/%s/" % id)
	if FileAccess.file_exists(dossier + TEMOIN):
		_vider(dossier)
		DirAccess.remove_absolute(dossier)


## Les chemins res:// hors du paquet que nomment ses ressources importées (un modèle et ses textures).
func _chemins_hors(fichiers: Dictionary, id: String) -> Array:
	var hors := {}
	var re := RegEx.new()
	re.compile("res://[A-Za-z0-9_./-]+")
	var bon := "res://communes/%s/" % id
	for cible in fichiers:
		if not str(cible).begins_with("res://.godot/imported/"):
			continue
		var b := FileAccess.get_file_as_bytes(fichiers[cible])
		for m in re.search_all(b.get_string_from_ascii()):
			var c := m.get_string()
			if not c.begins_with(bon) and not c.begins_with("res://.godot/"):
				hors[c] = true
	return hors.keys()
