extends Node3D
## Les rues du bourg, qui prolongent la place de la Mairie jusqu'aux environs, sur une seule maquette.
## Ce fichier est le propriétaire de l'agencement extérieur : les rues, les façades, les emplacements
## réservés aux lieux à venir (LOTS), les passages entre les socles et la vie de la rue.
##
## Repères : +X à l'est (bois de Saint-Pierre), -X à l'ouest (le Clain, le Moulin des Dames),
## -Z au nord (Passelourdin). La route traverse la place en z = 6,4.

const FACADES := preload("res://scripts/village/facades.gd")
const BOIS := preload("res://scripts/village/bois.gd")
const CHEMIN := preload("res://scripts/village/passelourdin.gd")
const PEPITES := preload("res://scripts/village/pepites.gd")
const KK := "res://assets/kaykit/"
const KN := "res://assets/kenney/nature/"
const KC := "res://assets/kenney/cars/"

## La vue extérieure qui suit l'habitant, en trois crans de molette (docs/SUITE.md, section 2) :
## [distance, tangage, champ]. Proche pour les détails, Rue pour parcourir (par défaut ; 18 u est le plus haut
## où l'on reconnaît encore quelqu'un à sa coiffure et à ses épaules), Quartier pour s'orienter.
const CAMERA_NOTCHES := [[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [40.0, -60.0, 30.0]]
const CAMERA_DEFAULT := 1

const ROAD_Z := 6.4
const ROAD_W := 2.4
## Les voitures roulent de part en part de la maquette, entre ces deux abscisses.
const ROAD_WEST := -80.0
const ROAD_EAST := 80.0
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
	Vector3(0, 0, 0): {"W": [[NORTH_FRONT, 8.1]], "E": [[NORTH_FRONT, 8.1]], "N": [[-3.0, -1.5]]},
	Vector3(0, 0, -70): {"S": [[-1.3, 1.3]]},
	Vector3(-70, 0, 0): {"E": [[5.0, 8.1]]},
	Vector3(70, 0, 0): {"W": [[NORTH_FRONT, 8.1]]},
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
	{"id": "pizzeria", "roof_sign": "PIZZERIA", "w": 3.4, "floors": 1, "shop": {"name": "Pizzeria du Clain", "sub": "Pizzas au feu de bois", "color": Color(0.14, 0.36, 0.2), "ink": Color(1.0, 0.95, 0.85), "awning": [Color(0.15, 0.5, 0.25), Color(0.97, 0.95, 0.9), Color(0.8, 0.15, 0.15), Color(0.97, 0.95, 0.9)], "glow": Color(1.0, 0.7, 0.4)}},
	{"w": 2.6, "floors": 1, "door": "right", "roof_kind": "pignon"},
	{"id": "epicerie", "roof_sign": "ÉPICERIE", "w": 3.8, "floors": 1, "shop": {"name": "L'Épicerie du Bourg", "sub": "Alimentation · Primeurs · Gaz", "color": Color(0.18, 0.32, 0.58), "ink": Color(1.0, 0.9, 0.6), "awning": [Color(0.95, 0.55, 0.15), Color(0.97, 0.94, 0.88)]}},
	{"id": "fleurs", "roof_sign": "FLEURS", "w": 3.0, "floors": 1, "shop": {"name": "Fleurs Odette", "sub": "Mariages · Fêtes · Deuils", "color": Color(0.38, 0.55, 0.32), "ink": Color(1.0, 0.98, 0.9), "awning": [Color(0.55, 0.72, 0.42), Color(0.98, 0.96, 0.9)], "glow": Color(1.0, 0.9, 0.7)}},
	{"kind": "jardin", "w": 2.8},
	{"id": "brocante", "roof_sign": "BROCANTE", "w": 3.2, "floors": 1, "shop": {"name": "Brocante Boutin", "sub": "Meubles · Objets · Débarras", "color": Color(0.36, 0.26, 0.2), "ink": Color(0.98, 0.88, 0.62), "glow": Color(1.0, 0.8, 0.5)}},
	{"w": 2.8, "floors": 1},
	{"id": "bibliotheque", "roof_sign": "BIBLIOTHÈQUE", "w": 4.4, "floors": 2, "roof_kind": "hip", "shop": {"name": "Bibliothèque municipale", "sub": "Mardi · Samedi", "color": Color(0.9, 0.86, 0.76), "ink": Color(0.15, 0.2, 0.35), "door": "left"}},
	{"w": 3.0, "floors": 1},
	{"w": 2.6, "floors": 1, "door": "center", "roof_kind": "pignon"},
	{"w": 3.2, "floors": 1, "roof_kind": "hip"},
]

## La route du Bois, de la place vers l'est (bois.gd) : le garage, le rond-point du vieux chêne,
## l'école, le stade ; en face, la pharmacie et les pavillons. « vide » laisse la place au rond-point.
const BOIS_NORTH := [
	{"id": "garage", "kind": "garage", "w": 5.0},
	{"w": 2.8, "floors": 2, "door": "right", "roof_kind": "pignon"},
	{"kind": "vide", "w": 0.0, "to": BOIS.ROND_X + BOIS.RING_R + 0.4},
	{"id": "ecole", "kind": "ecole", "w": 9.0},
	{"id": "stade", "kind": "stade", "w": 20.4},
	{"kind": "jardin", "w": 2.2},
]
const BOIS_SOUTH := [
	{"w": 2.8, "floors": 1, "roof_kind": "hip"},
	{"id": "pharmacie", "roof_sign": "PHARMACIE", "w": 3.0, "floors": 1, "shop": {"name": "Pharmacie", "sub": "Herboristerie · Orthopédie", "color": Color(0.92, 0.94, 0.9), "ink": Color(0.1, 0.45, 0.25), "glow": Color(0.85, 1.0, 0.9), "door": "left"}},
	{"w": 2.2, "floors": 1, "door": "center", "roof_kind": "pignon"},
	{"kind": "vide", "w": 0.0, "to": BOIS.ROND_X + BOIS.RING_R + 0.4},
	{"id": "lot_bois", "w": 3.2, "floors": 1, "closed": true, "shop": {"name": "Prochainement", "sub": "Un nouveau commerce", "color": Color(0.2, 0.28, 0.36), "ink": Color(0.95, 0.85, 0.55)}},
	{"kind": "pavillon", "w": 4.0},
	{"kind": "pavillon", "w": 4.0},
	{"kind": "jardin", "w": 2.4},
	{"kind": "pavillon", "w": 4.0},
	{"kind": "pavillon", "w": 4.0},
	{"kind": "jardin", "w": 2.4},
	{"kind": "pavillon", "w": 4.0},
	{"kind": "jardin", "w": 2.0},
]

