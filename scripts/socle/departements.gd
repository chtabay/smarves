class_name Departements
extends RefCounted
## Les communes des départements que la carte sait montrer commune par commune : la Vienne (Vienne,
## communes/vienne.json) et les autres départements de la Nouvelle-Aquitaine, au même format dans
## communes/departements/<code>.json (tools/departement_communes.py). Un référentiel ne se lit que
## lorsqu'on en a besoin, la première fois que la carte descend dans son département. Une commune
## d'un de ces départements peut se greffer comme une commune de la Vienne (Commune.verifier, Portail).

const DOSSIER := "res://communes/departements/"

static var _lus := {}


## Le fichier d'un département, « » si le jeu ne connaît pas ses communes.
static func chemin(code: String) -> String:
	if code == France.VIENNE:
		return Vienne.CHEMIN
	var c := DOSSIER + code + ".json"
	return c if ResourceLoader.exists(c) or FileAccess.file_exists(c) else ""


## Le jeu connaît-il les communes de ce département ?
static func connu(code: String) -> bool:
	return chemin(code) != ""


## Les départements dont le jeu connaît les communes, par code croissant.
static func connus() -> Array:
	return France.departements().map(func(d): return str(d.code)).filter(connu)


## Le département d'un code INSEE : ses deux premiers caractères (« 2A », « 2B » pour la Corse).
static func de(insee: String) -> String:
	return insee.left(2)


static func _charger(code: String) -> Dictionary:
	if _lus.has(code):
		return _lus[code]
	var lu := {"liste": [], "par_insee": {}}
	if code == France.VIENNE:
		lu.liste = Vienne.communes()
	elif connu(code):
		var data = JSON.parse_string(FileAccess.get_file_as_string(chemin(code)))
		if typeof(data) == TYPE_DICTIONARY:
			lu.liste = data.communes
		else:
			push_error("Référentiel des communes illisible : %s" % chemin(code))
	for c in lu.liste:
		lu.par_insee[str(c.insee)] = c
	_lus[code] = lu
	return lu


## Les communes actuelles d'un département, par code INSEE croissant ([] s'il n'est pas connu).
static func communes(code: String) -> Array:
	return _charger(code).liste


## Une commune par son code INSEE, quel que soit son département ({} si le jeu ne la connaît pas).
static func commune(insee: String) -> Dictionary:
	if insee.length() != 5:
		return {}
	return _charger(de(insee)).par_insee.get(insee, {})


## Le centre d'une commune, en longitude et latitude.
static func centre(insee: String) -> Vector2:
	var c := commune(insee)
	return Vector2(c.centre[0], c.centre[1]) if not c.is_empty() else Vector2.ZERO
