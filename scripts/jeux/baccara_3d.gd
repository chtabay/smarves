extends "res://scripts/jeux/table_3d.gd"
## La table de baccara (punto banco) : plateau ovale d'acajou, boudin de cuir, tapis imprimé avec
## les trois mises (Joueur, Égalité, Banque) où l'on clique, les deux cases de cartes, le sabot et le
## râtelier. Les cartes sortent du sabot face cachée, le croupier les retourne, la troisième carte
## se pose en travers ; le coup réglé, la case gagnante s'allume et les plaques sont payées.
## Sert aussi au Banco des salons particuliers (banque sans commission, tapis bordeaux).

const BAC := preload("res://scripts/baccara_panel.gd")

## Le plateau : deux demi-cercles reliés par des droites (demi-longueur A, rayon du tapis RF).
const A := 0.78
const RF := 0.66
const FELT := Vector2(2.0 * (A + RF), 2.0 * RF)
const OUT := Vector2(2.0 * (A + RF + 0.17), 2.0 * (RF + 0.17))

## Le nom imprimé sur le tapis et la règle de la Banque.
var title := "BACCARA"
var commission := true
var felt_color := Color(0.02, 0.15, 0.09)
var shoe_at := Vector3(0.86, 0.0, -0.42)
var _cards: Array[Node3D] = []
var _counts := {}
var _hand := {"player": [], "dealer": []}
var _labels := {}
var _stacks := {}


func _ready() -> void:
	felt_y = 0.79
	shoe_at.y = felt_y
	# Assis au milieu du grand côté, face au croupier : les cases de cartes au centre de l'image.
	seat = look(Vector3(0.0, 1.58, 1.3), Vector3(0.0, felt_y + 0.12, -0.3))
	seat_fov = 58.0
	cells["joueur"] = Rect2(-1.0, 0.14, 0.66, 0.34)
	cells["egalite"] = Rect2(-0.28, 0.18, 0.56, 0.28)
	cells["banquier"] = Rect2(0.34, 0.14, 0.66, 0.34)
	_build()


# --- La table -------------------------------------------------------------------------------

