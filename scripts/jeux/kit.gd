extends RefCounted
## La boîte à outils des tables de jeu : matériaux (feutre, bois verni, laiton), pièces tournées,
## jetons, cartes, dés, étincelles et annonces de gain. Tout est fabriqué par le code ; les textures
## avec du texte sont dessinées une fois dans des vues hors écran accrochées à la racine, pour
## survivre aux changements de scène.

const FELT_SHADER := preload("res://shaders/felt.gdshader")

## Les jetons : valeur -> [couleur du fond, couleur des inserts].
const CHIP_STYLES := {
	1: [Color(0.93, 0.91, 0.86), Color(0.16, 0.36, 0.69)],
	5: [Color(0.72, 0.07, 0.1), Color(0.96, 0.93, 0.86)],
	10: [Color(0.13, 0.32, 0.72), Color(0.96, 0.93, 0.86)],
	25: [Color(0.1, 0.45, 0.22), Color(0.96, 0.93, 0.86)],
	100: [Color(0.07, 0.07, 0.08), Color(0.92, 0.74, 0.36)],
	500: [Color(0.4, 0.15, 0.58), Color(0.96, 0.88, 0.6)],
	1000: [Color(0.92, 0.88, 0.78), Color(0.75, 0.55, 0.2)],
	5000: [Color(0.78, 0.53, 0.18), Color(0.98, 0.95, 0.85)],
}
const CHIP_R := 0.026
const CHIP_H := 0.0045

const CARD_W := 0.088
const CARD_H := 0.123
const SUIT_NAMES := ["pique", "coeur", "carreau", "trefle"]
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R"]

static var _mats := {}
static var _meshes := {}
static var _tex := {}
static var _font: Font


# --- Racine persistante pour les vues hors écran ----------------------------------------

static func _holder() -> Node:
	var root: Window = Engine.get_main_loop().root
	var h := root.get_node_or_null("TablesKit")
	if h == null:
		h = Node.new()
		h.name = "TablesKit"
		root.add_child.call_deferred(h)
		# Tant qu'il n'est pas dans l'arbre, on le retrouve par la méta de la racine.
		root.set_meta("tables_kit", h)
	return h


static func _add_viewport(vp: SubViewport) -> void:
	var root: Window = Engine.get_main_loop().root
	var h: Node = root.get_meta("tables_kit") if root.has_meta("tables_kit") else null
	if h == null or not is_instance_valid(h):
		h = _holder()
	h.add_child(vp)


## Les tapis imprimés et les bandeaux peints, partagés par les tables qui les ont pareils : une
## table demande sa vue par une clé qui dit tout ce qui change le dessin (« baccara:MINUIT:false ») ; la
## première la peint, les suivantes reprennent la même texture, au pixel près. Six blackjacks ne gardent
## qu'un tapis en mémoire. Les vues restent d'une scène à l'autre, comme les jetons et les cartes.
static var _vues := {}


## La texture déjà peinte sous cette clé, ou null.
static func vue_partagee(cle: String) -> Texture2D:
	var vp = _vues.get(cle)
	return vp.get_texture() if vp != null and is_instance_valid(vp) else null


## Garde la vue sous cette clé et rend sa texture.
static func partager(cle: String, vp: SubViewport) -> Texture2D:
	_add_viewport(vp)
	_vues[cle] = vp
	return vp.get_texture()


static func serif() -> Font:
	if _font == null:
		_font = Polices.gras()
	return _font


# --- Matériaux ---------------------------------------------------------------------------

static func mat(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func brass() -> StandardMaterial3D:
	if not _mats.has("brass"):
		var m := mat(Color(0.93, 0.7, 0.36), 0.22, 1.0)
		m.anisotropy_enabled = true
		m.anisotropy = 0.4
		_mats["brass"] = m
	return _mats["brass"]


static func chrome() -> StandardMaterial3D:
	if not _mats.has("chrome"):
		_mats["chrome"] = mat(Color(0.9, 0.9, 0.93), 0.08, 1.0)
	return _mats["chrome"]


## Bois verni : fil du bois étiré et vernis (couche de clearcoat).
static func varnished(c: Color, gloss := 0.9) -> StandardMaterial3D:
	var key := "wood_%s_%.2f" % [c.to_html(), gloss]
	if _mats.has(key):
		return _mats[key]
	var m := mat(c, 0.42)
	m.albedo_texture = _grain()
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.6, 5.0, 0.6)
	m.clearcoat_enabled = true
	m.clearcoat = gloss
	m.clearcoat_roughness = 0.12
	_mats[key] = m
	return m


