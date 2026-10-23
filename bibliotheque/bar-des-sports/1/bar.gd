extends Node3D
## Le sports bar de Cloué (1.6.2, MIT : voir LICENCE.txt), sans Cloué ni son tenancier : une grande salle de
## 28 × 24 m en brique et bois sombre, un comptoir cannelé de 11 m sous un portique de trois écrans, le mur de
## bouteilles, un lounge et des alcôves face aux écrans, une alcôve des tables tapissée de vert, le salon du club
## et sa vitrine. Dix écrans passent une séquence de football dessinée, sans score réel. Des habitués boivent et
## parlent, un serveur fait ses allers-retours derrière le comptoir. Le socle branche le reste par les ancres
## de la salle de jeu (Ancres.SALLE_JEU) : le tenancier (Comptoir), quatre places de table, l'enseigne du
## portique, l'arrivée et la sortie. Une commune la nomme dans le « modele » d'une salle de jeu.

const DECOR := preload("res://bibliotheque/bar-des-sports/1/menuiserie.gd")
const ANIMATION := preload("res://bibliotheque/bar-des-sports/1/animation_football.gd")
const CRITTER := preload("res://scripts/critter.gd")
const PEOPLE_SCALE := 2.6
const W := 28.0
const D := 24.0
const H := 5.2
## Les trois habits d'écran de l'original : la dalle, le bandeau, et les maillots des deux équipes.
const PALETTES := [[Color("071426"), Color("145bbc"), Color("cdff62"), Color("56aeff")],
	[Color("100e27"), Color("5e35a8"), Color("ddcdff"), Color("ac83ff")],
	[Color("091d19"), Color("23694c"), Color("ffd77d"), Color("79c798")]]

var atelier: RefCounted
var _habitués: Array = []
var _serveur: Node3D
var _service_t := 0.0


func _ready() -> void:
	atelier = DECOR.new(self)
	_soiree()
	_architecture()
	_grand_comptoir()
	_lounge_et_alcoves()
	_alcove()
	_galerie_et_details()
	_vie()
	atelier.achever()
	_ecrans()
	_ancres()


func _ancre(nom: String, p: Vector3, angle := 0.0, metas := {}) -> Marker3D:
	var m := Marker3D.new()
	m.name = nom
	m.position = p
	m.rotation.y = angle
	for k in metas:
		m.set_meta(k, metas[k])
	add_child(m)
	return m


## Les ancres du contrat de la salle de jeu : leur +Z regarde le visiteur (pour une table, la place du joueur).
func _ancres() -> void:
	_ancre("Arrivee", Vector3(0, 0.06, 10), PI)
	_ancre("Sortie", Vector3(0, 0, 11.4), PI)
	# Le tenancier derrière le comptoir, là où se tenait Selim.
	_ancre("Comptoir", Vector3(1.2, 0, -8.6))
	_ancre("Enseigne", Vector3(0, 4.99, -6.665), 0.0, {"hauteur": 0.3, "largeur": 13.0, "couleur": Color("e1c99e"), "espace": true})
	# L'alcôve des tables (la table de poker de l'original, puis la machine du café), ouverte à l'est.
	_ancre("Table1", Vector3(-9, 0, 7.2), PI / 2)
	_ancre("Table2", Vector3(-12.2, 0, 9.6), PI / 2)
	# Deux îlots de la salle, face à l'entrée.
	_ancre("Table3", Vector3(-4.5, 0, -0.3))
	_ancre("Table4", Vector3(3.8, 0, 2.4))


