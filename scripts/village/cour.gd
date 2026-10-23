extends RefCounted
## La cour derrière la rue du Clain : on passe sous la maison du porche (rangée nord, entre la maison
## basse et le local réservé) et l'on débouche dans une cour commune, que la rue cachait. Le revers des
## façades, l'escalier extérieur d'un logement, la grange au fond et sa porte charretière entrouverte, la
## remise où le boucher gare sa camionnette, le puits sous le tilleul, le linge, deux voisins qui
## écossent. Note d'intentions : communes/smarves/INTENTIONS.md (scène 1).

## L'étendue de la cour : entre le mur mitoyen de la boucherie et celui du local réservé, du revers des
## maisons au mur du fond de la maquette.
const X_EST := -21.0
const X_OUEST := -32.8
const Z_NORD := -8.0
const Z_SUD := 1.2
## La grange du fond, sa façade tournée vers la cour.
const GRANGE := Vector3(-27.6, 0, -5.1)
const GRANGE_W := 6.6
const GRANGE_D := 2.8
const PUITS := Vector3(-26.4, 0, -2.0)

const PIERRE := Color(0.84, 0.78, 0.66)
const BOIS := Color(0.42, 0.3, 0.2)
const BOIS_GRIS := Color(0.5, 0.48, 0.42)
const FER := Color(0.16, 0.17, 0.17)

var v: Node3D
var f: RefCounted
var KM: String


## Le porche, dans sa rangée : deux piédroits, une voûte en anse de panier, la maison par-dessus.
## Rend la profondeur du passage (la rangée en a besoin pour son mur mitoyen).
static func porche(village: Node3D, f: RefCounted, cx: float, w: float, front: float) -> float:
	var d := 3.2
	var pied := 0.3
	var ouv := w - 2.0 * pied
	var naissance := 0.92
	var fleche := 0.3
	var haut := 1.3
	var xf := Transform3D(Basis(), Vector3(cx, 0, front))
	var mur := Color(0.97, 0.92, 0.82)
	# La maison du porche, posée sur la voûte : un seul étage, au niveau de ceux des voisines.
	var maison := Transform3D(Basis(), Vector3(cx, haut, front))
	f.house(maison, {"w": w, "d": d, "floors": 1, "roof_kind": "gable", "lit": 0.8, "wall": mur, "chimney": false, "door": "center"})
	# Les piédroits, de pierre de taille, et leurs chasse-roues.
	for s in [-1.0, 1.0]:
		var px: float = s * (w / 2.0 - pied / 2.0)
		f.batch.box("wall", xf, Vector3(px, haut / 2.0, -d / 2.0), Vector3(pied, haut, d), mur)
		for z in [0.05, -d + 0.05]:
			f.batch.box("trim", xf, Vector3(px - s * (pied / 2.0 - 0.02), 0.6, z - 0.03), Vector3(0.05, 1.2, 0.08), mur.lightened(0.1))
			f.batch.cylinder("trim", xf, Vector3(px - s * (pied / 2.0 + 0.06), 0, z - 0.12), 0.08, 0.32, PIERRE.darkened(0.1), 8)
		village.main._solid_box(Vector3(pied, haut, d), xf * Vector3(px, haut / 2.0, -d / 2.0))
	# La voûte : le dessus de l'arc tranche par tranche (la douelle et les écoinçons d'un coup).
	var r := ((ouv / 2.0) * (ouv / 2.0) + fleche * fleche) / (2.0 * fleche)
	var cy := naissance + fleche - r
	var n := 12
	for i in n:
		var x0 := -ouv / 2.0 + ouv * i / n
		var x1 := -ouv / 2.0 + ouv * (i + 1) / n
		var xm := (x0 + x1) / 2.0
		var y_arc := cy + sqrt(maxf(0.0, r * r - xm * xm))
		f.batch.box("wall", xf, Vector3(xm, (y_arc + haut) / 2.0, -d / 2.0), Vector3(x1 - x0 + 0.01, haut - y_arc, d), mur.darkened(0.12))
	# Les claveaux, sur les deux faces, plus clairs, et la clé un peu plus grosse.
	var a0 := asin((ouv / 2.0) / r)
	var nv := 9
	for face in [0.02, -d - 0.02]:
		for i in nv:
			var a := -a0 + 2.0 * a0 * (i + 0.5) / nv
			var p := Vector3(sin(a) * (r + 0.1), cy + cos(a) * (r + 0.1), face)
			var cle := i == nv / 2
			var vxf := xf * Transform3D(Basis(Vector3.BACK, -a), p)
			f.batch.box("trim", vxf, Vector3.ZERO, Vector3(0.2 if not cle else 0.24, 0.22 if not cle else 0.28, 0.06), mur.lightened(0.08))
	# Le passage pavé, creusé au milieu par les roues, et la lanterne éteinte sous la voûte.
	village.main._box(Vector3(ouv, 0.05, d), xf * Vector3(0, 0.02, -d / 2.0), village.mats.slabs, village)
	f.batch.box("trim", xf, Vector3(0, 0.048, -d / 2.0), Vector3(ouv * 0.35, 0.01, d), Color(0.5, 0.47, 0.42))
	f.batch.box("trim", xf, Vector3(0, haut - 0.12, -d / 2.0), Vector3(0.12, 0.16, 0.12), Color(0.2, 0.2, 0.18))
	return d


