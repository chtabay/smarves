extends RefCounted
## Le chemin de Passelourdin : de la place, on passe entre la mairie et l'église, on remonte la rue de
## l'Église (le presbytère, la maison qu'on peut acheter chez Maître Garnier), puis le chemin de terre
## part en lacets entre les vignes vendangées, passe le calvaire et le château d'eau, longe une cabane
## de vigne qu'on ne voit pas de la place, et entre dans le bois jusqu'aux rochers.
## Le socle va de la place (z = -8,3) à celui des rochers (z = -61,7), entre x = -10 et x = 8.

const X0 := -10.0
const X1 := 8.0
const Z_PLACE := -8.3
const Z_ROCHERS := -61.7
## L'axe de la rue de l'Église, dans l'ouverture entre la mairie et l'église, et ses deux alignements.
const LANE_X := -2.25
const WEST_FRONT := -3.4
const EAST_FRONT := -1.1
const LANE_END := -21.5
## Le chemin de terre, de la rue de l'Église à l'entrée des rochers.
const PATH := [Vector2(LANE_X, LANE_END), Vector2(LANE_X, -26.0), Vector2(2.5, -32.0), Vector2(2.5, -38.0),
	Vector2(-2.5, -45.0), Vector2(-2.5, -50.0), Vector2(0.0, -55.0), Vector2(0.0, -62.5)]
const PATH_W := 1.6
## Les repères : le calvaire au premier lacet, le château d'eau, la cabane de vigne (sa porte au nord).
const CALVAIRE := Vector3(-0.3, 0, -24.0)
const CHATEAU_EAU := Vector3(5.6, 0, -45.0)
const CABANE := Vector3(-7.2, 0, -43.0)
## La trouvaille de la cabane (Biens.TROUVAILLES).
const TROUVAILLE := "affiche_loto_1987"

const SLATE := Color(0.36, 0.4, 0.48)
const ZINC := Color(0.62, 0.66, 0.68)
const AUTUMN := [Color(0.85, 0.42, 0.08), Color(0.7, 0.14, 0.08), Color(0.9, 0.68, 0.12), Color(0.55, 0.48, 0.1), Color(0.78, 0.26, 0.06)]

## Les maisons de la rue de l'Église, du sud au nord : [côté, largeur, spec]. « jardin » : un mur et un arbre.
const WEST := [
	[2.8, {"floors": 2, "door": "right", "roof_kind": "pignon"}],
	[3.4, {"id": "maison_eglise", "floors": 2, "door": "center", "roof_kind": "hip", "roof": SLATE, "wall": Color(0.95, 0.9, 0.8), "shutter": Color(0.38, 0.55, 0.7), "lit": 0.8, "dormer": false}],
	[2.0, {"kind": "jardin"}],
	[2.6, {"floors": 1, "door": "center"}],
	[2.4, {"floors": 2, "door": "left", "roof_kind": "gable"}],
]
const EAST := [
	[3.4, {"floors": 2, "door": "center", "roof_kind": "hip", "roof": SLATE, "plaque": "Presbytère", "wall": Color(0.97, 0.93, 0.84), "shutter": Color(0.8, 0.82, 0.8)}],
	[2.6, {"floors": 1, "door": "right", "roof_kind": "pignon"}],
	[2.6, {"kind": "jardin"}],
	[2.8, {"floors": 2, "door": "left", "roof": ZINC, "roof_kind": "gable"}],
]

var v: Node3D
var f: RefCounted
var _cabane_area: Area3D


func build(village: Node3D) -> void:
	v = village
	v._board(X0, X1, Z_ROCHERS, Z_PLACE, "", [
		[Vector3(X0 - 0.1, 0, Z_ROCHERS), Vector3(X0 - 0.1, 0, Z_PLACE)],
		[Vector3(X1 + 0.1, 0, Z_ROCHERS), Vector3(X1 + 0.1, 0, Z_PLACE)],
	])
	if not v.mats.has("foliage"):
		var leaf := StandardMaterial3D.new()
		leaf.vertex_color_use_as_albedo = true
		leaf.roughness = 0.9
		v.mats.foliage = leaf
	f = v.FACADES.new(v, v.main.serif, 1981)
	_rue_de_l_eglise()
	_chemin()
	_vignes()
	_calvaire()
	_chateau_d_eau()
	_cabane()
	_lisiere()
	v._glass.append(f.commit(v.mats, v.mats.glass, "CheminDePasselourdin"))
	_figurants()


# --- La rue de l'Église ------------------------------------------------------------------------