static func _grain() -> Texture2D:
	if _tex.has("grain"):
		return _tex["grain"]
	var n := FastNoiseLite.new()
	n.frequency = 0.015
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 128
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.52, 0.5))
	g.set_color(1, Color(1.08, 1.0, 0.95))
	t.color_ramp = g
	_tex["grain"] = Memo.bruit("kit", "res://scripts/jeux/kit.gd", "grain", t)
	return _tex["grain"]


static func leather(c := Color(0.16, 0.05, 0.03)) -> StandardMaterial3D:
	var key := "leather_" + c.to_html()
	if not _mats.has(key):
		var m := mat(c, 0.38)
		var n := FastNoiseLite.new()
		n.frequency = 0.35
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.seamless = true
		t.as_normal_map = true
		t.bump_strength = 1.5
		t.noise = n
		m.normal_enabled = true
		m.normal_texture = Memo.bruit("kit", "res://scripts/jeux/kit.gd", "cuir", t)
		m.normal_scale = 0.35
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 6.0
		m.clearcoat_enabled = true
		m.clearcoat = 0.4
		m.clearcoat_roughness = 0.4
		_mats[key] = m
	return _mats[key]


static func felt(c: Color, size_m: Vector2, layout: Texture2D = null) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FELT_SHADER
	m.set_shader_parameter("felt_col", c)
	m.set_shader_parameter("size_m", size_m)
	if layout:
		m.set_shader_parameter("layout_tex", layout)
		m.set_shader_parameter("use_layout", true)
	return m


static func glow(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := mat(c, 0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


# --- Pièces tournées ----------------------------------------------------------------------

## Fait tourner un profil (rayon, hauteur) autour de l'axe vertical. Le profil se parcourt de
## l'extérieur vers l'intérieur en montant : les normales pointent alors vers l'extérieur.
## Les angles vifs (plus de 35°) restent vifs. u fait le tour, v suit le profil.
static func lathe(profile: PackedVector2Array, segments := 64, v_repeat := 1.0, arc := TAU) -> ArrayMesh:
	var n := profile.size()
	var lens := PackedFloat32Array([0.0])
	for i in range(1, n):
		lens.append(lens[i - 1] + profile[i].distance_to(profile[i - 1]))
	var total := maxf(lens[n - 1], 0.0001)
	var seg_n: Array[Vector2] = []
	for i in n - 1:
		var d := (profile[i + 1] - profile[i]).normalized()
		seg_n.append(Vector2(d.y, -d.x))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n - 1:
		var na := seg_n[i]
		var nb := seg_n[i]
		if i > 0 and seg_n[i - 1].dot(seg_n[i]) > 0.82:
			na = (seg_n[i - 1] + seg_n[i]).normalized()
		if i < n - 2 and seg_n[i + 1].dot(seg_n[i]) > 0.82:
			nb = (seg_n[i + 1] + seg_n[i]).normalized()
		for s in segments:
			var a0 := arc * s / segments
			var a1 := arc * (s + 1) / segments
			var u0 := float(s) / segments
			var u1 := float(s + 1) / segments
			var v0 := lens[i] / total * v_repeat
			var v1 := lens[i + 1] / total * v_repeat
			var p := [_rv(profile[i], a0), _rv(profile[i], a1), _rv(profile[i + 1], a0), _rv(profile[i + 1], a1)]
			var nn := [_rn(na, a0), _rn(na, a1), _rn(nb, a0), _rn(nb, a1)]
			var uv := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u0, v1), Vector2(u1, v1)]
			_tri(st, p, nn, uv, 0, 2, 1)
			_tri(st, p, nn, uv, 1, 2, 3)
	return st.commit()


static func _rv(p: Vector2, a: float) -> Vector3:
	return Vector3(cos(a) * p.x, p.y, sin(a) * p.x)


static func _rn(n: Vector2, a: float) -> Vector3:
	return Vector3(cos(a) * n.x, n.y, sin(a) * n.x).normalized()


## Un triangle, remis dans l'ordre que Godot attend pour une face avant (sens horaire vu de face).
static func _tri(st: SurfaceTool, p: Array, nn: Array, uv: Array, a: int, b: int, c: int) -> void:
	var face: Vector3 = (p[b] - p[a]).cross(p[c] - p[a])
	var avg: Vector3 = nn[a] + nn[b] + nn[c]
	if face.length_squared() < 1e-14:
		return
	var order := [a, b, c] if face.dot(avg) < 0.0 else [a, c, b]
	for k in order:
		st.set_normal(nn[k])
		st.set_uv(uv[k])
		st.add_vertex(p[k])