func build(village: Node3D, rue: RefCounted) -> void:
	v = village
	f = rue
	KM = v.KK + "medieval_decoration/"
	_sol()
	_grange()
	_remise()
	_escalier_exterieur()
	_puits()
	_coin_des_voisins()
	_linge()
	_details()
	_figurants()


func _sol() -> void:
	var cx := (X_EST + X_OUEST) / 2.0
	var sx := absf(X_EST - X_OUEST) - 0.2
	var sz := Z_SUD - Z_NORD
	v.main._box(Vector3(sx, 0.04, sz), Vector3(cx, 0.015, (Z_NORD + Z_SUD) / 2.0), v.mats.gravel, v)
	# Une allée pavée du porche à la grange, et un rond de pavés autour du puits.
	var porche_x := -28.1
	v.main._box(Vector3(2.0, 0.05, Z_SUD - GRANGE.z), Vector3(porche_x, 0.02, (Z_SUD + GRANGE.z) / 2.0), v.mats.slabs, v)
	v.main._box(Vector3(2.0, 0.05, 2.0), PUITS + Vector3(0, 0.02, 0), v.mats.slabs, v)
	# L'herbe qui pousse le long des murs, là où personne ne marche.
	var xf := Transform3D()
	for z in [-7.7, -6.9]:
		f.batch.box("trim", xf, Vector3(X_OUEST + 0.5, 0.03, z), Vector3(0.6, 0.04, 0.6), Color(0.35, 0.45, 0.22))
	f.batch.box("trim", xf, Vector3(X_EST - 0.4, 0.03, -7.6), Vector3(0.5, 0.04, 0.5), Color(0.35, 0.45, 0.22))


## La grange du fond : moellon enduit à moitié tombé, tuile, porte charretière dont un battant est
## ouvert sur le foin et la charrette ; on comprend que derrière, il y a encore autre chose.
func _grange() -> void:
	var xf := Transform3D(Basis(), GRANGE)
	var mur := Color(0.86, 0.8, 0.68)
	var info: Dictionary = f.house(xf, {"w": GRANGE_W, "d": GRANGE_D, "floors": 1, "front": false, "back": false, "roof_kind": "gable",
		"wall": mur, "roof": Color(0.74, 0.4, 0.26), "chimney": false, "lit": 0.0, "dormer": false})
	var h: float = info.h
	# L'enduit tombé par plaques, qui montre le moellon dessous.
	var rng := f.rng as RandomNumberGenerator
	for i in 7:
		var px := rng.randf_range(-GRANGE_W / 2.0 + 0.4, GRANGE_W / 2.0 - 0.4)
		if absf(px) < 1.3:
			continue
		f.batch.box("trim", xf, Vector3(px, rng.randf_range(0.3, h - 0.3), 0.012), Vector3(rng.randf_range(0.3, 0.7), rng.randf_range(0.2, 0.4), 0.01), PIERRE.darkened(0.25))
	# La porte charretière : l'encadrement de pierre, le battant fermé, le battant ouvert.
	var pw := 2.0
	var ph := 1.18
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(s * (pw / 2.0 + 0.08), ph / 2.0, 0.03), Vector3(0.16, ph, 0.06), mur.lightened(0.1))
	f.batch.box("trim", xf, Vector3(0, ph + 0.08, 0.03), Vector3(pw + 0.32, 0.16, 0.06), mur.lightened(0.1))
	# Le noir de la grange, puis ce qu'on y devine : la meule de foin, la roue de charrette.
	f.batch.box("trim", xf, Vector3(0, ph / 2.0, -0.05), Vector3(pw, ph, 0.02), Color(0.07, 0.06, 0.05))
	f.batch.box("trim", xf, Vector3(-0.5, 0.35, -0.6), Vector3(0.9, 0.7, 0.8), Color(0.78, 0.66, 0.32))
	f.batch.cylinder("trim", xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.45, 0.42, -0.3)), Vector3.ZERO, 0.42, 0.06, Color(0.4, 0.28, 0.16), 12)
	var battant := Color(0.36, 0.42, 0.36)
	f.batch.box("trim", xf, Vector3(pw / 4.0, ph / 2.0, 0.0), Vector3(pw / 2.0 - 0.02, ph - 0.04, 0.05), battant)
	for k in 4:
		f.batch.box("trim", xf, Vector3(pw / 4.0 - pw / 4.0 + 0.12 + k * 0.24, ph / 2.0, 0.03), Vector3(0.02, ph - 0.1, 0.01), battant.darkened(0.25))
	var ouvert := xf * Transform3D(Basis(Vector3.UP, -1.05), Vector3(-pw / 2.0, 0, 0.02))
	f.batch.box("trim", ouvert, Vector3(pw / 4.0, ph / 2.0, 0.0), Vector3(pw / 2.0 - 0.02, ph - 0.04, 0.05), battant)
	# Une fenêtre à barreaux sur le côté, un œil-de-bœuf dans le pignon de l'est.
	f.batch.box("trim", xf, Vector3(GRANGE_W / 2.0 - 0.8, 0.85, 0.02), Vector3(0.36, 0.3, 0.02), Color(0.07, 0.06, 0.05))
	for k in 3:
		f.batch.box("trim", xf, Vector3(GRANGE_W / 2.0 - 0.92 + k * 0.12, 0.85, 0.03), Vector3(0.02, 0.3, 0.02), FER)
	# Le corps de la grange arrête l'habitant ; le battant ouvert aussi.
	v.main._solid_box(Vector3(GRANGE_W, h, GRANGE_D), GRANGE + Vector3(0, h / 2.0, -GRANGE_D / 2.0))
	v.main._solid_box(Vector3(0.1, ph, pw / 2.0), ouvert * Vector3(pw / 4.0, ph / 2.0, 0.0))


