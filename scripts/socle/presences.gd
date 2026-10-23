extends Node
## Les autres joueurs dans le lieu où l'on est (autoload « Presences »), lot 1 de la fiche « se croiser »
## (dossier du projet multi/fiche-se-croiser.md). Un lieu est une scène : la place de Smarves, l'intérieur
## du casino. La scène dit qu'on y entre (entrer) ; si le joueur est connecté à son compte et n'a pas
## éteint « Voir les autres joueurs » dans les réglages, on s'inscrit au lieu par la base
## (public.smarves_lieu_entrer, supabase/migrations/20261019030000_smarves_presences.sql), qui rend le
## canal Realtime du lieu et la liste des présents, avec leur nom et leur tenue.
##
## Ensuite, deux voies, comme la nuit d'Addict :
## - les positions vont de joueur à joueur sur le canal (TempsReel), 3 fois par seconde quand on bouge
##   (1 quand le lieu a plus de 8 joueurs), une fois toutes les 10 s quand on ne bouge pas ; elles ne
##   passent pas par la base ;
## - la liste des présents se relit à chaque battement (toutes les 20 s), et tout de suite quand une
##   position arrive d'un inconnu. Une place sans battement depuis une minute expire.
##
## Chaque autre joueur est un figurant ordinaire (critter.gd), habillé de sa tenue (Cast.player), son nom
## au-dessus de la tête, qui glisse d'une position reçue à la suivante avec 300 ms de retard. Sans
## nouvelles depuis 60 s, il s'éclipse. Sans compte ou hors ligne, rien de tout cela ne s'ouvre et le
## lieu est celui d'un joueur seul.
##
## Socle 1.23, pour toutes les communes (lot 5 de la fiche, docs/COMMUNE.md, « Les autres joueurs ») :
## - une scène de commune (celle du manifeste, ses autres scènes, les scènes du socle ouvertes pour elle)
##   entre seule dans son lieu, sans une ligne de réseau dans la commune ;
## - la portée : on ne voit un autre joueur que s'il est à moins de `portee` de soi (60 unités par
##   défaut, réglable au manifeste) ; loin de tous, on n'envoie plus qu'une position par seconde ;
## - les zones : une grande scène se découpe en canaux par des aires (Area3D) nommées au manifeste ; on
##   change de canal en passant d'une aire à l'autre, après deux secondes dans la nouvelle ;
## - les messages : une commune diffuse ses propres événements aux joueurs de sa zone (envoyer) et
##   reçoit les leurs (signal message), pour un jeu à deux comme la galerie de Colaby ;
## - les salons : deux joueurs appariés passent sur un canal à eux (salon), où l'on ne voit que son
##   partenaire, à 10 positions par seconde ; chaque position porte aussi la direction du regard et un
##   petit état libre (etat_libre : la lampe, la clé portée) ;
## - les départs : un joueur qui s'en va le dit sur le canal ; on le voit encore 3 s à sa dernière place,
##   puis il s'éclipse (signaux arrive et parti).

const CRITTER := preload("res://scripts/critter.gd")
const TEMPS_REEL := preload("res://scripts/socle/temps_reel.gd")

const BATTEMENT := 20.0
const IMMOBILE := 10.0
const RETARD := 0.3
const ECLIPSE := 60.0
const RELIRE_MIN := 3.0
## La portée par défaut, en unités d'une scène à l'échelle 1 (1 unité = 2,4 m dans Smarves et ses
## communes), soit environ 150 m ; elle suit l'échelle des figurants (le casino, à 2,6). 0 : tout le lieu.
const PORTEE := 60.0
## Au-delà de la portée, l'autre se cache un peu plus loin qu'il n'apparaît, pour ne pas clignoter.
const MARGE := 1.1
## Loin de tous : au plus une position par seconde.
const CADENCE_LOIN := 1
## Le temps passé dans une autre zone avant d'en changer de canal.
const GRACE_ZONE := 2.0
const ZONES_MAX := 32
## Les messages d'une commune : leur nom, leur taille en JSON, leur débit (par seconde, en rafale).
const EVENEMENT := "^[a-z0-9_]{1,24}$"
const MESSAGE_MAX := 1024
const MESSAGES_PAR_SECONDE := 10.0
## Dans un salon : la cadence, et le petit état libre porté avec chaque position (en JSON).
const CADENCE_SALON := 10
const ETAT_MAX := 256
## Un joueur parti reste visible à sa dernière place, puis s'éclipse.
const DEPART := 3.0

