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

var camera: Camera3D
var frozen := false
var focus_target: Node = null
## Pour les tests automatiques : une direction de marche imposée (repère du joueur).
var auto_move := Vector3.ZERO
var _pitch := 0.0


func _ready() -> void:
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
	add_child(camera)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
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
	dir = (transform.basis * dir).normalized()
	var run := 1.8 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	velocity.x = dir.x * speed * run
	velocity.z = dir.z * speed * run
	move_and_slide()
	_update_focus()


func _update_focus() -> void:
	focus_target = null
	if frozen:
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
