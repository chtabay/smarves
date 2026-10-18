extends Node
## Le compte Pyramides (autoload « Compte »), étape 1 du multi (docs/SUITE.md, section 4) : se
## connecter depuis le jeu et garder sa partie au compte, pour la retrouver sur un autre appareil.
##
## La connexion passe par le serveur d'autorisation de Pyramides, comme Addict Casino et Belley : le
## jeu s'y enregistre seul (client public), ouvre la page de connexion dans le navigateur du système
## et prouve sa demande par PKCE. Pyramides revient sur une adresse de la machine même
## (http://127.0.0.1:<port>/retour), où le jeu écoute dans un fil à part : sur Android, le jeu est
## en arrière-plan pendant ce temps et sa boucle principale est suspendue, le fil répond quand même.
## Le jeton (portée « smarves », trente jours) ne dit que qui joue ; la base le vérifie elle-même
## (supabase/migrations, fonctions public.smarves_*).
##
## La partie reste écrite sur l'appareil, et part aussi au compte : les fichiers tels quels (socle,
## tiroirs des communes, biens), numérotés par le serveur. Le jeu retient la version qu'il a envoyée
## ou reprise en dernier et l'empreinte de ses fichiers à ce moment ; c'est ce qui dit, au lancement,
## qui a bougé : le compte seul (on reprend), l'appareil seul (on envoie), ou les deux (le joueur
## choisit). Sans compte, rien de ce fichier ne s'exécute et le jeu se joue comme avant.

## L'état a changé : la bienvenue se redessine.
signal change

const PYRAMIDES := "https://pyramides2.vercel.app"
const SUPABASE := "https://alvxrjftenialifyktyz.supabase.co/rest/v1/rpc/"
## Clé publique du projet : elle n'ouvre rien, c'est le jeton du joueur qui fait foi.
const CLE_PUBLIQUE := "sb_publishable_JTwbhl8YTGJ9dPUmIwxctQ_vlu96NgE"
## Les ports essayés pour le retour, tous déclarés à l'enregistrement (l'adresse doit être exacte).
const PORTS := [47811, 47812, 47813, 47814, 47815]
const FICHIER := "user://compte.cfg"
## Les fichiers de la partie, relatifs à user:// : le socle, les tiroirs (communes/*.save), les biens.
const SOCLE := "socle.save"
const TIROIRS := "communes/"
const BIENS := "smarves_biens.save"
## Au plus un envoi par période, s'il y a du nouveau.
const PERIODE := 30.0
const ATTENTE_CONNEXION := 300.0

## « deconnecte », « connexion » (le navigateur est ouvert), « verification », « a_jour »,
## « envoi », « hors_ligne », « expire », « choix » (deux parties ont avancé chacune de leur côté)
## ou « erreur » (la connexion a échoué : voir message).
var etat := "deconnecte"
var message := ""
var nom := ""
var joueur_id := ""
## La partie du compte quand il faut choisir : {version, resume, appareil, maj}.
var autre := {}
## Le moment (secondes Unix) du dernier envoi ou de la dernière reprise réussis.
var synchro_a := 0

var _jeton := ""
var _expire := 0
## La version du compte que cet appareil a envoyée ou reprise en dernier, et l'empreinte des
## fichiers à ce moment-là.
var _version := 0
var _empreinte := ""
## L'enregistrement chez Pyramides, gardé : {adresses jointes par des espaces: client_id}.
var _clients := {}
var _attente := {}
var _fil: Thread
var _fil_arret := false
var _fil_retour := {}
var _verrou := Mutex.new()
var _depuis_connexion := 0.0
var _minuteur: Timer
var _essai := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--compte-essai="):
			_essai = arg.trim_prefix("--compte-essai=")
	if _essai != "":
		_mise_en_scene(_essai)
		return
	# Les outils de test (-s) et les captures mènent leur propre partie : jamais le compte.
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	_lire()
	_minuteur = Timer.new()
	_minuteur.wait_time = PERIODE
	_minuteur.autostart = true
	_minuteur.timeout.connect(_periodique)
	add_child(_minuteur)
	if connecte():
		verifier()
	elif _jeton != "":
		etat = "expire"


func _notification(what: int) -> void:
	# Le joueur quitte ou passe à autre chose : ce qu'il a joué part tout de suite.
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if etat in ["a_jour", "hors_ligne"] and connecte() and _sale():
			_envoyer(_version)
	elif what == NOTIFICATION_PREDELETE:
		_arreter_fil()


