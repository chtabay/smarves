extends PanelContainer
## Une table d'échecs du Cercle (la brique « plateaux », scripts/plateaux/plateaux.gd) : l'échiquier au
## milieu, les deux joueurs et leurs pendules de part et d'autre, la feuille de partie et les gestes à
## côté (sous l'échiquier sur un écran étroit). Tout se joue sur le serveur (fonction casino du dépôt
## chtabay/addict, smarves-plateaux.js) : il vérifie chaque coup, fait jouer le robot et tient la pendule.
## Le panneau relit la table toutes les 0,8 s et montre ce qui a changé.
##
## Deux sortes de tables :
## - avec un robot installé, on joue seul contre lui : on choisit la cadence et sa couleur, on accepte,
##   il répond à chaque coup ;
## - vide, elle attend un second joueur réel. Quand les deux sont assis, chacun voit la cadence
##   (5 minutes proposées) et les couleurs (les blancs au premier assis, proposés) ; l'un ou l'autre les
##   change, chacun accepte, la partie commence. On peut proposer la nulle, abandonner, demander la
##   revanche (couleurs inversées).
## Les mises se fixent avec les autres réglages, avant la partie (pour l'honneur, ou de 50 à 1 000
## crédits). Contre un robot, une victoire rend la mise multipliée selon sa force (son niveau se dit en
## mots, de Novice à Expert) ; entre deux joueurs, le gagnant prend les deux mises ; une nulle rend la
## mise. Les crédits vivent dans la partie du joueur : le serveur dit ce qu'il faut retirer au début et
## remettre à la fin, une seule fois par partie (plateau.encaisser), et le panneau l'applique.

const BARRE := preload("res://scripts/jeux/barre.gd")
const REGLES := preload("res://scripts/jeux/regles.gd")
const ECHIQUIER := preload("res://scripts/plateaux/echiquier.gd")
const RELIRE := 0.8
## Le temps que le robot semble réfléchir avant que sa réponse s'affiche.
const PAUSE_ROBOT := 0.7

signal closed
## Pour les salles qui encaissent les panneaux du casino : le panneau encaisse lui-même, il n'est jamais émis.
@warning_ignore("unused_signal")
signal played(mise: int, gain: int)

## La table du serveur (« cercle:echecs-1 »), et son nom à l'écran.
var table_id := "cercle:echecs-1"
var title := ""
## Pour les essais et les captures : pas de réseau, les vues sont posées par appliquer().
var hors_ligne := false

var vue := {}
var echiquier: Control
var _minuteur: Timer
var _busy := false
var _vue_a := 0.0
var _haut: Dictionary = {}
var _bas: Dictionary = {}
var _etat: Label
var _feuille: RichTextLabel
var _gestes: HFlowContainer
var _reglage: VBoxContainer
var _corps: BoxContainer
var _cote: VBoxContainer
var _attente_robot := false
var _encaisse_en_cours := false
var _derniere_cle := ""


