class_name FootCauserie
extends FootTableau
## La causerie du président : la fenêtre où l'on donne au club de la commune ses consignes pour son
## prochain match (docs/SUITE.md, section 6). La formation, la mentalité et le pressing, les trois
## choses que FootMatch lit avant le coup d'envoi. La consigne vaut tout de suite ici et part au
## championnat (Football.decider) si le joueur est connecté à son compte ; sinon elle reste sur cet
## appareil, et la fenêtre le dit : un match n'est commun que si ses consignes le sont.
##
## Elle emprunte au tableau du dimanche son ardoise et ses petites pièces ; s'ouvre et se ferme comme
## lui (signal closed, Échap).

## Le joueur veut passer au mercato (le stade ouvre FootMercato).
signal mercato

## Le club dont on parle (l'id du registre), et son prochain match.
var club := ""
var rencontre := {}
## Ce qui est coché, avant de valider.
var _choix := {}
var _ligne_etat: Label


func _ready() -> void:
	_preparer()
	remplir(_colonne)


func remplir(colonne: VBoxContainer) -> void:
	_vider(colonne)
	var f := foot()
	var c: Dictionary = f.clubs.get(club, {})
	colonne.add_child(_mot("L A   C A U S E R I E   D U   P R É S I D E N T", 13, DOUX))
	colonne.add_child(_mot(str(c.get("nom", "Le club")), 26 if _etroit() else 34, CRAIE, Polices.titre(), _etroit()))
	rencontre = f.prochain_match(club)
	if rencontre.is_empty():
		colonne.add_child(_mot("La saison qui vient n'est pas encore tirée : les consignes attendent le calendrier.", 16, DOUX, null, true))
		_bas(colonne, false)
		return
	var adv: String = rencontre.ext if rencontre.dom == club else rencontre.dom
	var ou := "à domicile" if rencontre.dom == club else "en déplacement"
	colonne.add_child(_mot("Prochain match : journée %d, %s à %d h, %s contre %s." % [rencontre.j, date(rencontre.quand),
		Time.get_datetime_dict_from_unix_time(rencontre.quand).hour, ou, str(f.clubs[adv].nom)], 17, CRAIE, null, true))
	colonne.add_child(_filet())
	var actuelle: Dictionary = f.consigne_de(rencontre.s, rencontre.j, club)
	if not f.actionnaires(club).is_empty():
		# Les parts du club, cédées chez le notaire : qui en tient le plus parle au président.
		colonne.add_child(_mot(str(f.phrase_actionnaires(club)), 15, OR, null, true))
	if not f.peut_decider(club):
		colonne.add_child(_mot("Le président n'écoute que son premier porteur d'obligations. Maître Garnier cède celles du club à l'étude.", 16, CRAIE, null, true))
		colonne.add_child(_mot(etat_texte(actuelle), 15, DOUX, null, true))
		_bas(colonne, false)
		return
	if _choix.is_empty():
		_choix = (actuelle.consigne as Dictionary).duplicate()
	_rangee(colonne, "La formation", "formation", FootMatch.FORMATIONS.keys(), func(k): return str(k))
	_rangee(colonne, "La mentalité", "mentalite", FootMatch.MENTALITES.keys(), func(k): return str(FootMatch.MENTALITES[k].nom))
	_rangee(colonne, "Le pressing", "pressing", FootMatch.PRESSINGS.keys(), func(k): return str(FootMatch.PRESSINGS[k].nom))
	colonne.add_child(_filet())
	_ligne_etat = _mot(etat_texte(actuelle), 15, DOUX, null, true)
	colonne.add_child(_ligne_etat)
	_bas(colonne, true)


## Ce que la fenêtre dit de la consigne en place : d'où elle vient, et si elle compte pour tout le monde.
func etat_texte(actuelle: Dictionary) -> String:
	var compte: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Compte")
	var connecte: bool = compte != null and compte.connecte()
	match str(actuelle.etat):
		"commune":
			return "Consigne au championnat%s : tout le monde jouera ce match ainsi." % (" (posée par %s)" % actuelle.par if actuelle.par != "" else "")
		"locale":
			if connecte:
				return "Consigne gardée sur cet appareil, en route vers le championnat."
			return "Consigne gardée sur cet appareil seulement : connectez-vous à votre compte Pyramides (dans la bienvenue) pour qu'elle compte pour tout le monde."
		_:
			if connecte:
				return "Aucune consigne encore : le club jouera en 4-4-2, équilibré, pressing normal."
			return "Aucune consigne encore. Sans compte Pyramides, une consigne reste sur cet appareil."


func _rangee(colonne: VBoxContainer, titre: String, cle: String, valeurs: Array, nom: Callable) -> void:
	colonne.add_child(_mot(titre, 15, DOUX))
	var rang := HFlowContainer.new()
	rang.add_theme_constant_override("h_separation", 8)
	rang.add_theme_constant_override("v_separation", 6)
	colonne.add_child(rang)
	for v in valeurs:
		var b := _bouton(nom.call(v), func():
			_choix[cle] = str(v)
			remplir(_colonne), 15)
		b.name = "Choix_%s_%s" % [cle, str(v)]
		if str(_choix.get(cle, "")) == str(v):
			for etat in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(etat, _boite(Color(OR, 0.45), CRAIE, 4, 8))
			for ct in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(ct, CRAIE)
		rang.add_child(b)


func _bas(colonne: VBoxContainer, valider: bool) -> void:
	var bas := _pied(colonne)
	if valider:
		var b := _bouton("Donner la consigne", func(): donner())
		b.name = "Valider"
		bas.add_child(b)
	var m := _bouton("Le mercato" + ("  ·  ouvert" if foot().mercato_ouvert(foot().saison) else ""), func(): mercato.emit())
	m.name = "Mercato"
	bas.add_child(m)
	bas.add_child(_bouton("Laisser le président  (Échap)", func(): closed.emit()))


## Pose la consigne cochée pour le prochain match ; vrai si le championnat l'a prise.
func donner() -> bool:
	if rencontre.is_empty():
		return false
	var ok: bool = foot().decider(rencontre.s, rencontre.j, club, _choix)
	remplir(_colonne)
	if not ok and _ligne_etat != null:
		_ligne_etat.text = "Trop tard : le coup d'envoi est donné. Les consignes attendent la journée suivante." if foot().peut_decider(club) \
			else "Le président n'écoute que son premier actionnaire."
	return ok
