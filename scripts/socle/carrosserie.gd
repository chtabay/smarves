class_name Carrosserie
## L'atelier des véhicules : de quoi bâtir une caisse galbée et ses matières, pour les véhicules qu'on veut
## plus beaux que ceux du Car Kit. Premier client : le van des chasseurs de pépites (scripts/village/pepites.gd).
##
## - `galbe(profil, largeur, arrondi)` : une caisse tirée d'un profil de côté (z vers l'avant, y vers le
##   haut, sens trigonométrique), aux flancs plats et aux arêtes arrondies d'un rayon `arrondi`.
## - `laque(...)`, `chrome()`, `dore()`, `verre()`, `feu(...)` : les matières (shaders/laque.gdshader), qui
##   reflètent une rue de nuit simulée et brillent donc pareil sur ordinateur, sur le web et au téléphone.
## - `arc(...)` : des points d'arc de cercle, pour dessiner les passages de roue et les galbes du profil.

const LAQUE := preload("res://shaders/laque.gdshader")
## Au-delà de cet angle entre deux arêtes du profil, l'arête reste vive (sinon elle est lissée).
const ANGLE_VIF := 38.0


## Une peinture vernie : `teinte` en haut, `bas` sous `coupe_y` (deux tons), le chatoiement vers `reflet`.
static func laque(teinte: Color, reflet := Color(0.9, 0.62, 0.32), paillettes := 0.6, bas := Color(-1, 0, 0), coupe_y := -100.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LAQUE
	m.set_shader_parameter("teinte", teinte)
	m.set_shader_parameter("teinte_bas", teinte if bas.r < 0.0 else bas)
	m.set_shader_parameter("coupe_y", coupe_y)
	m.set_shader_parameter("reflet", reflet)
	m.set_shader_parameter("paillettes", paillettes)
	return m


static func _metal(teinte: Color, rugosite: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LAQUE
	m.set_shader_parameter("teinte", teinte)
	m.set_shader_parameter("teinte_bas", teinte)
	m.set_shader_parameter("metal", 1.0)
	m.set_shader_parameter("rugosite", rugosite)
	return m


static func chrome() -> ShaderMaterial:
	return _metal(Color(0.82, 0.84, 0.88), 0.12)


static func dore() -> ShaderMaterial:
	return _metal(Color(0.95, 0.72, 0.34), 0.2)


## Une vitre teintée : presque noire de face, un miroir de la rue en biais.
static func verre() -> ShaderMaterial:
	var m := laque(Color(0.015, 0.02, 0.035), Color(0.3, 0.4, 0.6), 0.0)
	m.set_shader_parameter("vernis", 1.6)
	m.set_shader_parameter("rugosite", 0.05)
	return m


## Un feu : `force` le fait luire sans éclairer autour (aucune lampe ajoutée).
static func feu(teinte: Color, force := 1.5) -> ShaderMaterial:
	var m := laque(teinte, teinte, 0.0)
	m.set_shader_parameter("lumiere", force)
	m.set_shader_parameter("vernis", 1.2)
	return m


## Une matière mate et simple (pneus, bois, toile).
static func mat(teinte: Color, rugosite := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = teinte
	m.roughness = rugosite
	return m


## Des points sur un arc de centre `c` et de rayon `r`, de l'angle `de` à l'angle `a` (degrés), `n` segments.
static func arc(c: Vector2, r: float, de: float, a: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := deg_to_rad(lerpf(de, a, float(i) / n))
		out.append(c + Vector2(cos(t), sin(t)) * r)
	return out


## La caisse : le profil (z, y) en sens trigonométrique, tiré sur `largeur` (axe x) ; ses deux arêtes de
## flanc arrondies sur `arrondi` en `pas` facettes. Les normales suivent l'arrondi, la laque coule dessus.
static func galbe(profil: PackedVector2Array, largeur: float, arrondi: float, pas := 4) -> ArrayMesh:
	var n := profil.size()
	# Les normales sortantes de chaque arête du profil, puis celles de chaque point (lissées ou vives).
	var ne: Array[Vector2] = []
	for i in n:
		var e := profil[(i + 1) % n] - profil[i]
		ne.append(Vector2(e.y, -e.x).normalized())
	var vif: Array[bool] = []
	var nv: Array[Vector2] = []
	for i in n:
		var a := ne[(i - 1 + n) % n]
		var b := ne[i]
		vif.append(rad_to_deg(a.angle_to(b)) > ANGLE_VIF or rad_to_deg(a.angle_to(b)) < -ANGLE_VIF)
		var m := (a + b).normalized()
		nv.append(m)
	# Le profil rentré de `d` : le contour décalé vers l'intérieur (net, sans boucle aux passages de roue),
	# sur lequel chaque point du profil se pose au plus près ; ainsi chaque tranche a autant de points.
	var rentre := func(d: float) -> PackedVector2Array:
		if d <= 0.0:
			return profil
		var bords := Geometry2D.offset_polygon(profil, -d, Geometry2D.JOIN_MITER)
		if bords.is_empty():
			return profil
		var bord: PackedVector2Array = bords[0]
		var out := PackedVector2Array()
		for i in n:
			var best := bord[0]
			var dmin := INF
			for j in bord.size():
				var q := Geometry2D.get_closest_point_to_segment(profil[i], bord[j], bord[(j + 1) % bord.size()])
				var dd := q.distance_squared_to(profil[i])
				if dd < dmin:
					dmin = dd
					best = q
			out.append(best)
		return out
	# Les tranches : x et retrait, d'un flanc à l'autre en passant par l'arrondi.
	var tranches: Array = []  # [x, retrait, poids du flanc dans la normale]
	var w := largeur / 2.0
	for cote: float in [-1.0, 1.0]:
		var ks := range(pas + 1) if cote < 0.0 else range(pas, -1, -1)
		for k: int in ks:
			var t := deg_to_rad(90.0 * k / pas)
			tranches.append([cote * (w - arrondi + arrondi * cos(t)), arrondi * (1.0 - sin(t)), cote * cos(t), sin(t)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for tr: Array in tranches:
		pts.append(rentre.call(tr[1]))
	for j in tranches.size() - 1:
		var t0: Array = tranches[j]
		var t1: Array = tranches[j + 1]
		var p0: PackedVector2Array = pts[j]
		var p1: PackedVector2Array = pts[j + 1]
		for i in n:
			var i2 := (i + 1) % n
			var na := ne[i] if vif[i] else nv[i]
			var nb := ne[i] if vif[i2] else nv[i2]
			var q := [
				[Vector3(t0[0], p0[i].y, p0[i].x), na, t0],
				[Vector3(t1[0], p1[i].y, p1[i].x), na, t1],
				[Vector3(t1[0], p1[i2].y, p1[i2].x), nb, t1],
				[Vector3(t0[0], p0[i2].y, p0[i2].x), nb, t0],
			]
			for idx: int in [0, 2, 1, 0, 3, 2]:
				var s: Array = q[idx]
				var tr: Array = s[2]
				var pn: Vector2 = s[1]
				st.set_normal(Vector3(tr[2], pn.y * tr[3], pn.x * tr[3]).normalized())
				st.add_vertex(s[0])
	# Les deux flancs plats.
	var tri := Geometry2D.triangulate_polygon(pts[0])
	if tri.is_empty():
		push_warning("Carrosserie : flanc impossible à trianguler")
	for cote: int in [0, tranches.size() - 1]:
		var tr: Array = tranches[cote]
		var p: PackedVector2Array = pts[cote]
		var sens := 1.0 if tr[0] > 0.0 else -1.0
		for k in range(0, tri.size(), 3):
			var ordre := [0, 2, 1] if sens < 0.0 else [0, 1, 2]
			for o: int in ordre:
				var v := p[tri[k + o]]
				st.set_normal(Vector3(sens, 0, 0))
				st.add_vertex(Vector3(tr[0], v.y, v.x))
	return st.commit()
