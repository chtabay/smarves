extends SceneTree
## Les planches des briques du décor du Bugey (facadier-du-bugey@1, mobilier-du-bugey@1, vegetation-du-bugey@1,
## terrains-du-bugey@1), sous un ciel d'été franc, et les ambiances qu'on compose avec elles :
## godot --path . -s tools/planche_bugey.gd -- --vue=facadier --capture=planche.png
##   --nom=fontaine    avec mobilier, vegetation ou terrains : une seule pièce, de près
##   --vue=facadier    les onze bâtisses, en rangée
##   --vue=detail      la même rangée vue en enfilade, pour lire le relief des façades
##   --vue=appareil    la même maison en moellons réguliers et irréguliers (--nom=pres : le mur irrégulier de près)
##   --vue=mobilier    chaque objet du mobilier, avec son nom
##   --vue=vegetation  chaque plante, avec son nom
##   --vue=terrains    les champs, les chemins, les murets, le talus et la rivière
## Les ambiances, composées avec les quatre briques et les essences des autres (le tilleul et le bouleau des arbres
## de place, le cyprès de la végétation lyonnaise, les pavés en éventail des quais lyonnais) :
##   --vue=place       la place du village sous les falaises : la fontaine à la statue, le marché, le porche
##   --vue=rue         la grand-rue à hauteur d'œil : les boutiques, les enseignes, la chapelle au bout
##   --vue=hameau      le hameau vigneron : la ferme, la maison à escalier, les vignes en terrasses, le puits
##   --vue=riviere     le bord de rivière : les maisons sur la rive, les roseaux, le chemin de halage, les murets
##   --vue=campagne    les champs au pied des falaises : le blé, le maïs, les haies, la chapelle sur sa butte
## Sans carte graphique : xvfb-run avec --rendering-driver opengl3.

const FACADIER := "facadier-du-bugey@1"
const MOBILIER := "mobilier-du-bugey@1"
const VEGETATION := "vegetation-du-bugey@1"
const TERRAINS := "terrains-du-bugey@1"
const ARBRES := "arbres-de-place@1"
const LYON := "vegetation-lyonnaise@1"
const PAVES := "quais-lyonnais@1"

var monde: Node3D


