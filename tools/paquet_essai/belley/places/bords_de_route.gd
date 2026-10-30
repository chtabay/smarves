extends RefCounted
## Les bords de la route à vélo, de la ville au banc puis du banc au relais (relief/parcours.json, le plus court
## chemin sur les routes réelles) : des haies de bocage libres, par tronçons, et des arbres isolés ou en rideau,
## comme sur la route du pont de Lucey de la seconde planche. Hors du bourg seulement, qui a ses jardins.
##   BORDS.new(hauteur).batir(parent)

const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const REPEINDRE := preload("res://communes/belley/atelier/repeindre.gd")
const DONNEES := "res://communes/belley/relief/parcours.json"

## Les verts de la haie libre (noisetier, aubépine, prunellier), du cœur à l'ombre au dessus au soleil.
const VERTS_HAIE := [Color("4f7a2c"), Color("5d8833"), Color("6b9139"), Color("3f6526")]
const ESSENCES := ["platane", "marronnier", "jeune_platane"]
## Pas de haie ni d'arbre dans le bourg (jardins.gd), ni autour du banc et du relais (leurs scènes).
const LIBRES := [[Vector2(0, 0), 750.0], [Vector2(4200, 2160), 60.0], [Vector2(7180, 650), 170.0]]
const LOT := 500.0
const PORTEE := 1100.0

var hauteur: Callable
var lots := {}


func _init(sol: Callable) -> void:
	hauteur = sol


func batir(parent: Node3D) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	var n := Node3D.new()
	n.name = "BordsDeRoute"
	parent.add_child(n)
	var ombriere: PackedScene = load(Bibliotheque.scene("arbres-d-ombriere@1", "decor"))
	var t := 0
	for tr in d.troncons:
		var p: Array = tr
		var pts := PackedVector2Array()
		for i in range(0, p.size(), 2):
			pts.append(Vector2(p[i], p[i + 1]))
		_longer(n, ombriere, pts, t)
		t += 1
	for cle in lots:
		var mi: MeshInstance3D = lots[cle].construire(n, "Haies")
		mi.visibility_range_end = PORTEE
		mi.visibility_range_end_margin = 100.0


func _libre(v: Vector2) -> bool:
	for l in LIBRES:
		if v.distance_to(l[0]) < l[1]:
			return false
	return true


## Le long d'un tronçon, tous les 12 m : un bout de haie d'un côté ou de l'autre selon un bruit lent (le bocage
## s'ouvre et se ferme), et tous les 130 m environ un arbre sur la haie (plus serrés, ils épuisaient les variables d'instance des
## feuillages, plafonnées à 4 096).
func _longer(n: Node3D, ombriere: PackedScene, pts: PackedVector2Array, t: int) -> void:
	var s := 0.0
	var prochain_arbre := 20.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.5:
			continue
		var dir := (b - a) / seg
		var nrm := Vector2(-dir.y, dir.x)
		var u := fposmod(-s, 12.0)
		while u < seg:
			var c := a + dir * u
			var abs_s := s + u
			var h := absi(hash(Vector2i(int(abs_s), t)))
			if _libre(c):
				for cote: float in [-1.0, 1.0]:
					# Chaque côté a sa haie par tronçons de 100 à 200 m, avec des trouées (les entrées de champ).
					if sin(abs_s * 0.011 + cote * 1.7 + t * 2.3) + sin(abs_s * 0.037 + cote) * 0.5 > 0.1:
						_haie(c + nrm * cote * (5.5 + float(h % 3) * 0.5), dir, h)
				if abs_s > prochain_arbre:
					var cote2 := 1.0 if h % 2 == 0 else -1.0
					var q := c + nrm * cote2 * (7.0 + float(h % 4))
					var m: Node3D = ombriere.instantiate()
					m.set("arbre", ESSENCES[h % ESSENCES.size()])
					m.set("graine", h % 9973)
					m.set("options", {"hauteur": 10.0 + float(h % 7), "densite": 0.6})
					m.position = Vector3(q.x, hauteur.call(q.x, q.y) - 0.1, q.y)
					m.rotation.y = float(h % 628) / 100.0
					n.add_child(m)
					REPEINDRE.feuillage(m)
					for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
						mi.visibility_range_end = PORTEE
						mi.visibility_range_end_margin = 100.0
					prochain_arbre = abs_s + 90.0 + float(h % 80)
			u += 12.0
		s += seg


## Un bout de haie libre de 12 m, centré sur c : cinq touffes qui se chevauchent, hautes de 1,8 à 2,6 m.
func _haie(c: Vector2, dir: Vector2, h: int) -> void:
	var cle := Vector2i(int(floor(c.x / LOT)), int(floor(c.y / LOT)))
	if not lots.has(cle):
		lots[cle] = OUTILS.new(cle.x * 37 + cle.y)
	var o: RefCounted = lots[cle]
	for k in 5:
		var v := c + dir * (float(k) * 2.6 - 5.2)
		var hk := absi(hash(Vector2i(h, k)))
		var ht := 1.8 + float(hk % 9) * 0.1
		var y: float = hauteur.call(v.x, v.y)
		o.boule(Vector3(v.x, y + ht * 0.45, v.y), Vector3(1.7, ht * 0.55, 1.4), VERTS_HAIE[hk % 4], 0.22, OUTILS.FEUILLE, 0.07, 0.3, 4, 6)
