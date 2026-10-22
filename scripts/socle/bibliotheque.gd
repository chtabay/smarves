class_name Bibliotheque
extends RefCounted
## La bibliothèque commune (socle 1.13) : des briques que le jeu embarque et que toute commune emploie par
## référence, sans les mettre dans son paquet. Une brique a un identifiant et une version (« stade-de-campagne@1 ») ;
## une version publiée ne change plus, une brique qui évolue en publie une nouvelle (« @2 ») à côté, et les
## communes restées sur l'ancienne la gardent telle quelle. Le catalogue est res://bibliotheque/bibliotheque.json ;
## chaque version vit dans res://bibliotheque/<id>/<version>/. Le mode d'emploi est dans docs/BIBLIOTHEQUE.md.
##
## Une brique de décor qui reçoit un comportement du socle (un stade qui reçoit le club et son match) suit le
## contrat d'ancres de son genre (scripts/socle/ancres.gd) : c'est ce contrat, et non l'héritage d'un script,
## qui la branche sur le socle.

const CATALOGUE := "res://bibliotheque/bibliotheque.json"
## Les genres de briques que le jeu sait employer (un genre ajouté plus tard fait monter le socle).
##   stade : un décor de stade, branché par le contrat d'ancres du stade (Ancres.STADE) ;
##   salle : un décor de salle de basket, branché par celui de la salle (Ancres.SALLE, socle 1.14) ;
##   decor : un modèle ou un ensemble à poser tel quel, sans comportement ;
##   matieres : des images de matières (marbres, bois, moquettes…) employées par leur nom (socle 1.17).
const GENRES := ["stade", "salle", "decor", "matieres"]
## Les champs d'une fiche de brique proposée (brique.json) : requis, puis facultatifs. Une brique de matières
## nomme son fichier « matieres » (un .json du dossier) à la place de « scene ».
const FICHE_REQUIS := ["genre", "nom", "auteur", "licence"]
const FICHE_FACULTATIFS := ["description", "apercu"]
## Le shader des matières : l'image posée en dalles de taille réelle, sans UV.
const SHADER_MATIERE := "res://shaders/matiere.gdshader"
## Les réglages d'une matière (matieres.json), avec leurs bornes ; « image » et « dalle » sont requis.
const REGLAGES_MATIERE := {"rugosite": [0.0, 1.0], "metal": [0.0, 1.0], "speculaire": [0.0, 1.0], "lueur": [0.0, 4.0], "contraste": [0.0, 1.0]}

static var _catalogue: Dictionary = {}


## Le catalogue entier, lu une fois.
static func catalogue() -> Dictionary:
	if _catalogue.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
		_catalogue = d if typeof(d) == TYPE_DICTIONARY else {"format": 1, "briques": {}}
	return _catalogue


## Une référence de brique a la forme « <id>@<version> » : l'id en minuscules, chiffres et tirets, la version
## un entier (« stade-de-campagne@1 »). Ne dit pas si la brique existe.
static func est_reference(ref: String) -> bool:
	var m := ref.split("@")
	if m.size() != 2 or not m[1].is_valid_int() or int(m[1]) < 1 or m[0] == "":
		return false
	for ch in m[0]:
		if not (ch in "abcdefghijklmnopqrstuvwxyz0123456789-"):
			return false
	return not m[0].begins_with("-") and not m[0].ends_with("-")


## La brique d'une référence, avec sa version : {id, version, genre, nom, description, auteur, licence, scene,
## socle}, ou {} si l'id ou la version n'existe pas.
static func brique(ref: String) -> Dictionary:
	if not est_reference(ref):
		return {}
	var id := ref.get_slice("@", 0)
	var version := ref.get_slice("@", 1)
	var b: Dictionary = catalogue().briques.get(id, {})
	var v: Dictionary = b.get("versions", {}).get(version, {})
	if v.is_empty():
		return {}
	var out := b.duplicate(true)
	out.erase("versions")
	out.merge(v, true)
	out.id = id
	out.version = int(version)
	return out


## La scène d'une brique de ce genre (« stade »), ou « » si la référence est inconnue, d'un autre genre, ou
## demande un socle plus récent que celui-ci.
static func scene(ref: String, genre: String) -> String:
	var b := brique(ref)
	if b.is_empty() or str(b.get("genre", "")) != genre:
		return ""
	if str(b.get("socle", "1.0")).naturalnocasecmp_to(Commune.SOCLE) > 0:
		return ""
	return str(b.get("scene", ""))


## Le fichier propre à une brique de ce genre : « matieres » pour les matières, « scene » pour les autres.
static func champ_fichier(genre: String) -> String:
	return "matieres" if genre == "matieres" else "scene"


