extends Node3D
## Casino Minuit, sur le Strip de Las Vegas : une commune « ailleurs » (socle 1.5), rejointe en avion
## depuis Poitiers-Biard. Portage en GDScript des lots A à F du moteur web, bâtis par le kit (kit.gd)
## zone par zone : la rotonde d'entrée, l'atrium, le grand escalier et la galerie de la mezzanine (lot A) ;
## l'ouest (lot B) : le lobby de l'hôtel, le salon, les machines, le poker, les hautes limites, et à la
## mezzanine le lounge et le jardin d'hiver ; l'est (lot C) : le foyer du théâtre, la fosse aux tables, la
## caisse, le club Minuit, les paris sportifs, et à la mezzanine le Lucullus et les boutiques ; les coulisses
## (lot D) : le couloir de service, l'arrière-caisse, l'escalier du personnel et, au sous-sol, l'épine, le
## comptage, le sas et le coffre (clos), la surveillance, l'entretien, les vestiaires, la cuisine et le quai ;
## dehors (lot E) : le parvis et la façade, les fontaines, le boulevard et son trafic, le trottoir d'en face ;
## le lot F : l'arène de boxe en face et la salle de concert derrière le foyer, closes sous leur seuil.
## Comme toute commune, la scène expose `player` et `camera` : le jeu y ajoute la bascule de vue
## (Tab), les commandes tactiles et la carte. On entre à pied, par la porte-tambour de la rotonde ; on repart
## de dehors, par le voiturier de la porte-cochère ou la station de taxis : la carte et le vol du retour.

const BASE := "res://communes/casino_minuit/"
const ZONES := ["rotonde", "atrium", "escalier", "galerie",
	"lobby", "salon", "machines", "poker", "hautes_limites", "wc_ouest", "lounge", "jardin", "wc_mezzanine",
	"foyer", "pit", "cage", "club", "wc_est", "sports", "restaurant", "boutiques",
	"service", "arriere", "escalier_staff", "couloir", "comptage", "antichambre", "coffre", "securite",
	"entretien", "vestiaire", "cuisine", "quai",
	"strip", "facade", "fontaines", "boulevard", "enface", "arene", "concert"]
## Le change : un jeton du Minuit vaut un crédit de Smarves. C'est un premier taux, que réglera plus tard
## une doctrine économique commune aux villes. La caisse l'affiche ; aux tables (tables.gd), on mise ses
## crédits à ce taux.
const TAUX_JETONS := 1.0
## Le salon des hautes limites : son cordon s'ouvre au seuil de son lieu.
const HAUTES_LIMITES := "hautes_limites"
## Les lieux du lot C qui s'ouvrent à leur seuil.
const CLUB_MINUIT := "club_minuit"
const LUCULLUS := "lucullus"
const BOUTIQUES := "boutiques"
## Les coulisses (lot D), réservées au personnel : leurs trois portes d'entrée (la fosse, la caisse, la
## galerie des boutiques) restent closes sous le seuil du lieu. [porte, invite à x, y, z, hauteur du sol].
const COULISSES := "coulisses"
const PORTES_COULISSES := [["L25", Vector3(35.4, 1.1, 2.0), 0.0], ["L14", Vector3(31.5, 1.1, 20.4), 0.0], ["M12", Vector3(38.0, 1.1, -3.4), 6.0]]
const LOT_D := BASE + "zones/lot_d.gd"
## Le lot F : l'arène (sa porte sur le trottoir d'en face) et la salle de concert (les deux portes du foyer).
const ARENE := "arene"
const CONCERT := "concert"
const PORTES_CONCERT := [16.05, 19.95]
const ZF := -29.8
## Le découpage de la vue : dehors, dedans, l'arène, la salle de concert (zones K, figurants).
const DEDANS_VU := ["R-ROTONDE", "R-ATRIUM", "R-ESCALIER", "M-GALERIE"]
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
var _rendu
var _decor_
var _tables
## Les gens du casino (pnj/pnj.gd, le moteur des PNJ de l'original).
var pnj
## Les ascenseurs (ascenseurs.gd), que les PNJ prennent aussi.
var _ascenseurs
var _t := 0.0
## Les groupes de nœuds que la vue montre ou cache selon où l'on est, et le dernier état appliqué.
var _groupes := {}
## Le nœud de zone dont dépend la visibilité d'un nœud du dedans (zone, figurant).
var _zone_de := {}
var _vue := ""
var _invite: Label
var _message: Label
## Le coin du compte, comme au casino de Smarves : les crédits (qui roulent vers leur valeur), le gagné au jeu,
## les dettes ; et le rappel des commandes en bas, selon la vue.
var _credits: Label
var _gagne: Label
var _affiche := -1.0
var _aide: Label


