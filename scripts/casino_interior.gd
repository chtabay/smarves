extends Node3D
## L'intérieur du Casino de Smarves, sur le modèle d'Addict : sas, hall d'honneur avec réception et
## vestiaire, bar Le Nocturne, salle des jeux ; la Salle des Ambassadeurs et le salon privé s'ouvrent
## par des seuils de gains. On y marche à la première personne. 1 unité = 1 mètre.

const STATIC_BATCH := preload("res://scripts/static_batch.gd")
const PLAYER := preload("res://scripts/fp_player.gd")
const VILLAGER := preload("res://scripts/villager.gd")
const SLOT := preload("res://scripts/slot_machine.gd")
const ROULETTE := preload("res://scripts/roulette_panel.gd")
const BLACKJACK := preload("res://scripts/blackjack_panel.gd")
const BACCARA := preload("res://scripts/baccara_panel.gd")
const DICE := preload("res://scripts/dice_panel.gd")
const CRAPS := preload("res://scripts/craps_panel.gd")
const WHEEL := preload("res://scripts/wheel_panel.gd")
const POKER := preload("res://scripts/poker_panel.gd")
const LOAN := preload("res://scripts/loan_panel.gd")
const ROULETTE_3D := preload("res://scripts/jeux/roulette_3d.gd")
const BLACKJACK_3D := preload("res://scripts/jeux/blackjack_3d.gd")
const SLOT_3D := preload("res://scripts/jeux/slot_3d.gd")
const CRAPS_3D := preload("res://scripts/jeux/craps_3d.gd")
const HASARD_3D := preload("res://scripts/jeux/hasard_3d.gd")
const BACCARA_3D := preload("res://scripts/jeux/baccara_3d.gd")
const ROUE_3D := preload("res://scripts/jeux/roue_3d.gd")
const BOULE_3D := preload("res://scripts/jeux/boule_3d.gd")
const POKER_3D := preload("res://scripts/jeux/poker_3d.gd")
const POKER_MULTI := preload("res://scripts/jeux/poker_multi.gd")
const KIT := preload("res://scripts/jeux/kit.gd")
const BARRE := preload("res://scripts/jeux/barre.gd")
## Niveau du plancher de l'étage.
const UP := 5.2
const KC := "res://assets/kenney/characters/"
const KK := "res://assets/kaykit/"
const WALL_H := 5.0
## Les petits habitants de Smarves, grandis à taille humaine (1,7 m).
const PEOPLE_SCALE := 2.6

## Pièces fermées par un seuil sur le total gagné au jeu (comme dans Addict, tuning.js).
## Elles viennent du manifeste de la commune (« salles » → « casino », docs/COMMUNE.md).
static var LOCKS: Array = Commune.smarves().salles("casino")

## Les pièces, pour afficher leur nom quand on y entre : [nom, x0, x1, z0, z1].
const ROOMS := [
	["Le sas", -3.0, 3.0, 18.0, 22.0],
	["Le Hall d'honneur", -10.0, 10.0, 6.0, 18.0],
	["Le Nocturne", 10.0, 20.0, 6.0, 18.0],
	["La Salle des jeux", -14.0, 14.0, -14.0, 6.0],
	["La Salle des Ambassadeurs", 14.0, 26.0, -14.0, 6.0],
	["Le Salon privé", -26.0, -14.0, -14.0, 0.0],
	["La Galerie de la Verrière", -7.0, 7.0, -9.0, 6.0, 1],
	["Le Bar du Fumoir", -14.0, -7.0, -14.0, 6.0, 1],
	["Restaurant Le Lustre", -7.0, 7.0, -14.0, -9.0, 1],
	["La Loggia", 7.0, 14.0, -2.0, 6.0, 1],
	["La galerie du hall", -10.0, 10.0, 6.0, 18.0, 1],
	["La Salle des fêtes", 14.0, 26.0, -14.0, -7.0, 1],
	["Le Salon de musique", 14.0, 26.0, -7.0, -1.0, 1],
	["Les Salons particuliers", 14.0, 26.0, -1.0, 6.0, 1],
]

var serif: Font
var gold: StandardMaterial3D
var wood: StandardMaterial3D
var dark_wood: StandardMaterial3D
var marble_white: StandardMaterial3D
var felt: StandardMaterial3D
var velvet: StandardMaterial3D
var brass_glow: StandardMaterial3D
var chrome: StandardMaterial3D
var floor_marble: ShaderMaterial
var carpet: ShaderMaterial
var carpet_blue: ShaderMaterial
var damask: ShaderMaterial
var ceiling: StandardMaterial3D

var player: CharacterBody3D
var barriers := {}
var _panel_layer: CenterContainer
var _active_panel: Control
var _credits_label: Label
var _won_label: Label
var _prompt: Label
var _banner: Label
var _toast: PanelContainer
var _toast_tw: Tween
var _dim: ColorRect
var _room_label: Label
var _current_room := ""
var _shown := 0.0


func _ready() -> void:
	randomize()
	_materials()
	_extra_materials()
	_environment()
	_build_shell()
	_build_hall()
	_build_bar()
	_build_games_room()
	_build_miosson()
	_build_ambassadeurs()
	_build_salon()
	_build_upper()
	_build_ui()
	player = PLAYER.new()
	player.position = Vector3(0, 0, 20.5)
	player.rotation.y = 0.0
	if Game.return_point == "cercle":
		# Retour du Cercle Philidor : devant sa porte, au fond du Fumoir.
		Game.return_point = ""
		player.position = Vector3(-12.4, UP, 4.0)
		player.rotation.y = -PI / 2.0
	add_child(player)
	player.interact.connect(_on_interact)
	# Les autres joueurs connectés dans le casino, à la taille des figurants de la salle.
	Presences.entrer("smarves", "casino", self, player, PEOPLE_SCALE)
	_shown = Game.credits
	_refresh_locks(true)
	# L'architecture ne bouge plus : ses milliers de pièces se fondent en quelques maillages par matériau.
	var keep: Array = [player]
	for id in barriers:
		keep.append_array(barriers[id])
	STATIC_BATCH.bake(self, keep)
	Sfx.set_ambience("casino")
	Game.brunet_calls.connect(_on_brunet_calls)
	_maybe_capture()


## Méthode et non lambda : la connexion à l'autoload tombe avec la scène.
func _on_brunet_calls() -> void:
	_announce("Un mot de M. Brunet vous attend à la caisse : « Ne laissez pas passer votre chance, je suis là. »")


# --- Matériaux ------------------------------------------------------------------

func _std(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _shader(path: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _materials() -> void:
	serif = Polices.texte()
	gold = _std(Color(1.0, 0.76, 0.36), 0.28, 1.0)
	chrome = _std(Color(0.85, 0.85, 0.88), 0.15, 1.0)
	# Acajou : un bruit étiré en long fait le fil du bois.
	var n := FastNoiseLite.new()
	n.frequency = 0.02
	n.fractal_octaves = 3
	var grain := NoiseTexture2D.new()
	grain.width = 512
	grain.height = 64
	grain.seamless = true
	grain.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.6, 0.6))
	g.set_color(1, Color(1, 1, 1))
	grain.color_ramp = g
	wood = _std(Color(0.42, 0.17, 0.08), 0.35)
	wood.albedo_texture = Memo.bruit("casino", "res://scripts/casino_interior.gd", "acajou", grain)
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(0.5, 4.0, 0.5)
	dark_wood = wood.duplicate()
	dark_wood.albedo_color = Color(0.22, 0.09, 0.05)
	marble_white = _std(Color(0.92, 0.9, 0.86), 0.12)
	felt = _std(Color(0.06, 0.36, 0.2), 1.0)
	var fn := FastNoiseLite.new()
	fn.frequency = 0.9
	var ft := NoiseTexture2D.new()
	ft.width = 256
	ft.height = 256
	ft.seamless = true
	ft.noise = fn
	var fg := Gradient.new()
	fg.set_color(0, Color(0.78, 0.8, 0.78))
	fg.set_color(1, Color(1, 1, 1))
	ft.color_ramp = fg
	felt.albedo_texture = Memo.bruit("casino", "res://scripts/casino_interior.gd", "feutre", ft)
	felt.uv1_triplanar = true
	felt.uv1_scale = Vector3.ONE * 3.0
	velvet = _std(Color(0.5, 0.03, 0.08), 0.85)
	brass_glow = _std(Color(1.0, 0.85, 0.6), 0.3)
	brass_glow.emission_enabled = true
	brass_glow.emission = Color(1.0, 0.72, 0.4)
	brass_glow.emission_energy_multiplier = 3.0
	floor_marble = _shader("res://shaders/marble_checker.gdshader", {"tile": 1.0})
	carpet = _shader("res://shaders/carpet.gdshader")
	carpet_blue = _shader("res://shaders/carpet.gdshader", {"base_col": Color(0.05, 0.08, 0.25), "deep_col": Color(0.02, 0.03, 0.1)})
	damask = _shader("res://shaders/damask.gdshader")
	ceiling = _std(Color(0.16, 0.07, 0.05), 0.6)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.015, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.38, 0.25)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.ssil_enabled = true
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 1.2
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.9, 0.8, 0.7)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.005, 0.02))
	g.set_color(1, Color(1.0, 0.93, 0.78))
	g.add_point(0.5, Color(0.52, 0.47, 0.44))
	var grade := GradientTexture1D.new()
	grade.gradient = g
	env.adjustment_color_correction = grade
	# Un halo serré autour des seules sources vives (comme le bloom d'Addict : force 0,4, seuil 1,05) :
	# pas de bloom sur toute l'image ni de grands niveaux, qui voilaient la salle d'un flou.
	for i in 7:
		env.set_glow_level(i, [0.0, 0.8, 0.5, 0.15, 0.0, 0.0, 0.0][i])
	env.glow_intensity = 0.4
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	env.volumetric_fog_density = 0.003
	# Reflets dans les miroirs, le marbre ciré et le laque.
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# --- Briques de construction -------------------------------------------------------

