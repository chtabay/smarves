extends "res://scripts/jeux/table_3d.gd"
## Une machine à sous : caisson laqué à filets chromés, fronton à ampoules qui chassent, trois
## vrais tambours qui tournent derrière la vitre, ligne de paiement, pupitre à boutons lumineux,
## bras qu'on tire, tableau des gains rétroéclairé. Assis devant, les tambours suivent exactement
## les bandes du panneau ; au repos, ils tournent doucement sur une bande de vitrine.

const SLOT := preload("res://scripts/slot_machine.gd")
const REEL_R := 0.125
const REEL_W := 0.15
## Cases sur le tour d'un tambour : trois symboles et demi se voient dans la fenêtre. La bande du
## panneau est plus longue ; les cases cachées derrière le tambour sont réécrites au passage.
const K := 10
const WIN_Y := 1.25

## Teintes de caisson (fond, filet lumineux).
const THEMES := [
	[Color(0.42, 0.04, 0.08), Color(1.0, 0.3, 0.35)],
	[Color(0.05, 0.1, 0.32), Color(0.4, 0.65, 1.0)],
	[Color(0.03, 0.26, 0.15), Color(0.4, 1.0, 0.6)],
	[Color(0.36, 0.22, 0.04), Color(1.0, 0.78, 0.35)],
	[Color(0.24, 0.06, 0.32), Color(0.85, 0.5, 1.0)],
]

static var _pay_tex: Texture2D
static var _shop_tex: Texture2D

var title := "JACKPOT"
var theme := 0
var _spins: Array[Node3D] = []
var _reel_mats: Array[StandardMaterial3D] = []
var _bulbs_a: StandardMaterial3D
var _bulbs_b: StandardMaterial3D
var _line_mat: StandardMaterial3D
var _lever: Node3D
var _idle := [0.0, 0.0, 0.0]
var _strip_host: Node
var _ring_syms: Array = []
var _ring_views: Array = []
var _ring_keys := [INF, INF, INF]
var _win_t := 0.0
var _t := 0.0


func _ready() -> void:
	felt_y = 0.0
	seat = look(Vector3(0.0, 1.5, 1.25), Vector3(0.0, 1.3, 0.0))
	seat_fov = 50.0
	_build()


