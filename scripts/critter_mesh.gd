class_name CritterMesh
extends RefCounted
## Fabrique le corps d'un habitant à partir de sa fiche (Cast) : un seul maillage lissé, peint par sommets,
## posé sur un petit squelette partagé par toute la famille. Un seul appel de rendu par habitant, et un
## maillage mis en cache par fiche, pour qu'une place pleine de monde reste légère.
##
## Repère : le personnage regarde +Z, sa gauche est +X, les pieds sont en y = 0 ; environ 0,75 de haut
## à l'échelle 1 (grosse tête ronde, petit corps, façon Happy Tree Friends).

## [nom, parent] : l'ordre fixe les indices des os.
const BONES := [
	["root", -1], ["hips", 0], ["spine", 1], ["chest", 2], ["head", 3],
	["eye_l", 4], ["eye_r", 4], ["brow_l", 4], ["brow_r", 4], ["smile", 4], ["frown", 4], ["mouth", 4],
	["ear_l", 4], ["ear_r", 4],
	["arm_l", 3], ["forearm_l", 14], ["hand_l", 15], ["arm_r", 3], ["forearm_r", 17], ["hand_r", 18],
	["thigh_l", 1], ["shin_l", 20], ["foot_l", 21], ["thigh_r", 1], ["shin_r", 23], ["foot_r", 24],
	["tail", 1], ["tail_tip", 26],
]
enum { ROOT, HIPS, SPINE, CHEST, HEAD, EYE_L, EYE_R, BROW_L, BROW_R, SMILE, FROWN, MOUTH, EAR_L, EAR_R,
	ARM_L, FOREARM_L, HAND_L, ARM_R, FOREARM_R, HAND_R, THIGH_L, SHIN_L, FOOT_L, THIGH_R, SHIN_R, FOOT_R,
	TAIL, TAIL_TIP }

const DARK := Color(0.09, 0.07, 0.09)
const WHITE := Color(0.98, 0.97, 0.95)
const BLUSH := Color(1.0, 0.6, 0.66)
const MOUTH_IN := Color(0.45, 0.08, 0.12)
const GOLD := Color(0.86, 0.66, 0.27)

static var _cache := {}
static var _material: ShaderMaterial

# Tampons du maillage en cours.
var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _uv := PackedVector2Array()
var _b := PackedInt32Array()
var _w := PackedFloat32Array()
var _i := PackedInt32Array()

var look: Dictionary
## Positions de repos des os, dans le repère du personnage.
var rest: Array[Vector3] = []
# Grandeurs du gabarit.
var hip_y: float
var torso_h: float
var shoulder_y: float
var neck_y: float
var head_c: Vector3
var head_r: Vector3
var k: float
var w: float
var belly: float
var arm_len: float
var leg: float
var _prof: Array = []
var _skirt: Array = []


## Le matériau commun : la couleur vient des sommets, l'UV porte la rugosité (x) et l'émission (y).
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/critter.gdshader")
		var outline := ShaderMaterial.new()
		outline.shader = preload("res://shaders/critter_outline.gdshader")
		_material.next_pass = outline
	return _material


## Le maillage, le squelette et ses os de repos pour une fiche ; le maillage est partagé entre fiches
## identiques, et gardé sur l'appareil d'un lancement à l'autre (Memo) : un habitant demande 14 ms de
## GDScript (six mille triangles, sommet par sommet) et un lieu en pose de 26 à 48 ; relu, moins d'un.
static func build(l: Dictionary) -> Dictionary:
	var key := var_to_str(l).hash()
	if _cache.has(key):
		return _cache[key]
	var d: Dictionary = Memo.valeur("figurines", "res://scripts/critter_mesh.gd", key, func():
		var cm := CritterMesh.new()
		cm.look = l
		var out: Dictionary = cm._make()
		var a: Array = out.mesh.surface_get_arrays(0)
		return {"v": a[Mesh.ARRAY_VERTEX], "n": a[Mesh.ARRAY_NORMAL], "c": a[Mesh.ARRAY_COLOR], "uv": a[Mesh.ARRAY_TEX_UV],
			"b": a[Mesh.ARRAY_BONES], "w": a[Mesh.ARRAY_WEIGHTS], "i": a[Mesh.ARRAY_INDEX],
			"rest": out.rest, "height": out.height, "leg": out.leg, "face": out.face})
	var out := _depuis(d)
	_cache[key] = out
	return out


static func _depuis(d: Dictionary) -> Dictionary:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = d.v
	arrays[Mesh.ARRAY_NORMAL] = d.n
	arrays[Mesh.ARRAY_COLOR] = d.c
	arrays[Mesh.ARRAY_TEX_UV] = d.uv
	arrays[Mesh.ARRAY_BONES] = d.b
	arrays[Mesh.ARRAY_WEIGHTS] = d.w
	arrays[Mesh.ARRAY_INDEX] = d.i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	var rest: Array[Vector3] = []
	rest.assign(d.rest)
	var skin := Skin.new()
	for bi in BONES.size():
		skin.add_bind(bi, Transform3D(Basis(), -rest[bi]))
	return {"mesh": mesh, "skin": skin, "rest": rest, "height": float(d.height), "leg": float(d.leg), "face": float(d.face)}


func _make() -> Dictionary:
	_rig()
	_body()
	_head()
	_limbs()
	_outfit()
	_props()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_BONES] = _b
	arrays[Mesh.ARRAY_WEIGHTS] = _w
	arrays[Mesh.ARRAY_INDEX] = _i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	var skin := Skin.new()
	for bi in BONES.size():
		skin.add_bind(bi, Transform3D(Basis(), -rest[bi]))
	return {"mesh": mesh, "skin": skin, "rest": rest.duplicate(), "height": head_c.y + head_r.y, "leg": leg, "face": head_r.y / 0.158}


# --- Le gabarit ---------------------------------------------------------------------------

func _g(key: String, def: Variant) -> Variant:
	return look.get(key, def)


func _col(key: String, def := Color.WHITE) -> Color:
	var c: Variant = look.get(key, def)
	return Color(c) if c is String else c


func _rig() -> void:
	var build: Dictionary = _g("build", {})
	leg = 0.17 * float(build.get("leg", 1.0))
	torso_h = 0.23 * float(build.get("torso", 1.0))
	w = float(build.get("width", 1.0))
	belly = float(build.get("belly", 1.0))
	k = float(build.get("head", 1.0))
	arm_len = 0.165 * float(build.get("arm", 1.0)) * lerpf(1.0, float(build.get("torso", 1.0)), 0.5)
	hip_y = leg + 0.006
	shoulder_y = hip_y + torso_h * 0.84
	neck_y = hip_y + torso_h
	head_r = Vector3(0.175, 0.158, 0.152) * k
	head_c = Vector3(0, neck_y + head_r.y * 0.78, 0)
	if _human():
		# Ligne claire : des proportions d'adulte, la tête vers un sixième de la hauteur.
		leg = 0.255 * float(build.get("leg", 1.0))
		torso_h = 0.25 * float(build.get("torso", 1.0))
		w = 0.84 * float(build.get("width", 1.0))
		arm_len = 0.215 * float(build.get("arm", 1.0)) * lerpf(1.0, float(build.get("torso", 1.0)), 0.5)
		hip_y = leg + 0.006
		shoulder_y = hip_y + torso_h * 0.86
		neck_y = hip_y + torso_h
		k = 0.44 * float(build.get("head", 1.0))
		head_r = Vector3(0.172, 0.2, 0.18) * k
		head_c = Vector3(0, neck_y + 0.026 + head_r.y * 0.86, 0)
	rest.resize(BONES.size())
	var sx := 0.07 * w * lerpf(1.0, belly, 0.3)
	var hx := 0.043 * w * lerpf(1.0, belly, 0.4)
	rest[ROOT] = Vector3.ZERO
	rest[HIPS] = Vector3(0, hip_y, 0)
	rest[SPINE] = Vector3(0, hip_y + torso_h * 0.42, 0)
	rest[CHEST] = Vector3(0, hip_y + torso_h * 0.72, 0)
	rest[HEAD] = Vector3(0, neck_y, 0)
	var eye_yaw := 0.3 if _human() else 0.36
	for s in [1.0, -1.0]:
		var e := _on_head(s * eye_yaw, 0.06)
		rest[EYE_L if s > 0 else EYE_R] = e[0]
		rest[BROW_L if s > 0 else BROW_R] = _on_head(s * 0.34, 0.36)[0]
		var arm := Vector3(s * sx, shoulder_y, 0)
		rest[ARM_L if s > 0 else ARM_R] = arm
		rest[FOREARM_L if s > 0 else FOREARM_R] = arm + Vector3(s * 0.008, -arm_len * 0.5, 0.004)
		rest[HAND_L if s > 0 else HAND_R] = arm + Vector3(s * 0.012, -arm_len, 0.01)
		rest[THIGH_L if s > 0 else THIGH_R] = Vector3(s * hx, hip_y, 0)
		rest[SHIN_L if s > 0 else SHIN_R] = Vector3(s * hx, hip_y - leg * 0.5, 0.004)
		rest[FOOT_L if s > 0 else FOOT_R] = Vector3(s * hx, 0.03, 0)
		rest[EAR_L if s > 0 else EAR_R] = head_c
	var front := _on_head(0.0, -0.3)
	rest[SMILE] = front[0]
	rest[FROWN] = front[0]
	rest[MOUTH] = front[0]
	rest[TAIL] = Vector3(0, hip_y + 0.01, -0.06 * belly * w)
	rest[TAIL_TIP] = rest[TAIL] + Vector3(0, 0.05, -0.12)


## Un point sur la tête : [position, normale] pour un lacet et un tangage (radians) depuis l'avant.
func _on_head(yaw: float, pitch: float, lift := 0.0) -> Array:
	var d := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var p := head_c + head_r * d
	var nrm := (d / head_r).normalized()
	return [p + nrm * lift, nrm]


static func _facing(nrm: Vector3, roll := 0.0) -> Basis:
	var z := nrm.normalized()
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.FORWARD
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	var b := Basis(x, y, z)
	return b * Basis(Vector3.BACK, roll) if roll != 0.0 else b


