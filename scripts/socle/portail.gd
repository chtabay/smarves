class_name Portail
extends RefCounted
## Le catalogue des communes publiées sur le portail des développeurs (la page /developpeur de
## Pyramides) : ce que le jeu propose d'installer. Ici, la lecture et le tri des entrées, sans
## réseau ; le téléchargement est dans Communes. Le contrat est dans docs/COMMUNE.md, section
## « Publier sa commune ».

## Le catalogue, lisible sans compte. `--catalogue=<adresse>` le remplace (essais).
const ADRESSE := "https://pyramides2.vercel.app/api/communes"
## Le plafond d'un paquet, comme sur le portail.
const TAILLE_MAX := 32 * 1024 * 1024


static func adresse() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--catalogue="):
			return arg.trim_prefix("--catalogue=")
	return ADRESSE


## Les entrées utilisables d'un catalogue lu (texte JSON) : une commune réelle de la Vienne, un id
## valide, une adresse de paquet en https (ou locale, pour les essais), une taille sous le plafond
## et une empreinte sha256. Le reste est ignoré sans bruit : un catalogue abîmé ne doit pas
## empêcher de jouer.
static func entrees(texte: String) -> Array:
	var lu = JSON.parse_string(texte)
	if typeof(lu) != TYPE_DICTIONARY or typeof(lu.get("communes")) != TYPE_ARRAY or int(lu.get("format", 0)) != 1:
		return []
	var out := []
	for e in lu.communes:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var id := str(e.get("id", ""))
		var paquet := str(e.get("paquet", ""))
		var local := paquet.begins_with("http://127.0.0.1:") or paquet.begins_with("http://localhost:")
		if Vienne.commune(str(e.get("insee", ""))).is_empty() or not id.is_valid_identifier() or id != id.to_lower() \
				or id == "smarves" or not (paquet.begins_with("https://") or local) \
				or int(e.get("taille", 0)) <= 0 or int(e.get("taille", 0)) > TAILLE_MAX \
				or str(e.get("sha256", "")).length() != 64:
			continue
		out.append({"insee": str(e.insee), "id": id, "nom": str(e.get("nom", id)), "auteur": str(e.get("auteur", "")),
			"version": str(e.get("version", "")), "description": str(e.get("description", "")), "paquet": paquet,
			"taille": int(e.taille), "sha256": str(e.sha256).to_lower(), "publie_le": str(e.get("publie_le", ""))})
	return out


static func lire_json(chemin: String) -> Variant:
	if not FileAccess.file_exists(chemin):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(chemin))


static func ecrire(chemin: String, texte: String) -> void:
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	if f:
		f.store_string(texte)


## « 1,4 Mo », « 320 ko ».
static func taille(n: int) -> String:
	if n < 1024 * 1024:
		return "%d ko" % maxi(1, roundi(n / 1024.0))
	return ("%.1f Mo" % (n / 1048576.0)).replace(".", ",")
