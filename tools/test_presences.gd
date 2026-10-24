extends SceneTree
## Vérifie les autres joueurs dans un lieu (autoload Presences) sans réseau :
## godot --headless --path . -s tools/test_presences.gd
## Les vues de la base et les positions du canal arrivent à la main : les silhouettes naissent avec la
## tenue et le nom, glissent d'une position à l'autre avec du retard, se cachent à une table, partent
## avec la liste, s'éclipsent sans nouvelles ; ce que le joueur envoie suit sa cadence ; sans compte,
## rien ne s'ouvre. Socle 1.23 : la portée, les messages d'une commune, son entrée seule dans le lieu, ses
## zones, et la vérification du champ « presences » du manifeste. Le même jeu à deux clients, sur le vrai
## canal : tools/test_presences_deux.gd.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func attendre(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await process_frame


func _init() -> void:
	await process_frame
	var P: Node = root.get_node("Presences")
	var C: Node = root.get_node("Compte")
	var scene := Node3D.new()
	root.add_child(scene)
	var joueur := Node3D.new()
	scene.add_child(joueur)

	# Sans compte : la scène est retenue, rien ne s'ouvre.
	check(not C.connecte(), "l'essai tourne sans compte")
	P.entrer("smarves", "place", scene, joueur, 1.0)
	check(not P.actif() and P.etat == "", "sans compte, pas d'inscription au lieu")

	P.hors_ligne = true
	P.entrer("smarves", "place", scene, joueur, 1.0)
	P.appliquer_vue({"canal": "smarves:smarves:place:1:x", "moi": "moi000", "cadence": 3, "presents": [
		{"membre": "moi000", "nom": "Moi", "tenue": ""},
		{"membre": "aaa111", "nom": "Paulette", "tenue": "smoking"},
		{"membre": "bbb222", "nom": "Bastien", "tenue": ""}]})
	check(P.etat == "present" and P.presents.size() == 2, "deux autres présents, pas soi-même")
	check(P.tenue_de("Paulette") == "smoking" and P.tenue_de("Personne") == "", "la tenue d'un présent par son nom")
	await attendre(0.1)
	check(not is_instance_valid(P.presents.aaa111.noeud), "pas de silhouette tant qu'aucune position n'est arrivée")

	P.recevoir({"m": "aaa111", "x": 0.0, "y": 0.0, "z": 0.0, "a": 0.0})
	await attendre(0.05)
	var n: Node3D = P.presents.aaa111.noeud
	check(is_instance_valid(n) and n.get_parent() == scene, "Paulette apparaît dans la scène")
	var lab: Label3D = null
	for c in n.get_children():
		if c is Label3D:
			lab = c
	check(lab != null and lab.text == "Paulette", "son nom au-dessus de la tête")
	check(n.look == Cast.player("smoking") and n.look != Cast.player("costume"), "habillée de sa tenue")
	await attendre(0.3)
	P.recevoir({"m": "aaa111", "x": 3.0, "y": 0.0, "z": 0.0, "a": 1.0})
	await attendre(0.15)
	var x1: float = n.global_position.x
	check(x1 > 0.2 and x1 < 2.8, "elle glisse entre deux positions (x = %.2f)" % x1)
	await attendre(0.4)
	check(is_equal_approx(n.global_position.x, 3.0), "puis s'arrête à la dernière")

	P.masquer("Paulette")
	check(not n.visible, "cachée quand elle est assise à une table")
	P.masquer("Paulette", false)
	check(n.visible, "remontrée en se levant")

	# Une position d'un inconnu fait relire la liste tout de suite.
	P._battement = 15.0
	P.recevoir({"m": "zzz999", "x": 0.0, "z": 0.0})
	check(not P.presents.has("zzz999") and P._battement <= 0.0, "un inconnu fait relire la liste")

	# Ce qu'on envoie : à la cadence, seulement quand on bouge.
	P.essai_envois.clear()
	await attendre(0.2)
	var avant: int = P.essai_envois.size()
	joueur.position = Vector3(1, 0, 0)
	await attendre(0.05)
	check(P.essai_envois.size() == avant + 1 and is_equal_approx(float(P.essai_envois[-1].x), 1.0), "on envoie sa position quand on bouge")
	check(P.essai_envois[-1].m == "moi000", "signée de son identifiant public")
	for i in 20:
		joueur.position.x += 0.1
		await attendre(0.05)
	var n_envois: int = P.essai_envois.size() - avant
	check(n_envois >= 2 and n_envois <= 5, "au plus trois envois par seconde en marchant (%d en 1 s)" % n_envois)
	# La dernière position part encore une fois arrêté, puis plus rien.
	await attendre(0.4)
	check(is_equal_approx(float(P.essai_envois[-1].x), joueur.position.x), "la position d'arrivée part")
	var fige: int = P.essai_envois.size()
	await attendre(0.8)
	check(P.essai_envois.size() == fige, "rien quand on ne bouge plus")

	# Bastien quitte le lieu : la liste suivante ne l'a plus.
	P.recevoir({"m": "bbb222", "x": 1.0, "z": 1.0})
	await attendre(0.05)
	var nb: Node3D = P.presents.bbb222.noeud
	P.appliquer_vue({"canal": "smarves:smarves:place:1:x", "moi": "moi000", "cadence": 1, "presents": [
		{"membre": "aaa111", "nom": "Paulette", "tenue": "smoking"}]})
	await process_frame
	check(P.presents.has("bbb222") and is_instance_valid(nb) and nb.visible, "Bastien parti : encore visible à sa dernière place")
	await attendre(3.2)
	check(not P.presents.has("bbb222") and not is_instance_valid(nb), "puis il s'éclipse")
	check(P.cadence == 1, "la cadence suit la base (lieu plein)")

	# Sans nouvelles depuis une minute, la silhouette s'éclipse.
	P.presents.aaa111.vu -= 61.0
	await attendre(0.05)
	check(not is_instance_valid(P.presents.aaa111.noeud), "sans nouvelles, elle s'éclipse")

	await pensionnaires(P)

	# La scène s'en va : tout se range.
	scene.queue_free()
	await process_frame
	await process_frame
	check(P.etat == "" and P.presents.is_empty(), "quitter la scène quitte le lieu")

	await communes(P)
	print("%s : %d échec(s)" % ["test_presences", fails])
	quit(1 if fails else 0)


