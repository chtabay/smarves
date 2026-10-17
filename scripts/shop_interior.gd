extends Node3D
## L'intérieur d'un vendeur du village, à la première personne : l'étude de Maître Garnier, l'atelier
## de Raymonde, le garage Fradin. Une pièce, un comptoir, le vendeur derrière ; on lui parle (E) et il
## ouvre sa vitrine (scripts/shop_panel.gd). La porte ramène sur la place.
## Capture : godot --path . res://scenes/notaire.tscn -- --capture=sortie.png [--at=x,z,lacet,tangage] [--open=vitrine]
## [--won=5000] [--biens=smarvoise,dimanche,…] [--carnet]

const PLAYER := preload("res://scripts/fp_player.gd")
const CRITTER := preload("res://scripts/critter.gd")
const PANEL := preload("res://scripts/shop_panel.gd")
const KK := "res://assets/kaykit/"
const PEOPLE_SCALE := 2.6

## notaire, couture ou garage (une clé de Biens.SELLERS).
@export var shop := "notaire"

## La pièce : largeur (x), profondeur (z), hauteur. Le garage est plus grand, pour ses voitures.
var W := 9.0
var D := 8.0
var H := 3.4

## Le vendeur : espèce, pelage, tenue, accessoire, et ce qu'il dit quand on lui parle.
const KEEPERS := {
	"notaire": {"species": "chat", "fur": Color(0.72, 0.7, 0.68), "outfit": Color(0.16, 0.16, 0.2), "acc": "noeud",
		"lines": ["« Maître Garnier, pour vous servir. Le village cède ses parts : une occasion qui ne se représentera pas avant la prochaine. »",
			"« Un acte notarié, c'est une promesse qui ne peut pas mentir. Les rentes, c'est autre chose, mais l'acte est parfait. »",
			"« Josiane cède des parts de sa Smarvoise. Une machine qui tourne tous les soirs, voyez-vous ça. »",
			"« Je joue un peu, le samedi, du côté de Passelourdin. Pour connaître le marché. »"]},
	"couture": {"species": "lapin", "fur": Color(1.0, 0.86, 0.9), "outfit": Color(0.55, 0.2, 0.55), "acc": "collier",
		"lines": ["« Raymonde, couture et retouches. Un costume, c'est la moitié d'une martingale. »",
			"« Au casino, on ne fait pas crédit à une veste froissée. Enfin, M. Brunet si, mais lui il fait crédit à tout le monde. »",
			"« Le smoking, je le réserve aux clients du Salon privé. Ils ont besoin de poches profondes. »"]},
	"garage": {"species": "ours", "fur": Color(0.75, 0.55, 0.38), "outfit": Color(0.18, 0.32, 0.62), "acc": "",
		"lines": ["« Roger Fradin, garage toutes marques. Une voiture, c'est un placement qui roule. »",
			"« La 2 CV, c'était celle de Dédé. Il l'a perdue au 421 ; elle a gagné un nouveau propriétaire. »",
			"« Le jour où vous gagnez gros, la DS vous attend. Les gros gagnants ne prennent pas le car. »"]},
}

var player: CharacterBody3D
var _keeper: Node3D
var _prompt: Label
var _credits: Label
var _speech: Label
var _panel_layer: CenterContainer
var _panel: Control
var _serif: SystemFont
var _speech_tween: Tween


func _ready() -> void:
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"])
	if shop == "garage":
		W = 13.0
		D = 11.0
		H = 4.2
	_environment()
	match shop:
		"couture":
			_room(_wood_floor(Color(0.78, 0.6, 0.42)), _wallpaper(Color(0.86, 0.66, 0.68), Color(0.93, 0.78, 0.78)), Color(0.98, 0.95, 0.92))
			_couture()
		"garage":
			_room(_concrete(), _std(Color(0.88, 0.84, 0.72), 0.85), Color(0.75, 0.75, 0.72), Color(0.2, 0.42, 0.3))
			_garage()
		_:
			_room(_wood_floor(Color(0.42, 0.26, 0.15)), _wallpaper(Color(0.2, 0.32, 0.26), Color(0.26, 0.4, 0.32)), Color(0.92, 0.88, 0.8), Color(0.35, 0.2, 0.11))
			_notaire()
	_build_keeper()
	_door()
	_build_ui()
	player = PLAYER.new()
	player.position = Vector3(0, 0, D / 2.0 - 1.2)
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("casino" if shop == "notaire" else "village")
	_maybe_capture()


# --- Matériaux --------------------------------------------------------------------------------

