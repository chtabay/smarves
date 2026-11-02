extends RefCounted
## L'église Saint-Martin d'Availles-Limouzine, d'après les photos de la façade et du chevet, le plan
## de l'église et la vue aérienne de l'IGN : une croix latine. La nef romane unique, de moellons de
## granite sombre où se mêlent le rose, l'ocre et le gris, sa façade ouest en pignon nu, percée d'une
## porte en plein cintre à claveaux de calcaire jaune et d'une baie étroite, trois corbeaux, la croix au
## faîte ; le clocher carré sur la travée romane, devant le transept, sous sa pyramide d'ardoise ; les deux
## chapelles du transept, reconstruites en 1703 et 1781, enduites ; le chœur gothique flamboyant des
## Archiac à chevet plat, sa grande verrière à remplage au-dessus d'un soubassement de granite en assises
## (la crypte est dessous, le terrain descend de cinq mètres vers l'est), ses contreforts d'angle ; la
## sacristie basse au nord du chœur.
##
## Le repère : l'origine au milieu du pied de la façade ouest, au niveau du parvis ; +Z vers la place,
## +X vers le sud (la droite quand on regarde la façade). Dans ce repère, u = -z avance dans la nef
## vers le chevet, v = x va du nord au sud. Les mesures sont celles de l'emprise du cadastre.

const FLOOR_H := 1.3

## Le milieu du pied de la façade, et la direction de la nef (vers l'est), en unités du bourg.
const OUEST := Vector2(-88.82, -64.955)
const AXE := 32.4

const GRANITE := Color(0.66, 0.6, 0.53)
const CALCAIRE := Color(0.8, 0.66, 0.42)
const ENDUIT := Color(0.83, 0.79, 0.7)
const TUILE := Color(0.7, 0.42, 0.3)
const ARDOISE := Color(0.32, 0.35, 0.41)
const BOIS := Color(0.3, 0.2, 0.14)
const VITRAIL := Color(0.16, 0.2, 0.36)
## Les teintes des moellons de la façade : beige, rose, gris, ocre, brun.
const MOELLONS := [Color(0.76, 0.69, 0.58), Color(0.72, 0.55, 0.48), Color(0.6, 0.58, 0.56), Color(0.78, 0.62, 0.42), Color(0.5, 0.44, 0.4), Color(0.68, 0.62, 0.55)]

## Les volumes, en (u0, u1, v0, v1) et hauteur d'égout au-dessus du parvis.
const NEF := [0.0, 7.1, -2.48, 2.48, 3.55]
const TOUR := [7.0, 11.0, -2.0, 2.0, 8.0]
const BRAS_SUD := [9.4, 12.85, 1.9, 4.7, 3.0]
const BRAS_NORD := [9.5, 13.2, -5.9, -1.9, 3.0]
const CHOEUR := [10.9, 16.3, -2.4, 2.4, 4.0]
const SACRISTIE := [13.1, 16.3, -4.5, -2.35, 1.5]  # au nord du chœur


static func repere(hauteur: Callable) -> Transform3D:
	var a := deg_to_rad(AXE)
	var n := -Vector2(cos(a), sin(a))
	var y: float = hauteur.call(OUEST.x + n.x * 0.8, OUEST.y + n.y * 0.8)
	return Transform3D(Basis(Vector3.UP, atan2(n.x, n.y)), Vector3(OUEST.x, y, OUEST.y))


## Le point du bourg (x, z) sous le point (u, v) de l'église.
static func au_sol(xf: Transform3D, u: float, v: float) -> Vector2:
	var p := xf * Vector3(v, 0, -u)
	return Vector2(p.x, p.z)


## La profondeur du terrain sous le parvis, au plus bas d'un volume : de combien ses murs descendent.
static func _descente(xf: Transform3D, vol: Array, hauteur: Callable) -> float:
	var bas := INF
	for u in [vol[0], (vol[0] + vol[1]) / 2.0, vol[1]]:
		for v in [vol[2], vol[3]]:
			var p := au_sol(xf, u, v)
			bas = minf(bas, hauteur.call(p.x, p.y))
	return maxf(0.15, xf.origin.y - bas + 0.15)


static func construire(f, b: Dictionary, hauteur: Callable) -> void:
	var xf := repere(hauteur)
	f.rng.seed = 86015481
	_nef(f, xf, hauteur)
	_facade(f, xf)
	_tour(f, xf, hauteur)
	_bras(f, xf, BRAS_SUD, 1.0, hauteur)
	_bras(f, xf, BRAS_NORD, -1.0, hauteur)
	_choeur(f, xf, hauteur)
	_sacristie(f, xf, hauteur)


## Un volume au faîtage dans l'axe de la nef : le repère tourné d'un quart de tour, +X vers l'est.
static func _long(xf: Transform3D, vol: Array) -> Transform3D:
	return xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(vol[3], 0, -(vol[0] + vol[1]) / 2.0))


## Un volume au faîtage en travers (les bras du transept) : +X vers le sud.
static func _travers(xf: Transform3D, vol: Array) -> Transform3D:
	return xf * Transform3D(Basis(), Vector3((vol[2] + vol[3]) / 2.0, 0, -vol[0]))


