extends CanvasLayer
## Ce que le joueur voit des bagarres (buildHud, buildFist et la fin de playerTick de js/npc.js) : le voile rouge
## d'un coup reçu, le fondu au noir et son message (K.-O., arrestation), la jauge « Santé » en bas à gauche
## (« · recherché » quand la sécurité le cherche) et le poing à la première personne.

const NUIT := Color("#0b0a10")
const IVOIRE := Color("#f3ead7")
const LAITON := Color("#d9a441")
const ROUGE := Color("#c2182b")
const SOURD := Color("#a99fb3")
const PANNEAU := Color("#1f1a27")
const LIGNE := Color("#3a3144")

const VOILE := """
shader_type canvas_item;
// radial-gradient(ellipse at center, rgba(194,24,43,0) 35%, #c2182b 130%)
uniform vec4 rouge : source_color = vec4(0.761, 0.094, 0.169, 1.0);
uniform float opacite = 0.0;
void fragment() {
	vec2 d = (UV - 0.5) * 2.0;
	float r = length(d) / sqrt(2.0);
	float k = clamp((r - 0.35) / (1.30 - 0.35), 0.0, 1.0);
	COLOR = vec4(rouge.rgb, rouge.a * k * opacite);
}
"""

var pnj
var voile: ColorRect
var noir: ColorRect
var texte: RichTextLabel
var sante: Control
var etiquette: Label
var jauge: Panel
var remplissage: ColorRect
var poing: Node3D

var _fade := 0.0
var _de := 0.0
var _vers := 0.0
var _duree := 0.6
var _t := 0.0
var _on := false
var _alpha := 0.0
var _largeur := 1.0
var _cible := 1.0
var _recherche := false
var _bas := false


func preparer(p) -> void:
	pnj = p
	layer = 40
	var display := _police("decor/polices/limelight.woff2")
	var corps := _police("decor/polices/barlow-600.woff2")

	voile = ColorRect.new()
	voile.name = "Voile"
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VOILE
	sm.shader = sh
	voile.material = sm
	voile.visible = false
	add_child(voile)

	sante = Control.new()
	sante.name = "Sante"
	sante.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sante.anchor_top = 1.0
	sante.anchor_bottom = 1.0
	var bas := 150.0 if DisplayServer.is_touchscreen_available() else 16.0
	sante.offset_left = 16
	sante.offset_right = 16 + 132
	sante.offset_top = -bas - 26
	sante.offset_bottom = -bas
	sante.modulate.a = 0.0
	add_child(sante)
	etiquette = Label.new()
	etiquette.text = "SANTÉ"
	etiquette.add_theme_font_override("font", corps)
	etiquette.add_theme_font_size_override("font_size", 10)
	etiquette.add_theme_color_override("font_color", SOURD)
	etiquette.add_theme_constant_override("line_spacing", 0)
	etiquette.position = Vector2(0, 0)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# letter-spacing .14em
	var fv := FontVariation.new()
	fv.base_font = corps
	fv.spacing_glyph = 1
	etiquette.add_theme_font_override("font", fv)
	sante.add_child(etiquette)
	jauge = Panel.new()
	jauge.position = Vector2(0, 18)
	jauge.size = Vector2(132, 6)
	jauge.clip_contents = true
	jauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANNEAU
	sb.border_color = LIGNE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	jauge.add_theme_stylebox_override("panel", sb)
	sante.add_child(jauge)
	remplissage = ColorRect.new()
	remplissage.color = LAITON
	remplissage.position = Vector2(1, 1)
	remplissage.size = Vector2(130, 4)
	remplissage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jauge.add_child(remplissage)

	noir = ColorRect.new()
	noir.name = "Fondu"
	noir.color = NUIT
	noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	noir.modulate.a = 0.0
	noir.visible = false
	add_child(noir)
	texte = RichTextLabel.new()
	texte.bbcode_enabled = true
	texte.fit_content = true
	texte.scroll_active = false
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texte.anchor_left = 0.5
	texte.anchor_right = 0.5
	texte.anchor_top = 0.5
	texte.anchor_bottom = 0.5
	texte.offset_left = -260
	texte.offset_right = 260
	texte.grow_vertical = Control.GROW_DIRECTION_BOTH
	texte.add_theme_font_override("normal_font", corps)
	texte.add_theme_font_override("bold_font", corps)
	texte.add_theme_font_size_override("normal_font_size", 17)
	texte.add_theme_font_size_override("bold_font_size", 17)
	texte.add_theme_color_override("default_color", IVOIRE)
	texte.set_meta("display", display)
	noir.add_child(texte)


