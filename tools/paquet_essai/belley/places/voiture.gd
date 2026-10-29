extends RefCounted
## Une voiture garée, en attendant celles de la bibliothèque : une citadine à hayon, en jouet, comme sur la
## planche (gris, blanc, rouge, bleu nuit). Le pied à l'origine, l'avant vers +Z, 3,8 m de long.

const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const TEINTES := [Color("b9bec2", 0.3), Color("eceeec", 0.3), Color("4a4f57", 0.3), Color("b8312c", 0.3), Color("2f3e5c", 0.3), Color("8d9296", 0.3), Color("d9d4c6", 0.3)]
const VITRE := Color(0.2, 0.26, 0.32, 0.1)
const PNEU := Color("222222", 0.9)

var graine := 0


func _init(g: int) -> void:
	graine = g


func batir(parent: Node3D) -> Node3D:
	var o := OUTILS.new(graine)
	var c: Color = TEINTES[absi(hash(graine * 13)) % TEINTES.size()]
	var l := 3.8
	var lg := 1.66
	# La caisse, son capot et son hayon arrondis par deux biseaux.
	var caisse := PackedVector2Array([Vector2(-l * 0.5, 0.32), Vector2(l * 0.5, 0.32), Vector2(l * 0.5, 0.7), Vector2(l * 0.44, 0.86), Vector2(-l * 0.47, 0.9), Vector2(-l * 0.5, 0.75)])
	o.profil(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3.ZERO), caisse, -lg * 0.5, lg * 0.5, c, OUTILS.PEINT)
	# L'habitacle : le pare-brise incliné, le toit, la lunette.
	var cabine := PackedVector2Array([Vector2(-l * 0.47, 0.9), Vector2(l * 0.18, 0.88), Vector2(-l * 0.05, 1.38), Vector2(-l * 0.44, 1.4)])
	o.profil(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3.ZERO), cabine, -lg * 0.44, lg * 0.44, VITRE, OUTILS.VITRE)
	o.profil(Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0.02, 0)), PackedVector2Array([Vector2(-l * 0.44, 1.36), Vector2(-l * 0.06, 1.34), Vector2(-l * 0.07, 1.4), Vector2(-l * 0.43, 1.42)]), -lg * 0.45, lg * 0.45, c, OUTILS.PEINT)
	# Les montants entre les vitres.
	for s: float in [-1.0, 1.0]:
		o.boite(Transform3D(Basis(), Vector3(s * lg * 0.44, 1.12, -l * 0.18)), Vector3(0.05, 0.5, 0.08), c, OUTILS.PEINT)
	# Les roues, les phares, les feux.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			o.cylindre(Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(lg * 0.5 + 0.02 if sx > 0.0 else -lg * 0.5 + 0.2, 0.3, sz * l * 0.32)), 0.3, 0.3, 0.22, 10, PNEU, OUTILS.PEINT)
		o.boite(Transform3D(Basis(), Vector3(sx * lg * 0.32, 0.62, l * 0.5)), Vector3(0.32, 0.14, 0.04), Color("f4f0dc", 0.2), OUTILS.PEINT)
		o.boite(Transform3D(Basis(), Vector3(sx * lg * 0.36, 0.66, -l * 0.5)), Vector3(0.22, 0.16, 0.04), Color("a8221e", 0.2), OUTILS.PEINT)
	o.boite(Transform3D(Basis(), Vector3(0, 0.42, l * 0.5 + 0.03)), Vector3(lg, 0.14, 0.08), Color("3a3a3a", 0.8), OUTILS.PEINT)
	o.boite(Transform3D(Basis(), Vector3(0, 0.42, -l * 0.5 - 0.03)), Vector3(lg, 0.14, 0.08), Color("3a3a3a", 0.8), OUTILS.PEINT)
	var n := Node3D.new()
	n.name = "Voiture"
	parent.add_child(n)
	o.construire(n, "Caisse")
	return n
