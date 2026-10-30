extends RefCounted
## Le banc d'Au Replat, sur la colline de Parves (scène 2 de la note) : un banc de bois sous un chêne, la terre
## usée devant lui par ceux qui s'y arrêtent, sa plaque « À Raymond, qui voyait loin » ; le chemin de terre qui y
## monte, les herbes hautes et les fleurs du pré, deux bosquets qui cadrent la vue ; derrière soi, la maison à
## vendre. Devant : toute la vallée, le Rhône en contrebas, la crête du Chat en face.
## Repère : Vue2_Banc (belley.gd), là où l'on s'assied ; le banc regarde son lacet.
##   BANC.new(hauteur).batir(parent, x, z, lacet)

const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const FACADIER := preload("res://bibliotheque/facadier-du-bugey/1/facadier.gd")
const REPEINDRE := preload("res://communes/belley/atelier/repeindre.gd")

const TERRE := Color("9c8463", 0.95)
const TERRE_USEE := Color("7d6446", 0.95)
const PLAQUE := Color("b08d4a", 0.3)
## Le banc, à quelques pas devant le repère : on le voit de dos, avec la vallée au-dessus du dossier.
const BANC_AV := 3.2

var hauteur: Callable
var centre := Vector2.ZERO
## Le devant (ce que regarde le banc) et la droite, au sol.
var devant := Vector2.UP
var droite := Vector2.RIGHT


func _init(sol: Callable) -> void:
	hauteur = sol


## Un point à av mètres devant le repère et dr à sa droite, posé sur le sol, relevé de dy.
func _p(av: float, dr: float, dy := 0.0) -> Vector3:
	var v := centre + devant * av + droite * dr
	return Vector3(v.x, hauteur.call(v.x, v.y) + dy, v.y)


