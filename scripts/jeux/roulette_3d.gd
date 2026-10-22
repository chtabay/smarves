extends "res://scripts/jeux/table_3d.gd"
## La table de roulette européenne : cylindre tourné en acajou (cuvette, piste de la bille, losanges
## déflecteurs, cases à frettes de laiton, cône et croisillon), tapis imprimé où l'on mise en cliquant,
## piles de jetons, bille qui tourne, ralentit, descend, rebondit et tombe dans sa case, « dolly »
## posé sur le numéro, perdants ramassés et gagnants payés.

const WHEEL := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const STEP := TAU / 37.0

## Géométrie du tapis (mètres, repère de la table ; le joueur est du côté +z).
const CW := 0.125
const CH := 0.15
const X0 := -0.475
const Z0 := -0.40
const DZ := 0.11
const FELT := Vector2(3.2, 1.28)

## Géométrie du cylindre (repère de la roue).
const R_TRACK := 0.403
const Y_TRACK := 0.1345
const R_POCKET := 0.2425
const Y_POCKET := 0.0755
const BALL_R := 0.0095

var wheel_at := Vector3(-1.12, 0.72, 0.0)
var wheel: Node3D
var rotor: Node3D
var ball: MeshInstance3D
var dolly: Node3D
var _stacks := {}
var _leaving: Array[Node3D] = []
var _layout_tex: Texture2D

# Le lancer en cours.
var _spinning := false
var _t := 0.0
var _dur := 7.0
var _rotor_angle := 0.0
var _rotor_c := 0.0
var _ball_phi := 0.0
var _ball_rest := -1.0
var _target := 0
var _psi0 := 0.0
var _phase3 := false
const IDLE := 0.35
const K := 0.32
const DPSI := 3.0


func _ready() -> void:
	felt_y = 0.78
	seat = look(Vector3(0.2, 1.66, 1.15), Vector3(0.0, 0.78, -0.4))
	seat_fov = 58.0
	_build_table()
	_build_wheel()
	_build_cells()
	_ball_rest = 0.0


# --- La table ------------------------------------------------------------------------------

