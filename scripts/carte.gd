extends CanvasLayer
## L'écran de la carte de la Vienne (autoload « Carte »). On y arrive en dézoomant au-delà du cran
## « quartier » au village (molette ou pincer), avec M, depuis la bienvenue, ou dès le menu de départ ; on en repart en
## zoomant sur sa commune, avec Échap ou « Revenir ». Smarves en or, les villes installées en vert
## d'eau vif, les villes publiées sur le portail en vert d'eau pâle, les autres en filigrane, et
## Poitiers dans la brume. Une commune qui arrive (publiée, installée) s'allume à l'ouverture
## suivante. Toucher une commune la montre dans la fiche ; « Y aller » change de commune. Au bord de
## la brume, l'aéroport de Poitiers-Biard dessert les destinations lointaines (socle 1.5) : la fiche
## de Poitiers donne leurs vols, et l'on y part en avion (voler). Dézoomer encore sur le département
## entier montre la France (vers_france) : les régions cernées, la Vienne en or, l'épingle sur la
## commune où l'on est. Un clic sur une région s'en approche (vers_region), un clic sur un de ses
## départements que le jeu connaît (la Nouvelle-Aquitaine, l'Auvergne-Rhône-Alpes et l'Occitanie) y
## redescend (vers_departement), sans fiche à valider ; seule la commune demande « Y aller ». En haut à gauche, le fil d'Ariane (France › région ›
## département) dit où l'on regarde et y remonte d'un clic, et « Où aller » liste les villes ouvertes ou
## à installer, les plus proches d'abord ; la fiche d'une ville dit ce qu'on y trouve et le trajet.

const OR := Color(0.96, 0.8, 0.45)
const EAU := Color(0.35, 0.8, 0.75)
const TEXTE := Color(0.88, 0.9, 0.92)
const DOUX := Color(0.65, 0.7, 0.75)
const ROUGE := Color(0.95, 0.45, 0.42)
const NUIT := Color(0.05, 0.07, 0.1)
## Le zoom d'où l'on part et où l'on replonge : la commune remplit le milieu de l'écran.
const ZOOM_COMMUNE := 7.0
## Les communes déjà allumées sous les yeux du joueur.
const VUES := "allumees.json"

var _root: Control
var _voile: ColorRect
var _carte: CarteVienne
var _fiche: PanelContainer
var _fiche_box: VBoxContainer
var _compte: Label
var _legende: VBoxContainer
var _ariane: HBoxContainer
var _ou_aller: VBoxContainer
var _retour: Button
var _aide: Label
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _paused_before := false
var _en_route := false
## Ouverte depuis l'écran titre : pas encore de partie, on n'est nulle part, « Revenir » rend le menu.
var _titre := false
## « car » à l'arrêt de la place (les lignes vers les communes desservies), « route » au bout d'une
## route (la fiche de la voisine dans cette direction), « » sinon.
var _mode := ""
var _sur_titre: Label
var _grand_titre: Label
var _capture := "--capture" in " ".join(OS.get_cmdline_user_args())
## Le vol vers une destination lointaine (ou le retour) : un écran à part, au-dessus de tout.
var _vol: CanvasLayer
var _vol_trajet: Control
var _vol_titre: Label
var _vol_ligne: Label
## La durée d'un vol à l'écran (secondes) ; un test la raccourcit.
var duree_vol := 2.6


func _ready() -> void:
	layer = 46
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construire()
	_construire_vol()
	_root.visible = false
	Communes.catalogue_lu.connect(func():
		if is_open():
			_rafraichir(true))
	Communes.etat_change.connect(func(_id):
		if is_open():
			_rafraichir(true))
	Communes.installee.connect(func(id, ok, message):
		if is_open():
			_rafraichir(true)
			# Une destination lointaine n'a pas de code INSEE : sa fiche est celle de Poitiers(-Biard).
			var insee: String = Communes.au_catalogue(id).get("insee", "") if not ok else Communes.commune(id).insee
			_montrer(insee if insee != "" else CarteVienne.POITIERS_INSEE, "" if ok else message))


func is_open() -> bool:
	return _root.visible


## M ouvre la carte depuis le village ou une commune greffée, quand rien d'autre n'est ouvert.
func _unhandled_input(event: InputEvent) -> void:
	if is_open():
		if event.is_action_pressed("ui_cancel"):
			fermer()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
			fermer()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M and peut_ouvrir():
		ouvrir()
		get_viewport().set_input_as_handled()


## Dehors seulement : au village (sans table ni panneau ouvert) ou dans une commune greffée.
func peut_ouvrir() -> bool:
	var scene := get_tree().current_scene
	if scene == null or _en_route or Carnet.is_open() or Settings.is_open() or Bienvenue.is_open() or scene.has_meta("vitrine"):
		return false
	if Communes.actuelle() != Communes.ORIGINE:
		return true
	if scene.name != "Main" or get_tree().paused:
		return false
	var panneaux = scene.get("_panels")
	return not (panneaux is Node and panneaux.get_child_count() > 0)


## L'arrêt du car départemental, sur la place : la carte des communes où il s'arrête.
func ouvrir_car() -> void:
	ouvrir(false, "", "car")


## Le bout d'une route : la carte, tournée vers la commune voisine dans cette direction.
func ouvrir_vers(insee: String) -> void:
	ouvrir(false, insee, "route")


## Les communes où l'on peut aller d'ici : Smarves, les villes installées et les publiées.
func desservies() -> Array:
	var out := []
	for i in [CarteVienne.ORIGINE_INSEE] + _carte.installees + _carte.publiees:
		if i != _ici() and not out.has(i):
			out.append(i)
	return out


## depuis_titre : depuis le menu de départ, avant d'entrer dans le jeu ; choisir Smarves lance la partie.
## vers : la commune à montrer d'emblée ; mode : « car », « route » ou « ».
func ouvrir(depuis_titre := false, vers := "", mode := "") -> void:
	if is_open():
		return
	_titre = depuis_titre
	_mode = mode
	_mouse_before = Input.mouse_mode
	_paused_before = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_root.visible = true
	# La carte couvre tout l'écran : le village derrière elle n'a pas à être dessiné, la carte
	# graphique se repose.
	get_viewport().disable_3d = true
	_carte.niveau = "departement"
	_carte.departement = _dep_ici()
	_carte.region = ""
	_remplir_legende()
	_rafraichir(false)
	var ici := _ici() if not _loin() else CarteVienne.POITIERS_INSEE
	_carte.ici = "" if _titre or _loin() else ici
	_carte.choisie = vers
	_carte.trajet = vers
	_carte.lignes = desservies() if _mode == "car" else []
	_montrer(vers if vers != "" else ici)
	# On s'élève au-dessus de sa commune, puis le département entier se découvre ; au bout d'une
	# route, seulement jusqu'à voir les deux communes.
	_carte.cadrer(ici, ZOOM_COMMUNE)
	if vers != "":
		_carte.aller_a((_carte.centre_de(ici) + _carte.centre_de(vers)) / 2.0, 3.2, 1.1)
	elif _mode == "car":
		_carte.cadrer(ici, 2.6, 1.1)
	else:
		_carte.cadrer_tout(1.1)
	_voile.color = Color(NUIT, 1.0)
	var t := create_tween()
	t.tween_property(_voile, "color:a", 0.0, 0.45)
	var neuves := _neuves()
	_carte.allumer(neuves)
	if not neuves.is_empty():
		if not _capture:
			Portail.ecrire(Communes.dossier_greffes.path_join(VUES), JSON.stringify(_allumees()))


