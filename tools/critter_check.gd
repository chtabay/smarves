extends SceneTree
## Vérification sans écran : fabrique quelques habitants, les anime et les fait gesticuler.
## godot --headless --path . -s tools/critter_check.gd

func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child.call_deferred(root)
	await process_frame
	var t0 := Time.get_ticks_msec()
	var V := load("res://scripts/villager.gd")
	var ids := ["joueur", "josiane", "dede", "lucien", "m-brunet", "croupier-roulette", "hotesse-1", "character-male-b.glb", "character-female-c.glb", "passelourdin-1", "barman-salle", "pianiste"]
	var vs := []
	for i in ids.size():
		var v: Node3D = V.new()
		v.model_path = ids[i]
		v.position = Vector3(i, 0, 0)
		v.pose = "sit" if ids[i] == "pianiste" else "idle"
		root.add_child(v)
		vs.append(v)
	print("construits en ", Time.get_ticks_msec() - t0, " ms")
	for f in 30:
		await process_frame
	for v in vs:
		v.react("win")
	for f in 30:
		await process_frame
	for v in vs:
		v.gesture("talk")
	for f in 30:
		await process_frame
	print("ok")
	quit()
