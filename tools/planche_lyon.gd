extends SceneTree
## Les planches des briques du décor lyonnais (facadier-lyonnais@1, mobilier-lyonnais@1, vegetation-lyonnaise@1,
## quais-lyonnais@1), sous un ciel d'été franc, et la place qu'on bâtit avec les quatre :
## godot --path . -s tools/planche_lyon.gd -- --vue=facadier --capture=planche.png
##   --nom=fontaine    avec mobilier, vegetation ou quais : une seule pièce, de près
##   --vue=facadier    les onze bâtisses, en rangée
##   --vue=detail      la même rangée vue en enfilade, pour lire le relief des façades
##   --vue=mobilier    chaque objet du mobilier, avec son nom
##   --vue=vegetation  chaque plante, avec son nom
##   --vue=quais       les sols et les modules de quai
##   --vue=toits      un îlot de huit immeubles vu de 70 m, pour le grain des toits (--nom=grain=1 ; verdict n° 32)
##   --vue=jardin      un coin de jardin : la nappe d'herbe, des buissons et un massif en feuilles fines, de près
##   --vue=place       une place lyonnaise : fontaine au lion, terrasses, quai, rivière, pont, colline
##   --vue=rue         la même place à hauteur d'œil
##   --vue=quai        le quai, la rivière et le pont, vus du parapet
##   --vue=terrasses   un café et deux boutiques, leurs stores bannes et les terrasses bistrot, à hauteur d'œil
##                     (--nom=haut : de plus haut, comme sur la planche de la place Sathonay ; --nom=toits : les
##                     toits à 29°, leurs châssis et leurs grosses souches)
## Sans carte graphique : xvfb-run avec --rendering-driver opengl3.

const FACADIER := "facadier-lyonnais@1"
const MOBILIER := "mobilier-lyonnais@1"
const VEGETATION := "vegetation-lyonnaise@1"
const QUAIS := "quais-lyonnais@1"

var monde: Node3D


