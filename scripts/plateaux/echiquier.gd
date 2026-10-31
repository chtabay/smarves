extends Control
## L'échiquier à l'écran, à la manière de chess.com : cases crème et vert, coordonnées dans les coins,
## le dernier coup surligné en jaune, les coups permis en pastilles, le roi en échec sur fond rouge.
## Un peu de relief : un cadre de bois biseauté, une ombre sous chaque pièce et un liseré qui l'arrondit.
## On joue au clic (la pièce, puis sa case) ou en glissant la pièce ; la promotion se choisit sur la case.
##
## Le plateau est celui du serveur (smarves-plateaux.js, regence.js d'Addict) : 64 caractères, a1 en 0,
## h1 en 7, a8 en 56 ; blancs en majuscules, noirs en minuscules, « . » pour une case vide. Les coups
## permis viennent du serveur (« e2e4 », « e7e8q ») : l'échiquier ne connaît pas les règles.

## Le joueur a choisi un coup permis (« e2e4 », « e7e8q »).
signal coup(uci: String)

const CLAIR := Color("#ebecd0")
const FONCE := Color("#739552")
const SURLIGNE_CLAIR := Color("#f5f682")
const SURLIGNE_FONCE := Color("#b9ca43")
const ECHEC := Color(0.92, 0.2, 0.18)
const CADRE := Color(0.24, 0.15, 0.09)
const BLANC := Color(0.98, 0.97, 0.94)
const NOIR := Color(0.2, 0.19, 0.18)
const FILES := "abcdefgh"
## Les pièces pleines de DejaVu Sans (♚♛♜♝♞♟), pour les deux camps : la couleur fait le camp.
const GLYPHES := {"k": "♚", "q": "♛", "r": "♜", "b": "♝", "n": "♞", "p": "♟"}
const SYMBOLES: Font = preload("res://assets/polices/Symboles-DejaVuSans.ttf")

var plateau := ".".repeat(64)
## Les noirs en bas quand on les a.
var retourne := false
## Les coups permis au joueur, vides quand ce n'est pas à lui.
var legaux: PackedStringArray = []
## Le dernier coup joué, surligné (« e2e4 »).
var dernier := ""
var echec := false
var camp_au_trait := "blancs"

var _choisie := -1
var _glisse := -1
var _glisse_pos := Vector2.ZERO
## La promotion en attente : la case de départ et d'arrivée, et le camp.
var _promo := {}
var _survol := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(320, 320)
	resized.connect(queue_redraw)


## Pose une position : le plateau, les coups permis au joueur, le dernier coup et l'échec.
func poser(p: String, permis: Array, der := "", en_echec := false, au_trait := "blancs") -> void:
	if p.length() == 64:
		plateau = p
	legaux = PackedStringArray(permis)
	dernier = der
	echec = en_echec
	camp_au_trait = au_trait
	if _choisie >= 0 and _cibles(_choisie).is_empty():
		_choisie = -1
	if legaux.is_empty():
		_promo = {}
		_glisse = -1
	queue_redraw()


## La largeur d'une case, et le coin de l'échiquier (sans le cadre).
func _case() -> float:
	return (minf(size.x, size.y) - 2.0 * _marge()) / 8.0


func _marge() -> float:
	return clampf(minf(size.x, size.y) * 0.025, 6.0, 16.0)


func _origine() -> Vector2:
	var cote := _case() * 8.0
	return (size - Vector2(cote, cote)) / 2.0


## Le numéro (0 à 63) de la case affichée à la ligne `l` et la colonne `c` de l'écran.
func case_en(l: int, c: int) -> int:
	return (l * 8 + 7 - c) if retourne else ((7 - l) * 8 + c)


func _rect(s: int) -> Rect2:
	var f := s & 7
	var r := s >> 3
	var c := 7 - f if retourne else f
	var l := r if retourne else 7 - r
	var t := _case()
	return Rect2(_origine() + Vector2(c * t, l * t), Vector2(t, t))


func case_sous(p: Vector2) -> int:
	var q := (p - _origine()) / _case()
	if q.x < 0.0 or q.y < 0.0 or q.x >= 8.0 or q.y >= 8.0:
		return -1
	return case_en(int(q.y), int(q.x))


static func nom(s: int) -> String:
	return "%s%d" % [FILES[s & 7], (s >> 3) + 1]


static func numero(n: String) -> int:
	if n.length() < 2:
		return -1
	return FILES.find(n[0]) + (int(n[1]) - 1) * 8


