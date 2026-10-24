extends SceneTree
## Les salles à deux (socle 1.24) contre le faux serveur, sans compte ni réseau :
##   godot --headless --path . -s tools/test_salle_duo.gd
## Deux SalleDuo partagent un SalleDuoEssai : Ernestine attend, Gaston la rejoint, Presences passe dans le
## salon de la partie, chacun paie sa descente, la sortie paie la prime une seule fois et grave la plaque.
## Puis un départ (le partenaire le voit et garde sa descente), une reprise après une coupure, et deux
## fenêtres du jeu simulées par le fichier partagé. Le manifeste : la structure « salle_duo ».

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func joueur(essai: SalleDuoEssai, id: String, nom: String) -> SalleDuo:
	var s := SalleDuo.new()
	s.name = "Salle_" + nom
	s.essai = essai
	s.joueur_essai = {"id": id, "nom": nom}
	s.avec_argent = false
	root.add_child(s)
	return s


func attendre_que(f: Callable, s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < s * 1000.0:
		await process_frame
	return f.call()


func _init() -> void:
	await process_frame

	# Le manifeste.
	var bonne := [{"type": "salle_duo", "id": "colaby", "nom": "Le Colaby", "variantes": ["lab1", "lab2"]}]
	check(Structures.verifier(bonne).is_empty(), "une structure « salle_duo » se déclare avec ses variantes")
	check(Structures.verifier([{"type": "salle_duo", "id": "colaby", "nom": "Le Colaby"}]).size() == 1, "sans variantes, refusée")
	check(Structures.verifier([{"type": "salle_duo", "id": "colaby", "nom": "Le Colaby", "variantes": ["Lab 1"]}]).size() == 1, "une variante mal nommée est refusée")
	check(Commune.SOCLE.naturalnocasecmp_to("1.24") >= 0, "le socle (%s) connaît la salle à deux" % Commune.SOCLE)

	var essai := SalleDuoEssai.new()
	essai.tarifs = {"chauvigny:colaby:lab1": {"entree": 500, "prime": 5000}}
	essai.valider = func(carnet, v): return carnet is Array and carnet.size() >= 3 and carnet[-1] == "sortie"
	var a := joueur(essai, "e1", "Ernestine")
	var b := joueur(essai, "g2", "Gaston")
	var fiche := await a.fiche("chauvigny", "colaby", ["lab1", "lab2"])
	check(fiche.ok and fiche.variantes.lab1.entree == 500 and fiche.variantes.lab1.prime == 5000 and not fiche.variantes.lab1.gagnee,
		"la fiche dit les tarifs de chaque variante")

	# L'appariement.
	var vus := {"attente": 0, "a": {}, "b": {}}
	a.attente.connect(func(v): vus.attente += 1)
	a.apparie.connect(func(v): vus.a = v)
	b.apparie.connect(func(v): vus.b = v)
	await a.rejoindre("chauvigny", "colaby", "lab1")
	check(a.etat == "attente" and vus.attente == 1, "Ernestine attend seule")
	await b.rejoindre("chauvigny", "colaby", "lab1")
	check(b.etat == "salon" and b.role == "B" and vus.b.partenaire.nom == "Ernestine", "Gaston la rejoint : il est B, elle est sa partenaire")
	var pr: Node = root.get_node("Presences")
	check(pr.salon_id == str(vus.b.canal), "Presences passe dans le salon de la partie")
	await attendre_que(func(): return a.etat == "salon", 5.0)
	check(a.role == "A" and vus.a.canal == vus.b.canal and vus.a.partenaire.membre == SalleDuoEssai.membre_de("g2"),
		"Ernestine l'apprend au battement suivant : même canal secret, le membre de Gaston")

	# La descente, puis la partie.
	var debuts := []
	b.partie.connect(func(v): debuts.append(v))
	var ea := await a.entrer()
	check(ea.ok and ea.cout == 500 and a.etat == "salon", "Ernestine paie sa descente (500)")
	var eb := await b.entrer()
	check(eb.ok and eb.cout == 500 and b.etat == "partie" and debuts.size() == 1, "Gaston paie la sienne : la partie commence")
	check((await b.entrer()).cout == 0, "redescendre ne fait pas payer deux fois")

	# A tient le carnet ; B le reçoit.
	a.carnet = ["nord", "est"]
	await attendre_que(func(): return b.carnet.size() == 2, 6.0)
	check(b.carnet == ["nord", "est"], "le carnet de A arrive chez B par les battements")

	# La sortie.
	var faux := await a.sortir(["nord"])
	check(not faux.ok and "sortie" in faux.erreur, "des gestes qui ne sortent pas : pas de prime")
	var pa := await a.sortir(["nord", "est", "sortie"])
	check(pa.ok and pa.montant == 5000 and not pa.deja and a.etat == "fini", "la sortie : 5 000 pour Ernestine")
	var pb := await b.sortir(["nord", "est", "sortie"])
	check(pb.ok and pb.montant == 5000, "et 5 000 pour Gaston")
	check((await b.sortir(["nord", "est", "sortie"])).montant == 0, "une seule fois")
	var pl := await a.plaque("chauvigny", "colaby")
	check(pl.size() == 1 and pl[0].noms == ["Ernestine", "Gaston"], "la plaque grave leurs deux noms")
	fiche = await a.fiche("chauvigny", "colaby", ["lab1"])
	check(fiche.variantes.lab1.gagnee, "la fiche le sait : prime gagnée pour toujours")

	# Un départ : B s'en va en pleine partie, A le voit et garde sa descente.
	await a.entrer()
	await b.entrer()
	var partis := []
	a.partenaire_parti.connect(func(n): partis.append(n))
	await b.quitter()
	check(pr.salon_id == "", "en quittant, Presences sort du salon")
	await attendre_que(func(): return not partis.is_empty(), 6.0)
	check(partis == ["Gaston"], "Ernestine voit Gaston partir, au battement suivant")
	await a.quitter()
	fiche = await a.fiche("chauvigny", "colaby", ["lab1"])
	check(fiche.variantes.lab1.reports == 1, "elle garde sa descente pour la prochaine partie")
	fiche = await b.fiche("chauvigny", "colaby", ["lab1"])
	check(fiche.variantes.lab1.reports == 0, "lui, qui est parti, la perd")

	# Une coupure : B perd la main, le serveur le voit absent, puis il revient et retrouve le salon.
	var c := joueur(essai, "l3", "Lucienne")
	await c.rejoindre("chauvigny", "colaby", "lab1")
	await a.rejoindre("chauvigny", "colaby", "lab1")
	check(not (await c.entrer()).ok, "avant l'appariement, pas de descente")
	await attendre_que(func(): return c.etat == "salon", 5.0)
	var r0 := await c.entrer()
	check(r0.cout == 500, "Lucienne paie")
	check((await a.entrer()).cout == 0, "Ernestine descend sur son report")
	await attendre_que(func(): return c.role == "A", 5.0)
	c.carnet = ["ouest"]
	await attendre_que(func(): return a.carnet == ["ouest"], 6.0)
	var salon: String = a.vue.salon
	essai.maintenant = Time.get_unix_time_from_system() + 10.0
	var absents := []
	a.partenaire_absent.connect(func(n): absents.append(n))
	c.set_process(false)
	await attendre_que(func(): return not absents.is_empty(), 6.0)
	check(absents == ["Lucienne"], "sans battement depuis 6 s, Lucienne est montrée absente")
	essai.maintenant = -1.0
	var c2 := joueur(essai, "l3", "Lucienne")
	await c2.rejoindre("chauvigny", "colaby", "lab1")
	check(c2.vue.get("salon", "") == salon and c2.role == "A" and c2.carnet == ["ouest"] and c2.etat == "partie",
		"elle revient : même salon, même rôle, la partie reprend avec son carnet")
	c.free()
	await c2.quitter()
	await a.quitter()

	# Deux fenêtres : deux faux serveurs qui partagent un fichier.
	var chemin := "user://salle_duo_essai_test.json"
	DirAccess.remove_absolute(chemin)
	var f1 := SalleDuoEssai.new()
	f1.fichier = chemin
	var f2 := SalleDuoEssai.new()
	f2.fichier = chemin
	var x := joueur(f1, "x1", "Firmin")
	var y := joueur(f2, "y2", "Odette")
	await x.rejoindre("chauvigny", "colaby", "lab2")
	await y.rejoindre("chauvigny", "colaby", "lab2")
	check(y.etat == "salon" and y.vue.partenaire.nom == "Firmin", "deux fenêtres s'apparient par le fichier du faux serveur")
	DirAccess.remove_absolute(chemin)

	print("%s : %d échec(s)" % ["test_salle_duo", fails])
	quit(1 if fails else 0)
