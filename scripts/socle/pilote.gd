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
## - ce qui l'entoure : de chaque côté, jusqu'où l'on peut marcher avant une paroi.
## - l'écran lui-même, en image, quand le jeu se dessine (la tâche le lance sous un écran virtuel).
## Ne se voit que ce qu'aucun mur ne cache : une zone de l'autre côté d'une paroi n'est pas montrée.
##
## Ce qu'il fait (geste) :
## - aller : marcher jusqu'à être devant une zone, comme on le ferait aux flèches ;
## - marcher : avancer quelques secondes dans une direction ;
## - touche : une touche du clavier (E, Espace, Échap, Entrée, Tab, une lettre, un chiffre) ;
## - cliquer : un bouton, une case du tapis ou du plateau, par un clic de souris à sa place à l'écran ;
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
		var reseau: Node = load("res://scripts/socle/pilote_reseau.gd").new()
		reseau.name = "Reseau"
		add_child(reseau)


func _on_etat_change(membre: String, e: Dictionary) -> void:
	var pr: Node = get_node_or_null("/root/Presences")
	var p: Dictionary = pr.presents.get(membre, {}) if pr else {}
	if p.is_empty() or not p.get("a_portee", false) or not (e.get("dit") is String) or str(e.dit) == "":
		return
	entendu.append({"nom": str(p.get("nom", "")), "dit": str(e.dit).left(200)})
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
	if j:
		v["devant"] = _invite_de(j.focus_target) if j.focus_target and not j.frozen else ""
		v["assis"] = j.frozen
		v["zones"] = [] if j.frozen else _zones(j)
	var gens := _gens(j)
	if not gens.is_empty():
		v["gens"] = gens
	v["boutons"] = _boutons()
	var cases := _cases()
	if not cases.is_empty():
		v["cases"] = cases
	if j and not j.frozen:
		v["autour"] = _autour(j)
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
func _en_vue(j: CharacterBody3D, z: Node3D) -> bool:
	var at := z.global_position
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
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		cibles.append(at + d * pas * 0.7 + Vector3.UP * haut * 0.5)
	var lieu := _parent_sous_scene(z)
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
	var face := _a_plat(-j.global_basis.z).normalized()
	if face.length() < 0.5:
		return out
	var de := j.global_position + Vector3.UP * minf(_yeux(j).y - j.global_position.y, 1.6) * 0.75
	var espace := j.get_world_3d().direct_space_state
	for c in [["devant", 0.0], ["devant à droite", -45.0], ["à droite", -90.0], ["derrière à droite", -135.0],
			["derrière", 180.0], ["derrière à gauche", 135.0], ["à gauche", 90.0], ["devant à gauche", 45.0]]:
		var dir := face.rotated(Vector3.UP, deg_to_rad(c[1]))
		var q := PhysicsRayQueryParameters3D.create(de, de + dir * AUTOUR_LOIN, j.collision_mask, [j.get_rid()])
		var hit := espace.intersect_ray(q)
		if hit.is_empty():
			out[c[0]] = "libre sur %d m et plus" % int(AUTOUR_LOIN)
			continue
		var m := _a_plat(hit.position - de).length()
		var t := "paroi à %s m" % (str(snappedf(m, 0.1)) if m < 3.0 else str(int(round(m))))
		var quoi := _libelle_de(hit.collider)
		out[c[0]] = t + (" (%s)" % quoi if quoi != "" else "")
	return out


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
	if absf(a) < 35.0:
		return "devant"
	if absf(a) > 145.0:
		return "derrière"
	return "à gauche" if a > 0.0 else "à droite"


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


func _boutons() -> Array:
	var out := []
	var ecran := get_viewport().get_visible_rect()
	for r in _racines():
		for b in r.find_children("*", "BaseButton", true, false):
			var bt := b as BaseButton
			if not bt.is_visible_in_tree() or bt.disabled or not ecran.intersects(bt.get_global_rect()):
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
			r = await _marcher(str(g.get("vers", "devant")), float(g.get("secondes", 2.0)))
		"touche":
			r = await _touche(str(g.get("touche", "")))
		"cliquer":
			r = await _cliquer(str(g.get("quoi", "")))
		"attendre":
			await _attendre(clampf(float(g.get("secondes", 3.0)), 0.5, ATTENTE_MAX))
			r = {"ok": true, "dit": ""}
		"dire":
			var t := str(g.get("texte", "")).strip_edges().left(200)
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
	# Ce qu'il a sous les yeux, en image, quand le jeu se dessine (un plan, des chiffres gravés).
	var img := await image()
	if img != "":
		r["image"] = img
	if not entendu.is_empty():
		r["entendu"] = entendu.duplicate()
		entendu.clear()
	return r


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