func _init() -> void:
	await process_frame
	var vue := "place"
	var capture := "user://planche_bugey.png"
	var nom := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vue="):
			vue = a.trim_prefix("--vue=")
		elif a.begins_with("--capture="):
			capture = a.trim_prefix("--capture=")
		elif a.begins_with("--nom="):
			nom = a.trim_prefix("--nom=")
	root.size = Vector2i(1920, 1080)
	monde = Node3D.new()
	root.add_child(monde)
	_ciel()
	var cam := Camera3D.new()
	cam.fov = 45
	cam.far = 1500
	monde.add_child(cam)
	match vue:
		"appareil":
			_sol(Vector2(80, 60), Color("b8a27a"))
			_pose(FACADIER, "type", "r1", Vector3(-5.5, 0, 0), 4, {"w": 10.0, "mur": "moellons", "appareil": "regulier"})
			_pose(FACADIER, "type", "r1", Vector3(5.5, 0, 0), 4, {"w": 10.0, "mur": "moellons", "appareil": "irregulier"})
			_etiquette(Vector3(-5.5, 0.05, 3.0), "regulier")
			_etiquette(Vector3(5.5, 0.05, 3.0), "irregulier")
			cam.fov = 50
			if nom == "pres":
				cam.look_at_from_position(Vector3(6.5, 2.2, 5.5), Vector3(5.0, 2.4, 0))
			else:
				cam.look_at_from_position(Vector3(0, 5, 21), Vector3(0, 3.5, 0))
		"facadier", "detail":
			_sol(Vector2(160, 70), Color("b8a27a"))
			var types: Array = load(Bibliotheque.scene(FACADIER, "decor")).instantiate().types()
			var x := -62.0
			for t in types:
				var m := _pose(FACADIER, "type", t, Vector3(x, 0, 0), types.find(t) + 1, {})
				var w: float = m.get_meta("w")
				m.position.x += w * 0.5
				if t == "chapelle":
					m.position.x -= 1.6
				if vue == "facadier":
					_etiquette(Vector3(x + w * 0.5, 0.05, 3.0), t)
				x += w + 1.2
			if vue == "facadier":
				cam.fov = 38
				cam.look_at_from_position(Vector3(-6, 20, 98), Vector3(-6, 5, -4))
			else:
				cam.fov = 50
				cam.look_at_from_position(Vector3(-66, 2.5, 10), Vector3(-44, 7, -1))
		"mobilier", "vegetation", "terrains":
			var id: String = {"mobilier": MOBILIER, "vegetation": VEGETATION, "terrains": TERRAINS}[vue]
			var cle: String = {"mobilier": "objet", "vegetation": "plante", "terrains": "module"}[vue]
			var noms: Array = load(Bibliotheque.scene(id, "decor")).instantiate().noms()
			var par: int = {"terrains": 5, "vegetation": 4}.get(vue, 6)
			var pas: float = {"terrains": 9.0, "vegetation": 8.0}.get(vue, 4.8)
			_sol(Vector2(par * pas + 60, 80), Color("b8a27a"))
			if nom != "":
				# une seule pièce, de près
				var b := _pose(id, cle, nom, Vector3(0, 0.95 if nom == "riviere" else 0.0, 0), 1, {})
				var e: Vector2 = b.get_meta("emprise", Vector2(4, 4))
				var r := maxf(maxf(e.x, e.y), 2.0)
				var h: float = b.get_meta("hauteur", r * 0.5)
				cam.look_at_from_position(Vector3(r * 0.55, maxf(r * 0.45, h * 0.6), r * 0.95 + h * 0.4), Vector3(0, h * 0.35, 0))
				noms = []
			elif vue == "mobilier":
				# la fontaine à la statue, trop grande pour la grille, à gauche
				_pose(id, cle, noms[0], Vector3(-(par + 1) * pas * 0.5 - 5.0, 0, 0), 1, {})
				_etiquette(Vector3(-(par + 1) * pas * 0.5 - 5.0, 0.3, 5.5), noms[0], 0.007)
				noms.remove_at(0)
			elif vue == "terrains":
				# la falaise, trop grande pour la grille, ferme le fond
				_pose(id, cle, "falaise", Vector3(0, 0, -pas * 2.6), 1, {"largeur": 46.0})
				noms.erase("falaise")
			for i in noms.size():
				var p := Vector3((i % par - (par - 1) * 0.5) * pas, 0, floorf(i / float(par)) * pas * 1.4 - pas)
				# la rivière coule sous le sol : sur la planche, on la hausse jusqu'à lui
				var b := _pose(id, cle, noms[i], p, i + 1, {})
				if noms[i] == "riviere":
					b.position.y += 0.95
				_etiquette(p + Vector3(0, 0.3, pas * 0.45), noms[i], 0.0045 if vue != "terrains" else 0.007)
			var rangs := ceilf(noms.size() / float(par))
			var centre := Vector3(-4.0 if vue == "mobilier" else 0.0, 0.5, (rangs - 1) * pas * 0.62 - pas)
			if nom == "":
				var recul: float = {"terrains": 1.5, "vegetation": 1.7}.get(vue, 0.85)
				cam.look_at_from_position(centre + Vector3(0, 17, 25) * recul, centre + Vector3(0, 3.0 if vue == "vegetation" else 0.0, 0))
		"place":
			_place()
			cam.fov = 58
			cam.look_at_from_position(Vector3(1, 15, 29), Vector3(0, 5.5, -20))
		"rue":
			_rue()
			cam.fov = 60
			cam.look_at_from_position(Vector3(1.2, 1.7, 15), Vector3(-0.5, 5.0, -40))
		"hameau":
			_hameau()
			cam.fov = 52
			cam.look_at_from_position(Vector3(14, 17, 36), Vector3(-2, 2, -12))
		"riviere":
			_riviere()
			cam.fov = 55
			cam.look_at_from_position(Vector3(-14, 10, 22), Vector3(4, 0.5, -6))
		"campagne":
			_campagne()
			cam.fov = 55
			cam.look_at_from_position(Vector3(12, 15, 36), Vector3(-6, 2, -26))
		"un":
			_sol(Vector2(60, 60), Color("b8a27a"))
			var m := _pose(FACADIER, "type", nom, Vector3.ZERO, 3, {})
			var w: float = m.get_meta("w")
			cam.look_at_from_position(Vector3(w * 0.9, w * 0.6, w * 1.5), Vector3(0, 4, -3))
	for _k in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture)
	print("Planche %s : %s" % [vue, capture])
	quit(0)


