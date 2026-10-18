class_name FootObligations
extends FootTableau
## Le registre des obligations d'un club (docs/SUITE.md, section 6), sur le modèle d'Impérial 2030 : neuf
## obligations de tailles différentes, de 500 à 7 500 crédits, chacune en un seul exemplaire ; la plus
## grosse somme investie parle au président ; chaque journée jouée verse un dividende, 50 crédits par
## cran, selon le classement. On en prend une libre, on en rend une à l'étude (qui la reprend à 80 %),
## ou on échange une des siennes contre une plus grosse en payant la différence. Maître Garnier ouvre
## ce registre à l'étude ; les locaux du club aussi.
##
## Elle emprunte au tableau du dimanche son ardoise et ses petites pièces ; s'ouvre et se ferme comme
## lui (signal closed, Échap).

var club := ""
var _ligne_etat: Label


func _ready() -> void:
	_preparer()
	remplir(_colonne)


func remplir(colonne: VBoxContainer) -> void:
	_vider(colonne)
	var f := foot()
	var c: Dictionary = f.clubs.get(club, {})
	colonne.add_child(_mot("L E   R E G I S T R E   D E S   O B L I G A T I O N S", 13, DOUX))
	colonne.add_child(_mot(str(c.get("nom", "Le club")), 26 if _etroit() else 34, CRAIE, Polices.titre(), _etroit()))
	colonne.add_child(_mot(str(f.phrase_actionnaires(club)), 16, OR, null, true))
	var facteur: float = f.recette_facteur(club)
	colonne.add_child(_mot("Une obligation verse 50 crédits par cran à chaque journée jouée, ×%.1f au classement d'aujourd'hui. L'étude reprend à 80 %%, et une plus grosse s'échange contre une des vôtres pour la différence." % facteur, 14, DOUX, null, true))
	colonne.add_child(_filet())
	var miennes: Array = f.mes_obligations(club)
	for r in f.OBLIGATIONS.size():
		colonne.add_child(_rangee(r + 1, miennes, facteur))
	colonne.add_child(_filet())
	_ligne_etat = _mot(_etat_texte(), 15, DOUX, null, true)
	colonne.add_child(_ligne_etat)
	var bas := _pied(colonne)
	bas.add_child(_bouton("Refermer le registre  (Échap)", func(): closed.emit()))


func _rangee(rang: int, miennes: Array, facteur: float) -> Control:
	var f := foot()
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 10)
	h.add_theme_constant_override("v_separation", 4)
	var p: Dictionary = f.porteur(club, rang)
	var titre := _mot("n° %d  ·  %s crédits  ·  %s par journée" % [rang, Game.fmt(f.valeur(rang)), Game.fmt(int(round(f.dividende_de(rang) * facteur)))], 16, CRAIE, Polices.gras())
	titre.custom_minimum_size.x = 300 if _etroit() else 380
	h.add_child(titre)
	if p.is_empty():
		var b := _bouton("Prendre", func(): agir(f.prendre(club, rang)), 15)
		b.name = "Prendre_%d" % rang
		b.disabled = Game.credits < f.valeur(rang)
		h.add_child(b)
		# L'échange, depuis la plus grosse des siennes qui soit plus petite que celle-ci.
		var bas := -1
		for m in miennes:
			if int(m) < rang:
				bas = maxi(bas, int(m))
		if bas > 0:
			var e := _bouton("Échanger la n° %d  (+%s)" % [bas, Game.fmt(f.valeur(rang) - f.valeur(bas))], func(): agir(f.echanger(club, bas, rang)), 15)
			e.name = "Echanger_%d" % rang
			e.disabled = Game.credits < f.valeur(rang) - f.valeur(bas)
			h.add_child(e)
	elif bool(p.moi):
		h.add_child(_mot("à vous", 15, OR))
		var r := _bouton("Rendre  (%s)" % Game.fmt(int(round(f.valeur(rang) * f.RACHAT))), func(): agir(f.rendre(club, rang)), 15)
		r.name = "Rendre_%d" % rang
		h.add_child(r)
	else:
		h.add_child(_mot("tenue par %s" % str(p.nom), 15, DOUX))
	return h


## Après un acte au registre : la fenêtre se refait, et dit ce qui a coincé s'il y a lieu.
func agir(r: Dictionary) -> void:
	remplir(_colonne)
	if not r.get("ok", false) and _ligne_etat != null:
		_ligne_etat.text = {"credits": "Il vous manque des crédits pour celle-là.", "prise": "Quelqu'un l'a prise avant vous.",
			"absente": "Celle-là n'est pas à vous.", "rang": "Il n'y a pas d'obligation de ce rang."}.get(str(r.get("raison", "")), "Maître Garnier fait non de la tête.")


func _etat_texte() -> String:
	var f := foot()
	var inv: int = f.investi(club)
	if inv <= 0:
		return "Vous n'avez rien dans le club. Vous avez %s crédits." % Game.fmt(Game.credits)
	var dus: Array = f.dividendes_dus()
	var attendu := 0
	for d in dus:
		attendu += int(d.net)
	var suite := " ; %s de dividendes attendent la prochaine visite au club ou à l'étude" % Game.fmt(attendu) if attendu != 0 else ""
	return "Vous avez %s crédits dans le club, %s de dividendes touchés depuis le début%s. Vous avez %s crédits." % [Game.fmt(inv), Game.fmt(int(f.dividendes_total)), suite, Game.fmt(Game.credits)]
