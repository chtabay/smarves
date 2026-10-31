extends Node3D
## Le van des chasseurs de pépites, sur la placette de la rue du Clain : un clin d'œil à Authentic
## Spirits, de vrais dénicheurs d'eaux-de-vie rares qui sillonnent les régions en van
## (https://www.authentic-spirits.com/). Capucine Varenne, leur chasseuse, est au Bar du Fumoir du
## casino (Lines.SPEAKERS.capucine) ; quand elle est en ville, son van dort sur la placette.
##
## Le village de départ ne change pas : jusqu'au seuil, c'est la camionnette bleue de toujours.
## À SEUIL crédits gagnés au jeu (celui de la Loggia), elle devient leur van : un fourgon moderne gris
## anthracite, le médaillon rond de la maison sur le flanc arrière, comme le vrai (photo de leur site).
## Loi Évin : un médaillon de maison et un millésime de fondation, pas une réclame ; rien ne s'y vend.

const SEUIL := 2000
const ENSEIGNE := "AUTHENTIC SPIRITS"
const FONDATION := "MMXX"
const PLAQUE := "AS-020-VN"
const ANTHRACITE := Color(0.34, 0.36, 0.39)
const BLANC := Color(0.9, 0.91, 0.92)
const OR := Color(0.86, 0.68, 0.3)

var van: Node3D
var livree := false
var _font: Font


## `car` : la camionnette déjà posée sur la placette ; `font` : la police des enseignes.
func setup(car: Node3D, font: Font) -> void:
	van = car
	_font = font
	name = "VanDesPepites"
	set_process(true)
	_check()


func _process(_delta: float) -> void:
	_check()


func _check() -> void:
	if livree or van == null:
		return
	if Game.won >= SEUIL:
		paint()


## La livrée : la camionnette du Car Kit s'efface (sa boîte de collision reste) et le van des chasseurs
## prend sa place, à sa mesure, bâti par l'atelier des véhicules (scripts/socle/carrosserie.gd) : un
## fourgon moderne au long pare-brise couché dans le capot, gris anthracite métallisé pailleté qui tourne au
## bleu acier en bord de forme, bas de caisse noir, vitres teintées, phares effilés, jantes acier sombres,
## antenne de toit, et le médaillon blanc « Authentic Spirits · MMXX » sur les deux flancs arrière.
func paint() -> void:
	livree = true
	set_process(false)
	# Les dimensions du van posé, dans son propre repère (il est ramené à 1,5 de long par Village._car).
	var box := _local_aabb(van)
	for mi in van.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	var caisse := Node3D.new()
	caisse.name = "Livree"
	van.add_child(caisse)
	# Le van est dessiné à 2,8 de long, l'avant vers +z ; on le ramène à la boîte de la camionnette.
	var long_x := box.size.x > box.size.z
	var k := maxf(box.size.x, box.size.z) / LONG
	caisse.scale = Vector3.ONE * k
	caisse.position = Vector3(box.get_center().x, box.position.y, box.get_center().z)
	if long_x:
		caisse.rotation_degrees.y = 90.0
	_build(caisse)


const LONG := 2.8
const LARGE := 1.42
## Sous cette hauteur, le bas de caisse noir (boucliers et bas de portes).
const BAS := 0.3
const ROUE_Z := 0.86
const ROUE_R := 0.28


