extends PanelContainer
## La vitrine d'un vendeur : un acte de vente chez Maître Garnier, un bon de commande chez Raymonde et
## au garage Fradin. Chaque bien a sa fiche : prix, rente annoncée, charges, standing, la phrase de celui
## qui le cède, et deux façons de payer : comptant, ou financé au Crédit Smarvois.

signal closed
## Ce que dit le vendeur après un achat, une revente ou un refus.
signal spoke(text: String)

var seller := "notaire"
## La commune de l'étude (« » : la commune d'origine). Ses adresses sont au catalogue sous NOTAIRE.cle().
var commune := ""
## Chez un commerce d'une commune (seller « commerce ») : l'id de sa structure (scripts/socle/commerce.gd).
var boutique := ""

const INK := Color(0.12, 0.14, 0.3)
const INK_LIGHT := Color(0.32, 0.32, 0.42)
const PAPER := Color(0.96, 0.93, 0.84)
const HEADINGS := {
	"notaire": ["Étude de Maître Garnier, notaire à Smarves", "Registre des cessions  ·  parts du village et immeubles"],
	"couture": ["Raymonde, couture et retouches", "Bon de commande  ·  sur mesure, livré le soir même"],
	"garage": ["Garage Fradin  ·  toutes marques", "Bon de commande  ·  reprise de votre ancien véhicule à 60 %"],
	"brocante": ["Ginette Boutin, brocante et meubles", "Bon d'achat  ·  livré chez vous, posé où vous voulez"],
}
const THANKS := {
	"notaire": ["« Signé. Vous voilà propriétaire, et Smarves compte un investisseur de plus. »",
		"« Paraphez ici, et ici. Parfait. Votre avenir est enregistré. »",
		"« Acte conforme. Le village vous remercie de votre confiance. »"],
	"couture": ["« Il vous va comme un gant. On vous prendra pour un homme qui gagne. »",
		"« Avec ça, Monsieur Armand vous ouvrira la porte lui-même. »"],
	"garage": ["« Plein fait, rétroviseurs réglés. Elle vous attend sur la place. »",
		"« Rodage en douceur, hein. Enfin, jusqu'au casino. »"],
	"brocante": ["« Livré ce soir. Vous le poserez où vous voudrez, c'est noté dans votre carnet. »",
		"« Une bonne affaire. Les miennes le sont toutes, remarquez. »"],
}
const FINANCED := "« M. Brunet a déjà donné son accord, il me l'a dit ce matin. Le Crédit Smarvois règle, vous profitez. »"
const SOLD := "« Repris à %s. Le marché est ce qu'il est, mais vous gardez l'expérience. »"
const TOO_POOR := "« Il vous manque quelques crédits. M. Brunet finance, vous savez : c'est son métier, et il l'aime. »"

const CARTE := preload("res://scripts/carte_biens.gd")
const NOTAIRE := preload("res://scripts/socle/notaire.gd")
const OBLIGATIONS := preload("res://scripts/socle/foot_obligations.gd")
const ARTICLES := preload("res://scripts/socle/articles.gd")

var _list: VBoxContainer
## Chez le notaire, le registre est un plan : les biens sur leurs bâtiments, la fiche du lot choisi à côté.
var _map: Control
var _picked := ""
var _tabs := {}
var _status: Label
var _serif: Font


