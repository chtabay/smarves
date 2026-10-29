extends Node3D
## Une voiture des années 1980, garée telle quelle : on règle voiture, graine et options avant de l'ajouter à la
## scène, elle se bâtit à son entrée dans l'arbre de scène. Les roues sont sur un sol plat à y = 0, le centre de la
## voiture à l'origine, l'avant vers +Z ; en mètres.
##   var v = load(Bibliotheque.scene("voitures-des-annees-80@1", "decor")).instantiate()
##   v.voiture = "berline" ; v.options = {"couleur": "6b1d24"}
##   add_child(v)
## Après la construction, le nœud porte ses métadonnées : voiture, graine, emprise (la taille au sol, Vector2),
## longueur. Des silhouettes génériques de l'époque, sans marque : la citadine trois portes, la compacte à hayon,
## la berline à trois volumes, le grand break, la fourgonnette tôlée, et la suiveuse d'une course cycliste (le
## break et ses vélos sur la galerie). Demandé par la carte de Belley.
const Outils := preload("res://bibliotheque/voitures-des-annees-80/1/outils.gd")

const VOITURES := ["citadine", "compacte", "berline", "break", "fourgonnette", "suiveuse"]

## Les gabarits : longueur, largeur, empattement, rayon des roues, hauteur de la ceinture (le bas des vitres), du
## nez, de la poupe et du toit ; capot (de l'avant au pied du pare-brise), pare_brise (son avancée), coffre (de
## l'arrière au pied de la lunette), lunette (de l'arrière au bout du toit) ; caisse : la hauteur de la caisse
## tôlée de la fourgonnette, 0 sinon.
const GABARITS := {
	"citadine": {"l": 3.55, "w": 1.55, "emp": 2.4, "r": 0.28, "ceinture": 0.86, "nez": 0.68, "poupe": 0.86, "toit": 1.38, "capot": 0.78, "pare_brise": 0.55, "coffre": 0.04, "lunette": 0.24, "caisse": 0.0},
	"compacte": {"l": 3.95, "w": 1.63, "emp": 2.48, "r": 0.29, "ceinture": 0.88, "nez": 0.7, "poupe": 0.88, "toit": 1.4, "capot": 0.95, "pare_brise": 0.6, "coffre": 0.08, "lunette": 0.4, "caisse": 0.0},
	"berline": {"l": 4.5, "w": 1.7, "emp": 2.7, "r": 0.3, "ceinture": 0.9, "nez": 0.72, "poupe": 0.9, "toit": 1.42, "capot": 1.12, "pare_brise": 0.62, "coffre": 0.82, "lunette": 1.28, "caisse": 0.0},
	"break": {"l": 4.75, "w": 1.72, "emp": 2.9, "r": 0.3, "ceinture": 0.92, "nez": 0.72, "poupe": 0.92, "toit": 1.48, "capot": 1.12, "pare_brise": 0.62, "coffre": 0.04, "lunette": 0.14, "caisse": 0.0},
	"fourgonnette": {"l": 3.95, "w": 1.6, "emp": 2.45, "r": 0.28, "ceinture": 0.9, "nez": 0.7, "poupe": 0.9, "toit": 1.45, "capot": 0.75, "pare_brise": 0.5, "coffre": 0.0, "lunette": 0.0, "caisse": 1.82},
}

## Les teintes de l'époque : blanc cassé, rouge, bordeaux, jaune moutarde, orange, bleu ciel, bleu marine, vert
## bouteille, beige, gris métallisé, marron.
const COULEURS := ["efe9dc", "c8102e", "6b1d24", "d9b44a", "c66a2b", "8fb3c9", "2c4a7a", "2f5d3a", "b7ab8f", "8d9196", "6a4b2e"]
const VITRE := Color("2b3640")
const PNEU := Color("1f2022")
const NOIR := Color("2a2b2d")
const CHROME := Color("c9ccd0")
const FER := Color("9aa0a6")
const FER_SOMBRE := Color("3a3d40")
const PHARE := Color("efe8cf")
const FEU := Color("b3221c")
const CLIGNOTANT := Color("e08a1e")
const PLAQUE_AV := Color("f2f0ea")
const PLAQUE_AR := Color("f2c400")
const COULEURS_VELOS := ["d22a2a", "f2c600", "1f4fa0", "1f8a4c", "f4f1ea", "e86a1a"]

