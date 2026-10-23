extends Node3D
## L'église romane, venue de la collégiale Saint-Pierre de Chauvigny 0.2.2 (Le duke, MIT) : une nef à trois
## vaisseaux et ses bas-côtés (contreforts plats, fenêtres romanes, corniche à modillons), le transept et ses
## pignons à oculus, le clocher carré sur la croisée (50 m, arcatures et horloge), le chevet en pièce montée
## (abside, déambulatoire et chapelles rayonnantes), le portail ouest et la porte sud. Un bloc plein vu du
## dehors : rien dedans. La nef suit l'axe x, le portail à l'ouest (-x), le chevet à l'est (+x), le tout centré
## sur l'origine (36 × 24 m) ; posée sur un sol plat à y = 0, les murs plongent de 1,2 m dessous. En mètres.
const A := preload("res://bibliotheque/eglise-romane/1/pierre.gd")
const Z_NEF := -21.0
## La hauteur de la tour du clocher, sans son toit (8 m de plus avec la croix), en mètres : 34 pour un clocher à sa mesure ; 50 à Chauvigny (exagérée pour tenir la ligne d'horizon vue
## du pont) ; 30 au moins.
@export var hauteur_clocher := 34.0
var _fait := false


func _ready() -> void:
	if _fait:
		return
	_fait = true
	# (à Chauvigny, la collégiale est dessinée autour de x 8,1, z -21 (parvis compris) : on la ramène sur l'origine)
	var tenue := A.groupe(self, "Eglise", Vector3(-8.1, 0, -Z_NEF))
	_collegiale(tenue)
	A.fusionner(tenue)


## Le sol sous l'église et son parvis : plat (à Chauvigny, le plateau bombé).
func _y(_x: float, _z: float) -> float:
	return 0.0

