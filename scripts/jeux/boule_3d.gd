extends "res://scripts/jeux/table_3d.gd"
## La table de la Boule, au Salon de musique : plateau d'acajou, cuvette tournée posée à gauche
## (pente, couronne de dix-huit trous numérotés de 1 à 9, dôme central), tapis imprimé à droite où
## l'on mise en cliquant sur les neuf numéros et les six chances. Le croupier lance la boule, qui
## tourne contre la bande, ralentit, descend et tombe dans un trou du numéro tiré.

const FELT := Vector2(2.4, 1.1)
const OUT := Vector2(2.7, 1.4)
const BOWL_AT := Vector3(-0.72, 0.0, 0.0)
const BOWL_R := 0.42
const HOLE_R := 0.24
const BALL_R := 0.016
## L'ordre des numéros sur la couronne (deux fois chaque numéro).
const RING := [1, 6, 3, 8, 5, 2, 7, 4, 9, 1, 6, 3, 8, 5, 2, 7, 4, 9]
const RED := [1, 3, 6, 8]

## Le temps d'un lancer (le panneau attend ce temps pour régler le coup).
var spin_time := 5.0
var _ball: MeshInstance3D
var _floor_y := 0.0
var _stacks := {}


func _ready() -> void:
	felt_y = 0.79
	_floor_y = felt_y + 0.016
	seat = look(Vector3(0.05, 1.55, 1.25), Vector3(0.05, 0.86, -0.3))
	seat_fov = 58.0
	# Les neuf numéros en trois rangées, puis les six chances en deux colonnes.
	for n in 9:
		cells[str(n + 1)] = Rect2(-0.2 + (n % 3) * 0.26, -0.42 + (n / 3) * 0.24, 0.24, 0.22)
	var chances := [["rouge", "noir"], ["pair", "impair"], ["manque", "passe"]]
	for row in 3:
		for col in 2:
			cells[chances[row][col]] = Rect2(0.62 + col * 0.27, -0.42 + row * 0.24, 0.25, 0.22)
	_build()


func _build() -> void:
	var mahogany := KIT.varnished(Color(0.36, 0.13, 0.06))
	var dark := KIT.varnished(Color(0.14, 0.05, 0.03), 0.7)
	var brass := KIT.brass()
	var leather := KIT.leather()
	# Le plateau, sa ceinture et ses quatre pieds tournés.
	KIT.box(Vector3(OUT.x, 0.06, OUT.y), Vector3(0, felt_y - 0.03, 0), mahogany, self)
	KIT.box(Vector3(OUT.x + 0.01, 0.012, OUT.y + 0.01), Vector3(0, felt_y - 0.066, 0), brass, self)
	KIT.box(Vector3(OUT.x - 0.16, 0.12, OUT.y - 0.16), Vector3(0, felt_y - 0.12, 0), dark, self)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			KIT.turned_leg(felt_y - 0.18, 0.045, mahogany, self, Vector3(x * (OUT.x / 2.0 - 0.16), 0, z * (OUT.y / 2.0 - 0.16)))
	for z in [1.0, -1.0]:
		KIT.box(Vector3(OUT.x, 0.05, (OUT.y - FELT.y) / 2.0), Vector3(0, felt_y + 0.02, z * (OUT.y + FELT.y) / 4.0), leather, self)
	for x in [1.0, -1.0]:
		KIT.box(Vector3((OUT.x - FELT.x) / 2.0, 0.05, FELT.y), Vector3(x * (OUT.x + FELT.x) / 4.0, felt_y + 0.02, 0), leather, self)
	var fm := PlaneMesh.new()
	fm.size = FELT
	KIT.mesh_node(fm, KIT.felt(Color(0.05, 0.16, 0.2), FELT, _make_layout()), self, Vector3(0, felt_y + 0.001, 0))
	# La cuvette posée sur le tapis : paroi d'acajou, bord de laiton, pente, couronne des trous, dôme.
	var bowl := Node3D.new()
	bowl.position = BOWL_AT + Vector3(0, felt_y, 0)
	add_child(bowl)
	var fy := _floor_y - felt_y
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(BOWL_R + 0.05, 0.0), Vector2(BOWL_R + 0.04, 0.09)]), 64), mahogany, bowl)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(BOWL_R + 0.04, 0.09), Vector2(BOWL_R + 0.03, 0.103), Vector2(BOWL_R + 0.005, 0.105), Vector2(BOWL_R - 0.005, 0.095)]), 64), brass, bowl)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(BOWL_R - 0.005, 0.095), Vector2(HOLE_R + 0.06, fy + 0.004), Vector2(HOLE_R + 0.05, fy)]), 64), mahogany, bowl)
	var ring := KIT.mesh_node(_ring_mesh(HOLE_R + 0.05, HOLE_R - 0.05), KIT.mat(Color.WHITE, 0.5), bowl, Vector3(0, fy, 0))
	ring.material_override.albedo_texture = _make_ring()
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(HOLE_R - 0.05, fy), Vector2(0.12, fy + 0.012), Vector2(0.06, fy + 0.055), Vector2(0.0, fy + 0.065)]), 48), KIT.mat(Color(0.62, 0.45, 0.2), 0.55, 0.5), bowl)
	_ball = KIT.sphere(BALL_R, Vector3(HOLE_R, fy + BALL_R, 0.0), KIT.mat(Color(0.95, 0.93, 0.86), 0.15), bowl)
	if with_lamp:
		KIT.table_spot(self, Vector3(-0.2, 2.6, 0.1), Vector3(-0.2, felt_y, -0.05), 1.8, 52.0).light_specular = 0.15


