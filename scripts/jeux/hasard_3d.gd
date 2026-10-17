extends "res://scripts/jeux/table_3d.gd"
## La table du Grand Hasard, dans la loggia : plateau d'acajou, tapis imprimé (six numéros, Petit,
## Triple, Grand) où l'on mise en cliquant, et la cloche de verre sur son socle de laiton. Au lancer,
## le chef de partie agite la cloche, la repose et la lève : les trois dés montrent le tirage.

const FELT := Vector2(2.0, 1.1)
const OUT := Vector2(2.3, 1.4)
const DIE := 0.05
const DOME_AT := Vector3(0.0, 0.0, -0.4)

## Le temps entre le lancer et la cloche levée (le panneau attend ce temps pour régler le coup).
var reveal_time := 2.5
var _dome: Node3D
var _glass: Node3D
var _dice: Array[Node3D] = []
var _stacks := {}


func _ready() -> void:
	felt_y = 0.78
	# Assis, le regard assez haut pour voir le chef de partie entier derrière la cloche.
	seat = look(Vector3(0.0, 1.32, 1.1), Vector3(0.0, 0.86, -0.6))
	seat_fov = 60.0
	var cw := FELT.x * 0.84 / 6.0
	var x0 := -FELT.x * 0.42
	for n in 6:
		cells["n%d" % (n + 1)] = Rect2(x0 + n * cw, 0.04, cw, 0.3)
	cells["small"] = Rect2(x0, -0.24, 0.6, 0.25)
	cells["triple"] = Rect2(-0.24, -0.24, 0.48, 0.25)
	cells["big"] = Rect2(-x0 - 0.6, -0.24, 0.6, 0.25)
	_build()


func _build() -> void:
	var mahogany := KIT.varnished(Color(0.36, 0.13, 0.06))
	var dark := KIT.varnished(Color(0.14, 0.05, 0.03), 0.7)
	var brass := KIT.brass()
	var leather := KIT.leather()
	# Le plateau, sa ceinture de laiton et ses quatre pieds tournés.
	KIT.box(Vector3(OUT.x, 0.06, OUT.y), Vector3(0, felt_y - 0.03, 0), mahogany, self)
	KIT.box(Vector3(OUT.x + 0.01, 0.012, OUT.y + 0.01), Vector3(0, felt_y - 0.066, 0), brass, self)
	KIT.box(Vector3(OUT.x - 0.16, 0.12, OUT.y - 0.16), Vector3(0, felt_y - 0.12, 0), dark, self)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			KIT.turned_leg(felt_y - 0.18, 0.045, mahogany, self, Vector3(x * (OUT.x / 2.0 - 0.16), 0, z * (OUT.y / 2.0 - 0.16)))
	# Le boudin de cuir du bord.
	for z in [1.0, -1.0]:
		KIT.box(Vector3(OUT.x, 0.05, (OUT.y - FELT.y) / 2.0), Vector3(0, felt_y + 0.02, z * (OUT.y + FELT.y) / 4.0), leather, self)
	for x in [1.0, -1.0]:
		KIT.box(Vector3((OUT.x - FELT.x) / 2.0, 0.05, FELT.y), Vector3(x * (OUT.x + FELT.x) / 4.0, felt_y + 0.02, 0), leather, self)
	# Le tapis.
	var fm := PlaneMesh.new()
	fm.size = FELT
	KIT.mesh_node(fm, KIT.felt(Color(0.05, 0.16, 0.2), FELT, _make_layout()), self, Vector3(0, felt_y + 0.001, 0))
	# La cloche : socle de laiton, coupe de verre, trois dés dessous.
	_dome = Node3D.new()
	_dome.position = DOME_AT + Vector3(0, felt_y, 0)
	add_child(_dome)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(0.15, 0.0), Vector2(0.155, 0.012), Vector2(0.15, 0.024), Vector2(0.0, 0.024)]), 48), brass, _dome)
	var base_felt := KIT.disc(0.135)
	KIT.mesh_node(base_felt, KIT.mat(Color(0.5, 0.05, 0.08), 0.9), _dome, Vector3(0, 0.0245, 0))
	_glass = Node3D.new()
	_glass.position.y = 0.024
	_dome.add_child(_glass)
	var prof := PackedVector2Array()
	for k in 13:
		var a := PI / 2.0 * k / 12.0
		prof.append(Vector2(cos(a) * 0.14, sin(a) * 0.15))
	var glass := KIT.mat(Color(0.85, 0.92, 0.95, 0.16), 0.03)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	KIT.mesh_node(KIT.lathe(prof, 48), glass, _glass)
	KIT.sphere(0.016, Vector3(0, 0.155, 0), brass, _glass)
	for i in 3:
		var d := Node3D.new()
		d.add_child(KIT.die(DIE, Color(0.96, 0.94, 0.88), Color(0.08, 0.08, 0.1)))
		d.position = _die_rest(i)
		d.basis = KIT.die_basis(i + 1, randf() * TAU)
		_dome.add_child(d)
		_dice.append(d)
	if with_lamp:
		KIT.table_spot(self, Vector3(0.0, 2.6, 0.0), Vector3(0.0, felt_y, -0.1), 1.8, 44.0)


