extends "res://scripts/shop_interior.gd"
## Le stade municipal de Smarves, à la première personne, derrière son seuil (docs/SUITE.md, section 6) :
## la pelouse sous les projecteurs, la tribune couverte de l'Étoile, le tableau d'affichage, et le match
## du dimanche qui se joue minute par minute sur la pelouse (FootMatch, le même état que la feuille du
## café) : les vingt-deux joueurs suivent le ballon, le commentateur parle en bas de l'écran, le tableau
## tient le score. Avant la première journée, l'Étoile s'entraîne et le tableau donne le coup d'envoi.
## L'interface, la capture et les petits outils viennent de l'intérieur des vendeurs (shop_interior.gd).
## Capture : godot --path . res://scenes/stade.tscn -- --capture=sortie.png [--at=x,z,lacet,tangage] [--won=…] [--journee=n] [--minute=m]

## La pelouse : sa longueur (x) et sa largeur (z), et l'échelle des joueurs.
const L := 36.0
const P := 22.0
## Une minute de match par seconde ; Espace passe à quatre.
const CADENCE := 1.0
const COURSE := 4.2

var _etat := {}
var _joueurs := {}
var _hasard: Hasard
var _rencontre := {}
## Les joueurs sur la pelouse : id → son habitant, et où il va.
var _acteurs := {}
var _cibles := {}
var _ballon: MeshInstance3D
var _cible_ballon := Vector3.ZERO
var _vitesse := 1.0
var _chrono := 0.0
var _possession := [0, 0]
var _score: Label3D
var _horloge: Label3D
var _affiche: Label3D
var _supporters: Array = []
var _fini_annonce := false


func _ready() -> void:
	_serif = Polices.texte()
	W = L + 20.0
	D = P + 24.0
	_environment()
	_nuit()
	_pelouse()
	_tribune()
	_tableau_affichage()
	_build_ui()
	player = PLAYER.new()
	player.position = Vector3(0, 0, -P / 2.0 - 4.0)
	player.rotation.y = PI
	add_child(player)
	player.interact.connect(_on_interact)
	Sfx.set_ambience("village")
	_rencontre = _choisir()
	_composer()
	_maybe_capture()


func _place_name() -> String:
	return "Le stade municipal"


# --- Le terrain -----------------------------------------------------------------------------------

## La nuit du dimanche : un ciel sombre, une lune, et les quatre projecteurs qui font le jour sur la pelouse.
func _nuit() -> void:
	var we: WorldEnvironment = null
	for c in get_children():
		if c is WorldEnvironment:
			we = c
	if we:
		we.environment.background_color = Color(0.03, 0.04, 0.09)
		we.environment.ambient_light_color = Color(0.45, 0.5, 0.6)
		we.environment.ambient_light_energy = 0.5
		we.environment.sdfgi_enabled = false
		we.environment.ssil_enabled = false
		we.environment.fog_enabled = true
		we.environment.fog_light_color = Color(0.08, 0.1, 0.16)
		we.environment.fog_density = 0.004
	var lune := DirectionalLight3D.new()
	lune.light_color = Color(0.6, 0.7, 0.9)
	lune.light_energy = 0.25
	lune.rotation_degrees = Vector3(-55, 30, 0)
	add_child(lune)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pied := Vector3(sx * (L / 2.0 + 2.5), 0, sz * (P / 2.0 + 2.5))
			_cyl(0.12, 14.0, pied + Vector3(0, 7.0, 0), _std(Color(0.5, 0.52, 0.55), 0.6, 0.4))
			_box(Vector3(1.6, 0.8, 0.3), pied + Vector3(0, 14.2, 0), _std(Color(0.25, 0.25, 0.28), 0.6)).look_at_from_position(pied + Vector3(0, 14.2, 0), Vector3(0, 0.5, 0), Vector3.UP)
			var spot := SpotLight3D.new()
			spot.light_color = Color(1.0, 0.98, 0.9)
			spot.light_energy = 9.0
			spot.spot_range = 50.0
			spot.spot_angle = 50.0
			spot.shadow_enabled = sz < 0.0 and sx < 0.0
			add_child(spot)
			spot.position = pied + Vector3(0, 14.0, 0)
			spot.look_at(Vector3(sx * L / 6.0, 0, sz * P / 6.0), Vector3.UP)


