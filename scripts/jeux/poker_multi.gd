extends "res://scripts/poker_panel.gd"
## Le Poker des Ambassadeurs à plusieurs (docs/SUITE.md, section 4, temps réel) : une seule table pour
## tous les joueurs connectés à leur compte Pyramides, tenue par la fonction casino (dépôt chtabay/addict,
## supabase/functions/casino/smarves-poker.js), avec le même moteur que le poker d'Addict. Le serveur
## mélange, donne, fait parler les habitués et règle les pots ; le jeu relit la table chaque seconde et
## rejoue à l'écran ce qui a changé (cartes, mises, tableau, abattage), sur la même table 3D que le solo.
##
## L'argent : en s'asseyant, le joueur pose un tapis pris sur ses crédits ; il le reprend en se levant.
## Les donnes ne touchent que le tapis. S'il disparaît (page fermée, réseau coupé), la chaise se libère
## au bout de 30 s et le croupier garde le tapis : il revient dans les crédits à la prochaine chaise.
##
## Les places : la sienne est toujours la place 0 de l'écran ; les autres tournent autour à partir de
## la place du serveur (6 chaises). Les habitués gardent leur nom ; un joueur prend la chaise de l'un d'eux.

## Les habitués du serveur, par place, et leur figurant dans la salle (casino_interior.gd).
const FIGURANTS := {"Le Commandant": "le-commandant", "Mme Duval": "mme-duval", "Teddy": "teddy",
	"La comtesse Orlov": "comtesse-orlov", "Maître Garnier": "maitre-garnier"}
const SRV_RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SRV_SUITS := ["♠", "♥", "♦", "♣"]
## Le tapis posé en s'asseyant : tout ce qu'on a, jusqu'à 10 000.
const CAVE_MAX := 10000
const RELIRE := 0.8

## Qui est à quelle chaise de la salle, pour les figurants : {place à l'écran: {nom, figurant}}.
signal lineup_changed(places: Dictionary)

var srv := {}
var seated := false
var my_seat := -1
var stack := 0
var _hand_id := -1
var _board_n := 0
var _street := ""
var _busy := false
var _minuteur: Timer
var _options := {}
var _quitter_arme := false
var _lineup_key := ""
## Pour les essais : une vue du serveur posée à la main, sans réseau.
var hors_ligne := false


func _ready() -> void:
	title = "Poker des Ambassadeurs · à plusieurs"
	super()
	for i in range(1, 6):
		seats[i] = {"name": "", "ai": true, "stack": 0}
	_log.text = "Le croupier vous désigne la chaise libre. « Une table pour tous les joueurs du soir. »"
	_minuteur = Timer.new()
	_minuteur.wait_time = RELIRE
	_minuteur.autostart = not hors_ligne
	_minuteur.timeout.connect(func(): _appeler("voir"))
	add_child(_minuteur)
	if not hors_ligne:
		_appeler("voir")
	_render()


# --- Le réseau --------------------------------------------------------------------------------

func _appeler(action: String, args := {}) -> void:
	if _busy or hors_ligne:
		return
	_busy = true
	var r: Dictionary = await Compte.casino(action, args)
	_busy = false
	if not is_inside_tree():
		return
	if r.code == 0:
		_info_text("Le casino ne répond pas. Vérifiez la connexion à Internet.")
		return
	if r.code == 401:
		_log.text = "Votre connexion au compte a expiré : reconnectez-vous dans la bienvenue."
		_minuteur.stop()
		return
	if not r.corps is Dictionary:
		return
	if r.corps.has("error"):
		_log.text = str(r.corps.error)
		if action == "jouer":
			_appeler.call_deferred("voir")
		return
	appliquer(r.corps, action)


func _info_text(t: String) -> void:
	if _info:
		_info.text = t


# --- La table vue du serveur --------------------------------------------------------------------

