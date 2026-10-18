extends Camera3D
## Caméra qui tourne autour du diorama : clic droit pour tourner, molette pour zoomer.

## On dézoome encore alors que la caméra est arrivée au dernier cran : au-delà, c'est la carte.
signal au_dela

var target := Vector3(0.0, 0.3, 0.0)
var yaw := deg_to_rad(0.0)
var pitch := deg_to_rad(-40.0)
var distance := 26.0
var _target_goal := target
var _home := {}
var _locked := false
var _yaw_goal := yaw
var _pitch_goal := pitch
var _dist_goal := distance
var _dragging := false
## Les crans de la vue extérieure : [distance, tangage en degrés, champ]. Vide : la molette zoome librement.
var notches: Array = []
var notch := 0
var _fov_goal := 34.0


func _ready() -> void:
	fov = 34.0
	var attr := CameraAttributesPractical.new()
	# Flou de profondeur des deux côtés : l'œil lit « maquette miniature ».
	attr.dof_blur_far_enabled = true
	attr.dof_blur_near_enabled = true
	attr.dof_blur_amount = 0.11
	attributes = attr
	# Pour les captures de vérification : -- --view=distance,x,y,z,lacet,tangage
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			var v := arg.trim_prefix("--view=").split_floats(",")
			_dist_goal = v[0]
			distance = v[0]
			target = Vector3(v[1], v[2], v[3] if v.size() > 3 else 0.0)
			_target_goal = target
			if v.size() > 4:
				yaw = deg_to_rad(v[4])
				_yaw_goal = yaw
			if v.size() > 5:
				pitch = deg_to_rad(v[5])
				_pitch_goal = pitch
	_apply()


## Plonge vers un lieu (pour y jouer) ; release() ramène la vue d'ensemble.
func focus(at: Vector3, dist: float, y: float, p: float) -> void:
	if not _locked:
		_home = {"t": _target_goal, "d": _dist_goal, "y": _yaw_goal, "p": _pitch_goal}
	_locked = true
	_target_goal = at
	_dist_goal = dist
	_yaw_goal = y
	_pitch_goal = p


## Déplace le point visé sans verrouiller la caméra : pour voyager d'un socle à l'autre.
func go_to(at: Vector3) -> void:
	if _locked:
		release()
	_target_goal = at


func release() -> void:
	if not _locked:
		return
	_locked = false
	_target_goal = _home.t
	_dist_goal = _home.d
	_yaw_goal = _home.y
	_pitch_goal = _home.p


func _unhandled_input(event: InputEvent) -> void:
	if _locked:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if notches.is_empty():
				_dist_goal = maxf(8.0, _dist_goal - 1.5)
			else:
				set_notch(notch - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if notches.is_empty():
				_dist_goal = minf(45.0, _dist_goal + 1.5)
			else:
				set_notch(notch + 1)
	elif event is InputEventMouseMotion and _dragging:
		turn(event.relative.x, event.relative.y)


## Tourne la vue d'un glissé (clic droit, ou doigt : scripts/tactile/tactile.gd).
func turn(dx: float, dy: float) -> void:
	_yaw_goal -= dx * 0.005
	_pitch_goal = clampf(_pitch_goal - dy * 0.004, deg_to_rad(-75), deg_to_rad(-8))


## Passe la molette en crans (vue extérieure qui suit l'habitant) ; une liste vide rend le zoom libre.
func use_notches(list: Array, start: int) -> void:
	notches = list
	if list.is_empty():
		_fov_goal = 34.0
		return
	set_notch(start)


func set_notch(i: int) -> void:
	if i >= notches.size() and notch == notches.size() - 1 and absf(distance - _dist_goal) < 2.0:
		au_dela.emit()
	notch = clampi(i, 0, notches.size() - 1)
	var n: Array = notches[notch]
	_dist_goal = n[0]
	_pitch_goal = deg_to_rad(n[1])
	_fov_goal = n[2]


func _process(delta: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)
	fov = lerpf(fov, _fov_goal, k)
	yaw = lerpf(yaw, _yaw_goal, k)
	pitch = lerpf(pitch, _pitch_goal, k)
	distance = lerpf(distance, _dist_goal, k)
	target = target.lerp(_target_goal, k)
	_apply()


func _apply() -> void:
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	position = target + dir * distance
	look_at(target)
	var attr := attributes as CameraAttributesPractical
	if attr:
		# Effet miniature : seule une bande autour du point visé reste nette.
		attr.dof_blur_far_distance = distance * 1.1
		attr.dof_blur_far_transition = distance * 0.35
		attr.dof_blur_near_distance = maxf(0.5, distance * 0.82)
		attr.dof_blur_near_transition = distance * 0.25
