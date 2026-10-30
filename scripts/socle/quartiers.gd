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
##
## Socle 1.29, pour une ville faite de quartiers (Lyon) : un quartier dit son « centre » ([x, z], en mètres
## dans le repère de la commune), son « rayon » (150 m par défaut) et sa version lointaine « lointain »
## (quartiers/<nom>_loin.scn par défaut, enregistrée par tools/enregistrer_quartiers.gd : ses maillages fixes
## fondus par matière, sans détail). Quartiers.veiller pose le quartier où le joueur se tient en détail et
## les autres en version lointaine ; quand le joueur entre dans un sas (un nœud « Sas_<vers> » d'un quartier
## posé, méta « rayon », 6 m par défaut), le quartier d'en face se pose en détail, et celui que le joueur a
## quitté repasse en version lointaine une fois qu'il est sorti du sas.

const PAR_DEFAUT := "quartiers/%s.scn"
const LOINTAIN_DEFAUT := "quartiers/%s_loin.scn"
const RAYON_DEFAUT := 150.0
const SAS_RAYON := 6.0
## Les secondes entre deux regards de la veille sur la position du joueur.
const VEILLE_PAS := 0.4
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
			if not c in ["batir", "scene", "lointain", "centre", "rayon"]:
				out.append("quartier %s : champ inconnu « %s »" % [k, c])
		if typeof(e.get("batir")) != TYPE_STRING or not _relatif(e.batir, ["gd"]):
			out.append("quartier %s : « batir » est le script qui le bâtit, dans le dossier de la commune (quartiers/%s.gd)" % [k, k])
		if e.has("scene") and (typeof(e.scene) != TYPE_STRING or not _relatif(e.scene, ["scn", "tscn"])):
			out.append("quartier %s : « scene » est une scène .scn du dossier de la commune (quartiers/%s.scn)" % [k, k])
		if e.has("lointain") and (typeof(e.lointain) != TYPE_STRING or not _relatif(e.lointain, ["scn", "tscn"])):
			out.append("quartier %s : « lointain » est sa version lointaine, une scène .scn du dossier de la commune (quartiers/%s_loin.scn)" % [k, k])
		if e.has("centre") and not (typeof(e.centre) == TYPE_ARRAY and e.centre.size() == 2 and (e.centre[0] is float or e.centre[0] is int) and (e.centre[1] is float or e.centre[1] is int)):
			out.append("quartier %s : « centre » est [x, z], en mètres dans le repère de la commune" % k)
		if e.has("rayon") and not ((e.rayon is float or e.rayon is int) and e.rayon > 0):
			out.append("quartier %s : « rayon » est une distance en mètres, positive" % k)
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
		var e: Dictionary = q[k]
		var centre = e.get("centre")
		out[k] = {"batir": dossier + e.batir, "scene": dossier + str(e.get("scene", PAR_DEFAUT % k)),
			"lointain": dossier + str(e.get("lointain", LOINTAIN_DEFAUT % k)),
			"centre": Vector2(float(centre[0]), float(centre[1])) if centre != null else Vector2.INF,
			"rayon": float(e.get("rayon", RAYON_DEFAUT))}
	return out


## Lance la lecture, dans des fils, des quartiers enregistrés de la commune. Chargement l'appelle en entrant.
static func demander(c: Commune) -> void:
	var q := de(c)
	for k in q:
		for s: String in [q[k].scene, q[k].lointain]:
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
		_lointain_differe(n)
		return n
	n = Node3D.new()
	n.name = nom
	parent.add_child(n)
	await load(q.batir).batir(n)
	_lointain_differe(n)
	return n


## Les objets lointains à l'image suivante, si le quartier est encore là (la veille peut l'avoir allégé).
static func _lointain_differe(n: Node3D) -> void:
	var w := weakref(n)
	(func() -> void:
		var o = w.get_ref()
		if o != null and o.is_inside_tree():
			Lointain.appliquer(o)).call_deferred()


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


