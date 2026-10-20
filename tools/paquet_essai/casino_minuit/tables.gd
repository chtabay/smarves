extends RefCounted
## Les tables et les machines de l'original, jouables avec les jeux du socle (SalleJeu.JEUX : les mêmes
## panneaux qu'au casino de Smarves, la même bourse, le même total gagné). Les postes viennent de
## l'original (donnees/tables.json, exporté par tools/minuit_decor/exporter_tables.mjs) : on s'assoit à la
## place libre la plus proche, face au tapis, et le panneau du jeu s'ouvre. Les tables sous housse restent
## fermées. Un jeton du Minuit vaut un crédit (TAUX_JETONS de minuit.gd) : on mise ses crédits.
##
## Le poker, connecté au compte, se joue à plusieurs comme aux Ambassadeurs de Smarves (le même panneau,
## scripts/jeux/poker_multi.gd) : chaque table de l'original est une table du serveur, à six joueurs.
## Une table pleine renvoie à celle qui se remplit ; quand toutes le sont, la salle du poker (salle_poker.gd,
## au mur des tournois ou à toute table pleine) tient la liste d'attente. Sans compte, seul contre les habitués.
##
## Les tables sont celles du casino de Smarves, dernière version (Tables, scripts/socle/tables.gd, socle
## 1.10) : posées sur les postes de l'original, dont le tapis, les jetons et le cylindre cèdent la place.
## On s'y assoit comme au casino : la caméra glisse jusqu'à la place et le panneau devient la barre basse,
## habillé du thème du socle (Tables.theme()), la souris libérée tant qu'on joue. Les panneaux sans table
## (la salle du poker) s'ouvrent en bas de l'écran, au-dessus de la salle assombrie.

const BASE := "res://communes/casino_minuit/"
const POKER_MULTI := "res://scripts/jeux/poker_multi.gd"
const SALLE := preload("res://communes/casino_minuit/salle_poker.gd")
## Les tables de l'original et leur table au serveur (SMARVES.tables de la fonction casino).
const SERVEUR := {"poker-1": "minuit:poker-1", "poker-3": "minuit:poker-3", "poker-5": "minuit:poker-5"}

var scene: Node3D
var K
var postes: Array = []
var _calque: CanvasLayer
## Sous le calque : la salle assombrie, et le centre où se pose le panneau.
var _voile: ColorRect
var _centre: CenterContainer
var _panneau: Control
## Le poste où le joueur est assis (les PNJ réagissent à ses parties).
var _poste := ""
## Les tables du casino posées sur les postes (id du poste -> table), et celle où le joueur est assis.
var tables3d := {}
var _assis: Node3D
## Le mode de la souris avant le panneau : on le rend en se levant.
var _souris := Input.MOUSE_MODE_CAPTURED
## Pour les essais : le poker à plusieurs sans compte ni réseau, la salle posée à la main.
var essai_salle := {}


func _init(s: Node3D, kit) -> void:
	scene = s
	K = kit


## Une zone d'interaction par poste ouvert, au-dessus de son tapis (ou devant sa machine).
func poser() -> void:
	postes = JSON.parse_string(FileAccess.get_file_as_string(BASE + "donnees/tables.json"))
	for p in postes:
		if p.fermee or p.places.is_empty():
			continue
		var c: Dictionary = p.centre
		var a := Area3D.new()
		a.name = "table_" + str(p.id)
		a.set_meta("interact", "table")
		a.set_meta("poste", p)
		a.set_meta("prompt", "E : %s" % SalleJeu.JEUX[p.jeu].invite)
		a.position = Vector3(c.x, 1.0, c.z)
		a.rotation.y = float(p.rotation)
		var f := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(maxf(float(p.taille[0]) + 0.6, 1.2), 2.0, maxf(float(p.taille[1]) + 0.6, 1.2))
		f.shape = b
		a.add_child(f)
		scene.add_child(a)
		if Tables.a_une_table(p.jeu):
			_poser_table(p)
	_creuser()
	_calque = CanvasLayer.new()
	_calque.layer = 5
	scene.add_child(_calque)
	var racine := Control.new()
	racine.theme = Tables.theme()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_calque.add_child(racine)
	_voile = ColorRect.new()
	_voile.color = Color(0.05, 0.027, 0.035, 0.62)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.visible = false
	racine.add_child(_voile)
	_centre = CenterContainer.new()
	_centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_centre.anchor_top = 0.36
	_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(_centre)
	_poser_salle()


