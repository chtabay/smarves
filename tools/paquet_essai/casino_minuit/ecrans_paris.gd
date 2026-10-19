extends Control
## Un des deux écrans du mur des paris (c-sports.js l. 13-52, drawA et drawB), redessiné ligne pour ligne
## avec les polices de l'original (decor/polices/) : « A », trois rencontres en direct ; « B », le keno et
## les cotes. Le contenu ne dépend que de l'instant t, comme dans l'original.

const POLICES := "res://communes/casino_minuit/decor/polices/"
const MILIEU := "res://communes/casino_minuit/decor/ecrans/paris.json"
const W := 1024.0
const H := 256.0
const MATCHS := [["FOOTBALL · LIGUE DES NUITS", "PARIS", "LYON", "#0D5C3F"], ["BASKET · FINALE OUEST", "VEGAS", "RENO", "#8A4A1C"],
	["BOXE · POIDS MOYENS", "MOREAU", "DIAZ", "#24306A"]]
const COTES := [["Paris – Lyon", 1.85, 3.4, 4.2], ["Marseille – Lille", 2.1, 3.2, 3.55], ["Vegas – Reno", 1.45, 0, 2.7],
	["Moreau – Diaz", 1.6, 12, 2.3], ["Nice – Nantes", 2.45, 3.1, 2.95], ["Prix de Minuit · Éclair", 4.5, 0, 0]]

var ecran := "A"
var t := 0.0
static var _polices := {}
## Où l'original pose la ligne de base sous le milieu du texte, par police et taille (decor/ecrans/paris.json).
static var _milieu := {}
# L'état du pinceau, comme celui d'un canvas 2D : police, taille, alignement.
var _police: Font
var _nom := ""
var _taille := 12
var _align := "left"


static func police(nom: String) -> Font:
	if not _polices.has(nom):
		var f: FontFile = load(POLICES + nom + ".woff2")
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
		_polices[nom] = f
	return _polices[nom]


func _draw() -> void:
	if ecran == "A":
		_dessin_a()
	else:
		_dessin_b()


func _font(nom: String, taille: int) -> void:
	_police = police(nom)
	_nom = nom
	_taille = taille