func _build_table() -> void:
	var mahogany := KIT.varnished(Color(0.36, 0.13, 0.06))
	var dark := KIT.varnished(Color(0.16, 0.06, 0.03), 0.7)
	var brass := KIT.brass()
	var leather := KIT.leather()
	# Plateau, ceinture, piètement tourné.
	KIT.box(Vector3(3.36, 0.1, 1.44), Vector3(0, felt_y - 0.056, 0), mahogany, self)
	KIT.box(Vector3(3.38, 0.016, 1.46), Vector3(0, felt_y - 0.1, 0), brass, self)
	KIT.box(Vector3(3.1, 0.2, 1.2), Vector3(0, felt_y - 0.2, 0), dark, self)
	for x in [-1.45, 1.45]:
		for z in [-0.52, 0.52]:
			KIT.turned_leg(felt_y - 0.3, 0.05, mahogany, self, Vector3(x, 0, z))
	KIT.box(Vector3(2.9, 0.05, 0.08), Vector3(0, 0.12, 0), dark, self)
	# Le tapis imprimé.
	_layout_tex = _make_layout()
	var pm := PlaneMesh.new()
	pm.size = FELT
	KIT.mesh_node(pm, KIT.felt(Color(0.03, 0.27, 0.15), FELT, _layout_tex), self, Vector3(0, felt_y, 0))
	# La main courante de cuir, sur trois côtés, avec un jonc de laiton.
	var hx := FELT.x / 2.0 + 0.04
	var hz := FELT.y / 2.0 + 0.04
	var ry := felt_y + 0.03
	KIT.rail(Vector3(-hx, ry, hz), Vector3(hx, ry, hz), 0.045, leather, self)
	KIT.rail(Vector3(hx, ry, -hz), Vector3(hx, ry, hz), 0.045, leather, self)
	KIT.rail(Vector3(-hx, ry, -hz), Vector3(-hx, ry, hz), 0.045, leather, self)
	KIT.box(Vector3(3.3, 0.012, 0.012), Vector3(0, felt_y + 0.002, hz - 0.05), brass, self)
	# Côté croupier : le flotteur de jetons, le râteau.
	var tray := KIT.box(Vector3(0.62, 0.035, 0.16), Vector3(-0.2, felt_y + 0.0175, -0.54), KIT.varnished(Color(0.05, 0.03, 0.03), 1.0), self)
	tray.name = "Flotteur"
	var vals := [500, 100, 25, 5, 1, 25, 100]
	for k in vals.size():
		var s := KIT.chip_stack(vals[k] * 20, [vals[k]], 20)
		s.position = Vector3(-0.47 + k * 0.08, felt_y + 0.035, -0.54)
		add_child(s)
	var rake := KIT.cyl(0.006, 0.9, Vector3(0.6, felt_y + 0.008, -0.5), KIT.varnished(Color(0.45, 0.25, 0.1)), self)
	rake.rotation_degrees = Vector3(0, 12, 90)
	KIT.box(Vector3(0.012, 0.012, 0.16), Vector3(1.04, felt_y + 0.008, -0.41), KIT.varnished(Color(0.45, 0.25, 0.1)), self).rotation_degrees.y = 12
	# Le dolly, au repos sur le bord.
	dolly = Node3D.new()
	add_child(dolly)
	KIT.cyl(0.014, 0.008, Vector3(0, 0.004, 0), brass, dolly)
	KIT.cyl(0.006, 0.035, Vector3(0, 0.024, 0), brass, dolly)
	var crystal := KIT.mat(Color(0.9, 0.95, 1.0, 0.35), 0.02)
	crystal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal.metallic_specular = 1.0
	crystal.refraction_enabled = true
	crystal.refraction_scale = 0.05
	KIT.sphere(0.014, Vector3(0, 0.05, 0), crystal, dolly)
	dolly.position = Vector3(0.25, felt_y, -0.6)
	# La lampe au-dessus de la table.
	if with_lamp:
		KIT.table_spot(self, Vector3(-0.3, 2.6, 0.2), Vector3(-0.3, felt_y, 0.0), 2.0, 42.0)


