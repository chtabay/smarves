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
## Le plan du village : ses quartiers et ses lieux cachés (docs/VILLAGE.md, « Pour le plan du Carnet »).
const VILLAGE := preload("res://scripts/village/village.gd")
## La part de la maquette que couvre le plan, en mètres (x, z) : du Moulin au bois, des rochers à la route.
const PLAN_WORLD := Rect2(-82.0, -79.0, 164.0, 95.0)

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
## Le plan du village, déplié par-dessus le carnet : sa feuille, et ce qu'on y dessine.
var _cover: Control
var _sheet: PanelContainer
var _sheet_box: VBoxContainer


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
	# Le village n'est pas un autoload : on se branche sur lui quand la place se monte.
	get_tree().node_added.connect(_on_node_added)


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		if Settings.is_open() or get_tree().current_scene == null or get_tree().current_scene.name == "Titre":
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.is_action_pressed("ui_cancel"):
		if _sheet.visible:
			_show_sheet(false)
		else:
			toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _root.visible:
		_root.visible = false
		_sheet.visible = false
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
	_cover = cover
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 0)
	cover.add_child(spread)
	_left = _page(spread, false)
	_right = _page(spread, true)
	# Le plan, une grande feuille quadrillée collée dans la couverture, qu'on déplie.
	_sheet = Page.new()
	_sheet.custom_minimum_size = Vector2(1148, 728)
	var sh := StyleBoxFlat.new()
	sh.bg_color = PAPER
	sh.set_content_margin_all(26)
	sh.content_margin_left = 62
	sh.set_corner_radius_all(4)
	sh.shadow_color = Color(0, 0, 0, 0.5)
	sh.shadow_size = 18
	_sheet.add_theme_stylebox_override("panel", sh)
	_sheet.visible = false
	center.add_child(_sheet)
	_sheet_box = VBoxContainer.new()
	_sheet_box.add_theme_constant_override("separation", 4)
	_sheet.add_child(_sheet_box)


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
	for c in _left.get_children() + _right.get_children() + _sheet_box.get_children():
		c.queue_free()
	_cover.visible = not _sheet.visible
	if _sheet.visible:
		_fill_sheet()
		return
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
	_fill_plan()
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


# --- Le plan du village -------------------------------------------------------------------------

## Le plan se dessine en marchant : chaque quartier où l'on a mis les pieds, et les lieux cachés trouvés.
## Ils sont rangés dans le tiroir de Smarves (socle commune), pas avec les biens.
func _tiroir() -> Dictionary:
	return Game.tiroir(Communes.ORIGINE)


func zones_vues() -> Array:
	return _tiroir().get("zones", [])


func caches_trouvees() -> Array:
	var found: Array = _tiroir().get("caches", []).duplicate()
	# Une affiche trouvée avant que le carnet ne tienne le plan : la cabane est déjà connue.
	if Biens.trouvailles.has("affiche_loto_1987") and not found.has("cabane_vigne"):
		found.append("cabane_vigne")
	return found


func _on_node_added(node: Node) -> void:
	if node.get_script() == VILLAGE:
		node.zone_entered.connect(_on_zone_entered)
		node.cache_found.connect(_on_cache_found)


func _on_zone_entered(id: String) -> void:
	if _note_on_plan("zones", id) and id != "place":
		var nom := str(VILLAGE.ZONES[id].nom)
		show_slip("Au plan du carnet : %s." % (nom.left(1).to_lower() + nom.substr(1)))


func _on_cache_found(id: String) -> void:
	_note_on_plan("caches", id)


## Ajoute au plan ; vrai si c'est nouveau.
func _note_on_plan(key: String, id: String) -> bool:
	var t := _tiroir()
	var list: Array = t.get(key, [])
	if list.has(id):
		return false
	list.append(id)
	t[key] = list
	Game.save_game()
	if _root.visible:
		_refresh()
	return true


## Sur la page des comptes : où en est le plan, et de quoi le déplier.
func _fill_plan() -> void:
	_gap(_right)
	_title(_right, "Le plan du village")
	_text(_right, _plan_progress(), 16, INK_LIGHT)
	_link(_right, "→ déplier le plan", _show_sheet.bind(true)).custom_minimum_size.y = 48


func _plan_progress() -> String:
	var left := VILLAGE.ZONES.size() - zones_vues().size()
	if zones_vues().is_empty():
		return "Une page blanche. Sortir sur la place pour commencer le plan."
	if left > 0:
		return "Encore %d %s à parcourir." % [left, "quartier" if left == 1 else "quartiers"]
	return "Tout le village est au plan."


func _show_sheet(open: bool) -> void:
	_sheet.visible = open
	_refresh()


