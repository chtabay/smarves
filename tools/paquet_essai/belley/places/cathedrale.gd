extends RefCounted
## La cathédrale Saint-Jean-Baptiste, sur son emprise réelle (BD TOPO) : 84 m de la façade au chevet, une nef
## de 24 m avec ses bas-côtés, un transept de 38 m, le chœur gothique et son abside. La façade néo-gothique
## suit la planche de la place : une tour-porche au milieu, le portail en arc brisé sous son gâble et sa rose,
## le beffroi à trois baies, la balustrade ajourée et ses quatre pinacles ; les contreforts à pinacles le long
## des bas-côtés ; le parvis et ses marches vers la place.
##
## Repère : l'origine au pied de la façade, au milieu ; +Z sort de la façade (vers la place, à l'ouest-nord-
## ouest) ; +X à droite de qui regarde la façade ; l'édifice s'étend vers -Z.

const OUTILS := preload("res://communes/belley/atelier/outils.gd")

## Le pied de la façade dans le monde et l'axe de la nef (vers le chevet), relevés sur l'emprise.
const ORIGINE := Vector2(200.74, 340.64)
const AXE_DEG := 30.5

const C := Color("dbd1ba")  # un ton sous le calcaire des maisons : la grande façade au soleil ne brûle pas
const C2 := Color("d1c6ad")      # les parements un peu plus gris des parties hautes
const OMBRE := OUTILS.CALCAIRE_OMBRE
const VERRE := Color(0.21, 0.26, 0.25, 0.15)  # le gris-vert des vitraux vus du dehors
const ABAT := Color(0.12, 0.12, 0.13, 0.9)
const ZINC := Color(0.42, 0.46, 0.50, 0.5)
const TUILE := Color("b46a46", 0.0)

const NEF := 6.0        # la demi-largeur du vaisseau central
const BAS := 12.0       # la demi-largeur avec les bas-côtés
const TRANSEPT := 19.0
const EGOUT_NEF := 19.0
const FAITE_NEF := 25.5
const EGOUT_BAS := 9.8
const APPUI_BAS := 14.2  # le haut du toit des bas-côtés, contre la nef

var o: RefCounted


## Bâtit la cathédrale sous parent, son pied à l'altitude y (le sol du parvis). Rend le nœud.
func batir(parent: Node3D, y: float) -> Node3D:
	o = OUTILS.new(1034)
	var n := Node3D.new()
	n.name = "Cathedrale"
	parent.add_child(n)
	var a := deg_to_rad(AXE_DEG)
	var axe := Vector3(cos(a), 0, sin(a))
	var droite := Vector3(-axe.z, 0, axe.x)
	n.transform = Transform3D(Basis(droite, Vector3.UP, -axe), Vector3(ORIGINE.x, y, ORIGINE.y))
	_soubassement()
	_nef()
	_transept()
	_choeur()
	_facade()
	_tour()
	_parvis()
	var mi: MeshInstance3D = o.construire(n, "Pierre")
	mi.set_instance_shader_parameter("sol", y)
	return n


## Le socle sous tout l'édifice : il descend de 4 m pour suivre la pente de la place.
func _soubassement() -> void:
	_bloc(Vector3(0, -2.0, -14.5), Vector3(BAS * 2.0 + 0.6, 4.0, 29.0), OMBRE)
	_bloc(Vector3(0, -2.0, -44.0), Vector3(TRANSEPT * 2.0 + 0.6, 4.0, 32.0), OMBRE)
	_bloc(Vector3(0, -2.0, -68.0), Vector3(BAS * 2.0 + 0.6, 4.0, 16.0), OMBRE)


func _bloc(centre: Vector3, taille: Vector3, col, genre := OUTILS.PIERRE, collision := false) -> void:
	o.boite(Transform3D(Basis(), centre), taille, col, genre, collision)


