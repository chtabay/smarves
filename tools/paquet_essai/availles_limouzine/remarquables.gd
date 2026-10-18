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
		"mairie":
			_mairie(f, b, hauteur)
			return true
		"porte_cavaliers":
			_porte_cavaliers(f, b, hauteur)
			return true
		"groupama":
			_groupama(f, b, hauteur)
			return true
		"restaurant":
			_chez_cecile(f, b, hauteur)
			return true
		"maison_21":
			_maison_21(f, b, hauteur)
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
	_lampadaire(f, xf, Vector3(x0 + cote * 1.7, 0, 0.9))


# --- La mairie, place de la Mairie ------------------------------------------------------------------
## D'après photo, depuis le parking : un pavillon central à deux niveaux sous un toit de tuiles à
## quatre pans, chaînes d'angle et encadrements de pierre blanche sur l'enduit beige ; au milieu la
## porte bleue à deux vantaux sous son imposte en plein cintre, trois marches, le balcon de fer aux
## drapeaux français et européen, la plaque « MAIRIE » et, tout en haut, une petite fenêtre de comble ;
## de chaque côté deux grandes fenêtres cintrées en bas, une fenêtre à l'étage. Deux ailes basses à
## oculus et fenêtre cintrée, en légère avancée ; la rampe à garde-corps blanc à droite, deux
## lampadaires noirs, les massifs fleuris. La façade regarde le sud-ouest, vers le parking.
static func _mairie(f, b: Dictionary, hauteur: Callable) -> void:
	var fa := _facade(b, Vector2(51.0, 38.0), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = clampf(fa.w, 5.4, 6.4)
	var d: float = clampf(fa.d, 4.5, 6.5)
	var mur := Color(0.85, 0.8, 0.68)
	var clair := Color(0.94, 0.92, 0.86)
	var tuile := Color(0.72, 0.48, 0.34)
	var bleu := Color(0.3, 0.42, 0.62)
	var fer := Color(0.28, 0.2, 0.17)
	var gh := 1.85
	var h := gh + 1.55
	# Le pavillon central : corps, soubassement, cordon d'étage, chaînes, corniche, toit, cheminées.
	_socle(f, xf, w, d, fa.socle, mur.darkened(0.3))
	f.batch.box("wall", xf, Vector3(0, h / 2.0, -d / 2.0), Vector3(w, h, d), mur)
	f.batch.box("trim", xf, Vector3(0, BASE_H / 2.0, -d / 2.0), Vector3(w + 0.05, BASE_H, d + 0.05), mur.darkened(0.25))
	f.batch.box("trim", xf, Vector3(0, gh + 0.02, 0.01), Vector3(w, 0.07, 0.04), clair)
	_chaines(f, xf, w, h, clair)
	f.batch.box("trim", xf, Vector3(0, h - 0.06, -d / 2.0), Vector3(w + 0.16, 0.12, d + 0.16), clair)
	f._roof(xf, w, d, h, tuile, mur, "hip")
	for s in [-1.0, 1.0]:
		var top := h + 0.1 + d * 0.5 * tan(deg_to_rad(28.0))
		f.batch.box("wall", xf, Vector3(s * (w / 2.0 - 0.7), top - 0.3, -d * 0.4), Vector3(0.34, 1.0, 0.3), mur.darkened(0.05))
		f.batch.box("trim", xf, Vector3(s * (w / 2.0 - 0.7), top + 0.22, -d * 0.4), Vector3(0.42, 0.07, 0.38), clair)
	# La porte bleue, sous son imposte cintrée et son encadrement de pierre ; les trois marches.
	var seuil := 0.22
	for i in 3:
		f.batch.box("trim", xf, Vector3(0, 0.04 + i * 0.075, 0.52 - i * 0.18), Vector3(2.0 - i * 0.1, 0.08, 0.36 + i * 0.36), clair.darkened(0.12))
	_fenetre(f, xf, Vector3(0, seuil, 0), Vector2(0.86, 1.46), clair, true, false, Color(1.0, 0.85, 0.6))
	f.batch.box("trim", xf, Vector3(0, seuil + 0.55, 0.03), Vector3(0.86, 1.1, 0.03), bleu)
	f.batch.box("trim", xf, Vector3(0, seuil + 0.55, 0.045), Vector3(0.025, 1.1, 0.01), bleu.darkened(0.4))
	for s in [-1.0, 1.0]:
		f._glass(xf, Vector3(s * 0.22, seuil + 0.72, 0.05), Vector2(0.3, 0.55), 1, true, Color(1.0, 0.85, 0.6))
		f.batch.box("trim", xf, Vector3(s * 0.22, seuil + 0.22, 0.05), Vector3(0.3, 0.3, 0.01), bleu.lightened(0.08))
		# Les deux petits écussons tricolores de part et d'autre de la porte.
		for k in 3:
			f.batch.box("trim", xf, Vector3(s * 0.72 + (k - 1) * 0.035, seuil + 0.95, 0.03), Vector3(0.035, 0.13, 0.02), [Color(0.1, 0.25, 0.6), Color(0.95, 0.95, 0.95), Color(0.85, 0.15, 0.2)][k])
	f.glows.append([xf * Vector3(0, 1.0, 0.8), Color(1.0, 0.85, 0.6)])
	# Le balcon de fer forgé, et ses deux drapeaux inclinés vers la place.
	f.batch.box("trim", xf, Vector3(0, gh + 0.08, 0.2), Vector3(1.7, 0.1, 0.42), clair)
	for i in 9:
		f.batch.box("trim", xf, Vector3(-0.8 + i * 0.2, gh + 0.38, 0.39), Vector3(0.025, 0.5, 0.025), fer)
	for s in [-1.0, 1.0]:
		for k in 3:
			f.batch.box("trim", xf, Vector3(s * 0.8, gh + 0.38, 0.2 + k * 0.09), Vector3(0.025, 0.5, 0.025), fer)
		f.batch.box("trim", xf, Vector3(s * 0.8, gh + 0.63, 0.2), Vector3(0.03, 0.03, 0.4), fer)
	for y in [0.2, 0.63]:
		f.batch.box("trim", xf, Vector3(0, gh + y, 0.39), Vector3(1.62, 0.03, 0.03), fer)
	for s in [-1.0, 1.0]:
		var px: float = s * 0.32
		f.batch.box_tilted("trim", xf, Vector3(px, gh + 0.95, 0.5), Vector3(0.025, 0.9, 0.025), -0.6, Color(0.6, 0.6, 0.62))
		if s < 0.0:
			for k in 3:
				f.batch.box_tilted("trim", xf, Vector3(px - 0.07 + k * 0.07, gh + 1.0, 0.55), Vector3(0.07, 0.42, 0.015), -0.6, [Color(0.1, 0.25, 0.6), Color(0.95, 0.95, 0.95), Color(0.85, 0.15, 0.2)][k])
		else:
			f.batch.box_tilted("trim", xf, Vector3(px, gh + 1.0, 0.55), Vector3(0.21, 0.42, 0.015), -0.6, Color(0.1, 0.2, 0.55))
			for k in 6:
				f.batch.box_tilted("trim", xf, Vector3(px + 0.07 * cos(TAU * k / 6.0), gh + 1.0 + 0.1 * sin(TAU * k / 6.0), 0.565), Vector3(0.02, 0.02, 0.01), -0.6, Color(0.95, 0.8, 0.2))
	# La porte-fenêtre du balcon, la plaque MAIRIE, la petite fenêtre de comble.
	_fenetre(f, xf, Vector3(0, gh + 0.14, 0), Vector2(0.56, 0.88), clair, false, false, Color(1.0, 0.8, 0.5))
	f.batch.box("trim", xf, Vector3(0, h - 0.4, 0.02), Vector3(0.78, 0.22, 0.04), clair)
	f.batch.box("trim", xf, Vector3(0, h - 0.4, 0.045), Vector3(0.66, 0.14, 0.01), mur.darkened(0.08))
	_lettres(f, xf, Vector3(0, h - 0.4, 0.06), "MAIRIE", 34, 0.0032, Color(0.2, 0.17, 0.14), 0.6)
	_fenetre(f, xf, Vector3(0, h - 0.18, 0), Vector2(0.3, 0.2), clair, true, false, Color(1.0, 0.8, 0.5))
	# De chaque côté : deux grandes fenêtres cintrées en bas, une fenêtre à l'étage, les massifs fleuris.
	var bay := (w / 2.0 - 0.75) / 2.0
	for s in [-1.0, 1.0]:
		for k in 2:
			var x: float = s * (0.75 + bay * (k + 0.5))
			_fenetre(f, xf, Vector3(x, BASE_H + 0.3, 0), Vector2(0.66, 1.15), clair, true, f.rng.randf() < 0.3, Color(1.0, 0.82, 0.55))
		_fenetre(f, xf, Vector3(s * (0.75 + bay), gh + 0.22, 0), Vector2(0.52, 0.86), clair, false, false, Color(1.0, 0.8, 0.5))
	for i in 7:
		var x := -w / 2.0 + 0.35 + i * 0.33
		f.batch.box("trim", xf, Vector3(x, 0.18, 0.5 + (i % 2) * 0.1), Vector3(0.34, 0.3, 0.34), Color(0.26, 0.42, 0.2).lerp(Color(0.4, 0.5, 0.22), f.rng.randf()))
		for k in 3:
			f.batch.box("trim", xf, Vector3(x + (k - 1) * 0.1, 0.36, 0.5 + (i % 2) * 0.1), Vector3(0.07, 0.07, 0.07), [Color(0.95, 0.4, 0.6), Color(0.98, 0.95, 0.9), Color(0.9, 0.2, 0.3)][(i + k) % 3])
	# La rampe d'accès à droite, et son garde-corps blanc.
	var blanc := Color(0.95, 0.95, 0.93)
	f.batch.box("trim", xf, Vector3(1.9, 0.11, 0.42), Vector3(1.9, 0.22, 0.5), clair.darkened(0.15))
	for i in 6:
		f.batch.box("trim", xf, Vector3(1.0 + i * 0.36, 0.5, 0.68), Vector3(0.03, 0.56, 0.03), blanc)
	f.batch.box("trim", xf, Vector3(1.9, 0.78, 0.68), Vector3(1.9, 0.03, 0.03), blanc)
	f.batch.box("trim", xf, Vector3(1.9, 0.5, 0.68), Vector3(1.9, 0.02, 0.02), blanc)
	# Les deux ailes basses, en légère avancée, à oculus et fenêtre cintrée sous leur toit à quatre pans.
	var ww := 2.3
	var wd := clampf(d - 1.2, 3.0, 5.0)
	var hw := 1.8
	for s in [-1.0, 1.0]:
		var axf := xf * Transform3D(Basis(), Vector3(s * (w / 2.0 + ww / 2.0 - 0.02), 0, 0.4))
		_socle(f, axf, ww, wd, fa.socle + 0.02, mur.darkened(0.3))
		f.batch.box("wall", axf, Vector3(0, hw / 2.0, -wd / 2.0), Vector3(ww, hw, wd), mur)
		f.batch.box("trim", axf, Vector3(0, BASE_H / 2.0, -wd / 2.0), Vector3(ww + 0.05, BASE_H, wd + 0.05), mur.darkened(0.25))
		f.batch.box("trim", axf, Vector3(0, hw - 0.05, -wd / 2.0), Vector3(ww + 0.14, 0.1, wd + 0.14), clair)
		_chaines(f, axf, ww, hw, clair)
		f._roof(axf, ww, wd, hw, tuile, mur, "hip")
		_fenetre(f, axf, Vector3(0, BASE_H + 0.3, 0), Vector2(0.5, 0.78), clair, true, false, Color(1.0, 0.82, 0.55))
		f.batch.box("trim", axf, Vector3(0, hw - 0.36, 0.02), Vector3(0.42, 0.42, 0.04), clair)
		f.batch.box("trim", axf, Vector3(0, hw - 0.36, 0.045), Vector3(0.3, 0.3, 0.01), Color(0.3, 0.3, 0.32))
		_lampadaire(f, xf, Vector3(s * (w / 2.0 + 0.5), 0, 1.6))


# --- La porte des Cavaliers --------------------------------------------------------------------------
## D'après photo : la vieille porte de ville, un passage voûté en plein cintre dans un mur de moellons,
## sous un petit toit de tuiles, et à son côté la grosse tour ronde qui marque l'angle de la maison ;
## la maison elle-même regarde la place : deux niveaux à l'enduit crème, les volets blancs, les
## géraniums aux fenêtres. La voûte et la tour regardent l'ouest-sud-ouest, vers le carrefour de la
## rue des Cavaliers, qui passe sous la voûte et file derrière la maison vers la ruelle.
static func _porte_cavaliers(f, b: Dictionary, hauteur: Callable) -> void:
	var fa := _facade(b, Vector2(51.0, 38.0), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = clampf(fa.w, 4.0, 5.0)
	var d := 3.5
	# L'ouest est au bout de la façade le plus à l'ouest ; la rue des Cavaliers passe derrière la
	# maison, sous la voûte, et la tour se dresse entre la voûte et la maison.
	var ouest: float = (1.0 if fa.a.x < fa.c.x else -1.0) * fa.sens
	var creme := Color(0.9, 0.84, 0.7)
	var pierre := Color(0.72, 0.62, 0.46)
	var joint := Color(0.55, 0.47, 0.36)
	var blanc := Color(0.95, 0.95, 0.93)
	var tuile := Color(0.76, 0.5, 0.34)
	var clair := Color(0.92, 0.88, 0.78)
	var fer := Color(0.14, 0.14, 0.15)
	# La maison : corps enduit, soubassement, cordon, chaînes, toit à quatre pans, cheminée.
	var h := BASE_H + 2.0 * FLOOR_H
	_socle(f, xf, w, d, fa.socle, joint)
	f.batch.box("wall", xf, Vector3(0, h / 2.0, -d / 2.0), Vector3(w, h, d), creme)
	f.batch.box("trim", xf, Vector3(0, BASE_H / 2.0, -d / 2.0), Vector3(w + 0.05, BASE_H, d + 0.05), joint)
	f.batch.box("trim", xf, Vector3(0, BASE_H + FLOOR_H + 0.02, 0.01), Vector3(w, 0.06, 0.04), clair)
	_chaines(f, xf, w, h, clair)
	f._roof(xf, w, d, h, tuile, creme, "hip")
	var top := h + 0.1 + d * 0.5 * tan(deg_to_rad(28.0))
	f.batch.box("wall", xf, Vector3(-ouest * (w / 2.0 - 0.7), top - 0.25, -d * 0.4), Vector3(0.34, 0.9, 0.3), creme.darkened(0.08))
	f.batch.box("trim", xf, Vector3(-ouest * (w / 2.0 - 0.7), top + 0.22, -d * 0.4), Vector3(0.42, 0.07, 0.38), clair)
	# Sur la place : la porte côté est, les fenêtres à volets blancs et leurs géraniums.
	var xs := [-ouest * 1.5, -ouest * 0.45, ouest * 0.7]
	f._door(xf, xs[0], blanc.darkened(0.1), clair, false)
	for x in [xs[1], xs[2]]:
		f._window(xf, Vector3(x, BASE_H + 0.3, 0), Vector2(0.5, 0.78), blanc, clair, 0.2)
	for x in xs:
		f._window(xf, Vector3(x, BASE_H + FLOOR_H + 0.3, 0), Vector2(0.5, 0.78), blanc, clair, 0.2)
	# Le flanc ouest de la maison, celui qu'on voit en arrivant de la rue des Cavaliers : une travée
	# de fenêtres entre l'angle de la place et la tour.
	var oxf := xf * Transform3D(Basis(Vector3.UP, ouest * PI / 2.0), Vector3(ouest * w / 2.0, 0, -0.9))
	for k in 2:
		f._window(oxf, Vector3(0, BASE_H + 0.3 + k * FLOOR_H, 0), Vector2(0.5, 0.78), blanc, clair, 0.2)
	# Le mur de la porte, en retrait, dans le prolongement du flanc ouest : la rue des Cavaliers le
	# traverse sous sa voûte, derrière la maison, du carrefour au sud-ouest vers la ruelle au nord-est.
	var pw := 1.5
	var pxf := xf * Transform3D(Basis(), Vector3(ouest * (w / 2.0 + 0.1 + pw / 2.0), 0, 0))
	var z0 := -2.7
	var z1 := -5.8
	var zc := -4.2
	var ph := 2.45
	var passage_w := 1.2
	var passage_h := 1.6
	var zm := (z0 + z1) / 2.0
	var pd := z0 - z1
	if fa.socle > 0.02:
		f.batch.box("trim", pxf, Vector3(0, -fa.socle / 2.0, zm), Vector3(pw + 0.05, fa.socle, pd + 0.05), joint)
	var zs := zc + passage_w / 2.0
	f.batch.box("wall", pxf, Vector3(0, ph / 2.0, (z0 + zs) / 2.0), Vector3(pw, ph, z0 - zs), pierre)
	var zn := zc - passage_w / 2.0
	f.batch.box("wall", pxf, Vector3(0, ph / 2.0, (zn + z1) / 2.0), Vector3(pw, ph, zn - z1), pierre)
	f.batch.box("wall", pxf, Vector3(0, (ph + passage_h) / 2.0, zc), Vector3(pw, ph - passage_h, passage_w + 0.02), pierre)
	# La voûte en plein cintre, en claveaux de pierre claire, sur les deux faces du passage.
	var rr := passage_w / 2.0
	for s in [-1.0, 1.0]:
		var vx: float = s * (pw / 2.0 + 0.03)
		for k in 7:
			var am := PI * (k + 0.5) / 7.0
			var c := Vector3(vx, passage_h - rr + rr * 0.92 * sin(am), zc + rr * 0.92 * cos(am))
			f.batch.box("wall", pxf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0 - am), c), Vector3.ZERO, Vector3(0.08, 0.3, 0.26), clair)
		for q in [-1.0, 1.0]:
			# Les écoinçons, qui ferment les angles carrés au-dessus de la naissance de la voûte.
			f.batch.box("wall", pxf, Vector3(vx, passage_h - 0.14, zc + q * (rr - 0.14)), Vector3(0.07, 0.28, 0.28), pierre)
			f.batch.box("trim", pxf, Vector3(vx, (passage_h - rr) / 2.0, zc + q * (rr + 0.06)), Vector3(0.08, passage_h - rr, 0.12), clair)
	# Le dessous de la voûte, sombre, et le pavé de la rue sous le passage.
	f.batch.box("trim", pxf, Vector3(0, passage_h + 0.02, zc), Vector3(pw, 0.04, passage_w + 0.02), joint.darkened(0.45))
	f.batch.box("trim", pxf, Vector3(0, 0.02, zc), Vector3(pw + 0.6, 0.04, passage_w), joint.darkened(0.2))
	# La fenêtre à volets blancs au-dessus de la voûte, côté rue des Cavaliers, et le toit du mur.
	var wxf := pxf * Transform3D(Basis(Vector3.UP, ouest * PI / 2.0), Vector3(ouest * pw / 2.0, 0, zc))
	f._window(wxf, Vector3(0, passage_h + 0.22, 0), Vector2(0.42, 0.55), blanc, clair, 0.2)
	f.batch.box("trim", pxf, Vector3(0, ph - 0.05, zm), Vector3(pw + 0.12, 0.08, pd + 0.12), joint)
	f._roof(pxf * Transform3D(Basis(), Vector3(0, 0, z0)), pw, pd, ph, tuile, pierre, "hip")
	# La tour ronde, en moellons, entre la voûte et la maison, sous son toit conique de tuiles : ses
	# portes-fenêtres à volets blancs et le balcon de fer regardent le carrefour.
	var r := 0.85
	var tc := Vector3(ouest * 0.5, 0, z0)
	var ht := h + 0.25
	f.batch.cylinder("wall", pxf, tc + Vector3(0, -minf(fa.socle, 0.6), 0), r, ht + minf(fa.socle, 0.6), pierre, 12)
	f.batch.cylinder("trim", pxf, tc + Vector3(0, ht - 0.04, 0), r + 0.08, 0.08, joint, 12)
	_cone(f, pxf, tc + Vector3(0, ht + 0.04, 0), r + 0.14, 0.75, tuile, 12)
	var a := atan2(0.21, ouest * 0.977)
	for k in 2:
		var y := BASE_H + 0.1 + k * FLOOR_H
		var p := tc + Vector3(cos(a) * r, y, sin(a) * r)
		var txf := pxf * Transform3D(Basis(Vector3.UP, -a + PI / 2.0), p)
		f.batch.box("trim", txf, Vector3(0, 0.5, 0.0), Vector3(0.46, 0.92, 0.05), clair)
		for s in [-1.0, 1.0]:
			f.batch.box("trim", txf, Vector3(s * 0.12, 0.5, 0.03), Vector3(0.2, 0.86, 0.02), blanc)
		if k == 1:
			f.batch.box("trim", txf, Vector3(0, 0.0, 0.12), Vector3(0.7, 0.05, 0.3), joint)
			f.batch.box("trim", txf, Vector3(0, 0.36, 0.26), Vector3(0.7, 0.025, 0.025), fer)
			for i in 9:
				f.batch.box("trim", txf, Vector3(-0.32 + i * 0.08, 0.19, 0.26), Vector3(0.02, 0.36, 0.02), fer)
		else:
			f.glows.append([pxf * (p + Vector3(0, 0.5, 0.2)), Color(1.0, 0.8, 0.5)])
	# Le lampadaire du carrefour.
	_lampadaire(f, pxf, Vector3(ouest * (pw / 2.0 + 1.6), 0, zc + 1.6))