## Repart dans sa commune : la carte replonge sur elle et s'efface.
func fermer() -> void:
	if not is_open() or _en_route:
		return
	_en_route = true
	if _carte.niveau == "france":
		_carte.cadrer(_carte.departement, CarteVienne.ZOOM_MAX_FRANCE, 0.45)
	else:
		_carte.cadrer(_ici() if not _loin() else CarteVienne.POITIERS_INSEE, ZOOM_COMMUNE, 0.45)
	var t := create_tween()
	t.tween_property(_voile, "color:a", 1.0, 0.45)
	await t.finished
	_cacher()
	get_tree().paused = _paused_before
	Input.mouse_mode = _mouse_before


func _cacher() -> void:
	_root.visible = false
	get_viewport().disable_3d = false
	_en_route = false
	_voile.color.a = 0.0


## Va dans une autre commune : Smarves (on rentre), ou une commune greffée installée.
func aller(insee: String) -> void:
	if _en_route:
		return
	if insee == _ici() and not _titre and not _loin():
		fermer()
		return
	var c := Communes.par_insee(insee)
	if c == null:
		return
	# Depuis une destination lointaine, toute la Vienne est de l'autre côté de l'océan : on reprend l'avion.
	if _loin():
		voler(c.id)
		return
	_en_route = true
	_carte.cadrer(insee, ZOOM_COMMUNE, 0.6)
	var t := create_tween()
	t.tween_property(_voile, "color:a", 1.0, 0.6)
	await t.finished
	_cacher()
	if c.id == Communes.ORIGINE:
		Communes.revenir()
	elif not Communes.visiter(c.id):
		get_tree().paused = _paused_before
		Carnet.show_slip("%s ne s'ouvre pas : %s" % [c.nom, Communes.refus[-1][1] if not Communes.refus.is_empty() else "scène introuvable"])


## Le car descend à la salle de basket de la commune : la carte s'efface, la salle s'ouvre.
func descendre_salle(id: String) -> void:
	if _en_route:
		return
	_en_route = true
	var t := create_tween()
	t.tween_property(_voile, "color:a", 1.0, 0.45)
	await t.finished
	_cacher()
	get_tree().paused = false
	SalleBasket.ouvrir(id)


func _installer(id: String) -> void:
	Communes.installer(id)
	_rafraichir(true)


## Le geste de la commune (Installer, Mettre à jour, Réessayer, Relancer), ou la barre du téléchargement.
func _geste(id: String, actions: HBoxContainer) -> void:
	if Communes.etat(id) in ["telechargement", "attente"]:
		actions.add_child(BarreProgres.pour(id, EAU, 140.0))
		return
	var g := Communes.geste(id)
	if not g.is_empty():
		var teinte := EAU if Communes.etat(id) == "publiee" else OR
		var appel: Callable = _installer.bind(id) if g[0] != "Relancer maintenant" else g[1]
		actions.add_child(_bouton(g[0], Color(0, 0, 0, 0), teinte, teinte, appel, 16))


func _ici() -> String:
	var c := Communes.commune(Communes.actuelle())
	return c.insee if c else CarteVienne.ORIGINE_INSEE


## Le département où l'on est (la Vienne depuis une destination lointaine ou le menu).
func _dep_ici() -> String:
	var d := Departements.de(_ici()) if not _loin() else France.VIENNE
	return d if Departements.connu(d) else France.VIENNE


## L'endroit d'où l'on part : sa commune, ou Poitiers-Biard depuis une destination lointaine.
func _depart() -> String:
	return _ici() if not _loin() else CarteVienne.POITIERS_INSEE


## Le trajet d'ici à une commune : [kilomètres, mot du trajet, étapes]. Dans un département, le car
## départemental va de commune en commune (45 km/h, cinq minutes d'arrêt). D'un département à l'autre,
## on passe par les chefs-lieux, les gares des départements : le car départemental jusqu'au sien, le car
## régional (60 km/h, dix minutes) vers un chef-lieu de la même région ou l'avion (600 km/h, trois
## quarts d'heure d'embarquement) vers celui d'une autre région, puis le car départemental jusqu'au
## bout ; le retour fait le même chemin. La route fait environ 1,3 fois la distance à vol d'oiseau.
## Chaque étape : [mode, code INSEE de départ, code INSEE d'arrivée, kilomètres, minutes]. On part
## d'ici, ou de la commune « de ».
func trajet(insee: String, de := "") -> Array:
	if de == "":
		de = _depart()
	if insee == de or Departements.commune(insee).is_empty() or Departements.commune(de).is_empty():
		return [0, "", []]
	var etapes := []
	var da := Departements.de(de)
	var db := Departements.de(insee)
	if da == db:
		etapes.append(_etape("car départemental", de, insee))
	else:
		var ga := Departements.chef_lieu(da)
		var gb := Departements.chef_lieu(db)
		if Departements.commune(ga).is_empty() or Departements.commune(gb).is_empty():
			ga = de
			gb = insee
		if de != ga:
			etapes.append(_etape("car départemental", de, ga))
		etapes.append(_etape("car régional" if France.region_de(da) == France.region_de(db) else "avion", ga, gb))
		if insee != gb:
			etapes.append(_etape("car départemental", gb, insee))
	var km := 0
	var mn := 0
	for e in etapes:
		km += e[3]
		mn += e[4]
	var duree := ("%d h %02d" % [mn / 60, mn % 60]) if mn >= 60 else "%d min" % mn
	if etapes.size() == 1 and etapes[0][0] != "avion":
		return [km, "%d km  ·  %s en %s" % [km, duree, etapes[0][0]], etapes]
	var mots := []
	for e in etapes:
		mots.append(("avion de %s à %s" % [_gare(e[1]), _gare(e[2])]) if e[0] == "avion" else "%s jusqu'à %s" % [e[0], str(Departements.commune(e[2]).nom)])
	return [km, "%d km  ·  %s  ·  %s" % [km, duree, ", puis ".join(mots)], etapes]


func _etape(mode: String, a: String, b: String) -> Array:
	var vol := France.distance_km(Departements.centre(a), Departements.centre(b))
	if mode == "avion":
		return [mode, a, b, int(round(vol)), 45 + int(round(vol / 600.0 * 60.0))]
	var km := int(round(vol * 1.3))
	var vitesse := 45.0 if mode == "car départemental" else 60.0
	return [mode, a, b, km, (5 if mode == "car départemental" else 10) + int(round(km / vitesse * 60.0))]


