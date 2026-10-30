extends SceneTree
## Vérifie la minimap des communes sans affichage : godot --headless --path . -s tools/test_minimap.gd
## Sur une petite scène (un habitant, deux maisons, une porte), elle se cadre sur ce que la scène bâtit,
## relève les endroits où l'on appuie sur E, place les points autour de l'habitant (le nord en haut),
## s'affiche en haut à droite sans toucher au coin, et s'en va quand on quitte la commune. Sans rendu, elle
## n'a pas de photo et garde son fond de nuit.

const MINIMAP := preload("res://scripts/socle/minimap.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_lancer.call_deferred()


func _maison(s: Node3D, at: Vector3) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(10, 8, 10)
	m.mesh = b
	s.add_child(m)
	m.global_position = at


func _lancer() -> void:
	root.size = Vector2i(1600, 900)
	var s := Node3D.new()
	root.add_child(s)
	_maison(s, Vector3(-200, 4, 0))
	_maison(s, Vector3(300, 4, 50))
	var j := CharacterBody3D.new()
	s.add_child(j)
	j.global_position = Vector3(0, 0, 0)
	var porte := Area3D.new()
	porte.set_meta("interact", "porte")
	s.add_child(porte)
	porte.global_position = Vector3(45, 0, 0)
	var rien := Area3D.new()
	s.add_child(rien)

	var mm: MINIMAP = MINIMAP.new()
	root.add_child(mm)
	await process_frame
	await mm.suivre(s, j)
	await process_frame
	check(mm.visible, "dans la commune, la minimap s'affiche")
	check(is_equal_approx(mm.cote, 510.0) and mm.centre.is_equal_approx(Vector2(50.0, 25.0)), "elle se cadre sur ce que la scène bâtit : %s m autour de %s" % [mm.cote, mm.centre])
	check(mm._endroits.size() == 1 and mm._endroits[0] == porte, "elle relève la porte, et seulement elle")
	var d := MINIMAP.DIAMETRE
	check(mm.vers_rond(j.global_position).is_equal_approx(Vector2(d, d) / 2.0), "l'habitant est au centre du rond")
	check(mm.vers_rond(porte.global_position).is_equal_approx(Vector2(d / 2.0 + 45.0 / MINIMAP.ETENDUE * d, d / 2.0)), "la porte, 45 m à l'est, est à droite du centre")
	check(mm.vers_rond(Vector3(0, 0, -30)).y < d / 2.0, "le nord (-Z) est en haut")
	check(mm.plan == null, "sans rendu, pas de photo (le fond de nuit reste)")
	var r := (mm.get_node("Rond") as Control).get_global_rect()
	check(r.end.x <= 1600.0 - MINIMAP.MARGE + 0.5 and r.position.y >= MINIMAP.MARGE - 0.5 and r.size.x >= d - 0.5, "en haut à droite, loin du coin : %s" % r)
	check(mm.layer < 40, "sous le carnet, la carte et les réglages, qui la couvrent")

	j.global_position = Vector3(20, 0, 0)
	await process_frame
	check(mm.vers_rond(porte.global_position).is_equal_approx(Vector2(d / 2.0 + 25.0 / MINIMAP.ETENDUE * d, d / 2.0)), "quand l'habitant marche, les points glissent")

	j.queue_free()
	await process_frame
	await process_frame
	check(not mm.visible, "sans habitant, elle se cache")

	# Posée par le socle avec le coin, retirée au retour à Smarves.
	var communes = root.get_node("Communes")
	communes._bouton_retour(true)
	check(communes._minimap != null and communes._minimap._voulue, "le socle la pose avec le coin")
	communes._bouton_retour(false)
	check(not communes._minimap.visible and not communes._minimap._voulue, "de retour à Smarves, elle s'en va")

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
