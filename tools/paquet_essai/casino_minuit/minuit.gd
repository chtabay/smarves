extends Node3D
## Casino Minuit, sur le Strip de Las Vegas : une commune « ailleurs » (socle 1.5), rejointe en avion
## depuis Poitiers-Biard. Portage en GDScript des lots A, B et C du moteur web, bâtis par le kit (kit.gd)
## zone par zone : la rotonde d'entrée, l'atrium, le grand escalier et la galerie de la mezzanine (lot A) ;
## l'ouest (lot B) : le lobby de l'hôtel, le salon, les machines, le poker, les hautes limites, et à la
## mezzanine le lounge et le jardin d'hiver ; l'est (lot C) : le foyer du théâtre, la fosse aux tables, la
## caisse, le club Minuit, les paris sportifs, et à la mezzanine le Lucullus et les boutiques.
## Comme toute commune, la scène expose `player` et `camera` : le jeu y ajoute la bascule de vue
## (Tab), les commandes tactiles et la carte. On entre à pied, par la porte-tambour de la rotonde.

const BASE := "res://communes/casino_minuit/"
const ZONES := ["rotonde", "atrium", "escalier", "galerie",
	"lobby", "salon", "machines", "poker", "hautes_limites", "wc_ouest", "lounge", "jardin", "wc_mezzanine",
	"foyer", "pit", "cage", "club", "wc_est", "sports", "restaurant", "boutiques"]
## Le change : un jeton du Minuit vaut un crédit de Smarves. C'est un premier taux, que réglera plus tard
## une doctrine économique commune aux villes. La caisse l'affiche ; rien ne s'y échange tant que les tables
## ne sont pas jouables.
const TAUX_JETONS := 1.0
## Le salon des hautes limites : son cordon s'ouvre au seuil de son lieu.
const HAUTES_LIMITES := "hautes_limites"
## Les lieux du lot C qui s'ouvrent à leur seuil.
const CLUB_MINUIT := "club_minuit"
const LUCULLUS := "lucullus"
const BOUTIQUES := "boutiques"
## Les cordons de velours des lieux à seuil du lot C : le lieu, l'invite, la hauteur du sol, les travées
## [[ax, az], [bx, bz]] tendues devant leurs portes.
const CORDONS := [
	[LUCULLUS, "Le Lucullus", 6.0, [[[18.55, -20.9], [18.55, -17.1]], [[18.6, -12.55], [21.4, -12.55]]]],
	[BOUTIQUES, "Les boutiques de luxe", 6.0, [[[25.65, 5.8], [23.85, 5.8]], [[34.8, -2.2], [34.8, -0.45]]]],
]
## Les crans de la caméra de dessus, au plus près : sous les plafonds, on ne recule pas loin.
const CRANS := [[4.0, -40.0, 50.0], [7.0, -55.0, 50.0], [11.0, -70.0, 50.0]]
## L'arrivée, juste derrière la porte-tambour, face au nord et à la fontaine de la Fortune.
const ARRIVEE := Vector3(0, 0.05, 27.0)
## Le retour du stade : devant la porte du couloir, dans l'allée est du grand escalier, tourné vers l'ouest.
const RETOUR_STADE := Vector3(12.6, 0.05, -17.0)
const STADE := "stade_fortune"

var player: CharacterBody3D
var camera: Camera3D

var K
var _t := 0.0
var _invite: Label
var _message: Label


func _ready() -> void:
	_ambiance()
	K = load(BASE + "kit.gd").new(self)
	for z in ZONES:
		load(BASE + "zones/%s.gd" % z).construire(K)
	_cordon()
	for c in CORDONS:
		_cordon_lieu(c[0], c[1], c[2], c[3])
	load(BASE + "zones/figurants.gd").peupler(self)
	_joueur()
	_interface()
	# On entre à pied : la vue de dessus reste à un Tab.
	if get_tree().current_scene == self:
		Vue.basculer.call_deferred(self)


func _process(dt: float) -> void:
	_t += dt
	K.animer(dt, _t)
	var f = player.focus_target if player else null
	_invite.text = str(f.get_meta("prompt", "")) + "  [E]" if f != null and f.has_meta("prompt") else ""


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
	if Game.return_point == STADE:
		Game.return_point = ""
		player.global_position = RETOUR_STADE
		player.rotation.y = PI / 2.0
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
		"stade": _stade()
		"change": _dire("Au change, un jeton du Minuit vaut %s crédit. La caisse est à l'est, derrière la fosse aux tables." % _taux())
		"caisse": _dire("À la caisse, 1 jeton = %s crédit de Smarves. Rien ne s'échange encore : les tables ne sont pas jouables." % _taux())
		"hautes_limites": _dire("Le salon des hautes limites ouvre à %s crédits gagnés au jeu." % Game.fmt(_seuil(HAUTES_LIMITES)))
		"club_minuit": _club()
		"distributeur": _dire("Le distributeur affiche votre solde : %s crédits. Les retraits viendront avec les tables." % Game.fmt(Game.credits))
		"lucullus": _lieu(LUCULLUS, "Le Lucullus reçoit à dîner à partir de %s crédits gagnés au jeu.", "Le maître d'hôtel vous attend : la carte du Lucullus viendra plus tard.")
		"boutiques": _lieu(BOUTIQUES, "Les boutiques de luxe reçoivent à partir de %s crédits gagnés au jeu.", "Les vitrines vous sont ouvertes ; les achats viendront plus tard.")
		"theatre": _dire("Le Minuit Showroom fait relâche ce soir : la saison du théâtre viendra plus tard.")
		"paris": _dire("Les paris suivent les matchs du dimanche, comme à Smarves. Les guichets ouvriront avec les tables.")