## Les quartiers de la maquette, pour le plan du Carnet : id → {nom, rect (x, z, largeur, profondeur)}.
## Le village dit où est l'habitant (zone_at, zone_entered) ; le Carnet garde ce qui est découvert.
const ZONES := {
	"place": {"nom": "La place de la Mairie", "rect": Rect2(-11.3, -8.3, 22.6, 16.6)},
	"rue_du_clain": {"nom": "La rue du Clain", "rect": Rect2(CLAIN_X1, BOARD_Z0, CLAIN_X0 - CLAIN_X1, BOARD_Z1 - BOARD_Z0)},
	"route_du_bois": {"nom": "La route du Bois", "rect": Rect2(BOIS.X0, BOARD_Z0, BOIS.X1 - BOIS.X0, BOARD_Z1 - BOARD_Z0)},
	"chemin_passelourdin": {"nom": "Le chemin de Passelourdin", "rect": Rect2(CHEMIN.X0, CHEMIN.Z_ROCHERS, CHEMIN.X1 - CHEMIN.X0, CHEMIN.Z_PLACE - CHEMIN.Z_ROCHERS)},
	"moulin": {"nom": "Le Moulin des Dames", "rect": Rect2(-81.3, -8.3, 22.4, 16.6)},
	"bois": {"nom": "Le bois de Saint-Pierre", "rect": Rect2(58.9, -8.3, 22.4, 16.6)},
	"rochers": {"nom": "Les rochers de Passelourdin", "rect": Rect2(-11.3, -78.3, 22.6, 16.6)},
}
## Les lieux cachés, qu'aucune liste n'annonce (docs/SUITE.md, section 1) : id → {nom, zone, pos}.
const CACHES := {
	"cabane_vigne": {"nom": "La cabane de vigne", "zone": "chemin_passelourdin", "pos": CHEMIN.CABANE},
}

## L'habitant entre dans un quartier (aussi au premier pas et après un raccourci).
signal zone_entered(id: String)
## L'habitant trouve un lieu caché, la première fois.
signal cache_found(id: String)

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
	"brocante": "E : entrer à la brocante de Mme Boutin",
	"bibliotheque": "Bibliothèque municipale — ouverte mardi et samedi",
	"garage": "E : entrer au garage Fradin",
	"pharmacie": "Pharmacie — la croix verte veille, la porte est close",
	"lot_bois": "Local réservé — un nouveau commerce s'installe bientôt",
	"ecole": "École publique — fermée le samedi soir",
	"stade": "E : entrer au stade municipal",
}

## Les emplacements posés, par identifiant : {pos (milieu du pied de façade), rot, w, d, door (monde)}.
var lots := {}
var main: Node3D
var mats := {}
var _glass: Array[MultiMesh] = []
var _flicker := 2.0
var _cars: Array[Node3D] = []
var _chemin: RefCounted
## Les enseignes de toit, que l'on fait pâlir quand l'habitant passe derrière (Facades.roof_sign).
var _roof_signs: Array[Node3D] = []
## Le quartier où se tient l'habitant (ZONES), "" hors maquette.
var current_zone := ""


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
	_route_du_bois()
	_chemin = CHEMIN.new()
	_chemin.build(self)
	# Sur les socles du moulin et du bois, la route garde son marquage et ses réverbères.
	_plinth_road(-80.8, -59.2, [-63.0, -71.0, -78.5])
	_plinth_road(59.2, 80.8, [63.0, 74.5])
	_tournee()
	_logements()
	_biens()
	_voisinage()
	_arret_de_car()
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

## Une rue sur son socle, de x0 (côté place) à x1 : la chaussée, ses pointillés, ses trottoirs
## de dalles calcaires et leurs bordures. gap : un intervalle [a, b] en x où trottoirs et marquage s'arrêtent.
func _street(x0: float, x1: float, title: String, gap := []) -> void:
	var lo := minf(x0, x1)
	var hi := maxf(x0, x1)
	_board(x0, x1, BOARD_Z0, BOARD_Z1, title, [
		[Vector3(lo, 0, BOARD_Z0 - 0.1), Vector3(hi, 0, BOARD_Z0 - 0.1)],
		[Vector3(lo, 0, BOARD_Z1 + 0.1), Vector3(hi, 0, BOARD_Z1 + 0.1)],
		[Vector3(lo - 0.1, 0, 8.1), Vector3(lo - 0.1, 0, BOARD_Z1)],
		[Vector3(hi + 0.1, 0, 8.1), Vector3(hi + 0.1, 0, BOARD_Z1)],
	])
	main._box(Vector3(hi - lo, 0.11, ROAD_W), Vector3((lo + hi) / 2.0, -0.04, ROAD_Z), mats.asphalt, self)
	var spans := [[lo, hi]]
	if gap.size() == 2:
		spans = [[lo, gap[0]], [gap[1], hi]]
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(0.85, 0.85, 0.8)
	var xs := []
	var x := lo + 1.0
	while x < hi - 0.5:
		if gap.size() != 2 or x < gap[0] - 0.5 or x > gap[1] + 0.5:
			xs.append(x)
		x += 2.0
	var dashes := MultiMesh.new()
	dashes.transform_format = MultiMesh.TRANSFORM_3D
	var dm := BoxMesh.new()
	dm.size = Vector3(0.9, 0.02, 0.08)
	dm.material = line
	dashes.mesh = dm
	dashes.instance_count = xs.size()
	for i in xs.size():
		dashes.set_instance_transform(i, Transform3D(Basis(), Vector3(xs[i], 0.02, ROAD_Z)))
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = dashes
	add_child(dmi)
	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.82, 0.8, 0.75)
	curb.roughness = 0.8
	for sp in spans:
		var len: float = sp[1] - sp[0]
		var cx: float = (sp[0] + sp[1]) / 2.0
		for z in [NORTH_FRONT + 0.45, SOUTH_FRONT - 0.45]:
			main._box(Vector3(len, 0.12, 0.9), Vector3(cx, 0.0, z), mats.slabs, self)
		for z in [ROAD_Z - ROAD_W / 2.0 - 0.04, ROAD_Z + ROAD_W / 2.0 + 0.04]:
			main._box(Vector3(len, 0.14, 0.08), Vector3(cx, 0.0, z), curb, self)


