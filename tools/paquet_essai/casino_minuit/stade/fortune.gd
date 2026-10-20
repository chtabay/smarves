extends "res://scripts/village/stade.gd"
## Le stade de la Fortune, où joue le Racing Club Minuit (socle 1.8, champ « scene » du terrain) : la pelouse
## et le match du socle, dans un stade bâti par Casino Minuit. Un bol à l'américaine sous une roue de roulette
## géante qui tourne (roue.gd), deux étages de tribunes, la promenade, les Suites impériales, la piscine des
## parieurs, le Jackpot Lounge et sa scène, le penthouse du président (batiment.gd, sur le plan de bol.gd) ; au
## sud le parvis, ses fontaines, Jackpot le chat en smoking et la station de taxis (parvis.gd). On y arrive en
## taxi, on en repart en taxi : vers le casino ou l'aéroport (taxi.gd).
## Capture : outils/capture_stade_minuit.gd, ou les options du stade du socle (--at=x,z,lacet,tangage), plus
## --y=hauteur pour poser le visiteur à un étage.

const BASE := "res://communes/casino_minuit/"
const KIT := BASE + "kit.gd"
const PERSONNAGES := BASE + "personnages.gd"
const BATIMENT := BASE + "stade/batiment.gd"
const ROUE := BASE + "stade/roue.gd"
const PARVIS := BASE + "stade/parvis.gd"
const TAXI := BASE + "stade/taxi.gd"
const SEMAINE := BASE + "stade/semaine.gd"
const LOT_E := BASE + "zones/lot_e.gd"
## La roue tourne d'un tour en deux minutes.
const VITESSE_ROUE := TAU / 120.0

var K
var _t := 0.0
var _roue := {}
var _parvis := {}
var places := {}
## La vie de la semaine (semaine.gd) : le moment, les foules (assise aux tribunes, debout au parvis et au hall)
## et les projecteurs de la pelouse, qu'on baisse quand le stade est désert.
var moment := ""
var _foules: Array[MultiMeshInstance3D] = []
var _projecteurs: Array[SpotLight3D] = []
var _revu := 0.0


func _ready() -> void:
	K = load(KIT).new(self)
	super()
	var at := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			at = true
	if not at:
		player.position = load(PARVIS).ARRIVEE
		player.rotation.y = PI
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--y="):
			player.position.y = float(arg.trim_prefix("--y="))
	load(SEMAINE).inscrire()
	_vivre()
	_annoncer()


## Ce que le visiteur entend en arrivant, selon le moment : le stade du socle parle d'entraînement à toute
## heure ; ici, il dort la semaine.
func _annoncer() -> void:
	var nom := _nom_club()
	match moment:
		"desert":
			_note("Le stade de la Fortune dort : rendez-vous mercredi à 18 h pour l'entraînement public, ou dimanche dès 13 h.")
		"entrainement":
			_note("Entraînement public de %s jusqu'à 20 h : les tribunes sont ouvertes, prenez place." % nom)
		"portes":
			_note("Les portes sont ouvertes, la foule arrive : coup d'envoi à %d h." % Football.HEURE_COUP_ENVOI if _a_domicile()
				else "Les portes sont ouvertes : %s joue à l'extérieur, le match passe sur l'écran géant à %d h." % [nom, Football.HEURE_COUP_ENVOI])
		"match":
			if not _a_domicile():
				_note("%s joue à l'extérieur : tout le stade regarde le match sur l'écran géant." % nom)
		"sortie":
			_note("Le match est fini, la foule redescend vers le Strip. Les taxis attendent sur le parvis.")


func _place_name() -> String:
	return "Le stade de la Fortune"