## La table du casino de Smarves sur le poste : le tapis, les jetons, les cartes et le cylindre de l'original
## (le nœud du poste dans son décor) s'effacent, et le dessus de la table (plateau, bandeau, sabot, rack)
## est creusé dans les maillages fixes de la zone (_creuser) ; la caisse reste dessous, et les tabourets
## où s'assoient les habitués. Le tapis du casino se pose à la hauteur de celui de l'original ; la place
## du joueur (le +z de la table) regarde les places de l'original. La table ronde du poker, à six comme
## les tables du serveur, est un peu réduite pour laisser leurs chaises aux habitués de l'ovale d'origine.
## Les cylindres de l'original (les instances « roulettes » et « roulette-roues ») s'effacent avec leurs tables.
func _poser_table(p: Dictionary) -> void:
	var decor: Node = scene.find_child("Decor_" + str(p.zone), true, false)
	var poste: Node3D = decor.find_child(str(p.id), true, false) if decor else null
	if poste:
		poste.visible = false
	var t := Tables.table(p.jeu, "MINUIT" if p.jeu in ["machine", "baccara"] else "")
	t.with_lamp = false
	(decor.get_parent() if decor else scene).add_child(t)
	var c := Vector3(p.centre.x, p.position.y, p.centre.z)
	var vers := Vector3.ZERO
	for q in p.places:
		vers += Vector3(q.position.x, 0, q.position.z) - Vector3(c.x, 0, c.z)
	if vers.length() < 0.3 and not p.places.is_empty():
		vers = Vector3(p.places[0].position.x - c.x, 0, p.places[0].position.z - c.z)
	var machine: bool = p.jeu == "machine"
	var echelle := 0.85 if p.jeu == "poker" else 1.0
	var dessus: float = 0.0 if machine or p.jeu == "roue" else float(p.centre.y) - float(t.felt_y) * echelle
	t.global_transform = Transform3D(Basis(Vector3.UP, atan2(vers.x, vers.z)).scaled(Vector3.ONE * echelle), c + Vector3(0, dessus, 0))
	if p.jeu == "roulette" and decor:
		for nom in ["roulettes", "roulette-roues"]:
			var g: Node3D = decor.find_child(nom, true, false)
			if g:
				g.visible = false
	tables3d[p.id] = t
	if decor:
		# La boîte à creuser, dans le repère du poste de l'original (sa rotation, sa taille).
		var b := Transform3D(Basis(Vector3.UP, float(p.rotation)), Vector3(c.x, 0, c.z)).affine_inverse()
		var marge := 0.05 if machine else 0.12
		var bas: float = 0.02 if machine or p.jeu == "roue" else float(p.centre.y) - 0.12
		_a_creuser.append([decor, b, Vector3(float(p.taille[0]) / 2.0 + marge, 0, float(p.taille[1]) / 2.0 + marge), bas, 3.2])


## Les boîtes à creuser : [décor de la zone, repère du poste, demi-taille, bas, haut].
var _a_creuser: Array = []


## Ôte des maillages fixes du décor (les « static » cuits à l'export) les triangles tout entiers dans la
## boîte d'un poste : le dessus de la table de l'original, sous la table du casino.
func _creuser() -> void:
	var par_decor := {}
	for e in _a_creuser:
		if not par_decor.has(e[0]):
			par_decor[e[0]] = []
		par_decor[e[0]].append(e)
	for decor in par_decor:
		for mi in (decor as Node).find_children("*", "MeshInstance3D", true, false):
			if not (str(mi.name).begins_with("static") or str(mi.name).begins_with("props")) or mi.mesh == null:
				continue
			_creuser_maillage(mi, par_decor[decor])


func _creuser_maillage(mi: MeshInstance3D, boites: Array) -> void:
	var src: Mesh = mi.mesh
	var vers_monde: Transform3D = mi.global_transform
	var neuf := ArrayMesh.new()
	var touche := false
	for s in src.get_surface_count():
		var a: Array = src.surface_get_arrays(s)
		var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(pos.size()))
		# Chaque sommet : dans quelle boîte il tombe (-1 : aucune).
		var dans := PackedInt32Array()
		dans.resize(pos.size())
		for i in pos.size():
			dans[i] = -1
			var w := vers_monde * pos[i]
			for k in boites.size():
				var e: Array = boites[k]
				var l: Vector3 = e[1] * w
				if absf(l.x) <= e[2].x and absf(l.z) <= e[2].z and w.y >= e[3] and w.y <= e[4]:
					dans[i] = k
					break
		var garde := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var k := dans[idx[t]]
			if k >= 0 and dans[idx[t + 1]] == k and dans[idx[t + 2]] == k:
				touche = true
				continue
			garde.append_array([idx[t], idx[t + 1], idx[t + 2]])
		if garde.is_empty():
			garde = PackedInt32Array([0, 0, 0])
		a[Mesh.ARRAY_INDEX] = garde
		neuf.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		neuf.surface_set_material(s, src.surface_get_material(s))
	if touche:
		mi.mesh = neuf


