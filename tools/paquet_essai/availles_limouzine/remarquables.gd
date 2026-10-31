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


## Les murs contre lesquels l'habitant bute, pour un lieu dont l'emprise cadastrale ne vaut pas :
## une liste de segments [x1, z1, x2, z2] au sol, en unités du bourg, ou une liste vide pour
## laisser l'emprise faire. La porte des Cavaliers laisse passer la rue sous sa voûte.
static func murs(id: String, b: Dictionary, hauteur: Callable) -> Array:
	if id == "porte_cavaliers":
		return _murs_porte_cavaliers(b, hauteur)
	if id == "porte_riviere":
		return _murs_porte_riviere(b, hauteur)
	return []


static func construire(id: String, f, b: Dictionary, hauteur: Callable) -> bool:
	match id:
		"hotel":
			_chatellenie(f, b, hauteur)
			return true
		"adrien_bernard":
			_adrien_bernard(f, b, hauteur)
			return true
		"maison_8":
			_maison_8(f, b, hauteur)
			return true
		"maison_6":
			_maison_6(f, b, hauteur)
			return true
		"coop":
			_coop(f, b, hauteur)
			return true
		"pharmacie":
			_pharmacie(f, b, hauteur)
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
		"eglise":
			load("res://communes/availles_limouzine/eglise.gd").construire(f, b, hauteur)
			return true
		"porte_riviere":
			# Le logis lui-même reste une maison du bourg, mais de moellons ; la porte, ses tours et le
			# pigeonnier s'y ajoutent.
			b["mur"] = "pierre"
			_porte_riviere(f, b, hauteur)
			return false
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


# --- La place Adrien-Bernard : le 10, le 8, le 6, la Coop, la pharmacie ----------------------------
## Le bas de la place, à l'est, d'après les vues de la rue : du nord au sud le 10 et sa dépendance, le
## 8 aux volets bleus, le 6 sous son toit à la Mansart, la Coop et son tabac au coin de la rue
## Principale. En face, au nord-ouest, la pharmacie. Le parc du 10 sera traité à part.

## Le côté du repère d'une façade (+1 : +X) où se trouve le point p.
static func _cote_vers(fa: Dictionary, p: Vector2) -> float:
	var plus: Vector2 = fa.a if fa.sens > 0.0 else fa.c
	var m: Vector2 = (fa.a + fa.c) / 2.0
	return 1.0 if (plus - m).dot(p - m) > 0.0 else -1.0


