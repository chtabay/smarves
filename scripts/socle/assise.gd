class_name Assise
extends RefCounted
## L'assise des bâtiments sur un relief réel (socle 1.30) : un bâtiment ne flotte pas au-dessus du sol, son
## toit coiffe ses murs. Guillaume, 30 octobre : sur les villes en relief réel, « l'ajustement des bâtiments
## au sol, ou des toits vs les murs ». Trois causes, communes à Lyon, Belley et Availles :
##
## 1. Le pied des murs pris au relevé (`sol` de bourg.json, le point bas des sommets dans le RGE ALTI) et non
##    au terrain que la scène dessine : la scène le nivelle, le creuse, l'interpole sur sa grille de 5 m, et
##    entre deux sommets le sol peut passer sous le pied. On voit le jour sous le mur.
## 2. Les maisons du façadier posées sur un point de leur façade, avec un soubassement de 30 cm : sur une
##    pente, le dos ou un flanc reste en l'air dès que le terrain descend de plus de 30 cm sous l'emprise.
## 3. Les toits taillés sur le rectangle qui serre le plan (`rect`), posés sur des murs qui suivent le plan
##    réel : sur un plan en L ou en biais, le toit déborde dans le vide d'un côté et laisse le mur nu de
##    l'autre.
##
## Ce que la classe donne, à appeler dans le repère où le terrain est mesuré (`hauteur(x, z)`, la fonction de la
## scène, dans le repère du nœud parent des maisons) :
##   Assise.sol(hauteur, plan)           le plus bas et le plus haut du terrain sous une emprise (Vector2)
##   Assise.caler(maison, hauteur)       le soubassement d'une maison du façadier jusqu'au point bas du terrain
##   Assise.caler_tout(racine, hauteur)  toutes les maisons du façadier posées sous racine
##   Assise.deux_pans(plan, egout, ...)  un toit à deux pans sur le plan réel, et les pignons qui montent les
##                                       murs jusqu'à lui
## Le contrat est dans docs/COMMUNE.md, « L'assise des bâtiments ».

## La marge sous le terrain : le pied d'un mur ou d'un soubassement descend d'autant sous le point le plus bas.
const ENFOUI := 0.3
## L'écart à partir duquel une maison reçoit un soubassement : en deçà, celui du façadier (30 cm) suffit.
const ECART_MIN := 0.25
## Le pas d'échantillonnage du terrain sous une emprise, en mètres (la grille du relief est de 5 m).
const PAS := 1.5
## La pierre du soubassement, par défaut : un moellon gris chaud, plus sombre que les enduits.
const PIERRE := Color("8f8574")

static var _matieres := {}


## Le plus bas (x) et le plus haut (y) du terrain sous un plan fermé : aux sommets, le long des bords tous les
## `pas` mètres, et à l'intérieur sur une grille du même pas.
static func sol(hauteur: Callable, plan: PackedVector2Array, pas := PAS) -> Vector2:
	var bas := INF
	var haut := -INF
	var n := plan.size()
	if n == 0:
		return Vector2.ZERO
	var boite := Rect2(plan[0], Vector2.ZERO)
	for k in n:
		var a := plan[k]
		var b := plan[(k + 1) % n]
		boite = boite.expand(a)
		var nb := maxi(1, ceili(a.distance_to(b) / pas))
		for j in nb:
			var q := a.lerp(b, float(j) / nb)
			var y: float = hauteur.call(q.x, q.y)
			bas = minf(bas, y)
			haut = maxf(haut, y)
	var x := boite.position.x + pas * 0.5
	while x < boite.end.x:
		var z := boite.position.y + pas * 0.5
		while z < boite.end.y:
			if Geometry2D.is_point_in_polygon(Vector2(x, z), plan):
				var y: float = hauteur.call(x, z)
				bas = minf(bas, y)
				haut = maxf(haut, y)
			z += pas
		x += pas
	return Vector2(bas, haut)


