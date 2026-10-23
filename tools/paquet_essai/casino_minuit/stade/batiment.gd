extends RefCounted
## Le bâtiment du stade de la Fortune (bol.gd pour le plan) : le mur de la pelouse et son ruban de diodes, les
## gradins du bas, la promenade du niveau 1, la vitre des Suites impériales, les gradins du haut et leur
## coursive, la façade de diodes ceinte de couronnes d'or ; au sud le hall, son atrium et son escalier
## impérial, à l'est la piscine des parieurs sous l'écran du virage, à l'ouest le Jackpot Lounge et la scène de
## Minuit Live, et le penthouse du président, suspendu sous la roue du toit.
## Les cotes (écart d depuis le mur de la pelouse, hauteur y) :
##   d 0 à 6,4 : huit rangs du bas, de 1,3 à 4,5 ;  d 6,4 à 10 : la promenade (y 4,5) ;
##   d 10 : la vitre des loges (y 4,5 à 8,6) ;  d 10,3 à 17,9 : dix rangs du haut, de 9,4 à 13,9 ;
##   d 17,9 à 19,5 : la coursive haute (y 13,9) ;  d 19,5 : la façade (y 0 à 16).

const BOL := "res://communes/casino_minuit/stade/bol.gd"
const LOT_E := "res://communes/casino_minuit/zones/lot_e.gd"

const Y1 := 4.5
const D_BAS := 6.4
const D_VITRE := 10.0
const D_HAUT := 10.3
const Y_HAUT := 9.4
const D_COURSIVE := 17.9
const Y_COURSIVE := 13.9
const D_FACADE := 19.5
const H_FACADE := 16.0
## L'atrium du hall, sur deux étages, entre x = -10 et 10 (les points du pourtour) : de la verrière (z = -35,5) à
## la baie sur la pelouse (z = -26), où s'ouvrent les loges. La porte au milieu de la verrière, entre x = -3 et 3.
const ATRIUM_X := 10.0
const PORTE_X := 3.0
const Z_PORTE := -35.5
const Z_BAIE := -26.0
## Les deux volées de l'escalier : vingt-huit marches chacune, du pied (x = ±13,5) au palier (x = ±4), dans la
## bande de z = -29 à -26,2 ; le palier, en balcon sur l'atrium, rejoint la promenade.
const PALIER_X := 4.0
const VOLEE_PIED := 13.5
const VOLEE_Z0 := -29.0
const VOLEE_Z1 := -26.2
const MARCHES := 28
## La verrière du hall monte jusque-là ; le plafond de l'atrium suit le dessous des gradins du haut.
const H_VERRIERE := 8.8
## La rosace de l'atrium et le lustre de jetons au-dessus.
const ROSACE := Vector2(0.0, -32.0)
## Les lettres du plan du stade.
const PAL_OR := Color("#E8C26A")
const PAL_IVOIRE := Color("#F3EAD7")


## Tout le bâtiment ; rend les places assises (pour la foule des jours de match) : {"bas": [...], "haut": [...]}.
static func construire(K, S) -> Dictionary:
	var Bo = load(BOL)
	var places := {}
	K.zone_debut("FORTUNE-BOL")
	_mur(K, Bo)
	places.bas = _bas(K, Bo)
	_promenade(K, Bo)
	_loges(K, Bo)
	places.haut = _haut(K, Bo)
	_facade(K, Bo)
	K.zone_fin()
	K.zone_debut("FORTUNE-HALL")
	_hall(K)
	K.zone_fin()
	K.zone_debut("FORTUNE-PISCINE")
	_piscine(K)
	K.zone_fin()
	K.zone_debut("FORTUNE-LOUNGE")
	_lounge(K)
	K.zone_fin()
	K.zone_debut("FORTUNE-ESCALATORS")
	_escalators(K, Bo)
	K.zone_fin()
	K.zone_debut("FORTUNE-PENTHOUSE")
	_penthouse(K)
	K.zone_fin()
	_sieges(K, places)
	return places


# --- Les règles du plan ------------------------------------------------------------------------------

## Partout.
static func partout(_cote: String, _m: Vector2) -> bool:
	return true


## Tout sauf l'atrium du hall (au sud, entre x = -10 et 10) : sa verrière, sa baie sur la pelouse.
static func hors_atrium(cote: String, m: Vector2) -> bool:
	return not (cote == "S" and absf(m.x) < ATRIUM_X)


## La vitre des loges : ni l'atrium, ni la piscine (est), ni le lounge (ouest), ouverts sur la pelouse.
static func vitre(cote: String, m: Vector2) -> bool:
	return hors_atrium(cote, m) and cote != "E" and cote != "O"


## Les gradins du haut : partout sauf au-dessus de la piscine, que rien ne couvre que la roue.
static func haut(cote: String, _m: Vector2) -> bool:
	return cote != "E"


# --- Le bas -----------------------------------------------------------------------------------------

## Le mur de la pelouse, laqué rouge sous une lisse d'or, et son ruban de diodes ; la vitre de garde au-dessus.
static func _mur(K, Bo) -> void:
	Bo.anneau(K, "laque_rouge", [Vector2(0, 0), Vector2(0, 1.3)])
	Bo.anneau(K, "or", [Vector2(-0.06, 1.3), Vector2(0.1, 1.3)])
	Bo.ecrans(K, -0.04, 0.22, 1.08, 4, Callable(), true)
	Bo.anneau(K, "verre", [Vector2(-0.02, 1.3), Vector2(-0.02, 2.3)])
	Bo.collision(K, [Vector2(-0.02, 0.0), Vector2(-0.02, 2.6)])


## Les huit rangs du bas : contremarches noires, marches de béton ; la pente qu'on parcourt dessous.
static func _bas(K, Bo) -> Array:
	var marches := []
	var contre := []
	var y := 1.3
	var places := []
	for i in 8:
		var y1 := 1.3 + 0.4 * (i + 1)
		contre.append_array([Vector2(0.8 * i, y), Vector2(0.8 * i, y1)])
		marches.append_array([Vector2(0.8 * i, y1), Vector2(0.8 * (i + 1), y1)])
		places.append_array(Bo.places(0.8 * i + 0.42, y1, 0.6))
		y = y1
	for k in range(0, contre.size(), 2):
		Bo.anneau(K, "laque_noire", [contre[k], contre[k + 1]])
		Bo.anneau(K, "beton", [marches[k], marches[k + 1]])
	Bo.collision(K, [Vector2(0, 1.7), Vector2(D_BAS, Y1)])
	return places


## La promenade du niveau 1 : son dallage, et le palier de l'escalier du hall qui s'avance en balcon sur l'atrium.
static func _promenade(K, Bo) -> void:
	Bo.anneau(K, "marbre_noir", [Vector2(D_BAS, Y1), Vector2(D_VITRE, Y1)])
	Bo.collision(K, [Vector2(D_BAS, Y1), Vector2(D_VITRE, Y1)])
	K.plan("marbre_noir", -PALIER_X, PALIER_X, VOLEE_Z0, Z_BAIE, Y1)
	K.dalle(-PALIER_X, PALIER_X, VOLEE_Z0, Z_BAIE + 0.1, Y1)