## Le nom d'une gare : la commune, ou son aéroport quand il a un nom (Poitiers-Biard).
func _gare(insee: String) -> String:
	return "Poitiers-Biard" if insee == CarteVienne.POITIERS_INSEE else str(Departements.commune(insee).get("nom", ""))


## Comment on va d'ici dans un département : le car régional ou l'avion, depuis le chef-lieu d'ici.
func _moyen(code: String) -> String:
	var da := Departements.de(_depart())
	var gare := _gare(Departements.chef_lieu(da))
	if France.region_de(code) == France.region_de(da):
		return "le car régional y va depuis %s" % gare
	return "en avion depuis %s" % gare


## Le joueur est-il dans une destination lointaine (hors de la Vienne) ?
func _loin() -> bool:
	var c := Communes.commune(Communes.actuelle())
	return c != null and c.lointaine()


## Les communes marquées sur la carte : Smarves, les villes installées et les publiées.
func _allumees() -> Array:
	var out := [CarteVienne.ORIGINE_INSEE]
	for i in _carte.installees + _carte.publiees:
		if not out.has(i):
			out.append(i)
	return out


func _neuves() -> Array:
	var vues = Portail.lire_json(Communes.dossier_greffes.path_join(VUES))
	var deja: Array = vues if vues is Array else []
	return _allumees().filter(func(i): return not deja.has(i))


# --- La France ------------------------------------------------------------------------------------

## Dézoome au-delà du département : la France entière, les régions cernées, et le département d'où l'on
## vient en tête de fiche.
func vers_france() -> void:
	if _en_route or (_carte.niveau == "france" and _carte.region == ""):
		return
	var dep := _carte.departement
	var deja := _carte.niveau == "france"
	_carte.niveau = "france"
	_carte.region = ""
	_carte.choisie = ""
	_carte.trajet = ""
	_remplir_legende()
	_rafraichir(false)
	_montrer(dep)
	if not deja:
		_carte.cadrer(dep, CarteVienne.ZOOM_MAX_FRANCE)
	_carte.cadrer_tout(1.1)


## Regarde une région : la carte s'en approche, on y désigne ses départements.
func vers_region(code: String) -> void:
	if _en_route or France.region(code).is_empty():
		return
	if _carte.niveau != "france":
		var dep := _carte.departement
		_carte.niveau = "france"
		_carte.cadrer(dep, CarteVienne.ZOOM_MAX_FRANCE)
	_carte.region = code
	_carte.choisie = ""
	_carte.trajet = ""
	var cadre := _carte.cadre_region(code)
	_carte.aller_a(cadre[0], cadre[1], 0.9)
	_remplir_legende()
	_rafraichir(false)
	for c in _fiche_box.get_children():
		c.queue_free()
	_montrer_region(code)


## Redescend dans un département que le jeu connaît : la carte plonge sur lui, puis montre ses communes.
func vers_departement(code := France.VIENNE) -> void:
	if _en_route or not Departements.connu(code) or (_carte.niveau == "departement" and _carte.departement == code):
		return
	_en_route = true
	if _carte.niveau == "france":
		_carte.cadrer(code, CarteVienne.ZOOM_MAX_FRANCE, 0.6)
		await get_tree().create_timer(0.6).timeout
	_carte.niveau = "departement"
	_carte.departement = code
	_carte.region = ""
	_carte.choisie = ""
	_carte.trajet = ""
	_carte.cadrer_tout()
	_remplir_legende()
	_rafraichir(false)
	_montrer(_ici() if Departements.de(_ici()) == code else "")
	_en_route = false


## Le clic sur un département de la France : sur la France entière, sa région s'approche (la Vienne,
## elle, s'ouvre tout de suite) ; dans une région, un département connu montre ses communes, un
## département d'une autre région ouvre cette région, un département pas encore dans le jeu garde sa fiche.
func _descendre(code: String) -> void:
	var reg := France.region_de(code)
	if code == France.VIENNE and _carte.region == "":
		vers_departement(code)
	elif reg != "" and reg != _carte.region:
		vers_region(reg)
	elif Departements.connu(code):
		vers_departement(code)
	else:
		_carte.choisie = code
		_montrer(code)


## L'ancien nom : redescendre dans la Vienne.
func vers_vienne() -> void:
	vers_departement(France.VIENNE)


## Les villes d'un département qui sont dans le jeu, ouvertes ou à installer (codes INSEE), Smarves
## comprise pour la Vienne.
func villes_de(code: String) -> Array:
	return _allumees().filter(func(i): return Departements.de(i) == code)


## La fiche d'un département : la Vienne, un département de la même région (le car régional y va de
## chef-lieu à chef-lieu), ou un département plus loin, où l'on va en avion (trajet).
func _montrer_departement(code: String) -> void:
	var d := France.departement(code)
	var depart := _depart()
	var ici := Departements.commune(depart)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 10)
	tete.add_child(_mot(str(d.nom), 26, OR if code == France.VIENNE else Color.WHITE, Polices.titre()))
	if code == Departements.de(depart) and not _titre and not _loin():
		tete.add_child(_mot("VOUS ÊTES ICI", 12, EAU, Polices.gras()))
	_fiche_box.add_child(tete)
	var region := France.region(str(d.get("region", "")))
	var chef := str(d.get("chef_lieu", ""))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	var villes := villes_de(code)
	if code == France.VIENNE:
		_fiche_box.add_child(_mot("Votre département  ·  %s  ·  %s  ·  %s" % [code, _villes_mot(villes.size()), str(region.get("nom", ""))], 15, DOUX, null, true))
		_fiche_box.add_child(_mot("Smarves, au sud de Poitiers, sur le Clain : c'est d'ici que tout part. Les villes de la Vienne s'y allument une à une, à mesure qu'on les construit.\n\nPoitiers, son chef-lieu, est sa gare : le car régional en part vers la région, l'avion de Poitiers-Biard vers plus loin.", 16, TEXTE, null, true))
		if _carte.niveau == "france":
			actions.add_child(_bouton("Voir la Vienne  →", OR, Color(0.08, 0.06, 0.03), Color(0, 0, 0, 0), vers_departement.bind(code), 16))
	else:
		var km := France.distance_km(Departements.centre(depart), Vector2(d.centre[0], d.centre[1]))
		_fiche_box.add_child(_mot("Département %s%s  ·  à %s\u00a0km de %s, à vol d'oiseau" % [code, ("  ·  " + str(region.nom)) if not region.is_empty() else "",
			Game.fmt(int(round(km / 10.0) * 10)).replace(" ", "\u00a0"), str(ici.get("nom", "Smarves"))], 15, DOUX, null, true))
		var texte := ""
		if not villes.is_empty():
			texte = "%s, %s." % [_villes_mot(villes.size()), _moyen(code)]
		elif Departements.connu(code):
			texte = "%s ; ses %d communes attendent qu'on les construise%s, la première s'allumera ici." % [_moyen(code).left(1).to_upper() + _moyen(code).substr(1),
				Departements.communes(code).size(), (", de %s au moindre village" % chef) if chef != "" else ""]
		else:
			texte = "Pas encore dans le jeu : ses communes ne sont pas encore sur la carte. Le jour venu, %s." % _moyen(code)
		if chef != "" and Departements.connu(code):
			texte += "\n\n%s, son chef-lieu, est sa gare : le car régional et l'avion en partent vers les autres départements, et l'on y revient pour rentrer." % chef
		_fiche_box.add_child(_mot(texte, 16, TEXTE, null, true))
		if Departements.connu(code) and _carte.niveau == "france":
			actions.add_child(_bouton("Voir ses communes  →", EAU, Color(0.04, 0.1, 0.1), Color(0, 0, 0, 0), vers_departement.bind(code), 16))
		elif _carte.region == "" and not region.is_empty():
			actions.add_child(_bouton("Voir la région  →", Color(0, 0, 0, 0), EAU, EAU, vers_region.bind(str(region.code)), 16))
		actions.add_child(_bouton("Revenir à la Vienne", Color(0, 0, 0, 0), OR, OR, vers_departement.bind(France.VIENNE), 16))
	_fiche_box.add_child(_vide(2))
	_fiche_box.add_child(actions)


