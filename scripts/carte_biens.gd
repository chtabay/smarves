extends Control
## Le plan cadastral de l'étude de Maître Garnier : la place de la Mairie et le début du chemin de
## Passelourdin, vus d'en haut, avec chaque bien du registre posé sur son bâtiment (le café pour la
## Smarvoise, la boulangerie pour le fournil, la maison verte pour la maison de maître…). Un lot se
## touche ou se clique pour ouvrir sa fiche. Couleurs : à vendre, à vous, pas encore cédé.

signal picked(id: String)

## La part du monde dessinée, en mètres (x, z) : la place, la route, et le bas du chemin. La maison de la
## rue de l'Église est rapprochée de la place (elle est en vrai à z = -13,5) pour garder un plan large.
const WORLD := Rect2(-12.0, -12.4, 24.0, 20.4)
## Les bâtiments qui ne se vendent pas, pour s'y retrouver : [nom, centre (x, z), taille (x, z)].
const MARKS := [
	["Mairie", Vector2(-4.6, -5.8), Vector2(3.0, 2.6)],
	["Église", Vector2(0.4, -6.0), Vector2(3.4, 3.0)],
	["Banque", Vector2(9.0, 3.8), Vector2(2.6, 3.0)],
]
## Les biens du registre sur le plan : id du catalogue → [nom du lieu, centre (x, z), taille (x, z)].
const LOTS := {
	"smarvoise": ["Café de la Place", Vector2(-8.8, -0.2), Vector2(3.0, 3.4)],
	"chambre": ["La chambre", Vector2(-8.8, -2.9), Vector2(3.0, 1.6)],
	"maison_place": ["Maison de maître", Vector2(-8.6, -5.8), Vector2(3.0, 2.6)],
	"comite": ["Salle Rabelais", Vector2(-9.0, 3.5), Vector2(2.6, 3.0)],
	"casino": ["Casino", Vector2(6.4, -6.0), Vector2(5.2, 3.2)],
	"fournil": ["Boulangerie", Vector2(9.0, -1.2), Vector2(2.6, 3.0)],
	# Le Moulin des Dames est au bout de la rue du Clain, à l'ouest : son lot est posé au départ de la route.
	"cotes": ["Moulin des Dames ←", Vector2(-9.6, 6.6), Vector2(3.6, 2.0)],
	"maison": ["Rue de l'Église", Vector2(-4.2, -10.6), Vector2(3.4, 2.6)],
}
## Une cible qu'on touche du doigt fait au moins 48 px de côté.
const MIN_TARGET := 48.0

const INK := Color(0.12, 0.14, 0.3)
const INK_LIGHT := Color(0.32, 0.32, 0.42)
const FOR_SALE := Color(0.98, 0.84, 0.45)
const MINE := Color(0.55, 0.78, 0.5)
const CLOSED := Color(0.82, 0.8, 0.75)

var selected := ""
var _font: Font


func _ready() -> void:
	_font = Polices.texte()
	mouse_filter = Control.MOUSE_FILTER_STOP
	Biens.changed.connect(queue_redraw)
	Game.changed.connect(queue_redraw)


func select(id: String) -> void:
	selected = id
	queue_redraw()


func _k() -> float:
	return minf(size.x / WORLD.size.x, size.y / WORLD.size.y)


func _to_map(p: Vector2) -> Vector2:
	var k := _k()
	var off := (size - WORLD.size * k) / 2.0
	return off + (p - WORLD.position) * k


func _box(center: Vector2, extent: Vector2) -> Rect2:
	var a := _to_map(center - extent / 2.0)
	return Rect2(a, extent * _k())


## La zone qu'on touche : le lot, grossi jusqu'à 48 px s'il est plus petit.
func _target(id: String) -> Rect2:
	var r := _box(LOTS[id][1], LOTS[id][2])
	return r.grow_individual(maxf(0.0, (MIN_TARGET - r.size.x) / 2.0), maxf(0.0, (MIN_TARGET - r.size.y) / 2.0),
		maxf(0.0, (MIN_TARGET - r.size.x) / 2.0), maxf(0.0, (MIN_TARGET - r.size.y) / 2.0))