func _init() -> void:
	await process_frame
	var vue := "place"
	var capture := "user://planche_lyon.png"
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
		"terrasses":
			_sol(Vector2(80, 60), Color("8f8f8c"), Vector3(0, -0.01, 10))
			_sol(Vector2(40, 5), Color("cfc4ab"), Vector3(0, 0.0, 2.5))
			var x := -15.0
			var rang := [["boutique", {"toile": ["b8322c", "f3ead6"]}], ["cafe", {"enseigne": "CAFÉ SATHONAY", "toile": ["2f5a3a", "2f5a3a"]}], ["cafe", {"enseigne": "LE BOUCHON DES CANUTS"}], ["classique", {"toile": ["2f5f8f", "f3ead6"], "avancee": 1.8}]]
			for e in rang:
				var opt: Dictionary = e[1]
				opt["w"] = 9.5
				if nom == "toits":
					opt["chassis"] = 1 + rang.find(e) % 3
					opt["souches"] = "grosses"
					opt["pente"] = 29.0
				if nom == "sathonay" and rang.find(e) % 2 == 0 and e[0] != "cafe":
					# une boutique sur deux sans store banne (verdict de Sathonay)
					opt["store"] = false
				var m := _pose(FACADIER, "type", e[0], Vector3(x + 4.75, 0, 0), rang.find(e) + 3, opt)
				if e[0] == "cafe":
					_pose(MOBILIER, "objet", "terrasse", Vector3(x + 4.75, 0, 3.4), rang.find(e) + 1, {})
				x += 9.9
			if nom == "sathonay":
				# les marronniers du mail, de trois verts mêlés tirés par la graine
				for i in 5:
					_pose("arbres-d-ombriere@1", "arbre", "marronnier", Vector3(-18 + i * 9.0, 0, 12), i + 1, {"teinte": ["6e9440", "8ab04a", "4d6e33"]})
				cam.fov = 50
				cam.look_at_from_position(Vector3(2, 9, 34), Vector3(2, 6, 0))
			elif nom == "toits":
				cam.fov = 45
				cam.look_at_from_position(Vector3(2, 34, 30), Vector3(2, 14, -4))
			elif nom == "haut":
				cam.fov = 45
				cam.look_at_from_position(Vector3(4, 16, 26), Vector3(2, 2.5, 0))
			else:
				cam.fov = 55
				cam.look_at_from_position(Vector3(-4, 1.65, 10.5), Vector3(3, 2.6, 1))
		"toits":
			# un îlot de huit immeubles vu comme la Vue1 de Sathonay (caméra à 70 m, tangage -48°), pour mesurer le grain
			# des toits (--nom=grain=x, 0 par défaut ; verdict n° 32)
			_sol(Vector2(120, 120), Color("b8a27a"))
			var grain := 0.0
			if nom.begins_with("grain="):
				grain = float(nom.trim_prefix("grain="))
			var types_toits := ["classique", "immeuble", "cafe", "hotel", "maison", "etroite", "traboule", "angle"]
			var x := -24.0
			for i in types_toits.size():
				var rangee := i % 2
				var opt := {"grain": grain, "w": 10.0 if types_toits[i] != "etroite" else 5.2}
				var m := _pose(FACADIER, "type", types_toits[i], Vector3(x + (0.0 if rangee == 0 else 5.0), 0, -rangee * 26.0), i + 1, opt, 0.0 if rangee == 0 else PI)
				if rangee == 1:
					x += float(m.get_meta("w")) + 0.4
			cam.fov = 40
			cam.look_at_from_position(Vector3(-6, 52.0, 46.8 - 13.0), Vector3(-6, 0, -13.0))
		"facadier", "detail":
			_sol(Vector2(140, 60), Color("b8a27a"))
			var types: Array = load(Bibliotheque.scene(FACADIER, "decor")).instantiate().types()
			var x := -60.0
			for t in types:
				var m := _pose(FACADIER, "type", t, Vector3(x, 0, 0), types.find(t) + 1, {})
				var w: float = m.get_meta("w")
				m.position.x += w * 0.5
				if vue == "facadier":
					_etiquette(Vector3(x + w * 0.5, 0.05, 2.5), t)
				x += w + (5.0 if t == "angle" else 0.4)
			if vue == "facadier":
				cam.look_at_from_position(Vector3(4, 22, 92), Vector3(4, 9, -6))
			else:
				cam.fov = 50
				cam.look_at_from_position(Vector3(-64, 3.0, 11), Vector3(-40, 9, -1))
		"jardin":
			# un coin de jardin : la nappe d'herbe, deux buissons et un massif en feuilles fines, fleuris, de près (revue n° 4, verdict n° 29)
			_sol(Vector2(60, 60), Color("b8a27a"))
			_pose(VEGETATION, "plante", "herbe", Vector3(0, 0, 0), 1, {"points": [[-5, -3], [5, -3.5], [5.5, 3], [1, 3.5], [-4.5, 2.5]]})
			_pose(VEGETATION, "plante", "buisson", Vector3(-2.5, 0, -1.5), 2, {"hauteur": 1.3, "fleurs": "e0605a"})
			_pose(VEGETATION, "plante", "buisson", Vector3(3.0, 0, -1.8), 3, {"hauteur": 1.0, "fleurs": "f4f0e6"})
			_pose(VEGETATION, "plante", "massif", Vector3(0.5, 0, 1.2), 4, {"longueur": 3.5, "fleurs": "d04a8a"})
			cam.fov = 45
			cam.look_at_from_position(Vector3(2.5, 1.9, 6.5), Vector3(0, 0.5, -0.5))
		"mobilier", "vegetation", "quais":
			var id: String = {"mobilier": MOBILIER, "vegetation": VEGETATION, "quais": QUAIS}[vue]
			var cle: String = {"mobilier": "objet", "vegetation": "plante", "quais": "module"}[vue]
			var noms: Array = load(Bibliotheque.scene(id, "decor")).instantiate().noms()
			var par := 6 if vue == "quais" else 5
			var pas: float = {"quais": 7.5, "vegetation": 6.5}.get(vue, 4.6)
			_sol(Vector2(par * pas + 40, 60), Color("b8a27a"))
			if nom != "":
				# une seule pièce, de près
				var bas := nom in ["pont", "mur_quai_haut"]
				var b := _pose(id, cle, nom, Vector3(0, 3.8 if bas else 0.0, 0), 1, {"eau": true} if bas else {})
				var e: Vector2 = b.get_meta("emprise", Vector2(4, 4))
				var r := maxf(maxf(e.x, e.y), 2.0)
				cam.look_at_from_position(Vector3(r * 0.5, r * 0.45, r * 0.85), Vector3(0, r * 0.2, 0))
				noms = []
			elif vue == "mobilier":
				# la fontaine, trop grande pour la grille, à gauche
				_pose(id, cle, noms[0], Vector3(-(par + 1) * pas * 0.5 - 4.5, 0, 0), 1, {})
				_etiquette(Vector3(-(par + 1) * pas * 0.5 - 4.5, 0.3, 6.5), noms[0], 0.007)
				noms.remove_at(0)
			elif vue == "quais":
				# le pont, trop long pour la grille, derrière, sur son bout de rivière
				_pose(id, cle, "pont", Vector3(0, 3.8, -16), 1, {"eau": true})
				noms.erase("pont")
				# les hauts modules au fond, les sols devant
				var hauts := ["arche", "arche_mur", "passage_escalier", "escalier_haut", "escalier_bas", "mur_quai_haut"]
				var sols := noms.filter(func(n): return not n in hauts)
				noms = hauts.filter(func(n): return n in noms) + sols
			for i in noms.size():
				var p := Vector3((i % par - (par - 1) * 0.5) * pas, 0, floorf(i / float(par)) * pas * (1.45 if vue == "mobilier" else 1.1) - pas)
				# le quai haut descend dans la rivière : sur la planche, on le hausse jusqu'à l'eau
				var b := _pose(id, cle, noms[i], p, i + 1, {"eau": true} if noms[i] == "mur_quai_haut" else {})
				if noms[i] == "mur_quai_haut":
					b.position.y += 3.8
				_etiquette(p + Vector3(0, 0.3, pas * 0.42), noms[i], 0.0045)
			if noms.is_empty():
				pass
			var rangs := ceilf(noms.size() / float(par))
			var centre := Vector3(-4.0 if vue == "mobilier" else 0.0, 0.5, (rangs - 1) * pas * (0.72 if vue == "mobilier" else 0.55) - pas)
			if nom == "":
				var recul := 1.3 if vue == "quais" else 1.0
				cam.look_at_from_position(centre + Vector3(0, 17, 25) * recul + Vector3(0, 0, 0), centre + Vector3(0, 0, -3.0 if vue == "quais" else 0.0))
		"place", "rue", "quai":
			_place()
			if vue == "quai":
				cam.fov = 55
				cam.look_at_from_position(Vector3(-9, 2.0, -14.2), Vector3(4, 0.5, -28))
			elif vue == "place":
				cam.fov = 50
				cam.look_at_from_position(Vector3(10, 36, 56), Vector3(0, 4, -30))
			else:
				cam.fov = 60
				cam.look_at_from_position(Vector3(-6, 1.7, 9), Vector3(6, 6, -30))
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