## La voiture (voir VOITURES).
@export var voiture := "citadine"
## La graine : la teinte, la plaque, les pare-chocs.
@export var graine := 1
## Les options, toutes facultatives : couleur (un hexa), texte (l'inscription des portières : le nom d'une équipe,
## d'un garage), phares (vrai : allumés), plaque (le numéro, « 1234 AB 01 » au hasard, dans l'Ain), velos (la
## suiveuse : 1 à 5 sur la galerie, 4 par défaut).
@export var options := {}

var fait := false


func _ready() -> void:
	if fait:
		return
	fait = true
	var m := poser(self, Vector3.ZERO, voiture, graine, options)
	for k in m:
		set_meta(k, m[k])


## Les voitures, pour une commune qui les passe en revue.
static func voitures() -> Array:
	return VOITURES.duplicate()


## Les mêmes, sous le nom commun aux autres briques.
static func noms() -> Array:
	return voitures()


## Bâtit une voiture sous parent, son centre en p, l'avant vers +Z (sans rotation : tourner le parent). Rend
## voiture, graine, emprise, longueur.
static func poser(parent: Node3D, p: Vector3, nom: String, g: int, opt := {}) -> Dictionary:
	if not nom in VOITURES:
		nom = "citadine"
	var o := Outils.new(g * 7919 + VOITURES.find(nom) * 131)
	var gab: Dictionary = GABARITS["break" if nom == "suiveuse" else nom]
	var defaut: String = "efe9dc" if nom == "suiveuse" else COULEURS[o.rng.randi() % COULEURS.size()]
	var col := Color(str(opt.get("couleur", defaut)))
	var textes := []
	_caisse(o, p, gab, col, bool(opt.get("phares", false)), nom == "berline" or o.rng.randf() < 0.3)
	if nom == "suiveuse":
		_galerie(o, p, gab, clampi(int(opt.get("velos", 4)), 1, 5))
	var l := float(gab["l"])
	var w := float(gab["w"])
	var plaque := str(opt.get("plaque", "%d %s 01" % [o.rng.randi_range(100, 9899), _lettres(o)]))
	textes.append([Transform3D(Basis(), p + Vector3(0, 0.33, l * 0.5 + 0.105)), plaque, NOIR, 0.0011])
	textes.append([Transform3D(Basis(Vector3.UP, PI), p + Vector3(0, 0.33, -l * 0.5 - 0.105)), plaque, NOIR, 0.0011])
	var texte := str(opt.get("texte", ""))
	if texte != "":
		var t := minf(0.0045, 1.5 / (maxf(texte.length(), 1.0) * 96.0 * 0.6))
		var porte := p + Vector3(0, 0.6, l * 0.5 - float(gab["capot"]) - 0.5)
		textes.append([Transform3D(Basis(Vector3.UP, PI * 0.5), porte + Vector3(w * 0.5 + 0.012, 0, 0)), texte, NOIR if col.get_luminance() > 0.5 else Color("f4f1ea"), t])
		textes.append([Transform3D(Basis(Vector3.UP, -PI * 0.5), porte - Vector3(w * 0.5 + 0.012, 0, 0)), texte, NOIR if col.get_luminance() > 0.5 else Color("f4f1ea"), t])
	o.collisions.append([Transform3D(Basis(), p + Vector3(0, float(gab["toit"]) * 0.5, 0)), Vector3(w, float(gab["toit"]), l)])
	var n := Node3D.new()
	n.name = nom.capitalize()
	parent.add_child(n)
	o.construire(n, nom.capitalize())
	# les inscriptions : [Transform3D, texte, couleur, taille d'un pixel]
	for t in textes:
		var lb := Label3D.new()
		lb.text = t[1]
		lb.font_size = 96
		lb.pixel_size = t[3]
		lb.modulate = t[2]
		lb.outline_size = 0
		lb.double_sided = false
		lb.transform = t[0]
		n.add_child(lb)
	return {"voiture": nom, "graine": g, "emprise": Vector2(w, l), "longueur": l}