func _die_rest(i: int) -> Vector3:
	var a := TAU * i / 3.0 + 0.4
	return Vector3(cos(a) * 0.055, 0.0245 + DIE / 2.0, sin(a) * 0.055)


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
		for n in 6:
			var r: Rect2 = to_px.call(cells["n%d" % (n + 1)])
			c.draw_rect(r, ink, false, lw)
			_draw_face(c, r.get_center() + Vector2(0, -r.size.y * 0.1), 52.0, n + 1, ink)
			c.draw_string(f, r.position + Vector2(0, r.size.y * 0.9), "1 · 2 · 3", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, gold)
		var labels := {"small": ["PETIT", "4 à 10  ·  1 contre 1"], "triple": ["TRIPLE", "30 contre 1"], "big": ["GRAND", "11 à 17  ·  1 contre 1"]}
		for k in labels:
			var r: Rect2 = to_px.call(cells[k])
			c.draw_rect(r, ink, false, lw)
			c.draw_string(f, r.position + Vector2(0, r.size.y * 0.5), labels[k][0], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 46, gold if k == "triple" else ink)
			c.draw_string(f, r.position + Vector2(0, r.size.y * 0.82), labels[k][1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, ink)
		var bottom := Rect2(Vector2(0, (FELT.y / 2.0 + 0.36) * S), Vector2(FELT.x * S, (FELT.y / 2.0 - 0.36) * S))
		c.draw_string(f, bottom.position + Vector2(0, bottom.size.y * 0.62), "LE  GRAND  HASARD   ·   Petit et Grand perdent sur un triple", HORIZONTAL_ALIGNMENT_CENTER, bottom.size.x, 24, gold)
		var dome: Rect2 = to_px.call(Rect2(DOME_AT.x - 0.2, DOME_AT.z - 0.13, 0.4, 0.26))
		c.draw_arc(dome.get_center(), 0.17 * S, 0, TAU, 64, gold, 3.0, true)
		c.draw_rect(Rect2(Vector2(8, 8), Vector2(vp.size) - Vector2(16, 16)), gold, false, 3.0)
	)
	KIT._add_viewport(vp)
	return vp.get_texture()


## Une face de dé dessinée sur le tapis.
func _draw_face(c: Control, at: Vector2, size: float, v: int, col: Color) -> void:
	var r := Rect2(at - Vector2.ONE * size / 2.0, Vector2.ONE * size)
	c.draw_rect(r, col, false, 3.0)
	var pos := {1: [[0.5, 0.5]], 2: [[0.27, 0.27], [0.73, 0.73]], 3: [[0.25, 0.25], [0.5, 0.5], [0.75, 0.75]],
		4: [[0.27, 0.27], [0.73, 0.27], [0.27, 0.73], [0.73, 0.73]],
		5: [[0.25, 0.25], [0.75, 0.25], [0.5, 0.5], [0.25, 0.75], [0.75, 0.75]],
		6: [[0.28, 0.25], [0.72, 0.25], [0.28, 0.5], [0.72, 0.5], [0.28, 0.75], [0.72, 0.75]]}
	for p in pos[v]:
		c.draw_circle(r.position + Vector2(p[0], p[1]) * size, size * 0.09, col)


