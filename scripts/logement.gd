extends "res://scripts/shop_interior.gd"
## L'intérieur d'un logement (Biens.visiting) : la chambre au-dessus du café, la maison de la rue de
## l'Église, la maison de maître sur la place. Les pièces du gabarit (Biens.INTERIEURS) sont des zones
## d'un même plateau, séparées par des cloisons percées de passages ; chaque emplacement y a sa place,
## et on y pose ses meubles sur place (E), comme depuis le carnet. Rien à vendre, personne au comptoir.

const MEUBLES_3D := preload("res://scripts/meubles.gd")
## La taille de chaque logement : largeur, profondeur, hauteur sous plafond.
const SIZES := {"chambre": Vector3(8, 6.5, 2.9), "maison": Vector3(14, 12, 3.1), "maison_place": Vector3(18, 16, 3.8)}
const FLOORS := {"chambre": Color(0.55, 0.38, 0.24), "maison": Color(0.5, 0.33, 0.2), "maison_place": Color(0.36, 0.2, 0.12)}
const PAPERS := {"chambre": [Color(0.78, 0.7, 0.55), Color(0.84, 0.77, 0.62)], "maison": [Color(0.62, 0.7, 0.62), Color(0.7, 0.77, 0.68)],
	"maison_place": [Color(0.52, 0.16, 0.18), Color(0.6, 0.2, 0.22)]}

var home := ""
## Où chaque emplacement se trouve : id → [position, orientation].
var _spots := {}
## Ce qui est posé, par emplacement, pour le remplacer quand on change de meuble.
var _placed := {}


func _ready() -> void:
	_serif = Polices.texte()
	# Capture : le logement et les biens viennent de la ligne de commande, avant de bâtir.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--logement="):
			Biens.visiting = arg.trim_prefix("--logement=")
	if "--capture" in " ".join(OS.get_cmdline_user_args()):
		for arg in OS.get_cmdline_user_args():
			_capture_setup(arg)
		_prepared = true
	home = Biens.visiting if Biens.logements.has(Biens.visiting) else ""
	if home == "":
		for id in Biens.logements:
			home = id
			break
	var size: Vector3 = SIZES.get(home, SIZES.chambre)
	W = size.x
	D = size.y
	H = size.z
	_environment()
	var paper: Array = PAPERS.get(home, PAPERS.chambre)
	_room(_wood_floor(FLOORS.get(home, FLOORS.chambre)), _wallpaper(paper[0], paper[1]), Color(0.95, 0.93, 0.88), paper[0].darkened(0.45))
	_layout()
	_door()
	_build_ui()
	player = PLAYER.new()
	player.position = Vector3(0, 0, D / 2.0 - 1.2)
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("village")
	Biens.changed.connect(_refurnish)
	_maybe_capture()


func _place_name() -> String:
	if home == "":
		return "Chez vous"
	return "%s  ·  %s" % [Biens.item(home).name, "chez vous" if Biens.is_habite(home) else "louée, visite du propriétaire"]


# --- Le plan : des pièces en grille, une allée depuis la porte ---------------------------------

## Les pièces du gabarit, rangées en grille ; la dernière rangée laisse l'entrée libre au milieu.
func _layout() -> void:
	var rooms: Array = Biens.INTERIEURS.get(str(Biens.logements.get(home, {}).get("interieur", "")), [])
	if rooms.is_empty():
		return
	var cols := int(ceil(sqrt(rooms.size())))
	var rows := int(ceil(float(rooms.size()) / cols))
	var cw := W / cols
	var rd := D / rows
	var by_room := {}
	for sl in Biens.slots(home):
		if not by_room.has(sl.piece):
			by_room[sl.piece] = []
		by_room[sl.piece].append(sl)
	# Les cases de la grille, de la plus proche de la porte à la plus lointaine : la première pièce du
	# gabarit (le salon) accueille, le jardin finit au fond.
	var cells := []
	for r in rows:
		for c in cols:
			cells.append(Vector2i(c, r))
	var door := Vector2(0, D / 2.0)
	cells.sort_custom(func(a, b): return _cell_center(a, cw, rd).distance_to(door) < _cell_center(b, cw, rd).distance_to(door))
	for i in rooms.size():
		var cell: Vector2i = cells[i]
		var rect := Rect2(-W / 2.0 + cell.x * cw, -D / 2.0 + cell.y * rd, cw, rd)
		var piece: String = rooms[i][0]
		_zone(rect, piece, cell.x, cell.y, cols)
		_arrange(rect, by_room.get(piece, []))
		if piece != "Jardin":
			_bulb(Vector3(rect.get_center().x, H - 0.6, rect.get_center().y), Color(0.9, 0.82, 0.65))
	_refurnish()