## Les cases où la pièce de `s` peut aller.
func _cibles(s: int) -> Array:
	var out := []
	var de := nom(s)
	for m in legaux:
		if m.begins_with(de):
			var t := numero(m.substr(2, 2))
			if t not in out:
				out.append(t)
	return out


# --- Le dessin -------------------------------------------------------------------------------------

func _draw() -> void:
	var t := _case()
	var o := _origine()
	var cote := t * 8.0
	var m := _marge()
	# Le cadre : un bois sombre biseauté, clair en haut à gauche, sombre en bas à droite.
	var cadre := Rect2(o - Vector2(m, m), Vector2(cote + 2 * m, cote + 2 * m))
	draw_rect(Rect2(cadre.position + Vector2(3, 5), cadre.size), Color(0, 0, 0, 0.35))
	draw_rect(cadre, CADRE)
	draw_rect(Rect2(cadre.position, Vector2(cadre.size.x, m * 0.4)), CADRE.lightened(0.25))
	draw_rect(Rect2(cadre.position, Vector2(m * 0.4, cadre.size.y)), CADRE.lightened(0.18))
	draw_rect(Rect2(cadre.position + Vector2(0, cadre.size.y - m * 0.4), Vector2(cadre.size.x, m * 0.4)), CADRE.darkened(0.35))
	draw_rect(Rect2(cadre.position + Vector2(cadre.size.x - m * 0.4, 0), Vector2(m * 0.4, cadre.size.y)), CADRE.darkened(0.3))
	var der_de := numero(dernier.substr(0, 2)) if dernier.length() >= 4 else -1
	var der_a := numero(dernier.substr(2, 2)) if dernier.length() >= 4 else -1
	var roi := -1
	if echec:
		roi = plateau.find("K" if camp_au_trait == "blancs" else "k")
	for s in 64:
		var r := _rect(s)
		var clair := ((s & 7) + (s >> 3)) % 2 == 1
		var col := CLAIR if clair else FONCE
		if s == der_de or s == der_a or s == _choisie:
			col = SURLIGNE_CLAIR if clair else SURLIGNE_FONCE
		draw_rect(r, col)
		if s == roi:
			# Le roi en échec : une lueur rouge qui part du centre de la case.
			for k in 6:
				var a := 0.55 * (1.0 - k / 6.0)
				draw_circle(r.get_center(), t * (0.12 + 0.07 * k), Color(ECHEC, a * 0.5))
	# Un fin reflet sur tout l'échiquier, comme un plateau verni.
	draw_rect(Rect2(o, Vector2(cote, cote * 0.5)), Color(1, 1, 1, 0.035))
	_coordonnees(o, t)
	# Les coups permis depuis la pièce choisie (ou qu'on glisse).
	var depuis := _glisse if _glisse >= 0 else _choisie
	if depuis >= 0:
		for c in _cibles(depuis):
			var r := _rect(c)
			if plateau[c] != ".":
				draw_arc(r.get_center(), t * 0.44, 0, TAU, 40, Color(0, 0, 0, 0.16), t * 0.09, true)
			else:
				draw_circle(r.get_center(), t * 0.16, Color(0, 0, 0, 0.16))
		if _survol >= 0 and _survol in _cibles(depuis):
			draw_rect(_rect(_survol), Color(1, 1, 1, 0.22), false, maxf(2.0, t * 0.05))
	for s in 64:
		var p := plateau[s]
		if p == "." or s == _glisse:
			continue
		_piece(p, _rect(s).get_center(), t)
	if _glisse >= 0:
		_piece(plateau[_glisse], _glisse_pos, t * 1.08)
	if not _promo.is_empty():
		_choix_promotion(t)


