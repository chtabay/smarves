extends RefCounted
## Le rendu de Casino Minuit, porté du moteur web (js/engine.js, profils de scène V3 et finition) : ce qui fait
## l'ambiance d'une salle et que la scène règle à chaque image d'après la zone où l'on est.
## - Les profils de scène (public, coulisses, extérieur) et l'ambiance propre à chaque zone (ctx.setEnv) : fond,
##   brouillard linéaire, lumière ambiante et hémisphère, exposition ; on y glisse en fondu (2 par seconde), et vers
##   le profil extérieur à l'approche de l'entrée.
## - Le ton ACES et l'adaptation de l'œil : le moteur web corrige l'exposition d'après la luminance de l'image ; ici,
##   le facteur où cette adaptation s'arrête dans chaque salle (relevé aux vues de référence) est figé par zone.
## - Les lampes au budget : 118 lampes déclarées dans le moteur web, six lumières réelles réattribuées quatre fois par
##   seconde aux plus proches (devant le regard d'abord, même niveau), avec fondu ; un projecteur de même.
## - Les halos : les fausses lumières additives (K.Halos), un MultiMesh par zone.
## - La visibilité : une zone ne dessine que ce qu'on voit d'elle (ses « sees », son groupe, les voisines de ses
##   grandes ouvertures), et les zones voisines à moins de 7 m apportent les leurs.
## Les données (zones, lampes, projecteurs, halos) sont relevées dans le moteur web : donnees/rendu.json.

const BASE := "res://communes/casino_minuit/"
const PROFILS := {
	"public": {"fond": "#0c0507", "brume": ["#120609", 16.0, 95.0], "amb": ["#ffd2ae", 0.13], "hemi": ["#ffcf9a", "#2a0c12", 0.17],
		"expo": 0.9, "gain": 0.45, "decroit": 1.8},
	"coulisses": {"fond": "#121417", "brume": ["#15181b", 14.0, 60.0], "amb": ["#dde8f5", 0.26], "hemi": ["#eaf2ff", "#2f3836", 0.2],
		"expo": 0.95, "gain": 0.7, "decroit": 1.4},
	"exterieur": {"fond": "#04050b", "brume": ["#0b0d1a", 60.0, 430.0], "amb": ["#7484c0", 0.2], "hemi": ["#2a3a70", "#3a2416", 0.38],
		"expo": 1.0, "gain": 0.8, "decroit": 1.5},
}
## L'œil adapté, par zone : le facteur d'exposition où l'adaptation du moteur web se pose (bornée à [0,4 ; 2,4]).
## Les salles sombres montent au plafond ; les boutiques, sous leur ciel clair, redescendent.
const OEIL := {"M-LOUNGE": 2.4, "R-POKER": 2.4, "R-MACHINES": 2.4, "R-PIT": 2.1, "M-RESTAURANT": 2.4, "R-SPORTS": 2.4,
	"R-HL": 2.0, "R-SALON": 2.0, "M-BOUTIQUES": 1.0, "M-GALERIE": 1.3, "M-JARDIN": 1.05}
## Les zones du moteur web que le portage a réunies sous un seul nœud.
const NOEUDS := {"R-ESCALIER-PALIER": "R-ESCALIER", "ESC-STAFF-B": "ESC-STAFF", "ESC-STAFF-H": "ESC-STAFF", "M-ESC-STAFF": "ESC-STAFF",
	"F-SCENE": "F-CONCERT", "F-RING": "F-ARENE-SALLE"}
const POOL := 6
const PREFETCH := 7.0
## Ce que Godot rend autrement que three.js r128, mis à l'échelle une fois pour toutes : l'exposition (la courbe
## ACES de Godot n'a pas le 1/0,6 de three.js), l'énergie des lampes, celle de l'hémisphère, celle des halos.
const EXPO_K := 1.0
const LAMPE_K := 1.0
const HEMI_K := 1.0
const HALO_K := 1.0

var scene: Node3D
var env: Environment
var haut: DirectionalLight3D
var zones: Array = []
var _par_id := {}
var lampes: Array = []
var projecteurs: Array = []
var _pool: Array = []
var _spot: SpotLight3D
var _spot_cur = null
var _spot_voulu = null
var _spot_k := 0.0
var _choix: Array = []
var _t_lum := 0.0
var _mat_halo: ShaderMaterial
var _halos := {}
var _expo_compensee := -1.0
## L'état courant (fondu) : couleurs linéaires, exposition, brouillard.
var _c := {}
var zone: Dictionary = {}
var visibles := {}
var _t_vis := 0.0