## Les Suites impériales derrière leur vitre (y 4,5 à 8,6) : verre fumé entre des montants d'or, la moquette, le
## fond de bois laqué et la gorge de lumière, la frise d'or en haut ; au-dessus, le parapet rouge du haut.
static func _loges(K, Bo) -> void:
	var v := func(c, m): return vitre(c, m)
	Bo.anneau(K, "verre", [Vector2(D_VITRE, Y1), Vector2(D_VITRE, 8.6)], v)
	Bo.collision(K, [Vector2(D_VITRE, Y1), Vector2(D_VITRE, 8.6)], v)
	Bo.anneau(K, "moquette", [Vector2(D_VITRE, Y1 + 0.02), Vector2(14.5, Y1 + 0.02)], v)
	Bo.anneau(K, "bois_laque", [Vector2(14.5, Y1), Vector2(14.5, 8.6)], v)
	Bo.anneau(K, "fenetre", [Vector2(14.4, 8.0), Vector2(14.4, 8.3)], v)
	Bo.anneau(K, "or", [Vector2(D_VITRE - 0.05, 8.3), Vector2(D_VITRE - 0.05, 8.6)], v)
	for p in Bo.places(D_VITRE - 0.03, 6.55, 2.4, v, 1000):
		K.box("or", 0.1, 4.1, 0.1, p[0].x, p[0].y, p[0].z, p[1])
	# Le parapet du haut, rouge laqué à lisse d'or, sur tout le tour (au-dessus de l'ouverture de l'escalier aussi).
	var h := func(c, m): return haut(c, m)
	Bo.anneau(K, "laque_rouge", [Vector2(D_VITRE, 8.6), Vector2(D_VITRE, 10.0)], h)
	Bo.anneau(K, "or", [Vector2(D_VITRE - 0.06, 10.0), Vector2(D_HAUT, 10.0)], h)


# --- Le haut ----------------------------------------------------------------------------------------

## Les dix rangs du haut, plus raides, la coursive et son parapet ; le plafond à caissons dessous ; leurs pentes.
static func _haut(K, Bo) -> Array:
	var h := func(c, m): return haut(c, m)
	var places := []
	var dprev := D_HAUT
	var yprev := 10.0
	for i in 10:
		var d0 := D_HAUT + 0.76 * i
		var d1 := d0 + 0.76
		var y := Y_HAUT + 0.5 * i
		Bo.anneau(K, "laque_noire", [Vector2(d0, yprev), Vector2(d0, y)] if i > 0 else [Vector2(d0, y), Vector2(d0, yprev)], h)
		Bo.anneau(K, "beton", [Vector2(d0, y), Vector2(d1, y)], h)
		places.append_array(Bo.places(d0 + 0.4, y, 0.6, h))
		yprev = y
		dprev = d1
	Bo.anneau(K, "laque_noire", [Vector2(dprev, yprev), Vector2(dprev, Y_COURSIVE)], h)
	Bo.anneau(K, "marbre_noir", [Vector2(dprev, Y_COURSIVE), Vector2(D_FACADE, Y_COURSIVE)], h)
	Bo.anneau(K, "laque_rouge", [Vector2(D_FACADE - 0.02, Y_COURSIVE), Vector2(D_FACADE - 0.02, H_FACADE)], h, Color.WHITE, false)
	Bo.anneau(K, "plafond_bas", [Vector2(D_VITRE, 8.6), Vector2(D_FACADE, 13.4)], h, Color.WHITE, true)
	Bo.collision(K, [Vector2(D_HAUT, Y_HAUT), Vector2(D_COURSIVE, Y_COURSIVE), Vector2(D_FACADE, Y_COURSIVE)], h)
	Bo.collision(K, [Vector2(D_VITRE + 0.05, 8.6), Vector2(D_VITRE + 0.05, 11.0)], h)
	Bo.collision(K, [Vector2(D_FACADE - 0.05, Y_COURSIVE), Vector2(D_FACADE - 0.05, H_FACADE + 1.0)], h)
	# Les deux pignons du haut, de part et d'autre de la piscine (est) : laque noire, lisse d'or, écran.
	for s in [-1.0, 1.0]:
		var z: float = s * Bo.CZ
		var x0: float = Bo.CX + Bo.R + D_VITRE
		var x1: float = Bo.CX + Bo.R + D_FACADE
		K.box("laque_noire", x1 - x0, H_FACADE - 8.6, 0.3, (x0 + x1) / 2.0, (8.6 + H_FACADE) / 2.0, z)
		K.box("or", x1 - x0, 0.14, 0.4, (x0 + x1) / 2.0, H_FACADE, z)
		K.solide(x1 - x0, H_FACADE - 8.6, 0.3, (x0 + x1) / 2.0, (8.6 + H_FACADE) / 2.0, z)
	return places


# --- La façade --------------------------------------------------------------------------------------

## La peau de diodes sur tout le pourtour (au-dessus de la verrière du hall, au sud), ceinte de couronnes d'or
## aux trois étages ; la couronne du haut, le parapet d'or ; les murs qu'on ne traverse pas.
static func _facade(K, Bo) -> void:
	var porte := func(c, m): return hors_atrium(c, m)
	Bo.ecrans(K, D_FACADE + 0.02, 0.0, H_FACADE, 0, porte)
	Bo.ecrans(K, D_FACADE + 0.02, H_VERRIERE + 0.2, H_FACADE, 0, func(c, m): return not porte.call(c, m))
	for y in [Y1 + 0.15, 9.6, Y_COURSIVE + 0.2]:
		Bo.anneau(K, "or", [Vector2(D_FACADE, y), Vector2(D_FACADE + 0.5, y)])
		Bo.anneau(K, "or", [Vector2(D_FACADE + 0.5, y + 0.25), Vector2(D_FACADE + 0.5, y - 0.25)])
		Bo.anneau(K, "or", [Vector2(D_FACADE + 0.5, y - 0.25), Vector2(D_FACADE, y - 0.25)])
	Bo.anneau(K, "or", [Vector2(D_FACADE - 0.3, H_FACADE), Vector2(D_FACADE + 0.6, H_FACADE)])
	Bo.anneau(K, "or", [Vector2(D_FACADE + 0.6, H_FACADE), Vector2(D_FACADE + 0.6, H_FACADE - 0.6)])
	Bo.collision(K, [Vector2(D_FACADE, 0.0), Vector2(D_FACADE, Y1 + 1.2)], porte)
	# À l'est, au-dessus de la piscine, l'écran du virage tourné vers la pelouse, et le garde-corps de verre.
	var est := func(c, _m): return c == "E"
	Bo.ecrans(K, D_FACADE - 0.25, 7.0, H_FACADE - 0.4, 3, est, true)
	Bo.anneau(K, "laque_noire", [Vector2(D_FACADE - 0.2, Y1), Vector2(D_FACADE - 0.2, 7.0)], est, Color.WHITE, false)


# --- Le hall ----------------------------------------------------------------------------------------