func _taux() -> String:
	return str(TAUX_JETONS).trim_suffix(".0")


## Le comptoir du club de fidélité : on s'y inscrit une fois le seuil du lieu gagné au jeu.
func _club() -> void:
	var seuil := _seuil(CLUB_MINUIT)
	if Game.won < seuil:
		_dire("Le Club Minuit accueille ses membres à partir de %s crédits gagnés au jeu." % Game.fmt(seuil))
		return
	_dire("Bienvenue au Club Minuit : vos points vaudront de l'or quand les tables ouvriront.")


## Un lieu à seuil : son invite tant qu'il est fermé, son accueil au-delà.
func _lieu(id: String, ferme: String, ouvert: String) -> void:
	var seuil := _seuil(id)
	_dire(ferme % Game.fmt(seuil) if Game.won < seuil else ouvert)


## Le seuil d'un lieu de la commune (le total gagné au jeu qui l'ouvre).
func _seuil(id: String) -> int:
	var c: Commune = Communes.commune("casino_minuit")
	for l in (c.lieux() if c else []):
		if l.id == id:
			return int(l.seuil)
	return 0


## Le stade de la Fortune : la porte s'ouvre au seuil de son lieu (le total gagné au jeu), comme partout.
func _stade() -> void:
	var seuil := _seuil(STADE)
	if Game.won < seuil:
		_dire("Le stade de la Fortune ouvre à %s crédits gagnés au jeu." % Game.fmt(seuil))
		return
	Football.ouvrir_stade("casino_minuit")


## Le cordon de velours du seuil des hautes limites, au nord de l'atrium : tendu tant que le joueur n'a pas
## gagné le seuil du lieu ; au-delà, les poteaux sont rangés contre le mur et le salon est ouvert.
func _cordon() -> void:
	K.zone_debut("CordonHL")
	var ouvert := Game.won >= _seuil(HAUTES_LIMITES)
	for x in ([-17.6, -17.25] if ouvert else [-17.35, -14.65]):
		K.cyl("or", 0.17, 0.2, 0.04, x, 0.02, -11.3, 12)
		K.cyl("or", 0.025, 0.025, 1.0, x, 0.52, -11.3, 8)
		K.sph("or", 0.06, x, 1.05, -11.3)
	if not ouvert:
		K.beam("coussin", Vector3(-17.35, 0.9, -11.3), Vector3(-14.65, 0.9, -11.3), 0.05, 0.05)
		K.obstacle(-17.5, -14.5, -11.5, -11.1)
		K.interaction(HAUTES_LIMITES, "Le salon des hautes limites", -16, 1.0, -11.0, Vector3(3.0, 2.0, 0.8))
	K.zone_fin()


## Les cordons des lieux du lot C (CORDONS) : tendus devant leurs portes tant que le joueur n'a pas gagné le
## seuil du lieu ; au-delà, les poteaux restent seuls contre les tableaux et les portes sont libres.
func _cordon_lieu(id: String, invite: String, y: float, travees: Array) -> void:
	K.zone_debut("Cordon_" + id)
	var ouvert := Game.won >= _seuil(id)
	for t in travees:
		var a := Vector3(t[0][0], y, t[0][1])
		var b := Vector3(t[1][0], y, t[1][1])
		for p in [a, b]:
			K.cyl("or", 0.17, 0.2, 0.04, p.x, y + 0.02, p.z, 12)
			K.cyl("or", 0.025, 0.025, 1.0, p.x, y + 0.52, p.z, 8)
			K.sph("or", 0.06, p.x, y + 1.05, p.z)
		if not ouvert:
			K.beam("coussin", a + Vector3(0, 0.9, 0), b + Vector3(0, 0.9, 0), 0.05, 0.05)
			K.segment(a.x, a.z, b.x, b.z, 0.3, y, 2.4)
			var c := (a + b) / 2.0
			var n := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * 0.4
			K.interaction(id, invite, c.x - n.x, y + 1.0, c.z - n.z, Vector3(maxf(absf(b.x - a.x), 0.8), 2.0, maxf(absf(b.z - a.z), 0.8)))
	K.zone_fin()


func _dire(t: String) -> void:
	_message.text = t
	_message.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_message, "modulate:a", 0.0, 0.6)


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
	_message = _invite.duplicate()
	_message.offset_top = -140
	_message.offset_bottom = -110
	_message.add_theme_color_override("font_color", Color("#F3EAD7"))
	ui.add_child(_message)