func _soiree() -> void:
	var world := WorldEnvironment.new()
	world.name = "SoireeAuBar"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10191f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9cacc0")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	# Pas de soleil dans l'intérieur : ambre local, lumière froide des écrans.
	atelier.lumiere(Vector3(0, 2.8, -9.4), 3.2, 9.0, Color("ffbd72"), true)
	atelier.lumiere(Vector3(-8.9, 3.1, 7.1), 1.25, 5.5, Color("ffd6a0"), true)
	atelier.lumiere(Vector3(-9, 3.2, -2.5), 0.95, 7.0, Color("ffc997"))
	atelier.lumiere(Vector3(9.5, 3.2, 1), 1.15, 8.0, Color("ffc28b"))
	atelier.lumiere(Vector3(8, 3.1, 8.2), 0.8, 5.7, Color("ffc28b"))
	atelier.lumiere(Vector3(0, 3.4, 6.2), 0.9, 7.0, Color("ffd1a0"))
	atelier.lumiere(Vector3(0, 2.5, -4.7), 0.8, 7.5, Color("b7d4e1"))
	atelier.lumiere(Vector3(10.8, 3.1, -8.7), 0.7, 5.5, Color("99c7e0"))


func _architecture() -> void:
	atelier.b(Vector3(0, -0.14, 0), Vector3(W, 0.28, D), "pierre")
	atelier.solide(Vector3(0, -0.14, 0), Vector3(W, 0.28, D), "SolSportBar")
	atelier.b(Vector3(0, 0.012, 0), Vector3(W - 0.12, 0.022, D - 0.12), "parquet")
	for x in [-14.0, 14.0]:
		atelier.b(Vector3(x, H / 2, 0), Vector3(0.24, H, D), "brique")
		atelier.solide(Vector3(x, H / 2, 0), Vector3(0.24, H, D), "MurLateral")
		atelier.b(Vector3(x - signf(x) * 0.15, 0.7, 0), Vector3(0.09, 1.4, D), "bois")
		for y in [0.09, 1.39, 4.98]: atelier.b(Vector3(x - signf(x) * 0.22, y, 0), Vector3(0.12, 0.065, D), "laiton" if y == 1.39 else "chene")
		for z in range(-11, 12, 2): atelier.b(Vector3(x - signf(x) * 0.21, 0.72, z), Vector3(0.06, 1.18, 0.06), "chene")
	atelier.b(Vector3(0, H / 2, -12), Vector3(W, H, 0.24), "brique")
	atelier.solide(Vector3(0, H / 2, -12), Vector3(W, H, 0.24), "MurFond")
	for x in [-7.8, 7.8]:
		atelier.b(Vector3(x, H / 2, 12), Vector3(12.4, H, 0.24), "bois")
		atelier.solide(Vector3(x, H / 2, 12), Vector3(12.4, H, 0.24), "MurEntree")
	atelier.b(Vector3(0, 4.1, 12), Vector3(3.2, 2.2, 0.24), "brique")
	atelier.b(Vector3(0, 1.4, 11.95), Vector3(2.5, 2.8, 0.15), "vert")
	atelier.solide(Vector3(0, 1.4, 12), Vector3(2.5, 2.8, 0.15), "PorteBourg")
	for x in [-1.32, 1.32]: atelier.b(Vector3(x, 1.5, 11.79), Vector3(0.11, 3, 0.18), "laiton")
	atelier.b(Vector3(0, 2.98, 11.79), Vector3(2.75, 0.12, 0.18), "laiton")
	for x in [-0.62, 0.62]:
		atelier.b(Vector3(x, 1.9, 11.82), Vector3(0.84, 1.15, 0.03), "bleu")
		atelier.b(Vector3(x, 1.15, 11.72), Vector3(0.4, 0.045, 0.07), "laiton")
	atelier.b(Vector3(0, 3.24, 11.75), Vector3(1.3, 0.32, 0.1), "vert")
	atelier.texte("SORTIE", Vector3(0, 3.25, 11.68), 0.0025, PI, Color("cae2c5"))
	atelier.b(Vector3(0, H + 0.05, 0), Vector3(W, 0.1, D), "plafond")
	# Caissons acoustiques et lignes de structure, regroupés en instanciation.
	for x in range(-12, 14, 2): atelier.b(Vector3(x, H - 0.025, 0), Vector3(0.035, 0.07, D), "acier")
	for z in range(-10, 12, 2): atelier.b(Vector3(0, H - 0.025, z), Vector3(W, 0.07, 0.035), "acier")
	# Grilles de ventilation encastrées : détail architectural sombre, à l'échelle de la pièce.
	for p in [Vector3(0, 5.1, 1.4), Vector3(-10.1, 5.1, 6.7), Vector3(10.1, 5.1, -4.0)]:
		atelier.b(p, Vector3(2.4, 0.07, 0.92), "acier")
		for j in 11: atelier.b(p + Vector3(-1.06 + j * 0.212, -0.045, 0), Vector3(0.055, 0.035, 0.78), "cuivre")
	for x in [-6.1, 6.1]:
		atelier.b(Vector3(x, 2.6, -7.9), Vector3(0.24, 5.2, 0.24), "acier")
		atelier.b(Vector3(x, 0.12, -7.9), Vector3(0.46, 0.24, 0.46), "laiton")
		atelier.solide(Vector3(x, 2.6, -7.9), Vector3(0.28, 5.2, 0.28), "PoteauBar")
	# Deux grandes travées latérales réduisent visuellement la hauteur.
	for x in [-6.7, 6.7]: atelier.b(Vector3(x, 4.55, 1.2), Vector3(0.18, 0.32, 18.6), "bois")
	for z in [-3.8, 3.2, 9.5]:
		for x in [-10, 10]: atelier.b(Vector3(x, 4.57, z), Vector3(7.8, 0.28, 0.18), "bois")
	# Longues appliques basses : petites surfaces émissives, pas 40 lumières.
	for x in [-13.77, 13.77]:
		for z in [-8.9, -0.5, 7.6]:
			atelier.b(Vector3(x, 2.12, z), Vector3(0.13, 0.8, 0.23), "laiton")
			atelier.b(Vector3(x - signf(x) * 0.085, 2.12, z), Vector3(0.06, 0.63, 0.14), "led")