## L'emprise d'une maison du façadier, w × d (ses métadonnées), dans le repère t (par défaut celui de son parent) :
## façade vers +Z, origine au pied de la façade, au milieu, le corps vers −Z.
static func emprise(maison: Node3D, t = null) -> PackedVector2Array:
	var w := float(maison.get_meta("w", 0.0))
	var d := float(maison.get_meta("d", 0.0))
	var tr: Transform3D = maison.transform if t == null else t
	var plan := PackedVector2Array()
	for c in [Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), Vector3(w * 0.5, 0, -d), Vector3(-w * 0.5, 0, -d)]:
		var p: Vector3 = tr * c
		plan.append(Vector2(p.x, p.z))
	return plan


## Cale une maison du façadier déjà posée (sa position et son lacet réglés, ses métadonnées w et d lues, donc
## après son entrée dans l'arbre) : si le terrain descend sous son emprise plus bas que son soubassement, une
## assise de pierre descend du pied de la façade jusqu'à ENFOUI sous le point le plus bas, sur toute l'emprise.
## Rend l'écart rattrapé, dans le repère du terrain (0 si rien n'a été posé). La maison n'est pas déplacée : sa
## porte reste au niveau de la rue où la commune l'a mise. `hauteur` mesure le terrain dans le repère de `repere`
## (par défaut, le parent de la maison) ; une maison déjà calée ou qui porte la méta `sans_assise` est laissée.
static func caler(maison: Node3D, hauteur: Callable, pierre := PIERRE, repere: Node3D = null) -> float:
	var w := float(maison.get_meta("w", 0.0))
	var d := float(maison.get_meta("d", 0.0))
	if w <= 0.0 or d <= 0.0 or maison.has_meta("sans_assise") or maison.get_node_or_null("Assise") != null:
		return 0.0
	var t := maison.transform
	if repere != null and repere != maison.get_parent():
		t = repere.global_transform.affine_inverse() * maison.global_transform
	var s := sol(hauteur, emprise(maison, t))
	var ecart := t.origin.y - s.x
	if ecart < ECART_MIN:
		return 0.0
	var e := t.basis.y.length()
	var haut := (ecart + ENFOUI) / (e if e > 0.0 else 1.0)
	var m := MeshInstance3D.new()
	m.name = "Assise"
	var bm := BoxMesh.new()
	# 2 cm de moins que la façade de chaque côté : l'assise ne fait pas de lèvre sous les murs
	bm.size = Vector3(w - 0.04, haut, d - 0.04)
	m.mesh = bm
	m.material_override = _matiere(pierre)
	# son sommet à 2 cm sous le pied de la façade, pour ne pas scintiller contre le soubassement du façadier
	m.position = Vector3(0, -0.02 - haut * 0.5, -d * 0.5)
	maison.add_child(m)
	return ecart


## Cale toutes les maisons du façadier posées sous racine (les nœuds qui portent les métadonnées w, d et type), le
## terrain mesuré par `hauteur` dans le repère de `repere` (par défaut, racine). Rend le nombre de maisons calées.
## Un appel à la fin de la construction de la commune suffit.
static func caler_tout(racine: Node3D, hauteur: Callable, pierre := PIERRE, repere: Node3D = null) -> int:
	var nb := 0
	for m in maisons(racine):
		if caler(m, hauteur, pierre, racine if repere == null else repere) > 0.0:
			nb += 1
	return nb


## Les maisons du façadier posées sous racine : les nœuds qui portent les métadonnées w, d et type.
static func maisons(racine: Node) -> Array:
	var out := []
	_maisons(racine, out)
	return out


static func _maisons(n: Node, out: Array) -> void:
	if n is Node3D and n.has_meta("w") and n.has_meta("d") and n.has_meta("type"):
		out.append(n)
		return
	for e in n.get_children():
		_maisons(e, out)


