extends RefCounted
## Les figurants de Casino Minuit, sur le modèle du jeu web (js/npc.js, assets/manifest.json) : les
## personnages Quaternius (CC0) du jeu, habillés par rôle de teintes par matériau, avec leurs clips et ceux
## des fichiers d'animations « extra », reciblés sur leur squelette. Deux familles d'ossature :
## - human31 (man-*, woman-*) : onze clips embarqués, plus human31-extra (parler, boire, s'accouder…) ;
## - character62 (croupiers, real-*) : les clips des deux croupiers, plus real62-extra.
## Les modèles regardent vers +z ; un figurant regarde vers -z, comme un nœud Godot (look_at).

const DOSSIER := "res://communes/casino_minuit/personnages/"
## L'échelle qui met chaque ossature à sa taille en mètres (manifest.rigs.*.scaleToMeters).
const ECHELLE := {"human31": 0.3641, "character62": 0.9722}

## Les modèles et leur ossature.
const MODELES := {
	"man-suit": "human31", "man-longsleeves": "human31", "man-tshirt": "human31", "man-blond": "human31",
	"woman-casual": "human31", "woman-dress": "human31", "woman-tanktop": "human31", "woman-punk": "human31",
	"dealer-businessman": "character62", "dealer-woman-green": "character62", "real-swat": "character62",
	"real-worker": "character62", "real-casual-man": "character62", "real-casual-woman": "character62",
	"real-hoodie-man": "character62", "real-punk-man": "character62", "real-punk-woman": "character62",
}

## Les gestes, par ossature et par sexe : le nom du clip (embarqué, ou d'un fichier extra).
const GESTES := {
	"human31-man": {"idle": "HumanArmature|Man_Idle", "walk": "HumanArmature|Man_Walk", "sit": "HumanArmature|Man_Sitting",
		"clap": "HumanArmature|Man_Clapping", "talk": "UAL_Talk", "drink": "UAL_Consume", "phone": "UAL_Phone",
		"wave": "C62_Wave", "lean": "UAL_Lean_Rail", "arms": "UAL_FoldArms", "yes": "UAL_Yes", "sit_talk": "UAL_Sit_Talk", "interact": "UAL_Interact"},
	"human31-woman": {"idle": "HumanArmature|Female_Idle", "walk": "HumanArmature|Female_Walk", "sit": "HumanArmature|Female_Sitting",
		"clap": "HumanArmature|Female_Clapping", "talk": "UAL_Talk", "drink": "UAL_Consume", "phone": "UAL_Phone",
		"wave": "C62_Wave", "lean": "UAL_Lean_Rail", "arms": "UAL_FoldArms", "yes": "UAL_Yes", "sit_talk": "UAL_Sit_Talk", "interact": "UAL_Interact"},
	"character62": {"idle": "CharacterArmature|Idle", "walk": "CharacterArmature|Walk", "sit": "UAL_Sit_Idle",
		"clap": "CharacterArmature|Wave", "talk": "UAL_Talk", "drink": "UAL_Consume", "phone": "UAL_Phone",
		"wave": "CharacterArmature|Wave", "lean": "UAL_Lean_Rail", "arms": "UAL_FoldArms", "yes": "UAL_Yes", "sit_talk": "UAL_Sit_Talk", "interact": "CharacterArmature|Interact"},
}