func _std(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _noise(freq: float, stretch := Vector2.ONE, dark := Color(0.7, 0.7, 0.7)) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.width = int(512 * stretch.x)
	t.height = int(512 * stretch.y)
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.set_color(0, dark)
	g.set_color(1, Color.WHITE)
	t.color_ramp = g
	return t


func _wood_floor(c: Color) -> StandardMaterial3D:
	# Parquet : des lames étirées, un vernis qui brille un peu.
	var m := _std(c, 0.35)
	var n := FastNoiseLite.new()
	n.frequency = 0.004
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	var t := NoiseTexture2D.new()
	t.width = 1024
	t.height = 128
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.75, 0.7, 0.66))
	g.set_color(1, Color.WHITE)
	t.color_ramp = g
	m.albedo_texture = t
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.6, 0.6, 2.4)
	return m


func _wallpaper(a: Color, b: Color) -> StandardMaterial3D:
	# Papier peint à rayures : une image de deux couleurs, répétée.
	var img := Image.create(32, 4, false, Image.FORMAT_RGB8)
	for x in 32:
		for y in 4:
			img.set_pixel(x, y, a if (x / 4) % 2 == 0 else b)
	var m := _std(Color.WHITE, 0.85)
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.9, 0.9, 0.9)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func _concrete() -> StandardMaterial3D:
	var m := _std(Color(0.55, 0.54, 0.52), 0.8)
	m.albedo_texture = _noise(0.03, Vector2.ONE, Color(0.72, 0.7, 0.68))
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.4, 0.4, 0.4)
	return m


# --- Briques ----------------------------------------------------------------------------------

func _box(size: Vector3, pos: Vector3, mat: Material, collide := false, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)
	return mi