# --- Le 10 place Adrien-Bernard ---------------------------------------------------------------------
## D'après la vue de la rue : une maison bourgeoise à l'enduit beige et aux chaînes d'angle harpées de
## pierre blanche, deux niveaux de trois travées, les volets blancs, des corniches sur les fenêtres de
## l'étage, un toit d'ardoise à quatre pans, sa cheminée et son épi ; au nord, la dépendance basse sous
## son appentis d'ardoise, avec sa porte ; puis la palissade blanche entre ses piliers de pierre, le mur
## bas du jardin et le lampadaire du trottoir. La façade regarde la place, à l'ouest.
static func _adrien_bernard(f, b: Dictionary, hauteur: Callable) -> void:
	var fa := _facade(b, Vector2(-20.0, -22.5), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = clampf(fa.w, 4.4, 5.4)
	var nord := _cote_vers(fa, Vector2(-17.6, -26.0))
	var beige := Color(0.87, 0.8, 0.68)
	var blanc := Color(0.95, 0.95, 0.93)
	var ardoise := Color(0.34, 0.37, 0.43)
	var wm := 3.4
	var dm := 3.4
	var wa := w - wm
	# Le corps de logis, au sud, accolé au 8.
	var mxf := xf * Transform3D(Basis(), Vector3(-nord * (w / 2.0 - wm / 2.0), 0, 0))
	_socle(f, mxf, wm, dm, fa.socle, beige.darkened(0.3))
	var logis: Dictionary = f.house(mxf, {
		"w": wm, "d": dm, "floors": 2, "wall": beige, "shutter": blanc, "roof": ardoise, "roof_kind": "hip",
		"lit": 0.0, "chimney": true, "door": "center", "back": false,
	})
	var hm: float = logis.h
	_chaines(f, mxf * Transform3D(Basis(), Vector3(0, 0, 0.012)), wm + 0.02, hm, blanc)
	# Les corniches au-dessus des fenêtres de l'étage, une clé au milieu.
	var bay_w := (wm - 0.2) / 3.0
	for i in 3:
		var x := -wm / 2.0 + 0.1 + bay_w * (i + 0.5)
		f.batch.box("trim", mxf, Vector3(x, 2.5, 0.05), Vector3(0.74, 0.06, 0.1), blanc)
		f.batch.box("trim", mxf, Vector3(x, 2.44, 0.04), Vector3(0.62, 0.06, 0.06), blanc.darkened(0.04))
		f.batch.box("trim", mxf, Vector3(x, 2.4, 0.05), Vector3(0.1, 0.12, 0.06), blanc)
	# L'épi de faîtage, au sommet de la pyramide d'ardoise.
	var top := hm + 0.1 + (dm / 2.0 + 0.16) * tan(deg_to_rad(28.0))
	f.batch.box("trim", mxf, Vector3(0, top + 0.22, -dm / 2.0), Vector3(0.05, 0.44, 0.05), Color(0.2, 0.2, 0.22))
	f.batch.cylinder("trim", mxf, Vector3(0, top + 0.1, -dm / 2.0), 0.07, 0.14, Color(0.25, 0.25, 0.28), 8)
	# La dépendance basse, au nord, sous son appentis d'ardoise qui penche vers la place.
	var axf := xf * Transform3D(Basis(), Vector3(nord * (w / 2.0 - wa / 2.0), 0, -0.15))
	var ha := 1.45
	_socle(f, axf, wa, 2.4, fa.socle, beige.darkened(0.3))
	f.batch.box("wall", axf, Vector3(0, ha / 2.0, -1.2), Vector3(wa, ha, 2.4), beige.lightened(0.04))
	f.batch.box("trim", axf, Vector3(0, BASE_H / 2.0, -1.2), Vector3(wa + 0.05, BASE_H, 2.45), beige.darkened(0.3))
	f.batch.box("wall", axf, Vector3(0, ha + 0.25, -2.0), Vector3(wa, 0.5, 0.8), beige.lightened(0.04))
	var pente := atan2(0.55, 2.5)
	f.batch.box_tilted("roof", axf, Vector3(0, ha + 0.3, -1.15), Vector3(wa + 0.2, 0.06, 2.75), pente, ardoise)
	f._door(axf, -nord * 0.2, Color(0.55, 0.5, 0.45), blanc, false)
	f._window(axf, Vector3(nord * 0.45, 0.42, 0), Vector2(0.4, 0.55), blanc, blanc, 0.0)
	for i in 7:
		var vx: float = nord * (wa / 2.0 - 0.15) + f.rng.randf_range(-0.12, 0.12)
		f.batch.box("trim", axf, Vector3(vx, 0.25 + i * 0.18, 0.025), Vector3(0.12 + f.rng.randf() * 0.14, 0.14 + f.rng.randf() * 0.1, 0.05), Color(0.26, 0.42, 0.2).lerp(Color(0.45, 0.52, 0.22), f.rng.randf()))
	# La palissade blanche entre ses piliers de pierre, puis le mur bas du jardin.
	var x0 := nord * (w / 2.0 + 0.05)
	var pilier := Color(0.86, 0.84, 0.78)
	for p in 3:
		var px: float = x0 + nord * (0.15 + p * 1.1)
		f.batch.box("wall", xf, Vector3(px, 0.45, 0.1), Vector3(0.3, 0.9, 0.3), pilier)
		f.batch.box("trim", xf, Vector3(px, 0.93, 0.1), Vector3(0.36, 0.07, 0.36), pilier.lightened(0.1))
		if p < 2:
			f.batch.box("wall", xf, Vector3(px + nord * 0.55, 0.12, 0.1), Vector3(0.8, 0.24, 0.24), pilier.darkened(0.08))
			for i in 7:
				f.batch.box("trim", xf, Vector3(px + nord * (0.22 + i * 0.11), 0.48, 0.1), Vector3(0.05, 0.5, 0.03), blanc)
			f.batch.box("trim", xf, Vector3(px + nord * 0.55, 0.62, 0.1), Vector3(0.8, 0.04, 0.03), blanc)
	f.garden_wall(xf * Vector3(x0 + nord * 2.4, 0, 0.1), xf * Vector3(x0 + nord * 5.5, 0, 0.1), 0.55, Color(0.8, 0.78, 0.72))
	_lampadaire(f, xf, Vector3(x0 + nord * 1.0, 0, 0.9))


# --- Le 8 place Adrien-Bernard ----------------------------------------------------------------------
## Une maison plus simple, à l'enduit crème, deux niveaux, les volets et la porte vitrée peints en bleu,
## un toit d'ardoise à quatre pans. Elle tient entre le 10 au nord et le 6 au sud.
static func _maison_8(f, b: Dictionary, hauteur: Callable) -> void:
	var fa := _facade(b, Vector2(-20.0, -18.6), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = clampf(fa.w, 2.6, 3.2)
	var creme := Color(0.9, 0.86, 0.77)
	var bleu := Color(0.36, 0.56, 0.74)
	var d: float = clampf(fa.d, 2.6, 3.4)
	_socle(f, xf, w, d, fa.socle, creme.darkened(0.3))
	f.house(xf, {
		"w": w, "d": d, "floors": 2, "wall": creme, "shutter": bleu, "roof": Color(0.36, 0.39, 0.45), "roof_kind": "hip",
		"lit": 0.0, "chimney": true, "door": "left" if _cote_vers(fa, Vector2(-17.6, -26.0)) < 0.0 else "right", "back": false,
	})


# --- Le 6 place Adrien-Bernard ----------------------------------------------------------------------
## Une maison de deux niveaux sous un comble à la Mansart : le brisis d'ardoise presque droit, percé de
## deux lucarnes, le terrasson plat au-dessus, le bandeau de zinc entre les deux ; l'enduit gris clair,
## les volets gris, une lanterne de fer à potence près de la porte.
static func _maison_6(f, b: Dictionary, hauteur: Callable) -> void:
	var fa := _facade(b, Vector2(-20.0, -15.7), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = clampf(fa.w, 2.6, 3.2)
	var d: float = clampf(fa.d, 2.4, 3.2)
	var mur := Color(0.86, 0.84, 0.79)
	var clair := mur.lightened(0.12)
	var volet := Color(0.66, 0.68, 0.68)
	var ardoise := Color(0.33, 0.36, 0.42)
	var h := FLOOR_H * 2.0 + 0.15
	_socle(f, xf, w, d, fa.socle, mur.darkened(0.3))
	f.batch.box("wall", xf, Vector3(0, h / 2.0, -d / 2.0), Vector3(w, h, d), mur)
	f.batch.box("trim", xf, Vector3(0, BASE_H / 2.0, -d / 2.0), Vector3(w + 0.05, BASE_H, d + 0.05), mur.darkened(0.25))
	f.batch.box("trim", xf, Vector3(0, FLOOR_H + 0.02, 0.01), Vector3(w, 0.07, 0.04), clair)
	f.batch.box("trim", xf, Vector3(0, h + 0.05, -d / 2.0), Vector3(w + 0.16, 0.1, d + 0.16), clair)
	_chaines(f, xf, w, h, clair)
	var porte := -1.0 if _cote_vers(fa, Vector2(-17.6, -26.0)) < 0.0 else 1.0
	var bays := 3
	var bw := (w - 0.2) / bays
	for i in bays:
		var x := -w / 2.0 + 0.1 + bw * (i + 0.5)
		if (porte < 0.0 and i == 0) or (porte > 0.0 and i == bays - 1):
			f._door(xf, x, Color(0.4, 0.36, 0.32), clair, false)
			_applique(f, xf, Vector3(x - porte * 0.45, 1.25, 0))
		else:
			f._window(xf, Vector3(x, 0.42, 0), Vector2(0.48, 0.7), volet, clair, 0.0)
		f._window(xf, Vector3(x, FLOOR_H + 0.32, 0), Vector2(0.48, 0.74), volet, clair, 0.0)
	# Le brisis : quatre pans raides, de l'égout au bandeau de zinc.
	var y0 := h + 0.1
	var y1 := y0 + 0.95
	var o := 0.08
	var i0 := 0.32
	var pts := [Vector3(-w / 2.0 - o, y0, o), Vector3(w / 2.0 + o, y0, o), Vector3(w / 2.0 + o, y0, -d - o), Vector3(-w / 2.0 - o, y0, -d - o)]
	var hauts := [Vector3(-w / 2.0 + i0, y1, -i0), Vector3(w / 2.0 - i0, y1, -i0), Vector3(w / 2.0 - i0, y1, -d + i0), Vector3(-w / 2.0 + i0, y1, -d + i0)]
	for k in 4:
		var a: Vector3 = pts[k]
		var c: Vector3 = pts[(k + 1) % 4]
		var nrm := (c - a).cross(hauts[k] - a).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		f.batch.quad("roof", xf, [a, c, hauts[(k + 1) % 4], hauts[k]], nrm, ardoise)
	f.batch.box("trim", xf, Vector3(0, y1, -d / 2.0), Vector3(w - 2.0 * i0 + 0.08, 0.06, d - 2.0 * i0 + 0.08), Color(0.6, 0.62, 0.64))
	# Le terrasson, presque plat.
	f._roof(xf * Transform3D(Basis(), Vector3(0, 0, -i0 - 0.16)), w - 2.0 * i0 - 0.32, d - 2.0 * i0 - 0.32, y1 - 0.06, ardoise.lightened(0.05), mur, "hip")
	# Deux lucarnes dans le brisis, au-dessus des fenêtres de l'étage.
	for x in [-bw / 2.0 - 0.05, bw / 2.0 + 0.05]:
		var lz := -0.12
		f.batch.box("wall", xf, Vector3(x, y0 + 0.42, lz - 0.2), Vector3(0.56, 0.62, 0.4), clair)
		f._glass(xf, Vector3(x, y0 + 0.4, lz + 0.005), Vector2(0.32, 0.42), 0, false, Color(1.0, 0.8, 0.5))
		var lxf := xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x, y0 + 0.73, lz - 0.2))
		f.batch.quad("roof", lxf, [Vector3(-0.24, 0, -0.32), Vector3(-0.24, 0, 0.32), Vector3(0, 0.2, 0.32), Vector3(0, 0.2, -0.32)], Vector3(-0.6, 0.8, 0), ardoise)
		f.batch.quad("roof", lxf, [Vector3(0.24, 0, 0.32), Vector3(0.24, 0, -0.32), Vector3(0, 0.2, -0.32), Vector3(0, 0.2, 0.32)], Vector3(0.6, 0.8, 0), ardoise)
		f.batch.tri("wall", xf, Vector3(x - 0.28, y0 + 0.73, lz), Vector3(x + 0.28, y0 + 0.73, lz), Vector3(x, y0 + 0.93, lz), Vector3(0, 0, 1), clair)


# --- La Coop et le tabac ----------------------------------------------------------------------------
## Le bâtiment récent du coin de la rue Principale : l'enduit blanc cassé, au rez-de-chaussée la
## vitrine et la porte vitrée de la supérette sous la bannière rouge « Coop », deux portes de garage
## grises ; à l'étage le long balcon en terrasse à garde-corps blanc devant trois portes-fenêtres ; un
## toit de tuiles à quatre pans, très plat ; la carotte rouge du tabac à l'angle.
static func _coop(f, b: Dictionary, hauteur: Callable) -> void:
	var fa := _facade(b, Vector2(-20.0, -12.5), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = clampf(fa.w, 3.8, 4.6)
	var d: float = clampf(fa.d, 3.5, 6.0)
	var mur := Color(0.92, 0.9, 0.85)
	var blanc := Color(0.96, 0.96, 0.95)
	var rouge := Color(0.78, 0.12, 0.14)
	var gris := Color(0.62, 0.64, 0.66)
	var gh := 1.5
	var h := gh + FLOOR_H + 0.1
	var sud := _cote_vers(fa, Vector2(-17.0, -6.0))
	_socle(f, xf, w, d, fa.socle, mur.darkened(0.3))
	f.batch.box("wall", xf, Vector3(0, h / 2.0, -d / 2.0), Vector3(w, h, d), mur)
	f.batch.box("trim", xf, Vector3(0, BASE_H / 2.0, -d / 2.0), Vector3(w + 0.05, BASE_H, d + 0.05), mur.darkened(0.3))
	f.batch.box("trim", xf, Vector3(0, h + 0.04, -d / 2.0), Vector3(w + 0.2, 0.08, d + 0.2), blanc)
	f._roof(xf, w, d, h, Color(0.78, 0.48, 0.32), mur, "hip")
	# Côté nord, la supérette : la vitrine, la porte vitrée, la bannière rouge.
	var xs := -sud * w / 4.0
	f.batch.box("trim", xf, Vector3(xs, 0.7, 0.01), Vector3(w / 2.0 - 0.2, 1.0, 0.03), Color(0.25, 0.25, 0.27))
	f._glass(xf, Vector3(xs - sud * 0.25, 0.7, 0.03), Vector2(w / 2.0 - 0.9, 0.9), 0, true, Color(1.0, 0.92, 0.75))
	f._glass(xf, Vector3(xs + sud * (w / 4.0 - 0.45), 0.6, 0.03), Vector2(0.44, 0.92), 0, true, Color(1.0, 0.92, 0.75))
	f.batch.box("trim", xf, Vector3(xs, 1.33, 0.05), Vector3(w / 2.0 - 0.1, 0.24, 0.06), rouge)
	_lettres(f, xf, Vector3(xs, 1.33, 0.09), "Coop", 64, 0.004, blanc, w / 2.0 - 0.6)
	# Côté sud, les deux portes de garage.
	for k in 2:
		var xg := sud * (0.25 + w / 8.0 + k * (w / 4.0 - 0.05))
		f.batch.box("trim", xf, Vector3(xg, 0.6, 0.015), Vector3(w / 4.0 - 0.25, 1.0, 0.03), gris)
		for i in 5:
			f.batch.box("trim", xf, Vector3(xg, 0.2 + i * 0.2, 0.035), Vector3(w / 4.0 - 0.3, 0.02, 0.01), gris.darkened(0.15))
	# L'étage : le balcon en terrasse, son garde-corps blanc, trois portes-fenêtres.
	f.batch.box("trim", xf, Vector3(0, gh + 0.03, 0.3), Vector3(w + 0.1, 0.1, 0.6), blanc)
	f.batch.box("trim", xf, Vector3(0, gh + 0.5, 0.58), Vector3(w + 0.1, 0.04, 0.04), blanc)
	for i in 17:
		f.batch.box("trim", xf, Vector3(-w / 2.0 + i * w / 16.0, gh + 0.29, 0.58), Vector3(0.03, 0.44, 0.03), blanc)
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(s * (w / 2.0 + 0.02), gh + 0.29, 0.3), Vector3(0.03, 0.44, 0.58), blanc)
	for i in 3:
		var x := (i - 1) * w / 3.0
		f.batch.box("trim", xf, Vector3(x, gh + 0.55, 0.01), Vector3(0.66, 1.04, 0.03), blanc)
		f._glass(xf, Vector3(x, gh + 0.55, 0.03), Vector2(0.54, 0.96), 0, false, Color(1.0, 0.8, 0.5))
	# La carotte du tabac, en drapeau à l'angle nord.
	var cx := -sud * (w / 2.0 - 0.1)
	f.batch.box("trim", xf, Vector3(cx, gh + 0.1, 0.25), Vector3(0.04, 0.04, 0.5), Color(0.15, 0.15, 0.16))
	var cxf := xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(cx, gh - 0.22, 0.42))
	f.batch.box("trim", cxf * Transform3D(Basis(Vector3.BACK, PI / 4.0), Vector3.ZERO), Vector3.ZERO, Vector3(0.36, 0.36, 0.06), rouge)
	_lettres(f, cxf, Vector3(0, 0, 0.04), "TABAC", 32, 0.0035, blanc, 0.36)