## Un pavage qui suit le terrain (le plateau est bombé) : une grille de 1 m posée 2,5 cm au-dessus du sol.
func _pavage(g: Node3D, rect: Rect2, c: Variant = "pave", dy := .025, pas := 1.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := maxi(1, int(ceil(rect.size.x / pas)))
	var nz := maxi(1, int(ceil(rect.size.y / pas)))
	for j in nz:
		for i in nx:
			var x0 := rect.position.x + rect.size.x * i / nx
			var x1 := rect.position.x + rect.size.x * (i + 1) / nx
			var z0 := rect.position.y + rect.size.y * j / nz
			var z1 := rect.position.y + rect.size.y * (j + 1) / nz
			var q := [Vector3(x0, _y(x0, z0) + dy, z0), Vector3(x1, _y(x1, z0) + dy, z0), Vector3(x1, _y(x1, z1) + dy, z1), Vector3(x0, _y(x0, z1) + dy, z1)]
			for k in [0, 1, 2, 0, 2, 3]: st.add_vertex(q[k])  # sens horaire : face vers le haut
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = A.mat(c)
	g.add_child(m)
	return m

## Orientée est-ouest sur l'axe z = -21. Nef x -8..14 (vaisseau central 7 m, bas-côtés 4,5 m), transept
## x 14..21,5 (z -33..-9), clocher carré 9 × 9 sur la croisée (52 m), chevet en pièce montée (chapelles,
## déambulatoire, abside) jusqu'à x ≈ 27,6 (le bord du plateau est à 32). Bloc plein vu du dehors : murs solides,
## rien dedans. Le portail ouest est en x -10, la porte sud en x 10 (avant le recentrage de _ready).
func _collegiale(r: Node3D) -> void:
	var yb := 0.0  # le sol à l'ouest, le plus haut ; les murs descendent de 1,2 m sous lui
	var g := A.groupe(r, "Collegiale", Vector3(0, yb, 0))
	g.set_meta("repere", "collegiale")
	var H_NEF := 12.0
	var H_BAS := 8.0
	var X0 := -8.0
	var X1 := 14.0
	var XT := 21.5  # l'est du transept
	var ZN := Z_NEF - 8.0   # -29 : face nord
	var ZS := Z_NEF + 8.0   # -13 : face sud
	var ZVN := Z_NEF - 3.5  # murs du vaisseau central
	var ZVS := Z_NEF + 3.5
	var bas := -1.2
	# le vaisseau central : deux murs gouttereaux (visibles au-dessus des bas-côtés), le mur ouest et son pignon
	for zv in [ZVN, ZVS]:
		A.bloc(g, Vector3((X0 + X1) * .5, (bas + H_NEF) * .5, zv), Vector3(X1 - X0, H_NEF - bas, .6), "calcaire")
	A.bloc(g, Vector3(X0 + .3, (bas + H_NEF) * .5, Z_NEF), Vector3(.6, H_NEF - bas, 7.6), "calcaire", true)
	var ouest := A.groupe(g, "FacadeOuest", Vector3(X0 + .3, 0, Z_NEF), PI * .5)
	A.pignon(ouest, Vector3(0, H_NEF, 0), 7.6, 2.7, .6, "calcaire")
	# les bas-côtés : murs extérieurs, murs ouest, contreforts plats, fenêtres romanes, modillons, appentis
	for cote in [-1.0, 1.0]:
		var zf: float = Z_NEF + cote * 8.0     # la face extérieure (-29 ou -13)
		var zm: float = zf - cote * .3          # le centre du mur
		var ry := PI if cote < 0 else 0.0       # les fenêtres regardent dehors
		A.bloc(g, Vector3((X0 + X1) * .5, (bas + H_BAS) * .5, zm), Vector3(X1 - X0, H_BAS - bas, .6), "calcaire", true)
		A.bloc(g, Vector3(X0 + .3, (bas + H_BAS) * .5, Z_NEF + cote * 6.0), Vector3(.6, H_BAS - bas, 4.6), "calcaire", true)
		A.bloc(g, Vector3((X0 + X1) * .5, .2, zf + cote * .08), Vector3(X1 - X0 + .3, 1.4, .16), "taille")  # le soubassement
		for i in 6:
			var x := X0 + .45 + i * (X1 - X0 - .9) / 5.0
			A.bloc(g, Vector3(x, (bas + H_BAS - .6) * .5, zf + cote * .25), Vector3(.9, H_BAS - .6 - bas, .5), "taille", true)
			var cap := A.bloc(g, Vector3(x, H_BAS - .45, zf + cote * .25), Vector3(.9, .3, .5), "taille")
			cap.rotation.x = -cote * .5
			if i < 5:
				var xw := x + (X1 - X0 - .9) / 10.0
				A.fenetre_romane(g, Vector3(xw, 4.6, zf + cote * .02), .9, 2.4, ry)
				# la claire-voie du vaisseau central, au-dessus de l'appentis
				A.fenetre_romane(g, Vector3(xw, 10.6, Z_NEF + cote * 3.8), .7, 1.4, ry)
		# la corniche et ses modillons
		A.bloc(g, Vector3((X0 + X1) * .5, H_BAS - .12, zf + cote * .12), Vector3(X1 - X0 + .4, .24, .3), "taille")
		var nm := int((X1 - X0) / .9)
		for i in nm:
			A.bloc(g, Vector3(X0 + .45 + i * .9, H_BAS - .38, zf + cote * .1), Vector3(.22, .26, .3), "taille")
		# l'appentis de tuiles, du mur gouttereau au bord du bas-côté
		var pan := A.bloc(g, Vector3((X0 + X1) * .5, H_BAS + .95, Z_NEF + cote * 6.1), Vector3(X1 - X0 + .6, .18, 5.3), "tuile")
		pan.rotation.x = cote * .361
		A.bloc(g, Vector3((X0 + X1) * .5, H_NEF - .1, Z_NEF + cote * 3.6), Vector3(X1 - X0 + .3, .2, .3), "taille")
	# le toit de la nef (faîte le long de x)
	var tn := A.toit(g, Vector3((X0 + X1) * .5, H_NEF, Z_NEF), 7.9, X1 - X0 + .4, 2.7, "tuile", .3)
	tn.rotation.y = PI * .5
	# le transept : murs, pignons nord et sud avec une baie et un oculus, toit à deux pans (faîte le long de z)
	var ZTN := Z_NEF - 12.0
	var ZTS := Z_NEF + 12.0
	for zt in [ZTN, ZTS]:
		var cote := -1.0 if zt < Z_NEF else 1.0
		A.bloc(g, Vector3((X1 + XT) * .5, (bas + H_NEF) * .5, zt - cote * .3), Vector3(XT - X1, H_NEF - bas, .6), "calcaire", true)
		A.pignon(g, Vector3((X1 + XT) * .5, H_NEF, zt - cote * .3), XT - X1 + .2, 2.8, .6, "calcaire")
		A.fenetre_romane(g, Vector3((X1 + XT) * .5, 6.5, zt + cote * .02), 1.2, 3.2, PI if cote < 0 else 0.0)
		var oc := A.cyl(g, Vector3((X1 + XT) * .5, 11.0, zt + cote * .04), .75, .14, "taille", -1, 14)
		oc.rotation.x = PI * .5
		var ocv := A.cyl(g, Vector3((X1 + XT) * .5, 11.0, zt + cote * .1), .5, .06, "noir", -1, 12)
		ocv.rotation.x = PI * .5
		A.bloc(g, Vector3((X1 + XT) * .5, .2, zt + cote * .08), Vector3(XT - X1 + .3, 1.4, .16), "taille")
		A.bloc(g, Vector3(X1 + .3, (bas + H_NEF) * .5, Z_NEF + cote * 10.0), Vector3(.6, H_NEF - bas, 4.0), "calcaire", true)
		for sx in [X1 + .45, XT - .45]:
			A.bloc(g, Vector3(sx, (bas + H_NEF - .8) * .5, zt + cote * .25), Vector3(.9, H_NEF - .8 - bas, .5), "taille")
	A.bloc(g, Vector3(XT - .3, (bas + H_NEF) * .5, Z_NEF), Vector3(.6, H_NEF - bas, ZTS - ZTN), "calcaire", true)
	A.toit(g, Vector3((X1 + XT) * .5, H_NEF, Z_NEF), XT - X1 + .5, ZTS - ZTN + .4, 2.8, "tuile", .3)
	_clocher(g, Vector3((X1 + XT) * .5, 0, Z_NEF), 11.0, maxf(30.0, hauteur_clocher))  # (0.2 : 32 m + 56 %, élargi à 11 m : le haut et le centre de la ligne d'horizon vue du pont, sans devenir un campanile)
	_chevet(g, Vector3(XT, 0, Z_NEF))
	_portail(g, Vector3(X0 + .3, 0, Z_NEF))
	_porte_sud(g, Vector3(10.0, 0, ZS))
	# le parvis entre la rue et la façade, et la bande au pied du mur sud
	_pavage(r, Rect2(-11.6, -30.0, 3.4, 18.5))
	_pavage(r, Rect2(-1.0, -13.1, 20.0, 1.4))
	A.lanterne(g, Vector3(X0 + .3 - 3.0 - .02, 3.6, Z_NEF - 3.1), -PI * .5, true, .6)

## Le clocher carré sur la croisée (0.2, d'après les photos ; rehaussé de 32 à 52 m pour tenir le centre et le
## haut de la ligne d'horizon vue du pont) : un fût nu au-dessus des toits, puis deux registres — en bas trois
## arcatures aveugles sur colonnettes et l'horloge, en haut deux baies géminées ouvertes, plus hautes, par
## face (on voit le ciel au travers, et la cloche) —, une corniche à modillons, une pyramide d'ardoise grise
## peu raide et sa croix. C'est le repère de la cité vu du pont.
func _clocher(g: Node3D, p: Vector3, w: float, h: float) -> void:
	var c := A.groupe(g, "Clocher", p)
	var y0 := 10.0       # le bas est caché dans la croisée
	var ya := h - 21.5   # le registre des arcatures et de l'horloge
	var yb := h - 12.0   # le registre des baies (l'appui à yb + 1)
	var yc := h - 1.4    # la corniche
	var e := .8
	# le fût plein jusqu'à l'appui des baies
	A.bloc(c, Vector3(0, (y0 + yb + 1.0) * .5, 0), Vector3(w, yb + 1.0 - y0, w), "calcaire", true)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			A.bloc(c, Vector3(sx * (w * .5 - .05), (y0 + yc) * .5, sz * (w * .5 - .05)), Vector3(.9, yc - y0, .9), "taille")
	# les bandeaux qui séparent les registres, l'appui des baies, et un ressaut au milieu du fût
	for yy in [(y0 + ya) * .5 + 2.0, ya - .3, yb - .2, yb + 1.0]:
		A.bloc(c, Vector3(0, yy, 0), Vector3(w + .45, .32, w + .45), "taille")
	# le plancher des cloches, et la cloche (on la voit par les baies)
	A.cyl(c, Vector3(0, yb + 2.15, 0), .78, 1.15, "cuivre", .42, 12)
	A.bloc(c, Vector3(0, yb + 3.0, 0), Vector3(w - 1.0, .3, .35), "chene")
	for face in [[Vector3(0, 0, -w * .5), PI], [Vector3(0, 0, w * .5), 0.0], [Vector3(w * .5, 0, 0), PI * .5], [Vector3(-w * .5, 0, 0), -PI * .5]]:
		var o: Vector3 = face[0]
		var ry: float = face[1]
		var n := Vector3(sin(ry), 0, cos(ry))      # la normale de la face
		var lat := Vector3(cos(ry), 0, -sin(ry))   # le long de la face
		# le fût : une petite baie, au-dessus des toits
		if absf(ry) > .1:
			A.fenetre_romane(c, o + n * .02 + Vector3(0, ya - 4.5, 0), .7, 1.6, ry)
		# le registre bas : trois arcatures aveugles sur colonnettes
		for k in 3:
			var q := o + lat * (float(k - 1) * 2.55) + n * .03
			A.bloc(c, q + Vector3(0, ya + 3.4, 0), Vector3(1.85, 6.0, .06), "calcaire_sombre", false, ry)
			var ar := A.arc(c, q + n * .05 + Vector3(0, ya + 6.4, 0), .92, .26, .22, "taille", 0.0, PI, 6)
			ar.rotation.y = ry
		for k in 4:
			A.cyl(c, o + lat * (-3.83 + k * 2.55) + n * .1 + Vector3(0, ya + 3.3, 0), .13, 6.2, "taille", -1, 6)
		# l'horloge, dans l'arcature du milieu (à l'ouest vers le pont, à l'est vers le chevet)
		if absf(absf(ry) - PI * .5) < .1:
			var hg := A.groupe(c, "Horloge", o + n * .1 + Vector3(0, ya + 3.6, 0), ry)
			A.cyl(hg, Vector3.ZERO, .78, .08, "creme", -1, 16).rotation.x = PI * .5
			A.cyl(hg, Vector3(0, 0, -.01), .86, .06, "taille", -1, 16).rotation.x = PI * .5
			A.bloc(hg, Vector3(.0, .26, .06), Vector3(.07, .52, .02), "fer")
			var aig := A.bloc(hg, Vector3(.2, -.12, .07), Vector3(.05, .46, .02), "fer")
			aig.rotation.z = 2.1
		# le registre haut : deux grandes baies ouvertes, géminées (colonnette, deux petits arcs)
		var y_mur := yb + 1.16
		var hm := yc - y_mur
		var pm := o - lat * (w * .5) - n * (e * .5) + Vector3(0, y_mur, 0)
		var xs := [w * .5 - 2.05, w * .5 + 2.05]
		var ns := 5.8  # la naissance des grands arcs : des baies de 6,8 m sur 2
		A.mur_perce(c, pm, w, hm, e, [[xs[0], 1.0, ns], [xs[1], 1.0, ns]], "calcaire", ry, 10)
		for xb in xs:
			var q: Vector3 = pm + lat * float(xb) + n * (e * .5 - .1)
			A.cyl(c, q + Vector3(0, (ns - .95) * .5, 0), .12, ns - .95, "taille", -1, 6)
			A.bloc(c, q + Vector3(0, ns - .9, 0), Vector3(.36, .2, .36), "taille")
			for s in [-1.0, 1.0]:
				var pa := A.arc(c, q + lat * (s * .5) + Vector3(0, ns - .8, 0), .38, .14, .2, "taille", 0.0, PI, 4)
				pa.rotation.y = ry
		# la corniche et ses modillons
		A.bloc(c, o + n * .12 + Vector3(0, yc + .2, 0), Vector3(w + .7, .4, .5), "taille", false, ry)
		for k in 11:
			A.bloc(c, o + n * .2 + lat * (-4.0 + k * .8) + Vector3(0, yc - .18, 0), Vector3(.24, .3, .4), "taille", false, ry)
	# le haut, plein, de la corniche au toit
	A.bloc(c, Vector3(0, (yc + h) * .5, 0), Vector3(w + .1, h - yc, w + .1), "calcaire")
	# la pyramide d'ardoise grise, peu raide, une croix de fer au sommet
	A.bloc(c, Vector3(0, h + .1, 0), Vector3(w + .9, .2, w + .9), "taille")
	var hp := 6.2
	var fl := A.cyl(c, Vector3(0, h + .2 + hp * .5, 0), (w * .5 + .45) * sqrt(2.0), hp, "ardoise", .06, 4)
	fl.rotation.y = PI * .25
	A.barre(c, Vector3(0, h + hp, 0), Vector3(0, h + hp + 2.0, 0), .06, "fer", 6)
	A.barre(c, Vector3(-.5, h + hp + 1.4, 0), Vector3(.5, h + hp + 1.4, 0), .05, "fer", 6)
	A.boule(c, Vector3(0, h + hp + .25, 0), Vector3(.28, .28, .28), "laiton", 8)

## Une demi-révolution autour de Y (angles de a0 à a1 ; par défaut la moitié est, x ≥ 0) : les murs du chevet
## collés au transept, sans moitié cachée dedans.
func _demi_revolution(r: Node3D, p: Vector3, profil: Array, c: Variant, segments := 12, a0 := -PI * .5, a1 := PI * .5) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in profil.size() - 1:
		var a: Vector2 = profil[j]
		var b: Vector2 = profil[j + 1]
		for i in segments:
			var t0 := lerpf(a0, a1, float(i) / segments)
			var t1 := lerpf(a0, a1, float(i + 1) / segments)
			var p00 := Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x)
			var p10 := Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x)
			var p01 := Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)
			var p11 := Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x)
			for q in [p00, p11, p01, p00, p10, p11]: st.add_vertex(q)
	st.generate_normals()
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = A.mat(c)
	m.position = p
	r.add_child(m)
	return m

