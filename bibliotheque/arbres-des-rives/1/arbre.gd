extends Node3D
## Un arbre des rives, posé tel quel : on règle arbre, graine et options avant de l'ajouter à la scène, il se bâtit
## à son entrée dans l'arbre de scène. Le pied est à l'origine, sur un sol plat à y = 0 ; en mètres.
##   var a = load(Bibliotheque.scene("arbres-des-rives@1", "decor")).instantiate()
##   a.arbre = "peuplier" ; a.graine = 7
##   add_child(a)
## Après la construction, le nœud porte ses métadonnées : arbre, graine, hauteur, couronne (le rayon de la
## couronne, pour espacer un rideau).
## Demandé par la carte de Belley pour les bords du Rhône : le peuplier en rideau le long de l'eau, et ses voisins
## de la ripisylve. Même feuillage en dentelle que les arbres d'ombrière (des cartes percées où le shader dessine
## les feuilles), avec les feuilles de chaque essence.
const Outils := preload("res://bibliotheque/arbres-des-rives/1/outils.gd")

## Les arbres : le peuplier d'Italie (22 à 28 m, la colonne étroite des rideaux), le peuplier noir (20 à 24 m,
## large et irrégulier, l'arbre des îles et des lônes) et le saule blanc (12 à 15 m, penché sur l'eau, argenté).
const ARBRES := ["peuplier", "peuplier_noir", "saule"]

## Les verts, du dessus au soleil au cœur à l'ombre.
const VERTS := {
	"peuplier": ["bcd65c", "a2c74c", "88b440", "70a036", "5c862e"],
	"peuplier_noir": ["b4d058", "9ac149", "80ad3e", "699634", "567c2c"],
	"saule": ["cdd6aa", "b8c594", "a2b480", "8da06c", "79895a"],
}
const ECORCE := {"peuplier": "8f8c7e", "peuplier_noir": "6f6a5e", "saule": "857a66"}

## L'arbre (voir ARBRES).
@export var arbre := "peuplier"
## La graine : deux arbres de même nom et de graines différentes ne se ressemblent pas.
@export var graine := 1
## Les options, toutes facultatives : hauteur (en mètres), vent (0 à 1, l'amplitude du souffle), densite (0,5 à
## 1,5 : le nombre de touffes, 1 par défaut ; moins de touffes, plus de ciel), penche (le saule : l'inclinaison du
## tronc vers +Z, en radians, 0,3 par défaut : il se penche vers l'eau).
@export var options := {}

var fait := false


func _ready() -> void:
	if fait:
		return
	fait = true
	var m := pousser(self, Vector3.ZERO, arbre, graine, options)
	for k in m:
		set_meta(k, m[k])


## Les arbres, pour une commune qui les passe en revue.
static func noms() -> Array:
	return ARBRES.duplicate()


