extends Node3D
## Première scène : le Seuil et la première galerie de la Roche grise, dans le Mont Ombreclair.

const SMARVE := preload("res://scripts/smarve.gd")
const ORBIT := preload("res://scripts/orbit_camera.gd")
const KN := "res://assets/kenney/nature/"
const KS := "res://assets/kenney/survival/"
const KD := "res://assets/kenney/dungeon/"

## Hauteur de chaque colonne de la montagne, de x = 0 à x = 12 (rangée du fond).
const PROFILE := [5, 6, 8, 9, 8, 10, 11, 12, 10, 9, 8, 6, 5]
## Les rangées de devant sont plus basses : la montagne descend en terrasses vers le spectateur.
const ROW_DROP := {0: 4, -1: 2, -2: 1, -3: 0}
const MOUNTAIN_Z := [0, -1, -2, -3]
const GALLERY_END := 10
const ORE_X := [2.5, 5.5, 8.5]
const SMARVE_NAMES := ["Bodrin", "Pell", "Ysolde", "Grumm", "Tavi", "Orrik", "Mabbe", "Fennick"]

var gold := 0.0
var shown_gold := 0.0
var pick_level := 1
var hire_cost := 15
var pick_cost := 30
var smarves: Array[Node3D] = []
var ores: Array[Node3D] = []

var rock_material: StandardMaterial3D
var moss_material: StandardMaterial3D
var dirt_material: StandardMaterial3D
var pine_material: StandardMaterial3D
var ore_material: StandardMaterial3D
var spark_material: StandardMaterial3D
var glowcap_material: StandardMaterial3D
var serif: SystemFont

var _fire_light: OmniLight3D
var _gold_label: Label
var _crew_label: Label
var _hire_button: Button
var _pick_button: Button
var _time := 0.0


func _ready() -> void:
	randomize()
	_make_materials()
	_build_environment()
	_build_lights()
	_build_plinth()
	_build_terrain()
	_build_gallery()
	_build_camp()
	_build_ui()
	var cam := Camera3D.new()
	cam.set_script(ORBIT)
	add_child(cam)
	cam.make_current()
	for i in 2:
		_spawn_smarve()
	_maybe_capture()


# --- Matériaux : une seule palette pour unifier les packs ---------------------

func _noise_tex(normal: bool, freq: float) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 5
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = 4.0
	else:
		var g := Gradient.new()
		g.set_color(0, Color(0.42, 0.46, 0.58))
		g.set_color(1, Color(1.0, 1.0, 1.0))
		t.color_ramp = g
	return t


func _make_materials() -> void:
	rock_material = StandardMaterial3D.new()
	rock_material.albedo_color = Color(0.30, 0.34, 0.46)
	rock_material.albedo_texture = _noise_tex(false, 0.035)
	rock_material.normal_enabled = true
	rock_material.normal_texture = _noise_tex(true, 0.06)
	rock_material.uv1_triplanar = true
	rock_material.uv1_scale = Vector3.ONE * 0.5
	rock_material.roughness = 0.93

	moss_material = StandardMaterial3D.new()
	moss_material.albedo_color = Color(0.16, 0.27, 0.20)
	moss_material.albedo_texture = rock_material.albedo_texture
	moss_material.uv1_triplanar = true
	moss_material.roughness = 1.0

	dirt_material = StandardMaterial3D.new()
	dirt_material.albedo_color = Color(0.25, 0.19, 0.16)
	dirt_material.roughness = 1.0

	pine_material = StandardMaterial3D.new()
	pine_material.albedo_color = Color(0.08, 0.19, 0.17)
	pine_material.roughness = 0.9

	ore_material = StandardMaterial3D.new()
	ore_material.albedo_color = Color(0.85, 0.45, 0.2)
	ore_material.metallic = 0.6
	ore_material.roughness = 0.35
	ore_material.emission_enabled = true
	ore_material.emission = Color(1.0, 0.42, 0.12)
	ore_material.emission_energy_multiplier = 2.2

	spark_material = StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1.0, 0.75, 0.35)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.6, 0.2)
	spark_material.emission_energy_multiplier = 6.0

	glowcap_material = StandardMaterial3D.new()
	glowcap_material.albedo_color = Color(0.3, 0.9, 0.95)
	glowcap_material.emission_enabled = true
	glowcap_material.emission = Color(0.2, 0.85, 1.0)
	glowcap_material.emission_energy_multiplier = 3.0

	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"])