## La pelouse rayée, ses lignes, ses buts, la main courante et le gravier des abords.
func _pelouse() -> void:
	_box(Vector3(W, 0.2, D), Vector3(0, -0.1, 0), _std(Color(0.42, 0.4, 0.34), 0.95), true)
	var bandes := 12
	for i in bandes:
		var c := Color(0.27, 0.5, 0.2) if i % 2 == 0 else Color(0.32, 0.56, 0.24)
		_box(Vector3((L + 4.0) / bandes, 0.04, P + 4.0), Vector3(-(L + 4.0) / 2.0 + (i + 0.5) * (L + 4.0) / bandes, 0.02, 0), _std(c, 1.0))
	var craie := _std(Color(0.96, 0.96, 0.94), 0.9)
	var lw := 0.12
	for seg in [[Vector3(0, 0, -P / 2.0), Vector3(L, 0.01, lw)], [Vector3(0, 0, P / 2.0), Vector3(L, 0.01, lw)],
			[Vector3(-L / 2.0, 0, 0), Vector3(lw, 0.01, P)], [Vector3(L / 2.0, 0, 0), Vector3(lw, 0.01, P)], [Vector3(0, 0, 0), Vector3(lw, 0.01, P)]]:
		_box(seg[1], seg[0] + Vector3(0, 0.045, 0), craie)
	for s in [-1.0, 1.0]:
		var gx: float = s * L / 2.0
		_box(Vector3(lw, 0.01, 11.0), Vector3(gx - s * 5.5, 0.045, 0), craie)
		_box(Vector3(5.5, 0.01, lw), Vector3(gx - s * 2.75, 0.045, -5.5), craie)
		_box(Vector3(5.5, 0.01, lw), Vector3(gx - s * 2.75, 0.045, 5.5), craie)
		_box(Vector3(0.2, 0.01, 0.2), Vector3(gx - s * 3.6, 0.045, 0), craie)
	for i in 28:
		var a := TAU * i / 28.0
		var b := _box(Vector3(lw, 0.01, 0.65), Vector3(cos(a), 0.045, sin(a)) * 2.9, craie)
		b.rotation.y = -a
	_box(Vector3(0.2, 0.01, 0.2), Vector3(0, 0.045, 0), craie)
	# Les buts et leurs filets.
	var blanc := _std(Color(0.95, 0.95, 0.93), 0.4)
	var filet := _std(Color(0.85, 0.88, 0.9, 0.55), 0.9)
	filet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for s in [-1.0, 1.0]:
		var gx: float = s * L / 2.0
		for zz in [-1.9, 1.9]:
			_cyl(0.06, 1.6, Vector3(gx, 0.8, zz), blanc)
			_box(Vector3(1.4, 0.03, 0.03), Vector3(gx + s * 0.7, 1.6, zz), filet)
		_cyl(0.06, 3.9, Vector3(gx, 1.6, 0), blanc).rotation_degrees.x = 90.0
		_box(Vector3(0.03, 1.6, 3.8), Vector3(gx + s * 1.4, 0.8, 0), filet)
		_box(Vector3(1.4, 0.03, 3.8), Vector3(gx + s * 0.7, 1.6, 0), filet)
		for zz in [-1.9, 1.9]:
			_box(Vector3(1.4, 1.6, 0.03), Vector3(gx + s * 0.7, 0.8, zz), filet)
	# La main courante, le gravier derrière, et les bancs de touche côté tribune.
	var barre := _std(Color(0.85, 0.85, 0.88), 0.3, 0.8)
	for s in [-1.0, 1.0]:
		_box(Vector3(L + 8.0, 0.05, 0.05), Vector3(0, 1.0, s * (P / 2.0 + 3.0)), barre)
		_box(Vector3(0.05, 0.05, P + 6.0), Vector3(s * (L / 2.0 + 4.0), 1.0, 0), barre)
		for k in 15:
			_cyl(0.025, 1.0, Vector3(-L / 2.0 - 4.0 + k * (L + 8.0) / 14.0, 0.5, s * (P / 2.0 + 3.0)), barre)
	for s in [-1.0, 1.0]:
		var bx: float = s * 7.0
		_box(Vector3(4.0, 0.08, 0.5), Vector3(bx, 0.5, -P / 2.0 - 2.0), _std(Color(0.55, 0.36, 0.22), 0.7))
		_box(Vector3(4.0, 0.9, 0.08), Vector3(bx, 0.95, -P / 2.0 - 2.3), _std(Color(0.2, 0.3, 0.45), 0.6))
		_box(Vector3(4.2, 0.06, 1.2), Vector3(bx, 1.5, -P / 2.0 - 1.9), _std(Color(0.2, 0.3, 0.45), 0.6))
	# Le ballon.
	_ballon = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	_ballon.mesh = sm
	_ballon.material_override = _std(Color(0.97, 0.97, 0.95), 0.5)
	_ballon.position = Vector3(0, 0.22, 0)
	add_child(_ballon)


