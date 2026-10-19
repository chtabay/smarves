extends Node3D
## Le stade de la Fortune, où joue le Racing Club Minuit : l'habillage que Casino Minuit pose dans le
## stade du socle (champ « habillage » du terrain, socle 1.6). La pelouse, la tribune du club, le tableau
## d'affichage et le match sont ceux du socle ; ici, ce qui fait Las Vegas autour : le Strip la nuit sur
## les quatre côtés, deux virages de velours rouge sous des marquises dorées, la grande enseigne au néon
## derrière le tableau, la roue de la Fortune, des palmiers et des guirlandes de lanternes ; au-dessus du Strip
## peint à l'ouest, la tour du casino et sa couronne rouge « MINUIT », celle qu'on voit depuis le boulevard.
## Repère du stade : pelouse x ∈ [-18, 18], z ∈ [-11, 11] ; tribune au sud (z < -15), tableau au nord
## (z = 16), mains courantes à x = ±22 et z = ±14, murets à x = ±28 et z = ±23.

const KIT := "res://communes/casino_minuit/kit.gd"
const PERSONNAGES := "res://communes/casino_minuit/personnages.gd"
const LOT_E := "res://communes/casino_minuit/zones/lot_e.gd"

var K
var _t := 0.0
var _roue: Node3D


func _ready() -> void:
	K = load(KIT).new(self)
	K.zone_debut("STADE-FORTUNE")
	_strip()
	_tour_minuit()
	for s in [-1.0, 1.0]:
		_virage(s)
	_enseigne()
	_roue_de_la_fortune()
	for p in [[-25.5, -20.5], [25.5, -20.5], [-25.5, 20.5], [25.5, 20.5], [-14.0, 20.5], [14.0, 20.5]]:
		_palmier(p[0], p[1], 7.5 + fmod(absf(p[0]) * 0.37, 1.5))
	_guirlandes()
	K.zone_fin()
	_supporters()


func _process(dt: float) -> void:
	_t += dt
	K.animer(dt, _t)
	if _roue:
		_roue.rotation.z = _t * 0.35


## Le Strip la nuit, peint tout autour au-delà des murets, comme derrière la porte de la rotonde.
func _strip() -> void:
	for c in [[Vector3(0, 13, 46), PI, 140.0], [Vector3(0, 13, -46), 0.0, 140.0], [Vector3(60, 13, 0), -PI / 2.0, 100.0], [Vector3(-60, 13, 0), PI / 2.0, 100.0]]:
		var q := QuadMesh.new()
		q.size = Vector2(c[2], 30.0)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = K.mat("strip")
		mi.position = c[0]
		mi.rotation.y = c[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## La tour de Minuit (lot E, facade.gd) au-delà du Strip peint de l'ouest : le stade est à son pied, derrière
## le casino ; sa couronne rouge dépasse le décor peint.
func _tour_minuit() -> void:
	var E = load(LOT_E)
	E.bloc(K, -84.0, -68.0, -14.0, 2.0, 0.0, 80.0, E.TOUR, "sneo", Color("#1A0A0E"))
	K.box("laque_noire", 17.0, 5.0, 17.0, -76.0, 82.5, -6.0)
	K.box("rouge_lum", 17.2, 0.25, 17.2, -76.0, 80.1, -6.0)
	E.enseigne(K, "MINUIT", "#FF3348", 15.0, 3.6, -67.4, 82.5, -6.0, PI / 2.0)


## Un virage, derrière un but (s = -1 à l'ouest, 1 à l'est) : cinq gradins de velours rouge entre la
## main courante et le muret, une marquise dorée à ampoules, et le nom du club au néon dessus.
func _virage(s: float) -> void:
	var x0 := 23.0
	for i in 5:
		var x := s * (x0 + 0.5 + i * 0.95)
		var h := 0.45 + i * 0.5
		K.box("laque_noire", 0.95, h, 30.0, x, h / 2.0, 0)
		K.box("coussin", 0.5, 0.42, 29.6, x + s * 0.12, h + 0.21, 0)
		K.box("or", 0.04, 0.04, 30.0, x - s * 0.47, h + 0.02, 0)
		K.obstacle(x - 0.48, x + 0.48, -15.0, 15.0, 0.0, h)
	# La marquise : un auvent laqué rouge, sa frise d'ampoules, sur des colonnes d'or.
	var xm := s * 25.4
	for z in [-14.0, -7.0, 0.0, 7.0, 14.0]:
		K.cyl("or", 0.14, 0.18, 6.4, s * 27.4, 3.2, z, 10)
		K.rond(s * 27.4, z, 0.2)
	K.box("laque_rouge", 5.6, 0.3, 31.0, xm, 6.5, 0)
	K.box("or", 0.16, 0.5, 31.0, xm - s * 2.8, 6.4, 0)
	for k in 31:
		K.sph("ampoule", 0.07, xm - s * 2.9, 6.12, -15.0 + k)
	K.box("laque_noire", 0.12, 1.5, 16.0, s * 27.6, 7.6, 0)
	K.box("or", 0.16, 0.08, 16.4, s * 27.55, 8.37, 0)
	K.box("or", 0.16, 0.08, 16.4, s * 27.55, 6.83, 0)
	K.texte("RACING CLUB MINUIT", 15.0, 1.1, s * 27.5, 7.6, 0, -s * PI / 2.0, "neon")
	K.lumiere(xm - s * 3.0, 5.5, 0, K.pal.ambre, 1.4, 16.0)


## La grande enseigne derrière le tableau d'affichage, sur ses deux pylônes : « STADE DE LA FORTUNE ».
func _enseigne() -> void:
	var z := 21.0
	for x in [-9.0, 9.0]:
		K.cyl("or_brosse", 0.3, 0.4, 11.0, x, 5.5, z, 12)
		K.rond(x, z, 0.45)
	K.box("laque_noire", 19.0, 3.0, 0.3, 0, 10.0, z)
	K.box("or", 19.4, 0.16, 0.36, 0, 11.55, z)
	K.box("or", 19.4, 0.16, 0.36, 0, 8.45, z)
	for k in 39:
		K.sph("ampoule", 0.08, -9.5 + k * 0.5, 11.72, z - 0.1)
		K.sph("ampoule", 0.08, -9.5 + k * 0.5, 8.28, z - 0.1)
	K.texte("STADE DE LA FORTUNE", 17.0, 1.7, 0, 10.0, z - 0.17, PI, "neon")
	K.lumiere(0, 9.0, z - 3.0, K.pal.ambre_chaud, 1.6, 14.0)


## La roue de la Fortune, haute de six mètres, au-dessus de l'entrée sud-est : elle tourne pendant le match.
func _roue_de_la_fortune() -> void:
	var at := Vector3(0, 9.6, -22.6)
	K.box("laque_noire", 1.2, 9.6, 0.6, 0, 4.8, -22.9)
	_roue = Node3D.new()
	_roue.position = at
	add_child(_roue)
	var m := StandardMaterial3D.new()
	m.albedo_color = K.pal.or
	m.metallic = 0.8
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = K.pal.or_sombre
	m.emission_energy_multiplier = 0.6
	var tore := TorusMesh.new()
	tore.inner_radius = 2.75
	tore.outer_radius = 3.0
	tore.rings = 40
	var cercle := MeshInstance3D.new()
	cercle.mesh = tore
	cercle.material_override = m
	cercle.rotation.x = PI / 2.0
	_roue.add_child(cercle)
	var rouge: Material = K.mat("laque_rouge")
	var noir: Material = K.mat("laque_noire")
	for i in 18:
		var a := TAU * i / 18.0
		var case := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.9, 0.5, 0.12)
		case.mesh = b
		case.material_override = rouge if i % 2 == 0 else noir
		case.position = Vector3(cos(a), sin(a), 0) * 2.45
		case.rotation.z = a + PI / 2.0
		_roue.add_child(case)
		var rayon := MeshInstance3D.new()
		var r := BoxMesh.new()
		r.size = Vector3(2.1, 0.06, 0.06)
		rayon.mesh = r
		rayon.material_override = m
		rayon.position = Vector3(cos(a), sin(a), 0) * 1.05
		rayon.rotation.z = a
		_roue.add_child(rayon)
	var moyeu := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	moyeu.mesh = s
	moyeu.material_override = m
	_roue.add_child(moyeu)
	K.lumiere(0, 9.6, -20.5, K.pal.ambre, 1.2, 10.0)


