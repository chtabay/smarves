extends RefCounted
## Les maisons de bourg du Poitou, en jouet : calcaire crème, chaînes d'angle, encadrements de pierre
## claire, tuiles canal ocre, volets peints, vitrines et enseignes. Tout passe par un MeshBatch
## (peu d'appels de dessin) ; les vitres sont posées à part, dans un MultiMesh qu'on allume et éteint.
##
## Repère d'une maison : origine au pied de la façade, au milieu ; +Z regarde la rue ; la maison
## s'étend vers -Z sur sa profondeur.

const BATCH := preload("res://scripts/village/mesh_batch.gd")

const FLOOR_H := 1.3
const BASE_H := 0.12

## Teintes du bourg : pierre, enduits, volets, tuiles. Un peu plus vives que nature : c'est une maquette.
const STONES := [Color(0.95, 0.89, 0.76), Color(0.97, 0.92, 0.82), Color(0.91, 0.83, 0.68), Color(0.95, 0.82, 0.62), Color(0.94, 0.84, 0.76), Color(0.88, 0.84, 0.74)]
const SHUTTERS := [Color(0.38, 0.55, 0.7), Color(0.5, 0.66, 0.52), Color(0.62, 0.16, 0.18), Color(0.8, 0.82, 0.8), Color(0.2, 0.42, 0.34), Color(0.45, 0.6, 0.75), Color(0.85, 0.72, 0.4), Color(0.55, 0.42, 0.62)]
const ROOFS := [Color(0.84, 0.45, 0.27), Color(0.9, 0.55, 0.33), Color(0.76, 0.38, 0.24), Color(0.86, 0.5, 0.36)]

var batch := BATCH.new()
## Les vitres : [Transform3D, Color, type, graine].
var glass: Array = []
## Ce qui doit s'allumer la nuit à côté des vitrines : [position monde, couleur].
var glows: Array = []
var rng := RandomNumberGenerator.new()
var parent: Node3D
var font: Font


func _init(p: Node3D, f: Font, seed_value: int) -> void:
	parent = p
	font = f
	rng.seed = seed_value


func pick(list: Array) -> Variant:
	return list[rng.randi() % list.size()]


# --- La maison ---------------------------------------------------------------------------------