func _rue_de_l_eglise() -> void:
	v.main._box(Vector3(EAST_FRONT - WEST_FRONT - 0.1, 0.08, absf(LANE_END - Z_PLACE)), Vector3(LANE_X, 0.0, (Z_PLACE + LANE_END) / 2.0), v.mats.slabs, v)
	_side(WEST, WEST_FRONT, PI / 2.0)
	_side(EAST, EAST_FRONT, -PI / 2.0)
	# La plaque émaillée au coin, face à la place, et deux lanternes sur les façades.
	var corner := Transform3D(Basis(), Vector3(WEST_FRONT - 0.4, 1.55, Z_PLACE - 0.68))
	f.batch.box("trim", corner, Vector3.ZERO, Vector3(1.1, 0.3, 0.03), Color(0.95, 0.95, 0.92))
	f.batch.box("trim", corner, Vector3(0, 0, 0.005), Vector3(1.04, 0.24, 0.03), Color(0.14, 0.26, 0.6))
	var plate := Label3D.new()
	plate.text = "RUE DE L'ÉGLISE"
	plate.font = v.main.serif
	plate.font_size = 40
	plate.pixel_size = 0.0022
	plate.modulate = Color(0.97, 0.97, 0.95)
	plate.outline_size = 0
	plate.position = corner.origin + Vector3(0, 0, 0.03)
	v.add_child(plate)
	for p in [Vector3(WEST_FRONT + 0.12, 1.45, -11.9), Vector3(EAST_FRONT - 0.12, 1.45, -17.2)]:
		v.main._box(Vector3(0.1, 0.16, 0.1), p, v.main.bulb_material, v)
		v._lamp(p, 1.4, Color(1.0, 0.75, 0.45), 4.0)


## Un alignement de la rue, du sud au nord, façades sur front, tournées de rot (+X à l'ouest, -X à l'est).
func _side(row: Array, front: float, rot: float) -> void:
	var out := signf(sin(rot))
	var z := Z_PLACE - 0.7
	for item in row:
		var w: float = item[0]
		var spec: Dictionary = item[1].duplicate()
		var zc := z - w / 2.0
		if spec.get("kind", "") == "jardin":
			var a := Vector3(front, 0, z - 0.1)
			var b := Vector3(front, 0, z - w + 0.1)
			f.garden_wall(a, b, 0.75)
			v.main._solid_box(Vector3(0.25, 1.2, w), Vector3(front, 0.6, zc))
			v._tree(Vector3(front - out * 1.4, 0, zc), "tree_default_fall", 1.4)
		else:
			spec.w = w
			spec.d = 3.0
			var xf := Transform3D(Basis(Vector3.UP, rot), Vector3(front, 0, zc))
			var info: Dictionary = f.house(xf, spec)
			v.main._solid_box(Vector3(spec.d, info.h, w), Vector3(front - out * spec.d / 2.0, info.h / 2.0, zc))
			# Derrière, le jardin clos jusqu'au bord du socle.
			var back: float = front - out * spec.d
			var edge: float = X0 + 0.3 if out > 0 else X1 - 0.3
			if absf(edge - back) > 1.5:
				f.garden_wall(Vector3(back, 0, z - 0.05), Vector3(edge, 0, z - 0.05), 0.6)
		z -= w


# --- Le chemin et les vignes --------------------------------------------------------------------

func _chemin() -> void:
	for i in PATH.size() - 1:
		var a: Vector2 = PATH[i]
		var b: Vector2 = PATH[i + 1]
		var len := a.distance_to(b)
		var seg: MeshInstance3D = v.main._box(Vector3(PATH_W, 0.06, len + PATH_W * 0.5), Vector3((a.x + b.x) / 2.0, 0.0, (a.y + b.y) / 2.0), v.mats.gravel, v)
		seg.rotation.y = atan2(b.x - a.x, b.y - a.y)


