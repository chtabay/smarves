extends "res://scripts/poker_panel.gd"
## Le Poker des Ambassadeurs à plusieurs (docs/SUITE.md, section 4, temps réel) : une seule table pour
## tous les joueurs connectés à leur compte Pyramides, tenue par la fonction casino (dépôt chtabay/addict,
## supabase/functions/casino/smarves-poker.js), avec le même moteur que le poker d'Addict. Le serveur
## mélange, donne, fait parler les habitués et règle les pots ; le jeu relit la table chaque seconde et
## rejoue à l'écran ce qui a changé (cartes, mises, tableau, abattage), sur la même table 3D que le solo.
##
## L'argent, comme au solo : rien n'est pris d'avance. Le tapis que voit la table n'est que l'image des
## crédits du joueur (jusqu'à 10 000) ; chaque mise part des crédits quand elle part au pot, et la donne
## finie, ce qu'elle rend y revient. Se lever ne déplace rien ; disparaître (page fermée, réseau coupé)
## libère la chaise au bout de dix minutes ; entre-temps le croupier couche l'absent à chaque donne. `rendu` ne sert plus qu'à
## remettre ce que la première version avait pris à l'entrée : le serveur le rend au premier passage.
##
## Les places : la sienne est toujours la place 0 de l'écran ; les autres tournent autour à partir de
## la place du serveur (6 chaises). Les habitués gardent leur nom ; un joueur prend la chaise de l'un d'eux.
##
## L'encart : à droite de l'écran, qui est à la table, avec quoi devant lui et son dernier geste dans la
## donne, le donneur et celui qui parle ; en tête, ses crédits, le pot et le plafond d'une donne. Il se
## replie d'un clic en une ligne, et vient replié sur un écran étroit (téléphone).
##
## Les tarifs (socle 1.7) : le serveur est seul maître des blindes et du plafond de chaque table, et les
## renvoie dans chaque vue (`table` : id, nom, blindes, plafond). Une commune qui a une table à elle
## l'annonce par configurer_table("cloue:poker-cave", 125, 250, 10000) avant que le panneau entre dans
## la scène ; si le serveur ne confirme pas exactement cette table et ces tarifs, le panneau refuse de
## jouer, le dit, et se lève s'il était assis. Sans configurer_table, il attend la table du serveur aux
## tarifs des Ambassadeurs, et une vue qui ne dit pas sa table (un serveur d'avant) passe.

## Les habitués du serveur, par place, et leur figurant dans la salle (casino_interior.gd).
## Ceux de la table du Miosson (poker:miosson) ont d'autres noms, donnés par le serveur.
const FIGURANTS := {"Le Commandant": "le-commandant", "Mme Duval": "mme-duval", "Teddy": "teddy",
	"La comtesse Orlov": "comtesse-orlov", "Maître Garnier": "maitre-garnier",
	"Le père Rigaud": "pere-rigaud", "Mme Pacaud": "mme-pacaud", "Jordan": "jordan", "Odile": "odile",
	"M. Lebreton": "m-lebreton"}
const SRV_RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SRV_SUITS := ["♠", "♥", "♦", "♣"]
## Le tapis que la table montre pour soi : ses crédits, jusqu'à 10 000 (ou au plafond de la table, s'il
## est plus haut).
const CAVE_MAX := 10000
const TABLE_DEFAUT := "poker:ambassadeurs"
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
## Ce que le serveur me voyait de disponible (tapis moins l'engagé) à la dernière vue : la différence
## d'une vue à l'autre est ce qui part des crédits (mise) ou y revient (gain). -1 : pas de repère.
var _dispo := -1
## Pour les essais : une vue du serveur posée à la main, sans réseau.
var hors_ligne := false
## La table du serveur (SMARVES.tables) : vide, le Poker des Ambassadeurs ; un paquet de commune y met
## l'une des siennes (« minuit:poker-1 ») et son titre.
var table_id := ""
## La table et les tarifs annoncés par configurer_table() : le serveur doit les confirmer. Vide : pas
## d'annonce, la table du serveur aux tarifs par défaut.
var attendu := {}
## Le serveur n'a pas confirmé la table ou ses tarifs : on ne joue pas.
var refusee := false
var _encart: PanelContainer
var _encart_texte: RichTextLabel
var _encart_ouvert := true


func _ready() -> void:
	if table_id == "":
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
	if embedded and get_parent() is Control:
		_batir_encart(get_parent())
	_render()


# --- Le réseau --------------------------------------------------------------------------------

