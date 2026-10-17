extends Node3D
## Planche des personnages : tout le monde en rang, de face et de dessus, pour juger la famille d'un coup d'œil.
## godot --path . res://tools/lineup.tscn -- --capture=planche.png [--top] [--anim=walk] [--close]

const VILLAGER := preload("res://scripts/villager.gd")
const KC := "res://assets/kenney/characters/"

## [modèle, accessoire, voix, légende, pose]
const CAST := [
	["joueur", "noeud", "joueur", "le joueur", "idle"],
	["josiane", "collier", "josiane", "Josiane", "idle"],
	["dede", "", "dede", "Dédé", "idle"],
	["lucien", "chapeau", "lucien", "Lucien", "idle"],
	["m-brunet", "cravate", "brunet", "M. Brunet", "idle"],
	["mme-ferrand", "", "ferrand", "Mme Ferrand", "idle"],
	["m-gaudin", "noeud", "gaudin", "M. Gaudin", "idle"],
	["gardien-du-bois", "chapeau", "gardien", "le gardien", "idle"],
	["meunier", "chapeau", "meunier", "le meunier", "idle"],
	["inconnu", "chapeau", "inconnu", "l'Inconnu", "idle"],
	["m-castel", "noeud", "castel", "M. Castel", "idle"],
	["portier-salon", "chapeau", "armand", "M. Armand", "idle"],
	["hotesse-1", "collier", "hotesse", "l'hôtesse", "idle"],
	["croupier-roulette", "noeud", "croupier", "le croupier", "idle"],
	["croupiere-blackjack", "noeud", "croupier", "la croupière", "idle"],
	["barman-nocturne", "noeud", "barman", "le barman", "idle"],
	["caissier", "noeud", "caissier", "le caissier", "idle"],
	["chanteuse", "collier", "habitant", "la chanteuse", "idle"],
	["baron-de-vasseur", "chapeau", "habitant", "le baron", "idle"],
	["capucine-varenne", "chapeau", "habitant", "Capucine", "idle"],
	["fradin", "", "fradin", "Roger Fradin", "idle"],
	["character-female-c.glb", "", "habitant", "habitante", "idle"],
	["maitre-garnier", "", "garnier", "Maître Garnier", "idle"],
	["raymonde", "", "raymonde", "Raymonde", "idle"],
	["ginette-boutin", "", "ginette", "Ginette Boutin", "idle"],
]

## La planche des mouvements : [modèle, voix, mouvement, légende].
const MOVES := [
	["joueur", "joueur", "walk", "marche"], ["joueur", "joueur", "run", "court"], ["dede", "dede", "sit", "assis"],
	["lucien", "lucien", "talk", "parle"], ["josiane", "josiane", "wave", "salue"], ["character-male-b.glb", "habitant", "jump", "joie"],
	["character-female-c.glb", "habitant", "sulk", "dépit"], ["character-male-e.glb", "habitant", "stomp", "dépit, debout"],
	["teddy", "habitant", "bet", "mise ses jetons"],
	["croupier-roulette", "croupier", "spin", "lance la bille"], ["croupiere-blackjack", "croupier", "deal", "donne une carte"], ["croupier-roulette", "croupier", "rake", "ratisse"], ["croupiere-blackjack", "croupier", "pay", "distribue les jetons"],
	["barman-nocturne", "barman", "bar", "essuie un verre"], ["hotesse-1", "hotesse", "bow", "révérence"],
	["pianiste", "habitant", "piano", "au piano"], ["chanteuse", "habitant", "sing", "chante"],
	["caissier", "caissier", "look_watch", "regarde l'heure"], ["gardien-du-bois", "gardien", "scratch", "se gratte la tête"],
	["capucine-varenne", "habitant", "drink", "boit"],
]
const MOOD := {"jump": "joie", "sulk": "depit", "stomp": "depit", "talk": "joie", "wave": "joie", "bet": "attention", "drink": "joie"}

var people: Array[Node3D] = []


