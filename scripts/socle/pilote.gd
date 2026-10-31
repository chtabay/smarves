extends Node
## Le pilote d'un pensionnaire (autoload « Pilote », docs/PENSIONNAIRES.md, « Le pilote ») : le vrai jeu,
## sans écran, tenu par un assistant au lieu d'un clavier. Il ne connaît aucun lieu ni aucun jeu : il lit
## ce que le socle montre à tout joueur et rejoue les gestes d'un joueur.
##
## Ce qu'il voit (vue) :
## - les zones où l'on appuie sur E (toute Area3D qui porte la méta « interact »), avec leur invite, à
##   combien de secondes de marche et de quel côté ;
## - l'invite affichée quand on est devant l'une d'elles ;
## - les boutons à l'écran (le texte, sinon la bulle d'aide), les cases d'un tapis de table 3D
##   (scripts/jeux/table_3d.gd), et les textes affichés ;
## - les cases d'un plateau dessiné à l'écran (un échiquier) : tout contrôle qui les donne par
##   pilote_cases() -> {nom: Rect2 dans son repère}, avec ce qu'il montre par pilote_texte() -> String ;
## - les écrits posés dans le monde (tout Label3D en vue : une plaque, un panneau, une étiquette) ;
## - les choses qui se voient autour (une herse, une bascule, un banc) : tout nœud nommé de la scène,
##   d'une taille d'objet, qui n'est pas une zone, avec sa distance et sa direction ;
## - ce qui l'entoure : vers chaque point cardinal, jusqu'où l'on peut marcher avant une paroi ;
## - où il est (sa position, en mètres vers l'est et vers le nord) et vers où il regarde. Le nord est
##   vers les z négatifs, comme partout dans le jeu (et sur les plans dessinés, le nord en haut).
## - l'écran lui-même, en image, quand il regarde et que le jeu se dessine (la tâche le lance sous un écran
##   virtuel) ; les autres gestes rendent la vue en mots.
## Ne se voit que ce qu'aucun mur ne cache : une zone de l'autre côté d'une paroi n'est pas montrée.
## Assis à une table qui se résume elle-même (pilote_resume : l'échiquier du Cercle), la vue n'est que
## ce résumé et les boutons de la table.
##
## Ce qu'il fait (geste) :
## - aller : marcher jusqu'à être devant une zone ou une chose vue, comme on le ferait aux flèches ;
## - marcher : avancer quelques secondes, ou quelques mètres, dans une direction (un point cardinal, ou
##   devant, à gauche…), en se dégageant d'un pilier qui accroche comme un joueur qui tâtonne ;
## - touche : une touche du clavier (E, Espace, Échap, Entrée, Tab, une lettre, un chiffre) ;
## - cliquer : un bouton, une case du tapis ou du plateau, par un clic de souris à sa place à l'écran ;
##   ou un coup entier sur un plateau qui le sait (pilote_coup : « e2-e4 » sur l'échiquier), en un geste ;
## - attendre : laisser passer quelques secondes (une bille qui roule, une donne) ;
## - dire : une phrase en bulle (la partie réseau la porte au village).
##
## Une nouvelle carte, un nouveau bâtiment, un nouveau jeu se pilotent donc sans une ligne ici, tant
## qu'ils passent par ces briques du socle.
##
## Sans « --pilote » dans les arguments, rien ne tourne : le jeu d'un joueur n'en sait rien. Les essais
## (tools/test_pilote.gd) appellent vue() et geste() directement, sans réseau.

const TOUCHES := {
	"E": KEY_E, "ESPACE": KEY_SPACE, "ECHAP": KEY_ESCAPE, "ÉCHAP": KEY_ESCAPE, "ENTREE": KEY_ENTER,
	"ENTRÉE": KEY_ENTER, "TAB": KEY_TAB, "M": KEY_M, "V": KEY_V,
	"1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4, "5": KEY_5, "6": KEY_6, "7": KEY_7, "8": KEY_8, "9": KEY_9,
	"0": KEY_0,
}
## Ce qui se voit : en deçà, une zone se voit même derrière un coin ; ce qui arrête le regard tout contre
## la zone (la porte dont c'est la zone, le comptoir d'un guichet) ne la cache pas.
const VU_PRES := 3.0
const VU_CONTRE := 1.5
## Les écrits posés dans le monde : jusqu'à cette distance, tant au plus.
const ECRITS_LOIN := 25.0
const ECRITS_MAX := 15
## L'image de l'écran jointe à chaque vue : sa largeur (pixels) et sa qualité JPEG.
const IMAGE_LARGE := 768
const IMAGE_QUALITE := 0.7
## Ce qui entoure le corps : le regard porte jusque-là de chaque côté.
const AUTOUR_LOIN := 30.0
## Les choses qui se voient : à combien de mètres au plus, combien, et la taille d'un objet (au-delà, un
## mur, un bâtiment, une galerie : on regarde ce qu'il contient).
const OBJETS_LOIN := 20.0
const OBJETS_MAX := 15
const OBJET_LARGE := 4.5
const OBJET_HAUT := 12.0
const CARDINAUX := ["nord", "nord-est", "est", "sud-est", "sud", "sud-ouest", "ouest", "nord-ouest"]
## Les zones montrées : les plus proches, jusqu'à cette distance (unités de la scène).
const ZONES_MAX := 24
const ZONES_LOIN := 80.0
const BOUTONS_MAX := 40
const TEXTES_MAX := 30
const TEXTE_LONG := 240
## Marcher vers une zone : le plus long qu'on y consacre, et le temps sans avancer avant de contourner.
const MARCHE_MAX := 30.0
const BUTE := 0.6
const ATTENTE_MAX := 30.0
## Après un geste, le temps que l'écran se pose (une porte qui charge sa scène, un panneau qui s'ouvre).
const POSE := 1.2
## Après un clic, on attend encore que l'écran change puis reste calme ce temps-là (la réponse d'une table
## en ligne), sans dépasser POSE_MAX ; s'il n'a pas changé après POSE_RIEN, on n'attend plus.
const POSE_CALME := 1.0
const POSE_RIEN := 2.5
const POSE_MAX := 6.0
## Un coup joué sur un plateau : le temps qu'on attend au plus la réponse de l'adversaire.
const REPONSE_COUP := 10.0
## Les champs où l'on écrit (une petite annonce), et la longueur d'un texte écrit d'un coup.
const CHAMPS_MAX := 10
const ECRIT_LONG := 400
## Au-delà de cette différence de hauteur, une zone est à un autre étage.
const ETAGE := 2.5
## La grille du chemin : tant de cases de côté au plus, tant de cases visitées au plus.
const GRILLE_MAX := 320
const VISITES_MAX := 120000
## La recherche du chemin : son temps au plus, et le poids de l'estimation (au-dessus de 1, elle file
## droit vers le but au prix d'un chemin un peu moins court, et visite bien moins de cases).
const CHERCHE_MAX := 6.0
const POIDS := 2.5

## Vrai quand le pilote tient le jeu (réseau compris) ; les essais l'allument à la main.
var actif := false
## Ce que la partie réseau doit porter au village : les phrases dites, en attente.
var paroles: Array = []

## Les repères de la dernière vue : id -> nœud (z… zone, b… bouton, c… case de tapis -> [table, clé]).
var _reperes := {}
## Les choses déjà vues dans ce lieu (nom -> {objet, boite, nom}) : on peut y retourner sans les voir
## d'ici, comme un joueur qui se souvient de la bascule dans la chambre d'à côté.
var _vus := {}
var _vus_lieu: Node = null
var _dits := 0
## Ce qu'on a entendu autour de soi depuis le dernier geste : [{nom, dit}] ; une bulle ne dure que dix
## secondes, et l'assistant réfléchit souvent plus longtemps entre deux gestes.
var entendu: Array = []
const ENTENDU_MAX := 12


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pr: Node = get_node_or_null("/root/Presences")
	if pr:
		pr.etat_change.connect(_on_etat_change)
	if "--pilote" in OS.get_cmdline_user_args():
		actif = true
		# Dès le lancement : une image en rendu logiciel dure si longtemps que le catalogue du portail
		# (Communes) attendait plus que son délai, et les villes publiées ne s'installaient pas.
		if DisplayServer.get_name() != "headless":
			RenderingServer.render_loop_enabled = false
		var reseau: Node = load("res://scripts/socle/pilote_reseau.gd").new()
		reseau.name = "Reseau"
		add_child(reseau)