func _build(c: Node3D) -> void:
	var w := LARGE / 2.0
	var laque := Carrosserie.laque(ANTHRACITE, Color(0.45, 0.55, 0.8), 0.22, Color(0.12, 0.125, 0.135), BAS)
	laque.set_shader_parameter("rugosite", 0.25)
	laque.set_shader_parameter("paillette_teinte", Color(0.8, 0.85, 1.0))
	var chrome := Carrosserie.chrome()
	var verre := Carrosserie.verre()
	verre.set_shader_parameter("vernis", 0.9)
	verre.set_shader_parameter("teinte", Color(0.05, 0.055, 0.065))
	var noir := Carrosserie.laque(Color(0.02, 0.02, 0.025), Color(0.2, 0.22, 0.3), 0.0)
	noir.set_shader_parameter("vernis", 0.4)
	# La caisse, de profil : passages de roue, nez court et bombé, capot plongeant prolongé par le
	# pare-brise couché, long pavillon plat, arrière droit aux coins arrondis.
	var p := PackedVector2Array([Vector2(-1.4, 0.2), Vector2(-1.36, 0.13)])
	for z: float in [-ROUE_Z, ROUE_Z]:
		p.append_array(Carrosserie.arc(Vector2(z, ROUE_R), 0.36, 207.0, -27.0, 12))
	p.append_array([Vector2(1.34, 0.13), Vector2(1.42, 0.22)])
	p.append_array(Carrosserie.arc(Vector2(1.2, 0.45), 0.24, -5.0, 70.0, 5))
	p.append_array(Carrosserie.arc(Vector2(1.05, 0.2), 0.62, 75.0, 82.0, 2))
	p.append_array([Vector2(0.9, 0.86), Vector2(0.34, 1.22)])
	p.append_array(Carrosserie.arc(Vector2(0.16, 1.02), 0.21, 60.0, 90.0, 3))
	p.append_array(Carrosserie.arc(Vector2(-1.24, 1.08), 0.16, 90.0, 180.0, 4))
	_mesh(c, Carrosserie.galbe(p, LARGE, 0.2), laque)
	# Le pare-brise, couché dans la ligne du capot, cerné de noir.
	var pb := [Vector3(-w + 0.2, 0.88, 0.89), Vector3(w - 0.2, 0.88, 0.89), Vector3(w - 0.22, 1.2, 0.37), Vector3(-w + 0.22, 1.2, 0.37)]
	_quad(c, pb, verre, 0.006)
	_cadre(c, pb, Vector3(0, 0.0085, 0.0052), noir, 0.012)
	for s: float in [-1.0, 1.0]:
		var x := (w + 0.003) * s
		# Les vitres : la porte avant, la porte coulissante ; le flanc arrière plein, pour le médaillon.
		for v: Array in [[Vector3(x, 0.84, -0.02), Vector3(x, 0.84, 0.82), Vector3(x, 1.12, 0.42), Vector3(x, 1.12, -0.02)],
				[Vector3(x, 0.84, -0.66), Vector3(x, 0.84, -0.08), Vector3(x, 1.12, -0.08), Vector3(x, 1.12, -0.66)]]:
			_quad(c, v, verre, 0.0, s < 0.0)
			_cadre(c, v, Vector3(0.004 * s, 0, 0), noir, 0.012)
		# Les joints des portes, le rail de la porte coulissante, les poignées.
		for z: float in [-0.04, -0.7]:
			_box(c, Vector3(0.006, 0.5, 0.008), Vector3(x + 0.002 * s, 0.58, z), noir)
		_box(c, Vector3(0.008, 0.014, 1.1), Vector3(x + 0.003 * s, 0.7, -0.88), noir)
		for z: float in [0.2, -0.22]:
			_box(c, Vector3(0.016, 0.022, 0.1), Vector3(x + 0.006 * s, 0.68, z), noir)
		# Le bas de caisse : un jonc noir au-dessus du bouclier.
		_box(c, Vector3(0.012, 0.03, 2.3), Vector3(x + 0.004 * s, BAS + 0.02, 0.0), noir)
		# Le rétroviseur, noir, au pied du montant.
		_box(c, Vector3(0.08, 0.03, 0.04), Vector3(x + 0.03 * s, 0.86, 0.8), noir)
		_box(c, Vector3(0.05, 0.11, 0.13), Vector3(x + 0.08 * s, 0.89, 0.79), laque)
		for z: float in [-ROUE_Z, ROUE_Z]:
			_roue(c, Vector3((w - 0.13) * s, ROUE_R, z), s, chrome)
		_medaillon(c, Vector3(x + 0.004 * s, 0.86, -1.02), 90.0 if s > 0.0 else -90.0)
	# L'avant : calandre noire et son jonc chromé, phares effilés qui remontent vers les ailes.
	_box(c, Vector3(0.78, 0.13, 0.03), Vector3(0, 0.38, 1.43), noir)
	_capsule(c, 0.012, 0.74, Vector3(0, 0.46, 1.425), chrome)
	for s: float in [-1.0, 1.0]:
		var phare := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.3, 0.06, 0.04)
		phare.mesh = pm
		phare.material_override = Carrosserie.feu(Color(0.95, 0.97, 1.0), 1.4)
		phare.position = Vector3(0.44 * s, 0.6, 1.33)
		phare.rotation_degrees = Vector3(-30, -18 * s, 8 * s)
		c.add_child(phare)
		_box(c, Vector3(0.12, 0.03, 0.03), Vector3(0.5 * s, 0.27, 1.43), Carrosserie.feu(Color(1.0, 0.6, 0.2), 1.0))
		# À l'arrière, les grands feux verticaux sur les montants.
		_box(c, Vector3(0.08, 0.24, 0.03), Vector3(0.6 * s, 0.76, -1.405), Carrosserie.feu(Color(0.85, 0.04, 0.03), 0.7))
	_box(c, Vector3(LARGE - 0.04, 0.16, 0.05), Vector3(0, 0.24, 1.415), laque)
	_box(c, Vector3(LARGE - 0.04, 0.16, 0.05), Vector3(0, 0.24, -1.39), laque)
	# L'arrière : deux battants à la lunette teintée, le jonc qui les sépare, la plaque.
	var lunette := [Vector3(w - 0.22, 0.78, -1.405), Vector3(-w + 0.22, 0.78, -1.405), Vector3(-w + 0.22, 1.08, -1.405), Vector3(w - 0.22, 1.08, -1.405)]
	_quad(c, lunette, verre)
	_cadre(c, lunette, Vector3(0, 0, -0.004), noir, 0.012)
	_box(c, Vector3(0.012, 0.75, 0.01), Vector3(0, 0.7, -1.41), noir)
	_box(c, Vector3(0.5, 0.11, 0.012), Vector3(0, 0.42, -1.413), Carrosserie.mat(Color(0.93, 0.93, 0.9), 0.5))
	_letters(c, PLAQUE, Vector3(0, 0.42, -1.421), 180.0, 0.42, 0.0, Color(0.08, 0.08, 0.1), false)
	# Sur le pavillon : l'antenne fouet de la photo, vers l'avant.
	var ant := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.005
	am.bottom_radius = 0.012
	am.height = 0.15
	ant.mesh = am
	ant.material_override = noir
	ant.position = Vector3(0.0, 1.29, 0.2)
	ant.rotation_degrees.x = -30.0
	c.add_child(ant)


