extends "res://scripts/shop_interior.gd"
## La charge d'agent de change de Mme Vasseur, rue du Clain (docs/BOURSE.md) : le local « Prochainement »
## qu'un commerce occupe enfin, derrière son seuil. Le tableau de cotation au mur du fond, à la craie et à
## l'or, les quatre valeurs et leur dernière clôture ; les horloges de Paris, New York et Tokyo ; le
## téléscripteur et son ruban ; le guichet et sa grille de laiton, Mme Vasseur derrière. On lui parle (E),
## ou l'on lit la cote, et la fenêtre de la bourse s'ouvre (scripts/socle/bourse_panel.gd).
## Capture : godot --path . res://scenes/bourse.tscn -- --capture=sortie.png --bourse-essai [--at=x,z,lacet,tangage]
## [--open=cote] [--ordre=cac40]

const COTE := preload("res://scripts/socle/bourse_panel.gd")
const HOTE := "Mme Vasseur"
const NOM := "La charge de Mme Vasseur, agent de change"
const PAROLES := [
	"« Odile Vasseur, agent de change. Ici, on ne joue pas : on prend position. »",
	"« Le CAC ferme à 17 h 35, New York à 22 h, Tokyo pendant que vous dormez. La bourse, elle, ne dort pas. »",
	"« Au levier 100, un pour cent fait toute la différence. Dans un sens ou dans l'autre. »",
	"« Je vous exécute à la clôture. Personne ne connaît son prix d'avance, pas même moi. »",
	"« M. Brunet m'envoie ses meilleurs clients. Il dit qu'ils reviennent toujours le voir après. »",
	"« Un appel de marge, ce n'est pas une menace. C'est une politesse. »",
]
## Les horloges du mur ouest : la place et son décalage.
## Le guichet est à gauche du tableau, pour qu'on lise la cote par-dessus l'épaule de Mme Vasseur.
const KX := -3.0
## La hauteur du milieu du tableau de cotation.
const BY := 3.05
const HORLOGES := [["PARIS", "cac40"], ["NEW YORK", "sp500"], ["TOKYO", "nikkei"]]

var _lignes := {}
var _heures: Array = []
var _ruban: Label3D
var _ruban_texte := ""
var _ruban_pas := 0.0
var _rafraichi := 0.0


func _ready() -> void:
	_serif = Polices.texte()
	shop = "bourse"
	W = 9.0
	D = 8.0
	H = 4.2
	_environment()
	_room(_wood_floor(Color(0.36, 0.22, 0.13)), _wallpaper(Color(0.14, 0.24, 0.22), Color(0.18, 0.3, 0.27)), Color(0.9, 0.86, 0.78), Color(0.3, 0.17, 0.1))
	_charge()
	_build_keeper()
	_door()
	_build_ui()
	player = PLAYER.new()
	player.position = Vector3(0, 0, D / 2.0 - 1.2)
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("village")
	Bourse.change.connect(_ecrire_cote)
	Bourse.lire()
	_ecrire_cote()
	_maybe_capture()


