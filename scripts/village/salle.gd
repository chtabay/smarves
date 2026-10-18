extends "res://scripts/shop_interior.gd"
## Les salles de jeu du village, à la première personne : le Café de la Place et ses Smarvoise, la salle
## François-Rabelais et son grand loto, l'arrière-salle du Moulin des Dames et son blackjack. On ne joue
## plus dehors : on entre, on s'approche de la machine ou de la table, E ouvre le jeu (docs/VILLAGE.md).
## La pièce, les matériaux, la porte et l'interface viennent de l'intérieur des vendeurs (shop_interior.gd).
## Capture : godot --path . res://scenes/cafe.tscn -- --capture=sortie.png [--at=x,z,lacet,tangage] [--open=jeu|tableau|feuille] [--won=…] [--journee=n]

const SLOT := preload("res://scripts/slot_machine.gd")
const TABLEAU := preload("res://scripts/socle/foot_tableau.gd")
## Le total gagné au jeu à partir duquel Josiane accroche l'ardoise du championnat de la Vienne au mur
## du café : le premier rendez-vous du football (docs/SUITE.md, section 6), qu'on lit sans miser.
const SEUIL_TABLEAU := 1000
## Le total gagné à partir duquel Josiane sort le carnet du PMU : les paris sur la journée, au comptoir.
const SEUIL_PARIS := 2000
const PARIS := preload("res://scripts/socle/foot_paris.gd")
const LOTO := preload("res://scripts/loto_panel.gd")
const BLACKJACK := preload("res://scripts/blackjack_panel.gd")
const KA := "res://assets/kenney/arcade/"

## Chaque salle : son nom, son tenancier (fiche de Cast.NAMED), ce qu'il dit, le jeu, et où mène la porte.
const SALLES := {
	"cafe": {"name": "Le Café de la Place", "host": "Josiane", "who": "josiane", "pose": "bar",
		"jeu": "E : jouer à la Smarvoise", "sortie": "E : sortir sur la place",
		"lines": ["« Une Smarvoise, mon chou ? Elle a rendu trois fois la mise à Dédé, mardi. Enfin, une fois. »",
			"« Le 421 du comptoir, c'est pour les habitués. Vous, c'est la machine : elle travaille pour vous. »",
			"« Si vous êtes à sec, M. Brunet passe prendre son café à sept heures. Il prête avec le sourire. »"]},
	"rabelais": {"name": "La salle François-Rabelais", "host": "M. Gaudin", "who": "gaudin", "pose": "sing",
		"jeu": "E : prendre un carton pour le grand loto", "sortie": "E : sortir sur la place",
		"lines": ["« Le 22, les deux petits canards ! Pardon, on ne dit plus ça. Le 22. »",
			"« Ce soir, le gros lot, c'est un jambon et un séjour à Châtelaillon. Le jambon est réel. »",
			"« Un carton, c'est un placement. Trois cartons, c'est une stratégie. »"]},
	"moulin": {"name": "Le Moulin des Dames", "host": "Le meunier", "who": "meunier", "pose": "stand_table",
		"jeu": "E : s'asseoir à la table de blackjack", "sortie": "E : sortir sur la berge",
		"lines": ["« L'arrière-salle, c'est pour les amis. Vous êtes un ami si vous misez. »",
			"« La roue tourne dans le bief, les cartes tournent sur le feutre. Tout tourne, ici. »",
			"« Dix-sept, je reste. Toujours. C'est mon grand-père qui me l'a appris, il a perdu le moulin deux fois. »"]},
}

var _salle: Dictionary
var _game: Control
## L'ardoise du championnat, une fois accrochée.
var _ardoise: Node3D
## Le carnet du PMU sur le zinc, derrière son seuil.
var _carnet_pmu: Node3D


