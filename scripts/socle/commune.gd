class_name Commune
extends RefCounted
## Une commune de la Vienne, décrite par son manifeste (communes/<id>/commune.json). Le socle lit le
## manifeste, le vérifie et le traduit dans la forme que le code connaît déjà (PLACES de main.gd,
## LOCKS du casino). Le format est décrit dans docs/COMMUNE.md. Depuis le socle 1.5, une destination
## lointaine (champ « ailleurs », hors de la Vienne, sans code INSEE) se rejoint en avion.

## Le format de manifeste que ce socle sait lire.
const FORMAT := 1
## La version du socle, comparée au champ « socle_min » des manifestes. La monter ici, c'est aussi monter
## SOCLE dans le portail (Pyramides2, src/lib/communes/paquet.ts) et y recopier les règles nouvelles du
## manifeste (structures.ts) : sinon le portail refuse les paquets qui demandent ce socle.
const SOCLE := "1.18"
## Les compteurs du carnet (champ « carnet ») : leurs genres et leurs bornes.
const CARNET_GENRES := ["nombre", "credits", "texte", "case"]
const CARNET_COMPTEURS_MAX := 24
const CARNET_LIBELLE_MAX := 60
const CARNET_TEXTE_MAX := 80
const SMARVES := "res://communes/smarves/commune.json"
const REQUIS := ["format", "id", "nom", "insee", "scene", "lieux", "banque"]
## Socle 1.5 : les champs d'une destination lointaine (« ailleurs »), avec leur type ; « ville » est requise.
const AILLEURS_CHAMPS := {"ville": TYPE_STRING, "pays": TYPE_STRING, "vol": TYPE_STRING, "aeroport": TYPE_STRING}

var id := ""
var nom := ""
## Le code INSEE : la commune est posée sur la carte à sa vraie place (Vienne, communes/vienne.json).
var insee := ""
var chemin := ""
var data := {}
## Le pack d'une commune greffée (« » : commune du dépôt ou en dossier), et s'il est monté.
var pack := ""
var montee := true
## La date et la taille du pack quand on l'a lu : s'il change ensuite sur le disque, on le relit.
var signature := ""
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
	c.insee = str(parsed.get("insee", ""))
	c._verifier()
	return c


func valide() -> bool:
	return erreurs.is_empty()


func scene_presente() -> bool:
	return ResourceLoader.exists(str(data.get("scene", "")))


## Une destination lointaine (socle 1.5) : hors de la Vienne, rejointe en avion depuis Poitiers-Biard.
func lointaine() -> bool:
	return data.has("ailleurs")


## La ville d'une destination lointaine (« Las Vegas »), « » pour une commune de la Vienne.
func ville() -> String:
	return str(data.get("ailleurs", {}).get("ville", "")) if lointaine() else ""


## Le pays d'une destination lointaine (« États-Unis »), « » s'il n'est pas dit.
func pays() -> String:
	return str(data.get("ailleurs", {}).get("pays", "")) if lointaine() else ""


## L'aéroport d'arrivée (« McCarran »), la ville à défaut.
func aeroport() -> String:
	var a := str(data.get("ailleurs", {}).get("aeroport", "")) if lointaine() else ""
	return a if a != "" else ville()


## Le vol tel qu'il s'affiche au départ (« MN 1203 · via Paris-Charles-de-Gaulle »), « » s'il n'est pas dit.
func vol() -> String:
	return str(data.get("ailleurs", {}).get("vol", "")) if lointaine() else ""


func _verifier() -> void:
	for k in REQUIS:
		if k == "insee" and data.has("ailleurs"):
			continue
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
	if data.has("ailleurs"):
		erreurs.append_array(verifier_ailleurs(data))
	elif Vienne.commune(insee).is_empty():
		erreurs.append("code INSEE inconnu dans la Vienne : « %s »" % insee)
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
	erreurs.append_array(Structures.verifier(data.get("structures")))
	erreurs.append_array(load("res://scripts/socle/notaire.gd").verifier(data.get("notaire")))
	erreurs.append_array(verifier_facultatifs(data))


