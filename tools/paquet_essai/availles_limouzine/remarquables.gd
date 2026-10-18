extends RefCounted
## Les bâtiments remarquables d'Availles-Limouzine dessinés d'après photo, avec les pièces des maisons
## de Smarves (scripts/village/facades.gd) : la même pierre, les mêmes volets, mais la silhouette,
## les percements et les couleurs de la vraie façade. Chaque bâtiment se pose sur son emprise réelle,
## la façade sur le mur qui regarde la rue d'où on le photographie.
##
## construire(id, f, b) dessine le lieu `id` dans le lot de façades `f` et rend true ; false si ce
## lieu n'a pas encore sa silhouette (availles.gd le dessine alors comme une maison du bourg).

const FLOOR_H := 1.3
const BASE_H := 0.12


static func construire(id: String, f, b: Dictionary, hauteur: Callable) -> bool:
	match id:
		"hotel":
			_chatellenie(f, b, hauteur)
			return true
		"adrien_bernard":
			_adrien_bernard(f, b, hauteur)
			return true
	return false


# --- L'hôtel-restaurant de la Châtellenie, 1 rue du Commerce ---------------------------------------
## D'après photo : une grande façade d'enduit ocre où la pierre affleure, deux niveaux et un comble,
## cinq travées ; à l'étage des volets vert sombre, sous la génoise trois petites fenêtres de comble ;
## au rez-de-chaussée la porte de pierre au milieu, deux vitrines de chaque côté, le bandeau peint
## « Bistrot · La Châtellenie Hôtel · Restaurant » ; devant, la terrasse à garde-corps blanc et ses
## buis en pot. La façade regarde le carrefour de la rue du Commerce et de la rue Principale.
static func _chatellenie(f, b: Dictionary, hauteur: Callable) -> void:
	var fa := _facade(b, Vector2(-7.2, 12.2), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = maxf(fa.w, 5.0)
	var d: float = clampf(fa.d, 3.5, 5.5)
	var mur := Color(0.84, 0.74, 0.58)
	var clair := Color(0.93, 0.88, 0.78)
	var volet := Color(0.1, 0.36, 0.34)
	var tuile := Color(0.82, 0.5, 0.32)
	var gh := 1.45
	var h := gh + FLOOR_H + 0.85
	# Le corps, le soubassement, les cordons d'étage, les chaînes d'angle.
	_socle(f, xf, w, d, fa.socle, mur.darkened(0.3))
	f.batch.box("wall", xf, Vector3(0, h / 2.0, -d / 2.0), Vector3(w, h, d), mur)
	f.batch.box("trim", xf, Vector3(0, BASE_H / 2.0, -d / 2.0), Vector3(w + 0.05, BASE_H, d + 0.05), mur.darkened(0.3))
	f.batch.box("trim", xf, Vector3(0, gh + 0.02, 0.01), Vector3(w, 0.07, 0.04), clair)
	f.batch.box("trim", xf, Vector3(0, gh + FLOOR_H + 0.02, 0.01), Vector3(w, 0.07, 0.04), clair)
	_chaines(f, xf, w, h, clair)
	# La génoise : trois rangs de tuiles qui débordent sous l'égout.
	for r in 3:
		f.batch.box("trim", xf, Vector3(0, h - 0.16 + 0.07 * r, 0.03 + 0.045 * r), Vector3(w + 0.1 + 0.08 * r, 0.06, 0.1), tuile.darkened(0.1 * (2 - r)))
	f._roof(xf, w, d, h, tuile, mur, "hip")
	for s in [-1.0, 1.0]:
		var top := h + d * 0.5 * tan(deg_to_rad(28.0)) + 0.3
		f.batch.box("wall", xf, Vector3(s * (w / 2.0 - 0.6), top - 0.45, -d * 0.4), Vector3(0.36, 0.9, 0.32), mur.darkened(0.05))
		f.batch.box("trim", xf, Vector3(s * (w / 2.0 - 0.6), top + 0.02, -d * 0.4), Vector3(0.44, 0.07, 0.4), clair)
	# Cinq travées. En haut, les volets des deux travées de droite sont fermés, comme sur la photo.
	var bays := 5
	var bay_w := (w - 0.2) / bays
	for i in bays:
		var x := -w / 2.0 + 0.1 + bay_w * (i + 0.5)
		f._window(xf, Vector3(x, gh + 0.3, 0), Vector2(0.5, 0.78), volet, clair, 0.25, i >= 3)
		if i % 2 == 0:
			# Une petite fenêtre de comble, à l'encadrement de pierre.
			f.batch.box("trim", xf, Vector3(x, gh + FLOOR_H + 0.42, 0.0), Vector3(0.44, 0.46, 0.03), clair)
			f._glass(xf, Vector3(x, gh + FLOOR_H + 0.42, 0.02), Vector2(0.3, 0.34), 0, f.rng.randf() < 0.3, Color(1.0, 0.8, 0.5))
		if i == 2:
			# La porte de pierre, en plein cintre, qui donne sur le couloir de l'hôtel.
			f.batch.box("trim", xf, Vector3(x, BASE_H + 0.62, 0.0), Vector3(0.92, 1.24, 0.05), clair)
			f.batch.box("trim", xf, Vector3(x, BASE_H + 0.5, 0.03), Vector3(0.6, 1.0, 0.03), Color(0.3, 0.22, 0.16))
			f._glass(xf, Vector3(x, BASE_H + 0.55, 0.05), Vector2(0.5, 0.9), 2, true, Color(1.0, 0.82, 0.55))
		else:
			# Une vitrine à cadre blanc, éclairée.
			f.batch.box("trim", xf, Vector3(x, BASE_H + 0.62, 0.0), Vector3(bay_w * 0.82 + 0.1, 1.1, 0.03), Color(0.93, 0.93, 0.9))
			f._glass(xf, Vector3(x, BASE_H + 0.62, 0.02), Vector2(bay_w * 0.82, 1.0), 1, true, Color(1.0, 0.85, 0.6))
	# Le bandeau peint, et les trois mots de l'enseigne.
	f.batch.box("trim", xf, Vector3(0, gh - 0.2, 0.05), Vector3(w - 0.1, 0.3, 0.05), Color(0.88, 0.8, 0.64))
	var encre := Color(0.2, 0.17, 0.14)
	_lettres(f, xf, Vector3(0, gh - 0.17, 0.08), "La Châtellenie", 48, 0.0038, encre, bay_w * 1.6)
	_lettres(f, xf, Vector3(0, gh - 0.3, 0.08), "Hôtel ***", 30, 0.002, encre, bay_w)
	_lettres(f, xf, Vector3(-bay_w * 1.5, gh - 0.2, 0.08), "Bistrot", 40, 0.0032, encre, bay_w * 1.4)
	_lettres(f, xf, Vector3(bay_w * 1.5, gh - 0.2, 0.08), "Restaurant", 40, 0.0032, encre, bay_w * 1.6)
	f.glows.append([xf * Vector3(0, 0.9, 0.8), Color(1.0, 0.82, 0.55)])
	# La terrasse : le perron de pierre, le garde-corps blanc, les buis en pot.
	var pierre := Color(0.8, 0.7, 0.55)
	var blanc := Color(0.95, 0.95, 0.93)
	var tw := w - 0.5
	f.batch.box("trim", xf, Vector3(0, 0.1, 0.65), Vector3(tw, 0.2, 1.3), pierre)
	var n := int(tw / 0.45)
	for i in n + 1:
		var x := -tw / 2.0 + tw * i / n
		f.batch.box("trim", xf, Vector3(x, 0.44, 1.28), Vector3(0.03, 0.48, 0.03), blanc)
	f.batch.box("trim", xf, Vector3(0, 0.68, 1.28), Vector3(tw, 0.03, 0.03), blanc)
	f.batch.box("trim", xf, Vector3(0, 0.46, 1.28), Vector3(tw, 0.02, 0.02), blanc)
	for s in [-1.0, 1.0]:
		for i in 3:
			f.batch.box("trim", xf, Vector3(s * tw / 2.0, 0.44, 0.65 + 0.63 * (i - 1)), Vector3(0.03, 0.48, 0.03), blanc)
		f.batch.box("trim", xf, Vector3(s * tw / 2.0, 0.68, 0.65), Vector3(0.03, 0.03, 1.3), blanc)
	for x in [-bay_w * 0.55, bay_w * 0.55, bay_w * 1.7]:
		f.batch.box("trim", xf, Vector3(x, 0.32, 1.0), Vector3(0.22, 0.24, 0.22), Color(0.45, 0.45, 0.47))
		f.batch.box("trim", xf, Vector3(x, 0.58, 1.0), Vector3(0.3, 0.3, 0.3), Color(0.25, 0.45, 0.22))
	f.batch.box("trim", xf, Vector3(-bay_w * 1.7, 0.3, 1.0), Vector3(0.3, 0.2, 0.3), pierre.darkened(0.1))
	for i in 4:
		f.batch.box("trim", xf, Vector3(-bay_w * 1.7 + (i - 1.5) * 0.07, 0.44, 1.0 + (i % 2) * 0.06), Vector3(0.07, 0.07, 0.07), [Color(0.95, 0.2, 0.25), Color(0.98, 0.5, 0.2), Color(0.95, 0.85, 0.3), Color(0.3, 0.55, 0.25)][i])


# --- Le 10 place Adrien-Bernard --------------------------------------------------------------------
## D'après la vue de la rue : une maison bourgeoise à l'enduit crème et aux chaînes d'angle de pierre
## blanche, deux niveaux sous un haut toit d'ardoise à pignon sur rue, deux fenêtres de comble, la
## cheminée qui monte au nord ; à côté, au nord, une dépendance basse au pignon d'ardoise ;
## puis la palissade blanche, le pilier de pierre et le mur bas du jardin, et le lampadaire du trottoir.
## La façade regarde la place, à l'ouest.
static func _adrien_bernard(f, b: Dictionary, hauteur: Callable) -> void:
	var fa := _facade(b, Vector2(-20.0, -25.7), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = fa.w
	# De quel côté du repère de la façade est le nord (z plus petit) ? La dépendance, la palissade et
	# le jardin sont au nord ; la maison voisine est accolée au sud.
	var nord: float = (1.0 if fa.a.y < fa.c.y else -1.0) * fa.sens
	var cote := nord
	var creme := Color(0.93, 0.88, 0.78)
	var blanc := Color(0.95, 0.95, 0.93)
	var ardoise := Color(0.36, 0.39, 0.45)
	var wm := minf(3.1, w * 0.62)
	var wa := w - wm
	# Le corps de logis, accolé à la maison voisine.
	var xm := -cote * (w / 2.0 - wm / 2.0)
	var mxf := xf * Transform3D(Basis(), Vector3(xm, 0, 0))
	_socle(f, mxf, wm, 3.6, fa.socle, creme.darkened(0.3))
	var logis: Dictionary = f.house(mxf, {
		"w": wm, "d": 3.6, "floors": 2, "wall": creme, "shutter": blanc, "roof": ardoise, "roof_kind": "pignon",
		"lit": 0.2, "chimney": false, "door": "left" if cote > 0.0 else "right", "back": false,
	})
	var hm: float = logis.h
	# Les deux fenêtres de comble dans le pignon, et la haute cheminée du côté du jardin.
	for s in [-1.0, 1.0]:
		f.batch.box("trim", mxf, Vector3(s * 0.62, hm + 0.42, 0.0), Vector3(0.4, 0.46, 0.03), blanc)
		f._glass(mxf, Vector3(s * 0.62, hm + 0.42, 0.02), Vector2(0.28, 0.34), 0, false, Color(1.0, 0.8, 0.5))
	var faite := hm + 0.1 + wm * 0.5 * tan(deg_to_rad(28.0))
	f.batch.box("wall", mxf, Vector3(cote * (wm / 2.0 - 0.25), (faite + 0.7) / 2.0, -1.2), Vector3(0.4, faite + 0.7, 0.4), creme.darkened(0.08))
	f.batch.box("trim", mxf, Vector3(cote * (wm / 2.0 - 0.25), faite + 0.72, -1.2), Vector3(0.48, 0.08, 0.48), blanc)
	# La dépendance basse, côté jardin, son pignon sur la rue, sans ouverture côté rue.
	var axf := xf * Transform3D(Basis(), Vector3(cote * (w / 2.0 - wa / 2.0), 0, 0))
	_socle(f, axf, wa, 2.4, fa.socle, creme.darkened(0.3))
	f.house(axf, {
		"w": wa, "d": 2.4, "floors": 1, "wall": creme, "shutter": blanc, "roof": ardoise, "roof_kind": "pignon",
		"lit": 0.0, "chimney": false, "front": false, "back": false,
	})
	# Une porte sur le flanc de la dépendance, et la vigne vierge qui grimpe au pignon.
	var fxf := axf * Transform3D(Basis(Vector3.UP, cote * PI / 2.0), Vector3(cote * wa / 2.0, 0, -1.2))
	f._door(fxf, 0.3, Color(0.55, 0.5, 0.45), creme.lightened(0.1), false)
	for i in 7:
		var vx: float = cote * (wa / 2.0 - 0.3) + f.rng.randf_range(-0.2, 0.2)
		f.batch.box("trim", axf, Vector3(vx, 0.25 + i * 0.2, 0.025), Vector3(0.12 + f.rng.randf() * 0.16, 0.14 + f.rng.randf() * 0.1, 0.05), Color(0.26, 0.42, 0.2).lerp(Color(0.45, 0.52, 0.22), f.rng.randf()))
	# La palissade blanche, le pilier et le mur bas du jardin, dans le prolongement de la façade.
	var x0 := cote * (w / 2.0 + 0.05)
	for i in 16:
		f.batch.box("trim", xf, Vector3(x0 + cote * (0.08 + i * 0.13), 0.28, 0.1), Vector3(0.06, 0.5, 0.03), blanc)
	f.batch.box("trim", xf, Vector3(x0 + cote * 1.1, 0.42, 0.1), Vector3(2.1, 0.04, 0.03), blanc)
	f.batch.box("trim", xf, Vector3(x0 + cote * 1.1, 0.18, 0.1), Vector3(2.1, 0.04, 0.03), blanc)
	var pilier := Color(0.86, 0.84, 0.78)
	f.batch.box("wall", xf, Vector3(x0 + cote * 2.3, 0.42, 0.1), Vector3(0.3, 0.84, 0.3), pilier)
	f.batch.box("trim", xf, Vector3(x0 + cote * 2.3, 0.87, 0.1), Vector3(0.36, 0.06, 0.36), pilier.lightened(0.1))
	f.garden_wall(xf * Vector3(x0 + cote * 2.45, 0, 0.1), xf * Vector3(x0 + cote * 5.5, 0, 0.1), 0.55, Color(0.8, 0.78, 0.72))
	# Le lampadaire du trottoir.
	var lx := x0 + cote * 1.7
	f.batch.box("trim", xf, Vector3(lx, 0.8, 0.9), Vector3(0.06, 1.6, 0.06), Color(0.12, 0.12, 0.13))
	f.batch.box("trim", xf, Vector3(lx, 1.7, 0.9), Vector3(0.22, 0.26, 0.22), Color(0.15, 0.15, 0.16))
	f._glass(xf, Vector3(lx, 1.68, 1.02), Vector2(0.16, 0.18), 0, true, Color(1.0, 0.85, 0.6))
	f.glows.append([xf * Vector3(lx, 1.7, 0.9), Color(1.0, 0.85, 0.6)])


# --- Les outils ------------------------------------------------------------------------------------

## Le mur de l'emprise qui regarde le point `vers` : le repère de la façade (origine au pied du mur,
## au milieu, +Z vers la rue, à la hauteur du sol devant la porte), sa longueur w, la profondeur d de
## l'emprise derrière lui, ses bouts a et c, et le socle à bâtir sous la maison quand le terrain
## descend derrière (la hauteur du sol de l'emprise est son point le plus bas).
static func _facade(b: Dictionary, vers: Vector2, hauteur: Callable) -> Dictionary:
	var poly: Array = b.p
	var aire := 0.0
	for k in poly.size():
		var q: Array = poly[k]
		var r: Array = poly[(k + 1) % poly.size()]
		aire += q[0] * r[1] - r[0] * q[1]
	var sens := 1.0 if aire > 0.0 else -1.0
	var best := {}
	var dbest := 1e9
	for k in poly.size():
		var a := Vector2(poly[k][0], poly[k][1])
		var c := Vector2(poly[(k + 1) % poly.size()][0], poly[(k + 1) % poly.size()][1])
		var l := a.distance_to(c)
		if l < 2.0:
			continue
		var m := (a + c) / 2.0
		var dir := (c - a) / l
		var n := Vector2(dir.y, -dir.x) * sens
		if n.dot(vers - m) <= 0.0:
			continue
		var dd := m.distance_to(vers)
		if dd < dbest:
			dbest = dd
			var prof := 0.0
			for q in poly:
				prof = maxf(prof, -n.dot(Vector2(q[0], q[1]) - m))
			var y: float = maxf(b.sol, hauteur.call(m.x + n.x * 0.6, m.y + n.y * 0.6) - 0.04)
			var xf := Transform3D(Basis(Vector3.UP, atan2(n.x, n.y)), Vector3(m.x, y, m.y))
			# Dans ce repère, +X vaut -dir × sens : a est du côté +X quand sens vaut 1, du côté -X sinon.
			best = {"xf": xf, "w": l, "d": prof, "a": a, "c": c, "sens": sens, "socle": y - b.sol}
	if best.is_empty():
		# Aucun mur ne regarde par là : le rectangle de l'emprise, face à la rue.
		var r: Array = b.rect
		var u := Vector2(cos(r[4]), sin(r[4]))
		var v := Vector2(-u.y, u.x) * float(b.face)
		var avant: Vector2 = Vector2(r[0], r[1]) + v * (r[3] / 2.0)
		best = {"xf": Transform3D(Basis(Vector3.UP, atan2(v.x, v.y)), Vector3(avant.x, b.sol, avant.y)), "w": r[2], "d": r[3], "a": avant + u * r[2] / 2.0, "c": avant - u * r[2] / 2.0, "sens": 1.0, "socle": 0.0}
	return best


## Le socle de pierre sombre sous une maison posée plus haut que le bas de son emprise.
static func _socle(f, xf: Transform3D, w: float, d: float, dy: float, couleur: Color) -> void:
	if dy > 0.02:
		f.batch.box("trim", xf, Vector3(0, -dy / 2.0, -d / 2.0), Vector3(w + 0.05, dy, d + 0.05), couleur)


## Les chaînes d'angle des deux coins avant, comme sur les maisons de Smarves.
static func _chaines(f, xf: Transform3D, w: float, h: float, clair: Color) -> void:
	var y := BASE_H
	var k := 0
	while y < h - 0.1:
		var hs := minf(0.24, h - y)
		var long := k % 2 == 0
		for side in [-1.0, 1.0]:
			var lw := 0.26 if long else 0.15
			f.batch.box("trim", xf, Vector3(side * (w / 2.0 - lw / 2.0 + 0.01), y + hs / 2.0, 0.015), Vector3(lw, hs - 0.025, 0.04), clair)
			var ld := 0.15 if long else 0.26
			f.batch.box("trim", xf, Vector3(side * (w / 2.0 + 0.015), y + hs / 2.0, -ld / 2.0 + 0.01), Vector3(0.04, hs - 0.025, ld), clair)
		y += hs
		k += 1


## Des lettres peintes sur un mur, centrées en `at`, tenant dans `largeur`.
static func _lettres(f, xf: Transform3D, at: Vector3, texte: String, taille: int, px: float, encre: Color, largeur: float) -> void:
	var l := Label3D.new()
	l.text = texte
	l.font = f.font
	l.font_size = taille
	l.pixel_size = px
	l.modulate = encre
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.transform = xf * Transform3D(Basis(), at)
	l.visibility_range_end = 40.0
	f.parent.add_child(l)
	f._fit(l, largeur)