## La hauteur du muret bombé d'un étage de rayon r (1 m sur les chapelles, 1,25 m sur le déambulatoire).
func _h_bombe(r: float) -> float:
	return clampf(r * .22, .95, 1.3)

## Le muret rond (« bombé ») qui couronne un étage du chevet, et le toit de tuile presque plat qu'il cache :
## r le rayon du mur, y le haut du mur ; demi : seulement la moitié est (contre le transept). (Reprise B,
## photos 05 et 13) Le muret se lisait à peine : c'est un bourrelet haut d'un mètre et plus, d'un calcaire
## plus gris que le mur, qui sort au-dessus de la corniche, se gonfle, puis s'arrondit vers le dedans.
func _couronne(g: Node3D, p: Vector3, r: float, y: float, demi: bool, seg: int) -> void:
	var hb := _h_bombe(r)
	var muret := [Vector2(r - .05, y - .05), Vector2(r + .27, y + .02), Vector2(r + .29, y + .2), Vector2(r + .12, y + .27),
		Vector2(r + .19, y + hb * .38), Vector2(r + .23, y + hb * .62), Vector2(r + .15, y + hb * .86), Vector2(r - .03, y + hb),
		Vector2(r - .3, y + hb + .03), Vector2(r - .5, y + hb - .1)]
	var toit := [Vector2(r - .5, y + hb - .25), Vector2(maxf(r * .5, .2), y + hb + r * .05), Vector2(.12, y + hb + .1 + r * .08)]
	var pierre := A.matiere("cbc1a7:1")
	if demi:
		_demi_revolution(g, p, muret, pierre, seg)
		_demi_revolution(g, p, toit, "tuile", seg)
	else:
		A.revolution(g, p, muret, pierre, seg)
		A.revolution(g, p, toit, "tuile", seg)

