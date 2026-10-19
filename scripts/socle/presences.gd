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

const CRITTER := preload("res://scripts/critter.gd")
const TEMPS_REEL := preload("res://scripts/socle/temps_reel.gd")

const BATTEMENT := 20.0
const IMMOBILE := 10.0
const RETARD := 0.3
const ECLIPSE := 60.0
const RELIRE_MIN := 3.0

## La liste des présents a changé (arrivée, départ) : [{membre, nom, tenue}].
signal presents_changes(presents: Array)

## Pour les essais : pas de réseau, les vues et les positions arrivent à la main (appliquer_vue, recevoir).
var hors_ligne := false
## Pour les essais : ce qui serait parti sur le canal.
var essai_envois: Array = []
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
var _masques := {}
var _actif_avant := false
## Monte à chaque sortie : une réponse d'avant (un autre lieu) ne s'applique plus.
var _gen := 0
## Sortir du lieu attend un peu : si la scène suivante entre dans un autre lieu, l'entrée suffit (une
## sortie arrivée après elle effacerait la nouvelle place).
var _sortir_dans := -1.0


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


func _tenue() -> String:
	var t: String = str(Biens.worn)
	return t if t.length() <= 40 and t.is_valid_ascii_identifier() and t == t.to_lower() else ""


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
	if not hors_ligne:
		_tr.ouvrir(str(v.get("canal", "")))
	var vus := {}
	var liste: Array = v.get("presents", [])
	for x in liste:
		if not x is Dictionary or str(x.get("membre", "")) == "" or x.membre == moi:
			continue
		vus[x.membre] = true
		if not presents.has(x.membre):
			presents[x.membre] = {"nom": str(x.get("nom", "")), "tenue": str(x.get("tenue", "")), "noeud": null,
				"points": [], "vu": -1000.0}
		else:
			var p: Dictionary = presents[x.membre]
			if p.tenue != str(x.get("tenue", "")):
				p.tenue = str(x.get("tenue", ""))
				_effacer_noeud(p)
	for m in presents.keys():
		if not vus.has(m):
			_effacer_noeud(presents[m])
			presents.erase(m)
	presents_changes.emit(liste)


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
	p.points.append([_t, pos, float(d.get("a", 0.0))])
	if p.points.size() > 8:
		p.points.pop_front()
	p.vu = _t


func _on_recu(evenement: String, d: Dictionary) -> void:
	if evenement == "pos":
		recevoir(d)


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
		if a and etat == "" and not hors_ligne:
			_battement -= delta
			if _battement <= 0.0:
				_inscrire()
		return
	_battement -= delta
	if _battement <= 0.0 and not hors_ligne:
		_battre()
	_envoyer(delta)
	if _essai:
		_promener(delta)
	for m in presents:
		_placer(presents[m])


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
	var bouge: bool = _envoye_pos == Vector3.INF or mp[0].distance_to(_envoye_pos) > 0.05 * _echelle \
		or absf(angle_difference(mp[1], _envoye_cap)) > 0.08
	if not bouge and _depuis_envoi < IMMOBILE:
		return
	var donnees := {"m": moi, "x": snappedf(mp[0].x, 0.01), "y": snappedf(mp[0].y, 0.01),
		"z": snappedf(mp[0].z, 0.01), "a": snappedf(mp[1], 0.01)}
	if hors_ligne:
		essai_envois.append(donnees)
	if hors_ligne or _tr.envoyer("pos", donnees):
		_envoye_pos = mp[0]
		_envoye_cap = mp[1]
		_depuis_envoi = 0.0
		_envoi = 1.0 / cadence


## La silhouette d'un présent, là où ses positions la mettent, 300 ms en arrière.
func _placer(p: Dictionary) -> void:
	if p.points.is_empty():
		return
	if _t - p.vu > ECLIPSE:
		_effacer_noeud(p)
		p.points.clear()
		return
	if not is_instance_valid(p.noeud):
		p.noeud = _silhouette(p)
	var quand := _t - RETARD
	var pts: Array = p.points
	var pos: Vector3 = pts[0][1]
	var cap: float = pts[0][2]
	if quand >= pts[-1][0]:
		pos = pts[-1][1]
		cap = pts[-1][2]
	else:
		for i in range(pts.size() - 1, 0, -1):
			if quand >= pts[i - 1][0]:
				var k := inverse_lerp(pts[i - 1][0], pts[i][0], quand)
				pos = pts[i - 1][1].lerp(pts[i][1], k)
				cap = lerp_angle(pts[i - 1][2], pts[i][2], k)
				break
	p.noeud.global_position = pos
	p.noeud.rotation.y = cap


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
	if etat != "" and not hors_ligne:
		_sortir_dans = 1.5
	_gen += 1
	etat = ""
	_tr.fermer()
	for m in presents:
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
