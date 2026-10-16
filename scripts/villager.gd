extends Node3D
## Un habitant de Smarves : assis en terrasse, debout à regarder, ou en promenade entre deux points.

var model_path := "res://assets/kenney/characters/character-male-a.glb"
var pose := "idle"
## Promenade : liste de points visités en boucle (vide = immobile).
var route: Array[Vector3] = []
var speed := 0.6

var anim: AnimationPlayer
var _leg := 0
var _pause := 0.0


func _ready() -> void:
	var model: Node3D = load(model_path).instantiate()
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	for a in ["idle", "walk", "sit"]:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	anim.play("walk" if route.size() > 1 else pose)
	# Décale les animations pour que les habitants ne bougent pas tous en même temps.
	anim.seek(randf() * anim.current_animation_length, true)


func react(kind: String) -> void:
	if route.size() > 1 or not anim:
		return
	var a := "emote-yes" if kind == "win" else "emote-no"
	if anim.has_animation(a):
		anim.play(a, 0.2)
		anim.queue(pose)


func _process(delta: float) -> void:
	if route.size() < 2:
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			anim.play("walk", 0.2)
		return
	var target := route[_leg]
	var to := target - position
	to.y = 0
	if to.length() < 0.05:
		_leg = (_leg + 1) % route.size()
		_pause = randf_range(1.0, 4.0)
		anim.play("idle", 0.2)
		return
	position += to.normalized() * minf(speed * delta, to.length())
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 8.0 * delta)
