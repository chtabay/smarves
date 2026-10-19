extends SceneTree
## Vérifie les autres joueurs dans un lieu (autoload Presences) sans réseau :
## godot --headless --path . -s tools/test_presences.gd
## Les vues de la base et les positions du canal arrivent à la main : les silhouettes naissent avec la
## tenue et le nom, glissent d'une position à l'autre avec du retard, se cachent à une table, partent
## avec la liste, s'éclipsent sans nouvelles ; ce que le joueur envoie suit sa cadence ; sans compte,
## rien ne s'ouvre.

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
	check(not P.presents.has("bbb222") and not is_instance_valid(nb), "Bastien parti, sa silhouette aussi")
	check(P.cadence == 1, "la cadence suit la base (lieu plein)")

	# Sans nouvelles depuis une minute, la silhouette s'éclipse.
	P.presents.aaa111.vu -= 61.0
	await attendre(0.05)
	check(not is_instance_valid(P.presents.aaa111.noeud), "sans nouvelles, elle s'éclipse")

	# La scène s'en va : tout se range.
	scene.queue_free()
	await process_frame
	await process_frame
	check(P.etat == "" and P.presents.is_empty(), "quitter la scène quitte le lieu")
	print("%s : %d échec(s)" % ["test_presences", fails])
	quit(1 if fails else 0)
