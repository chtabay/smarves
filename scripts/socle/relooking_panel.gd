extends PanelContainer
## Le panneau d'une prestation (Avatar) : à gauche le joueur tel qu'il sortira, qui tourne sur lui-même ;
## à droite ce qu'on retouche ici. Chez le couturier, la coiffeuse et le chirurgien, on essaie champ par
## champ (◀ ▶), chaque changement a son prix, et l'on paie le tout d'un coup ; à la salle de sport et au
## restaurant, on commande une formule, qui se paie et se voit tout de suite.
## Ouvert par Prestation.panneau(métier, options) (scripts/socle/prestation.gd) ou par la vitrine d'un
## commerce de tenues (scripts/shop_panel.gd).

signal closed
## Ce que dit le prestataire après un paiement ou un refus.
signal spoke(text: String)

const INK := Color(0.12, 0.14, 0.3)
const INK_LIGHT := Color(0.32, 0.32, 0.42)
const PAPER := Color(0.96, 0.93, 0.84)
const CRITTER := preload("res://scripts/critter.gd")

const MERCIS := {
	"couture": ["« Je vous ai repris la taille et changé les boutons. Vous ne vous reconnaîtrez pas, la banque non plus. »",
		"« Ça tombe comme il faut. Monsieur Armand va vous saluer le premier. »"],
	"coiffure": ["« Et voilà ! Un coup de laque, et vous passez au Salon privé sans carte. »",
		"« Ça vous rajeunit de dix ans. Et de dix pertes, avec un peu de chance. »"],
	"chirurgie": ["« L'opération s'est très bien passée. Évitez le soleil et les mauvaises cartes pendant huit jours. »",
		"« Personne ne vous reconnaîtra au casino. Pas même vos créanciers, c'est un avantage. »"],
}
const TROP_CHER := "« Il vous manque quelques crédits. Repassez après une bonne soirée, je garde votre fiche. »"

## « couture », « coiffure », « chirurgie », « sport », « restaurant » (Avatar.METIERS).
var metier := "couture"
## {nom, tenancier, tarif, formules} : le nom de la maison, qui tient la boutique, un multiplicateur des
## prix (1 : ceux de Smarves) et, pour le sport et le restaurant, les formules de la maison.
var options := {}

var _essai := {}
var _apercu: Node3D
var _tourne: Node3D
var _liste: VBoxContainer
var _total: Label
var _payer: Button
var _statut: Label
var _serif: Font
var _t := 0.0


