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


# --- Les pièces, pour bâtir un véhicule dans le repère de sa caisse -----------------------------------

## Remplace l'habit d'un modèle de kit par une caisse dessinée à `longueur` (l'avant vers +z, le sol en
## y = 0) : les maillages du kit s'effacent (les collisions, lumières et scripts restent), la caisse est
## posée à leur place et à leur taille. Rend le nœud où bâtir.
static func habiller(modele: Node3D, longueur: float) -> Node3D:
	var box := AABB()
	var first := true
	var inv := modele.global_transform.affine_inverse()
	for n in modele.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
		mi.visible = false
	var caisse := Node3D.new()
	caisse.name = "Caisse"
	modele.add_child(caisse)
	var long_x := box.size.x > box.size.z
	caisse.scale = Vector3.ONE * maxf(box.size.x, box.size.z) / longueur
	caisse.position = Vector3(box.get_center().x, box.position.y, box.get_center().z)
	if long_x:
		caisse.rotation_degrees.y = 90.0
	return caisse


static func piece(parent: Node3D, mesh: Mesh, mat: Material, at := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func boite(parent: Node3D, taille: Vector3, at: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = taille
	return piece(parent, b, mat, at, rot)


## Un disque d'axe x (roue, `ep` d'épaisseur) ou d'axe z si `face` (phare, feu).
static func disque(parent: Node3D, r: float, ep: float, at: Vector3, mat: Material, face := false) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = ep
	m.radial_segments = 24
	return piece(parent, m, mat, at, Vector3(90, 0, 0) if face else Vector3(0, 0, 90))


## Un jonc arrondi de `a` à `b`.
static func jonc(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = a.distance_to(b) + r * 2.0
	m.radial_segments = 8
	m.rings = 2
	var mi := piece(parent, m, mat, (a + b) / 2.0)
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return mi


## Un quadrilatère plein (quatre coins dans l'ordre, sa face vers `vers`), décollé de `decol`.
static func plaque(parent: Node3D, coins: Array, mat: Material, vers: Vector3, decol := 0.0) -> MeshInstance3D:
	var a: Vector3 = coins[0]
	var nrm := ((coins[1] as Vector3) - a).cross((coins[3] as Vector3) - a).normalized()
	var ordre := [0, 1, 2, 0, 2, 3]
	if nrm.dot(vers) < 0.0:
		nrm = -nrm
		ordre = [0, 2, 1, 0, 3, 2]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in ordre:
		st.set_normal(nrm)
		st.add_vertex((coins[i] as Vector3) + nrm * decol)
	return piece(parent, st.commit(), mat)


## Le tour d'une vitre (ses coins), en joncs.
static func cadre(parent: Node3D, coins: Array, r: float, mat: Material, decal := Vector3.ZERO) -> void:
	for i in coins.size():
		jonc(parent, (coins[i] as Vector3) + decal, (coins[(i + 1) % coins.size()] as Vector3) + decal, r, mat)


## Une inscription peinte, tournée de `lacet` degrés, haute de `hauteur`.
static func inscription(parent: Node3D, texte: String, at: Vector3, lacet: float, hauteur: float, teinte: Color, police: Font = null) -> Label3D:
	var l := Label3D.new()
	l.text = texte
	if police:
		l.font = police
	l.font_size = 64
	l.outline_size = 0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.modulate = teinte
	l.double_sided = false
	l.pixel_size = hauteur / 64.0
	l.position = at
	l.rotation_degrees.y = lacet
	parent.add_child(l)
	return l