func _box(size: Vector3, pos: Vector3, mat: Material, collide := false, parent: Node = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		m.add_child(body)
	return m


func _cyl(r: float, h: float, pos: Vector3, mat: Material, parent: Node = self, r_top := -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r if r_top < 0.0 else r_top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 32
	m.mesh = c
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


func _bill(l: Label3D) -> Label3D:
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	return l


func _label(text: String, pos: Vector3, rot_y: float, size := 64, color := Color(1.0, 0.85, 0.5), parent: Node = self) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = serif
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.position = pos
	l.rotation_degrees.y = rot_y
	parent.add_child(l)
	return l


func _place(path: String, pos: Vector3, scale := 1.0, rot_y := 0.0) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scale
	n.rotation_degrees.y = rot_y
	add_child(n)
	return n


func _interactive(node: Node3D, kind: String, prompt: String, size: Vector3, offset := Vector3.ZERO) -> Area3D:
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = offset
	a.add_child(cs)
	a.set_meta("interact", kind)
	a.set_meta("prompt", prompt)
	node.add_child(a)
	return a


## La voix de chacun selon son rôle dans la maison.
func _speaker_for(model: String) -> String:
	if model.begins_with("hotesse"):
		return "hotesse"
	if model.begins_with("croupi") or model in ["stickman", "mlle-solange", "chef-de-partie"]:
		return "croupier"
	if model.begins_with("barman"):
		return "barman"
	if model == "caissier":
		return "caissier"
	if model == "portier-salon":
		return "armand"
	if model == "capucine-varenne":
		return "capucine"
	return "habitant"


func _person(model: String, pos: Vector3, rot_y: float, pose := "idle", acc := "") -> Node3D:
	var v: Node3D = VILLAGER.new()
	v.accessory = acc
	v.speaker = _speaker_for(model)
	v.model_path = KC + model
	v.pose = pose
	v.position = pos
	v.rotation_degrees.y = rot_y
	v.scale = Vector3.ONE * PEOPLE_SCALE
	add_child(v)
	return v




func _sconce(pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	add_child(root)
	_box(Vector3(0.18, 0.3, 0.06), Vector3(0, 0, 0), gold, false, root)
	_cyl(0.07, 0.16, Vector3(0, 0.15, 0.12), _sconce_shade(), root, 0.1)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.45)
	l.light_energy = 0.6
	l.omni_range = 3.0
	l.light_volumetric_fog_energy = 0.2
	l.position = Vector3(0, 0.2, 0.4)
	root.add_child(l)




## L'abat-jour des appliques : il luit sans éblouir le mur qui le porte.
var _shade_mat: StandardMaterial3D


func _sconce_shade() -> StandardMaterial3D:
	if _shade_mat == null:
		_shade_mat = brass_glow.duplicate()
		_shade_mat.emission_energy_multiplier = 1.6
	return _shade_mat


func _glass() -> StandardMaterial3D:
	var m := _std(Color(0.8, 0.9, 0.95, 0.25), 0.05)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.3
	return m




func _tint(node: Node, c: Color) -> void:
	var m := _std(c, 0.55)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			mi.set_surface_override_material(i, m)




func _roulette_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var c := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var d := Vector2(x, y) - c
			var r := d.length() / (size / 2.0)
			var col := Color(0.85, 0.66, 0.3)
			if r > 0.62 and r < 0.97:
				var a := fposmod(atan2(d.y, d.x) + PI / 37.0, TAU)
				var i := int(a / TAU * 37.0) % 37
				var n: int = ROULETTE.WHEEL[i]
				col = Color(0.05, 0.45, 0.2) if n == 0 else (Color(0.72, 0.08, 0.1) if n in ROULETTE.RED else Color(0.06, 0.06, 0.07))
			elif r <= 0.62:
				col = Color(0.35, 0.18, 0.08) if r > 0.25 else Color(0.85, 0.66, 0.3)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _invisible() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0)
	return m


func _node(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	return n




func _lock_info(id: String) -> Dictionary:
	for l in LOCKS:
		if l.id == id:
			return l
	return {}


# --- Jeux et interactions ----------------------------------------------------------------

var _last_target: Node


func _on_interact(target: Node) -> void:
	_last_target = target
	_table = null
	var kind: String = str(target.get_meta("interact"))
	match kind:
		"cercle":
			Cercle.ouvrir("smarves", "res://scenes/casino.tscn", "cercle")
		"exit":
			Game.return_point = "casino"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Chargement.changer("res://scenes/main.tscn")
		"talk":
			var v: Node = target.get_parent()
			v.say(Lines.line(v.speaker))
		"reception":
			_announce("« Bienvenue au Casino de Smarves. Ici, chaque mise prépare votre avenir. »")
		"cashier":
			if Game.advance_if_broke(5):
				_announce("La caisse vous avance %d crédits. « La maison croit en vous. »" % Game.ADVANCE)
			else:
				# Le guichet du Crédit Smarvois, à la caisse du casino.
				var loan: PanelContainer = LOAN.new()
				_open_panel(loan)
		"slot":
			var p: PanelContainer = SLOT.new()
			_table = target.get_parent()
			p.game = Game
			p.title = target.get_parent().get_meta("name")
			p.subtitle = "Casino de Smarves  ·  salle des jeux"
			_open_panel(p)
		"roulette":
			var r: PanelContainer = ROULETTE.new()
			r.title = "Roulette européenne"
			_open_panel(r)
		"blackjack":
			var b: PanelContainer = BLACKJACK.new()
			_open_panel(b)
		"poker", "poker-miosson":
			# Connecté au compte : la table partagée entre les joueurs du soir ; sinon, seul contre les habitués.
			var pk: PanelContainer = POKER_MULTI.new() if Compte.connecte() or _poker_essai else POKER.new()
			if _poker_essai:
				pk.hors_ligne = true
			var cle := "miosson" if kind == "poker-miosson" else "ambassadeurs"
			if cle == "miosson":
				_configurer_miosson(pk)
			if pk.has_signal("lineup_changed"):
				pk.lineup_changed.connect(_poker_lineup.bind(cle))
				pk.closed.connect(func(): _poker_lineup({}, cle))
			_open_panel(pk)
		"roue":
			var w: PanelContainer = WHEEL.new()
			w.mode = "roue"
			w.title = "La Roue de la fortune"
			_open_panel(w)
		"boule":
			var bo: PanelContainer = WHEEL.new()
			bo.mode = "boule"
			bo.title = "La Boule"
			_open_panel(bo)
		"banco":
			var bc: PanelContainer = BACCARA.new()
			bc.title = "Banco des Salons particuliers"
			bc.commission = false
			_open_panel(bc)
		"craps":
			var cp: PanelContainer = CRAPS.new()
			_open_panel(cp)
		"dice":
			var g: PanelContainer = DICE.new()
			_open_panel(g)
		"baccara":
			var c: PanelContainer = BACCARA.new()
			c.title = "Baccara du salon privé"
			_open_panel(c)


var _table: Node3D


func _open_panel(p: Control) -> void:
	if _table == null and _last_target != null:
		_table = _last_target.get_parent() as Node3D
	var t3d: Node = _table.get_meta("table3d") if _table and _table.has_meta("table3d") else null
	if _table:
		_face(_table.global_position)
		_staff_cues(p, _table)
		if t3d == null:
			_animate(p, _table)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_prompt.visible = false
	if t3d:
		# Table 3D : la caméra s'assoit à la table, le panneau devient une barre basse.
		t3d.attach(p)
		t3d.sit(player.camera)
		# Le nom de la pièce s'efface : il passerait sur le fronton ou le tapis.
		_room_label.modulate.a = 0.0
		_seated = t3d
		BARRE.dock(p, _panel_layer.get_parent())
	else:
		_panel_layer.add_child(p)
		_dim.visible = true
	if p.has_signal("played"):
		p.played.connect(_on_played)
	p.closed.connect(_close_panel)
	_active_panel = p


## Le joueur se tourne vers la table, le regard un peu plongeant.
func _face(at: Vector3) -> void:
	var to := at - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.camera.rotation.x = deg_to_rad(-28.0)


func _animate(p: Control, table: Node3D) -> void:
	if p.has_signal("spin_started") and table.has_meta("rotor"):
		p.spin_started.connect(func(n: int, dur: float): _spin_roulette(table, n, dur))
	if p.has_signal("reels_started") and table.has_meta("reel_mats"):
		p.reels_started.connect(func(): _spin_reels(table))
		p.reels_stopped.connect(func(line: Array): _stop_reels(table, line))
	if p.has_signal("card_dealt"):
		p.hand_started.connect(func(): _clear_cards(table))
		p.card_dealt.connect(func(who: String, c: Dictionary, hidden: bool): _deal_card(table, who, c, hidden))
		if p.has_signal("hole_revealed"):
			p.hole_revealed.connect(func(c: Dictionary): _reveal_hole(table, c))
	if p.has_signal("dice_rolled"):
		p.dice_rolled.connect(func(v: Array): _roll_dice(table, v))


# --- Animations des tables ---------------------------------------------------------------

## Le croupier de la table accompagne le jeu : il lance la bille, donne les cartes, ramasse les dés.
func _staff_cues(p: Control, table: Node3D) -> void:
	var at := table.global_position
	if p.has_signal("spin_started"):
		p.spin_started.connect(func(_n: int, _dur: float): VILLAGER.dealer_gesture(get_tree(), at, 3.0, "spin"))
	if p.has_signal("card_dealt"):
		p.card_dealt.connect(func(_who: String, _c: Dictionary, _hidden: bool): VILLAGER.dealer_gesture(get_tree(), at, 3.0, "deal"))
	if p.has_signal("dice_rolled"):
		p.dice_rolled.connect(func(_v: Array): VILLAGER.dealer_gesture(get_tree(), at, 3.0, "rake"))


func _spin_roulette(table: Node3D, n: int, dur: float) -> void:
	var rotor: Node3D = table.get_meta("rotor")
	var ball: Node3D = table.get_meta("ball")
	var step := TAU / 37.0
	var idx: int = ROULETTE.WHEEL.find(n)
	var start := rotor.rotation.y
	var end := start + TAU * 3.0
	# La bille finit dans la case tirée : angle de la case dans le repère de la roue, moins la rotation du rotor.
	var final_ball := idx * step - end
	var tw := create_tween().set_parallel()
	tw.tween_property(rotor, "rotation:y", end, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(a: float):
		var k := clampf((a - (final_ball + TAU * 5.0)) / (-TAU * 5.0), 0.0, 1.0)
		var r := lerpf(0.5, 0.38, smoothstep(0.7, 1.0, 1.0 - k))
		ball.position = Vector3(cos(a) * r, 0.2 + 0.02 * (1.0 - k), sin(a) * r), final_ball + TAU * 5.0, final_ball, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)


var _reel_spin := {}


func _spin_reels(table: Node3D) -> void:
	_reel_spin[table] = true
	var mats: Array = table.get_meta("reel_mats")
	while _reel_spin.get(table, false):
		for m in mats:
			m.uv1_offset.y = fposmod(m.uv1_offset.y + get_process_delta_time() * 2.6, 1.0)
		await get_tree().process_frame


## Chaque rouleau s'arrête sur son symbole, au milieu de la fenêtre, avec un petit rebond.
func _stop_reels(table: Node3D, line: Array) -> void:
	_reel_spin[table] = false
	var mats: Array = table.get_meta("reel_mats")
	for k in mats.size():
		var idx: int = SLOT.SYMBOLS.find(line[k])
		var target := fposmod(float(idx - 1) / 12.0, 1.0)
		var m: StandardMaterial3D = mats[k]
		var from := m.uv1_offset.y
		if target < from:
			target += 1.0
		var tw := create_tween()
		tw.tween_method(func(v: float): m.uv1_offset.y = fposmod(v, 1.0), from, target + 1.0, 0.35 + k * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


var _cards: Array[Node3D] = []
var _card_counts := {}
var _deal_queue := 0.0
var _hole: Node3D


func _clear_cards(_table_node: Node3D) -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_card_counts = {"player": 0, "dealer": 0}
	_deal_queue = 0.0
	_hole = null


func _card_mesh(c: Dictionary, hidden: bool) -> Node3D:
	var root := Node3D.new()
	var face := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.15, 0.004, 0.21)
	face.mesh = bm
	face.material_override = _std(Color(0.55, 0.06, 0.12) if hidden else Color(0.98, 0.97, 0.93), 0.4)
	root.add_child(face)
	var l := Label3D.new()
	l.font = Polices.texte()
	l.font_size = 64
	l.pixel_size = 0.0011
	l.rotation_degrees.x = -90
	l.position.y = 0.003
	l.outline_size = 0
	l.name = "Face"
	if not hidden:
		l.text = "%s\n%s" % [BLACKJACK.RANKS[c.r], BLACKJACK.SUITS[c.s]]
		l.modulate = Color(0.75, 0.05, 0.1) if c.s in [1, 2] else Color(0.08, 0.08, 0.1)
	root.add_child(l)
	return root


func _deal_card(table: Node3D, who: String, c: Dictionary, hidden: bool) -> void:
	var k: int = _card_counts.get(who, 0)
	_card_counts[who] = k + 1
	var card := _card_mesh(c, hidden)
	table.add_child(card)
	_cards.append(card)
	if hidden:
		_hole = card
	var start := Vector3(0.7, 1.0, -0.2)
	var dest := Vector3(-0.3 + k * 0.18, float(table.get_meta("felt_y", 0.78)) + 0.006, -0.25 if who == "dealer" else 0.6)
	card.position = start
	card.rotation_degrees.y = randf_range(-6, 6)
	var tw := create_tween()
	tw.tween_interval(_deal_queue)
	tw.tween_property(card, "position", dest, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_deal_queue += 0.18


func _reveal_hole(_table_node: Node3D, c: Dictionary) -> void:
	if _hole == null:
		return
	var face: MeshInstance3D = _hole.get_child(0)
	face.material_override = _std(Color(0.98, 0.97, 0.93), 0.4)
	var l: Label3D = _hole.get_node("Face")
	l.text = "%s\n%s" % [BLACKJACK.RANKS[c.r], BLACKJACK.SUITS[c.s]]
	l.modulate = Color(0.75, 0.05, 0.1) if c.s in [1, 2] else Color(0.08, 0.08, 0.1)


var _dice: Array[Node3D] = []


func _roll_dice(table: Node3D, values: Array) -> void:
	for d in _dice:
		d.queue_free()
	_dice.clear()
	for i in values.size():
		var die := Node3D.new()
		table.add_child(die)
		_dice.append(die)
		die.add_child(KIT.die(0.07, Color(0.96, 0.94, 0.88), Color(0.08, 0.08, 0.1)))
		var dest := Vector3(-0.3 + i * 0.16 + randf_range(-0.04, 0.04), float(table.get_meta("felt_y", 0.78)) + 0.035, randf_range(-0.15, 0.15))
		die.position = Vector3(0.9, 1.3, 0.4)
		die.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var final := Quaternion(KIT.die_basis(int(values[i]), randf_range(-0.4, 0.4)))
		var tw := create_tween().set_parallel()
		tw.tween_property(die, "position", dest, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		tw.tween_property(die, "quaternion", final, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


var _seated: Node


func _close_panel() -> void:
	_dim.visible = false
	if _seated:
		_seated.stand()
		_seated = null
	if _active_panel:
		_active_panel.queue_free()
		_active_panel = null
	player.frozen = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_played(bet: int, payout: int) -> void:
	Sfx.result(bet, payout)
	if _table and payout != bet:
		VILLAGER.crowd_react(get_tree(), _table.global_position, 3.0, "big" if payout >= bet * 10 and bet > 0 else ("win" if payout > bet else "lose"))
		# Le croupier ratisse les mises perdues ou distribue les gains.
		VILLAGER.dealer_gesture(get_tree(), _table.global_position, 3.0, "pay" if payout > bet else "rake")
	Game.cash_in(payout)
	_refresh_locks()
	if Game.advance_if_broke(1):
		_announce("La caisse vous avance %d crédits. « Un placement, ça se soutient. »" % Game.ADVANCE)


# --- Interface ------------------------------------------------------------------------

func _announce(text: String) -> void:
	_banner.text = text
	_toast.reset_size()
	var at := Vector2((get_viewport().get_visible_rect().size.x - _toast.size.x) / 2.0, get_viewport().get_visible_rect().size.y - _toast.size.y - 64.0)
	_toast.position = at + Vector2(0, 10)
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tw.parallel().tween_property(_toast, "position", at, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tw.tween_interval(3.5)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.8)


var _bark_timer := 5.0


## Les conversations de la salle : quelqu'un près de vous lâche une phrase, parfois une rumeur.
func _bark(delta: float) -> void:
	_bark_timer -= delta
	if _bark_timer > 0.0 or player == null:
		return
	_bark_timer = randf_range(8.0, 14.0)
	var near: Array = []
	for n in get_children():
		if n.has_method("say") and n.global_position.distance_to(player.global_position) < 8.0:
			near.append(n)
	if near.is_empty():
		return
	var v: Node = near.pick_random()
	if randf() < 0.35:
		for l in LOCKS:
			if Game.won < l.seuil:
				# « Les Salons particuliers » : le verbe s'accorde.
				v.say("Il paraît que %s %s à %s crédits gagnés. Ce n'est rien, pour un investisseur." % [l.name.substr(0, 1).to_lower() + l.name.substr(1), "ouvrent" if l.name.begins_with("Les ") else "ouvre", Game.fmt(l.seuil)])
				return
	v.say(Lines.line(v.speaker))


func _process(delta: float) -> void:
	_bark(delta)
	_shown = lerpf(_shown, Game.credits, 1.0 - exp(-10.0 * delta))
	if absf(_shown - Game.credits) < 0.5:
		_shown = Game.credits
	_credits_label.text = "%s crédits" % Game.fmt(roundi(_shown))
	_won_label.text = "Gagné au jeu : %s" % Game.fmt(Game.won) + ("
Dette au Crédit Smarvois : %s" % Game.fmt(Game.debt) if Game.debt > 0 else "")
	if player:
		var t: Node = player.focus_target
		_prompt.visible = t != null and _active_panel == null
		if t:
			_prompt.text = t.get_meta("prompt")
		var room := ""
		for r in ROOMS:
			var level := 1 if player.position.y > 3.0 else 0
			if (r[5] if r.size() > 5 else 0) == level and player.position.x > r[1] and player.position.x < r[2] and player.position.z > r[3] and player.position.z < r[4]:
				room = r[0]
		if room != _current_room:
			_current_room = room
			_room_label.text = room
			_room_label.modulate.a = 1.0
			var tw := create_tween()
			tw.tween_interval(2.0)
			tw.tween_property(_room_label, "modulate:a", 0.0, 1.2)


func _build_ui() -> void:
	# Les fenêtres à la manière d'Addict : laque sombre, filet d'or, angles arrondis, ombre portée ; le même
	# habillage que les communes reçoivent du socle (scripts/socle/tables.gd).
	var theme := Tables.theme()
	var gold_col := Color(0.96, 0.8, 0.45)

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(28, 24)
	root.add_child(top)
	var v := VBoxContainer.new()
	top.add_child(v)
	var title := Label.new()
	title.text = "C A S I N O   D E   S M A R V E S"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.75, 0.62, 0.45))
	v.add_child(title)
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 38)
	_credits_label.add_theme_color_override("font_color", gold_col)
	v.add_child(_credits_label)
	_won_label = Label.new()
	_won_label.add_theme_font_size_override("font_size", 16)
	v.add_child(_won_label)

	var cross := Label.new()
	cross.text = "·"
	cross.add_theme_font_size_override("font_size", 40)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position -= Vector2(5, 28)
	root.add_child(cross)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position.y += 40
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 6)
	root.add_child(_prompt)
	_room_label = Label.new()
	_room_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_room_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_room_label.position.y += 40
	_room_label.add_theme_font_size_override("font_size", 34)
	_room_label.add_theme_color_override("font_color", gold_col)
	_room_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_room_label.add_theme_constant_override("outline_size", 8)
	root.add_child(_room_label)
	# Les annonces (accueil, caisse, salle fermée) : une pastille laquée qui monte du bas, comme le
	# « toast » d'Addict.
	_toast = PanelContainer.new()
	BARRE.style(_toast)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 22)
	_banner.add_theme_color_override("font_color", Color(1, 0.92, 0.76))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_banner)
	root.add_child(_toast)
	var hint := Label.new()
	hint.text = "ZQSD : marcher   ·   souris : regarder   ·   E : jouer   ·   Échap : réglages"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6, 0.8))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.position.y -= 20
	root.add_child(hint)
	# Sous une fenêtre ouverte (caisse, Crédit Smarvois), la salle s'assombrit.
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.027, 0.035, 0.62)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	root.add_child(_dim)
	_panel_layer = CenterContainer.new()
	_panel_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_layer.anchor_top = 0.36
	_panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel_layer)


# --- Capture : godot -- --capture=chemin.png [--at=x,z,lacet,tangage] [--open=roulette] ---

