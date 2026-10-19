extends SceneTree
## Vérifie le client Realtime (scripts/socle/temps_reel.gd) : godot --headless --path . -s tools/test_temps_reel.gd
## Le protocole d'abord, sans réseau ; puis deux clients sur le vrai canal Supabase du projet (un canal
## jetable au nom tiré au hasard) : ils le rejoignent, l'un diffuse, l'autre reçoit, sans écho chez soi.
## Sans réseau, la seconde partie est sautée et le dit. Ne touche ni au compte ni à la base.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var TR: GDScript = load("res://scripts/socle/temps_reel.gd")
	var j: Dictionary = TR.message("realtime:x", "phx_join", TR.rejoindre_config(), "1", "1")
	check(j.topic == "realtime:x" and j.join_ref == "1", "rejoindre : sujet et référence")
	check(j.payload.config.broadcast.self == false and j.payload.config.private == false, "rejoindre : public, sans écho")
	check(not TR.message("phoenix", "heartbeat", {}, "2").has("join_ref"), "battement sans référence de canal")
	var m: Dictionary = TR.lire('{"topic":"realtime:x","event":"broadcast","payload":{"type":"broadcast","event":"pos","payload":{"m":"ab"}},"ref":null}')
	check(m.event == "broadcast" and m.payload.payload.m == "ab" and m.ref == "", "lire une diffusion")
	check(TR.lire("pas du json").is_empty() and TR.lire("[1,2]").is_empty(), "un message illisible est ignoré")

	var cle: String = root.get_node("Compte").CLE_PUBLIQUE
	var nom := "smarves:essai:%d" % (randi() % 1000000000)
	var a: Node = TR.new()
	var b: Node = TR.new()
	a.cle = cle
	b.cle = cle
	root.add_child(a)
	root.add_child(b)
	var recus := {"a": [], "b": []}
	a.recu.connect(func(e, d): recus.a.append([e, d]))
	b.recu.connect(func(e, d): recus.b.append([e, d]))
	a.ouvrir(nom)
	b.ouvrir(nom)
	var t0 := Time.get_ticks_msec()
	while not (a.est_rejoint and b.est_rejoint) and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
	if not (a.est_rejoint and b.est_rejoint):
		print("sauté   le vrai canal ne répond pas (pas de réseau ?)")
	else:
		check(true, "deux clients ont rejoint le canal")
		a.envoyer("pos", {"m": "aaa", "x": 1.5, "z": -2.0})
		t0 = Time.get_ticks_msec()
		while recus.b.is_empty() and Time.get_ticks_msec() - t0 < 5000:
			await process_frame
		check(recus.b.size() == 1 and recus.b[0][0] == "pos" and is_equal_approx(float(recus.b[0][1].x), 1.5), "l'autre reçoit la position")
		check(recus.a.is_empty(), "pas d'écho chez celui qui envoie")
		a.fermer()
		check(not a.est_rejoint and a.canal == "", "fermer quitte le canal")
	b.fermer()
	print("%s : %d échec(s)" % ["test_temps_reel", fails])
	quit(1 if fails else 0)