func _on_etat_change(membre: String, e: Dictionary) -> void:
	var pr: Node = get_node_or_null("/root/Presences")
	var p: Dictionary = pr.presents.get(membre, {}) if pr else {}
	if p.is_empty() or not p.get("a_portee", false) or not (e.get("dit") is String) or str(e.dit) == "":
		return
	entendu.append({"nom": str(p.get("nom", "")), "dit": str(e.dit).left(400)})
	if entendu.size() > ENTENDU_MAX:
		entendu.pop_front()


# --- Ce que voit le joueur ------------------------------------------------------------------------

func scene() -> Node:
	return get_tree().current_scene


## Le corps qu'on dirige dans la scène en cours (le groupe « player » de scripts/fp_player.gd).
func joueur() -> CharacterBody3D:
	var s := scene()
	if s == null:
		return null
	for p in get_tree().get_nodes_in_group("player"):
		if p is CharacterBody3D and s.is_ancestor_of(p):
			return p
	return null


func vue() -> Dictionary:
	_reperes.clear()
	var s := scene()
	var v := {"lieu": _nom_du_lieu(s), "credits": Game.credits, "gagne": Game.won}
	var j := joueur()
	# Une table qui se résume elle-même (l'échiquier du Cercle, pilote_resume()) : pendant qu'on y est
	# assis, la vue n'est que ce résumé et les boutons de la table. Les cases restent cliquables (repères).
	var seul := _panneau_seul()
	if seul != null:
		v["assis"] = true
		_cases()
		v["boutons"] = _boutons(seul)
		v["textes"] = [str(seul.pilote_resume()).strip_edges()]
		return v
	if j:
		v["devant"] = _invite_de(j.focus_target) if j.focus_target and not j.frozen else ""
		v["assis"] = j.frozen
		v["zones"] = [] if j.frozen else _zones(j)
	var gens := _gens(j)
	if not gens.is_empty():
		v["gens"] = gens
	v["boutons"] = _boutons()
	var champs := _champs()
	if not champs.is_empty():
		v["champs"] = champs
	var cases := _cases()
	if not cases.is_empty():
		v["cases"] = cases
	if j and not j.frozen:
		v["cap"] = _cardinal(-j.global_basis.z)
		v["position"] = {"est": snappedf(j.global_position.x, 0.1), "nord": snappedf(-j.global_position.z, 0.1)}
		v["autour"] = _autour(j)
		var objets := _objets(j)
		if not objets.is_empty():
			v["objets"] = objets
		var ecrits := _ecrits(j, gens)
		if not ecrits.is_empty():
			v["ecrits"] = ecrits
	var textes := _textes(v.get("devant", ""))
	for c in _plateaux():
		if c.has_method("pilote_texte"):
			var t := str(c.pilote_texte()).strip_edges()
			if t != "":
				textes.push_front(t)
	v["textes"] = textes
	return v


func _nom_du_lieu(s: Node) -> String:
	if s == null:
		return ""
	if s.has_method("nom_du_lieu"):
		return str(s.nom_du_lieu())
	return s.scene_file_path.get_file().get_basename() if s.scene_file_path != "" else str(s.name)


## Ce qu'affiche le jeu devant cette zone : la scène qui calcule son invite (invite_de), sinon la méta.
func _invite_de(z: Node) -> String:
	if z == null:
		return ""
	var s := scene()
	if s and s.has_method("invite_de"):
		var t := str(s.invite_de(z))
		if t != "":
			return t
	var p := str(z.get_meta("prompt", ""))
	if p != "":
		return p
	return str(z.get_meta("interact", ""))


func _zones(j: CharacterBody3D) -> Array:
	var liste := []
	for z in _toutes_les_zones():
		var d := _a_plat(z.global_position - j.global_position).length()
		if d > ZONES_LOIN or not _en_vue(j, z):
			continue
		liste.append([d, z])
	liste.sort_custom(func(a, b): return a[0] < b[0])
	# Une invite déjà vue (dix habitants à qui parler) ne se montre qu'une fois, la plus proche.
	var out := []
	var par_invite := {}
	for e in liste:
		var z: Area3D = e[1]
		var invite := _invite_de(z)
		if par_invite.has(invite):
			par_invite[invite]["aussi"] = int(par_invite[invite].get("aussi", 0)) + 1
			continue
		if out.size() >= ZONES_MAX:
			continue
		var id := "z%d" % (out.size() + 1)
		_reperes[id] = z
		var d := {"id": id, "invite": invite, "secondes": snappedf(e[0] / maxf(j.speed, 0.1), 1.0), "cote": _cote(j, z.global_position)}
		var dy := z.global_position.y - j.global_position.y
		if absf(dy) > ETAGE + 1.0:
			d["cote"] += ", à l'étage au-dessus" if dy > 0.0 else ", à l'étage en dessous"
		par_invite[invite] = d
		out.append(d)
	return out


func _toutes_les_zones() -> Array:
	var out := []
	var s := scene()
	if s == null:
		return out
	for n in s.find_children("*", "Area3D", true, false):
		if n.has_meta("interact") and (n as Area3D).is_visible_in_tree() and (n as Area3D).monitorable:
			out.append(n)
	return out