func _rue_du_clain() -> void:
	_street(CLAIN_X0, CLAIN_X1, "Rue du Clain")
	var f := FACADES.new(self, main.serif, 1962)
	_row(f, NORTH_ROW, true, CLAIN_X0 - 0.5, -1.0)
	_row(f, SOUTH_ROW, false, CLAIN_X0 - 0.5, -1.0)
	_lavoir(f)
	_placette(f)
	_street_props(f)
	_glass.append(f.commit(mats, mats.glass, "RueDuClain"))
	_roof_signs.append_array(f.roof_signs)
	for g in f.glows:
		var l := OmniLight3D.new()
		l.light_color = g[1]
		l.light_energy = 1.1
		l.omni_range = 2.6
		l.light_volumetric_fog_energy = 0.8
		l.position = g[0]
		add_child(l)
	_life()


## Une rangée de façades, de x_start en s'éloignant de la place (dir = -1 vers l'ouest, +1 vers l'est).
## north : côté nord, façades tournées vers le sud.
func _row(f: FACADES, row: Array, north: bool, x_start: float, dir: float) -> void:
	var x := x_start
	var front := NORTH_FRONT if north else SOUTH_FRONT
	var back := BOARD_Z0 + 0.3 if north else BOARD_Z1 - 0.3
	var rot := 0.0 if north else PI
	var out := 1.0 if north else -1.0
	for spec in row:
		var kind: String = spec.get("kind", "house")
		var w: float = spec.w
		if spec.has("to"):
			w = absf(spec.to - x)
		var cx := x + dir * w / 2.0
		var xf := Transform3D(Basis(Vector3.UP, rot), Vector3(cx, 0, front))
		var d := 3.2
		match kind:
			"house":
				var s: Dictionary = spec.duplicate(true)
				d = [3.0, 3.3, 3.6][f.rng.randi() % 3] if north else [2.6, 2.8][f.rng.randi() % 2]
				s.d = d
				if not s.has("lit"):
					s.lit = 0.72
				var info: Dictionary = f.house(xf, s)
				if spec.has("roof_sign"):
					# Côté sud, la boutique tourne le dos à la caméra : son nom passe sur le toit.
					f.roof_sign(xf, w, d, info.h, spec.roof_sign, spec.shop.color, spec.shop.ink, not north)
				main._solid_box(Vector3(w, info.h + 1.0, d), Vector3(cx, (info.h + 1.0) / 2.0, front - out * d / 2.0))
				var door: Vector3 = xf * info.door
				if spec.has("id"):
					lots[spec.id] = {"pos": Vector3(cx, 0, front), "rot": rot, "w": w, "d": d, "door": door}
					_door_area(spec.id, door, rot)
				else:
					_maisons.append({"cx": cx, "nord": north, "pos": Vector3(cx, 0, front), "rot": rot, "w": w, "d": d, "door": door})
				if spec.get("id", "") == "lot_reserve":
					lots.lot_reserve["xf"] = xf
					# La charge de Mme Vasseur (lieu « bourse ») a la porte du local : door_spawn("bourse") la trouve.
					lots["bourse"] = lots.lot_reserve
					_charge()
			"porche":
				# Un portail sur une cour pavée, et l'arbre de la cour qui dépasse du mur.
				f.gate(Vector3(cx, 0, front - out * 0.1), rot, w - 0.7, f.pick(f.SHUTTERS))
				main._box(Vector3(w, 0.06, 3.0), Vector3(cx, 0.0, front - out * 1.6), mats.gravel, self)
				main._solid_box(Vector3(w, 2.0, 0.3), Vector3(cx, 1.0, front - out * 0.1))
				_tree(Vector3(cx, 0, front - out * 2.4), "tree_oak_fall", 1.6)
			"jardin":
				f.garden_wall(Vector3(x, 0, front - out * 0.1), Vector3(x + dir * w, 0, front - out * 0.1), 0.8)
				main._solid_box(Vector3(w, 2.0, 0.3), Vector3(cx, 1.0, front - out * 0.1))
				_tree(Vector3(cx, 0, front - out * 1.6), ["tree_fat_fall", "tree_default_fall", "tree_oak_fall"][f.rng.randi() % 3], 1.5)
				for i in 3:
					_place(KN + "flower_%s.glb" % ["redA", "yellowA", "purpleA"][i], Vector3(cx - 0.8 + i * 0.8, 0, front - out * 0.5), 1.2)
			"ruelle":
				_ruelle(f, cx, w, front, out)
			_:
				d = _special(f, kind, spec, cx, w, front, back, out, rot)
				if kind == "pavillon":
					# La porte du pavillon est le portillon de l'allée, à côté du garage.
					var gate := Transform3D(Basis(Vector3.UP, rot), Vector3(cx, 0, front)) * Vector3(w / 2.0 - 0.7, 0, -0.3)
					_maisons.append({"cx": cx, "nord": north, "pos": Vector3(cx, 0, front), "rot": rot, "w": w, "d": d, "door": gate})
		# Le fond de la parcelle : jardin derrière la maison, mur mitoyen, potager, arbre fruitier.
		if kind != "ruelle" and kind != "vide":
			var z_b := front - out * (d + 0.05)
			if kind == "house" and not spec.get("no_yard", false):
				_backyard(f, cx, w, z_b, back, out)
			f.garden_wall(Vector3(x, 0, z_b if kind == "house" else front - out * 0.2), Vector3(x, 0, back), 0.4)
		x += dir * w
	# Le mur du fond de la maquette, derrière les jardins.
	f.garden_wall(Vector3(x_start, 0, back), Vector3(x, 0, back), 0.45)


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
		if i == 1:
			# Passé un seuil, la camionnette devient le van des chasseurs de pépites (pepites.gd).
			var pepites: Node3D = PEPITES.new()
			add_child(pepites)
			pepites.setup(car, main.serif)
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


