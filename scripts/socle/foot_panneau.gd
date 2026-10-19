class_name FootPanneau
extends FootObligations
## Le panneau du club, à l'entrée du stade (demande de Guillaume du 19 octobre 2026 : « que les parts
## possédées par les différents joueurs soient visibles à l'entrée du stade dans un panneau qui permet
## d'avoir les éléments essentiels du club, même si on ne le dirige pas ; c'est aussi une interface qui
## permet l'achat de parts »). Pour qui passe la grille, l'essentiel : le nom du club, sa place, le
## prochain match, le dernier résultat, qui tient quelles obligations et qui dirige ; puis le registre,
## les mêmes lignes qu'à l'étude de Maître Garnier, pour en prendre une sans entrer au siège.
##
## Même ardoise que le registre (FootObligations) : s'ouvre et se ferme comme lui (signal closed, Échap).


func remplir(colonne: VBoxContainer) -> void:
	_vider(colonne)
	var f := foot()
	var c: Dictionary = f.clubs.get(club, {})
	colonne.add_child(_mot("L E   P A N N E A U   D U   C L U B", 13, DOUX))
	colonne.add_child(_mot(str(c.get("nom", "Le club")), 26 if _etroit() else 34, CRAIE, Polices.titre(), _etroit()))
	if c.is_empty():
		colonne.add_child(_mot("Le club attend d'entrer au championnat.", 16, CRAIE, null, true))
	else:
		for ligne in essentiel():
			colonne.add_child(_mot(str(ligne), 16, CRAIE, null, true))
	colonne.add_child(_filet())
	colonne.add_child(_mot("Les porteurs d'obligations", 15, DOUX))
	var porteurs: Array = f.actionnaires(club)
	if porteurs.is_empty():
		colonne.add_child(_mot("Personne ne tient d'obligation du club : le président écoute tout le monde.", 16, OR, null, true))
	for i in porteurs.size():
		var x: Dictionary = porteurs[i]
		var rangs: Array = x.rangs.map(func(r): return "n° %d" % int(r))
		var texte := "%s  ·  %s crédits  ·  %s" % ["Vous" if bool(x.moi) else str(x.nom), Game.fmt(int(x.investi)), ", ".join(rangs)]
		if i == 0:
			texte += "  ·  dirige le club"
		var l := _mot(texte, 16, OR if bool(x.moi) else CRAIE, null, true)
		l.name = "Porteur_%d" % (i + 1)
		colonne.add_child(l)
	colonne.add_child(_filet())
	colonne.add_child(_mot("Le registre : prendre une obligation", 15, DOUX))
	var facteur: float = f.recette_facteur(club)
	colonne.add_child(_mot("Une obligation verse 50 crédits par cran à chaque journée jouée, ×%.1f au classement d'aujourd'hui. L'étude reprend à 80 %%, et une plus grosse s'échange contre une des vôtres pour la différence." % facteur, 14, DOUX, null, true))
	var miennes: Array = f.mes_obligations(club)
	for r in f.OBLIGATIONS.size():
		colonne.add_child(_rangee(r + 1, miennes, facteur))
	colonne.add_child(_filet())
	_ligne_etat = _mot(_etat_texte(), 15, DOUX, null, true)
	colonne.add_child(_ligne_etat)
	var bas := _pied(colonne)
	bas.add_child(_bouton("Quitter le panneau  (Échap)", func(): closed.emit()))


## L'essentiel du club, une phrase par ligne : sa place, le prochain match, le dernier résultat.
func essentiel() -> Array:
	var f := foot()
	var out: Array = []
	var place: Array = f.place_de(club)
	if place.is_empty():
		return out
	var cl: Array = f.classement(f.saison, place[0], place[1])
	for i in cl.size():
		if cl[i].club == club:
			out.append("%s  ·  %s, %d point%s après %d journée%s." % [f.nom_division(place[0], place[1]), FootLocaux._rang(i + 1), int(cl[i].pts), "s" if int(cl[i].pts) > 1 else "", int(cl[i].j), "s" if int(cl[i].j) > 1 else ""])
	var dernier := _dernier(place)
	if not dernier.is_empty():
		out.append("Dernier match : journée %d, %s %d - %d %s." % [dernier.j, f.clubs[dernier.dom].nom, dernier.score[0], dernier.score[1], f.clubs[dernier.ext].nom])
	var r: Dictionary = f.prochain_match(club)
	if r.is_empty():
		out.append("Pas de match à venir : le championnat attend un deuxième club." if cl.size() < 2 else "Pas de match avant la saison qui vient.")
	else:
		var adv: String = r.ext if r.dom == club else r.dom
		out.append("Prochain match : journée %d, %s à %d h, %s contre %s." % [r.j, date(r.quand), f.HEURE_COUP_ENVOI, "à domicile" if r.dom == club else "en déplacement", str(f.clubs[adv].nom)])
	return out


## Le dernier match joué du club cette saison : {j, dom, ext, score}, ou {}.
func _dernier(place: Array) -> Dictionary:
	var f := foot()
	var jouee: int = f.journee_jouee()
	for j in range(jouee, 0, -1):
		for m in f.journee(f.saison, place[0], place[1], j):
			if (m.dom == club or m.ext == club) and not m.score.is_empty():
				return {"j": j, "dom": m.dom, "ext": m.ext, "score": m.score}
	return {}
