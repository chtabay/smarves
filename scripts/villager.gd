extends Node3D
## Un habitant de Smarves : assis en terrasse, debout à regarder, ou en promenade entre deux points.
## Son allure (espèce, pelage, tenue) est tirée du nom qu'on lui donne, pour rester la même d'une partie à l'autre.

const CRITTER := preload("res://scripts/critter.gd")

## Ancien nom de modèle, gardé comme graine d'allure.
var model_path := "habitant"
var pose := "idle"
var accessory := ""
## Qui parle : une clé de Lines.SPEAKERS (« habitant » par défaut).
var speaker := "habitant"
## Promenade : liste de points visités en boucle (vide = immobile).
var route: Array[Vector3] = []
var speed := 0.6

var critter: Node3D
var _leg := 0
var _pause := 0.0
var _sulk := 0.0


func _ready() -> void:
	critter = CRITTER.new()
	critter.randomize_look(hash(model_path + str(position.snapped(Vector3.ONE * 0.1))))
	critter.accessory = accessory
	add_child(critter)
	_apply_pose(pose if route.size() < 2 else "walk")
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
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.96, 0.9, 0.94)
		sb.set_corner_radius_all(14)
		sb.set_content_margin_all(10)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
		_bubble.add_theme_stylebox_override("panel", sb)
		_bubble_label = Label.new()
		_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubble_label.custom_minimum_size = Vector2(320, 0)
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Georgia", "serif"])
		_bubble_label.add_theme_font_override("font", f)
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
	critter.cheer(0.4)


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
	_bubble.position = p - Vector2(_bubble.size.x / 2.0, _bubble.size.y + 6.0)


func _apply_pose(p: String) -> void:
	match p:
		"walk": critter.pose = CRITTER.Pose.WALK
		"sit": critter.pose = CRITTER.Pose.SIT
		_: critter.pose = CRITTER.Pose.IDLE


func react(kind: String) -> void:
	if kind == "win":
		critter.cheer()
	elif route.size() < 2 and pose != "sit":
		critter.pose = CRITTER.Pose.SULK
		_sulk = 1.5


func _process(delta: float) -> void:
	_update_bubble(delta)
	if _sulk > 0.0:
		_sulk -= delta
		if _sulk <= 0.0:
			_apply_pose(pose)
	if route.size() < 2:
		return
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
		return
	position += to.normalized() * minf(speed * delta, to.length())
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 8.0 * delta)
