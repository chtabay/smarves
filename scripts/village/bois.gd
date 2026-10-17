extends RefCounted
## La route du Bois : de la place (x = 11,3) à l'allée du château dans le bois de Saint-Pierre (x = 58,9).
## Le garage Fradin et sa cour à pompes, la pharmacie, le rond-point du vieux chêne, l'école publique
## et sa cour, le stade municipal sous ses projecteurs, et les pavillons des années 70 côté sud.
## Les rangées sont dans village.gd (BOIS_NORTH, BOIS_SOUTH) ; ici, ce qui n'est pas une maison de bourg.

const X0 := 11.3
const X1 := 58.9
## Le rond-point du vieux chêne : son centre sur la route, le rayon de l'îlot, de l'anneau, de la trajectoire.
const ROND_X := 23.4
const ISLAND_R := 1.3
const RING_R := 3.1
const DRIVE_R := 2.3
## Sur cette demi-longueur, de part et d'autre du centre, les voitures quittent leur file pour contourner l'îlot.
const SWERVE := 3.6

const CREPIS := [Color(0.96, 0.93, 0.86), Color(0.94, 0.88, 0.78), Color(0.97, 0.9, 0.84), Color(0.9, 0.9, 0.86)]
const MECA := [Color(0.62, 0.32, 0.22), Color(0.55, 0.3, 0.24), Color(0.68, 0.38, 0.26)]


## Où passe une voiture de la file lane (écart à l'axe de la route) quand elle est en x, et sa pente dz/dx.
static func road_z(x: float, lane: float, road_z: float) -> Vector2:
	var dx := x - ROND_X
	if absf(dx) >= SWERVE or lane == 0.0:
		return Vector2(road_z + lane, 0.0)
	var s := signf(lane)
	var extra := (DRIVE_R - absf(lane)) * 0.5
	var z := road_z + s * (absf(lane) + extra * (1.0 + cos(PI * dx / SWERVE)))
	var dz := s * extra * -sin(PI * dx / SWERVE) * PI / SWERVE
	return Vector2(z, dz)


## Le rond-point : l'anneau d'enrobé, sa bordure, l'îlot de pelouse et le vieux chêne.
static func rond_point(v: Node3D, f: RefCounted) -> void:
	var c := Vector3(ROND_X, 0, v.ROAD_Z)
	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.85, 0.83, 0.78)
	_disc(v, c, RING_R + 0.14, 0.035, curb)
	_disc(v, c, RING_R, 0.04, v.mats.asphalt)
	_disc(v, c, ISLAND_R + 0.1, 0.2, curb)
	_disc(v, c, ISLAND_R, 0.22, v.mats.grass)
	v.main._solid_box(Vector3(ISLAND_R * 1.6, 1.0, ISLAND_R * 1.6), c + Vector3(0, 0.5, 0))
	# Le vieux chêne, gardé quand on a fait le rond-point, et ses massifs de chrysanthèmes.
	var oak: Node3D = v._place(v.KN + "tree_oak_fall.glb", c + Vector3(0, 0.2, 0), 3.0, 40.0)
	oak.name = "VieuxChene"
	for i in 8:
		var a := TAU * i / 8.0
		v._place(v.KN + ["flower_yellowA", "flower_redB", "flower_purpleA"][i % 3] + ".glb", c + Vector3(cos(a) * 1.0, 0.2, sin(a) * 1.0), 1.0, i * 45.0)
	# Le panneau de direction, à l'ancienne, sur le coin nord-est.
	_direction_sign(v, c + Vector3(3.2, 0, -2.4), ["École · Stade  →", "Bois de Saint-Pierre  →", "←  Place de la Mairie"])


## Un disque posé au sol en at, dont le dessus est à la hauteur top.
static func _disc(v: Node3D, at: Vector3, r: float, top: float, mat: Material) -> void:
	var h := top + 0.1
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 40
	m.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at + Vector3(0, top - h / 2.0, 0)
	v.add_child(mi)