## Un disque plat, normale vers le haut, UV à plat (0..1 sur le diamètre).
static func disc(r: float, segments := 48) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		var p := [Vector3.ZERO, Vector3(cos(a0) * r, 0, sin(a0) * r), Vector3(cos(a1) * r, 0, sin(a1) * r)]
		var uv := [Vector2(0.5, 0.5), Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5), Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5)]
		_tri(st, p, [Vector3.UP, Vector3.UP, Vector3.UP], uv, 0, 1, 2)
	return st.commit()


static func mesh_node(m: Mesh, material: Material, parent: Node3D, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


static func box(size: Vector3, pos: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return mesh_node(bm, material, parent, pos)


static func cyl(r: float, h: float, pos: Vector3, material: Material, parent: Node3D, r_top := -1.0, sides := 32) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = sides
	return mesh_node(cm, material, parent, pos)


static func sphere(r: float, pos: Vector3, material: Material, parent: Node3D, sides := 24) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = sides
	sm.rings = sides / 2
	return mesh_node(sm, material, parent, pos)


## Un boudin rembourré (main courante) d'un point à un autre, terminé par deux boules.
static func rail(a: Vector3, b: Vector3, r: float, material: Material, parent: Node3D) -> void:
	var c := cyl(r, a.distance_to(b), (a + b) / 2.0, material, parent, -1.0, 24)
	var d := (b - a).normalized()
	c.basis = Basis(_perp(d), d, _perp(d).cross(d)).orthonormalized()
	sphere(r, a, material, parent)
	sphere(r, b, material, parent)


static func _perp(d: Vector3) -> Vector3:
	var p := d.cross(Vector3.UP)
	if p.length() < 0.01:
		p = d.cross(Vector3.RIGHT)
	return p.normalized()


## Un pied de table tourné en balustre.
static func turned_leg(h: float, r: float, material: Material, parent: Node3D, pos: Vector3) -> void:
	var prof := PackedVector2Array([
		Vector2(r * 0.9, 0), Vector2(r * 1.1, h * 0.03), Vector2(r * 0.7, h * 0.08), Vector2(r * 0.55, h * 0.3),
		Vector2(r * 1.0, h * 0.5), Vector2(r * 0.6, h * 0.65), Vector2(r * 0.7, h * 0.85), Vector2(r * 1.0, h * 0.9),
		Vector2(r * 1.0, h), Vector2(0.0, h)])
	mesh_node(lathe(prof, 20), material, parent, pos)


# --- Jetons ----------------------------------------------------------------------------

static func chip_style(value: int) -> Array:
	if CHIP_STYLES.has(value):
		return CHIP_STYLES[value]
	var best := 1
	for k in CHIP_STYLES:
		if k <= value:
			best = k
	return CHIP_STYLES[best]


## La tranche d'un jeton : fond, six inserts, liseré sombre entre deux jetons empilés.
static func _chip_edge_tex(value: int) -> Texture2D:
	var key := "edge_%d" % value
	if _tex.has(key):
		return _tex[key]
	var st: Array = chip_style(value)
	var img := Image.create(256, 32, false, Image.FORMAT_RGBA8)
	img.fill(st[0])
	for k in 6:
		img.fill_rect(Rect2i(k * 42 + 6, 4, 22, 24), st[1])
	img.fill_rect(Rect2i(0, 0, 256, 2), st[0].darkened(0.55))
	img.fill_rect(Rect2i(0, 30, 256, 2), st[0].darkened(0.55))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## Les faces des jetons, avec leur valeur, dans un atlas dessiné une fois.
static func _chip_faces() -> Texture2D:
	if _tex.has("faces") and is_instance_valid(_tex["faces_vp"]):
		return _tex["faces"]
	var vals := CHIP_STYLES.keys()
	var vp := SubViewport.new()
	vp.size = Vector2i(256 * vals.size(), 256)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	c.draw.connect(func():
		for i in vals.size():
			var st: Array = chip_style(vals[i])
			var o := Vector2(i * 256 + 128, 128)
			c.draw_circle(o, 127.0, st[0])
			for k in 8:
				var a := TAU * k / 8.0
				var pts := PackedVector2Array()
				for j in 5:
					var aa := a - 0.17 + 0.34 * j / 4.0
					pts.append(o + Vector2(cos(aa), sin(aa)) * 127.0)
				for j in 5:
					var aa := a + 0.17 - 0.34 * j / 4.0
					pts.append(o + Vector2(cos(aa), sin(aa)) * 100.0)
				c.draw_colored_polygon(pts, st[1])
			c.draw_arc(o, 88.0, 0, TAU, 64, st[1], 5.0, true)
			c.draw_circle(o, 80.0, st[0].lightened(0.08))
			var txt := str(vals[i]) if vals[i] < 1000 else "%dK" % (vals[i] / 1000)
			var fs := 74 if txt.length() <= 2 else (58 if txt.length() == 3 else 50)
			var ink: Color = st[1] if st[0].get_luminance() > 0.5 else Color(0.97, 0.94, 0.86)
			c.draw_string(serif(), o + Vector2(-80, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, 160, fs, ink)
	)
	_add_viewport(vp)
	_tex["faces"] = vp.get_texture()
	_tex["faces_vp"] = vp
	return _tex["faces"]


static func _chip_side_mat(value: int, count: int) -> StandardMaterial3D:
	var key := "chip_side_%d" % value
	if not _mats.has(key):
		var m := mat(Color.WHITE, 0.35)
		m.albedo_texture = _chip_edge_tex(value)
		m.clearcoat_enabled = true
		m.clearcoat = 0.3
		_mats[key] = m
	return _mats[key]


static func _chip_top_mat(value: int) -> StandardMaterial3D:
	var key := "chip_top_%d" % value
	if not _mats.has(key):
		var vals := CHIP_STYLES.keys()
		var idx := vals.find(value)
		if idx < 0:
			idx = vals.find(_nearest_style(value))
		var m := mat(Color.WHITE, 0.35)
		m.albedo_texture = _chip_faces()
		m.uv1_scale = Vector3(1.0 / vals.size(), 1.0, 1.0)
		m.uv1_offset = Vector3(float(idx) / vals.size(), 0.0, 0.0)
		m.clearcoat_enabled = true
		m.clearcoat = 0.3
		_mats[key] = m
	return _mats[key]


static func _nearest_style(value: int) -> int:
	var best := 1
	for k in CHIP_STYLES:
		if k <= value:
			best = k
	return best


## Décompose un montant en jetons, les plus gros en bas (au plus « cap » jetons).
static func breakdown(amount: int, denoms: Array = [5000, 1000, 500, 100, 25, 5, 1], cap := 14) -> Array:
	var out := []
	var rest := amount
	for d in denoms:
		while rest >= d and out.size() < cap:
			out.append(d)
			rest -= d
	return out


## Une pile de jetons : par valeur, une tranche répétée et une face sur le dessus. Légèrement
## désalignée, comme posée à la main.
static func chip_stack(amount: int, denoms: Array = [5000, 1000, 500, 100, 25, 5, 1], cap := 14) -> Node3D:
	var root := Node3D.new()
	var chips := breakdown(amount, denoms, cap)
	var y := 0.0
	var i := 0
	while i < chips.size():
		var v: int = chips[i]
		var n := 1
		while i + n < chips.size() and chips[i + n] == v:
			n += 1
		var key := "side_%d" % n
		if not _meshes.has(key):
			_meshes[key] = lathe(PackedVector2Array([Vector2(CHIP_R, 0), Vector2(CHIP_R, CHIP_H * n)]), 32, float(n))
		var side := mesh_node(_meshes[key], _chip_side_mat(v, n), root, Vector3(randf_range(-0.0012, 0.0012), y, randf_range(-0.0012, 0.0012)))
		side.rotation.y = randf() * TAU
		y += CHIP_H * n
		i += n
		if i >= chips.size() or chips[i] != v:
			if not _meshes.has("chip_top"):
				_meshes["chip_top"] = disc(CHIP_R * 0.995, 32)
			var top := mesh_node(_meshes["chip_top"], _chip_top_mat(v), root, side.position + Vector3(0, CHIP_H * n + 0.0002, 0))
			top.rotation.y = randf() * TAU
	root.set_meta("height", y)
	return root


# --- Cartes ----------------------------------------------------------------------------

## L'atlas des 52 cartes et du dos (13 colonnes, 5 rangées : pique, cœur, carreau, trèfle, dos).
static func card_atlas() -> Texture2D:
	if _tex.has("cards") and is_instance_valid(_tex["cards_vp"]):
		return _tex["cards"]
	var cw := 180
	var ch := 252
	var vp := SubViewport.new()
	vp.size = Vector2i(cw * 13, ch * 5)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	vp.add_child(c)
	c.draw.connect(func():
		for s in 4:
			for r in 13:
				_draw_card_face(c, Rect2(r * cw, s * ch, cw, ch), r, s)
		_draw_card_back(c, Rect2(0, 4 * ch, cw, ch))
	)
	_add_viewport(vp)
	_tex["cards"] = vp.get_texture()
	_tex["cards_vp"] = vp
	return _tex["cards"]


static func _rounded(c: Control, r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	c.draw_style_box(sb, r)


static func suit_color(s: int) -> Color:
	return Color(0.76, 0.06, 0.1) if s in [1, 2] else Color(0.07, 0.07, 0.09)


## Les quatre enseignes, dessinées en vectoriel (aucune police n'est nécessaire).
static func draw_suit(c: Control, s: int, at: Vector2, size: float, col: Color, flip := false, rot := 0.0) -> void:
	c.draw_set_transform(at, (PI if flip else 0.0) + rot, Vector2.ONE)
	var k := size
	match s:
		1:
			c.draw_circle(Vector2(-k * 0.24, -k * 0.12), k * 0.27, col)
			c.draw_circle(Vector2(k * 0.24, -k * 0.12), k * 0.27, col)
			c.draw_colored_polygon(PackedVector2Array([Vector2(-k * 0.5, -k * 0.04), Vector2(k * 0.5, -k * 0.04), Vector2(0, k * 0.5)]), col)
		2:
			c.draw_colored_polygon(PackedVector2Array([Vector2(0, -k * 0.52), Vector2(k * 0.38, 0), Vector2(0, k * 0.52), Vector2(-k * 0.38, 0)]), col)
		0:
			c.draw_circle(Vector2(-k * 0.24, k * 0.1), k * 0.26, col)
			c.draw_circle(Vector2(k * 0.24, k * 0.1), k * 0.26, col)
			c.draw_colored_polygon(PackedVector2Array([Vector2(-k * 0.49, k * 0.04), Vector2(k * 0.49, k * 0.04), Vector2(0, -k * 0.5)]), col)
			c.draw_colored_polygon(PackedVector2Array([Vector2(0, k * 0.1), Vector2(k * 0.17, k * 0.52), Vector2(-k * 0.17, k * 0.52)]), col)
		3:
			c.draw_circle(Vector2(0, -k * 0.22), k * 0.22, col)
			c.draw_circle(Vector2(-k * 0.24, k * 0.08), k * 0.22, col)
			c.draw_circle(Vector2(k * 0.24, k * 0.08), k * 0.22, col)
			c.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(k * 0.17, k * 0.52), Vector2(-k * 0.17, k * 0.52)]), col)
	c.draw_set_transform(Vector2.ZERO)


const PIPS := {
	1: [[0.5, 0.5]],
	2: [[0.5, 0.0], [0.5, 1.0]],
	3: [[0.5, 0.0], [0.5, 0.5], [0.5, 1.0]],
	4: [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0]],
	5: [[0.0, 0.0], [1.0, 0.0], [0.5, 0.5], [0.0, 1.0], [1.0, 1.0]],
	6: [[0.0, 0.0], [1.0, 0.0], [0.0, 0.5], [1.0, 0.5], [0.0, 1.0], [1.0, 1.0]],
	7: [[0.0, 0.0], [1.0, 0.0], [0.5, 0.25], [0.0, 0.5], [1.0, 0.5], [0.0, 1.0], [1.0, 1.0]],
	8: [[0.0, 0.0], [1.0, 0.0], [0.5, 0.25], [0.0, 0.5], [1.0, 0.5], [0.5, 0.75], [0.0, 1.0], [1.0, 1.0]],
	9: [[0.0, 0.0], [1.0, 0.0], [0.0, 0.333], [1.0, 0.333], [0.5, 0.5], [0.0, 0.667], [1.0, 0.667], [0.0, 1.0], [1.0, 1.0]],
	10: [[0.0, 0.0], [1.0, 0.0], [0.5, 0.17], [0.0, 0.333], [1.0, 0.333], [0.0, 0.667], [1.0, 0.667], [0.5, 0.83], [0.0, 1.0], [1.0, 1.0]],
}


