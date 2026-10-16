extends Camera3D
## Caméra qui tourne autour du diorama : clic droit pour tourner, molette pour zoomer.

var target := Vector3(1.5, 3.4, -0.8)
var yaw := deg_to_rad(-8.0)
var pitch := deg_to_rad(-16.0)
var distance := 34.0
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
	attr.dof_blur_amount = 0.08
	attributes = attr
	# Pour les captures de vérification : -- --view=distance,x,y
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			var v := arg.trim_prefix("--view=").split_floats(",")
			_dist_goal = v[0]
			distance = v[0]
			target = Vector3(v[1], v[2], -0.8)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_dist_goal = maxf(12.0, _dist_goal - 1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_dist_goal = minf(45.0, _dist_goal + 1.5)
	elif event is InputEventMouseMotion and _dragging:
		_yaw_goal -= event.relative.x * 0.005
		_pitch_goal = clampf(_pitch_goal - event.relative.y * 0.004, deg_to_rad(-60), deg_to_rad(-3))
		_yaw_goal = clampf(_yaw_goal, deg_to_rad(-70), deg_to_rad(70))


func _process(delta: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)
	yaw = lerpf(yaw, _yaw_goal, k)
	pitch = lerpf(pitch, _pitch_goal, k)
	distance = lerpf(distance, _dist_goal, k)
	_apply()


func _apply() -> void:
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	position = target + dir * distance
	look_at(target)
	var attr := attributes as CameraAttributesPractical
	if attr:
		attr.dof_blur_far_distance = distance + 6.0
		attr.dof_blur_far_transition = 10.0
		attr.dof_blur_near_distance = maxf(1.0, distance - 9.0)
		attr.dof_blur_near_transition = 5.0
