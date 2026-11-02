extends SceneTree
## Se repérer dans Belley, sans réseau : ce qu'un pensionnaire (le pilote, scripts/socle/pilote.gd) lit en chemin.
##   godot --headless --path . -s tools/test_pilote_belley.gd [-- --depuis=res://tools/paquet_essai/belley/]
## Le paquet est rangé comme le fait tools/emballer_commune.gd, puis greffé comme chez un joueur. On pose l'habitant
## à chaque repère (places/signaletique.gd) et l'on regarde ce que dit la vue : en arrivant, le plan de la ville
## nomme la place de la Cathédrale et la route du Grand Prix ; au coin de la rue des Barons, un poteau dit d'aller
## vers l'est ; sur la place, le chevalet du Grand Prix ; à la sortie sud, le premier poteau jaune de la course ;
## là où la route du banc et celle du relais se séparent, un poteau à trois lames.

const TMP := "user://test_pilote_belley/"
const ID := "belley"

var fails := 0
var P: Node


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	create_timer(600.0).timeout.connect(func():
		print("ÉCHEC   trop long : l'essai s'arrête")
		quit(1))
	await process_frame
	var depuis := "res://tools/paquet_essai/belley/"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--depuis="):
			depuis = a.trim_prefix("--depuis=")
	if not depuis.ends_with("/"):
		depuis += "/"
	DirAccess.make_dir_recursive_absolute(TMP)
	var pck := TMP + "%s.pck" % ID
	var fichiers := {}
	_parcourir(depuis, depuis, "res://communes/%s/" % ID, fichiers)
	var pk := PCKPacker.new()
	pk.pck_start(pck)
	for cible in fichiers:
		pk.add_file(cible, fichiers[cible])
	pk.flush()

	P = root.get_node("Pilote")
	var G: Node = root.get_node("Game")
	G.saving_enabled = false
	G.welcomed = true
	var communes: Node = root.get_node("Communes")
	communes.dossier_greffes = TMP
	check(communes.charger_pack(pck) == ID, "le paquet de Belley se greffe")
	var c: Commune = communes.commune(ID)
	if c == null or not communes.ouvrir(ID):
		check(false, "le paquet s'ouvre")
		_fin()
		return
	change_scene_to_file(str(c.data.scene))
	var fin := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < fin and (current_scene == null or P.joueur() == null):
		await create_timer(0.5).timeout
	check(P.joueur() != null, "on est à Belley, l'habitant posé à l'arrivée")
	if P.joueur() == null:
		_fin()
		return
	await create_timer(2.0).timeout

	# En arrivant : le plan de la ville, à 13 m devant.
	var v: Dictionary = P.vue()
	check(_lit(v, "PLAN DE LA VILLE") != "", "en arrivant, il lit le titre du plan de la ville")
	var cath := _lit(v, "Place de la Cathédrale, arrivée du Grand Prix")
	check(cath.contains("au sud") and cath.contains("rue des Barons"), "le plan dit où est la place de la Cathédrale (%s)" % cath)
	check(_lit(v, "Route du Grand Prix : départ").contains("sortie sud"), "le plan dit où part la route de la course")
	check(_lit(v, "Au Replat").contains("Dent du Chat"), "le plan nomme le banc d'Au Replat")
	check(_vu(v, "plan de la ville"), "il voit le plan de la ville, et peut y aller")

	# Au coin de la rue des Barons, en descendant la rue de la République.
	v = await _a(8.5, 258.0)
	var barons := _lit(v, "Place de la Cathédrale  160 m")
	check(barons.contains("vers l'est") and barons.contains("rue des Barons"), "au coin de la rue des Barons, un poteau dit d'aller vers l'est (%s)" % barons)
	check(_vu(v, "poteau indicateur"), "il voit le poteau indicateur")

	# Sur la place, sous la banderole : le chevalet du Grand Prix.
	v = await _a(152.0, 306.0)
	check(_lit(v, "GRAND PRIX DE LA LOUVE") != "", "rue des Barons, il lit le Grand Prix de la Louve (banderole ou chevalet)")
	check(_lit(v, "Dimanche, arrivée ici").contains("sortie sud"), "le chevalet dit où part la route de la course")

	# À la sortie sud, le premier poteau jaune.
	v = await _a(97.0, 808.0)
	var jaune := _lit(v, "Grand Prix de la Louve · Au Replat")
	check(jaune.contains("vers le sud"), "à la sortie sud, le poteau jaune du Grand Prix montre la route du banc (%s)" % jaune)

	# Où la route du relais quitte celle du banc : trois lames.
	v = await _a(4300.0, 1935.0)
	check(_lit(v, "Relais des Lônes") != "" and _lit(v, "Belley, centre") != "" and _lit(v, "Au Replat") != "", "au carrefour du banc, le poteau mène au banc, au relais et à Belley")
	_fin()


## L'habitant posé en (x, z), sur le sol ; la vue une fois posé.
func _a(x: float, z: float) -> Dictionary:
	var j: CharacterBody3D = P.joueur()
	var s: Node = current_scene
	var y: float = s.call("hauteur", x, z)
	j.velocity = Vector3.ZERO
	j.global_position = Vector3(x, y + 0.5, z)
	await create_timer(1.5).timeout
	return P.vue()


## Le premier écrit en vue qui contient ce texte, sinon « ».
func _lit(v: Dictionary, texte: String) -> String:
	for e in v.get("ecrits", []):
		if str(e.texte).contains(texte):
			return str(e.texte)
	return ""


func _vu(v: Dictionary, nom: String) -> bool:
	for o in v.get("objets", []):
		if str(o.nom) == nom:
			return true
	return false


func _fin() -> void:
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _parcourir(dossier: String, racine: String, cible: String, out: Dictionary) -> void:
	var d := DirAccess.open(dossier)
	for f in d.get_files():
		var chemin := dossier + f
		var dans_le_paquet := cible + chemin.trim_prefix(racine)
		if f.ends_with(".import"):
			out[dans_le_paquet] = chemin
			var cfg := ConfigFile.new()
			if cfg.load(chemin) == OK and cfg.has_section("remap"):
				for k in cfg.get_section_keys("remap"):
					var importe := str(cfg.get_value("remap", k))
					if k.begins_with("path") and FileAccess.file_exists(importe):
						out[importe] = importe
		elif not FileAccess.file_exists(chemin + ".import"):
			out[dans_le_paquet] = chemin
	for sub in d.get_directories():
		_parcourir(dossier + sub + "/", racine, cible, out)
