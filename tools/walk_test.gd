extends Node
## Vérifie qu'on peut marcher partout où il faut : escalier du casino, passages, portes ; et dans le village.
## godot --path . res://tools/walk_test.tscn

var report: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	Game.saving_enabled = false
	Game.won = 2_000_000
	Game.staked = 2_000_000
	get_tree().change_scene_to_file("res://scenes/casino.tscn")
	await _wait(2.5)
	var c := get_tree().current_scene
	var p: CharacterBody3D = c.player
	# Le hall, jusqu'au pied de l'escalier, puis la volée centrale, le palier, la volée est, le balcon.
	await _walk(p, Vector3(0, 0.1, 16.0), 0.0, Vector3(0, 0, -1), 4.0, "volée centrale → palier", func(): return p.global_position.y > 2.4 and p.global_position.z < 9.2)
	await _walk(p, Vector3(2.6, c.UP / 2.0 + 0.1, 7.35), -PI / 2.0, Vector3(0, 0, -1), 5.0, "volée est → balcon", func(): return p.global_position.y > c.UP - 0.2 and p.global_position.x > 7.6)
	await _walk(p, Vector3(8.8, c.UP + 0.1, 8.0), PI, Vector3(0, 0, -1), 3.0, "balcon est vers le sud", func(): return p.global_position.z > 11.0 and p.global_position.y > c.UP - 0.2)
	await _walk(p, Vector3(-8.8, c.UP + 0.1, 12.0), 0.0, Vector3(0, 0, -1), 4.0, "balcon ouest → porte du Fumoir", func(): return p.global_position.z < 5.0 and p.global_position.y > c.UP - 0.2)
	# Les passages sous les volées vers la salle des jeux.
	for x in [-5.3, 5.3]:
		await _walk(p, Vector3(x, 0.1, 11.0), 0.0, Vector3(0, 0, -1), 5.0, "porte de la salle des jeux x=%.1f" % x, func(): return p.global_position.z < 4.0)
	# Vestiaire, Nocturne.
	await _walk(p, Vector3(-6.0, 0.1, 15.0), -PI / 2.0, Vector3(0, 0, 1), 3.0, "vestiaire", func(): return p.global_position.x < -10.5)
	await _walk(p, Vector3(6.0, 0.1, 12.0), -PI / 2.0, Vector3(0, 0, -1), 3.0, "Nocturne", func(): return p.global_position.x > 10.5)
	# Salle des jeux → Verrière par l'étage : depuis le balcon ouest jusqu'à la balustrade de l'atrium.
	await _walk(p, Vector3(-9.5, c.UP + 0.1, -2.0), -PI / 2.0, Vector3(0, 0, -1), 4.0, "Fumoir → Verrière", func(): return p.global_position.x > -6.0 and p.global_position.y > c.UP - 0.2)
	print("\n=== MARCHE ===")
	for r in report:
		print(r)
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _walk(p: CharacterBody3D, start: Vector3, yaw: float, dir: Vector3, seconds: float, label: String, ok: Callable) -> void:
	p.global_position = start
	p.velocity = Vector3.ZERO
	p.rotation.y = yaw
	p.auto_move = dir
	var t := 0.0
	var success := false
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if ok.call():
			success = true
			break
	p.auto_move = Vector3.ZERO
	report.append("%s %s  (arrivé en %.1f, %.1f, %.1f)" % ["ok   " if success else "ÉCHEC", label, p.global_position.x, p.global_position.y, p.global_position.z])