## La liste des présents a changé (arrivée, départ) : [{membre, nom, tenue}].
signal presents_changes(presents: Array)
## Un autre joueur entre à portée de soi (oui) ou en sort.
signal a_portee(membre: String, nom: String, oui: bool)
## Un message d'une commune, diffusé par un autre joueur de la zone (envoyer).
signal message(membre: String, nom: String, evenement: String, donnees: Dictionary)
## On a changé de zone (de canal) dans la scène : l'id du lieu où l'on est maintenant.
signal zone_changee(lieu: String)
## Un autre joueur arrive dans le lieu (ou dans le salon), ou en part (son départ, la liste de la base,
## ou plus de nouvelles depuis 60 s).
signal arrive(membre: String, nom: String)
signal parti(membre: String, nom: String)
## L'état libre d'un autre joueur a changé.
signal etat_change(membre: String, etat: Dictionary)

## Pour les essais : pas de réseau, les vues et les positions arrivent à la main (appliquer_vue, recevoir).
var hors_ligne := false
## Pour les essais : ce qui serait parti sur le canal (les positions ; les messages à part).
var essai_envois: Array = []
var essai_messages: Array = []
## Pour les essais à deux clients : hors ligne pour la base, mais le canal donné par la vue est le vrai.
var essai_canal := false
## La portée de la scène ouverte (0 : tout le lieu).
var portee := PORTEE
## Le lieu de la scène hors de toute zone, et les zones : [{id, aires: [Node3D]}].
var lieu_scene := ""
var zones: Array = []
## Le salon où l'on est (« » : le canal de la zone, avec tous ses présents).
var salon_id := ""
## Un petit état libre, porté avec chaque position (la lampe, la clé portée, le geste en cours) : quelques
## champs, 256 octets en JSON au plus. Le changer l'envoie tout de suite.
var etat_libre := {}
## « » (pas de lieu), « entree » (inscription en cours), « present ».
var etat := ""
var commune := ""
var lieu := ""
var moi := ""
var cadence := 3
## {membre: {nom, tenue, noeud, points: [[t, pos, cap]], vu}}
var presents := {}

var _scene: Node3D
var _joueur: Node3D
var _echelle := 1.0
var _tr: Node
var _t := 0.0
var _battement := 0.0
var _relire_a := -100.0
var _envoi := 0.0
var _depuis_envoi := 0.0
var _envoye_pos := Vector3.INF
var _envoye_cap := 0.0
var _envoye_regard := Vector2.ZERO
var _envoye_etat := ""
var _canal_lieu := ""
var _masques := {}
var _actif_avant := false
## Monte à chaque sortie : une réponse d'avant (un autre lieu) ne s'applique plus.
var _gen := 0
## Sortir du lieu attend un peu : si la scène suivante entre dans un autre lieu, l'entrée suffit (une
## sortie arrivée après elle effacerait la nouvelle place).
var _sortir_dans := -1.0
var _zone_vise := ""
var _zone_depuis := 0.0
var _zone_lu := 0.0
var _jetons := MESSAGES_PAR_SECONDE


## Pour les captures (--presences-essai) : deux faux joueurs se promènent devant soi.
var _essai := false
var _essai_centre := Vector3.ZERO
var _essai_envoi := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--presences-essai" in OS.get_cmdline_user_args():
		_essai = true
		hors_ligne = true
	_tr = TEMPS_REEL.new()
	_tr.cle = Compte.CLE_PUBLIQUE
	_tr.recu.connect(_on_recu)
	add_child(_tr)
	get_tree().scene_changed.connect(_sur_scene)


## La scène d'un lieu y fait entrer le joueur : le corps qui le porte (sa position) et l'échelle des
## figurants de cette scène. Sans compte, la scène est retenue et rien ne part.
func entrer(id_commune: String, id_lieu: String, scene: Node3D, joueur: Node3D, echelle := 1.0) -> void:
	if _scene != null and _scene != scene:
		_quitter()
	commune = id_commune
	lieu = id_lieu
	_scene = scene
	_joueur = joueur
	_echelle = echelle
	# Une scène de commune garde ses réglages (portée, zones) : une scène gardée par Chargement et
	# rendue ensuite les retrouve.
	var cfg: Dictionary = scene.get_meta("presences", {})
	portee = float(cfg.get("portee", PORTEE * echelle))
	lieu_scene = id_lieu if cfg.is_empty() else str(cfg.get("lieu", id_lieu))
	zones = _zones_de(scene, cfg.get("zones", []))
	_zone_vise = ""
	_zone_depuis = 0.0
	if not scene.tree_exiting.is_connected(_on_scene_quittee):
		scene.tree_exiting.connect(_on_scene_quittee.bind(scene))
	_actif_avant = actif()
	if _essai:
		_mise_en_scene()
	elif _actif_avant:
		_inscrire()