func _init(s: Node3D) -> void:
	scene = s
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "donnees/rendu.json"))
	zones = d.zones
	for z in zones:
		_par_id[z.id] = z
	lampes = d.lampes
	projecteurs = d.projecteurs
	_environnement()
	for i in POOL:
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		l.visible = false
		l.shadow_enabled = false
		scene.add_child(l)
		_pool.append({"l": l, "lampe": null, "k": 0.0})
	_spot = SpotLight3D.new()
	_spot.visible = false
	scene.add_child(_spot)
	_halos_materiau()
	_halos = d.halos


func _environnement() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_curve = 1.0
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	# L'hémisphère : l'ambiante en porte la moyenne ; cette lumière d'en haut, la différence ciel-sol.
	haut = DirectionalLight3D.new()
	haut.rotation_degrees = Vector3(-90, 0, 0)
	haut.shadow_enabled = false
	scene.add_child(haut)
	_cible(PROFILS.public, 1.0, 0.0)
	for k in _c:
		_c[k] = _c[k + "_v"] if _c.has(k + "_v") else _c[k]
	_appliquer()


static func _lin(h: String) -> Color:
	return Color(h).srgb_to_linear()


## Le profil visé (profil de scène, ambiance de la zone, poids de l'extérieur) : couleurs linéaires.
func _cible(e: Dictionary, oeil: float, w: float) -> void:
	var x: Dictionary = PROFILS.exterieur
	var fond := _lin(e.fond).lerp(_lin(x.fond), w)
	var brume := _lin(e.brume[0]).lerp(_lin(x.brume[0]), w)
	var amb: Color = _lin(e.amb[0]) * float(e.amb[1])
	var ciel: Color = _lin(e.hemi[0])
	var sol: Color = _lin(e.hemi[1])
	var ih: float = e.hemi[2] * HEMI_K
	_c["fond_v"] = fond
	_c["brume_v"] = brume
	_c["pres_v"] = lerpf(e.brume[1], x.brume[1], w)
	_c["loin_v"] = lerpf(e.brume[2], x.brume[2], w)
	_c["amb_v"] = amb + (ciel + sol) * 0.5 * ih
	_c["haut_v"] = Color(maxf(ciel.r - sol.r, 0.0), maxf(ciel.g - sol.g, 0.0), maxf(ciel.b - sol.b, 0.0)) * 0.5 * ih
	_c["expo_v"] = float(e.expo) * oeil * EXPO_K
	for k in ["fond", "brume", "pres", "loin", "amb", "haut", "expo"]:
		if not _c.has(k):
			_c[k] = _c[k + "_v"]


func _appliquer() -> void:
	env.background_color = (_c.fond as Color).linear_to_srgb()
	env.fog_light_color = (_c.brume as Color).linear_to_srgb()
	env.fog_depth_begin = _c.pres
	env.fog_depth_end = _c.loin
	var a: Color = _c.amb
	var m := maxf(maxf(a.r, a.g), maxf(a.b, 0.0001))
	env.ambient_light_color = Color(a.r / m, a.g / m, a.b / m).linear_to_srgb()
	env.ambient_light_energy = m
	var h: Color = _c.haut
	var mh := maxf(maxf(h.r, h.g), maxf(h.b, 0.0001))
	haut.light_color = Color(h.r / mh, h.g / mh, h.b / mh).linear_to_srgb()
	haut.light_energy = mh
	env.tonemap_exposure = _c.expo
	var k = scene.get("K")
	if k != null and absf(_expo_compensee - _c.expo) > 0.005:
		_expo_compensee = _c.expo
		k.compenser(_c.expo)
	if _mat_halo:
		_mat_halo.set_shader_parameter("brume_pres", _c.pres)
		_mat_halo.set_shader_parameter("brume_loin", _c.loin)
		_mat_halo.set_shader_parameter("gain", HALO_K / maxf(_c.expo, 0.1))


# --- Zones -------------------------------------------------------------------------------------------

## La zone du moteur web où se trouve un point (le cadre le contient, la plus proche en hauteur, à 2,5 m près).
func zone_a(p: Vector3) -> Dictionary:
	var best := {}
	var bd := 2.5
	for z in zones:
		var b: Array = z.b
		if p.x < b[0] or p.x > b[1] or p.z < b[2] or p.z > b[3]:
			continue
		var y0 := float(z.y) - 0.6
		var y1 := float(z.y) + float(z.h)
		var d := maxf(maxf(y0 - p.y, p.y - y1), 0.0) * 10.0 + absf(p.y - float(z.y)) * 0.01
		if d < bd:
			bd = d
			best = z
	return best


