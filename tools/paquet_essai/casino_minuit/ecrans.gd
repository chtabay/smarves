extends RefCounted
## Les écrans que l'original redessine en direct, sur le décor exporté (decor.gd). Leurs pièces viennent
## du code de dessin de l'original lui-même (decor/ecrans/, tools/minuit_decor/exporter_ecrans.mjs) : on
## les recompose ici au rythme de l'original. Les textures du .glb sont retournées (le glTF les range tête
## en bas) : les images refaites le sont aussi.

const BASE := "res://communes/casino_minuit/"
const ECRANS := BASE + "decor/ecrans/"
## La texture du décor qui porte l'afficheur du jackpot (son nombre au moment de l'export).
const TEX_JACKPOT := "7cc4363233162793.png"
## Celle du mur des tournois du poker (son état de départ).
const TEX_POKER := "208030ace7240af4.png"
## Celles des deux écrans du mur des paris (leur image à l'instant 0).
const TEX_PARIS := {"A": "0dc3b62b4657f012.png", "B": "7f35b7f588180eff.png"}

var scene: Node3D
var K
var _hasard := RandomNumberGenerator.new()

# b-machines.js l. 72-80 : la cagnotte part de 1 284 560 et gagne 137 à 736 chaque seconde.
var _jack: Dictionary
var _jack_fond: Image
var _jack_gly: Image
var _jack_tex: ImageTexture
var _pot := 0
var _pot_t := 0.0

# b-poker.js l. 25-38 : toutes les 2 s le statut des inscriptions ouvertes clignote ; à chaque allumage,
# l'une des deux lignes gagne un joueur (jusqu'à 160).
var _pk: Dictionary
var _pk_fond: Image
var _pk_nombres: Image
var _pk_statuts: Image
var _pk_tex: ImageTexture
var _joueurs := {}
var _allume := false
var _pk_t := 0.0

# c-sports.js l. 87 : les deux écrans sont redessinés à tour de rôle, un tous les quarts de seconde.
var _paris := {}
var _paris_acc := 1.0
var _paris_phase := 0


func _init(s: Node3D, kit) -> void:
	scene = s
	K = kit


func charger() -> void:
	_hasard.randomize()
	var mats := _matieres([TEX_JACKPOT, TEX_POKER] + TEX_PARIS.values())
	if not mats[TEX_JACKPOT].is_empty():
		_jack = JSON.parse_string(FileAccess.get_file_as_string(ECRANS + "jackpot.json"))
		_jack_fond = _image("jackpot_fond")
		_jack_gly = _image("jackpot_glyphes")
		_pot = int(_jack.depart)
		_jack_tex = ImageTexture.create_from_image(_jackpot(_pot))
		for m in mats[TEX_JACKPOT]:
			(m as BaseMaterial3D).albedo_texture = _jack_tex
	if not mats[TEX_POKER].is_empty():
		_charger_poker()
		_pk_tex = ImageTexture.create_from_image(_poker(_joueurs, _allume))
		for m in mats[TEX_POKER]:
			(m as BaseMaterial3D).albedo_texture = _pk_tex
	for e in TEX_PARIS:
		if mats[TEX_PARIS[e]].is_empty():
			continue
		var vp := SubViewport.new()
		vp.size = Vector2i(1024, 256)
		vp.disable_3d = true
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var dessin: Control = load(BASE + "ecrans_paris.gd").new()
		dessin.ecran = e
		dessin.size = Vector2(1024, 256)
		vp.add_child(dessin)
		scene.add_child(vp)
		_paris[e] = [vp, dessin]
		for m in mats[TEX_PARIS[e]]:
			var b := m as BaseMaterial3D
			b.albedo_texture = vp.get_texture()
			# L'image du .glb était retournée, celle de l'écran ne l'est pas : la matière retourne ses UV.
			b.uv1_offset.y = 1.0 - b.uv1_offset.y
			b.uv1_scale.y = -b.uv1_scale.y
	K.chaque_image(animer)


func _charger_poker() -> void:
	_pk = JSON.parse_string(FileAccess.get_file_as_string(ECRANS + "poker.json"))
	_pk_fond = _image("poker_depart")
	_pk_nombres = _image("poker_nombres")
	_pk_statuts = _image("poker_statuts")
	for i in _pk.lignes:
		_joueurs[int(i)] = int(_pk.lignes[i].de)


