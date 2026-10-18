class_name FootLocaux
extends FootTableau
## Les locaux du club (docs/SUITE.md, section 6) : le siège, à côté de la buvette du stade, en attendant le
## bureau pleine page du fil « Bureau du club et mercato » (scripts/socle/bureau.gd), que le stade ouvre à sa
## place dès qu'il existe. D'ici là : le mercato, le registre des obligations, un mot du président ; et le
## siège dit où en est le club, qui le dirige, ce que les obligations ont versé. Demande de Guillaume du
## 18 octobre : « le pilotage ne se fait pas avec le président, il se fait plutôt dans le bureau ».
##
## Elle emprunte au tableau du dimanche son ardoise et ses petites pièces ; s'ouvre et se ferme comme
## lui (signal closed, Échap).

signal causerie
signal mercato
signal obligations

var club := ""


func _ready() -> void:
	_preparer()
	remplir(_colonne)


func remplir(colonne: VBoxContainer) -> void:
	_vider(colonne)
	var f := foot()
	var c: Dictionary = f.clubs.get(club, {})
	colonne.add_child(_mot("L E S   L O C A U X   D U   C L U B", 13, DOUX))
	colonne.add_child(_mot(str(c.get("nom", "Le club")), 26 if _etroit() else 34, CRAIE, Polices.titre(), _etroit()))
	var place: Array = f.place_de(club)
	if not place.is_empty():
		var cl: Array = f.classement(f.saison, place[0], place[1])
		for i in cl.size():
			if cl[i].club == club:
				colonne.add_child(_mot("%s  ·  %s, %d point%s après %d journée%s." % [f.nom_division(place[0], place[1]), _rang(i + 1), int(cl[i].pts), "s" if int(cl[i].pts) > 1 else "", int(cl[i].j), "s" if int(cl[i].j) > 1 else ""], 16, CRAIE, null, true))
	var r: Dictionary = f.prochain_match(club)
	if not r.is_empty():
		var adv: String = r.ext if r.dom == club else r.dom
		colonne.add_child(_mot("Prochain match : journée %d, %s à %d h, %s contre %s." % [r.j, date(r.quand), f.HEURE_COUP_ENVOI, "à domicile" if r.dom == club else "en déplacement", str(f.clubs[adv].nom)], 16, CRAIE, null, true))
	colonne.add_child(_filet())
	colonne.add_child(_mot("La direction", 15, DOUX))
	colonne.add_child(_mot(str(f.phrase_actionnaires(club)), 16, OR, null, true))
	var inv: int = f.investi(club)
	if inv > 0:
		var dus := 0
		for d in f.dividendes_dus():
			if d.club == club:
				dus += int(d.net)
		colonne.add_child(_mot("Vous avez %s crédits dans le club ; %s de dividendes touchés depuis le début%s." % [Game.fmt(inv), Game.fmt(int(f.dividendes_total)), ", %s à venir" % Game.fmt(dus) if dus != 0 else ""], 15, CRAIE, null, true))
	var t: Dictionary = f.transfert_de(f.saison, club)
	if t.etat != "aucune" and not t.joueur.is_empty():
		colonne.add_child(_mot("La recrue de la saison : %s %s, %s, note %d." % [t.joueur.prenom, t.joueur.nom, FootMatch.POSTES.get(t.joueur.poste, t.joueur.poste), int(t.joueur.note)], 15, CRAIE, null, true))
	colonne.add_child(_filet())
	colonne.add_child(_mot("Le bureau", 15, DOUX))
	var rang := HFlowContainer.new()
	rang.add_theme_constant_override("h_separation", 10)
	rang.add_theme_constant_override("v_separation", 6)
	colonne.add_child(rang)
	var b1 := _bouton("Un mot du président", func(): causerie.emit())
	b1.name = "Causerie"
	rang.add_child(b1)
	var b2 := _bouton("Le mercato" + ("  ·  ouvert" if f.mercato_ouvert(f.saison) else ""), func(): mercato.emit())
	b2.name = "Mercato"
	rang.add_child(b2)
	var b3 := _bouton("Le registre des obligations", func(): obligations.emit())
	b3.name = "Obligations"
	rang.add_child(b3)
	colonne.add_child(_mot("C'est ici que le club se dirige : le président commente, il ne décide pas. La tactique complète (le onze sur le terrain, les rôles) arrive avec le bureau.", 14, DOUX, null, true))
	var bas := _pied(colonne)
	bas.add_child(_bouton("Refermer la porte  (Échap)", func(): closed.emit()))


static func _rang(i: int) -> String:
	return "1er" if i == 1 else "%de" % i