# --- Les primitives -----------------------------------------------------------------------
# Toutes émettent une grille (nu colonnes autour, nv rangées le long), lissée, et découpée en bandes de couleur
# nettes ; bones dit à quel os chaque sommet obéit : un entier (rigide), {"y": [[y, os], ...]} (fondu selon la
# hauteur) ou {"t": [[t, os], ...]} (fondu le long de la forme).


func _weights(spec: Variant, p: Vector3, t: float) -> Array:
	if spec is int:
		return [spec, spec, 0.0]
	var key := "y" if spec.has("y") else "t"
	var x := p.y if key == "y" else t
	var pts: Array = spec[key]
	if x <= pts[0][0]:
		return [pts[0][1], pts[0][1], 0.0]
	for j in range(1, pts.size()):
		if x <= pts[j][0]:
			var f := inverse_lerp(float(pts[j - 1][0]), float(pts[j][0]), x)
			return [pts[j - 1][1], pts[j][1], smoothstep(0.0, 1.0, f)]
	return [pts[-1][1], pts[-1][1], 0.0]


## bands : [[t_début, couleur], ...] ; t va de 0 (première rangée) à 1 (dernière).
func _grid(pts: PackedVector3Array, nu: int, nv: int, center: Vector3, bands: Array, rough: float, bones: Variant, emit := 0.0, axis_pts := PackedVector3Array(), wrap := true) -> void:
	var cols := nu
	# Normales par différences dans la grille (le bord en u se referme).
	var nrm := PackedVector3Array()
	nrm.resize(pts.size())
	for j in nv + 1:
		for i in cols:
			var p := pts[j * cols + i]
			var du := pts[j * cols + (i + 1) % cols] - pts[j * cols + (i - 1 + cols) % cols]
			if not wrap:
				du = pts[j * cols + mini(i + 1, cols - 1)] - pts[j * cols + maxi(i - 1, 0)]
			var dv := pts[mini(j + 1, nv) * cols + i] - pts[maxi(j - 1, 0) * cols + i]
			var n := du.cross(dv)
			var ref := p - (axis_pts[j] if axis_pts.size() > 0 else center)
			if n.length_squared() < 1e-12:
				n = ref
			n = n.normalized()
			if n.dot(ref) < 0.0:
				n = -n
			nrm[j * cols + i] = n
	# Le sens des triangles suit la normale, quel que soit le sens du profil.
	var flip := false
	var jm := nv / 2
	for i in cols:
		var a := pts[jm * cols + i]
		var e := (pts[mini(jm + 1, nv) * cols + i] - a).cross(pts[jm * cols + (i + 1) % cols] - a)
		if e.length_squared() > 1e-14:
			flip = e.dot(nrm[jm * cols + i]) > 0.0
			break
	for bi in bands.size():
		var j0 := roundi(float(bands[bi][0]) * nv)
		var j1 := nv if bi == bands.size() - 1 else roundi(float(bands[bi + 1][0]) * nv)
		if j1 <= j0:
			continue
		var col: Color = bands[bi][1]
		var base := _v.size()
		for j in range(j0, j1 + 1):
			for i in cols:
				var p := pts[j * cols + i]
				_put(p, nrm[j * cols + i], col, rough, emit, _weights(bones, p, float(j) / nv))
		for j in j1 - j0:
			for i in (cols if wrap else cols - 1):
				var a := base + j * cols + i
				var b := base + j * cols + (i + 1) % cols
				var c := a + cols
				var d := b + cols
				if flip:
					_i.append_array([a, b, c, b, d, c])
				else:
					_i.append_array([a, c, b, b, c, d])


func _put(p: Vector3, n: Vector3, col: Color, rough: float, emit: float, wt: Array) -> void:
	_v.append(p)
	_n.append(n)
	_c.append(col)
	_uv.append(Vector2(rough, emit))
	_b.append_array([wt[0], wt[1], 0, 0])
	_w.append_array([1.0 - wt[2], wt[2], 0.0, 0.0])


## Un ellipsoïde, éventuellement effilé (taper > 0 élargit le haut local, < 0 l'affine).
func ellipsoid(center: Vector3, radii: Vector3, basis: Basis, col: Variant, rough: float, bones: Variant,
		taper := 0.0, nu := 16, nv := 10, emit := 0.0) -> void:
	var pts := PackedVector3Array()
	for j in nv + 1:
		var phi := PI * (float(j) / nv - 0.5)
		var y := sin(phi)
		var r := cos(phi)
		var f := maxf(0.02, 1.0 + taper * y)
		for i in nu:
			var th := TAU * i / nu
			var lp := Vector3(sin(th) * r * radii.x * f, y * radii.y, cos(th) * r * radii.z * f)
			pts.append(center + basis * lp)
	_grid(pts, nu, nv, center, _bands(col), rough, bones, emit)


## Une forme de révolution autour de l'axe Y local : profil [[rayon, y], ...] du bas vers le haut.
func lathe(center: Vector3, profile: Array, basis: Basis, col: Variant, rough: float, bones: Variant,
		squash := 1.0, nu := 18, emit := 0.0, arc := TAU) -> void:
	var pts := PackedVector3Array()
	var axis := PackedVector3Array()
	var nv := profile.size() - 1
	var full := arc >= TAU - 0.001
	var cols := nu if full else nu + 1
	for j in nv + 1:
		var r: float = profile[j][0]
		var y: float = profile[j][1]
		axis.append(center + basis * Vector3(0, y, 0))
		for i in cols:
			var th := TAU * i / nu if full else lerpf(-arc / 2.0, arc / 2.0, float(i) / nu)
			pts.append(center + basis * Vector3(sin(th) * r, y, cos(th) * r * squash))
	_grid(pts, cols, nv, center, _bands(col), rough, bones, emit, axis, full)


## Un tube le long d'une ligne de points, rayons par point ; les bouts sont arrondis.
func tube(points: Array, radii: Array, col: Variant, rough: float, bones: Variant, nu := 10, round_ends := true, emit := 0.0) -> void:
	var p := PackedVector3Array(points)
	var r := PackedFloat32Array(radii)
	if round_ends:
		var t0 := (p[1] - p[0]).normalized()
		var t1 := (p[-1] - p[-2]).normalized()
		p.insert(0, p[0] - t0 * r[0] * 0.55)
		r.insert(0, r[0] * 0.75)
		p.insert(0, p[0] - t0 * r[1] * 0.42)
		r.insert(0, 0.0)
		p.append(p[-1] + t1 * r[-1] * 0.55)
		r.append(r[-1] * 0.75)
		p.append(p[-1] + t1 * r[-2] * 0.42)
		r.append(0.0)
	var nv := p.size() - 1
	var pts := PackedVector3Array()
	var tang := (p[1] - p[0]).normalized()
	var normal := tang.cross(Vector3.UP if absf(tang.y) < 0.9 else Vector3.RIGHT).normalized()
	for j in nv + 1:
		var t: Vector3
		if j == 0:
			t = (p[1] - p[0]).normalized()
		elif j == nv:
			t = (p[nv] - p[nv - 1]).normalized()
		else:
			t = (p[j + 1] - p[j - 1]).normalized()
		# Transport parallèle du repère.
		normal = (normal - t * normal.dot(t)).normalized()
		var binorm := t.cross(normal)
		for i in nu:
			var th := TAU * i / nu
			pts.append(p[j] + (normal * cos(th) + binorm * sin(th)) * r[j])
	_grid(pts, nu, nv, Vector3.ZERO, _bands(col), rough, bones, emit, p)


## Une boîte à faces plates (accessoires : carnet, mallette, cartes).
func box(center: Vector3, size: Vector3, basis: Basis, col: Color, rough: float, bone: int) -> void:
	var h := size / 2.0
	for f in 6:
		var ax := f / 2
		var sg := 1.0 if f % 2 == 0 else -1.0
		var n := Vector3.ZERO
		n[ax] = sg
		var u := Vector3.ZERO
		u[(ax + 1) % 3] = 1.0
		var v := n.cross(u)
		var base := _v.size()
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var lp: Vector3 = n * h[ax] + u * c.x * h[(ax + 1) % 3] + v * c.y * h[(ax + 2) % 3]
			_put(center + basis * lp, (basis * n).normalized(), col, rough, 0.0, [bone, bone, 0.0])
		_i.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


func _bands(col: Variant) -> Array:
	if col is Color:
		return [[0.0, col]]
	return col


## Une bande : couleur a, puis b à partir de t.
static func band(a: Color, t: float, b: Color) -> Array:
	return [[0.0, a], [t, b]]


# --- Le corps -----------------------------------------------------------------------------

func _species() -> String:
	return _g("species", "humain")


func _human() -> bool:
	return _species() == "humain"


## Une couleur sans contour noir (les petits détails : yeux, bouche, boutons).
static func _bare(c: Color) -> Color:
	return Color(c, 0.0)