## La remise ouverte contre le mur de la boucherie : quatre poteaux, un toit à un pan, la camionnette.
func _remise() -> void:
	var x0 := X_EST - 0.15
	var x1 := X_EST - 2.7
	var z0 := -1.2
	var z1 := -4.6
	var xf := Transform3D()
	for x in [x1]:
		for z in [z0, (z0 + z1) / 2.0, z1]:
			f.batch.box("trim", xf, Vector3(x, 0.6, z), Vector3(0.12, 1.2, 0.12), BOIS)
	f.batch.box("trim", xf, Vector3(x1, 1.22, (z0 + z1) / 2.0), Vector3(0.14, 0.1, absf(z1 - z0) + 0.2), BOIS)
	f.batch.box("wall", xf, Vector3(x0 + 0.04, 0.8, (z0 + z1) / 2.0), Vector3(0.2, 1.6, absf(z1 - z0) + 0.2), PIERRE)
	f.batch.quad("roof", xf, [Vector3(x0 + 0.1, 1.62, z0 + 0.2), Vector3(x1 - 0.3, 1.24, z0 + 0.2), Vector3(x1 - 0.3, 1.24, z1 - 0.2), Vector3(x0 + 0.1, 1.62, z1 - 0.2)],
		Vector3(-0.15, 0.99, 0), Color(0.86, 0.52, 0.34), [Vector2(0, 0), Vector2(2.8, 0), Vector2(2.8, 3.8), Vector2(0, 3.8)])
	var cam: Node3D = v._car("delivery", Vector3((x0 + x1) / 2.0, 0.02, (z0 + z1) / 2.0 + 0.1), 180.0, 1.6)
	v.main._solid(cam)
	# Les cagettes et le billot du boucher, sous le toit.
	v._place(KM + "props/crate_A_small.gltf", Vector3(x0 - 0.35, 0, z1 + 0.35), 1.3, 10.0)
	v._place(KM + "props/crate_B_small.gltf", Vector3(x0 - 0.35, 0.3, z1 + 0.35), 1.2, 40.0)
	v._place(KM + "props/barrel.gltf", Vector3(x1 + 0.3, 0, z0 - 0.3), 1.6)


