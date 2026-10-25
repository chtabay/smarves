extends Node
## La partie réseau du pilote (scripts/socle/pilote.gd), seulement avec « --pilote » : le jeu d'un pensionnaire
## lancé sans écran par la tâche GitHub (.github/workflows/pilote.yml). Il parle à la fonction doublures
## (route « pilote », docs/PENSIONNAIRES.md) :
## - pilote_etat : le nom et le solde du pensionnaire ; la partie s'ouvre sur la place avec ce solde ;
## - pilote_attendre : le geste suivant de son assistant (la fonction le fait attendre vingt secondes au
##   plus), avec la position du corps ;
## - pilote_vue : ce que le jeu montre après le geste, les phrases dites, et ce que les jeux ont fait
##   bouger dans la poche, que la fonction porte au solde du pensionnaire (il fait foi) ;
## - pilote_pas : la position du corps en marche, pour que le village le voie.
##
## Trois variables d'environnement : SMARVES_PILOTE_URL (la fonction), SMARVES_PILOTE_JETON (le jeton de la
## tâche) et SMARVES_PENSIONNAIRE (son identifiant).

const PAS := 1.0
const ESSAIS_MAX := 30

var url := ""
var jeton := ""
var pensionnaire := ""
var _n := 0
## Le dernier geste reçu (son numéro à la fonction).
var _dernier := 0
var _poche := 0
var _pas_a := 0.0
var _dernier_pas := Vector3.INF
var _en_marche := false


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
	_poche = Game.credits
	_dernier = int(e.get("n", 0))
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
		var bouge := Game.credits - _poche
		if bouge != 0:
			corps["argent"] = {"cle": "p%s:%d:%d" % [pensionnaire.right(8), int(Time.get_unix_time_from_system()), _n], "montant": bouge}
		_n += 1
		corps.merge(_ou())
		var v := await _appeler("pilote_vue", corps)
		if v.has("solde"):
			# Le solde du serveur fait foi : un mouvement refusé repart de la poche.
			Game.credits = int(v.solde)
			_poche = Game.credits


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
