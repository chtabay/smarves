extends Node
## La page de Smarves dans le carnet du joueur (scripts/carnet.gd) : l'onglet de la commune d'origine,
## que son manifeste désigne (« page_carnet »). On y tient ce qui s'achète et se vit au village : les
## biens et la dernière recette, le logement, le plan du village qui se dessine en marchant, les
## adresses et la tournée au café. Ce qui suit le joueur partout (crédits, dettes, fortune) est sur
## l'onglet « Mon compte », tenu par le socle.

## Le plan du village : ses quartiers et ses lieux cachés (docs/VILLAGE.md, « Pour le plan du Carnet »).
const VILLAGE := preload("res://scripts/village/village.gd")
## La part de la maquette que couvre le plan, en mètres (x, z) : du Moulin au bois, des rochers à la route.
const PLAN_WORLD := Rect2(-82.0, -79.0, 164.0, 95.0)

## Le carnet, qui tient la page et ses façons d'écrire.
var carnet = null


func _ready() -> void:
	# Le village n'est pas un autoload : on se branche sur lui quand la place se monte.
	get_tree().node_added.connect(_on_node_added)


## Les deux pages de l'onglet.
func remplir(gauche: VBoxContainer, droite: VBoxContainer) -> void:
	_fill_biens(gauche)
	_fill_logement(gauche)
	_fill_recette(gauche)
	_fill_par_recette(droite)
	_fill_plan(droite)
	_fill_adresses(droite)


## La feuille dépliée qui revient à Smarves : le plan du village. Faux pour une autre feuille.
func feuille(box: VBoxContainer, mode: String) -> bool:
	if mode != "plan":
		return false
	_fill_sheet_plan(box)
	return true


## « Mes cartes ici » : les cartes qu'on tient au village, en petit (un clic ouvre le classeur dessus),
## ce qu'on porte et ce qu'on conduit, et le chemin de l'étude pour acheter autre chose.
func _fill_biens(page: VBoxContainer) -> void:
	var c = carnet
	c._title(page, "Mes cartes ici")
	c._gap(page, 4)
	var o: Commune = Communes.origine()
	if c._album.vignettes(page, o.id if o != null else "", 0.42, 6) == 0:
		c._text(page, "Rien encore. Maître Garnier a des parts de la Smarvoise à 200, et Josiane dit que c'est le placement du siècle.", 18, c.INK_LIGHT)
	else:
		var bas := func(t: String) -> String: return t.left(1).to_lower() + t.substr(1)
		var porte := []
		if Biens.worn != "":
			porte.append("vous portez %s" % bas.call(Biens.name_of(Biens.worn)))
		if Biens.driven != "":
			porte.append("au garage de la place, %s" % bas.call(Biens.name_of(Biens.driven)))
		if not porte.is_empty():
			var t := "; ".join(porte)
			c._text(page, t.left(1).to_upper() + t.substr(1) + ".", 16, c.INK_LIGHT)
	c._text(page, "Pour acheter autre chose, Maître Garnier, à l'étude.", 16, c.PENCIL)
	if Biens.SELLERS.has("notaire"):
		c._link(page, "→ aller chez le notaire", go_to.bind("notaire"))
	c._link(page, "→ ouvrir mes cartes", c.ouvrir_onglet.bind("cartes"))


