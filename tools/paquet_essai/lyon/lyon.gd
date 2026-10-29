extends Node3D
## Lyon, la place Sathonay : maquette de direction (note d'intentions, INTENTIONS.md). Le quartier dans sa
## disposition réelle, tiré de bourg.json (tools/bourg_reel.py : OpenStreetMap, BD TOPO et RGE ALTI de
## l'IGN), de la Saône au jardin des Plantes : le relief, les rues, les 1 077 bâtiments à leur hauteur,
## la place et son square sous les arbres, l'escalier de la montée de l'Amphithéâtre entre ses deux lions,
## la mairie du 1er, le sergent Blandan, et Fourvière en lointain. L'heure et les couleurs sont celles de
## la planche de Guillaume (references/planche-sathonay.png) : une fin d'après-midi de septembre, dorée.
##
## Tout le décor est en mètres sous le nœud « Ville », réduit à l'échelle de Smarves (une unité vaut
## 2,4 m), pour que les briques de la bibliothèque (en mètres) s'y posent telles quelles. L'habitant, la
## caméra et les repères sont en unités du jeu.

const DOSSIER := "res://communes/lyon/"
const U := 2.4
const FACADIER := "facadier-lyonnais@1"
const MOBILIER := "mobilier-lyonnais@1"
const VEGETATION := "vegetation-lyonnaise@1"
const QUAIS := "quais-lyonnais@1"
const OMBRIERE := "arbres-d-ombriere@1"
const CRANS := [[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [40.0, -58.0, 30.0], [90.0, -62.0, 30.0]]

## La fin d'après-midi de septembre de la planche de Guillaume : un soleil doré venu de l'ouest, encore haut.
const SOLEIL := {"hauteur": 31.0, "vient_de": 258.0, "couleur": Color("#ffe1b0")}

## La palette de la note (« Palette et matières »).
const ENDUITS_PLACE := ["ecd59c", "f1e1b8", "eac39a", "f0d6a4", "e6c08e", "f3e6c6"]
const ENDUITS_PENTES := ["e2cc98", "e9d6b0", "dcb78f", "e4c8a0", "d8c3a2"]
const TUILES := ["c25a3a", "b4503a", "cc6a45", "a84a35", "bf6040", "b65e48"]
const PAVE := Color("#8e8a84")
const DALLE := Color("#c9c1b2")
const SABLE := Color("#e8cb9c")
const VILLEBOIS := Color("#c7c3b6")
const PIERRE_DOREE := Color("#c9a66b")
const BRONZE := Color("#3c3a2e")
const EAU := Color("#3d5b57")

## Les lieux de la scène, en mètres (x vers l'est, z vers le sud), relevés sur le plan réel.
const CENTRE_PLACE := Vector2(10.0, 18.0)
const BLANDAN := Vector2(10.6, 12.8)
const LIONS := [Vector2(3.6, -15.2), Vector2(17.4, -15.2)]
## La place : le square et la chaussée qui l'entoure, entre les façades.
const PLACE := Rect2(-14.0, -14.0, 47.0, 66.0)
## Le square planté, au milieu de la place, entre ses deux rues pavées.
const SQUARE := Rect2(-2.5, -6.0, 25.5, 51.0)
## Là où le joueur passe (le quai et la rue de la Martinière, la place, la rue Louis-Vitet, la montée) :
## chaque façade tournée vers une rue y est un immeuble du façadier, en relief, jamais un mur peint.
const RELIEF := [Rect2(-180.0, 92.0, 260.0, 45.0), Rect2(-62.0, -100.0, 145.0, 200.0)]
## Fourvière, ramenée de 975 m à 730 m dans son vrai relèvement (sud-ouest), et la tour métallique.
const FOURVIERE := Vector3(-560.0, 0.0, 470.0)
const TOUR := Vector3(-545.0, 0.0, 330.0)

var player: CharacterBody3D
var camera: Camera3D
var ville: Node3D

var data: Dictionary
var _h := PackedFloat32Array()
var _nx := 0
var _nz := 0
var _x0 := 0.0
var _z0 := 0.0
var _pas := 1.0
var _niveau_place := 12.4
var _heros := {}
var _segments: Array = []
var _cases_rues := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "bourg.json"))
	var r: Dictionary = data.relief
	_nx = int(r.nx)
	_nz = int(r.nz)
	_x0 = r.x0 * U
	_z0 = r.z0 * U
	_pas = r.pas * U
	_h = PackedFloat32Array(r.h)
	for i in _h.size():
		_h[i] *= U
	_rng.seed = 69123
	ville = Node3D.new()
	ville.name = "Ville"
	ville.scale = Vector3.ONE / U
	add_child(ville)
	_niveler()
	_ciel()
	_terrain()
	_eau()
	_rues()
	_choisir_heros()
	_batiments()
	_place()
	_escalier()
	_arbres()
	_fourviere()
	_reperes()
	_joueur()


# --- Le relief ------------------------------------------------------------------------------------