## Une baie en arc brisé sur un mur : t a son origine au milieu de l'appui, x le long du mur, y en haut, z hors
## du mur. l la largeur, p le piédroit, meneaux le nombre de lancettes.
func baie(t: Transform3D, l: float, p: float, meneaux := 1, verre := VERRE, ebrasement := 0.45) -> void:
	var forme := ogive(l, p, l * 0.8)
	# Le mur est plein : l'encadrement avance de la profondeur de l'ébrasement, le verre se pose sur le nu du
	# mur ; les flancs intérieurs du cadre font l'ébrasement.
	bande(t, ogive(l + 0.44, p, (l + 0.44) * 0.8), forme, 0.0, ebrasement, OMBRE)
	if verre == ABAT:
		# Le beffroi : pas de verre, mais le fond sombre de la chambre des cloches et les abat-sons, lames de bois
		# gris inclinées vers le bas, en retrait au fond de l'ouverture.
		o.profil(t, forme, 0.0, 0.02, Color(0.07, 0.07, 0.08, 1.0), OUTILS.PEINT)
		var y := 0.45
		while y < p - 0.2:
			o.boite(t * Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(0, y, 0.16)), Vector3(l - 0.04, 0.05, 0.3), Color(0.30, 0.30, 0.29, 0.9), OUTILS.PEINT)
			y += 0.42
	else:
		o.profil(t, forme, 0.02, 0.04, verre, OUTILS.VITRE)
	o.boite(t * Transform3D(Basis(), Vector3(0, 0.08, ebrasement * 0.5 + 0.05)), Vector3(l + 0.6, 0.16, ebrasement + 0.1), OMBRE)
	if meneaux > 1:
		for k in range(1, meneaux):
			var x := -l * 0.5 + l * k / meneaux
			o.boite(t * Transform3D(Basis(), Vector3(x, p * 0.5 + l * 0.2, 0.1)), Vector3(0.14, p + l * 0.4, 0.14), C)
		# Le remplage : un oculus au-dessus des lancettes.
		_oculus(t * Transform3D(Basis(), Vector3(0, p + l * 0.42, 0.12)), l * 0.2, 6)


## Le tracé d'une baie en arc brisé, du pied gauche au pied droit en passant par la clé : largeur l, piédroit
## p, flèche f ; n points par arc. Fermé, c'est un polygone simple (le verre, le tympan).
static func ogive(l: float, p: float, f: float, n := 8) -> PackedVector2Array:
	var r := l * 0.5
	# Chaque arc a son centre sur la ligne des naissances, du côté opposé : rayon R tel que l'arc passe par la clé.
	var R := (r * r + f * f) / (2.0 * r)
	var cx := r - R
	var amax := asin(f / R)
	var pts := PackedVector2Array([Vector2(-r, 0)])
	for i in n + 1:
		var a := amax * i / n
		pts.append(Vector2(-cx - R * cos(a), p + R * sin(a)))
	for i in range(n - 1, -1, -1):
		var a := amax * i / n
		pts.append(Vector2(cx + R * cos(a), p + R * sin(a)))
	pts.append(Vector2(r, 0))
	return pts


## Une bande entre deux tracés de même nombre de points (l'extérieur et l'intérieur d'un cadre, d'une
## voussure), extrudée de z0 à z1 dans le repère t : sa face, son dos, ses deux flancs.
func bande(t: Transform3D, ext: PackedVector2Array, int_: PackedVector2Array, z0: float, z1: float, col: Color) -> void:
	for i in ext.size() - 1:
		var a := ext[i]
		var b := ext[i + 1]
		var c := int_[i + 1]
		var d := int_[i]
		for z in [z1, z0]:
			var n := Vector3(0, 0, 1 if z == z1 else -1)
			o.quad(t * Vector3(a.x, a.y, z), t * Vector3(b.x, b.y, z), t * Vector3(c.x, c.y, z), t * Vector3(d.x, d.y, z), t.basis * n, col)
		for bord in [[a, b, 1.0], [d, c, -1.0]]:
			var p: Vector2 = bord[0]
			var q: Vector2 = bord[1]
			var e := q - p
			# Le flanc extérieur regarde dehors, l'intérieur vers l'ouverture.
			var n2 := Vector2(-e.y, e.x)
			var m := (p + q) * 0.5
			if n2.dot(m - Vector2(0, m.y * 0.6)) * float(bord[2]) < 0.0:
				n2 = -n2
			o.quad(t * Vector3(p.x, p.y, z0), t * Vector3(q.x, q.y, z0), t * Vector3(q.x, q.y, z1), t * Vector3(p.x, p.y, z1), t.basis * Vector3(n2.x, n2.y, 0), col)