func _build() -> void:
	var th: Array = THEMES[theme % THEMES.size()]
	var body := KIT.mat(th[0], 0.18)
	body.clearcoat_enabled = true
	body.clearcoat = 1.0
	body.clearcoat_roughness = 0.08
	body.metallic = 0.35
	var lacquer := KIT.mat(Color(0.03, 0.025, 0.03), 0.12)
	lacquer.clearcoat_enabled = true
	lacquer.clearcoat = 1.0
	var chrome := KIT.chrome()
	var brass := KIT.brass()
	# Socle, caisson, joues chromées.
	KIT.box(Vector3(0.74, 0.06, 0.62), Vector3(0, 0.03, 0), brass, self)
	KIT.box(Vector3(0.72, 0.78, 0.58), Vector3(0, 0.45, -0.01), lacquer, self)
	# Le caisson du haut, percé de la fenêtre des rouleaux.
	var y0 := 0.84
	var y1 := 1.46
	var wy0 := WIN_Y - 0.15
	var wy1 := WIN_Y + 0.15
	KIT.box(Vector3(0.72, y1 - wy1, 0.56), Vector3(0, (y1 + wy1) / 2.0, -0.02), body, self)
	KIT.box(Vector3(0.72, wy0 - y0, 0.56), Vector3(0, (wy0 + y0) / 2.0, -0.02), body, self)
	for sx in [-1.0, 1.0]:
		KIT.box(Vector3(0.11, wy1 - wy0, 0.56), Vector3(sx * 0.305, WIN_Y, -0.02), body, self)
	for x in [-0.365, 0.365]:
		KIT.box(Vector3(0.016, 1.6, 0.58), Vector3(x, 0.83, -0.01), chrome, self)
	# Le cadre de la fenêtre des rouleaux, et l'ombre derrière les tambours.
	var fz := 0.262
	for b in [[Vector3(0.6, 0.05, 0.03), Vector3(0, WIN_Y + 0.175, fz)], [Vector3(0.6, 0.05, 0.03), Vector3(0, WIN_Y - 0.175, fz)],
			[Vector3(0.05, 0.4, 0.03), Vector3(-0.275, WIN_Y, fz)], [Vector3(0.05, 0.4, 0.03), Vector3(0.275, WIN_Y, fz)]]:
		KIT.box(b[0], b[1], chrome, self)
	KIT.box(Vector3(0.52, 0.32, 0.02), Vector3(0, WIN_Y, -0.02), KIT.mat(Color(0.02, 0.02, 0.02), 0.9), self)
	for k in 2:
		KIT.box(Vector3(0.006, 0.3, 0.26), Vector3(-0.085 + k * 0.17, WIN_Y, 0.11), chrome, self)
	# Les trois tambours.
	var mesh := KIT.lathe(PackedVector2Array([Vector2(REEL_R, -REEL_W / 2.0), Vector2(REEL_R, REEL_W / 2.0)]), 84)
	var cap := KIT.lathe(PackedVector2Array([Vector2(REEL_R, REEL_W / 2.0), Vector2(0.0, REEL_W / 2.0)]), 48)
	for k in 3:
		var spin := Node3D.new()
		spin.position = Vector3(-0.17 + k * 0.17, WIN_Y, 0.12)
		add_child(spin)
		var m := KIT.mat(Color(0.8, 0.79, 0.75), 0.35)
		m.albedo_texture = _shop_strip()
		m.emission_enabled = true
		m.emission = Color(1, 1, 1)
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = 0.1
		var reel := KIT.mesh_node(mesh, m, spin)
		reel.rotation.z = PI / 2.0
		for sgn in [-1.0, 1.0]:
			var c := KIT.mesh_node(cap, KIT.mat(Color(0.1, 0.1, 0.1), 0.5), spin)
			c.rotation.z = PI / 2.0 if sgn > 0 else -PI / 2.0
		_spins.append(spin)
		_reel_mats.append(m)
		_idle[k] = randf() * TAU
	# Ombres de courbure, ligne de paiement et ses flèches, vitre.
	for y in [WIN_Y + 0.12, WIN_Y - 0.12]:
		var sh := KIT.mat(Color(0, 0, 0, 0.55), 1.0)
		sh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sh.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		KIT.box(Vector3(0.5, 0.06, 0.002), Vector3(0, y, 0.252), sh, self)
	_line_mat = KIT.glow(Color(1.0, 0.2, 0.3), 2.5)
	KIT.box(Vector3(0.5, 0.004, 0.003), Vector3(0, WIN_Y, 0.256), _line_mat, self)
	for x in [-0.255, 0.255]:
		var arrow := KIT.box(Vector3(0.022, 0.022, 0.006), Vector3(x, WIN_Y, 0.262), _line_mat, self)
		arrow.rotation.z = PI / 4.0
	var glass := KIT.mat(Color(0.85, 0.9, 1.0, 0.04), 0.02)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic_specular = 0.6
	KIT.box(Vector3(0.5, 0.3, 0.004), Vector3(0, WIN_Y, 0.258), glass, self)
	# Le pupitre et ses boutons.
	var deck := KIT.box(Vector3(0.7, 0.04, 0.22), Vector3(0, 0.86, 0.3), lacquer, self)
	deck.rotation.x = 0.3
	var cols := [Color(1, 0.25, 0.2), Color(1, 0.8, 0.3), Color(0.3, 0.95, 0.45), Color(0.4, 0.7, 1.0)]
	for k in 4:
		var bt := KIT.cyl(0.026 if k < 3 else 0.04, 0.025, Vector3(-0.21 + k * 0.13, 0.893, 0.31), KIT.glow(cols[k], 1.6), self, -1.0, 20)
		bt.rotation.x = 0.3
	KIT.box(Vector3(0.7, 0.012, 0.012), Vector3(0, 0.83, 0.41), chrome, self)
	# Le bac à pièces.
	KIT.box(Vector3(0.44, 0.1, 0.12), Vector3(0, 0.12, 0.31), chrome, self)
	KIT.box(Vector3(0.4, 0.06, 0.1), Vector3(0, 0.15, 0.32), KIT.mat(Color(0.02, 0.02, 0.02), 0.6), self)
	# Le tableau des gains, rétroéclairé, sous le pupitre.
	var pay := KIT.mat(Color.WHITE, 0.3)
	pay.albedo_texture = _paytable()
	pay.emission_enabled = true
	pay.emission_texture = pay.albedo_texture
	pay.emission = Color(1, 1, 1)
	pay.emission_energy_multiplier = 0.55
	var pq := QuadMesh.new()
	pq.size = Vector2(0.6, 0.34)
	KIT.mesh_node(pq, pay, self, Vector3(0, 0.5, 0.282))
	for b in [[Vector3(0.64, 0.02, 0.02), Vector3(0, 0.68, 0.28)], [Vector3(0.64, 0.02, 0.02), Vector3(0, 0.32, 0.28)]]:
		KIT.box(b[0], b[1], brass, self)
	# Le fronton : caisson en arche, nom en lettres d'or, ampoules qui chassent.
	var top := KIT.mat(th[0].darkened(0.3), 0.2)
	top.emission_enabled = true
	top.emission = th[1]
	top.emission_energy_multiplier = 0.35
	KIT.box(Vector3(0.72, 0.36, 0.42), Vector3(0, 1.64, -0.08), top, self)
	var arch := KIT.cyl(0.36, 0.42, Vector3(0, 1.82, -0.08), top, self, -1.0, 48)
	arch.rotation.x = PI / 2.0
	arch.scale = Vector3(1.0, 1.0, 0.42)
	var face := KIT.mat(Color(0.06, 0.03, 0.04), 0.3)
	KIT.box(Vector3(0.6, 0.26, 0.01), Vector3(0, 1.66, 0.135), face, self)
	var name_l := Label3D.new()
	name_l.text = title
	name_l.font = KIT.serif()
	name_l.font_size = 64 if title.length() < 12 else 46
	name_l.pixel_size = 0.0011 if title.length() < 12 else 0.001
	name_l.modulate = Color(1.0, 0.86, 0.5)
	name_l.outline_size = 8
	name_l.outline_modulate = Color(0.3, 0.12, 0.02)
	name_l.position = Vector3(0, 1.68, 0.142)
	add_child(name_l)
	var sub := Label3D.new()
	sub.text = "CASINO DE SMARVES"
	sub.font = KIT.serif()
	sub.font_size = 24
	sub.pixel_size = 0.0011
	sub.modulate = Color(th[1], 0.9)
	sub.outline_size = 0
	sub.position = Vector3(0, 1.585, 0.142)
	add_child(sub)
	_bulbs_a = KIT.glow(Color(1.0, 0.92, 0.7), 4.0)
	_bulbs_b = KIT.glow(Color(1.0, 0.92, 0.7), 0.4)
	var n := 0
	for k in 9:
		var a := PI * k / 8.0
		KIT.sphere(0.016, Vector3(cos(a) * 0.335, 1.84 + sin(a) * 0.15, 0.142), _bulbs_a if n % 2 == 0 else _bulbs_b, self, 8)
		n += 1
	for k in 6:
		for x in [-0.33, 0.33]:
			KIT.sphere(0.014, Vector3(x, 1.5 + k * 0.06, 0.142), _bulbs_a if n % 2 == 0 else _bulbs_b, self, 8)
			n += 1
	# Le bras.
	_lever = Node3D.new()
	_lever.position = Vector3(0.405, 1.1, 0.0)
	add_child(_lever)
	KIT.cyl(0.04, 0.05, Vector3(0, 0, 0), chrome, _lever).rotation.z = PI / 2.0
	KIT.cyl(0.013, 0.42, Vector3(0.03, 0.21, 0), chrome, _lever, -1.0, 12)
	var knob := KIT.mat(Color(0.75, 0.03, 0.06), 0.12)
	knob.clearcoat_enabled = true
	knob.clearcoat = 1.0
	KIT.sphere(0.045, Vector3(0.03, 0.44, 0), knob, _lever)
	# Une lueur colorée qui fait briller la vitre et le sol.
	var o := OmniLight3D.new()
	o.light_color = th[1].lerp(Color(1.0, 0.8, 0.6), 0.5)
	o.light_energy = 0.12
	o.omni_range = 1.3
	o.position = Vector3(0, 0.7, 0.55)
	add_child(o)


