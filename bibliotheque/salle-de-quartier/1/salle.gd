extends Node3D
## La salle de quartier, version 1 (bibliothèque commune, « salle-de-quartier@1 ») : un gymnase municipal
## autour du parquet du socle. Les murs de brique et la charpente de métal, les bandeaux vitrés en haut des
## longs côtés, les gradins de bois au nord, le bureau du club vitré à l'ouest, le panneau et le tableau des
## parts à l'est, la porte au sud sous l'enseigne, le parvis et l'abribus devant. Rien que du décor et ses
## ancres (scripts/socle/ancres.gd, contrat de la salle) : le socle y pose le parquet, les paniers, les bancs,
## le cube, le club et son match, le président, le bureau, le panneau, les parts et l'arrêt du car.
## Une version publiée ne change plus : une retouche se publie en « @2 », dans un dossier à côté.

## Le parquet du socle et ses abords (les bancs, la table de marque, les fauteuils du bord) occupent
## ±18 × ±11.5 ; les murs de la salle sont au-delà. Le cube du socle (7,6 m de côté) pend sous le plafond.
const MUR_X := 24.0
const MUR_Z := 16.0
const HAUT := 13.5
const PORTE := 2.6
const PARVIS_Z := 32.0

var _mats := {}


func _ready() -> void:
	_sol()
	_murs()
	_charpente()
	_gradins()
	_bureau_du_club()
	_mur_est()
	_porte_et_parvis()


func _mat(nom: String, c: Color, rugosite := 0.85, lueur := 0.0) -> StandardMaterial3D:
	if not _mats.has(nom):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rugosite
		if lueur > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = lueur
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


func _lampe(pos: Vector3, energie := 1.4, portee := 7.0, couleur := Color(1.0, 0.86, 0.62)) -> void:
	var l := OmniLight3D.new()
	l.light_color = couleur
	l.light_energy = energie
	l.omni_range = portee
	l.position = pos
	add_child(l)


