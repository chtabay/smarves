class_name FootCauserie
extends FootTableau
## La causerie du président : un personnage, pas un pupitre (demande de Guillaume du 18 octobre 2026 : « le
## pilotage ne se fait pas avec le président, il se fait plutôt dans le bureau »). Il dit où en est le club,
## ce qu'il attend du prochain match, qui parle pour le club (les obligations), et renvoie au bureau, où se
## décident la tactique, la composition, les rôles et le marché.
##
## Elle emprunte au tableau du dimanche son ardoise et ses petites pièces ; s'ouvre et se ferme comme
## lui (signal closed, Échap).

## Le joueur veut passer au bureau (le stade ouvre le siège du club).
signal bureau

## Le club dont on parle (l'id du registre), et son prochain match.
var club := ""
var rencontre := {}


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
	for phrase in paroles():
		colonne.add_child(_mot(phrase, 17, CRAIE, null, true))
	colonne.add_child(_filet())
	if not f.actionnaires(club).is_empty():
		colonne.add_child(_mot(str(f.phrase_actionnaires(club)), 15, OR, null, true))
	colonne.add_child(_mot("« Pour la tactique, la composition et le marché, c'est au bureau que ça se passe : la porte à côté de la buvette. »", 15, DOUX, null, true))
	var bas := _pied(colonne)
	var b := _bouton("Passer au bureau", func(): bureau.emit())
	b.name = "Bureau"
	bas.add_child(b)
	bas.add_child(_bouton("Laisser le président  (Échap)", func(): closed.emit()))


## Ce que le président dit du club : le championnat, le dernier match, le prochain. Entre guillemets, à
## la première personne, dans un ordre tiré de la journée pour qu'il ne répète pas la même chose.
func paroles() -> Array:
	var f := foot()
	var out: Array = []
	var place: Array = f.place_de(club)
	if place.is_empty():
		out.append("« Notre club entre dans le championnat à la saison prochaine. D'ici là, on s'entraîne. »")
		return out
	var groupe: Array = f.niveaux[place[0]][place[1]]
	if groupe.size() < 2:
		out.append("« Nous sommes seuls en %s pour l'instant : le championnat attend qu'une autre commune déclare son terrain. On s'entraîne, et on garde la forme. »" % f.nom_division(place[0], place[1]))
		return out
	var joues: int = f.journee_jouee()
	var cl: Array = f.classement(f.saison, place[0], place[1])
	var rang := 0
	for i in cl.size():
		if cl[i].club == club:
			rang = i + 1
	if joues > 0 and rang > 0:
		var l: Dictionary = cl[rang - 1]
		var ou := "en tête" if rang == 1 else ("derniers" if rang == cl.size() else "%ds" % rang if rang != 2 else "deuxièmes")
		out.append("« Après %d journée%s, nous sommes %s de la %s, avec %d point%s. %s »" % [joues, "s" if joues > 1 else "", ou, f.nom_division(place[0], place[1]),
			int(l.pts), "s" if int(l.pts) > 1 else "", "Je ne demande rien de plus." if rang == 1 else ("Il va falloir se réveiller." if rang == cl.size() else "On peut mieux faire.")])
		var dernier := _dernier(f, joues)
		if not dernier.is_empty():
			var nous: int = dernier.score[0] if dernier.dom == club else dernier.score[1]
			var eux: int = dernier.score[1] if dernier.dom == club else dernier.score[0]
			var adv: String = dernier.ext if dernier.dom == club else dernier.dom
			var mot := "une belle victoire" if nous > eux else ("un match nul qui laisse des regrets" if nous == eux else "une défaite qui fait mal")
			out.append("« Dimanche dernier, %d à %d contre %s : %s. »" % [nous, eux, str(f.clubs.get(adv, {}).get("nom", adv)), mot])
	else:
		out.append("« La saison n'a pas commencé : tout reste à écrire. »")
	if rencontre.is_empty():
		out.append("« Le calendrier de la saison qui vient n'est pas encore tiré. »")
	else:
		var adv: String = rencontre.ext if rencontre.dom == club else rencontre.dom
		out.append("« Prochain match : journée %d, %s à %d h, %s contre %s. %s »" % [rencontre.j, date(rencontre.quand), f.HEURE_COUP_ENVOI,
			"à domicile" if rencontre.dom == club else "en déplacement", str(f.clubs.get(adv, {}).get("nom", adv)),
			"Devant nos supporters, pas le droit de décevoir." if rencontre.dom == club else "Un point là-bas serait déjà bien."])
	return out


## Le dernier match joué du club : {dom, ext, score}, ou {}.
func _dernier(f: Node, joues: int) -> Dictionary:
	var place: Array = f.place_de(club)
	for j in range(joues, 0, -1):
		for m in f.journee(f.saison, place[0], place[1], j, joues):
			if (m.dom == club or m.ext == club) and not m.score.is_empty():
				return m
	return {}