static func _lettres(o: Outils) -> String:
	var a := "ABCDEFGHJKLMNPRSTVWXYZ"
	return a[o.rng.randi() % a.length()] + a[o.rng.randi() % a.length()]


## Le repère du profil : x le long de la voiture (vers l'avant), y vers le haut, z en travers (vers -X).
static func _cote(p: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), p)


## Un parallélogramme du profil, de a à b, épais de e le long de la voiture : un montant, un liseré.
static func _montant(a: Vector2, b: Vector2, e: float) -> PackedVector2Array:
	return PackedVector2Array([a, b, b + Vector2(-e, 0), a + Vector2(-e, 0)])


## Un profil posé sur les deux flancs seulement, de e0 à e1 du milieu : un montant qui ne masque pas le pare-brise.
static func _flancs(o: Outils, t: Transform3D, pts: PackedVector2Array, e0: float, e1: float, col: Color) -> void:
	o.profil(t, pts, e0, e1, col)
	o.profil(t, pts, -e1, -e0, col)


## La caisse, le vitrage, les montants, les roues, les feux et les pare-chocs.
static func _caisse(o: Outils, p: Vector3, g: Dictionary, col: Color, phares: bool, chrome: bool) -> void:
	var l := float(g["l"])
	var w := float(g["w"])
	var r := float(g["r"])
	var emp := float(g["emp"])
	var ceinture := float(g["ceinture"])
	var nez := float(g["nez"])
	var poupe := float(g["poupe"])
	var toit := float(g["toit"])
	var caisse := float(g["caisse"])
	var bas := 0.24
	var av := l * 0.5
	var ar := -l * 0.5
	var t := _cote(p)
	var sombre := col.darkened(0.18)
	# le pied du pare-brise, le haut du pare-brise ; le pied de la lunette, le bout du toit
	var pb := av - float(g["capot"])
	var pt := pb - float(g["pare_brise"])
	var lb := ar + float(g["coffre"])
	var lt := ar + float(g["lunette"])
	if caisse > 0.0:
		# la fourgonnette : la cabine s'arrête aux portières, la caisse tôlée monte derrière
		lt = pt - 0.85
		lb = lt - 0.05
	# la caisse : le capot qui plonge en coin vers le nez, les flancs plats, la poupe tranchée
	var flanc := PackedVector2Array([Vector2(ar, bas), Vector2(ar, poupe - 0.06), Vector2(ar + 0.07, poupe), Vector2(ar + 0.2, ceinture),
		Vector2(pb, ceinture), Vector2(av - 0.12, nez), Vector2(av, nez - 0.12), Vector2(av, bas)])
	o.profil(t, flanc, -w * 0.5, w * 0.5, [col, col])
	# le bas de caisse, plus sombre, sous la baguette
	o.profil(t, PackedVector2Array([Vector2(ar + 0.05, bas - 0.04), Vector2(ar + 0.05, bas + 0.12), Vector2(av - 0.05, bas + 0.12), Vector2(av - 0.05, bas - 0.04)]), -w * 0.5 + 0.03, w * 0.5 - 0.03, NOIR)
	# les passages de roue, sombres, un peu plus larges que les pneus
	var essieux := [av - (l - emp) * 0.5 + 0.04, ar + (l - emp) * 0.5 + 0.04]
	for u in essieux:
		var cercle := Outils.arc(Vector2(u, r - 0.02), r + 0.07, 0.0, PI, 10)
		o.profil(t, cercle, -w * 0.5 - 0.004, w * 0.5 + 0.004, Color("141516"))
	# la caisse tôlée de la fourgonnette, ses nervures
	if caisse > 0.0:
		o.profil(t, PackedVector2Array([Vector2(ar, ceinture - 0.1), Vector2(ar, caisse), Vector2(lt + 0.08, caisse), Vector2(lt + 0.08, ceinture - 0.1)]), -w * 0.5, w * 0.5, [col, col])
		o.profil(t, PackedVector2Array([Vector2(ar - 0.01, caisse - 0.04), Vector2(ar - 0.01, caisse + 0.03), Vector2(lt + 0.1, caisse + 0.03), Vector2(lt + 0.1, caisse - 0.04)]), -w * 0.5 - 0.01, w * 0.5 + 0.01, sombre)
		for k in 4:
			var u := ar + 0.25 + k * (lt - ar - 0.2) / 4.0
			o.profil(t, PackedVector2Array([Vector2(u, ceinture), Vector2(u, caisse - 0.12), Vector2(u + 0.05, caisse - 0.12), Vector2(u + 0.05, ceinture)]), -w * 0.5 - 0.008, w * 0.5 + 0.008, sombre)
		o.boite(Transform3D(Basis(), p + Vector3(0, (caisse + bas) * 0.5, ar - 0.005)), Vector3(0.012, caisse - bas - 0.1, 0.012), Color("141516"))
	# le vitrage : une seule pièce sombre, puis le toit et les montants à la couleur de la caisse par-dessus
	var vitre := w * 0.5 - 0.08
	o.profil(t, PackedVector2Array([Vector2(lb, ceinture), Vector2(lt, toit), Vector2(pt, toit), Vector2(pb, ceinture)]), -vitre, vitre, VITRE)
	var bord := w * 0.5 - 0.065
	o.profil(t, PackedVector2Array([Vector2(lt - 0.02, toit - 0.03), Vector2(lt - 0.02, toit + 0.035), Vector2(pt + 0.03, toit + 0.035), Vector2(pt + 0.03, toit - 0.03)]), -bord, bord, [col, col])
	_flancs(o, t, _montant(Vector2(pb + 0.04, ceinture), Vector2(pt + 0.03, toit), 0.09), vitre - 0.01, bord, col)
	var b := lerpf(pt, lt, 0.42) if caisse <= 0.0 else lt + 0.12
	var b_bas := b + (pb - pt) * 0.08
	_flancs(o, t, _montant(Vector2(b_bas + 0.05, ceinture), Vector2(b + 0.05, toit), 0.1), vitre - 0.01, bord, col)
	if caisse <= 0.0:
		# le montant arrière : large sur la citadine et la berline, et le break a sa custode
		var large := 0.26 if float(g["lunette"]) - float(g["coffre"]) < 0.3 else 0.16
		_flancs(o, t, PackedVector2Array([Vector2(lb, ceinture), Vector2(lt - 0.02, toit), Vector2(lt + large * 0.6, toit), Vector2(lb + large, ceinture)]), vitre - 0.01, bord, col)
		if lt - ar < 0.3 and b - lt > 1.2:
			var c := lerpf(lt, b, 0.45)
			_flancs(o, t, _montant(Vector2(c + 0.05, ceinture), Vector2(c + 0.05, toit), 0.1), vitre - 0.01, bord, col)
	# les portières : leurs joints, la poignée
	for u in [pb - 0.02, b_bas - 0.02]:
		o.profil(t, PackedVector2Array([Vector2(u, bas + 0.12), Vector2(u, ceinture), Vector2(u + 0.012, ceinture), Vector2(u + 0.012, bas + 0.12)]), -w * 0.5 - 0.003, w * 0.5 + 0.003, sombre.darkened(0.3))
	if l > 3.8 and caisse <= 0.0:
		var u2 := lerpf(b_bas, ar + 0.6, 0.85)
		o.profil(t, PackedVector2Array([Vector2(u2, bas + 0.12), Vector2(u2, ceinture), Vector2(u2 + 0.012, ceinture), Vector2(u2 + 0.012, bas + 0.12)]), -w * 0.5 - 0.003, w * 0.5 + 0.003, sombre.darkened(0.3))
	for cote in [-1.0, 1.0]:
		o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 + 0.01), ceinture - 0.08, b_bas - 0.2)), Vector3(0.02, 0.03, 0.14), NOIR)
		# la baguette de protection le long du flanc
		o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 + 0.006), 0.56, 0)), Vector3(0.012, 0.05, l - 0.5), NOIR)
		# le rétroviseur
		o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 + 0.07), ceinture + 0.1, pb - 0.12)), Vector3(0.1, 0.09, 0.05), NOIR)
		o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 + 0.02), ceinture + 0.06, pb - 0.1)), Vector3(0.06, 0.03, 0.03), NOIR)
	# les roues : le pneu, l'enjoliveur, quatre écrous
	var tourne := Basis(Vector3.BACK, -PI * 0.5)
	var enjoliveur := CHROME if chrome else Color("8a8e92")
	for u in essieux:
		for cote in [-1.0, 1.0]:
			var pied := p + Vector3(cote * (w * 0.5 - 0.16) if cote > 0.0 else -w * 0.5 - 0.01, r - 0.025, u)
			o.cylindre(Transform3D(tourne, pied), r, r, 0.17, 14, PNEU)
			var face := p + Vector3(cote * (w * 0.5 + 0.01), r - 0.025, u)
			o.cylindre(Transform3D(Basis(Vector3.BACK, -PI * 0.5 * cote), face), r * 0.62, r * 0.5, 0.012, 12, enjoliveur)
	# l'avant : la calandre, les phares carrés, les clignotants, le pare-chocs et la plaque blanche
	var lueur := Outils.LUEUR if phares else Outils.DUR
	var h_feux := nez - 0.17
	o.boite(Transform3D(Basis(), p + Vector3(0, h_feux, av + 0.005)), Vector3(w * 0.42, 0.13, 0.02), Color("1a1b1d"))
	for k in 4:
		o.boite(Transform3D(Basis(), p + Vector3(0, h_feux - 0.045 + k * 0.03, av + 0.017)), Vector3(w * 0.4, 0.008, 0.008), FER_SOMBRE)
	for cote in [-1.0, 1.0]:
		o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 - 0.26), h_feux, av + 0.008)), Vector3(0.3, 0.14, 0.02), CHROME)
		o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 - 0.26), h_feux, av + 0.014)), Vector3(0.27, 0.115, 0.02), PHARE, lueur)
		o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 - 0.06), h_feux, av - 0.01)), Vector3(0.09, 0.1, 0.04), CLIGNOTANT)
	var pc := CHROME if chrome else NOIR
	o.boite(Transform3D(Basis(), p + Vector3(0, 0.33, av + 0.04)), Vector3(w + 0.03, 0.13, 0.12), pc)
	o.boite(Transform3D(Basis(), p + Vector3(0, 0.33, av + 0.102)), Vector3(0.52, 0.11, 0.008), PLAQUE_AV)
	# l'arrière : les feux rouges et orange, le pare-chocs et la plaque jaune
	var h_ar := poupe - 0.2 if caisse <= 0.0 else 0.62
	for cote in [-1.0, 1.0]:
		o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 - 0.2), h_ar, ar - 0.008)), Vector3(0.3, 0.17, 0.02), FEU)
		o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 - 0.39), h_ar, ar - 0.008)), Vector3(0.08, 0.17, 0.02), CLIGNOTANT)
	o.boite(Transform3D(Basis(), p + Vector3(0, 0.33, ar - 0.04)), Vector3(w + 0.03, 0.13, 0.12), pc)
	o.boite(Transform3D(Basis(), p + Vector3(0, 0.33, ar - 0.102)), Vector3(0.52, 0.11, 0.008), PLAQUE_AR)
	o.boite(Transform3D(Basis(), p + Vector3(-w * 0.3, 0.2, ar - 0.15)), Vector3(0.05, 0.05, 0.16), FER_SOMBRE)


