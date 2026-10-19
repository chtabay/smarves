extends Node3D
## Casino Minuit, sur le Strip de Las Vegas : une commune « ailleurs » (socle 1.5), rejointe en avion
## depuis Poitiers-Biard. Portage en GDScript du lot A du moteur web : la rotonde d'entrée, l'atrium,
## le grand escalier et la galerie de la mezzanine, bâtis par le kit (kit.gd) zone par zone.
## Comme toute commune, la scène expose `player` et `camera` : le jeu y ajoute la bascule de vue
## (Tab), les commandes tactiles et la carte. On entre à pied, par la porte-tambour de la rotonde.

const BASE := "res://communes/casino_minuit/"
const ZONES := ["rotonde", "atrium", "escalier", "galerie"]
## Les crans de la caméra de dessus, au plus près : sous les plafonds, on ne recule pas loin.
const CRANS := [[4.0, -40.0, 50.0], [7.0, -55.0, 50.0], [11.0, -70.0, 50.0]]
## L'arrivée, juste derrière la porte-tambour, face au nord et à la fontaine de la Fortune.
const ARRIVEE := Vector3(0, 0.05, 27.0)

var player: CharacterBody3D
var camera: Camera3D

var K
var _t := 0.0
var _invite: Label


func _ready() -> void:
	_ambiance()
	K = load(BASE + "kit.gd").new(self)
	for z in ZONES:
		load(BASE + "zones/%s.gd" % z).construire(K)
	_joueur()
	_interface()
	# On entre à pied : la vue de dessus reste à un Tab.
	if get_tree().current_scene == self:
		Vue.basculer.call_deferred(self)


func _process(dt: float) -> void:
	_t += dt
	K.animer(dt, _t)
	var f = player.focus_target if player else null
	_invite.text = str(f.get_meta("invite", "")) + "  [E]" if f != null and f.has_meta("invite") else ""


func _ambiance() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#07060a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6b4a32")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("#2a1a12")
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Une clarté chaude et douce venue d'en haut, pour que les volumes se lisent sans ombres.
	var haut := DirectionalLight3D.new()
	haut.light_color = Color("#ffd9a8")
	haut.light_energy = 0.35
	haut.rotation_degrees = Vector3(-70, 20, 0)
	add_child(haut)


## Un visiteur à taille d'homme (le casino est à l'échelle réelle), et la caméra à crans.
func _joueur() -> void:
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/orbit_camera.gd"))
	camera.far = 300.0
	add_child(camera)
	player = load("res://scripts/fp_player.gd").new()
	player.eye = 1.6
	player.body_height = 1.7
	player.radius = 0.3
	player.speed = 3.2
	player.reach = 2.6
	add_child(player)
	var me: Node3D = load("res://scripts/critter.gd").new()
	me.look = Cast.player(Biens.worn)
	me.walk_speed = 2.4
	me.run_speed = 4.4
	me.scale = Vector3.ONE * 2.4
	me.rotation.y = PI
	player.add_child(me)
	player.avatar = me
	player.global_position = ARRIVEE
	player.interact.connect(_interagir)
	camera.make_current()
	player.follow_camera = camera
	camera.au_dela.connect(func(): Carte.ouvrir())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.target = player.global_position + Vector3(0, 1.0, 0)
	camera.set("_target_goal", camera.target)
	camera.yaw = 0.0
	camera.set("_yaw_goal", camera.yaw)
	camera.use_notches(CRANS, 1)


func _interagir(cible: Node) -> void:
	match str(cible.get_meta("interact", "")):
		# Sortir sur le Strip, c'est repartir : la carte montre Las Vegas et le vol du retour.
		"sortie": Carte.ouvrir()


func _interface() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var aide := Label.new()
	aide.text = "Casino Minuit, Las Vegas  ·  Tab pour changer de vue  ·  E pour agir  ·  M pour la carte"
	aide.add_theme_font_override("font", Polices.texte())
	aide.add_theme_font_size_override("font_size", 16)
	aide.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	aide.add_theme_constant_override("outline_size", 5)
	aide.position = Vector2(24, 80)
	ui.add_child(aide)
	_invite = Label.new()
	_invite.add_theme_font_override("font", Polices.texte())
	_invite.add_theme_font_size_override("font_size", 20)
	_invite.add_theme_color_override("font_color", Color("#F2CF7A"))
	_invite.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_invite.add_theme_constant_override("outline_size", 6)
	_invite.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_invite.offset_top = -90
	_invite.offset_bottom = -60
	_invite.offset_left = -300
	_invite.offset_right = 300
	_invite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(_invite)
