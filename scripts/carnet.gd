extends CanvasLayer
## Le carnet du joueur (autoload « Carnet »), ouvert par C : un cahier d'écolier à petits carreaux,
## écrit à l'encre bleue. On y tient ses biens, la dernière recette et ses comptes. Pas de commentaire :
## les chiffres sont alignés, le joueur fait la soustraction. Une fiche de papier glisse en bas de
## l'écran à chaque recette et à chaque reprise de M. Brunet.

const PAPER := Color(0.97, 0.95, 0.88)
const MARGIN_RED := Color(0.85, 0.3, 0.3, 0.55)
const INK := Color(0.12, 0.2, 0.5)
const INK_LIGHT := Color(0.3, 0.38, 0.62)
const PENCIL := Color(0.38, 0.36, 0.34)

var _root: Control
var _left: VBoxContainer
var _right: VBoxContainer
var _slip: PanelContainer
var _slip_label: Label
var _slip_tween: Tween
## Une fiche arrivée carnet ouvert : elle attend qu'on le referme.
var _pending_slip := ""
var _hand: SystemFont
var _hand_bold: SystemFont
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _paused_before := false
## Le logement qu'on est en train d'aménager dans le carnet (« » : aucun).
var _amenage := ""


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hand = SystemFont.new()
	_hand.font_names = PackedStringArray(["Segoe Print", "Bradley Hand", "Comic Sans MS", "Georgia", "serif"])
	_hand.font_italic = true
	_hand_bold = _hand.duplicate()
	_hand_bold.font_weight = 700
	_build()
	_root.visible = false
	Biens.changed.connect(func():
		if _root.visible:
			_refresh())
	Biens.note.connect(show_slip)


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		if Settings.is_open() or get_tree().current_scene == null or get_tree().current_scene.name == "Titre":
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _root.visible:
		_root.visible = false
		Input.mouse_mode = _mouse_before
		get_tree().paused = _paused_before
		if _pending_slip != "":
			show_slip.call_deferred(_pending_slip)
			_pending_slip = ""
	else:
		_mouse_before = Input.mouse_mode
		_paused_before = get_tree().paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh()
		_root.visible = true
		get_tree().paused = true


# --- Le cahier ------------------------------------------------------------------------------

## Une page à petits carreaux, avec la marge rouge.
class Page extends PanelContainer:
	var margin_left := true

	func _draw() -> void:
		var step := 18.0
		var y := 64.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.55, 0.68, 0.85, 0.32), 1.0)
			y += step
		var x := step
		while x < size.x:
			draw_line(Vector2(x, 64), Vector2(x, size.y), Color(0.55, 0.68, 0.85, 0.16), 1.0)
			x += step
		var mx := 46.0 if margin_left else size.x - 46.0
		draw_line(Vector2(mx, 0), Vector2(mx, size.y), Color(0.85, 0.3, 0.3, 0.55), 2.0)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	# La couverture de carton, et les deux pages ouvertes.
	var cover := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.32, 0.12, 0.1)
	cs.set_corner_radius_all(10)
	cs.set_content_margin_all(14)
	cs.shadow_color = Color(0, 0, 0, 0.5)
	cs.shadow_size = 18
	cover.add_theme_stylebox_override("panel", cs)
	center.add_child(cover)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 0)
	cover.add_child(spread)
	_left = _page(spread, false)
	_right = _page(spread, true)


func _page(parent: Control, right: bool) -> VBoxContainer:
	var p := Page.new()
	p.margin_left = right
	p.custom_minimum_size = Vector2(560, 700)
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.content_margin_left = 62 if right else 30
	st.content_margin_right = 30 if right else 62
	st.content_margin_top = 26
	st.content_margin_bottom = 22
	if right:
		st.corner_radius_top_right = 4
		st.corner_radius_bottom_right = 4
	else:
		st.corner_radius_top_left = 4
		st.corner_radius_bottom_left = 4
	p.add_theme_stylebox_override("panel", st)
	parent.add_child(p)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	scroll.add_child(v)
	return v


func _text(parent: Control, t: String, size := 19, color := INK, bold := false) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", _hand_bold if bold else _hand)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _title(parent: Control, t: String) -> void:
	var l := _text(parent, t, 26, INK, true)
	l.add_theme_constant_override("line_spacing", 0)


## Une ligne de compte : le libellé à gauche, le chiffre à droite.
func _row(parent: Control, label: String, value: String, color := INK, bold := false) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var a := _text(h, label, 18, color, bold)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := _text(h, value, 18, color, bold)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.autowrap_mode = TextServer.AUTOWRAP_OFF


func _link(parent: Control, t: String, action: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	b.add_theme_font_override("font", _hand)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.65, 0.15, 0.15))
	b.add_theme_color_override("font_hover_color", Color(0.85, 0.2, 0.2))
	b.add_theme_color_override("font_disabled_color", PENCIL)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _gap(parent: Control, h := 10) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = h
	parent.add_child(c)