func _repaint(node: Node, interior := false, override: Material = null) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			if override:
				mi.set_surface_override_material(i, override)
				continue
			var m := mesh.surface_get_material(i)
			var n := m.resource_name if m else ""
			var rep: Material = null
			match n:
				"stone", "_defaultMat":
					rep = rock_material
				"grass":
					rep = rock_material if interior else moss_material
				"dirt":
					rep = dirt_material
				"leafsDark", "leafs":
					rep = pine_material
			if rep:
				mi.set_surface_override_material(i, rep)


func _place(path: String, pos: Vector3, scale := 1.0, rot_y := 0.0, parent: Node = self) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scale
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	return n


# --- Ambiance -----------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.016, 0.03)
	var sky := Sky.new()
	var pano := PanoramaSkyMaterial.new()
	pano.panorama = load("res://assets/hdri/kloppenheim_06_puresky_2k.hdr")
	sky.sky_material = pano
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.4, 0.62)
	env.ambient_light_energy = 0.1
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_intensity = 2.5
	env.ssil_enabled = true
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.8
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.4, 0.45, 0.6)
	env.volumetric_fog_gi_inject = 0.3
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_length = 60.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_lights() -> void:
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.66, 1.0)
	moon.light_energy = 0.75
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 0.1
	moon.rotation_degrees = Vector3(-42, -48, 0)
	add_child(moon)

	# Contre-jour froid pour détacher la silhouette de la montagne du noir.
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.45, 0.75, 1.0)
	rim.light_energy = 0.35
	rim.rotation_degrees = Vector3(-20, 160, 0)
	rim.light_volumetric_fog_energy = 0.0
	add_child(rim)


func _build_plinth() -> void:
	var walnut := StandardMaterial3D.new()
	walnut.albedo_color = Color(0.17, 0.09, 0.05)
	walnut.roughness = 0.45
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(23.8, 0.6, 5.8)
	box.mesh = bm
	box.material_override = walnut
	box.position = Vector3(1.0, -2.3, -1.0)
	add_child(box)

	var plaque := Label3D.new()
	plaque.text = "LE MONT OMBRECLAIR"
	plaque.font = serif
	plaque.font_size = 72
	plaque.pixel_size = 0.004
	plaque.modulate = Color(0.95, 0.75, 0.4)
	plaque.outline_size = 0
	plaque.position = Vector3(1.0, -2.3, 1.91)
	add_child(plaque)


# --- La montagne en blocs -------------------------------------------------------

func _is_gallery(c: Vector3i) -> bool:
	return c.x >= 0 and c.x <= GALLERY_END and c.y >= 0 and c.y <= 1 and c.z >= -1