## Le hall du niveau 0, sous les loges du sud (x de -17 à 17, z de -22,4 à -35,5). Au milieu, l'atrium sur deux
## étages : on passe la verrière et l'on a devant soi six mètres et demi de marbre libre, la rosace en roulette, le
## lustre de jetons qui pend du plafond des gradins, et au fond l'escalier impérial dont les deux volées montent
## vers le palier, en balcon sous la baie ouverte sur la pelouse. Sous le palier, l'allée du club : le tunnel des
## joueurs, la feuille du dernier match (le panneau du club est posé par fortune.gd, _entree). De part et
## d'autre, sous le plafond bas, la billetterie (ouest) et la boutique (est) ; derrière les volées, la galerie
## des trophées. L'accueil et le plan du stade attendent le visiteur à la porte.
static func _hall(K) -> void:
	var zn := -22.4
	var zs := Z_PORTE
	K.plan("marbre_noir", -17, 17, zs, zn, 0.01)
	# Le plafond bas des deux ailes et de la galerie, sous la promenade ; au-dessus de l'atrium, le dessous des
	# gradins du haut (le plafond à caissons de _haut) monte de 8,6 m à la baie à 13,4 m à la verrière.
	K.plan("plafond_bas", -17, -ATRIUM_X, zs, zn, Y1 - 0.02, false)
	K.plan("plafond_bas", ATRIUM_X, 17, zs, zn, Y1 - 0.02, false)
	K.plan("plafond_bas", -ATRIUM_X, ATRIUM_X, Z_BAIE, zn, Y1 - 0.02, false)
	# Les murs : le nord (sous les gradins), les pignons est et ouest, le dedans de la façade de part et d'autre de la verrière.
	K.box("marbre_noir", 34, Y1, 0.3, 0, Y1 / 2.0, zn - 0.15)
	K.solide(34, Y1, 0.3, 0, Y1 / 2.0, zn - 0.15)
	for s in [-1.0, 1.0]:
		K.box("marbre_noir", 0.3, Y1, zn - zs, s * 17.0, Y1 / 2.0, (zn + zs) / 2.0)
		K.solide(0.3, Y1, zn - zs, s * 17.0, Y1 / 2.0, (zn + zs) / 2.0)
		K.box("marbre_noir", 17.0 - ATRIUM_X, Y1, 0.3, s * (17.0 + ATRIUM_X) / 2.0, Y1 / 2.0, zs + 0.15)
		K.box("or", 0.5, Y1, 0.12, s * 13.5, Y1 / 2.0, zs + 0.36)
		for x in [5.0, 9.0, 13.0]:
			K.box("or", 0.5, Y1, 0.12, s * x, Y1 / 2.0, zn - 0.36)
	K.box("or", 34, 0.25, 0.1, 0, Y1 - 0.3, zn - 0.33)
	_verriere(K, zs)
	_atrium(K, zn, zs)
	_escalier(K)
	_allee_du_club(K, zn)
	_trophees(K, zn)
	_accueil(K, zs)
	# Les guichets de la billetterie (mur ouest du hall), comme à la caisse du casino : grilles d'or, lampes.
	for i in 4:
		var z := -24.5 - i * 2.8
		K.box("bois_laque", 0.8, 1.15, 2.2, -16.4, 0.58, z)
		K.box("marbre_noir", 0.9, 0.06, 2.3, -16.35, 1.18, z)
		K.box("or", 0.04, 1.6, 2.0, -16.0, 2.0, z)
		K.box("ambre_lum", 0.05, 0.3, 1.6, -16.6, 3.0, z)
		K.interaction("billetterie", "E : la billetterie", -15.6, 1.2, z, Vector3(1.0, 2.0, 2.4))
	K.obstacle(-16.8, -15.95, -33.8, -23.1, 0.0, 1.2)
	K.texte("BILLETTERIE", 9.0, 0.5, -16.75, 3.7, -28.7, PI / 2.0, "neon", Color("#FFD24A"))
	# La boutique du club (mur est) : maillots rouge et or sur des bustes, écharpes, ballons d'or sur les étagères.
	for i in 5:
		var z := -24.0 - i * 2.2
		K.box("laque_noire", 0.6, 2.6, 1.8, 16.5, 1.3, z)
		K.box("rouge_e", 0.42, 0.62, 0.3, 16.0, 1.6, z - 0.4)
		K.box("or", 0.44, 0.08, 0.32, 16.0, 1.28, z - 0.4)
		K.box("rouge_e", 0.42, 0.62, 0.3, 16.0, 1.6, z + 0.4)
		for k in 3:
			K.sph("or", 0.12, 16.25, 2.3, z - 0.5 + k * 0.5)
	K.obstacle(15.9, 16.85, -33.4, -22.9, 0.0, 2.6)
	K.interaction("boutique", "E : la boutique du club", 15.5, 1.2, -28.4, Vector3(1.0, 2.0, 10.0))
	K.texte("BOUTIQUE DU RACING CLUB MINUIT", 10.0, 0.42, 16.75, 3.7, -28.4, -PI / 2.0, "neon", Color("#FF5A6A"))
	# Les ailes basses : une lampe au-dessus des guichets et de la boutique, les gorges du plafond.
	for s in [-1.0, 1.0]:
		K.lumiere(s * 14.0, 3.8, -31.5, Color("#FFC27A"), 1.4, 9.0)
		K.box("ambre_lum", 13.0, 0.06, 0.3, s * 10.0, Y1 - 0.06, -24.0)
		K.box("ambre_lum", 17.0 - ATRIUM_X - 0.6, 0.06, 0.3, s * (17.0 + ATRIUM_X) / 2.0, Y1 - 0.06, -34.0)


## La verrière : vingt mètres de verre dans une résille d'or, haute de deux étages ; au milieu, les quatre portes
## sous leur imposte. Dehors, la marquise noire et or porte le nom du stade en néon, ses ampoules dessous.
static func _verriere(K, zs: float) -> void:
	var h := H_VERRIERE
	K.box("verre", 2.0 * ATRIUM_X, h, 0.06, 0, h / 2.0, zs)
	for x in [-10.0, -7.5, -5.0, -3.0, -1.5, 0.0, 1.5, 3.0, 5.0, 7.5, 10.0]:
		K.box("or", 0.12 if absf(x) <= PORTE_X else 0.16, h, 0.16, x, h / 2.0, zs)
	for y in [3.7, 6.3, h]:
		K.box("or", 2.0 * ATRIUM_X, 0.14, 0.18, 0, y, zs)
	# On ne traverse que les portes.
	for s in [-1.0, 1.0]:
		K.solide(ATRIUM_X - PORTE_X, 3.0, 0.2, s * (ATRIUM_X + PORTE_X) / 2.0, 1.5, zs)
	# Le dedans de la façade au-dessus de la verrière, jusqu'au plafond de l'atrium.
	K.box("marbre_noir", 2.0 * ATRIUM_X, 13.4 - h, 0.2, 0, (13.4 + h) / 2.0, zs + 0.2)
	K.box("ambre_lum", 2.0 * ATRIUM_X - 0.4, 0.08, 0.2, 0, h + 0.15, zs + 0.35)
	# La marquise.
	var zm := zs - 3.6
	K.box("laque_noire", 11.0, 0.35, 3.6, 0, 4.2, zs - 1.8)
	K.box("or", 11.2, 0.12, 0.16, 0, 4.4, zm)
	K.box("or", 11.2, 0.12, 0.16, 0, 4.0, zm)
	K.plan("laque_noire", -5.4, 5.4, zm, zs, 4.02, false)
	for i in 7:
		for k in 2:
			K.sph("ampoule", 0.045, -4.5 + i * 1.5, 3.99, zs - 0.9 - k * 1.6)
	K.texte("STADE DE LA FORTUNE", 9.0, 0.62, 0, 4.85, zm + 0.1, PI, "neon", Color("#FFD24A"))
	K.texte("RACING CLUB MINUIT", 4.0, 0.22, 0, 4.2, zm - 0.1, PI, "grave")
	for s in [-1.0, 1.0]:
		K.beam("or", Vector3(s * 5.2, 4.3, zm + 0.1), Vector3(s * 5.2, 8.4, zs - 0.1), 0.06, 0.06)
	load(LOT_E).ampoules(K, Vector3(-5.4, 4.22, zm - 0.02), Vector3(5.4, 4.22, zm - 0.02), 0.16, PI)
	K.lumiere(0, 3.4, zs - 1.9, Color("#FFC27A"), 1.4, 9.0)