## Les rangs de vigne, ceps par ceps, en feuilles d'automne, sur leur terre labourée ;
## hole : [x0, x1, z0, z1] laissé libre.
func _parcelle(x0: float, x1: float, z0: float, z1: float, hole := []) -> void:
	v.main._box(Vector3(x1 - x0, 0.05, absf(z1 - z0)), Vector3((x0 + x1) / 2.0, 0.0, (z0 + z1) / 2.0), v.mats.earth, v)
	var z := maxf(z0, z1) - 0.45
	while z > minf(z0, z1) + 0.3:
		# Le fil de palissage tendu d'un piquet à l'autre.
		f.batch.box("trim", Transform3D(), Vector3((x0 + x1) / 2.0, 0.42, z), Vector3(x1 - x0 - 0.4, 0.02, 0.02), Color(0.4, 0.38, 0.36))
		for px in [x0 + 0.2, x1 - 0.2]:
			f.batch.box("trim", Transform3D(), Vector3(px, 0.3, z), Vector3(0.06, 0.6, 0.06), Color(0.5, 0.4, 0.3))
		var x := x0 + 0.45
		while x < x1 - 0.35:
			if not (hole.size() == 4 and x > hole[0] and x < hole[1] and z < hole[3] and z > hole[2]):
				var h: float = f.rng.randf_range(0.28, 0.4)
				var col: Color = (f.pick(AUTUMN) as Color).lerp(f.pick(AUTUMN), f.rng.randf() * 0.4)
				f.batch.box("foliage", Transform3D(Basis(Vector3.UP, f.rng.randf_range(-0.1, 0.1)), Vector3(x, 0.1 + h / 2.0, z)), Vector3.ZERO, Vector3(0.6, h, 0.34), col)
				f.batch.box("trim", Transform3D(), Vector3(x, 0.08, z), Vector3(0.05, 0.16, 0.05), Color(0.32, 0.22, 0.14))
			x += f.rng.randf_range(0.36, 0.44)
		z -= 0.9


func _vignes() -> void:
	_parcelle(X0 + 0.4, -4.6, -23.0, -36.5)
	_parcelle(1.4, X1 - 0.4, -22.6, -28.8)
	_parcelle(4.0, X1 - 0.4, -31.0, -40.0)
	_parcelle(X0 + 0.4, -4.4, -38.0, -48.5, [-8.9, -5.5, -45.0, -41.0])
	# Des murets de pierre sèche entre les parcelles, et les piquets de bout de rang.
	f.garden_wall(Vector3(X0 + 0.3, 0, -37.3), Vector3(-4.4, 0, -37.3), 0.45, Color(0.85, 0.8, 0.68))
	f.garden_wall(Vector3(4.0, 0, -30.0), Vector3(X1 - 0.3, 0, -30.0), 0.45, Color(0.85, 0.8, 0.68))


# --- Les repères ---------------------------------------------------------------------------------

## Le calvaire du premier lacet : un socle à deux marches, le fût, la croix, et le lumignon du dimanche.
func _calvaire() -> void:
	var xf := Transform3D(Basis(), CALVAIRE)
	var stone := Color(0.9, 0.86, 0.76)
	f.batch.box("trim", xf, Vector3(0, 0.1, 0), Vector3(1.1, 0.2, 1.1), stone.darkened(0.1))
	f.batch.box("trim", xf, Vector3(0, 0.3, 0), Vector3(0.75, 0.2, 0.75), stone)
	f.batch.box("wall", xf, Vector3(0, 1.2, 0), Vector3(0.16, 1.7, 0.16), stone)
	f.batch.box("wall", xf, Vector3(0, 1.75, 0), Vector3(0.7, 0.14, 0.14), stone)
	v.main._solid_box(Vector3(1.1, 2.0, 1.1), CALVAIRE + Vector3(0, 1.0, 0))
	v.main._box(Vector3(0.06, 0.1, 0.06), CALVAIRE + Vector3(0.25, 0.45, 0.3), v.main.bulb_material, v)
	v._lamp(CALVAIRE + Vector3(0.25, 0.7, 0.4), 0.9, Color(1.0, 0.7, 0.4), 2.5)


