extends "res://scripts/jeux/table_3d.gd"
## La table ronde du Poker des Ambassadeurs : pied tourné, ceinture d'acajou, boudin de cuir, tapis
## imprimé. Chacun a ses deux cartes devant lui et ses plaques sur la ligne de mise ; le tableau se
## retourne au centre, les mises glissent au pot à chaque rue, le bouton du donneur fait le tour.
## À l'abattage, les mains encore en jeu se retournent et le pot part vers le gagnant.
## Repère : le joueur est assis en +z ; la place i du panneau est à 60° × i autour de l'axe vertical.

const POKER := preload("res://scripts/poker_panel.gd")

const R := 1.42
const SEAT_R := 1.85
## Les cartes sont plus grandes que nature : de la place du joueur, une carte de 9 cm au centre
## d'une table de près de trois mètres ne se lirait pas.
const BOARD_SCALE := 1.6
const BOARD_X := -0.38
const BOARD_STEP := 0.19
const POT_AT := Vector3(0.0, 0.0, -0.46)

## Ce qu'imprime le tapis, et sa couleur : les Ambassadeurs par défaut ; la table du Miosson, dans la
## Salle des jeux, a les siens (à poser avant que la table entre dans la scène).
var nom_tapis := "POKER DES AMBASSADEURS"
var ligne_tapis := "BLINDES 25 / 50  ·  CASINO DE SMARVES"
const LIGNE_PAR_DEFAUT := "BLINDES 25 / 50  ·  CASINO DE SMARVES"
var couleur_tapis := Color(0.03, 0.09, 0.2)

var _hole := {}             # place -> [carte, carte]
var _board: Array[Node3D] = []
var _bets := {}             # place -> pile de plaques
var _pot: Node3D
var _pot_amount := 0
var _button: Node3D
var _tags := {}             # place -> étiquette (PanelContainer à l'écran)
var _tag_layer: CanvasLayer
## Ce que chaque main montrée à l'abattage contenait (« deux paires »).
var _shown_hand := {}
var _shown := false
var _tapis: MeshInstance3D


func _ready() -> void:
	felt_y = 0.79
	seat = look(Vector3(0.0, 1.36, 1.5), Vector3(0.0, felt_y, -0.32))
	seat_fov = 58.0
	_build()


static func _dir(i: int) -> Vector3:
	var a := deg_to_rad(60.0 * i)
	return Vector3(sin(a), 0.0, cos(a))


func _at(i: int, r: float, side := 0.0) -> Vector3:
	var d := _dir(i)
	var t := Vector3(d.z, 0.0, -d.x)
	return d * r + t * side + Vector3(0, felt_y, 0)


func _button_spot(i: int) -> Vector3:
	return _at(i, 0.95, 0.24) if i != 0 else _at(0, 0.62, 0.3)


# --- La table -------------------------------------------------------------------------------

func _build() -> void:
	var mahogany := KIT.varnished(Color(0.36, 0.13, 0.06))
	var dark := KIT.varnished(Color(0.14, 0.05, 0.03), 0.7)
	var brass := KIT.brass()
	# Le pied tourné sur son patin, puis la ceinture, le jonc de laiton et le boudin de cuir.
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(0.62, 0.0), Vector2(0.62, 0.05), Vector2(0.3, 0.1), Vector2(0.17, 0.22),
		Vector2(0.14, felt_y - 0.38), Vector2(0.22, felt_y - 0.26), Vector2(0.5, felt_y - 0.2), Vector2(0.0, felt_y - 0.2)]), 48), mahogany, self)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(R + 0.15, felt_y - 0.16), Vector2(R + 0.16, felt_y - 0.05), Vector2(R + 0.12, felt_y - 0.01),
		Vector2(R, felt_y - 0.004), Vector2(R - 0.4, felt_y - 0.004)]), 96), mahogany, self)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(R + 0.162, felt_y - 0.16), Vector2(R + 0.162, felt_y - 0.146)]), 96), brass, self)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(R + 0.06, felt_y - 0.16), Vector2(R + 0.06, felt_y - 0.2), Vector2(0.5, felt_y - 0.2)]), 96), dark, self)
	var prof := PackedVector2Array()
	for k in 17:
		var t := -PI / 2.0 + TAU * k / 16.0
		prof.append(Vector2(R + 0.105, felt_y + 0.03) + Vector2(cos(t) * 0.06, sin(t) * 0.045))
	KIT.mesh_node(KIT.lathe(prof, 96), KIT.leather(Color(0.1, 0.05, 0.035)), self)
	_tapis = KIT.mesh_node(KIT.disc(R, 96), KIT.felt(couleur_tapis, Vector2(2.0 * R, 2.0 * R), _make_layout()), self, Vector3(0, felt_y, 0))
	# Le bouton du donneur.
	_button = Node3D.new()
	add_child(_button)
	KIT.cyl(0.035, 0.01, Vector3(0, 0.005, 0), KIT.mat(Color(0.93, 0.91, 0.86), 0.35), _button)
	var d := Label3D.new()
	d.text = "D"
	d.font = KIT.serif()
	d.font_size = 48
	d.pixel_size = 0.0008
	d.modulate = Color(0.12, 0.08, 0.06)
	d.rotation.x = -PI / 2.0
	d.position = Vector3(0, 0.0105, 0)
	_button.add_child(d)
	_button.position = _button_spot(0)
	for i in 6:
		_tag(i)
	if with_lamp:
		KIT.table_spot(self, Vector3(0.0, 2.7, 0.0), Vector3(0.0, felt_y, 0.0), 2.0, 56.0).light_specular = 0.15