## Un poteau à plaques blanches bordées de bleu, comme sur les routes de campagne.
static func _direction_sign(v: Node3D, at: Vector3, lines: Array) -> void:
	var pole := StandardMaterial3D.new()
	pole.albedo_color = Color(0.6, 0.6, 0.62)
	v.main._box(Vector3(0.07, 1.7, 0.07), at + Vector3(0, 0.85, 0), pole, v)
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.96, 0.96, 0.94)
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.15, 0.25, 0.55)
	for i in lines.size():
		var y := 1.55 - i * 0.26
		v.main._box(Vector3(1.5, 0.22, 0.03), at + Vector3(0, y, 0), rim, v)
		v.main._box(Vector3(1.44, 0.17, 0.04), at + Vector3(0, y, 0), plate, v)
		for side in [1.0, -1.0]:
			var l := Label3D.new()
			l.text = lines[i]
			l.font = v.main.serif
			l.font_size = 40
			l.pixel_size = 0.0028
			l.modulate = Color(0.12, 0.18, 0.4)
			l.outline_size = 0
			l.double_sided = false
			l.position = at + Vector3(0, y, 0.025 * side)
			l.rotation.y = 0.0 if side > 0 else PI
			l.visibility_range_end = 30.0
			v.add_child(l)


# --- Le garage Fradin -----------------------------------------------------------------------------

