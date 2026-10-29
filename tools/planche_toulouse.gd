extends SceneTree
## Les planches des briques du décor toulousain (facadier-toulousain@1, mobilier-toulousain@1, sols-toulousains@1,
## arbres-d-ombriere@1), sous le soleil d'été des planches de la place Saint-Georges, et l'ambiance qu'on compose
## avec elles :
## godot --path . -s tools/planche_toulouse.gd -- --vue=facadier --capture=planche.png
##   --vue=facadier    les treize bâtisses, en rangée
##   --vue=detail      la même rangée vue en enfilade, pour lire le relief des façades
##   --vue=un          une seule bâtisse, de trois quarts (--nom=lafage)
##   --vue=mobilier    les onze objets du mobilier (--nom=carrousel : un seul, de près)
##   --vue=sols        les dix modules de sol (--nom=fosse_arbre : un seul, de près)
##   --vue=arbres      les arbres d'ombrière sur le pavé, au soleil (--nom=platane : un seul, de près)
##   --vue=saint_georges  la place Saint-Georges composée avec les quatre briques
##                     (--nom=bas : à hauteur d'homme, depuis une terrasse)
## Sans carte graphique : xvfb-run avec --rendering-driver opengl3.

const FACADIER := "facadier-toulousain@1"
const ARBRES := "arbres-de-place@1"
const MOBILIER := "mobilier-toulousain@1"
const SOLS := "sols-toulousains@1"
const OMBRE := "arbres-d-ombriere@1"

var monde: Node3D


func _init() -> void:
	await process_frame
	var vue := "facadier"
	var capture := "user://planche_toulouse.png"
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
		"facadier", "detail":
			_sol(Vector2(240, 80), Color("c9b28c"))
			var types: Array = load(Bibliotheque.scene(FACADIER, "decor")).instantiate().types()
			var x := -82.0
			for t in types:
				var m := _pose(FACADIER, "type", t, Vector3(x, 0, 0), types.find(t) + 1, {})
				var w: float = m.get_meta("w")
				m.position.x += w * 0.5
				if vue == "facadier":
					_etiquette(Vector3(x + w * 0.5, 0.05, 3.5), t)
				x += w + 1.5
			if vue == "facadier":
				cam.fov = 36
				cam.look_at_from_position(Vector3(5, 26, 150), Vector3(5, 6, -4))
			else:
				cam.fov = 50
				cam.look_at_from_position(Vector3(-86, 2.5, 11), Vector3(-62, 8, -1))
		"un":
			_sol(Vector2(80, 80), Color("c9b28c"))
			var m := _pose(FACADIER, "type", nom, Vector3.ZERO, 3, {})
			var w: float = m.get_meta("w")
			var h: float = m.get_meta("hauteur")
			cam.look_at_from_position(Vector3(w * 0.75, h * 0.55, w * 0.9 + h * 0.9), Vector3(0, h * 0.42, -3))
		"mobilier", "sols":
			var id: String = MOBILIER if vue == "mobilier" else SOLS
			var cle: String = "objet" if vue == "mobilier" else "module"
			var noms: Array = load(Bibliotheque.scene(id, "decor")).instantiate().noms()
			var par := 5 if vue == "sols" else 6
			var pas := 5.2 if vue == "sols" else 4.4
			_sol(Vector2(par * pas + 160, 200), Color("c9b28c"))
			var gauche := 0.0
			if nom != "":
				# une seule pièce, de près
				var b := _pose(id, cle, nom, Vector3.ZERO, 1, {})
				var e: Vector2 = b.get_meta("emprise", Vector2(4, 4))
				var r := maxf(maxf(e.x, e.y), 2.0)
				var h: float = b.get_meta("hauteur", r * 0.5)
				cam.look_at_from_position(Vector3(r * 0.55, maxf(r * 0.45, h * 0.6), r * 0.95 + h * 0.4), Vector3(0, h * 0.35, 0))
				noms = []
			else:
				# les pièces trop grandes pour la grille, à gauche : le carrousel et le jardin d'enfants, le rond
				var grands: Array = ["carrousel", "jardin_enfants"] if vue == "mobilier" else ["rond"]
				var gx := -(par + 1) * pas * 0.5 - 6.0
				for k in grands.size():
					var gp := Vector3(gx - k * 15.0, 0, pas * 0.2)
					_pose(id, cle, grands[k], gp, 1, {})
					_etiquette(gp + Vector3(0, 0.3, 6.5), grands[k], 0.006)
					noms.erase(grands[k])
					gauche = gp.x - 8.0
			for i in noms.size():
				var p := Vector3((i % par - (par - 1) * 0.5) * pas, 0, floorf(i / float(par)) * pas * 1.3 - pas * 0.6)
				_pose(id, cle, noms[i], p, i + 1, {})
				_etiquette(p + Vector3(0, 0.3, pas * 0.5), noms[i], 0.0045)
			if nom == "":
				var droite := (par - 1) * pas * 0.5 + 2.5
				var span := droite - gauche
				var centre := Vector3((gauche + droite) * 0.5, 0.5, pas * 0.4)
				cam.look_at_from_position(centre + Vector3(0, span * 0.36, span * 0.56), centre)
		"arbres":
			_sol(Vector2(300, 300), Color("c9b28c"))
			for i in 17:
				for j in 5:
					_pose(SOLS, "module", "brique_epi", Vector3(-32 + i * 4, 0, -8 + j * 4), i * 5 + j + 1, {})
			var noms: Array = [nom] if nom != "" else load(Bibliotheque.scene(OMBRE, "decor")).instantiate().noms()
			var x := -float(noms.size() - 1) * 11.0
			for a in noms:
				_pose(OMBRE, "arbre", a, Vector3(x, 0, 0), 3, {})
				if nom == "":
					_etiquette(Vector3(x, 0.3, 9.0), a, 0.008)
				x += 22.0
			cam.fov = 50
			if nom == "":
				cam.look_at_from_position(Vector3(0, 9, 52), Vector3(0, 8.5, 0))
			else:
				cam.look_at_from_position(Vector3(10, 4, 30), Vector3(0, 9, 0))
		"saint_georges":
			_saint_georges()
			if nom == "bas":
				cam.fov = 62
				cam.look_at_from_position(Vector3(-23, 1.7, 13), Vector3(4, 5.5, -16))
			else:
				cam.fov = 60
				cam.look_at_from_position(Vector3(0, 17, 42), Vector3(0, 4.5, -12))
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