func _appeler(action: String, args := {}) -> void:
	if _busy or hors_ligne:
		return
	_busy = true
	var r: Dictionary = await Compte.casino(action, avec_table(args))
	_busy = false
	if not is_inside_tree():
		return
	if r.code == 0:
		_info_text("Le casino ne répond pas. Vérifiez la connexion à Internet.")
		return
	if r.code == 401:
		_log.text = "Votre connexion au compte a expiré : reconnectez-vous dans les réglages."
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


## Une table de commune à ses tarifs (socle 1.7) : son identifiant chez le serveur, petite et grosse
## blinde, plafond par donne. À appeler avant que le panneau entre dans la scène. Rend false, sans rien
## changer, pour un identifiant vide ou des tarifs incohérents.
func configurer_table(id: String, petite: int, grosse: int, plafond: int) -> bool:
	if id.strip_edges() == "" or not configurer_blindes(petite, grosse, plafond):
		return false
	table_id = id
	attendu = {"id": id, "blindes": [petite, grosse], "plafond": plafond}
	return true


## La table et les tarifs que le serveur doit renvoyer.
func tarif_attendu() -> Dictionary:
	if not attendu.is_empty():
		return attendu
	return {"id": table_id if table_id != "" else TABLE_DEFAUT, "blindes": [SB, BB], "plafond": CAP}


## Le serveur confirme-t-il la table et ses tarifs ? Une vue sans `table` (un serveur d'avant) ne passe
## que si la commune n'a rien annoncé.
func tarif_confirme(v: Dictionary) -> bool:
	var t = v.get("table")
	if not t is Dictionary:
		return attendu.is_empty()
	var a := tarif_attendu()
	var b = t.get("blindes")
	return str(t.get("id", "")) == a.id and b is Array and b.size() == 2 \
		and int(b[0]) == int(a.blindes[0]) and int(b[1]) == int(a.blindes[1]) and int(t.get("plafond", -1)) == int(a.plafond)


## La table n'est pas celle qu'on attend : on ne joue pas, on le dit, et on se lève si l'on était assis.
func _refuser(v: Dictionary) -> void:
	refusee = true
	_waiting_player = false
	if _minuteur:
		_minuteur.stop()
	var a := tarif_attendu()
	_log.text = "Le casino ne confirme pas cette table (%s, blindes %s/%s, %s par donne) : on n'y joue pas." % [a.id,
		Game.fmt(int(a.blindes[0])), Game.fmt(int(a.blindes[1])), Game.fmt(int(a.plafond))]
	if v.get("seat") != null and not hors_ligne:
		(func():
			while _busy:
				await get_tree().process_frame
			_busy = true
			await Compte.casino("partir", avec_table({}))
			_busy = false).call_deferred()
	seated = false
	_render()


## Les arguments d'une demande, avec la table quand ce n'est pas celle des Ambassadeurs.
func avec_table(args: Dictionary) -> Dictionary:
	if table_id != "":
		args["table"] = table_id
	return args


func _info_text(t: String) -> void:
	if _info:
		_info.text = t


# --- La table vue du serveur --------------------------------------------------------------------

## Le joueur était déjà assis (une autre fenêtre, ou il revient) : le jeu le sait par la vue.
func appliquer(v: Dictionary, action := "voir") -> void:
	if refusee or not tarif_confirme(v):
		if not refusee:
			_refuser(v)
		return
	srv = v
	var rendu := int(v.get("rendu", 0))
	if rendu > 0:
		Game.credits += rendu
		Game.changed.emit()
		_log.text = "Le croupier vous rend les %s crédits qu'il vous gardait." % Game.fmt(rendu)
	var was_seated := seated
	seated = v.get("seat") != null
	my_seat = int(v.seat) if seated else -1
	stack = int(round(float(v.get("stack", 0))))
	if was_seated and not seated and action != "partir":
		_log.text = "Le croupier a libéré votre chaise : vous n'avez plus donné de nouvelles."
	_lire_places(v)
	_suivre_argent(action)
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
		var etait := _waiting_player
		_waiting_player = not _options.is_empty()
		if _waiting_player:
			# À chaque tour de parole, la relance repart du minimum : celle de la main d'avant (980)
			# demandait une quinzaine de clics pour redescendre à 150.
			_raise_to = int(_options.minTo) if not etait else clampi(_raise_to, int(_options.minTo), int(_options.maxTo))
		if me.is_empty():
			seats[0].folded = true
	else:
		_waiting_player = false
		_options = {}
		turn = -1
	if not in_hand:
		_raconter_attente(pk)
	_render()