func _ready() -> void:
	_salle = SALLES.get(shop, SALLES.cafe)
	_serif = Polices.texte()
	match shop:
		"rabelais":
			W = 12.0
			D = 10.0
			H = 4.0
		"moulin":
			W = 8.0
			D = 7.0
			H = 3.0
		_:
			W = 10.0
			D = 8.0
			H = 3.2
	_environment()
	match shop:
		"rabelais":
			_room(_wood_floor(Color(0.62, 0.45, 0.28)), _std(Color(0.78, 0.84, 0.72), 0.85), Color(0.95, 0.94, 0.9), Color(0.55, 0.42, 0.3))
			_rabelais()
		"moulin":
			_room(_flagstones(), _stone(), Color(0.5, 0.42, 0.34))
			_moulin()
		_:
			_room(_checker(Color(0.86, 0.82, 0.74), Color(0.42, 0.16, 0.12)), _wallpaper(Color(0.7, 0.5, 0.3), Color(0.76, 0.56, 0.34)), Color(0.9, 0.84, 0.7), Color(0.3, 0.17, 0.1))
			_cafe()
	_door()
	for a in find_children("*", "Area3D", true, false):
		if a.get_meta("interact", "") == "exit":
			a.set_meta("prompt", _salle.sortie)
	_build_ui()
	player = PLAYER.new()
	player.position = Vector3(0, 0, D / 2.0 - 1.2)
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("casino")
	_maybe_capture()


func _place_name() -> String:
	return _salle.name


func say(text: String) -> void:
	_speech.text = "%s : %s" % [_salle.host, text]
	_show_speech()


## Une annonce sans personne qui parle : un gain, un lieu qui ouvre.
func _note(text: String) -> void:
	_speech.text = text
	_show_speech()


func _show_speech() -> void:
	_speech.modulate.a = 1.0
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = create_tween()
	_speech_tween.tween_interval(4.0 + _speech.text.length() * 0.04)
	_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.8)


func _process(_delta: float) -> void:
	_credits.text = "%s crédits" % Game.fmt(Game.credits)
	var t: Node = player.focus_target if player else null
	_prompt.visible = t != null and _game == null
	if t != null:
		_prompt.text = str(t.get_meta("prompt", ""))
	if _keeper and player:
		var d := player.global_position - _keeper.global_position
		_keeper.rotation.y = lerp_angle(_keeper.rotation.y, atan2(d.x, d.z), 0.05)


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			Game.return_point = shop
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		"keeper":
			say((_salle.lines as Array).pick_random())
			var c := _keeper.get_child(0)
			if c.has_method("gesture"):
				c.gesture("talk")
				c.talk(2.5)
		"jeu":
			open_game()
		"tableau":
			open_tableau()
		"paris":
			open_paris()


# --- Le jeu ---------------------------------------------------------------------------------------

## La machine à sous demande à son hôte de payer la mise.
func spend(amount: int) -> bool:
	return Game.spend(amount)


