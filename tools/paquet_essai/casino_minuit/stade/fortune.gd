extends Node3D
## Le stade de la Fortune, où joue le Racing Club Minuit : le décor du stade, branché par ses ancres (socle 1.13,
## champ « modele » du terrain ; décor vivant, socle 1.18). Le socle y pose la pelouse, le match, le président et
## sa gestion, le panneau et le tableau ; le décor bâtit le reste et le fait vivre. Un bol à l'américaine sous une
## roue de roulette géante qui tourne (roue.gd), deux étages de tribunes, la promenade, les Suites impériales, la
## piscine des parieurs, le Jackpot Lounge et sa scène, le penthouse du président (batiment.gd, sur le plan de
## bol.gd) ; au sud le parvis, ses fontaines, Jackpot le chat en smoking et la station de taxis (parvis.gd). On y
## arrive en taxi, on en repart en taxi : vers le casino ou l'aéroport (taxi.gd).
## Les ancres (scripts/socle/ancres.gd) : Pelouse au rond central, Arrivee sous l'auvent de la station, Sortie à
## la station de taxis, Tableau sur la face sud de l'écran à 360°, President et Bureau au penthouse, Panneau
## sous le palier de l'escalier du hall.
## Capture : outils/capture_stade_minuit.gd, ou les options du stade du socle (--at=x,z,lacet,tangage), plus
## --y=hauteur pour poser le visiteur à un étage.

const BASE := "res://communes/casino_minuit/"
const KIT := BASE + "kit.gd"
const BATIMENT := BASE + "stade/batiment.gd"
const ROUE := BASE + "stade/roue.gd"
const PARVIS := BASE + "stade/parvis.gd"
const TAXI := BASE + "stade/taxi.gd"
const SEMAINE := BASE + "stade/semaine.gd"
const LOT_E := BASE + "zones/lot_e.gd"
## La roue tourne d'un tour en deux minutes.
const VITESSE_ROUE := TAU / 120.0
## Le panneau du club, sous le palier, à gauche du tunnel des joueurs ; le penthouse du président.
const PANNEAU := Vector3(3.2, 0, -22.83)
const PRESIDENT := Vector3(-1.5, 16.5, -24.1)
const BUREAU := Vector3(0.3, 16.5, -23.0)

var K
## Le stade du socle, une fois qu'il a tout posé (brancher).
var stade: Node3D
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
	places = load(BATIMENT).construire(K, self)
	_roue = load(ROUE).construire(K)
	_parvis = load(PARVIS).construire(K)
	_panneau()
	_figurants()
	_foule()
	_ancres()
	# Mesuré ou vu seul, le décor suit déjà la semaine : brancher() le reprend avec le stade.
	_vivre()


## Les ancres du contrat du stade.
func _ancres() -> void:
	var e: Array = _roue.ecran[0]
	_ancre("Pelouse", Vector3.ZERO, 0.0)
	_ancre("Arrivee", load(PARVIS).ARRIVEE, 0.0)
	_ancre("Sortie", Vector3(0, 0, load(PARVIS).Z_TAXI - 3.0), PI)
	_ancre("Tableau", (e[0] as Label3D).position, PI)
	_ancre("President", PRESIDENT, 0.0)
	_ancre("Bureau", BUREAU, 0.0)
	_ancre("Panneau", PANNEAU, PI)


func _ancre(nom: String, p: Vector3, lacet: float) -> void:
	var m := Marker3D.new()
	m.name = nom
	m.position = p
	m.rotation.y = lacet
	add_child(m)


## La nuit du Strip (socle 1.18, à la place de celle du socle) : le ciel violet sombre, la lueur des diodes, et
## quatre projecteurs pendus au bord de la roue, qui font le jour sur la pelouse.
func nuit(s: Node3D) -> void:
	var we: WorldEnvironment = null
	for c in s.get_children():
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


## Le stade est posé (socle 1.18) : M. Castellane dans son costume, l'écran à 360° qui reprend le score du
## socle, la sortie qui devient la station de taxis, la semaine du stade et ce qu'on entend en arrivant.
func brancher(s: Node3D) -> void:
	stade = s
	_le_president()
	# Le score, la minute et l'affiche du socle (au Tableau) sont recopiés sur les quatre faces de l'écran.
	for l in [s._score, s._horloge, s._affiche]:
		if l:
			l.visible = false
	for a in s.find_children("*", "Area3D", true, false):
		if str(a.get_meta("interact", "")) == "exit":
			a.set_meta("prompt", "E : prendre un taxi")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--y="):
			_hauteur.call_deferred(float(arg.trim_prefix("--y=")))
	load(SEMAINE).inscrire()
	_vivre()
	_annoncer()


func _hauteur(y: float) -> void:
	stade.player.position.y = y