## La galerie de la suiveuse et ses vélos debout, roues dans les gouttières, et les roues de rechange.
static func _galerie(o: Outils, p: Vector3, g: Dictionary, n: int) -> void:
	var l := float(g["l"])
	var w := float(g["w"])
	var toit := float(g["toit"]) + 0.035
	var av := l * 0.5 - float(g["capot"]) - float(g["pare_brise"])
	var ar := -l * 0.5 + float(g["lunette"])
	var h := toit + 0.12
	for z in [av - 0.15, ar + 0.2]:
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(cote * (w * 0.5 - 0.12), toit + 0.06, z)), Vector3(0.05, 0.12, 0.05), NOIR)
		o.branche(p + Vector3(-w * 0.5 + 0.05, h, z), p + Vector3(w * 0.5 - 0.05, h, z), 0.018, 0.018, FER, 6)
	var pas := minf(0.36, (w - 0.25) / maxf(n - 1, 1))
	for i in n:
		var x := (i - (n - 1) * 0.5) * pas
		o.boite(Transform3D(Basis(), p + Vector3(x, h + 0.02, (av + ar) * 0.5)), Vector3(0.06, 0.03, av - ar + 0.25), FER_SOMBRE)
		# alternés tête-bêche, comme on les sangle
		var sens := Basis() if i % 2 == 0 else Basis(Vector3.UP, PI)
		_velo(o, Transform3D(sens, p + Vector3(x, h + 0.03, (av + ar) * 0.5 + 0.05)), Color(COULEURS_VELOS[(i + o.rng.randi()) % COULEURS_VELOS.size()]))
	# les roues de rechange à l'arrière de la galerie, en travers
	for k in 2:
		var c := p + Vector3(-w * 0.5 + 0.12 + k * 0.08, h + 0.36, ar + 0.08)
		o.anneau(Transform3D(Basis(Vector3.BACK, -PI * 0.5), c), 0.31, 0.34, 0.025, 18, PNEU)
		o.anneau(Transform3D(Basis(Vector3.BACK, -PI * 0.5), c), 0.28, 0.31, 0.02, 18, CHROME)