## Vrai si l'on montre les autres : un compte connecté et le réglage allumé (ou les essais).
func actif() -> bool:
	if hors_ligne:
		return true
	var reglage = Settings.get("voir_joueurs")
	return Compte.connecte() and reglage != false


## Cache un joueur par son nom (assis à une table où la scène le montre déjà), ou le remontre.
func masquer(nom: String, oui := true) -> void:
	if oui:
		_masques[nom] = true
	else:
		_masques.erase(nom)
	for m in presents:
		var p: Dictionary = presents[m]
		if p.nom == nom and is_instance_valid(p.get("noeud")):
			p.noeud.visible = not oui


## La tenue d'un présent, par son nom ; « » s'il n'est pas là.
func tenue_de(nom: String) -> String:
	for m in presents:
		if presents[m].nom == nom:
			return presents[m].tenue
	return ""


func _inscrire() -> void:
	if hors_ligne or etat == "entree":
		return
	etat = "entree"
	_sortir_dans = -1.0
	var g := _gen
	var r: Dictionary = await Compte.appeler("smarves_lieu_entrer",
		{"p_commune": commune, "p_lieu": lieu, "p_tenue": _tenue()})
	if g != _gen or etat != "entree":
		return
	etat = ""
	if r.code == 200 and r.corps is Dictionary and r.corps.has("canal"):
		appliquer_vue(r.corps)
	else:
		print_verbose("Presences : pas d'inscription (%d)" % r.code)
		_battement = BATTEMENT


## La tenue et les retouches (Avatar.mot) : un mot [a-z0-9_]{0,40}, comme le veut la base.
func _tenue() -> String:
	return str(Biens.apparence())


## Une vue de la base : {canal, moi, cadence, presents}, ou {sorti: true}.
func appliquer_vue(v: Dictionary) -> void:
	if v.get("sorti", false):
		etat = ""
		_tr.fermer()
		_inscrire()
		return
	etat = "present"
	moi = str(v.get("moi", ""))
	cadence = clampi(int(v.get("cadence", 3)), 1, 5)
	_battement = BATTEMENT
	_canal_lieu = str(v.get("canal", ""))
	if not hors_ligne or essai_canal:
		_tr.ouvrir(_canal())
	var vus := {}
	var liste: Array = v.get("presents", [])
	for x in liste:
		if not x is Dictionary or str(x.get("membre", "")) == "" or x.membre == moi:
			continue
		vus[x.membre] = true
		if not presents.has(x.membre):
			presents[x.membre] = {"nom": str(x.get("nom", "")), "tenue": str(x.get("tenue", "")), "noeud": null,
				"points": [], "vu": -1000.0, "a_portee": false, "part": -1.0, "etat": {}}
			# Un nouveau venu ne sait pas encore où l'on est : on le lui dit tout de suite.
			_envoi = 0.0
			_depuis_envoi = IMMOBILE
			if salon_id == "":
				arrive.emit(x.membre, presents[x.membre].nom)
		else:
			var p: Dictionary = presents[x.membre]
			if p.get("hors_liste", false):
				p.hors_liste = false
				p.part = -1.0
				arrive.emit(x.membre, p.nom)
			if p.tenue != str(x.get("tenue", "")):
				p.tenue = str(x.get("tenue", ""))
				_effacer_noeud(p)
	for m in presents.keys():
		if not vus.has(m):
			presents[m].hors_liste = true
			_depart(m)
	presents_changes.emit(liste)


## Le canal où l'on est : celui du lieu, ou celui du salon, qui en dérive (son nom garde le secret du lieu).
func _canal() -> String:
	return _canal_lieu + (":salon:" + salon_id if salon_id != "" and _canal_lieu != "" else "")


## Passe dans un salon (« » pour revenir au lieu) : un canal à part, que seuls ceux qui y entrent sous le
## même nom partagent. On n'y voit que ceux qui y sont, à 10 positions par seconde. Faux si l'id est refusé
## ([a-z0-9_]{0,40}). Le nom vient d'un appariement : celui que font deux joueurs, ou plus tard le serveur.
func salon(id: String) -> bool:
	if id != "" and not _nom_salon(id):
		return false
	if id == salon_id:
		return true
	_dire_au_revoir()
	salon_id = id
	for m in presents:
		var p: Dictionary = presents[m]
		if p.a_portee:
			a_portee.emit(m, p.nom, false)
		p.a_portee = false
		p.points.clear()
		p.part = -1.0
		_effacer_noeud(p)
	_envoye_pos = Vector3.INF
	_envoi = 0.0
	if etat == "present" and (not hors_ligne or essai_canal):
		_tr.ouvrir(_canal())
	return true