func _body() -> void:
	var fur := _col("fur")
	var top := _top_color()
	var legs := _legs_color()
	var waist := hip_y + 0.022
	var b := belly
	var prof := [
		[0.0, hip_y - 0.05], [0.042 * w, hip_y - 0.044], [0.07 * w * lerpf(1.0, b, 0.6), hip_y - 0.012],
		[0.084 * w * b, hip_y + torso_h * 0.28], [0.08 * w * lerpf(b, 1.0, 0.45), hip_y + torso_h * 0.55],
		[0.068 * w, shoulder_y - 0.005], [0.05 * w, neck_y - 0.022], [0.032, neck_y + 0.005], [0.0, neck_y + 0.02],
	]
	# Un profil plus fin pour que les bandes (marinière, ceinture) tombent juste.
	var fine := _resample(prof, 22)
	_prof = fine
	var bands := []
	var waist_t := _t_of(fine, waist)
	var style: String = _g("top", "nu")
	bands.append([0.0, top if style == "robe" else legs])
	if style == "mariniere":
		var stripe: Color = _col("top2", WHITE)
		bands.append([waist_t, top])
		var n := 6
		for s in n:
			var y0 := lerpf(waist + 0.02, shoulder_y + 0.01, float(s) / n)
			bands.append([_t_of(fine, y0), stripe if s % 2 == 0 else top])
	else:
		bands.append([waist_t, top])
	var bones := {"y": [[hip_y - 0.01, HIPS], [hip_y + torso_h * 0.45, SPINE], [shoulder_y, CHEST]]}
	lathe(Vector3.ZERO, fine, Basis(), bands, 0.75, bones, 0.84, 20)
	if _human():
		# Le cou.
		tube([Vector3(0, neck_y - 0.01, 0.002), Vector3(0, neck_y + 0.012, 0.004), Vector3(0, head_c.y - head_r.y * 0.6, 0.006)],
			[0.022 * w, 0.02 * w, 0.019 * w], fur, 0.8, {"y": [[neck_y, CHEST], [neck_y + 0.02, HEAD]]}, 10, false)
	# Le ventre clair, visible quand rien ne le couvre.
	if style == "nu":
		var fur2 := _col("fur2", fur.lightened(0.4))
		ellipsoid(Vector3(0, hip_y + torso_h * 0.32, 0.052 * b * w), Vector3(0.055 * w * b, 0.075, 0.035), Basis(),
			fur2, 0.8, {"y": [[hip_y, HIPS], [shoulder_y, CHEST]]}, 0.0, 12, 8)
	_tail(fur)


func _resample(prof: Array, n: int) -> Array:
	var out := []
	for j in n + 1:
		var f := float(j) / n * (prof.size() - 1)
		var a := floori(f)
		var b := mini(a + 1, prof.size() - 1)
		var t := f - a
		out.append([lerpf(prof[a][0], prof[b][0], t), lerpf(prof[a][1], prof[b][1], t)])
	return out


func _t_of(prof: Array, y: float) -> float:
	for j in prof.size():
		if prof[j][1] >= y:
			return float(j) / (prof.size() - 1)
	return 1.0


func _top_color() -> Color:
	match _g("top", "nu"):
		"nu":
			return _col("fur")
		_:
			return _col("top_color", Color(0.2, 0.3, 0.6))


func _legs_color() -> Color:
	var legs: String = _g("legs", "nu")
	if legs == "nu":
		return _col("fur")
	return _col("legs_color", Color(0.25, 0.25, 0.3))


func _tail(fur: Color) -> void:
	var t0 := rest[TAIL]
	var fur2 := _col("fur2", fur.lightened(0.4))
	var acc := _col("accent", fur.darkened(0.4))
	var tb := {"t": [[0.15, TAIL], [0.8, TAIL_TIP]]}
	match _g("tail", _default_tail()):
		"touffe":
			tube([t0 + Vector3(0, 0.0, 0.02), t0 + Vector3(0, -0.025, -0.06), t0 + Vector3(0, 0.02, -0.15),
				t0 + Vector3(0, 0.1, -0.2), t0 + Vector3(0, 0.17, -0.19)], [0.022, 0.05, 0.062, 0.05, 0.026],
				band(fur, 0.72, fur2), 0.85, tb, 12)
		"fine":
			tube([t0, t0 + Vector3(0, -0.02, -0.08), t0 + Vector3(0, 0.03, -0.16), t0 + Vector3(0, 0.12, -0.18),
				t0 + Vector3(0, 0.16, -0.13)], [0.016, 0.014, 0.013, 0.012, 0.01], fur, 0.8, tb, 8)
		"rose":
			tube([t0, t0 + Vector3(0, -0.06, -0.08), t0 + Vector3(0.02, -0.1, -0.17), t0 + Vector3(0.07, -0.1, -0.22),
				t0 + Vector3(0.1, -0.08, -0.2)], [0.012, 0.01, 0.009, 0.008, 0.006], _col("pink", BLUSH), 0.6, tb, 6)
		"pompon":
			ellipsoid(t0 + Vector3(0, 0.0, -0.025), Vector3(0.042, 0.04, 0.04), Basis(), fur2, 0.9, TAIL, 0.0, 10, 6)
		"plate":
			ellipsoid(t0 + Vector3(0, -0.05, -0.08), Vector3(0.05, 0.014, 0.085), Basis(Vector3.RIGHT, -0.7), acc, 0.7, tb, 0.25, 12, 8)
		"tire_bouchon":
			var pts := []
			var rr := []
			for j in 7:
				var a := j * 1.2
				pts.append(t0 + Vector3(sin(a) * 0.022, 0.012 * j, -0.01 - 0.014 * j + cos(a) * 0.02 - 0.02))
				rr.append(0.008)
			tube(pts, rr, fur, 0.7, tb, 6)
		"courte":
			tube([t0, t0 + Vector3(0, 0.02, -0.05), t0 + Vector3(0, 0.05, -0.08)], [0.03, 0.035, 0.025], fur, 0.85, tb, 10)
		"leve":
			tube([t0, t0 + Vector3(0, 0.03, -0.06), t0 + Vector3(0, 0.1, -0.1), t0 + Vector3(0, 0.15, -0.09)],
				[0.018, 0.02, 0.018, 0.012], fur, 0.8, tb, 8)
		"moignon":
			ellipsoid(t0 + Vector3(0, 0.0, -0.015), Vector3(0.03, 0.028, 0.026), Basis(), fur, 0.85, TAIL, 0.0, 8, 6)


func _default_tail() -> String:
	if _human():
		return ""
	return {"renard": "touffe", "chat": "fine", "souris": "rose", "lapin": "pompon", "castor": "plate",
		"sanglier": "tire_bouchon", "blaireau": "courte", "chien": "leve", "ours": "moignon", "herisson": "moignon"}.get(_species(), "moignon")


# --- La tête ------------------------------------------------------------------------------

func _head() -> void:
	if _human():
		_human_head()
		return
	var sp := _species()
	var fur := _col("fur")
	var fur2 := _col("fur2", fur.lightened(0.45))
	var acc := _col("accent", fur.darkened(0.45))
	var pink := _col("pink", BLUSH)
	var hb := HEAD
	# La tête : une boule un peu plus large en bas, comme un mochi.
	ellipsoid(head_c, head_r, Basis(), fur2 if sp == "blaireau" else fur, 0.85, hb, -0.07, 24, 16)
	# Le bas du visage clair (renard, blaireau, chat bicolore, hérisson).
	if sp in ["renard", "herisson"] or bool(_g("masque_clair", false)):
		var lf := _on_head(0.0, -0.32, -0.035)
		ellipsoid(lf[0], Vector3(0.13, 0.085, 0.07) * k, _facing(lf[1]), fur2, 0.85, hb, 0.0, 16, 10)
	if sp == "blaireau":
		for s in [-1.0, 1.0]:
			var pts := []
			var rr := []
			for j in 8:
				var pp := _on_head(s * 0.33, lerpf(-0.42, 1.35, j / 7.0), -0.012)
				pts.append(pp[0])
				rr.append(lerpf(0.026, 0.045, sin(PI * j / 7.0)) * k)
			tube(pts, rr, acc, 0.8, hb, 10)
	_muzzle(sp, fur, fur2, acc, pink)
	_eyes()
	_ears(sp, fur, fur2, acc, pink)
	if sp != "blaireau":
		for s in [-1.0, 1.0]:
			var ch := _on_head(s * 0.66, -0.22, -0.006)
			ellipsoid(ch[0], Vector3(0.03, 0.019, 0.008) * k, _facing(ch[1]), pink.lerp(fur, 0.25), 0.9, hb, 0.0, 10, 6)
	if sp == "herisson":
		_spikes(acc, fur2)
	if sp == "sanglier":
		for j in 5:
			var cr := _on_head(0.0, lerpf(0.75, 1.9, j / 4.0), -0.01)
			lathe(cr[0], [[0.016 * k, 0.0], [0.009 * k, 0.03 * k], [0.0, 0.05 * k]], _facing(cr[1]) * Basis(Vector3.RIGHT, PI / 2), acc, 0.9, hb, 1.0, 6)
	_face_extras()
	_hat()