# --- Le lancer ------------------------------------------------------------------------------

## La cloche se soulève, s'agite, se repose ; puis le verre se lève sur les valeurs tirées.
func throw(values: Array) -> void:
	var tw := create_tween()
	var home := _dome.position
	# Le verre, posé à côté depuis le coup précédent, revient coiffer les dés.
	if _glass.position.x != 0.0:
		tw.tween_property(_glass, "position", Vector3(0.0, 0.3, 0.0), 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_glass, "position", Vector3(0.0, 0.024, 0.0), 0.15)
	tw.tween_property(_dome, "position:y", home.y + 0.14, 0.25).set_trans(Tween.TRANS_SINE)
	for k in 6:
		var off := Vector3(randf_range(-0.03, 0.03), 0.0, randf_range(-0.03, 0.03))
		tw.tween_property(_dome, "position", home + Vector3(0, 0.14, 0) + off, 0.09)
		tw.parallel().tween_property(_dome, "rotation", Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), 0.09)
	tw.tween_property(_dome, "position", home, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_dome, "rotation", Vector3.ZERO, 0.2)
	# Les dés roulent sous la cloche pendant qu'elle s'agite, puis se posent sur le tirage.
	for i in _dice.size():
		var d := _dice[i]
		var t2 := create_tween()
		for k in 9:
			t2.tween_property(d, "quaternion", Quaternion.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)), 0.11)
			t2.parallel().tween_property(d, "position", _die_rest(i) + Vector3(randf_range(-0.02, 0.02), randf_range(0.0, 0.03), randf_range(-0.02, 0.02)), 0.11)
		t2.tween_property(d, "quaternion", Quaternion(KIT.die_basis(int(values[i]), randf_range(-0.5, 0.5))), 0.16)
		t2.parallel().tween_property(d, "position", _die_rest(i), 0.16)
	tw.tween_interval(0.25)
	tw.tween_callback(func(): shot(look(_dome.position + Vector3(0.0, 0.42, 0.42), _dome.position + Vector3(0, 0.04, 0)), 0.6, 40.0))
	tw.tween_property(_glass, "position:y", 0.3, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Puis le chef de partie le pose sur le tapis, à côté du socle.
	tw.tween_property(_glass, "position", Vector3(0.36, 0.06, 0.0), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_glass, "position:y", -0.0245 + 0.002, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Sfx.play("shake", -6.0)


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
		var p := cell_center(k) + Vector3(0, 0, 0.05)
		s.position = p + Vector3(0, 0.03, 0)
		add_child(s)
		_stacks[k] = s
		create_tween().tween_property(s, "position:y", p.y + 0.0005, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Sfx.play("chips", -6.0, randf_range(0.95, 1.1))


func settle(values: Array, wins: Dictionary) -> void:
	var gone := _stacks.duplicate()
	_stacks.clear()
	var sum := 0
	for v in values:
		sum += int(v)
	var triple: bool = values[0] == values[1] and values[1] == values[2]
	KIT.popup(self, _dome.position + Vector3(0, 0.2, 0.02), "%d%s" % [sum, "  ·  TRIPLE" if triple else ""], 64, Color(1.0, 0.9, 0.66), 1.8)
	await get_tree().create_timer(2.0).timeout
	shot(seat, 0.8, seat_fov)
	for k in wins:
		glow_cell(k, 2.6)
	var bank := Vector3(0.45, felt_y, -0.45)
	var mine := Vector3(0.0, felt_y + 0.3, FELT.y / 2.0 + 0.3)
	var total_win := 0
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
		total_win += w
		var gain: int = w - int(s.get_meta("amount"))
		if gain > 0:
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
	if total_win > 0:
		var at := Vector3(0.0, felt_y, 0.2)
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