func _build_terrain() -> void:
	var cells := {}
	# Le sol, deux couches, sous le camp et sous la montagne.
	for x in range(-10, 13):
		for z in range(1, -4, -1):
			for y in [-2, -1]:
				cells[Vector3i(x, y, z)] = true
	# La montagne, avec la galerie creusée dedans.
	for x in PROFILE.size():
		for z in MOUNTAIN_Z:
			# Un peu d'irrégularité pour casser l'escalier trop parfait.
			var jitter := -1 if (x * 7 + z * 13) % 5 == 0 else 0
			for y in maxi(3, PROFILE[x] - ROW_DROP[z] + jitter):
				var c := Vector3i(x, y, z)
				if not _is_gallery(c):
					cells[c] = true

	var dirs := [Vector3i.UP, Vector3i.LEFT, Vector3i.RIGHT, Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	add_child(terrain)
	for c: Vector3i in cells:
		var exposed := false
		for d in dirs:
			if not cells.has(c + d):
				exposed = true
				break
		if not exposed:
			continue
		var top := not cells.has(c + Vector3i.UP)
		# Sous la montagne et dans la galerie, la roche est nue ; la mousse ne pousse que dehors.
		var under_mountain := c.x >= 0 and c.x < PROFILE.size() and c.z <= 0
		var interior := not top or (c.y < 0 and under_mountain)
		var b := _place(KN + "cliff_block_stone.glb", Vector3(c), 1.0, 0.0, terrain)
		_repaint(b, interior)
		# Sur les terrasses de la montagne : pins noirs, rochers et touffes.
		if top and c.y >= 2:
			_decorate_ledge(Vector3(c) + Vector3(0, 1, 0), terrain)


func _decorate_ledge(at: Vector3, parent: Node) -> void:
	var r := randf()
	var p := at + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
	if r < 0.35:
		var t := _place(KN + ["tree_pineTallA_detailed.glb", "tree_pineTallB_detailed.glb", "tree_pineSmallA.glb", "tree_pineSmallC.glb"].pick_random(),
			p, randf_range(0.9, 1.5), randf() * 360.0, parent)
		_repaint(t)
	elif r < 0.6:
		var s := _place(KN + ["stone_tallB.glb", "stone_smallC.glb", "stone_largeA.glb", "stone_smallTopA.glb"].pick_random(),
			p, randf_range(0.5, 0.9), randf() * 360.0, parent)
		_repaint(s, true)
	elif r < 0.8:
		var g := _place(KN + "grass_large.glb", p, 1.2, randf() * 360.0, parent)
		_repaint(g)


# --- La galerie de la Roche grise ---------------------------------------------

func _build_gallery() -> void:
	# Étais en bois, chacun avec sa lanterne.
	for x in [0.0, 4.0, 7.0, 10.0]:
		var s := _place(KD + "wood-support.glb", Vector3(x, 0, -0.5), 1.0, 90.0)
		s.scale = Vector3(1.85, 1.95, 1.3)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.62, 0.3)
		lamp.light_energy = 1.1
		lamp.omni_range = 3.6
		lamp.light_volumetric_fog_energy = 2.0
		lamp.position = Vector3(x, 1.55, -0.5)
		add_child(lamp)
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		bulb.mesh = sm
		bulb.material_override = spark_material
		bulb.position = lamp.position
		add_child(bulb)

	# Rochers et éboulis au sol.
	for x in [1.2, 3.4, 6.3, 9.2]:
		var r := _place(KN + "rock_smallA.glb", Vector3(x, 0, -1.25), 0.7, randf() * 360.0)
		_repaint(r, true)

	# Trois filons de cuivre dans la paroi du fond.
	for x in ORE_X:
		var ore := Node3D.new()
		ore.position = Vector3(x, 0, -1.45)
		add_child(ore)
		for k in 4:
			var piece := _place(KN + ["stone_tallA.glb", "stone_tallB.glb", "stone_smallA.glb", "stone_tallC.glb"][k],
				Vector3(randf_range(-0.35, 0.35), randf_range(0.1, 0.9), 0), randf_range(0.28, 0.45), randf() * 360.0, ore)
			piece.rotation_degrees.x = randf_range(-25, 25)
			_repaint(piece, true, ore_material)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.5, 0.2)
		glow.light_energy = 0.9
		glow.omni_range = 2.2
		glow.position = Vector3(0, 0.6, 0.4)
		ore.add_child(glow)
		var area := Area3D.new()
		var shape := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.75
		shape.shape = sph
		shape.position = Vector3(0, 0.6, 0.2)
		area.add_child(shape)
		area.set_meta("ore", ore)
		ore.add_child(area)
		ores.append(ore)

	# La porte scellée vers la strate suivante : un seuil, pas encore ouvert.
	var gate := _place(KD + "gate.glb", Vector3(GALLERY_END + 0.35, 0, -0.5), 1.0, -90.0)
	gate.scale = Vector3(1.9, 1.75, 1.9)
	var seal := Label3D.new()
	seal.text = "Grotte aux cristaux\nscellée"
	seal.font = serif
	seal.font_size = 40
	seal.pixel_size = 0.004
	seal.modulate = Color(0.75, 0.6, 1.0)
	seal.position = Vector3(GALLERY_END - 0.2, 2.25, 0.3)
	add_child(seal)


# --- Le Seuil : le camp au pied de la montagne --------------------------------