## Le logement au-dessus du local réservé a sa porte à l'étage, sur la cour : un escalier de pierre
## le long du mur, sa rampe de fer, un pot de géranium sur le palier.
func _escalier_exterieur() -> void:
	var lot: Dictionary = v.lots.get("lot_reserve", {})
	if lot.is_empty():
		return
	var dos: float = lot.pos.z - lot.d - 0.02
	var x_bas := X_OUEST + 3.0
	var marches := 9
	var montee := 1.45 / marches
	var giron := 0.24
	var large := 0.62
	var z := dos - large / 2.0
	var xf := Transform3D()
	for i in marches:
		var top := montee * (i + 1)
		var x := x_bas - giron * (i + 0.5)
		f.batch.box("wall", xf, Vector3(x, top / 2.0, z), Vector3(giron, top, large), PIERRE.darkened(0.04 * (i % 2)))
		f.batch.box("trim", xf, Vector3(x, top + 0.005, z), Vector3(giron + 0.02, 0.02, large + 0.02), PIERRE.lightened(0.1))
	var x_palier := x_bas - giron * marches - 0.35
	f.batch.box("wall", xf, Vector3(x_palier, 1.45 / 2.0, z), Vector3(0.7, 1.45, large), PIERRE.darkened(0.06))
	# La rampe, côté cour.
	var zr := z - large / 2.0 + 0.03
	f.batch.box_tilted("trim", Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3((x_bas + x_palier) / 2.0 + 0.1, 0.0, zr)), Vector3(0, 1.32, 0), Vector3(0.025, 0.025, giron * marches + 0.3), atan2(1.45, giron * marches), FER)
	for i in [0, 4, 8]:
		f.batch.box("trim", xf, Vector3(x_bas - giron * (i + 0.5), montee * (i + 1) + 0.25, zr), Vector3(0.02, 0.5, 0.02), FER)
	# La porte de l'étage, et son pot de fleurs.
	f.batch.box("trim", xf, Vector3(x_palier, 1.45 + 0.45, dos + 0.01), Vector3(0.5, 0.9, 0.04), Color(0.38, 0.55, 0.7))
	f.batch.box("trim", xf, Vector3(x_palier, 1.45 + 0.93, dos + 0.02), Vector3(0.6, 0.06, 0.06), PIERRE.lightened(0.1))
	v._place(v.KN + "pot_small.glb", Vector3(x_palier - 0.2, 1.45, z), 1.0)
	v.main._solid_box(Vector3(giron * marches + 0.7, 1.45, large), Vector3((x_bas + x_palier - 0.35) / 2.0, 0.72, z))


## Le puits sous le tilleul : margelle de pierre, potence de fer, seau.
func _puits() -> void:
	var xf := Transform3D(Basis(), PUITS)
	f.batch.cylinder("wall", xf, Vector3.ZERO, 0.42, 0.5, PIERRE, 12)
	f.batch.cylinder("trim", xf, Vector3(0, 0.5, 0), 0.46, 0.05, PIERRE.lightened(0.1), 12)
	f.batch.cylinder("trim", xf, Vector3(0, 0.52, 0), 0.3, 0.01, Color(0.04, 0.05, 0.06), 12)
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(s * 0.38, 0.95, 0), Vector3(0.04, 0.9, 0.04), FER)
	f.batch.box("trim", xf, Vector3(0, 1.38, 0), Vector3(0.84, 0.04, 0.04), FER)
	f.batch.cylinder("trim", xf * Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0.1, 1.38, 0)), Vector3.ZERO, 0.06, 0.2, Color(0.4, 0.3, 0.2), 8)
	f.batch.box("trim", xf, Vector3(0.0, 1.1, 0), Vector3(0.01, 0.5, 0.01), Color(0.5, 0.45, 0.35))
	v._place(KM + "props/bucket_water.gltf", PUITS + Vector3(0.0, 0.53, 0.25), 1.1)
	v.main._solid_box(Vector3(0.9, 1.0, 0.9), PUITS + Vector3(0, 0.5, 0))
	v._tree(PUITS + Vector3(-2.4, 0, -1.0), "tree_detailed_fall", 1.8)


## Deux voisins qui écossent des haricots sur une table de jardin, devant la maison basse.
func _coin_des_voisins() -> void:
	var at := Vector3(-24.6, 0, -0.9)
	var xf := Transform3D(Basis(), at)
	f.batch.box("trim", xf, Vector3(0, 0.36, 0), Vector3(0.9, 0.04, 0.55), Color(0.85, 0.82, 0.74))
	for sx in [-0.4, 0.4]:
		for sz in [-0.22, 0.22]:
			f.batch.box("trim", xf, Vector3(sx, 0.17, sz), Vector3(0.03, 0.34, 0.03), Color(0.2, 0.32, 0.25))
	# Les deux chaises de fer, la bassine, le tas de cosses.
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(s * 0.62, 0.22, 0), Vector3(0.3, 0.03, 0.3), Color(0.2, 0.32, 0.25))
		f.batch.box("trim", xf, Vector3(s * 0.78, 0.4, 0), Vector3(0.03, 0.35, 0.3), Color(0.2, 0.32, 0.25))
	f.batch.cylinder("trim", xf, Vector3(0.0, 0.38, 0), 0.16, 0.08, Color(0.75, 0.78, 0.8), 10)
	f.batch.box("trim", xf, Vector3(0.0, 0.43, 0), Vector3(0.2, 0.03, 0.2), Color(0.45, 0.62, 0.3))
	f.batch.box("trim", xf, Vector3(0.28, 0.4, 0.1), Vector3(0.22, 0.04, 0.14), Color(0.58, 0.7, 0.38))
	v.main._solid_box(Vector3(1.7, 0.5, 0.7), at + Vector3(0, 0.25, 0))