func _ready() -> void:
	BARRE.style(self)
	theme = Tables.theme()
	var vp := get_viewport_rect().size
	var etroit := vp.x < vp.y * 1.05
	var cote_plateau := minf(vp.y * (0.62 if etroit else 0.64), vp.x * (0.94 if etroit else 0.5))
	_corps = VBoxContainer.new() if etroit else HBoxContainer.new()
	_corps.add_theme_constant_override("separation", 14)
	add_child(_corps)
	var gauche := VBoxContainer.new()
	gauche.add_theme_constant_override("separation", 6)
	_corps.add_child(gauche)
	_haut = _carte_joueur(gauche)
	echiquier = ECHIQUIER.new()
	echiquier.custom_minimum_size = Vector2(cote_plateau, cote_plateau)
	echiquier.coup.connect(_jouer)
	gauche.add_child(echiquier)
	_bas = _carte_joueur(gauche)
	_cote = VBoxContainer.new()
	_cote.add_theme_constant_override("separation", 10)
	_cote.custom_minimum_size.x = 0 if etroit else clampf(vp.x * 0.24, 260, 380)
	_corps.add_child(_cote)
	var titre := BARRE.label(title if title != "" else "Échecs", 24, BARRE.GOLD)
	titre.add_theme_font_override("font", Polices.gras())
	_cote.add_child(titre)
	_etat = BARRE.label("Le secrétaire du Cercle vous installe.", 20)
	_etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat.custom_minimum_size.x = 240
	_cote.add_child(_etat)
	_reglage = VBoxContainer.new()
	_reglage.add_theme_constant_override("separation", 8)
	_cote.add_child(_reglage)
	_feuille = RichTextLabel.new()
	_feuille.bbcode_enabled = true
	_feuille.fit_content = false
	_feuille.scroll_following = true
	_feuille.custom_minimum_size = Vector2(240, 90 if etroit else 220)
	_feuille.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feuille.add_theme_font_size_override("normal_font_size", 20)
	_feuille.add_theme_color_override("default_color", BARRE.CREAM)
	_cote.add_child(_feuille)
	_gestes = HFlowContainer.new()
	_gestes.add_theme_constant_override("h_separation", 8)
	_gestes.add_theme_constant_override("v_separation", 8)
	_cote.add_child(_gestes)
	_minuteur = Timer.new()
	_minuteur.wait_time = RELIRE
	_minuteur.autostart = not hors_ligne
	_minuteur.timeout.connect(func(): _appeler("plateau.voir"))
	add_child(_minuteur)
	if not hors_ligne:
		_appeler("plateau.asseoir")
	_rendre()


func _carte_joueur(parent: Control) -> Dictionary:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	var pastille := ColorRect.new()
	pastille.custom_minimum_size = Vector2(22, 22)
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pastille)
	var nom := BARRE.label("", 20)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.clip_text = true
	h.add_child(nom)
	var horloge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.14)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	horloge.add_theme_stylebox_override("panel", sb)
	h.add_child(horloge)
	var temps := BARRE.label("5:00", 26)
	temps.add_theme_font_override("font", Polices.gras())
	horloge.add_child(temps)
	return {"pastille": pastille, "nom": nom, "horloge": horloge, "fond": sb, "temps": temps}


# --- Le réseau --------------------------------------------------------------------------------

func _appeler(action: String, args := {}) -> void:
	if hors_ligne or (_busy and action == "plateau.voir"):
		return
	_busy = true
	var a := args.duplicate()
	a["table"] = table_id
	var r: Dictionary = await Compte.casino(action, a)
	_busy = false
	if not is_inside_tree():
		return
	if r.code == 0:
		_etat.text = "Le casino ne répond pas. Vérifiez la connexion à Internet."
		return
	if r.code == 401:
		_etat.text = "Votre connexion au compte a expiré : reconnectez-vous dans la bienvenue."
		_minuteur.stop()
		return
	if not r.corps is Dictionary:
		return
	if r.corps.has("error"):
		_etat.text = str(r.corps.error)
		if action == "plateau.jouer":
			_appeler.call_deferred("plateau.voir")
		return
	if action == "plateau.jouer" and _robot():
		# Le robot a déjà répondu : on laisse voir son coup à soi, puis le sien arrive.
		_attente_robot = true
		await get_tree().create_timer(PAUSE_ROBOT).timeout
		_attente_robot = false
		if not is_inside_tree():
			return
	appliquer(r.corps)
	if r.corps.has("refus"):
		_etat.text = str(r.corps.refus)


## Pose une vue du serveur (smarves-plateaux.js, viewPlateau).
func appliquer(v: Dictionary) -> void:
	if _attente_robot:
		return
	var avant: Dictionary = vue.get("partie", {}) if vue.get("partie") is Dictionary else {}
	vue = v
	_vue_a = Time.get_ticks_msec() / 1000.0
	var pt = v.get("partie")
	if pt is Dictionary and (pt.coups as Array).size() != (avant.get("coups", []) as Array).size():
		Sfx.play("click", -6.0)
	_rendre()
	if pt is Dictionary and pt.get("du") is Dictionary:
		_encaisser(pt)