static var _re_salon: RegEx


static func _nom_salon(id: String) -> bool:
	if _re_salon == null:
		_re_salon = RegEx.create_from_string("^[a-z0-9_]{1,40}$")
	return _re_salon.search(id) != null


## On s'en va : les autres du canal le savent tout de suite.
func _dire_au_revoir() -> void:
	if etat == "present" and moi != "" and (not hors_ligne or essai_canal):
		_tr.envoyer("bye", {"m": moi})


## Un joueur s'en va : on le voit encore DEPART secondes à sa dernière place, puis il s'éclipse.
func _depart(m: String) -> void:
	var p: Dictionary = presents.get(m, {})
	if p.is_empty() or p.part >= 0.0:
		return
	p.part = _t
	parti.emit(m, p.nom)


## Où en est un autre joueur, tel qu'on le voit (avec le retard de l'interpolation) : {position, cap,
## regard (lacet, tangage), etat, noeud} ; {} s'il n'est pas à portée.
func etat_de(membre: String) -> Dictionary:
	var p: Dictionary = presents.get(membre, {})
	if p.is_empty() or not p.a_portee or not is_instance_valid(p.noeud):
		return {}
	return {"position": p.noeud.global_position, "cap": p.noeud.rotation.y, "regard": p.get("regard_vu", Vector2.ZERO),
		"etat": p.etat, "noeud": p.noeud}


## Une position reçue d'un autre : {m, x, y, z, a}.
func recevoir(d: Dictionary) -> void:
	var m := str(d.get("m", ""))
	if m == "" or m == moi:
		return
	if not presents.has(m):
		# Un nouveau venu entre deux battements : la base dira qui c'est.
		if _t - _relire_a >= RELIRE_MIN:
			_relire_a = _t
			_battement = 0.0
		return
	var p: Dictionary = presents[m]
	var pos := Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))
	var r = d.get("r", [])
	var regard := Vector2(float(r[0]), float(r[1])) if r is Array and r.size() == 2 else Vector2(float(d.get("a", 0.0)), 0.0)
	p.points.append([_t, pos, float(d.get("a", 0.0)), regard])
	if p.points.size() > 12:
		p.points.pop_front()
	p.vu = _t
	if p.part >= 0.0 or (salon_id != "" and p.points.size() == 1):
		p.part = -1.0
		arrive.emit(m, p.nom)
	var e = d.get("e", {})
	if e is Dictionary and e != p.etat:
		p.etat = e
		etat_change.emit(m, e)


func _on_recu(evenement: String, d: Dictionary) -> void:
	if evenement == "pos":
		recevoir(d)
	elif evenement == "bye":
		_depart(str(d.get("m", "")))
	elif evenement.begins_with("c_"):
		recevoir_message(evenement.substr(2), d)


## Un message de commune reçu : {m, d}. Seulement d'un présent connu de la base.
func recevoir_message(evenement: String, d: Dictionary) -> void:
	var m := str(d.get("m", ""))
	if m == "" or m == moi or not presents.has(m) or not _nom_valable(evenement):
		return
	var donnees = d.get("d", {})
	if donnees is Dictionary:
		message.emit(m, presents[m].nom, evenement, donnees)


static var _re_evenement: RegEx


static func _nom_valable(evenement: String) -> bool:
	if _re_evenement == null:
		_re_evenement = RegEx.create_from_string(EVENEMENT)
	return _re_evenement.search(evenement) != null


## Diffuse un message de la commune aux autres joueurs de la zone (pas à soi) : un nom court
## ([a-z0-9_]{1,24}), des données en JSON d'au plus 1 Ko, dix par seconde au plus. Faux s'il n'est pas
## parti (pas de canal, nom ou taille refusés, débit dépassé). Comme les positions, ces messages ne sont
## ni signés ni vérifiés : rien de ce qui vaut de l'argent ne doit en dépendre.
func envoyer(evenement: String, donnees := {}) -> bool:
	if etat != "present" or not _nom_valable(evenement):
		return false
	if JSON.stringify(donnees).to_utf8_buffer().size() > MESSAGE_MAX:
		push_warning("Presences.envoyer : « %s » dépasse %d octets" % [evenement, MESSAGE_MAX])
		return false
	if _jetons < 1.0:
		return false
	_jetons -= 1.0
	var corps := {"m": moi, "d": donnees}
	if hors_ligne:
		essai_messages.append([evenement, donnees])
		if not essai_canal:
			return true
	return _tr.envoyer("c_" + evenement, corps)


