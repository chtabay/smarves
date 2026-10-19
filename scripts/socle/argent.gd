extends Node
## L'argent tenu par le serveur (autoload « Argent », docs/ARGENT.md) : avec un compte, les crédits du
## joueur ont aussi un solde au serveur (fonctions public.smarves_argent*), avec le journal de tous les
## mouvements. C'est le socle du change de Casino Minuit, et la première protection de l'argent de Smarves.
##
## Les jeux continuent de tourner dans Godot, hors ligne compris : ils font bouger Game.credits comme
## avant. Ce fichier rapproche, de temps en temps, la poche de l'appareil et le solde du serveur :
## - la première fois, le solde est ouvert avec ce que l'appareil a en poche (une seule fois par compte ;
##   s'il l'est déjà, par un autre appareil, l'appareil se range au solde du serveur) ;
## - ensuite, ce que les jeux ont fait bouger depuis le dernier rapprochement part en un mouvement
##   « jeu », avec une clé tirée ici ; hors ligne, il attend dans la file et partira plus tard, sous la
##   même clé : le serveur ne le compte qu'une fois, même envoyé deux fois ;
## - enfin le jeu se range au solde du serveur, qui fait foi : ce qu'un autre appareil ou Casino Minuit y
##   a fait bouger arrive dans la poche, et ce que le serveur a refusé en repart.
##
## Ce qu'il faut pour cela (le solde de référence, la file) est rangé dans la partie elle-même, dans le
## tiroir « _argent » : il part au compte avec elle, et un appareil qui reprend la partie du compte reprend
## aussi sa file, que les clés rendent sans danger à rejouer.
##
## Tant que la base n'a pas ces fonctions (la migration attend l'accord de Guillaume), le serveur répond
## « fonction inconnue » : le jeu le note, reste local, et ne dit rien au joueur. Sans compte, rien de ce
## fichier ne s'exécute.

signal change

## Le tiroir de la partie où vit l'état de l'argent.
const TIROIR := "_argent"
const SOURCE := "smarves"
## Un rapprochement au plus par période, quand le compte est à jour.
const PERIODE := 60.0
## La base n'a pas les fonctions : on réessaie au plus toutes les trente minutes.
const REESSAI_ABSENT := 1800.0
## Ce que le serveur accepte en un mouvement, et pour ouvrir le solde.
const MAX_MONTANT := 1000000000

## « local » (sans compte, ou pas encore rapproché), « rapprochement », « a_jour », « hors_ligne » (la
## file attend), « absent » (la base n'a pas encore l'argent : tout reste local).
var etat := "local"
## Le dernier solde lu au serveur (-1 : jamais lu).
var solde := -1
## Ce que le serveur laisse encore passer aujourd'hui par source plafonnée : {source: {entree, sortie}}.
var change_reste := {}
## Un serveur de remplacement (essais) : func(fonction, corps) -> {code, corps}.
var appel: Callable = Callable()

var _en_cours := false
var _absent_a := 0.0
var _minuteur: Timer


func _ready() -> void:
	# Les outils de test (-s) et les captures mènent leur propre partie : jamais le compte.
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	Compte.change.connect(func():
		if Compte.etat == "a_jour":
			rapprocher())
	_minuteur = Timer.new()
	_minuteur.wait_time = PERIODE
	_minuteur.autostart = true
	_minuteur.timeout.connect(func():
		if Compte.etat == "a_jour":
			rapprocher())
	add_child(_minuteur)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if is_inside_tree() and not appel.is_valid() and Compte.etat == "a_jour":
			rapprocher()


func connecte() -> bool:
	return appel.is_valid() or Compte.connecte()


## Des mouvements attendent d'être envoyés.
func en_attente() -> int:
	return (_etat_argent().get("file", []) as Array).size()


## Le solde est ouvert au serveur pour le compte de cette partie.
func ouvert() -> bool:
	var t := _etat_argent()
	return t.has("suivi") and str(t.get("joueur", "")) == Compte.joueur_id


## Un mouvement décidé par le jeu ou par une commune (montant positif : il arrive dans la poche ; négatif :
## il en part), avec sa source (« smarves », l'identifiant d'une commune, « casino_minuit ») et son motif.
## Il est fait tout de suite sur l'appareil, et part au serveur ; s'il y est refusé (plafond du jour), le
## rapprochement le défait. Faux si la poche n'y suffit pas.
func mouvement(source: String, motif: String, montant: int) -> bool:
	if montant == 0 or Game.credits + montant < 0:
		return false
	Game.credits += montant
	var t := _etat_argent()
	if ouvert():
		t.suivi = int(t.suivi) + montant
		_file(t).append({"cle": _cle(), "source": source, "motif": motif, "montant": montant})
	Game.changed.emit()
	if connecte() and etat != "absent":
		rapprocher()
	return true


## Rapproche la poche et le solde du serveur ; ne fait rien sans compte, ou si un rapprochement est en cours.
func rapprocher() -> void:
	if _en_cours or not connecte() or Compte.joueur_id == "":
		return
	if etat == "absent" and Time.get_ticks_msec() / 1000.0 - _absent_a < REESSAI_ABSENT:
		return
	_en_cours = true
	_etat("rapprochement")
	var fin := await _rapprocher()
	_en_cours = false
	_etat(fin)


