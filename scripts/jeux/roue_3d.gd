extends "res://scripts/jeux/table_3d.gd"
## La Roue de la fortune de la Salle des fêtes : grande roue verticale à 54 cases sur son pied
## d'acajou, jante dorée et ampoules, languette de cuir en haut qui claque sur les clous ; devant,
## un comptoir à tapis où l'on mise sur les sept symboles en cliquant. La roue tourne, ralentit,
## la languette s'arrête sur la case tirée ; la case gagnante du comptoir s'allume.

const R := 1.1
const HUB := Vector3(0.0, 1.85, 0.0)
const COUNTER := Vector2(2.4, 0.62)
const COUNTER_Z := 0.85
const KEYS := ["1", "2", "5", "10", "20", "Joker", "Étoile"]

## Le temps d'un lancer (le panneau attend ce temps pour régler le coup).
var spin_time := 5.5
var segments: Array = []
var _wheel: Node3D
var _flap: Node3D
var _face: MeshInstance3D
var _angle := 0.0
var _last_peg := 0
var _stacks := {}


func _ready() -> void:
	felt_y = 0.96
	# Debout devant le comptoir : la roue entière et le tapis dans le même regard.
	seat = look(Vector3(0.0, 1.9, 2.75), Vector3(0.0, 1.62, 0.4))
	seat_fov = 66.0
	var w := COUNTER.x * 0.9 / KEYS.size()
	for i in KEYS.size():
		cells[KEYS[i]] = Rect2(-COUNTER.x * 0.45 + i * w + 0.01, COUNTER_Z - 0.2, w - 0.02, 0.36)
	_build()


func _build() -> void:
	var mahogany := KIT.varnished(Color(0.36, 0.13, 0.06))
	var dark := KIT.varnished(Color(0.14, 0.05, 0.03), 0.7)
	var brass := KIT.brass()
	# Le pied : un socle et deux montants qui tiennent l'axe.
	KIT.box(Vector3(1.4, 0.12, 0.7), Vector3(0, 0.06, -0.15), dark, self)
	for x in [-0.32, 0.32]:
		var post := KIT.box(Vector3(0.12, HUB.y + 0.1, 0.14), Vector3(x, (HUB.y + 0.1) / 2.0, -0.18), mahogany, self)
		post.rotation.z = -x * 0.25
	KIT.cyl(0.05, 0.36, HUB + Vector3(0, 0, -0.1), brass, self).rotation.x = PI / 2.0
	# La roue : la face imprimée, la jante, les clous et les ampoules.
	_wheel = Node3D.new()
	_wheel.position = HUB
	add_child(_wheel)
	_face = KIT.mesh_node(KIT.disc(R, 108), KIT.mat(Color.WHITE, 0.45), _wheel)
	_face.rotation.x = PI / 2.0
	KIT.cyl(R + 0.02, 0.06, Vector3(0, 0, -0.035), dark, _wheel).rotation.x = PI / 2.0
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = R - 0.02
	tm.outer_radius = R + 0.07
	tm.rings = 96
	rim.mesh = tm
	rim.material_override = brass
	rim.rotation.x = PI / 2.0
	_wheel.add_child(rim)
	var pegs := 54
	for k in pegs:
		var a := TAU * (k + 0.5) / pegs
		KIT.cyl(0.008, 0.06, Vector3(cos(a) * (R - 0.04), sin(a) * (R - 0.04), 0.03), brass, _wheel, -1.0, 8).rotation.x = PI / 2.0
	var bulb := KIT.glow(Color(1.0, 0.86, 0.6), 1.4)
	for k in 18:
		var a := TAU * k / 18.0
		KIT.sphere(0.035, Vector3(cos(a) * (R + 0.1), sin(a) * (R + 0.1), 0.02), bulb, _wheel)
	KIT.cyl(0.06, 0.05, Vector3(0, 0, 0.02), brass, _wheel).rotation.x = PI / 2.0
	KIT.sphere(0.035, Vector3(0, 0, 0.05), brass, _wheel)
	# La languette en haut : une lame de cuir sur une chape de laiton.
	_flap = Node3D.new()
	_flap.position = HUB + Vector3(0, R + 0.2, 0.06)
	add_child(_flap)
	KIT.box(Vector3(0.12, 0.08, 0.06), Vector3(0, 0.03, 0), brass, _flap)
	var tongue := KIT.box(Vector3(0.05, 0.2, 0.012), Vector3(0, -0.1, 0.0), KIT.leather(Color(0.45, 0.06, 0.08)), _flap)
	tongue.name = "Lame"
	# Le comptoir des mises.
	KIT.box(Vector3(COUNTER.x, felt_y - 0.05, COUNTER.y), Vector3(0, (felt_y - 0.05) / 2.0, COUNTER_Z), dark, self)
	KIT.box(Vector3(COUNTER.x + 0.06, 0.05, COUNTER.y + 0.06), Vector3(0, felt_y - 0.025, COUNTER_Z), mahogany, self)
	KIT.box(Vector3(COUNTER.x + 0.07, 0.012, COUNTER.y + 0.07), Vector3(0, felt_y - 0.056, COUNTER_Z), brass, self)
	for z in [-1.0, 1.0]:
		KIT.box(Vector3(COUNTER.x + 0.06, 0.04, 0.05), Vector3(0, felt_y + 0.02, COUNTER_Z + z * (COUNTER.y / 2.0 + 0.005)), KIT.leather(), self)
	var fm := PlaneMesh.new()
	fm.size = COUNTER - Vector2(0.04, 0.06)
	KIT.mesh_node(fm, KIT.felt(Color(0.05, 0.16, 0.2), fm.size, _make_layout(fm.size)), self, Vector3(0, felt_y + 0.001, COUNTER_Z))
	if with_lamp:
		KIT.table_spot(self, Vector3(0.0, 3.4, 1.6), Vector3(0.0, 1.8, 0.2), 2.0, 55.0).light_specular = 0.15


