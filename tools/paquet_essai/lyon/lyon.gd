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
const CRANS := [[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [40.0, -58.0, 30.0], [90.0, -62.0, 30.0]]

## La fin d'après-midi de septembre de la planche de Guillaume : un soleil doré venu de l'ouest, encore haut.
const SOLEIL := {"hauteur": 31.0, "vient_de": 258.0, "couleur": Color("#ffe1b0")}

## La palette de la note (« Palette et matières »).
const ENDUITS_PLACE := ["ecd59c", "f1e1b8", "eac39a", "f0d6a4", "e6c08e", "f3e6c6"]
const ENDUITS_PENTES := ["e2cc98", "e9d6b0", "dcb78f", "e4c8a0", "d8c3a2"]
const TUILES := ["c4502c", "b0452a", "c85a33", "a9432a"]
const PAVE := Color("#8e8a84")
const DALLE := Color("#c9c1b2")
const SABLE := Color("#dcbc8c")
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
	e.ambient_light_energy = 0.5
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
	_boite(ville, Vector3(SQUARE.size.x, 0.1, SQUARE.size.y), Vector3(SQUARE.get_center().x, _niveau_place + 0.05, SQUARE.get_center().y), SABLE).material_override.roughness = 1.0
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
		for r in data.routes:
			for k in r.p.size() - 1:
				_segments.append([Vector2(r.p[k][0], r.p[k][1]) * U, Vector2(r.p[k + 1][0], r.p[k + 1][1]) * U])
	var best := 1e9
	for sg in _segments:
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
		var opt := {"w": w - 0.05, "d": lv, "niveaux": niveaux}
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
	_boite(s, Vector3(6.4, 0.18, 6.4), Vector3(0, 0.09, 0), VILLEBOIS)
	_boite(s, Vector3(4.6, 0.3, 4.6), Vector3(0, 0.33, 0), VILLEBOIS.darkened(0.05))
	_boite(s, Vector3(3.2, 0.35, 3.2), Vector3(0, 0.65, 0), VILLEBOIS)
	_boite(s, Vector3(1.7, 2.3, 1.7), Vector3(0, 1.95, 0), VILLEBOIS.lightened(0.05))
	_boite(s, Vector3(2.1, 0.3, 2.1), Vector3(0, 3.25, 0), VILLEBOIS.darkened(0.08))
	var statue := Color("#4e6656")
	_boite(s, Vector3(0.62, 1.25, 0.42), Vector3(0, 4.05, 0), statue)
	_boite(s, Vector3(0.8, 1.05, 0.5), Vector3(0, 5.2, 0), statue)
	_boite(s, Vector3(0.2, 1.0, 0.2), Vector3(0.5, 6.0, -0.1), statue, 0.5)
	var tete := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.22
	sp.height = 0.46
	tete.mesh = sp
	tete.material_override = _mat(statue, 0.4)
	tete.position = Vector3(0, 5.95, 0)
	s.add_child(tete)
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
		_pose(VEGETATION, "plante", "platane", Vector3(p.x, y, p.y), 400 + k, {"hauteur": _rng.randf_range(14.0, 17.0), "vent": true})
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
	for k in 5:
		_pose(MOBILIER, "objet", "terrasse", Vector3(-11.5, y, -2.0 + k * 3.8), 60 + k, {"toile": ["b8352e", "f3ead6"] if k < 3 else ["2f5a3a", "f3ead6"]})
	for k in 2:
		_pose(MOBILIER, "objet", "terrasse", Vector3(31.0, y, 22.0 + k * 3.8), 70 + k, {"toile": ["c8372e", "f2c94c"]})
	for z in [-10.0, 6.0, 30.0]:
		_pose(MOBILIER, "objet", "jardiniere", Vector3(-12.8, y, z), 100 + int(z), {"fleurs": "e0605a"})
		_pose(MOBILIER, "objet", "jardiniere", Vector3(32.4, y, z + 4.0), 120 + int(z), {"fleurs": "d04a8a"})


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
	for cote in [-1.0, 1.0]:
		var x: float = 10.5 + cote * 5.0
		_boite(e, Vector3(1.0, (y1 - y0) + 1.2, z0 - z1), Vector3(x, (y0 + y1) * 0.5 + 0.4, (z0 + z1) * 0.5), PIERRE_DOREE)
	_boite(e, Vector3(16.0, y1 - y0 + 0.2, 6.0), Vector3(10.5, (y0 + y1) * 0.5 - 0.1, z1 - 3.0), pierre)
	_pose(MOBILIER, "objet", "garde_corps", Vector3(10.5, y1, z1 - 0.2), 7, {"longueur": 7.0})
	# les deux fontaines aux lions de bronze, au pied de l'escalier
	for k in LIONS.size():
		var p: Vector2 = LIONS[k]
		var f := Node3D.new()
		f.name = "Lion%d" % (k + 1)
		f.position = Vector3(p.x, y0, p.y)
		ville.add_child(f)
		_boite(f, Vector3(3.2, 0.7, 2.0), Vector3(0, 0.35, 0.6), PIERRE_DOREE.darkened(0.1))
		_boite(f, Vector3(3.0, 0.15, 1.8), Vector3(0, 0.62, 0.6), EAU.lightened(0.15))
		_boite(f, Vector3(2.2, 2.0, 1.2), Vector3(0, 1.4, -0.6), PIERRE_DOREE)
		_boite(f, Vector3(1.8, 0.55, 0.8), Vector3(0, 2.65, -0.6), BRONZE)
		var tete := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.38
		sp.height = 0.76
		tete.mesh = sp
		tete.material_override = _mat(BRONZE, 0.35)
		tete.material_override.metallic = 0.6
		tete.position = Vector3(0.75 if k == 0 else -0.75, 3.05, -0.35)
		f.add_child(tete)
	# le jardin en haut : les deux volées latérales et le belvédère
	for x in [3.4, 16.4]:
		var ya := hauteur(x, -50.0)
		var yb := hauteur(x, -80.0)
		var n := 30
		for k in n:
			var z := lerpf(-50.0, -80.0, float(k) / n)
			var yy := lerpf(ya, yb, float(k + 1) / n)
			_boite(e, Vector3(3.0, 0.4, 1.02), Vector3(x, yy - 0.2, z - 0.5), pierre)


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
		var sur_la_place := false
		var plante := "platane"
		var haut := _rng.randf_range(11.0, 13.5) if sur_la_place else _rng.randf_range(9.0, 12.0)
		if p.y < -60.0 and k % 3 == 0:
			plante = "alignement"
			haut = _rng.randf_range(8.0, 11.0)
		_pose(VEGETATION, "plante", plante, _sur(p.x, p.y), 500 + k, {"hauteur": haut, "pied": "grille" if sur_la_place else ""})


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