func _grand_comptoir() -> void:
	# Comptoir à façade cannelée. Retour latéral, plinthe cuivre, repose-pieds.
	atelier.b(Vector3(0, 0.56, -6.92), Vector3(10.9, 1.12, 0.94), "bois")
	atelier.solide(Vector3(0, 0.56, -6.92), Vector3(10.9, 1.12, 0.94), "Comptoir")
	atelier.doux(Vector3(0, 1.17, -6.92), Vector3(11.16, 0.15, 1.23), "pierre")
	atelier.b(Vector3(0, 1.09, -6.27), Vector3(11.2, 0.055, 0.055), "laiton")
	atelier.b(Vector3(0, 0.11, -6.41), Vector3(10.9, 0.2, 0.045), "cuivre")
	for i in 72: atelier.b(Vector3(-5.34 + i * 0.15, 0.63, -6.425), Vector3(0.045, 0.82, 0.045), "chene")
	atelier.c(Vector3(0, 0.26, -6.03), 0.055, 10.7, "laiton", Vector3(0, 0, PI / 2))
	for x in [-4.5, 0.0, 4.5]: atelier.b(Vector3(x, 0.17, -6.19), Vector3(0.04, 0.3, 0.34), "laiton")
	atelier.b(Vector3(5.2, 0.56, -8.55), Vector3(0.8, 1.12, 3.3), "bois")
	atelier.solide(Vector3(5.2, 0.56, -8.55), Vector3(0.8, 1.12, 3.3), "RetourComptoir")
	atelier.doux(Vector3(5.2, 1.17, -8.55), Vector3(1.06, 0.15, 3.48), "pierre")
	# Mur de fond stratifié : menuiseries, verre sombre, bouteilles et sous-éclairage.
	atelier.b(Vector3(0, 0.61, -11.44), Vector3(11.2, 1.22, 0.95), "bois")
	atelier.b(Vector3(0, 1.25, -11.42), Vector3(11.35, 0.1, 1.1), "pierre")
	atelier.solide(Vector3(0, 0.62, -11.44), Vector3(11.2, 1.24, 0.95), "ArriereBar")
	for x in [-4.4, -2.2, 0.0, 2.2, 4.4]:
		atelier.b(Vector3(x, 2.7, -11.78), Vector3(2.05, 2.7, 0.06), "verre")
		for dx in [-1.06, 1.06]: atelier.b(Vector3(x + dx, 2.68, -11.62), Vector3(0.07, 2.78, 0.19), "laiton")
		for y in [1.65, 2.48, 3.31]:
			atelier.b(Vector3(x, y, -11.52), Vector3(2.08, 0.08, 0.45), "bois")
			atelier.b(Vector3(x, y - 0.045, -11.29), Vector3(2, 0.025, 0.018), "led")
			for j in 6: atelier.bouteille(Vector3(x - 0.8 + j * 0.32, y + 0.04, -11.43), j + int(y * 4))
	# Pression : six becs laiton et poignées courtes sur la vraie surface de service.
	atelier.b(Vector3(-2.3, 1.27, -6.92), Vector3(2.2, 0.05, 0.44), "acier")
	for i in 6:
		var x := -3.15 + i * 0.34
		atelier.c(Vector3(x, 1.52, -7), 0.065, 0.5, "laiton")
		atelier.c(Vector3(x, 1.75, -6.92), 0.065, 0.2, "laiton", Vector3(PI / 2, 0, 0))
		atelier.c(Vector3(x, 1.82, -7.04), 0.06, 0.22, "vert" if i % 2 else "bois")
	for i in 6: atelier.verre(Vector3(-3.2 + i * 0.36, 1.25, -6.58), i % 2 == 0)
	# Machine espresso, tasses, plateau et caisse : objets à taille de main.
	atelier.b(Vector3(3.7, 1.55, -11.2), Vector3(1.1, 0.54, 0.55), "chrome")
	atelier.b(Vector3(3.7, 1.53, -10.91), Vector3(0.87, 0.29, 0.035), "acier")
	for x in [3.45, 3.83]:
		atelier.c(Vector3(x, 1.43, -10.82), 0.07, 0.25, "chrome")
		atelier.c(Vector3(x, 1.35, -10.77), 0.14, 0.12, "creme")
	atelier.b(Vector3(3.3, 1.38, -6.97), Vector3(0.48, 0.28, 0.42), "acier")
	atelier.b(Vector3(3.3, 1.57, -6.94), Vector3(0.43, 0.09, 0.29), "ecran", Vector3(-0.35, 0, 0))
	# Gantry des écrans : menuiserie sombre, tiges, bords laiton, perforations groupées.
	atelier.b(Vector3(0, 4.98, -6.94), Vector3(14.7, 0.38, 0.5), "bois")
	atelier.b(Vector3(0, 5.17, -6.64), Vector3(14.72, 0.035, 0.04), "laiton")
	atelier.b(Vector3(0, 4.79, -6.64), Vector3(14.72, 0.035, 0.04), "laiton")
	for x in [-7.2, -2.4, 2.4, 7.2]: atelier.b(Vector3(x, 3.74, -6.94), Vector3(0.12, 2.14, 0.22), "laiton")
	for x in [-2.4, 2.4]:
		atelier.b(Vector3(x, 3.7, -6.9), Vector3(0.83, 2.05, 0.09), "cuivre")
		for i in 5:
			for j in 14: atelier.c(Vector3(x - 0.29 + i * 0.145, 2.8 + j * 0.139, -6.84), 0.065, 0.012, "plafond", Vector3(PI / 2, 0, 0))
	# Le bandeau du portique reste libre : le socle y écrit l'enseigne de la salle (ancre « Enseigne »).
	for x in [-6.8, 6.8]:
		for i in 3:
			for j in 3: atelier.c(Vector3(x + i * 0.13, 4.87 + j * 0.1, -6.665), 0.045, 0.025, "laiton", Vector3(PI / 2, 0, 0))
	for x in [-3.7, -1.6, 1.5, 3.8]:
		atelier.suspension(Vector3(x, 2.45, -9.25), 0.24, 2.59)
	for i in 8:
		var x := -4.55 + i * 1.3
		if abs(x) < 0.6: continue
		atelier.tabouret(Vector3(x, 0, -5.15), PI, 0.76)
	# Les consoles sous le triptyque d'écrans.
	for x in [-4.8, 0.0, 4.8]:
		atelier.b(Vector3(x, 0.88, -6.385), Vector3(0.71, 0.36, 0.06), "vert")
		atelier.b(Vector3(x, 0.88, -6.345), Vector3(0.64, 0.29, 0.025), "laiton")


