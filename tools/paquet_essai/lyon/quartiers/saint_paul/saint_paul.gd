extends RefCounted
## Lyon, Saint-Paul et le Change : le quartier n° 3 de la ville (cartes/lyon/VILLE.md ; la note d'intentions est
## INTENTIONS.md, le relevé releve.md). La rive sud de la Saône au pied de la colline, de la passerelle
## Saint-Vincent à la place du Change : l'église Saint-Paul et sa tour-lanterne, la gare et son horloge, la rue
## Juiverie et la galerie de Philibert Delorme, la Loge du Change. Tiré de bourg.json (tools/bourg_reel.py :
## OpenStreetMap, BD TOPO et RGE ALTI de l'IGN), dans le repère de la ville (origine au centre de la place
## Sathonay, x vers l'est, z vers le sud, en mètres).
##
## Quartiers.poser appelle batir(racine) avec racine sous la commune : le quartier lit le relief par
## racine.get_parent().hauteur(x, z) et prend les matières de la commune ; il ne fait ni sol, ni ciel, ni soleil.
## Tout le décor est en mètres sous racine, réduite à l'échelle de Smarves (une unité vaut 2,4 m) ; les
## habitants sont sous « Habitants », remis à l'échelle du jeu.

const DOSSIER := "res://communes/lyon/quartiers/saint_paul/"
const U := 2.4
const FACADIER := "facadier-lyonnais@1"
const MOBILIER := "mobilier-lyonnais@1"
const OMBRIERE := "arbres-d-ombriere@1"
const QUAIS := "quais-lyonnais@1"
const RELIEF_PORTEE := 70.0

## Les enduits du Vieux-Lyon, ocres rouges et roses (la bible de la ville), et ceux, plus pâles, du quai.
const ENDUITS := ["c98a62", "d4a074", "b9705a", "cc9470", "d8a982", "c07f5c", "d09a78"]
const ENDUITS_QUAI := ["d8b08a", "cdb08e", "e0c09a", "d4b494", "dcb890"]
const TUILES := ["8f4a38", "86422f", "965040", "7e3f30", "92503f", "8a4836"]
const PIERRE := Color("#a9a294")
const PIERRE_DOREE := Color("#c9a66b")
const VILLEBOIS := Color("#c7c3b6")
const DALLE := Color("#b3a998")
const BOIS := Color("#5e4b3c")
const FER := Color("#2a2a28")

## Les rues où le joueur passe : les façades y ont leur relief (le façadier), ailleurs le volume peint suffit.
const RELIEF := [Rect2(-250.0, 226.0, 85.0, 104.0), Rect2(-262.0, 318.0, 92.0, 62.0), Rect2(-252.0, 370.0, 52.0, 150.0),
	Rect2(-245.0, 495.0, 125.0, 75.0), Rect2(-192.0, 395.0, 44.0, 125.0)]
## La rive sud de Sathonay (lyon.gd, RIVE_SUD) : le quartier commence au sud de cette ligne.
const RIVE_SUD := [Vector2(-432, 188), Vector2(-351, 188), Vector2(-314, 186), Vector2(-302, 187), Vector2(-250, 202),
	Vector2(-200, 227), Vector2(-147, 280)]

## Les deux places, où toutes les façades qui les bordent ont leur relief.
const PLACE_CHANGE := Rect2(-172.0, 495.0, 55.0, 60.0)
const PLACE_SAINT_PAUL := Rect2(-252.0, 330.0, 60.0, 50.0)

## Les monuments, d'après le relevé : centre, longueur, largeur, angle du grand côté (radians).
const EGLISE := [Vector2(-247.0, 287.0), 54.0, 30.0, 2.4]
const GARE := [Vector2(-266.0, 352.0), 34.0, 36.0, 0.0]
const LOGE := [Vector2(-180.0, 528.0), 22.0, 24.0, 0.0]
## L'hôtel Bullioud : la façade sur la rue Juiverie, la cour, la galerie de Philibert Delorme au fond.
const BULLIOUD_RUE := -229.5
## rue Juiverie : l'alignement des façades est, et la hauteur sur elles en dessous de laquelle tombe l'ombre de
## la rangée ouest à l'heure du soleil (31° sur l'horizon)
const JUIVERIE_EST := -221.5
const JUIVERIE_OMBRE := 8.0
const BULLIOUD_COUR := Rect2(-252.0, 414.0, 14.0, 17.0)

## Le café de courses (en face de la gare) et les traces du fil rouge au Change : le comptoir de la banque de la
## commune, le prêteur sur gages, la boutique saisie (INTENTIONS.md, « Le fil rouge » ; jamais rue Juiverie).
const CAFE := Vector2(-205.0, 357.0)
const TRACES := {
	"banque": Vector2(-140.0, 522.0),
	"gages": Vector2(-142.0, 506.0),
	"saisie": Vector2(-150.0, 548.0),
}

## Les points de vue (œil, regard) et les sas.
const REPERES := {
	"Arrivee_SaintPaul": [Vector2(-196.0, 352.0), Vector2(-260.0, 356.0)],
	# au débouché de la passerelle, sur le quai : la tour-lanterne au-dessus des toits de droite, la rue qui monte
	"Vue1a_Passerelle": [Vector2(-218.0, 232.0), Vector2(-226.0, 290.0)],
	# les coudes du parcours : le quai, l'angle de la rue Saint-Paul, le bas de la rue du Docteur-Augros, la place
	"Vue1b_Quai": [Vector2(-182.0, 264.0), Vector2(-150.0, 300.0)],
	"Vue1c_Gerson": [Vector2(-186.0, 276.5), Vector2(-212.0, 297.0)],
	"Vue1d_Augros": [Vector2(-213.5, 305.0), Vector2(-214.0, 330.0)],
	"Vue1e_PlaceSaintPaul": [Vector2(-213.0, 343.0), Vector2(-240.0, 370.0)],
	"Vue2a_Juiverie": [Vector2(-231.5, 384.0), Vector2(-227.0, 440.0)],
	# devant le porche de l'hôtel Bullioud, le regard dans la cour vers la galerie de Delorme
	"Vue2b_Bullioud": [Vector2(-228.6, 422.5), Vector2(-260.0, 422.5)],
	"Vue2c_Juiverie": [Vector2(-224.5, 458.0), Vector2(-223.0, 500.0)],
	"Vue2d_Loge": [Vector2(-222.5, 512.5), Vector2(-160.0, 513.0)],
	"Vue3a_Change": [Vector2(-150.0, 516.0), Vector2(-157.0, 585.0)],
}
## Les sas (socle 1.26, Quartiers.veiller) : un nœud au débouché, son rayon en mètres dans la méta « rayon ».
const SAS := {
	"Sas_sathonay": [Vector2(-199.0, 236.0), 6.0],
	"Sas_saint_jean": [Vector2(-155.0, 592.0), 6.0],
}


static func batir(racine: Node3D) -> void:
	var b := Batisseur.new()
	b.batir(racine)