## L'altitude du sol en (x, z), en mètres, sur les mêmes triangles que le terrain dessiné.
func hauteur(x: float, z: float) -> float:
	var fx := clampf((x - _x0) / _pas, 0.0, _nx - 1.001)
	var fz := clampf((z - _z0) / _pas, 0.0, _nz - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h00 := _h[iz * _nx + ix]
	var h10 := _h[iz * _nx + ix + 1]
	var h01 := _h[(iz + 1) * _nx + ix]
	var h11 := _h[(iz + 1) * _nx + ix + 1]
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


## La place est une terrasse plate : le seul replat d'un quartier en pente (le parti pris de la note).
func _niveler() -> void:
	var somme := 0.0
	var n := 0
	for iz in _nz:
		for ix in _nx:
			var p := Vector2(_x0 + ix * _pas, _z0 + iz * _pas)
			if PLACE.has_point(p):
				somme += _h[iz * _nx + ix]
				n += 1
	_niveau_place = somme / maxi(n, 1)
	for iz in _nz:
		for ix in _nx:
			var p := Vector2(_x0 + ix * _pas, _z0 + iz * _pas)
			var d := _distance_rect(p, PLACE)
			if d <= 0.0:
				_h[iz * _nx + ix] = _niveau_place
			elif d < 10.0 and p.y > PLACE.position.y:
				# un raccord doux vers les rues du sud et des côtés ; au nord, l'escalier
				_h[iz * _nx + ix] = lerpf(_niveau_place, _h[iz * _nx + ix], d / 10.0)


func _distance_rect(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
	if dx == 0.0 and dz == 0.0:
		return -1.0
	return Vector2(dx, dz).length()


# --- La lumière -----------------------------------------------------------------------------------

func _ciel() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("#7fa6cf")
	ciel.sky_horizon_color = Color("#f2dcb4")
	ciel.sky_curve = 0.12
	ciel.ground_horizon_color = Color("#e6cfa6")
	ciel.ground_bottom_color = Color("#4a4a52")
	ciel.sun_angle_max = 12.0
	e.sky = Sky.new()
	e.sky.sky_material = ciel
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#c8bda6")
	e.ambient_light_energy = 0.4
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.84
	# la planche : des couleurs franches, la terre cuite qui chauffe, le vert cru des marronniers
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.3
	e.adjustment_contrast = 1.06
	e.ssao_enabled = true
	e.ssao_intensity = 1.2
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_hdr_threshold = 1.2
	e.fog_enabled = true
	e.fog_light_color = Color("#d9cbb2")
	e.fog_density = 0.0005
	e.fog_aerial_perspective = 0.6
	env.environment = e
	add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.name = "Soleil"
	var h := deg_to_rad(SOLEIL.hauteur)
	var a := deg_to_rad(SOLEIL.vient_de)
	add_child(soleil)
	soleil.look_at_from_position(Vector3.ZERO, Vector3(-sin(a) * cos(h), -sin(h), cos(a) * cos(h)))
	soleil.light_color = SOLEIL.couleur
	soleil.light_energy = 1.25
	soleil.shadow_enabled = true
	soleil.shadow_opacity = 0.85
	soleil.directional_shadow_max_distance = 220.0
	soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func _mat(c: Color, rugueux := 0.9, couleurs_sommets := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugueux
	m.vertex_color_use_as_albedo = couleurs_sommets
	return m


# --- Le sol ---------------------------------------------------------------------------------------

func _terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sols: Array = []
	for s in data.sols:
		var poly := PackedVector2Array()
		for q in s.p:
			poly.append(Vector2(q[0], q[1]) * U)
		sols.append(poly)
	for iz in _nz:
		for ix in _nx:
			var x := _x0 + ix * _pas
			var z := _z0 + iz * _pas
			var p := Vector2(x, z)
			var c := PAVE
			if PLACE.has_point(p):
				c = PAVE
			else:
				for poly in sols:
					if Geometry2D.is_point_in_polygon(p, poly):
						c = DALLE
						break
			var bruit := _rng.randf_range(-0.025, 0.025)
			st.set_color(Color(c.r + bruit, c.g + bruit, c.b + bruit))
			st.set_uv(Vector2(x, z) / 4.0)
			st.add_vertex(Vector3(x, _h[iz * _nx + ix], z))
	for iz in _nz - 1:
		for ix in _nx - 1:
			var i := iz * _nx + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + _nx)
			st.add_index(i + 1)
			st.add_index(i + _nx + 1)
			st.add_index(i + _nx)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Sol"
	mi.mesh = st.commit()
	mi.material_override = _materiau_paves()
	ville.add_child(mi)
	# le square de sable stabilisé et sa bordure de pierre, les trottoirs dallés au pied des façades
	var sable := _boite(ville, Vector3(SQUARE.size.x, 0.1, SQUARE.size.y), Vector3(SQUARE.get_center().x, _niveau_place + 0.05, SQUARE.get_center().y), SABLE)
	sable.material_override = _materiau_sable()
	_boite(ville, Vector3(SQUARE.size.x + 0.5, 0.16, SQUARE.size.y + 0.5), Vector3(SQUARE.get_center().x, _niveau_place + 0.0, SQUARE.get_center().y), VILLEBOIS)
	for x in [PLACE.position.x + 1.4, PLACE.end.x - 1.4]:
		_boite(ville, Vector3(2.8, 0.14, PLACE.size.y), Vector3(x, _niveau_place + 0.05, PLACE.get_center().y), DALLE)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	forme.shape = mi.mesh.create_trimesh_shape()
	corps.add_child(forme)
	mi.add_child(corps)


func _eau() -> void:
	var niveau: float = data.niveau_eau * U
	for e in data.eau:
		var poly := PackedVector2Array()
		for q in e.p:
			poly.append(Vector2(q[0], q[1]) * U)
		var tri := Geometry2D.triangulate_polygon(poly)
		if tri.is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for k in tri:
			st.add_vertex(Vector3(poly[k].x, niveau, poly[k].y))
		var mi := MeshInstance3D.new()
		mi.name = "Saone"
		mi.mesh = st.commit()
		var m := _mat(EAU, 0.08)
		m.metallic = 0.2
		m.metallic_specular = 0.8
		mi.material_override = m
		ville.add_child(mi)


## Les rues en rubans posés sur le relief : la chaussée d'enrobé, les rues piétonnes et les montées pavées.
## Les pavés lyonnais en rangs, joints sombres, sur les chaussées et la place ; le reste reste lisse.
## Le sable stabilisé du square : des nappes plus claires et plus foncées de 2 à 4 m, un grain de gravillons,
## l'usure plus claire au milieu des allées.
func _materiau_sable() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec3 teinte : source_color;
varying vec3 monde;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = monde.xz;
	float nappe = bruit(p * 0.35) * 0.6 + bruit(p * 0.9) * 0.4;
	float grain = hash(floor(p * 18.0));
	vec3 c = teinte * (0.93 + 0.12 * nappe);
	c = mix(c, c * 0.82, step(0.93, grain));
	c = mix(c, c * 1.08, step(grain, 0.05));
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("teinte", SABLE)
	return m


func _materiau_paves() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 monde;
void vertex() { monde = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 q = monde.xz / vec2(0.32, 0.22);
	q.x += floor(q.y) * 0.5;
	vec2 f = fract(q);
	float joint = smoothstep(0.0, 0.1, f.x) * smoothstep(1.0, 0.9, f.x) * smoothstep(0.0, 0.12, f.y) * smoothstep(1.0, 0.88, f.y);
	float v = 0.86 + 0.18 * hash(floor(q));
	ALBEDO = COLOR.rgb * mix(0.6, v, joint);
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _rues() -> void:
	var enrobe := SurfaceTool.new()
	enrobe.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pietons := SurfaceTool.new()
	pietons.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in data.routes:
		if r.get("pont", false):
			continue
		var k: String = r.k
		var st := pietons if k in ["footway", "path", "steps", "pedestrian", "living_street"] else enrobe
		var l: float = r.l * U * (0.5 if k == "footway" else 0.5)
		var pts: Array = []
		for q in r.p:
			pts.append(Vector2(q[0], q[1]) * U)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if PLACE.has_point(a) and PLACE.has_point(b):
				continue
			var n := (b - a).orthogonal().normalized() * l
			var pa := [a - n, a + n, b + n, b - n]
			var v := []
			for p in pa:
				v.append(Vector3(p.x, hauteur(p.x, p.y) + 0.06, p.y))
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color("#86827c") if st == enrobe else Color("#b3ab9d"))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[idx])
	for paire in [[enrobe, Color("#86827c"), "Chaussees"], [pietons, Color("#b3ab9d"), "Pietons"]]:
		var mi := MeshInstance3D.new()
		mi.name = paire[2]
		mi.mesh = paire[0].commit()
		mi.material_override = _materiau_paves()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ville.add_child(mi)


# --- Le bâti --------------------------------------------------------------------------------------

## Les immeubles qui bordent la place et la montée sont des immeubles du façadier lyonnais, posés sur
## leur rectangle réel ; les autres, des volumes à fenêtres peintes par le shader de la ville.
func _choisir_heros() -> void:
	for i in data.batiments.size():
		var b: Dictionary = data.batiments[i]
		var rc: Array = b.rect
		var c := Vector2(rc[0], rc[1]) * U
		var lu: float = rc[2] * U
		if b.rempli < 0.75 or lu < 5.0 or lu > 32.0:
			continue
		if b.get("r", "") == "mairie" or i in [237]:
			_heros[i] = true
		elif Rect2(-62.0, -45.0, 140.0, 125.0).has_point(c) and b.rue * U < 9.0:
			_heros[i] = true


func _batiments() -> void:
	var murs := SurfaceTool.new()
	murs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var toits := SurfaceTool.new()
	toits.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collisions := PackedVector3Array()
	_grille_emprises()
	for i in data.batiments.size():
		var b: Dictionary = data.batiments[i]
		if _heros.has(i):
			_heros_poser(i, b)
			continue
		var poly := PackedVector2Array()
		for q in b.p:
			poly.append(Vector2(q[0], q[1]) * U)
		var sol: float = b.sol * U - 0.5
		var h: float = b.h * U + 0.5
		var en_relief := _reliefs(i, b, poly)
		if not en_relief.is_empty():
			# le volume s'arrête à la corniche des façades posées devant lui, et son toit les coiffe
			var haut := 0.0
			for f in en_relief:
				haut = maxf(haut, f)
			h = haut - sol
		var c := _enduit(Vector2(b.rect[0], b.rect[1]) * U, i)
		var baie := 3.1 + float((i * 37) % 7) * 0.1
		for k in poly.size():
			var a := poly[k]
			var bb := poly[(k + 1) % poly.size()]
			var long := a.distance_to(bb)
			var v := [Vector3(a.x, sol, a.y), Vector3(bb.x, sol, bb.y), Vector3(bb.x, sol + h, bb.y), Vector3(a.x, sol + h, a.y)]
			var nb := maxf(1.0, round(long / baie))
			var uv := [Vector2(0, 0), Vector2(nb, 0), Vector2(nb, h), Vector2(0, h)]
			var n := Vector3(bb.y - a.y, 0, -(bb.x - a.x)).normalized()
			# un mur mitoyen ne se voit pas : on ne le dessine pas (il scintillerait contre celui du voisin)
			if _dans_un_autre((a + bb) * 0.5 + Vector2(n.x, n.z) * 0.6, i):
				continue
			if _relief_pose.has(Vector2i(i, k)):
				# derrière les façades en relief, le mur recule : il ne se voit qu'au-dessus d'une corniche plus basse
				for j in 4:
					v[j] -= n * 0.25
			for idx in [0, 2, 1, 0, 3, 2]:
				murs.set_color(c)
				murs.set_normal(n)
				murs.set_uv(uv[idx])
				murs.set_uv2(Vector2(h, float(i % 97)))
				murs.add_vertex(v[idx])
			if (Vector2(a.x, a.y) - CENTRE_PLACE).length() < 260.0:
				collisions.append_array(PackedVector3Array([v[0], v[2], v[1], v[0], v[3], v[2]]))
		_toit(toits, b, poly, sol + h, i)
	var mm := MeshInstance3D.new()
	mm.name = "Murs"
	mm.mesh = murs.commit()
	mm.material_override = _materiau_murs()
	ville.add_child(mm)
	var mt := MeshInstance3D.new()
	mt.name = "Toits"
	mt.mesh = toits.commit()
	mt.material_override = _mat(Color.WHITE, 0.8, true)
	ville.add_child(mt)
	var corps := StaticBody3D.new()
	corps.name = "Murs_collision"
	var forme := CollisionShape3D.new()
	var cs := ConcavePolygonShape3D.new()
	cs.backface_collision = true
	cs.set_faces(collisions)
	forme.shape = cs
	corps.add_child(forme)
	ville.add_child(corps)


var _emprises: Array = []
var _grille := {}
var _relief_pose := {}


## Les façades en relief d'un bâtiment ordinaire : sur chaque mur tourné vers une rue ou la place, dans
## les zones où passe le joueur, des immeubles du façadier de 5 à 11 m, au pied du mur, peu profonds (le
## volume du bâtiment fait le reste). Rend la hauteur de corniche de chacun, au-dessus du niveau 0.
func _reliefs(i: int, b: Dictionary, poly: PackedVector2Array) -> Array:
	var c := Vector2(b.rect[0], b.rect[1]) * U
	var dedans := false
	for z in RELIEF:
		if z.has_point(c):
			dedans = true
	if not dedans or b.h * U < 5.0:
		return []
	var niveaux := clampi(int(round((b.h * U - 4.2) / 3.3)), 1, 6)
	var pentes := c.y < -45.0 or c.x > 90.0
	if pentes:
		niveaux = clampi(niveaux + 1, 3, 6)
	var corniches := []
	for k in poly.size():
		var a := poly[k]
		var bb := poly[(k + 1) % poly.size()]
		var long := a.distance_to(bb)
		if long < 4.8:
			continue
		var u := (bb - a) / long
		var n := Vector2(u.y, -u.x)
		var milieu := (a + bb) * 0.5
		if Geometry2D.is_point_in_polygon(milieu + n * 0.4, poly):
			n = -n
		if _dans_un_autre(milieu + n * 0.6, i) or _ouverture(milieu + n * 3.0) > 6.0:
			continue
		_relief_pose[Vector2i(i, k)] = true
		var nb := maxi(1, int(round(long / 9.5)))
		var w := long / nb
		for j in nb:
			var q := a + u * w * (j + 0.5) + n * 0.02
			var type: String = "etroite" if w < 6.5 else ["immeuble", "classique", "traboule", "immeuble", "classique"][(i * 5 + k * 3 + j) % 5]
			var opt := {"w": w - 0.04, "d": 3.0, "niveaux": niveaux, "tuile": TUILES[(i + j) % TUILES.size()]}
			opt["enduit"] = (ENDUITS_PENTES if pentes else ENDUITS_PLACE)[(i + k + j) % 5]
			if pentes:
				opt["fleurs"] = false
			var m: Node3D = load(Bibliotheque.scene(FACADIER, "decor")).instantiate()
			m.type = type
			m.graine = i * 31 + k * 7 + j
			m.options = opt
			var y := hauteur(q.x, q.y) - 0.05
			m.position = Vector3(q.x, y, q.y)
			m.rotation.y = atan2(n.x, n.y)
			ville.add_child(m)
			corniches.append(y + 4.2 + float(opt.niveaux) * 3.3)
	return corniches


func _grille_emprises() -> void:
	for i in data.batiments.size():
		var poly := PackedVector2Array()
		for q in data.batiments[i].p:
			poly.append(Vector2(q[0], q[1]) * U)
		_emprises.append(poly)
		var r := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			r = r.expand(q)
		for gx in range(floori(r.position.x / 10.0), floori(r.end.x / 10.0) + 1):
			for gz in range(floori(r.position.y / 10.0), floori(r.end.y / 10.0) + 1):
				var k := Vector2i(gx, gz)
				if not _grille.has(k):
					_grille[k] = []
				_grille[k].append(i)


func _dans_un_autre(p: Vector2, sauf: int) -> bool:
	for j in _grille.get(Vector2i(floori(p.x / 10.0), floori(p.y / 10.0)), []):
		if j != sauf and Geometry2D.is_point_in_polygon(p, _emprises[j]):
			return true
	return false


func _enduit(c: Vector2, i: int) -> Color:
	# les pentes (au nord et à l'est, plus haut) sont plus pâles et plus usées que le bas
	var pentes := c.y < -45.0 or c.x > 90.0
	var liste: Array = ENDUITS_PENTES if pentes else ENDUITS_PLACE
	var col := Color(liste[(i * 7 + 3) % liste.size()])
	return col.darkened(float(i % 5) * 0.025)


func _toit(st: SurfaceTool, b: Dictionary, poly: PackedVector2Array, haut: float, i: int) -> void:
	var tuile := Color(TUILES[i % TUILES.size()])
	var rc: Array = b.rect
	var pente: float = clampf(b.pente * U, 1.2, 3.2)
	if b.rempli >= 0.85 and b.toit != "plat":
		# un toit à deux pans, en tuile canal à faible pente, le long du grand côté du rectangle
		var c := Vector2(rc[0], rc[1]) * U
		var lu: float = rc[2] * U * 0.5 + 0.3
		var lv: float = rc[3] * U * 0.5 + 0.3
		var u := Vector2(cos(rc[4]), sin(rc[4]))
		var v := Vector2(-u.y, u.x)
		var coins := [c - u * lu - v * lv, c + u * lu - v * lv, c + u * lu + v * lv, c - u * lu + v * lv]
		var A := Vector3(coins[0].x, haut, coins[0].y)
		var B := Vector3(coins[1].x, haut, coins[1].y)
		var C := Vector3(coins[2].x, haut, coins[2].y)
		var D := Vector3(coins[3].x, haut, coins[3].y)
		var f0 := c - u * lu
		var f1 := c + u * lu
		var E := Vector3(f0.x, haut + pente, f0.y)
		var F := Vector3(f1.x, haut + pente, f1.y)
		for tri in [[A, F, B], [A, E, F], [D, C, F], [D, F, E], [A, D, E], [B, F, C]]:
			var n: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
			if n.y < 0.0:
				tri = [tri[0], tri[2], tri[1]]
				n = -n
			for p in tri:
				st.set_color(tuile.darkened(0.15) if absf(n.y) < 0.2 else tuile)
				st.set_normal(n)
				st.add_vertex(p)
		return
	var tri := Geometry2D.triangulate_polygon(poly)
	for k in range(0, tri.size(), 3):
		for j in [0, 2, 1]:
			var p := poly[tri[k + j]]
			st.set_color(tuile.darkened(0.25) if b.toit != "plat" else Color("#8a8278"))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(p.x, haut + 0.15, p.y))