func _cell_center(cell: Vector2i, cw: float, rd: float) -> Vector2:
	return Vector2(-W / 2.0 + (cell.x + 0.5) * cw, -D / 2.0 + (cell.y + 0.5) * rd)


## Une pièce : son sol (de l'herbe pour le jardin), son nom écrit au sol, ses cloisons nord et ouest
## percées d'un passage.
func _zone(rect: Rect2, piece: String, c: int, r: int, cols: int) -> void:
	var center := Vector3(rect.get_center().x, 0, rect.get_center().y)
	if piece == "Jardin":
		var grass := _std(Color(0.3, 0.5, 0.22), 0.95)
		_box(Vector3(rect.size.x - 0.1, 0.02, rect.size.y - 0.1), center + Vector3(0, 0.01, 0), grass)
	else:
		_box(Vector3(rect.size.x - 0.6, 0.012, rect.size.y - 0.6), center + Vector3(0, 0.006, 0), _std(Color(0.55, 0.3, 0.25, 1).lerp(Color(0.3, 0.35, 0.5), float(c + r) / 4.0), 0.95))
	var l := _label3d(piece, Vector3(rect.position.x + 0.3, 0.03, rect.end.y - 0.35), 40, Color(0.95, 0.9, 0.78, 0.8))
	l.rotation_degrees.x = -90.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var paper: Array = PAPERS.get(home, PAPERS.chambre)
	var wall := _wallpaper(paper[0], paper[1])
	var gap := 1.4
	if r > 0:
		# Cloison nord, avec un passage au milieu.
		var half := (rect.size.x - gap) / 2.0
		_box(Vector3(half, H, 0.12), Vector3(rect.position.x + half / 2.0, H / 2.0, rect.position.y), wall, true)
		_box(Vector3(half, H, 0.12), Vector3(rect.end.x - half / 2.0, H / 2.0, rect.position.y), wall, true)
	if c > 0:
		var half := (rect.size.y - gap) / 2.0
		_box(Vector3(0.12, H, half), Vector3(rect.position.x, H / 2.0, rect.position.y + half / 2.0), wall, true)
		_box(Vector3(0.12, H, half), Vector3(rect.position.x, H / 2.0, rect.end.y - half / 2.0), wall, true)