## (Reprise B) Une baie romane du chevet, avec sa profondeur : l'encadrement de pierre de taille, une
## archivolte sur deux colonnettes qui sortent du mur, l'ébrasement en pierre dans l'ombre, et au fond le
## vitrail sombre (verre bleu-gris et ses plombs), l'appui. Comme A.fenetre_romane : un mur vers +Z local,
## p au nu du mur (la baie va de -h/2 à h*0,3 + w/2).
func _baie_chevet(r: Node3D, p: Vector3, w: float, h: float, ry: float) -> void:
	var g := A.groupe(r, "BaieChevet", p, ry)
	var ombre := A.matiere("8f846c:1")
	var yn := h * .3
	A.bloc(g, Vector3(0, 0, 0), Vector3(w + .46, h + .34, .12), "taille")
	# l'ébrasement : la baie en pierre ombrée, et le vitrail en retrait d'un liseré
	A.bloc(g, Vector3(0, -h * .1, .065), Vector3(w, h * .8, .02), ombre)
	A.cyl(g, Vector3(0, yn, .065), w * .5, .02, ombre, -1, 8).rotation.x = PI * .5
	var vitre := A.lumiere(Color("3e4c62"), .3)  # le vitrail : un bleu d'ardoise qui prend le ciel du soir
	A.bloc(g, Vector3(0, -h * .1 + .05, .08), Vector3(w - .2, h * .8 - .1, .02), vitre)
	A.cyl(g, Vector3(0, yn, .08), w * .5 - .1, .02, vitre, -1, 8).rotation.x = PI * .5
	A.bloc(g, Vector3(0, -h * .05, .095), Vector3(.025, h * .8, .01), "fer")
	A.bloc(g, Vector3(0, -h * .1 + .05, .095), Vector3(w - .2, .025, .01), "fer")
	# l'archivolte et ses colonnettes, l'appui
	A.arc(g, Vector3(0, yn, .1), w * .5 + .02, .13, .16, "taille", 0.0, PI, 5)
	for s in [-1.0, 1.0]:
		A.cyl(g, Vector3(s * (w * .5 + .09), (yn - h * .5) * .5, .12), .055, yn + h * .5, "taille", -1, 6)
	A.bloc(g, Vector3(0, -h * .5 - .03, .1), Vector3(w + .42, .08, .24), "taille")

