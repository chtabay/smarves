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
## Les panneaux s'ouvrent habillés comme au casino de Smarves (casino_interior.gd, _build_ui : laque sombre,
## filet d'or, boutons en pastille), posés en bas de l'écran au-dessus de la salle assombrie, et la souris
## est libérée tant qu'un panneau est ouvert : on mise et on joue au clic. Le thème est recopié ici, dans le
## paquet, pour que Minuit s'habille de même sur un jeu installé qui ne l'aurait pas.

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
	_calque = CanvasLayer.new()
	_calque.layer = 5
	scene.add_child(_calque)
	var racine := Control.new()
	racine.theme = theme()
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


## Le thème des fenêtres du casino de Smarves (casino_interior.gd, _build_ui), à la manière d'Addict :
## laque sombre, filet d'or, angles arrondis, ombre portée ; boutons en pastille de 48 px, au doigt aussi.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = Polices.texte()
	t.default_font_size = 20
	var or_ := Color(0.96, 0.8, 0.45)
	var panneau := StyleBoxFlat.new()
	panneau.bg_color = Color(0.06, 0.03, 0.035, 0.93)
	panneau.border_color = Color(0.89, 0.71, 0.35, 0.55)
	panneau.set_border_width_all(1)
	panneau.set_corner_radius_all(16)
	panneau.set_content_margin_all(22)
	panneau.shadow_color = Color(0, 0, 0, 0.5)
	panneau.shadow_size = 24
	panneau.anti_aliasing = true
	t.set_stylebox("panel", "PanelContainer", panneau)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color(0.14, 0.07, 0.04, 0.95), "hover": Color(0.28, 0.15, 0.06, 0.95),
			"pressed": Color(0.38, 0.22, 0.08, 1.0), "disabled": Color(0.07, 0.06, 0.06, 0.8),
			"focus": Color(0, 0, 0, 0)}[st]
		b.border_color = Color(0.85, 0.62, 0.3, 0.25 if st == "disabled" else 0.8)
		b.set_border_width_all(1)
		b.set_corner_radius_all(24)
		b.anti_aliasing = true
		b.content_margin_left = 20
		b.content_margin_right = 20
		b.content_margin_top = 11
		b.content_margin_bottom = 11
		if st == "focus":
			b.draw_center = false
			b.border_color = Color(0, 0, 0, 0)
		t.set_stylebox(st, "Button", b)
	t.set_color("font_color", "Button", or_)
	t.set_color("font_hover_color", "Button", Color(1, 0.92, 0.7))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.42))
	t.set_color("font_color", "Label", Color(0.9, 0.86, 0.8))
	return t


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
		if table_id != "":
			_seuils(avant))
	_poser(pn)


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


## Le panneau se pose sous le premier tiers de l'écran, comme au casino ; un grand (la machine à sous)
## remonte ce qu'il faut pour tenir en entier.
func _caler(p: Control) -> void:
	if not is_instance_valid(p):
		return
	var h := _centre.get_viewport_rect().size.y
	_centre.anchor_top = clampf((h - p.get_combined_minimum_size().y - 24.0) / h, 0.0, 0.36)


## Le panneau se ferme : la salle revient, et la souris comme elle était (reprise à la vue à pied).
func _lever() -> void:
	_panneau = null
	_voile.visible = false
	scene.player.frozen = false
	Input.mouse_mode = _souris


## Le gain s'encaisse comme partout ; les lieux du casino qui ouvrent avec lui font signe.
func _joue(bet: int, payout: int) -> void:
	Sfx.result(bet, payout)
	var avant := Game.won
	Game.cash_in(payout)
	if payout >= bet * 20:
		scene._dire("Jackpot ! Toute la salle se retourne.")
	_seuils(avant)


## Les lieux du casino dont le seuil vient d'être franchi font signe.
func _seuils(avant: int) -> void:
	var c: Commune = Communes.commune("casino_minuit")
	for l in (c.lieux() if c else []):
		if l.seuil > 0 and avant < l.seuil and Game.won >= l.seuil:
			scene._dire("%s vous fait signe : %s ouvre ce soir." % [l.host, l.name.substr(0, 1).to_lower() + l.name.substr(1)])
