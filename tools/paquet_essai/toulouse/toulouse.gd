extends Node3D
## Toulouse, les places du centre historique : le plan réel (bourg.json, tiré d'OpenStreetMap et de la BD TOPO
## de l'IGN par tools/bourg_reel.py), à l'échelle de Smarves (une unité vaut 2,4 m), recomposé d'après la note
## d'intentions (INTENTIONS.md). Version 0.1 : la place Saint-Georges. Les îlots du quartier sont des volumes de
## brique et d'enduit percés de fenêtres ; autour de la place, leurs fronts de rue sont des façades composées
## (saint_georges.gd), sous les platanes réels du plan. Le sol est plat : le quartier ne descend que de 7 m sur
## 750, et la carte le recompose à niveau.

const DOSSIER := "res://communes/toulouse/"
const SAINT_GEORGES := preload(DOSSIER + "saint_georges.gd")
const UNITE := 2.4
const CRANS := [[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [32.0, -58.0, 30.0]]

## La lumière de 18 h en septembre (note : « Lumière et caméras ») : soleil d'ouest-sud-ouest, bas et doré.
const SOLEIL := {"hauteur": 36.0, "vient_de": 262.0, "couleur": Color("ffd9a8")}

## Les familles de la palette (note : « Palette et matières »).
const BRIQUES := ["c8653f", "d2714a", "be5b38", "db8158", "c46a48"]
const ENDUITS := ["ebcfc0", "f2e4cf", "e7c9b0", "efdcc4"]
const RUE := Color("dccdab")
const PLACE := Color("c4804e")
const FILET := Color("efe7da")

## La place Saint-Georges, en unités : le tapis de brique d'une façade à l'autre, rue de bordure comprise
## (d'après le plan réel ; parti pris de la note : la place se lit en un seul tapis).
const PLACE_SAINT_GEORGES := [Vector2(-9.5, -18.0), Vector2(13.0, -18.5), Vector2(20.8, 3.2), Vector2(9.0, 12.5), Vector2(5.0, 19.0), Vector2(-0.5, 7.0), Vector2(-5.4, 0.4), Vector2(-6.0, -6.5), Vector2(-9.5, -12.0)]
## Là où les fronts de rue sont composés (au plus près de la place) ; ailleurs, les volumes seuls.
const CENTRE_DETAIL := Vector2(6.0, 0.0)
const RAYON_DETAIL := 34.0
## Le périmètre de la carte (demande de Guillaume, 29 octobre) : la place et 30 m autour (12,5 unités) ; les îlots
## qui ferment les rues vont jusqu'à 25 unités (60 m), en volumes simples, et une brume dorée efface le reste.
const PERIMETRE := 12.5
const FERMETURE := 25.0

var player: CharacterBody3D
var camera: Camera3D
## Le socle attend 1.0 avant d'inscrire l'habitant dans son lieu.
var chargement := 0.0

var data: Dictionary
var perimetre: PackedVector2Array
var fermeture: PackedVector2Array
var _grille := {}
var _mats := {}


func _ready() -> void:
	data = Atelier.donnees(DOSSIER + "bourg.json")
	perimetre = Geometry2D.offset_polygon(PackedVector2Array(PLACE_SAINT_GEORGES), PERIMETRE)[0]
	fermeture = Geometry2D.offset_polygon(PackedVector2Array(PLACE_SAINT_GEORGES), FERMETURE)[0]
	_ciel()
	_sol()
	_indexer()
	_ilots()
	SAINT_GEORGES.construire(self)
	_joueur()
	chargement = 1.0


# --- La lumière -----------------------------------------------------------------------------------

func _ciel() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# Un bleu franc qui pâlit vers un horizon bleu-gris, sans rose (CONCEPTION.md, « Les pièges »).
	sm.sky_top_color = Color("4f86c6")
	sm.sky_horizon_color = Color("9ec2de")
	# le bleu dès quelques degrés au-dessus de l'horizon : la vue du balcon voyait un ciel gris (juge, v0.9)
	sm.sky_curve = 0.06
	sm.ground_horizon_color = Color("b0a492")
	sm.ground_bottom_color = Color("5a4a3c")
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# une ombre colorée, pas noire : le bleu du ciel sur la brique, qui tempère l'orangé (juge, v0.11 puis v0.12)
	env.ambient_light_color = Color("8fa6c8")
	env.ambient_light_energy = 1.8
	env.ambient_light_sky_contribution = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	# Sans halo (Guillaume, 29 octobre : « les flash sont inutiles »).
	env.glow_enabled = false
	# L'étalonnage de l'image cible : plus saturé, un peu plus contrasté, chaud.
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 1.03
	# La brume dorée des lointains : au-delà des îlots qui ferment les rues, la ville se fond dans l'air du soir.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("e9d7b0")
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 110.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "Environnement"
	we.environment = env
	add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.name = "Soleil"
	soleil.light_color = SOLEIL.couleur
	soleil.light_energy = 1.6
	soleil.shadow_enabled = true
	# des ombres franches et denses sur un sol clair, pas une pénombre uniforme (juge, v0.9b)
	soleil.shadow_opacity = 1.0
	soleil.shadow_blur = 0.25
	soleil.shadow_bias = 0.03
	soleil.directional_shadow_max_distance = 48.0
	add_child(soleil)
	var h := deg_to_rad(SOLEIL.hauteur)
	var a := deg_to_rad(SOLEIL.vient_de)
	soleil.look_at_from_position(Vector3.ZERO, Vector3(-sin(a) * cos(h), -sin(h), cos(a) * cos(h)))
	# Le bleu du ciel à l'opposé du soleil, sans ombre : il refroidit les faces que le soleil ne touche pas
	# (juge, v0.13).
	var appoint := DirectionalLight3D.new()
	appoint.name = "Appoint"
	appoint.light_color = Color("8fa6c8")
	appoint.light_energy = 0.25
	appoint.shadow_enabled = false
	# pas de second disque dans le ciel : il y dessinait une tache sombre au zénith de la vue de départ (juge, v0.14)
	appoint.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(appoint)
	var ha := deg_to_rad(30.0)
	var aa := a + PI
	appoint.look_at_from_position(Vector3.ZERO, Vector3(-sin(aa) * cos(ha), -sin(ha), cos(aa) * cos(ha)))


# --- Le sol ---------------------------------------------------------------------------------------

func materiau_sol() -> ShaderMaterial:
	if not _mats.has("sol"):
		var m := ShaderMaterial.new()
		m.shader = load(DOSSIER + "sol.gdshader")
		_mats.sol = m
	return _mats.sol


## Le sol du périmètre en pavés de pierre claire, la place Saint-Georges en brique posée en épi par-dessus,
## et un seul plan de collision à y = 0.
func _sol() -> void:
	var r := Rect2(fermeture[0], Vector2.ZERO)
	for q in fermeture:
		r = r.expand(q)
	r = r.grow(6.0)
	var c: Array = [r.position.x, r.position.y, r.end.x, r.end.y]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_color(Color(RUE, 0.0))
	var a := Vector3(c[0], 0, c[1])
	var b := Vector3(c[2], 0, c[1])
	var d := Vector3(c[2], 0, c[3])
	var e := Vector3(c[0], 0, c[3])
	for p in [a, b, d, a, d, e]:
		st.add_vertex(p)
	var poly := PackedVector2Array(PLACE_SAINT_GEORGES)
	st.set_color(Color(PLACE, 1.0))
	for k in Geometry2D.triangulate_polygon(poly):
		st.add_vertex(Vector3(poly[k].x, 0.012, poly[k].y))
	# Le filet de pierre blanche, 30 cm, tout autour de la place.
	st.set_color(Color(FILET, 0.5))
	var dehors: PackedVector2Array = Geometry2D.offset_polygon(poly, 0.125)[0]
	for k in Geometry2D.triangulate_polygon(dehors):
		st.add_vertex(Vector3(dehors[k].x, 0.008, dehors[k].y))
	var mi := MeshInstance3D.new()
	mi.name = "Sol"
	mi.mesh = st.commit()
	mi.material_override = materiau_sol()
	add_child(mi)
	var corps := StaticBody3D.new()
	corps.name = "SolCorps"
	var cs := CollisionShape3D.new()
	var plan := BoxShape3D.new()
	plan.size = Vector3(c[2] - c[0], 1.0, c[3] - c[1])
	cs.shape = plan
	cs.position = Vector3((c[0] + c[2]) * 0.5, -0.5, (c[1] + c[3]) * 0.5)
	corps.add_child(cs)
	add_child(corps)


# --- Les îlots ------------------------------------------------------------------------------------

## Vrai si un sommet du polygone est dans la zone.
func _dans(poly: PackedVector2Array, zone: PackedVector2Array) -> bool:
	for q in poly:
		if Geometry2D.is_point_in_polygon(q, zone):
			return true
	return false


## Les bâtiments rangés par cases de 10 unités, pour savoir vite si un point est dans un bâtiment.
func _indexer() -> void:
	for i in data.batiments.size():
		var b: Dictionary = data.batiments[i]
		var poly := PackedVector2Array()
		var bas := Vector2(INF, INF)
		var haut := Vector2(-INF, -INF)
		for q in b.p:
			var v := Vector2(q[0], q[1])
			poly.append(v)
			bas = bas.min(v)
			haut = haut.max(v)
		b["poly"] = poly
		b["i"] = i
		for gx in range(int(floor(bas.x / 10.0)), int(floor(haut.x / 10.0)) + 1):
			for gz in range(int(floor(bas.y / 10.0)), int(floor(haut.y / 10.0)) + 1):
				var k := Vector2i(gx, gz)
				if not _grille.has(k):
					_grille[k] = []
				_grille[k].append(b)


## Le bâtiment qui contient p, ou {}.
func batiment_en(p: Vector2) -> Dictionary:
	for b in _grille.get(Vector2i(int(floor(p.x / 10.0)), int(floor(p.y / 10.0))), []):
		if Geometry2D.is_point_in_polygon(p, b.poly):
			return b
	return {}


## Un mur est sur la rue quand le dehors, devant son milieu et ses quarts, n'est dans aucun bâtiment.
func sur_la_rue(a: Vector2, c: Vector2) -> bool:
	var u := (c - a).normalized()
	var dehors := Vector2(u.y, -u.x)
	var libres := 0
	for t in [0.25, 0.5, 0.75]:
		if batiment_en(a.lerp(c, t) + dehors * 0.8).is_empty():
			libres += 1
	return libres >= 2


## Le sens de parcours direct, qui met le dehors à droite du mur, en (u.y, -u.x), quel que soit le sens du plan.
func _horaire(poly: PackedVector2Array) -> PackedVector2Array:
	var s := 0.0
	for k in poly.size():
		var a := poly[k]
		var c := poly[(k + 1) % poly.size()]
		s += a.x * c.y - c.x * a.y
	if s < 0.0:
		var r := poly.duplicate()
		r.reverse()
		return r
	return poly


func teinte_mur(b: Dictionary) -> Color:
	var g := int(b.i)
	# la ville rose : deux îlots sur trois en brique, quel que soit le relevé (juge, v0.14 : le fond du balcon)
	if _en_brique(b):
		return Color(BRIQUES[g % BRIQUES.size()])
	return Color(ENDUITS[g % ENDUITS.size()])


func _en_brique(b: Dictionary) -> bool:
	return b.mur == "brique" or int(b.i) % 3 != 0


## Les volumes : murs de brique ou d'enduit percés de fenêtres, toit de tuile canal plat vu d'en haut, fondus
## par cases de 40 unités ; les murs de tous les bâtiments font la collision. Les bâtiments dont la place
## compose les fronts (saint_georges.gd) sont laissés à elle.
func _ilots() -> void:
	var murs_mat := ShaderMaterial.new()
	murs_mat.shader = load(DOSSIER + "murs.gdshader")
	var toit_mat := ShaderMaterial.new()
	toit_mat.shader = load("res://shaders/roof_tiles.gdshader")
	var cases := {}
	var faces := PackedVector3Array()
	var composes: Dictionary = SAINT_GEORGES.batiments_composes(self)
	for b in data.batiments:
		if SAINT_GEORGES.FANTOMES.has(int(b.i)):
			continue
		var poly := _horaire(b.poly)
		if not _dans(poly, fermeture):
			continue
		var h: float = maxf(float(b.h), 1.2)
		for k in poly.size():
			var a := poly[k]
			var c := poly[(k + 1) % poly.size()]
			var v := [Vector3(a.x, 0, a.y), Vector3(c.x, 0, c.y), Vector3(c.x, h, c.y), Vector3(a.x, h, a.y)]
			for s in [0, 1, 2, 0, 2, 3]:
				faces.append(v[s])
		if composes.has(int(b.i)):
			continue
		var centre := Vector2(b.rect[0], b.rect[1])
		var cle := Vector2i(int(floor(centre.x / 40.0)), int(floor(centre.y / 40.0)))
		if not cases.has(cle):
			var sm := SurfaceTool.new()
			sm.begin(Mesh.PRIMITIVE_TRIANGLES)
			var stt := SurfaceTool.new()
			stt.begin(Mesh.PRIMITIVE_TRIANGLES)
			cases[cle] = [sm, stt]
		volume(cases[cle][0], cases[cle][1], b, poly, h, teinte_mur(b))
	for cle in cases:
		var mesh := ArrayMesh.new()
		cases[cle][0].commit(mesh)
		mesh.surface_set_material(0, murs_mat)
		cases[cle][1].commit(mesh)
		mesh.surface_set_material(1, toit_mat)
		var mi := MeshInstance3D.new()
		mi.name = "Ilots_%d_%d" % [cle.x, cle.y]
		mi.mesh = mesh
		add_child(mi)
	var forme := ConcavePolygonShape3D.new()
	forme.backface_collision = true
	forme.set_faces(faces)
	var corps := StaticBody3D.new()
	corps.name = "Murs"
	var cs := CollisionShape3D.new()
	cs.shape = forme
	corps.add_child(cs)
	add_child(corps)


## Un bâtiment en volume : ses murs (UV en mètres le long du mur et en hauteur), son toit plat de tuiles.
func volume(sm: SurfaceTool, stt: SurfaceTool, b: Dictionary, poly: PackedVector2Array, h: float, teinte: Color) -> void:
	var brique := 1.0 if _en_brique(b) else 0.0
	var hm := h * UNITE
	var x := 0.0
	for k in poly.size():
		var a := poly[k]
		var c := poly[(k + 1) % poly.size()]
		var l := a.distance_to(c) * UNITE
		var pts := [Vector3(a.x, 0, a.y), Vector3(c.x, 0, c.y), Vector3(c.x, h, c.y), Vector3(a.x, h, a.y)]
		var uvs := [Vector2(x, 0), Vector2(x + l, 0), Vector2(x + l, hm), Vector2(x, hm)]
		var u := (c - a).normalized()
		var n := Vector3(u.y, 0.0, -u.x)
		for s in [0, 2, 1, 0, 3, 2]:
			sm.set_normal(n)
			sm.set_color(Color(teinte, brique))
			sm.set_uv(uvs[s])
			sm.set_uv2(Vector2(hm, 0))
			sm.add_vertex(pts[s])
		x += l
	var toit := Color("c46a3c") if b.toit != "ardoise" else Color("4e5a66")
	if b.toit == "zinc":
		toit = Color("8d939a")
	toit = toit.lerp(Color("a4512e"), 0.35 * float(int(b.i) % 3) / 2.0)
	# Le rang de tuiles de l'égout, en débord sur chaque mur : de loin, le toit se lit au-dessus de la façade.
	for k in poly.size():
		var a := poly[k]
		var c := poly[(k + 1) % poly.size()]
		var u := (c - a).normalized()
		var d := Vector2(u.y, -u.x) * 0.22
		var pts := [Vector3(a.x, h + 0.06, a.y), Vector3(c.x, h + 0.06, c.y), Vector3(c.x + d.x, h - 0.1, c.y + d.y), Vector3(a.x + d.x, h - 0.1, a.y + d.y)]
		var l := a.distance_to(c) * UNITE
		var uvs := [Vector2(0, 0), Vector2(l, 0), Vector2(l, 0.6), Vector2(0, 0.6)]
		stt.set_normal(Vector3(d.x, 1.4, d.y).normalized())
		for t in [0, 1, 2, 0, 2, 3]:
			stt.set_color(toit)
			stt.set_uv(uvs[t])
			stt.add_vertex(pts[t])
	stt.set_normal(Vector3.UP)
	for k in Geometry2D.triangulate_polygon(poly):
		stt.set_color(toit)
		stt.set_uv(poly[k] * UNITE)
		stt.add_vertex(Vector3(poly[k].x, h, poly[k].y))


# --- L'habitant -----------------------------------------------------------------------------------

func _joueur() -> void:
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/orbit_camera.gd"))
	camera.far = 600.0
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
	# Au retour d'une salle de jeu, quand la scène s'est rebâtie : devant sa porte.
	if SAINT_GEORGES.PORTES.has(Game.return_point):
		var porte: Node3D = get_node_or_null(SAINT_GEORGES.PORTES[Game.return_point][0])
		Game.return_point = ""
		if porte != null:
			player.global_transform = porte.global_transform
	player.interact.connect(_interagir)
	camera.make_current()
	player.follow_camera = camera
	camera.au_dela.connect(func(): Carte.ouvrir())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.target = player.global_position + Vector3(0, 0.3, 0)
	camera.set("_target_goal", camera.target)
	camera.use_notches(CRANS, 1)


## Les portes de la place : les salles de jeu du manifeste, ouvertes par le socle (fermées, la porte dit le seuil).
func _interagir(cible: Node) -> void:
	var id := str(cible.get_meta("interact", ""))
	if SAINT_GEORGES.PORTES.has(id):
		SalleJeu.ouvrir("toulouse", id)