## Le chevet en « pièce montée » (les photos : vu de la place, du drone, la carte postale 13) : trois
## chapelles rayonnantes semi-circulaires basses (le toit vers 6 m), puis le déambulatoire qui les relie un
## peu plus haut, puis l'abside, chacun couronné d'un muret rond qui cache un toit de tuile presque plat ; en
## bas des arcatures aveugles sur colonnettes, des colonnes engagées, des corniches à modillons ; une tourelle
## d'escalier ronde au pied du clocher, coiffée d'un cône d'écailles de pierre. (Reprise : il se lisait
## comme une tour empilée — étages hauts, rayons étroits ; il est maintenant bas et large.) Même emprise vers
## l'est qu'avant (jusqu'à x ≈ 27,6) : la ruelle du chevet garde ses 4 m ; la chapelle sud touche toujours
## le bout du mur du clos du presbytère (25,2 ; -16,3).
func _chevet(g: Node3D, p: Vector3) -> void:
	# le centre des tambours est à un mètre dans le transept : le déambulatoire, plus large (11 m au lieu de
	# 8,6 contre le transept), garde la même avancée vers l'est
	var c := A.groupe(g, "Chevet", p + Vector3(-1.0, 0, 0))
	var RD := 5.7    # le déambulatoire
	var HD := 7.4    # (reprise B : 6,9 → 7,4 et l'abside 9,4 → 10,6, pour que chaque étage se lise au-dessus du
	var RA := 4.6    # bourrelet de celui d'en dessous, les fenêtres hautes de l'abside comprises)
	var HA := 10.6
	var RC := 1.85   # les chapelles, centrées un peu en dedans du mur du déambulatoire, à 0 et ±60°
	var DC := 5.15
	var HC := 5.2
	var AC := PI / 3.0
	var y_couronne := _h_bombe(RD)  # ce que le muret rond du déambulatoire ajoute au-dessus de son mur
	# --- le déambulatoire : un demi-tambour contre le transept, un soubassement qui déborde ---
	_demi_revolution(c, Vector3.ZERO, [Vector2(RD + .18, -1.2), Vector2(RD + .18, .35), Vector2(RD, .5), Vector2(RD, HD)], "calcaire", 16)
	A.collision_cyl(c, Vector3(0, HD * .5, 0), RD + .1, HD + 2.5)
	_couronne(c, Vector3.ZERO, RD, HD, true, 16)
	# --- l'abside, en retrait d'un mètre, plus haute ---
	_demi_revolution(c, Vector3.ZERO, [Vector2(RA, HD), Vector2(RA, HA)], "calcaire", 14)
	_couronne(c, Vector3.ZERO, RA, HA, true, 14)
	# les corniches à modillons (déambulatoire, abside), les fenêtres hautes, les colonnes engagées
	for i in 19:
		var a := -PI * .5 + PI * i / 18.0
		var m := A.bloc(c, Vector3(cos(a) * (RD + .1), HD - .3, sin(a) * (RD + .1)), Vector3(.22, .26, .3), "taille")
		m.rotation.y = -a
	for i in 15:
		var a := -PI * .5 + PI * i / 14.0
		var m := A.bloc(c, Vector3(cos(a) * (RA + .1), HA - .3, sin(a) * (RA + .1)), Vector3(.22, .26, .3), "taille")
		m.rotation.y = -a
	var y_fa := (HD + y_couronne + HA - .45) * .5
	for a in [0.0, PI * .27, -PI * .27]:
		_baie_chevet(c, Vector3(cos(a) * RA, y_fa, sin(a) * RA), .66, 1.2, -a + PI * .5)
	for a in [PI * .135, -PI * .135, PI * .4, -PI * .4]:
		var y0 := HD + y_couronne - .1
		A.cyl(c, Vector3(cos(a) * (RA + .1), (y0 + HA - .45) * .5, sin(a) * (RA + .1)), .13, HA - .45 - y0, "taille", -1, 6)
	# au déambulatoire : une grande baie entre deux chapelles, entre deux colonnes engagées jusqu'à la corniche
	for a in [AC * .5, -AC * .5]:
		_baie_chevet(c, Vector3(cos(a) * RD, 3.7, sin(a) * RD), .7, 1.8, -a + PI * .5)
		for s in [-1.0, 1.0]:
			var ac: float = a + s * .135
			A.cyl(c, Vector3(cos(ac) * (RD + .1), (HD - .45) * .5 + .3, sin(ac) * (RD + .1)), .14, HD - .45 - .6, "taille", -1, 6)
	# --- les trois chapelles rayonnantes, basses et larges ---
	for a in [0.0, AC, -AC]:
		var pc := Vector3(cos(a) * DC, 0, sin(a) * DC)
		var ch := A.groupe(c, "Chapelle", pc)
		A.revolution(ch, Vector3.ZERO, [Vector2(RC + .12, -1.2), Vector2(RC + .12, .3), Vector2(RC, .45), Vector2(RC, HC)], "calcaire", 14)
		A.collision_cyl(ch, Vector3(0, HC * .5 - .5, 0), RC + .1, HC + 1.5)
		_couronne(ch, Vector3.ZERO, RC, HC, false, 14)
		# l'arcature aveugle : cinq arcs sur colonnettes, la fenêtre dans celui du milieu, un cordon dessus ;
		# (reprise B) le fond des arcs aveugles dans l'ombre, cintré, et non plus des aplats clairs
		for k in 5:
			var am: float = a + (k - 2) * .52
			var q := Vector3(cos(am) * (RC + .02), 0, sin(am) * (RC + .02))
			if k == 2:
				_baie_chevet(ch, Vector3(cos(am) * RC, 2.35, sin(am) * RC), .6, 1.55, -am + PI * .5)
			else:
				var pn := A.bloc(ch, q + Vector3(0, 1.7, 0), Vector3(.66, 2.7, .05), A.matiere("a69a7f:1"))
				pn.rotation.y = -am + PI * .5
				A.cyl(ch, q + Vector3(0, 3.05, 0), .33, .05, A.matiere("a69a7f:1"), -1, 8).rotation = Vector3(PI * .5, -am + PI * .5, 0)
			var ar := A.arc(ch, Vector3(cos(am) * (RC + .06), 3.05, sin(am) * (RC + .06)), .36, .14, .12, "taille", 0.0, PI, 4)
			ar.rotation.y = -am + PI * .5
		for k in 6:
			var am: float = a + (k - 2.5) * .52
			A.cyl(ch, Vector3(cos(am) * (RC + .09), 1.55, sin(am) * (RC + .09)), .08, 3.0, "taille", -1, 6)
		A.revolution(ch, Vector3.ZERO, [Vector2(RC, 3.5), Vector2(RC + .1, 3.55), Vector2(RC + .1, 3.7), Vector2(RC, 3.75)], "taille", 14)
		for k in 8:
			var am: float = a + (k - 3.5) * .4
			var mo := A.bloc(ch, Vector3(cos(am) * (RC + .08), HC - .28, sin(am) * (RC + .08)), Vector3(.2, .22, .26), "taille")
			mo.rotation.y = -am
	# --- la tourelle d'escalier, ronde, au pied du clocher (côté nord, à demi prise dans le transept derrière
	# la chapelle nord), son cône d'écailles de pierre : elle sort au-dessus des chapelles et du déambulatoire ---
	var tq := Vector3(.5, 0, -7.3)
	var ht := 12.2
	A.cyl(c, tq + Vector3(0, (ht - 1.2) * .5, 0), 1.1, ht + 1.2, "calcaire", -1, 12, true)
	for yy in [HD - .3, HA - .3]:
		A.cyl(c, tq + Vector3(0, yy, 0), 1.24, .26, "taille", -1, 12)
	for k in 3:
		var fe := A.bloc(c, tq + Vector3(.75, 2.6 + k * 3.6, -.78), Vector3(.14, .9, .14), "noir")
		fe.rotation.y = -PI * .25
	var rr := [1.28, .98, .68, .38]
	for k in 3:
		A.cyl(c, tq + Vector3(0, ht + .45 + k * .9, 0), rr[k], .92, "calcaire_sombre" if k % 2 else "taille", rr[k + 1], 12)
	A.cyl(c, tq + Vector3(0, ht + 2.95, 0), .38, .5, "taille", .04, 8)