## L'atrium : ses deux pignons de marbre noir à pilastres d'or (au-dessus des ailes basses), leurs enseignes qui
## disent où mène chaque volée, la rosace en roulette au sol, le lustre de jetons, le ruban de diodes au bord de
## la baie et la balustrade de la promenade au-dessus des volées.
static func _atrium(K, zn: float, zs: float) -> void:
	for s in [-1.0, 1.0]:
		var x: float = s * ATRIUM_X
		_pignon(K, x, s)
		# La poutre qui porte le pignon au-dessus de l'aile basse, sa gorge lumineuse.
		K.box("laque_noire", 0.5, 0.5, Z_BAIE - zs, x, Y1 - 0.25, (Z_BAIE + zs) / 2.0)
		K.box("or", 0.54, 0.08, Z_BAIE - zs, x, Y1 - 0.52, (Z_BAIE + zs) / 2.0)
		K.box("ambre_lum", 0.08, 0.1, Z_BAIE - zs - 0.4, x - s * 0.3, Y1 + 0.1, (Z_BAIE + zs) / 2.0)
		for z in [-27.5, -31.0, -34.5]:
			K.box("or", 0.12, 3.6, 0.5, x - s * 0.12, Y1 + 1.8, z)
		# Les enseignes : où mène la volée de ce côté-là.
		var cap: float = -s * PI / 2.0
		if s > 0.0:
			K.texte("PISCINE DES PARIEURS", 7.0, 0.62, x - 0.2, 7.4, -31.0, cap, "neon", Color("#4DE0FF"))
			K.texte("PENTHOUSE · TRIBUNES 100", 6.0, 0.36, x - 0.2, 6.6, -31.0, cap, "neon", Color("#FFD24A"))
		else:
			K.texte("JACKPOT LOUNGE", 7.0, 0.62, x + 0.2, 7.4, -31.0, cap, "neon", Color("#FFD24A"))
			K.texte("MINUIT LIVE · TRIBUNES 100", 6.0, 0.36, x + 0.2, 6.6, -31.0, cap, "neon", Color("#FF4D8D"))
	# La balustrade de la promenade, au-dessus des volées, de part et d'autre du palier.
	for s in [-1.0, 1.0]:
		K.garde_corps(s * PALIER_X, Z_BAIE, s * ATRIUM_X, Z_BAIE, Y1)
	# Le ruban de diodes au bord du plafond, au-dessus de la baie : le nom du club qui défile.
	load(LOT_E).ecran(K, 0, 8.25, Z_BAIE - 0.05, 2.0 * ATRIUM_X - 0.4, 0.6, PI, 4, 0.3)
	K.box("or", 2.0 * ATRIUM_X, 0.1, 0.2, 0, 7.9, Z_BAIE)
	# La rosace : une roue de roulette en marbre et laque, rouge et noir, cerclée d'or, sous le lustre.
	var c := ROSACE
	K.anneau("or", c.x, c.y, 2.95, 3.12, 0.016)
	for i in 36:
		var a0 := TAU * i / 36.0
		K.anneau("laque_rouge" if i % 2 == 0 else "laque_noire", c.x, c.y, 2.3, 2.95, 0.015, a0, a0 + TAU / 36.0)
	K.anneau("or", c.x, c.y, 2.2, 2.3, 0.016)
	K.disque("or", c.x, c.y, 0.55, 0.017, 24)
	for i in 8:
		var a := TAU * i / 8.0
		K.beam("or", Vector3(c.x + sin(a) * 0.55, 0.016, c.y - cos(a) * 0.55), Vector3(c.x + sin(a) * 2.2, 0.016, c.y - cos(a) * 2.2), 0.06, 0.01)
	# Le lustre de jetons : une pile de douze jetons rouges, noirs et or, pendue au plafond par une tige d'or, son
	# anneau d'ampoules dessous.
	for i in 12:
		var m: String = ["rouge_e", "laque_noire", "or"][i % 3]
		K.cyl(m, 1.8, 1.8, 0.26, c.x, 10.4 - i * 0.3, c.y, 32)
	K.cyl("or", 0.04, 0.04, 1.2, c.x, 11.2, c.y, 6)
	K.tore("ambre_lum", 1.95, 0.06, Transform3D(Basis(), Vector3(c.x, 7.0, c.y)), 32)
	for i in 16:
		var a := TAU * i / 16.0
		K.sph("ampoule", 0.09, c.x + sin(a) * 1.95, 6.9, c.y - cos(a) * 1.95)
	K.lumiere(c.x, 6.4, c.y, Color("#FFD08A"), 2.6, 17.0)


