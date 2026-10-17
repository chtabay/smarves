extends Node
## Le registre des communes (autoload « Communes »). Smarves y est inscrite au démarrage depuis son
## manifeste ; les communes greffées arrivent de user://communes/, en pack (<id>.pck) ou en dossier
## (<id>/commune.json), et s'inscrivent de la même façon. Un pack n'est pas monté au lancement : son
## manifeste est lu dans le pack, et le pack n'est monté qu'au moment où l'on entre dans la commune
## (ouvrir), pour ne pas alourdir le démarrage, sur le web surtout. Rien ne s'affiche : la carte de la
## Vienne viendra lire ce registre. La notice est dans docs/COMMUNE.md.

## Une commune vient d'être inscrite (Smarves au démarrage, puis chaque greffe).
signal inscrite(id: String)
## Le catalogue du portail vient d'être lu (ou n'a pas pu l'être : voir catalogue_etat).
signal catalogue_lu
## Une installation depuis le catalogue est finie : ok, et la phrase à montrer au joueur.
signal installee(id: String, ok: bool, message: String)

const GREFFES := "user://communes/"

## La commune d'origine du joueur : son banquier est le prêteur par défaut.
const ORIGINE := "smarves"

## id -> Commune, dans l'ordre d'inscription (voir ordre).
var communes := {}
var ordre: Array[String] = []
## Les greffes refusées au dernier chargement, avec la raison : [chemin, raison].
var refus: Array = []
## Les communes publiées sur le portail (Portail.entrees), lues au lancement ou, hors ligne, la
## dernière copie. « » tant que rien n'a été lu, puis « lecture », « en_ligne » ou « hors_ligne ».
var catalogue: Array = []
var catalogue_etat := ""
## Les versions installées depuis le catalogue (id -> version), et l'id en cours de téléchargement.
var installations := {}
var en_cours := ""
## Où vont les paquets installés, la dernière copie du catalogue (catalogue.json, pour la liste hors
## ligne) et les versions installées (installees.json). Un test le déplace.
var dossier_greffes := GREFFES
var _retour: CanvasLayer


func _ready() -> void:
	inscrire(Commune.smarves())
	# Les captures et les tests partent du jeu seul, sans les mods du joueur.
	if not "--capture" in " ".join(OS.get_cmdline_user_args()) and get_tree().get_script() == null:
		charger_greffes()
		_lire_copies()
		lire_catalogue()


func commune(id: String) -> Commune:
	return communes.get(id)


func origine() -> Commune:
	return communes.get(ORIGINE)


## La commune développée à ce code INSEE, ou null.
func par_insee(insee: String) -> Commune:
	for id in communes:
		if communes[id].insee == insee:
			return communes[id]
	return null


## La carte de la Vienne : chaque commune réelle à sa place (centre et contour en longitude, latitude),
## avec « id » non vide et « cliquable » vrai seulement si elle est développée (installée) ; « publiee »
## dit qu'elle est au catalogue du portail, donc installable même si elle ne l'est pas encore.
func carte() -> Array:
	var publiees := {}
	for e in catalogue:
		publiees[e.insee] = true
	var out := []
	for v in Vienne.communes():
		var c := par_insee(str(v.insee))
		out.append({"insee": str(v.insee), "nom": str(v.nom), "centre": Vector2(v.centre[0], v.centre[1]),
			"contour": v.contour, "id": c.id if c else "", "cliquable": c != null, "publiee": publiees.has(str(v.insee))})
	return out


## Les communes greffées, installées chez le joueur (hors Smarves), dans l'ordre d'inscription.
func installees() -> Array:
	return ordre.filter(func(id): return id != ORIGINE)


## Les communes publiées sur le portail (la dernière liste lue), installées ou non.
func publiees() -> Array:
	return catalogue


## L'entrée du catalogue pour cet id, ou {}.
func au_catalogue(id: String) -> Dictionary:
	for e in catalogue:
		if e.id == id:
			return e
	return {}


## Les paquets refusés chez le joueur, déposés à la main ou téléchargés : [{id, nom, raison}], un par
## commune, le dernier motif l'emporte. Le carnet les montre, pour qu'un développeur qui essaie son
## paquet sache pourquoi sans ouvrir la console. Une commune inscrite depuis n'y figure plus.
func refusees() -> Array:
	var par_id := {}
	for r in refus:
		var chemin := str(r[0])
		if not chemin.begins_with(dossier_greffes):
			continue
		var f := chemin.get_file()
		var id := chemin.get_base_dir().get_file() if f == "commune.json" else f.get_slice(".", 0)
		if not communes.has(id):
			par_id[id] = {"id": id, "nom": str(au_catalogue(id).get("nom", id)), "raison": str(r[1])}
	return par_id.values()


## Lit le catalogue du portail, sans jamais bloquer le jeu : en cas d'échec, la dernière copie reste.
func lire_catalogue(adresse := Portail.adresse()) -> void:
	catalogue_etat = "lecture"
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(resultat: int, code: int, _h, corps: PackedByteArray):
		http.queue_free()
		var texte := corps.get_string_from_utf8()
		if resultat == HTTPRequest.RESULT_SUCCESS and code == 200 and JSON.parse_string(texte) is Dictionary:
			catalogue = Portail.entrees(texte)
			catalogue_etat = "en_ligne"
			Portail.ecrire(dossier_greffes.path_join("catalogue.json"), texte)
		else:
			catalogue_etat = "hors_ligne"
		catalogue_lu.emit())
	if http.request(adresse) != OK:
		http.queue_free()
		catalogue_etat = "hors_ligne"
		catalogue_lu.emit()