static func _draw_card_face(c: Control, cell: Rect2, r: int, s: int) -> void:
	var card := cell.grow(-3)
	_rounded(c, card, 16, Color(0.78, 0.76, 0.72))
	_rounded(c, card.grow(-1.5), 15, Color(0.93, 0.92, 0.88))
	var col := suit_color(s)
	var f := serif()
	var o := card.position
	var w := card.size.x
	var h := card.size.y
	# Les index, en haut à gauche et (retournés) en bas à droite.
	for flip in [false, true]:
		c.draw_set_transform(o + Vector2(w, h) if flip else o, PI if flip else 0.0, Vector2.ONE)
		c.draw_string(f, Vector2(2, 52), RANKS[r], HORIZONTAL_ALIGNMENT_CENTER, 50, 50 if r != 9 else 38, col)
		c.draw_set_transform(Vector2.ZERO)
		var sp := o + (Vector2(w - 27, h - 80) if flip else Vector2(27, 80))
		draw_suit(c, s, sp, 30.0, col, flip)
	var inner := Rect2(o + Vector2(62, 40), Vector2(w - 124, h - 80))
	if r == 0:
		draw_suit(c, s, card.get_center(), 78.0, col)
	elif r <= 9:
		for p in PIPS[r + 1]:
			var at := inner.position + Vector2(p[0], p[1]) * inner.size
			draw_suit(c, s, at, 34.0 if r < 8 else 28.0, col, p[1] > 0.55)
	else:
		# Les figures : un cadre doré, la lettre et l'enseigne, au tampon.
		var fr := inner.grow(4)
		_rounded(c, fr, 8, Color(0.93, 0.8, 0.5))
		_rounded(c, fr.grow(-4), 6, Color(0.99, 0.96, 0.88))
		var robe := Color(0.62, 0.09, 0.14) if s in [1, 2] else Color(0.12, 0.2, 0.45)
		c.draw_rect(Rect2(fr.position + Vector2(10, fr.size.y * 0.52), Vector2(fr.size.x - 20, fr.size.y * 0.4)), robe)
		c.draw_circle(fr.position + Vector2(fr.size.x / 2.0, fr.size.y * 0.36), fr.size.x * 0.2, Color(0.96, 0.82, 0.66))
		var crown := fr.position + Vector2(fr.size.x / 2.0, fr.size.y * 0.16)
		c.draw_colored_polygon(PackedVector2Array([crown + Vector2(-18, 10), crown + Vector2(-18, -6), crown + Vector2(-9, 2), crown + Vector2(0, -10), crown + Vector2(9, 2), crown + Vector2(18, -6), crown + Vector2(18, 10)]), Color(0.92, 0.7, 0.2))
		c.draw_string(f, fr.position + Vector2(0, fr.size.y * 0.86), RANKS[r], HORIZONTAL_ALIGNMENT_CENTER, fr.size.x, 40, Color(0.98, 0.9, 0.7))
		draw_suit(c, s, fr.position + Vector2(fr.size.x / 2.0, fr.size.y * 0.6), 22.0, Color(0.98, 0.92, 0.8))