func _ready() -> void:
	_serif = Polices.texte()
	if seller == "notaire":
		# Capture : --actionnaires=vous:3,Lucien:5 force les porteurs ; --registre ouvre le registre des obligations.
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--actionnaires="):
				get_node("/root/Football").forcer_porteurs(arg.trim_prefix("--actionnaires="), "smarves")
		if "--registre" in OS.get_cmdline_user_args():
			_ouvrir_obligations.call_deferred("smarves")
	custom_minimum_size = Vector2(1120, 760) if seller == "notaire" else Vector2(940, 620)
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.border_color = Color(0.45, 0.32, 0.18)
	st.set_border_width_all(2)
	st.set_corner_radius_all(3)
	st.set_content_margin_all(26)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 14
	add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head: Array = HEADINGS.get(seller, HEADINGS.notaire).duplicate()
	if seller == "notaire":
		head[0] = NOTAIRE.etude(_c()).titre
		if not _banque().is_empty():
			head[1] = "Registre des cessions  ·  les immeubles de %s" % str(_c().data.get("nom", ""))
	elif seller == "commerce":
		var s := _commerce()
		head = [str(s.get("enseigne", s.get("nom", "La boutique"))), ARTICLES.BONS.get(str(s.get("genre", "")), ARTICLES.BONS.tenue)[0]]
	_label(v, head[0], 28, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(v, head[1], 16, INK_LIGHT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := ColorRect.new()
	rule.color = Color(0.45, 0.32, 0.18, 0.6)
	rule.custom_minimum_size.y = 2
	v.add_child(rule)
	if seller == "couture" or (seller == "commerce" and str(_commerce().get("genre", "")) == "tenue"):
		# Chez tout couturier, la cabine d'essayage : on retouche la tenue qu'on porte (Avatar).
		var cabine := _button("La cabine d'essayage : retoucher la tenue, un chapeau, des lunettes…", _ouvrir_cabine)
		cabine.name = "Cabine"
		cabine.custom_minimum_size.y = 44
		cabine.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(cabine)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if seller == "notaire":
		var h := HBoxContainer.new()
		h.size_flags_vertical = Control.SIZE_EXPAND_FILL
		h.add_theme_constant_override("separation", 18)
		v.add_child(h)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", 6)
		h.add_child(left)
		# Les quartiers du plan, en onglets assez grands pour le doigt.
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 6)
		left.add_child(tabs)
		var reg := NOTAIRE.registre(_c())
		for quart in reg.quartiers:
			var q := str(quart.id)
			var t := _button(str(quart.nom), _on_quartier.bind(q))
			t.toggle_mode = true
			t.add_theme_color_override("font_pressed_color", INK)
			t.add_theme_color_override("font_hover_pressed_color", INK)
			t.custom_minimum_size = Vector2(150, 48)
			t.name = q
			tabs.add_child(t)
			_tabs[q] = t
		_map = CARTE.new()
		_map.registre = reg
		_map.commune = commune
		_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_map.picked.connect(_on_picked)
		_map.quartier_changed.connect(_on_quartier_changed)
		left.add_child(_map)
		_on_quartier_changed(_map.quartier)
		scroll.custom_minimum_size.x = 320
		h.add_child(scroll)
	else:
		v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_status = _label(v, "", 16, INK)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var leave := _button("Merci, au revoir  (Échap)", func(): closed.emit())
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(leave)
	_refresh()


func _c() -> Commune:
	var c: Commune = Communes.commune(commune) if commune != "" else null
	return c if c != null else Commune.smarves()


## La banque qui finance ici : celle de la commune, sauf à l'origine (le Crédit Smarvois).
func _banque() -> Dictionary:
	var b: Dictionary = _c().banque()
	return b if NOTAIRE.cle(_c(), "x") != "x" else {}


## La structure du commerce ouvert ({} hors d'un commerce).
func _commerce() -> Dictionary:
	for s in Structures.nettoyer(_c().data.get("structures")):
		if s.type == "commerce" and s.id == boutique:
			return s
	return {}


func _mercis() -> Array:
	if seller == "commerce":
		return ARTICLES.BONS.get(str(_commerce().get("genre", "")), ARTICLES.BONS.tenue)[1]
	return THANKS.get(seller, THANKS.notaire)


func _label(parent: Control, t: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Polices.gras() if bold else _serif)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(t: String, action: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.disabled = not enabled
	b.add_theme_font_override("font", _serif)
	b.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = {"normal": Color(0.9, 0.85, 0.72), "hover": Color(0.98, 0.9, 0.7), "pressed": Color(0.85, 0.75, 0.55),
			"disabled": Color(0.9, 0.88, 0.82), "focus": Color(0, 0, 0, 0)}[state]
		s.border_color = Color(0.45, 0.32, 0.18, 0.35 if state == "disabled" else 0.9)
		s.set_border_width_all(1)
		s.set_corner_radius_all(2)
		s.content_margin_left = 12
		s.content_margin_right = 12
		s.content_margin_top = 5
		s.content_margin_bottom = 5
		if state == "focus":
			s.draw_center = false
			s.border_color = Color(0, 0, 0, 0)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color(0.4, 0.1, 0.05))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.5))
	b.pressed.connect(action)
	return b


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if _map:
		_detail(_picked)
		_map.queue_redraw()
	for it in Biens.catalogue():
		if _map:
			break
		if it.seller != seller or (seller == "commerce" and str(it.get("commerce", "")) != "%s/%s" % [commune, boutique]):
			continue
		_card(it)
	var b := _banque()
	_status.text = "Vos crédits : %s   ·   Dette %s : %s   ·   Standing : %d" % [Game.fmt(Game.credits),
		"au Crédit Smarvois" if b.is_empty() else "à %s" % str(b.get("nom", "la banque")),
		Game.fmt(Game.debt if b.is_empty() else Game.debt_of(str(b.get("preteur", "")))), Biens.standing()]