func _process(delta: float) -> void:
	if etat != "connexion":
		return
	_depuis_connexion += delta
	_verrou.lock()
	var retour := _fil_retour.duplicate()
	_verrou.unlock()
	if not retour.is_empty():
		_arreter_fil()
		_retour(retour)
	elif _depuis_connexion > ATTENTE_CONNEXION:
		annuler()


## Un jeton qui vaut encore au moins une minute.
func connecte() -> bool:
	return _jeton != "" and _expire > Time.get_unix_time_from_system() + 60


# --- La connexion ----------------------------------------------------------------------------

func se_connecter() -> void:
	if etat == "connexion":
		return
	_arreter_fil()
	var serveur := TCPServer.new()
	var port := 0
	for p in PORTS:
		if serveur.listen(p, "127.0.0.1") == OK:
			port = p
			break
	if port == 0:
		_echec("Aucun port libre sur cette machine pour revenir de Pyramides.")
		return
	_etat("connexion", "Enregistrement…")
	var client := await _client()
	if client == "":
		serveur.stop()
		_echec("Pyramides ne répond pas. Vérifiez la connexion à Internet.")
		return
	var verifieur := _hasard()
	var adresse := "http://127.0.0.1:%d/retour" % port
	_attente = {"verifieur": verifieur, "etat": _hasard(), "client": client, "adresse": adresse}
	_fil_arret = false
	_fil_retour = {}
	_fil = Thread.new()
	_fil.start(_ecouter.bind(serveur))
	_depuis_connexion = 0.0
	var q := {"response_type": "code", "client_id": client, "redirect_uri": adresse, "scope": "smarves",
		"state": _attente.etat, "code_challenge": _b64url(verifieur.sha256_buffer()), "code_challenge_method": "S256"}
	OS.shell_open("%s/oauth/authorize?%s" % [PYRAMIDES, _requete(q)])
	_etat("connexion", "Terminez la connexion dans le navigateur, puis revenez ici.")


func annuler() -> void:
	_arreter_fil()
	_attente = {}
	_etat("deconnecte" if _jeton == "" else ("expire" if not connecte() else "a_jour"))


## Oublie le compte sur cet appareil. La partie de l'appareil reste telle quelle, celle du compte aussi.
func se_deconnecter() -> void:
	_jeton = ""
	_expire = 0
	nom = ""
	joueur_id = ""
	_version = 0
	_empreinte = ""
	autre = {}
	synchro_a = 0
	_ecrire()
	_etat("deconnecte")


## Un client par jeu d'adresses de retour, enregistré une fois et gardé.
func _client() -> String:
	var adresses: Array = PORTS.map(func(p): return "http://127.0.0.1:%d/retour" % p)
	var cle := " ".join(adresses)
	if _clients.has(cle):
		return str(_clients[cle])
	var r := await _http(PYRAMIDES + "/oauth/register", ["Content-Type: application/json"],
		JSON.stringify({"client_name": "Smarves", "redirect_uris": adresses}))
	if r.code != 201 or not r.corps is Dictionary or str(r.corps.get("client_id", "")) == "":
		return ""
	_clients[cle] = str(r.corps.client_id)
	_ecrire()
	return _clients[cle]


## Le retour de Pyramides, lu par le fil : {code, etat} ou {erreur}.
func _retour(retour: Dictionary) -> void:
	var attente := _attente
	_attente = {}
	if retour.has("erreur") or attente.is_empty():
		_echec("Connexion refusée." if retour.get("erreur", "") == "access_denied" else "La connexion n'a pas abouti.")
		return
	if retour.get("etat", "") != attente.etat:
		_echec("La connexion n'a pas abouti.")
		return
	_etat("connexion", "Connexion…")
	var r := await _http(PYRAMIDES + "/oauth/token", ["Content-Type: application/x-www-form-urlencoded"],
		_requete({"grant_type": "authorization_code", "code": retour.code, "client_id": attente.client,
			"redirect_uri": attente.adresse, "code_verifier": attente.verifieur}))
	if r.code != 200 or not r.corps is Dictionary or str(r.corps.get("access_token", "")) == "":
		_echec("La connexion n'a pas abouti.")
		return
	var jeton := str(r.corps.access_token)
	var corps := _corps_du_jeton(jeton)
	var id := str(corps.get("sub", ""))
	# Un autre compte que le précédent : cet appareil n'a rien envoyé à celui-ci.
	if id != joueur_id:
		_version = 0
		_empreinte = ""
	_jeton = jeton
	joueur_id = id
	nom = str(corps.get("name", ""))
	_expire = int(corps.get("exp", Time.get_unix_time_from_system() + int(r.corps.get("expires_in", 0))))
	_ecrire()
	verifier()


