extends RefCounted
## Les règles des paquets (docs/BIBLIOTHEQUE.md, « Les règles des paquets ») que l'emballeur applique ou
## signale (tools/emballer_commune.gd) :
##   - une texture de décor de plus de 256 px part en WebP avec perte (qualité 0,85), sauf celles que la commune
##     garde sans perte parce qu'elles sont relues au pixel (pièces d'écran, atlas de texte), nommées dans son
##     fichier emballage.json : {"sans_perte": ["ecrans/", "ui/atlas.png"]} (un dossier ou un fichier) ;
##   - une donnée de plus de 100 Ko part compressée (gzip, « .gz »), lue par Atelier.donnees ;
##   - ce qui est déjà dans le jeu (l'atelier, la bibliothèque) se référence au lieu de partir dans le paquet.
## L'emballeur convertit les textures quand il recopie la commune (--depuis) ; il ne touche jamais aux fichiers
## d'un dossier du projet, dont il signale seulement ce qui pèse. Rien de ceci ne refuse un paquet.

const REGLAGES := "emballage.json"
const COTE_MAX_SANS_PERTE := 256
const QUALITE := 0.85
const DONNEE_MAX := 100 * 1024
const IMAGES := ["png", "jpg", "jpeg", "webp", "tga", "bmp"]
const DONNEES := ["json", "txt", "csv", "tsv", "xml", "cfg"]
## Les dossiers du jeu où chercher ce qu'un paquet embarque déjà.
const DU_JEU := ["res://assets/", "res://bibliotheque/"]


## Les réglages d'emballage d'une commune (emballage.json à la racine de son dossier) : {sans_perte: […]}.
static func reglages(dossier: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(dossier + REGLAGES)) if FileAccess.file_exists(dossier + REGLAGES) else null
	var out := {"sans_perte": []}
	if typeof(d) == TYPE_DICTIONARY and typeof(d.get("sans_perte")) == TYPE_ARRAY:
		out.sans_perte = d.sans_perte.map(func(x): return str(x))
	return out


## Les fautes d'un fichier emballage.json (aucune s'il est absent).
static func verifier_reglages(dossier: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not FileAccess.file_exists(dossier + REGLAGES):
		return out
	var d = JSON.parse_string(FileAccess.get_file_as_string(dossier + REGLAGES))
	if typeof(d) != TYPE_DICTIONARY:
		out.append("%s n'est pas un objet JSON" % REGLAGES)
		return out
	for k in d:
		if k != "sans_perte":
			out.append("%s : champ inconnu « %s »" % [REGLAGES, k])
	if d.has("sans_perte") and (typeof(d.sans_perte) != TYPE_ARRAY or d.sans_perte.any(func(x): return typeof(x) != TYPE_STRING)):
		out.append("%s : « sans_perte » est une liste de chemins (« ecrans/ », « ui/atlas.png »)" % REGLAGES)
	return out


## Si l'image (relative au dossier de la commune) est gardée sans perte par les réglages.
static func sans_perte(relatif: String, r: Dictionary) -> bool:
	for p in r.sans_perte:
		if relatif == p or (p.ends_with("/") and relatif.begins_with(p)):
			return true
	return false


static func est_image(f: String) -> bool:
	return f.get_extension().to_lower() in IMAGES


## Le plus grand côté d'une image (0 si elle ne se lit pas).
static func cote(chemin: String) -> int:
	var img := Image.load_from_file(chemin)
	return maxi(img.get_width(), img.get_height()) if img else 0


## Si une image de ce côté, avec ces réglages d'import (le texte de son .import, « » s'il n'y en a pas), part
## sans perte alors que la règle la veut en WebP avec perte.
static func trop_lourde(cote_px: int, texte_import: String) -> bool:
	if cote_px <= COTE_MAX_SANS_PERTE:
		return false
	if texte_import == "":
		return true
	var cfg := ConfigFile.new()
	if cfg.parse(texte_import) != OK or str(cfg.get_value("remap", "importer", "texture")) != "texture":
		return false
	return int(cfg.get_value("params", "compress/mode", 0)) == 0


## Le texte d'un .import réglé en WebP avec perte (à partir de celui de l'auteur, ou de rien).
static func import_avec_perte(texte_import: String) -> String:
	var cfg := ConfigFile.new()
	if texte_import == "" or cfg.parse(texte_import) != OK:
		cfg = ConfigFile.new()
		cfg.set_value("remap", "importer", "texture")
		cfg.set_value("remap", "type", "CompressedTexture2D")
	cfg.set_value("params", "compress/mode", 1)
	cfg.set_value("params", "compress/lossy_quality", QUALITE)
	return cfg.encode_to_text()


## L'empreinte de chaque fichier du jeu qu'une commune pourrait embarquer (images, modèles, sons, polices) :
## {md5: chemin res://}.
static func index_du_jeu() -> Dictionary:
	var out := {}
	for d in DU_JEU:
		_indexer(d, out)
	return out


static func _indexer(dossier: String, out: Dictionary) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".import") or f.ends_with(".uid") or f.get_extension() in ["gd", "tscn", "tres", "json", "md"]:
			continue
		out[FileAccess.get_md5(dossier + f)] = dossier + f
	for s in d.get_directories():
		_indexer(dossier + s + "/", out)


## Ce qui pèse dans un dossier de commune au regard des règles, une phrase par fichier : les textures de plus
## de 256 px gardées sans perte (hors emballage.json), les données de plus de 100 Ko non compressées, et ce
## qui est déjà dans le jeu. index : celui d'index_du_jeu().
static func rapport(dossier: String, index: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	_rapport(dossier, dossier, reglages(dossier), index, out)
	return out


static func _rapport(dossier: String, racine: String, r: Dictionary, index: Dictionary, out: PackedStringArray) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	for f in d.get_files():
		var chemin := dossier + f
		var rel := chemin.trim_prefix(racine)
		if f.ends_with(".import") or f.ends_with(".uid") or f == REGLAGES:
			continue
		if est_image(f) and not sans_perte(rel, r):
			var c := cote(chemin)
			var imp := FileAccess.get_file_as_string(chemin + ".import") if FileAccess.file_exists(chemin + ".import") else ""
			if trop_lourde(c, imp):
				out.append("%s : %d px sans perte, à passer en WebP avec perte (ou à nommer dans %s s'il est relu au pixel)" % [rel, c, REGLAGES])
		if f.get_extension().to_lower() in DONNEES:
			var n := FileAccess.get_file_as_bytes(chemin).size()
			if n > DONNEE_MAX and f != "commune.json":
				out.append("%s : %s de données, à compresser (gzip, %s.gz) et à lire par Atelier.donnees" % [rel, Portail.taille(n), f])
		if not f.get_extension() in ["gd", "tscn", "tres", "json", "md", "gz"] and index.has(FileAccess.get_md5(chemin)):
			out.append("%s : déjà dans le jeu (%s), à référencer plutôt qu'à embarquer" % [rel, index[FileAccess.get_md5(chemin)]])
	for s in d.get_directories():
		if not s.begins_with("."):
			_rapport(dossier + s + "/", racine, r, index, out)