## Le tapis : grille des numéros, colonnes, douzaines, chances simples, filets crème et or.
func _make_layout() -> Texture2D:
	var cle := "roulette"
	if KIT.vue_partagee(cle):
		return KIT.vue_partagee(cle)
	var S := 640.0
	var vp := SubViewport.new()
	vp.size = Vector2i(int(FELT.x * S), int(FELT.y * S))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	var to_px := func(x: float, z: float) -> Vector2:
		return Vector2((x + FELT.x / 2.0) * S, (z + FELT.y / 2.0) * S)
	c.draw.connect(func():
		var ink := Color(0.95, 0.91, 0.79)
		var gold := Color(0.93, 0.74, 0.38)
		var red := Color(0.58, 0.03, 0.05)
		var black := Color(0.06, 0.06, 0.07)
		var f := KIT.serif()
		var lw := 4.0
		var rect := func(x: float, z: float, w: float, h: float) -> Rect2:
			var a: Vector2 = to_px.call(x, z)
			return Rect2(a, Vector2(w, h) * S)
		# Le zéro, une case en pointe.
		var zr: Rect2 = rect.call(X0 - CW, Z0, CW, CH * 3)
		var tip := PackedVector2Array([zr.position + Vector2(zr.size.x, 0), zr.position + Vector2(zr.size.x * 0.35, 0),
			zr.position + Vector2(0, zr.size.y / 2.0), zr.position + Vector2(zr.size.x * 0.35, zr.size.y), zr.end])
		c.draw_polyline(tip, ink, lw, true)
		c.draw_set_transform(zr.get_center(), -PI / 2.0, Vector2.ONE)
		c.draw_circle(Vector2.ZERO, 30, Color(0.04, 0.42, 0.22))
		c.draw_string(f, Vector2(-40, 15), "0", HORIZONTAL_ALIGNMENT_CENTER, 80, 44, ink)
		c.draw_set_transform(Vector2.ZERO)
		for col in 12:
			for row in 3:
				var n := col * 3 + (3 - row)
				var r: Rect2 = rect.call(X0 + col * CW, Z0 + row * CH, CW, CH)
				c.draw_rect(r, ink, false, lw)
				var ctr := r.get_center()
				c.draw_set_transform(ctr, -PI / 2.0, Vector2(1.0, 1.0))
				_ellipse(c, Vector2.ZERO, Vector2(36, 27), red if n in RED else black)
				c.draw_string(f, Vector2(-40, 14), str(n), HORIZONTAL_ALIGNMENT_CENTER, 80, 38, ink)
				c.draw_set_transform(Vector2.ZERO)
		for row in 3:
			var r: Rect2 = rect.call(X0 + 12 * CW, Z0 + row * CH, CW, CH)
			c.draw_rect(r, ink, false, lw)
			c.draw_set_transform(r.get_center(), -PI / 2.0, Vector2.ONE)
			c.draw_string(f, Vector2(-40, 12), "2 : 1", HORIZONTAL_ALIGNMENT_CENTER, 80, 28, ink)
			c.draw_set_transform(Vector2.ZERO)
		var dozens := ["1re 12", "2e 12", "3e 12"]
		for d in 3:
			var r: Rect2 = rect.call(X0 + d * 4 * CW, Z0 + 3 * CH, 4 * CW, DZ)
			c.draw_rect(r, ink, false, lw)
			c.draw_string(f, r.position + Vector2(0, r.size.y * 0.66), dozens[d], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, ink)
		var outs := ["1 à 18", "PAIR", "", "", "IMPAIR", "19 à 36"]
		for k in 6:
			var r: Rect2 = rect.call(X0 + k * 2 * CW, Z0 + 3 * CH + DZ, 2 * CW, DZ)
			c.draw_rect(r, ink, false, lw)
			if k == 2 or k == 3:
				var ctr := r.get_center()
				var dw := r.size.x * 0.26
				var dh := r.size.y * 0.3
				var pts := PackedVector2Array([ctr + Vector2(-dw, 0), ctr + Vector2(0, -dh), ctr + Vector2(dw, 0), ctr + Vector2(0, dh)])
				c.draw_colored_polygon(pts, red if k == 2 else black)
				pts.append(pts[0])
				c.draw_polyline(pts, ink, 2.0, true)
			else:
				c.draw_string(f, r.position + Vector2(0, r.size.y * 0.66), outs[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, ink)
		# Un filet d'or autour du tapis, et l'enseigne de la maison.
		var all: Rect2 = Rect2(Vector2.ZERO, c.size).grow(-14)
		c.draw_rect(all, gold, false, 3.0)
		c.draw_rect(all.grow(-10), Color(gold, 0.5), false, 1.5)
		var brand: Vector2 = to_px.call(1.4, Z0 + 1.5 * CH + 0.06)
		c.draw_set_transform(brand, -PI / 2.0, Vector2.ONE)
		c.draw_string(f, Vector2(-260, 0), "CASINO DE SMARVES", HORIZONTAL_ALIGNMENT_CENTER, 520, 46, gold)
		c.draw_string(f, Vector2(-260, 46), "Roulette européenne · un seul zéro", HORIZONTAL_ALIGNMENT_CENTER, 520, 24, Color(ink, 0.8))
		c.draw_set_transform(Vector2.ZERO)
	)
	return KIT.partager(cle, vp)


static func _ellipse(c: Control, at: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		pts.append(at + Vector2(cos(a) * r.x, sin(a) * r.y))
	c.draw_colored_polygon(pts, col)


func _build_cells() -> void:
	cells["n0"] = Rect2(X0 - CW, Z0, CW, CH * 3)
	for col in 12:
		for row in 3:
			cells["n%d" % (col * 3 + (3 - row))] = Rect2(X0 + col * CW, Z0 + row * CH, CW, CH)
	for row in 3:
		cells["col%d" % (3 - row)] = Rect2(X0 + 12 * CW, Z0 + row * CH, CW, CH)
	for d in 3:
		cells["doz%d" % (d + 1)] = Rect2(X0 + d * 4 * CW, Z0 + 3 * CH, 4 * CW, DZ)
	var outs := ["low", "even", "red", "black", "odd", "high"]
	for k in 6:
		cells[outs[k]] = Rect2(X0 + k * 2 * CW, Z0 + 3 * CH + DZ, 2 * CW, DZ)


# --- Le cylindre -----------------------------------------------------------------------------

func _build_wheel() -> void:
	wheel = Node3D.new()
	wheel.position = wheel_at
	add_child(wheel)
	var mahogany := KIT.varnished(Color(0.3, 0.1, 0.04))
	var track := KIT.mat(Color(0.16, 0.06, 0.025), 0.12)
	track.clearcoat_enabled = true
	track.clearcoat = 1.0
	track.clearcoat_roughness = 0.03
	var brass := KIT.brass()
	# La cuvette : flanc, lèvre, piste de la bille, puis la pente des losanges.
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(0.44, 0.0), Vector2(0.462, 0.07), Vector2(0.462, 0.14),
		Vector2(0.452, 0.162), Vector2(0.43, 0.168)]), 96), mahogany, wheel)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(0.43, 0.168), Vector2(0.418, 0.162), Vector2(0.414, 0.14),
		Vector2(0.405, 0.125), Vector2(0.37, 0.112), Vector2(0.31, 0.088), Vector2(0.305, 0.07)]), 96), track, wheel)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.452
	rim.outer_radius = 0.47
	rim.rings = 96
	rim.ring_segments = 12
	KIT.mesh_node(rim, brass, wheel, Vector3(0, 0.155, 0))
	# Les huit losanges déflecteurs, alternés debout et couchés.
	for k in 8:
		var a := TAU * k / 8.0 + 0.2
		var r := 0.355
		var d := KIT.box(Vector3(0.028, 0.008, 0.012) if k % 2 == 0 else Vector3(0.012, 0.012, 0.03), Vector3(cos(a) * r, _apron_y(r) + 0.005, sin(a) * r), brass, wheel)
		d.rotation.y = -a
		d.rotation.z = 0.35
	# Le rotor : bandeau des numéros, cases, frettes, cône, croisillon.
	rotor = Node3D.new()
	wheel.add_child(rotor)
	var ring_tex := _make_ring_texture()
	var ring_mat := KIT.mat(Color.WHITE, 0.28)
	ring_mat.albedo_texture = ring_tex
	ring_mat.uv1_scale = Vector3(1, 0.8, 1)
	ring_mat.clearcoat_enabled = true
	ring_mat.clearcoat = 0.8
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(0.306, 0.086), Vector2(0.272, 0.077)]), 148), ring_mat, rotor)
	var pocket_mat := KIT.mat(Color.WHITE, 0.4)
	pocket_mat.albedo_texture = ring_tex
	pocket_mat.uv1_scale = Vector3(1, 0.0, 1)
	pocket_mat.uv1_offset = Vector3(0, 0.92, 0)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(0.272, 0.077), Vector2(0.27, 0.066), Vector2(0.215, 0.066), Vector2(0.213, 0.079)]), 148), pocket_mat, rotor)
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(0.213, 0.079), Vector2(0.17, 0.093), Vector2(0.11, 0.108), Vector2(0.06, 0.118), Vector2(0.045, 0.12)]), 96), mahogany, rotor)
	for i in 37:
		var a := i * STEP
		var fret := KIT.box(Vector3(0.058, 0.014, 0.0026), Vector3(cos(a) * 0.2425, 0.073, sin(a) * 0.2425), brass, rotor)
		fret.rotation.y = -a
	for r in [0.214, 0.271]:
		var t := TorusMesh.new()
		t.inner_radius = r - 0.0025
		t.outer_radius = r + 0.0025
		t.rings = 96
		t.ring_segments = 6
		KIT.mesh_node(t, brass, rotor, Vector3(0, 0.079 if r < 0.25 else 0.078, 0))
	KIT.mesh_node(KIT.lathe(PackedVector2Array([Vector2(0.052, 0.118), Vector2(0.05, 0.128), Vector2(0.03, 0.14),
		Vector2(0.012, 0.16), Vector2(0.01, 0.2), Vector2(0.018, 0.212), Vector2(0.014, 0.228), Vector2(0.0, 0.234)]), 32), brass, rotor)
	for k in 4:
		var a := k * PI / 2.0
		var arm := KIT.cyl(0.0045, 0.15, Vector3(cos(a) * 0.075, 0.2, sin(a) * 0.075), brass, rotor, -1.0, 12)
		arm.rotation = Vector3(0, -a, PI / 2.0)
		KIT.sphere(0.011 if k % 2 == 0 else 0.008, Vector3(cos(a) * 0.152, 0.2, sin(a) * 0.152), brass, rotor)
	# La bille d'ivoire.
	var ivory := KIT.mat(Color(0.82, 0.8, 0.76), 0.3)
	ball = KIT.sphere(BALL_R, Vector3.ZERO, ivory, wheel)
	# Un petit éclairage qui fait briller le laiton du cylindre.
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.85, 0.65)
	o.light_energy = 0.25
	o.omni_range = 1.0
	o.position = Vector3(0.1, 0.55, 0.35)
	wheel.add_child(o)


