extends Node3D
## Availles-Limouzine, le bourg dans sa disposition réelle : les rues, les places, les bâtiments à
## leur place et à leur hauteur, la Vienne et son pont, le relief du coteau. Tout vient de bourg.json,
## construit par tools/bourg_reel.py à partir d'OpenStreetMap, de la BD TOPO et du RGE ALTI de l'IGN,
## à l'échelle de Smarves (une unité vaut 2,4 m). Les bâtiments sont les maisons du Poitou de Smarves
## (scripts/village/facades.gd), posées sur leur emprise réelle, façade sur la rue ; les lieux
## remarquables (l'église, la mairie, le pont, les portes…) sont des nœuds à part, nommés
## « Remarquable_<id> », prêts à être remplacés par leur vraie silhouette. Du décor que l'on parcourt :
## l'habitant de Smarves y marche, avec la caméra à crans du village et un cran de plus pour voir
## tout le bourg ; dézoomer au-delà ouvre la carte de la Vienne.

const DOSSIER := "res://communes/availles_limouzine/"
const KN := "res://assets/kenney/nature/"
const CRANS := [[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [40.0, -60.0, 30.0], [100.0, -62.0, 30.0]]
const PIERRE := Color(0.86, 0.8, 0.68)
const OR := Color(0.95, 0.82, 0.5)
## Les monuments dont les murs restent nus, en attendant leur vraie silhouette.
const FACADES := preload("res://scripts/village/facades.gd")
const REMARQUABLES := preload(DOSSIER + "remarquables.gd")
const SANS_FENETRES := ["eglise", "porte_cavaliers", "porte_riviere"]
## Où l'on arrive : la place de la Mairie, entre la porte des Cavaliers et la rue qui descend au pont.
const ARRIVEE_NOM := "Place de la Mairie"
const AIDE_DESSUS := "ZQSD : marcher  ·  Maj : courir  ·  clic droit : tourner  ·  molette : zoomer  ·  Tab : vue à pied  ·  M ou dézoomer encore : la carte"
const AIDE_A_PIED := "ZQSD : marcher  ·  Maj : courir  ·  souris : regarder  ·  Tab : vue de dessus"

## Pour le socle (Tactile) : l'habitant qu'on dirige, la caméra à crans, et l'on marche.
var player: CharacterBody3D
var camera: Camera3D
var fps := true

var data: Dictionary
var remarquables: Array = []
var _h := PackedFloat32Array()
var _nx := 0
var _nz := 0
var _x0 := 0.0
var _z0 := 0.0
var _pas := 1.0
var _mats := {}
var _ici: Label
var _aide: Label
var _capture := ""
var _suivre := true
var _arrivee := Vector2.ZERO
## Les trottoirs, par case d'une unité : [x, z, largeur] des points de leur axe (voir _trottoirs).
var _bandes := {}
const TROTTOIR_H := 0.12
## Les zones travaillées à la main d'après l'orthophoto (zones.json) : emprise nivelée, enrobé,
## trottoirs, arbres, passages, stationnements. Chaque zone garde son polygone dans « poly ».
const ZONES := DOSSIER + "zones.json"
var zones: Array = []


func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "bourg.json"))
	var r: Dictionary = data.relief
	_nx = int(r.nx)
	_nz = int(r.nz)
	_x0 = r.x0
	_z0 = r.z0
	_pas = r.pas
	_h = PackedFloat32Array(r.h)
	_charger_zones()
	_niveler()
	for p in data.places:
		if p.nom == ARRIVEE_NOM:
			_arrivee = Vector2(p.x, p.z)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--view="):
			_suivre = false
	_ciel()
	_terrain()
	_eau()
	_routes()
	_sols()
	_trottoirs()
	_zones_dessin()
	_batiments()
	_arbres()
	_noms()
	_joueur()
	_interface()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			_capture = a.trim_prefix("--capture=")
		elif a.begins_with("--a="):
			var v := a.trim_prefix("--a=").split_floats(",")
			player.global_position = Vector3(v[0], hauteur(v[0], v[1]) + 0.05, v[1])
			if v.size() > 2 and _suivre:
				camera.set_notch(int(v[2]))
			if v.size() > 3:
				camera.yaw = deg_to_rad(v[3])
				camera.set("_yaw_goal", camera.yaw)
		elif a.begins_with("--oeil="):
			# Un œil posé à hauteur d'homme : x,y,z de l'œil, puis x,y,z du point regardé, y au-dessus du sol.
			var v := a.trim_prefix("--oeil=").split_floats(",")
			_suivre = false
			camera.set_process(false)
			camera.global_position = Vector3(v[0], hauteur(v[0], v[2]) + v[1], v[2])
			camera.look_at(Vector3(v[3], hauteur(v[3], v[5]) + v[4], v[5]))
	if _capture != "":
		_capturer()


## L'altitude du sol en (x, z), sur les mêmes triangles que le terrain dessiné.
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


# --- Les zones travaillées à la main ---------------------------------------------------------------

func _charger_zones() -> void:
	if not FileAccess.file_exists(ZONES):
		return
	var j = JSON.parse_string(FileAccess.get_file_as_string(ZONES))
	if not j is Dictionary:
		return
	for z in j.get("zones", []):
		var poly := PackedVector2Array()
		for q in z.emprise:
			poly.append(Vector2(q[0], q[1]))
		z["poly"] = poly
		zones.append(z)


func _dans_zone(p: Vector2) -> bool:
	for z in zones:
		if Geometry2D.is_point_in_polygon(p, z.poly):
			return true
	return false


## La distance de `p` au polygone : 0 dedans, sinon jusqu'au bord le plus proche.
func _distance_poly(p: Vector2, poly: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var d := INF
	for k in poly.size():
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()])))
	return d


## Le nivellement d'une zone : le relief dans l'emprise est remplacé par le plan des moindres carrés
## de ses points (la pente d'ensemble reste, les bosses et les creux s'en vont), raccordé en douceur
## sur trois unités autour. Les bâtiments à portée reposent ensuite sur ce sol.
func _niveler() -> void:
	const RACCORD := 3.0
	for z in zones:
		if not z.get("nivelle", false):
			continue
		var poly: PackedVector2Array = z.poly
		var bas := Vector2(INF, INF)
		var haut := Vector2(-INF, -INF)
		for q in poly:
			bas = Vector2(minf(bas.x, q.x), minf(bas.y, q.y))
			haut = Vector2(maxf(haut.x, q.x), maxf(haut.y, q.y))
		var sxx := 0.0
		var sxz := 0.0
		var szz := 0.0
		var sx := 0.0
		var sz := 0.0
		var n := 0.0
		var shx := 0.0
		var shz := 0.0
		var sh := 0.0
		for j in _nz:
			for i in _nx:
				var p := Vector2(_x0 + i * _pas, _z0 + j * _pas)
				if p.x < bas.x or p.x > haut.x or p.y < bas.y or p.y > haut.y:
					continue
				if not Geometry2D.is_point_in_polygon(p, poly):
					continue
				var h := _h[j * _nx + i]
				sxx += p.x * p.x
				sxz += p.x * p.y
				szz += p.y * p.y
				sx += p.x
				sz += p.y
				n += 1.0
				shx += h * p.x
				shz += h * p.y
				sh += h
		if n < 3.0:
			continue
		var m := Basis(Vector3(sxx, sxz, sx), Vector3(sxz, szz, sz), Vector3(sx, sz, n))
		var abc := m.inverse() * Vector3(shx, shz, sh)
		for j in _nz:
			for i in _nx:
				var p := Vector2(_x0 + i * _pas, _z0 + j * _pas)
				if p.x < bas.x - RACCORD or p.x > haut.x + RACCORD or p.y < bas.y - RACCORD or p.y > haut.y + RACCORD:
					continue
				var d := _distance_poly(p, poly)
				if d >= RACCORD:
					continue
				var plan := abc.x * p.x + abc.y * p.y + abc.z
				var k := j * _nx + i
				_h[k] = lerpf(plan, _h[k], smoothstep(0.0, 1.0, d / RACCORD))
	for b in data.batiments:
		var c := Vector2(b.rect[0], b.rect[1])
		for z in zones:
			if z.get("nivelle", false) and _distance_poly(c, z.poly) < 4.0:
				var plancher := INF
				for q in b.p:
					plancher = minf(plancher, hauteur(q[0], q[1]))
				b.sol = minf(float(b.sol), plancher)
				break