# --- Le 7 place de la Mairie : l'agence Groupama ----------------------------------------------------
## D'après photo, depuis le carrefour de la rue des Cavaliers : une maison de moellons apparents à
## deux niveaux sous un toit de tuiles à deux pans ; à gauche la porte vitrée blanche de l'agence et
## son enseigne « Groupama », à droite une porte cintrée blanche et une petite fenêtre, à l'étage
## trois fenêtres à volets blancs ; à l'angle, le poteau des panneaux de direction, et deux buis en
## pot devant la porte. La façade regarde le nord-ouest, vers la place.
static func _groupama(f, b: Dictionary, hauteur: Callable) -> void:
	var fa := _facade(b, Vector2(32.7, 42.6), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = clampf(fa.w, 4.6, 5.4)
	var d := 2.6
	# Le bout de la façade le plus à l'est est l'angle de la rue des Cavaliers : l'agence est de ce côté.
	var est: float = (1.0 if fa.a.x > fa.c.x else -1.0) * fa.sens
	var pierre := Color(0.7, 0.63, 0.52)
	var joint := Color(0.5, 0.44, 0.36)
	var blanc := Color(0.95, 0.95, 0.93)
	var clair := Color(0.9, 0.86, 0.76)
	var tuile := Color(0.78, 0.5, 0.33)
	var vert := Color(0.0, 0.42, 0.3)
	var h := BASE_H + 2.0 * FLOOR_H
	_socle(f, xf, w, d, fa.socle, joint)
	f.batch.box("wall", xf, Vector3(0, h / 2.0, -d / 2.0), Vector3(w, h, d), pierre)
	f.batch.box("trim", xf, Vector3(0, BASE_H / 2.0, -d / 2.0), Vector3(w + 0.05, BASE_H, d + 0.05), joint)
	_moellons(f, xf, w, h, pierre)
	_chaines(f, xf, w, h, clair)
	f._roof(xf, w, d, h, tuile, pierre, "gable")
	var top := h + 0.1 + d * 0.5 * tan(deg_to_rad(28.0))
	f.batch.box("wall", xf, Vector3(est * (w / 2.0 - 0.5), top - 0.2, -d / 2.0), Vector3(0.34, 0.9, 0.34), pierre.darkened(0.1))
	f.batch.box("trim", xf, Vector3(est * (w / 2.0 - 0.5), top + 0.27, -d / 2.0), Vector3(0.42, 0.07, 0.42), clair)
	# Le corps arrière, plus bas, sur la moitié ouest de l'emprise.
	var axf := xf * Transform3D(Basis(), Vector3(-est * (w / 2.0 - 1.3), 0, -d))
	f.batch.box("wall", axf, Vector3(0, (h - 0.3) / 2.0, -1.1), Vector3(2.6, h - 0.3, 2.2), pierre)
	f._roof(axf, 2.6, 2.2, h - 0.3, tuile, pierre, "hip")
	# L'agence : la porte vitrée blanche à deux vantaux, l'enseigne blanche aux lettres vertes.
	var xa := est * 1.25
	f.batch.box("trim", xf, Vector3(xa, BASE_H + 0.56, 0.02), Vector3(0.92, 1.12, 0.04), blanc)
	f._glass(xf, Vector3(xa, BASE_H + 0.56, 0.045), Vector2(0.8, 1.02), 2, true, Color(1.0, 0.9, 0.75))
	f.batch.box("trim", xf, Vector3(xa, BASE_H + 1.26, 0.03), Vector3(1.0, 0.24, 0.05), blanc)
	f.batch.box("trim", xf, Vector3(xa - est * 0.38, BASE_H + 1.26, 0.06), Vector3(0.14, 0.14, 0.02), vert)
	_lettres(f, xf, Vector3(xa + est * 0.08, BASE_H + 1.26, 0.06), "Groupama", 40, 0.0032, vert, 0.7)
	f.glows.append([xf * Vector3(xa, BASE_H + 0.8, 0.5), Color(1.0, 0.9, 0.75)])
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(xa + s * 0.62, 0.14, 0.2), Vector3(0.22, 0.28, 0.22), Color(0.25, 0.22, 0.2))
		f.batch.box("trim", xf, Vector3(xa + s * 0.62, 0.42, 0.2), Vector3(0.3, 0.3, 0.3), Color(0.24, 0.4, 0.2))
	# La porte cintrée blanche et la petite fenêtre, côté ouest ; à l'étage, trois fenêtres.
	var xp := -est * 0.5
	f.batch.box("trim", xf, Vector3(xp, BASE_H + 0.5, 0.01), Vector3(0.5, 1.0, 0.03), blanc.darkened(0.05))
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(xp + s * 0.3, BASE_H + 0.5, 0.02), Vector3(0.1, 1.0, 0.05), clair)
	_arc(f, xf, Vector3(xp, BASE_H + 1.0, 0.02), 0.3, clair)
	f._window(xf, Vector3(-est * 1.75, BASE_H + 0.35, 0), Vector2(0.42, 0.62), blanc, clair, 0.0)
	for x in [est * 1.6, est * 0.2, -est * 1.3]:
		f._window(xf, Vector3(x, BASE_H + FLOOR_H + 0.32, 0), Vector2(0.5, 0.76), blanc, clair, 0.2)
	# Le poteau des panneaux de direction, à l'angle de la rue des Cavaliers.
	var px := est * (w / 2.0 + 0.35)
	f.batch.box("trim", xf, Vector3(px, 0.95, 0.45), Vector3(0.05, 1.9, 0.05), Color(0.35, 0.36, 0.38))
	for i in 4:
		var dx: float = est * (0.26 if i % 2 == 0 else -0.26)
		f.batch.box("trim", xf, Vector3(px + dx, 1.25 + i * 0.17, 0.45), Vector3(0.5, 0.13, 0.03), blanc)
		f.batch.box("trim", xf, Vector3(px + dx, 1.25 + i * 0.17, 0.465), Vector3(0.36, 0.05, 0.005), Color(0.2, 0.2, 0.22))


