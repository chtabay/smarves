extends RefCounted
## Les Terreaux, quartier n° 2 de Lyon (cartes/lyon/VILLE.md) : la place, l'Hôtel de Ville et son beffroi,
## la fontaine Bartholdi, le palais Saint-Pierre et son cloître, la rue Terme qui descend de Sathonay.
## La note est INTENTIONS.md, le relevé releve.md. Tout se pose sous racine, en mètres dans le repère de la
## ville (x est, z sud, y haut) ; le relief vient de la commune (racine.get_parent().hauteur).
##   Terreaux.batir(racine)

const DOSSIER := "res://communes/lyon/quartiers/terreaux/"
const U := 2.4
const FACADIER := "facadier-lyonnais@1"
const MOBILIER := "mobilier-lyonnais@1"
const VEGETATION := "vegetation-lyonnaise@1"
const ARBRES := "arbres-de-place@1"

## Le quartier : les bâtiments dont le centre tombe dans Rect2(104, 124, 376, 300) se bâtissent ici (la réserve
## des Terreaux dans lyon.gd, RESERVES) ; le reste appartient aux voisins (Sathonay au nord et à l'ouest).
const ZONE := [Vector2(104.0, 124.0), Vector2(480.0, 124.0), Vector2(480.0, 424.0), Vector2(104.0, 424.0)]
## La place est tournée de −8,3° : u suit son grand axe vers l'est, v son petit axe vers le sud (le palais).
const P0 := Vector2(252.75, 191.0)
const AXE := Vector2(0.98953, -0.14436)
const TRAVERS := Vector2(0.14436, 0.98953)
const LACET_PLACE := 0.1449
## Les bornes de la place entre ses façades, en (u, v).
const SALLE := Rect2(-55.5, -28.0, 118.0, 67.5)
const FONTAINE := Vector2(-2.0, -11.4)
## Le palais Saint-Pierre (u, v) et son cloître.
const PALAIS := Rect2(-51.0, 39.2, 108.0, 82.0)
const CLOITRE := Rect2(-30.0, 56.0, 66.0, 50.0)
const PORCHE := -2.0
## L'Hôtel de Ville : le pied du milieu de sa façade, et sa direction (vers le nord le long de la façade).
const HDV := Vector2(315.5, 187.2)
const HDV_LONG := Vector2(0.1458, 0.9893)
## Les bâtiments du relevé que les monuments remplacent (le corps sur la place de l'Hôtel de Ville, le palais).
const REMPLACES := [4, 169, 264]
## Les fronts bâtis par le façadier : la place (nord et ouest) et la rue Terme, avec leur rez-de-chaussée.
const FRONTS_PLACE := [22, 38, 64, 150, 151, 152, 154, 235, 236, 85, 178, 179]
const FRONTS_TERME := [136, 137, 148, 238]

const ENDUITS := ["e2c28a", "d8a888", "ebdab8", "e6c08e", "dcb48c", "efdcb6", "d9b27e"]
const ENDUITS_RUE := ["dccaa6", "d6c09a", "e2d0ac", "cfb894", "e0caa0"]
const TUILES := ["8f4a38", "86422f", "965040", "7e3f30", "92503f", "8a4836"]
const PIERRE := Color("#e8dcc3")
## la pierre de l'Hôtel de Ville sous le soleil du soir : la même, prise plus dorée pour que l'or passe à l'écran
const PIERRE_HDV := Color("#ebd9b8")
const RUE_TERME := [Vector2(136.0, 124.0), Vector2(138.0, 130.0), Vector2(139.0, 138.0), Vector2(144.0, 183.0),
	Vector2(146.0, 187.5), Vector2(149.0, 186.0), Vector2(183.0, 177.0), Vector2(199.0, 175.0)]
const PIERRE_PALAIS := Color("#d9c49a")
const ARDOISE := Color("#4a5058")
const DOME := Color("#3e464e")
const PLOMB := Color("#4c5254")
const OR := Color("#c9a66b")
const DALLE := Color("#b3a998")
const PAVE := Color("#a39b93")
const SABLE := Color("#b48e62")
const VILLEBOIS := Color("#c7c3b6")
const EAU := Color("#3d5b57")


static func batir(racine: Node3D) -> void:
	var q := {"racine": racine, "commune": racine.get_parent(), "rng": RandomNumberGenerator.new(),
		"data": JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "bourg.json"))}
	q.rng.seed = 69123002
	_volumes(q)
	_fronts(q)
	_place(q)
	_rues(q)
	_fontaine(q)
	_hotel_de_ville(q)
	_palais(q)
	_cloitre(q)
	_vie(q)
	_reperes(q)


## L'altitude du sol, celle de la commune (VILLE.md : un quartier ne refait pas le sol).
static func hauteur(q: Dictionary, x: float, z: float) -> float:
	var c = q.commune
	if c != null and c.has_method("hauteur"):
		return c.hauteur(x, z)
	return 7.0


static func dans_le_quartier(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, PackedVector2Array(ZONE))


## Du repère de la place (u le long, v en travers) au repère de la ville.
static func monde(u: float, v: float) -> Vector2:
	return P0 + AXE * u + TRAVERS * v


static func _centre(b: Dictionary) -> Vector2:
	var c := Vector2.ZERO
	for p in b.p:
		c += Vector2(p[0], p[1])
	return c / b.p.size() * U


# --- Les matières --------------------------------------------------------------------------------

## Les murs des volumes : fenêtres, volets, encadrements et bandeaux dessinés par le shader, comme les
## volumes de Sathonay ; en mode monument (pierre), de grandes baies à encadrement, cintrées au rez-de-chaussée.
## UV.x : la travée, UV.y : la hauteur au-dessus du sol ; UV2.x : la hauteur du mur, UV2.y : la graine.
static func materiau_murs(monument := false, rdc := 4.2, etage := 3.3) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform float monument = 0.0;
uniform float rdc = 4.2;
uniform float etage = 3.3;
uniform float ombre = 0.6;
varying vec3 dehors;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { dehors = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz; }
void fragment() {
	// les normales sont posées vers le dehors : on les reprend telles quelles, quel que soit le sens des faces
	NORMAL = normalize(dehors);
	// la lumière du ciel baisse sur la pierre, pour que le mur au soleil vaille deux fois et demie le mur à l'ombre
	AO = ombre;
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), 0.35 * (1.0 - monument)) * 1.04;
	float h = UV2.x;
	float y = UV.y;
	float bx = floor(UV.x);
	float fx = fract(UV.x);
	float niveau = y < rdc ? 0.0 : floor((y - rdc) / etage) + 1.0;
	float fy = y < rdc ? y / rdc : fract((y - rdc) / etage);
	float id = hash(vec2(bx, niveau) + UV2.y);
	float fen = 0.0;
	float volet = 0.0;
	float cadre = 0.0;
	float fleurs = 0.0;
	float haut = h - (monument > 0.5 ? 1.6 : 1.3);
	if (niveau < 0.5) {
		if (monument > 0.5) {
			// les baies cintrées du rez-de-chaussée
			vec2 a = vec2((fx - 0.5) / 0.3, (fy - 0.62) / 0.24);
			fen = step(0.2, fx) * step(fx, 0.8) * step(0.04, fy) * step(fy, 0.62) + step(length(a), 1.0) * step(0.62, fy);
			cadre = (step(0.15, fx) * step(fx, 0.85) * step(0.04, fy) * step(fy, 0.92)) * (1.0 - fen) * 0.6;
		} else {
			// une travée sur trois est une porte, une sur trois une vitrine, le reste du mur
			float t = hash(vec2(bx, 11.0) + UV2.y);
			fen = t < 0.33 ? step(0.32, fx) * step(fx, 0.68) * step(0.0, fy) * step(fy, 0.62)
				: (t < 0.66 ? step(0.14, fx) * step(fx, 0.86) * step(0.12, fy) * step(fy, 0.66) : 0.0);
		}
	} else if (y < haut) {
		float l = monument > 0.5 ? 0.24 : 0.3;
		fen = step(l, fx) * step(fx, 1.0 - l) * step(0.16, fy) * step(fy, 0.86);
		cadre = step(l - 0.05, fx) * step(fx, 1.05 - l) * step(0.1, fy) * step(fy, 0.95) * (1.0 - fen);
		if (monument < 0.5) {
			volet = (step(0.17, fx) * step(fx, 0.3) + step(0.7, fx) * step(fx, 0.83)) * step(0.16, fy) * step(fy, 0.86) * step(0.45, id);
			fleurs = step(0.28, fx) * step(fx, 0.72) * step(0.16, fy) * step(fy, 0.25) * step(0.55, hash(vec2(bx, niveau) + UV2.y + 7.0));
		}
	}
	float bandeau = step(rdc - 0.3, y) * step(y, rdc + 0.05) + step(h - 0.7, y);
	if (monument > 0.5) {
		bandeau += step(0.0, y - rdc) * step(fract((y - rdc) / etage), 0.05);
	}
	vec3 verre = vec3(0.24, 0.29, 0.34) + vec3(0.06, 0.06, 0.05) * step(fy, 0.5);
	vec3 col = c * (0.93 + 0.09 * hash(vec2(floor(y * 2.0), bx)));
	col = mix(col, vec3(0.42, 0.5, 0.44) * (0.8 + 0.4 * hash(vec2(UV2.y, 3.0))), volet);
	col = mix(col, c * 1.1, clamp(bandeau, 0.0, 1.0));
	col = mix(col, mix(vec3(0.95, 0.92, 0.84), c * 1.12, monument), cadre);
	col = mix(col, verre, fen);
	col = mix(col, mix(vec3(0.78, 0.12, 0.14), vec3(0.24, 0.42, 0.18), step(0.21, fy)), fleurs);
	col *= 1.0 - 0.3 * smoothstep(h - 0.7, h, y) - 0.3 * (1.0 - smoothstep(0.0, 0.5, y));
	ALBEDO = col * mix(1.0, 1.25, 1.0 - fen);
	ROUGHNESS = mix(0.9, 0.25, fen);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("monument", 1.0 if monument else 0.0)
	m.set_shader_parameter("rdc", rdc)
	m.set_shader_parameter("etage", etage)
	return m


