extends CanvasLayer
## La minimap des communes greffées, en haut à droite (demande de Guillaume du 30 octobre 2026 : « est-ce
## qu'un minimap est possible ? »). Un rond cerclé de laiton, le nord en haut, qui montre le quartier autour
## de l'habitant : sa flèche au centre, tournée où il regarde, et un point d'or pour chaque endroit où l'on
## appuie sur E (les portes, les tables, le panneau de la mairie). Un clic ouvre la grande carte.
##
## Le plan est une seule photo, prise à l'arrivée dans la scène principale de la commune : une caméra
## orthographique au-dessus des toits, rendue une fois dans une SubViewport, puis libérée. Ensuite seule la
## fenêtre glisse sur la photo et les points bougent : la minimap ne coûte presque rien, même sur
## téléphone et sur le web (filmer en continu redessinerait la ville une seconde fois à chaque image).
## La scène n'a rien à coder : le socle trouve l'habitant par le groupe « player » (scripts/fp_player.gd)
## et les endroits par la méta « interact » de leurs Area3D. Sans rendu (un test, --headless), le rond
## garde son fond de nuit et ses points.

const TEINTES := preload("res://scripts/socle/teintes.gd")

const DIAMETRE := 176.0
const MARGE := 20.0
## Le côté de la fenêtre autour de l'habitant, en mètres.
const ETENDUE := 180.0
## La photo couvre la ville autour du point d'arrivée, à cette distance au plus (en mètres).
const RAYON_MAX := 700.0
const COTE_MIN := 240.0
const PIXELS := 1024

const MASQUE := """
shader_type canvas_item;
uniform sampler2D plan : filter_linear, repeat_disable;
uniform bool a_plan = false;
uniform vec2 centre = vec2(0.5);
uniform float etendue = 0.2;
uniform vec4 fond : source_color = vec4(0.055, 0.05, 0.06, 1.0);
void fragment() {
	vec2 d = UV - 0.5;
	if (length(d) > 0.5) {
		discard;
	}
	vec2 uv = centre + d * etendue;
	vec3 c = fond.rgb;
	if (a_plan && uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		c = texture(plan, uv).rgb;
	}
	// Le bord s'assombrit vers le cadre, comme la plaque du coin.
	float v = smoothstep(0.5, 0.34, length(d));
	COLOR = vec4(mix(fond.rgb, c, 0.3 + 0.7 * v), 0.94);
}
"""

## Le centre de la photo (x, z du monde) et son côté en mètres ; la photo elle-même, null sans rendu.
var centre := Vector2.ZERO
var cote := 0.0
var plan: Texture2D

var _scene: Node3D
var _joueur: Node3D
var _endroits: Array[Node3D] = []
var _rond: Control
var _carte_plan: ColorRect
var _dessus: Control
var _voulue := false


func _init() -> void:
	# Sous le carnet, la carte, les réglages et le panneau (40 et plus), qui la couvrent quand ils s'ouvrent.
	layer = 30
	name = "Minimap"
	visible = false
	_rond = Control.new()
	_rond.name = "Rond"
	_rond.custom_minimum_size = Vector2(DIAMETRE, DIAMETRE)
	_rond.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_rond.offset_left = -MARGE - DIAMETRE
	_rond.offset_right = -MARGE
	_rond.offset_top = MARGE
	_rond.offset_bottom = MARGE + DIAMETRE
	_rond.tooltip_text = "La carte  (M)"
	_rond.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_rond.gui_input.connect(_clic)
	add_child(_rond)
	_carte_plan = ColorRect.new()
	_carte_plan.set_anchors_preset(Control.PRESET_FULL_RECT)
	_carte_plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = MASQUE
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("fond", TEINTES.NUIT)
	_carte_plan.material = m
	_rond.add_child(_carte_plan)
	_dessus = Control.new()
	_dessus.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dessus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dessus.draw.connect(_dessiner)
	_rond.add_child(_dessus)


func _ready() -> void:
	get_tree().scene_changed.connect(_sur_scene)


