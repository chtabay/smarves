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

const BASE := "res://communes/casino_minuit/"
const POKER_MULTI := "res://scripts/jeux/poker_multi.gd"
const SALLE := preload("res://communes/casino_minuit/salle_poker.gd")
## Les tables de l'original et leur table au serveur (SMARVES.tables de la fonction casino).
const SERVEUR := {"poker-1": "minuit:poker-1", "poker-3": "minuit:poker-3", "poker-5": "minuit:poker-5"}

var scene: Node3D
var K
var postes: Array = []
var _calque: CanvasLayer
var _panneau: Control
## Le poste où le joueur est assis (les PNJ réagissent à ses parties).
var _poste := ""
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
	_calque = CanvasLayer.new()
	_calque.layer = 5
	scene.add_child(_calque)
	_poser_salle()


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
	var joueur: Node3D = scene.player
	var sp: PanelContainer = SALLE.new()
	sp.table_ref = table_id
	if not essai_salle.is_empty():
		sp.hors_ligne = true
		sp.vue = essai_salle if v.is_empty() else v
	sp.closed.connect(func():
		sp.queue_free()
		_panneau = null
		joueur.frozen = false)
	sp.asseoir.connect(func(id: String):
		sp.queue_free()
		_panneau = null
		joueur.frozen = false
		for q in postes:
			if SERVEUR.get(q.id, "") == id:
				_asseoir(q, id, SALLE.nom(sp.vue, id)))
	joueur.frozen = true
	_calque.add_child(sp)
	_panneau = sp


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
		pn.game = self
	if "title" in pn:
		pn.title = "Casino Minuit : %s" % jeu.titre
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
		_panneau = null
		joueur.frozen = false
		_poste = ""
		if pnj != null:
			pnj.lever_joueur()
		if table_id != "":
			_seuils(avant))
	joueur.frozen = true
	_calque.add_child(pn)
	_panneau = pn
	_poste = p.id
	if pnj != null and idx >= 0:
		pnj.asseoir_joueur(p.id, idx)


## La machine à sous demande à son hôte de payer la mise.
func spend(amount: int) -> bool:
	return Game.spend(amount)


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