## Le portail ouest : un avant-corps à pignon, trois voussures emboîtées de rayons croissants, des
## colonnettes, un tympan plein, une porte de bois à deux vantaux (solide : on entre par le socle).
func _portail(g: Node3D, p: Vector3) -> void:
	var o := A.groupe(g, "Portail", p)
	var prof := 3.0
	var larg := 7.6
	var h := 9.0
	var bas := -1.2
	# les piles de part et d'autre de l'ouverture (demi-largeur 2,4), le haut, le pignon, la corniche
	for s in [-1.0, 1.0]:
		A.bloc(o, Vector3(-prof * .5, (bas + h) * .5, s * (2.4 + .7)), Vector3(prof, h - bas, 1.4), "calcaire", true)
		A.bloc(o, Vector3(-prof - .25, (bas + h - 1.0) * .5, s * (larg * .5 - .45)), Vector3(.5, h - 1.0 - bas, .9), "taille", true)
	A.bloc(o, Vector3(-prof * .5, (5.3 + h) * .5, 0), Vector3(prof, h - 5.3, 4.8), "calcaire", true)
	A.bloc(o, Vector3(-prof * .5, h - .15, 0), Vector3(prof + .5, .3, larg + .4), "taille")
	var pg := A.groupe(o, "Pignon", Vector3(-prof + .3, 0, 0), PI * .5)
	A.pignon(pg, Vector3(0, h, 0), larg, 1.7, .6, "calcaire")
	var pan := A.bloc(o, Vector3(-prof * .5 - .1, h + 1.0, 0), Vector3(2.6, .16, larg + .5), "tuile")
	pan.rotation.z = .6
	# les trois voussures (du dehors au dedans), leurs jambages étagés et leurs colonnettes
	var rayons := [2.3, 1.8, 1.3]
	for i in 3:
		var rr: float = rayons[i]
		var x := -prof + .6 * i + .3
		var arc := A.arc(o, Vector3(x, 2.4, 0), rr, .45, .6, "taille", 0.0, PI, 18)
		arc.rotation.y = PI * .5
		if i > 0:
			for s in [-1.0, 1.0]:
				A.bloc(o, Vector3(x, 1.2, s * (rr + (2.4 - rr) * .5)), Vector3(.6, 2.4, 2.4 - rr), "taille")
				A.cyl(o, Vector3(x - .1, 1.25, s * (rr + .14)), .11, 2.1, "taille", -1, 8)
				A.bloc(o, Vector3(x - .1, 2.4, s * (rr + .14)), Vector3(.3, .3, .32), "calcaire_sombre")
				A.bloc(o, Vector3(x - .1, .12, s * (rr + .14)), Vector3(.32, .24, .34), "taille")
			A.bloc(o, Vector3(x, (2.4 + rr + .45 + 5.3) * .5, 0), Vector3(.6, 5.3 - (2.4 + rr + .45), 4.8), "calcaire")
	# le tympan (un demi-disque sur un linteau), une mandorle en relief, la porte à deux vantaux ferrés
	var xd := -1.2
	A.bloc(o, Vector3(xd, 2.32, 0), Vector3(.4, .3, 2.7), "taille")
	var ty := A.cyl(o, Vector3(xd - .02, 2.4, 0), 1.27, .3, "calcaire_clair", -1, 16)
	ty.rotation.z = PI * .5
	A.boule(o, Vector3(xd - .2, 3.05, 0), Vector3(.12, .55, .38), "calcaire_sombre", 8)
	A.cyl(o, Vector3(xd - .24, 3.05, 0), .09, .5, "c4b793", -1, 6)
	A.bloc(o, Vector3(xd, 1.1, 0), Vector3(.12, 2.2, 2.4), "bois_sombre", true)
	A.bloc(o, Vector3(xd - .07, 1.1, 0), Vector3(.03, 2.2, .06), "fer")
	for yy in [.5, 1.2, 1.9]:
		for s in [-1.0, 1.0]:
			A.bloc(o, Vector3(xd - .08, yy, s * .62), Vector3(.02, .08, 1.0), "fer")
	A.bloc(o, Vector3(xd - .09, 1.0, .25), Vector3(.03, .05, .05), "laiton")
	A.bloc(o, Vector3(xd + .2, -.03, 0), Vector3(1.4, .1, 3.2), "taille")
	# une fenêtre en plein cintre de part et d'autre, au-dessus, et l'oculus du pignon de la nef
	for s in [-1.0, 1.0]:
		A.fenetre_romane(g, p + Vector3(-.32, 11.2, s * 2.5), .8, 1.8, -PI * .5)
	var oc := A.cyl(g, p + Vector3(-.34, 13.3, 0), .8, .14, "taille", -1, 14)
	oc.rotation.z = PI * .5
	var ocv := A.cyl(g, p + Vector3(-.4, 13.3, 0), .55, .06, "noir", -1, 12)
	ocv.rotation.z = PI * .5

