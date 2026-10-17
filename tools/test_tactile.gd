extends Node
## Vérifie les commandes tactiles en imitant des doigts : marcher en touchant le sol, tourner,
## pincer, le bouton Vue, puis le pouce virtuel et le regard au casino.
##   godot --path . res://tools/test_tactile.tscn -- --tactile
## Sans --tactile, vérifie que rien n'est créé (le PC ne change pas).

var report: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	Game.saving_enabled = false
	Game.welcomed = true
	# La fenêtre de bienvenue du carnet met le jeu en pause : pas pendant le test.
	Carnet._accueil_attendu = false
	if not "--tactile" in OS.get_cmdline_user_args():
		_check("PC : pas de commandes tactiles", not Tactile.active and Tactile.get_child_count() == 0)
		_end()
		return
	_check("commandes tactiles actives", Tactile.active)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await _wait(3.0)
	var m := get_tree().current_scene
	var p: CharacterBody3D = m.player
	var size := get_viewport().get_visible_rect().size
	_check("vue de dessus au départ", m.fps and m.topdown)

	# Toucher le sol un peu au-dessus de l'habitant : il y marche.
	var start := p.global_position
	var at: Vector2 = m.camera.unproject_position(start) + Vector2(0, -100)
	var origin: Vector3 = m.camera.project_ray_origin(at)
	var ray: Vector3 = m.camera.project_ray_normal(at)
	var aim := origin + ray * ((start.y - origin.y) / ray.y)
	await _tap(at)
	await _wait(2.5)
	_check("toucher le sol : l'habitant marche vers le point touché (%.1f m, reste %.1f m)" % [start.distance_to(p.global_position), Vector2(aim.x - p.global_position.x, aim.z - p.global_position.z).length()],
		start.distance_to(p.global_position) > 1.0 and Vector2(aim.x - p.global_position.x, aim.z - p.global_position.z).length() < 1.5)
	_check("puis s'arrête", p.auto_move == Vector3.ZERO)

	# Glisser : la vue tourne.
	var yaw: float = m.camera._yaw_goal
	await _drag(0, size * Vector2(0.55, 0.5), size * Vector2(0.75, 0.5))
	_check("glisser : la vue tourne", absf(m.camera._yaw_goal - yaw) > 0.3)

	# Pincer : écarter les doigts rapproche d'un cran.
	var notch: int = m.camera.notch
	await _pinch(size / 2.0, 60.0, 260.0)
	_check("écarter : un cran plus près (%d → %d)" % [notch, m.camera.notch], m.camera.notch < notch or notch == 0)
	notch = m.camera.notch
	await _pinch(size / 2.0, 260.0, 60.0)
	_check("pincer : un cran plus loin (%d → %d)" % [notch, m.camera.notch], m.camera.notch > notch)

	# Le bouton Vue vaut Tab.
	_check("bouton Vue affiché", Tactile._view_btn.visible)
	Tactile._view_btn.pressed.emit()
	await _wait(0.5)
	_check("bouton Vue : vue à pied", m.fps and not m.topdown)
	Tactile._view_btn.pressed.emit()
	await _wait(0.5)
	_check("bouton Vue : retour en vue de dessus", m.fps and m.topdown)
	_check("ligne d'aide du clavier cachée", not m._hint.visible)

	# Au casino : pouce virtuel et regard.
	get_tree().change_scene_to_file("res://scenes/casino.tscn")
	await _wait(3.0)
	var c := get_tree().current_scene
	p = c.player
	p.global_position = Vector3(0, 0.1, 16.0)
	p.rotation.y = 0.0
	await _wait(0.3)
	start = p.global_position
	var thumb := size * Vector2(0.15, 0.75)
	_touch(1, thumb, true)
	await _wait(0.05)
	_move(1, thumb + Vector2(0, -80), Vector2(0, -80))
	await _wait(1.0)
	_touch(1, thumb + Vector2(0, -80), false)
	await _wait(0.2)
	_check("pouce virtuel : on avance (%.1f m)" % (start.z - p.global_position.z), start.z - p.global_position.z > 1.0)
	_check("pouce relâché : on s'arrête", p.auto_move == Vector3.ZERO)
	var ry := p.rotation.y
	await _drag(2, size * Vector2(0.6, 0.4), size * Vector2(0.8, 0.4))
	_check("glisser à droite : on regarde ailleurs", absf(p.rotation.y - ry) > 0.3)
	_end()


func _check(label: String, ok: bool) -> void:
	report.append(("ok   " if ok else "ÉCHEC ") + label)


func _end() -> void:
	print("\n=== TACTILE ===")
	for r in report:
		print(r)
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Les positions sont en unités de l'interface ; l'écran tactile parle en pixels de la fenêtre.
func _win(pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * pos


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _win(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


func _move(index: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _win(pos)
	e.relative = get_tree().root.get_final_transform().basis_xform(rel)
	Input.parse_input_event(e)


func _tap(pos: Vector2) -> void:
	# Posé et levé dans la même image : le rendu logiciel est trop lent pour un vrai toucher bref.
	_touch(0, pos, true)
	_touch(0, pos, false)
	await get_tree().process_frame


func _drag(index: int, a: Vector2, b: Vector2) -> void:
	_touch(index, a, true)
	await get_tree().process_frame
	for i in range(1, 11):
		var prev := a.lerp(b, (i - 1) / 10.0)
		var pos := a.lerp(b, i / 10.0)
		_move(index, pos, pos - prev)
		await get_tree().process_frame
	_touch(index, b, false)
	await _wait(0.2)


func _pinch(center: Vector2, from: float, to: float) -> void:
	_touch(0, center - Vector2(from / 2.0, 0), true)
	_touch(1, center + Vector2(from / 2.0, 0), true)
	await get_tree().process_frame
	for i in range(1, 11):
		var d := lerpf(from, to, i / 10.0)
		_move(0, center - Vector2(d / 2.0, 0), Vector2.ZERO)
		_move(1, center + Vector2(d / 2.0, 0), Vector2.ZERO)
		await get_tree().process_frame
	_touch(0, center - Vector2(to / 2.0, 0), false)
	_touch(1, center + Vector2(to / 2.0, 0), false)
	await _wait(0.3)