func _build_keeper() -> void:
	var noyer := _std(Color(0.28, 0.14, 0.08), 0.4)
	var laiton := _std(Color(0.85, 0.68, 0.3), 0.25, 1.0)
	_box(Vector3(2.6, ESTRADE, 1.5), Vector3(KX, ESTRADE / 2.0, -D / 2.0 + 1.15), noyer, true)
	_keeper = Node3D.new()
	_keeper.position = Vector3(KX, ESTRADE, -D / 2.0 + 1.3)
	add_child(_keeper)
	var c := CRITTER.new()
	c.look = Cast.NAMED.vasseur.duplicate(true)
	c.idle_anim = "attentive"
	c.scale = Vector3.ONE * PEOPLE_SCALE
	_keeper.add_child(c)
	# Le guichet : un comptoir de noyer, sa tablette de marbre et la grille de laiton à hauteur d'yeux.
	var z := -D / 2.0 + 2.2
	_box(Vector3(2.6, 1.05, 0.5), Vector3(KX, 0.525, z), noyer, true)
	_box(Vector3(2.7, 0.05, 0.62), Vector3(KX, 1.075, z), _std(Color(0.9, 0.88, 0.84), 0.25))
	for k in 11:
		var x := -1.2 + k * 0.24
		if absf(x) < 0.4:
			continue
		_cyl(0.012, 0.62, Vector3(KX + x, 1.42, z - 0.12), laiton)
	_box(Vector3(2.5, 0.04, 0.04), Vector3(KX, 1.73, z - 0.12), laiton)
	_box(Vector3(0.8, 0.04, 0.04), Vector3(KX, 1.36, z - 0.12), laiton)
	_label3d("ORDRES", Vector3(KX, 1.8, z - 0.1), 34, Color(0.9, 0.78, 0.45))
	# Le carnet d'ordres ouvert, le tampon, et la lampe verte.
	_box(Vector3(0.4, 0.01, 0.28), Vector3(KX + 0.15, 1.105, z + 0.05), _std(Color(0.97, 0.95, 0.88), 0.9))
	var shade := _std(Color(0.1, 0.45, 0.25), 0.2)
	shade.emission_enabled = true
	shade.emission = Color(0.1, 0.5, 0.25)
	shade.emission_energy_multiplier = 0.6
	_cyl(0.02, 0.3, Vector3(KX + 0.9, 1.25, z), laiton)
	_box(Vector3(0.42, 0.09, 0.16), Vector3(KX + 0.9, 1.42, z + 0.03), shade)
	_lamp(Vector3(KX + 0.9, 1.3, z + 0.1), Color(1.0, 0.85, 0.6), 1.0, 3.0)
	_interactive(_keeper, "keeper", "E : parler à Mme Vasseur", Vector3(1.4, 2.2, 2.6), Vector3(0, 1.1, 1.3))


