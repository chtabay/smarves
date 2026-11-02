extends Node
## La Mobylette bleue du socle, garée dans une commune greffée (socle 1.31) : la même qu'à Smarves
## (Biens.build_vehicle), menée comme à Belley et à Lyon, où elle est née (#432, #433). E (ou V) devant elle
## pour l'enfourcher, V pour en descendre ; elle reste où on l'a laissée. Au téléphone, l'invite devient un
## bouton « Enfourcher la Mobylette bleue », puis « Descendre de la Mobylette » (scripts/tactile/tactile.gd
## lit les invites du groupe « invites »).
##
## Le socle en pose une à l'arrivée de toute commune qui n'a pas la sienne (Mobylettes,
## scripts/socle/mobylettes.gd). Une commune peut aussi en garer où elle veut :
##     add_child(preload("res://scripts/socle/mobylette.gd").new(self, Vector3(x, y, z), cap))
## Toutes les longueurs suivent la taille de l'habitant (player.body_height), mesurée à Belley (1,7 m,
## Mobylette ×5,1) et vérifiée à Lyon (0,7 unité, ×2,125) : une commune en mètres comme une commune en
## unités du jeu la voit à la même taille sous son habitant.
## Test : godot --headless --path . -s tools/test_mobylette.gd

## Le dessin du socle fois ceci fois la taille de l'habitant : selle à 0,45 de sa hauteur, guidon à 0,57.
const ECHELLE := 3.0
## Au guidon, le pas de l'habitant fois ceci (3,2 m/s × 3,6 ≈ 41 km/h à Belley).
const ALLURE := 3.6
## La largeur du corps au guidon, la portée de V, et où elle attend à l'arrivée (à gauche, un peu devant),
## en tailles d'habitant.
const RAYON := 0.19
const PORTEE := 1.47
const COTE := -1.18
const DEVANT := 0.82
## Le bassin sur la selle, en arrière du milieu (Lyon, #433 : à Belley on le voyait sur le réservoir).
const SELLE_RECUL := 0.21
## Une seule Mobylette à la fois sous l'habitant.
static var en_selle: Node = null

var scene: Node3D
var player: CharacterBody3D
var mob: Node3D
var monte := false
## Où elle attend, dans le repère de la scène, et son cap ; INF : près de l'habitant à l'arrivée.
var ou := Vector3.INF
var cap := 0.0
var _zone: Area3D
var _prompt: Label
var _taille := 0.7
var _vitesse_pied := 0.0
var _rayon_pied := 0.0


func _init(s: Node3D, place := Vector3.INF, lacet := 0.0, nom := "Mobylette") -> void:
	scene = s
	ou = place
	cap = lacet
	name = nom
	add_to_group("invites")
	add_to_group("mobylettes")


func _ready() -> void:
	player = scene.get("player")
	_taille = float(player.body_height) if player.get("body_height") != null else 1.7
	_vitesse_pied = player.speed
	_rayon_pied = player.radius
	mob = Biens.build_vehicle("mobylette")
	mob.name = name + "Bleue"
	mob.scale = Vector3.ONE * _echelle()
	scene.add_child(mob)
	if ou == Vector3.INF:
		var devant := -player.global_basis.z
		devant.y = 0.0
		devant = devant.normalized() if devant.length() > 0.01 else Vector3.FORWARD
		var at := player.global_position + devant.cross(Vector3.UP) * COTE * _taille + devant * DEVANT * _taille
		at.y = _sol(at, player.global_position.y)
		_garer(at, atan2(devant.x, devant.z) + 0.5)
	else:
		_garer(ou, cap)
	_zone = Area3D.new()
	_zone.set_meta("interact", "mobylette")
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.3, 0.3, 0.45)
	cs.shape = b
	cs.position = Vector3(0, 0.15, 0)
	_zone.add_child(cs)
	mob.add_child(_zone)
	player.interact.connect(_on_interact)
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -70.0
	_prompt.offset_bottom = -40.0
	_prompt.offset_left = -300.0
	_prompt.offset_right = 300.0
	_prompt.visible = false
	ui.add_child(_prompt)
	Vue.basculee.connect(_on_basculee)


func _exit_tree() -> void:
	if en_selle == self:
		en_selle = null


func _echelle() -> float:
	return ECHELLE * _taille


func _process(_delta: float) -> void:
	var t := ""
	if monte:
		t = "V : descendre de la Mobylette"
	elif en_selle == null and player.focus_target == _zone:
		t = "E : enfourcher la Mobylette bleue"
	_prompt.text = t
	_prompt.visible = t != "" and not player.frozen


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		if player.frozen:
			return
		if monte:
			descendre()
			get_viewport().set_input_as_handled()
		elif en_selle == null and mob.global_position.distance_to(player.global_position) < PORTEE * _taille:
			monter()
			get_viewport().set_input_as_handled()


func _on_interact(target: Node) -> void:
	if target == _zone:
		monter()
	elif monte:
		# Une porte, un comptoir qu'on prend en roulant : on se gare devant d'abord (comme au village).
		descendre()


func monter() -> void:
	if monte or player.frozen or en_selle != null:
		return
	monte = true
	en_selle = self
	(_zone.get_child(0) as CollisionShape3D).disabled = true
	mob.reparent(player, false)
	# La Mobylette regarde +Z, l'habitant avance vers -Z.
	mob.position = Vector3.ZERO
	mob.rotation = Vector3(0, PI, 0)
	mob.scale = Vector3.ONE * _echelle()
	player.speed = _vitesse_pied * ALLURE
	player.set_radius(RAYON * _taille)
	_poser_habitant()
	Sfx.play("tick")


## La Mobylette reste là où l'on est, l'habitant met pied à terre à côté.
func descendre() -> void:
	if not monte:
		return
	monte = false
	en_selle = null
	var yaw := player.global_rotation.y
	var ici := player.global_position
	mob.reparent(scene, false)
	mob.scale = Vector3.ONE * _echelle()
	_garer(ici, yaw + PI)
	(_zone.get_child(0) as CollisionShape3D).disabled = false
	player.speed = _vitesse_pied
	player.set_radius(_rayon_pied)
	player.assis = false
	if player.avatar:
		player.avatar.position = Vector3.ZERO
		player.avatar.pose = 0
	var cote := player.global_basis.x * (0.35 * _taille)
	if not player.test_move(player.global_transform, cote):
		player.global_position += cote


func _garer(at: Vector3, lacet: float) -> void:
	mob.global_position = at
	mob.global_rotation = Vector3(0, lacet, 0)


## Le sol sous `at` : un rayon qui descend depuis la hauteur du genou (les toits et les branches restent
## au-dessus), et à défaut l'altitude de l'habitant.
func _sol(at: Vector3, defaut: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, defaut + _taille * 0.5, at.z), Vector3(at.x, defaut - _taille * 3.0, at.z))
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if hit else defaut


func _on_basculee(_topdown: bool) -> void:
	_poser_habitant()


## Assis sur la selle, le bassin au-dessus de la partie brune (critter.gd baisse les hanches de « _seat »).
func _poser_habitant() -> void:
	if not monte or player.avatar == null:
		return
	player.assis = true
	player.avatar.pose = 2
	var seat := float(player.avatar.get("_seat")) if player.avatar.get("_seat") != null else 0.09
	var s: float = player.avatar.scale.y
	player.avatar.position = Vector3(0, Biens.selle("mobylette") * _echelle() - seat * s, SELLE_RECUL * _taille)