## Un pignon de l'atrium, à x : du plafond bas (y 4,5) au dessous des gradins du haut, de la baie à la verrière.
static func _pignon(K, x: float, s: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(x, Y1, Z_BAIE)
	var b := Vector3(x, Y1, Z_PORTE)
	var c := Vector3(x, 13.4, Z_PORTE)
	var d := Vector3(x, 8.6, Z_BAIE)
	var uv := func(p: Vector3) -> Vector2: return Vector2(p.z, p.y) / 2.0
	K._quad(st, a, b, c, d, Vector3(-s, 0, 0), uv.call(a), uv.call(b), uv.call(c), uv.call(d))
	K.put("marbre_noir", st.commit())


## L'escalier impérial : deux volées suspendues, marches de marbre noir à nez d'or et tapis rouge sur deux limons
## laqués, qui montent des ailes vers le palier ; leurs rampes de verre à main courante d'or. On passe dessous là
## où l'on tient debout : l'atrium s'ouvre ainsi sur l'allée du club et la galerie des trophées. Le palier, en
## balcon sur l'atrium, porté par deux colonnes d'or.
static func _escalier(K) -> void:
	var largeur := VOLEE_Z1 - VOLEE_Z0
	var zm := (VOLEE_Z0 + VOLEE_Z1) / 2.0
	var giron := (VOLEE_PIED - PALIER_X) / MARCHES
	# Là où le dessous de la volée passe à 2,2 m : au-delà, vers le pied, on ne passe plus dessous.
	var x_libre := PALIER_X + (VOLEE_PIED - PALIER_X) * (1.0 - 2.2 / Y1)
	for s in [-1.0, 1.0]:
		for i in MARCHES:
			var y := Y1 * (i + 1) / MARCHES
			var x: float = s * (VOLEE_PIED - giron * (i + 0.5))
			K.box("marbre_noir", giron + 0.02, 0.14, largeur - 0.3, x, y - 0.07, zm)
			K.box("or", 0.04, 0.04, largeur - 0.3, s * (VOLEE_PIED - giron * i) - s * 0.02, y - 0.02, zm)
			K.box("tapis_rouge", giron, 0.02, 1.8, x, y + 0.01, zm)
		var pied := Vector2(s * VOLEE_PIED, 0.0)
		var haut_ := Vector2(s * PALIER_X, Y1)
		_rampe_x(K, pied, haut_, VOLEE_Z0 + 0.1, VOLEE_Z1 - 0.1)
		for z in [VOLEE_Z0, VOLEE_Z1]:
			var a := Vector3(pied.x, 0.0, z + (0.12 if z < zm else -0.12))
			var b := Vector3(haut_.x, Y1, a.z)
			# Le limon, sous les marches, et sa baguette d'or ; la rampe au-dessus.
			K.beam("laque_noire", a + Vector3(0, -0.12, 0), b + Vector3(0, -0.12, 0), 0.24, 0.5)
			K.beam("or", a + Vector3(0, -0.4, 0), b + Vector3(0, -0.4, 0), 0.26, 0.05)
			K.beam("verre", a + Vector3(0, 0.62, 0), b + Vector3(0, 0.62, 0), 0.02, 0.95)
			K.beam("or", a + Vector3(0, 1.12, 0), b + Vector3(0, 1.12, 0), 0.07, 0.07)
			for k in 7:
				var p := a.lerp(b, k / 6.0)
				K.cyl("or", 0.025, 0.025, 1.1, p.x, p.y + 0.55, p.z, 8)
			# Les rampes qu'on ne traverse pas : du sol là où l'on ne passe pas dessous, à hauteur de marche au-delà.
			K.segment(pied.x, z, s * x_libre, z, 0.14, 0.0, 2.2 + 1.2)
			for k in 4:
				var x0: float = lerpf(x_libre, PALIER_X, k / 4.0)
				var x1: float = lerpf(x_libre, PALIER_X, (k + 1) / 4.0)
				var y0: float = Y1 * (VOLEE_PIED - x0) / (VOLEE_PIED - PALIER_X)
				var y1: float = Y1 * (VOLEE_PIED - x1) / (VOLEE_PIED - PALIER_X)
				K.segment(s * x0, z, s * x1, z, 0.14, y0, y1 - y0 + 1.2)
		# Sous la volée, là où elle devient trop basse : un écran de verre cerclé d'or, qu'on ne traverse pas.
		K.box("verre", 0.04, 2.0, largeur - 0.3, s * x_libre, 1.0, zm)
		K.box("or", 0.08, 0.06, largeur - 0.3, s * x_libre, 0.03, zm)
		K.solide(0.14, 2.2, largeur, s * x_libre, 1.1, zm)
		# Au pied, deux bornes d'or et leur lanterne.
		for z in [VOLEE_Z0 - 0.2, VOLEE_Z1 + 0.2]:
			K.cyl("or", 0.14, 0.18, 1.3, s * (VOLEE_PIED + 0.15), 0.65, z, 12)
			K.sph("ampoule", 0.16, s * (VOLEE_PIED + 0.15), 1.42, z)
		K.lumiere(s * 8.5, 6.6, zm, Color("#FFC27A"), 1.3, 10.0)
	# Les deux colonnes d'or qui portent le palier.
	for s in [-1.0, 1.0]:
		K.cyl("or", 0.16, 0.2, Y1 - 0.4, s * (PALIER_X - 0.4), (Y1 - 0.4) / 2.0, VOLEE_Z0 + 0.4, 16)
		K.cyl("laque_noire", 0.3, 0.3, 0.2, s * (PALIER_X - 0.4), 0.1, VOLEE_Z0 + 0.4, 16)
		K.rond(s * (PALIER_X - 0.4), VOLEE_Z0 + 0.4, 0.25)
	# Le palier : sa dalle épaisse, sa sous-face à caissons, son bandeau d'or et sa balustrade en balcon.
	K.box("laque_noire", 2.0 * PALIER_X, 0.4, Z_BAIE - VOLEE_Z0, 0, Y1 - 0.2, (VOLEE_Z0 + Z_BAIE) / 2.0)
	K.plan("plafond_bas", -PALIER_X, PALIER_X, VOLEE_Z0, Z_BAIE, Y1 - 0.41, false)
	K.box("or", 2.0 * PALIER_X + 0.1, 0.08, 0.1, 0, Y1 - 0.05, VOLEE_Z0 - 0.02)
	K.box("or", 2.0 * PALIER_X + 0.1, 0.08, 0.1, 0, Y1 - 0.37, VOLEE_Z0 - 0.02)
	K.texte("RACING CLUB MINUIT", 5.0, 0.24, 0, Y1 - 0.21, VOLEE_Z0 - 0.08, PI, "neon", Color("#FF5A6A"))
	K.garde_corps(-PALIER_X, VOLEE_Z0, PALIER_X, VOLEE_Z0, Y1)


## Une rampe de collision sous une volée qui monte le long de x : du pied (x, y) au haut (x, y), entre z0 et z1.
static func _rampe_x(K, a: Vector2, b: Vector2, z0: float, z1: float) -> void:
	var d := b - a
	var forme := BoxShape3D.new()
	forme.size = Vector3(d.length(), 0.3, z1 - z0)
	var c := (a + b) / 2.0
	K.forme(Transform3D(Basis(Vector3.BACK, atan2(d.y, d.x)), Vector3(c.x, c.y - 0.15, (z0 + z1) / 2.0)), forme)


## L'allée du club, sous le palier, dans l'axe de la porte : au fond le tunnel des joueurs, entre la feuille du
## dernier match (à droite en entrant) et le panneau du club (à gauche, fortune.gd, _entree).
static func _allee_du_club(K, zn: float) -> void:
	# Le tunnel des joueurs, au nord : deux vantaux d'acier sous un fronton rouge, fermés (les joueurs passent par là).
	K.box("acier_sombre", 3.0, 2.8, 0.1, 0, 1.4, zn - 0.36)
	K.box("or", 0.06, 2.8, 0.12, 0, 1.4, zn - 0.4)
	K.box("laque_rouge", 3.6, 0.6, 0.2, 0, 3.1, zn - 0.4)
	K.texte("TUNNEL DES JOUEURS", 3.4, 0.3, 0, 3.1, zn - 0.52, PI, "grave")
	K.interaction("tunnel", "E : le tunnel des joueurs", 0, 1.3, zn - 1.0, Vector3(3.0, 2.6, 1.2))
	load(LOT_E).cadre_ampoules(K, 0, 1.6, zn - 0.45, 3.4, 3.2, PI, 0.14)
	# La feuille du dernier match (la même qu'au tableau d'affichage), à droite du tunnel.
	var x := -3.2
	var z := zn - 0.36
	K.box("laque_noire", 2.3, 2.2, 0.12, x, 1.9, z)
	K.box("or", 2.5, 0.1, 0.16, x, 3.05, z)
	K.texte("LA FEUILLE DU DERNIER MATCH", 2.1, 0.22, x, 2.75, z - 0.08, PI, "grave")
	K.box("creme", 1.8, 1.4, 0.04, x, 1.75, z - 0.08)
	K.interaction("feuille", "E : lire la feuille du dernier match", x, 1.6, zn - 1.0, Vector3(2.3, 2.4, 1.2))
	K.lumiere(0, 3.5, -25.4, Color("#FFC27A"), 1.1, 8.0)


## La galerie des trophées, derrière les volées, sous la promenade : des vitrines éclairées, une coupe d'or
## dans chacune ; on y passe de l'allée du club aux ailes.
static func _trophees(K, zn: float) -> void:
	for x in [-11.5, -7.0, 7.0, 11.5]:
		var z := zn - 0.8
		K.box("laque_noire", 1.6, 1.0, 0.8, x, 0.5, z)
		K.box("or", 1.64, 0.06, 0.84, x, 1.02, z)
		K.box("verre", 1.5, 1.2, 0.7, x, 1.65, z)
		K.box("ambre_lum", 1.4, 0.04, 0.6, x, 2.27, z)
		K.cyl("or", 0.05, 0.12, 0.25, x, 1.17, z, 10)
		K.cyl("or", 0.22, 0.08, 0.4, x, 1.5, z, 14)
		K.tore("or", 0.12, 0.02, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(x - 0.24, 1.55, z)), 10)
		K.tore("or", 0.12, 0.02, Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(x + 0.24, 1.55, z)), 10)
		K.obstacle(x - 0.8, x + 0.8, z - 0.4, z + 0.4, 0.0, 2.3)
	K.texte("LA GALERIE DES TROPHÉES", 6.0, 0.3, -9.25, 3.6, zn - 0.42, PI, "grave")
	K.texte("LA GALERIE DES TROPHÉES", 6.0, 0.3, 9.25, 3.6, zn - 0.42, PI, "grave")
	for s in [-1.0, 1.0]:
		K.lumiere(s * 9.25, 3.6, -24.6, Color("#FFC27A"), 1.0, 8.0)