## Les pensionnaires : la vue de la place les donne avec leur trajet et leurs bulles ; le jeu les fait
## marcher à l'heure du serveur, montre leur bulle, et les range quand la liste ne les a plus.
func pensionnaires(P: Node) -> void:
	var t := Time.get_unix_time_from_system() * 1000.0
	var e: Dictionary = P.au_trajet([[0, 0, 0, 0], [1000, 10, 0, 0]], 500.0)
	check(e.position.is_equal_approx(Vector3(5, 0, 0)) and is_equal_approx(e.cap, PI / 2.0), "au milieu du trajet, tourné vers l'est")
	check(P.au_trajet([[0, 0, 0, 0], [1000, 10, 0, 0]], 5000.0, 1.0).cap == 1.0, "à l'arrêt, il garde son cap")
	check(P.au_trajet([], 0.0).is_empty(), "sans trajet, nulle part")
	check(P.bulle_a([[100, "a"], [5000, "b"]], 200.0) == "a" and P.bulle_a([[100, "a"]], 20000.0) == "", "une bulle dure dix secondes")
	var vue := {"canal": "smarves:smarves:place:1:x", "moi": "moi000", "cadence": 3, "maintenant": t + 60000.0, "presents": [
		{"membre": "aaa111", "nom": "Paulette", "tenue": "smoking"}], "pensionnaires": [
		{"membre": "ccc333", "nom": "Billy Bob (pensionnaire)", "tenue": "canotier",
			"trajet": [[t + 59000.0, 0, 0, 2], [t + 61000.0, 4, 0, 2], [t + 80000.0, 4, 0, 2]],
			"bulles": [[t + 59500.0, "Bonjour la place !"]]}]}
	P.appliquer_vue(vue)
	check(P.presents.has("p:ccc333") and P.presents["p:ccc333"].corps, "un pensionnaire présent sur la place")
	await attendre(0.1)
	var n: Node3D = P.presents["p:ccc333"].noeud
	check(is_instance_valid(n) and n.position.x > 0.5 and n.position.x < 3.5, "il marche le long de son trajet, à l'heure du serveur (x = %.2f)" % (n.position.x if is_instance_valid(n) else -1.0))
	var b: Label3D = n.get_node_or_null("Bulle") if is_instance_valid(n) else null
	check(b != null and b.visible and b.text.contains("Bonjour la place !"), "sa bulle au-dessus de la tête")
	await attendre(1.2)
	check(is_equal_approx(n.position.x, 4.0), "arrivé, il s'arrête")
	vue.erase("pensionnaires")
	P.appliquer_vue(vue)
	await attendre(3.2)
	check(not P.presents.has("p:ccc333") and not is_instance_valid(n), "la liste ne l'a plus : il s'en va")


