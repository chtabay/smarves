extends RefCounted
## La sauvegarde de la partie, rangée en tiroirs (docs/COMMUNE.md) :
## - le socle (socle.save) tient ce qui vaut pour toutes les communes : la bourse, le total gagné au jeu
##   (la clé), le total misé, le pic de crédits et la dette par prêteur ;
## - chaque commune a son tiroir (communes/<id>.save) : pour Smarves, les avances de Josiane, les prêts
##   déjà accordés par M. Brunet et l'accueil du premier soir ; une commune greffée y range ce qu'elle veut.
## Les biens gardent leur propre fichier (smarves_biens.save), tenu par l'autoload Biens.
## L'ancien fichier unique (smarves.save) est lu une seule fois, réécrit en tiroirs, puis gardé à côté
## sous le nom smarves.save.ancien.

const FORMAT := 1
const SOCLE := "socle.save"
const TIROIRS := "communes/"
const ANCIEN := "smarves.save"


## Écrit le socle et tous les tiroirs sous dossier (« user:// » pour la vraie partie).
static func ecrire(game: Node, dossier := "user://") -> void:
	_ecrire_json(dossier + SOCLE, {"format": FORMAT, "bourse": game.credits, "gagne": game.won, "mise": game.staked,
		"pic": game.peak_credits, "dettes": game.debts})
	game.tiroirs[game.lender] = game.tiroir(game.lender).merged({"avances": game.advances_left,
		"prets": game.loans_taken, "accueil": game.welcomed}, true)
	DirAccess.make_dir_recursive_absolute(dossier + TIROIRS)
	for id in game.tiroirs:
		_ecrire_json(dossier + TIROIRS + id + ".save", {"format": FORMAT, "commune": id, "tiroir": game.tiroirs[id]})


## Lit la partie : les tiroirs s'ils existent, sinon l'ancien fichier, migré aussitôt. Renvoie
## « tiroirs », « migree » ou « » (aucune partie : on part du pécule). migrer : faux pour lire
## l'ancien fichier sans rien écrire (outils de test).
static func charger(game: Node, dossier := "user://", migrer := true) -> String:
	if FileAccess.file_exists(dossier + SOCLE):
		var s := _lire_json(dossier + SOCLE)
		game.credits = int(s.get("bourse", game.credits))
		game.won = int(s.get("gagne", game.won))
		game.staked = int(s.get("mise", game.staked))
		game.peak_credits = int(s.get("pic", game.peak_credits))
		var d = s.get("dettes", {})
		game.debts = {}
		if typeof(d) == TYPE_DICTIONARY:
			for k in d:
				if int(d[k]) > 0:
					game.debts[str(k)] = int(d[k])
		var dir := DirAccess.open(dossier + TIROIRS)
		if dir:
			for f in dir.get_files():
				if f.get_extension() == "save":
					var t := _lire_json(dossier + TIROIRS + f)
					if typeof(t.get("tiroir")) == TYPE_DICTIONARY:
						game.tiroirs[f.get_basename()] = t.tiroir
		var mien: Dictionary = game.tiroir(game.lender)
		game.advances_left = int(mien.get("avances", game.advances_left))
		game.loans_taken = int(mien.get("prets", game.loans_taken))
		game.welcomed = bool(mien.get("accueil", game.welcomed))
		return "tiroirs"
	if FileAccess.file_exists(dossier + ANCIEN):
		var a := _lire_json(dossier + ANCIEN)
		if a.is_empty():
			return ""
		game.credits = int(a.get("credits", game.credits))
		game.won = int(a.get("won", game.won))
		game.staked = int(a.get("staked", game.staked))
		game.advances_left = int(a.get("advances_left", game.advances_left))
		game.debts = {}
		if int(a.get("debt", 0)) > 0:
			game.debts[game.lender] = int(a.debt)
		game.loans_taken = int(a.get("loans_taken", game.loans_taken))
		game.peak_credits = int(a.get("peak", game.peak_credits))
		game.welcomed = bool(a.get("welcomed", game.welcomed))
		if not migrer:
			return "ancienne"
		ecrire(game, dossier)
		DirAccess.rename_absolute(ProjectSettings.globalize_path(dossier + ANCIEN), ProjectSettings.globalize_path(dossier + ANCIEN + ".ancien"))
		return "migree"
	return ""


## Nouvelle partie : le socle, tous les tiroirs et l'ancien fichier s'il traîne encore.
static func effacer(dossier := "user://") -> void:
	for f in [SOCLE, ANCIEN]:
		if FileAccess.file_exists(dossier + f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dossier + f))
	var dir := DirAccess.open(dossier + TIROIRS)
	if dir:
		for f in dir.get_files():
			if f.get_extension() == "save":
				DirAccess.remove_absolute(ProjectSettings.globalize_path(dossier + TIROIRS + f))


static func _ecrire_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


static func _lire_json(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}