func _build() -> void:
	var mahogany := KIT.varnished(Color(0.36, 0.13, 0.06))
	var dark := KIT.varnished(Color(0.14, 0.05, 0.03), 0.7)
	var brass := KIT.brass()
	var leather := KIT.leather()
	# La ceinture d'acajou, le jonc de laiton, puis le boudin de cuir qui fait le tour.
	KIT.mesh_node(_sweep(PackedVector2Array([Vector2(0.15, felt_y - 0.15), Vector2(0.16, felt_y - 0.05), Vector2(0.12, felt_y - 0.01), Vector2(0.0, felt_y - 0.004)])), mahogany, self)
	KIT.mesh_node(_sweep(PackedVector2Array([Vector2(0.162, felt_y - 0.158), Vector2(0.162, felt_y - 0.146)])), brass, self)
	KIT.mesh_node(_sweep(PackedVector2Array([Vector2(0.06, felt_y - 0.15), Vector2(0.06, felt_y - 0.24), Vector2(-0.3, felt_y - 0.24)])), dark, self)
	var prof := PackedVector2Array()
	for k in 17:
		var t := -PI / 2.0 + TAU * k / 16.0
		prof.append(Vector2(0.105, felt_y + 0.03) + Vector2(cos(t) * 0.06, sin(t) * 0.045))
	KIT.mesh_node(_sweep(prof), leather, self)
	# Deux pieds en colonne sur leur patin.
	for x in [-A * 0.8, A * 0.8]:
		KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(0.3, 0.0), Vector2(0.3, 0.04), Vector2(0.12, 0.08), Vector2(0.09, 0.2),
			Vector2(0.08, felt_y - 0.42), Vector2(0.11, felt_y - 0.3), Vector2(0.2, felt_y - 0.24), Vector2(0.0, felt_y - 0.24)]), 40), mahogany, self, Vector3(x, 0, 0))
	# Le tapis.
	KIT.mesh_node(_stadium(RF), KIT.felt(felt_color, FELT, _make_layout()), self, Vector3(0, felt_y, 0))
	# Côté croupier : le râtelier de plaques, le sabot, la défausse.
	KIT.box(Vector3(0.7, 0.04, 0.16), Vector3(0, felt_y + 0.02, -0.53), KIT.varnished(Color(0.04, 0.03, 0.03), 1.0), self)
	var vals := [5000, 1000, 500, 100, 100, 500, 1000, 5000]
	for k in vals.size():
		var s := KIT.chip_stack(vals[k] * 14, [vals[k]], 14)
		s.position = Vector3(-0.3 + k * 0.085, felt_y + 0.04, -0.53)
		add_child(s)
	var shoe := Node3D.new()
	shoe.position = shoe_at + Vector3(0, 0, -0.04)
	shoe.rotation.y = 0.5
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
	discard.position = Vector3(-0.86, felt_y, -0.42)
	discard.rotation.y = -0.5
	add_child(discard)
	var glass := KIT.mat(Color(0.75, 0.85, 0.95, 0.3), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	KIT.box(Vector3(0.1, 0.07, 0.13), Vector3(0, 0.035, 0), glass, discard)
	if with_lamp:
		# Peu de reflet direct : le râtelier verni et les plaques renvoyaient la lampe en tache vive.
		KIT.table_spot(self, Vector3(0.0, 2.6, 0.1), Vector3(0.0, felt_y, -0.05), 1.8, 50.0).light_specular = 0.15


## Un point du contour ovale, à la distance r du centre de son arrondi, et sa normale.
func _outline(r: float) -> Array:
	var pts := []
	var n := 24
	for side in [1.0, -1.0]:
		for k in n + 1:
			var a := -PI / 2.0 + PI * k / n
			if side < 0.0:
				a += PI
			var nrm := Vector3(cos(a), 0, sin(a))
			pts.append([Vector3(side * A, 0, 0) + nrm * r, nrm])
	pts.append(pts[0])
	return pts


## Le tapis ovale, UV à plat sur FELT.
func _stadium(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := _outline(r)
	var up := [Vector3.UP, Vector3.UP, Vector3.UP]
	for i in pts.size() - 1:
		var p := [Vector3.ZERO, pts[i][0], pts[i + 1][0]]
		var uv := []
		for q in p:
			uv.append(Vector2(q.x / FELT.x + 0.5, q.z / FELT.y + 0.5))
		KIT._tri(st, p, up, uv, 0, 1, 2)
	return st.commit()


## Fait courir un profil (décalage vers l'extérieur depuis le bord du tapis, hauteur) tout autour
## de l'ovale. Le profil se parcourt de l'extérieur vers l'intérieur en montant, comme KIT.lathe.
func _sweep(profile: PackedVector2Array) -> ArrayMesh:
	var pts := _outline(RF)
	var n := profile.size()
	var seg_n: Array[Vector2] = []
	for i in n - 1:
		var d := (profile[i + 1] - profile[i]).normalized()
		seg_n.append(Vector2(d.y, -d.x))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n - 1:
		var na := seg_n[i]
		var nb := seg_n[i]
		if i > 0 and seg_n[i - 1].dot(seg_n[i]) > 0.82:
			na = (seg_n[i - 1] + seg_n[i]).normalized()
		if i < n - 2 and seg_n[i + 1].dot(seg_n[i]) > 0.82:
			nb = (seg_n[i + 1] + seg_n[i]).normalized()
		for s in pts.size() - 1:
			var p := []
			var nn := []
			for e in [[s, profile[i], na], [s + 1, profile[i], na], [s, profile[i + 1], nb], [s + 1, profile[i + 1], nb]]:
				var o: Vector3 = pts[e[0]][0]
				var nrm: Vector3 = pts[e[0]][1]
				var pr: Vector2 = e[1]
				var pn: Vector2 = e[2]
				p.append(o + nrm * pr.x + Vector3(0, pr.y, 0))
				nn.append((nrm * pn.x + Vector3(0, pn.y, 0)).normalized())
			var uv := [Vector2(float(s) / pts.size(), float(i) / n), Vector2(float(s + 1) / pts.size(), float(i) / n),
				Vector2(float(s) / pts.size(), float(i + 1) / n), Vector2(float(s + 1) / pts.size(), float(i + 1) / n)]
			KIT._tri(st, p, nn, uv, 0, 2, 1)
			KIT._tri(st, p, nn, uv, 1, 2, 3)
	return st.commit()


## Le tapis imprimé : le nom de la table, les trois mises, les deux cases de cartes.
func _make_layout() -> Texture2D:
	var S := 600.0
	var vp := SubViewport.new()
	vp.size = Vector2i(int(FELT.x * S), int(FELT.y * S))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	var to_px := func(r: Rect2) -> Rect2:
		return Rect2((r.position + FELT / 2.0) * S, r.size * S)
	c.draw.connect(func():
		var ink := Color(0.95, 0.91, 0.79)
		var gold := Color(0.93, 0.74, 0.38)
		var f := KIT.serif()
		var lw := 4.0
		# Le filet d'or qui suit l'ovale.
		var o := PackedVector2Array()
		for e in _outline(RF - 0.04):
			o.append((Vector2(e[0].x, e[0].z) + FELT / 2.0) * S)
		c.draw_polyline(o, gold, 4.0, true)
		var bets := {"joueur": ["JOUEUR", "1 contre 1", Color(0.25, 0.4, 0.85, 0.22)],
			"egalite": ["ÉGALITÉ", "8 contre 1", Color(0.9, 0.7, 0.3, 0.14)],
			"banquier": ["BANQUE", "1 contre 1, moins 5 %" if commission else "1 contre 1, sans commission", Color(0.85, 0.15, 0.2, 0.22)]}
		for k in bets:
			var r: Rect2 = to_px.call(cells[k])
			c.draw_rect(r, bets[k][2])
			c.draw_rect(r, gold if k == "egalite" else ink, false, lw)
			c.draw_string(f, r.position + Vector2(0, r.size.y * 0.5), bets[k][0], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 50, gold if k == "egalite" else ink)
			c.draw_string(f, r.position + Vector2(0, r.size.y * 0.82), bets[k][1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, ink)
		# Les cases de cartes, côté croupier.
		for side in [-1.0, 1.0]:
			var box: Rect2 = to_px.call(Rect2(Vector2(0.13 if side > 0.0 else -0.58, -0.32), Vector2(0.45, 0.2)))
			c.draw_rect(box, Color(ink, 0.7), false, 3.0)
			c.draw_string(f, box.position + Vector2(0, box.size.y + 30), "BANQUE" if side > 0.0 else "JOUEUR", HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 26, Color(ink, 0.8))
		var mid: Rect2 = to_px.call(Rect2(-1.0, -0.02, 2.0, 0.12))
		c.draw_string(f, mid.position + Vector2(0, mid.size.y * 0.7), title, HORIZONTAL_ALIGNMENT_CENTER, mid.size.x, 40, gold)
		c.draw_string(f, mid.position + Vector2(0, mid.size.y * 0.7 + 30), "CASINO DE SMARVES", HORIZONTAL_ALIGNMENT_CENTER, mid.size.x, 20, Color(gold, 0.7))
	)
	KIT._add_viewport(vp)
	return vp.get_texture()


# --- Les cartes -----------------------------------------------------------------------------

## La place d'une carte : Joueur à gauche, Banque à droite ; la troisième en travers, à l'extérieur.
func _spot(who: String, k: int) -> Vector3:
	var side := -1.0 if who == "player" else 1.0
	if k >= 2:
		return Vector3(side * 0.47, felt_y + 0.001, -0.22)
	return Vector3(side * (0.2 + k * 0.1), felt_y + 0.001, -0.22)


func _clear() -> void:
	for c in _cards:
		var t := c.create_tween()
		t.tween_property(c, "position", Vector3(-0.86, felt_y + 0.06, -0.42), 0.4).set_trans(Tween.TRANS_CUBIC)
		t.tween_callback(c.queue_free)
	_cards.clear()
	_hand = {"player": [], "dealer": []}
	for k in _labels:
		_labels[k].queue_free()
	_labels.clear()


func deal(who: String, c: Dictionary) -> void:
	var k: int = _counts.get(who, 0)
	_counts[who] = k + 1
	if k < 2:
		schedule(0.42, func(): _deal_now(who, c, k, true))
		# Les quatre premières cartes posées, le croupier les retourne : Joueur, puis Banque.
		if who == "dealer" and k == 1:
			schedule(0.5, func(): shot(look(Vector3(0.0, 1.22, 0.72), Vector3(0.0, 0.98, -0.5)), 0.6, 50.0))
			for w in ["player", "dealer"]:
				schedule(0.75, _flip_pair.bind(w))
	else:
		schedule(0.9, func(): _deal_now(who, c, k, false))


func _deal_now(who: String, c: Dictionary, k: int, hidden: bool) -> void:
	var card := KIT.card(int(c.r), int(c.s))
	card.set_meta("c", c)
	add_child(card)
	_cards.append(card)
	var start := shoe_at + Vector3(-0.03, 0.06, 0.12)
	var dest := _spot(who, k)
	card.position = start
	card.rotation = Vector3(0, 0.5, PI)
	var yaw := PI / 2.0 if k >= 2 else randf_range(-0.04, 0.04)
	var tw := card.create_tween().set_parallel()
	tw.tween_method(func(t: float):
		card.position = start.lerp(dest, t) + Vector3(0, sin(t * PI) * 0.05, 0), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "rotation", Vector3(0, yaw, PI if hidden else 0.0), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("card", -4.0, randf_range(0.95, 1.1))
	card.set_meta("who", who)
	if not hidden:
		_hand[who].append(c)
		tw.chain().tween_callback(func(): _show_total(who))


func _flip_pair(who: String) -> void:
	var i := 0
	for card in _cards:
		if card.get_meta("who") != who:
			continue
		var p := card.position
		var tw := card.create_tween()
		tw.tween_interval(i * 0.22)
		tw.tween_property(card, "position", p + Vector3(0, 0.05, 0), 0.14)
		tw.parallel().tween_property(card, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(card, "position", p, 0.1)
		_hand[who].append(card.get_meta("c"))
		i += 1
	Sfx.play("card", -2.0, 0.9)
	get_tree().create_timer(0.6).timeout.connect(_show_total.bind(who))


func _show_total(who: String) -> void:
	if not is_inside_tree() or _hand[who].is_empty():
		return
	var v := BAC.value(_hand[who])
	if not _labels.has(who):
		var l := Label3D.new()
		l.font = KIT.serif()
		l.font_size = 64
		l.pixel_size = 0.0005
		l.outline_size = 12
		l.outline_modulate = Color(0.05, 0.02, 0.02, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = Vector3((-0.35 if who == "player" else 0.35), felt_y + 0.12, -0.24)
		add_child(l)
		_labels[who] = l
	var lab: Label3D = _labels[who]
	lab.text = "%s  %d" % ["Joueur" if who == "player" else "Banque", v]
	# Un 8 ou un 9 d'entrée : la « naturelle », en or.
	lab.modulate = Color(1.0, 0.86, 0.45) if v >= 8 and _hand[who].size() == 2 else Color(0.97, 0.94, 0.86)


# --- Les mises et le règlement -----------------------------------------------------------

func show_bets(bets: Dictionary) -> void:
	for k in _stacks.keys():
		if not bets.has(k) or bets[k] <= 0 or int(_stacks[k].get_meta("amount")) != int(bets[k]):
			_stacks[k].queue_free()
			_stacks.erase(k)
	for k in bets:
		if bets[k] <= 0 or _stacks.has(k) or not cells.has(k):
			continue
		var s := KIT.chip_stack(int(bets[k]))
		s.set_meta("amount", int(bets[k]))
		var p := cell_center(k) + Vector3(0, 0, 0.06)
		s.position = p + Vector3(0, 0.03, 0)
		add_child(s)
		_stacks[k] = s
		create_tween().tween_property(s, "position:y", p.y + 0.0005, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Sfx.play("chips", -6.0, randf_range(0.95, 1.1))


## Le coup réglé : « wins » donne, par case, ce qui revient au joueur (mise comprise).
func settle(wins: Dictionary, pv: int, bv: int) -> void:
	var gone := _stacks.duplicate()
	_stacks.clear()
	var text := "JOUEUR  %d à %d" % [pv, bv] if pv > bv else ("BANQUE  %d à %d" % [bv, pv] if bv > pv else "ÉGALITÉ  %d" % pv)
	KIT.popup(self, Vector3(0.0, felt_y + 0.22, -0.2), text, 56, Color(1.0, 0.9, 0.66), 1.8)
	glow_cell("joueur" if pv > bv else ("banquier" if bv > pv else "egalite"), 3.2)
	await get_tree().create_timer(1.6).timeout
	shot(seat, 0.8, seat_fov)
	var bank := Vector3(0.0, felt_y + 0.04, -0.53)
	var mine := Vector3(0.0, felt_y + 0.3, FELT.y / 2.0 + 0.35)
	var gain_total := 0
	for k in gone:
		var s: Node3D = gone[k]
		if not is_instance_valid(s):
			continue
		var w: int = int(wins.get(k, 0))
		if w <= 0:
			var t := s.create_tween()
			t.tween_property(s, "position", bank, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			t.parallel().tween_property(s, "scale", Vector3.ONE * 0.3, 0.55)
			t.tween_callback(s.queue_free)
			continue
		var gain: int = w - int(s.get_meta("amount"))
		if gain > 0:
			gain_total += gain
			var paid := KIT.chip_stack(gain)
			paid.position = bank
			add_child(paid)
			var t := paid.create_tween()
			t.tween_property(paid, "position", s.position + Vector3(0.07, 0, 0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_interval(0.7)
			t.tween_property(paid, "position", mine, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t.tween_callback(paid.queue_free)
		var t2 := s.create_tween()
		t2.tween_interval(1.3)
		t2.tween_property(s, "position", mine, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t2.tween_callback(s.queue_free)
	if gain_total > 0:
		var at := Vector3(0.0, felt_y, 0.3)
		Sfx.play("chips_win", -2.0)
		KIT.burst(self, at + Vector3(0, 0.02, 0), 80 if gain_total < 5000 else 160, 0.5)
		KIT.flash(self, at + Vector3(0, 0.4, 0), 3.0 if gain_total < 5000 else 6.0)
		KIT.popup(self, at + Vector3(0, 0.15, 0.05), "+ %s" % Game.fmt(gain_total), 110)


# --- Lien avec le panneau ------------------------------------------------------------------

func attach(p: Control) -> void:
	panel = p
	p.embedded = true
	p.table3d = self
	p.bets_changed.connect(show_bets)
	p.hand_started.connect(func():
		_counts = {"player": 0, "dealer": 0}
		schedule(0.45, _clear))
	p.card_dealt.connect(func(who: String, c: Dictionary, _hidden: bool): deal(who, c))
	p.settled.connect(settle)
	cell_clicked.connect(func(k: String): p._place(k))
