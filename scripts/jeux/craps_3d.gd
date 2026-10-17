extends "res://scripts/jeux/table_3d.gd"
## La table de craps : une cuve d'acajou au tapis en contrebas, bord rembourré de cuir et main
## courante de laiton, paroi du fond garnie de caoutchouc à pyramides, tapis imprimé où l'on mise en
## cliquant. Les dés partent de la main du joueur, frappent le fond, rebondissent et se posent ;
## le palet « ON » marque le point ; les perdants sont ramassés, les gagnants payés.

## Géométrie de la cuve (mètres, repère de la table ; le joueur est du côté +z).
const IN := Vector2(3.0, 1.36)
const OUT := Vector2(3.4, 1.76)
const DIE := 0.042

## Les cases : clé -> Rect2(x, z, largeur, profondeur) sur le tapis.
const POINTS := [4, 5, 6, 8, 9, 10]
const PX0 := -1.34
const PW := 0.34
const X1 := PX0 + 6 * PW
## La rangée des points, au fond ; les lignes viennent devant, à distance du bord du joueur.
const PZ0 := -0.5
const PH := 0.34

var throw_time := 1.7
var _dice: Array[Node3D] = []
var _stacks := {}
var _puck: Node3D
var _puck_label: Label3D
var _point := 0


func _ready() -> void:
	felt_y = 0.74
	# Assez relevé pour voir les croupiers entiers derrière la cuve, assez large pour la Pass Line.
	seat = look(Vector3(0.0, 1.95, 1.32), Vector3(0.0, felt_y, -0.62))
	seat_fov = 60.0
	cells = {
		"pass": Rect2(PX0, 0.27, X1 - PX0, 0.2),
		"dont": Rect2(PX0, 0.13, X1 - PX0, 0.13),
		"field": Rect2(PX0, -0.13, X1 - PX0, 0.25),
		"place6": Rect2(PX0 + 2 * PW, PZ0, PW, PH),
		"place8": Rect2(PX0 + 3 * PW, PZ0, PW, PH),
		"seven": Rect2(X1 + 0.08, PZ0, 1.36 - X1 - 0.08, 0.3),
		"craps": Rect2(X1 + 0.08, -0.13, 1.36 - X1 - 0.08, 0.3),
	}
	_build()


