extends Node3D
## Le stade de campagne, version 1 (bibliothèque commune, « stade-de-campagne@1 ») : un terrain de village
## autour de la pelouse du socle. La petite tribune de bois couverte au nord, le club-house en crépi et sa
## véranda à l'ouest, la buvette à l'est, le tableau à volets au sud, la haie de charmille tout autour et le
## portail dans la haie. Rien que du décor et ses ancres (scripts/socle/ancres.gd, contrat du stade) : le
## socle y pose la pelouse, le match, le président, le bureau, le panneau, le tableau et la sortie.
## Une version publiée ne change plus : une retouche se publie en « @2 », dans un dossier à côté.

## Le terrain du socle et ses abords (la pelouse, les bancs, la main courante, les pylônes) occupent
## ±23 × ±15 ; le décor commence au-delà.
const HAIE_X := 29.0
const HAIE_Z := 23.0

var _mats := {}


func _ready() -> void:
	_sol()
	_haie()
	_tribune()
	_club_house()
	_buvette()
	_tableau()
	_portail()


func _mat(nom: String, c: Color, rugosite := 0.85) -> StandardMaterial3D:
	if not _mats.has(nom):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rugosite
		_mats[nom] = m
	return _mats[nom]


func _boite(taille: Vector3, pos: Vector3, mat: Material, solide := false, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if solide:
		var corps := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = taille
		cs.shape = sh
		corps.add_child(cs)
		mi.add_child(corps)
	return mi


func _ancre(nom: String, pos: Vector3, lacet := 0.0) -> Marker3D:
	var a := Marker3D.new()
	a.name = nom
	a.position = pos
	a.rotation.y = lacet
	add_child(a)
	return a


func _lampe(pos: Vector3, energie := 1.4, portee := 7.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.55)
	l.light_energy = energie
	l.omni_range = portee
	l.position = pos
	add_child(l)


## L'herbe des abords, sous le terrain du socle, et le chemin de gravier du portail à la tribune.
func _sol() -> void:
	_ancre("Pelouse", Vector3.ZERO)
	_boite(Vector3(HAIE_X * 2.0 + 2.0, 0.2, HAIE_Z * 2.0 + 2.0), Vector3(0, -0.12, 0), _mat("herbe", Color(0.24, 0.38, 0.18), 1.0), true)
	_boite(Vector3(6.0, 0.02, 2.4), Vector3(-25.5, -0.01, -6.0), _mat("gravier", Color(0.62, 0.58, 0.5), 1.0))
	_boite(Vector3(2.4, 0.02, 10.0), Vector3(-23.6, -0.01, -11.6), _mat("gravier", Color(0.62, 0.58, 0.5), 1.0))


## La haie de charmille tout autour, ouverte au portail (ouest).
func _haie() -> void:
	var vert := _mat("charmille", Color(0.18, 0.32, 0.14), 1.0)
	_boite(Vector3(HAIE_X * 2.0, 2.2, 1.0), Vector3(0, 1.1, -HAIE_Z), vert, true)
	_boite(Vector3(HAIE_X * 2.0, 2.2, 1.0), Vector3(0, 1.1, HAIE_Z), vert, true)
	_boite(Vector3(1.0, 2.2, HAIE_Z * 2.0), Vector3(HAIE_X, 1.1, 0), vert, true)
	# À l'ouest, la haie s'ouvre sur le portail (z = -6, 3 de large).
	var nord := HAIE_Z - 7.5
	_boite(Vector3(1.0, 2.2, nord), Vector3(-HAIE_X, 1.1, -7.5 - nord / 2.0), vert, true)
	var sud := HAIE_Z - 4.5
	_boite(Vector3(1.0, 2.2, sud), Vector3(-HAIE_X, 1.1, -4.5 + sud / 2.0), vert, true)


## La tribune de bois au nord, quatre gradins sous un toit de tôle, le fronton face à la pelouse.
func _tribune() -> void:
	var bois := _mat("bois", Color(0.5, 0.34, 0.2), 0.7)
	var planche := _mat("planche", Color(0.62, 0.45, 0.28), 0.75)
	var tole := _mat("tole", Color(0.36, 0.4, 0.42), 0.45)
	var z0 := -16.4
	for i in 4:
		_boite(Vector3(20.0, 0.45 + i * 0.45, 1.0), Vector3(0, (0.45 + i * 0.45) / 2.0, z0 - 0.5 - i), bois, true)
		_boite(Vector3(19.6, 0.06, 0.45), Vector3(0, 0.48 + i * 0.45, z0 - 0.55 - i), planche)
	_boite(Vector3(20.6, 4.2, 0.25), Vector3(0, 2.1, z0 - 4.4), bois, true)
	for x in [-9.8, -4.9, 0.0, 4.9, 9.8]:
		_boite(Vector3(0.18, 4.3, 0.18), Vector3(x, 2.15, z0 + 0.1), bois)
	var toit := _boite(Vector3(21.0, 0.1, 5.4), Vector3(0, 4.45, z0 - 2.2), tole)
	toit.rotation_degrees.x = -7.0
	_boite(Vector3(21.0, 0.6, 0.1), Vector3(0, 4.05, z0 + 0.22), _mat("fronton", Color(0.93, 0.9, 0.82), 0.8))
	_ancre("TribuneClub", Vector3(0, 4.05, z0 + 0.3))


## Le club-house à l'ouest de la tribune : murs de crépi, toit de tuiles, une véranda ouverte côté pelouse
## où le président a son bureau.
func _club_house() -> void:
	var crepi := _mat("crepi", Color(0.88, 0.83, 0.7), 0.9)
	var tuile := _mat("tuile", Color(0.62, 0.3, 0.2), 0.8)
	var bois := _mat("bois", Color(0.5, 0.34, 0.2), 0.7)
	var c := Vector3(-18.5, 0, -20.0)
	_boite(Vector3(7.0, 3.0, 4.0), c + Vector3(0, 1.5, -1.0), crepi, true)
	_boite(Vector3(7.6, 0.25, 7.2), c + Vector3(0, 3.1, 0.4), tuile)
	# La véranda : un plancher, deux poteaux, le toit qui la couvre.
	_boite(Vector3(7.0, 0.12, 3.0), c + Vector3(0, 0.06, 2.5), _mat("planche", Color(0.62, 0.45, 0.28), 0.75), true)
	for x in [-3.3, 3.3]:
		_boite(Vector3(0.16, 3.0, 0.16), c + Vector3(x, 1.5, 3.9), bois)
	_boite(Vector3(1.0, 2.1, 0.06), c + Vector3(2.0, 1.05, 1.02), bois)
	_boite(Vector3(1.4, 0.9, 0.06), c + Vector3(-1.6, 1.7, 1.02), _mat("vitre", Color(0.35, 0.45, 0.6), 0.2))
	# Le bureau du président, sur la véranda : la table, la chaise, le classeur.
	_boite(Vector3(1.8, 0.08, 0.8), c + Vector3(-1.0, 0.85, 2.3), bois, true)
	for x in [-1.75, -0.25]:
		_boite(Vector3(0.08, 0.78, 0.7), c + Vector3(x, 0.47, 2.3), bois)
	_boite(Vector3(0.3, 0.32, 0.24), c + Vector3(-0.4, 1.05, 2.2), _mat("classeur", Color(0.2, 0.3, 0.5), 0.6))
	_ancre("Bureau", c + Vector3(-1.0, 0.12, 2.9))
	_ancre("President", c + Vector3(1.6, 0.12, 3.6), deg_to_rad(30.0))
	_lampe(c + Vector3(0, 2.8, 2.6))


## La buvette à l'est de la tribune : un cabanon de planches, son auvent et son comptoir.
func _buvette() -> void:
	var b := Vector3(15.0, 0, -19.0)
	_boite(Vector3(3.4, 2.5, 2.4), b + Vector3(0, 1.25, 0), _mat("planche", Color(0.62, 0.45, 0.28), 0.75), true)
	_boite(Vector3(3.8, 0.1, 1.4), b + Vector3(0, 2.55, 1.6), _mat("auvent", Color(0.75, 0.2, 0.18), 0.7))
	_boite(Vector3(2.8, 0.1, 0.5), b + Vector3(0, 1.05, 1.45), _mat("bois", Color(0.5, 0.34, 0.2), 0.7))
	_ancre("Buvette", b + Vector3(0, 0, 1.4))
	_lampe(b + Vector3(0, 2.3, 2.0), 1.2, 6.0)


## Le tableau à volets au sud, face à la tribune : deux poteaux, le panneau noir où le socle écrit.
func _tableau() -> void:
	var t := Vector3(0, 0, 18.5)
	var fer := _mat("fer", Color(0.3, 0.32, 0.34), 0.5)
	for x in [-3.0, 3.0]:
		_boite(Vector3(0.2, 5.6, 0.2), t + Vector3(x, 2.8, 0.2), fer, true)
	_boite(Vector3(6.8, 2.4, 0.2), t + Vector3(0, 4.3, 0.2), _mat("ardoise", Color(0.07, 0.08, 0.09), 0.6))
	_boite(Vector3(7.0, 0.16, 0.4), t + Vector3(0, 5.6, 0.2), _mat("auvent", Color(0.75, 0.2, 0.18), 0.7))
	_ancre("Tableau", t + Vector3(0, 4.3, 0.0), PI)


## Le portail dans la haie, à l'ouest, et le panneau du club juste passé le portail.
func _portail() -> void:
	var pierre := _mat("pierre", Color(0.86, 0.82, 0.72), 0.9)
	var bois := _mat("bois", Color(0.5, 0.34, 0.2), 0.7)
	for z in [-7.8, -4.2]:
		_boite(Vector3(0.6, 2.6, 0.6), Vector3(-HAIE_X, 1.3, z), pierre, true)
	_boite(Vector3(0.3, 0.4, 4.2), Vector3(-HAIE_X, 2.8, -6.0), bois)
	_ancre("Sortie", Vector3(-HAIE_X + 0.6, 0, -6.0), PI / 2.0)
	_ancre("Arrivee", Vector3(-HAIE_X + 3.0, 0, -6.0), PI / 2.0)
	# Le panneau du club, sur deux pieds, tourné vers qui entre.
	var p := Vector3(-24.0, 0, -10.5)
	for dx in [-0.95, 0.95]:
		_boite(Vector3(0.1, 2.3, 0.1), p + Vector3(0.3, 1.15, dx), bois)
	_boite(Vector3(0.08, 1.3, 2.1), p + Vector3(0.3, 1.75, 0), _mat("ardoise", Color(0.07, 0.08, 0.09), 0.6), true)
	_ancre("Panneau", p + Vector3(0.36, 0, 0), PI / 2.0)