## Le contour d'un cadre : l'anneau entre un tracé extérieur et un tracé intérieur, rendu comme un polygone
## unique (coupé en bas, là où l'appui le ferme).
func _contour(ext: PackedVector2Array, int_: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in ext:
		if p.y >= -0.01:
			out.append(Vector2(p.x, maxf(p.y, 0.0)))
	var dedans := int_.duplicate()
	dedans.reverse()
	for p in dedans:
		out.append(p)
	return out


## Un oculus à remplage : un anneau de pierre et ses rayons, devant un disque de verre.
func _oculus(t: Transform3D, r: float, rayons: int) -> void:
	var rot := Basis(Vector3.RIGHT, PI * 0.5)
	o.cylindre(t * Transform3D(rot, Vector3(0, 0, -0.04)), r, r, 0.02, 16, VERRE, OUTILS.VITRE)
	o.anneau(t * Transform3D(rot, Vector3(0, 0, -0.02)), r, r + 0.18, 0.16, 16, C)
	o.cylindre(t * Transform3D(rot, Vector3(0, 0, -0.02)), r * 0.22, r * 0.22, 0.14, 8, C)
	for k in rayons:
		var a := TAU * k / rayons
		var m := Vector3(cos(a), sin(a), 0) * r * 0.6
		o.boite(t * Transform3D(Basis(Vector3.BACK, a), m + Vector3(0, 0, 0.04)), Vector3(r * 0.8, 0.08, 0.1), C)


## Un pinacle : un fût carré, ses gâblets, puis la flèche fine et son fleuron ; pied en p, côté s.
func pinacle(p: Vector3, s: float, h: float, col := C) -> void:
	var fut := h * 0.42
	o.boite(Transform3D(Basis(), p + Vector3(0, fut * 0.5, 0)), Vector3(s, fut, s), col)
	for k in 4:
		var b := Basis(Vector3.UP, k * PI * 0.5)
		var c := p + Vector3(0, fut, 0) + b * Vector3(0, 0, s * 0.5)
		var g := PackedVector2Array([Vector2(-s * 0.5, 0), Vector2(s * 0.5, 0), Vector2(0, s * 0.9)])
		o.profil(Transform3D(b, c), g, -0.06, 0.06, col)
	o.cylindre(Transform3D(Basis(), p + Vector3(0, fut, 0)), s * 0.42, 0.04, h - fut, 8, col)
	for k in 3:
		var y := fut + (h - fut) * (0.3 + 0.22 * k)
		var r := s * 0.42 * (1.0 - (y - fut) / (h - fut)) + 0.08
		for q in 4:
			var b := Basis(Vector3.UP, q * PI * 0.5 + PI * 0.25)
			o.boite(Transform3D(b, p + Vector3(0, y, 0) + b * Vector3(0, 0, r)), Vector3(0.1, 0.16, 0.12), col)
	o.boule(p + Vector3(0, h + 0.1, 0), Vector3(0.14, 0.16, 0.14), col, 0.1, OUTILS.PIERRE, 0.0)


## Un contrefort à ressauts : pied en p (au nu du mur), largeur l, saillie s, hauteur h ; le glacis à chaque
## ressaut ; normale du mur n (sortante).
func contrefort(p: Vector3, n: Vector3, l: float, s: float, h: float, ressauts := 2, col := C) -> void:
	var b := Basis(Vector3.UP, atan2(n.x, n.z))
	var y := 0.0
	var sa := s
	for k in ressauts:
		var hh := h * (0.5 if k == 0 else 0.5 / (ressauts - 1)) if ressauts > 1 else h
		o.boite(Transform3D(b, p + b * Vector3(0, y + hh * 0.5, sa * 0.5)), Vector3(l, hh, sa), col)
		# Le glacis : un pan incliné qui renvoie l'eau.
		var g := PackedVector2Array([Vector2(0, 0), Vector2(sa, 0), Vector2(0, minf(sa * 0.9, 1.0))])
		o.profil(Transform3D(Basis(Vector3.UP, atan2(n.x, n.z) - PI * 0.5), p + b * Vector3(0, y + hh, 0)), g, -l * 0.5, l * 0.5, col)
		y += hh
		sa *= 0.65


## La nef et ses bas-côtés, de la tour (z = -7) au transept (z = -28) ; cinq travées.
func _nef() -> void:
	var z0 := 0.0
	var z1 := -28.0
	# Les bas-côtés : murs, toits en appentis, contreforts à pinacles et baies.
	for cote: float in [-1.0, 1.0]:
		_bloc(Vector3(cote * (BAS - 3.0), EGOUT_BAS * 0.5, (z0 + z1) * 0.5), Vector3(6.0, EGOUT_BAS, z0 - z1), C, OUTILS.PIERRE, true)
		_corniche(Vector3(cote * BAS, EGOUT_BAS, z0), Vector3(cote * BAS, EGOUT_BAS, z1), Vector3(cote, 0, 0))
		var e := Vector3(cote * (BAS + 0.35), EGOUT_BAS + 0.1, 0)
		var f := Vector3(cote * NEF, APPUI_BAS, 0)
		_pan_toit(e + Vector3(0, 0, z0 - 0.2), e + Vector3(0, 0, z1), f + Vector3(0, 0, z1), f + Vector3(0, 0, z0 - 0.2), TUILE)
		for k in 5:
			var zc := z0 - 2.8 - 5.6 * k
			var mur := Transform3D(Basis(Vector3.UP, cote * PI * 0.5), Vector3(cote * BAS, 2.6, zc))
			baie(mur, 2.0, 4.2, 2)
			if k > 0:
				contrefort(Vector3(cote * BAS, 0, zc + 2.8), Vector3(cote, 0, 0), 1.0, 1.6, EGOUT_BAS + 0.8, 2)
				pinacle(Vector3(cote * (BAS + 0.3), EGOUT_BAS + 0.8, zc + 2.8), 0.6, 3.6)
			# Les fenêtres hautes de la nef, au-dessus des toits des bas-côtés.
			var haut := Transform3D(Basis(Vector3.UP, cote * PI * 0.5), Vector3(cote * NEF, APPUI_BAS + 0.6, zc))
			baie(haut, 1.5, 2.2, 2)
	# Le vaisseau central : ses murs hauts et son grand toit.
	_bloc(Vector3(0, EGOUT_NEF * 0.5, (z0 + z1) * 0.5 - 1.0), Vector3(NEF * 2.0, EGOUT_NEF, z0 - z1 + 2.0), C2)
	_toit_long(-7.0, z1 - 0.5, NEF, EGOUT_NEF, FAITE_NEF)


## Un toit à deux pans d'axe z, de z0 à z1 (z0 > z1), demi-largeur l, égout et faîte.
func _toit_long(z0: float, z1: float, l: float, egout: float, faite: float) -> void:
	var d := 0.5
	for cote: float in [-1.0, 1.0]:
		_pan_toit(Vector3(cote * (l + d), egout - 0.3, z0), Vector3(cote * (l + d), egout - 0.3, z1), Vector3(0, faite, z1), Vector3(0, faite, z0), TUILE)
		_corniche(Vector3(cote * l, egout, z0), Vector3(cote * l, egout, z1), Vector3(cote, 0, 0))
	# Le faîtage : une ligne de tuiles plus sombres.
	o.boite(Transform3D(Basis(), Vector3(0, faite + 0.08, (z0 + z1) * 0.5)), Vector3(0.36, 0.22, z0 - z1), TUILE.darkened(0.2), OUTILS.PEINT)


## Un pan de tuiles, ses quatre coins (égouts puis faîte).
func _pan_toit(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	o.pan(a, b, c, d, col)
	# Le dessous du pan, pour qu'il ait une épaisseur vue d'en bas.
	o.quad(a - Vector3(0, 0.12, 0), b - Vector3(0, 0.12, 0), c - Vector3(0, 0.12, 0), d - Vector3(0, 0.12, 0), Vector3.DOWN, OMBRE.darkened(0.3), OUTILS.PEINT)


## La corniche sous un égout et sa gouttière de zinc : de a à b, n vers dehors.
func _corniche(a: Vector3, b: Vector3, n: Vector3) -> void:
	var m := (a + b) * 0.5
	var l := a.distance_to(b)
	var bas := Basis(Vector3.UP, atan2(n.x, n.z))
	o.boite(Transform3D(bas, m + n * 0.18 - Vector3(0, 0.25, 0)), Vector3(l, 0.5, 0.36), OMBRE)
	o.boite(Transform3D(bas, m + n * 0.45 - Vector3(0, 0.1, 0)), Vector3(l, 0.18, 0.18), ZINC, OUTILS.PEINT)


## Le transept : deux bras sous un toit en travers, leurs pignons à rose.
func _transept() -> void:
	var z0 := -28.0
	var z1 := -60.0
	var zc := (z0 + z1) * 0.5
	var demi := (z0 - z1) * 0.5 - 4.0
	for cote: float in [-1.0, 1.0]:
		_bloc(Vector3(cote * (TRANSEPT + BAS) * 0.5, EGOUT_NEF * 0.45, zc), Vector3(TRANSEPT - BAS + 0.1, EGOUT_NEF * 0.9, demi * 2.0), C2, OUTILS.PIERRE, true)
		var x := cote * TRANSEPT
		# Le pignon et sa rose.
		var pignon := PackedVector2Array([Vector2(-demi, 0), Vector2(demi, 0), Vector2(0, FAITE_NEF - EGOUT_NEF * 0.9)])
		var t := Transform3D(Basis(Vector3.UP, cote * PI * 0.5), Vector3(x, EGOUT_NEF * 0.9, zc))
		o.profil(t, pignon, -0.4, 0.0, C2)
		_oculus(Transform3D(t.basis, Vector3(x, 0, zc) + t.basis * Vector3(0, EGOUT_NEF * 0.9 - 2.2, 0.05)), 3.0, 12)
		baie(Transform3D(t.basis, Vector3(x, 2.4, zc) + t.basis * Vector3(-5.0, 0, 0.0)), 2.2, 5.0, 2)
		baie(Transform3D(t.basis, Vector3(x, 2.4, zc) + t.basis * Vector3(5.0, 0, 0.0)), 2.2, 5.0, 2)
		for s: float in [-1.0, 1.0]:
			contrefort(Vector3(x, 0, zc + s * demi), Vector3(cote, 0, 0), 1.2, 1.8, EGOUT_NEF * 0.9 + 1.0, 3)
			pinacle(Vector3(x + cote * 0.4, EGOUT_NEF * 0.9 + 1.0, zc + s * demi), 0.8, 5.5)
		# Le toit des bras, d'axe x : de la nef au pignon.
		for s: float in [-1.0, 1.0]:
			_pan_toit(Vector3(x + cote * 0.4, EGOUT_NEF * 0.9 - 0.3, zc + s * (demi + 0.5)), Vector3(cote * NEF, EGOUT_NEF * 0.9 - 0.3, zc + s * (demi + 0.5)), Vector3(cote * NEF, FAITE_NEF, zc), Vector3(x + cote * 0.4, FAITE_NEF, zc), TUILE)
			_corniche(Vector3(x, EGOUT_NEF * 0.9, zc + s * demi), Vector3(cote * BAS, EGOUT_NEF * 0.9, zc + s * demi), Vector3(0, 0, s))
		# Les bas-côtés qui longent le transept jusqu'au chœur.
		_bloc(Vector3(cote * (BAS - 3.0), EGOUT_BAS * 0.5, zc), Vector3(6.0, EGOUT_BAS, z0 - z1), C)
	_bloc(Vector3(0, EGOUT_NEF * 0.5, zc), Vector3(NEF * 2.0, EGOUT_NEF, z0 - z1), C2)
	_toit_long(z0, z1, NEF, EGOUT_NEF, FAITE_NEF)


## Le chœur gothique et son abside à cinq pans, sous un toit en croupe ronde.
func _choeur() -> void:
	var z0 := -60.0
	var zc := -72.0
	var r_haut := NEF
	var r_bas := 10.5
	_bloc(Vector3(0, EGOUT_NEF * 0.5, (z0 + zc) * 0.5), Vector3(NEF * 2.0, EGOUT_NEF, zc - z0 if zc > z0 else z0 - zc), C2)
	for cote: float in [-1.0, 1.0]:
		_bloc(Vector3(cote * (BAS - 3.0) * 0.95, EGOUT_BAS * 0.5, (z0 + zc) * 0.5), Vector3(5.6, EGOUT_BAS, z0 - zc), C)
	_toit_long(z0, zc, NEF, EGOUT_NEF, FAITE_NEF)
	# L'abside : un demi-polygone, haut au centre, le déambulatoire autour.
	var pans := 5
	for k in pans:
		var a0 := PI * k / pans
		var a1 := PI * (k + 1) / pans
		var d0 := Vector3(cos(a0), 0, -sin(a0))
		var d1 := Vector3(cos(a1), 0, -sin(a1))
		var c := Vector3(0, 0, zc)
		var dm := (d0 + d1).normalized()
		for anneau in [[r_bas, EGOUT_BAS, C], [r_haut, EGOUT_NEF, C2]]:
			var r: float = anneau[0]
			var h: float = anneau[1]
			var p0 := c + d0 * r
			var p1 := c + d1 * r
			o.quad(p0, p1, p1 + Vector3(0, h, 0), p0 + Vector3(0, h, 0), dm, anneau[2])
			_corniche(p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), dm)
		# Le toit du déambulatoire et la croupe du chœur.
		_pan_toit(c + d0 * (r_bas + 0.35) + Vector3(0, EGOUT_BAS, 0), c + d1 * (r_bas + 0.35) + Vector3(0, EGOUT_BAS, 0), c + d1 * r_haut + Vector3(0, APPUI_BAS - 1.0, 0), c + d0 * r_haut + Vector3(0, APPUI_BAS - 1.0, 0), TUILE)
		o.croupe(c + d0 * (r_haut + 0.5) + Vector3(0, EGOUT_NEF - 0.3, 0), c + d1 * (r_haut + 0.5) + Vector3(0, EGOUT_NEF - 0.3, 0), c + Vector3(0, FAITE_NEF, 0), TUILE)
		var t := Transform3D(Basis(Vector3.UP, atan2(dm.x, dm.z)), c + dm * r_haut * cos(PI / pans * 0.5) + Vector3(0, APPUI_BAS + 0.3, 0))
		baie(t, 1.6, 3.0, 2)
		var tb := Transform3D(Basis(Vector3.UP, atan2(dm.x, dm.z)), c + dm * r_bas * cos(PI / pans * 0.5) + Vector3(0, 2.4, 0))
		baie(tb, 1.8, 3.8, 2)
		var pc := c + d1 * r_bas
		if k < pans - 1:
			contrefort(pc, d1, 1.0, 1.8, EGOUT_BAS + 0.8, 2)
			pinacle(pc + d1 * 0.3 + Vector3(0, EGOUT_BAS + 0.8, 0), 0.6, 3.6)


## La façade des bas-côtés de part et d'autre de la tour : leur mur, leur rampant, leur baie, leur contrefort
## d'angle et son grand pinacle.
func _facade() -> void:
	for cote: float in [-1.0, 1.0]:
		var xm := cote * (BAS + 6.6) * 0.5
		_bloc(Vector3(xm, EGOUT_BAS * 0.5, -0.4), Vector3(BAS - 6.6, EGOUT_BAS, 0.8), C)
		# Le rampant qui monte vers la tour, son chaperon.
		var r := PackedVector2Array([Vector2(-(BAS - 6.6) * 0.5, 0), Vector2((BAS - 6.6) * 0.5, 0), Vector2(-cote * (BAS - 6.6) * 0.5, APPUI_BAS - EGOUT_BAS)])
		o.profil(Transform3D(Basis(), Vector3(xm, EGOUT_BAS, 0)), r, -0.8, 0.0, C)
		baie(Transform3D(Basis(), Vector3(xm, 2.8, 0.0)), 2.2, 5.0, 2)
		# Le contrefort d'angle, et son pinacle.
		# Deux contreforts d'équerre à trois ressauts, l'un sur la façade, l'autre sur le flanc : l'angle se
		# lit en gradins jusqu'au pinacle.
		contrefort(Vector3(cote * (BAS - 0.7), 0, 0), Vector3(0, 0, 1), 1.5, 1.9, 14.0, 3)
		contrefort(Vector3(cote * BAS, 0, -1.0), Vector3(cote, 0, 0), 1.5, 1.9, 12.0, 3)
		o.boite(Transform3D(Basis(), Vector3(cote * (BAS - 0.7), 0.6, 1.1)), Vector3(2.0, 1.2, 2.4), OMBRE)
		pinacle(Vector3(cote * (BAS - 0.7), 14.0, 0.45), 1.3, 7.0)


## La tour-porche : de 11 m de large, elle avance de 1,5 m sur la façade et monte à 38 m, ses pinacles à 45 m.
const TOUR := 5.5
const TOUR_AV := 1.5
const TOUR_H := 38.0


func _tour() -> void:
	var zf := TOUR_AV
	var zb := -7.0
	var zm := (zf + zb) * 0.5
	var prof := zf - zb
	# Le corps, en trois étages séparés de cordons.
	_bloc(Vector3(0, 7.0, zm), Vector3(TOUR * 2.0, 14.0, prof), C)
	_bloc(Vector3(0, 19.5, zm), Vector3(TOUR * 2.0 - 0.6, 11.0, prof - 0.6), C)
	_bloc(Vector3(0, 31.0, zm), Vector3(TOUR * 2.0 - 1.0, 12.0, prof - 1.0), C2)
	for y: float in [14.0, 25.0, 37.0]:
		o.boite(Transform3D(Basis(), Vector3(0, y, zm)), Vector3(TOUR * 2.0 + 0.3, 0.35, prof + 0.3), OMBRE)
	# Les contreforts d'angle de la tour, à ressauts jusqu'au beffroi.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [zf, zb]:
			var sens := signf(sz - zm)
			# Deux contreforts d'équerre par angle, à trois ressauts jusqu'au beffroi, puis un dernier
			# contrefort plus mince qui file jusqu'à la balustrade.
			contrefort(Vector3(sx * (TOUR - 0.8), 0, sz), Vector3(0, 0, sens), 1.5, 1.4, 25.0, 3)
			contrefort(Vector3(sx * TOUR, 0, sz - sens * 0.8), Vector3(sx, 0, 0), 1.5, 1.4, 25.0, 3)
			contrefort(Vector3(sx * (TOUR - 0.8), 25.0, sz), Vector3(0, 0, sens), 1.1, 0.6, 12.4, 2, C2)
			contrefort(Vector3(sx * TOUR, 25.0, sz - sens * 0.8), Vector3(sx, 0, 0), 1.1, 0.6, 12.4, 2, C2)
		# Les grands pinacles qui encadrent le gâble du portail.
		pinacle(Vector3(sx * TOUR, 25.0, zf), 1.2, 6.5)
	# Le portail : l'arc brisé profond, ses voussures, les vantaux de chêne, le tympan et sa statue.
	var portail := Transform3D(Basis(), Vector3(0, 0, zf))
	var vous := 5
	var piedroit := 5.0
	for k in vous:
		# De la voussure la plus large, en avant, à la plus étroite, contre la tour.
		var l := 5.2 + 0.6 * (vous - 1 - k)
		var z := 0.32 * (vous - 1 - k)
		bande(portail * Transform3D(Basis(), Vector3(0, 0, z)), ogive(l + 1.0, piedroit, (l + 1.0) * 0.55), ogive(l, piedroit, l * 0.55), 0.0, 0.45, C if k % 2 == 0 else OMBRE)
	var fond := portail
	var tymp := ogive(5.2, piedroit, 5.2 * 0.55)
	o.profil(fond, tymp, 0.0, 0.04, C2)
	for s: float in [-1.0, 1.0]:
		o.boite(fond * Transform3D(Basis(), Vector3(s * 1.2, 2.25, 0.08)), Vector3(2.2, 4.5, 0.1), Color(OUTILS.BOIS_PORTE, 0.6), OUTILS.PEINT)
		for j in 3:
			o.boite(fond * Transform3D(Basis(), Vector3(s * 1.2, 0.8 + j * 1.4, 0.15)), Vector3(1.7, 1.1, 0.05), Color(OUTILS.BOIS_PORTE.darkened(0.15), 0.6), OUTILS.PEINT)
	o.boite(fond * Transform3D(Basis(), Vector3(0, 2.25, 0.15)), Vector3(0.35, 4.5, 0.3), C)
	o.boite(fond * Transform3D(Basis(), Vector3(0, 4.65, 0.15)), Vector3(5.2, 0.3, 0.3), OMBRE)
	# La statue du Baptiste sur sa console, dans le tympan.
	var st := fond * Vector3(0, 4.9, 0.35)
	o.boite(Transform3D(Basis(), st), Vector3(0.8, 0.22, 0.45), C)
	o.cylindre(Transform3D(Basis(), st + Vector3(0, 0.11, 0)), 0.28, 0.2, 1.3, 8, C)
	o.boule(st + Vector3(0, 1.55, 0), Vector3(0.15, 0.18, 0.15), C, 0.04, OUTILS.PIERRE, 0.0)
	# Le gâble au-dessus du portail, ajouré d'une rose.
	var gable := PackedVector2Array([Vector2(-4.2, 0), Vector2(4.2, 0), Vector2(0, 6.2)])
	var tg := Transform3D(Basis(), Vector3(0, 9.3, zf + 1.35))
	o.profil(tg, gable, -1.35, 0.0, C)
	o.profil(tg, _contour(OUTILS.grossir(gable, 0.25), gable), 0.0, 0.12, OMBRE)
	_oculus(tg * Transform3D(Basis(), Vector3(0, 2.3, 0.02)), 1.35, 8)
	o.boule(tg * Vector3(0, 6.5, -0.15), Vector3(0.25, 0.35, 0.25), C, 0.15, OUTILS.PIERRE, 0.0)
	# Les crochets le long des rampants, les trilobes aveugles de part et d'autre de la rose.
	for cote: float in [-1.0, 1.0]:
		for k in 6:
			var f := (k + 1) / 7.0
			var q := Vector2(cote * 4.2 * (1.0 - f), 6.2 * f)
			# Les crochets en crosse, de la teinte de la pierre : une tige qui sort du rampant et s'enroule.
			o.boite(tg * Transform3D(Basis(Vector3.BACK, cote * 0.6), Vector3(q.x + cote * 0.1, q.y + 0.12, 0.05)), Vector3(0.07, 0.2, 0.07), OMBRE)
			o.boule(tg * Vector3(q.x + cote * 0.16, q.y + 0.22, 0.05), Vector3(0.08, 0.07, 0.08), OMBRE, 0.1, OUTILS.PIERRE, 0.0)
		bande(tg * Transform3D(Basis(), Vector3(cote * 2.3, 0.35, 0.0)), ogive(1.1, 0.6, 0.7), ogive(0.8, 0.6, 0.5), 0.0, 0.1, OMBRE)
		# Les pinacles qui encadrent le gâble, sur les contreforts du portail.
		pinacle(Vector3(cote * 4.55, 9.3, zf + 1.1), 0.7, 6.0)
	# La galerie aveugle sous le cordon du deuxième étage : une rangée d'arcatures.
	for k in 9:
		var x := (k - 4) * 1.15
		if absf(x) < 2.0:
			continue
		bande(Transform3D(Basis(), Vector3(x, 11.6, zf)), ogive(1.0, 1.2, 0.6), ogive(0.72, 1.2, 0.42), 0.0, 0.14, OMBRE)
	# Deuxième étage : deux baies jumelles de chaque côté du gâble, la galerie aveugle.
	for s: float in [-1.0, 1.0]:
		baie(Transform3D(Basis(), Vector3(s * 3.5, 16.0, zf - 0.3)), 1.1, 3.4, 1)
		# Au-dessus du gâble, deux hautes lancettes jumelles sous un arc commun : le deuxième registre de la
		# planche, qui tient le milieu de la tour.
		baie(Transform3D(Basis(), Vector3(s * 0.85, 16.6, zf - 0.3)), 1.15, 5.2, 1)
	bande(Transform3D(Basis(), Vector3(0, 16.6, zf - 0.3)), ogive(4.6, 5.3, 4.6 * 0.75), ogive(3.9, 5.3, 3.9 * 0.75), 0.0, 0.32, OMBRE)
	# La frise d'arcatures aveugles sous le cordon du beffroi, sur les quatre faces.
	for face in 4:
		var bf := Basis(Vector3.UP, face * PI * 0.5)
		var demi_f := (TOUR - 0.3) if face % 2 == 0 else (prof - 0.6) * 0.5
		var cf := Vector3(0, 23.4, zm) + bf * Vector3(0, 0, (prof - 0.6) * 0.5 if face % 2 == 0 else TOUR - 0.3)
		var nf := int(demi_f * 2.0 / 0.9)
		for k in nf:
			var x := -demi_f + 0.45 + k * (demi_f * 2.0 - 0.9) / maxf(nf - 1, 1)
			bande(Transform3D(bf, cf + bf * Vector3(x, 0, 0)), ogive(0.8, 0.7, 0.5), ogive(0.56, 0.7, 0.34), 0.0, 0.12, OMBRE)
	for s: float in [-1.0, 1.0]:
		for k in 2:
			baie(Transform3D(Basis(Vector3.UP, s * PI * 0.5), Vector3(s * (TOUR - 0.3), 16.0, zm + (k - 0.5) * 3.6)), 1.1, 3.4, 1)
	# Le beffroi : trois hautes baies à abat-son sur chaque face.
	for face in 4:
		var b := Basis(Vector3.UP, face * PI * 0.5)
		var demi := (TOUR - 0.5) if face % 2 == 0 else (prof - 1.0) * 0.5
		var centre := Vector3(0, 26.8, zm) + b * Vector3(0, 0, demi if face % 2 == 0 else (TOUR - 0.5))
		var n := 3 if face % 2 == 0 else 2
		for k in n:
			var x := (k - (n - 1) * 0.5) * 2.3
			baie(Transform3D(b, centre + b * Vector3(x, 0, 0)), 1.5, 6.6, 1, ABAT, 0.5)
	# La balustrade ajourée du couronnement et les quatre pinacles d'angle.
	var hb := TOUR_H
	o.boite(Transform3D(Basis(), Vector3(0, hb - 0.4, zm)), Vector3(TOUR * 2.0 + 0.5, 0.8, prof + 0.5), OMBRE)
	for face in 4:
		var b := Basis(Vector3.UP, face * PI * 0.5)
		var demi_l := TOUR if face % 2 == 0 else prof * 0.5
		var demi_p := prof * 0.5 if face % 2 == 0 else TOUR
		var cc := Vector3(0, hb, zm) + b * Vector3(0, 0, demi_p)
		o.boite(Transform3D(b, cc + Vector3(0, 1.25, 0)), Vector3(demi_l * 2.0, 0.22, 0.32), C)
		var nb := int(demi_l * 2.0 / 0.7)
		for k in nb:
			var x := -demi_l + 0.35 + k * (demi_l * 2.0 - 0.7) / maxf(nb - 1, 1)
			o.boite(Transform3D(b, cc + b * Vector3(x, 0.6, 0)), Vector3(0.14, 1.2, 0.2), C)
		# Les petits gâbles de la balustrade, au milieu de chaque face.
		o.profil(Transform3D(b, cc + Vector3(0, 1.3, 0)), PackedVector2Array([Vector2(-1.0, 0), Vector2(1.0, 0), Vector2(0, 1.5)]), -0.1, 0.1, C)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [zf, zb]:
			pinacle(Vector3(sx * (TOUR - 0.1), hb, sz - signf(sz - zm) * 0.1), 1.1, 7.0)
	# La couronne : de petits pinacles serrés le long de la balustrade, comme sur la planche.
	for face in 4:
		var b := Basis(Vector3.UP, face * PI * 0.5)
		var demi_l := TOUR if face % 2 == 0 else prof * 0.5
		var demi_p := prof * 0.5 if face % 2 == 0 else TOUR
		var nb := 3 if face % 2 == 0 else 2
		for k in nb:
			var x := (k - (nb - 1) * 0.5) * demi_l * 2.0 / (nb + 0.6)
			pinacle(Vector3(0, hb, zm) + b * Vector3(x, 0, demi_p - 0.25) + Vector3(0, 1.3, 0), 0.45, 3.4)
	# Le toit plat de la tour, de zinc.
	o.boite(Transform3D(Basis(), Vector3(0, hb + 0.05, zm)), Vector3(TOUR * 2.0 - 0.6, 0.1, prof - 0.6), ZINC, OUTILS.PEINT)


## Le parvis dallé et ses marches qui descendent vers la place.
func _parvis() -> void:
	var l := 20.0
	o.boite(Transform3D(Basis(), Vector3(0, -2.0, 3.4)), Vector3(l, 4.0, 4.0), Color("d8cdb5"), OUTILS.PIERRE, true)
	_marches(l, 6)


func _marches(l: float, n: int) -> void:
	# Chaque marche : une boîte qui descend jusqu'à 4 m sous le parvis (la pente de la place).
	for k in n:
		var dessus := -0.17 * (k + 1)
		var z := 5.4 + 0.42 * k + 0.21
		o.boite(Transform3D(Basis(), Vector3(0, (dessus - 4.0) * 0.5, z)), Vector3(l - 0.5 * k, 4.0 + dessus, 0.42), Color("d8cdb5"), OUTILS.PIERRE, true)