func open_game() -> void:
	if _game != null:
		return
	var p: PanelContainer
	match shop:
		"rabelais":
			p = LOTO.new()
		"moulin":
			p = BLACKJACK.new()
			p.title = "Le blackjack du Moulin des Dames"
		_:
			p = SLOT.new()
			p.game = self
	p.played.connect(_on_played)
	p.closed.connect(func():
		p.queue_free()
		_game = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_game = p


## L'ardoise du championnat, en grand : on la lit, on ne joue pas.
func open_tableau() -> void:
	if _game != null:
		return
	var p: PanelContainer = TABLEAU.new()
	p.closed.connect(func():
		p.queue_free()
		_game = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_game = p


## Le carnet du PMU, en grand : les paris sur la journée à venir (FootParis).
func open_paris() -> void:
	if _game != null:
		return
	var p: PanelContainer = PARIS.new()
	p.closed.connect(func():
		p.queue_free()
		_game = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_game = p


## Les tickets dont le dimanche est passé se règlent en entrant au café, et Josiane le dit.
func _regler_paris() -> void:
	if shop != "cafe":
		return
	for t in Paris.regler():
		if t.etat == "gagne":
			_note("Josiane : « Votre ticket de la journée %d est bon : %s crédits. »" % [int(t.j), Game.fmt(int(t.gain))])
		else:
			_note("Josiane : « La journée %d, c'est pour la maison. Un autre ? »" % int(t.j))


func _on_played(bet: int, payout: int) -> void:
	Sfx.result(bet, payout)
	var before := Game.won
	Game.cash_in(payout)
	if payout >= bet * 20:
		_note("Jackpot ! Toute la salle se retourne.")
	# Les lieux qui ouvrent avec ce gain : leur tenancier fait signe, comme sur la place.
	for p in Commune.smarves().lieux():
		if p.seuil > 0 and before < p.seuil and Game.won >= p.seuil:
			_note("%s vous fait signe : %s ouvre ce soir." % [p.host, p.name.substr(0, 1).to_lower() + p.name.substr(1)])
	if shop == "cafe" and before < SEUIL_TABLEAU and Game.won >= SEUIL_TABLEAU and _ardoise == null:
		_tableau_du_dimanche()
		_note("Josiane accroche une ardoise au mur de l'est : le tableau du dimanche, le championnat de la Vienne.")
	if shop == "cafe" and before < SEUIL_PARIS and Game.won >= SEUIL_PARIS and _carnet_pmu == null:
		_carnet_du_pmu()
		_note("Josiane pose le carnet du PMU sur le zinc : les paris sur la journée du championnat, au comptoir.")
	if shop == "cafe" and Game.advance_if_broke(SLOT.BETS[0]):
		say("Je vous avance %d crédits. « Un placement, ça se soutient. »" % Game.ADVANCE)


# --- Le tenancier et les habitués --------------------------------------------------------------

func _host(at: Vector3, estrade := 0.0) -> void:
	if estrade > 0.0:
		_box(Vector3(2.8, estrade, 1.5), Vector3(at.x, estrade / 2.0, at.z), _std(Color(0.3, 0.18, 0.1), 0.6), true)
	_keeper = Node3D.new()
	_keeper.position = at + Vector3(0, estrade, 0)
	add_child(_keeper)
	var c := CRITTER.new()
	if Cast.NAMED.has(_salle.who):
		c.look = Cast.NAMED[_salle.who].duplicate(true)
	c.idle_anim = _salle.pose
	c.scale = Vector3.ONE * PEOPLE_SCALE
	_keeper.add_child(c)
	_interactive(_keeper, "keeper", "E : parler à %s" % _salle.host, Vector3(1.2, 2.2, 1.6), Vector3(0, 1.1, 0.9))


## Un habitué assis, tiré au hasard (toujours le même pour une même graine).
func _regular(at: Vector3, rot_y: float, seed_value: int) -> void:
	var c := CRITTER.new()
	c.randomize_look(seed_value)
	c.scale = Vector3.ONE * PEOPLE_SCALE
	c.position = at
	c.rotation_degrees.y = rot_y
	add_child(c)
	c.debug_anim("sit_table")


# --- Matériaux de plus ---------------------------------------------------------------------------

func _checker(a: Color, b: Color) -> StandardMaterial3D:
	# Le carrelage en damier des cafés.
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, a)
	img.set_pixel(1, 1, a)
	img.set_pixel(1, 0, b)
	img.set_pixel(0, 1, b)
	var m := _std(Color.WHITE, 0.3)
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.0, 1.0, 1.0)
	return m


func _stone() -> StandardMaterial3D:
	var m := _std(Color(0.74, 0.68, 0.58), 0.95)
	m.albedo_texture = _noise(0.05, Vector2.ONE, Color(0.62, 0.58, 0.52))
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return m


func _flagstones() -> StandardMaterial3D:
	var m := _std(Color(0.52, 0.46, 0.4), 0.8)
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.02
	var t := NoiseTexture2D.new()
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.58, 0.55))
	g.set_color(1, Color.WHITE)
	t.color_ramp = g
	m.albedo_texture = t
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.3, 0.3, 0.3)
	return m


func _glow(c: Color, energy := 3.0) -> StandardMaterial3D:
	var m := _std(c, 0.4)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


# --- Le Café de la Place --------------------------------------------------------------------------