## Dans une commune (Communes la pose avec le coin) ou non.
func poser(dans_une_commune: bool) -> void:
	_voulue = dans_une_commune
	if not dans_une_commune:
		lacher()
	else:
		_sur_scene()


func lacher() -> void:
	_scene = null
	_joueur = null
	_endroits.clear()
	plan = null
	visible = false


## À chaque scène : la minimap ne suit que la scène principale d'une commune greffée (pas ses intérieurs
## ni ses stades, qui n'ont pas de plan à eux), comme le panneau de la mairie (Tableau).
func _sur_scene() -> void:
	var tree := get_tree()
	await tree.process_frame
	await tree.process_frame
	lacher()
	if not _voulue:
		return
	var s := tree.current_scene
	if s == null or not is_instance_valid(s) or not (s is Node3D):
		return
	# Les autoloads par leur nœud : ce script est chargé par Communes elle-même, avant qu'ils aient un nom.
	var communes = tree.root.get_node("Communes")
	var c: Commune = communes.commune(communes.actuelle())
	if c == null or c.id == communes.ORIGINE or str(c.data.get("scene", "")) != s.scene_file_path:
		return
	# La ville se bâtit en plusieurs images derrière l'écran de chargement : la photo attend qu'elle soit finie.
	var chargement = tree.root.get_node_or_null("Chargement")
	while chargement != null and chargement.actif():
		await tree.process_frame
	if not is_instance_valid(s) or tree.current_scene != s or not _voulue:
		return
	for p in tree.get_nodes_in_group("player"):
		if p is CharacterBody3D and s.is_ancestor_of(p):
			await suivre(s as Node3D, p as Node3D)
			return


## Suit l'habitant j dans la scène s : prend la photo autour de lui, relève les endroits, et s'affiche.
func suivre(s: Node3D, j: Node3D) -> void:
	_scene = s
	_joueur = j
	_cadrer(s, j)
	_endroits.clear()
	for a in s.find_children("*", "Area3D", true, false):
		if str(a.get_meta("interact", "")) != "":
			_endroits.append(a as Node3D)
	var m := _carte_plan.material as ShaderMaterial
	m.set_shader_parameter("etendue", ETENDUE / cote)
	m.set_shader_parameter("a_plan", false)
	visible = true
	await _photographier(s)
	if _scene != s:
		return
	m.set_shader_parameter("a_plan", plan != null)
	if plan != null:
		m.set_shader_parameter("plan", plan)


## Le carré de la photo : ce que la ville bâtit autour de l'habitant (ses maillages), au plus à RAYON_MAX.
func _cadrer(s: Node3D, j: Node3D) -> void:
	var ici := Vector2(j.global_position.x, j.global_position.z)
	var boite := Rect2(ici, Vector2.ZERO)
	for v in s.find_children("*", "GeometryInstance3D", true, false):
		var g := v as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var b: AABB = g.global_transform * g.get_aabb()
		var r := Rect2(b.position.x, b.position.z, b.size.x, b.size.z)
		boite = boite.merge(r)
	var limite := Rect2(ici - Vector2.ONE * RAYON_MAX, Vector2.ONE * RAYON_MAX * 2.0)
	boite = boite.intersection(limite)
	cote = maxf(COTE_MIN, maxf(boite.size.x, boite.size.y))
	centre = boite.get_center()


## La photo de dessus, rendue une fois puis gardée en image ; null si le jeu tourne sans rendu.
func _photographier(s: Node3D) -> void:
	plan = null
	if DisplayServer.get_name() == "headless":
		return
	var hauts := _hauteurs(s)
	var vue := SubViewport.new()
	vue.size = Vector2i(PIXELS, PIXELS)
	vue.render_target_update_mode = SubViewport.UPDATE_ONCE
	vue.transparent_bg = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = cote
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3(centre.x, hauts.y + 40.0, centre.y)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.near = 1.0
	cam.far = hauts.y - hauts.x + 120.0
	# Une lumière égale, sans brouillard ni ciel : un plan, pas une vue de l'heure qu'il est.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = TEINTES.NUIT
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.82, 0.78)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	cam.environment = env
	cam.current = true
	vue.add_child(cam)
	add_child(vue)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vue.get_texture().get_image() if is_instance_valid(vue) else null
	if is_instance_valid(vue):
		vue.queue_free()
	if img != null and not img.is_empty() and _scene == s:
		plan = ImageTexture.create_from_image(img)


