extends CanvasLayer
## L'écran de chargement d'une commune greffée (autoload « Chargement », socle 1.11). Il couvre
## l'arrivée dans une commune en pack, en avion comme en car ou au retour d'un de ses lieux, et montre
## où en est le chargement : une roue de roulette qui tourne, la bille qui court en sens inverse, des
## ampoules qui défilent autour du nom de la commune, et la barre de progression avec l'étape en cours.
##
## Trois temps, dans la barre :
## 1. le préchargement (jusqu'à 45 %) : le vol vers une destination lointaine lance dès le décollage la
##    lecture des ressources du paquet (modèles, textures, scripts, shaders) dans des fils à part
##    (precharger) : l'avion vole pendant que le paquet se lit, et ce qui est lu à l'atterrissage est
##    autant de moins à lire. On n'attend pas la fin : le reste se lit pendant que la scène se bâtit ;
## 2. la scène (jusqu'à 97 %) : si la scène de la commune expose `chargement` (de 0 à 1) et, si elle veut,
##    `chargement_etape` (une phrase), l'écran reste là tant qu'elle n'a pas fini, et elle peut se bâtir
##    en plusieurs images (await) pendant que l'écran s'anime (actif() le lui dit) ; sinon la scène se
##    bâtit d'un bloc ;
## 3. les premières images (97 à 100 %) : le moteur prépare ses shaders et envoie les textures à la
##    carte graphique derrière l'écran, qui s'efface ensuite.
## Les durées de chaque temps vont dans le journal du jeu (godot.log), pour comparer d'un PC à l'autre.

## La part de la barre prise par le préchargement, puis par la scène.
const PART_PRECHARGEMENT := 0.45
const PART_SCENE := 0.97
## Les images laissées au moteur derrière l'écran, la scène bâtie, avant de l'effacer.
const IMAGES_APRES := 4
const NUIT := Color(0.035, 0.03, 0.07)
const OR := Color(0.96, 0.8, 0.45)
const ROUGE := Color(0.72, 0.09, 0.13)
const NOIR := Color(0.09, 0.09, 0.11)
const VERT := Color(0.06, 0.48, 0.28)
const DOUX := Color(0.7, 0.72, 0.8)
## Ce qu'on lit pendant le préchargement, une phrase après l'autre.
const PHRASES := ["Les croupiers mettent leur nœud papillon…", "On cire le tapis vert…", "Les néons s'allument un à un…",
	"On compte les jetons de la caisse…", "Le voiturier gare les limousines…", "On accorde le piano du lounge…"]

## La commune en cours de préchargement ou de chargement (id), et ses ressources en lecture.
var _id := ""
var _requetes: PackedStringArray = []
var _gardees: Array = []
var _debut_prechargement := 0
## L'écran est-il affiché (une arrivée est en cours) ?
var _actif := false
var _progression := 0.0
var _affichee := 0.0
var _etape := ""
var _t := 0.0

var _voile: ColorRect
var _dessin: Control
var _titre: Label
var _lieu: Label
var _ligne: Label
var _pourcent: Label
var _barre: Control


func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_voile = ColorRect.new()
	_voile.color = NUIT
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_voile)
	_dessin = Dessin.new()
	_dessin.ecran = self
	_dessin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dessin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.add_child(_dessin)
	var boite := VBoxContainer.new()
	boite.set_anchors_preset(Control.PRESET_FULL_RECT)
	boite.alignment = BoxContainer.ALIGNMENT_END
	boite.offset_bottom = -70
	boite.add_theme_constant_override("separation", 10)
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.add_child(boite)
	_titre = _mot(40, OR, Polices.titre())
	boite.add_child(_titre)
	_lieu = _mot(17, DOUX, Polices.texte())
	boite.add_child(_lieu)
	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 44)
	boite.add_child(espace)
	_barre = Barre.new()
	_barre.ecran = self
	_barre.custom_minimum_size = Vector2(520, 14)
	_barre.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boite.add_child(_barre)
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_theme_constant_override("separation", 14)
	boite.add_child(bas)
	_ligne = _mot(16, Color(0.85, 0.86, 0.9), Polices.texte())
	bas.add_child(_ligne)
	_pourcent = _mot(16, OR, Polices.gras())
	bas.add_child(_pourcent)


