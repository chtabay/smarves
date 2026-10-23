class_name FootCourrier
extends RefCounted
## Ce que le bureau du club raconte de lui-même (demande de Guillaume du 23 octobre 2026 : un bureau
## « réellement addictif, à la Football Manager ») : le courrier de l'accueil, le rapport de l'adjoint sur le
## prochain adversaire, l'objectif que la direction fixe pour la saison et sa confiance. Rien n'est inventé à
## part : tout se lit dans Football (les matchs joués, les effectifs, l'entraînement de chaque semaine, les
## consignes), donc chacun lit le même courrier pour le même club.
##
## Un message : {id, quand (horodatage), titre, texte, page (la page du bureau où il mène, ou ""), bouton}.
## Seul ce qu'on a lu reste propre à l'appareil (le bureau le garde).


## Le match d'un club à une journée : {dom, ext, score} (score vide s'il n'est pas joué), ou {}.
static func match_de(f: Node, club: String, s: int, j: int) -> Dictionary:
	var place: Array = f.place_de(club)
	if place.is_empty():
		return {}
	for m in f.journee(s, place[0], place[1], j):
		if m.dom == club or m.ext == club:
			return m
	return {}


## « Victoire 2-1 », « Nul 0-0 », « Défaite 1-3 », le score de notre côté d'abord.
static func issue(m: Dictionary, club: String) -> Dictionary:
	var nous: int = 0 if m.dom == club else 1
	var a: int = m.score[nous]
	var b: int = m.score[1 - nous]
	return {"lettre": "V" if a > b else ("N" if a == b else "D"), "mot": "Victoire" if a > b else ("Nul" if a == b else "Défaite"), "pour": a, "contre": b,
		"adv": m.ext if nous == 0 else m.dom, "domicile": nous == 0}


## La forme d'un club : ses cinq derniers résultats de la saison, du plus ancien au plus récent (« VNDVV »).
static func forme(f: Node, club: String, n := 5) -> String:
	var out := ""
	for k in range(1, int(f.journee_jouee()) + 1):
		var m := match_de(f, club, f.saison, k)
		if not m.is_empty() and not (m.score as Array).is_empty():
			out += str(issue(m, club).lettre)
	return out.right(n)


# ---------------------------------------------------------------- l'objectif de la direction

## L'objectif de la saison, d'après la force des clubs du groupe (Football.force) : {place (la place visée),
## attendue (où la force nous met), taille, titre, phrase}.
static func objectif(f: Node, club: String) -> Dictionary:
	var place: Array = f.place_de(club)
	if place.is_empty():
		return {}
	var groupe: Array = (f.niveaux[place[0]][place[1]] as Array).duplicate()
	var forces := {}
	for c in groupe:
		forces[c] = float(f.force(c, f.saison))
	groupe.sort_custom(func(a, b): return forces[a] > forces[b] if forces[a] != forces[b] else str(a) < str(b))
	var n := groupe.size()
	var attendue: int = groupe.find(club) + 1
	var out := {"attendue": attendue, "taille": n}
	if n <= 1:
		out.merge({"place": 1, "titre": "Jouer", "phrase": "Le club est seul inscrit : la direction attend un adversaire."})
	elif attendue == 1:
		out.merge({"place": 1, "titre": "La montée", "phrase": "Sur le papier, c'est le meilleur effectif du groupe. La direction veut la première place, celle qui fait monter."})
	elif attendue <= maxi(1, n / 2):
		out.merge({"place": maxi(1, n / 2), "titre": "La première moitié", "phrase": "L'effectif est parmi les bons du groupe. La direction veut finir dans la première moitié, %s au pire." % FootLocaux._rang(maxi(1, n / 2))})
	else:
		var p: int = n - int(f.DESCENDENT)
		if p >= 2:
			out.merge({"place": p, "titre": "Le maintien", "phrase": "L'effectif est parmi les plus modestes du groupe. La direction veut le maintien : finir %s ou mieux." % FootLocaux._rang(p)})
		else:
			out.merge({"place": n, "titre": "Progresser", "phrase": "L'effectif est le plus modeste du groupe. La direction demande de progresser, match après match."})
	return out