## Le tapis imprimé : le filet d'or, la ligne de mise, les cinq cases du tableau, le nom de la salle.
func _make_layout() -> Texture2D:
	var cle := "poker" if nom_tapis == "POKER DES AMBASSADEURS" and ligne_tapis == LIGNE_PAR_DEFAUT else "poker:%s|%s" % [nom_tapis, ligne_tapis]
	if KIT.vue_partagee(cle):
		return KIT.vue_partagee(cle)
	var S := 700.0
	var vp := SubViewport.new()
	var px := int(2.0 * R * S)
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	c.draw.connect(func():
		var ink := Color(0.95, 0.91, 0.79)
		var gold := Color(0.93, 0.74, 0.38)
		var f := KIT.serif()
		var mid := Vector2(px, px) / 2.0
		c.draw_arc(mid, (R - 0.05) * S, 0, TAU, 160, gold, 4.0, true)
		c.draw_arc(mid, 0.82 * S, 0, TAU, 160, Color(gold, 0.45), 2.5, true)
		for k in 5:
			var r := Rect2(mid + Vector2((BOARD_X + k * BOARD_STEP) * S - 0.075 * S, -0.1 * S), Vector2(0.15, 0.2) * S)
			c.draw_rect(r, Color(ink, 0.5), false, 3.0)
		c.draw_string(f, mid + Vector2(-0.6 * S, -0.3 * S), nom_tapis, HORIZONTAL_ALIGNMENT_CENTER, 1.2 * S, 46, gold)
		c.draw_string(f, mid + Vector2(-0.6 * S, 0.27 * S), ligne_tapis, HORIZONTAL_ALIGNMENT_CENTER, 1.2 * S, 24, Color(gold, 0.75))
	)
	return KIT.partager(cle, vp)


## Le tapis imprime les blindes de la table : celles que le panneau a reçues (configurer_blindes) remplacent
## celles écrites en tête de ligne_tapis, pour ne jamais afficher un faux tarif.
func _blindes_du_panneau(p: Control) -> void:
	if not ("SB" in p and "BB" in p) or not ligne_tapis.begins_with("BLINDES "):
		return
	var blindes := "BLINDES %d / %d" % [p.SB, p.BB]
	var reste := ligne_tapis.substr(ligne_tapis.find("  ·  ")) if ligne_tapis.contains("  ·  ") else ""
	if ligne_tapis == blindes + reste:
		return
	ligne_tapis = blindes + reste
	if _tapis and _tapis.material_override is ShaderMaterial:
		_tapis.material_override.set_shader_parameter("layout_tex", _make_layout())


