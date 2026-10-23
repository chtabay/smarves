extends CanvasLayer
## Les commandes tactiles (autoload « Tactile »). Elles n'existent que sur téléphone, ou avec
## l'argument --tactile pour les essayer sur ordinateur : sur PC sans cet argument, rien n'est créé.
## Elles ne touchent pas aux lieux : elles jouent les touches du clavier (E, Tab, C, Échap) et
## pilotent l'habitant par sa marche imposée (auto_move) et la caméra de maquette (turn, set_notch).
##
## Vue de dessus : toucher le sol pour y marcher, toucher une porte ou un habitant pour y aller et
## agir comme avec E, glisser pour tourner la vue, pincer pour changer de cran.
## Vue à pied (casino, Tab au village) : pouce virtuel à gauche, glisser à droite pour regarder,
## toucher une table ou une porte proche pour agir.
## L'invite « E : … » devient un bouton ; Vue (Tab), Carnet (C) et Menu (Échap) sont dans un coin.
## Une scène qui a une méthode action_tactile() (le texte de sa touche F, vide quand elle ne sert pas)
## a aussi son bouton quand rien n'est à portée de E : Casino Minuit y met « Frapper ».
## Le bouton retour d'Android vaut Échap.

## Plus petit que ça, un toucher est un « tap » ; au-delà, c'est un glissé.
const TAP_SLOP := 18.0
const TAP_TIME := 0.5
## Rayon du pouce virtuel, en pixels de la base d'écran.
const STICK_RADIUS := 70.0
const KIT := preload("res://scripts/jeux/kit.gd")

var active := false

var _surface: Control
var _act: Button
## Le bouton tient l'invite « V : … » (descendre du véhicule) plutôt qu'une action E.
var _act_v := false
## Le bouton joue la touche F de la scène (action_tactile()) plutôt que E.
var _act_f := false
var _view_btn: Button
var _carte_btn: Button
var _carnet_btn: Button
var _menu_btn: Button
var _stick_base: Panel
var _stick_knob: Panel
## Les boutons de coin : en bas à droite en marchant, en haut à droite dans un lieu (la barre de
## jeu occupe le bas).
var _corner: HBoxContainer
var _corner_top := false

## Les doigts posés sur la surface : index → {start, pos, time, role}.
var _touches := {}
var _pinch_start := 0.0
## Le doigt du pouce virtuel (-1 : aucun) et sa direction (x à droite, y vers le bas).
var _stick_index := -1
var _stick_vec := Vector2.ZERO
## Marche vers un point touché (vue de dessus).
var _goal := Vector3.INF
var _goal_target: Node = null
var _goal_time := 0.0
var _goal_best := INF
var _goal_since_best := 0.0
## Les lignes d'aide du clavier de la scène en cours, cachées au doigt.
var _hints: Array[Node] = []
var _hints_scene: Node = null
var _hints_wait := 0.0


func _ready() -> void:
	active = OS.has_feature("mobile") or "--tactile" in OS.get_cmdline_user_args()
	if not active:
		set_process(false)
		set_physics_process(false)
		return
	# Au-dessus du carnet (40), de la bienvenue (45) et de la carte (46), pour que « Fermer » reste sous
	# le doigt ; les autres boutons se cachent quand le jeu est en pause.
	layer = 47
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Le retour d'Android ne quitte plus le jeu : il ferme ce qui est ouvert (Échap).
	get_tree().quit_on_go_back = false
	_apply_ui_scale()
	_build()


## L'interface est dessinée pour 1600 × 900. Sur un téléphone, on prend une base plus petite pour que
## tout grossisse : environ 222 unités par pouce de hauteur d'écran, entre 600 (téléphone de 6 pouces
## en paysage, tout grossit de moitié) et 900 (tablette, rien ne change). --base=600 pour l'essayer.
func _apply_ui_scale() -> void:
	var h := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--base="):
			h = int(arg.trim_prefix("--base="))
	if h == 0:
		var screen := DisplayServer.screen_get_size()
		var inches := float(mini(screen.x, screen.y)) / maxf(1.0, DisplayServer.screen_get_dpi())
		h = clampi(roundi(inches * 222.0), 600, 900)
	var base_h: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	var base_w: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	if h >= base_h:
		return
	get_tree().root.content_scale_size = Vector2i(roundi(base_w * float(h) / base_h), h)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and active:
		press_key(KEY_ESCAPE)