## Le shader de la ville : les fenêtres hautes des immeubles lyonnais, les persiennes, le bandeau du
## rez-de-chaussée et ses boutiques, les encadrements clairs et les géraniums aux fenêtres.
func _materiau_murs() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec3 c = COLOR.rgb;
	float h = UV2.x;
	float y = UV.y;
	float bx = floor(UV.x);
	float fx = fract(UV.x);
	float rdc = 4.2;
	float etage = y < rdc ? 0.0 : floor((y - rdc) / 3.3) + 1.0;
	float fy = y < rdc ? y / rdc : fract((y - rdc) / 3.3);
	float id = hash(vec2(bx, etage) + UV2.y);
	float fen = 0.0;
	float volet = 0.0;
	if (etage < 0.5) {
		fen = step(0.12, fx) * step(fx, 0.88) * step(0.02, fy) * step(fy, 0.7);
	} else if (y < h - 1.3) {
		fen = step(0.33, fx) * step(fx, 0.67) * step(0.18, fy) * step(fy, 0.9);
		volet = (step(0.2, fx) * step(fx, 0.33) + step(0.67, fx) * step(fx, 0.8)) * step(0.18, fy) * step(fy, 0.9) * step(0.45, id);
	}
	float bandeau = step(rdc - 0.25, y) * step(y, rdc + 0.05) + step(h - 0.6, y);
	// l'encadrement de pierre claire autour de chaque fenêtre d'étage, et la jardinière de géraniums
	float cadre = 0.0;
	float fleurs = 0.0;
	if (etage > 0.5 && y < h - 1.3) {
		cadre = step(0.29, fx) * step(fx, 0.71) * step(0.13, fy) * step(fy, 0.94) * (1.0 - fen);
		fleurs = step(0.31, fx) * step(fx, 0.69) * step(0.18, fy) * step(fy, 0.27) * step(0.4, hash(vec2(bx, etage) + UV2.y + 7.0));
	}
	vec3 verre = vec3(0.17, 0.2, 0.25) + vec3(0.1, 0.1, 0.08) * step(fy, 0.5);
	vec3 col = c * (0.92 + 0.1 * hash(vec2(floor(y * 2.0), bx)));
	col = mix(col, vec3(0.42, 0.5, 0.44) * (0.8 + 0.4 * hash(vec2(UV2.y, 3.0))), volet);
	col = mix(col, c * 1.12, bandeau);
	col = mix(col, vec3(0.95, 0.92, 0.84), cadre);
	col = mix(col, verre, fen);
	col = mix(col, mix(vec3(0.78, 0.12, 0.14), vec3(0.24, 0.42, 0.18), step(0.23, fy)), fleurs);
	// l'ombre de contact que le rendu n'a pas : sous l'égout et au pied du mur
	col *= 1.0 - 0.35 * smoothstep(h - 0.6, h, y) - 0.3 * (1.0 - smoothstep(0.0, 0.4, y));
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.25, fen);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## La distance d'un point à l'espace ouvert le plus proche (une rue, la place) : la façade d'un immeuble
## regarde du côté où elle est la plus courte.
func _ouverture(p: Vector2) -> float:
	if PLACE.has_point(p):
		return 0.0
	if _segments.is_empty():
		# les tronçons de rue, rangés par cases de 20 m pour ne chercher que près du point
		for r in data.routes:
			for k in r.p.size() - 1:
				var sa := Vector2(r.p[k][0], r.p[k][1]) * U
				var sb := Vector2(r.p[k + 1][0], r.p[k + 1][1]) * U
				_segments.append([sa, sb])
				var bo := Rect2(sa, Vector2.ZERO).expand(sb).grow(12.0)
				for gx in range(floori(bo.position.x / 20.0), floori(bo.end.x / 20.0) + 1):
					for gz in range(floori(bo.position.y / 20.0), floori(bo.end.y / 20.0) + 1):
						var cle := Vector2i(gx, gz)
						if not _cases_rues.has(cle):
							_cases_rues[cle] = []
						_cases_rues[cle].append(_segments.size() - 1)
	var best := 1e9
	var proches: Array = _cases_rues.get(Vector2i(floori(p.x / 20.0), floori(p.y / 20.0)), [])
	if proches.is_empty():
		return 12.0
	for j in proches:
		var sg: Array = _segments[j]
		var q := Geometry2D.get_closest_point_to_segment(p, sg[0], sg[1])
		best = minf(best, q.distance_to(p))
	return best


