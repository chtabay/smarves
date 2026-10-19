extends RefCounted
## Le décor de l'original, zone par zone (decor/zone-<id>.glb) : exporté tel quel de la scène du moteur web
## (tools/minuit_decor/), mêmes formes, mêmes textures, mêmes répétitions. Il remplace les maillages que les
## zones du portage ont refaits ; elles gardent le reste (sols qu'on foule, murs qu'on ne traverse pas,
## interactions, lumières, jets d'eau, halos, voitures, foules, figurants). Une zone de l'original sans zone
## du portage va sous la plus proche. Ce que l'original anime, ce fichier l'anime avec les mêmes formules
## (js/zones/*.js, onUpdate).

const BASE := "res://communes/casino_minuit/"
const DECOR := BASE + "decor/"
const SOUS := {"R-ESCALIER-PALIER": "R-ESCALIER", "ESC-STAFF-B": "ESC-STAFF", "ESC-STAFF-H": "ESC-STAFF",
	"M-ESC-STAFF": "ESC-STAFF", "F-SCENE": "F-CONCERT", "F-RING": "F-ARENE-SALLE"}
## Ce que le portage dessine lui-même et que le décor n'apporte pas : ses jets d'eau en arc (lot « jet »),
## et, hors des lots, les matières de ses jets, halos, ciel, voitures, foules et faisceaux.
const GARDE_LOTS := ["lot_jet"]
const GARDE_SHADERS := ["jet.gdshader", "halo.gdshader", "nuit.gdshader", "vehicule.gdshader", "foule.gdshader", "faisceau.gdshader"]

var scene: Node3D
var K
## Les textures qui défilent (matière marquée « anim| » à l'export) : [matière, décalage de départ, genre, vitesse].
var _defilent: Array = []
## Les instances animées de l'original, devenues des MultiMesh, par nom : [MultiMesh, transformations de départ].
var _inst := {}
## Les objets animés de l'original, par nom : [nœud, transformation de départ].
var _objets := {}
var _gyro: BaseMaterial3D
var _roue := {"ang": 0.0, "vel": 0.0, "wait": 4.0}
var _lot := -1


func _init(s: Node3D, kit) -> void:
	scene = s
	K = kit


func charger() -> void:
	var refaits := {}
	for z in _zones_originales():
		# Une zone de l'original sans rien à dessiner (le palier de l'escalier) n'a pas de .glb.
		var sous: Node = scene.get_node_or_null(SOUS.get(z, z))
		if sous == null or not ResourceLoader.exists(DECOR + "zone-%s.glb" % z):
			continue
		var d: Node3D = (load(DECOR + "zone-%s.glb" % z) as PackedScene).instantiate()
		d.name = "Decor_" + z
		sous.add_child(d)
		# Le .glb porte la place de la zone dans le casino (la mezzanine à 6 m) : la zone du portage aussi.
		d.global_transform = Transform3D.IDENTITY
		refaits[sous] = true
		_matieres(d)
		_animes(d)
	# Les extérieurs de l'original sont d'un tenant (X-STRIP) : toutes les zones X- du portage lui cèdent.
	if refaits.has(scene.get_node_or_null("X-STRIP")):
		for c in scene.get_children():
			if str(c.name).begins_with("X-"):
				refaits[c] = true
	for sous in refaits:
		_retirer_refaits(sous)
	K.chaque_image(animer)