# --- La route du Bois ---------------------------------------------------------------------------

func _route_du_bois() -> void:
	var gap := [BOIS.ROND_X - BOIS.RING_R - 0.2, BOIS.ROND_X + BOIS.RING_R + 0.2]
	_street(BOIS.X0, BOIS.X1, "Route du Bois", gap)
	var f := FACADES.new(self, main.serif, 1975)
	BOIS.rond_point(self, f)
	_row(f, BOIS_NORTH, true, BOIS.X0 + 0.5, 1.0)
	_row(f, BOIS_SOUTH, false, BOIS.X0 + 0.5, 1.0)
	# La croix verte de la pharmacie, en drapeau sur la façade, allumée des deux côtés.
	var ph: Dictionary = lots.get("pharmacie", {})
	if not ph.is_empty():
		var out := Basis(Vector3.UP, ph.rot) * Vector3(0, 0, 1)
		var side := Basis(Vector3.UP, ph.rot) * Vector3(1, 0, 0)
		var at: Vector3 = ph.pos + side * (ph.w / 2.0 - 0.3) + out * 0.42 + Vector3(0, 1.75, 0)
		for s in [1.0, -1.0]:
			var xf := Transform3D(Basis(Vector3.UP, ph.rot + s * PI / 2.0), at)
			f._glass(xf, Vector3(0, 0, 0.03), Vector2(0.12, 0.42), 2, true, Color(0.25, 1.0, 0.45))
			f._glass(xf, Vector3(0, 0, 0.031), Vector2(0.42, 0.12), 2, true, Color(0.25, 1.0, 0.45))
		f.batch.box("trim", Transform3D(Basis(Vector3.UP, ph.rot), at), Vector3.ZERO, Vector3(0.05, 0.46, 0.46), Color(0.2, 0.25, 0.22))
		f.batch.box("trim", Transform3D(Basis(Vector3.UP, ph.rot), at), Vector3(0, 0, -0.3), Vector3(0.04, 0.04, 0.2), Color(0.2, 0.2, 0.2))
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 1.0, 0.5)
		l.light_energy = 1.2
		l.omni_range = 3.0
		l.position = at
		add_child(l)
	# Réverbères en quinconce, sauf autour du rond-point qui a les siens.
	var k := 0
	var x := BOIS.X0 + 6.5
	while x < BOIS.X1 - 2.0:
		if x < gap[0] - 0.5 or x > gap[1] + 0.5:
			var north := k % 2 == 0
			var z := NORTH_FRONT + 0.6 if north else SOUTH_FRONT - 0.6
			_place(KK + "city/streetlight.gltf", Vector3(x, 0.06, z), 2.2, 180.0 if north else 0.0)
			_lamp(Vector3(x + (0.45 if north else -0.45), 2.0, z), 2.6, Color(1.0, 0.72, 0.4), 6.5)
			k += 1
		x += 6.5
	for c in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		var p: Vector3 = Vector3(BOIS.ROND_X, 0, ROAD_Z) + c * Vector3(BOIS.RING_R + 0.4, 0, BOIS.RING_R - 0.2)
		_place(KK + "city/streetlight.gltf", p + Vector3(0, 0.02, 0), 2.2, 0.0 if c.z > 0 else 180.0)
		_lamp(p + Vector3(0, 2.0, 0), 2.2, Color(1.0, 0.72, 0.4), 6.0)
	_place(KK + "city/bench.gltf", Vector3(BOIS.X0 + 4.6, 0.06, SOUTH_FRONT - 0.55), 2.2, 180.0)
	_place(KK + "city/trash_A.gltf", Vector3(BOIS.X0 + 5.7, 0.06, SOUTH_FRONT - 0.5), 1.8)
	_glass.append(f.commit(mats, mats.glass, "RouteDuBois"))
	_roof_signs.append_array(f.roof_signs)
	for g in f.glows:
		var l := OmniLight3D.new()
		l.light_color = g[1]
		l.light_energy = 1.1
		l.omni_range = 2.6
		l.position = g[0]
		add_child(l)
	# Ceux qui passent, et le mécano qui fume devant l'atelier.
	main._villager("passant-bois", Vector3(BOIS.X0 + 2.0, 0.06, NORTH_FRONT + 0.5), 90.0, "idle",
		[Vector3(BOIS.X0 + 2.0, 0.06, NORTH_FRONT + 0.5), Vector3(BOIS.X0 + 7.5, 0.06, NORTH_FRONT + 0.5)])
	main._villager("promeneuse-bois", Vector3(40.0, 0.06, SOUTH_FRONT - 0.5), -90.0, "idle",
		[Vector3(54.0, 0.06, SOUTH_FRONT - 0.5), Vector3(30.0, 0.06, SOUTH_FRONT - 0.5)])
	var ga: Dictionary = lots.get("garage", {})
	if not ga.is_empty():
		main._villager("mecano", ga.door + Vector3(1.6, 0.06, 1.0), 200.0)


## La route sur un socle des environs : pointillés, bordures, et des réverbères côté sud.
func _plinth_road(x0: float, x1: float, lamps: Array) -> void:
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(0.85, 0.85, 0.8)
	var x := x0 + 1.0
	while x < x1 - 0.5:
		main._box(Vector3(0.9, 0.02, 0.08), Vector3(x, 0.025, ROAD_Z), line, self)
		x += 2.0
	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.82, 0.8, 0.75)
	for z in [ROAD_Z - ROAD_W / 2.0 - 0.04, ROAD_Z + ROAD_W / 2.0 + 0.04]:
		main._box(Vector3(x1 - x0, 0.14, 0.08), Vector3((x0 + x1) / 2.0, 0.0, z), curb, self)
	for lx in lamps:
		_place(KK + "city/streetlight.gltf", Vector3(lx, 0.0, ROAD_Z + ROAD_W / 2.0 + 0.4), 2.2, 0.0)
		_lamp(Vector3(lx - 0.45, 2.0, ROAD_Z + ROAD_W / 2.0 + 0.4), 2.6, Color(1.0, 0.72, 0.4), 6.5)