## Le médaillon de la maison, peint sur le flanc arrière : un disque cerclé de blanc, le nom en couronne,
## un trait au milieu et le millésime de fondation dessous, comme sur le vrai van.
func _medaillon(c: Node3D, at: Vector3, yaw: float) -> void:
	var m := Node3D.new()
	m.name = "Medaillon"
	m.position = at
	m.rotation_degrees.y = yaw
	c.add_child(m, true)
	var blanc := Carrosserie.laque(BLANC, BLANC, 0.0)
	blanc.set_shader_parameter("vernis", 0.6)
	var fond := Carrosserie.laque(Color(0.16, 0.2, 0.28), Color(0.4, 0.5, 0.7), 0.3)
	for d: Array in [[0.25, 0.0, blanc], [0.235, 0.002, fond], [0.17, 0.004, blanc], [0.16, 0.006, fond]]:
		var cy := CylinderMesh.new()
		cy.top_radius = d[0]
		cy.bottom_radius = d[0]
		cy.height = 0.004
		cy.radial_segments = 40
		var mi := _mesh(m, cy, d[2])
		mi.position = Vector3(0, 0, float(d[1]))
		mi.rotation_degrees.x = 90.0
	# Le nom en couronne sur le haut du cercle, une lettre à la fois.
	var r := 0.2
	var n := ENSEIGNE.length()
	for i in n:
		var ch := ENSEIGNE[i]
		if ch == " ":
			continue
		var t := deg_to_rad(lerpf(150.0, 30.0, float(i) / (n - 1)))
		var l := _label(ch, BLANC, 0.05)
		l.position = Vector3(cos(t) * r, sin(t) * r, 0.008)
		l.rotation_degrees.z = rad_to_deg(t) - 90.0
		m.add_child(l)
	var milli := _label(FONDATION, BLANC, 0.065)
	milli.position = Vector3(0, -0.2, 0.008)
	m.add_child(milli)
	# Au cœur : une goutte dorée sur un trait, la chasse aux pépites.
	_box(m, Vector3(0.18, 0.008, 0.004), Vector3(0, -0.04, 0.009), blanc)
	var goutte := SphereMesh.new()
	goutte.radius = 0.045
	goutte.height = 0.11
	_mesh(m, goutte, Carrosserie.dore()).position = Vector3(0, 0.03, 0.01)