func _build() -> void:
	var mahogany := KIT.varnished(Color(0.36, 0.13, 0.06))
	var dark := KIT.varnished(Color(0.14, 0.05, 0.03), 0.7)
	var brass := KIT.brass()
	var leather := KIT.leather()
	var rail_y := felt_y + 0.2
	# Le caisson et son socle.
	KIT.box(Vector3(OUT.x - 0.3, 0.06, OUT.y - 0.3), Vector3(0, 0.03, 0), dark, self)
	KIT.box(Vector3(OUT.x - 0.4, felt_y - 0.06, OUT.y - 0.4), Vector3(0, felt_y / 2.0, 0), dark, self)
	KIT.box(Vector3(OUT.x, 0.03, OUT.y), Vector3(0, felt_y - 0.02, 0), mahogany, self)
	# Les quatre parois de la cuve : bois au-dehors, feutre au-dedans.
	var wall_h := rail_y - felt_y
	var inner := KIT.mat(Color(0.03, 0.2, 0.11), 0.95)
	var side := [[Vector3(OUT.x, wall_h, (OUT.y - IN.y) / 2.0), Vector3(0, felt_y + wall_h / 2.0, (IN.y + OUT.y) / 4.0)],
		[Vector3(OUT.x, wall_h, (OUT.y - IN.y) / 2.0), Vector3(0, felt_y + wall_h / 2.0, -(IN.y + OUT.y) / 4.0)],
		[Vector3((OUT.x - IN.x) / 2.0, wall_h, IN.y), Vector3((IN.x + OUT.x) / 4.0, felt_y + wall_h / 2.0, 0)],
		[Vector3((OUT.x - IN.x) / 2.0, wall_h, IN.y), Vector3(-(IN.x + OUT.x) / 4.0, felt_y + wall_h / 2.0, 0)]]
	for e in side:
		KIT.box(e[0], e[1], mahogany, self)
	KIT.box(Vector3(IN.x, wall_h - 0.02, 0.004), Vector3(0, felt_y + wall_h / 2.0, IN.y / 2.0 - 0.002), inner, self)
	KIT.box(Vector3(0.004, wall_h - 0.02, IN.y), Vector3(IN.x / 2.0 - 0.002, felt_y + wall_h / 2.0, 0), inner, self)
	KIT.box(Vector3(0.004, wall_h - 0.02, IN.y), Vector3(-IN.x / 2.0 + 0.002, felt_y + wall_h / 2.0, 0), inner, self)
	# Le fond, où les dés doivent frapper : caoutchouc noir à pyramides.
	var rubber := KIT.mat(Color(0.05, 0.05, 0.055), 0.55)
	rubber.albedo_texture = _pyramids()
	rubber.normal_enabled = true
	rubber.normal_texture = _pyramids(true)
	rubber.uv1_scale = Vector3(IN.x / 0.06, (wall_h - 0.03) / 0.06, 1)
	var back := KIT.box(Vector3(IN.x, wall_h - 0.03, 0.006), Vector3(0, felt_y + (wall_h - 0.03) / 2.0, -IN.y / 2.0 + 0.003), rubber, self)
	back.name = "Pyramides"
	# Le bord : boudin de cuir et main courante de laiton, avec la rigole à jetons.
	for z in [1.0, -1.0]:
		var zr: float = z * (IN.y + OUT.y) / 4.0
		KIT.box(Vector3(OUT.x + 0.04, 0.07, (OUT.y - IN.y) / 2.0 + 0.04), Vector3(0, rail_y + 0.035, zr), leather, self)
		KIT.rail(Vector3(-OUT.x / 2.0, rail_y + 0.085, zr + z * 0.05), Vector3(OUT.x / 2.0, rail_y + 0.085, zr + z * 0.05), 0.012, brass, self)
	for x in [1.0, -1.0]:
		var xr: float = x * (IN.x + OUT.x) / 4.0
		KIT.box(Vector3((OUT.x - IN.x) / 2.0 + 0.04, 0.07, OUT.y + 0.04), Vector3(xr, rail_y + 0.035, 0), leather, self)
	var groove := KIT.box(Vector3(IN.x - 0.2, 0.012, 0.09), Vector3(0, rail_y + 0.072, (IN.y + OUT.y) / 4.0 - 0.02), dark, self)
	groove.name = "Rigole"
	# Le tapis imprimé.
	var fm := PlaneMesh.new()
	fm.size = IN
	KIT.mesh_node(fm, KIT.felt(Color(0.03, 0.28, 0.16), IN, _make_layout()), self, Vector3(0, felt_y, 0))
	# Les piles de la banque, devant le boxman.
	var vals := [500, 100, 25, 5, 5, 25, 100, 500]
	for k in vals.size():
		var s := KIT.chip_stack(vals[k] * 16, [vals[k]], 16)
		s.position = Vector3(0.3 + (k - 3.5) * 0.06, rail_y + 0.078, -(IN.y + OUT.y) / 4.0 + 0.0)
		add_child(s)
	# Le palet : noir « OFF » tant qu'aucun point n'est établi.
	_puck = Node3D.new()
	add_child(_puck)
	KIT.cyl(0.042, 0.012, Vector3(0, 0.006, 0), KIT.mat(Color(0.05, 0.05, 0.06), 0.4), _puck)
	_puck_label = Label3D.new()
	_puck_label.font = KIT.serif()
	_puck_label.font_size = 44
	_puck_label.pixel_size = 0.0006
	_puck_label.outline_size = 0
	_puck_label.rotation_degrees.x = -90
	_puck_label.position.y = 0.0125
	_puck.add_child(_puck_label)
	_set_puck(0, false)
	if with_lamp:
		KIT.table_spot(self, Vector3(0.0, 2.7, -0.1), Vector3(0.0, felt_y, -0.05), 1.8, 48.0)