## Le joueur était déjà assis (une autre fenêtre, ou il revient) : le jeu le sait par la vue.
func appliquer(v: Dictionary, action := "voir") -> void:
	srv = v
	var rendu := int(v.get("rendu", 0))
	if rendu > 0:
		Game.credits += rendu
		Game.changed.emit()
		if action == "partir":
			_log.text = "Le croupier vous rend %s crédits." % Game.fmt(rendu)
		else:
			_log.text = "Le croupier vous rend les %s crédits qu'il vous gardait." % Game.fmt(rendu)
	var was_seated := seated
	seated = v.get("seat") != null
	my_seat = int(v.seat) if seated else -1
	stack = int(round(float(v.get("stack", 0))))
	if was_seated and not seated and action != "partir":
		_log.text = "Le croupier a libéré votre chaise : vous n'avez plus donné de nouvelles."
	if not seated and int(v.get("caisse", 0)) > 0:
		_log.text = "Le croupier vous garde %s crédits : asseyez-vous pour les reprendre." % Game.fmt(int(v.caisse))
	_lire_places(v)
	var pk: Dictionary = v.get("poker", {})
	var h = pk.get("hand")
	var last = v.get("last")
	# La donne qu'on suivait est finie : l'abattage d'abord.
	if _hand_id >= 0 and (h == null or int(h.id) != _hand_id):
		if last is Dictionary and int(last.get("hand", -1)) == _hand_id:
			_abattage(last)
		else:
			in_hand = false
		_hand_id = -1
	if h is Dictionary and seated:
		var me := _moi(h)
		if int(h.id) != _hand_id:
			_nouvelle_donne(h)
		else:
			_suivre(h)
		_options = h.get("options", {}) if h.get("options") is Dictionary else {}
		_waiting_player = not _options.is_empty()
		if _waiting_player:
			_raise_to = clampi(_raise_to, int(_options.minTo), int(_options.maxTo))
		if me.is_empty():
			seats[0].folded = true
	else:
		_waiting_player = false
		_options = {}
		turn = -1
	if not in_hand:
		_raconter_attente(pk)
	_render()


func _moi(h: Dictionary) -> Dictionary:
	for p in h.players:
		if p.get("me", false):
			return p
	return {}


## La place à l'écran d'une place du serveur : la sienne en 0, les autres dans le sens des chaises.
func rel(seat: int) -> int:
	return posmod(seat - (my_seat if my_seat >= 0 else 0), 6)


static func carte(c) -> Dictionary:
	if not c is Dictionary:
		return {"r": 0, "s": 0}
	return {"r": maxi(0, SRV_RANKS.find(str(c.r))), "s": maxi(0, SRV_SUITS.find(str(c.s)))}


## Les noms et les tapis aux six chaises, hors donne : joueurs assis et habitués aux places libres.
func _lire_places(v: Dictionary) -> void:
	var fresh := {}
	for s in v.get("seats", []):
		fresh[rel(int(s.seat))] = {"name": "Vous" if s.get("me", false) else str(s.name), "ai": not s.get("me", false),
			"stack": int(round(float(s.stack))), "human": true}
	for r in v.get("poker", {}).get("regulars", []):
		var i := rel(int(r.seat))
		if not fresh.has(i):
			fresh[i] = {"name": str(r.name), "ai": true, "stack": 0, "human": false}
	for i in 6:
		var f: Dictionary = fresh.get(i, {"name": "", "ai": i != 0, "stack": 0, "human": false})
		seats[i].name = f.name
		seats[i].ai = f.ai if i != 0 else false
		seats[i].human = f.human
		if f.human:
			seats[i].stack = f.stack
	var places := {}
	for i in 6:
		places[i] = {"nom": seats[i].name, "figurant": FIGURANTS.get(seats[i].name, "joueur" if seats[i].get("human", false) else "")}
	var key := JSON.stringify(places)
	if key != _lineup_key:
		_lineup_key = key
		lineup_changed.emit(places)


func _nouvelle_donne(h: Dictionary) -> void:
	_hand_id = int(h.id)
	in_hand = true
	board.clear()
	_board_n = 0
	_street = str(h.street)
	var present := {}
	for p in h.players:
		present[rel(int(p.seat))] = p
	for i in 6:
		var s: Dictionary = seats[i]
		var p = present.get(i)
		# Les cartes des autres restent face cachée : on en pose des fausses, retournées à l'abattage.
		s.cards = [carte(p.cards[0]), carte(p.cards[1])] if p is Dictionary and p.get("cards") is Array else [{"r": 0, "s": 0}, {"r": 1, "s": 1}]
		s.folded = not p is Dictionary or not p.get("in", false)
		s.bet = int(round(float(p.get("street", 0)))) if p is Dictionary else 0
		s.acted = false
	_lire_donne(h)
	Sfx.play("shuffle", -6.0)
	_log.text = "Nouvelle donne. Blindes %d et %d." % [SB, BB]
	hand_started.emit()
	var b: Array = h.get("board", [])
	if not b.is_empty():
		board = b.map(func(c): return carte(c))
		_board_n = board.size()
		board_dealt.emit(board.duplicate())