func _build_camp() -> void:
	_place(KS + "campfire-pit.glb", Vector3(-5.0, 0, -0.3), 3.2)
	_place(KN + "campfire_logs.glb", Vector3(-5.0, 0.05, -0.3), 2.6)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.52, 0.2)
	_fire_light.light_energy = 5.0
	_fire_light.omni_range = 9.0
	_fire_light.shadow_enabled = true
	_fire_light.light_volumetric_fog_energy = 1.5
	_fire_light.position = Vector3(-5.0, 0.7, -0.3)
	add_child(_fire_light)
	_add_flames(Vector3(-5.0, 0.15, -0.3))

	var tent := _place(KN + "tent_detailedOpen.glb", Vector3(-7.6, 0, -1.7), 2.6, 35.0)
	_repaint(tent)
	_place(KS + "workbench-anvil.glb", Vector3(-3.6, 0, -2.2), 2.6, -20.0)
	_place(KS + "barrel.glb", Vector3(-2.9, 0, -2.6), 2.4)
	_place(KS + "box-large-open.glb", Vector3(-2.2, 0, -0.75), 2.6, 90.0)
	_place(KS + "resource-stone.glb", Vector3(-2.6, 0, 0.3), 2.4, 40.0)
	_place(KS + "signpost-single.glb", Vector3(-1.0, 0, 0.9), 2.4, -15.0)
	_place(KS + "bedroll.glb", Vector3(-6.6, 0, 0.6), 2.4, 70.0)
	_place(KN + "log_large.glb", Vector3(-4.6, 0, 0.7), 2.2, 80.0)

	for p in [Vector3(-9.3, 0, -2.6), Vector3(-8.4, 0, -3.0), Vector3(-9.5, 0, 0.6), Vector3(-1.4, 0, -3.0), Vector3(-6.0, 0, -3.1)]:
		var tree := _place(KN + ["tree_pineTallA_detailed.glb", "tree_pineTallB_detailed.glb", "tree_pineTallC_detailed.glb"].pick_random(),
			p, randf_range(2.2, 3.0), randf() * 360.0)
		_repaint(tree)
	for p in [Vector3(-0.7, 0, -1.3), Vector3(-1.2, 0, 0.2), Vector3(11.5, 0, 0.9), Vector3(-8.0, 0, 1.0)]:
		var m := _place(KN + "mushroom_tanGroup.glb", p, 2.0, randf() * 360.0)
		_repaint(m, false, glowcap_material)
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 0.85, 1.0)
		l.light_energy = 0.5
		l.omni_range = 1.5
		l.position = p + Vector3(0, 0.3, 0)
		add_child(l)
	for i in 14:
		var g := _place(KN + ["grass.glb", "grass_large.glb"].pick_random(),
			Vector3(randf_range(-9.8, -0.8), 0, randf_range(-3.2, 1.3)), 1.6, randf() * 360.0)
		_repaint(g)


func _add_flames(at: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	quad.material = mat

	var ramp := Gradient.new()
	ramp.set_color(0, Color(4.0, 2.6, 0.9, 1.0))
	ramp.set_color(1, Color(1.2, 0.2, 0.05, 0.0))

	var flames := CPUParticles3D.new()
	flames.mesh = quad
	flames.amount = 40
	flames.lifetime = 0.7
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.18
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.gravity = Vector3(0, 1.6, 0)
	flames.initial_velocity_min = 0.2
	flames.initial_velocity_max = 0.5
	flames.scale_amount_min = 0.6
	flames.scale_amount_max = 1.2
	flames.color_ramp = ramp
	flames.position = at
	add_child(flames)

	var embers := CPUParticles3D.new()
	var eq := QuadMesh.new()
	eq.size = Vector2(0.04, 0.04)
	eq.material = mat
	embers.mesh = eq
	embers.amount = 24
	embers.lifetime = 2.4
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.25
	embers.direction = Vector3.UP
	embers.spread = 25.0
	embers.gravity = Vector3(0.15, 0.6, 0)
	embers.initial_velocity_min = 0.5
	embers.initial_velocity_max = 1.1
	embers.color_ramp = ramp
	embers.position = at + Vector3(0, 0.3, 0)
	add_child(embers)


# --- Les smarves et l'économie ------------------------------------------------

func _spawn_smarve() -> void:
	var s: Node3D = SMARVE.new()
	s.game = self
	s.model_path = "res://assets/kenney/characters/" + ("character-male-b.glb" if smarves.size() % 3 != 2 else "character-male-e.glb")
	s.lane_z = randf_range(-1.0, -0.35)
	s.name = SMARVE_NAMES[smarves.size() % SMARVE_NAMES.size()]
	s.position = Vector3(-1.8, 0, s.lane_z)
	s.delivered.connect(_on_delivered)
	add_child(s)
	smarves.append(s)


func pick_ore() -> Node3D:
	return ores.pick_random()


func pick_power() -> int:
	return pick_level


func crate_drop_point(lane: float) -> Vector3:
	return Vector3(-1.55 + randf_range(-0.1, 0.1), 0, clampf(lane, -1.0, -0.4))


func on_ore_hit(ore: Node3D, by_player: bool) -> void:
	_sparks(ore.global_position + Vector3(0, 0.5, 0.3))
	if by_player:
		gold += pick_level
		_float_text("+%d" % pick_level, ore.global_position + Vector3(0, 1.3, 0.4))


func _on_delivered(amount: int, at: Vector3) -> void:
	gold += amount
	_float_text("+%d" % amount, at)


func _sparks(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.035
	bm.material = spark_material
	p.mesh = bm
	p.amount = 18
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 0.6, 1)
	p.spread = 60.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -6, 0)
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _float_text(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = serif
	l.font_size = 56
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color(1.0, 0.82, 0.4)
	l.outline_modulate = Color(0.2, 0.1, 0.0, 0.8)
	l.outline_size = 10
	l.position = at
	add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", at.y + 0.9, 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cam := get_viewport().get_camera_3d()
		var from := cam.project_ray_origin(event.position)
		var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(event.position) * 200.0)
		q.collide_with_areas = true
		q.collide_with_bodies = false
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit and hit.collider.has_meta("ore"):
			on_ore_hit(hit.collider.get_meta("ore"), true)