## La maison du garagiste et son atelier : grande porte de bois à moitié ouverte sur l'atelier éclairé,
## bandeau peint, bureau vitré, et devant, la cour bétonnée avec ses deux pompes à essence.
static func garage(v: Node3D, f: RefCounted, spec: Dictionary, cx: float, w: float, front: float, out: float, rot: float) -> float:
	var court := 1.5
	var d := 3.6
	var xf := Transform3D(Basis(Vector3.UP, rot), Vector3(cx, 0, front - out * court))
	var green := Color(0.2, 0.4, 0.32)
	var info: Dictionary = f.house(xf, {"w": w, "d": d, "floors": 2, "front": false, "roof_kind": "gable", "wall": Color(0.93, 0.9, 0.82),
		"shutter": green, "chimney": true, "lit": 0.7, "dormer": false})
	var light := Color(0.97, 0.95, 0.9)
	# La porte d'atelier, en planches, poussée à gauche : à droite, l'atelier allumé.
	var dx := -w / 2.0 + 0.3 + 1.25
	f.batch.box("trim", xf, Vector3(dx, 1.2, 0.03), Vector3(2.7, 0.14, 0.08), light)
	f.batch.box("trim", xf, Vector3(dx - 0.62, 0.6, 0.05), Vector3(1.3, 1.1, 0.04), green)
	for i in 6:
		f.batch.box("trim", xf, Vector3(dx - 1.2 + i * 0.23, 0.6, 0.072), Vector3(0.025, 1.06, 0.01), green.darkened(0.3))
	f.batch.box("trim", xf, Vector3(dx - 0.62, 0.6, 0.075), Vector3(1.2, 0.04, 0.01), green.darkened(0.3))
	f.batch.box("trim", xf, Vector3(dx, 1.16, 0.1), Vector3(2.7, 0.04, 0.04), Color(0.3, 0.3, 0.32))
	f._glass(xf, Vector3(dx + 0.62, 0.6, 0.01), Vector2(1.2, 1.1), 1, true, Color(1.0, 0.9, 0.7))
	# Le bureau : une fenêtre et sa porte vitrée.
	f._window(xf, Vector3(w / 2.0 - 1.1, 0.42, 0), Vector2(0.5, 0.7), green, light, 0.95)
	f._door(xf, w / 2.0 - 0.45, green, light, true)
	# Le bandeau peint entre les deux niveaux.
	f.batch.box("trim", xf, Vector3(0, 1.45, 0.05), Vector3(w - 0.3, 0.2, 0.05), Color(0.96, 0.94, 0.88))
	f.batch.box("trim", xf, Vector3(0, 1.45, 0.045), Vector3(w - 0.2, 0.24, 0.04), Color(0.7, 0.12, 0.1))
	var name_l := _paint(v, f, "GARAGE FRADIN", xf * Transform3D(Basis(), Vector3(-0.35, 1.45, 0.08)), Color(0.7, 0.12, 0.1), 56, w - 1.6)
	name_l.visibility_range_end = 40.0
	_paint(v, f, "Réparations\ntoutes marques", xf * Transform3D(Basis(), Vector3(w / 2.0 - 0.6, 1.45, 0.08)), Color(0.15, 0.2, 0.3), 30, 0.8)
	# La cour : la dalle de béton, l'îlot des pompes, la pile de pneus.
	var concrete := Color(0.62, 0.6, 0.57)
	f.batch.box("trim", xf, Vector3(0, 0.02, court / 2.0), Vector3(w, 0.04, court), concrete)
	f.batch.box("trim", xf, Vector3(1.0, 0.07, court * 0.62), Vector3(1.2, 0.1, 0.36), concrete.lightened(0.2))
	for i in 2:
		var px := 0.7 + i * 0.6
		var body: Color = [Color(0.82, 0.12, 0.12), Color(0.95, 0.95, 0.9)][i]
		f.batch.box("trim", xf, Vector3(px, 0.55, court * 0.62), Vector3(0.3, 0.86, 0.22), body)
		f.batch.box("trim", xf, Vector3(px, 0.2, court * 0.62), Vector3(0.32, 0.2, 0.24), Color(0.2, 0.2, 0.22))
		f._glass(xf, Vector3(px, 0.68, court * 0.62 + 0.112), Vector2(0.2, 0.2), 2, true, Color(1.0, 0.95, 0.8))
		f.batch.cylinder("trim", xf, Vector3(px, 0.98, court * 0.62), 0.11, 0.18, Color(1.0, 0.85, 0.3), 10)
		f._glass(xf, Vector3(px, 1.07, court * 0.62 + 0.11), Vector2(0.18, 0.12), 2, true, Color(1.0, 0.85, 0.4))
		f.batch.box("trim", xf, Vector3(px + 0.17, 0.5, court * 0.62), Vector3(0.03, 0.3, 0.03), Color(0.1, 0.1, 0.1))
	for i in 4:
		f.batch.cylinder("trim", xf, Vector3(-w / 2.0 + 0.35, 0.04 + i * 0.13, 0.35), 0.22, 0.12, Color(0.08, 0.08, 0.09), 10)
	v.main._solid_box(Vector3(1.4, 1.2, 0.4), xf * Vector3(1.0, 0.6, court * 0.62))
	v.main._solid_box(Vector3(w, info.h + 1.0, d), xf * Vector3(0, (info.h + 1.0) / 2.0, -d / 2.0))
	v._lamp(xf * Vector3(dx + 0.62, 1.0, 0.6), 1.6, Color(1.0, 0.92, 0.75), 4.0)
	v._lamp(xf * Vector3(1.0, 1.4, court * 0.62), 1.0, Color(1.0, 0.95, 0.85), 3.0)
	var door: Vector3 = xf * Vector3(dx + 0.62, 0, 0.1)
	if spec.has("id"):
		v.lots[spec.id] = {"pos": Vector3(cx, 0, front), "rot": rot, "w": w, "d": d + court, "door": door}
		v._door_area(spec.id, door, rot)
	# Une voiture qui attend son tour, garée de travers sur le côté.
	var car: Node3D = v._car("van", xf * Vector3(-w / 2.0 + 1.0, 0.04, court * 0.45), rad_to_deg(rot) + 75.0, 1.6)
	v.main._solid(car)
	return d + court