## Vrai si le point se voit d'ici : un joueur tourne la tête et fait un pas de côté, et une porte dans une
## façade se voit en enfilade ; on essaie donc les yeux et un pas de chaque côté, vers le point et quatre
## points autour de lui, à mi-hauteur d'homme. Ce qui arrête le regard tout contre soi (le mur qu'on
## longe) ou qui appartient à la même chose que la zone (le bâtiment dont c'est la porte) ne la cache
## pas. Une zone de l'autre côté d'une paroi, d'un autre lieu de la scène, ne se voit d'aucun.
## Une chose vue (boite) : on vise sa boîte, et ce qui l'arrête dans sa boîte, c'est elle.
func _en_vue(j: CharacterBody3D, z: Node3D, boite := AABB()) -> bool:
	var objet := boite.size != Vector3.ZERO
	var at := z.global_position if not objet else Vector3(boite.get_center().x, boite.position.y, boite.get_center().z)
	if _a_plat(j.global_position - at).length() < VU_PRES:
		return true
	var espace := j.get_world_3d().direct_space_state
	var yeux := _yeux(j)
	var haut := maxf(yeux.y - j.global_position.y, 0.3)
	var pas := haut * 1.5
	var departs := [yeux]
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var p: Vector3 = yeux + d * pas
		if espace.intersect_ray(PhysicsRayQueryParameters3D.create(yeux, p, j.collision_mask, [j.get_rid()])).is_empty():
			departs.append(p)
	var cibles := [at + Vector3.UP * haut * 0.5]
	if objet:
		var c := boite.get_center()
		cibles = [c]
		for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			cibles.append(c + d * (boite.size * 0.4).dot(d.abs()))
	var large := boite.grow(0.3)
	for d in [] if objet else [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		cibles.append(at + d * pas * 0.7 + Vector3.UP * haut * 0.5)
	var lieu: Node = null if objet else _parent_sous_scene(z)
	# Ce qui enferme la zone elle-même (le bâtiment dont c'est la porte, d'un seul bloc) ne la cache pas.
	var q := PhysicsPointQueryParameters3D.new()
	q.position = cibles[0]
	q.collision_mask = j.collision_mask
	var dedans := {}
	for h in espace.intersect_point(q, 8):
		dedans[h.rid] = true
	for de in departs:
		for vers in cibles:
			var dir: Vector3 = (vers - de).normalized()
			var depuis: Vector3 = de
			for k in 3:
				var hit := espace.intersect_ray(PhysicsRayQueryParameters3D.create(depuis, vers, j.collision_mask, [j.get_rid()]))
				if hit.is_empty() or (hit.position as Vector3).distance_to(vers) < VU_CONTRE * 0.5:
					return true
				if dedans.has(hit.rid) or (lieu != null and _parent_sous_scene(hit.collider) == lieu):
					return true
				if objet and (large.has_point(hit.position) or z.is_ancestor_of(hit.collider)):
					return true
				# Tout contre soi (le poteau qu'on frôle, le mur qu'on longe) : le regard passe à côté.
				if (hit.position as Vector3).distance_to(de) > j.radius * 4.0:
					break
				depuis = (hit.position as Vector3) + dir * j.radius
	return false


## L'enfant de la scène qui contient ce nœud (un bâtiment, une galerie), ou null s'il est la scène même.
func _parent_sous_scene(n: Variant) -> Node:
	var s := scene()
	if not (n is Node) or s == null:
		return null
	var x: Node = n
	while x != null and x.get_parent() != s:
		x = x.get_parent()
	return x


func _yeux(j: CharacterBody3D) -> Vector3:
	var c = j.get("camera")
	if c is Camera3D and is_instance_valid(c):
		return (c as Camera3D).global_position
	return j.global_position + Vector3.UP * 1.6


## De chaque côté (devant, à droite, derrière, à gauche, et entre deux), jusqu'où le regard porte à
## hauteur d'homme avant une paroi : on y voit les couloirs et les passages, comme un joueur.
func _autour(j: CharacterBody3D) -> Dictionary:
	var out := {}
	var de := j.global_position + Vector3.UP * minf(_yeux(j).y - j.global_position.y, 1.6) * 0.75
	var espace := j.get_world_3d().direct_space_state
	for i in CARDINAUX.size():
		var nom: String = CARDINAUX[i]
		var dir := _dir_cardinale(nom)
		var q := PhysicsRayQueryParameters3D.create(de, de + dir * AUTOUR_LOIN, j.collision_mask, [j.get_rid()])
		var hit := espace.intersect_ray(q)
		if hit.is_empty():
			out[nom] = "libre sur %d m et plus" % int(AUTOUR_LOIN)
			continue
		var m := _a_plat(hit.position - de).length()
		var t := "paroi à %s m" % (str(snappedf(m, 0.1)) if m < 3.0 else str(int(round(m))))
		var quoi := _libelle_de(hit.collider)
		out[nom] = t + (" (%s)" % quoi if quoi != "" else "")
	return out


## Le point cardinal d'une direction (le nord vers les z négatifs, l'est vers les x positifs).
func _cardinal(v: Vector3) -> String:
	var a := fposmod(rad_to_deg(atan2(v.x, -v.z)), 360.0)
	return CARDINAUX[int(round(a / 45.0)) % 8]


func _dir_cardinale(nom: String) -> Vector3:
	var i := CARDINAUX.find(nom)
	return Vector3.FORWARD.rotated(Vector3.UP, -deg_to_rad(45.0 * i)) if i >= 0 else Vector3.ZERO


## « au nord », « à l'est ».
func _vers(nom: String) -> String:
	return ("à l'" if nom.begins_with("e") or nom.begins_with("o") else "au ") + nom


## Les choses qui se voient d'ici : un nœud nommé de la scène (pas « @… »), d'une taille d'objet, dont le
## parent est plus grand (une galerie, un bâtiment) ; ni une zone, ni un écrit, ni un corps vivant. Son
## nom est celui que lui a donné son auteur (« CleAuClou » : « cle au clou »), ou sa méta « libelle ».
func _objets(j: CharacterBody3D) -> Array:
	var s := scene()
	var out := []
	if s == null:
		return out
	if _vus_lieu != s:
		_vus.clear()
		_vus_lieu = s
	var boites := {}
	_boites(s, j, boites)
	var trouves := []
	_choisir_objets(s, boites, trouves)
	var liste := []
	for e in trouves:
		var b: AABB = e[1]
		var c := b.get_center()
		var d := _a_plat(c - j.global_position).length()
		if d > OBJETS_LOIN or c.y - j.global_position.y > ETAGE + 1.0 or c.y + b.size.y * 0.5 < j.global_position.y - ETAGE:
			continue
		liste.append([d, e[0], b])
	liste.sort_custom(func(a, b): return a[0] < b[0])
	for e in liste:
		if out.size() >= OBJETS_MAX:
			break
		var n: Node3D = e[1]
		var nom := _nom_d_objet(n)
		if nom == "" or not _en_vue(j, n, e[2]):
			continue
		# Deux bascules : chacune son id, la plus proche d'abord (« aller bascule » va à celle-là).
		var id := "o%d" % (out.size() + 1)
		var b: AABB = e[2]
		_reperes[id] = {"objet": n, "boite": b, "nom": nom}
		_vus[nom] = _reperes[id]
		out.append({"id": id, "nom": nom, "metres": snappedf(e[0], 0.5), "cote": _cote(j, b.get_center())})
	return out


## La boîte de ce que dessine chaque nœud avec ses enfants (boites[nœud], s'il dessine quelque chose).
func _boites(n: Node, j: CharacterBody3D, boites: Dictionary) -> void:
	if n == j or n is CanvasItem or n is Area3D or n is CharacterBody3D or n is Label3D or n is Light3D \
			or n is Camera3D or n is GPUParticles3D or n is CPUParticles3D or (n is Node3D and not (n as Node3D).visible):
		return
	var boite := AABB()
	var vide := true
	if n is VisualInstance3D:
		var g := n as VisualInstance3D
		boite = g.global_transform * g.get_aabb()
		vide = false
	for c in n.get_children():
		_boites(c, j, boites)
		if boites.has(c):
			boite = boites[c] if vide else boite.merge(boites[c])
			vide = false
	if not vide:
		boites[n] = boite


## Du haut vers le bas : le premier nœud nommé d'une taille d'objet est une chose ; on ne regarde pas
## dans ses enfants (la herse, pas son vantail).
func _choisir_objets(n: Node, boites: Dictionary, trouves: Array) -> void:
	for c in n.get_children():
		if not boites.has(c):
			continue
		var b: AABB = boites[c]
		if _taille_d_objet(b) and _nom_d_objet(c) != "":
			trouves.append([c, b])
		elif maxf(b.size.x, b.size.z) >= 0.15:
			_choisir_objets(c, boites, trouves)


func _taille_d_objet(b: AABB) -> bool:
	return maxf(b.size.x, b.size.z) <= OBJET_LARGE and b.size.y <= OBJET_HAUT and maxf(b.size.x, b.size.z) >= 0.15


func _nom_d_objet(n: Node) -> String:
	if n.has_meta("libelle"):
		return str(n.get_meta("libelle"))
	var t := str(n.name)
	# Un nom laissé par défaut (« Skeleton3D », « MeshInstance3D2 ») ne dit rien.
	if t.begins_with("@") or t.begins_with(n.get_class()) or t in ["Geometrie", "Geometry", "Mesh", "Modele", "Model"]:
		return ""
	var mots := ""
	for i in t.length():
		var ch := t[i]
		if ch == "_" or ch == "-":
			mots += " "
		elif i > 0 and ch != ch.to_lower() and t[i - 1] == t[i - 1].to_lower() and t[i - 1] != "_":
			mots += " " + ch.to_lower()
		elif i > 0 and ch.is_valid_int() and not t[i - 1].is_valid_int():
			mots += " " + ch
		else:
			mots += ch.to_lower()
	return mots.strip_edges()


## Ce que le jeu dit d'un obstacle (la méta « libelle » d'un corps ou de son parent), sinon rien.
func _libelle_de(n: Variant) -> String:
	var k := 0
	while n is Node and k < 3:
		if (n as Node).has_meta("libelle"):
			return str((n as Node).get_meta("libelle"))
		n = (n as Node).get_parent()
		k += 1
	return ""


## Les écrits posés dans le monde et visibles d'ici (Label3D) : une plaque, un panneau, une étiquette ;
## pas les noms des gens, déjà dits.
func _ecrits(j: CharacterBody3D, gens: Array) -> Array:
	var s := scene()
	var out := []
	if s == null:
		return out
	var noms := {}
	for g in gens:
		noms[str(g.nom)] = true
	var liste := []
	for n in s.find_children("*", "Label3D", true, false):
		var l := n as Label3D
		var t := l.text.strip_edges().replace("\n", " · ")
		if t == "" or noms.has(t) or not l.is_visible_in_tree() or l.modulate.a < 0.1:
			continue
		var d := l.global_position.distance_to(j.global_position)
		if d > ECRITS_LOIN or not _en_vue(j, l):
			continue
		liste.append([d, t, l.global_position])
	# Du plus proche au plus loin, et de haut en bas sur un même panneau.
	liste.sort_custom(func(a, b): return a[2].y > b[2].y if absf(a[0] - b[0]) < 1.0 else a[0] < b[0])
	var vus := {}
	for e in liste:
		if vus.has(e[1]):
			continue
		vus[e[1]] = true
		out.append({"texte": str(e[1]).left(TEXTE_LONG), "secondes": snappedf(e[0] / maxf(j.speed, 0.1), 1.0), "cote": _cote(j, e[2])})
		if out.size() >= ECRITS_MAX:
			break
	return out


func _cote(j: Node3D, at: Vector3) -> String:
	var to := _a_plat(at - j.global_position)
	if to.length() < 0.3:
		return "ici"
	var face := _a_plat(-j.global_basis.z).normalized()
	var a := rad_to_deg(face.signed_angle_to(to.normalized(), Vector3.UP))
	var ou := _vers(_cardinal(to))
	if absf(a) < 35.0:
		return "devant, " + ou
	if absf(a) > 145.0:
		return "derrière, " + ou
	return ("à gauche, " if a > 0.0 else "à droite, ") + ou


func _a_plat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Les autres joueurs et pensionnaires à portée (autoload Presences), et ce qu'ils disent.
func _gens(j: CharacterBody3D) -> Array:
	var out := []
	var pr: Node = get_node_or_null("/root/Presences")
	if pr == null or j == null:
		return out
	for a in pr.autour():
		var e := {"nom": str(a.nom), "secondes": snappedf(float(a.distance) / maxf(j.speed, 0.1), 1.0), "cote": _cote(j, a.position)}
		if str(a.get("dit", "")) != "":
			e["dit"] = str(a.dit)
		out.append(e)
		if out.size() >= 12:
			break
	return out


## Les racines de ce qui est à l'écran : la scène en cours et les autoloads (une scène gardée par
## Chargement, cachée, n'en est pas).
func _racines() -> Array:
	var out := []
	for c in get_tree().root.get_children():
		if c == scene() or not (c is Node3D):
			out.append(c)
	return out


## Le panneau à l'écran qui se résume lui-même (pilote_resume()), ou null.
func _panneau_seul() -> Control:
	for r in _racines():
		for n in r.find_children("*", "Control", true, false):
			if n.has_method("pilote_resume") and (n as Control).is_visible_in_tree():
				return n
	return null


## Les boutons à l'écran ; seulement ceux d'un panneau (dans), s'il est donné.
func _boutons(dans: Node = null) -> Array:
	var out := []
	var ecran := get_viewport().get_visible_rect()
	for r in _racines():
		for b in r.find_children("*", "BaseButton", true, false):
			var bt := b as BaseButton
			if not bt.is_visible_in_tree() or bt.disabled or not ecran.intersects(bt.get_global_rect()):
				continue
			if dans != null and not dans.is_ancestor_of(bt):
				continue
			var t := _texte_du_bouton(bt)
			if t == "":
				continue
			var id := "b%d" % (out.size() + 1)
			_reperes[id] = bt
			var e := {"id": id, "texte": t}
			if bt.toggle_mode and bt.button_pressed:
				e["choisi"] = true
			if bt.has_meta("selected") and bt.get_meta("selected"):
				e["choisi"] = true
			out.append(e)
			if out.size() >= BOUTONS_MAX:
				return out
	return out


## Les champs à l'écran où l'on peut écrire : leur invite (le texte grisé), et ce qui y est déjà écrit.
func _champs() -> Array:
	var out := []
	var ecran := get_viewport().get_visible_rect()
	for r in _racines():
		for n in r.find_children("*", "Control", true, false):
			if not (n is LineEdit or n is TextEdit):
				continue
			var c := n as Control
			if not c.is_visible_in_tree() or not bool(c.get("editable")) or not ecran.intersects(c.get_global_rect()):
				continue
			var id := "f%d" % (out.size() + 1)
			_reperes[id] = c
			var e := {"id": id, "invite": str(c.get("placeholder_text")).strip_edges().left(80), "texte": str(c.get("text")).left(TEXTE_LONG)}
			if c.has_focus():
				e["actif"] = true
			out.append(e)
			if out.size() >= CHAMPS_MAX:
				return out
	return out


## Écrire dans un champ : on le prend (un clic, comme du doigt), et le texte s'y tape à la suite de ce qui
## y est déjà. Sans champ nommé, celui qui a la main, sinon le seul à l'écran.
func _ecrire(quoi: String, texte: String) -> Dictionary:
	var t := texte.strip_edges().left(ECRIT_LONG)
	if t == "":
		return {"ok": false, "dit": "rien à écrire"}
	var champs := _champs()
	if champs.is_empty():
		return {"ok": false, "dit": "pas de champ où écrire à l'écran"}
	var c: Control = null
	var cherche := quoi.strip_edges().to_lower()
	for e in champs:
		if cherche == "" and e.get("actif", false):
			c = _reperes[e.id]
		elif cherche != "" and (e.id == cherche or str(e.invite).to_lower().contains(cherche)):
			c = _reperes[e.id]
			break
	if c == null and cherche == "" and champs.size() == 1:
		c = _reperes[champs[0].id]
	if c == null:
		return {"ok": false, "dit": "quel champ ? (%s)" % ", ".join(champs.map(func(e): return "%s « %s »" % [e.id, e.invite]))}
	await _clic(c.get_global_rect().get_center())
	if not c.has_focus():
		c.grab_focus()
	await get_tree().process_frame
	var avant := str(c.get("text"))
	if c is LineEdit:
		(c as LineEdit).caret_column = avant.length()
		(c as LineEdit).insert_text_at_caret(t)
	else:
		var te := c as TextEdit
		te.set_caret_line(te.get_line_count() - 1)
		te.set_caret_column(te.get_line(te.get_line_count() - 1).length())
		te.insert_text_at_caret(t)
	await get_tree().process_frame
	var ecrit := str(c.get("text"))
	if ecrit == avant:
		return {"ok": false, "dit": "le champ n'a rien pris (plein ?)"}
	return {"ok": true, "dit": "écrit dans le champ : « %s » (pour l'envoyer, son bouton, ou la touche Entrée)" % ecrit.left(TEXTE_LONG)}


func _texte_du_bouton(b: BaseButton) -> String:
	var t := ""
	if "text" in b:
		t = str(b.text).strip_edges()
	if t == "":
		t = b.tooltip_text.strip_edges()
	return t.left(80)


## Les cases d'un tapis où l'on est assis (le socle des tables 3D).
func _cases() -> Array:
	var out := []
	var s := scene()
	if s != null:
		for t in s.find_children("*", "Node3D", true, false):
			if "cells" in t and "active" in t and t.active and t.has_signal("cell_clicked") and t.get("cam") != null:
				for k in t.cells:
					var id := "c:%s" % k
					_reperes[id] = [t, k]
					out.append(k)
	for c in _plateaux():
		var rects: Dictionary = c.pilote_cases()
		for k in rects:
			var id := "c:%s" % k
			_reperes[id] = [c, str(k), rects[k]]
			out.append(str(k))
	return out


## Les plateaux dessinés à l'écran (un échiquier) : les contrôles visibles qui donnent leurs cases.
func _plateaux() -> Array:
	var out := []
	for r in _racines():
		for n in r.find_children("*", "Control", true, false):
			if n.has_method("pilote_cases") and (n as Control).is_visible_in_tree():
				out.append(n)
	return out


func _textes(sauf: String) -> Array:
	var out := []
	var vus := {sauf: true}
	for r in _racines():
		for n in r.find_children("*", "Control", true, false):
			if not (n is Label or n is RichTextLabel):
				continue
			var c := n as Control
			# Ce qui est posé sur l'écran, même un peu au-delà de son bord (une bulle au-dessus d'une tête
			# proche, le nom d'un joueur à la table) ; pas ce qui s'efface.
			if not c.is_visible_in_tree() or _opacite(c) < 0.1:
				continue
			if c.get_parent() is BaseButton:
				continue
			var t: String = (c as RichTextLabel).get_parsed_text() if c is RichTextLabel else (c as Label).text
			t = t.strip_edges().replace("\n", " · ")
			if t == "" or vus.has(t):
				continue
			vus[t] = true
			out.append(t.left(TEXTE_LONG))
			if out.size() >= TEXTES_MAX:
				return out
	return out


## L'opacité d'un contrôle avec celle de ses parents (une bulle qui s'efface par son cadre).
func _opacite(c: CanvasItem) -> float:
	var a := 1.0
	var n: Node = c
	while n is CanvasItem:
		a *= (n as CanvasItem).modulate.a * (n as CanvasItem).self_modulate.a
		n = n.get_parent()
	return a


# --- Les gestes -----------------------------------------------------------------------------------

## Fait un geste et rend {ok, dit}, puis la vue qui suit (vue). Les repères sont ceux de la dernière vue.
func geste(g: Dictionary) -> Dictionary:
	# Personne ne regarde l'écran entre deux gestes : il ne se dessine que pour l'image (le rendu
	# logiciel d'une image coûte plus que tout le reste du jeu, et la marche en prendrait du retard).
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
	var quoi := str(g.get("geste", ""))
	var r := {}
	match quoi:
		"regarder":
			r = {"ok": true, "dit": ""}
		"aller":
			r = await _aller(str(g.get("vers", "")))
		"marcher":
			r = await _marcher(str(g.get("vers", "devant")), float(g.get("secondes", 2.0)), float(g.get("metres", 0.0)))
		"touche":
			r = await _touche(str(g.get("touche", "")))
		"cliquer":
			r = await _cliquer(str(g.get("quoi", "")))
		"ecrire":
			r = await _ecrire(str(g.get("quoi", "")), str(g.get("texte", "")))
		"attendre":
			await _attendre(clampf(float(g.get("secondes", 3.0)), 0.5, ATTENTE_MAX))
			r = {"ok": true, "dit": ""}
		"dire":
			var t := str(g.get("texte", "")).strip_edges().left(400)
			if t == "":
				r = {"ok": false, "dit": "rien à dire"}
			else:
				paroles.append(t)
				# Les joueurs autour la lisent en bulle au-dessus de sa tête (Presences, l'état porté).
				_dits += 1
				var pr: Node = get_node_or_null("/root/Presences")
				if pr:
					pr.etat_libre = {"dit": t, "k": _dits}
				r = {"ok": true, "dit": "tu dis : « %s » (en bulle, lue par qui est autour de toi)" % t}
		_:
			r = {"ok": false, "dit": "geste inconnu"}
	r["vue"] = vue()
	# Ce qu'il a sous les yeux, en image, quand il regarde (un plan, des chiffres gravés). Pas à chaque geste :
	# le rendu logiciel d'une image et son envoi retardaient chaque pas d'une ou deux secondes.
	if quoi == "regarder":
		r.merge(await image_et_camera())
	if not entendu.is_empty():
		r["entendu"] = entendu.duplicate()
		entendu.clear()
	return r


## {image, image_vue} : l'écran en JPEG et la caméra qui l'a fait ; vide sans rendu (--headless, les essais).
func image_et_camera() -> Dictionary:
	var img := await image()
	if img == "":
		return {}
	# De quelle vue il s'agit : à pied (« oeil ») ou la caméra de dessus qui le suit (« dessus »).
	return {"image": img, "image_vue": image_vue()}


## L'écran en JPEG (base64), large de IMAGE_LARGE pixels ; « » sans rendu (--headless, les essais).
func image() -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	RenderingServer.render_loop_enabled = true
	# Deux images : la première rattrape ce qui a bougé depuis la dernière.
	for i in 2:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	if img == null or img.is_empty():
		return ""
	if img.get_width() > IMAGE_LARGE:
		img.resize(IMAGE_LARGE, int(round(IMAGE_LARGE * img.get_height() / float(img.get_width()))), Image.INTERPOLATE_BILINEAR)
	return Marshalls.raw_to_base64(img.save_jpg_to_buffer(IMAGE_QUALITE))


## La caméra qui a fait l'image : « dessus » quand la caméra de maquette le suit, « oeil » à pied.
func image_vue() -> String:
	var j := joueur()
	if j != null and "follow_camera" in j and j.get("follow_camera") != null:
		return "dessus"
	return "oeil"


func _attendre(s: float) -> void:
	await get_tree().create_timer(s, true, true).timeout


## Le repère d'une vue, ou une zone dont l'invite contient le texte donné.
func _repere(quoi: String) -> Variant:
	if _reperes.has(quoi):
		var n = _reperes[quoi]
		if n is Array:
			return n if is_instance_valid(n[0]) else null
		if n is Dictionary:
			return n if is_instance_valid(n.objet) else null
		return n if is_instance_valid(n) else null
	var cherche := quoi.to_lower().strip_edges()
	if cherche == "":
		return null
	# Une case nommée sans son « c: » (« e2 »).
	if _reperes.has("c:" + quoi.strip_edges()):
		return _repere("c:" + quoi.strip_edges())
	for z in _toutes_les_zones():
		if _invite_de(z).to_lower().contains(cherche):
			return z
	# Une chose vue à la dernière vue, par son nom (« herse »), sinon déjà vue dans ce lieu.
	for liste in [_reperes, _vus]:
		for k in liste:
			var o = liste[k]
			if o is Dictionary and is_instance_valid(o.objet) and str(o.nom).contains(cherche) and _vus_lieu == scene():
				return o
	for r in _racines():
		for b in r.find_children("*", "BaseButton", true, false):
			if (b as BaseButton).is_visible_in_tree() and _texte_du_bouton(b).to_lower().contains(cherche):
				return b
	# Une case par un mot de son nom (« café » pour « Café de la Place »).
	for k in _reperes:
		if str(k).begins_with("c:") and str(k).to_lower().contains(cherche):
			return _repere(k)
	return null


func _aller(vers: String) -> Dictionary:
	var j := joueur()
	if j == null:
		return {"ok": false, "dit": "pas de corps ici"}
	if j.frozen:
		return {"ok": false, "dit": "assis : il faut d'abord se lever (Quitter, ou Échap)"}
	var z = _repere(vers)
	if z is Dictionary:
		return await _aller_a(j, z)
	if not (z is Area3D):
		var piece := _piece(vers)
		if not piece.is_empty():
			return await _aller_piece(j, piece)
		return {"ok": false, "dit": "zone ou chose inconnue : %s (une zone z3, une chose o2, un mot de son nom, ou une pièce du lieu)" % vers}
	var zone: Area3D = z
	if j.focus_target == zone:
		return {"ok": true, "dit": "déjà devant"}
	var t0 := Time.get_ticks_msec() / 1000.0
	var sc := scene()
	var loin := zone.global_position.distance_to(j.global_position)
	# Un chemin entre les obstacles, sur une grille où le corps tient debout, jusqu'à portée de la zone.
	var chemin := _chemin(j, _centre_zone(zone))
	# Le temps de chercher ne se compte pas dans celui de marcher.
	t0 = Time.get_ticks_msec() / 1000.0
	var essais := 0
	while true:
		var fin := await _suivre(j, zone, zone.global_position, chemin, t0, sc)
		if fin != "":
			_arreter(j)
			if fin == "pas trouvé de chemin jusque-là" and _en_route(j, zone, loin) != "":
				return {"ok": false, "dit": _en_route(j, zone, loin)}
			return {"ok": fin == "arrivé" or fin == "le lieu a changé en chemin", "dit": fin}
		# Au bout du chemin sans voir l'invite : on regarde autour, comme à la souris.
		if await _chercher_du_regard(j, zone):
			return {"ok": true, "dit": "arrivé"}
		essais += 1
		if essais >= 3 or Time.get_ticks_msec() / 1000.0 - t0 > MARCHE_MAX:
			_arreter(j)
			if _en_route(j, zone, loin) != "":
				return {"ok": false, "dit": _en_route(j, zone, loin)}
			return {"ok": false, "dit": "pas trouvé de chemin jusque-là : quelque chose barre le passage (une porte fermée, un cordon ?)"}
		var t1 := Time.get_ticks_msec() / 1000.0
		chemin = _chemin(j, _centre_zone(zone), essais)
		t0 += Time.get_ticks_msec() / 1000.0 - t1
	return {}


## Jusqu'à une chose vue (une herse, une bascule) : à portée de main, tourné vers elle.
func _aller_a(j: CharacterBody3D, o: Dictionary) -> Dictionary:
	var n: Node3D = o.objet
	var b: AABB = o.boite
	var but := Vector3(b.get_center().x, maxf(b.position.y, j.global_position.y - ETAGE), b.get_center().z)
	var proche := func() -> bool:
		return _a_plat(but - j.global_position).length() <= maxf(j.reach * 0.7, maxf(b.size.x, b.size.z) * 0.5 + j.radius * 2.0)
	if proche.call():
		_viser(j, b.get_center(), true)
		return {"ok": true, "dit": "déjà tout près"}
	var sc := scene()
	var t0 := Time.get_ticks_msec() / 1000.0
	for essai in 3:
		# D'abord dessus (une bascule, une dalle : on y monte), sinon au plus près (une herse, un mur).
		var chemin := _chemin(j, but, essai, j.radius if essai == 0 else -1.0)
		t0 = Time.get_ticks_msec() / 1000.0
		var fin := await _suivre(j, n, but, chemin, t0, sc)
		_arreter(j)
		if fin == "le lieu a changé en chemin":
			return {"ok": true, "dit": fin}
		if not is_instance_valid(j) or not is_instance_valid(n):
			return {"ok": false, "dit": "elle n'est plus là"}
		if proche.call():
			_viser(j, b.get_center(), true)
			var dessus := _a_plat(but - j.global_position).length() < maxf(j.radius * 2.0, 0.6)
			return {"ok": true, "dit": ("arrivé, sur : " if dessus else "arrivé, tout près de : ") + str(o.nom)}
	return {"ok": false, "dit": "pas trouvé de chemin jusque-là (encore %s m) : quelque chose barre le passage" % str(snappedf(_a_plat(but - j.global_position).length(), 0.5))}


## Une pièce du lieu par son nom (« Salle des Ambassadeurs ») : les lieux qui nomment leurs pièces (ROOMS du
## casino : [nom, x0, x1, z0, z1, étage]) ; {nom, centre, rect, etage}, ou {} si aucune ne répond.
func _piece(vers: String) -> Dictionary:
	var s := scene()
	if s == null or not (s is Node3D):
		return {}
	var pieces = s.get("ROOMS")
	if not (pieces is Array):
		return {}
	var cherche := _sans_articles(vers)
	if cherche == "":
		return {}
	var haut := float(s.get("WALL_H")) if s.get("WALL_H") != null else 5.0
	for r in pieces:
		if not (r is Array) or r.size() < 5:
			continue
		var nom := str(r[0])
		var n := _sans_articles(nom)
		if n == cherche or n.contains(cherche) or cherche.contains(n):
			var etage := int(r[5]) if r.size() > 5 else 0
			var centre := (s as Node3D).to_global(Vector3((float(r[1]) + float(r[2])) / 2.0, haut * etage, (float(r[3]) + float(r[4])) / 2.0))
			return {"nom": nom, "centre": centre, "rect": Rect2(float(r[1]), float(r[3]), float(r[2]) - float(r[1]), float(r[4]) - float(r[3])), "etage": etage}
	return {}


## Un nom sans ses articles ni sa casse (« La Salle des Ambassadeurs » -> « salle des ambassadeurs »).
func _sans_articles(t: String) -> String:
	var mots := []
	for m in t.to_lower().strip_edges().replace("'", " ").replace("’", " ").split(" ", false):
		if not m in ["le", "la", "les", "l", "au", "aux"]:
			mots.append(m)
	return " ".join(mots)


## Vrai si le corps est dans la pièce (à son étage).
func _dans_piece(j: CharacterBody3D, p: Dictionary) -> bool:
	var s := scene() as Node3D
	if s == null:
		return false
	var l := s.to_local(j.global_position)
	return (p.rect as Rect2).has_point(Vector2(l.x, l.z)) and (1 if l.y > 3.0 else 0) == int(p.etage)


## Jusque dans une pièce, par son nom : on marche vers son milieu et l'on s'arrête dès qu'on y est.
func _aller_piece(j: CharacterBody3D, p: Dictionary) -> Dictionary:
	if _dans_piece(j, p):
		return {"ok": true, "dit": "déjà dans " + str(p.nom)}
	var sc := scene()
	var but: Vector3 = p.centre
	var loin := _a_plat(but - j.global_position).length()
	for essai in 3:
		var chemin := _chemin(j, but, essai, 2.5)
		var t0 := Time.get_ticks_msec() / 1000.0
		var fin := await _suivre(j, null, but, chemin, t0, sc)
		_arreter(j)
		if fin == "le lieu a changé en chemin":
			return {"ok": true, "dit": fin}
		if not is_instance_valid(j):
			return {"ok": false, "dit": "le lieu a changé en chemin"}
		if _dans_piece(j, p):
			return {"ok": true, "dit": "arrivé dans " + str(p.nom)}
	var reste := _a_plat(but - j.global_position).length()
	if reste < loin - 5.0:
		return {"ok": false, "dit": "en route vers %s, encore environ %d m : refais « aller » pour continuer" % [str(p.nom), int(snappedf(reste, 5.0))]}
	return {"ok": false, "dit": "pas trouvé de chemin jusqu'à %s : quelque chose barre le passage (un cordon : la salle n'est peut-être pas encore ouverte pour toi)" % str(p.nom)}


## Un long trajet se fait en plusieurs gestes, comme un joueur qui marche longtemps : s'il a bien
## avancé, il le dit et l'on continue d'un nouveau « aller » vers la même zone.
func _en_route(j: CharacterBody3D, zone: Area3D, loin: float) -> String:
	if not is_instance_valid(zone):
		return ""
	var reste := zone.global_position.distance_to(j.global_position)
	if reste > loin - 5.0:
		return ""
	return "en route, encore une cinquantaine de mètres au plus : refais « aller » vers la même zone pour continuer" if reste < 50.0 \
		else "en route, encore environ %d m : refais « aller » vers la même zone pour continuer" % int(snappedf(reste, 10.0))


## Suit le chemin : « » au bout, sinon ce qui l'arrête (arrivé, le lieu a changé, trop long).
func _suivre(j: CharacterBody3D, zone: Node3D, but: Vector3, chemin: Array, t0: float, sc: Node) -> String:
	var k := 0
	var dernier := j.global_position
	var depuis := Time.get_ticks_msec() / 1000.0
	while true:
		await get_tree().physics_frame
		if not is_instance_valid(j) or scene() != sc:
			return "le lieu a changé en chemin"
		if is_instance_valid(zone) and j.focus_target == zone:
			return "arrivé"
		var maintenant := Time.get_ticks_msec() / 1000.0
		if maintenant - t0 > MARCHE_MAX:
			return "pas trouvé de chemin jusque-là"
		while k < chemin.size() and _a_plat(chemin[k] - j.global_position).length() < 0.25 * maxf(j.radius / 0.3, 0.5):
			k += 1
		var cible: Vector3 = chemin[k] if k < chemin.size() else but
		var to := _a_plat(cible - j.global_position)
		if k >= chemin.size() and to.length() < j.reach * 0.6:
			_arreter(j)
			return ""
		if j.global_position.distance_to(dernier) > 0.1:
			dernier = j.global_position
			depuis = maintenant
		elif maintenant - depuis > BUTE * 2.0:
			_arreter(j)
			return ""
		_viser(j, but if k >= chemin.size() - 1 else cible, _a_plat(but - j.global_position).length() < j.reach * 1.5)
		_pousser(j, to.normalized())
	return ""


## Devant la zone sans son invite : on tourne la tête et le regard, un cran à la fois.
func _chercher_du_regard(j: CharacterBody3D, zone: Area3D) -> bool:
	var to := zone.global_position - j.global_position
	var lacet := atan2(-to.x, -to.z)
	for dl in [0.0, 0.3, -0.3, 0.6, -0.6, 0.9, -0.9]:
		for tangage in [0.0, -0.35, -0.7, 0.3]:
			if j.follow_camera == null:
				j.rotation.y = lacet + dl
				if j.camera:
					j.camera.rotation.x = tangage
			else:
				j.rotation.y = lacet + dl
			await get_tree().physics_frame
			await get_tree().physics_frame
			if is_instance_valid(zone) and j.focus_target == zone:
				return true
	return false


## Le chemin (points du monde) du corps jusqu'à portée de la zone, par une recherche A* sur une grille
## où l'on teste, case par case, que le corps y tient sans toucher un obstacle. Chaque case porte la
## hauteur de son sol, cherchée d'un rayon vers le bas à une marche près de la case d'où l'on vient :
## ainsi le chemin monte les escaliers et passe d'un étage à l'autre, comme un joueur. Rien de propre à
## un lieu : seulement la physique de la scène. `ecart` élargit la recherche aux essais suivants.
## `portee` : à quelle distance du but on s'arrête (par défaut, à portée de main d'une zone).
func _chemin(j: CharacterBody3D, but: Vector3, ecart := 0, portee := -1.0) -> Array:
	var depart := j.global_position
	# Une zone d'un autre étage : l'escalier peut être loin, on cherche plus large.
	var etage := absf(but.y - depart.y) > ETAGE
	# Aux essais suivants, bien plus large : le chemin fait parfois un grand détour (redescendre une butte
	# pour contourner une carrière, Chauvigny), hors d'une bande de quelques mètres autour du trajet direct.
	var marge := (60.0 + 15.0 * ecart if etage else 6.0 + 30.0 * ecart)
	var pas: float = maxf(j.radius * 1.2, 0.12)
	var lo := Vector2(minf(depart.x, but.x) - marge, minf(depart.z, but.z) - marge)
	var hi := Vector2(maxf(depart.x, but.x) + marge, maxf(depart.z, but.z) + marge)
	var nx := mini(int((hi.x - lo.x) / pas) + 1, GRILLE_MAX)
	var nz := mini(int((hi.y - lo.y) / pas) + 1, GRILLE_MAX)
	pas = maxf((hi.x - lo.x) / nx, (hi.y - lo.y) / nz)
	var espace := j.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = j.radius * 0.9
	cap.height = maxf(j.body_height - j.step_height, cap.radius * 2.0)
	q.shape = cap
	q.collide_with_areas = false
	q.exclude = [j.get_rid()]
	# Seulement ce que le corps heurte : pas les volumes que seule la caméra évite (les houppiers).
	q.collision_mask = j.collision_mask
	var r := PhysicsRayQueryParameters3D.new()
	r.collide_with_areas = false
	r.exclude = [j.get_rid()]
	r.collision_mask = j.collision_mask
	var marche: float = j.step_height
	var centre := func(x: int, z: int) -> Vector2:
		return Vector2(lo.x + (x + 0.5) * pas, lo.y + (z + 0.5) * pas)
	# Le sol d'une case, à une marche près de la hauteur « y » : sa hauteur, ou NAN s'il n'y en a pas (un
	# vide, un mur, une pente trop raide).
	var sol := func(x: int, z: int, y: float) -> float:
		var c: Vector2 = centre.call(x, z)
		r.from = Vector3(c.x, y + marche + 0.1, c.y)
		r.to = Vector3(c.x, y - marche - 0.1, c.y)
		var h := espace.intersect_ray(r)
		if h.is_empty() or (h.normal as Vector3).y < 0.6:
			return NAN
		return (h.position as Vector3).y
	var libre := {}
	var tient := func(x: int, z: int, y: float) -> bool:
		var k := Vector3i(x, z, roundi(y * 4.0))
		if libre.has(k):
			return libre[k]
		var c: Vector2 = centre.call(x, z)
		q.transform = Transform3D(Basis(), Vector3(c.x, y + marche + cap.height / 2.0 + 0.02, c.y))
		var ok := espace.intersect_shape(q, 1).is_empty()
		libre[k] = ok
		return ok
	var sx := clampi(int((depart.x - lo.x) / pas), 0, nx - 1)
	var sz := clampi(int((depart.z - lo.y) / pas), 0, nz - 1)
	var s := Vector3i(sx, sz, roundi(depart.y * 4.0))
	var hauteur := {s: depart.y}
	if portee < 0.0:
		portee = j.reach * (0.8 - 0.15 * ecart)
	var voisins := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var h0 := func(x: int, z: int, y: float) -> float:
		var c: Vector2 = centre.call(x, z)
		return (Vector2(but.x, but.z) - c).length() / pas + absf(but.y - y) / pas
	# A* sur un tas binaire : les cases à portée de la zone, à son étage, sont le but.
	var tas := _Tas.new()
	tas.mettre(0.0, s)
	var cout := {s: 0.0}
	var venu := {}
	var fin := Vector3i(-1, -1, 0)
	# La case la plus proche du but déjà atteinte : faute de chemin entier, on y va, et l'on cherche de
	# nouveau de là (un long trajet se fait en plusieurs morceaux).
	var proche := s
	var h_proche: float = h0.call(s.x, s.y, depart.y)
	var visites := 0
	var limite := Time.get_ticks_msec() + int(CHERCHE_MAX * 1000.0)
	while not tas.vide() and visites < VISITES_MAX:
		var c: Vector3i = tas.prendre()
		visites += 1
		if visites % 512 == 0 and Time.get_ticks_msec() > limite:
			break
		var y: float = hauteur[c]
		var w: Vector2 = centre.call(c.x, c.y)
		if c != s and (Vector2(but.x, but.z) - w).length() <= portee and but.y - y > -1.0 and but.y - y < ETAGE:
			fin = c
			break
		var hc: float = h0.call(c.x, c.y, y)
		if hc < h_proche:
			h_proche = hc
			proche = c
		for d in voisins:
			var x: int = c.x + d.x
			var z: int = c.y + d.y
			if x < 0 or z < 0 or x >= nx or z >= nz:
				continue
			var yn: float = sol.call(x, z, y)
			if is_nan(yn) or not tient.call(x, z, yn):
				continue
			if d.x != 0 and d.y != 0:
				var ya: float = sol.call(c.x + d.x, c.y, y)
				var yb: float = sol.call(c.x, c.y + d.y, y)
				if is_nan(ya) or is_nan(yb) or not tient.call(c.x + d.x, c.y, ya) or not tient.call(c.x, c.y + d.y, yb):
					continue
			var n := Vector3i(x, z, roundi(yn * 4.0))
			var g: float = cout[c] + (1.414 if d.x != 0 and d.y != 0 else 1.0) + absf(yn - y) / pas
			if g < cout.get(n, INF):
				cout[n] = g
				venu[n] = c
				hauteur[n] = yn
				tas.mettre(g + POIDS * h0.call(x, z, yn), n)
	if fin.x < 0:
		if proche == s:
			return [but]
		fin = proche
	var pts := []
	var c := fin
	while venu.has(c):
		var w: Vector2 = centre.call(c.x, c.y)
		pts.push_front(Vector3(w.x, hauteur[c], w.y))
		c = venu[c]
	# Un point sur trois suffit : le corps lisse entre eux.
	var out := []
	for i in pts.size():
		if i % 3 == 2 or i == pts.size() - 1:
			out.append(pts[i])
	return out


## Un tas binaire (le plus petit d'abord), pour la recherche du chemin.
class _Tas:
	var _cles: Array[float] = []
	var _vals: Array = []

	func vide() -> bool:
		return _cles.is_empty()

	func mettre(cle: float, val: Variant) -> void:
		_cles.append(cle)
		_vals.append(val)
		var i := _cles.size() - 1
		while i > 0:
			var p := (i - 1) / 2
			if _cles[p] <= _cles[i]:
				break
			_echanger(i, p)
			i = p

	func prendre() -> Variant:
		var v: Variant = _vals[0]
		var n := _cles.size() - 1
		_echanger(0, n)
		_cles.pop_back()
		_vals.pop_back()
		var i := 0
		while true:
			var g := 2 * i + 1
			var m := i
			if g < n and _cles[g] < _cles[m]:
				m = g
			if g + 1 < n and _cles[g + 1] < _cles[m]:
				m = g + 1
			if m == i:
				break
			_echanger(i, m)
			i = m
		return v

	func _echanger(a: int, b: int) -> void:
		var k := _cles[a]
		_cles[a] = _cles[b]
		_cles[b] = k
		var v: Variant = _vals[a]
		_vals[a] = _vals[b]
		_vals[b] = v


## Le milieu de la zone : celui de sa forme, posé où elle est.
func _centre_zone(zone: Area3D) -> Vector3:
	for c in zone.get_children():
		if c is CollisionShape3D:
			return (c as CollisionShape3D).global_position
	return zone.global_position


## Tourner le corps (et le regard) vers ce qu'on vise, comme à la souris.
func _viser(j: CharacterBody3D, at: Vector3, de_pres: bool) -> void:
	var to := at - j.global_position
	if j.follow_camera == null:
		j.rotation.y = atan2(-to.x, -to.z)
		if de_pres and j.camera:
			var oeil: Vector3 = j.camera.global_position
			var d: Vector3 = at - oeil
			j.camera.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-60.0), deg_to_rad(50.0))
		elif j.camera:
			j.camera.rotation.x = 0.0


