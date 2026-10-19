extends RefCounted
## La vague « vie » des PNJ (js/npc-vie.js) : le Strip, la salle de concert et l'arène de boxe peuplés de vrais
## personnages. Extension du moteur (pnj/pnj.gd) : elle passe par ses crochets (ext_start, ext_tick, ext_decide)
## et ses briques. Sections : 1 réglages · 2 outils, corps, poses procédurales · 3 imposteurs (la foule de fond
## échangée près du joueur) · 4 le Strip (passants, traversées, fontaines) · 5 le concert (musiciens, public,
## entracte) · 6 l'arène (boxeurs, arbitre, soigneurs, officiels, spectateurs) · 7 destinations des clients ·
## 8 démarrage, boucle, état.
## Figurants (kind « extra ») : hors des 120 PNJ du casino ; rattachés à un lieu, masqués (aucun coût de rendu ni
## d'animation) tant que ce lieu n'est pas montré. Les lieux suivent les pilotes du lot F (zones/pilotes.gd) et
## l'état des fontaines (zones/fontaines.gd).

# ==================================================================================================
# 1. Réglages
# ==================================================================================================
var CFG := {
	"strip": {"peds": 18, "couples": 3, "crossShare": 0.4, "far": 42.0, "despawn": 58.0},
	"concert": {"dancers": 22, "proxies": 14},
	"arene": {"spectators": 26, "proxies": 12, "officials": true},
	"proxyIn": 8.5, "proxyOut": 10.5,
	"clientVenues": 1.0,
}

var NK
var scene: Node3D
var CO: Dictionary
var AR: Dictionary
var FONT = null
var LAY: Dictionary
var extras: Array = []
var venues := {}
var stat := {"coups": 0, "touches": 0, "knockdowns": 0, "acclamations": 0, "crossings": 0, "fountainWatch": 0, "swaps": 0, "arrivals": {}, "fails": {}}
var _fontaines_vu := false
var _ar_bell := -99.0

func rnd(a: float, b: float) -> float: return a + randf() * (b - a)
func irnd(a: int, b: int) -> int: return floori(a + randf() * (b - a + 1))
func pick(a: Array): return a[floori(randf() * a.size())]
static func has_tag(o, t: String) -> bool: return o != null and o.has("tags") and t in o.tags
static func yaw_to(dx: float, dz: float) -> float: return atan2(-dx, -dz)
func now() -> float: return NK.now
func arrived(k: String) -> void: stat.arrivals[k] = int(stat.arrivals.get(k, 0)) + 1
func failed(k: String) -> void: stat.fails[k] = int(stat.fails.get(k, 0)) + 1
func emit(nom: String, d := {}) -> void: NK.event(nom, d)
## Un point libre (personne ne le tient, ou quelqu'un qui n'est plus là).
func libre(p: Dictionary) -> bool: return p.get("_occ") == null or not NK.by_id.has(p._occ)
func zone_active(id: String) -> bool: return scene == null or not scene.has_method("zone_montree") or scene.zone_montree(id)
func level_y(l: float) -> float: return NK.M.niveau_y(l)
func joueur_pos() -> Vector3: return Vector3(NK.J.x, NK.J.y, NK.J.z)


func _init(pnj, s: Node3D) -> void:
	NK = pnj
	scene = s
	var pl = s.get("K").places if s != null and s.get("K") != null else {}
	var pil = pl.get("pilotes")
	if pil != null:
		CO = pil.concert
		AR = pil.arene
		pil.ecoutes.append(_bus)
	FONT = pl.get("e_fontaines_etat")
	LAY = NK.M.donnees.get("lay", {})
	NK.ext_start.append(start)
	NK.ext_tick.append(tick)
	NK.ext_decide.append(decide_hook)


# ==================================================================================================
# 2. Outils : corps, apparence, places, poses procédurales
# ==================================================================================================
const TOPS := ["#7a1f2b", "#1f3a5f", "#2f5d50", "#c9a24a", "#e8e2d0", "#4a2d5e", "#24242a", "#b5482f", "#3c6e8f", "#cfcfd6", "#8c2f5a", "#5b6b2e", "#1d6a72", "#d98a9a", "#6b6f7a", "#234a2c"]
const BOTTOMS := ["#1b1b20", "#23283a", "#3a2f28", "#4b4b52", "#1d2b24", "#2c2230", "#6b6257", "#2a3550"]
const HAIRS := ["#2a1a10", "#0f0d0c", "#7a5a2a", "#b9952f", "#8c8c90", "#5c2a14", "#d9d2c4"]

## Les teintes (tint de npc-vie.js) aux matières du modèle, comme clientTint.
func tint(tpl: Dictionary, o: Dictionary) -> Dictionary:
	var out := {}
	if o.has("by"):
		for k in o.by:
			out[k] = Color(o.by[k])
	var tops: Array = NK.RE_TOP if tpl.human else NK.RE_TOP62.get(tpl.name, [])
	var bots: Array = NK.RE_BOTTOM if tpl.human else NK.RE_BOT62.get(tpl.name, ["LightBlue"])
	if o.get("top") != null:
		for m in tops:
			if not out.has(m):
				out[m] = Color(o.top)
	if o.get("bottom") != null:
		for m in bots:
			if not out.has(m):
				out[m] = Color(o.bottom)
	if o.get("hair") != null:
		for m in NK.RE_HAIR:
			if not out.has(m):
				out[m] = Color(o.hair)
	if o.get("skin") != null and float(o.skin) != 1.0:
		out["Skin*"] = float(o.skin)
	return out


func random_tint() -> Dictionary:
	return {"top": pick(TOPS), "bottom": pick(BOTTOMS), "hair": pick(HAIRS) if randf() < 0.7 else null, "skin": pick([1.0, 1.0, 0.82, 0.66, 0.5, 1.08])}


func template(want) -> Dictionary:
	var T: Dictionary = NK.templates
	if want is String and T.has(want):
		return T[want]
	var list: Array = []
	if want is Array:
		list = want.filter(func(k): return T.has(k))
	else:
		var re := RegEx.new()
		re.compile("^dealer-|real-swat|real-worker")
		list = T.keys().filter(func(k): return re.search(k) == null)
	return T[pick(list if list.size() else T.keys())]


## Un figurant : un corps, masqué jusqu'à ce que son lieu s'active.
func create(role: String, venue: Dictionary, o := {}) -> Dictionary:
	var tpl := template(o.get("tpl"))
	var n: Dictionary = NK.base_npc("extra", role, tpl, tint(tpl, o.tint if o.has("tint") else random_tint()))
	cles(n)
	n.venue = venue
	n.pace = rnd(0.86, 1.05)
	n.speed = float(tpl.natural) * n.pace
	n.mood = rnd(0.5, 0.9)
	n.guts = 0.15
	n.heat = 0.0
	n.hp = 3
	n.hidden = true
	n.level = float(o.get("level", 0.0))
	n.x = float(o.get("x", 0.0))
	n.z = float(o.get("z", 0.0))
	n.y = level_y(n.level)
	n.yaw = float(o.get("yaw", 0.0))
	n.vs = {"s": "off"}
	n.job = func(m): NK.set_beh(m, "vie")
	n.rank = 1
	extras.append(n)
	venue.extras.append(n)
	NK.set_beh(n, "vie")
	return n


## Les champs de la vague « vie » (l'original les ajoute à la volée) : sur les figurants, et sur les clients qui
## dansent ou acclament.
func cles(n: Dictionary) -> void:
	if not n.has("rig"):
		n.merge({"vstep": null, "lead": null, "mate": null, "proxy": false, "part": "", "spot": null, "gear": false, "kit": false, "opp": null,
			"corner": "", "color": "", "home": null, "dance": null, "cheer": null, "rig": null, "snap": false, "pw": 0.0, "oppK": null}, false)


func set_level(n: Dictionary, level: float) -> void:
	n.level = level
	n.y = level_y(level)


func hide(n: Dictionary) -> void:
	if n.hidden and n.seatState == null:
		return
	if n.seatState != null:
		release_seat(n)
	NK.free_points(n)
	n.nav = null
	NK.set_move(n, null)
	still(n)
	n.hidden = true
	n.vs.s = "off"
	n.follow = null


## Coupe les mouvements procéduraux.
func still(n: Dictionary) -> void:
	n.anim = null
	n.pose = null
	n.dance = null
	var inner: Node3D = n.corps.inner
	inner.rotation.z = 0.0
	n.corps.vitesses.clear()
	n.gest = null
	NK.set_base(n, "idle")


## Places : vraie station (claim) ou place fictive (imposteur, musicien).
func fake_seat(x: float, z: float, facing: float, seat_height: float, elevation := 0.0) -> Dictionary:
	var seat := {"index": 0, "position": {"x": x, "y": 0.0, "z": z}, "facing": facing, "sit": true, "seatHeight": seat_height, "elevation": elevation,
		"approach": {"x": x - sin(facing) * 0.6, "y": 0.0, "z": z - cos(facing) * 0.6}, "occupant": null, "_bad": 0}
	return {"st": {"id": "vie-place", "type": "vie", "level": 0.0, "seats": [seat], "tags": ["vie"]}, "seat": seat}


func sit_now(n: Dictionary, st: Dictionary, seat: Dictionary) -> bool:
	if st.type == "vie":
		seat.occupant = n.id
		n.station = st
		n.seat = seat
	elif not NK.claim(n, st, seat):
		return false
	set_level(n, float(st.get("level", 0.0)))
	n.x = float(seat.position.x)
	n.z = float(seat.position.z)
	n.yaw = float(seat.facing)
	n.seatState = "seated"
	n.sitK = 1.0
	n.seatT = 0.0
	n.nav = null
	NK.set_move(n, null)
	NK.refresh_anim(n, 0)
	return true


func release_seat(n: Dictionary) -> void:
	var st = n.station
	var seat = n.seat
	if st != null and seat != null and seat.occupant == n.id:
		if st.type == "vie":
			seat.occupant = null
		else:
			NK.release_seat(st, int(seat.index))
	n.station = null
	n.seat = null
	n.seatState = null
	n.sitK = 0.0
	var inner: Node3D = n.corps.inner
	inner.position = Vector3.ZERO
	NK.refresh_anim(n, 0)


## Aller s'asseoir sur une vraie place.
func seat_go(n: Dictionary, st: Dictionary, seat: Dictionary) -> bool:
	if not NK.claim(n, st, seat):
		return false
	n.vs.sp = 0
	NK.go_to(n, {"x": seat.approach.x, "z": seat.approach.z, "level": float(st.get("level", 0.0))})
	return true


## « go », « seated » ou « fail ».
func seat_step_vie(n: Dictionary, dt: float) -> String:
	if n.vs.get("sp") == 0:
		var r: String = NK.step_nav(n, dt)
		if r == "fail":
			var st = n.station
			NK.unclaim(n)
			failed("place " + (str(st.id) if st != null else "?"))
			return "fail"
		if r == "done":
			NK.begin_sit(n)
			n.vs.sp = 1
		return "go"
	var s = NK.seat_step(n, dt)
	if s == "seated":
		return "seated"
	if s == null:
		return "fail"
	return "go"


## Se lever et quitter la place : vrai quand c'est fait.
func stand_step(n: Dictionary, dt: float) -> bool:
	if n.seatState == null:
		return true
	if n.seatState == "seated" or n.seatState == "cheer":
		if n.station != null and n.station.type == "vie":
			release_seat(n)
			return true
		n.seatState = "seated"
		NK.begin_stand(n)
	return NK.seat_step(n, dt) == null