func _hire() -> void:
	if gold < hire_cost:
		return
	gold -= hire_cost
	hire_cost = int(round(hire_cost * 1.6))
	_spawn_smarve()


func _upgrade_picks() -> void:
	if gold < pick_cost:
		return
	gold -= pick_cost
	pick_level += 1
	pick_cost = int(round(pick_cost * 2.3))


func _process(delta: float) -> void:
	_time += delta
	_fire_light.light_energy = 4.6 + sin(_time * 13.0) * 0.35 + sin(_time * 7.3) * 0.45 + randf() * 0.25
	shown_gold = lerpf(shown_gold, gold, 1.0 - exp(-10.0 * delta))
	if absf(shown_gold - gold) < 0.5:
		shown_gold = gold
	_gold_label.text = "%d or" % roundi(shown_gold)
	_crew_label.text = "%d smarves  ·  pioches de niveau %d" % [smarves.size(), pick_level]
	_hire_button.text = "Engager un smarve  —  %d or" % hire_cost
	_pick_button.text = "Forger de meilleures pioches  —  %d or" % pick_cost
	_hire_button.disabled = gold < hire_cost
	_pick_button.disabled = gold < pick_cost


# --- Interface ----------------------------------------------------------------

func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font = serif
	theme.default_font_size = 20
	var gold_col := Color(0.96, 0.8, 0.45)

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.04, 0.045, 0.07, 0.78)
	panel.border_color = Color(0.8, 0.6, 0.3, 0.55)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(16)
	theme.set_stylebox("panel", "PanelContainer", panel)

	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color(0.12, 0.08, 0.04, 0.9), "hover": Color(0.25, 0.16, 0.06, 0.95),
			"pressed": Color(0.35, 0.22, 0.08, 1.0), "disabled": Color(0.07, 0.07, 0.09, 0.8),
			"focus": Color(0, 0, 0, 0)}[st]
		b.border_color = Color(0.85, 0.62, 0.3, 0.25 if st == "disabled" else 0.8)
		b.set_border_width_all(1)
		b.set_corner_radius_all(3)
		b.content_margin_left = 18
		b.content_margin_right = 18
		b.content_margin_top = 10
		b.content_margin_bottom = 10
		if st == "focus":
			b.draw_center = false
			b.border_color = Color(0, 0, 0, 0)
		theme.set_stylebox(st, "Button", b)
	theme.set_color("font_color", "Button", gold_col)
	theme.set_color("font_hover_color", "Button", Color(1, 0.92, 0.7))
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.42))
	theme.set_color("font_color", "Label", Color(0.85, 0.83, 0.8))

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var top := PanelContainer.new()
	top.position = Vector2(28, 24)
	root.add_child(top)
	var v := VBoxContainer.new()
	top.add_child(v)
	var title := Label.new()
	title.text = "S M A R V E S"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.7, 0.62, 0.5))
	v.add_child(title)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 44)
	_gold_label.add_theme_color_override("font_color", gold_col)
	v.add_child(_gold_label)
	_crew_label = Label.new()
	_crew_label.add_theme_font_size_override("font_size", 16)
	v.add_child(_crew_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.position.y -= 28
	root.add_child(bottom)
	_hire_button = Button.new()
	_hire_button.pressed.connect(_hire)
	bottom.add_child(_hire_button)
	_pick_button = Button.new()
	_pick_button.pressed.connect(_upgrade_picks)
	bottom.add_child(_pick_button)

	var hint := Label.new()
	hint.text = "Clic sur un filon : piocher   ·   Clic droit : tourner   ·   Molette : zoomer"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 0.8))
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.position += Vector2(-28, 28)
	root.add_child(hint)


# --- Capture d'écran pour vérifier le rendu : godot -- --capture=chemin.png ----

func _maybe_capture() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			var path := arg.trim_prefix("--capture=")
			gold = 37
			await get_tree().create_timer(6.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()
