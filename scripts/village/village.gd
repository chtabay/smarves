extends Node3D
## Les rues du bourg, qui prolongent la place de la Mairie jusqu'aux environs, sur une seule maquette.
## Ce fichier est le propriétaire de l'agencement extérieur : les rues, les façades, les emplacements
## réservés aux lieux à venir (LOTS), les passages entre les socles et la vie de la rue.
##
## Repères : +X à l'est (bois de Saint-Pierre), -X à l'ouest (le Clain, le Moulin des Dames),
## -Z au nord (Passelourdin). La route traverse la place en z = 6,4.

const FACADES := preload("res://scripts/village/facades.gd")
const KK := "res://assets/kaykit/"
const KN := "res://assets/kenney/nature/"
const KC := "res://assets/kenney/cars/"

const ROAD_Z := 6.4
const ROAD_W := 2.4
## Les voitures roulent de part en part de la maquette, entre ces deux abscisses.
const ROAD_WEST := -80.0
const ROAD_EAST := 12.5
## Alignement des façades de part et d'autre de la route.
const NORTH_FRONT := 4.3
const SOUTH_FRONT := 8.5

## La rue du Clain : de la place (x = -11,3) au socle du Moulin des Dames (x = -58,9).
const CLAIN_X0 := -11.3
const CLAIN_X1 := -58.9
const BOARD_Z0 := -8.3
const BOARD_Z1 := 15.3

## Les passages ouverts dans les bords des socles : centre du socle → côté → intervalles libres.
## Côtés : "W" et "E" (intervalle en z), "N" et "S" (intervalle en x).
const OPENINGS := {
	Vector3(0, 0, 0): {"W": [[NORTH_FRONT, 8.1]]},
	Vector3(-70, 0, 0): {"E": [[5.0, 8.1]]},
}

## Les emplacements de la rue, d'est en ouest. Côté nord, face à la caméra, les maisons à étage ;
## côté sud, entre la caméra et la rue, des maisons basses, pour que la maquette se lise de biais. Les « lot_ » sont réservés aux autres chantiers :
## une façade fermée attend son lieu (voir docs/VILLAGE.md).
const NORTH_ROW := [
	{"id": "notaire", "w": 2.8, "floors": 2, "door": "center", "roof_kind": "hip", "plaque": "Maître Garnier\nNotaire", "lit": 0.9, "wall": Color(0.97, 0.93, 0.84), "shutter": Color(0.36, 0.4, 0.38)},
	{"id": "poste", "w": 3.6, "floors": 2, "roof_kind": "hip", "shop": {"name": "POSTES · PTT", "sub": "Télégraphe · Téléphone", "color": Color(0.13, 0.22, 0.48), "ink": Color(1.0, 0.84, 0.2)}},
	{"w": 2.8, "floors": 2, "roof_kind": "pignon"},
	{"id": "boucherie", "w": 3.2, "floors": 2, "shop": {"name": "Boucherie Texier", "sub": "Charcuterie · Volailles", "color": Color(0.58, 0.1, 0.12), "ink": Color(1.0, 0.92, 0.75), "awning": [Color(0.8, 0.12, 0.14), Color(0.96, 0.94, 0.9)]}},
	{"w": 2.6, "floors": 1, "door": "center"},
	{"kind": "porche", "w": 2.6},
	{"id": "lot_reserve", "w": 3.4, "floors": 2, "closed": true, "shop": {"name": "Prochainement", "sub": "Un nouveau commerce", "color": Color(0.16, 0.32, 0.24), "ink": Color(0.95, 0.85, 0.55)}},
	{"w": 3.0, "floors": 3, "door": "right", "roof_kind": "hip", "wall": Color(0.97, 0.9, 0.78), "shutter": Color(0.38, 0.55, 0.7)},
	{"kind": "ruelle", "w": 2.4},
	{"id": "coiffure", "w": 3.0, "floors": 2, "shop": {"name": "Gisèle Coiffure", "sub": "Dames · Messieurs · Mise en plis", "color": Color(0.82, 0.42, 0.55), "ink": Color(1.0, 0.97, 0.92), "awning": [Color(0.92, 0.55, 0.68), Color(0.98, 0.95, 0.92)], "glow": Color(1.0, 0.85, 0.75)}},
	{"id": "couture", "w": 2.8, "floors": 2, "shop": {"name": "Raymonde", "sub": "Couture · Retouches", "color": Color(0.32, 0.2, 0.42), "ink": Color(1.0, 0.88, 0.7), "awning": [Color(0.5, 0.32, 0.6), Color(0.97, 0.94, 0.9)], "glow": Color(1.0, 0.86, 0.68), "mannequin": true}},
	{"w": 3.4, "floors": 2, "roof_kind": "hip", "door": "center"},
	{"kind": "jardin", "w": 2.4},
]
const SOUTH_ROW := [
	{"w": 2.8, "floors": 1},
	{"id": "pizzeria", "w": 3.4, "floors": 1, "shop": {"name": "Pizzeria du Clain", "sub": "Pizzas au feu de bois", "color": Color(0.14, 0.36, 0.2), "ink": Color(1.0, 0.95, 0.85), "awning": [Color(0.15, 0.5, 0.25), Color(0.97, 0.95, 0.9), Color(0.8, 0.15, 0.15), Color(0.97, 0.95, 0.9)], "glow": Color(1.0, 0.7, 0.4)}},
	{"w": 2.6, "floors": 1, "door": "right", "roof_kind": "pignon"},
	{"id": "epicerie", "w": 3.8, "floors": 1, "shop": {"name": "L'Épicerie du Bourg", "sub": "Alimentation · Primeurs · Gaz", "color": Color(0.18, 0.32, 0.58), "ink": Color(1.0, 0.9, 0.6), "awning": [Color(0.95, 0.55, 0.15), Color(0.97, 0.94, 0.88)]}},
	{"id": "fleurs", "w": 3.0, "floors": 1, "shop": {"name": "Fleurs Odette", "sub": "Mariages · Fêtes · Deuils", "color": Color(0.38, 0.55, 0.32), "ink": Color(1.0, 0.98, 0.9), "awning": [Color(0.55, 0.72, 0.42), Color(0.98, 0.96, 0.9)], "glow": Color(1.0, 0.9, 0.7)}},
	{"kind": "jardin", "w": 2.8},
	{"id": "lot_a_ceder", "w": 3.2, "floors": 1, "closed": true, "shop": {"name": "Local à céder", "sub": "S'adresser au Crédit Smarvois", "color": Color(0.35, 0.3, 0.28), "ink": Color(0.95, 0.9, 0.8)}},
	{"w": 2.8, "floors": 1},
	{"id": "bibliotheque", "w": 4.4, "floors": 2, "roof_kind": "hip", "shop": {"name": "Bibliothèque municipale", "sub": "Mardi · Samedi", "color": Color(0.9, 0.86, 0.76), "ink": Color(0.15, 0.2, 0.35), "door": "left"}},
	{"w": 3.0, "floors": 1},
	{"w": 2.6, "floors": 1, "door": "center", "roof_kind": "pignon"},
	{"w": 3.2, "floors": 1, "roof_kind": "hip"},
]