## Les lieux qui ne sont pas une maison de bourg : rend la profondeur bâtie depuis la rue.
func _special(f: FACADES, kind: String, spec: Dictionary, cx: float, w: float, front: float, back: float, out: float, rot: float) -> float:
	match kind:
		"garage":
			return BOIS.garage(self, f, spec, cx, w, front, out, rot)
		"ecole":
			return BOIS.ecole(self, f, spec, cx, w, front, out, rot)
		"stade":
			return BOIS.stade(self, f, spec, cx, w, front, out, rot)
		"pavillon":
			return BOIS.pavillon(self, f, spec, cx, w, front, back, out, rot)
	return 0.0


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
	elif LOGEMENTS.has(id) or portes_adresses.has(id):
		a.set_meta("action", enter_logement.bind(id))
	elif id == "stade":
		# Le stade est un lieu du manifeste, derrière son seuil : la scène principale en tient la porte.
		a.set_meta("action", func(): main._enter("stade"))
	add_child(a)
	lots[id]["area"] = a


## La charge de Mme Vasseur s'installe dans le local réservé de la rue du Clain à son seuil (lieu
## « bourse » du manifeste) ; avant, rien ne change.
func charge_ouverte() -> bool:
	return main.is_open("bourse")


## La devanture repeinte par-dessus celle du local fermé : on ne refait pas la façade, pour que le
## tirage des fenêtres du reste de la rue reste le même. Un bandeau vert bouteille et or, la vitrine
## éclairée où se lit la cote, et la porte qui mène chez Mme Vasseur. Posée à la construction si le
## seuil est passé, ou dès qu'il l'est (Game.changed), une seule fois.
func _charge() -> void:
	if lots.lot_reserve.has("charge"):
		return
	if not charge_ouverte():
		if not Game.changed.is_connected(_charge):
			Game.changed.connect(_charge)
		return
	if Game.changed.is_connected(_charge):
		Game.changed.disconnect(_charge)
	var lot: Dictionary = lots.lot_reserve
	var xf: Transform3D = lot.xf
	var w: float = lot.w
	var root := Node3D.new()
	root.name = "Charge"
	add_child(root)
	lot["charge"] = root
	var gh := 1.45
	var vert := Color(0.1, 0.26, 0.2)
	var dw := 0.55
	var vw := w - 0.5 - dw - 0.15
	var vx := -w / 2.0 + 0.25 + vw / 2.0
	var plein := func(taille: Vector3, ou: Vector3, c: Color, lueur := 0.0) -> void:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = taille
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.6
		if lueur > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = lueur
		mi.material_override = m
		mi.transform = xf * Transform3D(Basis(), ou)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	plein.call(Vector3(w - 0.16, 0.34, 0.03), Vector3(0, gh - 0.17, 0.14), vert)
	plein.call(Vector3(w - 0.12, 0.04, 0.05), Vector3(0, gh + 0.01, 0.14), Color(0.85, 0.68, 0.3))
	plein.call(Vector3(vw, 0.78, 0.01), Vector3(vx, 0.77, 0.09), Color(1.0, 0.74, 0.42), 1.2)
	plein.call(Vector3(dw, 1.0, 0.01), Vector3(w / 2.0 - 0.25 - dw / 2.0, 0.67, 0.09), Color(1.0, 0.74, 0.42), 1.0)
	var enseigne := [["VASSEUR & CIE", 56, 0.004, Vector3(0, gh - 0.12, 0.16), Color(0.96, 0.8, 0.45)],
		["Agent de change  ·  Bourse  ·  Titres", 30, 0.0032, Vector3(0, gh - 0.27, 0.16), Color(0.9, 0.82, 0.62)],
		["COTE DU JOUR\nCAC 40  ·  S&P 500\nNIKKEI  ·  OR", 30, 0.0035, Vector3(vx, 0.8, 0.1), Color(0.2, 0.12, 0.05)]]
	for e in enseigne:
		var l := Label3D.new()
		l.text = e[0]
		l.font = main.serif
		l.font_size = e[1]
		l.pixel_size = e[2]
		l.modulate = e[4]
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false
		l.transform = xf * Transform3D(Basis(), e[3])
		l.visibility_range_end = 40.0
		root.add_child(l)
	var lum := OmniLight3D.new()
	lum.light_color = Color(1.0, 0.75, 0.45)
	lum.light_energy = 0.8
	lum.omni_range = 2.5
	lum.position = xf * Vector3(vx, 0.8, 0.6)
	root.add_child(lum)
	# Le local réservé a trouvé son commerce : sa porte mène chez Mme Vasseur (docs/BOURSE.md).
	if lot.has("area"):
		lot.area.set_meta("prompt", "E : entrer chez Mme Vasseur, agent de change")
		lot.area.set_meta("action", func(): main._enter("bourse"))


## Les portes qui mènent chez un vendeur du fil « Gestion » (autoload Biens, Biens.SELLERS).
const SELLER_DOORS := ["notaire", "couture", "garage", "brocante"]


func enter_seller(id: String) -> void:
	var biens := get_node_or_null("/root/Biens")
	if biens == null:
		return
	if not biens.SELLERS.has(id):
		main._announce("La porte est close : on prépare encore l'intérieur.")
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


# --- Les logements du joueur (fil « Gestion », Biens.door_of) -----------------------------------

## Les portes des logements qu'on peut posséder : lot → [porte (monde), orientation]. La chambre est
## au-dessus du café, par l'escalier de la ruelle ; la maison de maître est la maison verte de la place.
## La maison de la rue de l'Église est sur le chemin de Passelourdin (passelourdin.gd).
const LOGEMENTS := {
	"chambre_cafe": [Vector3(-7.6, 0, -2.47), PI],
	"maison_place": [Vector3(-8.6, 0, -3.82), 0.0],
	"maison_eglise": [Vector3(-3.4, 0, -13.5), PI / 2.0],
}