## Le champ « ailleurs » (socle 1.5) : une destination hors de la Vienne, sans code INSEE, rejointe en
## avion. Les phrases sont celles du rapport du portail.
static func verifier_ailleurs(m: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var a = m.get("ailleurs")
	if typeof(a) != TYPE_DICTIONARY:
		out.append("ailleurs doit être un objet (ville, pays, vol, aeroport)")
		return out
	if str(m.get("insee", "")) != "":
		out.append("une destination lointaine (ailleurs) n'a pas de code INSEE")
	if str(m.get("socle_min", "1.0")).naturalnocasecmp_to("1.5") < 0:
		out.append("une destination lointaine (ailleurs) demande le socle 1.5 (socle_min)")
	if typeof(a.get("ville")) != TYPE_STRING or str(a.get("ville", "")).strip_edges() == "":
		out.append("ailleurs.ville : il faut nommer la ville")
	for k in a:
		if not AILLEURS_CHAMPS.has(k):
			out.append("ailleurs : champ inconnu « %s »" % k)
		elif typeof(a[k]) != AILLEURS_CHAMPS[k]:
			out.append("ailleurs.%s doit être un texte" % k)
	return out


## Les champs facultatifs de présentation (auteur, arrivée, population, licence, sources) : absents,
## ils prennent leur valeur par défaut ; présents, ils doivent avoir le bon type. Le portail des
## développeurs fait la même vérification (src/lib/communes/paquet.ts dans Pyramides2).
static func verifier_facultatifs(m: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in ["auteur", "licence"]:
		if m.has(k) and typeof(m[k]) != TYPE_STRING:
			out.append("%s doit être un texte" % k)
	if m.has("arrivee"):
		var a = m.arrivee
		if typeof(a) != TYPE_DICTIONARY:
			out.append("arrivee doit être un objet (lot, nom, par)")
		else:
			for k in ["lot", "nom"]:
				if a.has(k) and typeof(a[k]) != TYPE_STRING:
					out.append("arrivee.%s doit être un texte" % k)
			if a.has("par") and typeof(a.par) != TYPE_ARRAY:
				out.append("arrivee.par doit être une liste de communes")
	if m.has("population"):
		var n = m.population
		if (typeof(n) != TYPE_INT and typeof(n) != TYPE_FLOAT) or float(n) < 0 or float(n) != floorf(float(n)):
			out.append("population doit être un nombre entier positif")
	if m.has("sources"):
		var s = m.sources
		var ok := typeof(s) == TYPE_STRING
		if typeof(s) == TYPE_ARRAY:
			ok = true
			for x in s:
				ok = ok and typeof(x) == TYPE_STRING
		if not ok:
			out.append("sources doit être un texte ou une liste de textes")
	out.append_array(verifier_carnet(m.get("carnet")))
	return out


## Le champ « carnet » : les compteurs que la commune tient au carnet du joueur (docs/COMMUNE.md, « Le carnet
## du joueur »). Les phrases d'erreur sont reprises telles quelles par le portail des développeurs.
static func verifier_carnet(carnet) -> PackedStringArray:
	var out := PackedStringArray()
	if carnet == null:
		return out
	if typeof(carnet) != TYPE_ARRAY:
		out.append("carnet doit être une liste de compteurs")
		return out
	if carnet.size() > CARNET_COMPTEURS_MAX:
		out.append("carnet : %d compteurs au plus" % CARNET_COMPTEURS_MAX)
	var vus := {}
	for d in carnet:
		if typeof(d) != TYPE_DICTIONARY or not d.has("id") or not d.has("libelle") or not d.has("genre"):
			out.append("carnet : compteur incomplet (id, libelle, genre) : %s" % str(d))
			continue
		var id := str(d.id)
		if typeof(d.id) != TYPE_STRING or not id.is_valid_identifier() or id != id.to_lower():
			out.append("carnet : id invalide : « %s » (minuscules, chiffres, _)" % id)
		elif vus.has(id):
			out.append("carnet : compteur en double : %s" % id)
		vus[id] = true
		if not CARNET_GENRES.has(str(d.genre)):
			out.append("carnet : genre inconnu pour %s : « %s » (nombre, credits, texte, case)" % [id, str(d.genre)])
		if typeof(d.libelle) != TYPE_STRING or str(d.libelle).length() > CARNET_LIBELLE_MAX:
			out.append("carnet : libelle de %s trop long (%d caractères au plus)" % [id, CARNET_LIBELLE_MAX])
		if d.has("rubrique") and typeof(d.rubrique) != TYPE_STRING:
			out.append("carnet : rubrique de %s doit être un texte" % id)
	return out


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


## Où la poser sur la carte : le centre de la commune réelle (longitude, latitude).
func centre() -> Vector2:
	return Vienne.centre(insee)


## Les structures que la commune déclare (gare, arrêt de car, terrain…), vide si elle n'en a pas.
## Le comportement est au socle (Structures) et au registre (autoload Registre).
func structures() -> Array:
	return data.get("structures", [])


## Qui a fait la commune, pour sa fiche sur la carte (« » si le manifeste ne le dit pas).
func auteur() -> String:
	return str(data.get("auteur", ""))


## Le nom du lieu où l'on débarque (« La place de la Mairie »), ou « » s'il n'est pas donné.
func arrivee_nom() -> String:
	var a = data.get("arrivee", {})
	return str(a.get("nom", "")) if typeof(a) == TYPE_DICTIONARY else ""


## La population : celle du manifeste si elle est donnée (plus que zéro), sinon celle du référentiel
## de la Vienne (communes/vienne.json).
func population() -> int:
	var n := int(data.get("population", 0))
	return n if n > 0 or lointaine() else int(Vienne.commune(insee).get("population", 0))


## La licence du plan et des photos, et leurs sources (une liste, vide si rien n'est dit).
func licence() -> String:
	return str(data.get("licence", ""))


func sources() -> PackedStringArray:
	var s = data.get("sources", [])
	if typeof(s) == TYPE_STRING:
		return PackedStringArray([s]) if s != "" else PackedStringArray()
	return PackedStringArray(s)


func banque() -> Dictionary:
	return data.get("banque", {})


func interieur(id_interieur: String) -> String:
	return str(data.get("interieurs", {}).get(id_interieur, ""))
