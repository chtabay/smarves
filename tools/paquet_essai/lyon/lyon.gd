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
const TOILES := [["b8322c", "f3ead6"], ["2f5a3a", "f3ead6"], ["c8962e", "f3ead6"], ["2f5a3a", "2f5a3a"], ["8a2a2a", "8a2a2a"], ["2e4a6e", "f3ead6"]]
# les trois palettes des marronniers, du soleil à l'ombre : le jaune-vert de la planche sur le haut des couronnes
const PALETTES_MARRONNIER := [["b9c84a", "8fb048", "7a9c40", "5f7f3e", "4a6634"], ["b9c84a", "86a845", "6e9440", "587a3a", "455f30"],
	["a9bc48", "7a9c40", "6a8a3c", "5f7f3e", "4d6e33"]]
const TUILES := ["8f4a38", "86422f", "965040", "7e3f30", "92503f", "8a4836"]
const PAVE := Color("#a39b93")
## Les voies sans voitures : elles restent pavées.
## La halle de la Martinière : son emprise dans le relevé (le long bâtiment bas de la rue de la Martinière).
const HALLE := 456
const PIETONS := ["footway", "path", "steps", "pedestrian", "living_street", "cycleway"]
const DALLE := Color("#b3a998")
const SABLE := Color("#b48e62")
const VILLEBOIS := Color("#c7c3b6")
const PIERRE_DOREE := Color("#c9a66b")
const BRONZE := Color("#3c3a2e")
const EAU := Color("#3d5b57")

## Les terrains des quartiers de Lyon (quartiers/<nom>/<nom>.gd) : quand un quartier est dans le paquet, la scène n'y bâtit
## plus ses volumes ni ses bois lointains, le quartier livre les siens. En mètres, x vers l'est, z vers le sud.
const RESERVES := {
	# la rue Terme, ses deux rives, et tout ce qui est à l'est, au sud de la rue Sainte-Catherine
	"terreaux": [[Vector2(104, 124), Vector2(480, 124), Vector2(480, 424), Vector2(104, 424)]],
	# la rive droite de la Saône au sud de la rive (le quai Pierre-Scize, à l'est de x = -147, reste à Sathonay),
	# et tout ce qui est au sud de z = 280
	"saint_paul": [[Vector2(-900, 188), Vector2(-432, 188), Vector2(-351, 188), Vector2(-314, 186),
			Vector2(-302, 187), Vector2(-250, 202), Vector2(-200, 227), Vector2(-147, 280),
			Vector2(-900, 280)],
		[Vector2(-2000, 280), Vector2(2000, 280), Vector2(2000, 3000), Vector2(-2000, 3000)]],
}

## Les lieux de la scène, en mètres (x vers l'est, z vers le sud), relevés sur le plan réel.
const CENTRE_PLACE := Vector2(10.0, 18.0)
const BLANDAN := Vector2(10.6, 12.8)
const LIONS := [Vector2(3.6, -15.2), Vector2(17.4, -15.2)]
## La place : le square et la chaussée qui l'entoure, entre les façades.
const PLACE := Rect2(-14.0, -14.0, 47.0, 66.0)
## Le square planté, au milieu de la place, entre ses deux rues pavées.
const SQUARE := Rect2(-2.5, -6.0, 25.5, 51.0)
## Là où le joueur passe (le quai et la rue de la Martinière, la place, les rues Rambaud et Louis-Vitet, la montée) :
## chaque façade tournée vers une rue y est un immeuble du façadier, en relief, jamais un mur peint.
const RELIEF := [Rect2(-180.0, 92.0, 260.0, 45.0), Rect2(-62.0, -100.0, 145.0, 200.0), Rect2(-280.0, 137.0, 230.0, 35.0),
		Rect2(-60.0, 40.0, 170.0, 140.0), Rect2(-62.0, -230.0, 145.0, 130.0)]
## Fourvière, ramenée de 975 m à 730 m dans son vrai relèvement (sud-ouest), et la tour métallique.
const FOURVIERE := Vector3(-560.0, 0.0, 470.0)
const TOUR := Vector3(-545.0, 0.0, 330.0)

var player: CharacterBody3D
var camera: Camera3D
var ville: Node3D

var data: Dictionary
var _cafe_pose := false
var _h := PackedFloat32Array()
var _nx := 0
var _nz := 0
var _x0 := 0.0
var _z0 := 0.0
var _pas := 1.0
var _niveau_place := 12.4
var _niveau_eau := 0.0
## Les tronçons de chaussée en enrobé près de la place : [a, b, demi-largeur].
var _chaussees: Array = []
## Le niveau du trottoir de quai au point de vue du quai : le piéton y a les yeux au-dessus du parapet.
var _niveau_quai_vue := -100.0
var _ecart_quai_vue := 1e9
## Les modules du quai, près du point de vue : [centre, normale vers l'eau, niveau du trottoir].
var _quai_modules: Array = []
var _heros := {}
var _segments: Array = []
var _cases_rues := {}
## Les terrains réservés aux quartiers présents dans le paquet (voir RESERVES).
var _reserves: Array = []
## Le relief de toute la ville, tenu par la maquette des quartiers : hauteur() lui passe la main hors du relevé.
var _relief_ville: Script
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
	for nom in RESERVES:
		if ResourceLoader.exists(DOSSIER + "quartiers/%s/%s.gd" % [nom, nom]):
			for poly in RESERVES[nom]:
				_reserves.append(PackedVector2Array(poly))
	if ResourceLoader.exists(DOSSIER + "quartiers/_ville/relief.gd"):
		_relief_ville = load(DOSSIER + "quartiers/_ville/relief.gd")
	ville = Node3D.new()
	ville.name = "Ville"
	ville.scale = Vector3.ONE / U
	add_child(ville)
	_niveler()
	_creuser_lit()
	_ciel()
	_terrain()
	_eau()
	_quais()
	_passerelle()
	_rues()
	_choisir_heros()
	_batiments()
	_place()
	_escalier()
	_arbres()
	_parcours()
	_quai_habite()
	_fourviere()
	_relief_de_pres()
	_reperes()
	_joueur()


# --- Le relief ------------------------------------------------------------------------------------

## L'altitude du sol en (x, z), en mètres, sur les mêmes triangles que le terrain dessiné.
## Hors du relevé, le relief de la ville s'il est là, sinon l'altitude du bord.
func hauteur(x: float, z: float) -> float:
	if _relief_ville != null and (x < _x0 or z < _z0 or x > _x0 + (_nx - 1) * _pas or z > _z0 + (_nz - 1) * _pas):
		return _relief_ville.call("hauteur", x, z)
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



## Vrai si (x, z) est sur le terrain d'un quartier présent dans le paquet.
func _reserve(p: Vector2) -> bool:
	for poly in _reserves:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


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


## La Saône : un vert profond et sourd sous le quai, qui s'éclaircit en reflet du ciel vers le loin, des rides
## croisées qui cassent le miroir et accrochent l'or du soleil.
func _materiau_eau() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 monde;
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = monde.xz;
	float r1 = sin(p.x * 0.9 + p.y * 0.35 + TIME * 0.6) + sin(p.x * 0.31 - p.y * 1.3 - TIME * 0.4);
	float r2 = sin(p.x * 2.7 - p.y * 1.9 + TIME * 1.1) * 0.5 + sin(p.x * 1.7 + p.y * 3.1) * 0.35;
	vec3 n = normalize(vec3(r1 * 0.025 + r2 * 0.018, 1.0, (r2 - r1) * 0.022));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 profond = pow(vec3(0.17, 0.30, 0.27), vec3(2.2));
	vec3 ciel = pow(vec3(0.62, 0.70, 0.72), vec3(2.2));
	ALBEDO = mix(profond, ciel, fres * 0.55);
	ROUGHNESS = 0.12;
	SPECULAR = 0.45;
	METALLIC = 0.0;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Le relevé met la Saône presque au ras des quais, et sa grille de cinq mètres fait glisser les quais en pente
## douce vers l'eau ; en vrai, le quai est de niveau jusqu'au parapet, et le mur tombe de cinq mètres. L'eau
## descend, le lit se creuse à pic sous elle, et le sol des quais garde le niveau de la rue jusqu'au bord.
func _creuser_lit() -> void:
	_niveau_eau = data.niveau_eau * U - 2.2
	var polys: Array = []
	for e in data.eau:
		var poly := PackedVector2Array()
		for q in e.p:
			poly.append(Vector2(q[0], q[1]) * U)
		polys.append(poly)
	var nouveaux := {}
	for iz in _nz:
		for ix in _nx:
			var p := Vector2(_x0 + ix * _pas, _z0 + iz * _pas)
			var dedans := false
			var bord := Vector2.INF
			for poly in polys:
				if Geometry2D.is_point_in_polygon(p, poly):
					dedans = true
				for k in poly.size():
					var q := Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()])
					if q.distance_to(p) < bord.distance_to(p):
						bord = q
			if dedans:
				nouveaux[iz * _nx + ix] = -60.0
			elif p.distance_to(bord) < 14.0 and p.distance_to(bord) > 0.01:
				var loin: Vector2 = bord + (p - bord).normalized() * 16.0
				nouveaux[iz * _nx + ix] = maxf(_h[iz * _nx + ix], hauteur(loin.x, loin.y))
	for k in nouveaux:
		_h[k] = nouveaux[k]


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
	ciel.sky_top_color = Color("#5f94d0")
	ciel.sky_horizon_color = Color("#f4d6a6")
	# le bleu commence bas sur l'horizon : la caméra à pied ne regarde pas dans une bande de brume grise
	ciel.sky_curve = 0.05
	ciel.ground_horizon_color = Color("#e6cfa6")
	ciel.ground_bottom_color = Color("#4a4a52")
	# le soleil, bas et doré : un halo large plutôt qu'un disque
	ciel.sun_angle_max = 38.0
	ciel.sun_curve = 0.06
	e.sky = Sky.new()
	e.sky.sky_material = ciel
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#c8bda6")
	e.ambient_light_energy = 0.55
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.74
	e.tonemap_white = 1.6
	# la planche : des couleurs franches, la terre cuite qui chauffe, le vert cru des marronniers
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.05
	e.adjustment_contrast = 1.06
	# une courbe de tons à gamma 0,9 : les ombres se relèvent sans que les lumières ne brûlent
	var courbe := Gradient.new()
	courbe.offsets = PackedFloat32Array()
	courbe.colors = PackedColorArray()
	for k in 17:
		var x := k / 16.0
		var v := pow(x, 0.9)
		courbe.add_point(x, Color(v, v, v))
	var lut := GradientTexture1D.new()
	lut.gradient = courbe
	lut.width = 256
	e.adjustment_color_correction = lut
	e.ssao_enabled = true
	e.ssao_intensity = 0.6
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_hdr_threshold = 1.2
	e.fog_enabled = true
	e.fog_light_color = Color("#d9cbb2")
	e.fog_density = 0.00035
	e.fog_aerial_perspective = 0.4
	e.fog_sky_affect = 0.15
	env.environment = e
	add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.name = "Soleil"
	var h := deg_to_rad(SOLEIL.hauteur)
	var a := deg_to_rad(SOLEIL.vient_de)
	add_child(soleil)
	soleil.look_at_from_position(Vector3.ZERO, Vector3(-sin(a) * cos(h), -sin(h), cos(a) * cos(h)))
	soleil.light_color = SOLEIL.couleur
	# le ciel garde le halo doré du couchant mais pas le disque, un rond pâle et net qui détonnait au-dessus du quai
	soleil.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	soleil.light_energy = 1.05
	soleil.shadow_enabled = true
	soleil.shadow_opacity = 0.78
	soleil.directional_shadow_max_distance = 140.0
	soleil.shadow_blur = 0.8
	soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


## Les fabriques de matières (materiau, materiau_paves, materiau_sable, materiau_enrobe) et les constantes de
## palette sont publiques : les quartiers de Lyon les reprennent, pour que leurs pavés et leurs enduits soient ceux-ci.
func materiau(c: Color, rugueux := 0.9, couleurs_sommets := false) -> StandardMaterial3D:
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
	mi.material_override = materiau_paves()
	ville.add_child(mi)
	# le square de sable stabilisé et sa bordure de pierre, les trottoirs dallés au pied des façades
	var sable := _boite(ville, Vector3(SQUARE.size.x, 0.1, SQUARE.size.y), Vector3(SQUARE.get_center().x, _niveau_place + 0.05, SQUARE.get_center().y), SABLE)
	sable.material_override = materiau_sable()
	_boite(ville, Vector3(SQUARE.size.x + 0.5, 0.16, SQUARE.size.y + 0.5), Vector3(SQUARE.get_center().x, _niveau_place + 0.0, SQUARE.get_center().y), VILLEBOIS)
	for x in [PLACE.position.x + 1.4, PLACE.end.x - 1.4]:
		_boite(ville, Vector3(2.8, 0.14, PLACE.size.y), Vector3(x, _niveau_place + 0.05, PLACE.get_center().y), DALLE)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	forme.shape = mi.mesh.create_trimesh_shape()
	corps.add_child(forme)
	mi.add_child(corps)


func _eau() -> void:
	var niveau := _niveau_eau
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
		mi.material_override = _materiau_eau()
		ville.add_child(mi)


## Les quais de la Saône devant la passerelle : le mur de quai qui tombe dans la rivière, son parapet de pierre
## dorée et la rangée de platanes du quai Saint-Vincent ; en face, le quai Pierre-Scize, tenu de la même façon.
## Les rives sont celles du plan réel ; on ne tient que le tronçon que l'on voit depuis le quai.
const RIVE_NORD := [Vector2(-388, 104), Vector2(-344, 103), Vector2(-333, 104), Vector2(-284, 114), Vector2(-238, 129), Vector2(-188, 150),
	Vector2(-147, 174), Vector2(-68, 238), Vector2(-45, 266)]
const RIVE_SUD := [Vector2(-432, 188), Vector2(-351, 188), Vector2(-314, 186), Vector2(-302, 187), Vector2(-250, 202), Vector2(-200, 227),
	Vector2(-147, 280)]
## La passerelle Saint-Vincent : ses deux culées, au nord sur le quai Saint-Vincent, au sud sur le quai Pierre-Scize.
const PASSERELLE := [Vector2(-166.0, 163.0), Vector2(-202.0, 226.5)]
## Le point de vue du quai, à trois mètres du parapet : la passerelle de trois quarts, la Saône et Fourvière.
const QUAI_VUE := Vector2(-138.0, 177.0)
## Le regard de la Vue1a : tourné de 15° vers le quai pour le prendre en enfilade, et l'œil reculé d'un pas
## (1,5 m), pour que le parapet passe sous le quart bas du cadre.
## au-delà, en mètres (la scène est en unités du jeu, d'où le / U), le relief des façades de la ville s'efface devant leur volume peint
const RELIEF_PORTEE := 70.0
var _modules_ville: Array[Node3D] = []
const VUE1A_REGARD := Vector2(-0.989, 0.146)
const VUE1A_OEIL := Vector2(-136.5, 175.3)

