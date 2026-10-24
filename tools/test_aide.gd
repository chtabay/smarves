extends SceneTree
## Vérifie le (i) du socle sans affichage : godot --headless --path . -s tools/test_aide.gd
## Posé à côté d'un texte (dans une rangée ou dans une colonne), il ouvre sa bulle au survol de la souris et
## la referme à la sortie ; un clic ou un toucher l'épingle, une pression ailleurs, Échap ou un deuxième
## toucher la referment ; Échap ne va pas plus loin ; la bulle tient dans l'écran ; une seule à la fois ;
## et dans le carnet, les explications des pages de club sont passées sur des (i).

const AIDE := preload("res://scripts/socle/aide.gd")

var fails := 0
var echap_plus_loin := 0


class Temoin extends Node:
	var vu := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			vu += 1


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_lancer.call_deferred()


func _centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _souris(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	root.push_input(m)


func _clic(pos: Vector2) -> void:
	for appui in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.position = pos
		b.global_position = pos
		b.pressed = appui
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if appui else 0
		root.push_input(b)


## Un toucher, comme sur un téléphone : l'événement tactile, puis le clic que Godot en tire.
func _toucher(pos: Vector2) -> void:
	for appui in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = pos
		t.pressed = appui
		root.push_input(t)
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.position = pos
		b.global_position = pos
		b.pressed = appui
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if appui else 0
		root.push_input(b)


func _echap() -> void:
	for appui in [true, false]:
		var k := InputEventKey.new()
		k.keycode = KEY_ESCAPE
		k.physical_keycode = KEY_ESCAPE
		k.pressed = appui
		root.push_input(k)


func _attendre() -> void:
	await process_frame
	await process_frame


func _lancer() -> void:
	# Sans affichage, la fenêtre fait 64 px : on lui donne la taille du jeu pour que les gestes tombent juste.
	root.size = Vector2i(1600, 900)
	var temoin := Temoin.new()
	root.add_child(temoin)
	var calque := CanvasLayer.new()
	calque.layer = 40
	root.add_child(calque)
	var fond := VBoxContainer.new()
	fond.position = Vector2(40, 40)
	fond.size = Vector2(500, 300)
	calque.add_child(fond)

	# ---- posé dans une colonne : une rangée prend la place du texte
	var avant := Label.new()
	avant.text = "Avant"
	fond.add_child(avant)
	var titre := Label.new()
	titre.text = "CLASSEMENT"
	fond.add_child(titre)
	var apres := Label.new()
	apres.text = "Après"
	fond.add_child(apres)
	var i: Button = AIDE.poser(titre, "Le premier monte, les 2 derniers descendent.")
	var h := titre.get_parent()
	check(h is HBoxContainer and h.get_parent() == fond and h.get_index() == 1 and i.get_parent() == h and i.get_index() == 1,
		"dans une colonne, le (i) suit le texte dans une rangée, à la même place")
	check(i.text == "i" and i.tooltip_text == "" and i.focus_mode == Control.FOCUS_NONE, "un rond « i », sans infobulle Godot, qui ne prend pas le focus")

	# ---- posé dans une rangée : juste à côté
	var rangee := HBoxContainer.new()
	fond.add_child(rangee)
	var chiffre := Label.new()
	chiffre.text = "12 points"
	rangee.add_child(chiffre)
	var suite := Label.new()
	suite.text = "en 6 matchs"
	rangee.add_child(suite)
	var j: Button = AIDE.poser(chiffre, "Deux points la victoire.")
	check(j.get_parent() == rangee and j.get_index() == 1 and chiffre.get_parent() == rangee, "dans une rangée, le (i) se glisse juste après le texte")
	await _attendre()

	# ---- la souris : le survol ouvre, la sortie referme
	check(not AIDE.ouverte(), "rien d'ouvert au départ")
	_souris(_centre(i))
	await _attendre()
	check(AIDE.ouverte() and AIDE.texte_ouvert() == "Le premier monte, les 2 derniers descendent.", "le survol ouvre la bulle, avec son explication")
	var bulle: Control = root.find_child("Bulle", true, false)
	check(bulle != null and (bulle.get_parent() as CanvasLayer).layer > calque.layer, "la bulle passe au-dessus du calque du (i)")
	check(bulle != null and bulle.position.y >= i.get_global_rect().end.y, "et s'ouvre sous lui")
	_souris(Vector2(600, 500))
	await _attendre()
	check(not AIDE.ouverte(), "la sortie du survol la referme")

	# ---- le clic épingle ; une pression ailleurs referme
	_souris(_centre(i))
	_clic(_centre(i))
	await _attendre()
	_souris(Vector2(600, 500))
	await _attendre()
	check(AIDE.ouverte(), "cliquée, la bulle reste ouverte quand la souris s'en va")
	_clic(Vector2(600, 500))
	await _attendre()
	check(not AIDE.ouverte(), "un clic ailleurs la referme")

	# ---- le toucher : ouvre et épingle ; un deuxième toucher sur le (i) referme
	_toucher(_centre(i))
	await _attendre()
	check(AIDE.ouverte() and AIDE.texte_ouvert().begins_with("Le premier"), "au doigt, un toucher ouvre la bulle")
	_toucher(_centre(i))
	await _attendre()
	check(not AIDE.ouverte(), "un deuxième toucher sur le (i) la referme")
	_toucher(_centre(i))
	await _attendre()
	_toucher(Vector2(600, 500))
	await _attendre()
	check(not AIDE.ouverte(), "un toucher ailleurs la referme")

	# ---- un toucher dans la bulle la garde ouverte
	_toucher(_centre(i))
	await _attendre()
	bulle = root.find_child("Bulle", true, false)
	_toucher(_centre(bulle))
	await _attendre()
	check(AIDE.ouverte(), "un toucher dans la bulle la laisse ouverte")

	# ---- Échap la referme et ne ferme rien d'autre (le menu Échap des réglages, mis de côté, ne s'ouvre pas)
	var reglages: Node = root.get_node("Settings")
	reglages.process_mode = Node.PROCESS_MODE_DISABLED
	var vus := temoin.vu
	_echap()
	await _attendre()
	check(not AIDE.ouverte() and temoin.vu == vus, "Échap referme la bulle, et rien d'autre (l'écran dessous ne la reçoit pas)")
	_echap()
	await _attendre()
	check(temoin.vu == vus + 1, "bulle fermée, Échap revient à l'écran")
	reglages.process_mode = Node.PROCESS_MODE_INHERIT

	# ---- une seule à la fois
	# (le (i) du dessus d'abord : sa bulle, ouverte en dessous, couvrirait l'autre)
	_toucher(_centre(j))
	await _attendre()
	_toucher(_centre(i))
	await _attendre()
	check(AIDE.texte_ouvert().begins_with("Le premier") and root.find_children("Bulle", "", true, false).size() == 1, "un autre (i) remplace la bulle, une seule à la fois")
	AIDE.fermer()
	await _attendre()

	# ---- tenue dans l'écran : un (i) au bord droit, en bas
	var vue := root.get_visible_rect().size
	var bord := AIDE.creer("Une explication un peu plus longue que les autres, pour voir la bulle se replier sur plusieurs lignes et tenir dans l'écran.")
	calque.add_child(bord)
	bord.position = vue - Vector2(24, 24)
	await _attendre()
	_toucher(_centre(bord))
	await _attendre()
	bulle = root.find_child("Bulle", true, false)
	var r := bulle.get_global_rect() if bulle != null else Rect2()
	check(bulle != null and r.position.x >= 0 and r.end.x <= vue.x and r.position.y >= 0 and r.end.y <= vue.y, "au coin de l'écran, la bulle tient dedans")
	check(bulle != null and r.end.y <= bord.get_global_rect().position.y, "et passe au-dessus du (i) quand la place manque en dessous")

	# ---- un (i) qui disparaît emporte sa bulle
	bord.queue_free()
	await _attendre()
	check(not AIDE.ouverte() and root.find_child("Bulle_aide", true, false) == null, "le (i) retiré, sa bulle s'en va avec lui")

	# ---- dans le carnet : les explications des pages de club sont sur des (i)
	calque.queue_free()
	await _attendre()
	await _carnet()

	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _carnet() -> void:
	var TMP := "user://test_aide/"
	var foot: Node = root.get_node("Football")
	var carnet: Node = root.get_node("Carnet")
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	DirAccess.make_dir_recursive_absolute(TMP)
	foot.dossier = TMP
	foot.effacer()
	var t: int = foot.coup_envoi(1, 5) + 4 * 3600
	foot.regler_horloge(func(): return t)
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	foot.forcer_porteurs("vous:2", "smarves")
	carnet.ouvrir_club("smarves")
	await _attendre()
	var g: Control = carnet.get("_left")
	var d: Control = carnet.get("_right")
	var aides: Array = g.find_children("Aide", "Button", true, false) + d.find_children("Aide", "Button", true, false)
	var textes: Array = aides.map(func(a): return str(a.texte))
	check(textes.any(func(x): return x.contains("descendent")), "le classement a son (i) : qui monte, qui descend")
	# La poule d'essai n'a que deux clubs (pas de descente à dire) : la tuile du rang, sur une poule de dix.
	carnet.call("_tuiles_club", {"joues": 6, "rang": 4, "ecart_tete": 3, "taille": 10, "ecart_relegation": 5, "pts": 11, "forme": "VNDVV"}, 8)
	var rang: Control = (g.find_children("Tuile_Rang", "", true, false) as Array).back()
	var ia: Node = rang.find_child("Aide", true, false)
	check(ia != null and str(ia.texte) == "5 pts d'avance sur la descente.", "la tuile du rang a son (i) : l'écart sur la descente")
	var parts: Control = d.find_child("Parts", true, false)
	check(parts != null and parts.tooltip_text == "" and parts.get_parent().find_child("Aide", false, false) != null, "les parts ont leur (i) : qui dirige")
	var classement := g.find_children("*", "Label", true, false).filter(func(l): return (l as Label).text == "CLASSEMENT")
	check(classement.size() == 1 and (classement[0] as Label).tooltip_text == "", "plus d'infobulle sur les titres, seulement le (i)")
	carnet.toggle()
	foot.effacer()