## Un toit à deux pans sur le plan réel. Le faîtage court le long de `axe` (le grand côté du rectangle qui serre
## le plan) par `centre` ; chaque pan monte de l'égout, à la hauteur `egout` (le haut réel des murs), à
## `egout + montee` au faîtage, sur la demi-largeur `demi` (la moitié du petit côté). Le toit déborde de `debord`
## au-delà des murs, en continuant ses pentes. Les murs du plan qui ne sont pas sous l'égout (les pignons, et
## les murs en retrait d'un plan en L) montent jusqu'au toit : rien ne reste en l'air, rien ne reste ouvert.
## Rend {"pans": [[a, b, c], …], "pignons": [[a, b, c], …]}, des triangles de Vector3 tournés vers le dehors
## (les pans vers le ciel, les pignons hors du plan), à verser dans le maillage de la commune.
static func deux_pans(plan: PackedVector2Array, egout: float, montee: float, centre: Vector2, axe: Vector2, demi: float, debord := 0.3) -> Dictionary:
	var u := axe.normalized()
	var v := u.orthogonal()
	demi = maxf(demi, 0.5)
	var hauteur_toit := func(p: Vector2) -> float:
		return egout + montee * (1.0 - absf((p - centre).dot(v)) / demi)
	var pans := []
	var dessus := plan
	if debord > 0.0:
		var elargi := Geometry2D.offset_polygon(plan, debord, Geometry2D.JOIN_MITER)
		if not elargi.is_empty():
			dessus = elargi[0]
	# les deux pans : le plan coupé par la ligne du faîtage, chaque moitié est plane
	var loin := 10000.0
	for cote in [1.0, -1.0]:
		var demi_plan := PackedVector2Array([
			centre - u * loin, centre + u * loin, centre + u * loin + v * cote * loin, centre - u * loin + v * cote * loin])
		for morceau in Geometry2D.intersect_polygons(dessus, demi_plan):
			var tri := Geometry2D.triangulate_polygon(morceau)
			for k in range(0, tri.size(), 3):
				var t := []
				for j in 3:
					var q: Vector2 = morceau[tri[k + j]]
					t.append(Vector3(q.x, hauteur_toit.call(q), q.y))
				pans.append(_vers(t, Vector3.UP))
	# les pignons : sur chaque mur, ce qui sépare l'égout du toit, coupé au faîtage s'il le traverse
	var pignons := []
	for k in plan.size():
		var a := plan[k]
		var b := plan[(k + 1) % plan.size()]
		if a.distance_to(b) < 0.05:
			continue
		var n2 := (b - a).normalized().orthogonal()
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + n2 * 0.05, plan):
			n2 = -n2
		var dehors := Vector3(n2.x, 0, n2.y)
		var pts := [a]
		var da := (a - centre).dot(v)
		var db := (b - centre).dot(v)
		if da * db < 0.0:
			pts.append(a.lerp(b, da / (da - db)))
		pts.append(b)
		for j in pts.size() - 1:
			var p0: Vector2 = pts[j]
			var p1: Vector2 = pts[j + 1]
			var h0: float = hauteur_toit.call(p0)
			var h1: float = hauteur_toit.call(p1)
			if h0 - egout < 0.02 and h1 - egout < 0.02:
				continue
			var A := Vector3(p0.x, egout, p0.y)
			var B := Vector3(p1.x, egout, p1.y)
			var C := Vector3(p1.x, maxf(h1, egout), p1.y)
			var D := Vector3(p0.x, maxf(h0, egout), p0.y)
			if C.y - B.y > 0.02:
				pignons.append(_vers([A, B, C], dehors))
			if D.y - A.y > 0.02:
				pignons.append(_vers([A, C, D], dehors))
	return {"pans": pans, "pignons": pignons}


## Le triangle dans l'ordre qui tourne sa face vers `dehors` (le sens direct de Godot, vu du dehors).
static func _vers(t: Array, dehors: Vector3) -> Array:
	var n: Vector3 = (t[2] - t[0]).cross(t[1] - t[0])
	if n.dot(dehors) < 0.0:
		return [t[0], t[2], t[1]]
	return t


## La normale d'un triangle rendu par deux_pans.
static func normale(t: Array) -> Vector3:
	return (t[2] - t[0]).cross(t[1] - t[0]).normalized()


static func _matiere(c: Color) -> StandardMaterial3D:
	var cle := c.to_html()
	if not _matieres.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.95
		_matieres[cle] = m
	return _matieres[cle]