## La dalle de la place : de grands carreaux de granit clair de 3,5 m, à joints sombres, alignés sur la grille
## des jets (dans le repère du nœud, celui de la place).
static func materiau_dalle(module := 3.5, decalage := Vector2(3.0, 3.0)) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 teinte : source_color = vec3(0.70, 0.66, 0.6);
uniform float module = 3.5;
uniform vec2 decalage = vec2(3.0, 3.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 g = (lp.xz - decalage) / module;
	vec2 f = fract(g);
	float joint = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * module;
	// les carreaux de 3,5 m sont faits de dalles de 0,7 m, à joints fins
	vec2 g2 = lp.xz / vec2(0.7, 0.7);
	vec2 f2 = fract(g2);
	float fin = min(min(f2.x, 1.0 - f2.x), min(f2.y, 1.0 - f2.y)) * 0.7;
	float v = 0.9 + 0.12 * hash(floor(g2)) + 0.04 * hash(floor(g));
	vec3 c = teinte * v;
	c *= mix(0.86, 1.0, smoothstep(0.008, 0.02, fin));
	c = mix(vec3(0.42, 0.39, 0.34), c, smoothstep(0.015, 0.04, joint));
	ALBEDO = c;
	ROUGHNESS = 0.8;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("module", module)
	m.set_shader_parameter("decalage", decalage)
	return m


static func mat(c: Color, rugueux := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugueux
	m.metallic = metal
	return m


static func materiau_eau(clair := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#a3b7ba") if clair else EAU
	m.roughness = 0.08
	m.metallic = 0.2
	if clair:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.45
		m.emission_enabled = true
		m.emission = Color("#c8d6d8")
		m.emission_energy_multiplier = 0.25
	return m


# --- Les volumes du quartier ---------------------------------------------------------------------

## Un mur vertical de a à b (pieds au sol), de base à haut, aux UV du shader des murs.
static func mur(st: SurfaceTool, a: Vector2, b: Vector2, base: float, sol: float, haut: float, c: Color, graine: float, travee: float, dedans: Vector2) -> void:
	var l := a.distance_to(b)
	# la normale sort du volume : du côté opposé au point du dedans
	var n := Vector2(b.y - a.y, a.x - b.x).normalized()
	if n.dot((a + b) * 0.5 - dedans) < 0.0:
		n = -n
	var u1 := l / travee
	var hm := haut - sol
	var pts := [Vector3(a.x, base, a.y), Vector3(b.x, base, b.y), Vector3(b.x, haut, b.y), Vector3(a.x, haut, a.y)]
	var uvs := [Vector2(0, base - sol), Vector2(u1, base - sol), Vector2(u1, hm), Vector2(0, hm)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3(n.x, 0.0, n.y))
		st.set_color(c)
		st.set_uv(uvs[k])
		st.set_uv2(Vector2(hm, graine))
		st.add_vertex(pts[k])


## Les bâtiments du relevé dans le quartier, en volumes : murs au shader, toit de tuile en croupe sur leur
## rectangle quand l'emprise le remplit, sinon une terrasse de tuile. Les fronts du façadier abaissent le
## volume qu'ils habillent à leur corniche.
static func _volumes(q: Dictionary) -> void:
	var murs := SurfaceTool.new()
	murs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var toits := SurfaceTool.new()
	toits.begin(Mesh.PRIMITIVE_TRIANGLES)
	var coll := PackedVector3Array()
	q["corniches"] = {}
	var bats: Array = q.data.batiments
	for i in bats.size():
		var b: Dictionary = bats[i]
		if i in REMPLACES:
			continue
		var c := _centre(b)
		if not dans_le_quartier(c):
			continue
		var poly := PackedVector2Array()
		for p in b.p:
			poly.append(Vector2(p[0], p[1]) * U)
		var sol := hauteur(q, c.x, c.y)
		var bas := sol
		for p in poly:
			bas = minf(bas, hauteur(q, p.x, p.y))
		var h: float = b.h * U
		if i in FRONTS_PLACE or i in FRONTS_TERME:
			var n := clampi(roundi((h - 4.2 - 2.0) / 3.3), 4, 6)
			h = 4.2 + 3.3 * n
			q.corniches[i] = n
		var haut := sol + h
		var teinte := Color(ENDUITS_RUE[i % ENDUITS_RUE.size()]) if c.y < 175.0 or c.x < 190.0 else Color(ENDUITS[i % ENDUITS.size()])
		if b.get("mur", "") == "pierre":
			teinte = teinte.lerp(PIERRE_PALAIS, 0.35)
		for k in poly.size():
			var a := poly[k]
			var e := poly[(k + 1) % poly.size()]
			if a.distance_to(e) < 0.2:
				continue
			mur(murs, a, e, bas - 1.5, sol, haut, teinte, float(i % 97), 3.2, c)
			for v in [Vector3(a.x, bas - 1.5, a.y), Vector3(e.x, bas - 1.5, e.y), Vector3(e.x, haut, e.y),
					Vector3(a.x, bas - 1.5, a.y), Vector3(e.x, haut, e.y), Vector3(a.x, haut, a.y)]:
				coll.append(v)
		_toit(toits, b, poly, haut, Color(TUILES[i % TUILES.size()]))
	var racine: Node3D = q.racine
	var mi := MeshInstance3D.new()
	mi.name = "Volumes"
	mi.mesh = murs.commit()
	mi.material_override = materiau_murs()
	racine.add_child(mi)
	var mt := MeshInstance3D.new()
	mt.name = "Toits"
	toits.generate_normals()
	mt.mesh = toits.commit()
	var mtoit := mat(Color.WHITE, 0.8)
	mtoit.vertex_color_use_as_albedo = true
	mt.material_override = mtoit
	racine.add_child(mt)
	var corps := StaticBody3D.new()
	corps.name = "Murs"
	var forme := CollisionShape3D.new()
	var cs := ConcavePolygonShape3D.new()
	cs.backface_collision = true
	cs.set_faces(coll)
	forme.shape = cs
	corps.add_child(forme)
	racine.add_child(corps)


static func _toit(st: SurfaceTool, b: Dictionary, poly: PackedVector2Array, haut: float, c: Color) -> void:
	# la terrasse, toujours : elle ferme le volume quand la croupe ne le couvre pas
	var tri := Geometry2D.triangulate_polygon(poly)
	var sombre := c.darkened(0.12)
	for k in range(0, tri.size(), 3):
		for j in [0, 2, 1] if _sens(poly) > 0.0 else [0, 1, 2]:
			var p := poly[tri[k + j]]
			st.set_color(sombre)
			st.add_vertex(Vector3(p.x, haut + 0.02, p.y))
	var r = b.get("rect", null)
	if r == null or float(b.get("rempli", 0.0)) < 0.8:
		return
	var ctr := Vector2(r[0], r[1]) * U
	var w: float = r[2] * U * 0.98
	var d: float = r[3] * U * 0.98
	var ex := Vector2(cos(r[4]), sin(r[4]))
	var ez := Vector2(-ex.y, ex.x)
	if d > w:
		var t := w
		w = d
		d = t
		var e := ex
		ex = ez
		ez = -e
	var hr := minf(d * 0.5 * 0.42, 5.5)
	var r1 := ctr + ex * (w * 0.5 - d * 0.5)
	var r0 := ctr - ex * (w * 0.5 - d * 0.5)
	var coins := [ctr - ex * w * 0.5 - ez * d * 0.5, ctr + ex * w * 0.5 - ez * d * 0.5, ctr + ex * w * 0.5 + ez * d * 0.5, ctr - ex * w * 0.5 + ez * d * 0.5]
	var A := Vector3(coins[0].x, haut, coins[0].y)
	var B := Vector3(coins[1].x, haut, coins[1].y)
	var C := Vector3(coins[2].x, haut, coins[2].y)
	var D := Vector3(coins[3].x, haut, coins[3].y)
	var R0 := Vector3(r0.x, haut + hr, r0.y)
	var R1 := Vector3(r1.x, haut + hr, r1.y)
	var faces := [[A, B, R1, R0, c], [C, D, R0, R1, c.darkened(0.06)], [B, C, R1, R1, c.lightened(0.04)], [D, A, R0, R0, c.darkened(0.1)]]
	for f in faces:
		for v in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			st.set_color(f[4])
			st.add_vertex(v)
		for v in [f[0], f[2], f[1], f[0], f[3], f[2]]:
			st.set_color(f[4])
			st.add_vertex(v)


static func _sens(poly: PackedVector2Array) -> float:
	var s := 0.0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s


# --- Les fronts du façadier ----------------------------------------------------------------------

## Les façades de la bibliothèque sur la place et dans la rue Terme : chaque côté de l'emprise qui regarde
## la place (ou l'axe de la rue) reçoit un immeuble du façadier, à sa largeur et à la corniche du volume.
static func _fronts(q: Dictionary) -> void:
	var groupe := Node3D.new()
	groupe.name = "Fronts"
	q.racine.add_child(groupe)
	var bats: Array = q.data.batiments
	var cafes := 0
	for i in FRONTS_PLACE + FRONTS_TERME:
		var b: Dictionary = bats[i]
		var poly := PackedVector2Array()
		for p in b.p:
			poly.append(Vector2(p[0], p[1]) * U)
		var c := _centre(b)
		var terme: bool = i in FRONTS_TERME
		for k in poly.size():
			var a := poly[k]
			var e := poly[(k + 1) % poly.size()]
			var l := a.distance_to(e)
			if l < 4.0:
				continue
			var m := (a + e) * 0.5
			var t := (e - a) / l
			var n := Vector2(-t.y, t.x)
			if n.dot(m - c) < 0.0:
				n = -n
			var vers: Vector2
			if terme:
				vers = Vector2(signf(141.0 - m.x), 0.0)
				if absf(m.x - 141.0) > 9.0 or m.y < 126.0 or m.y > 190.0:
					continue
			else:
				var lu := (m - P0).dot(AXE)
				var lv := (m - P0).dot(TRAVERS)
				if lv > -20.0 and lu > -45.0:
					continue
				vers = (P0 - m).normalized()
			if n.dot(vers) < 0.75:
				continue
			_front(q, groupe, i, a, e, n, l, terme, cafes)
			if not terme:
				cafes += 1


static func _front(q: Dictionary, groupe: Node3D, i: int, a: Vector2, e: Vector2, n: Vector2, l: float, terme: bool, rang: int) -> void:
	var niveaux: int = q.corniches.get(i, 5) - 1
	var type := "immeuble"
	var opt := {"w": l, "d": 8.0, "niveaux": niveaux, "grain": 1, "tuile": TUILES[i % TUILES.size()]}
	if terme:
		opt["enduit"] = ENDUITS_RUE[i % ENDUITS_RUE.size()]
		type = "traboule" if i == 137 else ("etroite" if l < 6.0 else "immeuble")
		if i == 148:
			type = "cafe"
			opt["enseigne"] = "AU TIERCÉ"
			opt["toile"] = ["2f5a3a", "f3ead6"]
		opt["rdc"] = "passage" if type == "traboule" else ("cafe" if type == "cafe" else "logis")
	else:
		opt["enduit"] = ENDUITS[i % ENDUITS.size()]
		if l < 6.0:
			type = "etroite"
		elif rang % 3 == 0:
			type = "cafe"
			opt["enseigne"] = ["CAFÉ DU BEFFROI", "LES QUATRE CHEVAUX", "BRASSERIE DES TERREAUX", "LE BARTHOLDI"][rang / 3 % 4]
			opt["toile"] = [["b8322c", "f3ead6"], ["2f5a3a", "f3ead6"], ["b8322c", "b8322c"], ["c8962e", "f3ead6"]][rang / 3 % 4]
			opt["avancee"] = 2.4
		elif rang % 3 == 1:
			type = "bourgeois" if l > 11.0 else "immeuble"
			opt["rdc"] = "boutique"
		else:
			opt["rdc"] = "boutique"
		if i == 150:
			opt["enseigne"] = "CAISSE DE LA GRANDE-CÔTE"
			opt["rdc"] = "pierre"
			opt["toile"] = ["2e4a6e", "2e4a6e"]
	var f: Node3D = load(Bibliotheque.scene(FACADIER, "decor")).instantiate()
	f.type = type
	f.graine = 2000 + i
	f.options = opt
	var m := (a + e) * 0.5 + n * 0.15
	f.position = Vector3(m.x, hauteur(q, m.x, m.y), m.y)
	f.rotation.y = atan2(n.x, n.y)
	f.name = "Front%d" % i
	groupe.add_child(f)
	if type == "cafe" and not terme:
		# la terrasse du café, sous son store : deux rangs de tables
		for k in 3:
			var p := m + n * 3.2 + (e - a).normalized() * (k - 1) * 3.4
			_poser(q, MOBILIER, "objet", "terrasse", Vector3(p.x, hauteur(q, p.x, p.y), p.y), 300 + i * 7 + k, {}, atan2(n.x, n.y))


static func _poser(q: Dictionary, id: String, cle: String, valeur: String, p: Vector3, g: int, opt := {}, lacet := 0.0, parent: Node3D = null) -> Node3D:
	var s := Bibliotheque.scene(id, "decor")
	if s == "":
		return null
	var b: Node3D = load(s).instantiate()
	b.set(cle, valeur)
	b.graine = g
	b.options = opt
	b.position = p
	b.rotation.y = lacet
	(parent if parent != null else q.racine).add_child(b)
	return b


# --- La place ------------------------------------------------------------------------------------

## Le niveau de la dalle en (u, v) de la place : elle suit le relief de la commune, cinq centimètres au-dessus.
static func sol_place(q: Dictionary, u: float, v: float) -> float:
	var p := monde(u, v)
	return hauteur(q, p.x, p.y) + 0.22


## La place : une dalle de granit en grille, les jets d'eau aux nœuds de la grille, les quatorze piliers
## devant le palais. Tout dans le repère tourné de la place.
static func _place(q: Dictionary) -> void:
	var place := Node3D.new()
	place.name = "Place"
	place.position = Vector3(P0.x, 0.0, P0.y)
	place.rotation.y = LACET_PLACE
	q.racine.add_child(place)
	q["place"] = place
	var dalle := MeshInstance3D.new()
	dalle.name = "Dalle"
	# une nappe de 2 m de maille posée sur le relief : la place descend doucement vers l'Hôtel de Ville
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := int(ceil(SALLE.size.x / 2.0))
	var nv := int(ceil(SALLE.size.y / 2.0))
	for iv in nv + 1:
		for iu in nu + 1:
			var u := SALLE.position.x + SALLE.size.x * iu / nu
			var v := SALLE.position.y + SALLE.size.y * iv / nv
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(u, sol_place(q, u, v), v))
	for iv in nv:
		for iu in nu:
			var k := iv * (nu + 1) + iu
			for t in [k, k + 1, k + nu + 1, k + 1, k + nu + 2, k + nu + 1]:
				st.add_index(t)
	st.generate_normals()
	dalle.mesh = st.commit()
	dalle.material_override = materiau_dalle()
	place.add_child(dalle)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	forme.shape = dalle.mesh.create_trimesh_shape()
	corps.add_child(forme)
	dalle.add_child(corps)
	# les jets : une grille de 7 m, sauf autour de la fontaine
	var jets := MultiMesh.new()
	jets.transform_format = MultiMesh.TRANSFORM_3D
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.06
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	jets.mesh = cyl
	var grilles := MultiMesh.new()
	grilles.transform_format = MultiMesh.TRANSFORM_3D
	var g := CylinderMesh.new()
	g.top_radius = 0.32
	g.bottom_radius = 0.32
	g.height = 0.02
	g.radial_segments = 12
	grilles.mesh = g
	var poses: Array = []
	var u := -46.0
	while u <= 53.0:
		var v := 3.0
		while v <= 31.0:
			if Vector2(u, v).distance_to(FONTAINE) > 13.0:
				poses.append(Vector2(u, v))
			v += 7.0
		u += 7.0
	jets.instance_count = poses.size()
	grilles.instance_count = poses.size()
	for k in poses.size():
		var p: Vector2 = poses[k]
		var hj: float = 1.4 + q.rng.randf() * 1.2
		jets.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(1, hj, 1)), Vector3(p.x, sol_place(q, p.x, p.y) + hj * 0.5, p.y)))
		grilles.set_instance_transform(k, Transform3D(Basis(), Vector3(p.x, sol_place(q, p.x, p.y) + 0.01, p.y)))
	var mj := MultiMeshInstance3D.new()
	mj.name = "Jets"
	mj.multimesh = jets
	mj.material_override = materiau_eau(true)
	mj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	place.add_child(mj)
	var mg := MultiMeshInstance3D.new()
	mg.name = "Grilles"
	mg.multimesh = grilles
	mg.material_override = mat(Color("#3a3a36"), 0.5, 0.4)
	place.add_child(mg)
	# l'eau qui luit autour de chaque jet
	var flaques := MultiMesh.new()
	flaques.transform_format = MultiMesh.TRANSFORM_3D
	var fl := CylinderMesh.new()
	fl.top_radius = 1.1
	fl.bottom_radius = 1.1
	fl.height = 0.01
	fl.radial_segments = 16
	flaques.mesh = fl
	flaques.instance_count = poses.size()
	for k in poses.size():
		var p: Vector2 = poses[k]
		flaques.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(1.0 + q.rng.randf() * 0.4, 1, 0.8 + q.rng.randf() * 0.4)), Vector3(p.x, sol_place(q, p.x, p.y) + 0.012, p.y)))
	var mf := MultiMeshInstance3D.new()
	mf.name = "Flaques"
	mf.multimesh = flaques
	var mfl := mat(Color("#7f8c8c"), 0.05, 0.3)
	mfl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mfl.albedo_color.a = 0.25
	mf.material_override = mfl
	mf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	place.add_child(mf)
	# les quatorze piliers devant le palais
	var piliers := MultiMesh.new()
	piliers.transform_format = MultiMesh.TRANSFORM_3D
	var pb := BoxMesh.new()
	pb.size = Vector3(0.6, 2.0, 0.6)
	piliers.mesh = pb
	piliers.instance_count = 14
	for k in 14:
		piliers.set_instance_transform(k, Transform3D(Basis(), Vector3(-45.5 + 7.0 * k, sol_place(q, -45.5 + 7.0 * k, 34.0) + 1.0, 34.0)))
	var mp := MultiMeshInstance3D.new()
	mp.name = "Piliers"
	mp.multimesh = piliers
	mp.material_override = mat(Color("#77746e"), 0.6)
	place.add_child(mp)
	var cp := StaticBody3D.new()
	for k in 14:
		var fp := CollisionShape3D.new()
		var bp := BoxShape3D.new()
		bp.size = pb.size
		fp.shape = bp
		fp.position = Vector3(-45.5 + 7.0 * k, sol_place(q, -45.5 + 7.0 * k, 34.0) + 1.0, 34.0)
		cp.add_child(fp)
	place.add_child(cp)