func _ready() -> void:
	_serif = Polices.texte()
	_essai = Biens.avatar.duplicate()
	custom_minimum_size = Vector2(980, 640)
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.border_color = Color(0.45, 0.32, 0.18)
	st.set_border_width_all(2)
	st.set_corner_radius_all(3)
	st.set_content_margin_all(24)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 14
	add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_label(v, str(options.get("nom", Avatar.METIERS[metier].nom)), 28, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(v, _sous_titre(), 16, INK_LIGHT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := ColorRect.new()
	rule.color = Color(0.45, 0.32, 0.18, 0.6)
	rule.custom_minimum_size.y = 2
	v.add_child(rule)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	h.add_child(_vue())
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste.add_theme_constant_override("separation", 8)
	scroll.add_child(_liste)
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_theme_constant_override("separation", 12)
	v.add_child(bas)
	_total = _label(bas, "", 20, INK, true)
	_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _a_champs():
		_payer = _button("Payer", _on_payer)
		_payer.name = "Payer"
		bas.add_child(_payer)
		bas.add_child(_button("Tout remettre", _on_remettre))
	var partir := _button("Merci, au revoir  (Échap)", func(): closed.emit())
	partir.name = "Partir"
	bas.add_child(partir)
	_statut = _label(v, "", 15, INK_LIGHT)
	_statut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rafraichir()


func _sous_titre() -> String:
	var qui := str(options.get("tenancier", ""))
	match metier:
		"couture":
			return "Retouches sur la tenue que vous portez" + ("  ·  %s" % qui if qui != "" else "")
		"coiffure":
			return "Coupe, couleur, moustache" + ("  ·  %s" % qui if qui != "" else "")
		"chirurgie":
			return "Sur rendez-vous, opéré le soir même" + ("  ·  %s" % qui if qui != "" else "")
		"sport":
			return "On y perd des crans de corpulence" + ("  ·  %s" % qui if qui != "" else "")
		_:
			return "On y prend des crans de corpulence" + ("  ·  %s" % qui if qui != "" else "")


func _a_champs() -> bool:
	return Avatar.METIERS[metier].has("champs")


func _tarif() -> float:
	return clampf(float(options.get("tarif", 1.0)), 0.1, 100.0)


## Les formules de la maison (les siennes, sinon celles de Smarves), au tarif.
func formules() -> Array:
	var out: Array = []
	var f: Variant = options.get("formules")
	var liste: Array = f if f is Array and not (f as Array).is_empty() else Avatar.METIERS[metier].get("formules", [])
	for x in liste:
		if not x is Dictionary:
			continue
		var crans := clampi(int(x.get("poids", 0)), -7, 7)
		if crans == 0:
			continue
		out.append({"id": str(x.get("id", x.get("nom", ""))), "nom": str(x.get("nom", "")), "poids": crans,
			"prix": int(round(int(x.get("prix", 0)) * _tarif())), "dit": str(x.get("dit", ""))})
	return out


## Les champs qu'on retouche ici (la pilosité ne se propose qu'aux hommes).
func champs() -> Array:
	var out: Array = []
	for c in Avatar.METIERS[metier].get("champs", {}):
		if c == "pilosite" and Avatar.valeur(_essai, "sexe") == 1:
			continue
		out.append(c)
	return out


func prix_essai() -> int:
	return Avatar.prix(metier, Biens.avatar, _essai, _tarif())


## Essaie une autre valeur d'un champ (pas : +1 ou -1, en boucle).
func essayer(champ: String, pas: int) -> void:
	var b := Avatar.bornes(champ)
	var n := b.y - b.x + 1
	var v := Avatar.valeur(_essai, champ) - b.x
	_essai[champ] = b.x + posmod(v + pas, n)
	if champ == "sexe":
		# Une femme rasée de près, un homme sans rouge : la coupe suit si elle n'allait qu'à l'autre.
		var femme := Avatar.valeur(_essai, "sexe") == 1
		_essai.pilosite = 0 if femme else Avatar.valeur(Biens.avatar, "pilosite")
		_essai.coupe = Avatar.coupe_pour(Avatar.valeur(_essai, "coupe"), femme)
	_rafraichir()


func _on_remettre() -> void:
	_essai = Biens.avatar.duplicate()
	_rafraichir()


func _on_payer() -> void:
	var p := prix_essai()
	if p <= 0:
		return
	if not Biens.relooker(_essai, p):
		spoke.emit(TROP_CHER)
		return
	Sfx.play("chips", -6.0)
	spoke.emit((MERCIS.get(metier, MERCIS.couture) as Array).pick_random())
	_essai = Biens.avatar.duplicate()
	_rafraichir()


func commander(f: Dictionary) -> void:
	var avant := Avatar.valeur(Biens.avatar, "poids")
	var apres := clampi(avant + int(f.poids), Avatar.POIDS_MIN, Avatar.POIDS_MAX)
	if apres == avant:
		return
	if not Biens.corpulence(int(f.poids), int(f.prix)):
		spoke.emit(TROP_CHER)
		return
	Sfx.play("chips", -6.0)
	if str(f.dit) != "":
		spoke.emit(str(f.dit))
	_essai = Biens.avatar.duplicate()
	_rafraichir()


func _rafraichir() -> void:
	for c in _liste.get_children():
		c.queue_free()
	if _a_champs():
		for champ in champs():
			_ligne(champ)
		var p := prix_essai()
		_total.text = "À payer : %s crédits" % Game.fmt(p) if p > 0 else "Essayez, c'est gratuit : on ne paie que ce qu'on garde."
		_payer.text = "Payer %s crédits" % Game.fmt(p) if p > 0 else "Payer"
		_payer.disabled = p <= 0
		if metier == "couture":
			_label(_liste, "Les retouches du haut et du bas tiennent jusqu'au prochain changement de tenue ; le chapeau, le col et les lunettes restent.", 14, INK_LIGHT)
	else:
		var v := Avatar.valeur(Biens.avatar, "poids")
		_label(_liste, "Votre corpulence : %s." % Avatar.libelle("poids", v), 19, INK, true)
		for f in formules():
			_formule(f, v)
		_total.text = ""
	_statut.text = "Vos crédits : %s" % Game.fmt(Game.credits)
	if is_instance_valid(_apercu):
		_apercu.set_look(Avatar.fiche(str(Biens.worn), _essai))


func _ligne(champ: String) -> void:
	var row := HBoxContainer.new()
	row.name = champ
	row.add_theme_constant_override("separation", 8)
	_liste.add_child(row)
	var nom := _label(row, Avatar.LIBELLES.get(champ, champ), 17, INK)
	nom.custom_minimum_size.x = 210
	nom.autowrap_mode = TextServer.AUTOWRAP_OFF
	var moins := _button("◀", essayer.bind(champ, -1))
	moins.custom_minimum_size = Vector2(48, 44)
	row.add_child(moins)
	var v := Avatar.valeur(_essai, champ)
	var val := _label(row, Avatar.libelle(champ, v), 17, INK, true)
	val.custom_minimum_size.x = 200
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	var plus := _button("▶", essayer.bind(champ, 1))
	plus.custom_minimum_size = Vector2(48, 44)
	row.add_child(plus)
	var change := v != Avatar.valeur(Biens.avatar, champ)
	var prix := _label(row, "%s cr." % Game.fmt(Avatar.prix_champ(metier, champ, _tarif())), 16, INK if change else INK_LIGHT, change)
	prix.autowrap_mode = TextServer.AUTOWRAP_OFF
	prix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prix.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _formule(f: Dictionary, poids: int) -> void:
	var row := HBoxContainer.new()
	row.name = str(f.id)
	row.add_theme_constant_override("separation", 12)
	_liste.add_child(row)
	var g := VBoxContainer.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(g)
	_label(g, str(f.nom), 19, INK, true)
	var n := absi(int(f.poids))
	var effet := ("perdre %d cran%s" if f.poids < 0 else "prendre %d cran%s") % [n, "s" if n > 1 else ""]
	var apres := clampi(poids + int(f.poids), Avatar.POIDS_MIN, Avatar.POIDS_MAX)
	_label(g, "%s  ·  vous serez %s" % [effet, Avatar.libelle("poids", apres)] if apres != poids else
		"%s  ·  déjà au bout : %s" % [effet, Avatar.libelle("poids", poids)], 15, INK_LIGHT)
	_label(row, "%s crédits" % Game.fmt(int(f.prix)), 20, INK, true).autowrap_mode = TextServer.AUTOWRAP_OFF
	var b := _button("Commander" if metier == "restaurant" else "S'inscrire", commander.bind(f), apres != poids)
	b.custom_minimum_size = Vector2(130, 44)
	row.add_child(b)


## L'aperçu : le joueur tel qu'il sortira, dans un petit monde à lui, qui tourne lentement.
func _vue() -> Control:
	var box := SubViewportContainer.new()
	box.custom_minimum_size = Vector2(300, 420)
	box.stretch = true
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.88, 0.83, 0.72)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.88, 0.85)
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	var sol := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 0.42
	disque.bottom_radius = 0.42
	disque.height = 0.02
	sol.mesh = disque
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.36, 0.22)
	sol.material_override = m
	sol.position.y = -0.01
	vp.add_child(sol)
	var lum := DirectionalLight3D.new()
	lum.rotation_degrees = Vector3(-40, 30, 0)
	lum.light_energy = 1.1
	vp.add_child(lum)
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.position = Vector3(0, 0.5, 1.75)
	cam.look_at_from_position(cam.position, Vector3(0, 0.39, 0))
	vp.add_child(cam)
	_tourne = Node3D.new()
	vp.add_child(_tourne)
	_apercu = CRITTER.new()
	_apercu.look = Avatar.fiche(str(Biens.worn), _essai)
	_tourne.add_child(_apercu)
	return box


## Il se balance d'un trois-quarts à l'autre, le visage vers nous.
func _process(dt: float) -> void:
	_t += dt
	if is_instance_valid(_tourne):
		_tourne.rotation.y = sin(_t * 0.6) * 0.9


func _label(parent: Control, t: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Polices.gras() if bold else _serif)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(t: String, action: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.disabled = not enabled
	b.add_theme_font_override("font", _serif)
	b.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = {"normal": Color(0.9, 0.85, 0.72), "hover": Color(0.98, 0.9, 0.7), "pressed": Color(0.85, 0.75, 0.55),
			"disabled": Color(0.9, 0.88, 0.82), "focus": Color(0, 0, 0, 0)}[state]
		s.border_color = Color(0.45, 0.32, 0.18, 0.35 if state == "disabled" else 0.9)
		s.set_border_width_all(1)
		s.set_corner_radius_all(2)
		s.content_margin_left = 12
		s.content_margin_right = 12
		s.content_margin_top = 5
		s.content_margin_bottom = 5
		if state == "focus":
			s.draw_center = false
			s.border_color = Color(0, 0, 0, 0)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color(0.4, 0.1, 0.05))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.5))
	b.pressed.connect(action)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