func batir(parent: Node3D, x: float, z: float, lacet_deg: float) -> void:
	centre = Vector2(x, z)
	var l := deg_to_rad(lacet_deg)
	devant = Vector2(sin(l), -cos(l))
	droite = Vector2(cos(l), sin(l))
	var n := Node3D.new()
	n.name = "BancAuReplat"
	parent.add_child(n)
	var lacet_noeud := -l
	var o := OUTILS.new(1572)
	# La terre usée devant et sous le banc, et le chemin de terre qui monte de la route, par la gauche.
	var chemin := PackedVector2Array()
	for k in 16:
		chemin.append(Vector2(0.6 - k * 1.9, -2.2 - k * 0.9 + sin(k * 0.7) * 0.8))
	var av1 := -32.0
	while av1 < 6.0:
		var dr1 := -18.0
		while dr1 < 3.0:
			var cs := []
			var garde := false
			for cn: Vector2 in [Vector2(0, 0), Vector2(0.5, 0), Vector2(0.5, 0.5), Vector2(0, 0.5)]:
				var a := av1 + cn.x
				var b := dr1 + cn.y
				var k := _terre(a, b, chemin)
				garde = garde or k > 0.0
				cs.append(_pre(a, b).lerp(TERRE_USEE if k > 1.5 else TERRE, clampf(k, 0.0, 1.0)))
			if garde:
				o.quad_fondu(_p(av1, dr1, 0.04), _p(av1 + 0.5, dr1, 0.04), _p(av1 + 0.5, dr1 + 0.5, 0.04), _p(av1, dr1 + 0.5, 0.04), Vector3.UP, cs)
			dr1 += 0.5
		av1 += 0.5
	o.construire(n, "Terre")
	var mob: PackedScene = load(Bibliotheque.scene("mobilier-du-bugey@1", "decor"))
	var banc: Node3D = mob.instantiate()
	banc.set("objet", "banc")
	banc.set("graine", 157)
	# Le devant du banc regarde +Z : on le tourne vers la vallée.
	banc.position = _p(BANC_AV, 0.0, 0.02)
	banc.rotation.y = lacet_noeud + PI
	n.add_child(banc)
	# La plaque de laiton vissée au dossier.
	var plaque := Label3D.new()
	plaque.text = "À Raymond,\nqui voyait loin"
	plaque.font_size = 22
	plaque.pixel_size = 0.0022
	plaque.modulate = Color("3a2c18")
	plaque.outline_size = 0
	plaque.position = _p(BANC_AV - 0.36, 0.0, 0.78)
	plaque.rotation.y = lacet_noeud
	n.add_child(plaque)
	var fond := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.11, 0.01)
	fond.mesh = bm
	var mp := StandardMaterial3D.new()
	mp.albedo_color = PLAQUE
	mp.metallic = 0.6
	mp.roughness = 0.35
	fond.material_override = mp
	fond.position = _p(BANC_AV - 0.35, 0.0, 0.78)
	fond.rotation.y = lacet_noeud
	n.add_child(fond)
	var bugey: PackedScene = load(Bibliotheque.scene("vegetation-du-bugey@1", "decor"))
	# L'arbre du banc, en repoussoir en haut à gauche du cadre (verdict n° 28) : un marronnier en dentelle
	# (arbres-d-ombriere@1), repeint du vert posé ; le chêne de vegetation-du-bugey@1 lisait en boule à facettes
	# vert pomme (verdict n° 29).
	var ombriere: PackedScene = load(Bibliotheque.scene("arbres-d-ombriere@1", "decor"))
	_dentelle(n, ombriere, "marronnier", 161, 12.0, 4.0, -7.0)
	# Les bosquets qui cadrent la vue, à gauche et à droite, plus bas sur la pente.
	_dentelle(n, ombriere, "marronnier", 162, 12.0, 16.0, -24.0)
	_dentelle(n, ombriere, "jeune_platane", 163, 10.0, 19.0, -19.0)
	_plante(n, bugey, "cerisier", 164, {}, 12.0, 21.0)
	_plante(n, bugey, "charme", 165, {"hauteur": 9.0}, 17.0, 26.0)
	# Le pré sec du replat, blond (#A8A864), sur la moitié de la vue, et ses taches de fleurs des champs : de
	# petites fleurs en semis, groupées par taches, pas un tapis régulier (verdict n° 28).
	var herbe := OUTILS.new(1573)
	var sec := OUTILS.new(1574)
	# Sans bord ni marche d'un carreau à l'autre : chaque coin prend sa teinte (_pre).
	var av0 := -2.0
	while av0 < 34.0:
		var dr0 := -26.0
		while dr0 < 26.0:
			sec.quad_fondu(_p(av0, dr0, 0.03), _p(av0 + 1.0, dr0, 0.03), _p(av0 + 1.0, dr0 + 1.0, 0.03), _p(av0, dr0 + 1.0, 0.03), Vector3.UP, [_pre(av0, dr0), _pre(av0 + 1.0, dr0), _pre(av0 + 1.0, dr0 + 1.0), _pre(av0, dr0 + 1.0)])
			dr0 += 1.0
		av0 += 1.0
	sec.construire(n, "PreSec")
	var taches := [Vector2(6.0, -7.0), Vector2(9.0, 6.5), Vector2(14.0, -13.0), Vector2(17.0, 11.0), Vector2(22.0, -3.0), Vector2(5.0, 12.0)]
	for i in 140:
		var h := absi(hash(Vector2i(i, 77)))
		var t: Vector2 = taches[h % taches.size()]
		var av := t.x + float((h / 7) % 50) / 10.0 - 2.5
		var dr := t.y + float((h / 350) % 50) / 10.0 - 2.5
		var c := _p(av, dr, 0.0)
		var hh := 0.12 + float(h % 5) * 0.03
		for b in 3:
			var db := Vector3(float((h >> b) % 5) * 0.03 - 0.06, 0, float((h >> (b + 2)) % 5) * 0.03 - 0.06)
			herbe.boule(c + db + Vector3(0, hh * 0.45, 0), Vector3(0.02, hh * 0.5, 0.02), Color("6b7f34").lightened(float(h % 9) * 0.015), 0.2, OUTILS.FEUILLE, 0.06, 1.0, 3, 4)
		var fl: Color = [Color("f4f0e6"), Color("f2c14e"), Color("b06ad0"), Color("e0605a")][(h / 11) % 4].darkened(0.1)
		for q in 2:
			var dq := Vector3(float((h >> q) % 5) * 0.04 - 0.08, hh * 0.85, float((h >> (q + 3)) % 5) * 0.04 - 0.08)
			herbe.boule(c + dq, Vector3(0.025, 0.018, 0.025), fl, 0.1, OUTILS.FEUILLE, 0.05, 1.0, 3, 4)
	herbe.construire(n, "HerbesHautes")
	# Derrière soi, la maison à vendre, son panneau à la grille.
	var mp0 := _p(-26.0, 4.0)
	var m: Node3D = FACADIER.maison(n, mp0, "r1", 158, {"mur": "enduit", "enduit": "d2be98", "couverture": "tuile_vieillie", "volets": "bois", "volet": "8ea78c", "fleurs": false})
	# Sa façade regarde la vallée, comme le banc.
	m.rotation.y = lacet_noeud + PI
	var vendre := Label3D.new()
	vendre.text = "À VENDRE"
	vendre.font_size = 64
	vendre.pixel_size = 0.004
	vendre.modulate = Color("b8322c")
	vendre.outline_modulate = Color("f3ead6")
	vendre.outline_size = 18
	vendre.position = _p(-20.5, 2.0, 1.3)
	vendre.rotation.y = lacet_noeud + PI
	n.add_child(vendre)