## La tribune couverte, derrière la ligne de touche nord : trois rangs de gradins, le toit, les supporters,
## la grille et l'arche par où l'on est entré.
func _tribune() -> void:
	var beton := _std(Color(0.75, 0.73, 0.7), 0.9)
	var bois := _std(Color(0.55, 0.36, 0.22), 0.7)
	var bleu := _std(Color(0.2, 0.3, 0.45), 0.6)
	var tz := -P / 2.0 - 4.0
	var tw := 22.0
	for i in 4:
		_box(Vector3(tw, 0.4 + i * 0.4, 1.0), Vector3(0, 0.2 + i * 0.2, tz - 0.5 - i * 1.0), beton, true)
		_box(Vector3(tw - 0.2, 0.08, 0.5), Vector3(0, 0.44 + i * 0.4, tz - 0.6 - i * 1.0), bois)
	_box(Vector3(tw + 1.0, 4.0, 0.3), Vector3(0, 2.8, tz - 4.6), _std(Color(0.92, 0.88, 0.8), 0.9), true)
	for px in [-tw / 2.0 + 0.3, -tw / 4.0, 0.0, tw / 4.0, tw / 2.0 - 0.3]:
		_box(Vector3(0.15, 4.2, 0.15), Vector3(px, 2.4, tz + 0.2), bleu)
	var toit := _box(Vector3(tw + 1.0, 0.12, 5.6), Vector3(0, 4.6, tz - 2.2), bleu)
	toit.rotation_degrees.x = -6.0
	_box(Vector3(tw + 1.0, 0.5, 0.08), Vector3(0, 4.3, tz + 0.25), _std(Color(0.97, 0.95, 0.9), 0.6))
	_label3d("L'ÉTOILE DE SMARVES  ·  STADE MUNICIPAL", Vector3(0, 4.3, tz + 0.3), 64, Color(0.15, 0.25, 0.5))
	# Les supporters, assis en tribune : ils se lèvent au but.
	var graine := 70
	for i in 4:
		for k in 7:
			if (i + k) % 3 == 1:
				continue
			graine += 1
			var c := CRITTER.new()
			c.randomize_look(graine)
			if graine % 2 == 0:
				c.look["top_color"] = "#1b3c8c"
			c.scale = Vector3.ONE * PEOPLE_SCALE
			c.position = Vector3(-tw / 2.0 + 1.5 + k * (tw - 3.0) / 6.0 + (i % 2) * 0.8, 0.4 + i * 0.4, tz - 0.3 - i * 1.0)
			add_child(c)
			c.debug_anim("sit")
			_supporters.append(c)
	# Derrière la tribune : la grille, l'arche de l'entrée, et la sortie sur la route du Bois.
	var pierre := _std(Color(0.9, 0.86, 0.76), 0.9)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.24, 1.8, 0.24), Vector3(-tw / 2.0 - 1.0 + s * 0.75, 0.9, tz + 1.0), pierre)
	_box(Vector3(1.8, 0.3, 0.1), Vector3(-tw / 2.0 - 1.0, 1.85, tz + 1.0), bleu)
	_label3d("STADE MUNICIPAL", Vector3(-tw / 2.0 - 1.0, 1.85, tz + 1.07), 40, Color(1.0, 0.9, 0.55))
	var sortie := Node3D.new()
	sortie.position = Vector3(-tw / 2.0 - 1.0, 0, tz + 1.0)
	add_child(sortie)
	_interactive(sortie, "exit", "E : sortir sur la route du Bois", Vector3(2.2, 2.2, 2.0), Vector3(0, 1.1, 0))
	_lamp(Vector3(-tw / 2.0 - 1.0, 2.4, tz + 1.6), Color(1.0, 0.75, 0.45), 1.5, 7.0)
	# Un muret ferme le reste, et la buvette dans l'angle.
	_box(Vector3(W, 1.2, 0.3), Vector3(0, 0.6, -D / 2.0 + 0.2), pierre, true)
	_box(Vector3(0.3, 1.2, D), Vector3(-W / 2.0 + 0.2, 0.6, 0), pierre, true)
	_box(Vector3(0.3, 1.2, D), Vector3(W / 2.0 - 0.2, 0.6, 0), pierre, true)
	_box(Vector3(W, 1.2, 0.3), Vector3(0, 0.6, D / 2.0 - 0.2), pierre, true)
	var buvette := Node3D.new()
	buvette.position = Vector3(tw / 2.0 + 3.0, 0, tz - 1.0)
	add_child(buvette)
	_box(Vector3(3.0, 2.4, 2.0), Vector3.ZERO + Vector3(0, 1.2, 0), _std(Color(0.9, 0.85, 0.7), 0.8), true, buvette)
	_box(Vector3(3.2, 0.1, 1.2), Vector3(0, 2.45, 1.2), bleu, false, buvette)
	_box(Vector3(2.4, 0.08, 0.5), Vector3(0, 1.05, 1.2), bois, false, buvette)
	_label3d("BUVETTE", Vector3(0, 2.0, 1.02), 44, Color(0.95, 0.85, 0.6)).position += buvette.position
	_lamp(buvette.position + Vector3(0, 2.2, 1.6), Color(1.0, 0.8, 0.5), 1.2, 6.0)
	_interactive(buvette, "buvette", "E : un café à la buvette", Vector3(3.4, 2.4, 2.0), Vector3(0, 1.2, 1.8))


