extends SceneTree
## Mesure ce que coûte chaque lieu au processeur : godot --headless --path . -s tools/mesure_lenteur.gd
## --scenes=res://scenes/title.tscn,jouer,res://scenes/casino.tscn : « jouer » appuie sur Jouer.
## Pour chaque scène : durée du chargement, nœuds, nœuds qui tournent à chaque image (_process ou
## _physics_process), temps moyen des scripts et de la physique par image.

const SCENES := ["res://scenes/title.tscn", "res://scenes/main.tscn", "res://scenes/casino.tscn",
	"res://scenes/salle_basket.tscn", "res://scenes/stade.tscn", "res://scenes/cafe.tscn"]


func _compter(n: Node, c: Dictionary) -> void:
	c.noeuds += 1
	if n.is_processing() or n.is_physics_processing():
		c.actifs += 1
		var cle: String = n.get_script().resource_path.get_file() if n.get_script() else n.get_class()
		c.par[cle] = c.par.get(cle, 0) + 1
	for k in n.get_children():
		_compter(k, c)


## --sans=sdfgi,ssil,brouillard,ssr,ssao,ombres : éteint ces effets pour en mesurer le prix.
func _retirer(n: Node) -> void:
	var sans := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sans="):
			sans = a.trim_prefix("--sans=").split(",")
	if sans.is_empty():
		return
	for we in n.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = we.environment
		if "sdfgi" in sans: env.sdfgi_enabled = false
		if "ssil" in sans: env.ssil_enabled = false
		if "brouillard" in sans: env.volumetric_fog_enabled = false
		if "ssr" in sans: env.ssr_enabled = false
		if "ssao" in sans: env.ssao_enabled = false
	if "ombres" in sans:
		for l in n.find_children("*", "Light3D", true, false):
			if not l is DirectionalLight3D:
				l.shadow_enabled = false


func _init() -> void:
	await process_frame
	OS.low_processor_usage_mode_sleep_usec = 0
	var settings: Node = root.get_node("Settings")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qualite=") and settings.has_method("appliquer_qualite"):
			settings.qualite = a.trim_prefix("--qualite=")
			settings.appliquer_qualite()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true
	print("démarrage jusqu'à la première image : %d ms" % Time.get_ticks_msec())
	var scenes := SCENES
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenes="):
			scenes = a.trim_prefix("--scenes=").split(",")
	for s in scenes:
		var t0 := Time.get_ticks_usec()
		if s == "jouer":
			# « Jouer » depuis l'écran titre (qui doit être la scène en cours).
			current_scene._play()
		else:
			change_scene_to_file(s)
		await process_frame
		await process_frame
		var t1 := Time.get_ticks_usec()
		for i in 5:
			await process_frame
		_retirer(current_scene)
		if DisplayServer.get_name() != "headless":
			for i in 5:
				await process_frame
		var proc := 0.0
		var phys := 0.0
		var pire := 0.0
		var n := 120
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--images="):
				n = int(a.trim_prefix("--images="))
		var d0 := Time.get_ticks_usec()
		var prec := d0
		for i in n:
			await process_frame
			var maintenant := Time.get_ticks_usec()
			var p := (maintenant - prec) / 1e6
			prec = maintenant
			proc += p
			pire = maxf(pire, p)
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		var c := {"noeuds": 0, "actifs": 0, "par": {}}
		_compter(root, c)
		var par: Array = c.par.keys()
		par.sort_custom(func(a, b): return c.par[a] > c.par[b])
		var top := []
		for k in par.slice(0, 8):
			top.append("%s×%d" % [k, c.par[k]])
		print("%s : chargement %d ms · nœuds %d (dont %d actifs : %s) · image %.2f ms en moyenne (pire %.1f) · physique %.2f ms · %.1f images/s sans rendu" % [
			s.get_file(), (t1 - t0) / 1000, c.noeuds, c.actifs, ", ".join(top), proc / n * 1000.0, pire * 1000.0, phys / n * 1000.0, n / ((Time.get_ticks_usec() - d0) / 1e6)])
	quit()