## La confiance de la direction, de 0 à 100, et ce qu'elle en dit : la place du moment contre la place visée,
## et la forme récente. Avant le premier match, elle attend.
static func confiance(f: Node, club: String) -> Dictionary:
	var obj := objectif(f, club)
	var place: Array = f.place_de(club)
	if obj.is_empty() or place.is_empty():
		return {}
	if int(f.journee_jouee()) <= 0:
		return {"valeur": 60, "phrase": "La direction attend le premier match."}
	var cl: Array = f.classement(f.saison, place[0], place[1])
	var rang := 0
	for i in cl.size():
		if cl[i].club == club:
			rang = i + 1
	var fo := forme(f, club)
	var bonus := 0
	for x in fo:
		bonus += 4 if x == "V" else (-4 if x == "D" else 0)
	var v := clampi(65 - 14 * (rang - int(obj.place)) + bonus, 5, 100)
	var phrase := "La direction est ravie." if v >= 85 else ("La direction est satisfaite." if v >= 60 else ("La direction s'interroge." if v >= 40 else "La direction s'impatiente."))
	return {"valeur": v, "rang": rang, "phrase": phrase}


# ---------------------------------------------------------------- le rapport de l'adjoint

## Le rapport sur le prochain adversaire, essai : la consigne qu'on prépare (ou {} pour la consigne posée).
## {adv, nom, domicile, forme, rang, formation (celle de son dernier match), meilleur {nom, poste, note},
## nous, eux (FootMatch.secteurs), duels [{secteur, nous, eux, titre}], conseils [phrases]}, ou {}.
static func rapport(f: Node, club: String, essai := {}) -> Dictionary:
	var r: Dictionary = f.prochain_match(club)
	if r.is_empty():
		return {}
	var s: int = r.s
	var j: int = r.j
	var adv: String = r.ext if r.dom == club else r.dom
	# La formation de l'adversaire : celle de son dernier match joué, l'adjoint ne lit pas dans les têtes.
	var leur := {}
	for k in range(j - 1, 0, -1):
		var d: Dictionary = f.decisions.get("%d/%d/%s" % [s, k, adv], {})
		if not d.is_empty():
			leur = {"formation": d.get("formation", "4-4-2"), "mentalite": d.get("mentalite", "equilibree"), "pressing": d.get("pressing", "normal")}
			break
	var nous: Dictionary = f.secteurs_du_jour(s, j, club, essai if not essai.is_empty() else null)
	var eux: Dictionary = f.secteurs_du_jour(s, j, adv, leur)
	var e: Dictionary = f.effectif(adv, s, j)
	var meilleur := {}
	for id in e:
		if meilleur.is_empty() or float(e[id].note) > float(meilleur.note):
			meilleur = e[id]
	var place: Array = f.place_de(adv)
	var rang := 0
	if not place.is_empty() and int(f.journee_jouee()) > 0 and s == f.saison:
		var cl: Array = f.classement(s, place[0], place[1])
		for i in cl.size():
			if cl[i].club == adv:
				rang = i + 1
	var duels: Array = [
		{"secteur": "milieu", "titre": "Le milieu", "nous": float(nous.milieu), "eux": float(eux.milieu)},
		{"secteur": "gauche", "titre": "Notre attaque à gauche", "nous": float(nous.attaque_gauche), "eux": float(eux.defense_gauche)},
		{"secteur": "centre", "titre": "Notre attaque au centre", "nous": float(nous.attaque_centre), "eux": float(eux.defense_centre)},
		{"secteur": "droite", "titre": "Notre attaque à droite", "nous": float(nous.attaque_droite), "eux": float(eux.defense_droite)},
		{"secteur": "def_gauche", "titre": "Notre défense à gauche", "nous": float(nous.defense_gauche), "eux": float(eux.attaque_gauche)},
		{"secteur": "def_centre", "titre": "Notre défense au centre", "nous": float(nous.defense_centre), "eux": float(eux.attaque_centre)},
		{"secteur": "def_droite", "titre": "Notre défense à droite", "nous": float(nous.defense_droite), "eux": float(eux.attaque_droite)},
	]
	return {"adv": adv, "nom": str(f.clubs.get(adv, {}).get("nom", adv)), "domicile": r.dom == club, "forme": forme(f, adv), "rang": rang,
		"formation": str(leur.get("formation", "")), "meilleur": meilleur, "nous": nous, "eux": eux, "duels": duels, "conseils": conseils(duels)}