## Joue une touche comme si on l'avait frappée : les lieux, le carnet et les tables l'écoutent déjà.
func press_key(key: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = pressed
		Input.parse_input_event(e)


# --- Ce qu'on lit de la scène en cours (sans dépendre de son script) ----------------------------

func _scene() -> Node:
	return get_tree().current_scene


func _player() -> CharacterBody3D:
	var s := _scene()
	if s == null:
		return null
	var p = s.get("player")
	return p if p is CharacterBody3D and is_instance_valid(p) else null


## On marche (vue de dessus ou à pied), sans jeu, carnet ni réglages ouverts.
func _walking() -> bool:
	var p := _player()
	if p == null or p.frozen or get_tree().paused:
		return false
	var s := _scene()
	if s.get("fps") == false:
		return false
	return not (Carnet.is_open() or Settings.is_open())


func _topdown(p: CharacterBody3D) -> bool:
	return p.get("follow_camera") != null


# --- L'interface ---------------------------------------------------------------------------------

func _build() -> void:
	# La surface des gestes est sous toute l'interface du jeu (couche -100) : elle ne reçoit que les
	# touchers qui ne tombent sur aucun bouton, et avale les clics que Godot imite à partir du toucher,
	# pour qu'un pouce posé ne vaille pas un clic sur la table d'en face.
	var under := CanvasLayer.new()
	under.layer = -100
	add_child(under)
	_surface = Control.new()
	_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.gui_input.connect(_on_surface_input)
	under.add_child(_surface)

	_act = _button("", 24)
	_act.pressed.connect(_on_act)
	_act.visible = false
	add_child(_act)

	var corner := HBoxContainer.new()
	corner.add_theme_constant_override("separation", 14)
	add_child(corner)
	_corner = corner
	_place_corner()
	_view_btn = _button("Vue", 22)
	_view_btn.pressed.connect(press_key.bind(KEY_TAB))
	corner.add_child(_view_btn)
	# La carte de la Vienne : au doigt, rien ne la montrait que le pincer au-delà du dernier cran.
	_carte_btn = _button("Carte", 22)
	_carte_btn.pressed.connect(func():
		if Carte.peut_ouvrir():
			Carte.ouvrir())
	corner.add_child(_carte_btn)
	_carnet_btn = _button("Carnet", 22)
	_carnet_btn.pressed.connect(press_key.bind(KEY_C))
	corner.add_child(_carnet_btn)
	_menu_btn = _button("Menu", 22)
	_menu_btn.pressed.connect(press_key.bind(KEY_ESCAPE))
	corner.add_child(_menu_btn)

	_stick_base = _disc(STICK_RADIUS, Color(1, 0.92, 0.7, 0.16))
	_stick_knob = _disc(STICK_RADIUS * 0.45, Color(1, 0.92, 0.7, 0.45))
	_stick_base.visible = false
	_stick_knob.visible = false
	add_child(_stick_base)
	add_child(_stick_knob)


func _place_corner() -> void:
	# Ancres et marges remises d'un bloc : set_anchors_preset seul garderait la position courante.
	_corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT if _corner_top else Control.PRESET_BOTTOM_RIGHT)
	_corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_corner.grow_vertical = Control.GROW_DIRECTION_END if _corner_top else Control.GROW_DIRECTION_BEGIN
	_corner.offset_right = -24
	if _corner_top:
		_corner.offset_top = 24
	else:
		_corner.offset_bottom = -24


func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(100, 64)
	b.add_theme_font_override("font", KIT.serif())
	b.add_theme_font_size_override("font_size", size)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.05, 0.03, 0.82 if state != "pressed" else 0.95)
		sb.border_color = Color(0.96, 0.8, 0.45, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	b.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.7))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	return b


