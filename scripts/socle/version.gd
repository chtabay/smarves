extends Node
## La version du jeu (autoload « Version »). Chaque export range son commit dans res://version.json
## (addons/smarves_version) ; au lancement, le jeu lit sur GitHub les derniers commits de l'étiquette
## « derniere-version », celle de la Release que l'export de main déplace. Si l'étiquette est
## ailleurs, une nouvelle version attend : la bienvenue l'annonce, avec ce qui a changé, et propose
## de la télécharger. Sans estampille (lancé depuis l'éditeur, outils de test) ou sur le web, qui se
## met à jour seul, rien n'est lu. En cas d'échec, le jeu se tait : on joue à la version qu'on a.

## La lecture est finie (ou a échoué : voir etat).
signal lue

const DEPOT := "chtabay/smarves"
const ETIQUETTE := "derniere-version"
## Les commits de l'étiquette, sans compte. `--version-distante=<adresse>` la remplace (essais).
const ADRESSE := "https://api.github.com/repos/%s/commits?sha=%s&per_page=20" % [DEPOT, ETIQUETTE]
const TELECHARGER := "https://github.com/%s/releases/download/%s/" % [DEPOT, ETIQUETTE]
const PAGE := "https://github.com/%s/releases/tag/%s" % [DEPOT, ETIQUETTE]

## Le commit de ce jeu (« » sans estampille), celui de la dernière version, et ses nouveautés :
## les titres des commits arrivés depuis, du plus récent au plus ancien.
var locale := ""
var distante := ""
var nouveautes: Array[String] = []
## « » tant que rien n'est lu, puis « lecture », « a_jour », « nouvelle » ou « hors_ligne ».
var etat := ""


func _ready() -> void:
	if FileAccess.file_exists("res://version.json"):
		var lu = JSON.parse_string(FileAccess.get_file_as_string("res://version.json"))
		if lu is Dictionary:
			locale = str(lu.get("commit", ""))
	if (locale != "" or _adresse() != ADRESSE) and not OS.has_feature("web") and get_tree().get_script() == null:
		lire()


func disponible() -> bool:
	return etat == "nouvelle"


func lire(adresse := _adresse()) -> void:
	etat = "lecture"
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(resultat: int, code: int, _h, corps: PackedByteArray):
		http.queue_free()
		var commits = JSON.parse_string(corps.get_string_from_utf8())
		if resultat == HTTPRequest.RESULT_SUCCESS and code == 200 and commits is Array and not commits.is_empty():
			comparer(commits)
		else:
			etat = "hors_ligne"
			print_verbose("Version : lecture impossible (%d, %d)" % [resultat, code])
		lue.emit())
	if http.request(adresse, ["Accept: application/vnd.github+json", "User-Agent: Smarves"]) != OK:
		http.queue_free()
		etat = "hors_ligne"
		lue.emit()


## Les commits de l'étiquette (réponse de GitHub, du plus récent au plus ancien) face au commit local.
func comparer(commits: Array) -> void:
	distante = str(commits[0].get("sha", ""))
	nouveautes.clear()
	if distante == "" or distante == locale:
		etat = "a_jour"
		return
	for c in commits:
		if str(c.get("sha", "")) == locale:
			break
		var titre := str(c.get("commit", {}).get("message", "")).get_slice("\n", 0).strip_edges()
		# « Place : l'encart se replie (#68) » : le numéro de PR ne dit rien au joueur.
		var re := RegEx.create_from_string("\\s*\\(#\\d+\\)$")
		titre = re.sub(titre, "")
		if titre != "" and not titre.begins_with("Merge "):
			nouveautes.append(titre)
	etat = "nouvelle"


## Le fichier de la Release pour cette plateforme ; à défaut, la page de la Release.
func adresse_telechargement() -> String:
	match OS.get_name():
		"Windows":
			return TELECHARGER + "Smarves-installateur.exe"
		"Android":
			return TELECHARGER + "Smarves.apk"
	return PAGE


func telecharger() -> void:
	OS.shell_open(adresse_telechargement())


static func _adresse() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--version-distante="):
			return arg.trim_prefix("--version-distante=")
	return ADRESSE