## Le niveau où l'on pose un pied, un socle ou un lampadaire : le terrain, plus le trottoir s'il y en a un.
func sol(x: float, z: float) -> float:
	return hauteur(x, z) + _trottoir_en(x, z)


## La hauteur du trottoir en (x, z) : TROTTOIR_H sur un trottoir, 0 ailleurs.
func _trottoir_en(x: float, z: float) -> float:
	var cx := int(floor(x))
	var cz := int(floor(z))
	for i in range(cx - 1, cx + 2):
		for j in range(cz - 1, cz + 2):
			for t in _bandes.get(Vector2i(i, j), []):
				if Vector2(x, z).distance_to(Vector2(t[0], t[1])) <= t[2] / 2.0 + 0.45:
					return TROTTOIR_H
	return 0.0


func _mat(c: Color, rugueux := 0.9, couleurs_sommets := false) -> StandardMaterial3D:
	var k := "%s%s%s" % [c, rugueux, couleurs_sommets]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rugueux
		m.vertex_color_use_as_albedo = couleurs_sommets
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[k] = m
	return _mats[k]


func _ciel() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.46, 0.7)
	sm.sky_horizon_color = Color(0.86, 0.74, 0.6)
	sm.ground_horizon_color = Color(0.5, 0.45, 0.38)
	sm.ground_bottom_color = Color(0.18, 0.16, 0.14)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.light_color = Color(1.0, 0.86, 0.68)
	soleil.light_energy = 1.25
	soleil.shadow_enabled = true
	soleil.shadow_opacity = 0.65
	soleil.directional_shadow_max_distance = 140.0
	soleil.rotation_degrees = Vector3(-38, -35, 0)
	add_child(soleil)


# --- Le terrain -----------------------------------------------------------------------------------

func _terrain() -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	v.resize(_nx * _nz)
	n.resize(_nx * _nz)
	uv.resize(_nx * _nz)
	uv2.resize(_nx * _nz)
	for j in _nz:
		for i in _nx:
			var k := j * _nx + i
			v[k] = Vector3(_x0 + i * _pas, _h[k], _z0 + j * _pas)
			var gx := _h[j * _nx + mini(i + 1, _nx - 1)] - _h[j * _nx + maxi(i - 1, 0)]
			var gz := _h[mini(j + 1, _nz - 1) * _nx + i] - _h[maxi(j - 1, 0) * _nx + i]
			n[k] = Vector3(-gx, 2.0 * _pas, -gz).normalized()
			uv[k] = Vector2(float(i) / (_nx - 1), float(j) / (_nz - 1))
			uv2[k] = Vector2(v[k].x, v[k].z) / 10.0
	var idx := PackedInt32Array()
	for j in _nz - 1:
		for i in _nx - 1:
			var a := j * _nx + i
			idx.append_array([a, a + 1, a + _nx, a + 1, a + _nx + 1, a + _nx])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(DOSSIER + "sol.png")
	# La couverture peinte vue d'avion, et par-dessus, à l'échelle du pas, le grain de l'herbe et de
	# la terre (un bruit en UV2, en coordonnées du monde) pour que le sol tienne de près.
	mat.albedo_color = Color(1.0, 1.0, 0.98)
	mat.detail_enabled = true
	mat.detail_albedo = _grain(0.12, Color(0.74, 0.77, 0.68))
	mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = m
	mi.material_override = mat
	add_child(mi)

	# Le sol où l'on marche : la même grille, à l'échelle d'une maille.
	var hm := HeightMapShape3D.new()
	hm.map_width = _nx
	hm.map_depth = _nz
	var hs := PackedFloat32Array()
	hs.resize(_h.size())
	for k in _h.size():
		hs[k] = _h[k] / _pas
	hm.map_data = hs
	var corps := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = hm
	cs.scale = Vector3.ONE * _pas
	cs.position = Vector3(_x0 + (_nx - 1) * _pas / 2.0, 0.0, _z0 + (_nz - 1) * _pas / 2.0)
	corps.add_child(cs)
	add_child(corps)

	# Le socle de la maquette : les bords du terrain descendent jusqu'à une tranche de terre.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bas := -4.0
	var bords := []
	for i in _nx:
		bords.append(Vector2i(i, 0))
	for j in _nz:
		bords.append(Vector2i(_nx - 1, j))
	for i in range(_nx - 1, -1, -1):
		bords.append(Vector2i(i, _nz - 1))
	for j in range(_nz - 1, -1, -1):
		bords.append(Vector2i(0, j))
	for k in bords.size() - 1:
		var a: Vector2i = bords[k]
		var b: Vector2i = bords[k + 1]
		if a == b:
			continue
		var pa := Vector3(_x0 + a.x * _pas, _h[a.y * _nx + a.x], _z0 + a.y * _pas)
		var pb := Vector3(_x0 + b.x * _pas, _h[b.y * _nx + b.x], _z0 + b.y * _pas)
		var qa := Vector3(pa.x, bas, pa.z)
		var qb := Vector3(pb.x, bas, pb.z)
		st.add_vertex(pa)
		st.add_vertex(pb)
		st.add_vertex(qb)
		st.add_vertex(pa)
		st.add_vertex(qb)
		st.add_vertex(qa)
	st.generate_normals()
	var socle := MeshInstance3D.new()
	socle.mesh = st.commit()
	socle.material_override = _mat(Color(0.36, 0.27, 0.2))
	add_child(socle)


# --- L'eau ----------------------------------------------------------------------------------------

func _eau() -> void:
	var niveau: float = data.niveau_eau if data.niveau_eau != null else 0.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.27, 0.45, 0.52)
	mat.roughness = 0.08
	mat.metallic = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var murs := PackedVector3Array()
	var ponts := []
	for r in data.routes:
		if r.get("pont", false):
			ponts.append(r)
	for e in data.eau:
		var poly := PackedVector2Array()
		for q in e.p:
			poly.append(Vector2(q[0], q[1]))
		var tri := Geometry2D.triangulate_polygon(poly)
		if tri.is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		# Un petit plan d'eau prend le niveau de son sol ; la rivière, le niveau mesuré.
		var y := niveau
		if not e.has("nom"):
			y = INF
			for p in poly:
				y = minf(y, hauteur(p.x, p.y))
			y += 0.15
		for k in tri:
			st.add_vertex(Vector3(poly[k].x, y, poly[k].y))
		var mi := MeshInstance3D.new()
		mi.name = "Eau" if not e.has("nom") else str(e.nom).replace(" ", "")
		mi.mesh = st.commit()
		mi.material_override = mat
		add_child(mi)
		if not e.has("nom"):
			continue
		# On ne marche pas dans la rivière : un mur invisible suit ses rives, sauf sous les ponts.
		for k in poly.size():
			var a := poly[k]
			var b := poly[(k + 1) % poly.size()]
			var pas := maxi(1, int(a.distance_to(b) / 0.8))
			for s in pas:
				var p0 := a.lerp(b, float(s) / pas)
				var p1 := a.lerp(b, float(s + 1) / pas)
				if _sous_un_pont((p0 + p1) / 2.0, ponts):
					continue
				var h0 := Vector3(p0.x, y - 2.0, p0.y)
				var h1 := Vector3(p1.x, y - 2.0, p1.y)
				var t0 := Vector3(p0.x, y + 3.0, p0.y)
				var t1 := Vector3(p1.x, y + 3.0, p1.y)
				murs.append_array([h0, h1, t1, h0, t1, t0])
	if not murs.is_empty():
		var c := ConcavePolygonShape3D.new()
		c.backface_collision = true
		c.set_faces(murs)
		var corps := StaticBody3D.new()
		corps.name = "Rives"
		var cs := CollisionShape3D.new()
		cs.shape = c
		corps.add_child(cs)
		add_child(corps)
	# Les ruisseaux, des rubans d'eau sur le sol.
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	for r in data.ruisseaux:
		n += _ruban(st2, r.p, r.l, 0.03, Color.WHITE)
	if n > 0:
		st2.generate_normals()
		var mi2 := MeshInstance3D.new()
		mi2.name = "Ruisseaux"
		mi2.mesh = st2.commit()
		mi2.material_override = mat
		add_child(mi2)


