extends SceneTree
## Captures de la gestion (clubs et cartes), du premier gain au club dirigé, pour en juger l'UX :
## godot --path . --resolution 1600x900 -s tools/capture_gestion.gd -- --sortie=<dossier/> [--base=600]
## Images : debutant-cartes.png, debutant-compte.png et calendrier.png (400 gagnés, rien en poche), premiers-gains.png (3 500
## gagnés, une part de la Smarvoise et une obligation de l'Étoile ; premiers-gains-cartes.png, plus bas), foot-obligations.png (le registre du
## stade ; foot-obligations-en-saison.png, hors de l'intersaison ; foot-panneau.png, le panneau de l'entrée), basket-accueil.png, basket-parts.png, basket-bureau.png, basket-panneau.png et basket-partenaires.png (le club de basket, Lucien dirige, vous
## tenez la n° 2), notaire-telephone-basket.png et notaire-telephone-foot.png (le registre ouvert du carnet),
## notaire-etude.png et notaire-etude-basket.png (l'étude et son registre du basket), sur un faux serveur qui suit les règles de tools/test_basket_bureau.gd.

const CLICHE := "res://tools/fixtures/basket_cliche.json"
const TMP := "user://capture_gestion/"

var serveur := {"obligations": [], "encheres": [], "liberations": [], "consignes": [], "noms": []}
var t := 0


func _initialize() -> void:
	_lancer.call_deferred()


func appel(f: String, c: Dictionary) -> Dictionary:
	if f == "smarves_basket_bureau":
		var out := {}
		for k in serveur:
			out[k] = (serveur[k] as Array).map(func(x):
				var y: Dictionary = x.duplicate()
				y.moi = str(x.get("par", "")) == "Moi"
				return y)
		return {"code": 200, "corps": out}
	if f == "smarves_basket_obligation_prendre":
		serveur.obligations.append({"club": c.p_club, "rang": int(c.p_rang), "par": "Moi"})
	return {"code": 200, "corps": {"ok": true}}


