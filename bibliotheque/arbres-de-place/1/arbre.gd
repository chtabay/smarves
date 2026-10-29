extends Node3D
## Un arbre de la place du nord, posé tel quel : on règle espece, graine et options avant de l'ajouter à la
## scène, il se bâtit à son entrée dans l'arbre de scène. Le pied est à l'origine, sur un sol plat à y = 0 ;
## en mètres (une commune à l'échelle du village de Smarves, 1 unité = 2,4 m, le pose à l'échelle 1/2,4).
##   var a = load(Bibliotheque.scene("arbres-de-place@1", "decor")).instantiate()
##   a.espece = "tilleul" ; a.graine = 7 ; a.options = {"pied": "grille"}
##   add_child(a)
## Après la construction, le nœud porte ses métadonnées : espece, graine, hauteur, couronne (le rayon de la
## couronne, pour espacer une rangée).
const Outils := preload("res://bibliotheque/arbres-de-place/1/outils.gd")

## Les espèces : la touffe ronde d'un tilleul, le bouleau blanc, le marronnier large et sombre, la boule taillée
## d'un charme sur sa tige, l'if en cône.
const ESPECES := ["tilleul", "bouleau", "marronnier", "boule", "if"]

## Les verts de la place, du plus clair au plus sombre, par espèce.
const VERTS := {
	"tilleul": ["a9dc5a", "8fcf47", "7cc23c", "69b032"],
	"bouleau": ["b7e26b", "9fd655", "8acb48", "76b83c"],
	"marronnier": ["7fbf45", "6aae38", "5a9c30", "4b8a2a"],
	"boule": ["8fcf47", "7cc23c", "69b032", "5aa02b"],
	"if": ["4f8a3a", "457d33", "3b6f2c", "325f26"],
}
## Les écorces : le fût, et une seconde teinte (les taches du bouleau, le pied plus sombre).
const ECORCES := {
	"tilleul": ["7a6450", "5e4c3c"], "bouleau": ["ece8dc", "33302c"], "marronnier": ["6e5a48", "54453a"],
	"boule": ["7a6450", "5e4c3c"], "if": ["7d4f3a", "5a3a2b"],
}

## L'espèce (voir ESPECES).
@export var espece := "tilleul"
## La graine : deux arbres de même espèce et de graines différentes ne se ressemblent pas.
@export var graine := 1
## Les options, toutes facultatives : hauteur (en mètres ; sinon celle de l'espèce, un peu variée), pied
## (« » : la terre seule ; « grille » : une grille de fonte au ras du pavé ; « bordure » : une bordure de pierre
## et un tapis de fleurs), fleurs (la couleur du tapis de fleurs, un hexa), vent (0 à 1, l'amplitude du souffle).
@export var options := {}

var fait := false


func _ready() -> void:
	if fait:
		return
	fait = true
	var m := arbre(self, Vector3.ZERO, espece, graine, options)
	for k in m:
		set_meta(k, m[k])