## spec : w, d, floors, wall, shutter, roof (couleurs), roof_kind ("gable" ou "hip"), lit (0..1),
## chimney, door ("left", "center", "right"), shop (Dictionary : name, sub, color, awning, ink), closed,
## front (false : rez-de-chaussée nu, l'appelant y pose sa propre façade).
## Rend la hauteur des murs et la position de la porte (repère local).
func house(xf: Transform3D, spec: Dictionary) -> Dictionary:
	var w: float = spec.get("w", 3.0)
	var d: float = spec.get("d", 3.0)
	var floors: int = spec.get("floors", 2)
	var wall: Color = spec.get("wall", pick(STONES))
	var shutter: Color = spec.get("shutter", pick(SHUTTERS))
	var roof: Color = spec.get("roof", pick(ROOFS))
	var lit: float = spec.get("lit", 0.55)
	var shop: Dictionary = spec.get("shop", {})
	var ground_h := 1.45 if not shop.is_empty() else FLOOR_H
	var h := ground_h + (floors - 1) * FLOOR_H + 0.15
	var light := wall.lightened(0.12)
	var dark := wall.darkened(0.25)

	# Le corps, le soubassement, la corniche.
	batch.box("wall", xf, Vector3(0, h / 2.0, -d / 2.0), Vector3(w, h, d), wall)
	batch.box("trim", xf, Vector3(0, BASE_H / 2.0, -d / 2.0), Vector3(w + 0.05, BASE_H, d + 0.05), dark)
	batch.box("trim", xf, Vector3(0, h + 0.05, -d / 2.0), Vector3(w + 0.14, 0.1, d + 0.14), light)
	if floors > 1:
		# Le bandeau d'étage, en pierre claire.
		batch.box("trim", xf, Vector3(0, ground_h + 0.02, 0.01), Vector3(w, 0.07, 0.04), light)

	# Chaînes d'angle : une pierre longue, une courte, sur les deux coins avant.
	var y := BASE_H
	var k := 0
	while y < h - 0.1:
		var hs := minf(0.24, h - y)
		var long := k % 2 == 0
		for side in [-1.0, 1.0]:
			var lw := 0.26 if long else 0.15
			batch.box("trim", xf, Vector3(side * (w / 2.0 - lw / 2.0 + 0.01), y + hs / 2.0, 0.015), Vector3(lw, hs - 0.025, 0.04), light)
			var ld := 0.15 if long else 0.26
			batch.box("trim", xf, Vector3(side * (w / 2.0 + 0.015), y + hs / 2.0, -ld / 2.0 + 0.01), Vector3(0.04, hs - 0.025, ld), light)
		y += hs
		k += 1

	var roof_kind: String = spec.get("roof_kind", "gable")
	if roof_kind == "pignon":
		# Pignon sur rue : le faîtage perpendiculaire à la rue, le triangle de pierre en façade.
		var rxf := xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0, 0, -d / 2.0)) * Transform3D(Basis(), Vector3(0, 0, w / 2.0))
		_roof(rxf, d, w, h, roof, wall, "gable")
		# Un oculus dans le pignon, éclairé.
		_glass(xf, Vector3(0, h + 0.1 + w * 0.5 * tan(deg_to_rad(28.0)) * 0.45, 0.012), Vector2(0.3, 0.3), 0, rng.randf() < lit, Color(1.0, 0.78, 0.45))
		batch.box("trim", xf, Vector3(0, h + 0.1 + w * 0.5 * tan(deg_to_rad(28.0)) * 0.45, 0.01), Vector3(0.42, 0.42, 0.02), light)
	else:
		_roof(xf, w, d, h, roof, wall, roof_kind)
		if roof_kind == "gable" and floors >= 2 and spec.get("dormer", rng.randf() < 0.45):
			_dormer(xf, rng.randf_range(-w * 0.2, w * 0.2), h, d, roof, light, lit)
	if spec.get("chimney", rng.randf() < 0.6):
		var cx := (w / 2.0 - 0.45) * (1.0 if rng.randf() < 0.5 else -1.0)
		var top := h + d * 0.5 * tan(deg_to_rad(28.0)) + 0.35
		batch.box("wall", xf, Vector3(cx, top - 0.45, -d * 0.45), Vector3(0.34, 0.9, 0.3), wall.darkened(0.05))
		batch.box("trim", xf, Vector3(cx, top + 0.02, -d * 0.45), Vector3(0.42, 0.07, 0.38), light)
		batch.box("trim", xf, Vector3(cx, top + 0.1, -d * 0.45), Vector3(0.14, 0.12, 0.14), roof.darkened(0.2))

	# Où sont la porte et les fenêtres : des travées régulières, à la poitevine.
	var bays := maxi(1, int((w - 0.3) / 0.9))
	var bay_w := (w - 0.2) / bays
	var door_bay := 0
	match spec.get("door", "left"):
		"center":
			door_bay = bays / 2
		"right":
			door_bay = bays - 1
	var door_x := -w / 2.0 + 0.1 + bay_w * (door_bay + 0.5)
	var closed: bool = spec.get("closed", false)

	if not spec.get("front", true):
		pass  # La façade est dessinée par l'appelant (garage, école).
	elif shop.is_empty():
		for i in bays:
			var x := -w / 2.0 + 0.1 + bay_w * (i + 0.5)
			if i == door_bay:
				_door(xf, x, shutter, light, rng.randf() < lit)
				if spec.has("plaque"):
					_plaque(xf, Vector3(x - 0.46, 0.75, 0.0), spec.plaque)
			else:
				_window(xf, Vector3(x, 0.42, 0), Vector2(0.48, 0.7), shutter, light, lit, closed)
	else:
		door_x = _shopfront(xf, w, ground_h, shop, light, closed)
	for f in range(1, floors):
		for i in bays:
			var x := -w / 2.0 + 0.1 + bay_w * (i + 0.5)
			_window(xf, Vector3(x, ground_h + (f - 1) * FLOOR_H + 0.32, 0), Vector2(0.48, 0.74), shutter, light, lit, closed)
	if spec.get("back", true):
		# L'arrière, sur le jardin : on le voit depuis la maquette, il a aussi ses fenêtres et sa porte.
		var bxf := xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -d))
		var back_door := rng.randi() % bays
		for f in floors:
			for i in bays:
				var x := -w / 2.0 + 0.1 + bay_w * (i + 0.5)
				if f == 0 and i == back_door:
					_door(bxf, x, shutter, light, rng.randf() < lit * 0.6)
				elif rng.randf() < 0.75:
					_window(bxf, Vector3(x, 0.42 if f == 0 else ground_h + (f - 1) * FLOOR_H + 0.32, 0), Vector2(0.44, 0.66), shutter, light, lit * 0.8, closed)
	return {"h": h, "door": Vector3(door_x, 0, 0), "w": w, "d": d}


