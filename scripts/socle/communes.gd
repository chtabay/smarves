extends Node
## Le registre des communes (autoload « Communes »). Smarves y est inscrite au démarrage depuis son
## manifeste ; les communes greffées arrivent de user://communes/, en pack (<id>.pck) ou en dossier
## (<id>/commune.json), et s'inscrivent de la même façon. Un pack n'est pas monté au lancement : son
## manifeste est lu dans le pack, et le pack n'est monté qu'au moment où l'on entre dans la commune
## (ouvrir), pour ne pas alourdir le démarrage, sur le web surtout. Rien ne s'affiche : la carte de la
## Vienne viendra lire ce registre. La notice est dans docs/COMMUNE.md.

## Une commune vient d'être inscrite (Smarves au démarrage, puis chaque greffe).
signal inscrite(id: String)

const GREFFES := "user://communes/"

## La commune d'origine du joueur : son banquier est le prêteur par défaut.
const ORIGINE := "smarves"

## id -> Commune, dans l'ordre d'inscription (voir ordre).
var communes := {}
var ordre: Array[String] = []
## Les greffes refusées au dernier chargement, avec la raison : [chemin, raison].
var refus: Array = []


func _ready() -> void:
	inscrire(Commune.smarves())
	# Les captures et les tests partent du jeu seul, sans les mods du joueur.
	if not "--capture" in " ".join(OS.get_cmdline_user_args()) and get_tree().get_script() == null:
		charger_greffes()


func commune(id: String) -> Commune:
	return communes.get(id)


func origine() -> Commune:
	return communes.get(ORIGINE)


## Inscrit une commune lue et vérifiée. Refuse un manifeste en erreur ou un id déjà pris.
func inscrire(c: Commune) -> bool:
	if c == null or not c.valide():
		_refuser(c.chemin if c else "?", "; ".join(c.erreurs) if c else "commune vide")
		return false
	if communes.has(c.id):
		_refuser(c.chemin, "la commune « %s » est déjà inscrite" % c.id)
		return false
	communes[c.id] = c
	ordre.append(c.id)
	inscrite.emit(c.id)
	return true


## Toutes les greffes déposées par le joueur : user://communes/<id>.pck et user://communes/<id>/.
func charger_greffes(dossier := GREFFES) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	for f in d.get_files():
		if f.get_extension() == "pck":
			charger_pack(dossier.path_join(f))
	for sub in d.get_directories():
		if FileAccess.file_exists(dossier.path_join(sub).path_join("commune.json")):
			charger_dossier(dossier.path_join(sub))


## Une commune en pack, inscrite sans être montée. Le nom du fichier donne l'id ; le pack n'écrit que
## sous res://communes/<id>/ (plus ce qu'un export ajoute dans .godot/), ne contient pas de code natif
## (GDExtension, qui ne passerait pas sur le web), et ne remplacera jamais un fichier du jeu.
func charger_pack(path: String) -> String:
	var id := path.get_file().get_basename()
	if communes.has(id):
		_refuser(path, "la commune « %s » est déjà inscrite" % id)
		return ""
	var rep = repertoire_pack(path)
	if rep == null:
		_refuser(path, "pack illisible ou chiffré")
		return ""
	var manifeste := "communes/%s/commune.json" % id
	var texte := ""
	for e in rep:
		if _natif(e[0]):
			_refuser(path, "le pack contient du code natif : %s" % e[0])
			return ""
		if not _permis(e[0], id):
			_refuser(path, "le pack écrit hors de res://communes/%s/ : %s" % [id, e[0]])
			return ""
		if e[0] == manifeste:
			texte = _extraire(path, e)
	if texte == "":
		_refuser(path, "le pack n'a pas de manifeste res://%s" % manifeste)
		return ""
	var c := Commune.depuis_texte(texte, "res://" + manifeste, path)
	if c.valide() and c.id != id:
		c.erreurs.append("le pack s'appelle « %s » mais son manifeste dit « %s »" % [id, c.id])
	return id if inscrire(c) else ""


