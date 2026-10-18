extends "res://scripts/shop_interior.gd"
## Le stade municipal de Smarves, à la première personne, derrière son seuil (docs/SUITE.md, section 6) :
## la pelouse sous les projecteurs, la tribune couverte de l'Étoile, le tableau d'affichage, et le match
## du dimanche qui se joue minute par minute sur la pelouse (FootMatch, le même état que la feuille du
## café) : les vingt-deux joueurs suivent le ballon, chaque action se joue en scènes (la construction dans
## son couloir, le centre de l'ailier, le corner tiré du poteau, le coup franc, le tir qui finit au fond,
## dans les gants ou sur le poteau), le commentateur parle en bas de l'écran, le tableau tient le score. Avant la première journée, l'Étoile s'entraîne et le tableau donne le coup d'envoi.
## L'interface, la capture et les petits outils viennent de l'intérieur des vendeurs (shop_interior.gd).
## Capture : godot --path . res://scenes/stade.tscn -- --capture=sortie.png [--at=x,z,lacet,tangage] [--won=…] [--journee=n] [--minute=m]

## La pelouse : sa longueur (x) et sa largeur (z), et l'échelle des joueurs.
const L := 36.0
const P := 22.0
## Une minute de match par seconde ; Espace passe à quatre.
const COURSE := 4.2

var _etat := {}
var _joueurs := {}
var _hasard: Hasard
var _rencontre := {}
## Les joueurs sur la pelouse : id → son habitant, et où il va.
var _acteurs := {}
var _cibles := {}
var _ballon: MeshInstance3D
var _cible_ballon := Vector3.ZERO
## Les scènes d'une minute de match, jouées l'une après l'autre : {ballon, duree, porteur, vitesse, vol, action}.
## Le moteur dit ce qui arrive (le couloir, le centre, le corner, le tir) ; la pelouse le montre.
var _scenes: Array = []
var _scene_t := 0.0
var _vitesse_ballon := 14.0
var _vol := 0.0
var _depart_ballon := Vector3.ZERO
var _chrono := 0.0
var _possession := [0, 0]
var _score: Label3D
var _horloge: Label3D
var _affiche: Label3D
var _supporters: Array = []
## Les minutes déjà jouées depuis le coup d'envoi réel, et le dernier match fini (son état complet).
var _pas := 0
var _resultat := {}
const MI_TEMPS := 15 * 60
const TABLEAU := preload("res://scripts/socle/foot_tableau.gd")
## Le président Chauvin, et sa causerie (les consignes du prochain match) quand elle est ouverte.
const CAUSERIE := preload("res://scripts/socle/foot_causerie.gd")
const MERCATO := preload("res://scripts/socle/foot_mercato.gd")
var _president: Node3D
var _causerie: PanelContainer


func _ready() -> void:
	_serif = Polices.texte()
	W = L + 20.0
	D = P + 24.0
	_environment()
	_nuit()
	_pelouse()
	_tribune()
	_tableau_affichage()
	_le_president()
	_build_ui()
	player = PLAYER.new()
	player.position = Vector3(0, 0, -P / 2.0 - 4.0)
	player.rotation.y = PI
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("village")
	_rencontre = _choisir()
	_composer()
	_maybe_capture()


func _place_name() -> String:
	return "Le stade municipal"


# --- Le terrain -----------------------------------------------------------------------------------

## La nuit du dimanche : un ciel sombre, une lune, et les quatre projecteurs qui font le jour sur la pelouse.
func _nuit() -> void:
	var we: WorldEnvironment = null
	for c in get_children():
		if c is WorldEnvironment:
			we = c
	if we:
		we.environment.background_color = Color(0.03, 0.04, 0.09)
		we.environment.ambient_light_color = Color(0.45, 0.5, 0.6)
		we.environment.ambient_light_energy = 0.5
		we.environment.sdfgi_enabled = false
		we.environment.ssil_enabled = false
		we.environment.fog_enabled = true
		we.environment.fog_light_color = Color(0.08, 0.1, 0.16)
		we.environment.fog_density = 0.004
	var lune := DirectionalLight3D.new()
	lune.light_color = Color(0.6, 0.7, 0.9)
	lune.light_energy = 0.25
	lune.rotation_degrees = Vector3(-55, 30, 0)
	add_child(lune)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pied := Vector3(sx * (L / 2.0 + 2.5), 0, sz * (P / 2.0 + 2.5))
			_cyl(0.12, 14.0, pied + Vector3(0, 7.0, 0), _std(Color(0.5, 0.52, 0.55), 0.6, 0.4))
			_box(Vector3(1.6, 0.8, 0.3), pied + Vector3(0, 14.2, 0), _std(Color(0.25, 0.25, 0.28), 0.6)).look_at_from_position(pied + Vector3(0, 14.2, 0), Vector3(0, 0.5, 0), Vector3.UP)
			var spot := SpotLight3D.new()
			spot.light_color = Color(1.0, 0.98, 0.9)
			spot.light_energy = 9.0
			spot.spot_range = 50.0
			spot.spot_angle = 50.0
			spot.shadow_enabled = sz < 0.0 and sx < 0.0
			add_child(spot)
			spot.position = pied + Vector3(0, 14.0, 0)
			spot.look_at(Vector3(sx * L / 6.0, 0, sz * P / 6.0), Vector3.UP)