func _police(chemin: String) -> Font:
	var f = load(pnj.BASE + chemin) if pnj != null else null
	if f is FontFile:
		(f as FontFile).fallbacks = [Polices.texte()]
		return f
	return Polices.texte()


## Le fondu au noir (fadeTo) : vers v en sec secondes ; html remplace le message quand il est donné.
func fondu(v: float, sec := 0.6, html = null) -> void:
	_de = _fade
	_vers = v
	_duree = sec if sec > 0 else 0.6
	_t = 0.0
	if html != null:
		texte.text = str(html)


## Le message du fondu : un titre en laiton (Limelight), puis le texte.
func message(titre: String, corps: String) -> void:
	var display: Font = texte.get_meta("display")
	var t := "[font_size=26][color=#d9a441]%s[/color][/font_size]" % titre
	if display.resource_path != "":
		t = "[font=%s]%s[/font]" % [display.resource_path, t]
	texte.text = "[center]%s\n[font_size=10] [/font_size]\n%s[/center]" % [t, corps]


func chaque_image(rdt: float) -> void:
	if pnj == null:
		return
	var P: Dictionary = pnj.P
	# voile
	var v: float = P.veil
	voile.visible = v > 0.0005
	if voile.visible:
		(voile.material as ShaderMaterial).set_shader_parameter("opacite", snappedf(v, 0.001))
	# fondu
	if _fade != _vers:
		_t += rdt
		var k := minf(1.0, _t / _duree)
		_fade = _de + (_vers - _de) * k
		noir.modulate.a = _fade
		noir.visible = _fade > 0.0005
	# santé
	var hp_max: float = pnj.CFG.playerHp
	var show: bool = P.hp < hp_max - 0.5 or P.wanted != null or P.attackers.size() > 0
	_on = show
	_alpha = move_toward(_alpha, 1.0 if _on else 0.0, rdt / 0.4)
	sante.modulate.a = _alpha
	var w := roundf(clampf(P.hp / hp_max, 0.0, 1.0) * 100.0)
	_cible = w / 100.0
	_largeur = move_toward(_largeur, _cible, rdt / 0.25)
	remplissage.size.x = 130.0 * _largeur
	var bas := w < 35
	if bas != _bas:
		_bas = bas
		remplissage.color = ROUGE if bas else LAITON
	var rech: bool = P.wanted != null
	if rech != _recherche:
		_recherche = rech
		_maj_recherche()
	_poing(P)


func _maj_recherche() -> void:
	var r: Label = etiquette.get_node_or_null("Recherche")
	if r == null:
		r = Label.new()
		r.name = "Recherche"
		r.text = " · RECHERCHÉ"
		r.add_theme_font_override("font", etiquette.get_theme_font("font"))
		r.add_theme_font_size_override("font_size", 10)
		r.add_theme_color_override("font_color", ROUGE)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		etiquette.add_child(r)
	r.position = Vector2(etiquette.get_theme_font("font").get_string_size("SANTÉ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 1, 0)
	r.visible = _recherche


## Le poing à la première personne (buildFist) : un avant-bras et un poing accrochés à la caméra.
func _poing(P: Dictionary) -> void:
	var cam: Camera3D = _camera()
	if cam == null:
		return
	if poing == null or not is_instance_valid(poing) or poing.get_parent() != cam:
		poing = _faire_poing()
		cam.add_child(poing)
	if P.fist > 0:
		var k: float = 1.0 - P.fist / 0.3
		var s := sin(minf(1.0, k) * PI)
		poing.visible = true
		poing.position = Vector3(0.24 - s * 0.16, -0.26 + s * 0.1, -0.42 - s * 0.38)
		poing.rotation = Vector3(0.1 - s * 0.1, 0.25 * (1 - s), 0)
	elif poing.visible:
		poing.visible = false


func _camera() -> Camera3D:
	var sc = pnj.scene
	if sc == null:
		return null
	var p = sc.get("player")
	if p == null:
		return null
	var c = p.get("camera")
	return c if c is Camera3D else null


func _faire_poing() -> Node3D:
	var g := Node3D.new()
	g.name = "pnj-poing"
	var peau := StandardMaterial3D.new()
	peau.albedo_color = Color("#c49a78")
	peau.roughness = 0.8
	var manche := StandardMaterial3D.new()
	manche.albedo_color = Color("#23232a")
	manche.roughness = 0.9
	for d in [[Vector3(0.075, 0.075, 0.34), Vector3(0, 0, 0.2), manche], [Vector3(0.085, 0.08, 0.1), Vector3.ZERO, peau], [Vector3(0.03, 0.035, 0.07), Vector3(-0.05, 0.01, 0), peau]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = d[0]
		m.mesh = b
		m.position = d[1]
		m.material_override = d[2]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(m)
	g.visible = false
	return g
