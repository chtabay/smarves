extends Node3D
## Ligugé, commune d'essai de la carte de la Vienne : le prieuré Saint-Martin, où vécut Rabelais, le
## Clain et son pont, quelques maisons et le Café du Pont, fermé. Du décor, construit ici en code
## pour éprouver la greffe d'un paquet qui apporte son script. La caméra est celle de Smarves, avec
## ses trois crans ; dézoomer au-delà du dernier ouvre la carte (Carte.ouvrir), comme au village.
## Comme le kit de départ (tools/kit/), la scène expose `player` et `camera` : le jeu y ajoute la vue
## à pied (Tab, ou le bouton « Vue »), les commandes tactiles et la carte.

const KN := "res://assets/kenney/nature/"
const PIERRE := Color(0.93, 0.87, 0.74)
const ARDOISE := Color(0.32, 0.36, 0.42)
const TUILE := Color(0.82, 0.45, 0.28)
const LUEUR := Color(1.0, 0.78, 0.45)

## Les crans de la caméra de dessus : distance, tangage, champ, du plus près au plus loin.
const CRANS := [[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [40.0, -60.0, 30.0]]
## L'arrivée, sur la rue du bourg, entre le pont et le prieuré.
const ARRIVEE := Vector3(1.0, 0.05, 2.2)

## Pour le jeu (vue, tactile, carte) : l'habitant qu'on dirige et la caméra à crans.
var player: CharacterBody3D
var camera: Camera3D

var _mats := {}


func _ready() -> void:
	_ciel()
	_sol()
	_clain()
	_prieure(Vector3(4, 0, -3))
	for m in [[Vector3(-1, 0, 4), 0.0, TUILE], [Vector3(2.4, 0, 5), 0.0, TUILE], [Vector3(6.2, 0, 4.4), 0.0, ARDOISE], [Vector3(10, 0, 1), 90.0, TUILE], [Vector3(-2, 0, -6), 0.0, TUILE]]:
		_maison(m[0], m[1], m[2], false)
	var cafe := _maison(Vector3(-2.2, 0, 0.6), 90.0, TUILE, true)
	_enseigne(cafe.position + Vector3(0, 3.3, 0), "CAFÉ DU PONT", Color(0.95, 0.85, 0.55), 0.005)
	_enseigne(cafe.position + Vector3(0, 3.0, 0), "Fermé. Réouverture à 40 000.", Color(0.8, 0.8, 0.8), 0.0032)
	_enseigne(Vector3(-3.6, 1.6, 3.2), "LIGUGÉ", Color.WHITE, 0.012)
	_enseigne(Vector3(4, 4.3, -1.2), "Prieuré Saint-Martin · Rabelais y vécut", Color(0.95, 0.9, 0.75), 0.0045)
	for t in [[Vector3(-8.5, 0, 6), "tree_oak", 2.4], [Vector3(-9, 0, -4), "tree_default", 2.2], [Vector3(-5.6, 0, -8), "tree_fat", 2.0],
			[Vector3(9.5, 0, -6), "tree_oak", 2.6], [Vector3(12, 0, 5), "tree_detailed", 2.2], [Vector3(-11, 0, 1), "tree_cone", 2.0],
			[Vector3(1, 0, -9), "tree_default", 2.4], [Vector3(13, 0, -2), "tree_fat", 2.2]]:
		var a: Node3D = load(KN + t[1] + ".glb").instantiate()
		a.position = t[0]
		a.scale = Vector3.ONE * t[2]
		a.rotation_degrees.y = t[0].x * 37.0
		add_child(a)
	for p in [Vector3(-0.6, 0, 2.2), Vector3(3, 0, 1.2), Vector3(7.5, 0, 1.6), Vector3(-4.3, 0, 1)]:
		_reverbere(p)
	_joueur()
	var aide := Label.new()
	aide.text = "Ligugé, commune d'essai  ·  Tab pour marcher  ·  clic droit pour tourner  ·  molette pour zoomer  ·  M pour la carte"
	aide.add_theme_font_override("font", Polices.texte())
	aide.add_theme_font_size_override("font_size", 16)
	aide.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	aide.add_theme_constant_override("outline_size", 5)
	aide.position = Vector2(24, 80)
	var ui := CanvasLayer.new()
	ui.add_child(aide)
	add_child(ui)


## L'habitant de Smarves et la caméra à crans du village, posés à l'arrivée (comme le kit).
func _joueur() -> void:
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/orbit_camera.gd"))
	camera.far = 400.0
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
	player.global_position = ARRIVEE
	camera.make_current()
	player.follow_camera = camera
	camera.au_dela.connect(func(): Carte.ouvrir())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.target = player.global_position + Vector3(0, 0.3, 0)
	camera.set("_target_goal", camera.target)
	camera.yaw = deg_to_rad(20.0)
	camera.set("_yaw_goal", camera.yaw)
	camera.use_notches(CRANS, 1)


## Un volume qu'on ne traverse pas : le sol, les murs.
func _solide(taille: Vector3, at: Vector3, rot := 0.0, parent: Node = self) -> void:
	var corps := StaticBody3D.new()
	corps.position = at
	corps.rotation_degrees.y = rot
	var forme := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = taille
	forme.shape = b
	corps.add_child(forme)
	parent.add_child(corps)


func _mat(c: Color, lueur := false) -> StandardMaterial3D:
	var k := "%s%s" % [c, lueur]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		if lueur:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 2.2
		_mats[k] = m
	return _mats[k]


func _boite(taille: Vector3, at: Vector3, c: Color, rot := 0.0, lueur := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = _mat(c, lueur)
	mi.position = at
	mi.rotation_degrees.y = rot
	add_child(mi)
	return mi


## Un toit à deux pans, faîtage le long de x local.
func _toit(long: float, larg: float, haut: float, at: Vector3, c: Color, rot := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = Vector3(larg, haut, long)
	mi.mesh = p
	mi.material_override = _mat(c)
	mi.position = at
	mi.rotation_degrees.y = rot + 90.0
	add_child(mi)


func _ciel() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.1, 0.13, 0.3)
	sm.sky_horizon_color = Color(0.75, 0.5, 0.42)
	sm.ground_horizon_color = Color(0.4, 0.3, 0.3)
	sm.ground_bottom_color = Color(0.1, 0.1, 0.12)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.light_color = Color(1.0, 0.78, 0.58)
	soleil.light_energy = 1.1
	soleil.shadow_enabled = true
	soleil.rotation_degrees = Vector3(-28, -55, 0)
	add_child(soleil)


func _sol() -> void:
	_boite(Vector3(34, 0.2, 24), Vector3(0, -0.1, 0), Color(0.42, 0.55, 0.3))
	_solide(Vector3(34, 0.2, 24), Vector3(0, -0.1, 0))
	# La rue du bourg et la place devant le prieuré.
	_boite(Vector3(22, 0.03, 1.8), Vector3(1, 0.01, 1.8), Color(0.62, 0.6, 0.56))
	_boite(Vector3(5, 0.03, 3.2), Vector3(4, 0.012, 0), Color(0.7, 0.66, 0.58))


func _clain() -> void:
	var eau := _boite(Vector3(3.2, 0.06, 24), Vector3(-6.5, 0.0, 0), Color(0.25, 0.42, 0.55))
	(eau.material_override as StandardMaterial3D).roughness = 0.15
	(eau.material_override as StandardMaterial3D).metallic = 0.3
	# Le pont de pierre, trois arches suggérées par ses piles.
	_boite(Vector3(4.2, 0.25, 1.8), Vector3(-6.5, 0.35, 1.8), PIERRE)
	for z in [1.0, 2.6]:
		_boite(Vector3(4.2, 0.35, 0.12), Vector3(-6.5, 0.62, z), PIERRE.darkened(0.08))
	for x in [-7.6, -5.4]:
		_boite(Vector3(0.5, 0.4, 1.8), Vector3(x, 0.1, 1.8), PIERRE.darkened(0.15))
	_enseigne(Vector3(-6.5, 0.15, 6.5), "le Clain", Color(0.7, 0.85, 1.0), 0.012, -90.0, true)


func _prieure(at: Vector3) -> void:
	# La nef, le chœur plus bas, et le clocher-porche surmonté de sa flèche.
	_boite(Vector3(6.0, 2.6, 2.6), at + Vector3(0, 1.3, 0), PIERRE)
	_solide(Vector3(9.0, 2.6, 2.6), at + Vector3(0.15, 1.3, 0))
	_toit(6.0, 2.9, 1.5, at + Vector3(0, 3.35, 0), ARDOISE)
	_boite(Vector3(1.8, 2.0, 2.0), at + Vector3(3.9, 1.0, 0), PIERRE.darkened(0.04))
	_toit(1.8, 2.2, 1.1, at + Vector3(3.9, 2.55, 0), ARDOISE)
	_boite(Vector3(1.8, 5.2, 1.8), at + Vector3(-3.6, 2.6, 0), PIERRE.darkened(0.02))
	var fleche := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 1.2
	c.height = 3.0
	c.radial_segments = 8
	fleche.mesh = c
	fleche.material_override = _mat(ARDOISE)
	fleche.position = at + Vector3(-3.6, 6.7, 0)
	add_child(fleche)
	for x in [-1.8, 0.0, 1.8]:
		_boite(Vector3(0.45, 1.1, 0.05), at + Vector3(x, 1.6, 1.31), LUEUR, 0.0, true)
	_boite(Vector3(0.8, 1.4, 0.05), at + Vector3(-3.6, 0.7, 0.91), Color(0.35, 0.22, 0.14))
	_boite(Vector3(0.5, 0.5, 0.05), at + Vector3(-3.6, 3.8, 0.91), LUEUR, 0.0, true)


func _maison(at: Vector3, rot: float, toit: Color, fermee: bool) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.rotation_degrees.y = rot
	add_child(n)
	var murs := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(2.4, 1.9, 1.8)
	murs.mesh = b
	murs.material_override = _mat(PIERRE.darkened(fmod(absf(at.x) * 0.013, 0.08)))
	murs.position.y = 0.95
	n.add_child(murs)
	_solide(b.size, Vector3(0, 0.95, 0), 0.0, n)
	var mt := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = Vector3(2.0, 1.0, 2.6)
	mt.mesh = p
	mt.material_override = _mat(toit)
	mt.position.y = 2.4
	mt.rotation_degrees.y = 90.0
	n.add_child(mt)
	for x in [-0.6, 0.6]:
		var f := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.4, 0.5, 0.04)
		f.mesh = fb
		f.material_override = _mat(Color(0.35, 0.45, 0.5) if fermee else LUEUR, not fermee)
		f.position = Vector3(x, 1.3, 0.91)
		n.add_child(f)
	var porte := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.5, 0.85, 0.04)
	porte.mesh = pb
	porte.material_override = _mat(Color(0.4, 0.15, 0.12) if fermee else Color(0.3, 0.42, 0.32))
	porte.position = Vector3(0, 0.43, 0.91)
	n.add_child(porte)
	return n


func _enseigne(at: Vector3, texte: String, c: Color, px := 0.01, rot := 0.0, couche := false) -> void:
	var l := Label3D.new()
	l.text = texte
	l.font = Polices.gras()
	l.font_size = 64
	l.pixel_size = px
	l.modulate = c
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.7)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED if couche else BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	if couche:
		l.rotation_degrees = Vector3(-90, rot, 0)
	add_child(l)


func _reverbere(at: Vector3) -> void:
	_boite(Vector3(0.08, 1.4, 0.08), at + Vector3(0, 0.7, 0), Color(0.15, 0.15, 0.17))
	_boite(Vector3(0.22, 0.22, 0.22), at + Vector3(0, 1.45, 0), LUEUR, 0.0, true)
	var l := OmniLight3D.new()
	l.light_color = LUEUR
	l.light_energy = 1.4
	l.omni_range = 4.0
	l.position = at + Vector3(0, 1.5, 0)
	add_child(l)