## La mise part des crédits au début de la partie, le gain y revient à la fin : on le demande au
## serveur, qui le note une seule fois, puis on l'applique.
func _encaisser(pt: Dictionary) -> void:
	if _encaisse_en_cours or hors_ligne:
		return
	_encaisse_en_cours = true
	var r: Dictionary = await Compte.casino("plateau.encaisser", {"table": table_id, "partie": pt.id, "quand": pt.du.quand})
	_encaisse_en_cours = false
	if not is_inside_tree() or r.code != 200 or not r.corps is Dictionary:
		return
	var m := int(r.corps.get("encaisse", 0))
	if m < 0:
		if not Game.spend(-m):
			Game.credits = maxi(0, Game.credits + m)
			Game.changed.emit()
	elif m > 0:
		Game.cash_in(m)
		Sfx.result(int(pt.get("mise", 0)), m)


func _robot() -> bool:
	return vue.get("table", {}).get("robot") is Dictionary


func _ma_couleur() -> String:
	var k := int(vue.get("moi", -1))
	var places: Array = vue.get("places", [])
	if k < 0 or k >= places.size() or not places[k] is Dictionary:
		return "blancs"
	return str(places[k].couleur)


# --- L'écran ------------------------------------------------------------------------------------

func _rendre() -> void:
	if echiquier == null:
		return
	var phase := str(vue.get("phase", "attente"))
	var mine := _ma_couleur()
	echiquier.retourne = mine == "noirs"
	var pt = vue.get("partie")
	if pt is Dictionary:
		var coups: Array = pt.coups
		echiquier.poser(str(pt.plateau), pt.get("legaux", []), str(coups[-1]) if not coups.is_empty() else "", bool(pt.get("echec", false)), str(pt["trait"]))
	else:
		echiquier.poser("RNBQKBNRPPPPPPPP" + ".".repeat(32) + "pppppppprnbqkbnr", [])
	_cartes(mine)
	_feuille.text = _feuille_texte(pt)
	_etat.text = _etat_texte(phase, pt)
	var cle := "%s|%s|%s" % [phase, JSON.stringify(vue.get("places", [])), JSON.stringify(vue.get("reglage", {}))]
	if pt is Dictionary:
		cle += "|%s|%s" % [str(pt.get("nulle")), str(pt.get("fin"))]
	if cle != _derniere_cle:
		_derniere_cle = cle
		_rendre_reglage(phase)
		_rendre_gestes(phase, pt)


func _cartes(mine: String) -> void:
	var places: Array = vue.get("places", [null, null])
	var moi := int(vue.get("moi", -1))
	var lui := -1
	for k in places.size():
		if k != moi and places[k] is Dictionary:
			lui = k
	var autre := "noirs" if mine == "blancs" else "blancs"
	_carte(_bas, places[moi] if moi >= 0 and moi < places.size() else null, mine, "Vous")
	_carte(_haut, places[lui] if lui >= 0 else null, autre, "En attente d'un adversaire")


func _carte(c: Dictionary, p, couleur: String, defaut: String) -> void:
	c.pastille.color = ECHIQUIER.BLANC if couleur == "blancs" else ECHIQUIER.NOIR
	var nom := defaut
	if p is Dictionary:
		nom = "Vous" if p.get("moi", false) else str(p.nom)
		var r = vue.get("table", {}).get("robot")
		if p.get("robot", false) and r is Dictionary and str(r.get("force", "")) != "":
			nom += "  ·  %s" % str(r.force)
	c.nom.text = nom
	var pt = vue.get("partie")
	var ms := 0.0
	var court := false
	if pt is Dictionary:
		ms = float(pt.pendule[couleur])
		court = str(pt.pendule.get("court", "")) == couleur
	else:
		var cad := str(vue.get("reglage", {}).get("cadence", "5+0"))
		ms = float(cad.get_slice("+", 0)) * 60000.0
	c["ms"] = ms
	c["court"] = court
	_horloge(c)