## Ce qu'on lit en s'approchant d'une devanture.
const PROMPTS := {
	"notaire": "E : entrer à l'étude de Maître Garnier",
	"couture": "E : entrer chez Raymonde, couture et retouches",
	"poste": "La poste — fermée à cette heure",
	"boucherie": "Boucherie Texier — fermée pour l'instant",
	"lot_reserve": "Local réservé — un nouveau commerce s'installe bientôt",
	"coiffure": "Gisèle Coiffure — sur rendez-vous",
	"pizzeria": "Pizzeria du Clain — complet ce soir",
	"epicerie": "L'Épicerie du Bourg — fermée pour l'instant",
	"fleurs": "Fleurs Odette — fermé pour l'instant",
	"lot_a_ceder": "Local à céder — s'adresser au Crédit Smarvois",
	"bibliotheque": "Bibliothèque municipale — ouverte mardi et samedi",
}

## Les emplacements posés, par identifiant : {pos (milieu du pied de façade), rot, w, d, door (monde)}.
var lots := {}
var main: Node3D
var mats := {}
var _glass: Array[MultiMesh] = []
var _flicker := 2.0
var _cars: Array[Node3D] = []


# --- Bords des socles, avec leurs passages ----------------------------------------------------

## Les quatre bords invisibles d'un socle de 22 × 16, percés là où une rue passe.
static func plinth_walls(m: Node3D, c: Vector3) -> void:
	var gaps: Dictionary = OPENINGS.get(c, {})
	for side in ["N", "S", "W", "E"]:
		var along_x: bool = side == "N" or side == "S"
		var lo := -11.2 if along_x else -8.2
		var hi := -lo
		var offset: float = c.x if along_x else c.z
		var segs := [[lo, hi]]
		for g in gaps.get(side, []):
			var nxt := []
			for s in segs:
				var g0: float = g[0] - offset
				var g1: float = g[1] - offset
				if g1 <= s[0] or g0 >= s[1]:
					nxt.append(s)
					continue
				if g0 > s[0]:
					nxt.append([s[0], g0])
				if g1 < s[1]:
					nxt.append([g1, s[1]])
			segs = nxt
		for s in segs:
			var mid: float = (s[0] + s[1]) / 2.0
			var len: float = s[1] - s[0]
			match side:
				"N":
					m._solid_box(Vector3(len, 3.0, 0.2), c + Vector3(mid, 1.5, -8.1))
				"S":
					m._solid_box(Vector3(len, 3.0, 0.2), c + Vector3(mid, 1.5, 8.1))
				"W":
					m._solid_box(Vector3(0.2, 3.0, len), c + Vector3(-11.1, 1.5, mid))
				"E":
					m._solid_box(Vector3(0.2, 3.0, len), c + Vector3(11.1, 1.5, mid))


# --- Construction ------------------------------------------------------------------------------

func build(m: Node3D) -> void:
	main = m
	name = "Village"
	_make_materials()
	_rue_du_clain()
	_tournee()
	_capture_view()