func _cafe() -> void:
	var wood := _std(Color(0.3, 0.16, 0.08), 0.45)
	var zinc := _std(Color(0.72, 0.74, 0.76), 0.22, 0.85)
	# Le zinc, au fond, et Josiane derrière.
	var bz := -D / 2.0 + 1.9
	_box(Vector3(4.6, 1.05, 0.6), Vector3(0.6, 0.525, bz), wood, true)
	_box(Vector3(4.7, 0.05, 0.72), Vector3(0.6, 1.07, bz), zinc)
	_box(Vector3(4.7, 0.05, 0.05), Vector3(0.6, 0.12, bz + 0.33), zinc)
	for x in [-1.0, 0.2, 1.4, 2.6]:
		_place(KK + "furniture/chair_stool_wood.gltf", Vector3(x, 0, bz + 0.75), 0.8, randf() * 40.0)
	# Le 421 sur son tapis, la pression, le cendrier.
	_box(Vector3(0.5, 0.02, 0.4), Vector3(-0.8, 1.1, bz + 0.1), _std(Color(0.1, 0.35, 0.18), 0.9))
	var die := _std(Color(0.96, 0.95, 0.9), 0.4)
	for i in 3:
		_box(Vector3(0.05, 0.05, 0.05), Vector3(-0.9 + i * 0.09, 1.135, bz + 0.1 + (i % 2) * 0.05), die).rotation_degrees.y = i * 23.0
	_cyl(0.05, 0.4, Vector3(1.6, 1.3, bz - 0.1), zinc)
	_cyl(0.07, 0.03, Vector3(2.4, 1.11, bz + 0.15), _std(Color(0.55, 0.15, 0.1), 0.4))
	_host(Vector3(0.6, 0, -D / 2.0 + 0.9))
	# Les étagères de bouteilles, éclairées par-dessous.
	for row in 2:
		var y := 1.5 + row * 0.55
		_box(Vector3(4.4, 0.04, 0.25), Vector3(0.6, y, -D / 2.0 + 0.14), wood)
		for k in 14:
			var col: Color = [Color(0.25, 0.45, 0.2), Color(0.55, 0.3, 0.1), Color(0.85, 0.75, 0.4), Color(0.4, 0.1, 0.12)][(k + row) % 4]
			_cyl(0.045, 0.32, Vector3(-1.4 + k * 0.29, y + 0.18, -D / 2.0 + 0.14), _std(col, 0.15))
	_lamp(Vector3(0.6, 1.4, -D / 2.0 + 0.5), Color(1.0, 0.7, 0.4), 0.9, 4.0)
	_label3d("Café de la Place", Vector3(0.6, 2.85, -D / 2.0 + 0.12), 90, Color(0.95, 0.85, 0.6))
	_label3d("Tabac  ·  Loto  ·  PMU", Vector3(0.6, 2.58, -D / 2.0 + 0.12), 36, Color(0.85, 0.75, 0.55))
	# Les quatre Smarvoise contre le mur ouest, sous leur néon.
	var mx := -W / 2.0 + 0.55
	for z in [-1.6, -0.5, 0.6, 1.7]:
		var m := _place(KA + "gambling-machine.glb", Vector3(mx, 0, z), 2.3, 90.0)
		_solid(m)
		_interactive(m, "jeu", _salle.jeu, Vector3(0.9, 1.0, 0.9), Vector3(0.3, 0.5, 0))
		_lamp(Vector3(mx + 0.8, 1.6, z), Color(1.0, 0.45, 0.75), 0.5, 2.5)
	var neon := _label3d("JACKPOT", Vector3(-W / 2.0 + 0.08, 2.6, 0.05), 140, Color(2.2, 0.7, 1.6), 90.0)
	neon.shaded = false
	_label3d("La Smarvoise  ·  la machine de Josiane", Vector3(-W / 2.0 + 0.08, 2.25, 0.05), 40, Color(1.0, 0.85, 0.6), 90.0).shaded = false
	# La salle : des guéridons, des habitués, le juke-box du coin.
	for t in [[Vector3(1.6, 0, 0.4), 11], [Vector3(3.2, 0, -0.9), 12], [Vector3(3.0, 0, 2.0), 13]]:
		var p: Vector3 = t[0]
		_place(KK + "furniture/table_small.gltf", p, 0.9)
		_solid_box_at(Vector3(0.7, 0.8, 0.7), p + Vector3(0, 0.4, 0))
		_place(KK + "furniture/chair_A_wood.gltf", p + Vector3(-0.6, 0, 0), 0.8, 90.0)
		_place(KK + "furniture/chair_A_wood.gltf", p + Vector3(0.6, 0, 0), 0.8, -90.0)
	_regular(Vector3(1.0, 0, 0.4), 90.0, 31)
	_regular(Vector3(3.8, 0, -0.9), -90.0, 32)
	var juke: Node3D = MEUBLES.build("juke_box")
	juke.position = Vector3(W / 2.0 - 0.5, 0, -D / 2.0 + 0.6)
	juke.rotation_degrees.y = -45.0
	add_child(juke)
	_solid(juke)
	_bulb(Vector3(-1.5, H - 0.7, 0.2), Color(0.85, 0.55, 0.3))
	_bulb(Vector3(2.4, H - 0.7, 0.6), Color(0.85, 0.55, 0.3))
	if Game.won >= SEUIL_TABLEAU:
		_tableau_du_dimanche()
	if Game.won >= SEUIL_PARIS:
		_carnet_du_pmu()
	_regler_paris.call_deferred()