## Les autres joueurs à portée dont on connaît la position : [{membre, nom, tenue, position, distance}],
## du plus proche au plus loin.
func autour() -> Array:
	var out := []
	for m in presents:
		var p: Dictionary = presents[m]
		if p.a_portee and not p.points.is_empty():
			var pos: Vector3 = p.points[-1][1]
			out.append({"membre": m, "nom": p.nom, "tenue": p.tenue, "position": pos, "distance": _distance(pos)})
	out.sort_custom(func(a, b): return a.distance < b.distance)
	return out


func _process(delta: float) -> void:
	_t += delta
	if _sortir_dans > 0.0:
		_sortir_dans -= delta
		if _sortir_dans <= 0.0 and etat == "" and Compte.connecte():
			Compte.appeler("smarves_lieu_sortir", {})
	if _scene == null:
		return
	var a := actif()
	if a != _actif_avant:
		_actif_avant = a
		if a:
			_inscrire()
		else:
			_quitter(false)
			return
	if etat != "present":
		_suivre_zone(delta)
		if a and etat == "" and not hors_ligne:
			_battement -= delta
			if _battement <= 0.0:
				_inscrire()
		return
	_battement -= delta
	if _battement <= 0.0 and not hors_ligne:
		_battre()
	_jetons = minf(_jetons + delta * MESSAGES_PAR_SECONDE, MESSAGES_PAR_SECONDE)
	_suivre_zone(delta)
	if etat != "present":
		return
	_envoyer(delta)
	if _essai:
		_promener(delta)
	for m in presents.keys():
		_placer(m)
		if presents[m].part >= 0.0 and _t - presents[m].part > DEPART:
			if presents[m].a_portee:
				a_portee.emit(m, presents[m].nom, false)
			_effacer_noeud(presents[m])
			if presents[m].get("hors_liste", false):
				presents.erase(m)
			else:
				# Parti du canal mais encore dans la liste (un salon, une coupure) : il revient à sa prochaine position.
				presents[m].points.clear()
				presents[m].a_portee = false
				presents[m].part = -1.0


# --- Les communes : entrer seul, les zones -------------------------------------------------------

## Une scène vient d'être ouverte. Si c'est une scène de commune (Communes.actuelle) qui n'est pas
## entrée d'elle-même dans un lieu, le socle l'y fait entrer : son habitant est `player`, ou le premier
## nœud du groupe « player ».
func _sur_scene() -> void:
	await get_tree().process_frame
	var s := get_tree().current_scene
	if s == null or s == _scene or not s is Node3D:
		return
	var communes := get_node_or_null("/root/Communes")
	if communes == null:
		return
	var id: String = communes.actuelle()
	if id == "" or id == communes.ORIGINE or not communes.communes.has(id):
		return
	entrer_commune(id, s, communes.communes[id].data)


## Fait entrer le joueur dans le lieu d'une scène de commune, d'après le champ « presences » du
## manifeste (docs/COMMUNE.md, « Les autres joueurs »). Faux si la scène n'a pas d'habitant.
func entrer_commune(id: String, scene: Node3D, manifeste: Dictionary) -> bool:
	var joueur = scene.get("player")
	if not joueur is Node3D:
		joueur = null
		for n in get_tree().get_nodes_in_group("player"):
			if n is Node3D and scene.is_ancestor_of(n):
				joueur = n
				break
	if joueur == null:
		return false
	var cfg: Dictionary = manifeste.get("presences", {}) if manifeste.get("presences") is Dictionary else {}
	var lieu_id := lieu_de_scene(scene)
	var echelle := float(cfg.get("echelle", 0.0))
	if echelle <= 0.0:
		var consts: Dictionary = scene.get_script().get_script_constant_map() if scene.get_script() else {}
		echelle = float(consts.get("PEOPLE_SCALE", 1.0))
	scene.set_meta("presences", {"lieu": lieu_id, "portee": float(cfg.get("portee", PORTEE * echelle)), "zones": cfg.get("zones", [])})
	# On entre tout de suite dans la zone où l'on se tient.
	var z := _zones_de(scene, cfg.get("zones", []))
	var depart := _zone_ou(z, joueur.global_position)
	entrer(id, depart if depart != "" else lieu_id, scene, joueur, echelle)
	return true