func _make_materials() -> void:
	var stone_shader: Shader = load("res://shaders/village_stone.gdshader")
	var wall := ShaderMaterial.new()
	wall.shader = stone_shader
	wall.set_shader_parameter("grain", main._noise_tex(false, 0.06, Color(0.8, 0.76, 0.7)))
	wall.set_shader_parameter("grain_scale", 0.8)
	mats.wall = wall
	var trim := ShaderMaterial.new()
	trim.shader = stone_shader
	trim.set_shader_parameter("grain", main._noise_tex(false, 0.2, Color(0.88, 0.86, 0.83)))
	trim.set_shader_parameter("grain_scale", 1.0)
	trim.set_shader_parameter("rough", 0.72)
	mats.trim = trim
	var roof := ShaderMaterial.new()
	roof.shader = load("res://shaders/roof_tiles.gdshader")
	mats.roof = roof
	var glass := ShaderMaterial.new()
	glass.shader = load("res://shaders/window_glow.gdshader")
	mats.glass = glass
	var slabs := ShaderMaterial.new()
	slabs.shader = load("res://shaders/cobbles.gdshader")
	slabs.set_shader_parameter("stone_a", Color(0.78, 0.74, 0.66))
	slabs.set_shader_parameter("stone_b", Color(0.68, 0.64, 0.58))
	slabs.set_shader_parameter("joint", Color(0.45, 0.42, 0.38))
	slabs.set_shader_parameter("size", 0.32)
	mats.slabs = slabs
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.09, 0.09, 0.1)
	asphalt.albedo_texture = main._noise_tex(false, 0.5, Color(0.8, 0.8, 0.82))
	asphalt.uv1_triplanar = true
	asphalt.roughness = 0.3
	mats.asphalt = asphalt
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.3, 0.42, 0.2)
	grass.albedo_texture = main._noise_tex(false, 0.08, Color(0.72, 0.8, 0.66))
	grass.uv1_triplanar = true
	grass.roughness = 1.0
	mats.grass = grass
	var gravel := StandardMaterial3D.new()
	gravel.albedo_color = Color(0.74, 0.68, 0.56)
	gravel.albedo_texture = main._noise_tex(false, 0.4, Color(0.75, 0.72, 0.68))
	gravel.uv1_triplanar = true
	gravel.roughness = 1.0
	mats.gravel = gravel
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(0.33, 0.22, 0.14)
	earth.albedo_texture = main._noise_tex(false, 0.6, Color(0.7, 0.66, 0.6))
	earth.uv1_triplanar = true
	earth.roughness = 1.0
	mats.earth = earth
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	mats.water = water
	var walnut := StandardMaterial3D.new()
	walnut.albedo_color = Color(0.17, 0.09, 0.05)
	walnut.roughness = 0.4
	mats.walnut = walnut


## Un socle de bois en plus, de x0 à x1 et z0 à z1, avec sa pelouse et ses bords invisibles.
func _board(x0: float, x1: float, z0: float, z1: float, title: String, walls: Array) -> void:
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	var sx := absf(x1 - x0)
	var sz := absf(z1 - z0)
	main._box(Vector3(sx, 0.8, sz), Vector3(cx, -0.5, cz), mats.walnut, self)
	main._box(Vector3(sx, 0.1, sz), Vector3(cx, -0.05, cz), mats.grass, self)
	main._solid_box(Vector3(sx, 0.4, sz), Vector3(cx, -0.2, cz))
	var plaque := Label3D.new()
	plaque.text = title.to_upper()
	plaque.font = main.serif
	plaque.font_size = 80
	plaque.pixel_size = 0.004
	plaque.modulate = Color(0.95, 0.75, 0.4)
	plaque.position = Vector3(cx, -0.5, maxf(z0, z1) + 0.01)
	add_child(plaque)
	for w in walls:
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		var mid := (a + b) / 2.0
		var size := Vector3(maxf(0.2, absf(b.x - a.x)), 3.0, maxf(0.2, absf(b.z - a.z)))
		main._solid_box(size, mid + Vector3(0, 1.5, 0))


# --- La rue du Clain ---------------------------------------------------------------------------

func _rue_du_clain() -> void:
	var x0 := CLAIN_X0
	var x1 := CLAIN_X1
	_board(x0, x1, BOARD_Z0, BOARD_Z1, "Rue du Clain", [
		[Vector3(x0, 0, BOARD_Z0 - 0.1), Vector3(x1, 0, BOARD_Z0 - 0.1)],
		[Vector3(x0, 0, BOARD_Z1 + 0.1), Vector3(x1, 0, BOARD_Z1 + 0.1)],
		[Vector3(x1 - 0.1, 0, 8.1), Vector3(x1 - 0.1, 0, BOARD_Z1)],
		[Vector3(x0 + 0.1, 0, 8.1), Vector3(x0 + 0.1, 0, BOARD_Z1)],
	])
	var len := absf(x1 - x0)
	var cx := (x0 + x1) / 2.0
	# La chaussée, ses pointillés, ses trottoirs de dalles calcaires et leurs bordures.
	main._box(Vector3(len, 0.11, ROAD_W), Vector3(cx, -0.04, ROAD_Z), mats.asphalt, self)
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(0.85, 0.85, 0.8)
	var dashes := MultiMesh.new()
	dashes.transform_format = MultiMesh.TRANSFORM_3D
	var dm := BoxMesh.new()
	dm.size = Vector3(0.9, 0.02, 0.08)
	dm.material = line
	dashes.mesh = dm
	var n := int(len / 2.0)
	dashes.instance_count = n
	for i in n:
		dashes.set_instance_transform(i, Transform3D(Basis(), Vector3(x0 - 1.0 - i * 2.0, 0.02, ROAD_Z)))
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = dashes
	add_child(dmi)
	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.82, 0.8, 0.75)
	curb.roughness = 0.8
	for z in [NORTH_FRONT + 0.45, SOUTH_FRONT - 0.45]:
		main._box(Vector3(len, 0.12, 0.9), Vector3(cx, 0.0, z), mats.slabs, self)
	for z in [ROAD_Z - ROAD_W / 2.0 - 0.04, ROAD_Z + ROAD_W / 2.0 + 0.04]:
		main._box(Vector3(len, 0.14, 0.08), Vector3(cx, 0.0, z), curb, self)

	var f := FACADES.new(self, main.serif, 1962)
	_row(f, NORTH_ROW, true)
	_row(f, SOUTH_ROW, false)
	_lavoir(f)
	_placette(f)
	_street_props(f)
	_glass.append(f.commit(mats, mats.glass, "RueDuClain"))
	for g in f.glows:
		var l := OmniLight3D.new()
		l.light_color = g[1]
		l.light_energy = 1.1
		l.omni_range = 2.6
		l.light_volumetric_fog_energy = 0.8
		l.position = g[0]
		add_child(l)
	_life()