func _ciel() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("#4f9fe0")
	ciel.sky_horizon_color = Color("#d6e8f0")
	ciel.ground_horizon_color = Color("#d6e8f0")
	ciel.ground_bottom_color = Color("#8c8a78")
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ciel
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b8c8d8")
	env.environment.ambient_light_energy = 0.3
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	env.environment.ssao_intensity = 1.4
	monde.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-46, -38, 0)
	soleil.light_color = Color("#fff0d4")
	soleil.light_energy = 0.62
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 200.0
	monde.add_child(soleil)


func _sol(taille: Vector2, couleur: Color, centre := Vector3.ZERO) -> void:
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = taille
	sol.mesh = plan
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 1.0
	sol.material_override = m
	sol.position = centre + Vector3(0, -0.01, 0)
	monde.add_child(sol)


func _etiquette(p: Vector3, texte: String, taille := 0.012) -> void:
	var l := Label3D.new()
	l.text = texte.replace("_", " ")
	l.font_size = 96
	l.pixel_size = taille
	l.modulate = Color("#2a2a2a")
	l.outline_size = 0
	l.rotation_degrees = Vector3(-55, 0, 0)
	l.no_depth_test = true
	l.position = p
	monde.add_child(l)


## Pose une brique : cle est la propriété qui choisit la variante (type, objet, plante, module).
func _pose(id: String, cle: String, valeur: String, p: Vector3, g: int, opt: Dictionary, lacet := 0.0) -> Node3D:
	var b: Node3D = load(Bibliotheque.scene(id, "decor")).instantiate()
	b.set(cle, valeur)
	b.graine = g
	b.options = opt
	b.position = p
	b.rotation.y = lacet
	monde.add_child(b)
	return b


## Une rangée d'immeubles de a vers b, façades tournées selon lacet ; les types pris dans l'ordre, en boucle.
func _rangee(a: Vector3, b: Vector3, lacet: float, types: Array, graine: int, opts := {}) -> Array:
	var dir := (b - a).normalized()
	var long := (b - a).length()
	var fait := 0.0
	var i := 0
	var poses := []
	while fait < long - 4.0:
		var t: String = types[i % types.size()]
		var opt: Dictionary = opts.get(t, {}).duplicate()
		var m := _pose(FACADIER, "type", t, Vector3.ZERO, graine * 31 + i, opt, lacet)
		var w: float = m.get_meta("w")
		m.position = a + dir * (fait + w * 0.5)
		poses.append(m)
		fait += w
		i += 1
	return poses


func _arbre(espece: String, p: Vector3, g: int, opt := {}) -> Node3D:
	return _pose(ARBRES, "espece", espece, p, g, opt)


func _plante(nom: String, p: Vector3, g: int, opt := {}, lacet := 0.0) -> Node3D:
	return _pose(VEGETATION, "plante", nom, p, g, opt, lacet)


func _objet(nom: String, p: Vector3, g: int, opt := {}, lacet := 0.0) -> Node3D:
	return _pose(MOBILIER, "objet", nom, p, g, opt, lacet)


func _module(nom: String, p: Vector3, g: int, opt := {}, lacet := 0.0) -> Node3D:
	return _pose(TERRAINS, "module", nom, p, g, opt, lacet)


func _maison(type: String, p: Vector3, g: int, opt := {}, lacet := 0.0) -> Node3D:
	return _pose(FACADIER, "type", type, p, g, opt, lacet)