# --- La pharmacie -----------------------------------------------------------------------------------
## D'après la vue de la place : un long bâtiment blanc à un niveau haut, sous un toit de tuiles à
## génoise. À l'ouest, plus haut que la place, la pharmacie : on y monte par un escalier à rampe de fer
## posé contre la façade, sur son mur de béton ; la vitrine, la porte vitrée et, dressé au-dessus de
## l'égout, le bandeau blanc « Pharmacie » et ses croix vertes. À l'est, au niveau de la place, la
## boutique de matériel médical : ses lettres vertes sur la façade, trois fenêtres à barreaux au-dessus,
## deux portes à encadrement brun ; la croix verte en drapeau à l'angle.
static func _pharmacie(f, b: Dictionary, hauteur: Callable) -> void:
	var r: Array = b.rect
	var u := Vector2(cos(r[4]), sin(r[4]))
	var v := Vector2(-u.y, u.x) * float(b.face)
	var w: float = r[2]
	var d: float = r[3]
	var avant: Vector2 = Vector2(r[0], r[1]) + v * (d / 2.0)
	var y: float = hauteur.call(avant.x + v.x * 0.5, avant.y + v.y * 0.5)
	var xf := Transform3D(Basis(Vector3.UP, atan2(v.x, v.y)), Vector3(avant.x, y, avant.y))
	# Dans ce repère, +X est l'est (le matériel médical), -X l'ouest (la pharmacie, plus haut).
	var est := _cote_vers({"a": avant + u, "c": avant - u, "sens": 1.0}, Vector2(-26.0, -30.0))
	var blanc := Color(0.95, 0.95, 0.93)
	var vert := Color(0.16, 0.55, 0.3)
	var brun := Color(0.45, 0.24, 0.14)
	var h := 2.2
	var po: Vector2 = avant - u * est * (w / 2.0 - 0.3) + v * 0.5
	var palier: float = maxf(0.45, hauteur.call(po.x, po.y) - y + 0.15)
	f.batch.box("wall", xf, Vector3(0, (h - 1.0) / 2.0, -d / 2.0), Vector3(w, h + 1.0, d), blanc)
	f.batch.box("trim", xf, Vector3(0, BASE_H / 2.0 - 0.2, 0.0), Vector3(w + 0.04, BASE_H + 0.4, 0.04), blanc.darkened(0.12))
	f._roof(xf, w, d, h, Color(0.78, 0.45, 0.3), blanc, "gable")
	# La génoise : deux rangs de tuiles blanches sous l'égout.
	for k in 2:
		f.batch.box("trim", xf, Vector3(0, h - 0.04 + k * 0.07, 0.04 + k * 0.05), Vector3(w + 0.06 + k * 0.1, 0.06, 0.08), blanc.darkened(0.05 * k))
	# L'ouest : la pharmacie, sur son palier.
	var xp := -est * w * 0.3
	var lp := w * 0.36
	f.batch.box("wall", xf, Vector3(xp, palier / 2.0 - 0.25, 0.5), Vector3(lp, palier + 0.5, 1.0), Color(0.72, 0.7, 0.66))
	f.batch.box("trim", xf, Vector3(xp, palier + 0.02, 0.5), Vector3(lp, 0.06, 1.0), Color(0.8, 0.78, 0.74))
	for i in 3:
		var x: float = xp + (i - 1) * lp / 3.2
		f.batch.box("trim", xf, Vector3(x, palier + 0.6, 0.01), Vector3(0.9, 1.05, 0.03), Color(0.3, 0.3, 0.32))
		f._glass(xf, Vector3(x, palier + 0.6, 0.03), Vector2(0.78, 0.95), 0, true, Color(0.9, 1.0, 0.92))
	# La rampe de l'escalier, et l'escalier qui descend vers l'est le long de la façade.
	for i in 13:
		f.batch.box("trim", xf, Vector3(xp - lp / 2.0 + 0.1 + i * (lp - 0.2) / 12.0, palier + 0.27, 0.98), Vector3(0.025, 0.5, 0.025), Color(0.3, 0.3, 0.3))
	f.batch.box("trim", xf, Vector3(xp, palier + 0.52, 0.98), Vector3(lp, 0.03, 0.03), Color(0.3, 0.3, 0.3))
	var n := int(ceil(palier / 0.15))
	var x0: float = xp + est * lp / 2.0
	for k in n:
		var hk: float = palier - k * palier / n
		f.batch.box("trim", xf, Vector3(x0 + est * (0.15 + k * 0.28), hk / 2.0 - 0.1, 0.5), Vector3(0.3, hk + 0.2, 0.9), Color(0.74, 0.72, 0.68))
	f.batch.box_tilted("trim", xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x0 + est * (n * 0.14 + 0.15), palier / 2.0 + 0.5, 0.98)), Vector3.ZERO, Vector3(0.03, 0.03, n * 0.3), -est * atan2(palier, n * 0.28), Color(0.3, 0.3, 0.3))
	f._door(xf, x0 + est * 0.5, brun, blanc, false)
	# Le bandeau « Pharmacie » dressé au-dessus de l'égout, ses croix vertes.
	f.batch.box("wall", xf, Vector3(xp, h + 0.4, 0.06), Vector3(lp + 0.3, 0.7, 0.1), blanc)
	_lettres(f, xf, Vector3(xp, h + 0.4, 0.12), "Pharmacie", 64, 0.006, vert, lp - 0.8)
	for s in [-1.0, 1.0]:
		var cxp: float = xp + s * (lp / 2.0 - 0.15)
		f.batch.box("trim", xf, Vector3(cxp, h + 0.4, 0.12), Vector3(0.3, 0.1, 0.02), vert)
		f.batch.box("trim", xf, Vector3(cxp, h + 0.4, 0.12), Vector3(0.1, 0.3, 0.02), vert)
	# L'est : le matériel médical.
	var xm := est * w * 0.22
	_lettres(f, xf, Vector3(xm, 1.35, 0.03), "Hospitalisation à domicile · Matériel Médical", 64, 0.005, vert, w * 0.5)
	for i in 3:
		var x: float = xm + (i - 1) * w * 0.15
		f.batch.box("trim", xf, Vector3(x, 1.75, 0.01), Vector3(0.42, 0.5, 0.03), brun.darkened(0.3))
		for k in 6:
			f.batch.box("trim", xf, Vector3(x - 0.17 + k * 0.068, 1.75, 0.03), Vector3(0.02, 0.48, 0.02), Color(0.15, 0.15, 0.16))
	for p in [[xm - est * w * 0.08, 0.5], [xm + est * w * 0.15, 0.9]]:
		f.batch.box("trim", xf, Vector3(p[0], 0.55, 0.015), Vector3(p[1] + 0.12, 1.06, 0.03), brun)
		f._glass(xf, Vector3(p[0], 0.55, 0.035), Vector2(p[1], 0.94), 0, true, Color(1.0, 0.9, 0.75))
	# La croix verte, en drapeau à l'angle est.
	var cx := est * (w / 2.0 - 0.05)
	f.batch.box("trim", xf, Vector3(cx, 1.9, 0.25), Vector3(0.05, 0.05, 0.5), Color(0.2, 0.2, 0.2))
	var cxf := xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(cx, 1.9, 0.6))
	f.batch.box("trim", cxf, Vector3.ZERO, Vector3(0.6, 0.2, 0.08), vert.lightened(0.15))
	f.batch.box("trim", cxf, Vector3.ZERO, Vector3(0.2, 0.6, 0.08), vert.lightened(0.15))


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
	var d := 4.0
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
	# La maison : moellons apparents, soubassement, cordon, chaînes, toit à quatre pans, cheminée.
	var h := BASE_H + 2.0 * FLOOR_H
	_socle(f, xf, w, d, fa.socle, joint)
	f.batch.box("wall", xf, Vector3(0, h / 2.0, -d / 2.0), Vector3(w, h, d), pierre)
	f.batch.box("trim", xf, Vector3(0, BASE_H / 2.0, -d / 2.0), Vector3(w + 0.05, BASE_H, d + 0.05), joint)
	f.batch.box("trim", xf, Vector3(0, BASE_H + FLOOR_H + 0.02, 0.01), Vector3(w, 0.06, 0.04), clair)
	_moellons(f, xf, w, h, pierre)
	_chaines(f, xf, w, h, clair)
	f._roof(xf, w, d, h, tuile, pierre, "hip")
	var top := h + 0.1 + d * 0.5 * tan(deg_to_rad(28.0))
	f.batch.box("wall", xf, Vector3(-ouest * (w / 2.0 - 0.7), top - 0.25, -d * 0.4), Vector3(0.34, 0.9, 0.3), pierre.darkened(0.08))
	f.batch.box("trim", xf, Vector3(-ouest * (w / 2.0 - 0.7), top + 0.22, -d * 0.4), Vector3(0.42, 0.07, 0.38), clair)
	# Sur la place : la porte côté est, les fenêtres à volets blancs et leurs géraniums.
	var xs := [-ouest * 1.5, -ouest * 0.45, ouest * 0.7]
	f._door(xf, xs[0], blanc.darkened(0.1), clair, false)
	for x in [xs[1], xs[2]]:
		f._window(xf, Vector3(x, BASE_H + 0.3, 0), Vector2(0.5, 0.78), blanc, clair, 0.2)
	for x in xs:
		f._window(xf, Vector3(x, BASE_H + FLOOR_H + 0.3, 0), Vector2(0.5, 0.78), blanc, clair, 0.2)
	# Le flanc ouest de la maison, celui qu'on voit en arrivant de la rue des Cavaliers : la porte
	# blanche et une fenêtre en bas, une fenêtre à volets blancs à l'étage, entre l'angle et la tour.
	var oxf := xf * Transform3D(Basis(Vector3.UP, ouest * PI / 2.0), Vector3(ouest * w / 2.0, 0, -0.9))
	_moellons(f, oxf, 1.8, h, pierre)
	f._door(oxf, -0.45, blanc.darkened(0.1), clair, false)
	f._window(oxf, Vector3(0.45, BASE_H + 0.3, 0), Vector2(0.44, 0.7), blanc, clair, 0.2)
	f._window(oxf, Vector3(0.0, BASE_H + FLOOR_H + 0.3, 0), Vector2(0.5, 0.78), blanc, clair, 0.2)
	# Le mur de la porte, en retrait, dans le prolongement du flanc ouest : la rue des Cavaliers le
	# traverse sous sa voûte, derrière la maison, du carrefour au sud-ouest vers la ruelle au nord-est.
	var pw := 1.5
	var pxf := xf * Transform3D(Basis(), Vector3(ouest * (w / 2.0 + 0.1 + pw / 2.0), 0, 0))
	var z0 := -2.7
	var z1 := -6.6
	var zc := -5.0
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
	# Les moellons du mur, de part et d'autre du passage et au-dessus de lui, jamais dans le vide de la voûte.
	for part in [[z0, zs, 0.0], [zn, z1, 0.0], [zs, zn, passage_h]]:
		var za: float = part[0]
		var zb: float = part[1]
		var mxf := pxf * Transform3D(Basis(Vector3.UP, ouest * PI / 2.0), Vector3(ouest * pw / 2.0, 0, (za + zb) / 2.0))
		_moellons(f, mxf, za - zb, ph, pierre, part[2])
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
	_lampadaire(f, pxf, Vector3(ouest * (pw / 2.0 + 2.6), 0, zc + 2.6))