## Une rangée de façades, de la place vers l'ouest. north : côté nord, façades tournées vers le sud.
func _row(f: FACADES, row: Array, north: bool) -> void:
	var x := CLAIN_X0 - 0.5
	var front := NORTH_FRONT if north else SOUTH_FRONT
	var back := BOARD_Z0 + 0.3 if north else BOARD_Z1 - 0.3
	var rot := 0.0 if north else PI
	var out := 1.0 if north else -1.0
	for spec in row:
		var w: float = spec.w
		var cx := x - w / 2.0
		var xf := Transform3D(Basis(Vector3.UP, rot), Vector3(cx, 0, front))
		var kind: String = spec.get("kind", "house")
		var d := 3.2
		match kind:
			"house":
				var s: Dictionary = spec.duplicate(true)
				d = [3.0, 3.3, 3.6][f.rng.randi() % 3] if north else [2.6, 2.8][f.rng.randi() % 2]
				s.d = d
				if not s.has("lit"):
					s.lit = 0.72
				var info: Dictionary = f.house(xf, s)
				main._solid_box(Vector3(w, info.h + 1.0, d), Vector3(cx, (info.h + 1.0) / 2.0, front - out * d / 2.0))
				var door: Vector3 = xf * info.door
				if spec.has("id"):
					lots[spec.id] = {"pos": Vector3(cx, 0, front), "rot": rot, "w": w, "d": d, "door": door}
					_door_area(spec.id, door, rot)
			"porche":
				# Un portail sur une cour pavée, et l'arbre de la cour qui dépasse du mur.
				f.gate(Vector3(cx, 0, front - out * 0.1), rot, w - 0.7, f.pick(f.SHUTTERS))
				main._box(Vector3(w, 0.06, 3.0), Vector3(cx, 0.0, front - out * 1.6), mats.gravel, self)
				main._solid_box(Vector3(w, 2.0, 0.3), Vector3(cx, 1.0, front - out * 0.1))
				_tree(Vector3(cx, 0, front - out * 2.4), "tree_oak_fall", 1.6)
			"jardin":
				f.garden_wall(Vector3(x, 0, front - out * 0.1), Vector3(x - w, 0, front - out * 0.1), 0.8)
				main._solid_box(Vector3(w, 2.0, 0.3), Vector3(cx, 1.0, front - out * 0.1))
				_tree(Vector3(cx, 0, front - out * 1.6), ["tree_fat_fall", "tree_default_fall", "tree_oak_fall"][f.rng.randi() % 3], 1.5)
				for i in 3:
					_place(KN + "flower_%s.glb" % ["redA", "yellowA", "purpleA"][i], Vector3(cx - 0.8 + i * 0.8, 0, front - out * 0.5), 1.2)
			"ruelle":
				_ruelle(f, cx, w, front, out)
		# Le fond de la parcelle : jardin derrière la maison, mur mitoyen, potager, arbre fruitier.
		if kind != "ruelle":
			var z_b := front - out * (d + 0.05)
			if kind == "house":
				_backyard(f, cx, w, z_b, back, out)
			f.garden_wall(Vector3(x, 0, z_b if kind == "house" else front - out * 0.2), Vector3(x, 0, back), 0.4)
		x -= w
	# Le mur du fond de la maquette, derrière les jardins.
	f.garden_wall(Vector3(CLAIN_X0 - 0.5, 0, back), Vector3(x, 0, back), 0.45)


func _backyard(f: FACADES, cx: float, w: float, z0: float, z1: float, out: float) -> void:
	var depth := absf(z1 - z0)
	var r: float = f.rng.randf()
	if r < 0.45:
		# Un potager en rangs.
		for i in 3:
			_place(KN + "crops_dirtRow.glb", Vector3(cx - 0.6 + i * 0.6, 0, z0 - out * depth * 0.55), 1.0, 0.0)
			_place(KN + "crops_leafsStageB.glb", Vector3(cx - 0.6 + i * 0.6, 0, z0 - out * depth * 0.55), 1.0, 0.0)
		_tree(Vector3(cx + w * 0.25, 0, z0 - out * depth * 0.85), "tree_default_fall", 1.3)
	elif r < 0.85:
		_tree(Vector3(cx, 0, z0 - out * depth * 0.5), ["tree_oak_fall", "tree_fat_fall", "tree_default_fall", "tree_cone_fall"][f.rng.randi() % 3], 1.6)
		_place(KN + "log_stack.glb", Vector3(cx - w * 0.3, 0, z0 - out * 0.6), 0.9, 90.0)
	else:
		# Une remise au fond du jardin, et la pelouse.
		var xf := Transform3D(Basis(Vector3.UP, 0.0 if out > 0 else PI), Vector3(cx, 0, z0 - out * (depth - 1.6)))
		var shed: Dictionary = f.house(xf, {"w": minf(w - 0.6, 2.0), "d": 1.4, "floors": 1, "lit": 0.0, "chimney": false, "door": "center", "back": false})
		main._solid_box(Vector3(minf(w - 0.6, 2.0), shed.h, 1.4), xf * Vector3(0, shed.h / 2.0, -0.7))
		_place(KN + "pot_large.glb", Vector3(cx + w * 0.3, 0, z0 - out * 0.6), 1.0)