func _roof(xf: Transform3D, w: float, d: float, h: float, roof: Color, wall: Color, kind: String) -> void:
	var ov := 0.16
	var pitch := deg_to_rad(28.0)
	var eave := h + 0.1
	var rise := (d / 2.0 + ov) * tan(pitch)
	var x0 := -w / 2.0 - ov
	var x1 := w / 2.0 + ov
	var zf := ov
	var zb := -d - ov
	var zr := -d / 2.0
	var top := eave + rise
	var slope := sqrt(pow(d / 2.0 + ov, 2) + rise * rise)
	var nf := Vector3(0, cos(pitch), sin(pitch))
	var nb := Vector3(0, cos(pitch), -sin(pitch))
	if kind == "hip":
		var inset := minf(d / 2.0 + ov, (x1 - x0) / 2.0)
		var r0 := Vector3(x0 + inset, top, zr)
		var r1 := Vector3(x1 - inset, top, zr)
		var lf := x1 - x0
		batch.quad("roof", xf, [Vector3(x0, eave, zf), Vector3(x1, eave, zf), r1, r0], nf, roof,
			[Vector2(0, 0), Vector2(lf, 0), Vector2(lf - inset, slope), Vector2(inset, slope)])
		batch.quad("roof", xf, [Vector3(x1, eave, zb), Vector3(x0, eave, zb), r0, r1], nb, roof,
			[Vector2(0, 0), Vector2(lf, 0), Vector2(lf - inset, slope), Vector2(inset, slope)])
		var span := zf - zb
		batch.tri("roof", xf, Vector3(x0, eave, zb), Vector3(x0, eave, zf), r0, Vector3(-cos(pitch), sin(pitch), 0), roof,
			[Vector2(0, 0), Vector2(span, 0), Vector2(span / 2.0, slope)])
		batch.tri("roof", xf, Vector3(x1, eave, zf), Vector3(x1, eave, zb), r1, Vector3(cos(pitch), sin(pitch), 0), roof,
			[Vector2(0, 0), Vector2(span, 0), Vector2(span / 2.0, slope)])
		batch.box("trim", xf, Vector3((r0.x + r1.x) / 2.0, top + 0.03, zr), Vector3(maxf(0.1, r1.x - r0.x) + 0.1, 0.08, 0.12), roof.darkened(0.15))
	else:
		batch.quad("roof", xf, [Vector3(x0, eave, zf), Vector3(x1, eave, zf), Vector3(x1, top, zr), Vector3(x0, top, zr)], nf, roof,
			[Vector2(0, 0), Vector2(x1 - x0, 0), Vector2(x1 - x0, slope), Vector2(0, slope)])
		batch.quad("roof", xf, [Vector3(x1, eave, zb), Vector3(x0, eave, zb), Vector3(x0, top, zr), Vector3(x1, top, zr)], nb, roof,
			[Vector2(0, 0), Vector2(x1 - x0, 0), Vector2(x1 - x0, slope), Vector2(0, slope)])
		# Les pignons, en pierre, et le faîtage.
		var g_rise := (d / 2.0) * tan(pitch)
		for side in [-1.0, 1.0]:
			var x: float = side * w / 2.0
			batch.tri("wall", xf, Vector3(x, h + 0.1, 0), Vector3(x, h + 0.1, -d), Vector3(x, h + 0.1 + g_rise, zr), Vector3(side, 0, 0), wall)
		batch.box("trim", xf, Vector3(0, top + 0.03, zr), Vector3(x1 - x0 + 0.04, 0.08, 0.12), roof.darkened(0.15))
	# La planche d'égout, qui donne de l'épaisseur au toit vu de la rue.
	batch.box("trim", xf, Vector3(0, eave - 0.03, zf - 0.02), Vector3(x1 - x0, 0.07, 0.05), roof.darkened(0.35))


