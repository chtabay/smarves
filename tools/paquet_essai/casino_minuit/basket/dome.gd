extends "res://scripts/village/salle_basket.gd"
## Le Dôme de Minuit, où jouent les Noctambules de Minuit (structure « gymnase » du manifeste) : la salle de
## basket du socle (scripts/village/salle_basket.gd), habillée pour le Strip. Le club, le sigle, les couleurs
## et le nom viennent de la structure, comme partout ; ce script ne change que ce qui était du Clain : la statue
## du parvis (le Grand-Duc, un hibou de néon sur une pile de jetons), la mascotte, les échoppes de la coursive,
## le parking du voiturier, le président, et l'arrêt du car devenu une station de taxis. On y arrive en taxi
## depuis la porte-cochère du casino, on en repart en taxi : le casino, le stade de la Fortune ou l'aéroport.

const BASE := "res://communes/casino_minuit/"
const TAXI := BASE + "stade/taxi.gd"
const COMMUNE := "casino_minuit"
## Le point de retour que minuit.gd lit pour poser le visiteur sous la porte-cochère.
const RETOUR := "dome"

## Les échoppes de la coursive, aux mêmes places que celles du socle (même ordre).
const ECHOPPES_STRIP := [
	["LA BOUTIQUE DES NOCTAMBULES", "club", "« Le maillot violet, cent vingt crédits. Le flocage en néon est en supplément, et il clignote. »"],
	["HOT-DOGS DU STRIP", "#d8432a", "« Le hot-dog d'un pied de long, chili et cheddar. On le mange avec les deux mains. »"],
	["PIZZA DES ENCHÈRES", "#2e8b57", "« La part est à un crédit. La pizza entière se gagne à la roue, au comptoir. »"],
	["LE BAR DES NOCTAMBULES", "club", "« Le cocktail du match : il change de couleur à chaque panier à trois points. »"],
	["GLACES DU DÉSERT", "#e58fb1", "« Pistache du Nevada ou crème brûlée. Il fait quarante degrés dehors, prenez deux boules. »"],
	["SOUVENIRS DU DÔME", "club", "« La figurine du Grand-Duc, le jeton souvenir, le ballon doré dédicacé. »"],
	["LE STEAKHOUSE DU DÔME", "#c8873a", "« Une côte de bœuf pour deux, servie à votre loge entre deux quarts-temps. »"],
	["LE CLUB DES INSOMNIAQUES", "club", "« Les supporters du dernier rang. On ne se couche pas avant la fin du dernier quart. »"],
	["POPCORN & NACHOS", "#e9b929", "« Popcorn au caramel ou au piment. Le seau géant se remplit à volonté. »"],
	["MAILLOTS & PAILLETTES", "club", "« Votre nom au dos, en strass. Dix minutes, et vous brillez sous les projecteurs. »"],
	["LE COMPTOIR DES PARIS", "#7b2d3b", "« Le score à la mi-temps, le meilleur marqueur, le premier dunk. Les cotes sont au mur. »"],
	["LE STAND DE TIRS", "#3a7bd5", "« Trois ballons, un crédit. Le panier du milieu fait sonner le jackpot. »"],
]


