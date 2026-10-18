class_name FootMercato
extends FootTableau
## Le mercato du président : la semaine qui précède la première journée, le club de la commune peut
## recruter un joueur libre (docs/SUITE.md, section 6). Douze joueurs libres par saison, les mêmes chez
## tout le monde, avec leur poste, leur âge, leur note et leur prix ; une recrue par club et par saison,
## qui prend la place du plus faible de son poste ; un libre ne part qu'une fois. C'est celui qui parle
## pour le club (le premier actionnaire) qui recrute, avec ses propres crédits : le club n'a pas de
## caisse, il a des actionnaires. Connecté, la recrue part au serveur ; sinon elle reste sur l'appareil.
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
	var s: int = f.saison
	var c: Dictionary = f.clubs.get(club, {})
	colonne.add_child(_mot("L E   M E R C A T O", 13, DOUX))
	colonne.add_child(_mot(str(c.get("nom", "Le club")), 26 if _etroit() else 34, CRAIE, Polices.titre(), _etroit()))
	var ouvert: bool = f.mercato_ouvert(s)
	if ouvert:
		colonne.add_child(_mot("Mercato ouvert jusqu'au coup d'envoi de la saison %d, %s à %d h." % [s, date(f.coup_envoi(s, 1)), f.HEURE_COUP_ENVOI], 17, OR, null, true))
	else:
		colonne.add_child(_mot("Mercato fermé. Le prochain s'ouvre le %s, pour une semaine." % date(f.prochain_mercato()), 17, CRAIE, null, true))
	var t: Dictionary = f.transfert_de(s, club)
	if t.etat != "aucune" and not t.joueur.is_empty():
		var j: Dictionary = t.joueur
		var origine := "posée par %s, elle compte pour tout le monde" % t.par if t.etat == "commune" else "sur cet appareil, en route vers le championnat"
		colonne.add_child(_mot("La recrue de la saison : %s %s, %s, %d ans, note %d (%s)." % [j.prenom, j.nom, FootMatch.POSTES.get(j.poste, j.poste), j.age, j.note, origine], 15, OR, null, true))
	if not f.actionnaires(club).is_empty():
		colonne.add_child(_mot(str(f.phrase_actionnaires(club)), 15, DOUX, null, true))
	colonne.add_child(_filet())
	colonne.add_child(_mot("Les joueurs libres de la saison %d" % s, 20, CRAIE, Polices.gras()))
	var peut: bool = ouvert and f.peut_decider(club) and t.etat == "aucune"
	for j in f.libres(s):
		colonne.add_child(_rangee(j, peut))
	colonne.add_child(_filet())
	_ligne_etat = _mot(_etat_texte(ouvert, t), 15, DOUX, null, true)
	colonne.add_child(_ligne_etat)
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_END
	bas.add_theme_constant_override("separation", 10)
	colonne.add_child(bas)
	bas.add_child(_bouton("Laisser le président  (Échap)", func(): closed.emit()))


func _rangee(j: Dictionary, peut: bool) -> Control:
	var f := foot()
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 10)
	h.add_theme_constant_override("v_separation", 4)
	var nom := _mot("%s %s" % [j.prenom, j.nom], 15, CRAIE, Polices.gras())
	nom.custom_minimum_size.x = 150 if _etroit() else 220
	h.add_child(nom)
	var fiche := _mot("%s  ·  %d ans  ·  note %d" % [FootMatch.POSTES.get(j.poste, j.poste), j.age, j.note], 14, DOUX)
	fiche.custom_minimum_size.x = 150 if _etroit() else 260
	h.add_child(fiche)
	var preneur: String = f.preneur(f.saison, int(j.rang))
	if preneur != "":
		h.add_child(_mot("parti à %s" % f.clubs.get(preneur, {}).get("nom", preneur), 14, DOUX))
	else:
		var b := _bouton("Recruter  ·  %s crédits" % Game.fmt(int(j.prix)), func(): recruter(int(j.rang)), 14)
		b.name = "Recruter_%d" % int(j.rang)
		b.disabled = not peut
		h.add_child(b)
	return h


func _etat_texte(ouvert: bool, t: Dictionary) -> String:
	var f := foot()
	if not ouvert:
		return "On regarde, on ne signe pas : le président attend la semaine du mercato."
	if not f.peut_decider(club):
		return "Le président ne recrute qu'avec son premier actionnaire. Maître Garnier cède des parts du club à l'étude."
	if t.etat != "aucune":
		return "Une recrue par saison, c'est le règlement du président. Tu as %s crédits." % Game.fmt(Game.credits)
	return "La recrue se paie de ta poche : le club n'a pas de caisse, il a des actionnaires. Tu as %s crédits." % Game.fmt(Game.credits)


## Recrute le joueur libre de ce rang, en payant son prix ; vrai si le président signe.
func recruter(rang: int) -> bool:
	var f := foot()
	var l: Array = f.libres(f.saison)
	if rang < 0 or rang >= l.size():
		return false
	var prix := int(l[rang].prix)
	if Game.credits < prix:
		if _ligne_etat != null:
			_ligne_etat.text = "Il te manque des crédits : %s pour %s %s." % [Game.fmt(prix), l[rang].prenom, l[rang].nom]
		return false
	var r: Dictionary = f.recruter(f.saison, club, rang)
	if r.ok:
		Game.credits -= prix
		Game.changed.emit()
		remplir(_colonne)
		if _ligne_etat != null:
			_ligne_etat.text = "Le président signe : %s %s arrive à l'Étoile pour %s crédits." % [l[rang].prenom, l[rang].nom, Game.fmt(prix)]
		return true
	if _ligne_etat != null:
		_ligne_etat.text = {"ferme": "Le mercato est fermé.", "parts": "Le président ne recrute qu'avec son premier actionnaire.",
			"deja": "Une recrue par saison, c'est le règlement.", "pris": "Trop tard, un autre club l'a signé."}.get(str(r.raison), "Le président fait non de la tête.")
	return false
