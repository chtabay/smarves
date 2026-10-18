extends Node3D
## Le van des chasseurs de pépites, sur la placette de la rue du Clain : un clin d'œil à Authentic
## Spirits, de vrais dénicheurs d'eaux-de-vie rares qui sillonnent les régions en van
## (https://www.authentic-spirits.com/). Capucine Varenne, leur chasseuse, est au Bar du Fumoir du
## casino (Lines.SPEAKERS.capucine) ; quand elle est en ville, son van dort sur la placette.
##
## Le village de départ ne change pas : jusqu'au seuil, c'est la camionnette bleue de toujours.
## À SEUIL crédits gagnés au jeu (celui de la Loggia), elle prend sa livrée noire aux lettres dorées.
## Loi Évin : une enseigne de métier (origine, chasse, terroirs), pas une réclame ; rien ne s'y vend.

const SEUIL := 2000
const ENSEIGNE := "AUTHENTIC SPIRITS"
const METIER := "Chasseurs de pépites"
const ROUTE := "Armagnac · Calvados · Cognac · Alsace"
const PLAQUE := "AS-020-VN"
const NOIR := Color(0.05, 0.05, 0.06)
const OR := Color(0.86, 0.68, 0.3)

var van: Node3D
var livree := false
var _font: Font


## `car` : la camionnette déjà posée sur la placette ; `font` : la police des enseignes.
func setup(car: Node3D, font: Font) -> void:
	van = car
	_font = font
	name = "VanDesPepites"
	set_process(true)
	_check()


func _process(_delta: float) -> void:
	_check()


func _check() -> void:
	if livree or van == null:
		return
	if Game.won >= SEUIL:
		paint()


## Peint la camionnette : carrosserie noire laquée, lettres dorées sur les deux flancs, plaque à l'arrière.
func paint() -> void:
	livree = true
	set_process(false)
	_lacquer(van)
	# Les dimensions du van posé, dans son propre repère (il est ramené à 1,5 de long par Village._car).
	var box := _local_aabb(van)
	var long_x := box.size.x >= box.size.z
	var length := maxf(box.size.x, box.size.z)
	var width := minf(box.size.x, box.size.z)
	var mid := box.get_center()
	var h := box.position.y + box.size.y * 0.62
	for side: float in [-1.0, 1.0]:
		var off := (width / 2.0 + 0.004) * side
		var at := Vector3(mid.x, h, mid.z + off) if long_x else Vector3(mid.x + off, h, mid.z)
		var yaw := (0.0 if side > 0.0 else 180.0) if long_x else (90.0 if side > 0.0 else -90.0)
		_letters(ENSEIGNE, at, yaw, length * 0.85, box.size.y * 0.05)
		_letters(METIER, at, yaw, length * 0.65, -box.size.y * 0.12)
	# À l'arrière : la plaque et la route, sur les deux battants.
	var back := Vector3(box.end.x + 0.004, h, mid.z) if long_x else Vector3(mid.x, h, box.position.z - 0.004)
	var back_yaw := 90.0 if long_x else 180.0
	_letters(ROUTE, back, back_yaw, width * 0.8, 0.0)
	_letters(PLAQUE, back, back_yaw, width * 0.4, -box.size.y * 0.3, Color(0.95, 0.95, 0.9))


func _letters(text: String, at: Vector3, yaw: float, span: float, dy: float, color := OR) -> void:
	var l := Label3D.new()
	l.text = text
	if _font:
		l.font = _font
	l.font_size = 96
	l.outline_size = 0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.modulate = color
	l.double_sided = false
	# Largeur visée : `span` en mètres, à peu près 0,6 caractère par point de police.
	l.pixel_size = span / maxf(1.0, text.length() * 96.0 * 0.72)
	l.position = at + Vector3(0, dy, 0)
	l.rotation_degrees.y = yaw
	van.add_child(l)


## La carrosserie passe au noir laqué. Le Car Kit de Kenney peint tout d'une même planche de
## couleurs : on teinte la planche de la caisse (vitres et feux restent plus sombres que la tôle),
## et on laisse les roues telles quelles.
static func _lacquer(n: Node) -> void:
	for c in n.get_children():
		_lacquer(c)
	var mi := n as MeshInstance3D
	if mi == null or mi.mesh == null or str(mi.name).begins_with("wheel"):
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s) as BaseMaterial3D
		if m == null:
			continue
		var paint := m.duplicate() as BaseMaterial3D
		paint.albedo_color = NOIR * 3.5 if m.albedo_texture else NOIR
		paint.albedo_color.a = 1.0
		paint.metallic = 0.3
		paint.roughness = 0.25
		mi.set_surface_override_material(s, paint)


## La boîte du van dans son propre repère (sans sa rotation ni son échelle sur la placette).
func _local_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (inv * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