func animer(dt: float, t: float) -> void:
	if not _paris.is_empty():
		_paris_acc += dt
		if _paris_acc >= 0.25:
			_paris_acc = 0.0
			_paris_phase ^= 1
			var e := "A" if _paris_phase else "B"
			if _paris.has(e):
				_paris[e][1].t = t
				_paris[e][1].queue_redraw()
				_paris[e][0].render_target_update_mode = SubViewport.UPDATE_ONCE
	if _jack_tex:
		_pot_t += dt
		if _pot_t > 1.0:
			_pot_t = 0.0
			_pot += 137 + _hasard.randi_range(0, 599)
			_jack_tex.update(_jackpot(_pot))
	if _pk_tex:
		_pk_t += dt
		if _pk_t > 2.0:
			_pk_t = 0.0
			_allume = not _allume
			if _allume:
				var i := 3 if _hasard.randf() < 0.5 else 4
				if _joueurs[i] < 160:
					_joueurs[i] += 1
			_pk_tex.update(_poker(_joueurs, _allume))


## Les matières du décor dont la texture est l'une de `noms` (fichiers de decor/tex/), par nom.
func _matieres(noms: Array) -> Dictionary:
	var r := {}
	for n in noms:
		r[n] = []
	for d in scene.find_children("Decor_*", "Node3D", true, false):
		for mi in d.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = (mi as MeshInstance3D).mesh
			for i in m.get_surface_count():
				var mat := m.surface_get_material(i) as BaseMaterial3D
				if mat == null or mat.albedo_texture == null:
					continue
				var f := mat.albedo_texture.resource_path.get_file()
				if r.has(f) and not r[f].has(mat):
					r[f].append(mat)
	return r


func _image(nom: String) -> Image:
	var im := (load(ECRANS + nom + ".png") as Texture2D).get_image()
	im.decompress()
	im.clear_mipmaps()
	im.convert(Image.FORMAT_RGBA8)
	return im


## L'afficheur avec la cagnotte `n` : chaque chiffre posé avec sa lueur là où le moteur web l'écrirait
## (texte centré, chasses et crénages de la police, quart de pixel le plus proche).
func _jackpot(n: int) -> Image:
	var s := _milliers(n)
	var chasse: Dictionary = _jack.chasse
	var crenage: Dictionary = _jack.crenage
	var tot := 0.0
	for k in s.length():
		tot += chasse[s[k]] + (crenage[s.substr(k, 2)] if k + 1 < s.length() else 0.0)
	var sl := int(_jack.case[0])
	var hh := int(_jack.case[1])
	var ph := int(_jack.phases)
	var yb := int(_jack.y_bande)
	var x: float = _jack.x_centre - tot / 2.0
	var im := _jack_fond.duplicate() as Image
	for k in s.length():
		var xi := int(floorf(x))
		var p := int(roundf((x - xi) * ph))
		if p == ph:
			xi += 1
			p = 0
		var ci := (_jack.caracteres as String).find(s[k])
		im.blend_rect(_jack_gly, Rect2i(ci * sl, p * hh, sl, hh), Vector2i(xi - int(_jack.marge), yb))
		x += chasse[s[k]] + (crenage[s.substr(k, 2)] if k + 1 < s.length() else 0.0)
	im.flip_y()
	im.generate_mipmaps()
	return im


## Le mur des tournois : le nombre de joueurs de chaque ligne qui change et le statut qui clignote, posés
## sur le tableau de départ (des découpes que l'original a dessinées).
func _poker(joueurs: Dictionary, allume: bool) -> Image:
	var im := _pk_fond.duplicate() as Image
	var nw := int(_pk.cellule[0])
	var ch := int(_pk.cellule[1])
	var sw := int(_pk.statut_taille[0])
	for i in joueurs:
		var l: Dictionary = _pk.lignes[str(i)]
		var k: int = int(l.premiere) + int(joueurs[i]) - int(l.de)
		im.blit_rect(_pk_nombres, Rect2i(0, k * ch, nw, ch), Vector2i(int(_pk.x_nombre), int(l.y)))
		var st: Dictionary = _pk.statut[str(i)]
		im.blit_rect(_pk_statuts, Rect2i(0, int(st.allume if allume else st.eteint) * ch, sw, ch), Vector2i(int(_pk.x_statut), int(st.y)))
	im.flip_y()
	im.generate_mipmaps()
	return im


## 1284560 → « 1 284 560 », comme String(pot).replace(/\B(?=(\d{3})+(?!\d))/g, ' ').
static func _milliers(n: int) -> String:
	var s := str(n)
	var r := ""
	for i in s.length():
		r += s[i]
		var reste := s.length() - 1 - i
		if reste > 0 and reste % 3 == 0:
			r += " "
	return r