func _cyl(r: float, h: float, pos: Vector3, mat: Material, parent: Node = self, r_top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if r_top < 0.0 else r_top
	c.height = h
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _place(path: String, pos: Vector3, scale := 1.0, rot_y := 0.0) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scale
	n.rotation_degrees.y = rot_y
	add_child(n)
	return n


func _lamp(pos: Vector3, color := Color(1.0, 0.78, 0.5), energy := 1.6, rng := 6.0, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadow
	l.position = pos
	add_child(l)
	return l


func _bulb(pos: Vector3, shade: Color) -> void:
	# Une suspension : le fil, l'abat-jour, l'ampoule qui brille.
	var glow := _std(Color(1.0, 0.85, 0.6), 0.3)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.75, 0.45)
	glow.emission_energy_multiplier = 6.0
	_box(Vector3(0.015, H - pos.y, 0.015), Vector3(pos.x, (H + pos.y) / 2.0, pos.z), _std(Color(0.1, 0.1, 0.1), 0.5))
	_cyl(0.26, 0.22, pos + Vector3(0, 0.08, 0), _std(shade, 0.5), self, 0.08).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var s := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.07
	sp.height = 0.14
	s.mesh = sp
	s.material_override = glow
	s.position = pos
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	_lamp(pos + Vector3(0, -0.1, 0), Color(1.0, 0.76, 0.48), 2.2, 7.0, true)


func _interactive(node: Node3D, kind: String, prompt: String, size: Vector3, offset := Vector3.ZERO) -> Area3D:
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = offset
	a.add_child(cs)
	a.set_meta("interact", kind)
	a.set_meta("prompt", prompt)
	node.add_child(a)
	return a


func _label3d(text: String, pos: Vector3, size: int, color: Color, rot_y := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _serif
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees.y = rot_y
	add_child(l)
	return l


# --- La pièce ---------------------------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.45, 0.4)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.4
	env.ssil_enabled = true
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## Sol, plafond, quatre murs (une porte au sud), une plinthe, et une fenêtre sur le crépuscule à l'est.
func _room(floor_mat: Material, wall_mat: Material, ceiling_col: Color, wainscot := Color(0, 0, 0, 0)) -> void:
	_box(Vector3(W, 0.2, D), Vector3(0, -0.1, 0), floor_mat, true)
	_box(Vector3(W, 0.2, D), Vector3(0, H + 0.1, 0), _std(ceiling_col, 0.9))
	var t := 0.2
	_box(Vector3(W + 2 * t, H, t), Vector3(0, H / 2.0, -D / 2.0 - t / 2.0), wall_mat, true)
	_box(Vector3(t, H, D), Vector3(-W / 2.0 - t / 2.0, H / 2.0, 0), wall_mat, true)
	# Mur est : la fenêtre au milieu.
	var win_z := 0.4
	var win_w := 1.8
	var north_end := win_z - win_w / 2.0
	var south_start := win_z + win_w / 2.0
	_box(Vector3(t, H, north_end + D / 2.0), Vector3(W / 2.0 + t / 2.0, H / 2.0, (-D / 2.0 + north_end) / 2.0), wall_mat, true)
	_box(Vector3(t, H, D / 2.0 - south_start), Vector3(W / 2.0 + t / 2.0, H / 2.0, (south_start + D / 2.0) / 2.0), wall_mat, true)
	_box(Vector3(t, 1.0, win_w), Vector3(W / 2.0 + t / 2.0, 0.5, win_z), wall_mat, true)
	_box(Vector3(t, H - 2.4, win_w), Vector3(W / 2.0 + t / 2.0, 2.4 + (H - 2.4) / 2.0, win_z), wall_mat)
	# Dehors : le ciel bleu nuit du samedi, et une lueur de vitrine en face.
	var sky := _std(Color(0.1, 0.14, 0.32), 1.0)
	sky.emission_enabled = true
	sky.emission = Color(0.12, 0.18, 0.42)
	sky.emission_energy_multiplier = 1.4
	_box(Vector3(0.05, 1.4, win_w), Vector3(W / 2.0 + 0.5, 1.7, win_z), sky)
	var frame := _std(Color(0.92, 0.9, 0.84), 0.5)
	_box(Vector3(0.08, 0.06, win_w), Vector3(W / 2.0 + 0.02, 1.7, win_z), frame)
	_box(Vector3(0.08, 1.4, 0.06), Vector3(W / 2.0 + 0.02, 1.7, win_z), frame)
	_box(Vector3(0.3, 0.06, win_w + 0.2), Vector3(W / 2.0 - 0.1, 1.0, win_z), frame)
	_lamp(Vector3(W / 2.0 - 0.6, 1.8, win_z), Color(0.35, 0.45, 0.9), 0.6, 4.0)
	# Mur sud, avec la porte (1,2 m) au milieu.
	var dw := 1.2
	var side := (W - dw) / 2.0
	_box(Vector3(side, H, t), Vector3(-W / 2.0 + side / 2.0, H / 2.0, D / 2.0 + t / 2.0), wall_mat, true)
	_box(Vector3(side, H, t), Vector3(W / 2.0 - side / 2.0, H / 2.0, D / 2.0 + t / 2.0), wall_mat, true)
	_box(Vector3(dw, H - 2.3, t), Vector3(0, 2.3 + (H - 2.3) / 2.0, D / 2.0 + t / 2.0), wall_mat)
	# Plinthes, et lambris à hauteur d'appui si la pièce en a.
	var trim := _std(Color(0.3, 0.2, 0.12) if wainscot.a == 0.0 else wainscot.darkened(0.3), 0.5)
	for seg in [[Vector3(W, 0.14, 0.04), Vector3(0, 0.07, -D / 2.0 + 0.02)], [Vector3(0.04, 0.14, D), Vector3(-W / 2.0 + 0.02, 0.07, 0)]]:
		_box(seg[0], seg[1], trim)
	if wainscot.a > 0.0:
		var panel := _std(wainscot, 0.45)
		_box(Vector3(W, 1.1, 0.05), Vector3(0, 0.55, -D / 2.0 + 0.025), panel)
		_box(Vector3(0.05, 1.1, D), Vector3(-W / 2.0 + 0.025, 0.55, 0), panel)
		for seg in [[Vector3(W, 0.05, 0.08), Vector3(0, 1.12, -D / 2.0 + 0.04)], [Vector3(0.08, 0.05, D), Vector3(-W / 2.0 + 0.04, 1.12, 0)]]:
			_box(seg[0], seg[1], trim)
		# Des panneaux moulurés, un tous les 0,9 m.
		for i in 9:
			_box(Vector3(0.6, 0.6, 0.02), Vector3(-W / 2.0 + 0.6 + i * 0.95, 0.56, -D / 2.0 + 0.06), trim)
		for i in 8:
			_box(Vector3(0.02, 0.6, 0.6), Vector3(-W / 2.0 + 0.06, 0.56, -D / 2.0 + 0.7 + i * 0.95), trim)
	# Corniche.
	_box(Vector3(W, 0.12, 0.1), Vector3(0, H - 0.06, -D / 2.0 + 0.05), frame)
	_box(Vector3(0.1, 0.12, D), Vector3(-W / 2.0 + 0.05, H - 0.06, 0), frame)


func _door() -> void:
	# La porte vitrée, et le crépuscule derrière.
	var wood := _std(Color(0.35, 0.2, 0.1), 0.5)
	var root := Node3D.new()
	root.position = Vector3(0, 0, D / 2.0 + 0.05)
	add_child(root)
	_box(Vector3(1.2, 2.3, 0.06), Vector3(0, 1.15, 0.0), wood, false, root)
	var glass := _std(Color(0.2, 0.28, 0.55), 0.1)
	glass.emission_enabled = true
	glass.emission = Color(0.14, 0.2, 0.45)
	glass.emission_energy_multiplier = 1.2
	_box(Vector3(0.8, 1.0, 0.07), Vector3(0, 1.55, 0.0), glass, false, root)
	_cyl(0.035, 0.12, Vector3(0.45, 1.05, -0.08), _std(Color(0.85, 0.68, 0.3), 0.25, 1.0), root).rotation_degrees.x = 90.0
	_interactive(root, "exit", "E : sortir sur la place", Vector3(1.2, 2.3, 0.6), Vector3(0, 1.15, -0.2))


func _build_keeper() -> void:
	var k: Dictionary = KEEPERS.get(shop, KEEPERS.notaire)
	_keeper = Node3D.new()
	_keeper.position = Vector3(0, 0, -D / 2.0 + 1.3)
	add_child(_keeper)
	var c := CRITTER.new()
	c.species = k.species
	c.fur = k.fur
	c.outfit = k.outfit
	c.accessory = k.acc
	# Leur fiche de personnage (docs/PERSONNAGES.md), si elle existe.
	var who: String = {"notaire": "garnier", "couture": "raymonde", "garage": "fradin"}.get(shop, "")
	if Cast.NAMED.has(who):
		c.look = Cast.NAMED[who].duplicate(true)
		c.idle_anim = "attentive"
	c.scale = Vector3.ONE * PEOPLE_SCALE
	_keeper.add_child(c)
	var host: String = Biens.SELLERS[shop].host
	_interactive(_keeper, "keeper", "E : parler à %s" % host, Vector3(1.2, 2.2, 1.6), Vector3(0, 1.1, 0.9))


# --- L'étude de Maître Garnier ------------------------------------------------------------------

func _notaire() -> void:
	var mahogany := _std(Color(0.3, 0.13, 0.07), 0.35)
	var leather := _std(Color(0.12, 0.3, 0.18), 0.5)
	var brass := _std(Color(0.85, 0.68, 0.3), 0.25, 1.0)
	# Le grand bureau, son sous-main de cuir vert, la lampe de banquier.
	_box(Vector3(2.6, 0.08, 1.1), Vector3(0, 0.82, -D / 2.0 + 2.2), mahogany, true)
	_box(Vector3(2.5, 0.74, 0.08), Vector3(0, 0.4, -D / 2.0 + 2.72), mahogany, true)
	for x in [-1.2, 1.2]:
		_box(Vector3(0.1, 0.78, 1.0), Vector3(x, 0.39, -D / 2.0 + 2.2), mahogany, true)
	_box(Vector3(1.0, 0.01, 0.6), Vector3(0, 0.865, -D / 2.0 + 2.2), leather)
	var shade := _std(Color(0.1, 0.45, 0.25), 0.2)
	shade.emission_enabled = true
	shade.emission = Color(0.1, 0.5, 0.25)
	shade.emission_energy_multiplier = 0.6
	_cyl(0.025, 0.36, Vector3(0.9, 1.04, -D / 2.0 + 2.0), brass)
	_box(Vector3(0.5, 0.1, 0.18), Vector3(0.9, 1.24, -D / 2.0 + 2.05), shade)
	_lamp(Vector3(0.9, 1.1, -D / 2.0 + 2.1), Color(1.0, 0.85, 0.6), 1.2, 3.0)
	# Un acte en cours, l'encrier, le tampon.
	var paper := _std(Color(0.97, 0.95, 0.88), 0.9)
	_box(Vector3(0.3, 0.005, 0.42), Vector3(-0.15, 0.87, -D / 2.0 + 2.25), paper).rotation_degrees.y = 8.0
	_box(Vector3(0.3, 0.005, 0.42), Vector3(-0.5, 0.872, -D / 2.0 + 2.15), paper).rotation_degrees.y = -12.0
	_cyl(0.05, 0.07, Vector3(0.3, 0.9, -D / 2.0 + 2.0), _std(Color(0.05, 0.05, 0.1), 0.1))
	_place(KK + "furniture/armchair.gltf", Vector3(0, 0, -D / 2.0 + 0.9), 0.6, 0.0)
	_place(KK + "furniture/chair_A_wood.gltf", Vector3(-0.9, 0, -D / 2.0 + 3.3), 0.75, 200.0)
	_place(KK + "furniture/chair_A_wood.gltf", Vector3(0.9, 0, -D / 2.0 + 3.3), 0.75, 160.0)
	# Les rayonnages de dossiers, du sol au plafond, contre le mur ouest.
	for i in 3:
		var z := -2.6 + i * 1.7
		_shelf_of_files(Vector3(-W / 2.0 + 0.35, 0, z), mahogany)
	# Le coffre-fort, l'horloge, le portrait du fondateur.
	_box(Vector3(0.8, 1.0, 0.7), Vector3(W / 2.0 - 0.6, 0.5, -D / 2.0 + 0.6), _std(Color(0.18, 0.2, 0.22), 0.4, 0.6), true)
	_cyl(0.18, 0.04, Vector3(W / 2.0 - 0.6, 0.6, -D / 2.0 + 0.97), brass).rotation_degrees.x = 90.0
	_box(Vector3(0.5, 2.1, 0.35), Vector3(W / 2.0 - 1.6, 1.05, -D / 2.0 + 0.25), mahogany, true)
	_cyl(0.18, 0.03, Vector3(W / 2.0 - 1.6, 1.7, -D / 2.0 + 0.44), _std(Color(0.95, 0.92, 0.82), 0.6)).rotation_degrees.x = 90.0
	_box(Vector3(1.8, 0.62, 0.05), Vector3(0, 2.75, -D / 2.0 + 0.06), brass)
	_box(Vector3(1.7, 0.52, 0.06), Vector3(0, 2.75, -D / 2.0 + 0.07), _std(Color(0.12, 0.1, 0.08), 0.8))
	_label3d("Maître Garnier  ·  Notaire", Vector3(0, 2.82, -D / 2.0 + 0.11), 64, Color(0.9, 0.78, 0.45))
	_label3d("Fondée en 1911  ·  « Votre avenir, notre acte »", Vector3(0, 2.62, -D / 2.0 + 0.11), 30, Color(0.85, 0.72, 0.45))
	_place(KK + "furniture/rug_rectangle_stripes_A.gltf", Vector3(0, 0.01, 0.6), 2.0, 90.0)
	_place(KK + "furniture/lamp_standing.gltf", Vector3(W / 2.0 - 0.5, 0, 2.6), 1.4)
	_place("res://assets/kenney/furniture/pottedPlant.glb", Vector3(W / 2.0 - 0.5, 0, -1.2), 3.0)
	_bulb(Vector3(0, H - 0.6, -1.2), Color(0.9, 0.85, 0.7))
	_bulb(Vector3(0, H - 0.6, 2.0), Color(0.9, 0.85, 0.7))
	_lamp(Vector3(-2.5, 2.2, 0), Color(1.0, 0.8, 0.55), 0.7, 5.0)


func _shelf_of_files(at: Vector3, wood: Material) -> void:
	_box(Vector3(0.5, 2.8, 1.5), at + Vector3(0, 1.4, 0), wood, true)
	var colors := [Color(0.55, 0.2, 0.15), Color(0.2, 0.3, 0.5), Color(0.8, 0.7, 0.5), Color(0.25, 0.4, 0.25), Color(0.6, 0.55, 0.45)]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.z * 100.0)
	for row in 5:
		var y := 0.25 + row * 0.55
		_box(Vector3(0.46, 0.03, 1.44), at + Vector3(0.05, y - 0.03, 0), wood)
		var z := -0.66
		while z < 0.62:
			var w := rng.randf_range(0.05, 0.12)
			var h := rng.randf_range(0.32, 0.46)
			var c: Color = colors[rng.randi() % colors.size()]
			_box(Vector3(0.36, h, w), at + Vector3(0.12, y + h / 2.0, z + w / 2.0), _std(c, 0.8))
			z += w + 0.01


# --- L'atelier de Raymonde ----------------------------------------------------------------------

func _couture() -> void:
	var wood := _std(Color(0.62, 0.42, 0.26), 0.4)
	# Le comptoir, sa caisse enregistreuse, le mètre ruban.
	_box(Vector3(3.0, 1.0, 0.7), Vector3(0, 0.5, -D / 2.0 + 2.2), wood, true)
	_box(Vector3(3.1, 0.05, 0.8), Vector3(0, 1.02, -D / 2.0 + 2.2), _std(Color(0.95, 0.92, 0.85), 0.3))
	_box(Vector3(0.4, 0.28, 0.35), Vector3(1.0, 1.18, -D / 2.0 + 2.2), _std(Color(0.75, 0.62, 0.3), 0.3, 0.8))
	_box(Vector3(1.2, 0.01, 0.03), Vector3(-0.5, 1.05, -D / 2.0 + 2.1), _std(Color(1.0, 0.9, 0.3), 0.6))
	# Les mannequins, habillés des tenues de la maison.
	var tenues := []
	for it in Biens.CATALOGUE:
		if it.kind == "tenue":
			tenues.append(it)
	var spots := [Vector3(-3.0, 0, 0.9), Vector3(-2.0, 0, 0.1), Vector3(1.9, 0, -1.6)]
	for i in tenues.size():
		_mannequin(spots[i % spots.size()], tenues[i].color, tenues[i].name)
	# Les rouleaux de tissu, en biais, contre le mur ouest.
	var fabrics := [Color(0.16, 0.26, 0.66), Color(0.5, 0.46, 0.4), Color(0.05, 0.05, 0.07), Color(0.75, 0.15, 0.2),
		Color(0.85, 0.75, 0.55), Color(0.2, 0.45, 0.3), Color(0.6, 0.3, 0.55), Color(0.92, 0.9, 0.86)]
	_box(Vector3(0.6, 2.4, 3.2), Vector3(-W / 2.0 + 0.3, 1.2, -1.6), wood, true)
	for row in 3:
		for k in fabrics.size():
			var roll := _cyl(0.09, 0.55, Vector3(-W / 2.0 + 0.62, 0.45 + row * 0.75, -3.0 + k * 0.38), _std(fabrics[(k + row * 3) % fabrics.size()], 0.85))
			roll.rotation_degrees.z = 90.0
	# Le grand miroir en pied et la cabine d'essayage.
	var mirror := _std(Color(0.85, 0.9, 0.95), 0.02, 1.0)
	_box(Vector3(0.9, 2.0, 0.05), Vector3(2.4, 1.15, -D / 2.0 + 0.08), mirror)
	_box(Vector3(1.0, 2.1, 0.06), Vector3(2.4, 1.15, -D / 2.0 + 0.06), _std(Color(0.85, 0.7, 0.35), 0.3, 1.0))
	var curtain := _std(Color(0.6, 0.15, 0.25), 0.9)
	_box(Vector3(1.4, 2.4, 0.06), Vector3(W / 2.0 - 0.8, 1.25, 2.4), curtain, true)
	_box(Vector3(0.06, 2.4, 1.4), Vector3(W / 2.0 - 1.5, 1.25, 3.1), curtain, true)
	# La table de coupe, la machine à coudre.
	_box(Vector3(1.6, 0.06, 0.9), Vector3(2.0, 0.85, 0.6), wood, true)
	for p in [Vector3(1.3, 0.42, 0.25), Vector3(2.7, 0.42, 0.25), Vector3(1.3, 0.42, 0.95), Vector3(2.7, 0.42, 0.95)]:
		_box(Vector3(0.06, 0.84, 0.06), p, wood)
	var black := _std(Color(0.05, 0.05, 0.06), 0.2, 0.3)
	_box(Vector3(0.5, 0.25, 0.2), Vector3(2.2, 1.02, 0.6), black)
	_box(Vector3(0.12, 0.3, 0.2), Vector3(2.4, 1.2, 0.6), black)
	_box(Vector3(0.4, 0.1, 0.2), Vector3(2.25, 1.36, 0.6), black)
	_label3d("Raymonde", Vector3(0, 2.6, -D / 2.0 + 0.12), 96, Color(0.6, 0.15, 0.3))
	_label3d("couture  ·  retouches  ·  sur mesure", Vector3(0, 2.25, -D / 2.0 + 0.12), 36, Color(0.45, 0.2, 0.3))
	_place(KK + "furniture/rug_oval_A.gltf", Vector3(0, 0.01, 1.4), 2.0)
	_place("res://assets/kenney/furniture/pottedPlant.glb", Vector3(-W / 2.0 + 0.5, 0, 3.2), 3.0)
	_bulb(Vector3(-1.2, H - 0.7, -0.2), Color(0.95, 0.8, 0.85))
	_bulb(Vector3(1.5, H - 0.7, 1.2), Color(0.95, 0.8, 0.85))


func _mannequin(at: Vector3, outfit: Color, name: String) -> void:
	var stand := _std(Color(0.3, 0.2, 0.12), 0.4)
	var cloth := _std(outfit, 0.7)
	var body := _std(Color(0.92, 0.86, 0.75), 0.6)
	_cyl(0.22, 0.05, at + Vector3(0, 0.03, 0), stand)
	_cyl(0.025, 1.0, at + Vector3(0, 0.55, 0), stand)
	_cyl(0.2, 0.75, at + Vector3(0, 1.38, 0), cloth, self, 0.26)
	_cyl(0.27, 0.12, at + Vector3(0, 1.8, 0), cloth, self, 0.12)
	_cyl(0.06, 0.12, at + Vector3(0, 1.9, 0), body)
	var knob := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.08
	sp.height = 0.16
	knob.mesh = sp
	knob.material_override = stand
	knob.position = at + Vector3(0, 2.0, 0)
	add_child(knob)
	# Le revers et la boutonnière, pour qu'on lise un costume.
	_box(Vector3(0.12, 0.35, 0.02), at + Vector3(0, 1.55, 0.24), _std(Color(0.95, 0.95, 0.92), 0.6))
	_label3d(name, at + Vector3(0, 0.12, 0.3), 18, Color(0.35, 0.2, 0.25)).rotation_degrees.x = -60.0


# --- Le garage Fradin ---------------------------------------------------------------------------

func _garage() -> void:
	var steel := _std(Color(0.35, 0.37, 0.4), 0.45, 0.7)
	var red := _std(Color(0.75, 0.12, 0.1), 0.4)
	# L'établi au fond, le comptoir où l'on signe le bon de commande.
	_box(Vector3(3.0, 1.0, 0.7), Vector3(0, 0.5, -D / 2.0 + 2.2), _std(Color(0.4, 0.3, 0.2), 0.6), true)
	_box(Vector3(3.1, 0.05, 0.8), Vector3(0, 1.02, -D / 2.0 + 2.2), steel)
	_box(Vector3(4.0, 1.4, 0.05), Vector3(-3.6, 1.7, -D / 2.0 + 0.04), _std(Color(0.55, 0.42, 0.28), 0.8))
	for i in 9:
		var tool := _box(Vector3(0.05, 0.35, 0.03), Vector3(-5.2 + i * 0.4, 1.8, -D / 2.0 + 0.08), steel)
		tool.rotation_degrees.z = (i % 3 - 1) * 15.0
	# Les véhicules à vendre : celui du moment, sur le pont, et les deux autres.
	var spots := [Vector3(4.6, 0, 3.6), Vector3(-3.6, 0, 0.8), Vector3(3.4, 0, -0.8)]
	var i := 0
	for it in Biens.CATALOGUE:
		if it.kind != "vehicule":
			continue
		var v := Biens.build_vehicle(it.id)
		v.position = spots[i] as Vector3
		v.rotation_degrees.y = [-130.0, 20.0, -40.0][i]
		v.scale = Vector3.ONE * 4.2
		add_child(v)
		# L'étiquette de prix, posée sur un chevalet.
		var tag: Vector3 = spots[i] + Vector3(0, 0, 2.2 if i == 1 else 1.4)
		if i == 0:
			tag = spots[i] + Vector3(-1.0, 0, 0)
		_box(Vector3(0.04, 0.9, 0.04), tag + Vector3(0, 0.45, 0), steel)
		_box(Vector3(0.7, 0.4, 0.03), tag + Vector3(0, 1.0, 0), _std(Color(0.97, 0.95, 0.88), 0.8))
		_label3d("%s\n%s crédits" % [it.name, Game.fmt(it.price)], tag + Vector3(0, 1.0, 0.02), 22, Color(0.15, 0.15, 0.2))
		i += 1
	# Le pont élévateur sous la première.
	for x in [-4.5, -2.7]:
		_box(Vector3(0.18, 0.08, 4.0), Vector3(x, 0.04, 0.8), red)
	# La pompe à essence, les pneus, le bidon d'huile.
	_box(Vector3(0.6, 1.6, 0.45), Vector3(W / 2.0 - 0.5, 0.8, -D / 2.0 + 0.6), red, true)
	var dial := _std(Color(0.95, 0.95, 0.9), 0.3)
	dial.emission_enabled = true
	dial.emission = Color(1.0, 0.95, 0.8)
	dial.emission_energy_multiplier = 0.8
	_box(Vector3(0.4, 0.3, 0.02), Vector3(W / 2.0 - 0.5, 1.25, -D / 2.0 + 0.84), dial)
	_label3d("SUPER", Vector3(W / 2.0 - 0.5, 1.7, -D / 2.0 + 0.84), 40, Color(1.0, 0.9, 0.3))
	var rubber := _std(Color(0.06, 0.06, 0.06), 0.85)
	for k in 4:
		var tire := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.18
		t.outer_radius = 0.33
		tire.mesh = t
		tire.material_override = rubber
		tire.position = Vector3(-W / 2.0 + 0.5, 0.08 + k * 0.16, 3.2)
		add_child(tire)
	_cyl(0.28, 0.85, Vector3(-W / 2.0 + 1.3, 0.43, 3.3), _std(Color(0.15, 0.35, 0.6), 0.4, 0.5))
	# Les taches d'huile, l'enseigne peinte.
	var oil := _std(Color(0.05, 0.05, 0.06), 0.1)
	for p in [Vector3(-3.2, 0.005, 2.0), Vector3(-4.0, 0.005, -0.4), Vector3(2.0, 0.005, 1.6), Vector3(0.6, 0.005, 3.4)]:
		_cyl(0.3, 0.005, p, oil)
	_label3d("GARAGE FRADIN", Vector3(1.6, 3.1, -D / 2.0 + 0.12), 96, Color(0.2, 0.42, 0.3))
	_label3d("toutes marques  ·  réparations  ·  occasions  ·  crédit", Vector3(1.6, 2.75, -D / 2.0 + 0.12), 32, Color(0.25, 0.3, 0.3))
	for x in [-4.0, 0.0, 4.0]:
		var neon := _std(Color(1, 1, 1), 0.2)
		neon.emission_enabled = true
		neon.emission = Color(0.85, 0.95, 1.0)
		neon.emission_energy_multiplier = 4.0
		_box(Vector3(1.8, 0.05, 0.12), Vector3(x, H - 0.1, 0.6), neon)
		_lamp(Vector3(x, H - 0.4, 0.6), Color(0.88, 0.95, 1.0), 2.0, 8.0, x == 0.0)


# --- Interface --------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.045, 0.07, 0.8)
	st.border_color = Color(0.8, 0.6, 0.3, 0.55)
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(14)
	box.add_theme_stylebox_override("panel", st)
	box.position = Vector2(28, 24)
	root.add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	var t := Label.new()
	t.text = Biens.SELLERS[shop].name.to_upper()
	t.add_theme_font_override("font", _serif)
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", Color(0.7, 0.62, 0.5))
	v.add_child(t)
	_credits = Label.new()
	_credits.add_theme_font_override("font", _serif)
	_credits.add_theme_font_size_override("font_size", 34)
	_credits.add_theme_color_override("font_color", Color(0.96, 0.8, 0.45))
	v.add_child(_credits)
	var hint := Label.new()
	hint.text = "ZQSD : marcher   ·   E : parler, sortir   ·   C : le carnet   ·   Échap : réglages"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 0.85))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.position.y -= 22
	root.add_child(hint)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position.y += 40
	_prompt.add_theme_font_override("font", _serif)
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_prompt.add_theme_constant_override("outline_size", 7)
	root.add_child(_prompt)
	_speech = Label.new()
	_speech.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speech.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_speech.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_speech.position.y -= 46
	_speech.custom_minimum_size.x = 1000
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech.add_theme_font_override("font", _serif)
	_speech.add_theme_font_size_override("font_size", 22)
	_speech.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_speech.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_speech.add_theme_constant_override("outline_size", 8)
	_speech.modulate.a = 0.0
	root.add_child(_speech)
	_panel_layer = CenterContainer.new()
	_panel_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel_layer)


