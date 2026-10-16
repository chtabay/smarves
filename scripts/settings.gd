extends CanvasLayer
## Le menu de réglages (autoload « Settings »), ouvert par Échap quand aucun jeu n'est ouvert :
## volume général, ambiance, bruitages, plein écran, et nouvelle partie. Les réglages sont gardés.

const PATH := "user://reglages.cfg"

var _root: Control
var _panel: PanelContainer
var _confirm: Button
var _sliders := {}
var _fullscreen: CheckButton
var _mouse_before := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_load()
	_root.visible = false


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
		_confirm.text = "Nouvelle partie"
		_confirm.set_meta("armed", false)
		_root.visible = true
		get_tree().paused = true


func _build() -> void:
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "serif"])
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
	_fullscreen = CheckButton.new()
	_fullscreen.text = "Plein écran"
	_fullscreen.toggled.connect(_set_fullscreen)
	v.add_child(_fullscreen)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 12)
	v.add_child(row2)
	_confirm = Button.new()
	_confirm.text = "Nouvelle partie"
	_confirm.pressed.connect(_new_game)
	row2.add_child(_confirm)
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


## Deux clics pour recommencer : on ne perd pas sa partie par mégarde.
func _new_game() -> void:
	if not _confirm.get_meta("armed", false):
		_confirm.set_meta("armed", true)
		_confirm.text = "Confirmer : tout effacer ?"
		return
	toggle()
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _save() -> void:
	var cfg := ConfigFile.new()
	for k in _sliders:
		cfg.set_value("son", k, _sliders[k].value)
	cfg.set_value("ecran", "plein_ecran", _fullscreen.button_pressed)
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		for k in _sliders:
			_set_volume(_sliders[k].value, k)
		return
	for k in _sliders:
		_sliders[k].set_value_no_signal(float(cfg.get_value("son", k, 0.8)))
		_set_volume(_sliders[k].value, k)
	var fs: bool = cfg.get_value("ecran", "plein_ecran", false)
	_fullscreen.set_pressed_no_signal(fs)
	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