## Le tableau d'affichage, derrière la touche sud, face à la tribune.
func _tableau_affichage() -> void:
	var z := P / 2.0 + 5.0
	var noir := _std(Color(0.08, 0.09, 0.1), 0.5)
	for x in [-3.2, 3.2]:
		_box(Vector3(0.2, 4.0, 0.2), Vector3(x, 2.0, z), _std(Color(0.4, 0.42, 0.45), 0.6, 0.4))
	_box(Vector3(7.4, 2.6, 0.3), Vector3(0, 4.3, z), noir)
	_box(Vector3(7.6, 0.2, 0.4), Vector3(0, 5.7, z), _std(Color(0.2, 0.3, 0.45), 0.6))
	_score = _label3d("0 - 0", Vector3(0, 4.7, z - 0.17), 160, Color(1.0, 0.85, 0.3), 180.0)
	_score.shaded = false
	_horloge = _label3d("", Vector3(0, 3.95, z - 0.17), 48, Color(0.95, 0.95, 0.9), 180.0)
	_horloge.shaded = false
	_affiche = _label3d("", Vector3(0, 3.45, z - 0.17), 34, Color(0.8, 0.85, 0.95), 180.0)
	_affiche.shaded = false
	_lamp(Vector3(0, 5.0, z - 1.5), Color(1.0, 0.9, 0.7), 1.0, 6.0)


# --- Le match -------------------------------------------------------------------------------------

## Le match qu'on joue ce soir : celui de l'Étoile à la dernière journée jouée, sinon le premier match de la
## division suivie ; avant la première journée, rien : {} (l'Étoile s'entraîne).
func _choisir() -> Dictionary:
	if Football.niveaux.is_empty():
		Football.actualiser()
	var tableau: PanelContainer = FootTableau.new()
	var d: Array = tableau.division_suivie()
	tableau.free()
	var s: int = Football.saison
	var joues: int = Football.journee_jouee()
	var j: int = joues if joues > 0 else 1
	var matchs: Array = Football.journee(s, d[0], d[1], j, joues)
	var origine: Commune = Communes.origine()
	var choisi: Dictionary = matchs[0]
	for m in matchs:
		if origine and (m.dom == origine.id or m.ext == origine.id):
			choisi = m
	return {"s": s, "j": j, "dom": choisi.dom, "ext": choisi.ext, "joue": joues > 0}