func _coordonnees(o: Vector2, t: float) -> void:
	var f := get_theme_default_font()
	var fs := int(clampf(t * 0.2, 10, 18))
	for i in 8:
		# Les lettres en bas, les chiffres à gauche, dans la couleur de l'autre case.
		var col_s := case_en(7, i)
		var lig_s := case_en(i, 0)
		var clair_c := ((col_s & 7) + (col_s >> 3)) % 2 == 1
		var clair_l := ((lig_s & 7) + (lig_s >> 3)) % 2 == 1
		draw_string(f, o + Vector2((i + 1) * t - fs * 0.75, 8 * t - fs * 0.3), FILES[col_s & 7], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FONCE if clair_c else CLAIR)
		draw_string(f, o + Vector2(fs * 0.25, i * t + fs * 1.05), str((lig_s >> 3) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FONCE if clair_l else CLAIR)


## Une pièce centrée en `c` : son ombre, un liseré sombre pour le relief, puis le corps.
func _piece(p: String, c: Vector2, t: float) -> void:
	var blanc := p == p.to_upper()
	var g: String = GLYPHES[p.to_lower()]
	var fs := int(t * 0.86)
	var w := SYMBOLES.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := c + Vector2(-w / 2.0, fs * 0.36)
	var contour := maxi(2, int(t * 0.06))
	draw_string(SYMBOLES, base + Vector2(t * 0.03, t * 0.05), g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.28))
	draw_string_outline(SYMBOLES, base, g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, contour, Color(0.12, 0.1, 0.09) if blanc else Color(0.02, 0.02, 0.02))
	draw_string(SYMBOLES, base, g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, BLANC if blanc else NOIR)
	# Le reflet : la même pièce, un peu plus petite, plus claire, décalée vers le haut.
	var fs2 := int(fs * 0.9)
	var w2 := SYMBOLES.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	draw_string(SYMBOLES, c + Vector2(-w2 / 2.0, fs2 * 0.36 - t * 0.02), g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1, 1, 1, 0.16) if blanc else Color(1, 1, 1, 0.07))


## Les quatre pièces de promotion, en colonne sur la case d'arrivée, vers le centre de l'échiquier.
func _choix_promotion(t: float) -> void:
	var r := _rect(_promo.a)
	var vers := 1.0 if r.position.y < _origine().y + t * 4.0 else -1.0
	var blanc: bool = _promo.blanc
	for i in 4:
		var rr := Rect2(r.position + Vector2(0, vers * i * t), r.size)
		draw_rect(rr, Color(1, 1, 1, 0.96))
		draw_rect(rr, Color(0, 0, 0, 0.2), false, 1.0)
		var p: String = ["q", "n", "r", "b"][i]
		_piece(p.to_upper() if blanc else p, rr.get_center(), t * 0.9)


func _promotion_sous(p: Vector2) -> String:
	var t := _case()
	var r := _rect(_promo.a)
	var vers := 1.0 if r.position.y < _origine().y + t * 4.0 else -1.0
	for i in 4:
		if Rect2(r.position + Vector2(0, vers * i * t), r.size).has_point(p):
			return ["q", "n", "r", "b"][i]
	return ""


# --- Pour le pilote d'un pensionnaire (scripts/socle/pilote.gd) -------------------------------------

## Les cases à l'écran, par leur nom (« e2 ») ; pendant une promotion, les quatre pièces au choix
## (« promotion-dame », …).
func pilote_cases() -> Dictionary:
	var out := {}
	if not _promo.is_empty():
		var t := _case()
		var r := _rect(_promo.a)
		var vers := 1.0 if r.position.y < _origine().y + t * 4.0 else -1.0
		for i in 4:
			out["promotion-%s" % ["dame", "cavalier", "tour", "fou"][i]] = Rect2(r.position + Vector2(0, vers * i * t), r.size)
		return out
	for s in 64:
		out[nom(s)] = _rect(s)
	return out


const NOMS_PIECES := {"k": "R", "q": "D", "r": "T", "b": "F", "n": "C", "p": ""}

## La position en mots, comme la verrait un joueur : où sont les pièces, qui a le trait, ce qu'on peut
## jouer et comment.
func pilote_texte() -> String:
	var blancs := []
	var noirs := []
	for s in 64:
		var p := plateau[s]
		if p == ".":
			continue
		var n := "%s%s" % [NOMS_PIECES.get(p.to_lower(), "?"), nom(s)]
		if p == p.to_upper():
			blancs.append(n)
		else:
			noirs.append(n)
	var l := ["Échiquier (R roi, D dame, T tour, F fou, C cavalier, sans lettre un pion) — tu joues les %s, en bas." % ("noirs" if retourne else "blancs")]
	l.append("Blancs : %s." % ", ".join(blancs))
	l.append("Noirs : %s." % ", ".join(noirs))
	var au_trait := "Au trait : les %s%s." % [camp_au_trait, ", en échec" if echec else ""]
	if dernier != "":
		au_trait += " Dernier coup : %s-%s." % [dernier.substr(0, 2), dernier.substr(2, 2)]
	l.append(au_trait)
	if not _promo.is_empty():
		l.append("Promotion : clique la pièce choisie (c:promotion-dame, c:promotion-cavalier, c:promotion-tour, c:promotion-fou).")
	elif not legaux.is_empty():
		var coups := []
		for m in legaux:
			coups.append("%s-%s%s" % [m.substr(0, 2), m.substr(2, 2), m.substr(4)])
		l.append("À toi de jouer, en un seul geste : cliquer le coup, « e2-e4 » (une promotion : « e7-e8=D », D, T, F ou C). Coups permis : %s." % ", ".join(coups))
		if _choisie >= 0:
			l.append("Pièce choisie : %s." % nom(_choisie))
	return "\n".join(l)