## Un palmier : un tronc d'anneaux, un bouquet de palmes vertes retombantes.
func _palmier(x: float, z: float, h: float) -> void:
	for i in 8:
		var y := h * i / 8.0
		K.cyl("bois_laque", 0.2 - i * 0.012, 0.24 - i * 0.012, h / 8.0 + 0.02, x + sin(i * 0.4) * 0.15, y + h / 16.0, z, 8)
	var tete := Vector3(x + sin(3.2) * 0.15, h, z)
	for k in 9:
		var a := TAU * k / 9.0
		var mi := tete + Vector3(cos(a), 0.55, sin(a)) * 1.5
		var bout := tete + Vector3(cos(a) * 3.0, -0.9, sin(a) * 3.0)
		K.beam("feutre", tete, mi, 0.55, 0.05)
		K.beam("feutre", mi, bout, 0.42, 0.05)
	K.sph("bois_laque", 0.3, tete.x, tete.y, tete.z)
	K.rond(x, z, 0.3)


## Des guirlandes de lanternes rouges au-dessus des mains courantes nord, d'un pylône à l'autre.
func _guirlandes() -> void:
	for x in [-20.0, -10.0, 0.0, 10.0, 20.0]:
		K.cyl("or", 0.05, 0.06, 5.0, x, 2.5, 14.5, 6)
	for i in 4:
		var x0: float = -20.0 + i * 10.0
		for k in 7:
			var u := (k + 1) / 8.0
			var x := x0 + u * 10.0
			var y := 4.9 - 1.2 * 4.0 * u * (1.0 - u)
			K.lanterne(x, y - 0.55, 14.5, 0.55, 0.4)
		K.beam("or", Vector3(x0, 5.0, 14.5), Vector3(x0 + 5.0, 3.8, 14.5), 0.02, 0.02)
		K.beam("or", Vector3(x0 + 5.0, 3.8, 14.5), Vector3(x0 + 10.0, 5.0, 14.5), 0.02, 0.02)


## Les supporters du Racing Club Minuit, les figurants du casino : assis dans les virages, quelques-uns
## debout au premier rang qui applaudissent, tournés vers la pelouse.
func _supporters() -> void:
	var P = load(PERSONNAGES)
	var g := 300
	for s in [-1.0, 1.0]:
		for i in 5:
			var h: float = 0.45 + i * 0.5
			var x: float = s * (23.5 + i * 0.95)
			for k in 4:
				g += 1
				var z: float = -12.5 + k * 8.3 + fmod(g * 1.37, 2.5)
				var f = P.figurant("client", g)
				var debout: bool = i == 0 and k % 2 == 0
				f.position = Vector3(x + s * 0.12, h if debout else h - 0.03, z)
				add_child(f)
				f.regarder(Vector3(0, f.position.y, z))
				f.jouer("clap" if debout else ("sit_talk" if g % 4 == 0 else "sit"))