## La fiche d'une région, désignée sur la France entière : ses départements, et comment on y va.
func _montrer_region(code: String) -> void:
	var r := France.region(code)
	if r.is_empty():
		return
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 10)
	tete.add_child(_mot(str(r.nom), 26, EAU if code == France.REGION else Color.WHITE, Polices.titre()))
	if code == France.REGION and not _titre and not _loin():
		tete.add_child(_mot("VOTRE RÉGION", 12, EAU, Polices.gras()))
	_fiche_box.add_child(tete)
	var deps: Array = r.departements
	var villes := 0
	for d in deps:
		villes += villes_de(str(d)).size()
	_fiche_box.add_child(_mot("Région  ·  %d départements  ·  %s" % [deps.size(), _villes_mot(villes)], 15, DOUX, null, true))
	_fiche_box.add_child(_mot(("La Vienne et ses voisines : le car départemental dessert la Vienne, le car régional les %d autres départements." % (deps.size() - 1)) if code == France.REGION
		else ("Ses départements sont sur la carte, commune par commune : %s, jusqu'au chef-lieu de chacun." % _moyen(str(deps[0]))) if deps.any(func(d): return Departements.connu(str(d)))
		else "Pas encore dans le jeu. Le jour où ses villes seront construites, %s." % _moyen(str(deps[0])), 16, TEXTE, null, true))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.add_child(_bouton("Voir la région  →", EAU if code == France.REGION else Color(0, 0, 0, 0), Color(0.04, 0.1, 0.1) if code == France.REGION else EAU,
		Color(0, 0, 0, 0) if code == France.REGION else EAU, vers_region.bind(code), 16))
	_fiche_box.add_child(_vide(2))
	_fiche_box.add_child(actions)


func _villes_mot(n: int) -> String:
	return "aucune ville dans le jeu" if n == 0 else "%d ville%s dans le jeu" % [n, "s" if n > 1 else ""]


# --- Les destinations lointaines (socle 1.5) ------------------------------------------------------

## La fiche d'une destination lointaine, quand on y est : on n'en repart qu'en avion.
func _fiche_lointaine(id: String) -> void:
	var c := Communes.commune(id)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 10)
	tete.add_child(_mot(c.nom, 26, Color.WHITE, Polices.titre()))
	tete.add_child(_mot("VOUS ÊTES ICI", 12, EAU, Polices.gras()))
	_fiche_box.add_child(tete)
	_fiche_box.add_child(_mot("%s%s  ·  hors de la Vienne" % [c.ville(), (", " + c.pays()) if c.pays() != "" else ""], 15, DOUX, null, true))
	_fiche_box.add_child(_mot("La Vienne est de l'autre côté de l'océan. Pour y revenir, on reprend l'avion jusqu'à Poitiers-Biard, puis le car jusqu'à Smarves.", 16, TEXTE, null, true))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.add_child(_bouton("Reprendre l'avion  →", OR, Color(0.08, 0.06, 0.03), Color(0, 0, 0, 0), voler.bind(Communes.ORIGINE), 16))
	actions.add_child(_bouton("Rester à %s" % c.ville(), Color(0, 0, 0, 0), EAU, EAU, fermer, 16))
	_fiche_box.add_child(_vide(2))
	_fiche_box.add_child(actions)


## Part en avion : vers une destination lointaine depuis la Vienne, ou d'une destination lointaine vers
## une commune de la Vienne (Smarves par défaut). L'écran du vol couvre le changement de scène.
func voler(id := Communes.ORIGINE) -> void:
	var arrivee := Communes.commune(id)
	if arrivee == null or _vol.visible:
		return
	var loin := arrivee if arrivee.lointaine() else Communes.commune(Communes.actuelle())
	if loin == null or not loin.lointaine():
		return
	var aller := arrivee.lointaine()
	# Le paquet de la destination se lit pendant le vol (Chargement), l'écran du vol reste fluide.
	if arrivee.id != Communes.ORIGINE:
		Chargement.precharger(arrivee.id)
	_vol_titre.text = ("VOL POUR %s" % loin.ville() if aller else "VOL RETOUR").to_upper()
	_vol_ligne.text = ("Poitiers-Biard  →  %s" % loin.aeroport()) if aller else ("%s  →  Poitiers-Biard" % loin.aeroport())
	if loin.vol() != "":
		_vol_ligne.text += "\n" + loin.vol()
	_vol_trajet.set("aller", aller)
	_vol_trajet.set("avance", 0.0)
	_vol.visible = true
	_en_route = true
	var voile: ColorRect = _vol.get_child(0)
	voile.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(voile, "modulate:a", 1.0, 0.35)
	t.tween_property(_vol_trajet, "avance", 1.0, duree_vol).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	if _root.visible:
		_cacher()
	_en_route = false
	if arrivee.id == Communes.ORIGINE:
		Communes.revenir()
	elif not Communes.visiter(arrivee.id):
		Carnet.show_slip("%s ne s'ouvre pas : %s" % [arrivee.nom, Communes.refus[-1][1] if not Communes.refus.is_empty() else "scène introuvable"])
	var t2 := create_tween()
	t2.tween_property(voile, "modulate:a", 0.0, 0.5)
	await t2.finished
	_vol.visible = false


func _construire_vol() -> void:
	_vol = CanvasLayer.new()
	_vol.layer = 95
	_vol.visible = false
	add_child(_vol)
	var voile := ColorRect.new()
	voile.color = NUIT
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vol.add_child(voile)
	_vol_trajet = Trajet.new()
	_vol_trajet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vol_trajet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	voile.add_child(_vol_trajet)
	var boite := VBoxContainer.new()
	boite.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boite.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boite.offset_top = 90
	boite.alignment = BoxContainer.ALIGNMENT_CENTER
	boite.add_theme_constant_override("separation", 10)
	voile.add_child(boite)
	_vol_titre = _mot("", 15, Color(0.55, 0.75, 0.75))
	_vol_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boite.add_child(_vol_titre)
	_vol_ligne = _mot("", 30, Color.WHITE, Polices.titre())
	_vol_ligne.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boite.add_child(_vol_ligne)


