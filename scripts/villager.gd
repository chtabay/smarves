extends Node3D
## Un habitant de Smarves : assis en terrasse, debout à regarder, ou en promenade entre deux points.
## Son allure (espèce, pelage, tenue) est tirée du nom qu'on lui donne, pour rester la même d'une partie à l'autre.

const CRITTER := preload("res://scripts/critter.gd")

## Ancien nom de modèle, gardé comme graine d'allure.
var model_path := "habitant"
var pose := "idle"
var accessory := ""
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