static func _draw_card_back(c: Control, cell: Rect2) -> void:
	var card := cell.grow(-3)
	_rounded(c, card, 16, Color(0.97, 0.95, 0.9))
	var inner := card.grow(-9)
	_rounded(c, inner, 10, Color(0.45, 0.06, 0.12))
	var gold := Color(0.9, 0.72, 0.36)
	# Un treillis de losanges dorés et un médaillon au S de Smarves.
	var step := 18.0
	var x := inner.position.x - inner.size.y
	while x < inner.end.x:
		c.draw_line(Vector2(x, inner.position.y), Vector2(x + inner.size.y, inner.end.y), Color(gold, 0.35), 1.5)
		c.draw_line(Vector2(x + inner.size.y, inner.position.y), Vector2(x, inner.end.y), Color(gold, 0.35), 1.5)
		x += step
	c.draw_rect(inner.grow(-5), gold, false, 2.0)
	var ctr := inner.get_center()
	c.draw_circle(ctr, 34, Color(0.45, 0.06, 0.12))
	c.draw_arc(ctr, 34, 0, TAU, 48, gold, 3.0, true)
	c.draw_string(serif(), ctr + Vector2(-34, 17), "S", HORIZONTAL_ALIGNMENT_CENTER, 68, 48, gold)


