extends Node3D
## Socle commun des tables 3D : la place assise (une caméra qui glisse depuis le regard du joueur),
## les plans de coup, le choix des cases du tapis à la souris avec surbrillance, et le lien avec le
## panneau de jeu, qui devient alors une barre basse.

const KIT := preload("res://scripts/jeux/kit.gd")

## Émis quand le joueur clique une case du tapis.
signal cell_clicked(key: String)

var cam: Camera3D
## La place du joueur et le plan rapproché sur l'action, dans le repère de la table.
var seat := Transform3D()
var seat_fov := 50.0
## La table pose sa propre lampe ; le casino, qui a déjà les siennes au-dessus des tables, l'éteint.
var with_lamp := true
var active := false
var felt_y := 0.78
## Cases cliquables : clé -> Rect2 dans le plan du tapis (x, z), repère de la table.
var cells := {}
var panel: Control
var _return_cam: Camera3D
var _cam_tw: Tween
var _hover: MeshInstance3D
var _hover_key := ""
## La file des gestes du croupier : chaque geste attend la fin du précédent.
var _clock := 0.0
var _busy_until := 0.0


## Fabrique un regard (position, cible) dans le repère de la table.
static func look(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(at - from, Vector3.UP), from)


func _ensure_cam() -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.near = 0.02
		cam.far = 120.0
		add_child(cam)


## S'asseoir : la caméra part du regard actuel du joueur et glisse jusqu'à la place.
func sit(from: Camera3D) -> void:
	_ensure_cam()
	_return_cam = from
	cam.global_transform = from.global_transform
	cam.fov = from.fov
	cam.make_current()
	active = true
	shot(seat, 0.9, seat_fov)


func stand() -> void:
	active = false
	_set_hover("")
	if _return_cam == null or not is_instance_valid(_return_cam):
		return
	if _cam_tw:
		_cam_tw.kill()
	_cam_tw = create_tween().set_parallel()
	_cam_tw.tween_property(cam, "global_transform", _return_cam.global_transform, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cam_tw.tween_property(cam, "fov", _return_cam.fov, 0.6)
	var back := _return_cam
	_cam_tw.chain().tween_callback(func(): back.make_current())


## Un mouvement de caméra vers un plan (repère de la table).
func shot(t: Transform3D, dur := 0.9, fov := -1.0) -> void:
	if cam == null or not active:
		return
	if _cam_tw:
		_cam_tw.kill()
	_cam_tw = create_tween().set_parallel()
	_cam_tw.tween_property(cam, "transform", t, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if fov > 0.0:
		_cam_tw.tween_property(cam, "fov", fov, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_clock += delta


## Programme un geste après ceux déjà prévus ; « cost » est sa durée.
func schedule(cost: float, cb: Callable) -> void:
	var start := maxf(_clock, _busy_until)
	_busy_until = start + cost
	if start - _clock < 0.001:
		cb.call()
	else:
		get_tree().create_timer(start - _clock).timeout.connect(cb)


## Le temps qu'il reste avant que tous les gestes prévus soient finis.
func busy_time() -> float:
	return maxf(_busy_until - _clock, 0.0)


## Relie la table au panneau : à surcharger par chaque jeu.
func attach(p: Control) -> void:
	panel = p


# --- Le tapis cliquable -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not active or cells.is_empty() or cam == null:
		return
	if event is InputEventMouseMotion:
		_set_hover(pick(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var k := pick(event.position)
		if k != "":
			cell_clicked.emit(k)
			get_viewport().set_input_as_handled()


## La case du tapis sous le pointeur ("" si aucune).
func pick(screen: Vector2) -> String:
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var inv := global_transform.affine_inverse()
	var lf := inv * from
	var ld := (inv.basis * dir).normalized()
	if absf(ld.y) < 1e-4:
		return ""
	var t := (felt_y - lf.y) / ld.y
	if t <= 0.0:
		return ""
	var hit := lf + ld * t
	var p := Vector2(hit.x, hit.z)
	var best := ""
	var best_area := INF
	for k in cells:
		var r: Rect2 = cells[k]
		if r.has_point(p) and r.get_area() < best_area:
			best = k
			best_area = r.get_area()
	return best


func cell_center(key: String) -> Vector3:
	var r: Rect2 = cells[key]
	var c := r.get_center()
	return Vector3(c.x, felt_y, c.y)


func _set_hover(k: String) -> void:
	if k == _hover_key:
		return
	_hover_key = k
	if _hover == null:
		_hover = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE
		_hover.mesh = pm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1.0, 0.8, 0.4, 0.22)
		_hover.material_override = m
		add_child(_hover)
	_hover.visible = k != ""
	if k != "":
		var r: Rect2 = cells[k]
		_hover.position = Vector3(r.get_center().x, felt_y + 0.001, r.get_center().y)
		_hover.scale = Vector3(r.size.x, 1.0, r.size.y)


## Une case qui s'allume (case gagnante), le temps d'un coup.
func glow_cell(key: String, dur := 3.0) -> void:
	if not cells.has(key):
		return
	var r: Rect2 = cells[key]
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = r.size
	g.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.85, 0.45, 0.0)
	g.material_override = m
	g.position = Vector3(r.get_center().x, felt_y + 0.0015, r.get_center().y)
	add_child(g)
	var tw := g.create_tween()
	for i in 3:
		tw.tween_property(m, "albedo_color:a", 0.45, 0.25)
		tw.tween_property(m, "albedo_color:a", 0.15, 0.35)
	tw.tween_interval(maxf(dur - 1.8, 0.0))
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(g.queue_free)