func _lounge_et_alcoves() -> void:
	# Lounge ouest : deux salons qui regardent les écrans depuis l'intérieur de la salle.
	for z in [-5.1, 0.7]:
		atelier.banquette(Vector3(-9.2, 0, z), 3.3, -PI / 2, true)
		atelier.table_basse(Vector3(-11.15, 0, z), Vector2(1.35, 1.8))
		atelier.fauteuil(Vector3(-12.5, 0, z + 1.1), PI / 2)
		atelier.suspension(Vector3(-11.1, 3.15, z), 0.38, 1.89)
	# Alcôves est : cloisons hautes seulement sur les côtés, chemin continu x6..8.
	for z in [-3.5, 3.3, 8.8]:
		atelier.banquette(Vector3(9, 0, z), 3.3, PI / 2)
		atelier.table_basse(Vector3(10.8, 0, z), Vector2(1.65, 1.2))
		atelier.banquette(Vector3(12.45, 0, z), 3.3, -PI / 2)
		atelier.suspension(Vector3(10.8, 3.1, z), 0.38, 1.94)
	for z in [-6, 0.0, 6.1]:
		atelier.b(Vector3(11, 0.58, z), Vector3(5.4, 1.16, 0.17), "bois")
		atelier.solide(Vector3(11, 0.58, z), Vector3(5.4, 1.16, 0.17), "CloisonAlcove")
		atelier.b(Vector3(11, 1.19, z), Vector3(5.48, 0.08, 0.25), "laiton")
		for x in [8.5, 10.8, 13.4]: atelier.b(Vector3(x, 2.16, z), Vector3(0.06, 2.1, 0.06), "acier")
		atelier.b(Vector3(11, 3.2, z), Vector3(5.4, 0.065, 0.12), "acier")
		for i in 18:
			atelier.b(Vector3(8.4 + i * 0.3, 2.62, z), Vector3(0.045, 1.12, 0.04), "cuivre")
	# Hautes tables dans les îlots : l'axe de la porte au bar reste libre.
	# Deux îlots de l'original sont devenus des places de table (Table3, Table4).
	for p in [Vector3(-3.8, 0, 5), Vector3(3.8, 0, -2.5), Vector3(3.8, 0, 7.4)]:
		atelier.table_basse(p, Vector2(1.55, 1.0), 1.06)
		for dx in [-1.1, 1.1]: atelier.tabouret(p + Vector3(dx, 0, 0), -signf(dx) * PI / 2, 0.74)
		atelier.suspension(p + Vector3(0, 3.3, 0), 0.33, 1.74)
	# Salon du club au nord-est, à l'écart du service.
	atelier.banquette(Vector3(10.9, 0, -8.8), 3.3, PI, true)
	atelier.table_basse(Vector3(10.5, 0, -10.3), Vector2(1.9, 0.8))
	atelier.texte("LE SALON DU CLUB", Vector3(9.2, 4.5, -11.73), 0.0034)