## La nuit du Strip : le ciel violet sombre, la lueur des diodes, et quatre projecteurs pendus au bord de la
## roue, qui font le jour sur la pelouse.
func _nuit() -> void:
	var we: WorldEnvironment = null
	for c in get_children():
		if c is WorldEnvironment:
			we = c
	if we:
		var e := we.environment
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.035, 0.02, 0.07)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.5, 0.42, 0.6)
		e.ambient_light_energy = 0.45
		e.sdfgi_enabled = false
		e.ssil_enabled = false
		e.ssao_enabled = false
		e.fog_enabled = true
		e.fog_light_color = Color(0.12, 0.06, 0.14)
		e.fog_density = 0.0025
		e.glow_enabled = true
		e.glow_intensity = 0.7
		e.glow_bloom = 0.08
		e.glow_hdr_threshold = 1.1
	var lune := DirectionalLight3D.new()
	lune.light_color = Color(0.7, 0.62, 0.9)
	lune.light_energy = 0.2
	lune.rotation_degrees = Vector3(-50, 25, 0)
	add_child(lune)
	var r: float = load(ROUE).R_CASES + 1.0
	for a in [PI / 4.0, 3.0 * PI / 4.0, 5.0 * PI / 4.0, 7.0 * PI / 4.0]:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.97, 0.9)
		spot.light_energy = 7.0
		spot.spot_range = 60.0
		spot.spot_angle = 42.0
		spot.shadow_enabled = a < PI / 2.0
		add_child(spot)
		_projecteurs.append(spot)
		spot.position = Vector3(sin(a) * r, 20.0, cos(a) * r)
		spot.look_at(Vector3(sin(a) * 6.0, 0, cos(a) * 4.0), Vector3.UP)


## Tout le stade de la commune, à la place de la tribune du socle.
func _tribune() -> void:
	places = load(BATIMENT).construire(K, self)
	_roue = load(ROUE).construire(K)
	_parvis = load(PARVIS).construire(K)
	_figurants()
	_foule()


## Les foules du dimanche, posées une fois pour toutes et montrées par parts (visible_instance_count) : les
## places des deux étages mêlées au hasard, pour que le stade se remplisse partout à la fois ; debout, la file
## du parvis et les gens du hall.
func _foule() -> void:
	var E = load(LOT_E)
	var h := RandomNumberGenerator.new()
	h.seed = 1203
	var assis := []
	for p in places.bas + places.haut:
		var v: Vector3 = p[0]
		assis.append([v.x, v.y, v.z, float(p[1]) + PI])
	_melanger(assis, h)
	var debout := []
	for i in 360:
		var x := h.randf_range(-34.0, 34.0)
		var z := h.randf_range(-91.0, -37.0)
		# Ni sur le tapis, ni dans les bassins, ni sur Jackpot.
		if absf(x) < 3.4 or (absf(x) > 7.6 and absf(x) < 30.4 and z > -62.4 and z < -41.6) or Vector2(x, z + 70.0).length() < 7.4:
			continue
		debout.append([x, 0.0, z, h.randf() * TAU])
	# La file, le long des cordons du tapis, tournée vers la porte de verre.
	for i in 320:
		var x := h.randf_range(3.7, 7.3) * (1.0 if i % 2 == 0 else -1.0)
		var z := h.randf_range(-90.0, -38.0)
		if Vector2(x, z + 70.0).length() < 7.4:
			continue
		debout.append([x, 0.0, z, PI + h.randf_range(-0.5, 0.5)])
	for i in 90:
		debout.append([h.randf_range(-15.0, 15.0), 0.0, h.randf_range(-34.8, -23.5), h.randf() * TAU])
	_melanger(debout, h)
	K.zone_debut("FORTUNE-FOULE")
	_foules = [E.foule(K, assis, "assis", 1203, "foule_tribunes"), E.foule(K, debout, "debout", 1204, "foule_parvis")]
	K.zone_fin()


