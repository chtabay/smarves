extends Node
## La bascule vue de dessus / vue à pied, fournie par le jeu à toute commune chargée : Tab, ou le
## bouton « Vue » de l'interface tactile. La scène n'a rien à coder : il lui suffit d'exposer `player`
## (un fp_player.gd) et `camera` (un orbit_camera.gd), ce que le socle demande déjà (Tactile).
## Smarves (main.gd) garde sa propre bascule et marque Tab comme traité avant qu'on arrive ici ;
## une scène qui a sa méthode set_fps() est laissée tranquille de même.

signal basculee(topdown: bool)

## Vue de dessus (la caméra à crans suit l'habitant) ou vue à pied, pour la scène en cours.
var topdown := true
var _scene: Node = null
var _crans: Array = []
var _cran := 0


func _input(event: InputEvent) -> void:
	# Avant l'interface : Tab est aussi la touche qui fait passer le focus d'un bouton à l'autre, et un
	# bouton resté en focus (la carte, la bienvenue, la liste des communes) l'avalerait avant le socle.
	# On laisse seulement les champs de texte, où Tab appartient à la saisie.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		var s := get_tree().current_scene
		if gere(s) and not s.player.frozen and not get_tree().paused:
			if focus != null:
				focus.release_focus()
			basculer(s)
			get_viewport().set_input_as_handled()


## La scène se prête à la bascule : un habitant à la première personne, une caméra à crans, et
## pas de bascule à elle.
func gere(s: Node) -> bool:
	if s == null or s.has_method("set_fps"):
		return false
	var p = s.get("player")
	var c = s.get("camera")
	return p is CharacterBody3D and is_instance_valid(p) and "follow_camera" in p and p.get("camera") is Camera3D \
		and c is Camera3D and is_instance_valid(c) and c.has_method("use_notches")


## Alterne les deux vues de la scène `s` (voir gere()).
func basculer(s: Node) -> void:
	if s != _scene:
		_scene = s
		topdown = true
	var p: CharacterBody3D = s.player
	var c: Camera3D = s.camera
	topdown = not topdown
	if topdown:
		c.make_current()
		p.follow_camera = c
		if p.avatar:
			p.avatar.visible = true
		c.target = p.global_position + Vector3(0, 0.3, 0)
		c.set("_target_goal", c.target)
		c.use_notches(_crans, _cran)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_crans = c.notches.duplicate()
		_cran = c.notch
		c.use_notches([], 0)
		p.follow_camera = null
		if p.avatar:
			p.avatar.visible = false
		p.camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	basculee.emit(topdown)