## Le corps d'un volume, de sa base (sous le parvis si le terrain descend) à l'égout.
static func _corps(f, vxf: Transform3D, w: float, d: float, h: float, bas: float, mur: Color) -> void:
	f.batch.box("wall", vxf, Vector3(0, (h - bas) / 2.0, -d / 2.0), Vector3(w, h + bas, d), mur)


## Des moellons en applique sur une face (repère de la face : +Z dehors, le mur de x0 à x1, de y0 à y1).
static func moellons(f, fxf: Transform3D, x0: float, x1: float, y0: float, y1: float, densite := 9.0, pente := 0.0) -> void:
	var n := int((x1 - x0) * (y1 - y0) * densite)
	for i in n:
		var pw: float = f.rng.randf_range(0.07, 0.2)
		var ph: float = f.rng.randf_range(0.05, 0.11)
		var x: float = f.rng.randf_range(x0 + 0.12, x1 - 0.12)
		var y: float = f.rng.randf_range(y0 + 0.05, y1 - 0.08)
		if pente > 0.0:
			# Dans un pignon : sous les rampants seulement.
			var demi := (x1 - x0) / 2.0
			var lim := y0 + (demi - absf(x - (x0 + x1) / 2.0)) * pente
			if y > lim - 0.1:
				continue
		var c: Color = MOELLONS[f.rng.randi() % MOELLONS.size()]
		c = c.darkened(f.rng.randf_range(0.0, 0.15))
		f.batch.box("trim", fxf, Vector3(x, y, 0.01), Vector3(pw, ph, 0.025), c)


## Les assises régulières d'un soubassement de granite (le chevet) : des rangs de pierres rougeâtres.
static func assises(f, fxf: Transform3D, x0: float, x1: float, y0: float, y1: float) -> void:
	var y := y0
	var rang := 0
	while y < y1 - 0.05:
		var hr := minf(0.16, y1 - y)
		var x := x0 + (0.12 if rang % 2 == 1 else 0.0)
		while x < x1 - 0.05:
			var lw: float = minf(f.rng.randf_range(0.22, 0.4), x1 - x)
			var c := Color(0.55, 0.42, 0.36).lerp(Color(0.66, 0.52, 0.42), f.rng.randf()).darkened(f.rng.randf_range(0.0, 0.12))
			f.batch.box("trim", fxf, Vector3(x + lw / 2.0, y + hr / 2.0, 0.01), Vector3(lw - 0.025, hr - 0.022, 0.025), c)
			x += lw
		y += hr
		rang += 1


## Une baie romane : étroite, en plein cintre, ébrasée, son vitrail sombre (repère de la face).
static func baie(f, fxf: Transform3D, x: float, y: float, w: float, h: float, pierre: Color) -> void:
	f.batch.box("trim", fxf, Vector3(x, y + h / 2.0, 0.005), Vector3(w + 0.16, h, 0.03), pierre)
	f.batch.box("trim", fxf, Vector3(x, y + (h - w / 2.0) / 2.0, 0.025), Vector3(w, h - w / 2.0, 0.02), VITRAIL)
	var r := w / 2.0
	for k in 6:
		var a := PI * (k + 0.5) / 6.0
		f.batch.box("trim", fxf * Transform3D(Basis(Vector3.BACK, a - PI / 2.0), Vector3(x + (r + 0.05) * cos(a), y + h - r + (r + 0.05) * sin(a), 0.01)), Vector3.ZERO, Vector3(0.1, 0.12, 0.035), pierre)
		f.batch.box("trim", fxf, Vector3(x + r * 0.7 * cos(a), y + h - r + r * 0.55 * sin(a), 0.025), Vector3(w * 0.32, r * 0.5, 0.02), VITRAIL)
	f.batch.box("trim", fxf, Vector3(x, y - 0.03, 0.04), Vector3(w + 0.22, 0.06, 0.08), pierre)


## Un contrefort : un pilier de pierre de section (l le long du mur, p en saillie), coiffé d'un glacis.
static func contrefort(f, fxf: Transform3D, x: float, l: float, p: float, h: float, bas: float, pierre: Color) -> void:
	f.batch.box("wall", fxf, Vector3(x, (h - bas) / 2.0, p / 2.0), Vector3(l, h + bas, p), pierre)
	var g := p * 0.9
	f.batch.box_tilted("trim", fxf, Vector3(x, h + g * 0.25, p * 0.4), Vector3(l + 0.04, 0.08, p * 1.15), deg_to_rad(38.0), pierre.darkened(0.12))
	f.batch.box("trim", fxf, Vector3(x, h * 0.45, p + 0.02), Vector3(l + 0.04, 0.06, 0.06), pierre.darkened(0.1))