func _disc(r: float, col: Color) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size = Vector2(r, r) * 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	p.add_theme_stylebox_override("panel", sb)
	return p


func _process(delta: float) -> void:
	# Pas de souris capturée au doigt : les boutons et la surface des gestes doivent voir les touchers.
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p := _player()
	var walking := _walking()
	_surface.mouse_filter = Control.MOUSE_FILTER_STOP if walking else Control.MOUSE_FILTER_IGNORE
	if not walking:
		_touches.clear()
		_release_stick()
	var s := _scene()
	_view_btn.visible = walking and s != null and (s.has_method("set_fps") or Vue.gere(s))
	_carte_btn.visible = walking and not Carnet.is_open() and Carte.peut_ouvrir()
	_carnet_btn.visible = (walking or Carnet.is_open()) and not Settings.is_open()
	var lettres: int = Avis.non_lus().size()
	_carnet_btn.text = "Fermer" if Carnet.is_open() else ("Carnet (%d)" % lettres if lettres > 0 else "Carnet")
	# Dans un lieu (café, banque, table…), l'habitant est figé et Échap en sort : le bouton le dit.
	var inside: bool = p != null and p.frozen and not get_tree().paused and not (Carnet.is_open() or Settings.is_open())
	_menu_btn.visible = walking or inside
	_menu_btn.text = "Menu" if walking else "Sortir"
	if inside != _corner_top:
		_corner_top = inside
		_place_corner()
	_fit_carnet()
	# Les touches du clavier ne servent pas au doigt : les lignes d'aide « ZQSD : marcher… » s'effacent.
	if s != _hints_scene:
		_hints_scene = s
		_hints.clear()
	_hints_wait -= delta
	if s != null and _hints.is_empty() and _hints_wait <= 0.0:
		_hints_wait = 1.0
		for l in s.find_children("*", "Label", true, false):
			if (l as Label).text.begins_with("ZQSD") or (l as Label).text.begins_with("Cliquer sur un lieu"):
				_hints.append(l)
	for l in _hints:
		if is_instance_valid(l):
			l.visible = false
	_update_act(p, walking)


## Le carnet est dessiné pour 1600 × 900 : sur un petit écran, sa couverture et son plan rapetissent
## pour tenir dedans, centrés comme avant.
func _fit_carnet() -> void:
	if not Carnet.is_open():
		return
	var size := get_viewport().get_visible_rect().size
	for c: Control in [Carnet._cover, Carnet._sheet]:
		if c == null or not c.visible or c.size.x <= 0.0:
			continue
		var s := minf(1.0, minf((size.x - 16.0) / c.size.x, (size.y - 16.0) / c.size.y))
		c.pivot_offset = c.size / 2.0
		# Plus haute que l'écran, la couverture pousse son conteneur et se pose en haut : le pivot la ramène
		# au milieu de l'écran une fois rapetissée.
		if s < 1.0:
			var haut := (c.get_parent() as Control).global_position + c.position
			c.pivot_offset = ((size - c.size * s) / 2.0 - haut) / (1.0 - s)
		c.scale = Vector2(s, s)


## L'invite « E : … » de la scène devient un bouton posé dessus, avec le même texte sans le « E : ».
func _update_act(p: CharacterBody3D, walking: bool) -> void:
	var s := _scene()
	var prompt = s.get("_prompt") if s != null else null
	var show := walking and prompt is Label and (prompt as Label).visible
	# « V : descendre de la 2 CV » : en roulant, sans rien à portée (scripts/village/conduite.gd).
	_act_v = show and p.focus_target == null and (prompt as Label).text.begins_with("V : ")
	show = show and (p.focus_target != null or _act_v)
	if show and ((prompt as Label).text.begins_with("E : ") or _act_v):
		_act.text = (prompt as Label).text.substr(4)
		_act.reset_size()
		var r: Rect2 = (prompt as Label).get_global_rect()
		_act.position = r.get_center() - _act.size / 2.0
	else:
		show = false
	# Rien à portée de E, mais la scène propose sa touche F (frapper, au casino de Minuit) : le bouton la joue.
	_act_f = false
	if not show and walking and p.focus_target == null and s != null and s.has_method("action_tactile"):
		var t := str(s.action_tactile())
		if t != "":
			show = true
			_act_f = true
			if _act.text != t:
				_act.text = t
				_act.reset_size()
			var vp := get_viewport().get_visible_rect().size
			_act.position = Vector2(vp.x / 2.0, vp.y - 75.0) - _act.size / 2.0
	_act.visible = show