func _suivre(h: Dictionary) -> void:
	var b: Array = h.get("board", [])
	var street_changed := str(h.street) != _street
	_street = str(h.street)
	_lire_donne(h)
	if street_changed or b.size() > _board_n:
		street_ended.emit()
	if b.size() > _board_n:
		var nouvelles: Array = b.slice(_board_n).map(func(c): return carte(c))
		board = b.map(func(c): return carte(c))
		_board_n = b.size()
		board_dealt.emit(nouvelles)
	_raconter(h)


func _lire_donne(h: Dictionary) -> void:
	pot = int(round(float(h.pot)))
	current_bet = int(round(float(h.level)))
	turn = -1
	for p in h.players:
		var i := rel(int(p.seat))
		var s: Dictionary = seats[i]
		s.bet = int(round(float(p.get("street", 0))))
		s.folded = not p.get("in", false)
		if p.get("turn", false):
			turn = i
		if p.get("button", false):
			dealer = i
		if p.get("me", false):
			player_in = int(round(float(p.committed)))


## Le journal de la donne : la dernière action, dite comme au solo.
func _raconter(h: Dictionary) -> void:
	var log: Array = h.get("log", [])
	if log.is_empty():
		return
	var e: Dictionary = log[-1]
	var who := str(e.get("name", ""))
	if e.has("seat") and rel(int(e.seat)) == 0:
		who = "Vous"
	var vous := who == "Vous"
	var amount := int(round(float(e.get("amount", 0))))
	match str(e.get("kind", "")):
		"fold": _log.text = "Vous vous couchez." if vous else "%s se couche." % who
		"check": _log.text = "Vous parlez." if vous else "%s parle." % who
		"call": _log.text = "Vous suivez." if vous else "%s suit." % who
		"bet": _log.text = ("Vous misez %s." if vous else who + " mise %s.") % Game.fmt(amount)
		"raise": _log.text = ("Vous relancez à %s." if vous else who + " relance à %s.") % Game.fmt(amount)
		"flop", "turn", "river": _log.text = {"flop": "Le flop.", "turn": "Le tournant.", "river": "La rivière."}[str(e.kind)]


func _abattage(last: Dictionary) -> void:
	var shown: Array = last.get("shown", [])
	for x in shown:
		var i := rel(int(x.seat))
		seats[i].cards = [carte(x.cards[0]), carte(x.cards[1])]
		seats[i].folded = false
	if not shown.is_empty():
		var montre := {}
		for x in shown:
			montre[rel(int(x.seat))] = true
		for i in 6:
			if not montre.has(i):
				seats[i].folded = true
	var b: Array = last.get("board", [])
	if b.size() > _board_n:
		street_ended.emit()
		board_dealt.emit(b.slice(_board_n).map(func(c): return carte(c)))
	board = b.map(func(c): return carte(c))
	_board_n = board.size()
	pot = int(round(float(last.get("pot", 0))))
	var net_pot := pot - int(round(float(last.get("rake", 0))))
	var winners: Array = []
	var mine := {}
	for r in last.get("results", []):
		if float(r.get("returned", 0)) > 0:
			winners.append(rel(int(r.seat)))
		if r.get("me", false):
			mine = r
	for s in seats:
		s.bet = 0
	in_hand = false
	turn = -1
	var names: Array = last.get("winners", [])
	var who := " et ".join(names.map(func(n): return str(n)))
	if winners == [0]:
		who = "Vous"
	var verb := "remportez" if winners == [0] else ("remportent" if winners.size() > 1 else "remporte")
	var what := str(last.get("what", "")) if last.get("what") != null else ""
	_log.text = "%s %s %s%s.%s" % [who, verb, Game.fmt(net_pot), (" avec " + what) if what != "" else "",
		(" La maison prend %d." % int(last.rake)) if float(last.get("rake", 0)) > 0 else ""]
	if not winners.is_empty():
		showdown.emit(winners, not shown.is_empty(), net_pot)
	# La donne compte dans la partie comme au solo : misé, rendu (le gain reste sur le tapis).
	if not mine.is_empty():
		var bet := int(round(float(mine.staked)))
		var payout := int(round(float(mine.returned)))
		Game.staked += bet
		Game.won += payout
		Game.changed.emit()
		Sfx.result(bet, payout)


func _raconter_attente(pk: Dictionary) -> void:
	if not seated:
		return
	if pk.get("waiting", false):
		_log.text = "Votre tapis est sous %s : recavez pour être servi." % Game.fmt(CAP)


# --- Les gestes ------------------------------------------------------------------------------------

func cave() -> int:
	return mini(Game.credits, CAVE_MAX)