## Une colline ronde et verte (Fourvière), de centre c et de rayons R, semée d'arbres sur sa face avant.
func _colline(c: Vector3, R: Vector3, graine: int) -> float:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 48
	sphere.rings = 24
	mi.mesh = sphere
	mi.scale = R
	mi.position = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("86a24e")
	m.roughness = 1.0
	mi.material_override = m
	monde.add_child(mi)
	var r := RandomNumberGenerator.new()
	r.seed = graine
	for i in 70:
		var u := r.randf_range(-0.85, 0.85)
		var v := r.randf_range(0.15, 0.95)
		var y := 1.0 - u * u - (1.0 - v) * (1.0 - v)
		if y <= 0.05:
			continue
		var q := c + Vector3(u * R.x * 0.5, sqrt(y) * R.y * 0.5, (1.0 - v) * R.z * 0.5)
		if q.y < 1.0:
			continue
		var nom: String = ["alignement", "cypres", "alignement", "platane", "buisson"][r.randi() % 5]
		_pose(VEGETATION, "plante", nom, q - Vector3(0, 0.3, 0), 200 + i, {"hauteur": {"alignement": 7.0, "cypres": 8.0, "platane": 10.0, "buisson": 2.5}[nom] * r.randf_range(0.9, 1.3)})
	return c.y + R.y * 0.5