## L'horizon du Bugey : une longue colline boisée de chênes, de charmes et de cèdres, couronnée de falaises
## calcaires ; c le pied du milieu, R ses rayons.
func _horizon(c: Vector3, R: Vector3, graine: int, falaises := true) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 64
	sphere.rings = 32
	mi.mesh = sphere
	mi.scale = R
	mi.position = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("6c8c3e")
	m.roughness = 1.0
	mi.material_override = m
	monde.add_child(mi)
	var r := RandomNumberGenerator.new()
	r.seed = graine
	var sommet := c.y + R.y * 0.5
	if falaises:
		var x := -R.x * 0.42
		while x < R.x * 0.42:
			var u := x / (R.x * 0.5)
			var y := c.y + R.y * 0.5 * sqrt(maxf(0.0, 1.0 - u * u)) - 9.0
			_module("falaise", Vector3(x, y, c.z + R.z * 0.18), graine + int(x), {"largeur": 34.0, "hauteur": r.randf_range(16.0, 24.0)})
			x += 34.0 + r.randf_range(4.0, 20.0)
	for i in 240:
		var u := r.randf_range(-0.9, 0.9)
		var v := r.randf_range(0.2, 0.92)
		var y := 1.0 - u * u - (1.0 - v) * (1.0 - v)
		if y <= 0.04:
			continue
		var q := c + Vector3(u * R.x * 0.5, sqrt(y) * R.y * 0.5, (1.0 - v) * R.z * 0.5)
		if q.y < 0.5 or (falaises and q.y > sommet - 14.0):
			continue
		var nom: String = ["chene", "charme", "cedre", "chene", "charme"][r.randi() % 5]
		_plante(nom, q - Vector3(0, 0.4, 0), 300 + i, {"hauteur": {"chene": 11.0, "charme": 9.0, "cedre": 13.0}[nom] * r.randf_range(0.9, 1.4), "vent": 0.3})


## La place du village sous les falaises, d'après l'ambiance de Guillaume : la place pavée en éventail, la fontaine
## ronde fleurie et sa statue, le porche aux bannières, le clocher derrière, le marché, les tilleuls et les bouleaux.
func _place() -> void:
	_sol(Vector2(300, 260), Color("9ea464"), Vector3(0, 0, -60))
	for i in 8:
		for j in 7:
			_pose(PAVES, "module", "paves_eventail" if (i + j) % 3 != 0 else "paves", Vector3(-14 + i * 4, 0, 10 - j * 4), i * 7 + j + 1, {})
	_objet("fontaine_statue", Vector3(0, 0, -1), 1, {})
	# le fond de la place : le porche au milieu, les maisons de part et d'autre ; le clocher de la chapelle derrière
	_maison("porche", Vector3(0, 0, -15), 3, {"couverture": "tuile_vieillie"})
	_rangee(Vector3(-30, 0, -15), Vector3(-4.2, 0, -15), 0.0, ["r1", "r2", "bourgeoise"], 7, {"r1": {"couverture": "tuile_rouge"}})
	_rangee(Vector3(4.2, 0, -15), Vector3(30, 0, -15), 0.0, ["r2", "r1", "r2"], 11, {"r2": {"couverture": "ardoise"}})
	_maison("chapelle", Vector3(-3, 0, -32), 2, {"clocher": "tour"})
	# les deux côtés : à gauche le café et ses tables, à droite la vigneronne et les étals
	_rangee(Vector3(-15, 0, 14), Vector3(-15, 0, -15), PI * 0.5, ["r1", "r2", "village", "redents"], 5, {"r1": {"rdc": "boutique", "enseigne": "CAFÉ DU BUGEY", "toile": ["4f8a4a", "f3ead6"]}})
	_rangee(Vector3(15, 0, -15), Vector3(15, 0, 14), -PI * 0.5, ["r2", "vigneronne", "r1", "bourgeoise"], 13, {"r1": {"rdc": "boutique", "enseigne": "FROMAGERIE"}})
	# le marché, la charrette, les tonneaux
	_objet("etal", Vector3(10.5, 0, -6.0), 2, {"marchandise": "primeurs"}, -PI * 0.5)
	_objet("etal", Vector3(10.5, 0, -2.8), 3, {"marchandise": "fromages", "toile": ["2f5f8f", "f3ead6"]}, -PI * 0.5)
	_objet("etal", Vector3(10.5, 0, 0.4), 4, {"marchandise": "fleurs", "toile": ["d08a3a", "f3ead6"]}, -PI * 0.5)
	_objet("charrette", Vector3(7.0, 0, 9.0), 5, {}, -0.6)
	_objet("tonneaux", Vector3(9.5, 0, 6.0), 6, {})
	_objet("caisses", Vector3(12.0, 0, 3.0), 7, {})
	# la terrasse du café
	for k in 3:
		_objet("table", Vector3(-11.5, 0, 6.0 - k * 2.6), 8 + k, {}, PI * 0.5)
	_objet("tonnelle", Vector3(-11.8, 0, -3.5), 3, {}, PI * 0.5)
	# les bancs, les lampadaires, les jardinières, le panneau, le bachal
	_objet("banc", Vector3(-4.5, 0, 5.5), 2, {}, PI + 0.5)
	_objet("banc_fer", Vector3(4.5, 0, 5.5), 3, {}, PI - 0.5)
	_objet("lampadaire", Vector3(6.0, 0, 6.0), 4, {})
	_objet("lampadaire", Vector3(-6.5, 0, -8.5), 5, {})
	_objet("jardiniere", Vector3(-6.0, 0, 10.5), 6, {"longueur": 3.0})
	_objet("jardiniere", Vector3(6.0, 0, -10.0), 7, {"longueur": 2.6}, PI * 0.5)
	_objet("panneau", Vector3(-8.5, 0, -11.0), 8, {})
	_objet("bachal", Vector3(12.5, 0, -10.5), 9, {}, -PI * 0.5)
	# les arbres : des tilleuls et des bouleaux aux coins, des fleurs au pied des façades
	_arbre("tilleul", Vector3(-10.0, 0, 10.0), 3, {"pied": "bordure", "hauteur": 8.0})
	_arbre("tilleul", Vector3(10.5, 0, 11.5), 4, {"pied": "bordure", "hauteur": 8.5})
	_arbre("bouleau", Vector3(-9.5, 0, -9.0), 5, {"hauteur": 9.0})
	_arbre("bouleau", Vector3(8.5, 0, -9.5), 6, {"hauteur": 8.0})
	_plante("fleurs", Vector3(-13.6, 0, 9.5), 2, {})
	_plante("fleurs", Vector3(13.4, 0, -12.0), 3, {})
	_plante("arbuste_fleuri", Vector3(13.2, 0, 12.5), 4, {})
	_plante("cerisier", Vector3(-13.0, 0, -12.4), 5, {"saison": "fleurs", "hauteur": 4.5})
	# l'horizon : les collines boisées et les falaises
	_horizon(Vector3(0, -14, -165), Vector3(440, 84, 120), 21)