## « Mon logement » : où l'on dort, et pour chaque maison les deux colonnes, louée ou habitée.
func _fill_logement(page: VBoxContainer) -> void:
	var c = carnet
	c._gap(page)
	c._title(page, "Mon logement")
	var home := Biens.habite()
	c._text(page, "Adresse : %s" % (Biens.item(home).name if home != "" else "l'hôtel du casino, chez Monsieur Armand"), 18, c.INK)
	for it in Biens.catalogue():
		if not Biens.logements.has(it.id):
			continue
		var lived := Biens.is_habite(it.id)
		c._text(page, "%s  (%s)" % [it.name, "habitée" if lived else "louée"], 18, c.INK, true)
		c._row(page, "louée : rente annoncée", Game.fmt(it.rente), c.INK_LIGHT)
		c._row(page, "habitée : standing", "+%d" % (it.standing * 2), c.INK_LIGHT)
		var furnished := Biens.meubles_value(it.id)
		c._row(page, "estimation, meubles compris", Game.fmt(int(round(it.price * Biens.RESALE)) + furnished), c.INK_LIGHT)
		if lived:
			c._link(page, "→ la remettre en location", Biens.louer.bind(it.id))
		else:
			c._link(page, "→ m'y installer", Biens.habiter.bind(it.id))
		var here := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		c._link(page, "→ y aller", _go_home.bind(it.id), not (here == Biens.LOGEMENT_SCENE and Biens.visiting == it.id))
		if c._amenage != it.id:
			c._link(page, "→ l'aménager  (%d meubles posés)" % Biens.logements[it.id].meubles.size(), _set_amenage.bind(it.id))
			continue
		c._link(page, "→ fermer le plan", _set_amenage.bind(""))
		var room := ""
		for sl in Biens.slots(it.id):
			if sl.piece != room:
				room = sl.piece
				c._text(page, room, 17, c.INK, true)
			var cur := str(Biens.logements[it.id].meubles.get(sl.id, ""))
			var can := cur != "" or not Biens.posables(sl.genre).is_empty()
			c._link(page, "%s : %s" % [sl.label.trim_prefix(room + ", "), Biens.name_of(cur) if cur != "" else "—"], _cycle.bind(it.id, sl), can)
	var loose: Array = Biens.trouvailles.filter(func(t): return Biens.free_count(t) > 0)
	if not loose.is_empty():
		c._text(page, "Dans le carton : " + ", ".join(loose.map(func(t): return Biens.name_of(t))), 16, c.INK_LIGHT)


func _fill_recette(page: VBoxContainer) -> void:
	var c = carnet
	c._gap(page)
	c._title(page, "La dernière recette")
	if Biens.recettes == 0:
		c._text(page, "Toutes les 20 mises. Pas encore de recette.", 17, c.INK_LIGHT)
		return
	var anim := "recette pleine" if Biens.last_animation >= 0.99 else "village animé à %d %%" % int(Biens.last_animation * 100)
	c._text(page, "Recette n° %d, %s." % [Biens.recettes, anim], 17, c.INK_LIGHT)
	for r in Biens.last_recette:
		c._row(page, r[0], "%s  (annoncé %s)" % [Game.fmt(r[1]), Game.fmt(r[2])], c.INK_LIGHT)
	c._row(page, "Net de la recette", Game.fmt(Biens.last_net), c.INK, true)


## Ce que les biens font à chaque recette, et le standing qu'ils donnent.
func _fill_par_recette(page: VBoxContainer) -> void:
	var c = carnet
	c._title(page, "À chaque recette")
	c._gap(page, 6)
	c._row(page, "Rente annoncée", Game.fmt(Biens.rente_annoncee()), c.INK_LIGHT)
	c._row(page, "Charges", Game.fmt(Biens.charges()), c.INK_LIGHT)
	c._row(page, "Standing", str(Biens.standing()), c.INK_LIGHT)
	if Biens.reprises > 0:
		c._row(page, "Biens repris par M. Brunet", str(Biens.reprises), c.INK_LIGHT)


func _fill_adresses(page: VBoxContainer) -> void:
	var c = carnet
	c._gap(page)
	c._title(page, "Adresses")
	var here := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	for id in Biens.SELLERS:
		var s: Dictionary = Biens.SELLERS[id]
		c._link(page, "%s  →  y aller" % s.name, go_to.bind(id), here != s.scene)
	var on_square := here == "res://scenes/main.tscn"
	var tl: Button = c._link(page, "Offrir une tournée générale au café  (%s)" % Game.fmt(Biens.tournee_price()), _tournee, on_square and Game.credits >= Biens.tournee_price())
	if not on_square:
		tl.tooltip_text = "Au Café de la Place."


func _go_home(id: String) -> void:
	if carnet.is_open():
		carnet.toggle()
	Biens.enter(id)