## Les crédits suivent la table : ce que le serveur me voit de disponible baisse d'une mise (elle part
## des crédits, comptée comme misée) ou monte d'un gain (il y revient, compté comme gagné). S'asseoir et
## recaver posent le repère sans rien déplacer : le tapis n'est que l'image des crédits.
func _suivre_argent(action: String) -> void:
	if not seated:
		_dispo = -1
		return
	var dispo := int(seats[0].get("stack", 0))
	if _dispo >= 0 and action != "s-asseoir" and action != "recaver":
		var d := dispo - _dispo
		if d < 0:
			_miser(-d)
		elif d > 0:
			Game.cash_in(d)
	_dispo = dispo


func _miser(amount: int) -> void:
	if Game.spend(amount):
		return
	# Les crédits ont bougé ailleurs depuis que le tapis a été posé : la mise part quand même.
	Game.credits = maxi(0, Game.credits - amount)
	Game.staked += amount
	Game.changed.emit()


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
	# Les mains montrées : celle du gagnant dite en entier (« un brelan de rois »), et ses cartes quand
	# ce n'est pas la sienne.
	if not shown.is_empty() and not winners.is_empty() and board.size() >= 3:
		what = nommer(evaluate(seats[winners[0]].cards + board), true)
		if not (0 in winners):
			what += " (%s)" % " · ".join(winners.map(func(w): return "%s %s" % [_card_text(seats[w].cards[0]), _card_text(seats[w].cards[1])]))
	_log.text = "%s %s %s%s.%s" % [who, verb, Game.fmt(net_pot), (" avec " + what) if what != "" else "",
		(" La maison prend %d." % int(last.rake)) if float(last.get("rake", 0)) > 0 else ""]
	if not winners.is_empty():
		showdown.emit(winners, not shown.is_empty(), net_pot)
	# Les crédits ont déjà suivi la donne (_suivre_argent) : reste le son du résultat, comme au solo.
	if not mine.is_empty():
		Sfx.result(int(round(float(mine.staked))), int(round(float(mine.returned))))


func _raconter_attente(pk: Dictionary) -> void:
	if not seated:
		return
	if pk.get("waiting", false):
		_log.text = "Il faut %s devant soi pour être servi : recavez, si vos crédits y suffisent." % Game.fmt(CAP)


# --- Les gestes ------------------------------------------------------------------------------------

func cave() -> int:
	return mini(Game.credits, maxi(CAVE_MAX, CAP))


## « Nouvelle donne » devient « S'asseoir » ou « Recaver » : les donnes partent seules au serveur.
## Ni l'un ni l'autre ne prend de crédits : la table ne fait que lire ce qu'on a.
func _new_hand() -> void:
	if refusee:
		return
	var c := cave()
	if c < CAP:
		_log.text = "Il faut au moins %s crédits pour être servi." % Game.fmt(CAP)
		return
	if not seated:
		_appeler_assis("s-asseoir", c)
	elif srv.get("poker", {}).get("waiting", false):
		_appeler_assis("recaver", c)


func _appeler_assis(action: String, c: int) -> void:
	while _busy:
		await get_tree().process_frame
	_busy = true
	var r: Dictionary = await Compte.casino(action, avec_table({"cave": c}))
	_busy = false
	if not is_inside_tree():
		return
	if r.code != 200 or not r.corps is Dictionary or r.corps.has("error"):
		_log.text = str(r.corps.error) if r.corps is Dictionary and r.corps.has("error") else "Le casino ne répond pas."
		return
	if action == "s-asseoir":
		_log.text = "Vous prenez place avec %s crédits. La donne part quand le croupier est prêt." % Game.fmt(c)
	else:
		_log.text = "Votre tapis est remis à %s crédits." % Game.fmt(c)
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

## L'encart des joueurs, posé à droite sur le même calque que la barre ; il part avec le panneau.
func _batir_encart(layer: Control) -> void:
	_encart = PanelContainer.new()
	BARRE.style(_encart)
	_encart.mouse_filter = Control.MOUSE_FILTER_STOP
	_encart.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			_encart_ouvert = not _encart_ouvert
			_render_encart())
	_encart_texte = RichTextLabel.new()
	_encart_texte.bbcode_enabled = true
	_encart_texte.fit_content = true
	_encart_texte.scroll_active = false
	_encart_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_encart_texte.add_theme_font_override("normal_font", BARRE.KIT.serif())
	_encart_texte.add_theme_font_size_override("normal_font_size", 20)
	_encart_texte.add_theme_color_override("default_color", BARRE.CREAM)
	_encart_texte.custom_minimum_size = Vector2(300, 0)
	_encart.add_child(_encart_texte)
	layer.add_child(_encart)
	var poser := func(): _encart.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 18)
	_encart.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	_encart.resized.connect(poser)
	# Au téléphone, l'encart ouvert cacherait la table : il vient replié, un geste l'ouvre.
	_encart_ouvert = get_viewport().get_visible_rect().size.x >= 900
	tree_exiting.connect(func(): if _encart: _encart.queue_free())