## Le Grand-Duc, en statue de huit mètres au milieu du parvis : un hibou de néon aux couleurs du club, perché
## sur une pile de jetons géants, les yeux d'or allumés, un ballon sous l'aile.
func _heron_geant() -> void:
	var duc := Node3D.new()
	duc.position = Vector3(-14.0, 0, FACADE_Z + 16.0)
	duc.rotation.y = deg_to_rad(-150.0)
	duc.name = "StatueGrandDuc"
	add_child(duc)
	# La pile de jetons : cinq jetons de casino géants, aux deux couleurs du club, filetés d'or.
	var or_ := _std(Color(0.85, 0.66, 0.25), 0.25, 0.9)
	for k in 5:
		var jeton := _cyl(2.2 - k * 0.12, 0.42, Vector3(0, 0.21 + k * 0.44, 0), _std(_c1() if k % 2 == 0 else _c2().darkened(0.2), 0.4), duc)
		jeton.rotation.y = k * 0.4
		_cyl(2.24 - k * 0.12, 0.06, Vector3(0, 0.42 + k * 0.44, 0), or_, duc)
		if k == 0:
			_box(Vector3(4.6, 0.1, 4.6), Vector3(0, 0.05, 0), _std(Color(0.06, 0.05, 0.08), 0.3), true, duc)
	var haut := 2.2
	# Le corps : un œuf de plumes sombres, le ventre au néon du club.
	var plumes := _std(_c1().lightened(0.25), 0.55)
	var corps := _sphere(1.5, Vector3(0, haut + 2.0, 0), plumes, duc)
	corps.scale = Vector3(1.0, 1.35, 0.9)
	var ventre := _sphere(1.05, Vector3(0, haut + 1.8, 0.62), _neon(_c2(), 1.2), duc)
	ventre.scale = Vector3(1.0, 1.3, 0.5)
	# La tête, ses aigrettes, ses grands yeux d'or et son bec.
	var tete := _sphere(1.15, Vector3(0, haut + 4.4, 0.1), plumes, duc)
	tete.scale = Vector3(1.15, 0.95, 1.0)
	for s: float in [-1.0, 1.0]:
		var aigrette := _cyl(0.0, 1.1, Vector3(s * 0.75, haut + 5.5, 0.0), plumes, duc, 0.0)
		(aigrette.mesh as CylinderMesh).bottom_radius = 0.28
		aigrette.rotation.z = -s * 0.35
		_sphere(0.42, Vector3(s * 0.48, haut + 4.5, 0.95), _std(Color(0.95, 0.92, 0.85), 0.4), duc)
		_sphere(0.24, Vector3(s * 0.48, haut + 4.5, 1.28), _neon(Color(1.0, 0.78, 0.2), 4.0), duc)
		var aile := _box(Vector3(0.3, 2.6, 1.8), Vector3(s * 1.45, haut + 2.0, -0.1), plumes, false, duc)
		aile.rotation.z = s * 0.18
		# Les serres, d'or, sur le jeton du haut.
		for d in 3:
			_cyl(0.07, 0.5, Vector3(s * 0.55 + (d - 1) * 0.16, haut + 0.25, 0.7), or_, duc)
	var bec := _cyl(0.0, 0.5, Vector3(0, haut + 4.15, 1.2), or_, duc, 0.0)
	(bec.mesh as CylinderMesh).bottom_radius = 0.16
	bec.rotation.x = PI * 0.6
	# Le ballon doré sous l'aile droite.
	_sphere(0.55, Vector3(1.75, haut + 1.3, 0.6), _std(Color(0.95, 0.7, 0.2), 0.3, 0.8), duc)
	var maillot := Label3D.new()
	maillot.text = _court()
	maillot.font = _serif
	maillot.font_size = 140
	maillot.pixel_size = 0.006
	maillot.modulate = Color(1, 1, 1)
	maillot.outline_size = 0
	maillot.position = Vector3(0, haut + 1.9, 1.15)
	duc.add_child(maillot)
	var plaque := Label3D.new()
	plaque.text = "LE GRAND-DUC"
	plaque.font = _serif
	plaque.font_size = 60
	plaque.pixel_size = 0.005
	plaque.modulate = _c2()
	plaque.outline_size = 0
	plaque.position = Vector3(0, 1.0, 2.25)
	duc.add_child(plaque)
	_lamp(duc.position + Vector3(0, 1.8, 0) + duc.basis * Vector3(0, 0, 3.5), _c2().lightened(0.3), 4.0, 14.0)


## La station de taxis du Strip, au bout du tapis rouge : le damier jaune et noir, l'enseigne, l'auvent.
func _arret_du_car() -> void:
	var arret := Node3D.new()
	arret.position = Vector3(5.0, 0, ARRET_Z)
	arret.rotation.y = PI
	arret.name = "StationDeTaxis"
	add_child(arret)
	var noir := _std(Color(0.06, 0.05, 0.07), 0.4, 0.4)
	var jaune := _std(Color("#F2C12E"), 0.5)
	_box(Vector3(4.0, 0.14, 1.8), Vector3(0, 2.6, 0), noir, false, arret)
	_box(Vector3(4.0, 0.08, 0.1), Vector3(0, 2.5, 0.88), _neon(_c2(), 2.0), false, arret)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(0.1, 2.6, 0.1), Vector3(s * 1.9, 1.3, 0.8), noir, false, arret)
		_box(Vector3(0.1, 2.6, 0.1), Vector3(s * 1.9, 1.3, -0.8), noir, false, arret)
	# Le damier du bandeau, en cases jaunes et noires.
	for k in 16:
		_box(Vector3(0.25, 0.25, 0.04), Vector3(-1.875 + k * 0.25, 2.3, -0.82), jaune if k % 2 == 0 else noir, false, arret)
	_box(Vector3(2.4, 0.08, 0.4), Vector3(0, 0.5, -0.5), _std(Color(0.3, 0.1, 0.12), 0.6), false, arret)
	var nom := Label3D.new()
	nom.text = "TAXIS  ·  %s" % _enseigne(_nom_salle())
	nom.font = _serif
	nom.font_size = 40
	nom.pixel_size = 0.004
	nom.modulate = Color("#F2C12E")
	nom.outline_size = 0
	nom.position = Vector3(0, 2.75, 0.92)
	arret.add_child(nom)
	# Un taxi jaune qui attend le long du trottoir.
	var taxi := Node3D.new()
	taxi.position = arret.position + Vector3(-6.0, 0, 1.5)
	taxi.name = "TaxiQuiAttend"
	add_child(taxi)
	_box(Vector3(4.6, 0.8, 1.9), Vector3(0, 0.65, 0), jaune, true, taxi)
	_box(Vector3(2.4, 0.6, 1.7), Vector3(-0.2, 1.35, 0), _std(Color(0.12, 0.14, 0.18), 0.1, 0.4), false, taxi)
	_box(Vector3(0.7, 0.22, 0.3), Vector3(-0.2, 1.76, 0), _neon(Color(1.0, 0.92, 0.6), 1.5), false, taxi)
	for x: float in [-1.5, 1.5]:
		for z: float in [-0.95, 0.95]:
			var roue := _cyl(0.36, 0.25, Vector3(x, 0.36, z), noir, taxi)
			roue.rotation.x = PI / 2.0
	_lamp(arret.position + Vector3(0, 2.4, -0.4), Color(1.0, 0.9, 0.6), 1.4, 7.0)
	_interactive(arret, "exit", "E : prendre un taxi (le casino, le stade, l'aéroport)", Vector3(4.4, 2.6, 2.4), Vector3(0, 1.2, 0.4))