## Un visage de bande dessinée : deux points pour les yeux, un nez rond, une bouche d'un trait.
func _human_head() -> void:
	var skin := _col("fur")
	var hb := HEAD
	var dark := _col("brow", _col("hair_color", DARK).darkened(0.2))
	# Le crâne, un peu plus étroit vers le menton.
	ellipsoid(head_c, head_r, Basis(), skin, 0.8, hb, 0.12, 22, 14)
	var jaw := float(_g("jaw", 1.0))
	if jaw != 1.0:
		ellipsoid(head_c + Vector3(0, -head_r.y * 0.45, head_r.z * 0.1), head_r * Vector3(0.8 * jaw, 0.5, 0.82), Basis(), skin, 0.8, hb, 0.0, 16, 8)
	# Les oreilles.
	for s in [-1.0, 1.0]:
		var e := _on_head(s * 1.52, -0.02, -0.004)
		ellipsoid(e[0], Vector3(0.022, 0.04, 0.03) * k, _facing(Vector3(s, 0, 0.25)), skin.darkened(0.04), 0.8, hb, 0.0, 10, 8)
	# Le nez : rond par défaut, ou la forme qui signe le personnage.
	var n0 := _on_head(0.0, -0.06, -0.006)
	var nose_col := skin.lerp(Color(0.85, 0.4, 0.35), float(_g("nose_red", 0.12)))
	match _g("nose", "rond"):
		"rond":
			ellipsoid(n0[0] + Vector3(0, -0.006, 0.028) * k, Vector3(0.036, 0.034, 0.036) * k, Basis(), nose_col, 0.7, hb, 0.0, 12, 8)
		"patate":
			ellipsoid(n0[0] + Vector3(0, -0.012, 0.034) * k, Vector3(0.05, 0.046, 0.044) * k, Basis(), nose_col, 0.7, hb, 0.0, 12, 8)
		"long":
			ellipsoid(n0[0] + Vector3(0, -0.012, 0.05) * k, Vector3(0.026, 0.03, 0.062) * k, Basis(Vector3.RIGHT, 0.35), nose_col, 0.7, hb, -0.3, 12, 8)
		"busque":
			ellipsoid(n0[0] + Vector3(0, -0.004, 0.044) * k, Vector3(0.026, 0.05, 0.05) * k, Basis(Vector3.RIGHT, -0.5), nose_col, 0.7, hb, 0.3, 12, 8)
		"retrousse":
			ellipsoid(n0[0] + Vector3(0, -0.01, 0.026) * k, Vector3(0.026, 0.024, 0.03) * k, Basis(Vector3.RIGHT, -0.4), nose_col, 0.7, hb, 0.0, 10, 6)
	# Les yeux : deux points noirs, avec ou sans le blanc autour.
	var size := float(_g("eyes", 1.0))
	for s in [-1.0, 1.0]:
		var bone := EYE_L if s > 0 else EYE_R
		var e := _on_head(s * 0.3, 0.06, -0.004)
		var nb := _facing(e[1])
		if bool(_g("eye_whites", false)):
			ellipsoid(e[0], Vector3(0.036, 0.034, 0.012) * k * size, nb, _bare(WHITE), 0.3, bone, 0.0, 10, 6)
		ellipsoid(e[0] + e[1] * 0.006 * k, Vector3(0.017, 0.026, 0.009) * k * size, nb, _bare(DARK), 0.15, bone, 0.0, 10, 6)
		rest[bone] = e[0]
		var brow := []
		for j in 4:
			var bp := _on_head(s * lerpf(0.15, 0.46, j / 3.0), 0.3 + sin(PI * j / 3.0) * 0.04, 0.004)
			brow.append(bp[0])
		var bw := float(_g("brow_size", 1.0))
		tube(brow, [0.007 * k * bw, 0.009 * k * bw, 0.009 * k * bw, 0.006 * k * bw], _bare(dark), 0.8, BROW_L if s > 0 else BROW_R, 6)
		rest[BROW_L if s > 0 else BROW_R] = (brow[1] + brow[2]) / 2.0
	# La bouche, d'un trait, sous le nez.
	var mc: Vector3 = _on_head(0.0, -0.42, 0.003)[0]
	var lip := _bare(_col("lip", skin.darkened(0.5)))
	var arc := []
	var frown := []
	var rr := []
	for j in 7:
		var a := lerpf(-1.0, 1.0, j / 6.0)
		arc.append(mc + Vector3(a * 0.05 * k, a * a * 0.016 * k, -absf(a) * 0.022 * k))
		frown.append(mc + Vector3(a * 0.044 * k, -a * a * 0.014 * k - 0.002, -absf(a) * 0.022 * k))
		rr.append(0.006 * k)
	tube(arc, rr, lip, 0.4, SMILE, 6)
	tube(frown, rr, lip, 0.4, FROWN, 6)
	ellipsoid(mc + Vector3(0, -0.012 * k, -0.004), Vector3(0.034, 0.026, 0.01) * k, _facing(Vector3(0, -0.3, 1)), _bare(MOUTH_IN), 0.5, MOUTH, 0.0, 10, 6)
	rest[SMILE] = mc
	rest[FROWN] = mc
	rest[MOUTH] = mc + Vector3(0, -0.004, 0)
	_hair()
	_face_extras()
	_hat()


## Les cheveux : une calotte posée en arrière du front, et la coupe qui fait la silhouette.
func _hair() -> void:
	var style: String = _g("hair", "court")
	var c := _col("hair_color", Color("#4a3426"))
	var hb := HEAD
	var cap := func(scale: Vector3, tilt: float, lift := 0.0) -> void:
		ellipsoid(head_c + Vector3(0, head_r.y * (0.12 + lift), -head_r.z * 0.1), head_r * scale, Basis(Vector3.RIGHT, -tilt), c, 0.9, hb, 0.12, 22, 12)
	match style:
		"court":
			cap.call(Vector3(1.06, 0.9, 1.08), 0.42)
		"raie":
			cap.call(Vector3(1.07, 0.92, 1.08), 0.38)
			ellipsoid(head_c + Vector3(head_r.x * 0.35, head_r.y * 0.82, head_r.z * 0.25), head_r * Vector3(0.6, 0.25, 0.55), Basis(Vector3.BACK, -0.3), c, 0.9, hb, 0.0, 14, 8)
		"houppe":
			# La houppe de Tintin, le cheveu sur la tête qui dépasse.
			cap.call(Vector3(1.05, 0.88, 1.07), 0.45)
			ellipsoid(head_c + Vector3(0.0, head_r.y * 1.02, head_r.z * 0.5), Vector3(0.05, 0.1, 0.04) * k, Basis(Vector3.RIGHT, 0.5), c, 0.9, hb, -0.8, 10, 8)
		"gomina":
			cap.call(Vector3(1.06, 0.92, 1.1), 0.3, 0.05)
		"degarni":
			cap.call(Vector3(1.06, 0.75, 1.08), 0.95, -0.1)
		"chauve":
			# Une couronne autour de l'arrière du crâne.
			for j in 9:
				var a := lerpf(1.25, TAU - 1.25, j / 8.0)
				var pp := _on_head(a, 0.05, 0.004)
				ellipsoid(pp[0], Vector3(0.045, 0.045, 0.03) * k, _facing(pp[1]), c, 0.95, hb, 0.0, 8, 6)
		"brushing":
			cap.call(Vector3(1.2, 1.0, 1.18), 0.3, 0.08)
			for s in [-1.0, 1.0]:
				ellipsoid(head_c + Vector3(s * head_r.x * 0.85, -head_r.y * 0.15, -head_r.z * 0.1), Vector3(0.07, 0.11, 0.1) * k, Basis(), c, 0.9, hb, 0.2, 12, 8)
		"carre":
			cap.call(Vector3(1.1, 0.95, 1.12), 0.25)
			lathe(head_c + Vector3(0, -head_r.y * 0.5, -head_r.z * 0.12), [[head_r.x * 1.12, 0.0], [head_r.x * 1.12, head_r.y * 0.9]], Basis(Vector3.UP, PI), c, 0.9, hb, 1.0, 20, 0.0, 4.2)
		"permanente":
			for j in 16:
				var pp := _on_head(lerpf(0.0, TAU, j / 16.0) + 0.2 * (j % 2), 0.55 + 0.35 * (j % 3) / 2.0, 0.0)
				if absf(angle_difference(lerpf(0.0, TAU, j / 16.0), 0.0)) < 0.7 and j % 3 != 2:
					continue
				ellipsoid(pp[0], Vector3(0.06, 0.055, 0.06) * k, _facing(pp[1]), c, 0.95, hb, 0.0, 10, 6)
			cap.call(Vector3(1.08, 0.92, 1.08), 0.4)
		"chignon":
			cap.call(Vector3(1.07, 0.92, 1.08), 0.3)
			ellipsoid(head_c + Vector3(0, head_r.y * 0.65, -head_r.z * 0.85), Vector3(0.075, 0.07, 0.07) * k, Basis(), c, 0.9, hb, 0.0, 12, 8)
		"queue":
			cap.call(Vector3(1.07, 0.92, 1.08), 0.32)
			var b0 := head_c + Vector3(0, head_r.y * 0.3, -head_r.z * 0.95)
			tube([b0, b0 + Vector3(0, -0.04, -0.02) * k * 2.0, b0 + Vector3(0, -0.12, -0.01) * k * 2.0], [0.03 * k, 0.04 * k, 0.02 * k], c, 0.9, hb, 8)
		"frange":
			cap.call(Vector3(1.1, 0.95, 1.1), 0.12)
		"":
			pass