## Bâtit un arbre sous parent, son pied en p. Rend arbre, graine, hauteur, couronne.
static func pousser(parent: Node3D, p: Vector3, nom: String, g: int, opt := {}) -> Dictionary:
	if not nom in ARBRES:
		nom = "peuplier"
	var o := Outils.new(g * 7919 + ARBRES.find(nom) * 37 + 5)
	var r := o.rng
	var gabarit: Dictionary = {
		"peuplier": {"h": 25.0, "rt": 0.018, "R": Vector2(0.09, 0.42), "touffes": 420, "taille": 1.05},
		"peuplier_noir": {"h": 22.0, "fut": 0.28, "rt": 0.028, "n": 4, "ouverture": 0.55, "R": Vector2(0.3, 0.36), "touffes": 520, "taille": 1.35},
		"saule": {"h": 14.0, "fut": 0.32, "rt": 0.034, "n": 5, "ouverture": 1.0, "R": Vector2(0.46, 0.3), "touffes": 480, "taille": 1.2},
	}[nom]
	var h := float(opt.get("hauteur", float(gabarit["h"]) * r.randf_range(0.9, 1.1)))
	var vent := float(opt.get("vent", 1.0))
	var verts: Array = VERTS[nom].map(func(x): return Color(x))
	var ec := Color(ECORCE[nom])
	var rt := h * float(gabarit["rt"])
	var Rv: Vector2 = gabarit["R"]
	var R := Vector3(h * Rv.x, h * Rv.y, h * Rv.x)
	var forme := 1 if nom == "saule" else 0
	var bouts := []
	var c: Vector3
	if nom == "peuplier":
		# la colonne : un tronc droit jusqu'en haut, des branches courtes qui montent serrées contre lui
		c = p + Vector3(0, h * 0.54, 0)
		o.branche(p + Vector3(0, -0.3, 0), p + Vector3(0, h * 0.94, 0), rt * 1.1, rt * 0.15, ec, 8)
		o.cylindre(Transform3D(Basis(), p), rt * 1.7, rt * 1.1, 0.4, 8, ec.darkened(0.12), Outils.DUR, false)
		var y := h * 0.1
		while y < h * 0.88:
			var a := r.randf() * TAU
			var t := y / h
			var l := h * 0.09 * (1.0 - absf(t - 0.45) * 1.2)
			var d := Vector3(cos(a) * 0.38, 1.0, sin(a) * 0.38).normalized()
			var a0 := p + Vector3(0, y, 0)
			var b := a0 + d * l
			o.branche(a0, b, rt * 0.3 * (1.0 - t * 0.6), rt * 0.08, ec.lightened(0.04), 4)
			bouts.append(b)
			bouts.append(a0.lerp(b, 0.55))
			y += r.randf_range(0.35, 0.7)
	else:
		# le peuplier noir et le saule : un fût court, des charpentières qui se partagent ; le saule se penche
		var penche := float(opt.get("penche", 0.3)) if nom == "saule" else r.randf_range(-0.04, 0.04)
		var fut := h * float(gabarit["fut"])
		var haut := p + Vector3(0, fut, 0).rotated(Vector3.RIGHT, penche)
		c = haut + Vector3(0, R.y * 0.85, 0)
		o.branche(p + Vector3(0, -0.3, 0), haut, rt * 1.2, rt, ec, 9)
		o.cylindre(Transform3D(Basis(), p), rt * 1.8, rt * 1.2, 0.45, 9, ec.darkened(0.12), Outils.DUR, false)
		# l'écorce crevassée : des bandes verticales plus sombres
		for i in 14:
			var a := TAU * i / 14.0
			var b := Basis(Vector3.RIGHT, penche) * Basis(Vector3.UP, a)
			o.boite(Transform3D(b, p.lerp(haut, 0.5) + b * Vector3(0, 0, rt * 1.08)), Vector3(rt * 0.18, fut * 0.9, 0.02), ec.darkened(0.25))
		var n: int = gabarit["n"] + r.randi() % 2
		var ouverture: float = gabarit["ouverture"]
		for i in n:
			var a := TAU * i / n + r.randf_range(-0.4, 0.4)
			var ou := ouverture * r.randf_range(0.7, 1.15)
			var d := Vector3(cos(a) * sin(ou), cos(ou), sin(a) * sin(ou))
			_ramure(o, haut - Vector3(0, r.randf_range(0.0, 0.6), 0), d, h * r.randf_range(0.24, 0.32), rt * 0.7, ec, 0, bouts, c, R)
		for i in 3:
			var a := r.randf() * TAU
			_ramure(o, haut, Vector3(cos(a) * 0.3, 1.0, sin(a) * 0.3).normalized(), h * 0.22, rt * 0.4, ec, 1, bouts, c, R)
	# les touffes : autour des bouts, dans la silhouette de l'essence ; le saule laisse pendre les siennes
	var total := int(float(gabarit["touffes"]) * float(opt.get("densite", 1.0)))
	var taille: float = gabarit["taille"]
	var semees := 0
	var essais := 0
	var portee := 0.05 if nom == "peuplier" else 0.11
	while semees < total and essais < total * 8:
		essais += 1
		var bout: Vector3 = bouts[r.randi() % bouts.size()]
		var q := bout + Vector3(r.randf_range(-1, 1), r.randf_range(-0.6, 0.9), r.randf_range(-1, 1)) * h * portee
		if nom == "saule" and r.randf() < 0.3:
			# les rameaux retombants : trois ou quatre touffes en chapelet sous un bout du bord de la couronne
			var l0 := bout - c
			if Vector2(l0.x / R.x, l0.z / R.z).length() < 0.55:
				continue
			var chute := r.randf_range(h * 0.15, h * 0.36)
			var n_ch := 3 + r.randi() % 2
			for k in n_ch:
				var t := float(k + 1) / n_ch
				_touffe(o, bout + Vector3(r.randf_range(-0.3, 0.3), -chute * t, r.randf_range(-0.3, 0.3)), taille * r.randf_range(0.6, 0.9), verts, c, R, vent, forme)
			semees += n_ch
			continue
		elif r.randf() < 0.15:
			q = c + Vector3(r.randf_range(-0.6, 0.6) * R.x, r.randf_range(0.3, 0.95) * R.y, r.randf_range(-0.6, 0.6) * R.z)
		var l := q - c
		var e := Vector3(l.x / R.x, l.y / (R.y * (1.0 if l.y > 0.0 else 0.8)), l.z / R.z)
		if e.length() > 1.05:
			continue
		if nom != "peuplier" and e.length() < 0.5 and e.y < 0.2 and r.randf() < 0.75:
			continue
		var s := taille * r.randf_range(0.7, 1.3)
		_touffe(o, q, s, verts, c, R, vent, forme)
		semees += 1
	o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.5, 0)), Vector3(rt * 2.2, 3.0, rt * 2.2)])
	o.construire(parent, nom.capitalize())
	return {"arbre": nom, "graine": g, "hauteur": c.y - p.y + R.y, "couronne": R.x}


