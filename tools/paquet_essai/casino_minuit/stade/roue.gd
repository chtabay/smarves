extends RefCounted
## Le toit du stade de la Fortune : une roue de roulette géante posée sur le stade, ouverte au-dessus de la
## pelouse. De l'intérieur vers le dehors : les 37 cases rouges et noires (le zéro vert) entre leurs frettes d'or,
## qui tournent lentement ; la piste de la bille en bois laqué, ses losanges d'or et sa rangée d'ampoules ; le
## bord d'or. Une bille de lumière court sur la piste. Douze colonnes d'or la portent depuis la façade.
## Suspendu au milieu, sous la roue, l'écran à 360 degrés : huit faces de diodes et, sur les quatre grandes, le
## score, la minute et l'affiche du match.

const BOL := "res://communes/casino_minuit/stade/bol.gd"

## Les rayons (depuis le rond central) et les hauteurs de la roue : elle monte un peu vers le dehors, comme une cuvette.
const R_CASES := 25.0
const R_PISTE := 31.0
const R_BORD := 40.0
const R_FIN := 46.0
const Y_IN := 21.0
const Y_OUT := 24.0
## L'ordre des numéros sur une roue européenne.
const NUMEROS := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const ROUGES := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]


static func hauteur(r: float) -> float:
	return lerpf(Y_IN, Y_OUT, clampf((r - R_CASES) / (R_FIN - R_CASES), 0.0, 1.0))