## Une lucarne à fronton sur le pan avant du toit.
func _dormer(xf: Transform3D, x: float, h: float, d: float, roof: Color, light: Color, lit: float) -> void:
	var pitch := deg_to_rad(28.0)
	var z := -0.45
	var base := h + 0.1 + (0.16 + 0.45) * tan(pitch) - 0.16 * tan(pitch)
	batch.box("wall", xf, Vector3(x, base + 0.28, z), Vector3(0.62, 0.56, 0.5), light)
	var rxf := xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x, base + 0.56, z - 0.05))
	batch.quad("roof", rxf, [Vector3(-0.32, 0, -0.38), Vector3(-0.32, 0, 0.38), Vector3(0, 0.2, 0.38), Vector3(0, 0.2, -0.38)], Vector3(-0.53, 0.85, 0), roof,
		[Vector2(0, 0), Vector2(0.76, 0), Vector2(0.76, 0.38), Vector2(0, 0.38)])
	batch.quad("roof", rxf, [Vector3(0.32, 0, 0.38), Vector3(0.32, 0, -0.38), Vector3(0, 0.2, -0.38), Vector3(0, 0.2, 0.38)], Vector3(0.53, 0.85, 0), roof,
		[Vector2(0, 0), Vector2(0.76, 0), Vector2(0.76, 0.38), Vector2(0, 0.38)])
	batch.tri("wall", xf, Vector3(x - 0.31, base + 0.56, z + 0.251), Vector3(x + 0.31, base + 0.56, z + 0.251), Vector3(x, base + 0.76, z + 0.251), Vector3(0, 0, 1), light)
	_glass(xf, Vector3(x, base + 0.3, z + 0.255), Vector2(0.34, 0.4), 0, rng.randf() < lit, Color(1.0, 0.75, 0.42))


func _window(xf: Transform3D, at: Vector3, size: Vector2, shutter: Color, light: Color, lit: float, closed := false) -> void:
	var c := at + Vector3(0, size.y / 2.0, 0)
	# L'encadrement de pierre claire : appui saillant, linteau, jambages.
	batch.box("trim", xf, c + Vector3(0, -size.y / 2.0 - 0.03, 0.04), Vector3(size.x + 0.14, 0.06, 0.1), light)
	batch.box("trim", xf, c + Vector3(0, size.y / 2.0 + 0.05, 0.02), Vector3(size.x + 0.16, 0.1, 0.05), light)
	for s in [-1.0, 1.0]:
		batch.box("trim", xf, c + Vector3(s * (size.x / 2.0 + 0.035), 0, 0.02), Vector3(0.07, size.y, 0.05), light)
	if closed or rng.randf() < 0.18:
		# Volets fermés, à barres et écharpe.
		batch.box("trim", xf, c + Vector3(0, 0, 0.012), Vector3(size.x, size.y, 0.03), shutter)
		for yy in [-0.3, 0.0, 0.3]:
			batch.box("trim", xf, c + Vector3(0, yy * size.y, 0.03), Vector3(size.x * 0.96, 0.03, 0.01), shutter.darkened(0.2))
		return
	# Volets ouverts, rabattus contre le mur.
	for s in [-1.0, 1.0]:
		batch.box("trim", xf, c + Vector3(s * (size.x * 0.75 + 0.08), 0, 0.02), Vector3(size.x / 2.0, size.y, 0.025), shutter)
		for yy in [-0.3, 0.3]:
			batch.box("trim", xf, c + Vector3(s * (size.x * 0.75 + 0.08), yy * size.y, 0.035), Vector3(size.x / 2.0 - 0.02, 0.025, 0.01), shutter.darkened(0.2))
	var on := rng.randf() < lit
	_glass(xf, c + Vector3(0, 0, 0.006), size, 0, on, Color(1.0, 0.72, 0.38).lerp(Color(1.0, 0.85, 0.6), rng.randf()))
	# Parfois, une jardinière de géraniums sous la fenêtre.
	if rng.randf() < 0.3:
		batch.box("trim", xf, c + Vector3(0, -size.y / 2.0 - 0.12, 0.12), Vector3(size.x * 0.9, 0.12, 0.12), Color(0.55, 0.32, 0.2))
		for i in 4:
			batch.box("trim", xf, c + Vector3((i - 1.5) * size.x * 0.22, -size.y / 2.0 - 0.03, 0.12), Vector3(0.09, 0.08, 0.09), [Color(0.95, 0.2, 0.25), Color(0.98, 0.45, 0.55), Color(0.3, 0.55, 0.25)][i % 3])