func _alcove() -> void:
	# L'alcôve reste au niveau du sol, accessible sans marche ni passage étroit.
	atelier.b(Vector3(-9, 0.03, 7.3), Vector3(7.2, 0.025, 7.2), "vert")
	for x in [-12.6, -5.4]: atelier.b(Vector3(x, 0.047, 7.3), Vector3(0.035, 0.006, 7.2), "laiton")
	for z in [3.7, 10.9]: atelier.b(Vector3(-9, 0.047, z), Vector3(7.2, 0.006, 0.035), "laiton")
	atelier.b(Vector3(-10.6, 0.64, 3.5), Vector3(6.55, 1.28, 0.25), "bois")
	atelier.solide(Vector3(-10.6, 0.64, 3.5), Vector3(6.55, 1.28, 0.25), "CloisonPoker")
	atelier.b(Vector3(-10.6, 1.3, 3.5), Vector3(6.65, 0.07, 0.32), "laiton")
	for i in 14: atelier.b(Vector3(-13.6 + i * 0.46, 2.25, 3.5), Vector3(0.035, 1.85, 0.035), "acier")
	atelier.b(Vector3(-10.6, 3.2, 3.5), Vector3(6.7, 0.13, 0.2), "bois")
	atelier.b(Vector3(-8.9, 4.2, 6.9), Vector3(5.3, 0.18, 0.85), "bois")
	for x in [-10.4, -7.4]: atelier.suspension(Vector3(x, 2.5, 7.2), 0.42, 1.52)
	atelier.b(Vector3(-5.7, 1.0, 5.0), Vector3(0.12, 1.8, 1.4), "bois")
	atelier.texte("LES\nTABLES", Vector3(-5.62, 1.5, 5.0), 0.0038, PI / 2)


