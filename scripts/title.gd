extends Node3D
## L'écran titre : la place de Smarves qui tourne lentement en fond, le nom du jeu, et trois boutons :
## Jouer, Réglages, Quitter. La carte de la Vienne n'y est plus (choix du 24 octobre 2026) : le joueur
## la découvre au premier voyage. À droite, l'encart « Ce soir à Smarves », et en bas la barre des mises
## à jour et du compte : les deux sont à la bienvenue (scripts/bienvenue.gd).

const MAIN := preload("res://scenes/main.tscn")

var village: Node3D


func _ready() -> void:
	village = MAIN.instantiate()
	village.set_meta("vitrine", true)
	add_child(village)
	# La place tourne derrière, mais on n'y est pas encore : le thème de l'écran titre (tools/musiques.py).
	Sfx.musique("titre")
	_build_ui()


func _process(delta: float) -> void:
	if village == null:
		return
	var cam: Camera3D = village.camera
	if cam:
		cam._yaw_goal += delta * 0.06
		cam._dist_goal = 24.0
		cam._pitch_goal = deg_to_rad(-30.0)


func _build_ui() -> void:
	var serif := Polices.texte()
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	# Un voile sombre en bas pour lire le titre.
	var veil := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.02, 0.01, 0.03, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.3)
	gt.fill_to = Vector2(0.5, 1.0)
	veil.texture = gt
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	# Le nom et les boutons à gauche : la droite est à l'encart de la bienvenue, le bas à sa barre.
	var gauche := Control.new()
	gauche.set_anchors_preset(Control.PRESET_FULL_RECT)
	gauche.anchor_right = 0.56
	gauche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gauche)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.position.y -= 70
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	gauche.add_child(v)
	var title := Label.new()
	title.text = "SMARVES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Polices.titre())
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.45, 0.1, 0.45))
	title.add_theme_constant_override("shadow_outline_size", 18)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Le village où l'on joue  ·  Vienne"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", serif)
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.92, 0.86, 0.78))
	v.add_child(sub)
	var tag := Label.new()
	tag.text = "« Le jeu est un investissement. »  — Crédit Smarvois"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_override("font", serif)
	tag.add_theme_font_size_override("font_size", 17)
	tag.add_theme_color_override("font_color", Color(0.7, 0.66, 0.62))
	v.add_child(tag)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for b in [["Jouer", jouer], ["Réglages", func(): Settings.toggle()], ["Quitter", func(): get_tree().quit()]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(150, 52)
		btn.add_theme_font_override("font", serif)
		btn.add_theme_font_size_override("font_size", 24)
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = {"normal": Color(0.12, 0.06, 0.03, 0.9), "hover": Color(0.3, 0.16, 0.05, 0.95), "pressed": Color(0.4, 0.22, 0.08), "focus": Color(0.12, 0.06, 0.03, 0.9)}[st]
			sb.border_color = Color(0.95, 0.7, 0.3)
			sb.set_border_width_all(2 if st == "hover" else 1)
			sb.set_corner_radius_all(4)
			btn.add_theme_stylebox_override(st, sb)
		btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		btn.pressed.connect(b[1])
		row.add_child(btn)
	var credit := Label.new()
	credit.text = Sfx.CREDIT_MUSIQUE
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_override("font", serif)
	credit.add_theme_font_size_override("font_size", 13)
	credit.add_theme_color_override("font_color", Color(0.6, 0.56, 0.52))
	v.add_child(credit)
	_maybe_capture()


func jouer() -> void:
	# Le village du fond devient la partie, sans être rebâti (main.gd, quitter_vitrine).
	var tree := get_tree()
	var v := village
	village = null
	remove_child(v)
	tree.root.add_child(v)
	tree.current_scene = v
	v.quitter_vitrine()
	queue_free()


func _maybe_capture() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--carte":
			Carte.ouvrir.call_deferred(true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await get_tree().create_timer(6.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
			get_tree().quit()