func _apron_y(r: float) -> float:
	return lerpf(0.088, 0.125, clampf((r - 0.31) / (0.405 - 0.31), 0.0, 1.0))


## Le bandeau des numéros : 37 secteurs colorés, numéro crème, filets d'or ; en bas, la couleur pure
## pour le fond des cases.
func _make_ring_texture() -> Texture2D:
	var cle := "roulette:cylindre"
	if KIT.vue_partagee(cle):
		return KIT.vue_partagee(cle)
	var sw := 80
	var vp := SubViewport.new()
	vp.size = Vector2i(sw * 37, 128)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	c.draw.connect(func():
		var f := KIT.serif()
		for i in 37:
			var n: int = WHEEL[i]
			var col := Color(0.04, 0.42, 0.2) if n == 0 else (Color(0.72, 0.06, 0.09) if n in RED else Color(0.06, 0.06, 0.07))
			c.draw_rect(Rect2(i * sw, 0, sw, 128), col)
			c.draw_rect(Rect2(i * sw, 0, 3, 102), Color(0.9, 0.72, 0.38))
			# Lu depuis l'extérieur de la roue, le haut des chiffres vers le centre.
			c.draw_set_transform(Vector2(i * sw + sw / 2.0, 50), PI, Vector2.ONE)
			c.draw_string(f, Vector2(-sw / 2.0, 16), str(n), HORIZONTAL_ALIGNMENT_CENTER, sw, 44, Color(0.97, 0.93, 0.82))
			c.draw_set_transform(Vector2.ZERO)
		c.draw_rect(Rect2(0, 100, sw * 37, 3), Color(0.9, 0.72, 0.38))
	)
	return KIT.partager(cle, vp)