# --- Les matières (socle 1.17) ------------------------------------------------------------------------

static var _matieres := {}


## Les matières d'une brique de matières, par nom : {nom: {image (chemin res://), nom, dalle, rugosite…}}, ou
## {} si la référence est inconnue, d'un autre genre ou demande un socle plus récent.
static func matieres(ref: String) -> Dictionary:
	if _matieres.has(ref):
		return _matieres[ref]
	var b := brique(ref)
	if b.is_empty() or str(b.get("genre", "")) != "matieres" or str(b.get("socle", "1.0")).naturalnocasecmp_to(Commune.SOCLE) > 0:
		return {}
	var chemin := str(b.get("matieres", ""))
	var d = JSON.parse_string(FileAccess.get_file_as_string(chemin)) if FileAccess.file_exists(chemin) else null
	var out := {}
	if typeof(d) == TYPE_DICTIONARY and typeof(d.get("matieres")) == TYPE_DICTIONARY:
		for nom in d.matieres:
			var m: Dictionary = d.matieres[nom].duplicate(true)
			m.image = chemin.get_base_dir().path_join(str(m.get("image", "")))
			out[nom] = m
	_matieres[ref] = out
	return out


## L'image d'une matière (« matieres-de-minuit@1 », « marbre_creme »), ou null.
static func texture(ref: String, nom: String) -> Texture2D:
	var m: Dictionary = matieres(ref).get(nom, {})
	return load(m.image) as Texture2D if not m.is_empty() and ResourceLoader.exists(m.image) else null


## Une matière prête à poser : un ShaderMaterial neuf (SHADER_MATIERE), avec les réglages de la brique, que
## « reglages » remplace au besoin ({"teinte": Color, "dalle": Vector2, "rugosite": 0.5, "origine": Vector2…}).
## Rend null si la référence ou le nom est inconnu.
static func matiere(ref: String, nom: String, reglages := {}) -> ShaderMaterial:
	var tex := texture(ref, nom)
	if tex == null:
		return null
	var m: Dictionary = matieres(ref)[nom]
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_MATIERE)
	mat.set_shader_parameter("motif", tex)
	mat.set_shader_parameter("dalle", Vector2(float(m.dalle[0]), float(m.dalle[1])))
	for k in REGLAGES_MATIERE:
		if m.has(k):
			mat.set_shader_parameter(k, float(m[k]))
	for k in reglages:
		mat.set_shader_parameter(k, reglages[k])
	return mat


## Les fautes d'un fichier de matières (matieres.json) dont les images sont dans « dossier ».
static func verifier_matieres(d: Variant, dossier: String) -> PackedStringArray:
	var erreurs := PackedStringArray()
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("matieres")) != TYPE_DICTIONARY or d.matieres.is_empty():
		erreurs.append("les matières : un objet JSON {\"matieres\": {nom: {image, dalle…}}}, non vide")
		return erreurs
	for nom in d.matieres:
		var m = d.matieres[nom]
		if "-" in str(nom) or not est_reference(str(nom).replace("_", "-") + "@1"):
			erreurs.append("matière « %s » : le nom s'écrit en minuscules, chiffres et soulignés" % nom)
		if typeof(m) != TYPE_DICTIONARY:
			erreurs.append("matière %s : un objet" % nom)
			continue
		var image := str(m.get("image", ""))
		if image == "" or "/" in image or ":" in image or not image.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			erreurs.append("matière %s : « image » est une image du dossier (png, jpg, webp), sans chemin" % nom)
		elif not FileAccess.file_exists(dossier.path_join(image)) and not ResourceLoader.exists(dossier.path_join(image)):
			erreurs.append("matière %s : « %s » introuvable" % [nom, image])
		var dalle = m.get("dalle")
		if typeof(dalle) != TYPE_ARRAY or dalle.size() != 2 or not dalle.all(func(x): return typeof(x) in [TYPE_INT, TYPE_FLOAT] and x > 0 and x <= 64):
			erreurs.append("matière %s : « dalle » est la taille réelle d'une dalle en mètres, [largeur, hauteur], entre 0 et 64" % nom)
		for k in m:
			if k in ["image", "dalle", "nom"]:
				continue
			if not REGLAGES_MATIERE.has(k):
				erreurs.append("matière %s : réglage inconnu « %s »" % [nom, k])
			elif not typeof(m[k]) in [TYPE_INT, TYPE_FLOAT] or m[k] < REGLAGES_MATIERE[k][0] or m[k] > REGLAGES_MATIERE[k][1]:
				erreurs.append("matière %s : « %s » entre %s et %s" % [nom, k, REGLAGES_MATIERE[k][0], REGLAGES_MATIERE[k][1]])
	return erreurs