func _mot(taille: int, couleur: Color, police: Font) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	if police:
		l.add_theme_font_override("font", police)
	return l


## Une arrivée est-elle couverte par l'écran ? Une scène de commune peut alors se bâtir en plusieurs
## images (voir l'en-tête) ; sinon (un test, une capture, l'éditeur), elle se bâtit d'un bloc.
func actif() -> bool:
	return _actif


## Où en est l'arrivée, de 0 à 1 (la barre).
func progression() -> float:
	return _progression


## Lance la lecture des ressources du paquet de cette commune dans des fils à part, sans rien afficher :
## le vol l'appelle au décollage. Le paquet est monté s'il ne l'est pas. Sans effet pour une commune
## sans paquet (en dossier, ou Smarves).
func precharger(id: String) -> void:
	if _id == id and not _requetes.is_empty():
		return
	_lacher()
	var c: Commune = Communes.commune(id)
	if c == null or c.pack == "" or not Communes.ouvrir(id):
		return
	_id = id
	_debut_prechargement = Time.get_ticks_msec()
	var rep = Communes.repertoire_pack(c.pack)
	if rep == null:
		return
	for e in rep:
		var f := "res://" + str(e[0])
		if f.begins_with("res://.godot/") or f.ends_with(".uid"):
			continue
		if f.ends_with(".import"):
			f = f.trim_suffix(".import")
		elif f.get_extension() not in ["gd", "tscn", "scn", "tres", "res", "gdshader"]:
			continue
		if ResourceLoader.exists(f) and ResourceLoader.load_threaded_request(f, "", true) == OK:
			_requetes.append(f)


## Les ressources du préchargement déjà lues, de 0 à 1.
func _lues() -> float:
	if _requetes.is_empty():
		return 1.0
	var n := 0
	for f in _requetes:
		if ResourceLoader.load_threaded_get_status(f) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			n += 1
	return float(n) / _requetes.size()


## Garde les ressources lues jusqu'à ce que la scène les ait prises (sinon le cache les oublierait).
func _recueillir() -> void:
	for f in _requetes:
		if ResourceLoader.load_threaded_get_status(f) == ResourceLoader.THREAD_LOAD_LOADED:
			_gardees.append(ResourceLoader.load_threaded_get(f))
		elif ResourceLoader.load_threaded_get_status(f) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_gardees.append(ResourceLoader.load_threaded_get(f))
	_requetes = []


func _lacher() -> void:
	# Une lecture lancée doit être reprise (load_threaded_get) pour que le moteur la libère.
	_recueillir()
	_gardees = []
	_id = ""


## Change de scène : derrière l'écran si `chemin` est une scène d'une commune en paquet (res://communes/<id>/),
## d'un coup sinon. Les portes qui ramènent dans une commune (boutique, étude, salle, stade) passent par là.
func changer(chemin: String) -> void:
	var id := chemin.trim_prefix("res://communes/").get_slice("/", 0) if chemin.begins_with("res://communes/") else ""
	var c: Commune = Communes.commune(id) if id != "" else null
	if c == null or c.pack == "" or not Communes.ouvrir(id):
		get_tree().change_scene_to_file(chemin)
		return
	entrer(id, chemin)