## Les tenues par rôle : [modèle, teintes par matériau] (LOOKS de npc.js, et manifest.roles).
const TENUES := {
	"croupier": [["dealer-businessman", {}], ["dealer-woman-green", {}], ["dealer-businessman", {"Suit": "#3a1220", "Tie": "#101010"}], ["dealer-woman-green", {"LimeGreen": "#6e1423"}]],
	"barman": [["dealer-businessman", {"Suit": "#2b2b33", "Tie": "#7a1420"}], ["dealer-woman-green", {"LimeGreen": "#23232a", "Gold": "#d9a441"}]],
	"vigile": [["dealer-businessman", {"Suit": "#15171a", "Tie": "#15171a", "White": "#e8e8e8"}], ["man-suit", {}], ["dealer-businessman", {"Suit": "#15171a", "Tie": "#15171a", "White": "#e8e8e8", "Skin": "#7a5a3c", "Hair": "#0f0d0c"}]],
	"serveur": [["dealer-businessman", {"Suit": "#f2f0ea", "Tie": "#101010", "Black": "#17181b"}], ["dealer-woman-green", {"LimeGreen": "#17181b", "Gold": "#e8e8e8"}]],
	"hotesse": [["dealer-woman-green", {"LimeGreen": "#1f3a5f", "Gold": "#d9a441"}], ["woman-dress", {"Dress": "#1f2c44"}]],
	# Le personnel des coulisses (lot D) : vestes blanches de cuisine, plongeurs en bleu de travail, agents de
	# sécurité en costume marine, compteurs en blouse verte, livreurs, employés en civil ou en uniforme bordeaux.
	"cuisinier": [["dealer-businessman", {"Suit": "#f2f0ea", "Tie": "#f2f0ea", "Black": "#e8e8e8"}], ["dealer-woman-green", {"LimeGreen": "#f2f0ea", "Gold": "#e8e8e8"}]],
	"plongeur": [["real-worker", {"Worker_Yellow": "#2c4a72", "Worker_Vest": "#3d5f8c", "Brown2": "#23324a"}]],
	"agent": [["dealer-businessman", {"Suit": "#1c2740", "Tie": "#1c2740", "White": "#dfe4ea"}], ["dealer-woman-green", {"LimeGreen": "#1c2740", "Gold": "#dfe4ea"}],
		["dealer-businessman", {"Suit": "#1c2740", "Tie": "#1c2740", "White": "#dfe4ea", "Skin": "#7a5a3c", "Hair": "#0f0d0c"}]],
	"compteur": [["dealer-businessman", {"Suit": "#2f5d50", "Tie": "#1b1b20"}], ["dealer-woman-green", {"LimeGreen": "#2f5d50", "Gold": "#cfcfd6"}]],
	"livreur": [["real-worker", {}], ["real-worker", {"Worker_Vest": "#d4622a", "Skin": "#7a5a3c"}]],
	"employe": [["real-casual-man", {}], ["real-casual-woman", {}], ["real-hoodie-man", {}], ["dealer-businessman", {"Suit": "#6e1423", "Tie": "#101010"}],
		["dealer-woman-green", {"LimeGreen": "#6e1423", "Gold": "#d9a441"}]],
	# Dehors (lot E) : les portiers en redingote rouge et or, les voituriers en gilet noir ; au lot F, l'arbitre en
	# chemise blanche, les boxeurs (les couleurs de leur coin), les musiciens et les techniciens en noir.
	"portier": [["dealer-businessman", {"Suit": "#8a1020", "Tie": "#d9a441", "White": "#f2ead7"}], ["dealer-woman-green", {"LimeGreen": "#8a1020", "Gold": "#d9a441"}]],
	"voiturier": [["dealer-businessman", {"Suit": "#17181b", "Tie": "#8a1020", "White": "#f2f0ea"}], ["dealer-businessman", {"Suit": "#17181b", "Tie": "#8a1020", "White": "#f2f0ea", "Skin": "#7a5a3c", "Hair": "#0f0d0c"}]],
	"arbitre": [["dealer-businessman", {"Suit": "#f2f0ea", "Tie": "#101010", "Black": "#101010"}]],
	"boxeur_rouge": [["real-worker", {"Worker_Yellow": "#b3121f", "Worker_Vest": "#b3121f", "Brown2": "#b3121f"}]],
	"boxeur_bleu": [["real-worker", {"Worker_Yellow": "#1d3f8a", "Worker_Vest": "#1d3f8a", "Brown2": "#1d3f8a", "Skin": "#7a5a3c"}]],
	"musicien": [["real-punk-man", {}], ["real-punk-woman", {}], ["real-hoodie-man", {}], ["woman-punk", {}]],
	"technicien": [["real-hoodie-man", {"Black": "#17181b"}], ["real-casual-woman", {}]],
	"client": [["man-longsleeves", {}], ["man-tshirt", {}], ["man-blond", {}], ["woman-casual", {}], ["woman-dress", {}], ["woman-tanktop", {}],
		["woman-punk", {}], ["real-casual-man", {}], ["real-hoodie-man", {}], ["real-punk-man", {}], ["real-punk-woman", {}], ["real-casual-woman", {}], ["man-suit", {}]],
}
## Les teintes tirées pour les clients (npc.js : TOPS, BOTTOMS), sur les matériaux qui s'y prêtent.
const HAUTS := ["#7a1f2b", "#1f3a5f", "#2f5d50", "#c9a24a", "#e8e2d0", "#4a2d5e", "#24242a", "#b5482f", "#3c6e8f", "#cfcfd6", "#8c2f5a", "#5b6b2e", "#1d6a72", "#d98a9a"]
const BAS := ["#1b1b20", "#23283a", "#3a2f28", "#4b4b52", "#1d2b24", "#2c2230", "#6b6257", "#2a3550", "#54463a"]
const MAT_HAUT := ["Shirt", "Shirt2", "Dress", "Jacket", "LightJacket", "Suit", "LimeGreen", "Purple", "Orange", "LightBrown"]
const MAT_BAS := ["Pants", "LightBlue"]