# --- Le lancer --------------------------------------------------------------------------------

## Lance la bille : elle finira dans la case du numéro n au bout de « dur » secondes.
func spin(n: int, dur: float) -> void:
	_target = WHEEL.find(n)
	_dur = dur
	_t = 0.0
	_spinning = true
	_phase3 = false
	# La bille part de la main du croupier, côté joueurs.
	_ball_phi = PI * 0.5
	# On règle l'élan du rotor pour que la case visée arrive sous la bille au bon moment.
	var t2 := _dur * 0.76
	var phi2 := _ball_phi + _ball_travel(t2)
	var base := IDLE * t2
	var e := (1.0 - exp(-K * t2)) / K
	# Angle relatif final : psi_end = phi2 + theta(t2) + DPSI doit valoir l'angle de la case (modulo 2π).
	var aim := (_target + 0.5) * STEP
	var need := fposmod(aim - (phi2 + _rotor_angle + base + DPSI), TAU) + TAU * 2.0
	_rotor_c = need / e
	_rotor_start = _rotor_angle
	Sfx.play("shake", -16.0, 1.6)


var _rotor_start := 0.0


## Le chemin parcouru par la bille (angle) pendant les deux premières phases.
func _ball_travel(t: float) -> float:
	var t1 := _dur * 0.56
	var t2 := _dur * 0.76
	var w0 := 13.0
	var w1 := 5.0
	var w2 := 3.0
	if t <= t1:
		return w0 * t + (w1 - w0) * t * t / (2.0 * t1)
	var a1 := (w0 + w1) * t1 / 2.0
	var u := minf(t, t2) - t1
	var d := t2 - t1
	return a1 + w1 * u + (w2 - w1) * u * u / (2.0 * d)