# --- La version lointaine seule, et la veille des sas (socle 1.29) ---------------------------------

## Pose sous `parent` la version lointaine seule du quartier `nom` : la scène « lointain » enregistrée,
## sinon le quartier bâti puis fondu sur place (lent : c'est pour l'auteur, avant l'enregistrement). Le
## nœud rendu s'appelle « <nom>_loin », porte la méta « quartier_loin » et se voit à toute distance.
static func lointain_de(parent: Node, c: Commune, nom: String) -> Node3D:
	var q: Dictionary = de(c).get(nom, {})
	if q.is_empty():
		push_warning("Quartiers.lointain : la commune « %s » ne déclare pas le quartier « %s »" % [c.id if c else "?", nom])
		return null
	var n: Node3D
	if ResourceLoader.exists(q.lointain):
		var ps: PackedScene = await lire(q.lointain)
		n = ps.instantiate() if ps != null else null
	if n == null:
		var plein := Node3D.new()
		plein.name = nom
		parent.add_child(plein)
		await load(q.batir).batir(plein)
		n = fondre(plein)
		plein.free()
		if n == null:
			return null
	n.name = "%s_loin" % nom
	n.set_meta("quartier_loin", nom)
	parent.add_child(n)
	return n


## La version lointaine d'un quartier bâti et dans l'arbre : un nœud neuf, hors de l'arbre, qui porte ses
## maillages fixes fondus par matière (Lointain.quartier), visibles à toute distance. null si rien à fondre.
static func fondre(plein: Node3D) -> Node3D:
	# Un quartier déjà traité par Lointain (méta « lointain » lue par Chargement) a déjà ses maillages fondus.
	Lointain.quartier(plein, 0.0)
	var n := Node3D.new()
	n.name = "%s_loin" % plein.name
	n.transform = plein.transform
	var partis := []
	for e in plein.get_children():
		if e is MeshInstance3D and e.has_meta("lointain_quartier"):
			partis.append(e)
	# Les maillages d'origine regardaient ces nœuds comme parents de visibilité : ils redeviennent libres.
	for mi: MeshInstance3D in plein.find_children("*", "MeshInstance3D", true, false):
		if mi.visibility_parent != NodePath("") and mi.get_node_or_null(mi.visibility_parent) in partis:
			mi.visibility_parent = NodePath("")
	for e in partis:
		plein.remove_child(e)
		e.visibility_range_begin = 0.0
		e.visibility_range_begin_margin = 0.0
		n.add_child(e)
	if n.get_child_count() == 0:
		n.free()
		return null
	return n


## Enregistre la version lointaine d'un quartier bâti (dans l'arbre) : son nœud fondu, rangé en .scn
## compressée. Les maillages d'origine gardent leur place dans `plein`. ERR_SKIP si rien à fondre.
static func enregistrer_lointain(plein: Node3D, chemin: String) -> Error:
	var n := fondre(plein)
	if n == null:
		return ERR_SKIP
	plein.get_parent().add_child(n)
	var e := enregistrer(n, chemin)
	n.free()
	return e


## Pose la veille des quartiers de la commune `id` sous `parent` : le quartier `depart` en détail, les
## autres en version lointaine, puis suit `joueur`. `parent` reçoit les quartiers posés.
static func veiller(parent: Node3D, id: String, joueur: Node3D, depart: String) -> Veille:
	return veiller_de(parent, (Engine.get_main_loop() as SceneTree).root.get_node("Communes").commune(id), joueur, depart)


static func veiller_de(parent: Node3D, c: Commune, joueur: Node3D, depart: String) -> Veille:
	var v := Veille.new()
	v.name = "Veille"
	v.commune = c
	v.joueur = joueur
	v.courant = depart
	parent.add_child(v)
	return v