func _lancer() -> void:
	var sortie := "/tmp/gestion/"
	var seul := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
		elif arg.begins_with("--seul="):
			seul = arg.trim_prefix("--seul=")
	DirAccess.make_dir_recursive_absolute(sortie)
	DirAccess.make_dir_recursive_absolute(TMP)
	var game: Node = root.get_node("Game")
	var biens: Node = root.get_node("Biens")
	var foot: Node = root.get_node("Football")
	var basket: Node = root.get_node("Basket")
	game.saving_enabled = false
	foot.dossier = TMP
	foot.effacer()
	var t0 := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 18, "hour": 20, "minute": 0, "second": 0})
	foot.regler_horloge(func(): return t0)
	foot.actualiser()
	# Le basket sur son faux serveur, la saison commencée, deux clubs au groupe.
	basket.dossier = ""
	basket.effacer()
	basket.appel = appel
	var inscrits: Array = [{"commune": "smarves", "nom": "Le Clain Garden", "type": "gymnase", "champs": {"club": "Les Hérons du Clain"}},
		{"commune": "rivale", "nom": "La salle de Rivale", "type": "gymnase", "champs": {"club": "Les Loups de Rivale"}}]
	basket.source_gymnases = func(): return inscrits
	t = basket.coup_envoi(1, 2) - 2 * 86400
	basket.regler_horloge(func(): return t)
	basket.actualiser()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLICHE))
	for j in [1, 2, 3]:
		var cl: Dictionary = fixture.duplicate(true)
		cl.id = basket.id_cliche(1, j)
		basket.garder(cl)
	await basket.lire()

	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	var carnet: Node = root.get_node("Carnet")
	# Le débutant : 400 gagnés, rien acheté.
	game.won = 400
	game.credits = 650
	if seul == "" or seul == "debutant":
		carnet.toggle()
		carnet.ouvrir_onglet("cartes")
		await _photo(sortie + "debutant-cartes.png")
		carnet.ouvrir_onglet("compte")
		await _photo(sortie + "debutant-compte.png")
		carnet.ouvrir_onglet("calendrier")
		await _photo(sortie + "calendrier.png")
		carnet.toggle()
	# Les premiers gains : une part de la Smarvoise, une obligation de l'Étoile.
	game.won = 3500
	game.credits = 5000
	biens.buy("smarvoise")
	foot.forcer_porteurs("vous:1,Lucien:4", "smarves")
	game.credits = 1800
	if seul == "" or seul == "premiers":
		carnet.toggle()
		carnet.ouvrir_onglet("cartes")
		await _photo(sortie + "premiers-gains.png")
		var defile: ScrollContainer = carnet.get("_album").get("_defile")
		defile.scroll_vertical = 520
		await _photo(sortie + "premiers-gains-cartes.png")
		carnet.toggle()
	var hote := CanvasLayer.new()
	hote.layer = 60
	root.add_child(hote)
	var fond := ColorRect.new()
	fond.color = Color(0.03, 0.04, 0.06, 0.85)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	hote.add_child(fond)
	if seul == "" or seul == "foot":
		var reg: Control = load("res://scripts/socle/foot_obligations.gd").new()
		reg.set("club", "smarves")
		hote.add_child(reg)
		await _photo(sortie + "foot-obligations.png")
		reg.queue_free()
		# En pleine saison : les obligations ne se prennent pas, le registre dit quand.
		var t5: int = foot.coup_envoi(1, 5) + 86400
		foot.regler_horloge(func(): return t5)
		reg = load("res://scripts/socle/foot_obligations.gd").new()
		reg.set("club", "smarves")
		hote.add_child(reg)
		await _photo(sortie + "foot-obligations-en-saison.png")
		reg.queue_free()
		reg = load("res://scripts/socle/foot_panneau.gd").new()
		reg.set("club", "smarves")
		hote.add_child(reg)
		await _photo(sortie + "foot-panneau.png")
		reg.queue_free()
		foot.regler_horloge(func(): return t0)
	game.won = 12000
	game.credits = 4200
	# Au Clain Garden : Lucien tient la n° 5, vous la n° 2.
	serveur.obligations = [{"club": "smarves", "rang": 5, "par": "Lucien"}, {"club": "smarves", "rang": 2, "par": "Moi"}]
	await basket.lire()
	for quoi in [["basket-accueil", "res://scripts/socle/basket_club.gd"], ["basket-parts", "res://scripts/socle/basket_parts.gd"],
			["basket-bureau", "res://scripts/socle/basket_bureau.gd"], ["basket-panneau", "res://scripts/socle/basket_panneau.gd"],
			["basket-partenaires", "res://scripts/socle/basket_partenaires.gd"]]:
		if seul != "" and seul != "basket":
			break
		var p: Control = load(quoi[1]).new()
		p.set("commune", "smarves")
		hote.add_child(p)
		await _photo(sortie + quoi[0] + ".png")
		p.queue_free()
	# Le notaire au téléphone, depuis le carnet, puis l'étude et son registre du basket.
	if seul == "" or seul == "notaire":
		hote.visible = false
		carnet.notaire("basket", "smarves")
		await _photo(sortie + "notaire-telephone-basket.png")
		carnet.notaire("football", "smarves")
		await _photo(sortie + "notaire-telephone-foot.png")
		carnet.fermer_gestion()
		carnet.toggle()
		hote.visible = true
		var centre := CenterContainer.new()
		centre.set_anchors_preset(Control.PRESET_FULL_RECT)
		hote.add_child(centre)
		var etude: Control = load("res://scripts/shop_panel.gd").new()
		etude.set("seller", "notaire")
		centre.add_child(etude)
		await _photo(sortie + "notaire-etude.png")
		etude.find_child("Registre_basket_smarves", true, false).pressed.emit()
		await _photo(sortie + "notaire-etude-basket.png")
		centre.queue_free()
	foot.effacer()
	basket.effacer()
	quit()


func _photo(chemin: String) -> void:
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(chemin)
