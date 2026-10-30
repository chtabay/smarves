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
	_tache(o, BANC_AV - 0.6, 0.0, 3.4, 2.6, TERRE_USEE)
	var k := 0
	while k < 16:
		var av := 0.6 - k * 1.9
		var dr := -2.2 - k * 0.9 + sin(k * 0.7) * 0.8
		_tache(o, av, dr, 2.0, 1.4, TERRE)
		k += 1
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
	# Le chêne du banc, un peu à gauche derrière : sa couronne fait le haut du cadre.
	_plante(n, bugey, "chene", 161, {"hauteur": 15.0}, -1.5, -5.5)
	# Les bosquets qui cadrent la vue, à gauche et à droite, plus bas sur la pente.
	_plante(n, bugey, "chene", 162, {"hauteur": 12.0}, 16.0, -24.0)
	_plante(n, bugey, "charme", 163, {"hauteur": 10.0}, 19.0, -19.0)
	_plante(n, bugey, "cerisier", 164, {}, 12.0, 21.0)
	_plante(n, bugey, "charme", 165, {"hauteur": 9.0}, 17.0, 26.0)
	# Les herbes hautes et les fleurs des champs du pré, de part et d'autre de la vue : des touffes d'herbe et des
	# semis de petites fleurs, pas des pots.
	var herbe := OUTILS.new(1573)
	for i in 420:
		var h := absi(hash(Vector2i(i, 77)))
		var av := 1.0 + float(h % 220) / 10.0
		var dr := float((h / 220) % 400) / 10.0 - 20.0
		if absf(dr) < 2.2 and av < 5.0:
			continue
		var c := _p(av, dr, 0.0)
		# Une touffe : trois brins effilés, d'un vert plus sombre que le pré.
		var hh := 0.3 + float(h % 7) * 0.05
		for b in 3:
			var db := Vector3(float((h >> b) % 5) * 0.05 - 0.1, 0, float((h >> (b + 2)) % 5) * 0.05 - 0.1)
			herbe.boule(c + db + Vector3(0, hh * 0.45, 0), Vector3(0.07, hh * 0.5, 0.07), Color("4a7a2a").lightened(float(h % 9) * 0.015), 0.2, OUTILS.FEUILLE, 0.06, 1.0, 3, 5)
		if h % 3 != 0:
			var fl: Color = [Color("f4f0e6"), Color("f2c14e"), Color("b06ad0"), Color("e0605a")][(h / 7) % 4]
			for q in 4:
				var dq := Vector3(float((h >> q) % 7) * 0.07 - 0.21, hh * 0.8, float((h >> (q + 3)) % 7) * 0.07 - 0.21)
				herbe.boule(c + dq, Vector3(0.06, 0.04, 0.06), fl, 0.1, OUTILS.FEUILLE, 0.05, 1.0, 3, 5)
	herbe.construire(n, "HerbesHautes")
	for i in 6:
		_plante(n, bugey, "haie", 200 + i, {"longueur": 2.5, "hauteur": 1.1}, 6.0 + i * 1.5, (-1.0 if i % 2 == 0 else 1.0) * (9.0 + i * 1.4))
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


func _plante(n: Node3D, scene: PackedScene, nom: String, graine: int, options: Dictionary, av: float, dr: float) -> void:
	var m: Node3D = scene.instantiate()
	m.set("plante", nom)
	m.set("graine", graine)
	m.set("options", options)
	m.position = _p(av, dr, -0.05)
	m.rotation.y = float(graine % 628) / 100.0
	n.add_child(m)


## Une tache de terre de taille w × d (le long du devant, en travers), drapée sur le sol par carreaux de 0,5 m.
func _tache(o: RefCounted, av: float, dr: float, w: float, d: float, col: Color) -> void:
	var pas := 0.5
	var i := -w * 0.5
	while i < w * 0.5 - 0.01:
		var j := -d * 0.5
		while j < d * 0.5 - 0.01:
			# Un bord irrégulier : les coins de la tache s'effilochent dans l'herbe.
			var r := Vector2(i / (w * 0.5), j / (d * 0.5)).length()
			if r < 1.0 - float(absi(hash(Vector2i(int(i * 10.0 + av * 7.0), int(j * 10.0 + dr * 7.0)))) % 30) / 100.0:
				var c := col.darkened(float(absi(hash(Vector2i(int(i * 4.0), int(j * 4.0)))) % 8) * 0.01)
				o.quad(_p(av + i, dr + j, 0.04), _p(av + i + pas, dr + j, 0.04), _p(av + i + pas, dr + j + pas, 0.04), _p(av + i, dr + j + pas, 0.04), Vector3.UP, c, OUTILS.PEINT)
			j += pas
		i += pas