func _ready() -> void:
	_ambiance()
	K = load(BASE + "kit.gd").new(self)
	K.places["pilotes"] = load(BASE + "zones/pilotes.gd").new()
	for z in ZONES:
		load(BASE + "zones/%s.gd" % z).construire(K)
	_cordon()
	for c in CORDONS:
		_cordon_lieu(c[0], c[1], c[2], c[3])
	_coulisses()
	_arene_porte()
	_concert_portes()
	_decor()
	_tables = load(BASE + "tables.gd").new(self, K)
	_tables.poser()
	_eclairer()
	_joueur()
	_peupler()
	_decouper()
	_interface()
	# On entre à pied : la vue de dessus reste à un Tab.
	if get_tree().current_scene == self:
		Vue.basculer.call_deferred(self)


func _process(dt: float) -> void:
	_t += dt
	K.places.pilotes.avancer()
	K.animer(dt, _t)
	_rendu.chaque_image(dt, player.global_position, -player.global_basis.z)
	_cadrer()
	_affiche = Game.credits if _affiche < 0.0 else lerpf(_affiche, Game.credits, 1.0 - exp(-10.0 * dt))
	if absf(_affiche - Game.credits) < 0.5:
		_affiche = Game.credits
	_credits.text = "%s crédits" % Game.fmt(roundi(_affiche))
	_gagne.text = "Gagné au jeu : %s" % Game.fmt(Game.won) + ("\nDettes : %s" % Game.fmt(Game.debt) if Game.debt > 0 else "")
	# Sous un panneau de jeu, le rappel des commandes s'efface : le panneau a les siennes.
	_aide.visible = _tables._panneau == null
	var f = player.focus_target if player else null
	_invite.text = str(f.get_meta("prompt", "")) + "  [E]" if f != null and f.has_meta("prompt") else ""
	if _invite.text == "" and pnj != null:
		_invite.text = pnj.invite()


## Les PNJ de l'original : ils vivent dans tout le casino ; les lieux encore fermés au joueur restent au
## personnel (les clients n'y vont pas).
func _peupler() -> void:
	var fermes: Array = []
	for id in [HAUTES_LIMITES, LUCULLUS, BOUTIQUES, ARENE, CONCERT]:
		if Game.won < _seuil(id):
			fermes.append(id)
	pnj = load(BASE + "pnj/pnj.gd").new()
	if not pnj.preparer(self, fermes):
		pnj.free()
		pnj = null
	else:
		_ascenseurs = load(BASE + "ascenseurs.gd").new(self, K, pnj)
		_ascenseurs.poser()
		add_child(pnj)
	load(BASE + "zones/figurants.gd").peupler(self, pnj == null)


## Les cabines, portes et voyants, à chaque pas des ascenseurs (pnj.update_elevators).
func ascenseurs_animer(_elevators: Dictionary) -> void:
	if _ascenseurs != null:
		_ascenseurs.animer()


## Une zone est-elle montrée (les PNJ d'une zone cachée ne sont ni affichés ni animés) ?
func zone_montree(id: String) -> bool:
	var nd := get_node_or_null(NodePath(_rendu.noeud(id)))
	if nd is Node3D:
		return (nd as Node3D).visible
	return player != null and player.global_position.z <= 30.5


## Le décor de l'original (decor.gd) : il remplace les maillages que les zones du portage ont refaits.
func _decor() -> void:
	_decor_ = load(BASE + "decor.gd").new(self, K)
	_decor_.charger()


## L'ambiance (rendu.gd) : les profils de scène et de zone du moteur web, ses lampes au budget, ses halos.
func _ambiance() -> void:
	_rendu = load(BASE + "rendu.gd").new(self)


