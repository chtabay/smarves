extends RefCounted
## Le relief de toute la ville de Lyon (cartes/lyon/VILLE.md), une grille IGN de 10 m sur environ 2,6 km
## par 3,1 km, dans le repère de la commune : origine au centre de la place Sathonay, x vers l'est, z vers
## le sud, mètres, zéro au niveau de la Saône (altitude 162 m). Hors de sa grille fine, hauteur(x, z) de
## lyon.gd délègue ici ; les quartiers lisent toujours le relief par la commune, jamais ce fichier
## directement. Les données : relief.json.gz, écrit par tools/relief_ville.py (h en décimètres entiers).

## Lu par Atelier.donnees, qui prend le .gz à côté (docs/BIBLIOTHEQUE.md, « Les règles des paquets »).
const FICHIER := "res://communes/lyon/quartiers/_ville/relief.json"

static var _h := PackedFloat32Array()
static var _x0 := 0.0
static var _z0 := 0.0
static var _pas := 10.0
static var _nx := 0
static var _nz := 0


## La hauteur du terrain en mètres au-dessus du zéro de la commune, interpolée ; au bord, la valeur du bord.
static func hauteur(x: float, z: float) -> float:
	if _nx == 0 and not _lire():
		return 0.0
	var fx := clampf((x - _x0) / _pas, 0.0, _nx - 1.001)
	var fz := clampf((z - _z0) / _pas, 0.0, _nz - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h00 := _h[iz * _nx + ix]
	var h10 := _h[iz * _nx + ix + 1]
	var h01 := _h[(iz + 1) * _nx + ix]
	var h11 := _h[(iz + 1) * _nx + ix + 1]
	return h00 * (1.0 - tx) * (1.0 - tz) + h10 * tx * (1.0 - tz) + h01 * (1.0 - tx) * tz + h11 * tx * tz


## Le cadre couvert, en mètres : [x0, z0, x1, z1].
static func cadre() -> Array:
	if _nx == 0 and not _lire():
		return []
	return [_x0, _z0, _x0 + (_nx - 1) * _pas, _z0 + (_nz - 1) * _pas]


static func _lire() -> bool:
	var d = Atelier.donnees(FICHIER)
	if typeof(d) != TYPE_DICTIONARY:
		return false
	_x0 = float(d.x0)
	_z0 = float(d.z0)
	_pas = float(d.pas)
	_nx = int(d.nx)
	_nz = int(d.nz)
	var h: Array = d.h
	_h.resize(h.size())
	for i in h.size():
		_h[i] = float(h[i]) * 0.1
	return _nx > 1 and _nz > 1 and _h.size() == _nx * _nz