func _quais() -> void:
	var niveau := _niveau_eau
	var arbres_reels: Array = []
	for a in data.arbres:
		arbres_reels.append(Vector2(a[0], a[1]) * U)
	var k := 0
	# un tirage à part, pour ne pas déranger celui du reste de la ville
	var alea := RandomNumberGenerator.new()
	alea.seed = 4691
	var trottoir := SurfaceTool.new()
	trottoir.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rive in [[RIVE_NORD, 1.0], [RIVE_SUD, -1.0]]:
		var pts: Array = rive[0]
		var prochain_arbre := 4.0
		var prochain_banc := 9.0
		var prochain_lampe := 2.0
		var parcouru := 0.0
		# les modules de 4 m le long de la rive, et le niveau du quai : le plus haut du sol relevé entre le parapet
		# et la rue, lissé sur cinq modules pour que le trottoir ne fasse pas de marches
		var modules: Array = []
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var l := a.distance_to(b)
			var n_mod := maxi(1, int(ceil(l / 4.0)))
			var w := l / n_mod
			var t := (b - a).normalized()
			# la normale qui regarde l'eau : la rivière est au sud de la rive nord, au nord de la rive sud
			var n: Vector2 = Vector2(-t.y, t.x) * float(rive[1])
			if n.y * rive[1] < 0.0:
				n = -n
			for j in n_mod:
				var c := a + t * w * (j + 0.5)
				var y := -100.0
				for dd in [2.0, 4.0, 7.5, 12.0]:
					var dedans: Vector2 = c - n * dd
					y = maxf(y, hauteur(dedans.x, dedans.y))
				modules.append([c, n, w, y])
		for m in modules.size():
			var somme := 0.0
			var nb := 0
			for d in range(-2, 3):
				if m + d >= 0 and m + d < modules.size():
					somme += modules[m + d][3]
					nb += 1
			modules[m].append(somme / nb)
		for m in modules.size():
			var c: Vector2 = modules[m][0]
			var n: Vector2 = modules[m][1]
			var w: float = modules[m][2]
			var y: float = modules[m][4]
			if c.distance_to(QUAI_VUE) < _ecart_quai_vue:
				_ecart_quai_vue = c.distance_to(QUAI_VUE)
				_niveau_quai_vue = y + 0.03
			var lacet := atan2(n.x, n.y)
			k += 1
			if c.distance_to(QUAI_VUE) < 140.0:
				_quai_modules.append([c, n, y + 0.03])
			# le trottoir dallé du quai, du parapet jusqu'aux platanes, d'un seul tenant : il recouvre la marche que
			# le lit creusé laisse dans la grille du relevé, et ses bouts suivent le niveau des modules voisins
			var t := Vector2(n.y, -n.x)
			var y0: float = (y + (modules[m - 1][4] if m > 0 else y)) * 0.5
			var y1: float = (y + (modules[m + 1][4] if m < modules.size() - 1 else y)) * 0.5
			# un peu plus long que le module : aux coudes de la rive, les modules voisins tournent et laissaient un coin vide
			var demi := w * 0.5 + 0.9
			var coins := [[c - t * demi - n * 0.5, y0], [c + t * demi - n * 0.5, y1], [c + t * demi - n * 6.5, y1], [c - t * demi - n * 6.5, y0]]
			# dans ce sens-là, la face regarde le ciel : à l'envers, le moteur ne dessinait que des morceaux du dallage
			for idx in [0, 2, 1, 0, 3, 2]:
				trottoir.set_normal(Vector3.UP)
				trottoir.add_vertex(Vector3(coins[idx][0].x, coins[idx][1] + 0.03, coins[idx][0].y))
			for paire in [[2, 3], [0, 1]]:
				var pa: Array = coins[paire[0]]
				var pb: Array = coins[paire[1]]
				for q in [[pa, 0.0], [pb, 0.0], [pb, -3.0], [pa, 0.0], [pb, -3.0], [pa, -3.0]]:
					trottoir.set_normal(Vector3(n.x, 0, n.y) * (1.0 if paire[0] == 0 else -1.0))
					trottoir.add_vertex(Vector3(q[0][0].x, q[0][1] + 0.03 + q[1], q[0][0].y))
			_pose(QUAIS, "module", "mur_quai_haut", Vector3(c.x, y, c.y), 800 + k, {"largeur": w + 0.04}, lacet)
			if y - 3.8 > niveau:
				# le pied du mur, plus haut que la brique : les mêmes assises, dans l'ombre de l'eau
				var pied := y - 3.8 - niveau + 0.4
				var mi := _boite(ville, Vector3(w + 0.04, pied, 1.2), Vector3(c.x, niveau - 0.4 + pied * 0.5, c.y) + Vector3(n.x, 0, n.y) * -0.35, Color("#a8936a"))
				mi.rotation.y = lacet
				mi.material_override = _materiau_appareil(Color("#b39c6e"))
			# le parapet, sauf devant les culées de la passerelle
			var libre := true
			for q in PASSERELLE:
				if c.distance_to(q) < 3.2:
					libre = false
			if libre:
				var pp := c - n * 0.45
				# le parapet du quai Saint-Vincent est plus mince et un peu plus bas que celui de la brique : 0,9 m
				# sous la tablette, 40 cm d'épaisseur ; le piéton voit l'eau par-dessus
				var parapet := _pose(QUAIS, "module", "mur_quai_bas", Vector3(pp.x, y, pp.y), 900 + k, {"largeur": w + 0.02}, lacet)
				parapet.scale = Vector3(1.0, 0.86, 0.68)
			# les bancs tournés vers l'eau, à 1,7 m du parapet, et les lampadaires contre lui, en quinconce
			if libre and c.distance_to(QUAI_VUE) > 5.0:
				if parcouru + w >= prochain_banc:
					prochain_banc += alea.randf_range(19.0, 24.0)
					var pb := c - n * 1.7
					_pose(MOBILIER, "objet", "banc", Vector3(pb.x, y + 0.03, pb.y), 1200 + k, {}, lacet)
				if parcouru + w >= prochain_lampe:
					prochain_lampe += alea.randf_range(24.0, 28.0)
					var pl := c - n * 0.95
					_pose(MOBILIER, "objet", "lampadaire", Vector3(pl.x, y + 0.03, pl.y), 1300 + k, {})
			# les platanes du quai, à cinq mètres du parapet, tous les dix mètres environ
			parcouru += w
			if parcouru >= prochain_arbre:
				prochain_arbre += alea.randf_range(9.0, 11.0)
				var pa := c - n * 5.0
				var loin := true
				for q in PASSERELLE:
					if pa.distance_to(q) < 7.0:
						loin = false
				for q in arbres_reels:
					if pa.distance_to(q) < 5.0 and q.distance_to(CENTRE_PLACE) <= 220.0:
						loin = false
				if pa.distance_to(QUAI_VUE) < 9.0:
					loin = false
				if loin:
					_pose(OMBRIERE, "arbre", "platane", Vector3(pa.x, y, pa.y), 700 + k, {"hauteur": alea.randf_range(12.5, 14.5), "vent": 0.3, "densite": 0.85})
	var mt := MeshInstance3D.new()
	mt.name = "TrottoirsDesQuais"
	mt.mesh = trottoir.commit()
	mt.material_override = _materiau_dalles_quai()
	ville.add_child(mt)
	# on marche dessus
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	forme.shape = mt.mesh.create_trimesh_shape()
	corps.add_child(forme)
	mt.add_child(corps)


## Une poutre dans un SurfaceTool : de a à b, de section l × h (h dans le plan vertical qui la contient).
func _poutre_st(st: SurfaceTool, a: Vector3, b: Vector3, l: float, h: float, col: Color) -> void:
	var d := (b - a).normalized()
	var cote := d.cross(Vector3.UP)
	if cote.length() < 0.01:
		cote = Vector3.RIGHT
	cote = cote.normalized() * l * 0.5
	var haut := cote.cross(d).normalized() * h * 0.5
	if haut.y < 0.0:
		haut = -haut
	var c := [-cote - haut, cote - haut, cote + haut, -cote + haut]
	for f in 4:
		var u: Vector3 = c[f]
		var v: Vector3 = c[(f + 1) % 4]
		var nrm := (u + v).normalized()
		for q in [a + u, b + u, b + v, a + u, b + v, a + v]:
			st.set_color(col)
			st.set_normal(nrm)
			st.add_vertex(q)
	for bout in [[a, -d], [b, d]]:
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_normal(bout[1])
			st.add_vertex(bout[0] + c[idx])


## La passerelle Saint-Vincent, pièce unique : une passerelle suspendue pour les piétons, son tablier de fer
## vert-de-gris tendu d'une rive à l'autre, ses deux portiques de pierre dorée sur les culées, les câbles en
## chaînette et leurs suspentes, le garde-corps à barreaux fins.
func _passerelle() -> void:
	var a2: Vector2 = PASSERELLE[0]
	var b2: Vector2 = PASSERELLE[1]
	var dir := (b2 - a2).normalized()
	# les culées sont au ras du mur ; le tablier part du niveau du trottoir de quai
	var ya := hauteur(a2.x - dir.x * 7.5, a2.y - dir.y * 7.5) + 0.15
	var yb := hauteur(b2.x + dir.x * 7.5, b2.y + dir.y * 7.5) + 0.15
	var cote := Vector2(-dir.y, dir.x)
	var long := a2.distance_to(b2)
	var lacet := atan2(dir.x, dir.y)
	var fer := Color("#465a52")
	var fer_sombre := Color("#2c3833")
	var planches := Color("#8a7a62")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 48
	var largeur := 2.8
	var tablier := func(s: float) -> Vector3:
		var p := a2 + dir * long * s
		# une légère contre-flèche : le tablier se bombe de 60 cm au milieu
		return Vector3(p.x, lerpf(ya, yb, s) + 0.6 * sin(PI * s), p.y)
	for i in n:
		var p0: Vector3 = tablier.call(float(i) / n)
		var p1: Vector3 = tablier.call(float(i + 1) / n)
		# le platelage, les deux poutres de rive et les entretoises
		_poutre_st(st, p0, p1, largeur, 0.08, planches)
		for s in [-1.0, 1.0]:
			var o: Vector3 = Vector3(cote.x, 0, cote.y) * s * (largeur * 0.5 + 0.06)
			_poutre_st(st, p0 + o + Vector3(0, -0.12, 0), p1 + o + Vector3(0, -0.12, 0), 0.14, 0.42, fer)
			# la main courante et la lisse basse
			_poutre_st(st, p0 + o + Vector3(0, 1.1, 0), p1 + o + Vector3(0, 1.1, 0), 0.08, 0.06, fer_sombre)
			_poutre_st(st, p0 + o + Vector3(0, 0.15, 0), p1 + o + Vector3(0, 0.15, 0), 0.04, 0.04, fer_sombre)
			# les barreaux, tous les 25 cm
			var nb := int(p0.distance_to(p1) / 0.25)
			for j in nb:
				var q: Vector3 = p0.lerp(p1, (j + 0.5) / nb) + o
				_poutre_st(st, q + Vector3(0, 0.15, 0), q + Vector3(0, 1.08, 0), 0.025, 0.025, fer_sombre)
		var milieu := (p0 + p1) * 0.5
		_poutre_st(st, milieu - Vector3(cote.x, 0, cote.y) * (largeur * 0.5 + 0.1) + Vector3(0, -0.3, 0),
			milieu + Vector3(cote.x, 0, cote.y) * (largeur * 0.5 + 0.1) + Vector3(0, -0.3, 0), 0.12, 0.22, fer)
	# les portiques : deux piles de pierre à refends, leur entablement et un linteau de fer, sur chaque culée
	var pierre := Color("#d8bf8c")
	var haut_pile := 9.5
	var sommets := []
	for bout in [[0.0, ya], [1.0, yb]]:
		var p: Vector3 = tablier.call(bout[0])
		var pierres := []
		for s in [-1.0, 1.0]:
			var c: Vector3 = p + Vector3(cote.x, 0, cote.y) * s * (largeur * 0.5 + 0.75)
			for e in 8:
				var h := haut_pile / 8.0
				var retrait := 0.0 if e % 2 == 0 else 0.04
				_boite_st(st, c + Vector3(0, h * (e + 0.5) - 0.5, 0), Vector3(1.1 - retrait, h - 0.05, 1.1 - retrait), -lacet, pierre.darkened(0.02 * (e % 3)))
			_boite_st(st, c + Vector3(0, haut_pile - 0.3, 0), Vector3(1.4, 0.35, 1.4), -lacet, pierre.lightened(0.08))
			_boite_st(st, c + Vector3(0, haut_pile + 0.1, 0), Vector3(1.0, 0.5, 1.0), -lacet, pierre)
			_boite_st(st, c + Vector3(0, -0.2, 0), Vector3(1.5, 0.6, 1.5), -lacet, pierre.darkened(0.1))
			pierres.append(c)
			sommets.append(c + Vector3(0, haut_pile + 0.3, 0))
		_poutre_st(st, pierres[0] + Vector3(0, haut_pile - 1.4, 0), pierres[1] + Vector3(0, haut_pile - 1.4, 0), 0.3, 0.5, fer)
		_poutre_st(st, pierres[0] + Vector3(0, haut_pile - 2.2, 0), pierres[1] + Vector3(0, haut_pile - 2.2, 0), 0.12, 0.12, fer)
	# les câbles porteurs en chaînette, d'un portique à l'autre, et les suspentes tous les deux mètres
	for s in 2:
		var c0: Vector3 = sommets[s]
		var c1: Vector3 = sommets[2 + s]
		var m := 40
		var prec := c0
		for i in range(1, m + 1):
			var u := float(i) / m
			var q := c0.lerp(c1, u)
			var tab: Vector3 = tablier.call(u)
			q.y = lerpf(c0.y, c1.y, u) - (lerpf(c0.y, c1.y, u) - tab.y - 1.4) * (1.0 - pow(2.0 * u - 1.0, 2.0))
			_poutre_st(st, prec, q, 0.09, 0.09, fer_sombre)
			prec = q
		var nb := int(long / 2.0)
		for j in range(1, nb):
			var u := float(j) / nb
			var tab: Vector3 = tablier.call(u)
			var q := c0.lerp(c1, u)
			q.y = lerpf(c0.y, c1.y, u) - (lerpf(c0.y, c1.y, u) - tab.y - 1.4) * (1.0 - pow(2.0 * u - 1.0, 2.0))
			var o := Vector3(cote.x, 0, cote.y) * (-1.0 if s == 0 else 1.0) * (largeur * 0.5 + 0.06)
			_poutre_st(st, Vector3(q.x, q.y, q.z), tab + o + Vector3(0, 1.1, 0), 0.03, 0.03, fer_sombre)
	var mi := MeshInstance3D.new()
	mi.name = "Passerelle"
	mi.mesh = st.commit()
	var mat := materiau(Color.WHITE, 0.7, true)
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	ville.add_child(mi)


## Les rues en rubans posés sur le relief : la chaussée d'enrobé, les rues piétonnes et les montées pavées.
## Les pavés lyonnais en rangs, joints sombres, sur les chaussées et la place ; le reste reste lisse.
## Le sable stabilisé du square : des nappes plus claires et plus foncées de 2 à 4 m, un grain de gravillons,
## l'usure plus claire au milieu des allées.
func materiau_sable() -> ShaderMaterial:
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
	// des plaques plus claires, damées par les pas, et plus sombres, que l'on voit encore de haut
	// les plaques à bords nets : mates là où l'on passe, plus claires ailleurs
	float pas = step(0.5, bruit(p * 0.45 + 3.7)) - step(0.62, bruit(p * 0.7 + 9.1));
	vec3 c = teinte * (0.88 + 0.22 * nappe) * (1.0 + 0.1 * pas);
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