## La pelouse rayée, ses lignes, ses buts, la main courante et le gravier des abords.
func _pelouse() -> void:
	_box(Vector3(W, 0.2, D), Vector3(0, -0.1, 0), _std(Color(0.42, 0.4, 0.34), 0.95), true)
	var bandes := 12
	for i in bandes:
		var c := Color(0.27, 0.5, 0.2) if i % 2 == 0 else Color(0.32, 0.56, 0.24)
		_box(Vector3((L + 4.0) / bandes, 0.04, P + 4.0), Vector3(-(L + 4.0) / 2.0 + (i + 0.5) * (L + 4.0) / bandes, 0.02, 0), _std(c, 1.0))
	var craie := _std(Color(0.96, 0.96, 0.94), 0.9)
	var lw := 0.12
	for seg in [[Vector3(0, 0, -P / 2.0), Vector3(L, 0.01, lw)], [Vector3(0, 0, P / 2.0), Vector3(L, 0.01, lw)],
			[Vector3(-L / 2.0, 0, 0), Vector3(lw, 0.01, P)], [Vector3(L / 2.0, 0, 0), Vector3(lw, 0.01, P)], [Vector3(0, 0, 0), Vector3(lw, 0.01, P)]]:
		_box(seg[1], seg[0] + Vector3(0, 0.045, 0), craie)
	for s in [-1.0, 1.0]:
		var gx: float = s * L / 2.0
		_box(Vector3(lw, 0.01, 11.0), Vector3(gx - s * 5.5, 0.045, 0), craie)
		_box(Vector3(5.5, 0.01, lw), Vector3(gx - s * 2.75, 0.045, -5.5), craie)
		_box(Vector3(5.5, 0.01, lw), Vector3(gx - s * 2.75, 0.045, 5.5), craie)
		_box(Vector3(0.2, 0.01, 0.2), Vector3(gx - s * 3.6, 0.045, 0), craie)
	for i in 28:
		var a := TAU * i / 28.0
		var b := _box(Vector3(lw, 0.01, 0.65), Vector3(cos(a), 0.045, sin(a)) * 2.9, craie)
		b.rotation.y = -a
	_box(Vector3(0.2, 0.01, 0.2), Vector3(0, 0.045, 0), craie)
	# Les buts et leurs filets.
	var blanc := _std(Color(0.95, 0.95, 0.93), 0.4)
	var filet := _std(Color(0.85, 0.88, 0.9, 0.55), 0.9)
	filet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for s in [-1.0, 1.0]:
		var gx: float = s * L / 2.0
		for zz in [-1.9, 1.9]:
			_cyl(0.06, 1.6, Vector3(gx, 0.8, zz), blanc)
			_box(Vector3(1.4, 0.03, 0.03), Vector3(gx + s * 0.7, 1.6, zz), filet)
		_cyl(0.06, 3.9, Vector3(gx, 1.6, 0), blanc).rotation_degrees.x = 90.0
		_box(Vector3(0.03, 1.6, 3.8), Vector3(gx + s * 1.4, 0.8, 0), filet)
		_box(Vector3(1.4, 0.03, 3.8), Vector3(gx + s * 0.7, 1.6, 0), filet)
		for zz in [-1.9, 1.9]:
			_box(Vector3(1.4, 1.6, 0.03), Vector3(gx + s * 0.7, 0.8, zz), filet)
	# La main courante, le gravier derrière, et les bancs de touche côté tribune.
	var barre := _std(Color(0.85, 0.85, 0.88), 0.3, 0.8)
	for s in [-1.0, 1.0]:
		_box(Vector3(L + 8.0, 0.05, 0.05), Vector3(0, 1.0, s * (P / 2.0 + 3.0)), barre)
		_box(Vector3(0.05, 0.05, P + 6.0), Vector3(s * (L / 2.0 + 4.0), 1.0, 0), barre)
		for k in 15:
			_cyl(0.025, 1.0, Vector3(-L / 2.0 - 4.0 + k * (L + 8.0) / 14.0, 0.5, s * (P / 2.0 + 3.0)), barre)
	for s in [-1.0, 1.0]:
		var bx: float = s * 7.0
		_box(Vector3(4.0, 0.08, 0.5), Vector3(bx, 0.5, -P / 2.0 - 2.0), _std(Color(0.55, 0.36, 0.22), 0.7))
		_box(Vector3(4.0, 0.9, 0.08), Vector3(bx, 0.95, -P / 2.0 - 2.3), _std(Color(0.2, 0.3, 0.45), 0.6))
		_box(Vector3(4.2, 0.06, 1.2), Vector3(bx, 1.5, -P / 2.0 - 1.9), _std(Color(0.2, 0.3, 0.45), 0.6))
	# Le ballon.
	_ballon = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	_ballon.mesh = sm
	_ballon.material_override = _std(Color(0.97, 0.97, 0.95), 0.5)
	_ballon.position = Vector3(0, 0.22, 0)
	add_child(_ballon)