func _heros_poser(i: int, b: Dictionary) -> void:
	var rc: Array = b.rect
	var c := Vector2(rc[0], rc[1]) * U
	var lu: float = rc[2] * U
	var lv: float = rc[3] * U
	var u := Vector2(cos(rc[4]), sin(rc[4]))
	var v := Vector2(-u.y, u.x)
	# la façade regarde le côté le plus proche d'une rue ou de la place, parmi les quatre du rectangle
	var cotes := [[v, u, lu, lv], [-v, -u, lu, lv], [u, -v, lv, lu], [-u, v, lv, lu]]
	var meilleur := 1e9
	for ct in cotes:
		var d := _ouverture(c + ct[0] * (ct[3] * 0.5 + 2.5))
		if ct[2] < 6.0:
			d += 4.0
		if d < meilleur:
			meilleur = d
			v = ct[0]
			u = ct[1]
			var l: float = ct[2]
			lv = ct[3]
			lu = l
	var front := c + v * lv * 0.5
	var sol: float = b.sol * U + 0.3
	var h: float = b.h * U
	var niveaux := clampi(int(round((h - 4.2) / 3.3)), 1, 6)
	var lacet := atan2(v.x, v.y)
	var est_mairie: bool = b.get("r", "") == "mairie" or i == 237
	# une façade large se découpe en immeubles mitoyens de 8 à 13 m, aux hauteurs voisines
	var n := maxi(1, int(round(lu / 11.0)))
	if est_mairie:
		n = 1
	var w := lu / n
	for k in n:
		var x := -lu * 0.5 + w * (k + 0.5)
		var p := front + u * x
		var type := "classique"
		var opt := {"w": w - 0.05, "d": lv, "niveaux": niveaux, "tuile": TUILES[(i + k) % TUILES.size()]}
		if est_mairie:
			type = "hotel"
			opt.merge({"enduit": "c6bca3", "persiennes": false, "fleurs": false, "niveaux": 3, "rdc": "pierre"}, true)
		else:
			var pentes := p.y < -45.0
			var r := (i * 13 + k * 7) % 10
			type = ["immeuble", "classique", "bourgeois", "immeuble", "traboule", "classique", "immeuble", "angle", "immeuble", "classique"][r]
			if type == "angle":
				type = "immeuble"
			if pentes:
				opt["enduit"] = ENDUITS_PENTES[(i + k) % ENDUITS_PENTES.size()]
				opt["fleurs"] = false
				opt["niveaux"] = clampi(niveaux + 1, 4, 6)
			else:
				opt["enduit"] = ENDUITS_PLACE[(i + k) % ENDUITS_PLACE.size()]
			if absf(p.x - (-14.0)) < 6.0 and p.y > -5.0 and p.y < 45.0 and k == 0:
				type = "cafe"
				opt["enseigne"] = "CAFÉ DU LION D'OR"
				opt["toile"] = ["b8352e", "f3ead6"]
				opt["avancee"] = 2.4
		var m: Node3D = load(Bibliotheque.scene(FACADIER, "decor")).instantiate()
		m.type = type
		m.graine = i * 17 + k
		m.options = opt
		m.position = Vector3(p.x, hauteur(p.x, p.y) - 0.05 if not est_mairie else sol, p.y)
		m.rotation.y = lacet
		ville.add_child(m)
		# le socle de l'immeuble, jusqu'au point le plus bas de la pente
		var bas := minf(hauteur(p.x - u.x * w * 0.5, p.y - u.y * w * 0.5), hauteur(p.x + u.x * w * 0.5, p.y + u.y * w * 0.5))
		if m.position.y - bas > 0.3:
			var socle := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(w, m.position.y - bas + 0.4, lv)
			socle.mesh = bm
			socle.material_override = _mat(PIERRE_DOREE.darkened(0.15))
			socle.position = Vector3(p.x - v.x * lv * 0.5, bas + bm.size.y * 0.5 - 0.4, p.y - v.y * lv * 0.5)
			socle.rotation.y = lacet
			ville.add_child(socle)


# --- La place -------------------------------------------------------------------------------------

func _pose(id: String, cle: String, valeur: String, p: Vector3, g: int, opt := {}, lacet := 0.0) -> Node3D:
	var b: Node3D = load(Bibliotheque.scene(id, "decor")).instantiate()
	b.set(cle, valeur)
	b.graine = g
	b.options = opt
	b.position = p
	b.rotation.y = lacet
	ville.add_child(b)
	return b


func _sur(x: float, z: float) -> Vector3:
	return Vector3(x, hauteur(x, z), z)