## Le plus bas et le plus haut de ce que la scène bâtit dans le carré de la photo (x : bas, y : haut).
func _hauteurs(s: Node3D) -> Vector2:
	var bas := INF
	var haut := -INF
	var carre := Rect2(centre - Vector2.ONE * cote / 2.0, Vector2.ONE * cote)
	for v in s.find_children("*", "GeometryInstance3D", true, false):
		var g := v as GeometryInstance3D
		var b: AABB = g.global_transform * g.get_aabb()
		if not carre.intersects(Rect2(b.position.x, b.position.z, b.size.x, b.size.z)):
			continue
		bas = minf(bas, b.position.y)
		haut = maxf(haut, b.end.y)
	if bas == INF:
		return Vector2(-10, 60)
	return Vector2(maxf(bas, -50.0), minf(haut, 400.0))


## La place d'un point du monde dans le rond (en pixels du rond), autour de l'habitant.
func vers_rond(p: Vector3) -> Vector2:
	var d := Vector2(p.x - _joueur.global_position.x, p.z - _joueur.global_position.z)
	return Vector2(DIAMETRE, DIAMETRE) / 2.0 + d / ETENDUE * DIAMETRE


func _process(_delta: float) -> void:
	if not visible:
		return
	if _joueur == null or not is_instance_valid(_joueur) or not _joueur.is_inside_tree():
		lacher()
		return
	var p := _joueur.global_position
	var uv := Vector2((p.x - centre.x) / cote + 0.5, (p.z - centre.y) / cote + 0.5)
	(_carte_plan.material as ShaderMaterial).set_shader_parameter("centre", uv)
	_dessus.queue_redraw()


func _dessiner() -> void:
	if _joueur == null or not is_instance_valid(_joueur):
		return
	var o := Vector2(DIAMETRE, DIAMETRE) / 2.0
	var r := DIAMETRE / 2.0
	for e in _endroits:
		if not is_instance_valid(e) or not e.is_inside_tree():
			continue
		var q := vers_rond(e.global_position)
		if q.distance_to(o) > r - 7.0:
			continue
		_dessus.draw_circle(q, 4.5, Color(TEINTES.NUIT, 0.85))
		_dessus.draw_circle(q, 3.0, TEINTES.OR)
	# L'habitant : une flèche tournée où il regarde.
	var devant := -_joueur.global_basis.z
	var cap := Vector2(devant.x, devant.z)
	cap = cap.normalized() if cap.length() > 0.01 else Vector2.UP
	var cote_f := Vector2(-cap.y, cap.x)
	var fleche := PackedVector2Array([o + cap * 9.0, o - cap * 6.0 + cote_f * 6.5, o - cap * 3.0, o - cap * 6.0 - cote_f * 6.5])
	var ombre := PackedVector2Array()
	for k in fleche:
		ombre.append(o + (k - o) * 1.35)
	_dessus.draw_colored_polygon(ombre, Color(TEINTES.NUIT, 0.8))
	_dessus.draw_colored_polygon(fleche, TEINTES.TEXTE)
	# Le cadre laiton et le nord.
	_dessus.draw_arc(o, r - 1.0, 0.0, TAU, 96, Color(TEINTES.LAITON, 0.75), 2.0, true)
	var n := o + Vector2(0, -r + 13.0)
	_dessus.draw_circle(n, 8.0, Color(TEINTES.NUIT, 0.9))
	var police := Polices.gras()
	var t := police.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	_dessus.draw_string(police, n + Vector2(-t.x / 2.0, 4.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEINTES.OR)


func _clic(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if (event.position - Vector2(DIAMETRE, DIAMETRE) / 2.0).length() <= DIAMETRE / 2.0:
			_rond.accept_event()
			get_tree().root.get_node("Carte").ouvrir()