## Le fil d'écoute : attend la visite du navigateur sur l'adresse de retour, lui répond une page
## courte, et laisse le code au jeu. Il s'arrête de lui-même dès qu'il a une réponse.
func _ecouter(serveur: TCPServer) -> void:
	var page_ok := "<p>Smarves est connecté à votre compte Pyramides.</p><p>Vous pouvez fermer cette page et revenir au jeu.</p>"
	var page_ko := "<p>La connexion à Smarves n'a pas abouti.</p><p>Revenez au jeu pour réessayer.</p>"
	while not _fil_arret:
		if not serveur.is_connection_available():
			OS.delay_msec(50)
			continue
		var pair := serveur.take_connection()
		var texte := ""
		var debut := Time.get_ticks_msec()
		while Time.get_ticks_msec() - debut < 3000 and not "\r\n\r\n" in texte:
			pair.poll()
			var n := pair.get_available_bytes()
			if n > 0:
				texte += pair.get_utf8_string(n)
			else:
				OS.delay_msec(10)
		var ligne := texte.get_slice("\r\n", 0).split(" ")
		var chemin := ligne[1] if ligne.size() > 1 else ""
		if not chemin.begins_with("/retour"):
			_repondre(pair, 404, "")
			continue
		var params := _params(chemin.get_slice("?", 1) if "?" in chemin else "")
		var resultat := {}
		if params.has("code"):
			resultat = {"code": params.code, "etat": params.get("state", "")}
		else:
			resultat = {"erreur": params.get("error", "inconnue")}
		_repondre(pair, 200, page_ok if params.has("code") else page_ko)
		_verrou.lock()
		_fil_retour = resultat
		_verrou.unlock()
		break
	serveur.stop()


func _repondre(pair: StreamPeerTCP, code: int, contenu: String) -> void:
	var html := ("<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width'>"
		+ "<title>Smarves</title><body style='font:18px sans-serif;background:#0f141e;color:#e0e4ea;"
		+ "display:grid;place-items:center;min-height:90vh;text-align:center'><div><h1 style='color:#f5cc73'>"
		+ "Smarves</h1>%s</div>") % contenu
	var corps := html.to_utf8_buffer()
	var tete := "HTTP/1.1 %d %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
		% [code, "OK" if code == 200 else "Not Found", corps.size()]
	pair.put_data(tete.to_utf8_buffer() + corps)
	pair.poll()
	OS.delay_msec(100)
	pair.disconnect_from_host()


func _arreter_fil() -> void:
	if _fil and _fil.is_started():
		_fil_arret = true
		_fil.wait_to_finish()
	_fil = null


# --- La partie au compte ---------------------------------------------------------------------

## Compare la partie de l'appareil à celle du compte, et fait ce qu'il faut.
func verifier() -> void:
	if not connecte():
		_etat("expire" if _jeton != "" else "deconnecte")
		return
	_etat("verification")
	var r := await _rpc("smarves_partie_lire", {})
	if not _reponse_valable(r):
		return
	var v := int(r.corps.get("version", 0))
	match decider(v, _version, _sale(), _vierge()):
		"envoyer":
			_envoyer(v)
		"reprendre":
			_reprendre(r.corps)
		"choisir":
			autre = r.corps.duplicate()
			autre.erase("fichiers")
			_etat("choix")
		_:
			_version = v
			synchro_a = maxi(synchro_a, int(r.corps.get("maj", 0)))
			_ecrire()
			_etat("a_jour")


## Qui a bougé depuis la dernière synchro : serveur (version du compte), local (version que cet appareil
## connaît), sale (la partie de l'appareil a changé depuis), vierge (l'appareil n'a qu'une partie neuve).
## Renvoie « envoyer », « reprendre », « choisir » ou « rien ».
static func decider(serveur: int, local: int, sale: bool, vierge: bool) -> String:
	if serveur == 0:
		return "envoyer"
	if serveur == local:
		return "envoyer" if sale else "rien"
	if not sale or vierge:
		return "reprendre"
	return "choisir"


## Le joueur garde la partie de cet appareil : elle remplace celle du compte.
func garder_appareil() -> void:
	if etat == "choix":
		_envoyer(int(autre.get("version", 0)))


## Le joueur reprend la partie du compte : elle remplace celle de cet appareil.
func prendre_compte() -> void:
	if etat != "choix":
		return
	_etat("verification")
	var r := await _rpc("smarves_partie_lire", {})
	if _reponse_valable(r):
		_reprendre(r.corps)