## Un contrefort à deux ressauts : le pied épais jusqu'à h1, puis un étage moins saillant jusqu'à h2,
## un glacis au haut de chacun, et les assises de pierre marquées par des joints.
static func contrefort_etage(f, fxf: Transform3D, l: float, p: float, h1: float, h2: float, bas: float, pierre: Color) -> void:
	f.batch.box("wall", fxf, Vector3(0, (h1 - bas) / 2.0, p / 2.0), Vector3(l, h1 + bas, p), pierre)
	f.batch.box_tilted("trim", fxf, Vector3(0, h1 + 0.1, p * 0.72), Vector3(l + 0.04, 0.08, p * 0.62), deg_to_rad(40.0), pierre.darkened(0.12))
	var p2 := p * 0.55
	f.batch.box("wall", fxf, Vector3(0, (h1 + h2) / 2.0, p2 / 2.0), Vector3(l * 0.9, h2 - h1, p2), pierre.lightened(0.03))
	f.batch.box_tilted("trim", fxf, Vector3(0, h2 + p2 * 0.3, p2 * 0.45), Vector3(l * 0.9 + 0.04, 0.08, p2 * 1.2), deg_to_rad(40.0), pierre.darkened(0.12))
	moellons(f, fxf * Transform3D(Basis(), Vector3(0, 0, p)), -l / 2.0, l / 2.0, -bas, h1, 14.0)
	moellons(f, fxf * Transform3D(Basis(), Vector3(0, 0, p2)), -l * 0.45, l * 0.45, h1 + 0.15, h2, 14.0)
	var y := -bas + 0.3
	while y < h2 - 0.1:
		var pp := p if y < h1 else p2
		f.batch.box("trim", fxf, Vector3(0, y, pp + 0.005), Vector3(l * (1.0 if y < h1 else 0.9) + 0.01, 0.025, 0.02), pierre.darkened(0.2))
		y += 0.32


# --- La nef --------------------------------------------------------------------------------------

static func _nef(f, xf: Transform3D, hauteur: Callable) -> void:
	var v := NEF
	var w: float = v[1] - v[0]
	var d: float = v[3] - v[2]
	var h: float = v[4]
	var bas := _descente(xf, v, hauteur)
	var nxf := _long(xf, v)
	_corps(f, nxf, w, d, h, bas, GRANITE)
	f._roof(nxf, w, d, h, TUILE, GRANITE, "pignon")
	# Les deux longs murs : sud (+X du repère de l'église) et nord, leurs baies hautes et leurs contreforts.
	for cote in [1.0, -1.0]:
		var fxf: Transform3D = xf * Transform3D(Basis(Vector3.UP, cote * PI / 2.0), Vector3(cote * v[3] if cote > 0.0 else v[2], 0, -w / 2.0))
		# Dans ce repère de face, x va de l'ouest vers l'est côté sud et l'inverse côté nord.
		moellons(f, fxf, -w / 2.0, w / 2.0, -bas, h, 6.0)
		for u in [2.35, 4.7]:
			contrefort(f, fxf, _x_face(u - w / 2.0, cote), 0.42, 0.32, h * 0.72, bas, GRANITE.lightened(0.04))
		for u in [1.2, 3.55, 5.9]:
			if cote > 0.0 and absf(u - 3.55) < 0.1:
				continue
			baie(f, fxf, _x_face(u - w / 2.0, cote), h * 0.62, 0.26, 0.85, CALCAIRE.lightened(0.05))
		# La corniche sous l'égout.
		f.batch.box("trim", fxf, Vector3(0, h - 0.05, 0.03), Vector3(w, 0.1, 0.08), GRANITE.darkened(0.15))
	# La porte sud, sous son petit auvent de tuiles, au milieu de la nef.
	var sxf: Transform3D = xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(v[3], 0, -3.85))
	_porte(f, sxf, 0.0, 0.62, 0.95, true)
	f.batch.box("wall", sxf, Vector3(0, 1.5, 0.35), Vector3(1.3, 0.12, 0.7), GRANITE.darkened(0.08))
	f.batch.box_tilted("roof", sxf, Vector3(0, 1.66, 0.38), Vector3(1.45, 0.06, 0.85), deg_to_rad(-22.0), TUILE)


## Le x d'un point d'abscisse u (depuis le milieu de la nef) dans le repère d'une face latérale.
static func _x_face(du: float, cote: float) -> float:
	return du * cote


# --- La façade ouest -----------------------------------------------------------------------------

