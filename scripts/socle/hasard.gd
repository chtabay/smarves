class_name Hasard
extends RefCounted
## Un tirage pseudo-aléatoire rejouable (mulberry32), le même que celui du Vestiaire (Zeus,
## src/moteur/hasard.js) : à graine égale, mêmes tirages des deux côtés. L'état tient dans un entier,
## pour qu'un match du championnat de la Vienne se rejoue à l'identique chez tous les joueurs
## (docs/SUITE.md, section 6).

var etat: int = 0


static func depuis(graine: int) -> Hasard:
	var h := Hasard.new()
	h.etat = graine & 0xFFFFFFFF
	return h


## Une graine stable tirée d'un texte (FNV-1a 32 bits) : « 3/7/smarves/liguge » donne toujours la même.
static func graine(texte: String) -> int:
	var g: int = 0x811c9dc5
	for b in texte.to_utf8_buffer():
		g = ((g ^ b) * 0x01000193) & 0xFFFFFFFF
	return g


## Un réel dans [0, 1).
func suivant() -> float:
	etat = (etat + 0x6d2b79f5) & 0xFFFFFFFF
	var t: int = etat
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ (t + _imul(t ^ (t >> 7), t | 61))) & 0xFFFFFFFF
	return float(t ^ (t >> 14)) / 4294967296.0


func entier(mini: int, maxi: int) -> int:
	return mini + int(floor(suivant() * (maxi - mini + 1)))


func chance(p: float) -> bool:
	return suivant() < p


func choix(liste: Array) -> Variant:
	return liste[int(floor(suivant() * liste.size()))]


## Un choix pondéré : poids(élément) >= 0 ; tout à zéro, un choix simple.
func pondere(liste: Array, poids: Callable) -> Variant:
	var w: Array = liste.map(poids)
	var total := 0.0
	for x in w:
		total += x
	if total <= 0.0:
		return choix(liste)
	var r := suivant() * total
	for i in liste.size():
		r -= w[i]
		if r < 0.0:
			return liste[i]
	return liste[-1]


## Loi normale approchée (Box-Muller).
func normal(moyenne := 0.0, ecart := 1.0) -> float:
	var u := maxf(suivant(), 1e-9)
	var v := suivant()
	return moyenne + ecart * sqrt(-2.0 * log(u)) * cos(TAU * v)


func melanger(liste: Array) -> Array:
	var l := liste.duplicate()
	for i in range(l.size() - 1, 0, -1):
		var j := int(floor(suivant() * (i + 1)))
		var tmp = l[i]
		l[i] = l[j]
		l[j] = tmp
	return l


## Le Math.imul de JavaScript, en non signé : les 32 bits bas du produit (tout ici reste non signé, les
## décalages de JavaScript étant des >>> ; les bits sont les mêmes).
static func _imul(a: int, b: int) -> int:
	return (a * b) & 0xFFFFFFFF