static func _card_mat(idx: int) -> StandardMaterial3D:
	var key := "card_%d" % idx
	if not _mats.has(key):
		# Carton mat et un peu sombre : sous les lampes du casino, une carte plus claire brûle au blanc.
		var m := mat(Color(0.62, 0.62, 0.62), 0.8)
		m.albedo_texture = card_atlas()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.uv1_scale = Vector3(1.0 / 13.0, 1.0 / 5.0, 1.0)
		m.uv1_offset = Vector3(float(idx % 13) / 13.0, float(idx / 13) / 5.0, 0.0)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mats[key] = m
	return _mats[key]


## Une carte : face (« r » rang 0..12, « s » enseigne 0..3) et dos. Face visible quand la carte
## est à plat sans rotation ; on la retourne en tournant autour de son axe z.
static func card(r: int, s: int) -> Node3D:
	var root := Node3D.new()
	if not _meshes.has("card"):
		var pm := PlaneMesh.new()
		pm.size = Vector2(CARD_W, CARD_H)
		_meshes["card"] = pm
	var face := mesh_node(_meshes["card"], _card_mat(s * 13 + r), root, Vector3(0, 0.0004, 0))
	face.name = "Face"
	var back := mesh_node(_meshes["card"], _card_mat(4 * 13), root, Vector3(0, -0.0004, 0))
	back.rotation.z = PI
	back.name = "Dos"
	return root