## L'accueil, à droite en entrant : le comptoir rouge et or de l'hôtesse (fortune.gd la pose, et lui fait dire
## le chemin) ; à gauche, le plan du stade sur sa stèle.
static func _accueil(K, zs: float) -> void:
	var x := -6.8
	var z := zs + 3.2
	K.box("laque_rouge", 2.6, 1.05, 0.7, x, 0.53, z)
	K.box("or", 2.7, 0.06, 0.8, x, 1.08, z)
	K.box("laque_noire", 2.6, 0.12, 0.72, x, 0.06, z)
	K.texte("ACCUEIL", 2.0, 0.28, x, 0.62, z - 0.37, PI, "neon", Color("#FFD24A"))
	K.obstacle(x - 1.3, x + 1.3, z - 0.35, z + 0.35, 0.0, 1.1)
	K.interaction("accueil", "E : demander son chemin à l'accueil", x, 1.1, z - 0.9, Vector3(2.6, 2.0, 1.0))
	# Le plan du stade : une stèle noire, son cadre d'or, les lieux et leur côté.
	var px := 6.8
	var pz := zs + 3.0
	K.box("laque_noire", 1.7, 2.5, 0.25, px, 1.25, pz)
	K.box("or", 1.8, 0.08, 0.3, px, 2.52, pz)
	K.box("or", 0.06, 2.5, 0.3, px - 0.88, 1.25, pz)
	K.box("or", 0.06, 2.5, 0.3, px + 0.88, 1.25, pz)
	K.obstacle(px - 0.9, px + 0.9, pz - 0.15, pz + 0.15)
	var lignes := [["STADE DE LA FORTUNE", 0.16, PAL_OR],
		["Tribunes et promenade : par l'escalier", 0.1, PAL_IVOIRE],
		["À gauche : la boutique du club,", 0.1, PAL_IVOIRE],
		["la piscine des parieurs, le penthouse", 0.1, PAL_IVOIRE],
		["À droite : la billetterie,", 0.1, PAL_IVOIRE],
		["le Jackpot Lounge, Minuit Live", 0.1, PAL_IVOIRE],
		["Sous le palier : le tunnel des joueurs", 0.1, PAL_IVOIRE],
		["Derrière l'escalier : les trophées", 0.1, PAL_IVOIRE]]
	var y := 2.25
	for l in lignes:
		K.texte(l[0], 1.5, l[1], px, y, pz - 0.14, PI, "grave", l[2])
		y -= l[1] + 0.12


# --- La piscine des parieurs (est) ---------------------------------------------------------------------

## Au niveau de la promenade, derrière le but est : le pont de teck, le bassin à débordement face à la pelouse,
## quatre cabanas rayées rouge et blanc, des transats, le bar de la piscine et ses palmiers.
static func _piscine(K) -> void:
	var x0 := 23.0 + D_VITRE
	var x1 := 23.0 + D_FACADE
	K.plan("plancher", x0, x1, -10.0, 10.0, Y1)
	K.dalle(x0, x1, -10.0, 10.0, Y1)
	# Le bassin, son bord d'or, l'eau qui déborde vers la pelouse.
	K.plan("eau", x0 + 0.4, x0 + 3.6, -8.5, 8.5, Y1 - 0.08)
	K.box("or", 3.4, 0.1, 0.14, x0 + 2.0, Y1 + 0.02, -8.55)
	K.box("or", 3.4, 0.1, 0.14, x0 + 2.0, Y1 + 0.02, 8.55)
	K.box("or", 0.14, 0.1, 17.1, x0 + 3.65, Y1 + 0.02, 0)
	K.box("nappe", 0.04, 0.5, 17.0, x0 + 0.38, Y1 - 0.3, 0)
	K.obstacle(x0, x0 + 3.7, -8.6, 8.6, Y1, 1.0)
	# Les cabanas, deux de chaque côté du bar.
	for z in [-7.4, -4.4, 4.4, 7.4]:
		var cx := x1 - 1.3
		K.box("blanc", 2.2, 0.08, 2.6, cx, Y1 + 2.6, z)
		K.box("rouge_e", 2.2, 2.4, 0.04, cx, Y1 + 1.3, z - 1.3)
		K.box("rouge_e", 2.2, 2.4, 0.04, cx, Y1 + 1.3, z + 1.3)
		K.box("rouge_e", 0.05, 2.4, 2.6, cx + 1.1, Y1 + 1.3, z)
		K.box("coussin", 1.6, 0.4, 1.8, cx + 0.1, Y1 + 0.2, z)
		K.obstacle(cx - 0.9, cx + 1.15, z - 1.3, z + 1.3, Y1, 2.4)
	K.lumiere(x1 - 2.0, Y1 + 2.2, -5.9, Color("#FFB86A"), 0.6, 6.0)
	K.lumiere(x1 - 2.0, Y1 + 2.2, 5.9, Color("#FFB86A"), 0.6, 6.0)
	# Les transats sur le pont, entre le bassin et les cabanas.
	for i in 6:
		var z := -7.5 + i * 3.0
		K.box("blanc", 0.7, 0.3, 1.8, x0 + 4.6, Y1 + 0.3, z)
		K.box("blanc", 0.7, 0.6, 0.1, x0 + 4.6, Y1 + 0.6, z - 0.9)
	# Le bar de la piscine, entre les cabanas.
	K.box("laque_rouge", 1.0, 1.1, 4.0, x1 - 1.6, Y1 + 0.55, 0)
	K.box("or", 1.1, 0.06, 4.1, x1 - 1.6, Y1 + 1.12, 0)
	K.obstacle(x1 - 2.1, x1, -2.0, 2.0, Y1, 1.2)
	K.texte("LA PISCINE DES PARIEURS", 8.0, 0.6, x1 - 0.3, Y1 + 3.4, 0, -PI / 2.0, "neon", Color("#4DE0FF"))
	K.interaction("piscine", "E : le bar de la piscine", x1 - 2.6, Y1 + 1.0, 0, Vector3(1.2, 2.0, 4.0))
	load(LOT_E).palmiers(K, [[x0 + 6.4, -9.3, 0.3, 0.7, Y1], [x0 + 6.4, 9.3, 1.1, 0.75, Y1], [x0 + 6.4, 0.0, 2.0, 0.6, Y1]])