## La tribune couverte, derrière la ligne de touche nord : trois rangs de gradins, le toit, les supporters,
## la grille et l'arche par où l'on est entré.
func _tribune() -> void:
	var beton := _std(Color(0.75, 0.73, 0.7), 0.9)
	var bois := _std(Color(0.55, 0.36, 0.22), 0.7)
	var bleu := _std(Color(0.2, 0.3, 0.45), 0.6)
	var tz := -P / 2.0 - 4.0
	var tw := 22.0
	for i in 4:
		_box(Vector3(tw, 0.4 + i * 0.4, 1.0), Vector3(0, 0.2 + i * 0.2, tz - 0.5 - i * 1.0), beton, true)
		_box(Vector3(tw - 0.2, 0.08, 0.5), Vector3(0, 0.44 + i * 0.4, tz - 0.6 - i * 1.0), bois)
	_box(Vector3(tw + 1.0, 4.0, 0.3), Vector3(0, 2.8, tz - 4.6), _std(Color(0.92, 0.88, 0.8), 0.9), true)
	for px in [-tw / 2.0 + 0.3, -tw / 4.0, 0.0, tw / 4.0, tw / 2.0 - 0.3]:
		_box(Vector3(0.15, 4.2, 0.15), Vector3(px, 2.4, tz + 0.2), bleu)
	var toit := _box(Vector3(tw + 1.0, 0.12, 5.6), Vector3(0, 4.6, tz - 2.2), bleu)
	toit.rotation_degrees.x = -6.0
	_box(Vector3(tw + 1.0, 0.5, 0.08), Vector3(0, 4.3, tz + 0.25), _std(Color(0.97, 0.95, 0.9), 0.6))
	_label3d("L'ÉTOILE DE SMARVES  ·  STADE MUNICIPAL", Vector3(0, 4.3, tz + 0.3), 64, Color(0.15, 0.25, 0.5))
	# Les supporters, assis en tribune : ils se lèvent au but.
	var graine := 70
	for i in 4:
		for k in 7:
			if (i + k) % 3 == 1:
				continue
			graine += 1
			var c := CRITTER.new()
			c.randomize_look(graine)
			if graine % 2 == 0:
				c.look["top_color"] = "#1b3c8c"
			c.scale = Vector3.ONE * PEOPLE_SCALE
			c.position = Vector3(-tw / 2.0 + 1.5 + k * (tw - 3.0) / 6.0 + (i % 2) * 0.8, 0.4 + i * 0.4, tz - 0.3 - i * 1.0)
			add_child(c)
			c.debug_anim("sit")
			_supporters.append(c)
	# Derrière la tribune : la grille, l'arche de l'entrée, et la sortie sur la route du Bois.
	var pierre := _std(Color(0.9, 0.86, 0.76), 0.9)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.24, 1.8, 0.24), Vector3(-tw / 2.0 - 1.0 + s * 0.75, 0.9, tz + 1.0), pierre)
	_box(Vector3(1.8, 0.3, 0.1), Vector3(-tw / 2.0 - 1.0, 1.85, tz + 1.0), bleu)
	_label3d("STADE MUNICIPAL", Vector3(-tw / 2.0 - 1.0, 1.85, tz + 1.07), 40, Color(1.0, 0.9, 0.55))
	var sortie := Node3D.new()
	sortie.position = Vector3(-tw / 2.0 - 1.0, 0, tz + 1.0)
	add_child(sortie)
	_interactive(sortie, "exit", "E : sortir sur la route du Bois", Vector3(2.2, 2.2, 2.0), Vector3(0, 1.1, 0))
	_lamp(Vector3(-tw / 2.0 - 1.0, 2.4, tz + 1.6), Color(1.0, 0.75, 0.45), 1.5, 7.0)
	# Un muret ferme le reste, et la buvette dans l'angle.
	_box(Vector3(W, 1.2, 0.3), Vector3(0, 0.6, -D / 2.0 + 0.2), pierre, true)
	_box(Vector3(0.3, 1.2, D), Vector3(-W / 2.0 + 0.2, 0.6, 0), pierre, true)
	_box(Vector3(0.3, 1.2, D), Vector3(W / 2.0 - 0.2, 0.6, 0), pierre, true)
	_box(Vector3(W, 1.2, 0.3), Vector3(0, 0.6, D / 2.0 - 0.2), pierre, true)
	var buvette := Node3D.new()
	buvette.position = Vector3(tw / 2.0 + 3.0, 0, tz - 1.0)
	add_child(buvette)
	_box(Vector3(3.0, 2.4, 2.0), Vector3.ZERO + Vector3(0, 1.2, 0), _std(Color(0.9, 0.85, 0.7), 0.8), true, buvette)
	_box(Vector3(3.2, 0.1, 1.2), Vector3(0, 2.45, 1.2), bleu, false, buvette)
	_box(Vector3(2.4, 0.08, 0.5), Vector3(0, 1.05, 1.2), bois, false, buvette)
	_label3d("BUVETTE", Vector3(0, 2.0, 1.02), 44, Color(0.95, 0.85, 0.6)).position += buvette.position
	_lamp(buvette.position + Vector3(0, 2.2, 1.6), Color(1.0, 0.8, 0.5), 1.2, 6.0)
	_interactive(buvette, "buvette", "E : un café à la buvette", Vector3(3.4, 2.4, 2.0), Vector3(0, 1.2, 1.8))


## Le tableau d'affichage, derrière la touche sud, face à la tribune.
## Le président Chauvin, debout au bord de la pelouse devant sa tribune : E ouvre la causerie.
func _le_president() -> void:
	var c := CRITTER.new()
	c.randomize_look(1987)
	c.look["top"] = "veste"
	c.look["top_color"] = "#2b2f3a"
	c.look["legs"] = "pantalon"
	c.look["legs_color"] = "#3a3a44"
	c.look["hat"] = "casquette"
	c.look["hat_color"] = "#1b3c8c"
	c.look.erase("prop_r")
	c.look.erase("apron")
	c.scale = Vector3.ONE * PEOPLE_SCALE
	c.position = Vector3(9.0, 0, -P / 2.0 - 2.4)
	c.rotation.y = PI * 0.75
	add_child(c)
	_president = c
	_label3d("Le président Chauvin", c.position + Vector3(0, 2.3, 0), 22, Color(0.95, 0.85, 0.6), 180.0)
	_interactive(c, "president", "E : parler au président Chauvin", Vector3(1.2, 1.0, 1.2), Vector3(0, 0.4, 0))