## M. Castellane, le président, dans son penthouse suspendu sous la roue, derrière son bureau : le socle l'a posé
## à l'ancre President ; il garde son costume noir et sa cravate aux couleurs du club.
func _le_president() -> void:
	var ancien: Node3D = stade._president
	if ancien == null:
		return
	var P = Atelier.personnages()
	var c: Node3D = P.faire("dealer-businessman", {"Suit": "#0E0C10", "Tie": "#B3121F", "White": "#F3EAD7"})
	stade.add_child(c)
	c.global_position = ancien.global_position
	c.regarder(c.global_position + Vector3(0, 0, 1))
	c.jouer("idle")
	stade._president = c
	stade._interactive(c, "president", "E : parler %s" % stade._a(stade._nom_president()), Vector3(1.6, 1.8, 1.2), Vector3(0, 0.9, 1.6))
	ancien.queue_free()


## Ce que le visiteur entend en arrivant, selon le moment : le stade du socle parle d'entraînement à toute
## heure ; ici, il dort la semaine.
func _annoncer() -> void:
	var nom: String = stade._nom_club()
	match moment:
		"desert":
			stade._note("Le stade de la Fortune dort : rendez-vous mercredi à 18 h pour l'entraînement public, ou dimanche dès 13 h.")
		"entrainement":
			stade._note("Entraînement public de %s jusqu'à 20 h : les tribunes sont ouvertes, prenez place." % nom)
		"portes":
			stade._note("Les portes sont ouvertes, la foule arrive : coup d'envoi à %d h." % Football.HEURE_COUP_ENVOI if _a_domicile()
				else "Les portes sont ouvertes : %s joue à l'extérieur, le match passe sur l'écran géant à %d h." % [nom, Football.HEURE_COUP_ENVOI])
		"match":
			if not _a_domicile():
				stade._note("%s joue à l'extérieur : tout le stade regarde le match sur l'écran géant." % nom)
		"sortie":
			stade._note("Le match est fini, la foule redescend vers le Strip. Les taxis attendent sur le parvis.")


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
	# L'atrium du hall (ni l'accueil ni le plan du stade), et le balcon du palier, au-dessus.
	for i in 90:
		var x := h.randf_range(-9.5, 9.5)
		var z := h.randf_range(-35.0, -29.6)
		if z < -31.4 and absf(absf(x) - 6.8) < 1.7:
			continue
		debout.append([x, 0.0, z, h.randf() * TAU])
	for i in 24:
		debout.append([h.randf_range(-3.6, 3.6), 4.5, h.randf_range(-28.7, -26.4), h.randf_range(-0.8, 0.8)])
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
	if stade == null:
		return
	var sur_la_pelouse := moment == "entrainement" or ((moment == "portes" or moment == "match") and _a_domicile())
	for id in stade._acteurs:
		(stade._acteurs[id] as Node3D).visible = sur_la_pelouse
	if stade._ballon:
		stade._ballon.visible = sur_la_pelouse
	for sp in _projecteurs:
		sp.light_energy = 7.0 if moment != "desert" else 2.2


## Le Racing Club Minuit reçoit-il ce dimanche ? Sinon (ou sans club au championnat), le match est ailleurs.
func _a_domicile() -> bool:
	return stade != null and stade._club != "" and str(stade._rencontre.get("dom", "")) == stade._club


## Le panneau du club, en diodes sous le palier de l'escalier, à gauche du tunnel des joueurs, dans l'axe de la
## porte : le cadre et l'écran ; le socle y écrit le club et y pose la lecture (ancre Panneau).
func _panneau() -> void:
	K.zone_debut("FORTUNE-PANNEAU")
	var x := PANNEAU.x
	var z := -22.4 - 0.36
	K.box("laque_noire", 2.3, 2.4, 0.12, x, 1.9, z)
	K.box("or", 2.5, 0.1, 0.16, x, 3.15, z)
	K.box("or", 2.5, 0.1, 0.16, x, 0.65, z)
	load(LOT_E).ecran(K, x, 1.75, z - 0.07, 2.0, 1.3, PI, 4, 0.5)
	K.zone_fin()


## Ceux qui restent quand le stade est désert : le voiturier de la station, le barman de la piscine ; dans le
## hall, l'hôtesse de l'accueil, le vigile à la porte, et sur le balcon du palier deux visiteurs qui regardent
## l'atrium en bavardant.
func _figurants() -> void:
	var P = Atelier.personnages()
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
	var h: Node3D = P.figurant("hotesse", 2)
	h.position = Vector3(-6.8, 0, -31.6)
	add_child(h)
	h.regarder(Vector3(-4.0, 0, -35.5))
	h.jouer("idle")
	var g: Node3D = P.figurant("vigile", 1)
	g.position = Vector3(4.0, 0, -34.7)
	add_child(g)
	g.regarder(Vector3(0, 0, -31.0))
	g.jouer("idle")
	for k in 2:
		var c: Node3D = P.figurant("client", 31 + k)
		c.position = Vector3(-1.2 + k * 0.9, 4.5, -28.4)
		add_child(c)
		c.regarder(Vector3(-0.3 - k * 0.9, 4.5, -28.4))
		c.jouer("talk", k * 1.3)