## La ruelle qui monte vers Passelourdin, entre deux murs de jardin.
func _ruelle(f: FACADES, cx: float, w: float, front: float, out: float) -> void:
	main._box(Vector3(w - 0.4, 0.06, absf(front - BOARD_Z0)), Vector3(cx, 0.0, (front + BOARD_Z0) / 2.0), mats.gravel, self)
	for s in [-1.0, 1.0]:
		var xx: float = cx + s * (w / 2.0 - 0.1)
		f.garden_wall(Vector3(xx, 0, front - 3.6), Vector3(xx, 0, BOARD_Z0 + 0.3), 0.75)
	_signpost(Vector3(cx + 0.9, 0, front - 0.6), 0.0, "Rochers de Passelourdin  ↑", "passelourdin")


## Le lavoir sur le Clain, au bout de la rue : un bassin couvert d'un toit à un pan.
func _lavoir(f: FACADES) -> void:
	var x_start := -50.4
	var x_end := CLAIN_X1
	var cx := (x_start + x_end) / 2.0
	var len := absf(x_end - x_start)
	# Le Clain qui sort du socle du moulin et vient finir au lavoir.
	main._box(Vector3(len, 0.1, 3.4), Vector3(cx, -0.02, 3.2), mats.water, self)
	main._solid_box(Vector3(len, 2.0, 3.4), Vector3(cx, 1.0, 3.2))
	var stone := Color(0.88, 0.82, 0.7)
	# Le parapet entre la rivière et la rue, et le mur de fin de bief.
	f.garden_wall(Vector3(x_start, 0, 5.05), Vector3(x_end, 0, 5.05), 0.4, stone)
	f.garden_wall(Vector3(x_start, 0, 1.4), Vector3(x_start, 0, 5.0), 0.5, stone)
	main._box(Vector3(len, 0.12, 0.3), Vector3(cx, 0.0, 1.35), mats.slabs, self)
	main._solid_box(Vector3(len, 2.0, 0.3), Vector3(cx, 1.0, 5.05))
	# Le lavoir : quatre poteaux, la charpente, le toit de tuiles qui penche vers l'eau.
	var lx := -54.5
	var xf := Transform3D(Basis(), Vector3(lx, 0, 3.2))
	for px in [-1.6, 1.6]:
		for pz in [-1.5, 1.5]:
			f.batch.box("trim", xf, Vector3(px, 0.75, pz), Vector3(0.16, 1.5, 0.16), Color(0.45, 0.3, 0.18))
	f.batch.box("trim", xf, Vector3(0, 1.52, 0), Vector3(3.6, 0.1, 3.4), Color(0.42, 0.28, 0.16))
	f.batch.quad("roof", xf, [Vector3(-2.0, 1.55, -1.9), Vector3(2.0, 1.55, -1.9), Vector3(2.0, 2.1, 1.9), Vector3(-2.0, 2.1, 1.9)],
		Vector3(0, 0.99, -0.14), Color(0.86, 0.48, 0.3), [Vector2(0, 0), Vector2(4, 0), Vector2(4, 3.85), Vector2(0, 3.85)])
	# Les pierres à laver, en pente vers l'eau.
	for s in [-1.0, 1.0]:
		f.batch.box_tilted("trim", xf, Vector3(0, 0.08, s * 1.15), Vector3(3.0, 0.08, 0.5), s * deg_to_rad(12.0), stone.lightened(0.1))
	_lamp(Vector3(lx, 1.35, 3.2), 0.9, Color(1.0, 0.72, 0.4), 3.5)
	# Les saules du pré, de l'autre côté de l'eau.
	for p in [Vector3(-52.0, 0, -1.5), Vector3(-56.5, 0, -3.0), Vector3(-53.5, 0, -6.0)]:
		_tree(p, "tree_cone_fall", 1.8)


## La placette du bout de la rue, côté sud : un tilleul, un banc, deux voitures garées, la pompe.
func _placette(f: FACADES) -> void:
	var x_start := -49.9
	var cx := (x_start + CLAIN_X1) / 2.0
	var len := absf(CLAIN_X1 - x_start)
	main._box(Vector3(len, 0.06, 4.5), Vector3(cx, 0.0, 10.9), mats.gravel, self)
	_tree(Vector3(cx + 2.5, 0, 11.6), "tree_oak_fall", 2.0)
	_place(KK + "city/bench.gltf", Vector3(cx + 2.5, 0, 10.0), 2.4, 180.0)
	for i in 2:
		var car := _car(["sedan", "van"][i], Vector3(cx - 2.6 + i * 2.2, 0, 11.4), 0.0, 1.5)
		main._solid(car)
	var xf := Transform3D(Basis(), Vector3(cx + 0.2, 0, 9.4))
	f.batch.box("trim", xf, Vector3(0, 0.35, 0), Vector3(0.24, 0.7, 0.24), Color(0.25, 0.35, 0.3))
	f.batch.box("trim", xf, Vector3(0, 0.6, 0.18), Vector3(0.06, 0.06, 0.3), Color(0.25, 0.35, 0.3))
	f.batch.box("trim", xf, Vector3(0, 0.08, 0.22), Vector3(0.5, 0.12, 0.36), Color(0.85, 0.8, 0.7))
	# Le muret du fond de la placette, vers les jardins.
	f.garden_wall(Vector3(x_start, 0, BOARD_Z1 - 0.3), Vector3(CLAIN_X1 + 0.2, 0, BOARD_Z1 - 0.3), 0.6)


