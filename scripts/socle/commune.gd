class_name Commune
extends RefCounted
## Une commune de la Vienne, décrite par son manifeste (communes/<id>/commune.json). Le socle lit le
## manifeste, le vérifie et le traduit dans la forme que le code connaît déjà (PLACES de main.gd,
## LOCKS du casino). Le format est décrit dans docs/COMMUNE.md.

## Le format de manifeste que ce socle sait lire.
const FORMAT := 1
## La version du socle, comparée au champ « socle_min » des manifestes.
const SOCLE := "1.0"
const SMARVES := "res://communes/smarves/commune.json"
const REQUIS := ["format", "id", "nom", "carte", "scene", "lieux", "banque"]

var id := ""
var nom := ""
var chemin := ""
var data := {}
## Le pack d'une commune greffée (« » : commune du dépôt ou en dossier), et s'il est monté.
var pack := ""
var montee := true
## Ce qui ne va pas dans le manifeste ; une commune avec des erreurs n'est pas enregistrée.
var erreurs := PackedStringArray()

static var _smarves: Commune


## Smarves, lue une fois et gardée : main.gd et le casino s'en servent dès le chargement de leur script.
static func smarves() -> Commune:
	if _smarves == null:
		_smarves = lire(SMARVES)
	return _smarves


static func lire(path: String) -> Commune:
	if not FileAccess.file_exists(path):
		var c := Commune.new()
		c.chemin = path
		c.erreurs.append("manifeste introuvable : %s" % path)
		return c
	return depuis_texte(FileAccess.get_file_as_string(path), path)


## Un manifeste déjà lu (par exemple dans un pack pas encore monté). pack : le pack d'où il vient ;
## la scène n'est alors vérifiée qu'au montage (Communes.ouvrir).
static func depuis_texte(texte: String, path: String, pack_path := "") -> Commune:
	var c := Commune.new()
	c.chemin = path
	c.pack = pack_path
	c.montee = pack_path == ""
	var parsed = JSON.parse_string(texte)
	if typeof(parsed) != TYPE_DICTIONARY:
		c.erreurs.append("manifeste illisible (JSON) : %s" % path)
		return c
	c.data = parsed
	c.id = str(parsed.get("id", ""))
	c.nom = str(parsed.get("nom", ""))
	c._verifier()
	return c


func valide() -> bool:
	return erreurs.is_empty()


func scene_presente() -> bool:
	return ResourceLoader.exists(str(data.get("scene", "")))


func _verifier() -> void:
	for k in REQUIS:
		if not data.has(k):
			erreurs.append("champ manquant : %s" % k)
	if not erreurs.is_empty():
		return
	if int(data.format) > FORMAT:
		erreurs.append("format %d, ce socle lit le format %d" % [int(data.format), FORMAT])
	if str(data.get("socle_min", "1.0")).naturalnocasecmp_to(SOCLE) > 0:
		erreurs.append("demande le socle %s, celui-ci est %s" % [data.socle_min, SOCLE])
	if not id.is_valid_identifier() or id != id.to_lower():
		erreurs.append("id invalide : « %s » (minuscules, chiffres, _)" % id)
	elif not chemin.begins_with("res://communes/%s/" % id) and not chemin.begins_with("user://"):
		erreurs.append("le manifeste de « %s » doit être dans res://communes/%s/" % [id, id])
	if montee and not scene_presente():
		erreurs.append("scène introuvable : %s" % data.scene)
	var ids := {}
	for l in data.lieux:
		if typeof(l) != TYPE_DICTIONARY or not l.has("id") or not l.has("nom") or not l.has("seuil"):
			erreurs.append("lieu incomplet (id, nom, seuil) : %s" % str(l))
		elif ids.has(l.id):
			erreurs.append("lieu en double : %s" % l.id)
		else:
			ids[l.id] = true
	if typeof(data.banque) != TYPE_DICTIONARY or str(data.banque.get("preteur", "")) == "":
		erreurs.append("la banque doit nommer son prêteur (banque.preteur)")


## Les lieux, dans la forme de PLACES (main.gd) : id, name, game, seuil, host, accord.
func lieux() -> Array:
	var out := []
	for l in data.get("lieux", []):
		var p := {"id": str(l.id), "name": str(l.nom), "game": str(l.get("jeu", "")), "seuil": int(l.seuil), "host": str(l.get("hote", ""))}
		if l.has("accord"):
			p["accord"] = str(l.accord)
		out.append(p)
	return out


## Les salles fermées d'un intérieur, dans la forme de LOCKS (casino_interior.gd) : id, name, seuil, host, on.
func salles(interieur: String) -> Array:
	var out := []
	for s in data.get("salles", {}).get(interieur, []):
		var p := {"id": str(s.id), "name": str(s.nom), "seuil": int(s.seuil), "host": str(s.get("hote", ""))}
		if s.has("sur"):
			p["on"] = str(s.sur)
		out.append(p)
	return out


## Le prêteur de la commune : la clé de sa dette dans le socle (« smarves » pour M. Brunet).
func preteur() -> String:
	return str(data.banque.preteur)


func banque() -> Dictionary:
	return data.get("banque", {})


func interieur(id_interieur: String) -> String:
	return str(data.get("interieurs", {}).get(id_interieur, ""))