func materiau_paves() -> ShaderMaterial:
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
	// les teintes des sommets sont en sRGB ; les joints, plus sombres que la pierre, la découpent
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * mix(0.5, v, joint);
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Les dalles de pierre du trottoir de quai, en rangs décalés, de la teinte de celles de la brique des quais.
var _dalles_quai: ShaderMaterial
func _materiau_dalles_quai() -> ShaderMaterial:
	if _dalles_quai:
		return _dalles_quai
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 monde;
// le pas des dalles : celui du quai, en grandes dalles ; les trottoirs des rues le resserrent
uniform float echelle = 2.4;
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	// le monde est en unités du jeu : les dalles se comptent en mètres
	vec2 q = monde.xz * echelle / vec2(0.6, 0.4);
	q.x += floor(q.y) * 0.5;
	vec2 f = fract(q);
	float joint = smoothstep(0.0, 0.03, f.x) * smoothstep(1.0, 0.97, f.x) * smoothstep(0.0, 0.045, f.y) * smoothstep(1.0, 0.955, f.y);
	float v = 0.9 + 0.12 * hash(floor(q));
	// le granit gris du quai Saint-Vincent, pris un peu bleuté : la lumière dorée le ramène au gris à l'écran
	ALBEDO = pow(vec3(0.68, 0.69, 0.74), vec3(2.2)) * mix(0.62, v, joint);
	ROUGHNESS = 0.92;
}
"""
	_dalles_quai = ShaderMaterial.new()
	_dalles_quai.shader = sh
	return _dalles_quai


## Vrai si p est à moins de d mètres de la ligne d'une des deux rives.
func _pres_rive(p: Vector2, d: float) -> bool:
	for rive in [RIVE_NORD, RIVE_SUD]:
		for i in rive.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, rive[i], rive[i + 1]).distance_to(p) < d:
				return true
	return false


func _rues() -> void:
	var enrobe := SurfaceTool.new()
	enrobe.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pietons := SurfaceTool.new()
	pietons.begin(Mesh.PRIMITIVE_TRIANGLES)
	# les chaussées, pour poser les bordures de trottoir là où aucune autre chaussée ne passe
	var chaussees: Array = []
	var cases := {}
	for r in data.routes:
		if r.get("pont", false):
			continue
		var k: String = r.k
		var st := pietons if k in PIETONS else enrobe
		var l: float = r.l * U * 0.5
		var pts: Array = []
		for q in r.p:
			pts.append(Vector2(q[0], q[1]) * U)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if PLACE.has_point(a) and PLACE.has_point(b):
				continue
			# le trottoir du quai a son dallage : les chemins du relevé qui le longent ou y aboutissent s'y posaient
			# par-dessus, en dalles de pavés surélevées
			if st == pietons and (_pres_rive(a, 8.0) or _pres_rive(b, 8.0) or _pres_rive((a + b) * 0.5, 8.0)):
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
			if st == enrobe and a.distance_to(CENTRE_PLACE) < 320.0:
				chaussees.append([a, b, l])
				var bo := Rect2(a, Vector2.ZERO).expand(b).grow(l + 1.0)
				for gx in range(floori(bo.position.x / 20.0), floori(bo.end.x / 20.0) + 1):
					for gz in range(floori(bo.position.y / 20.0), floori(bo.end.y / 20.0) + 1):
						var cle := Vector2i(gx, gz)
						if not cases.has(cle):
							cases[cle] = []
						cases[cle].append(chaussees.size() - 1)
	_chaussees = chaussees
	var mi := MeshInstance3D.new()
	mi.name = "Chaussees"
	mi.mesh = enrobe.commit()
	mi.material_override = materiau_enrobe()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ville.add_child(mi)
	var mp := MeshInstance3D.new()
	mp.name = "Pietons"
	mp.mesh = pietons.commit()
	mp.material_override = materiau_paves()
	mp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ville.add_child(mp)
	# les bordures de granit gris clair, de part et d'autre de chaque chaussée, coupées aux carrefours
	var bordures := SurfaceTool.new()
	bordures.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dalles := SurfaceTool.new()
	dalles.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in chaussees.size():
		var a: Vector2 = chaussees[c][0]
		var b: Vector2 = chaussees[c][1]
		var l: float = chaussees[c][2]
		var t := (b - a).normalized()
		var n := t.orthogonal()
		var long := a.distance_to(b)
		var nb := maxi(1, int(long / 1.2))
		var ang := atan2(t.y, t.x)
		for s in [-1.0, 1.0]:
			for j in nb:
				var q: Vector2 = a + t * long * (j + 0.5) / nb + n * s * (l + 0.12)
				if PLACE.has_point(q):
					continue
				var dans := false
				for o in cases.get(Vector2i(floori(q.x / 20.0), floori(q.y / 20.0)), []):
					if o == c:
						continue
					var sg: Array = chaussees[o]
					if Geometry2D.get_closest_point_to_segment(q, sg[0], sg[1]).distance_to(q) < sg[2] + 0.1:
						dans = true
						break
				if not dans:
					# granit gris comme le parapet du quai, 13 cm de vue au-dessus de la chaussée
					_boite_st(bordures, Vector3(q.x, hauteur(q.x, q.y) + 0.09, q.y), Vector3(long / nb + 0.02, 0.2, 0.2), ang, Color("#8e8f94"))
					# le trottoir en dalles de granit, derrière la bordure, jusqu'aux façades
					var tq: Vector2 = q + n * s * 1.63
					if not PLACE.has_point(tq):
						_boite_st(dalles, Vector3(tq.x, hauteur(tq.x, tq.y) + 0.04, tq.y), Vector3(long / nb + 0.02, 0.12, 3.0), ang, Color.WHITE)
	var mb := MeshInstance3D.new()
	mb.name = "Bordures"
	mb.mesh = bordures.commit()
	var mat := materiau(Color.WHITE, 0.85, true)
	mat.vertex_color_is_srgb = true
	mb.material_override = mat
	ville.add_child(mb)
	var md := MeshInstance3D.new()
	md.name = "Trottoirs"
	md.mesh = dalles.commit()
	# les trottoirs des rues en dalles de 40 sur 27, plus serrées que celles du quai
	var mtr: ShaderMaterial = _materiau_dalles_quai().duplicate()
	mtr.set_shader_parameter("echelle", 3.6)
	md.material_override = mtr
	md.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ville.add_child(md)


## L'enrobé des rues des pentes : un gris chaud et sombre, des reprises plus claires ou plus noires, un grain
## fin de gravillons ; il tient à côté des pavés de la place sans les imiter.
func materiau_enrobe() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley;
varying vec3 monde;
void vertex() { monde = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = monde.xz;
	float reprise = bruit(p * 0.18) * 0.6 + bruit(p * 0.55) * 0.4;
	float grain = hash(floor(p * 18.0));
	// un gris bleuté : la lumière dorée de fin septembre le ramène au gris neutre à l'écran
	vec3 c = pow(vec3(0.62, 0.645, 0.71), vec3(2.2));
	c *= 0.82 + 0.3 * reprise + 0.12 * (grain - 0.5);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


# --- Le bâti --------------------------------------------------------------------------------------

## Les immeubles qui bordent la place et la montée sont des immeubles du façadier lyonnais, posés sur
## leur rectangle réel ; les autres, des volumes à fenêtres peintes par le shader de la ville.
## Le pignon d'un immeuble du façadier, là où la rangée s'arrête : la descente d'eau de zinc sur ses colliers, sa
## cuvette sous la corniche et son dauphin de fonte au pied ; un pignon sur deux garde une vieille réclame peinte,
## passée au soleil, et la trace du toit d'une maison démolie. x : le flanc, dans le repère de l'immeuble.
func _pignon(m: Node3D, x: float, corniche: float, enduit: Color, graine: int) -> void:
	var s := signf(x)
	var zinc := Color("#8a9094")
	var px := x + s * 0.14
	_segment(m, Vector3(px, 0.9, -0.9), Vector3(px, corniche - 0.5, -0.9), 0.05, zinc, 0.45)
	_boite(m, Vector3(0.22, 0.32, 0.26), Vector3(px, corniche - 0.35, -0.9), zinc.darkened(0.1))
	_segment(m, Vector3(px, 0.0, -0.9), Vector3(px, 0.95, -0.9), 0.06, Color("#4a4a48"), 0.3)
	var y := 2.6
	while y < corniche - 0.8:
		_boite(m, Vector3(0.2, 0.05, 0.16), Vector3(x + s * 0.07, y, -0.9), zinc.darkened(0.25))
		y += 2.8
	if graine % 2 == 1:
		return
	# la trace du toit disparu : un triangle d'enduit plus sombre, au pied du pignon
	var trace := Node3D.new()
	trace.position = Vector3(x + s * 0.012, 0.0, -1.5)
	m.add_child(trace)
	var haut := minf(corniche * 0.45, 7.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in [Vector3(0, 0, 1.45), Vector3(0, 0, -1.45), Vector3(0, haut, -0.2)]:
		st.set_normal(Vector3(s, 0, 0))
		st.add_vertex(q)
	var tri := MeshInstance3D.new()
	tri.mesh = st.commit()
	tri.material_override = materiau(enduit.darkened(0.14))
	tri.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	trace.add_child(tri)
	# la réclame peinte, au-dessus de la trace : un fond crème passé, trois lignes de lettres délavées
	var yr := haut + 2.4
	if yr + 1.7 > corniche - 0.5:
		return
	var fond := enduit.lerp(Color("#efe4c8"), 0.35)
	_boite(m, Vector3(0.02, 3.4, 2.4), Vector3(x + s * 0.012, yr, -1.5), fond)
	# deux bandes de couleur passée, à 40 % dans l'enduit : une large rouge sombre, une plus étroite bleue
	for l in 2:
		var teinte: Color = fond.lerp(Color("#7a3e30") if l == 0 else Color("#3e5a6e"), 0.4)
		_boite(m, Vector3(0.02, 0.8 if l == 0 else 0.45, 2.0), Vector3(x + s * 0.02, yr + 0.55 - l * 1.15, -1.5), teinte)


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
	# les murs des volumes cachent au moteur tout ce qui est derrière eux (le socle a l'occlusion culling)
	var occ_v := PackedVector3Array()
	var occ_i := PackedInt32Array()
	_grille_emprises()
	for i in data.batiments.size():
		var b: Dictionary = data.batiments[i]
		if _reserve(Vector2(b.rect[0], b.rect[1]) * U):
			continue
		if _heros.has(i):
			_heros_poser(i, b)
			continue
		if i == HALLE:
			_halle(b)
			continue
		var poly := PackedVector2Array()
		for q in b.p:
			poly.append(Vector2(q[0], q[1]) * U)
		var sol: float = b.sol * U - 0.5
		var h: float = b.h * U + 0.5
		if i == 745:
			# l'immeuble à fenêtres carrées au haut de la montée, vu de la mairie : un étage de moins, il se range
			# derrière elle au lieu de la dominer (verdicts 24 et 34)
			h -= 3.3
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
			# le relevé ne tourne pas toujours dans le même sens : le mur regarde dehors, sinon il disparaît vu de la
			# rue et laisse voir le dessous du toit, une dalle sombre qui semble basculée
			var ordre := [0, 2, 1, 0, 3, 2]
			if Geometry2D.is_point_in_polygon((a + bb) * 0.5 + Vector2(n.x, n.z) * 0.3, poly):
				n = -n
				ordre = [0, 1, 2, 0, 2, 3]
			# un mur mitoyen ne se voit pas : on ne le dessine pas (il scintillerait contre celui du voisin) ; mais
			# au-dessus d'un voisin plus bas il se voit, et sans lui le toit flotte en dalle sombre vu de la rue
			var voisin := _dans_qui((a + bb) * 0.5 + Vector2(n.x, n.z) * 0.6, i)
			if voisin >= 0:
				var bv: Dictionary = data.batiments[voisin]
				var haut_voisin: float = bv.sol * U + bv.h * U
				if sol + h - haut_voisin < 1.0:
					continue
				for j in 2:
					v[j].y = haut_voisin
				uv[0].y = haut_voisin - sol
				uv[1].y = haut_voisin - sol
			if _relief_pose.has(Vector2i(i, k)):
				# derrière les façades en relief, le mur recule : il ne se voit qu'au-dessus d'une corniche plus basse
				for j in 4:
					v[j] -= n * 0.25
			var base := occ_v.size()
			occ_v.append_array(PackedVector3Array([v[0], v[1], v[2], v[3]]))
			occ_i.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
			for idx in ordre:
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
	# les deux faces portent ombre : la vue d'ensemble attend l'ombre des façades ouest sur la rue, soleil bas
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	mm.mesh = murs.commit()
	var ecrans := ArrayOccluder3D.new()
	ecrans.set_arrays(occ_v, occ_i)
	var occ := OccluderInstance3D.new()
	occ.name = "Ecrans"
	occ.occluder = ecrans
	ville.add_child(occ)
	mm.material_override = materiau_murs()
	ville.add_child(mm)
	var mt := MeshInstance3D.new()
	mt.name = "Toits"
	mt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	mt.mesh = toits.commit()
	mt.material_override = materiau_toits()
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


## La halle de la Martinière (1838), pièce unique du parcours : un long vaisseau bas de pierre dorée, ses arcades
## en plein cintre vitrées sur la rue, ses pilastres, sa corniche et son attique percé de petites baies, le toit de
## zinc et sa lanterne vitrée qui court sur toute la longueur, l'inscription dorée sur la rue.
func _halle(b: Dictionary) -> void:
	var rc: Array = b.rect
	var c := Vector2(rc[0], rc[1]) * U
	var L: float = rc[2] * U
	var P: float = rc[3] * U
	var a: float = rc[4]
	var sol: float = b.sol * U - 0.3
	var h := maxf(b.h * U, 10.0)
	var m := Node3D.new()
	m.name = "HalleMartiniere"
	m.position = Vector3(c.x, sol, c.y)
	m.rotation.y = -a
	ville.add_child(m)
	# la pierre grise de la vraie halle, la brique rouge des tympans
	var pierre := Color("#c8bc9e")
	var claire := Color("#d9cfb4")
	var brique := Color("#a5553a")
	var vitre := Color("#3c4a4c")
	var fer := Color("#3f4b46")
	var app := _materiau_appareil(pierre)
	var corps := _boite(m, Vector3(L, 7.0, P), Vector3(0, 3.5, 0), pierre)
	corps.material_override = app
	# le soubassement, la corniche et l'attique
	_boite(m, Vector3(L + 0.3, 0.6, P + 0.3), Vector3(0, 0.3, 0), pierre.darkened(0.12))
	_boite(m, Vector3(L + 0.7, 0.45, P + 0.7), Vector3(0, 7.15, 0), claire)
	_boite(m, Vector3(L + 0.9, 0.18, P + 0.9), Vector3(0, 7.45, 0), claire.darkened(0.05))
	var attique := _boite(m, Vector3(L - 0.4, 1.8, P - 0.4), Vector3(0, 8.4, 0), pierre)
	attique.material_override = app
	_boite(m, Vector3(L, 0.25, P), Vector3(0, 9.4, 0), claire)
	# le toit de zinc à faible pente et la lanterne vitrée
	_boite(m, Vector3(L - 0.6, 0.5, P - 0.6), Vector3(0, 9.75, 0), Color("#8b9095"))
	var lanterne := _boite(m, Vector3(L - 4.0, 1.4, P * 0.35), Vector3(0, 10.7, 0), Color("#9fb3b5"))
	var mv := materiau(Color("#9fb3b5"), 0.15)
	mv.metallic = 0.3
	lanterne.material_override = mv
	for k in int((L - 4.0) / 1.2):
		var x := -(L - 4.0) * 0.5 + 0.6 + k * 1.2
		for s in [-1.0, 1.0]:
			_boite(m, Vector3(0.08, 1.45, 0.08), Vector3(x, 10.7, s * P * 0.175), fer)
	_boite(m, Vector3(L - 3.6, 0.2, P * 0.42), Vector3(0, 11.5, 0), Color("#7d8288"))
	# les arcades sur les quatre côtés : pilastres, baies vitrées en plein cintre, clés et impostes
	var travee := 4.2
	var cote_rue := -1.0 if cos(-a) < 0.0 else 1.0
	# les arcades ouvertes sur les étals : les trois de la façade sur rue les plus proches du trottoir de la Vue1b
	var ouvertes := {}
	var nb_rue := maxi(1, int(L / travee))
	var rangs := []
	for k in nb_rue:
		var x := -L * 0.5 + (k + 0.5) * L / nb_rue
		var local := Vector3(x if cote_rue > 0.0 else -x, 0, cote_rue * P * 0.5)
		var monde: Vector3 = m.transform * local
		rangs.append([Vector2(monde.x, monde.z).distance_to(Vector2(-76.0, 118.6)), k])
	rangs.sort_custom(func(u, w): return u[0] < w[0])
	for j in 3:
		ouvertes[rangs[j][1]] = true
	var ceramiques := [Color("#2f6ea0"), Color("#e0a93a"), Color("#3f8a55"), Color("#b8452e")]
	for cote in [[L, P, 0.0], [L, P, PI], [P, L, PI * 0.5], [P, L, -PI * 0.5]]:
		var longueur: float = cote[0]
		var profond: float = cote[1]
		var f := Node3D.new()
		f.rotation.y = cote[2]
		m.add_child(f)
		var z := profond * 0.5
		var nb := maxi(1, int(longueur / travee))
		var pas := longueur / nb
		for k in nb + 1:
			var x := -longueur * 0.5 + k * pas
			_boite(f, Vector3(0.75, 6.6, 0.3), Vector3(x, 3.3, z + 0.12), claire)
			_boite(f, Vector3(0.95, 0.35, 0.4), Vector3(x, 6.6, z + 0.15), claire.darkened(0.04))
		var sur_rue: bool = longueur == L and ((cote[2] == 0.0 and cote_rue > 0.0) or (cote[2] == PI and cote_rue < 0.0))
		# la frise de céramique sous la corniche, en carreaux de couleur alternés
		# des carreaux de 55 cm sur une bande de 60, pour qu'elle se lise depuis le trottoir d'en face
		_boite(f, Vector3(longueur, 0.62, 0.05), Vector3(0, 6.42, z + 0.05), claire)
		var nc := int(longueur / 0.62)
		for j in nc:
			_boite(f, Vector3(0.55, 0.5, 0.06), Vector3(-longueur * 0.5 + (j + 0.5) * longueur / nc, 6.42, z + 0.07), ceramiques[j % 4])
		for k in nb:
			var x := -longueur * 0.5 + (k + 0.5) * pas
			var r := (pas - 0.75) * 0.5 - 0.25
			var base := 4.4
			var ouverte: bool = sur_rue and ouvertes.has(k)
			# le tympan de brique entre les arcs de pierre, jusqu'à la frise ; au-dessus de l'arc seulement quand
			# l'arcade est ouverte, l'ombre de la halle remplit l'arc
			var pied := base + r + 0.1 if ouverte else base
			_boite(f, Vector3(pas - 0.75, 6.6 - pied + 0.1, 0.05), Vector3(x, pied + (6.6 - pied) * 0.5, z + 0.0), brique)
			if ouverte:
				# l'arcade ouverte : le fond d'ombre de la halle, et l'étal devant, ses cagettes et sa toile
				_boite(f, Vector3(r * 2.0, base, 0.1), Vector3(x, base * 0.5, z + 0.03), Color("#2b2620"))
				for j in 9:
					var t := PI * j / 8.0
					_boite(f, Vector3(r * 0.36, maxf(0.2, sin(t) * r), 0.1), Vector3(x + cos(t) * r * 0.82, base + sin(t) * r * 0.5, z + 0.03), Color("#2b2620"))
				_boite(f, Vector3(r * 2.0 + 0.2, 0.08, 1.0), Vector3(x, 0.92, z + 0.75), Color("#8a6a45"))
				for e in [-1.0, 1.0]:
					_boite(f, Vector3(0.08, 0.9, 0.9), Vector3(x + e * r, 0.45, z + 0.75), Color("#6e5236"))
				var fruits := [Color("#e07a2e"), Color("#c8102e"), Color("#7aa63a"), Color("#e8c547"), Color("#8e3a6e")]
				for j in 4:
					var cx := x - r + 0.45 + j * (r * 2.0 - 0.9) / 3.0
					_boite(f, Vector3(0.55, 0.2, 0.42), Vector3(cx, 1.06, z + 0.75), Color("#b8915e"))
					_boite(f, Vector3(0.48, 0.12, 0.36), Vector3(cx, 1.2, z + 0.75), fruits[(k + j) % fruits.size()])
				var toile := _boite(f, Vector3(r * 2.0 + 0.3, 0.05, 1.3), Vector3(x, 2.55, z + 0.75), Color("#e8e0cc"), 0.0)
				toile.rotation.x = -0.3
				for j in 4:
					var bande := _boite(f, Vector3((r * 2.0 + 0.3) / 8.0, 0.055, 1.31), Vector3(x - r - 0.15 + (j * 2 + 0.5) * (r * 2.0 + 0.3) / 8.0, 2.55, z + 0.75), Color("#2f6b4a"))
					bande.rotation.x = -0.3
			else:
				# la baie : le rectangle vitré et son arc, les petits bois
				_boite(f, Vector3(r * 2.0, base - 0.6, 0.12), Vector3(x, 0.6 + (base - 0.6) * 0.5, z + 0.02), vitre)
				for j in 9:
					var t := PI * j / 8.0
					_boite(f, Vector3(r * 0.36, maxf(0.2, sin(t) * r), 0.12), Vector3(x + cos(t) * r * 0.82, base + sin(t) * r * 0.5, z + 0.02), vitre)
				_boite(f, Vector3(0.05, base - 0.6, 0.16), Vector3(x, 0.6 + (base - 0.6) * 0.5, z + 0.06), fer)
				_boite(f, Vector3(r * 2.0, 0.05, 0.16), Vector3(x, 2.6, z + 0.06), fer)
			for j in 11:
				var t := PI * j / 10.0
				var vs := _boite(f, Vector3(0.42, 0.24, 0.32), Vector3(x + cos(t) * (r + 0.12), base + sin(t) * (r + 0.12), z + 0.1), claire)
				vs.rotation.z = t - PI * 0.5
			_boite(f, Vector3(0.36, 0.5, 0.36), Vector3(x, base + r + 0.2, z + 0.16), claire.lightened(0.05))
			# les petites baies carrées de l'attique, une par travée, sauf sous l'inscription
			if absf(x) > 8.5 or longueur < 20.0:
				_boite(f, Vector3(1.1, 0.8, 0.1), Vector3(x, 8.4, z - 0.15), vitre)
	# l'inscription sur la rue, en lettres dorées sur la frise
	var cartouche := _boite(m, Vector3(15.0, 1.0, 0.1), Vector3(0, 8.4, cote_rue * (P * 0.5 - 0.15)), Color("#4a5249"))
	cartouche.material_override = materiau(Color("#4a5249"), 0.6)
	_boite(m, Vector3(15.4, 0.08, 0.14), Vector3(0, 8.92, cote_rue * (P * 0.5 - 0.15)), Color("#c9a24a"))
	_boite(m, Vector3(15.4, 0.08, 0.14), Vector3(0, 7.88, cote_rue * (P * 0.5 - 0.15)), Color("#c9a24a"))
	var mot := Label3D.new()
	mot.text = "HALLE DE LA MARTINIÈRE"
	mot.font_size = 96
	mot.pixel_size = 0.0078
	mot.double_sided = false
	mot.modulate = Color("#e2bf63")
	mot.outline_size = 0
	mot.shaded = false
	mot.position = Vector3(0, 8.35, cote_rue * (P * 0.5 + 0.08))
	mot.rotation.y = 0.0 if cote_rue > 0.0 else PI
	m.add_child(mot)
	# on ne la traverse pas
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(L, 9.0, P)
	cs.shape = bx
	cs.position = Vector3(0, 4.5, 0)
	sb.add_child(cs)
	m.add_child(sb)


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
			var opt := {"w": w - 0.04, "d": 3.0, "niveaux": niveaux, "tuile": TUILES[(i + j) % TUILES.size()], "pente": 29.0, "grain": 1.0, "chassis": 1 + (i + j) % 2, "souches": "grosses", "toile": TOILES[(i * 5 + k * 3 + j) % TOILES.size()], "store": (i + k + j) % 2 == 0}
			opt["enduit"] = (ENDUITS_PENTES if pentes else ENDUITS_PLACE)[(i + k + j) % 5]
			if pentes:
				opt["fleurs"] = false
			elif q.x > 25.0 and q.y > -15.0 and q.y < 55.0:
				# le flanc est de la place, en plein soleil sur la planche : ocre, balcons filants, jardinières
				opt["enduit"] = "d6b27a"
				opt["balcons"] = true
				opt["fleurs"] = true
			var m: Node3D = load(Bibliotheque.scene(FACADIER, "decor")).instantiate()
			_modules_ville.append(m)
			m.type = type
			m.graine = i * 31 + k * 7 + j
			m.options = opt
			var y := hauteur(q.x, q.y) - 0.05
			m.position = Vector3(q.x, y, q.y)
			m.rotation.y = atan2(n.x, n.y)
			ville.add_child(m)
			if j % 2 == 0:
				_souches_cote_rue(m, w - 0.04, 3.0, Color(str(opt["enduit"])))
			for bout in [-1.0, 1.0]:
				if (bout < 0.0 and j > 0) or (bout > 0.0 and j < nb - 1):
					continue
				# le flanc que rien ne cache, au bout de la rangée : un pignon nu, que l'on habille
				var dehors: Vector2 = q + u * bout * (w * 0.5 + 0.8) - n * 1.5
				if Geometry2D.is_point_in_polygon(dehors, poly) or _dans_un_autre(dehors, i):
					continue
				# le x de l'immeuble court le long de (n.y, -n.x), qui va dans le sens de u ou à rebours
				var cote: float = signf(Vector2(n.y, -n.x).dot(u)) * bout
				_pignon(m, cote * (w * 0.5 - 0.02), 4.2 + float(opt.niveaux) * 3.3, Color(str(opt["enduit"])), i * 7 + k + j)
			corniches.append(y + 4.2 + float(opt.niveaux) * 3.3)
	return corniches


## Deux grosses souches enduites sur le pan côté rue, comme sur la planche : celles du façadier
## sont sur le pan arrière, que la vue d'ensemble ne montre pas. w et d : la largeur et la profondeur de l'immeuble.
func _souches_cote_rue(m: Node3D, w: float, d: float, enduit: Color) -> void:
	var faite: float = m.get_meta("hauteur", 0.0)
	if faite <= 0.0 or w < 6.0:
		return
	# à 3,5 m de la façade au plus : sur les toits profonds, le faîte sort du cadre de la vue d'ensemble
	var z := -minf(3.5, d * 0.5 - 1.0)
	# du pan, pris assez bas pour qu'elle y soit fichée, jusqu'à 1,6 m au-dessus du faîte, comme à Lyon
	var bas := faite - (d * 0.5 + z) * tan(deg_to_rad(40.0)) - 0.5
	var haut := faite + 1.6
	# et sur le pan arrière des immeubles profonds, qui est celui que la vue d'ensemble voit quand la façade
	# regarde l'autre rue
	var pans := [z, -d - z] if d > 8.0 else [z]
	for zp in pans:
		for x in [-0.27 * w, 0.31 * w]:
			_boite(m, Vector3(1.3, haut - bas, 0.8), Vector3(x, (haut + bas) * 0.5, zp), enduit.darkened(0.1))
			_boite(m, Vector3(1.5, 0.16, 1.0), Vector3(x, haut + 0.08, zp), Color("#b9ac92"))
			for j in 3:
				_boite(m, Vector3(0.18, 0.35, 0.18), Vector3(x - 0.4 + j * 0.4, haut + 0.33, zp), Color("#b5603c"))


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


## Le bâtiment voisin dont l'emprise contient p, ou -1.
func _dans_qui(p: Vector2, sauf: int) -> int:
	for j in _grille.get(Vector2i(floori(p.x / 10.0), floori(p.y / 10.0)), []):
		if j != sauf and Geometry2D.is_point_in_polygon(p, _emprises[j]):
			return j
	return -1


func _enduit(c: Vector2, i: int) -> Color:
	# les pentes (au nord et à l'est, plus haut) sont plus pâles et plus usées que le bas
	var pentes := c.y < -45.0 or c.x > 90.0
	var liste: Array = ENDUITS_PENTES if pentes else ENDUITS_PLACE
	var col := Color(liste[(i * 7 + 3) % liste.size()])
	# le flanc est de la place, en plein soleil sur la planche : ocre
	if not pentes and c.x > 25.0 and c.x < 60.0 and c.y > -15.0 and c.y < 55.0:
		col = Color("d6b27a")
	return col.darkened(float(i % 5) * 0.025)


## Une boîte dans un SurfaceTool : centre c, taille t, tournée de ang autour de la verticale.
func _boite_st(st: SurfaceTool, c: Vector3, t: Vector3, ang: float, col: Color) -> void:
	var b := Basis(Vector3.UP, -ang)
	var h := t * 0.5
	for f in [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD], [Vector3.BACK, Vector3.UP, Vector3.LEFT],
			[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT], [Vector3.UP, Vector3.BACK, Vector3.RIGHT]]:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var r: Vector3 = f[2]
		var o := n * h
		var ea := a * h
		var er := r * h
		var coins := [o - ea - er, o - ea + er, o + ea + er, o + ea - er]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(col if n != Vector3.UP else col.darkened(0.2))
			st.set_normal(b * n)
			st.add_vertex(c + b * coins[idx])


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
		# les grosses souches de cheminée enduites, posées sur le faîtage, et leur couronnement de pierre
		var nc := clampi(int(lu * 2.0 / 7.0), 2, 3)
		for k in nc:
			var t := (float(k) + 0.5) / nc + (float(i % 5) - 2.0) * 0.04
			var q := E.lerp(F, t) + Vector3(v.x, 0, v.y) * (0.9 if (i + k) % 2 else -0.9)
			_boite_st(st, q + Vector3(0, 0.6, 0), Vector3(1.3, 2.4, 0.8), rc[4], Color(ENDUITS_PLACE[(i + k) % ENDUITS_PLACE.size()]).darkened(0.08))
			_boite_st(st, q + Vector3(0, 1.88, 0), Vector3(1.5, 0.16, 1.0), rc[4], Color("#b9ac92"))
		# les lucarnes à mi-pente : un petit corps enduit, sa fenêtre et son chapeau de tuile
		var nl := clampi(int(lu / 3.5), 1, 4)
		for k in nl:
			var t := (float(k) + 0.5) / nl
			# sur les deux pans : la vue d'ensemble voit l'un ou l'autre selon le côté de la rue
			for pan in [[A.lerp(B, t), -1.0], [D.lerp(C, t), 1.0]]:
				var pied: Vector3 = pan[0].lerp(E.lerp(F, t), 0.45)
				var dehors := Vector3(v.x, 0, v.y) * float(pan[1])
				_boite_st(st, pied + Vector3(0, 0.45, 0), Vector3(1.0, 1.0, 0.9), rc[4], Color(ENDUITS_PLACE[(i + k) % ENDUITS_PLACE.size()]))
				_boite_st(st, pied + Vector3(0, 0.45, 0) + dehors * 0.46, Vector3(0.55, 0.6, 0.04), rc[4], Color("#3a4250"))
				_boite_st(st, pied + Vector3(0, 1.02, 0), Vector3(1.2, 0.18, 1.1), rc[4], tuile.darkened(0.1))
		return
	var dessus := poly
	var rehausse := 0.15
	if b.toit != "plat" and poly.size() >= 3:
		# un toit en croupe sur un plan quelconque : un rampant de tuile de 2,5 m sur tout le pourtour, monté à
		# 29°, puis un terrasson de tuile ; une souche sur le terrasson
		var d := 2.5
		var monte := d * tan(deg_to_rad(29.0))
		var ccw := Geometry2D.is_polygon_clockwise(poly) == false
		var dedans := PackedVector2Array()
		for k in poly.size():
			var a := poly[(k - 1 + poly.size()) % poly.size()]
			var o := poly[k]
			var c := poly[(k + 1) % poly.size()]
			var n1 := (o - a).normalized().orthogonal()
			var n2 := (c - o).normalized().orthogonal()
			if not ccw:
				n1 = -n1
				n2 = -n2
			var m := (n1 + n2).normalized()
			var cosinus := maxf(m.dot(n1), 0.5)
			dedans.append(o - m * d / cosinus)
		if Geometry2D.triangulate_polygon(dedans).size() > 0 and Geometry2D.is_polygon_clockwise(dedans) == Geometry2D.is_polygon_clockwise(poly):
			for k in poly.size():
				var k2 := (k + 1) % poly.size()
				var A := Vector3(poly[k].x, haut, poly[k].y)
				var B := Vector3(poly[k2].x, haut, poly[k2].y)
				var C := Vector3(dedans[k2].x, haut + monte, dedans[k2].y)
				var D := Vector3(dedans[k].x, haut + monte, dedans[k].y)
				for t3 in [[A, B, C], [A, C, D]]:
					var nn: Vector3 = (t3[1] - t3[0]).cross(t3[2] - t3[0]).normalized()
					if nn.y < 0.0:
						t3 = [t3[0], t3[2], t3[1]]
						nn = -nn
					for q in t3:
						st.set_color(tuile)
						st.set_normal(nn)
						st.add_vertex(q)
			dessus = dedans
			rehausse = monte
			var centre := Vector2.ZERO
			for q in dedans:
				centre += q
			centre /= dedans.size()
			# une souche au milieu de chacun des trois plus longs bords du terrasson, là où la vue d'ensemble les voit
			var bords := []
			for k in dedans.size():
				bords.append([dedans[k].distance_to(dedans[(k + 1) % dedans.size()]), k])
			bords.sort_custom(func(x, y): return x[0] > y[0])
			for j in mini(3, bords.size()):
				if bords[j][0] < 4.0:
					continue
				var k: int = bords[j][1]
				var q := (dedans[k] + dedans[(k + 1) % dedans.size()]) * 0.5
				q = q.lerp(centre, 0.15)
				var ang := (dedans[(k + 1) % dedans.size()] - dedans[k]).angle()
				_boite_st(st, Vector3(q.x, haut + monte + 0.6, q.y), Vector3(1.3, 2.4, 0.8), ang, Color(ENDUITS_PLACE[(i + j) % ENDUITS_PLACE.size()]).darkened(0.08))
				_boite_st(st, Vector3(q.x, haut + monte + 1.88, q.y), Vector3(1.5, 0.16, 1.0), ang, Color("#b9ac92"))
	var tri := Geometry2D.triangulate_polygon(dessus)
	for k in range(0, tri.size(), 3):
		for j in [0, 2, 1]:
			var p := dessus[tri[k + j]]
			st.set_color(tuile.darkened(0.06) if b.toit != "plat" else Color("#a39a8c"))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(p.x, haut + rehausse, p.y))


## Le relief des façades ne se lit que de près : au-delà de RELIEF_PORTEE, les modules du façadier s'effacent
## en fondu et laissent voir le volume peint qui les attend derrière (fenêtres, enduit, toit), reculé de 25 cm.
func _relief_de_pres() -> void:
	for m in _modules_ville:
		var pile: Array[Node] = [m]
		while not pile.is_empty():
			var n: Node = pile.pop_back()
			pile.append_array(n.get_children())
			if n is GeometryInstance3D:
				var g := n as GeometryInstance3D
				g.visibility_range_end = RELIEF_PORTEE / U
				g.visibility_range_end_margin = 10.0 / U
				g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Le shader des toits de la ville : la tuile canal du façadier, en rangs parallèles à l'égout, avec ses ondes
## et six nuances d'une tuile à l'autre. Les teintes des sommets sont en sRGB.
func materiau_toits() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
varying vec3 lp;
varying vec3 ln;
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}
void fragment() {
	vec3 c = COLOR.rgb;
	if (abs(ln.y) > 0.2 && abs(ln.y) < 0.97) {
		vec2 h = normalize(ln.xz);
		float s = dot(lp.xz, vec2(-h.y, h.x)) / 0.3;
		float r = lp.y / 0.3;
		float rang = floor(r);
		float onde = 0.5 + 0.5 * cos(6.2832 * s);
		float recouvrement = smoothstep(0.0, 0.35, fract(r));
		float nuance = floor(hash(vec2(rang, floor(s))) * 6.0) / 5.0;
		c *= (0.72 + 0.28 * onde) * (0.6 + 0.4 * recouvrement) * (0.88 + 0.24 * nuance);
		// vu de haut, les rangs de 30 cm se fondent : un rang sur quatre plus sombre, et des plaques de tuiles
		// plus neuves ou plus passées, pour que le pan garde son grain depuis la Vue1
		float cours = step(3.0, mod(rang, 4.0));
		c *= 1.0 - 0.25 * cours;
		float plaque = hash(vec2(floor(s / 6.0), floor(r / 5.0)));
		c *= 0.85 + 0.3 * plaque;
	}
	ALBEDO = pow(c, vec3(2.2)) * 1.4;
	ROUGHNESS = 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Le shader de la ville : les fenêtres hautes des immeubles lyonnais, les persiennes, le bandeau du
## rez-de-chaussée et ses boutiques, les encadrements clairs et les géraniums aux fenêtres.
func materiau_murs() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
// les deux faces : quelques emprises du relevé tournent à l'envers, et un mur vu de dos laissait voir le
// dessous du toit comme une dalle sombre basculée
render_mode diffuse_burley, cull_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	// les teintes d'enduit sont en sRGB, comme celles du façadier
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	// un mur peint n'est qu'un fond : moins saturé que le façadier, il ne tire pas l'œil en brun ou en orange
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), 0.45) * 1.06;
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
		fen = step(0.3, fx) * step(fx, 0.7) * step(0.18, fy) * step(fy, 0.9);
		volet = (step(0.17, fx) * step(fx, 0.3) + step(0.7, fx) * step(fx, 0.83)) * step(0.18, fy) * step(fy, 0.9) * step(0.45, id);
	}
	float bandeau = step(rdc - 0.25, y) * step(y, rdc + 0.05) + step(h - 0.6, y);
	// l'encadrement de pierre claire autour de chaque fenêtre d'étage, et la jardinière de géraniums
	float cadre = 0.0;
	float fleurs = 0.0;
	if (etage > 0.5 && y < h - 1.3) {
		cadre = step(0.26, fx) * step(fx, 0.74) * step(0.13, fy) * step(fy, 0.94) * (1.0 - fen);
		fleurs = step(0.28, fx) * step(fx, 0.72) * step(0.18, fy) * step(fy, 0.27) * step(0.4, hash(vec2(bx, etage) + UV2.y + 7.0));
	}
	// le verre des modules du façadier, bleu-gris pâle, pour que la relève ne se voie pas au fondu
	vec3 verre = vec3(0.3, 0.37, 0.44) + vec3(0.06, 0.06, 0.05) * step(fy, 0.5);
	vec3 col = c * (0.92 + 0.1 * hash(vec2(floor(y * 2.0), bx)));
	col = mix(col, vec3(0.42, 0.5, 0.44) * (0.8 + 0.4 * hash(vec2(UV2.y, 3.0))), volet);
	col = mix(col, c * 1.12, bandeau);
	col = mix(col, vec3(0.95, 0.92, 0.84), cadre);
	col = mix(col, verre, fen);
	col = mix(col, mix(vec3(0.78, 0.12, 0.14), vec3(0.24, 0.42, 0.18), step(0.23, fy)), fleurs);
	// l'ombre de contact que le rendu n'a pas : sous l'égout et au pied du mur
	col *= 1.0 - 0.35 * smoothstep(h - 0.6, h, y) - 0.3 * (1.0 - smoothstep(0.0, 0.4, y));
	// au loin, le volume prend le relais des façades du façadier : même clarté d'enduit au soleil
	ALBEDO = col * mix(1.0, 1.35, 1.0 - fen);
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
		var opt := {"w": w - 0.05, "d": lv, "niveaux": niveaux, "tuile": TUILES[(i + k) % TUILES.size()], "pente": 29.0, "grain": 1.0, "chassis": 2, "souches": "grosses", "toile": TOILES[(i * 3 + k) % TOILES.size()], "store": (i + k) % 2 == 0}
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
				# le flanc est de la place, en plein soleil sur la planche : ocre, balcons filants, jardinières
				if p.x > 25.0 and p.y > -15.0 and p.y < 55.0:
					opt["enduit"] = "d6b27a"
					opt["balcons"] = true
					opt["fleurs"] = true
			if absf(p.x - (-14.0)) < 6.0 and p.y > -5.0 and p.y < 45.0 and k == 0 and not _cafe_pose:
				_cafe_pose = true
				type = "cafe"
				opt["enseigne"] = "CAFÉ DU LION D'OR"
				opt["store"] = true
				opt["toile"] = ["b8352e", "f3ead6"]
				opt["avancee"] = 2.4
		var m: Node3D = load(Bibliotheque.scene(FACADIER, "decor")).instantiate()
		m.type = type
		m.graine = i * 17 + k
		m.options = opt
		if est_mairie:
			# le seuil au niveau de la rue devant la porte : le relevé la posait sous la chaussée qui monte
			var devant := p + v * 2.2
			sol = maxf(sol, hauteur(devant.x, devant.y) + 0.15)
		m.position = Vector3(p.x, hauteur(p.x, p.y) - 0.05 if not est_mairie else sol, p.y)
		m.rotation.y = lacet
		ville.add_child(m)
		if est_mairie:
			_mairie(m, w - 0.05)
			# le trottoir de pierre devant la mairie, au niveau du seuil, et sa bordure de granit : la chaussée
			# ne monte plus jusqu'à la porte ; en six tronçons, chacun descendu jusqu'à la rue qui monte
			for j in 6:
				var qj := p + u * (-w * 0.5 + w * (j + 0.5) / 6.0)
				var qt := qj + v * 0.95
				var qb := qj + v * 1.95
				var rue := hauteur(qb.x, qb.y)
				var haut_t := maxf(sol - 0.12, rue + 0.14)
				var dalle := _boite(ville, Vector3(w / 6.0 + 0.02, haut_t - rue + 0.3, 1.9), Vector3(qt.x, (haut_t + rue - 0.3) * 0.5, qt.y), Color("#b9b2a4"))
				dalle.rotation.y = lacet
				var bord := _boite(ville, Vector3(w / 6.0 + 0.02, haut_t - rue + 0.32, 0.22), Vector3(qb.x, (haut_t + rue - 0.3) * 0.5 + 0.01, qb.y), Color("#8e8f94"))
				bord.rotation.y = lacet
		else:
			_souches_cote_rue(m, w - 0.05, lv, Color(str(opt["enduit"])))
		# le socle de l'immeuble, jusqu'au point le plus bas de la pente
		var bas := minf(hauteur(p.x - u.x * w * 0.5, p.y - u.y * w * 0.5), hauteur(p.x + u.x * w * 0.5, p.y + u.y * w * 0.5))
		if m.position.y - bas > 0.3:
			var socle := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(w, m.position.y - bas + 0.4, lv)
			socle.mesh = bm
			socle.material_override = materiau(PIERRE_DOREE.darkened(0.15))
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
	# les quatre touffes fleuries aux coins du socle, de la même main que celles des trouées
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		for j in 3:
			var b := a + (float(j) - 1.0) * 0.28
			_pose(VEGETATION, "plante", "buisson", Vector3(BLANDAN.x + cos(b) * 4.0, y, BLANDAN.y + sin(b) * 4.0), 300 + k * 3 + j, {"hauteur": 1.0 + 0.3 * float(j % 2), "fleurs": ["f4f0e6", "e0605a", "d04a8a", "f4f0e6"][k]})
	# un bosquet de marronniers irrégulier (la planche) : des troncs semés dans tout le square, une clairière
	# autour de Blandan et dans l'axe de l'escalier, des massifs fleuris dans les trouées
	# le point de vue de Blandan (la planche) : pas de massif sous l'objectif
	var genants: Array[Vector2] = [Vector2(12.96, 23.76), Vector2(13.7, 21.4), Vector2(12.0, 21.0)]
	for k in 6:
		var zb := lerpf(sq.position.y + 9.0, sq.end.y - 9.0, float(k) / 5.0)
		genants.append(Vector2(sq.position.x + 4.6, zb))
		genants.append(Vector2(sq.end.x - 4.6, zb))
	var graines := RandomNumberGenerator.new()
	graines.seed = 1817
	var troncs: Array[Vector2] = []
	var essais := 0
	while troncs.size() < 17 and essais < 6000:
		essais += 1
		var p := Vector2(graines.randf_range(sq.position.x + 2.2, sq.end.x - 2.2), graines.randf_range(sq.position.y + 2.2, sq.end.y - 2.2))
		# seul un cercle de 7 m reste ouvert autour de Blandan, et l'allée vers l'escalier
		if p.distance_to(BLANDAN) < 7.0 or (absf(p.x - BLANDAN.x) < 2.5 and p.y < BLANDAN.y):
			continue
		var libre := true
		for q in troncs:
			if q.distance_to(p) < 8.0:
				libre = false
		for q in genants:
			if q.distance_to(p) < 2.0:
				libre = false
		if libre:
			troncs.append(p)
	# la planche en a 14 : on retire les deux plus proches du centre du square et celui du coin sud-ouest, pour
	# ouvrir les trouées sur les massifs et sur la statue
	for coin in [sq.get_center(), sq.get_center(), Vector2(sq.position.x, sq.end.y)]:
		var proche := 0
		for k in troncs.size():
			if troncs[k].distance_to(coin) < troncs[proche].distance_to(coin):
				proche = k
		troncs.remove_at(proche)
	for k in troncs.size():
		var p: Vector2 = troncs[k]
		var arbre := _pose(OMBRIERE, "arbre", "marronnier", Vector3(p.x, y, p.y), 400 + k, {"hauteur": graines.randf_range(12.0, 16.0), "vent": 0.4, "densite": graines.randf_range(0.75, 0.95), "contre_jour": 0.6, "jour": 0.6, "ajour": 0.55, "teinte": PALETTES_MARRONNIER[k % PALETTES_MARRONNIER.size()]})
		# des couronnes resserrées d'un huitième, que le sable et leur ombre séparent comme sur la planche
		arbre.scale = Vector3(0.88, 1.0, 0.88)
	var massifs := 0
	essais = 0
	# deux allées de gravier clair le long du square, de part et d'autre de Blandan, comme sur la planche
	var allees := [BLANDAN.x - 6.5, BLANDAN.x + 6.5]
	for ax in allees:
		_boite(ville, Vector3(1.8, 0.03, sq.size.y - 4.0), Vector3(ax, y + 0.015, sq.get_center().y), Color("#dcc8a2"))
	# les massifs fleuris de 3 à 5 m dans les trouées entre les couronnes : c'est eux qu'on voit d'en haut
	while massifs < 16 and essais < 4000:
		essais += 1
		var p := Vector2(graines.randf_range(sq.position.x + 3.0, sq.end.x - 3.0), graines.randf_range(sq.position.y + 3.0, sq.end.y - 3.0))
		var e := Vector2((p.x - BLANDAN.x) / 7.0, (p.y - BLANDAN.y) / 9.5)
		if e.length() < 1.0:
			continue
		var libre := true
		for ax in allees:
			if absf(p.x - ax) < 2.2:
				libre = false
		for q in troncs:
			if q.distance_to(p) < 4.0:
				libre = false
		for q in genants:
			if q.distance_to(p) < 2.6:
				libre = false
		if libre:
			massifs += 1
			# trois boules molles de 1 à 2 m, d'une seule couleur de fleur par touffe
			var fleur: String = ["f4f0e6", "d04a8a", "e0605a", "f2c14e"][massifs % 4]
			for j in 3:
				var a := TAU * j / 3.0 + graines.randf()
				var q := p + Vector2(cos(a), sin(a)) * graines.randf_range(0.6, 1.1)
				_pose(VEGETATION, "plante", "buisson", Vector3(q.x, y, q.y), 700 + massifs * 3 + j, {"hauteur": graines.randf_range(1.0, 1.8), "fleurs": fleur})
			genants.append(p)
	# la bordure basse de pierre grise et les plates-bandes fleuries, en herbe, le long du pourtour
	var noir := Color("#6e6a64")
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
				_pose(VEGETATION, "plante", "herbe", Vector3(q.x, y, q.y) + Vector3(dedans.x, 0, dedans.y) * 0.9, 640 + k, {"longueur": 2.0, "largeur": 1.4}, atan2(dir.x, dir.y))
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
	# les candélabres à trois lanternes aux quatre coins du square, comme sur la planche
	for k in 4:
		var c := Vector2(sq.position.x + 2.0 if k % 2 == 0 else sq.end.x - 2.0, sq.position.y + 2.0 if k < 2 else sq.end.y - 2.0)
		_pose(MOBILIER, "objet", "candelabre", Vector3(c.x, y, c.y), 85 + k, {})
	_vie(y)
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
	_rues_du_square(y)


## Les rues autour du square, comme sur la planche : le caniveau de la rue est, son passage piéton au sud, une
## voiture rouge garée au bout et une camionnette dans la rue ouest, hors des couronnes pour qu'on les voie d'en haut.
func _rues_du_square(y: float) -> void:
	_boite(ville, Vector3(0.35, 0.02, 60.0), Vector3(30.5, y + 0.012, SQUARE.get_center().y), Color("#6f6a62"))
	for k in 7:
		_boite(ville, Vector3(0.5, 0.02, 3.2), Vector3(24.0 + k * 0.9, y + 0.014, SQUARE.end.y + 2.5), Color("#ece8de"))
	var garees := [["citadine", Vector2(28.0, 50.6), {"couleur": "c8102e"}], ["fourgonnette", Vector2(-5.0, 24.0), {"couleur": "efe9dc"}]]
	for k in garees.size():
		var g: Array = garees[k]
		var vo: Node3D = load(Bibliotheque.scene("voitures-des-annees-80@1", "decor")).instantiate()
		vo.voiture = g[0]
		vo.graine = 80 + k
		vo.options = g[2]
		vo.position = Vector3(g[1].x, y, g[1].y)
		ville.add_child(vo)


## La vie du square, un soir de septembre : des groupes qui bavardent autour de Blandan, deux lecteurs sur
## les bancs, des promeneurs sur les trottoirs et dans l'axe du square. Les figurants du socle sont à l'échelle
## du jeu : on les pose sous la scène, hors de la ville en mètres.
func _vie(y: float) -> void:
	var groupe := Node3D.new()
	groupe.name = "Habitants"
	add_child(groupe)
	var g := 69123
	for centre in [Vector2(BLANDAN.x - 2.0, BLANDAN.y + 8.5), Vector2(BLANDAN.x + 5.5, 33.0), Vector2(-9.0, 8.0), Vector2(29.0, 16.0)]:
		for k in 3:
			var a: float = TAU * k / 3.0 + centre.x
			var q := Vector2(centre.x + cos(a) * 1.1, centre.y + sin(a) * 1.1)
			var f: Node3D = Atelier.figurant(g, "idle")
			f.position = Vector3(q.x, y, q.y) / U
			f.rotation.y = atan2(-cos(a), -sin(a))
			groupe.add_child(f)
			g += 1
	# deux lecteurs assis, sur un banc de chaque allée, et un couple sur le banc du bout, côté marronniers
	for b in [[Vector2(SQUARE.position.x + 4.9, 20.4), -PI * 0.5], [Vector2(SQUARE.end.x - 4.9, 30.6), PI * 0.5],
			[Vector2(SQUARE.position.x + 4.9, 35.5), -PI * 0.5], [Vector2(SQUARE.position.x + 4.9, 36.5), -PI * 0.5]]:
		var f: Node3D = Atelier.figurant(g, "sit")
		f.position = Vector3(b[0].x, y, b[0].y) / U
		f.rotation.y = b[1]
		groupe.add_child(f)
		g += 1
	# les promeneurs : les deux trottoirs, l'axe du square vers l'escalier, la traversée au sud
	var routes := [
		[Vector2(-8.0, 46.0), Vector2(-8.0, 20.0), Vector2(-8.0, -8.0)],
		[Vector2(27.5, -8.0), Vector2(27.5, 20.0), Vector2(27.5, 46.0)],
		[Vector2(BLANDAN.x, 40.0), Vector2(BLANDAN.x - 1.0, 22.0), Vector2(BLANDAN.x - 4.0, 13.0), Vector2(BLANDAN.x, 2.0), Vector2(BLANDAN.x, -8.0)],
		# la traversée au sud s'arrête avant le point de vue des marronniers (12, 49), à plus de 6 m
		[Vector2(-8.0, 48.0), Vector2(5.0, 48.5)],
		[Vector2(27.5, 48.0), Vector2(19.0, 48.5)],
		# les deux rues, dans les deux sens, et sur les trottoirs des terrasses
		[Vector2(-4.8, -6.0), Vector2(-4.6, 20.0), Vector2(-4.8, 46.0)],
		[Vector2(-9.0, 40.0), Vector2(-9.0, 12.0), Vector2(-9.2, -6.0)],
		[Vector2(-6.2, 30.0), Vector2(-6.0, 5.0)],
		[Vector2(26.0, 46.0), Vector2(26.2, 20.0), Vector2(26.0, -6.0)],
		[Vector2(28.4, 0.0), Vector2(28.5, 30.0), Vector2(28.2, 46.0)],
		[Vector2(26.8, 12.0), Vector2(27.0, 40.0)],
	]
	for k in routes.size():
		var route: Array[Vector3] = []
		for q in routes[k]:
			route.append(Vector3(q.x, hauteur(q.x, q.y), q.y) / U)
		var f: Node3D = Atelier.figurant(g, "walk", "village", route)
		f.position = route[0]
		groupe.add_child(f)
		g += 1


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
			var mur := _boite(e, Vector3(0.9, haut, za - zb + 0.02), Vector3(x, y0 + haut * 0.5, (za + zb) * 0.5), PIERRE_DOREE)
			mur.material_override = _materiau_appareil(PIERRE_DOREE.darkened(0.03 * (k / pas % 2)))
			_boite(e, Vector3(1.1, 0.14, za - zb + 0.06), Vector3(x, y0 + haut + 0.07, (za + zb) * 0.5), VILLEBOIS)
		for z in [z0, z1]:
			var yy := y0 if z == z0 else y1
			_boite(e, Vector3(1.2, 1.5, 1.2), Vector3(x, yy + 0.55 if z == z1 else y0 + 0.75, z - 0.6 if z == z0 else z + 0.6), PIERRE_DOREE).material_override = _materiau_appareil(PIERRE_DOREE)
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
		# la main courante de fer noir de chaque côté de la volée, sur ses potelets
		for bord in [-1.4, 1.4]:
			var ha := Vector3(x + bord, ya + 0.95, -50.0)
			var hb := Vector3(x + bord, yb + 0.95, -80.0)
			_segment(e, ha, hb, 0.03, Color("#23262a"), 0.5)
			for j in 11:
				var pz := lerpf(-50.0, -80.0, j / 10.0)
				var py := lerpf(ya, yb, j / 10.0)
				_segment(e, Vector3(x + bord, py, pz), Vector3(x + bord, py + 0.95, pz), 0.022, Color("#23262a"), 0.5)
	# entre les deux volées, le jardin en terrasses de la montée : une allée de sable au milieu, de part et
	# d'autre des planches de gazon tenues par une bordure de Villebois, des massifs fleuris au pied de chacune
	var sable := materiau_sable()
	for k in 10:
		var za := -50.0 - k * 3.0
		var zc := za - 1.5
		var yy := hauteur(10.0, zc)
		var allee := _boite(e, Vector3(3.0, 0.5, 3.02), Vector3(10.0, yy - 0.17, zc), Color.WHITE)
		allee.material_override = sable
		# le muret de pierre dorée au bord bas de chaque terrasse, du niveau de la terrasse d'en dessous jusqu'à
		# 45 cm au-dessus du gazon ; dans l'allée, une marche de Villebois
		var bas := hauteur(10.0, za + 1.5)
		var h_mur := yy + 0.18 - bas
		if h_mur > 0.05:
			_boite(e, Vector3(3.0, h_mur + 0.02, 0.4), Vector3(10.0, bas + h_mur * 0.5, za - 0.2), VILLEBOIS)
		for cote in [-1.0, 1.0]:
			var xg: float = 10.0 + cote * 3.2
			var mur := _boite(e, Vector3(3.4, h_mur + 0.45, 0.24), Vector3(xg, bas + (h_mur + 0.45) * 0.5, za - 0.12), PIERRE_DOREE)
			mur.material_override = _materiau_appareil(PIERRE_DOREE.darkened(0.03 * (k % 2)))
			# le chaperon étroit, de la pierre dorée du muret
			_boite(e, Vector3(3.44, 0.07, 0.28), Vector3(xg, bas + h_mur + 0.485, za - 0.12), Color("#d4b781"))
			_boite(e, Vector3(3.4, 0.6, 3.02), Vector3(xg, yy - 0.12, zc), Color("#5f7f35"))
			# l'herbe de la planche, en touffes, sur le fond vert
			_pose(VEGETATION, "plante", "herbe", Vector3(xg, yy + 0.18, zc), 860 + k * 2 + int(cote > 0.0), {"longueur": 3.3, "largeur": 2.9})
			_boite(e, Vector3(0.22, 0.75, 3.02), Vector3(10.0 + cote * 1.6, yy - 0.08, zc), VILLEBOIS)
			if k % 2 == 1:
				_pose(VEGETATION, "plante", "massif" if k % 4 == 1 else "buisson", Vector3(xg + cote * 0.4, yy + 0.18, zc), 820 + k * 2 + int(cote > 0.0), {"fleurs": ["f4f0e6", "e0605a", "d04a8a", "f2c14e"][(k + int(cote > 0.0)) % 4], "longueur": 2.4}, PI * 0.5)


# --- Les pièces uniques ---------------------------------------------------------------------------

var _sculptures := {}
const Sculpture := preload("res://communes/lyon/sculptures/sculpture.gd")


## Une sculpture modelée à part (sculptures/sculpter.py), lue une fois.
func _sculpture(nom: String) -> ArrayMesh:
	if not _sculptures.has(nom):
		_sculptures[nom] = Sculpture.maillage(DOSSIER + "sculptures/%s.bin" % nom)
	return _sculptures[nom]


func _bronze(sombre: Color, patine: Color) -> ShaderMaterial:
	return Sculpture.bronze(sombre, patine)


## Une forme simple (boîte, cylindre, sphère, capsule) sous parent, tournée par les angles a (radians) ;
## m ajoute le métal et le poli du bronze.
func _forme(parent: Node3D, mesh: Mesh, p: Vector3, c: Color, a := Vector3.ZERO, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := materiau(c, 0.38 if metal > 0.0 else 0.88)
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


## La pierre appareillée des murs d'échiffre et des dés de l'escalier : des assises de 42 cm, des blocs de
## 90 cm à joints décalés, chacun d'une nuance ; le dessus reste lisse. En coordonnées du monde (unités de 2,4 m).
var _appareils := {}
func _materiau_appareil(c: Color) -> ShaderMaterial:
	if _appareils.has(c):
		return _appareils[c]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 teinte : source_color;
varying vec3 w;
varying vec3 n;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * 2.4;
	n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 c = teinte.rgb;
	if (abs(n.y) < 0.7) {
		float a = abs(n.x) > abs(n.z) ? w.z : w.x;
		float rang = floor(w.y / 0.42);
		a += rang * 0.45;
		vec2 f = vec2(fract(a / 0.9), fract(w.y / 0.42));
		float joint = smoothstep(0.0, 0.04, f.x) * smoothstep(1.0, 0.96, f.x) * smoothstep(0.0, 0.08, f.y) * smoothstep(1.0, 0.92, f.y);
		c *= (0.9 + 0.16 * hash(vec2(floor(a / 0.9), rang))) * mix(0.62, 1.0, joint);
	}
	ALBEDO = c;
	ROUGHNESS = 0.88;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("teinte", c)
	_appareils[c] = m
	return m


## La mairie du 1er, pièce unique comme Blandan : sur la façade d'hôtel du façadier, un avant-corps de pierre
## claire, quatre pilastres d'ordre ionique sur un rez-de-chaussée à refends, l'entablement, le fronton
## triangulaire et son horloge, le balcon d'honneur et la porte cintrée. m : l'immeuble (façade en z = 0, devant
## vers +Z), w : sa largeur.
func _mairie(m: Node3D, w: float) -> void:
	var pierre := Color("#ddd2b8")
	var ombre := pierre.darkened(0.12)
	var l := minf(w * 0.45, 11.0)
	var rdc := 4.2
	var corniche: float = m.get_meta("hauteur", 16.0) - 3.0
	corniche = clampf(corniche, 12.0, 16.0)
	# l'avant-corps, et les refends du rez-de-chaussée
	_boite(m, Vector3(l, corniche, 0.5), Vector3(0, corniche * 0.5, 0.25), pierre).material_override = _materiau_appareil(pierre)
	for k in 6:
		_boite(m, Vector3(l + 0.04, 0.06, 0.06), Vector3(0, 0.7 * (k + 1), 0.52), ombre)
	# les quatre pilastres, leurs bases et leurs chapiteaux à volutes
	for j in 4:
		var x := lerpf(-l * 0.5 + 0.6, l * 0.5 - 0.6, j / 3.0)
		_boite(m, Vector3(0.62, corniche - rdc - 0.6, 0.22), Vector3(x, (rdc + corniche) * 0.5, 0.6), pierre.lightened(0.05))
		_boite(m, Vector3(0.8, 0.3, 0.3), Vector3(x, rdc + 0.15, 0.62), ombre)
		_boite(m, Vector3(0.86, 0.32, 0.32), Vector3(x, corniche - 0.45, 0.64), pierre.lightened(0.08))
		for cote in [-1.0, 1.0]:
			_boite(m, Vector3(0.12, 0.22, 0.22), Vector3(x + cote * 0.42, corniche - 0.5, 0.72), ombre)
	# les hautes fenêtres de l'avant-corps, trois travées entre les pilastres, à chambranle et à fronton plat
	var etages := int((corniche - rdc - 0.8) / 3.3)
	for j in 3:
		var x := lerpf(-l * 0.5 + 0.6, l * 0.5 - 0.6, (j + 0.5) / 3.0)
		for e in etages:
			var yb := rdc + 0.9 + e * 3.3
			_boite(m, Vector3(1.4, 2.5, 0.06), Vector3(x, yb + 1.15, 0.52), pierre.lightened(0.08))
			_boite(m, Vector3(1.1, 2.2, 0.08), Vector3(x, yb + 1.1, 0.54), Color("#2c3640"))
			_boite(m, Vector3(1.7, 0.18, 0.3), Vector3(x, yb + 2.5, 0.6), ombre)
	# l'entablement : architrave, frise, corniche saillante
	_boite(m, Vector3(l + 0.3, 0.35, 0.75), Vector3(0, corniche + 0.1, 0.4), pierre)
	_boite(m, Vector3(l + 0.3, 0.45, 0.6), Vector3(0, corniche + 0.5, 0.35), pierre.lightened(0.04))
	_boite(m, Vector3(l + 0.8, 0.22, 1.1), Vector3(0, corniche + 0.84, 0.5), ombre)
	# le fronton triangulaire, son rampant mouluré et l'horloge du tympan
	var haut := l * 0.22
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := corniche + 0.95
	var g := Vector3(-l * 0.5 - 0.2, b, 0.9)
	var d := Vector3(l * 0.5 + 0.2, b, 0.9)
	var s := Vector3(0, b + haut, 0.9)
	var arriere := Vector3(0, 0, -1.2)
	for tri in [[g, d, s], [g + arriere, s + arriere, d + arriere], [g, s, s + arriere], [g, s + arriere, g + arriere], [d, d + arriere, s + arriere], [d, s + arriere, s]]:
		var nn: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		for q in tri:
			st.set_normal(nn)
			st.add_vertex(q)
	var fronton := MeshInstance3D.new()
	fronton.mesh = st.commit()
	fronton.material_override = materiau(pierre)
	fronton.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.add_child(fronton)
	var pente := atan2(haut, l * 0.5 + 0.2)
	for cote in [-1.0, 1.0]:
		var r := _boite(m, Vector3(sqrt(pow(l * 0.5 + 0.2, 2) + haut * haut) + 0.3, 0.24, 1.3), Vector3(cote * (l * 0.25 + 0.1), b + haut * 0.5 + 0.1, 0.4), ombre)
		r.rotation.z = -cote * pente
	# le cadran rond, blanc dans sa bague dorée, et ses deux aiguilles
	var hc := b + haut * 0.42
	_forme(m, _cyl(0.82, 0.82, 0.08, 32), Vector3(0, hc, 0.93), Color("#9c7f3c"), Vector3(PI * 0.5, 0, 0), 0.6)
	_forme(m, _cyl(0.7, 0.7, 0.06, 32), Vector3(0, hc, 0.98), Color("#f6f2e6"), Vector3(PI * 0.5, 0, 0))
	_boite(m, Vector3(0.07, 0.5, 0.03), Vector3(0, hc + 0.2, 1.03), Color("#2a2a2a"))
	_boite(m, Vector3(0.36, 0.07, 0.03), Vector3(0.16, hc, 1.03), Color("#2a2a2a"))
	# le balcon d'honneur sur consoles, et la porte cintrée sous lui
	_boite(m, Vector3(l * 0.42, 0.18, 1.0), Vector3(0, rdc + 0.1, 0.9), pierre)
	_boite(m, Vector3(l * 0.42, 0.85, 0.05), Vector3(0, rdc + 0.6, 1.38), Color("#24282a"))
	for cote in [-1.0, 1.0]:
		_boite(m, Vector3(0.3, 0.5, 0.6), Vector3(cote * l * 0.17, rdc - 0.25, 0.75), ombre)
	_boite(m, Vector3(2.0, 3.0, 0.1), Vector3(0, 1.5, 0.52), Color("#3b2a20"))
	var arc := _boite(m, Vector3(1.4, 1.4, 0.1), Vector3(0, 3.0, 0.52), Color("#3b2a20"))
	arc.rotation.z = PI * 0.25
	_boite(m, Vector3(2.6, 0.3, 0.2), Vector3(0, 3.65, 0.6), pierre.lightened(0.05))
	# le drapeau
	_boite(m, Vector3(0.05, 2.2, 0.05), Vector3(l * 0.18, rdc + 1.4, 1.6), Color("#2a2a2a")).rotation.x = 0.5
	var drapeau := Node3D.new()
	drapeau.position = Vector3(l * 0.18, rdc + 2.2, 2.05)
	m.add_child(drapeau)
	for k in 3:
		_boite(drapeau, Vector3(0.05, 0.9, 0.42), Vector3(0, -0.35, 0.21 + 0.42 * k), [Color("#24408e"), Color("#f4f1ea"), Color("#c8102e")][k])


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
	var vert := Color("#4a4a35")
	var vert_clair := Color("#5f6b4e")
	# la plaque de bronze sur le dé, à cadre mouluré et lettres en relief, polies par la patine
	_forme(s, _blo(Vector3(1.0, 0.7, 0.03)), Vector3(0, 2.2, 0.965), vert.darkened(0.2), Vector3.ZERO, 0.5).material_override = _bronze(vert.darkened(0.2), vert)
	_forme(s, _blo(Vector3(0.88, 0.58, 0.03)), Vector3(0, 2.2, 0.98), vert, Vector3.ZERO, 0.5).material_override = _bronze(vert, vert_clair)
	var lettres := Label3D.new()
	lettres.text = "AU SERGENT\nBLANDAN\n1842"
	lettres.font_size = 40
	lettres.pixel_size = 0.0042
	lettres.outline_size = 0
	lettres.modulate = Color("#b9b07a")
	lettres.shaded = true
	lettres.double_sided = false
	lettres.position = Vector3(0, 2.2, 0.997)
	s.add_child(lettres)
	# le soldat (2,8 m), modelé à part (sculptures/sculpter.py), sur sa terrasse de bronze, face à la place
	_forme(s, _sculpture("blandan"), Vector3(0, 3.56, 0), vert, Vector3.ZERO, 0.55).material_override = _bronze(vert, vert_clair)


## Une des deux fontaines aux lions (fonderie du Creusot, 1823) au pied de la montée : le lion de bronze
## couché sur son socle mouluré de pierre dorée, tourné vers l'axe de l'escalier, la gueule qui crache
## dans une vasque à margelle de Villebois, la mousse au bas de la pierre. sens : -1 à l'ouest, 1 à l'est.
func _fontaine_lion(f: Node3D, _sens: float) -> void:
	# la pierre grise et froide de la fontaine, comme sur la planche, et non la pierre dorée des murs
	var dore := Color("#aaa69a")
	var z := -0.55
	# le socle de pierre grise, bas et mouluré : une plinthe, un dé à tables saillantes et chanfreins, une
	# corniche à trois ressauts, la tablette où se couche le lion ; un tablier demi-rond avance dans la vasque
	_forme(f, _blo(Vector3(2.1, 0.3, 1.4)), Vector3(0, 0.15, z), dore.darkened(0.12))
	_forme(f, _blo(Vector3(1.95, 0.08, 1.3)), Vector3(0, 0.34, z), dore.darkened(0.05))
	_forme(f, _blo(Vector3(1.8, 1.0, 1.15)), Vector3(0, 0.88, z), dore)
	for c in [-1.0, 1.0]:
		_forme(f, _blo(Vector3(0.16, 1.0, 1.17)), Vector3(c * 0.86, 0.88, z), dore.lightened(0.05))
	_forme(f, _blo(Vector3(1.1, 0.6, 0.05)), Vector3(0, 0.9, z + 0.58), dore.lightened(0.08))
	var tablier := _forme(f, _cyl(0.55, 0.62, 0.62, 24), Vector3(0, 0.66, z + 0.55), dore.darkened(0.03))
	tablier.scale = Vector3(1.0, 1.0, 0.55)
	for k in 3:
		_forme(f, _blo(Vector3(1.86 + k * 0.1, 0.09, 1.21 + k * 0.1)), Vector3(0, 1.42 + k * 0.09, z), dore.darkened(0.04 * k))
	_forme(f, _blo(Vector3(1.7, 0.1, 1.1)), Vector3(0, 1.72, z), dore.darkened(0.08))
	# la vasque demi-ronde de Villebois au pied, sa margelle moulurée, l'eau, la mousse au ras du sol
	var vasque := _forme(f, _cyl(1.6, 1.4, 0.7, 40), Vector3(0, 0.35, z + 0.7), VILLEBOIS.darkened(0.06))
	vasque.scale = Vector3(1.0, 1.0, 0.75)
	var margelle := TorusMesh.new()
	margelle.inner_radius = 1.45
	margelle.outer_radius = 1.75
	margelle.rings = 32
	margelle.ring_segments = 8
	_forme(f, margelle, Vector3(0, 0.72, z + 0.7), VILLEBOIS).scale = Vector3(1.0, 0.9, 0.75)
	_forme(f, _cyl(1.47, 1.47, 0.04, 40), Vector3(0, 0.64, z + 0.7), EAU.lightened(0.25)).scale = Vector3(1.0, 1.0, 0.75)
	# le tore du pied et le listel sous la margelle : la vasque se lit moulurée, pas tournée d'un bloc
	for anneau in [[1.38, 1.68, 0.1, 0.92], [1.42, 1.62, 0.5, 0.6]]:
		var tore := TorusMesh.new()
		tore.inner_radius = anneau[0]
		tore.outer_radius = anneau[1]
		tore.rings = 32
		tore.ring_segments = 8
		_forme(f, tore, Vector3(0, anneau[2], z + 0.7), VILLEBOIS.darkened(0.1)).scale = Vector3(1.0, anneau[3], 0.75)
	_forme(f, _cyl(1.62, 1.66, 0.1, 40), Vector3(0, 0.05, z + 0.7), Color("#5d6b45")).scale = Vector3(1.0, 1.0, 0.75)
	var bronze := Color("#4d4a36")
	var clair := Color("#66705a")
	var sombre := bronze.darkened(0.25)
	var m := 0.65
	var l := Node3D.new()
	l.position = Vector3(0, 1.77, -0.6)
	l.scale = Vector3.ONE * 1.25
	f.add_child(l)
	# le lion couché, face à la place, modelé à part (sculptures/sculpter.py)
	_forme(l, _sculpture("lion"), Vector3.ZERO, bronze).material_override = _bronze(bronze, clair)
	# le filet d'eau de la gueule à la vasque, en arc
	var eau := materiau(Color("#cfe3e6"), 0.05)
	eau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eau.albedo_color.a = 0.65
	var avant := Vector3(0, 0.7, 0.9)
	for k in range(1, 11):
		var t := k / 10.0
		var q := Vector3(0, 0.7 + t * 0.12 - t * t * 1.71, 0.9 + t * 0.42)
		var jet := _segment(l, avant, q, 0.03 + t * 0.012, Color.WHITE)
		jet.mesh = _cyl(0.03 + t * 0.012, 0.03 + t * 0.012, avant.distance_to(q) + 0.02, 8)
		jet.material_override = eau
		avant = q


func _boite(parent: Node3D, taille: Vector3, p: Vector3, c: Color, inclinaison := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = materiau(c)
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


## La vie du parcours, du quai à la place : des passants sur les deux trottoirs de la rue de la Martinière et de
## la rue Louis-Vitet, des voitures garées le long d'une bordure, une qui roule au pas.
const PARCOURS := [Vector2(-149.0, 114.0), Vector2(-30.0, 114.0), Vector2(68.0, 117.0), Vector2(34.0, 57.0), Vector2(14.0, 44.0)]

func _parcours() -> void:
	var alea := RandomNumberGenerator.new()
	alea.seed = 1830
	var groupe := Node3D.new()
	groupe.name = "Passants"
	add_child(groupe)
	var g := 91000
	var longueur := 0.0
	for i in PARCOURS.size() - 1:
		longueur += PARCOURS[i].distance_to(PARCOURS[i + 1])
	# un point du parcours à l'abscisse d, et la direction de la rue
	var sur := func(d: float) -> Array:
		var reste := d
		for i in PARCOURS.size() - 1:
			var a: Vector2 = PARCOURS[i]
			var b: Vector2 = PARCOURS[i + 1]
			var l := a.distance_to(b)
			if reste <= l or i == PARCOURS.size() - 2:
				return [a.lerp(b, clampf(reste / l, 0.0, 1.0)), (b - a).normalized()]
			reste -= l
		return [PARCOURS[0], Vector2.RIGHT]
	# un passant qui monte l'allée du jardin, à une dizaine de mètres du pied de la montée : deux pas de terrasse
	# seulement, pour qu'on l'y trouve encore quand on regarde
	var montee: Array[Vector3] = []
	for zc in [-57.2, -58.8]:
		montee.append(Vector3(10.6, hauteur(10.0, zc) + 0.08, zc) / U)
	var fm: Node3D = Atelier.figurant(g, "walk", "village", montee)
	fm.position = montee[0]
	groupe.add_child(fm)
	g += 1
	# les passants : chacun marche une quarantaine de mètres sur un trottoir, dans un sens ou dans l'autre
	for k in 22:
		var d0 := alea.randf_range(10.0, longueur - 50.0)
		var cote := -1.0 if k % 2 == 0 else 1.0
		var route: Array[Vector3] = []
		for e in 4:
			var pt: Array = sur.call(d0 + e * 13.0)
			var q: Vector2 = pt[0] + (pt[1] as Vector2).orthogonal() * cote * alea.randf_range(3.4, 4.2)
			route.append(Vector3(q.x, hauteur(q.x, q.y), q.y) / U)
		if k % 3 == 0:
			route.reverse()
		# pas de passant collé à l'objectif d'un point de vue : il mangerait le cadre
		var trop_pres := false
		for oeil in [Vector2(-76.0, 118.6), Vector2(-30.1, 117.0), Vector2(68.0, 116.0), Vector2(34.0, 57.0)]:
			if (Vector2(route[0].x, route[0].z) * U).distance_to(oeil) < 6.0:
				trop_pres = true
		if trop_pres:
			continue
		var f: Node3D = Atelier.figurant(g, "walk", "village", route)
		f.position = route[0]
		groupe.add_child(f)
		g += 1
	# quelques-uns qui s'arrêtent pour causer, devant une vitrine
	for k in 4:
		var pt: Array = sur.call(alea.randf_range(30.0, longueur - 30.0))
		var c: Vector2 = pt[0] + (pt[1] as Vector2).orthogonal() * 4.0 * (1.0 if k % 2 == 0 else -1.0)
		for j in 2:
			var q := c + (pt[1] as Vector2) * (j - 0.5) * 1.1
			var f: Node3D = Atelier.figurant(g, "idle")
			f.position = Vector3(q.x, hauteur(q.x, q.y), q.y) / U
			f.rotation.y = atan2(-(pt[1] as Vector2).x, -(pt[1] as Vector2).y) * (1.0 if j == 0 else -1.0)
			groupe.add_child(f)
			g += 1
	# un couple qui cause sur le trottoir de la Martinière, à quelques pas du point de vue
	for q in [Vector2(-70.6, 118.2), Vector2(-70.4, 119.4)]:
		var f: Node3D = Atelier.figurant(g, "idle")
		f.position = Vector3(q.x, hauteur(q.x, q.y) + 0.1, q.y) / U
		f.rotation.y = 0.0 if q.y < 118.8 else PI
		groupe.add_child(f)
		g += 1
	# dans le champ de la Vue1b : une voiture garée à dix mètres le long de la halle, un passant sur le trottoir d'en face
	var vue := Vector2(-76.0, 118.6)
	var regard := (Vector2(-36.0, 101.0) - vue).normalized()
	var cible := vue + regard * 10.0
	var proche_v := -1
	var ecart_v := 1e9
	for c in _chaussees.size():
		var e: float = Geometry2D.get_closest_point_to_segment(cible, _chaussees[c][0], _chaussees[c][1]).distance_to(cible)
		if e < ecart_v:
			ecart_v = e
			proche_v = c
	if proche_v >= 0:
		var sa: Vector2 = _chaussees[proche_v][0]
		var sb: Vector2 = _chaussees[proche_v][1]
		var tv := (sb - sa).normalized()
		var cote_halle := tv.orthogonal()
		if cote_halle.dot(Vector2(-42.0, 97.0) - cible) < 0.0:
			cote_halle = -cote_halle
		var pied := Geometry2D.get_closest_point_to_segment(cible, sa, sb)
		var qv: Vector2 = pied + cote_halle * (float(_chaussees[proche_v][2]) - 1.05)
		var vo: Node3D = load(Bibliotheque.scene("voitures-des-annees-80@1", "decor")).instantiate()
		vo.voiture = "berline"
		vo.graine = 290
		vo.options = {"couleur": "2c4a7a"}
		vo.position = Vector3(qv.x, hauteur(qv.x, qv.y) + 0.06, qv.y)
		vo.rotation.y = atan2(tv.x, tv.y)
		ville.add_child(vo)
		# le passant, sur le trottoir de la halle, qui vient vers nous
		var route: Array[Vector3] = []
		for e in 4:
			var q: Vector2 = pied + tv * (18.0 - e * 6.0) * (1.0 if tv.dot(regard) > 0.0 else -1.0) + cote_halle * (float(_chaussees[proche_v][2]) + 2.2)
			route.append(Vector3(q.x, hauteur(q.x, q.y), q.y) / U)
		var fp: Node3D = Atelier.figurant(g, "walk", "village", route)
		fp.position = route[0]
		groupe.add_child(fp)
		g += 1
	# les voitures garées le long de la bordure droite, par paquets, et une qui roule au milieu
	var d := 18.0
	var n := 0
	while d < longueur - 20.0:
		var pt: Array = sur.call(d)
		# garée contre la bordure de la vraie chaussée la plus proche, dans son axe ; pas de voiture dans les
		# rues piétonnes
		var proche := -1
		var ecart := 1e9
		for c in _chaussees.size():
			var e: float = Geometry2D.get_closest_point_to_segment(pt[0], _chaussees[c][0], _chaussees[c][1]).distance_to(pt[0])
			if e < ecart:
				ecart = e
				proche = c
		var garable := proche >= 0 and ecart < float(_chaussees[proche][2]) + 2.5 and float(_chaussees[proche][2]) >= 2.4
		var t := Vector2.RIGHT
		var q: Vector2 = pt[0]
		if garable:
			var sa: Vector2 = _chaussees[proche][0]
			var sb: Vector2 = _chaussees[proche][1]
			t = (sb - sa).normalized()
			if t.dot(pt[1]) < 0.0:
				t = -t
			q = Geometry2D.get_closest_point_to_segment(pt[0], sa, sb) + t.orthogonal() * -(float(_chaussees[proche][2]) - 1.05)
		# pas de voiture dans les pieds d'un point de vue : elle mangerait la moitié du cadre
		for oeil in [Vector2(-76.0, 118.6), Vector2(-30.0, 114.0), Vector2(68.0, 116.0), Vector2(34.0, 57.0)]:
			if q.distance_to(oeil) < 7.0:
				garable = false
		if garable and alea.randf() < 0.7:
			var vo: Node3D = load(Bibliotheque.scene("voitures-des-annees-80@1", "decor")).instantiate()
			vo.voiture = ["citadine", "compacte", "berline", "break", "citadine", "fourgonnette"][alea.randi() % 6]
			vo.graine = 300 + n
			vo.options = {"couleur": ["efe9dc", "c8102e", "6b1d24", "d9b44a", "8fb3c9", "2c4a7a", "2f5d3a", "b7ab8f", "8d9196"][alea.randi() % 9]}
			vo.position = Vector3(q.x, hauteur(q.x, q.y) + 0.06, q.y)
			vo.rotation.y = atan2(t.x, t.y)
			ville.add_child(vo)
			n += 1
		d += alea.randf_range(5.2, 6.5) if alea.randf() < 0.8 else 14.0
	# rues Rambaud et Louis-Vitet : une file de quatre voitures contre la bordure gauche, de 9 à 26 m devant le
	# point de vue, et deux passants qui viennent vers nous, un sur chaque trottoir
	for vue_r in [[Vector2(-30.0, 114.0), Vector2(68.0, 118.0)], [Vector2(68.0, 116.0), Vector2(34.0, 57.0)]]:
		var o: Vector2 = vue_r[0]
		var dir: Vector2 = (vue_r[1] - o).normalized()
		for m in 8:
			# 0 à 3 : les voitures ; 4 et 5 : les passants au loin ; 6 : un passant à 7 m sur le trottoir du point de
			# vue ; 7 : le passage piéton à 38 m, sur Rambaud seulement
			var cible_r := o + dir * (9.0 + m * 5.6)
			if m == 6:
				cible_r = o + dir * 7.0
			elif m == 7:
				cible_r = o + dir * 38.0
			var pc := -1
			var ec := 1e9
			for c in _chaussees.size():
				var e: float = Geometry2D.get_closest_point_to_segment(cible_r, _chaussees[c][0], _chaussees[c][1]).distance_to(cible_r)
				if e < ec:
					ec = e
					pc = c
			if pc < 0 or float(_chaussees[pc][2]) < 2.4 or ec > float(_chaussees[pc][2]) + 2.5:
				continue
			var sa: Vector2 = _chaussees[pc][0]
			var sb: Vector2 = _chaussees[pc][1]
			var t := (sb - sa).normalized()
			if t.dot(dir) < 0.0:
				t = -t
			var pied := Geometry2D.get_closest_point_to_segment(cible_r, sa, sb)
			var lw := float(_chaussees[pc][2])
			if m < 4:
				var q := pied + t.orthogonal() * (lw - 1.05)
				var vo: Node3D = load(Bibliotheque.scene("voitures-des-annees-80@1", "decor")).instantiate()
				vo.voiture = ["compacte", "citadine", "break", "berline"][(m + n) % 4]
				vo.graine = 400 + n
				vo.options = {"couleur": ["8d9196", "c8102e", "efe9dc", "2f5d3a", "d9b44a", "6b1d24"][(m * 2 + n) % 6]}
				vo.position = Vector3(q.x, hauteur(q.x, q.y) + 0.06, q.y)
				vo.rotation.y = atan2(t.x, t.y)
				ville.add_child(vo)
				n += 1
			elif m == 7:
				if vue_r[0].x > 0.0:
					continue
				var ang := atan2(t.x, t.y)
				var nbb := int(floor((lw * 2.0 - 0.6) / 0.9))
				for k in nbb:
					var qz: Vector2 = pied + t.orthogonal() * (-lw + 0.6 + k * 0.9)
					var bande := _boite(ville, Vector3(0.5, 0.02, 3.0), Vector3(qz.x, hauteur(qz.x, qz.y) + 0.03, qz.y), Color("#ece8de"))
					bande.rotation.y = ang
			else:
				var cote_r := 1.0 if m == 4 else -1.0
				var route: Array[Vector3] = []
				for e in 4:
					var qr: Vector2 = pied + t * (6.0 - e * 6.0) + t.orthogonal() * cote_r * (lw + 2.0)
					if m == 6:
						# il s'éloigne devant nous, sur notre trottoir
						qr = pied + t * (e * 6.0) - t.orthogonal() * (lw + 1.6)
					route.append(Vector3(qr.x, hauteur(qr.x, qr.y), qr.y) / U)
				var fr: Node3D = Atelier.figurant(g, "walk", "village", route)
				fr.position = route[0]
				groupe.add_child(fr)
				g += 1


## Le quai habité, autour du point de vue : des promeneurs sur les dalles, dans les deux sens, et quelques-uns
## accoudés au parapet qui regardent l'eau ; les voitures garées le long de la rue du quai, de l'autre côté
## des platanes.
func _quai_habite() -> void:
	if _quai_modules.size() < 8:
		return
	var alea := RandomNumberGenerator.new()
	alea.seed = 1906
	var groupe := Node3D.new()
	groupe.name = "PassantsDuQuai"
	add_child(groupe)
	var g := 93000
	var nb: int = _quai_modules.size()
	# les promeneurs : chacun suit le quai sur une trentaine de mètres, entre le parapet et les platanes
	for k in 14:
		var m0 := alea.randi_range(0, nb - 9)
		var ecart := alea.randf_range(2.4, 4.0)
		var route: Array[Vector3] = []
		for e in 4:
			var mod: Array = _quai_modules[mini(m0 + e * 2, nb - 1)]
			var q: Vector2 = mod[0] - mod[1] * ecart
			route.append(Vector3(q.x, mod[2], q.y) / U)
		if k % 2 == 0:
			route.reverse()
		var c0: Vector2 = Vector2(route[0].x, route[0].z) * U
		if c0.distance_to(QUAI_VUE) < 4.0:
			continue
		var f: Node3D = Atelier.figurant(g, "walk", "village", route)
		f.position = route[0]
		groupe.add_child(f)
		g += 1
	# accoudés au parapet, seuls ou à deux, tournés vers la Saône
	for k in 5:
		var mod: Array = _quai_modules[alea.randi_range(2, nb - 3)]
		var c: Vector2 = mod[0]
		if c.distance_to(QUAI_VUE) < 6.0:
			continue
		var t := Vector2(mod[1].y, -mod[1].x)
		for j in (2 if k % 2 == 0 else 1):
			var q: Vector2 = c - mod[1] * 0.85 + t * (j * 0.8)
			var f: Node3D = Atelier.figurant(g, "idle")
			f.position = Vector3(q.x, mod[2], q.y) / U
			f.rotation.y = atan2(mod[1].x, mod[1].y)
			groupe.add_child(f)
			g += 1
	# dans le champ de la Vue1a : un banc à dix mètres, deux accoudés juste après, un troisième à vingt mètres
	var module_pres := func(q: Vector2) -> Array:
		var meilleur: Array = _quai_modules[0]
		for mod in _quai_modules:
			if (mod[0] as Vector2).distance_to(q) < (meilleur[0] as Vector2).distance_to(q):
				meilleur = mod
		return meilleur
	var depart: Array = module_pres.call(VUE1A_OEIL)
	var tq := Vector2(depart[1].y, -depart[1].x)
	if tq.dot(VUE1A_REGARD) < 0.0:
		tq = -tq
	var mb: Array = module_pres.call(depart[0] + tq * 10.0)
	var pb: Vector2 = mb[0] - mb[1] * 1.7
	_pose(MOBILIER, "objet", "banc", Vector3(pb.x, mb[2], pb.y), 1290, {}, atan2(mb[1].x, mb[1].y))
	for ecart in [12.5, 13.3, 21.0]:
		var ma: Array = module_pres.call(depart[0] + tq * ecart)
		var qa: Vector2 = ma[0] - ma[1] * 0.85
		var f: Node3D = Atelier.figurant(g, "idle")
		f.position = Vector3(qa.x, ma[2], qa.y) / U
		f.rotation.y = atan2(ma[1].x, ma[1].y)
		groupe.add_child(f)
		g += 1
	# dans le champ du retour : un promeneur qui s'éloigne sur les dalles, à huit mètres et plus de l'œil
	var retour: Array[Vector3] = []
	var dos := -VUE1A_REGARD
	for ecart in [9.0, 15.0, 22.0, 30.0]:
		var qr: Vector2 = VUE1A_OEIL + dos * ecart + Vector2(-dos.y, dos.x) * ecart * 0.62
		retour.append(Vector3(qr.x, maxf(hauteur(qr.x, qr.y), float(depart[2])), qr.y) / U)
	var promeneur: Node3D = Atelier.figurant(g, "walk", "village", retour)
	promeneur.position = retour[0]
	groupe.add_child(promeneur)
	g += 1
	# les voitures de la rue du quai, garées contre la bordure côté platanes, quand une vraie chaussée y passe
	var n := 0
	var m := 1
	while m < nb:
		var mod: Array = _quai_modules[m]
		var pt: Vector2 = mod[0] - mod[1] * 9.0
		var proche := -1
		var ecart := 1e9
		for c in _chaussees.size():
			var e: float = Geometry2D.get_closest_point_to_segment(pt, _chaussees[c][0], _chaussees[c][1]).distance_to(pt)
			if e < ecart:
				ecart = e
				proche = c
		if proche >= 0 and ecart < float(_chaussees[proche][2]) + 2.0 and float(_chaussees[proche][2]) >= 2.4 and alea.randf() < 0.75:
			var sa: Vector2 = _chaussees[proche][0]
			var sb: Vector2 = _chaussees[proche][1]
			var t := (sb - sa).normalized()
			var pied := Geometry2D.get_closest_point_to_segment(pt, sa, sb)
			# du côté de l'eau, contre la bordure
			var cote := t.orthogonal()
			if cote.dot(mod[1]) < 0.0:
				cote = -cote
			var q := pied + cote * (float(_chaussees[proche][2]) - 1.05)
			var vo: Node3D = load(Bibliotheque.scene("voitures-des-annees-80@1", "decor")).instantiate()
			vo.voiture = ["citadine", "compacte", "berline", "break", "citadine", "fourgonnette"][alea.randi() % 6]
			vo.graine = 400 + n
			vo.options = {"couleur": ["efe9dc", "c8102e", "6b1d24", "d9b44a", "8fb3c9", "2c4a7a", "2f5d3a", "b7ab8f", "8d9196"][alea.randi() % 9]}
			vo.position = Vector3(q.x, hauteur(q.x, q.y) + 0.06, q.y)
			vo.rotation.y = atan2(t.x, t.y)
			ville.add_child(vo)
			n += 1
		m += 2


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
	var vert := Color("#5a6236")
	for j in n + 1:
		for i in n + 1:
			var x := o.x + taille * i / n
			var z := o.z + taille * j / n
			var y := _colline(x, z)
			var t := clampf(y / 130.0, 0.0, 1.0)
			# les bois en taches sombres, les prés et les jardins plus clairs entre eux
			var c := vert.lerp(Color("#2f4a24"), _rng.randf() * 0.8).lerp(Color("#7d8a55"), _rng.randf() * 0.25).darkened(0.1 * (1.0 - t))
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
	# les bois de la colline, peints sur la pente : des couronnes de dix mètres, claires dessus, sombres entre
	var sh_colline := Shader.new()
	sh_colline.code = """