# --- La fontaine Bartholdi -----------------------------------------------------------------------

static func _forme(parent: Node3D, mesh: Mesh, p: Vector3, m: Material, rot := Vector3.ZERO, echelle := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = p
	mi.rotation = rot
	mi.scale = echelle
	parent.add_child(mi)
	return mi


static func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 10
	c.rings = 3
	return c


static func _bou(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _cyl(r0: float, r1: float, h: float, cotes := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r0
	c.bottom_radius = r1
	c.height = h
	c.radial_segments = cotes
	c.rings = 1
	return c


static func _blo(t: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = t
	return b


## Le sol du sas : un seul pavé, celui des rues de la ville, de la limite du quartier au bord de la place,
## d'une façade à l'autre, posé sur la chaussée et les trottoirs de la commune. Il monte de 3 à 20 cm sur ses
## huit premiers mètres au milieu de la rue, pour que le pas ne bute pas sur la couture.
static func _rues(q: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector2Array()
	for k in RUE_TERME.size() - 1:
		var a: Vector2 = RUE_TERME[k]
		var b: Vector2 = RUE_TERME[k + 1]
		var n := int(ceil(a.distance_to(b) / 2.0))
		for i in n:
			pts.append(a.lerp(b, float(i) / n))
	pts.append(RUE_TERME[-1])
	var bords: Array = []
	var depart := 0.0
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-t.y, t.x)
		# 14 m entre façades dans la rue Terme, 9 m dans la rue d'Algérie
		var l := 7.0 if pts[i].y < 184.0 else 4.5
		if i > 0:
			depart += pts[i].distance_to(pts[i - 1])
		# la chaussée de la commune monte de 3 à 22 cm ; ses trottoirs et leurs bordures restent dessous
		var dy := lerpf(0.03, 0.22, clampf(depart / 8.0, 0.0, 1.0))
		var cote := []
		for e in [-l, -3.2, 3.2, l]:
			var p: Vector2 = pts[i] + n * e
			cote.append(Vector3(p.x, hauteur(q, p.x, p.y) + (dy if absf(e) < 3.5 else 0.22), p.y))
		bords.append(cote)
	var coll := PackedVector3Array()
	for i in bords.size() - 1:
		for k in 3:
			var a0: Vector3 = bords[i][k]
			var a1: Vector3 = bords[i][k + 1]
			var b0: Vector3 = bords[i + 1][k]
			var b1: Vector3 = bords[i + 1][k + 1]
			for v in [a0, b0, a1, a1, b0, b1]:
				st.set_normal(Vector3.UP)
				st.set_color(PAVE)
				st.add_vertex(v)
				coll.append(v)
	var mi := MeshInstance3D.new()
	mi.name = "RueTerme"
	mi.mesh = st.commit()
	var c = q.commune
	if c != null and c.has_method("materiau_paves"):
		mi.material_override = c.materiau_paves()
	else:
		var m := mat(PAVE, 0.9)
		m.vertex_color_use_as_albedo = true
		mi.material_override = m
	q.racine.add_child(mi)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var tri := ConcavePolygonShape3D.new()
	tri.backface_collision = true
	tri.set_faces(coll)
	forme.shape = tri
	corps.add_child(forme)
	mi.add_child(corps)


## Le char triomphant : le bassin de pierre, le rocher, le char en conque, la femme qui mène, et les quatre
## chevaux cabrés vers le palais (+v), le poitrail dans l'écume. Un peu plus grand que nature (la note).
static func _fontaine(q: Dictionary) -> void:
	var f := Node3D.new()
	f.name = "FontaineBartholdi"
	f.position = Vector3(FONTAINE.x, sol_place(q, FONTAINE.x, FONTAINE.y) - 0.05, FONTAINE.y)
	q.place.add_child(f)
	var pierre := mat(Color("#cdbfa4"), 0.85)
	var plomb := mat(PLOMB, 0.42, 0.35)
	var ecume := mat(Color("#f4f2ea"), 0.6)
	# le bassin : la margelle à deux degrés, l'eau, le rocher
	_forme(f, _cyl(9.0, 9.2, 0.35), Vector3(0, 0.17, 0), mat(VILLEBOIS))
	_forme(f, _cyl(8.6, 8.6, 0.75), Vector3(0, 0.5, 0), pierre)
	_forme(f, _cyl(8.1, 8.1, 0.8), Vector3(0, 0.45, 0), materiau_eau())
	var corps := StaticBody3D.new()
	var fc := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 8.6
	cs.height = 1.0
	fc.shape = cs
	fc.position = Vector3(0, 0.5, 0)
	corps.add_child(fc)
	f.add_child(corps)
	_forme(f, _bou(3.8), Vector3(0, 1.0, -0.6), mat(Color("#7d7a70"), 0.9), Vector3.ZERO, Vector3(1.25, 0.55, 1.0))
	_forme(f, _bou(2.0), Vector3(-1.4, 2.4, -1.5), mat(Color("#6f6d66"), 0.9), Vector3(0.2, 0.4, 0), Vector3(1.0, 0.7, 0.9))
	# l'écume au pied des chevaux et les gerbes des naseaux
	for k in 9:
		var a := -1.2 + k * 0.3
		_forme(f, _bou(0.8 + 0.3 * (k % 3)), Vector3(sin(a) * 4.8, 0.9, 2.2 + cos(a) * 1.4), ecume, Vector3.ZERO, Vector3(1.4, 0.45, 1.0))
	# le char en conque et la femme debout qui tient les rênes
	_forme(f, _bou(1.8), Vector3(0, 3.0, -2.2), plomb, Vector3(0.5, 0, 0), Vector3(1.0, 0.75, 1.3))
	_forme(f, _cyl(0.9, 1.5, 1.4, 10), Vector3(0, 2.4, -2.6), plomb)
	_forme(f, _cap(0.42, 2.6), Vector3(0, 4.9, -2.3), plomb, Vector3(-0.15, 0, 0))
	_forme(f, _bou(0.3), Vector3(0, 6.45, -2.1), plomb)
	_forme(f, _cap(0.13, 1.8), Vector3(0.35, 5.6, -1.6), plomb, Vector3(-1.1, 0, -0.2))
	_forme(f, _cap(0.13, 1.6), Vector3(-0.45, 5.9, -2.0), plomb, Vector3(-0.3, 0, 0.6))
	# la draperie qui flotte derrière elle
	_forme(f, _bou(0.9), Vector3(0, 5.1, -3.0), plomb, Vector3(0.6, 0, 0), Vector3(0.9, 1.6, 0.4))
	# les quatre chevaux cabrés, deux paires décalées
	for k in 4:
		var x := -2.7 + k * 1.8
		var avance := 1.6 if k == 1 or k == 2 else 1.0
		_cheval(f, Vector3(x, 2.1, avance), (k - 1.5) * 0.12, plomb)


static func _cheval(f: Node3D, p: Vector3, ecart: float, m: Material) -> void:
	var c := Node3D.new()
	c.position = p
	c.rotation.y = ecart
	f.add_child(c)
	# le corps cabré : 40° vers le haut, vers +z
	var cabre := Vector3(-0.7, 0, 0)
	_forme(c, _cap(0.78, 3.4), Vector3(0, 1.3, 0.4), m, Vector3(PI * 0.5, 0, 0) + cabre * 1.0)
	# l'encolure et la tête
	_forme(c, _cap(0.42, 2.0), Vector3(0, 3.0, 1.75), m, Vector3(0.35, 0, 0))
	_forme(c, _cap(0.3, 1.3), Vector3(0, 3.8, 2.45), m, Vector3(1.9, 0, 0))
	# la crinière
	_forme(c, _cap(0.16, 1.6), Vector3(0, 3.35, 1.45), m, Vector3(0.45, 0, 0))
	# les antérieurs repliés, battant l'air
	for s in [-1.0, 1.0]:
		_forme(c, _cap(0.15, 1.2), Vector3(0.35 * s, 2.0, 2.0), m, Vector3(1.0 + 0.3 * s, 0, 0))
		_forme(c, _cap(0.13, 1.0), Vector3(0.35 * s, 1.55, 2.6), m, Vector3(-0.2, 0, 0))
	# les postérieurs plantés dans le rocher
	for s in [-1.0, 1.0]:
		_forme(c, _cap(0.19, 1.8), Vector3(0.38 * s, -0.1, -0.7), m, Vector3(-0.3, 0, 0))
	# la queue
	_forme(c, _cap(0.14, 1.4), Vector3(0, 0.0, -1.3), m, Vector3(-0.6, 0, 0))


# --- L'Hôtel de Ville ----------------------------------------------------------------------------

## La façade sur la place, dans son repère : +z vers la place (l'ouest), x le long de la façade (vers le
## nord), le corps vers -z. Trois niveaux de pierre claire, pavillons d'angle sous leurs dômes carrés,
## avant-corps central et Henri IV à cheval, balustrade, comble d'ardoise et beffroi à horloge.
static func _hotel_de_ville(q: Dictionary) -> void:
	var h := Node3D.new()
	h.name = "HotelDeVille"
	var y := hauteur(q, HDV.x, HDV.y)
	var n := Vector2(-HDV_LONG.y, HDV_LONG.x)
	h.position = Vector3(HDV.x, y, HDV.y)
	h.rotation.y = atan2(n.x, n.y)
	q.racine.add_child(h)
	q["hdv"] = h
	var W := 48.0
	var D := 30.0
	var H := 20.0
	var pierre := mat(PIERRE, 0.85)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# le corps, la façade et ses retours, et les avant-corps : des murs au shader des monuments
	var corps := [[Vector2(-W * 0.5 + 9.0, 0.0), Vector2(W * 0.5 - 9.0, 0.0), H],
		[Vector2(-W * 0.5, 1.6), Vector2(-W * 0.5 + 9.0, 1.6), H + 1.5], [Vector2(W * 0.5 - 9.0, 1.6), Vector2(W * 0.5, 1.6), H + 1.5],
		[Vector2(-7.0, 1.0), Vector2(7.0, 1.0), H + 1.0]]
	for r in corps:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var hh: float = r[2]
		mur(st, Vector2(a.x, a.y), Vector2(b.x, b.y), -1.0, 0.0, hh, PIERRE_HDV, 3.0, 4.36, Vector2((a.x + b.x) * 0.5, -D * 0.5))
		mur(st, Vector2(b.x, b.y), Vector2(b.x, -D), -1.0, 0.0, hh, PIERRE_HDV, 3.0, 4.36, Vector2((a.x + b.x) * 0.5, -D * 0.5))
		mur(st, Vector2(a.x, -D), Vector2(a.x, a.y), -1.0, 0.0, hh, PIERRE_HDV, 3.0, 4.36, Vector2((a.x + b.x) * 0.5, -D * 0.5))
	var mi := MeshInstance3D.new()
	mi.name = "Facade"
	mi.mesh = st.commit()
	mi.material_override = materiau_murs(true, 6.5, 6.8)
	h.add_child(mi)
	var coll := StaticBody3D.new()
	var fcoll := CollisionShape3D.new()
	var bcoll := BoxShape3D.new()
	bcoll.size = Vector3(W, H, D + 1.6)
	fcoll.shape = bcoll
	fcoll.position = Vector3(0, H * 0.5, -D * 0.5 + 0.8)
	coll.add_child(fcoll)
	h.add_child(coll)
	# les toits : les terrasses, le comble d'ardoise du corps, les dômes carrés des pavillons
	_forme(h, _blo(Vector3(W - 18.0, 0.3, D)), Vector3(0, H, -D * 0.5), pierre)
	var comble := PrismMesh.new()
	comble.size = Vector3(D - 2.0, 6.0, W - 18.0)
	_forme(h, comble, Vector3(0, H + 3.0, -D * 0.5), mat(ARDOISE, 0.6), Vector3(0, PI * 0.5, 0))
	for s in [-1.0, 1.0]:
		var x: float = s * (W * 0.5 - 4.5)
		_forme(h, _blo(Vector3(9.0, 0.3, D + 1.6)), Vector3(x, H + 1.5, -D * 0.5 + 0.8), pierre)
		_forme(h, _cyl(0.6, 6.6, 7.5, 4), Vector3(x, H + 1.5 + 3.75, -4.0), mat(ARDOISE, 0.6), Vector3(0, PI * 0.25, 0))
		_forme(h, _cyl(0.15, 0.4, 2.0, 6), Vector3(x, H + 1.5 + 8.4, -4.0), mat(OR, 0.4, 0.6))
	# la balustrade au sommet de la façade et des pavillons
	var balustres := MultiMesh.new()
	balustres.transform_format = MultiMesh.TRANSFORM_3D
	balustres.mesh = _cyl(0.1, 0.13, 0.85, 6)
	var poses: Array = []
	var x0 := -W * 0.5 + 0.4
	while x0 < W * 0.5 - 0.3:
		var avant := 1.6 if absf(x0) > W * 0.5 - 9.0 else (1.0 if absf(x0) < 7.0 else 0.0)
		var hb := H + (1.5 if absf(x0) > W * 0.5 - 9.0 else (1.0 if absf(x0) < 7.0 else 0.0))
		poses.append(Vector3(x0, hb + 0.45, avant - 0.3))
		x0 += 0.45
	balustres.instance_count = poses.size()
	for k in poses.size():
		balustres.set_instance_transform(k, Transform3D(Basis(), poses[k]))
	var mb := MultiMeshInstance3D.new()
	mb.multimesh = balustres
	mb.material_override = pierre
	h.add_child(mb)
	for s in [[0.0, H + 1.0, 1.0, 14.0], [-(W * 0.5 - 4.5), H + 1.5, 1.6, 9.0], [W * 0.5 - 4.5, H + 1.5, 1.6, 9.0], [-15.0, H, 0.0, 7.0], [15.0, H, 0.0, 7.0]]:
		_forme(h, _blo(Vector3(s[3], 0.22, 0.6)), Vector3(s[0], s[1] + 0.95, s[2] - 0.3), pierre)
		_forme(h, _blo(Vector3(s[3], 0.35, 0.8)), Vector3(s[0], s[1] + 0.12, s[2] - 0.2), pierre)
	# les frontons triangulaires du premier étage
	var fronton := PrismMesh.new()
	fronton.size = Vector3(2.4, 0.8, 0.3)
	var f2 := MultiMesh.new()
	f2.transform_format = MultiMesh.TRANSFORM_3D
	f2.mesh = fronton
	var fps: Array = []
	for k in 11:
		var xb := -W * 0.5 + 4.36 * (k + 0.5)
		if absf(xb) < 7.0:
			continue
		var avant2 := 1.6 if absf(xb) > W * 0.5 - 9.0 else 0.0
		fps.append(Vector3(xb, 6.5 + 6.8 * 0.95 + 0.25, avant2 + 0.15))
	f2.instance_count = fps.size()
	for k in fps.size():
		f2.set_instance_transform(k, Transform3D(Basis(), fps[k]))
	var mf := MultiMeshInstance3D.new()
	mf.multimesh = f2
	mf.material_override = pierre
	h.add_child(mf)
	# l'avant-corps : la porte entre deux colonnes, Henri IV à cheval au second
	_forme(h, _blo(Vector3(3.6, 5.2, 0.4)), Vector3(0, 2.6, 1.05), mat(Color("#3a2c22"), 0.7))
	for s in [-1.0, 1.0]:
		_forme(h, _cyl(0.42, 0.45, 5.6, 12), Vector3(s * 2.6, 2.8, 1.6), pierre)
	_forme(h, _blo(Vector3(7.4, 0.8, 1.2)), Vector3(0, 6.0, 1.5), pierre)
	_forme(h, _blo(Vector3(6.6, 5.4, 0.3)), Vector3(0, 16.0, 1.1), mat(Color("#d2c3a4"), 0.85))
	var relief := mat(Color("#efe4cc"), 0.8)
	_forme(h, _cap(0.7, 3.0), Vector3(0, 15.3, 1.35), relief, Vector3(0, 0, PI * 0.5))
	_forme(h, _cap(0.32, 1.6), Vector3(1.6, 16.4, 1.35), relief, Vector3(0, 0, -0.6))
	_forme(h, _cap(0.3, 1.5), Vector3(0.0, 16.8, 1.4), relief)
	_forme(h, _bou(0.26), Vector3(0.0, 17.8, 1.4), relief)
	for s in [-1.0, 1.0]:
		_forme(h, _cap(0.13, 1.6), Vector3(s * 0.9, 14.0, 1.35), relief, Vector3(0, 0, 0.2 * s))
	# le perron
	for k in 3:
		_forme(h, _blo(Vector3(16.0 - k * 1.2, 0.18, 2.2 - k * 0.5)), Vector3(0, 0.09 + k * 0.18, 2.6 - k * 0.25), mat(VILLEBOIS))
	# le beffroi : la tour carrée à horloge, le tambour à baies, le dôme, le lanternon doré
	var b := Node3D.new()
	b.name = "Beffroi"
	b.position = Vector3(0, H, -5.5)
	h.add_child(b)
	_forme(b, _blo(Vector3(9.0, 11.0, 9.0)), Vector3(0, 5.5, 0), pierre)
	_forme(b, _blo(Vector3(9.6, 0.6, 9.6)), Vector3(0, 11.0, 0), pierre)
	for r in [0.0, PI]:
		var pivot := Node3D.new()
		pivot.rotation.y = r
		b.add_child(pivot)
		_forme(pivot, _cyl(1.7, 1.7, 0.2, 24), Vector3(0, 7.2, 4.55), mat(Color("#f2ecdc"), 0.5), Vector3(PI * 0.5, 0, 0))
		_forme(pivot, _cyl(1.9, 1.9, 0.12, 24), Vector3(0, 7.2, 4.5), mat(OR, 0.4, 0.6), Vector3(PI * 0.5, 0, 0))
		_forme(pivot, _blo(Vector3(0.14, 1.3, 0.06)), Vector3(0, 7.7, 4.7), mat(Color("#1e1e1e")))
		_forme(pivot, _blo(Vector3(0.9, 0.12, 0.06)), Vector3(0.4, 7.2, 4.7), mat(Color("#1e1e1e")))
	_forme(b, _cyl(4.1, 4.4, 6.5, 8), Vector3(0, 14.6, 0), pierre, Vector3(0, PI / 8.0, 0))
	for k in 8:
		var a := TAU * k / 8.0
		var piv := Node3D.new()
		piv.rotation.y = a
		b.add_child(piv)
		_forme(piv, _blo(Vector3(1.3, 3.6, 0.3)), Vector3(0, 14.8, 4.0), mat(Color("#2a2622"), 0.7))
	var dome := _bou(4.5)
	_forme(b, dome, Vector3(0, 17.8, 0), mat(DOME, 0.55, 0.15), Vector3.ZERO, Vector3(1, 1.25, 1))
	_forme(b, _cyl(1.1, 1.3, 3.2, 8), Vector3(0, 24.4, 0), pierre)
	_forme(b, _bou(1.3), Vector3(0, 26.1, 0), mat(DOME, 0.55, 0.15), Vector3.ZERO, Vector3(1, 1.1, 1))
	_forme(b, _cyl(0.05, 0.35, 2.8, 8), Vector3(0, 28.4, 0), mat(OR, 0.35, 0.7))


# --- Le palais Saint-Pierre et son cloître ---------------------------------------------------------

## Le palais : quatre ailes de pierre dorée autour du cloître, la façade nord sur la place (dans l'ombre au
## soir), un porche dans l'axe de la fontaine. Dans le repère de la place.
static func _palais(q: Dictionary) -> void:
	var p := Node3D.new()
	p.name = "PalaisSaintPierre"
	p.position = Vector3(P0.x, sol_place(q, PORCHE, PALAIS.position.y) - 0.04, P0.y)
	p.rotation.y = LACET_PLACE
	q.racine.add_child(p)
	q["palais"] = p
	var H := 18.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var coll := PackedVector3Array()
	var ext := PALAIS
	var inn := CLOITRE
	# les ailes, en blocs : (u0, v0, u1, v1) ; l'aile nord est coupée par le porche
	var blocs := [[ext.position.x, ext.position.y, PORCHE - 2.5, inn.position.y], [PORCHE + 2.5, ext.position.y, ext.end.x, inn.position.y],
		[ext.position.x, inn.end.y, ext.end.x, ext.end.y], [ext.position.x, inn.position.y, inn.position.x, inn.end.y], [inn.end.x, inn.position.y, ext.end.x, inn.end.y]]
	for r in blocs:
		var a := Vector2(r[0], r[1])
		var c := Vector2(r[2], r[3])
		var coins := [Vector2(a.x, c.y), Vector2(c.x, c.y), Vector2(c.x, a.y), Vector2(a.x, a.y)]
		for k in 4:
			var e0: Vector2 = coins[k]
			var e1: Vector2 = coins[(k + 1) % 4]
			mur(st, e0, e1, -1.5, 0.0, H, PIERRE_PALAIS, 11.0, 4.2, (a + c) * 0.5)
			for v in [Vector3(e0.x, -1.5, e0.y), Vector3(e1.x, -1.5, e1.y), Vector3(e1.x, H, e1.y), Vector3(e0.x, -1.5, e0.y), Vector3(e1.x, H, e1.y), Vector3(e0.x, H, e0.y)]:
				coll.append(v)
		var toit := PrismMesh.new()
		var lu: float = c.x - a.x
		var lv: float = c.y - a.y
		if lu >= lv:
			toit.size = Vector3(lv + 0.6, 3.2, lu + 0.6)
			_forme(p, toit, Vector3((a.x + c.x) * 0.5, H + 1.6, (a.y + c.y) * 0.5), mat(Color(TUILES[1]), 0.8), Vector3(0, PI * 0.5, 0))
		else:
			toit.size = Vector3(lu + 0.6, 3.2, lv + 0.6)
			_forme(p, toit, Vector3((a.x + c.x) * 0.5, H + 1.6, (a.y + c.y) * 0.5), mat(Color(TUILES[1]), 0.8))
		_forme(p, _blo(Vector3(lu, 0.3, lv)), Vector3((a.x + c.x) * 0.5, H + 0.05, (a.y + c.y) * 0.5), mat(Color(TUILES[1]).darkened(0.2)))
	# le porche : la voûte au-dessus du passage, et l'entablement de la façade
	var porche := [Vector2(PORCHE - 2.5, ext.position.y), Vector2(PORCHE + 2.5, ext.position.y), Vector2(PORCHE + 2.5, inn.position.y), Vector2(PORCHE - 2.5, inn.position.y)]
	for k in 4:
		var e0: Vector2 = porche[k]
		var e1: Vector2 = porche[(k + 1) % 4]
		mur(st, e0, e1, 6.5, 0.0, H, PIERRE_PALAIS, 11.0, 4.2, Vector2(PORCHE, (ext.position.y + inn.position.y) * 0.5))
	var mi := MeshInstance3D.new()
	mi.name = "Ailes"
	mi.mesh = st.commit()
	mi.material_override = materiau_murs(true, 6.0, 6.0)
	p.add_child(mi)
	_forme(p, _blo(Vector3(5.0, 0.4, inn.position.y - ext.position.y)), Vector3(PORCHE, 6.5, (ext.position.y + inn.position.y) * 0.5), mat(Color("#8a7a62"), 0.9))
	_forme(p, _blo(Vector3(5.0, 0.12, inn.position.y - ext.position.y)), Vector3(PORCHE, 0.04, (ext.position.y + inn.position.y) * 0.5), mat(DALLE))
	# l'encadrement du porche sur la place : deux pilastres et un fronton
	var pierre := mat(PIERRE_PALAIS.lightened(0.08), 0.85)
	for s in [-1.0, 1.0]:
		_forme(p, _blo(Vector3(0.9, 7.6, 0.6)), Vector3(PORCHE + s * 3.0, 3.8, ext.position.y - 0.25), pierre)
	_forme(p, _blo(Vector3(7.6, 1.0, 0.8)), Vector3(PORCHE, 8.0, ext.position.y - 0.3), pierre)
	var fr := PrismMesh.new()
	fr.size = Vector3(8.4, 1.6, 0.6)
	_forme(p, fr, Vector3(PORCHE, 9.3, ext.position.y - 0.3), pierre)
	var corps := StaticBody3D.new()
	corps.name = "Murs"
	var forme := CollisionShape3D.new()
	var cs := ConcavePolygonShape3D.new()
	cs.backface_collision = true
	cs.set_faces(coll)
	forme.shape = cs
	corps.add_child(forme)
	p.add_child(corps)


## Le cloître : le sable, les allées en croix, le bassin rond, les statues sous les arbres, les galeries
## d'arcades au pied des ailes, les bancs et leurs joueurs.
static func _cloitre(q: Dictionary) -> void:
	var p: Node3D = q.palais
	var c := Node3D.new()
	c.name = "Cloitre"
	p.add_child(c)
	var inn := CLOITRE
	var ctr := Vector3(inn.get_center().x, 0.0, inn.get_center().y)
	# le sable, et sa collision (la dalle de la place s'arrête au palais)
	var sable := _forme(c, _blo(Vector3(inn.size.x, 1.0, inn.size.y)), ctr + Vector3(0, -0.45, 0), mat(SABLE, 0.95))
	var corps := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(inn.size.x, 1.0, inn.size.y)
	fs.shape = bs
	corps.add_child(fs)
	sable.add_child(corps)
	var passage := _forme(c, _blo(Vector3(5.0, 1.0, inn.position.y - PALAIS.position.y + 1.0)), Vector3(PORCHE, -0.47, (PALAIS.position.y + inn.position.y) * 0.5), mat(DALLE))
	var cp := StaticBody3D.new()
	var fp := CollisionShape3D.new()
	var bp := BoxShape3D.new()
	bp.size = Vector3(5.0, 1.0, inn.position.y - PALAIS.position.y + 1.0)
	fp.shape = bp
	cp.add_child(fp)
	passage.add_child(cp)
	# les allées en croix et le tour du jardin, de dalle claire
	var allee := mat(Color("#cbbf9f"), 0.9)
	_forme(c, _blo(Vector3(inn.size.x - 9.0, 0.06, 3.0)), ctr + Vector3(0, 0.06, 0), allee)
	_forme(c, _blo(Vector3(3.0, 0.06, inn.size.y - 9.0)), ctr + Vector3(0, 0.06, 0), allee)
	_forme(c, _blo(Vector3(3.0, 0.06, ctr.z - inn.position.y)), Vector3(PORCHE, 0.06, (inn.position.y + ctr.z) * 0.5), allee)
	# le bassin rond
	_forme(c, _cyl(4.2, 4.3, 0.55), ctr + Vector3(0, 0.27, 0), mat(VILLEBOIS))
	_forme(c, _cyl(3.8, 3.8, 0.56), ctr + Vector3(0, 0.3, 0), materiau_eau())
	_forme(c, _cyl(0.35, 0.6, 1.6, 12), ctr + Vector3(0, 0.8, 0), mat(VILLEBOIS))
	_forme(c, _cyl(1.0, 0.3, 0.3, 16), ctr + Vector3(0, 1.7, 0), mat(VILLEBOIS))
	var cb := StaticBody3D.new()
	var fb := CollisionShape3D.new()
	var cyb := CylinderShape3D.new()
	cyb.radius = 4.3
	cyb.height = 0.6
	fb.shape = cyb
	fb.position = ctr + Vector3(0, 0.3, 0)
	cb.add_child(fb)
	c.add_child(cb)
	# les galeries d'arcades au pied des quatre ailes : piliers, arcs, toit en appentis
	var piliers := MultiMesh.new()
	piliers.transform_format = MultiMesh.TRANSFORM_3D
	piliers.mesh = _blo(Vector3(0.7, 4.2, 0.7))
	var poses: Array = []
	var prof := 4.0
	var u := inn.position.x + prof
	while u <= inn.end.x - prof + 0.1:
		if absf(u - PORCHE) > 2.0:
			poses.append(Vector3(u, 2.1, inn.position.y + prof))
		poses.append(Vector3(u, 2.1, inn.end.y - prof))
		u += 4.0
	var v := inn.position.y + prof + 4.0
	while v <= inn.end.y - prof - 0.1:
		poses.append(Vector3(inn.position.x + prof, 2.1, v))
		poses.append(Vector3(inn.end.x - prof, 2.1, v))
		v += 4.0
	piliers.instance_count = poses.size()
	for k in poses.size():
		piliers.set_instance_transform(k, Transform3D(Basis(), poses[k]))
	var mp := MultiMeshInstance3D.new()
	mp.name = "Arcades"
	mp.multimesh = piliers
	mp.material_override = mat(PIERRE_PALAIS.lightened(0.05), 0.85)
	c.add_child(mp)
	var cpl := StaticBody3D.new()
	for pp in poses:
		var f := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(0.7, 4.2, 0.7)
		f.shape = b
		f.position = pp
		cpl.add_child(f)
	c.add_child(cpl)
	var galeries := [[Vector3(ctr.x, 0, inn.position.y + prof * 0.5), Vector3(inn.size.x, 0, prof), 0.0],
		[Vector3(ctr.x, 0, inn.end.y - prof * 0.5), Vector3(inn.size.x, 0, prof), PI],
		[Vector3(inn.position.x + prof * 0.5, 0, ctr.z), Vector3(inn.size.y - prof * 2.0, 0, prof), -PI * 0.5],
		[Vector3(inn.end.x - prof * 0.5, 0, ctr.z), Vector3(inn.size.y - prof * 2.0, 0, prof), PI * 0.5]]
	for g in galeries:
		var piv := Node3D.new()
		piv.position = g[0]
		piv.rotation.y = g[2]
		c.add_child(piv)
		var l: float = g[1].x
		# l'arc au-dessus des piliers (un bandeau percé d'ombre), la voûte, l'appentis de tuile
		_forme(piv, _blo(Vector3(l, 1.0, 0.7)), Vector3(0, 4.7, prof * 0.5), mat(PIERRE_PALAIS.lightened(0.05), 0.85))
		_forme(piv, _blo(Vector3(l, 0.3, prof)), Vector3(0, 5.3, 0), mat(Color("#8d7d64"), 0.9))
		_forme(piv, _blo(Vector3(l, 0.25, prof + 1.0)), Vector3(0, 6.0, 0.2), mat(Color(TUILES[0]), 0.8), Vector3(-0.32, 0, 0))
		_forme(piv, _blo(Vector3(l, 0.06, prof)), Vector3(0, 0.04, 0), mat(DALLE))
	# les arbres, en quinconce le long des allées, la vue vers le nord-est laissée libre
	var arbres := [Vector2(-22, 64), Vector2(-22, 98), Vector2(-8, 66), Vector2(-14, 104), Vector2(14, 96), Vector2(28, 96), Vector2(28, 76), Vector2(14, 66)]
	for k in arbres.size():
		var a: Vector2 = arbres[k]
		_poser(q, ARBRES, "espece", "tilleul", Vector3(a.x, 0.0, a.y), 500 + k, {"hauteur": 12.0 + (k % 3), "pied": "bordure"}, 0.0, c)
	# les statues sur leurs socles, aux quatre angles du bassin
	var marbre := mat(Color("#ece6d6"), 0.6)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var sp := ctr + Vector3(cos(a) * 9.0, 0, sin(a) * 9.0)
		_forme(c, _blo(Vector3(1.2, 1.6, 1.2)), sp + Vector3(0, 0.8, 0), mat(VILLEBOIS))
		_forme(c, _cap(0.38, 1.9), sp + Vector3(0, 2.6, 0), marbre)
		_forme(c, _bou(0.24), sp + Vector3(0, 3.75, 0), marbre)
	# les bancs, tournés vers le bassin, et les massifs
	var bancs := [[Vector2(-12, 81), PI * 0.5], [Vector2(18, 81), -PI * 0.5], [Vector2(3, 70), 0.0], [Vector2(3, 92), PI], [Vector2(-18, 72), PI * 0.25], [Vector2(24, 90), -PI * 0.75]]
	for k in bancs.size():
		var bp2: Vector2 = bancs[k][0]
		_poser(q, MOBILIER, "objet", "banc", Vector3(bp2.x, 0.0, bp2.y), 600 + k, {}, bancs[k][1], c)
	q["bancs"] = bancs
	for k in 4:
		var m := Vector2(ctr.x + (-16.0 if k % 2 == 0 else 16.0), ctr.z + (-10.0 if k < 2 else 10.0))
		_poser(q, VEGETATION, "plante", "massif", Vector3(m.x, 0.0, m.y), 700 + k, {"longueur": 8.0, "largeur": 3.0, "fleurs": "#d04a8a" if k % 2 == 0 else "#f4f0e6"}, 0.0, c)


# --- La vie ---------------------------------------------------------------------------------------

## Le samedi soir : le mariage sur le perron de l'Hôtel de Ville, les terrasses du nord, deux enfants dans
## les jets, des passants en diagonale, le livreur de la rue Terme, les joueurs du cloître. Les figurants
## du socle sont à l'échelle du jeu : leur groupe annule l'échelle de la racine.
static func _vie(q: Dictionary) -> void:
	var racine: Node3D = q.racine
	var k := 1.0 / racine.scale.x if racine.scale.x != 0.0 else 1.0
	var groupe := Node3D.new()
	groupe.name = "Habitants"
	groupe.scale = Vector3.ONE * k
	groupe.set_meta("sans_lointain", true)
	racine.add_child(groupe)
	var g := 69200
	var e := 1.0 / k
	# le mariage : un arc de figurants devant le perron, le photographe en face
	var hdv: Node3D = q.hdv
	for j in 12:
		var a := -1.2 + j * 0.22
		var lp := Vector3(sin(a) * 5.5, 0.0, 4.6 + cos(a) * 1.5 + (j % 2) * 0.8)
		var w: Vector3 = hdv.transform * lp
		var f: Node3D = Atelier.figurant(g, "idle", "soiree" if j % 3 == 0 else "village")
		f.position = Vector3(w.x, hauteur(q, w.x, w.z), w.z) * e
		f.rotation.y = hdv.rotation.y + PI + a * 0.3
		groupe.add_child(f)
		g += 1
	var ph: Vector3 = hdv.transform * Vector3(0.0, 0.0, 13.0)
	var fph: Node3D = Atelier.figurant(g, "idle")
	fph.position = Vector3(ph.x, hauteur(q, ph.x, ph.z), ph.z) * e
	fph.rotation.y = hdv.rotation.y
	groupe.add_child(fph)
	g += 1
	# les terrasses : des attablés devant les cafés du nord
	for j in 14:
		var uv := Vector2(-40.0 + j * 6.5 + (j % 2) * 1.5, -21.5 - (j % 3) * 1.1)
		var w := monde(uv.x, uv.y)
		var f: Node3D = Atelier.figurant(g, "sit")
		f.position = Vector3(w.x, sol_place(q, uv.x, uv.y), w.y) * e
		f.rotation.y = LACET_PLACE + (PI if j % 2 == 0 else 0.0)
		groupe.add_child(f)
		g += 1
	# deux enfants dans les jets
	for uv in [Vector2(11.0, 10.5), Vector2(13.0, 9.0)]:
		var w := monde(uv.x, uv.y)
		var f: Node3D = Atelier.figurant(g, "idle")
		f.position = Vector3(w.x, sol_place(q, uv.x, uv.y), w.y) * e
		f.scale = Vector3.ONE * 0.7
		f.rotation.y = q.rng.randf() * TAU
		groupe.add_child(f)
		g += 1
	# les passants : en diagonale sur la place, le long des façades, dans la rue Terme
	var routes := [
		[Vector2(-50, 30), Vector2(0, 12), Vector2(55, -5)],
		[Vector2(55, 25), Vector2(10, 22), Vector2(-50, -18)],
		[Vector2(-50, -24), Vector2(10, -25), Vector2(58, -24)],
		[Vector2(58, 30), Vector2(0, 31), Vector2(-50, 31)],
		[Vector2(-2, 36), Vector2(-2, 20), Vector2(30, 0)],
	]
	for r in routes:
		var route: Array[Vector3] = []
		for uv in r:
			var w := monde(uv.x, uv.y)
			route.append(Vector3(w.x, sol_place(q, uv.x, uv.y), w.y) * e)
		var f: Node3D = Atelier.figurant(g, "walk", "village", route)
		f.position = route[0]
		groupe.add_child(f)
		g += 1
	var livreur: Array[Vector3] = []
	for p in [Vector2(139.0, 128.0), Vector2(140.5, 160.0), Vector2(146.0, 184.0)]:
		livreur.append(Vector3(p.x, hauteur(q, p.x, p.y), p.y) * e)
	var fl: Node3D = Atelier.figurant(g, "walk", "village", livreur)
	fl.position = livreur[0]
	groupe.add_child(fl)
	g += 1
	# le cloître : les deux joueurs d'écarté, celui qui regarde, deux lecteurs
	var palais: Node3D = q.palais
	for j in q.bancs.size():
		if j > 3:
			break
		var bp: Vector2 = q.bancs[j][0]
		var w: Vector3 = palais.transform * Vector3(bp.x, 0.0, bp.y)
		var f: Node3D = Atelier.figurant(g, "sit")
		f.position = Vector3(w.x, palais.position.y, w.z) * e
		f.rotation.y = palais.rotation.y + float(q.bancs[j][1]) + PI
		groupe.add_child(f)
		g += 1
	var wv: Vector3 = palais.transform * Vector3(-12.0 + 1.3, 0.0, 82.5)
	var fv: Node3D = Atelier.figurant(g, "idle")
	fv.position = Vector3(wv.x, palais.position.y, wv.z) * e
	groupe.add_child(fv)


# --- Les repères ---------------------------------------------------------------------------------

## Les repères du parcours, l'arrivée du taxi et le sas vers Sathonay (VILLE.md, section 5).
static func _reperes(q: Dictionary) -> void:
	var racine: Node3D = q.racine
	var palais: Node3D = q.palais
	var cl := func(lp: Vector2) -> Vector2:
		var w: Vector3 = palais.transform * Vector3(lp.x, 0.0, lp.y)
		return Vector2(w.x, w.z)
	var reperes := {
		# dans l'ombre de la rue d'Algérie, à 25 m du débouché : les façades cadrent la place, le beffroi au fond
		"Vue1a_Terme": [Vector2(172.0, 180.5), Vector2(305.0, 196.0)],
		"Vue1b_Debouche": [Vector2(200.0, 178.0), Vector2(305.0, 180.0)],
		"Vue2a_Salle": [monde(-35.0, 26.0), Vector2(305.0, 176.0)],
		# les coudes de la promenade : devant le porche, puis dans la galerie nord du cloître
		"Vue2b_Porche": [monde(PORCHE, 31.0), monde(PORCHE, 60.0)],
		"Vue2c_Galerie": [cl.call(Vector2(PORCHE, 60.0)), cl.call(Vector2(-20.0, 100.0))],
		"Vue3_Cloitre": [cl.call(Vector2(-20.0, 100.0)), Vector2(HDV.x, HDV.y - 5.0)],
		"Arrivee_Terreaux": [Vector2(321.0, 236.0), Vector2(290.0, 205.0)],
	}
	for nom in reperes:
		var a: Vector2 = reperes[nom][0]
		var b: Vector2 = reperes[nom][1]
		var y := hauteur(q, a.x, a.y) + 0.05
		if nom == "Vue2c_Galerie" or nom == "Vue3_Cloitre":
			y = palais.position.y
		var m := Marker3D.new()
		m.name = nom
		var pa := Vector3(a.x, y + 0.1, a.y)
		m.transform = Transform3D(Basis.looking_at(Vector3(b.x - a.x, 0.0, b.y - a.y), Vector3.UP), pa)
		racine.add_child(m)
	# le sas vers Sathonay : un repère et son rayon, que la veille des sas du socle surveille (Quartiers.veiller)
	var sas := Marker3D.new()
	sas.name = "Sas_sathonay"
	sas.set_meta("rayon", 6.0)
	sas.position = Vector3(133.0, hauteur(q, 133.0, 118.0), 118.0)
	racine.add_child(sas)
