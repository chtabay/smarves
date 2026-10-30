extends Control
## Le plan de l'étude du notaire, dessiné depuis le registre de la commune (scripts/socle/notaire.gd) :
## un onglet par quartier, chaque adresse posée sur son papier à sa place et à sa largeur. Un quartier
## « plan » montre ses bâtiments avec leur nom et leur prix ; un quartier « rue » montre ses façades
## numérotées des deux côtés. Une adresse se touche ou se clique pour ouvrir sa fiche. Couleurs : à vendre,
## à vous, pas encore cédé. Rien ici n'est propre à Smarves.

signal picked(id: String)
## Le plan change de quartier (un onglet, ou le bout d'une rue).
signal quartier_changed(id: String)

const NOTAIRE := preload("res://scripts/socle/notaire.gd")
## Tout est dessiné sur un papier de cette taille, mis à l'échelle de la fenêtre.
const DESIGN := NOTAIRE.PAPIER
## Une cible qu'on touche du doigt fait au moins 48 px de côté.
const MIN_TARGET := 48.0

const INK := Color(0.12, 0.14, 0.3)
const INK_LIGHT := Color(0.32, 0.32, 0.42)
const FOR_SALE := Color(0.98, 0.84, 0.45)
const MINE := Color(0.55, 0.78, 0.5)
const CLOSED := Color(0.82, 0.8, 0.75)
const TEINTES := {
	"place": Color(0.88, 0.84, 0.74), "route": Color(0.72, 0.7, 0.66), "chemin": Color(0.86, 0.82, 0.7),
	"jardin": Color(0.62, 0.72, 0.5), "cour": Color(0.8, 0.77, 0.7), "fond": Color(0.9, 0.87, 0.79),
}

## Le registre dessiné : celui de la commune en cours, sauf si on en donne un autre avant _ready.
var registre := {}
## La commune du registre (« » : la commune d'origine) : ses adresses sont au catalogue sous NOTAIRE.cle().
var commune := ""
var selected := ""
var quartier := ""
var _font: Font


func _ready() -> void:
	_font = Polices.texte()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if registre.is_empty():
		registre = NOTAIRE.registre(_c())
	if quartier == "" and not quartiers().is_empty():
		quartier = str(quartiers()[0].id)
	Biens.changed.connect(queue_redraw)
	Game.changed.connect(queue_redraw)


func _c() -> Commune:
	var c: Commune = Communes.commune(commune) if commune != "" else null
	return c if c != null else Commune.smarves()


func quartiers() -> Array:
	return registre.get("quartiers", [])


func select(id: String) -> void:
	selected = id
	queue_redraw()


func set_quartier(id: String) -> void:
	if _quartier(id).is_empty() or id == quartier:
		return
	quartier = id
	quartier_changed.emit(id)
	queue_redraw()


func _quartier(id: String) -> Dictionary:
	for q in quartiers():
		if str(q.id) == id:
			return q
	return {}


## Les adresses du quartier affiché.
func _lots() -> Array:
	var out := []
	for a in registre.get("adresses", []):
		if str(a.quartier) == quartier:
			out.append(a)
	return out


func _k() -> float:
	return minf(size.x / DESIGN.x, size.y / DESIGN.y)


func _box(r: Rect2) -> Rect2:
	var k := _k()
	var off := (size - DESIGN * k) / 2.0
	return Rect2(off + r.position * k, r.size * k)


## La zone qu'on touche : la case, grossie jusqu'à 48 px si elle est plus petite.
func _target(rect: Rect2) -> Rect2:
	var r := _box(rect)
	var gx := maxf(0.0, (MIN_TARGET - r.size.x) / 2.0)
	var gy := maxf(0.0, (MIN_TARGET - r.size.y) / 2.0)
	return r.grow_individual(gx, gy, gx, gy)


## Ce que montre une adresse : à vendre (prix), à vous, ou pas encore cédé.
static func state_of(id: String) -> String:
	var it: Dictionary = Biens.item(id)
	if it.is_empty() or Game.won < int(it.gate):
		return "ferme"
	if it.kind == "club":
		# Les obligations du club : à vous dès qu'on y a mis quelque chose, à prendre sinon.
		var f: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Football")
		return "a_vous" if f != null and int(f.investi(str(it.club))) > 0 else "vente"
	if Biens.available(id):
		return "vente"
	return "a_vous"


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for a in _lots():
		if _target(a.rect).has_point(event.position):
			select(str(a.id))
			picked.emit(str(a.id))
			accept_event()
			return
	# Le bout d'une rue mène à un autre quartier.
	for l in _quartier(quartier).get("liens", []):
		if _target(l.rect).has_point(event.position):
			set_quartier(str(l.vers))
			accept_event()
			return


func _draw() -> void:
	var q := _quartier(quartier)
	if q.is_empty():
		return
	for d in q.decor:
		var c: Color = TEINTES.get(d.teinte, TEINTES.place)
		if d.forme == "rond":
			var b := _box(Rect2(d.centre - Vector2.ONE * d.rayon, Vector2.ONE * d.rayon * 2.0))
			draw_circle(b.get_center(), b.size.x / 2.0, c)
		else:
			draw_rect(_box(d.rect), c)
	for t in q.textes:
		_fit(t.texte, _box(t.rect), t.taille, INK_LIGHT, t.centre)
	for l in q.liens:
		var r := _box(l.rect)
		draw_rect(r, TEINTES.chemin)
		draw_rect(r, Color(0.45, 0.32, 0.18), false, 1.5)
		_fit(l.texte, r, 22, INK)
	var street: bool = q.style == "rue"
	for a in _lots():
		_lot(a, street)