func _envoyer(base: int) -> void:
	var fichiers := lire_fichiers()
	var empreinte := empreinte_de(fichiers)
	# Rien encore d'écrit sur l'appareil : rien à envoyer.
	if fichiers.is_empty():
		_etat("a_jour")
		return
	_etat("envoi")
	var r := await _rpc("smarves_partie_ecrire", {"p_version": base, "p_fichiers": fichiers,
		"p_resume": resume(), "p_appareil": appareil()})
	if not _reponse_valable(r):
		return
	if r.corps.get("ok", false):
		_version = int(r.corps.version)
		_empreinte = empreinte
		synchro_a = int(Time.get_unix_time_from_system())
		_ecrire()
		_etat("a_jour")
	else:
		# Un autre appareil a écrit entre-temps : on relit, et le joueur choisira s'il le faut.
		verifier()


func _reprendre(partie: Dictionary) -> void:
	var fichiers = partie.get("fichiers", {})
	if not fichiers is Dictionary or fichiers.is_empty():
		_echec("La partie du compte est illisible.")
		return
	ecrire_fichiers(fichiers)
	Game.recharger()
	Biens.recharger()
	Game.changed.emit()
	_version = int(partie.get("version", 0))
	_empreinte = empreinte_de(lire_fichiers())
	synchro_a = int(Time.get_unix_time_from_system())
	autre = {}
	_ecrire()
	_etat("a_jour", "Partie du compte reprise.")
	# Le décor (maisons, tenue, véhicule) se reconstruit sur la place.
	var scene := get_tree().current_scene
	if scene and scene.name == "Main":
		get_tree().reload_current_scene()


func _periodique() -> void:
	if not connecte():
		if etat in ["a_jour", "hors_ligne", "verification", "envoi"]:
			_etat("expire")
		return
	if etat == "hors_ligne":
		verifier()
	elif etat == "a_jour" and _sale():
		_envoyer(_version)


func _sale() -> bool:
	return empreinte_de(lire_fichiers()) != _empreinte


## Une partie à peine commencée : rien de gagné, rien de misé, aucun bien.
func _vierge() -> bool:
	return Game.won == 0 and Game.staked == 0 and Biens.owned.is_empty()


## Ce que le jeu montre de la partie pour choisir entre deux.
func resume() -> Dictionary:
	return {"credits": Game.credits, "gagne": Game.won, "fortune": Game.credits + Biens.value() - Game.debt}


func appareil() -> String:
	var modele := OS.get_model_name()
	if OS.get_name() == "Android" and modele != "" and modele != "GenericDevice":
		return "Téléphone %s" % modele
	return {"Windows": "PC Windows", "Android": "Téléphone Android", "macOS": "Mac", "Linux": "PC Linux",
		"iOS": "iPhone"}.get(OS.get_name(), OS.get_name())


## Les fichiers de la partie sous dossier : {chemin relatif : contenu}.
static func lire_fichiers(dossier := "user://") -> Dictionary:
	var out := {}
	for f in [SOCLE, BIENS]:
		if FileAccess.file_exists(dossier + f):
			out[f] = FileAccess.get_file_as_string(dossier + f)
	var dir := DirAccess.open(dossier + TIROIRS)
	if dir:
		for f in dir.get_files():
			if f.get_extension() == "save":
				out[TIROIRS + f] = FileAccess.get_file_as_string(dossier + TIROIRS + f)
	return out


## Remplace la partie sous dossier par ces fichiers ; un tiroir absent du compte est retiré.
static func ecrire_fichiers(fichiers: Dictionary, dossier := "user://") -> void:
	DirAccess.make_dir_recursive_absolute(dossier + TIROIRS)
	var dir := DirAccess.open(dossier + TIROIRS)
	if dir:
		for f in dir.get_files():
			if f.get_extension() == "save" and not fichiers.has(TIROIRS + f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(dossier + TIROIRS + f))
	for f in [SOCLE, BIENS]:
		if not fichiers.has(f) and FileAccess.file_exists(dossier + f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dossier + f))
	for chemin in fichiers:
		var c := str(chemin)
		# Rien d'autre que les fichiers de la partie, et jamais hors du dossier.
		if ".." in c or not (c in [SOCLE, BIENS] or (c.begins_with(TIROIRS) and c.get_extension() == "save" and c.count("/") == 1)):
			continue
		var f := FileAccess.open(dossier + c, FileAccess.WRITE)
		if f:
			f.store_string(str(fichiers[chemin]))


static func empreinte_de(fichiers: Dictionary) -> String:
	var cles := fichiers.keys()
	cles.sort()
	var texte := ""
	for k in cles:
		texte += "%s\n%d\n%s\n" % [k, str(fichiers[k]).length(), fichiers[k]]
	return texte.sha256_text()