# --- poses procédurales : orientation d'os en espace « corps » (x = côté gauche si sL > 0, y = haut, z = devant).
# Pour chaque os visé : la rotation « corps » du parent, la rotation minimale qui amène l'axe de l'os (vers son
# premier enfant) sur la direction voulue, retour en local, mélange (poids). Appelé juste après le lecteur.
func rig(n: Dictionary):
	cles(n)
	if n.rig != null:
		return n.rig if n.rig is Dictionary else null
	var c = n.corps
	var sk: Skeleton3D = c.sk
	if sk == null:
		n.rig = false
		return null
	var t := Transform3D()
	var nd: Node = sk
	while nd != c.inner and nd != null:
		t = (nd as Node3D).transform * t
		nd = nd.get_parent()
	var tq := t.basis.orthonormalized().get_rotation_quaternion()
	var bone := func(nom: String):
		var i: int = c._idx(nom)
		if i < 0:
			return null
		var axe := Vector3.UP
		for ch in sk.get_bone_children(i):
			var o := sk.get_bone_rest(ch).origin
			if o.length() > 1e-6:
				axe = o.normalized()
			break
		return {"i": i, "parent": sk.get_bone_parent(i), "axis": axe}
	var r := {"uaL": bone.call("UpperArmL"), "laL": bone.call("LowerArmL"), "uaR": bone.call("UpperArmR"), "laR": bone.call("LowerArmR"), "sL": 1.0, "tq": tq, "sk": sk}
	if r.uaL == null or r.laL == null or r.uaR == null or r.laR == null:
		n.rig = false
		return null
	var xl := (t * sk.get_bone_global_rest(r.uaL.i).origin).x
	var xr := (t * sk.get_bone_global_rest(r.uaR.i).origin).x
	r.sL = 1.0 if xl >= xr else -1.0
	n.rig = r
	return r


func _corps_q(R: Dictionary, i: int) -> Quaternion:
	if i < 0:
		return R.tq
	var sk: Skeleton3D = R.sk
	return R.tq * sk.get_bone_global_pose(i).basis.orthonormalized().get_rotation_quaternion()


func _aim(R: Dictionary, rec: Dictionary, dir: Vector3, w: float) -> void:
	var sk: Skeleton3D = R.sk
	var P := _corps_q(R, rec.parent)
	var qb := sk.get_bone_pose_rotation(rec.i)
	var qB := P * qb
	var v1: Vector3 = (qB * rec.axis).normalized()
	var qR: Quaternion
	var d := v1.dot(dir)
	if d < -0.99999:
		var ax := v1.cross(Vector3.RIGHT)
		if ax.length() < 1e-4:
			ax = v1.cross(Vector3.UP)
		qR = Quaternion(ax.normalized(), PI)
	elif d > 0.99999:
		qR = Quaternion()
	else:
		qR = Quaternion(v1, dir)
	var qL := P.inverse() * (qR * qB)
	sk.set_bone_pose_rotation(rec.i, qL.normalized() if w >= 0.999 else qb.slerp(qL.normalized(), w))


## Bras : up = direction du bras, lo = de l'avant-bras ; [dehors, haut, devant] ; side « L » | « R ».
func arm(n: Dictionary, side: String, up: Array, lo: Array, w: float) -> void:
	var R = rig(n)
	if R == null or w <= 0.001:
		return
	var s: float = R.sL if side == "L" else -R.sL
	_aim(R, R["ua" + side], Vector3(up[0] * s, up[1], up[2]).normalized(), w)
	_aim(R, R["la" + side], Vector3(lo[0] * s, lo[1], lo[2]).normalized(), w)


func pose_guard(n, w: float) -> void:
	arm(n, "L", [0.32, -0.5, 0.78], [-0.2, 0.86, 0.48], w)
	arm(n, "R", [0.4, -0.72, 0.5], [-0.42, 0.86, 0.3], w)

func pose_arms_up(n, w: float, t: float) -> void:
	var a := sin(t * 5.2) * 0.35
	arm(n, "L", [0.42, 0.85, 0.2], [0.18 + a, 0.97, 0.12], w)
	arm(n, "R", [0.42, 0.85, 0.2], [0.18 - a, 0.97, 0.12], w)

func pose_one_up(n, w: float, t: float) -> void:
	arm(n, "R", [0.35, 0.9, 0.25], [0.1 + sin(t * 3) * 0.25, 1, 0.2], w)

func pose_clap(n, w: float, open: float) -> void:
	arm(n, "L", [0.18, -0.45, 0.75], [-0.62 + open * 0.55, 0.42, 0.68], w)
	arm(n, "R", [0.18, -0.45, 0.75], [-0.62 + open * 0.55, 0.42, 0.68], w)

func pose_mic(n, w: float) -> void:
	arm(n, "R", [0.28, -0.5, 0.6], [-0.38, 0.86, 0.32], w)

func pose_winner(n, w: float) -> void:
	arm(n, "L", [0.3, 0.95, 0.05], [0.12, 1, 0.05], w)
	arm(n, "R", [0.3, 0.95, 0.05], [0.12, 1, 0.05], w)


# --- instruments : boîtes à couleurs de sommets (le matériau partagé des accessoires) ---
static var _geo := {}
static var _mat_instr: StandardMaterial3D = null