## Entre dans la scène `chemin` de la commune `id`, derrière l'écran. Rend la main tout de suite : la
## scène change quand le paquet est lu.
func entrer(id: String, chemin: String) -> void:
	if _actif:
		return
	var c: Commune = Communes.commune(id)
	if c == null or c.pack == "":
		get_tree().change_scene_to_file(chemin)
		return
	_actif = true
	_progression = 0.0
	_affichee = 0.0
	_titre.text = c.nom.to_upper()
	_lieu.text = ("%s, %s" % [c.ville(), c.pays()]) if c.lointaine() else c.nom
	_etape = PHRASES[randi() % PHRASES.size()]
	_voile.modulate.a = 1.0
	visible = true
	# Ce que le vol a déjà lu compte dans la barre ; le reste se lit pendant que la scène se bâtit (la scène
	# attend d'elle-même une ressource encore en lecture). Sans trajet, on ne précharge pas : lire tout le
	# paquet dans des fils puis bâtir prend plus longtemps que bâtir directement.
	if _id != id:
		_lacher()
	var t0 := Time.get_ticks_msec()
	var pendant := t0 - _debut_prechargement if not _requetes.is_empty() else 0
	var lues := _lues() if not _requetes.is_empty() else 0.0
	var depart := PART_PRECHARGEMENT * lues
	_progression = depart
	await get_tree().process_frame
	var scene: PackedScene = load(chemin)
	get_tree().change_scene_to_packed(scene)
	# La scène entre dans l'arbre à la fin de cette image ; elle peut se bâtir sur plusieurs images.
	await get_tree().process_frame
	await get_tree().process_frame
	var s := get_tree().current_scene
	var phrase := 0
	while s != null and is_instance_valid(s) and s.get("chargement") is float and s.chargement < 1.0:
		_progression = lerpf(depart, PART_SCENE, clampf(s.chargement, 0.0, 1.0))
		var e = s.get("chargement_etape")
		if e is String and e != "":
			_etape = e
		elif int((Time.get_ticks_msec() - t0) / 2200.0) != phrase:
			phrase = int((Time.get_ticks_msec() - t0) / 2200.0)
			_etape = PHRASES[(PHRASES.find(_etape) + 1) % PHRASES.size()]
		await get_tree().process_frame
	var t2 := Time.get_ticks_msec()
	_progression = PART_SCENE
	_etape = "Bienvenue !"
	for i in IMAGES_APRES:
		await get_tree().process_frame
	var t3 := Time.get_ticks_msec()
	_progression = 1.0
	_lacher()
	print("[chargement] %s : %d %% du paquet lu pendant le trajet (%d ms), scène %d ms, premières images %d ms" % [
		id, roundi(lues * 100.0), pendant, t2 - t0, t3 - t2])
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(_voile, "modulate:a", 0.0, 0.4)
	await tw.finished
	visible = false
	_actif = false


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	# La barre avance en douceur vers la progression, sans jamais reculer.
	_affichee = maxf(_affichee, lerpf(_affichee, _progression, 1.0 - exp(-8.0 * dt)))
	if _progression >= 1.0:
		_affichee = 1.0
	_ligne.text = _etape
	_pourcent.text = "%d %%" % roundi(_affichee * 100.0)
	_dessin.queue_redraw()
	_barre.queue_redraw()