## La grand-rue : deux rangs de maisons serrées, les boutiques au rez-de-chaussée et leurs enseignes en potence,
## les pavés, les lampadaires et les jardinières ; la chapelle ferme la rue, les falaises dominent les toits.
func _rue() -> void:
	_sol(Vector2(260, 260), Color("9ea464"), Vector3(0, 0, -60))
	for i in 3:
		for j in 16:
			_pose(PAVES, "module", "paves", Vector3(-4 + i * 4, 0, 16 - j * 4), i * 17 + j + 1, {})
	_rangee(Vector3(-6, 0, 18), Vector3(-6, 0, -44), PI * 0.5, ["r1", "r2", "village", "r1", "redents", "r2", "tour"], 3, {
		"r1": {"rdc": "boutique", "enseigne": "BOULANGERIE", "toile": ["8f3a2f", "f3ead6"]},
		"village": {"rdc": "boutique", "enseigne": "QUINCAILLERIE"}})
	_rangee(Vector3(6, 0, -44), Vector3(6, 0, 18), -PI * 0.5, ["r2", "r1", "bourgeoise", "r2", "r1", "vigneronne"], 9, {
		"r1": {"rdc": "boutique", "enseigne": "ÉPICERIE", "toile": ["2f5f8f", "f3ead6"]},
		"r2": {"couverture": "ardoise"}})
	_maison("chapelle", Vector3(0, 0, -56), 2, {"clocher": "tour"})
	_maison("porche", Vector3(-12, 0, -50), 4, {}, PI * 0.25)
	_maison("r1", Vector3(13, 0, -50), 5, {"couverture": "tuile_rouge"}, -PI * 0.25)
	for k in 4:
		_objet("lampadaire", Vector3(4.6 if k % 2 == 0 else -4.6, 0, 10 - k * 13), 10 + k, {})
	_objet("jardiniere", Vector3(-5.0, 0, 6.0), 2, {"longueur": 2.4}, PI * 0.5)
	_objet("jardiniere", Vector3(5.0, 0, -8.0), 3, {"longueur": 2.4}, PI * 0.5)
	_objet("banc", Vector3(4.8, 0, 2.0), 4, {}, -PI * 0.5)
	_objet("tonneaux", Vector3(-4.8, 0, -12.0), 5, {})
	_objet("caisses", Vector3(-4.9, 0, -14.0), 6, {})
	_objet("charrette", Vector3(3.2, 0, -20.0), 7, {}, 0.2)
	_objet("bachal", Vector3(-4.6, 0, -26.0), 8, {}, PI * 0.5)
	_objet("panneau", Vector3(4.8, 0, -30.0), 9, {}, -PI * 0.5)
	_plante("fleurs", Vector3(-5.2, 0, 12.0), 2, {})
	_plante("fleurs", Vector3(5.2, 0, -16.0), 3, {})
	_plante("arbuste_fleuri", Vector3(-5.0, 0, -36.0), 4, {})
	_arbre("tilleul", Vector3(6.5, 0, -46.0), 5, {"hauteur": 9.0})
	_horizon(Vector3(0, -14, -175), Vector3(440, 96, 120), 51)


