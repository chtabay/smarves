extends SceneTree
## Vérifie les règles de direction et le calendrier sans affichage : godot --headless --path . -s tools/test_diriger.gd
## Demande de Guillaume du 31 octobre (la relève des présidents) : les parts se prennent toute l'année ; un
## président ne dirige qu'un club à la fois ; prendre la main sur un club dirigé, ou changer de club, se
## déclare quand on veut et prend effet à la relève, le lundi à midi ; on ne change de club qu'une fois
## pendant la saison et une fois pendant l'intersaison. Et, du 23 octobre, le calendrier des championnats se
## trouve facilement (l'onglet « Le calendrier » du carnet).

var fails := 0
var t := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _textes(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		out += _textes(c)
	return out


func _init() -> void:
	await process_frame
	var diriger: GDScript = load("res://scripts/socle/diriger.gd")
	var cal: GDScript = load("res://scripts/socle/calendrier.gd")
	var foot: Node = root.get_node("Football")
	var basket: Node = root.get_node("Basket")
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	foot.dossier = ""
	foot.effacer()
	foot.regler_horloge(func(): return t)
	t = foot.coup_envoi(1, 1) - 86400
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	var ids: Array = foot.clubs.keys()
	ids.sort()
	check(ids.size() >= 2 and diriger.division(foot, ids[0]) == diriger.division(foot, ids[1]), "deux clubs dans la même division (%s)" % str(ids))
	var a: String = ids[0]
	var b: String = ids[1]

	# ---- l'intersaison
	check(diriger.en_intersaison(foot) and int(diriger.intersaison(foot)[1]) == foot.coup_envoi(1, 1), "avant la première saison, c'est l'intersaison, jusqu'au premier coup d'envoi")
	check(diriger.phrase_intersaison(foot).begins_with("jusqu'au dimanche 25 octobre à 15 h"), "et elle se dit (%s)" % diriger.phrase_intersaison(foot))
	t = foot.coup_envoi(1, 5)
	check(not diriger.en_intersaison(foot), "en pleine saison, ce n'est pas l'intersaison")
	var i: Array = diriger.intersaison(foot)
	check(int(i[0]) == foot.coup_envoi(1, 14) + 3 * 3600 and int(i[1]) == foot.coup_envoi(2, 1), "la prochaine : de la fin de la journée 14 au coup d'envoi de la saison 2")
	t = foot.coup_envoi(1, 14) + 3 * 3600
	check(diriger.en_intersaison(foot), "trois heures après le coup d'envoi de la journée 14, l'intersaison s'ouvre")
	t = foot.coup_envoi(2, 1) - 1
	check(diriger.en_intersaison(foot), "elle court jusqu'au premier coup d'envoi de la saison 2")

	# ---- la relève : le lundi à midi, strictement après ; la saison et l'intersaison
	var lundi: int = foot.coup_envoi(1, 2) + 86400 - 3 * 3600
	check(diriger.date(lundi) == "lundi 2 novembre à midi", "le lundi d'après la journée 2, à midi (%s)" % diriger.date(lundi))
	check(diriger.releve_suivante(foot.coup_envoi(1, 2)) == lundi and diriger.releve_suivante(lundi - 1) == lundi, "la relève suit le match du dimanche")
	check(diriger.releve_suivante(lundi) == lundi + 7 * 86400, "à midi pile, c'est la suivante")
	check(diriger.periode(foot, foot.coup_envoi(1, 1) - 1) == "i1" and diriger.periode(foot, foot.coup_envoi(1, 5)) == "s1", "avant la première journée, l'intersaison ; ensuite, la saison")
	check(diriger.periode(foot, foot.coup_envoi(1, 14) + 3 * 3600 - 1) == "s1" and diriger.periode(foot, foot.coup_envoi(1, 14) + 3 * 3600) == "i2", "l'intersaison s'ouvre trois heures après la journée 14")

	# ---- les parts se prennent toute l'année, et se rendent quand on veut
	t = foot.coup_envoi(1, 5)
	game.credits = 20000
	check(foot.prendre(a, 2).ok, "en pleine saison, une obligation se prend")
	check(foot.echanger(a, 2, 4).ok, "et s'échange")
	check(foot.rendre(a, 4).ok and foot.mes_obligations(a).is_empty(), "rendre, toujours")
	var fen: PanelContainer = load("res://scripts/socle/foot_obligations.gd").new()
	fen.club = a
	root.add_child(fen)
	await process_frame
	var f: Label = fen.find_child("Fenetre", true, false)
	check(f != null and f.text.contains("toute l'année") and f.text.contains("le lundi à midi"), "le registre le dit (%s)" % (f.text if f else ""))
	check(not (fen.find_child("Prendre_1", true, false) as Button).disabled, "ses boutons « Prendre » sont allumés")
	check(fen.find_child("Calendrier", true, false) != null, "et le registre mène au calendrier")
	fen.queue_free()
	check(basket.prendre("absent", 1).raison == "club", "le basket refuse un club qui n'existe pas")
	basket.dossier = ""
	basket.effacer()
	basket.regler_horloge(func(): return t)
	basket.clubs = {"smarves": {"nom": "Les Hérons du Clain"}}
	t = basket.coup_envoi(1, 5)
	check(basket.prendre("smarves", 1).ok, "au basket aussi, en saison, une part se prend")
	basket.effacer()

	# ---- un club à la fois
	t = foot.coup_envoi(1, 5)
	foot.forcer_porteurs("vous:1,Lucien:4", a)
	foot.forcer_porteurs("vous:9,Lucien:1", b)
	foot.appliquer_directions([{"club": a, "par": "vous", "moi": true, "division": diriger.division(foot, a)}])
	foot.appliquer_releves({})
	check(foot.peut_decider(a), "je dirige %s, où j'ai pourtant moins que Lucien : je garde la main" % a)
	check(diriger.phrase(foot, a).contains("il peut demander la direction pour la relève du lundi"), "et c'est dit (%s)" % diriger.phrase(foot, a))
	check(not foot.peut_decider(b) and str(diriger.dirigeant(foot, b).nom) == "Lucien", "à %s, où j'ai le plus, c'est Lucien qui dirige : un club à la fois" % b)
	check(diriger.phrase(foot, b).contains("un président ne dirige qu'un club à la fois"), "la règle est dite (%s)" % diriger.phrase(foot, b))
	check(not diriger.peut_prendre(foot, b), "je ne prends pas %s de moi-même" % b)
	var rel: Dictionary = diriger.relevable(foot, b)
	check(rel.ok and rel.changer, "mais je peux le demander pour la relève, en quittant %s" % a)
	check(diriger.bouton_releve(foot, b).begins_with("Diriger ce club à la place") and diriger.bouton_releve(foot, b).ends_with("à midi"), "le bouton le dit (%s)" % diriger.bouton_releve(foot, b))
	check(diriger.peut_prendre(foot, a) == false and not diriger.relevable(foot, a).ok, "et l'on ne redemande pas la direction qu'on tient")
	# La relève annoncée.
	foot.appliquer_releves({"releves": [{"club": b, "par": "vous", "moi": true, "effet": diriger.prochaine_releve(foot)}]})
	check(diriger.phrase(foot, b).begins_with("Vous prenez la direction du club à la relève, lundi"), "ma relève est dite (%s)" % diriger.phrase(foot, b))
	check(diriger.bouton_releve(foot, b) == "", "et ne se redemande pas")
	# Un changement fait pendant la saison : plus d'autre avant l'intersaison.
	foot.appliquer_releves({"changements": [{"periode": "s1", "club": a}]})
	check(diriger.relevable(foot, b).raison == "saison" and diriger.phrase(foot, b).contains("déjà changé cette saison"), "un seul changement pendant la saison (%s)" % diriger.phrase(foot, b))
	t = foot.coup_envoi(1, 14) + 4 * 3600
	check(diriger.relevable(foot, b).ok, "mais un autre pendant l'intersaison")
	foot.appliquer_releves({"changements": [{"periode": "s1", "club": a}, {"periode": "i2", "club": a}]})
	check(diriger.relevable(foot, b).raison == "saison" and diriger.phrase(foot, b).contains("déjà changé cette intersaison"), "et un seul (%s)" % diriger.phrase(foot, b))
	t = foot.coup_envoi(1, 5)
	foot.appliquer_releves({})
	# Une direction dont le titulaire n'a plus de part ne compte plus.
	foot.appliquer_directions([{"club": a, "par": "Gaston", "moi": false, "division": diriger.division(foot, a)}])
	check(diriger.direction_valide(foot, a).is_empty() and str(diriger.dirigeant(foot, a).nom) == "Lucien", "une direction tenue par quelqu'un sans part est vacante : le plus gros porteur la prend")
	foot.appliquer_directions([{"club": a, "par": "Lucien", "moi": false, "division": diriger.division(foot, a)}])
	check(str(diriger.dirigeant(foot, a).nom) == "Lucien" and diriger.phrase(foot, a).contains("Lucien dirige le club. Il vous manque"), "Lucien dirige %s : il me manque des parts (%s)" % [a, diriger.phrase(foot, a)])
	check(foot.peut_decider(b) or diriger.dirigeant(foot, b).moi, "et %s me revient, puisque je ne dirige plus %s" % [b, a])
	check(diriger.peut_prendre(foot, b), "je le prends tout de suite : la direction est vacante")
	# Prendre la main sur un club que Lucien dirige : à la relève.
	foot.forcer_porteurs("vous:9,Lucien:4", a)
	foot.appliquer_directions([{"club": a, "par": "Lucien", "moi": false, "division": diriger.division(foot, a)}])
	check(not diriger.peut_prendre(foot, a) and diriger.relevable(foot, a).ok and not diriger.relevable(foot, a).changer, "j'ai mis plus que Lucien à %s : je demande la direction pour la relève" % a)
	check(diriger.phrase(foot, a).contains("elle vous revient à la relève, lundi"), "c'est dit (%s)" % diriger.phrase(foot, a))
	foot.appliquer_releves({"releves": [{"club": a, "par": "Lucien", "moi": false, "effet": diriger.prochaine_releve(foot)}]})
	check(diriger.phrase(foot, a).begins_with("Lucien prend la direction du club à la relève"), "la relève d'un autre se lit aussi (%s)" % diriger.phrase(foot, a))
	foot.appliquer_releves({})

	# ---- le calendrier
	t = foot.coup_envoi(1, 1) - 86400
	foot.appliquer_directions([])
	var p: Dictionary = cal.page(foot, "football")
	var lib: Array = p.lignes.map(func(l): return l[0])
	check(lib.has("L'intersaison") and lib.has("La relève") and lib.has("Le mercato") and lib.has("Le prochain match"), "la page du football : l'intersaison, la relève, le mercato, le prochain match (%s)" % str(lib))
	check(p.journees.size() == 14 and p.journees[0].prochaine and p.journees[0].jour == "25 oct.", "les quatorze journées, la première le 25 octobre")
	check(str(cal.resume(foot, "football")).contains("intersaison maintenant, jusqu'au dimanche 25 octobre"), "le résumé (%s)" % cal.resume(foot, "football"))
	t = foot.coup_envoi(1, 3) + 5 * 3600
	p = cal.page(foot, "football")
	check(p.lignes[0][1] == "journée 3 sur 14 jouée" and p.journees[2].jouee and p.journees[3].prochaine, "en saison : la journée 3 jouée, la 4 à venir")
	basket.regler_horloge(func(): return t)
	var pb: Dictionary = cal.page(basket, "basket")
	check(pb.lignes.map(func(l): return l[0]).has("Le marché"), "la page du basket dit le marché")
	var carnet: Node = root.get_node("Carnet")
	check(carnet.onglets().map(func(o): return o[0]).has("clubs") and carnet.pages_clubs()[-1][0] == "calendrier", "le carnet a « Le calendrier », dernière page de « Mes clubs »")
	carnet.ouvrir_calendrier()
	await process_frame
	check(carnet.is_open() and carnet.get("_onglet") == "clubs" and carnet.get("_club_vu") == "calendrier", "et il s'ouvre dessus")
	carnet.toggle()

	foot.effacer()
	print("ÉCHECS : %d" % fails if fails > 0 else "TOUT EST BON")
	quit(1 if fails > 0 else 0)
