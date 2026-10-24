extends Node
## Le chronomètre du démarrage (outil de mesure, jamais dans le jeu) : placé en tête des autoloads par
## mesurer.sh, il note l'heure de chaque étape depuis le lancement du moteur, et la mémoire du processus.
##   --mesure=titre    : jusqu'à la première image de l'écran titre, puis « Jouer » jusqu'à la place.
##   --mesure=carnet   : scène vide (vide.tscn, sans village), puis le carnet ouvert et affiché, puis
##                       le bureau du club (composer l'équipe), les offres et le notaire par téléphone,
##                       par-dessus le carnet.
##   --mesure=trajets  : « Jouer », puis la distance à pied de l'arrivée sur la place aux portes des
##                       gestes courants, et le chargement de chacun des lieux (notaire, stade, casino).
## Les résultats s'impriment (« CHRONO ») et s'écrivent dans user://mesure_demarrage.json.
## Aucun nom d'autoload ni de classe du jeu ici (get_node seulement) : sinon le chronomètre compilerait
## lui-même les scripts du jeu avant de naître, et la mesure ne saurait plus ce qui coûte.

var _etapes: Array = []
var _arbre: SceneTree
var _scenes := 0


func _init() -> void:
	marquer("chrono (premier autoload créé)")
	_arbre = Engine.get_main_loop() as SceneTree
	_arbre.node_added.connect(_noeud_ajoute)


func _mode() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mesure="):
			return a.trim_prefix("--mesure=")
	return "titre"


func marquer(etape: String) -> void:
	var ms := Time.get_ticks_usec() / 1000.0
	var rss := _rss_mo()
	# Ce que la dernière image a demandé à la carte graphique (zéro sans écran).
	var appels := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var video := snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)
	_etapes.append({"etape": etape, "ms": snappedf(ms, 0.1), "rss_mo": rss, "appels_de_dessin": appels,
		"video_mo": video, "statique_mo": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1)})
	print("CHRONO %8.1f ms  %6.1f Mo  %5d appels  %6.1f Mo vidéo  %s" % [ms, rss, appels, video, etape])


## La mémoire résidente du processus (Linux et Android lisent tous deux /proc).
func _rss_mo() -> float:
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f == null:
		return -1.0
	while not f.eof_reached():
		var l := f.get_line()
		if l.begins_with("VmRSS:"):
			return snappedf(float(l.split(":")[1].strip_edges().split(" ")[0]) / 1024.0, 0.1)
	return -1.0


## Les autoloads entrent dans l'arbre ensemble, puis chacun fait son _ready dans l'ordre : l'écart entre
## deux « prêt » est le prix du _ready du second.
func _noeud_ajoute(n: Node) -> void:
	if n == self or n.get_parent() != _arbre.root:
		return
	if ProjectSettings.has_setting("autoload/" + str(n.name)):
		n.ready.connect(func(): marquer("prêt : " + str(n.name)), CONNECT_ONE_SHOT)
		return
	marquer("scène ajoutée : " + str(n.name))
	_scenes += 1
	if _scenes == 1:
		n.ready.connect(func(): _scene_prete(n), CONNECT_ONE_SHOT)
	else:
		n.ready.connect(func(): marquer("scène prête (_ready) : " + str(n.name)), CONNECT_ONE_SHOT)


## Une image dessinée ; sans écran (--headless), rien ne se dessine : une image traitée en tient lieu.
func _image() -> void:
	if DisplayServer.get_name() == "headless":
		await _arbre.process_frame
	else:
		await RenderingServer.frame_post_draw


func _scene_prete(scene: Node) -> void:
	marquer("scène principale prête (_ready) : " + str(scene.name))
	await _image()
	marquer("première image dessinée")
	for i in 5:
		await _image()
	marquer("cinquième image suivante dessinée")
	if _mode() == "carnet":
		await _carnet()
	elif scene.name == "Titre":
		await _jouer(scene)
		if _mode() == "trajets":
			await _trajets()
	_finir()