## Le lieu d'une scène, hors zones : l'id de la structure pour une scène du socle ouverte pour une
## commune (sa salle de jeu, son commerce), le nom du fichier de la scène sinon (« commune »).
static func lieu_de_scene(scene: Node) -> String:
	var st = scene.get("structure")
	var brut := str(st.get("id", "")) if st is Dictionary else ""
	if brut == "":
		brut = scene.scene_file_path.get_file().get_basename()
	if brut == "":
		brut = str(scene.name)
	var out := ""
	for c in brut.to_lower():
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	return out.left(40) if out != "" else "scene"


## Les zones déclarées, avec leurs aires trouvées dans la scène : [{id, aires: [Node3D]}]. Une zone dont
## aucune aire n'est dans cette scène est laissée de côté (elle est d'une autre scène de la commune).
func _zones_de(scene: Node, decl) -> Array:
	var out := []
	if not decl is Array:
		return out
	for z in decl:
		if not z is Dictionary:
			continue
		var noms = z.get("aire", [])
		if noms is String:
			noms = [noms]
		var aires := []
		for n in noms:
			var a := scene.find_child(str(n), true, false)
			if a is Node3D:
				aires.append(a)
		if not aires.is_empty():
			out.append({"id": str(z.get("id", "")), "aires": aires})
	return out


## La zone où se trouve une position : la première dont une aire la contient, « » sinon.
static func _zone_ou(z: Array, pos: Vector3) -> String:
	for zone in z:
		for a in zone.aires:
			if is_instance_valid(a) and dans_aire(a, pos):
				return zone.id
	return ""


## Vrai si la position est dans l'une des formes (CollisionShape3D) de l'aire : boîte, sphère, cylindre,
## capsule ; une autre forme compte par sa boîte englobante.
static func dans_aire(aire: Node3D, pos: Vector3) -> bool:
	for c in aire.find_children("*", "CollisionShape3D", true, false):
		var forme: Shape3D = c.shape
		if forme == null or c.disabled:
			continue
		var p: Vector3 = c.global_transform.affine_inverse() * pos
		if forme is BoxShape3D:
			var h: Vector3 = forme.size * 0.5
			if absf(p.x) <= h.x and absf(p.y) <= h.y and absf(p.z) <= h.z:
				return true
		elif forme is SphereShape3D:
			if p.length() <= forme.radius:
				return true
		elif forme is CylinderShape3D or forme is CapsuleShape3D:
			if Vector2(p.x, p.z).length() <= forme.radius and absf(p.y) <= forme.height * 0.5:
				return true
		elif forme.get_debug_mesh() and forme.get_debug_mesh().get_aabb().has_point(p):
			return true
	return false


## Suit le joueur d'une zone à l'autre : deux secondes dans une nouvelle zone, et l'on change de canal.
func _suivre_zone(delta: float) -> void:
	if zones.is_empty() or not is_instance_valid(_joueur):
		return
	_zone_lu -= delta
	if _zone_lu > 0.0:
		return
	_zone_lu = 0.25
	var z := _zone_ou(zones, _joueur.global_position)
	var cible := z if z != "" else lieu_scene
	if cible == lieu:
		_zone_vise = ""
		return
	if cible != _zone_vise:
		_zone_vise = cible
		_zone_depuis = 0.0
		return
	_zone_depuis += 0.25
	if _zone_depuis >= GRACE_ZONE:
		_basculer(cible)


## Change de lieu sans quitter la scène : on rentre dans le nouveau (la base efface l'ancienne place).
func _basculer(nouveau: String) -> void:
	_dire_au_revoir()
	salon_id = ""
	_zone_vise = ""
	_gen += 1
	_tr.fermer()
	for m in presents:
		if presents[m].a_portee:
			a_portee.emit(m, presents[m].nom, false)
		_effacer_noeud(presents[m])
	presents.clear()
	_envoye_pos = Vector3.INF
	etat = ""
	lieu = nouveau
	zone_changee.emit(nouveau)
	if _essai:
		_mise_en_scene()
	elif actif():
		_inscrire()


func _battre() -> void:
	_battement = BATTEMENT
	var g := _gen
	var r: Dictionary = await Compte.appeler("smarves_lieu_battement", {})
	if g != _gen or etat != "present":
		return
	if r.code == 200 and r.corps is Dictionary and (r.corps.has("canal") or r.corps.has("sorti")):
		appliquer_vue(r.corps)