shader_type spatial;
render_mode diffuse_burley;
varying vec3 monde;
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * 2.4; }
vec2 h2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
void fragment() {
	vec2 p = monde.xz / 24.0;
	vec2 i = floor(p);
	float d = 9.0;
	float teinte = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = h2(i + g);
			float dd = length(g + o - fract(p));
			if (dd < d) { d = dd; teinte = o.x; }
		}
	}
	float couronne = smoothstep(0.8, 0.35, d);
	vec3 sombre = pow(vec3(0.11, 0.17, 0.09), vec3(2.2));
	vec3 clair = pow(mix(vec3(0.40, 0.52, 0.24), vec3(0.55, 0.60, 0.30), teinte), vec3(2.2));
	ALBEDO = mix(sombre, clair, couronne) * mix(vec3(1.0), pow(COLOR.rgb, vec3(2.2)) * 3.0, 0.25);
	ROUGHNESS = 1.0;
	// pas de reflet : face au soleil couchant, le lustre rasant blanchirait toute la pente
	SPECULAR = 0.0;
}
"""
	var mat_colline := ShaderMaterial.new()
	mat_colline.shader = sh_colline
	mi.material_override = mat_colline
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(mi)
	# les toits et les murs de terrasses sur la pente qui regarde la Saône
	for k in 260:
		var x := FOURVIERE.x + _rng.randf_range(-520.0, 420.0)
		var z := FOURVIERE.z + _rng.randf_range(-560.0, 380.0)
		var y := _colline(x, z)
		# les maisons tiennent le bas de la pente ; au-dessus, ce sont les bois et les jardins
		if y < 8.0 or y > 70.0 or (x - FOURVIERE.x) > 260.0 + (FOURVIERE.z - z) * 0.2:
			continue
		var w := _rng.randf_range(10.0, 22.0)
		var h := _rng.randf_range(9.0, 18.0)
		var c := Color(ENDUITS_PLACE[k % ENDUITS_PLACE.size()]).lightened(0.05)
		_boite(f, Vector3(w, h, w * 0.8), Vector3(x, y + h * 0.5 - 2.0, z), c)
		_boite(f, Vector3(w + 0.8, 1.6, w * 0.8 + 0.8), Vector3(x, y + h - 1.2, z), Color(TUILES[k % TUILES.size()]))
	# les bois et les jardins du Rosaire qui tiennent la pente : des touffes sombres serrées, plus claires au soleil
	var bois := MultiMesh.new()
	bois.transform_format = MultiMesh.TRANSFORM_3D
	bois.use_colors = true
	var touffe := SphereMesh.new()
	touffe.radius = 1.0
	touffe.height = 1.6
	# à deux cents mètres et plus, six côtés et trois rangs suffisent à la touffe
	touffe.radial_segments = 6
	touffe.rings = 3
	bois.mesh = touffe
	var touffes: Array = []
	for k in 16000:
		var x := FOURVIERE.x + _rng.randf_range(-560.0, 460.0)
		var z := FOURVIERE.z + _rng.randf_range(-600.0, 420.0)
		var y := _colline(x, z)
		if y < 6.0:
			continue
		# plus serré sur la pente qui regarde la Saône, plus clair près du sommet
		if _rng.randf() > 0.5 + clampf((x - FOURVIERE.x) / 400.0, 0.0, 0.45):
			continue
		var r := _rng.randf_range(8.0, 15.0)
		var c := Color(["2f4a24", "3a5a2a", "466a30", "4f7434", "5d7f3a"][_rng.randi() % 5])
		c = c.lightened(clampf(y / 160.0, 0.0, 1.0) * 0.12)
		touffes.append([Transform3D(Basis().scaled(Vector3(r, r * 0.85, r)), Vector3(x, y + r * 0.8, z)), c])
	# et le pied de la colline, dans le relevé même, de l'autre côté de la Saône : les pentes boisées au-dessus
	# des quais de Pierre-Scize et de Saint-Paul
	for k in 9000:
		var x := _rng.randf_range(_x0, -120.0)
		var z := _rng.randf_range(190.0, _z0 + _nz * _pas)
		var y := hauteur(x, z)
		if y < 12.0 or _reserve(Vector2(x, z)):
			continue
		var r := _rng.randf_range(6.0, 11.0)
		var c := Color(["2f4a24", "3a5a2a", "466a30", "4f7434", "5d7f3a"][_rng.randi() % 5])
		touffes.append([Transform3D(Basis().scaled(Vector3(r, r * 0.85, r)), Vector3(x, y + r * 0.55, z)), c])
	bois.instance_count = touffes.size()
	for i in touffes.size():
		bois.set_instance_transform(i, touffes[i][0])
		bois.set_instance_color(i, touffes[i][1])
	var mb := MultiMeshInstance3D.new()
	mb.name = "Bois"
	mb.multimesh = bois
	# chaque touffe a son dessus clair et son dessous sombre, pour que le bois se lise en masses de loin
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley;
void fragment() {
	vec3 n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float haut = clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * mix(0.62, 1.2, haut * haut);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
	var mat_bois := ShaderMaterial.new()
	mat_bois.shader = sh
	mb.material_override = mat_bois
	mb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(mb)
	_basilique(f, Vector3(FOURVIERE.x, _colline(FOURVIERE.x, FOURVIERE.z) - 2.0, FOURVIERE.z))
	_tour_metallique(f, Vector3(TOUR.x, _colline(TOUR.x, TOUR.z), TOUR.z))


## La basilique de Fourvière, pièce unique vue de loin : la nef de pierre blanche sous son toit gris, ses quatre
## tours octogonales à créneaux aux angles, l'abside tournée vers la ville, le porche à fronton et ses colonnes,
## et le clocher de la vieille chapelle à côté, avec la Vierge dorée.
func _basilique(f: Node3D, sommet: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blanc := Color("#efe8d8")
	var ombre := Color("#d9d0bc")
	var toit := Color("#7d8288")
	var L := 72.0
	var l := 30.0
	var h := 26.0
	# la nef, son soubassement, ses corniches et les baies hautes
	_boite_st(st, sommet + Vector3(0, 2.0, 0), Vector3(L + 4.0, 4.0, l + 4.0), 0.0, ombre)
	_boite_st(st, sommet + Vector3(0, h * 0.5 + 2.0, 0), Vector3(L, h, l), 0.0, blanc)
	_boite_st(st, sommet + Vector3(0, h + 2.4, 0), Vector3(L + 1.2, 1.0, l + 1.2), 0.0, ombre)
	for i in 8:
		var x := -L * 0.5 + 8.0 + i * (L - 16.0) / 7.0
		for s in [-1.0, 1.0]:
			_boite_st(st, sommet + Vector3(x, h * 0.62, s * (l * 0.5 + 0.05)), Vector3(2.6, 9.0, 0.3), 0.0, Color("#6f6a62"))
			_boite_st(st, sommet + Vector3(x - 4.2, h * 0.5 + 2.0, s * (l * 0.5 + 0.4)), Vector3(1.4, h, 0.8), 0.0, ombre)
	# le toit à deux pans, gris d'ardoise
	var y0 := h + 2.9
	var faite := y0 + 9.0
	var coins := [Vector3(-L * 0.5, y0, -l * 0.5), Vector3(L * 0.5, y0, -l * 0.5), Vector3(L * 0.5, y0, l * 0.5), Vector3(-L * 0.5, y0, l * 0.5)]
	var fa := Vector3(-L * 0.5, faite, 0)
	var fb := Vector3(L * 0.5, faite, 0)
	for tri in [[coins[0], fa, fb, toit], [coins[0], fb, coins[1], toit], [coins[3], fb, fa, toit.darkened(0.15)], [coins[3], coins[2], fb, toit.darkened(0.15)],
			[coins[0], coins[3], fa, blanc], [coins[1], fb, coins[2], blanc]]:
		var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		for q in [tri[0], tri[1], tri[2]]:
			st.set_color(tri[3])
			st.set_normal(nrm)
			st.add_vertex(sommet + q)
	# l'abside, à l'est, vers la ville
	for i in 9:
		var a := -PI * 0.5 + PI * i / 8.0
		var p := sommet + Vector3(L * 0.5 + cos(a) * l * 0.42, 0, sin(a) * l * 0.42)
		_boite_st(st, p + Vector3(0, h * 0.45 + 2.0, 0), Vector3(6.0, h * 0.9, 6.0), -a, blanc.darkened(0.03 * (i % 2)))
	# les quatre tours octogonales et leurs créneaux
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var c := sommet + Vector3(cx * L * 0.5, 0, cz * l * 0.5)
			var ht := 46.0
			for i in 8:
				var a := TAU * i / 8.0
				_boite_st(st, c + Vector3(cos(a) * 4.6, ht * 0.5, sin(a) * 4.6), Vector3(3.9, ht, 1.2), a + PI * 0.5, blanc if i % 2 == 0 else ombre)
			_boite_st(st, c + Vector3(0, ht * 0.5, 0), Vector3(8.0, ht, 8.0), PI / 8.0, blanc)
			_boite_st(st, c + Vector3(0, ht + 0.6, 0), Vector3(11.0, 1.2, 11.0), PI / 8.0, ombre)
			for i in 12:
				var a := TAU * i / 12.0
				_boite_st(st, c + Vector3(cos(a) * 5.0, ht + 2.2, sin(a) * 5.0), Vector3(1.6, 2.2, 1.0), a + PI * 0.5, blanc)
			for e in [0.3, 0.55, 0.8]:
				_boite_st(st, c + Vector3(0, ht * e, 0), Vector3(9.8, 0.6, 9.8), PI / 8.0, ombre)
	# le porche à l'ouest : quatre colonnes et un fronton
	var pw := sommet + Vector3(-L * 0.5 - 6.0, 0, 0)
	for i in 4:
		var z := -9.0 + i * 6.0
		_boite_st(st, pw + Vector3(-1.0, 10.0, z), Vector3(1.8, 16.0, 1.8), 0.0, blanc)
	_boite_st(st, pw + Vector3(0, 19.0, 0), Vector3(8.0, 2.4, 24.0), 0.0, ombre)
	for tri in [[Vector3(-4, 20.2, -12), Vector3(-4, 27.0, 0), Vector3(-4, 20.2, 12)]]:
		for q in tri:
			st.set_color(blanc)
			st.set_normal(Vector3.LEFT)
			st.add_vertex(pw + q)
	# le clocher de la vieille chapelle, au nord-ouest, et la Vierge dorée qui le couronne
	var ch := sommet + Vector3(-L * 0.5 - 4.0, 0, -l * 0.5 - 16.0)
	_boite_st(st, ch + Vector3(0, 14.0, 0), Vector3(7.0, 28.0, 7.0), 0.0, blanc.darkened(0.04))
	_boite_st(st, ch + Vector3(0, 29.0, 0), Vector3(5.0, 3.0, 5.0), 0.0, ombre)
	_boite_st(st, ch + Vector3(0, 33.0, 0), Vector3(1.6, 5.0, 1.6), 0.0, Color("#d4a63a"))
	var mi := MeshInstance3D.new()
	mi.name = "Basilique"
	mi.mesh = st.commit()
	var mat := materiau(Color.WHITE, 0.85, true)
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	f.add_child(mi)


## La tour métallique de Fourvière : quatre montants de treillis qui se resserrent, leurs croix de Saint-André
## et la lanterne en haut, d'un gris de fer.
func _tour_metallique(f: Node3D, pied: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fer := Color("#7f868c")
	var h := 86.0
	var etages := 10
	var demi := func(y: float) -> float:
		return lerpf(7.0, 1.2, pow(y / h, 0.8))
	var coins := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for e in etages:
		var ya := h * e / etages
		var yb := h * (e + 1) / etages
		var da: float = demi.call(ya)
		var db: float = demi.call(yb)
		for i in 4:
			var c0: Vector2 = coins[i]
			var c1: Vector2 = coins[(i + 1) % 4]
			var a0: Vector3 = pied + Vector3(c0.x * da, ya, c0.y * da)
			var b0: Vector3 = pied + Vector3(c0.x * db, yb, c0.y * db)
			var a1: Vector3 = pied + Vector3(c1.x * da, ya, c1.y * da)
			var b1: Vector3 = pied + Vector3(c1.x * db, yb, c1.y * db)
			_poutre_st(st, a0, b0, 0.7, 0.7, fer)
			_poutre_st(st, a0, b1, 0.25, 0.25, fer)
			_poutre_st(st, a1, b0, 0.25, 0.25, fer)
			_poutre_st(st, b0, b1, 0.3, 0.3, fer)
	_boite_st(st, pied + Vector3(0, h + 2.0, 0), Vector3(3.0, 4.0, 3.0), 0.0, fer)
	_poutre_st(st, pied + Vector3(0, h + 4.0, 0), pied + Vector3(0, h + 12.0, 0), 0.4, 0.4, fer)
	var mi := MeshInstance3D.new()
	mi.name = "TourMetallique"
	mi.mesh = st.commit()
	var mat := materiau(Color.WHITE, 0.6, true)
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	f.add_child(mi)


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
		# sur le quai Saint-Vincent, un pas en arrière du parapet : le trottoir du quai en enfilade, ses bancs et ses
		# accoudés sur la gauche, la passerelle de trois quarts, la Saône et Fourvière en face
		"Vue1a_Passerelle": [VUE1A_OEIL, VUE1A_OEIL + VUE1A_REGARD * 160.0],
		# sur le trottoir sud, la halle de trois quarts de l'autre côté de la rue
		"Vue1b_Martiniere": [Vector2(-76.0, 118.6), Vector2(-36.0, 101.0)],
		# sur le trottoir sud, la chaussée sur la gauche et ses voitures garées en premier plan
		"Vue1c_Rambaud": [Vector2(-30.1, 117.0), Vector2(68.0, 121.0)],
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
		var sol := hauteur(a.x, a.y)
		if nom == "Vue1a_Passerelle":
			sol = maxf(sol, _niveau_quai_vue)
		var pa := Vector3(a.x, sol + 0.1, a.y) / U
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


## La caméra de dessus suit l'habitant (Guillaume, 30 octobre : en marchant vers le haut de l'écran, il en
## sortait, la vue restait fixe). En vue à pied (Vue, Tab), l'habitant n'a plus de caméra à suivre.
func _process(_delta: float) -> void:
	if player != null and player.follow_camera == camera:
		camera.set("_target_goal", player.global_position + Vector3(0, 0.3, 0))