func _set_amenage(id: String) -> void:
	carnet._amenage = id
	carnet._refresh()


func _cycle(home: String, sl: Dictionary) -> void:
	Biens.cycle(home, sl.id)


func go_to(id: String) -> void:
	if carnet.is_open():
		carnet.toggle()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().change_scene_to_file(Biens.SELLERS[id].scene)


func _tournee() -> void:
	if Biens.offer_tournee():
		if carnet.is_open():
			carnet.toggle()
		carnet.show_slip("Tournée générale ! Josiane remplit les verres : « Voilà un investisseur qui sait vivre. »")
		var scene := get_tree().current_scene
		var people = scene.get("villagers") if scene else null
		if people != null:
			for v in people:
				if v.critter and v.global_position.x < -2.0:
					v.critter.cheer(2.5)


# --- Le plan du village -------------------------------------------------------------------------

## Le plan se dessine en marchant : chaque quartier où l'on a mis les pieds, et les lieux cachés trouvés.
## Ils sont rangés dans le tiroir de Smarves (socle commune), pas avec les biens.
func tiroir() -> Dictionary:
	return Game.tiroir(Communes.ORIGINE)


func zones_vues() -> Array:
	return tiroir().get("zones", [])


func caches_trouvees() -> Array:
	var found: Array = tiroir().get("caches", []).duplicate()
	# Une affiche trouvée avant que le carnet ne tienne le plan : la cabane est déjà connue.
	if Biens.trouvailles.has("affiche_loto_1987") and not found.has("cabane_vigne"):
		found.append("cabane_vigne")
	return found


func _on_node_added(node: Node) -> void:
	# Le village de l'écran titre rentre dans l'arbre une seconde fois quand on appuie sur Jouer.
	if node.get_script() == VILLAGE and not node.zone_entered.is_connected(_on_zone_entered):
		node.zone_entered.connect(_on_zone_entered)
		node.cache_found.connect(_on_cache_found)


func _on_zone_entered(id: String) -> void:
	if _note_on_plan("zones", id) and id != "place":
		var nom := str(VILLAGE.ZONES[id].nom)
		carnet.show_slip("Au plan du carnet : %s." % (nom.left(1).to_lower() + nom.substr(1)))


func _on_cache_found(id: String) -> void:
	_note_on_plan("caches", id)


## Ajoute au plan ; vrai si c'est nouveau.
func _note_on_plan(key: String, id: String) -> bool:
	var t := tiroir()
	var list: Array = t.get(key, [])
	if list.has(id):
		return false
	list.append(id)
	t[key] = list
	Game.save_game()
	if carnet.is_open():
		carnet._refresh()
	return true


## Sur la page de droite : où en est le plan, et de quoi le déplier.
func _fill_plan(page: VBoxContainer) -> void:
	var c = carnet
	c._gap(page)
	c._title(page, "Le plan du village")
	c._text(page, _plan_progress(), 16, c.INK_LIGHT)
	c._link(page, "→ déplier le plan", c._show_sheet.bind(true, "plan")).custom_minimum_size.y = 48


func _plan_progress() -> String:
	var left := VILLAGE.ZONES.size() - zones_vues().size()
	if zones_vues().is_empty():
		return "Une page blanche. Sortir sur la place pour commencer le plan."
	if left > 0:
		return "Encore %d %s à parcourir." % [left, "quartier" if left == 1 else "quartiers"]
	return "Tout le village est au plan."