## Les murs de la porte des Cavaliers : la maison, le mur de la porte de part et d'autre du passage,
## la tour ; les mêmes mesures que le dessin.
static func _murs_porte_cavaliers(b: Dictionary, hauteur: Callable) -> Array:
	var fa := _facade(b, Vector2(51.0, 38.0), hauteur)
	var xf: Transform3D = fa.xf
	var w: float = clampf(fa.w, 4.0, 5.0)
	var d := 4.0
	var ouest: float = (1.0 if fa.a.x < fa.c.x else -1.0) * fa.sens
	var pw := 1.5
	var px: float = ouest * (w / 2.0 + 0.1 + pw / 2.0)
	var zc := -5.0
	var passage_w := 1.2
	var out: Array = []
	var rect := func(x0: float, x1: float, za: float, zb: float) -> void:
		var pts := [Vector3(x0, 0, za), Vector3(x1, 0, za), Vector3(x1, 0, zb), Vector3(x0, 0, zb)]
		for k in 4:
			var p: Vector3 = xf * pts[k]
			var q: Vector3 = xf * pts[(k + 1) % 4]
			out.append([p.x, p.z, q.x, q.z])
	rect.call(-w / 2.0, w / 2.0, 0.0, -d)
	rect.call(px - pw / 2.0, px + pw / 2.0, -2.7, zc + passage_w / 2.0)
	rect.call(px - pw / 2.0, px + pw / 2.0, zc - passage_w / 2.0, -6.6)
	var tc := Vector3(px + ouest * 0.5, 0, -2.7)
	for k in 8:
		var a0 := TAU * k / 8.0
		var a1 := TAU * (k + 1) / 8.0
		var p: Vector3 = xf * (tc + Vector3(cos(a0) * 0.85, 0, sin(a0) * 0.85))
		var q: Vector3 = xf * (tc + Vector3(cos(a1) * 0.85, 0, sin(a1) * 0.85))
		out.append([p.x, p.z, q.x, q.z])
	return out