func _maybe_capture() -> void:
	var path := ""
	var open := ""
	# Plusieurs captures à des instants donnés après le coup : sortie-1.png, sortie-2.png…
	var shots := [6.0]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
			if v.size() > 3:
				player.camera.rotation.x = deg_to_rad(v[3])
			if v.size() > 4:
				player.position.y = v[4]
		elif arg.begins_with("--open="):
			open = arg.trim_prefix("--open=")
		elif arg.begins_with("--shots="):
			shots = Array(arg.trim_prefix("--shots=").split_floats(","))
		elif arg.begins_with("--won="):
			Game.won = int(arg.trim_prefix("--won="))
			Game.staked = Game.won
			Game.credits += Game.won
			_refresh_locks(true)
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# La table à plusieurs, rejouée sur des vues du serveur enregistrées (tools/fixtures), sans réseau.
	if open == "poker-multi":
		_poker_essai = true
		open = "poker"
	if open != "":
		await get_tree().create_timer(1.0).timeout
		var target: Node = null
		for a in find_children("*", "Area3D", true, false):
			if str(a.get_meta("interact", "")) == open:
				target = a
				break
		if target == null:
			target = Node.new()
			target.set_meta("interact", open)
			add_child(target)
		_on_interact(target)
		# Joue un coup tout seul, pour voir l'animation de la table.
		await get_tree().create_timer(0.8).timeout
		var pnl := _active_panel
		if pnl:
			match open:
				"roulette":
					pnl._place_bet("red")
					for k in ["n17", "doz2", "n0", "n17", "col3"]:
						pnl._place_bet(k)
						await get_tree().create_timer(0.15).timeout
					pnl.spin()
				"blackjack":
					pnl.bet_index = 2
					# --sabot=8,8,A,6,… : les cartes de la donne, dans l'ordre (joueur, joueur, croupier, croupier, puis
					# les tirages), pour voir l'assurance et le partage.
					for arg in OS.get_cmdline_user_args():
						if arg.begins_with("--sabot="):
							var noms := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R"]
							var rang: Array = Array(arg.trim_prefix("--sabot=").split(",")).map(func(n): return {"r": noms.find(n), "s": randi() % 4})
							rang.reverse()
							var reste: Array = []
							for k in 80:
								reste.append({"r": 1 + k % 9, "s": k % 4})
							pnl.shoe = reste + rang
					_jouer_blackjack(pnl)
				"slot":
					pnl.spin()
				"dice":
					pnl._place("n3")
					pnl._roll()
				"craps":
					pnl._place("pass")
					pnl._roll()
				"baccara", "banco":
					pnl._place("joueur")
					pnl._deal()
				"roue", "boule":
					pnl._place("1")
					pnl._spin()
				"poker", "poker-miosson":
					if _poker_essai:
						_rejouer_poker(pnl)
					else:
						pnl._new_hand()
						_suivre_tout(pnl)
	var elapsed := 0.0
	for i in shots.size():
		await get_tree().create_timer(maxf(float(shots[i]) - elapsed, 0.0)).timeout
		elapsed = float(shots[i])
		await RenderingServer.frame_post_draw
		var out := path if shots.size() == 1 else path.get_basename() + "-%d.png" % (i + 1)
		get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()

## Pour les captures du blackjack : une donne, l'assurance si on la propose, le partage si on peut, puis
## on reste sur chaque main. Sans attendre : les captures se prennent pendant la donne.
func _jouer_blackjack(pnl: Control) -> void:
	pnl._start()
	await get_tree().create_timer(2.6).timeout
	if pnl.attente_assurance:
		pnl._on_insure()
		await get_tree().create_timer(1.2).timeout
	if pnl.peut_partager():
		pnl._on_split()
		await get_tree().create_timer(2.4).timeout
	for k in 4:
		if is_instance_valid(pnl) and pnl.in_hand:
			pnl._on_stand()
			await get_tree().create_timer(1.6).timeout


## Pour les captures du poker : le joueur suit tout, jusqu'à l'abattage.
func _suivre_tout(pnl: Control) -> void:
	for k in 600:
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(pnl):
			return
		if pnl._waiting_player:
			pnl._on_call()

# =====================================================================================
# L'ARCHITECTURE DU CASINO
# Le plan suit Addict, mais chaque pièce a désormais un sujet : le hall est une cage
# d'escalier d'honneur (escalier impérial vers les balcons), la salle des jeux s'organise
# autour d'un atrium ouvert sur la verrière, et chaque table a sa lampe, ses chaises et
# son tapis. Les murs sont rythmés par des pilastres, avec miroirs et tableaux entre eux.
# =====================================================================================

var lacquer: StandardMaterial3D
var leather: StandardMaterial3D
var mirror: StandardMaterial3D
var cream: StandardMaterial3D
var brass: StandardMaterial3D
var lamp_shade: StandardMaterial3D
var _slot_count := 0
var _paintings: Array[Texture2D] = []


func _extra_materials() -> void:
	lacquer = _std(Color(0.03, 0.025, 0.03), 0.08)
	leather = _std(Color(0.18, 0.06, 0.03), 0.45)
	mirror = _std(Color(0.9, 0.92, 0.95), 0.02, 1.0)
	cream = _std(Color(0.86, 0.8, 0.68), 0.7)
	brass = _std(Color(0.85, 0.62, 0.28), 0.35, 1.0)
	lamp_shade = _std(Color(0.12, 0.35, 0.18), 0.3)
	lamp_shade.emission_enabled = true
	lamp_shade.emission = Color(0.25, 0.6, 0.3)
	lamp_shade.emission_energy_multiplier = 0.6
	for k in 6:
		_paintings.append(Memo.image("casino", "res://scripts/casino_interior.gd", ["tableau", k], _make_painting.bind(k)))


# --- Briques d'architecture --------------------------------------------------------------

## Un mur : lambris d'acajou à panneaux moulurés, tenture damassée, plinthe, cimaise et corniche
## dorées, et des pilastres réguliers. Les ouvertures sont [centre le long du mur, largeur, hauteur].
## « decor » pose des miroirs et des tableaux entre les pilastres (côté « inside », +1 ou -1).
func _wall(a: Vector3, b: Vector3, openings: Array = [], h := WALL_H, y0 := 0.0, decor := 0) -> void:
	var length := a.distance_to(b)
	var dir := (b - a).normalized()
	var normal_rot := atan2(dir.x, dir.z)
	var cuts := openings.duplicate()
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var start := 0.0
	var pieces := []
	for o in cuts:
		pieces.append([start, o[0] - o[1] / 2.0, h, 0.0])
		pieces.append([o[0] - o[1] / 2.0, o[0] + o[1] / 2.0, h - o[2], o[2]])
		start = o[0] + o[1] / 2.0
	pieces.append([start, length, h, 0.0])
	for p in pieces:
		var w: float = p[1] - p[0]
		if w <= 0.01 or p[2] <= 0.01:
			continue
		var mid: float = (p[0] + p[1]) / 2.0
		var base: float = p[3]
		var seg := Node3D.new()
		seg.position = a + dir * mid + Vector3(0, y0, 0)
		seg.rotation.y = normal_rot + PI / 2.0
		add_child(seg)
		_box(Vector3(w, p[2], 0.2), Vector3(0, base + p[2] / 2.0, 0), damask, true, seg)
		for side in [-1.0, 1.0]:
			if base == 0.0:
				# Lambris : socle sombre, panneaux en relief, cimaise dorée.
				_box(Vector3(w, 1.05, 0.05), Vector3(0, 0.525, side * 0.125), wood, false, seg)
				_box(Vector3(w, 0.16, 0.08), Vector3(0, 0.08, side * 0.14), dark_wood, false, seg)
				_box(Vector3(w, 0.06, 0.09), Vector3(0, 1.08, side * 0.145), gold, false, seg)
				var n := int(w / 0.9)
				for k in n:
					var px := -w / 2.0 + (k + 0.5) * w / n
					_box(Vector3(w / n - 0.16, 0.62, 0.02), Vector3(px, 0.58, side * 0.155), dark_wood, false, seg)
			_box(Vector3(w, 0.14, 0.14), Vector3(0, h - 0.07, side * 0.16), gold, false, seg)
			_box(Vector3(w, 0.1, 0.22), Vector3(0, h - 0.2, side * 0.2), dark_wood, false, seg)
	# Pilastres réguliers, sans tomber dans les ouvertures.
	var count := int(length / 3.6)
	for k in range(1, count + 1):
		var t := k * length / (count + 1)
		var blocked := false
		for o in cuts:
			if absf(t - float(o[0])) < float(o[1]) / 2.0 + 0.5:
				blocked = true
		if blocked:
			continue
		var pil := Node3D.new()
		pil.position = a + dir * t + Vector3(0, y0, 0)
		pil.rotation.y = normal_rot + PI / 2.0
		add_child(pil)
		for side in [-1.0, 1.0]:
			_box(Vector3(0.38, h - 0.4, 0.1), Vector3(0, (h - 0.4) / 2.0 + 0.1, side * 0.17), cream, false, pil)
			_box(Vector3(0.46, 0.22, 0.14), Vector3(0, h - 0.4, side * 0.19), gold, false, pil)
			_box(Vector3(0.46, 0.2, 0.14), Vector3(0, 0.1, side * 0.19), dark_wood, false, pil)
			for f in 3:
				_box(Vector3(0.03, h - 1.0, 0.02), Vector3(-0.1 + f * 0.1, h / 2.0, side * 0.225), gold, false, pil)
	# Miroirs et tableaux entre les pilastres.
	if decor != 0 and count > 0:
		for k in range(0, count + 1):
			var t := (k + 0.5) * length / (count + 1)
			var blocked := false
			for o in cuts:
				if absf(t - float(o[0])) < float(o[1]) / 2.0 + 0.9:
					blocked = true
			if blocked or h < 3.6:
				continue
			var frame := Node3D.new()
			frame.position = a + dir * t + Vector3(0, y0, 0)
			frame.rotation.y = normal_rot + PI / 2.0 + (0.0 if decor > 0 else PI)
			add_child(frame)
			if k % 2 == 0:
				_mirror(frame, Vector3(0, 2.25, 0.2), Vector2(1.1, 1.7))
			else:
				_painting(frame, Vector3(0, 2.2, 0.2), Vector2(1.3, 0.95), _paintings[(k + int(t)) % _paintings.size()])
	# Encadrements des ouvertures : chambranle sombre, fronton doré.
	for o in cuts:
		var c := a + dir * float(o[0])
		var fr := Node3D.new()
		fr.position = c + Vector3(0, y0, 0)
		fr.rotation.y = normal_rot + PI / 2.0
		add_child(fr)
		for s in [-1.0, 1.0]:
			_box(Vector3(0.22, o[2], 0.34), Vector3(s * (o[1] / 2.0 + 0.11), o[2] / 2.0, 0), dark_wood, false, fr)
			_box(Vector3(0.08, o[2] - 0.2, 0.36), Vector3(s * (o[1] / 2.0 + 0.05), o[2] / 2.0, 0), gold, false, fr)
		_box(Vector3(o[1] + 0.5, 0.24, 0.38), Vector3(0, o[2] + 0.12, 0), dark_wood, false, fr)
		_box(Vector3(o[1] + 0.6, 0.06, 0.4), Vector3(0, o[2] + 0.27, 0), gold, false, fr)
		if o[2] < h - 0.9:
			var crest := _cyl(0.22, 0.06, Vector3(0, o[2] + 0.55, 0.0), gold, fr)
			crest.rotation_degrees.x = 90


func _mirror(parent: Node3D, at: Vector3, size: Vector2) -> void:
	_box(Vector3(size.x + 0.2, size.y + 0.2, 0.05), at, gold, false, parent)
	_box(Vector3(size.x, size.y, 0.02), at + Vector3(0, 0, 0.03), mirror, false, parent)
	# Un laiton satiné : poli, le cimier renvoyait le lustre en un point qui bavait sur le palier.
	var satin: StandardMaterial3D = gold.duplicate()
	satin.roughness = 0.7
	satin.metallic = 0.4
	var crest := _cyl(0.16, 0.06, at + Vector3(0, size.y / 2.0 + 0.16, 0.0), satin, parent)
	crest.rotation_degrees.x = 90


func _painting(parent: Node3D, at: Vector3, size: Vector2, tex: Texture2D) -> void:
	_box(Vector3(size.x + 0.24, size.y + 0.24, 0.06), at, gold, false, parent)
	_box(Vector3(size.x + 0.08, size.y + 0.08, 0.07), at, dark_wood, false, parent)
	var canvas := _std(Color.WHITE, 0.8)
	canvas.albedo_texture = tex
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	q.mesh = qm
	q.material_override = canvas
	q.position = at + Vector3(0, 0, 0.04)
	parent.add_child(q)
	# Petite rampe de lumière au-dessus du tableau.
	_box(Vector3(0.5, 0.04, 0.12), at + Vector3(0, size.y / 2.0 + 0.2, 0.1), brass, false, parent)


## Un « tableau à l'huile » : un paysage du Poitou tiré du hasard, coucher de soleil sur les champs.
func _make_painting(seed_value: int) -> Image:
	var w := 192
	var h := 144
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.04
	var sky_top := Color.from_hsv(rng.randf_range(0.55, 0.7), 0.5, 0.45)
	var sky_low := Color.from_hsv(rng.randf_range(0.03, 0.12), 0.6, 0.95)
	var horizon := int(h * rng.randf_range(0.45, 0.62))
	for y in h:
		for x in w:
			var c: Color
			if y < horizon:
				c = sky_top.lerp(sky_low, float(y) / horizon)
				c = c.lerp(Color(1, 0.9, 0.7), maxf(0.0, noise.get_noise_2d(x * 0.6, y * 2.0)) * 0.4)
			else:
				var hill := noise.get_noise_2d(x * 1.5, 50.0) * 10.0
				var band := int((y - horizon + hill) / 9.0)
				c = [Color(0.35, 0.42, 0.18), Color(0.55, 0.48, 0.2), Color(0.28, 0.35, 0.16), Color(0.62, 0.5, 0.25)][absi(band) % 4]
				c = c.darkened(0.25 * float(y - horizon) / (h - horizon))
			# Touche de peinture : un grain de pinceau.
			c = c.lightened(noise.get_noise_2d(x * 6.0, y * 6.0) * 0.08)
			img.set_pixel(x, y, c)
	# Un clocher ou un moulin, parfois.
	if rng.randf() < 0.6:
		var bx := rng.randi_range(20, w - 40)
		for y in range(horizon - 30, horizon + 4):
			for x in range(bx, bx + 8):
				img.set_pixel(x, y, Color(0.2, 0.15, 0.15))
	return img


func _floor(x0: float, x1: float, z0: float, z1: float, mat: Material, h := WALL_H, coffers := true, y0 := 0.0) -> void:
	_box(Vector3(x1 - x0, 0.1, z1 - z0), Vector3((x0 + x1) / 2.0, y0 - 0.05, (z0 + z1) / 2.0), mat, true)
	_ceiling(x0, x1, z0, z1, y0 + h, coffers)


## Un plafond à caissons : poutres sombres filetées d'or, panneaux crème, rosaces dorées.
func _ceiling(x0: float, x1: float, z0: float, z1: float, y: float, coffers := true) -> void:
	_box(Vector3(x1 - x0, 0.1, z1 - z0), Vector3((x0 + x1) / 2.0, y + 0.05, (z0 + z1) / 2.0), cream, false)
	if not coffers:
		return
	var step := 2.4
	var nx := maxi(1, int((x1 - x0) / step))
	var nz := maxi(1, int((z1 - z0) / step))
	var sx := (x1 - x0) / nx
	var sz := (z1 - z0) / nz
	for i in range(1, nx):
		var x := x0 + i * sx
		_box(Vector3(0.22, 0.32, z1 - z0), Vector3(x, y - 0.16, (z0 + z1) / 2.0), dark_wood)
		_box(Vector3(0.24, 0.03, z1 - z0), Vector3(x, y - 0.33, (z0 + z1) / 2.0), gold)
	for j in range(1, nz):
		var z := z0 + j * sz
		_box(Vector3(x1 - x0, 0.32, 0.22), Vector3((x0 + x1) / 2.0, y - 0.16, z), dark_wood)
		_box(Vector3(x1 - x0, 0.03, 0.24), Vector3((x0 + x1) / 2.0, y - 0.33, z), gold)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.12
	s.is_hemisphere = true
	s.material = gold
	mm.mesh = s
	mm.instance_count = nx * nz
	var k := 0
	for i in nx:
		for j in nz:
			mm.set_instance_transform(k, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(x0 + (i + 0.5) * sx, y, z0 + (j + 0.5) * sz)))
			k += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	# Corniche périphérique.
	for side in [[Vector3(x1 - x0, 0.3, 0.3), Vector3((x0 + x1) / 2.0, y - 0.15, z0 + 0.15)], [Vector3(x1 - x0, 0.3, 0.3), Vector3((x0 + x1) / 2.0, y - 0.15, z1 - 0.15)],
			[Vector3(0.3, 0.3, z1 - z0), Vector3(x0 + 0.15, y - 0.15, (z0 + z1) / 2.0)], [Vector3(0.3, 0.3, z1 - z0), Vector3(x1 - 0.15, y - 0.15, (z0 + z1) / 2.0)]]:
		_box(side[0], side[1], dark_wood)