## Le mobilier de la rue : réverbères, guirlandes, cabine, boîte aux lettres, étals.
func _street_props(f: FACADES) -> void:
	# Réverbères en quinconce, et leur lumière orange.
	var k := 0
	var x := CLAIN_X0 - 4.0
	while x > CLAIN_X1 + 2.0:
		var north := k % 2 == 0
		var z := NORTH_FRONT + 0.6 if north else SOUTH_FRONT - 0.6
		_place(KK + "city/streetlight.gltf", Vector3(x, 0.06, z), 2.2, 180.0 if north else 0.0)
		_lamp(Vector3(x + (0.45 if north else -0.45), 2.0, z), 2.6, Color(1.0, 0.72, 0.4), 6.5)
		x -= 6.5
		k += 1
	# Deux guirlandes d'ampoules en travers de la rue.
	for gx in [-18.0, -38.5]:
		main._garland(Vector3(gx, 2.6, NORTH_FRONT + 0.1), Vector3(gx - 1.5, 2.6, SOUTH_FRONT - 0.1), 0.5)
	# La cabine téléphonique et la boîte aux lettres jaune, devant la poste.
	var poste: Dictionary = lots.get("poste", {})
	if not poste.is_empty():
		_cabine(f, poste.pos + Vector3(-poste.w / 2.0 - 0.1, 0.06, 0.55))
		var bx := Transform3D(Basis(), poste.pos + Vector3(poste.w / 2.0 - 0.3, 0.06, 0.55))
		f.batch.box("trim", bx, Vector3(0, 0.3, 0), Vector3(0.06, 0.6, 0.06), Color(0.2, 0.2, 0.22))
		f.batch.box("trim", bx, Vector3(0, 0.72, 0), Vector3(0.3, 0.32, 0.22), Color(0.98, 0.8, 0.1))
		f.batch.box("trim", bx, Vector3(0, 0.84, 0.115), Vector3(0.2, 0.03, 0.01), Color(0.15, 0.2, 0.45))
	# Les cageots de l'épicerie et les seaux de la fleuriste, sur le trottoir.
	var epi: Dictionary = lots.get("epicerie", {})
	if not epi.is_empty():
		for i in 4:
			var p: Vector3 = epi.pos + Vector3(-1.2 + i * 0.55, 0.06, -0.45)
			var cx := Transform3D(Basis(Vector3.UP, 0.1 * (i - 2)), p)
			f.batch.box("trim", cx, Vector3(0, 0.12, 0), Vector3(0.45, 0.24, 0.32), Color(0.7, 0.55, 0.35))
			var fruit: Color = [Color(0.95, 0.55, 0.1), Color(0.85, 0.15, 0.12), Color(0.55, 0.75, 0.2), Color(0.95, 0.85, 0.25)][i]
			for j in 6:
				f.batch.box("trim", cx, Vector3(-0.15 + (j % 3) * 0.15, 0.27, -0.07 + (j / 3) * 0.14), Vector3(0.1, 0.08, 0.1), fruit)
		_place(KK + "city/box_A.gltf", epi.pos + Vector3(1.4, 0.06, -0.5), 1.6, 15.0)
	var fl: Dictionary = lots.get("fleurs", {})
	if not fl.is_empty():
		var names := ["flower_redA", "flower_yellowB", "flower_purpleB", "flower_redB", "flower_yellowA"]
		for i in 5:
			var p: Vector3 = fl.pos + Vector3(-1.1 + i * 0.5, 0.06, -0.4)
			_place(KN + "pot_small.glb", p, 1.2)
			_place(KN + names[i] + ".glb", p + Vector3(0, 0.18, 0), 1.0)
	# Des bacs fleuris et des bancs le long du trottoir nord.
	for bx in [-21.5, -31.0, -44.0]:
		_place(KN + "pot_large.glb", Vector3(bx, 0.06, NORTH_FRONT + 0.6), 1.3)
		_place(KN + "plant_bushSmall.glb", Vector3(bx, 0.38, NORTH_FRONT + 0.6), 1.4)
	_place(KK + "city/bench.gltf", Vector3(-27.5, 0.06, SOUTH_FRONT - 0.55), 2.2, 180.0)
	_place(KK + "city/trash_A.gltf", Vector3(-26.4, 0.06, SOUTH_FRONT - 0.5), 1.8)