## Socle 1.23 : ce qu'une commune en paquet reçoit du socle.
func communes(P: Node) -> void:
	# Comme la scène du kit : elle expose son habitant par `player`.
	var gd := GDScript.new()
	gd.source_code = "extends Node3D\nvar player: Node3D\n"
	gd.reload()
	var scene := Node3D.new()
	scene.set_script(gd)
	scene.name = "Chauvigny"
	root.add_child(scene)
	var joueur := Node3D.new()
	joueur.name = "Habitant"
	scene.add_child(joueur)
	scene.player = joueur
	var aire := Area3D.new()
	aire.name = "Galerie"
	scene.add_child(aire)
	aire.position = Vector3(200, 0, 0)
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(20, 10, 20)
	forme.shape = boite
	aire.add_child(forme)
	check(P.dans_aire(aire, Vector3(205, 1, -5)) and not P.dans_aire(aire, Vector3(215, 1, 0)), "une position dans une aire, une autre dehors")

	# La commune n'écrit rien : le socle trouve l'habitant, le lieu de la scène, la portée par défaut.
	var manifeste := {"presences": {"zones": [{"id": "galerie", "aire": "Galerie"}]}}
	check(P.entrer_commune("chauvigny", scene, manifeste), "une scène de commune entre seule dans son lieu")
	check(P.commune == "chauvigny" and P.lieu == P.lieu_de_scene(scene) and P.portee == P.PORTEE, "son lieu et la portée par défaut")
	var sans := Node3D.new()
	root.add_child(sans)
	check(not P.entrer_commune("chauvigny", sans, {}), "sans habitant, rien ne s'ouvre")
	sans.queue_free()

	P.appliquer_vue({"canal": "essai", "moi": "moi000", "cadence": 3, "presents": [
		{"membre": "aaa111", "nom": "Paulette", "tenue": ""}, {"membre": "ccc333", "nom": "Lucien", "tenue": ""}]})
	var portees := []
	P.a_portee.connect(func(m, nom, oui): portees.append([nom, oui]))
	P.recevoir({"m": "aaa111", "x": 10.0, "y": 0.0, "z": 0.0, "a": 0.0})
	P.recevoir({"m": "ccc333", "x": 100.0, "y": 0.0, "z": 0.0, "a": 0.0})
	await attendre(0.1)
	check(P.presents.aaa111.a_portee and is_instance_valid(P.presents.aaa111.noeud) and P.presents.aaa111.noeud.visible, "à 10 unités : visible")
	check(not P.presents.ccc333.a_portee and not is_instance_valid(P.presents.ccc333.noeud), "à 100 unités : hors de portée, pas de silhouette")
	check(["Paulette", true] in portees and not ["Lucien", true] in portees, "le signal a_portee pour celle qui arrive à portée")
	var autour: Array = P.autour()
	check(autour.size() == 1 and autour[0].nom == "Paulette" and is_equal_approx(autour[0].distance, 10.0), "autour() : les joueurs à portée et leur distance")
	# Lucien approche jusqu'à 50 : visible ; il recule à 63 (dans la marge) : toujours ; à 70 : caché.
	P.recevoir({"m": "ccc333", "x": 50.0, "y": 0.0, "z": 0.0, "a": 0.0})
	await attendre(0.45)
	check(P.presents.ccc333.a_portee and P.presents.ccc333.noeud.visible, "il entre à portée en approchant")
	P.recevoir({"m": "ccc333", "x": 63.0, "y": 0.0, "z": 0.0, "a": 0.0})
	await attendre(0.45)
	check(P.presents.ccc333.a_portee, "un peu au-delà, la marge le garde (pas de clignotement)")
	P.recevoir({"m": "ccc333", "x": 70.0, "y": 0.0, "z": 0.0, "a": 0.0})
	await attendre(0.45)
	check(not P.presents.ccc333.a_portee and not P.presents.ccc333.noeud.visible, "plus loin, il se cache")
	check(["Lucien", false] in portees, "et le signal le dit")

	# Les messages d'une commune.
	var recus := []
	P.message.connect(func(m, nom, e, d): recus.append([nom, e, d]))
	P.essai_messages.clear()
	check(P.envoyer("pret", {"salle": "lab1"}) and P.essai_messages[-1] == ["pret", {"salle": "lab1"}], "envoyer un message de la commune")
	check(not P.envoyer("Prêt !", {}) and not P.envoyer("pos2" + "x".repeat(30), {}), "un nom de message refusé")
	check(not P.envoyer("gros", {"t": "x".repeat(1100)}), "un message de plus d'1 Ko refusé")
	var partis := 0
	for i in 30:
		if P.envoyer("geste", {"i": i}):
			partis += 1
	check(partis <= 10, "au plus dix messages d'un coup (%d partis)" % partis)
	P.recevoir_message("geste", {"m": "aaa111", "d": {"action": "nord"}})
	P.recevoir_message("geste", {"m": "inconnu", "d": {"action": "sud"}})
	P.recevoir_message("geste", {"m": "aaa111", "d": "pas un objet"})
	check(recus.size() == 1 and recus[0][0] == "Paulette" and recus[0][2].action == "nord", "recevoir le message d'un présent, pas d'un inconnu")

	# Loin de tous, une position par seconde ; près de quelqu'un, la pleine cadence.
	check(P._quelqu_un_pres(), "quelqu'un est près")
	P.recevoir({"m": "aaa111", "x": 400.0, "y": 0.0, "z": 0.0, "a": 0.0})
	P.recevoir({"m": "ccc333", "x": -400.0, "y": 0.0, "z": 0.0, "a": 0.0})
	check(not P._quelqu_un_pres(), "loin de tous")
	P.essai_envois.clear()
	for i in 20:
		joueur.position.z += 0.1
		await attendre(0.05)
	check(P.essai_envois.size() <= 2, "loin de tous, au plus une position par seconde (%d en 1 s)" % P.essai_envois.size())

	# Les zones : deux secondes dans la galerie, et l'on change de canal.
	var zones_vues := []
	P.zone_changee.connect(func(z): zones_vues.append(z))
	joueur.position = Vector3(201, 0, 0)
	await attendre(1.0)
	check(P.lieu != "galerie", "pas tout de suite (le temps de grâce)")
	await attendre(1.6)
	check(P.lieu == "galerie" and zones_vues == ["galerie"] and P.presents.is_empty(), "dans la galerie, son propre canal")
	joueur.position = Vector3(0, 0, 0)
	await attendre(0.6)
	joueur.position = Vector3(201, 0, 0)
	await attendre(2.6)
	check(P.lieu == "galerie" and zones_vues.size() == 1, "un aller-retour sur la limite ne change rien")
	joueur.position = Vector3(0, 0, 0)
	await attendre(2.6)
	check(P.lieu == P.lieu_de_scene(scene) and zones_vues.size() == 2, "hors de la galerie, le lieu de la scène")
	# Qui entre dans la scène en se tenant dans la galerie y entre tout de suite.
	var a2 := aire.duplicate()
	scene.queue_free()
	await process_frame
	await process_frame
	var s2 := Node3D.new()
	root.add_child(s2)
	var j2 := Node3D.new()
	j2.add_to_group("player")
	s2.add_child(j2)
	s2.add_child(a2)
	j2.position = Vector3(200, 0, 0)
	check(P.entrer_commune("chauvigny", s2, {"presences": {"portee": 25, "zones": [{"id": "galerie", "aire": ["Galerie"]}]}}),
		"l'habitant trouvé par le groupe « player »")
	check(P.lieu == "galerie" and P.portee == 25.0, "on entre dans la zone où l'on se tient, à la portée du manifeste")
	s2.queue_free()
	await process_frame
	await process_frame

	# Le lieu d'une scène, et le champ « presences » du manifeste.
	var salle := Node3D.new()
	salle.set_script(GDScript.new())
	check(P.lieu_de_scene(salle) != "", "un lieu même sans fichier de scène")
	salle.free()
	check(Commune.verifier_presences(null).is_empty() and Commune.verifier_presences({"portee": 40, "echelle": 1.5,
		"zones": [{"id": "galerie", "aire": "Galerie"}, {"id": "hall", "aire": ["Escalier", "Mezzanine"]}]}).is_empty(), "un champ presences juste")
	var mauvais := Commune.verifier_presences({"portee": -1, "zones": [{"id": "Galerie", "aire": ""}, {"id": "a", "aire": "A"}, {"id": "a", "aire": "B"}], "x": 1})
	check(mauvais.size() == 5, "un champ presences faux : portée, id, aire, double, champ inconnu (%s)" % ", ".join(mauvais))