static func _facade(f, xf: Transform3D) -> void:
	var v := NEF
	var d: float = v[3] - v[2]
	var h: float = v[4]
	var demi := d / 2.0
	var pente := tan(deg_to_rad(28.0))
	var faite := h + 0.1 + demi * pente
	var fxf := xf * Transform3D(Basis(), Vector3(0, 0, 0.0))
	# Les moellons du mur et du pignon, plus serrés qu'ailleurs : c'est la face qu'on regarde.
	moellons(f, fxf, -demi, demi, 0.0, h + 0.1, 26.0)
	moellons(f, fxf, -demi, demi, h + 0.1, faite, 26.0, pente)
	# Les chaînes d'angle, de gros blocs de granite plus clair.
	var y := 0.0
	var k := 0
	while y < h - 0.1:
		var hs := 0.26
		var long := k % 2 == 0
		for s in [-1.0, 1.0]:
			var lw := 0.5 if long else 0.3
			var c: Color = MOELLONS[(k + (1 if s > 0 else 0)) % 3].lightened(0.06)
			f.batch.box("trim", fxf, Vector3(s * (demi - lw / 2.0 + 0.01), y + hs / 2.0, 0.02), Vector3(lw, hs - 0.03, 0.04), c)
		y += hs
		k += 1
	# Le chaperon des rampants : une rangée de dalles qui dépasse un peu.
	var lr := demi / cos(deg_to_rad(28.0)) + 0.1
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf * Transform3D(Basis(Vector3.BACK, -s * deg_to_rad(28.0)), Vector3(s * demi / 2.0, h + 0.1 + demi * pente / 2.0 + 0.04, 0.0)), Vector3.ZERO, Vector3(lr, 0.1, 0.24), GRANITE.darkened(0.1))
	# La porte en plein cintre, la baie haute, les trois corbeaux, la croix au faîte.
	_porte(f, fxf, 0.0, 0.98, 1.0, false)
	baie(f, fxf, 0.05, 2.0, 0.3, 0.86, CALCAIRE)
	for x in [-0.95, -0.15, 0.95]:
		f.batch.box("trim", fxf, Vector3(x, 1.72, 0.08), Vector3(0.16, 0.12, 0.16), GRANITE.lightened(0.1))
	f.batch.box("trim", fxf, Vector3(0, faite + 0.16, 0), Vector3(0.07, 0.42, 0.07), CALCAIRE)
	f.batch.box("trim", fxf, Vector3(0, faite + 0.26, 0), Vector3(0.26, 0.07, 0.07), CALCAIRE)
	f.batch.box("trim", fxf, Vector3(0, faite + 0.02, 0), Vector3(0.18, 0.06, 0.18), CALCAIRE.darkened(0.1))
	# Le soubassement et le parvis : une marche de granite au pied du mur.
	f.batch.box("trim", fxf, Vector3(0, 0.03, 0.3), Vector3(1.5, 0.06, 0.6), GRANITE.darkened(0.05))
	# La console de fer du réverbère, à droite de la porte, comme sur la photo.
	f.batch.box("trim", fxf, Vector3(demi - 0.25, 1.15, 0.25), Vector3(0.03, 0.03, 0.5), Color(0.12, 0.12, 0.13))
	f.batch.box("trim", fxf, Vector3(demi - 0.25, 1.1, 0.5), Vector3(0.16, 0.22, 0.16), Color(0.15, 0.15, 0.16))
	f._glass(fxf, Vector3(demi - 0.25, 1.08, 0.59), Vector2(0.11, 0.15), 0, true, Color(1.0, 0.85, 0.6))
	f.glows.append([fxf * Vector3(demi - 0.25, 1.1, 0.7), Color(1.0, 0.85, 0.6)])


## Une porte en plein cintre à deux vantaux de bois, ses claveaux de calcaire jaune, ses impostes.
## `ressaut` : sans voussure, pour la petite porte sud.
static func _porte(f, fxf: Transform3D, x: float, w: float, hp: float, ressaut: bool) -> void:
	var r := w / 2.0
	var ep := 0.16 if not ressaut else 0.12
	# Les vantaux, et leur cintre en lamelles.
	f.batch.box("trim", fxf, Vector3(x, hp / 2.0, 0.02), Vector3(w, hp, 0.03), BOIS)
	for k in 5:
		var t := (k + 0.5) / 5.0
		var hh := sqrt(maxf(0.0, 1.0 - pow(t * 2.0 - 1.0, 2.0))) * r
		f.batch.box("trim", fxf, Vector3(x - r + t * w, hp + hh / 2.0, 0.02), Vector3(w / 5.0 + 0.005, hh, 0.03), BOIS)
	f.batch.box("trim", fxf, Vector3(x, (hp + r * 0.8) / 2.0, 0.04), Vector3(0.02, hp + r * 0.8, 0.01), BOIS.darkened(0.4))
	for i in 4:
		f.batch.box("trim", fxf, Vector3(x - w * 0.375 + i * w * 0.25, hp * 0.5, 0.037), Vector3(0.012, hp * 0.92, 0.006), BOIS.darkened(0.25))
	# Les jambages et les impostes.
	for s in [-1.0, 1.0]:
		f.batch.box("trim", fxf, Vector3(x + s * (r + ep / 2.0), hp / 2.0, 0.03), Vector3(ep, hp, 0.06), CALCAIRE)
		f.batch.box("trim", fxf, Vector3(x + s * (r + ep / 2.0), hp + 0.03, 0.05), Vector3(ep + 0.06, 0.07, 0.1), CALCAIRE.darkened(0.08))
	# Les claveaux de l'arc.
	var n := 11
	for k in n:
		var a := PI * (k + 0.5) / n
		var c := Vector3(x + (r + ep / 2.0) * cos(a), hp + 0.06 + (r + ep / 2.0) * sin(a), 0.03)
		f.batch.box("trim", fxf * Transform3D(Basis(Vector3.BACK, a - PI / 2.0), c), Vector3.ZERO, Vector3(PI * (r + ep / 2.0) / n - 0.012, ep, 0.06), CALCAIRE.lerp(CALCAIRE.darkened(0.15), f.rng.randf()))
	if not ressaut:
		# La petite clef ronde au sommet de l'arc.
		f.batch.cylinder("trim", fxf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(x, hp + 0.06 + r + ep + 0.05, 0.03)), Vector3.ZERO, 0.06, 0.05, CALCAIRE.darkened(0.1), 8)
	f.batch.box("trim", fxf, Vector3(x, 0.02, 0.12), Vector3(w + 0.4, 0.04, 0.24), GRANITE.darkened(0.1))


# --- Le clocher ----------------------------------------------------------------------------------