## Le château d'eau : un fût de béton, la cuve en champignon peinte au nom du bourg, le feu rouge
## au sommet pour les avions de Biard, et un projecteur au pied : on le voit de toute la maquette.
func _chateau_d_eau() -> void:
	var xf := Transform3D(Basis(), CHATEAU_EAU)
	var beton := Color(0.88, 0.86, 0.8)
	f.batch.cylinder("wall", xf, Vector3.ZERO, 0.6, 5.2, beton, 12)
	var steps := [[0.85, 5.0], [1.15, 5.3], [1.45, 5.6]]
	for s in steps:
		f.batch.cylinder("wall", xf, Vector3(0, s[1], 0), s[0], 0.32, beton.darkened(0.04), 16)
	f.batch.cylinder("wall", xf, Vector3(0, 5.9, 0), 1.75, 1.8, beton.lightened(0.04), 20)
	f.batch.cylinder("trim", xf, Vector3(0, 6.15, 0), 1.78, 0.18, Color(0.2, 0.36, 0.62), 20)
	f.batch.cylinder("trim", xf, Vector3(0, 7.7, 0), 1.85, 0.14, beton.darkened(0.1), 20)
	f.batch.cylinder("trim", xf, Vector3(0, 7.84, 0), 0.6, 0.3, beton.darkened(0.15), 10)
	# La porte de service et l'échelle.
	f.batch.box("trim", xf, Vector3(0, 0.5, 0.6), Vector3(0.45, 0.95, 0.04), Color(0.3, 0.4, 0.5))
	for x in [-0.12, 0.12]:
		f.batch.box("trim", xf, Vector3(x + 0.5, 3.0, 0.42), Vector3(0.03, 4.4, 0.03), Color(0.5, 0.5, 0.52))
	v.main._solid_box(Vector3(1.3, 5.0, 1.3), CHATEAU_EAU + Vector3(0, 2.5, 0))
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = "SMARVES"
		l.font = v.main.serif
		l.font_size = 72
		l.pixel_size = 0.009
		l.modulate = Color(0.16, 0.28, 0.55)
		l.outline_size = 0
		l.position = CHATEAU_EAU + Vector3(0, 6.9, 1.77 * side)
		l.rotation.y = 0.0 if side > 0 else PI
		v.add_child(l)
	# Le feu d'obstacle, qui clignote.
	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = Color(1.0, 0.1, 0.08)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.1, 0.05)
	bulb.emission_energy_multiplier = 3.0
	v.main._box(Vector3(0.14, 0.14, 0.14), CHATEAU_EAU + Vector3(0, 8.22, 0), bulb, v)
	var red := OmniLight3D.new()
	red.light_color = Color(1.0, 0.15, 0.1)
	red.light_energy = 1.6
	red.omni_range = 3.5
	red.position = CHATEAU_EAU + Vector3(0, 8.4, 0)
	v.add_child(red)
	var blink := v.create_tween().set_loops()
	blink.tween_callback(_beacon.bind(red, bulb, false)).set_delay(1.1)
	blink.tween_callback(_beacon.bind(red, bulb, true)).set_delay(0.5)
	# Le projecteur qui éclaire la cuve depuis le pied, côté village.
	var spot := SpotLight3D.new()
	spot.light_color = Color(0.95, 0.92, 1.0)
	spot.light_energy = 5.0
	spot.spot_range = 9.0
	spot.spot_angle = 22.0
	spot.shadow_enabled = false
	spot.position = CHATEAU_EAU + Vector3(0, 0.2, 3.2)
	spot.rotation.x = deg_to_rad(68.0)
	v.add_child(spot)



func _beacon(red: OmniLight3D, bulb: StandardMaterial3D, on: bool) -> void:
	red.light_energy = 1.6 if on else 0.0
	bulb.emission_energy_multiplier = 3.0 if on else 0.3

# --- La cabane de vigne (lieu caché) ----------------------------------------------------------------

## Au milieu des rangs, une cabane de pierre au toit de zinc ; sa porte donne au nord, à l'abri des regards
## de la place. Le comité des fêtes y range ses vieilles affiches.
func _cabane() -> void:
	var xf := Transform3D(Basis(Vector3.UP, PI), CABANE + Vector3(0, 0, -0.85))
	var info: Dictionary = f.house(xf, {"w": 1.9, "d": 1.7, "floors": 1, "door": "center", "roof_kind": "gable", "roof": ZINC,
		"wall": Color(0.86, 0.8, 0.68), "shutter": Color(0.42, 0.5, 0.36), "lit": 1.0, "chimney": false, "dormer": false, "back": false})
	v.main._solid_box(Vector3(1.9, info.h, 1.7), CABANE + Vector3(0, info.h / 2.0, 0))
	# Le seuil de terre battue devant la porte, les bonbonnes et la brouette.
	v.main._box(Vector3(2.2, 0.06, 1.3), CABANE + Vector3(0, 0.01, -1.6), v.mats.gravel, v)
	for i in 2:
		f.batch.cylinder("trim", Transform3D(), CABANE + Vector3(1.25, 0, -1.2 - i * 0.35), 0.14, 0.32, Color(0.25, 0.45, 0.3), 8)
	var door: Vector3 = xf * info.door
	v._lamp(door + Vector3(0, 0.9, -0.6), 0.8, Color(1.0, 0.72, 0.4), 2.5)
	_cabane_area = Area3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.4, 1.4, 1.0)
	cs.shape = b
	cs.position = Vector3(0, 0.7, -0.5)
	_cabane_area.add_child(cs)
	_cabane_area.position = door
	_cabane_area.set_meta("interact", "lot")
	_cabane_area.set_meta("action", fouiller)
	v.add_child(_cabane_area)
	_refresh_cabane()


func _has_trouvaille() -> bool:
	var biens := v.get_node_or_null("/root/Biens")
	return biens != null and biens.trouvailles.has(TROUVAILLE)