func _maison(type: String, p: Vector3, g: int, opt := {}, lacet := 0.0) -> Node3D:
	return _pose(FACADIER, "type", type, p, g, opt, lacet)


func _objet(nom: String, p: Vector3, g: int, opt := {}, lacet := 0.0) -> Node3D:
	return _pose(MOBILIER, "objet", nom, p, g, opt, lacet)


## La place Saint-Georges des planches de Guillaume : le grand tapis de brique en épi bordé d'un trottoir de dalles,
## l'hôtel de Lafage au fond, les rangs de brique rose aux cafés et restaurants, l'immeuble XIXe à angle courbe en
## avant à droite ; les platanes en deux rangs sur leurs fosses grillagées, les terrasses sous les parasols crème
## et bordeaux, le carrousel et le jardin d'enfants au milieu.
func _saint_georges() -> void:
	_sol(Vector2(400, 400), Color("5a585a"), Vector3(0, 0, -40))
	var arbres := []
	for x in [-20.0, 20.0]:
		for z in [-16.0, -4.0, 8.0]:
			arbres.append(Vector2(x, z))
	for i in 15:
		for j in 11:
			var x := -28.0 + i * 4.0
			var z := -24.0 + j * 4.0
			var m := "brique_epi"
			if j == 0 or i == 0 or i == 14:
				m = "dalles"
			elif Vector2(x, z) in arbres:
				m = "fosse_arbre"
			elif j == 10:
				m = "bordure"
			_pose(SOLS, "module", m, Vector3(x, 0, z), i * 13 + j + 1, {})
	# le fond : l'hôtel de Lafage au milieu, les cafés et restaurants de part et d'autre
	var lafage := _maison("lafage", Vector3(0, 0, -26), 3, {"enduit": "rose_poudre"})
	var lw: float = lafage.get_meta("w")
	_rangee(Vector3(-30, 0, -26), Vector3(-lw * 0.5 - 0.2, 0, -26), 0.0, ["cafe", "etroite", "moyenne"], 5, {
		"cafe": {"enseigne": "CAFÉ SAINT-GEORGES", "toile": ["8a2a2e", "8a2a2e"]}})
	_rangee(Vector3(lw * 0.5 + 0.2, 0, -26), Vector3(30, 0, -26), 0.0, ["restaurant", "immeuble"], 7, {
		"restaurant": {"enseigne": "LE BISTROT"}})
	# à gauche : le grand rang des terrasses ; à droite : les commerces et l'immeuble Wilson en proue
	_rangee(Vector3(-30, 0, 18), Vector3(-30, 0, -26), PI * 0.5, ["immeuble", "cafe", "moyenne", "commerce", "etroite", "hotel"], 9, {
		"cafe": {"enseigne": "BRASSERIE DU CAPITOLE", "toile": ["2f6a4a", "f3ead6"]}, "hotel": {"enduit": "creme"}})
	var wilson := _maison("wilson", Vector3.ZERO, 4, {}, -PI * 0.5)
	var ww: float = wilson.get_meta("w")
	wilson.position = Vector3(30, 0, 18 - ww * 0.5)
	_rangee(Vector3(30, 0, -26), Vector3(30, 0, 18 - ww - 0.2), -PI * 0.5, ["commerce", "restaurant", "colombages", "moyenne", "immeuble"], 11, {
		"commerce": {"enseigne": "LIBRAIRIE"}})
	# les platanes
	var k := 0
	for a in arbres:
		var v: Vector2 = a
		_pose(OMBRE, "arbre", "platane", Vector3(v.x, 0, v.y), 20 + k, {"hauteur": 16.0})
		k += 1
	# les terrasses du fond, sous les parasols
	for t in [[-22.0, ["f0e3c4", "f0e3c4"]], [-15.0, ["8a2a2e", "8a2a2e"]], [17.0, ["f0e3c4", "f0e3c4"]], [24.0, ["8a2a2e", "8a2a2e"]]]:
		var x: float = t[0]
		_objet("grand_parasol", Vector3(x, 0, -20.5), k, {"toile": t[1]})
		k += 1
	# la terrasse de la brasserie, le long du rang de gauche, sous son store
	for z in [-14.0, -7.0, 0.0]:
		_objet("terrasse", Vector3(-25.0, 0, z), k, {}, PI * 0.5)
		_objet("parasol", Vector3(-25.0, 0, z + 3.2), k + 1, {"toile": ["f0e3c4", "f0e3c4"]})
		k += 2
	_objet("store_terrasse", Vector3(-26.5, 0, 9.0), k, {}, PI * 0.5)
	_objet("chevalet", Vector3(-12.0, 0, -21.0), 3, {}, 0.3)
	_objet("chevalet", Vector3(-24.0, 0, 13.5), 4, {}, PI * 0.5)
	# le milieu : le carrousel, le jardin d'enfants, les lampadaires, les bacs, les potelets, les vélos
	_objet("carrousel", Vector3(-4.0, 0, -6.0), 2, {})
	_objet("jardin_enfants", Vector3(7.0, 0, 4.0), 3, {}, -0.3)
	for p in [Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(-12, 0, 10), Vector3(12, 0, 10)]:
		_objet("lampadaire", p, k, {})
		k += 1
	for x in [-9.0, 9.0]:
		_objet("bac_bois", Vector3(x, 0, 15.0), k, {})
		k += 1
	for i in 9:
		_objet("potelet", Vector3(-16.0 + i * 4.0, 0, 17.2), i + 1, {})
	_objet("appui_velo", Vector3(25.0, 0, 6.0), 2, {}, -PI * 0.5)
	_objet("appui_velo", Vector3(25.0, 0, 8.5), 3, {}, -PI * 0.5)