## Le tableau de cotation, les horloges, le téléscripteur, les fauteuils des clients.
func _charge() -> void:
	var laiton := _std(Color(0.85, 0.68, 0.3), 0.25, 1.0)
	var noyer := _std(Color(0.28, 0.14, 0.08), 0.4)
	# Le tableau : un grand panneau noir sous un fronton doré, quatre lignes de cotation.
	var zt := -D / 2.0 + 0.06
	_box(Vector3(5.2, 1.85, 0.06), Vector3(0, BY, zt), laiton)
	_box(Vector3(5.05, 1.7, 0.07), Vector3(0, BY, zt + 0.005), _std(Color(0.06, 0.08, 0.08), 0.85))
	_label3d("COTE  ·  DERNIÈRES CLÔTURES", Vector3(0, BY + 0.7, zt + 0.05), 54, Color(0.95, 0.8, 0.45))
	for k in 4:
		var y := BY + 0.35 - k * 0.36
		var id: String = Bourse.ORDRE[k]
		var nom := _label3d(Bourse.VALEURS[id].nom.to_upper(), Vector3(-2.35, y, zt + 0.05), 50, Color(0.93, 0.93, 0.88))
		nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var cours := _label3d("…", Vector3(0.9, y, zt + 0.05), 54, Color(0.96, 0.82, 0.45))
		cours.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var v := _label3d("", Vector3(2.35, y, zt + 0.05), 46, Color(0.93, 0.93, 0.88))
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_lignes[id] = [cours, v]
		if k < 3:
			_box(Vector3(4.8, 0.008, 0.01), Vector3(0, y - 0.18, zt + 0.045), _std(Color(0.4, 0.42, 0.4), 0.9))
	# Le ruban lumineux sous le tableau, où défilent les valeurs.
	_box(Vector3(5.2, 0.22, 0.06), Vector3(0, BY - 1.03, zt), _std(Color(0.03, 0.03, 0.03), 0.6))
	_ruban = _label3d("", Vector3(0, BY - 1.03, zt + 0.05), 40, Color(1.0, 0.62, 0.2))
	_ruban.font = Polices.gras()
	var tableau := Node3D.new()
	tableau.position = Vector3(0, BY, zt + 0.3)
	add_child(tableau)
	_interactive(tableau, "cote", "E : lire la cote", Vector3(5.0, 1.8, 0.6))
	_lamp(Vector3(0, 3.6, zt + 1.2), Color(1.0, 0.86, 0.62), 1.4, 5.0)

	# Les trois horloges du mur ouest.
	for k in HORLOGES.size():
		var z := -2.4 + k * 1.5
		var x := -W / 2.0 + 0.06
		var disque := _cyl(0.32, 0.05, Vector3(x, 2.9, z), laiton)
		disque.rotation_degrees.z = 90.0
		var cadran := _cyl(0.28, 0.06, Vector3(x + 0.01, 2.9, z), _std(Color(0.96, 0.94, 0.88), 0.6))
		cadran.rotation_degrees.z = 90.0
		var h := _label3d("--:--", Vector3(x + 0.06, 2.9, z), 36, Color(0.1, 0.1, 0.12), 90.0)
		h.font = Polices.gras()
		_heures.append(h)
		_label3d(HORLOGES[k][0], Vector3(x + 0.06, 2.45, z), 28, Color(0.92, 0.82, 0.55), 90.0)

	# Le téléscripteur sur sa colonne, sous sa cloche de verre, et son ruban de papier jusqu'au sol.
	var tx := W / 2.0 - 0.9
	var tz := -1.0
	_cyl(0.16, 0.95, Vector3(tx, 0.475, tz), noyer)
	_box(Vector3(0.5, 0.16, 0.4), Vector3(tx, 1.03, tz), _std(Color(0.12, 0.12, 0.14), 0.4, 0.4))
	var verre := _std(Color(0.75, 0.85, 0.9, 0.25), 0.05)
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cyl(0.26, 0.4, Vector3(tx, 1.31, tz), verre, self, 0.2)
	var papier := _std(Color(0.96, 0.94, 0.86), 0.9)
	for k in 6:
		var b := _box(Vector3(0.05, 0.004, 0.22), Vector3(tx - 0.3 - k * 0.12, 0.9 - k * 0.15, tz + 0.1 * sin(k)), papier)
		b.rotation_degrees.z = -50.0 + k * 6.0
	_box(Vector3(0.6, 0.004, 0.05), Vector3(tx - 0.6, 0.01, tz + 0.4), papier).rotation_degrees.y = 30.0
	var tele := Node3D.new()
	tele.position = Vector3(tx, 1.0, tz)
	add_child(tele)
	_interactive(tele, "telescripteur", "E : lire le ruban du téléscripteur", Vector3(0.8, 1.4, 0.8))
	_label3d("TÉLÉSCRIPTEUR", Vector3(tx, 0.6, tz + 0.17), 22, Color(0.9, 0.78, 0.45))

	# Les fauteuils des clients, la table basse et son journal, les rayonnages de titres.
	_place(KK + "furniture/armchair.gltf", Vector3(-2.6, 0, 1.6), 0.75, 60.0)
	_place(KK + "furniture/armchair.gltf", Vector3(-2.6, 0, 3.0), 0.75, 110.0)
	_box(Vector3(0.6, 0.4, 0.6), Vector3(-1.9, 0.2, 2.3), noyer, true)
	_box(Vector3(0.36, 0.01, 0.26), Vector3(-1.9, 0.41, 2.3), _std(Color(0.94, 0.9, 0.82), 0.9)).rotation_degrees.y = 14.0
	_label3d("LE COURRIER DE LA COTE", Vector3(-1.9, 0.42, 2.3), 12, Color(0.15, 0.15, 0.18)).rotation_degrees.x = -90.0
	_place("res://assets/kenney/furniture/pottedPlant.glb", Vector3(W / 2.0 - 0.5, 0, 2.8), 3.0)
	_bulb(Vector3(-1.6, H - 0.7, 0.8), Color(0.2, 0.4, 0.3))
	_bulb(Vector3(1.6, H - 0.7, 0.8), Color(0.2, 0.4, 0.3))


## Le tableau et le ruban d'après la dernière lecture.
func _ecrire_cote() -> void:
	var morceaux := []
	for id in Bourse.ORDRE:
		var i: Dictionary = Bourse.indice(id)
		var der: Array = Bourse.dernier(i)
		if der.is_empty():
			_lignes[id][0].text = "…" if Bourse.etat in ["", "lecture"] else "–"
			_lignes[id][1].text = ""
			continue
		var v: float = Bourse.variation(i, 1)
		_lignes[id][0].text = COTE.nombre(float(der[1]))
		_lignes[id][1].text = COTE.pourcent(v)
		_lignes[id][1].modulate = COTE.HAUSSE if v >= 0.0 else COTE.BAISSE
		morceaux.append("%s %s %s" % [Bourse.VALEURS[id].nom.to_upper(), COTE.nombre(float(der[1])), COTE.pourcent(v)])
	_ruban_texte = ("   ·   ".join(morceaux) + "   ·   ") if not morceaux.is_empty() else "LIAISON INTERROMPUE   ·   "