## Les lignes de l'encart (bbcode), dans l'ordre des chaises à partir de la sienne.
func encart_lignes() -> Array[String]:
	var cream := BARRE.CREAM.to_html(false)
	var muted := BARRE.MUTED.to_html(false)
	var gold := BARRE.GOLD.to_html(false)
	var h = srv.get("poker", {}).get("hand")
	var dans_donne := h is Dictionary and in_hand
	var lignes: Array[String] = []
	var tete := "Vos crédits : %s" % Game.fmt(Game.credits)
	if dans_donne:
		tete += "   ·   pot %s" % Game.fmt(pot)
	tete += "   ·   %s par donne au plus" % Game.fmt(CAP)
	lignes.append("[color=%s]%s[/color]" % [muted, tete])
	var joueurs := {}
	if h is Dictionary:
		for p in h.players:
			joueurs[rel(int(p.seat))] = p
	for i in 6:
		var s: Dictionary = seats[i]
		if str(s.get("name", "")) == "":
			continue
		var p = joueurs.get(i)
		var nom := "Vous" if i == 0 else str(s.name)
		# Les habitués jouent la bourse de la maison : leur nom suffit, sans tapis à montrer.
		var avoir := Game.fmt(Game.credits) if i == 0 else (Game.fmt(int(s.get("stack", 0))) if s.get("human", false) else "")
		var geste := ""
		if dans_donne and p is Dictionary:
			if p.get("button", false):
				nom += " (donneur)"
			geste = _geste(p)
		elif dans_donne:
			geste = "ne joue pas"
		var parle: bool = dans_donne and p is Dictionary and p.get("turn", false)
		var l := "%s%s" % ["▶ " if parle else "    ", nom]
		if avoir != "":
			l += "  —  " + avoir
		if geste != "":
			l += "   ·   " + geste
		if parle:
			l = "[color=%s]%s[/color]" % [gold, l]
		elif dans_donne and p is Dictionary and not p.get("in", false):
			l = "[color=%s]%s[/color]" % [muted, l]
		else:
			l = "[color=%s]%s[/color]" % [cream, l]
		lignes.append(l)
	return lignes


## Le dernier geste d'un joueur dans la donne, dit court.
static func _geste(p: Dictionary) -> String:
	if not p.get("in", false):
		return "couché"
	var mise := int(round(float(p.get("street", 0))))
	var last = p.get("last")
	if p.get("allIn", false):
		return "tapis"
	match str(last) if last != null else "":
		"fold": return "couché"
		"check": return "parle"
		"call": return "suit %s" % Game.fmt(mise) if mise > 0 else "suit"
		"bet": return "mise %s" % Game.fmt(mise)
		"raise": return "relance à %s" % Game.fmt(mise)
	if mise > 0:
		return "blinde %s" % Game.fmt(mise)
	return "attend" if p.get("turn", false) else "à suivre"


func _render_encart() -> void:
	if _encart == null:
		return
	if not _encart_ouvert:
		_encart_texte.text = "[color=%s]Autour de la table ▸[/color]" % BARRE.MUTED.to_html(false)
		return
	_encart_texte.text = "\n".join(encart_lignes())

## Debout, on regarde la table : pas de main à rappeler (les cartes de la place 0 sont alors fausses).
func mes_cartes() -> Array:
	return super() if seated else []


func _render_bar() -> void:
	_render_rappel()
	var to_call := int(round(float(_options.get("toCall", 0))))
	var parts: Array[String] = []
	if in_hand:
		parts.append("Pot : %s" % Game.fmt(pot))
		if not seats[0].get("folded", false) and seats[0].has("cards"):
			if ma_main_nommee() != "":
				parts.append("votre main : %s" % ma_main_nommee())
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
	_buttons["deal"].text = "  S'asseoir  " if not seated else "  Recaver  "
	for k in ["fold", "call", "raise", "less", "more"]:
		_buttons[k].visible = in_hand and seated
		_buttons[k].disabled = not acting
	_buttons["raise"].disabled = not acting or not _options.get("canRaise", false)
	_raise_label.visible = in_hand and seated
	_buttons["call"].text = "Suivre %s" % Game.fmt(to_call) if to_call > 0 else "Parler"


func _render(show_all := false) -> void:
	if embedded:
		_render_bar()
		_render_encart()
		changed.emit()
	elif _rows.size() == 6:
		super(show_all)