## Une couronne plate (normale vers le haut), UV à plat sur le diamètre extérieur.
func _ring_mesh(r_out: float, r_in: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 72
	var up := [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var p := [Vector3(cos(a0) * r_in, 0, sin(a0) * r_in), Vector3(cos(a0) * r_out, 0, sin(a0) * r_out),
			Vector3(cos(a1) * r_in, 0, sin(a1) * r_in), Vector3(cos(a1) * r_out, 0, sin(a1) * r_out)]
		var uv := []
		for q in p:
			uv.append(Vector2(0.5 + q.x / (2.0 * r_out), 0.5 + q.z / (2.0 * r_out)))
		KIT._tri(st, p, up, uv, 0, 1, 2)
		KIT._tri(st, p, up, uv, 2, 1, 3)
	return st.commit()


## L'angle (repère de la cuvette, dans le plan x, z) du trou k.
func _hole_angle(k: int) -> float:
	return TAU * k / RING.size()


## La couronne : un trou noir cerclé de couleur par case, le numéro à côté.
func _make_ring() -> Texture2D:
	var S := 1024
	var vp := SubViewport.new()
	vp.size = Vector2i(S, S)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	c.draw.connect(func():
		var o := Vector2(S, S) / 2.0
		var px := S / (2.0 * (HOLE_R + 0.05))
		var f := KIT.serif()
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(S, S)), Color(0.93, 0.89, 0.8))
		for k in RING.size():
			var a := _hole_angle(k)
			var n: int = RING[k]
			var col := Color(0.92, 0.72, 0.15) if n == 5 else (Color(0.7, 0.07, 0.1) if n in RED else Color(0.08, 0.08, 0.09))
			var h := o + Vector2(cos(a), sin(a)) * HOLE_R * px
			c.draw_circle(h, 0.03 * px, col)
			c.draw_circle(h, 0.021 * px, Color(0.03, 0.02, 0.02))
			var t := o + Vector2(cos(a + 0.17), sin(a + 0.17)) * HOLE_R * px
			c.draw_set_transform(t, a + 0.17 + PI / 2.0, Vector2.ONE)
			c.draw_string(f, Vector2(-30, 14), str(n), HORIZONTAL_ALIGNMENT_CENTER, 60, 40, col)
			c.draw_set_transform(Vector2.ZERO)
	)
	KIT._add_viewport(vp)
	return vp.get_texture()