func _muzzle(sp: String, fur: Color, fur2: Color, acc: Color, pink: Color) -> void:
	var hb := HEAD
	var m := _on_head(0.0, -0.3, -0.02)
	var nose_col := _col("nose", DARK)
	var tip: Vector3
	match sp:
		"renard", "blaireau", "herisson", "souris":
			var length: float = {"renard": 0.1, "blaireau": 0.085, "herisson": 0.09, "souris": 0.07}[sp] * k
			var mb := _facing(m[1]) * Basis(Vector3.RIGHT, PI / 2)
			var col := fur2 if sp != "souris" else fur
			ellipsoid(m[0] + m[1] * length * 0.35, Vector3(0.062, length, 0.05) * k, mb, col, 0.85, hb, -0.55, 14, 10)
			tip = m[0] + m[1] * length * 1.3
			ellipsoid(tip, Vector3(0.024, 0.019, 0.018) * k, _facing(m[1]), pink if sp == "souris" else nose_col, 0.25, hb, 0.0, 10, 6)
		"sanglier":
			var mb := _facing(m[1]) * Basis(Vector3.RIGHT, PI / 2)
			lathe(m[0], [[0.07 * k, -0.01], [0.072 * k, 0.05 * k], [0.068 * k, 0.085 * k], [0.0, 0.088 * k]], mb, band(fur2, 0.66, pink.darkened(0.15)), 0.7, hb, 0.8, 16)
			tip = m[0] + m[1] * 0.09 * k
			for s in [-1.0, 1.0]:
				ellipsoid(tip + mb * Vector3(s * 0.022, 0, 0) * k, Vector3(0.01, 0.003, 0.014) * k, mb, DARK, 0.4, hb, 0.0, 8, 4)
				var tusk: Vector3 = m[0] + m[1] * 0.035 * k + Vector3(s * 0.055 * k, -0.015, 0)
				lathe(tusk, [[0.011 * k, 0.0], [0.007 * k, 0.025 * k], [0.0, 0.045 * k]], Basis(Vector3.BACK, s * 0.4), _col("tusk", WHITE), 0.4, hb, 1.0, 8)
		_:
			# Museau rond : ours, chat, lapin, castor, chien.
			var size: Vector3 = {"ours": Vector3(0.085, 0.06, 0.06), "chat": Vector3(0.07, 0.045, 0.045), "lapin": Vector3(0.06, 0.045, 0.045),
				"castor": Vector3(0.085, 0.06, 0.06), "chien": Vector3(0.08, 0.058, 0.065)}.get(sp, Vector3(0.07, 0.05, 0.05)) * k
			ellipsoid(m[0], size, _facing(m[1]), fur2, 0.85, hb, 0.0, 14, 10)
			tip = m[0] + m[1] * size.z * 0.95 + Vector3(0, size.y * 0.35, 0)
			var nose_size := Vector3(0.026, 0.018, 0.016) if sp in ["ours", "chien", "castor"] else Vector3(0.016, 0.011, 0.01)
			ellipsoid(tip, nose_size * k, _facing(m[1]), pink if sp in ["lapin", "chat"] else nose_col, 0.25, hb, 0.0, 10, 6)
	# La bouche : un sourire, une moue (cachée), et une bouche ouverte (cachée), chacun sur son os.
	var mouth_c := tip + Vector3(0, -0.032 * k, -0.004)
	var lip := _col("lip", DARK)
	var arc := []
	var arc_r := []
	var frown := []
	for j in 7:
		var a := lerpf(-1.0, 1.0, j / 6.0)
		arc.append(mouth_c + Vector3(a * 0.026 * k, (a * a) * 0.012 * k - 0.004, -absf(a) * 0.01))
		frown.append(mouth_c + Vector3(a * 0.022 * k, -(a * a) * 0.01 * k - 0.006, -absf(a) * 0.01))
		arc_r.append(0.0042 * k)
	tube(arc, arc_r, lip, 0.4, SMILE, 6)
	tube(frown, arc_r, lip, 0.4, FROWN, 6)
	ellipsoid(mouth_c + Vector3(0, -0.012 * k, -0.006), Vector3(0.022, 0.018, 0.01) * k, _facing(Vector3(0, -0.2, 1)), MOUTH_IN, 0.5, MOUTH, 0.0, 10, 6)
	rest[SMILE] = mouth_c
	rest[FROWN] = mouth_c
	rest[MOUTH] = mouth_c + Vector3(0, -0.006, 0)
	if sp in ["castor", "lapin"]:
		var big := sp == "castor"
		for s in [-1.0, 1.0]:
			box(mouth_c + Vector3(s * 0.0085 * k, -0.017 * k, 0.003), Vector3(0.015, 0.024 if big else 0.016, 0.006) * k, Basis(), WHITE, 0.3, HEAD)
	if sp in ["chat", "souris"]:
		for s in [-1.0, 1.0]:
			for j in 3:
				var o := tip + Vector3(s * 0.03 * k, -0.012 * k - j * 0.008 * k, -0.01)
				tube([o, o + Vector3(s * 0.07 * k, 0.012 - j * 0.012, -0.012)], [0.0016, 0.001], DARK.lightened(0.15), 0.5, HEAD, 4, false)


func _eyes() -> void:
	var size := float(_g("eyes", 1.0))
	for s in [-1.0, 1.0]:
		var bone := EYE_L if s > 0 else EYE_R
		var e := _on_head(s * 0.36, 0.06, -0.008)
		var nb := _facing(e[1])
		var white_r := Vector3(0.052, 0.064, 0.026) * k * size
		ellipsoid(e[0], white_r, nb, WHITE, 0.12, bone, 0.0, 14, 10)
		# La pupille regarde un peu vers le nez : un air attendri.
		var pd: Vector3 = (e[1] + Vector3(-s * 0.18, -0.06, 0)).normalized()
		ellipsoid(e[0] + pd * white_r.z * 0.9, Vector3(0.03, 0.04, 0.013) * k * size, _facing(pd), DARK, 0.08, bone, 0.0, 12, 8)
		ellipsoid(e[0] + pd * white_r.z * 1.3 + nb * Vector3(0.012, 0.016, 0) * k, Vector3(0.0095, 0.0095, 0.004) * k * size, _facing(pd), WHITE, 0.1, bone, 0.0, 8, 4, 1.0)
		rest[bone] = e[0]
		# Le sourcil, sur son os pour l'expression.
		var brow := []
		for j in 4:
			var bp := _on_head(s * lerpf(0.2, 0.5, j / 3.0), 0.33 + sin(PI * j / 3.0) * 0.03, 0.004)
			brow.append(bp[0])
		var brow_col := _col("brow", _col("fur").darkened(0.55))
		tube(brow, [0.007 * k, 0.008 * k, 0.008 * k, 0.006 * k], brow_col, 0.8, BROW_L if s > 0 else BROW_R, 6)
		rest[BROW_L if s > 0 else BROW_R] = (brow[1] + brow[2]) / 2.0


func _ears(sp: String, fur: Color, fur2: Color, acc: Color, pink: Color) -> void:
	var inner := pink if sp in ["lapin", "souris", "chat", "ours", "castor"] else fur2
	var big := float(_g("ears", 1.0))
	for s in [-1.0, 1.0]:
		var bone := EAR_L if s > 0 else EAR_R
		match sp:
			"renard", "chat":
				var fox := sp == "renard"
				var e := _on_head(s * 0.55, 0.78, -0.03)
				var b := Basis(Vector3.BACK, -s * 0.32) * Basis(Vector3.UP, s * 0.25)
				var r := Vector3(0.058, 0.09 if fox else 0.07, 0.022) * k * big
				ellipsoid(e[0] + b.y * r.y * 0.7, r, b, band(fur, 0.72, acc) if fox else fur, 0.85, bone, -0.92, 12, 10)
				ellipsoid(e[0] + b.y * r.y * 0.65 + b.z * 0.012, r * Vector3(0.6, 0.72, 0.5), b, inner, 0.9, bone, -0.92, 10, 8)
				rest[bone] = e[0]
			"sanglier":
				var e := _on_head(s * 0.75, 0.58, -0.02)
				var b := Basis(Vector3.BACK, -s * 0.9) * Basis(Vector3.RIGHT, -0.3)
				var r := Vector3(0.04, 0.06, 0.016) * k * big
				ellipsoid(e[0] + b.y * r.y * 0.7, r, b, fur, 0.9, bone, -0.85, 10, 8)
				rest[bone] = e[0]
			"lapin":
				var e := _on_head(s * 0.28, 0.95, -0.02)
				var b := Basis(Vector3.BACK, -s * 0.16) * Basis(Vector3.RIGHT, -0.12)
				var r := Vector3(0.04, 0.14, 0.022) * k * big
				ellipsoid(e[0] + b.y * r.y * 0.9, r, b, fur, 0.85, {"t": [[0.3, HEAD], [0.45, bone]]}, -0.15, 12, 12)
				ellipsoid(e[0] + b.y * r.y * 0.9 + b.z * 0.012, r * Vector3(0.55, 0.8, 0.5), b, inner, 0.9, {"t": [[0.3, HEAD], [0.45, bone]]}, -0.15, 10, 10)
				rest[bone] = e[0]
			"chien":
				var e := _on_head(s * 0.82, 0.5, -0.01)
				var b := Basis(Vector3.BACK, s * 0.25) * Basis(Vector3.RIGHT, 0.1)
				var r := Vector3(0.05, 0.11, 0.022) * k * big
				ellipsoid(e[0] + Vector3(s * 0.02, -r.y * 0.7, 0), r, b, acc, 0.85, bone, 0.25, 12, 10)
				rest[bone] = e[0]
			"souris":
				var e := _on_head(s * 0.62, 0.7, -0.02)
				var b := _facing(Vector3(s * 0.25, 0.1, 1.0))
				var r := Vector3(0.085, 0.085, 0.02) * k * big
				ellipsoid(e[0] + Vector3(s * r.x * 0.5, r.y * 0.55, 0), r, b, fur, 0.85, bone, 0.0, 14, 8)
				ellipsoid(e[0] + Vector3(s * r.x * 0.5, r.y * 0.55, 0.012), r * Vector3(0.7, 0.7, 0.5), b, inner, 0.9, bone, 0.0, 12, 8)
				rest[bone] = e[0]
			_:
				# Oreilles rondes : ours, castor, blaireau, hérisson.
				var e := _on_head(s * 0.62, 0.75, -0.015)
				var size: float = {"ours": 0.05, "castor": 0.032, "blaireau": 0.034, "herisson": 0.032}.get(sp, 0.04) * k * big
				var b := _facing(Vector3(s * 0.2, 0.15, 1.0))
				ellipsoid(e[0] + Vector3(s * size * 0.3, size * 0.55, 0), Vector3(size, size, size * 0.45), b,
					fur2 if sp == "blaireau" else fur, 0.85, bone, 0.0, 12, 8)
				if sp == "ours":
					ellipsoid(e[0] + Vector3(s * size * 0.3, size * 0.55, size * 0.25), Vector3(size, size, size * 0.4) * 0.6, b, inner.lerp(fur, 0.3), 0.9, bone, 0.0, 10, 6)
				rest[bone] = e[0]


func _spikes(acc: Color, tipc: Color) -> void:
	var cols := band(acc, 0.62, tipc)
	for row in 4:
		var pitch := lerpf(1.3, -0.15, row / 3.0)
		var n := 5 + row * 2
		for j in n:
			var yaw := lerpf(1.25, TAU - 1.25, (j + 0.5 * (row % 2)) / float(n))
			var p := _on_head(yaw, pitch, -0.015)
			var b := _facing(p[1]) * Basis(Vector3.RIGHT, PI / 2) * Basis(Vector3.RIGHT, -0.5)
			lathe(p[0], [[0.024 * k, 0.0], [0.015 * k, 0.04 * k], [0.0, 0.075 * k]], b, cols, 0.8, HEAD, 1.0, 6)
	# Et le dos.
	for row in 3:
		for j in 5:
			var a := lerpf(-1.1, 1.1, j / 4.0) + (0.2 if row % 2 else 0.0)
			var y := lerpf(shoulder_y, hip_y + 0.04, row / 2.0)
			var p := Vector3(sin(a) * 0.07 * w * belly, y, -cos(a) * 0.065 * w * belly)
			var nrm := Vector3(sin(a), 0.25, -cos(a)).normalized()
			var b := _facing(nrm) * Basis(Vector3.RIGHT, PI / 2) * Basis(Vector3.RIGHT, -0.6)
			lathe(p, [[0.02, 0.0], [0.012, 0.03], [0.0, 0.065]], b, cols, 0.8, CHEST if row == 0 else SPINE, 1.0, 6)


