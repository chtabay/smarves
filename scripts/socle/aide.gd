extends Button
## Le (i) : un petit rond « i » à côté d'un titre ou d'un chiffre, qui garde l'explication hors de l'écran
## (chantier « Le (i) et la chasse aux textes », 24 octobre 2026). Un panneau dit ce qui est ; les règles
## et les calculs vont dans le (i) (docs/ACTIVITES.md, brique 9).
##
## Au survol de la souris, il ouvre une bulle, que la sortie du survol referme. Au toucher (ou au clic), il
## l'épingle : on la referme en touchant ailleurs, par Échap, ou en retouchant le (i). Une seule bulle à la
## fois, au-dessus de tout (calque 120), tenue dans l'écran.
##
## Chargé par son chemin (pas de class_name) : les autoloads qui l'emploient ne dépendent pas du cache.
##   const AIDE := preload("res://scripts/socle/aide.gd")
##   AIDE.poser(label, "Le premier monte, les 2 derniers descendent.")  # le (i) juste après le label
##   var i := AIDE.creer("…")  # un (i) seul, à placer soi-même

const ENCRE := Color(0.53, 0.58, 0.66)
const ENCRE_VIVE := Color(0.93, 0.95, 0.98)
const FOND := Color(0.085, 0.1, 0.135, 0.98)
const BORD := Color(1, 1, 1, 0.14)
const LARGEUR := 300
const CALQUE := 120

## L'explication que la bulle montre.
var texte := ""

## La bulle ouverte (un PanelContainer sur son calque), le (i) qui l'a ouverte, et si elle est épinglée.
static var _bulle: PanelContainer
static var _source: Button
static var _epinglee := false


## Un (i) seul.
static func creer(t: String) -> Button:
	var b: Button = load("res://scripts/socle/aide.gd").new()
	b.texte = t
	return b


## Pose un (i) juste après c : à côté de lui s'il est dans une rangée, sinon dans une rangée qui prend sa
## place. Rend le (i).
static func poser(c: Control, t: String) -> Button:
	var i := creer(t)
	var p := c.get_parent()
	if p is HBoxContainer or p is HFlowContainer:
		p.add_child(i)
		p.move_child(i, c.get_index() + 1)
		return i
	var h := HBoxContainer.new()
	h.name = "Avec_aide"
	h.add_theme_constant_override("separation", 5)
	h.size_flags_horizontal = c.size_flags_horizontal
	h.size_flags_vertical = c.size_flags_vertical
	if p != null:
		var idx := c.get_index()
		p.remove_child(c)
		p.add_child(h)
		p.move_child(h, idx)
	h.add_child(c)
	c.size_flags_horizontal = Control.SIZE_FILL
	h.add_child(i)
	return i


## La bulle est-elle ouverte (par n'importe quel (i)) ?
static func ouverte() -> bool:
	return is_instance_valid(_bulle)


## Le texte de la bulle ouverte, ou "".
static func texte_ouvert() -> String:
	return str(_source.texte) if ouverte() and is_instance_valid(_source) else ""


## Referme la bulle, d'où qu'elle vienne.
static func fermer() -> void:
	if is_instance_valid(_bulle):
		_bulle.get_parent().queue_free()
	_bulle = null
	if is_instance_valid(_source):
		_source.set_process_input(false)
		_source.set_process_shortcut_input(false)
	_source = null
	_epinglee = false


func _init() -> void:
	name = "Aide"
	text = "i"
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_HELP
	custom_minimum_size = Vector2(18, 18)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_font_size_override("font_size", 12)
	for k in ["font_color", "font_focus_color"]:
		add_theme_color_override(k, ENCRE)
	for k in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(k, ENCRE_VIVE)
	for k in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(1, 1, 1, 0.1 if k in ["hover", "pressed", "hover_pressed"] else 0.0)
		st.border_color = ENCRE
		st.set_border_width_all(1)
		st.set_corner_radius_all(9)
		st.set_content_margin_all(0)
		add_theme_stylebox_override(k, st)
	pressed.connect(_touche)
	mouse_entered.connect(_survol)
	mouse_exited.connect(_quitte)
	set_process_input(false)
	set_process_shortcut_input(false)


func _exit_tree() -> void:
	if _source == self:
		fermer()


## Toucher ou cliquer : épingle la bulle, ou la referme si elle l'était.
func _touche() -> void:
	if _source == self and _epinglee:
		fermer()
	else:
		_ouvrir(true)


func _survol() -> void:
	if _source != self:
		_ouvrir(false)


func _quitte() -> void:
	if _source == self and not _epinglee:
		fermer()


func _ouvrir(epingler: bool) -> void:
	if _source != self:
		fermer()
		var calque := CanvasLayer.new()
		calque.name = "Bulle_aide"
		calque.layer = CALQUE
		get_tree().root.add_child(calque)
		var p := PanelContainer.new()
		p.name = "Bulle"
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		var st := StyleBoxFlat.new()
		st.bg_color = FOND
		st.border_color = BORD
		st.set_border_width_all(1)
		st.set_corner_radius_all(6)
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.content_margin_top = 8
		st.content_margin_bottom = 9
		st.shadow_color = Color(0, 0, 0, 0.35)
		st.shadow_size = 6
		p.add_theme_stylebox_override("panel", st)
		var l := Label.new()
		l.text = texte
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = minf(LARGEUR, get_viewport_rect().size.x - 48)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", ENCRE_VIVE)
		p.add_child(l)
		calque.add_child(p)
		p.resized.connect(_placer)
		_bulle = p
		_source = self
		set_process_input(true)
		set_process_shortcut_input(true)
		_placer()
	_epinglee = _epinglee or epingler


## Sous le (i), décalée pour tenir dans l'écran ; au-dessus s'il n'y a pas la place en dessous.
func _placer() -> void:
	if not is_instance_valid(_bulle) or _source != self:
		return
	_bulle.reset_size()
	var vue := get_viewport_rect().size
	var r := _rect_ecran()
	var s := _bulle.size
	var x := clampf(r.position.x - 12, 8, maxf(8, vue.x - s.x - 8))
	var y := r.end.y + 4
	if y + s.y > vue.y - 8:
		y = maxf(8, r.position.y - s.y - 4)
	_bulle.position = Vector2(x, y)


## Le rectangle du (i) dans l'écran, quel que soit le calque qui le porte.
func _rect_ecran() -> Rect2:
	return get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size)


## La bulle ouverte : Échap la referme, et ne ferme rien d'autre (_shortcut_input passe avant tous les
## _unhandled_input, celui du carnet compris).
func _shortcut_input(event: InputEvent) -> void:
	if _source == self and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fermer()


## Une pression hors de la bulle et hors du (i) la referme sans s'arrêter là (le geste fait aussi ce qu'il
## devait faire).
func _input(event: InputEvent) -> void:
	if _source != self:
		return
	var pos = null
	if event is InputEventMouseButton and event.pressed:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos == null:
		return
	if is_instance_valid(_bulle) and _bulle.get_global_rect().has_point(pos):
		return
	if _rect_ecran().has_point(pos):
		return
	fermer()