func _horloge(c: Dictionary) -> void:
	var ms := float(c.get("ms", 0.0))
	var court := bool(c.get("court", false))
	if court:
		ms = maxf(0.0, ms - (Time.get_ticks_msec() / 1000.0 - _vue_a) * 1000.0)
	var s := int(ceil(ms / 1000.0))
	c.temps.text = ("%d:%02d" % [s / 60, s % 60]) if s >= 20 or not court else ("%d:%02d.%d" % [s / 60, int(ms / 1000.0) % 60, int(ms / 100.0) % 10])
	c.fond.bg_color = Color(0.95, 0.95, 0.92) if court else Color(0.16, 0.15, 0.14)
	c.temps.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1) if court else BARRE.CREAM)
	if court and ms < 20000.0:
		c.fond.bg_color = Color(0.86, 0.3, 0.26)
		c.temps.add_theme_color_override("font_color", Color.WHITE)


func _process(_d: float) -> void:
	if _haut.has("temps"):
		_horloge(_haut)
		_horloge(_bas)


func _feuille_texte(pt) -> String:
	if not pt is Dictionary:
		return ""
	var coups: Array = pt.coups
	var lignes := []
	var i := 0
	while i < coups.size():
		var l := "[color=#a89a80]%d.[/color] %s" % [i / 2 + 1, _lisible(coups[i])]
		if i + 1 < coups.size():
			l += "   " + _lisible(coups[i + 1])
		lignes.append(l)
		i += 2
	return "\n".join(lignes)


## Un coup en clair : « e2-e4 », « e7-e8=D ».
static func _lisible(uci: String) -> String:
	var s := "%s-%s" % [uci.substr(0, 2), uci.substr(2, 2)]
	if uci.length() == 5:
		s += "=" + {"q": "D", "r": "T", "b": "F", "n": "C"}.get(uci[4], "D")
	return s


const RAISONS := {"mat": "échec et mat", "pat": "pat", "temps": "au temps", "abandon": "par abandon"}


func _etat_texte(phase: String, pt) -> String:
	var places: Array = vue.get("places", [])
	var assis := places.filter(func(p): return p is Dictionary).size()
	match phase:
		"attente":
			return "Vous êtes assis. Un second joueur peut vous rejoindre à cette table." if assis == 1 else "La table attend ses joueurs."
		"reglage":
			if _robot():
				return "Choisissez la cadence et votre couleur, puis acceptez."
			return "Fixez ensemble la cadence et les couleurs. La partie commence quand chacun a accepté."
		"partie":
			if not pt is Dictionary:
				return ""
			var mine := _ma_couleur()
			var a_moi: bool = str(pt["trait"]) == mine
			var t := "À vous de jouer." if a_moi else "À votre adversaire."
			if pt.get("echec", false):
				t = ("Échec ! " if a_moi else "Échec. ") + t
			if pt.get("nulle") != null and str(pt.nulle) != mine:
				t += " Votre adversaire propose la nulle."
			elif pt.get("nulle") != null:
				t += " Vous avez proposé la nulle."
			return t
		"fin":
			if not pt is Dictionary or not pt.get("fin") is Dictionary:
				return "La partie est finie."
			var f: Dictionary = pt.fin
			var raison := str(RAISONS.get(str(f.raison), str(f.raison)))
			if f.get("gagnant") == null:
				return "Partie nulle (%s)." % raison
			return ("Vous gagnez, %s !" if str(f.gagnant) == _ma_couleur() else "Vous perdez, %s.") % raison
	return ""