## Ce que l'adjoint en tire : où l'on est le plus fort, où l'on souffrira, et ce qu'il ferait.
static func conseils(duels: Array) -> Array:
	var out: Array = []
	var attaques: Array = duels.filter(func(d): return d.secteur in ["gauche", "centre", "droite"])
	var defenses: Array = duels.filter(func(d): return str(d.secteur).begins_with("def_"))
	attaques.sort_custom(func(a, b): return a.nous / maxf(a.eux, 1.0) > b.nous / maxf(b.eux, 1.0))
	defenses.sort_custom(func(a, b): return a.nous / maxf(a.eux, 1.0) < b.nous / maxf(b.eux, 1.0))
	var milieu: Dictionary = duels[0]
	var rm: float = milieu.nous / maxf(milieu.eux, 1.0)
	if rm >= 1.08:
		out.append("Nous devrions avoir le ballon : notre milieu est plus fort que le leur. Une mentalité offensive en profiterait.")
	elif rm <= 0.92:
		out.append("Leur milieu est plus fort : ils auront le ballon. Un milieu de plus (4-5-1, 3-5-2) ou un pressing haut pour le leur disputer.")
	else:
		out.append("Le milieu s'équilibre : le match se jouera dans les couloirs.")
	var a: Dictionary = attaques[0]
	var cote := {"gauche": "à gauche", "centre": "dans l'axe", "droite": "à droite"}
	if a.nous / maxf(a.eux, 1.0) >= 1.1:
		out.append("Leur défense est la plus friable %s : c'est par là qu'il faut passer (un joueur offensif dans ce couloir)." % cote[a.secteur])
	else:
		out.append("Leur défense tient partout ; c'est %s qu'elle cède le plus." % cote[a.secteur])
	var d: Dictionary = defenses[0]
	var cote_def := {"def_gauche": "à gauche", "def_centre": "dans l'axe", "def_droite": "à droite"}
	if d.nous / maxf(d.eux, 1.0) <= 0.9:
		out.append("Attention %s : leur attaque y est plus forte que notre défense. Un défenseur de plus, ou une consigne défensive pour le joueur du couloir." % cote_def[d.secteur])
	return out


# ---------------------------------------------------------------- le courrier

## Les messages du club, le plus récent d'abord : les comptes rendus des matchs joués de la saison, les progrès
## de l'entraînement, le rapport de l'adjoint et ce qui reste à faire avant le prochain match, l'objectif.
static func messages(f: Node, club: String) -> Array:
	var out: Array = []
	var s: int = f.saison
	var place: Array = f.place_de(club)
	if place.is_empty():
		return out
	var obj := objectif(f, club)
	if not obj.is_empty():
		out.append({"id": "objectif/%d" % s, "quand": int(f.coup_envoi(s, 1)) - 6 * 86400, "titre": "La direction : l'objectif de la saison, %s" % str(obj.titre).to_lower(),
			"texte": str(obj.phrase), "page": "", "bouton": ""})
	var jouee: int = int(f.journee_jouee()) if s == f.saison else 0
	for k in range(1, jouee + 1):
		var m := match_de(f, club, s, k)
		if m.is_empty() or (m.score as Array).is_empty():
			continue
		out.append(compte_rendu(f, club, s, k, m))
		var p := progres(f, club, s, k)
		if not p.is_empty():
			out.append(p)
	var r: Dictionary = f.prochain_match(club)
	# Ce qui reste à faire avant le match est daté au plus tard d'aujourd'hui.
	var maintenant: int = f.maintenant()
	if not r.is_empty():
		var rap := rapport(f, club)
		if not rap.is_empty():
			var texte := "%s%s. %s" % ["Forme récente : %s. " % str(rap.forme) if str(rap.forme) != "" else "", "Son meilleur joueur : %s %s (%s, note %d)" % [rap.meilleur.get("prenom", ""), rap.meilleur.get("nom", ""), FootMatch.POSTES.get(str(rap.meilleur.get("poste", "")), "").to_lower(), int(rap.meilleur.get("note", 0))], " ".join(rap.conseils)]
			out.append({"id": "rapport/%d/%d" % [r.s, r.j], "quand": mini(int(f.coup_envoi(r.s, r.j)) - 4 * 86400, maintenant), "titre": "L'adjoint : rapport sur %s" % rap.nom,
				"texte": texte, "page": "adversaire", "bouton": "Lire le rapport"})
		if f.peut_decider(club):
			var c: Dictionary = f.consigne_de(r.s, r.j, club)
			if not c.consigne.has("entrainement"):
				out.append({"id": "programme/%d/%d" % [r.s, r.j], "quand": mini(int(f.coup_envoi(r.s, r.j)) - 6 * 86400, maintenant), "titre": "L'adjoint attend le programme de la semaine",
					"texte": "Sans programme, les joueurs font du général : un peu de tout, rien de poussé. Un programme ciblé fait progresser les jeunes d'un cran en six ou sept semaines.",
					"page": "entrainement", "bouton": "Choisir le programme"})
			if c.etat == "aucune":
				out.append({"id": "compo/%d/%d" % [r.s, r.j], "quand": mini(int(f.coup_envoi(r.s, r.j)) - 2 * 86400, maintenant), "titre": "La composition de dimanche n'est pas posée",
					"texte": "Sans consigne, l'adjoint aligne l'équipe type en 4-4-2, mentalité équilibrée.", "page": "tactique", "bouton": "Préparer la tactique"})
	out.sort_custom(func(a, b): return int(a.quand) > int(b.quand) if int(a.quand) != int(b.quand) else str(a.id) < str(b.id))
	return out


