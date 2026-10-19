extends Node
## Le registre des communes (autoload « Communes »). Smarves y est inscrite au démarrage depuis son
## manifeste ; les communes greffées arrivent de user://communes/, en pack (<id>.pck) ou en dossier
## (<id>/commune.json), et s'inscrivent de la même façon. Un pack n'est pas monté au lancement : son
## manifeste est lu dans le pack, et le pack n'est monté qu'au moment où l'on entre dans la commune
## (ouvrir), pour ne pas alourdir le démarrage, sur le web surtout. La carte de la Vienne (autoload
## Carte) lit ce registre pour savoir quelles communes s'allument et où l'on peut aller. La notice est dans docs/COMMUNE.md.

## Une commune vient d'être inscrite (Smarves au démarrage, puis chaque greffe).
signal inscrite(id: String)
## Le catalogue du portail vient d'être lu (ou n'a pas pu l'être : voir catalogue_etat).
signal catalogue_lu
## Une installation depuis le catalogue est finie : ok, et la phrase à montrer au joueur.
signal installee(id: String, ok: bool, message: String)
## L'état d'une commune a changé (mise en file, début ou fin d'un téléchargement) : voir etat().
signal etat_change(id: String)

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
## Les installations qui attendent leur tour (ids), une seule se télécharge à la fois ; le dernier
## échec de chaque commune (id -> phrase), gardé jusqu'au prochain essai ; et les communes mises à
## jour toutes seules au lancement depuis l'ouverture du jeu (ids).
var file: Array[String] = []
var echecs := {}
var mises_a_jour_seules: Array[String] = []
## Les villes publiées installées toutes seules à ce lancement.
var arrivees_seules: Array[String] = []
var _http: HTTPRequest
var _seules := {}
## Où vont les paquets installés, la dernière copie du catalogue (catalogue.json, pour la liste hors
## ligne) et les versions installées (installees.json). Un test le déplace.
var dossier_greffes := GREFFES
var _retour: CanvasLayer
## La commune où l'on vient d'entrer (visiter), avant que sa scène ne remplace la précédente.
var actuelle_apres := ""
## Les communes publiées que le joueur n'a pas encore vues dans son carnet (ids), et celles qu'il a
## vues : le carnet les marque « nouvelle », et le jeu en avertit au lancement.
var nouvelles: Array = []
var _vues: Array = []


func _ready() -> void:
	inscrire(Commune.smarves())
	# Les captures et les tests partent du jeu seul, sans les mods du joueur.
	if not "--capture" in " ".join(OS.get_cmdline_user_args()) and get_tree().get_script() == null:
		charger_greffes()
		_lire_copies()
		lire_catalogue()
	# Pour les captures : --greffes=<dossier> pose les greffes et la copie du catalogue d'un dossier d'essai.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--greffes="):
			dossier_greffes = arg.trim_prefix("--greffes=")
			charger_greffes(dossier_greffes)
			_lire_copies()


func commune(id: String) -> Commune:
	return communes.get(id)


func origine() -> Commune:
	return communes.get(ORIGINE)


## La commune développée à ce code INSEE, ou null (jamais une destination lointaine, qui n'en a pas).
func par_insee(insee: String) -> Commune:
	if insee == "":
		return null
	for id in communes:
		if communes[id].insee == insee:
			return communes[id]
	return null


## Les destinations lointaines installées (socle 1.5, champ « ailleurs ») : les vols au départ de
## Poitiers-Biard, dans l'ordre d'inscription.
func lointaines() -> Array:
	var out := []
	for id in ordre:
		if communes[id].lointaine():
			out.append(id)
	return out


## La carte de la Vienne : chaque commune réelle à sa place (centre et contour en longitude, latitude),
## avec « id » non vide et « cliquable » vrai seulement si elle est développée (installée) ; « publiee »
## dit qu'elle est au catalogue du portail, donc installable même si elle ne l'est pas encore.
func carte() -> Array:
	var publiees := {}
	for e in catalogue:
		if e.insee != "":
			publiees[e.insee] = true
	var out := []
	for v in Vienne.communes():
		var c := par_insee(str(v.insee))
		out.append({"insee": str(v.insee), "nom": str(v.nom), "centre": Vector2(v.centre[0], v.centre[1]),
			"contour": v.contour, "id": c.id if c else "", "cliquable": c != null, "publiee": publiees.has(str(v.insee))})
	return out