## Le trajet du vol : un arc de tirets d'or au-dessus de l'océan, et l'avion qui le suit.
class Trajet extends Control:
	var avance := 0.0:
		set(v):
			avance = v
			queue_redraw()
	var aller := true

	func _draw() -> void:
		var a := Vector2(size.x * 0.16, size.y * 0.66)
		var b := Vector2(size.x * 0.84, size.y * 0.66)
		if not aller:
			var t := a
			a = b
			b = t
		var haut := size.y * 0.28
		var point := func(u: float) -> Vector2: return a.lerp(b, u) - Vector2(0, 4.0 * haut * u * (1.0 - u))
		var n := 48
		for i in n:
			if i % 2 == 0:
				draw_line(point.call(float(i) / n), point.call(float(i + 1) / n), Color(0.96, 0.8, 0.45, 0.35 if float(i) / n > avance else 0.9), 2.0, true)
		for p in [a, b]:
			draw_circle(p, 6.0, Color(0.96, 0.8, 0.45))
		# L'avion : un fuseau et deux ailes, tourné selon la pente de l'arc.
		var ici: Vector2 = point.call(avance)
		var dir: Vector2 = (point.call(minf(avance + 0.01, 1.0)) - point.call(maxf(avance - 0.01, 0.0))).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var blanc := Color(0.95, 0.96, 0.98)
		draw_colored_polygon(PackedVector2Array([ici + dir * 22, ici + nrm * 4 - dir * 16, ici - nrm * 4 - dir * 16]), blanc)
		draw_colored_polygon(PackedVector2Array([ici + dir * 4, ici + nrm * 20 - dir * 6, ici + nrm * 20 - dir * 10, ici - dir * 4]), blanc)
		draw_colored_polygon(PackedVector2Array([ici + dir * 4, ici - nrm * 20 - dir * 6, ici - nrm * 20 - dir * 10, ici - dir * 4]), blanc)
		draw_colored_polygon(PackedVector2Array([ici - dir * 12, ici + nrm * 8 - dir * 18, ici - nrm * 8 - dir * 18]), blanc)
		var f := Polices.texte()
		draw_string(f, a + Vector2(-60, 34), "Poitiers-Biard" if aller else "", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(0.65, 0.7, 0.75))
		draw_string(f, b + Vector2(-60, 34), "Poitiers-Biard" if not aller else "", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(0.65, 0.7, 0.75))


# --- L'écran ------------------------------------------------------------------------------------

func _construire() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var fond := TextureRect.new()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.texture = _fond()
	fond.stretch_mode = TextureRect.STRETCH_SCALE
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(fond)
	_carte = CarteVienne.new()
	_carte.interactive = true
	_carte.brume = true
	_carte.rivieres = true
	_carte.marge = 36.0
	_carte.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Une commune choisie garde sa fiche : en allant vers « Y aller », la souris passe sur d'autres
	# communes sans que la fiche change sous elle. Sans choix, la fiche suit le survol.
	_carte.survol.connect(func(i):
		if _carte.choisie != "":
			return
		_montrer(i if i != "" else _defaut()))
	_carte.choix.connect(func(i):
		# Sur la France, un clic descend d'un cran, sans fiche à valider : la confirmation n'a lieu
		# qu'au niveau des communes, avant le chargement.
		if _carte.niveau == "france" and i != "":
			_descendre(i)
			return
		_carte.choisie = i
		_carte.trajet = i if _carte.niveau == "departement" else ""
		_montrer(i if i != "" else _defaut()))
	_carte.recul.connect(vers_france)
	_carte.region_quittee.connect(func():
		_carte.choisie = ""
		_remplir_legende()
		_rafraichir(false)
		_montrer(_carte.departement))
	_carte.plongee.connect(func(i):
		if _carte.niveau == "france":
			if Departements.connu(i):
				vers_departement(i)
			elif i != "" and _carte.region == "":
				vers_region(France.region_de(i))
			return
		if i == "" or (i == _ici() and not _titre):
			fermer()
		elif Communes.par_insee(i) != null:
			aller(i))
	_root.add_child(_carte)

	# En haut à gauche, le titre et le compte des communes.
	var cartouche := PanelContainer.new()
	cartouche.add_theme_stylebox_override("panel", _boite(Color(0.04, 0.05, 0.08, 0.72), Color(0, 0, 0, 0), 10, 16))
	cartouche.position = Vector2(18, 14)
	cartouche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cartouche)
	var tete := VBoxContainer.new()
	tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tete.add_theme_constant_override("separation", 4)
	cartouche.add_child(tete)
	# Le fil d'Ariane : France › région › département, chaque cran cliquable pour y remonter.
	_ariane = HBoxContainer.new()
	_ariane.add_theme_constant_override("separation", 2)
	tete.add_child(_ariane)
	_sur_titre = _mot("", 13, Color(0.55, 0.75, 0.75))
	tete.add_child(_sur_titre)
	_grand_titre = _mot("", 34, Color.WHITE, Polices.titre())
	tete.add_child(_grand_titre)
	_compte = _mot("", 16, DOUX)
	tete.add_child(_compte)
	_legende = VBoxContainer.new()
	_legende.add_theme_constant_override("separation", 2)
	_legende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tete.add_child(_vide(10))
	tete.add_child(_legende)
	# Où aller : les villes ouvertes ou à installer, les plus proches d'abord, chacune cliquable.
	_ou_aller = VBoxContainer.new()
	_ou_aller.add_theme_constant_override("separation", 0)
	tete.add_child(_ou_aller)
	_remplir_legende()


	# En haut à droite, le retour.
	_retour = _bouton("", Color(0, 0, 0, 0), TEXTE, Color(1, 1, 1, 0.3), fermer, 17)
	_retour.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_retour.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_retour.offset_right = -28
	_retour.offset_left = -28
	_retour.offset_top = 26
	_root.add_child(_retour)

	# En bas à droite, la fiche de la commune survolée ou choisie.
	_fiche = PanelContainer.new()
	var st := _boite(Color(0.06, 0.08, 0.12, 0.92), Color(EAU, 0.35), 10, 20)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 18
	_fiche.add_theme_stylebox_override("panel", st)
	_fiche.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fiche.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fiche.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fiche.offset_right = -28
	_fiche.offset_bottom = -28
	_fiche.custom_minimum_size.x = 340
	# La fiche capte la souris : ce qu'elle couvre de la carte ne s'allume pas sous elle.
	_fiche.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_fiche)
	_fiche_box = VBoxContainer.new()
	_fiche_box.add_theme_constant_override("separation", 8)
	_fiche.add_child(_fiche_box)

	_aide = _mot("", 14, Color(0.55, 0.6, 0.66))
	_aide.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_aide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_aide.position = Vector2(32, -40)
	_root.add_child(_aide)

	_voile = ColorRect.new()
	_voile.color = Color(NUIT, 0.0)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_voile)