# --- La porte de la Rivière -------------------------------------------------------------------------
## Le bas de la rue des Cavaliers, la « porte de la Ville » des promenades du bourg, d'après photos : au
## bout de la ruelle qui tourne, un mur de moellons percé d'un arc à peine brisé, l'herbe sur son arase,
## le lierre qui en retombe ; dans les piédroits, les rainures de l'ancienne herse ; côté rivière, une
## lanterne de fer de chaque côté de l'arc. À droite en venant de la rue, le pigeonnier : une tour
## carrée de moellons sous son toit de tuiles en pavillon à deux épis, la porte haute aux planches
## blanches, la lucarne à barreaux entre les panneaux de briques des boulins ; derrière lui, l'aile
## basse en avancée vers la rivière. Au-delà de l'arc, le quai du lavoir (abords.gd).
## Le repère : au milieu du passage, +Z vers la ville (le sud-ouest), +X vers le logis (l'est).
const RIVIERE_C := Vector2(69.05, -3.75)
const RIVIERE_A := Vector2(0.32, -0.95)


static func repere_riviere(hauteur: Callable) -> Transform3D:
	var n := -RIVIERE_A.normalized()
	return Transform3D(Basis(Vector3.UP, atan2(n.x, n.y)), Vector3(RIVIERE_C.x, hauteur.call(RIVIERE_C.x, RIVIERE_C.y) - 0.02, RIVIERE_C.y))


