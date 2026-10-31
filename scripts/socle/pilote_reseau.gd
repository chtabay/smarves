extends Node
## La partie réseau du pilote (scripts/socle/pilote.gd), seulement avec « --pilote » : le jeu d'un pensionnaire
## lancé sans écran par la tâche GitHub (.github/workflows/pilote.yml). Il parle à la fonction doublures
## (route « pilote », docs/PENSIONNAIRES.md) :
## - pilote_etat : le nom et le solde du pensionnaire ; la partie s'ouvre sur la place avec ce solde ;
## - pilote_attendre : le geste suivant de son assistant (la fonction le fait attendre vingt secondes au
##   plus), avec la position du corps ;
## - pilote_vue : ce que le jeu montre après le geste, les phrases dites, et ce que les jeux ont fait
##   bouger dans la poche, que la fonction porte au solde du pensionnaire (il fait foi) ;
## - pilote_pas : la position du corps en marche, pour que le village le voie ;
## - pilote_image : l'image de son écran pour son créateur (ses dernières vues du jeu), prise après avoir
##   répondu, pendant que l'assistant réfléchit : au changement de lieu, sinon au plus une par VUE_GARDEE.
##
## Trois variables d'environnement : SMARVES_PILOTE_URL (la fonction), SMARVES_PILOTE_JETON (le jeton de la
## tâche) et SMARVES_PENSIONNAIRE (son identifiant).

const PAS := 1.0
const ESSAIS_MAX := 30
## Une image pour ses dernières vues du jeu au plus toutes les tant de secondes (les pages qui les montrent se
## relisent toutes les trente), et à chaque changement de lieu ou de caméra.
const VUE_GARDEE := 30.0

var url := ""
var jeton := ""
var pensionnaire := ""
var _n := 0
## Le dernier geste reçu (son numéro à la fonction).
var _dernier := 0
var _poche := 0
var _gains := 0
var _pas_a := 0.0
var _dernier_pas := Vector3.INF
var _en_marche := false
## La dernière image envoyée pour ses vues : quand, et de quel lieu et de quelle caméra.
var _vue_a := -INF
var _vue_de := ""
## Ses dettes (Crédit Smarvois, autres prêteurs) : le jeu du pilote ne sauvegarde pas sa partie, et un
## redémarrage les effaçait. Elles se gardent dans son dossier de partie (user://), que la tâche reprend.
const DETTES := "user://pilote_dettes.json"
var _dettes_ecrites := ""


func _ready() -> void:
	url = OS.get_environment("SMARVES_PILOTE_URL")
	jeton = OS.get_environment("SMARVES_PILOTE_JETON")
	pensionnaire = OS.get_environment("SMARVES_PENSIONNAIRE")
	if url == "" or jeton == "" or pensionnaire == "":
		push_error("pilote : SMARVES_PILOTE_URL, SMARVES_PILOTE_JETON et SMARVES_PENSIONNAIRE sont requis")
		get_tree().quit(2)
		return
	_demarrer.call_deferred()


func _demarrer() -> void:
	var e := await _appeler("pilote_etat", {})
	if not e.get("ok", false):
		print("pilote : pas de pensionnaire à tenir (%s)" % str(e.get("raison", "?")))
		get_tree().quit(0)
		return
	Game.saving_enabled = false
	Game.welcomed = true
	Game.credits = int(e.get("solde", 0))
	Game.won = maxi(int(e.get("gagne", 0)), 0)
	_reprendre_dettes()
	Game.changed.connect(_garder_dettes)
	_poche = Game.credits
	_gains = Game.won
	_dernier = int(e.get("n", 0))
	if str(e.get("compte", "")) != "":
		# Il joue sous son nom, comme un joueur connecté : les autres le voient, il les voit, il s'assoit aux
		# tables à plusieurs. Son argent passe par la fonction (pilote_vue), pas par Argent.
		Argent.appel = func(_f: String, _c: Dictionary) -> Dictionary: return {"code": 404, "corps": {}}
		Compte.pilote(str(e.compte))
	print("pilote : %s, %d crédits" % [str(e.get("nom", "")), Game.credits])
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	while get_parent().joueur() == null:
		await get_tree().create_timer(0.3).timeout
	_boucle()