func _dentelle(n: Node3D, scene: PackedScene, nom: String, graine: int, h: float, av: float, dr: float) -> void:
	var m: Node3D = scene.instantiate()
	m.set("arbre", nom)
	m.set("graine", graine)
	m.set("options", {"hauteur": h})
	m.position = _p(av, dr, -0.05)
	m.rotation.y = float(graine % 628) / 100.0
	n.add_child(m)
	REPEINDRE.feuillage(m)


func _plante(n: Node3D, scene: PackedScene, nom: String, graine: int, options: Dictionary, av: float, dr: float) -> void:
	var m: Node3D = scene.instantiate()
	m.set("plante", nom)
	m.set("graine", graine)
	m.set("options", options)
	m.position = _p(av, dr, -0.05)
	m.rotation.y = float(graine % 628) / 100.0
	n.add_child(m)


## La teinte du pré sec à av, dr : du vert du pré (PRE du terrain) au blond (#A8A864) par un bruit lent, revenue au
## vert sur le pourtour pour que la nappe se fonde dans le terrain ; dégagée devant le banc.
func _pre(a: float, b: float) -> Color:
	var bruit := sin(a * 0.21 + b * 0.13) + sin(b * 0.31 - a * 0.07) + 0.4
	var bord := minf(minf(a + 2.0, 34.0 - a) / 6.0, minf(b + 26.0, 26.0 - b) / 6.0)
	var ks := smoothstep(-0.4, 0.8, bruit) * clampf(bord, 0.0, 1.0)
	ks *= smoothstep(1.5, 3.5, Vector2(a - BANC_AV, b).length())
	# Écrites plus sourdes qu'à l'écran : la saturation et la courbe de tons de belley.gd les relèvent (le blond
	# visé #B0AE6A sortait #C1DA76, verdict n° 29).
	return Color(0.40, 0.50, 0.20).lerp(Color("8e8652"), ks)


## La part de terre à av, dr (0 : le pré ; 1 : la terre ; au-delà de 1,5 : la terre usée sous le banc) : une
## ellipse sous le banc et le ruban du chemin, aux bords effilochés par un bruit fin.
func _terre(a: float, b: float, chemin: PackedVector2Array) -> float:
	var frange := sin(a * 2.3 + b * 1.7) * 0.18 + sin(a * 5.1 - b * 3.7) * 0.1
	var banc := 2.6 - Vector2((a - BANC_AV + 0.6) / 1.9, b / 1.5).length() * 2.4 + frange
	var d := INF
	for i in chemin.size() - 1:
		d = minf(d, Geometry2D.get_closest_point_to_segment(Vector2(a, b), chemin[i], chemin[i + 1]).distance_to(Vector2(a, b)))
	var ruban := (0.5 - d) / 0.25 + frange
	return maxf(banc, minf(ruban, 1.0))