func _lot(a: Dictionary, street: bool) -> void:
	var id := NOTAIRE.cle_adresse(_c(), a)
	var r := _box(a.rect)
	var state := state_of(id)
	var fill: Color = {"vente": FOR_SALE, "a_vous": MINE, "ferme": CLOSED}[state]
	if state == "vente" and Biens.count(id) > 0:
		fill = FOR_SALE.lerp(MINE, 0.45)
	draw_rect(r, fill)
	var sel := str(a.id) == selected
	draw_rect(r, Color(0.65, 0.12, 0.08) if sel else Color(0.45, 0.32, 0.18), false, 3.0 if sel else 1.5)
	var line := ""
	var it: Dictionary = Biens.item(id)
	if it.get("kind", "") == "club" and state != "ferme":
		var f: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Football")
		var inv: int = int(f.investi(str(it.club))) if f != null else 0
		line = "%s cr. placés" % Game.fmt(inv) if inv > 0 else "obligations"
	else:
		match state:
			"vente":
				line = "%s cr." % Game.fmt(Biens.next_price(id))
				if Biens.count(id) > 0:
					line = "×%d · %s" % [Biens.count(id), line]
			"a_vous":
				line = "à vous" if Biens.count(id) <= 1 else "à vous ×%d" % Biens.count(id)
			"ferme":
				line = "pas encore"
	if street and int(a.numero) > 0:
		_street_label(str(a.numero), str(a.etiquette), line, r, state)
		return
	# Le nom en haut, le prix ou l'état en bas, chacun dans sa moitié de case.
	var half := Vector2(r.size.x, r.size.y / 2.0)
	_fit(str(a.etiquette), Rect2(r.position + Vector2(0, r.size.y * 0.06), half), 25, INK)
	_fit(line, Rect2(r.position + Vector2(0, r.size.y * 0.44), half), 23, INK if state != "ferme" else INK_LIGHT)


## Une façade de la rue, souvent étroite : le numéro, en grand ; l'enseigne en dessous, couchée le long de
## la façade quand la case est plus haute que large ; le prix, s'il tient.
func _street_label(num: String, nom: String, line: String, r: Rect2, state: String) -> void:
	_fit(num, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.3)), 30, INK)
	var rest := Rect2(r.position + Vector2(0, r.size.y * 0.3), Vector2(r.size.x, r.size.y * 0.7))
	var lines: Array[String] = []
	if nom != "":
		lines.append(nom)
	lines.append(line)
	if rest.size.y > rest.size.x * 1.3:
		# Couché : on écrit le long de la case, de bas en haut, comme sur un plan cadastral.
		draw_set_transform(rest.get_center(), -PI / 2.0)
		var turned := Rect2(-rest.size.y / 2.0, -rest.size.x / 2.0, rest.size.y, rest.size.x)
		_lines(lines, turned, state)
		draw_set_transform(Vector2.ZERO)
	else:
		_lines(lines, rest, state)


func _lines(lines: Array[String], r: Rect2, state: String) -> void:
	var h := r.size.y / lines.size()
	for i in lines.size():
		var last := i == lines.size() - 1
		_fit(lines[i], Rect2(r.position + Vector2(0, h * i), Vector2(r.size.x, h)), 20 if last else 22, INK_LIGHT if last and state == "ferme" else INK)


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


# --- Pour le pilote d'un pensionnaire (scripts/socle/pilote.gd) -------------------------------------

## Le nom d'une adresse, tel qu'on le lit sur le plan : son enseigne, précédée du numéro dans une rue.
func _nom_lot(a: Dictionary) -> String:
	var nom := str(a.etiquette).strip_edges()
	if _style() == "rue" and int(a.get("numero", 0)) > 0:
		nom = ("%s %s" % [a.numero, nom]).strip_edges()
	return nom if nom != "" else str(a.id)


func _style() -> String:
	return str(_quartier(quartier).get("style", ""))


## Les adresses du quartier affiché, par leur nom, et les bouts de rue qui mènent ailleurs : chacune se
## clique comme du doigt.
func pilote_cases() -> Dictionary:
	var out := {}
	for a in _lots():
		var nom := _nom_lot(a)
		if out.has(nom):
			nom = "%s (%s)" % [nom, a.id]
		out[nom] = _target(a.rect)
	for l in _quartier(quartier).get("liens", []):
		var t := str(l.texte).strip_edges()
		if t != "" and not out.has(t):
			out[t] = _target(l.rect)
	return out


## Ce que montre le plan, en mots : chaque adresse, son état et son prix.
func pilote_texte() -> String:
	var q := _quartier(quartier)
	if q.is_empty():
		return ""
	var lignes := ["Plan : %s." % str(q.get("nom", quartier))]
	for a in _lots():
		var id := NOTAIRE.cle_adresse(_c(), a)
		var etat := ""
		match state_of(id):
			"vente":
				etat = "à vendre, %s cr." % Game.fmt(Biens.next_price(id))
			"a_vous":
				etat = "à vous"
			"ferme":
				etat = "pas encore cédé"
		lignes.append("%s : %s" % [_nom_lot(a), etat])
	return "\n".join(lignes)