## Change la face d'une carte déjà posée (carte cachée du croupier).
static func set_card_face(node: Node3D, r: int, s: int) -> void:
	var f: MeshInstance3D = node.get_node("Face")
	f.material_override = _card_mat(s * 13 + r)


# --- Dés ---------------------------------------------------------------------------------

const DIE_FACES := {
	1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3.RIGHT, 5: Vector3.LEFT, 3: Vector3.BACK, 4: Vector3.FORWARD,
}


static func _die_tex(body: Color, pip: Color) -> Texture2D:
	var key := "die_%s_%s" % [body.to_html(), pip.to_html()]
	if _tex.has(key):
		return _tex[key]
	var t := Memo.image("kit", "res://scripts/jeux/kit.gd", key, _die_img.bind(body, pip))
	_tex[key] = t
	return t


## Les six faces, peintes pixel par pixel (une centaine de milliers) : gardées sur l'appareil.
static func _die_img(body: Color, pip: Color) -> Image:
	var cs := 128
	var img := Image.create(cs * 3, cs * 2, false, Image.FORMAT_RGBA8)
	img.fill(body)
	var pos := {
		1: [[0.5, 0.5]], 2: [[0.27, 0.27], [0.73, 0.73]], 3: [[0.25, 0.25], [0.5, 0.5], [0.75, 0.75]],
		4: [[0.27, 0.27], [0.73, 0.27], [0.27, 0.73], [0.73, 0.73]],
		5: [[0.25, 0.25], [0.75, 0.25], [0.5, 0.5], [0.25, 0.75], [0.75, 0.75]],
		6: [[0.28, 0.25], [0.72, 0.25], [0.28, 0.5], [0.72, 0.5], [0.28, 0.75], [0.72, 0.75]],
	}
	for v in 6:
		var ox := (v % 3) * cs
		var oy := (v / 3) * cs
		for y in cs:
			for x in cs:
				# Un liseré plus sombre fait l'arrondi des arêtes.
				var e := minf(minf(x, cs - 1 - x), minf(y, cs - 1 - y))
				var col := body.darkened(0.12 * (1.0 - clampf(e / 10.0, 0.0, 1.0)))
				var rad := 13.0 if v > 0 else 18.0
				for p in pos[v + 1]:
					var d := Vector2(x, y).distance_to(Vector2(p[0], p[1]) * cs)
					if d < rad + 1.0:
						col = col.lerp(pip, clampf(rad + 1.0 - d, 0.0, 1.0))
				img.set_pixel(ox + x, oy + y, col)
	img.generate_mipmaps()
	return img


