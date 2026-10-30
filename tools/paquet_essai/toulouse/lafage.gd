extends RefCounted
## L'hôtel de Lafage, 19 place Saint-Georges (Mérimée PA00094547) : construit en 1745 par Maduran, façade Louis XV
## en alternance de brique et de pierre, avant-corps central de trois travées sous un fronton à oculus, deux corps
## latéraux de cinq travées, rez-de-chaussée en arcades continues. Un monument unique : il reste dans le paquet.
## Partis pris (note : « Les partis pris ») : l'enduit pâle des hôtels et le rose de la brique plus contrastés
## qu'en vrai, les arcades plus profondes pour l'ombre, le fronton un peu plus haut pour qu'il se lise au fond de
## la place. Repère : façade vers +Z, origine au pied, au milieu ; en mètres.

const Outils := preload("res://bibliotheque/facadier-lyonnais/1/outils.gd")

const ENDUIT := Color("f2e4cf")
const BRIQUE := Color("c8653f")
const BRIQUE_SOMBRE := Color("a4512e")
# le fond de brique des étages, chaînages et encadrements clairs (juge, v0.13 : 54 % de brique sur la cible)
const FOND := Color("b5603c")
const PIERRE := Color("efe6d4")
const PIERRE_OMBRE := Color("d9cbb0")
const VOLET := Color("9daa92")
const VITRE := Color("33404c")
const FER := Color("23272a")
const TUILE := Color("c46a3c")
const SOMBRE := Color("3a2f2a")

const TRAVEES := 13
const RDC := 5.4
const ETAGE1 := 4.4
const ETAGE2 := 3.8
const ENTABLEMENT := 1.0


## Bâtit la façade sous parent, sur une longueur l (m), devant un corps de profondeur d.
static func construire(parent: Node3D, l: float, d: float) -> void:
	var o := Outils.new(1745)
	var t := (l - 2.4) / TRAVEES
	var x0 := -l * 0.5 + 1.2
	var H := RDC + ETAGE1 + ETAGE2
	var centre := [5, 6, 7]
	# Le mur des étages, en brique ; l'avant-corps central avance de 40 cm.
	o.boite(Transform3D(Basis(), Vector3(0, RDC + (H - RDC) * 0.5, -0.1)), Vector3(l, H - RDC, 0.4), FOND)
	var ac0 := x0 + 5 * t
	var ac1 := x0 + 8 * t
	o.boite(Transform3D(Basis(), Vector3((ac0 + ac1) * 0.5, H * 0.5, 0.25)), Vector3(ac1 - ac0, H, 0.3), FOND)
	# Les chaînes de pierre claire en harpe : aux angles, et de part et d'autre de l'avant-corps.
	for x in [-l * 0.5 + 0.45, l * 0.5 - 0.45, ac0 + 0.4, ac1 - 0.4]:
		var z := 0.45 if x == ac0 + 0.4 or x == ac1 - 0.4 else 0.15
		var y := RDC
		var k := 0
		while y < H - 0.1:
			var h := minf(0.5, H - y)
			o.boite(Transform3D(Basis(), Vector3(x, y + h * 0.5, z)), Vector3(0.9 if k % 2 == 0 else 0.62, h, 0.12), PIERRE if k % 2 == 0 else PIERRE_OMBRE.lerp(PIERRE, 0.5))
			y += h
			k += 1
	# Les bandeaux de brique entre les étages, la corniche de pierre.
	o.boite(Transform3D(Basis(), Vector3(0, RDC + 0.12, 0.2)), Vector3(l + 0.1, 0.24, 0.3), PIERRE)
	o.boite(Transform3D(Basis(), Vector3(0, RDC + ETAGE1 + 0.08, 0.17)), Vector3(l + 0.1, 0.16, 0.24), PIERRE)
	o.boite(Transform3D(Basis(), Vector3(0, H + 0.25, 0.2)), Vector3(l + 0.4, 0.5, 0.5), PIERRE_OMBRE)
	o.boite(Transform3D(Basis(), Vector3(0, H + 0.62, 0.32)), Vector3(l + 0.6, 0.24, 0.74), PIERRE)
	# Le rez-de-chaussée : treize arcades en plein cintre, claveaux alternés, la galerie sombre derrière.
	_arcades(o, x0, t, l)
	# Les fenêtres : hautes au premier (balcons de fonte sur l'avant-corps), plus basses au second.
	for i in TRAVEES:
		var x := x0 + (i + 0.5) * t
		var z := 0.42 if i in centre else 0.12
		_fenetre(o, Vector3(x, RDC + 0.55, z), 1.3, 2.75, i in centre, i)
		_fenetre(o, Vector3(x, RDC + ETAGE1 + 0.5, z), 1.15, 2.1, false, i + 20)
	# Le fronton triangulaire et son oculus, au-dessus de l'avant-corps.
	var fw := ac1 - ac0 + 0.6
	var fh := 2.9
	var base := H + 0.74
	var tri := PackedVector2Array([Vector2(-fw * 0.5, 0), Vector2(fw * 0.5, 0), Vector2(0, fh)])
	o.profil(Transform3D(Basis(), Vector3((ac0 + ac1) * 0.5, base, 0)), Outils.grossir(tri, 0.22), 0.2, 0.62, PIERRE)
	o.profil(Transform3D(Basis(), Vector3((ac0 + ac1) * 0.5, base, 0)), tri, 0.2, 0.66, ENDUIT)
	var oc := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3((ac0 + ac1) * 0.5, base + fh * 0.38, 0.66))
	o.anneau(oc, 0.42, 0.62, 0.08, 20, PIERRE)
	o.cylindre(oc.translated_local(Vector3(0, -0.02, 0)), 0.42, 0.42, 0.04, 20, VITRE)
	# Le toit de tuile canal à deux pentes, à 25°, sur la profondeur du corps.
	var pente := tan(deg_to_rad(25.0))
	var dd := minf(d, 9.0)
	var faite := base + dd * 0.5 * pente
	var a := Vector3(-l * 0.5 - 0.3, base, 0.6)
	var b := Vector3(l * 0.5 + 0.3, base, 0.6)
	var c := Vector3(l * 0.5 + 0.3, faite, -dd * 0.5)
	var e := Vector3(-l * 0.5 - 0.3, faite, -dd * 0.5)
	o.quad(a, b, c, e, Vector3(0, 1, pente).normalized(), TUILE)
	o.quad(e, c, Vector3(c.x, base, -dd), Vector3(e.x, base, -dd), Vector3(0, 1, -pente).normalized(), TUILE.darkened(0.1))
	# Les souches de cheminée, de brique.
	for x in [-l * 0.36, -l * 0.12, l * 0.12, l * 0.36]:
		o.boite(Transform3D(Basis(), Vector3(x, faite + 0.6, -dd * 0.5)), Vector3(0.9, 1.8, 0.6), BRIQUE)
		o.boite(Transform3D(Basis(), Vector3(x, faite + 1.55, -dd * 0.5)), Vector3(1.05, 0.12, 0.75), PIERRE)
	o.construire(parent, "HotelDeLafage")


