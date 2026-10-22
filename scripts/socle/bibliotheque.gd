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
##   decor : un modèle ou un ensemble à poser tel quel, sans comportement.
const GENRES := ["stade", "decor"]
## Les champs d'une fiche de brique proposée (brique.json) : requis, puis facultatifs.
const FICHE_REQUIS := ["genre", "nom", "auteur", "licence", "scene"]
const FICHE_FACULTATIFS := ["description", "apercu"]

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
	for k in FICHE_REQUIS:
		if str(fiche.get(k, "")).strip_edges() == "":
			erreurs.append("brique %s : champ manquant « %s »" % [id, k])
	for k in fiche:
		if not (k in FICHE_REQUIS or k in FICHE_FACULTATIFS):
			erreurs.append("brique %s : champ inconnu « %s »" % [id, k])
		elif typeof(fiche[k]) != TYPE_STRING:
			erreurs.append("brique %s : « %s » est un texte" % [id, k])
	if fiche.has("genre") and not str(fiche.genre) in GENRES:
		erreurs.append("brique %s : genre inconnu « %s » (connus : %s)" % [id, str(fiche.genre), ", ".join(GENRES)])
	# La scène et l'aperçu sont des fichiers du dossier de la brique, nommés sans chemin.
	for k in ["scene", "apercu"]:
		var f := str(fiche.get(k, ""))
		if f == "":
			continue
		if "/" in f or ":" in f:
			erreurs.append("brique %s : « %s » est un fichier du dossier de la brique, sans chemin" % [id, k])
		elif not ResourceLoader.exists(dossier + f) and not FileAccess.file_exists(dossier + f):
			erreurs.append("brique %s : « %s » introuvable dans son dossier" % [id, f])
	if str(fiche.get("scene", "")) != "" and not str(fiche.scene).ends_with(".tscn"):
		erreurs.append("brique %s : « scene » est une scène .tscn" % id)
	return erreurs