## Prépare une commune pour y entrer : monte son pack s'il ne l'est pas encore et vérifie sa scène.
## À appeler depuis la carte, juste avant de changer de scène.
func ouvrir(id: String) -> bool:
	var c: Commune = communes.get(id)
	if c == null:
		return false
	if not c.montee:
		if not ProjectSettings.load_resource_pack(c.pack, false):
			_refuser(c.pack, "Godot n'a pas pu monter le pack")
			return false
		c.montee = true
	if not c.scene_presente():
		_refuser(c.chemin, "scène introuvable : %s" % c.data.scene)
		return false
	return true


## Une commune en dossier (données et scènes sous user://communes/<id>/), sans pack.
func charger_dossier(path: String) -> String:
	var c := Commune.lire(path.path_join("commune.json"))
	var id := path.trim_suffix("/").get_file()
	if c.valide() and c.id != id:
		c.erreurs.append("le dossier s'appelle « %s » mais son manifeste dit « %s »" % [id, c.id])
	return c.id if inscrire(c) else ""


## Le code natif (GDExtension, bibliothèques) ne se charge pas dans un navigateur : refusé partout.
func _natif(f: String) -> bool:
	return f.get_extension().to_lower() in ["gdextension", "so", "dll", "dylib", "wasm", "framework"]


func _permis(f: String, id: String) -> bool:
	f = f.trim_prefix("res://")
	if f.begins_with("communes/%s/" % id):
		return true
	# Ce qu'un export ajoute de lui-même ; load_resource_pack(…, false) ne laisse rien remplacer.
	return f.begins_with(".godot/imported/") or f.begins_with(".godot/exported/") or f in [".godot/uid_cache.bin", ".godot/global_script_class_cache.cfg", "project.binary"]


func _refuser(path: String, raison: String) -> void:
	refus.append([path, raison])
	push_warning("Commune refusée (%s) : %s" % [path, raison])


## La liste des fichiers d'un pack .pck (formats 2 à 4 de Godot 4), ou null s'il est illisible.
static func lister_pack(path: String) -> Variant:
	var rep = repertoire_pack(path)
	if rep == null:
		return null
	var out := PackedStringArray()
	for e in rep:
		out.append(e[0])
	return out


## Le répertoire d'un pack : [chemin, début, taille] par fichier, ou null s'il est illisible ou si son
## répertoire est chiffré : on n'inscrit pas un pack dont on ne voit pas le contenu.
static func repertoire_pack(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() < 4 or f.get_32() != 0x43504447:  # « GDPC »
		return null
	var version := f.get_32()
	if version < 2 or version > 4:
		return null
	f.get_32()
	f.get_32()
	f.get_32()
	var flags := f.get_32()
	if flags & 1:  # répertoire chiffré
		return null
	# Les débuts de fichiers sont relatifs à file_base quand le drapeau 2 est levé (packs récents).
	var file_base := f.get_64()
	var base := file_base if flags & 2 else 0
	if version >= 3:  # le répertoire est à la fin, son adresse suit
		f.seek(f.get_64())
	else:
		for i in 16:
			f.get_32()
	var n := f.get_32()
	if n > 100000:
		return null
	var out := []
	for i in n:
		var len := f.get_32()
		if len <= 0 or len > 4096 or f.eof_reached():
			return null
		var nom := f.get_buffer(len).get_string_from_utf8().trim_prefix("res://")
		var debut := base + f.get_64()
		var taille := f.get_64()
		f.get_buffer(16)
		if f.get_32() & 1:  # fichier chiffré
			return null
		out.append([nom, debut, taille])
	return out


static func _extraire(path: String, entree: Array) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or entree[1] + entree[2] > f.get_length():
		return ""
	f.seek(entree[1])
	return f.get_buffer(entree[2]).get_string_from_utf8()