## Une branche de a dans la direction d, longue de l, de rayon ra ; elle se partage en deux ou trois jusqu'au
## niveau 2. Les bouts sont rangés dans bouts.
static func _ramure(o: Outils, a: Vector3, d: Vector3, l: float, ra: float, ec: Color, niveau: int, bouts: Array, c: Vector3, R: Vector3) -> void:
	var r := o.rng
	# la branche s'infléchit : elle monte puis s'étale vers le bord du dôme
	var b := a + d * l
	var l2 := b - c
	var e := Vector3(l2.x / R.x, l2.y / R.y, l2.z / R.z).length()
	if e > 1.0:
		b = c + (b - c) / e * 0.98
	var rb := ra * 0.62
	var m := a.lerp(b, 0.5) + Vector3(0, l * 0.06, 0)
	o.branche(a, m, ra, (ra + rb) * 0.5, ec.lightened(niveau * 0.03), 7 - niveau)
	o.branche(m, b, (ra + rb) * 0.5, rb, ec.lightened(niveau * 0.03), 6 - niveau)
	if niveau >= 2:
		bouts.append(b)
		return
	bouts.append(m)
	var fils := 2 + (1 if r.randf() < 0.45 else 0)
	for i in fils:
		var axe := d.cross(Vector3.UP)
		if axe.length() < 0.01:
			axe = Vector3.RIGHT
		axe = axe.normalized().rotated(d, TAU * i / fils + r.randf_range(-0.5, 0.5))
		var nd := d.rotated(axe, r.randf_range(0.3, 0.6))
		# les branches du haut se redressent un peu, celles du bord s'abaissent
		nd = (nd + Vector3(0, 0.15, 0)).normalized()
		_ramure(o, b, nd, l * r.randf_range(0.55, 0.7), rb, ec, niveau + 1, bouts, c, R)


## Une touffe : deux cartes croisées où le shader du feuillage dessine cinq à sept feuilles en dentelle (UV.x porte
## la variante de la carte, UV.y la forme des feuilles : 0 le peuplier, 1 le saule), tournées vers le dehors de la couronne. Les normales penchent vers le
## dehors du dôme, pour une ombre douce de dessin ; le dessus et le côté du soleil sont plus clairs, le dessous et
## le cœur plus sombres.
static func _touffe(o: Outils, q: Vector3, s: float, verts: Array, c: Vector3, R: Vector3, vent: float, forme: int) -> void:
	var r := o.rng
	var l := q - c
	var dans := Vector3(l.x / R.x, l.y / R.y, l.z / R.z)
	var dehors := dans.normalized() if dans.length() > 0.01 else Vector3.UP
	var soleil := Vector3(0.5, 0.75, 0.45).normalized()
	var lumiere := clampf(dehors.dot(soleil) * 0.5 + 0.5, 0.0, 1.0) * clampf(dans.length() * 1.2, 0.4, 1.0)
	var rang := clampi(int((1.0 - lumiere) * 4.0 + r.randf_range(-0.8, 0.8)), 0, 4)
	var teinte: Color = (verts[rang] as Color).lightened(r.randf_range(-0.04, 0.06))
	teinte.a = clampf(vent * (0.5 + 0.5 * dans.length()), 0.0, 1.0)
	var nrm := (dehors + Vector3(0, 0.5, 0) + Vector3(r.randf_range(-0.5, 0.5), 0, r.randf_range(-0.5, 0.5))).normalized()
	var u := nrm.cross(Vector3.RIGHT if absf(nrm.x) < 0.9 else Vector3.FORWARD).normalized().rotated(nrm, r.randf() * TAU)
	var v := nrm.cross(u)
	var normale := (nrm * 0.35 + dehors * 0.65 + Vector3(0, 0.25, 0)).normalized()
	var st := o._s(Outils.FEUILLE)
	var demi := s * 0.75
	for carte in 2:
		# la seconde carte, debout et tournée d'un quart, donne du volume quand on voit la première par la tranche
		var a := u if carte == 0 else v
		var b := v if carte == 0 else (nrm * 0.8 + u * 0.2).normalized()
		var k := float(r.randi() % 64)
		var coins := [q - a * demi - b * demi, q + a * demi - b * demi, q + a * demi + b * demi, q - a * demi + b * demi]
		var f := float(forme)
		var uv := [Vector2(k, f + 0.999), Vector2(k + 0.999, f + 0.999), Vector2(k + 0.999, f), Vector2(k, f)]
		for t in [[0, 1, 2], [0, 2, 3]]:
			for j in t:
				st.set_color(teinte)
				st.set_normal(normale)
				st.set_uv(uv[j])
				st.add_vertex(coins[j])