## Un lustre de cristal : armature dorée, trois couronnes de bougies, pampilles qui scintillent.
func _chandelier(pos: Vector3, size := 1.0, shadows := false) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	_cyl(0.025 * size, 1.4 * size, Vector3(0, 0.7 * size, 0), gold, root)
	var body := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.16 * size
	bs.height = 0.42 * size
	body.mesh = bs
	body.material_override = gold
	body.position.y = -0.1 * size
	root.add_child(body)
	var crystal := _std(Color(0.95, 0.97, 1.0, 0.55), 0.02)
	crystal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal.emission_enabled = true
	crystal.emission = Color(1.0, 0.9, 0.75)
	crystal.emission_energy_multiplier = 0.8
	var drop := CylinderMesh.new()
	drop.top_radius = 0.0
	drop.bottom_radius = 0.025 * size
	drop.height = 0.09 * size
	drop.radial_segments = 4
	drop.material = crystal
	var drops := MultiMesh.new()
	drops.transform_format = MultiMesh.TRANSFORM_3D
	drops.mesh = drop
	var transforms: Array[Transform3D] = []
	for ring in 3:
		var r := (0.85 - ring * 0.24) * size
		var y := -ring * 0.3 * size
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.025 * size
		tm.outer_radius = r
		t.mesh = tm
		t.material_override = gold
		t.position.y = y
		root.add_child(t)
		var count := 14 - ring * 4
		for k in count:
			var a := TAU * k / count
			var p := Vector3(cos(a) * r, y + 0.06 * size, sin(a) * r)
			_cyl(0.015 * size, 0.12 * size, p, cream, root)
			var flame := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.028 * size
			fm.height = 0.07 * size
			flame.mesh = fm
			flame.material_override = brass_glow
			flame.position = p + Vector3(0, 0.09 * size, 0)
			root.add_child(flame)
			for d in 3:
				transforms.append(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(cos(a + d * 0.15) * (r + 0.02), y - 0.06 * size - d * 0.07 * size, sin(a + d * 0.15) * (r + 0.02))))
	for d in 10:
		var a := TAU * d / 10.0
		transforms.append(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(cos(a) * 0.12 * size, -0.95 * size - (d % 3) * 0.05 * size, sin(a) * 0.12 * size)))
	drops.instance_count = transforms.size()
	for i in transforms.size():
		drops.set_instance_transform(i, transforms[i])
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = drops
	root.add_child(dmi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.52)
	# Les grands lustres ne montent pas en proportion : au-delà, ils brûlaient les murs proches.
	light.light_energy = 4.0 * size if size <= 1.0 else 4.0 + 1.5 * (size - 1.0)
	light.omni_range = 10.0 * size
	light.shadow_enabled = shadows
	light.light_volumetric_fog_energy = 0.25
	# Sous la coupe, assez bas pour ne pas brûler le plafond tout proche (dessous des galeries).
	light.position.y = -0.4 * size - 0.25
	# Peu de reflet direct : poli, le bandeau de la galerie renvoyait le grand lustre en une tache
	# brillante au-dessus de la porte du palier.
	light.light_specular = 0.15
	root.add_child(light)


## La lampe de table des casinos : une hotte de laiton suspendue, verre vert dessous, lumière franche sur le tapis.
func _table_lamp(pos: Vector3, length: float, rot_y := 0.0, energy := 3.5) -> void:
	var root := _node(pos)
	root.rotation_degrees.y = rot_y
	for s in [-1.0, 1.0]:
		_cyl(0.01, WALL_H - pos.y, Vector3(s * length * 0.35, (WALL_H - pos.y) / 2.0, 0), brass, root)
	_box(Vector3(length, 0.14, 0.42), Vector3(0, 0, 0), brass, false, root)
	_box(Vector3(length - 0.06, 0.04, 0.36), Vector3(0, -0.08, 0), lamp_shade, false, root)
	for k in 3:
		var s := SpotLight3D.new()
		s.light_color = Color(1.0, 0.86, 0.66)
		s.light_energy = energy
		s.spot_range = 3.0
		s.spot_angle = 50.0
		s.spot_attenuation = 0.6
		s.light_volumetric_fog_energy = 0.4
		s.position = Vector3((k - 1) * length * 0.33, -0.1, 0)
		s.rotation_degrees.x = -90
		root.add_child(s)


## Une colonne de marbre à base et chapiteau dorés.
func _column(at: Vector3, h: float, r := 0.3) -> void:
	_cyl(r, h - 0.7, at + Vector3(0, (h - 0.7) / 2.0 + 0.35, 0), marble_white)
	_box(Vector3(r * 2.6, 0.2, r * 2.6), at + Vector3(0, 0.1, 0), dark_wood, true)
	_cyl(r * 1.25, 0.15, at + Vector3(0, 0.27, 0), gold)
	_cyl(r * 1.1, 0.2, at + Vector3(0, h - 0.45, 0), gold, self, r * 1.5)
	_box(Vector3(r * 3.2, 0.16, r * 3.2), at + Vector3(0, h - 0.27, 0), gold)
	_solid_cyl(at + Vector3(0, h / 2.0, 0), r + 0.05, h)


func _solid_cyl(at: Vector3, r: float, h: float) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	body.add_child(cs)
	body.position = at
	add_child(body)


func _solid(size: Vector3, at: Vector3, rot_y := 0.0) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	body.position = at
	body.rotation.y = rot_y
	add_child(body)


## Une rampe : balustres dorés, main courante, et un obstacle invisible pour ne pas tomber.
func _railing(a: Vector3, b: Vector3, h := 1.0) -> void:
	var length := a.distance_to(b)
	var n := int(length / 0.22)
	var d := b - a
	for k in n + 1:
		var p := a + d * (float(k) / n)
		_cyl(0.022, h - 0.08, p + Vector3(0, (h - 0.08) / 2.0, 0), gold)
	var rail := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(0.09, 0.07, length)
	rail.mesh = rb
	rail.material_override = dark_wood
	add_child(rail)
	rail.look_at_from_position((a + b) / 2.0 + Vector3(0, h, 0), b + Vector3(0, h, 0), Vector3.UP)
	var base := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.1, 0.06, length)
	base.mesh = bb
	base.material_override = gold
	add_child(base)
	base.look_at_from_position((a + b) / 2.0 + Vector3(0, 0.03, 0), b + Vector3(0, 0.03, 0), Vector3.UP)
	# L'obstacle reste vertical, même le long d'une volée : un mur fin qui couvre toute la pente.
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.12, absf(b.y - a.y) + 1.4, flat.length())
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	body.position = Vector3((a.x + b.x) / 2.0, (a.y + b.y) / 2.0 + 0.7, (a.z + b.z) / 2.0)
	body.rotation.y = atan2(flat.x, flat.y)


## Un escalier droit, de « from » (en bas) à « to » (en haut, plus haut de « rise »), de largeur « width ».
## Marches de marbre, tapis rouge, limons d'acajou ; la pente se marche (rampe invisible).
func _stair(from: Vector3, to: Vector3, width: float, rails := [true, true], soffit := false, filled := false) -> void:
	var rise := to.y - from.y
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var run := flat.length()
	var steps := int(round(rise / 0.17))
	var dir := flat.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var yaw := atan2(dir.x, dir.z)
	var runner := _shader("res://shaders/carpet.gdshader", {"scale": 0.5})
	for i in steps:
		var y := from.y + rise * (i + 1) / steps
		var c := from + dir * (run * (i + 0.5) / steps)
		var step := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(width, 0.06, run / steps + 0.03)
		step.mesh = sm
		step.material_override = marble_white
		step.position = Vector3(c.x, y - 0.03, c.z)
		step.rotation.y = yaw
		add_child(step)
		var riser := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(width, rise / steps, 0.03)
		riser.mesh = rm
		riser.material_override = cream
		riser.position = Vector3(c.x, y - rise / steps / 2.0, c.z) - dir * (run / steps / 2.0)
		riser.rotation.y = yaw
		add_child(riser)
		var carpet_step := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(width * 0.7, 0.012, run / steps + 0.03)
		carpet_step.mesh = cm
		carpet_step.material_override = runner
		carpet_step.position = Vector3(c.x, y + 0.006, c.z)
		carpet_step.rotation.y = yaw
		add_child(carpet_step)
	if filled:
		# Volée pleine jusqu'au sol, habillée d'acajou.
		for i in steps:
			var y := from.y + rise * (i + 1) / steps
			var c := from + dir * (run * (i + 0.5) / steps)
			var fill := MeshInstance3D.new()
			var fb := BoxMesh.new()
			fb.size = Vector3(width + 0.28, y - 0.06, run / steps + 0.02)
			fill.mesh = fb
			fill.material_override = dark_wood
			fill.position = Vector3(c.x, (y - 0.06) / 2.0, c.z)
			fill.rotation.y = yaw
			add_child(fill)
	if soffit:
		# Sous-face : un plafond rampant crème, filet d'or.
		var sof := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(width + 0.28, 0.12, sqrt(run * run + rise * rise))
		sof.mesh = sb
		sof.material_override = cream
		add_child(sof)
		var mid := (from + to) / 2.0 + Vector3(0, -0.32, 0)
		sof.look_at_from_position(mid, mid + (to - from), Vector3.UP)
	# Limons (côtés) d'acajou.
	for s in [-1.0, 1.0]:
		var string := MeshInstance3D.new()
		var stm := BoxMesh.new()
		stm.size = Vector3(0.14, 0.4, sqrt(run * run + rise * rise))
		string.mesh = stm
		string.material_override = dark_wood
		add_child(string)
		var mid: Vector3 = (from + to) / 2.0 + side * s * (width / 2.0 + 0.07)
		string.look_at_from_position(mid, mid + (to - from), Vector3.UP)
	# La pente qu'on marche.
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.1, sqrt(run * run + rise * rise) + 0.2)
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	body.look_at_from_position((from + to) / 2.0 + Vector3(0, -0.05, 0), to + Vector3(0, -0.05, 0), Vector3.UP)
	for s in [0, 1]:
		if rails[s]:
			var off := side * (1.0 if s == 0 else -1.0) * (width / 2.0 + 0.07)
			_railing(from + off + dir * 0.4 + Vector3(0, rise * 0.4 / run, 0), to + off, 0.95)


# --- La coque ------------------------------------------------------------------------

func _build_shell() -> void:
	_floor(-3, 3, 18, 22, floor_marble, 4.0, false)
	_floor(-10, 10, 6, 18, floor_marble, UP + 4.5)
	_floor(10, 20, 6, 18, carpet, 4.5)
	_box(Vector3(28, 0.1, 20), Vector3(0, -0.05, -4), carpet, true)
	_floor(14, 26, -14, 6, carpet_blue)
	_floor(-26, -14, -14, 0, carpet_blue, 4.6)
	_floor(-15, -10, 12, 18, carpet, 3.6, false)
	# Sas et façade.
	_wall(Vector3(-3, 0, 22), Vector3(3, 0, 22), [[3.0, 2.2, 3.0]], 4.0)
	_wall(Vector3(-3, 0, 18), Vector3(-3, 0, 22), [], 4.0)
	_wall(Vector3(3, 0, 18), Vector3(3, 0, 22), [], 4.0)
	# Hall sur deux niveaux.
	_wall(Vector3(-10, 0, 18), Vector3(10, 0, 18), [[10.0, 3.4, 3.4]], UP, 0.0, 1)
	_wall(Vector3(-10, 0, 18), Vector3(10, 0, 18), [], 4.5, UP, 1)
	_wall(Vector3(-10, 0, 6), Vector3(-10, 0, 18), [[9.0, 2.6, 3.0]], UP, 0.0)
	_wall(Vector3(-10, 0, 6), Vector3(-10, 0, 18), [], 4.5, UP, 1)
	_wall(Vector3(10, 0, 6), Vector3(10, 0, 18), [[6.0, 4.0, 3.6]], UP, 0.0)
	_wall(Vector3(10, 0, 6), Vector3(10, 0, 18), [], 4.5, UP, -1)
	# Mur nord du hall : deux portes vers la salle des jeux (sous les volées), deux portes à l'étage.
	_wall(Vector3(-14, 0, 6), Vector3(26, 0, 6), [[8.7, 2.4, 2.8], [19.3, 2.4, 2.8], [29.0, 2.0, 2.8]], WALL_H)
	_box(Vector3(20.0, UP - WALL_H, 0.2), Vector3(0, (WALL_H + UP) / 2.0, 6.0), dark_wood, true)
	# Vestiaire.
	_wall(Vector3(-15, 0, 12), Vector3(-15, 0, 18), [], 3.6)
	_wall(Vector3(-15, 0, 12), Vector3(-10, 0, 12), [], 3.6)
	_wall(Vector3(-15, 0, 18), Vector3(-10, 0, 18), [], 3.6)
	# Bar.
	_wall(Vector3(10, 0, 18), Vector3(20, 0, 18), [], 4.5, 0.0, 1)
	_wall(Vector3(20, 0, 6), Vector3(20, 0, 18), [], 4.5, 0.0, -1)
	# Salle des jeux, Ambassadeurs, salon.
	_wall(Vector3(-14, 0, -14), Vector3(-14, 0, 6), [[7.0, 2.0, 2.8]], WALL_H, 0.0, 1)
	_wall(Vector3(14, 0, -14), Vector3(14, 0, 6), [[10.0, 5.0, 3.8]], WALL_H)
	_wall(Vector3(-26, 0, -14), Vector3(26, 0, -14), [], WALL_H, 0.0, -1)
	_wall(Vector3(26, 0, -14), Vector3(26, 0, 6), [], WALL_H, 0.0, -1)
	_wall(Vector3(-26, 0, -14), Vector3(-26, 0, 0), [], 4.6, 0.0, 1)
	_wall(Vector3(-26, 0, 0), Vector3(-14, 0, 0), [], 4.6, 0.0, 1)
	# Dalle entre les deux niveaux, au-dessus des salles, percée par l'atrium.
	var slab_y := (WALL_H + UP) / 2.0
	var slab_h := UP - WALL_H
	_box(Vector3(40.0, slab_h, 5.0), Vector3(6.0, slab_y, -11.5), dark_wood)
	_box(Vector3(40.0, slab_h, 7.0), Vector3(6.0, slab_y, 2.5), dark_wood)
	_box(Vector3(9.0, slab_h, 8.0), Vector3(-9.5, slab_y, -5.0), dark_wood)
	_box(Vector3(21.0, slab_h, 8.0), Vector3(15.5, slab_y, -5.0), dark_wood)
	# Porte à tambour vers la place du village.
	var door := Node3D.new()
	door.position = Vector3(0, 0, 21.8)
	add_child(door)
	_cyl(1.0, 2.8, Vector3(0, 1.4, 0), _glass(), door)
	_cyl(1.05, 0.12, Vector3(0, 2.86, 0), gold, door)
	for k in 4:
		var leaf := _box(Vector3(1.9, 2.6, 0.04), Vector3(0, 1.4, 0), _glass(), false, door)
		leaf.rotation.y = k * PI / 4.0
	_label("Sortie · Place de la Mairie", Vector3(0, 3.3, -0.3), 180.0, 48, Color(1.0, 0.85, 0.5), door)
	_interactive(door, "exit", "E : sortir sur la place", Vector3(2.0, 2.8, 0.6), Vector3(0, 1.4, -0.8))
	for x in [-2.3, 2.3]:
		_place("res://assets/kenney/furniture/pottedPlant.glb", Vector3(x, 0, 19.0), 3.2)
		_sconce(Vector3(x * 1.25, 2.4, 18.15), 0.0)


# --- Le hall d'honneur : un escalier impérial et ses balcons ------------------------------