func _process(delta: float) -> void:
	super(delta)
	if rotor == null:
		return
	if not _spinning:
		_rotor_angle += IDLE * delta
		rotor.rotation.y = _rotor_angle
		if _ball_rest >= 0.0:
			_place_ball(_ball_rest - _rotor_angle, R_POCKET, Y_POCKET)
		return
	_t += delta
	var t := minf(_t, _dur)
	_rotor_angle = _rotor_start + IDLE * t + _rotor_c * (1.0 - exp(-K * t)) / K
	rotor.rotation.y = _rotor_angle
	var t1 := _dur * 0.56
	var t2 := _dur * 0.76
	if t < t1:
		_place_ball(PI * 0.5 + _ball_travel(t), R_TRACK, Y_TRACK)
	elif t < t2:
		var k := (t - t1) / (t2 - t1)
		var r := lerpf(R_TRACK, 0.31, k * k)
		var y := _apron_y(r) + BALL_R
		# Le choc sur un losange : un petit saut.
		y += 0.012 * maxf(sin(clampf((k - 0.45) / 0.25, 0.0, 1.0) * PI), 0.0)
		_place_ball(PI * 0.5 + _ball_travel(t), r, y)
	else:
		if not _phase3:
			_phase3 = true
			_psi0 = PI * 0.5 + _ball_travel(t2) + (_rotor_start + IDLE * t2 + _rotor_c * (1.0 - exp(-K * t2)) / K)
			Sfx.play("tick", -8.0, 1.4)
		var s := clampf((t - t2) / (_dur - t2), 0.0, 1.0)
		var psi := _psi0 + DPSI * (1.0 - pow(1.0 - s, 2.2))
		var r := lerpf(0.31, R_POCKET, smoothstep(0.0, 0.3, s))
		var hop := 0.016 * absf(sin(s * PI * 3.5)) * pow(1.0 - s, 2.0)
		var y := lerpf(0.088 + BALL_R, Y_POCKET, smoothstep(0.0, 0.25, s)) + hop
		_place_ball(psi - _rotor_angle, r, y)
		if s > 0.2 and int(s * 7.0) != int((s - delta / (_dur - t2)) * 7.0) and s < 0.75:
			Sfx.play("tick", -12.0, 1.8 + randf() * 0.4)
	if _t >= _dur:
		_spinning = false
		_ball_rest = (_target + 0.5) * STEP


func _place_ball(phi: float, r: float, y: float) -> void:
	# Angle « monde » phi dans le repère fixe de la roue.
	ball.position = Vector3(cos(phi) * r, y, sin(phi) * r)