# --- Le restaurant Chez Cécile, rue Adrien-Veillon, à côté de l'agence ---------------------------------
## D'après photo : une salle basse en façade, enduit ocre et menuiseries blanches, sous un toit de
## tuiles à quatre pans, le corps de logis à deux niveaux derrière ; devant, la petite barrière de bois
## brun et l'enseigne rouge « Chez Cécile » sur son poteau, au bout vers la place.
static func _chez_cecile(f, b: Dictionary, hauteur: Callable) -> void:
	var fa := _facade(b, Vector2(32.7, 42.6), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = clampf(fa.w, 3.8, 4.6)
	var est: float = (1.0 if fa.a.x > fa.c.x else -1.0) * fa.sens
	var ocre := Color(0.8, 0.58, 0.34)
	var creme := Color(0.9, 0.85, 0.72)
	var blanc := Color(0.95, 0.95, 0.93)
	var tuile := Color(0.8, 0.52, 0.34)
	var brun := Color(0.42, 0.26, 0.15)
	var rouge := Color(0.72, 0.12, 0.1)
	_socle(f, xf, w, 2.4, fa.socle, ocre.darkened(0.35))
	f.house(xf, {
		"w": w, "d": 2.4, "floors": 1, "wall": ocre, "shutter": blanc, "roof": tuile, "roof_kind": "hip",
		"lit": 0.6, "chimney": false, "door": "left" if est > 0.0 else "right", "back": false,
	})
	var lxf := xf * Transform3D(Basis(), Vector3(0, 0, -2.4))
	_socle(f, lxf, w - 0.3, 3.4, fa.socle, creme.darkened(0.35))
	f.house(lxf, {
		"w": w - 0.3, "d": 3.4, "floors": 2, "wall": creme, "shutter": blanc, "roof": tuile, "roof_kind": "hip",
		"lit": 0.2, "chimney": true, "front": false, "back": false,
	})
	# La barrière de bois brun le long du trottoir, qui laisse l'entrée.
	var x0: float = -est * w / 2.0
	var x1: float = est * (w / 2.0 - 1.1)
	var n := int(absf(x1 - x0) / 0.32)
	for i in n + 1:
		var x: float = x0 + (x1 - x0) * float(i) / float(n)
		f.batch.box("trim", xf, Vector3(x, 0.3, 0.55), Vector3(0.05, 0.6, 0.05), brun)
	for y in [0.25, 0.5]:
		f.batch.box("trim", xf, Vector3((x0 + x1) / 2.0, y, 0.56), Vector3(absf(x1 - x0) + 0.05, 0.04, 0.03), brun)
	# L'enseigne sur son poteau, tournée vers la place.
	var ex: float = est * (w / 2.0 + 0.25)
	f.batch.box("trim", xf, Vector3(ex, 1.0, 0.3), Vector3(0.06, 2.0, 0.06), Color(0.3, 0.3, 0.32))
	var exf := xf * Transform3D(Basis(Vector3.UP, est * PI / 2.0), Vector3(ex, 1.75, 0.3))
	f.batch.box("trim", exf, Vector3(0, 0, 0), Vector3(0.62, 0.36, 0.04), rouge)
	f.batch.box("trim", exf, Vector3(0, 0, 0.022), Vector3(0.56, 0.3, 0.005), blanc)
	_lettres(f, exf, Vector3(0, 0.06, 0.03), "Chez", 30, 0.0026, rouge, 0.5)
	_lettres(f, exf, Vector3(0, -0.07, 0.03), "CÉCILE", 36, 0.003, rouge, 0.52)
	f.glows.append([xf * Vector3(ex, 1.75, 0.6), Color(1.0, 0.85, 0.7)])


# --- Le 21 place de la Mairie : la maison de maître ---------------------------------------------------
## D'après photo, depuis la place : la grille de fer forgé sur son mur bas, ses deux portails à
## volutes entre les piliers de pierre ; au fond de la cour, la maison de maître aux cinq travées de
## hautes fenêtres, chaînes d'angle et cordon, perron, lucarnes et cheminées sur le toit à quatre
## pans ; à droite, sur la rue, le pavillon d'angle à chaînes en damier, son balcon de fer et son toit
## d'ardoise en pointe, relié à la maison par une aile basse à l'enduit blanc ; deux tilleuls en boule
## dans la cour. La grille et le pavillon sont sur la place ; la maison regarde la cour, au nord-est.
static func _maison_21(f, b: Dictionary, hauteur: Callable) -> void:
	var fa := _facade(b, Vector2(17.05, 46.15), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = clampf(fa.w, 4.0, 4.6)
	var d: float = clampf(fa.d, 4.2, 5.2)
	var ocre := Color(0.84, 0.76, 0.6)
	var clair := Color(0.94, 0.91, 0.84)
	var gris := Color(0.55, 0.58, 0.6)
	var blanc := Color(0.92, 0.9, 0.86)
	var tuile := Color(0.78, 0.5, 0.33)
	var ardoise := Color(0.3, 0.32, 0.38)
	var fer := Color(0.12, 0.12, 0.13)
	var moellon := Color(0.76, 0.7, 0.6)
	var lumiere := Color(1.0, 0.82, 0.55)
	var eh := 1.45
	var h := BASE_H + 2.0 * eh
	# La maison de maître.
	_socle(f, xf, w, d, fa.socle, ocre.darkened(0.35))
	f.batch.box("wall", xf, Vector3(0, h / 2.0, -d / 2.0), Vector3(w, h, d), ocre)
	f.batch.box("trim", xf, Vector3(0, BASE_H / 2.0, -d / 2.0), Vector3(w + 0.05, BASE_H, d + 0.05), ocre.darkened(0.3))
	f.batch.box("trim", xf, Vector3(0, BASE_H + eh + 0.02, 0.01), Vector3(w, 0.07, 0.05), clair)
	f.batch.box("trim", xf, Vector3(0, h + 0.02, -d / 2.0), Vector3(w + 0.16, 0.1, d + 0.16), clair)
	_chaines(f, xf, w, h, clair)
	f._roof(xf, w, d, h, tuile, ocre, "hip")
	var top := h + 0.1 + d * 0.5 * tan(deg_to_rad(28.0))
	for zc in [-1.2, -d + 1.2]:
		f.batch.box("wall", xf, Vector3(0, top - 0.1, zc), Vector3(0.5, 1.0, 0.36), ocre.darkened(0.1))
		f.batch.box("trim", xf, Vector3(0, top + 0.42, zc), Vector3(0.58, 0.08, 0.44), clair)
	for x in [-1.0, 1.0]:
		f._dormer(xf, x, h, d, tuile, clair, 0.0)
	for x in [-1.6, -0.8, 0.8, 1.6]:
		_fenetre(f, xf, Vector3(x, BASE_H + 0.25, 0), Vector2(0.46, 0.95), clair, false, false, lumiere)
	for x in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		_fenetre(f, xf, Vector3(x, BASE_H + eh + 0.2, 0), Vector2(0.46, 0.95), clair, false, false, lumiere)
	f._door(xf, 0.0, gris, clair, true)
	f.batch.box("trim", xf, Vector3(0, BASE_H + 1.08, 0.02), Vector3(0.68, 0.2, 0.05), clair)
	f._glass(xf, Vector3(0, BASE_H + 1.08, 0.05), Vector2(0.5, 0.14), 2, true, lumiere)
	f.batch.box("trim", xf, Vector3(0, 0.03, 0.3), Vector3(1.3, 0.06, 0.6), clair.darkened(0.1))
	f.batch.box("trim", xf, Vector3(0, 0.09, 0.18), Vector3(1.1, 0.06, 0.36), clair.darkened(0.05))
	# Le pavillon d'angle sur la place, au bout de l'aile, et l'aile basse qui le relie à la maison.
	var base := Vector2(14.2, 43.5)
	var bout := Vector2(18.3, 40.97)
	var u := (bout - base).normalized()
	var yp: float = maxf(float(b.sol), hauteur.call(bout.x + u.x * 0.6, bout.y + u.y * 0.6) - 0.04)
	var pxf := Transform3D(Basis(Vector3.UP, atan2(u.x, u.y)), Vector3(bout.x, yp, bout.y))
	var pw := 2.0
	var hp := BASE_H + 2.0 * FLOOR_H + 0.1
	var sp: float = yp - float(b.sol)
	_socle(f, pxf, pw, pw, sp, moellon.darkened(0.3))
	f.batch.box("wall", pxf, Vector3(0, hp / 2.0, -pw / 2.0), Vector3(pw, hp, pw), moellon)
	f.batch.box("trim", pxf, Vector3(0, BASE_H / 2.0, -pw / 2.0), Vector3(pw + 0.05, BASE_H, pw + 0.05), moellon.darkened(0.3))
	_moellons(f, pxf, pw, hp, moellon)
	_chaines(f, pxf, pw, hp, clair)
	_chaines(f, pxf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -pw)), pw, hp, clair)
	f.batch.box("trim", pxf, Vector3(0, hp + 0.03, -pw / 2.0), Vector3(pw + 0.24, 0.1, pw + 0.24), clair)
	_cone(f, pxf, Vector3(0, hp + 0.08, -pw / 2.0), (pw / 2.0 + 0.12) * sqrt(2.0), 1.7, ardoise, 4, PI / 4.0)
	f.batch.cylinder("trim", pxf, Vector3(0, hp + 1.7, -pw / 2.0), 0.03, 0.4, fer, 6)
	f.batch.box("trim", pxf, Vector3(0, hp + 2.08, -pw / 2.0), Vector3(0.1, 0.1, 0.1), fer)
	f._window(pxf, Vector3(0, BASE_H + 0.3, 0), Vector2(0.46, 0.7), blanc, clair, 0.0, true)
	var by := BASE_H + FLOOR_H
	f.batch.box("trim", pxf, Vector3(0, by + 0.5, 0.0), Vector3(0.52, 0.96, 0.05), clair)
	f.batch.box("trim", pxf, Vector3(0, by + 0.5, 0.03), Vector3(0.42, 0.9, 0.02), gris)
	f._glass(pxf, Vector3(0, by + 0.5, 0.045), Vector2(0.36, 0.84), 0, false, lumiere)
	f.batch.box("trim", pxf, Vector3(0, by + 0.0, 0.16), Vector3(1.3, 0.07, 0.34), clair)
	f.batch.box("trim", pxf, Vector3(0, by + 0.42, 0.31), Vector3(1.3, 0.025, 0.025), fer)
	for i in 15:
		f.batch.box("trim", pxf, Vector3(-0.6 + i * 0.086, by + 0.22, 0.31), Vector3(0.02, 0.4, 0.02), fer)
	var sxf := pxf * Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-pw / 2.0, 0, -pw / 2.0))
	f._window(sxf, Vector3(0, BASE_H + FLOOR_H + 0.3, 0), Vector2(0.46, 0.7), blanc, clair, 0.2)
	var aw := 1.6
	var al := 2.8
	var ha := BASE_H + 2.0 * FLOOR_H - 0.3
	var axf := pxf * Transform3D(Basis(), Vector3(0.1, 0, -pw))
	_socle(f, axf, aw, al, sp, blanc.darkened(0.35))
	f.batch.box("wall", axf, Vector3(0, ha / 2.0, -al / 2.0), Vector3(aw, ha, al), blanc)
	f.batch.box("trim", axf, Vector3(0, BASE_H / 2.0, -al / 2.0), Vector3(aw + 0.05, BASE_H, al + 0.05), blanc.darkened(0.3))
	f._roof(axf, aw, al, ha, tuile, blanc, "hip")
	var cxf := axf * Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(-aw / 2.0, 0, -al / 2.0))
	for k in 2:
		for x in [-0.7, 0.7]:
			f._window(cxf, Vector3(x, BASE_H + 0.3 + k * FLOOR_H, 0), Vector2(0.44, 0.68), blanc, clair, 0.2)
	# La grille sur la place : le mur bas de pierre, les barreaux, les deux portails entre leurs piliers.
	var ga: Vector3 = pxf * Vector3(-pw / 2.0, 0, 0)
	var gb := Vector3(20.21, ga.y, 46.85)
	var dir := gb - ga
	var long := dir.length()
	var gxf := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z) - PI / 2.0), Vector3(ga.x, 0, ga.z))
	var pil := 1.0
	var p1 := long / 2.0 - pil
	var p2 := long / 2.0 + pil
	var seg := 0.65
	var x := 0.0
	while x < long - 0.05:
		var xe := minf(x + seg, long)
		var xm := (x + xe) / 2.0
		var pt: Vector3 = gxf * Vector3(xm, 0, 0)
		var y: float = hauteur.call(pt.x, pt.z) - 0.03
		if xe <= p1 + 0.01 or x >= p2 - 0.01:
			f.batch.box("wall", gxf, Vector3(xm, y + 0.22, 0), Vector3(xe - x + 0.02, 0.44, 0.16), moellon)
			f.batch.box("trim", gxf, Vector3(xm, y + 0.46, 0), Vector3(xe - x + 0.04, 0.05, 0.2), clair)
			f.batch.box("trim", gxf, Vector3(xm, y + 1.42, 0), Vector3(xe - x + 0.02, 0.03, 0.03), fer)
			f.batch.box("trim", gxf, Vector3(xm, y + 1.2, 0), Vector3(xe - x + 0.02, 0.1, 0.015), fer)
			var bx := x + 0.055
			while bx < xe:
				f.batch.box("trim", gxf, Vector3(bx, y + 0.96, 0), Vector3(0.025, 1.0, 0.025), fer)
				bx += 0.11
		x = xe
	for px in [p1 - 0.2, p2 + 0.2]:
		var pt: Vector3 = gxf * Vector3(px, 0, 0)
		var y: float = hauteur.call(pt.x, pt.z) - 0.03
		f.batch.box("wall", gxf, Vector3(px, y + 0.8, 0), Vector3(0.36, 1.6, 0.36), clair.darkened(0.08))
		f.batch.box("trim", gxf, Vector3(px, y + 1.64, 0), Vector3(0.44, 0.08, 0.44), clair)
	for s in [-1.0, 1.0]:
		var cx: float = long / 2.0 + s * (pil / 2.0 - 0.02)
		var pt: Vector3 = gxf * Vector3(cx, 0, 0)
		var y: float = hauteur.call(pt.x, pt.z) - 0.03
		f.batch.box("trim", gxf, Vector3(cx, y + 0.32, 0), Vector3(pil - 0.06, 0.5, 0.03), fer.lightened(0.05))
		f.batch.box("trim", gxf, Vector3(cx, y + 1.45, 0), Vector3(pil - 0.06, 0.03, 0.03), fer)
		f.batch.box("trim", gxf, Vector3(cx, y + 1.25, 0), Vector3(pil - 0.06, 0.12, 0.015), fer)
		for i in 10:
			f.batch.box("trim", gxf, Vector3(cx - pil / 2.0 + 0.08 + i * 0.09, y + 1.0, 0), Vector3(0.025, 0.9, 0.025), fer)
	# Deux tilleuls taillés en boule dans la cour.
	for q in [Vector2(15.3, 44.3), Vector2(18.2, 46.1)]:
		var yt: float = hauteur.call(q.x, q.y) - 0.05
		var txf := Transform3D(Basis(), Vector3(q.x, yt, q.y))
		f.batch.cylinder("trim", txf, Vector3.ZERO, 0.08, 1.1, Color(0.36, 0.28, 0.2), 6)
		var feuille := Color(0.3, 0.48, 0.2)
		f.batch.cylinder("trim", txf, Vector3(0, 1.0, 0), 0.6, 0.45, feuille.darkened(0.1), 8)
		f.batch.cylinder("trim", txf, Vector3(0, 1.45, 0), 0.85, 0.7, feuille, 8)
		f.batch.cylinder("trim", txf, Vector3(0, 2.15, 0), 0.55, 0.45, feuille.lightened(0.1), 8)
	var lp: Vector3 = gxf * Vector3(long - 0.6, 0, -0.7)
	_lampadaire(f, gxf, Vector3(long - 0.6, hauteur.call(lp.x, lp.z) - 0.03, -0.7))


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


