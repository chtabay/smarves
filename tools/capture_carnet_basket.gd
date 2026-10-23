extends SceneTree
## Capture du basket dans le carnet :
## godot --path . --resolution 1600x900 -s tools/capture_carnet_basket.gd -- --sortie=<dossier/>
## Images : aujourdhui_basket.png (l'Étoile et les Hérons suivis, la consigne attend), basket_club.png (la
## page des Hérons dans Mes clubs).

const CLICHE := "res://tools/fixtures/basket_cliche.json"
const TMP := "user://capture_carnet_basket/"
var t := 0


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/carnet_basket/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
	DirAccess.make_dir_recursive_absolute(sortie)
	DirAccess.make_dir_recursive_absolute(TMP)
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	var avis: Node = root.get_node("Avis")
	var foot: Node = root.get_node("Football")
	var basket: Node = root.get_node("Basket")
	avis.dossier = TMP
	avis.effacer()
	foot.dossier = TMP
	foot.effacer()
	basket.dossier = ""
	basket.effacer()
	t = basket.coup_envoi(1, 5) - 86400
	foot.regler_horloge(func(): return t)
	basket.regler_horloge(func(): return t)
	basket.appel = func(_f, _c): return {"code": 200, "corps": {"ok": true}}
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	foot.forcer_porteurs("vous:3", "smarves")
	var inscrits: Array = [{"commune": "smarves", "nom": "La salle de Smarves", "type": "gymnase", "champs": {"club": "Les Hérons du Clain"}}]
	basket.source_gymnases = func(): return inscrits
	basket.actualiser()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLICHE))
	for j in range(1, 6):
		var c: Dictionary = fixture.duplicate(true)
		c.id = basket.id_cliche(1, j)
		basket.garder(c)
	basket.bureau.obligations = [{"club": "smarves", "rang": 4, "par": "Moi", "moi": true}]
	basket._oublier()
	avis.verifier()
	avis.set("_file", [])
	var carnet: Node = root.get_node("Carnet")
	carnet.ouvrir_sur("aujourdhui")
	await _photo(sortie + "aujourdhui_basket.png")
	carnet.ouvrir_club("basket:smarves")
	await _photo(sortie + "basket_club.png")
	avis.effacer()
	foot.effacer()
	basket.effacer()
	quit()


func _photo(chemin: String) -> void:
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(chemin)
