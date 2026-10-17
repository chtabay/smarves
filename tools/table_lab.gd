extends Node3D
## Banc d'essai des tables 3D, sans charger tout le casino : une table, la lumière du casino, la
## barre de jeu, un coup joué tout seul et des captures à des instants donnés.
##   godot --path . res://tools/table_lab.tscn -- --game=roulette --capture=sortie.png --shots=1,4,8

const ROULETTE := preload("res://scripts/roulette_panel.gd")
const ROULETTE_3D := preload("res://scripts/jeux/roulette_3d.gd")
const BARRE := preload("res://scripts/jeux/barre.gd")

var game := "roulette"
var path := ""
var shots := [3.0]
var ui: Control


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--game="):
			game = arg.trim_prefix("--game=")
		elif arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--shots="):
			shots = Array(arg.trim_prefix("--shots=").split_floats(","))
	Game.saving_enabled = false
	Game.credits = 100000
	_environment()
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var eye := Camera3D.new()
	eye.fov = 72
	add_child(eye)
	eye.look_at_from_position(Vector3(0, 1.7, 3.2), Vector3(0, 0.8, 0))
	eye.make_current()
	match game:
		"roulette":
			var t := ROULETTE_3D.new()
			add_child(t)
			var p: PanelContainer = ROULETTE.new()
			p.title = "Roulette européenne"
			t.attach(p)
			t.sit(eye)
			BARRE.dock(p, ui)
			await get_tree().create_timer(1.2).timeout
			for k in ["red", "n17", "doz2", "n0", "n17", "col3", "n22", "even"]:
				p._place_bet(k)
				await get_tree().create_timer(0.1).timeout
			if path != "":
				await _shot(0)
			p.spin()
	if path == "":
		return
	var elapsed := 0.0
	for i in shots.size():
		await get_tree().create_timer(maxf(float(shots[i]) - elapsed, 0.0)).timeout
		elapsed = float(shots[i])
		await _shot(i + 1)
	get_tree().quit()


func _shot(i: int) -> void:
	await RenderingServer.frame_post_draw
	print("capture %d à %.2f s" % [i, Time.get_ticks_msec() / 1000.0])
	get_viewport().get_texture().get_image().save_png(path.get_basename() + "-%d.png" % i)


## La lumière du casino, en plus léger : nuit chaude, lustres hors champ, moquette rouge.
func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.015, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.38, 0.25)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssr_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var floor_m := ShaderMaterial.new()
	floor_m.shader = load("res://shaders/carpet.gdshader")
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	var f := MeshInstance3D.new()
	f.mesh = pm
	f.material_override = floor_m
	add_child(f)
	for at in [Vector3(-3, 3.5, -2), Vector3(3, 3.5, -2), Vector3(0, 3.5, 3)]:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.8, 0.55)
		o.light_energy = 1.2
		o.omni_range = 7.0
		o.position = at
		add_child(o)