# --- Le Jackpot Lounge (ouest) --------------------------------------------------------------------------

## Derrière le but ouest, sous les gradins du haut : la salle ouverte sur la pelouse, ses machines à sous en
## rangs, le bar d'onyx, et devant, la scène de Minuit Live où se joue le show de la mi-temps.
static func _lounge(K) -> void:
	var x0 := -(23.0 + D_VITRE)
	var x1 := -(23.0 + 14.5)
	K.plan("moquette_c", x1, x0, -10.0, 10.0, Y1 + 0.01)
	K.dalle(x1 - 5.0, x0, -10.0, 10.0, Y1)
	K.box("bois_laque", 0.3, 4.1, 20.0, x1 - 0.15, Y1 + 2.05, 0)
	K.solide(0.3, 4.1, 20.0, x1 - 0.15, Y1 + 2.05, 0)
	K.box("fenetre", 0.05, 0.3, 20.0, x1 + 0.05, 8.1, 0)
	# Les machines à sous, en deux rangs dos à dos.
	for r in 2:
		for i in 7:
			var z := -7.8 + i * 2.6
			var x := x1 + 1.2 + r * 1.3
			var ry := PI / 2.0 if r == 0 else -PI / 2.0
			K.box("laque_rouge", 0.8, 1.6, 0.9, x, Y1 + 0.8, z)
			K.box("or", 0.82, 0.18, 0.92, x, Y1 + 1.7, z)
			load(LOT_E).ecran(K, x + (0.41 if r == 0 else -0.41), Y1 + 1.25, z, 0.6, 0.5, ry, 1 + (i + r) % 6, i * 0.7)
		K.obstacle(x1 + 0.75, x1 + 2.95, -8.4, 8.0, Y1, 1.8)
	K.interaction("machines", "E : une machine à sous", x1 + 3.4, Y1 + 1.0, 0, Vector3(1.0, 2.0, 16.0))
	# Le bar d'onyx.
	K.box("onyx", 0.9, 1.1, 6.0, x1 + 6.0, Y1 + 0.55, 0)
	K.box("or", 1.0, 0.06, 6.1, x1 + 6.0, Y1 + 1.12, 0)
	K.obstacle(x1 + 5.5, x1 + 6.5, -3.0, 3.0, Y1, 1.2)
	K.texte("JACKPOT LOUNGE", 10.0, 0.9, x1 + 0.1, 7.2, 0, PI / 2.0, "neon", Color("#FFD24A"))
	# La scène de Minuit Live, sur la promenade devant le lounge : l'estrade, son arche d'ampoules, l'enseigne.
	var sx := -(23.0 + 8.8)
	K.box("laque_noire", 2.4, 0.4, 7.0, sx, Y1 + 0.2, 0)
	K.box("or", 2.5, 0.06, 7.1, sx, Y1 + 0.41, 0)
	K.obstacle(sx - 1.2, sx + 1.2, -3.5, 3.5, Y1, 1.0)
	load(LOT_E).cadre_ampoules(K, sx - 1.1, Y1 + 2.8, 0, 6.8, 4.6, PI / 2.0)
	K.texte("MINUIT LIVE", 5.0, 0.7, sx - 1.1, Y1 + 5.5, 0, PI / 2.0, "neon", Color("#FF4D8D"))
	K.interaction("scene", "E : la scène de Minuit Live", sx + 1.6, Y1 + 1.0, 0, Vector3(1.0, 2.0, 7.0))
	K.lumiere(sx, Y1 + 3.5, 0, Color("#FF6AA8"), 1.2, 9.0)
	K.lumiere(x1 + 4.0, Y1 + 3.4, 0, Color("#FFB86A"), 1.0, 10.0)


# --- Les escalators et l'ascenseur ------------------------------------------------------------------------

## Dans chaque coin de la promenade, une porte d'or ouvre sur les escalators du haut (E : on monte à la
## coursive) ; en haut, la même porte redescend. Rend leurs paires de points [bas, haut, cap].
static func _escalators(K, Bo) -> void:
	var e: Array = Bo.echantillons()
	for i in [8, 19, 32, 43]:
		var s: Array = e[i]
		var n: Vector2 = s[1]
		var cap := atan2(-n.x, -n.y)
		var bas: Vector3 = Bo.pt(s, D_VITRE - 0.6, Y1)
		var haut_: Vector3 = Bo.pt(s, D_COURSIVE + 0.7, Y_COURSIVE)
		var porte: Vector3 = Bo.pt(s, D_VITRE + 0.05, Y1)
		K.box("laque_noire", 2.6, 3.2, 0.2, porte.x, Y1 + 1.6, porte.z, cap)
		K.box("or", 2.8, 0.2, 0.26, porte.x, Y1 + 3.3, porte.z, cap)
		K.box("acier", 1.2, 2.6, 0.22, porte.x, Y1 + 1.3, porte.z, cap)
		var l = K.texte("ESCALATORS · TRIBUNE 300", 2.6, 0.22, porte.x, Y1 + 3.6, porte.z, cap + PI, "neon", Color("#FFD24A"))
		l.position -= Vector3(n.x, 0, n.y) * 0.2
		var a = K.interaction("escalator_%d" % i, "E : les escalators, vers la tribune du haut", bas.x, Y1 + 1.2, bas.z, Vector3(2.4, 2.4, 1.2))
		a.set_meta("interact", "monter")
		a.set_meta("vers", haut_)
		a.set_meta("cap", cap + PI)
		var porte_h: Vector3 = Bo.pt(s, D_FACADE - 0.05, Y_COURSIVE)
		K.box("laque_noire", 2.6, 2.6, 0.2, porte_h.x, Y_COURSIVE + 1.3, porte_h.z, cap)
		K.box("or", 2.8, 0.2, 0.26, porte_h.x, Y_COURSIVE + 2.7, porte_h.z, cap)
		var b = K.interaction("escalator_bas_%d" % i, "E : les escalators, vers la promenade", haut_.x, Y_COURSIVE + 1.2, haut_.z, Vector3(2.4, 2.4, 1.2))
		b.set_meta("interact", "monter")
		b.set_meta("vers", bas)
		b.set_meta("cap", cap)
		var l2 = K.texte("ESCALATORS · PROMENADE", 2.6, 0.2, porte_h.x, Y_COURSIVE + 2.95, porte_h.z, cap + PI, "neon", Color("#FFD24A"))
		l2.position -= Vector3(n.x, 0, n.y) * 0.2
	# L'ascenseur de verre du penthouse, sur la promenade sud, à l'est de l'escalier : la cage, sa colonne d'or.
	var ax := 7.6
	var az: float = -(Bo.B + 8.6)
	for k in 4:
		var a2 := TAU * k / 4.0 + PI / 4.0
		K.cyl("or", 0.08, 0.08, 13.0, ax + cos(a2) * 0.9, Y1 + 6.5, az + sin(a2) * 0.9, 8)
	K.cyl("verre", 0.95, 0.95, 13.0, ax, Y1 + 6.5, az, 20)
	K.cyl("ambre_lum", 0.98, 0.98, 0.12, ax, Y1 + 2.6, az, 20)
	K.rond(ax, az, 1.0, Y1, 2.4)
	var asc = K.interaction("ascenseur", "E : l'ascenseur du penthouse du président", ax - 1.4, Y1 + 1.2, az, Vector3(1.2, 2.4, 2.0))
	asc.set_meta("interact", "monter")
	asc.set_meta("vers", Vector3(4.6, 16.55, -24.0))
	asc.set_meta("cap", PI / 2.0)
	K.texte("PENTHOUSE", 2.0, 0.3, ax - 1.0, Y1 + 3.0, az, -PI / 2.0, "neon", Color("#FFD24A"))


