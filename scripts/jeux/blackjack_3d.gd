extends "res://scripts/jeux/table_3d.gd"
## La table de blackjack : demi-lune d'acajou, boudin de cuir, tapis imprimé en arc, sabot et
## râtelier du croupier. Les cartes sortent du sabot, glissent sur le feutre et se retournent ;
## la carte cachée se retourne en place ; la mise est ramassée ou payée à côté.

const BJ := preload("res://scripts/blackjack_panel.gd")

const R := 1.3
const ZC := -0.4
const S := 640.0

var shoe_at := Vector3(0.82, 0.0, ZC + 0.2)
var _cards: Array[Node3D] = []
var _counts := {}
var _hole: Node3D
var _bet_stack: Node3D
var _double_stack: Node3D
var _labels := {}
var _bet := 0
var _hand := {"player": [], "dealer": []}
var _hole_hidden := false


func _ready() -> void:
	felt_y = 0.79
	shoe_at.y = felt_y
	seat = look(Vector3(0.0, 1.30, 1.15), Vector3(0.0, 0.95, 0.0))
	seat_fov = 56.0
	_build()


func _build() -> void:
	var mahogany := KIT.varnished(Color(0.36, 0.13, 0.06))
	var dark := KIT.varnished(Color(0.14, 0.05, 0.03), 0.7)
	var brass := KIT.brass()
	var leather := KIT.leather()
	var c := Node3D.new()
	c.position = Vector3(0, 0, ZC)
	add_child(c)
	# Le plateau en demi-lune, sa ceinture et son pied.
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(R + 0.02, felt_y - 0.13), Vector2(R + 0.03, felt_y - 0.02), Vector2(R, felt_y - 0.012)]), 64, 1.0, PI), mahogany, c)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(R + 0.035, felt_y - 0.136), Vector2(R + 0.035, felt_y - 0.124)]), 64, 1.0, PI), brass, c)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(R - 0.25, 0.02), Vector2(R - 0.25, felt_y - 0.13)]), 48, 1.0, PI), dark, c)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(R - 0.18, 0.0), Vector2(R - 0.18, 0.04), Vector2(0.0, 0.04)]), 48, 1.0, PI), mahogany, c)
	KIT.box(Vector3(2 * R + 0.06, felt_y - 0.02, 0.12), Vector3(0, (felt_y - 0.02) / 2.0, ZC - 0.05), dark, self)
	KIT.box(Vector3(2 * R + 0.08, 0.02, 0.14), Vector3(0, felt_y - 0.012, ZC - 0.05), mahogany, self)
	# Le tapis.
	var felt := _make_layout()
	var fm := _half_disc(R)
	KIT.mesh_node(fm, KIT.felt(Color(0.03, 0.28, 0.16), Vector2(2 * R, R), felt), c, Vector3(0, felt_y, 0))
	# Le boudin de cuir sur l'arc, terminé par deux pommeaux.
	var prof := PackedVector2Array()
	for k in 17:
		var t := -PI / 2.0 + TAU * k / 16.0
		prof.append(Vector2(R + 0.05, felt_y + 0.035) + Vector2(cos(t) * 0.062, sin(t) * 0.05))
	KIT.mesh_node(KIT.lathe(prof, 72, 1.0, PI), leather, c)
	for x in [-1.0, 1.0]:
		KIT.sphere(0.058, Vector3(x * (R + 0.05), felt_y + 0.035, ZC), leather, self).scale = Vector3(1.0, 0.85, 1.0)
	# Côté croupier : le râtelier, le sabot, la défausse, la plaque des limites.
	var rack := KIT.box(Vector3(0.62, 0.04, 0.17), Vector3(0, felt_y + 0.02, ZC + 0.07), KIT.varnished(Color(0.04, 0.03, 0.03), 1.0), self)
	rack.name = "Ratelier"
	var vals := [500, 100, 25, 10, 5, 25, 100]
	for k in vals.size():
		var s := KIT.chip_stack(vals[k] * 18, [vals[k]], 18)
		s.position = Vector3(-0.255 + k * 0.085, felt_y + 0.04, ZC + 0.07)
		add_child(s)
	var shoe := Node3D.new()
	shoe.position = shoe_at + Vector3(0, 0, -0.04)
	shoe.rotation.y = -0.5
	add_child(shoe)
	KIT.box(Vector3(0.13, 0.09, 0.3), Vector3(0, 0.045, 0), KIT.varnished(Color(0.05, 0.04, 0.04), 1.0), shoe)
	var lip := KIT.box(Vector3(0.12, 0.05, 0.05), Vector3(0, 0.035, 0.16), KIT.varnished(Color(0.05, 0.04, 0.04), 1.0), shoe)
	lip.rotation.x = 0.5
	KIT.box(Vector3(0.132, 0.012, 0.302), Vector3(0, 0.091, 0), brass, shoe)
	var back := KIT.card(0, 0)
	back.rotation.z = PI
	back.rotation.x = -0.35
	back.position = Vector3(0, 0.07, 0.13)
	shoe.add_child(back)
	var discard := Node3D.new()
	discard.position = Vector3(-0.82, felt_y, ZC + 0.18)
	discard.rotation.y = 0.5
	add_child(discard)
	KIT.box(Vector3(0.1, 0.07, 0.13), Vector3(0, 0.035, 0), KIT.mat(Color(0.75, 0.85, 0.95, 0.3), 0.05), discard).material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var plate := KIT.box(Vector3(0.16, 0.08, 0.01), Vector3(-0.42, felt_y + 0.04, ZC + 0.02), brass, self)
	plate.rotation.x = -0.4
	var pl := Label3D.new()
	pl.text = "Mise\n5 à 500"
	pl.font = KIT.serif()
	pl.font_size = 28
	pl.pixel_size = 0.0012
	pl.modulate = Color(0.12, 0.06, 0.03)
	pl.outline_size = 0
	pl.position = Vector3(0, 0, 0.006)
	plate.add_child(pl)
	if with_lamp:
		KIT.table_spot(self, Vector3(0, 2.6, 0.25), Vector3(0, felt_y, 0.15), 2.2, 45.0)