func _label(text: String, color: Color, hauteur: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	if _font:
		l.font = _font
	l.font_size = 64
	l.outline_size = 0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.modulate = color
	l.double_sided = false
	l.pixel_size = hauteur / 64.0
	return l


func _mesh(c: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	c.add_child(mi)
	return mi


func _box(c: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var b := BoxMesh.new()
	b.size = size
	_mesh(c, b, mat).position = at


## Une barre arrondie couchée en travers (axe x), ou en long (axe z) si `long`.
func _capsule(c: Node3D, r: float, longueur: float, at: Vector3, mat: Material, long := false) -> void:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = longueur
	m.radial_segments = 16
	m.rings = 4
	var mi := _mesh(c, m, mat)
	mi.position = at
	mi.rotation_degrees = Vector3(90, 0, 0) if long else Vector3(0, 0, 90)


## Un disque tourné vers l'avant (axe z) : cerclage de phare, verre de feu.
func _rond(c: Node3D, at: Vector3, r: float, ep: float, mat: Material) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = ep
	m.radial_segments = 20
	var mi := _mesh(c, m, mat)
	mi.position = at
	mi.rotation_degrees.x = 90.0


## Une roue tournée vers le flanc `s` : pneu, flanc blanc, enjoliveur chromé bombé.
func _roue(c: Node3D, at: Vector3, s: float, chrome: Material) -> void:
	var sombre := Carrosserie.mat(Color(0.03, 0.03, 0.035), 0.9)
	var acier := Carrosserie.laque(Color(0.16, 0.17, 0.18), Color(0.4, 0.45, 0.55), 0.0)
	var pieces := [[ROUE_R, 0.2, sombre, 0.0], [ROUE_R * 0.68, 0.012, acier, 0.1], [ROUE_R * 0.56, 0.012, sombre, 0.104]]
	for piece: Array in pieces:
		var m := CylinderMesh.new()
		m.top_radius = piece[0]
		m.bottom_radius = piece[0]
		m.height = piece[1]
		m.radial_segments = 24
		var mi := _mesh(c, m, piece[2])
		mi.position = at + Vector3(float(piece[3]) * s, 0, 0)
		mi.rotation_degrees.z = 90.0
	# La jante argent à cinq branches, et son cache-moyeu.
	for i in 5:
		var br := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, ROUE_R * 0.56, 0.035)
		br.mesh = bm
		br.material_override = acier
		br.rotation_degrees.x = i * 72.0
		br.position = at + Vector3(0.108 * s, 0, 0) + Basis(Vector3.RIGHT, deg_to_rad(i * 72.0)) * Vector3(0, ROUE_R * 0.28, 0)
		c.add_child(br)
	var dome := SphereMesh.new()
	dome.radius = ROUE_R * 0.14
	dome.height = ROUE_R * 0.14
	dome.is_hemisphere = true
	var mi := _mesh(c, dome, chrome)
	mi.position = at + Vector3(0.11 * s, 0, 0)
	mi.rotation_degrees.z = -90.0 * s


## Un jonc chromé tout autour d'une vitre (ses quatre coins), décalé de `decal`.
func _cadre(c: Node3D, coins: Array, decal: Vector3, mat: Material, r := 0.014) -> void:
	for i in 4:
		var a: Vector3 = (coins[i] as Vector3) + decal
		var b: Vector3 = (coins[(i + 1) % 4] as Vector3) + decal
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = a.distance_to(b) + r * 2.0
		m.radial_segments = 8
		m.rings = 2
		var mi := _mesh(c, m, mat)
		mi.position = (a + b) / 2.0
		mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))


## Un quadrilatère (quatre coins dans l'ordre), décollé de `decol` le long de sa normale.
func _quad(c: Node3D, coins: Array, mat: Material, decol := 0.0, inverse := false) -> void:
	var a: Vector3 = coins[0]
	var nrm := ((coins[1] as Vector3) - a).cross((coins[3] as Vector3) - a).normalized()
	if inverse:
		nrm = -nrm
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ordre := [0, 1, 2, 0, 2, 3] if not inverse else [0, 2, 1, 0, 3, 2]
	for i: int in ordre:
		st.set_normal(nrm)
		st.add_vertex((coins[i] as Vector3) + nrm * decol)
	_mesh(c, st.commit(), mat)


## Des lettres dorées à l'ombre portée : une doublure sombre décalée sous les lettres, qui les détache.
func _letters(c: Node3D, text: String, at: Vector3, yaw: float, span: float, dy: float, color := OR, ombre := true) -> void:
	var normale := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
	var couches := [[color, Vector3.ZERO]]
	if ombre:
		var droite := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(1, 0, 0)
		couches.push_front([Color(0.12, 0.07, 0.02), droite * span * 0.006 + Vector3(0, -span * 0.008, 0) - normale * 0.002])
	for couche: Array in couches:
		var l := Label3D.new()
		l.text = text
		if _font:
			l.font = _font
		l.font_size = 96
		l.outline_size = 0
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		l.modulate = couche[0]
		l.double_sided = false
		# Largeur visée : `span`, à peu près 0,72 de point de police par caractère.
		l.pixel_size = span / maxf(1.0, text.length() * 96.0 * 0.72)
		l.position = at + Vector3(0, dy, 0) + (couche[1] as Vector3)
		l.rotation_degrees.y = yaw
		c.add_child(l)


## La boîte du van dans son propre repère (sans sa rotation ni son échelle sur la placette).
func _local_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (inv * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