static func noeud(id: String) -> String:
	return NOEUDS.get(id, id)


func _voit(z: Dictionary, id: String) -> int:
	var s = z.voit
	if s is Array:
		if id in s:
			return 1
		if (id + "*") in s:
			return 2
	return 0


static func _scene_ok(a: String, b: String) -> bool:
	return a == b or (a != "coulisses" and b != "coulisses")


## Les zones vues depuis cur (seenFrom) : elle-même, son groupe, celles qu'elle voit ou qui la voient, au second rang
## celles qu'on voit par une grande ouverture, et pour deux zones sans « sees », celles du même niveau non closes.
func _vues_depuis(cur: Dictionary, out: Dictionary, rang: int) -> void:
	if cur.is_empty():
		return
	for z in zones:
		if not _scene_ok(z.scene, cur.scene):
			continue
		var direct: bool = z == cur or (cur.groupe != null and z.groupe == cur.groupe) or _voit(cur, z.id) > 0 or _voit(z, cur.id) > 0 \
			or (cur.voit == null and z.voit == null and z.niv == cur.niv and not z.clos and not cur.clos)
		if not direct:
			continue
		var neuve: bool = not out.has(z.id)
		out[z.id] = z
		if neuve and rang == 0 and z != cur and (_voit(cur, z.id) == 2 or _voit(z, cur.id) == 2):
			_vues_depuis(z, out, 1)


static func _dist_cadre(z: Dictionary, x: float, zz: float) -> float:
	var b: Array = z.b
	return Vector2(maxf(maxf(b[0] - x, 0.0), x - b[1]), maxf(maxf(b[2] - zz, 0.0), zz - b[3])).length()


## Les noms des nœuds de zone à dessiner d'où l'on est (vide : hors des zones relevées).
func noeuds_visibles(p: Vector3) -> Dictionary:
	var out := {}
	_vues_depuis(zone, out, 0)
	for id in out.keys():
		var z: Dictionary = out[id]
		if z != zone and absf(float(z.niv) - float(zone.niv)) <= 0.5 and _dist_cadre(z, p.x, p.z) < PREFETCH:
			_vues_depuis(z, out, 0)
	visibles = out
	var noms := {}
	for id in out:
		noms[noeud(id)] = true
	return noms


# --- Chaque image ------------------------------------------------------------------------------------

func chaque_image(dt: float, p: Vector3, regard: Vector3) -> void:
	zone = zone_a(p)
	var sc: String = zone.get("scene", "exterieur") if not zone.is_empty() else "exterieur"
	var base: Dictionary = PROFILS[sc]
	var e := base.duplicate()
	var ze: Dictionary = zone.get("env", {}) if not zone.is_empty() else {}
	for k in ze:
		e[k] = ze[k]
	# Le poids de l'extérieur : 0,85 au seuil de l'entrée, nul à 18 m.
	var w := 0.0
	if sc == "public" and _par_id.has("X-STRIP"):
		var dx := _dist_cadre(_par_id["X-STRIP"], p.x, p.z)
		if dx < 18.0:
			w = 0.85 * (1.0 - dx / 18.0)
	var oeil: float = OEIL.get(zone.get("id", ""), 1.0)
	_cible(e, oeil, w)
	var k := minf(1.0, dt * 2.0)
	for c in ["fond", "brume", "amb", "haut"]:
		_c[c] = (_c[c] as Color).lerp(_c[c + "_v"], k)
	for c in ["pres", "loin", "expo"]:
		_c[c] = lerpf(_c[c], _c[c + "_v"], k)
	_appliquer()
	_lumieres(dt, p, regard, e)