func _build_hall() -> void:
	var h1 := UP / 2.0
	# Médaillon de marbre au sol, et tapis rouge de la porte au pied de l'escalier.
	var medal := MeshInstance3D.new()
	var md := CylinderMesh.new()
	md.top_radius = 2.2
	md.bottom_radius = 2.2
	md.height = 0.01
	md.radial_segments = 64
	medal.mesh = md
	var mm := _std(Color.WHITE, 0.15)
	mm.albedo_texture = Memo.image("casino", "res://scripts/casino_interior.gd", "rose", _compass_texture)
	medal.material_override = mm
	medal.position = Vector3(0, 0.006, 15.6)
	add_child(medal)
	var runner := _shader("res://shaders/carpet.gdshader", {"scale": 0.6})
	_box(Vector3(2.6, 0.02, 4.6), Vector3(0, 0.012, 15.7), runner)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.08, 0.025, 4.6), Vector3(s * 1.34, 0.013, 15.7), gold)

	# L'escalier impérial : une volée centrale jusqu'au palier, puis deux volées vers les balcons.
	_stair(Vector3(0, 0, 13.2), Vector3(0, h1, 8.7), 4.0, [true, true], false, true)
	_box(Vector3(6.6, h1, 2.6), Vector3(0, h1 / 2.0, 7.4), dark_wood, true)
	_box(Vector3(6.6, 0.06, 2.6), Vector3(0, h1 + 0.03, 7.4), marble_white)
	_box(Vector3(4.6, 0.014, 2.4), Vector3(0, h1 + 0.065, 7.4), runner)
	for s in [-1.0, 1.0]:
		_stair(Vector3(s * 3.3, h1, 7.35), Vector3(s * 7.6, UP, 7.35), 2.3, [s > 0, s < 0], true)
		# Garde-corps du palier, de part et d'autre de la volée centrale.
		_railing(Vector3(s * 2.15, h1, 8.65), Vector3(s * 3.3, h1, 8.65))
		# Grands candélabres au pied de l'escalier.
		var cand := _node(Vector3(s * 2.45, 0, 13.4))
		_box(Vector3(0.6, 1.0, 0.6), Vector3(0, 0.5, 0), marble_white, true, cand)
		_box(Vector3(0.66, 0.08, 0.66), Vector3(0, 1.02, 0), gold, false, cand)
		_cyl(0.04, 1.3, Vector3(0, 1.7, 0), gold, cand)
		for k in 5:
			var a := TAU * k / 5.0
			_cyl(0.025, 0.2, Vector3(cos(a) * 0.25, 2.4, sin(a) * 0.25), cream, cand)
			var fl := _cyl(0.035, 0.08, Vector3(cos(a) * 0.25, 2.55, sin(a) * 0.25), brass_glow, cand)
			fl.name = "Flamme"
		var cl := OmniLight3D.new()
		cl.light_color = Color(1.0, 0.75, 0.45)
		cl.light_energy = 1.6
		cl.omni_range = 5.0
		cl.position = Vector3(0, 2.6, 0)
		cand.add_child(cl)
	# Sous les volées supérieures : deux passages vers les portes de la salle des jeux.
	for s in [-1.0, 1.0]:
		_label("Salle des jeux", Vector3(s * 5.3, 3.28, 6.13), 0.0, 32, Color(1.0, 0.86, 0.55))

	# Les balcons, de chaque côté, portés par des colonnes ; ils mènent aux portes de l'étage.
	for s in [-1.0, 1.0]:
		_box(Vector3(2.4, 0.35, 11.8), Vector3(s * 8.8, UP - 0.175, 12.1), dark_wood, true)
		_box(Vector3(2.4, 0.02, 11.8), Vector3(s * 8.8, UP + 0.01, 12.1), carpet)
		_box(Vector3(0.12, 0.3, 11.8), Vector3(s * 7.56, UP - 0.3, 12.1), gold)
		_railing(Vector3(s * 7.62, UP, 8.55), Vector3(s * 7.62, UP, 17.9))
		for z in [10.3, 13.3, 16.3]:
			_column(Vector3(s * 7.6, 0, z), UP - 0.35, 0.26)
			_column(Vector3(s * 7.6, UP, z), 4.5, 0.2)
	# Le nom de la maison au-dessus du palier.
	_label("CASINO DE SMARVES", Vector3(0, UP + 1.2, 6.13), 0.0, 130)
	_label("Le jeu est un investissement", Vector3(0, UP + 0.55, 6.13), 0.0, 60, Color(0.92, 0.84, 0.66))
	_mirror(_node(Vector3(0, h1, 6.1)), Vector3(0, 1.4, 0.05), Vector2(2.4, 1.6))
	_chandelier(Vector3(0, UP + 2.9, 12.6), 2.4)
	_chandelier(Vector3(0, 3.1, 20.0), 0.6)

	# La réception, sous le balcon est : comptoir de marbre et de bronze, deux hôtesses.
	var desk := _node(Vector3(8.4, 0, 15.3))
	_box(Vector3(0.9, 1.1, 3.6), Vector3(0, 0.55, 0), marble_white, true, desk)
	_box(Vector3(1.05, 0.08, 3.75), Vector3(0, 1.14, 0), dark_wood, false, desk)
	for k in 4:
		_box(Vector3(0.04, 0.8, 0.5), Vector3(-0.46, 0.55, -1.3 + k * 0.87), gold, false, desk)
	_cyl(0.06, 0.4, Vector3(0, 1.38, 1.4), brass, desk)
	_cyl(0.18, 0.2, Vector3(0, 1.62, 1.4), lamp_shade, desk, 0.1)
	_label("Réception", Vector3(-0.48, 1.6, 0), -90.0, 64, Color(1.0, 0.86, 0.55), desk)
	_person("hotesse-1", Vector3(9.3, 0, 14.4), -90.0, "idle", "collier")
	_person("hotesse-2", Vector3(9.3, 0, 16.2), -90.0, "idle", "collier")
	_interactive(desk, "reception", "E : parler à la réception", Vector3(1.6, 2.0, 3.6), Vector3(-0.6, 1.0, 0))

	# Sous le balcon ouest : banquettes, palmiers, guéridon.
	for z in [9.3, 11.6]:
		_banquette(Vector3(-9.35, 0, z), 90.0)
	_cyl(0.35, 0.65, Vector3(-8.4, 0.33, 10.45), dark_wood)
	_cyl(0.42, 0.04, Vector3(-8.4, 0.67, 10.45), marble_white)
	for p in [Vector3(-4.4, 0, 13.0), Vector3(4.4, 0, 13.0), Vector3(-9.3, 0, 17.3), Vector3(9.3, 0, 8.2), Vector3(-6.6, 0, 6.8), Vector3(6.6, 0, 6.8)]:
		_place("res://assets/kenney/furniture/pottedPlant.glb", p, 3.4)
	for z in [8.0, 17.0]:
		_sconce(Vector3(-9.85, 2.6, z), 90.0)
	_sconce(Vector3(9.85, 2.6, 8.2), -90.0)
	# Des clients qui conversent au pied de l'escalier.
	_person("character-male-b.glb", Vector3(-1.6, 0, 16.6), 160.0)
	_person("character-female-a.glb", Vector3(-0.9, 0, 15.9), -40.0)
	_person("character-male-d.glb", Vector3(5.6, 0, 11.0), -60.0)
	_build_cloakroom()


func _build_cloakroom() -> void:
	# Le vestiaire : un comptoir, des rangées de manteaux, une préposée.
	_box(Vector3(0.7, 1.05, 4.4), Vector3(-11.4, 0.525, 15.0), dark_wood, true)
	_box(Vector3(0.8, 0.06, 4.5), Vector3(-11.4, 1.08, 15.0), marble_white)
	_label("Vestiaire", Vector3(-10.06, 3.25, 15.0), 90.0, 56)
	var coats := [Color(0.1, 0.1, 0.12), Color(0.35, 0.25, 0.18), Color(0.45, 0.05, 0.08), Color(0.2, 0.22, 0.3), Color(0.6, 0.55, 0.45)]
	for row in 2:
		var x := -13.3 - row * 1.1
		_cyl(0.02, 4.8, Vector3(x, 2.1, 15.0), brass).rotation_degrees.x = 90
		for k in 14:
			var coat := _box(Vector3(0.14, 1.0, 0.3), Vector3(x, 1.55, 12.8 + k * 0.32), _std(coats[(k + row * 3) % coats.size()], 0.8))
			coat.rotation_degrees.y = randf_range(-12, 12)
	_person("preposee-vestiaire", Vector3(-12.2, 0, 15.6), 90.0, "idle", "collier")
	_chandelier(Vector3(-12.5, 3.2, 15.0), 0.5)


func _compass_texture() -> Image:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var c := Vector2(s / 2.0, s / 2.0)
	for y in s:
		for x in s:
			var d := Vector2(x, y) - c
			var r := d.length() / (s / 2.0)
			var a := atan2(d.y, d.x)
			var col := Color(0.93, 0.9, 0.84)
			var star := absf(cos(a * 4.0))
			if r < 0.15:
				col = Color(0.75, 0.55, 0.25)
			elif r < 0.9 * pow(star, 3.0) + 0.1 and r < 0.92:
				col = Color(0.12, 0.08, 0.08) if fmod(a + TAU, PI / 4.0) < PI / 8.0 else Color(0.5, 0.12, 0.12)
			elif r > 0.93 and r < 0.98:
				col = Color(0.75, 0.55, 0.25)
			elif r >= 0.98:
				col = Color(0.12, 0.08, 0.08)
			img.set_pixel(x, y, col)
	return img