## fillText avec textBaseline « middle » : la ligne de base là où le moteur web la met.
func _texte(s: String, x: float, y: float, c: Color) -> void:
	var l := _police.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, _taille).x
	if _align == "center":
		x -= l / 2.0
	elif _align == "right":
		x -= l
	if _milieu.is_empty():
		_milieu = JSON.parse_string(FileAccess.get_file_as_string(MILIEU)).milieu
	# Le moteur web arrondit la ligne de base au pixel le plus proche.
	var base := roundf(y - float(_milieu["%s|%d" % [_nom, _taille]]))
	draw_string(_police, Vector2(x, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, _taille, c)


func _rond(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col, true, -1.0, true)


## strokeRect d'un ligne de 2 px, centré sur le bord.
func _cadre(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(x, y, w, h), col, false, 2.0, true)


static func fr(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")


# --- Écran A : trois rencontres en aplats animés --------------------------------------------------
func _dessin_a() -> void:
	var pw := W / 3.0
	draw_rect(Rect2(0, 0, W, H), Color("#060A18"))
	var ligne := Color(243 / 255.0, 234 / 255.0, 215 / 255.0, 0.75)
	for k in 3:
		var m: Array = MATCHS[k]
		var x0 := k * pw + 6.0
		var w := pw - 12.0
		var tt := t + k * 17.0
		var mn := int(floorf(tt / 2.2)) % 90
		var sa := int(floorf(tt / 41.0)) % 4 + (61 if k == 1 else 0)
		var sb := int(floorf(tt / 67.0)) % 3 + (58 if k == 1 else 0)
		draw_rect(Rect2(x0, 6, w, H - 12), Color("#0E1530"))
		draw_rect(Rect2(x0, 6, w, 30), Color("#131A3A"))
		_font("barlow-700", 15)
		_align = "left"
		_texte(m[0], x0 + 10, 22, Color("#F2CF7A"))
		if int(floorf(t * 2.0)) % 2:
			_rond(Vector2(x0 + w - 78, 21), 5, Color("#FF3348"))
		_font("barlow-600", 12)
		_texte("EN DIRECT", x0 + w - 68, 22, Color("#F3EAD7"))
		# le terrain
		var fx := x0 + 14
		var fy := 44.0
		var fw := w - 28
		var fh := 116.0
		draw_rect(Rect2(fx, fy, fw, fh), Color(m[3]))
		_cadre(fx + 4, fy + 4, fw - 8, fh - 8, ligne)
		if k < 2:
			draw_line(Vector2(fx + fw / 2, fy + 4), Vector2(fx + fw / 2, fy + fh - 4), ligne, 2.0, true)
			draw_arc(Vector2(fx + fw / 2, fy + fh / 2), 20, 0, TAU, 64, ligne, 2.0, true)
			_cadre(fx + 4, fy + fh / 2 - 26, 30, 52, ligne)
			_cadre(fx + fw - 34, fy + fh / 2 - 26, 30, 52, ligne)
		else:
			_cadre(fx + fw * 0.22, fy + 14, fw * 0.56, fh - 28, ligne)
			_cadre(fx + fw * 0.25, fy + 20, fw * 0.5, fh - 40, ligne)
		for i in (2 if k == 2 else 10):
			var s := 0 if i < (1 if k == 2 else 5) else 1
			var a := tt * (0.5 + i * 0.07) + i * 2.1
			var px := fx + fw * ((0.5 + (0.07 if s else -0.07) + sin(a) * 0.04) if k == 2 else (0.5 + 0.4 * sin(a * 0.6 + i)))
			var py := fy + fh * (0.5 + 0.36 * sin(a * 0.83 + i * 1.3) * (0.3 if k == 2 else 1.0))
			_rond(Vector2(px, py), 9 if k == 2 else 5, Color("#FF5466") if s else Color("#F3EAD7"))
		if k < 2:
			_rond(Vector2(fx + fw * (0.5 + 0.42 * sin(tt * 0.9)), fy + fh * (0.5 + 0.34 * sin(tt * 1.37))), 3.5, Color("#FFC24A"))
		# le tableau de marque
		_font("barlow-700", 22)
		_align = "left"
		_texte(m[1], x0 + 14, 186, Color("#F3EAD7"))
		_align = "right"
		_texte(m[2], x0 + w - 14, 186, Color("#F3EAD7"))
		_font("limelight", 34)
		_align = "center"
		var reprise := 1 + int(floorf(tt / 30.0)) % 12
		_texte("R%d" % reprise if k == 2 else "%d – %d" % [sa, sb], x0 + w / 2, 190, Color("#4DFF9A"))
		_font("barlow-600", 14)
		var cote: float = COTES[0 if k == 0 else (2 if k == 1 else 3)][1] + 0.05 * sin(tt * 0.2)
		var bas := "Reprise %d / 12" % reprise if k == 2 else ("MI-TEMPS" if mn == 45 else "%d′" % mn) + "  ·  Cote " + fr(cote)
		_texte(bas, x0 + w / 2, 226, Color("#CFE4FF"))
		draw_rect(Rect2(x0 + 14, 240, (w - 28) * (fmod(tt, 20.0) / 20.0), 3), Color("#4DFF9A"))


# --- Écran B : le keno (80 cases, 20 numéros tirés un à un) et le tableau des cotes ----------------
func _dessin_b() -> void:
	var tir := int(floorf(t / 40.0))
	var n := mini(20, int(floorf(fmod(t, 40.0) / 1.4)))
	var rnd := Seme.new(tir * 31 + 5)
	var pick: Array[int] = []
	while pick.size() < 20:
		var v := 1 + int(floorf(rnd.suivant() * 80.0))
		if not pick.has(v):
			pick.append(v)
	draw_rect(Rect2(0, 0, W, H), Color("#060A18"))
	draw_rect(Rect2(6, 6, 470, H - 12), Color("#0E1530"))
	draw_rect(Rect2(484, 6, W - 490, H - 12), Color("#0E1530"))
	_font("limelight", 26)
	_align = "left"
	_texte("KENO", 20, 26, Color("#F2CF7A"))
	_font("barlow-600", 14)
	_texte("Tirage n° %d   ·   %d / 20" % [4120 + tir, n], 120, 27, Color("#F3EAD7"))
	for i in 80:
		var cx := 18.0 + (i % 10) * 45
		var cy := 46.0 + (i / 10) * 25
		var k := pick.find(i + 1)
		var on := k >= 0 and k < n
		var last := on and k == n - 1
		draw_rect(Rect2(cx, cy, 41, 21), (Color("#FFFFFF") if last else Color("#FFB347")) if on else Color("#131A3A"))
		_font("barlow-700", 14)
		_align = "center"
		_texte(str(i + 1), cx + 20.5, cy + 11.5, Color("#17141A") if on else Color("#8FA0C8"))
	_align = "left"
	_font("limelight", 26)
	_texte("COTES EN DIRECT", 498, 26, Color("#4DFF9A"))
	_font("barlow-700", 13)
	for i in 3:
		_align = "center"
		_texte(["1", "N", "2"][i], 820 + i * 70, 28, Color("#8FA0C8"))
	var sh := int(floorf(t / 5.0))
	for j in COTES.size():
		var r: Array = COTES[j]
		var y := 58.0 + j * 31
		var up := (sh + j) % 3
		draw_rect(Rect2(492, y - 13, W - 506, 27), Color("#101838") if j % 2 else Color("#131A3A"))
		_align = "left"
		_font("barlow-600", 17)
		_texte(r[0], 502, y + 1, Color("#F3EAD7"))
		for i in 3:
			var v: float = r[1 + i]
			_align = "center"
			# Le tiret garde la police du moment : celle du nom, ou celle de la cote écrite juste avant.
			if v == 0:
				_texte("—", 820 + i * 70, y + 1, Color("#56608A"))
				continue
			var d := 0.05 * sin(sh * 1.7 + j * 2 + i)
			_font("barlow-700", 18)
			_texte(fr(v + d), 820 + i * 70, y + 1, Color("#4DFF9A") if i == up else (Color("#FF5466") if d < -0.02 else Color("#F2CF7A")))
	draw_rect(Rect2(492, 240, (W - 506) * (fmod(t, 5.0) / 5.0), 3), Color("#FF3348"))


## Le générateur à graine du kit de l'original (kit.js, seeded : mulberry32), en entiers de 32 bits.
class Seme:
	var a: int

	func _init(s: int) -> void:
		a = (s + 0x6D2B79F5) & 0xFFFFFFFF

	static func _imul(x: int, y: int) -> int:
		return (x * y) & 0xFFFFFFFF

	func suivant() -> float:
		a = _imul(a ^ (a >> 15), a | 1)
		a = (a ^ ((a + _imul(a ^ (a >> 7), a | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
		return float((a ^ (a >> 14)) & 0xFFFFFFFF) / 4294967296.0