func box_geo(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var b := BoxMesh.new()
		b.size = Vector3(p[0], p[1], p[2])
		var ar := b.get_mesh_arrays()
		var P: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
		var N: PackedVector3Array = ar[Mesh.ARRAY_NORMAL]
		var I: PackedInt32Array = ar[Mesh.ARRAY_INDEX]
		var c := Color(p[6])
		for k in I:
			st.set_color(c)
			st.set_normal(N[k])
			st.add_vertex(P[k] + Vector3(p[3], p[4], p[5]))
	if _mat_instr == null:
		_mat_instr = StandardMaterial3D.new()
		_mat_instr.vertex_color_use_as_albedo = true
		_mat_instr.vertex_color_is_srgb = true
		_mat_instr.roughness = 0.6
	st.set_material(_mat_instr)
	return st.commit()


func guitar_geo(bass: bool, color: String) -> ArrayMesh:
	var k := "g%s%s" % [bass, color]
	if not _geo.has(k):
		var L := 0.95 if bass else 0.7
		_geo[k] = box_geo([[0.42, 0.34, 0.08, 0, 0, 0, color], [0.2, 0.3, 0.081, 0.12, 0.02, 0, color], [0.1, 0.1, 0.01, -0.02, 0, 0.045, "#15151a"],
			[L, 0.055, 0.035, L / 2.0 + 0.16, 0.02, 0, "#3a2516"], [0.16, 0.08, 0.03, 1.18 if bass else 0.93, 0.02, 0, "#15151a"],
			[0.05, 0.22, 0.012, -0.08, 0, 0.047, "#d9d2c4"]])
	return _geo[k]


## Instrument porté : enfant du modèle (espace « corps »), le corps de l'instrument devant le ventre, le manche
## vers la main gauche.
func wear_guitar(n: Dictionary, bass: bool, color: String) -> void:
	var R = rig(n)
	var s: float = R.sL if R != null else 1.0
	var inner: Node3D = n.corps.inner
	var sc: float = inner.scale.x if inner.scale.x > 1e-6 else 1.0
	var m := MeshInstance3D.new()
	m.name = "pnj-instrument"
	m.mesh = guitar_geo(bass, color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var xa := Vector3(0.9 * s, 0.3, 0.22).normalized()
	var za := Vector3(0, 0.1, 1).normalized()
	var ya := za.cross(xa).normalized()
	za = xa.cross(ya).normalized()
	m.transform = Transform3D(Basis(xa, ya, za).scaled_local(Vector3.ONE / sc), Vector3(-0.04 * s / sc, 1.0 / sc, 0.2 / sc))
	inner.add_child(m)
	n.accs.append(m)


func hand(n: Dictionary, side: String) -> String:
	return ("Palm" if n.tpl.human else "Wrist") + side


func acc(n: Dictionary, os: String, couleur: int, along: float, size: Array) -> void:
	var m = n.corps.accessoire(os, "box", Color.hex((couleur << 8) | 0xff), {"along": along, "size": size})
	if m != null:
		n.accs.append(m)


# --- danse : le clip calé sur le tempo, rebond, balancement, bras levés ; styles variés ---
const DANCE_STYLES := ["clip", "clip", "bounce", "clap", "arms", "phone", "clip"]

func dance_start(n: Dictionary, style := "") -> void:
	cles(n)
	n.dance = {"style": style if style != "" else pick(DANCE_STYLES), "off": randf(), "amp": rnd(0.03, 0.07), "sway": rnd(0.03, 0.08), "up": randf() < 0.35}
	if n.dance.style == "clap" and NK.resolve_key(n, "clap") != "clap":
		n.dance.style = "bounce"
	dance_base(n)
	n.anim = dance_anim
	n.pose = dance_pose


func dance_base(n: Dictionary) -> void:
	var d = n.get("dance")
	if d == null or CO.is_empty():
		return
	var ballad: bool = CO.song.style == "ballade"
	var on: bool = CO.state == "morceau" and CO.playing
	var base := "idle"
	if on:
		if ballad:
			base = "phone" if d.style == "phone" else "idle"
		else:
			base = {"clip": "dance", "clap": "clap", "phone": "phone"}.get(d.style, "idle")
	NK.set_base(n, base, 0.3)
	if base == "dance":
		tempo_dance(n)


func tempo_dance(n: Dictionary) -> void:
	var k: String = NK.resolve_key(n, "dance")
	if not n.corps.a_clip(k):
		return
	var dur: float = n.corps.duree(k)
	var beats := maxi(2, roundi(dur * 2.1))
	n.corps.regler_vitesse(k, clampf((CO.bpm / 60.0) * dur / beats, 0.45, 1.6))


func dance_anim(n: Dictionary, _dt: float) -> void:
	var d = n.get("dance")
	if d == null or CO.is_empty():
		return
	var on: bool = CO.state == "morceau" and CO.playing
	var ph: float = CO.phase + d.off * 0.25
	var ballad: bool = CO.song.style == "ballade"
	var inner: Node3D = n.corps.inner
	var hop := 0.0
	if on:
		hop = pow(maxf(0.0, sin(ph * TAU)), 2) * d.amp * (0.5 + CO.energy) * (0.2 if ballad else 1.0) * (0.4 if d.style == "clip" else 1.0)
	inner.position.y += hop
	inner.rotation.z = sin((CO.beatPos + d.off) * PI) * d.sway * (1.6 if ballad else 1.0) if on else inner.rotation.z * 0.9


func dance_pose(n: Dictionary) -> void:
	var d = n.get("dance")
	if d == null or CO.is_empty():
		return
	if CO.state != "morceau" or not CO.playing or n.gest != null:
		return
	var ballad: bool = CO.song.style == "ballade"
	var t: float = now() + d.off * 10
	if d.style == "arms" or (ballad and d.up):
		pose_arms_up(n, 0.85 if ballad else 1.0, t * (0.35 if ballad else 1.0))
	elif d.style == "bounce" and CO.energy > 0.85:
		if d.up:
			pose_arms_up(n, 1, t)
		else:
			pose_one_up(n, 1, t)
	elif d.style == "clap" and NK.resolve_key(n, "clap") != "clap":
		pose_clap(n, 1, absf(sin(CO.phase * PI)))


# --- debout depuis un siège (temps forts) : seatState « cheer », sitK → 0 ; retour à l'assise ensuite ---
func cheer_start(n: Dictionary, dur: float, how := "") -> bool:
	cles(n)
	if n.seatState != "seated" or n.seat == null or not n.seat.get("sit", false):
		return false
	n.seatState = "cheer"
	n.cheer = {"until": now() + dur, "how": how if how != "" else pick(["clap", "railCall", "yes", "arms"])}
	NK.set_base(n, "idle" if n.cheer.how == "arms" or n.cheer.how == "yes" else n.cheer.how, 0.25)
	if n.cheer.how == "yes":
		NK.gesture(n, "yes", minf(dur, 2))
	n.anim = cheer_anim
	n.pose = cheer_pose if n.cheer.how == "arms" else null
	return true


func cheer_anim(n: Dictionary, _dt: float) -> void:
	var s = n.seat
	if s != null and float(s.get("elevation", 0.0)):
		var k: float = n.sitK
		(n.corps.inner as Node3D).position.y += float(s.elevation) * (1 - k * k * (3 - 2 * k))


func cheer_pose(n: Dictionary) -> void:
	pose_arms_up(n, 1, now())


func cheer_step(n: Dictionary, dt: float) -> void:
	var c = n.get("cheer")
	var s = n.seat
	if c == null or s == null:
		return
	var fx: float = -sin(s.facing) * 0.22
	var fz: float = -cos(s.facing) * 0.22
	if n.seatState == "cheer":
		if now() < c.until:
			n.sitK = maxf(0.0, n.sitK - dt * 2.6)
		else:
			n.sitK = minf(1.0, n.sitK + dt * 2.6)
			if n.sitK >= 1:
				n.seatState = "seated"
				n.cheer = null
				n.anim = null
				n.pose = null
				NK.set_base(n, "idle")
				NK.refresh_anim(n, 0.2)
		var k: float = 1.0 - n.sitK
		n.x = float(s.position.x) + fx * k
		n.z = float(s.position.z) + fz * k


# ==================================================================================================
# 3. Imposteurs : la foule de fond échangée près du joueur contre de vrais personnages
# ==================================================================================================
## Lit les foules instanciées des zones (MultiMeshInstance3D « foule_* » : une pose par appel), garde leurs
## matrices ; les instances à moins de proxyIn m de la caméra sont aplaties et remplacées par un figurant posé au
## même endroit, même orientation.
func swapper(venue: Dictionary, zone_ids: Array, size: int, on_assign: Callable) -> Dictionary:
	var list: Array = []
	for id in zone_ids:
		var z = NK.M.zone_par_id.get(id)
		var nd: Node = scene.get_node_or_null(NodePath(scene.get("_rendu").noeud(id))) if scene != null and scene.get("_rendu") != null else null
		if nd == null or z == null:
			continue
		var lv := float(z.get("level", 0.0))
		for m in nd.find_children("foule*", "MultiMeshInstance3D", false, false):
			var mmi := m as MultiMeshInstance3D
			var mm := mmi.multimesh
			var seated = (mmi.multimesh.mesh == load(NK.BASE + "zones/lot_e.gd").forme_silhouette("assis"))
			var t0s: Array = mmi.get_meta("t0s", [])
			for i in mm.instance_count:
				var t0: Transform3D = t0s[i] if i < t0s.size() else mm.get_instance_transform(i)
				var g := mmi.global_transform * t0
				list.append({"mm": mm, "i": i, "t0": t0, "x": g.origin.x, "y": g.origin.y - level_y(lv), "z": g.origin.z, "ry": g.basis.get_euler().y,
					"seated": seated, "level": lv, "npc": null, "d2": 0.0})
	var pool: Array = []
	for i in (size if list.size() else 0):
		var n := create("figurant", venue)
		n.proxy = true
		pool.append(n)
	var self_ := {"list": list, "pool": pool, "active": 0, "scanT": 0.0, "on_assign": on_assign}
	return self_


func sw_flat(it: Dictionary, on: bool) -> void:
	var mm: MultiMesh = it.mm
	mm.set_instance_transform(it.i, Transform3D(Basis().scaled(Vector3.ZERO), it.t0.origin) if on else it.t0)


func sw_release(S: Dictionary, it: Dictionary) -> void:
	var n = it.npc
	it.npc = null
	sw_flat(it, false)
	if n != null:
		n.proxyOf = null
		hide(n)
	S.active -= 1


func sw_release_all(S: Dictionary) -> void:
	for it in S.list:
		if it.npc != null:
			sw_release(S, it)


func sw_tick(S: Dictionary, dt: float) -> void:
	S.scanT -= dt
	if S.scanT > 0 or S.list.is_empty():
		return
	S.scanT = 0.3
	var cam_n: Camera3D = scene.get_viewport().get_camera_3d() if scene != null and scene.is_inside_tree() else null
	var cam: Vector3 = cam_n.global_position if cam_n != null else joueur_pos() + Vector3(0, 1.6, 0)
	var fwd: Vector3 = -cam_n.global_basis.z if cam_n != null else Vector3.FORWARD
	var rin: float = CFG.proxyIn * CFG.proxyIn
	var rout: float = CFG.proxyOut * CFG.proxyOut
	var fl := Vector2(fwd.x, fwd.z).length()
	if fl < 1e-6:
		fl = 1.0
	var cand: Array = []
	for it in S.list:
		var dx: float = it.x - cam.x
		var dz: float = it.z - cam.z
		var dy: float = it.y + level_y(it.level) + 1 - cam.y
		var d2 := dx * dx + dz * dz + dy * dy
		if it.npc != null:
			if d2 > rout or (NK.J.level != it.level and absf(NK.J.y - level_y(it.level)) > 3):
				sw_release(S, it)
			else:
				it.d2 = d2
		elif d2 < rin:
			var dot := (dx * fwd.x + dz * fwd.z) / fl
			it.d2 = d2 if dot > -0.5 else d2 * 4 + 40
			cand.append(it)
	if cand.is_empty():
		return
	cand.sort_custom(func(a, b): return a.d2 < b.d2)
	for k in cand.size():
		var n = _sw_libre(S)
		if n == null:
			var far = null
			for it in S.list:
				if it.npc != null and (far == null or it.d2 > far.d2):
					far = it
			if far == null or far.d2 <= cand[k].d2 + 4:
				break
			sw_release(S, far)
			n = _sw_libre(S)
			if n == null:
				break
		var it: Dictionary = cand[k]
		it.npc = n
		n.proxyOf = it
		S.active += 1
		stat.swaps += 1
		sw_flat(it, true)
		n.hidden = false
		n.vs = {"s": "proxy"}
		set_level(n, it.level)
		n.yaw = it.ry
		n.x = it.x
		n.z = it.z
		if it.seated:
			var f := fake_seat(it.x, it.z, it.ry, it.y + 0.45, it.y)
			sit_now(n, f.st, f.seat)
		else:
			n.y = level_y(it.level) + it.y
		S.on_assign.call(n, it)


func _sw_libre(S: Dictionary):
	for p in S.pool:
		if p.proxyOf == null:
			return p
	return null


## Un figurant d'imposteur : rester à sa place, réagir au lieu (piloté par le lieu).
func proxy_step(n: Dictionary, _b: Dictionary, dt: float) -> bool:
	if n.proxyOf == null:
		if not n.hidden:
			hide(n)
		return false
	var it: Dictionary = n.proxyOf
	if not it.seated:
		n.y = level_y(it.level) + it.y
		n.x = it.x
		n.z = it.z
		NK.turn(n, it.ry, 3, dt)
	elif n.seatState == "cheer" or n.get("cheer") != null:
		cheer_step(n, dt)
	elif n.seatState == null:
		var f := fake_seat(it.x, it.z, it.ry, it.y + 0.45, it.y)
		n.anim = null
		n.pose = null
		sit_now(n, f.st, f.seat)
	return false


# ==================================================================================================
# 4. Le Strip : passants sur les trottoirs (points walk), traversées, fontaines
# ==================================================================================================
func setup_strip():
	if LAY.is_empty() or not NK.M.zone_par_id.has("X-STRIP"):
		return null
	var walk: Array = NK.pts("walk").filter(func(p): return has_tag(p, "strip"))
	var sides := {"casino": walk.filter(func(p): return p.get("side") == "casino"), "enface": walk.filter(func(p): return p.get("side") == "enface")}
	for k in sides:
		sides[k].sort_custom(func(a, b): return a.x < b.x)
	if sides.casino.size() < 3 or sides.enface.size() < 3:
		return null
	var L := LAY
	var V := {"id": "strip", "zone": "X-STRIP", "L": L, "sides": sides, "extras": [], "on": false, "showOn": false, "scan": 0.0,
		"lane": {"casino": [L.WALK0 + 0.9, L.CURB0 - 0.9], "enface": [L.CURB1 + 1.2, L.CURB1 + 6.5]},
		"fountain": NK.pts("watch").filter(func(p): return has_tag(p, "fontaines")),
		"waits": NK.pts("wait").filter(func(p): return has_tag(p, "strip") and not has_tag(p, "feu") and not has_tag(p, "arene"))}
	var P: Dictionary = CFG.strip
	for i in P.peds:
		create("passant", V).vstep = strip_step
	# couples : un second passant suit le premier (côte à côte)
	for i in P.couples:
		var lead: Dictionary = V.extras[i * 2]
		var n := create("passant", V)
		n.vstep = strip_step
		n.lead = lead
		lead.mate = n
	return V


func player_on_strip() -> float:
	return NK.J.x if NK.J.level == 0.0 and NK.J.z > 28 and NK.J.z < 92 else 0.0


func strip_activate(V: Dictionary) -> void:
	V.on = true
	var px := clampf(player_on_strip(), -100, 100)
	for n in V.extras:
		if n.lead == null:
			strip_spawn(V, n, px, true)
	for n in V.extras:
		if n.lead != null:
			couple_join(n)


func lane_z(V: Dictionary, side: String, x: float) -> float:
	var r: Array = V.lane[side]
	for k in 6:
		var z := rnd(r[0], r[1])
		if NK.M.degagement(0.0, x, z) >= 0.55:
			return z
	return (r[0] + r[1]) / 2.0


func nearest(x: float, z: float, r: int, level: float):
	var i: int = NK.M.proche({"x": x, "z": z}, r, level)
	return NK.M._pt(i) if i >= 0 else null


## (Re)place un passant : au premier passage n'importe où autour du joueur, ensuite hors de vue (au-delà de far).
func strip_spawn(V: Dictionary, n: Dictionary, px: float, first: bool) -> void:
	var far := maxf(CFG.strip.far, float(NK.CFG.far) + 4)
	var L: Dictionary = V.L
	var side := "casino" if randf() < 0.58 else "enface"
	var x: float
	var dir: float
	if first:
		x = clampf(px + rnd(-far, far), -L.XEND + 4, L.XEND - 4)
		dir = 1.0 if randf() < 0.5 else -1.0
	else:
		var s := 1.0 if randf() < 0.5 else -1.0
		x = px + s * rnd(far, far + 12)
		if absf(x) > L.XEND - 3:
			x = px - s * rnd(far, far + 12)
		x = clampf(x, -L.XEND + 3, L.XEND - 3)
		dir = signf(px - x) if px != x else 1.0
		if randf() < 0.25:
			dir = -dir
	var z := lane_z(V, side, x)
	var nd = nearest(x, z, 4, 0.0)
	if nd == null:
		hide(n)
		return
	still(n)
	n.hidden = false
	set_level(n, 0.0)
	n.x = nd.x
	n.z = nd.z
	n.yaw = -PI / 2 if dir > 0 else PI / 2
	n.vs = {"s": "walk", "side": side, "dir": dir, "wi": -1, "t": 0.0, "plan": 0, "crossed": false}
	n.trailOn = n.mate != null
	n.trail = []
	if n.mate != null:
		couple_join(n.mate)
	strip_next(V, n)


func couple_join(n: Dictionary) -> void:
	var L = n.lead
	if L == null or L.hidden:
		hide(n)
		n.vs = {"s": "off"}
		return
	still(n)
	n.hidden = false
	set_level(n, 0.0)
	n.x = L.x + 0.5
	n.z = L.z
	n.yaw = L.yaw
	n.vs = {"s": "follow"}
	var nd = nearest(n.x, n.z, 3, 0.0)
	if nd != null and NK.M.degagement(0.0, n.x, n.z) < 0.3:
		n.x = nd.x
		n.z = nd.z


## L'étape suivante : point walk suivant dans le sens de marche, ou une halte (fontaines, abribus, traversée,
## entrée du casino).
func strip_next(V: Dictionary, n: Dictionary) -> void:
	var s: Dictionary = n.vs
	var L: Dictionary = V.L
	var list: Array = V.sides[s.side]
	if s.side == "casino" and absf(n.x) < 9 and not s.get("crossed", false) and randf() < CFG.strip.crossShare:
		s.s = "cross"
		s.side = "enface"
		s.crossed = true
		s.dir = 1.0 if randf() < 0.5 else -1.0
		NK.go_to(n, {"x": rnd(-1.6, 1.6), "z": L.CURB1 + rnd(1.0, 2.2), "level": 0.0})
		stat.crossings += 1
		return
	if s.side == "enface" and absf(n.x) < 9 and not s.get("crossed", false) and randf() < CFG.strip.crossShare * 0.8:
		s.s = "cross"
		s.side = "casino"
		s.crossed = true
		s.dir = 1.0 if randf() < 0.5 else -1.0
		NK.go_to(n, {"x": rnd(-1.6, 1.6), "z": L.CURB0 - rnd(1.0, 2.0), "level": 0.0})
		stat.crossings += 1
		return
	if absf(n.x) > 12:
		s.crossed = false
	if V.showOn and s.side == "casino" and randf() < 0.65 and watch_fountain(V, n):
		return
	if randf() < 0.07:
		var w: Array = V.waits.filter(func(p): return libre(p) and absf(p.x - n.x) < 14 and (p.z < 66) == (s.side == "casino"))
		if w.size():
			var p: Dictionary = pick(w)
			if NK.take_point(n, p):
				s.s = "wait"
				s.p = p
				s.until = 0.0
				s.at = false
				NK.go_to(n, p)
				return
	if s.side == "casino" and absf(n.x) < 7 and randf() < 0.12:
		s.s = "enter"
		NK.go_to(n, {"x": rnd(-1.5, 1.5), "z": L.FACADE + 1.2, "level": 0.0})
		return
	# point walk suivant dans le sens de marche
	var next = null
	for i in list.size():
		var p: Dictionary = list[i if s.dir > 0 else list.size() - 1 - i]
		if (p.x - n.x) * s.dir > 2.5:
			next = p
			break
	if next == null:
		s.s = "gone"
		return
	var z := lane_z(V, s.side, next.x)
	s.s = "walk"
	NK.go_to(n, {"x": next.x + rnd(-1.5, 1.5), "z": z, "level": 0.0})
	if randf() < 0.06:
		s.phoneAt = now() + rnd(1, 4)


func watch_fountain(V: Dictionary, n: Dictionary) -> bool:
	var pts: Array = V.fountain.filter(func(p): return libre(p) and absf(p.x - n.x) < 26)
	if pts.is_empty():
		return false
	pts.sort_custom(func(a, b): return absf(a.x - n.x) < absf(b.x - n.x))
	var p: Dictionary = pts[0]
	if not NK.take_point(n, p):
		return false
	n.vs.s = "fountain"
	n.vs.p = p
	n.vs.until = 0.0
	n.vs.at = false
	NK.go_to(n, p)
	stat.fountainWatch += 1
	return true


func fountain_call(V: Dictionary) -> void:
	for n in V.extras:
		if not n.hidden and n.lead == null and n.vs.s == "walk" and n.vs.get("side") == "casino" and randf() < 0.6:
			n.nav = null
			watch_fountain(V, n)


func fountain_end(_V: Dictionary) -> void:
	var k := 0
	var sx := 0.0
	for n in venues.strip.extras:
		if n.vs.s == "fountain" and n.vs.get("at", false):
			k += 1
			sx += n.x
			n.vs.until = now() + rnd(1.5, 4.5)
			NK.gesture(n, "clap", 2.4)
	for n in NK.clients:
		if n.beh != null and n.beh.type == "spot" and has_tag(n.beh.p, "fontaines") and n.beh.phase == 1:
			k += 1
			sx += n.x
			NK.gesture(n, "clap", 2.2)
	if k >= 2:
		stat.acclamations += 1
		emit("pnj:acclamation", {"lieu": "fontaines", "x": snappedf(sx / k, 0.1), "y": 1.5, "z": 47, "force": clampf(k / 10.0, 0.2, 1), "count": k})


func strip_step(n: Dictionary, _b: Dictionary, dt: float) -> bool:
	var V: Dictionary = n.venue
	var s: Dictionary = n.vs
	if not V.on:
		if not n.hidden:
			hide(n)
		return false
	if n.lead != null:
		# le second du couple
		var L: Dictionary = n.lead
		if L.hidden or s.s != "follow":
			if not L.hidden:
				couple_join(n)
			elif not n.hidden:
				hide(n)
			return false
		if (L.vs.s == "fountain" or L.vs.s == "wait") and L.vs.get("at", false):
			NK.set_move(n, null)
			var p: Dictionary = L.vs.p
			NK.face(n, p.look.x if p.has("look") else L.x, p.look.z if p.has("look") else L.z, dt, 3)
			return false
		n.follow = L
		NK.follow_step(n, L, 0.45, 0.62, dt)
		return false
	if n.hidden:
		return false
	if s.get("phoneAt", 0.0) and now() > s.phoneAt:
		s.phoneAt = 0.0
		NK.set_base(n, "phone")
		s.phoneEnd = now() + rnd(6, 14)
	if s.get("phoneEnd", 0.0) and now() > s.phoneEnd:
		s.phoneEnd = 0.0
		NK.set_base(n, "idle")
	match s.s:
		"walk", "cross", "enter":
			var r: String = NK.step_nav(n, dt)
			if r == "fail":
				failed("strip:" + s.s)
				strip_spawn(V, n, player_on_strip(), false)
				return false
			if r == "done":
				if s.s == "cross":
					arrived("traversée")
				if s.s == "enter":
					arrived("entrée casino")
					strip_spawn(V, n, player_on_strip(), false)
					return false
				strip_next(V, n)
			if s.s == "gone":
				strip_spawn(V, n, player_on_strip(), false)
		"fountain", "wait":
			if not s.get("at", false):
				var r: String = NK.step_nav(n, dt)
				if r == "fail":
					NK.free_points(n)
					strip_next(V, n)
					return false
				if r == "done":
					s.at = true
					arrived("fontaines" if s.s == "fountain" else "attente")
					NK.set_base(n, "phone" if s.s == "wait" and randf() < 0.5 else ("foldArms" if randf() < 0.3 else "idle"))
					if s.s == "wait":
						s.until = now() + rnd(14, 34)
				return false
			var p: Dictionary = s.p
			if p.has("look"):
				NK.face(n, p.look.x, p.look.z, dt, 3)
			elif p.has("facing"):
				NK.turn(n, p.facing, 3, dt)
			if s.s == "fountain" and not V.showOn and not s.until:
				s.until = now() + rnd(1, 3)
			if s.until and now() > s.until:
				NK.free_points(n)
				s.at = false
				s.until = 0.0
				NK.set_base(n, "idle")
				strip_next(V, n)
		_:
			strip_next(V, n)
	return false


func strip_tick(V: Dictionary, dt: float) -> void:
	if not zone_active(V.zone):
		if V.on:
			V.on = false
			for n in V.extras:
				hide(n)
		return
	if not V.on:
		strip_activate(V)
	# tapis roulant : un passant trop loin du joueur repart de l'autre côté du champ
	V.scan -= dt
	if V.scan > 0:
		return
	V.scan = 0.5
	var px := player_on_strip()
	var lim := maxf(CFG.strip.despawn, float(NK.CFG.far) + 16)
	for n in V.extras:
		if n.lead != null or (n.hidden and n.vs.s != "off"):
			continue
		var away: bool = (n.x - px) * float(n.vs.get("dir", 0.0)) > 0
		if n.vs.s == "off" or (absf(n.x - px) > lim and away and not n.visible and n.vs.s != "cross"):
			strip_spawn(V, n, px, false)


# ==================================================================================================
# 5. Le concert : musiciens sur les points stage, public sur les points dance
# ==================================================================================================
const LOOK := {
	"chant": {"tpl": ["woman-dress", "real-casual-woman"], "tint": {"top": "#c2185b", "hair": "#0f0d0c", "by": {"Dress": "#c2185b"}}},
	"guitare": {"tpl": ["man-tshirt", "real-punk-man"], "tint": {"top": "#15151a", "bottom": "#2a2a33", "hair": "#2a1a10"}},
	"basse": {"tpl": ["real-punk-man", "man-blond"], "tint": {"top": "#5a1a24", "bottom": "#15151a"}},
	"batterie": {"tpl": ["real-hoodie-man", "man-longsleeves"], "tint": {"top": "#202838", "bottom": "#15151a"}},
	"claviers": {"tpl": ["woman-punk", "woman-tanktop"], "tint": {"top": "#3de0e0", "bottom": "#15151a"}},
	"choeurs": {"tpl": ["woman-casual", "real-casual-woman", "woman-tanktop"], "tint": {"top": "#d9a441", "bottom": "#15151a"}},
}

func setup_concert():
	if CO.is_empty() or not NK.M.zone_par_id.has("F-CONCERT"):
		return null
	var stage: Array = NK.pts("stage").filter(func(p): return has_tag(p, "concert"))
	var dance: Array = NK.pts("dance").filter(func(p): return has_tag(p, "concert"))
	var V := {"id": "concert", "zones": ["F-CONCERT", "F-CONCERT-SAS", "F-SCENE"], "extras": [], "musicians": [], "dancers": [], "dance": dance, "stage": stage, "on": false,
		"center": Vector2(22, -46), "bar": 0, "lastState": CO.state, "lastSong": CO.index}
	for p in stage:
		var role: String = p.get("role", p.tags[0] if p.has("tags") and p.tags.size() else "choeurs")
		var lk: Dictionary = LOOK.get(role, LOOK.choeurs)
		var n := create("musicien", V, {"tpl": lk.tpl, "tint": lk.tint, "level": float(p.level), "x": p.x, "z": p.z, "yaw": float(p.get("facing", PI))})
		n.part = role
		n.spot = p
		n.vstep = musician_step
		V.musicians.append(n)
	for i in CFG.concert.dancers:
		var n := create("danseur", V)
		n.vstep = dancer_step
		V.dancers.append(n)
	V.swap = swapper(V, ["F-CONCERT"], CFG.concert.proxies, func(n, _it):
		if n.seatState == null:
			dance_start(n, pick(["bounce", "clip", "arms", "clap"]))
		else:
			NK.set_base(n, "idle"))
	for n in V.swap.pool:
		n.vstep = proxy_step
	return V


func concert_active(V: Dictionary) -> bool:
	for id in V.zones:
		if zone_active(id):
			return true
	return false


func concert_activate(V: Dictionary) -> void:
	V.on = true
	for n in V.musicians:
		musician_place(V, n)
	# le public est déjà là : posé directement sur des points de danse libres (les plus proches de la scène d'abord)
	var pp := joueur_pos()
	var free: Array = V.dance.filter(func(p): return libre(p) and Vector2(p.x - pp.x, p.z - pp.z).length() > 1.4)
	for p in free:
		p["_tri"] = p.z + rnd(-3, 3)
	free.sort_custom(func(a, b): return a._tri < b._tri)
	for i in V.dancers.size():
		var n: Dictionary = V.dancers[i]
		if n.vs.s != "off" and not n.hidden:
			continue
		if i >= free.size():
			continue
		var p: Dictionary = free[i]
		if not NK.take_point(n, p):
			continue
		still(n)
		n.hidden = false
		set_level(n, 0.0)
		n.x = p.x + rnd(-0.15, 0.15)
		n.z = p.z + rnd(-0.15, 0.15)
		n.yaw = float(p.get("facing", 0.0))
		n.vs = {"s": "dance", "p": p, "songs": irnd(2, 5), "leaveAt": 0.0}
		dance_start(n)


func concert_song(V: Dictionary) -> void:
	for n in V.dancers:
		if n.vs.s == "dance" and n.get("dance") != null:
			n.vs.songs -= 1
			dance_base(n)
		elif n.vs.s == "resting" or n.vs.s == "rest":
			n.vs.rest -= 1
	for n in V.swap.pool:
		if n.get("dance") != null:
			dance_base(n)
	for n in NK.clients:
		if n.beh != null and n.beh.type == "concert" and n.get("dance") != null:
			n.beh.songs -= 1
			dance_base(n)
	for n in V.musicians:
		n.vs.wave = false
		NK.set_base(n, "talk" if n.part == "chant" else "idle")


## L'entracte : applaudissements, une partie du public va au bar ou s'assoit, les musiciens saluent.
func concert_break(V: Dictionary) -> void:
	var k := [0]
	var clap_now := func(n):
		if n.hidden or (n.seatState != null and n.seatState != "seated"):
			return
		k[0] += 1
		NK.set_base(n, "idle", 0.2)
		NK.gesture(n, "clap" if randf() < 0.7 else "yes", rnd(2.5, 5))
	for n in V.dancers:
		if n.vs.s != "dance":
			continue
		clap_now.call(n)
		if n.vs.songs <= 0 or randf() < 0.18:
			n.vs.leaveAt = now() + rnd(2.5, 5)
	for n in V.swap.pool:
		if n.proxyOf != null and n.seatState == null:
			clap_now.call(n)
	for n in NK.clients:
		if n.beh != null and n.beh.type == "concert" and n.beh.phase == 1:
			clap_now.call(n)
	for n in V.musicians:
		if n.part == "chant":
			NK.set_base(n, "idle")
			NK.gesture(n, "wave", 2.5)
			NK.say(n, pick(["Merci Las Vegas !", "Vous êtes incroyables !", "Merci, merci !", "On continue ?"]))
		elif randf() < 0.5:
			NK.gesture(n, "wave", 2)
	if k[0]:
		stat.acclamations += 1
		emit("pnj:acclamation", {"lieu": "concert", "x": V.center.x, "y": 1.6, "z": V.center.y, "force": clampf(k[0] / 20.0, 0.3, 1), "count": k[0]})


func musician_place(_V: Dictionary, n: Dictionary) -> void:
	var p: Dictionary = n.spot
	still(n)
	n.hidden = false
	set_level(n, float(p.level))
	n.x = p.x
	n.z = p.z
	n.yaw = float(p.get("facing", PI))
	if p.get("sit", false):
		var f := fake_seat(p.x, p.z, float(p.get("facing", PI)), float(p.get("seatHeight", 0.58)), 0.0)
		sit_now(n, f.st, f.seat)
		set_level(n, float(p.level))
	if not n.gear:
		n.gear = true
		match n.part:
			"guitare": wear_guitar(n, false, "#b3121f")
			"basse": wear_guitar(n, true, "#1f2c44")
			"chant": acc(n, hand(n, "R"), 0x15151a, 1.1, [0.045, 0.2, 0.045])
			"batterie":
				acc(n, hand(n, "R"), 0xd8c49a, 1.15, [0.02, 0.42, 0.02])
				acc(n, hand(n, "L"), 0xd8c49a, 1.15, [0.02, 0.42, 0.02])
	n.vs = {"s": "play", "wave": false}
	NK.set_base(n, "talk" if n.part == "chant" else "idle")
	n.pose = musician_pose
	n.anim = musician_anim


func musician_anim(n: Dictionary, _dt: float) -> void:
	var on: bool = CO.state == "morceau" and CO.playing
	var ballad: bool = CO.song.style == "ballade"
	var inner: Node3D = n.corps.inner
	if not on:
		inner.rotation.z *= 0.9
		return
	if n.part == "batterie":
		return
	var hop := 0.035 if n.part == "chant" or n.part == "choeurs" else 0.018
	inner.position.y += pow(maxf(0.0, sin(CO.phase * TAU)), 2) * hop * (0.4 + CO.energy) * (0.3 if ballad else 1.0)
	inner.rotation.z = sin(CO.beatPos * PI) * (0.07 if n.part == "choeurs" else 0.035) * (1.5 if ballad else 1.0)


func musician_pose(n: Dictionary) -> void:
	var on: bool = CO.state == "morceau" and CO.playing
	var ph: float = CO.phase
	var bp: float = CO.beatPos
	var e: float = CO.energy
	if n.gest != null:
		return
	match n.part:
		"guitare", "basse":
			var bass: bool = n.part == "basse"
			var strum := sin(bp * (1.0 if bass else 2.0) * TAU) if on else 0.0
			arm(n, "L", [0.3, -0.66, 0.6], [0.92 if bass else 0.82, -0.08, 0.5], 1)
			arm(n, "R", [0.18, -0.86, 0.38], [-0.72, -0.28 + strum * 0.28, 0.58], 1)
			n.lookPitchT = 0.18 + maxf(0.0, sin(ph * TAU)) * 0.12 * e if on else 0.1
			n.lookPitch = n.lookPitchT
		"chant":
			pose_mic(n, 1)
			if on and e > 0.9 and int(floorf(bp / 8)) % 2:
				arm(n, "L", [0.45, 0.6, 0.55], [0.25, 0.9, 0.35], 1)
		"claviers":
			var j := sin(bp * PI) * 0.12 if on else 0.0
			var press := absf(sin(bp * 2 * TAU)) * 0.06 if on else 0.0
			arm(n, "L", [0.16, -0.78, 0.52], [-0.12 - j, -0.32 - press, 0.95], 1)
			arm(n, "R", [0.16, -0.78, 0.52], [-0.12 + j, -0.32 - press, 0.95], 1)
			n.lookPitchT = 0.25 + maxf(0.0, sin(ph * TAU)) * 0.08 if on else 0.15
			n.lookPitch = n.lookPitchT
		"batterie":
			var f8 := fmod(bp * 2, 1.0)
			var b4 := int(floorf(bp)) % 2
			var fb := fmod(bp, 1.0)
			var hh := sin(f8 * PI) if on else 0.3
			var sn := (sin(fb * PI) if b4 else 0.25 + 0.15 * sin(fb * PI)) if on else 0.3
			arm(n, "R", [0.38, -0.6, 0.62], [-0.12, -0.32 + hh * 0.42 * (0.6 + e * 0.6), 0.9], 1)
			arm(n, "L", [0.34, -0.62, 0.6], [-0.38, -0.36 + sn * 0.5 * (0.6 + e * 0.6), 0.9], 1)
			n.lookPitchT = 0.15 + pow(maxf(0.0, sin(ph * TAU)), 2) * 0.22 if on else 0.08
			n.lookPitch = n.lookPitchT
		_:
			if on and e > 0.75:
				pose_clap(n, 1, absf(sin(ph * PI)))


func musician_step(n: Dictionary, _b: Dictionary, dt: float) -> bool:
	var V: Dictionary = n.venue
	if not V.on:
		if not n.hidden:
			hide(n)
		return false
	if n.hidden or n.vs.s != "play":
		musician_place(V, n)
		return false
	if n.seatState == null:
		n.x += (n.spot.x - n.x) * minf(1.0, dt * 4)
		n.z += (n.spot.z - n.z) * minf(1.0, dt * 4)
		NK.turn(n, float(n.spot.get("facing", PI)), 3, dt)
	return false


## Un danseur figurant : point de danse ↔ bar ou gradins pendant les entractes.
func dancer_step(n: Dictionary, _b: Dictionary, dt: float) -> bool:
	var V: Dictionary = n.venue
	var s: Dictionary = n.vs
	if not V.on:
		if not n.hidden:
			hide(n)
		return false
	if n.hidden:
		var pp := joueur_pos()
		var p = null
		for q in V.dance:
			if libre(q) and Vector2(q.x - pp.x, q.z - pp.z).length() > 1.4:
				p = q
				break
		if p != null and NK.take_point(n, p):
			n.hidden = false
			set_level(n, 0.0)
			var nd = nearest(V.center.x + rnd(-6, 6), -38, 6, 0.0)
			if nd == null:
				nd = p
			n.x = nd.x
			n.z = nd.z
			n.vs = {"s": "goDance", "p": p, "songs": irnd(2, 4), "leaveAt": 0.0}
			NK.go_to(n, p)
		return false
	match s.s:
		"goDance":
			var r: String = NK.step_nav(n, dt)
			if r == "fail":
				failed("danse")
				NK.free_points(n)
				hide(n)
				return false
			if r == "done":
				arrived("danse")
				s.s = "dance"
				dance_start(n)
		"dance":
			var p: Dictionary = s.p
			NK.face(n, p.look.x if p.has("look") else V.center.x, p.look.z if p.has("look") else -60.0, dt, 3)
			if s.get("leaveAt", 0.0) and now() > s.leaveAt:
				s.leaveAt = 0.0
				still(n)
				NK.free_points(n)
				concert_rest(V, n)
		"rest":
			var r := seat_step_vie(n, dt)
			if r == "fail":
				s.s = "back"
				return false
			if r == "seated":
				arrived(s.what)
				s.s = "resting"
				if s.what == "bar":
					NK.gesture(n, "drink")
		"resting":
			s.drinkT = float(s.get("drinkT", rnd(5, 10))) - dt
			if s.drinkT <= 0:
				s.drinkT = rnd(6, 14)
				NK.gesture(n, "drink" if randf() < 0.6 else "talk", 2.5)
			if s.rest <= 0 and CO.state == "morceau":
				s.s = "standUp"
		"standUp":
			if stand_step(n, dt):
				s.s = "back"
		"back":
			for q in V.dance:
				if libre(q) and NK.take_point(n, q):
					s.s = "goDance"
					s.p = q
					s.songs = irnd(2, 4)
					NK.go_to(n, q)
					break
		_:
			s.s = "back"
	return false


func concert_rest(_V: Dictionary, n: Dictionary) -> void:
	var s: Dictionary = n.vs
	var sts: Array
	var re := RegEx.new()
	re.compile("^concert-mange-debout")
	if randf() < 0.6:
		sts = NK.M.stations.filter(func(st): return st.id == "concert-bar" or re.search(st.id) != null)
	else:
		sts = NK.M.stations.filter(func(st): return st.type == "seat" and has_tag(st, "concert") and not has_tag(st, "élevé"))
	sts = sts.filter(func(x): return NK.free_count(x) > 1)
	var st = pick(sts) if sts.size() else null
	var seat = NK.free_seat(st) if st != null else null
	if seat == null or not seat_go(n, st, seat):
		s.s = "back"
		return
	s.s = "rest"
	s.what = "bar" if st.id == "concert-bar" else ("mange-debout" if "mange" in st.id else "gradins")
	s.rest = irnd(1, 2)


func concert_tick(V: Dictionary, dt: float) -> void:
	if not concert_active(V):
		if V.on:
			V.on = false
			sw_release_all(V.swap)
			for n in V.extras:
				hide(n)
		return
	if not V.on:
		concert_activate(V)
	sw_tick(V.swap, dt)


# ==================================================================================================
# 6. L'arène : combat, arbitre, soigneurs, officiels, spectateurs
# ==================================================================================================
const ESTRADE := 0.2
const CORNER_IN := {"rouge": [-1.75, 128.75], "bleu": [1.75, 125.25]}
const PUNCH := {"punchJab": {"kind": "jab", "p": 0.55, "f": 0.4}, "punchCross": {"kind": "direct", "p": 0.45, "f": 0.7}, "hook": {"kind": "crochet", "p": 0.4, "f": 0.9}}

func ring_p(V: Dictionary, r: String):
	for p in V.ring:
		if p.get("role") == r:
			return p
	return null


func setup_arene():
	if AR.is_empty() or not NK.M.zone_par_id.has("F-ARENE-SALLE"):
		return null
	var V := {"id": "arene", "zones": ["F-ARENE-SALLE", "F-RING"], "extras": [], "on": false, "center": Vector2(0, 127), "spectators": [],
		"ring": NK.pts("ring"), "stool": {"rouge": NK.station("ring-tabouret-rouge"), "bleu": NK.station("ring-tabouret-bleu")},
		"fight": null, "lastState": "", "kd": null, "points": {"rouge": 0, "bleu": 0}, "hypeT": 0.0, "kdRound": 0, "winner": "", "verdictAt": 0.0,
		"officials": [], "corners": []}
	if ring_p(V, "rouge") == null or ring_p(V, "bleu") == null or ring_p(V, "arbitre") == null:
		push_warning("[vie] points du ring absents : pas de combat")
		return null
	var boxer := func(corner: String, color: String) -> Dictionary:
		var n := create("boxeur", V, {"tpl": ["man-tshirt", "man-blond", "real-casual-man"], "tint": {"top": "#c08a62" if corner == "rouge" else "#5a3a28", "bottom": color, "hair": "#0f0d0c", "skin": 1.0 if corner == "rouge" else 0.62}, "level": ESTRADE})
		n.corner = corner
		n.vstep = boxer_step
		n.color = color
		return n
	V.rouge = boxer.call("rouge", "#b3121f")
	V.bleu = boxer.call("bleu", "#1d3f8a")
	V.rouge.opp = V.bleu
	V.bleu.opp = V.rouge
	V.ref = create("arbitre", V, {"tpl": ["man-longsleeves", "man-suit", "man-blond"], "tint": {"top": "#ececec", "bottom": "#141414"}, "level": ESTRADE})
	V.ref.vstep = referee_step
	for c in ["rouge", "bleu"]:
		var p = ring_p(V, "soigneur-" + c)
		if p == null:
			continue
		var n := create("soigneur", V, {"tint": {"top": "#7a0e18" if c == "rouge" else "#1d3f8a", "bottom": "#1b1b20"}})
		n.corner = c
		n.home = p
		n.vstep = corner_step
		V.corners.append(n)
	# officiels (juges, chronométreur) si personne du personnel ne tient leur place
	if CFG.arene.officials:
		for id in ["arene-juge-ouest", "arene-juge-est", "arene-juge-nord", "arene-chronometreur"]:
			var st = NK.station(id)
			if st == null or st.seats.is_empty() or st.seats[0].occupant != null:
				continue
			var n := create("chronométreur" if "chrono" in id else "juge", V, {"tpl": ["man-suit", "dealer-businessman", "woman-dress"], "tint": {"top": "#1b1b22", "bottom": "#1b1b22"}})
			n.post = {"st": st, "seat": st.seats[0]}
			n.vstep = official_step
			V.officials.append(n)
			sit_now(n, st, st.seats[0])
			n.hidden = true
	for i in CFG.arene.spectators:
		var n := create("spectateur", V)
		n.vstep = spectator_step
		V.spectators.append(n)
	V.swap = swapper(V, ["F-ARENE-SALLE"], CFG.arene.proxies, func(n, _it):
		if n.seatState == null:
			NK.set_base(n, "foldArms" if randf() < 0.5 else "idle"))
	for n in V.swap.pool:
		n.vstep = proxy_step
	return V


func arene_active(V: Dictionary) -> bool:
	for id in V.zones:
		if zone_active(id):
			return true
	return false


func ring_pos(n: Dictionary, x: float, z: float, yaw: float) -> void:
	still(n)
	n.hidden = false
	set_level(n, ESTRADE)
	n.x = x
	n.z = z
	n.yaw = yaw


func arene_activate(V: Dictionary) -> void:
	V.on = true
	# boxeurs, arbitre, soigneurs : posés selon l'état du combat en cours
	for n in [V.rouge, V.bleu]:
		var p: Dictionary = ring_p(V, n.corner)
		ring_pos(n, p.x, p.z, yaw_to(V.center.x - p.x, V.center.y - p.z))
		n.vs = {"s": "corner"}
		boxer_kit(n)
	var pr: Dictionary = ring_p(V, "arbitre")
	ring_pos(V.ref, pr.x, pr.z, yaw_to(-pr.x, V.center.y - pr.z))
	V.ref.vs = {"s": "ref"}
	for n in V.corners:
		still(n)
		n.hidden = false
		set_level(n, 0.0)
		n.x = n.home.x
		n.z = n.home.z
		n.yaw = float(n.home.get("facing", 0.0))
		n.vs = {"s": "apron"}
	for n in V.officials:
		n.hidden = false
		n.vs = {"s": "sit"}
	# spectateurs : directement assis aux premiers rangs (bord de ring d'abord), en laissant des places libres
	var sts: Array = NK.M.stations.filter(func(s): return s.type == "seat" and has_tag(s, "boxe") and float(s.get("level", 0.0)) == 0.0)
	sts.sort_custom(func(a, b):
		var ra := 1 if has_tag(a, "ringside") else 0
		var rb := 1 if has_tag(b, "ringside") else 0
		if ra != rb:
			return ra > rb
		return Vector2(a.position.x, a.position.z - 127).length() < Vector2(b.position.x, b.position.z - 127).length())
	var k := 0
	for s in sts:
		var cap := floori(s.seats.size() * 0.6)
		var used: int = NK.npc_count(s)
		for seat in s.seats:
			if k >= V.spectators.size() or used >= cap or seat.occupant != null or randf() < 0.3:
				continue
			var n: Dictionary = V.spectators[k]
			if not n.hidden and n.seatState != null:
				k += 1
				continue
			still(n)
			n.hidden = false
			if sit_now(n, s, seat):
				n.vs = {"s": "watch", "fidget": rnd(3, 12)}
				used += 1
				k += 1
	while k < V.spectators.size():
		hide(V.spectators[k])
		k += 1
	V.lastState = ""
	arene_state(V, AR.state, true)


func boxer_kit(n: Dictionary) -> void:
	if n.kit:
		return
	n.kit = true
	var c := 0xb3121f if n.corner == "rouge" else 0x1d3f8a
	for s in ["L", "R"]:
		acc(n, hand(n, s), c, 0.9, [0.12, 0.15, 0.13])


## Un changement d'état du combat (le pilote de l'arène).
func arene_state(V: Dictionary, state: String, snap := false) -> void:
	if state == "" or state == V.lastState:
		return
	V.lastState = state
	if state == "round":
		V.fight = {"ang": atan2(1, -1), "angV": rnd(-0.25, 0.25), "dist": 1.6, "cx": 0.0, "cz": 127.0, "nextEx": now() + rnd(1.5, 3), "clinch": 0.0, "inUntil": 0.0, "last10": false, "queue": []}
		for n in [V.rouge, V.bleu]:
			n.vs = {"s": "standUp" if n.seatState != null else "fight"}
		for n in V.corners:
			n.vs = {"s": "leave"}
		if AR.round == 1:
			V.points.rouge = 0
			V.points.bleu = 0
			V.kdRound = 0
		V.kd = null
	elif state == "repos":
		for n in [V.rouge, V.bleu]:
			if n.down:
				boxer_up(n)
			n.vs = {"s": "toStool"}
		for n in V.corners:
			n.vs = {"s": "toCorner"}
		hype_up(V, 0.5, "fin du round")
	elif state == "fin":
		for n in [V.rouge, V.bleu]:
			if n.down:
				boxer_up(n)
			n.vs = {"s": "standUp" if n.seatState != null else "verdict"}
		V.winner = pick(["rouge", "bleu"]) if V.points.rouge == V.points.bleu else ("rouge" if V.points.rouge > V.points.bleu else "bleu")
		V.verdictAt = now() + 6
		for n in V.corners:
			n.vs = {"s": "toCorner"}
	else:
		# attente : échauffement dans les coins
		for n in [V.rouge, V.bleu]:
			if n.down:
				boxer_up(n)
			n.vs = {"s": "standUp" if n.seatState != null else "warm"}
		for n in V.corners:
			n.vs = {"s": "leave"}
	if snap:
		for n in [V.rouge, V.bleu, V.ref]:
			n.snap = true


## Se déplacer sur le ring sans graphe de navigation (aire dégagée), en gardant la garde vers une cible.
func ring_move(n: Dictionary, tx: float, tz: float, dt: float, sp: float, look = null) -> float:
	var dx: float = tx - n.x
	var dz: float = tz - n.z
	var d := Vector2(dx, dz).length()
	var lim := 2.75
	if d > 0.02:
		var st := minf(d, sp * dt)
		n.x += dx / d * st
		n.z += dz / d * st
	n.x = clampf(n.x, -lim, lim)
	n.z = clampf(n.z, 127 - lim, 127 + lim)
	var facing: float = yaw_to(look.x - n.x, look.y - n.z) if look != null else (yaw_to(dx, dz) if d > 0.05 else n.yaw)
	NK.turn(n, facing, 6, dt)
	var along := absf(cos(yaw_to(dx, dz) - n.yaw)) if d > 0.05 else 0.0
	NK.set_move(n, "walk" if d > 0.35 and sp > 0.9 and along > 0.6 else null)
	return d


func boxer_anim(n: Dictionary, _dt: float) -> void:
	var V: Dictionary = n.venue
	if V.fight == null or n.seatState != null or n.down or (AR.state != "round" and AR.state != "attente"):
		return
	(n.corps.inner as Node3D).position.y += absf(sin(now() * 5.6 + (0.0 if n.corner == "rouge" else 1.3))) * 0.035


func boxer_pose(n: Dictionary) -> void:
	if n.down or n.seatState != null or n.gest != null:
		n.pw = 0.0
		return
	if n.vs.s == "win":
		pose_winner(n, 1)
		return
	if AR.state != "round" and AR.state != "attente" and n.vs.s != "warm":
		return
	n.pw = minf(1.0, n.pw + 0.25)
	pose_guard(n, n.pw)


func boxer_up(n: Dictionary) -> void:
	n.down = false
	n.downHeld = false
	n.hp = 3
	n.animKey = ""
	NK.gesture(n, "getup", 0, 0.2)


func boxer_step(n: Dictionary, _b: Dictionary, dt: float) -> bool:
	var V: Dictionary = n.venue
	var s: Dictionary = n.vs
	if not V.on:
		if not n.hidden:
			hide(n)
		return false
	if n.hidden:
		return false
	n.anim = boxer_anim
	n.pose = boxer_pose
	var stool = V.stool[n.corner]
	match s.s:
		"corner", "warm":
			var c: Array = CORNER_IN[n.corner]
			ring_move(n, c[0] + sin(now() * 0.7 + (0.0 if n.corner == "rouge" else 2.0)) * 0.35, c[1] + cos(now() * 0.5) * 0.3, dt, 0.5, Vector2(0, 127))
			s.t = float(s.get("t", rnd(1, 3))) - dt
			if s.t <= 0:
				s.t = rnd(1.6, 3.6)
				NK.gesture(n, pick(["punchJab", "punchJab", "punchCross", "hook"]), 0.7)
		"standUp":
			if stand_step(n, dt):
				s.s = "fight" if AR.state == "round" else ("verdict" if AR.state == "fin" else "warm")
		"toStool":
			if stool == null:
				s.s = "corner"
				return false
			if n.snap:
				n.snap = false
				sit_now(n, stool, stool.seats[0])
				s.s = "stool"
				return false
			if not s.has("sp"):
				if not seat_go(n, stool, stool.seats[0]):
					s.s = "corner"
					return false
			var r := seat_step_vie(n, dt)
			if r == "seated":
				s.s = "stool"
				arrived("tabouret")
			elif r == "fail":
				s.s = "corner"
		"stool":
			s.t = float(s.get("t", rnd(4, 9))) - dt
			if s.t <= 0:
				s.t = rnd(8, 16)
				NK.gesture(n, "drink" if randf() < 0.5 else "yes", 2)
		"fight":
			pass # piloté par fight_tick
		"verdict":
			var side := -0.75 if n.corner == "rouge" else 0.75
			ring_move(n, side, 127 + side * 0.1, dt, 0.9, Vector2(0, 140))
			if V.verdictAt and now() > V.verdictAt:
				V.verdictAt = 0.0
				var w: Dictionary = V.rouge if V.winner == "rouge" else V.bleu
				var l: Dictionary = w.opp
				w.vs.s = "win"
				l.vs.s = "lose"
				NK.set_base(l, "idle")
				l.lookPitchT = 0.45
				l.lookHold = 20.0
				NK.say(V.ref, "Vainqueur… " + str(AR[V.winner].court) + " !", 4)
				emit("pnj:boxe", {"phase": "victoire", "coin": V.winner, "nom": AR[V.winner].nom, "points": V.points.duplicate()})
				hype_up(V, 1, "victoire")
		"win", "lose":
			ring_move(n, -0.75 if n.corner == "rouge" else 0.75, 127, dt, 0.6, Vector2(0, 140))
		_:
			s.s = "corner"
	return false


## Le combat : un cercle autour d'un centre qui dérive, une distance qui respire, des échanges de 1 à 3 coups.
func fight_tick(V: Dictionary, dt: float) -> void:
	var f = V.fight
	var A: Dictionary = V.rouge
	var B: Dictionary = V.bleu
	if f == null or AR.state != "round":
		return
	var fighting := func(n): return n.vs.s == "fight" and n.seatState == null and not n.hidden
	if not fighting.call(A) or not fighting.call(B):
		for n in [A, B]:
			if n.vs.s == "fight" and n.seatState != null:
				n.vs.s = "standUp"
		return
	if V.kd != null:
		knockdown_tick(V, dt)
		return
	var t := now()
	f.ang += f.angV * dt
	if randf() < dt * 0.25:
		f.angV = rnd(-0.35, 0.35)
	f.cx += (sin(t * 0.13) * 0.7 - f.cx) * dt * 0.4
	f.cz += (127 + cos(t * 0.11) * 0.7 - f.cz) * dt * 0.4
	var want: float = 0.62 if f.clinch > t else (0.95 if f.inUntil > t else 1.45 + sin(t * 0.8) * 0.3)
	f.dist += (want - f.dist) * minf(1.0, dt * 3)
	var cx := cos(f.ang)
	var cz := sin(f.ang)
	ring_move(A, f.cx - cx * f.dist / 2, f.cz - cz * f.dist / 2, dt, 1.3, Vector2(B.x, B.z))
	ring_move(B, f.cx + cx * f.dist / 2, f.cz + cz * f.dist / 2, dt, 1.3, Vector2(A.x, A.z))
	# coups en attente : l'impact ~0,3 s après le départ du geste
	for i in range(f.queue.size() - 1, -1, -1):
		var q: Dictionary = f.queue[i]
		if t >= q.at:
			f.queue.remove_at(i)
			impact(V, q)
	if t >= f.nextEx and f.queue.is_empty():
		var att: Dictionary = A if randf() < 0.5 + (V.points.rouge - V.points.bleu) * -0.01 else B
		var def: Dictionary = att.opp
		var nb := irnd(1, 3)
		f.inUntil = t + nb * 0.5 + 0.4
		var tt := t + 0.15
		for k in nb:
			var key: String = pick(["punchJab", "punchJab", "punchCross"]) if k == 0 else pick(["punchJab", "punchCross", "hook", "hook"])
			f.queue.append({"start": tt, "at": tt + 0.3, "att": att, "def": def, "key": key, "go": false})
			tt += rnd(0.42, 0.6)
		f.nextEx = tt + rnd(0.8, 2.6)
		if randf() < 0.06:
			f.clinch = tt + 2.2
			f.nextEx = f.clinch + rnd(1, 2)
	for q in f.queue:
		if not q.go and t >= q.start:
			q.go = true
			if not q.att.down:
				NK.gesture(q.att, q.key, minf(0.75, NK.clip_dur(q.att, q.key)))
	# fin de round : les dix dernières secondes, la salle pousse
	if not f.last10 and AR.chrono < 10:
		f.last10 = true
		hype_up(V, 0.45, "dernières secondes")


func impact(V: Dictionary, q: Dictionary) -> void:
	var att: Dictionary = q.att
	var def: Dictionary = q.def
	var P: Dictionary = PUNCH.get(q.key, PUNCH.punchJab)
	if att.down or def.down:
		return
	var d := Vector2(att.x - def.x, att.z - def.z).length()
	var hit = d < 1.9 and randf() < P.p
	stat.coups += 1
	emit("pnj:coup", {"x": snappedf(def.x, 0.01), "y": level_y(ESTRADE) + 1.5, "z": snappedf(def.z, 0.01), "kind": P.kind, "force": snappedf(P.f * (1.0 if hit else 0.35), 0.01), "touche": hit, "coin": att.corner})
	if not hit:
		NK.lean_pulse(def, -0.18, 0.4)
		def.lookYawT = rnd(-0.5, 0.5)
		def.lookHold = 0.5
		return
	stat.touches += 1
	V.points[att.corner] += 1
	var dx: float = def.x - att.x
	var dz: float = def.z - att.z
	var l := Vector2(dx, dz).length()
	if l < 1e-6:
		l = 1.0
	def.x += dx / l * 0.12
	def.z += dz / l * 0.12
	if q.key != "punchJab" and AR.round >= 3 and not V.kdRound and randf() < 0.035:
		knockdown(V, def, att)
		return
	NK.gesture(def, ("knockback" if randf() < 0.5 else "hit") if q.key == "hook" else ("hitChest" if q.key == "punchCross" else "hit"), 0.6)
	if q.key == "hook" and randf() < 0.5:
		hype_up(V, 0.3, "crochet")


## Knock-down : la chute, l'adversaire au coin neutre, le compte de l'arbitre, relevé à 6-8.
func knockdown(V: Dictionary, def: Dictionary, att: Dictionary) -> void:
	stat.knockdowns += 1
	V.kdRound = AR.round
	def.down = true
	def.downHeld = false
	def.gest = null
	def.animKey = ""
	NK.set_move(def, null)
	NK.refresh_anim(def, 0.1)
	def.downT = now()
	V.kd = {"def": def, "att": att, "t": now(), "count": 0, "up": irnd(6, 8), "nextCount": now() + 1.2}
	emit("pnj:boxe", {"phase": "knockdown", "coin": def.corner, "x": snappedf(def.x, 0.01), "z": snappedf(def.z, 0.01)})
	hype_up(V, 1, "knock-down")


func knockdown_tick(V: Dictionary, dt: float) -> void:
	var k: Dictionary = V.kd
	var ref: Dictionary = V.ref
	var nx := 2.2 if k.att.corner == "rouge" else -2.2
	var nz := 124.8 if k.att.corner == "rouge" else 129.2
	ring_move(k.att, nx * 0.85, 127 + (nz - 127) * 0.85, dt, 1.2, Vector2(k.def.x, k.def.z))
	ring_move(ref, k.def.x + 0.9, k.def.z + 0.4, dt, 1.4, Vector2(k.def.x, k.def.z))
	if now() >= k.nextCount:
		k.count += 1
		k.nextCount = now() + 1
		NK.say(ref, str(k.count) + " !", 0.9)
		NK.gesture(ref, "interact", 0.8)
		emit("pnj:boxe", {"phase": "compte", "n": k.count, "coin": k.def.corner})
		if k.count >= k.up:
			boxer_up(k.def)
			emit("pnj:boxe", {"phase": "debout", "coin": k.def.corner})
			hype_up(V, 0.7, "relevé")
			V.kd = null
			V.fight.nextEx = now() + 2.5


func referee_step(n: Dictionary, _b: Dictionary, dt: float) -> bool:
	var V: Dictionary = n.venue
	var f = V.fight
	if not V.on:
		if not n.hidden:
			hide(n)
		return false
	if n.hidden or V.kd != null:
		return false
	var A: Dictionary = V.rouge
	var B: Dictionary = V.bleu
	if AR.state == "round" and f != null and A.vs.s == "fight" and B.vs.s == "fight":
		var mx: float = (A.x + B.x) / 2
		var mz: float = (A.z + B.z) / 2
		var ax: float = B.x - A.x
		var az: float = B.z - A.z
		var l := Vector2(ax, az).length()
		if l < 1e-6:
			l = 1.0
		var px := -az / l
		var pz := ax / l
		if pow(mx + px * 1.7, 2) + pow(mz + pz * 1.7 - 127, 2) > pow(mx - px * 1.7, 2) + pow(mz - pz * 1.7 - 127, 2):
			px = -px
			pz = -pz
		var close: bool = f.clinch > now()
		ring_move(n, mx + px * (0.55 if close else 1.7), mz + pz * (0.55 if close else 1.7), dt, 1.6 if close else 1.0, Vector2(mx, mz))
		if close and not n.vs.get("broke", false):
			n.vs.broke = true
			NK.say(n, "Break !", 1.2)
			NK.gesture(n, "interact", 0.8)
		if not close:
			n.vs.broke = false
	elif AR.state == "fin":
		ring_move(n, 0, 127.6, dt, 1, Vector2(0, 140))
		if (V.rouge.vs.s == "win" or V.bleu.vs.s == "win") and n.vs.get("raise", "") != V.winner:
			n.vs.raise = V.winner
			n.pose = ref_pose
	else:
		var p = {"x": 0.0, "z": 127.0} if AR.state == "attente" else ring_p(V, "arbitre")
		ring_move(n, p.x, p.z, dt, 0.9, Vector2(0, 127))
		n.pose = null
	return false


func ref_pose(n: Dictionary) -> void:
	var V: Dictionary = n.venue
	if AR.state != "fin":
		n.pose = null
		return
	var w: Dictionary = V.rouge if V.winner == "rouge" else V.bleu
	var side := "L" if ((w.x - n.x) * cos(n.yaw) - (w.z - n.z) * sin(n.yaw)) > 0 else "R"
	arm(n, side, [0.4, 0.9, 0.1], [0.15, 1, 0.05], 1)


## Les soigneurs : sur le tablier pendant le round, dans le coin (par les marches) pendant la minute de repos.
func corner_step(n: Dictionary, _b: Dictionary, dt: float) -> bool:
	var V: Dictionary = n.venue
	var s: Dictionary = n.vs
	if not V.on:
		if not n.hidden:
			hide(n)
		return false
	if n.hidden:
		return false
	var stool = V.stool[n.corner]
	var sp = stool.seats[0] if stool != null else null
	match s.s:
		"toCorner":
			if sp == null:
				s.s = "apron"
				return false
			if not s.has("go"):
				var cx: float = sp.position.x * 0.78
				var cz: float = 127 + (sp.position.z - 127) * 0.78
				s.go = {"x": cx + (0.45 if n.corner == "rouge" else -0.45), "z": cz}
				NK.go_to(n, {"x": s.go.x, "z": s.go.z, "level": ESTRADE}, {"urgent": true})
			var r: String = NK.step_nav(n, dt)
			if r == "done":
				s.s = "tend"
				arrived("coin")
			elif r == "fail":
				failed("coin")
				s.s = "apron"
		"tend":
			var bx: Dictionary = V[n.corner]
			NK.face(n, bx.x, bx.z, dt, 4)
			s.t = float(s.get("t", 0.5)) - dt
			if s.t <= 0:
				s.t = rnd(2.5, 5)
				NK.gesture(n, pick(["talk", "interact", "talk", "yes"]), 2.4)
				if randf() < 0.3:
					NK.say(n, pick(["Garde haute !", "Travaille au corps !", "Respire…", "Son crochet gauche, attention !", "Encore trois rounds comme ça !"]), 2.2)
		"leave":
			if n.level == 0.0 and Vector2(n.x - n.home.x, n.z - n.home.z).length() < 0.4:
				s.s = "apron"
				return false
			if not s.has("go"):
				s.go = true
				NK.go_to(n, n.home, {"urgent": true})
			var r: String = NK.step_nav(n, dt)
			if r == "done":
				s.s = "apron"
			elif r == "fail":
				failed("tablier")
				n.x = n.home.x
				n.z = n.home.z
				set_level(n, 0.0)
				s.s = "apron"
		_:
			# au pied du coin, on encourage
			if n.home.has("look"):
				NK.face(n, V[n.corner].x, V[n.corner].z, dt, 3)
			s.t = float(s.get("t", rnd(2, 5))) - dt
			if s.t <= 0:
				s.t = rnd(3, 7)
				if AR.state == "round":
					NK.gesture(n, "railCall", 2.2)
					if randf() < 0.35:
						NK.say(n, pick(["Allez !", "Le jab !", "Bouge !", "Ta garde !"]), 1.4)
				else:
					NK.set_base(n, "foldArms" if randf() < 0.5 else "idle")
	return false


func official_step(n: Dictionary, _b: Dictionary, dt: float) -> bool:
	var V: Dictionary = n.venue
	if not V.on:
		if not n.hidden:
			n.hidden = true
		return false
	if n.hidden:
		n.hidden = false
	if n.seatState == null:
		var p: Dictionary = n.post
		if p.seat.occupant != null and p.seat.occupant != n.id:
			return false
		if not sit_now(n, p.st, p.seat):
			return false
	n.vs.g = float(n.vs.get("g", rnd(1, 3))) - dt
	if n.vs.g <= 0:
		n.vs.g = rnd(1.5, 4)
		var t: Dictionary = V.rouge if AR.state == "round" else V.ref
		NK.look_at_(n, t.x, t.z, -0.05, 3)
		if "juge" in n.role and AR.state == "repos" and randf() < 0.5:
			NK.gesture(n, "interact", 1.5)
	return false


## Les spectateurs figurants : assis, le regard vers l'action, des gestes, debout aux temps forts.
func spectator_step(n: Dictionary, _b: Dictionary, dt: float) -> bool:
	var V: Dictionary = n.venue
	var s: Dictionary = n.vs
	if not V.on:
		if not n.hidden:
			hide(n)
		return false
	if n.hidden:
		return false
	if n.seatState == null:
		# chassé de sa place (coup du joueur) : il ne revient qu'à la prochaine ouverture
		hide(n)
		return false
	if n.seatState == "cheer" or n.get("cheer") != null:
		cheer_step(n, dt)
		return false
	s.fidget = float(s.get("fidget", 5.0)) - dt
	if s.fidget <= 0:
		s.fidget = rnd(4, 14)
		var r := randf()
		if AR.state == "round":
			var t: Dictionary = V.rouge if randf() < 0.5 else V.bleu
			NK.look_at_(n, t.x, t.z, -0.15, 3)
			if r < 0.15:
				NK.gesture(n, "clap", 1.5)
			elif r < 0.25:
				NK.gesture(n, "yes" if randf() < 0.5 else "no", 1.5)
		elif r < 0.3:
			NK.gesture(n, "talk" if randf() < 0.5 else "drink", 2.5)
		elif r < 0.4:
			NK.set_base(n, "phone")
		else:
			NK.set_base(n, "idle")
	return false


## Les temps forts : une part de la salle se lève (figurants), tout le monde réagit.
func hype_up(V: Dictionary, force: float, why: String) -> void:
	var T := now()
	if V.hypeT and T - V.hypeT < 1.2 and force < 0.9:
		return
	V.hypeT = T
	var k := 0
	var share := clampf(force, 0.15, 1)
	for n in V.spectators + V.swap.pool:
		if n.hidden or n.seatState == null:
			continue
		if n.seatState == "seated" and randf() < share * 0.8:
			if cheer_start(n, rnd(2.5, 5) + force * 3):
				k += 1
		elif n.seatState == "seated" and randf() < 0.5:
			NK.gesture(n, "clap", 1.6)
			k += 1
	for n in NK.clients:
		if n.seatState == "seated" and n.station != null and has_tag(n.station, "boxe") and randf() < 0.7:
			NK.gesture(n, "clap" if randf() < 0.6 else "railCall", 1.8)
			k += 1
	if k:
		stat.acclamations += 1
		emit("pnj:acclamation", {"lieu": "arene", "x": 0, "y": 2, "z": 127, "force": snappedf(clampf(force, 0.1, 1), 0.01), "count": k, "why": why})


func arene_tick(V: Dictionary, dt: float) -> void:
	if not arene_active(V):
		if V.on:
			V.on = false
			sw_release_all(V.swap)
			for n in V.extras:
				if n.post != null:
					n.hidden = true
					continue
				hide(n)
		return
	if not V.on:
		arene_activate(V)
	if AR.state != V.lastState:
		arene_state(V, AR.state)
	fight_tick(V, dt)
	sw_tick(V.swap, dt)


# ==================================================================================================
# 7. Les clients : nouvelles destinations (danser au concert, voir la boxe, les fontaines)
# ==================================================================================================
func decide_hook(n: Dictionary, add: Callable) -> void:
	var N: Dictionary = n.needs
	var T: Dictionary = n.T
	var k: float = CFG.clientVenues
	if not k or n.retire:
		return
	var dist := func(x: float, z: float) -> float: return 1.0 / (1.0 + Vector2(n.x - x, n.z - z).length() / 70.0)
	var Vc = venues.get("concert")
	var Va = venues.get("arene")
	var Vs = venues.get("strip")
	# portage : un lieu encore fermé au joueur (seuils de Smarves) l'est aussi aux clients
	if "concert" in NK.lieux_fermes:
		Vc = null
	if "arene" in NK.lieux_fermes:
		Va = null
	if Vc != null and CO.playing and n.level == 0.0:
		add.call("concert", k * (N.social * 0.6 + N.curiosity * 0.5) * (0.6 + T.social * 0.35 + (0.7 if n.temper == "fetard" else 0.0)) * dist.call(22, -46), func(): return start_concert(n))
	if Va != null and n.level == 0.0:
		add.call("boxe", k * N.curiosity * (0.55 + T.watch * 0.3 + n.heat * 0.5) * dist.call(0, 120), func():
			return NK.use_station(n, NK.choose_of(n, "relax", func(st): return st.type == "seat" and has_tag(st, "boxe") and NK.free_count(st) > 2), {"stay": rnd(150, 300)}))
	if Vs != null and FONT != null and (FONT.en_cours or FONT.prochain < 25) and n.level == 0.0 and Vector2(n.x, n.z - 40).length() < 70:
		add.call("fontaines", k * N.curiosity * 1.1, func(): return go_fountain(n))


func go_fountain(n: Dictionary) -> bool:
	var V = venues.get("strip")
	if V == null:
		return false
	var pts: Array = V.fountain.filter(func(p): return libre(p))
	if pts.is_empty():
		return false
	pts.sort_custom(func(a, b): return Vector2(a.x - n.x, a.z - n.z).length() < Vector2(b.x - n.x, b.z - n.z).length())
	var p: Dictionary = pts[mini(pts.size() - 1, irnd(0, 2))]
	if not NK.take_point(n, p):
		return false
	NK.set_beh(n, "spot", {"p": p, "kind": "watch"})
	return true


func start_concert(n: Dictionary) -> bool:
	var V = venues.get("concert")
	if V == null:
		return false
	var pts: Array = V.dance.filter(func(p): return libre(p))
	if pts.is_empty():
		return false
	var p: Dictionary = pick(pts.slice(0, maxi(1, floori(pts.size() * 0.6))))
	if not NK.take_point(n, p):
		return false
	NK.set_beh(n, "concert", {"p": p, "songs": irnd(1, 3), "breakSeen": false})
	return true


# ==================================================================================================
# 8. Démarrage, comportements enregistrés, boucle, état
# ==================================================================================================
func register_beh() -> void:
	NK._beh("vie", null,
		func(n, b, dt): return n.vstep.call(n, b, dt) if n.get("vstep") != null else false,
		func(n, _b):
			if n.seatState == "cheer":
				n.seatState = "seated"
				n.cheer = null
				n.sitK = 1.0
			if n.get("lead") != null or n.get("mate") != null:
				n.follow = null
			n.anim = null
			n.pose = null
			n.dance = null
			(n.corps.inner as Node3D).rotation.z = 0.0
			n.vs = {"s": "proxy" if n.get("proxy", false) else "off", "back": true})
	# le client au concert : y aller, danser 1 à 3 morceaux, parfois le bar à l'entracte
	NK._beh("concert",
		func(n, b):
			NK.go_to(n, b.p)
			NK.note("concert"),
		func(n, b, dt):
			if b.phase == 0:
				var r: String = NK.step_nav(n, dt)
				if r == "fail":
					failed("client concert")
					return true
				if r == "done":
					arrived("client concert")
					b.phase = 1
					b.t = 0.0
					dance_start(n)
				return b.t > 240
			var p: Dictionary = b.p
			NK.face(n, p.look.x if p.has("look") else 22.0, p.look.z if p.has("look") else -60.0, dt, 3)
			n.needs.social = maxf(0.0, n.needs.social - dt / 60)
			n.needs.curiosity = maxf(0.0, n.needs.curiosity - dt / 80)
			n.needs.fatigue += dt / 900
			n.mood = minf(1.0, n.mood + dt / 400)
			if CO.state == "entracte" and not b.breakSeen:
				b.breakSeen = true
				if b.songs <= 0 or randf() < 0.3:
					var bar = NK.choose_of(n, "drink", func(st): return st.id == "concert-bar")
					if bar != null and n.needs.thirst > 0.2 and NK.use_station(n, bar, {"stay": rnd(40, 90)}):
						return false
					return true
			if CO.state == "morceau":
				b.breakSeen = false
			return b.t > 900,
		func(n, _b):
			n.anim = null
			n.pose = null
			n.dance = null
			(n.corps.inner as Node3D).rotation.z = 0.0
			n.corps.vitesses.clear()
			NK.set_base(n, "idle"))


func start() -> void:
	register_beh()
	var t0 := Time.get_ticks_usec()
	for k in ["strip", "concert", "arene"]:
		var V = call("setup_" + k)
		if V != null:
			venues[k] = V
	buildMs = (Time.get_ticks_usec() - t0) / 1000.0


var buildMs := 0.0


## Les évènements des pilotes du lot F (C.bus de l'original).
func _bus(nom: String, _d: Dictionary) -> void:
	match nom:
		"concert:song":
			if venues.has("concert") and venues.concert.on:
				concert_song(venues.concert)
		"concert:entracte":
			if venues.has("concert") and venues.concert.on:
				concert_break(venues.concert)
		"concert:beat":
			if venues.has("concert") and venues.concert.on and int(_d.get("bar", 1)) == 0:
				venues.concert.bar += 1
		"boxe:round":
			if venues.has("arene") and venues.arene.on:
				arene_state(venues.arene, str(_d.get("state", "")))
		"boxe:bell":
			if venues.has("arene") and venues.arene.on:
				var V: Dictionary = venues.arene
				for o in V.officials:
					if "chrono" in o.role:
						NK.gesture(o, "interact", 1)
						break
				hype_up(V, 0.6, "cloche")


func tick(dt: float) -> void:
	# les fontaines (« strip:fontaines ») : le spectacle commence ou finit
	if FONT != null and venues.has("strip"):
		var on: bool = FONT.en_cours
		if on != _fontaines_vu:
			_fontaines_vu = on
			var V: Dictionary = venues.strip
			V.showOn = on
			if V.on:
				if on:
					fountain_call(V)
				else:
					fountain_end(V)
	if venues.has("strip"):
		strip_tick(venues.strip, dt)
	if venues.has("concert"):
		concert_tick(venues.concert, dt)
	if venues.has("arene"):
		arene_tick(venues.arene, dt)


func stats() -> Dictionary:
	var by := {}
	var shown := 0
	var vis := 0
	for n in extras:
		if not n.hidden:
			shown += 1
			by[n.role] = int(by.get(n.role, 0)) + 1
		if n.visible:
			vis += 1
	var cl := {}
	for n in NK.clients:
		var b = n.beh
		if b == null:
			continue
		var k = null
		if b.type == "concert":
			k = "concert"
		elif b.type == "use" and has_tag(b.get("st"), "boxe"):
			k = "boxe"
		elif b.type == "spot" and has_tag(b.get("p"), "fontaines"):
			k = "fontaines"
		if k != null:
			cl[k] = int(cl.get(k, 0)) + 1
	var vl := []
	for k in venues:
		var V: Dictionary = venues[k]
		vl.append({"id": k, "on": V.on, "swapped": V.swap.active if V.has("swap") else 0, "imposteurs": V.swap.list.size() if V.has("swap") else 0})
	return {"extras": extras.size(), "shown": shown, "visible": vis, "byRole": by, "clients": cl, "venues": vl,
		"arene": {"state": AR.state, "round": AR.round, "points": venues.arene.points.duplicate(), "kd": venues.arene.kd != null} if venues.has("arene") else null,
		"concert": {"state": CO.state, "song": CO.song.titre} if venues.has("concert") else null,
		"stat": stat.duplicate(true), "buildMs": buildMs}


## Essais : un knock-down tout de suite.
func test_knockdown() -> bool:
	var V = venues.get("arene")
	if V == null or AR.state != "round":
		return false
	knockdown(V, V.bleu, V.rouge)
	return true