## Les vingt-deux sur la pelouse, le tableau à zéro, et le coup d'envoi (ou l'entraînement).
func _composer() -> void:
	var r := _rencontre
	var cd: Dictionary = Football.clubs[r.dom]
	var ce: Dictionary = Football.clubs[r.ext]
	var direct: Dictionary = Football.rencontre_en_direct(r.s, r.j, r.dom, r.ext)
	_etat = direct.etat
	_joueurs = direct.joueurs
	_hasard = direct.hasard
	for i in 2:
		var eq: Dictionary = _etat.equipes[i]
		var club: Dictionary = cd if i == 0 else ce
		for e in eq.onze:
			_acteur(e.id, i, club.couleurs)
	_placer(true)
	_score.text = "%s  0 - 0  %s" % [cd.court, ce.court]
	_score.font_size = 110
	if r.joue:
		_horloge.text = "Journée %d  ·  0'" % r.j
		_affiche.text = "%s – %s  ·  %s" % [cd.nom, ce.nom, FootTableau.date(Football.coup_envoi(r.s, r.j))]
		_dire(_etat.evenements[0].texte)
	else:
		_etat = {}
		_horloge.text = "Entraînement"
		var prochain: Array = Football.prochain_coup_envoi(Football.maintenant())
		_affiche.text = "Journée 1 : %s – %s, %s à %d h" % [cd.nom, ce.nom, FootTableau.date(prochain[2]), Football.HEURE_COUP_ENVOI]
		_note("L'Étoile s'entraîne sous les projecteurs. Premier coup d'envoi %s à %d h." % [FootTableau.date(prochain[2]), Football.HEURE_COUP_ENVOI])


## Un joueur sur la pelouse, aux couleurs de son club, au banc d'abord.
func _acteur(id: String, equipe: int, couleurs: Array) -> Node3D:
	if _acteurs.has(id):
		return _acteurs[id]
	var j: Dictionary = _joueurs[id]
	var c := CRITTER.new()
	c.randomize_look(Hasard.graine(id))
	c.look["top"] = "pull"
	c.look["top_color"] = str(couleurs[0])
	c.look["legs"] = "pantalon"
	c.look["legs_color"] = str(couleurs[1]) if couleurs.size() > 1 else "#ffffff"
	c.look["shoes"] = "#1a1a1a"
	c.look.erase("hat")
	c.look.erase("prop_r")
	c.look.erase("apron")
	if j.poste == "G":
		c.look["top_color"] = "#2a8f3a" if str(couleurs[0]).to_lower() != "#0f6b3f" else "#d98f2a"
	c.scale = Vector3.ONE * PEOPLE_SCALE
	c.walk_speed = 1.0
	c.run_speed = 1.6
	c.position = Vector3((-7.0 if equipe == 0 else 7.0), 0, -P / 2.0 - 1.6)
	add_child(c)
	_acteurs[id] = c
	_cibles[id] = c.position
	return c


## Où chaque joueur doit être : sa case de formation, l'équipe glissant vers le ballon. L'équipe à domicile
## défend le but ouest (x < 0) et attaque vers l'est.
func _placer(dun_coup := false) -> void:
	var etat: Dictionary = _etat if not _etat.is_empty() else _entrainement()
	for i in 2:
		var eq: Dictionary = etat.equipes[i]
		var cases: Array = FootMatch.FORMATIONS.get(eq.formation, FootMatch.FORMATIONS["4-4-2"])
		var sens := 1.0 if i == 0 else -1.0
		var glisse := clampf(_cible_ballon.x * 0.35, -6.0, 6.0)
		var prises: Array = []
		for e in eq.onze:
			# Sa case : celle de son poste encore libre, sinon la première libre.
			var cs: Array = []
			for k in cases.size():
				if not (k in prises) and cases[k][0] == e.poste:
					cs = cases[k]
					prises.append(k)
					break
			if cs.is_empty():
				for k in cases.size():
					if not (k in prises):
						cs = cases[k]
						prises.append(k)
						break
			if cs.is_empty():
				cs = cases[-1]
			var along: float = (50.0 - cs[3]) / 50.0 * (L / 2.0 * 0.88)
			var across: float = (cs[2] - 50.0) / 50.0 * (P / 2.0 * 0.85)
			var cible := Vector3(sens * along, 0, sens * across)
			if e.poste != "G":
				cible.x += glisse
				cible.x = clampf(cible.x, -L / 2.0 + 0.5, L / 2.0 - 0.5)
			_cibles[e.id] = cible
			if dun_coup and _acteurs.has(e.id):
				_acteurs[e.id].position = cible
	if dun_coup:
		_ballon.position = Vector3(_cible_ballon.x, 0.22, _cible_ballon.z)