## Après la construction : les halos relevés sous leurs zones ; les lumières que les zones du dedans ont posées
## cèdent la place aux lampes au budget (le dehors, l'arène et la salle de concert gardent les leurs).
func _eclairer() -> void:
	_rendu.poser_halos()
	for c in get_children():
		var nom := str(c.name)
		if nom.begins_with("R-") or nom.begins_with("M-") or nom.begins_with("B-") or nom.begins_with("ESC-"):
			for l in c.find_children("*", "OmniLight3D", true, false):
				l.visible = false
				l.light_energy = 0.0


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
	# Le champ du moteur web : 68° à la verticale.
	player.camera.fov = 68.0
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
		# Le voiturier de la porte-cochère ou la station de taxis : repartir, c'est la carte de Las Vegas et
		# le vol du retour.
		"sortie": Carte.ouvrir()
		"stade": _stade()
		"change": _dire("Au change, un jeton du Minuit vaut %s crédit. La caisse est à l'est, derrière la fosse aux tables." % _taux())
		"caisse": _dire("À la caisse, 1 jeton = %s crédit de Smarves : aux tables et aux machines, on mise ses crédits." % _taux())
		"hautes_limites": _dire("Le salon des hautes limites ouvre à %s crédits gagnés au jeu." % Game.fmt(_seuil(HAUTES_LIMITES)))
		"club_minuit": _club()
		"distributeur": _dire("Le distributeur affiche votre solde : %s crédits." % Game.fmt(Game.credits))
		"lucullus": _lieu(LUCULLUS, "Le Lucullus reçoit à dîner à partir de %s crédits gagnés au jeu.", "Le maître d'hôtel vous attend : la carte du Lucullus viendra plus tard.")
		"boutiques": _lieu(BOUTIQUES, "Les boutiques de luxe reçoivent à partir de %s crédits gagnés au jeu.", "Les vitrines vous sont ouvertes ; les achats viendront plus tard.")
		"theatre": _dire("Le Minuit Showroom fait relâche ce soir : la saison du théâtre viendra plus tard.")
		"arene": _lieu(ARENE, "Minuit Arena ouvre ses portes à %s crédits gagnés au jeu : M. Delgado, le promoteur, vous y attend.", "M. Delgado vous fait passer le contrôle : le combat du soir est commencé.")
		"concert": _lieu(CONCERT, "Minuit Live ouvre à %s crédits gagnés au jeu : Mme Rivière, la programmatrice, vous y fera entrer.", "Mme Rivière vous ouvre la salle : le concert a commencé.")
		"fontaines": _fontaines(cible)
		"cloche": _cloche(cible)
		"coulisses": _lieu(COULISSES, "Les coulisses sont réservées au personnel : M. Vasseur, le chef de la sécurité, vous les ouvrira à %s crédits gagnés au jeu.", "M. Vasseur vous a fait badger : les coulisses vous sont ouvertes.")
		"coffre": _dire("La porte du coffre ne s'ouvre qu'à deux, devant les caméras : elle reste close.")
		"paris": _dire("Les paris suivent les matchs du dimanche, comme à Smarves. Les guichets ouvriront plus tard.")
		"table": _tables.ouvrir(cible)
		"ascenseur_appel", "ascenseur_panneau": _ascenseurs.utiliser(cible)
		"salle_poker": _tables.ouvrir_salle()


## Le pupitre des fontaines : le prochain spectacle, qu'on peut lancer tout de suite.
func _fontaines(cible: Node) -> void:
	var etat: Dictionary = cible.get_meta("etat", {})
	if etat.get("en_cours", false):
		_dire("Le spectacle des fontaines est en cours.")
		return
	etat.debut = etat.get("t", _t)
	_dire("Les jets se lèvent : le spectacle des fontaines commence.")


## La cloche du chronométreur (arene-cloche : AR.bell('joueur')) : elle lance le round, le clôt, ou relance la soirée.
func _cloche(_cible: Node) -> void:
	K.places.pilotes.bell("joueur")


## La machine à sous demande à son hôte de payer la mise (tables.gd la fait jouer).
func spend(amount: int) -> bool:
	return Game.spend(amount)


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


## Les portes des coulisses (PORTES_COULISSES) : closes, avec leur invite côté public, tant que le joueur n'a
## pas gagné le seuil du lieu ; au-delà, ouvertes en grand contre leur tableau.
func _coulisses() -> void:
	var D = load(LOT_D)
	var ouvert := Game.won >= _seuil(COULISSES)
	for p in PORTES_COULISSES:
		K.zone_debut("Coulisses_" + p[0])
		K.zone.position.y = p[2]
		D.porte(K, p[0], not ouvert)
		if not ouvert:
			var v: Vector3 = p[1]
			K.interaction(COULISSES, "Les coulisses", v.x, v.y, v.z, Vector3(1.4, 2.2, 1.4))
		K.zone_fin()