func _card(it: Dictionary) -> void:
	var n := Biens.count(it.id)
	var open: bool = Game.won >= it.gate
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_list.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 1)
	row.add_child(left)
	var title: String = it.name
	if n > 0:
		title += "   ·   vous en avez %d" % n if it.max > 1 else "   ·   à vous"
	_label(left, title, 20, INK if open else INK_LIGHT, true)
	if not open:
		_label(left, "Pas encore cédé. %s attend que vous ayez gagné %s au jeu." % [it.from, Game.fmt(it.gate)], 15, INK_LIGHT)
		return
	_label(left, "%s  —  %s" % [it.from, it.blurb], 15, INK_LIGHT)
	var facts: Array[String] = []
	if it.rente > 0:
		facts.append("rente annoncée %s par recette" % Game.fmt(it.rente))
	if it.charge > 0:
		facts.append("charges %s" % Game.fmt(it.charge))
	if it.standing > 0:
		facts.append(("standing +%d, posé chez soi" if it.kind == "meuble" else "standing +%d") % it.standing)
	if it.max > 1:
		facts.append("%d au plus" % it.max)
	_label(left, "  ·  ".join(facts), 15, INK)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 250
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	if Biens.available(it.id):
		var price := Biens.next_price(it.id)
		_label(right, "%s crédits" % Game.fmt(price), 22, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var buttons := HBoxContainer.new()
		buttons.alignment = BoxContainer.ALIGNMENT_END
		right.add_child(buttons)
		buttons.add_child(_button("Payer comptant", _buy.bind(it.id, false)))
		buttons.add_child(_button("Financer", _buy.bind(it.id, true)))
	else:
		_label(right, "complet", 16, INK_LIGHT).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if n > 0:
		var resell := _button("Revendre (%s)" % Game.fmt(Biens.resale_of(it.id)), _sell.bind(it.id))
		resell.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(resell)


func _on_quartier(q: String) -> void:
	_map.set_quartier(q)
	_on_quartier_changed(_map.quartier)


func _on_quartier_changed(q: String) -> void:
	for k in _tabs:
		_tabs[k].set_pressed_no_signal(k == q)
	if _picked != "" and not _dans(_picked, q):
		_picked = ""
		_map.select("")
		_refresh()


## Une adresse est-elle sur le plan de ce quartier (le Moulin est sur la place et au bout de la rue du Clain).
func _dans(id: String, q: String) -> bool:
	for a in NOTAIRE.registre(_c()).adresses:
		if str(a.id) == id and str(a.quartier) == q:
			return true
	return false


func _on_picked(id: String) -> void:
	if not _dans(id, _map.quartier):
		_map.set_quartier(NOTAIRE.quartier_of(_c(), id))
	_picked = id
	_map.select(id)
	_refresh()


## La fiche d'un lot du plan : ce qu'il rapporte, qui le cède, et les actes possibles.
## Sans lot choisi : la légende du plan et ce qu'on possède déjà.
func _detail(id: String) -> void:
	if id == "":
		_label(_list, "Touchez un bâtiment du plan pour voir ce qui s'y vend.", 17, INK)
		_legend("à vendre", CARTE.FOR_SALE)
		_legend("à vous", CARTE.MINE)
		_legend("pas encore cédé", CARTE.CLOSED)
		var mine: Array[String] = []
		for it in Biens.catalogue():
			if it.seller == seller and str(it.get("commune", "")) == ("" if _banque().is_empty() else str(_c().data.id)) and Biens.count(it.id) > 0:
				mine.append(it.name if Biens.count(it.id) == 1 else "%s ×%d" % [it.name, Biens.count(it.id)])
		_label(_list, "Vos biens chez %s : " % NOTAIRE.etude(_c()).nom + (", ".join(mine) if not mine.is_empty() else "aucun pour l'instant."), 15, INK_LIGHT)
		return
	var adr := NOTAIRE.adresse(_c(), id)
	id = NOTAIRE.cle_adresse(_c(), adr) if not adr.is_empty() else id
	var it: Dictionary = Biens.item(id)
	var n := Biens.count(id)
	_label(_list, it.name, 21, INK, true)
	var lieu := str(adr.get("ligne", ""))
	if int(adr.get("numero", 0)) == 0 and str(adr.get("etiquette", "")) not in ["", lieu]:
		lieu = "%s  ·  %s" % [adr.etiquette, lieu] if lieu != "" and not lieu.begins_with("Le ") else str(adr.etiquette)
	if lieu != "":
		_label(_list, lieu, 15, INK_LIGHT)
	if Game.won < it.gate:
		_label(_list, "Pas encore cédé. %s attend que vous ayez gagné %s au jeu." % [it.from, Game.fmt(it.gate)], 16, INK_LIGHT)
		return
	_label(_list, "%s  —  %s" % [it.from, it.blurb], 15, INK_LIGHT)
	if it.kind == "club":
		# Les obligations du club : le registre est au championnat (FootObligations), l'étude ne fait que l'ouvrir.
		var f := get_node_or_null("/root/Football")
		if f != null:
			_label(_list, "Neuf obligations, de %s à %s crédits, une seule de chaque ; un dividende à chaque journée, selon le classement." % [Game.fmt(int(f.OBLIGATIONS[0])), Game.fmt(int(f.OBLIGATIONS[f.OBLIGATIONS.size() - 1]))], 16, INK)
			_label(_list, str(f.phrase_actionnaires(str(it.club))), 15, INK_LIGHT)
			if f.investi(str(it.club)) > 0:
				_label(_list, "Vous avez %s crédits dans le club ; dividendes touchés : %s." % [Game.fmt(int(f.investi(str(it.club)))), Game.fmt(int(f.dividendes_total))], 15, INK)
			var reg := _button("Ouvrir le registre des obligations", _ouvrir_obligations.bind(str(it.club)))
			reg.name = "Obligations"
			reg.custom_minimum_size.y = 48
			_list.add_child(reg)
		return
	if it.rente > 0:
		_label(_list, "Rente annoncée : %s par recette" % Game.fmt(it.rente), 16, INK)
	if it.charge > 0:
		_label(_list, "Charges : %s" % Game.fmt(it.charge), 16, INK)
	if it.standing > 0:
		_label(_list, "Standing : +%d" % it.standing, 16, INK)
	if it.max > 1:
		_label(_list, "Vous en avez %d, sur %d au plus." % [n, it.max], 16, INK)
	elif n > 0:
		_label(_list, "À vous.", 16, INK, true)
	if Biens.available(id):
		_label(_list, "%s crédits" % Game.fmt(Biens.next_price(id)), 24, INK, true)
		var banque := str(_banque().get("nom", "au Crédit Smarvois"))
		for b in [_button("Payer comptant", _buy.bind(id, false)), _button("Financer " + (banque if banque.begins_with("au ") else "par %s" % banque), _buy.bind(id, true))]:
			b.custom_minimum_size.y = 48
			_list.add_child(b)
	if Biens.logements.has(id):
		# Une maison à soi : on y habite, ou on la loue ; on change d'avis ici comme dans le carnet.
		var lived := Biens.is_habite(id)
		_label(_list, "Vous y habitez : elle ne verse pas de rente, et compte double en standing." if lived else "Louée : elle verse sa rente à chaque recette.", 15, INK)
		var choice := _button("La remettre en location" if lived else "M'y installer", (Biens.louer if lived else Biens.habiter).bind(id))
		choice.custom_minimum_size.y = 48
		choice.pressed.connect(_refresh)
		_list.add_child(choice)
	if n > 0:
		var resell := _button("Revendre (%s)" % Game.fmt(Biens.resale_of(id)), _sell.bind(id))
		resell.custom_minimum_size.y = 48
		_list.add_child(resell)


func _legend(t: String, c: Color) -> void:
	var h := HBoxContainer.new()
	var sw := ColorRect.new()
	sw.color = c
	sw.custom_minimum_size = Vector2(22, 16)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	_label(h, t, 15, INK).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(h)


func _buy(id: String, financed: bool) -> void:
	if not financed and Game.credits < Biens.next_price(id):
		spoke.emit(TOO_POOR)
		return
	if Biens.buy(id, financed, str(_banque().get("preteur", ""))):
		Sfx.play("chips", -6.0)
		spoke.emit((FINANCED if _banque().is_empty() else "« %s finance, c'est signé. »" % str(_banque().get("nom", "La banque"))) if financed else (_mercis() as Array).pick_random())
	_refresh()


## La cabine d'essayage, par-dessus la vitrine ; elle y revient en se fermant.
func _ouvrir_cabine() -> void:
	var s := _commerce()
	var p := Prestation.panneau("couture", {"nom": "La cabine d'essayage",
		"tenancier": str(s.get("tenancier", "")) if seller == "commerce" else "Raymonde"})
	p.spoke.connect(func(t: String): spoke.emit(t))
	p.closed.connect(func():
		p.queue_free()
		visible = true
		_refresh())
	visible = false
	get_parent().add_child(p)


## Le registre des obligations du club, par-dessus l'étude ; il revient à la fiche en se fermant.
func _ouvrir_obligations(club: String) -> void:
	var p: PanelContainer = OBLIGATIONS.new()
	p.club = club
	p.closed.connect(func():
		p.queue_free()
		visible = true
		_refresh())
	visible = false
	get_parent().add_child(p)


func _sell(id: String) -> void:
	var paid := Biens.sell(id)
	if paid > 0:
		spoke.emit(SOLD % Game.fmt(paid))
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