## La commune où se trouve le joueur : celle dont la scène est ouverte, Smarves sinon (le village, et
## aussi ses intérieurs).
func actuelle() -> String:
	var scene := get_tree().current_scene
	var chemin := scene.scene_file_path if scene else ""
	for id in ordre:
		if id != ORIGINE and str(communes[id].data.get("scene", "")) == chemin:
			return id
	return ORIGINE


## Les communes greffées, installées chez le joueur (hors Smarves), dans l'ordre d'inscription.
func installees() -> Array:
	return ordre.filter(func(id): return id != ORIGINE)


## Les communes publiées sur le portail (la dernière liste lue), installées ou non.
func publiees() -> Array:
	return catalogue


## La version publiée à installer pour cette commune installée, ou « » si elle est à jour (ou pas au
## catalogue). La version installée est celle téléchargée en dernier, sinon celle du manifeste.
func mise_a_jour(id: String) -> String:
	var e := au_catalogue(id)
	var c: Commune = communes.get(id)
	if e.is_empty() or c == null or e.version == "":
		return ""
	return e.version if str(installations.get(id, c.data.get("version", ""))) != e.version else ""


## Une version plus récente est déjà téléchargée et s'ouvrira au prochain lancement : sa version, ou « ».
func en_attente(id: String) -> String:
	var c: Commune = communes.get(id)
	var v := str(installations.get(id, ""))
	return v if c != null and v != "" and v != str(c.data.get("version", v)) else ""


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
	# Dans un navigateur, la réponse arrive déjà décompressée : Godot ne doit pas la décompresser encore.
	http.accept_gzip = not OS.has_feature("web")
	http.timeout = 0.0 if OS.has_feature("web") else 10.0
	# La bienvenue, le carnet et la carte mettent le jeu en pause : la requête doit avancer quand même.
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)
	http.request_completed.connect(func(resultat: int, code: int, _h, corps: PackedByteArray):
		http.queue_free()
		var texte := corps.get_string_from_utf8()
		if resultat == HTTPRequest.RESULT_SUCCESS and code == 200 and JSON.parse_string(texte) is Dictionary:
			catalogue = Portail.entrees(texte)
			catalogue_etat = "en_ligne"
			Portail.ecrire(dossier_greffes.path_join("catalogue.json"), texte)
			nouvelles = catalogue.map(func(e): return e.id).filter(func(id): return not _vues.has(id) and not communes.has(id))
			_mettre_a_jour_seules()
		else:
			catalogue_etat = "hors_ligne"
		catalogue_lu.emit())
	if http.request(adresse) != OK:
		http.queue_free()
		catalogue_etat = "hors_ligne"
		catalogue_lu.emit()


## L'état d'une commune pour le joueur, le même partout (bienvenue, carte, carnet) :
## « telechargement », « attente », « echec », « a_relancer » (la nouvelle version s'ouvrira au
## prochain lancement), « mise_a_jour » (une version plus récente est publiée), « a_jour »
## (installée), « publiee » (à installer), ou « » (ni installée ni publiée).
func etat(id: String) -> String:
	if en_cours == id:
		return "telechargement"
	if file.has(id):
		return "attente"
	if echecs.has(id):
		return "echec"
	if en_attente(id) != "":
		return "a_relancer"
	if mise_a_jour(id) != "":
		return "mise_a_jour"
	if communes.has(id):
		return "a_jour"
	return "publiee" if not au_catalogue(id).is_empty() else ""


