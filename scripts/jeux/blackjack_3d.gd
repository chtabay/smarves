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
var _labels := {}
var _hand := {"dealer": []}
## Les mains du joueur, une ou plusieurs après un partage : {cartes, noeuds, label, piles}. Les piles sont
## la mise de la main, et son doublement.
var _mains: Array = []
## L'assurance posée sur la ligne, ou null.
var _pile_assurance: Node3D
var _hole_hidden := false
var _plaque: Label3D


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
	_plaque = pl
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

## Le centre d'une main du joueur : une seule devant son cercle ; après un partage, côte à côte.
func _x_main(h: int) -> float:
	var n := maxi(_mains.size(), 1)
	return -0.05 + (h - (n - 1) / 2.0) * 0.3


func _spot(who: String, k: int) -> Vector3:
	if who == "dealer":
		return Vector3(-0.1 + k * 0.1, felt_y, ZC + 0.3)
	# Les cartes du joueur se chevauchent en escalier, devant son cercle.
	return Vector3(_x_main(_main_de(who)) + k * 0.034, felt_y + k * 0.0012, ZC + 0.84 - k * 0.022)


## « player » est la première main, « player1 » la deuxième, et ainsi de suite.
static func _main_de(who: String) -> int:
	return 0 if who == "player" else int(who.trim_prefix("player"))


func _main(h: int) -> Dictionary:
	while _mains.size() <= h:
		_mains.append({"cartes": [], "noeuds": [], "label": null, "piles": []})
	return _mains[h]


func _pile_at(h: int, k: int) -> Vector3:
	return Vector3(_x_main(h) + 0.05 + k * 0.06, felt_y + 0.0005, ZC + R * 0.78 + k * 0.02)


func _clear() -> void:
	for c in _cards:
		var t := c.create_tween()
		t.tween_property(c, "position", Vector3(-0.82, felt_y + 0.06, ZC + 0.18), 0.4).set_trans(Tween.TRANS_CUBIC)
		t.tween_callback(c.queue_free)
	_cards.clear()
	_counts = {"dealer": 0}
	_hand = {"dealer": []}
	_hole = null
	for k in _labels:
		_labels[k].queue_free()
	_labels.clear()
	for m in _mains:
		if m.label:
			m.label.queue_free()
	_mains.clear()


func deal(who: String, c: Dictionary, hidden: bool) -> void:
	schedule(0.42, func(): _deal_now(who, c, hidden))


func _deal_now(who: String, c: Dictionary, hidden: bool) -> void:
	var k: int
	if who == "dealer":
		k = _counts.get("dealer", 0)
		_counts["dealer"] = k + 1
	else:
		k = _main(_main_de(who)).noeuds.size()
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
	elif who == "dealer":
		_hand["dealer"].append(c)
	else:
		var m := _main(_main_de(who))
		m.cartes.append(c)
		m.noeuds.append(card)
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


## Le partage : la seconde carte de la main « from » glisse à droite et forme la main « to », avec sa mise ;
## toutes les mains se rangent côte à côte.
func split(from: int, to: int, amount: int) -> void:
	schedule(0.5, func():
		var m := _main(from)
		if m.noeuds.is_empty():
			return
		var nouvelle := {"cartes": [m.cartes.pop_back()], "noeuds": [m.noeuds.pop_back()], "label": null, "piles": []}
		_mains.insert(to, nouvelle)
		Sfx.play("card", -4.0, 1.05)
		_pile(to, amount)
		_ranger())


## Toutes les mains du joueur reprennent leur place (après un partage) : cartes, totaux, mises.
func _ranger() -> void:
	for h in _mains.size():
		var m: Dictionary = _mains[h]
		for k in m.noeuds.size():
			var n: Node3D = m.noeuds[k]
			n.create_tween().tween_property(n, "position", _spot(_who(h), k), 0.3).set_trans(Tween.TRANS_CUBIC)
		for k in m.piles.size():
			var pile: Node3D = m.piles[k]
			if is_instance_valid(pile):
				pile.create_tween().tween_property(pile, "position", _pile_at(h, k), 0.3).set_trans(Tween.TRANS_CUBIC)
		if m.label:
			m.label.queue_free()
			m.label = null
		_show_total(_who(h))


static func _who(h: int) -> String:
	return "player" if h == 0 else "player%d" % h