## Le vélo de course, comme celui de course-cycliste@1 : debout, roues sur le sol du repère t, l'avant vers +Z.
static func _velo(o: Outils, t: Transform3D, col: Color) -> void:
	var rr := 0.34
	var ar := t * Vector3(0, rr, -0.5)
	var av := t * Vector3(0, rr, 0.5)
	var pedalier := t * Vector3(0, 0.29, -0.06)
	var selle := t * Vector3(0, 0.86, -0.22)
	var tete := t * Vector3(0, 0.84, 0.36)
	var douille := t * Vector3(0, 0.7, 0.4)
	var roue := Basis(Vector3.BACK, -PI * 0.5)
	for c in [ar, av]:
		var tr := Transform3D(t.basis * roue, c - t.basis * Vector3(0.012, 0, 0))
		o.anneau(tr, rr - 0.025, rr, 0.024, 20, PNEU)
		o.anneau(tr, rr - 0.06, rr - 0.025, 0.02, 20, CHROME)
		o.cylindre(Transform3D(t.basis * roue, c - t.basis * Vector3(0.05, 0, 0)), 0.025, 0.025, 0.1, 6, FER)
		for k in 8:
			var a := TAU * k / 8.0
			o.branche(c, c + t.basis * Vector3(0, cos(a), sin(a)) * (rr - 0.05), 0.003, 0.003, FER, 3)
	var tube := 0.016
	o.branche(pedalier, selle, tube, tube, col, 5)
	o.branche(pedalier, douille, tube * 1.1, tube, col, 5)
	o.branche(selle, tete, tube, tube, col, 5)
	o.branche(tete, douille, tube * 1.2, tube * 1.2, col, 5)
	for cote in [-0.05, 0.05]:
		var dc := t.basis * Vector3(cote, 0, 0)
		o.branche(pedalier + dc, ar + dc, 0.01, 0.01, col, 4)
		o.branche(selle + dc * 0.4, ar + dc, 0.009, 0.009, col, 4)
		o.branche(douille + dc * 0.6, av + dc, 0.011, 0.009, col.darkened(0.1), 4)
	o.branche(selle, selle + t.basis * Vector3(0, 0.1, -0.02), 0.012, 0.012, FER, 4)
	o.boite(Transform3D(t.basis, selle + t.basis * Vector3(0, 0.12, 0)), Vector3(0.12, 0.04, 0.27), NOIR)
	var potence := tete + t.basis * Vector3(0, 0.06, 0.08)
	o.branche(tete, potence, 0.012, 0.012, FER, 4)
	o.branche(potence + t.basis * Vector3(-0.2, 0, 0), potence + t.basis * Vector3(0.2, 0, 0), 0.012, 0.012, NOIR, 5)
	o.cylindre(Transform3D(t.basis * roue, pedalier - t.basis * Vector3(0.07, 0, 0)), 0.1, 0.1, 0.01, 12, FER)