## Les échoppes du socle, aux mêmes places, aux enseignes du Strip.
func _echoppe(e: Array, i: int) -> void:
	if i < ECHOPPES_STRIP.size():
		var m: Array = ECHOPPES_STRIP[i]
		e = [m[0], e[1], e[2], e[3], m[1], m[2]]
	super(e, i)


## Le parking : celui du socle, tenu par les voituriers du Dôme.
func _parking() -> void:
	super()
	for n in find_children("*", "Label3D", true, false):
		if (n as Label3D).text == "PARKING DU GARDEN":
			(n as Label3D).text = "VOITURIERS DU DÔME"


## La mascotte : le Grand-Duc en costume, des aigrettes au lieu du bec du socle.
func _vivants() -> void:
	super()
	if _heron == null:
		return
	# Le bec du socle est le dernier posé sur la mascotte.
	var bec: Node = _heron.get_child(_heron.get_child_count() - 1) if _heron.get_child_count() > 0 else null
	if bec is MeshInstance3D and (bec as MeshInstance3D).mesh is CylinderMesh:
		bec.queue_free()
	var plumes := _std(_c1().lightened(0.25), 0.55)
	for s: float in [-1.0, 1.0]:
		var aigrette := _cyl(0.0, 0.22, Vector3(s * 0.1, 0.86, 0.0), plumes, _heron, 0.0)
		(aigrette.mesh as CylinderMesh).bottom_radius = 0.05
		aigrette.rotation.z = -s * 0.35
		_sphere(0.05, Vector3(s * 0.07, 0.7, 0.13), _neon(Color(1.0, 0.78, 0.2), 3.0), _heron)


func _on_interact(target: Node) -> void:
	match str(target.get_meta("interact", "")):
		"president":
			_dire("%s : « %s »" % [_nom_president(), [
				"Bienvenue au Dôme. Ici, le match commence à vingt heures et la fête ne finit jamais.",
				"Vingt mille places, des loges au-dessus du parquet, et le Grand-Duc qui dunke au trampoline. C'est Las Vegas.",
				"Les Hérons de Smarves sont dans notre groupe. Je leur ai envoyé une limousine pour le match aller.",
				"Mes joueurs sont de vrais joueurs d'Euroleague. Ce sont leurs notes du vendredi qui jouent le samedi.",
			].pick_random()])
			if _president.has_method("gesture"):
				_president.gesture("talk")
		"trophees":
			_dire("La vitrine est éclairée comme une table de baccara. Il n'y manque que le trophée du championnat de la Vienne.")
		_:
			super(target)


## Le taxi du Strip : le casino, le stade de la Fortune, ou l'aéroport.
func reprendre_le_car() -> void:
	load(TAXI).ouvrir(self, player, "Où va-t-on ?", [
		["Le Casino Minuit", "La porte-cochère, sur le Strip", _au_casino],
		["Le stade de la Fortune", "Le Racing Club Minuit, au bout du Strip", _au_stade],
		["L'aéroport McCarran", "Le vol MN 1203, pour Poitiers-Biard", func(): Carte.ouvrir()]])


func _au_casino() -> void:
	Game.return_point = RETOUR
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var c: Commune = Communes.commune(COMMUNE)
	get_tree().change_scene_to_file(str(c.data.scene) if c else "res://scenes/main.tscn")


func _au_stade() -> void:
	var seuil := 0
	var c: Commune = Communes.commune(COMMUNE)
	for l in (c.lieux() if c else []):
		if l.id == "stade_fortune":
			seuil = int(l.seuil)
	if Game.won < seuil:
		_dire("Le stade de la Fortune ouvre à %s crédits gagnés au jeu." % Game.fmt(seuil))
		return
	Football.ouvrir_stade(COMMUNE)