## Une fenêtre à encadrement de pierre, sans volets (mairie, dépendances) ; `arche` l'arrondit en
## plein cintre, par un escalier de claveaux.
static func _fenetre(f, xf: Transform3D, at: Vector3, size: Vector2, clair: Color, arche: bool, on: bool, lumiere: Color) -> void:
	var c := at + Vector3(0, size.y / 2.0, 0)
	f.batch.box("trim", xf, c + Vector3(0, -size.y / 2.0 - 0.03, 0.04), Vector3(size.x + 0.16, 0.06, 0.1), clair)
	f.batch.box("trim", xf, c + Vector3(0, 0, 0.0), Vector3(size.x + 0.14, size.y, 0.04), clair)
	f.batch.box("trim", xf, c + Vector3(0, 0, 0.025), Vector3(size.x, size.y - 0.08, 0.02), Color(0.5, 0.5, 0.52))
	f._glass(xf, c + Vector3(0, 0, 0.04), Vector2(size.x - 0.06, size.y - 0.14), 0, on, lumiere)
	if arche:
		var r := size.x / 2.0 + 0.07
		for k in 5:
			var a := PI * (k + 0.5) / 5.0
			var p := c + Vector3(r * 0.72 * cos(a), size.y / 2.0 + r * 0.72 * sin(a), 0.0)
			f.batch.box("trim", xf * Transform3D(Basis(Vector3.BACK, a - PI / 2.0), p), Vector3.ZERO, Vector3(0.28, 0.14, 0.04), clair)
		f.batch.box("trim", xf, c + Vector3(0, size.y / 2.0 + 0.12, 0.02), Vector3(size.x * 0.75, 0.24, 0.01), Color(0.5, 0.5, 0.52))
		f._glass(xf, c + Vector3(0, size.y / 2.0 + 0.11, 0.035), Vector2(size.x * 0.7, 0.2), 2, on, lumiere)
	else:
		f.batch.box("trim", xf, c + Vector3(0, size.y / 2.0 + 0.06, 0.02), Vector3(size.x + 0.18, 0.1, 0.05), clair)