static func _porte_riviere(f, _b: Dictionary, hauteur: Callable) -> void:
	var xf := repere_riviere(hauteur)
	# Des moellons bruns irréguliers, aux joints sombres, comme sur les photos de la rue et de la rive.
	var pierre := Color(0.59, 0.51, 0.41)
	var joint := Color(0.4, 0.34, 0.27)
	var clair := Color(0.72, 0.63, 0.5)
	var tuile := Color(0.6, 0.38, 0.29)
	var blanc := Color(0.9, 0.9, 0.88)
	var brique := Color(0.82, 0.45, 0.3)
	var lierre := Color(0.36, 0.52, 0.2)
	var w := 2.6
	var d := 1.4
	var pw := 1.36
	var ps := 1.0
	var r := pw / 2.0
	var bas := 0.9
	# L'arc brisé : deux arcs de rayon R, centrés de part et d'autre de l'axe, qui se croisent.
	var R := pw * 0.78
	var phi := acos((R - r) / R)
	var cle := ps + R * sin(phi)
	var h := cle + 0.6
	var arc := func(s: float, k: int, n: int, ray: float) -> Array:
		var t := (k + 0.5) / n
		var a: float = phi * t if s > 0.0 else PI - phi * t
		return [Vector3(s * (r - R) + ray * cos(a), ps + ray * sin(a), 0), a]
	# Le mur de la porte : deux piédroits, le haut au-dessus de l'arc, sans chambre ni toit ; l'herbe et
	# les ronces sur son arase.
	var yb := cle + 0.2
	for s in [-1.0, 1.0]:
		var lp := w / 2.0 - pw / 2.0
		f.batch.box("wall", xf, Vector3(s * (pw / 2.0 + lp / 2.0), (yb - bas) / 2.0, 0), Vector3(lp, yb + bas, d), pierre)
	f.batch.box("wall", xf, Vector3(0, (yb + h) / 2.0, 0), Vector3(w, h - yb, d), pierre)
	f.batch.box("trim", xf, Vector3(0, h + 0.03, 0), Vector3(w + 0.04, 0.08, d + 0.04), joint)
	for i in 9:
		f.batch.box("trim", xf, Vector3(-w / 2.0 + 0.15 + i * 0.29 + f.rng.randf_range(-0.05, 0.05), h + 0.1 + f.rng.randf() * 0.06, f.rng.randf_range(-0.4, 0.4)), Vector3(0.3 + f.rng.randf() * 0.2, 0.14 + f.rng.randf() * 0.12, 0.4 + f.rng.randf() * 0.3), lierre.lerp(Color(0.5, 0.48, 0.3), f.rng.randf() * 0.5))
	# L'intrados de la voûte, par tranches, et les écoinçons au-dessus.
	var n := 6
	var l := 2.0 * R * sin(phi / n / 2.0)
	for s in [-1.0, 1.0]:
		for k in n:
			var q: Array = arc.call(s, k, n, R + 0.12)
			var a: float = q[1]
			f.batch.box("wall", xf * Transform3D(Basis(Vector3.BACK, a - PI / 2.0), q[0]), Vector3.ZERO, Vector3(l + 0.03, 0.24, d), joint.darkened(0.3))
			var c: Vector3 = arc.call(s, k, n, R)[0]
			if c.y + 0.2 < yb:
				f.batch.box("wall", xf, Vector3(c.x, (c.y + 0.2 + yb) / 2.0, 0), Vector3(l + 0.04, yb - c.y - 0.2, d), pierre)
	for face in [1.0, -1.0]:
		var fxf := xf * Transform3D(Basis(Vector3.UP, 0.0 if face > 0.0 else PI), Vector3(0, 0, face * d / 2.0))
		_moellons_bruns(f, fxf, w, h, pierre, -bas + 0.1)
		# Les claveaux de l'arc, à peine plus clairs que le mur, les piédroits harpés.
		for s in [-1.0, 1.0]:
			for k in 6:
				var q: Array = arc.call(s, k, 6, R + 0.13)
				f.batch.box("trim", fxf * Transform3D(Basis(Vector3.BACK, float(q[1]) - PI / 2.0), q[0] + Vector3(0, 0, 0.02)), Vector3.ZERO, Vector3(0.22, 0.28, 0.05), clair.lerp(pierre, 0.4 + 0.3 * float(k % 2)))
			var y := -0.2
			var k := 0
			while y < ps:
				f.batch.box("trim", fxf, Vector3(s * (r + 0.1 + (0.05 if k % 2 == 0 else 0.0)), y + 0.12, 0.02), Vector3(0.2 + (0.1 if k % 2 == 0 else 0.0), 0.22, 0.05), clair.lerp(pierre, 0.5))
				y += 0.24
				k += 1
	# Côté rivière, la lanterne de fer à gauche de l'arc, du côté du pigeonnier.
	var rv := xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -d / 2.0))
	_applique(f, rv, Vector3(-1.0, 1.7, 0))
	# Côté ville, le lierre qui retombe du mur, à droite de l'arc.
	var vl := xf * Transform3D(Basis(), Vector3(0, 0, d / 2.0))
	for i in 26:
		var x: float = f.rng.randf_range(0.75, w / 2.0 - 0.05)
		var y: float = f.rng.randf_range(maxf(0.3, h - 1.6 + (x - 0.75) * 0.6), h)
		f.batch.box("trim", vl, Vector3(x, y, 0.04 + f.rng.randf() * 0.04), Vector3(0.18 + f.rng.randf() * 0.2, 0.14 + f.rng.randf() * 0.16, 0.06), lierre.lerp(Color(0.5, 0.66, 0.26), f.rng.randf()))
	# Les rainures de la herse, dans les piédroits ; le pavé du passage.
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(s * (r - 0.01), ps / 2.0, 0.1), Vector3(0.04, ps + 0.1, 0.09), Color(0.12, 0.11, 0.1))
	f.batch.box("trim", xf, Vector3(0, -0.04, 0), Vector3(pw, 0.1, d + 0.4), joint.darkened(0.15))
	# Le pigeonnier, à droite de la porte vu de la rue : une tour carrée de moellons, un peu en retrait,
	# son toit de tuiles en pavillon, retroussé, à deux épis ; côté rue la porte haute aux planches
	# blanches et, sous le toit, la lucarne à barreaux entre les deux panneaux de briques des boulins.
	var tw := 1.6
	var th := 4.0
	var txf := xf * Transform3D(Basis(), Vector3(w / 2.0 + tw / 2.0 - 0.25, 0, -0.35))
	f.batch.box("wall", txf, Vector3(0, (th - bas) / 2.0, 0), Vector3(tw, th + bas, tw), pierre)
	for q in 4:
		var qxf := txf * Transform3D(Basis(Vector3.UP, q * PI / 2.0), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, 0, tw / 2.0))
		_moellons_bruns(f, qxf, tw, th, pierre.lightened(0.08), -bas)
		for s in [-1.0, 1.0]:
			var y := 0.0
			var k := 0
			while y < th - 0.2:
				f.batch.box("trim", qxf, Vector3(s * (tw / 2.0 - 0.12 + (0.0 if k % 2 == 0 else 0.04)), y + 0.13, 0.015), Vector3(0.24 - (0.0 if k % 2 == 0 else 0.08), 0.24, 0.03), clair.lerp(pierre, 0.45))
				y += 0.27
				k += 1
	var tv := txf * Transform3D(Basis(), Vector3(0, 0, tw / 2.0))
	f.batch.box("trim", tv, Vector3(0, th - 0.7, 0.02), Vector3(0.3, 0.42, 0.04), clair)
	f.batch.box("trim", tv, Vector3(0, th - 0.7, 0.03), Vector3(0.18, 0.3, 0.03), Color(0.1, 0.09, 0.08))
	for i in 3:
		f.batch.box("trim", tv, Vector3(-0.05 + i * 0.05, th - 0.7, 0.045), Vector3(0.015, 0.3, 0.02), blanc)
	for s in [-1.0, 1.0]:
		f.batch.box("trim", tv, Vector3(s * 0.48, th - 0.72, 0.02), Vector3(0.5, 0.28, 0.04), brique)
		for i in 3:
			f.batch.box("trim", tv, Vector3(s * 0.48 + (i - 1) * 0.15, th - 0.72, 0.035), Vector3(0.06, 0.16, 0.03), Color(0.12, 0.08, 0.06))
	f.batch.box("trim", tv, Vector3(0, 2.0, 0.02), Vector3(0.52, 0.86, 0.04), clair)
	f.batch.box("trim", tv, Vector3(0, 1.97, 0.035), Vector3(0.4, 0.78, 0.03), blanc)
	for i in 4:
		f.batch.box("trim", tv, Vector3(-0.1 + i * 0.07, 2.27, 0.05), Vector3(0.02, 0.14, 0.02), Color(0.15, 0.14, 0.13))
	var rxf := txf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -tw / 2.0))
	f.batch.box("trim", rxf, Vector3(-0.2, th - 0.8, 0.02), Vector3(0.18, 0.24, 0.03), Color(0.1, 0.09, 0.08))
	f.batch.box("trim", rxf, Vector3(-0.2, th - 0.8, 0.01), Vector3(0.28, 0.34, 0.02), clair)
	_pavillon(f, txf * Transform3D(Basis(), Vector3(0, th, 0)), tw / 2.0 + 0.12, 1.25, tuile)
	# Côté rivière, au-delà du pigeonnier, l'aile basse de moellons, sa lucarne, son toit de tuiles.
	var aw := 1.2
	var ah := 2.6
	var axf := xf * Transform3D(Basis(), Vector3(w / 2.0 + tw - 0.25 + aw / 2.0, 0, -0.6))
	f.batch.box("wall", axf, Vector3(0, (ah - bas - 0.6) / 2.0, 0), Vector3(aw, ah + bas + 0.6, 1.8), pierre.darkened(0.06))
	var bxf := axf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 0.9))
	_moellons(f, bxf, aw, ah, pierre.darkened(0.06), -bas)
	f.batch.box("trim", bxf, Vector3(-0.1, ah - 0.75, 0.01), Vector3(0.18, 0.26, 0.03), Color(0.1, 0.09, 0.08))
	f.batch.box("trim", bxf, Vector3(-0.1, ah - 0.75, 0.02), Vector3(0.28, 0.36, 0.02), clair)
	f._roof(axf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, 0, aw / 2.0)), 1.8, aw, ah, tuile, pierre, "hip")


