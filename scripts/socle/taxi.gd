class_name Taxi
## Le taxi de bourg, bâti par l'atelier des véhicules (scripts/socle/carrosserie.gd) : une berline basse
## et filante, bleu nuit laqué qui tourne au violet et à l'or en bord de forme, joncs chromés sous les
## vitres, jantes argent, feux effilés, et sur le toit le lumineux blanc « TAXI » à la française, avec ses
## petites lampes de tarif. Sur les portières arrière, le nom de la commune en lettres d'argent.
## Deux livrées (LIVREES) : « bleu-nuit », celle du bourg, et « jaune », jaune d'or laqué au damier noir et
## blanc sous les glaces, lettres noires. La brique taxis@1 de la bibliothèque les offre aux communes.
##
## `Taxi.habiller(modele, commune)` efface l'habit du modèle de kit (sa collision, ses lumières et son
## mouvement restent) et pose la berline à sa taille. Premier client : le taxi qui passe sur la grand-rue
## de Smarves (Main._build_trees_and_lights).

const LONG := 4.6
const LARGE := 1.84
const ROUE_Z := 1.42
const ROUE_R := 0.33
const BLEU_NUIT := Color(0.11, 0.21, 0.64)
const JAUNE := Color(1.0, 0.8, 0.1)
const PLAQUE := "TX-086-SM"
const LIVREES := ["bleu-nuit", "jaune"]
const ARRONDI := 0.1
const ARGENT := Color(0.86, 0.87, 0.9)


static func habiller(modele: Node3D, commune := "", police: Font = null, livree := "bleu-nuit") -> Node3D:
	var c := Carrosserie.habiller(modele, LONG)
	c.name = "Taxi"
	batir(c, commune, police, livree)
	return c