func _refresh_cabane() -> void:
	if _cabane_area == null:
		return
	if _has_trouvaille():
		_cabane_area.set_meta("prompt", "La cabane de vigne — des sécateurs, des bonbonnes, et un clou où pendait l'affiche")
	else:
		_cabane_area.set_meta("prompt", "E : pousser la porte de la cabane")


## On pousse la porte : la première fois, on repart avec l'affiche du loto de 1987.
func fouiller() -> void:
	var biens := v.get_node_or_null("/root/Biens")
	if biens == null or _has_trouvaille():
		v.main._announce("Des sécateurs, des bonbonnes, l'odeur du moût. Rien d'autre à prendre.")
		return
	biens.trouvailles.append(TROUVAILLE)
	biens.changed.emit()
	if v.main.has_method("_announce"):
		v.main._announce("Derrière les bonbonnes, une affiche roulée : le grand loto de 1987, salle Rabelais. Vous la gardez.")
	_refresh_cabane()


# --- La lisière et les figurants --------------------------------------------------------------------

func _lisiere() -> void:
	var trees := [[-7.8, -51.0, "tree_oak_fall", 1.8], [-5.0, -54.5, "tree_default_fall", 1.6], [-8.6, -57.5, "tree_fat_fall", 1.9],
		[-4.2, -59.6, "tree_oak_fall", 1.5], [3.4, -50.5, "tree_cone_fall", 1.6], [6.6, -53.5, "tree_oak_fall", 1.9],
		[3.0, -57.8, "tree_default_fall", 1.7], [6.4, -59.5, "tree_fat_fall", 1.6], [-8.6, -22.0, "tree_cone_fall", 1.3],
		[7.0, -42.0, "tree_default_fall", 1.4], [-1.0, -48.0, "tree_fat_fall", 1.3]]
	for t in trees:
		v._tree(Vector3(t[0], 0, t[1]), t[2], t[3])
	for p in [Vector3(-6.2, 0, -60.4), Vector3(4.6, 0, -61.0), Vector3(-2.2, 0, -60.8), Vector3(7.0, 0, -56.6)]:
		var rock: Node3D = v._place(v.KK + "medieval_decoration/nature/rock_single_%s.gltf" % ["A", "C", "D", "B"][int(absf(p.x)) % 4], p, 3.4, p.x * 40.0)
		v.main._solid(rock, 0.3)
	for p in [Vector3(-2.0, 0, -52.0), Vector3(1.6, 0, -53.6), Vector3(4.6, 0, -48.6), Vector3(-6.2, 0, -49.2)]:
		v._place(v.KN + "plant_bushLarge.glb", p, 1.3, p.z * 30.0)
	# Quelques lanternes sur poteau de bois, comme la commune en a mis le long des chemins.
	for p in [Vector3(3.5, 0, -33.5), Vector3(-3.6, 0, -44.0), Vector3(-3.0, 0, -52.5), Vector3(1.0, 0, -59.0)]:
		f.batch.box("trim", Transform3D(), p + Vector3(0, 1.1, 0), Vector3(0.1, 2.2, 0.1), Color(0.4, 0.3, 0.22))
		f.batch.box("trim", Transform3D(), p + Vector3(0.22, 2.12, 0), Vector3(0.44, 0.05, 0.05), Color(0.3, 0.3, 0.3))
		v.main._box(Vector3(0.14, 0.14, 0.14), p + Vector3(0.42, 2.02, 0), v.main.bulb_material, v)
		v._lamp(p + Vector3(0.42, 1.9, 0), 2.0, Color(1.0, 0.74, 0.45), 6.0)
		v.main._solid_box(Vector3(0.2, 2.2, 0.2), p + Vector3(0, 1.1, 0))
	# Le banc du point de vue, d'où l'on voit les toits du bourg et le clocher.
	v._place(v.KK + "city/bench.gltf", Vector3(1.8, 0.0, -51.2), 2.2, 180.0)


func _figurants() -> void:
	v.main._villager("passant-eglise", Vector3(LANE_X + 0.3, 0.06, -9.4), 180.0, "idle",
		[Vector3(LANE_X + 0.3, 0.06, -9.4), Vector3(LANE_X + 0.3, 0.06, -20.5)])
	v.main._villager("voisine-eglise", Vector3(WEST_FRONT + 0.45, 0.06, -10.6), 90.0)
	v.main._villager("promeneur-vignes", Vector3(LANE_X, 0.06, -26.0), 140.0, "idle",
		[Vector3(LANE_X, 0.06, -26.0), Vector3(2.5, 0.06, -32.0), Vector3(2.5, 0.06, -38.0), Vector3(-2.5, 0.06, -45.0)])
