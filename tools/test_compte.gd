extends SceneTree
## Vérifie le compte sans réseau : godot --headless --path . -s tools/test_compte.gd
## La règle qui décide qui a bougé (envoyer, reprendre, choisir), l'aller-retour des fichiers de la
## partie, l'empreinte, la lecture du jeton, et le retour de Pyramides sur la boucle locale, joué par
## un faux navigateur. Tout se passe dans user://test_compte/ ; la vraie partie n'est pas touchée.

## Chargé après les autoloads, qu'il nomme (Game, Biens).
var COMPTE: GDScript
const DIR := "user://test_compte/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	COMPTE = load("res://scripts/socle/compte.gd")
	_decider()
	_fichiers()
	_jeton()
	await _retour()
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _decider() -> void:
	check(COMPTE.decider(0, 0, true, false) == "envoyer", "compte vide : on envoie")
	check(COMPTE.decider(3, 3, false, false) == "rien", "rien n'a bougé")
	check(COMPTE.decider(3, 3, true, false) == "envoyer", "l'appareil seul a bougé : on envoie")
	check(COMPTE.decider(4, 3, false, false) == "reprendre", "le compte seul a bougé : on reprend")
	check(COMPTE.decider(4, 3, true, false) == "choisir", "les deux ont bougé : le joueur choisit")
	check(COMPTE.decider(4, 0, true, true) == "reprendre", "premier lien, partie neuve ici : on reprend celle du compte")
	check(COMPTE.decider(4, 0, true, false) == "choisir", "premier lien, partie avancée ici : le joueur choisit")


func _fichiers() -> void:
	_vider()
	var partie := {"socle.save": "{\"bourse\":4321}", "smarves_biens.save": "{\"owned\":{}}",
		"communes/smarves.save": "{\"tiroir\":{}}", "communes/liguge.save": "{}"}
	COMPTE.ecrire_fichiers(partie, DIR)
	var relue: Dictionary = COMPTE.lire_fichiers(DIR)
	check(relue == partie, "les fichiers écrits se relisent à l'identique")
	check(COMPTE.empreinte_de(relue) == COMPTE.empreinte_de(partie), "même partie, même empreinte")
	var autre := partie.duplicate()
	autre.erase("communes/liguge.save")
	autre["socle.save"] = "{\"bourse\":5}"
	check(COMPTE.empreinte_de(autre) != COMPTE.empreinte_de(partie), "partie différente, empreinte différente")
	COMPTE.ecrire_fichiers(autre, DIR)
	check(COMPTE.lire_fichiers(DIR) == autre, "reprendre retire le tiroir que le compte n'a pas")
	COMPTE.ecrire_fichiers({"../evade.save": "x", "reglages.cfg": "x", "communes/a/b.save": "x", "socle.save": "{}"}, DIR)
	check(not FileAccess.file_exists("user://evade.save") and not FileAccess.file_exists(DIR + "reglages.cfg"),
		"rien n'est écrit hors des fichiers de la partie")
	check(COMPTE.lire_fichiers(DIR).keys() == ["socle.save"], "seul le socle reste")
	_vider()


func _jeton() -> void:
	var corps := Marshalls.raw_to_base64(JSON.stringify({"sub": "u_1", "name": "Éloïse", "exp": 2000000000}).to_utf8_buffer())
	corps = corps.replace("+", "-").replace("/", "_").replace("=", "")
	var lu: Dictionary = COMPTE._corps_du_jeton("e30." + corps + ".sig")
	check(lu.get("sub") == "u_1" and lu.get("name") == "Éloïse", "le nom se lit dans le jeton, accents compris")
	var p: Dictionary = COMPTE._params("code=abc%2Fd&state=x+y&iss=https%3A%2F%2Fp")
	check(p == {"code": "abc/d", "state": "x y", "iss": "https://p"}, "les paramètres du retour se décodent")
	check(COMPTE._b64url(PackedByteArray([251, 255, 0])) == "-_8A", "base64 pour adresses")


## Le fil écoute comme pendant une vraie connexion ; un faux navigateur revient avec le code.
func _retour() -> void:
	var compte: Node = COMPTE.new()
	root.add_child(compte)
	var serveur := TCPServer.new()
	check(serveur.listen(47819, "127.0.0.1") == OK, "le port de retour s'ouvre")
	compte._fil = Thread.new()
	compte._fil.start(compte._ecouter.bind(serveur))
	var http := HTTPClient.new()
	http.connect_to_host("127.0.0.1", 47819)
	while http.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		http.poll()
		await process_frame
	http.request(HTTPClient.METHOD_GET, "/retour?code=le-code&state=l-etat", [])
	var page := PackedByteArray()
	var debut := Time.get_ticks_msec()
	while Time.get_ticks_msec() - debut < 5000:
		http.poll()
		if http.get_status() == HTTPClient.STATUS_BODY:
			page += http.read_response_body_chunk()
		elif http.get_status() != HTTPClient.STATUS_REQUESTING and not page.is_empty():
			break
		await process_frame
	check(http.get_response_code() == 200 and "revenir au jeu" in page.get_string_from_utf8(), "le navigateur reçoit la page de retour")
	compte._fil.wait_to_finish()
	check(compte._fil_retour == {"code": "le-code", "etat": "l-etat"}, "le jeu reçoit le code et l'état")
	compte.queue_free()


func _vider() -> void:
	for f in COMPTE.lire_fichiers(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