## Des moellons bruns et ocre, serrés, de tailles très diverses, sur un mur aux joints sombres.
static func _moellons_bruns(f, xf: Transform3D, w: float, h: float, mur: Color, y0: float) -> void:
	var bas: float = maxf(BASE_H, y0) + 0.04
	var n := int(w * (h - bas) * 16.0)
	for i in n:
		var pw: float = f.rng.randf_range(0.09, 0.24)
		var ph: float = f.rng.randf_range(0.06, 0.14)
		var t: float = f.rng.randf()
		var c := Color(0.62, 0.53, 0.42).lerp(Color(0.8, 0.7, 0.54), t)
		if f.rng.randf() < 0.15:
			c = Color(0.62, 0.45, 0.33)
		f.batch.box("trim", xf, Vector3(f.rng.randf_range(-w / 2.0 + 0.12, w / 2.0 - 0.12), f.rng.randf_range(bas, h - 0.08), 0.01), Vector3(pw, ph, 0.02), c)


## Un toit en pavillon sur une tour carrée : pans raides jusqu'à un court faîtage, coyau retroussé à
## l'égout, un épi de faîtage à chaque bout. `xf` est au centre du haut des murs, `demi` la demi-largeur.
static func _pavillon(f, xf: Transform3D, demi: float, haut: float, tuile: Color) -> void:
	var fa := 0.22
	var b := demi
	var k := demi + 0.28
	var y0 := 0.12
	for q in 4:
		var qx := xf * Transform3D(Basis(Vector3.UP, q * PI / 2.0), Vector3.ZERO)
		var ri := fa if q % 2 == 0 else 0.0
		# Le pan raide, du coyau au faîtage.
		f.batch.quad("roof", qx, [Vector3(-b, y0, b), Vector3(b, y0, b), Vector3(ri, haut, 0), Vector3(-ri, haut, 0)], Vector3(0, b, haut).normalized(), tuile)
		# Le coyau : le bas du toit qui se relève en débordant.
		f.batch.quad("roof", qx, [Vector3(-k, y0 - 0.12, k), Vector3(k, y0 - 0.12, k), Vector3(b, y0, b), Vector3(-b, y0, b)], Vector3(0, 0.9, 0.4).normalized(), tuile.darkened(0.06))
	f.batch.box("trim", xf, Vector3(0, haut + 0.02, 0), Vector3(fa * 2.0 + 0.1, 0.07, 0.1), tuile.darkened(0.25))
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(s * fa, haut + 0.18, 0), Vector3(0.04, 0.32, 0.04), Color(0.25, 0.2, 0.18))
		f.batch.cylinder("trim", xf, Vector3(s * fa, haut + 0.1, 0), 0.05, 0.1, Color(0.3, 0.24, 0.2), 8)