## Le tapis du comptoir : un cadre par symbole, à sa couleur, avec ce qu'il paie.
func _make_layout(size: Vector2) -> Texture2D:
	var cle := "roue:%s" % size
	if KIT.vue_partagee(cle):
		return KIT.vue_partagee(cle)
	var S := 600.0
	var vp := SubViewport.new()
	vp.size = Vector2i(int(size.x * S), int(size.y * S))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	c.draw.connect(func():
		var ink := Color(0.95, 0.91, 0.79)
		var gold := Color(0.93, 0.74, 0.38)
		var f := KIT.serif()
		for k in KEYS:
			var r: Rect2 = cells[k]
			var px := Rect2(Vector2((r.position.x + size.x / 2.0) * S, (r.position.y - COUNTER_Z + size.y / 2.0) * S), r.size * S)
			var col: Color = WHEEL_COLORS[k]
			c.draw_rect(px, Color(col, 0.28))
			c.draw_rect(px, gold, false, 4.0)
			var name: String = "★" if k == "Étoile" else ("J" if k == "Joker" else k)
			c.draw_string(f, px.position + Vector2(0, px.size.y * 0.55), name, HORIZONTAL_ALIGNMENT_CENTER, px.size.x, 64, ink)
			c.draw_string(f, px.position + Vector2(0, px.size.y * 0.86), "%d contre 1" % PAYS[k], HORIZONTAL_ALIGNMENT_CENTER, px.size.x, 22, gold)
	)
	return KIT.partager(cle, vp)


const WHEEL_COLORS := {"1": Color(0.95, 0.85, 0.3), "2": Color(0.3, 0.6, 0.95), "5": Color(0.85, 0.3, 0.6),
	"10": Color(0.3, 0.8, 0.45), "20": Color(0.95, 0.5, 0.2), "Joker": Color(0.1, 0.1, 0.12), "Étoile": Color(0.95, 0.95, 0.95)}
const PAYS := {"1": 1, "2": 2, "5": 5, "10": 10, "20": 20, "Joker": 40, "Étoile": 40}


## La face de la roue, d'après les cases du panneau : la case i est centrée sur l'angle i × pas,
## dans le sens des aiguilles d'une montre depuis le haut quand la roue est au repos.
func _paint_face() -> void:
	var S := 1024
	var vp := SubViewport.new()
	vp.size = Vector2i(S, S)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	var segs := segments.duplicate()
	c.draw.connect(func():
		var o := Vector2(S, S) / 2.0
		var r := S / 2.0
		var n := segs.size()
		var step := TAU / n
		var f := KIT.serif()
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(S, S)), Color(0.1, 0.05, 0.04))
		for i in n:
			# L'angle de l'image (y vers le bas) part du haut : -PI/2 est en haut.
			var mid := -PI / 2.0 + i * step
			var pts := PackedVector2Array([o])
			for k in 5:
				var a := mid - step / 2.0 + step * k / 4.0
				pts.append(o + Vector2(cos(a), sin(a)) * r)
			var key: String = segs[i]
			c.draw_colored_polygon(pts, WHEEL_COLORS[key])
			c.draw_line(o, o + Vector2(cos(mid - step / 2.0), sin(mid - step / 2.0)) * r, Color(0.85, 0.66, 0.3), 3.0, true)
			var txt: String = "★" if key == "Étoile" else ("J" if key == "Joker" else key)
			var ink := Color(1, 1, 1) if key == "Joker" else Color(0.08, 0.05, 0.04)
			c.draw_set_transform(o + Vector2(cos(mid), sin(mid)) * r * 0.83, mid + PI / 2.0, Vector2.ONE)
			c.draw_string(f, Vector2(-40, 14), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 38 if txt.length() < 2 else 30, ink)
			c.draw_set_transform(Vector2.ZERO)
		c.draw_circle(o, r * 0.32, Color(0.12, 0.05, 0.04))
		c.draw_arc(o, r * 0.32, 0, TAU, 96, Color(0.85, 0.66, 0.3), 6.0, true)
		c.draw_string(f, o + Vector2(-r * 0.3, -8), "CASINO", HORIZONTAL_ALIGNMENT_CENTER, r * 0.6, 40, Color(0.93, 0.74, 0.38))
		c.draw_string(f, o + Vector2(-r * 0.3, 40), "DE SMARVES", HORIZONTAL_ALIGNMENT_CENTER, r * 0.6, 30, Color(0.93, 0.74, 0.38))
	)
	KIT._add_viewport(vp)
	var m: StandardMaterial3D = _face.material_override
	m.albedo_texture = vp.get_texture()