## Deux lignes qui trottinent autour du rond central, avant la saison.
func _entrainement() -> Dictionary:
	var faux := {"equipes": []}
	var direct: Dictionary = Football.rencontre_en_direct(_rencontre.s, _rencontre.j, _rencontre.dom, _rencontre.ext)
	for i in 2:
		faux.equipes.append({"onze": direct.etat.equipes[i].onze, "formation": direct.etat.equipes[i].formation})
	return faux


func _process(delta: float) -> void:
	_credits.text = "%s crédits" % Game.fmt(Game.credits)
	var t: Node = player.focus_target if player else null
	_prompt.visible = t != null
	if t != null:
		_prompt.text = str(t.get_meta("prompt", ""))
	# Le match avance d'une minute par seconde (quatre avec Espace), la mi-temps dure quelques secondes.
	if not _etat.is_empty() and not _etat.fini:
		_chrono += delta * _vitesse
		while _chrono >= CADENCE and not _etat.fini:
			_chrono -= CADENCE
			_minute()
	elif _etat.is_empty():
		# L'entraînement : le ballon se promène, les joueurs le suivent.
		_chrono += delta
		if _chrono > 2.5:
			_chrono = 0.0
			_cible_ballon = Vector3(randf_range(-L / 3.0, L / 3.0), 0, randf_range(-P / 3.0, P / 3.0))
			_placer()
	# Le ballon et les joueurs courent vers leur cible.
	var b := _ballon.position
	var vers := Vector3(_cible_ballon.x, 0.22, _cible_ballon.z)
	_ballon.position = b.move_toward(vers, delta * 14.0)
	_ballon.position.y = 0.22 + maxf(0.0, sin(Time.get_ticks_msec() / 90.0) * 0.08) * (1.0 if b.distance_to(vers) > 0.5 else 0.0)
	for id in _acteurs:
		var c: Node3D = _acteurs[id]
		var cible: Vector3 = _cibles.get(id, c.position)
		if c.position.distance_to(cible) > 0.15:
			var d := (cible - c.position)
			d.y = 0.0
			c.position = c.position.move_toward(cible, delta * COURSE)
			c.rotation.y = lerp_angle(c.rotation.y, atan2(d.x, d.z), 0.15)
		elif not _etat.is_empty():
			var vb := _ballon.position - c.position
			c.rotation.y = lerp_angle(c.rotation.y, atan2(vb.x, vb.z), 0.05)


## Une minute de match : les événements font bouger le ballon, parler le commentateur, tenir le tableau.
func _minute() -> void:
	var avant: Array = [_etat.stats[0].possession, _etat.stats[1].possession]
	var evenements: Array = FootMatch.avancer(_etat, _joueurs, _hasard)
	var qui: int = 0 if _etat.stats[0].possession > avant[0] else 1
	_horloge.text = "Journée %d  ·  %s" % [_rencontre.j, FootMatch.libelle_minute(_etat)]
	var sens := 1.0 if qui == 0 else -1.0
	# Sans événement, le ballon circule dans le camp de celui qui l'a.
	if evenements.is_empty() or evenements.all(func(e): return e.type in ["ambiance", "info"]):
		_cible_ballon = Vector3(sens * randf_range(-4.0, 10.0), 0, randf_range(-P / 2.0 + 3.0, P / 2.0 - 3.0))
	for ev in evenements:
		_evenement(ev)
	_placer()
	if _etat.pause == "mi-temps":
		_chrono = -6.0 * _vitesse
		_placer(true)
	if _etat.fini and not _fini_annonce:
		_fini_annonce = true
		_vitesse = 1.0