func _door(xf: Transform3D, x: float, color: Color, light: Color, on: bool) -> void:
	var dw := 0.52
	var dh := 0.98
	batch.box("trim", xf, Vector3(x, BASE_H + dh / 2.0, 0.005), Vector3(dw, dh, 0.03), color.darkened(0.1))
	for yy in [0.3, 0.65]:
		batch.box("trim", xf, Vector3(x, BASE_H + dh * yy, 0.025), Vector3(dw * 0.8, dh * 0.25, 0.01), color)
	batch.box("trim", xf, Vector3(x, BASE_H + dh + 0.07, 0.025), Vector3(dw + 0.18, 0.14, 0.06), light)
	for s in [-1.0, 1.0]:
		batch.box("trim", xf, Vector3(x + s * (dw / 2.0 + 0.04), BASE_H + dh / 2.0, 0.02), Vector3(0.08, dh, 0.05), light)
	# Le seuil de pierre, et l'imposte qui laisse voir la lumière du couloir.
	batch.box("trim", xf, Vector3(x, 0.04, 0.12), Vector3(dw + 0.2, 0.08, 0.24), light.darkened(0.08))
	_glass(xf, Vector3(x, BASE_H + dh - 0.1, 0.03), Vector2(dw * 0.7, 0.12), 2, on, Color(1.0, 0.75, 0.4))
	batch.box("trim", xf, Vector3(x + dw * 0.3, BASE_H + dh * 0.5, 0.04), Vector3(0.04, 0.04, 0.03), Color(0.95, 0.75, 0.3))