func _boucle() -> void:
	var rates := 0
	while true:
		var demande := {"n": _dernier}
		demande.merge(_ou())
		var r := await _appeler("pilote_attendre", demande)
		if r.get("fin", false):
			print("pilote : fin (%s)" % str(r.get("raison", "")))
			get_tree().quit(0)
			return
		if not r.get("ok", false):
			rates += 1
			if rates > ESSAIS_MAX:
				get_tree().quit(1)
				return
			await get_tree().create_timer(2.0).timeout
			continue
		rates = 0
		if not r.get("geste") is Dictionary:
			continue
		_dernier = int(r.get("n", _dernier + 1))
		_en_marche = true
		var res: Dictionary = await get_parent().geste(r.geste)
		_en_marche = false
		var corps := {"n": _dernier, "resultat": res, "paroles": get_parent().paroles.duplicate()}
		get_parent().paroles.clear()
		# Une main en cours (le blackjack) : sa mise ne part au serveur qu'une fois la main jouée. Si le jeu
		# s'arrête avant (relais de la tâche, repos), la mise n'a jamais quitté son solde : elle lui reste.
		var engage := _mise_engagee()
		var bouge := Game.credits + engage - _poche
		# Ses gains, comme ceux d'un joueur (Game.won) : le « gagné au jeu » ne baisse pas quand il perd.
		var gain := maxi(Game.won - _gains, 0)
		if bouge != 0 or gain > 0:
			corps["argent"] = {"cle": "p%s:%d:%d" % [pensionnaire.right(8), int(Time.get_unix_time_from_system()), _n], "montant": bouge, "gain": gain}
		_n += 1
		corps.merge(_ou())
		var poche_envoyee := Game.credits + engage
		var gains_envoyes := Game.won
		var v := await _appeler("pilote_vue", corps)
		if v.has("solde"):
			# Le solde du serveur fait foi : un mouvement refusé repart de la poche. Ce que le jeu a versé
			# pendant l'appel (une prime qui tombe à la sortie d'une épreuve) n'est pas encore au serveur :
			# il reste dans la poche, et part avec la vue suivante.
			_poche = int(v.solde)
			Game.credits = _poche + Game.credits - poche_envoyee
			_gains = gains_envoyes
		await _garder_vue(res)


## Ce qui est sur le tapis d'une main pas encore jouée (les tables du groupe « mises_engagees »).
func _mise_engagee() -> int:
	var t := 0
	for n in get_tree().get_nodes_in_group("mises_engagees"):
		if n.has_method("mise_engagee"):
			t += maxi(int(n.mise_engagee()), 0)
	return t


func _reprendre_dettes() -> void:
	var f := FileAccess.open(DETTES, FileAccess.READ)
	if f == null:
		return
	var lu = JSON.parse_string(f.get_as_text())
	if not (lu is Dictionary) or not (lu.get("dettes") is Dictionary):
		return
	var d := {}
	for k in lu.dettes:
		if int(lu.dettes[k]) > 0:
			d[str(k)] = int(lu.dettes[k])
	Game.debts = d
	Game.loans_taken = int(lu.get("prets", 0))
	_dettes_ecrites = JSON.stringify({"dettes": Game.debts, "prets": Game.loans_taken})
	print("pilote : dettes reprises (%d)" % Game.debt)


func _garder_dettes() -> void:
	var t := JSON.stringify({"dettes": Game.debts, "prets": Game.loans_taken})
	if t == _dettes_ecrites:
		return
	var f := FileAccess.open(DETTES, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(t)
	_dettes_ecrites = t


## Ses dernières vues du jeu, pour son créateur : l'assistant a déjà sa réponse, l'image se prend pendant qu'il
## réfléchit. Celle d'un « regarder » sert telle quelle ; sinon une image neuve, si le lieu ou la caméra a
## changé ou si la dernière a plus de VUE_GARDEE secondes.
func _garder_vue(res: Dictionary) -> void:
	var lieu := str(_ou().get("lieu", ""))
	var de := "%s/%s" % [lieu, get_parent().image_vue()]
	var t := Time.get_ticks_msec() / 1000.0
	if res.has("image"):
		_vue_a = t
		_vue_de = de
		return
	if de == _vue_de and t - _vue_a < VUE_GARDEE:
		return
	var img: Dictionary = await get_parent().image_et_camera()
	if img.is_empty():
		return
	_vue_a = t
	_vue_de = de
	img.merge(_ou())
	await _appeler("pilote_image", img)


func _process(_delta: float) -> void:
	# En marche, le village le voit avancer : une position par seconde, seulement s'il a bougé.
	var t := Time.get_ticks_msec() / 1000.0
	if not _en_marche or t - _pas_a < PAS:
		return
	var j: Node3D = get_parent().joueur()
	if j == null or j.global_position.distance_to(_dernier_pas) < 0.2:
		return
	_pas_a = t
	_dernier_pas = j.global_position
	_appeler("pilote_pas", _ou())


## Où est le corps : le lieu et la position dans la scène.
func _ou() -> Dictionary:
	var j: Node3D = get_parent().joueur()
	var o := {"lieu": get_parent()._nom_du_lieu(get_parent().scene())}
	if j:
		o["x"] = snappedf(j.global_position.x, 0.01)
		o["y"] = snappedf(j.global_position.y, 0.01)
		o["z"] = snappedf(j.global_position.z, 0.01)
	return o


func _appeler(action: String, args: Dictionary) -> Dictionary:
	var h := HTTPRequest.new()
	h.timeout = 40.0
	add_child(h)
	var corps := JSON.stringify({"action": action, "pensionnaire": pensionnaire, "args": args})
	var err := h.request(url, ["content-type: application/json", "authorization: Bearer " + jeton], HTTPClient.METHOD_POST, corps)
	if err != OK:
		h.queue_free()
		return {"ok": false, "raison": "requete"}
	var rep: Array = await h.request_completed
	h.queue_free()
	if rep[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "raison": "reseau"}
	var lu = JSON.parse_string((rep[3] as PackedByteArray).get_string_from_utf8())
	if not lu is Dictionary:
		return {"ok": false, "raison": "illisible %d" % rep[1]}
	if rep[1] == 401:
		lu["fin"] = true
	return lu