## La légende du niveau montré : les communes de la Vienne, ou les départements de la France.
func _remplir_legende() -> void:
	for c in _legende.get_children():
		c.queue_free()
	var lignes := [[Color(OR, 0.55), "la Vienne, votre département"], [Color(EAU, 0.3), "votre région, en car régional"], [Color(EAU, 0.6), "des villes dans le jeu"],
		[Color(1, 1, 1, 0.16), "pas encore dans le jeu"]] if _carte.niveau == "france" \
		else ([[OR, "votre commune"]] if _carte.departement == France.VIENNE else []) + [[EAU, "villes ouvertes"], [Color(EAU, 0.55), "villes à installer"]]
	if _carte.niveau == "departement" and _carte.departement == France.VIENNE:
		lignes.append([Color(0.78, 0.8, 0.84, 0.6), "Poitiers, dans la brume"])
	for l in lignes:
		var rang := HBoxContainer.new()
		rang.add_theme_constant_override("separation", 8)
		rang.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pastille := ColorRect.new()
		pastille.color = l[0]
		pastille.custom_minimum_size = Vector2(14, 14)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rang.add_child(pastille)
		rang.add_child(_mot(l[1], 15, DOUX))
		_legende.add_child(rang)


## Un fond de nuit, plus clair au milieu, comme une table éclairée par une lampe.
func _fond() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.1, 0.13, 0.18))
	g.set_color(1, Color(0.03, 0.04, 0.06))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.1, 1.1)
	t.width = 256
	t.height = 256
	return t


func _rafraichir(garder := true) -> void:
	_carte.publiees = Communes.publiees().map(func(e): return e.insee).filter(func(i): return i != "")
	_carte.installees = Communes.installees().map(func(id): return Communes.commune(id).insee).filter(func(i): return i != "")
	_carte.actifs = []
	for i in _allumees():
		var d := Departements.de(i)
		if d != France.VIENNE and not _carte.actifs.has(d):
			_carte.actifs.append(d)
	_carte.a_jour = {}
	for id in Communes.installees():
		if Communes.mise_a_jour(id) != "":
			_carte.a_jour[Communes.commune(id).insee] = Communes.mise_a_jour(id)
	_carte.queue_redraw()
	var ici := Communes.commune(Communes.actuelle())
	var france := _carte.niveau == "france"
	var region := France.region(_carte.region)
	var dep := France.departement(_carte.departement)
	if france:
		var n := 1 + _carte.actifs.size()
		_compte.text = ("%d département%s dans le jeu sur %d" % [n, "s" if n > 1 else "", France.departements().size()]) + (" : la Vienne" if n == 1 else "")
		if not region.is_empty():
			_compte.text = "%d départements  ·  %s" % [region.departements.size(), _moyen(str(region.departements[0]))]
	else:
		var ouvertes := villes_de(_carte.departement)
		var a_telecharger := Communes.publiees().filter(func(e): return Communes.commune(e.id) == null and Departements.de(str(e.insee)) == _carte.departement).size()
		var n := ouvertes.size() - a_telecharger
		_compte.text = ("%d ville%s ouverte%s" % [n, "s" if n > 1 else "", "s" if n > 1 else ""] if n > 0 else "Aucune ville ouverte") \
			+ ("  ·  %d à installer" % a_telecharger if a_telecharger > 0 else "") + "  ·  %d communes" % Departements.communes(_carte.departement).size()
	_sur_titre.visible = _mode == "car" and not france
	_sur_titre.text = "C A R   D É P A R T E M E N T A L"
	_grand_titre.text = ("Carte de France" if region.is_empty() else str(region.nom)) if france \
		else ("Arrêt de la Place, %s" % (ici.nom if ici else "Smarves")) if _mode == "car" else str(dep.get("nom", "Vienne"))
	_retour.text = "←  Revenir au menu" if _titre else "←  Revenir à %s" % (ici.nom if ici else "Smarves")
	if france:
		_aide.text = ("Pincer pour zoomer  ·  toucher une région, puis un département pour voir ses communes" if Tactile.active
			else "Molette pour zoomer  ·  cliquer une région, puis un département pour voir ses communes  ·  Échap ou M pour revenir")
	else:
		_aide.text = ("Pincer pour zoomer  ·  glisser pour déplacer  ·  toucher une commune  ·  écarter encore pour la France" if Tactile.active
			else "Molette pour zoomer  ·  glisser pour déplacer  ·  cliquer une commune  ·  dézoomer encore pour la France  ·  Échap ou M pour revenir")
	_remplir_ariane()
	_remplir_ou_aller()
	if garder:
		_montrer(_carte.choisie if _carte.choisie != "" else _defaut())


## La fiche montrée quand rien n'est désigné : sa commune, ou le département regardé.
func _defaut() -> String:
	if _carte.niveau == "france":
		return _carte.departement
	return _ici() if Departements.de(_ici()) == _carte.departement else ""


## Le fil d'Ariane : France › région › département, le dernier cran en blanc, les autres cliquables.
func _remplir_ariane() -> void:
	for c in _ariane.get_children():
		c.queue_free()
	var crans := [["France", vers_france]]
	var reg := _carte.region if _carte.niveau == "france" else France.region_de(_carte.departement)
	if reg != "":
		crans.append([str(France.region(reg).get("nom", "")), vers_region.bind(reg)])
	if _carte.niveau == "departement":
		crans.append([str(France.departement(_carte.departement).get("nom", "")), Callable()])
	for k in crans.size():
		if k > 0:
			_ariane.add_child(_mot("›", 15, DOUX))
		var dernier: bool = k == crans.size() - 1
		var b := _lien(crans[k][0], Color.WHITE if dernier else Color(0.55, 0.75, 0.75), crans[k][1] if not dernier else Callable())
		_ariane.add_child(b)