## La feuille dépliée : le plan sur toute la largeur, et de quoi revenir au carnet.
func _fill_sheet_plan(box: VBoxContainer) -> void:
	var c = carnet
	c._sheet.custom_minimum_size = Vector2(1148, 728)
	c._title(box, "Le plan du village")
	var plan := Plan.new()
	plan.font = c._hand
	plan.zones = zones_vues()
	plan.caches = caches_trouvees()
	var scene := get_tree().current_scene
	var player = scene.get("player") if scene and scene.scene_file_path == "res://scenes/main.tscn" else null
	if player is Node3D:
		plan.here = Vector2(player.global_position.x, player.global_position.z)
		plan.show_here = true
	plan.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(plan)
	var foot := HBoxContainer.new()
	box.add_child(foot)
	var t: Label = c._text(foot, _plan_progress(), 17, c.INK_LIGHT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c._link(foot, "← revenir au carnet", c._show_sheet.bind(false, "plan")).custom_minimum_size = Vector2(220, 48)


## Le plan au crayon : les quartiers parcourus en lavis, leurs noms, les lieux cachés d'une croix rouge.
class Plan extends Control:
	var font: Font
	var zones: Array = []
	var caches: Array = []
	var here := Vector2.ZERO
	var show_here := false

	func _to_page(p: Vector2) -> Vector2:
		var k := minf(size.x / PLAN_WORLD.size.x, size.y / PLAN_WORLD.size.y)
		var off := (size - PLAN_WORLD.size * k) / 2.0
		return off + (p - PLAN_WORLD.position) * k

	func _draw() -> void:
		var pencil := Color(0.38, 0.36, 0.34)
		for id in zones:
			if not VILLAGE.ZONES.has(id):
				continue
			var r: Rect2 = VILLAGE.ZONES[id].rect
			var a := _to_page(r.position)
			var b := _to_page(r.end)
			var box := Rect2(a, b - a)
			draw_rect(box, Color(0.55, 0.68, 0.85, 0.22))
			draw_rect(box, Color(0.12, 0.2, 0.5, 0.8), false, 1.5)
			_label(str(VILLAGE.ZONES[id].nom), box)
		for id in caches:
			if not VILLAGE.CACHES.has(id):
				continue
			var c: Dictionary = VILLAGE.CACHES[id]
			var p := _to_page(Vector2(c.pos.x, c.pos.z))
			var red := Color(0.7, 0.12, 0.12)
			draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), red, 3.0)
			draw_line(p + Vector2(-7, 7), p + Vector2(7, -7), red, 3.0)
			_ink(str(c.nom), p + Vector2(11, 6), 18, red)
		if show_here:
			var h := _to_page(here)
			draw_circle(h, 7.0, Color(0.12, 0.2, 0.5))
			_ink("vous êtes ici", h + Vector2(11, 22), 18, pencil)

	## Le nom du quartier, coupé en deux lignes s'il déborde de son rectangle.
	func _label(t: String, box: Rect2) -> void:
		var ink := Color(0.12, 0.2, 0.5)
		var fs := 18
		var lines := [t]
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > box.size.x - 6:
			var words := t.split(" ")
			var cut := words.size() / 2
			lines = [" ".join(words.slice(0, cut)), " ".join(words.slice(cut))]
		# En haut du quartier (le milieu est souvent pris par « vous êtes ici »), et toujours dans la feuille.
		var lh := font.get_height(fs)
		var widths := lines.map(func(l): return font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var top := clampf(box.position.y + 4.0, 4.0, size.y - lh * lines.size() - 4.0)
		for i in lines.size():
			var x := clampf(box.get_center().x - widths[i] / 2.0, 4.0, size.x - widths[i] - 4.0)
			_paper(Rect2(x - 3.0, top + i * lh, widths[i] + 6.0, lh))
		for i in lines.size():
			var x := clampf(box.get_center().x - widths[i] / 2.0, 4.0, size.x - widths[i] - 4.0)
			draw_string(font, Vector2(x, top + i * lh + font.get_ascent(fs)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

	## Un mot au crayon sur un fond de papier, pour qu'il se lise par-dessus les traits ; at est le pied du mot.
	func _ink(t: String, at: Vector2, fs: int, color: Color) -> void:
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(clampf(at.x, 4.0, size.x - w - 4.0), clampf(at.y, font.get_ascent(fs) + 4.0, size.y - font.get_descent(fs) - 4.0))
		_paper(Rect2(p.x - 3.0, p.y - font.get_ascent(fs), w + 6.0, font.get_height(fs)))
		draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

	func _paper(r: Rect2) -> void:
		draw_rect(r, Color(0.97, 0.95, 0.88, 0.85))