func _texte(texte: String, pos: Vector3, taille: int, couleur: Color, lacet := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = texte
	l.font_size = taille
	l.pixel_size = 0.005
	l.modulate = couleur
	l.outline_size = 0
	l.position = pos
	l.rotation.y = lacet
	add_child(l)
	return l


## Le sol de la salle autour du parquet (un lino gris, juste sous le bord du socle), le cube et les tribunes.
func _sol() -> void:
	_ancre("Parquet", Vector3.ZERO)
	_boite(Vector3(MUR_X * 2.0, 0.2, MUR_Z * 2.0), Vector3(0, -0.11, 0), _mat("lino", Color(0.36, 0.38, 0.4), 0.7), true)
	_ancre("Cube", Vector3(0, 9.2, 0))


## Les quatre murs de brique, la plinthe peinte, la porte au sud ; les bandeaux vitrés en haut des longs
## côtés, qui laissent voir le soir.
func _murs() -> void:
	var brique := _mat("brique", Color(0.62, 0.34, 0.25), 0.95)
	var plinthe := _mat("plinthe", Color(0.16, 0.3, 0.46), 0.6)
	var vitre := _mat("vitre", Color(0.1, 0.16, 0.3), 0.15, 0.6)
	var e := 0.4
	_boite(Vector3(MUR_X * 2.0, HAUT, e), Vector3(0, HAUT / 2.0, -MUR_Z), brique, true)
	_boite(Vector3(e, HAUT, MUR_Z * 2.0), Vector3(-MUR_X, HAUT / 2.0, 0), brique, true)
	_boite(Vector3(e, HAUT, MUR_Z * 2.0), Vector3(MUR_X, HAUT / 2.0, 0), brique, true)
	# Le mur sud, de part et d'autre de la porte, et le linteau au-dessus.
	var cote := MUR_X - PORTE
	for s: float in [-1.0, 1.0]:
		_boite(Vector3(cote, HAUT, e), Vector3(s * (PORTE + cote / 2.0), HAUT / 2.0, MUR_Z), brique, true)
	_boite(Vector3(PORTE * 2.0, HAUT - 3.6, e), Vector3(0, 3.6 + (HAUT - 3.6) / 2.0, MUR_Z), brique)
	# La plinthe bleue, à hauteur d'épaule, tout autour (sauf la porte).
	_boite(Vector3(MUR_X * 2.0, 1.6, 0.05), Vector3(0, 0.8, -MUR_Z + e / 2.0 + 0.03), plinthe)
	for s: float in [-1.0, 1.0]:
		_boite(Vector3(0.05, 1.6, MUR_Z * 2.0), Vector3(s * (MUR_X - e / 2.0 - 0.03), 0.8, 0), plinthe)
		_boite(Vector3(cote, 1.6, 0.05), Vector3(s * (PORTE + cote / 2.0), 0.8, MUR_Z - e / 2.0 - 0.03), plinthe)
	# Les bandeaux vitrés, est et ouest, sous le plafond.
	for s: float in [-1.0, 1.0]:
		_boite(Vector3(0.05, 1.8, MUR_Z * 2.0 - 2.0), Vector3(s * (MUR_X - e / 2.0 - 0.04), HAUT - 2.0, 0), vitre)
	_texte("SALLE OMNISPORTS", Vector3(0, 7.5, -MUR_Z + 0.3), 220, Color(0.93, 0.9, 0.82))


## Le plafond, les fermes de métal qui le portent, les rangées de lampes.
func _charpente() -> void:
	var metal := _mat("metal", Color(0.42, 0.45, 0.48), 0.5)
	_boite(Vector3(MUR_X * 2.0, 0.3, MUR_Z * 2.0), Vector3(0, HAUT + 0.15, 0), _mat("plafond", Color(0.72, 0.72, 0.7), 0.9))
	for k in 7:
		var x := -MUR_X + 3.0 + k * (MUR_X * 2.0 - 6.0) / 6.0
		_boite(Vector3(0.3, 0.5, MUR_Z * 2.0), Vector3(x, HAUT - 0.4, 0), metal)
		_boite(Vector3(0.12, 1.4, MUR_Z * 2.0), Vector3(x, HAUT - 1.3, 0), metal)
	for z in [-12.0, 12.0]:
		for k in 4:
			var x := -15.0 + k * 10.0
			_boite(Vector3(2.4, 0.12, 0.5), Vector3(x, HAUT - 1.6, z), _mat("neon", Color(0.95, 0.96, 1.0), 0.4, 2.0))
			_lampe(Vector3(x, HAUT - 2.0, z), 1.6, 12.0, Color(0.92, 0.95, 1.0))


## Les gradins de bois au nord, six rangs, leur garde-corps, l'escalier au bout.
func _gradins() -> void:
	var beton := _mat("beton", Color(0.55, 0.55, 0.53), 0.95)
	var bois := _mat("banc", Color(0.66, 0.48, 0.3), 0.75)
	var z0 := -12.0
	for i in 6:
		var h := 0.45 + i * 0.45
		_boite(Vector3(30.0, h, 0.6), Vector3(0, h / 2.0, z0 - 0.3 - i * 0.6), beton, true)
		_boite(Vector3(29.6, 0.08, 0.36), Vector3(0, h + 0.04, z0 - 0.38 - i * 0.6), bois)
	_boite(Vector3(30.0, 1.0, 0.06), Vector3(0, 1.0, z0 + 0.05), _mat("garde", Color(0.16, 0.3, 0.46), 0.5))


## Le bureau du club, à l'ouest : une boîte vitrée sur le côté du parquet, le bureau et son fauteuil, l'armoire
## aux coupes ; le président se tient devant, côté terrain.
func _bureau_du_club() -> void:
	var c := Vector3(-21.5, 0, -1.0)
	var cloison := _mat("cloison", Color(0.85, 0.84, 0.8), 0.9)
	var verre := _mat("verre", Color(0.6, 0.75, 0.85, 0.3), 0.1)
	verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_boite(Vector3(4.6, 0.3, 7.0), c + Vector3(0, 3.0, 0), cloison)
	_boite(Vector3(4.6, 3.0, 0.15), c + Vector3(0, 1.5, -3.5), cloison, true)
	_boite(Vector3(4.6, 3.0, 0.15), c + Vector3(0, 1.5, 3.5), cloison, true)
	# La vitre côté parquet, ouverte d'une porte au sud.
	_boite(Vector3(0.08, 3.0, 5.2), c + Vector3(2.3, 1.5, -0.9), verre, true)
	_boite(Vector3(0.1, 0.4, 7.0), c + Vector3(2.3, 2.85, 0), cloison)
	_texte("BUREAU DU CLUB", c + Vector3(2.36, 2.85, 0), 60, Color(0.16, 0.3, 0.46), PI / 2.0)
	var bois := _mat("bureau", Color(0.36, 0.22, 0.12), 0.5)
	_boite(Vector3(1.0, 0.08, 2.2), c + Vector3(-0.6, 0.8, -1.0), bois, true)
	for dz in [-1.95, -0.05]:
		_boite(Vector3(0.9, 0.76, 0.08), c + Vector3(-0.6, 0.38, -1.0 + dz + 0.95), bois)
	_boite(Vector3(0.7, 1.2, 0.7), c + Vector3(-1.6, 0.6, -1.0), _mat("fauteuil", Color(0.1, 0.1, 0.12), 0.5))
	_boite(Vector3(0.5, 2.0, 1.6), c + Vector3(-2.0, 1.0, 2.2), bois)
	_ancre("Bureau", c + Vector3(0.6, 0, -1.0), PI / 2.0)
	_ancre("President", c + Vector3(3.4, 0, 4.6), PI / 2.0)
	_lampe(c + Vector3(0, 2.6, 0), 1.2, 6.0)


## Le mur est, côté entrée : le panneau du club et le tableau des parts, sous leurs lampes.
func _mur_est() -> void:
	var cadre := _mat("cadre", Color(0.16, 0.3, 0.46), 0.6)
	var liege := _mat("liege", Color(0.08, 0.09, 0.1), 0.7)
	var x := MUR_X - 0.25
	_boite(Vector3(0.1, 1.6, 2.6), Vector3(x, 1.8, -4.0), cadre)
	_boite(Vector3(0.06, 1.4, 2.4), Vector3(x - 0.05, 1.8, -4.0), liege)
	_ancre("Panneau", Vector3(x - 0.1, 0, -4.0), -PI / 2.0)
	_boite(Vector3(0.1, 2.0, 3.6), Vector3(x, 2.1, 4.0), cadre)
	_boite(Vector3(0.06, 1.8, 3.4), Vector3(x - 0.05, 2.1, 4.0), liege)
	_ancre("Parts", Vector3(x - 0.1, 0, 4.0), -PI / 2.0)


## La porte au sud, l'enseigne au-dessus côté rue, le parvis, l'abribus du car et le réverbère.
func _porte_et_parvis() -> void:
	var asphalte := _mat("asphalte", Color(0.2, 0.2, 0.22), 0.95)
	_boite(Vector3(60.0, 0.2, PARVIS_Z - MUR_Z), Vector3(0, -0.11, (PARVIS_Z + MUR_Z) / 2.0), asphalte, true)
	_boite(Vector3(PORTE * 2.0 + 1.0, 0.25, 0.5), Vector3(0, 3.7, MUR_Z + 0.35), _mat("auvent", Color(0.16, 0.3, 0.46), 0.6))
	_boite(Vector3(16.0, 1.4, 0.1), Vector3(0, 6.0, MUR_Z + 0.25), _mat("enseigne", Color(0.1, 0.12, 0.16), 0.6))
	_ancre("Fronton", Vector3(0, 6.0, MUR_Z + 0.32))
	# Les murs de la rue, pour qu'on ne parte pas dans le noir.
	var muret := _mat("muret", Color(0.5, 0.5, 0.48), 0.9)
	_boite(Vector3(60.0, 1.2, 0.4), Vector3(0, 0.6, PARVIS_Z), muret, true)
	for s: float in [-1.0, 1.0]:
		_boite(Vector3(0.4, 1.2, PARVIS_Z - MUR_Z), Vector3(s * 30.0, 0.6, (PARVIS_Z + MUR_Z) / 2.0), muret, true)
	# L'abribus.
	var a := Vector3(6.0, 0, PARVIS_Z - 3.0)
	var vert := _mat("abri", Color(0.12, 0.32, 0.26), 0.6)
	_boite(Vector3(3.6, 0.12, 1.6), a + Vector3(0, 2.5, 0), vert)
	_boite(Vector3(3.6, 2.4, 0.05), a + Vector3(0, 1.2, 0.75), _mat("verre", Color(0.6, 0.75, 0.85, 0.3), 0.1))
	for s: float in [-1.0, 1.0]:
		_boite(Vector3(0.08, 2.5, 0.08), a + Vector3(s * 1.75, 1.25, 0.75), vert)
		_boite(Vector3(0.08, 2.5, 0.08), a + Vector3(s * 1.75, 1.25, -0.7), vert)
	_ancre("Sortie", a + Vector3(0, 0, -0.6), PI)
	_ancre("Arrivee", Vector3(0, 0, PARVIS_Z - 6.0), PI)
	_lampe(a + Vector3(0, 2.3, 0), 1.2, 6.0)
	_boite(Vector3(0.14, 5.0, 0.14), Vector3(-6.0, 2.5, PARVIS_Z - 3.0), _mat("metal", Color(0.42, 0.45, 0.48), 0.5))
	_lampe(Vector3(-6.0, 4.8, PARVIS_Z - 3.0), 2.0, 14.0)
	_lampe(Vector3(0, 3.2, MUR_Z + 1.4), 1.2, 6.0)