## Bâtit le taxi sous c, roues au sol en y = 0, l'avant vers +Z, long de LONG. `plaque` vide : celle de la livrée.
static func batir(c: Node3D, commune := "", police: Font = null, livree := "bleu-nuit", plaque := "") -> void:
	var w := LARGE / 2.0
	var jaune := livree == "jaune"
	if plaque == "":
		plaque = "TX-512-JN" if jaune else PLAQUE
	var laque: ShaderMaterial
	if jaune:
		# Un jaune d'or plein, qui se dore en bord de forme, sur un bas de caisse noir.
		laque = Carrosserie.laque(JAUNE, Color(1.0, 0.62, 0.18), 0.25, Color(0.03, 0.03, 0.04), 0.3)
		laque.set_shader_parameter("rugosite", 0.16)
		laque.set_shader_parameter("vernis", 1.6)
		laque.set_shader_parameter("chatoiement", 0.3)
	else:
		laque = Carrosserie.laque(BLEU_NUIT, Color(0.62, 0.45, 0.85), 0.45, Color(0.03, 0.03, 0.04), 0.3)
		# Une laque claire et très vernie : les lampes de la placette et la rue courent sur les flancs.
		laque.set_shader_parameter("rugosite", 0.14)
		laque.set_shader_parameter("vernis", 2.4)
		laque.set_shader_parameter("chatoiement", 0.6)
	var chrome := Carrosserie.chrome()
	var verre := Carrosserie.verre()
	verre.set_shader_parameter("vernis", 1.0)
	var noir := Carrosserie.laque(Color(0.02, 0.02, 0.025), Color(0.2, 0.22, 0.3), 0.0)
	noir.set_shader_parameter("vernis", 0.4)
	var mat_noir := Carrosserie.mat(Color(0.015, 0.015, 0.018), 0.7)
	# La caisse, de profil : malle courte, lunette couchée, pavillon bas, long pare-brise, capot plongeant.
	var p := PackedVector2Array([Vector2(-2.3, 0.36), Vector2(-2.24, 0.22)])
	for z: float in [-ROUE_Z, ROUE_Z]:
		p.append_array(Carrosserie.arc(Vector2(z, ROUE_R), 0.41, 208.0, -28.0, 12))
	p.append_array([Vector2(2.22, 0.22), Vector2(2.32, 0.36)])
	p.append_array(Carrosserie.arc(Vector2(2.08, 0.52), 0.25, -15.0, 75.0, 5))
	p.append_array([Vector2(1.2, 0.92), Vector2(0.3, 1.4)])
	p.append_array(Carrosserie.arc(Vector2(-0.15, 0.95), 0.5, 65.0, 105.0, 4))
	p.append_array([Vector2(-1.55, 0.98), Vector2(-2.12, 0.93)])
	p.append_array(Carrosserie.arc(Vector2(-2.08, 0.72), 0.22, 95.0, 180.0, 4))
	c.add_child(_mi(Carrosserie.galbe(p, LARGE, ARRONDI), laque))
	# Les vitres : pare-brise, lunette, et sur chaque flanc les deux glaces séparées par le montant.
	var pb := [Vector3(-w + 0.28, 0.95, 1.16), Vector3(w - 0.28, 0.95, 1.16), Vector3(w - 0.32, 1.36, 0.36), Vector3(-w + 0.32, 1.36, 0.36)]
	Carrosserie.plaque(c, pb, verre, Vector3(0, 1, 1), 0.008)
	Carrosserie.cadre(c, pb, 0.012, noir, Vector3(0, 0.01, 0.006))
	var lu := [Vector3(-w + 0.3, 1.0, -1.52), Vector3(w - 0.3, 1.0, -1.52), Vector3(w - 0.32, 1.345, -0.5), Vector3(-w + 0.32, 1.345, -0.5)]
	Carrosserie.plaque(c, lu, verre, Vector3(0, 1, -1), 0.008)
	for s: float in [-1.0, 1.0]:
		var x := (w + 0.01) * s
		# Les glaces suivent le flanc rentré de l'arrondi : rien ne dépasse du pavillon ni des montants.
		var avant := [Vector3(x, 0.96, -0.05), Vector3(x, 0.96, 0.9), Vector3(x, 1.24, 0.38), Vector3(x, 1.27, -0.05)]
		var arriere := [Vector3(x, 0.96, -1.3), Vector3(x, 0.96, -0.15), Vector3(x, 1.27, -0.15), Vector3(x, 1.27, -0.42)]
		for v: Array in [avant, arriere]:
			Carrosserie.plaque(c, v, verre, Vector3(s, 0, 0))
			Carrosserie.cadre(c, v, 0.012, noir, Vector3(0.004 * s, 0, 0))
		# Le jonc chromé sous les glaces, d'un bout à l'autre ; les poignées ; les rétroviseurs.
		Carrosserie.jonc(c, Vector3(x + 0.008 * s, 0.94, -1.3), Vector3(x + 0.008 * s, 0.94, 0.9), 0.011, chrome)
		Carrosserie.jonc(c, Vector3(x + 0.008 * s, 1.285, -0.42), Vector3(x + 0.008 * s, 1.285, 0.36), 0.009, chrome)
		for z: float in [0.25, -0.95]:
			Carrosserie.boite(c, Vector3(0.02, 0.025, 0.13), Vector3(x + 0.008 * s, 0.82, z), chrome)
		Carrosserie.boite(c, Vector3(0.1, 0.03, 0.04), Vector3(x + 0.04 * s, 0.98, 0.86), mat_noir)
		Carrosserie.boite(c, Vector3(0.06, 0.11, 0.16), Vector3(x + 0.1 * s, 1.0, 0.84), laque)
		# Le bas de caisse noir et son liseré d'argent.
		Carrosserie.boite(c, Vector3(0.02, 0.05, 2.0), Vector3(x + 0.005 * s, 0.27, 0.0), mat_noir)
		Carrosserie.boite(c, Vector3(0.012, 0.012, 2.0), Vector3(x + 0.012 * s, 0.31, 0.0), chrome)
		for z: float in [-ROUE_Z, ROUE_Z]:
			_roue(c, Vector3((w - 0.14) * s, ROUE_R, z), s, chrome)
		# L'avant : les projecteurs en lames de 50 × 8 cm, couchés dans la pente de l'aile, le feu de jour dessous.
		var phare := Node3D.new()
		phare.position = Vector3(0.56 * s, 0.6, 2.3)
		phare.rotation_degrees = Vector3(-22, -10 * s, 0)
		c.add_child(phare)
		Carrosserie.boite(phare, Vector3(0.5, 0.08, 0.016), Vector3.ZERO, noir)
		Carrosserie.boite(phare, Vector3(0.44, 0.04, 0.012), Vector3(0.0, 0.0, 0.006), Carrosserie.feu(Color(0.92, 0.95, 1.0), 1.0))
		Carrosserie.boite(c, Vector3(0.22, 0.014, 0.012), Vector3(0.62 * s, 0.4, 2.31), Carrosserie.feu(Color(0.95, 0.97, 1.0), 1.3))
		# Le jaune porte son damier noir et blanc sous les glaces, de la lunette au pare-brise.
		if jaune:
			_damier(c, x + 0.006 * s, s, 0.85, -1.3, 0.9, 0.035)
		# Le nom de la commune sur les portières arrière, en lettres d'argent (noires sur le jaune).
		if commune != "":
			Carrosserie.inscription(c, "TAXI · " + commune.to_upper(), Vector3(x + 0.006 * s, 0.66, -0.75), 90.0 if s > 0.0 else -90.0, 0.075, Color(0.04, 0.04, 0.05) if jaune else ARGENT, police)
	# La calandre : basse et large, cerclée de chrome, à lames ; la plaque sous elle.
	var gr := [Vector3(-0.5, 0.36, 2.32), Vector3(0.5, 0.36, 2.32), Vector3(0.44, 0.55, 2.28), Vector3(-0.44, 0.55, 2.28)]
	Carrosserie.plaque(c, gr, mat_noir, Vector3(0, 0, 1), 0.012)
	Carrosserie.cadre(c, gr, 0.012, chrome, Vector3(0, 0, 0.016))
	for i in 3:
		Carrosserie.boite(c, Vector3(0.86, 0.01, 0.012), Vector3(0, 0.41 + i * 0.05, 2.325 - i * 0.012), chrome)
	Carrosserie.boite(c, Vector3(LARGE - 0.2, 0.1, 0.04), Vector3(0, 0.25, 2.24), mat_noir)
	_plaque(c, Vector3(0, 0.29, 2.3), 0.0, Color(0.95, 0.95, 0.93), plaque, police)
	# L'arrière : le bandeau rouge des feux d'un bord à l'autre de la malle, la plaque.
	Carrosserie.boite(c, Vector3(LARGE - 0.3, 0.06, 0.02), Vector3(0, 0.8, -2.305), Carrosserie.feu(Color(0.85, 0.05, 0.04), 0.8))
	for s: float in [-1.0, 1.0]:
		Carrosserie.boite(c, Vector3(0.3, 0.12, 0.02), Vector3(0.68 * s, 0.76, -2.315), Carrosserie.feu(Color(0.85, 0.05, 0.04), 0.9))
	_plaque(c, Vector3(0, 0.55, -2.31), 180.0, Color(0.95, 0.95, 0.93) if jaune else Color(0.96, 0.8, 0.18), plaque, police)
	Carrosserie.boite(c, Vector3(LARGE - 0.2, 0.12, 0.04), Vector3(0, 0.27, -2.25), mat_noir)
	# Sur le pavillon, le lumineux « TAXI » : blanc éclairé, lettres noires devant et derrière,
	# les quatre petites lampes de tarif sur sa face avant.
	var lum := Node3D.new()
	lum.name = "Lumineux"
	lum.position = Vector3(0, 1.47, 0.0)
	c.add_child(lum)
	Carrosserie.boite(lum, Vector3(0.64, 0.035, 0.22), Vector3(0, 0.0, 0), mat_noir)
	Carrosserie.boite(lum, Vector3(0.6, 0.15, 0.18), Vector3(0, 0.09, 0), Carrosserie.feu(Color(0.95, 0.94, 0.88), 0.9))
	for f: Array in [[0.0, 1.0], [180.0, -1.0]]:
		Carrosserie.inscription(lum, "TAXI", Vector3(0, 0.1, 0.092 * float(f[1])), f[0], 0.11, Color(0.04, 0.04, 0.05), police)
	for i in 4:
		Carrosserie.disque(lum, 0.014, 0.01, Vector3(-0.21 + i * 0.14, 0.02, 0.112), Carrosserie.feu([Color(0.2, 0.9, 0.3), Color(0.95, 0.2, 0.1)][i % 2], 0.6), true)


