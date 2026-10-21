extends SceneTree
## Vérifie qu'on enjambe les petites marches et qu'on bute toujours sur les hautes, aux deux tailles
## du joueur (un homme au casino, un Smarvois au village) : godot --headless --path . -s tools/test_marches.gd
## Chaque essai pose un sol, une marche de la hauteur donnée à un mètre devant, et fait marcher le joueur
## droit dessus deux secondes.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _box(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	parent.add_child(b)


## Marche droit sur une marche de hauteur h ; rend la hauteur atteinte et l'avancée.
func _essai(taille: Dictionary, h: float) -> Vector2:
	var w := Node3D.new()
	root.add_child(w)
	_box(w, Vector3(20, 1, 20), Vector3(0, -0.5, 0))
	if h > 0.0:
		# La marche commence à z = -1 et s'étend loin devant.
		_box(w, Vector3(6, h, 6), Vector3(0, h / 2.0, -4.0))
	var p: CharacterBody3D = load("res://scripts/fp_player.gd").new()
	for k in taille:
		p.set(k, taille[k])
	w.add_child(p)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.position = Vector3(0, 0.05, 0)
	for i in 10:
		await physics_frame
	p.auto_move = Vector3(0, 0, -1)
	for i in 120:
		await physics_frame
	var r := Vector2(p.global_position.y, -p.global_position.z)
	w.queue_free()
	await process_frame
	return r


func _init() -> void:
	await process_frame
	var homme := {}
	var smarvois := {"eye": 0.6, "body_height": 0.7, "radius": 0.14, "speed": 1.5}
	for c in [["homme", homme, [0.05, 0.17, 0.3], [0.45, 1.0]], ["Smarvois", smarvois, [0.05, 0.08, 0.12], [0.2, 0.5]]]:
		for h in c[2]:
			var r: Vector2 = await _essai(c[1], h)
			check(absf(r.x - h) < 0.03 and r.y > 1.3, "%s : marche de %.2f enjambée (y=%.2f, avancé de %.2f)" % [c[0], h, r.x, r.y])
		for h in c[3]:
			var r: Vector2 = await _essai(c[1], h)
			check(r.x < 0.03 and r.y < 1.0, "%s : marche de %.2f infranchissable (y=%.2f, avancé de %.2f)" % [c[0], h, r.x, r.y])
	# Sur le plat, rien ne change : on avance à la même allure.
	var r0: Vector2 = await _essai(homme, 0.0)
	check(absf(r0.x) < 0.02 and r0.y > 5.5, "homme : sur le plat, on avance (%.2f m en deux secondes)" % r0.y)
	print("\n%s" % ("MARCHES : tout va bien" if fails == 0 else "MARCHES : %d échec(s)" % fails))
	quit(1 if fails > 0 else 0)