## Marcher dans une direction du monde : le corps la reçoit dans son repère (ou celui de la caméra de dessus).
func _pousser(j: CharacterBody3D, dir_monde: Vector3) -> void:
	if dir_monde == Vector3.ZERO:
		j.auto_move = Vector3.ZERO
		return
	var base := Basis(Vector3.UP, j.global_rotation.y) if j.follow_camera == null else Basis(Vector3.UP, j.follow_camera.global_rotation.y)
	j.auto_move = (base.inverse() * dir_monde).normalized()


func _arreter(j: CharacterBody3D) -> void:
	if is_instance_valid(j):
		j.auto_move = Vector3.ZERO
		j.velocity.x = 0.0
		j.velocity.z = 0.0


## Vers un point cardinal (le plan a le nord en haut), ou devant, à gauche, à droite, derrière ; pendant
## quelques secondes, ou jusqu'à avoir fait « metres ». Un pilier qui accroche, on s'en dégage d'un pas
## de côté, comme un joueur qui tâtonne ; une paroi en face, on s'arrête et on le dit.
func _marcher(vers: String, secondes: float, metres := 0.0) -> Dictionary:
	var j := joueur()
	if j == null or j.frozen:
		return {"ok": false, "dit": "impossible de marcher maintenant"}
	var face := _a_plat(-j.global_basis.z).normalized()
	var angles := {"devant": 0.0, "gauche": 90.0, "derrière": 180.0, "derriere": 180.0, "droite": -90.0}
	var dir := _dir_cardinale(vers)
	if dir == Vector3.ZERO:
		if not angles.has(vers):
			return {"ok": false, "dit": "direction inconnue : nord, nord-est, est, sud-est, sud, sud-ouest, ouest, nord-ouest, ou devant, gauche, droite, derrière"}
		dir = face.rotated(Vector3.UP, deg_to_rad(angles[vers]))
	j.rotation.y = atan2(-dir.x, -dir.z)
	var duree := clampf(secondes, 0.5, 10.0)
	if metres > 0.0:
		metres = minf(metres, 30.0)
		duree = minf(metres / maxf(j.speed, 0.1) * 2.0 + 2.0, 20.0)
	var depart := j.global_position
	var fin := Time.get_ticks_msec() / 1000.0 + duree
	var sc := scene()
	var dernier := j.global_position
	var depuis := Time.get_ticks_msec() / 1000.0
	var cotes := 0
	var bloque := false
	while Time.get_ticks_msec() / 1000.0 < fin and is_instance_valid(j) and scene() == sc:
		if metres > 0.0 and _a_plat(j.global_position - depart).dot(dir) >= metres:
			break
		_pousser(j, dir)
		await get_tree().physics_frame
		var t := Time.get_ticks_msec() / 1000.0
		if _a_plat(j.global_position - dernier).dot(dir) > 0.15:
			dernier = j.global_position
			depuis = t
			continue
		if t - depuis < BUTE:
			continue
		# Accroché : un pas de biais, d'un côté puis de l'autre, puis on reprend la direction.
		var degage: bool = cotes < 4 and await _degager(j, dir, cotes)
		if not degage:
			bloque = true
			break
		cotes += 1
		# Le temps de se dégager ne se compte pas dans celui de marcher.
		fin += Time.get_ticks_msec() / 1000.0 - t
		dernier = j.global_position
		depuis = Time.get_ticks_msec() / 1000.0
	_arreter(j)
	if not is_instance_valid(j) or scene() != sc:
		return {"ok": true, "dit": "le lieu a changé en chemin"}
	var fait := _a_plat(j.global_position - depart).length()
	var dit := "tu as fait %s m %s" % [str(snappedf(fait, 0.1)), _vers(_cardinal(dir))]
	if metres > 0.0 and _a_plat(j.global_position - depart).dot(dir) < metres - 0.3:
		bloque = true
	if bloque:
		var paroi: String = _autour(j).get(_cardinal(dir), "")
		dit += " ; arrêté : on ne passe pas par là" + (" (%s)" % paroi if paroi != "" else "")
	return {"ok": true, "dit": dit}