# --- Le réseau -------------------------------------------------------------------------------

func _rpc(fonction: String, corps: Dictionary) -> Dictionary:
	corps["p_jeton"] = _jeton
	return await _http(SUPABASE + fonction, ["Content-Type: application/json", "apikey: " + CLE_PUBLIQUE],
		JSON.stringify(corps))


## {code, corps} ; code 0 si rien n'est revenu.
func _http(adresse: String, entetes: Array, corps: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	if http.request(adresse, PackedStringArray(entetes + ["User-Agent: Smarves"]), HTTPClient.METHOD_POST, corps) != OK:
		http.queue_free()
		return {"code": 0, "corps": null}
	var r: Array = await http.request_completed
	http.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "corps": null}
	return {"code": r[1], "corps": JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())}


## Une réponse de la base exploitable ; sinon l'état dit pourquoi, et c'est faux.
func _reponse_valable(r: Dictionary) -> bool:
	if r.code == 0:
		_etat("hors_ligne")
		return false
	if r.code != 200 or not r.corps is Dictionary:
		_etat("hors_ligne")
		print_verbose("Compte : réponse %d" % r.code)
		return false
	if r.corps.get("erreur", "") == "jeton":
		_jeton = ""
		_expire = 0
		_ecrire()
		_etat("expire")
		return false
	return true


# --- Les petites pièces ----------------------------------------------------------------------

func _etat(e: String, m := "") -> void:
	etat = e
	message = m
	change.emit()


func _echec(m: String) -> void:
	_arreter_fil()
	_attente = {}
	_etat("erreur", m)


func _lire() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FICHIER) != OK:
		return
	_jeton = str(cfg.get_value("compte", "jeton", ""))
	_expire = int(cfg.get_value("compte", "expire", 0))
	nom = str(cfg.get_value("compte", "nom", ""))
	joueur_id = str(cfg.get_value("compte", "id", ""))
	_version = int(cfg.get_value("partie", "version", 0))
	_empreinte = str(cfg.get_value("partie", "empreinte", ""))
	synchro_a = int(cfg.get_value("partie", "synchro", 0))
	var c = cfg.get_value("pyramides", "clients", {})
	_clients = c if c is Dictionary else {}


func _ecrire() -> void:
	if _essai != "":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("compte", "jeton", _jeton)
	cfg.set_value("compte", "expire", _expire)
	cfg.set_value("compte", "nom", nom)
	cfg.set_value("compte", "id", joueur_id)
	cfg.set_value("partie", "version", _version)
	cfg.set_value("partie", "empreinte", _empreinte)
	cfg.set_value("partie", "synchro", synchro_a)
	cfg.set_value("pyramides", "clients", _clients)
	cfg.save(FICHIER)


static func _hasard() -> String:
	return _b64url(Crypto.new().generate_random_bytes(32))


static func _b64url(octets: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(octets).replace("+", "-").replace("/", "_").replace("=", "")


static func _corps_du_jeton(jeton: String) -> Dictionary:
	var p := jeton.get_slice(".", 1).replace("-", "+").replace("_", "/")
	while p.length() % 4 != 0:
		p += "="
	var d = JSON.parse_string(Marshalls.base64_to_raw(p).get_string_from_utf8())
	return d if d is Dictionary else {}


static func _requete(q: Dictionary) -> String:
	var parts: Array = []
	for k in q:
		parts.append("%s=%s" % [str(k).uri_encode(), str(q[k]).uri_encode()])
	return "&".join(parts)


static func _params(q: String) -> Dictionary:
	var out := {}
	for part in q.split("&", false):
		out[part.get_slice("=", 0).uri_decode()] = part.get_slice("=", 1).replace("+", " ").uri_decode() if "=" in part else ""
	return out


## Les captures montrent la rubrique du compte dans chacun de ses états, sans réseau.
func _mise_en_scene(e: String) -> void:
	nom = "Guillaume"
	joueur_id = "essai"
	synchro_a = int(Time.get_unix_time_from_system()) - 120
	etat = e
	match e:
		"connexion":
			message = "Terminez la connexion dans le navigateur, puis revenez ici."
		"choix":
			autre = {"version": 7, "resume": {"credits": 18450, "gagne": 96200, "fortune": 61300},
				"appareil": "Téléphone Android", "maj": int(Time.get_unix_time_from_system()) - 3 * 3600}
		"erreur":
			message = "Pyramides ne répond pas. Vérifiez la connexion à Internet."