func _sous_un_pont(p: Vector2, ponts: Array) -> bool:
	for r in ponts:
		for k in r.p.size() - 1:
			var a := Vector2(r.p[k][0], r.p[k][1])
			var b := Vector2(r.p[k + 1][0], r.p[k + 1][1])
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < r.l / 2.0 + 0.6:
				return true
	return false


# --- Les rues et les ponts -------------------------------------------------------------------------

## Les revêtements : [matière, teinte (multiplie la matière), hauteur au-dessus du terrain].
## Le bitume granuleux des rues et les dalles calcaires des trottoirs sont ceux de Smarves.
const REVETEMENTS := {
	"secondary": ["bitume", 0.88, 0.05], "primary": ["bitume", 0.88, 0.05], "tertiary": ["bitume", 0.94, 0.05],
	"residential": ["bitume", 1.04, 0.05], "unclassified": ["bitume", 1.04, 0.05], "road": ["bitume", 1.04, 0.05],
	"living_street": ["bitume", 1.14, 0.05], "service": ["bitume", 1.16, 0.045], "cycleway": ["bitume", 0.96, 0.045],
	"pedestrian": ["gravier", 1.1, 0.045], "footway": ["gravier", 1.06, 0.04], "steps": ["gravier", 1.1, 0.04],
	"track": ["gravier", 0.92, 0.04], "path": ["gravier", 0.9, 0.04],
}
## Les rues du bourg qui ont des trottoirs quand elles sont bâties.
const AVEC_TROTTOIRS := ["secondary", "primary", "tertiary", "residential", "unclassified", "road", "living_street"]
## Les routes marquées d'un pointillé au milieu.
const AVEC_POINTILLES := ["secondary", "primary", "tertiary"]


func _sols_materiaux() -> void:
	if _mats.has("bitume"):
		return
	var bitume := StandardMaterial3D.new()
	bitume.albedo_color = Color(0.5, 0.49, 0.47)
	bitume.albedo_texture = _grain(0.18, Color(0.6, 0.6, 0.62))
	bitume.uv1_triplanar = true
	bitume.uv1_scale = Vector3(0.35, 0.35, 0.35)
	bitume.roughness = 0.85
	bitume.vertex_color_use_as_albedo = true
	bitume.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats.bitume = bitume
	var gravier := StandardMaterial3D.new()
	gravier.albedo_color = Color(0.66, 0.6, 0.48)
	gravier.albedo_texture = _grain(0.25, Color(0.7, 0.68, 0.64))
	gravier.uv1_triplanar = true
	gravier.uv1_scale = Vector3(0.5, 0.5, 0.5)
	gravier.roughness = 1.0
	gravier.vertex_color_use_as_albedo = true
	gravier.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats.gravier = gravier
	# Les trottoirs : un béton clair uni, à peine grenu, sans motif qui trahirait l'échelle.
	var dalles := StandardMaterial3D.new()
	dalles.albedo_color = Color(0.74, 0.72, 0.67)
	dalles.albedo_texture = _grain(0.3, Color(0.86, 0.85, 0.82))
	dalles.uv1_triplanar = true
	dalles.uv1_scale = Vector3(0.6, 0.6, 0.6)
	dalles.roughness = 0.95
	dalles.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats.dalles = dalles
	# La bordure : un ciment uni, un peu plus clair que le trottoir.
	var bordure := StandardMaterial3D.new()
	bordure.albedo_color = Color(0.8, 0.79, 0.75)
	bordure.roughness = 0.8
	bordure.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats.bordure = bordure
	# Le sol piéton des places : un béton sablé chaud, posé à plat, cerné d'un filet de ciment.
	var sable := StandardMaterial3D.new()
	sable.albedo_color = Color(0.8, 0.75, 0.66)
	sable.albedo_texture = _grain(0.4, Color(0.88, 0.86, 0.8))
	sable.uv1_triplanar = true
	sable.uv1_scale = Vector3(0.7, 0.7, 0.7)
	sable.roughness = 1.0
	sable.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats.sable = sable
	var marque := StandardMaterial3D.new()
	marque.albedo_color = Color(0.86, 0.86, 0.8)
	marque.roughness = 0.7
	_mats.marque = marque


## La ligne densifiée d'une voie : un point tous les `pas` environ, les sommets d'origine compris.
func _densifier(pts: Array, pas: float) -> PackedVector2Array:
	var ligne := PackedVector2Array()
	for k in pts.size():
		var p := Vector2(pts[k][0], pts[k][1])
		if k > 0:
			var prec := ligne[ligne.size() - 1]
			var n := int(prec.distance_to(p) / pas)
			for s in range(1, n):
				ligne.append(prec.lerp(p, float(s) / n))
		ligne.append(p)
	return ligne


## Un ruban posé sur le relief, le long d'une ligne de points [x, z] ; rend le nombre de points.
func _ruban(st: SurfaceTool, pts: Array, largeur: float, dessus: float, c: Color) -> int:
	var ligne := _densifier(pts, 0.8)
	if ligne.size() < 2:
		return 0
	st.set_color(c)
	var g: Array[Vector3] = []
	var d: Array[Vector3] = []
	var dehors := PackedByteArray()
	for k in ligne.size():
		var avant := ligne[maxi(k - 1, 0)]
		var apres := ligne[mini(k + 1, ligne.size() - 1)]
		var dir := (apres - avant).normalized()
		var perp := Vector2(-dir.y, dir.x) * largeur / 2.0
		var pg := ligne[k] + perp
		var pd := ligne[k] - perp
		g.append(Vector3(pg.x, hauteur(pg.x, pg.y) + dessus, pg.y))
		d.append(Vector3(pd.x, hauteur(pd.x, pd.y) + dessus, pd.y))
		dehors.append(0 if _dans_zone(ligne[k]) else 1)
	for k in ligne.size() - 1:
		# Dans une zone travaillée à la main, le ruban s'efface (un pas de recouvrement au bord).
		if dehors[k] == 0 and dehors[k + 1] == 0:
			continue
		st.add_vertex(g[k])
		st.add_vertex(d[k])
		st.add_vertex(d[k + 1])
		st.add_vertex(g[k])
		st.add_vertex(d[k + 1])
		st.add_vertex(g[k + 1])
	return ligne.size()


func _routes() -> void:
	_sols_materiaux()
	var sts := {}
	for r in data.routes:
		if r.get("pont", false):
			_pont(r)
			continue
		var t: Array = REVETEMENTS.get(r.k, REVETEMENTS.residential)
		if not sts.has(t[0]):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			sts[t[0]] = st
		_ruban(sts[t[0]], r.p, r.l, t[2], Color(t[1], t[1], t[1]))
	for m in sts:
		var st: SurfaceTool = sts[m]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Rues" if m == "bitume" else "Chemins"
		mi.mesh = st.commit()
		mi.material_override = _mats[m]
		add_child(mi)
	_pointilles()


## Le pointillé au milieu des routes qui en ont : un trait clair toutes les deux unités.
func _pointilles() -> void:
	var xfs: Array[Transform3D] = []
	for r in data.routes:
		if r.get("pont", false) or not r.k in AVEC_POINTILLES:
			continue
		var ligne := _densifier(r.p, 0.5)
		var depuis := 1.0
		for k in ligne.size() - 1:
			var a := ligne[k]
			var b := ligne[k + 1]
			var l := a.distance_to(b)
			depuis += l
			if depuis < 2.0 or l < 0.01:
				continue
			depuis = 0.0
			if _dans_zone(a) or _dans_zone(b):
				continue
			var m := (a + b) / 2.0
			var dir := (b - a) / l
			xfs.append(Transform3D(Basis(Vector3.UP, -atan2(dir.y, dir.x)), Vector3(m.x, hauteur(m.x, m.y) + 0.062, m.y)))
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.01, 0.05)
	bm.material = _mats.marque
	mm.mesh = bm
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Pointilles"
	mi.multimesh = mm
	add_child(mi)


# --- Les places et les cours ----------------------------------------------------------------------