## Une bande de vitrine, partagée par toutes les machines au repos.
func _shop_strip() -> Texture2D:
	if _shop_tex == null or not is_instance_valid(_shop_tex):
		var strip := ["7", "♠", "♦", "★", "♥", "♣", "♠", "♦", "♥", "♣"]
		_shop_tex = make_strip(strip, null).get_texture()
	return _shop_tex


## La bande d'un tambour : K cases, un symbole par case, couché pour s'enrouler. Le dessin relit
## « strip » à chaque mise à jour de la vue. Sans hôte, la vue est gardée par le kit (texture
## partagée qui survit aux changements de scène).
static func make_strip(strip: Array, host: Node) -> SubViewport:
	# Une case fait 128 px sur le tour et 244 px sur la largeur, aux proportions du tambour.
	var cs := 128
	var cw := 244
	var vp := SubViewport.new()
	vp.size = Vector2i(cs * strip.size(), cw)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	c.draw.connect(func():
		# Lancée, la bande est un filé : chaque symbole traîne sur la case voisine.
		var blur: bool = c.get_meta("blur") if c.has_meta("blur") else false
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.97, 0.95, 0.89))
		for i in strip.size():
			var r := Rect2(i * cs, 0, cs, cw)
			if blur:
				for d in [-36.0, -18.0, 0.0, 18.0, 36.0]:
					draw_symbol(c, strip[i], r.get_center() + Vector2(d, 0), 112.0, -PI / 2.0)
			else:
				c.draw_rect(Rect2(i * cs, 0, 2, cw), Color(0.82, 0.76, 0.62))
				draw_symbol(c, strip[i], r.get_center(), 112.0, -PI / 2.0)
		if blur:
			c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.97, 0.95, 0.89, 0.55))
	)
	if host:
		host.add_child(vp)
	else:
		KIT._add_viewport(vp)
	return vp