## Le tapis : les neuf numéros à leurs couleurs, les six chances, la règle du 5.
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
		for n in range(1, 10):
			var r: Rect2 = to_px.call(cells[str(n)])
			var col := Color(0.92, 0.72, 0.15) if n == 5 else (Color(0.75, 0.1, 0.12) if n in RED else Color(0.05, 0.05, 0.06))
			c.draw_rect(r, Color(col, 0.55))
			c.draw_rect(r, gold if n == 5 else ink, false, 4.0)
			c.draw_string(f, r.position + Vector2(0, r.size.y * 0.66), str(n), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 64, ink)
		var names := {"rouge": "ROUGE", "noir": "NOIR", "pair": "PAIR", "impair": "IMPAIR", "manque": "MANQUE", "passe": "PASSE"}
		var subs := {"manque": "1 à 4", "passe": "6 à 9"}
		for k in names:
			var r: Rect2 = to_px.call(cells[k])
			if k == "rouge":
				c.draw_rect(r, Color(0.75, 0.1, 0.12, 0.45))
			elif k == "noir":
				c.draw_rect(r, Color(0.0, 0.0, 0.0, 0.45))
			c.draw_rect(r, ink, false, 4.0)
			c.draw_string(f, r.position + Vector2(0, r.size.y * (0.5 if subs.has(k) else 0.62)), names[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, ink)
			if subs.has(k):
				c.draw_string(f, r.position + Vector2(0, r.size.y * 0.84), subs[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, gold)
		var band: Rect2 = to_px.call(Rect2(-0.2, 0.32, 1.32, 0.2))
		c.draw_string(f, band.position + Vector2(0, band.size.y * 0.45), "LA BOULE   ·   un numéro paie 7 contre 1", HORIZONTAL_ALIGNMENT_CENTER, band.size.x, 28, gold)
		c.draw_string(f, band.position + Vector2(0, band.size.y * 0.85), "Le 5 est à la maison : les chances perdent", HORIZONTAL_ALIGNMENT_CENTER, band.size.x, 24, ink)
		var bowl: Rect2 = to_px.call(Rect2(BOWL_AT.x - 0.5, -0.5, 1.0, 1.0))
		c.draw_arc(bowl.get_center(), (BOWL_R + 0.07) * S, 0, TAU, 96, gold, 4.0, true)
		c.draw_rect(Rect2(Vector2(8, 8), Vector2(vp.size) - Vector2(16, 16)), gold, false, 3.0)
	)
	KIT._add_viewport(vp)
	return vp.get_texture()


# --- Le lancer ------------------------------------------------------------------------------

## La boule part contre la bande, tourne en ralentissant, descend la pente et tombe dans un trou
## du numéro tiré (« idx » est l'index du numéro dans 1..9).
func spin(idx: int, dur: float) -> void:
	var n := idx + 1
	var holes := []
	for k in RING.size():
		if RING[k] == n:
			holes.append(k)
	var hole: int = holes.pick_random()
	var end_a := _hole_angle(hole)
	var turns := 5.0
	var start_a := end_a + TAU * turns + randf_range(0.0, TAU)
	var fy := _floor_y - felt_y
	var tw := create_tween()
	tw.tween_method(func(t: float):
		# t : 0 au lancer, 1 dans le trou. La vitesse décroît ; la boule quitte la bande vers 60 %.
		var e := 1.0 - pow(1.0 - t, 2.2)
		var a := lerpf(start_a, end_a, e)
		var k := smoothstep(0.55, 0.92, t)
		var r := lerpf(BOWL_R - 0.05, HOLE_R, k)
		var y := lerpf(0.067, fy, k) + BALL_R
		# Deux petits sauts sur la couronne avant de tomber.
		y += absf(sin(PI * 4.0 * clampf((t - 0.9) / 0.1, 0.0, 1.0))) * 0.012 * (1.0 - t) * 10.0
		if t >= 0.999:
			y = fy + BALL_R * 0.3
		# Le repère de la cuvette tourne a dans le plan x, z ; z vers le joueur.
		_ball.position = Vector3(cos(a) * r, y, sin(a) * r), 0.0, 1.0, dur - 0.3)
	Sfx.play("shake", -16.0, 1.6)
	# Le plan serré sur la cuvette quand la boule descend.
	get_tree().create_timer(dur * 0.5).timeout.connect(func():
		var c := BOWL_AT + Vector3(0, felt_y, 0)
		shot(look(c + Vector3(0.15, 0.62, 0.55), c + Vector3(0, -0.05, 0)), 0.8, 44.0))


# --- Les mises et le règlement -----------------------------------------------------------

func show_bets(bets: Dictionary) -> void:
	for k in _stacks.keys():
		if not bets.has(k) or int(_stacks[k].get_meta("amount")) != int(bets[k]):
			_stacks[k].queue_free()
			_stacks.erase(k)
	for k in bets:
		if _stacks.has(k) or not cells.has(k):
			continue
		var s := KIT.chip_stack(int(bets[k]))
		s.set_meta("amount", int(bets[k]))
		var p := cell_center(k) + Vector3(0.06, 0, 0.04)
		s.position = p + Vector3(0, 0.03, 0)
		add_child(s)
		_stacks[k] = s
		create_tween().tween_property(s, "position:y", p.y + 0.0005, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Sfx.play("chips", -6.0, randf_range(0.95, 1.1))


func settle(result: String, wins: Dictionary) -> void:
	var gone := _stacks.duplicate()
	_stacks.clear()
	var n := int(result)
	var text := "%d" % n
	if n == 5:
		text += "  ·  LA MAISON"
	else:
		text += "  ·  %s" % ("ROUGE" if n in RED else "NOIR")
	KIT.popup(self, BOWL_AT + Vector3(0, felt_y + 0.3, 0), text, 64, Color(1.0, 0.9, 0.66), 1.8)
	glow_cell(result, 3.2)
	for k in wins:
		if k != result:
			glow_cell(k, 3.2)
	await get_tree().create_timer(1.6).timeout
	shot(seat, 0.8, seat_fov)
	var bank := Vector3(0.4, felt_y, -FELT.y / 2.0 - 0.05)
	var mine := Vector3(0.3, felt_y + 0.3, OUT.y / 2.0 + 0.3)
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
		gain_total += gain
		var paid := KIT.chip_stack(gain)
		paid.position = bank
		add_child(paid)
		var t := paid.create_tween()
		t.tween_property(paid, "position", s.position + Vector3(0.06, 0, 0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.7)
		t.tween_property(paid, "position", mine, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_callback(paid.queue_free)
		var t2 := s.create_tween()
		t2.tween_interval(1.3)
		t2.tween_property(s, "position", mine, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t2.tween_callback(s.queue_free)
	if gain_total > 0:
		var at := Vector3(0.4, felt_y, 0.0)
		Sfx.play("chips_win", -2.0)
		KIT.burst(self, at + Vector3(0, 0.02, 0), 80 if gain_total < 500 else 160, 0.5)
		KIT.flash(self, at + Vector3(0, 0.4, 0), 3.0 if gain_total < 500 else 6.0)
		KIT.popup(self, at + Vector3(0, 0.15, 0.05), "+ %s" % Game.fmt(gain_total), 110)


# --- Lien avec le panneau ------------------------------------------------------------------

func attach(p: Control) -> void:
	panel = p
	p.embedded = true
	p.table3d = self
	p.bets_changed.connect(show_bets)
	p.spin_started.connect(spin)
	p.settled.connect(settle)
	cell_clicked.connect(func(k: String): p._place(k))
