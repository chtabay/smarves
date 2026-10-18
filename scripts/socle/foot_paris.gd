class_name FootParis
extends FootTableau
## Le comptoir des paris : la fenêtre où Josiane prend les paris sur la journée à venir du championnat
## de la Vienne (docs/SUITE.md, section 6). Les matchs de la division qu'on suit, trois cotes par match
## (1, N, 2), une mise ; un match coché fait un pari simple, plusieurs font un combiné dont les cotes se
## multiplient. Les tickets ouverts et les derniers réglés sont dessous, avec le bilan depuis le début :
## la marge gagne à la longue, les chiffres le disent, personne ne fait la leçon.
##
## Elle emprunte au tableau du dimanche son ardoise et ses petites pièces ; s'ouvre et se ferme comme
## lui (signal closed, Échap).

## Ce qui est coché : "dom|ext" -> issue.
var choix := {}
var mise := 20
var _ligne_etat: Label
var _journee := {}


static func paris() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Paris")


func _ready() -> void:
	_preparer()
	remplir(_colonne)


func remplir(colonne: VBoxContainer) -> void:
	_vider(colonne)
	var f := foot()
	var p := paris()
	division = division_suivie()
	colonne.add_child(_mot("L E   C O M P T O I R   D E S   P A R I S", 13, DOUX))
	colonne.add_child(_mot("Le carnet du PMU de Josiane", 26 if _etroit() else 32, CRAIE, Polices.titre(), _etroit()))
	var prochain: Array = f.prochain_coup_envoi(f.maintenant())
	_journee = {}
	if prochain[0] != f.saison or f.niveaux.is_empty():
		colonne.add_child(_mot("La saison qui vient n'est pas encore tirée : Josiane range le carnet.", 16, DOUX, null, true))
	else:
		_journee = {"s": f.saison, "j": prochain[1], "n": division[0], "g": division[1], "quand": prochain[2]}
		colonne.add_child(_mot("Journée %d, %s à %d h  ·  %s" % [_journee.j, date(_journee.quand), f.HEURE_COUP_ENVOI, f.nom_division(division[0], division[1])], 17, CRAIE, null, true))
		colonne.add_child(_mot("Coche 1, N ou 2 sur un match pour un pari simple, sur plusieurs pour un combiné : les cotes se multiplient.", 14, DOUX, null, true))
		for m in f.journee(_journee.s, _journee.n, _journee.g, _journee.j, 0):
			colonne.add_child(_rangee_match(m))
		colonne.add_child(_filet())
		_rangee_mises(colonne)
		_ligne_etat = _mot(_etat_texte(), 15, OR, null, true)
		colonne.add_child(_ligne_etat)
	colonne.add_child(_filet())
	_tickets(colonne)
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_END
	bas.add_theme_constant_override("separation", 10)
	colonne.add_child(bas)
	if not _journee.is_empty():
		var b := _bouton("Jouer le ticket", func(): jouer())
		b.name = "Jouer"
		bas.add_child(b)
	bas.add_child(_bouton("Reposer le stylo  (Échap)", func(): closed.emit()))


func _rangee_match(m: Dictionary) -> Control:
	var f := foot()
	var p := paris()
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 4)
	var noms := _mot("%s – %s" % [f.clubs[m.dom].nom, f.clubs[m.ext].nom], 15, CRAIE, Polices.gras())
	noms.custom_minimum_size.x = 150 if _etroit() else 330
	noms.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(noms)
	var k := Paris.cle(m.dom, m.ext)
	var c: Dictionary = p.cotes(_journee.s, m.dom, m.ext)
	for issue in Paris.ISSUES:
		var b := _bouton("%s  %.2f" % [issue, float(c[issue])], func():
			if str(choix.get(k, "")) == issue:
				choix.erase(k)
			else:
				choix[k] = issue
			remplir(_colonne), 15)
		b.name = "Choix_%s_%s" % [k, issue]
		if str(choix.get(k, "")) == issue:
			for etat in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(etat, _boite(Color(OR, 0.45), CRAIE, 4, 8))
			for ct in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(ct, CRAIE)
		h.add_child(b)
	return h