## Les symboles, dessinés en vectoriel (le 7 au trait épais, l'étoile d'or, les enseignes).
static func draw_symbol(c: Control, s: String, at: Vector2, size: float, rot := 0.0) -> void:
	c.draw_set_transform(at, rot, Vector2.ONE)
	match s:
		"7":
			var col := Color(0.82, 0.08, 0.1)
			var gold := Color(0.95, 0.72, 0.25)
			var pts := PackedVector2Array([Vector2(-0.36, -0.42), Vector2(0.38, -0.42), Vector2(0.38, -0.28), Vector2(-0.02, 0.44),
				Vector2(-0.22, 0.44), Vector2(0.16, -0.24), Vector2(-0.36, -0.24)])
			var big := PackedVector2Array()
			var small := PackedVector2Array()
			for p in pts:
				big.append(p * size * 1.12 + Vector2(0, 2))
				small.append(p * size)
			c.draw_colored_polygon(big, gold)
			c.draw_colored_polygon(small, col)
		"★":
			var star := PackedVector2Array()
			var inner := PackedVector2Array()
			for k in 10:
				var a := -PI / 2.0 + PI * k / 5.0
				var rr := (0.48 if k % 2 == 0 else 0.2) * size
				star.append(Vector2(cos(a), sin(a)) * rr)
				inner.append(Vector2(cos(a), sin(a)) * rr * 0.72)
			c.draw_colored_polygon(star, Color(0.75, 0.48, 0.08))
			c.draw_colored_polygon(inner, Color(1.0, 0.82, 0.25))
		_:
			var suit := ["♠", "♥", "♦", "♣"].find(s)
			var cols := [Color(0.12, 0.12, 0.2), Color(0.85, 0.15, 0.3), Color(0.15, 0.45, 0.9), Color(0.1, 0.55, 0.25)]
			KIT.draw_suit(c, suit, at, size * 0.85, cols[suit], false, rot)
	c.draw_set_transform(Vector2.ZERO)


## Le tableau des gains (partagé).
func _paytable() -> Texture2D:
	if _pay_tex != null and is_instance_valid(_pay_tex):
		return _pay_tex
	var vp := SubViewport.new()
	vp.size = Vector2i(600, 340)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.05, 0.03, 0.06))
		c.draw_rect(Rect2(Vector2(6, 6), c.size - Vector2(12, 12)), Color(0.85, 0.65, 0.3), false, 3.0)
		var f := KIT.serif()
		c.draw_string(f, Vector2(0, 46), "GAINS POUR UNE MISE", HORIZONTAL_ALIGNMENT_CENTER, 600, 28, Color(0.95, 0.78, 0.42))
		var i := 0
		for s in SLOT.PAYS:
			var x := 40 + (i % 2) * 290
			var y := 92 + (i / 2) * 64
			for k in 3:
				draw_symbol(c, s, Vector2(x + 20 + k * 44, y), 40.0)
			c.draw_string(f, Vector2(x + 150, y + 13), "× %d" % SLOT.PAYS[s], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.97, 0.93, 0.83))
			i += 1
		c.draw_string(f, Vector2(0, 318), "deux 7 : × 2", HORIZONTAL_ALIGNMENT_CENTER, 600, 24, Color(0.8, 0.74, 0.62))
	)
	KIT._add_viewport(vp)
	_pay_tex = vp.get_texture()
	return _pay_tex