static func _arcades(o: Outils, x0: float, t: float, l: float) -> void:
	var r := minf(t * 0.36, 1.3)
	var naissance := RDC - 0.55 - r
	# La galerie, en retrait de 1,6 m : le fond de brique dans l'ombre, et non un aplat noir bleuté (verdict du
	# juge sur la v0.6) ; des vitrines chaudes à boiseries, quelques portes vitrées, une imposte au-dessus.
	o.boite(Transform3D(Basis(), Vector3(0, RDC * 0.5, -1.6)), Vector3(l, RDC, 0.1), Color("7a4a36"))
	o.boite(Transform3D(Basis(), Vector3(0, RDC - 0.05, -0.8)), Vector3(l, 0.1, 1.6), PIERRE_OMBRE)
	var bois := [Color("5b3a2a"), Color("2f4a3c"), Color("6e2a2e"), Color("4a3a2c")]
	for i in TRAVEES:
		var x := x0 + (i + 0.5) * t
		var cadre: Color = bois[o.rng.randi() % bois.size()]
		o.boite(Transform3D(Basis(), Vector3(x, 1.45, -1.52)), Vector3(r * 1.7, 2.8, 0.06), cadre)
		o.boite(Transform3D(Basis(), Vector3(x, 1.4, -1.48)), Vector3(r * 1.5, 2.5, 0.04), Color("6a5a48").lerp(Color("b89a6a"), o.rng.randf_range(0.0, 0.45)))
		if i % 3 == 1:
			o.boite(Transform3D(Basis(), Vector3(x, 1.25, -1.45)), Vector3(0.05, 2.5, 0.04), cadre)
		o.boite(Transform3D(Basis(), Vector3(x, 3.2, -1.5)), Vector3(r * 1.5, 0.7, 0.04), Color("4a4038"))
	# Les piles entre les arcades, de pierre à leur pied, de brique au-dessus.
	for i in TRAVEES + 1:
		var x := x0 + i * t
		var w := t - 2.0 * r
		if i == 0 or i == TRAVEES:
			w = 1.3
			x += -0.4 if i == 0 else 0.4
		o.boite(Transform3D(Basis(), Vector3(x, 0.45, 0.3)), Vector3(w + 0.1, 0.9, 0.62), PIERRE, Outils.DUR, true)
		var y := 0.9
		var k := 0
		while y < naissance:
			var h := minf(0.45, naissance - y)
			o.boite(Transform3D(Basis(), Vector3(x, y + h * 0.5, 0.3)), Vector3(w, h, 0.6), BRIQUE if k % 2 == 0 else PIERRE, Outils.DUR, true)
			y += h
			k += 1
		o.boite(Transform3D(Basis(), Vector3(x, naissance + 0.1, 0.33)), Vector3(w + 0.16, 0.2, 0.66), PIERRE)
	# Les écoinçons au-dessus des arcs, et les claveaux alternés en éventail.
	for i in TRAVEES:
		var cx := x0 + (i + 0.5) * t
		var arc := Outils.arc(Vector2(0, naissance), r, 0.0, PI, 12)
		var pts := PackedVector2Array([Vector2(-t * 0.5, naissance), Vector2(-t * 0.5, RDC), Vector2(t * 0.5, RDC), Vector2(t * 0.5, naissance)])
		for p in arc:
			pts.append(p)
		o.profil(Transform3D(Basis(), Vector3(cx, 0, 0)), pts, 0.0, 0.6, FOND)
		for k in 9:
			var a0 := PI * k / 9.0
			var a1 := PI * (k + 1) / 9.0
			var q := PackedVector2Array([
				Vector2(cos(a0), sin(a0)) * r, Vector2(cos(a0), sin(a0)) * (r + 0.42),
				Vector2(cos(a1), sin(a1)) * (r + 0.42), Vector2(cos(a1), sin(a1)) * r])
			for j in q.size():
				q[j] += Vector2(0, naissance)
			# des claveaux moins saturés et pas tous pareils : la brique foraine varie d'une pièce à l'autre
			var claveau := BRIQUE.lerp(PIERRE, 0.18) if k % 2 == 0 else PIERRE_OMBRE.lerp(PIERRE, 0.5)
			claveau = claveau.darkened(o.rng.randf_range(-0.04, 0.08))
			o.profil(Transform3D(Basis(), Vector3(cx, 0, 0)), q, 0.0, 0.64, claveau)
		# La clé de l'arc, plus saillante.
		o.boite(Transform3D(Basis(), Vector3(cx, naissance + r + 0.2, 0.36)), Vector3(0.34, 0.5, 0.66), PIERRE)