## Les salles de jeu du village (scripts/village/salle.gd) : la porte où l'on ressort, sur le trottoir.
## Le Café de la Place et la salle Rabelais donnent sur la place, l'arrière-salle du Moulin sur la berge.
const SALLES := {
	"cafe": [Vector3(-6.8, 0, -0.6), PI / 2.0],
	"rabelais": [Vector3(-7.5, 0, 3.5), PI / 2.0],
	"moulin": [Vector3(-69.4, 0, 0.5), PI / 2.0],
}


## Les maisons des rues sans enseigne, telles que _row les a bâties : {cx, nord, pos, rot, w, d, door}.
## _portes_adresses leur donne leur adresse (scripts/adresses.gd) et une porte.
var _maisons: Array = []
## Les portes des maisons à adresse : id du bien au registre du notaire (adr_clain_13…) → true.
var portes_adresses := {}


## Chaque maison de la rue du Clain et de la route du Bois a sa porte : à vendre chez le notaire, à vous,
## on rentre chez soi. Le lot porte l'id du bien, comme celui des logements de la place.
func _portes_adresses() -> void:
	var adresses: Variant = load("res://scripts/adresses.gd")
	if adresses == null:
		return
	for a in adresses.rues():
		if a.genre != "maison":
			continue
		for m in _maisons:
			if m.nord == a.nord and m.cx > a.x0 and m.cx < a.x1:
				var id := str(a.item)
				lots[id] = {"pos": m.pos, "rot": m.rot, "w": m.w, "d": m.d, "door": m.door}
				portes_adresses[id] = true
				_door_area(id, m.door, m.rot)
				break


func _logements() -> void:
	_portes_adresses()
	for id in SALLES:
		lots[id] = {"pos": SALLES[id][0], "rot": SALLES[id][1], "w": 1.0, "d": 1.0, "door": SALLES[id][0]}
	for id in LOGEMENTS:
		var at: Vector3 = LOGEMENTS[id][0]
		var rot: float = LOGEMENTS[id][1]
		lots[id] = {"pos": at, "rot": rot, "w": 1.0, "d": 1.0, "door": at}
		_door_area(id, at, rot)
	# La porte de la chambre, sur le flanc du café, avec son petit escalier de pierre et sa lanterne.
	var f := FACADES.new(self, main.serif, 1984)
	var xf := Transform3D(Basis(Vector3.UP, PI), Vector3(-7.6, 0, -2.47))
	f._door(xf, 0.0, Color(0.3, 0.42, 0.36), Color(0.92, 0.88, 0.8), true)
	for i in 2:
		f.batch.box("trim", xf, Vector3(0, 0.05 + i * 0.1, 0.3 - i * 0.12), Vector3(0.8, 0.1, 0.24), Color(0.8, 0.76, 0.68))
	f.commit(mats, mats.glass, "Logements")
	_lamp(Vector3(-7.6, 1.35, -2.75), 0.7, Color(1.0, 0.78, 0.5), 2.2)


## Ce que dit la porte d'un logement, selon qu'on l'a, qu'il est à vendre, ou non.
func _logement_prompt(id: String) -> String:
	var biens := get_node_or_null("/root/Biens")
	var what: String = {"chambre_cafe": "La chambre au-dessus du café", "maison_place": "La maison de maître", "maison_eglise": "La maison de la rue de l'Église"}.get(id, "Une maison")
	if portes_adresses.has(id) and biens != null:
		what = str(biens.item(id).get("name", what))
	if biens == null or not biens.has_method("door_of"):
		return "%s — propriété privée" % what
	var d: Dictionary = biens.door_of(id)
	if d.get("owned", false):
		return "E : rentrer chez vous — %s" % what.to_lower() if d.get("scene", "") != "" else "%s — chez vous ; l'intérieur se prépare" % what
	if not Voisinage.voisins(id).is_empty():
		return "E : frapper chez %s — %s" % [_noms(Voisinage.voisins(id)), what.to_lower()]
	if d.get("en_vente", false):
		return "%s — en vente chez Maître Garnier" % what
	return "%s — propriété privée" % what


func enter_logement(id: String) -> void:
	var biens := get_node_or_null("/root/Biens")
	if biens == null or not biens.has_method("door_of"):
		main._announce(_logement_prompt(id))
		return
	var d: Dictionary = biens.door_of(id)
	if d.get("owned", false) and d.get("scene", "") != "" and biens.has_method("enter"):
		# Une seule scène pour tous les logements : Biens.enter lui dit lequel construire,
		# et la sortie remet Game.return_point à l'id du lot, devant cette porte.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		biens.enter(d.logement)
		return
	if not d.get("owned", false) and not Voisinage.voisins(id).is_empty():
		Tableau.ouvrir_maison(id)
		return
	main._announce(_logement_prompt(id))


# --- Les biens du joueur, dehors (fil « Gestion », autoload Biens) --------------------------------

## Où l'on gare le véhicule qu'on conduit : sur la place, entre la pétanque et le banc.
const PARKING := [Vector3(-0.6, 0.02, 3.4), 90.0]
## Les panneaux « Propriété » : bien → [position, rotation]. La maison de la rue de l'Église est sur
## le chemin de Passelourdin ; la maison de maître est la maison verte de la place.
const PROPERTY_SIGNS := {
	"maison_place": [Vector3(-7.4, 0, -3.5), 20.0],
	"maison": [Vector3(-3.05, 0, -12.1), 20.0],
}

var _vehicle: Node3D
var _vehicle_id := ""
var _property_signs := {}