## La roue, la bille et les ampoules : tout se dessine, rien ne se charge.
class Dessin extends Control:
	var ecran

	func _draw() -> void:
		var t: float = ecran._t
		var c := Vector2(size.x * 0.5, size.y * 0.36)
		var r := minf(size.x, size.y) * 0.2
		# Le halo derrière la roue, qui respire.
		for i in 6:
			draw_circle(c, r * (1.5 - i * 0.07), Color(0.55, 0.12, 0.35, 0.025 + 0.012 * sin(t * 1.6)))
		# La roue : 37 cases (le zéro vert, puis rouge et noir), qui tourne dans un sens.
		var a0 := t * 0.9
		var n := 37
		draw_circle(c, r * 1.08, Color(0.36, 0.2, 0.08))
		draw_arc(c, r * 1.08, 0, TAU, 96, OR.darkened(0.2), 3.0, true)
		for i in n:
			var a1 := a0 + TAU * i / n
			var a2 := a0 + TAU * (i + 1) / n
			var coul: Color = VERT if i == 0 else (ROUGE if i % 2 else NOIR)
			var pts := PackedVector2Array([c + Vector2.from_angle(a1) * r * 0.62, c + Vector2.from_angle(a1) * r,
				c + Vector2.from_angle((a1 + a2) * 0.5) * r, c + Vector2.from_angle(a2) * r, c + Vector2.from_angle(a2) * r * 0.62])
			draw_colored_polygon(pts, coul)
			draw_line(c + Vector2.from_angle(a1) * r * 0.62, c + Vector2.from_angle(a1) * r, OR.darkened(0.35), 1.0, true)
		draw_circle(c, r * 0.62, Color(0.3, 0.17, 0.07))
		draw_arc(c, r * 0.62, 0, TAU, 64, OR.darkened(0.3), 2.0, true)
		# Le moyeu et sa croix dorée.
		for k in 4:
			var d := Vector2.from_angle(a0 * 1.0 + PI * 0.5 * k)
			draw_line(c, c + d * r * 0.42, OR, 4.0, true)
			draw_circle(c + d * r * 0.42, 4.0, OR)
		draw_circle(c, r * 0.1, OR)
		# La bille court en sens inverse, sur le rebord, et tressaute un peu.
		var ab := -t * 2.3
		var rb := r * (0.9 + 0.035 * sin(t * 7.0))
		draw_circle(c + Vector2.from_angle(ab) * rb + Vector2(1.5, 2.0), r * 0.045, Color(0, 0, 0, 0.35))
		draw_circle(c + Vector2.from_angle(ab) * rb, r * 0.045, Color(0.97, 0.97, 0.95))
		# Les ampoules autour de l'enseigne : elles défilent comme sur le Strip.
		# L'enseigne encadre le nom de la commune et sa ville.
		var titre: Rect2 = ecran._titre.get_global_rect().merge(ecran._lieu.get_global_rect())
		var police: Font = ecran._titre.get_theme_font("font")
		var large := police.get_string_size(ecran._titre.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ecran._titre.get_theme_font_size("font_size")).x
		var w := clampf(large + 180.0, 440.0, size.x - 40.0)
		var cadre := Rect2(Vector2((size.x - w) * 0.5, titre.position.y - 22.0), Vector2(w, titre.size.y + 44.0))
		var pas := 22.0
		var tour := 2.0 * (cadre.size.x + cadre.size.y)
		var nb := int(tour / pas)
		for i in nb:
			var u := float(i) * pas
			var p: Vector2
			if u < cadre.size.x:
				p = cadre.position + Vector2(u, 0)
			elif u < cadre.size.x + cadre.size.y:
				p = cadre.position + Vector2(cadre.size.x, u - cadre.size.x)
			elif u < 2.0 * cadre.size.x + cadre.size.y:
				p = cadre.position + Vector2(cadre.size.x - (u - cadre.size.x - cadre.size.y), cadre.size.y)
			else:
				p = cadre.position + Vector2(0, cadre.size.y - (u - 2.0 * cadre.size.x - cadre.size.y))
			var allumee := (i + int(t * 9.0)) % 3 == 0
			if allumee:
				draw_circle(p, 7.0, Color(1.0, 0.82, 0.45, 0.18))
			draw_circle(p, 3.4, Color(1.0, 0.88, 0.55) if allumee else Color(0.4, 0.3, 0.18))


## La barre de progression : un rail sombre, l'or qui avance et un reflet qui la parcourt.
class Barre extends Control:
	var ecran

	func _draw() -> void:
		var f: float = ecran._affichee
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(1, 1, 1, 0.08))
		var plein := Rect2(Vector2.ZERO, Vector2(size.x * f, size.y))
		draw_rect(plein, OR.darkened(0.15))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * f, size.y * 0.45)), Color(1, 0.92, 0.7, 0.35))
		# Le reflet qui file sur la partie pleine.
		var x := fmod(ecran._t * 260.0, size.x + 120.0) - 60.0
		if x < size.x * f:
			var x0 := maxf(0.0, x - 30.0)
			var x1 := minf(size.x * f, x + 30.0)
			if x1 > x0:
				draw_rect(Rect2(Vector2(x0, 0), Vector2(x1 - x0, size.y)), Color(1, 1, 1, 0.22))
		draw_rect(r, OR.darkened(0.4), false, 1.0)
