extends Control
## Le plan cadastral de l'étude de Maître Garnier : la place de la Mairie et le début du chemin de
## Passelourdin, vus d'en haut, avec chaque bien du registre posé sur son bâtiment (le café pour la
## Smarvoise, la boulangerie pour le fournil, la maison verte pour la maison de maître…). Un lot se
## touche ou se clique pour ouvrir sa fiche. Couleurs : à vendre, à vous, pas encore cédé.

signal picked(id: String)

## Le plan est un schéma, comme celui de l'agence Lacroix d'Addict Casino : les bâtiments gardent leur
## place autour de la place de la Mairie, mais chaque case est assez grande pour son nom et son prix.
## Tout est dessiné sur un papier de DESIGN unités, mis à l'échelle de la fenêtre.
const DESIGN := Vector2(1000.0, 620.0)
const SQUARE := Rect2(150, 120, 710, 400)
const ROAD := Rect2(0, 530, 1000, 70)
const CHEMIN := Rect2(470, 0, 60, 120)
## Les bâtiments qui ne se vendent pas, pour s'y retrouver : [nom, case].
const MARKS := [
	["Mairie", Rect2(390, 140, 130, 80)],
	["Église", Rect2(540, 140, 110, 80)],
	["Banque", Rect2(680, 400, 160, 70)],
]
## Les biens du registre sur le plan : id du catalogue → [nom du lieu, case].
const LOTS := {
	"maison_place": ["Maison de maître", Rect2(170, 135, 190, 80)],
	"chambre": ["La chambre", Rect2(170, 230, 190, 80)],
	"smarvoise": ["Café de la Place", Rect2(170, 325, 190, 80)],
	"comite": ["Salle Rabelais", Rect2(170, 420, 190, 80)],
	"casino": ["Casino", Rect2(680, 135, 160, 110)],
	"fournil": ["Boulangerie", Rect2(680, 265, 160, 110)],
	"maison": ["Rue de l'Église", Rect2(250, 15, 190, 85)],
	# Le Moulin des Dames est au bout de la rue du Clain, à l'ouest, par la route.
	"cotes": ["← Moulin des Dames", Rect2(10, 535, 220, 75)],
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
	return minf(size.x / DESIGN.x, size.y / DESIGN.y)


func _box(r: Rect2) -> Rect2:
	var k := _k()
	var off := (size - DESIGN * k) / 2.0
	return Rect2(off + r.position * k, r.size * k)


## La zone qu'on touche : le lot, grossi jusqu'à 48 px s'il est plus petit.
func _target(id: String) -> Rect2:
	var r := _box(LOTS[id][1])
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
	draw_rect(_box(SQUARE), Color(0.88, 0.84, 0.74))
	draw_rect(_box(ROAD), Color(0.72, 0.7, 0.66))
	draw_rect(_box(CHEMIN), Color(0.86, 0.82, 0.7))
	_fit("La place de la Mairie", _box(Rect2(390, 240, 270, 280)), 24, INK_LIGHT)
	_fit("Route de Poitiers", _box(Rect2(260, 540, 600, 50)), 22, INK_LIGHT)
	_fit("Chemin de Passelourdin ↑", _box(Rect2(545, 20, 300, 60)), 22, INK_LIGHT, false)
	for m in MARKS:
		var r := _box(m[1])
		draw_rect(r, Color(0.78, 0.74, 0.66))
		draw_rect(r, Color(0.45, 0.32, 0.18, 0.6), false, 1.0)
		_fit(m[0], r, 21, INK_LIGHT)
	for id in LOTS:
		_lot(id)


func _lot(id: String) -> void:
	var r := _box(LOTS[id][1])
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
	# Le nom en haut, le prix ou l'état en bas, chacun dans sa moitié de case.
	var half := Vector2(r.size.x, r.size.y / 2.0)
	_fit(LOTS[id][0], Rect2(r.position + Vector2(0, r.size.y * 0.06), half), 25, INK)
	_fit(line, Rect2(r.position + Vector2(0, r.size.y * 0.44), half), 23, INK if state != "ferme" else INK_LIGHT)


## Un texte dans sa case : la taille suit l'échelle du plan, et rapetisse s'il le faut pour ne jamais déborder.
func _fit(t: String, r: Rect2, design_fs: int, color: Color, centered := true) -> void:
	var fs := maxi(int(design_fs * _k()), 10)
	var pad := 6.0
	while fs > 9 and (_font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - pad * 2.0 or _font.get_height(fs) > r.size.y):
		fs -= 1
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := r.get_center().x - w / 2.0 if centered else r.position.x + pad
	var y := r.get_center().y - _font.get_height(fs) / 2.0 + _font.get_ascent(fs)
	draw_string(_font, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