func say(text: String) -> void:
	_speech.text = "%s : %s" % [Biens.SELLERS[shop].host, text]
	_speech.modulate.a = 1.0
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = create_tween()
	_speech_tween.tween_interval(4.0 + text.length() * 0.04)
	_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.8)


func _process(_delta: float) -> void:
	_credits.text = "%s crédits" % Game.fmt(Game.credits)
	var t: Node = player.focus_target if player else null
	_prompt.visible = t != null and _panel == null
	if t != null:
		_prompt.text = str(t.get_meta("prompt", ""))
	# Le vendeur suit le joueur des yeux.
	if _keeper and player:
		var d := player.global_position - _keeper.global_position
		_keeper.rotation.y = lerp_angle(_keeper.rotation.y, atan2(d.x, d.z), 0.05)


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			Game.return_point = shop
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		"keeper":
			say((KEEPERS.get(shop, KEEPERS.notaire).lines as Array).pick_random())
			var keeper := _keeper.get_child(0)
			if keeper.has_method("gesture"):
				keeper.gesture("talk")
				keeper.talk(2.5)
			open_vitrine()


func open_vitrine() -> void:
	if _panel != null:
		return
	var p: PanelContainer = PANEL.new()
	p.seller = shop
	p.spoke.connect(say)
	p.closed.connect(func():
		p.queue_free()
		_panel = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_panel = p


# --- Capture ------------------------------------------------------------------------------------

func _maybe_capture() -> void:
	var path := ""
	var open := false
	var carnet := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
			if v.size() > 3:
				player.camera.rotation.x = deg_to_rad(v[3])
		elif arg == "--open=vitrine":
			open = true
		elif arg.begins_with("--biens="):
			# Des biens déjà achetés, et quelques recettes passées, pour voir le carnet rempli.
			Game.credits += 50000
			for id in arg.trim_prefix("--biens=").split(","):
				Biens.buy(id)
			Game.credits -= 40000
			for k in 60:
				Game.spend(25)
		elif arg == "--carnet":
			carnet = true
		elif arg.begins_with("--won="):
			Game.won = int(arg.trim_prefix("--won="))
			Game.credits += Game.won / 2
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if open:
		await get_tree().create_timer(1.0).timeout
		say((KEEPERS.get(shop, KEEPERS.notaire).lines as Array)[0])
		open_vitrine()
	if carnet:
		await get_tree().create_timer(1.0).timeout
		Carnet.toggle()
	await get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