static func _tour(f, xf: Transform3D, hauteur: Callable) -> void:
	var t := TOUR
	var c := 2.0
	var h: float = t[4]
	var um: float = (t[0] + t[1]) / 2.0
	var bas := _descente(xf, t, hauteur)
	var txf := xf * Transform3D(Basis(), Vector3(0, 0, -um))
	f.batch.box("wall", txf, Vector3(0, (h - bas) / 2.0, 0), Vector3(2.0 * c, h + bas, 2.0 * c), GRANITE.darkened(0.04))
	var faite_nef: float = NEF[4] + 0.1 + (2.48 + 0.16) * tan(deg_to_rad(28.0))
	for k in 4:
		var fxf := txf * Transform3D(Basis(Vector3.UP, k * PI / 2.0), Vector3(0, 0, 0)) * Transform3D(Basis(), Vector3(0, 0, c))
		moellons(f, fxf, -c, c, faite_nef - 0.2, h, 7.0)
		# Le cordon au-dessus des toits, puis celui sous les baies du beffroi.
		f.batch.box("trim", fxf, Vector3(0, faite_nef + 0.15, 0.04), Vector3(2.0 * c + 0.1, 0.1, 0.1), GRANITE.lightened(0.1))
		f.batch.box("trim", fxf, Vector3(0, h - 2.25, 0.04), Vector3(2.0 * c + 0.1, 0.1, 0.1), GRANITE.lightened(0.1))
		# Les deux baies géminées des cloches, et leurs abat-sons.
		for s in [-0.75, 0.75]:
			var y0: float = h - 2.1
			var bw := 0.55
			var bh := 1.45
			f.batch.box("trim", fxf, Vector3(s, y0 + (bh - bw / 2.0) / 2.0, 0.005), Vector3(bw, bh - bw / 2.0, 0.02), Color(0.08, 0.07, 0.07))
			for i in 7:
				var a := PI * (i + 0.5) / 7.0
				var r := bw / 2.0
				f.batch.box("trim", fxf, Vector3(s + r * 0.7 * cos(a), y0 + bh - r + r * 0.5 * sin(a), 0.005), Vector3(bw * 0.3, r * 0.6, 0.02), Color(0.08, 0.07, 0.07))
				f.batch.box("trim", fxf * Transform3D(Basis(Vector3.BACK, a - PI / 2.0), Vector3(s + (r + 0.06) * cos(a), y0 + bh - r + (r + 0.06) * sin(a), 0.02)), Vector3.ZERO, Vector3(0.12, 0.13, 0.05), GRANITE.lightened(0.14))
			for q in [-1.0, 1.0]:
				f.batch.box("trim", fxf, Vector3(s + q * (bw / 2.0 + 0.06), y0 + (bh - bw / 2.0) / 2.0, 0.02), Vector3(0.12, bh - bw / 2.0, 0.05), GRANITE.lightened(0.14))
			for i in 6:
				f.batch.box_tilted("trim", fxf, Vector3(s, y0 + 0.12 + i * 0.17, 0.0), Vector3(bw - 0.04, 0.03, 0.14), deg_to_rad(-30.0), Color(0.42, 0.36, 0.3))
			f.batch.box("trim", fxf, Vector3(s, y0 - 0.03, 0.05), Vector3(bw + 0.22, 0.06, 0.1), GRANITE.lightened(0.1))
		# La corniche à modillons sous la pyramide.
		f.batch.box("trim", fxf, Vector3(0, h - 0.06, 0.06), Vector3(2.0 * c + 0.2, 0.12, 0.14), GRANITE.lightened(0.08))
		for i in 9:
			f.batch.box("trim", fxf, Vector3(-c + 0.2 + i * (2.0 * c - 0.4) / 8.0, h - 0.18, 0.06), Vector3(0.08, 0.1, 0.12), GRANITE.lightened(0.05))
		# Une petite baie étroite au-dessus des toits, sur les faces est et ouest (la cage de l'escalier).
		if k % 2 == 0:
			baie(f, fxf, 0.0, faite_nef + 0.6, 0.14, 0.42, GRANITE.lightened(0.14))
	# La pyramide d'ardoise, son égout retroussé, et la croix de fer au sommet.
	var cxf := txf * Transform3D(Basis(), Vector3(0, h, 0))
	var REM = load("res://communes/availles_limouzine/remarquables.gd")
	REM._cone(f, cxf, Vector3.ZERO, (c + 0.22) * sqrt(2.0), 3.0, ARDOISE, 4, PI / 4.0)
	REM._cone(f, cxf, Vector3(0, -0.02, 0), (c + 0.3) * sqrt(2.0), 0.28, ARDOISE.darkened(0.1), 4, PI / 4.0)
	f.batch.box("trim", cxf, Vector3(0, 3.2, 0), Vector3(0.04, 0.6, 0.04), Color(0.15, 0.14, 0.14))
	f.batch.box("trim", cxf, Vector3(0, 3.32, 0), Vector3(0.26, 0.04, 0.04), Color(0.15, 0.14, 0.14))
	f.batch.cylinder("trim", cxf, Vector3(0, 2.95, 0), 0.07, 0.1, Color(0.6, 0.5, 0.25), 8)


# --- Les bras du transept ------------------------------------------------------------------------