func _evenement(ev: Dictionary) -> void:
	var i: int = int(ev.equipe)
	var sens := 1.0 if i == 0 else -1.0
	match str(ev.type):
		"occasion":
			_cible_ballon = Vector3(sens * (L / 2.0 - 4.0), 0, randf_range(-4.0, 4.0))
		"but":
			_cible_ballon = Vector3(sens * (L / 2.0 + 0.8), 0, randf_range(-1.2, 1.2))
			_marquer(i, ev)
		"arret", "rate", "poteau":
			_cible_ballon = Vector3(sens * (L / 2.0 - 1.5), 0, randf_range(-3.0, 3.0))
		"rouge":
			if _acteurs.has(ev.get("joueur", "")):
				_cibles[ev.joueur] = Vector3(sens * 7.0, 0, -P / 2.0 - 1.6)
		"remplacement":
			var club: Dictionary = Football.clubs[_rencontre.dom if i == 0 else _rencontre.ext]
			_acteur(ev.entrant, i, club.couleurs)
			_cibles[ev.sortant] = Vector3((-7.0 if i == 0 else 7.0) + randf_range(-1.5, 1.5), 0, -P / 2.0 - 1.6)
		"reprise":
			_cible_ballon = Vector3.ZERO
	if ev.type != "info" or _etat.minute in [45, 90]:
		_dire(str(ev.texte))


## Le but : le tableau change, le buteur lève les bras, la tribune se lève.
func _marquer(i: int, ev: Dictionary) -> void:
	var cd: Dictionary = Football.clubs[_rencontre.dom]
	var ce: Dictionary = Football.clubs[_rencontre.ext]
	_score.text = "%s  %d - %d  %s" % [cd.court, _etat.score[0], _etat.score[1], ce.court]
	if _acteurs.has(ev.get("joueur", "")):
		_acteurs[ev.joueur].cheer(2.0)
	var origine: Commune = Communes.origine()
	var chez_nous: bool = origine != null and (_rencontre.dom if i == 0 else _rencontre.ext) == origine.id
	for s in _supporters:
		if chez_nous:
			s.cheer(2.4)
		elif randf() < 0.2:
			s.gesture("facepalm")
	Sfx.result(1, 50 if chez_nous else 0)


func _dire(texte: String) -> void:
	_speech.text = texte
	_show_speech()


func _note(texte: String) -> void:
	_dire(texte)


func _show_speech() -> void:
	_speech.modulate.a = 1.0
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = create_tween()
	_speech_tween.tween_interval(3.0 + _speech.text.length() * 0.03)
	_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.8)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and not _etat.is_empty():
		_vitesse = 4.0 if _vitesse == 1.0 else 1.0
		_dire("Le match passe %s." % ("en accéléré (Espace pour revenir)" if _vitesse > 1.0 else "au rythme normal"))
		get_viewport().set_input_as_handled()


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"exit":
			Game.return_point = "stade"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		"buvette":
			_dire(["« Un café, un. C'est la femme du président qui tient la buvette, et elle ne fait pas crédit. »",
				"« Le chocolat chaud, c'est pour les moins de douze ans et les gardiens de but. »",
				"« Le président Chauvin dit que l'Étoile montera. Il le dit depuis 1987. »"].pick_random())


# --- Capture --------------------------------------------------------------------------------------

func _maybe_capture() -> void:
	var path := ""
	var minute := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split_floats(",")
			player.position = Vector3(v[0], 0, v[1])
			player.rotation.y = deg_to_rad(v[2])
			if v.size() > 3:
				player.camera.rotation.x = deg_to_rad(v[3])
		elif arg.begins_with("--minute="):
			minute = int(arg.trim_prefix("--minute="))
		elif arg.begins_with("--journee="):
			pass
		else:
			_capture_setup(arg)
	if path == "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Le match est avancé d'un coup jusqu'à la minute demandée, les joueurs posés où ils doivent être.
	while not _etat.is_empty() and not _etat.fini and _etat.minute < minute:
		_minute()
		_placer(true)
	_chrono = -100.0
	await get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## L'horloge du football, posée avant que la scène ne choisisse son match (--journee=n), et le total gagné.
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			Football.dossier = ""
		elif arg.begins_with("--journee="):
			var t: int = Football.coup_envoi(1, int(arg.trim_prefix("--journee="))) + 3600
			Football.regler_horloge(func(): return t)