## La veille : quel quartier est en détail, lesquels sont au loin, et le passage de l'un à l'autre par
## les sas. Le quartier courant est celui dont le joueur est le plus près du centre, dans son rayon ; s'y
## ajoutent les quartiers « vers » lesquels mène un sas où le joueur se tient. Ceux-là sont en détail,
## tous les autres en version lointaine. Un quartier sans centre déclaré reste comme il est posé.
class Veille extends Node:
	signal pose(nom: String)
	signal allege(nom: String)

	var commune: Commune
	var joueur: Node3D
	var courant := ""
	## {nom: Node3D} des quartiers posés en détail, et de ceux posés au loin.
	var detailles := {}
	var lointains := {}
	var _en_cours := {}
	var _horloge := 0.0
	var _prete := false

	func _ready() -> void:
		var q := Quartiers.de(commune)
		if courant != "" and q.has(courant):
			await _detailler(courant)
		for nom in q:
			if nom != courant and not detailles.has(nom):
				await _alleger(nom)
		_prete = true

	func _process(delta: float) -> void:
		_horloge += delta
		if _horloge < Quartiers.VEILLE_PAS or not _prete:
			return
		_horloge = 0.0
		verifier()

	## Les quartiers que le joueur demande en détail, d'où il se tient : le courant et ceux des sas.
	func voulus() -> Array:
		var q := Quartiers.de(commune)
		if joueur == null or not is_instance_valid(joueur):
			return [courant] if courant != "" else []
		var p := joueur.global_position
		var ici := Vector2(p.x, p.z)
		var plus_pres := courant
		var d_pres := ici.distance_to(q[courant].centre) if q.has(courant) and q[courant].centre != Vector2.INF else INF
		for nom in q:
			var centre: Vector2 = q[nom].centre
			if centre == Vector2.INF:
				continue
			var d := ici.distance_to(centre)
			if d <= q[nom].rayon and d < d_pres:
				plus_pres = nom
				d_pres = d
		courant = plus_pres
		var out := [courant] if courant != "" else []
		for nom in detailles:
			var n: Node3D = detailles[nom]
			if not is_instance_valid(n):
				continue
			for sas: Node3D in n.find_children("Sas_*", "Node3D", true, false):
				var vers := String(sas.name).trim_prefix("Sas_")
				var r := float(sas.get_meta("rayon", Quartiers.SAS_RAYON))
				if q.has(vers) and not vers in out and sas.global_position.distance_to(p) <= r:
					out.append(vers)
		return out

	## Un regard : pose en détail ce que le joueur demande, allège le reste. Renvoie les quartiers voulus.
	func verifier() -> Array:
		var v := voulus()
		for nom in v:
			if not detailles.has(nom) and not _en_cours.has(nom):
				_detailler(nom)
		for nom in detailles.keys():
			if not nom in v and not _en_cours.has(nom):
				_alleger(nom)
		return v

	func _detailler(nom: String) -> void:
		_en_cours[nom] = true
		var n: Node3D = await Quartiers.poser_de(get_parent(), commune, nom)
		if n != null:
			detailles[nom] = n
			if lointains.has(nom):
				if is_instance_valid(lointains[nom]):
					lointains[nom].queue_free()
				lointains.erase(nom)
			pose.emit(nom)
		_en_cours.erase(nom)

	func _alleger(nom: String) -> void:
		_en_cours[nom] = true
		var loin: Node3D
		var plein: Node3D = detailles.get(nom)
		if plein != null and is_instance_valid(plein) and not ResourceLoader.exists(Quartiers.de(commune)[nom].lointain):
			# Pas de version lointaine enregistrée : on fond le quartier posé plutôt que de le rebâtir.
			loin = Quartiers.fondre(plein)
			if loin != null:
				loin.set_meta("quartier_loin", nom)
				get_parent().add_child(loin)
		else:
			loin = await Quartiers.lointain_de(get_parent(), commune, nom)
		if loin != null:
			lointains[nom] = loin
		if detailles.has(nom):
			if is_instance_valid(detailles[nom]):
				detailles[nom].queue_free()
			detailles.erase(nom)
		allege.emit(nom)
		_en_cours.erase(nom)