## La feuille dépliée : le plan sur toute la largeur, et de quoi revenir au carnet.
func _fill_sheet() -> void:
	_title(_sheet_box, "Le plan du village")
	var plan := Plan.new()
	plan.font = _hand
	plan.zones = zones_vues()
	plan.caches = caches_trouvees()
	var scene := get_tree().current_scene
	var player = scene.get("player") if scene and scene.scene_file_path == "res://scenes/main.tscn" else null
	if player is Node3D:
		plan.here = Vector2(player.global_position.x, player.global_position.z)
		plan.show_here = true
	plan.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet_box.add_child(plan)
	var foot := HBoxContainer.new()
	_sheet_box.add_child(foot)
	var t := _text(foot, _plan_progress(), 17, INK_LIGHT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_link(foot, "← revenir au carnet", _show_sheet.bind(false)).custom_minimum_size = Vector2(220, 48)


## Le plan au crayon : les quartiers parcourus en lavis, leurs noms, les lieux cachés d'une croix rouge.
class Plan extends Control:
	var font: Font
	var zones: Array = []
	var caches: Array = []
	var here := Vector2.ZERO
	var show_here := false

	func _to_page(p: Vector2) -> Vector2:
		var k := minf(size.x / PLAN_WORLD.size.x, size.y / PLAN_WORLD.size.y)
		var off := (size - PLAN_WORLD.size * k) / 2.0
		return off + (p - PLAN_WORLD.position) * k

	func _draw() -> void:
		var pencil := Color(0.38, 0.36, 0.34)
		for id in zones:
			if not VILLAGE.ZONES.has(id):
				continue
			var r: Rect2 = VILLAGE.ZONES[id].rect
			var a := _to_page(r.position)
			var b := _to_page(r.end)
			var box := Rect2(a, b - a)
			draw_rect(box, Color(0.55, 0.68, 0.85, 0.22))
			draw_rect(box, Color(0.12, 0.2, 0.5, 0.8), false, 1.5)
			_label(str(VILLAGE.ZONES[id].nom), box)
		for id in caches:
			if not VILLAGE.CACHES.has(id):
				continue
			var c: Dictionary = VILLAGE.CACHES[id]
			var p := _to_page(Vector2(c.pos.x, c.pos.z))
			var red := Color(0.7, 0.12, 0.12)
			draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), red, 3.0)
			draw_line(p + Vector2(-7, 7), p + Vector2(7, -7), red, 3.0)
			_ink(str(c.nom), p + Vector2(11, 6), 18, red)
		if show_here:
			var h := _to_page(here)
			draw_circle(h, 7.0, Color(0.12, 0.2, 0.5))
			_ink("vous êtes ici", h + Vector2(11, 22), 18, pencil)

	## Le nom du quartier, coupé en deux lignes s'il déborde de son rectangle.
	func _label(t: String, box: Rect2) -> void:
		var ink := Color(0.12, 0.2, 0.5)
		var fs := 18
		var lines := [t]
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > box.size.x - 6:
			var words := t.split(" ")
			var cut := words.size() / 2
			lines = [" ".join(words.slice(0, cut)), " ".join(words.slice(cut))]
		# En haut du quartier (le milieu est souvent pris par « vous êtes ici »), et toujours dans la feuille.
		var lh := font.get_height(fs)
		var widths := lines.map(func(l): return font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var top := clampf(box.position.y + 4.0, 4.0, size.y - lh * lines.size() - 4.0)
		for i in lines.size():
			var x := clampf(box.get_center().x - widths[i] / 2.0, 4.0, size.x - widths[i] - 4.0)
			_paper(Rect2(x - 3.0, top + i * lh, widths[i] + 6.0, lh))
		for i in lines.size():
			var x := clampf(box.get_center().x - widths[i] / 2.0, 4.0, size.x - widths[i] - 4.0)
			draw_string(font, Vector2(x, top + i * lh + font.get_ascent(fs)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

	## Un mot au crayon sur un fond de papier, pour qu'il se lise par-dessus les traits ; at est le pied du mot.
	func _ink(t: String, at: Vector2, fs: int, color: Color) -> void:
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(clampf(at.x, 4.0, size.x - w - 4.0), clampf(at.y, font.get_ascent(fs) + 4.0, size.y - font.get_descent(fs) - 4.0))
		_paper(Rect2(p.x - 3.0, p.y - font.get_ascent(fs), w + 6.0, font.get_height(fs)))
		draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

	func _paper(r: Rect2) -> void:
		draw_rect(r, Color(0.97, 0.95, 0.88, 0.85))


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
		# Sous le carnet : une fiche arrivée juste avant qu'on l'ouvre ne vient pas sur la page.
		move_child(_slip, 0)
		_slip_label = _text(_slip, "", 17)
		_slip_label.custom_minimum_size.x = 400
	_slip_label.text = text
	_fit_slip()
	# Le texte ne connaît sa hauteur qu'une fois mis en page : on reprend la mesure à l'image suivante.
	_fit_slip.call_deferred()
	_slip.rotation_degrees = -1.5
	_slip.modulate.a = 0.0
	if _slip_tween:
		_slip_tween.kill()
	var tw := create_tween()
	_slip_tween = tw
	tw.tween_property(_slip, "modulate:a", 1.0, 0.3)
	tw.tween_interval(5.0 + text.length() * 0.03)
	tw.tween_property(_slip, "modulate:a", 0.0, 0.8)


## La fiche reprend la taille de son texte, puis se pose en bas à gauche.
func _fit_slip() -> void:
	_slip.reset_size()
	_slip.size = _slip.get_combined_minimum_size()
	_slip.position = Vector2(28, get_viewport().get_visible_rect().size.y - _slip.size.y - 60)