## Une tuile de caoutchouc à pyramides : la couleur, ou sa carte de normales.
func _pyramids(normals := false) -> Texture2D:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n - 0.5
			var v := (y + 0.5) / n - 0.5
			var nx := 0.0
			var ny := 0.0
			if absf(u) > absf(v):
				nx = signf(u)
			else:
				ny = signf(v)
			if normals:
				var nn := Vector3(nx * 0.7, ny * 0.7, 1.0).normalized()
				img.set_pixel(x, y, Color(nn.x * 0.5 + 0.5, -nn.y * 0.5 + 0.5, nn.z * 0.5 + 0.5))
			else:
				var l := 0.85 + 0.15 * (ny * 0.6 - nx * 0.4)
				img.set_pixel(x, y, Color(l, l, l))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _make_layout() -> Texture2D:
	var S := 600.0
	var vp := SubViewport.new()
	vp.size = Vector2i(int(IN.x * S), int(IN.y * S))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	var to_px := func(r: Rect2) -> Rect2:
		return Rect2((r.position + IN / 2.0) * S, r.size * S)
	c.draw.connect(func():
		var ink := Color(0.95, 0.91, 0.79)
		var gold := Color(0.93, 0.74, 0.38)
		var red := Color(0.72, 0.1, 0.1)
		var f := KIT.serif()
		var lw := 4.0
		# Les cases des points, en haut : le 6 et le 8 se jouent en Place.
		for k in 6:
			var r: Rect2 = to_px.call(Rect2(PX0 + k * PW, PZ0, PW, PH))
			c.draw_rect(r, ink, false, lw)
			var n: int = POINTS[k]
			var txt := "SIX" if n == 6 else ("NEUF" if n == 9 else str(n))
			c.draw_string(f, r.position + Vector2(0, r.size.y * 0.62), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 64 if txt.length() < 3 else 48, ink)
			if n == 6 or n == 8:
				c.draw_string(f, r.position + Vector2(0, r.size.y * 0.88), "PLACE  7 : 6", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, gold)
		# Le Field.
		var fr: Rect2 = to_px.call(cells["field"])
		c.draw_rect(fr, ink, false, lw)
		var nums := ["2", "3", "4", "9", "10", "11", "12"]
		for k in nums.size():
			var x := fr.position.x + fr.size.x * (0.1 + 0.8 * k / 6.0)
			var special: bool = nums[k] == "2" or nums[k] == "12"
			if special:
				c.draw_arc(Vector2(x, fr.position.y + fr.size.y * 0.42), 34, 0, TAU, 40, gold, 3.0, true)
			c.draw_string(f, Vector2(x - 40, fr.position.y + fr.size.y * 0.42 + 15), nums[k], HORIZONTAL_ALIGNMENT_CENTER, 80, 44, gold if special else ink)
		c.draw_string(f, fr.position + Vector2(0, fr.size.y * 0.86), "FIELD   ·   le 2 paie double, le 12 triple", HORIZONTAL_ALIGNMENT_CENTER, fr.size.x, 26, ink)
		# Don't Pass et Pass Line.
		var dr: Rect2 = to_px.call(cells["dont"])
		c.draw_rect(dr, ink, false, lw)
		c.draw_string(f, dr.position + Vector2(0, dr.size.y * 0.7), "DON'T PASS BAR", HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, 34, ink)
		var pr: Rect2 = to_px.call(cells["pass"])
		c.draw_rect(pr, ink, false, lw)
		c.draw_rect(pr.grow(-10), ink, false, 2.0)
		c.draw_string(f, pr.position + Vector2(0, pr.size.y * 0.68), "PASS  LINE", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 60, ink)
		# Les paris du centre : Any Seven et Any Craps, en rouge comme au stickman.
		for k in ["seven", "craps"]:
			var r: Rect2 = to_px.call(cells[k])
			c.draw_rect(r, red, false, lw)
			c.draw_string(f, r.position + Vector2(0, r.size.y * 0.45), "ANY SEVEN" if k == "seven" else "ANY CRAPS", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 38, red.lightened(0.25))
			c.draw_string(f, r.position + Vector2(0, r.size.y * 0.78), "4 contre 1" if k == "seven" else "7 contre 1", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, ink)
		# Le bandeau du fond, sous les pyramides.
		var top := Rect2(Vector2(0, 0), Vector2(IN.x * S, (IN.y / 2.0 + PZ0) * S))
		c.draw_string(f, top.position + Vector2(0, top.size.y * 0.7), "CASINO  DE  SMARVES", HORIZONTAL_ALIGNMENT_CENTER, top.size.x, 34, gold)
		c.draw_rect(Rect2(Vector2(8, 8), Vector2(vp.size) - Vector2(16, 16)), gold, false, 3.0)
	)
	KIT._add_viewport(vp)
	return vp.get_texture()