## Une lanterne de fer sur sa potence, scellée au mur en `at` (repère de la façade).
static func _applique(f, xf: Transform3D, at: Vector3) -> void:
	var noir := Color(0.12, 0.12, 0.13)
	f.batch.box("trim", xf, at + Vector3(0, 0.0, 0.03), Vector3(0.08, 0.2, 0.04), noir)
	f.batch.box("trim", xf, at + Vector3(0, 0.08, 0.17), Vector3(0.03, 0.03, 0.3), noir)
	f.batch.box("trim", xf, at + Vector3(0, -0.06, 0.3), Vector3(0.16, 0.2, 0.16), Color(0.15, 0.15, 0.16))
	f.batch.box("trim", xf, at + Vector3(0, 0.06, 0.3), Vector3(0.2, 0.05, 0.2), noir)
	for a in [0.0, PI / 2.0, PI, -PI / 2.0]:
		var lxf := xf * Transform3D(Basis(), at + Vector3(0, 0, 0.3)) * Transform3D(Basis(Vector3.UP, a), Vector3.ZERO)
		f._glass(lxf, Vector3(0, -0.07, 0.085), Vector2(0.12, 0.14), 0, true, Color(1.0, 0.85, 0.6))
	f.glows.append([xf * (at + Vector3(0, -0.06, 0.3)), Color(1.0, 0.85, 0.6)])


static func _murs_porte_riviere(b: Dictionary, hauteur: Callable) -> Array:
	var out: Array = []
	var poly: Array = b.p
	for k in poly.size():
		var q: Array = poly[k]
		var s: Array = poly[(k + 1) % poly.size()]
		out.append([q[0], q[1], s[0], s[1]])
	var xf := repere_riviere(hauteur)
	var rect := func(x0: float, x1: float, za: float, zb: float) -> void:
		var pts := [Vector3(x0, 0, za), Vector3(x1, 0, za), Vector3(x1, 0, zb), Vector3(x0, 0, zb)]
		for k in 4:
			var p: Vector3 = xf * pts[k]
			var q: Vector3 = xf * pts[(k + 1) % 4]
			out.append([p.x, p.z, q.x, q.z])
	rect.call(-1.3, -0.68, 0.7, -0.7)
	rect.call(0.68, 1.3, 0.7, -0.7)
	rect.call(1.05, 2.65, 0.45, -1.15)
	rect.call(2.55, 3.75, 0.3, -1.5)
	return out


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
	var pierre := Color(0.76, 0.68, 0.56)
	var joint := Color(0.52, 0.46, 0.38)
	var blanc := Color(0.95, 0.95, 0.93)
	var clair := Color(0.92, 0.88, 0.78)
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
	# Le haut mur de pierre qui ferme la cour au sud-est, de la maison au pignon aveugle du voisin.
	var ma := Vector3(17.26, 0, 48.64)
	var mb := Vector3(20.21, 0, 46.85)
	var ym: float = hauteur.call((ma.x + mb.x) / 2.0, (ma.z + mb.z) / 2.0) - 0.03
	ma.y = ym
	mb.y = ym
	f.garden_wall(ma, mb, 2.3, moellon)
	# Deux tilleuls taillés en boule dans la cour.
	for q in [Vector2(15.1, 43.9), Vector2(19.0, 45.7)]:
		var yt: float = hauteur.call(q.x, q.y) - 0.05
		var txf := Transform3D(Basis(), Vector3(q.x, yt, q.y))
		f.batch.cylinder("trim", txf, Vector3.ZERO, 0.08, 1.1, Color(0.36, 0.28, 0.2), 6)
		var feuille := Color(0.3, 0.48, 0.2)
		f.batch.cylinder("trim", txf, Vector3(0, 1.0, 0), 0.5, 0.4, feuille.darkened(0.1), 8)
		f.batch.cylinder("trim", txf, Vector3(0, 1.4, 0), 0.7, 0.6, feuille, 8)
		f.batch.cylinder("trim", txf, Vector3(0, 2.0, 0), 0.45, 0.4, feuille.lightened(0.1), 8)
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
static func _moellons(f, xf: Transform3D, w: float, h: float, mur: Color, y0: float = 0.0) -> void:
	var bas: float = maxf(BASE_H, y0) + 0.05
	if w < 0.7 or h - 0.1 <= bas:
		return
	var n := int(w * (h - bas) * 7.0)
	for i in n:
		var pw: float = f.rng.randf_range(0.1, 0.26)
		var ph: float = f.rng.randf_range(0.06, 0.13)
		var x: float = f.rng.randf_range(-w / 2.0 + 0.3, w / 2.0 - 0.3)
		var y: float = f.rng.randf_range(bas, h - 0.1)
		var t: float = f.rng.randf()
		var c := mur.darkened(0.18).lerp(mur.lightened(0.2), t)
		f.batch.box("trim", xf, Vector3(x, y, 0.008), Vector3(pw, ph, 0.016), c)


## Un arc en plein cintre de claveaux clairs, centré en `c` (la naissance de l'arc), de rayon `r`.
static func _arc(f, xf: Transform3D, c: Vector3, r: float, clair: Color) -> void:
	for k in 5:
		var a := PI * (k + 0.5) / 5.0
		var p := c + Vector3(r * 0.8 * cos(a), r * 0.8 * sin(a), 0.0)
		f.batch.box("trim", xf * Transform3D(Basis(Vector3.BACK, a - PI / 2.0), p), Vector3.ZERO, Vector3(0.3, 0.14, 0.04), clair)