## Le carnet du PMU, posé sur le zinc à côté du 421 : E ouvre le comptoir des paris (FootParis).
func _carnet_du_pmu() -> void:
	if _carnet_pmu != null:
		return
	var bz := -D / 2.0 + 1.9
	_carnet_pmu = Node3D.new()
	_carnet_pmu.position = Vector3(0.2, 1.1, bz + 0.12)
	add_child(_carnet_pmu)
	_box(Vector3(0.36, 0.025, 0.26), Vector3.ZERO, _std(Color(0.16, 0.42, 0.2), 0.7), false, _carnet_pmu)
	_box(Vector3(0.3, 0.012, 0.2), Vector3(0, 0.018, 0), _std(Color(0.95, 0.93, 0.85), 0.9), false, _carnet_pmu)
	_cyl(0.008, 0.16, Vector3(0.12, 0.03, 0.02), _std(Color(0.12, 0.12, 0.3), 0.3), _carnet_pmu).rotation_degrees = Vector3(90, 0, 25)
	var l := _label3d("PMU", Vector3(0, 0.03, 0), 18, Color(0.95, 0.95, 0.9))
	l.rotation_degrees.x = -90.0
	l.reparent(_carnet_pmu)
	l.position = Vector3(0, 0.03, -0.05)
	_interactive(_carnet_pmu, "paris", "E : parier au comptoir", Vector3(1.0, 1.2, 1.2), Vector3(0, -0.3, 0.5))


## L'ardoise du championnat de la Vienne, sur le mur de l'est, entre la fenêtre et la porte : le titre à la craie,
## la division suivie et son premier, le prochain coup d'envoi. E l'ouvre en grand (FootTableau).
func _tableau_du_dimanche() -> void:
	if _ardoise != null:
		return
	_ardoise = Node3D.new()
	_ardoise.position = Vector3(W / 2.0 - 0.05, 1.7, 2.6)
	add_child(_ardoise)
	var cadre := _std(Color(0.42, 0.28, 0.14), 0.6)
	_box(Vector3(0.06, 1.3, 1.9), Vector3.ZERO, cadre, false, _ardoise)
	_box(Vector3(0.04, 1.18, 1.78), Vector3(-0.02, 0, 0), _std(Color(0.12, 0.17, 0.15), 0.95), false, _ardoise)
	# Le petit rebord et ses craies.
	_box(Vector3(0.12, 0.03, 1.9), Vector3(-0.04, -0.66, 0), cadre, false, _ardoise)
	for k in 3:
		var craie := _cyl(0.008, 0.08, Vector3(-0.07, -0.63, -0.5 + k * 0.17), _std(Color(0.93, 0.93, 0.88), 0.9), _ardoise)
		craie.rotation_degrees.x = 90.0
		craie.rotation_degrees.y = k * 30.0 - 30.0
	_lamp(Vector3(W / 2.0 - 0.8, 2.3, 2.6), Color(1.0, 0.85, 0.6), 0.6, 3.0)
	_interactive(_ardoise, "tableau", "E : lire le tableau du dimanche", Vector3(1.4, 2.4, 2.2), Vector3(-0.6, -0.9, 0))
	_ecrire_ardoise()
	Football.change.connect(_ecrire_ardoise)


## Ce que Josiane a écrit à la craie sur l'ardoise, remis au jour quand la pyramide bouge.
func _ecrire_ardoise() -> void:
	if _ardoise == null:
		return
	for c in _ardoise.get_children():
		if c is Label3D:
			c.free()
	if Football.niveaux.is_empty():
		Football.actualiser()
	var tableau: PanelContainer = TABLEAU.new()
	var d: Array = tableau.division_suivie()
	var lignes: Array = Football.classement(Football.saison, d[0], d[1])
	var prochain: Array = Football.prochain_coup_envoi(Football.maintenant())
	var joues: int = Football.journee_jouee()
	var textes := [
		["Le tableau du dimanche", 0.42, 30, Color(0.95, 0.85, 0.6)],
		["Championnat de la Vienne  ·  saison %d" % Football.saison, 0.27, 17, Color(0.93, 0.93, 0.88)],
		["%s  ·  %s" % [Football.nom_division(d[0], d[1]), "journée %d" % joues if joues > 0 else "avant la 1re journée"], 0.1, 17, Color(0.93, 0.93, 0.88)],
	]
	for i in mini(3, lignes.size()):
		var l: Dictionary = lignes[i]
		textes.append(["%d.  %s   %d pts" % [i + 1, Football.clubs[l.club].nom, l.pts], -0.05 - i * 0.13, 16, Color(0.93, 0.93, 0.88)])
	textes.append(["Coup d'envoi : %s à %d h" % [TABLEAU.date(prochain[2]), Football.HEURE_COUP_ENVOI], -0.5, 17, Color(0.95, 0.85, 0.6)])
	for t in textes:
		var l := Label3D.new()
		l.text = t[0]
		l.font = _serif
		l.font_size = t[2]
		l.pixel_size = 0.004
		l.modulate = t[3]
		l.outline_size = 0
		l.position = Vector3(-0.045, t[1], 0)
		l.rotation_degrees.y = -90.0
		_ardoise.add_child(l)
	tableau.free()