static func _bras(f, xf: Transform3D, vol: Array, cote: float, hauteur: Callable) -> void:
	var w: float = vol[3] - vol[2]
	var d: float = vol[1] - vol[0]
	var h: float = vol[4]
	var bas := _descente(xf, vol, hauteur)
	var bxf := _travers(xf, vol)
	_corps(f, bxf, w, d, h, bas, ENDUIT)
	f._roof(bxf, w, d, h, TUILE, ENDUIT, "pignon")
	# Le pignon du bras, vers le dehors : la baie en croix, les chaînes d'angle, un soubassement.
	var ext: float = vol[3] if cote > 0.0 else vol[2]
	var fxf := xf * Transform3D(Basis(Vector3.UP, cote * PI / 2.0), Vector3(ext, 0, -(vol[0] + vol[1]) / 2.0))
	var demi := d / 2.0
	var pierre := Color(0.84, 0.78, 0.66)
	var y := -bas
	var k := 0
	while y < h:
		var hs := 0.24
		for s in [-1.0, 1.0]:
			var lw := 0.3 if k % 2 == 0 else 0.18
			f.batch.box("trim", fxf, Vector3(s * (demi - lw / 2.0 + 0.01), y + hs / 2.0, 0.015), Vector3(lw, hs - 0.025, 0.035), pierre)
		y += hs
		k += 1
	f.batch.box("trim", fxf, Vector3(0, -bas / 2.0 + 0.2, 0.01), Vector3(d, bas + 0.4, 0.03), GRANITE.darkened(0.08))
	var wy := 0.9
	var ww := 0.62
	var wh := 1.35
	f.batch.box("trim", fxf, Vector3(0, wy + wh / 2.0, 0.005), Vector3(ww + 0.18, wh + 0.18, 0.03), pierre)
	f.batch.box("trim", fxf, Vector3(0, wy + wh / 2.0, 0.025), Vector3(ww, wh, 0.02), VITRAIL)
	f.batch.box("trim", fxf, Vector3(0, wy + wh / 2.0, 0.04), Vector3(0.07, wh, 0.02), pierre)
	f.batch.box("trim", fxf, Vector3(0, wy + wh * 0.68, 0.04), Vector3(ww, 0.07, 0.02), pierre)
	f.batch.box("trim", fxf, Vector3(0, wy - 0.04, 0.05), Vector3(ww + 0.3, 0.07, 0.1), pierre)
	# L'oculus sous le faîte.
	var faite := h + 0.1 + demi * tan(deg_to_rad(28.0))
	f.batch.cylinder("trim", fxf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, (h + faite) / 2.0 + 0.05, 0.03)), Vector3.ZERO, 0.17, 0.04, pierre, 10)
	f.batch.cylinder("trim", fxf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, (h + faite) / 2.0 + 0.05, 0.05)), Vector3.ZERO, 0.1, 0.04, VITRAIL, 10)
	_face_est(f, xf, vol, bas, true)


## La face est d'un volume enduit (bras, sacristie), qu'on voit depuis le bas du chevet : le
## soubassement de granite, l'enduit usé où percent des moellons, la corniche sous l'égout et, pour
## les bras, une baie étroite.
static func _face_est(f, xf: Transform3D, vol: Array, bas: float, baie_haute: bool) -> void:
	var w: float = vol[3] - vol[2]
	var h: float = vol[4]
	var exf := xf * Transform3D(Basis(Vector3.UP, PI), Vector3((vol[2] + vol[3]) / 2.0, 0, -vol[1]))
	var demi := w / 2.0
	assises(f, exf, -demi, demi, -bas, 0.3)
	f.batch.box("trim", exf, Vector3(0, 0.33, 0.03), Vector3(w, 0.06, 0.05), GRANITE.darkened(0.1))
	moellons(f, exf, -demi, demi, 0.4, h, 3.0)
	f.batch.box("trim", exf, Vector3(0, h - 0.04, 0.03), Vector3(w, 0.08, 0.07), ENDUIT.darkened(0.2))
	for s in [-1.0, 1.0]:
		var y := 0.36
		var k := 0
		while y < h - 0.1:
			var lw := 0.28 if k % 2 == 0 else 0.16
			f.batch.box("trim", exf, Vector3(s * (demi - lw / 2.0 + 0.01), y + 0.11, 0.015), Vector3(lw, 0.2, 0.035), Color(0.84, 0.78, 0.66))
			y += 0.23
			k += 1
	if baie_haute:
		baie(f, exf, 0.0, h * 0.45, 0.26, 0.8, CALCAIRE.lightened(0.05))
	else:
		baie(f, exf, 0.3, 0.55, 0.24, 0.5, CALCAIRE.lightened(0.05))


# --- Le chœur et son chevet plat ------------------------------------------------------------------