## Ce que le joueur envoie de lui : sa position et le cap de sa silhouette (elle regarde +Z).
func ma_position() -> Array:
	if not is_instance_valid(_joueur):
		return []
	var av = _joueur.get("avatar")
	var cap: float = av.global_rotation.y if av is Node3D and is_instance_valid(av) else _joueur.global_rotation.y + PI
	return [_joueur.global_position, wrapf(cap, -PI, PI)]


func _envoyer(delta: float) -> void:
	_envoi -= delta
	_depuis_envoi += delta
	if _envoi > 0.0:
		return
	var mp := ma_position()
	if mp.is_empty():
		return
	var regard := mon_regard()
	var etat_texte := JSON.stringify(etat_libre) if not etat_libre.is_empty() else ""
	if etat_texte.to_utf8_buffer().size() > ETAT_MAX:
		push_warning("Presences.etat_libre dépasse %d octets : il ne part pas" % ETAT_MAX)
		etat_texte = _envoye_etat
	var bouge: bool = _envoye_pos == Vector3.INF or mp[0].distance_to(_envoye_pos) > 0.05 * _echelle \
		or absf(angle_difference(mp[1], _envoye_cap)) > 0.08 \
		or absf(angle_difference(regard.x, _envoye_regard.x)) > 0.06 or absf(regard.y - _envoye_regard.y) > 0.06 \
		or etat_texte != _envoye_etat
	if not bouge and _depuis_envoi < IMMOBILE:
		return
	var donnees := {"m": moi, "x": snappedf(mp[0].x, 0.01), "y": snappedf(mp[0].y, 0.01),
		"z": snappedf(mp[0].z, 0.01), "a": snappedf(mp[1], 0.01), "r": [snappedf(regard.x, 0.01), snappedf(regard.y, 0.01)]}
	if etat_texte != "":
		donnees.e = JSON.parse_string(etat_texte)
	if hors_ligne:
		essai_envois.append(donnees)
	if (hors_ligne and not essai_canal) or _tr.envoyer("pos", donnees):
		_envoye_pos = mp[0]
		_envoye_cap = mp[1]
		_envoye_regard = regard
		_envoye_etat = etat_texte
		_depuis_envoi = 0.0
		if salon_id != "":
			_envoi = 1.0 / CADENCE_SALON
		else:
			_envoi = 1.0 / (cadence if _quelqu_un_pres() else mini(cadence, CADENCE_LOIN))


## Où regarde le joueur : (lacet, tangage) de sa caméra à la première personne, la direction de sa
## silhouette sinon (vue de dessus).
func mon_regard() -> Vector2:
	if not is_instance_valid(_joueur):
		return Vector2.ZERO
	var cam = _joueur.get("camera")
	if cam is Camera3D and is_instance_valid(cam) and cam.current:
		# La caméra regarde -Z, la silhouette +Z : le même repère que le cap.
		return Vector2(wrapf(cam.global_rotation.y + PI, -PI, PI), cam.global_rotation.x)
	var mp := ma_position()
	return Vector2(mp[1], 0.0) if not mp.is_empty() else Vector2.ZERO


## Quelqu'un est assez près pour qu'on lui doive la pleine cadence : à portée, ou pas loin d'y entrer,
## ou pas encore situé (il vient d'arriver).
func _quelqu_un_pres() -> bool:
	if portee <= 0.0:
		return not presents.is_empty()
	for m in presents:
		var p: Dictionary = presents[m]
		if p.points.is_empty() or _distance(p.points[-1][1]) <= portee * 1.5:
			return true
	return false


## La distance au sol entre soi et une position de la scène.
func _distance(pos: Vector3) -> float:
	if not is_instance_valid(_joueur):
		return INF
	var d := pos - _joueur.global_position
	d.y = 0.0
	return d.length()


