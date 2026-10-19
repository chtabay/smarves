extends RefCounted
## Les tables et les machines de l'original, jouables avec les jeux du socle (SalleJeu.JEUX : les mêmes
## panneaux qu'au casino de Smarves, la même bourse, le même total gagné). Les postes viennent de
## l'original (donnees/tables.json, exporté par tools/minuit_decor/exporter_tables.mjs) : on s'assoit à la
## place libre la plus proche, face au tapis, et le panneau du jeu s'ouvre. Les tables sous housse restent
## fermées. Un jeton du Minuit vaut un crédit (TAUX_JETONS de minuit.gd) : on mise ses crédits.

const BASE := "res://communes/casino_minuit/"

var scene: Node3D
var K
var postes: Array = []
var _calque: CanvasLayer
var _panneau: Control


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


## Le joueur s'assoit à la place libre la plus proche du poste et le jeu s'ouvre.
func ouvrir(cible: Node) -> void:
	if _panneau != null:
		return
	var p: Dictionary = cible.get_meta("poste")
	var joueur: Node3D = scene.player
	var place: Dictionary = p.places[0]
	for q in p.places:
		var d := Vector2(q.position.x, q.position.z).distance_to(Vector2(joueur.global_position.x, joueur.global_position.z))
		if d < Vector2(place.position.x, place.position.z).distance_to(Vector2(joueur.global_position.x, joueur.global_position.z)):
			place = q
	joueur.global_position = Vector3(place.position.x, joueur.global_position.y, place.position.z)
	var vers := Vector3(p.centre.x, 0, p.centre.z) - Vector3(place.position.x, 0, place.position.z)
	if vers.length() > 0.01:
		joueur.rotation.y = atan2(-vers.x, -vers.z)
	var jeu: Dictionary = SalleJeu.JEUX[p.jeu]
	var pn: Control = load(jeu.panneau).new()
	if "game" in pn:
		pn.game = self
	if "title" in pn:
		pn.title = "Casino Minuit : %s" % jeu.titre
	pn.played.connect(_joue)
	pn.closed.connect(func():
		pn.queue_free()
		_panneau = null
		joueur.frozen = false)
	joueur.frozen = true
	_calque.add_child(pn)
	_panneau = pn


## La machine à sous demande à son hôte de payer la mise.
func spend(amount: int) -> bool:
	return Game.spend(amount)


## Le gain s'encaisse comme partout ; les lieux du casino qui ouvrent avec lui font signe.
func _joue(bet: int, payout: int) -> void:
	Sfx.result(bet, payout)
	var avant := Game.won
	Game.cash_in(payout)
	if payout >= bet * 20:
		scene._dire("Jackpot ! Toute la salle se retourne.")
	var c: Commune = Communes.commune("casino_minuit")
	for l in (c.lieux() if c else []):
		if l.seuil > 0 and avant < l.seuil and Game.won >= l.seuil:
			scene._dire("%s vous fait signe : %s ouvre ce soir." % [l.host, l.name.substr(0, 1).to_lower() + l.name.substr(1)])
