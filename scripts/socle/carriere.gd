extends RefCounted
## L'onglet « Ma carrière » du carnet (demande de Guillaume du 23 octobre 2026, la refonte du carnet à la
## Football Manager) : la fortune semaine après semaine, le palmarès des clubs suivis, quelques records.
##
## La fortune nette se note à chaque ouverture du carnet, une valeur par semaine (la dernière vue), dans
## user://carriere.json. Le palmarès se lit dans Football.historique : la place finale de chaque club
## (« rangs », depuis le 24 octobre 2026), le champion, les montés et les descendus.

const FICHIER := "carriere.json"
const SEMAINE := 7 * 86400
## Les semaines gardées : un an.
const GARDEES := 52

static var dossier := "user://"
static var _lu := {}
static var _charge := false


static func _chemin() -> String:
	return dossier.path_join(FICHIER)


static func _donnees() -> Dictionary:
	if not _charge:
		_charge = true
		_lu = {}
		if dossier != "" and FileAccess.file_exists(_chemin()):
			var x = JSON.parse_string(FileAccess.get_file_as_string(_chemin()))
			if x is Dictionary:
				_lu = x
	if not _lu.has("semaines"):
		_lu["semaines"] = {}
	return _lu


## Oublie tout (les essais).
static func effacer() -> void:
	_lu = {"semaines": {}}
	_charge = true
	if dossier != "" and FileAccess.file_exists(_chemin()):
		DirAccess.remove_absolute(_chemin())


## La semaine d'un instant : le nombre de semaines depuis l'origine des temps locaux.
static func semaine_de(t: int) -> int:
	return int(floor(t / float(SEMAINE)))


## Note la fortune de la semaine de t (la dernière vue l'emporte), et sauve.
static func noter(fortune: int, t: int, sauver := true) -> void:
	var s: Dictionary = _donnees().semaines
	s[str(semaine_de(t))] = fortune
	var cles: Array = s.keys().map(func(k): return int(k))
	cles.sort()
	while cles.size() > GARDEES:
		s.erase(str(cles.pop_front()))
	if sauver and dossier != "":
		var f := FileAccess.open(_chemin(), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_lu))


## La fortune, semaine par semaine, la plus ancienne d'abord : [[semaine, fortune]].
static func courbe() -> Array:
	var s: Dictionary = _donnees().semaines
	var cles: Array = s.keys().map(func(k): return int(k))
	cles.sort()
	return cles.map(func(k): return [k, int(s[str(k)])])


## Ce que la fortune a gagné depuis la semaine d'avant celle de t (la dernière notée avant), ou null.
static func variation(fortune: int, t: int):
	var avant = null
	for x in courbe():
		if int(x[0]) < semaine_de(t):
			avant = int(x[1])
	return null if avant == null else fortune - int(avant)


## La plus haute fortune notée, ou 0.
static func record() -> int:
	var m := 0
	for x in courbe():
		m = maxi(m, int(x[1]))
	return m


## Le palmarès d'un club, la saison la plus récente d'abord : [{saison, rang (0 : inconnu), division,
## titre (« Champion », « Montée », « Descente », « » )}].
static func palmares(f: Node, club: String) -> Array:
	var out: Array = []
	for h in f.historique:
		var rangs: Dictionary = h.get("rangs", {})
		var r: Array = rangs.get(club, [])
		var titre := ""
		if str(h.get("champion", "")) == club:
			titre = "Champion"
		elif (h.get("montes", []) as Array).has(club):
			titre = "Montée"
		elif (h.get("descendus", []) as Array).has(club):
			titre = "Descente"
		if r.is_empty() and titre == "":
			continue
		out.append({"saison": int(h.saison), "rang": int(r[2]) if r.size() == 3 else 0,
			"division": f.nom_division(int(r[0]), int(r[1])) if r.size() == 3 else "", "titre": titre})
	out.reverse()
	return out