func _galerie_et_details() -> void:
	# Fenêtres de soirée donnant de la profondeur aux murs sans emprunter une vidéo.
	for x in [-4.25, 4.25]:
		atelier.b(Vector3(x, 2.3, 11.82), Vector3(2.3, 2.9, 0.08), "acier")
		atelier.b(Vector3(x, 2.3, 11.76), Vector3(2.1, 2.7, 0.03), "bleu")
		for dx in [-1.12, 0.0, 1.12]: atelier.b(Vector3(x + dx, 2.3, 11.70), Vector3(0.065, 2.85, 0.06), "laiton")
		for y in [0.9, 2.3, 3.7]: atelier.b(Vector3(x, y, 11.7), Vector3(2.32, 0.065, 0.06), "bois")
		atelier.b(Vector3(x, 0.81, 11.55), Vector3(2.6, 0.12, 0.5), "bois")
	# Vitrine du club : trophées et vrais maillots géométriques encadrés.
	for i in 3:
		var x := -10.5 + i * 1.7
		atelier.b(Vector3(x, 2.8, -11.79), Vector3(1.35, 1.9, 0.16), "laiton")
		atelier.b(Vector3(x, 2.8, -11.69), Vector3(1.19, 1.74, 0.04), "bleu")
		atelier.b(Vector3(x, 2.85, -11.65), Vector3(0.57, 0.84, 0.04), "creme" if i == 1 else "vert")
		for dx in [-0.41, 0.41]: atelier.b(Vector3(x + dx, 3.15, -11.64), Vector3(0.38, 0.33, 0.05), "creme" if i == 1 else "vert", Vector3(0, 0, -signf(dx) * 0.4))
		atelier.texte(["86", "10", "09"][i], Vector3(x, 2.89, -11.61), 0.0042, 0, Color("d2b574") if i != 1 else Color("234335"))
	atelier.b(Vector3(-9, 1.45, -11.45), Vector3(6.7, 0.1, 0.7), "bois")
	for x in [-11.2, -9.0, -6.8]:
		atelier.b(Vector3(x, 1.58, -11.4), Vector3(0.4, 0.18, 0.34), "pierre")
		atelier.c(Vector3(x, 1.78, -11.4), 0.09, 0.24, "laiton")
		atelier.c(Vector3(x, 2.01, -11.4), 0.4, 0.3, "laiton", Vector3(PI, 0, 0), true)
		for dx in [-0.25, 0.25]: atelier.c(Vector3(x + dx, 1.98, -11.4), 0.055, 0.27, "laiton", Vector3(0, 0, signf(dx) * 0.3))
	atelier.texte("LE CLUB", Vector3(-9, 4.22, -11.69), 0.0032)
	# Totem d'orientation près de l'entrée : trois destinations réellement présentes.
	atelier.b(Vector3(-2.6, 1.05, 8.85), Vector3(0.15, 1.8, 0.15), "acier")
	atelier.b(Vector3(-2.6, 1.85, 8.85), Vector3(1.3, 0.66, 0.12), "vert")
	atelier.texte("LES TABLES ←\nLE BAR ↑\nLE SALON ↗", Vector3(-2.6, 1.85, 8.93), 0.0022)
	# Patères, cadres de programme, haut-parleurs et livrets de tactique donnent une échelle humaine.
	for x in [-2.05, 2.05]:
		for y in [1.65, 2.1]:
			atelier.b(Vector3(x, y, 11.74), Vector3(0.06, 0.05, 0.14), "laiton")
	for x in [-6.8, 6.8]:
		atelier.b(Vector3(x, 3.9, -7), Vector3(0.42, 0.68, 0.34), "acier")
		for y in [3.75, 4.02]: atelier.c(Vector3(x, y, -6.81), 0.24, 0.02, "plafond", Vector3(PI / 2, 0, 0))
	for z in [-8.3, 8.1]:
		atelier.b(Vector3(-13.77, 2.8, z), Vector3(0.12, 1.65, 1.0), "laiton")
		atelier.b(Vector3(-13.69, 2.8, z), Vector3(0.03, 1.49, 0.84), "vert")
		atelier.texte("À DOMICILE\nDEPUIS\nTOUJOURS", Vector3(-13.65, 2.8, z), 0.0027, PI / 2)


