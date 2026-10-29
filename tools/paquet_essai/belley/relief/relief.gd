extends RefCounted
## Le relief réel de Belley, en mètres : x vers l'est, z vers le sud, depuis la place de la Victoire ;
## y = altitude − ALT0. Trois grilles, de la plus fine à la plus large, chacune lue là où elle couvre :
##   le bourg (bourg.json de bourg_reel.py, 2,08 m au pas, 800 m autour du centre),
##   le relief proche (relief.png de relief_lointain.py, 15 m, 9,6 × 5 km : la ville, le canal, Parves, le Rhône),
##   la crête du Mont du Chat (crete.png, 25 m, de la Charvaz au col du Chat : ses barres, la Dent),
##   l'horizon (lointain.png, 75 m, 36 km de côté : le Colombier, le Mont du Chat, le Mont Pela).
## Les cartes PNG portent l'altitude sur 16 bits, l'octet haut dans le rouge, le bas dans le vert.

const DOSSIER := "res://communes/belley/"
## L'altitude du y = 0 (plus bas que le Rhône, 212 m au pied de Parves).
const ALT0 := 200.0
## Le bourg_reel compte en unités de Smarves (2,4 m).
const UNITE := 2.4

var _grilles: Array = []  # du plus fin au plus large : {x0, z0, pas, nx, nz, h: PackedFloat32Array (y), marge}


func _init() -> void:
	var b = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "bourg.json"))
	var r: Dictionary = b.relief
	var h := PackedFloat32Array()
	h.resize(r.h.size())
	var zero := float(b.altitude_zero) - ALT0
	for i in r.h.size():
		h[i] = zero + float(r.h[i]) * UNITE
	_grilles.append({"x0": float(r.x0) * UNITE, "z0": float(r.z0) * UNITE, "pas": float(r.pas) * UNITE,
		"nx": int(r.nx), "nz": int(r.nz), "h": h, "marge": 60.0})
	_grilles.append(_carte("relief", 150.0))
	_grilles.append(_carte("crete", 300.0))
	_grilles.append(_carte("lointain", 0.0))


## Une carte PNG de relief_lointain.py et son .json.
func _carte(nom: String, marge: float) -> Dictionary:
	var m = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "relief/" + nom + ".json"))
	# Une carte de données s'importe sans perte ni mipmaps (son .import) et part sans perte (emballage.json).
	var img: Image = (load(DOSSIER + "relief/" + nom + ".png") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var nx := img.get_width()
	var nz := img.get_height()
	var data := img.get_data()
	var canaux := 4 if img.get_format() == Image.FORMAT_RGBA8 else 3
	var h := PackedFloat32Array()
	h.resize(nx * nz)
	var bas := float(m.noir) - ALT0
	var etendue := float(m.blanc) - float(m.noir)
	for i in nx * nz:
		h[i] = bas + float(data[i * canaux] * 256 + data[i * canaux + 1]) / 65535.0 * etendue
	return {"x0": float(m.cadre[0]), "z0": float(m.cadre[1]), "pas": float(m.pas), "nx": nx, "nz": nz, "h": h, "marge": marge}


## La hauteur du sol en (x, z), lue dans la grille la plus fine qui couvre le point ; près du bord d'une grille,
## elle se fond dans la suivante sur sa marge.
func hauteur(x: float, z: float) -> float:
	for k in _grilles.size():
		var g: Dictionary = _grilles[k]
		var d := _dedans(g, x, z)
		if d <= 0.0:
			continue
		var v := _lire(g, x, z)
		if d >= g.marge or k == _grilles.size() - 1:
			return v
		return lerpf(_suivante(k + 1, x, z), v, d / g.marge)
	return 0.0


func _suivante(k: int, x: float, z: float) -> float:
	for i in range(k, _grilles.size()):
		if _dedans(_grilles[i], x, z) > 0.0:
			return _lire(_grilles[i], x, z)
	return 0.0


## La distance du point au bord de la grille, vers l'intérieur (négative dehors).
func _dedans(g: Dictionary, x: float, z: float) -> float:
	var x1: float = g.x0 + (g.nx - 1) * g.pas
	var z1: float = g.z0 + (g.nz - 1) * g.pas
	return minf(minf(x - g.x0, x1 - x), minf(z - g.z0, z1 - z))


func _lire(g: Dictionary, x: float, z: float) -> float:
	var fi := clampf((x - g.x0) / g.pas, 0.0, g.nx - 1.001)
	var fj := clampf((z - g.z0) / g.pas, 0.0, g.nz - 1.001)
	var i := int(fi)
	var j := int(fj)
	fi -= i
	fj -= j
	var h: PackedFloat32Array = g.h
	var n: int = g.nx
	var a := h[j * n + i]
	var b := h[j * n + i + 1]
	var c := h[(j + 1) * n + i]
	var d := h[(j + 1) * n + i + 1]
	return lerpf(lerpf(a, b, fi), lerpf(c, d, fi), fj)


## Le cadre d'une grille, en mètres : [x0, z0, x1, z1]. 0 le bourg, 1 le proche, 2 la crête, 3 l'horizon.
func cadre(k: int) -> Array:
	var g: Dictionary = _grilles[k]
	return [g.x0, g.z0, g.x0 + (g.nx - 1) * g.pas, g.z0 + (g.nz - 1) * g.pas]