## La porte de l'arène sur le trottoir d'en face : ses vantaux de verre fermés (on voit le hall au travers) tant
## que le joueur n'a pas gagné le seuil du lieu ; au-delà, ils restent coulissés de part et d'autre.
func _arene_porte() -> void:
	if Game.won >= _seuil(ARENE):
		return
	K.zone_debut("Porte_arene")
	for s in [-1.0, 1.0]:
		K.box("verre", 2.96, 3.9, 0.04, s * 1.5, 1.95, 90.35)
		K.box("or", 0.05, 3.9, 0.08, s * 2.98, 1.95, 90.35)
		K.box("or", 2.96, 0.06, 0.08, s * 1.5, 3.92, 90.35)
		K.box("or", 0.04, 1.2, 0.06, s * 0.15, 1.1, 90.3)
	K.texte("FERMÉ · OUVERTURE AU SEUIL DU LIEU", 2.6, 0.12, 0, 1.6, 90.31, PI, "grave", Color("#F3EAD7"))
	K.solide(6.0, 4.2, 0.3, 0, 2.1, 90.35)
	K.interaction(ARENE, "Minuit Arena", 0, 1.2, 89.2, Vector3(6.0, 2.4, 1.4))
	K.zone_fin()


## Les deux portes du foyer vers Minuit Live : leurs vantaux rouges clos tant que le joueur n'a pas gagné le seuil
## du lieu ; au-delà, ouverts à 100° contre le parement du sas.
func _concert_portes() -> void:
	var ouvert := Game.won >= _seuil(CONCERT)
	K.zone_debut("Portes_concert")
	for x in PORTES_CONCERT:
		for s in [-1.0, 1.0]:
			if ouvert:
				var hx: float = x + s * 0.94
				K.box("laque_rouge", 0.06, 2.5, 0.9, hx + s * 0.06, 1.3, -30.75)
				K.cyl("or", 0.03, 0.03, 0.5, hx + s * 0.11, 1.1, -31.0, 6)
				K.obstacle(hx - 0.02 + minf(0.0, s * 0.12), hx + 0.02 + maxf(0.0, s * 0.12), -31.25, -30.3)
			else:
				K.box("laque_rouge", 0.93, 2.6, 0.06, x + s * 0.48, 1.3, ZF + 0.02)
				K.box("or", 0.04, 0.4, 0.08, x + s * 0.1, 1.1, ZF + 0.06)
		if not ouvert:
			K.obstacle(x - 0.95, x + 0.95, ZF - 0.1, ZF + 0.2, 0.0, 2.8)
	if not ouvert:
		K.interaction(CONCERT, "Minuit Live", 18, 1.3, ZF + 0.6, Vector3(5.0, 2.6, 0.8))
	K.zone_fin()


## Les groupes de la vue : dehors (le lot E et ses figurants), le dedans qu'on voit par la porte-tambour,
## le reste du dedans, l'arène, la salle de concert.
func _decouper() -> void:
	_groupes = {"dehors": [], "vu": [], "dedans": [], "hall": [], "arene": [], "concert": []}
	_zone_de = {}
	for c in get_children():
		var nom := str(c.name)
		if nom.begins_with("X-") or nom == "Porte_arene":
			_groupes.dehors.append(c)
		elif nom == "F-ARENE":
			_groupes.hall.append(c)
		elif nom.begins_with("F-ARENE"):
			_groupes.arene.append(c)
		elif nom.begins_with("F-CONCERT") or nom == "Portes_concert":
			_groupes.concert.append(c)
		elif nom in DEDANS_VU:
			_groupes.vu.append(c)
			_zone_de[c] = nom
		elif nom.begins_with("R-") or nom.begins_with("M-") or nom.begins_with("B-") or nom.begins_with("ESC-") or nom.begins_with("Cordon") or nom.begins_with("Coulisses"):
			_groupes.dedans.append(c)
			if not (nom.begins_with("Cordon") or nom.begins_with("Coulisses")):
				_zone_de[c] = nom
	var fig := get_node_or_null("Figurants")
	if fig:
		for c in fig.get_children():
			var nom := str(c.name)
			if nom == "Dehors":
				_groupes.dehors.append(c)
			elif nom == "Arene":
				_groupes.arene.append(c)
			elif nom == "Concert":
				_groupes.concert.append(c)
			else:
				_groupes.dedans.append(c)
				# Un figurant du dedans se montre avec la zone où il se tient.
				var z: Dictionary = _rendu.zone_a((c as Node3D).global_position + Vector3(0, 0.1, 0))
				if not z.is_empty():
					_zone_de[c] = _rendu.noeud(z.id)
	_cadrer()