## Les zones de l'original (rendu.json), celles dont le décor est exporté.
func _zones_originales() -> Array:
	var f := FileAccess.open(BASE + "donnees/rendu.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	return d.zones.map(func(z): return z.id)


## Les marques posées à l'export sur le nom des matières : « nt| » (le moteur web ne les passe pas par
## l'exposition : elles suivent compenser), « add| » (additives), « anim|genre|vx|vy| » (texture qui défile).
func _matieres(d: Node) -> void:
	for mi in d.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m: Mesh = (mi as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var mat := m.surface_get_material(i) as BaseMaterial3D
			if mat == null:
				continue
			# Les instances cuites portent leur couleur aux sommets (fleurs de verre, palmiers).
			if m.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR and not mat.vertex_color_use_as_albedo:
				mat.vertex_color_use_as_albedo = true
			var nom := mat.resource_name
			if nom.begins_with("nt|"):
				nom = nom.trim_prefix("nt|")
				if not K.lueurs.any(func(l): return l[0] == mat):
					if mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or not mat.emission_enabled:
						K.lueurs.append([mat, mat.albedo_color, "albedo"])
					else:
						K.lueurs.append([mat, mat.emission_energy_multiplier])
			if nom.begins_with("add|"):
				nom = nom.trim_prefix("add|")
				mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			if nom.begins_with("anim|") and not _defilent.any(func(e): return e[0] == mat):
				var a := nom.split("|")
				_defilent.append([mat, mat.uv1_offset, a[1], Vector2(float(a[2]), float(a[3])), a[4] if a[1] == "pas" else ""])


## Les maillages refaits par la zone du portage cèdent la place au décor ; ses textes peints aussi.
func _retirer_refaits(sous: Node) -> void:
	for c in sous.find_children("*", "GeometryInstance3D", true, false):
		if str(c.get_path()).contains("/Decor_") or str(c.name) == "Halos" or str(c.name) in GARDE_LOTS:
			continue
		if c is Label3D:
			c.visible = false
			continue
		if c is MeshInstance3D and str(c.name).begins_with("lot_"):
			c.queue_free()
			continue
		var mat: Material = (c as GeometryInstance3D).material_override
		if mat == null and c is MeshInstance3D and c.mesh and c.mesh.get_surface_count() > 0:
			mat = c.mesh.surface_get_material(0)
		if mat == null and c is MultiMeshInstance3D and c.multimesh and c.multimesh.mesh:
			mat = c.multimesh.mesh.surface_get_material(0)
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader.resource_path.get_file() in GARDE_SHADERS:
			continue
		# Une pièce animée refaite (roue, porte, flammes, carpes) : celle de l'original l'anime ici.
		c.visible = false


## Les instances animées (exportées en groupe d'enfants « i<k>[_couleur] ») deviennent un MultiMesh ;
## les objets animés de l'original sont relevés par leur nom.
func _animes(d: Node) -> void:
	for g in d.find_children("*", "Node3D", true, false):
		var nom := str(g.name)
		if nom in ["porte-tambour", "roue", "roue-de-la-fortune", "gyrophare"] or (nom == "flammes" and g is MeshInstance3D):
			if not _objets.has(nom):
				_objets[nom] = []
			_objets[nom].append([g, (g as Node3D).transform])
			if nom == "gyrophare":
				_gyro = ((g as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D)
				K.lueurs = K.lueurs.filter(func(l): return l[0] != _gyro)
			continue
		if not nom in ["lustre-pendeloques", "roulette-roues", "carpes", "totem-ampoules", "marquise-chenillard", "roulettes", "flammes"]:
			continue
		var enfants := g.get_children().filter(func(c): return c is MeshInstance3D and str(c.name).begins_with("i"))
		if enfants.is_empty():
			continue
		enfants.sort_custom(func(a, b): return int(str(a.name).substr(1).split("_")[0]) < int(str(b.name).substr(1).split("_")[0]))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var couleurs := str(enfants[0].name).contains("_")
		mm.use_colors = couleurs
		mm.mesh = (enfants[0] as MeshInstance3D).mesh
		mm.instance_count = enfants.size()
		var depart := []
		for i in enfants.size():
			var c: MeshInstance3D = enfants[i]
			mm.set_instance_transform(i, c.transform)
			depart.append(c.transform)
			if couleurs:
				mm.set_instance_color(i, Color(str(c.name).split("_")[1]))
			c.queue_free()
		if couleurs:
			for s in mm.mesh.get_surface_count():
				var mat := mm.mesh.surface_get_material(s) as BaseMaterial3D
				if mat:
					mat.vertex_color_use_as_albedo = true
		var mmi := MultiMeshInstance3D.new()
		mmi.name = nom + "_mm"
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mmi)
		if not _inst.has(nom):
			_inst[nom] = []
		_inst[nom].append([mm, depart, g])


func animer(dt: float, t: float) -> void:
	# Les textures qui défilent (kit.js l. 1302-1304, 1561 ; a-escalier.js l. 117 ; b-salon.js l. 42 ;
	# c-pit.js l. 210 ; c-sports.js l. 87 ; e-0-commun.js l. 434). Le glTF garde le décalage du moteur web tel quel.
	for e in _defilent:
		var v: Vector2 = e[3]
		var o := v * t
		match e[2]:
			"eau":
				o += Vector2(sin(t * 0.31), cos(t * 0.23)) * 0.03
			"pas":
				# pas|vx|vy|cadence : la texture saute d'un cran par tic, à la cadence donnée.
				o = v * floorf(t * float(e[4]))
			"rouleaux":
				var ph := fmod(t, 3.5)
				o = Vector2(0.0, -fmod(floorf(t / 3.5) * 0.375 + (ph * 2.2 if ph < 1.3 else 0.0), 1.0))
		(e[0] as BaseMaterial3D).uv1_offset = e[1] + Vector3(o.x, o.y, 0)
	# a-rotonde.js l. 216 : la porte-tambour.
	for o in _objets.get("porte-tambour", []):
		(o[0] as Node3D).rotate_object_local(Vector3.UP, dt * 0.55)
	# b-hl.js l. 89 : la roue de la table des hautes limites, lancée toutes les 14 s.
	for o in _objets.get("roue", []):
		var ph := fmod(t, 14.0)
		var rz := -(floorf(t / 14.0) * 2.1 + (9.0 * ph - 0.5 * ph * ph if ph < 9.0 else 40.5))
		(o[0] as Node3D).basis = Basis.from_euler(Vector3(-PI / 2.0, 0.0, rz), EULER_ORDER_XYZ)
	# c-pit.js l. 174 : la roue de la fortune, lancée, freinée, arrêtée 9 à 14 s, relancée.
	if _objets.has("roue-de-la-fortune"):
		var r := _roue
		if r.vel > 0.02:
			r.ang += r.vel * dt
			r.vel *= exp(-dt * 0.55)
			if r.vel <= 0.02:
				r.vel = 0.0
				r.wait = 9.0 + fmod(r.ang, 5.0)
		else:
			r.wait -= dt
			if r.wait <= 0.0:
				r.vel = 5.5 + randf() * 2.5
		for o in _objets["roue-de-la-fortune"]:
			(o[0] as Node3D).basis = Basis(Vector3.BACK, -r.ang)
	# b-salon.js l. 42 : les flammes de la cheminée.
	for o in _objets.get("flammes", []):
		var k := 0.5 * sin(t * 9.1) + 0.3 * sin(t * 14.3 + 1.0) + 0.2 * sin(t * 5.7 + 2.0)
		var tr: Transform3D = o[1]
		(o[0] as Node3D).transform = Transform3D(tr.basis.scaled_local(Vector3(1.0, 1.0 + 0.12 * k, 1.0)), tr.origin)
	# d-b-antichambre.js l. 59 : le gyrophare.
	if _gyro:
		var k := 0.35 + 0.65 * maxf(0.0, sin(t * 4.2))
		var f := 0.9 / maxf(K.expo, 0.1)
		_gyro.albedo_color = Color(k * f, 0.05 * k * f, 0.04 * k * f)
	_animer_instances(t)


func _animer_instances(t: float) -> void:
	# a-atrium.js l. 160 : la pluie de pendeloques tourne lentement, trente d'entre elles scintillent.
	for e in _inst.get("lustre-pendeloques", []):
		var mm: MultiMesh = e[0]
		var dep: Array = e[1]
		var n := dep.size()
		(e[2] as Node3D).rotation.y = t * 0.03
		var lot := int(floorf(t / 0.5)) % 100000
		if lot != _lot:
			if _lot >= 0:
				for k in 30:
					var i := (_lot * 37 + k * 13) % n
					mm.set_instance_transform(i, Transform3D(Basis(), (dep[i] as Transform3D).origin))
			_lot = lot
		for k in 30:
			var i := (lot * 37 + k * 13) % n
			var s := 1.0 + 0.7 * absf(sin(t * 9.4 + k))
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), (dep[i] as Transform3D).origin))
	# a-atrium.js l. 181 : les deux roues des roulettes de l'atrium.
	for e in _inst.get("roulette-roues", []):
		var vit := [1.1, -0.8]
		for i in (e[1] as Array).size():
			var d: Transform3D = e[1][i]
			(e[0] as MultiMesh).set_instance_transform(i, d * Transform3D(Basis(Vector3.BACK, vit[i % 2] * t), Vector3.ZERO))
	# c-pit.js l. 147 : les cylindres des roulettes du pit.
	for e in _inst.get("roulettes", []):
		for i in (e[1] as Array).size():
			var d: Transform3D = e[1][i]
			(e[0] as MultiMesh).set_instance_transform(i, Transform3D(Basis(Vector3.UP, t * (1.3 + i * 0.25) + i * 2.0), d.origin))
	# b-jardin.js l. 48 : les carpes du bassin.
	for e in _inst.get("carpes", []):
		for i in (e[1] as Array).size():
			var w := (0.22 + (i % 3) * 0.07) * (1.0 if i % 2 else -1.0)
			var a := t * w + i * 2.1
			var rx := 1.3 + (i % 4) * 0.38
			var rz := 0.8 + (i % 3) * 0.3
			var b := Basis.from_euler(Vector3(0.0, -a - (0.0 if w > 0.0 else PI) + PI / 2.0, 0.0)).scaled_local(Vector3(0.16, 0.035, 0.055))
			(e[0] as MultiMesh).set_instance_transform(i, Transform3D(b, Vector3(-29.0 + cos(a) * rx, 0.368, -21.0 + sin(a) * rz)))
	# b-machines.js l. 80 : les trois couronnes d'ampoules du totem, en chenillard.
	for e in _inst.get("totem-ampoules", []):
		var n := 0
		for r in 3:
			var q: int = [20, 16, 12][r]
			for k in q:
				var ph := fposmod(float(k) / q * 4.0 + t * (-1.6 if r % 2 else 1.6) + r * 0.33, 1.0)
				var v := 1.0 if ph < 0.5 else 0.18
				(e[0] as MultiMesh).set_instance_color(n, Color(v, v * (0.45 if r == 1 else 0.82), v * (0.6 if r == 1 else 0.42)))
				n += 1
	# c-foyer.js l. 50 : la marquise du théâtre, une ampoule sur trois, six pas par seconde.
	for e in _inst.get("marquise-chenillard", []):
		var p := int(floorf(t * 6.0)) % 3
		for i in 60:
			(e[0] as MultiMesh).set_instance_color(i, Color(0.3, 0.12, 0.03) if (i + p) % 3 else Color(1.0, 0.86, 0.55))
	# c-restaurant.js l. 106 : les flammes des feux de la cuisine.
	for e in _inst.get("flammes", []):
		for i in (e[1] as Array).size():
			var d: Transform3D = e[1][i]
			var s := 0.75 + 0.35 * sin(t * 9.0 + i * 2.1) * sin(t * 5.3 + i)
			var b := Basis.from_scale(Vector3(0.9 + 0.2 * sin(t * 7.0 + i), s * (1.5 if i % 3 == 1 else 0.6), 0.9))
			(e[0] as MultiMesh).set_instance_transform(i, Transform3D(b, d.origin))
