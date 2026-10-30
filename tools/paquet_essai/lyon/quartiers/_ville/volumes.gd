extends RefCounted
## La ville de Lyon en volumes, au loin (cartes/lyon/VILLE.md, « Ce qu'on voit au loin ») : là où aucun
## quartier n'est encore livré, un terrain lâche tiré du relief de la ville et les bâtiments de la BD TOPO
## en boîtes, aux couleurs du façadier, pour qu'aucune vue ne tombe sur le bord du monde. On ne bâtit rien
## dans le cadre de lyon.gd (Sathonay dessine ses propres volumes) ni dans une réserve dont le quartier est
## dans le paquet (sa version lointaine prend la suite). Tout en mètres, sous un nœud réduit à 1/U.
## Données : relief.json (tools/relief_ville.py) et volumes.json.gz (tools/volumes_ville.py).

const DOSSIER := "res://communes/lyon/"
const VOLUMES := DOSSIER + "quartiers/_ville/volumes.json"
const RELIEF := DOSSIER + "quartiers/_ville/relief.gd"
## Le pas du terrain lâche, en mètres (le relief est au pas de 10).
const PAS_TERRAIN := 20.0
## Les hauteurs sous lesquelles le terrain est de l'eau (la Saône et le Rhône sont au zéro).
const EAU_SOUS := 0.6
const COULEUR_SOL := Color("#b8a98a")
const COULEUR_EAU := Color("#3d5b57")
const COULEUR_BOIS := Color("#4a6634")
const TOITS := {0: Color("#b0452a"), 1: Color("#4a4f5a"), 2: Color("#8d9196"), 3: Color("#a39b93")}
## Les bois des collines : au-dessus de ces hauteurs sans bâtiment, le terrain verdit (Fourvière, Croix-Rousse).
const BOIS_AU_DESSUS := 60.0


## Bâtit sous `racine` (mètres) : le terrain lâche, puis les boîtes. Renvoie le nombre de boîtes posées.
static func batir(racine: Node3D) -> int:
	var relief: Script = load(RELIEF)
	var cadre: Array = relief.call("cadre")
	if cadre.is_empty():
		return 0
	var lyon: Script = load(DOSSIER + "lyon.gd")
	var exclus := _exclusions(lyon)
	var sans_terrain: Rect2 = exclus[0]
	var reserves: Array = exclus[1]
	_terrain(racine, relief, cadre, sans_terrain)
	return _boites(racine, relief, lyon, sans_terrain, reserves)


## Le cadre de lyon.gd (où Sathonay dessine son propre terrain et ses volumes) et les polygones des
## réserves dont le quartier est dans le paquet.
static func _exclusions(lyon: Script) -> Array:
	var b = Atelier.donnees(DOSSIER + "bourg.json")
	var u := float(b.get("unite_m", 2.4))
	var r: Dictionary = b.relief
	var sans := Rect2(float(r.x0) * u, float(r.z0) * u, (int(r.nx) - 1) * float(r.pas) * u, (int(r.nz) - 1) * float(r.pas) * u)
	var reserves := []
	var dict = lyon.get("RESERVES")
	if typeof(dict) == TYPE_DICTIONARY:
		for nom in dict:
			if ResourceLoader.exists(DOSSIER + "quartiers/%s/%s.gd" % [nom, nom]):
				for poly in dict[nom]:
					reserves.append(PackedVector2Array(poly))
	return [sans, reserves]


static func _dedans(p: Vector2, sans: Rect2, reserves: Array) -> bool:
	if sans.has_point(p):
		return true
	for poly in reserves:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