## La salle du poker s'ouvre devant le mur des tournois.
func _poser_salle() -> void:
	var ecrans = scene._decor_._ecrans if scene._decor_ else null
	if ecrans == null or not ecrans.porteurs.has(ecrans.TEX_POKER):
		return
	var mi: MeshInstance3D = ecrans.porteurs[ecrans.TEX_POKER][0]
	var b := mi.global_transform * mi.get_aabb()
	var a := Area3D.new()
	a.name = "salle_poker"
	a.set_meta("interact", "salle_poker")
	a.set_meta("prompt", "E : voir les tables de poker")
	a.position = Vector3(b.get_center().x, 1.0, b.get_center().z)
	var f := CollisionShape3D.new()
	var bo := BoxShape3D.new()
	bo.size = Vector3(b.size.x + 3.0, 2.0, b.size.z + 3.0)
	f.shape = bo
	a.add_child(f)
	scene.add_child(a)


func _multi() -> bool:
	return not essai_salle.is_empty() or Compte.connecte()


## Le joueur s'assoit à la place libre la plus proche du poste et le jeu s'ouvre. Au poker à plusieurs,
## une table pleine renvoie à une autre, ou à la salle.
func ouvrir(cible: Node) -> void:
	if _panneau != null:
		return
	var p: Dictionary = cible.get_meta("poste")
	if p.jeu == "poker" and SERVEUR.has(p.id) and _multi():
		var v := await _salle(SERVEUR[p.id])
		if v.is_empty():
			_dire("Le casino ne répond pas : la table se joue seul contre les habitués.")
		else:
			var t: Dictionary = SALLE.table_de(v, SERVEUR[p.id])
			if not t.get("moi", false) and int(t.get("libres", 0)) <= 0:
				var autre := SALLE.vers(v, SERVEUR[p.id])
				if autre != "":
					var n := int(SALLE.table_de(v, autre).libres)
					_dire("Le croupier : « Complète. La %s a %d chaise%s libre%s. »" % [SALLE.nom(v, autre).to_lower(), n, "s" if n > 1 else "", "s" if n > 1 else ""])
				else:
					ouvrir_salle(SERVEUR[p.id], v)
				return
			_asseoir(p, SERVEUR[p.id], SALLE.nom(v, SERVEUR[p.id]))
			return
	_asseoir(p)



func _dire(t: String) -> void:
	scene._dire(t)


## La salle vue du serveur ({} s'il ne répond pas).
func _salle(table_id: String) -> Dictionary:
	if not essai_salle.is_empty():
		return essai_salle
	var r: Dictionary = await Compte.casino("salle", {"table": table_id})
	if r.code != 200 or not r.corps is Dictionary or r.corps.has("error"):
		return {}
	return r.corps


## La salle du poker : les tables, et la liste d'attente.
func ouvrir_salle(table_id := "minuit:poker-1", v := {}) -> void:
	if _panneau != null:
		return
	var sp: PanelContainer = SALLE.new()
	sp.table_ref = table_id
	if not essai_salle.is_empty():
		sp.hors_ligne = true
		sp.vue = essai_salle if v.is_empty() else v
	sp.closed.connect(func():
		sp.queue_free()
		_lever())
	sp.asseoir.connect(func(id: String):
		sp.queue_free()
		_lever()
		for q in postes:
			if SERVEUR.get(q.id, "") == id:
				_asseoir(q, id, SALLE.nom(sp.vue, id)))
	_poser(sp)