## Télécharge le paquet publié de cette commune dans user://communes/<id>.pck, vérifie son empreinte,
## puis le soumet aux mêmes refus qu'une greffe déposée à la main. Un paquet refusé est effacé.
func installer(id: String) -> void:
	var e := au_catalogue(id)
	if e.is_empty() or en_cours != "":
		installee.emit(id, false, "Une installation est déjà en cours." if en_cours != "" else "Commune absente du catalogue.")
		return
	en_cours = id
	DirAccess.make_dir_recursive_absolute(dossier_greffes)
	var part := dossier_greffes.path_join(id + ".pck.part")
	var http := HTTPRequest.new()
	http.timeout = 120.0
	http.download_file = part
	http.body_size_limit = Portail.TAILLE_MAX + 1
	add_child(http)
	http.request_completed.connect(func(resultat: int, code: int, _h, _c):
		http.queue_free()
		_installe(e, part, resultat == HTTPRequest.RESULT_SUCCESS and code == 200))
	if http.request(e.paquet) != OK:
		http.queue_free()
		_installe(e, part, false)


func _installe(e: Dictionary, part: String, recu: bool) -> void:
	en_cours = ""
	var id: String = e.id
	var fin := dossier_greffes.path_join(id + ".pck")
	var raison := ""
	if not recu:
		raison = "Le téléchargement n'a pas abouti. Réessayez une fois en ligne."
	elif FileAccess.get_sha256(part) != e.sha256:
		raison = "Le paquet reçu ne correspond pas au catalogue."
	if raison != "":
		DirAccess.remove_absolute(part)
		_refuser(part, "téléchargement inabouti" if not recu else "le paquet reçu ne correspond pas au catalogue")
		installee.emit(id, false, raison)
		return
	# Une commune déjà inscrite a son pack ouvert : la nouvelle version attend le prochain lancement.
	var deja := communes.has(id)
	if deja:
		DirAccess.rename_absolute(part, fin + ".nouveau")
	else:
		DirAccess.remove_absolute(fin)
		DirAccess.rename_absolute(part, fin)
	if not deja and charger_pack(fin) == "":
		raison = refus[-1][1] if not refus.is_empty() else "paquet refusé"
		DirAccess.remove_absolute(fin)
		installee.emit(id, false, "%s n'a pas pu s'installer : %s." % [e.nom, raison])
		return
	installations[id] = e.version
	Portail.ecrire(dossier_greffes.path_join("installees.json"), JSON.stringify(installations))
	installee.emit(id, true, ("%s est installée." % e.nom) if not deja else ("La version %s de %s s'ouvrira au prochain lancement." % [e.version, e.nom]))


## Entre dans une commune greffée : monte son pack, change de scène, et pose le bouton du retour.
func visiter(id: String) -> bool:
	if id == ORIGINE or not ouvrir(id):
		return false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(str(communes[id].data.scene))
	_bouton_retour(true)
	return true


func revenir() -> void:
	_bouton_retour(false)
	get_tree().paused = false
	get_tree().change_scene_to_file(str(origine().data.scene))


func _bouton_retour(visible: bool) -> void:
	if _retour == null:
		_retour = CanvasLayer.new()
		_retour.layer = 90
		var b := Button.new()
		b.text = "Revenir à Smarves"
		b.position = Vector2(20, 20)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(revenir)
		_retour.add_child(b)
		add_child(_retour)
	_retour.visible = visible


func _lire_copies() -> void:
	var cache = Portail.lire_json(dossier_greffes.path_join("catalogue.json"))
	if cache is Dictionary:
		catalogue = Portail.entrees(JSON.stringify(cache))
	var inst = Portail.lire_json(dossier_greffes.path_join("installees.json"))
	if inst is Dictionary:
		installations = inst


## Inscrit une commune lue et vérifiée. Refuse un manifeste en erreur ou un id déjà pris.
func inscrire(c: Commune) -> bool:
	if c == null or not c.valide():
		_refuser(c.chemin if c else "?", "; ".join(c.erreurs) if c else "commune vide")
		return false
	if communes.has(c.id):
		_refuser(c.chemin, "la commune « %s » est déjà inscrite" % c.id)
		return false
	if par_insee(c.insee) != null:
		_refuser(c.chemin, "la commune INSEE %s est déjà développée par « %s »" % [c.insee, par_insee(c.insee).id])
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
	# Une mise à jour téléchargée pendant la partie précédente prend la place de l'ancien pack.
	for f in d.get_files():
		if f.ends_with(".pck.nouveau"):
			DirAccess.remove_absolute(dossier.path_join(f.trim_suffix(".nouveau")))
			DirAccess.rename_absolute(dossier.path_join(f), dossier.path_join(f.trim_suffix(".nouveau")))
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