## Les sols revêtus de bourg.json (les places et parkings en enrobé, les cours en gravier), drapés
## sur le relief : chaque polygone est découpé en cases d'une unité, posées chacune sur le terrain.
func _sols() -> void:
	_sols_materiaux()
	var sts := {}
	for z in data.get("sols", []):
		var poly := PackedVector2Array()
		for q in z.p:
			poly.append(Vector2(q[0], q[1]))
		if poly.size() < 3 or _dans_zone(poly[0]):
			continue
		var m: String = "gravier" if z.k == "cour" else "bitume"
		var teinte := 1.0 if z.k == "cour" else 1.14
		if not sts.has(m):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			sts[m] = st
		var st: SurfaceTool = sts[m]
		st.set_color(Color(teinte, teinte, teinte))
		_draper(st, poly, 0.042)
	for m in sts:
		var st: SurfaceTool = sts[m]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Places" if m == "bitume" else "Cours"
		mi.mesh = st.commit()
		mi.material_override = _mats[m]
		add_child(mi)


## Un polygone drapé sur le relief, découpé en cases d'une unité clippées, à `dessus` du terrain.
func _draper(st: SurfaceTool, poly: PackedVector2Array, dessus: float) -> void:
	var x0 := INF
	var z0 := INF
	var x1 := -INF
	var z1 := -INF
	for q in poly:
		x0 = minf(x0, q.x)
		z0 = minf(z0, q.y)
		x1 = maxf(x1, q.x)
		z1 = maxf(z1, q.y)
	for i in range(int(floor(x0)), int(ceil(x1))):
		for j in range(int(floor(z0)), int(ceil(z1))):
			var case := PackedVector2Array([Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)])
			for morceau in Geometry2D.intersect_polygons(case, poly):
				var tri := Geometry2D.triangulate_polygon(morceau)
				for t in range(0, tri.size(), 3):
					for c in [tri[t], tri[t + 2], tri[t + 1]]:
						var q: Vector2 = morceau[c]
						st.add_vertex(Vector3(q.x, hauteur(q.x, q.y) + dessus, q.y))


## Une zone travaillée à la main : l'enrobé sur toute l'emprise, puis ses trottoirs, ses arbres,
## ses passages piétons et ses places de stationnement, d'après zones.json.
func _zones_dessin() -> void:
	_sols_materiaux()
	for z in zones:
		var noeud := Node3D.new()
		noeud.name = "Zone_" + str(z.id)
		add_child(noeud)
		var teinte: float = z.get("teinte", 0.96)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_color(Color(teinte, teinte, teinte))
		_draper(st, z.poly, 0.05)
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Enrobe"
		mi.mesh = st.commit()
		mi.material_override = _mats.bitume
		noeud.add_child(mi)
		var sd := SurfaceTool.new()
		sd.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sb := SurfaceTool.new()
		sb.begin(Mesh.PRIMITIVE_TRIANGLES)
		for t in z.get("trottoirs", []):
			_bande(sd, sb, _densifier(t.ligne, 0.5), float(t.l))
		sd.generate_normals()
		var md := MeshInstance3D.new()
		md.name = "Trottoirs"
		md.mesh = sd.commit()
		md.material_override = _mats.dalles
		noeud.add_child(md)
		sb.generate_normals()
		var mb := MeshInstance3D.new()
		mb.name = "Bordures"
		mb.mesh = sb.commit()
		mb.material_override = _mats.bordure
		noeud.add_child(mb)
		for pz in z.get("pietons", []):
			_pieton(noeud, pz)
		for a in z.get("arbres", []):
			_arbre(noeud, Vector2(a[0], a[1]))
		for m in z.get("mobilier", []):
			_mobilier(noeud, m)
		for pp in z.get("passages", []):
			var c := Vector2(pp.c[0], pp.c[1])
			var dir := Vector2(pp.dir[0], pp.dir[1]).normalized()
			var n: int = int(pp.n)
			for k in n:
				var q: Vector2 = c + dir * ((k - (n - 1) / 2.0) * 0.32)
				var bande := _boite(Vector3(float(pp.l), 0.012, 0.16), Color(0.88, 0.88, 0.84), noeud)
				bande.material_override = _mats.marque
				bande.transform = Transform3D(Basis(Vector3.UP, -atan2(dir.y, dir.x) + PI / 2.0), Vector3(q.x, hauteur(q.x, q.y) + 0.062, q.y))
		for sp in z.get("stationnements", []):
			var a := Vector2(sp.a[0], sp.a[1])
			var b := Vector2(sp.b[0], sp.b[1])
			var dir := (b - a).normalized()
			var perp := Vector2(-dir.y, dir.x) * float(sp.cote)
			var n: int = int(sp.n)
			var prof: float = float(sp.prof)
			for k in n + 1:
				var q: Vector2 = a + dir * (a.distance_to(b) * k / n) + perp * prof / 2.0
				var marque := _boite(Vector3(0.06, 0.012, prof), Color(0.88, 0.88, 0.84), noeud)
				marque.material_override = _mats.marque
				marque.transform = Transform3D(Basis(Vector3.UP, -atan2(dir.y, dir.x)), Vector3(q.x, hauteur(q.x, q.y) + 0.062, q.y))


## Une bande de trottoir posée à la main : le dessus en pavés, les deux faces et les bouts en pierre
## claire ; elle compte pour sol() comme les trottoirs des rues.
func _bande(sd: SurfaceTool, sb: SurfaceTool, ligne: PackedVector2Array, l: float) -> void:
	if ligne.size() < 2:
		return
	var g: Array[Vector3] = []
	var d: Array[Vector3] = []
	var gb: Array[Vector3] = []
	var db: Array[Vector3] = []
	for k in ligne.size():
		var avant := ligne[maxi(k - 1, 0)]
		var apres := ligne[mini(k + 1, ligne.size() - 1)]
		var dir := (apres - avant).normalized()
		var perp := Vector2(-dir.y, dir.x) * l / 2.0
		var pg := ligne[k] + perp
		var pd := ligne[k] - perp
		var yg := hauteur(pg.x, pg.y)
		var yd := hauteur(pd.x, pd.y)
		g.append(Vector3(pg.x, yg + TROTTOIR_H, pg.y))
		d.append(Vector3(pd.x, yd + TROTTOIR_H, pd.y))
		gb.append(Vector3(pg.x, yg - 0.06, pg.y))
		db.append(Vector3(pd.x, yd - 0.06, pd.y))
		var cle := Vector2i(int(floor(ligne[k].x)), int(floor(ligne[k].y)))
		if not _bandes.has(cle):
			_bandes[cle] = []
		_bandes[cle].append([ligne[k].x, ligne[k].y, l])
	for k in ligne.size() - 1:
		_quad2(sd, g[k], d[k], d[k + 1], g[k + 1])
		_quad2(sb, gb[k], g[k], g[k + 1], gb[k + 1])
		_quad2(sb, db[k], d[k], d[k + 1], db[k + 1])
	_quad2(sb, g[0], d[0], db[0], gb[0])
	var n := ligne.size() - 1
	_quad2(sb, g[n], d[n], db[n], gb[n])


## Un sol piéton d'une place : un polygone drapé trois centimètres au-dessus de l'enrobé, en béton
## sablé (ou en gravier), cerné d'un petit filet de ciment : pas de vrai trottoir, juste une marche.
const PIETON_H := 0.08


