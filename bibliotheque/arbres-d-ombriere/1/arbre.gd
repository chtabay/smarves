extends Node3D
## Un arbre d'ombrière, posé tel quel : on règle arbre, graine et options avant de l'ajouter à la scène, il se
## bâtit à son entrée dans l'arbre de scène. Le pied est à l'origine, sur un sol plat à y = 0 ; en mètres.
##   var a = load(Bibliotheque.scene("arbres-d-ombriere@1", "decor")).instantiate()
##   a.arbre = "platane" ; a.graine = 7
##   add_child(a)
## Après la construction, le nœud porte ses métadonnées : arbre, graine, hauteur, couronne (le rayon de la
## couronne, pour espacer une rangée).
## Tiré de l'image de la place Saint-Étienne de Guillaume : une charpente de branches claires qu'on voit, portant
## des centaines de petites touffes vert-jaune espacées, où le ciel passe et d'où tombe une ombre tachetée. Le pied
## se pose dans une fosse (sols-toulousains@1, « fosse_arbre ») ou dans l'herbe d'un jardin.
const Outils := preload("res://bibliotheque/arbres-d-ombriere/1/outils.gd")

## Les arbres : le grand platane d'ombrière des places (18 à 22 m, couronne en dôme très large), le micocoulier
## des jardins et des cours (10 à 12 m, couronne ronde), le jeune platane d'un mail récent (9 à 11 m), et le
## marronnier des cours et des places lyonnaises (12 à 18 m, couronne large et irrégulière, tronc sombre, feuilles
## palmées à sept folioles).
const ARBRES := ["platane", "micocoulier", "jeune_platane", "marronnier"]

## Les verts, du dessus au soleil au cœur à l'ombre.
const VERTS := {
	"platane": ["6f9c36", "5e8a2e", "4d7426", "3e5e22", "2f4a1e"],
	"micocoulier": ["c4df5a", "aacf4a", "91bd3f", "7aa836", "669430"],
	"jeune_platane": ["78a43a", "659132", "547c2a", "446624", "34511f"],
	"marronnier": ["a6c852", "8cb246", "73993b", "5e8433", "4b6e2b"],
}
const ECORCE := {"platane": "c9bea0", "micocoulier": "9a978a", "jeune_platane": "c9bea0", "marronnier": "5a4f46"}
## La forme des feuilles dans le shader : 0 la feuille lobée du platane, 1 la feuille palmée du marronnier.
const FORMES := {"platane": 0, "micocoulier": 0, "jeune_platane": 0, "marronnier": 1}
const PLAQUES := ["b5b08e", "bfb596", "a9a888", "ddd3b8", "d0c4a4"]