func _face_extras() -> void:
	var face: Array = _g("face", [])
	var hb := HEAD
	var gold := _col("frame", GOLD)
	for f in face:
		match f:
			"lunettes", "demi_lune", "monocle":
				for s in [-1.0, 1.0]:
					if f == "monocle" and s < 0:
						continue
					var e := _on_head(s * 0.36, 0.06 if f != "demi_lune" else -0.02, 0.022)
					var nb := _facing(e[1])
					var ring := []
					var rr := []
					var n := 22
					var r := 0.052 * k if f != "demi_lune" else 0.044 * k
					for j in n + 1:
						var a := TAU * j / n if f != "demi_lune" else lerpf(PI * 1.05, TAU * 0.98, float(j) / n)
						ring.append(e[0] + nb * Vector3(cos(a) * r, sin(a) * r * (1.12 if f != "demi_lune" else 0.8), 0))
						rr.append(0.0042 * k)
					tube(ring, rr, gold if f != "lunettes" else _col("frame", DARK), 0.3, hb, 5, f == "demi_lune")
				if f != "monocle":
					var l := _on_head(0.1, 0.05, 0.02)
					var r2 := _on_head(-0.1, 0.05, 0.02)
					tube([l[0], (l[0] + r2[0]) / 2.0 + Vector3(0, 0.006, 0.01), r2[0]], [0.004, 0.004, 0.004], gold if f == "demi_lune" else _col("frame", DARK), 0.3, hb, 5)
			"moustache", "barbe", "favoris", "bouc" when _human():
				_human_hair_face(f)
			"moustache":
				var m := _on_head(0.0, -0.3, -0.02)
				var tip: Vector3 = m[0] + m[1] * (0.11 if _species() == "renard" else 0.06) * k
				for s in [-1.0, 1.0]:
					tube([tip + Vector3(0, -0.012, 0.004), tip + Vector3(s * 0.03, -0.02, -0.004) * k, tip + Vector3(s * 0.06, -0.008, -0.02) * k],
						[0.009 * k, 0.011 * k, 0.004 * k], _col("moustache", _col("fur").darkened(0.5)), 0.85, hb, 8)
			"cils" when not _human():
				for s in [-1.0, 1.0]:
					for j in 3:
						var e := _on_head(s * (0.5 + j * 0.05), 0.2 - j * 0.07, 0.0)
						tube([e[0], e[0] + (e[1] + Vector3(s * 0.8, 0.6, 0)).normalized() * 0.022 * k], [0.004, 0.002], DARK, 0.5, EYE_L if s > 0 else EYE_R, 4, false)


## Moustache, barbe, favoris et bouc d'un humain, de la couleur de ses cheveux (ou « moustache »).
func _human_hair_face(f: String) -> void:
	var c := _col("moustache", _col("hair_color", Color("#4a3426")))
	var hb := HEAD
	match f:
		"moustache":
			var m: Vector3 = _on_head(0.0, -0.27, 0.006)[0]
			for s in [-1.0, 1.0]:
				tube([m + Vector3(0, 0.002, 0.004) * k, m + Vector3(s * 0.04, -0.004, -0.004) * k, m + Vector3(s * 0.075, -0.018, -0.024) * k],
					[0.016 * k, 0.017 * k, 0.007 * k], c, 0.9, hb, 8)
		"barbe":
			ellipsoid(head_c + Vector3(0, -head_r.y * 0.48, head_r.z * 0.22), head_r * Vector3(0.86, 0.55, 0.86), Basis(), c, 0.95, hb, 0.25, 18, 10)
		"favoris":
			for s in [-1.0, 1.0]:
				var e := _on_head(s * 1.25, -0.25, 0.003)
				ellipsoid(e[0], Vector3(0.03, 0.06, 0.03) * k, _facing(e[1]), c, 0.9, hb, 0.0, 8, 6)
		"bouc":
			ellipsoid(_on_head(0.0, -0.75, 0.004)[0], Vector3(0.04, 0.04, 0.035) * k, Basis(), c, 0.9, hb, -0.3, 10, 6)


func _hat() -> void:
	var hat: String = _g("hat", "")
	if hat == "":
		return
	var c := _col("hat_color", DARK)
	var band_c := _col("hat_band", c.lightened(0.3))
	var top := head_c + Vector3(0, head_r.y, 0)
	var hb := HEAD
	match hat:
		"beret":
			var b := Basis(Vector3.BACK, -0.2) * Basis(Vector3.RIGHT, -0.12)
			ellipsoid(top + Vector3(0.012, -0.022, -0.012) * k, Vector3(0.17, 0.045, 0.16) * k, b, c, 0.9, hb, 0.2, 18, 8)
			tube([top + b * Vector3(0, 0.03, 0) * k, top + b * Vector3(0.004, 0.05, 0) * k], [0.006, 0.004], c, 0.9, hb, 5)
		"casquette":
			var b := Basis(Vector3.RIGHT, -0.12)
			ellipsoid(top + Vector3(0, -0.035, -0.008) * k, Vector3(0.165, 0.075, 0.16) * k, b, c, 0.9, hb, 0.25, 18, 8)
			ellipsoid(top + Vector3(0, -0.06, 0.13) * k, Vector3(0.11, 0.012, 0.075) * k, Basis(Vector3.RIGHT, 0.25), c.darkened(0.15), 0.85, hb, 0.0, 14, 6)
		"haut_de_forme":
			var b := Basis(Vector3.BACK, 0.06)
			var h := float(_g("hat_h", 1.0))
			lathe(top + Vector3(0, -0.035, 0) * k, [[0.0, 0.0], [0.19 * k, 0.0], [0.2 * k, 0.012], [0.11 * k, 0.016], [0.105 * k, 0.04 * k], [0.108 * k, 0.17 * k * h], [0.11 * k, 0.18 * k * h], [0.0, 0.185 * k * h]], b,
				[[0.0, c], [0.42, band_c], [0.6, c]], 0.45, hb, 0.92, 22)
		"feutre", "chasse":
			var b := Basis(Vector3.BACK, -0.08) * Basis(Vector3.RIGHT, -0.08)
			var brim := 0.21 if hat == "feutre" else 0.17
			lathe(top + Vector3(0, -0.04, 0) * k, [[0.0, 0.0], [brim * k, 0.012], [brim * k * 1.02, 0.022], [0.115 * k, 0.02], [0.112 * k, 0.05 * k], [0.1 * k, 0.1 * k], [0.05 * k, 0.11 * k], [0.0, 0.1 * k]], b,
				[[0.0, c], [0.42, band_c], [0.6, c]], 0.75, hb, 0.9, 22)
			if hat == "chasse":
				var f := top + b * Vector3(0.1, 0.04, -0.03) * k
				ellipsoid(f + Vector3(0.0, 0.05, -0.02) * k, Vector3(0.012, 0.06, 0.006) * k, Basis(Vector3.RIGHT, -0.5) * Basis(Vector3.BACK, -0.3), _col("feather", Color(0.75, 0.25, 0.2)), 0.8, hb, -0.6, 8, 8)
		"canotier":
			lathe(top + Vector3(0, -0.035, 0) * k, [[0.0, 0.0], [0.2 * k, 0.0], [0.205 * k, 0.012], [0.115 * k, 0.014], [0.112 * k, 0.07 * k], [0.0, 0.072 * k]], Basis(Vector3.BACK, -0.08),
				[[0.0, c], [0.45, band_c], [0.8, c]], 0.85, hb, 0.92, 22)
		"calot":
			var b := Basis(Vector3.BACK, -0.35)
			lathe(top + Vector3(0.05, -0.02, 0.01) * k, [[0.0, 0.0], [0.075 * k, 0.0], [0.078 * k, 0.05 * k], [0.0, 0.052 * k]], b,
				[[0.0, c], [0.25, band_c], [0.55, c]], 0.6, hb, 1.0, 16)
		"cloche":
			var b := Basis(Vector3.RIGHT, -0.15)
			ellipsoid(top + Vector3(0, -0.06, -0.01) * k, Vector3(0.18, 0.11, 0.17) * k, b, [[0.0, c], [0.42, band_c], [0.52, c]], 0.85, hb, 0.1, 20, 12)
			lathe(top + Vector3(0, -0.11, 0.0) * k, [[0.17 * k, 0.0], [0.2 * k, -0.01], [0.17 * k, 0.01]], b, c, 0.85, hb, 0.95, 20)
		"visiere":
			lathe(top + Vector3(0, -0.075, 0) * k, [[0.172 * k, 0.0], [0.175 * k, 0.02], [0.17 * k, 0.03]], Basis(Vector3.RIGHT, -0.15), band_c, 0.6, hb, 0.9, 20)
			ellipsoid(top + Vector3(0, -0.06, 0.15) * k, Vector3(0.13, 0.01, 0.07) * k, Basis(Vector3.RIGHT, 0.45), c, 0.4, hb, 0.0, 14, 6)
		"bonnet":
			ellipsoid(top + Vector3(0.02, -0.02, -0.03) * k, Vector3(0.17, 0.1, 0.165) * k, Basis(Vector3.BACK, -0.25) * Basis(Vector3.RIGHT, -0.3), c, 0.95, hb, -0.2, 18, 10)
		"toque":
			lathe(top + Vector3(0, -0.05, 0) * k, [[0.15 * k, 0.0], [0.15 * k, 0.05 * k], [0.19 * k, 0.12 * k], [0.18 * k, 0.17 * k], [0.0, 0.19 * k]], Basis(), c, 0.95, hb, 0.95, 20)
		"chignon":
			ellipsoid(top + Vector3(0, 0.0, -0.06) * k, Vector3(0.075, 0.07, 0.07) * k, Basis(), c, 0.8, hb, 0.0, 14, 10)
			lathe(top + Vector3(0, -0.045, -0.05) * k, [[0.05 * k, 0.0], [0.055 * k, 0.012], [0.05 * k, 0.024]], Basis(Vector3.RIGHT, -0.6), band_c, 0.5, hb, 1.0, 14)
		"noeud_cheveux":
			var p: Vector3 = _on_head(0.45, 0.95, 0.0)[0]
			for s in [-1.0, 1.0]:
				ellipsoid(p + Vector3(s * 0.035, 0, 0) * k, Vector3(0.04, 0.028, 0.014) * k, Basis(Vector3.BACK, s * 0.4 + 0.3), c, 0.6, hb, -0.5 * s, 10, 6)
			ellipsoid(p, Vector3(0.015, 0.015, 0.015) * k, Basis(), c.darkened(0.2), 0.6, hb, 0.0, 8, 6)
		"fleur":
			var p := _on_head(0.62, 0.62, 0.0)
			var nb := _facing(p[1])
			for j in 5:
				var a := TAU * j / 5.0
				ellipsoid(p[0] + nb * Vector3(cos(a), sin(a), 0) * 0.026 * k, Vector3(0.022, 0.014, 0.008) * k, nb * Basis(Vector3.BACK, a), c, 0.6, hb, 0.0, 8, 4)
			ellipsoid(p[0] + p[1] * 0.006, Vector3(0.013, 0.013, 0.008) * k, nb, band_c, 0.5, hb, 0.0, 8, 4)
		"fichu":
			ellipsoid(head_c + Vector3(0, 0.035, -0.012) * k, head_r * Vector3(1.04, 0.86, 1.04), Basis(Vector3.RIGHT, -0.25), c, 0.9, hb, 0.15, 22, 12)
			var kn := head_c + Vector3(0, -head_r.y * 0.62, head_r.z * 0.55)
			ellipsoid(kn, Vector3(0.025, 0.02, 0.016) * k, Basis(), c.darkened(0.12), 0.9, hb, 0.0, 8, 6)