## La silhouette d'un présent, là où ses positions la mettent, 300 ms en arrière.
func _placer(m: String) -> void:
	var p: Dictionary = presents[m]
	if p.points.is_empty():
		return
	if _t - p.vu > ECLIPSE:
		_effacer_noeud(p)
		p.points.clear()
		_portee_de(m, false)
		parti.emit(m, p.nom)
		return
	var d := _distance(p.points[-1][1])
	_portee_de(m, portee <= 0.0 or d <= portee or (p.a_portee and d <= portee * MARGE))
	if not p.a_portee:
		if is_instance_valid(p.noeud):
			p.noeud.visible = false
		return
	if not is_instance_valid(p.noeud):
		p.noeud = _silhouette(p)
	p.noeud.visible = not _masques.has(p.nom)
	var pts: Array = p.points
	# Le retard suit la cadence de l'autre : 300 ms à 3 positions par seconde, 150 ms à 10.
	var retard := RETARD
	if pts.size() >= 3:
		retard = clampf(1.5 * (pts[-1][0] - pts[0][0]) / (pts.size() - 1), 0.15, RETARD)
	var quand := _t - retard
	var pos: Vector3 = pts[0][1]
	var cap: float = pts[0][2]
	var regard: Vector2 = pts[0][3]
	if quand >= pts[-1][0]:
		pos = pts[-1][1]
		cap = pts[-1][2]
		regard = pts[-1][3]
	else:
		for i in range(pts.size() - 1, 0, -1):
			if quand >= pts[i - 1][0]:
				var k := inverse_lerp(pts[i - 1][0], pts[i][0], quand)
				pos = pts[i - 1][1].lerp(pts[i][1], k)
				cap = lerp_angle(pts[i - 1][2], pts[i][2], k)
				regard = Vector2(lerp_angle(pts[i - 1][3].x, pts[i][3].x, k), lerpf(pts[i - 1][3].y, pts[i][3].y, k))
				break
	p.noeud.global_position = pos
	p.noeud.rotation.y = cap
	p.regard_vu = regard


func _portee_de(m: String, oui: bool) -> void:
	var p: Dictionary = presents[m]
	if p.a_portee == oui:
		return
	p.a_portee = oui
	a_portee.emit(m, p.nom, oui)


func _silhouette(p: Dictionary) -> Node3D:
	var c: Node3D = CRITTER.new()
	c.look = Cast.player(p.tenue if p.tenue != "" else "costume")
	c.name = "Joueur_" + str(p.nom).validate_node_name()
	c.scale = Vector3.ONE * _echelle
	c.walk_speed = 1.0
	c.run_speed = 1.9
	var nom := Label3D.new()
	nom.text = p.nom
	nom.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nom.fixed_size = true
	nom.pixel_size = 0.0008
	nom.font_size = 18
	nom.outline_size = 5
	nom.modulate = Color("#f4f1ea")
	nom.outline_modulate = Color("#16151b")
	nom.position = Vector3(0, 0.88, 0)
	c.add_child(nom)
	_scene.add_child(c)
	c.visible = not _masques.has(p.nom)
	return c


## Le jeu se ferme : on dit au revoir, pour que l'autre soit libéré tout de suite.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_dire_au_revoir()


func _effacer_noeud(p: Dictionary) -> void:
	if is_instance_valid(p.get("noeud")):
		p.noeud.queue_free()
	p.noeud = null


func _on_scene_quittee(scene: Node3D) -> void:
	if scene == _scene:
		_quitter()
		_scene = null
		_joueur = null


func _quitter(oublier := true) -> void:
	_dire_au_revoir()
	salon_id = ""
	if etat != "" and not hors_ligne:
		_sortir_dans = 1.5
	_gen += 1
	etat = ""
	_tr.fermer()
	for m in presents:
		if presents[m].a_portee:
			a_portee.emit(m, presents[m].nom, false)
		_effacer_noeud(presents[m])
	presents.clear()
	_envoye_pos = Vector3.INF
	moi = ""
	if oublier:
		_masques.clear()


# --- Les captures ----------------------------------------------------------------------------

func _mise_en_scene() -> void:
	appliquer_vue({"canal": "essai", "moi": "moi", "cadence": 3, "presents": [
		{"membre": "essai1", "nom": "Paulette", "tenue": "smoking"},
		{"membre": "essai2", "nom": "Bastien", "tenue": "dimanche"}]})
	var mp := ma_position()
	if mp.is_empty():
		return
	# Devant soi, à quelques pas : le joueur regarde -Z de son corps.
	var devant: Vector3 = -_joueur.global_basis.z
	devant.y = 0.0
	_essai_centre = mp[0] + devant.normalized() * 2.2 * _echelle
	_essai_envoi = 0.0
	_promener(0.0)
	for m in presents:
		presents[m].points[0][0] -= 1.0


func _promener(delta: float) -> void:
	_essai_envoi -= delta
	if _essai_envoi > 0.0:
		return
	_essai_envoi = 1.0 / 3.0
	var k := 0
	for m in presents:
		var a := _t * 0.25 + k * PI
		var r := (0.5 + 0.3 * k) * _echelle
		var pos := _essai_centre + Vector3(cos(a) * r, 0.0, sin(a) * r)
		recevoir({"m": m, "x": pos.x, "y": pos.y, "z": pos.z, "a": -a})
		k += 1