## La devanture : vitrine éclairée, porte vitrée, bandeau peint avec le nom, store rayé.
func _shopfront(xf: Transform3D, w: float, gh: float, shop: Dictionary, light: Color, closed: bool) -> float:
	var col: Color = shop.get("color", Color(0.3, 0.2, 0.15))
	var dw := 0.55
	var door_x := w / 2.0 - 0.25 - dw / 2.0 if shop.get("door", "right") == "right" else -w / 2.0 + 0.25 + dw / 2.0
	var vw := w - 0.5 - dw - 0.15
	var vx := -w / 2.0 + 0.25 + vw / 2.0 if door_x > 0.0 else w / 2.0 - 0.25 - vw / 2.0
	# La devanture de bois peint, en applique sur la pierre.
	batch.box("trim", xf, Vector3(0, gh / 2.0 + 0.05, 0.04), Vector3(w - 0.3, gh - 0.1, 0.06), col)
	batch.box("trim", xf, Vector3(0, gh - 0.17, 0.09), Vector3(w - 0.2, 0.32, 0.06), col.darkened(0.15))
	batch.box("trim", xf, Vector3(0, gh + 0.0, 0.11), Vector3(w - 0.14, 0.05, 0.1), light)
	batch.box("trim", xf, Vector3(vx, 0.3, 0.1), Vector3(vw + 0.06, 0.06, 0.1), light)
	var glow_col: Color = shop.get("glow", Color(1.0, 0.82, 0.55))
	_glass(xf, Vector3(vx, 0.35 + 0.42, 0.075), Vector2(vw, 0.78), 1, not closed, glow_col)
	_glass(xf, Vector3(door_x, BASE_H + 0.55, 0.075), Vector2(dw, 1.0), 2, not closed, glow_col)
	if shop.get("mannequin", false):
		# Un mannequin de couturière en silhouette dans la vitrine, et un rouleau de tissu.
		for mx in [vx - vw * 0.22, vx + vw * 0.22]:
			batch.box("trim", xf, Vector3(mx, 0.45, 0.085), Vector3(0.04, 0.3, 0.01), Color(0.12, 0.08, 0.1))
			batch.box("trim", xf, Vector3(mx, 0.78, 0.085), Vector3(0.22, 0.36, 0.01), Color(0.25, 0.1, 0.18))
			batch.box("trim", xf, Vector3(mx, 0.99, 0.085), Vector3(0.1, 0.07, 0.01), Color(0.12, 0.08, 0.1))
		batch.box("trim", xf, Vector3(vx, 0.5, 0.085), Vector3(0.1, 0.32, 0.01), Color(0.75, 0.2, 0.25))
	if closed:
		# Vitrine passée au blanc d'Espagne, en attendant le repreneur.
		batch.box("trim", xf, Vector3(vx, 0.77, 0.08), Vector3(vw, 0.78, 0.01), Color(0.92, 0.9, 0.84))
	var name_l := Label3D.new()
	name_l.text = shop.get("name", "")
	name_l.font = font
	name_l.font_size = 56
	name_l.pixel_size = 0.004
	name_l.modulate = shop.get("ink", Color(1.0, 0.9, 0.6))
	name_l.outline_size = 0
	name_l.shaded = true
	name_l.double_sided = false
	name_l.width = (w - 0.3) / name_l.pixel_size
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.transform = xf * Transform3D(Basis(), Vector3(0, gh - 0.17, 0.125))
	name_l.visibility_range_end = 40.0
	parent.add_child(name_l)
	_fit(name_l, w - 0.4)
	if shop.has("sub"):
		var sub := Label3D.new()
		sub.text = shop.sub
		sub.font = font
		sub.font_size = 40
		sub.pixel_size = 0.0035
		sub.modulate = shop.get("ink", Color(1.0, 0.9, 0.6)).darkened(0.1)
		sub.shaded = true
		sub.double_sided = false
		if shop.has("awning"):
			# Sur le lambrequin du store, en lettres peintes.
			var tilt := deg_to_rad(24.0)
			sub.transform = xf * Transform3D(Basis(), Vector3(vx, gh - 0.38 - sin(tilt) * 0.62 - 0.06, 0.12 + cos(tilt) * 0.62 + 0.012))
			sub.modulate = Color(0.12, 0.1, 0.1)
		else:
			sub.transform = xf * Transform3D(Basis(), Vector3(vx, 1.08, 0.085))
		sub.visibility_range_end = 30.0
		parent.add_child(sub)
		_fit(sub, vw - 0.1)
		if shop.has("awning"):
			sub.pixel_size = minf(sub.pixel_size, 0.1 / sub.font_size)
	if shop.has("awning"):
		_awning(xf, Vector3(vx, gh - 0.38, 0.12), vw + 0.2, shop.awning)
	if not closed:
		glows.append([xf * Vector3(vx, 0.9, 0.7), glow_col])
	return door_x


## La plaque de cuivre à côté de la porte, gravée en noir.
func _plaque(xf: Transform3D, at: Vector3, text: String) -> void:
	batch.box("trim", xf, at + Vector3(0, 0, 0.012), Vector3(0.36, 0.26, 0.02), Color(0.95, 0.68, 0.3))
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 40
	l.pixel_size = 0.0022
	l.modulate = Color(0.15, 0.1, 0.05)
	l.shaded = true
	l.double_sided = false
	l.transform = xf * Transform3D(Basis(), at + Vector3(0, 0, 0.024))
	l.visibility_range_end = 25.0
	parent.add_child(l)
	_fit(l, 0.32)
	glows.append([xf * (at + Vector3(0, 0.3, 0.4)), Color(1.0, 0.8, 0.5)])


## Réduit une étiquette pour qu'elle tienne dans la largeur voulue.
func _fit(l: Label3D, width: float) -> void:
	var longest := ""
	for line in l.text.split("\n"):
		if line.length() > longest.length():
			longest = line
	# La police système n'est pas la même partout : on prend la plus large des deux estimations.
	var size := font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size)
	var real := maxf(size.x, longest.length() * l.font_size * 0.78) * l.pixel_size
	if real > width:
		l.pixel_size *= width / real