func _process(delta: float) -> void:
	_t += delta
	K.animer(delta, _t)
	if _roue.has("cases"):
		(_roue.cases as Node3D).rotation.y = _t * VITESSE_ROUE
		(_roue.bille as Node3D).position = load(ROUE).place_bille(_t)
		var m: Array = _roue.ecran
		if stade != null:
			for i in m.size():
				m[i][0].text = stade._score.text
				m[i][1].text = stade._horloge.text
				m[i][2].text = stade._affiche.text
	_revu += delta
	if _revu > 1.0:
		_revu = 0.0
		_vivre()
	for o in _parvis.get("yeux", []):
		var mat: StandardMaterial3D = o.material_override
		mat.emission_energy_multiplier = 2.4 + 1.2 * sin(_t * 1.3)


## Les interactions passent d'abord par le décor (socle 1.18) : les siennes, et la sortie, qui est un taxi.
func interagir(cle: String, cible: Node) -> bool:
	var player: CharacterBody3D = stade.player
	match cle:
		"taxi", "exit":
			load(TAXI).ouvrir(stade, player, "Où va-t-on ?", [
				["Retour au Casino Minuit", "Le Strip, la porte-cochère du casino", _retour_casino],
				["L'aéroport McCarran", "Le vol MN 1203, pour Poitiers-Biard", func(): Carte.ouvrir()]])
		"monter":
			player.global_position = cible.get_meta("vers")
			player.velocity = Vector3.ZERO
			player.rotation.y = float(cible.get_meta("cap", player.rotation.y))
		"billetterie":
			stade._dire(_billetterie())
		"accueil":
			stade._dire(_accueil())
		"boutique":
			stade._dire(["« Le maillot du dimanche, rouge et or, brodé main : 1 203 dollars. Le prix du vol, monsieur. »",
				"« L'écharpe en soie du Racing Club Minuit. Elle porte bonheur aux tables, paraît-il. »",
				"« Jackpot en peluche, chapeau compris. Les enfants l'adorent, les joueurs aussi. »"].pick_random())
		"tunnel":
			stade._dire("Les joueurs entrent par là le dimanche, sous les flammes et les feux d'artifice. La porte est fermée la semaine.")
		"piscine":
			stade._dire(["« Un Fortune Spritz ? Les cabanas se louent à la journée de match, avec vue sur la pelouse. »",
				"« La piscine est à l'année. Le dimanche, on parie depuis l'eau. »"].pick_random())
		"machines":
			stade._dire("Les machines du Jackpot Lounge tournent pour le décor : on joue aux tables du casino, sur le Strip.")
		"scene":
			stade._dire("La scène de Minuit Live : le dimanche, un concert avant le coup d'envoi et à la mi-temps.")
		_:
			return false
	return true


## Le taxi du retour : on repart à la porte-cochère du casino (minuit.gd lit le point de retour).
func _retour_casino() -> void:
	Game.return_point = stade._lot()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var c: Commune = Communes.commune(stade.commune)
	Chargement.changer(str(c.data.scene) if c else "res://scenes/main.tscn")


## L'hôtesse de l'accueil : le chemin, et ce qui se passe au stade à cette heure.
func _accueil() -> String:
	match moment:
		"desert":
			return "« Bienvenue au stade de la Fortune. Tout dort ce soir, mais la piscine des parieurs est ouverte : par l'escalier, à gauche. »"
		"entrainement":
			return "« L'entraînement est public : montez par l'escalier, les tribunes sont ouvertes. Le tunnel des joueurs est sous le palier. »"
		"portes", "match":
			return "« Vos places sont en haut de l'escalier. Le Jackpot Lounge à droite, la piscine à gauche, le penthouse par l'ascenseur de verre. »"
		"sortie":
			return "« Merci de votre visite ! Les taxis attendent sur le parvis, sous la marquise. »"
	return "« Les tribunes en haut de l'escalier, la billetterie à droite, la boutique du club à gauche. »"


## Le guichet : le prochain coup d'envoi, à l'heure du jeu.
func _billetterie() -> String:
	var t: int = Football.maintenant()
	var pc: Array = Football.prochain_coup_envoi(t)
	var d := Time.get_datetime_dict_from_unix_time(int(pc[2]))
	var jours := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
	return "« Prochain match le %s %d à %d h, portes à 13 h. Le Racing Club Minuit compte sur vous. »" % [jours[d.weekday], d.day, d.hour]