## Un pas de biais (à 60°, de plus en plus large) pour décoller d'un pilier : vrai si l'on a bougé.
func _degager(j: CharacterBody3D, dir: Vector3, essai: int) -> bool:
	var avant := j.global_position
	var signe := 1.0 if essai % 2 == 0 else -1.0
	var biais := dir.rotated(Vector3.UP, deg_to_rad(signe * (60.0 + 30.0 * int(essai / 2))))
	for etape in [biais, -dir * 0.6 + biais * 0.4]:
		var t := Time.get_ticks_msec() / 1000.0 + 0.4
		while Time.get_ticks_msec() / 1000.0 < t and is_instance_valid(j):
			_pousser(j, (etape as Vector3).normalized())
			await get_tree().physics_frame
		if is_instance_valid(j) and _a_plat(j.global_position - avant).length() > 0.15:
			j.rotation.y = atan2(-dir.x, -dir.z)
			return true
	return false


func _touche(nom: String) -> Dictionary:
	var n := nom.strip_edges().to_upper()
	var k: int = TOUCHES.get(n, KEY_NONE)
	# Toute lettre du clavier : celle que le jeu affiche (« P : le plan »).
	if k == KEY_NONE and n.length() == 1 and n >= "A" and n <= "Z":
		k = OS.find_keycode_from_string(n)
	if k == KEY_NONE:
		return {"ok": false, "dit": "touche inconnue : %s" % nom}
	var avant := _empreinte()
	for appui in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = appui
		Input.parse_input_event(e)
		await get_tree().process_frame
	await _attendre(POSE)
	if _empreinte() == avant:
		return {"ok": true, "dit": "rien n'a changé à l'écran"}
	return {"ok": true, "dit": ""}