func _biens() -> void:
	var biens := get_node_or_null("/root/Biens")
	if biens == null:
		return
	for id in PROPERTY_SIGNS:
		var sp: Array = PROPERTY_SIGNS[id]
		var root := Node3D.new()
		root.position = sp[0]
		root.rotation_degrees.y = sp[1]
		add_child(root)
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.45, 0.28, 0.14)
		main._box(Vector3(0.06, 0.9, 0.06), Vector3(0, 0.45, 0), wood, root)
		var board := StandardMaterial3D.new()
		board.albedo_color = Color(0.95, 0.9, 0.78)
		main._box(Vector3(0.9, 0.36, 0.04), Vector3(0, 0.82, 0), board, root)
		var l := Label3D.new()
		l.text = "PROPRIÉTÉ"
		l.font = main.serif
		l.font_size = 40
		l.pixel_size = 0.0035
		l.modulate = Color(0.55, 0.12, 0.1)
		l.outline_size = 0
		l.position = Vector3(0, 0.82, 0.025)
		root.add_child(l)
		_property_signs[id] = root
	biens.changed.connect(_refresh_biens)
	_refresh_biens()


func _refresh_biens() -> void:
	var biens := get_node("/root/Biens")
	for id in LOGEMENTS.keys() + portes_adresses.keys():
		if lots.has(id) and lots[id].has("area"):
			lots[id].area.set_meta("prompt", _logement_prompt(id))
	for id in _property_signs:
		_property_signs[id].visible = biens.count(id) > 0
	if _chemin:
		_chemin._refresh_cabane()
	if biens.driven == _vehicle_id:
		return
	_vehicle_id = biens.driven
	if _vehicle:
		_vehicle.queue_free()
		_vehicle = null
	if _vehicle_id == "":
		return
	_vehicle = biens.build_vehicle(_vehicle_id)
	if _vehicle == null:
		return
	_vehicle.position = PARKING[0]
	_vehicle.rotation_degrees.y = PARKING[1]
	# Biens.build_vehicle rend tout à l'échelle des voitures KayKit, posées à 1,9 sur la place.
	_vehicle.scale = Vector3.ONE * 1.9
	add_child(_vehicle)


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


# --- L'arrêt du car départemental : la carte des communes où il s'arrête (autoload Carte) -------

## L'abri, au bord de la place, tourné vers la rue du Clain : [position, orientation (degrés)].
const ARRET := [Vector3(4.25, 0, 4.15), 0.0]


func _arret_de_car() -> void:
	var root := Node3D.new()
	root.position = ARRET[0]
	root.rotation_degrees.y = ARRET[1]
	add_child(root)
	var acier := StandardMaterial3D.new()
	acier.albedo_color = Color(0.16, 0.3, 0.32)
	acier.metallic = 0.5
	acier.roughness = 0.45
	var vitre := StandardMaterial3D.new()
	vitre.albedo_color = Color(0.7, 0.85, 0.9, 0.28)
	vitre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vitre.roughness = 0.1
	var banc := StandardMaterial3D.new()
	banc.albedo_color = Color(0.45, 0.28, 0.14)
	# Quatre montants, un toit, le fond et les côtés vitrés, un banc.
	for x in [-1.05, 1.05]:
		for z in [-0.45, 0.45]:
			main._box(Vector3(0.07, 2.2, 0.07), Vector3(x, 1.1, z), acier, root)
	main._box(Vector3(2.4, 0.08, 1.15), Vector3(0, 2.24, 0), acier, root)
	main._box(Vector3(2.1, 1.7, 0.03), Vector3(0, 1.15, -0.45), vitre, root)
	for x in [-1.05, 1.05]:
		main._box(Vector3(0.03, 1.7, 0.85), Vector3(x, 1.15, 0), vitre, root)
	main._box(Vector3(1.6, 0.06, 0.36), Vector3(0, 0.48, -0.25), banc, root)
	main._box(Vector3(2.4, 0.24, 0.04), Vector3(0, 2.08, 0.56), acier, root)
	# Le poteau de l'arrêt, son disque et le nom de la ligne.
	main._box(Vector3(0.07, 2.6, 0.07), Vector3(1.5, 1.3, 0.5), acier, root)
	var disque := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.32
	cyl.height = 0.04
	disque.mesh = cyl
	var jaune := StandardMaterial3D.new()
	jaune.albedo_color = Color(0.96, 0.8, 0.3)
	disque.material_override = jaune
	disque.rotation_degrees.x = 90
	disque.position = Vector3(1.5, 2.45, 0.53)
	root.add_child(disque)
	var car := Label3D.new()
	car.text = "CAR"
	car.font = main.serif
	car.font_size = 44
	car.pixel_size = 0.004
	car.modulate = Color(0.1, 0.12, 0.14)
	car.outline_size = 0
	car.position = Vector3(1.5, 2.45, 0.56)
	root.add_child(car)
	var nom := Label3D.new()
	nom.text = "CAR DÉPARTEMENTAL  ·  ARRÊT PLACE"
	nom.font = main.serif
	nom.font_size = 36
	nom.pixel_size = 0.004
	nom.modulate = Color(0.95, 0.92, 0.82)
	nom.outline_size = 0
	nom.position = Vector3(0, 2.08, 0.585)
	root.add_child(nom)
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(3.2, 2.4, 1.8)
	cs.shape = b
	cs.position = Vector3(0.2, 1.2, 0.3)
	a.add_child(cs)
	a.set_meta("interact", "car")
	a.set_meta("action", Carte.ouvrir_car)
	a.set_meta("prompt", "E : prendre le car départemental")
	root.add_child(a)


# --- Le voisinage : le panneau de la mairie et les noms des autres joueurs (autoload Voisinage) -----

## Le panneau d'affichage, sur la place, à droite de la mairie : [position, orientation (degrés)].
const PANNEAU := [Vector3(-1.9, 0, -3.3), 0.0]

## Au-dessus de la porte de chaque logement, les noms des autres joueurs qui en ont la clef.
var _plaques := {}