func _rangee_mises(colonne: VBoxContainer) -> void:
	colonne.add_child(_mot("La mise", 15, DOUX))
	var rang := HFlowContainer.new()
	rang.add_theme_constant_override("h_separation", 8)
	rang.add_theme_constant_override("v_separation", 6)
	colonne.add_child(rang)
	for v in Paris.MISES:
		var b := _bouton("%d crédits" % v, func():
			mise = int(v)
			remplir(_colonne), 15)
		b.name = "Mise_%d" % v
		if mise == int(v):
			_allumer(b)
		rang.add_child(b)
	# La mise est libre : on tape ce qu'on veut, les boutons ne sont que des raccourcis.
	var champ := LineEdit.new()
	champ.name = "MiseLibre"
	champ.text = str(mise)
	champ.placeholder_text = "autre montant"
	champ.custom_minimum_size = Vector2(130, 0)
	champ.max_length = 9
	champ.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	champ.add_theme_font_size_override("font_size", 15)
	champ.add_theme_color_override("font_color", CRAIE)
	champ.add_theme_color_override("font_placeholder_color", DOUX)
	champ.add_theme_stylebox_override("normal", _boite(Color(0, 0, 0, 0.25), DOUX, 4, 8))
	champ.add_theme_stylebox_override("focus", _boite(Color(0, 0, 0, 0.25), OR, 4, 8))
	champ.text_changed.connect(func(t: String): poser_mise(t))
	champ.text_submitted.connect(func(_t: String): jouer())
	rang.add_child(champ)
	var tout := _bouton("Tout  (%s)" % Game.fmt(Game.credits), func():
		mise = maxi(Paris.MISE_MIN, int(Game.credits))
		remplir(_colonne), 15)
	tout.name = "Mise_tout"
	rang.add_child(tout)


## Une mise tapée au clavier : les chiffres seulement, au moins MISE_MIN ; la ligne d'état suit.
func poser_mise(texte: String) -> void:
	var chiffres := ""
	for c in texte:
		if c >= "0" and c <= "9":
			chiffres += c
	mise = maxi(Paris.MISE_MIN, int(chiffres)) if chiffres != "" else Paris.MISE_MIN
	if _ligne_etat != null:
		_ligne_etat.text = _etat_texte()


func _allumer(b: Button) -> void:
	for etat in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(etat, _boite(Color(OR, 0.45), CRAIE, 4, 8))
	for ct in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(ct, CRAIE)


## La cote du ticket coché, et ce qu'il rapporterait.
func cote_ticket() -> float:
	var c := 1.0
	for k in choix:
		var p: PackedStringArray = str(k).split("|")
		c *= float(paris().cotes(_journee.s, p[0], p[1])[choix[k]])
	return snappedf(c, 0.01)


func _etat_texte() -> String:
	if choix.is_empty():
		return "Rien de coché. Tu as %s crédits." % Game.fmt(Game.credits)
	var c := cote_ticket()
	return "%s sur %d match%s, cote %.2f : %s crédits si tout passe." % [Game.fmt(mise), choix.size(), "s" if choix.size() > 1 else "", c, Game.fmt(int(round(mise * c)))]


## Pose le ticket coché ; vrai s'il est pris.
func jouer() -> bool:
	if _journee.is_empty():
		return false
	var r: Dictionary = paris().parier(_journee.s, _journee.j, _journee.n, _journee.g, choix, mise)
	if r.ok:
		choix = {}
		remplir(_colonne)
		if _ligne_etat != null:
			_ligne_etat.text = "Josiane déchire le ticket : « Rendez-vous dimanche à 17 h. »"
		return true
	if _ligne_etat != null:
		_ligne_etat.text = {"vide": "Coche au moins un match.", "credits": "Il te manque des crédits pour cette mise.",
			"joue": "Trop tard : le coup d'envoi est donné, les paris attendent la journée suivante.", "mise": "Une mise, c'est au moins un crédit."}.get(str(r.raison), "Josiane fait non de la tête.")
	return false


## Les tickets ouverts, les derniers réglés, et le bilan.
func _tickets(colonne: VBoxContainer) -> void:
	var f := foot()
	var p := paris()
	var liste: Array = p.tickets.duplicate()
	liste.reverse()
	var montres := 0
	for t in liste:
		if montres >= 5:
			break
		montres += 1
		var morceaux: Array = []
		for k in t.choix:
			var pc: PackedStringArray = str(k).split("|")
			morceaux.append("%s – %s : %s" % [f.clubs.get(pc[0], {}).get("court", pc[0]), f.clubs.get(pc[1], {}).get("court", pc[1]), t.choix[k]])
		var sort: String = {"ouvert": "ouvert, réglé dimanche à 17 h", "gagne": "gagné : %s crédits" % Game.fmt(int(t.gain)), "perdu": "perdu"}.get(str(t.etat), "")
		colonne.add_child(_mot("Journée %d  ·  %s  ·  %s à %.2f  ·  %s" % [int(t.j), ", ".join(morceaux), Game.fmt(int(t.mise)), float(t.cote), sort], 14,
			OR if t.etat == "gagne" else (CRAIE if t.etat == "ouvert" else DOUX), null, true))
	var b: Dictionary = p.bilan()
	if b.tickets == 0:
		colonne.add_child(_mot("Pas encore de ticket. Josiane : « Le premier, c'est pour voir. »", 14, DOUX, null, true))
	else:
		colonne.add_child(_mot("Depuis le début : %d ticket%s, %s misés, %s repris. Les chiffres le disent, Josiane ne dit rien." % [b.tickets, "s" if b.tickets > 1 else "", Game.fmt(int(b.mise)), Game.fmt(int(b.gagne))], 14, DOUX, null, true))