func _show_total(who: String) -> void:
	var cartes: Array = _hand["dealer"] if who == "dealer" else _main(_main_de(who)).cartes
	if cartes.is_empty():
		return
	var t := BJ.total(cartes)
	var text := str(t)
	if who == "dealer" and _hole_hidden:
		text = str(t) + " + ?"
	var lab: Label3D = _labels.get("dealer") if who == "dealer" else _main(_main_de(who)).label
	if lab == null:
		lab = Label3D.new()
		lab.font = KIT.serif()
		lab.font_size = 64
		lab.pixel_size = 0.0007
		lab.outline_size = 12
		lab.outline_modulate = Color(0.05, 0.02, 0.02, 0.9)
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		add_child(lab)
		if who == "dealer":
			_labels["dealer"] = lab
		else:
			_main(_main_de(who)).label = lab
	lab.text = text
	lab.modulate = Color(1.0, 0.45, 0.4) if t > 21 else (Color(1.0, 0.86, 0.45) if t == 21 else Color(0.97, 0.94, 0.86))
	var n: int = _counts.get("dealer", 0) if who == "dealer" else cartes.size()
	lab.position = _spot(who, n - 1) + Vector3(0.11, 0.03, 0.0)


## Une pile de plaques pour la main h : sa mise, puis son doublement à côté.
func _pile(h: int, amount: int) -> void:
	var m := _main(h)
	var k: int = m.piles.size()
	var s := KIT.chip_stack(amount, [500, 100, 25, 10, 5, 1])
	var at := _pile_at(h, k)
	s.position = at + Vector3(0, 0.04, 0)
	add_child(s)
	m.piles.append(s)
	create_tween().tween_property(s, "position:y", at.y, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Sfx.play("chips", -6.0)


func _place_bet(amount: int) -> void:
	_pile(0, amount)


## L'assurance : une pile sur la ligne, entre le croupier et la mise.
func _assurer(amount: int) -> void:
	schedule(0.3, func():
		_pile_assurance = KIT.chip_stack(amount, [500, 100, 25, 10, 5, 1])
		var at := Vector3(0.0, felt_y + 0.0005, ZC + 0.62)
		_pile_assurance.position = at + Vector3(0, 0.04, 0)
		add_child(_pile_assurance)
		create_tween().tween_property(_pile_assurance, "position:y", at.y, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Sfx.play("chips", -6.0))


func result(bet: int, payout: int) -> void:
	schedule(1.6, func():
		var stacks: Array[Node3D] = []
		for m in _mains:
			for s in m.piles:
				if s != null and is_instance_valid(s):
					stacks.append(s)
			m.piles = []
		var tray := Vector3(0, felt_y + 0.04, ZC + 0.07)
		var mine := Vector3(0.0, felt_y, ZC + R + 0.1)
		# L'assurance : payée si le croupier a blackjack, ramassée sinon.
		if _pile_assurance and is_instance_valid(_pile_assurance):
			var a := _pile_assurance
			_pile_assurance = null
			var dealer_bj: bool = _hand["dealer"].size() == 2 and BJ.total(_hand["dealer"]) == 21
			var ta := a.create_tween()
			if dealer_bj:
				ta.tween_interval(1.1)
				ta.tween_property(a, "position", mine, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			else:
				ta.tween_property(a, "position", tray, 0.55).set_trans(Tween.TRANS_CUBIC)
				ta.parallel().tween_property(a, "scale", Vector3.ONE * 0.4, 0.55)
			ta.tween_callback(a.queue_free)
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
			var natural: bool = _mains.size() == 1 and _mains[0].cartes.size() == 2 and BJ.total(_mains[0].cartes) == 21
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
	# La plaque dit les mises de la table (configurer_mises), pas celles du casino.
	if _plaque and "BETS" in p and not p.BETS.is_empty():
		_plaque.text = "Mise\n%d à %d" % [p.BETS[0], p.BETS[-1]]
	p.embedded = true
	p.table3d = self
	p.hand_started.connect(func():
		var amount: int = p.bet
		schedule(0.5, func():
			_clear()
			_place_bet(amount)))
	p.card_dealt.connect(deal)
	p.hand_doubled.connect(func(h: int, amount: int): schedule(0.2, func(): _pile(h, amount)))
	p.hand_split.connect(func(from: int, to: int): split(from, to, int(p.hands[to].bet)))
	p.insured.connect(_assurer)
	p.hole_revealed.connect(reveal)
	p.played.connect(result)
