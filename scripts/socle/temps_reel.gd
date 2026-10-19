class_name TempsReel
extends Node
## Un canal Supabase Realtime, sur WebSocketPeer (fiche « se croiser », lot 1) : rejoindre un canal
## public, y diffuser et en recevoir des messages. Le protocole est celui de Phoenix (version 1.0.0, en
## JSON) : on rejoint par « phx_join », on diffuse par « broadcast », on dit qu'on est là toutes les
## 25 s par un « heartbeat » sur le sujet « phoenix ». Rien d'autre : ni Presence, ni changements de la
## base. Une coupure se rattrape seule, après 1 s, puis 2, 4… jusqu'à 30 s.
##
## Pas d'ENet ni d'UDP (docs/SUITE.md) : WebSocketPeer marche pareil sur PC, sur téléphone et dans un
## navigateur.

## Le canal est rejoint : les envois partent.
signal rejoint
## Un message diffusé par un autre : son événement (« pos »…) et ce qu'il porte.
signal recu(evenement: String, donnees: Dictionary)
## Le canal est perdu (coupure, refus) ; il se reprend seul tant qu'on ne l'a pas fermé.
signal perdu

const ADRESSE := "wss://alvxrjftenialifyktyz.supabase.co/realtime/v1/websocket"
const BATTEMENT := 25.0
const ATTENTE_MAX := 30.0

## L'adresse et la clé, réglables pour les essais.
var adresse := ADRESSE
var cle := ""
## Le nom du canal (sans le préfixe « realtime: »), vide quand on n'en veut pas.
var canal := ""
var est_rejoint := false

var _ws: WebSocketPeer
var _ref := 0
var _join_ref := ""
var _battement := 0.0
var _attente := 0.0
var _delai := 1.0
var _etat := WebSocketPeer.STATE_CLOSED


## Rejoint ce canal (quitte celui d'avant).
func ouvrir(nom: String) -> void:
	if nom == canal and _ws != null:
		return
	fermer()
	canal = nom
	_delai = 1.0
	_connecter()


## Quitte le canal et ferme la connexion.
func fermer() -> void:
	if _ws != null:
		if est_rejoint:
			_ws.send_text(JSON.stringify(message("realtime:" + canal, "phx_leave", {}, _suivant(), _join_ref)))
		_ws.close()
	_ws = null
	canal = ""
	est_rejoint = false
	_etat = WebSocketPeer.STATE_CLOSED


## Diffuse un message aux autres membres du canal (pas à soi). Faux s'il n'est pas parti.
func envoyer(evenement: String, donnees: Dictionary) -> bool:
	if not est_rejoint:
		return false
	return _ws.send_text(JSON.stringify(message("realtime:" + canal, "broadcast",
		{"type": "broadcast", "event": evenement, "payload": donnees}, _suivant(), _join_ref))) == OK


func _connecter() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 18
	est_rejoint = false
	var url := "%s?apikey=%s&vsn=1.0.0" % [adresse, cle.uri_encode()]
	if _ws.connect_to_url(url) != OK:
		_ws = null
		_attente = _delai


func _process(delta: float) -> void:
	if canal == "":
		return
	if _ws == null:
		_attente -= delta
		if _attente <= 0.0:
			_connecter()
		return
	_ws.poll()
	var e := _ws.get_ready_state()
	if e == WebSocketPeer.STATE_OPEN and _etat != WebSocketPeer.STATE_OPEN:
		_join_ref = _suivant()
		_ws.send_text(JSON.stringify(message("realtime:" + canal, "phx_join", rejoindre_config(), _join_ref, _join_ref)))
		_battement = BATTEMENT
	_etat = e
	if e == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count() > 0:
			_lire(_ws.get_packet().get_string_from_utf8())
		_battement -= delta
		if _battement <= 0.0:
			_battement = BATTEMENT
			_ws.send_text(JSON.stringify(message("phoenix", "heartbeat", {}, _suivant())))
	elif e == WebSocketPeer.STATE_CLOSED:
		_couper()


func _lire(texte: String) -> void:
	var m := lire(texte)
	if m.is_empty() or (m.topic != "realtime:" + canal):
		return
	match m.event:
		"phx_reply":
			if m.ref == _join_ref and not est_rejoint:
				if m.payload.get("status", "") == "ok":
					est_rejoint = true
					_delai = 1.0
					rejoint.emit()
				else:
					print_verbose("TempsReel : refusé, %s" % [m.payload])
					_couper()
		"broadcast":
			var d = m.payload.get("payload", {})
			if d is Dictionary:
				recu.emit(str(m.payload.get("event", "")), d)
		"phx_error", "phx_close":
			_couper()


func _couper() -> void:
	var etait := est_rejoint
	if _ws != null:
		_ws.close()
	_ws = null
	est_rejoint = false
	_etat = WebSocketPeer.STATE_CLOSED
	_attente = _delai
	_delai = minf(_delai * 2.0, ATTENTE_MAX)
	if etait:
		perdu.emit()


func _suivant() -> String:
	_ref += 1
	return str(_ref)


func _exit_tree() -> void:
	fermer()


# --- Le protocole, à part pour les essais -----------------------------------------------------

## Un message de Phoenix.
static func message(topic: String, event: String, payload: Dictionary, ref: String, join_ref := "") -> Dictionary:
	var m := {"topic": topic, "event": event, "payload": payload, "ref": ref}
	if join_ref != "":
		m.join_ref = join_ref
	return m


## Ce qu'on demande en rejoignant : la diffusion seule, sans écho, sur un canal public.
static func rejoindre_config() -> Dictionary:
	return {"config": {"broadcast": {"ack": false, "self": false}, "presence": {"key": "", "enabled": false},
		"postgres_changes": [], "private": false}}


## Un message reçu : {topic, event, payload, ref}, ou {} s'il ne se lit pas.
static func lire(texte: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(texte) != OK:
		return {}
	var m = json.data
	if not m is Dictionary or not m.get("topic") is String or not m.get("event") is String:
		return {}
	var p = m.get("payload", {})
	return {"topic": m.topic, "event": m.event, "payload": p if p is Dictionary else {},
		"ref": str(m.ref) if m.get("ref") != null else ""}
