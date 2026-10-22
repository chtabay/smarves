extends CanvasLayer
## Le menu de réglages (autoload « Settings »), ouvert par Échap quand aucun jeu n'est ouvert :
## volume général, ambiance, bruitages, plein écran, et le chemin vers le compte Pyramides. Pas de « Nouvelle partie » ici : le joueur tient à sa
## partie, qui le suit sur son compte ; l'effacer se fait tout au fond de la bienvenue (scripts/bienvenue.gd).

const PATH := "user://reglages.cfg"

var _root: Control
var _panel: PanelContainer
var _sliders := {}
var _fullscreen: CheckButton
var _device: OptionButton
var _joueurs: CheckButton
## Voir les autres joueurs connectés dans les lieux (autoload Presences) ; sans compte, rien ne s'ouvre.
var voir_joueurs := true
## La qualité de l'image : « haute » (tous les effets, comme avant le 22 octobre 2026), « equilibree »
## (mêmes effets à moindre coût) ou « legere » (sans éclairage indirect, brouillard ni reflets, rendu 3D
## réduit). Appliquée à chaque environnement qui entre dans l'arbre (_sur_noeud), sans toucher aux lieux.
var qualite := "equilibree"
const QUALITES := [["haute", "Haute"], ["equilibree", "Équilibrée"], ["legere", "Légère"]]
## Images par seconde au plus, et quand la fenêtre n'a pas le focus : au-delà, la carte graphique tourne
## pour rien (le jeu montait à la fréquence de l'écran, 144 ou 165 images/s sur les écrans rapides).
const CADENCE := {"haute": 60, "equilibree": 60, "legere": 30}
const CADENCE_ARRIERE_PLAN := 10
var _qualite: OptionButton
var _mouse_before := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Téléphone et navigateur : la qualité légère d'office (le rendu Mobile ou Compatibility n'a de toute
	# façon ni éclairage indirect ni brouillard volumétrique).
	if OS.has_feature("mobile") or OS.has_feature("web"):
		qualite = "legere"
	_build()
	_load()
	_root.visible = false
	get_tree().node_added.connect(_sur_noeud)
	appliquer_qualite()


func _notification(what: int) -> void:
	# Fenêtre en arrière-plan ou réduite : dix images par seconde suffisent (la musique a un quart de
	# seconde d'avance, le réseau et les minuteries suivent).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not OS.has_feature("mobile"):
		Engine.max_fps = CADENCE_ARRIERE_PLAN
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Engine.max_fps = CADENCE.get(qualite, 60)


## Les réglages du moteur qui valent pour tout le jeu : cadence, filtres des ombres, finesse de
## l'éclairage indirect, du brouillard et de l'occlusion, résolution du rendu 3D.
func appliquer_qualite() -> void:
	Engine.max_fps = CADENCE.get(qualite, 60)
	var rs := RenderingServer
	var haute := qualite == "haute"
	var legere := qualite == "legere"
	# En qualité haute, les valeurs du projet (celles du jeu jusqu'ici) ; sinon, un cran ou deux plus bas.
	var ombre_soleil: int = _reglage("lights_and_shadows/directional_shadow/soft_shadow_filter_quality")
	var ombre_lampes: int = _reglage("lights_and_shadows/positional_shadow/soft_shadow_filter_quality")
	rs.directional_soft_shadow_filter_set_quality(ombre_soleil if haute else (rs.SHADOW_QUALITY_SOFT_VERY_LOW if legere else rs.SHADOW_QUALITY_SOFT_LOW))
	rs.positional_soft_shadow_filter_set_quality(ombre_lampes if haute else (rs.SHADOW_QUALITY_HARD if legere else rs.SHADOW_QUALITY_SOFT_VERY_LOW))
	rs.gi_set_use_half_resolution(_reglage("global_illumination/gi/use_half_resolution") if haute else true)
	# Rayons et convergence restent ceux du projet : converger en moins d'images, c'est lancer plus de
	# rayons à chaque image (mesuré : l'image du casino passait de 1,2 à 2,2 s en rendu logiciel).
	rs.environment_set_sdfgi_frames_to_update_light(_reglage("global_illumination/sdfgi/frames_to_update_lights") if haute else rs.ENV_SDFGI_UPDATE_LIGHT_IN_8_FRAMES)
	rs.environment_set_volumetric_fog_volume_size(_reglage("environment/volumetric_fog/volume_size") if haute else 48, _reglage("environment/volumetric_fog/volume_depth") if haute else 32)
	rs.environment_set_volumetric_fog_filter_active(_reglage("environment/volumetric_fog/use_filter") if haute else false)
	for genre in ["ssao", "ssil"]:
		var q: int = _reglage("environment/%s/quality" % genre) if haute else 1
		var demi: bool = _reglage("environment/%s/half_size" % genre) if haute else true
		var args := [q, demi, _reglage("environment/%s/adaptive_target" % genre), _reglage("environment/%s/blur_passes" % genre),
			_reglage("environment/%s/fadeout_from" % genre), _reglage("environment/%s/fadeout_to" % genre)]
		if genre == "ssao":
			rs.callv("environment_set_ssao_quality", args)
		else:
			rs.callv("environment_set_ssil_quality", args)
	rs.environment_set_ssr_roughness_quality(_reglage("environment/screen_space_reflection/roughness_quality", rs.ENV_SSR_ROUGHNESS_QUALITY_LOW) if haute else rs.ENV_SSR_ROUGHNESS_QUALITY_DISABLED)
	var vp := get_viewport()
	# FSR (plus net que l'étirement simple) n'existe pas dans le rendu Compatibility du navigateur.
	var fsr := RenderingServer.get_current_rendering_method() != "gl_compatibility"
	vp.scaling_3d_mode = (Viewport.SCALING_3D_MODE_FSR if fsr else Viewport.SCALING_3D_MODE_BILINEAR) if legere else _reglage("scaling_3d/mode")
	vp.scaling_3d_scale = 0.75 if legere else _reglage("scaling_3d/scale")
	vp.msaa_3d = Viewport.MSAA_DISABLED if legere else _reglage("anti_aliasing/quality/msaa_3d")
	for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_regler_environnement(we)