func _banquette(pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	add_child(root)
	_box(Vector3(1.9, 0.1, 0.7), Vector3(0, 0.12, 0), dark_wood, true, root)
	for x in [-0.85, 0.85]:
		_cyl(0.04, 0.12, Vector3(x, 0.06, 0.25), gold, root)
		_cyl(0.04, 0.12, Vector3(x, 0.06, -0.25), gold, root)
	_box(Vector3(1.8, 0.22, 0.62), Vector3(0, 0.28, 0.02), velvet, false, root)
	# Dossier capitonné : des boutons dorés sur le velours.
	_box(Vector3(1.8, 0.7, 0.16), Vector3(0, 0.72, -0.27), velvet, false, root)
	for i in 6:
		for j in 2:
			var b := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.018
			sm.height = 0.036
			b.mesh = sm
			b.material_override = gold
			b.position = Vector3(-0.75 + i * 0.3, 0.6 + j * 0.25, -0.18)
			root.add_child(b)
	_box(Vector3(1.9, 0.06, 0.2), Vector3(0, 1.08, -0.27), dark_wood, false, root)
	for x in [-0.95, 0.95]:
		_box(Vector3(0.1, 0.42, 0.62), Vector3(x, 0.45, 0.0), dark_wood, false, root)


## Une chaise de casino : pieds d'acajou, assise et dossier de velours, fil d'or.
func _chair(parent: Node3D, at: Vector3, rot_y: float, color := Color(0.5, 0.03, 0.08)) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees.y = rot_y
	parent.add_child(root)
	var v := _std(color, 0.85)
	for x in [-0.2, 0.2]:
		for z in [-0.2, 0.2]:
			_cyl(0.025, 0.46, Vector3(x, 0.23, z), dark_wood, root, 0.018)
	_box(Vector3(0.48, 0.09, 0.48), Vector3(0, 0.5, 0), v, false, root)
	_box(Vector3(0.5, 0.03, 0.5), Vector3(0, 0.455, 0), dark_wood, false, root)
	_box(Vector3(0.46, 0.52, 0.07), Vector3(0, 0.82, 0.21), v, false, root)
	_box(Vector3(0.5, 0.05, 0.09), Vector3(0, 1.1, 0.21), dark_wood, false, root)
	for x in [-0.23, 0.23]:
		_box(Vector3(0.04, 0.6, 0.06), Vector3(x, 0.8, 0.22), dark_wood, false, root)
	_box(Vector3(0.48, 0.02, 0.02), Vector3(0, 0.555, -0.24), gold, false, root)


## Une pile de jetons, pour la caisse et les râteliers.
func _chips(parent: Node3D, at: Vector3, n: int, color: Color) -> void:
	var m := _std(color, 0.4)
	var c := _cyl(0.022, 0.006 * n, at + Vector3(0, 0.003 * n, 0), m, parent)
	c.name = "Jetons"
	_cyl(0.0225, 0.004, at + Vector3(0, 0.006 * n, 0), _std(Color(0.95, 0.93, 0.85), 0.4), parent)


# --- La salle des jeux, autour de son atrium -----------------------------------------

func _build_games_room() -> void:
	# Le plafond : caissons sur le pourtour, et au centre l'atrium ouvert sur la Verrière.
	_ceiling(-14, -5, -14, 6, WALL_H)
	_ceiling(5, 14, -14, 6, WALL_H)
	_ceiling(-5, 5, -14, -9, WALL_H)
	_ceiling(-5, 5, -1, 6, WALL_H)
	for x in [-5.0, 5.0]:
		_box(Vector3(0.4, 0.6, 8.4), Vector3(x, WALL_H - 0.3, -5.0), dark_wood)
		_box(Vector3(0.44, 0.06, 8.4), Vector3(x, WALL_H - 0.62, -5.0), gold)
	for z in [-9.0, -1.0]:
		_box(Vector3(10.4, 0.6, 0.4), Vector3(0, WALL_H - 0.3, z), dark_wood)
		_box(Vector3(10.4, 0.06, 0.44), Vector3(0, WALL_H - 0.62, z), gold)
	for x in [-5.2, 5.2]:
		for z in [-9.2, -0.8]:
			_column(Vector3(x, 0, z), WALL_H, 0.3)
	# Bordure de moquette plus sombre le long des murs.
	var border := _shader("res://shaders/carpet.gdshader", {"base_col": Color(0.12, 0.02, 0.04), "motif_col": Color(0.4, 0.26, 0.1), "scale": 0.8})
	for b in [[Vector3(28, 0.012, 0.9), Vector3(0, 0.006, -13.55)], [Vector3(28, 0.012, 0.9), Vector3(0, 0.006, 5.55)],
			[Vector3(0.9, 0.012, 20), Vector3(-13.55, 0.006, -4)], [Vector3(0.9, 0.012, 20), Vector3(13.55, 0.006, -4)]]:
		_box(b[0], b[1], border)
	for z in [-10.5, -4.5, 1.5]:
		_sconce(Vector3(-13.85, 2.7, z), 90.0)
		_sconce(Vector3(13.85, 2.7, z), -90.0)
	_chandelier(Vector3(-9.5, WALL_H - 0.4, 3.0), 0.8)
	_chandelier(Vector3(9.5, WALL_H - 0.4, 3.0), 0.8)
	_chandelier(Vector3(-9.5, WALL_H - 0.4, -11.2), 0.8)
	_chandelier(Vector3(9.5, WALL_H - 0.4, -11.2), 0.8)

	# Neuf machines contre le mur du fond, deux îlots de quatre près des portes.
	var names := ["La Grande Smarvoise", "Le Clain", "Le Miosson", "Saint-Félix", "L'Érable", "Passelourdin", "Le Moulin", "Les Zèbres", "La Rabelais"]
	for i in 9:
		_slot_machine(Vector3(-8.0 + i * 2.0, 0, -13.25), 0.0, names[i])
	for s in [-1.0, 1.0]:
		for k in 4:
			var x: float = s * (7.4 + (k % 2) * 1.0)
			var z: float = 1.6 if k < 2 else 3.1
			var rot := 180.0 if k < 2 else 0.0
			_slot_machine(Vector3(x, 0, z + (-0.35 if k < 2 else 0.35)), rot, "")
		_box(Vector3(2.2, 2.0, 0.1), Vector3(s * 7.9, 1.2, 2.35), lacquer, true)
		_label("MACHINES À SOUS", Vector3(s * 7.9, 2.35, 2.35), 0.0, 36, Color(1.0, 0.8, 0.4))

	# Les tables : roulette à l'ouest, blackjack à l'est, craps sous l'atrium.
	_roulette_table(Vector3(-9.2, 0, -5.8))
	_blackjack_table(Vector3(9.2, 0, -6.2))
	_craps_table(Vector3(0.0, 0, -5.0))
	_table_lamp(Vector3(-9.2, 2.5, -5.8), 2.4, 90.0)
	# Plus douce au blackjack : les cartes blanches y sont à plat sous la lampe.
	_table_lamp(Vector3(8.9, 2.5, -6.2), 2.0, 90.0, 1.6)

	# La caisse, une cage de laiton contre le mur ouest, près de la porte.
	var cage := _node(Vector3(-12.2, 0, 3.6))
	_box(Vector3(3.2, 1.15, 0.8), Vector3(0, 0.575, 0), dark_wood, true, cage)
	_box(Vector3(3.3, 0.06, 0.9), Vector3(0, 1.18, 0), marble_white, false, cage)
	for k in 16:
		_cyl(0.012, 1.1, Vector3(-1.5 + k * 0.2, 1.75, 0), brass, cage)
	_box(Vector3(3.2, 0.1, 0.12), Vector3(0, 2.32, 0), brass, false, cage)
	_box(Vector3(3.4, 0.5, 0.2), Vector3(0, 2.65, 0), dark_wood, false, cage)
	_label("CAISSE", Vector3(0, 2.65, 0.12), 0.0, 52, Color(1.0, 0.86, 0.55), cage)
	for k in 6:
		_chips(cage, Vector3(-1.2 + k * 0.25, 1.21, -0.25), 6 + k * 2, [Color(0.85, 0.1, 0.1), Color(0.1, 0.25, 0.7), Color(0.1, 0.5, 0.2), Color(0.1, 0.1, 0.1)][k % 4])
	_person("caissier", Vector3(-12.2, 0, 2.8), 0.0, "idle", "noeud")
	_interactive(cage, "cashier", "E : passer à la caisse", Vector3(3.2, 2.0, 1.4), Vector3(0, 1.0, 0.6))
	# Un petit comptoir de bar en face, pour les joueurs.
	var bar := _node(Vector3(12.2, 0, 3.6))
	_box(Vector3(3.0, 1.1, 0.7), Vector3(0, 0.55, 0), dark_wood, true, bar)
	_box(Vector3(3.1, 0.06, 0.8), Vector3(0, 1.13, 0), marble_white, false, bar)
	_box(Vector3(3.0, 0.04, 0.04), Vector3(0, 0.25, -0.4), brass, false, bar)
	for k in 4:
		_stool(Vector3(10.95 + k * 0.85, 0, 2.85), 0.0)
	_person("barman-salle", Vector3(12.2, 0, 4.4), 180.0, "idle", "noeud")
	# Les clients.
	_person("character-male-e.glb", Vector3(-2.0, 0, -12.2), 180.0)
	_person("character-female-f.glb", Vector3(4.0, 0, -12.2), 180.0)
	_person("character-female-a.glb", Vector3(11.8, 0, 2.6), 160.0, "sit")
	# Deux curieux debout, qui regardent la table du Miosson.
	_person("character-male-b.glb", Vector3(-3.3, 0, 4.6), 121.0)
	_person("character-female-c.glb", Vector3(3.2, 0, 0.4), -55.0)


func _stool(at: Vector3, rot_y: float) -> void:
	var root := _node(at)
	root.rotation_degrees.y = rot_y
	_cyl(0.2, 0.03, Vector3(0, 0.015, 0), brass, root)
	_cyl(0.03, 0.7, Vector3(0, 0.38, 0), chrome, root)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.15
	tm.outer_radius = 0.17
	ring.mesh = tm
	ring.material_override = brass
	ring.position.y = 0.3
	root.add_child(ring)
	_cyl(0.2, 0.1, Vector3(0, 0.76, 0), velvet, root, 0.19)
	_box(Vector3(0.34, 0.22, 0.05), Vector3(0, 0.95, 0.17), velvet, false, root)


## Une machine à sous de salon (scripts/jeux/slot_3d.gd) : caisson laqué, vrais tambours derrière
## la vitre, fronton à ampoules qui chassent, bras qu'on tire ; et son tabouret.
func _slot_machine(pos: Vector3, rot_y: float, title: String) -> void:
	var root := SLOT_3D.new()
	root.title = title if title != "" else "JACKPOT"
	root.theme = _slot_count
	_slot_count += 1
	root.position = pos
	root.rotation_degrees.y = rot_y
	add_child(root)
	root.set_meta("table3d", root)
	_solid(Vector3(0.75, 2.0, 0.65), pos + Vector3(0, 1.0, 0), deg_to_rad(rot_y))
	var stool_at := pos + Basis(Vector3.UP, deg_to_rad(rot_y)) * Vector3(0, 0, 0.72)
	_stool(stool_at, rot_y)
	_interactive(root, "slot", "E : jouer à %s" % (title if title != "" else "la machine"), Vector3(0.9, 2.0, 1.2), Vector3(0, 1.0, 0.3))
	root.set_meta("name", title if title != "" else "Machine de la salle")


## Un tapis de jeu imprimé (roulette, blackjack, craps), dessiné une fois dans une vue hors écran.
func _layout_texture(kind: String, size: Vector2i) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = kind == "blackjack"
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var c := Control.new()
	c.size = Vector2(size)
	vp.add_child(c)
	var font := serif
	c.draw.connect(func():
		var w := float(size.x)
		var h := float(size.y)
		var felt_c := Color(0.07, 0.36, 0.2)
		var ink := Color(0.95, 0.92, 0.8)
		var goldc := Color(0.95, 0.75, 0.35)
		match kind:
			"roulette":
				c.draw_rect(Rect2(0, 0, w, h), felt_c)
				var x0 := w * 0.36
				var cw := (w - x0 - 40.0) / 13.0
				var ch := (h - 120.0) / 3.0
				c.draw_rect(Rect2(x0 - cw, 20, cw, ch * 3), Color(0.05, 0.45, 0.22))
				c.draw_string(font, Vector2(x0 - cw * 0.75, 20 + ch * 1.6), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, ink)
				for col in 12:
					for row in 3:
						var n := col * 3 + (3 - row)
						var r := Rect2(x0 + col * cw, 20 + row * ch, cw, ch)
						c.draw_rect(r, Color(0.7, 0.07, 0.09) if n in ROULETTE.RED else Color(0.06, 0.06, 0.07))
						c.draw_rect(r, ink, false, 2.0)
						c.draw_string(font, r.position + Vector2(cw * 0.18, ch * 0.62), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)
				for row in 3:
					var r := Rect2(x0 + 12 * cw, 20 + row * ch, cw, ch)
					c.draw_rect(r, ink, false, 2.0)
					c.draw_string(font, r.position + Vector2(8, ch * 0.62), "2:1", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
				var labels := ["1re 12", "2e 12", "3e 12"]
				for k in 3:
					var r := Rect2(x0 + k * 4 * cw, 20 + 3 * ch, cw * 4, 45)
					c.draw_rect(r, ink, false, 2.0)
					c.draw_string(font, r.position + Vector2(cw * 1.4, 33), labels[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink)
				var outs := ["1-18", "PAIR", "ROUGE", "NOIR", "IMPAIR", "19-36"]
				for k in 6:
					var r := Rect2(x0 + k * 2 * cw, 20 + 3 * ch + 45, cw * 2, 45)
					c.draw_rect(r, ink, false, 2.0)
					var col: Color = Color(0.85, 0.15, 0.15) if outs[k] == "ROUGE" else (Color(0.1, 0.1, 0.1) if outs[k] == "NOIR" else ink)
					c.draw_string(font, r.position + Vector2(10, 32), outs[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
				c.draw_rect(Rect2(6, 6, w - 12, h - 12), goldc, false, 4.0)
			"blackjack":
				var center := Vector2(w / 2.0, 0)
				c.draw_circle(center, w * 0.495, felt_c)
				c.draw_arc(center, w * 0.47, 0, PI, 96, goldc, 4.0)
				c.draw_arc(center, w * 0.3, 0.15, PI - 0.15, 96, ink, 2.0)
				c.draw_string(font, Vector2(w * 0.24, h * 0.42), "LE BLACKJACK PAIE 3 CONTRE 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, goldc)
				c.draw_string(font, Vector2(w * 0.27, h * 0.56), "Le croupier reste sur tous les 17", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
				for k in 5:
					var a := PI * (0.15 + 0.7 * k / 4.0)
					var p := center + Vector2(cos(a), sin(a)) * w * 0.4
					c.draw_arc(p, 34, 0, TAU, 32, ink, 3.0)
			"craps":
				c.draw_rect(Rect2(0, 0, w, h), felt_c)
				c.draw_rect(Rect2(10, 10, w - 20, h - 20), goldc, false, 4.0)
				var nums := ["4", "5", "SIX", "8", "NEUF", "10"]
				for k in 6:
					var r := Rect2(w * 0.2 + k * w * 0.1, 30, w * 0.1, h * 0.22)
					c.draw_rect(r, ink, false, 2.0)
					c.draw_string(font, r.position + Vector2(12, h * 0.15), nums[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 36, ink)
				c.draw_rect(Rect2(w * 0.2, h * 0.32, w * 0.6, h * 0.16), ink, false, 2.0)
				c.draw_string(font, Vector2(w * 0.38, h * 0.43), "COME", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(0.9, 0.2, 0.2))
				c.draw_rect(Rect2(w * 0.2, h * 0.5, w * 0.6, h * 0.16), ink, false, 2.0)
				c.draw_string(font, Vector2(w * 0.24, h * 0.61), "FIELD  2 · 3 · 4 · 9 · 10 · 11 · 12", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, goldc)
				c.draw_rect(Rect2(w * 0.2, h * 0.68, w * 0.6, h * 0.1), ink, false, 2.0)
				c.draw_string(font, Vector2(w * 0.4, h * 0.755), "DON'T PASS", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink)
				c.draw_rect(Rect2(w * 0.12, h * 0.8, w * 0.76, h * 0.14), ink, false, 2.0)
				c.draw_string(font, Vector2(w * 0.4, h * 0.9), "PASS LINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, ink)
				c.draw_rect(Rect2(w * 0.83, h * 0.3, w * 0.14, h * 0.4), ink, false, 2.0)
				c.draw_string(font, Vector2(w * 0.845, h * 0.52), "ANY 7", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.9, 0.2, 0.2))
	)
	return vp.get_texture()


func _felt_quad(parent: Node3D, size: Vector2, y: float, tex: Texture2D, alpha := false) -> void:
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	q.mesh = pm
	var m := _std(Color.WHITE, 0.95)
	m.albedo_texture = tex
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	q.material_override = m
	q.position.y = y
	parent.add_child(q)


## Une table rectangulaire : piètement d'acajou, plateau, tapis imprimé, boudin de cuir.
func _table_base(root: Node3D, size: Vector3, layout: Texture2D = null) -> void:
	_box(Vector3(size.x - 0.5, 0.62, size.z - 0.5), Vector3(0, 0.36, 0), dark_wood, true, root)
	_box(Vector3(size.x - 0.3, 0.08, size.z - 0.3), Vector3(0, 0.04, 0), dark_wood, false, root)
	_box(Vector3(size.x, 0.1, size.z), Vector3(0, 0.72, 0), wood, false, root)
	_box(Vector3(size.x + 0.02, 0.025, size.z + 0.02), Vector3(0, 0.665, 0), gold, false, root)
	if layout:
		_felt_quad(root, Vector2(size.x - 0.3, size.z - 0.3), 0.775, layout)
	else:
		_box(Vector3(size.x - 0.3, 0.01, size.z - 0.3), Vector3(0, 0.775, 0), felt, false, root)
	for e in [[Vector3(size.x, 0.09, 0.16), Vector3(0, 0.81, size.z / 2.0 - 0.08)], [Vector3(size.x, 0.09, 0.16), Vector3(0, 0.81, -size.z / 2.0 + 0.08)],
			[Vector3(0.16, 0.09, size.z), Vector3(size.x / 2.0 - 0.08, 0.81, 0)], [Vector3(0.16, 0.09, size.z), Vector3(-size.x / 2.0 + 0.08, 0.81, 0)]]:
		_box(e[0], e[1], leather, false, root)
	root.set_meta("felt_y", 0.78)


func _roulette_table(pos: Vector3) -> void:
	var root := _node(pos)
	root.rotation_degrees.y = 90
	# La table et son cylindre : voir scripts/jeux/roulette_3d.gd.
	var t := ROULETTE_3D.new()
	t.with_lamp = false
	root.add_child(t)
	root.set_meta("table3d", t)
	_solid(Vector3(1.5, 0.9, 3.4), pos + Vector3(0, 0.45, 0))
	# Chaises côté joueurs, croupier côté cylindre, râteau et jetons.
	for k in 4:
		_chair(root, Vector3(-0.2 + k * 0.6, 0, 1.15), 180.0)
	# Le croupier fait face aux joueurs, de l'autre côté du tapis, près du cylindre : en entier dans
	# le regard du joueur assis, hors du plan rapproché sur le cylindre.
	_person("croupier-roulette", pos + Vector3(-1.0, 0, 0.6), 90.0, "idle", "noeud")
	_person("character-male-f.glb", pos + Vector3(1.4, 0, -1.6), -90.0)
	_bill(_label("Roulette", Vector3(0, 2.0, 0), 0.0, 72, Color(1.0, 0.85, 0.5), root))
	_interactive(root, "roulette", "E : s'asseoir à la roulette", Vector3(3.6, 2.0, 2.8), Vector3(0, 1.0, 0.4))


func _blackjack_table(pos: Vector3) -> void:
	var root := _node(pos)
	root.rotation_degrees.y = -90
	# La table, le sabot et les cartes : voir scripts/jeux/blackjack_3d.gd.
	var t := BLACKJACK_3D.new()
	t.with_lamp = false
	root.add_child(t)
	root.set_meta("table3d", t)
	_solid(Vector3(1.45, 0.9, 2.8), pos + Vector3(-0.22, 0.45, 0))
	for k in 5:
		var a := deg_to_rad(-60.0 + k * 30.0)
		_stool(pos + Basis(Vector3.UP, deg_to_rad(-90.0)) * Vector3(sin(a) * 2.0, 0, cos(a) * 2.0), rad_to_deg(a) - 90.0 + 180.0)
	_person("croupiere-blackjack", pos + Basis(Vector3.UP, deg_to_rad(-90.0)) * Vector3(0, 0, -1.05), -90.0, "idle", "noeud")
	_person("character-female-b.glb", pos + Basis(Vector3.UP, deg_to_rad(-90.0)) * Vector3(1.6, 0, 1.4), 120.0)
	_bill(_label("Blackjack", Vector3(0, 2.0, 0), 0.0, 72, Color(1.0, 0.85, 0.5), root))
	_interactive(root, "blackjack", "E : s'asseoir au blackjack", Vector3(3.6, 2.0, 2.6), Vector3(0, 1.0, 0.8))


func _craps_table(pos: Vector3) -> void:
	var root := _node(pos)
	# La cuve, le tapis, les dés et le palet : voir scripts/jeux/craps_3d.gd.
	var t := CRAPS_3D.new()
	root.add_child(t)
	root.set_meta("table3d", t)
	_solid(Vector3(CRAPS_3D.OUT.x, 1.0, CRAPS_3D.OUT.y), pos + Vector3(0, 0.5, 0))
	# Un pas en arrière de la bande : les mains restent derrière le rebord.
	_person("stickman", pos + Vector3(0, 0, -1.4), 0.0, "idle", "noeud")
	_person("boxman", pos + Vector3(0.9, 0, -1.4), -20.0, "idle", "noeud")
	_person("character-male-f.glb", pos + Vector3(-1.4, 0, 1.5), 180.0)
	_person("character-female-c.glb", pos + Vector3(1.2, 0, 1.5), 180.0)
	_person("character-male-c.glb", pos + Vector3(2.7, 0, 0.3), -90.0)
	_bill(_label("Craps", Vector3(0, 2.2, 0), 0.0, 72, Color(1.0, 0.85, 0.5), root))
	_interactive(root, "craps", "E : jouer au craps", Vector3(4.8, 2.0, 3.0), Vector3(0, 1.0, 0.6))


## Le piano à queue : caisse laquée, couvercle levé, clavier.
func _piano(at: Vector3, rot_y: float) -> void:
	var piano := _node(at)
	piano.rotation_degrees.y = rot_y
	_box(Vector3(1.5, 0.3, 1.4), Vector3(0, 0.85, 0.1), lacquer, true, piano)
	_cyl(0.75, 0.3, Vector3(0, 0.85, -0.6), lacquer, piano)
	_box(Vector3(0.9, 0.3, 0.6), Vector3(-0.3, 0.85, -1.1), lacquer, false, piano)
	for x in [-0.6, 0.6]:
		_cyl(0.05, 0.7, Vector3(x, 0.35, 0.65), lacquer, piano)
	_cyl(0.05, 0.7, Vector3(0, 0.35, -1.25), lacquer, piano)
	_box(Vector3(1.4, 0.05, 0.22), Vector3(0, 0.82, 0.88), marble_white, false, piano)
	for k in 20:
		_box(Vector3(0.025, 0.03, 0.12), Vector3(-0.6 + k * 0.064, 0.85, 0.85), lacquer, false, piano)
	var lid := _box(Vector3(1.45, 0.03, 2.2), Vector3(-0.5, 1.4, -0.3), lacquer, false, piano)
	lid.rotation_degrees.z = 40
	_cyl(0.015, 0.7, Vector3(0.55, 1.2, -0.3), brass, piano).rotation_degrees.z = -20
	_box(Vector3(0.9, 0.08, 0.4), Vector3(0, 0.5, 1.35), lacquer, false, piano)


# --- Le Nocturne -------------------------------------------------------------------------

func _build_bar() -> void:
	# Le comptoir en arc de cercle, son repose-pied de laiton, et le miroir de l'arrière-bar.
	_box(Vector3(0.8, 1.1, 8.0), Vector3(18.0, 0.55, 12.0), dark_wood, true)
	_box(Vector3(1.0, 0.07, 8.1), Vector3(17.9, 1.13, 12.0), marble_white)
	_box(Vector3(0.05, 0.06, 8.0), Vector3(17.55, 1.0, 12.0), gold)
	_box(Vector3(0.05, 0.05, 8.0), Vector3(17.4, 0.22, 12.0), brass)
	for k in 9:
		_box(Vector3(0.02, 0.9, 0.7), Vector3(17.58, 0.5, 8.4 + k * 0.9), wood)
	var back := _node(Vector3(19.85, 0, 12.0))
	back.rotation_degrees.y = -90
	_mirror(back, Vector3(0, 2.3, 0.05), Vector2(6.0, 1.6))
	_box(Vector3(7.0, 0.04, 0.3), Vector3(19.7, 1.6, 12.0), dark_wood)
	_box(Vector3(7.0, 0.04, 0.3), Vector3(19.7, 2.2, 12.0), dark_wood)
	var bottle_mat := _std(Color(0.4, 0.8, 0.5, 0.8), 0.1)
	bottle_mat.emission_enabled = true
	bottle_mat.emission = Color(0.9, 0.6, 0.2)
	bottle_mat.emission_energy_multiplier = 1.0
	for shelf in 2:
		for k in 16:
			var m := bottle_mat.duplicate()
			m.albedo_color = Color.from_hsv(randf_range(0.0, 0.15), 0.7, 0.8)
			_cyl(0.05, 0.3, Vector3(19.7, 1.78 + shelf * 0.6, 8.8 + k * 0.42), m)
	var shelf_light := OmniLight3D.new()
	shelf_light.light_color = Color(1.0, 0.7, 0.4)
	shelf_light.light_energy = 1.4
	shelf_light.omni_range = 4.0
	shelf_light.position = Vector3(19.3, 2.0, 12.0)
	add_child(shelf_light)
	for z in [9.0, 10.5, 12.0, 13.5, 15.0]:
		_stool(Vector3(17.0, 0, z), 90.0)
	_person("barman-nocturne", Vector3(19.0, 0, 12.0), -90.0, "idle", "noeud")
	_label("Le Nocturne", Vector3(10.15, 3.9, 12.0), 90.0, 64, Color(0.6, 0.85, 1.0))
	# Le piano et sa chanteuse, au fond ; des fauteuils club autour de guéridons.
	_piano(Vector3(12.3, 0, 16.4), 160.0)
	_person("pianiste-nocturne", Vector3(12.0, 0, 15.2), -20.0, "sit", "noeud")
	_person("chanteuse", Vector3(13.6, 0, 15.4), -40.0, "idle", "collier")
	for p in [Vector3(12.8, 0, 9.0), Vector3(15.2, 0, 12.6)]:
		_cyl(0.35, 0.65, p + Vector3(0, 0.33, 0), dark_wood)
		_cyl(0.42, 0.04, p + Vector3(0, 0.67, 0), marble_white)
		_cyl(0.05, 0.15, p + Vector3(0, 0.76, 0), brass_glow)
		for a in [0.0, 120.0, 240.0]:
			var off := Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a))) * 1.0
			var chair := _place(KK + "furniture/armchair.gltf", p + off, 0.9, a + 180.0)
			_tint(chair, Color(0.32, 0.12, 0.05))
	_person("character-female-d.glb", Vector3(13.4, 0, 9.6), -120.0, "sit")
	_chandelier(Vector3(15.0, 3.9, 12.0), 0.8)
	_sconce(Vector3(10.15, 2.4, 8.0), -90.0)
	_sconce(Vector3(10.15, 2.4, 16.0), -90.0)


# --- Les salles à seuils -------------------------------------------------------------

## Les captures de la table à plusieurs : sans réseau, sur des vues enregistrées.
var _poker_essai := false


## Rejoue les vues enregistrées, une toutes les 0,8 s, comme les relirait le jeu.
func _rejouer_poker(pnl: Control) -> void:
	var vues: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/poker_multi_vues.json"))
	for x in vues.slice(0, vues.size() - 1):
		if not is_instance_valid(pnl):
			return
		pnl.appliquer(x.v, x.action)
		await get_tree().create_timer(0.8).timeout

## Les deux tables de poker du casino : le centre de la table et ses habitués, chaise par chaise.
## Le Miosson, dans la Salle des jeux, est ouvert à tous (pas de seuil) et joue petit : blindes 5/10,
## 200 au plus par donne, à la table poker:miosson du serveur quand on est connecté.
const POKER_TABLES := {
	"ambassadeurs": {"centre": Vector3(20.0, 0, -4.0),
		"habitues": ["le-commandant", "mme-duval", "teddy", "comtesse-orlov", "maitre-garnier"]},
	"miosson": {"centre": Vector3(0.0, 0, 2.6),
		"habitues": ["pere-rigaud", "mme-pacaud", "jordan", "odile", "m-lebreton"]},
}
## Le Miosson en solo : les mêmes manières qu'aux Ambassadeurs, place pour place, chez d'autres gens.
const MIOSSON_SOLO := [["le père Rigaud", 0.75, 0.8], ["Mme Pacaud", 0.1, 0.15], ["Jordan", 0.2, 0.9], ["Odile", 0.6, 0.35], ["M. Lebreton", 0.5, 0.55]]

## Les habitués du poker par figurant, et les joueurs venus s'asseoir (par table, puis par chaise).
var _poker_people := {"ambassadeurs": {}, "miosson": {}}
var _poker_guests := {"ambassadeurs": {}, "miosson": {}}


## La place d'un figurant à la chaise k (0 : le premier habitué ; 5 : la chaise libre du joueur).
func _poker_chair(k: int, table := "ambassadeurs") -> Vector3:
	var a := TAU * k / 6.0
	var c: Vector3 = POKER_TABLES[table].centre
	return Vector3(c.x + sin(a) * 1.85, 0.0, c.z + cos(a) * 1.85)


## Le panneau du Miosson : son titre, ses tarifs, ses habitués (la table du serveur, connecté).
func _configurer_miosson(pk: Control) -> void:
	pk.title = "La table du Miosson"
	if pk.has_method("configurer_table"):
		pk.title = "La table du Miosson · à plusieurs"
		pk.configurer_table("poker:miosson", 5, 10, 200)
	else:
		pk.configurer_blindes(5, 10, 200)
		pk.regulars = MIOSSON_SOLO.duplicate(true)


## La table à plusieurs dit qui est assis où (places de l'écran, la sienne en 0) : les habitués
## vont à leur chaise ou se lèvent, et un joueur prend forme à la sienne. {} : tout le monde reprend
## sa place de toujours.
func _poker_lineup(places: Dictionary, table := "ambassadeurs") -> void:
	var regulars: Array = POKER_TABLES[table].habitues
	var people: Dictionary = _poker_people[table]
	var guests: Dictionary = _poker_guests[table]
	var at := {}
	for i in places:
		var f: String = places[i].get("figurant", "")
		if f != "" and int(i) != 0:
			at[posmod(int(i) - 1, 6)] = f
	if places.is_empty():
		for k in 5:
			at[k] = regulars[k]
	for id in regulars:
		var node: Node3D = people.get(id)
		if node == null:
			continue
		var k = at.find_key(id)
		node.visible = k != null
		if k != null:
			node.position = _poker_chair(k, table)
			node.rotation_degrees.y = rad_to_deg(TAU * k / 6.0) + 180.0
	# Le nom de chaque joueur venu s'asseoir, par chaise de la salle.
	var noms := {}
	for i in places:
		if places[i].get("figurant", "") == "joueur" and int(i) != 0:
			noms[posmod(int(i) - 1, 6)] = str(places[i].get("nom", ""))
	for k in 6:
		var want: bool = at.get(k, "") == "joueur"
		var nom: String = noms.get(k, "")
		if guests.has(k) and (not want or guests[k].get_meta("nom", "") != nom):
			Presences.masquer(guests[k].get_meta("nom", ""), false)
			guests[k].queue_free()
			guests.erase(k)
		if want and not guests.has(k):
			var g := _person("character-male-b.glb" if k % 2 == 0 else "character-female-a.glb", _poker_chair(k, table), rad_to_deg(TAU * k / 6.0) + 180.0)
			g.set_meta("nom", nom)
			# Un joueur présent dans le casino (autoload Presences) s'assoit avec sa tenue, et sa silhouette
			# qui marche s'efface tant qu'il est à la table.
			var tenue: String = Presences.tenue_de(nom) if nom != "" else ""
			if tenue != "" and g.get("critter") != null:
				g.critter.set_look(Cast.player(tenue))
			if nom != "":
				Presences.masquer(nom)
			guests[k] = g

## La table du Miosson, au milieu de la Salle des jeux, entre les deux portes du hall : la même table
## ronde qu'aux Ambassadeurs, chaises de velours bordeaux, cinq habitués du village. Pas de cordon.
func _build_miosson() -> void:
	var c: Vector3 = POKER_TABLES.miosson.centre
	var poker := Node3D.new()
	poker.position = c
	add_child(poker)
	var pt := POKER_3D.new()
	pt.with_lamp = false
	pt.nom_tapis = "TABLE DU MIOSSON"
	pt.ligne_tapis = "BLINDES 5 / 10  ·  SALLE DES JEUX"
	pt.couleur_tapis = Color(0.03, 0.16, 0.08)
	pt.rotation_degrees.y = -60.0
	poker.add_child(pt)
	poker.set_meta("table3d", pt)
	_solid_cyl(c + Vector3(0, 0.5, 0), 1.6, 1.0)
	var regulars: Array = POKER_TABLES.miosson.habitues
	for k in 6:
		var a := TAU * k / 6.0
		_chair(poker, Vector3(sin(a) * 2.0, 0, cos(a) * 2.0), rad_to_deg(a))
		if k < 5:
			_poker_people.miosson[regulars[k]] = _person(regulars[k], _poker_chair(k, "miosson"), rad_to_deg(a) + 180.0)
	_table_lamp(c + Vector3(0, 2.6, 0), 1.6)
	_bill(_label("La table du Miosson", c + Vector3(0, 2.9, 0), 0.0, 56))
	_interactive(poker, "poker-miosson", "E : s'asseoir à la table du Miosson (blindes 5/10)", Vector3(4.0, 2.0, 4.0), Vector3(0, 1.0, 0))


func _build_ambassadeurs() -> void:
	_chandelier(Vector3(20.0, WALL_H - 0.3, -4.0), 1.2)
	var poker := Node3D.new()
	poker.position = Vector3(20.0, 0, -4.0)
	add_child(poker)
	# La table ronde, tournée pour que la chaise libre soit la place du joueur (scripts/jeux/poker_3d.gd).
	var pt := POKER_3D.new()
	pt.with_lamp = false
	pt.rotation_degrees.y = -60.0
	poker.add_child(pt)
	poker.set_meta("table3d", pt)
	_solid_cyl(Vector3(20.0, 0.5, -4.0), 1.6, 1.0)
	var regulars: Array = POKER_TABLES.ambassadeurs.habitues
	for k in 6:
		var a := TAU * k / 6.0
		_chair(poker, Vector3(sin(a) * 2.0, 0, cos(a) * 2.0), rad_to_deg(a), Color(0.08, 0.15, 0.4))
		if k < 5:
			_poker_people.ambassadeurs[regulars[k]] = _person(regulars[k], _poker_chair(k), rad_to_deg(a) + 180.0)
	_table_lamp(Vector3(20.0, 2.6, -4.0), 1.6)
	_bill(_label("Poker des Ambassadeurs", Vector3(20.0, 2.9, -4.0), -90.0, 64))
	_interactive(poker, "poker", "E : prendre la chaise libre au poker", Vector3(4.0, 2.0, 4.0), Vector3(0, 1.0, 0))
	# Tables sous housse, en attente de seuils plus hauts.
	var cover := _std(Color(0.85, 0.82, 0.75), 0.95)
	for z in [-10.5, 2.5]:
		var t := _node(Vector3(23.0, 0, z))
		_table_base(t, Vector3(3.0, 0.9, 1.6))
		_box(Vector3(3.1, 0.5, 1.7), Vector3(0, 0.65, 0), cover, false, t)
	_barrier("ambassadeurs", Vector3(14.0, 0, -4.0), 90.0, 5.0)


func _build_salon() -> void:
	_chandelier(Vector3(-20.0, 4.2, -7.0), 1.0)
	var baccara := _node(Vector3(-20.0, 0, -7.0))
	baccara.rotation_degrees.y = 90
	# La table ovale, le sabot et les cartes : voir scripts/jeux/baccara_3d.gd.
	var bt := BACCARA_3D.new()
	bt.with_lamp = false
	baccara.add_child(bt)
	baccara.set_meta("table3d", bt)
	_solid(Vector3(BACCARA_3D.OUT.x, 1.0, BACCARA_3D.OUT.y), Vector3(-20.0, 0.5, -7.0), PI / 2.0)
	# Pas de chaise au milieu : c'est la place du joueur.
	for k in [0, 1, 3, 4]:
		_chair(baccara, Vector3(-1.2 + k * 0.6, 0, 1.25), 180.0, Color(0.08, 0.15, 0.4))
	_table_lamp(Vector3(-20.0, 2.5, -7.0), 2.0, 90.0)
	_bill(_label("Baccara", Vector3(0, 2.4, 0), 90.0, 64, Color(1.0, 0.85, 0.5), baccara))
	_interactive(baccara, "baccara", "E : s'asseoir au baccara", Vector3(3.6, 2.0, 2.8), Vector3(0, 1.0, 0.6))
	_person("mlle-solange", Vector3(-21.3, 0, -7.0), 90.0, "idle", "noeud")
	_person("baron-de-vasseur", Vector3(-18.6, 0, -6.0), 135.0, "idle", "chapeau")
	for z in [-12.5, -1.5]:
		_banquette(Vector3(-24.0, 0, z), 90.0)
	_piano(Vector3(-23.2, 0, -10.0), 60.0)
	# La porte capitonnée et son portier.
	_person("portier-salon", Vector3(-13.0, 0, -5.6), -90.0, "idle", "chapeau")
	_barrier("salon", Vector3(-14.0, 0, -7.0), 90.0, 2.0)


# --- L'étage : la Verrière autour de l'atrium, le Fumoir, le Lustre, la Loggia ----------

func _build_upper() -> void:
	# Le plancher de l'étage, percé au-dessus de la salle des jeux.
	for slab in [[Vector3(28.0, 0.1, 5.0), Vector3(0, UP, -11.5)], [Vector3(28.0, 0.1, 7.0), Vector3(0, UP, 2.5)],
			[Vector3(9.0, 0.1, 8.0), Vector3(-9.5, UP, -5.0)], [Vector3(9.0, 0.1, 8.0), Vector3(9.5, UP, -5.0)]]:
		_box(slab[0], slab[1], carpet, true)
	# La balustrade de l'atrium, et la verrière au-dessus.
	_railing(Vector3(-5, UP, -9), Vector3(5, UP, -9))
	_railing(Vector3(5, UP, -9), Vector3(5, UP, -1))
	_railing(Vector3(5, UP, -1), Vector3(-5, UP, -1))
	_railing(Vector3(-5, UP, -1), Vector3(-5, UP, -9))
	_ceiling(-14, -5, -14, 6, UP + 4.5)
	_ceiling(5, 14, -14, 6, UP + 4.5)
	_ceiling(-5, 5, -14, -9, UP + 4.5)
	_ceiling(-5, 5, -1, 6, UP + 4.5)
	var night := _std(Color(0.06, 0.1, 0.24), 0.05)
	night.emission_enabled = true
	night.emission = Color(0.05, 0.09, 0.22)
	night.emission_energy_multiplier = 1.4
	_box(Vector3(10.0, 0.05, 8.0), Vector3(0, UP + 4.55, -5.0), night)
	for k in 6:
		_box(Vector3(0.08, 0.12, 8.0), Vector3(-5.0 + k * 2.0, UP + 4.5, -5.0), gold)
	for k in 5:
		_box(Vector3(10.0, 0.12, 0.08), Vector3(0, UP + 4.5, -9.0 + k * 2.0), gold)
	# Le grand lustre qui descend dans l'atrium, au-dessus du craps.
	_chandelier(Vector3(0, UP + 1.8, -5.0), 2.0, false)
	for x in [-5.2, 5.2]:
		for z in [-9.2, -0.8]:
			_column(Vector3(x, UP, z), 4.5, 0.22)
	# Les murs de l'étage.
	_wall(Vector3(-14, 0, 6), Vector3(14, 0, 6), [[5.2, 1.8, 2.6], [22.8, 1.8, 2.6]], 4.5, UP)
	_wall(Vector3(-14, 0, -14), Vector3(14, 0, -14), [], 4.5, UP, -1)
	# La porte du Cercle Philidor (à 18 m du coin nord) : le mur lui laisse sa baie et son chambranle.
	_wall(Vector3(-14, 0, -14), Vector3(-14, 0, 6), [[18.0, 1.5, 2.6]], 4.5, UP, 1)
	_wall(Vector3(14, 0, -14), Vector3(14, 0, 6), [[3.5, 1.8, 2.6], [9.5, 1.8, 2.6], [16.0, 1.8, 2.6]], 4.5, UP)
	_wall(Vector3(-7, 0, -14), Vector3(-7, 0, 6), [[12.0, 3.0, 3.0]], 4.5, UP)
	_wall(Vector3(7, 0, -2), Vector3(7, 0, 6), [[4.0, 2.2, 2.8]], 4.5, UP)
	_wall(Vector3(7, 0, -2), Vector3(14, 0, -2), [], 4.5, UP)
	_label("Galerie de la Verrière", Vector3(0, UP + 3.2, 5.88), 180.0, 56)
	for p in [Vector3(-3.0, UP, 3.6), Vector3(3.0, UP, 3.6)]:
		_banquette(p, 180.0)
	for p in [Vector3(-6.2, UP, 5.2), Vector3(6.2, UP, 5.2)]:
		_place("res://assets/kenney/furniture/pottedPlant.glb", p, 3.2)

	# Le Bar du Fumoir : comptoir, fauteuils de cuir, cheminée, fumée bleutée.
	_box(Vector3(0.8, 1.1, 7.0), Vector3(-13.3, UP + 0.55, -5.0), dark_wood, true)
	_box(Vector3(1.0, 0.07, 7.1), Vector3(-13.2, UP + 1.13, -5.0), marble_white)
	_person("barman-fumoir", Vector3(-13.9, UP, -5.0), 90.0, "idle", "noeud")
	_person("capucine-varenne", Vector3(-12.4, UP, -8.0), -90.0, "sit", "chapeau")
	for p in [Vector3(-10.0, UP, -11.0), Vector3(-10.0, UP, 1.5)]:
		_cyl(0.35, 0.65, p + Vector3(0, 0.33, 0), dark_wood)
		_cyl(0.42, 0.04, p + Vector3(0, 0.67, 0), marble_white)
		for a in [0.0, 120.0, 240.0]:
			var off := Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a))) * 1.0
			var chair := _place(KK + "furniture/armchair.gltf", p + off, 0.9, a + 180.0)
			_tint(chair, Color(0.3, 0.13, 0.06))
	_person("character-male-b.glb", Vector3(-9.2, UP, -10.6), -120.0, "sit")
	var fire := _node(Vector3(-7.25, UP, -5.0))
	fire.rotation_degrees.y = -90
	_box(Vector3(1.8, 1.4, 0.4), Vector3(0, 0.7, 0), marble_white, true, fire)
	_box(Vector3(1.0, 0.8, 0.42), Vector3(0, 0.5, 0), lacquer, false, fire)
	var embers := _box(Vector3(0.8, 0.12, 0.3), Vector3(0, 0.15, 0.06), brass_glow, false, fire)
	embers.name = "Braises"
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.5, 0.2)
	fl.light_energy = 2.0
	fl.omni_range = 5.0
	fl.position = Vector3(0, 0.6, 0.6)
	fire.add_child(fl)
	var smoke := FogVolume.new()
	smoke.size = Vector3(7.0, 4.5, 20.0)
	smoke.position = Vector3(-10.5, UP + 2.25, -4.0)
	var fm := FogMaterial.new()
	fm.density = 0.08
	fm.albedo = Color(0.7, 0.75, 0.85)
	smoke.material = fm
	add_child(smoke)
	_label("Bar du Fumoir", Vector3(-7.15, UP + 3.4, 2.0), 90.0, 56)
	_porte_du_cercle()

	# Restaurant Le Lustre : nappes blanches, couverts, bougies, dîneurs.
	var cloth := _std(Color(0.96, 0.95, 0.92), 0.8)
	for x in [-4.5, 0.0, 4.5]:
		var t := Vector3(x, UP, -11.8)
		_cyl(0.06, 0.72, t + Vector3(0, 0.36, 0), gold)
		_cyl(0.8, 0.32, t + Vector3(0, 0.62, 0), cloth, self, 0.78)
		_cyl(0.03, 0.22, t + Vector3(0, 0.89, 0), cream)
		_cyl(0.025, 0.05, t + Vector3(0, 1.02, 0), brass_glow)
		for k in 4:
			var a := TAU * k / 4.0 + PI / 4.0
			_cyl(0.12, 0.01, t + Vector3(cos(a) * 0.5, 0.79, sin(a) * 0.5), marble_white)
			_chair(_node(Vector3.ZERO), t + Vector3(cos(a) * 1.05, 0, sin(a) * 1.05), rad_to_deg(-a) - 90.0, Color(0.5, 0.36, 0.2))
		_person(["diner-1", "diner-2", "diner-3"][int(x / 4.5) + 1], t + Vector3(0, 0, 1.0), 180.0, "sit")
	_label("Restaurant Le Lustre", Vector3(0, UP + 3.4, -13.85), 0.0, 64)
	_chandelier(Vector3(0, UP + 3.9, -11.8), 0.9)

	# La Loggia et sa table de Grand Hasard.
	var hasard := _node(Vector3(10.5, UP, 2.0))
	# Le plateau, le tapis et la cloche : voir scripts/jeux/hasard_3d.gd.
	var ht := HASARD_3D.new()
	ht.with_lamp = false
	hasard.add_child(ht)
	hasard.set_meta("table3d", ht)
	_solid(Vector3(HASARD_3D.OUT.x, 0.9, HASARD_3D.OUT.y), Vector3(10.5, UP + 0.45, 2.0))
	# La place du milieu est celle du joueur : pas de dossier devant la caméra assise.
	for x in [-0.75, 0.75]:
		_chair(hasard, Vector3(x, 0, 1.05), 180.0)
	_person("chef-de-partie", Vector3(10.5, UP, 0.9), 0.0, "idle", "noeud")
	_bill(_label("Le Grand Hasard", Vector3(0, 2.2, 0), 0.0, 56, Color(1.0, 0.85, 0.5), hasard))
	_interactive(hasard, "dice", "E : jouer au Grand Hasard", Vector3(2.6, 2.0, 2.4), Vector3(0, 1.0, 0.5))
	_chandelier(Vector3(10.5, UP + 3.9, 2.0), 0.7)
	_barrier("loggia", Vector3(7.0, UP, 2.0), 90.0, 2.2)
	_barrier("loggia", Vector3(8.8, UP, 6.3), 0.0, 1.8)
	_build_salons()


## La porte capitonnée du Cercle Philidor, au fond du Fumoir (mur ouest) : les tables d'échecs, une
## salle à part (scripts/socle/cercle.gd), derrière son cordon et son seuil.
func _porte_du_cercle() -> void:
	var porte := _node(Vector3(-14.0, UP, 4.0))
	porte.rotation_degrees.y = 90.0
	_box(Vector3(1.5, 2.6, 0.12), Vector3(0, 1.3, 0), dark_wood, false, porte)
	_box(Vector3(1.2, 2.3, 0.06), Vector3(0, 1.2, 0.07), velvet, false, porte)
	for x in [-0.3, 0.3]:
		_box(Vector3(0.04, 0.04, 0.05), Vector3(x, 1.15, 0.12), gold, false, porte)
	_label("Cercle Philidor · Échecs", Vector3(0, 3.15, 0.25), 0.0, 40, Color(1.0, 0.85, 0.5), porte)
	_interactive(porte, "cercle", "E : entrer au Cercle Philidor", Vector3(1.6, 2.4, 1.2), Vector3(0, 1.2, 0.6))
	_barrier("cercle", Vector3(-13.2, UP, 4.0), 90.0, 2.0)


# --- Les salons de l'étage, au-dessus des Ambassadeurs ------------------------------------

func _build_salons() -> void:
	_box(Vector3(12.0, 0.1, 20.0), Vector3(20.0, UP, -4.0), carpet_blue, true)
	_ceiling(14, 26, -14, 6, UP + 4.5)
	_wall(Vector3(26, 0, -14), Vector3(26, 0, 6), [], 4.5, UP, -1)
	_wall(Vector3(14, 0, -14), Vector3(26, 0, -14), [], 4.5, UP, -1)
	_wall(Vector3(14, 0, 6), Vector3(26, 0, 6), [], 4.5, UP)
	_wall(Vector3(14, 0, -7), Vector3(26, 0, -7), [], 4.5, UP)
	_wall(Vector3(14, 0, -1), Vector3(26, 0, -1), [], 4.5, UP)
	_barrier("fetes", Vector3(14.0, UP, -10.5), 90.0, 1.8)
	_barrier("musique", Vector3(14.0, UP, -4.5), 90.0, 1.8)
	_barrier("particuliers", Vector3(14.0, UP, 2.0), 90.0, 1.8)

	# La Salle des fêtes : la grande roue de la fortune.
	_chandelier(Vector3(20.0, UP + 3.9, -10.5), 1.0)
	var wheel := _node(Vector3(24.5, UP, -10.5))
	# Face à la porte : la grande roue, sa languette et le comptoir des mises (scripts/jeux/roue_3d.gd).
	wheel.rotation_degrees.y = -90
	var rt := ROUE_3D.new()
	rt.with_lamp = false
	wheel.add_child(rt)
	wheel.set_meta("table3d", rt)
	_solid(Vector3(0.8, 3.0, 1.6), Vector3(24.5, UP + 1.5, -10.5))
	_solid(Vector3(ROUE_3D.COUNTER.y, 1.0, ROUE_3D.COUNTER.x), Vector3(24.5 - ROUE_3D.COUNTER_Z, UP + 0.5, -10.5))
	_bill(_label("La Roue de la fortune", Vector3(0, 4.3, 0), 0.0, 56, Color(1.0, 0.85, 0.5), wheel))
	_interactive(wheel, "roue", "E : faire tourner la roue", Vector3(3.4, 4.0, 2.0), Vector3(0, 2.0, 1.6))
	# Le maître de cérémonie tient la roue : à côté d'elle, derrière le comptoir, face aux joueurs.
	_person("maitre-ceremonie", Vector3(24.05, UP, -9.15), -90.0, "idle", "chapeau")
	_person("invitee-fetes", Vector3(19.0, UP, -9.0), 120.0)
	_person("invite-fetes", Vector3(18.0, UP, -12.0), 60.0)

	# Le Salon de musique : piano à queue et table de la Boule.
	_chandelier(Vector3(20.0, UP + 3.9, -4.0), 0.9)
	_piano(Vector3(24.0, UP, -5.2), 180.0)
	_person("pianiste", Vector3(24.0, UP, -3.6), 180.0, "sit", "noeud")
	var boule := _node(Vector3(18.5, UP, -4.0))
	# La cuvette, le tapis et la boule : voir scripts/jeux/boule_3d.gd.
	var bt3 := BOULE_3D.new()
	bt3.with_lamp = false
	boule.add_child(bt3)
	boule.set_meta("table3d", bt3)
	_solid(Vector3(BOULE_3D.OUT.x, 1.0, BOULE_3D.OUT.y), Vector3(18.5, UP + 0.5, -4.0))
	_bill(_label("La Boule", Vector3(0, 2.2, 0), 0.0, 56, Color(1.0, 0.85, 0.5), boule))
	_interactive(boule, "boule", "E : jouer à la Boule", Vector3(2.6, 2.0, 2.4), Vector3(0, 1.0, 0.4))
	_person("croupier-boule", Vector3(18.5, UP, -5.1), 0.0, "idle", "noeud")

	# Les Salons particuliers : le Banco, à l'abri des regards.
	_chandelier(Vector3(20.0, UP + 3.9, 2.5), 0.8)
	var banco := _node(Vector3(20.5, UP, 2.5))
	var bk := BACCARA_3D.new()
	bk.title = "BANCO"
	bk.commission = false
	bk.felt_color = Color(0.22, 0.03, 0.05)
	banco.add_child(bk)
	banco.set_meta("table3d", bk)
	_solid(Vector3(BACCARA_3D.OUT.x, 1.0, BACCARA_3D.OUT.y), Vector3(20.5, UP + 0.5, 2.5))
	for k in 4:
		_chair(banco, Vector3(-0.9 + k * 0.6, 0, 1.15), 180.0, Color(0.08, 0.15, 0.4))
	_bill(_label("Banco", Vector3(0, 2.2, 0), 0.0, 56, Color(1.0, 0.85, 0.5), banco))
	_interactive(banco, "banco", "E : s'asseoir au Banco", Vector3(3.2, 2.0, 2.6), Vector3(0, 1.0, 0.5))
	_person("croupier-banco", Vector3(20.5, UP, 1.3), 0.0, "idle", "noeud")
	_person("baron", Vector3(22.4, UP, 3.2), -110.0, "idle", "chapeau")
	for p in [Vector3(25.0, UP, 0.5), Vector3(25.0, UP, 4.5)]:
		_banquette(p, -90.0)


## Un cordon de velours entre deux poteaux dorés, avec le seuil affiché. Il bloque le passage.
## Une même salle peut en avoir plusieurs (une par porte).
func _barrier(id: String, pos: Vector3, rot_y: float, width: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y
	add_child(root)
	for s in [-1.0, 1.0]:
		_cyl(0.05, 1.0, Vector3(s * width / 2.0, 0.5, 0), gold, root)
		_cyl(0.12, 0.05, Vector3(s * width / 2.0, 0.03, 0), gold, root)
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		ball.mesh = sm
		ball.material_override = gold
		ball.position = Vector3(s * width / 2.0, 1.03, 0)
		root.add_child(ball)
	for k in 20:
		var t := (k + 0.5) / 20.0
		var x := -width / 2.0 + width * t
		var y := 0.95 - 0.25 * 4.0 * t * (1.0 - t)
		var seg := _cyl(0.03, width / 20.0 + 0.02, Vector3(x, y, 0), velvet, root)
		seg.rotation_degrees.z = 90
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(width, 2.5, 0.4)
	cs.shape = b
	cs.position.y = 1.25
	body.add_child(cs)
	root.add_child(body)
	var info := _lock_info(id)
	var seal := _label("%s\nouvre à %s crédits %s" % [info.name, Game.fmt(info.seuil), "misés" if info.get("on", "won") == "staked" else "gagnés"], Vector3(0, 1.5, 0.05), 0.0, 44, Color(1.0, 0.88, 0.6), root)
	seal.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	if not barriers.has(id):
		barriers[id] = []
	barriers[id].append(root)


func _refresh_locks(silent := false) -> void:
	for l in LOCKS:
		var amount: int = Game.staked if l.get("on", "won") == "staked" else Game.won
		if barriers.has(l.id) and amount >= l.seuil:
			for b in barriers[l.id]:
				b.queue_free()
			barriers.erase(l.id)
			if not silent:
				if l.id != "salon":
					_announce("%s vous ouvre %s." % [l.host, l.name.substr(0, 1).to_lower() + l.name.substr(1)])
				else:
					Game.credits += 500
					Game.changed.emit()
					_announce("Monsieur Armand vous ouvre le salon et vous offre une plaque de 500. « Un client d'avenir. »")