static func _melanger(a: Array, h: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := h.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Le stade au moment de la semaine : les foules à leur part, la pelouse vide hors de l'entraînement et du
## match à domicile (à l'extérieur, le match passe sur l'écran à 360°), les projecteurs baissés quand il est désert.
func _vivre() -> void:
	var S = load(SEMAINE)
	var t: int = Football.maintenant()
	moment = S.moment(t)
	var part: float = S.remplissage(t)
	if _foules.size() == 2:
		var a: MultiMesh = _foules[0].multimesh
		a.visible_instance_count = int(a.instance_count * part)
		var d: MultiMesh = _foules[1].multimesh
		var debout := part if moment == "portes" or moment == "sortie" else (0.15 if moment == "match" else 0.0)
		d.visible_instance_count = int(d.instance_count * debout)
	var sur_la_pelouse := moment == "entrainement" or ((moment == "portes" or moment == "match") and _a_domicile())
	for id in _acteurs:
		(_acteurs[id] as Node3D).visible = sur_la_pelouse
	if _ballon:
		_ballon.visible = sur_la_pelouse
	for sp in _projecteurs:
		sp.light_energy = 7.0 if moment != "desert" else 2.2


## Le Racing Club Minuit reçoit-il ce dimanche ? Sinon (ou sans club au championnat), le match est ailleurs.
func _a_domicile() -> bool:
	return _club != "" and str(_rencontre.get("dom", "")) == _club


## L'entrée du stade du socle (portail, panneau du club) : ici, on entre par le parvis et le hall, où le
## panneau du club tient en diodes sur le mur nord, à côté de la feuille du dernier match.
func _entree() -> void:
	K.zone_debut("FORTUNE-PANNEAU")
	var x := -14.3
	var z := -22.4 - 0.36
	K.box("laque_noire", 3.0, 2.4, 0.12, x, 1.9, z)
	K.box("or", 3.2, 0.1, 0.16, x, 3.15, z)
	K.box("or", 3.2, 0.1, 0.16, x, 0.65, z)
	load(BASE + "zones/lot_e.gd").ecran(K, x, 1.75, z - 0.07, 2.6, 1.5, PI, 4, 0.5)
	K.texte("LE PANNEAU DU CLUB", 2.8, 0.24, x, 2.85, z - 0.08, PI, "grave")
	K.interaction("panneau", "E : lire le panneau du club", x, 1.6, z - 1.0, Vector3(3.0, 2.4, 1.2))
	K.zone_fin()


## Le siège du club, au socle une pièce à part : ici, c'est le bureau du penthouse (_le_president).
func _siege() -> void:
	pass


## Le score, l'horloge et l'affiche du match : sur la face sud de l'écran à 360°, recopiés sur les trois autres.
func _tableau_affichage() -> void:
	var m: Array = _roue.ecran
	_score = m[0][0]
	_horloge = m[0][1]
	_affiche = m[0][2]
	_score.text = "0 - 0"


## M. Castellane, le président, dans son penthouse suspendu sous la roue, derrière son bureau : on monte le voir
## par l'ascenseur de verre de la promenade.
func _le_president() -> void:
	var P = load(PERSONNAGES)
	var c: Node3D = P.faire("dealer-businessman", {"Suit": "#0E0C10", "Tie": "#B3121F", "White": "#F3EAD7"})
	c.position = Vector3(-1.5, 16.5, -24.1)
	add_child(c)
	c.regarder(Vector3(-1.5, 16.5, 0))
	c.jouer("idle")
	_president = c
	var l := _label3d(_nom_president(), c.position + Vector3(0, 2.2, 0.3), 22, Color(0.95, 0.85, 0.6), 180.0)
	l.shaded = false
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_interactive(c, "president", "E : parler %s" % _a(_nom_president()), Vector3(1.6, 1.8, 1.2), Vector3(0, 0.9, 1.6))
	# Le bureau d'acajou, devant lui : la gestion du club, comme au siège du stade du socle.
	var bureau := Node3D.new()
	bureau.position = Vector3(0.3, 16.5, -23.0)
	add_child(bureau)
	_interactive(bureau, "bureau", "E : le bureau du président, la gestion du club", Vector3(1.0, 1.6, 1.6), Vector3(0, 0.8, 0))


## Le voiturier de la station, et le barman de la piscine : les seuls qui restent quand le stade est désert.
func _figurants() -> void:
	var P = load(PERSONNAGES)
	var v: Node3D = P.figurant("voiturier", 3)
	v.position = Vector3(-1.8, 0, -88.8)
	add_child(v)
	v.regarder(Vector3(0, 0, -80))
	v.jouer("idle")
	var b: Node3D = P.figurant("barman", 7)
	b.position = Vector3(41.0, 4.5, 0.0)
	add_child(b)
	b.regarder(Vector3(0, 4.5, 0))
	b.jouer("idle")


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	K.animer(delta, _t)
	if _roue.has("cases"):
		(_roue.cases as Node3D).rotation.y = _t * VITESSE_ROUE
		(_roue.bille as Node3D).position = load(ROUE).place_bille(_t)
		var m: Array = _roue.ecran
		for i in range(1, m.size()):
			for k in 3:
				m[i][k].text = m[0][k].text
	_revu += delta
	if _revu > 1.0:
		_revu = 0.0
		_vivre()
	for o in _parvis.get("yeux", []):
		var mat: StandardMaterial3D = o.material_override
		mat.emission_energy_multiplier = 2.4 + 1.2 * sin(_t * 1.3)


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"taxi":
			load(TAXI).ouvrir(self, player, "Où va-t-on ?", [
				["Retour au Casino Minuit", "Le Strip, la porte-cochère du casino", _retour_casino],
				["L'aéroport McCarran", "Le vol MN 1203, pour Poitiers-Biard", func(): Carte.ouvrir()]])
		"monter":
			player.global_position = target.get_meta("vers")
			player.velocity = Vector3.ZERO
			player.rotation.y = float(target.get_meta("cap", player.rotation.y))
		"billetterie":
			_dire(_billetterie())
		"boutique":
			_dire(["« Le maillot du dimanche, rouge et or, brodé main : 1 203 dollars. Le prix du vol, monsieur. »",
				"« L'écharpe en soie du Racing Club Minuit. Elle porte bonheur aux tables, paraît-il. »",
				"« Jackpot en peluche, chapeau compris. Les enfants l'adorent, les joueurs aussi. »"].pick_random())
		"tunnel":
			_dire("Les joueurs entrent par là le dimanche, sous les flammes et les feux d'artifice. La porte est fermée la semaine.")
		"piscine":
			_dire(["« Un Fortune Spritz ? Les cabanas se louent à la journée de match, avec vue sur la pelouse. »",
				"« La piscine est à l'année. Le dimanche, on parie depuis l'eau. »"].pick_random())
		"machines":
			_dire("Les machines du Jackpot Lounge tournent pour le décor : on joue aux tables du casino, sur le Strip.")
		"scene":
			_dire("La scène de Minuit Live : le dimanche, un concert avant le coup d'envoi et à la mi-temps.")
		_:
			super(target)


## Le taxi du retour : on repart à la porte-cochère du casino (minuit.gd lit le point de retour).
func _retour_casino() -> void:
	Game.return_point = _lot()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var c: Commune = Communes.commune(commune)
	Chargement.changer(str(c.data.scene) if c else "res://scenes/main.tscn")


## Le guichet : le prochain coup d'envoi, à l'heure du jeu.
func _billetterie() -> String:
	var t: int = Football.maintenant()
	var pc: Array = Football.prochain_coup_envoi(t)
	var d := Time.get_datetime_dict_from_unix_time(int(pc[2]))
	var jours := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
	return "« Prochain match le %s %d à %d h, portes à 13 h. Le Racing Club Minuit compte sur vous. »" % [jours[d.weekday], d.day, d.hour]