## Combien de contrôles s'affichent : un plan qui se déplie, un panneau dessiné, sans texte à lire.
func _controles_visibles() -> int:
	var n := 0
	for r in _racines():
		for c in r.find_children("*", "Control", true, false):
			if (c as Control).is_visible_in_tree():
				n += 1
	return n


## Ce qui se voit de l'écran, pour savoir si une touche y a changé quelque chose.
func _empreinte() -> String:
	var j := joueur()
	var t := [_nom_du_lieu(scene()), _textes(""), _boutons().map(func(b): return b.texte), _controles_visibles()]
	if j:
		t.append([j.frozen, j.focus_target, j.global_position.snapped(Vector3.ONE * 0.2)])
	for c in _plateaux():
		if c.has_method("pilote_texte"):
			t.append(str(c.pilote_texte()))
	return var_to_str(t)


func _cliquer(quoi: String) -> Dictionary:
	# Un coup sur un plateau, en un seul geste (« e2-e4 ») : le plateau le reconnaît et le joue.
	for c in _plateaux():
		if c.has_method("pilote_coup"):
			var avant_coup := _empreinte()
			var fait = c.pilote_coup(quoi)
			if fait is Dictionary:
				if fait.get("ok", false):
					# La réponse de l'adversaire vient avec (un robot répond tout de suite) : on l'attend
					# un peu, pour qu'un coup ne coûte qu'un geste.
					var seul := _panneau_seul()
					var t0 := Time.get_ticks_msec()
					while seul != null and seul.has_method("pilote_en_attente") and seul.pilote_en_attente() \
							and Time.get_ticks_msec() - t0 < REPONSE_COUP * 1000.0:
						await _attendre(0.25)
					await _poser(avant_coup)
				return fait
	var r = _repere(quoi)
	if r == null:
		return {"ok": false, "dit": "rien de tel à l'écran : %s" % quoi}
	var avant := _empreinte()
	if r is Array and r[0] is Control:
		# La case d'un plateau à l'écran : un clic de souris en son milieu, appuyé puis relâché.
		var c: Control = r[0]
		var at: Vector2 = (r[2] as Rect2).get_center()
		for appui in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.position = at
			e.global_position = c.get_global_transform() * at
			e.pressed = appui
			c._gui_input(e)
			await get_tree().process_frame
		await _poser(avant)
		return {"ok": true, "dit": ""}
	if r is Array:
		var table: Node3D = r[0]
		var cle: String = r[1]
		var ecran: Vector2 = table.cam.unproject_position(table.global_transform * table.cell_center(cle))
		var pris := [false]
		var vu := func(k: String): pris[0] = pris[0] or k == cle
		table.cell_clicked.connect(vu)
		await _clic(ecran)
		if not pris[0]:
			table.cell_clicked.emit(cle)
		table.cell_clicked.disconnect(vu)
		await _attendre(0.3)
		return {"ok": true, "dit": ""}
	if r is BaseButton:
		var b: BaseButton = r
		if b.disabled or not b.is_visible_in_tree():
			return {"ok": false, "dit": "ce bouton n'est pas disponible"}
		var presse := [false]
		var vu := func(): presse[0] = true
		b.pressed.connect(vu)
		await _clic(b.get_global_rect().get_center())
		if is_instance_valid(b):
			if not presse[0] and not b.disabled:
				# Sans écran, le clic ne trouve pas toujours sa cible : on appuie sur le bouton lui-même.
				if b.toggle_mode:
					b.button_pressed = not b.button_pressed
				b.pressed.emit()
			if b.pressed.is_connected(vu):
				b.pressed.disconnect(vu)
		await _poser(avant)
		return {"ok": true, "dit": ""}
	return {"ok": false, "dit": "on ne clique pas sur une zone : il faut aller devant et appuyer sur E"}


## Après un clic : le temps de pose, puis, si l'écran change (la réponse d'une table en ligne qui arrive
## un peu plus tard), jusqu'à ce qu'il reste calme ; s'il ne change pas, on n'attend pas plus.
func _poser(avant: String) -> void:
	await _attendre(POSE)
	var t0 := Time.get_ticks_msec()
	var vu := _empreinte()
	var calme := t0
	while Time.get_ticks_msec() - t0 < (POSE_MAX - POSE) * 1000.0:
		if vu == avant and Time.get_ticks_msec() - t0 >= (POSE_RIEN - POSE) * 1000.0:
			return
		if vu != avant and Time.get_ticks_msec() - calme >= POSE_CALME * 1000.0:
			return
		await _attendre(0.25)
		var n := _empreinte()
		if n != vu:
			vu = n
			calme = Time.get_ticks_msec()


func _clic(at: Vector2) -> void:
	var vp := get_viewport()
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	vp.push_input(m)
	for appui in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = appui
		vp.push_input(e)
		await get_tree().process_frame