## Un coup en un seul geste, pour le pilote d'un pensionnaire : « e2-e4 », « e2e4 », « e7-e8=D » (D, T,
## F, C ou Q, R, B, N ; la dame si la promotion ne dit pas sa pièce). Rend null si le texte n'est pas un
## coup (le pilote le cherche alors ailleurs), sinon {ok, dit} : le coup part comme un clic de joueur.
func pilote_coup(texte: String) -> Variant:
	var re := RegEx.create_from_string("^\\s*(?:c:)?([a-h][1-8])\\s*[-x–—]?\\s*(?:c:)?([a-h][1-8])\\s*(?:=?\\s*([dtfcqrbn]))?\\s*$")
	var m := re.search(texte.strip_edges().to_lower())
	if m == null:
		return null
	if legaux.is_empty():
		return {"ok": false, "dit": "ce n'est pas à toi de jouer"}
	var de := m.get_string(1)
	var a := m.get_string(2)
	var promo: String = {"d": "q", "t": "r", "f": "b", "c": "n"}.get(m.get_string(3), m.get_string(3))
	if (de + a + "q") in legaux and promo == "":
		promo = "q"
	var uci := de + a + promo
	if uci not in legaux:
		return {"ok": false, "dit": "coup non permis : %s-%s" % [de, a]}
	_promo = {}
	_jouer(numero(de), numero(a), promo)
	return {"ok": true, "dit": "joué %s-%s%s" % [de, a, ("=" + NOMS_PIECES[promo]) if promo != "" else ""]}


# --- Le jeu à la souris et au doigt ----------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_survol = case_sous(e.position)
		if _glisse >= 0:
			_glisse_pos = e.position
		queue_redraw()
		return
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var s := case_sous(e.position)
	if not _promo.is_empty():
		if e.pressed:
			var choix := _promotion_sous(e.position)
			var de: int = _promo.de
			var a: int = _promo.a
			_promo = {}
			_choisie = -1
			if choix != "":
				_jouer(de, a, choix)
			queue_redraw()
		accept_event()
		return
	if e.pressed:
		if _choisie >= 0 and s in _cibles(_choisie):
			_essayer(_choisie, s)
		elif s >= 0 and not _cibles(s).is_empty():
			_choisie = s
			_glisse = s
			_glisse_pos = e.position
		else:
			_choisie = -1
	else:
		if _glisse >= 0:
			var de := _glisse
			_glisse = -1
			if s >= 0 and s != de and s in _cibles(de):
				_essayer(de, s)
	queue_redraw()
	accept_event()


## Un coup vers une case permise : la promotion demande d'abord la pièce.
func _essayer(de: int, a: int) -> void:
	var promo := "%s%sq" % [nom(de), nom(a)]
	if promo in legaux:
		_promo = {"de": de, "a": a, "blanc": plateau[de] == "P"}
		return
	_jouer(de, a, "")


func _jouer(de: int, a: int, promo: String) -> void:
	var uci := nom(de) + nom(a) + promo
	_choisie = -1
	if uci not in legaux:
		return
	# Le coup s'affiche tout de suite ; le serveur confirme (ou corrige) à sa réponse.
	plateau = appliquer(plateau, uci)
	dernier = uci
	legaux = PackedStringArray()
	echec = false
	queue_redraw()
	coup.emit(uci)


## Joue un coup sur un plateau, sans vérifier les règles : le roque déplace sa tour, la prise en passant
## retire le pion, la promotion pose la pièce choisie.
static func appliquer(b: String, uci: String) -> String:
	var de := numero(uci.substr(0, 2))
	var a := numero(uci.substr(2, 2))
	if de < 0 or a < 0:
		return b
	var p := b[de]
	var out := b
	if p.to_lower() == "p" and (de & 7) != (a & 7) and b[a] == ".":
		out[a + (-8 if p == "P" else 8)] = "."
	if p.to_lower() == "k" and absi(a - de) == 2:
		var rf := de + 3 if a > de else de - 4
		var rt := de + 1 if a > de else de - 1
		out[rt] = out[rf]
		out[rf] = "."
	out[a] = p
	out[de] = "."
	if uci.length() == 5:
		out[a] = uci[4].to_upper() if p == "P" else uci[4]
	return out