class Batisseur:
	var racine: Node3D
	var commune: Node
	var data: Dictionary
	var murs_mat: Material
	var toits_mat: Material
	var paves_mat: Material
	var rng := RandomNumberGenerator.new()
	var emprises: Array = []
	var miens: Array = []
	var grille := {}
	var segments: Array = []
	var cases := {}
	var modules: Array[Node3D] = []
	var relief_pose := {}
	var mats := {}
	var facades: Array = []
	var cafe_pose := false
	var cafe_au: Array = []

	func batir(r: Node3D) -> void:
		racine = r
		# la commune est le premier ancêtre qui a un relief : sous Quartiers.poser, le parent direct est $Quartiers
		commune = r.get_parent()
		while commune != null and not commune.has_method("hauteur"):
			commune = commune.get_parent()
		if commune == null:
			commune = r.get_parent()
		racine.scale = Vector3.ONE / U
		racine.set_meta("lointain", 150.0)
		rng.seed = 69005
		data = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "bourg.json"))
		murs_mat = commune.call("materiau_murs") if commune.has_method("materiau_murs") else mat(Color("#c98a62"))
		toits_mat = commune.call("materiau_toits") if commune.has_method("materiau_toits") else mat(Color("#b0452a"))
		paves_mat = commune.call("materiau_paves") if commune.has_method("materiau_paves") else mat(Color("#a39b93"))
		_choisir()
		_places()
		_batiments()
		_eglise()
		_gare()
		_bullioud()
		_loge()
		_quai()
		_arbres()
		_relief_de_pres()
		_vie()
		_reperes()

	# --- Les outils ---------------------------------------------------------------------------------

	func h(x: float, z: float) -> float:
		return commune.hauteur(x, z) if commune.has_method("hauteur") else 0.0

	func mat(c: Color, rugueux := 0.9) -> StandardMaterial3D:
		var k := c.to_html() + str(rugueux)
		if not mats.has(k):
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.roughness = rugueux
			mats[k] = m
		return mats[k]

	func boite(parent: Node3D, taille: Vector3, p: Vector3, c: Color, lacet := 0.0) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = taille
		mi.mesh = bm
		mi.material_override = mat(c)
		mi.position = p
		mi.rotation.y = lacet
		parent.add_child(mi)
		return mi

	func cyl(parent: Node3D, r0: float, r1: float, haut: float, p: Vector3, c: Color, cotes := 12) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.bottom_radius = r0
		cm.top_radius = r1
		cm.height = haut
		cm.radial_segments = cotes
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = mat(c)
		mi.position = p
		parent.add_child(mi)
		return mi

	func pose(id: String, cle: String, valeur: String, p: Vector3, g: int, opt := {}, lacet := 0.0, parent: Node3D = null) -> Node3D:
		var n: Node3D = load(Bibliotheque.scene(id, "decor")).instantiate()
		n.set(cle, valeur)
		n.graine = g
		n.options = opt
		n.position = p
		n.rotation.y = lacet
		(parent if parent != null else racine).add_child(n)
		return n

	func sur(x: float, z: float) -> Vector3:
		return Vector3(x, h(x, z), z)

	## Un bloc de collision (un mur, un monument) dans le corps du quartier.
	func solide(parent: Node3D, taille: Vector3, p: Vector3, lacet := 0.0) -> void:
		var corps := StaticBody3D.new()
		var forme := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		forme.shape = bs
		corps.add_child(forme)
		corps.position = p
		corps.rotation.y = lacet
		parent.add_child(corps)

	static func rive_sud(x: float) -> float:
		for k in RIVE_SUD.size() - 1:
			var a: Vector2 = RIVE_SUD[k]
			var b: Vector2 = RIVE_SUD[k + 1]
			if x >= a.x and x <= b.x:
				return lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
		return 188.0 if x < -432.0 else 280.0

	## Un bâtiment du relevé est au quartier s'il est sur la rive sud, à l'ouest de la Saône.
	static func au_quartier(c: Vector2) -> bool:
		if c.x > -60.0:
			return false
		return c.y > 255.0 or (c.x < -147.0 and c.y > rive_sud(c.x) + 3.0)

	static func dans_monument(c: Vector2) -> bool:
		for m in [EGLISE, GARE, LOGE]:
			var u := Vector2(cos(m[3]), sin(m[3]))
			var d: Vector2 = c - m[0]
			if absf(d.dot(u)) < m[1] * 0.5 and absf(d.dot(u.orthogonal())) < m[2] * 0.5:
				return true
		return Rect2(-268.0, 408.0, 38.0, 30.0).has_point(c)

	# --- Le relevé ----------------------------------------------------------------------------------

	func _choisir() -> void:
		for i in data.batiments.size():
			var b: Dictionary = data.batiments[i]
			var poly := PackedVector2Array()
			for q in b.p:
				poly.append(Vector2(q[0], q[1]) * U)
			emprises.append(poly)
			var c := Vector2(b.rect[0], b.rect[1]) * U
			if not au_quartier(c) or dans_monument(c):
				continue
			miens.append(i)
			var r := Rect2(poly[0], Vector2.ZERO)
			for q in poly:
				r = r.expand(q)
			for gx in range(floori(r.position.x / 10.0), floori(r.end.x / 10.0) + 1):
				for gz in range(floori(r.position.y / 10.0), floori(r.end.y / 10.0) + 1):
					var k := Vector2i(gx, gz)
					if not grille.has(k):
						grille[k] = []
					grille[k].append(i)
		for rt in data.routes:
			for k in rt.p.size() - 1:
				var sa := Vector2(rt.p[k][0], rt.p[k][1]) * U
				var sb := Vector2(rt.p[k + 1][0], rt.p[k + 1][1]) * U
				segments.append([sa, sb])
				var bo := Rect2(sa, Vector2.ZERO).expand(sb).grow(12.0)
				for gx in range(floori(bo.position.x / 20.0), floori(bo.end.x / 20.0) + 1):
					for gz in range(floori(bo.position.y / 20.0), floori(bo.end.y / 20.0) + 1):
						var cle := Vector2i(gx, gz)
						if not cases.has(cle):
							cases[cle] = []
						cases[cle].append(segments.size() - 1)

	func dans_qui(p: Vector2, sauf: int) -> int:
		for j in grille.get(Vector2i(floori(p.x / 10.0), floori(p.y / 10.0)), []):
			if j != sauf and Geometry2D.is_point_in_polygon(p, emprises[j]):
				return j
		return -1

	## La distance d'un point à la rue la plus proche.
	func ouverture(p: Vector2) -> float:
		var best := 1e9
		for j in cases.get(Vector2i(floori(p.x / 20.0), floori(p.y / 20.0)), []):
			var sg: Array = segments[j]
			best = minf(best, Geometry2D.get_closest_point_to_segment(p, sg[0], sg[1]).distance_to(p))
		return best if best < 1e8 else 12.0

	# --- Les places ---------------------------------------------------------------------------------

	## La dalle claire des places (Saint-Paul, le Change, Gerson), posée sur le pavé de la commune.
	func _places() -> void:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for s in data.sols:
			if s.k != "place" or str(s.get("nom", "")) == "Réservé SNCF":
				continue
			var poly := PackedVector2Array()
			for q in s.p:
				poly.append(Vector2(q[0], q[1]) * U)
			var c := Vector2.ZERO
			for q in poly:
				c += q
			c /= poly.size()
			if not au_quartier(c) or poly.size() < 3:
				continue
			var tri := Geometry2D.triangulate_polygon(poly)
			for k in range(0, tri.size(), 3):
				for j in [0, 2, 1]:
					var p := poly[tri[k + j]]
					st.set_color(DALLE)
					st.set_normal(Vector3.UP)
					st.add_vertex(Vector3(p.x, h(p.x, p.y) + 0.05, p.y))
		var mi := MeshInstance3D.new()
		mi.name = "Places"
		mi.mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.9
		mi.material_override = m
		racine.add_child(mi)

	# --- Le bâti ordinaire --------------------------------------------------------------------------

	func _batiments() -> void:
		var murs := SurfaceTool.new()
		murs.begin(Mesh.PRIMITIVE_TRIANGLES)
		var toits := SurfaceTool.new()
		toits.begin(Mesh.PRIMITIVE_TRIANGLES)
		var collisions := PackedVector3Array()
		var occ_v := PackedVector3Array()
		var occ_i := PackedInt32Array()
		# d'abord la hauteur réelle de chaque volume (celles des façades en relief l'emportent), pour que les murs
		# mitoyens se règlent sur le voisin tel qu'il est bâti
		var hauts := {}
		for i in miens:
			var b: Dictionary = data.batiments[i]
			var sol: float = b.sol * U - 0.5
			var haut: float = minf(b.h * U, 22.0) + 0.5
			var c0 := Vector2(b.rect[0], b.rect[1]) * U
			for z in RELIEF:
				if z.has_point(c0):
					haut = minf(haut, 17.0)
			haut = minf(haut, _plafond_juiverie(c0, emprises[i], sol))
			var en_relief := _reliefs(i, b, emprises[i])
			if not en_relief.is_empty():
				var hmax := 0.0
				for f in en_relief:
					hmax = maxf(hmax, f)
				haut = hmax - sol
			hauts[i] = haut
		for i in miens:
			var b: Dictionary = data.batiments[i]
			var poly: PackedVector2Array = emprises[i]
			var c := Vector2(b.rect[0], b.rect[1]) * U
			var sol: float = b.sol * U - 0.5
			var haut: float = hauts[i]
			var col := Color(_enduit(c, i))
			var baie := 3.1 + float((i * 37) % 7) * 0.1
			for k in poly.size():
				var a := poly[k]
				var bb := poly[(k + 1) % poly.size()]
				var long := a.distance_to(bb)
				var v := [Vector3(a.x, sol, a.y), Vector3(bb.x, sol, bb.y), Vector3(bb.x, sol + haut, bb.y), Vector3(a.x, sol + haut, a.y)]
				var nb := maxf(1.0, round(long / baie))
				var uv := [Vector2(0, 0), Vector2(nb, 0), Vector2(nb, haut), Vector2(0, haut)]
				var n := Vector3(bb.y - a.y, 0, -(bb.x - a.x)).normalized()
				var ordre := [0, 2, 1, 0, 3, 2]
				if Geometry2D.is_point_in_polygon((a + bb) * 0.5 + Vector2(n.x, n.z) * 0.3, poly):
					n = -n
					ordre = [0, 1, 2, 0, 2, 3]
				# un mur mitoyen ne se voit qu'au-dessus du voisin
				var voisin := dans_qui((a + bb) * 0.5 + Vector2(n.x, n.z) * 0.6, i)
				if voisin >= 0:
					var bv: Dictionary = data.batiments[voisin]
					var haut_voisin: float = bv.sol * U - 0.5 + hauts[voisin] if hauts.has(voisin) else bv.sol * U + minf(bv.h * U, 22.0)
					if sol + haut - haut_voisin < 1.0:
						continue
					for j in 2:
						v[j].y = haut_voisin
					uv[0].y = haut_voisin - sol
					uv[1].y = haut_voisin - sol
				if relief_pose.has(Vector2i(i, k)):
					for j in 4:
						v[j] -= n * 0.25
				var base := occ_v.size()
				occ_v.append_array(PackedVector3Array([v[0], v[1], v[2], v[3]]))
				occ_i.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
				for idx in ordre:
					murs.set_color(col)
					murs.set_normal(n)
					murs.set_uv(uv[idx])
					murs.set_uv2(Vector2(haut, float(i % 97)))
					murs.add_vertex(v[idx])
				collisions.append_array(PackedVector3Array([v[0], v[2], v[1], v[0], v[3], v[2]]))
			_toit(toits, b, poly, sol + haut, i)
		var mm := MeshInstance3D.new()
		mm.name = "Murs"
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		mm.mesh = murs.commit()
		mm.material_override = murs_mat
		racine.add_child(mm)
		var ecrans := ArrayOccluder3D.new()
		ecrans.set_arrays(occ_v, occ_i)
		var occ := OccluderInstance3D.new()
		occ.name = "Ecrans"
		occ.occluder = ecrans
		racine.add_child(occ)
		var mt := MeshInstance3D.new()
		mt.name = "Toits"
		mt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		mt.mesh = toits.commit()
		mt.material_override = toits_mat
		racine.add_child(mt)
		var corps := StaticBody3D.new()
		corps.name = "Murs_collision"
		var forme := CollisionShape3D.new()
		var cs := ConcavePolygonShape3D.new()
		cs.backface_collision = true
		cs.set_faces(collisions)
		forme.shape = cs
		corps.add_child(forme)
		racine.add_child(corps)

	## Rue Juiverie, la rangée ouest : la hauteur (au-dessus de son sol) que le soleil du soir laisse passer pour
	## n'allumer que le haut des façades d'en face, au-dessus de JUIVERIE_OMBRE (« le soir tombe par le haut ») ;
	## les maisons montées sur la pente de Fourvière, plus loin, ont d'autant plus de hauteur.
	func _plafond_juiverie(c: Vector2, poly: PackedVector2Array, sol: float) -> float:
		if c.x > -229.0 or c.y < 376.0 or c.y > 515.0:
			return INF
		var xe := -INF
		for q in poly:
			xe = maxf(xe, q.x)
		return h(JUIVERIE_EST, c.y) + JUIVERIE_OMBRE + maxf(JUIVERIE_EST - xe, 0.0) * tan(deg_to_rad(31.0)) - sol

	func _enduit(c: Vector2, i: int) -> String:
		# le quai, plus classique et plus pâle ; la ville Renaissance, ocre rouge
		if c.x > -140.0 or c.y < 250.0:
			return ENDUITS_QUAI[(i * 7 + 3) % ENDUITS_QUAI.size()]
		return ENDUITS[(i * 7 + 3) % ENDUITS.size()]

	## Les façades en relief : sur chaque mur tourné vers une rue, dans les rues du parcours, des maisons du
	## façadier de 5 à 10 m, peu profondes ; le volume fait le reste. Rend les corniches.
	func _reliefs(i: int, b: Dictionary, poly: PackedVector2Array) -> Array:
		var c := Vector2(b.rect[0], b.rect[1]) * U
		var dedans := false
		for z in RELIEF:
			if z.has_point(c):
				dedans = true
		if not dedans or b.h * U < 6.0:
			return []
		# le Vieux-Lyon : quatre ou cinq niveaux, toits bas
		var niveaux := clampi(int(round((minf(b.h * U, 22.0) - 4.2) / 3.3)), 2, 4)
		var plafond: float = b.sol * U - 0.5 + _plafond_juiverie(c, poly, b.sol * U - 0.5)
		var corniches := []
		for k in poly.size():
			var a := poly[k]
			var bb := poly[(k + 1) % poly.size()]
			var long := a.distance_to(bb)
			if long < 4.5:
				continue
			var u := (bb - a) / long
			var n := Vector2(u.y, -u.x)
			var milieu := (a + bb) * 0.5
			if Geometry2D.is_point_in_polygon(milieu + n * 0.4, poly):
				n = -n
			# une façade loin de toute voie ne se voit pas, sauf sur les places, où l'axe de la voie passe au milieu
			var portee := 16.0 if (PLACE_CHANGE.has_point(milieu) or PLACE_SAINT_PAUL.has_point(milieu)) else 6.0
			if dans_qui(milieu + n * 0.6, i) >= 0 or ouverture(milieu + n * 3.0) > portee:
				continue
			relief_pose[Vector2i(i, k)] = true
			var nb := maxi(1, int(round(long / 8.0)))
			var w := long / nb
			for j in nb:
				var q := a + u * w * (j + 0.5) + n * 0.02
				var r := (i * 5 + k * 3 + j) % 6
				var type: String = "etroite" if w < 6.5 else ["immeuble", "classique", "immeuble", "traboule", "classique", "immeuble"][r]
				var quai := c.x > -140.0 and c.y < 495.0
				var y := h(q.x, q.y) - 0.05
				var nf := niveaux
				if plafond < INF:
					nf = mini(niveaux, floori((plafond - y - 4.2) / 3.3))
					if nf < 1:
						continue
				var opt := {"w": w - 0.04, "d": 3.0, "niveaux": nf + (1 if quai else 0), "tuile": TUILES[(i + j) % TUILES.size()],
					"grain": 1.0, "souches": "grosses", "fleurs": (i + j) % 3 == 0, "store": false, "vigne": false, "lod": "loin"}
				if quai:
					# le quai de Bondy : des immeubles classiques, plus pâles, à persiennes
					opt.merge({"pente": 22.0, "persiennes": true, "balcons": false, "rdc": "boutique" if (i + k + j) % 2 == 0 else "pierre",
						"enduit": ENDUITS_QUAI[(i + k + j) % ENDUITS_QUAI.size()]})
				else:
					# la ville Renaissance : la façade du Vieux-Lyon de la bibliothèque, enduit tiré par la graine
					opt["renaissance"] = true
					opt["rdc"] = ["boutique", "logis", "boutique", "arcades", "logis", "passage"][(i * 3 + k + j) % 6]
					if type == "traboule":
						type = "classique"
				if not cafe_pose and q.distance_to(CAFE) < 9.0 and w > 6.0:
					# le café de courses, en face de la gare : sa devanture verte, son store, son enseigne
					cafe_pose = true
					type = "cafe"
					opt.merge({"enseigne": "LE DÉPART", "store": true, "toile": ["2f5a3a", "f3ead6"], "avancee": 2.2, "rdc": "cafe"}, true)
					cafe_au = [q, n]
				var m: Node3D = load(Bibliotheque.scene(FACADIER, "decor")).instantiate()
				modules.append(m)
				facades.append([q, n, w, m])
				m.type = type
				m.graine = i * 31 + k * 7 + j
				m.options = opt
				m.position = Vector3(q.x, y, q.y)
				m.rotation.y = atan2(n.x, n.y)
				racine.add_child(m)
				corniches.append(y + 4.2 + float(opt.niveaux) * 3.3)
		return corniches

	## Le toit du volume : deux pans de tuile canal à faible pente sur un plan rectangulaire, sinon un rampant
	## sur le pourtour et un terrasson.
	func _toit(st: SurfaceTool, b: Dictionary, poly: PackedVector2Array, haut: float, i: int) -> void:
		var tuile := Color(TUILES[i % TUILES.size()])
		var rc: Array = b.rect
		if b.rempli >= 0.8 and b.toit != "plat":
			var c := Vector2(rc[0], rc[1]) * U
			var lu: float = rc[2] * U * 0.5 + 0.3
			var lv: float = rc[3] * U * 0.5 + 0.3
			var pente := clampf(lv * 0.4, 1.0, 3.0)
			var u := Vector2(cos(rc[4]), sin(rc[4]))
			var v := Vector2(-u.y, u.x)
			var coins := [c - u * lu - v * lv, c + u * lu - v * lv, c + u * lu + v * lv, c - u * lu + v * lv]
			# un rectangle mal tourné ferait déborder le toit au-dessus de la rue : on s'en tient alors au terrasson
			var juste := true
			for q in coins:
				if not Geometry2D.is_point_in_polygon(q + (c - q).normalized() * 1.8, poly):
					juste = false
			if not juste:
				_terrasson(st, poly, haut, tuile)
				return
			var A := Vector3(coins[0].x, haut, coins[0].y)
			var B := Vector3(coins[1].x, haut, coins[1].y)
			var C := Vector3(coins[2].x, haut, coins[2].y)
			var D := Vector3(coins[3].x, haut, coins[3].y)
			var f0 := c - u * lu
			var f1 := c + u * lu
			var E := Vector3(f0.x, haut + pente, f0.y)
			var F := Vector3(f1.x, haut + pente, f1.y)
			for tri in [[A, F, B], [A, E, F], [D, C, F], [D, F, E], [A, D, E], [B, F, C]]:
				var n: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0]).normalized()
				if n.y < 0.0:
					tri = [tri[0], tri[2], tri[1]]
					n = -n
				for p in tri:
					st.set_color(tuile.darkened(0.15) if absf(n.y) < 0.2 else tuile)
					st.set_normal(n)
					st.add_vertex(p)
			return
		_terrasson(st, poly, haut, tuile)

	func _terrasson(st: SurfaceTool, poly: PackedVector2Array, haut: float, tuile: Color) -> void:
		var tri := Geometry2D.triangulate_polygon(poly)
		for k in range(0, tri.size(), 3):
			for j in [0, 2, 1]:
				var p := poly[tri[k + j]]
				st.set_color(tuile.darkened(0.06))
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(p.x, haut + 0.4, p.y))

	## Le relief des façades ne se lit que de près : au-delà de RELIEF_PORTEE, les modules s'effacent en fondu
	## devant le volume peint, comme à Sathonay.
	func _relief_de_pres() -> void:
		for m in modules:
			var pile: Array[Node] = [m]
			while not pile.is_empty():
				var n: Node = pile.pop_back()
				pile.append_array(n.get_children())
				# le corps lointain (« lod »: « loin ») reste hors de vue en jeu : c'est l'imposteur de la version légère
				if n is GeometryInstance3D and not n.has_meta("corps_lointain"):
					var g := n as GeometryInstance3D
					g.visibility_range_end = RELIEF_PORTEE / U
					g.visibility_range_end_margin = 10.0 / U
					g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	# --- Les monuments ------------------------------------------------------------------------------

	## Un nœud de monument posé au sol en c, tourné de ang (le +x local le long du grand côté).
	func _monument(nom: String, c: Vector2, ang: float, y: float) -> Node3D:
		var m := Node3D.new()
		m.name = nom
		m.position = Vector3(c.x, y, c.y)
		m.rotation.y = -ang
		racine.add_child(m)
		return m

	## L'église Saint-Paul : la nef et ses bas-côtés, le chevet roman vers la Saône (nord-est), la tour-lanterne
	## octogonale sur la croisée, le clocher à flèche sur la façade, au sud-ouest.
	func _eglise() -> void:
		var c: Vector2 = EGLISE[0]
		var L: float = EGLISE[1]
		var W: float = EGLISE[2]
		var y := h(c.x, c.y) - 0.3
		var e := _monument("EgliseSaintPaul", c, EGLISE[3], y)
		var pierre := Color("#c7b48e")
		# le +x local va vers le sud-ouest (la façade), -x vers le chevet
		boite(e, Vector3(L - 8.0, 17.0, 12.0), Vector3(-1.0, 8.5, 0), pierre)
		for s in [-1.0, 1.0]:
			boite(e, Vector3(L - 14.0, 9.0, 7.5), Vector3(2.0, 4.5, s * 9.7), pierre.darkened(0.04))
		# le transept et le chevet en hémicycle
		boite(e, Vector3(9.0, 15.0, W), Vector3(-12.0, 7.5, 0), pierre)
		var abside := cyl(e, 6.0, 6.0, 13.0, Vector3(-L * 0.5 + 4.0, 6.5, 0), pierre, 16)
		abside.scale = Vector3(1.0, 1.0, 1.0)
		var toit := Color("#b0452a")
		var faite := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(12.4, 3.0, L - 8.0)
		faite.mesh = pm
		faite.material_override = mat(toit)
		faite.position = Vector3(-1.0, 18.5, 0)
		faite.rotation.y = PI * 0.5
		e.add_child(faite)
		# la tour-lanterne : un socle carré, deux étages d'arcatures en octogone, un toit bas
		var croisee := Vector3(-12.0, 0, 0)
		boite(e, Vector3(10.0, 5.0, 10.0), croisee + Vector3(0, 17.5, 0), pierre.darkened(0.05))
		cyl(e, 5.6, 5.6, 6.5, croisee + Vector3(0, 23.2, 0), pierre.lightened(0.06), 8)
		cyl(e, 5.0, 5.0, 5.5, croisee + Vector3(0, 29.2, 0), pierre.lightened(0.1), 8)
		for k in 8:
			var a := TAU * (k + 0.5) / 8.0
			for et in [[5.62, 23.0, 3.6], [5.02, 29.0, 3.0]]:
				var baie := boite(e, Vector3(1.4, et[2], 0.3), croisee + Vector3(cos(a) * et[0], et[1], sin(a) * et[0]), Color("#3a3530"))
				baie.rotation.y = -a + PI * 0.5
		# les corniches qui séparent les deux étages, et les colonnettes aux angles de l'octogone
		for yc in [19.95, 26.6, 32.0]:
			cyl(e, 5.95 if yc < 30.0 else 5.3, 5.95 if yc < 30.0 else 5.3, 0.35, croisee + Vector3(0, yc, 0), pierre.darkened(0.12), 8)
		for k in 8:
			var a := TAU * k / 8.0
			cyl(e, 0.2, 0.2, 6.0, croisee + Vector3(cos(a) * 5.75, 23.2, sin(a) * 5.75), pierre.lightened(0.15), 6)
			cyl(e, 0.18, 0.18, 5.0, croisee + Vector3(cos(a) * 5.15, 29.2, sin(a) * 5.15), pierre.lightened(0.15), 6)
		cyl(e, 5.6, 0.6, 3.5, croisee + Vector3(0, 33.7, 0), toit, 8)
		# le toit en cul-de-four de l'abside et ceux des bras du transept
		cyl(e, 6.3, 0.4, 3.0, Vector3(-L * 0.5 + 4.0, 14.5, 0), toit, 16)
		var tr := MeshInstance3D.new()
		var tm := PrismMesh.new()
		tm.size = Vector3(9.4, 2.6, W)
		tr.mesh = tm
		tr.material_override = mat(toit)
		tr.position = Vector3(-12.0, 16.3, 0)
		e.add_child(tr)
		# le clocher à flèche, sur la façade
		var cl := Vector3(L * 0.5 - 4.0, 0, -6.5)
		boite(e, Vector3(7.0, 26.0, 7.0), cl + Vector3(0, 13.0, 0), pierre)
		cyl(e, 4.6, 0.25, 20.0, cl + Vector3(0, 36.0, 0), Color("#7d7a72"), 8)
		# l'horloge de 1676 sur le clocher, côté place Gerson
		var cad := cyl(e, 1.1, 1.1, 0.15, cl + Vector3(0, 21.0, -3.6), Color("#efe6cf"), 20)
		cad.rotation.x = PI * 0.5
		solide(e, Vector3(L, 18.0, W), Vector3(0, 9.0, 0))

	## La gare Saint-Paul : la façade de pierre sur la place, deux niveaux, le pavillon central et son horloge.
	func _gare() -> void:
		var c: Vector2 = GARE[0]
		var y := h(c.x + 17.0, c.y) - 0.2
		var g := _monument("GareSaintPaul", c, GARE[3], y)
		var pierre := Color("#d2c3a2")
		# la halle derrière, plus basse et plus sombre, adossée à la colline
		boite(g, Vector3(GARE[1] - 6.0, 13.0, GARE[2]), Vector3(-3.0, 6.5, 0), Color("#b9a98c"))
		boite(g, Vector3(6.0, 11.0, GARE[2]), Vector3(GARE[1] * 0.5 - 3.0, 5.5, 0), pierre)
		boite(g, Vector3(7.0, 16.0, 12.0), Vector3(GARE[1] * 0.5 - 3.5, 8.0, 0), pierre.lightened(0.05))
		# la grande baie cintrée sous l'horloge et le cadran, de 2,5 m
		boite(g, Vector3(0.3, 6.5, 6.0), Vector3(GARE[1] * 0.5 + 0.02, 4.0, 0), Color("#3b4450"))
		var cadran := cyl(g, 1.25, 1.25, 0.2, Vector3(GARE[1] * 0.5 + 0.05, 12.6, 0), Color("#f2ecdc"), 24)
		cadran.rotation.z = PI * 0.5
		var cercle := cyl(g, 1.45, 1.45, 0.12, Vector3(GARE[1] * 0.5 + 0.01, 12.6, 0), Color("#3a3328"), 24)
		cercle.rotation.z = PI * 0.5
		# les aiguilles, à sept heures dix : l'heure des trains du soir
		for ag in [[TAU * 7.17 / 12.0, 0.75, 0.16], [TAU * 10.0 / 60.0, 1.05, 0.1]]:
			var dirz := Vector3(0, cos(ag[0]), -sin(ag[0]))
			var aig := boite(g, Vector3(0.06, ag[1], ag[2]), Vector3(GARE[1] * 0.5 + 0.2, 12.6, 0) + dirz * ag[1] * 0.45, Color("#1e1c1a"))
			aig.rotation.x = -ag[0]
		for k in 12:
			var a := TAU * k / 12.0
			boite(g, Vector3(0.05, 0.22, 0.07), Vector3(GARE[1] * 0.5 + 0.17, 12.6 + cos(a) * 1.05, -sin(a) * 1.05), Color("#1e1c1a")).rotation.x = -a
		for s in [-1.0, 1.0]:
			for k in 4:
				boite(g, Vector3(0.2, 2.6, 1.4), Vector3(GARE[1] * 0.5 + 0.02, 2.4, s * (8.0 + k * 3.0)), Color("#3b4450"))
				boite(g, Vector3(0.2, 2.0, 1.2), Vector3(GARE[1] * 0.5 + 0.02, 7.4, s * (8.0 + k * 3.0)), Color("#3b4450"))
		# les bandeaux et la corniche de pierre, les pilastres, le fronton qui porte l'horloge, le toit d'ardoise
		var fx: float = GARE[1] * 0.5
		for yb in [5.2, 10.8]:
			boite(g, Vector3(0.5, 0.4, GARE[2]), Vector3(fx + 0.15, yb, 0), pierre.lightened(0.08))
		boite(g, Vector3(0.8, 0.6, 12.6), Vector3(fx - 0.2, 15.6, 0), pierre.lightened(0.1))
		for k in 13:
			var z: float = -GARE[2] * 0.5 + 0.8 + (GARE[2] - 1.6) * k / 12.0
			if absf(z) > 6.5:
				boite(g, Vector3(0.3, 10.6, 0.6), Vector3(fx + 0.1, 5.4, z), pierre.lightened(0.04))
		var fronton := MeshInstance3D.new()
		var fm := PrismMesh.new()
		fm.size = Vector3(12.6, 2.4, 0.8)
		fronton.mesh = fm
		fronton.material_override = mat(pierre.lightened(0.06))
		fronton.position = Vector3(fx - 0.2, 17.1, 0)
		fronton.rotation.y = PI * 0.5
		g.add_child(fronton)
		boite(g, Vector3(GARE[1] - 8.0, 2.2, GARE[2] - 1.0), Vector3(-4.0, 14.0, 0), Color("#5d6268"))
		solide(g, Vector3(GARE[1], 16.0, GARE[2]), Vector3(0, 8.0, 0))

	## L'hôtel Bullioud : la façade sur la rue Juiverie percée d'un porche, la cour, et au fond la galerie de
	## Philibert Delorme, portée par ses deux trompes au-dessus de la cour.
	func _bullioud() -> void:
		var cour := BULLIOUD_COUR
		var y := h(BULLIOUD_RUE - 2.0, cour.get_center().y)
		var b := Node3D.new()
		b.name = "HotelBullioud"
		racine.add_child(b)
		var enduit := Color("#c98a62")
		var haut := 17.4
		# les deux ailes sur la rue, de part et d'autre du porche, et les ailes autour de la cour
		var x_rue := BULLIOUD_RUE
		for bloc in [Rect2(cour.end.x, 412.0, x_rue - 2.9 - cour.end.x, cour.position.y - 412.0 + 7.2),
				Rect2(cour.end.x, cour.position.y + 9.8, x_rue - 2.9 - cour.end.x, cour.end.y - cour.position.y - 9.8 + 7.0),
				Rect2(-268.0, 406.0, cour.position.x + 268.0, 32.0),
				Rect2(cour.position.x, 406.0, cour.size.x, cour.position.y - 406.0),
				Rect2(cour.position.x, cour.end.y, cour.size.x, 438.0 - cour.end.y)]:
			if bloc.size.x <= 0.1 or bloc.size.y <= 0.1:
				continue
			boite(b, Vector3(bloc.size.x, haut, bloc.size.y), Vector3(bloc.get_center().x, y + haut * 0.5, bloc.get_center().y), enduit)
			solide(b, Vector3(bloc.size.x, haut, bloc.size.y), Vector3(bloc.get_center().x, y + haut * 0.5, bloc.get_center().y))
		# la façade sur la rue : quatre travées Renaissance, deux de chaque côté du porche ; au nord de z = 412, la
		# rue s'élargit devant la maison voisine, qui recule
		for t in [[412.0, cour.position.y + 7.2], [cour.position.y + 9.8, 438.0]]:
			var l: float = t[1] - t[0]
			for k in 2:
				var zc: float = t[0] + l * (k + 0.5) / 2.0
				var m: Node3D = load(Bibliotheque.scene(FACADIER, "decor")).instantiate()
				m.type = "classique"
				m.graine = 8 + k * 3 + int(t[0])
				m.options = {"w": l / 2.0 - 0.04, "d": 3.0, "niveaux": 3, "renaissance": true, "enduit": "c98a62" if k == 0 else "d4a074",
					"rdc": "logis", "tuile": TUILES[k], "store": false, "fleurs": k == 1, "lod": "loin"}
				m.position = Vector3(x_rue + 0.02, h(x_rue + 1.0, zc) - 0.05, zc)
				m.rotation.y = PI * 0.5
				b.add_child(m)
				modules.append(m)
		# le passage du porche, de la rue à la cour, voûté
		var z_porche := cour.position.y + 8.5
		boite(b, Vector3(x_rue - cour.end.x, 0.6, 2.6), Vector3((x_rue + cour.end.x) * 0.5, y + 4.3, z_porche), PIERRE.darkened(0.2))
		boite(b, Vector3(x_rue - cour.end.x, haut - 4.6, 2.6), Vector3((x_rue + cour.end.x) * 0.5, y + 4.6 + (haut - 4.6) * 0.5, z_porche), enduit)
		# la galerie de Delorme, au fond de la cour, contre l'aile ouest : deux arcades à l'étage, sur deux trompes
		var gx := cour.position.x + 1.4
		var gz0 := cour.position.y + 3.0
		var gz1 := cour.end.y - 3.0
		var gal := Node3D.new()
		gal.name = "GalerieDelorme"
		b.add_child(gal)
		var pierre := Color("#cbbd9c")
		boite(gal, Vector3(2.8, 3.6, gz1 - gz0), Vector3(gx, y + 7.6, (gz0 + gz1) * 0.5), pierre)
		for k in 2:
			var zc := lerpf(gz0, gz1, (k + 0.5) / 2.0)
			boite(gal, Vector3(0.2, 2.4, 2.6), Vector3(gx + 1.41, y + 7.4, zc), Color("#2f2a25"))
		boite(gal, Vector3(3.2, 0.5, gz1 - gz0 + 0.4), Vector3(gx, y + 9.6, (gz0 + gz1) * 0.5), pierre.lightened(0.08))
		for z in [gz0, gz1]:
			var t := cyl(gal, 1.6, 0.1, 2.4, Vector3(gx, y + 4.6, z), pierre.darkened(0.06), 10)
			t.rotation.x = PI
		# la tour d'escalier dans l'angle de la cour
		cyl(b, 1.9, 1.9, haut + 2.0, Vector3(cour.end.x - 2.0, y + (haut + 2.0) * 0.5, cour.end.y - 2.0), enduit.darkened(0.05), 8)

	## La Loge du Change : cinq arcades au rez-de-chaussée, l'étage de Soufflot à colonnes, la balustrade et les
	## deux cadrans ; elle regarde l'est, la place.
	func _loge() -> void:
		var c: Vector2 = LOGE[0]
		var y := h(c.x + 12.0, c.y) - 0.1
		var l := _monument("LogeDuChange", c, LOGE[3], y)
		var pierre := Color("#d8c9a6")
		var Lx: float = LOGE[1]
		var Wz: float = LOGE[2]
		boite(l, Vector3(Lx, 15.6, Wz), Vector3(0, 7.8, 0), pierre.darkened(0.04))
		var fx := Lx * 0.5
		var sombre := Color("#2a2622")
		var claire := pierre.lightened(0.1)
		var pas := Wz / 5.0
		# le soubassement : cinq arcades en plein cintre entre des piles à refends, la clé de chaque arc
		for k in 6:
			var z := -Wz * 0.5 + pas * k
			boite(l, Vector3(0.6, 6.4, 1.2), Vector3(fx + 0.3, 3.2, z), claire)
			for r in 4:
				boite(l, Vector3(0.66, 0.08, 1.24), Vector3(fx + 0.3, 1.2 + r * 1.4, z), pierre.darkened(0.12))
		for k in 5:
			var z := -Wz * 0.5 + pas * (k + 0.5)
			var ouv := pas - 1.4
			# l'arc est peint en retrait des piles : le vide sombre devant, l'archivolte claire qui le borde
			boite(l, Vector3(0.08, 4.0, ouv), Vector3(fx + 0.05, 2.0, z), sombre)
			var arc := cyl(l, ouv * 0.5, ouv * 0.5, 0.08, Vector3(fx + 0.05, 4.0, z), sombre, 16)
			arc.rotation.z = PI * 0.5
			var archivolte := cyl(l, ouv * 0.5 + 0.3, ouv * 0.5 + 0.3, 0.06, Vector3(fx + 0.02, 4.0, z), claire, 16)
			archivolte.rotation.z = PI * 0.5
			boite(l, Vector3(0.5, 0.7, 0.5), Vector3(fx + 0.3, 4.0 + ouv * 0.5 + 0.1, z), claire.lightened(0.05))
		boite(l, Vector3(1.0, 0.6, Wz + 0.4), Vector3(fx + 0.4, 6.7, 0), claire)
		# l'étage noble : six colonnes ioniques engagées sur un piédestal, cinq hautes fenêtres à fronton
		for k in 6:
			var z := -Wz * 0.5 + pas * k + (0.6 if k == 0 else (-0.6 if k == 5 else 0.0))
			boite(l, Vector3(1.1, 1.0, 1.3), Vector3(fx + 0.45, 7.5, z), claire)
			cyl(l, 0.42, 0.36, 5.0, Vector3(fx + 0.55, 10.5, z), claire.lightened(0.05), 12)
			boite(l, Vector3(1.0, 0.45, 1.2), Vector3(fx + 0.55, 13.2, z), claire)
		for k in 5:
			var z := -Wz * 0.5 + pas * (k + 0.5)
			boite(l, Vector3(0.3, 3.6, 1.7), Vector3(fx - 0.05, 10.3, z), Color("#2e3238"))
			boite(l, Vector3(0.35, 0.25, 2.3), Vector3(fx + 0.15, 8.4, z), claire)
			var fr := MeshInstance3D.new()
			var fpm := PrismMesh.new()
			fpm.size = Vector3(2.4, 0.6, 0.35)
			fr.mesh = fpm
			fr.material_override = mat(claire)
			fr.position = Vector3(fx + 0.15, 12.6, z)
			fr.rotation.y = PI * 0.5
			l.add_child(fr)
		# l'entablement, la balustrade, le toit bas d'ardoise ; les deux cadrans sur l'attique
		boite(l, Vector3(1.4, 1.1, Wz + 0.8), Vector3(fx + 0.5, 13.9, 0), claire)
		boite(l, Vector3(0.9, 0.3, Wz + 0.8), Vector3(fx + 0.6, 14.55, 0), claire.lightened(0.05))
		for k in 25:
			cyl(l, 0.13, 0.13, 0.9, Vector3(fx + 0.3, 15.15, -Wz * 0.5 + 0.5 + (Wz - 1.0) * k / 24.0), claire, 6)
		boite(l, Vector3(0.6, 0.25, Wz + 0.6), Vector3(fx + 0.3, 15.7, 0), claire)
		var toit := MeshInstance3D.new()
		var tpm := PrismMesh.new()
		tpm.size = Vector3(Lx - 1.0, 2.6, Wz - 1.0)
		toit.mesh = tpm
		toit.material_override = mat(Color("#5d6268"))
		toit.position = Vector3(0, 16.3, 0)
		toit.rotation.y = PI * 0.5
		l.add_child(toit)
		for s in [-1.0, 1.0]:
			var cad := cyl(l, 0.7, 0.7, 0.12, Vector3(fx + 0.62, 14.0, s * pas * 1.5), Color("#efe6cf"), 20)
			cad.rotation.z = PI * 0.5
		# les marches du parvis
		for k in 3:
			boite(l, Vector3(1.2 - 0.0, 0.18, Wz - 2.0 + k * 0.5), Vector3(fx + 0.6 + k * 0.4, 0.09 - k * 0.18 + 0.36, 0), VILLEBOIS)
		solide(l, Vector3(Lx, 15.0, Wz), Vector3(0, 7.5, 0))

	# --- Le quai, les arbres ------------------------------------------------------------------------

	## Le quai de Bondy, de la passerelle à la place du Change : le parapet le long de l'eau. Le mur de quai
	## qui tombe dans la Saône est celui de la commune (les quais de lyon.gd), quand elle le prolongera.
	func _quai() -> void:
		var polys: Array = []
		for e in data.eau:
			var poly := PackedVector2Array()
			for q in e.p:
				poly.append(Vector2(q[0], q[1]) * U)
			polys.append(poly)
		# la rive ouest de l'eau, de 4 m en 4 m : l'intersection la plus à l'ouest de chaque horizontale
		var rive: Array[Vector2] = []
		var z := 284.0
		while z < 598.0:
			var x_min := 1e9
			for poly in polys:
				for k in poly.size():
					var a: Vector2 = poly[k]
					var bb: Vector2 = poly[(k + 1) % poly.size()]
					if (a.y - z) * (bb.y - z) < 0.0:
						var x := lerpf(a.x, bb.x, (z - a.y) / (bb.y - a.y))
						if x > -140.0 and x < x_min:
							x_min = x
			if x_min < 1e8:
				rive.append(Vector2(x_min, z))
			z += 4.0
		for j in rive.size() - 1:
			var a := rive[j]
			var bb := rive[j + 1]
			var t := (bb - a).normalized()
			var dehors := Vector2(-t.y, t.x)
			if dehors.x < 0.0:
				dehors = -dehors
			var q := (a + bb) * 0.5 - dehors * 0.8
			pose(QUAIS, "module", "mur_quai_bas", sur(q.x, q.y), 900 + j, {"largeur": a.distance_to(bb) + 0.05}, atan2(dehors.x, dehors.y))

	func _arbres() -> void:
		var k := 0
		for a in data.arbres:
			var p := Vector2(a[0], a[1]) * U
			if not au_quartier(p) or p.x < -330.0:
				continue
			k += 1
			pose(OMBRIERE, "arbre", "jeune_platane", sur(p.x, p.y), 700 + k, {"hauteur": rng.randf_range(9.0, 12.0), "vent": 0.3, "lod": "loin"})
		# deux platanes sur la place Saint-Paul : au soleil du soir, leurs ombres traversent la place vers le quai
		for p in [Vector2(-208.0, 366.0), Vector2(-236.0, 344.0)]:
			k += 1
			pose(OMBRIERE, "arbre", "jeune_platane", sur(p.x, p.y), 700 + k, {"hauteur": 11.0, "vent": 0.3, "lod": "loin"})

	# --- La vie -------------------------------------------------------------------------------------

	## Les habitants, à l'échelle du jeu, et la situation du jour : le train du soir à Saint-Paul, une noce qui
	## sort de la Loge au Change ; la rue Juiverie presque vide.
	func _vie() -> void:
		var groupe := Node3D.new()
		groupe.name = "Habitants"
		groupe.scale = Vector3.ONE * U
		groupe.set_meta("sans_lointain", true)
		racine.add_child(groupe)
		# un compteur partagé : une fonction anonyme garde une copie de ses variables simples
		var g := [69005]
		var gens := func(p: Vector2, pose_: String, regard: Vector2, tenue := "village") -> void:
			var f: Node3D = Atelier.figurant(g[0], pose_, tenue)
			f.position = Vector3(p.x, h(p.x, p.y), p.y) / U
			f.rotation.y = atan2(p.x - regard.x, p.y - regard.y)
			groupe.add_child(f)
			g[0] += 1
		# la gare : des voyageurs devant la porte, un couple sous l'horloge, deux qui traversent avec leurs valises
		var porte := Vector2(-247.0, 352.0)
		for k in 5:
			var a := 0.6 + k * 0.5
			gens.call(porte + Vector2(cos(a) * (3.0 + k % 2), sin(a) * 4.0 - 2.0), "idle", porte + Vector2(12.0, 0.0))
		gens.call(Vector2(-244.5, 348.5), "idle", Vector2(-244.5, 351.0))
		gens.call(Vector2(-244.5, 350.0), "idle", Vector2(-244.5, 347.0))
		# la terrasse du café de courses
		if not cafe_au.is_empty():
			var q: Vector2 = cafe_au[0]
			var n: Vector2 = cafe_au[1]
			var t := q + n * 3.0
			pose(MOBILIER, "objet", "terrasse", sur(t.x, t.y), 31, {}, atan2(n.x, n.y))
			gens.call(t + n.orthogonal() * 1.6, "sit", t)
			gens.call(t - n.orthogonal() * 1.4 + n * 0.6, "sit", t)
			# l'ardoise des cotes sous le store, des tickets froissés par terre
			var ard := Label3D.new()
			ard.text = "COTES DU JOUR\n3e  Bel Ami  8/1\n5e  Rose de Vaise  12/1"
			ard.font_size = 30
			ard.pixel_size = 0.005
			ard.modulate = Color("#f2efe6")
			ard.outline_size = 0
			var fond := boite(racine, Vector3(1.1, 0.8, 0.04), Vector3(q.x + n.x * 0.12, h(q.x, q.y) + 1.5, q.y + n.y * 0.12), Color("#20241f"), atan2(n.x, n.y))
			ard.position = Vector3(0, 0, 0.03)
			fond.add_child(ard)
			for k in 7:
				var p := t + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
				var tk := boite(racine, Vector3(0.09, 0.005, 0.06), Vector3(p.x, h(p.x, p.y) + 0.07, p.y), Color("#e8e2cf"), rng.randf() * TAU)
				tk.rotation.x = rng.randf_range(-0.3, 0.3)
		# la noce sur le parvis de la Loge : les mariés, les invités en demi-cercle, le photographe, le riz
		# les mariés sur la plus haute marche, la famille étagée sur les marches de part et d'autre, des amis en
		# grappes au pied ; le photographe recule sur la place pour les prendre tous
		var marche := Vector2(LOGE[0].x + LOGE[1] * 0.5 + 0.9, LOGE[0].y)
		var parvis := marche + Vector2(3.0, 0.0)
		gens.call(marche + Vector2(0.0, -0.4), "idle", marche + Vector2(8.0, 0.6), "soiree")
		gens.call(marche + Vector2(0.0, 0.4), "idle", marche + Vector2(8.0, -0.6), "soiree")
		for k in 6:
			var cote := -1.0 if k % 2 == 0 else 1.0
			var rang := k / 2
			gens.call(marche + Vector2(0.5 * (rang % 2), cote * (1.6 + rang * 1.3)), "idle", marche + Vector2(8.0, 0.0), "soiree")
		for k in 7:
			var a := -1.1 + k * 0.37 + rng.randf_range(-0.1, 0.1)
			gens.call(marche + Vector2(cos(a) * (4.5 + (k % 3) * 0.9), sin(a) * (5.0 + (k % 2))), "idle", marche, "soiree")
		gens.call(marche + Vector2(9.0, 0.4), "idle", marche)
		var riz := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var qm := BoxMesh.new()
		qm.size = Vector3(0.05, 0.01, 0.05)
		mm.mesh = qm
		mm.instance_count = 160
		for k in 160:
			var p := parvis + Vector2(rng.randf_range(-2.0, 3.0), rng.randf_range(-3.5, 3.5))
			mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, h(p.x, p.y) + 0.07, p.y)))
		riz.multimesh = mm
		riz.material_override = mat(Color("#f4f0e6"))
		racine.add_child(riz)
		# les terrasses de l'est de la place, au soleil
		for k in 2:
			var p := Vector2(-141.5, 512.0 + k * 9.0)
			pose(MOBILIER, "objet", "terrasse", sur(p.x, p.y), 40 + k, {}, -PI * 0.5)
			gens.call(p + Vector2(0.0, 1.4), "sit", p)
		# rue Juiverie : personne dans la rue ; une visiteuse dans la cour de l'hôtel Bullioud, le nez levé vers la galerie
		gens.call(Vector2(BULLIOUD_COUR.position.x + 9.0, 422.0), "idle", Vector2(BULLIOUD_COUR.position.x, 424.0))
		var routes := [
			[Vector2(-206.0, 296.0), Vector2(-212.5, 306.0), Vector2(-214.0, 330.0)],
			[Vector2(-150.0, 560.0), Vector2(-153.0, 535.0), Vector2(-158.0, 516.0)],
			[Vector2(-232.0, 345.0), Vector2(-215.0, 350.0), Vector2(-206.0, 366.0)],
		]
		for r in routes:
			var route: Array[Vector3] = []
			for q in r:
				route.append(Vector3(q.x, h(q.x, q.y), q.y) / U)
			var f: Node3D = Atelier.figurant(g[0], "walk", "village", route)
			f.position = route[0]
			groupe.add_child(f)
			g[0] += 1
		_traces()

	## Les traces du fil rouge sur les façades du Change : une plaque et une enseigne sur la façade la plus proche.
	func _traces() -> void:
		for cle in TRACES:
			var cible: Vector2 = TRACES[cle]
			var best: Array = []
			var d := 1e9
			for f in facades:
				if f[0].distance_to(cible) < d:
					d = f[0].distance_to(cible)
					best = f
			if best.is_empty() or d > 25.0:
				continue
			var m: Node3D = best[3]
			var texte: String = {"banque": "CAISSE DE LA GRANDE-CÔTE\nCOMPTOIR DU CHANGE", "gages": "PRÊTS SUR GAGES\nACHAT · VENTE · DÉPÔT",
				"saisie": "FERMÉ POUR CAUSE DE SAISIE"}[cle]
			var fond := boite(m, Vector3(minf(best[2] - 1.0, 4.4), 0.7, 0.05), Vector3(0, 4.55, 0.12), Color("#1e2a24") if cle != "saisie" else Color("#efe9d8"))
			var l := Label3D.new()
			l.text = texte
			l.font_size = 40
			l.pixel_size = 0.0045
			l.modulate = Color("#d9b65a") if cle != "saisie" else Color("#7a1f1a")
			l.position = Vector3(0, 0, 0.03)
			fond.add_child(l)
			if cle == "gages":
				# la vitrine : une montre, une alliance, des clés, un saxophone
				for k in 4:
					var o := boite(m, Vector3(0.12 + k * 0.05, 0.12, 0.05), Vector3(-0.8 + k * 0.55, 1.3, 0.18), [Color("#d9b65a"), Color("#e8d27a"), Color("#9aa0a6"), Color("#c89b3c")][k])
					o.rotation.z = 0.3 * k
			if cle == "saisie":
				# l'enseigne repeinte au nom du créancier
				var e := Label3D.new()
				e.text = "MAISON VERNAY & FILS"
				e.font_size = 48
				e.pixel_size = 0.005
				e.modulate = Color("#2a2a28")
				e.position = Vector3(0, 3.7, 0.2)
				m.add_child(e)

	# --- Les repères et les sas ---------------------------------------------------------------------

	func _reperes() -> void:
		for nom in REPERES:
			var a: Vector2 = REPERES[nom][0]
			var b: Vector2 = REPERES[nom][1]
			var m := Marker3D.new()
			m.name = nom
			var p := Vector3(a.x, h(a.x, a.y) + 0.1, a.y)
			var cible := Vector3(b.x, p.y, b.y)
			m.transform = Transform3D(Basis.looking_at(cible - p, Vector3.UP), p)
			racine.add_child(m)
		for nom in SAS:
			var c: Vector2 = SAS[nom][0]
			var sas := Marker3D.new()
			sas.name = nom
			sas.set_meta("rayon", SAS[nom][1])
			sas.position = Vector3(c.x, h(c.x, c.y), c.y)
			racine.add_child(sas)