func _attendre(s: float) -> void:
	await get_tree().create_timer(s, true, true).timeout


## Le repère d'une vue, ou une zone dont l'invite contient le texte donné.
func _repere(quoi: String) -> Variant:
	if _reperes.has(quoi):
		var n = _reperes[quoi]
		if n is Array:
			return n if is_instance_valid(n[0]) else null
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
	for r in _racines():
		for b in r.find_children("*", "BaseButton", true, false):
			if (b as BaseButton).is_visible_in_tree() and _texte_du_bouton(b).to_lower().contains(cherche):
				return b
	return null


func _aller(vers: String) -> Dictionary:
	var j := joueur()
	if j == null:
		return {"ok": false, "dit": "pas de corps ici"}
	if j.frozen:
		return {"ok": false, "dit": "assis : il faut d'abord se lever (Quitter, ou Échap)"}
	var z = _repere(vers)
	if not (z is Area3D):
		return {"ok": false, "dit": "zone inconnue : %s" % vers}
	var zone: Area3D = z
	if j.focus_target == zone:
		return {"ok": true, "dit": "déjà devant"}
	var t0 := Time.get_ticks_msec() / 1000.0
	var sc := scene()
	var loin := zone.global_position.distance_to(j.global_position)
	# Un chemin entre les obstacles, sur une grille où le corps tient debout, jusqu'à portée de la zone.
	var chemin := _chemin(j, zone)
	# Le temps de chercher ne se compte pas dans celui de marcher.
	t0 = Time.get_ticks_msec() / 1000.0
	var essais := 0
	while true:
		var fin := await _suivre(j, zone, chemin, t0, sc)
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
		chemin = _chemin(j, zone, essais)
		t0 += Time.get_ticks_msec() / 1000.0 - t1
	return {}


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
func _suivre(j: CharacterBody3D, zone: Area3D, chemin: Array, t0: float, sc: Node) -> String:
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
		var cible: Vector3 = chemin[k] if k < chemin.size() else zone.global_position
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
		_viser(j, zone.global_position if k >= chemin.size() - 1 else cible, _a_plat(zone.global_position - j.global_position).length() < j.reach * 1.5)
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
func _chemin(j: CharacterBody3D, zone: Area3D, ecart := 0) -> Array:
	var depart := j.global_position
	var but := _centre_zone(zone)
	# Une zone d'un autre étage : l'escalier peut être loin, on cherche plus large.
	var etage := absf(but.y - depart.y) > ETAGE
	var marge := (60.0 + 15.0 * ecart if etage else 6.0 + 4.0 * ecart)
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
	var portee: float = j.reach * (0.8 - 0.15 * ecart)
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


func _marcher(vers: String, secondes: float) -> Dictionary:
	var j := joueur()
	if j == null or j.frozen:
		return {"ok": false, "dit": "impossible de marcher maintenant"}
	var face := _a_plat(-j.global_basis.z).normalized()
	var angles := {"devant": 0.0, "gauche": 90.0, "derrière": 180.0, "derriere": 180.0, "droite": -90.0}
	if not angles.has(vers):
		return {"ok": false, "dit": "direction inconnue : devant, gauche, droite ou derrière"}
	var dir := face.rotated(Vector3.UP, deg_to_rad(angles[vers]))
	j.rotation.y = atan2(-dir.x, -dir.z)
	var fin := Time.get_ticks_msec() / 1000.0 + clampf(secondes, 0.5, 10.0)
	var sc := scene()
	while Time.get_ticks_msec() / 1000.0 < fin and is_instance_valid(j) and scene() == sc:
		_pousser(j, dir)
		await get_tree().physics_frame
	_arreter(j)
	return {"ok": true, "dit": ""}


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
	var r = _repere(quoi)
	if r == null:
		return {"ok": false, "dit": "rien de tel à l'écran : %s" % quoi}
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
		await _attendre(POSE)
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
		await _attendre(POSE)
		return {"ok": true, "dit": ""}
	return {"ok": false, "dit": "on ne clique pas sur une zone : il faut aller devant et appuyer sur E"}


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