# --- Bras, jambes, mains, chaussures -------------------------------------------------------

func _limbs() -> void:
	var fur := _col("fur")
	var sleeve := _sleeve_color()
	var sleeves: String = _g("sleeves", "longues" if _g("top", "nu") != "nu" else "aucune")
	var cuff := _col("cuff", sleeve)
	var hand := _col("gloves", _col("hands", fur))
	var legs: String = _g("legs", "nu")
	var lc := _legs_color()
	var shoe := _col("shoes", DARK.lightened(0.05))
	var thin := 0.74 if _human() else 1.0
	var ra := 0.026 * sqrt(w) * lerpf(1.0, belly, 0.25) * thin
	var rl := 0.031 * sqrt(w) * lerpf(1.0, belly, 0.35) * thin
	for s in [1.0, -1.0]:
		var arm := ARM_L if s > 0 else ARM_R
		var fore := FOREARM_L if s > 0 else FOREARM_R
		var hnd := HAND_L if s > 0 else HAND_R
		var a0 := rest[arm] + Vector3(-s * 0.012, 0.004, 0)
		var a1 := rest[fore]
		var a2 := rest[hnd] + Vector3(0, 0.012, -0.004)
		var cols: Variant = sleeve
		match sleeves:
			"aucune":
				cols = fur
			"courtes":
				cols = band(sleeve, 0.42, fur)
			_:
				cols = [[0.0, sleeve], [0.86, cuff]] if cuff != sleeve else sleeve
		tube([a0, a0.lerp(a1, 0.5), a1, a1.lerp(a2, 0.5), a2], [ra, ra * 0.96, ra * 0.9, ra * 0.86, ra * 0.8], cols, 0.8,
			{"t": [[0.38, arm], [0.56, fore]]}, 10)
		# Une moufle et un pouce.
		var hc := rest[hnd] + Vector3(s * 0.002, -0.006, 0.004)
		ellipsoid(hc, Vector3(0.03, 0.033, 0.025) * sqrt(w) * thin, Basis(Vector3.BACK, s * 0.1), hand, 0.8, hnd, -0.1, 12, 8)
		ellipsoid(hc + Vector3(-s * 0.012, 0.004, 0.02) * thin, Vector3(0.012, 0.016, 0.012) * thin, Basis(Vector3.RIGHT, -0.4), hand, 0.8, hnd, 0.0, 8, 6)
		# La jambe.
		var th := THIGH_L if s > 0 else THIGH_R
		var sh := SHIN_L if s > 0 else SHIN_R
		var ft := FOOT_L if s > 0 else FOOT_R
		var l0 := rest[th] + Vector3(0, 0.03, 0)
		var l1 := rest[sh]
		var l2 := rest[ft] + Vector3(0, 0.005, 0)
		var lcol: Variant = lc
		if legs == "short":
			lcol = band(lc, 0.38, fur)
		tube([l0, l0.lerp(l1, 0.5), l1, l1.lerp(l2, 0.5), l2], [rl, rl * 0.95, rl * 0.86, rl * 0.8, rl * 0.76], lcol, 0.8,
			{"t": [[0.36, th], [0.54, sh]]}, 10)
		ellipsoid(Vector3(rest[ft].x, 0.022, 0.02 if _human() else 0.016), Vector3(0.036, 0.026, 0.054) * sqrt(w) * Vector3(0.78, 0.8, 1.08) if _human() else Vector3(0.036, 0.026, 0.054) * sqrt(w), Basis(), shoe, 0.35, ft, -0.15, 12, 8)
		rest[ft] = Vector3(rest[ft].x, 0.03, 0)


func _sleeve_color() -> Color:
	match _g("top", "nu"):
		"nu", "robe_bustier":
			return _col("fur")
		"gilet", "tablier":
			return _col("top2", WHITE)
		_:
			return _col("sleeve_color", _top_color())


# --- Les vêtements par-dessus --------------------------------------------------------------

func _outfit() -> void:
	var style: String = _g("top", "nu")
	var top := _top_color()
	var shirt := _col("top2", WHITE)
	var fz := 0.07 * w * belly * 0.84
	var chestb := {"y": [[hip_y, HIPS], [hip_y + torso_h * 0.45, SPINE], [shoulder_y, CHEST]]}
	# Le plastron de chemise et les revers pour les vestes ouvertes.
	if style in ["veste", "smoking", "queue_de_pie", "gilet", "trench"]:
		var pc := Vector3(0, shoulder_y - 0.025, 0.056 * w * lerpf(1.0, belly, 0.5))
		ellipsoid(pc, Vector3(0.03 * w, 0.05, 0.014), Basis(Vector3.RIGHT, -0.18), shirt, 0.7, CHEST, 0.55, 12, 8)
		if style != "gilet":
			for s in [-1.0, 1.0]:
				var lap := _col("lapel", top.lightened(0.12) if style != "smoking" else top.lightened(0.18))
				ellipsoid(pc + Vector3(s * 0.026 * w, 0.002, -0.002), Vector3(0.016, 0.05, 0.008), Basis(Vector3.BACK, s * 0.32) * Basis(Vector3.RIGHT, -0.2), lap, 0.45 if style == "smoking" else 0.75, CHEST, 0.5, 8, 6)
		var btn := _col("buttons", top.lightened(0.3))
		for j in (2 if style != "gilet" else 3):
			var y := hip_y + torso_h * (0.4 - j * 0.14) + (0.05 if style == "gilet" else 0.0)
			ellipsoid(Vector3(0, y, _front_z(y) + 0.002), Vector3(0.008, 0.008, 0.005), Basis(), btn, 0.3, chestb, 0.0, 6, 4)
	# Le bas de veste qui tombe sur les hanches, et les basques de la queue-de-pie.
	if style in ["veste", "smoking", "queue_de_pie", "trench"]:
		var r0 := _torso_r(hip_y + 0.035) * 1.04
		var hem_y := hip_y - (0.035 if style != "trench" else leg * 0.62)
		var flare := 1.08 if style != "trench" else 1.3
		var r1 := maxf(r0, _torso_r(hip_y) * 1.05)
		lathe(Vector3.ZERO, [[r0, hip_y + 0.035], [r1, hip_y + 0.0], [r1 * flare, hem_y], [r1 * flare * 0.97, hem_y - 0.004]], Basis(), top, 0.8, HIPS, 0.86, 20)
		if style == "queue_de_pie":
			for s in [-1.0, 1.0]:
				ellipsoid(Vector3(s * 0.03 * w, hip_y - leg * 0.35, -0.062 * w * belly), Vector3(0.03, leg * 0.42, 0.01), Basis(Vector3.BACK, s * 0.08), top, 0.8, HIPS, -0.5, 10, 8)
		if style == "trench":
			lathe(Vector3.ZERO, [[0.045, neck_y - 0.04], [0.06, neck_y - 0.0], [0.07, neck_y + 0.035]], Basis(), top, 0.8, CHEST, 0.9, 18)
	if style in ["robe", "tablier_robe"] or _g("skirt", false):
		var skirt := _col("skirt_color", top)
		var r0 := _torso_r(hip_y + 0.03) * 1.05
		var r1 := maxf(r0, _torso_r(hip_y - 0.01) * 1.08)
		var length := float(_g("skirt_len", 0.62))
		var hem := hip_y - leg * length
		var rh := r1 * (1.12 + length * 0.4)
		_skirt = [[rh * 0.97, hem - 0.004], [rh, hem], [r1, hip_y - 0.01], [r0, hip_y + 0.03]]
		lathe(Vector3.ZERO, [[r0 * 0.6, hip_y + 0.035], [r0, hip_y + 0.03], [r1, hip_y - 0.01], [rh, hem], [rh * 0.97, hem - 0.004]], Basis(), skirt, 0.8, HIPS, 0.9, 22)
	if _g("apron", false):
		# Le tablier épouse la jupe (ou le ventre) : une part de la même forme, un peu en avant.
		var ac := _col("apron_color", WHITE)
		var top_y := hip_y + 0.03
		var bot_y := hip_y - leg * (0.55 if not _skirt.is_empty() else 0.62)
		var prof := []
		for j in 7:
			var y := lerpf(top_y, bot_y, j / 6.0)
			var r := _prof_r(_skirt, y) * 0.9 if not _skirt.is_empty() else _torso_r(maxf(y, hip_y - 0.03)) * 0.84
			prof.append([r + 0.006, y])
		lathe(Vector3.ZERO, prof, Basis(), ac, 0.9, HIPS, 1.0, 10, 0.0, 1.5)
		if _g("apron_bib", false):
			var bib := []
			for j in 5:
				var y := lerpf(top_y, shoulder_y - 0.02, j / 4.0)
				bib.append([_torso_r(y) * 0.84 + 0.005, y])
			lathe(Vector3.ZERO, bib, Basis(), ac, 0.9, {"y": [[hip_y, HIPS], [hip_y + torso_h * 0.45, SPINE], [shoulder_y, CHEST]]}, 1.0, 8, 0.0, 1.0)
	if _g("badge", false):
		var by := shoulder_y - 0.03
		box(Vector3(0.042 * w, by, _front_z(by) + 0.003), Vector3(0.022, 0.009, 0.004), Basis(Vector3.UP, 0.4), GOLD, 0.25, CHEST)
	if _g("watch_chain", false):
		var y := hip_y + torso_h * 0.3
		var z := _front_z(y)
		var pts := []
		for j in 7:
			var a := lerpf(-1.0, 1.0, j / 6.0)
			pts.append(Vector3(a * 0.05 * w, y - (1.0 - a * a) * 0.018, z + 0.004 - absf(a) * 0.012))
		tube(pts, [0.0025, 0.0025, 0.0025, 0.0025, 0.0025, 0.0025, 0.0025], GOLD, 0.25, SPINE, 4)
	_neck()