## Un dé : la valeur v est en haut quand on le tourne de « die_basis(v) ».
static func die(size: float, body: Color, pip: Color, glossy := true) -> MeshInstance3D:
	var key := "die_mesh_%.3f" % size
	if not _meshes.has(key):
		# Un cube aux arêtes arrondies : chaque face est une grille dont les bords sont repliés sur un
		# quart de cylindre ; les UV restent ceux de la face, les points tombent dans l'arrondi.
		var h := size / 2.0
		var r := size * 0.14
		var a := h - r
		var coords: Array[float] = []
		var m_steps := 3
		for k in range(m_steps, 0, -1):
			coords.append(-a - r * tan(PI / 4.0 * k / m_steps))
		coords.append(-a)
		coords.append(a)
		for k in range(1, m_steps + 1):
			coords.append(a + r * tan(PI / 4.0 * k / m_steps))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in DIE_FACES:
			var n: Vector3 = DIE_FACES[v]
			var u := _perp(n) if absf(n.y) < 0.5 else Vector3.RIGHT
			var w := n.cross(u)
			var cell := Vector2(((v - 1) % 3) / 3.0, ((v - 1) / 3) / 2.0)
			var pts := []
			var nrm := []
			var uvs := []
			for j in coords.size():
				for i in coords.size():
					var p: Vector3 = n * h + u * coords[i] + w * coords[j]
					var c := p.clamp(-Vector3.ONE * a, Vector3.ONE * a)
					var d := (p - c).normalized()
					pts.append(c + d * r)
					nrm.append(d)
					uvs.append(cell + Vector2((coords[i] + h) / size / 3.0, (coords[j] + h) / size / 2.0))
			var nc := coords.size()
			for j in nc - 1:
				for i in nc - 1:
					var i00 := j * nc + i
					_tri(st, pts, nrm, uvs, i00, i00 + 1, i00 + nc)
					_tri(st, pts, nrm, uvs, i00 + 1, i00 + nc + 1, i00 + nc)
		_meshes[key] = st.commit()
	var m := mat(Color.WHITE, 0.18 if glossy else 0.5)
	m.albedo_texture = _die_tex(body, pip)
	if glossy:
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.clearcoat_roughness = 0.05
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.material_override = m
	return mi


static func die_basis(v: int, yaw := 0.0) -> Basis:
	# Le 6 est à l'opposé du haut : demi-tour franc plutôt qu'un arc indéterminé.
	var q := Quaternion(Vector3.RIGHT, PI) if v == 6 else Quaternion(DIE_FACES[v], Vector3.UP)
	return Basis(Vector3.UP, yaw) * Basis(q)


# --- Effets ------------------------------------------------------------------------------

## Une gerbe d'étincelles dorées (ou de confettis) qui se libère d'elle-même.
static func burst(parent: Node3D, pos: Vector3, amount := 60, spread := 0.6, confetti := false) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.92
	p.lifetime = 1.6 if confetti else 1.1
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.initial_velocity_min = 0.6 * spread
	pm.initial_velocity_max = 1.8 * spread
	pm.gravity = Vector3(0, -2.2 if confetti else -1.4, 0)
	pm.damping_min = 0.8
	pm.damping_max = 1.6
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	var g := Gradient.new()
	if confetti:
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		pm.hue_variation_min = -0.5
		pm.hue_variation_max = 0.5
	else:
		g.set_color(0, Color(1.0, 0.95, 0.7, 1))
		g.add_point(0.4, Color(1.0, 0.72, 0.3, 1))
		g.set_color(1, Color(0.9, 0.4, 0.1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.02) if confetti else Vector2.ONE * 0.01
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1.0, 0.45, 0.6) if confetti else Color(3.0, 2.4, 1.2)
	q.material = m
	p.draw_pass_1 = q
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Une annonce flottante (« +1 250 », « 17 ROUGE ») qui jaillit puis s'efface.
static func popup(parent: Node3D, pos: Vector3, text: String, size := 96, col := Color(1.0, 0.86, 0.45), hold := 1.4) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = serif()
	l.font_size = size
	l.pixel_size = 0.0009
	l.outline_size = 10
	l.outline_modulate = Color(0.2, 0.08, 0.02, 0.9)
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.outline_render_priority = 9
	l.position = pos
	l.scale = Vector3.ONE * 0.2
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", pos.y + 0.12, hold + 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(maxf(hold - 0.35, 0.0))
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	return l


## Un éclair de lumière chaude qui retombe (gain).
static func flash(parent: Node3D, pos: Vector3, energy := 4.0) -> void:
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.78, 0.4)
	o.light_energy = energy
	o.omni_range = 2.5
	o.position = pos
	parent.add_child(o)
	var tw := o.create_tween()
	tw.tween_property(o, "light_energy", 0.0, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_callback(o.queue_free)


## Une lampe de table : un cône de lumière chaude, ombres douces.
static func table_spot(parent: Node3D, pos: Vector3, target: Vector3, energy := 6.0, angle := 38.0) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.light_color = Color(1.0, 0.86, 0.66)
	s.light_energy = energy
	s.spot_range = (pos - target).length() * 1.8
	s.spot_angle = angle
	s.spot_angle_attenuation = 0.6
	s.shadow_enabled = true
	s.shadow_blur = 1.5
	s.shadow_bias = 0.06
	s.shadow_normal_bias = 2.5
	s.light_size = 0.15
	parent.add_child(s)
	s.position = pos
	s.look_at_from_position(pos, target, Vector3.FORWARD if absf((target - pos).normalized().y) > 0.99 else Vector3.UP)
	return s
