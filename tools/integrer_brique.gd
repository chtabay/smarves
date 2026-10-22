extends SceneTree
## Fait entrer dans la bibliothèque commune une brique qu'une commune propose (docs/BIBLIOTHEQUE.md,
## « Proposer une brique ») : godot --headless --path . -s tools/integrer_brique.gd -- <commune> <brique>
##   --depuis=dossier   le dossier source de la commune (son dépôt, ou res://communes/<commune>/ par défaut)
## La brique est recopiée dans res://bibliotheque/<brique>/<version>/ (version 1, ou la suivante si la brique
## existe déjà, du même auteur), ses chemins res://communes/<commune>/bibliotheque/<brique>/ deviennent ceux
## de la bibliothèque, et le catalogue reçoit sa fiche avec le crédit de son auteur et de sa commune.
## C'est un geste de Guillaume, à la main, après avoir regardé la brique : rien ne le fait tout seul.
## Ensuite : godot --headless --path . --import, le test de la bibliothèque, et la référence recopiée dans
## le portail (STADES_DE_LA_BIBLIOTHEQUE, src/lib/communes/structures.ts dans Pyramides2) pour un stade.


func _init() -> void:
	await process_frame
	var ids := []
	var depuis := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--depuis="):
			depuis = a.trim_prefix("--depuis=")
		elif not a.begins_with("--"):
			ids.append(a)
	if ids.size() != 2:
		printerr("Usage : godot --headless --path . -s tools/integrer_brique.gd -- <commune> <brique> [--depuis=dossier]")
		quit(2)
		return
	if depuis == "":
		depuis = "res://communes/%s/" % ids[0]
	var r := integrer(ids[0], ids[1], depuis, "res://bibliotheque/", Bibliotheque.CATALOGUE)
	if r.has("erreur"):
		printerr(r.erreur)
		quit(1)
		return
	print("« %s@%d » entre dans la bibliothèque : %s" % [ids[1], r.version, r.scene])
	print("Ensuite : --import, tools/test_bibliotheque.gd, et la référence dans le portail si c'est un stade.")
	quit(0)


## Le geste lui-même, sans rien supposer du projet : la brique <brique> de la commune <commune> (dans le
## dossier source) recopiée sous <racine>/<brique>/<version>/ et inscrite au catalogue <catalogue>. Rend
## {version, scene, dossier} ou {erreur}.
static func integrer(commune: String, brique: String, source: String, racine: String, catalogue: String) -> Dictionary:
	if not source.ends_with("/"):
		source += "/"
	var dehors := ProjectSettings.globalize_path(source) if source.begins_with("res://") or source.begins_with("user://") else source
	var proposees := Bibliotheque.propositions(dehors)
	var p: Dictionary = {}
	for x in proposees:
		if x.id == brique:
			p = x
	if p.is_empty():
		return {"erreur": "la commune %s ne propose pas de brique « %s » (proposées : %s)" % [commune, brique, ", ".join(proposees.map(func(x): return x.id))]}
	if not p.erreurs.is_empty():
		return {"erreur": " ; ".join(p.erreurs)}
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalogue)) if FileAccess.file_exists(catalogue) else {"format": 1, "briques": {}}
	var existante: Dictionary = cat.briques.get(brique, {})
	if not existante.is_empty() and str(existante.get("auteur", "")) != str(p.fiche.auteur):
		return {"erreur": "« %s » existe déjà dans la bibliothèque, d'un autre auteur (%s) : la brique proposée doit prendre un autre nom" % [brique, existante.auteur]}
	if not existante.is_empty() and str(existante.get("genre", "")) != str(p.fiche.genre):
		return {"erreur": "« %s » est un %s dans la bibliothèque : une nouvelle version garde son genre" % [brique, existante.genre]}
	var version := 1
	for v in existante.get("versions", {}):
		version = maxi(version, int(v) + 1)
	if not racine.ends_with("/"):
		racine += "/"
	var dest := "%s%s/%d/" % [racine, brique, version]
	var avant := "res://communes/%s/bibliotheque/%s/" % [commune, brique]
	# Une brique se suffit : elle ne nomme rien d'autre de sa commune.
	var fautes := []
	_copier(p.dossier, ProjectSettings.globalize_path(dest), avant, dest, commune, fautes)
	if not fautes.is_empty():
		_vider(ProjectSettings.globalize_path(dest))
		return {"erreur": "la brique nomme des fichiers de sa commune hors de son dossier : %s" % ", ".join(fautes.slice(0, 5))}
	var fiche: Dictionary = p.fiche
	if existante.is_empty():
		existante = {"genre": fiche.genre, "versions": {}}
		cat.briques[brique] = existante
	for k in ["nom", "description", "auteur", "licence"]:
		if fiche.has(k):
			existante[k] = fiche[k]
	existante["commune"] = commune
	var champ := Bibliotheque.champ_fichier(str(fiche.genre))
	var entree := {champ: dest + str(fiche[champ]), "socle": Commune.SOCLE}
	if fiche.has("apercu"):
		entree.apercu = dest + str(fiche.apercu)
	existante.versions[str(version)] = entree
	FileAccess.open(catalogue, FileAccess.WRITE).store_string(JSON.stringify(cat, "\t", false) + "\n")
	Bibliotheque._catalogue = {}
	Bibliotheque._matieres = {}
	return {"version": version, "scene": entree[champ], "dossier": dest}


## Recopie le dossier (sans brique.json, .import ni .uid : le projet les refait) en remplaçant le chemin de
## la brique dans les fichiers texte ; note les chemins de la commune hors de la brique.
static func _copier(de: String, vers: String, avant: String, apres: String, commune: String, fautes: Array) -> void:
	DirAccess.make_dir_recursive_absolute(vers)
	var d := DirAccess.open(de)
	var re := RegEx.new()
	re.compile("res://communes/%s/[A-Za-z0-9_./-]*" % commune)
	for f in d.get_files():
		if f == "brique.json" or f.ends_with(".import") or f.ends_with(".uid"):
			continue
		if f.get_extension() in ["gd", "tscn", "tres", "gdshader", "json", "cfg"]:
			var t := FileAccess.get_file_as_string(de + f).replace(avant, apres)
			for m in re.search_all(t):
				fautes.append(m.get_string())
			FileAccess.open(vers + f, FileAccess.WRITE).store_string(t)
		else:
			DirAccess.copy_absolute(de + f, vers + f)
	for sous in d.get_directories():
		_copier(de + sous + "/", vers + sous + "/", avant, apres, commune, fautes)


static func _vider(dossier: String) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(dossier + f)
	for sous in d.get_directories():
		_vider(dossier + sous + "/")
		DirAccess.remove_absolute(dossier + sous)
	DirAccess.remove_absolute(dossier)