func _refresh() -> void:
	for c in _left.get_children() + _right.get_children():
		c.queue_free()
	_fill_left()
	_fill_right()


func _fill_left() -> void:
	_title(_left, "Mes biens")
	_gap(_left, 6)
	if Biens.owned.is_empty():
		_text(_left, "Rien encore. Maître Garnier a des parts de la Smarvoise à 200, et Josiane dit que c'est le placement du siècle.", 18, INK_LIGHT)
	var paid_by := {}
	for r in Biens.last_recette:
		paid_by[r[0]] = r[1]
	for it in Biens.CATALOGUE:
		var n := Biens.count(it.id)
		if n <= 0:
			continue
		var name: String = it.name if n == 1 else "%s  × %d" % [it.name, n]
		if it.kind == "tenue":
			name += "  (portée)" if Biens.worn == it.id else ""
		elif it.kind == "vehicule":
			name += "  (au garage de la place)" if Biens.driven == it.id else ""
		_text(_left, name, 19, INK, true)
		var detail := ""
		if Biens.is_habite(it.id):
			detail = "habitée, ne verse pas de rente"
		elif it.rente > 0:
			detail = "rente annoncée %s" % Game.fmt(it.rente * n)
			if paid_by.has(it.name):
				detail += " · dernière recette %s" % Game.fmt(paid_by[it.name])
		var ch := 0
		if it.kind in ["part", "maison"]:
			ch = it.charge * n
		elif Biens.worn == it.id or Biens.driven == it.id:
			ch = it.charge
		if ch > 0:
			detail += (" · " if detail != "" else "") + "charges %s" % Game.fmt(ch)
		if detail != "":
			_text(_left, detail, 16, INK_LIGHT)
		if it.kind == "tenue" and Biens.worn != it.id:
			_link(_left, "→ la porter", Biens.wear.bind(it.id))
		elif it.kind == "vehicule" and Biens.driven != it.id:
			_link(_left, "→ la prendre", Biens.wear.bind(it.id))
	_fill_logement()
	_gap(_left)
	_title(_left, "La dernière recette")
	if Biens.recettes == 0:
		_text(_left, "Toutes les 20 mises. Pas encore de recette.", 17, INK_LIGHT)
	else:
		var anim := "recette pleine" if Biens.last_animation >= 0.99 else "village animé à %d %%" % int(Biens.last_animation * 100)
		_text(_left, "Recette n° %d, %s." % [Biens.recettes, anim], 17, INK_LIGHT)
		for r in Biens.last_recette:
			_row(_left, r[0], "%s  (annoncé %s)" % [Game.fmt(r[1]), Game.fmt(r[2])], INK_LIGHT)
		_row(_left, "Net de la recette", Game.fmt(Biens.last_net), INK, true)


## « Mon logement » : où l'on dort, et pour chaque maison les deux colonnes, louée ou habitée.
func _fill_logement() -> void:
	_gap(_left)
	_title(_left, "Mon logement")
	var home := Biens.habite()
	_text(_left, "Adresse : %s" % (Biens.item(home).name if home != "" else "l'hôtel du casino, chez Monsieur Armand"), 18, INK)
	for it in Biens.CATALOGUE:
		if not Biens.logements.has(it.id):
			continue
		var lived := Biens.is_habite(it.id)
		_text(_left, "%s  (%s)" % [it.name, "habitée" if lived else "louée"], 18, INK, true)
		_row(_left, "louée : rente annoncée", Game.fmt(it.rente), INK_LIGHT)
		_row(_left, "habitée : standing", "+%d" % (it.standing * 2), INK_LIGHT)
		var furnished := Biens.meubles_value(it.id)
		_row(_left, "estimation, meubles compris", Game.fmt(int(round(it.price * Biens.RESALE)) + furnished), INK_LIGHT)
		if lived:
			_link(_left, "→ la remettre en location", Biens.louer.bind(it.id))
		else:
			_link(_left, "→ m'y installer", Biens.habiter.bind(it.id))
		var here := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		_link(_left, "→ y aller", _go_home.bind(it.id), not (here == Biens.LOGEMENT_SCENE and Biens.visiting == it.id))
		if _amenage != it.id:
			_link(_left, "→ l'aménager  (%d meubles posés)" % Biens.logements[it.id].meubles.size(), _set_amenage.bind(it.id))
			continue
		_link(_left, "→ fermer le plan", _set_amenage.bind(""))
		var room := ""
		for sl in Biens.slots(it.id):
			if sl.piece != room:
				room = sl.piece
				_text(_left, room, 17, INK, true)
			var cur := str(Biens.logements[it.id].meubles.get(sl.id, ""))
			var can := cur != "" or not Biens.posables(sl.genre).is_empty()
			_link(_left, "%s : %s" % [sl.label.trim_prefix(room + ", "), Biens.name_of(cur) if cur != "" else "—"], _cycle.bind(it.id, sl), can)
	var loose: Array = Biens.trouvailles.filter(func(t): return Biens.free_count(t) > 0)
	if not loose.is_empty():
		_text(_left, "Dans le carton : " + ", ".join(loose.map(func(t): return Biens.name_of(t))), 16, INK_LIGHT)