## La causerie : les consignes de l'Étoile pour son prochain match, dans la même ardoise que le tableau du café.
func open_causerie() -> void:
	if _causerie != null:
		return
	var p: PanelContainer = CAUSERIE.new()
	p.club = _club_de_la_commune()
	p.closed.connect(func():
		p.queue_free()
		_causerie = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	p.mercato.connect(func():
		p.queue_free()
		_causerie = null
		open_mercato())
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_causerie = p


## Le mercato : les joueurs libres de la saison, et la recrue du club, dans la même ardoise.
func open_mercato() -> void:
	if _causerie != null:
		return
	var p: PanelContainer = MERCATO.new()
	p.club = _club_de_la_commune()
	p.closed.connect(func():
		p.queue_free()
		_causerie = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_causerie = p


## Le club de la commune d'origine (celui du terrain du registre), « smarves » ici.
func _club_de_la_commune() -> String:
	var origine: Commune = Communes.origine()
	for id in Football.clubs:
		if str(Football.clubs[id].get("commune", "")) == origine.id:
			return id
	return "smarves"


func _tableau_affichage() -> void:
	var z := P / 2.0 + 5.0
	var noir := _std(Color(0.08, 0.09, 0.1), 0.5)
	for x in [-3.2, 3.2]:
		_box(Vector3(0.2, 4.0, 0.2), Vector3(x, 2.0, z), _std(Color(0.4, 0.42, 0.45), 0.6, 0.4))
	_box(Vector3(7.4, 2.6, 0.3), Vector3(0, 4.3, z), noir)
	_box(Vector3(7.6, 0.2, 0.4), Vector3(0, 5.7, z), _std(Color(0.2, 0.3, 0.45), 0.6))
	_score = _label3d("0 - 0", Vector3(0, 4.7, z - 0.17), 160, Color(1.0, 0.85, 0.3), 180.0)
	_score.shaded = false
	_horloge = _label3d("", Vector3(0, 3.95, z - 0.17), 48, Color(0.95, 0.95, 0.9), 180.0)
	_horloge.shaded = false
	_affiche = _label3d("", Vector3(0, 3.45, z - 0.17), 34, Color(0.8, 0.85, 0.95), 180.0)
	_affiche.shaded = false
	_lamp(Vector3(0, 5.0, z - 1.5), Color(1.0, 0.9, 0.7), 1.0, 6.0)
	var feuille := Node3D.new()
	feuille.position = Vector3(0, 0, z - 1.0)
	add_child(feuille)
	_interactive(feuille, "feuille", "E : lire la feuille du dernier match", Vector3(7.0, 2.5, 2.0), Vector3(0, 1.2, 0))


# --- Le match -------------------------------------------------------------------------------------

## Le match du stade : celui de l'Étoile à la dernière journée dont le coup d'envoi est donné, sinon le
## premier match de la division suivie à la journée 1. Il ne se suit qu'en direct, à l'heure réelle du
## coup d'envoi (une minute de jeu par minute, un quart d'heure de mi-temps) ; avant, l'Étoile
## s'entraîne ; après, le tableau d'affichage garde le score et la feuille se lit au tableau.
func _choisir() -> Dictionary:
	if Football.niveaux.is_empty():
		Football.actualiser()
	var tableau: PanelContainer = FootTableau.new()
	var d: Array = tableau.division_suivie()
	tableau.free()
	var s: int = Football.saison
	var joues: int = Football.journee_jouee()
	var j: int = joues if joues > 0 else 1
	var matchs: Array = Football.journee(s, d[0], d[1], j, joues)
	var origine: Commune = Communes.origine()
	var choisi: Dictionary = matchs[0]
	for m in matchs:
		if origine and (m.dom == origine.id or m.ext == origine.id):
			choisi = m
	return {"s": s, "j": j, "dom": choisi.dom, "ext": choisi.ext, "joue": joues > 0, "coup_envoi": Football.coup_envoi(s, j)}


## Les vingt-deux sur la pelouse, le tableau, et le match remis à l'heure réelle : en cours, il reprend
## à la minute où l'on en est ; fini, le tableau garde le score et l'Étoile s'entraîne ; pas commencé,
## l'Étoile s'entraîne et le tableau annonce le coup d'envoi.
func _composer() -> void:
	var r := _rencontre
	var cd: Dictionary = Football.clubs[r.dom]
	var ce: Dictionary = Football.clubs[r.ext]
	var direct: Dictionary = Football.rencontre_en_direct(r.s, r.j, r.dom, r.ext)
	_etat = direct.etat
	_joueurs = direct.joueurs
	_hasard = direct.hasard
	_pas = 0
	for i in 2:
		var eq: Dictionary = _etat.equipes[i]
		var club: Dictionary = cd if i == 0 else ce
		for e in eq.onze:
			_acteur(e.id, i, club.couleurs)
	_score.text = "%s  0 - 0  %s" % [cd.court, ce.court]
	_score.font_size = 110
	if r.joue:
		_horloge.text = "Journée %d  ·  0'" % r.j
		_affiche.text = "%s – %s  ·  %s" % [cd.nom, ce.nom, FootTableau.date(r.coup_envoi)]
		_synchroniser(true)
		if _etat.fini:
			_terminer()
		elif not _etat.evenements.is_empty():
			_dire(_etat.evenements[-1].texte)
	else:
		_entrainer()
		_note("L'Étoile s'entraîne sous les projecteurs. %s" % _affiche.text)
	_placer(true)


## Remet le match à l'heure : une minute de jeu par minute réelle depuis le coup d'envoi, et un quart
## d'heure de mi-temps. Appelé à l'arrivée (d'un coup) puis à chaque image.
func _synchroniser(dun_coup := false) -> void:
	if _etat.is_empty():
		return
	var du: int = Football.maintenant() - int(_rencontre.coup_envoi)
	while not _etat.fini:
		var seuil: int = _pas * 60 + (MI_TEMPS if _etat.pause == "mi-temps" or _etat.periode == 2 else 0)
		if du < seuil:
			break
		_minute()
		_pas += 1
		if dun_coup:
			_scenes.clear()
			_vol = 0.0
			_vitesse_ballon = 14.0
			_placer(true)


## Le match est fini (à l'arrivée ou sous nos yeux) : le tableau garde le score, la feuille se lit au
## tableau d'affichage, et l'Étoile revient s'entraîner.
func _terminer() -> void:
	_resultat = _etat
	_score.text = "%s  %d - %d  %s" % [Football.clubs[_rencontre.dom].court, _etat.score[0], _etat.score[1], Football.clubs[_rencontre.ext].court]
	_horloge.text = "Journée %d  ·  terminé" % _rencontre.j
	_affiche.text = "%s – %s  ·  la feuille de match au tableau (E)" % [Football.clubs[_rencontre.dom].nom, Football.clubs[_rencontre.ext].nom]
	_entrainer()


## L'Étoile s'entraîne : plus de match sur la pelouse, le tableau annonce le prochain coup d'envoi.
func _entrainer() -> void:
	_etat = {}
	var pce: Array = Football.prochain_coup_envoi(Football.maintenant())
	var quand := "%s à %d h" % [FootTableau.date(pce[2]), Football.HEURE_COUP_ENVOI]
	if _resultat.is_empty():
		_horloge.text = "Entraînement"
		_affiche.text = "Journée %d : coup d'envoi %s" % [pce[1], quand]
	else:
		_affiche.text += "\nProchain coup d'envoi : %s" % quand


## La feuille du dernier match, sur l'ardoise du tableau du dimanche.
func open_feuille() -> void:
	if _causerie != null:
		return
	if _resultat.is_empty():
		_dire("« Pas de feuille à lire : le match n'est pas joué. Reviens dimanche à %d h. »" % Football.HEURE_COUP_ENVOI)
		return
	var p: PanelContainer = TABLEAU.new()
	p.closed.connect(func():
		p.queue_free()
		_causerie = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	p.ouvrir_feuille(_rencontre.s, _rencontre.j, _rencontre.dom, _rencontre.ext)
	_causerie = p


## Un joueur sur la pelouse, aux couleurs de son club, au banc d'abord.
func _acteur(id: String, equipe: int, couleurs: Array) -> Node3D:
	if _acteurs.has(id):
		return _acteurs[id]
	var j: Dictionary = _joueurs[id]
	var c := CRITTER.new()
	c.randomize_look(Hasard.graine(id))
	c.look["top"] = "pull"
	c.look["top_color"] = str(couleurs[0])
	c.look["legs"] = "pantalon"
	c.look["legs_color"] = str(couleurs[1]) if couleurs.size() > 1 else "#ffffff"
	c.look["shoes"] = "#1a1a1a"
	c.look.erase("hat")
	c.look.erase("prop_r")
	c.look.erase("apron")
	if j.poste == "G":
		c.look["top_color"] = "#2a8f3a" if str(couleurs[0]).to_lower() != "#0f6b3f" else "#d98f2a"
	c.scale = Vector3.ONE * PEOPLE_SCALE
	c.walk_speed = 1.0
	c.run_speed = 1.6
	c.position = Vector3((-7.0 if equipe == 0 else 7.0), 0, -P / 2.0 - 1.6)
	add_child(c)
	_acteurs[id] = c
	_cibles[id] = c.position
	return c


## Où chaque joueur doit être : sa case de formation, l'équipe glissant vers le ballon. L'équipe à domicile
## défend le but ouest (x < 0) et attaque vers l'est.
func _placer(dun_coup := false) -> void:
	var etat: Dictionary = _etat if not _etat.is_empty() else _entrainement()
	for i in 2:
		var eq: Dictionary = etat.equipes[i]
		var cases: Array = FootMatch.FORMATIONS.get(eq.formation, FootMatch.FORMATIONS["4-4-2"])
		var sens := 1.0 if i == 0 else -1.0
		var glisse := clampf(_cible_ballon.x * 0.35, -6.0, 6.0)
		var glisse_z := clampf(_cible_ballon.z * 0.25, -3.0, 3.0)
		var prises: Array = []
		for e in eq.onze:
			# Sa case : celle de son poste encore libre, sinon la première libre.
			var cs: Array = []
			for k in cases.size():
				if not (k in prises) and cases[k][0] == e.poste:
					cs = cases[k]
					prises.append(k)
					break
			if cs.is_empty():
				for k in cases.size():
					if not (k in prises):
						cs = cases[k]
						prises.append(k)
						break
			if cs.is_empty():
				cs = cases[-1]
			var along: float = (50.0 - cs[3]) / 50.0 * (L / 2.0 * 0.88)
			var across: float = (cs[2] - 50.0) / 50.0 * (P / 2.0 * 0.85)
			var cible := Vector3(sens * along, 0, sens * across)
			if e.poste != "G":
				cible.x += glisse
				cible.z += glisse_z
				cible.x = clampf(cible.x, -L / 2.0 + 0.5, L / 2.0 - 0.5)
				cible.z = clampf(cible.z, -P / 2.0 + 0.5, P / 2.0 - 0.5)
			else:
				# Le gardien se décale vers le ballon sur sa ligne.
				cible.z = clampf(_cible_ballon.z * 0.3, -2.5, 2.5)
			_cibles[e.id] = cible
			if dun_coup and _acteurs.has(e.id):
				_acteurs[e.id].position = cible
	if dun_coup:
		_ballon.position = Vector3(_cible_ballon.x, 0.22, _cible_ballon.z)


## Deux lignes qui trottinent autour du rond central, avant la saison.
func _entrainement() -> Dictionary:
	var faux := {"equipes": []}
	var direct: Dictionary = Football.rencontre_en_direct(_rencontre.s, _rencontre.j, _rencontre.dom, _rencontre.ext)
	for i in 2:
		faux.equipes.append({"onze": direct.etat.equipes[i].onze, "formation": direct.etat.equipes[i].formation})
	return faux


func _process(delta: float) -> void:
	_credits.text = "%s crédits" % Game.fmt(Game.credits)
	var t: Node = player.focus_target if player else null
	_prompt.visible = t != null
	if t != null:
		_prompt.text = str(t.get_meta("prompt", ""))
	# Le match suit l'heure réelle ; quand il finit, le tableau garde le score.
	if not _etat.is_empty() and not _etat.fini:
		_synchroniser()
		if _etat.fini:
			_terminer()
	if _etat.is_empty():
		# L'entraînement : le ballon se promène, les joueurs le suivent.
		_chrono += delta
		if _chrono > 2.5:
			_chrono = 0.0
			_cible_ballon = Vector3(randf_range(-L / 3.0, L / 3.0), 0, randf_range(-P / 3.0, P / 3.0))
			_placer()
	_animer(minf(delta, 0.1))


## Une image d'animation : la scène en cours, puis le ballon et les joueurs qui courent vers leur cible.
## Le pas est plafonné (un dixième de seconde) : une image lente ne téléporte personne.
func _animer(delta: float) -> void:
	_jouer_scenes(delta)
	var b := _ballon.position
	var vers := Vector3(_cible_ballon.x, 0.22, _cible_ballon.z)
	_ballon.position = b.move_toward(vers, delta * _vitesse_ballon)
	var reste := Vector2(_ballon.position.x - vers.x, _ballon.position.z - vers.z).length()
	if _vol > 0.0 and reste > 0.2:
		# Un ballon levé : une cloche entre son départ et sa cible.
		var total := maxf(Vector2(_depart_ballon.x - vers.x, _depart_ballon.z - vers.z).length(), 0.01)
		_ballon.position.y = 0.22 + _vol * sin(PI * clampf(1.0 - reste / total, 0.0, 1.0))
	else:
		_ballon.position.y = 0.22 + maxf(0.0, sin(Time.get_ticks_msec() / 90.0) * 0.08) * (1.0 if reste > 0.5 else 0.0)
	for id in _acteurs:
		var c: Node3D = _acteurs[id]
		var cible: Vector3 = _cibles.get(id, c.position)
		if c.position.distance_to(cible) > 0.15:
			var d := (cible - c.position)
			d.y = 0.0
			c.position = c.position.move_toward(cible, delta * COURSE)
			c.rotation.y = lerp_angle(c.rotation.y, atan2(d.x, d.z), 0.15)
		elif not _etat.is_empty():
			var vb := _ballon.position - c.position
			c.rotation.y = lerp_angle(c.rotation.y, atan2(vb.x, vb.z), 0.05)


## Une minute de match : les événements font bouger le ballon, parler le commentateur, tenir le tableau.
func _minute() -> void:
	var avant: Array = [_etat.stats[0].possession, _etat.stats[1].possession]
	var evenements: Array = FootMatch.avancer(_etat, _joueurs, _hasard)
	var qui: int = 0 if _etat.stats[0].possession > avant[0] else 1
	_horloge.text = "Journée %d  ·  %s" % [_rencontre.j, FootMatch.libelle_minute(_etat)]
	var sens := 1.0 if qui == 0 else -1.0
	# La minute précédente est finie, même si sa dernière scène ne l'était pas.
	_scenes.clear()
	# Sans événement, le ballon circule dans le camp de celui qui l'a : deux passes, puis on temporise.
	if evenements.is_empty() or evenements.all(func(e): return e.type in ["ambiance", "info"]):
		var eq: Dictionary = _etat.equipes[qui]
		for k in 2:
			var e = eq.onze[randi() % eq.onze.size()] if not eq.onze.is_empty() else null
			_scene(Vector3(sens * randf_range(-4.0, 10.0), 0, randf_range(-P / 2.0 + 3.0, P / 2.0 - 3.0)), 3.0, e.id if e != null else null, 12.0)
	for ev in evenements:
		_evenement(ev)
	_placer()
	if _etat.pause == "mi-temps":
		_scenes.clear()
		_placer(true)


## Une scène de plus : le ballon va là, à cette vitesse, levé ou non, et ce joueur le rejoint.
func _scene(ballon: Vector3, duree: float, porteur = null, vitesse := 14.0, vol := 0.0, action := Callable()) -> void:
	_scenes.append({"ballon": ballon, "duree": duree, "porteur": porteur, "vitesse": vitesse, "vol": vol, "action": action, "lancee": false})


## Joue la scène en cours : au départ, le ballon reçoit sa cible et le porteur court la rejoindre ; au bout
## de sa durée, la suivante.
func _jouer_scenes(delta: float) -> void:
	if _scenes.is_empty():
		return
	var sc: Dictionary = _scenes[0]
	if not sc.lancee:
		sc.lancee = true
		_scene_t = 0.0
		_depart_ballon = _ballon.position
		_cible_ballon = sc.ballon
		_vitesse_ballon = sc.vitesse
		_vol = sc.vol
		_placer()
		if sc.porteur != null and _acteurs.has(sc.porteur):
			# Le porteur se poste un pas derrière le ballon, du côté de son but.
			var recul := -1.0 if _cibles.get(sc.porteur, Vector3.ZERO).x < sc.ballon.x else 1.0
			_cibles[sc.porteur] = sc.ballon + Vector3(recul * 0.6, 0, 0)
		if sc.action.is_valid():
			sc.action.call()
	_scene_t += delta
	if _scene_t >= sc.duree:
		_scenes.pop_front()
		# La suivante part tout de suite, sans image perdue.
		_jouer_scenes(0.0)


func _evenement(ev: Dictionary) -> void:
	var i: int = int(ev.equipe)
	var sens := 1.0 if i == 0 else -1.0
	# Le couloir de l'action : pour qui attaque vers l'est, la gauche est au nord (z < 0) ; l'inverse à l'ouest.
	var cote: float = _cote(str(ev.get("couloir", "centre"))) * sens
	var tireur = ev.get("joueur", null)
	var but := Vector3(sens * (L / 2.0), 0, 0)
	match str(ev.type):
		"occasion":
			match str(ev.get("phase", "jeu")):
				"corner":
					# Le tireur va au poteau de corner, lève le ballon, la tête le reprend aux six mètres.
					var coin := Vector3(sens * (L / 2.0 - 0.3), 0, (P / 2.0 - 0.3) * (cote if cote != 0.0 else 1.0))
					_scene(coin, 2.2, ev.get("tireur", null), 16.0)
					_scene(Vector3(sens * (L / 2.0 - 2.2), 0, randf_range(-2.5, 2.5)), 1.0, tireur, 18.0, 2.2)
				"coupFranc":
					# Le ballon posé à vingt mètres, le tireur prend son élan.
					_scene(Vector3(sens * (L / 2.0 - 8.0), 0, cote * 4.0 + randf_range(-1.0, 1.0)), 2.6, tireur, 16.0)
				"penalty":
					_scene(Vector3(sens * (L / 2.0 - 3.8), 0, 0), 2.6, tireur, 16.0)
				_:
					var passeur = ev.get("passeur", null)
					if ev.get("centre", false) and cote != 0.0:
						# L'ailier déborde jusqu'à la ligne et centre ; le buteur attend au point de penalty.
						_scene(Vector3(sens * (L / 2.0 - 10.0), 0, cote * 7.0), 1.6, passeur, 16.0)
						_scene(Vector3(sens * (L / 2.0 - 2.5), 0, cote * 8.5), 1.6, passeur, 16.0)
						_scene(Vector3(sens * (L / 2.0 - 4.0), 0, randf_range(-1.5, 1.5)), 0.9, tireur, 22.0, 1.4)
					else:
						# La construction dans le couloir, puis la passe au tireur à l'entrée de la surface.
						_scene(Vector3(sens * (L / 2.0 - 13.0), 0, cote * 6.0 + randf_range(-1.5, 1.5)), 1.8, passeur if passeur != null else tireur, 16.0)
						_scene(Vector3(sens * (L / 2.0 - 5.5), 0, cote * 5.0 + randf_range(-2.0, 2.0)), 1.2, tireur, 20.0)
		"but":
			_scene(but + Vector3(sens * 0.7, 0, randf_range(-1.2, 1.2)), 1.2, null, 32.0, 0.5)
			_scene(Vector3.ZERO, 4.0, null, 10.0, 0.0, _marquer.bind(i, ev))
		"arret":
			var g = _gardien(1 - i)
			_scene(but + Vector3(-sens * 0.5, 0, randf_range(-1.0, 1.0)), 0.9, g, 32.0, 0.4, _geste.bind(g, "jump"))
			_scene(Vector3(sens * (L / 2.0 - 9.0), 0, randf_range(-6.0, 6.0)), 2.0, null, 18.0, 1.8)
		"rate":
			_scene(but + Vector3(sens * 2.5, 0, (3.0 + randf() * 2.0) * (1.0 if randf() < 0.5 else -1.0)), 1.2, null, 30.0, 1.6, _geste.bind(tireur, "shrug"))
			_scene(but + Vector3(-sens * 2.0, 0, randf_range(-2.0, 2.0)), 2.2, _gardien(1 - i), 10.0)
		"poteau":
			var z := 1.7 * (1.0 if randf() < 0.5 else -1.0)
			_scene(but + Vector3(0, 0, z), 0.7, null, 32.0, 0.3, _geste.bind(tireur, "stomp"))
			_scene(but + Vector3(-sens * 4.0, 0, z * 1.5), 1.2, null, 18.0)
		"jaune", "rouge":
			if ev.type == "rouge" and _acteurs.has(tireur):
				_cibles[tireur] = Vector3(sens * 7.0, 0, -P / 2.0 - 1.6)
			_geste(tireur, "shrug" if ev.type == "jaune" else "sulk")
		"blessure":
			_geste(tireur, "sulk")
		"remplacement":
			var club: Dictionary = Football.clubs[_rencontre.dom if i == 0 else _rencontre.ext]
			_acteur(ev.entrant, i, club.couleurs)
			_cibles[ev.sortant] = Vector3((-7.0 if i == 0 else 7.0) + randf_range(-1.5, 1.5), 0, -P / 2.0 - 1.6)
		"reprise", "coupEnvoi":
			_scene(Vector3.ZERO, 1.5, null, 14.0)
	if ev.type != "info" or _etat.minute in [45, 90]:
		_dire(str(ev.texte))


## Le gardien d'une équipe sur la pelouse (son id), s'il y en a un.
func _gardien(i: int) -> Variant:
	for e in _etat.equipes[i].onze:
		if e.poste == "G":
			return e.id
	return null


## Un geste d'un joueur, s'il est sur la pelouse.
func _geste(id, nom: String) -> void:
	if id != null and _acteurs.has(id):
		_acteurs[id].gesture(nom)


## Le côté d'un couloir pour une équipe qui attaque vers l'est : -1 à gauche (nord), +1 à droite, 0 au centre.
static func _cote(couloir: String) -> float:
	return -1.0 if couloir == "gauche" else (1.0 if couloir == "droite" else 0.0)


## Le but : le tableau change, le buteur lève les bras, la tribune se lève.
func _marquer(i: int, ev: Dictionary) -> void:
	var cd: Dictionary = Football.clubs[_rencontre.dom]
	var ce: Dictionary = Football.clubs[_rencontre.ext]
	_score.text = "%s  %d - %d  %s" % [cd.court, _etat.score[0], _etat.score[1], ce.court]
	if _acteurs.has(ev.get("joueur", "")):
		_acteurs[ev.joueur].cheer(2.0)
	var origine: Commune = Communes.origine()
	var chez_nous: bool = origine != null and (_rencontre.dom if i == 0 else _rencontre.ext) == origine.id
	for s in _supporters:
		if chez_nous:
			s.cheer(2.4)
		elif randf() < 0.2:
			s.gesture("facepalm")
	Sfx.result(1, 50 if chez_nous else 0)


func _dire(texte: String) -> void:
	_speech.text = texte
	_show_speech()


func _note(texte: String) -> void:
	_dire(texte)


func _show_speech() -> void:
	_speech.modulate.a = 1.0
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = create_tween()
	_speech_tween.tween_interval(3.0 + _speech.text.length() * 0.03)
	_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.8)


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			Game.return_point = "stade"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		"president":
			open_causerie()
		"feuille":
			open_feuille()
		"buvette":
			_dire(["« Un café, un. C'est la femme du président qui tient la buvette, et elle ne fait pas crédit. »",
				"« Le chocolat chaud, c'est pour les moins de douze ans et les gardiens de but. »",
				"« Le président Chauvin dit que l'Étoile montera. Il le dit depuis 1987. »"].pick_random())


# --- Capture --------------------------------------------------------------------------------------

## --rejouer=but (ou arret, rate, poteau, corner, coupFranc, penalty) rejoue en scènes, pour la capture, la
## dernière minute déjà jouée où c'est arrivé ; --attendre=s prend la capture au bout de s secondes (6 sans).
func _maybe_capture() -> void:
	var path := ""
	var attente := 6.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
			if v.size() > 3:
				player.camera.rotation.x = deg_to_rad(v[3])
		elif arg.begins_with("--minute=") or arg.begins_with("--journee=") or arg == "--mercato":
			pass
		elif arg.begins_with("--actionnaires="):
			# Des parts du club pour la capture : --actionnaires=vous:2,Lucien:1 (avant --open=causerie).
			var club := _club_de_la_commune()
			var autres: Array = []
			for morceau in arg.trim_prefix("--actionnaires=").split(","):
				var kv := morceau.split(":")
				if kv[0] == "vous":
					Football.parts_locales[club] = int(kv[1])
				else:
					autres.append({"par": kv[0], "nombre": int(kv[1]), "moi": false})
			Football.parts[club] = autres
		elif arg == "--open=causerie":
			open_causerie()
		elif arg == "--open=mercato":
			open_mercato()
		elif arg.begins_with("--rejouer="):
			_rejouer(arg.trim_prefix("--rejouer="))
		elif arg.begins_with("--attendre="):
			attente = float(arg.trim_prefix("--attendre="))
		else:
			_capture_setup(arg)
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_chrono = -100.0
	await get_tree().create_timer(attente).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## Rejoue en scènes la dernière minute où un événement de ce type (ou une occasion de cette phase) est
## arrivé : rien ne change au match, seule la pelouse le remontre. « but@3.4 » avance aussitôt les scènes
## de 3,4 secondes, pour qu'une capture les prenne en plein vol quel que soit le rythme des images.
func _rejouer(quoi: String) -> void:
	if _etat.is_empty() and _resultat.is_empty():
		return
	var avance := 0.0
	if "@" in quoi:
		avance = float(quoi.get_slice("@", 1))
		quoi = quoi.get_slice("@", 0)
	var etat: Dictionary = _etat if not _etat.is_empty() else _resultat
	var minute := ""
	for k in range(etat.evenements.size() - 1, -1, -1):
		var ev: Dictionary = etat.evenements[k]
		if ev.type == quoi or (ev.type == "occasion" and ev.get("phase", "") == quoi):
			minute = ev.minute
			break
	if minute == "":
		return
	_scenes.clear()
	for ev in etat.evenements:
		if ev.minute == minute:
			_evenement(ev)
	for k in int(avance * 30.0):
		_animer(1.0 / 30.0)


## L'horloge du football, posée avant que la scène ne choisisse son match : --journee=n met l'horloge à
## la minute --minute=m (0 sans elle) de la journée n, mi-temps comprise.
func _init() -> void:
	var journee := 0
	var minute := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			Football.dossier = ""
		elif arg.begins_with("--journee="):
			journee = int(arg.trim_prefix("--journee="))
		elif arg.begins_with("--minute="):
			minute = int(arg.trim_prefix("--minute="))
		elif arg == "--mercato":
			# Le milieu de la semaine du mercato de la saison 1.
			journee = -1
	if journee > 0:
		var t: int = Football.coup_envoi(1, journee) + minute * 60 + (MI_TEMPS if minute > 45 else 0)
		Football.regler_horloge(func(): return t)
	elif journee < 0:
		var tm: int = Football.coup_envoi(1, 1) - 3 * 86400
		Football.regler_horloge(func(): return tm)