## Un mot cliquable, sans cadre (inerte sans action).
func _lien(t: String, encre: Color, action: Callable, taille := 15) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if action.is_valid() else Control.CURSOR_ARROW
	b.add_theme_font_override("font", Polices.gras())
	b.add_theme_font_size_override("font_size", taille)
	for c in ["font_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, encre)
	b.add_theme_color_override("font_hover_color", encre.lightened(0.3) if action.is_valid() else encre)
	var vide := StyleBoxEmpty.new()
	vide.content_margin_left = 4
	vide.content_margin_right = 4
	vide.content_margin_top = 2
	vide.content_margin_bottom = 2
	for e in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(e, vide)
	if action.is_valid():
		b.pressed.connect(action)
	return b


## « Où aller » : sur un département, ses villes dans le jeu, les plus proches d'abord (au car, ses
## arrêts) ; sur la France, les départements où il y a des villes, et les destinations lointaines.
func _remplir_ou_aller() -> void:
	for c in _ou_aller.get_children():
		c.queue_free()
	var rangs := []  # [couleur, nom, détail, action]
	if _carte.niveau == "departement":
		var villes := villes_de(_carte.departement).filter(func(i): return i != CarteVienne.POITIERS_INSEE)
		if _mode == "car":
			villes = villes.filter(func(i): return i == _ici() or desservies().has(i) or _carte.publiees.has(i))
		var dist := {}
		for i in villes:
			dist[i] = trajet(i)[0]
		villes.sort_custom(func(a, b): return dist[a] < dist[b])
		for i in villes:
			var etat := "vous êtes ici" if i == _ici() and not _titre and not _loin() else ("%d\u00a0km" % dist[i] if dist[i] > 0 else "")
			if Communes.par_insee(i) == null and i != CarteVienne.ORIGINE_INSEE:
				etat = (etat + "  ·  " if etat != "" else "") + "à installer"
			var couleur := OR if i == CarteVienne.ORIGINE_INSEE else EAU if Communes.par_insee(i) != null else Color(EAU, 0.55)
			rangs.append([couleur, str(Departements.commune(i).get("nom", "")), etat, _designer.bind(i)])
	else:
		for code in [France.VIENNE] + _carte.actifs:
			var n := villes_de(code).size()
			rangs.append([OR if code == France.VIENNE else EAU, str(France.departement(code).nom), "%d ville%s" % [n, "s" if n > 1 else ""], vers_departement.bind(code)])
		for id in Communes.lointaines():
			var c := Communes.commune(id)
			rangs.append([Color(0.8, 0.7, 1.0), c.nom, "%s  ·  en avion" % c.ville(), _vers_biard])
		for e in Communes.publiees():
			if str(e.insee) == "" and e.has("ailleurs") and Communes.commune(e.id) == null:
				rangs.append([Color(0.8, 0.7, 1.0, 0.55), str(e.nom), "%s  ·  en avion, à installer" % str(e.ailleurs.ville), _vers_biard])
	if rangs.is_empty():
		return
	_ou_aller.add_child(_vide(10))
	_ou_aller.add_child(_mot(("LES ARRÊTS DU CAR" if _mode == "car" and _carte.niveau == "departement" else "OÙ ALLER"), 12, Color(0.55, 0.75, 0.75), Polices.gras()))
	var max_rangs := 7
	for k in mini(rangs.size(), max_rangs):
		var r: Array = rangs[k]
		var rang := HBoxContainer.new()
		rang.add_theme_constant_override("separation", 6)
		var pastille := ColorRect.new()
		pastille.color = r[0]
		pastille.custom_minimum_size = Vector2(9, 9)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rang.add_child(pastille)
		rang.add_child(_lien(r[1], Color.WHITE, r[3], 16))
		rang.add_child(_mot(r[2], 14, DOUX))
		_ou_aller.add_child(rang)
	if rangs.size() > max_rangs:
		_ou_aller.add_child(_mot("et %d autres, sur la carte" % (rangs.size() - max_rangs), 14, DOUX))


## Désigne une ville de la liste : la carte s'en approche, sa fiche s'ouvre, le trajet se dessine.
func _designer(insee: String) -> void:
	_carte.choix.emit(insee)
	var de := _depart() if Departements.de(_depart()) == _carte.departement else Departements.chef_lieu(_carte.departement)
	_carte.aller_a((_carte.centre_de(de) + _carte.centre_de(insee)) / 2.0 if insee != de and Departements.de(de) == _carte.departement else _carte.centre_de(insee), 3.0, 0.7)


## Les destinations lointaines partent de Poitiers-Biard : on redescend dans la Vienne, sur sa fiche.
func _vers_biard() -> void:
	await vers_departement(France.VIENNE)
	_designer(CarteVienne.POITIERS_INSEE)


## La fiche d'une commune : ce qu'elle est pour le joueur, et ce qu'il peut y faire.
func _montrer(insee: String, alerte := "") -> void:
	for c in _fiche_box.get_children():
		c.queue_free()
	if _carte.niveau == "france":
		var code := insee if not France.departement(insee).is_empty() else _carte.departement
		# Sur la France entière, on désigne une région ; son propre département garde sa fiche.
		if _carte.region == "" and code != _carte.departement:
			_montrer_region(France.region_de(code))
		else:
			_montrer_departement(code)
		return
	if insee == "" and Departements.de(_ici()) != _carte.departement:
		_montrer_departement(_carte.departement)
		return
	if insee == "":
		insee = _ici()
	if insee == "" and _loin():
		_fiche_lointaine(Communes.actuelle())
		return
	var v := Departements.commune(insee)
	if v.is_empty():
		return
	var c := Communes.par_insee(insee)
	var e := {}
	for x in Communes.publiees():
		if x.insee == insee:
			e = x
	var ici := insee == _ici() and not _titre
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 10)
	tete.add_child(_mot(str(v.nom), 26, OR if insee == CarteVienne.ORIGINE_INSEE else Color.WHITE, Polices.titre()))
	if ici:
		tete.add_child(_mot("VOUS ÊTES ICI", 12, EAU, Polices.gras()))
	else:
		var id: String = c.id if c != null else str(e.get("id", ""))
		var marque: Array = {"publiee": ["NOUVELLE", EAU] if Communes.nouvelles.has(id) else [], "mise_a_jour": ["MISE À JOUR", OR],
			"a_relancer": ["À RELANCER", OR], "echec": ["ÉCHEC", ROUGE]}.get(Communes.etat(id), []) if id != "" else []
		if not marque.is_empty():
			tete.add_child(_mot(marque[0], 12, marque[1], Polices.gras()))
	_fiche_box.add_child(tete)
	var pop := int(v.get("population", 0))
	var etat := ""
	var texte := ""
	if insee == CarteVienne.ORIGINE_INSEE:
		etat = "Votre commune"
		texte = "Le Café de la Place, le casino, le Crédit Smarvois, la salle François-Rabelais et le Moulin des Dames."
	elif insee == CarteVienne.POITIERS_INSEE:
		etat = "Dans la brume"
		texte = "On n'y va pas. C'est là que partent ceux qui ne croient pas au jeu."
		if not Communes.lointaines().is_empty() or Communes.publiees().any(func(x): return str(x.insee) == ""):
			texte += "\n\nÀ sa lisière, l'aéroport de Poitiers-Biard a des vols pour plus loin que la Vienne."
	elif c != null or not e.is_empty():
		# L'état et ses mots sont ceux de la bienvenue et du carnet (Communes.etat, resume).
		var id: String = c.id if c != null else e.id
		etat = Communes.resume(id) if Communes.etat(id) in ["a_jour", "publiee"] else ("Installée" if c != null else "Publiée")
		if c != null and Communes.etat(id) != "a_jour" and str(c.data.get("version", "")) != "":
			etat += "  ·  version %s" % str(c.data.version)
		# L'auteur du manifeste, à côté de la version (« Publiée par » le dit déjà pour une ville à installer).
		if c != null and c.auteur() != "":
			etat += "  ·  par %s" % c.auteur()
		texte = str(e.get("description", c.data.get("description", "") if c != null else ""))
		if not Communes.etat(id) in ["a_jour", "publiee"]:
			texte += ("\n\n" if texte != "" else "") + Communes.resume(id)
	else:
		etat = "Pas encore développée"
		texte = ("La route continue jusqu'à %s, mais la ville n'est pas encore construite. " % v.nom if _mode == "route" else "Les développeurs construisent les villes sur le portail. ") \
			+ "Elle s'allumera ici le jour où elle sera publiée."
	_fiche_box.add_child(_mot(etat + ("  ·  %s\u00a0habitants" % Game.fmt(pop).replace(" ", "\u00a0") if pop > 0 and insee != CarteVienne.POITIERS_INSEE else ""), 15, DOUX, null, true))
	if _mode == "car" and not ici and insee != CarteVienne.POITIERS_INSEE:
		texte += ("\n\n" if texte != "" else "") + ("Le car s'y arrête." if desservies().has(insee) else "Le car ne s'y arrête pas encore.")
	if texte != "":
		_fiche_box.add_child(_mot(texte, 16, TEXTE, null, true))
	var trouve := _ce_qu_on_trouve(c.structures() if c != null else e.get("structures", []))
	if not trouve.is_empty() and insee != CarteVienne.ORIGINE_INSEE:
		_fiche_box.add_child(_mot("ON Y TROUVE", 12, Color(0.55, 0.75, 0.75), Polices.gras()))
		_fiche_box.add_child(_mot("\n".join(trouve), 15, TEXTE, null, true))
	var t := trajet(insee)
	if not ici and t[1] != "" and insee != CarteVienne.POITIERS_INSEE:
		_fiche_box.add_child(_mot("Trajet depuis %s  ·  %s" % [str(Departements.commune(_depart()).get("nom", "")), t[1]], 15, OR, null, true))
	if alerte != "":
		_fiche_box.add_child(_mot(alerte, 15, ROUGE, null, true))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	if ici:
		actions.add_child(_bouton("Revenir au village" if insee == CarteVienne.ORIGINE_INSEE else "Revenir à %s" % v.nom, OR if insee == CarteVienne.ORIGINE_INSEE else EAU, Color(0.08, 0.06, 0.03), Color(0, 0, 0, 0), fermer, 16))
		# L'arrêt de la salle de basket de la commune (scripts/village/salle_basket.gd), derrière son seuil.
		var ic := Communes.commune(Communes.actuelle())
		var id_ici: String = ic.id if ic else Communes.ORIGINE
		if _mode == "car" and SalleBasket.desservie(id_ici):
			var salle := SalleBasket.lieu_de(id_ici)
			var nom_salle := str(salle.get("name", "la salle de basket"))
			if SalleBasket.ouverte(id_ici):
				actions.add_child(_bouton("Descendre au %s  →" % nom_salle.trim_prefix("Le ") if nom_salle.begins_with("Le ") else "Descendre à %s  →" % nom_salle, EAU, Color(0.04, 0.1, 0.1), Color(0, 0, 0, 0), descendre_salle.bind(id_ici), 16))
			else:
				_fiche_box.add_child(_mot("%s : le car s'y arrêtera à %s crédits gagnés." % [nom_salle, Game.fmt(SalleBasket.seuil_de(id_ici))], 15, DOUX, null, true))
	elif c != null:
		actions.add_child(_bouton("Monter dans le car  →" if _mode == "car" else "Prendre la route  →" if _mode == "route" else (("Jouer à Smarves  →" if _titre else "Rentrer à Smarves  →") if c.id == Communes.ORIGINE else "Y aller  →"), OR if c.id == Communes.ORIGINE else EAU, Color(0.04, 0.1, 0.1), Color(0, 0, 0, 0), aller.bind(insee), 16))
		_geste(c.id, actions)
	elif not e.is_empty():
		_geste(e.id, actions)
	# Depuis le menu de départ aussi : on embarque pour une destination lointaine comme on va dans une commune.
	if insee == CarteVienne.POITIERS_INSEE:
		for id in Communes.lointaines():
			if id != Communes.actuelle():
				var vols := HBoxContainer.new()
				vols.add_theme_constant_override("separation", 10)
				vols.add_child(_bouton("Embarquer pour %s  →" % Communes.commune(id).ville(), OR, Color(0.08, 0.06, 0.03), Color(0, 0, 0, 0), voler.bind(id), 16))
				_fiche_box.add_child(vols)
		# Les destinations publiées sur le portail, pas encore installées : on les installe d'ici.
		for x in Communes.publiees():
			if str(x.insee) == "" and x.has("ailleurs") and Communes.commune(x.id) == null:
				var vol := HBoxContainer.new()
				vol.add_theme_constant_override("separation", 10)
				vol.add_child(_mot("Vol pour %s" % str(x.ailleurs.ville), 15, TEXTE))
				_geste(x.id, vol)
				_fiche_box.add_child(vol)
	if actions.get_child_count() > 0:
		_fiche_box.add_child(_vide(2))
		_fiche_box.add_child(actions)