## Les références de toutes les versions des briques d'un genre (toutes sans genre), triées.
static func references(genre := "") -> PackedStringArray:
	var out := PackedStringArray()
	var briques: Dictionary = catalogue().briques
	for id in briques:
		if genre != "" and str(briques[id].get("genre", "")) != genre:
			continue
		for v in briques[id].get("versions", {}):
			out.append("%s@%s" % [id, v])
	out.sort()
	return out


# --- Les briques proposées par les communes ---------------------------------------------------------

## Les briques qu'une commune propose à la bibliothèque : chaque dossier
## <commune>/bibliotheque/<id de la brique>/ qui tient une fiche brique.json. La proposition ne change rien
## au jeu : la commune s'en sert comme de ses propres fichiers, et la brique n'entre dans la bibliothèque que
## si Guillaume l'accepte (tools/integrer_brique.gd). Rend [{id, dossier, fiche, erreurs}], triées par id.
static func propositions(dossier_commune: String) -> Array:
	var out := []
	if not dossier_commune.ends_with("/"):
		dossier_commune += "/"
	var racine := dossier_commune + "bibliotheque/"
	var d := DirAccess.open(racine)
	if d == null:
		return out
	var ids := Array(d.get_directories())
	ids.sort()
	for id in ids:
		var dossier: String = racine + id + "/"
		if not FileAccess.file_exists(dossier + "brique.json"):
			continue
		var fiche = JSON.parse_string(FileAccess.get_file_as_string(dossier + "brique.json"))
		var p := {"id": id, "dossier": dossier, "fiche": fiche if typeof(fiche) == TYPE_DICTIONARY else {}}
		p.erreurs = verifier_fiche(fiche, id, dossier)
		out.append(p)
	return out


## Les fautes d'une fiche de brique proposée (aucune : elle peut être examinée).
static func verifier_fiche(fiche: Variant, id: String, dossier: String) -> PackedStringArray:
	var erreurs := PackedStringArray()
	if not est_reference(id + "@1"):
		erreurs.append("brique « %s » : l'id du dossier s'écrit en minuscules, chiffres et tirets" % id)
	if typeof(fiche) != TYPE_DICTIONARY:
		erreurs.append("brique %s : brique.json n'est pas un objet JSON lisible" % id)
		return erreurs
	var fichier := champ_fichier(str(fiche.get("genre", "")))
	for k in FICHE_REQUIS + [fichier]:
		if str(fiche.get(k, "")).strip_edges() == "":
			erreurs.append("brique %s : champ manquant « %s »" % [id, k])
	for k in fiche:
		if not (k in FICHE_REQUIS or k in FICHE_FACULTATIFS or k == fichier):
			erreurs.append("brique %s : champ inconnu « %s »" % [id, k])
		elif typeof(fiche[k]) != TYPE_STRING:
			erreurs.append("brique %s : « %s » est un texte" % [id, k])
	if fiche.has("genre") and not str(fiche.genre) in GENRES:
		erreurs.append("brique %s : genre inconnu « %s » (connus : %s)" % [id, str(fiche.genre), ", ".join(GENRES)])
	# La scène et l'aperçu sont des fichiers du dossier de la brique, nommés sans chemin.
	for k in ["scene", "matieres", "apercu"]:
		var f := str(fiche.get(k, ""))
		if f == "":
			continue
		if "/" in f or ":" in f:
			erreurs.append("brique %s : « %s » est un fichier du dossier de la brique, sans chemin" % [id, k])
		elif not ResourceLoader.exists(dossier + f) and not FileAccess.file_exists(dossier + f):
			erreurs.append("brique %s : « %s » introuvable dans son dossier" % [id, f])
	if str(fiche.get("scene", "")) != "" and not str(fiche.scene).ends_with(".tscn"):
		erreurs.append("brique %s : « scene » est une scène .tscn" % id)
	if fichier == "matieres" and str(fiche.get("matieres", "")) != "":
		if not str(fiche.matieres).ends_with(".json"):
			erreurs.append("brique %s : « matieres » est un fichier .json" % id)
		elif FileAccess.file_exists(dossier + str(fiche.matieres)):
			var d = JSON.parse_string(FileAccess.get_file_as_string(dossier + str(fiche.matieres)))
			for e in verifier_matieres(d, dossier):
				erreurs.append("brique %s : %s" % [id, e])
	return erreurs