## Le hameau vigneron : la ferme et sa grange, la maison vigneronne et son escalier, la maison de village, le
## chemin de terre bordé de murets, le puits, la tonnelle, les vignes en terrasses qui montent vers le bois.
func _hameau() -> void:
	_sol(Vector2(2000, 2000), Color("93ab55"), Vector3(0, 0, -40))
	for k in 7:
		_module("chemin", Vector3(0, 0, 20 - k * 8), k + 1, {})
	for k in 3:
		_module("prairie", Vector3(-8, 0, 20 - k * 8), k + 20, {})
		_module("prairie", Vector3(8, 0, 20 - k * 8), k + 30, {})
	_maison("ferme", Vector3(-6.5, 0, -2.0), 4, {"couverture": "tuile_vieillie"}, PI * 0.5)
	_maison("vigneronne", Vector3(-6.5, 0, 12.0), 6, {"couverture": "tuile_rouge"}, PI * 0.5)
	_maison("village", Vector3(6.5, 0, -1.0), 8, {}, -PI * 0.5)
	_maison("r0", Vector3(6.5, 0, 9.5), 9, {"couverture": "lauze"}, -PI * 0.5)
	_objet("puits", Vector3(3.0, 0, 4.5), 1, {})
	_objet("tonnelle", Vector3(-3.4, 0, 18.5), 2, {}, PI * 0.5)
	_objet("charrette", Vector3(-3.5, 0, -8.5), 3, {}, 0.4)
	_objet("tonneaux", Vector3(-3.4, 0, 9.0), 4, {})
	_objet("muret", Vector3(2.4, 0, 16.0), 5, {"longueur": 8.0}, PI * 0.5)
	_objet("banc", Vector3(3.6, 0, 1.0), 6, {}, -PI * 0.5)
	_plante("cerisier", Vector3(4.5, 0, 14.0), 2, {"saison": "fruits"})
	_plante("chene", Vector3(-12.0, 0, 24.0), 3, {})
	_plante("arbuste_fleuri", Vector3(3.2, 0, -5.5), 4, {})
	_plante("fleurs", Vector3(-3.2, 0, 3.0), 5, {})
	_plante("haie", Vector3(10.0, 0, 16.0), 6, {"longueur": 5.0})
	_pose(LYON, "plante", "cypres", Vector3(-3.0, 0, -14.0), 7, {"hauteur": 7.0})
	_arbre("tilleul", Vector3(3.5, 0, -12.0), 8, {"hauteur": 8.0})
	# les vignes en terrasses derrière le hameau, puis le bois, le talus et les falaises
	for i in 6:
		_module("vigne_coteau", Vector3(-20 + i * 8, 0, -28), 40 + i, {})
		_module("vigne_coteau", Vector3(-20 + i * 8, 2.2, -36), 50 + i, {})
	for i in 6:
		_module("talus", Vector3(-20 + i * 8, 4.4, -44), 60 + i, {})
	_horizon(Vector3(0, -6, -120), Vector3(340, 90, 120), 31)