static func _paint(v: Node3D, f: RefCounted, text: String, xf: Transform3D, ink: Color, size: int, width: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = v.main.serif
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = ink
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.transform = xf
	l.visibility_range_end = 30.0
	v.add_child(l)
	f._fit(l, width)
	return l


# --- L'école publique ------------------------------------------------------------------------------

## L'école de la IIIe République : deux niveaux, toit à quatre pans, l'inscription gravée au-dessus
## de la porte, la devise, le drapeau, et à côté la cour, le préau, la marelle et le platane.
static func ecole(v: Node3D, f: RefCounted, spec: Dictionary, cx: float, w: float, front: float, out: float, rot: float) -> float:
	var p := Transform3D(Basis(Vector3.UP, rot), Vector3(cx, 0, front))
	var bw := 5.6
	var bx := -w / 2.0 + bw / 2.0
	var d := 3.6
	var xf := p * Transform3D(Basis(), Vector3(bx, 0, -0.5))
	var info: Dictionary = f.house(xf, {"w": bw, "d": d, "floors": 2, "roof_kind": "hip", "wall": Color(0.97, 0.93, 0.85),
		"shutter": Color(0.58, 0.64, 0.68), "door": "center", "lit": 0.12, "chimney": false})
	var stone := Color(0.99, 0.97, 0.92)
	f.batch.box("trim", xf, Vector3(0, 1.45, 0.03), Vector3(3.6, 0.36, 0.05), stone)
	_paint(v, f, "ÉCOLE PUBLIQUE", xf * Transform3D(Basis(), Vector3(0, 1.5, 0.06)), Color(0.2, 0.2, 0.25), 56, 3.2)
	_paint(v, f, "Liberté · Égalité · Fraternité", xf * Transform3D(Basis(), Vector3(0, 1.35, 0.06)), Color(0.3, 0.3, 0.35), 32, 2.4)
	v.main._solid_box(Vector3(bw, info.h + 1.0, d), xf * Vector3(0, (info.h + 1.0) / 2.0, -d / 2.0))
	# La grille basse devant l'école, sur un muret.
	f.garden_wall(p * Vector3(-w / 2.0, 0, -0.1), p * Vector3(bx - 0.6, 0, -0.1), 0.35, stone)
	f.garden_wall(p * Vector3(bx + 0.6, 0, -0.1), p * Vector3(bw - w / 2.0, 0, -0.1), 0.35, stone)
	_railing(f, p, -w / 2.0, bx - 0.6, -0.1, 0.35, 0.55)
	_railing(f, p, bx + 0.6, bw - w / 2.0, -0.1, 0.35, 0.55)
	# La cour : enrobé, marelle, préau, platane, et le portail.
	var cw := w - bw
	var ccx := w / 2.0 - cw / 2.0
	var depth := 7.0
	f.batch.box("trim", p, Vector3(ccx, 0.02, -depth / 2.0 - 0.2), Vector3(cw, 0.04, depth), Color(0.36, 0.36, 0.38))
	var chalk := Color(0.95, 0.95, 0.92)
	var cells := [[0, 0], [0, 1], [-1, 2], [1, 2], [0, 3], [-1, 4], [1, 4], [0, 5]]
	for c in cells:
		var cc := Vector3(ccx - 0.6 + c[0] * 0.15, 0.045, -1.0 - c[1] * 0.3)
		for e in [[Vector3(0, 0, 0.15), Vector3(0.3, 0.005, 0.02)], [Vector3(0, 0, -0.15), Vector3(0.3, 0.005, 0.02)],
				[Vector3(0.15, 0, 0), Vector3(0.02, 0.005, 0.3)], [Vector3(-0.15, 0, 0), Vector3(0.02, 0.005, 0.3)]]:
			f.batch.box("trim", p, cc + e[0], e[1], chalk)
	f.gate(p * Vector3(ccx, 0, -0.1), rot, 1.6, Color(0.25, 0.3, 0.35))
	f.garden_wall(p * Vector3(bw - w / 2.0, 0, -0.1), p * Vector3(ccx - 1.1, 0, -0.1), 0.9, stone)
	f.garden_wall(p * Vector3(ccx + 1.1, 0, -0.1), p * Vector3(w / 2.0, 0, -0.1), 0.9, stone)
	# On passe devant la porte de l'école ; le reste de la grille est fermé.
	for seg in [[-w / 2.0, bx - 0.6], [bx + 0.6, w / 2.0]]:
		v.main._solid_box(Vector3(seg[1] - seg[0], 1.5, 0.3), p * Vector3((seg[0] + seg[1]) / 2.0, 0.75, -0.1))
	var pz := -depth + 0.6
	for px in [ccx - cw / 2.0 + 0.3, ccx + cw / 2.0 - 0.3]:
		for zz in [pz, pz - 1.3]:
			f.batch.box("trim", p, Vector3(px, 0.6, zz), Vector3(0.12, 1.2, 0.12), Color(0.35, 0.3, 0.28))
	f.batch.quad("roof", p, [Vector3(ccx - cw / 2.0, 1.2, pz + 0.3), Vector3(ccx + cw / 2.0, 1.2, pz + 0.3), Vector3(ccx + cw / 2.0, 1.6, pz - 1.6), Vector3(ccx - cw / 2.0, 1.6, pz - 1.6)],
		Vector3(0, 0.98, 0.2), Color(0.82, 0.46, 0.3), [Vector2(0, 0), Vector2(cw, 0), Vector2(cw, 1.95), Vector2(0, 1.95)])
	v._tree(p * Vector3(ccx + 0.8, 0, -3.0), "tree_detailed_fall", 1.8)
	# Le mât et le drapeau tricolore.
	var mast := p * Vector3(ccx - 1.0, 0, -2.6)
	f.batch.cylinder("trim", Transform3D(Basis(), mast), Vector3.ZERO, 0.035, 3.0, Color(0.85, 0.85, 0.85), 6)
	var flag := Transform3D(Basis(Vector3.UP, rot), mast)
	for i in 3:
		f.batch.box("trim", flag, Vector3(0.12 + i * 0.24, 2.75, 0), Vector3(0.24, 0.45, 0.02), [Color(0.1, 0.2, 0.6), Color(0.97, 0.97, 0.97), Color(0.85, 0.12, 0.15)][i])
	v._lamp(p * Vector3(ccx, 1.6, 0.4), 0.8, Color(1.0, 0.8, 0.5), 3.0)
	if spec.has("id"):
		var door: Vector3 = xf * info.door
		v.lots[spec.id] = {"pos": Vector3(cx, 0, front), "rot": rot, "w": w, "d": d, "door": door}
		v._door_area(spec.id, door, rot)
	return d + 0.5


## Une grille de barreaux sur un muret, de a à b (abscisses locales), à la profondeur z.
static func _railing(f: RefCounted, p: Transform3D, a: float, b: float, z: float, base: float, h: float) -> void:
	var n := int(absf(b - a) / 0.14)
	var iron := Color(0.16, 0.18, 0.2)
	for i in n:
		f.batch.box("trim", p, Vector3(a + (i + 0.5) * (b - a) / n, base + h / 2.0, z), Vector3(0.025, h, 0.025), iron)
	f.batch.box("trim", p, Vector3((a + b) / 2.0, base + h, z), Vector3(absf(b - a), 0.04, 0.04), iron)


# --- Le stade municipal ----------------------------------------------------------------------------

## Le terrain rayé, ses lignes et ses buts, quatre projecteurs, la petite tribune couverte
## de l'U.S. Smarves, la grille sur la route et l'arche d'entrée.
static func stade(v: Node3D, f: RefCounted, spec: Dictionary, cx: float, w: float, front: float, out: float, rot: float) -> float:
	var p := Transform3D(Basis(Vector3.UP, rot), Vector3(cx, 0, front))
	var pw := w - 1.6
	var z0 := -1.2
	var pd := 9.4
	var pc := Vector3(0, 0, z0 - pd / 2.0)
	var stripes := 12
	for i in stripes:
		var c := Color(0.3, 0.55, 0.24) if i % 2 == 0 else Color(0.36, 0.62, 0.28)
		f.batch.box("trim", p, pc + Vector3(-pw / 2.0 + (i + 0.5) * pw / stripes, 0.015, 0), Vector3(pw / stripes, 0.03, pd), c)
	var chalk := Color(0.96, 0.96, 0.94)
	var lw := 0.06
	var lines := [
		[Vector3(0, 0, -pd / 2.0 + 0.3), Vector3(pw - 0.6, 0, lw)], [Vector3(0, 0, pd / 2.0 - 0.3), Vector3(pw - 0.6, 0, lw)],
		[Vector3(-pw / 2.0 + 0.3, 0, 0), Vector3(lw, 0, pd - 0.6)], [Vector3(pw / 2.0 - 0.3, 0, 0), Vector3(lw, 0, pd - 0.6)],
		[Vector3(0, 0, 0), Vector3(lw, 0, pd - 0.6)],
	]
	for s in [-1.0, 1.0]:
		var gx: float = s * (pw / 2.0 - 0.3)
		lines.append([Vector3(gx - s * 1.6, 0, 0), Vector3(lw, 0, 4.2)])
		lines.append([Vector3(gx - s * 0.8, 0, -2.1), Vector3(1.6, 0, lw)])
		lines.append([Vector3(gx - s * 0.8, 0, 2.1), Vector3(1.6, 0, lw)])
	for l in lines:
		f.batch.box("trim", p, pc + l[0] + Vector3(0, 0.035, 0), l[1] + Vector3(0, 0.005, 0), chalk)
	for i in 20:
		var a := TAU * i / 20.0
		var q := pc + Vector3(cos(a), 0.035, sin(a)) * 1.2
		f.batch.box("trim", p * Transform3D(Basis(Vector3.UP, -a), q), Vector3.ZERO, Vector3(lw, 0.005, 0.4), chalk)
	# Les buts, et leurs filets en ficelle claire.
	for s in [-1.0, 1.0]:
		var gx: float = s * (pw / 2.0 - 0.3)
		for zz in [-0.75, 0.75]:
			f.batch.box("trim", p, pc + Vector3(gx, 0.35, zz), Vector3(0.05, 0.7, 0.05), chalk)
		f.batch.box("trim", p, pc + Vector3(gx, 0.7, 0), Vector3(0.05, 0.05, 1.55), chalk)
		f.batch.box_tilted("trim", Transform3D(Basis(Vector3.UP, rot + (PI / 2.0 if s > 0 else -PI / 2.0)), p * (pc + Vector3(gx + s * 0.25, 0.37, 0))), Vector3.ZERO, Vector3(1.5, 0.02, 0.8), deg_to_rad(60.0), Color(0.85, 0.88, 0.9))
	# Les projecteurs aux quatre coins, deux qui éclairent vraiment.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var mp := pc + Vector3(sx * (pw / 2.0 + 0.35), 0, sz * (pd / 2.0 + 0.2))
			f.batch.box("trim", p, mp + Vector3(0, 2.2, 0), Vector3(0.1, 4.4, 0.1), Color(0.55, 0.56, 0.58))
			f.batch.box("trim", p, mp + Vector3(0, 4.5, 0), Vector3(0.6, 0.36, 0.14), Color(0.3, 0.3, 0.32))
			var face := Transform3D(Basis(Vector3.UP, rot + atan2(-sx, -sz)), p * (mp + Vector3(0, 4.5, 0)))
			f._glass(face, Vector3(0, 0, 0.08), Vector2(0.52, 0.3), 2, true, Color(1.0, 1.0, 0.92))
			if sz > 0.0:
				var spot := SpotLight3D.new()
				spot.light_color = Color(1.0, 0.98, 0.9)
				spot.light_energy = 5.0
				spot.spot_range = 16.0
				spot.spot_angle = 48.0
				var at: Vector3 = p * (mp + Vector3(0, 4.4, 0))
				v.add_child(spot)
				spot.global_position = at
				spot.look_at(p * pc, Vector3.UP)
	# La tribune couverte, au fond, face à la route.
	var tz := z0 - pd - 0.2
	var tw := 7.0
	var wood := Color(0.55, 0.36, 0.22)
	for i in 3:
		f.batch.box("trim", p, Vector3(0, 0.15 + i * 0.25, tz - 0.25 - i * 0.35), Vector3(tw, 0.3 + i * 0.5, 0.35), Color(0.75, 0.73, 0.7))
		f.batch.box("trim", p, Vector3(0, 0.33 + i * 0.5, tz - 0.25 - i * 0.35), Vector3(tw - 0.1, 0.06, 0.24), wood)
	f.batch.box("wall", p, Vector3(0, 1.2, tz - 1.35), Vector3(tw, 2.4, 0.15), Color(0.92, 0.88, 0.8))
	for px in [-tw / 2.0 + 0.1, 0.0, tw / 2.0 - 0.1]:
		f.batch.box("trim", p, Vector3(px, 1.3, tz - 0.05), Vector3(0.08, 2.0, 0.08), Color(0.2, 0.3, 0.45))
	f.batch.box_tilted("trim", p, Vector3(0, 2.35, tz - 0.65), Vector3(tw + 0.3, 0.06, 1.6), deg_to_rad(-8.0), Color(0.2, 0.3, 0.45))
	f.batch.box("trim", p, Vector3(0, 2.2, tz + 0.12), Vector3(tw + 0.3, 0.28, 0.05), Color(0.97, 0.95, 0.9))
	_paint(v, f, "U.S. SMARVES · FOOTBALL", p * Transform3D(Basis(), Vector3(0, 2.2, tz + 0.15)), Color(0.15, 0.25, 0.5), 56, tw - 0.6)
	v.main._solid_box(Vector3(tw, 2.4, 1.4), p * Vector3(0, 1.2, tz - 0.7))
	# La grille le long de la route, et l'arche de l'entrée à gauche.
	var gate_x := -w / 2.0 + 1.4
	var stone := Color(0.92, 0.88, 0.78)
	f.garden_wall(p * Vector3(gate_x + 0.8, 0, -0.1), p * Vector3(w / 2.0, 0, -0.1), 0.3, stone)
	_railing(f, p, gate_x + 0.8, w / 2.0, -0.1, 0.3, 0.75)
	f.garden_wall(p * Vector3(-w / 2.0, 0, -0.1), p * Vector3(gate_x - 0.8, 0, -0.1), 0.3, stone)
	_railing(f, p, -w / 2.0, gate_x - 0.8, -0.1, 0.3, 0.75)
	v.main._solid_box(Vector3(w / 2.0 - gate_x - 0.8, 1.5, 0.3), p * Vector3((gate_x + 0.8 + w / 2.0) / 2.0, 0.75, -0.1))
	v.main._solid_box(Vector3(gate_x - 0.8 + w / 2.0, 1.5, 0.3), p * Vector3((gate_x - 0.8 - w / 2.0) / 2.0, 0.75, -0.1))
	for s in [-1.0, 1.0]:
		f.batch.box("wall", p, Vector3(gate_x + s * 0.75, 0.9, -0.1), Vector3(0.24, 1.8, 0.24), stone)
	f.batch.box("trim", p, Vector3(gate_x, 1.85, -0.1), Vector3(1.8, 0.3, 0.1), Color(0.2, 0.3, 0.45))
	_paint(v, f, "STADE MUNICIPAL", p * Transform3D(Basis(), Vector3(gate_x, 1.85, -0.04)), Color(1.0, 0.9, 0.55), 40, 1.6)
	_lamp_post(v, p * Vector3(gate_x + 1.2, 0, 0.35))
	if spec.has("id"):
		var door: Vector3 = p * Vector3(gate_x, 0, -0.1)
		v.lots[spec.id] = {"pos": Vector3(cx, 0, front), "rot": rot, "w": w, "d": pd, "door": door}
		v._door_area(spec.id, door, rot)
	# Un match du samedi soir entre vétérans, et deux supporters en tribune.
	var players := [[Vector3(-3.0, 0, -0.8), Vector3(2.5, 0, 1.5)], [Vector3(3.5, 0, -1.6), Vector3(-1.5, 0, 0.9)],
		[Vector3(-6.5, 0, 0.5), Vector3(-2.0, 0, -2.5)], [Vector3(6.0, 0, 1.4), Vector3(1.0, 0, -1.8)]]
	for i in players.size():
		var a: Vector3 = p * (pc + players[i][0])
		var b: Vector3 = p * (pc + players[i][1])
		v.main._villager("footballeur-%d" % i, a + Vector3(0, 0.06, 0), 0.0, "idle", [a + Vector3(0, 0.06, 0), b + Vector3(0, 0.06, 0)])
	for i in 2:
		v.main._villager("supporter-%d" % i, p * Vector3(-1.5 + i * 2.2, 0.62, tz - 0.6), rad_to_deg(rot), "sit")
	return pd


static func _lamp_post(v: Node3D, at: Vector3) -> void:
	v._place(v.KK + "city/streetlight.gltf", at + Vector3(0, 0.06, 0), 2.2, 0.0)
	v._lamp(at + Vector3(0.45, 2.0, 0), 2.2, Color(1.0, 0.72, 0.4), 6.0)


# --- Les pavillons -----------------------------------------------------------------------------------

## Un pavillon des années 70 : crépi clair, toit à quatre pans en tuiles mécaniques, garage accolé,
## jardinet devant avec son muret, son conifère, et parfois la voiture dans l'allée.
static func pavillon(v: Node3D, f: RefCounted, spec: Dictionary, cx: float, w: float, front: float, back: float, out: float, rot: float) -> float:
	var p := Transform3D(Basis(Vector3.UP, rot), Vector3(cx, 0, front))
	var setback := 1.6
	var hw := w - 1.4
	var hx := -w / 2.0 + hw / 2.0 + 0.1
	var d := 2.8
	var xf := p * Transform3D(Basis(), Vector3(hx, 0, -setback))
	var crepi: Color = f.pick(CREPIS)
	var info: Dictionary = f.house(xf, {"w": hw, "d": d, "floors": 1, "roof_kind": "hip", "wall": crepi, "roof": f.pick(MECA),
		"door": "right", "lit": 0.8, "chimney": true})
	# Le garage accolé, toit plat, porte basculante.
	var gx := hx + hw / 2.0 + 0.6
	f.batch.box("wall", p, Vector3(gx, 0.62, -setback - d / 2.0), Vector3(1.2, 1.24, d), crepi.darkened(0.04))
	f.batch.box("trim", p, Vector3(gx, 1.27, -setback - d / 2.0), Vector3(1.3, 0.08, d + 0.1), Color(0.5, 0.48, 0.45))
	f.batch.box("trim", p, Vector3(gx, 0.5, -setback + 0.015), Vector3(0.95, 0.9, 0.03), Color(0.82, 0.76, 0.62))
	for i in 5:
		f.batch.box("trim", p, Vector3(gx, 0.15 + i * 0.18, -setback + 0.035), Vector3(0.95, 0.02, 0.01), Color(0.65, 0.6, 0.5))
	v.main._solid_box(Vector3(w - 0.2, 2.0, d), p * Vector3(0, 1.0, -setback - d / 2.0))
	# Le jardinet : muret et grille, l'allée, le portillon, la pelouse et le conifère.
	var wall_c := crepi.lightened(0.05)
	f.garden_wall(p * Vector3(-w / 2.0, 0, -0.1), p * Vector3(gx - 0.65, 0, -0.1), 0.35, wall_c)
	_railing(f, p, -w / 2.0, gx - 0.65, -0.1, 0.35, 0.4)
	f.batch.box("trim", p, Vector3(gx, 0.02, -setback / 2.0), Vector3(1.0, 0.04, setback), Color(0.7, 0.68, 0.64))
	v.main._solid_box(Vector3(gx - 0.65 + w / 2.0, 1.2, 0.25), p * Vector3((gx - 0.65 - w / 2.0) / 2.0, 0.6, -0.1))
	v._tree(p * Vector3(-w / 2.0 + 0.5, 0, -0.7), ["tree_cone", "tree_cone_fall", "tree_blocks_fall"][f.rng.randi() % 3], 1.3)
	v._place(v.KN + "plant_bushSmall.glb", p * Vector3(hx + 0.4, 0.0, -0.6), 1.2)
	if f.rng.randf() < 0.55:
		var car: Node3D = v._car(["sedan", "van"][f.rng.randi() % 2], p * Vector3(gx, 0.04, -setback * 0.5), rad_to_deg(rot), 1.35)
		v.main._solid(car)
	v._backyard(f, cx, w, front - out * (setback + d + 0.05), back, out)
	return setback + d