# --- Le lancer ------------------------------------------------------------------------------

## La roue tourne jusqu'à poser la case « idx » sous la languette.
func spin(idx: int, dur: float) -> void:
	var step := TAU / segments.size()
	# Au repos, la case i est à i × pas dans le sens horaire depuis le haut ; tourner la roue
	# de θ dans le sens trigonométrique l'amène en haut quand θ = i × pas.
	var target := idx * step + randf_range(-0.3, 0.3) * step
	while target < _angle + TAU * 3.0:
		target += TAU
	var tw := create_tween()
	tw.tween_method(_turn, _angle, target, dur - 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	# Un plan serré sur la languette quand la roue ralentit, le croupier dans le cadre à droite.
	get_tree().create_timer(dur * 0.55).timeout.connect(func():
		shot(look(Vector3(0.85, 1.5, 2.4), Vector3(0.75, 1.95, 0.0)), 0.8, 64.0))


func _turn(a: float) -> void:
	_angle = a
	_wheel.rotation.z = a
	# La languette claque sur chaque clou qui passe.
	var peg := int(floor(a / (TAU / 54.0)))
	if peg != _last_peg:
		_last_peg = peg
		var lame: Node3D = _flap.get_node("Lame")
		var t := lame.create_tween()
		lame.rotation.z = -0.45
		Sfx.play("tick", -14.0, 1.6)
		t.tween_property(lame, "rotation:z", 0.0, 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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
		var p := cell_center(k) + Vector3(0, 0, -0.06)
		s.position = p + Vector3(0, 0.03, 0)
		add_child(s)
		_stacks[k] = s
		create_tween().tween_property(s, "position:y", p.y + 0.0005, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Sfx.play("chips", -6.0, randf_range(0.95, 1.1))


func settle(result: String, wins: Dictionary) -> void:
	var gone := _stacks.duplicate()
	_stacks.clear()
	var label := "★ ÉTOILE" if result == "Étoile" else ("JOKER" if result == "Joker" else result)
	KIT.popup(self, HUB + Vector3(0, R + 0.5, 0.3), label, 120, Color(1.0, 0.9, 0.66), 1.8)
	glow_cell(result, 3.2)
	await get_tree().create_timer(1.4).timeout
	shot(seat, 0.8, seat_fov)
	var bank := Vector3(0.0, felt_y, COUNTER_Z - COUNTER.y / 2.0 - 0.1)
	var mine := Vector3(0.0, felt_y + 0.3, COUNTER_Z + COUNTER.y / 2.0 + 0.5)
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
		t.tween_property(paid, "position", s.position + Vector3(0.07, 0, 0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.7)
		t.tween_property(paid, "position", mine, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_callback(paid.queue_free)
		var t2 := s.create_tween()
		t2.tween_interval(1.3)
		t2.tween_property(s, "position", mine, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t2.tween_callback(s.queue_free)
	if gain_total > 0:
		var at := Vector3(0.0, felt_y, COUNTER_Z)
		Sfx.play("chips_win", -2.0)
		KIT.burst(self, at + Vector3(0, 0.02, 0), 80 if gain_total < 500 else 160, 0.6, gain_total >= 500)
		KIT.flash(self, at + Vector3(0, 0.4, 0), 3.0 if gain_total < 500 else 6.0)
		KIT.popup(self, at + Vector3(0, 0.2, 0.05), "+ %s" % Game.fmt(gain_total), 110)


# --- Lien avec le panneau ------------------------------------------------------------------

func attach(p: Control) -> void:
	panel = p
	p.embedded = true
	p.table3d = self
	p.make_segments()
	segments = p.segments
	_paint_face()
	p.bets_changed.connect(show_bets)
	p.spin_started.connect(spin)
	p.settled.connect(settle)
	cell_clicked.connect(func(k: String): p._place(k))
