extends SceneTree
## Vérifie l'entraînement, le courrier, le rapport de l'adjoint et la répétition sans affichage :
## godot --headless --path . -s tools/test_foot_entrainement.gd
## Un programme ciblé fait progresser les jeunes du bon poste plus que les anciens ; il voyage dans la consigne
## (« general » n'y est pas écrit) ; il compte après le match, pour la journée suivante et la saison suivante ;
## la tactique validée garde le programme ; le courrier raconte les matchs joués et les progrès ; la direction
## fixe un objectif ; la répétition joue vingt matchs sans toucher au résultat officiel ; les pages s'ouvrent.

const TMP := "user://test_foot_entrainement/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_lancer.call_deferred()


## Chargées une fois les autoloads posés (FootCourrier lit Game par FootLocaux).
var FootEntrainement: GDScript
var FootCourrier: GDScript


func _lancer() -> void:
	FootEntrainement = load("res://scripts/socle/foot_entrainement.gd")
	FootCourrier = load("res://scripts/socle/foot_courrier.gd")
	_programmes()
	var foot: Node = root.get_node("Football")
	var m: Node = root.get_node("Mercato")
	DirAccess.make_dir_recursive_absolute(TMP)
	foot.dossier = TMP
	m.dossier = TMP
	foot.effacer()
	m.effacer()
	DirAccess.remove_absolute(TMP + "courrier_lu.json")
	var t: int = foot.coup_envoi(1, 1) - 3 * 86400
	foot.regler_horloge(func(): return t)
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	var club := "smarves"
	foot.forcer_porteurs("vous:2", club)
	check(foot.prochain_match(club).get("j", 0) == 1, "le prochain match est la première journée")

	# La consigne : le programme y entre, sauf le général.
	check(not foot.consigne({"entrainement": "general"}).has("entrainement") and not foot.consigne({"entrainement": "n'importe"}).has("entrainement"), "le général et l'inconnu ne s'écrivent pas")
	check(foot.consigne({"entrainement": "finition"}).entrainement == "finition", "un programme ciblé s'écrit dans la consigne")
	check(foot.consigne({}) == {"formation": "4-4-2", "mentalite": "equilibree", "pressing": "normal"}, "une consigne sans programme reste celle d'avant")

	var avant: Dictionary = foot.effectif(club, 1, 2).duplicate(true)
	check(foot.decider(1, 1, club, {"entrainement": "finition"}), "le président pose le programme de la semaine")
	check(foot.consigne_de(1, 1, club).consigne.get("entrainement", "") == "finition", "la consigne de la journée 1 porte la finition")
	check(foot.programmes(club, 1, 3) == ["finition", "general", "general"], "les programmes semaine par semaine : %s" % str(foot.programmes(club, 1, 3)))
	var e1: Dictionary = foot.effectif(club, 1, 1)
	var e2: Dictionary = foot.effectif(club, 1, 2)
	check(e1 == foot.effectif(club, 1), "à la première journée, rien n'est encore travaillé")
	var attaquants: Array = e2.keys().filter(func(id): return e2[id].poste == "A")
	check(attaquants.all(func(id): return float(e2[id].competences.but) > float(avant[id].competences.but) + 0.1), "après la semaine de finition, les attaquants ont gagné en but")
	var gardiens: Array = e2.keys().filter(func(id): return e2[id].poste == "G")
	check(gardiens.all(func(id): return is_equal_approx(float(e2[id].competences.but), float(e1[id].competences.but))), "les gardiens n'ont rien gagné en but")
	check(attaquants.all(func(id): return float(e2[id].note) > float(e1[id].note)), "la note des attaquants monte avec leur but")
	var jeune := {"poste": "A", "age": 19, "note": 60}
	var vieux := {"poste": "A", "age": 33, "note": 60}
	check(float(FootEntrainement.gains(jeune, "finition").but) > 5.0 * float(FootEntrainement.gains(vieux, "finition").but), "un jeune progresse bien plus vite qu'un vétéran")
	check(float(FootEntrainement.gains(jeune, "finition").note) > float(FootEntrainement.gains(jeune, "general").note), "un programme ciblé fait plus pour la note que le général")
	var r1: Dictionary = foot.prochain_match(club)
	check((foot.resultat(1, 1, r1.dom, r1.ext) as Array).size() == 2, "le match de la journée 1 se calcule avec la consigne nouvelle : %s" % str(foot.resultat(1, 1, r1.dom, r1.ext)))

	# La tactique validée au bureau garde le programme.
	var b: Control = load("res://scripts/socle/bureau.gd").new()
	b.set("club", club)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	centre.add_child(b)
	await process_frame
	for p in ["accueil", "adversaire", "entrainement", "tactique"]:
		b.call("aller", p)
		await process_frame
		check(b.get("page") == p and (b.get("_corps") as Node).get_child_count() > 0, "la page %s s'ouvre" % p)
	b.call("valider")
	check(foot.consigne_de(1, 1, club).consigne.get("entrainement", "") == "finition" and foot.consigne_de(1, 1, club).consigne.has("compo"), "la composition validée garde le programme de la semaine")
	b.call("aller", "entrainement")
	await process_frame
	check(b.find_child("Programme_defense", true, false) != null and b.find_child("Progres", true, false) is GridContainer, "la page Entraînement montre les programmes et les progrès")
	b.call("poser_programme", "defense")
	check(foot.consigne_de(1, 1, club).consigne.entrainement == "defense" and foot.consigne_de(1, 1, club).consigne.has("compo"), "poser un programme garde la composition")

	# Le rapport et la répétition.
	var rap: Dictionary = FootCourrier.rapport(foot, club)
	check(rap.adv == "essai" and rap.duels.size() == 7 and not (rap.conseils as Array).is_empty(), "le rapport de l'adjoint : sept duels et des conseils (%s)" % " / ".join(rap.conseils))
	var officiel: Array = foot.resultat(1, 1, r1.dom, r1.ext)
	var debut := Time.get_ticks_msec()
	var rep: Dictionary = foot.repetition(1, 1, r1.dom, r1.ext, club, {"formation": "4-3-3", "mentalite": "offensive"})
	var duree := Time.get_ticks_msec() - debut
	check(int(rep.victoires) + int(rep.nuls) + int(rep.defaites) == 20, "la répétition joue vingt matchs : %d V, %d N, %d D en %d ms" % [rep.victoires, rep.nuls, rep.defaites, duree])
	check(foot.resultat(1, 1, r1.dom, r1.ext) == officiel and foot.consigne_de(1, 1, club).consigne.formation == "4-4-2", "la répétition ne touche ni au résultat officiel ni à la consigne")
	b.call("aller", "adversaire")
	await process_frame
	await b.call("repeter")
	await process_frame
	check(b.find_child("Repetition", true, false) is Label, "la page Adversaire montre ce qu'a donné la répétition")

	# Après quatre journées : le courrier raconte, l'entraînement a fait passer des crans aux jeunes.
	foot.decider(1, 2, club, {"entrainement": "finition"})
	foot.decider(1, 3, club, {"entrainement": "finition"})
	var t4: int = foot.coup_envoi(1, 4) + 3 * 3600
	foot.regler_horloge(func(): return t4)
	foot.actualiser()
	var msgs: Array = FootCourrier.messages(foot, club)
	var ids: Array = msgs.map(func(x): return str(x.id))
	check(ids.has("match/1/1") and ids.has("match/1/3") and ids.has("objectif/1"), "le courrier a les comptes rendus et l'objectif : %s" % str(ids.slice(0, 6)))
	check(msgs.all(func(x): return x.has("titre") and x.has("texte") and x.has("quand")), "chaque message a un titre, un texte, une date")
	check(int(msgs[0].quand) >= int(msgs[-1].quand), "le plus récent d'abord")
	check(ids.any(func(x): return x.begins_with("progres/")), "un message dit les progrès de l'entraînement")
	var obj: Dictionary = FootCourrier.objectif(foot, club)
	check(obj.has("titre") and int(obj.place) >= 1, "la direction fixe un objectif : %s" % str(obj.get("titre", "")))
	var conf: Dictionary = FootCourrier.confiance(foot, club)
	check(int(conf.valeur) >= 5 and int(conf.valeur) <= 100 and str(conf.phrase) != "", "et dit sa confiance : %s (%d)" % [conf.phrase, conf.valeur])
	b.call("aller", "accueil")
	await process_frame
	var n0: int = b.call("non_lus")
	check(n0 == msgs.size(), "tout le courrier est neuf : %d" % n0)
	b.call("_ouvrir_message", str(msgs[0].id))
	await process_frame
	check(int(b.call("non_lus")) == n0 - 1 and b.find_child("Courrier", true, false) != null, "un message ouvert est lu")

	# La saison suivante emporte les progrès de toute la saison.
	var s1_fin: Dictionary = foot.effectif(club, 1, 14)
	var s2: Dictionary = foot.effectif(club, 2)
	var sans: Dictionary = foot.fondateurs(club)
	check(s2.keys().filter(func(id): return s1_fin.has(id) and sans.has(id)).size() > 10, "la saison 2 garde la plupart des joueurs")
	print("\n%d échec%s" % [fails, "s" if fails > 1 else ""])
	quit(1 if fails > 0 else 0)


func _programmes() -> void:
	check(FootEntrainement.PROGRAMMES.has(FootEntrainement.DEFAUT) and FootEntrainement.PROGRAMMES.size() == 8, "huit programmes, dont le général")
	check(FootEntrainement.PROGRAMMES.values().all(func(p): return (p.competences as Array).all(func(c): return (load("res://scripts/socle/foot_match.gd").COMPETENCES as Dictionary).has(c))), "chaque programme travaille des compétences du moteur")
	var j := {"poste": "D", "age": 20, "note": 60, "competences": {"gardien": 20, "defense": 64.9, "jeu": 50, "aile": 50, "passe": 50, "but": 30, "cpa": 40, "endurance": 60}}
	var avant := j.duplicate(true)
	FootEntrainement.travailler(j, "defense")
	check(FootEntrainement.crans_gagnes(avant, j).size() == 1 and FootEntrainement.crans_gagnes(avant, j)[0].competence == "defense", "un défenseur à 64,9 passe le cran 13 en une semaine de défense")