## Le bord de rivière : l'eau claire et ses roseaux, les maisons de l'autre rive, le chemin et la route à murets
## sur la rive proche, les chênes et les charmes, le talus et les falaises au loin.
func _riviere() -> void:
	# le sol s'arrête aux berges, pour laisser voir le lit creusé de la rivière
	_sol(Vector2(2000, 1000), Color("93ab55"), Vector3(0, -0.02, -504))
	_sol(Vector2(2000, 1000), Color("93ab55"), Vector3(0, -0.02, 504))
	for k in 30:
		_module("riviere", Vector3(-116 + k * 8, 0, 0), k + 1, {})
	# la rive d'en face : une rangée de maisons, une ferme, le clocher
	_rangee(Vector3(-36, 0, -9), Vector3(-6, 0, -9), 0.0, ["village", "r1", "r2", "r0"], 17)
	_maison("ferme", Vector3(5, 0, -9), 3, {"couverture": "lauze"})
	_maison("tour", Vector3(15, 0, -9), 4, {})
	_rangee(Vector3(19, 0, -9), Vector3(44, 0, -9), 0.0, ["r1", "redents", "village"], 23)
	for k in 10:
		_module("prairie", Vector3(-36 + k * 8, 0, -6), 70 + k, {"fleurs": false}, PI)
	# la rive proche : le chemin de halage, la route et ses murets, les arbres
	for k in 12:
		_module("route_murets", Vector3(-44 + k * 8, 0, 9.5), k + 80, {}, PI * 0.5)
	_plante("chene", Vector3(-8.0, 0, 5.0), 2, {"hauteur": 10.0})
	_plante("charme", Vector3(6.0, 0, 5.2), 3, {})
	_arbre("bouleau", Vector3(-20.0, 0, 5.0), 4, {})
	_arbre("bouleau", Vector3(18.0, 0, -4.5), 5, {})
	_pose(LYON, "plante", "cypres", Vector3(-2.0, 0, -5.0), 6, {"hauteur": 8.0})
	_plante("arbuste_fleuri", Vector3(1.0, 0, 5.0), 7, {})
	_objet("banc", Vector3(-3.0, 0, 5.4), 8, {})
	_objet("lampadaire", Vector3(2.5, 0, 5.4), 9, {})
	for i in 8:
		_module("talus", Vector3(-28 + i * 8, 0, -30), 90 + i, {"hauteur": 4.0})
	_horizon(Vector3(0, -8, -120), Vector3(360, 90, 110), 41)


## Les champs au pied des falaises : le blé, le maïs et la prairie en parcelles, les haies, le chemin, le mur de
## pierre sèche, la chapelle et son cèdre sur leur butte.
func _campagne() -> void:
	_sol(Vector2(2000, 2000), Color("93ab55"), Vector3(0, 0, -60))
	var cultures := ["ble", "mais", "prairie", "ble", "prairie", "mais", "prairie", "ble"]
	for i in 8:
		for j in 6:
			var x := -32 + i * 8 + (8 if i >= 4 else 0)
			var z := 12 - j * 8
			var nom: String = cultures[(i * 3 + j * 5) % cultures.size()]
			if (i == 2 and j == 3) or (i == 5 and j == 1):
				nom = "vigne_coteau"
			_module(nom, Vector3(x, 0, z), i * 11 + j, {})
	for j in 8:
		_module("chemin", Vector3(0, 0, 12 - j * 8), 100 + j, {})
	for i in 4:
		_plante("haie", Vector3(-26 + i * 16, 0, -0.1 - 8.0), 120 + i, {"longueur": 7.6})
		_plante("haie", Vector3(-30 + i * 16, 0, -24.1), 130 + i, {"longueur": 7.6})
	for i in 4:
		_module("mur_pierre_seche", Vector3(-32 + i * 8, 0, 16.6), 140 + i, {})
	# la chapelle sur sa butte, le cèdre et les chênes
	var butte := MeshInstance3D.new()
	var sp := SphereMesh.new()
	butte.mesh = sp
	butte.scale = Vector3(40, 10, 34)
	butte.position = Vector3(-22, -3.2, -46)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("8aa650")
	butte.material_override = m
	monde.add_child(butte)
	_maison("chapelle", Vector3(-22, 1.4, -45), 5, {"clocher": "mur"}, 0.3)
	_plante("cedre", Vector3(-14, 0.8, -46), 6, {"hauteur": 14.0})
	_plante("chene", Vector3(18, 0, -38), 7, {})
	_plante("chene", Vector3(30, 0, 6), 8, {"hauteur": 12.0})
	_plante("charme", Vector3(-40, 0, -6), 9, {})
	_plante("cerisier", Vector3(5, 0, 4), 10, {"saison": "fleurs"})
	_objet("charrette", Vector3(2.5, 0, -4.0), 3, {}, 0.3)
	_horizon(Vector3(0, -10, -130), Vector3(400, 95, 110), 51)