## L'étiquette d'une place : une pastille sombre à l'écran, posée sur le bord de la table devant
## chacun. Le fond la garde lisible même devant une chemise claire.
func _tag(i: int) -> void:
	if _tag_layer == null:
		_tag_layer = CanvasLayer.new()
		_tag_layer.layer = 1
		add_child(_tag_layer)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.035, 0.8)
	sb.border_color = Color(0.89, 0.71, 0.35, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.add_theme_font_override("font", KIT.serif())
	l.add_theme_font_size_override("font_size", 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(l)
	pc.visible = false
	_tag_layer.add_child(pc)
	_tags[i] = pc


func _process(delta: float) -> void:
	super(delta)
	if _tag_layer == null:
		return
	for i in _tags:
		var pc: PanelContainer = _tags[i]
		var show: bool = active and cam != null and i != 0
		var at := to_global(_at(i, R + 0.02) + Vector3(0, 0.1, 0))
		if show and cam.is_position_behind(at):
			show = false
		pc.visible = show
		if show:
			var sp := cam.unproject_position(at)
			pc.reset_size()
			pc.position = sp - Vector2(pc.size.x / 2.0, pc.size.y)


# --- Les cartes -----------------------------------------------------------------------------

## Les deux cartes d'une place : côte à côte devant le joueur, un peu de biais devant les autres.
func _hole_spot(i: int, k: int) -> Vector3:
	if i == 0:
		return _at(0, 0.5, -0.085 + k * 0.17) + Vector3(0, 0.001 + k * 0.0006, 0)
	return _at(i, 1.1, -0.04 + k * 0.08) + Vector3(0, 0.001 + k * 0.0006, 0)


func _deal_card(c: Dictionary, dest: Vector3, yaw: float, face_up: bool, tilt := 0.0, size := BOARD_SCALE) -> Node3D:
	var card := KIT.card((int(c.r) + 1) % 13, int(c.s))
	card.scale = Vector3.ONE * size
	add_child(card)
	var start := Vector3(0.0, felt_y + 0.08, -0.2)
	card.position = start
	card.rotation = Vector3(0, yaw + 1.2, PI)
	var tw := card.create_tween().set_parallel()
	tw.tween_method(func(t: float):
		card.position = start.lerp(dest, t) + Vector3(0, sin(t * PI) * 0.06, 0), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "rotation", Vector3(tilt, yaw, 0.0 if face_up else PI), 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("card", -6.0, randf_range(0.95, 1.1))
	return card


func _deal_hands() -> void:
	_clear_all()
	for k in 2:
		for n in 6:
			var i: int = (panel.dealer + 1 + n) % 6
			var c: Dictionary = panel.seats[i].cards[k]
			schedule(0.11, func():
				var yaw := deg_to_rad(60.0 * i) + randf_range(-0.05, 0.05)
				var card := _deal_card(c, _hole_spot(i, k), yaw, i == 0, 0.0, BOARD_SCALE if i == 0 else 1.35)
				card.set_meta("c", c)
				_hole[i] = _hole.get(i, []) + [card])
	# Les deux cartes du joueur arrivent : il les soulève du coin pour les regarder.
	schedule(0.5, func():
		for card: Node3D in _hole.get(0, []):
			var tw := card.create_tween()
			tw.tween_property(card, "rotation:x", -0.35, 0.2).set_trans(Tween.TRANS_CUBIC)
			tw.tween_interval(0.5)
			tw.tween_property(card, "rotation:x", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC))


func _deal_board(cards: Array) -> void:
	schedule(0.3, func(): shot(look(Vector3(0.0, 1.3, 1.05), Vector3(0.0, felt_y, -0.1)), 0.6, 54.0))
	for c in cards:
		var k := _board.size()
		_board.append(null)
		schedule(0.34, func():
			var card := _deal_card(c, Vector3(BOARD_X + k * BOARD_STEP, felt_y + 0.001, 0.0), 0.0, true)
			_board[k] = card)
	schedule(0.9, func(): shot(seat, 0.7, seat_fov))


## Les mains encore en jeu se retournent.
func _reveal() -> void:
	# Le panneau a pu fermer pendant que le geste attendait son tour : plus de mains à lire.
	if not is_instance_valid(panel):
		return
	for i in _hole:
		if i == 0 or panel.seats[i].folded:
			continue
		_shown_hand[i] = POKER.CATEGORIES[POKER.evaluate(panel.seats[i].cards + panel.board)[0]].to_lower()
		# Au poker à plusieurs, les cartes des autres ont été servies de dos sans leur valeur (le serveur
		# ne la donne qu'à l'abattage) : elles prennent ici leur vraie figure avant de se retourner.
		var cards: Array = panel.seats[i].cards
		for j in mini(_hole[i].size(), cards.size()):
			var old: Node3D = _hole[i][j]
			var c: Dictionary = cards[j]
			if old.get_meta("c", {}) == c:
				continue
			var fresh := KIT.card((int(c.r) + 1) % 13, int(c.s))
			fresh.transform = old.transform
			fresh.set_meta("c", c)
			add_child(fresh)
			old.queue_free()
			_hole[i][j] = fresh
		# Les cartes montrées s'avancent vers le centre et grandissent : lisibles depuis sa place.
		var k := 0
		for card: Node3D in _hole[i]:
			var dest := _at(i, 0.86, -0.085 + k * 0.17) + Vector3(0, 0.001 + k * 0.0006, 0)
			var tw := card.create_tween().set_parallel()
			tw.tween_property(card, "position", dest, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(card, "scale", Vector3.ONE * BOARD_SCALE, 0.4)
			k += 1
	_refresh()
	Sfx.play("card", -2.0, 0.9)


func _muck(i: int) -> void:
	for card: Node3D in _hole.get(i, []):
		var t := card.create_tween().set_parallel()
		t.tween_property(card, "position", Vector3(0.5, felt_y + 0.003, -0.55), 0.4).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(card, "rotation", Vector3(0, randf_range(-1.0, 1.0), PI), 0.4)
		t.chain().tween_property(card, "scale", Vector3.ONE * 0.01, 0.25)
		t.chain().tween_callback(card.queue_free)
	_hole.erase(i)


func _clear_all() -> void:
	for i in _hole.keys():
		_muck(i)
	for card in _board:
		if card and is_instance_valid(card):
			var t := card.create_tween()
			t.tween_property(card, "position", Vector3(0.5, felt_y + 0.003, -0.55), 0.4).set_trans(Tween.TRANS_CUBIC)
			t.tween_callback(card.queue_free)
	_board.clear()
	_shown = false
	_shown_hand.clear()


# --- Les plaques ---------------------------------------------------------------------------

func _set_bet(i: int, amount: int) -> void:
	var cur: Node3D = _bets.get(i)
	if cur and is_instance_valid(cur) and int(cur.get_meta("amount")) == amount:
		return
	if cur and is_instance_valid(cur):
		cur.queue_free()
	_bets.erase(i)
	if amount <= 0:
		return
	var s := KIT.chip_stack(amount, [1000, 500, 100, 25], 10)
	s.scale = Vector3.ONE * 1.3
	s.set_meta("amount", amount)
	var p := _at(i, 0.74) if i != 0 else _at(0, 0.42, 0.25)
	s.position = p + Vector3(0, 0.03, 0)
	add_child(s)
	_bets[i] = s
	create_tween().tween_property(s, "position:y", p.y + 0.0005, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Sfx.play("chips", -8.0, randf_range(0.95, 1.1))


## Fin de rue : les mises glissent au pot.
func _sweep_bets() -> void:
	var dest := POT_AT + Vector3(0, felt_y, 0)
	if not _bets.is_empty():
		Sfx.play("chips", -6.0)
	for i in _bets.keys():
		var s: Node3D = _bets[i]
		if not is_instance_valid(s):
			continue
		var t := s.create_tween()
		t.tween_property(s, "position", dest, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.tween_callback(s.queue_free)
	_bets.clear()
	get_tree().create_timer(0.36).timeout.connect(_set_pot.bind(panel.pot))


func _set_pot(amount: int) -> void:
	if not is_inside_tree() or amount == _pot_amount:
		return
	_pot_amount = amount
	if _pot and is_instance_valid(_pot):
		_pot.queue_free()
	_pot = null
	if amount <= 0:
		return
	_pot = Node3D.new()
	_pot.scale = Vector3.ONE * 1.4
	_pot.position = POT_AT + Vector3(0, felt_y + 0.0005, 0)
	add_child(_pot)
	# Le pot en deux ou trois piles, comme le croupier les rassemble.
	var parts := KIT.breakdown(amount, [5000, 1000, 500, 100, 25], 12)
	var groups := {}
	for v in parts:
		groups[v] = groups.get(v, 0) + v
	var x := -0.03 * (groups.size() - 1)
	for v in groups:
		var s := KIT.chip_stack(groups[v], [v], 12)
		s.position = Vector3(x, 0, randf_range(-0.01, 0.01))
		_pot.add_child(s)
		x += 0.06


# --- Lien avec le panneau ------------------------------------------------------------------

func _refresh() -> void:
	if panel == null:
		return
	for i in 6:
		var s: Dictionary = panel.seats[i]
		if s.get("folded", false) and _hole.has(i) and not _shown:
			_muck(i)
		_set_bet(i, int(s.get("bet", 0)) if panel.in_hand else 0)
		var l: Label = _tags[i].get_child(0)
		if s.ai:
			var state := ""
			if _shown_hand.has(i):
				state = "  ·  " + _shown_hand[i]
			elif s.get("folded", false) and panel.in_hand:
				state = "  ·  couché"
			elif panel.in_hand and int(s.get("bet", 0)) > 0:
				state = "  ·  mise %s" % Game.fmt(int(s.bet))
			# À la table à plusieurs, les habitués jouent la bourse de la maison : leur nom suffit.
			if s.get("human", true) == false:
				l.text = "%s%s" % [s.name, ("\n" + state.trim_prefix("  ·  ")) if state != "" else ""]
			else:
				l.text = "%s\n%s%s" % [s.name, Game.fmt(int(s.stack)), state]
		var lit: bool = panel.turn == i
		l.modulate = Color(1.0, 0.85, 0.45) if lit else (Color(0.6, 0.58, 0.55) if s.get("folded", false) and panel.in_hand else Color(0.96, 0.93, 0.86))
	if panel.in_hand:
		var target := _button_spot(panel.dealer)
		if _button.position.distance_to(target) > 0.01:
			create_tween().tween_property(_button, "position", target, 0.5).set_trans(Tween.TRANS_CUBIC)


func _on_showdown(winners: Array, show_all: bool, amount: int) -> void:
	_shown = true
	if show_all:
		schedule(0.5, _reveal)
		schedule(0.6, func(): shot(look(Vector3(0.0, 2.2, 1.45), Vector3(0.0, felt_y, -0.15)), 0.7, 66.0))
	schedule(1.3, func():
		if not is_instance_valid(panel):
			return
		var names: Array[String] = []
		for w in winners:
			names.append("Vous" if w == 0 else panel.seats[w].name)
		var cat := ""
		if show_all:
			var e: Array = POKER.evaluate(panel.seats[winners[0]].cards + panel.board)
			cat = "  ·  " + POKER.CATEGORIES[e[0]].to_lower()
		KIT.popup(self, Vector3(0.0, felt_y + 0.1, 0.3), "%s%s" % [" et ".join(names), cat], 52, Color(1.0, 0.9, 0.66), 2.0))
	schedule(0.8, func():
		# Le pot part vers le ou les gagnants.
		var pot := _pot
		_pot = null
		_pot_amount = 0
		if pot == null or not is_instance_valid(pot):
			return
		var dest := _at(winners[0], 0.95) + Vector3(0, 0.0005, 0)
		var t := pot.create_tween()
		t.tween_property(pot, "position", dest, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.tween_interval(0.9)
		t.tween_property(pot, "scale", Vector3.ONE * 0.01, 0.3)
		t.tween_callback(pot.queue_free)
		if 0 in winners:
			var gain := amount / winners.size()
			Sfx.play("chips_win", -2.0)
			KIT.burst(self, dest + Vector3(0, 0.02, 0), 80 if gain < 5000 else 160, 0.5)
			KIT.flash(self, dest + Vector3(0, 0.4, 0), 3.0 if gain < 5000 else 6.0)
			KIT.popup(self, dest + Vector3(0, 0.15, 0.05), "+ %s" % Game.fmt(gain), 110)
		else:
			Sfx.play("chips", -4.0))
	schedule(1.2, func(): shot(seat, 0.8, seat_fov))


func attach(p: Control) -> void:
	panel = p
	_blindes_du_panneau(p)
	p.embedded = true
	p.table3d = self
	p.hand_started.connect(_deal_hands)
	p.board_dealt.connect(_deal_board)
	p.street_ended.connect(_sweep_bets)
	p.showdown.connect(_on_showdown)
	p.changed.connect(_refresh)