func _jouer(titre: Node) -> void:
	await get_tree().create_timer(1.0).timeout
	marquer("« Jouer » appuyé")
	titre.call("jouer" if titre.has_method("jouer") else "_play")
	await _image()
	marquer("place : première image dessinée")
	for i in 5:
		await _image()
	marquer("place : cinquième image suivante dessinée")


func _carnet() -> void:
	var carnet: Node = get_node("/root/Carnet")
	marquer("carnet : ouverture demandée")
	carnet.toggle()
	await _image()
	marquer("carnet : première image dessinée")
	await _image()
	var club := _un_club()
	if club == "":
		marquer("carnet : aucun club de football pour le bureau")
		return
	marquer("bureau du club (" + club + ") : ouverture demandée")
	carnet.gerer("foot", club, "tactique")
	await _image()
	marquer("bureau du club : première image dessinée")
	carnet.fermer_gestion()
	await _image()
	carnet.gerer("foot", club, "offres")
	await _image()
	marquer("offres de transfert : première image dessinée")
	carnet.fermer_gestion()
	await _image()
	marquer("notaire par téléphone : ouverture demandée")
	carnet.notaire("football", club)
	await _image()
	marquer("notaire par téléphone : première image dessinée")


## Depuis l'arrivée sur la place : la porte de chaque geste, à vol d'oiseau (le trajet réel est plus long),
## au pas de l'habitant ; puis le chargement de chaque lieu, jusqu'à sa première image.
func _trajets() -> void:
	var place: Node = get_tree().current_scene
	var village: Node = place.get_node("Village")
	var depart: Vector3 = place.player.global_position
	var pas: float = place.player.speed
	var portes := {}
	for id in ["notaire", "stade", "casino", "cafe", "bourse"]:
		if village.has_door(id):
			portes[id] = village.lots[id].door
	portes["cafe"] = village.SALLES.cafe[0]
	portes["arret du car (salle de basket)"] = village.ARRET[0]
	for id in portes:
		var d: float = Vector2(depart.x, depart.z).distance_to(Vector2(portes[id].x, portes[id].z))
		marquer("porte %s : %.1f m à vol d'oiseau, %.1f s au pas (%.1f m/s)" % [id, d, d / pas, pas])
	var club := _un_club()
	for lieu in [["étude du notaire", func(): get_node("/root/Chargement").lieu("res://scenes/notaire.tscn")],
			["stade (" + club + ")", func(): load("res://scripts/village/stade.gd").ouvrir_sur(club, "")],
			["casino", func(): get_node("/root/Chargement").lieu("res://scenes/casino.tscn")]]:
		await _charger(lieu[0], lieu[1])
		var s: Node = get_tree().current_scene
		if lieu[0] == "casino" and s.get("player") != null:
			var p: Vector3 = s.player.global_position
			var d := Vector2(p.x, p.z).distance_to(Vector2(0.0, 2.6)) - 2.0
			marquer("casino : table du Miosson à %.1f m de l'entrée, %.1f s au pas" % [d, d / float(s.player.speed)])
		await _charger("retour sur la place", func(): get_node("/root/Chargement").lieu("res://scenes/main.tscn"))


func _charger(nom: String, action: Callable) -> void:
	var avant: Node = get_tree().current_scene
	marquer(nom + " : demandé")
	action.call()
	while get_tree().current_scene == avant or get_tree().current_scene == null or not get_tree().current_scene.is_node_ready():
		await _arbre.process_frame
	await _image()
	marquer(nom + " : première image dessinée (" + str(get_tree().current_scene.name) + ")")


func _un_club() -> String:
	var clubs: Dictionary = get_node("/root/Football").clubs
	return "" if clubs.is_empty() else str(clubs.keys()[0])


func _finir() -> void:
	marquer("fin")
	var f := FileAccess.open("user://mesure_demarrage.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"mode": _mode(), "moteur": Engine.get_version_info().string,
			"rendu": RenderingServer.get_current_rendering_method(), "etapes": _etapes}, "\t"))
	# Le jeu ne rend pas toujours la main à quit() sans écran (un fil réseau qui attend) : la mesure est
	# écrite, le processus s'arrête net, sans rien sauvegarder.
	OS.kill(OS.get_process_id())