## L'arbre (voir ARBRES).
@export var arbre := "platane"
## La graine : deux arbres de même nom et de graines différentes ne se ressemblent pas.
@export var graine := 1
## Les options, toutes facultatives : hauteur (en mètres), vent (0 à 1, l'amplitude du souffle), densite (0,5 à
## 1,5 : le nombre de touffes, 1 par défaut ; moins de touffes, plus de ciel), contre_jour (0 à 1 : la lumière qui
## traverse les feuilles, 0,15 par défaut).
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
		nom = "platane"
	var o := Outils.new(g * 7919 + ARBRES.find(nom) * 31 + 3)
	var r := o.rng
	# hauteur, fût, ouverture des charpentières, rayon de la couronne (horizontal, vertical), niveaux de ramure
	var gabarit: Dictionary = {
		"platane": {"h": 20.0, "fut": 0.3, "rt": 0.032, "n": 5, "ouverture": 0.95, "R": Vector2(0.46, 0.34), "touffes": 620, "taille": 1.6},
		"micocoulier": {"h": 11.0, "fut": 0.24, "rt": 0.03, "n": 4, "ouverture": 0.8, "R": Vector2(0.42, 0.36), "touffes": 400, "taille": 1.25},
		"jeune_platane": {"h": 10.0, "fut": 0.32, "rt": 0.026, "n": 4, "ouverture": 0.7, "R": Vector2(0.34, 0.34), "touffes": 300, "taille": 1.2},
		"marronnier": {"h": 15.0, "fut": 0.2, "rt": 0.036, "n": 5, "ouverture": 0.85, "R": Vector2(0.42, 0.37), "touffes": 340, "taille": 1.7},
	}[nom]
	var h := float(opt.get("hauteur", float(gabarit["h"]) * r.randf_range(0.9, 1.1)))
	var vent := float(opt.get("vent", 1.0))
	var verts: Array = VERTS[nom].map(func(x): return Color(x))
	var ec := Color(ECORCE[nom])
	var fut := h * float(gabarit["fut"])
	var rt := h * float(gabarit["rt"])
	var Rv: Vector2 = gabarit["R"]
	var R := Vector3(h * Rv.x, h * Rv.y, h * Rv.x)
	# le centre de la couronne : le dôme pose son bas un peu au-dessus du fût
	var c := p + Vector3(0, fut + R.y * 0.9, 0)

	# le fût, son empattement, ses plaques d'écorce (le platane se marbre, le micocoulier reste lisse)
	o.branche(p + Vector3(0, -0.3, 0), p + Vector3(0, fut, 0), rt * 1.15, rt, ec, 10)
	o.cylindre(Transform3D(Basis(), p), rt * 1.75, rt * 1.15, 0.45, 10, ec.darkened(0.12), Outils.DUR, false)
	if nom == "marronnier":
		# l'écorce du marronnier se fend en longues lanières sombres, qui vrillent un peu
		for i in 36:
			var y := r.randf_range(0.2, fut)
			var a := r.randf() * TAU
			var b := Basis(Vector3.UP, a) * Basis(Vector3.BACK, r.randf_range(-0.12, 0.12))
			var rr := lerpf(rt * 1.15, rt, y / fut) + 0.005
			o.boite(Transform3D(b, p + Vector3(0, y, 0) + b * Vector3(0, 0, rr)), Vector3(rr * 0.12, r.randf_range(0.5, 1.4), 0.014), ec.darkened(0.35))
	elif nom != "micocoulier":
		for i in 40:
			var y := r.randf_range(0.3, fut)
			var a := r.randf() * TAU
			var b := Basis(Vector3.UP, a)
			var rr := lerpf(rt * 1.15, rt, y / fut) + 0.006
			o.boite(Transform3D(b, p + Vector3(0, y, 0) + b * Vector3(0, 0, rr)), Vector3(rr * r.randf_range(0.3, 0.7), r.randf_range(0.18, 0.45), 0.012), Color(PLAQUES[r.randi() % PLAQUES.size()]))

	# la charpente : des charpentières en coupe ouverte, chacune se partage deux fois ; les bouts portent les touffes
	var bouts := []
	var n: int = gabarit["n"] + r.randi() % 2
	var ouverture: float = gabarit["ouverture"]
	for i in n:
		var a := TAU * i / n + r.randf_range(-0.35, 0.35)
		var penche := ouverture * r.randf_range(0.75, 1.1)
		var d := Vector3(cos(a) * sin(penche), cos(penche), sin(a) * sin(penche))
		var depart := p + Vector3(0, fut - r.randf_range(0.0, 0.8), 0)
		var l1 := h * r.randf_range(0.24, 0.3)
		_ramure(o, depart, d, l1, rt * 0.72, ec, 0, bouts, c, R)
	# quelques branches courtes au cœur, pour qu'on ne voie pas le vide sous le dôme
	for i in 3:
		var a := r.randf() * TAU
		var d := Vector3(cos(a) * 0.35, 1.0, sin(a) * 0.35).normalized()
		_ramure(o, p + Vector3(0, fut, 0), d, h * 0.2, rt * 0.4, ec, 1, bouts, c, R)

	# les touffes : autour des bouts, et semées dans le dôme près des branches, jamais en masse pleine
	var total := int(float(gabarit["touffes"]) * float(opt.get("densite", 1.0)))
	var taille: float = gabarit["taille"]
	var semees := 0
	var essais := 0
	while semees < total and essais < total * 6:
		essais += 1
		var bout: Vector3 = bouts[r.randi() % bouts.size()]
		var q := bout + Vector3(r.randf_range(-1, 1), r.randf_range(-0.6, 0.9), r.randf_range(-1, 1)) * h * 0.11
		# une touffe sur cinq comble le haut du dôme, que les charpentières ouvertes laissent creux
		if r.randf() < 0.2:
			q = c + Vector3(r.randf_range(-0.6, 0.6) * R.x, r.randf_range(0.35, 0.95) * R.y, r.randf_range(-0.6, 0.6) * R.z)
		# ramenée dans le dôme : un ellipsoïde au bas aplati
		var l := q - c
		var e := Vector3(l.x / R.x, l.y / (R.y * (1.0 if l.y > 0.0 else 0.75)), l.z / R.z)
		if e.length() > 1.05:
			continue
		# le cœur reste clair de touffes : on n'y garde qu'une touffe sur quatre
		if e.length() < 0.55 and e.y < 0.25 and r.randf() < 0.75:
			continue
		var s := taille * r.randf_range(0.7, 1.3) * (0.85 + 0.3 * e.length())
		# sous la couronne, près du joueur, des cartes plus petites d'un tiers et plus
		if e.y < 0.0:
			s *= lerpf(1.0, 0.62, clampf(-e.y * 2.0, 0.0, 1.0))
		_touffe(o, q, s, verts, c, R, vent, FORMES[nom])
		semees += 1

	o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.5, 0)), Vector3(rt * 2.2, 3.0, rt * 2.2)])
	var mi := o.construire(parent, nom.capitalize())
	mi.set_instance_shader_parameter("contre_jour", float(opt.get("contre_jour", 0.15)))
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