func _place() -> void:
	var EAU := -3.4
	# le sol de la place et des rues, jusqu'au quai ; la rive d'en face ; la rivière entre les deux
	_sol(Vector2(200, 80), Color("b9a686"), Vector3(0, 0, 24))
	_sol(Vector2(200, 60), Color("b9a686"), Vector3(0, 0, -66))
	var lit := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(200, 0.2, 20)
	lit.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("4f8399")
	mat.roughness = 0.35
	lit.material_override = mat
	lit.position = Vector3(0, EAU - 0.1, -26)
	monde.add_child(lit)
	# la place pavée en éventail, de 32 m sur 28
	for i in 8:
		for j in 7:
			_pose(QUAIS, "module", "paves_eventail" if (i + j) % 3 != 0 else "paves", Vector3(-14 + i * 4, 0, 10 - j * 4), i * 7 + j + 1, {})
	# les quais : le mur qui tombe dans l'eau des deux côtés, le parapet de garde-corps côté place
	for k in 25:
		var x := -48.0 + k * 4.0
		if absf(x) > 3.5:
			_pose(QUAIS, "module", "mur_quai_haut", Vector3(x, 0, -16), k + 1, {}, PI)
			_pose(QUAIS, "module", "mur_quai_haut", Vector3(x, 0, -36), k + 40, {})
		if absf(x + 2.0) > 7.5 and k % 2 == 0:
			_pose(MOBILIER, "objet", "garde_corps", Vector3(x + 2.0, 0, -15.6), k, {"longueur": 8.0})
	# le pont qui enjambe la rivière, et ses culées
	_pose(QUAIS, "module", "pont", Vector3(0, 0, -26), 3, {}, PI * 0.5)
	# les façades : à gauche et à droite de la place, puis la rive d'en face
	_rangee(Vector3(-18, 0, 9), Vector3(-18, 0, -15), PI * 0.5, ["classique", "etroite", "immeuble", "traboule", "maison"], 3)
	_rangee(Vector3(18, 0, -15), Vector3(18, 0, 9), -PI * 0.5, ["cafe", "bourgeois", "etroite", "classique"], 5, {"cafe": {"enseigne": "CAFÉ DES CANUTS"}})
	_rangee(Vector3(-70, 0, -40), Vector3(-6, 0, -40), 0.0, ["hotel", "classique", "immeuble", "arcades", "etroite", "bourgeois", "maison"], 9)
	_rangee(Vector3(6, 0, -40), Vector3(80, 0, -40), 0.0, ["immeuble", "maison", "classique", "traboule", "etroite", "hotel"], 11)
	# la colline de Fourvière et sa basilique au sommet
	var sommet := _colline(Vector3(-6, -8, -105), Vector3(150, 58, 80), 17)
	var ch := _pose(FACADIER, "type", "chapelle", Vector3(-6, sommet - 0.6, -105), 4, {"enduit": "e8dcc0"})
	ch.scale = Vector3.ONE * 1.25
	# la fontaine au lion au centre, les platanes le long du quai
	_pose(MOBILIER, "objet", "fontaine", Vector3(0, 0, -1), 1, {})
	for k in 7:
		var x := -15.0 + k * 5.0
		if absf(x) > 3.0:
			_pose(VEGETATION, "plante", "platane", Vector3(x, 0, -12.5), 30 + k, {"pied": "grille", "hauteur": 11.0})
	# devant le café : la terrasse sous les parasols, les orangers en caisse ; les lampadaires du quai
	for k in 3:
		_pose(MOBILIER, "objet", "terrasse", Vector3(13.2, 0, -10.5 + k * 3.7), 40 + k, {"toile": ["b8322c", "f3ead6"]})
	_pose(VEGETATION, "plante", "oranger", Vector3(15.8, 0, -13.2), 3, {})
	_pose(VEGETATION, "plante", "oranger", Vector3(15.8, 0, -0.4), 4, {})
	for x in [-12.0, -3.8, 3.8, 16.5]:
		_pose(MOBILIER, "objet", "candelabre" if absf(x) < 5.0 else "lampadaire", Vector3(x, 0, -14.6), int(x) + 50, {})
	# la place : bancs, bornes, jardinières, le kiosque, la colonne d'affiches, l'étal, les massifs
	_pose(MOBILIER, "objet", "banc", Vector3(-6.5, 0, 6.5), 2, {}, PI * 0.25)
	_pose(MOBILIER, "objet", "banc", Vector3(6.5, 0, 6.5), 3, {}, -PI * 0.25)
	_pose(MOBILIER, "objet", "banc_pierre", Vector3(-6.0, 0, -8.0), 4, {}, PI * 0.8)
	_pose(MOBILIER, "objet", "kiosque", Vector3(-11.0, 0, 8.0), 5, {})
	_pose(MOBILIER, "objet", "colonne", Vector3(8.5, 0, 10.5), 6, {})
	_pose(MOBILIER, "objet", "etal", Vector3(-12.5, 0, -2.0), 7, {}, PI * 0.5)
	_pose(MOBILIER, "objet", "etal", Vector3(-12.5, 0, -6.0), 8, {}, PI * 0.5)
	for k in 6:
		_pose(MOBILIER, "objet", "borne", Vector3(-4.0 + k * 1.6, 0, 13.0), 9 + k, {})
	_pose(MOBILIER, "objet", "jardiniere", Vector3(-3.5, 0, -9.5), 20, {})
	_pose(MOBILIER, "objet", "jardiniere", Vector3(3.5, 0, -9.5), 21, {})
	_pose(MOBILIER, "objet", "vasque", Vector3(-7.5, 0, 0.0), 22, {})
	_pose(MOBILIER, "objet", "vasque", Vector3(7.5, 0, -2.0), 23, {})
	_pose(MOBILIER, "objet", "corbeille", Vector3(-4.5, 0, 7.5), 24, {})
	_pose(VEGETATION, "plante", "massif", Vector3(-13.5, 0, 12.5), 25, {"longueur": 5.0}, PI * 0.5)
	_pose(VEGETATION, "plante", "cypres", Vector3(-15.5, 0, -12.0), 26, {"hauteur": 7.0})