## Ce que montre un lot : à vendre (prix), à vous, complet, ou pas encore cédé.
static func state_of(id: String) -> String:
	var it: Dictionary = Biens.item(id)
	if Game.won < int(it.gate):
		return "ferme"
	if Biens.available(id):
		return "vente"
	return "a_vous"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for id in LOTS:
			if _target(id).has_point(event.position):
				select(id)
				picked.emit(id)
				accept_event()
				return


func _draw() -> void:
	# La place, la route, le chemin qui monte vers Passelourdin.
	draw_rect(_box(Vector2(0, 0), Vector2(22.6, 16.6)), Color(0.88, 0.84, 0.74))
	draw_rect(_box(Vector2(0, 6.4), Vector2(24.0, 2.4)), Color(0.72, 0.7, 0.66))
	draw_rect(_box(Vector2(-1.0, -10.4), Vector2(2.0, 4.2)), Color(0.86, 0.82, 0.7))
	_text("La place de la Mairie", _to_map(Vector2(-2.8, 1.4)), 16, INK_LIGHT)
	_text("Route de Poitiers", _to_map(Vector2(-2.0, 6.9)), 14, INK_LIGHT)
	_text("Chemin de Passelourdin  ↑", _to_map(Vector2(0.3, -10.0)), 14, INK_LIGHT)
	for m in MARKS:
		var r := _box(m[1], m[2])
		draw_rect(r, Color(0.78, 0.74, 0.66))
		draw_rect(r, Color(0.45, 0.32, 0.18, 0.6), false, 1.0)
		_centered(m[0], r, 13, INK_LIGHT)
	for id in LOTS:
		_lot(id)


func _lot(id: String) -> void:
	var r := _box(LOTS[id][1], LOTS[id][2])
	var state := state_of(id)
	var fill: Color = {"vente": FOR_SALE, "a_vous": MINE, "ferme": CLOSED}[state]
	if state == "vente" and Biens.count(id) > 0:
		fill = FOR_SALE.lerp(MINE, 0.45)
	draw_rect(r, fill)
	var sel := id == selected
	draw_rect(r, Color(0.65, 0.12, 0.08) if sel else Color(0.45, 0.32, 0.18), false, 3.0 if sel else 1.5)
	var line := ""
	match state:
		"vente":
			line = "%s cr." % Game.fmt(Biens.next_price(id))
			if Biens.count(id) > 0:
				line = "×%d · %s" % [Biens.count(id), line]
		"a_vous":
			line = "à vous" if Biens.count(id) <= 1 else "à vous ×%d" % Biens.count(id)
		"ferme":
			line = "pas encore"
	var name: String = LOTS[id][0]
	var fs := 15
	var h := _font.get_height(fs)
	var top := r.get_center().y - h
	_centered(name, Rect2(r.position.x, top, r.size.x, h), fs, INK)
	_centered(line, Rect2(r.position.x, top + h, r.size.x, h), fs, INK if state != "ferme" else INK_LIGHT)


## Un mot centré dans un rectangle ; s'il est plus large, il déborde de part et d'autre, sur fond de papier.
func _centered(t: String, r: Rect2, fs: int, color: Color) -> void:
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := clampf(r.get_center().x - w / 2.0, 2.0, size.x - w - 2.0)
	var y := r.get_center().y - _font.get_height(fs) / 2.0 + _font.get_ascent(fs)
	if w > r.size.x - 4.0:
		draw_rect(Rect2(x - 3.0, y - _font.get_ascent(fs), w + 6.0, _font.get_height(fs)), Color(0.96, 0.93, 0.84, 0.9))
	draw_string(_font, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _text(t: String, at: Vector2, fs: int, color: Color) -> void:
	draw_string(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