func _lumieres(dt: float, p: Vector3, regard: Vector3, e: Dictionary) -> void:
	var ly: float = zone.get("y", p.y) if not zone.is_empty() else p.y
	_t_lum -= dt
	if _t_lum <= 0.0:
		_t_lum = 0.25
		var cand := []
		var f := Vector2(regard.x, regard.z).normalized()
		for l in lampes:
			var zl: Dictionary = _par_id.get(l[0], {})
			if zl.is_empty() or not visibles.has(l[0]) or absf(float(zl.y) - ly) > 1.5:
				continue
			var dx: float = l[1] - p.x
			var dy: float = (l[2] - p.y - 1.6) * 2.0
			var dz: float = l[3] - p.z
			var d := sqrt(dx * dx + dy * dy + dz * dz)
			var hd := Vector2(dx, dz).length()
			var front := 1.0 if hd < 2.0 else (dx * f.x + dz * f.y) / hd
			var s: float = (1.0 + d) / float(l[8]) / (1.0 + 0.8 * maxf(0.0, front))
			for u in _pool:
				if u.lampe == l and u.k > 0.0:
					s *= 0.75
			cand.append([s, l])
		cand.sort_custom(func(a, b): return a[0] < b[0])
		_choix = []
		for c in cand.slice(0, POOL):
			_choix.append(c[1])
		var best = null
		var bd := 1e12
		for s in projecteurs:
			var zs: Dictionary = _par_id.get(s[0], {})
			if zs.is_empty() or not visibles.has(s[0]) or absf(float(zs.y) - ly) > 1.5:
				continue
			var d := Vector3(s[1] - p.x, s[2] - p.y - 3.0, s[3] - p.z).length()
			if d < bd:
				bd = d
				best = s
		_spot_voulu = best
	var gain: float = e.get("gain", 0.45) * LAMPE_K
	var decroit: float = e.get("decroit", 1.8)
	for u in _pool:
		var l: OmniLight3D = u.l
		if u.lampe != null and u.lampe in _choix:
			u.k = minf(1.0, u.k + dt * 2.5)
		else:
			u.k = maxf(0.0, u.k - dt * 2.5)
			if u.k == 0.0:
				u.lampe = null
				for c in _choix:
					var libre := true
					for o in _pool:
						if o.lampe == c:
							libre = false
					if libre:
						u.lampe = c
						break
				if u.lampe != null:
					var c: Array = u.lampe
					l.global_position = Vector3(c[1], c[2], c[3])
					l.light_color = Color(c[4])
					l.omni_range = c[6]
					# three.js : (1 - d/portée)^décroissance ; Godot : d^-a dans une fenêtre douce. a ≈ 0,36 × décroissance.
					l.omni_attenuation = 0.36 * maxf(float(c[7]), decroit)
		l.light_energy = (float(u.lampe[5]) * u.k * gain) if u.lampe != null else 0.0
		l.visible = l.light_energy > 0.001
	if _spot_voulu != null and _spot_voulu == _spot_cur:
		_spot_k = minf(1.0, _spot_k + dt * 3.0)
	else:
		_spot_k = maxf(0.0, _spot_k - dt * 3.0)
		if _spot_k == 0.0:
			_spot_cur = _spot_voulu
			if _spot_cur != null:
				var s: Array = _spot_cur
				_spot.global_position = Vector3(s[1], s[2], s[3])
				var cible := Vector3(s[4], s[5], s[6])
				var dir := (cible - _spot.global_position).normalized()
				_spot.look_at(cible, Vector3.FORWARD if absf(dir.y) > 0.99 else Vector3.UP)
				_spot.light_color = Color(s[7])
				_spot.spot_range = s[9]
				_spot.spot_angle = rad_to_deg(s[10])
				_spot.spot_angle_attenuation = 1.0 + 2.0 * float(s[11])
				_spot.spot_attenuation = 0.36
	_spot.light_energy = (float(_spot_cur[8]) * _spot_k * gain) if _spot_cur != null else 0.0
	_spot.visible = _spot.light_energy > 0.001


# --- Halos -------------------------------------------------------------------------------------------

func _halos_materiau() -> void:
	_mat_halo = ShaderMaterial.new()
	_mat_halo.shader = load(BASE + "shaders/halo.gdshader")


## Pose les halos relevés sous les nœuds de zone (un MultiMesh par zone, vu ou caché avec elle).
func poser_halos() -> int:
	var d := _halos
	var n := 0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for id in d:
		var nd := scene.get_node_or_null(noeud(id)) as Node3D
		if nd == null:
			continue
		var liste: Array = d[id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = liste.size()
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		var inv := nd.global_transform.affine_inverse()
		for i in liste.size():
			var h: Array = liste[i]
			var pos := inv * Vector3(h[0], h[1], h[2])
			mm.set_instance_transform(i, Transform3D(Basis(), pos))
			mm.set_instance_color(i, Color(1, 1, 1, float(h[7])))
			var c := Color(h[3], h[4], h[5]).srgb_to_linear()
			mm.set_instance_custom_data(i, Color(c.r, c.g, c.b, h[6]))
			lo = lo.min(pos - Vector3.ONE * h[6])
			hi = hi.max(pos + Vector3.ONE * h[6])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Halos"
		mi.multimesh = mm
		mi.material_override = _mat_halo
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(lo, hi - lo)
		nd.add_child(mi)
		n += liste.size()
	return n