## La porte sud : un petit avant-corps dans le mur du bas-côté, la porte à la zone du socle.
func _porte_sud(g: Node3D, p: Vector3) -> void:
	var o := A.groupe(g, "PorteSud", p)
	var prof := 1.6
	for s in [-1.0, 1.0]:
		A.bloc(o, Vector3(s * 1.5, 1.6, prof * .5), Vector3(.6, 5.6, prof), "taille", true)
	A.bloc(o, Vector3(0, 3.95, prof * .5), Vector3(3.6, 1.1, prof), "calcaire", true)
	A.arc(o, Vector3(0, 2.2, prof - .3), 1.2, .35, .5, "taille", 0.0, PI, 14)
	A.bloc(o, Vector3(0, 2.75, prof - .3), Vector3(2.4, .5, .5), "calcaire")
	A.bloc(o, Vector3(0, 1.1, prof - .25), Vector3(2.4, 2.2, .1), "bois_sombre", true)
	A.bloc(o, Vector3(0, 1.1, prof - .19), Vector3(.05, 2.2, .03), "fer")
	A.bloc(o, Vector3(.4, 1.05, prof - .18), Vector3(.05, .05, .04), "laiton")
	A.bloc(o, Vector3(0, -.03, prof + .2), Vector3(3.2, .1, 1.0), "taille")
	var pan := A.bloc(o, Vector3(0, 5.0, prof * .5 - .1), Vector3(4.2, .14, 2.2), "tuile")
	pan.rotation.x = .5
	A.bloc(o, Vector3(0, 4.45, prof + .05), Vector3(3.9, .25, .3), "taille")
