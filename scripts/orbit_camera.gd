extends Camera3D
## Caméra qui tourne autour du diorama : clic droit pour tourner, molette pour zoomer.

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
			_dist_goal = maxf(8.0, _dist_goal - 1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_dist_goal = minf(45.0, _dist_goal + 1.5)
	elif event is InputEventMouseMotion and _dragging:
		_yaw_goal -= event.relative.x * 0.005
		_pitch_goal = clampf(_pitch_goal - event.relative.y * 0.004, deg_to_rad(-75), deg_to_rad(-8))


func _process(delta: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)
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