## Où vont les emplacements d'une pièce : les murs au fond, le lit et la grande place au milieu,
## les meubles le long des côtés, les guéridons devant, le jardin en quinconce.
func _arrange(rect: Rect2, slots: Array) -> void:
	var by_genre := {}
	for sl in slots:
		if not by_genre.has(sl.genre):
			by_genre[sl.genre] = []
		by_genre[sl.genre].append(sl)
	var back := rect.position.y + 0.08
	for g in by_genre:
		var list: Array = by_genre[g]
		var n := list.size()
		for k in n:
			var t := (k + 1.0) / (n + 1.0)
			var pos := Vector3.ZERO
			var rot := 0.0
			match g:
				"mur":
					# De part et d'autre du passage percé au milieu de la cloison.
					var half := k % 2
					var per := (n + 1 - half) / 2
					var u := (k / 2 + 0.5) / maxf(1.0, per)
					var x_from := rect.position.x + 0.5 if half == 0 else rect.get_center().x + 1.0
					var x_to := rect.get_center().x - 1.0 if half == 0 else rect.end.x - 0.5
					pos = Vector3(lerpf(x_from, x_to, u), 1.25, back + 0.04)
				"lit":
					pos = Vector3(rect.get_center().x, 0, back + 1.05)
				"grand":
					pos = Vector3(rect.get_center().x, 0, rect.get_center().y + 0.3)
					rot = 90.0 if rect.size.y > rect.size.x else 0.0
				"sol":
					var left := k % 2 == 0
					var row := k / 2
					var rows := (n + 1) / 2
					pos = Vector3(rect.position.x + 0.75 if left else rect.end.x - 0.75, 0, lerpf(rect.position.y + 1.2, rect.end.y - 1.0, (row + 0.5) / rows))
					rot = 90.0 if left else -90.0
				"petit":
					pos = Vector3(lerpf(rect.position.x + 1.4, rect.end.x - 1.4, t), 0, rect.end.y - 1.1)
					_gueridon(pos)
					pos.y = 0.66
				"jardin":
					pos = Vector3(lerpf(rect.position.x + 1.0, rect.end.x - 1.0, t), 0, rect.get_center().y + (0.8 if k % 2 else -0.8))
			_spots[list[k].id] = [pos, rot]
			var hit := Node3D.new()
			hit.position = pos
			add_child(hit)
			var a := _interactive(hit, "slot", "", Vector3(1.0, 1.4, 1.0), Vector3(0, 0.6 if g != "mur" else 0.0, 0.3 if g == "mur" else 0.0))
			a.set_meta("slot", list[k].id)
			a.set_meta("label", list[k].label)


func _gueridon(pos: Vector3) -> void:
	var wood := _std(Color(0.3, 0.17, 0.09), 0.4)
	_cyl(0.28, 0.04, pos + Vector3(0, 0.64, 0), wood)
	_cyl(0.035, 0.62, pos + Vector3(0, 0.31, 0), wood)
	_cyl(0.18, 0.03, pos + Vector3(0, 0.015, 0), wood)


## Repose les meubles d'après Biens.logements : ce qui a changé est remplacé, le reste ne bouge pas.
func _refurnish() -> void:
	if home == "" or not Biens.logements.has(home):
		return
	var meubles: Dictionary = Biens.logements[home].meubles
	for slot in _spots:
		var want := str(meubles.get(slot, ""))
		var have: Node3D = _placed.get(slot)
		if have != null and str(have.get_meta("thing", "")) == want:
			continue
		if have != null:
			have.queue_free()
			_placed.erase(slot)
		if want == "":
			continue
		var m: Node3D = MEUBLES_3D.build(want)
		m.set_meta("thing", want)
		m.position = _spots[slot][0]
		m.rotation_degrees.y = _spots[slot][1]
		add_child(m)
		_placed[slot] = m
	# Les invites suivent ce qui est posé.
	for a in find_children("*", "Area3D", true, false):
		if a.get_meta("interact", "") == "slot":
			var cur := str(meubles.get(a.get_meta("slot"), ""))
			var label: String = a.get_meta("label")
			a.set_meta("prompt", "E : %s  ·  %s" % [label, Biens.name_of(cur) if cur != "" else "poser un meuble"])


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			Game.return_point = str(Biens.item(home).get("lot", ""))
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		"slot":
			Biens.cycle(home, str(target.get_meta("slot")))
			if Biens.posables(_genre_of_slot(str(target.get_meta("slot")))).is_empty() and str(Biens.logements[home].meubles.get(target.get_meta("slot"), "")) == "":
				say("Rien à poser ici. Ginette Boutin a ce qu'il faut, rue du Clain.")


func _genre_of_slot(slot: String) -> String:
	for sl in Biens.slots(home):
		if sl.id == slot:
			return sl.genre
	return ""


func say(text: String) -> void:
	_speech.text = text
	_speech.modulate.a = 1.0
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = create_tween()
	_speech_tween.tween_interval(3.0 + text.length() * 0.04)
	_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.8)
