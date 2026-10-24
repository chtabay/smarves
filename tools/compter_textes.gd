extends SceneTree
## Compte les mots visibles de chaque écran principal (chantier « Le (i) et la chasse aux textes ») :
## godot --headless --path . -s tools/compter_textes.gd -- [--sortie=mots.json] [--detail[=écran]]
## Un chiffre par écran, avant et après une passe, au lieu d'une impression. Un mot est un bout de texte
## qui porte au moins une lettre (« 20 346 » n'en est pas un, « cr. » oui), dans un Label, un Button ou un
## RichTextLabel visible ; le texte d'un (i) n'est pas compté tant que sa bulle est fermée.
## --sortie écrit {écran: mots} en JSON ; --detail imprime aussi les textes (tous, ou ceux d'un écran).
##
## Les écrans : l'accueil (l'écran titre et le panneau de la bienvenue), puis chaque page du carnet, avec une
## partie d'essai (une part de l'Étoile de Smarves à la cinquième journée, une commune greffée). Un écran
## de plus : une entrée dans ECRANS et sa fonction, qui ouvre l'écran et rend le nœud à compter.

const TMP := "user://compter_textes/"

var _detail := ""
var _lettre := RegEx.create_from_string("[A-Za-zÀ-ÖØ-öø-ÿŒœ]")


func _initialize() -> void:
	_lancer.call_deferred()


## Les mots d'un texte.
func mots(t: String) -> int:
	var n := 0
	for m in t.split(" ", false):
		for x in m.split("\n", false):
			if _lettre.search(x) != null:
				n += 1
	return n


## Les textes visibles sous un nœud.
func textes(n: Node, out: Array) -> Array:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return out
	if n is Label:
		out.append((n as Label).text)
	elif n is Button and n.name != "Aide":
		out.append((n as Button).text)
	elif n is RichTextLabel:
		out.append((n as RichTextLabel).get_parsed_text())
	for c in n.get_children():
		textes(c, out)
	return out


func _lancer() -> void:
	var sortie := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
		elif arg == "--detail":
			_detail = "*"
		elif arg.begins_with("--detail="):
			_detail = arg.trim_prefix("--detail=")
	root.size = Vector2i(1600, 900)
	var ecrans: Array = []
	await _accueil(ecrans)
	await _carnet(ecrans)
	var compte := {}
	var total := 0
	for e in ecrans:
		var n := 0
		for x in e[1]:
			n += mots(str(x))
		compte[e[0]] = n
		total += n
		print("%-44s %5d" % [e[0], n])
		if _detail == "*" or _detail == e[0]:
			for x in e[1]:
				if str(x).strip_edges() != "":
					print("    · " + str(x).replace("\n", " ⏎ "))
	print("%-44s %5d" % ["total", total])
	if sortie != "":
		var f := FileAccess.open(sortie, FileAccess.WRITE)
		f.store_string(JSON.stringify(compte, "\t"))
		print("écrit : " + sortie)
	root.get_node("Football").effacer()
	quit()


## Chaque écran ajoute [nom, ses textes visibles], relevés au moment où il est ouvert.

## L'accueil : l'écran titre et le panneau de la bienvenue, à droite.
func _accueil(out: Array) -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await create_timer(1.5).timeout
	var bienvenue: Node = root.get_node("Bienvenue")
	if not bienvenue.is_open():
		bienvenue.ouvrir()
	await process_frame
	out.append(["accueil", textes(current_scene, []) + textes(bienvenue.get("_root"), [])])
	bienvenue.fermer()
	unload_current_scene()
	await process_frame


## Le carnet, page par page : chaque rubrique, et chacune de ses pages.
func _carnet(out: Array) -> void:
	var foot: Node = root.get_node("Football")
	var game: Node = root.get_node("Game")
	var carnet: Node = root.get_node("Carnet")
	game.saving_enabled = false
	DirAccess.make_dir_recursive_absolute(TMP)
	foot.dossier = TMP
	foot.effacer()
	var t: int = foot.coup_envoi(1, 5) + 4 * 3600
	foot.regler_horloge(func(): return t)
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	foot.forcer_porteurs("vous:2", "smarves")
	carnet.toggle()
	for r in carnet.RUBRIQUES:
		var cle := str(r[0])
		carnet.ouvrir_onglet(cle)
		await process_frame
		var pages: Array = carnet.call("_sous_pages", cle)
		if pages.is_empty():
			out.append(["carnet · " + str(r[1]), textes(carnet.get("_root"), [])])
			continue
		for p in pages:
			if cle == "clubs":
				carnet.ouvrir_club(str(p[0]))
			else:
				carnet.ouvrir_onglet(str(p[0]))
			await process_frame
			out.append(["carnet · %s · %s" % [r[1], p[1]], textes(carnet.get("_root"), [])])
	carnet.toggle()
