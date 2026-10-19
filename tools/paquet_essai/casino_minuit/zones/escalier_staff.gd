extends RefCounted
## Lot D, zone ESC-STAFF (js/zones/d-esc-staff.js) : l'escalier du personnel, gaine [36, 40] × [-12, -4], du
## sous-sol (y -5) à la mezzanine (y 6), en béton brut. Cage à deux volées par niveau, séparées par le mur
## d'échiffre (x = 38) : volée ouest vers le nord, demi-palier au nord, volée est vers le sud.
## B1 (-5) → demi-palier bas (-2,5) → RDC (0) → demi-palier haut (3) → mezzanine (6). Les paliers donnent au sud
## par les baies de 1,8 m de l'épine (B-COULOIR) et du couloir de service (R-SERVICE), et par la porte M12 vers
## la galerie des boutiques (posée par minuit.gd, close sous le seuil des coulisses). Zone en y absolu.

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"
const X0 := 36.0
const X1 := 40.0
const XI0 := 36.2
const XI1 := 39.8
const ZN := -10.5
const ZS := -5.5
const XW := 37.05
const XE := 38.95
const LW := 1.7


## Une volée de marches pleines (volee) : du pied (zf, y0) à la tête (zh, y1), massif visible jusqu'à y_base,
## nez de marche jaunes, main courante côté mur ; la marche se fait sur une rampe de collision.
static func _volee(K, D, xc: float, zf: float, zh: float, y0: float, y1: float, y_base: float, mur_x: float) -> void:
	var n := int(round(absf(y1 - y0) / 0.167))
	var run := (zh - zf) / n
	var rs := (y1 - y0) / n
	var dir := signf(run)
	for i in n:
		var top := y0 + rs * (i + 1)
		var za := zf + run * i
		var zb := zf + run * (i + 1)
		D.bloc(K, xc - LW / 2.0, xc + LW / 2.0, y_base, top, minf(za, zb), maxf(za, zb), false)
		D.bx(K, "jaune", LW, 0.012, 0.06, xc, top + 0.006, za + dir * 0.03)
	K.rampe(xc, LW, zf, y0, zh, y1)
	K.beam("acier", Vector3(mur_x, y0 + 0.98, zf), Vector3(mur_x, y1 + 0.98, zh), 0.045, 0.045)


static func construire(K) -> void:
	var D = load(LOT_D)
	K.zone_debut("ESC-STAFF")

	# --- l'enveloppe : flancs, fond nord, plafond ---
	D.bloc(K, X0, XI0, -5.0, 9.2, -12.0, -4.0)
	D.bloc(K, XI1, X1, -5.0, 9.2, -12.0, -4.0)
	D.bloc(K, X0, X1, -5.0, 9.2, -12.0, -11.8)
	K.plan("brut", X0, X1, -12.0, -4.0, 9.2, false)
	# Le sol de la cage au sous-sol.
	K.dalle(X0, X1, -12.0, -4.0, -5.0)
	# La face sud, entre les cloisons des niveaux : au-dessus de l'épine, au-dessus du couloir de service.
	D.bloc(K, X0, X1, -1.6, -0.3, -4.0, -3.8)
	D.bloc(K, X0, X1, 3.4, 5.4, -4.0, -3.8)

	# --- les paliers ---
	K.plan("lino", XI0, XI1, ZS, -4.0, -4.999)
	D.bloc(K, X0, X1, -0.3, 0.0, ZS, -4.0)
	K.plan("lino", XI0, XI1, ZS, -4.0, 0.001)
	D.bloc(K, X0, X1, 5.4, 6.0, ZS, -4.0)
	K.plan("lino", XI0, XI1, ZS, -4.0, 6.001)

	# --- volées 1 et 2 : du sous-sol au rez-de-chaussée ---
	D.bloc(K, XI0, XI1, -5.0, -2.5, -11.8, ZN)
	_volee(K, D, XW, ZS, ZN, -5.0, -2.5, -5.0, XI0 + 0.06)
	_volee(K, D, XE, ZN, ZS, -2.5, 0.0, -5.0, XI1 - 0.06)
	# Le massif sous la volée 2, solide pour qui longe le palier du sous-sol.
	K.solide(XI1 - 38.1, 2.4, ZS - ZN, (38.1 + XI1) / 2.0, -3.8, (ZN + ZS) / 2.0)
	# Le mur d'échiffre, garde-corps de la volée 4 en tête.
	D.bloc(K, 37.9, 38.1, -5.0, 7.05, ZN, ZS)

	# --- volées 3 et 4 : du rez-de-chaussée à la mezzanine ---
	D.bloc(K, XI0, 37.9, -0.1, 0.1, -11.8, ZS)
	D.bloc(K, XI0, 37.9, 0.1, 3.0, -11.8, ZN)
	D.bloc(K, 38.1, XI1, 2.88, 3.0, -11.8, ZN)
	K.plan("brut", 38.0, XI1, -11.8, ZN, 3.002)
	_volee(K, D, XW, ZS, ZN, 0.0, 3.0, 0.0, XI0 + 0.06)
	_volee(K, D, XE, ZN, ZS, 3.0, 6.0, 3.0, XI1 - 0.06)
	D.bloc(K, 38.1, XI1, 2.9, 3.0, ZN, ZS)
	# Le garde-corps du palier de la mezzanine, au-dessus de la volée 3.
	for h in [0.35, 0.7, 1.05]:
		K.beam("acier", Vector3(XI0, 6.0 + h, ZS - 0.05), Vector3(37.9, 6.0 + h, ZS - 0.05), 0.04, 0.04)
	for x in [XI0 + 0.05, 37.05, 37.85]:
		K.box("acier", 0.04, 1.05, 0.04, x, 6.525, ZS - 0.05)
	K.segment(XI0, ZS - 0.05, 37.9, ZS - 0.05, 0.08, 6.0, 1.1)

	# --- signalétique, lumière ---
	D.pochoir(K, "B1", 39.79, -3.1, -4.85, -PI / 2.0, 0.55)
	D.pochoir(K, "ESCALIER", 36.21, -2.7, -4.85, PI / 2.0, 0.22)
	D.pochoir(K, "RDC", 39.79, 1.9, -4.85, -PI / 2.0, 0.5)
	D.pochoir(K, "RDC", 38.85, -0.75, -11.79, 0.0, 0.3)
	D.pochoir(K, "MEZZANINE", 39.79, 7.9, -4.85, -PI / 2.0, 0.3)
	D.pochoir(K, "B1", 37.2, 2.2, -4.22, PI, 0.3)
	D.sortie(K, 38.0, -2.45, -4.22, PI)
	D.sortie(K, 38.0, 8.5, -4.22, PI)
	D.plaque(K, "coupe", 38.0, 7.75, -4.22, PI, 0.5)
	D.neon(K, 38.0, -4.85, "x", 1.2, -1.67)
	D.neon(K, 38.0, -4.85, "x", 1.2, 5.33)
	D.neon(K, 37.05, -11.15, "x", 1.0, -0.17)
	D.neon(K, 38.0, -11.15, "x", 1.4, 9.13)
	D.reseaux(K, "z", 39.68, -11.6, -4.3, 9.0)
	D.dome(K, 36.5, 9.2, -11.5)
	K.lumiere(38.0, -1.0, -8.0, Color("#cfe4ff"), 1.2, 9.0)
	K.lumiere(38.0, 5.0, -8.0, Color("#cfe4ff"), 1.2, 10.0)
	K.zone_fin()