## Le linge entre le coin de la grange et un poteau : draps, torchons, une salopette bleue, un seul vent.
func _linge() -> void:
	var a := Vector3(GRANGE.x - GRANGE_W / 2.0 + 0.2, 1.15, GRANGE.z + 0.1)
	var b := Vector3(X_OUEST + 0.6, 1.15, -2.8)
	var xf := Transform3D()
	f.batch.box("trim", xf, Vector3(b.x, 0.6, b.z), Vector3(0.05, 1.2, 0.05), BOIS_GRIS)
	var dir := b - a
	var len := dir.length()
	var rot := Basis(Vector3.UP, atan2(dir.x, dir.z) - PI / 2.0)
	f.batch.box("trim", Transform3D(rot, (a + b) / 2.0), Vector3.ZERO, Vector3(len, 0.012, 0.012), Color(0.85, 0.85, 0.82))
	var pieces := [[0.55, 0.5, Color(0.96, 0.95, 0.9)], [0.25, 0.26, Color(0.9, 0.86, 0.72)], [0.3, 0.45, Color(0.28, 0.4, 0.65)], [0.55, 0.5, Color(0.93, 0.9, 0.86)]]
	var t := 0.12
	for p in pieces:
		var pw: float = p[0]
		var ph: float = p[1]
		var mid := a + dir * (t + pw / 2.0 / len)
		f.batch.box("trim", Transform3D(rot * Basis(Vector3.UP, 0.1), mid - Vector3(0, ph / 2.0, 0)), Vector3.ZERO, Vector3(pw, ph, 0.015), p[2])
		t += (pw + 0.1) / len


func _details() -> void:
	# Le bois coupé contre le pignon de la grange, la niche du chien, les géraniums aux portes.
	v._place(v.KN + "log_stack.glb", GRANGE + Vector3(GRANGE_W / 2.0 + 0.5, 0, -1.0), 1.0, 90.0)
	v._place(v.KN + "log_stack.glb", GRANGE + Vector3(GRANGE_W / 2.0 + 0.5, 0, -2.0), 1.0, 90.0)
	var niche := Transform3D(Basis(Vector3.UP, 0.4), Vector3(-31.6, 0, -6.6))
	f.batch.box("wall", niche, Vector3(0, 0.22, 0), Vector3(0.5, 0.44, 0.6), Color(0.58, 0.36, 0.22))
	f.batch.box("trim", niche, Vector3(0, 0.18, 0.301), Vector3(0.2, 0.26, 0.01), Color(0.05, 0.04, 0.03))
	for s in [-1.0, 1.0]:
		f.batch.box_tilted("roof", niche, Vector3(0, 0.52, s * 0.0), Vector3(0.6, 0.03, 0.7), 0.0, Color(0.48, 0.5, 0.52))
	for p in [Vector3(-25.0, 0, 0.6), Vector3(-22.0, 0, 0.4), Vector3(-30.0, 0, 0.5)]:
		v._place(v.KN + "pot_small.glb", p, 1.0)
	v._place(KM + "props/wheelbarrow.gltf", Vector3(-29.7, 0, -4.4), 1.3, 200.0)
	v._place(KM + "props/sack.gltf", GRANGE + Vector3(1.4, 0, 0.35), 1.3)
	v._place(KM + "props/sack.gltf", GRANGE + Vector3(1.75, 0, 0.3), 1.2, 50.0)


func _figurants() -> void:
	v.main._villager("ecosseur-de-la-cour", Vector3(-25.22, 0.07, -0.9), 90.0, "sit")
	v.main._villager("ecosseuse-de-la-cour", Vector3(-23.98, 0.07, -0.9), -90.0, "sit")
	v.main._villager("voisine-de-la-cour", Vector3(-31.0, 0.06, -3.4), 180.0, "idle",
		[Vector3(-31.0, 0.06, -3.4), Vector3(-29.4, 0.06, -0.2)])
	v.main._villager("boucher-a-la-remise", Vector3(-22.4, 0.06, -0.6), 180.0)
