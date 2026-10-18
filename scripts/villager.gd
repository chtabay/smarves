extends Node3D
## Un habitant de Smarves : assis en terrasse, debout à regarder, en promenade entre deux points, ou derrière
## sa table au casino. Son allure vient de sa fiche (Cast) : un nom connu donne toujours le même personnage,
## un figurant est tiré de son nom de modèle et de sa place, pour rester le même d'une partie à l'autre.
##
## Ce qu'il fait tout seul : il respire, cligne des yeux, a ses petites manies, tourne la tête vers le joueur
## qui s'approche (puis le corps s'il s'attarde), bavarde avec son voisin, suit des yeux la table qu'on lui donne,
## et réagit aux coups (joie, dépit d'une seconde) quand la scène appelle react() ou crowd_react().

const CRITTER := preload("res://scripts/critter.gd")
const CROUPIER_SCALE := 0.8

## Nom de modèle (ancien nom de fichier, ou rôle : « croupier-roulette », « m-brunet »…), graine de l'allure.
var model_path := "habitant"
var pose := "idle"
var accessory := ""
## Qui parle : une clé de Lines.SPEAKERS (« habitant » par défaut).
var speaker := "habitant"
## Promenade : liste de points visités en boucle (vide = immobile).
var route: Array[Vector3] = []
var speed := 0.6
## Un point que l'habitant suit des yeux (une table, la scène) ; Vector3.INF = rien.
var watch := Vector3.INF

var critter: Node3D
## « public », « staff » ou « croupier » (voir Cast).
var role := "public"
var _fidgets: Array = []
var _leg := 0
var _pause := 0.0
var _home_yaw := 0.0
var _turn_goal := INF
var _fidget_wait := 0.0
var _think := 0.0
var _near_time := 0.0
var _chat_with: Node3D = null
var _talking := 0.0
## La pastille au-dessus d'un personnage nommé, vue seulement de loin (cran Quartier).
var _badge: Label3D = null


func _ready() -> void:
	add_to_group("villagers")
	var id := model_path.get_file()
	var seed_value := hash(id + str(position.snapped(Vector3.ONE * 0.1)))
	var info := Cast.resolve(id, speaker, accessory, seed_value, pose, _in_casino())
	critter = CRITTER.new()
	critter.look = info.look
	critter.idle_anim = info.idle
	critter.sit_anim = info.sit
	critter.walk_speed = speed
	role = info.role
	_fidgets = info.fidgets
	# Les croupiers un peu plus menus : ils restent dans le champ du joueur assis sans le boucher.
	if role == "croupier":
		scale *= CROUPIER_SCALE
	add_child(critter)
	if info.has("named") and not _in_casino():
		_add_badge(info.look)
	_apply_pose(pose if route.size() < 2 else "walk")
	_home_yaw = rotation.y
	_fidget_wait = randf_range(3.0, 10.0)
	# Une zone cliquable (au village) ou visée (au casino) pour lui parler.
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.36, 0.8, 0.36)
	cs.shape = box
	cs.position.y = 0.4
	area.add_child(cs)
	area.set_meta("talk", true)
	area.set_meta("interact", "talk")
	area.set_meta("prompt", "E : parler à %s" % Lines.display_name(speaker))
	add_child(area)


## Une pastille de la couleur qui signe le personnage (chapeau, sinon veste), cerclée de noir ; elle n'apparaît
## que quand la caméra est loin, là où la figurine n'est plus qu'un point. Sa taille se compte en pixels d'écran
## (BADGE_PX pour 1080 de haut), recalculée à chaque coup d'œil d'après la distance et le champ de la caméra.
const BADGE_FROM := 30.0
const BADGE_PX := 18.0
## Part de la hauteur de ligne qu'occupe le disque « ● » dans la police.
const BADGE_GLYPH := 0.5

func _add_badge(look: Dictionary) -> void:
	_badge = Label3D.new()
	_badge.text = "●"
	_badge.font_size = 64
	_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge.no_depth_test = true
	_badge.modulate = Color(look.get("hat_color", look.get("top_color", "#d4a443")))
	_badge.outline_size = 10
	_badge.outline_modulate = Color(0.07, 0.05, 0.06)
	_badge.position.y = 1.3
	_badge.visible = false
	add_child(_badge)


func _update_badge() -> void:
	var cam := get_viewport().get_camera_3d()
	var d := cam.global_position.distance_to(_badge.global_position) if cam else 0.0
	_badge.visible = d > BADGE_FROM
	if not _badge.visible:
		return
	var h := get_viewport().get_visible_rect().size.y
	# Unités du monde par pixel à cette distance, puis la taille voulue (rapportée à 1080 de haut).
	var per_px := 2.0 * d * tan(deg_to_rad(cam.fov) * 0.5) / h
	var px := BADGE_PX * h / 1080.0
	_badge.pixel_size = px * per_px / (_badge.font_size * BADGE_GLYPH) / global_basis.get_scale().y


func _in_casino() -> bool:
	var n: Node = get_parent()
	while n:
		if "casino" in n.scene_file_path or (n.get_script() and "casino_interior" in str(n.get_script().resource_path)):
			return true
		n = n.get_parent()
	return false