func _on_act() -> void:
	if _act_v:
		_stop_goal()
		press_key(KEY_V)
		return
	if _act_f:
		press_key(KEY_F)
		return
	var p := _player()
	if p != null and p.focus_target != null:
		_stop_goal()
		p.interact.emit(p.focus_target)


# --- Les gestes ----------------------------------------------------------------------------------

func _on_surface_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
		_surface.accept_event()
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position, event.relative)
		_surface.accept_event()
	elif event is InputEventMouse:
		# Les clics imités du toucher : la surface les garde pour elle.
		_surface.accept_event()


func _touch_down(index: int, pos: Vector2) -> void:
	var p := _player()
	if p == null:
		return
	var role := "tap"
	# Le pouce virtuel à gauche, en vue de dessus comme à pied (un toucher bref y reste un « tap »).
	if pos.x < _surface.size.x * 0.4 and _stick_index == -1:
		role = "stick"
		_stick_index = index
		_stick_base.position = pos - _stick_base.size / 2.0
		_stick_base.visible = true
		_stick_knob.visible = true
		_place_knob(pos)
	_touches[index] = {"start": pos, "pos": pos, "time": Time.get_ticks_msec() / 1000.0, "role": role}
	if _touches.size() == 2 and _topdown(p):
		# Deux doigts en vue de dessus : un pincement, même si le premier était posé sur le pouce.
		_release_stick()
		_pinch_start = _pinch_distance()
		for t in _touches.values():
			t.role = "pinch"


func _touch_move(index: int, pos: Vector2, rel: Vector2) -> void:
	if not _touches.has(index):
		return
	var t: Dictionary = _touches[index]
	t.pos = pos
	var p := _player()
	if p == null:
		return
	match t.role:
		"stick":
			_place_knob(pos)
		"pinch":
			_on_pinch(p)
		_:
			if t.role == "tap" and pos.distance_to(t.start) > TAP_SLOP:
				t.role = "drag"
			if t.role == "drag":
				_look(p, rel)


