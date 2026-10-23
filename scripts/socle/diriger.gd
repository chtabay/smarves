extends RefCounted
## Ce qu'il faut pour diriger un club, calculé pour le joueur (demande de Guillaume du 23 octobre : une
## gestion accessible dès les premiers gains). Le football et le basket ont les mêmes règles : neuf
## obligations, chacune en un exemplaire ; celui qui a mis le plus décide, et l'égalité suffit. Plutôt que
## d'aligner « Lucien 2 250, vous 500 » et de laisser la soustraction au joueur, on la fait ici, et l'on
## dit quelle obligation libre y suffit. `moteur` est l'autoload Football ou Basket.


## {dirige, mien, tete (le premier des autres, ou ""), sa_mise, manque, suffit (le rang libre le moins cher
## qui suffit, 0 sinon), libres (les rangs libres)}.
static func etat(moteur: Node, club: String) -> Dictionary:
	var a: Array = moteur.actionnaires(club)
	var mien: int = moteur.investi(club)
	var tete := ""
	var sa_mise := 0
	for x in a:
		if not bool(x.moi):
			tete = str(x.nom)
			sa_mise = int(x.investi)
			break
	var libres: Array = []
	for r in range(1, moteur.OBLIGATIONS.size() + 1):
		if moteur.porteur(club, r).is_empty():
			libres.append(r)
	var manque := maxi(0, sa_mise - mien)
	var suffit := 0
	for r in libres:
		if moteur.valeur(r) >= manque and (manque > 0 or mien == 0):
			suffit = r
			break
	return {"dirige": bool(moteur.peut_decider(club)) and mien > 0, "mien": mien, "tete": tete, "sa_mise": sa_mise,
		"manque": manque, "suffit": suffit, "libres": libres, "personne": a.is_empty()}


## La phrase à afficher : ce qui manque et comment le combler, ou l'avance qu'on a.
static func phrase(moteur: Node, club: String) -> String:
	var e := etat(moteur, club)
	if e.personne:
		return "Personne ne tient de part : la n° 1, à %s crédits, vous fait dirigeant." % Game.fmt(moteur.valeur(1)) if e.libres.has(1) \
			else "Personne ne tient de part : la première prise fait son porteur dirigeant."
	if e.dirige:
		if e.tete == "":
			return "Vous dirigez le club, seul porteur."
		var avance: int = int(e.mien) - int(e.sa_mise)
		return "Vous dirigez le club ; %s est %s." % [e.tete, "à égalité : une obligation de plus vous mettrait devant" if avance == 0 else "à %s crédits derrière" % Game.fmt(avance)]
	var t := "Il vous manque %s crédits de parts pour diriger (%s en a %s)" % [Game.fmt(int(e.manque)), e.tete, Game.fmt(int(e.sa_mise))]
	if int(e.suffit) > 0:
		return t + " : la n° %d, à %s, y suffit." % [e.suffit, Game.fmt(moteur.valeur(e.suffit))]
	if e.libres.is_empty():
		return t + " : toutes les obligations sont prises."
	return t + " : il y faut plusieurs obligations."


## Le texte d'un bouton « Prendre » qu'on ne peut pas payer : ce qui manque.
static func manque_credits(prix: int) -> String:
	return "il manque %s" % Game.fmt(prix - Game.credits)


## « de » devant le nom d'un club : « des Hérons du Clain », « de l'Étoile de Smarves », « du Racing ».
static func de(nom: String) -> String:
	for x in [["Les ", "des "], ["Le ", "du "], ["La ", "de la "], ["L'", "de l'"], ["L’", "de l’"]]:
		if nom.begins_with(x[0]):
			return x[1] + nom.substr(x[0].length())
	return "de " + nom