func _asseoir(p: Dictionary, table_id := "", nom := "") -> void:
	var joueur: Node3D = scene.player
	var place: Dictionary = p.places[0]
	for q in p.places:
		var d := Vector2(q.position.x, q.position.z).distance_to(Vector2(joueur.global_position.x, joueur.global_position.z))
		if d < Vector2(place.position.x, place.position.z).distance_to(Vector2(joueur.global_position.x, joueur.global_position.z)):
			place = q
	# Les PNJ tiennent leurs places : on prend la plus proche qui reste libre.
	var pnj = scene.get("pnj")
	var idx := -2
	if pnj != null:
		idx = pnj.place_libre(p.id, joueur.global_position.x, joueur.global_position.z)
		if idx == -1:
			_dire("Toutes les places sont prises à cette table.")
			return
		if idx >= 0 and idx < p.places.size():
			place = p.places[idx]
	joueur.global_position = Vector3(place.position.x, joueur.global_position.y, place.position.z)
	var vers := Vector3(p.centre.x, 0, p.centre.z) - Vector3(place.position.x, 0, place.position.z)
	if vers.length() > 0.01:
		joueur.rotation.y = atan2(-vers.x, -vers.z)
	var jeu: Dictionary = SalleJeu.JEUX[p.jeu]
	var pn: Control = load(POKER_MULTI if table_id != "" else jeu.panneau).new()
	if "game" in pn:
		# La machine à sous demande à la scène (un Node) de payer la mise : minuit.gd, spend().
		pn.game = scene
	if "title" in pn:
		pn.title = "Casino Minuit : %s" % jeu.titre
	if "subtitle" in pn:
		pn.subtitle = "Casino Minuit  ·  la forêt des machines"
	var avant := Game.won
	if table_id != "":
		# À plusieurs, le panneau tient lui-même les crédits (chaque mise, chaque gain) : on guette les seuils.
		pn.table_id = table_id
		pn.title = "Casino Minuit : poker, %s · à plusieurs" % nom.to_lower()
		pn.hors_ligne = not essai_salle.is_empty()
	else:
		pn.played.connect(_joue)
	pn.closed.connect(func():
		pn.queue_free()
		_lever()
		_poste = ""
		if pnj != null:
			pnj.lever_joueur()
		if table_id != "":
			_seuils(avant))
	if tables3d.has(p.id):
		_asseoir_table(tables3d[p.id], pn)
	else:
		_poser(pn)
	_poste = p.id
	if pnj != null and idx >= 0:
		pnj.asseoir_joueur(p.id, idx)


## Le panneau s'ouvre : le visiteur s'arrête, la salle s'assombrit, la souris est rendue pour jouer au clic.
func _poser(p: Control) -> void:
	scene.player.frozen = true
	if _panneau == null:
		_souris = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_voile.visible = true
	_centre.add_child(p)
	_panneau = p
	p.resized.connect(_caler.bind(p))
	_caler(p)


## S'asseoir à la table du casino, comme à Smarves : la caméra (celle de la vue à pied ou de dessus)
## glisse jusqu'à la place, le panneau devient la barre basse, la souris est libérée.
func _asseoir_table(t: Node3D, p: Control) -> void:
	scene.player.frozen = true
	if _panneau == null:
		_souris = Input.mouse_mode
	Tables.asseoir(t, p, scene.get_viewport().get_camera_3d(), _centre.get_parent())
	_panneau = p
	_assis = t


## Le panneau se pose sous le premier tiers de l'écran, comme au casino ; un grand (la machine à sous)
## remonte ce qu'il faut pour tenir en entier.
func _caler(p: Control) -> void:
	if not is_instance_valid(p):
		return
	var h := _centre.get_viewport_rect().size.y
	_centre.anchor_top = clampf((h - p.get_combined_minimum_size().y - 24.0) / h, 0.0, 0.36)


## Le panneau se ferme : la salle revient, et la souris comme elle était (reprise à la vue à pied).
func _lever() -> void:
	if _assis:
		Tables.lever(_assis)
		_assis = null
	_panneau = null
	_voile.visible = false
	scene.player.frozen = false
	Input.mouse_mode = _souris


## Le gain s'encaisse comme partout ; les lieux du casino qui ouvrent avec lui font signe.
func _joue(bet: int, payout: int) -> void:
	Sfx.result(bet, payout)
	var avant := Game.won
	Game.cash_in(payout)
	var pnj = scene.get("pnj")
	if pnj != null and _poste != "":
		pnj.evenement_jeu({"type": "result", "stationId": _poste, "amount": payout - bet})
	if payout >= bet * 20:
		scene._dire("Jackpot ! Toute la salle se retourne.")
	_seuils(avant)


## Les lieux du casino dont le seuil vient d'être franchi font signe.
func _seuils(avant: int) -> void:
	var c: Commune = Communes.commune("casino_minuit")
	for l in (c.lieux() if c else []):
		if l.seuil > 0 and avant < l.seuil and Game.won >= l.seuil:
			scene._dire("%s vous fait signe : %s ouvre ce soir." % [l.host, l.name.substr(0, 1).to_lower() + l.name.substr(1)])