func _ready() -> void:
	var args := " ".join(OS.get_cmdline_user_args())
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.07, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.4, 0.6)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.4
	e.ssao_enabled = true
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.78, 0.52)
	key.light_energy = 1.4
	key.shadow_enabled = OS.get_environment("NOSHADOW") == ""
	key.rotation_degrees = Vector3(-38, 28, 0)
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.45, 0.55, 1.0)
	rim.light_energy = 0.7
	rim.rotation_degrees = Vector3(-20, 200, 0)
	add_child(rim)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 12)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.2, 0.13)
	fm.roughness = 0.7
	floor_mi.material_override = fm
	add_child(floor_mi)

	var moves := "--moves" in args
	var list: Array = CAST
	var moves_list: Array = MOVES
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			var only := a.trim_prefix("--only=").split(",")
			moves_list = MOVES.filter(func(m): return m[2] in only)
	if moves:
		list = moves_list.map(func(m): return [m[0], "", m[1], m[3], m[2]])
	# --tenues : le renard du joueur dans chaque tenue de Cast.PLAYER_OUTFITS.
	var tenues := "--tenues" in args
	if tenues:
		list = Cast.PLAYER_OUTFITS.keys().map(func(o): return ["joueur", "", "joueur", o.replace("_", " "), "idle"])
	# --part=N : une rangée de neuf, de plus près, pour la planche.
	var part := -1 if not tenues else 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = int(a.trim_prefix("--part="))
			list = CAST.slice(part * 9, part * 9 + 9)
	var per_row := mini(9, list.size()) if moves or part >= 0 else 12
	var gap := 0.78 if moves else (0.55 if part >= 0 else 0.62)
	for i in list.size():
		var c: Array = list[i]
		var row := i / per_row
		var col := i % per_row
		var v: Node3D = VILLAGER.new()
		v.accessory = c[1]
		v.speaker = c[2]
		v.model_path = (KC + c[0]) if c[0].ends_with(".glb") else c[0]
		v.pose = "sit" if c[4] in ["sit", "piano"] else "idle"
		v.position = Vector3((col - (per_row - 1) / 2.0) * gap, 0, -row * 1.15)
		add_child(v)
		people.append(v)
		if tenues:
			v.critter.set_look(Cast.player(Cast.PLAYER_OUTFITS.keys()[i]))
		if not moves and v.critter.get("_blink_wait") != null:
			v.critter.set("_blink_wait", 99.0)  # les yeux ouverts sur la planche
		if c[0] == "joueur" and v.critter.get("skeleton") == null:
			# L'ancien renard du joueur, tel que main.gd le fabriquait.
			v.critter.queue_free()
			var me: Node3D = VILLAGER.CRITTER.new()
			me.species = "renard"
			me.fur = Color(1.0, 0.62, 0.32)
			me.outfit = Color(0.1, 0.12, 0.25)
			me.accessory = "noeud"
			v.add_child(me)
		var l := Label3D.new()
		l.text = c[3]
		l.font_size = 30
		l.pixel_size = 0.0022
		l.modulate = Color(1.0, 0.86, 0.55)
		l.outline_size = 8
		l.position = Vector3(0, 0.02, 0.32)
		l.rotation_degrees.x = -90 if "--top" in args or "--rue" in args or "--quartier" in args else -20
		v.add_child(l)

	var cam := Camera3D.new()
	add_child(cam)
	if "--top" in args:
		cam.position = Vector3(0, 6.5, 2.2)
		cam.rotation_degrees = Vector3(-62, 0, 0)
		cam.fov = 48
	elif "--close" in args:
		cam.position = Vector3(-2.2, 0.62, 1.45)
		cam.rotation_degrees = Vector3(-8, 0, 0)
		cam.fov = 40
	else:
		cam.position = Vector3(0, 2.3, 4.3)
		cam.rotation_degrees = Vector3(-25, 0, 0)
		cam.fov = 50
	# Les crans de la caméra extérieure de la suite (docs/SUITE.md) : Rue à 22 u et 52°, Quartier à 40 u et 60°.
	for cran in [["--rue", 22.0, 52.0], ["--quartier", 40.0, 60.0]]:
		if cran[0] in args:
			cam.position = Vector3(0, cran[1], cran[1] / tan(deg_to_rad(cran[2])))
			cam.rotation_degrees = Vector3(-cran[2], 0, 0)
			cam.fov = 30
	if part >= 0 and not "--top" in args:
		cam.position = Vector3(0, 0.5, 3.35)
		cam.rotation_degrees = Vector3(-3, 0, 0)
		cam.fov = 50
	if moves:
		cam.position = Vector3(0, 1.75, 4.1)
		cam.rotation_degrees = Vector3(-20, 0, 0)
		cam.fov = 52
		if moves_list.size() <= 5:
			cam.position = Vector3(0.0, 0.62, 2.9)
			cam.rotation_degrees = Vector3(-5, 0, 0)
			cam.fov = 40
		for i in people.size():
			_move(people[i], moves_list[i][2])
	cam.make_current()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--anim="):
			_apply_anim(a.trim_prefix("--anim="))
	_capture()


## Un mouvement saisi en plein milieu au moment de la capture (2 s après le départ).
func _move(v: Node3D, what: String) -> void:
	if what in CritterAnims.BASE:
		v.debug_anim(what)
		return
	var length := CritterAnims.library().get_animation(what).length
	var at := maxf(0.05, 2.0 - length * 0.45)
	get_tree().create_timer(at).timeout.connect(func():
		v.debug_anim(what)
		if MOOD.has(what):
			v.critter.set_expression(MOOD[what], 10.0)
		if what == "talk":
			v.critter.talk(10.0))


func _apply_anim(what: String) -> void:
	for v in people:
		if v.has_method("debug_anim"):
			v.debug_anim(what)


func _capture() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			path = a.trim_prefix("--capture=")
	if path == "":
		return
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