func _touch_up(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var t: Dictionary = _touches[index]
	_touches.erase(index)
	var brief: bool = Time.get_ticks_msec() / 1000.0 - t.time < TAP_TIME and pos.distance_to(t.start) <= TAP_SLOP
	if t.role == "stick":
		_release_stick()
		if brief:
			_tap(pos)
	elif t.role == "tap" and brief:
		_tap(pos)
	if _touches.size() < 2:
		for o in _touches.values():
			if o.role == "pinch":
				o.role = "drag"


func _place_knob(pos: Vector2) -> void:
	var c := _stick_base.position + _stick_base.size / 2.0
	var d := (pos - c).limit_length(STICK_RADIUS)
	_stick_vec = d / STICK_RADIUS
	_stick_knob.position = c + d - _stick_knob.size / 2.0


func _release_stick() -> void:
	if _stick_index == -1:
		return
	_stick_index = -1
	_stick_vec = Vector2.ZERO
	_stick_base.visible = false
	_stick_knob.visible = false
	var p := _player()
	if p != null and _goal == Vector3.INF:
		p.auto_move = Vector3.ZERO


func _pinch_distance() -> float:
	var pts: Array = _touches.values()
	return (pts[0].pos as Vector2).distance_to(pts[1].pos)


## Écarter les doigts rapproche la vue d'un cran, les pincer l'éloigne.
func _on_pinch(_p: CharacterBody3D) -> void:
	if _touches.size() != 2 or _pinch_start <= 0.0:
		return
	var cam = _scene().get("camera")
	if cam == null or not cam.has_method("set_notch") or cam.notches.is_empty():
		return
	var ratio := _pinch_distance() / _pinch_start
	if ratio > 1.3:
		cam.set_notch(cam.notch - 1)
		_pinch_start = _pinch_distance()
	elif ratio < 0.77:
		cam.set_notch(cam.notch + 1)
		_pinch_start = _pinch_distance()


func _look(p: CharacterBody3D, rel: Vector2) -> void:
	if _topdown(p):
		var cam = p.follow_camera
		if cam.has_method("turn"):
			cam.turn(rel.x, 0.0)
		return
	# À pied : le même regard que la souris (fp_player.gd), un peu plus vif au doigt.
	p.rotation.y -= rel.x * 0.005
	var pitch := clampf(p.camera.rotation.x - rel.y * 0.004, deg_to_rad(-70), deg_to_rad(60))
	p.set("_pitch", pitch)
	p.camera.rotation.x = pitch


## Un toucher bref : agir sur ce qu'on touche (comme E), ou, en vue de dessus, marcher jusque-là.
func _tap(pos: Vector2) -> void:
	var p := _player()
	if p == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.project_ray_origin(pos)
	var dir := cam.project_ray_normal(pos)
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.hit_from_inside = true
	var hit := space.intersect_ray(q)
	var target: Node = hit.collider if hit and hit.collider.has_meta("interact") else null
	if not _topdown(p):
		# À pied : seulement ce qui est à portée de main, comme le clic du casino.
		if target and (target as Node3D).global_position.distance_to(p.global_position) < p.reach * 1.6:
			p.interact.emit(target)
		return
	if target:
		_walk_to((target as Node3D).global_position, target)
		return
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.exclude = [p.get_rid()]
	var ground := space.intersect_ray(q)
	if ground:
		_walk_to(ground.position, null)


func _walk_to(at: Vector3, target: Node) -> void:
	_goal = at
	_goal_target = target
	_goal_time = 0.0
	_goal_best = INF
	_goal_since_best = 0.0


func _stop_goal() -> void:
	if _goal == Vector3.INF:
		return
	_goal = Vector3.INF
	_goal_target = null
	var p := _player()
	if p != null:
		p.auto_move = Vector3.ZERO


func _physics_process(delta: float) -> void:
	var p := _player()
	if p == null or not _walking():
		_goal = Vector3.INF
		_goal_target = null
		return
	if _stick_index != -1:
		_goal = Vector3.INF
		# Le pouce : vers le haut, on avance (repère du joueur, comme ZQSD).
		p.auto_move = Vector3(_stick_vec.x, 0, _stick_vec.y) if _stick_vec.length() > 0.15 else Vector3.ZERO
		return
	if _goal == Vector3.INF:
		return
	# Arrivé devant ce qu'on a touché : la même action que E.
	if _goal_target != null and is_instance_valid(_goal_target) and p.focus_target == _goal_target:
		var t := _goal_target
		_stop_goal()
		p.interact.emit(t)
		return
	var to := _goal - p.global_position
	to.y = 0.0
	var d := to.length()
	_goal_time += delta
	if d < _goal_best - 0.05:
		_goal_best = d
		_goal_since_best = 0.0
	else:
		_goal_since_best += delta
	# Arrivé, bloqué contre un mur, ou trop long : on s'arrête là.
	var near := 0.9 if _goal_target != null else 0.35
	if d < near or _goal_since_best > 1.2 or _goal_time > 20.0:
		_stop_goal()
		return
	var world := to / d
	if _topdown(p):
		# fp_player.gd tourne la marche imposée selon le lacet de la caméra qui suit.
		var yaw: float = p.follow_camera.global_rotation.y
		p.auto_move = Basis(Vector3.UP, yaw).inverse() * world
	else:
		p.auto_move = p.global_basis.inverse() * world