# --- Le penthouse du président ------------------------------------------------------------------------

## Une loge de verre et d'or suspendue sous la roue du toit, au-dessus de la tribune sud (x de -6 à 6, z de
## -27 à -21, y 16,5 à 19,5) : le parquet, le bureau de M. Castellane, le canapé de cuir, la vitre sur la pelouse.
static func _penthouse(K) -> void:
	var y := 16.5
	var x0 := -6.0
	var x1 := 6.0
	var z0 := -27.0
	var z1 := -21.0
	K.box("laque_noire", x1 - x0 + 0.4, 0.4, z1 - z0 + 0.4, 0, y - 0.2, (z0 + z1) / 2.0)
	K.plan("bois_laque", x0, x1, z0, z1, y + 0.01)
	K.dalle(x0, x1, z0, z1, y)
	K.box("laque_noire", x1 - x0 + 0.4, 0.3, z1 - z0 + 0.4, 0, y + 3.15, (z0 + z1) / 2.0)
	K.plan("plafond_bas", x0, x1, z0, z1, y + 2.99, false)
	K.box("or", x1 - x0 + 0.5, 0.12, 0.12, 0, y + 3.0, z1 + 0.2)
	K.box("or", x1 - x0 + 0.5, 0.12, 0.12, 0, y + 0.02, z1 + 0.2)
	# Les vitres : la grande baie sur la pelouse (nord), les côtés ; le fond, laqué rouge, porte le blason.
	K.box("verre", x1 - x0, 3.0, 0.05, 0, y + 1.5, z1)
	for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		K.box("or", 0.1, 3.0, 0.1, x, y + 1.5, z1)
	for s in [-1.0, 1.0]:
		K.box("verre", 0.05, 3.0, z1 - z0, s * 6.0, y + 1.5, (z0 + z1) / 2.0)
	K.box("laque_rouge", x1 - x0, 3.0, 0.1, 0, y + 1.5, z0)
	K.texte("R C M", 3.0, 0.8, 0, y + 2.0, z0 + 0.08, 0.0, "grave")
	K.solide(x1 - x0, 3.0, 0.1, 0, y + 1.5, z1)
	K.solide(x1 - x0, 3.0, 0.1, 0, y + 1.5, z0)
	for s in [-1.0, 1.0]:
		K.solide(0.1, 3.0, z1 - z0, s * 6.0, y + 1.5, (z0 + z1) / 2.0)
	# Le bureau d'acajou et d'or, le fauteuil, le canapé de cuir, le bar à cigares.
	K.box("bois_laque", 2.4, 0.78, 1.1, -1.5, y + 0.39, -23.0)
	K.box("or", 2.42, 0.04, 1.12, -1.5, y + 0.8, -23.0)
	K.box("cuir_noir", 0.7, 1.2, 0.7, -1.5, y + 0.6, -24.1)
	K.box("cuir_noir", 3.0, 0.5, 0.9, 2.0, y + 0.25, -25.8)
	K.box("cuir_noir", 3.0, 0.6, 0.2, 2.0, y + 0.7, -26.2)
	K.box("bois_laque", 1.4, 1.0, 0.5, -4.6, y + 0.5, -26.5)
	K.obstacle(-2.7, -0.3, -23.55, -22.45, y, 0.9)
	K.obstacle(0.5, 3.5, -26.3, -25.3, y, 0.9)
	# Les tiges d'or qui le pendent à la roue.
	for x in [-5.5, 5.5]:
		for z in [-26.5, -21.5]:
			K.cyl("or", 0.06, 0.06, 21.0 - y - 3.15, x, (21.0 + y + 3.15) / 2.0, z, 6)
	K.lumiere(0, y + 2.5, -24.0, Color("#FFD08A"), 1.2, 9.0)
	# L'ascenseur, côté est : la porte, et le retour à la promenade.
	K.box("or", 0.2, 2.6, 1.6, 5.9, y + 1.3, -24.0)
	var r = K.interaction("ascenseur_retour", "E : redescendre à la promenade", 5.2, y + 1.2, -24.0, Vector3(1.0, 2.4, 1.8))
	r.set_meta("interact", "monter")
	r.set_meta("vers", Vector3(6.0, Y1 + 0.05, -24.6))
	r.set_meta("cap", PI)
	# La passerelle de verre jusqu'à la cage de l'ascenseur.
	K.box("verre", 1.6, 0.06, 1.4, 6.8, y, -24.4)


# --- Les sièges ------------------------------------------------------------------------------------------

## Les sièges rouges des deux tribunes, en une seule forme instanciée ; un rang sur quatre est d'or.
static func _sieges(K, places: Dictionary) -> void:
	var tout: Array = places.bas + places.haut
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var Bo = load(BOL)
	_pave(Bo, st, Vector3(0.46, 0.08, 0.42), Vector3(0, 0.42, 0.0))
	_pave(Bo, st, Vector3(0.46, 0.5, 0.07), Vector3(0, 0.66, -0.22))
	_pave(Bo, st, Vector3(0.06, 0.42, 0.3), Vector3(-0.2, 0.21, 0.05))
	_pave(Bo, st, Vector3(0.06, 0.42, 0.3), Vector3(0.2, 0.21, 0.05))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = st.commit()
	mm.instance_count = tout.size()
	var rouge := Color("#B3121F")
	var rouge2 := Color("#8E0E19")
	var or_ := Color("#D9A441")
	for i in tout.size():
		var p: Array = tout[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(0, p[1], 0)), p[0]))
		var rang := int(round((p[0].y - 1.7) / 0.4)) if p[0].y < 5.0 else int(round((p[0].y - Y_HAUT) / 0.5))
		mm.set_instance_color(i, or_ if rang % 4 == 3 else (rouge if (i / 14) % 2 == 0 else rouge2))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.55
	mat.metallic = 0.1
	var mi := MultiMeshInstance3D.new()
	mi.name = "sieges"
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.racine.add_child(mi)


## Un pavé dans la forme d'un siège (la face avant du siège regarde vers +z local : la pelouse).
static func _pave(Bo, st: SurfaceTool, t: Vector3, c: Vector3) -> void:
	var h := t / 2.0
	var faces := [[Vector3.UP, 1], [Vector3.DOWN, 1], [Vector3.RIGHT, 0], [Vector3.LEFT, 0], [Vector3.BACK, 2], [Vector3.FORWARD, 2]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = Vector3(n.y, n.z, n.x).abs()
		var v: Vector3 = n.cross(u)
		var o: Vector3 = c + n * h
		var su := u * h
		var sv := v * h
		Bo._quad(st, o - su - sv, o + su - sv, o + su + sv, o - su + sv, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color.WHITE)
