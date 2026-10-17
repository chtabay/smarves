extends PanelContainer
## La vitrine d'un vendeur : un acte de vente chez Maître Garnier, un bon de commande chez Raymonde et
## au garage Fradin. Chaque bien a sa fiche : prix, rente annoncée, charges, standing, la phrase de celui
## qui le cède, et deux façons de payer : comptant, ou financé au Crédit Smarvois.

signal closed
## Ce que dit le vendeur après un achat, une revente ou un refus.
signal spoke(text: String)

var seller := "notaire"

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

var _list: VBoxContainer
var _status: Label
var _serif: SystemFont


func _ready() -> void:
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"])
	custom_minimum_size = Vector2(940, 620)
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
	var head: Array = HEADINGS.get(seller, HEADINGS.notaire)
	_label(v, head[0], 28, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(v, head[1], 16, INK_LIGHT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := ColorRect.new()
	rule.color = Color(0.45, 0.32, 0.18, 0.6)
	rule.custom_minimum_size.y = 2
	v.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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


func _label(parent: Control, t: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var f := _serif
	if bold:
		f = _serif.duplicate()
		f.font_weight = 700
	l.add_theme_font_override("font", f)
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
	for it in Biens.CATALOGUE:
		if it.seller != seller:
			continue
		_card(it)
	_status.text = "Vos crédits : %s   ·   Dette au Crédit Smarvois : %s   ·   Standing : %d" % [
		Game.fmt(Game.credits), Game.fmt(Game.debt), Biens.standing()]


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


func _buy(id: String, financed: bool) -> void:
	if not financed and Game.credits < Biens.next_price(id):
		spoke.emit(TOO_POOR)
		return
	if Biens.buy(id, financed):
		Sfx.play("chips", -6.0)
		spoke.emit(FINANCED if financed else (THANKS.get(seller, THANKS.notaire) as Array).pick_random())
	_refresh()


func _sell(id: String) -> void:
	var paid := Biens.sell(id)
	if paid > 0:
		spoke.emit(SOLD % Game.fmt(paid))
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