func _reglage(nom: String, defaut: Variant = null) -> Variant:
	var v = ProjectSettings.get_setting("rendering/" + nom)
	return defaut if v == null else v


func _sur_noeud(n: Node) -> void:
	if n is WorldEnvironment:
		_regler_environnement.call_deferred(n)


## Chaque lieu règle son environnement pour la qualité haute ; on garde ses choix de côté (méta
## « qualite_haute ») pour les rendre si le joueur revient à la qualité haute.
func _regler_environnement(we: WorldEnvironment) -> void:
	if not is_instance_valid(we) or we.environment == null:
		return
	var env := we.environment
	if not env.has_meta("qualite_haute"):
		env.set_meta("qualite_haute", {"sdfgi": env.sdfgi_enabled, "ssil": env.ssil_enabled,
			"brouillard": env.volumetric_fog_enabled, "ssr": env.ssr_enabled, "ssr_pas": env.ssr_max_steps})
	var h: Dictionary = env.get_meta("qualite_haute")
	var legere := qualite == "legere"
	env.sdfgi_enabled = h.sdfgi and not legere
	env.ssil_enabled = h.ssil and not legere
	env.volumetric_fog_enabled = h.brouillard and not legere
	env.ssr_enabled = h.ssr and not legere
	env.ssr_max_steps = h.ssr_pas if qualite == "haute" else mini(h.ssr_pas, 24)


func _set_qualite(q: String) -> void:
	qualite = q
	appliquer_qualite()
	_save()


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _root.visible:
		_root.visible = false
		Input.mouse_mode = _mouse_before
		get_tree().paused = false
	else:
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_root.visible = true
		get_tree().paused = true


