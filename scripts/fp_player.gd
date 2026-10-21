extends CharacterBody3D
## Le joueur à la première personne (ZQSD ou WASD, souris pour regarder, Maj pour courir),
## E pour s'asseoir à une table, entrer ou parler. Sa taille se règle : un homme au casino,
## un petit Smarvois sur la place.

signal interact(target: Node)

var speed := 3.2
var eye := 1.6
var body_height := 1.7
var radius := 0.3
var reach := 2.6
## La plus haute marche qu'on enjambe sans y penser : un trottoir, un seuil, un raccord de décor.
## Négative, elle suit la taille (un cinquième de la hauteur du corps passé un peu) : 0,37 m pour un
## homme au casino, 0,15 pour un Smarvois. Une estrade, un mur, un rebord restent infranchissables.
var step_height := -1.0

var camera: Camera3D
var frozen := false
var focus_target: Node = null
## Pour les tests automatiques : une direction de marche imposée (repère du joueur).
var auto_move := Vector3.ZERO
## Vue de dessus : la caméra qui suit le joueur. Les déplacements se font alors par rapport à elle,
## le personnage se tourne vers sa marche, et l'on interagit avec ce qui est à portée de main.
var follow_camera: Camera3D = null
var avatar: Node3D = null
var _pitch := 0.0


func _ready() -> void:
	add_to_group("player")
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = body_height
	shape.shape = cap
	shape.position.y = body_height / 2.0
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = eye
	camera.fov = 72.0
	camera.near = 0.02 if eye < 1.0 else 0.05
	floor_snap_length = 0.3 * eye
	floor_max_angle = deg_to_rad(50.0)
	if step_height < 0.0:
		step_height = 0.22 * body_height
	add_child(camera)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	if follow_camera != null:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and focus_target:
			interact.emit(focus_target)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.0025
		_pitch = clampf(_pitch - event.relative.y * 0.0025, deg_to_rad(-70), deg_to_rad(60))
		camera.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if focus_target:
			interact.emit(focus_target)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and focus_target:
		interact.emit(focus_target)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	var dir := Vector3.ZERO
	if not frozen:
		# Touches physiques : ZQSD sur AZERTY et WASD sur QWERTY tombent au même endroit.
		if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.z -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.z += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1
	if auto_move != Vector3.ZERO:
		dir = auto_move
	if follow_camera != null:
		# Vue de dessus : « avancer » s'éloigne de la caméra, le corps se tourne vers la marche.
		var yaw := follow_camera.global_rotation.y
		dir = (Basis(Vector3.UP, yaw) * dir).normalized()
		if dir.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)
		if avatar:
			avatar.pose = 1 if dir.length() > 0.1 else 0
	else:
		dir = (transform.basis * dir).normalized()
	var run := 1.8 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	velocity.x = dir.x * speed * run
	velocity.z = dir.z * speed * run
	_step_up(delta)
	move_and_slide()
	_update_focus()


## Enjamber une petite marche : quand on bute au sol contre un obstacle raide, on essaie la même
## avancée un cran plus haut. Si la place est libre au-dessus et qu'on retombe sur un sol, on y
## monte d'un coup ; sinon c'est un mur, et move_and_slide fait comme avant.
func _step_up(delta: float) -> void:
	if frozen or step_height <= 0.0 or not is_on_floor():
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 0.01:
		return
	var xf := global_transform
	# Assez loin pour que le bas de la capsule passe le nez de la marche et s'y pose.
	var ahead := flat.normalized() * maxf(flat.length() * delta, radius * 0.4)
	var hit := KinematicCollision3D.new()
	if not test_move(xf, ahead, hit) or hit.get_normal().y > cos(floor_max_angle):
		return
	var up := Vector3.UP * step_height
	if test_move(xf, up):
		return
	var high := xf.translated(up)
	if test_move(high, ahead):
		return
	high = high.translated(ahead)
	var land := KinematicCollision3D.new()
	if not test_move(high, -up, land) or land.get_normal().y < cos(floor_max_angle):
		return
	var rise := high.origin.y + land.get_travel().y - xf.origin.y
	if rise < 0.01:
		return
	global_position = high.origin + land.get_travel()
	velocity.y = 0.0


func _update_focus() -> void:
	focus_target = null
	if frozen:
		return
	if follow_camera != null:
		# À portée de main : la zone la plus proche devant soi.
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = reach * 0.6
		q.shape = sph
		q.transform = Transform3D(Basis(), global_position + (-global_basis.z) * reach * 0.4 + Vector3(0, eye * 0.6, 0))
		q.collide_with_areas = true
		q.collide_with_bodies = false
		var best := INF
		for hit in get_world_3d().direct_space_state.intersect_shape(q, 16):
			var c: Object = hit.collider
			if c is Area3D and c.has_meta("interact"):
				var d: float = (c as Node3D).global_position.distance_to(global_position)
				if d < best:
					best = d
					focus_target = c
		return
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * reach
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	q.hit_from_inside = true
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and hit.collider.has_meta("interact"):
		focus_target = hit.collider