## La ligne qui dit l'état d'une commune, en français, la même partout.
func resume(id: String) -> String:
	var e := au_catalogue(id)
	var c: Commune = communes.get(id)
	match etat(id):
		"telechargement":
			return "Téléchargement en cours"
		"attente":
			return "En attente de téléchargement"
		"echec":
			return str(echecs[id])
		"a_relancer":
			return ("Version %s téléchargée : relancez le jeu pour l'ouvrir." if peut_relancer()
				else "Version %s téléchargée : fermez Smarves et rouvrez-le pour l'ouvrir.") % en_attente(id)
		"mise_a_jour":
			return "La version %s est publiée." % mise_a_jour(id)
		"a_jour":
			var v := str(installations.get(id, c.data.get("version", "")))
			return ("Installée  ·  version %s" % v if v != "" else "Installée") + ("  ·  mise à jour toute seule" if mises_a_jour_seules.has(id)
				else "  ·  arrivée à ce lancement" if arrivees_seules.has(id) else "")
		"publiee":
			return "Publiée par %s  ·  %s" % [e.auteur, Portail.taille(e.taille)]
	return ""


## Le geste à proposer pour une commune, le même partout : [libellé, appel], ou [] s'il n'y en a pas.
## « Y aller » n'en fait pas partie : chaque écran a sa façon d'y emmener.
func geste(id: String) -> Array:
	match etat(id):
		"publiee":
			return ["Installer", installer.bind(id)]
		"mise_a_jour":
			return ["Mettre à jour (%s)" % mise_a_jour(id), installer.bind(id)]
		"echec":
			return ["Réessayer", installer.bind(id)]
		"a_relancer":
			return ["Relancer maintenant", relancer] if peut_relancer() else []
	return []


## Où en est le téléchargement de cette commune, de 0 à 1.
func progression(id: String) -> float:
	if en_cours != id or _http == null:
		return 0.0
	var total := maxi(_http.get_body_size(), int(au_catalogue(id).get("taille", 0)))
	return clampf(float(_http.get_downloaded_bytes()) / maxf(1.0, float(total)), 0.0, 1.0)


## Les communes qui demandent un geste (à mettre à jour, à réessayer, à relancer) et les nouvelles
## publiées pas encore installées.
func a_faire() -> Array:
	var ids: Array = ordre.filter(func(id): return id != ORIGINE)
	for e in catalogue:
		if not ids.has(e.id):
			ids.append(e.id)
	return ids.filter(func(id): return etat(id) in ["mise_a_jour", "echec", "a_relancer", "telechargement", "attente"])


func a_installer() -> Array:
	return catalogue.filter(func(e): return not communes.has(e.id)).map(func(e): return e.id)


## Met en file toutes les mises à jour publiées (et les échecs à réessayer).
func tout_mettre_a_jour() -> void:
	for id in ordre:
		if etat(id) in ["mise_a_jour", "echec"] and not au_catalogue(id).is_empty():
			installer(id)


## Au lancement : une commune installée mais pas encore ouverte dans la partie prend sa nouvelle
## version toute seule, rien ne s'y oppose. Une commune déjà ouverte attend le geste du joueur. Une
## ville publiée s'installe aussi toute seule : le portail ne publie que des villes déjà validées
## avec leurs développeurs, il n'y a rien à refuser.
func _mettre_a_jour_seules() -> void:
	for id in ordre:
		if id != ORIGINE and mise_a_jour(id) != "" and not communes[id].montee and not echecs.has(id):
			installer(id, true)
	for id in a_installer():
		if not echecs.has(id):
			installer(id, true)


## Télécharge le paquet publié de cette commune dans user://communes/<id>.pck, vérifie son empreinte,
## puis le soumet aux mêmes refus qu'une greffe déposée à la main. Un paquet refusé est effacé. Si
## un autre se télécharge déjà, celui-ci attend son tour dans la file.
func installer(id: String, seule := false) -> void:
	var e := au_catalogue(id)
	if e.is_empty():
		installee.emit(id, false, "Commune absente du catalogue.")
		return
	if en_cours == id or file.has(id):
		return
	echecs.erase(id)
	if seule:
		# true : une ville qui arrive ; false : une mise à jour.
		_seules[id] = not communes.has(id)
	if en_cours != "":
		file.append(id)
		etat_change.emit(id)
		return
	en_cours = id
	etat_change.emit(id)
	DirAccess.make_dir_recursive_absolute(dossier_greffes)
	var part := dossier_greffes.path_join(id + ".pck.part")
	var http := HTTPRequest.new()
	# Dans un navigateur, la réponse arrive déjà décompressée : Godot ne doit pas la décompresser encore.
	http.accept_gzip = not OS.has_feature("web")
	http.timeout = 0.0 if OS.has_feature("web") else 120.0
	http.download_file = part
	http.body_size_limit = Portail.TAILLE_MAX + 1
	# Un téléchargement lancé depuis la bienvenue ou la carte, jeu en pause, doit aboutir.
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)
	_http = http
	http.request_completed.connect(func(resultat: int, code: int, _h, _c):
		http.queue_free()
		_http = null
		_installe(e, part, resultat == HTTPRequest.RESULT_SUCCESS and code == 200))
	if http.request(e.paquet) != OK:
		http.queue_free()
		_http = null
		_installe(e, part, false)