## Le terrain lâche : une grille de PAS_TERRAIN m, colorée par sommet (eau au zéro, bois en haut), dont les
## cases entièrement dans le cadre de lyon.gd sont omises.
static func _terrain(racine: Node3D, relief: Script, cadre: Array, sans: Rect2) -> void:
	var x0 := float(cadre[0])
	var z0 := float(cadre[1])
	var nx := int((float(cadre[2]) - x0) / PAS_TERRAIN) + 1
	var nz := int((float(cadre[3]) - z0) / PAS_TERRAIN) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sommet := func(i: int, j: int) -> void:
		var x := x0 + i * PAS_TERRAIN
		var z := z0 + j * PAS_TERRAIN
		var h: float = relief.call("hauteur", x, z)
		var c := COULEUR_SOL
		if h < EAU_SOUS:
			c = COULEUR_EAU
			h = 0.0
		elif h > BOIS_AU_DESSUS:
			c = COULEUR_SOL.lerp(COULEUR_BOIS, clampf((h - BOIS_AU_DESSUS) / 40.0, 0.0, 1.0))
		st.set_color(c)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(x, h - 0.05, z))
	for j in nz - 1:
		for i in nx - 1:
			var case := Rect2(x0 + i * PAS_TERRAIN, z0 + j * PAS_TERRAIN, PAS_TERRAIN, PAS_TERRAIN)
			if sans.encloses(case):
				continue
			sommet.call(i, j)
			sommet.call(i, j + 1)
			sommet.call(i + 1, j)
			sommet.call(i + 1, j)
			sommet.call(i, j + 1)
			sommet.call(i + 1, j + 1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "TerrainVille"
	mi.mesh = st.commit()
	mi.material_override = _materiau()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(mi)


static func _materiau() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	return m


## Les boîtes : un multimaillage pour les murs, un pour les toits, chaque boîte colorée.
static func _boites(racine: Node3D, relief: Script, lyon: Script, sans: Rect2, reserves: Array) -> int:
	var d = Atelier.donnees(VOLUMES)
	if typeof(d) != TYPE_DICTIONARY:
		return 0
	var enduits: Array = []
	for cle in ["ENDUITS_PLACE", "ENDUITS_PENTES"]:
		var liste = lyon.get(cle)
		if liste is Array:
			for e in liste:
				enduits.append(Color(e))
	if enduits.is_empty():
		enduits = [Color("#d8b677"), Color("#cdbfa4")]
	var gardes := []
	for v in d.v:
		var p := Vector2(float(v[0]), float(v[1]))
		if not _dedans(p, sans, reserves):
			gardes.append(v)
	var murs := MultiMesh.new()
	murs.transform_format = MultiMesh.TRANSFORM_3D
	murs.use_colors = true
	murs.mesh = BoxMesh.new()
	murs.instance_count = gardes.size()
	var toits := MultiMesh.new()
	toits.transform_format = MultiMesh.TRANSFORM_3D
	toits.use_colors = true
	var prisme := PrismMesh.new()
	prisme.left_to_right = 0.5
	toits.mesh = prisme
	toits.instance_count = gardes.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 69123
	for i in gardes.size():
		var v: Array = gardes[i]
		var x := float(v[0])
		var z := float(v[1])
		var l := maxf(float(v[2]), 2.0)
		var pr := maxf(float(v[3]), 2.0)
		var ang := float(v[4])
		var h := float(v[5])
		var toit := int(v[6])
		var sol: float = relief.call("hauteur", x, z) - 0.3
		var base := Basis(Vector3.UP, -ang)
		murs.set_instance_transform(i, Transform3D(base.scaled(Vector3(l, h, pr)), Vector3(x, sol + h * 0.5, z)))
		murs.set_instance_color(i, enduits[rng.randi() % enduits.size()])
		var ht := 0.0 if toit == 3 else clampf(pr * 0.35, 1.5, 6.0)
		toits.set_instance_transform(i, Transform3D(base.scaled(Vector3(l + 0.6, maxf(ht, 0.2), pr + 0.6)), Vector3(x, sol + h + maxf(ht, 0.2) * 0.5, z)))
		toits.set_instance_color(i, TOITS.get(toit, TOITS[0]))
	for e in [["MursVille", murs], ["ToitsVille", toits]]:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = e[0]
		mmi.multimesh = e[1]
		mmi.material_override = _materiau()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.set_meta("sans_lointain", true)
		racine.add_child(mmi)
	return gardes.size()
