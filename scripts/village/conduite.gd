extends Node
## Rouler dans le village avec son véhicule (vélo, Mobylette, moto, voiture), achetés chez Roger Fradin.
## On touche (E) le véhicule garé pour monter dessus ou dedans ; V fait monter ou descendre. Au guidon,
## l'habitant reste assis sur la selle ; au volant, il disparaît dans la voiture. On va plus vite à
## mesure que le véhicule est beau (Biens.vitesse). Une porte qu'on prend en roulant fait garer le
## véhicule devant elle, où on le retrouve en sortant, le temps de la partie (Village.garee).
## Test : godot --headless --path . -s tools/test_conduite.gd

const VILLAGE := preload("res://scripts/village/village.gd")
## La largeur du corps au volant ou au guidon (le piéton fait 0,14).
const RAYON_VOITURE := 0.3
const RAYON_DEUX_ROUES := 0.18

## La scène de la place (scripts/main.gd), son village et l'habitant qu'on dirige.
var main: Node
var village: Node
var player: CharacterBody3D
## Le véhicule qu'on conduit (« » : on est à pied).
var monte := ""
var _vitesse_pied := 0.0
var _rayon_pied := 0.0


func _init(scene: Node, v: Node, p: CharacterBody3D) -> void:
	main = scene
	village = v
	player = p
	name = "Conduite"
	_vitesse_pied = p.speed
	_rayon_pied = p.radius
	village.monter_vehicule.connect(monter)
	Biens.changed.connect(_on_biens_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		if player.frozen or not main.fps:
			return
		if monte != "":
			descendre()
		elif _assez_pres():
			monter()
		get_viewport().set_input_as_handled()


## Le véhicule garé est à portée de main.
func _assez_pres() -> bool:
	var v: Node3D = village._vehicle
	return v != null and v.get_parent() == village and v.global_position.distance_to(player.global_position) < 1.6


## Ce que dit l'invite tant qu'on roule, et le bouton du téléphone (scripts/tactile/tactile.gd).
func invite() -> String:
	if monte == "":
		return ""
	var nom: String = village._bas(Biens.name_of(monte))
	return "V : descendre " + ("du " + nom.substr(3) if nom.begins_with("le ") else "de " + nom)


func monter() -> void:
	var v: Node3D = village._vehicle
	if monte != "" or v == null or player.frozen:
		return
	monte = village._vehicle_id
	(v.get_node("Monter/CollisionShape3D") as CollisionShape3D).disabled = true
	v.reparent(player, false)
	# Le véhicule regarde +Z, l'habitant avance vers -Z.
	v.position = Vector3.ZERO
	v.rotation = Vector3(0, PI, 0)
	v.scale = Vector3.ONE * 1.9
	player.speed = _vitesse_pied * Biens.vitesse(monte)
	player.set_radius(RAYON_DEUX_ROUES if Biens.deux_roues(monte) else RAYON_VOITURE)
	appliquer()
	Sfx.play("tick")
	main._announce(("En selle sur %s." if Biens.deux_roues(monte) else "Au volant de %s.") % village._bas(Biens.name_of(monte)), 2.0)


## Pose le véhicule là où l'on est, un peu de côté, et l'habitant reprend sa marche.
func descendre() -> void:
	if monte == "":
		return
	var v: Node3D = village._vehicle
	var yaw := player.global_rotation.y
	var ou := player.global_position
	ou.y = village.PARKING[0].y
	if v != null and is_instance_valid(v):
		v.reparent(village, false)
		v.global_position = ou
		v.global_rotation = Vector3(0, yaw + PI, 0)
		v.scale = Vector3.ONE * 1.9
		(v.get_node("Monter/CollisionShape3D") as CollisionShape3D).disabled = false
		VILLAGE.garee = [monte, v.position, v.rotation_degrees.y]
	var cote := player.global_basis.x * (0.35 if Biens.deux_roues(monte) else 0.55)
	_a_pied()
	# On met pied à terre à côté, pas dans la carrosserie.
	if not player.test_move(player.global_transform, cote):
		player.global_position += cote


## L'habitant reprend sa marche et sa taille de piéton.
func _a_pied() -> void:
	monte = ""
	player.speed = _vitesse_pied
	player.set_radius(_rayon_pied)
	player.assis = false
	if player.avatar:
		player.avatar.position = Vector3.ZERO
		player.avatar.pose = 0
		player.avatar.visible = main.topdown


## Le véhicule a changé sous nous (revendu, repris par M. Brunet, un autre au volant) : le village en
## gare un autre sur la place, on repart à pied.
func _on_biens_changed() -> void:
	if monte != "" and Biens.driven != monte:
		_a_pied()


## Remet l'habitant à sa place sur le véhicule (après un changement de vue, scripts/main.gd set_fps).
func appliquer() -> void:
	if player.avatar == null:
		return
	if monte == "":
		return
	var v: Node3D = village._vehicle
	if Biens.deux_roues(monte):
		player.assis = true
		player.avatar.pose = 2
		# Assis, les hanches descendent à la hauteur d'une chaise (critter.gd) : on les pose sur la selle,
		# un peu en arrière du milieu.
		var seat := float(player.avatar.get("_seat")) if player.avatar.get("_seat") != null else 0.09
		player.avatar.position = Vector3(0, Biens.selle(monte) * 1.9 - seat * 0.55, 0.06)
	else:
		# Au volant : l'habitant est dans la voiture, on ne voit qu'elle (et la vue à pied, depuis la place du conducteur).
		player.assis = false
		player.avatar.visible = false
	if v:
		# À pied (vue à la première personne), la carrosserie d'une voiture boucherait la vue.
		v.visible = main.topdown or Biens.deux_roues(monte)


## Une porte, un comptoir, un lieu qu'on prend en roulant : on se gare devant d'abord.
func avant_d_agir(target: Node) -> void:
	if monte != "" and (target.has_meta("action") or target.has_meta("place")):
		descendre()