func _process(delta: float) -> void:
	super._process(delta)
	# Le ruban avance d'un caractère tous les dixièmes de seconde, sur une cinquantaine de caractères.
	_ruban_pas += delta
	if _ruban_texte != "" and _ruban_pas >= 0.12:
		_ruban_pas = 0.0
		var k := int(Time.get_ticks_msec() / 120) % _ruban_texte.length()
		_ruban.text = (_ruban_texte + _ruban_texte + _ruban_texte).substr(k, 52)
	_rafraichi -= delta
	if _rafraichi <= 0.0:
		_rafraichi = 1.0
		var t := int(Time.get_unix_time_from_system())
		if Bourse._essai:
			t = int(Bourse.donnees.get("maintenant", t))
		for k in HORLOGES.size():
			var id: String = HORLOGES[k][1]
			var l := t + Bourse.decalage(id, t) * 3600
			var d := Time.get_datetime_dict_from_unix_time(l)
			_heures[k].text = "%02d:%02d" % [d.hour, d.minute]


func _place_name() -> String:
	return NOM


func say(text: String) -> void:
	_speech.text = "%s : %s" % [HOTE, text]
	_speech.modulate.a = 1.0
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = create_tween()
	_speech_tween.tween_interval(4.0 + text.length() * 0.04)
	_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.8)


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			# On ressort devant l'ancien local « Prochainement » (Village.lots).
			Game.return_point = "lot_reserve"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Chargement.changer("res://scenes/main.tscn")
		"keeper":
			say(PAROLES.pick_random())
			var keeper := _keeper.get_child(0)
			if keeper.has_method("gesture"):
				keeper.gesture("talk")
				keeper.talk(2.5)
			open_vitrine()
		"cote":
			open_vitrine()
		"telescripteur":
			say(_depeche())


## Ce que dit le ruban : la valeur qui a le plus bougé à la dernière séance.
func _depeche() -> String:
	var meilleur := ""
	var ecart := -1.0
	for id in Bourse.ORDRE:
		var v: float = Bourse.variation(Bourse.indice(id), 1)
		if absf(v) > ecart:
			ecart = absf(v)
			meilleur = id
	if meilleur == "" or Bourse.dernier(Bourse.indice(meilleur)).is_empty():
		return "« Le ruban est blanc. Quand New York tousse, il crépite ; là, il se tait. »"
	var v: float = Bourse.variation(Bourse.indice(meilleur), 1)
	return "« %s, %s à la dernière séance. Au levier 50, cela fait %s sur la marge. »" % [
		Bourse.VALEURS[meilleur].nom, COTE.pourcent(v), COTE.pourcent(v * 50.0)]


## Le parcours automatique (tools/smoke.gd) ouvre le jeu de chaque salle par open_game et _game.
var _game: Control


func open_game() -> void:
	open_vitrine()
	_game = _panel


func open_vitrine() -> void:
	if _panel != null:
		return
	var p: PanelContainer = COTE.new()
	p.spoke.connect(say)
	p.closed.connect(func():
		p.queue_free()
		_panel = null
		_game = null
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel_layer.add_child(p)
	_panel = p


func _maybe_capture() -> void:
	var path := ""
	var open := false
	var ordre := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
			if v.size() > 3:
				player.camera.rotation.x = deg_to_rad(v[3])
		elif arg == "--open=cote":
			open = true
		elif arg.begins_with("--ordre="):
			open = true
			ordre = arg.trim_prefix("--ordre=")
		elif arg.begins_with("--won="):
			Game.won = int(arg.trim_prefix("--won="))
			Game.credits += Game.won / 2
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if open:
		await get_tree().create_timer(1.0).timeout
		say(PAROLES[0])
		open_vitrine()
		if ordre != "":
			_panel.ouvrir_ordre(ordre)
	await get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