var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_time := 0.0


## Une bulle au-dessus de la tête, dessinée à l'écran pour rester nette malgré l'effet miniature.
func say(text: String) -> void:
	if _bubble == null:
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		_bubble = PanelContainer.new()
		# La bulle se lit, elle ne se touche pas : le sol dessous reste atteignable au doigt.
		_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.96, 0.9, 0.94)
		sb.set_corner_radius_all(14)
		sb.set_content_margin_all(10)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
		_bubble.add_theme_stylebox_override("panel", sb)
		_bubble_label = Label.new()
		_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubble_label.custom_minimum_size = Vector2(320, 0)
		_bubble_label.add_theme_font_override("font", Polices.texte())
		_bubble_label.add_theme_font_size_override("font_size", 17)
		_bubble_label.add_theme_color_override("font_color", Color(0.18, 0.1, 0.08))
		_bubble.add_child(_bubble_label)
		layer.add_child(_bubble)
	var who := Lines.display_name(speaker)
	_bubble_label.text = "%s
« %s »" % [who.substr(0, 1).to_upper() + who.substr(1), text]
	_bubble_time = 4.5 + text.length() * 0.045
	_bubble.modulate.a = 1.0
	_bubble.visible = true
	_bubble.reset_size()
	# Il se tourne vers le joueur et lui parle, avec les mains.
	var p := _player()
	if p:
		_face_point(p.global_position)
	critter.gesture("talk")
	critter.talk(minf(_bubble_time - 1.0, 3.0))
	critter.set_expression("attention" if role != "public" else "joie", 2.0)
	_talking = _bubble_time


func _update_bubble(delta: float) -> void:
	if _bubble == null or not _bubble.visible:
		return
	_bubble_time -= delta
	if _bubble_time < 0.8:
		_bubble.modulate.a = maxf(0.0, _bubble_time / 0.8)
	if _bubble_time <= 0.0:
		_bubble.visible = false
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var head := global_position + Vector3.UP * 0.95 * global_basis.get_scale().y
	if cam.is_position_behind(head):
		_bubble.modulate.a = 0.0
		return
	var p := cam.unproject_position(head)
	var view := get_viewport().get_visible_rect().size
	var r := Rect2(p - Vector2(_bubble.size.x / 2.0, _bubble.size.y + 6.0), _bubble.size)
	r.position.x = clampf(r.position.x, 12.0, maxf(12.0, view.x - r.size.x - 12.0))
	# Pas par-dessus l'interface (crédits, liste des lieux) : sous la tête, sinon à côté du panneau.
	for hud in _hud_rects():
		if r.intersects(hud):
			r.position.y = p.y + 24.0
			if r.intersects(hud):
				r.position.x = hud.end.x + 8.0 if p.x > hud.get_center().x else hud.position.x - r.size.x - 8.0
	_bubble.position = r.position


static var _hud_cache: Array[Rect2] = []
static var _hud_time := -10.0


## Les panneaux de l'interface à l'écran (rafraîchis toutes les secondes, pour toutes les bulles).
func _hud_rects() -> Array[Rect2]:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _hud_time < 1.0:
		return _hud_cache
	_hud_time = now
	_hud_cache.clear()
	var scene := get_tree().current_scene
	if scene == null:
		return _hud_cache
	var view := get_viewport().get_visible_rect().size
	for layer: CanvasLayer in scene.find_children("*", "CanvasLayer", true, false):
		# Les bulles des autres habitants ne comptent pas.
		if not layer.visible or layer.get_parent().is_in_group("villagers"):
			continue
		for panel: Control in layer.find_children("*", "PanelContainer", true, false):
			var rect := panel.get_global_rect()
			if panel.is_visible_in_tree() and rect.size.x < view.x * 0.6 and rect.size.y < view.y * 0.6:
				_hud_cache.append(rect)
	return _hud_cache


func _apply_pose(p: String) -> void:
	match p:
		"walk": critter.pose = CRITTER.Pose.WALK
		"sit": critter.pose = CRITTER.Pose.SIT
		_: critter.pose = CRITTER.Pose.IDLE


## Un coup de la partie : « win » (joie) ou « lose » (dépit d'une seconde, puis on repart).
func react(kind: String) -> void:
	if kind == "win":
		critter.gesture(["jump", "cheer", "clap"].pick_random() if pose != "sit" else ["cheer", "clap"].pick_random())
		critter.set_expression("joie", 1.8)
	elif kind == "big":
		critter.gesture("jump" if pose != "sit" else "cheer")
		critter.set_expression("surprise", 0.6)
		# Des Callable liés plutôt que des lambdas : la connexion tombe d'elle-même si le nœud disparaît.
		get_tree().create_timer(0.5).timeout.connect(critter.set_expression.bind("joie", 1.8))
	else:
		critter.gesture(["sulk", "facepalm", "shrug", "stomp"].pick_random() if pose != "sit" else ["sulk", "facepalm", "shrug"].pick_random())
		critter.set_expression("depit", 1.4)