## Renvoie l'état où l'on finit.
func _rapprocher() -> String:
	var t := _etat_argent()
	# Un autre compte que celui de la partie : son solde de référence ne vaut rien ici.
	if str(t.get("joueur", "")) != Compte.joueur_id:
		t.clear()
		t["joueur"] = Compte.joueur_id
	if not t.has("suivi"):
		var semence := clampi(Game.credits, 0, MAX_MONTANT)
		var r := await _appeler("smarves_argent_ouvrir", {"p_solde": semence, "p_cle": _cle()})
		var e := _refus(r)
		if e != "":
			return e
		t["file"] = []
		solde = int(r.corps.get("solde", 0))
		if r.corps.get("cree", false):
			# Ouvert avec la poche d'avant l'échange : ce qui a bougé depuis part avec le reste.
			t["suivi"] = semence
		else:
			# Déjà ouvert ailleurs : la poche se range au solde du serveur.
			t["suivi"] = Game.credits
			_ranger(t, solde)
		_sauver()
	# Ce que les jeux ont fait bouger depuis le dernier rapprochement.
	var ecart := Game.credits - int(t.suivi)
	while ecart != 0:
		var part := clampi(ecart, -MAX_MONTANT, MAX_MONTANT)
		_file(t).append({"cle": _cle(), "source": SOURCE, "motif": "jeu", "montant": part})
		ecart -= part
	t.suivi = Game.credits
	_sauver()
	var lu := false
	var file := _file(t)
	while not file.is_empty():
		var m: Dictionary = file[0]
		var r := await _appeler("smarves_argent_mouvement", {"p_cle": m.cle, "p_source": m.source,
			"p_motif": m.motif, "p_montant": int(m.montant)})
		if r.code == 400:
			# Le serveur ne veut pas de ce mouvement tel qu'il est écrit : il n'y passera jamais.
			file.pop_front()
			_sauver()
			continue
		var e := _refus(r)
		if e != "":
			return e
		file.pop_front()
		solde = int(r.corps.get("solde", solde))
		lu = true
		if not r.corps.get("ok", false):
			match str(r.corps.get("raison", "")):
				"solde":
					# Les jeux ont perdu plus que ce que le serveur tient (un autre appareil a dépensé
					# entre-temps) : on perd ce qui reste, pas davantage.
					if m.motif == "jeu" and int(m.montant) < 0 and solde > 0:
						file.push_front({"cle": str(m.cle) + ":borne", "source": m.source, "motif": m.motif, "montant": -solde})
				"compte":
					# Le solde a disparu du serveur : on le rouvrira au prochain passage.
					t.erase("suivi")
					file.clear()
					_sauver()
					return "local"
		_sauver()
	if not lu:
		var r := await _appeler("smarves_argent", {})
		var e := _refus(r)
		if e != "":
			return e
		if not r.corps.get("ouvert", false):
			t.erase("suivi")
			_sauver()
			return "local"
		solde = int(r.corps.get("solde", 0))
		var c = r.corps.get("change", {})
		change_reste = c if c is Dictionary else {}
	_ranger(t, solde)
	return "a_jour"


## Le serveur fait foi : la poche prend l'écart entre son solde et celui qu'on croyait lui avoir laissé.
## Ce que les jeux ont fait bouger pendant l'échange reste dans la poche, pour le prochain passage.
func _ranger(t: Dictionary, s: int) -> void:
	var ecart := s - int(t.suivi)
	t.suivi = s
	if ecart == 0:
		_sauver()
		return
	var avant: int = Game.credits
	Game.credits = maxi(0, Game.credits + ecart)
	# La poche ne descend pas sous zéro : ce qui manque partira au prochain passage.
	t.suivi = s + Game.credits - (avant + ecart)
	Game.changed.emit()


## « » si la réponse est exploitable ; sinon l'état où l'on finit (et le serveur n'a rien dit de plus).
func _refus(r: Dictionary) -> String:
	if r.code == 404:
		# PostgREST : « Could not find the function » (PGRST202). La migration n'est pas encore là.
		_absent_a = Time.get_ticks_msec() / 1000.0
		return "absent"
	if r.code != 200 or not r.corps is Dictionary:
		return "hors_ligne"
	if r.corps.get("erreur", "") == "jeton":
		return "local"
	return ""


func _appeler(fonction: String, corps: Dictionary) -> Dictionary:
	if appel.is_valid():
		return await appel.call(fonction, corps)
	return await Compte.appeler(fonction, corps)


func _etat_argent() -> Dictionary:
	return Game.tiroir(TIROIR)


func _file(t: Dictionary) -> Array:
	if not t.get("file") is Array:
		t["file"] = []
	return t.file


func _sauver() -> void:
	Game.save_game()


func _etat(e: String) -> void:
	etat = e
	change.emit()


static func _cle() -> String:
	return Marshalls.raw_to_base64(Crypto.new().generate_random_bytes(18)).replace("+", "-").replace("/", "_").replace("=", "")
