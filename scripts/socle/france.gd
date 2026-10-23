class_name France
extends RefCounted
## Les départements et les régions de la France métropolitaine, à leur vraie place : code, nom, région,
## chef-lieu, centre et contour, construits par tools/france_departements.py dans communes/france.json,
## avec quelques grandes villes pour se repérer. Au-delà d'un département, la carte se dézoome sur eux
## (CarteVienne, niveau « france ») : les régions cernées, la Vienne en or, Smarves épinglée dedans,
## les autres départements en filigrane.

const CHEMIN := "res://communes/france.json"
## Le département du jeu.
const VIENNE := "86"
## Sa région, la Nouvelle-Aquitaine : le car régional en dessert les départements.
const REGION := "75"

static var _par_code := {}
static var _liste: Array = []
static var _villes: Array = []
static var _regions: Array = []


static func _charger() -> void:
	if not _liste.is_empty():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CHEMIN))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Référentiel des départements illisible : %s" % CHEMIN)
		return
	_liste = data.departements
	_villes = data.get("villes", [])
	_regions = data.get("regions", [])
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


## Les 13 régions, par code croissant : code, nom, départements, centre et contour.
static func regions() -> Array:
	_charger()
	return _regions


## Une région par son code ({} si elle n'existe pas).
static func region(code: String) -> Dictionary:
	_charger()
	for r in _regions:
		if str(r.code) == code:
			return r
	return {}


## La région d'un département (son code, « » s'il n'existe pas).
static func region_de(departement_code: String) -> String:
	return str(departement(departement_code).get("region", ""))