func _vie() -> void:
	# Habitués du lieu : animations sociales locales, sans inventer des réactions aux vrais scores.
	_personne("LoungeA", Vector3(-9.2, 0, -5.7), -PI / 2, 510, true, 0.58, "sit", "drink")
	_personne("LoungeB", Vector3(-9.2, 0, -4.4), -PI / 2, 511, true, 0.58, "sit", "nod")
	_personne("LoungeC", Vector3(-9.2, 0, 0.5), -PI / 2, 512, true, 0.58, "sit", "talk")
	_personne("AlcoveA", Vector3(9, 0, -3.6), PI / 2, 516, true, 0.58, "sit", "point")
	_personne("AlcoveB", Vector3(12.45, 0, -3.0), -PI / 2, 517, true, 0.58, "sit", "nod")
	_personne("AlcoveC", Vector3(9, 0, 3.3), PI / 2, 518, true, 0.58, "sit", "drink")
	_personne("SalonA", Vector3(10.1, 0, -8.8), PI, 519, true, 0.58, "sit", "talk")
	_personne("ComptoirA", Vector3(-3.25, 0, -5.15), PI, 527, true, 0.83, "sit_table", "drink")
	_personne("DeboutTable", Vector3(-2.6, 0, 5), -PI / 2, 530, false, 0, "stand_table", "talk")
	# Un serveur suit une courte trajectoire entièrement derrière le comptoir.
	_serveur = _personne("ServiceArriereBar", Vector3(-3.5, 0, -9.4), 0, 532, false, 0, "bar", "nod")


func _personne(nom: String, p: Vector3, angle: float, graine: int, assis: bool, assise: float, repos: String, geste: String) -> Node3D:
	var c := CRITTER.new()
	c.name = nom
	c.randomize_look(graine)
	# La même distribution Smarves, habillée pour ce lieu ; aucune mutation du catalogue Cast.
	c.look = c.look.duplicate(true)
	c.look.top_color = ["#435c50", "#3b4452", "#78524b", "#c0b399", "#67404b", "#303c38"][graine % 6]
	c.look.legs_color = "#34373b"
	c.look.apron = false
	if nom == "ServiceArriereBar":
		c.look.top = "chemise"
		c.look.top_color = "#d8ccb0"
		c.look.apron = true
		c.look.apron_bib = true
		c.look.apron_color = "#233c33"
		c.look.hat = ""
	c.idle_anim = repos
	c.sit_anim = repos
	c.scale = Vector3.ONE * PEOPLE_SCALE
	c.position = p
	c.rotation.y = angle
	add_child(c)
	if assis:
		c.pose = 2
		# Le socle calcule la hauteur de bassin selon le personnage : on pose ce bassin sur l'assise.
		c.position.y = assise - float(c.get("_seat")) * PEOPLE_SCALE + 0.045
	_habitués.append({"personnage": c, "attente": 4.0 + (graine % 9), "geste": geste, "periode": 11.0 + (graine % 7)})
	return c


