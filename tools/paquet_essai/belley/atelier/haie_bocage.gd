extends RefCounted
## La haie de bocage libre (noisetier, aubépine, prunellier), en cartes de feuillage : les touffes en dentelle
## d'arbres-d-ombriere@1 (ARBRE._touffe), semées le long d'un axe, leurs normales tournées vers le dehors de la
## haie ; le feuillage prend ensuite le vert posé de Belley (atelier/repeindre.gd). Les blocs à facettes qu'elle
## remplace viraient au blanc-bleu au soleil (verdict n° 30).
##   var h := HAIE.new(sol)
##   h.troncon(Vector2(0, 0), Vector2(30, 0), 7)
##   h.construire(parent, "Haie")

const ARBRE := preload("res://bibliotheque/arbres-d-ombriere/1/arbre.gd")
const OUTILS_ARBRE := preload("res://bibliotheque/arbres-d-ombriere/1/outils.gd")
const REPEINDRE := preload("res://communes/belley/atelier/repeindre.gd")

## Trois verts de haie, du dessus au soleil au cœur à l'ombre (cinq rangs chacun) : une haie tire le sien par sa
## graine, pour que deux haies voisines ne soient pas du même vert.
## Écrits clairs : le vert posé les assombrit (pow 2,2), et les verts du platane y sortaient presque noirs.
const VERTS := [
	["a6c852", "8cb246", "73993b", "5e8433", "4b6e2b"],
	["b2c85a", "97b04a", "7c973e", "667f35", "52692c"],
	["9cc04e", "84a842", "6d8f38", "597830", "476228"],
]
## Touffes par mètre de haie.
const DENSITE := 7.0

var hauteur: Callable
var o: RefCounted


func _init(sol: Callable, graine := 1) -> void:
	hauteur = sol
	o = OUTILS_ARBRE.new(graine)


## Une haie de a à b (au sol), haute de haut, épaisse de epais.
func troncon(a: Vector2, b: Vector2, graine: int, haut := 2.0, epais := 1.3) -> void:
	var l := a.distance_to(b)
	if l < 0.5:
		return
	var dir := (b - a) / l
	var nrm := Vector2(-dir.y, dir.x)
	var verts: Array = VERTS[posmod(graine, VERTS.size())].map(func(x): return Color(x))
	var r: RandomNumberGenerator = o.rng
	for i in int(l * DENSITE):
		var t := r.randf()
		var m := a.lerp(b, t)
		# La haie ondule en hauteur : un arbuste plus haut tous les quelques mètres.
		var hh := haut * (0.85 + 0.25 * sin(t * l * 0.7 + graine) + 0.1 * sin(t * l * 2.3))
		var c := Vector3(m.x, hauteur.call(m.x, m.y) + hh * 0.5, m.y)
		var ec := nrm * r.randf_range(-0.5, 0.5) * epais
		var q := c + Vector3(ec.x, r.randf_range(-0.45, 0.5) * hh, ec.y)
		ARBRE._touffe(o, q, r.randf_range(0.55, 0.85), verts, c, Vector3(epais * 0.6, hh * 0.55, epais * 0.6), 0.4, 0)


## Bâtit la haie sous parent, dans un nœud à son nom, au vert posé de Belley ; rend ce nœud.
func construire(parent: Node3D, nom: String) -> Node3D:
	var n := Node3D.new()
	n.name = nom
	parent.add_child(n)
	o.construire(n, "Feuillage")
	REPEINDRE.feuillage(n)
	return n
