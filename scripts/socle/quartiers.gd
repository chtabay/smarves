class_name Quartiers
extends RefCounted
## Les quartiers d'une commune, enregistrés d'avance et lus en arrière-plan (socle 1.21, retour de l'auteur
## de Chauvigny : une ville bâtie par code à chaque ouverture fait attendre 10 à 15 s). Le manifeste les
## nomme (champ « quartiers », docs/COMMUNE.md, « Les quartiers enregistrés ») :
##
##   "quartiers": {"chateau": {"batir": "quartiers/chateau.gd", "scene": "quartiers/chateau.scn"}}
##
## « batir » est un script dont la fonction statique batir(racine: Node3D) remplit le quartier, par code,
## comme la commune le faisait dans sa scène ; « scene » (par défaut quartiers/<nom>.scn) est ce qu'il a
## bâti, enregistré une fois par tools/enregistrer_quartiers.gd chez l'auteur. Le jeu lit la scène dans un
## fil dès qu'on entre dans la commune (Chargement), et Quartiers.poser la pose quand elle est lue. Tant
## que la scène n'est pas enregistrée, poser bâtit par code : le même appel marche avant et après.

const PAR_DEFAUT := "quartiers/%s.scn"
const _NOM := "^[a-z_][a-z0-9_]{0,47}$"


## Les fautes du champ « quartiers » d'un manifeste (aucune s'il est absent).
static func verifier(q) -> PackedStringArray:
	var out := PackedStringArray()
	if q == null:
		return out
	if typeof(q) != TYPE_DICTIONARY:
		out.append("quartiers doit être un objet : {\"<nom>\": {\"batir\": \"quartiers/<nom>.gd\"}}")
		return out
	var nom := RegEx.create_from_string(_NOM)
	for k in q:
		var e = q[k]
		if nom.search(str(k)) == null:
			out.append("quartier « %s » : un nom en minuscules, chiffres et « _ »" % k)
		if typeof(e) != TYPE_DICTIONARY:
			out.append("quartier %s : un objet {batir, scene}" % k)
			continue
		for c in e:
			if not c in ["batir", "scene"]:
				out.append("quartier %s : champ inconnu « %s »" % [k, c])
		if typeof(e.get("batir")) != TYPE_STRING or not _relatif(e.batir, ["gd"]):
			out.append("quartier %s : « batir » est le script qui le bâtit, dans le dossier de la commune (quartiers/%s.gd)" % [k, k])
		if e.has("scene") and (typeof(e.scene) != TYPE_STRING or not _relatif(e.scene, ["scn", "tscn"])):
			out.append("quartier %s : « scene » est une scène .scn du dossier de la commune (quartiers/%s.scn)" % [k, k])
	return out


static func _relatif(chemin: String, extensions: Array) -> bool:
	return chemin != "" and not chemin.begins_with("res://") and not chemin.begins_with("/") \
		and not ".." in chemin.split("/") and chemin.get_extension() in extensions


## Les quartiers d'une commune : {nom: {batir, scene}}, en chemins res://.
static func de(c: Commune) -> Dictionary:
	var out := {}
	var q = c.data.get("quartiers") if c != null else null
	if typeof(q) != TYPE_DICTIONARY or not verifier(q).is_empty():
		return out
	var dossier := c.chemin.get_base_dir() + "/"
	for k in q:
		out[k] = {"batir": dossier + q[k].batir, "scene": dossier + str(q[k].get("scene", PAR_DEFAUT % k))}
	return out


## Lance la lecture, dans des fils, des quartiers enregistrés de la commune. Chargement l'appelle en entrant.
static func demander(c: Commune) -> void:
	for k in de(c):
		var s: String = de(c)[k].scene
		if ResourceLoader.exists(s) and not ResourceLoader.has_cached(s):
			ResourceLoader.load_threaded_request(s, "", true)


## Pose le quartier `nom` de la commune `id` sous `parent` et le rend : la scène enregistrée, lue en
## arrière-plan (on attend, image après image, qu'elle soit lue), sinon bâti par son script. null si la
## commune ne déclare pas ce quartier.
static func poser(parent: Node, id: String, nom: String) -> Node3D:
	return await poser_de(parent, (Engine.get_main_loop() as SceneTree).root.get_node("Communes").commune(id), nom)


static func poser_de(parent: Node, c: Commune, nom: String) -> Node3D:
	var q: Dictionary = de(c).get(nom, {})
	if q.is_empty():
		push_warning("Quartiers.poser : la commune « %s » ne déclare pas le quartier « %s »" % [c.id if c else "?", nom])
		return null
	var n: Node3D
	if ResourceLoader.exists(q.scene):
		var ps: PackedScene = await lire(q.scene)
		n = ps.instantiate() if ps != null else null
	if n != null:
		parent.add_child(n)
		# Ce qui arrive après la scène n'a pas eu ses objets lointains (Chargement) : on les lui donne.
		Callable(Lointain, "appliquer").call_deferred(n)
		return n
	n = Node3D.new()
	n.name = nom
	parent.add_child(n)
	await load(q.batir).batir(n)
	Callable(Lointain, "appliquer").call_deferred(n)
	return n


## Une scène lue dans un fil, sans bloquer l'image : demandée si elle ne l'est pas, attendue sinon.
static func lire(chemin: String) -> PackedScene:
	if ResourceLoader.has_cached(chemin):
		return load(chemin)
	var etat := ResourceLoader.load_threaded_get_status(chemin)
	if etat == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		if ResourceLoader.load_threaded_request(chemin, "", true) != OK:
			return null
	var arbre := Engine.get_main_loop() as SceneTree
	while ResourceLoader.load_threaded_get_status(chemin) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await arbre.process_frame
	if ResourceLoader.load_threaded_get_status(chemin) != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	return ResourceLoader.load_threaded_get(chemin) as PackedScene


## Enregistre un quartier bâti (le nœud et tout ce qu'il porte) en scène .scn compressée. Les scènes posées
## dedans (une brique de la bibliothèque, un modèle) restent des liens vers leur fichier.
static func enregistrer(racine: Node, chemin: String) -> Error:
	_adopter(racine, racine)
	var ps := PackedScene.new()
	var e := ps.pack(racine)
	if e != OK:
		return e
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	return ResourceSaver.save(ps, chemin, ResourceSaver.FLAG_COMPRESS)


static func _adopter(n: Node, racine: Node) -> void:
	for e in n.get_children():
		e.owner = racine
		if e.scene_file_path == "":
			_adopter(e, racine)