## Bâtit la roue ; rend {"cases": le nœud qui tourne, "bille": la bille, "ecran": {score, horloge, affiche, miroirs}}.
static func construire(K) -> Dictionary:
	var out := {}
	K.zone_debut("FORTUNE-ROUE-CASES")
	var cases: Node3D = K.zone
	var rouge := _lueur(Color("#E0202F"), 1.4)
	var noir := _lueur(Color("#0E0C10"), 0.0)
	var vert := _lueur(Color("#0FA060"), 1.4)
	var n := NUMEROS.size()
	var st_r := SurfaceTool.new()
	var st_n := SurfaceTool.new()
	var st_v := SurfaceTool.new()
	for st in [st_r, st_n, st_v]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var num: int = NUMEROS[i]
		var st: SurfaceTool = st_v if num == 0 else (st_r if num in ROUGES else st_n)
		_secteur(st, R_CASES, R_PISTE, a0, a1, 6)
		# Les frettes d'or, de part et d'autre.
		var p0 := Vector3(sin(a0) * R_CASES, hauteur(R_CASES) - 0.25, cos(a0) * R_CASES)
		var p1 := Vector3(sin(a0) * R_PISTE, hauteur(R_PISTE) - 0.25, cos(a0) * R_PISTE)
		K.beam("or", p0, p1, 0.18, 0.7)
		# Le numéro, en lettres d'or tournées vers les gradins (dessous) et vers le ciel (dessus).
		var am := (a0 + a1) / 2.0
		var rn := R_CASES + 1.6
		for dessous in [true, false]:
			var l := Label3D.new()
			l.text = str(num)
			l.font = Polices.titre()
			l.font_size = 96
			l.pixel_size = 0.022
			l.modulate = Color("#FFD27A")
			l.outline_size = 8
			l.outline_modulate = Color("#3A2408")
			l.shaded = false
			l.double_sided = false
			l.position = Vector3(sin(am) * rn, hauteur(rn) + (-0.08 if dessous else 0.08), cos(am) * rn)
			l.rotation = Vector3(PI / 2.0 if dessous else -PI / 2.0, am + PI, 0)
			cases.add_child(l)
	for p in [[st_r, rouge], [st_n, noir], [st_v, vert]]:
		var mi := MeshInstance3D.new()
		mi.mesh = (p[0] as SurfaceTool).commit()
		mi.material_override = p[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cases.add_child(mi)
	# Le bord intérieur des cases : une lisse d'or et ses ampoules, ce qu'on voit d'abord depuis la pelouse.
	K.tore("or", R_CASES, 0.22, Transform3D(Basis.IDENTITY, Vector3(0, Y_IN - 0.1, 0)), 96)
	K.zone_fin()
	out.cases = cases
	# La piste, les losanges, le bord d'or : fixes.
	K.zone_debut("FORTUNE-ROUE-PISTE")
	var piste := SurfaceTool.new()
	piste.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bord := SurfaceTool.new()
	bord.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 72:
		var a0 := TAU * i / 72.0
		var a1 := TAU * (i + 1) / 72.0
		_secteur(piste, R_PISTE, R_BORD, a0, a1, 1)
		_secteur(bord, R_BORD, R_FIN, a0, a1, 1)
	K.put("bois_laque", piste.commit())
	K.put("or", bord.commit())
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var r := (R_PISTE + R_BORD) / 2.0
		K.box("or", 1.2, 0.5, 1.2, sin(a) * r, hauteur(r) - 0.3, cos(a) * r, a + PI / 4.0)
	# Le chant de la roue : une bande d'or verticale, et une couronne d'ampoules qui se voit depuis le Strip.
	K.put("or", _chant(R_FIN, Y_OUT - 0.6, Y_OUT + 0.6))
	K.put("ampoule", _chant(R_FIN + 0.05, Y_OUT - 0.15, Y_OUT + 0.15))
	K.put("ampoule", _chant(R_CASES - 0.25, Y_IN - 0.45, Y_IN - 0.25, true))
	_colonnes(K)
	_ecran(K, out)
	K.zone_fin()
	# La bille de lumière, sur la piste.
	var bille := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 1.8
	bille.mesh = sm
	bille.material_override = _lueur(Color("#FFF4DE"), 4.0)
	bille.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := OmniLight3D.new()
	halo.light_color = Color("#FFE6B0")
	halo.light_energy = 1.4
	halo.omni_range = 9.0
	bille.add_child(halo)
	K.racine.add_child(bille)
	out.bille = bille
	return out


## La place de la bille au temps t : elle court sur la piste, sous le bord (on la voit d'en bas).
static func place_bille(t: float, vitesse := 0.18) -> Vector3:
	var a := -t * vitesse
	var r := R_PISTE + 2.2
	return Vector3(sin(a) * r, hauteur(r) - 1.0, cos(a) * r)


## Un secteur d'anneau entre r0 et r1, de a0 à a1, ses deux faces (le dessus et le dessous).
static func _secteur(st: SurfaceTool, r0: float, r1: float, a0: float, a1: float, pas: int) -> void:
	for k in pas:
		var b0 := lerpf(a0, a1, float(k) / pas)
		var b1 := lerpf(a0, a1, float(k + 1) / pas)
		var p := [Vector3(sin(b0) * r0, hauteur(r0), cos(b0) * r0), Vector3(sin(b1) * r0, hauteur(r0), cos(b1) * r0),
			Vector3(sin(b1) * r1, hauteur(r1), cos(b1) * r1), Vector3(sin(b0) * r1, hauteur(r1), cos(b0) * r1)]
		var up: Vector3 = (p[1] - p[0]).cross(p[3] - p[0]).normalized()
		if up.y < 0.0:
			up = -up
		_quad(st, p[0], p[1], p[2], p[3], up)
		_quad(st, p[0] - up * 0.3, p[1] - up * 0.3, p[2] - up * 0.3, p[3] - up * 0.3, -up)


## Une bande verticale tout autour, au rayon r (le chant de la roue).
static func _chant(r: float, y0: float, y1: float, dedans := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 96:
		var a0 := TAU * i / 96.0
		var a1 := TAU * (i + 1) / 96.0
		var n := Vector3(sin((a0 + a1) / 2.0), 0, cos((a0 + a1) / 2.0)) * (-1.0 if dedans else 1.0)
		_quad(st, Vector3(sin(a0) * r, y0, cos(a0) * r), Vector3(sin(a1) * r, y0, cos(a1) * r), Vector3(sin(a1) * r, y1, cos(a1) * r), Vector3(sin(a0) * r, y1, cos(a0) * r), n)
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for t in [[a, b, c], [a, c, d]]:
		var p: Vector3 = t[0]
		var q: Vector3 = t[1]
		var r: Vector3 = t[2]
		if (q - p).cross(r - p).dot(n) > 0.0:
			var x := q
			q = r
			r = x
		for v in [p, q, r]:
			st.set_normal(n)
			st.set_uv(Vector2(v.x, v.z) / 4.0)
			st.add_vertex(v)


static func _lueur(c: Color, energie: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	m.metallic = 0.2
	if energie > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energie
	return m


## Les douze colonnes d'or qui portent la roue, du haut de la façade au-dessous de la roue, et leurs chapiteaux.
static func _colonnes(K) -> void:
	var Bo = load(BOL)
	var e: Array = Bo.echantillons()
	for i in range(0, e.size(), 4):
		var p: Vector3 = Bo.pt(e[i], 19.2, 16.0)
		var r := Vector2(p.x, p.z).length()
		var h := hauteur(r) - 0.3 - 16.0
		K.cyl("or", 0.45, 0.6, h, p.x, 16.0 + h / 2.0, p.z, 12)
		K.box("or", 1.6, 0.4, 1.6, p.x, 16.0 + h, p.z)


## L'écran à 360 degrés, sous la roue, au-dessus du rond central : huit faces de diodes autour d'un tambour noir,
## une couronne d'or dessus et dessous, quatre câbles jusqu'au bord des cases ; sur les quatre grandes faces,
## le score, la minute et l'affiche (la face sud porte les étiquettes du socle, les trois autres les recopient).
static func _ecran(K, out: Dictionary) -> void:
	var E = load("res://communes/casino_minuit/zones/lot_e.gd")
	var y := 15.6
	var h := 4.2
	var r := 5.6
	var cote := 2.0 * r * tan(PI / 8.0)
	# Le corps, caché derrière les huit faces (un cylindre à huit pans a ses pans de biais : on le prend plus étroit).
	K.cyl("laque_noire", r * 0.9, r * 0.9, h + 0.2, 0, y, 0, 8)
	K.cyl("or", r + 0.25, r + 0.25, 0.3, 0, y + h / 2.0 + 0.15, 0, 32)
	K.cyl("or", r + 0.25, r + 0.25, 0.3, 0, y - h / 2.0 - 0.15, 0, 32)
	K.cyl("or", 1.5, 0.1, 1.6, 0, y - h / 2.0 - 1.0, 0, 8)
	for k in 8:
		# Les faces regardent les quatre tribunes et les quatre coins.
		var a := TAU * k / 8.0
		var ap := r * cos(PI / 8.0) + 0.06
		E.ecran(K, sin(a) * ap, y, cos(a) * ap, cote, h, a, 4 if k % 2 == 0 else 1, k * 1.3)
		var bout := Vector3(sin(a) * R_CASES, Y_IN, cos(a) * R_CASES)
		K.beam("acier", Vector3(sin(a) * r, y + h / 2.0 + 0.2, cos(a) * r), bout, 0.06, 0.06)
	# Les quatre grandes faces (celles qui regardent les quatre tribunes) portent les chiffres du match.
	var miroirs := []
	var faces := [[Vector3(0, 0, -1), PI], [Vector3(0, 0, 1), 0.0], [Vector3(1, 0, 0), PI / 2.0], [Vector3(-1, 0, 0), -PI / 2.0]]
	for f in faces:
		var n: Vector3 = f[0]
		var base: Vector3 = n * (r * cos(PI / 8.0) + 0.14)
		var etiquettes := []
		for spec in [[0.9, 160, Color("#FFD24A")], [-0.35, 64, Color("#F3EAD7")], [-1.25, 40, Color("#FF9AA6")]]:
			var l := Label3D.new()
			l.font = Polices.titre()
			l.font_size = spec[1]
			l.pixel_size = 0.0065 if spec[1] == 160 else 0.0075
			l.modulate = spec[2]
			l.outline_size = 10
			l.outline_modulate = Color(0, 0, 0, 0.8)
			l.shaded = false
			l.width = 900
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.position = base + Vector3(0, y + spec[0], 0)
			l.rotation.y = f[1]
			K.racine.add_child(l)
			etiquettes.append(l)
		miroirs.append(etiquettes)
	out.ecran = miroirs