## Le rayon du torse à une hauteur donnée, d'après son profil.
func _torso_r(y: float) -> float:
	return _prof_r(_prof, y)


static func _prof_r(prof: Array, y: float) -> float:
	if prof.is_empty():
		return 0.08
	if y <= prof[0][1]:
		return prof[0][0]
	for j in range(1, prof.size()):
		if y <= prof[j][1]:
			return lerpf(prof[j - 1][0], prof[j][0], inverse_lerp(prof[j - 1][1], prof[j][1], y))
	return prof[-1][0]


## La surface avant du torse à une hauteur donnée (pour poser boutons et bavettes).
func _front_z(y: float) -> float:
	return _torso_r(y) * 0.84


func _neck() -> void:
	var n: String = _g("neck", "")
	var c := _col("neck_color", DARK)
	var y := neck_y - 0.018
	var z := 0.048 * w + 0.01
	match n:
		"noeud":
			for s in [-1.0, 1.0]:
				ellipsoid(Vector3(s * 0.02, y, z), Vector3(0.024, 0.016, 0.01), Basis(Vector3.BACK, s * 0.15), c, 0.5, CHEST, 0.0, 10, 6, 0.0)
			ellipsoid(Vector3(0, y, z + 0.004), Vector3(0.009, 0.01, 0.008), Basis(), c.darkened(0.15), 0.5, CHEST, 0.0, 8, 6)
		"cravate":
			ellipsoid(Vector3(0, y, z), Vector3(0.012, 0.012, 0.009), Basis(), c, 0.5, CHEST, 0.0, 8, 6)
			ellipsoid(Vector3(0, y - 0.05, _front_z(y - 0.05) + 0.006), Vector3(0.014, 0.045, 0.006), Basis(Vector3.RIGHT, -0.15), c, 0.5,
				{"y": [[hip_y + torso_h * 0.45, SPINE], [shoulder_y, CHEST]]}, -0.3, 8, 8)
		"collier":
			var pearls := []
			for j in 11:
				var a := lerpf(-1.3, 1.3, j / 10.0)
				pearls.append(Vector3(sin(a) * 0.05 * w, y + 0.004 - cos(a) * 0.012, cos(a) * 0.046 * w + 0.004))
			for p in pearls:
				ellipsoid(p, Vector3(0.008, 0.008, 0.008), Basis(), _col("neck_color", WHITE), 0.15, CHEST, 0.0, 6, 4)
		"metre":
			# Le mètre ruban de la couturière, passé autour du cou et qui pend sur le devant.
			var tape := _col("neck_color", Color("#e8c440"))
			lathe(Vector3(0, neck_y - 0.026, 0), [[0.047 * w, 0.0], [0.048 * w, 0.006]], Basis(), tape, 0.6, CHEST, 0.95, 16)
			for s in [-1.0, 1.0]:
				var x0: float = s * 0.036 * w
				var pts := []
				for j in 5:
					var yy := y - j * 0.024 - 0.004
					pts.append(Vector3(x0 + s * j * 0.002, yy, _front_z(yy) + 0.006))
				tube(pts, [0.0065, 0.0065, 0.0065, 0.0065, 0.0065], tape, 0.6, {"y": [[hip_y + torso_h * 0.5, SPINE], [shoulder_y, CHEST]]}, 4)
		"foulard":
			lathe(Vector3(0, neck_y - 0.03, 0), [[0.045 * w, 0.0], [0.05 * w, 0.015], [0.042 * w, 0.03]], Basis(), c, 0.85, CHEST, 0.95, 16)
			ellipsoid(Vector3(0, y - 0.022, z - 0.002), Vector3(0.026, 0.03, 0.01), Basis(), c, 0.85, CHEST, 0.6, 10, 6)


# --- Les accessoires en main ---------------------------------------------------------------

func _props() -> void:
	for side in ["prop_r", "prop_l"]:
		var p: String = _g(side, "")
		if p == "":
			continue
		var s := -1.0 if side == "prop_r" else 1.0
		var hb := HAND_R if s < 0 else HAND_L
		var h := rest[hb] + Vector3(0, -0.012, 0.02)
		match p:
			"gobelet":
				lathe(h + Vector3(-s * 0.012, -0.03, 0.02), [[0.0, 0.0], [0.024, 0.0], [0.028, 0.06], [0.026, 0.062], [0.0, 0.055]], Basis(), Color(0.42, 0.22, 0.12), 0.6, hb, 1.0, 12)
			"carnet":
				box(h + Vector3(0, 0.0, 0.025), Vector3(0.008, 0.07, 0.05), Basis(Vector3.RIGHT, -0.3), Color(0.15, 0.3, 0.2), 0.7, hb)
			"baguette":
				ellipsoid(h + Vector3(s * 0.01, 0.02, 0.0), Vector3(0.017, 0.15, 0.017), Basis(Vector3.RIGHT, 1.25), Color(0.86, 0.6, 0.28), 0.85, hb, 0.0, 10, 10)
			"canne":
				tube([h + Vector3(0, 0.03, 0.01), h + Vector3(0, -0.01, 0.005), h + Vector3(0, -0.06, 0.0), h + Vector3(0, -0.17, -0.005)],
					[0.007, 0.007, 0.007, 0.006], Color(0.2, 0.12, 0.08), 0.4, hb, 6)
			"verre":
				var g := h + Vector3(-s * 0.005, 0.0, 0.022)
				lathe(g, [[0.015, -0.03], [0.004, -0.028], [0.003, 0.0], [0.022, 0.035], [0.0, 0.03]], Basis(), [[0.0, Color(0.85, 0.85, 0.9)], [0.55, Color(1.0, 0.55, 0.15)]], 0.1, hb, 1.0, 10, 0.25)
			"micro":
				tube([h + Vector3(0, -0.02, 0.01), h + Vector3(0, 0.05, 0.04)], [0.007, 0.008], DARK, 0.4, hb, 6)
				ellipsoid(h + Vector3(0, 0.065, 0.048), Vector3(0.017, 0.017, 0.017), Basis(), Color(0.7, 0.7, 0.72), 0.3, hb, 0.0, 8, 6)
			"cartes":
				for j in 4:
					box(h + Vector3(0, 0.03, 0.02), Vector3(0.035, 0.05, 0.002), Basis(Vector3.BACK, (j - 1.5) * 0.25) * Basis(Vector3.RIGHT, -0.3), WHITE if j % 2 == 0 else Color(0.95, 0.92, 0.85), 0.5, hb)
			"sac":
				box(h + Vector3(0, -0.04, 0.0), Vector3(0.025, 0.045, 0.06), Basis(), _col("bag_color", Color(0.45, 0.15, 0.18)), 0.5, hb)
				tube([h + Vector3(0, -0.018, -0.02), h + Vector3(0, 0.01, 0.0), h + Vector3(0, -0.018, 0.02)], [0.003, 0.003, 0.003], GOLD, 0.3, hb, 4, false)
			"mallette":
				box(h + Vector3(0, -0.055, 0.0), Vector3(0.025, 0.07, 0.1), Basis(), Color(0.32, 0.18, 0.1), 0.45, hb)
				box(h + Vector3(0, -0.012, 0.0), Vector3(0.008, 0.012, 0.035), Basis(), GOLD, 0.3, hb)
			"jetons":
				lathe(h + Vector3(0, -0.01, 0.03), [[0.0, 0.0], [0.02, 0.0], [0.02, 0.03], [0.0, 0.03]], Basis(Vector3.RIGHT, 0.2),
					[[0.0, Color(0.75, 0.1, 0.12)], [0.4, WHITE], [0.6, Color(0.75, 0.1, 0.12)]], 0.4, hb, 1.0, 12)
			"cle":
				# La clé plate du garagiste.
				var steel := Color(0.62, 0.64, 0.68)
				box(h + Vector3(0, -0.04, 0.01), Vector3(0.008, 0.1, 0.016), Basis(), steel, 0.3, hb)
				lathe(h + Vector3(0, -0.095, 0.01), [[0.0, -0.004], [0.017, -0.004], [0.017, 0.004], [0.0, 0.004]], Basis(Vector3.RIGHT, PI / 2), steel, 0.3, hb, 1.0, 10)
			"plateau":
				lathe(h + Vector3(0, 0.02, 0.04), [[0.0, 0.0], [0.09, 0.0], [0.095, 0.008], [0.0, 0.004]], Basis(), Color(0.8, 0.8, 0.82), 0.25, hb, 1.0, 18)