## Le compte rendu d'un match joué : le score, les buteurs, l'homme du match (la meilleure note de chez nous).
static func compte_rendu(f: Node, club: String, s: int, k: int, m: Dictionary) -> Dictionary:
	var etat: Dictionary = f.rencontre(s, k, m.dom, m.ext)
	var i := issue(m, club)
	var nous: int = 0 if m.dom == club else 1
	var joueurs := {}
	joueurs.merge(f.effectif(m.dom, s, k))
	joueurs.merge(f.effectif(m.ext, s, k))
	var buteurs: Array = []
	for b in etat.get("buts", []):
		if int(b.equipe) == nous and joueurs.has(b.buteur):
			buteurs.append("%s (%s)" % [FootMatch.nom_court(joueurs[b.buteur]), b.minute])
	var notes: Dictionary = etat.equipes[nous].get("notes", {})
	var homme := ""
	var meilleure := -1.0
	for id in notes:
		if float(notes[id]) > meilleure and joueurs.has(id):
			meilleure = float(notes[id])
			homme = id
	var adv_nom := str(f.clubs.get(i.adv, {}).get("nom", i.adv))
	var texte := "Journée %d, %s %s : %d-%d." % [k, "contre" if i.domicile else "chez", adv_nom, i.pour, i.contre]
	texte += (" Nos buts : %s." % ", ".join(buteurs)) if not buteurs.is_empty() else " Aucun but de notre côté."
	if homme != "":
		texte += " Le meilleur des nôtres : %s %s (%.1f)." % [joueurs[homme].prenom, joueurs[homme].nom, meilleure]
	return {"id": "match/%d/%d" % [s, k], "quand": int(f.coup_envoi(s, k)) + 2 * 3600, "titre": "%s %d-%d %s %s" % [i.mot, i.pour, i.contre, "contre" if i.domicile else "chez", adv_nom],
		"texte": texte, "page": "championnat", "bouton": "Le classement"}


## Les progrès d'une semaine d'entraînement (celle de la journée k, qui compte après le match) : chaque cran
## passé par un joueur du club. {} si personne n'a passé de cran.
static func progres(f: Node, club: String, s: int, k: int) -> Dictionary:
	if k >= int(f.JOURNEES):
		return {}
	var avant: Dictionary = f.effectif(club, s, k)
	var apres: Dictionary = f.effectif(club, s, k + 1)
	var lignes: Array = []
	for id in apres:
		if not avant.has(id):
			continue
		for c in FootEntrainement.crans_gagnes(avant[id], apres[id]):
			lignes.append("%s %s, %s : %d → %d" % [apres[id].prenom, apres[id].nom, str(FootMatch.COMPETENCES[c.competence]).to_lower(), c.avant, c.apres])
	if lignes.is_empty():
		return {}
	var prog: String = f.programmes(club, s, k)[k - 1]
	return {"id": "progres/%d/%d" % [s, k], "quand": int(f.coup_envoi(s, k)) + 3 * 3600,
		"titre": "L'entraînement : %d progrès cette semaine" % lignes.size() if lignes.size() > 1 else "L'entraînement : un progrès cette semaine",
		"texte": "Programme %s. %s." % [str(FootEntrainement.PROGRAMMES[prog].nom).to_lower(), " ; ".join(lignes)], "page": "entrainement", "bouton": "L'entraînement"}