## La réplique d'un voisin à qui l'on vient de parler.
func answer() -> void:
	if not critter.is_busy():
		critter.gesture(["nod", "shrug", "talk"].pick_random())


## Un geste du métier : le croupier qui lance la bille, donne une carte, ramasse ; le joueur qui mise.
func gesture(name: String) -> void:
	critter.gesture(name)


## Fait réagir tous les habitants proches d'un point (une table) ; le personnel garde son calme et salue.
static func crowd_react(tree: SceneTree, at: Vector3, radius: float, kind: String) -> void:
	for v in tree.get_nodes_in_group("villagers"):
		var d: float = v.global_position.distance_to(at)
		if d > radius:
			continue
		if v.role == "public":
			var delay := randf_range(0.0, 0.35)
			tree.create_timer(delay).timeout.connect(v.react.bind(kind))
		elif kind != "lose" and randf() < 0.6:
			v.gesture("nod")


## Fait faire un geste au croupier le plus proche d'un point.
static func dealer_gesture(tree: SceneTree, at: Vector3, radius: float, name: String) -> void:
	var best: Node3D = null
	var best_d := radius
	for v in tree.get_nodes_in_group("villagers"):
		if v.role != "croupier":
			continue
		var d: float = v.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = v
	# Une carte après l'autre : on ne recommence pas le geste en plein milieu.
	if best and not (name == "deal" and best.critter.is_busy()):
		best.gesture(name)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _face_point(p: Vector3) -> void:
	if pose == "sit" or role == "croupier":
		return
	var to := p - global_position
	_turn_goal = atan2(to.x, to.z) - (get_parent_node_3d().global_rotation.y if get_parent_node_3d() else 0.0)


func _process(delta: float) -> void:
	_update_bubble(delta)
	_talking = maxf(0.0, _talking - delta)
	var walking := route.size() >= 2 and _pause <= 0.0
	if route.size() >= 2:
		_walk(delta)
	elif _turn_goal != INF:
		rotation.y = lerp_angle(rotation.y, _turn_goal, 1.0 - exp(-5.0 * delta))
		if absf(angle_difference(rotation.y, _turn_goal)) < 0.01:
			rotation.y = _turn_goal
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(0.25, 0.4)
		_attention(walking)
		if _badge:
			_update_badge()
	if walking or _talking > 0.0:
		return
	_fidget_wait -= delta
	if _fidget_wait <= 0.0:
		_fidget_wait = randf_range(6.0, 14.0)
		_fidget()


## Où il regarde : le joueur qui s'approche, sinon son voisin de conversation, sinon sa table.
func _attention(walking: bool) -> void:
	var sc := global_basis.get_scale().y
	var p := _player()
	var near := false
	if p:
		var eye_h: float = p.get("eye") if p.get("eye") != null else 1.0
		var head := p.global_position + Vector3.UP * eye_h * (0.85 if p.get("follow_camera") == null else 0.9)
		var to := head - global_position
		to.y = 0.0
		var d := to.length() / sc
		var fwd := global_basis.z.normalized()
		var ahead := fwd.dot(to.normalized()) > -0.3
		near = d < 1.5 and (ahead or d < 0.6)
		if near:
			critter.look_at_point(head, 1.0)
			_near_time += 0.33
			# Le joueur s'attarde : on se tourne vers lui (sauf assis, ou le croupier à sa table).
			if _near_time > 1.6 and not walking:
				_face_point(p.global_position)
			return
	if _near_time > 0.0:
		_near_time = 0.0
		if route.size() < 2:
			_turn_goal = _home_yaw
	if _chat_with and is_instance_valid(_chat_with):
		critter.look_at_point(_chat_with.global_position + Vector3.UP * 0.6 * sc, 0.8)
		return
	if watch != Vector3.INF:
		critter.look_at_point(watch, 0.75)
		return
	critter.clear_look()


func _fidget() -> void:
	if critter.is_busy():
		return
	# Bavarder avec un voisin, de temps en temps.
	if role == "public" and randf() < 0.45:
		var sc := global_basis.get_scale().y
		var best: Node3D = null
		for v in get_tree().get_nodes_in_group("villagers"):
			if v != self and v.role == "public" and v.global_position.distance_to(global_position) < 1.1 * sc:
				best = v
				break
		_chat_with = best
		if best:
			critter.gesture("talk")
			critter.talk(1.8)
			if randf() < 0.6:
				get_tree().create_timer(2.2).timeout.connect(best.answer)
			return
	_chat_with = null
	if _fidgets.is_empty():
		return
	critter.gesture(_fidgets.pick_random())


func _walk(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_apply_pose("walk")
		return
	var target := route[_leg]
	var to := target - position
	to.y = 0
	if to.length() < 0.05:
		_leg = (_leg + 1) % route.size()
		_pause = randf_range(1.0, 4.0)
		_apply_pose("idle")
		if randf() < 0.5 and not _fidgets.is_empty():
			critter.gesture(_fidgets.pick_random())
		return
	position += to.normalized() * minf(speed * delta, to.length())
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-6.0 * delta))


## Pour les planches et les captures.
func debug_anim(what: String) -> void:
	critter.debug_anim(what)
