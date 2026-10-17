class_name Vienne
extends RefCounted
## Les communes de la Vienne, à leur vraie place : le référentiel officiel (code INSEE, nom, population,
## centre et contour), construit par tools/vienne_communes.py dans communes/vienne.json. La carte pose
## chaque commune là où elle est ; une commune n'y devient cliquable que lorsqu'elle est développée,
## c'est-à-dire inscrite au registre Communes avec ce code INSEE.

const CHEMIN := "res://communes/vienne.json"

static var _par_insee := {}
static var _liste: Array = []


static func _charger() -> void:
	if not _liste.is_empty():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CHEMIN))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Référentiel des communes illisible : %s" % CHEMIN)
		return
	_liste = data.communes
	for c in _liste:
		_par_insee[str(c.insee)] = c


## Toutes les communes actuelles du département, par code INSEE croissant.
static func communes() -> Array:
	_charger()
	return _liste


## Une commune par son code INSEE ({} si ce n'est pas une commune actuelle de la Vienne).
static func commune(insee: String) -> Dictionary:
	_charger()
	return _par_insee.get(insee, {})


## Le centre d'une commune, en longitude et latitude.
static func centre(insee: String) -> Vector2:
	var c := commune(insee)
	return Vector2(c.centre[0], c.centre[1]) if not c.is_empty() else Vector2.ZERO