## Un store banne à rayures, déroulé au-dessus de la vitrine.
func _awning(xf: Transform3D, at: Vector3, width: float, colors: Array) -> void:
	var depth := 0.62
	var stripes := maxi(4, int(width / 0.16))
	var sw := width / stripes
	var tilt := deg_to_rad(-24.0)
	for i in stripes:
		var x := at.x - width / 2.0 + sw * (i + 0.5)
		batch.box_tilted("trim", xf, Vector3(x, at.y - sin(-tilt) * depth / 2.0, at.z + cos(tilt) * depth / 2.0), Vector3(sw, 0.025, depth), tilt, colors[i % colors.size()])
		# Le lambrequin festonné au bout du store.
		batch.box("trim", xf, Vector3(x, at.y - sin(-tilt) * depth - 0.06, at.z + cos(tilt) * depth), Vector3(sw * 0.9, 0.12, 0.02), colors[i % colors.size()])


func _glass(xf: Transform3D, center: Vector3, size: Vector2, kind: int, on: bool, color: Color) -> void:
	var t := xf * Transform3D(Basis().scaled(Vector3(size.x, size.y, 1.0)), center)
	glass.append([t, Color(color.r, color.g, color.b, 1.0 if on else 0.0), kind, rng.randf() * 100.0])


# --- Murs de jardin, portails ------------------------------------------------------------------

## Un mur de pierre sèche à chaperon de tuiles, de a à b (au sol).
func garden_wall(a: Vector3, b: Vector3, h := 0.7, color := Color(0.93, 0.87, 0.74)) -> void:
	var dir := b - a
	var len := dir.length()
	var xf := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z) - PI / 2.0), (a + b) / 2.0)
	batch.box("wall", xf, Vector3(0, h / 2.0, 0), Vector3(len, h, 0.16), color)
	batch.box("trim", xf, Vector3(0, h + 0.03, 0), Vector3(len + 0.04, 0.06, 0.22), Color(0.86, 0.5, 0.32))


## Deux piliers à boule et un portail de bois peint, centrés en at, tournés de rot.
func gate(at: Vector3, rot: float, width: float, color: Color) -> void:
	var xf := Transform3D(Basis(Vector3.UP, rot), at)
	for s in [-1.0, 1.0]:
		batch.box("wall", xf, Vector3(s * (width / 2.0 + 0.15), 0.5, 0), Vector3(0.3, 1.0, 0.3), Color(0.92, 0.86, 0.74))
		batch.box("trim", xf, Vector3(s * (width / 2.0 + 0.15), 1.04, 0), Vector3(0.36, 0.08, 0.36), Color(0.97, 0.93, 0.84))
		batch.cylinder("trim", xf, Vector3(s * (width / 2.0 + 0.15), 1.08, 0), 0.1, 0.16, Color(0.97, 0.93, 0.84))
	for i in 7:
		var x := -width / 2.0 + width * (i + 0.5) / 7.0
		var hh := 0.75 + 0.12 * sin(PI * (i + 0.5) / 7.0)
		batch.box("trim", xf, Vector3(x, hh / 2.0 + 0.05, 0), Vector3(width / 7.0 - 0.03, hh, 0.04), color)
	batch.box("trim", xf, Vector3(0, 0.3, 0.02), Vector3(width, 0.05, 0.03), color.darkened(0.2))
	batch.box("trim", xf, Vector3(0, 0.7, 0.02), Vector3(width, 0.05, 0.03), color.darkened(0.2))


# --- Pose ----------------------------------------------------------------------------------------

func commit(materials: Dictionary, glass_material: Material, label: String) -> MultiMesh:
	batch.commit(parent, materials, label)
	if glass.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = glass.size()
	for i in glass.size():
		var g: Array = glass[i]
		mm.set_instance_transform(i, g[0])
		mm.set_instance_color(i, g[1])
		mm.set_instance_custom_data(i, Color(g[2], g[3], 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "%s_vitres" % label
	mmi.multimesh = mm
	mmi.material_override = glass_material
	parent.add_child(mmi)
	glass.clear()
	return mm