static func _choeur(f, xf: Transform3D, hauteur: Callable) -> void:
	var v := CHOEUR
	var w: float = v[1] - v[0]
	var d: float = v[3] - v[2]
	var h: float = v[4]
	var bas := _descente(xf, v, hauteur)
	var cxf := _long(xf, v)
	_corps(f, cxf, w, d, h, bas, ENDUIT)
	f._roof(cxf, w, d, h, TUILE.darkened(0.08), ENDUIT, "pignon")
	# Le chevet, vers l'est : soubassement de granite en assises, la grande verrière à remplage.
	var exf := xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -v[1]))
	var demi := d / 2.0
	var socle := 0.35
	assises(f, exf, -demi, demi, -bas, socle)
	f.batch.box("trim", exf, Vector3(0, socle + 0.03, 0.03), Vector3(d, 0.07, 0.06), GRANITE.darkened(0.1))
	var gy := 0.75
	var gw := 1.5
	var gh := 2.05
	_verriere(f, exf, gy, gw, gh)
	# L'écu des Archiac à la clef de la verrière, et le jour du comble.
	var pointe := gy + gh + gw * 0.6
	f.batch.box("trim", exf, Vector3(0, pointe + 0.16, 0.04), Vector3(0.18, 0.22, 0.05), CALCAIRE.lightened(0.1))
	f.batch.box("trim", exf, Vector3(0, h + 0.8, 0.02), Vector3(0.14, 0.2, 0.02), Color(0.1, 0.1, 0.1))
	# Le soupirail de la crypte, en plein cintre, dans les assises.
	baie(f, exf, -0.55, -bas + 0.55, 0.3, 0.45, CALCAIRE)
	# Le mur du chevet, au-dessus des assises : des moellons de granite jusque dans le pignon, sous
	# les rampants une rive de pierre qui porte le bord du toit, la croix au sommet.
	var pente := tan(deg_to_rad(28.0))
	moellons(f, exf, -demi, demi, socle + 0.07, h, 9.0)
	moellons(f, exf, -demi, demi, h, h + demi * pente, 9.0, pente)
	var rive := Color(0.6, 0.5, 0.42)
	var lr := sqrt(demi * demi + pow(demi * pente, 2.0)) + 0.22
	for s in [-1.0, 1.0]:
		var a := atan(pente)
		f.batch.box("trim", exf * Transform3D(Basis(Vector3.BACK, -s * a), Vector3(s * demi / 2.0, h + demi * pente / 2.0 + 0.1, 0.06)), Vector3.ZERO, Vector3(lr, 0.16, 0.2), rive)
		f.batch.box("trim", exf, Vector3(s * (demi + 0.02), h + 0.02, 0.06), Vector3(0.3, 0.16, 0.22), rive)
	var sommet := h + demi * pente + 0.2
	f.batch.box("trim", exf, Vector3(0, sommet + 0.25, 0.06), Vector3(0.07, 0.5, 0.07), rive.darkened(0.1))
	f.batch.box("trim", exf, Vector3(0, sommet + 0.36, 0.06), Vector3(0.26, 0.07, 0.07), rive.darkened(0.1))
	# Les contreforts d'angle, à deux ressauts, en granite appareillé, posés de biais à chaque coin
	# comme sur la photo, chaque étage coiffé de son glacis.
	for s in [-1.0, 1.0]:
		var cxf2 := exf * Transform3D(Basis(Vector3.UP, s * PI / 4.0), Vector3(s * demi, 0, 0))
		contrefort_etage(f, cxf2, 0.5, 0.75, h * 0.32, h * 0.7, bas, rive)
	# Les longs murs du chœur : une haute baie gothique de chaque côté, au-dessus du toit des bras.
	for cote in [1.0, -1.0]:
		var fxf: Transform3D = xf * Transform3D(Basis(Vector3.UP, cote * PI / 2.0), Vector3(v[3] if cote > 0.0 else v[2], 0, -(v[0] + v[1]) / 2.0))
		assises(f, fxf, -w / 2.0, w / 2.0, -bas, socle)
		if cote < 0.0:
			# Au nord, la sacristie couvre le bas du mur.
			continue
		moellons(f, fxf, -w / 2.0, w / 2.0, socle + 0.05, h, 7.0)
		_lancette(f, fxf, _x_face(w / 2.0 - 1.1, cote), 1.2, 0.45, 1.5)
		contrefort(f, fxf, _x_face(w / 2.0 - 2.2, cote), 0.45, 0.5, h * 0.6, bas, Color(0.6, 0.5, 0.42))