## Les écrans du bar : une coque, une dalle sombre au bandeau de couleur, et une séquence de football dessinée
## qui tourne en boucle (animation_football.gd), sans rencontre ni score réels. Les dix places de l'original.
func _ecrans() -> void:
	var places := [
		[Vector3(-4.8, 3.7, -6.8), 0.0, 1.05, 0], [Vector3(0, 3.7, -6.8), 0.0, 1.05, 1], [Vector3(4.8, 3.7, -6.8), 0.0, 1.05, 2],
		[Vector3(-13.72, 2.9, -4), PI / 2, 1.0, 0], [Vector3(-13.72, 2.9, 1), PI / 2, 1.0, 1],
		[Vector3(13.72, 2.9, -2.4), -PI / 2, 1.0, 2], [Vector3(13.72, 2.9, 4.5), -PI / 2, 1.0, 0],
		[Vector3(-8.8, 2.95, 11.65), PI, 0.9, 1], [Vector3(8.8, 2.95, 11.65), PI, 0.9, 2], [Vector3(9.2, 3, -11.65), 0.0, 1.15, 0]]
	for i in places.size():
		var e := Node3D.new()
		e.name = "Ecran%d" % (i + 1)
		e.position = places[i][0]
		e.rotation.y = places[i][1]
		e.scale = Vector3.ONE * places[i][2]
		add_child(e)
		var palette: Array = PALETTES[places[i][3]]
		_dalle(e, Vector3.ZERO, Vector3(3.44, 2.04, 0.18), Color("161c1c"), 0.0)
		_dalle(e, Vector3(0, 0, 0.094), Vector3(3.20, 1.80, 0.008), palette[0], 0.25)
		_dalle(e, Vector3(0, 0.738, 0.101), Vector3(3.20, 0.324, 0.003), palette[1], 0.6)
		_dalle(e, Vector3(0, -0.70, 0.101), Vector3(3.0, 0.22, 0.003), palette[1], 0.35)
		var animation: Node3D = ANIMATION.new()
		e.add_child(animation)
		animation.construire("ecran%d" % i, palette[2], palette[3], i)


func _dalle(parent: Node3D, p: Vector3, taille: Vector3, couleur: Color, lueur: float) -> void:
	var m := MeshInstance3D.new()
	var boite := BoxMesh.new()
	boite.size = taille
	m.mesh = boite
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	mat.roughness = 0.6
	if lueur > 0.0:
		mat.emission_enabled = true
		mat.emission = couleur
		mat.emission_energy_multiplier = lueur
	m.material_override = mat
	m.position = p
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)


func _process(delta: float) -> void:
	for habitue: Dictionary in _habitués:
		habitue.attente -= delta
		if habitue.attente <= 0.0:
			habitue.attente = habitue.periode
			var c: Node3D = habitue.personnage
			if is_instance_valid(c): c.gesture(habitue.geste)
	if is_instance_valid(_serveur):
		_service_t += delta
		# Service posé : marche 4s, pause 8s, retour 4s, pause 8s.
		var t := fmod(_service_t, 24.0)
		var x := -3.5
		if t < 4.0:
			x = lerpf(-3.5, -1.2, t / 4.0)
			_serveur.pose = 1
			_serveur.rotation.y = PI / 2
		elif t < 12.0:
			x = -1.2
			_serveur.pose = 0
			_serveur.rotation.y = PI
		elif t < 16.0:
			x = lerpf(-1.2, -3.5, (t - 12.0) / 4.0)
			_serveur.pose = 1
			_serveur.rotation.y = -PI / 2
		else:
			_serveur.pose = 0
			_serveur.rotation.y = 0
		_serveur.position.x = x