func _pieton(parent: Node3D, pz: Dictionary) -> void:
	var poly := PackedVector2Array()
	for q in pz.p:
		poly.append(Vector2(q[0], q[1]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	_draper(st, poly, PIETON_H)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Pieton"
	mi.mesh = st.commit()
	mi.material_override = _mats.gravier if str(pz.get("sol", "sable")) == "gravier" else _mats.sable
	parent.add_child(mi)
	if not bool(pz.get("bord", true)):
		return
	var sb := SurfaceTool.new()
	sb.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var ya := hauteur(a.x, a.y)
		var yb := hauteur(b.x, b.y)
		_quad2(sb, Vector3(a.x, ya + 0.04, a.y), Vector3(a.x, ya + PIETON_H + 0.005, a.y), Vector3(b.x, yb + PIETON_H + 0.005, b.y), Vector3(b.x, yb + 0.04, b.y))
	sb.generate_normals()
	var mb := MeshInstance3D.new()
	mb.name = "Filet"
	mb.mesh = sb.commit()
	mb.material_override = _mats.bordure
	parent.add_child(mb)


## Le mobilier d'une place, choisi pièce par pièce dans l'atelier (KayKit City) : `m` dit lequel,
## `p` où, `rot` l'orientation en degrés. Les pièces qu'on heurte sont rendues solides.
const KK := "res://assets/kaykit/"
const MOBILIER := {
	"banc": ["city/bench.gltf", 2.6, true],
	"poubelle": ["city/trash_A.gltf", 2.2, true],
	"buisson": ["city/bush.gltf", 2.5, true],
	"borne_incendie": ["city/firehydrant.gltf", 2.2, true],
	"lampadaire": ["city/streetlight.gltf", 2.2, true],
	"tonneau": ["medieval_decoration/props/barrel.gltf", 2.4, true],
	"voiture": ["city/car_sedan.gltf", 1.9, true],
	"voiture_break": ["city/car_stationwagon.gltf", 1.9, true],
	"voiture_citadine": ["city/car_hatchback.gltf", 1.9, true],
}


func _mobilier(parent: Node3D, m: Dictionary) -> void:
	var fiche: Array = MOBILIER.get(str(m.m), [])
	if fiche.is_empty():
		push_warning("Mobilier inconnu : %s" % str(m.m))
		return
	var p := Vector2(m.p[0], m.p[1])
	var n: Node3D = load(KK + str(fiche[0])).instantiate()
	n.position = Vector3(p.x, hauteur(p.x, p.y) + float(m.get("y", PIETON_H)), p.y)
	n.scale = Vector3.ONE * float(fiche[1])
	n.rotation_degrees.y = float(m.get("rot", 0.0))
	parent.add_child(n)
	if bool(fiche[2]):
		_solidifier(n)


## Rend un modèle solide : une boîte à sa mesure, comme à Smarves.
func _solidifier(n: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var t: Transform3D = n.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform
		var b: AABB = t * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	var corps := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var forme := BoxShape3D.new()
	forme.size = box.size
	cs.shape = forme
	cs.position = box.get_center()
	corps.add_child(cs)
	n.add_child(corps)


## Un arbre de l'atelier (le chêne du Nature Kit), posé en `p`.
func _arbre(parent: Node3D, p: Vector2) -> void:
	var scene: Node3D = load(KN + "tree_oak.glb").instantiate()
	var ech := 2.2 + fmod(absf(p.x * 1.7 + p.y * 0.9), 1.0) * 0.6
	scene.transform = Transform3D(Basis(Vector3.UP, p.x * 37.0).scaled(Vector3.ONE * ech), Vector3(p.x, hauteur(p.x, p.y) - 0.05, p.y))
	parent.add_child(scene)


# --- Les trottoirs ---------------------------------------------------------------------------------

## Les trottoirs du bourg : le long des rues bâties, de chaque côté où des maisons bordent la rue,
## une bande de dalles calcaires surélevée avec sa bordure, large comme l'écart entre la chaussée et
## les façades (une unité et demie au plus), interrompue aux carrefours. Les maisons s'y posent (sol()).
func _trottoirs() -> void:
	_sols_materiaux()
	# Les bords des bâtiments, par case de deux unités.
	var bords := {}
	for b in data.batiments:
		var poly: Array = b.p
		for k in poly.size():
			var a := Vector2(poly[k][0], poly[k][1])
			var d := Vector2(poly[(k + 1) % poly.size()][0], poly[(k + 1) % poly.size()][1])
			var n := maxi(1, int(a.distance_to(d) / 0.7))
			for i in n:
				var q := a.lerp(d, float(i) / n)
				var cle := Vector2i(int(floor(q.x / 2.0)), int(floor(q.y / 2.0)))
				if not bords.has(cle):
					bords[cle] = PackedVector2Array()
				bords[cle].append(q)
	# Les axes de toutes les voies, par case de deux unités, pour couper aux carrefours.
	var voies := {}
	var lignes := []
	for r in data.routes:
		var ligne := _densifier(r.p, 0.8)
		lignes.append(ligne)
		if r.get("pont", false):
			continue
		for q in ligne:
			var cle := Vector2i(int(floor(q.x / 2.0)), int(floor(q.y / 2.0)))
			if not voies.has(cle):
				voies[cle] = []
			voies[cle].append([q, r.l, lignes.size() - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sb := SurfaceTool.new()
	sb.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ri in data.routes.size():
		var r: Dictionary = data.routes[ri]
		if r.get("pont", false) or not r.k in AVEC_TROTTOIRS:
			continue
		var ligne: PackedVector2Array = lignes[ri]
		if ligne.size() < 3:
			continue
		var demi: float = r.l / 2.0
		for cote in [1.0, -1.0]:
			# Pour chaque point de l'axe : la largeur du trottoir de ce côté, 0 s'il n'y en a pas.
			var larg := PackedFloat32Array()
			larg.resize(ligne.size())
			var perps: Array[Vector2] = []
			for k in ligne.size():
				var avant := ligne[maxi(k - 1, 0)]
				var apres := ligne[mini(k + 1, ligne.size() - 1)]
				var dir := (apres - avant).normalized()
				var perp: Vector2 = Vector2(-dir.y, dir.x) * cote
				perps.append(perp)
				var p := ligne[k]
				var ecart := INF
				var cx := int(floor(p.x / 2.0))
				var cz := int(floor(p.y / 2.0))
				for i in range(cx - 2, cx + 3):
					for j in range(cz - 2, cz + 3):
						for q in bords.get(Vector2i(i, j), PackedVector2Array()):
							var v: Vector2 = q - p
							var lat := v.dot(perp)
							if absf(v.dot(dir)) <= 1.2 and lat >= demi - 0.3 and lat <= demi + 3.5:
								ecart = minf(ecart, lat - demi)
				if ecart == INF:
					larg[k] = 0.0
					continue
				var w := clampf(ecart, 0.14, 1.4)
				# Pas de trottoir dans l'emprise d'une autre voie (un carrefour, une impasse qui débouche),
				# ni dans une zone travaillée à la main.
				var c: Vector2 = p + perp * (demi + w / 2.0)
				if _dans_zone(c):
					w = 0.0
				for i in range(cx - 2, cx + 3):
					for j in range(cz - 2, cz + 3):
						for v in voies.get(Vector2i(i, j), []):
							if v[2] != ri and c.distance_to(v[0]) < v[1] / 2.0 + w / 2.0 + 0.25:
								w = 0.0
				larg[k] = w
			# On bouche les trous courts, on écarte les bouts trop courts, et la largeur est la plus
			# petite des voisins pour que la bande se rétrécisse avant une maison qui avance.
			var present := PackedByteArray()
			present.resize(ligne.size())
			for k in ligne.size():
				present[k] = 1 if larg[k] > 0.0 else 0
			var k := 0
			while k < ligne.size():
				if present[k] == 0:
					var fin := k
					while fin < ligne.size() and present[fin] == 0:
						fin += 1
					if k > 0 and fin < ligne.size() and fin - k <= 3:
						for i in range(k, fin):
							present[i] = 1
							larg[i] = minf(larg[k - 1], larg[fin])
					k = fin
				else:
					k += 1
			k = 0
			while k < ligne.size():
				if present[k] == 1:
					var fin := k
					while fin < ligne.size() and present[fin] == 1:
						fin += 1
					if fin - k < 4:
						for i in range(k, fin):
							present[i] = 0
					else:
						var lisse := PackedFloat32Array()
						for i in range(k, fin):
							var w := larg[i]
							for j in range(maxi(k, i - 2), mini(fin, i + 3)):
								w = minf(w, larg[j])
							lisse.append(w)
						_trottoir(st, sb, ligne, perps, demi, lisse, k, fin)
					k = fin
				else:
					k += 1
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Trottoirs"
	mi.mesh = st.commit()
	mi.material_override = _mats.dalles
	add_child(mi)
	sb.generate_normals()
	var mb := MeshInstance3D.new()
	mb.name = "Bordures"
	mb.mesh = sb.commit()
	mb.material_override = _mats.bordure
	add_child(mb)


## Une bande de trottoir, des points k0 à k1 (exclu) de l'axe : le dessus en pavés, la bordure
## côté chaussée, la face extérieure et les deux bouts en pierre claire. Les faces sont dessinées
## des deux côtés.
func _trottoir(st: SurfaceTool, sb: SurfaceTool, ligne: PackedVector2Array, perps: Array[Vector2], demi: float, larg: PackedFloat32Array, k0: int, k1: int) -> void:
	var dedans: Array[Vector3] = []
	var dehors: Array[Vector3] = []
	var bas_in: Array[Vector3] = []
	var bas_out: Array[Vector3] = []
	for k in range(k0, k1):
		var w: float = larg[k - k0]
		var pi: Vector2 = ligne[k] + perps[k] * (demi - 0.02)
		var pe: Vector2 = ligne[k] + perps[k] * (demi + w)
		var yi := hauteur(pi.x, pi.y)
		var ye := hauteur(pe.x, pe.y)
		dedans.append(Vector3(pi.x, yi + TROTTOIR_H, pi.y))
		dehors.append(Vector3(pe.x, ye + TROTTOIR_H, pe.y))
		bas_in.append(Vector3(pi.x, yi + 0.03, pi.y))
		bas_out.append(Vector3(pe.x, ye - 0.08, pe.y))
		var c: Vector2 = ligne[k] + perps[k] * (demi + w / 2.0)
		var cle := Vector2i(int(floor(c.x)), int(floor(c.y)))
		if not _bandes.has(cle):
			_bandes[cle] = []
		_bandes[cle].append([c.x, c.y, w])
	for k in dedans.size() - 1:
		_quad2(st, dedans[k], dehors[k], dehors[k + 1], dedans[k + 1])
		_quad2(sb, bas_in[k], dedans[k], dedans[k + 1], bas_in[k + 1])
		_quad2(sb, dehors[k], bas_out[k], bas_out[k + 1], dehors[k + 1])
	_quad2(sb, dedans[0], dehors[0], bas_out[0], bas_in[0])
	var n := dedans.size() - 1
	_quad2(sb, dedans[n], dehors[n], bas_out[n], bas_in[n])


## Un quadrilatère dessiné des deux côtés.
func _quad2(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for tri in [[a, b, c], [a, c, d], [a, c, b], [a, d, c]]:
		for v in tri:
			st.add_vertex(v)


## Un pont : un tablier droit d'une rive à l'autre, ses parapets et ses piles.
func _pont(r: Dictionary) -> void:
	var n := Node3D.new()
	var grand: bool = r.k in ["primary", "secondary", "tertiary", "residential", "unclassified"]
	n.name = "Pont" if grand else "Passerelle"
	add_child(n)
	var y0: float = r.y[0]
	var y1: float = r.y[1]
	var total := 0.0
	for k in r.p.size() - 1:
		total += Vector2(r.p[k][0], r.p[k][1]).distance_to(Vector2(r.p[k + 1][0], r.p[k + 1][1]))
	var fait := 0.0
	var corps := StaticBody3D.new()
	n.add_child(corps)
	var pierre := PIERRE.darkened(0.12) if grand else Color(0.45, 0.36, 0.28)
	var niveau: float = data.niveau_eau if data.niveau_eau != null else 0.0
	for k in r.p.size() - 1:
		var a := Vector2(r.p[k][0], r.p[k][1])
		var b := Vector2(r.p[k + 1][0], r.p[k + 1][1])
		var l := a.distance_to(b)
		var ya := lerpf(y0, y1, fait / total)
		var yb := lerpf(y0, y1, (fait + l) / total)
		fait += l
		var milieu := (a + b) / 2.0
		var tr := Transform3D(Basis(Vector3.UP, -atan2(b.y - a.y, b.x - a.x)), Vector3(milieu.x, (ya + yb) / 2.0, milieu.y))
		tr.basis = tr.basis * Basis(Vector3.BACK, atan2(yb - ya, l))
		var tablier := _boite(Vector3(l + 0.1, 0.25, r.l), pierre, n)
		tablier.transform = tr.translated_local(Vector3(0, -0.05, 0))
		var route := _boite(Vector3(l + 0.1, 0.02, r.l * 0.86), Color(0.38, 0.38, 0.4), n)
		route.transform = tr.translated_local(Vector3(0, 0.08, 0))
		for cote in [-1.0, 1.0]:
			var parapet := _boite(Vector3(l + 0.1, 0.42 if grand else 0.4, 0.14), pierre.lightened(0.05), n)
			parapet.transform = tr.translated_local(Vector3(0, 0.25, cote * (r.l / 2.0 - 0.07)))
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(l + 0.1, 0.25, r.l)
		cs.shape = bx
		cs.transform = tablier.transform
		corps.add_child(cs)
		# Les piles, dans l'eau, toutes les huit unités environ.
		if grand:
			var piles := int(l / 8.0)
			for s in range(1, piles + 1):
				var p := a.lerp(b, float(s) / (piles + 1))
				var yp := lerpf(ya, yb, float(s) / (piles + 1))
				if hauteur(p.x, p.y) > yp - 1.0:
					continue
				var pile := _boite(Vector3(1.0, yp - niveau + 1.5, r.l + 0.3), pierre, n)
				pile.transform = Transform3D(tr.basis.orthonormalized(), Vector3(p.x, (yp + niveau - 1.5) / 2.0 - 0.1, p.y))


func _boite(taille: Vector3, c: Color, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


# --- Les bâtiments ---------------------------------------------------------------------------------

func _batiments() -> void:
	_materiaux()
	# Les maisons du Poitou de Smarves (scripts/village/facades.gd) : calcaire, chaînes d'angle,
	# encadrements, volets, tuiles canal. Une graine fixe : le bourg est le même à chaque visite.
	var f = FACADES.new(self, Polices.texte(), 86015)
	var murs := PackedVector3Array()
	var a_part := {}
	var absorbes := {}
	for r in data.remarquables:
		if r.has("batiment"):
			a_part[int(r.batiment)] = r
		for q in r.get("absorbe", []):
			# Un bâtiment que la silhouette du lieu couvre déjà (une annexe, un pan de mur du cadastre) :
			# le plus proche du point donné, pas dessiné à part.
			var k := _batiment_en(Vector2(q[0], q[1]))
			if k >= 0:
				absorbes[k] = true
	var lot := 0
	for i in data.batiments.size():
		if absorbes.has(i):
			continue
		var b: Dictionary = data.batiments[i]
		var rem: Dictionary = a_part.get(i, {})
		var segments: Array = REMARQUABLES.murs(rem.id, b, sol) if not rem.is_empty() else []
		if segments.is_empty():
			_collision(b, murs)
		else:
			_murs_segments(segments, b, murs)
		if not rem.is_empty():
			# Un lieu remarquable : son propre lot, nommé, prêt à être remplacé par sa vraie silhouette.
			var noeud := Node3D.new()
			noeud.name = "Remarquable_" + str(rem.id)
			noeud.set_meta("remarquable", rem.id)
			noeud.set_meta("nom", rem.nom)
			noeud.set_meta("osm", rem.osm)
			add_child(noeud)
			var fr = FACADES.new(noeud, Polices.texte(), 86015 + i)
			if not REMARQUABLES.construire(rem.id, fr, b, sol):
				_maison(fr, b, rem)
			fr.commit(_mats, _mats.glass, "Remarquable_" + str(rem.id))
			continue
		_maison(f, b, {})
		lot += 1
		if lot % 120 == 0:
			# Un maillage par matériau pour cent vingt maisons : assez gros pour peu d'appels de dessin,
			# assez petit pour que l'élagage par la caméra en écarte une partie.
			f.commit(_mats, _mats.glass, "Maisons%d" % (lot / 120))
	f.commit(_mats, _mats.glass, "Maisons")
	var c := ConcavePolygonShape3D.new()
	c.backface_collision = true
	c.set_faces(murs)
	var corps := StaticBody3D.new()
	corps.name = "Murs"
	var cs := CollisionShape3D.new()
	cs.shape = c
	corps.add_child(cs)
	add_child(corps)


## Les matières des maisons, celles du village de Smarves : la teinte vient du sommet, le grain
## de calcaire et les tuiles canal des nuanceurs du jeu.
func _materiaux() -> void:
	var stone: Shader = load("res://shaders/village_stone.gdshader")
	var wall := ShaderMaterial.new()
	wall.shader = stone
	wall.set_shader_parameter("grain", _grain(0.06, Color(0.8, 0.76, 0.7)))
	wall.set_shader_parameter("grain_scale", 0.8)
	_mats.wall = wall
	var trim := ShaderMaterial.new()
	trim.shader = stone
	trim.set_shader_parameter("grain", _grain(0.2, Color(0.88, 0.86, 0.83)))
	trim.set_shader_parameter("grain_scale", 1.0)
	trim.set_shader_parameter("rough", 0.72)
	_mats.trim = trim
	var roof := ShaderMaterial.new()
	roof.shader = load("res://shaders/roof_tiles.gdshader")
	_mats.roof = roof
	var glass := ShaderMaterial.new()
	glass.shader = load("res://shaders/window_glow.gdshader")
	# En plein jour, les fenêtres allumées restent discrètes.
	glass.set_shader_parameter("energy", 1.6)
	_mats.glass = glass


func _grain(freq: float, sombre: Color) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.set_color(0, sombre)
	g.set_color(1, Color.WHITE)
	t.color_ramp = g
	return t


## Les murs de l'emprise, pour marcher autour : la vraie forme, même quand la maison dessinée
## est son rectangle.
func _collision(b: Dictionary, murs: PackedVector3Array) -> void:
	var bas: float = b.sol
	var haut: float = b.sol + b.h
	for k in b.p.size():
		var a: Array = b.p[k]
		var c: Array = b.p[(k + 1) % b.p.size()]
		var v := [Vector3(a[0], bas, a[1]), Vector3(c[0], bas, c[1]), Vector3(c[0], haut, c[1]), Vector3(a[0], haut, a[1])]
		for s in [0, 1, 2, 0, 2, 3]:
			murs.append(v[s])


## Les murs d'un lieu dessiné d'après photo, donnés par remarquables.gd : des segments au sol, dressés
## de la base de l'emprise au-dessus du toit.
func _murs_segments(segments: Array, b: Dictionary, murs: PackedVector3Array) -> void:
	var bas: float = b.sol
	var haut: float = b.sol + maxf(b.h, 3.0) + 1.5
	for sg in segments:
		var v := [Vector3(sg[0], bas, sg[1]), Vector3(sg[2], bas, sg[3]), Vector3(sg[2], haut, sg[3]), Vector3(sg[0], haut, sg[1])]
		for s in [0, 1, 2, 0, 2, 3]:
			murs.append(v[s])


## Une maison : sur son rectangle quand l'emprise le remplit (une maison du Poitou complète, façade
## sur la rue), sinon ses vrais murs percés de fenêtres, sous un toit à quatre pans ou plat.
func _maison(f, b: Dictionary, rem: Dictionary) -> void:
	var r: Array = b.rect
	var etages := clampi(int(round((b.h - 0.15) / f.FLOOR_H)), 1, 4)
	var annexe: bool = b.get("annexe", false) or (b.h < 1.5 and etages == 1 and r[2] * r[3] < 10.0)
	var teinte: Color = {"pierre": Color(0.9, 0.82, 0.66), "brique": Color(0.86, 0.6, 0.48), "bois": Color(0.7, 0.56, 0.42)}.get(b.mur, f.pick(f.STONES))
	var toit: Color = f.pick(f.ROOFS)
	if b.toit == "ardoise":
		toit = Color(0.36, 0.39, 0.45)
	elif b.toit == "zinc":
		toit = Color(0.6, 0.62, 0.66)
	var nu: bool = rem.get("id", "") in SANS_FENETRES
	if annexe:
		etages = 1
	# Le repère de la maison : l'origine au pied de la façade, au milieu, +Z vers la rue.
	var u := Vector2(cos(r[4]), sin(r[4]))
	var v := Vector2(-u.y, u.x) * float(b.face)
	var c := Vector2(r[0], r[1])
	var avant: Vector2 = c + v * (r[3] / 2.0)
	# La maison se pose au niveau du sol devant sa porte ; en pente, un socle de pierre sombre descend
	# jusqu'au bas de l'emprise, derrière.
	var y_sol: float = maxf(b.sol, sol(avant.x + v.x * 0.6, avant.y + v.y * 0.6) - 0.04)
	var xf := Transform3D(Basis(Vector3.UP, atan2(v.x, v.y)), Vector3(avant.x, y_sol, avant.y))
	if b.rempli >= 0.72 or annexe:
		if y_sol - b.sol > 0.02:
			f.batch.box("trim", xf, Vector3(0, -(y_sol - b.sol) / 2.0, -r[3] / 2.0), Vector3(r[2] + 0.05, y_sol - b.sol, r[3] + 0.05), teinte.darkened(0.3))
		var spec := {
			"w": r[2], "d": r[3], "floors": etages, "wall": teinte, "roof": toit,
			"roof_kind": "hip" if b.pans == 4 else "gable", "lit": 0.0 if annexe else 0.22,
			"chimney": not annexe and f.rng.randf() < 0.6, "door": ["left", "center", "right"][f.rng.randi() % 3],
			"back": b.rue > 2.0 or annexe, "dormer": not annexe and etages >= 2 and f.rng.randf() < 0.3,
			"front": not nu, "closed": nu,
		}
		if nu:
			spec.back = false
		if rem.get("genre", "") == "commerce":
			spec.shop = {"name": _enseigne_de(rem.id), "color": f.pick(f.SHUTTERS).darkened(0.2), "ink": Color(1.0, 0.92, 0.7)}
			spec.floors = maxi(etages, 2)
		f.house(xf, spec)
		return
	# Une emprise en L ou en U : chaque mur à sa place, avec ses travées de fenêtres.
	var lumiere: Color = teinte.lightened(0.12)
	var volets: Color = f.pick(f.SHUTTERS)
	var bas: float = b.sol
	var h: float = etages * f.FLOOR_H + 0.15
	var poly: Array = b.p
	var aire := 0.0
	for k in poly.size():
		aire += poly[k][0] * poly[(k + 1) % poly.size()][1] - poly[(k + 1) % poly.size()][0] * poly[k][1]
	var sens := 1.0 if aire > 0.0 else -1.0
	for k in poly.size():
		var a := Vector2(poly[k][0], poly[k][1])
		var d := Vector2(poly[(k + 1) % poly.size()][0], poly[(k + 1) % poly.size()][1])
		var l := a.distance_to(d)
		var dir := (d - a) / l
		var n := Vector2(dir.y, -dir.x) * sens  # vers l'extérieur, quel que soit le sens du pourtour
		var m := (a + d) / 2.0
		var mxf := Transform3D(Basis(Vector3.UP, atan2(n.x, n.y)), Vector3(m.x, bas, m.y))
		f.batch.box("wall", mxf, Vector3(0, h / 2.0, -0.05), Vector3(l, h, 0.1), teinte)
		f.batch.box("trim", mxf, Vector3(0, f.BASE_H / 2.0, 0.0), Vector3(l, f.BASE_H, 0.14), teinte.darkened(0.25))
		f.batch.box("trim", mxf, Vector3(0, h + 0.05, 0.0), Vector3(l + 0.1, 0.1, 0.16), lumiere)
		if nu or l < 0.9:
			continue
		var travees := maxi(1, int((l - 0.3) / 0.9))
		var pas := (l - 0.2) / travees
		for e in etages:
			for i in travees:
				if f.rng.randf() < 0.3:
					continue
				var x := -l / 2.0 + 0.1 + pas * (i + 0.5)
				f._window(mxf, Vector3(x, 0.42 + e * f.FLOOR_H, 0), Vector2(0.48, 0.7), volets, lumiere, 0.22)
	# Le toit : à quatre pans sur le rectangle quand il couvre à peu près l'emprise, sinon une
	# terrasse de tuiles entre ses murs.
	if b.rempli >= 0.5:
		f._roof(Transform3D(xf.basis, Vector3(avant.x, b.sol, avant.y)), r[2], r[3], h, toit, teinte, "hip")
	else:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(Vector2(q[0], q[1]))
		var tri := Geometry2D.triangulate_polygon(pts)
		var y := bas + h + 0.08
		for t in range(0, tri.size(), 3):
			var q := [pts[tri[t]], pts[tri[t + 1]], pts[tri[t + 2]]]
			f.batch.tri("roof", Transform3D.IDENTITY, Vector3(q[0].x, y, q[0].y), Vector3(q[1].x, y, q[1].y),
				Vector3(q[2].x, y, q[2].y), Vector3.UP, toit, [q[0] - pts[0], q[1] - pts[0], q[2] - pts[0]])


## Le bâtiment dont le centre est le plus proche de `p`, à moins de deux unités ; -1 sinon.
func _batiment_en(p: Vector2) -> int:
	var best := -1
	var dbest := 2.0
	for i in data.batiments.size():
		var r: Array = data.batiments[i].rect
		var dd := p.distance_to(Vector2(r[0], r[1]))
		if dd < dbest:
			dbest = dd
			best = i
	return best


## Le nom peint sur la devanture d'un commerce de la place.
func _enseigne_de(id: String) -> String:
	match id:
		"boulangerie": return "Boulangerie"
		"boucherie": return "Boucherie"
		"pharmacie": return "Pharmacie"
		"poste": return "La Poste"
		"cafe": return "Café"
		"hotel": return "La Châtellenie"
		"restaurant": return "Restaurant"
		"garage": return "Garage"
	return ""


# --- Les arbres ------------------------------------------------------------------------------------

func _arbres() -> void:
	var modeles := ["tree_oak", "tree_default", "tree_fat", "tree_detailed", "tree_cone"]
	var places := []
	for m in modeles:
		places.append([])
	for k in data.arbres.size():
		var a: Array = data.arbres[k]
		places[(k * 7 + int(absf(a[0]) * 3.0)) % modeles.size()].append(a)
	for m in modeles.size():
		if places[m].is_empty():
			continue
		var scene: Node3D = load(KN + modeles[m] + ".glb").instantiate()
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			var base: Transform3D = scene.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform if mi.is_inside_tree() else _relatif(mi, scene)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = (mi as MeshInstance3D).mesh
			mm.instance_count = places[m].size()
			for k in places[m].size():
				var a: Array = places[m][k]
				var ech := 2.0 + fmod(absf(a[0] * 1.7 + a[1] * 0.9), 1.0) * 0.9
				var tr := Transform3D(Basis(Vector3.UP, a[0] * 37.0).scaled(Vector3.ONE * ech), Vector3(a[0], hauteur(a[0], a[1]) - 0.05, a[1]))
				mm.set_instance_transform(k, tr * base)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Arbres_" + modeles[m]
			mmi.multimesh = mm
			add_child(mmi)
		scene.free()


func _relatif(n: Node3D, racine: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var x: Node = n
	while x != null and x != racine:
		if x is Node3D:
			t = (x as Node3D).transform * t
		x = x.get_parent()
	return t


# --- Les noms --------------------------------------------------------------------------------------

func _noms() -> void:
	for r in data.remarquables:
		remarquables.append(r)
		var majeur: bool = r.genre != "commerce"
		var at := Vector3(r.x, r.y, r.z)
		if r.has("batiment"):
			var b: Dictionary = data.batiments[int(r.batiment)]
			at.y = b.sol + b.h + b.pente + 0.9
		else:
			at.y += 2.2
		var l := _enseigne(at, r.nom, OR if majeur else Color(0.92, 0.9, 0.85), 0.011 if majeur else 0.0075)
		# Les commerces se lisent de près ; les monuments jusqu'à la vue de tout le bourg.
		l.visibility_range_end = 260.0 if majeur else 34.0
	# Les noms des rues, couchés sur la chaussée, une fois par rue, sur son plus long tronçon.
	var plus_long := {}
	for r in data.routes:
		if not r.has("nom") or r.get("pont", false):
			continue
		var l := 0.0
		for k in r.p.size() - 1:
			l += Vector2(r.p[k][0], r.p[k][1]).distance_to(Vector2(r.p[k + 1][0], r.p[k + 1][1]))
		if l > 25.0 and (not plus_long.has(r.nom) or l > plus_long[r.nom][0]):
			plus_long[r.nom] = [l, r]
	for nom in plus_long:
		var r: Dictionary = plus_long[nom][1]
		var m: int = r.p.size() / 2
		var a := Vector2(r.p[maxi(m - 1, 0)][0], r.p[maxi(m - 1, 0)][1])
		var b := Vector2(r.p[mini(m + 1, r.p.size() - 1)][0], r.p[mini(m + 1, r.p.size() - 1)][1])
		var p := (a + b) / 2.0
		var ang := atan2(b.y - a.y, b.x - a.x)
		if ang > PI / 2.0 or ang < -PI / 2.0:
			ang += PI
		var l := Label3D.new()
		l.text = nom
		l.font = Polices.texte()
		l.font_size = 48
		l.pixel_size = 0.007
		l.modulate = Color(1, 1, 1, 0.85)
		l.outline_size = 8
		l.outline_modulate = Color(0, 0, 0, 0.5)
		l.position = Vector3(p.x, hauteur(p.x, p.y) + 0.12, p.y)
		l.rotation = Vector3(-PI / 2.0, -ang, 0)
		add_child(l)


func _enseigne(at: Vector3, texte: String, c: Color, px: float) -> Label3D:
	var l := Label3D.new()
	l.text = texte
	l.font = Polices.gras()
	l.font_size = 64
	l.pixel_size = px
	l.modulate = c
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.7)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	add_child(l)
	return l


# --- L'habitant, la caméra, l'interface ------------------------------------------------------------

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
	me.look = Cast.player(Biens.worn)
	me.walk_speed = 1.0
	me.run_speed = 1.9
	me.rotation.y = PI
	player.add_child(me)
	player.avatar = me
	player.global_position = Vector3(_arrivee.x, hauteur(_arrivee.x, _arrivee.y) + 0.05, _arrivee.y)
	player.rotation.y = deg_to_rad(-30.0)
	camera.make_current()
	player.follow_camera = camera
	camera.au_dela.connect(func(): Carte.ouvrir())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _suivre:
		return  # une vue imposée pour une capture (--view=)
	camera.target = player.global_position + Vector3(0, 0.3, 0)
	camera.set("_target_goal", camera.target)
	camera.yaw = deg_to_rad(-20.0)
	camera.set("_yaw_goal", camera.yaw)
	camera.use_notches(CRANS, 1)


func _interface() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var titre := Label.new()
	titre.text = "Availles-Limouzine"
	titre.add_theme_font_override("font", Polices.gras())
	titre.add_theme_font_size_override("font_size", 30)
	titre.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	titre.add_theme_constant_override("outline_size", 6)
	titre.position = Vector2(24, 70)
	ui.add_child(titre)
	_aide = _ligne(AIDE_DESSUS, 16)
	_aide.position = Vector2(24, 112)
	ui.add_child(_aide)
	# Tab (ou le bouton « Vue ») : la bascule est au socle, la ligne d'aide la suit. Par son chemin,
	# pour que le paquet s'ouvre aussi dans un jeu plus ancien, qui n'a pas encore cette bascule.
	var vue := get_node_or_null("/root/Vue")
	if vue:
		vue.basculee.connect(func(dessus: bool): _aide.text = AIDE_DESSUS if dessus else AIDE_A_PIED)
	var sources := _ligne("Plan : © les contributeurs d'OpenStreetMap ; IGN, BD TOPO et RGE ALTI", 13)
	sources.modulate = Color(1, 1, 1, 0.7)
	sources.anchor_top = 1.0
	sources.anchor_bottom = 1.0
	sources.position = Vector2(24, -34)
	ui.add_child(sources)
	_ici = _ligne("", 24)
	_ici.anchor_left = 0.5
	_ici.anchor_right = 0.5
	_ici.anchor_top = 1.0
	_ici.anchor_bottom = 1.0
	_ici.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ici.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ici.position = Vector2(-400, -90)
	_ici.size = Vector2(800, 40)
	_ici.add_theme_color_override("font_color", OR)
	ui.add_child(_ici)


func _ligne(texte: String, taille: int) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_override("font", Polices.texte())
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _process(_delta: float) -> void:
	if _suivre:
		camera.set("_target_goal", player.global_position + Vector3(0, 0.3, 0))
	# Le lieu remarquable le plus proche, nommé en bas de l'écran.
	var p := Vector2(player.global_position.x, player.global_position.z)
	var best := ""
	var d := 5.0
	for r in remarquables:
		var dr := p.distance_to(Vector2(r.x, r.z))
		if dr < d:
			d = dr
			best = r.nom
	_ici.text = best
	# Tombé hors du bourg (au-delà du socle) : on revient sur la place.
	if player.global_position.y < -10.0:
		player.global_position = Vector3(_arrivee.x, hauteur(_arrivee.x, _arrivee.y) + 0.5, _arrivee.y)
		player.velocity = Vector3.ZERO


## Pour les captures de vérification : -- --capture=sortie.png [--a=x,z,cran,lacet] [--oeil=x,y,z,cx,cy,cz]
func _capturer() -> void:
	for k in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_capture)
	get_tree().quit()