## Les bibliothèques de clips, une par ossature et par sexe, construites une fois.
static var _bibliotheques := {}
static var _scenes := {}


## Un figurant du rôle donné ; graine choisit sa tenue (et ses teintes, pour un client).
static func figurant(role: String, graine: int) -> Node3D:
	var h := RandomNumberGenerator.new()
	h.seed = hash("minuit/%s/%d" % [role, graine])
	var tenues: Array = TENUES[role]
	var t: Array = tenues[h.randi() % tenues.size()]
	var teintes: Dictionary = (t[1] as Dictionary).duplicate()
	if role == "client":
		var haut: String = HAUTS[h.randi() % HAUTS.size()]
		var bas: String = BAS[h.randi() % BAS.size()]
		for m in MAT_HAUT:
			teintes[m] = haut
		for m in MAT_BAS:
			teintes[m] = bas
	return faire(t[0], teintes)


## Un figurant d'un modèle, aux teintes données ({matériau: couleur} ; « Skin* » : facteur de la peau).
static func faire(modele: String, teintes := {}) -> Node3D:
	var os: String = MODELES[modele]
	var cle := os + ("-woman" if modele.begins_with("woman") or modele.ends_with("-woman") or modele == "dealer-woman-green" else "-man") if os == "human31" else os
	var f := Figurant.new()
	f.name = modele
	f.gestes = GESTES[cle]
	var m: Node3D = _scene(modele).instantiate()
	m.scale = Vector3.ONE * ECHELLE[os]
	m.rotation.y = PI
	f.add_child(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat and teintes.has(mat.resource_name) and mat is BaseMaterial3D:
				var t := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				t.albedo_color = Color(teintes[mat.resource_name])
				t.albedo_texture = null
				(mi as MeshInstance3D).set_surface_override_material(s, t)
			elif mat and teintes.has("Skin*") and mat.resource_name.begins_with("Skin") and mat is BaseMaterial3D:
				# la peau assombrie ou éclaircie d'un facteur, en linéaire (clientTint : skin)
				var t := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				var k := float(teintes["Skin*"])
				var c := t.albedo_color.srgb_to_linear()
				t.albedo_color = Color(c.r * k, c.g * k, c.b * k, c.a).linear_to_srgb()
				(mi as MeshInstance3D).set_surface_override_material(s, t)
	var ap: AnimationPlayer = m.find_child("AnimationPlayer", false, false)
	if ap == null:
		ap = AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		m.add_child(ap)
	for l in ap.get_animation_library_list():
		ap.remove_animation_library(l)
	ap.add_animation_library("", _bibliotheque(cle, modele))
	f.joueur = ap
	return f


static func _scene(modele: String) -> PackedScene:
	if not _scenes.has(modele):
		_scenes[modele] = load(DOSSIER + modele + ".glb")
	return _scenes[modele]


## La bibliothèque d'une ossature : ses clips embarqués et ceux du fichier extra, reciblés sur le squelette.
static func _bibliotheque(cle: String, modele: String) -> AnimationLibrary:
	if _bibliotheques.has(cle):
		return _bibliotheques[cle]
	var lib := AnimationLibrary.new()
	var source := modele if cle.begins_with("human31") else "dealer-businessman"
	var armature := "HumanArmature" if cle.begins_with("human31") else "CharacterArmature"
	var propre: Node = _scene(source).instantiate()
	var ap: AnimationPlayer = propre.find_child("AnimationPlayer", false, false)
	var sk: Skeleton3D = propre.find_child("Skeleton3D", true, false)
	for n in ap.get_animation_list():
		lib.add_animation(n, ap.get_animation(n))
	var extra: Node = _scene("human31-extra" if cle.begins_with("human31") else "real62-extra").instantiate()
	var ape: AnimationPlayer = extra.find_child("AnimationPlayer", false, false)
	for n in ape.get_animation_list():
		if lib.has_animation(n):
			continue
		lib.add_animation(n, _recibler(ape.get_animation(n), sk, armature))
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		a.loop_mode = Animation.LOOP_LINEAR if not n.ends_with("Death") else Animation.LOOP_NONE
	propre.free()
	extra.free()
	_bibliotheques[cle] = lib
	return lib


## Un clip d'un fichier extra (os en nœuds « RootNode/Armature/Root/Body/… ») rendu au squelette
## (« RootNode/Armature/Skeleton3D:Body ») ; les noms Godot « UpperLeg_L » redeviennent « UpperLeg.L ».
static func _recibler(a: Animation, sk: Skeleton3D, armature: String) -> Animation:
	var b := a.duplicate(true) as Animation
	for i in range(b.get_track_count() - 1, -1, -1):
		var chemin := str(b.track_get_path(i))
		var os := chemin.get_slice(":", 0).get_file()
		var nom := os
		if sk.find_bone(nom) < 0 and (nom.ends_with("_L") or nom.ends_with("_R")):
			nom = nom.left(-2) + "." + nom.right(1)
		if sk.find_bone(nom) < 0:
			b.remove_track(i)
			continue
		b.track_set_path(i, NodePath("RootNode/%s/Skeleton3D:%s" % [armature, nom]))
	return b


## Un figurant : il joue un geste, va vers un point, suit un circuit.
class Figurant extends Node3D:
	var gestes := {}
	var joueur: AnimationPlayer
	var geste_courant := ""
	## Le circuit : des points (Vector3), parcourus en boucle ; pauses : secondes d'arrêt à chaque point.
	var circuit: Array = []
	var vitesse := 1.2
	var pause := 0.0
	var _i := 0
	var _attente := 0.0
	var _geste_arret := "idle"

	func _ready() -> void:
		if geste_courant == "":
			jouer("idle")

	## Joue un geste (« idle », « walk », « sit », « talk »…), d'un fondu ; décale le départ pour que
	## deux figurants voisins ne bougent pas ensemble.
	func jouer(g: String, decalage := -1.0) -> void:
		var clip: String = gestes.get(g, gestes.idle)
		if not joueur.has_animation(clip):
			clip = gestes.idle
		if geste_courant == g and joueur.is_playing():
			return
		geste_courant = g
		joueur.play(clip, 0.3)
		var d := decalage if decalage >= 0.0 else fmod(absf(position.x * 3.1 + position.z * 1.7), 1.0)
		joueur.seek(joueur.current_animation_length * d, true)

	## Regarde vers un point (à l'horizontale).
	func regarder(p: Vector3) -> void:
		var d := Vector3(p.x - position.x, 0, p.z - position.z)
		if d.length() > 0.01:
			rotation.y = atan2(-d.x, -d.z)

	## Suit un circuit en boucle, à partir du point i ; s'arrête pause secondes à chaque point, avec ce geste.
	func suivre(points: Array, depart := 0, vit := 1.2, arret := 0.0, geste_arret := "idle") -> void:
		circuit = points
		vitesse = vit
		pause = arret
		_geste_arret = geste_arret
		_i = depart % points.size()
		position = points[_i]
		_i = (_i + 1) % points.size()
		jouer("walk")

	func _process(dt: float) -> void:
		if circuit.is_empty():
			return
		if _attente > 0.0:
			_attente -= dt
			if _attente <= 0.0:
				jouer("walk")
			return
		var cible: Vector3 = circuit[_i]
		var d := cible - position
		var pas := vitesse * dt
		if d.length() <= pas:
			position = cible
			_i = (_i + 1) % circuit.size()
			if pause > 0.0:
				_attente = pause
				jouer(_geste_arret)
			return
		position += d.normalized() * pas
		regarder(cible)