## Ce que la vue montre d'où l'on est : dehors, le dedans s'arrête à la rotonde et à l'atrium (vus par la
## porte) ; dedans, seules les zones qu'on voit de celle où l'on est (rendu.gd, les « sees » du moteur web) et
## leurs figurants ; le dehors s'efface passé la rotonde ; le hall de l'arène (vu par sa porte) dès qu'on est
## dehors, sa salle depuis le trottoir d'en face, la salle de concert depuis le foyer. La caméra voit loin dehors (le ciel, les tours), court dedans.
func _cadrer() -> void:
	if player == null or _groupes.is_empty():
		return
	var p := player.global_position
	var dehors := p.z > 30.5
	var noms := {}
	if not dehors and not _rendu.zone.is_empty():
		noms = _rendu.noeuds_visibles(p)
	var cle := ",".join(PackedStringArray(noms.keys()))
	var vue := "%d%d%d%d" % [int(p.z > 12.0), int(dehors), int(p.z > 75.0), int(p.x > 4.0 and p.z < -12.0)] + cle
	if vue == _vue:
		return
	_vue = vue
	_montrer(_groupes.dehors, p.z > 12.0)
	if noms.is_empty():
		_montrer(_groupes.dedans, not dehors)
		_montrer(_groupes.vu, true)
	else:
		for g in [_groupes.dedans, _groupes.vu]:
			for n in g:
				_montrer([n], noms.has(_zone_de[n]) if _zone_de.has(n) else true)
	_montrer(_groupes.hall, dehors)
	_montrer(_groupes.arene, p.z > 75.0)
	_montrer(_groupes.concert, p.x > 4.0 and p.z < -12.0)
	camera.far = 900.0 if p.z > 12.0 else 300.0


## Montre ou cache un groupe ; les figurants cachés s'arrêtent (les zones gardent leurs collisions).
func _montrer(liste: Array, oui: bool) -> void:
	for n in liste:
		(n as Node3D).visible = oui
		if n.get_parent() != self:
			n.process_mode = Node.PROCESS_MODE_INHERIT if oui else Node.PROCESS_MODE_DISABLED


func _dire(t: String) -> void:
	_message.text = t
	_message.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_message, "modulate:a", 0.0, 0.6)


func _interface() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var racine := Control.new()
	racine.theme = load(BASE + "tables.gd").theme()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(racine)
	# Le compte, en haut à gauche, sous les boutons du retour que le jeu pose dans le coin.
	var compte := PanelContainer.new()
	compte.position = Vector2(20, 74)
	compte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(compte)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	compte.add_child(v)
	var titre := Label.new()
	titre.text = "C A S I N O   M I N U I T   ·   L A S   V E G A S"
	titre.add_theme_font_size_override("font_size", 13)
	titre.add_theme_color_override("font_color", Color(0.75, 0.62, 0.45))
	v.add_child(titre)
	_credits = Label.new()
	_credits.add_theme_font_size_override("font_size", 38)
	_credits.add_theme_color_override("font_color", Color(0.96, 0.8, 0.45))
	v.add_child(_credits)
	_gagne = Label.new()
	_gagne.add_theme_font_size_override("font_size", 16)
	v.add_child(_gagne)
	_aide = Label.new()
	_aide.add_theme_font_size_override("font_size", 15)
	_aide.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68, 0.9))
	_aide.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_aide.add_theme_constant_override("outline_size", 4)
	_aide.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_aide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_aide.offset_top = -44
	_aide.offset_bottom = -20
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	racine.add_child(_aide)
	_rappel(true)
	Vue.basculee.connect(_rappel)
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


## Le rappel des commandes, comme au village : à pied, ou vu de dessus (la bascule du jeu, Tab).
func _rappel(dessus: bool) -> void:
	_aide.text = ("ZQSD : marcher   ·   Maj : courir   ·   Clic droit : tourner   ·   Molette : zoom   ·   E : agir, jouer   ·   Tab : vue à pied" if dessus
		else "ZQSD : marcher   ·   Maj : courir   ·   Souris : regarder   ·   E : agir, jouer   ·   Tab : vue de dessus") \
		+ "   ·   M : la carte   ·   C : le carnet   ·   Échap : réglages"