## La cabine téléphonique des années 80 : vitrée, cadre gris-bleu, bandeau TÉLÉPHONE.
func _cabine(f: FACADES, at: Vector3) -> void:
	var xf := Transform3D(Basis(), at)
	var frame := Color(0.55, 0.62, 0.68)
	for px in [-0.32, 0.32]:
		for pz in [-0.32, 0.32]:
			f.batch.box("trim", xf, Vector3(px, 0.65, pz), Vector3(0.06, 1.3, 0.06), frame)
	f.batch.box("trim", xf, Vector3(0, 1.36, 0), Vector3(0.76, 0.14, 0.76), frame.darkened(0.2))
	f.batch.box("trim", xf, Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.7), frame.darkened(0.3))
	f.batch.box("trim", xf, Vector3(0, 0.75, -0.25), Vector3(0.22, 0.3, 0.1), Color(0.2, 0.22, 0.25))
	f._glass(xf, Vector3(0, 0.75, 0.33), Vector2(0.58, 1.0), 2, true, Color(0.75, 0.85, 1.0))
	f._glass(Transform3D(Basis(Vector3.UP, PI / 2.0), at), Vector3(0, 0.75, 0.33), Vector2(0.58, 1.0), 2, true, Color(0.75, 0.85, 1.0))
	var l := Label3D.new()
	l.text = "TÉLÉPHONE"
	l.double_sided = false
	l.font = main.serif
	l.font_size = 40
	l.pixel_size = 0.003
	l.modulate = Color(1.0, 1.0, 1.0)
	l.shaded = false
	l.position = at + Vector3(0, 1.36, 0.39)
	l.visibility_range_end = 30.0
	add_child(l)
	_lamp(at + Vector3(0, 1.1, 0), 0.6, Color(0.75, 0.85, 1.0), 2.0)
	main._solid_box(Vector3(0.7, 1.4, 0.7), at + Vector3(0, 0.7, 0))


# --- Petites choses ----------------------------------------------------------------------------

func _place(path: String, pos: Vector3, scale := 1.0, rot_y := 0.0) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scale
	n.rotation_degrees.y = rot_y
	add_child(n)
	return n


func _tree(pos: Vector3, model: String, scale: float) -> void:
	var t := _place(KN + model + ".glb", pos, scale, randf() * 360.0)
	main._solid(t, 0.25)


func _lamp(pos: Vector3, energy := 1.6, color := Color(1.0, 0.75, 0.45), range_m := 4.5) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.light_volumetric_fog_energy = 1.2
	l.position = pos
	add_child(l)


## Une voiture du Car Kit de Kenney, ramenée à la taille des voitures de la place.
func _car(model: String, pos: Vector3, rot: float, length := 1.5) -> Node3D:
	var car := _place(KC + model + ".glb", pos, 1.0, rot)
	var box: AABB = main._aabb_of(car)
	var l := maxf(box.size.x, box.size.z)
	if l > 0.0:
		car.scale = Vector3.ONE * length / l
	return car


## Une zone devant la porte : l'invite dit ce qu'est le lieu (et, pour un lot, ce qui viendra).
func _door_area(id: String, at: Vector3, rot: float) -> void:
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.2, 1.4, 0.8)
	cs.shape = b
	cs.position = Vector3(0, 0.7, 0.3)
	a.add_child(cs)
	a.position = at
	a.rotation.y = rot
	a.set_meta("interact", "lot")
	a.set_meta("lot", id)
	a.set_meta("prompt", PROMPTS.get(id, ""))
	if id in SELLER_DOORS:
		a.set_meta("action", enter_seller.bind(id))
	add_child(a)
	lots[id]["area"] = a


## Les portes qui mènent chez un vendeur du fil « Gestion » (autoload Biens, Biens.SELLERS).
const SELLER_DOORS := ["notaire", "couture", "garage"]


func enter_seller(id: String) -> void:
	var biens := get_node_or_null("/root/Biens")
	if biens == null or not biens.SELLERS.has(id):
		return
	var scene: String = biens.SELLERS[id].scene
	if not ResourceLoader.exists(scene):
		main._announce("%s ouvre bientôt ses portes." % biens.SELLERS[id].name)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(scene)


func has_door(id: String) -> bool:
	return id != "" and lots.has(id)


## Où réapparaître en sortant d'un lieu : sur le trottoir devant sa porte, face à la rue.
func door_spawn(id: String) -> Array:
	var lot: Dictionary = lots[id]
	var out := Basis(Vector3.UP, lot.rot) * Vector3(0, 0, 1)
	return [lot.door + out * 0.8 + Vector3(0, 0.08, 0), lot.rot + PI]


## Un panneau de bois vers les environs, comme ceux de la place.
func _signpost(pos: Vector3, rot: float, text: String, where: String) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot
	add_child(root)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.28, 0.14)
	main._box(Vector3(0.1, 1.6, 0.1), Vector3(0, 0.8, 0), wood, root)
	main._box(Vector3(2.0, 0.36, 0.06), Vector3(0, 1.4, 0), wood, root)
	var l := Label3D.new()
	l.text = text
	l.font = main.serif
	l.font_size = 40
	l.pixel_size = 0.0036
	l.modulate = Color(1.0, 0.92, 0.75)
	l.outline_size = 0
	l.double_sided = true
	l.position = Vector3(0, 1.4, 0.04)
	root.add_child(l)
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(2.2, 1.8, 0.8)
	cs.shape = b
	cs.position.y = 0.9
	a.add_child(cs)
	a.set_meta("travel", where)
	a.set_meta("interact", "travel")
	a.set_meta("prompt", "E : prendre le chemin — %s" % text.replace("↑", "").strip_edges())
	root.add_child(a)


# --- La tournée générale, en terrasse du Café de la Place ----------------------------------------

var _tournee_area: Area3D


func _tournee() -> void:
	if get_node_or_null("/root/Biens") == null:
		return
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.8, 1.0, 1.2)
	cs.shape = b
	cs.position.y = 0.5
	a.add_child(cs)
	a.position = Vector3(-5.0, 0, -0.4)
	a.set_meta("interact", "tournee")
	a.set_meta("action", _offer_tournee)
	add_child(a)
	_tournee_area = a