const JEUX := {"machine": "machine à sous", "des": "dés", "roue": "roue de la fortune", "courses": "courses", "loto": "loto",
	"roulette": "roulette", "blackjack": "blackjack", "poker": "poker", "baccara": "baccara", "craps": "craps"}


## Ce qu'une ville déclare (Structures) en une ligne par lieu : ses salles de jeu et leurs jeux, son
## club, ses commerces ; quatre lignes au plus.
func _ce_qu_on_trouve(structures: Array) -> Array:
	var out := []
	for s in structures:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var nom := str(s.get("nom", ""))
		match str(s.get("type", "")):
			"salle_jeu":
				var jeux: Array = s.get("jeux", []).map(func(j): return JEUX.get(str(j), str(j)))
				out.append(nom + ("  ·  " + ", ".join(jeux) if not jeux.is_empty() else ""))
			"terrain_foot", "gymnase":
				out.append(str(s.get("club", nom)) + ("  ·  " + str(s.get("stade", "")) if str(s.get("stade", "")) != "" else ""))
			"commerce":
				out.append(nom)
	if out.size() > 4:
		var reste := out.size() - 3
		out = out.slice(0, 3)
		out.append("et %d autres lieux" % reste)
	return out


# --- Les pièces, comme celles de la bienvenue ---------------------------------------------------

func _boite(fond: Color, bord: Color, rayon := 6, marge := 12, epaisseur := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(epaisseur if bord.a > 0 else 0)
	s.set_corner_radius_all(rayon)
	s.set_content_margin_all(marge)
	return s


func _mot(t: String, taille: int, couleur: Color, police: Font = null, replie := false) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", police if police else Polices.texte())
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4 if not replie else 0)
	if replie:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 300
	return l


func _vide(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _bouton(t: String, fond: Color, encre: Color, bord: Color, action: Callable, taille := 17, actif := true) -> Button:
	var b := Button.new()
	b.text = t
	b.disabled = not actif
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Polices.gras())
	b.add_theme_font_size_override("font_size", taille)
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var f := fond
		if etat == "hover" or etat == "pressed":
			f = fond.lightened(0.12) if fond.a > 0 else Color(encre, 0.12)
		var s := _boite(f, bord if etat != "disabled" else Color(bord, bord.a * 0.4), 4, 10)
		s.content_margin_left = 20
		s.content_margin_right = 20
		b.add_theme_stylebox_override(etat, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, encre)
	b.add_theme_color_override("font_disabled_color", Color(encre, 0.4))
	b.pressed.connect(action)
	return b