func _build() -> void:
	var serif := Polices.texte()
	var theme := Theme.new()
	theme.default_font = serif
	theme.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.05, 0.035, 0.04, 0.95)
	panel.border_color = Color(0.85, 0.65, 0.3, 0.8)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(26)
	theme.set_stylebox("panel", "PanelContainer", panel)
	for st in ["normal", "hover", "pressed", "focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color(0.14, 0.08, 0.04), "hover": Color(0.28, 0.15, 0.06), "pressed": Color(0.38, 0.22, 0.08), "focus": Color(0.14, 0.08, 0.04)}[st]
		b.border_color = Color(0.85, 0.62, 0.3, 0.8)
		b.set_border_width_all(1)
		b.set_corner_radius_all(3)
		b.set_content_margin_all(10)
		theme.set_stylebox(st, "Button", b)
	theme.set_color("font_color", "Button", Color(0.96, 0.8, 0.45))
	theme.set_color("font_color", "Label", Color(0.9, 0.86, 0.8))
	theme.set_color("font_color", "CheckButton", Color(0.9, 0.86, 0.8))

	_root = Control.new()
	_root.theme = theme
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)
	var t := Label.new()
	t.text = "Réglages"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color(0.96, 0.8, 0.45))
	v.add_child(t)
	for bus in [["Master", "Volume général"], ["Ambiance", "Ambiance et musique"], ["Bruitages", "Bruitages et fanfares"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)
		var l := Label.new()
		l.text = bus[1]
		l.custom_minimum_size = Vector2(220, 0)
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01
		s.value = 0.8
		s.custom_minimum_size = Vector2(220, 24)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.value_changed.connect(_set_volume.bind(bus[0]))
		row.add_child(s)
		_sliders[bus[0]] = s
	# La sortie son : sur ce PC, « Default » peut tomber sur un périphérique muet (haut-parleurs Steam, écran).
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 12)
	v.add_child(drow)
	var dl := Label.new()
	dl.text = "Sortie son"
	dl.custom_minimum_size = Vector2(220, 0)
	drow.add_child(dl)
	_device = OptionButton.new()
	_device.custom_minimum_size = Vector2(220, 0)
	_device.clip_text = true
	for d in AudioServer.get_output_device_list():
		_device.add_item(d)
	_device.item_selected.connect(func(i: int):
		AudioServer.output_device = _device.get_item_text(i)
		Sfx.play("win", 0.0)
		_save())
	drow.add_child(_device)
	var test := Button.new()
	test.text = "Tester le son"
	test.pressed.connect(func(): Sfx.play("big_win", 0.0))
	v.add_child(test)
	# Le compte Pyramides vit dans la fenêtre de bienvenue, qui ne s'ouvre seule qu'à l'arrivée sur la place.
	var compte := Button.new()
	compte.text = "Votre compte Pyramides"
	compte.pressed.connect(func():
		toggle()
		Bienvenue.ouvrir())
	v.add_child(compte)
	_joueurs = CheckButton.new()
	_joueurs.text = "Voir les autres joueurs (avec un compte)"
	_joueurs.button_pressed = true
	_joueurs.toggled.connect(func(on: bool):
		voir_joueurs = on
		_save())
	v.add_child(_joueurs)
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 12)
	v.add_child(qrow)
	var ql := Label.new()
	ql.text = "Qualité de l'image"
	ql.custom_minimum_size = Vector2(220, 0)
	qrow.add_child(ql)
	_qualite = OptionButton.new()
	_qualite.custom_minimum_size = Vector2(220, 0)
	for q in QUALITES:
		_qualite.add_item(q[1])
	_qualite.item_selected.connect(func(i: int): _set_qualite(QUALITES[i][0]))
	qrow.add_child(_qualite)
	_fullscreen = CheckButton.new()
	_fullscreen.text = "Plein écran"
	_fullscreen.toggled.connect(_set_fullscreen)
	v.add_child(_fullscreen)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 12)
	v.add_child(row2)
	var resume := Button.new()
	resume.text = "Reprendre (Échap)"
	resume.pressed.connect(toggle)
	row2.add_child(resume)
	var quit := Button.new()
	quit.text = "Quitter le jeu"
	quit.pressed.connect(func(): get_tree().quit())
	row2.add_child(quit)


func _set_volume(value: float, bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(idx, value <= 0.001)
	_save()


func _set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	for k in _sliders:
		cfg.set_value("son", k, _sliders[k].value)
	cfg.set_value("ecran", "plein_ecran", _fullscreen.button_pressed)
	cfg.set_value("son", "sortie", AudioServer.output_device)
	cfg.set_value("multi", "voir_joueurs", voir_joueurs)
	cfg.set_value("ecran", "qualite", qualite)
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	_montrer_qualite()
	if cfg.load(PATH) != OK:
		for k in _sliders:
			_set_volume(_sliders[k].value, k)
		return
	var q: String = cfg.get_value("ecran", "qualite", qualite)
	for e in QUALITES:
		if e[0] == q:
			qualite = q
	_montrer_qualite()
	for k in _sliders:
		_sliders[k].set_value_no_signal(float(cfg.get_value("son", k, 0.8)))
		_set_volume(_sliders[k].value, k)
	var dev: String = cfg.get_value("son", "sortie", "Default")
	if dev in AudioServer.get_output_device_list():
		AudioServer.output_device = dev
		for i in _device.item_count:
			if _device.get_item_text(i) == dev:
				_device.select(i)
	voir_joueurs = bool(cfg.get_value("multi", "voir_joueurs", true))
	_joueurs.set_pressed_no_signal(voir_joueurs)
	var fs: bool = cfg.get_value("ecran", "plein_ecran", false)
	_fullscreen.set_pressed_no_signal(fs)
	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _montrer_qualite() -> void:
	for i in QUALITES.size():
		if QUALITES[i][0] == qualite:
			_qualite.select(i)