func _offer_tournee() -> void:
	var biens := get_node("/root/Biens")
	if not biens.offer_tournee():
		main._announce("La tournée générale coûte %s crédits. Josiane vous la gardera pour plus tard." % main._fmt(biens.tournee_price()))
		return
	Sfx.play("win")
	main._announce("Tournée générale ! Josiane remplit les verres : « Un placement, ça se soutient. »")
	for v in main.villagers:
		if v.global_position.distance_to(_tournee_area.global_position) < 6.0:
			v.react("win")


## Pour les captures de vérification : -- --vue=distance,x,y,z,lacet,tangage (vue maquette, sans suivre l'habitant).
func _capture_view() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--vue="):
			continue
		var v := arg.trim_prefix("--vue=").split_floats(",")
		main._bark_timer = INF
		await get_tree().create_timer(0.3).timeout
		main.set_fps(false)
		var cam: Camera3D = main.camera
		cam._target_goal = Vector3(v[1], v[2], v[3])
		cam.target = cam._target_goal
		cam._dist_goal = v[0]
		cam.distance = v[0]
		cam._yaw_goal = deg_to_rad(v[4])
		cam.yaw = cam._yaw_goal
		cam._pitch_goal = deg_to_rad(v[5])
		cam.pitch = cam._pitch_goal


# --- La coupe de maquette ----------------------------------------------------------------------

## En vue de dessus, les toits du premier plan se percent pour laisser voir l'habitant qu'on dirige.
func _update_cutaway() -> void:
	var on: bool = main.player != null and main.fps and main.topdown and main.camera != null
	for k in ["wall", "trim", "roof", "glass"]:
		var m: ShaderMaterial = mats[k]
		m.set_shader_parameter("cut_on", 1.0 if on else 0.0)
		if on:
			m.set_shader_parameter("cut_from", main.camera.global_position)
			m.set_shader_parameter("cut_to", main.player.global_position + Vector3(0, 0.4, 0))


# --- La vie de la rue --------------------------------------------------------------------------

func _life() -> void:
	# Les voitures qui traversent tout le bourg, phares allumés.
	var models := [["delivery", 1.7, 0.9], ["sedan", 1.5, 1.6], ["tractor", 1.1, 0.7]]
	for i in models.size():
		var m: Array = models[i]
		var east := i % 2 == 0
		var car := _car(m[0], Vector3(-20.0 - i * 18.0, 0.02, ROAD_Z + (0.55 if east else -0.55)), 90.0 if east else -90.0, m[1])
		car.set_meta("speed", m[2] * (1.0 if east else -1.0))
		for side in [-0.12, 0.12]:
			var beam := SpotLight3D.new()
			beam.light_color = Color(1.0, 0.92, 0.75)
			beam.light_energy = 2.5
			beam.spot_range = 5.0
			beam.spot_angle = 30.0
			beam.position = Vector3(side, 0.18, 0.5) / car.scale.x
			beam.rotation_degrees.x = -8.0
			beam.rotation_degrees.y = 180.0
			car.add_child(beam)
		_cars.append(car)
	# Les habitants de la rue : ceux qui passent, ceux qui attendent.
	main._villager("passante-clain", Vector3(-14.0, 0.06, NORTH_FRONT + 0.5), -90.0, "idle",
		[Vector3(-14.0, 0.06, NORTH_FRONT + 0.5), Vector3(-36.0, 0.06, NORTH_FRONT + 0.5)])
	main._villager("passant-clain", Vector3(-40.0, 0.06, SOUTH_FRONT - 0.5), 90.0, "idle",
		[Vector3(-46.0, 0.06, SOUTH_FRONT - 0.5), Vector3(-15.0, 0.06, SOUTH_FRONT - 0.5)])
	main._villager("promeneur-lavoir", Vector3(-53.0, 0.06, 5.5), -90.0, "idle",
		[Vector3(-56.0, 0.06, 7.9), Vector3(-44.0, 0.06, 7.9)])
	var poste: Dictionary = lots.get("poste", {})
	if not poste.is_empty():
		# Quelqu'un téléphone dans la cabine.
		main._villager("au-telephone", poste.pos + Vector3(-poste.w / 2.0 - 0.1, 0.06, 0.55), 180.0)
	var epi: Dictionary = lots.get("epicerie", {})
	if not epi.is_empty():
		main._villager("cliente-epicerie", epi.pos + Vector3(0.6, 0.06, -0.95), 0.0)
	main._villager("sur-le-banc", Vector3(-27.5, 0.06, SOUTH_FRONT - 0.75), 180.0, "sit")
	main._villager("laveuse", Vector3(-54.5, 0.06, 4.6), 180.0)


func _process(delta: float) -> void:
	_update_cutaway()
	if _tournee_area:
		_tournee_area.set_meta("prompt", "E : offrir une tournée générale (%s crédits)" % main._fmt(get_node("/root/Biens").tournee_price()))
	for car in _cars:
		var v: float = car.get_meta("speed")
		car.position.x += v * delta
		if car.position.x > ROAD_EAST:
			car.position.x = ROAD_WEST
		elif car.position.x < ROAD_WEST:
			car.position.x = ROAD_EAST
	# De temps en temps, quelqu'un allume ou éteint chez lui.
	_flicker -= delta
	if _flicker <= 0.0:
		_flicker = randf_range(1.5, 4.0)
		for mm in _glass:
			if mm == null:
				continue
			var i := randi() % mm.instance_count
			if mm.get_instance_custom_data(i).r < 0.5:
				var c := mm.get_instance_color(i)
				c.a = 1.0 - c.a
				mm.set_instance_color(i, c)