func _voisinage() -> void:
	var root := Node3D.new()
	root.position = PANNEAU[0]
	root.rotation_degrees.y = PANNEAU[1]
	add_child(root)
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.36, 0.22, 0.12)
	var ardoise := StandardMaterial3D.new()
	ardoise.albedo_color = Color(0.13, 0.19, 0.17)
	for x in [-0.62, 0.62]:
		main._box(Vector3(0.08, 1.9, 0.08), Vector3(x, 0.95, 0), bois, root)
	main._box(Vector3(1.4, 0.95, 0.06), Vector3(0, 1.3, 0), bois, root)
	main._box(Vector3(1.28, 0.83, 0.02), Vector3(0, 1.3, 0.035), ardoise, root)
	main._box(Vector3(1.5, 0.08, 0.2), Vector3(0, 1.84, 0), bois, root)
	var titre := Label3D.new()
	titre.text = "AFFICHAGE"
	titre.font = main.serif
	titre.font_size = 44
	titre.pixel_size = 0.004
	titre.modulate = Color(0.93, 0.93, 0.88)
	titre.outline_size = 0
	titre.position = Vector3(0, 1.6, 0.05)
	root.add_child(titre)
	# Des feuilles punaisées, pour qu'on voie de loin qu'il y a des nouvelles.
	var papier := StandardMaterial3D.new()
	papier.albedo_color = Color(0.95, 0.92, 0.82)
	for f in [[-0.35, 1.2, 0.0], [0.05, 1.28, 0.06], [0.4, 1.15, -0.04]]:
		main._box(Vector3(0.28, 0.36, 0.005), Vector3(f[0], f[1], 0.05), papier, root).rotation.z = f[2]
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.6, 2.0, 1.0)
	cs.shape = b
	cs.position = Vector3(0, 1.0, 0.4)
	a.add_child(cs)
	a.set_meta("interact", "panneau")
	a.set_meta("action", Tableau.ouvrir_panneau)
	a.set_meta("prompt", "E : lire le panneau d'affichage")
	root.add_child(a)
	for id in LOGEMENTS:
		var p := Label3D.new()
		p.font = main.serif
		p.font_size = 36
		p.pixel_size = 0.004
		p.modulate = Color(0.98, 0.9, 0.7)
		p.outline_size = 8
		p.outline_modulate = Color(0, 0, 0, 0.7)
		p.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		p.position = LOGEMENTS[id][0] + Vector3(0, 2.5, 0)
		p.visible = false
		add_child(p)
		_plaques[id] = p
	Voisinage.lu.connect(_refresh_voisinage)
	_refresh_voisinage()
	Voisinage.lire(true)


func _refresh_voisinage() -> void:
	for id in _plaques:
		var gens := Voisinage.voisins(id)
		_plaques[id].visible = not gens.is_empty()
		_plaques[id].text = "Aussi chez %s" % _noms(gens)
	if get_node_or_null("/root/Biens"):
		_refresh_biens()


## « Paulette », « Paulette et Bastien », « Paulette, Bastien et 3 autres ».
static func _noms(gens: Array) -> String:
	var noms: Array = gens.map(func(g): return str(g.get("nom", "")))
	if noms.size() <= 1:
		return "".join(noms)
	if noms.size() == 2:
		return "%s et %s" % noms
	if noms.size() == 3:
		return "%s, %s et %s" % noms
	return "%s, %s et %d autres" % [noms[0], noms[1], noms.size() - 2]


## Pour les captures de vérification : -- --vue=distance,x,y,z,lacet,tangage (vue maquette, sans suivre l'habitant).
func _capture_view() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cran="):
			# Pour comparer les cadrages de la vue qui suit l'habitant : -- --cran=0 (proche), 1 (rue), 2 (quartier).
			main._bark_timer = INF
			await get_tree().create_timer(0.4).timeout
			var c := arg.trim_prefix("--cran=").split_floats(",")
			if c.size() == 1:
				main.camera.set_notch(int(c[0]))
			else:
				# Ou un cadrage libre à essayer : -- --cran=distance,tangage,champ
				main.camera.use_notches([[c[0], c[1], c[2]]], 0)
			continue
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


## Une enseigne de toit entre la caméra et l'habitant pâlit, au lieu de se brouiller sous la coupe.
func _fade_roof_signs(delta: float) -> void:
	var at: Vector3 = main.player.global_position if main.player and main.fps and main.topdown else Vector3(INF, 0, INF)
	for sign in _roof_signs:
		var p := sign.global_position
		var near := Vector2(p.x - at.x, p.z - at.z).length() < 4.0
		var mat: StandardMaterial3D = sign.get_meta("material")
		var a := move_toward(mat.albedo_color.a, 0.12 if near else 1.0, delta * 3.0)
		if a == mat.albedo_color.a:
			continue
		mat.albedo_color.a = a
		var l: Label3D = sign.get_meta("label")
		l.modulate.a = a


## Le quartier qui contient ce point du monde, "" s'il n'est sur aucun socle.
static func zone_at(pos: Vector3) -> String:
	for id in ZONES:
		if (ZONES[id].rect as Rect2).has_point(Vector2(pos.x, pos.z)):
			return id
	return ""


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


## Garde une voiture dans sa file, l'écarte autour du rond-point et la tourne dans le sens de sa marche.
func _follow_road(car: Node3D) -> void:
	if not car.has_meta("lane"):
		car.set_meta("lane", car.position.z - ROAD_Z)
		car.set_meta("last_x", car.position.x)
	var lane: float = car.get_meta("lane")
	var last: float = car.get_meta("last_x")
	var dx := car.position.x - last
	car.set_meta("last_x", car.position.x)
	if absf(dx) < 0.0001 or absf(dx) > 5.0:
		return
	var r := BOIS.road_z(car.position.x, lane, ROAD_Z)
	car.position.z = r.x
	var dir := signf(dx)
	car.rotation.y = atan2(dir, dir * r.y)


func _process(delta: float) -> void:
	_update_cutaway()
	_fade_roof_signs(delta)
	if main.player:
		var z := zone_at(main.player.global_position)
		if z != current_zone:
			current_zone = z
			if z != "":
				zone_entered.emit(z)
	if _tournee_area:
		_tournee_area.set_meta("prompt", "E : offrir une tournée générale (%s crédits)" % main._fmt(get_node("/root/Biens").tournee_price()))
	for car in _cars:
		var v: float = car.get_meta("speed")
		car.position.x += v * delta
		if car.position.x > ROAD_EAST:
			car.position.x = ROAD_WEST
		elif car.position.x < ROAD_WEST:
			car.position.x = ROAD_EAST
	# Toutes les voitures, celles de la place comprises, contournent le vieux chêne.
	for car in _cars + main.moving_cars:
		_follow_road(car)
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