func _go_home(id: String) -> void:
	if is_open():
		toggle()
	Biens.enter(id)


func _set_amenage(id: String) -> void:
	_amenage = id
	_refresh()


func _cycle(home: String, sl: Dictionary) -> void:
	Biens.cycle(home, sl.id)


func _fill_right() -> void:
	_title(_right, "Mes comptes")
	_gap(_right, 6)
	_row(_right, "Crédits en poche", Game.fmt(Game.credits))
	_row(_right, "Mes biens (estimation de Maître Garnier)", Game.fmt(Biens.value()))
	_row(_right, "Dette au Crédit Smarvois", Game.fmt(-Game.debt) if Game.debt > 0 else "0", Color(0.7, 0.12, 0.12) if Game.debt > 0 else INK)
	var net := Game.credits + Biens.value() - Game.debt
	_row(_right, "Fortune nette", Game.fmt(net), INK, true)
	_gap(_right, 6)
	_row(_right, "Rente annoncée par recette", Game.fmt(Biens.rente_annoncee()), INK_LIGHT)
	_row(_right, "Charges par recette", Game.fmt(Biens.charges()), INK_LIGHT)
	_row(_right, "Standing", str(Biens.standing()), INK_LIGHT)
	_gap(_right, 6)
	_text(_right, "Depuis le début", 18, INK, true)
	_row(_right, "Gagné au jeu", Game.fmt(Game.won), INK_LIGHT)
	_row(_right, "Misé", Game.fmt(Game.staked), INK_LIGHT)
	_row(_right, "Dépensé en biens", Game.fmt(Biens.total_spent), INK_LIGHT)
	_row(_right, "Reçu en rentes", Game.fmt(Biens.total_rentes), INK_LIGHT)
	_row(_right, "Payé en charges", Game.fmt(Biens.total_charges), INK_LIGHT)
	if Biens.reprises > 0:
		_row(_right, "Biens repris par M. Brunet", str(Biens.reprises), INK_LIGHT)
	_gap(_right)
	_title(_right, "Adresses")
	var here := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	for id in Biens.SELLERS:
		var s: Dictionary = Biens.SELLERS[id]
		_link(_right, "%s  →  y aller" % s.name, go_to.bind(id), here != s.scene)
	var on_square := here == "res://scenes/main.tscn"
	var tl := _link(_right, "Offrir une tournée générale au café  (%s)" % Game.fmt(Biens.tournee_price()), _tournee, on_square and Game.credits >= Biens.tournee_price())
	if not on_square:
		tl.tooltip_text = "Au Café de la Place."
	_gap(_right, 4)
	_text(_right, "Fermer le carnet : C ou Échap", 15, PENCIL)


func go_to(id: String) -> void:
	if is_open():
		toggle()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().change_scene_to_file(Biens.SELLERS[id].scene)


func _tournee() -> void:
	if Biens.offer_tournee():
		if is_open():
			toggle()
		show_slip("Tournée générale ! Josiane remplit les verres : « Voilà un investisseur qui sait vivre. »")
		var scene := get_tree().current_scene
		var people = scene.get("villagers") if scene else null
		if people != null:
			for v in people:
				if v.critter and v.global_position.x < -2.0:
					v.critter.cheer(2.5)


# --- La fiche de papier ------------------------------------------------------------------------

func show_slip(text: String) -> void:
	if _root.visible:
		_pending_slip = text
		return
	if _slip == null:
		_slip = PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = PAPER
		st.set_content_margin_all(12)
		st.content_margin_left = 18
		st.shadow_color = Color(0, 0, 0, 0.4)
		st.shadow_size = 8
		st.border_color = MARGIN_RED
		st.border_width_left = 3
		_slip.add_theme_stylebox_override("panel", st)
		_slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slip.custom_minimum_size.x = 420
		add_child(_slip)
		_slip_label = _text(_slip, "", 17)
		_slip_label.custom_minimum_size.x = 400
	_slip_label.text = text
	# La fiche reprend la taille de son texte, puis se pose en bas à gauche.
	_slip.reset_size()
	_slip.size = _slip.get_combined_minimum_size()
	_slip.position = Vector2(28, get_viewport().get_visible_rect().size.y - _slip.size.y - 60)
	_slip.rotation_degrees = -1.5
	_slip.modulate.a = 0.0
	if _slip_tween:
		_slip_tween.kill()
	var tw := create_tween()
	_slip_tween = tw
	tw.tween_property(_slip, "modulate:a", 1.0, 0.3)
	tw.tween_interval(5.0 + text.length() * 0.03)
	tw.tween_property(_slip, "modulate:a", 0.0, 0.8)
