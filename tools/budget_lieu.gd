extends SceneTree
## Le budget des lieux (scripts/socle/budget.gd) : chaque scène est bâtie, on attend quelques images, puis
## on compte ce qu'elle demande (triangles, surfaces dessinées, lampes et ombres, textures, nœuds, scripts
## actifs) et on dit ce qui dépasse les seuils.
##   godot --headless --path . -s tools/budget_lieu.gd                       les lieux de Smarves
##   godot --headless --path . -s tools/budget_lieu.gd -- --scenes=a.tscn,b   des scènes
##   godot --headless --path . -s tools/budget_lieu.gd -- --pck=…/x.pck       les lieux d'un paquet (sa scène
##                                                                           et celles de ses structures)
##   --json=chemin                                                           écrit aussi la mesure en JSON

const SCENES := ["res://scenes/main.tscn", "res://scenes/casino.tscn", "res://scenes/salle_basket.tscn",
	"res://scenes/stade.tscn", "res://scenes/cafe.tscn", "res://scenes/commerce.tscn", "res://scenes/salle_jeu.tscn"]
const IMAGES := 4


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true
	Engine.max_fps = 0
	var scenes := SCENES
	var json := ""
	var pck := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenes="):
			scenes = Array(a.trim_prefix("--scenes=").split(","))
		elif a.begins_with("--json="):
			json = a.trim_prefix("--json=")
		elif a.begins_with("--pck="):
			pck = a.trim_prefix("--pck=")
	if pck != "":
		scenes = _scenes_du_paquet(pck)
		if scenes.is_empty():
			quit(1)
			return
	var mesures := {}
	for s in scenes:
		var m := await mesurer(s)
		mesures[s] = m
		var dep := Budget.depassements(m)
		print("%s : %s%s" % [s.get_file(), Budget.resume(m), "" if dep.is_empty() else "\n   À alléger : " + " ; ".join(dep)])
	if json != "":
		var f := FileAccess.open(json, FileAccess.WRITE)
		f.store_string(JSON.stringify(mesures, "  "))
	quit(0)


## Bâtit la scène, attend IMAGES images et ses niveaux de détail, mesure, puis la libère.
func mesurer(chemin: String) -> Dictionary:
	var ps: PackedScene = load(chemin)
	if ps == null:
		printerr("Scène illisible : %s" % chemin)
		return {}
	var vieille := current_scene
	if vieille:
		root.remove_child(vieille)
		vieille.free()
	var n := ps.instantiate()
	root.add_child(n)
	current_scene = n
	for i in IMAGES:
		await process_frame
	# Les niveaux de détail des gros maillages se calculent dans un fil (Lointain) : on les attend.
	for i in 600:
		if not Lointain.en_travail():
			break
		await process_frame
	return Budget.mesurer(n)


## Les scènes qu'un paquet ouvre : la sienne et celles de ses structures (scene, habillage, modele).
func _scenes_du_paquet(pck: String) -> Array:
	var communes: Node = root.get_node("Communes")
	DirAccess.make_dir_recursive_absolute("user://budget/")
	communes.dossier_greffes = "user://budget/"
	var copie := "user://budget/" + pck.get_file()
	DirAccess.copy_absolute(pck, copie)
	var id: String = communes.charger_pack(copie)
	if id == "":
		printerr("Paquet refusé : %s" % str(communes.refus[-1][1] if not communes.refus.is_empty() else "?"))
		return []
	communes.ouvrir(id)
	var data: Dictionary = communes.commune(id).data
	var out := [str(data.scene)]
	for s in data.get("structures", []):
		for champ in ["scene", "habillage", "modele"]:
			var v := str(s.get(champ, ""))
			if v.begins_with("res://") and not v in out:
				out.append(v)
	return out