## Un lampadaire noir à lanterne, le pied en `at`, posé au sol.
static func _lampadaire(f, xf: Transform3D, at: Vector3) -> void:
	var noir := Color(0.12, 0.12, 0.13)
	f.batch.box("trim", xf, at + Vector3(0, 0.06, 0), Vector3(0.16, 0.12, 0.16), noir)
	f.batch.box("trim", xf, at + Vector3(0, 0.8, 0), Vector3(0.06, 1.6, 0.06), noir)
	f.batch.box("trim", xf, at + Vector3(0, 1.72, 0), Vector3(0.22, 0.26, 0.22), Color(0.15, 0.15, 0.16))
	f.batch.box("trim", xf, at + Vector3(0, 1.88, 0), Vector3(0.26, 0.06, 0.26), noir)
	for a in [0.0, PI / 2.0, PI, -PI / 2.0]:
		var lxf := xf * Transform3D(Basis(Vector3.UP, a), at)
		f._glass(lxf, Vector3(0, 1.7, 0.115), Vector2(0.16, 0.18), 0, true, Color(1.0, 0.85, 0.6))
	f.glows.append([xf * (at + Vector3(0, 1.72, 0)), Color(1.0, 0.85, 0.6)])


## Un toit conique, à facettes, posé sur `base` (le centre du cercle) ; `phase` tourne la première
## arête (PI / 4 avec quatre pans : une pyramide posée droite sur un carré).
static func _cone(f, xf: Transform3D, base: Vector3, radius: float, height: float, color: Color, sides := 12, phase := 0.0) -> void:
	var apex := base + Vector3(0, height, 0)
	for i in sides:
		var a0 := TAU * i / sides + phase
		var a1 := TAU * (i + 1) / sides + phase
		var p0 := base + Vector3(cos(a0) * radius, 0, sin(a0) * radius)
		var p1 := base + Vector3(cos(a1) * radius, 0, sin(a1) * radius)
		var am := (a0 + a1) / 2.0
		var n := Vector3(cos(am) * height, radius, sin(am) * height).normalized()
		f.batch.tri("roof", xf, p0, apex, p1, n, color)