## La grande verrière du chevet : un arc brisé à claveaux de grès, trois lancettes et leurs meneaux,
## le remplage flamboyant en mouchettes au-dessus (repère de la face).
static func _verriere(f, fxf: Transform3D, y: float, w: float, h: float) -> void:
	var gres := Color(0.72, 0.52, 0.34)
	var r := w * 0.8
	var cx := w / 2.0 - r
	# Le vitrail : le rectangle, puis l'ogive par bandes.
	f.batch.box("trim", fxf, Vector3(0, y + h / 2.0, 0.02), Vector3(w, h, 0.02), VITRAIL)
	var n := 8
	var haut := sqrt(r * r - cx * cx)
	for k in n:
		var t0 := float(k) / n
		var yy := t0 * haut
		var demi := sqrt(maxf(0.0, r * r - yy * yy)) + cx
		f.batch.box("trim", fxf, Vector3(0, y + h + yy + haut / n / 2.0, 0.02), Vector3(maxf(0.04, demi * 2.0), haut / n + 0.01, 0.02), VITRAIL.lightened(0.04 * (k % 2)))
	# Les claveaux de l'arc brisé, des deux côtés.
	for s in [-1.0, 1.0]:
		for k in 9:
			var a := (k + 0.5) / 9.0 * acos(-cx / r)
			var p := Vector3(-s * cx - s * (r + 0.07) * cos(a), y + h + (r + 0.07) * sin(a), 0.03)
			f.batch.box("trim", fxf * Transform3D(Basis(Vector3.BACK, s * (a - PI / 2.0) + (PI if s < 0.0 else 0.0)), p), Vector3.ZERO, Vector3(0.16, 0.13, 0.05), gres.lerp(gres.lightened(0.15), float(k % 2)))
		f.batch.box("trim", fxf, Vector3(s * (w / 2.0 + 0.07), y + h / 2.0, 0.03), Vector3(0.14, h, 0.05), gres)
	f.batch.box("trim", fxf, Vector3(0, y - 0.04, 0.05), Vector3(w + 0.3, 0.08, 0.1), gres)
	# Les meneaux, les lancettes trilobées, les mouchettes.
	for s in [-1.0, 1.0]:
		f.batch.box("trim", fxf, Vector3(s * w / 6.0, y + h / 2.0 + 0.1, 0.035), Vector3(0.05, h + 0.2, 0.02), gres.lightened(0.1))
	for i in 3:
		var lx := (i - 1) * w / 3.0
		f.batch.box("trim", fxf, Vector3(lx, y + h + 0.05, 0.035), Vector3(w / 3.0 - 0.06, 0.05, 0.02), gres.lightened(0.1))
		for q in [-1.0, 1.0]:
			f.batch.box_tilted("trim", fxf * Transform3D(Basis(Vector3.BACK, q * 0.5), Vector3(lx + q * 0.08, y + h + 0.16, 0.035)), Vector3.ZERO, Vector3(0.04, 0.22, 0.02), 0.0, gres.lightened(0.1))
	for k in 5:
		var a := PI * (k + 0.5) / 5.0
		var p := Vector3(0.32 * cos(a), y + h + 0.5 + 0.28 * sin(a), 0.035)
		f.batch.box("trim", fxf * Transform3D(Basis(Vector3.BACK, a), p), Vector3.ZERO, Vector3(0.26, 0.04, 0.02), gres.lightened(0.1))
	f.batch.cylinder("trim", fxf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, y + h + 0.62, 0.03)), Vector3.ZERO, 0.13, 0.03, gres.lightened(0.1), 10)
	f.batch.cylinder("trim", fxf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, y + h + 0.62, 0.045)), Vector3.ZERO, 0.08, 0.03, Color(0.5, 0.16, 0.14), 10)
	# Quelques éclats colorés dans le vitrail : la Transfiguration des frères Guérithault.
	var teintes := [Color(0.55, 0.15, 0.14), Color(0.75, 0.6, 0.2), Color(0.2, 0.35, 0.55), Color(0.25, 0.45, 0.3)]
	for i in 18:
		var px: float = f.rng.randf_range(-w / 2.0 + 0.08, w / 2.0 - 0.08)
		var py: float = f.rng.randf_range(y + 0.1, y + h - 0.05)
		f.batch.box("trim", fxf, Vector3(px, py, 0.032), Vector3(0.08, 0.12, 0.01), teintes[i % teintes.size()])


## Une lancette gothique haute et étroite, en arc brisé (les longs murs du chœur).
static func _lancette(f, fxf: Transform3D, x: float, y: float, w: float, h: float) -> void:
	var gres := Color(0.72, 0.52, 0.34)
	f.batch.box("trim", fxf, Vector3(x, y + h / 2.0, 0.005), Vector3(w + 0.16, h, 0.03), gres)
	f.batch.box("trim", fxf, Vector3(x, y + h / 2.0, 0.025), Vector3(w, h - 0.04, 0.02), VITRAIL)
	for s in [-1.0, 1.0]:
		f.batch.box_tilted("trim", fxf * Transform3D(Basis(Vector3.BACK, s * 0.62), Vector3(x + s * w * 0.22, y + h + w * 0.3, 0.01)), Vector3.ZERO, Vector3(w * 0.72, 0.12, 0.035), 0.0, gres)
		f.batch.box_tilted("trim", fxf * Transform3D(Basis(Vector3.BACK, s * 0.62), Vector3(x + s * w * 0.16, y + h + w * 0.18, 0.025)), Vector3.ZERO, Vector3(w * 0.5, 0.2, 0.02), 0.0, VITRAIL)
	f.batch.box("trim", fxf, Vector3(x, y - 0.03, 0.04), Vector3(w + 0.24, 0.06, 0.08), gres)


static func _sacristie(f, xf: Transform3D, hauteur: Callable) -> void:
	var v := SACRISTIE
	var w: float = v[1] - v[0]
	var d: float = v[3] - v[2]
	var h: float = v[4]
	var bas := _descente(xf, v, hauteur)
	var sxf := _long(xf, v)
	_corps(f, sxf, w, d, h, bas, ENDUIT.darkened(0.04))
	f._roof(sxf, w, d, h, TUILE, ENDUIT, "hip")
	var fxf := xf * Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(v[2], 0, -(v[0] + v[1]) / 2.0))
	assises(f, fxf, -w / 2.0, w / 2.0, -bas, 0.25)
	_face_est(f, xf, v, bas, false)
	var REM = load("res://communes/availles_limouzine/remarquables.gd")
	REM._fenetre(f, fxf, Vector3(0.4, 0.45, 0), Vector2(0.4, 0.6), Color(0.86, 0.8, 0.68), false, false, Color(1.0, 0.8, 0.5))