## « Nouvelle donne » devient « S'asseoir » ou « Recaver » : les donnes partent seules au serveur.
func _new_hand() -> void:
	var c := cave()
	if c < CAP:
		_log.text = "Il faut au moins %s crédits pour poser un tapis." % Game.fmt(CAP)
		return
	if not seated:
		if not Game.spend_chips(c):
			return
		_tapis_pose = c
		_appeler_assis("s-asseoir", c)
	elif srv.get("poker", {}).get("waiting", false):
		var room := int(srv.get("cave", {}).get("stackMax", 20000)) - stack
		c = mini(c, room)
		if c < CAP:
			_log.text = "Votre tapis est déjà assez haut."
			return
		if not Game.spend_chips(c):
			return
		_tapis_pose = c
		_appeler_assis("recaver", c)


var _tapis_pose := 0


## S'asseoir et recaver : les crédits partent avant ; si le serveur refuse, ils reviennent.
func _appeler_assis(action: String, c: int) -> void:
	while _busy:
		await get_tree().process_frame
	_busy = true
	var r: Dictionary = await Compte.casino(action, {"cave": c})
	_busy = false
	if not is_inside_tree():
		return
	if r.code != 200 or not r.corps is Dictionary or r.corps.has("error"):
		Game.credits += _tapis_pose
		Game.changed.emit()
		_tapis_pose = 0
		_log.text = str(r.corps.error) if r.corps is Dictionary and r.corps.has("error") else "Le casino ne répond pas : vos crédits vous sont rendus."
		return
	_tapis_pose = 0
	_log.text = "Vous posez %s crédits devant vous. La donne part quand le croupier est prêt." % Game.fmt(c)
	appliquer(r.corps, action)


func _on_fold() -> void:
	if _waiting_player:
		_jouer("fold")


func _on_call() -> void:
	if _waiting_player:
		_jouer("call" if float(_options.get("toCall", 0)) > 0 else "check")


func _on_raise() -> void:
	if _waiting_player and _options.get("canRaise", false):
		_jouer("raise", _raise_to)


func _adjust_raise(d: int) -> void:
	if _options.is_empty():
		return
	_raise_to = clampi(_raise_to + d * BB, int(_options.minTo), int(_options.maxTo))
	_render()


func _jouer(kind: String, to := -1) -> void:
	_waiting_player = false
	_render()
	var args := {"kind": kind}
	if to >= 0:
		args.to = to
	while _busy:
		await get_tree().process_frame
	_appeler("jouer", args)


func _leave() -> void:
	if not seated or hors_ligne:
		closed.emit()
		return
	if in_hand and not seats[0].get("folded", true) and not _quitter_arme:
		_quitter_arme = true
		_log.text = "Vous êtes dans la donne : Quitter encore pour vous coucher et vous lever."
		return
	_minuteur.stop()
	while _busy:
		await get_tree().process_frame
	await _appeler("partir")
	closed.emit()


# --- L'affichage -----------------------------------------------------------------------------------

func _render_bar() -> void:
	var to_call := int(round(float(_options.get("toCall", 0))))
	var parts: Array[String] = []
	if seated:
		parts.append("Tapis : %s" % Game.fmt(stack))
	if in_hand:
		parts.append("Pot : %s" % Game.fmt(pot))
		if not seats[0].get("folded", false) and seats[0].has("cards"):
			if board.size() >= 3:
				parts.append("votre main : %s" % CATEGORIES[evaluate(seats[0].cards + board)[0]].to_lower())
			parts.append("engagé : %s / %s" % [Game.fmt(player_in), Game.fmt(CAP)])
	var humains := 0
	for s in seats:
		if s.get("human", false):
			humains += 1
	parts.append("%d joueur%s à la table" % [humains, "s" if humains > 1 else ""])
	_info.text = "   ·   ".join(parts)
	_raise_label.text = "Relance à %s" % Game.fmt(_raise_to)
	var acting := _waiting_player and in_hand
	var waiting: bool = srv.get("poker", {}).get("waiting", false)
	_buttons["deal"].visible = not seated or (waiting and not in_hand)
	_buttons["deal"].text = "  S'asseoir  (tapis de %s)  " % Game.fmt(cave()) if not seated else "  Recaver  "
	for k in ["fold", "call", "raise", "less", "more"]:
		_buttons[k].visible = in_hand and seated
		_buttons[k].disabled = not acting
	_buttons["raise"].disabled = not acting or not _options.get("canRaise", false)
	_raise_label.visible = in_hand and seated
	_buttons["call"].text = "Suivre %s" % Game.fmt(to_call) if to_call > 0 else "Parler"


func _render(show_all := false) -> void:
	if embedded:
		_render_bar()
		changed.emit()
	elif _rows.size() == 6:
		super(show_all)