# --- Le palet ------------------------------------------------------------------------------

func _puck_home() -> Vector3:
	return Vector3(PX0 - 0.08, felt_y, PZ0 + 0.1)


func _set_puck(point: int, animate := true) -> void:
	var dest := _puck_home()
	if point != 0:
		var k: int = POINTS.find(point)
		dest = Vector3(PX0 + (k + 0.5) * PW, felt_y, PZ0 + 0.05)
	_puck_label.text = "ON" if point != 0 else "OFF"
	_puck_label.modulate = Color(0.08, 0.08, 0.09) if point != 0 else Color(0.95, 0.93, 0.88)
	var face: MeshInstance3D = _puck.get_child(0)
	face.material_override = KIT.mat(Color(0.93, 0.92, 0.88) if point != 0 else Color(0.05, 0.05, 0.06), 0.4)
	if not animate:
		_puck.position = dest
		return
	var tw := create_tween()
	tw.tween_property(_puck, "position", dest + Vector3(0, 0.06, 0), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_puck, "position", dest, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Sfx.play("chips", -10.0, 0.8)


# --- Les dés ---------------------------------------------------------------------------------

## Le lancer : les dés partent de la main, frappent le fond et se posent sur les valeurs tirées.
func throw(values: Array) -> void:
	# Le stickman ramène les dés du coup précédent.
	for d in _dice:
		var t := d.create_tween()
		t.tween_property(d, "position", Vector3(0.0, felt_y + DIE / 2.0, -IN.y / 2.0 + 0.1), 0.3).set_trans(Tween.TRANS_CUBIC)
		t.tween_callback(d.queue_free)
	_dice.clear()
	var mid := Vector3.ZERO
	for i in values.size():
		var d := Node3D.new()
		add_child(d)
		d.add_child(KIT.die(DIE, Color(0.72, 0.04, 0.06), Color(0.97, 0.95, 0.9)))
		_dice.append(d)
		var start := Vector3(0.28 + i * 0.05, felt_y + 0.32, IN.y / 2.0 + 0.05)
		var wall := Vector3(randf_range(-0.55, 0.15) + i * 0.12, felt_y + randf_range(0.05, 0.12), -IN.y / 2.0 + DIE)
		var rest := Vector3(-0.3 + i * 0.2 + randf_range(-0.06, 0.06), felt_y + DIE / 2.0, randf_range(-0.12, 0.04))
		var final := Quaternion(KIT.die_basis(int(values[i]), randf() * TAU))
		var axis := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), 1.0).normalized()
		var turns := TAU * randf_range(3.0, 4.5)
		var tw := d.create_tween()
		tw.tween_method(_fly.bind(d, start, wall, rest, final, axis, turns), 0.0, 1.0, throw_time - randf_range(0.0, 0.15))
		mid += rest
	Sfx.play("dice", -8.0, 1.2)
	# Le plan serré arrive pendant que les dés finissent de rouler, pour lire leurs faces.
	mid /= maxf(values.size(), 1)
	get_tree().create_timer(throw_time * 0.55).timeout.connect(_close_up.bind(mid))


func _close_up(mid: Vector3) -> void:
	shot(look(mid + Vector3(0.05, 0.42, 0.5), mid + Vector3(0, 0.05, 0)), 0.7, 38.0)