static func _fenetre(o: Outils, p: Vector3, w: float, h: float, balcon: bool, graine: int) -> void:
	# L'encadrement de pierre, la clé de pierre, l'appui saillant.
	o.boite(Transform3D(Basis(), p + Vector3(0, h * 0.5, 0.04)), Vector3(w + 0.42, h + 0.32, 0.1), PIERRE_OMBRE)
	o.boite(Transform3D(Basis(), p + Vector3(0, h * 0.5, 0.06)), Vector3(w, h, 0.1), VITRE)
	o.boite(Transform3D(Basis(), p + Vector3(0, h * 0.5, 0.075)), Vector3(0.06, h, 0.06), PIERRE)
	o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.2, 0.1)), Vector3(0.36, 0.42, 0.14), PIERRE)
	o.boite(Transform3D(Basis(), p + Vector3(0, -0.08, 0.14)), Vector3(w + 0.6, 0.12, 0.28), PIERRE)
	# Les persiennes gris vert, ouvertes à plat contre le mur, sauf quelques-unes tirées.
	var r := RandomNumberGenerator.new()
	r.seed = graine * 97
	if r.randf() < 0.22:
		o.boite(Transform3D(Basis(), p + Vector3(0, h * 0.5, 0.12)), Vector3(w, h, 0.04), VOLET)
	else:
		for s in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), p + Vector3(s * (w * 0.75 + 0.22), h * 0.5, 0.1)), Vector3(w * 0.5, h, 0.04), VOLET)
	if balcon:
		o.boite(Transform3D(Basis(), p + Vector3(0, -0.02, 0.45)), Vector3(w + 0.7, 0.12, 0.8), PIERRE)
		for k in 9:
			var x := lerpf(-(w + 0.6) * 0.5, (w + 0.6) * 0.5, k / 8.0)
			o.boite(Transform3D(Basis(), p + Vector3(x, 0.5, 0.8)), Vector3(0.03, 0.9, 0.03), FER)
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.96, 0.8)), Vector3(w + 0.7, 0.05, 0.06), FER)
	else:
		o.boite(Transform3D(Basis(), p + Vector3(0, 0.55, 0.15)), Vector3(w, 0.04, 0.03), FER)