## La fin d'une installation : le dernier échec retenu, la phrase pour le joueur, puis la suivante.
func _fini(id: String, ok: bool, message: String) -> void:
	en_cours = ""
	if ok:
		echecs.erase(id)
		var liste: Array[String] = arrivees_seules if _seules.get(id, false) else mises_a_jour_seules
		if _seules.has(id) and not liste.has(id):
			liste.append(id)
	else:
		echecs[id] = message
	_seules.erase(id)
	installee.emit(id, ok, message)
	etat_change.emit(id)
	if not file.is_empty():
		installer(file.pop_front())


func _installe(e: Dictionary, part: String, recu: bool) -> void:
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
		_fini(id, false, raison)
		return
	# Une commune déjà visitée a son pack monté : Godot ne peut pas le remplacer, la nouvelle version
	# attend le prochain lancement (relancer()). Pas encore visitée, elle prend sa place tout de suite.
	var deja: bool = communes.has(id) and communes[id].montee
	if deja:
		DirAccess.rename_absolute(part, fin + ".nouveau")
	else:
		var ancienne: Commune = communes.get(id)
		if ancienne:
			DirAccess.rename_absolute(fin, fin + ".ancien")
			communes.erase(id)
			ordre.erase(id)
		DirAccess.remove_absolute(fin)
		DirAccess.rename_absolute(part, fin)
		if charger_pack(fin) == "":
			raison = refus[-1][1] if not refus.is_empty() else "paquet refusé"
			DirAccess.remove_absolute(fin)
			if ancienne:
				DirAccess.rename_absolute(fin + ".ancien", fin)
				inscrire(ancienne)
			_fini(id, false, "%s n'a pas pu s'installer : %s." % [e.nom, raison])
			return
		DirAccess.remove_absolute(fin + ".ancien")
	installations[id] = e.version
	Portail.ecrire(dossier_greffes.path_join("installees.json"), JSON.stringify(installations))
	_fini(id, true, ("%s est arrivée : elle est sur la carte." % e.nom) if _seules.get(id, false)
		else ("%s s'est mise à jour toute seule en %s." % [e.nom, e.version]) if _seules.has(id)
		else ("%s est installée." % e.nom) if not deja else ("La version %s de %s s'ouvrira au prochain lancement." % [e.version, e.nom]))