## Bâtit un arbre sous parent, son pied en p. Rend ses mesures : espece, graine, hauteur, couronne.
static func arbre(parent: Node3D, p: Vector3, esp: String, gr: int, opt := {}) -> Dictionary:
	if not esp in ESPECES:
		esp = "tilleul"
	var o := Outils.new(gr * 7919 + ESPECES.find(esp))
	var r := o.rng
	var verts: Array = VERTS[esp].map(func(h): return Color(h))
	var ec := Color(ECORCES[esp][0])
	var ec2 := Color(ECORCES[esp][1])
	var vent := float(opt.get("vent", 1.0))
	var defaut: float = {"tilleul": 7.0, "bouleau": 8.5, "marronnier": 8.0, "boule": 3.6, "if": 5.0}[esp]
	var h := float(opt.get("hauteur", defaut * r.randf_range(0.88, 1.12)))
	var k: float = h / defaut
	var couronne := 0.0
	var penche := Vector3(r.randf_range(-1, 1), 0, r.randf_range(-1, 1)).normalized() * (0.06 if esp == "bouleau" else 0.02)
	match esp:
		"tilleul", "marronnier":
			var large := esp == "marronnier"
			var fut := h * (0.3 if large else 0.34)
			var R := Vector3(h * (0.42 if large else 0.36), h * (0.34 if large else 0.37), h * (0.42 if large else 0.36))
			R.x *= r.randf_range(0.9, 1.1)
			R.z *= r.randf_range(0.9, 1.1)
			var c := p + Vector3(0, fut + R.y * 0.95, 0) + penche * h
			var rt: float = 0.13 * k * (1.25 if large else 1.0)
			o.branche(p + Vector3(0, -0.2, 0), p + Vector3(0, fut, 0) + penche * fut, rt * 1.25, rt, ec, 8)
			o.cylindre(Transform3D(Basis(), p), rt * 2.0, rt * 1.1, 0.35, 8, ec2, Outils.DUR, false)
			# les maîtresses branches, visibles sous la couronne
			for i in 4:
				var a := TAU * i / 4.0 + r.randf() * 0.8
				var bout := c + Vector3(cos(a) * R.x * 0.55, R.y * r.randf_range(-0.1, 0.35), sin(a) * R.z * 0.55)
				o.branche(p + Vector3(0, fut, 0) + penche * fut, bout, rt * 0.7, rt * 0.25, ec, 5)
			o.boule(c, R * 0.82, verts[3], 0.1, Outils.FEUILLE, 0.04, vent * 0.5)
			var n := 13 + r.randi() % 5
			for i in n:
				var y := r.randf_range(-0.45, 1.0)
				var a := r.randf() * TAU
				var rr := sqrt(maxf(0.0, 1.0 - y * y))
				var d := Vector3(cos(a) * rr, y, sin(a) * rr)
				var s := r.randf_range(0.36, 0.52)
				var teinte: Color = verts[clampi(int((1.0 - (y * 0.5 + 0.5)) * 3.0 + r.randf_range(-0.6, 0.6)), 0, 3)]
				o.boule(c + Vector3(d.x * R.x, d.y * R.y, d.z * R.z) * 0.62, R * s, teinte, 0.16, Outils.FEUILLE, 0.06, vent)
			couronne = maxf(R.x, R.z)
		"bouleau":
			# un ou deux troncs blancs un peu penchés, la couronne en touffes étagées et légères
			var troncs := 1 + (1 if r.randf() < 0.35 else 0)
			for t in troncs:
				var dec := Vector3(r.randf_range(-0.25, 0.25), 0, r.randf_range(-0.25, 0.25)) if troncs > 1 else Vector3.ZERO
				var pt := penche + dec * 0.12
				var haut := p + dec + Vector3(0, h * 0.9, 0) + pt * h
				var rt: float = 0.11 * k
				o.branche(p + dec + Vector3(0, -0.2, 0), haut, rt, rt * 0.35, ec, 7)
				# les taches noires de l'écorce
				for i in 7:
					var y := r.randf_range(0.3, h * 0.65)
					var at := p + dec + Vector3(0, y, 0) + pt * y
					var rr := lerpf(rt, rt * 0.35, y / (h * 0.9)) + 0.004
					var a := r.randf() * TAU
					var b := Basis(Vector3.UP, a)
					o.boite(Transform3D(b, at + b * Vector3(0, 0, rr)), Vector3(rr * r.randf_range(0.8, 1.4), 0.05, 0.02), ec2)
				for i in 9:
					var y := r.randf_range(0.42, 0.98)
					var a := r.randf() * TAU
					var ecart := h * 0.22 * sin(PI * y) * r.randf_range(0.6, 1.1)
					var cc := p + dec + Vector3(cos(a) * ecart, h * y, sin(a) * ecart) + pt * h * y
					var tige := p + dec + Vector3(0, h * y * 0.85, 0) + pt * h * y * 0.85
					o.branche(tige, cc, rt * 0.3, rt * 0.12, ec, 4)
					var s := h * r.randf_range(0.12, 0.17) * (1.0 - absf(y - 0.7) * 0.6)
					o.boule(cc, Vector3(s, s * 0.95, s), verts[r.randi() % 4], 0.2, Outils.FEUILLE, 0.07, vent)
			couronne = h * 0.3
		"boule":
			var fut := h * 0.5
			var rt: float = 0.07 * k
			o.branche(p + Vector3(0, -0.2, 0), p + Vector3(0, fut + 0.2, 0), rt, rt * 0.8, ec, 6)
			var R := h * 0.27
			var c := p + Vector3(0, fut + R * 0.85, 0)
			o.boule(c, Vector3(R, R * 0.95, R), verts[1], 0.05, Outils.FEUILLE, 0.03, vent * 0.4)
			for i in 6:
				var a := TAU * i / 6.0 + r.randf()
				var y := r.randf_range(-0.2, 0.7)
				o.boule(c + Vector3(cos(a) * R * 0.45, y * R * 0.5, sin(a) * R * 0.45), Vector3.ONE * R * 0.6, verts[r.randi() % 3], 0.08, Outils.FEUILLE, 0.04, vent * 0.4)
			couronne = R
		"if":
			o.branche(p + Vector3(0, -0.2, 0), p + Vector3(0, h * 0.25, 0), 0.12 * k, 0.1 * k, ec, 6)
			var etages := 5
			for i in etages:
				var f := float(i) / etages
				var rr := h * 0.26 * (1.0 - f * 0.8)
				var c := p + Vector3(0, h * (0.28 + f * 0.62), 0)
				o.boule(c, Vector3(rr, h * 0.16, rr), verts[clampi(3 - i, 0, 3)], 0.12, Outils.FEUILLE, 0.05, vent * 0.3)
			couronne = h * 0.26
	var pied := str(opt.get("pied", ""))
	if pied == "grille":
		var t := Transform3D(Basis(), p)
		o.cylindre(t, 0.62, 0.62, 0.03, 16, Color("2c2f30"), Outils.DUR)
		for i in 12:
			var a := TAU * i / 12.0
			var b := Basis(Vector3.UP, -a)
			o.boite(Transform3D(b, p + Vector3(cos(a), 0, sin(a)) * 0.42 + Vector3(0, 0.04, 0)), Vector3(0.36, 0.02, 0.03), Color("1f2223"))
		o.anneau(t, 0.62, 0.72, 0.05, 16, Color("cbbf9f"))
	elif pied == "bordure":
		var t := Transform3D(Basis(), p)
		o.anneau(t, 0.95, 1.15, 0.28, 16, Color("d8cba8"))
		o.cylindre(t, 0.95, 0.95, 0.2, 16, Color("6b4f36"), Outils.DUR)
		var fleur := Color(str(opt.get("fleurs", ["e88aa8", "b06ad0", "f2c14e", "f4f0e6"][o.rng.randi() % 4])))
		for i in 10:
			var a := TAU * i / 10.0 + o.rng.randf() * 0.3
			var q := p + Vector3(cos(a), 0, sin(a)) * o.rng.randf_range(0.55, 0.78) + Vector3(0, 0.26, 0)
			o.boule(q, Vector3(0.22, 0.14, 0.22), Color("5f9e33"), 0.2, Outils.FEUILLE, 0.05, 0.2)
			o.boule(q + Vector3(0, 0.08, 0), Vector3(0.14, 0.07, 0.14), fleur, 0.3, Outils.FEUILLE, 0.1, 0.2)
	o.collisions.append([Transform3D(Basis(), p + Vector3(0, 1.2, 0)), Vector3(0.4, 2.4, 0.4) * clampf(k, 0.6, 1.4)])
	o.construire(parent, "Arbre")
	return {"espece": esp, "graine": gr, "hauteur": h, "couronne": couronne}


## Les espèces, pour une commune qui les tire au hasard.
static func especes() -> Array:
	return ESPECES.duplicate()