func _place() -> void:
	var y := _niveau_place
	var sq := SQUARE
	# le sergent Blandan, bronze vert sombre sur son socle à degrés, au milieu du square (planche de Guillaume)
	var s := Node3D.new()
	s.name = "Remarquable_blandan"
	s.position = Vector3(BLANDAN.x, y, BLANDAN.y)
	ville.add_child(s)
	_blandan(s)
	# les quatre massifs fleuris au pied du socle, chacun dans sa grille basse
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		_pose(VEGETATION, "plante", "massif", Vector3(BLANDAN.x + cos(a) * 3.9, y, BLANDAN.y + sin(a) * 3.9), 300 + k, {"longueur": 2.4, "fleurs": ["f4f0e6", "e0605a", "d04a8a", "f4f0e6"][k]}, -a)
	# l'anneau de marronniers sur le pourtour du square, le sable au milieu
	var pas := 10.5
	var bord := 3.2
	var points: Array[Vector2] = []
	var nx := int(round((sq.size.x - bord * 2.0) / pas))
	var nz := int(round((sq.size.y - bord * 2.0) / pas))
	for i in nx + 1:
		var x := lerpf(sq.position.x + bord, sq.end.x - bord, float(i) / nx)
		points.append(Vector2(x, sq.position.y + bord))
		points.append(Vector2(x, sq.end.y - bord))
	for j in range(1, nz):
		var z := lerpf(sq.position.y + bord, sq.end.y - bord, float(j) / nz)
		points.append(Vector2(sq.position.x + bord, z))
		points.append(Vector2(sq.end.x - bord, z))
	for k in points.size():
		var p: Vector2 = points[k]
		# l'allée du nord reste ouverte vers l'escalier
		if p.y < sq.position.y + 1.0 + bord and absf(p.x - BLANDAN.x) < 4.0:
			continue
		p += Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2))
		_pose(OMBRIERE, "arbre", "marronnier", Vector3(p.x, y, p.y), 400 + k, {"hauteur": _rng.randf_range(14.0, 17.0), "vent": 0.4, "densite": 0.8})
	# la bordure basse de fonte noire et les plates-bandes fleuries le long du pourtour
	var noir := Color("#1f2422")
	for cote in [[Vector2(sq.position.x, sq.position.y), Vector2(sq.end.x, sq.position.y)], [Vector2(sq.position.x, sq.end.y), Vector2(sq.end.x, sq.end.y)],
			[Vector2(sq.position.x, sq.position.y), Vector2(sq.position.x, sq.end.y)], [Vector2(sq.end.x, sq.position.y), Vector2(sq.end.x, sq.end.y)]]:
		var a: Vector2 = cote[0]
		var b: Vector2 = cote[1]
		var long := a.distance_to(b)
		var dir := (b - a) / long
		# trois entrées par côté long, une par côté court
		var n := int(long / 2.0)
		for k in n:
			var t := (k + 0.5) / n
			var q := a.lerp(b, t)
			var milieu := absf(t - 0.5) < 0.09 or (long > 30.0 and absf(t - 0.25) < 0.05) or (long > 30.0 and absf(t - 0.75) < 0.05)
			if milieu:
				continue
			_boite(ville, Vector3(2.0 if dir.x != 0.0 else 0.05, 0.5, 2.0 if dir.y != 0.0 else 0.05), Vector3(q.x, y + 0.25, q.y), noir)
			if k % 3 == 1:
				var dedans := Vector2(-dir.y, dir.x) * (1.0 if (cote[0] == Vector2(sq.position.x, sq.position.y) and dir.x != 0.0) or (cote[0] == Vector2(sq.end.x, sq.position.y)) else -1.0)
				_pose(VEGETATION, "plante", "buisson" if k % 2 else "massif", Vector3(q.x, y, q.y) + Vector3(dedans.x, 0, dedans.y) * 0.9, 600 + k, {"fleurs": ["f4f0e6", "e0605a", "d04a8a"][k % 3], "longueur": 1.8}, atan2(dir.x, dir.y))
	# les bancs de fonte verte, tournés vers la statue, et les réverbères noirs des allées
	for k in 6:
		var z := lerpf(sq.position.y + 9.0, sq.end.y - 9.0, float(k) / 5.0)
		_pose(MOBILIER, "objet", "banc", Vector3(sq.position.x + 4.6, y, z), 40 + k, {}, PI * 0.5)
		_pose(MOBILIER, "objet", "banc", Vector3(sq.end.x - 4.6, y, z), 50 + k, {}, -PI * 0.5)
	var lampes := [Vector2(BLANDAN.x - 6.0, BLANDAN.y - 5.0), Vector2(BLANDAN.x + 6.0, BLANDAN.y - 5.0), Vector2(BLANDAN.x - 6.0, BLANDAN.y + 6.0),
		Vector2(BLANDAN.x + 6.0, BLANDAN.y + 6.0), Vector2(sq.position.x + 4.0, sq.end.y - 4.0), Vector2(sq.end.x - 4.0, sq.end.y - 4.0),
		Vector2(sq.position.x - 1.5, sq.position.y + 4.0), Vector2(sq.end.x + 1.5, sq.position.y + 4.0)]
	for k in lampes.size():
		var p: Vector2 = lampes[k]
		_pose(MOBILIER, "objet", "lampadaire", Vector3(p.x, y, p.y), 80 + k, {})
	_pose(MOBILIER, "objet", "corbeille", Vector3(sq.position.x + 4.0, y, sq.end.y - 2.0), 90)
	_pose(MOBILIER, "objet", "corbeille", Vector3(sq.end.x - 4.0, y, sq.end.y - 2.0), 91)
	# les terrasses des cafés : à l'ouest sous les stores rouge et vert, à l'est sous un store rayé
	# les tables bistrot sous les stores, la longueur le long des façades, tournées vers le square
	for k in 4:
		_pose(MOBILIER, "objet", "terrasse", Vector3(-11.3, y, -1.0 + k * 5.0), 60 + k, {}, PI * 0.5)
	for k in 2:
		_pose(MOBILIER, "objet", "terrasse", Vector3(30.8, y, 22.0 + k * 5.0), 70 + k, {}, -PI * 0.5)
	for z in [-10.0, 21.0, 32.0]:
		_pose(MOBILIER, "objet", "jardiniere", Vector3(-12.8, y, z), 100 + int(z), {"fleurs": "e0605a"})
	for z in [-6.0, 10.0, 34.0]:
		_pose(MOBILIER, "objet", "jardiniere", Vector3(32.4, y, z), 120 + int(z), {"fleurs": "d04a8a"})