## Relancer le jeu ouvre les versions téléchargées pendant la partie ; seulement sur ordinateur.
func peut_relancer() -> bool:
	return not (OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web"))


## Enregistre la partie, puis ferme le jeu et le rouvre.
func relancer() -> void:
	Game.save_game()
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()


## Entre dans une commune greffée : monte son pack, change de scène, et pose le bouton du retour.
func visiter(id: String) -> bool:
	if id == ORIGINE or not ouvrir(id):
		return false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(str(communes[id].data.scene))
	actuelle_apres = id
	_bouton_retour(true)
	return true


func revenir() -> void:
	actuelle_apres = ""
	_bouton_retour(false)
	get_tree().paused = false
	get_tree().change_scene_to_file(str(origine().data.scene))


func _bouton_retour(visible: bool) -> void:
	if _retour == null:
		_retour = CanvasLayer.new()
		_retour.layer = 90
		var rang := HBoxContainer.new()
		rang.position = Vector2(20, 20)
		rang.add_theme_constant_override("separation", 10)
		_retour.add_child(rang)
		for t in [["Revenir à Smarves", _rentrer], ["La carte  (M)", func(): Carte.ouvrir()]]:
			var b := Button.new()
			b.text = t[0]
			b.add_theme_font_override("font", Polices.gras())
			b.add_theme_font_size_override("font_size", 22)
			b.pressed.connect(t[1])
			rang.add_child(b)
		add_child(_retour)
	_retour.visible = visible
	# D'une destination lointaine, on rentre en avion (socle 1.5).
	var loin := commune(actuelle_apres) if actuelle_apres != "" else null
	(_retour.get_child(0).get_child(0) as Button).text = "Reprendre l'avion" if loin != null and loin.lointaine() else "Revenir à Smarves"


## Le premier bouton du coin : rentrer à Smarves, en avion depuis une destination lointaine.
func _rentrer() -> void:
	var c := commune(actuelle())
	if c != null and c.lointaine():
		Carte.voler(ORIGINE)
	else:
		revenir()


func _lire_copies() -> void:
	var cache = Portail.lire_json(dossier_greffes.path_join("catalogue.json"))
	if cache is Dictionary:
		catalogue = Portail.entrees(JSON.stringify(cache))
	var inst = Portail.lire_json(dossier_greffes.path_join("installees.json"))
	if inst is Dictionary:
		installations = inst
	var vues = Portail.lire_json(dossier_greffes.path_join("vues.json"))
	if vues is Array:
		_vues = vues


## Le joueur a vu la liste : plus rien n'y est nouveau.
func marquer_vues() -> void:
	if nouvelles.is_empty():
		return
	for id in nouvelles:
		if not _vues.has(id):
			_vues.append(id)
	nouvelles = []
	Portail.ecrire(dossier_greffes.path_join("vues.json"), JSON.stringify(_vues))


## Inscrit une commune lue et vérifiée. Refuse un manifeste en erreur ou un id déjà pris.
func inscrire(c: Commune) -> bool:
	if c == null or not c.valide():
		_refuser(c.chemin if c else "?", "; ".join(c.erreurs) if c else "commune vide")
		return false
	if communes.has(c.id):
		_refuser(c.chemin, "la commune « %s » est déjà inscrite" % c.id)
		return false
	if not c.lointaine() and par_insee(c.insee) != null:
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
	c.signature = signature(path)
	if c.valide() and c.id != id:
		c.erreurs.append("le pack s'appelle « %s » mais son manifeste dit « %s »" % [id, c.id])
	return id if inscrire(c) else ""


## Prépare une commune pour y entrer : monte son pack s'il ne l'est pas encore et vérifie sa scène.
## À appeler depuis la carte, juste avant de changer de scène.
func ouvrir(id: String) -> bool:
	var c: Commune = communes.get(id)
	if c == null:
		return false
	# Un pack remplacé sur le disque pendant la partie (une nouvelle version déposée à la main) : pas
	# encore monté, on relit son manifeste ; déjà monté, Godot lirait le nouveau fichier aux places de
	# l'ancien et planterait, alors on attend le prochain lancement.
	if c.pack != "" and signature(c.pack) != c.signature:
		if c.montee:
			_refuser(c.pack, "le paquet a changé depuis qu'il a été ouvert ; la nouvelle version s'ouvrira au prochain lancement du jeu")
			return false
		communes.erase(id)
		ordre.erase(id)
		if charger_pack(c.pack) == "":
			return false
		c = communes[id]
	if not c.montee:
		if not ProjectSettings.load_resource_pack(c.pack, false):
			_refuser(c.pack, "Godot n'a pas pu monter le pack")
			return false
		c.montee = true
	if not c.scene_presente():
		_refuser(c.chemin, "scène introuvable : %s" % c.data.scene)
		return false
	return true


## La date et la taille d'un fichier, pour savoir s'il a été remplacé depuis qu'on l'a lu.
static func signature(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return "%d:%d" % [FileAccess.get_modified_time(path), f.get_length()] if f else ""


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