# --- Les mises -----------------------------------------------------------------------------

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
		var p := cell_center(k)
		s.position = p + Vector3(randf_range(-0.006, 0.006), 0.0005, randf_range(-0.006, 0.006))
		add_child(s)
		_stacks[k] = s
		# Le jeton tombe sur le tapis.
		s.position.y += 0.03
		create_tween().tween_property(s, "position:y", p.y + 0.0005, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Sfx.play("chips", -6.0, randf_range(0.95, 1.1))


## Le coup est joué : le dolly se pose, les perdants sont ramassés, les gagnants payés.
func settle(n: int, wins: Dictionary) -> void:
	var stacks := _stacks.duplicate()
	_stacks.clear()
	var key := "n%d" % n
	glow_cell(key, 3.4)
	for k in wins:
		if wins[k] > 0 and k != key:
			glow_cell(k, 3.4)
	var col := "VERT" if n == 0 else ("ROUGE" if n in RED else "NOIR")
	KIT.popup(wheel, Vector3(0, 0.24, -0.05), "%d  %s" % [n, col], 64, Color(1.0, 0.88, 0.55) if n == 0 else (Color(1.0, 0.42, 0.38) if n in RED else Color(0.95, 0.93, 0.88)), 1.4)
	# On reste un instant sur la bille, puis on revient au tapis pour le paiement.
	await get_tree().create_timer(1.3).timeout
	shot(seat, 0.9, seat_fov)
	await get_tree().create_timer(0.5).timeout
	var dest := cell_center(key)
	var tw := create_tween()
	tw.tween_property(dolly, "position", dest + Vector3(0, 0.12, 0), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(dolly, "position", dest, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	await get_tree().create_timer(0.5).timeout
	var croupier := Vector3(-0.2, felt_y + 0.04, -0.54)
	var total_win := 0
	for k in stacks:
		var s: Node3D = stacks[k]
		var w: int = int(wins.get(k, 0))
		if w <= 0:
			var t := s.create_tween()
			t.tween_property(s, "position", croupier, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			t.parallel().tween_property(s, "scale", Vector3.ONE * 0.3, 0.55)
			t.tween_callback(s.queue_free)
		else:
			total_win += w
			var paid := KIT.chip_stack(w - int(s.get_meta("amount")))
			paid.position = croupier
			add_child(paid)
			var t := paid.create_tween()
			t.tween_property(paid, "position", s.position + Vector3(0.045, 0, 0.0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_interval(0.7)
			t.tween_property(paid, "position", Vector3(0.4, felt_y, 0.55), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t.tween_callback(paid.queue_free)
			var t2 := s.create_tween()
			t2.tween_interval(1.3)
			t2.tween_property(s, "position", Vector3(0.36, felt_y, 0.55), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t2.tween_callback(s.queue_free)
	if total_win > 0:
		Sfx.play("chips_win", -2.0, 1.0)
		KIT.burst(self, dest + Vector3(0, 0.02, 0), 80 if total_win < 500 else 160, 0.5)
		KIT.flash(self, dest + Vector3(0, 0.4, 0), 3.0 if total_win < 500 else 6.0)
		KIT.popup(self, dest + Vector3(0, 0.15, 0.05), "+ %s" % Game.fmt(total_win), 110)
	await get_tree().create_timer(2.2).timeout
	var back := create_tween()
	back.tween_property(dolly, "position", Vector3(0.25, felt_y, -0.6), 0.5).set_trans(Tween.TRANS_CUBIC)


# --- Lien avec le panneau ------------------------------------------------------------------

func attach(p: Control) -> void:
	panel = p
	p.embedded = true
	p.spin_time = 7.0
	p.bets_changed.connect(show_bets)
	p.spin_started.connect(func(n: int, dur: float):
		spin(n, dur)
		await get_tree().create_timer(0.5).timeout
		var w := wheel.position
		shot(look(w + Vector3(0.62, 0.52, 0.5), w + Vector3(0.0, 0.05, 0.0)), 1.3, 42.0))
	p.settled.connect(settle)
	cell_clicked.connect(func(k: String): p._place_bet(k))