## La montée de l'Amphithéâtre : la volée centrale entre les deux lions, le palier, puis les deux volées
## qui montent vers la rue du Jardin-des-Plantes, de part et d'autre.
func _escalier() -> void:
	var y0 := _niveau_place
	var y1 := hauteur(10.5, -40.0)
	var e := Node3D.new()
	e.name = "Remarquable_amphitheatre"
	ville.add_child(e)
	var marches := 34
	var z0 := -14.0
	var z1 := -38.0
	var pierre := VILLEBOIS
	for k in marches:
		var t0 := float(k) / marches
		var z := lerpf(z0, z1, t0)
		var yy := lerpf(y0, y1, float(k + 1) / marches)
		_boite(e, Vector3(9.0, yy - y0 + 0.2, (z0 - z1) / marches + 0.02), Vector3(10.5, (yy + y0) * 0.5 - 0.1, z - (z0 - z1) / marches * 0.5), pierre.darkened(0.04 * (k % 2)))
	# les murs d'échiffre, la balustrade du palier
	# les murs d'échiffre suivent la pente par ressauts, sous leur chaperon de Villebois et leurs dés
	for cote in [-1.0, 1.0]:
		var x: float = 10.5 + cote * 5.0
		var pas := 4
		for k in range(0, marches, pas):
			var za := lerpf(z0, z1, float(k) / marches)
			var zb := lerpf(z0, z1, float(mini(k + pas, marches)) / marches)
			var ya := lerpf(y0, y1, float(mini(k + pas, marches)) / marches)
			var haut := ya - y0 + 1.0
			_boite(e, Vector3(0.9, haut, za - zb + 0.02), Vector3(x, y0 + haut * 0.5, (za + zb) * 0.5), PIERRE_DOREE.darkened(0.03 * (k / pas % 2)))
			_boite(e, Vector3(1.1, 0.14, za - zb + 0.06), Vector3(x, y0 + haut + 0.07, (za + zb) * 0.5), VILLEBOIS)
		for z in [z0, z1]:
			var yy := y0 if z == z0 else y1
			_boite(e, Vector3(1.2, 1.5, 1.2), Vector3(x, yy + 0.55 if z == z1 else y0 + 0.75, z - 0.6 if z == z0 else z + 0.6), PIERRE_DOREE)
			_boite(e, Vector3(1.4, 0.18, 1.4), Vector3(x, (yy + 1.4) if z == z1 else y0 + 1.59, z - 0.6 if z == z0 else z + 0.6), VILLEBOIS)
	_boite(e, Vector3(16.0, y1 - y0 + 0.2, 6.0), Vector3(10.5, (y0 + y1) * 0.5 - 0.1, z1 - 3.0), pierre)
	_pose(MOBILIER, "objet", "garde_corps", Vector3(10.5, y1, z1 - 0.2), 7, {"longueur": 7.0})
	# les deux fontaines aux lions de bronze, au pied de l'escalier
	for k in LIONS.size():
		var p: Vector2 = LIONS[k]
		var f := Node3D.new()
		f.name = "Lion%d" % (k + 1)
		f.position = Vector3(p.x, y0, p.y)
		ville.add_child(f)
		_fontaine_lion(f, -1.0 if k == 0 else 1.0)
	# le jardin en haut : les deux volées latérales et le belvédère
	for x in [3.4, 16.4]:
		var ya := hauteur(x, -50.0)
		var yb := hauteur(x, -80.0)
		var n := 30
		for k in n:
			var z := lerpf(-50.0, -80.0, float(k) / n)
			var yy := lerpf(ya, yb, float(k + 1) / n)
			_boite(e, Vector3(3.0, 0.4, 1.02), Vector3(x, yy - 0.2, z - 0.5), pierre)


# --- Les pièces uniques ---------------------------------------------------------------------------

