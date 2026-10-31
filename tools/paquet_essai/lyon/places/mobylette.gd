extends Node
## Une Mobylette bleue garée dans Lyon, pour aller plus vite d'un quartier à l'autre (Guillaume, 31 octobre :
## « même mobylette que dans Smarves », utilitaire). C'est la Mobylette du socle (Biens.build_vehicle), menée
## comme à Belley (communes/belley/places/mobylette.gd) : E (ou V) devant elle pour l'enfourcher, V pour en
## descendre, elle reste où on l'a laissée. Lyon compte en unités du jeu (2,4 m) : toutes les longueurs de
## Belley, qui compte en mètres, sont divisées par U.

const U := 2.4
## Le dessin du socle est à l'échelle des petits Smarvois : ×5,1 pour l'habitant, mesuré de profil à côté de lui
## à Belley (#432 : selle à 0,45 de sa hauteur, guidon à 0,57), puis en unités.
const ECHELLE := 5.1 / U
## Au guidon, le pas de l'habitant fois ceci (comme à Belley).
const ALLURE := 3.6
const RAYON := 0.32 / U
const PORTEE := 2.5 / U
## Où elle attend quand on ne donne pas de place : à gauche de l'habitant à l'arrivée, un peu devant.
const COTE := -2.0 / U
const DEVANT := 1.4 / U
## Une seule Mobylette à la fois sous l'habitant.
static var en_selle: Node = null

var scene: Node3D
var player: CharacterBody3D
var mob: Node3D
var monte := false
## La place, en mètres dans le repère de la ville (x, z), et le cap ; INF : près de l'arrivée.
var ou_m := Vector2.INF
var cap := 0.0
var _zone: Area3D
var _prompt: Label
var _vitesse_pied := 0.0
var _rayon_pied := 0.0


func _init(s: Node3D, place_m := Vector2.INF, lacet := 0.0, nom := "Mobylette") -> void:
	scene = s
	ou_m = place_m
	cap = lacet
	name = nom


func _ready() -> void:
	player = scene.player
	_vitesse_pied = player.speed
	_rayon_pied = player.radius
	mob = Biens.build_vehicle("mobylette")
	mob.name = name + "Bleue"
	mob.scale = Vector3.ONE * ECHELLE
	scene.add_child(mob)
	if ou_m == Vector2.INF:
		var devant := -player.global_basis.z
		devant.y = 0.0
		devant = devant.normalized()
		_garer(player.global_position + devant.cross(Vector3.UP) * COTE + devant * DEVANT, atan2(devant.x, devant.z) + 0.5)
	else:
		_garer(Vector3(ou_m.x / U, 0.0, ou_m.y / U), cap)
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
	Vue.basculee.connect(func(_t): _poser_habitant())


func _process(_delta: float) -> void:
	var t := ""
	if monte:
		t = "V : descendre de la Mobylette"
	elif en_selle == null and player.focus_target == _zone:
		t = "E : enfourcher la Mobylette bleue"
	_prompt.text = t
	_prompt.visible = t != "" and not player.frozen
	# l'interface tactile lit l'invite de la scène (scripts/tactile/tactile.gd) : celle de la Mobylette qui parle
	if t != "":
		scene.set("_prompt", _prompt)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		if player.frozen:
			return
		if monte:
			descendre()
			get_viewport().set_input_as_handled()
		elif en_selle == null and mob.global_position.distance_to(player.global_position) < PORTEE:
			monter()
			get_viewport().set_input_as_handled()


func _on_interact(target: Node) -> void:
	if target == _zone:
		monter()


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
	mob.scale = Vector3.ONE * ECHELLE
	player.speed = _vitesse_pied * ALLURE
	player.set_radius(RAYON)
	_poser_habitant()


## La Mobylette reste là où l'on est, l'habitant met pied à terre à côté.
func descendre() -> void:
	if not monte:
		return
	monte = false
	en_selle = null
	var yaw := player.global_rotation.y
	var ici := player.global_position
	mob.reparent(scene, false)
	mob.scale = Vector3.ONE * ECHELLE
	_garer(ici, yaw + PI)
	(_zone.get_child(0) as CollisionShape3D).disabled = false
	player.speed = _vitesse_pied
	player.set_radius(_rayon_pied)
	player.assis = false
	if player.avatar:
		player.avatar.position = Vector3.ZERO
		player.avatar.pose = 0
	var cote := player.global_basis.x * (0.6 / U)
	if not player.test_move(player.global_transform, cote):
		player.global_position += cote


## Garée au sol de la ville : hauteur() de lyon.gd compte en mètres, la scène en unités.
func _garer(at: Vector3, lacet: float) -> void:
	at.y = scene.hauteur(at.x * U, at.z * U) / U
	mob.global_position = at
	mob.global_rotation = Vector3(0, lacet, 0)


## Assis sur la selle, le bassin au-dessus de la partie brune (critter.gd baisse les hanches de « _seat ») :
## 15 cm plus en arrière qu'à Belley, où le verdict 40 le voyait assis sur le réservoir.
func _poser_habitant() -> void:
	if not monte or player.avatar == null:
		return
	player.assis = true
	player.avatar.pose = 2
	var seat := float(player.avatar.get("_seat")) if player.avatar.get("_seat") != null else 0.09
	var s: float = player.avatar.scale.y
	player.avatar.position = Vector3(0, Biens.selle("mobylette") * ECHELLE - seat * s, 0.35 / U)