# --- Le jeu -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	super(delta)
	_t += delta
	# Les ampoules chassent, plus vite et toutes ensemble après un gain.
	var fast := _win_t > 0.0
	_win_t = maxf(_win_t - delta, 0.0)
	var phase := int(_t * (12.0 if fast else 3.0)) % 2 == 0
	if fast:
		_bulbs_a.emission_energy_multiplier = 6.0 if phase else 0.5
		_bulbs_b.emission_energy_multiplier = 6.0 if phase else 0.5
		_line_mat.emission = Color(1.0, 0.82, 0.35)
		_line_mat.emission_energy_multiplier = 3.0 + 2.0 * sin(_t * 18.0)
	else:
		_bulbs_a.emission_energy_multiplier = 4.0 if phase else 0.4
		_bulbs_b.emission_energy_multiplier = 0.4 if phase else 4.0
		_line_mat.emission = Color(1.0, 0.2, 0.3)
		_line_mat.emission_energy_multiplier = 2.5
	if panel and is_instance_valid(panel) and not panel.strips.is_empty():
		if _strip_host == null:
			_strip_host = Node.new()
			add_child(_strip_host)
			_ring_syms.clear()
			_ring_views.clear()
			for k in 3:
				var syms := []
				syms.resize(K)
				syms.fill("♠")
				var vp := make_strip(syms, _strip_host)
				_ring_syms.append(syms)
				_ring_views.append(vp)
				_ring_keys[k] = INF
				_reel_mats[k].albedo_texture = vp.get_texture()
				_reel_mats[k].emission_texture = vp.get_texture()
		for k in 3:
			# Le symbole au centre de la fenêtre du panneau : offset / case + 1.
			var c: float = panel.offsets[k] / SLOT.CELL + 1.0
			_fill_ring(k, c, panel.strips[k], panel.speeds[k] > 0.0)
			_spins[k].rotation.x = PI / 2.0 - (c + 0.5) * TAU / K
	elif not active:
		for k in 3:
			_idle[k] += delta * 0.05
			_spins[k].rotation.x = _idle[k]


## Recopie sur le tambour les K symboles de la bande les plus proches du centre « c » : la case j
## porte le symbole i de la bande, avec i ≡ j (mod K). Ne redessine que si une case a changé.
func _fill_ring(k: int, c: float, strip: Array, blur: bool) -> void:
	var key := floorf(c + 0.5) + (0.5 if blur else 0.0)
	if key == _ring_keys[k]:
		return
	_ring_keys[k] = key
	var n := strip.size()
	var syms: Array = _ring_syms[k]
	for j in K:
		var i := j + K * roundi((c - j) / K)
		syms[j] = strip[posmod(i, n)]
	var vp: SubViewport = _ring_views[k]
	vp.get_child(0).set_meta("blur", blur)
	vp.get_child(0).queue_redraw()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func pull() -> void:
	var tw := _lever.create_tween()
	tw.tween_property(_lever, "rotation:x", 0.9, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_lever, "rotation:x", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play("click", -4.0, 0.7)


func won(bet: int, payout: int) -> void:
	if payout <= 0:
		return
	_win_t = 2.6 if payout < bet * 20 else 5.0
	var at := Vector3(0, WIN_Y - 0.08, 0.34)
	KIT.burst(self, at, 90 if payout < bet * 20 else 220, 0.6, payout >= bet * 20)
	KIT.flash(self, at + Vector3(0, 0.2, 0.2), 3.0 if payout < bet * 20 else 7.0)
	KIT.popup(self, at + Vector3(0, 0.0, 0.05), ("JACKPOT !  + %s" if payout >= bet * 100 else "+ %s") % Game.fmt(payout), 44)


func attach(p: Control) -> void:
	panel = p
	p.embedded = true
	p.reels_started.connect(pull)
	p.played.connect(won)


func stand() -> void:
	super()
	panel = null
	if _strip_host:
		_strip_host.queue_free()
		_strip_host = null
	for k in 3:
		_reel_mats[k].albedo_texture = _shop_strip()
		_reel_mats[k].emission_texture = _reel_mats[k].albedo_texture
		_idle[k] = _spins[k].rotation.x