func _rendre_reglage(phase: String) -> void:
	for c in _reglage.get_children():
		c.queue_free()
	if phase != "reglage":
		return
	var r: Dictionary = vue.get("reglage", {})
	_reglage.add_child(BARRE.label("Cadence", 20, BARRE.MUTED))
	var cads := HFlowContainer.new()
	cads.add_theme_constant_override("h_separation", 6)
	cads.add_theme_constant_override("v_separation", 6)
	_reglage.add_child(cads)
	var noms: Dictionary = r.get("cadences", {"5+0": "5 min"})
	for k in noms:
		var b := BARRE.pill(str(noms[k]))
		b.toggle_mode = true
		b.button_pressed = str(r.get("cadence", "")) == k
		b.pressed.connect(_appeler.bind("plateau.regler", {"cadence": k}))
		cads.add_child(b)
	_reglage.add_child(BARRE.label("Votre couleur", 20, BARRE.MUTED))
	var cols := HFlowContainer.new()
	cols.add_theme_constant_override("h_separation", 6)
	_reglage.add_child(cols)
	var mine := _ma_couleur()
	for c in [["blancs", "Les blancs"], ["noirs", "Les noirs"], ["hasard", "Au hasard"]]:
		var b := BARRE.pill(c[1])
		b.toggle_mode = true
		b.button_pressed = c[0] == mine
		b.pressed.connect(_appeler.bind("plateau.regler", {"couleur": c[0]}))
		cols.add_child(b)
	_reglage.add_child(BARRE.label("La mise", 20, BARRE.MUTED))
	var mises := HFlowContainer.new()
	mises.add_theme_constant_override("h_separation", 6)
	mises.add_theme_constant_override("v_separation", 6)
	_reglage.add_child(mises)
	for m in r.get("mises", [0]):
		var b := BARRE.pill("Pour l'honneur" if int(m) == 0 else Game.fmt(int(m)))
		b.toggle_mode = true
		b.button_pressed = int(r.get("mise", 0)) == int(m)
		b.disabled = int(m) > Game.credits
		b.pressed.connect(_appeler.bind("plateau.regler", {"mise": int(m)}))
		mises.add_child(b)
	var mise := int(r.get("mise", 0))
	if mise > 0:
		var gain := BARRE.label("", 20, BARRE.GOLD)
		gain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if _robot():
			gain.text = "Une victoire rend %s crédits, mise comprise ; une nulle rend la mise." % Game.fmt(roundi(mise * float(r.get("paie", 2))))
		else:
			gain.text = "Chacun mise %s : le gagnant prend les deux mises, une nulle les rend." % Game.fmt(mise)
		_reglage.add_child(gain)
	var places: Array = vue.get("places", [])
	var moi := int(vue.get("moi", -1))
	var j_ai_accepte: bool = moi >= 0 and places[moi] is Dictionary and places[moi].get("ok", false)
	var accepter := BARRE.main_button("Accepté, on attend l'autre" if j_ai_accepte else "Accepter et jouer")
	accepter.disabled = j_ai_accepte
	accepter.pressed.connect(func(): _appeler("plateau.accepter", {"solde": Game.credits}))
	_reglage.add_child(accepter)


func _rendre_gestes(phase: String, pt) -> void:
	for c in _gestes.get_children():
		c.queue_free()
	if phase == "partie":
		var mine := _ma_couleur()
		var propose: bool = pt is Dictionary and pt.get("nulle") != null and str(pt.nulle) != mine
		var n := BARRE.pill("Accepter la nulle" if propose else "Proposer la nulle")
		n.pressed.connect(_appeler.bind("plateau.nulle"))
		_gestes.add_child(n)
		var ab := BARRE.pill("Abandonner")
		ab.pressed.connect(_appeler.bind("plateau.abandonner"))
		_gestes.add_child(ab)
	elif phase == "fin":
		var rv := BARRE.main_button("Revanche")
		rv.pressed.connect(_appeler.bind("plateau.revanche"))
		_gestes.add_child(rv)
	_gestes.add_child(REGLES.bouton(self, "echecs"))
	var lever := BARRE.pill("Se lever")
	lever.pressed.connect(_se_lever)
	_gestes.add_child(lever)


func _jouer(uci: String) -> void:
	_appeler("plateau.jouer", {"coup": uci})


func _se_lever() -> void:
	_minuteur.stop()
	if not hors_ligne:
		# Pendant une partie, se lever, c'est abandonner : le serveur le note.
		Compte.casino("plateau.lever", {"table": table_id})
	closed.emit()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_se_lever()
		get_viewport().set_input_as_handled()