## Une touffe : deux cartes croisées où le shader du feuillage dessine cinq à sept feuilles de platane en dentelle,
## ou deux à trois feuilles palmées de marronnier (UV.x porte la variante de la carte, UV.y la forme dans sa partie
## paire), tournées vers le dehors de la couronne. Les normales penchent vers le dehors du dôme, pour une ombre
## douce de dessin ; le dessus et le côté du soleil sont plus clairs, le dessous et le cœur plus sombres.
static func _touffe(o: Outils, q: Vector3, s: float, verts: Array, c: Vector3, R: Vector3, vent: float, forme := 0) -> void:
	var r := o.rng
	var l := q - c
	var dans := Vector3(l.x / R.x, l.y / R.y, l.z / R.z)
	var dehors := dans.normalized() if dans.length() > 0.01 else Vector3.UP
	var soleil := Vector3(0.5, 0.75, 0.45).normalized()
	var lumiere := clampf(dehors.dot(soleil) * 0.5 + 0.5, 0.0, 1.0) * clampf(dans.length() * 1.2, 0.4, 1.0)
	# la lumière en aplats du shader fait déjà le côté du soleil : le rang de vert ne fait que nuancer
	var rang := clampi(int((1.0 - lumiere) * 2.6 + r.randf_range(-0.6, 0.9)), 0, 4)
	var teinte: Color = (verts[rang] as Color).lightened(r.randf_range(-0.04, 0.06))
	teinte.a = clampf(vent * (0.5 + 0.5 * dans.length()), 0.0, 1.0)
	var nrm := (dehors + Vector3(0, 0.5, 0) + Vector3(r.randf_range(-0.5, 0.5), 0, r.randf_range(-0.5, 0.5))).normalized()
	var u := nrm.cross(Vector3.RIGHT if absf(nrm.x) < 0.9 else Vector3.FORWARD).normalized().rotated(nrm, r.randf() * TAU)
	var v := nrm.cross(u)
	# les normales suivent le dôme plus que la carte : les aplats de lumière dessinent de grandes masses
	var normale := (nrm * 0.12 + dehors * 0.88 + Vector3(0, 0.2, 0)).normalized()
	var st := o._s(Outils.FEUILLE)
	var demi := s * 0.75
	for carte in 2:
		# la seconde carte, debout et tournée d'un quart, donne du volume quand on voit la première par la tranche
		var a := u if carte == 0 else v
		var b := v if carte == 0 else (nrm * 0.8 + u * 0.2).normalized()
		var k := float(r.randi() % 64)
		var coins := [q - a * demi - b * demi, q + a * demi - b * demi, q + a * demi + b * demi, q - a * demi + b * demi]
		var f := forme * 2.0
		var uv := [Vector2(k, f + 1), Vector2(k + 0.999, f + 1), Vector2(k + 0.999, f), Vector2(k, f)]
		for t in [[0, 1, 2], [0, 2, 3]]:
			for j in t:
				st.set_color(teinte)
				st.set_normal(normale)
				st.set_uv(uv[j])
				st.add_vertex(coins[j])
