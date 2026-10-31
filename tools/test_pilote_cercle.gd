extends SceneTree
## Le pilote d'un pensionnaire trouve le Cercle Philidor, sans réseau :
## godot --headless --path . -s tools/test_pilote_cercle.gd
## Rien de l'étage ne se voit du hall : en entrant, il lit le panneau « À l'étage » au pied de l'escalier,
## qui nomme le Cercle ; « aller » vers « cercle » le mène à l'étage, au fond du Fumoir, et E l'y fait entrer.

var fails := 0
var P: Node


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func attendre_scene(nom: String, s: float) -> bool:
	var fin := Time.get_ticks_msec() + int(s * 1000)
	while Time.get_ticks_msec() < fin:
		await create_timer(0.2).timeout
		if current_scene and current_scene.scene_file_path.get_file().get_basename() == nom and P.joueur() != null:
			return true
	return false


func _init() -> void:
	create_timer(240.0).timeout.connect(func():
		print("ÉCHEC   trop long : l'essai s'arrête")
		quit(1))
	await process_frame
	P = root.get_node("Pilote")
	var G: Node = root.get_node("Game")
	G.saving_enabled = false
	G.credits = 3000
	G.won = 1500
	G.welcomed = true
	change_scene_to_file("res://scenes/casino.tscn")
	check(await attendre_scene("casino", 30.0), "le casino se charge")
	await create_timer(1.5).timeout
	var v: Dictionary = P.vue()
	var lu := ""
	for e in v.get("ecrits", []):
		if str(e.texte).contains("Cercle Philidor"):
			lu = str(e.texte)
	check(lu != "", "en entrant, il lit le panneau de l'étage, qui nomme le Cercle Philidor")
	var r: Dictionary = await P.geste({"geste": "aller", "vers": "cercle"})
	check(r.ok and str(r.vue.devant).contains("Cercle Philidor"), "« aller » vers « cercle » : jusqu'à sa porte, à l'étage (%s)" % r.dit)
	await P.geste({"geste": "touche", "touche": "E"})
	check(await attendre_scene("cercle", 30.0), "E : il entre au Cercle")
	print("%d échec(s)" % fails)
	quit(1 if fails else 0)