## Une forme simple (boîte, cylindre, sphère, capsule) sous parent, tournée par les angles a (radians) ;
## m ajoute le métal et le poli du bronze.
func _forme(parent: Node3D, mesh: Mesh, p: Vector3, c: Color, a := Vector3.ZERO, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := _mat(c, 0.38 if metal > 0.0 else 0.88)
	m.metallic = metal
	mi.material_override = m
	mi.position = p
	mi.rotation = a
	parent.add_child(mi)
	return mi


## Un membre : une capsule de rayon r tendue de a à b.
func _segment(parent: Node3D, a: Vector3, b: Vector3, r: float, c: Color, metal := 0.0) -> MeshInstance3D:
	var d := b - a
	var mi := _forme(parent, _cap(r, d.length() + r * 2.0), (a + b) * 0.5, c, Vector3.ZERO, metal)
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(x, y, x.cross(y))
	return mi


func _cyl(r0: float, r1: float, h: float, cotes := 16) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r0
	m.bottom_radius = r1
	m.height = h
	m.radial_segments = cotes
	m.rings = 1
	return m


func _bou(r: float, h := -1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 if h < 0.0 else h
	m.radial_segments = 16
	m.rings = 8
	return m


func _cap(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 4
	return m


func _blo(t: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = t
	return m


## Une moulure : une pile de boîtes de plus en plus larges (une corniche) ou de plus en plus étroites (une base).
func _moulure(parent: Node3D, y: float, l: float, p: float, c: Color, sens := 1.0) -> void:
	for k in 3:
		var e := 0.08 * (k if sens > 0.0 else 2 - k)
		_forme(parent, _blo(Vector3(l + e * 2.0, 0.1, p + e * 2.0)), Vector3(0, y + k * 0.1 + 0.05, 0), c.darkened(0.03 * k))


## Le sergent Blandan de Lamotte, bronze vert sur son haut socle de pierre de Villebois, face au sud (la
## planche) : le soldat debout, le shako, la capote, le fusil à la main droite, le bras gauche tendu.
func _blandan(s: Node3D) -> void:
	var pierre := VILLEBOIS
	# trois degrés, le dé, la corniche, la plaque de bronze
	_forme(s, _blo(Vector3(6.4, 0.18, 6.4)), Vector3(0, 0.09, 0), pierre.darkened(0.06))
	_forme(s, _blo(Vector3(5.2, 0.22, 5.2)), Vector3(0, 0.29, 0), pierre.darkened(0.03))
	_forme(s, _blo(Vector3(4.0, 0.26, 4.0)), Vector3(0, 0.53, 0), pierre)
	_moulure(s, 0.66, 2.3, 2.3, pierre, -1.0)
	_forme(s, _blo(Vector3(1.9, 2.1, 1.9)), Vector3(0, 2.01, 0), pierre.lightened(0.05))
	for c in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		_forme(s, _blo(Vector3(0.22, 2.1, 0.22)), Vector3(c.x * 0.9, 2.01, c.z * 0.9), pierre.lightened(0.08))
	_moulure(s, 3.06, 2.0, 2.0, pierre, 1.0)
	_forme(s, _blo(Vector3(1.5, 0.2, 1.5)), Vector3(0, 3.46, 0), pierre.darkened(0.04))
	var vert := Color("#4f6a58")
	var vert_clair := Color("#6f8f74")
	_forme(s, _blo(Vector3(0.9, 0.6, 0.03)), Vector3(0, 2.2, 0.965), vert, Vector3.ZERO, 0.5)
	# le soldat (2,8 m), sur sa terrasse de bronze, face à la place
	var f := Node3D.new()
	f.position = Vector3(0, 3.56, 0)
	s.add_child(f)
	var m := 0.55
	_forme(f, _blo(Vector3(1.1, 0.12, 0.9)), Vector3(0, 0.06, 0), vert, Vector3.ZERO, m)
	# les jambes en léger pas, le pantalon large, les guêtres et les souliers
	_segment(f, Vector3(-0.15, 0.2, -0.12), Vector3(-0.13, 1.05, -0.02), 0.11, vert, m)
	_segment(f, Vector3(0.15, 0.2, 0.14), Vector3(0.12, 1.05, 0.02), 0.11, vert, m)
	_forme(f, _blo(Vector3(0.18, 0.12, 0.34)), Vector3(-0.15, 0.18, -0.06), vert.darkened(0.2), Vector3.ZERO, m)
	_forme(f, _blo(Vector3(0.18, 0.12, 0.34)), Vector3(0.15, 0.18, 0.22), vert.darkened(0.2), Vector3.ZERO, m)
	# la capote croisée, ses pans évasés jusqu'aux genoux, le ceinturon et la giberne
	_forme(f, _cyl(0.26, 0.36, 0.7), Vector3(0, 1.0, 0), vert, Vector3.ZERO, m)
	_forme(f, _cyl(0.25, 0.26, 0.55), Vector3(0, 1.6, 0), vert_clair, Vector3.ZERO, m)
	_forme(f, _cyl(0.27, 0.27, 0.08), Vector3(0, 1.36, 0), vert.darkened(0.25), Vector3.ZERO, m)
	_forme(f, _blo(Vector3(0.22, 0.14, 0.08)), Vector3(0.12, 1.34, 0.26), vert.darkened(0.25), Vector3.ZERO, m)
	_forme(f, _bou(0.3, 0.26), Vector3(0, 1.9, 0), vert_clair, Vector3.ZERO, m)
	for cote in [-1.0, 1.0]:
		_forme(f, _bou(0.11), Vector3(cote * 0.27, 1.9, 0), vert_clair, Vector3.ZERO, m)
	# la tête, le col, le shako à visière et pompon
	_forme(f, _cyl(0.08, 0.1, 0.12), Vector3(0, 2.05, 0), vert, Vector3.ZERO, m)
	_forme(f, _bou(0.13, 0.3), Vector3(0, 2.25, 0.02), vert_clair, Vector3.ZERO, m)
	_forme(f, _cyl(0.14, 0.12, 0.28), Vector3(0, 2.48, -0.01), vert.darkened(0.12), Vector3(-0.08, 0, 0), m)
	_forme(f, _blo(Vector3(0.2, 0.025, 0.12)), Vector3(0, 2.35, 0.15), vert.darkened(0.25), Vector3(0.25, 0, 0), m)
	_forme(f, _bou(0.05), Vector3(0, 2.66, 0.03), vert_clair, Vector3.ZERO, m)
	# le bras gauche levé vers la place, la main ouverte ; le droit tient le fusil crosse à terre
	var epaule_g := Vector3(-0.28, 1.88, 0.0)
	var coude_g := epaule_g + Vector3(-0.12, 0.2, 0.3)
	var main_g := coude_g + Vector3(-0.04, 0.28, 0.24)
	_segment(f, epaule_g, coude_g, 0.085, vert_clair, m)
	_segment(f, coude_g, main_g, 0.075, vert_clair, m)
	_forme(f, _bou(0.065, 0.15), main_g + Vector3(0, 0.05, 0.03), vert_clair, Vector3.ZERO, m)
	var epaule_d := Vector3(0.28, 1.88, 0.0)
	var coude_d := epaule_d + Vector3(0.1, -0.36, 0.08)
	var main_d := coude_d + Vector3(0.04, -0.12, 0.3)
	_segment(f, epaule_d, coude_d, 0.085, vert_clair, m)
	_segment(f, coude_d, main_d, 0.075, vert_clair, m)
	_segment(f, Vector3(0.44, 0.14, 0.42), Vector3(0.42, 1.95, 0.3), 0.035, vert.darkened(0.2), m)
	_forme(f, _blo(Vector3(0.09, 0.4, 0.14)), Vector3(0.44, 0.32, 0.42), vert.darkened(0.2), Vector3(-0.07, 0, 0), m)
	_segment(f, Vector3(0.42, 1.95, 0.3), Vector3(0.415, 2.3, 0.28), 0.01, vert_clair.lightened(0.25), 0.7)


## Une des deux fontaines aux lions (fonderie du Creusot, 1823) au pied de la montée : le lion de bronze
## couché sur son socle mouluré de pierre dorée, tourné vers l'axe de l'escalier, la gueule qui crache
## dans une vasque à margelle de Villebois, la mousse au bas de la pierre. sens : -1 à l'ouest, 1 à l'est.
func _fontaine_lion(f: Node3D, _sens: float) -> void:
	var dore := PIERRE_DOREE
	# la vasque, sa margelle arrondie, l'eau
	_forme(f, _blo(Vector3(3.2, 0.55, 1.9)), Vector3(0, 0.27, 0.75), VILLEBOIS.darkened(0.05))
	_forme(f, _blo(Vector3(3.4, 0.14, 2.1)), Vector3(0, 0.6, 0.75), VILLEBOIS)
	_forme(f, _blo(Vector3(2.9, 0.06, 1.6)), Vector3(0, 0.5, 0.78), EAU.lightened(0.2))
	_forme(f, _blo(Vector3(3.24, 0.12, 1.94)), Vector3(0, 0.06, 0.75), Color("#5d6b45"))
	# le socle mouluré, sa table, son mascaron
	_moulure(f, 0.0, 2.4, 1.4, dore.darkened(0.08), -1.0)
	_forme(f, _blo(Vector3(2.2, 1.9, 1.3)), Vector3(0, 1.25, -0.55), dore)
	_forme(f, _blo(Vector3(1.4, 1.0, 0.04)), Vector3(0, 1.3, 0.12), dore.lightened(0.06))
	_moulure(f, 2.2, 2.3, 1.4, dore, 1.0)
	_forme(f, _blo(Vector3(2.0, 0.12, 1.2)), Vector3(0, 2.56, -0.55), dore.darkened(0.06))
	var bronze := Color("#5a5236")
	var clair := Color("#7d6e45")
	var sombre := bronze.darkened(0.25)
	var m := 0.65
	var l := Node3D.new()
	l.position = Vector3(0, 2.62, -0.55)
	l.scale = Vector3.ONE * 1.25
	f.add_child(l)
	# le lion couché, face à la place : le dos qui s'abaisse vers la croupe, les flancs, les cuisses
	_segment(l, Vector3(0, 0.38, 0.25), Vector3(0, 0.32, -0.55), 0.3, bronze, m)
	_forme(l, _bou(0.34, 0.5), Vector3(0, 0.3, -0.62), bronze, Vector3.ZERO, m)
	for cote in [-1.0, 1.0]:
		_forme(l, _bou(0.24, 0.42), Vector3(cote * 0.22, 0.24, -0.55), bronze.lightened(0.04), Vector3(0, 0, cote * 0.3), m)
		_segment(l, Vector3(cote * 0.3, 0.1, -0.5), Vector3(cote * 0.3, 0.07, -0.05), 0.08, bronze, m)
		# les pattes de devant allongées vers la place, les doigts posés
		_segment(l, Vector3(cote * 0.18, 0.28, 0.32), Vector3(cote * 0.2, 0.08, 0.55), 0.1, bronze, m)
		_segment(l, Vector3(cote * 0.2, 0.08, 0.55), Vector3(cote * 0.2, 0.07, 0.92), 0.085, bronze, m)
		for d in 3:
			_forme(l, _bou(0.04), Vector3(cote * 0.2 + (d - 1) * 0.05, 0.05, 0.99), clair, Vector3.ZERO, m)
	# la queue enroulée le long du flanc, sa touffe
	_segment(l, Vector3(0.15, 0.2, -0.85), Vector3(0.38, 0.06, -0.55), 0.04, bronze, m)
	_segment(l, Vector3(0.38, 0.06, -0.55), Vector3(0.36, 0.05, -0.1), 0.035, bronze, m)
	_forme(l, _bou(0.07, 0.16), Vector3(0.36, 0.06, -0.04), sombre, Vector3.ZERO, m)
	# le poitrail, la crinière en mèches qui retombent sur les épaules, la tête levée
	_forme(l, _bou(0.33, 0.6), Vector3(0, 0.45, 0.35), bronze, Vector3.ZERO, m)
	_forme(l, _bou(0.4, 0.62), Vector3(0, 0.78, 0.36), sombre, Vector3(-0.35, 0, 0), m)
	for rang in 3:
		var nb := 9 - rang * 2
		for k in nb:
			var a := lerpf(-1.4, 1.4, float(k) / (nb - 1))
			var base := Vector3(sin(a) * (0.3 - rang * 0.05), 0.95 - rang * 0.05 + cos(a) * 0.08, 0.42 - rang * 0.14)
			_segment(l, base, base + Vector3(sin(a) * 0.12, -0.32, -0.08), 0.07 - rang * 0.008, sombre.lightened(rang * 0.05), m)
	_forme(l, _bou(0.22, 0.4), Vector3(0, 0.82, 0.58), clair, Vector3.ZERO, m)
	_forme(l, _blo(Vector3(0.2, 0.15, 0.2)), Vector3(0, 0.76, 0.76), clair, Vector3(0.15, 0, 0), m)
	_forme(l, _bou(0.05), Vector3(0, 0.82, 0.86), sombre, Vector3.ZERO, m)
	_forme(l, _blo(Vector3(0.14, 0.05, 0.1)), Vector3(0, 0.66, 0.8), Color("#1e1c14"), Vector3.ZERO, 0.2)
	for cote in [-1.0, 1.0]:
		_forme(l, _bou(0.06, 0.1), Vector3(cote * 0.14, 1.02, 0.52), sombre, Vector3.ZERO, m)
		_forme(l, _bou(0.03), Vector3(cote * 0.08, 0.88, 0.76), Color("#1e1c14"), Vector3.ZERO, 0.2)
	# le filet d'eau de la gueule à la vasque, en arc
	var eau := _mat(Color("#cfe3e6"), 0.05)
	eau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eau.albedo_color.a = 0.65
	var avant := Vector3(0, 0.64, 0.86)
	for k in range(1, 9):
		var t := k / 8.0
		var q := Vector3(0, 0.64 - t * t * 2.34, 0.86 + t * 0.38)
		_segment(l, avant, q, 0.03 + t * 0.012, Color.WHITE).material_override = eau
		avant = q


func _boite(parent: Node3D, taille: Vector3, p: Vector3, c: Color, inclinaison := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = p
	mi.rotation.z = inclinaison
	parent.add_child(mi)
	return mi


# --- Les arbres -----------------------------------------------------------------------------------

## Les arbres réels (OpenStreetMap) : des platanes sur la place et le long des rues, le jardin des
## Plantes plus varié. Au-delà de 220 m, rien : le lointain se lit par les toits.
func _arbres() -> void:
	var k := 0
	for a in data.arbres:
		var p := Vector2(a[0], a[1]) * U
		var d := p.distance_to(CENTRE_PLACE)
		if d > 220.0:
			continue
		k += 1
		if PLACE.has_point(p):
			continue
		# les platanes des rues et des quais, les micocouliers des cours et du jardin des pentes
		var arbre := "jeune_platane"
		var haut := _rng.randf_range(9.0, 12.0)
		if p.y < -60.0 and k % 3 == 0:
			arbre = "micocoulier"
			haut = _rng.randf_range(9.0, 11.0)
		_pose(OMBRIERE, "arbre", arbre, _sur(p.x, p.y), 500 + k, {"hauteur": haut, "vent": 0.3})


# --- Le lointain ----------------------------------------------------------------------------------

## Fourvière, de l'autre côté de la Saône : la colline qui ferme l'ouest, ses jardins et ses toits étagés, la
## basilique et ses quatre tours, la tour métallique. Le soleil se couche derrière : depuis les pentes, on la
## voit en silhouette sur le ciel d'or (« les partis pris »). Rapprochée et grandie : un relief à part, qui
## naît sous le terrain du quartier et monte au-delà de la rivière.
func _fourviere() -> void:
	var f := Node3D.new()
	f.name = "Fourviere"
	ville.add_child(f)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 64
	var taille := 1500.0
	var o := FOURVIERE + Vector3(-taille * 0.5, 0, -taille * 0.5)
	var vert := Color("#56703f")
	for j in n + 1:
		for i in n + 1:
			var x := o.x + taille * i / n
			var z := o.z + taille * j / n
			var y := _colline(x, z)
			var t := clampf(y / 130.0, 0.0, 1.0)
			var c := vert.lerp(Color("#7d8a55"), _rng.randf() * 0.5).darkened(0.15 * (1.0 - t))
			st.set_color(c)
			st.add_vertex(Vector3(x, y, z))
	for j in n:
		for i in n:
			var k := j * (n + 1) + i
			for idx in [k, k + 1, k + n + 1, k + 1, k + n + 2, k + n + 1]:
				st.add_index(idx)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(Color.WHITE, 1.0, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(mi)
	# les toits et les murs de terrasses sur la pente qui regarde la Saône
	for k in 260:
		var x := FOURVIERE.x + _rng.randf_range(-520.0, 420.0)
		var z := FOURVIERE.z + _rng.randf_range(-560.0, 380.0)
		var y := _colline(x, z)
		if y < 8.0 or (x - FOURVIERE.x) > 260.0 + (FOURVIERE.z - z) * 0.2:
			continue
		var w := _rng.randf_range(10.0, 22.0)
		var h := _rng.randf_range(9.0, 18.0)
		var c := Color(ENDUITS_PLACE[k % ENDUITS_PLACE.size()]).lightened(0.05)
		_boite(f, Vector3(w, h, w * 0.8), Vector3(x, y + h * 0.5 - 2.0, z), c)
		_boite(f, Vector3(w + 0.8, 1.6, w * 0.8 + 0.8), Vector3(x, y + h - 1.2, z), Color(TUILES[k % TUILES.size()]))
	# la basilique au sommet, de pierre blanche : la nef, l'abside, et ses quatre tours octogonales
	var sommet := Vector3(FOURVIERE.x, _colline(FOURVIERE.x, FOURVIERE.z) - 2.0, FOURVIERE.z)
	var blanc := Color("#ece4d2")
	_boite(f, Vector3(80.0, 30.0, 32.0), sommet + Vector3(0, 15.0, 0), blanc)
	_boite(f, Vector3(82.0, 5.0, 34.0), sommet + Vector3(0, 32.0, 0), blanc.darkened(0.15))
	for cx in [-34.0, 34.0]:
		for cz in [-15.0, 15.0]:
			var tour := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 4.0
			cy.bottom_radius = 5.0
			cy.height = 52.0
			cy.radial_segments = 8
			tour.mesh = cy
			tour.material_override = _mat(blanc)
			tour.position = sommet + Vector3(cx, 26.0, cz)
			f.add_child(tour)
	# la statue dorée de la chapelle, à côté, et la tour métallique plus au nord
	_boite(f, Vector3(8.0, 30.0, 8.0), sommet + Vector3(-52.0, 15.0, -6.0), blanc.darkened(0.05))
	var pied := Vector3(TOUR.x, _colline(TOUR.x, TOUR.z), TOUR.z)
	var tm := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.8
	cm.bottom_radius = 7.0
	cm.height = 86.0
	cm.radial_segments = 4
	tm.mesh = cm
	tm.material_override = _mat(Color("#8a8f94"), 0.5)
	tm.position = pied + Vector3(0, 43.0, 0)
	f.add_child(tm)


## La colline : un dôme allongé du nord au sud, qui plonge sous le quartier avant la Saône.
func _colline(x: float, z: float) -> float:
	var dx := (x - FOURVIERE.x) / 300.0
	var dz := (z - FOURVIERE.z) / 480.0
	var d2 := dx * dx + dz * dz
	return 160.0 * exp(-d2 * 2.2) / (1.0 + 0.0 * d2) - 18.0


# --- Les repères et l'habitant --------------------------------------------------------------------

## Les trois scènes de la note, en unités du jeu : l'œil posé sur le sol, -Z vers ce qu'on doit voir.
func _reperes() -> void:
	var reperes := {
		"Arrivee": [Vector2(-157.0, 143.0), Vector2(-148.0, 40.0)],
		"Vue1a_Passerelle": [Vector2(-157.0, 143.0), Vector2(-148.0, 40.0)],
		"Vue1b_Martiniere": [Vector2(-149.0, 114.0), Vector2(0.0, 116.0)],
		"Vue1c_Rambaud": [Vector2(-30.0, 114.0), Vector2(68.0, 118.0)],
		"Vue1d_Vitet": [Vector2(68.0, 116.0), Vector2(34.0, 57.0)],
		"Vue1e_Rue": [Vector2(34.0, 57.0), Vector2(12.0, 40.0)],
		"Vue2a_Place": [Vector2(12.0, 49.0), Vector2(10.0, -30.0)],
		"Vue2b_Lions": [Vector2(10.5, -11.0), Vector2(10.5, -60.0)],
		"Vue2c_Palier": [Vector2(16.4, -44.0), Vector2(16.4, -90.0)],
		"Vue3a_Belvedere": [Vector2(16.4, -83.0), Vector2(10.0, 60.0)],
	}
	for nom in reperes:
		var m: Node3D = get_node_or_null(nom)
		if m == null:
			continue
		var a: Vector2 = reperes[nom][0]
		var b: Vector2 = reperes[nom][1]
		var pa := Vector3(a.x, hauteur(a.x, a.y) + 0.1, a.y) / U
		m.global_transform = Transform3D(Basis(), pa)
		m.look_at(Vector3(b.x / U, pa.y, b.y / U), Vector3.UP)


func _joueur() -> void:
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/orbit_camera.gd"))
	camera.far = 900.0
	add_child(camera)
	player = load("res://scripts/fp_player.gd").new()
	player.eye = 0.6
	player.body_height = 0.7
	player.radius = 0.14
	player.speed = 1.5
	player.reach = 2.4
	add_child(player)
	var me: Node3D = load("res://scripts/critter.gd").new()
	me.look = Cast.moi()
	me.walk_speed = 1.0
	me.run_speed = 1.9
	me.rotation.y = PI
	player.add_child(me)
	player.avatar = me
	player.global_transform = $Arrivee.global_transform
	camera.make_current()
	player.follow_camera = camera
	camera.au_dela.connect(func(): Carte.ouvrir())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.target = player.global_position + Vector3(0, 0.3, 0)
	camera.set("_target_goal", camera.target)
	camera.use_notches(CRANS, 1)