## Les moellons apparents d'un mur de pierre : des pierres de tailles diverses, un peu plus claires ou
## plus sombres que le mur, posées en applique sur la face avant.
static func _moellons(f, xf: Transform3D, w: float, h: float, mur: Color) -> void:
	var n := int(w * h * 7.0)
	for i in n:
		var pw: float = f.rng.randf_range(0.1, 0.26)
		var ph: float = f.rng.randf_range(0.06, 0.13)
		var x: float = f.rng.randf_range(-w / 2.0 + 0.3, w / 2.0 - 0.3)
		var y: float = f.rng.randf_range(BASE_H + 0.05, h - 0.1)
		var t: float = f.rng.randf()
		var c := mur.darkened(0.18).lerp(mur.lightened(0.2), t)
		f.batch.box("trim", xf, Vector3(x, y, 0.008), Vector3(pw, ph, 0.016), c)


## Un arc en plein cintre de claveaux clairs, centré en `c` (la naissance de l'arc), de rayon `r`.
static func _arc(f, xf: Transform3D, c: Vector3, r: float, clair: Color) -> void:
	for k in 5:
		var a := PI * (k + 0.5) / 5.0
		var p := c + Vector3(r * 0.8 * cos(a), r * 0.8 * sin(a), 0.0)
		f.batch.box("trim", xf * Transform3D(Basis(Vector3.BACK, a - PI / 2.0), p), Vector3.ZERO, Vector3(0.3, 0.14, 0.04), clair)