## Un obstacle invisible.
func _solid_box_at(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.position = pos
	body.add_child(cs)
	add_child(body)


# --- La salle François-Rabelais ---------------------------------------------------------------------

func _rabelais() -> void:
	var trestle := _std(Color(0.55, 0.38, 0.22), 0.6)
	var cloth := _std(Color(0.92, 0.9, 0.84), 0.9)
	# La scène, au fond, et M. Gaudin au micro devant le tableau des numéros.
	_box(Vector3(W - 1.0, 0.5, 2.2), Vector3(0, 0.25, -D / 2.0 + 1.1), _std(Color(0.4, 0.2, 0.14), 0.55), true)
	_box(Vector3(W - 1.0, 0.04, 0.06), Vector3(0, 0.5, -D / 2.0 + 2.2), _std(Color(0.85, 0.68, 0.3), 0.25, 1.0))
	_host(Vector3(-1.4, 0.5, -D / 2.0 + 1.3))
	# Le tableau : quatre-vingt-dix cases, quelques-unes déjà tirées.
	var board := Node3D.new()
	board.position = Vector3(1.6, 2.3, -D / 2.0 + 0.08)
	add_child(board)
	_box(Vector3(3.4, 1.9, 0.06), Vector3.ZERO, _std(Color(0.1, 0.16, 0.12), 0.8), false, board)
	var lit := _glow(Color(1.0, 0.8, 0.35), 2.5)
	var dark := _std(Color(0.2, 0.26, 0.22), 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1987
	for n in 90:
		var cx := -1.5 + (n % 10) * 0.33
		var cy := 0.75 - (n / 10) * 0.18
		_box(Vector3(0.26, 0.13, 0.02), Vector3(cx, cy, 0.04), lit if rng.randf() < 0.3 else dark, false, board)
	_label3d("GRAND LOTO", Vector3(1.6, 3.55, -D / 2.0 + 0.12), 110, Color(0.9, 0.2, 0.15)).shaded = false
	# Le boulier sur sa table.
	_box(Vector3(0.8, 0.75, 0.6), Vector3(-0.4, 0.875, -D / 2.0 + 1.2), trestle)
	var cage := _std(Color(0.85, 0.7, 0.3), 0.2, 1.0)
	cage.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cage.albedo_color.a = 0.45
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	ball.mesh = sm
	ball.material_override = cage
	ball.position = Vector3(-0.4, 1.55, -D / 2.0 + 1.2)
	add_child(ball)
	for k in 9:
		_cyl(0.035, 0.07, Vector3(-0.4 + rng.randf_range(-0.15, 0.15), 1.36 + rng.randf() * 0.12, -D / 2.0 + 1.2 + rng.randf_range(-0.12, 0.12)), _std(Color(0.95, 0.92, 0.85), 0.4))
	# Les tables à tréteaux en rangs, avec leurs cartons et leurs jetons.
	var card := _std(Color(0.95, 0.85, 0.5), 0.8)
	var first := true
	for row in 3:
		for side in [-1.0, 1.0]:
			var x: float = side * 2.6
			var z := -0.6 + row * 1.7
			_box(Vector3(3.6, 0.05, 0.8), Vector3(x, 0.76, z), cloth, false)
			_box(Vector3(3.4, 0.74, 0.7), Vector3(x, 0.37, z), trestle, true)
			for k in 3:
				_box(Vector3(0.36, 0.01, 0.24), Vector3(x - 1.1 + k * 1.1, 0.79, z + 0.15), card)
			for k in 4:
				_place(KK + "furniture/chair_A_wood.gltf", Vector3(x - 1.35 + k * 0.9, 0, z + 0.7), 0.8, 180.0)
			if first:
				# Le carton du joueur, à la première table : E pour jouer.
				var spot := Node3D.new()
				spot.position = Vector3(x, 0, z)
				add_child(spot)
				_interactive(spot, "jeu", _salle.jeu, Vector3(3.6, 1.6, 2.0), Vector3(0, 0.8, 0.5))
				first = false
	_regular(Vector3(1.9, 0, 0.1), 180.0, 41)
	_regular(Vector3(3.7, 0, 0.1), 180.0, 42)
	_regular(Vector3(-3.0, 0, 1.8), 180.0, 43)
	_regular(Vector3(2.8, 0, 3.5), 180.0, 44)
	# Des fanions tricolores sous le plafond, et les néons de la salle des fêtes.
	var flags := [Color(0.2, 0.3, 0.75), Color(0.95, 0.95, 0.92), Color(0.85, 0.15, 0.15)]
	var cord := _std(Color(0.2, 0.18, 0.15), 0.8)
	for z in [-1.4, 2.6]:
		_box(Vector3(W, 0.012, 0.012), Vector3(0, H - 0.38, z), cord)
		for k in 22:
			var fx := -W / 2.0 + 0.5 + k * 0.5
			var flag := _box(Vector3(0.22, 0.26, 0.01), Vector3(fx, H - 0.52, z), _std(flags[k % 3], 0.8))
			flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-3.0, 3.0]:
		_box(Vector3(2.0, 0.05, 0.12), Vector3(x, H - 0.1, 0.8), _glow(Color(0.9, 0.95, 1.0), 3.0))
		_lamp(Vector3(x, H - 0.5, 0.8), Color(0.92, 0.95, 1.0), 1.8, 9.0, x < 0.0)
	_lamp(Vector3(0, 2.4, -D / 2.0 + 2.0), Color(1.0, 0.8, 0.5), 1.2, 6.0)


# --- L'arrière-salle du Moulin des Dames ----------------------------------------------------------

func _moulin() -> void:
	var oak := _std(Color(0.28, 0.17, 0.09), 0.6)
	# Les poutres du plafond et les sacs de farine contre le mur.
	for x in [-2.6, 0.0, 2.6]:
		_box(Vector3(0.25, 0.3, D), Vector3(x, H - 0.15, 0), oak)
	# Les sacs couchés en pile, trois puis deux puis un.
	var sack := _std(Color(0.88, 0.84, 0.74), 0.95)
	var n := 0
	for row in 3:
		for i in 3 - row:
			var bag := _cyl(0.22, 0.75, Vector3(-W / 2.0 + 0.55 + i * 0.46 + row * 0.23, 0.22 + row * 0.38, -D / 2.0 + 0.5), sack, self, 0.19)
			bag.rotation_degrees.x = 90.0
			bag.rotation_degrees.y = (n % 2) * 8.0 - 4.0
			n += 1
	_solid_box_at(Vector3(1.5, 1.2, 0.9), Vector3(-W / 2.0 + 0.95, 0.6, -D / 2.0 + 0.5))
	_label3d("FARINE  ·  MOULIN DES DAMES", Vector3(-W / 2.0 + 1.05, 1.95, -D / 2.0 + 0.12), 38, Color(0.35, 0.25, 0.15))
	# La table de jeu sous sa lampe, le meunier qui donne les cartes.
	var felt := _std(Color(0.05, 0.3, 0.16), 0.95)
	var tz := -0.4
	_box(Vector3(2.2, 0.06, 1.3), Vector3(0.6, 0.78, tz), felt)
	_box(Vector3(2.3, 0.06, 1.4), Vector3(0.6, 0.73, tz), oak)
	_box(Vector3(2.0, 0.7, 1.1), Vector3(0.6, 0.35, tz), oak, true)
	for k in 5:
		_box(Vector3(0.09, 0.005, 0.13), Vector3(0.0 + k * 0.3, 0.815, tz + 0.3), _std(Color(0.97, 0.96, 0.92), 0.5))
	for k in 6:
		_cyl(0.035, 0.02 + k * 0.012, Vector3(1.5, 0.82 + k * 0.006, tz - 0.3), _std([Color(0.8, 0.15, 0.1), Color(0.15, 0.3, 0.7)][k % 2], 0.4))
	_host(Vector3(0.6, 0, tz - 1.05))
	var spot := Node3D.new()
	spot.position = Vector3(0.6, 0, tz)
	add_child(spot)
	_interactive(spot, "jeu", _salle.jeu, Vector3(2.6, 1.6, 2.4), Vector3(0, 0.8, 0.4))
	for x in [-0.4, 1.6]:
		_place(KK + "furniture/chair_A_wood.gltf", Vector3(x, 0, tz + 1.0), 0.8, 180.0)
	_regular(Vector3(-0.55, 0, tz + 0.1), 90.0, 51)
	_place(KK + "furniture/chair_A_wood.gltf", Vector3(-0.75, 0, tz + 0.1), 0.8, 90.0)
	_label3d("BLACKJACK", Vector3(W / 2.0 - 0.08, 2.2, -1.6), 90, Color(2.0, 1.5, 0.7), -90.0).shaded = false
	# Une seule lampe basse au-dessus du feutre, et la lueur de la roue à travers la fenêtre.
	_cyl(0.32, 0.18, Vector3(0.6, 1.9, tz), _std(Color(0.15, 0.3, 0.2), 0.5), self, 0.12)
	_box(Vector3(0.015, H - 1.9, 0.015), Vector3(0.6, (H + 1.9) / 2.0, tz), _std(Color(0.1, 0.1, 0.1), 0.5))
	_lamp(Vector3(0.6, 1.75, tz), Color(1.0, 0.8, 0.5), 2.2, 5.0, true)
	_lamp(Vector3(-2.5, 2.0, 2.0), Color(1.0, 0.65, 0.35), 0.6, 5.0)
	for k in 3:
		_place("res://assets/kaykit/restaurant/crate.gltf", Vector3(W / 2.0 - 0.6, k * 0.5, D / 2.0 - 1.6), 0.6, k * 20.0)


# --- Capture --------------------------------------------------------------------------------------

func _maybe_capture() -> void:
	var path := ""
	var open := false
	var tableau := false
	var feuille := false
	var pari := false
	var ticket := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
			# La pyramide d'une capture se fonde sur place, sans toucher au fichier du joueur.
			Football.dossier = ""
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
			if v.size() > 3:
				player.camera.rotation.x = deg_to_rad(v[3])
		elif arg == "--open=jeu":
			open = true
		elif arg == "--open=tableau":
			tableau = true
		elif arg == "--open=feuille":
			tableau = true
			feuille = true
		elif arg == "--open=paris":
			pari = true
		elif arg.begins_with("--ticket="):
			# Un ticket déjà pris sur le match de l'Étoile de la journée à venir, pour la capture.
			ticket = int(arg.trim_prefix("--ticket="))
		elif arg.begins_with("--journee="):
			# L'horloge du football posée une heure après le coup d'envoi de cette journée de la saison 1.
			var t: int = Football.coup_envoi(1, int(arg.trim_prefix("--journee="))) + 3600
			Football.regler_horloge(func(): return t)
		else:
			_capture_setup(arg)
	if path == "":
		return
	if shop == "cafe" and Game.won >= SEUIL_TABLEAU:
		_tableau_du_dimanche()
	if shop == "cafe" and Game.won >= SEUIL_PARIS:
		_carnet_du_pmu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ticket > 0:
		var pce: Array = Football.prochain_coup_envoi(Football.maintenant())
		var div: Array = TABLEAU.new().division_suivie()
		for m in Football.journee(Football.saison, div[0], div[1], pce[1], 0):
			if m.dom == "smarves" or m.ext == "smarves":
				Paris.parier(Football.saison, pce[1], div[0], div[1], {Paris.cle(m.dom, m.ext): "1" if m.dom == "smarves" else "2"}, ticket)
	if open or tableau or pari:
		await get_tree().create_timer(1.0).timeout
		if pari:
			open_paris()
		elif tableau:
			open_tableau()
			if feuille:
				# La feuille du premier match de la dernière journée jouée.
				var d: Array = _game.division
				var m: Dictionary = Football.journee(Football.saison, d[0], d[1], Football.journee_jouee())[0]
				_game.ouvrir_feuille(Football.saison, Football.journee_jouee(), m.dom, m.ext)
		else:
			open_game()
	await get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