## Une plaque d'immatriculation : fond `fond`, numéro noir, tournée de `lacet` degrés.
static func _plaque(c: Node3D, at: Vector3, lacet: float, fond: Color, numero: String, police: Font) -> void:
	var n := Node3D.new()
	n.position = at
	n.rotation_degrees.y = lacet
	c.add_child(n)
	Carrosserie.boite(n, Vector3(0.52, 0.11, 0.012), Vector3.ZERO, Carrosserie.mat(fond, 0.5))
	Carrosserie.inscription(n, numero, Vector3(0, 0, 0.008), 0.0, 0.075, Color(0.03, 0.03, 0.035), police)


## Le damier du flanc `s` : deux rangs de carreaux de `cote`, de z0 à z1, le bas en y ; un ruban blanc et ses
## carreaux noirs en un seul maillage.
static func _damier(c: Node3D, x: float, s: float, y: float, z0: float, z1: float, cote: float) -> void:
	Carrosserie.boite(c, Vector3(0.006, cote * 2.0, z1 - z0), Vector3(x, y + cote, (z0 + z1) / 2.0), Carrosserie.mat(Color(0.95, 0.95, 0.92), 0.4))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xx := x + 0.009 * s
	var n := int((z1 - z0) / cote)
	for rang in 2:
		for i in n:
			if (i + rang) % 2 == 1:
				continue
			var a := z0 + i * cote
			var b := a + cote
			var y0 := y + rang * cote
			var y1 := y0 + cote
			var q := [Vector3(xx, y0, a), Vector3(xx, y0, b), Vector3(xx, y1, b), Vector3(xx, y1, a)]
			# Les faces tournent dans le sens horaire vues de leur côté : le flanc +x et le flanc -x s'opposent.
			var ordre := [0, 1, 2, 0, 2, 3] if s > 0.0 else [0, 2, 1, 0, 3, 2]
			for k: int in ordre:
				st.set_normal(Vector3(s, 0, 0))
				st.add_vertex(q[k])
	Carrosserie.piece(c, st.commit(), Carrosserie.mat(Color(0.02, 0.02, 0.025), 0.4))


static func _mi(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi


## Une roue tournée vers le flanc `s` : pneu, jante argent à branches fines, moyeu.
static func _roue(c: Node3D, at: Vector3, s: float, chrome: Material) -> void:
	var pneu := Carrosserie.mat(Color(0.03, 0.03, 0.035), 0.9)
	Carrosserie.disque(c, ROUE_R, 0.24, at, pneu)
	Carrosserie.disque(c, ROUE_R * 0.7, 0.012, at + Vector3(0.12 * s, 0, 0), Carrosserie.mat(Color(0.05, 0.05, 0.06), 0.6))
	Carrosserie.disque(c, ROUE_R * 0.72, 0.008, at + Vector3(0.118 * s, 0, 0), chrome)
	for i in 10:
		var a := deg_to_rad(i * 36.0)
		Carrosserie.boite(c, Vector3(0.012, ROUE_R * 0.6, 0.022), at + Vector3(0.127 * s, cos(a) * ROUE_R * 0.32, sin(a) * ROUE_R * 0.32), chrome, Vector3(i * 36.0, 0, 0))
	Carrosserie.disque(c, ROUE_R * 0.14, 0.02, at + Vector3(0.13 * s, 0, 0), chrome)
