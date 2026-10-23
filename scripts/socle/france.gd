class_name France
extends RefCounted
## Les départements de la France métropolitaine, à leur vraie place : code, nom, centre et contour,
## construits par tools/france_departements.py dans communes/france.json, avec quelques grandes
## villes pour se repérer. Au-delà de la Vienne, la carte se dézoome sur eux (CarteVienne, niveau
## « france ») : la Vienne en or, Smarves épinglée dedans, les autres en filigrane.

const CHEMIN := "res://communes/france.json"
## Le département du jeu.
const VIENNE := "86"

static var _par_code := {}
static var _liste: Array = []
static var _villes: Array = []


static func _charger() -> void:
	if not _liste.is_empty():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CHEMIN))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Référentiel des départements illisible : %s" % CHEMIN)
		return
	_liste = data.departements
	_villes = data.get("villes", [])
	for d in _liste:
		_par_code[str(d.code)] = d


## Les 96 départements, par code croissant.
static func departements() -> Array:
	_charger()
	return _liste


## Un département par son code ({} s'il n'existe pas).
static func departement(code: String) -> Dictionary:
	_charger()
	return _par_code.get(code, {})


## Les repères : [nom, longitude, latitude].
static func villes() -> Array:
	_charger()
	return _villes


## La distance à vol d'oiseau entre deux points (longitude, latitude), en kilomètres.
static func distance_km(a: Vector2, b: Vector2) -> float:
	var la := deg_to_rad(a.y)
	var lb := deg_to_rad(b.y)
	var h := pow(sin((lb - la) / 2.0), 2) + cos(la) * cos(lb) * pow(sin(deg_to_rad(b.x - a.x) / 2.0), 2)
	return 2.0 * 6371.0 * asin(sqrt(h))
