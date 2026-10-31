extends SceneTree
## Test de l'assise des bâtiments (scripts/socle/assise.gd) : le sol sous une emprise, l'assise d'une maison sur une
## pente, et le toit à deux pans d'un plan en L, qui couvre le plan et rien d'autre, et dont les pignons ferment les
## murs.
##   godot --headless --path . -s tools/test_assise.gd

var echecs := 0


func check(ok: bool, quoi: String) -> void:
	print(("  ok  " if ok else "ÉCHEC ") + quoi)
	if not ok:
		echecs += 1


func _init() -> void:
	# une pente vers le nord (−Z) : 30 cm par mètre, et 10 cm par mètre vers l'est
	var pente := func(x: float, z: float) -> float: return 0.3 * z + 0.1 * x
	var carre := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var s := Assise.sol(pente, carre)
	check(is_equal_approx(s.x, 0.0) and is_equal_approx(s.y, 4.0), "le sol sous un carré de 10 m : de 0 à 4 m (%.2f, %.2f)" % [s.x, s.y])
	# un creux entre deux sommets : le bord le trouve, pas les sommets
	var creux := func(x: float, z: float) -> float: return -2.0 if absf(x - 5.0) < 1.0 and z < 0.5 else 0.0
	check(Assise.sol(creux, carre).x <= -2.0, "un creux au milieu d'un bord, entre deux sommets, est trouvé")

	# une maison du façadier, façade au sud au pied de la pente, le dos qui descend de 3 m
	var parent := Node3D.new()
	root.add_child(parent)
	var m := Node3D.new()
	m.set_meta("w", 8.0)
	m.set_meta("d", 10.0)
	parent.add_child(m)
	var descend := func(x: float, z: float) -> float: return 0.3 * z
	m.position = Vector3(0, 0, 0)
	var ecart := Assise.caler(m, descend)
	var a: MeshInstance3D = m.get_node_or_null("Assise")
	check(is_equal_approx(ecart, 3.0) and a != null, "la maison posée sur la pente : 3 m rattrapés par son assise (%.2f)" % ecart)
	if a != null:
		var bas := a.position.y - (a.mesh as BoxMesh).size.y * 0.5
		check(bas <= -3.0 - Assise.ENFOUI + 0.03, "l'assise descend sous le point le plus bas (%.2f)" % bas)
	# tournée d'un demi-tour, le dos vers le sud qui monte : rien à rattraper
	var m2 := Node3D.new()
	m2.set_meta("w", 8.0)
	m2.set_meta("d", 10.0)
	parent.add_child(m2)
	m2.rotation.y = PI
	check(Assise.caler(m2, descend) == 0.0 and m2.get_node_or_null("Assise") == null, "le dos qui monte : pas d'assise")

	# un plan en L : 12 × 4 et 4 × 8 ; son rectangle (12 × 12) est vide aux deux tiers d'un quart
	var l := PackedVector2Array([Vector2(0, 0), Vector2(12, 0), Vector2(12, 4), Vector2(4, 4), Vector2(4, 12), Vector2(0, 12)])
	var egout := 10.0
	var t := Assise.deux_pans(l, egout, 2.0, Vector2(6, 6), Vector2(1, 0), 6.0, 0.3)
	var aire := 0.0
	var dehors := 0
	var dessous := 0
	var elargi: PackedVector2Array = Geometry2D.offset_polygon(l, 0.31, Geometry2D.JOIN_MITER)[0]
	for tr in t.pans:
		var a2 := Vector2(tr[0].x, tr[0].z) as Vector2
		var b2 := Vector2(tr[1].x, tr[1].z)
		var c2 := Vector2(tr[2].x, tr[2].z)
		aire += absf((b2 - a2).cross(c2 - a2)) * 0.5
		if not Geometry2D.is_point_in_polygon((a2 + b2 + c2) / 3.0, elargi):
			dehors += 1
		if Assise.normale(tr).y <= 0.0:
			dessous += 1
	var attendue := 0.0
	var e2: PackedVector2Array = Geometry2D.offset_polygon(l, 0.3, Geometry2D.JOIN_MITER)[0]
	for k in e2.size():
		attendue += e2[k].cross(e2[(k + 1) % e2.size()]) * 0.5
	check(absf(aire - absf(attendue)) < 0.5, "les pans couvrent le plan et son débord, %.1f m² pour %.1f" % [aire, absf(attendue)])
	check(dehors == 0, "aucun pan au-dessus du vide du L (%d)" % dehors)
	check(dessous == 0, "les pans regardent le ciel (%d à l'envers)" % dessous)
	# au-dessus de chaque sommet du plan, le toit est à l'égout ou plus haut : il coiffe les murs
	var bas_toit := INF
	for q in l:
		for tr in t.pans:
			var a3: Vector3 = tr[0]
			var b3: Vector3 = tr[1]
			var c3: Vector3 = tr[2]
			var tri2 := PackedVector2Array([Vector2(a3.x, a3.z), Vector2(b3.x, b3.z), Vector2(c3.x, c3.z)])
			if Geometry2D.point_is_inside_triangle(q, tri2[0], tri2[1], tri2[2]):
				var n := Assise.normale(tr)
				# le plan du pan, en q : n · (p − a) = 0
				bas_toit = minf(bas_toit, a3.y - (n.x * (q.x - a3.x) + n.z * (q.y - a3.z)) / n.y)
	check(bas_toit >= egout - 0.01, "le toit ne descend jamais sous le haut des murs au-dessus du plan (%.2f)" % bas_toit)
	# les pignons : les murs qui coupent le faîtage montent jusqu'à lui, et regardent dehors
	var haut_pignon := 0.0
	var mal_tournes := 0
	for tr in t.pignons:
		var c: Vector3 = (tr[0] + tr[1] + tr[2]) / 3.0
		var n := Assise.normale(tr)
		if Geometry2D.is_point_in_polygon(Vector2(c.x, c.z) + Vector2(n.x, n.z) * 0.1, l):
			mal_tournes += 1
		for p: Vector3 in tr:
			haut_pignon = maxf(haut_pignon, p.y)
	check(t.pignons.size() > 0 and is_equal_approx(haut_pignon, egout + 2.0), "les pignons montent jusqu'au faîtage (%.2f)" % haut_pignon)
	check(mal_tournes == 0, "les pignons regardent hors du plan (%d tournés dedans)" % mal_tournes)

	print("\n%d échec(s)" % echecs)
	quit(1 if echecs > 0 else 0)