## Une position du dé sur son trajet (t de 0 à 1) : une parabole jusqu'au fond, puis des rebonds
## qui s'amortissent jusqu'au repos ; il tourne de moins en moins vite et finit sur sa face.
func _fly(t: float, d: Node3D, start: Vector3, wall: Vector3, rest: Vector3, final: Quaternion, axis: Vector3, turns: float) -> void:
	const HIT := 0.32
	var p: Vector3
	if t < HIT:
		var k := t / HIT
		p = start.lerp(wall, k)
		p.y = lerpf(start.y, wall.y, k) + 0.18 * sin(PI * k)
	else:
		var k := (t - HIT) / (1.0 - HIT)
		var e := 1.0 - pow(1.0 - k, 2.4)
		p = wall.lerp(rest, e)
		# Trois rebonds de plus en plus bas.
		var b := absf(sin(PI * 3.0 * pow(k, 0.7))) * 0.09 * pow(1.0 - k, 1.6)
		p.y = lerpf(wall.y, rest.y, minf(k * 4.0, 1.0)) + b
	d.position = p
	var spin := turns * pow(1.0 - t, 2.0)
	d.quaternion = Quaternion(axis, spin) * final


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
		var p := _bet_spot(k)
		s.position = p + Vector3(0, 0.03, 0)
		add_child(s)
		_stacks[k] = s
		create_tween().tween_property(s, "position:y", p.y + 0.0005, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Sfx.play("chips", -6.0, randf_range(0.95, 1.1))


## Où la pile se pose dans sa case (sur la ligne, devant la place du joueur).
func _bet_spot(k: String) -> Vector3:
	var c := cell_center(k)
	if k in ["pass", "dont", "field"]:
		c.x = 0.0
	return c


## Le coup est réglé : annonce, palet, perdants ramassés, gagnants payés.
func settle(total: int, wins: Dictionary, call: String) -> void:
	# Les piles réglées quittent la table maintenant : le panneau va redonner les mises restantes.
	var still: Dictionary = panel.bets if panel else {}
	var gone := {}
	for k in _stacks.keys():
		if not still.has(k) or wins.has(k):
			gone[k] = _stacks[k]
			if not still.has(k):
				_stacks.erase(k)
	var mid := Vector3.ZERO
	for d in _dice:
		mid += d.position
	mid /= maxf(_dice.size(), 1)
	KIT.popup(self, mid + Vector3(0, 0.1, 0.02), "%d  ·  %s" % [total, call], 48, Color(1.0, 0.9, 0.66), 1.8)
	# On reste sur les dés le temps de lire l'annonce, puis retour à la place.
	var new_point: int = panel.point if panel else 0
	await get_tree().create_timer(2.2).timeout
	shot(seat, 0.8, seat_fov)
	if new_point != _point:
		_point = new_point
		_set_puck(_point)
	for k in wins:
		glow_cell(k, 2.6)
	var bank := Vector3(0.3, felt_y, -IN.y / 2.0 + 0.12)
	var mine := Vector3(0.2, felt_y + 0.3, IN.y / 2.0 + 0.2)
	var total_win := 0
	for k in gone:
		var s: Node3D = gone[k]
		if not is_instance_valid(s):
			continue
		var w: int = int(wins.get(k, 0))
		var stays: bool = still.has(k)
		if w <= 0:
			var t := s.create_tween()
			t.tween_property(s, "position", bank, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			t.parallel().tween_property(s, "scale", Vector3.ONE * 0.3, 0.55)
			t.tween_callback(s.queue_free)
			continue
		total_win += w
		# Une Place gagnante reste au travail : on ne paie que le gain, la pile reste.
		var gain: int = w if stays else w - int(s.get_meta("amount"))
		if gain > 0:
			var paid := KIT.chip_stack(gain)
			paid.position = bank
			add_child(paid)
			var t := paid.create_tween()
			t.tween_property(paid, "position", s.position + Vector3(0.06, 0, 0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_interval(0.7)
			t.tween_property(paid, "position", mine, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t.tween_callback(paid.queue_free)
		if not stays:
			var t2 := s.create_tween()
			t2.tween_interval(1.3)
			t2.tween_property(s, "position", mine, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t2.tween_callback(s.queue_free)
	if total_win > 0:
		var at := Vector3(0.0, felt_y, 0.3)
		Sfx.play("chips_win", -2.0)
		KIT.burst(self, at + Vector3(0, 0.02, 0), 80 if total_win < 500 else 160, 0.5)
		KIT.flash(self, at + Vector3(0, 0.4, 0), 3.0 if total_win < 500 else 6.0)
		KIT.popup(self, at + Vector3(0, 0.15, 0.05), "+ %s" % Game.fmt(total_win), 110)


# --- Lien avec le panneau ------------------------------------------------------------------

func attach(p: Control) -> void:
	panel = p
	p.embedded = true
	p.table3d = self
	p.bets_changed.connect(show_bets)
	p.dice_rolled.connect(throw)
	p.settled.connect(settle)
	cell_clicked.connect(func(k: String): p._place(k))