## Un demi-disque (côté +z), UV à plat : u sur la largeur 2R, v sur la profondeur R.
func _half_disc(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 72
	for k in n:
		var a0 := PI * k / n
		var a1 := PI * (k + 1) / n
		var p := [Vector3.ZERO, Vector3(cos(a0) * r, 0, sin(a0) * r), Vector3(cos(a1) * r, 0, sin(a1) * r)]
		var uv := []
		for q in p:
			uv.append(Vector2((q.x + r) / (2.0 * r), q.z / r))
		KIT._tri(st, p, [Vector3.UP, Vector3.UP, Vector3.UP], uv, 0, 1, 2)
	return st.commit()


## Le tapis : deux arcs, les annonces écrites en courbe, les cinq cercles de mise.
func _make_layout() -> Texture2D:
	var cle := "blackjack"
	if KIT.vue_partagee(cle):
		return KIT.vue_partagee(cle)
	var vp := SubViewport.new()
	vp.size = Vector2i(int(2 * R * S), int(R * S))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cv := Control.new()
	cv.size = Vector2(vp.size)
	vp.add_child(cv)
	cv.draw.connect(func():
		var o := Vector2(R * S, 0)
		var ink := Color(0.95, 0.91, 0.79)
		var gold := Color(0.93, 0.74, 0.38)
		cv.draw_arc(o, R * S * 0.93, 0.0, PI, 128, gold, 5.0, true)
		cv.draw_arc(o, R * S * 0.56, 0.12, PI - 0.12, 96, ink, 3.0, true)
		cv.draw_arc(o, R * S * 0.415, 0.22, PI - 0.22, 96, ink, 3.0, true)
		_arc_text(cv, o, R * S * 0.505, "LE BLACKJACK PAIE 3 CONTRE 2", 34, gold)
		_arc_text(cv, o, R * S * 0.455, "Le croupier reste sur 17", 26, ink)
		_arc_text(cv, o, R * S * 0.35, "CASINO DE SMARVES", 26, Color(gold, 0.8))
		for k in 5:
			var a := PI * (0.2 + 0.6 * k / 4.0)
			var p := o + Vector2(cos(a), sin(a)) * R * S * 0.78
			cv.draw_arc(p, 46, 0, TAU, 48, gold, 4.0, true)
			cv.draw_arc(p, 38, 0, TAU, 48, Color(ink, 0.6), 2.0, true)
	)
	return KIT.partager(cle, vp)


## Du texte posé sur un arc (centre en haut de la texture), lisible depuis les joueurs.
static func _arc_text(c: Control, o: Vector2, radius: float, text: String, size: int, col: Color) -> void:
	var f := KIT.serif()
	var widths := []
	var total := 0.0
	for ch in text:
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		widths.append(w)
		total += w
	var a := PI / 2.0 + total / radius / 2.0
	for i in text.length():
		var w: float = widths[i]
		var mid := a - w / radius / 2.0
		var p := o + Vector2(cos(mid), sin(mid)) * radius
		c.draw_set_transform(p, mid - PI / 2.0, Vector2.ONE)
		c.draw_string(f, Vector2(-w / 2.0, size * 0.35), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		a -= w / radius
	c.draw_set_transform(Vector2.ZERO)


# --- Les gestes ---------------------------------------------------------------------------

func _spot(who: String, k: int) -> Vector3:
	if who == "dealer":
		return Vector3(-0.1 + k * 0.1, felt_y, ZC + 0.3)
	# Les cartes du joueur se chevauchent en escalier, devant son cercle.
	return Vector3(-0.05 + k * 0.034, felt_y + k * 0.0012, ZC + 0.84 - k * 0.022)


func _clear() -> void:
	for c in _cards:
		var t := c.create_tween()
		t.tween_property(c, "position", Vector3(-0.82, felt_y + 0.06, ZC + 0.18), 0.4).set_trans(Tween.TRANS_CUBIC)
		t.tween_callback(c.queue_free)
	_cards.clear()
	_counts = {"player": 0, "dealer": 0}
	_hand = {"player": [], "dealer": []}
	_hole = null
	for k in _labels:
		_labels[k].queue_free()
	_labels.clear()


func deal(who: String, c: Dictionary, hidden: bool) -> void:
	schedule(0.42, func(): _deal_now(who, c, hidden))


func _deal_now(who: String, c: Dictionary, hidden: bool) -> void:
	var k: int = _counts.get(who, 0)
	_counts[who] = k + 1
	var card := KIT.card(int(c.r), int(c.s))
	add_child(card)
	_cards.append(card)
	var start := shoe_at + Vector3(-0.03, 0.06, 0.12)
	var dest := _spot(who, k)
	card.position = start
	card.rotation = Vector3(0, -0.5, PI)
	var yaw := randf_range(-0.05, 0.05)
	var tw := card.create_tween().set_parallel()
	tw.tween_method(func(t: float):
		card.position = start.lerp(dest, t) + Vector3(0, sin(t * PI) * 0.05, 0), 0.0, 1.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "rotation", Vector3(0, yaw, PI if hidden else 0.0), 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("card", -4.0, randf_range(0.95, 1.1))
	if hidden:
		_hole = card
		_hole_hidden = true
	else:
		_hand[who].append(c)
	tw.chain().tween_callback(func(): _show_total(who))


func reveal(c: Dictionary) -> void:
	schedule(0.5, func():
		if _hole == null:
			return
		var card := _hole
		_hole_hidden = false
		_hand["dealer"].insert(1, c)
		var p := card.position
		var tw := card.create_tween()
		tw.tween_property(card, "position", p + Vector3(0, 0.06, 0), 0.15)
		tw.parallel().tween_property(card, "rotation:z", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(card, "position", p, 0.12)
		tw.tween_callback(func(): _show_total("dealer"))
		Sfx.play("card", -2.0, 0.9))


func _show_total(who: String) -> void:
	var t := BJ.total(_hand[who])
	if _hand[who].is_empty():
		return
	var text := str(t)
	if who == "dealer" and _hole_hidden:
		text = str(t) + " + ?"
	if not _labels.has(who):
		var l := Label3D.new()
		l.font = KIT.serif()
		l.font_size = 64
		l.pixel_size = 0.0007
		l.outline_size = 12
		l.outline_modulate = Color(0.05, 0.02, 0.02, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		add_child(l)
		_labels[who] = l
	var lab: Label3D = _labels[who]
	lab.text = text
	lab.modulate = Color(1.0, 0.45, 0.4) if t > 21 else (Color(1.0, 0.86, 0.45) if t == 21 else Color(0.97, 0.94, 0.86))
	var n: int = _counts[who]
	lab.position = _spot(who, n - 1) + Vector3(0.11, 0.03, 0.0)


func _place_bet(amount: int) -> void:
	if _bet_stack:
		_bet_stack.queue_free()
	_bet_stack = KIT.chip_stack(amount, [500, 100, 25, 10, 5, 1])
	_bet_stack.position = Vector3(0, felt_y + 0.04, ZC + R * 0.78)
	add_child(_bet_stack)
	create_tween().tween_property(_bet_stack, "position:y", felt_y + 0.0005, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Sfx.play("chips", -6.0)


func _double(amount: int) -> void:
	_double_stack = KIT.chip_stack(amount, [500, 100, 25, 10, 5, 1])
	_double_stack.position = Vector3(0.06, felt_y + 0.04, ZC + R * 0.78 + 0.02)
	add_child(_double_stack)
	create_tween().tween_property(_double_stack, "position:y", felt_y + 0.0005, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Sfx.play("chips", -6.0)


func result(bet: int, payout: int) -> void:
	schedule(1.6, func():
		var stacks: Array[Node3D] = []
		for s in [_bet_stack, _double_stack]:
			if s != null:
				stacks.append(s)
		_bet_stack = null
		_double_stack = null
		var tray := Vector3(0, felt_y + 0.04, ZC + 0.07)
		var mine := Vector3(0.0, felt_y, ZC + R + 0.1)
		if payout > bet:
			var paid := KIT.chip_stack(payout - bet, [500, 100, 25, 10, 5, 1])
			paid.position = tray
			add_child(paid)
			var d := Vector3(-0.065, felt_y, ZC + R * 0.78)
			var t := paid.create_tween()
			t.tween_property(paid, "position", d, 0.5).set_trans(Tween.TRANS_CUBIC)
			t.tween_interval(0.6)
			t.tween_property(paid, "position", mine, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t.tween_callback(paid.queue_free)
			Sfx.play("chips_win", -2.0)
			var natural: bool = _hand["player"].size() == 2 and BJ.total(_hand["player"]) == 21
			KIT.burst(self, d + Vector3(0, 0.03, 0), 160 if natural else 80, 0.5, natural)
			KIT.flash(self, d + Vector3(0, 0.4, 0), 5.0 if natural else 3.0)
			KIT.popup(self, d + Vector3(0, 0.16, 0), ("BLACKJACK !  + %s" if natural else "+ %s") % Game.fmt(payout - bet), 96)
		for s in stacks:
			var t := s.create_tween()
			if payout >= bet and payout > 0:
				t.tween_interval(1.1)
				t.tween_property(s, "position", mine, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			else:
				t.tween_property(s, "position", tray, 0.55).set_trans(Tween.TRANS_CUBIC)
				t.parallel().tween_property(s, "scale", Vector3.ONE * 0.4, 0.55)
			t.tween_callback(s.queue_free))


# --- Lien avec le panneau ------------------------------------------------------------------

func attach(p: Control) -> void:
	panel = p
	p.embedded = true
	p.table3d = self
	p.hand_started.connect(func():
		var amount: int = p.bet
		_bet = amount
		schedule(0.5, func():
			_clear()
			_place_bet(amount)))
	p.card_dealt.connect(func(who: String, c: Dictionary, hidden: bool):
		if who == "player" and p.bet > _bet:
			_double(p.bet - _bet)
			_bet = p.bet
		deal(who, c, hidden))
	p.hole_revealed.connect(reveal)
	p.played.connect(result)
