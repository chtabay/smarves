extends RefCounted
## Le corps d'un PNJ et son animation, comme js/npc.js (sections 2 et 3) : une pose de base (idle, talk, phone,
## cower…), une allure (walk, run, carry) et un geste ponctuel ; assis, le bas du corps tient l'assise et le haut
## joue le geste (découpe par os). Les clés courtes se résolvent par le gabarit exporté de l'original
## (donnees/pnj_monde.json : templates[].names), avec ses replis (FALLBACKS). La tête et le buste se tournent
## par-dessus le clip (applyBone). Un PNJ non affiché ne fait tourner aucun lecteur : la simulation ne dépend
## jamais de l'état d'une animation.

const PERSONNAGES := "res://communes/casino_minuit/personnages.gd"

const FALLBACKS := {"clap": ["yes", "interact"], "leanRail": ["idle"], "foldArms": ["idle"], "cower": ["idle"], "carry": ["walk"], "run": ["walk"], "railCall": ["wave", "interact"], "phone": ["talk", "idle"],
	"eat": ["interact"], "drink": ["eat", "interact"], "talk": ["interact", "idle"], "sitTalk": ["talk"], "hit": ["hitChest", "idle"], "hitChest": ["hit"], "knockback": ["hit", "hitChest"], "punch": ["punchJab"], "punchJab": ["punch"], "punchCross": ["punch"],
	"hook": ["punch"], "kick": ["punch"], "kickLeft": ["kick", "punch"], "fall": ["death"], "getup": ["idle"], "yes": ["idle"], "no": ["idle"], "wave": ["interact", "idle"], "interact": ["wave", "idle"], "throw": ["punchJab", "interact"], "fixKneel": ["interact", "idle"],
	"dance": ["clap", "idle"], "pickUpTable": ["interact"], "stand": ["idle"]}
const ONCE := {"sitNative": 1, "sitNative#bas": 1, "fall": 1, "death": 1}
const SIT_UPPER := {"talk": 1, "eat": 1, "drink": 1, "phone": 1, "clap": 1, "interact": 1, "yes": 1, "no": 1, "foldArms": 1, "wave": 1, "railCall": 1}
const FADE := 0.25
## Les os du haut du corps (RE_UPPER de npc.js).
const HAUT := ["Neck", "Head", "Shoulder", "UpperArm", "LowerArm", "Palm", "MiddleHand", "Fingers", "Thumb", "Wrist", "Index", "Middle", "Ring", "Pinky"]

## Le gabarit d'un modèle (voir Corps.gabarit).
static func gabarit(t: Dictionary) -> Dictionary:
	return Corps.gabarit(t)


## Un corps : le modèle Quaternius du gabarit aux teintes données, deux lecteurs (le corps entier ou le bas ;
## le haut quand il est découpé), réglés à la main (cadence selon la distance).
class Corps:
	var g: Dictionary
	var root: Node3D
	var inner: Node3D
	var a: AnimationPlayer
	var b: AnimationPlayer
	var sk: Skeleton3D
	var ka := ""
	var kb := ""
	var head := {}
	var torso := {}

	## Les gabarits : nom → { données exportées, lib (AnimationLibrary propre au gabarit : clés courtes), clips (clé → Animation | null), res }
	static var gabarits := {}


	## Le gabarit d'un modèle, ses clips sous leurs clés courtes (et leurs découpes « #haut », « #bas »).
	static func gabarit(t: Dictionary) -> Dictionary:
		if gabarits.has(t.name):
			return gabarits[t.name]
		var g := {"t": t, "name": t.name, "clips": {}, "res": {}, "lib": AnimationLibrary.new(), "head": null, "torso": null}
		gabarits[t.name] = g
		return g


	## Le clip d'une clé courte (clipOf) : par son nom dans les bibliothèques du modèle ; découpes créées à la demande.
	static func clip(g: Dictionary, src: AnimationPlayer, cle: String) -> Animation:
		if g.clips.has(cle):
			return g.clips[cle]
		var a: Animation = null
		var h := cle.find("#")
		if h > 0:
			var base := clip(g, src, cle.left(h))
			if base != null:
				a = _decouper(base, cle.substr(h + 1) == "haut")
		else:
			var nom = g.t.names.get(cle)
			if nom != null and src.has_animation(nom):
				a = src.get_animation(nom).duplicate(true)
		if a != null:
			a.loop_mode = Animation.LOOP_NONE if ONCE.has(cle) else Animation.LOOP_LINEAR
			(g.lib as AnimationLibrary).add_animation(cle, a)
		g.clips[cle] = a
		return a


	static func _decouper(a: Animation, haut: bool) -> Animation:
		var b := a.duplicate(true) as Animation
		for i in range(b.get_track_count() - 1, -1, -1):
			var os := str(b.track_get_path(i)).get_slice(":", 1)
			var est_haut := false
			for p in HAUT:
				if os.begins_with(p):
					est_haut = true
					break
			if est_haut != haut:
				b.remove_track(i)
		return b


	## La clé jouée pour une clé demandée (resolveKey) : elle-même, sinon son premier repli, sinon idle.
	static func resoudre(g: Dictionary, src: AnimationPlayer, cle: String) -> String:
		if g.res.has(cle):
			return g.res[cle]
		var k := cle
		if clip(g, src, k) == null:
			k = "idle"
			for f in FALLBACKS.get(cle, []):
				if clip(g, src, f) != null:
					k = f
					break
		g.res[cle] = k
		return k

	func _init(gab: Dictionary, teintes: Dictionary) -> void:
		g = gab
		root = load(PERSONNAGES).faire(g.name, teintes)
		root.set_process(false)
		inner = root.get_child(0)
		var src: AnimationPlayer = root.joueur
		a = AnimationPlayer.new()
		a.name = "PNJ_A"
		b = AnimationPlayer.new()
		b.name = "PNJ_B"
		for p in [a, b]:
			inner.add_child(p)
			p.root_node = NodePath("..")
			p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			# deux lecteurs sur le même squelette (corps entier ou bas, et haut) : chacun ne touche que ses os
			p.deterministic = false
			p.add_animation_library("", g.lib)
		a.set_meta("src", src)
		src.stop()
		src.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		sk = inner.find_child("Skeleton3D", true, false)
		if g.head == null:
			g.head = _axes("Head")
			g.torso = _axes("Torso")
			if g.torso.is_empty():
				g.torso = _axes("Chest")
		head = _os("Head", g.head)
		torso = _os("Torso", g.torso)
		if torso.is_empty():
			torso = _os("Chest", g.torso)

	## L'indice d'un os sous son nom de three.js (les points y sont retirés : « UpperArmL » pour « UpperArm.L »).
	func _idx(nom: String) -> int:
		var i := sk.find_bone(nom)
		if i < 0 and (nom.ends_with("L") or nom.ends_with("R")):
			for sep in [".", "_"]:
				i = sk.find_bone(nom.left(-1) + sep + nom.right(1))
				if i >= 0:
					break
		return i

	func source() -> AnimationPlayer:
		return a.get_meta("src")

	## Les axes de lacet et de tangage d'un os dans son repère (boneAxes) : à la pose de repos, dans le repère du modèle.
	func _axes(nom: String) -> Dictionary:
		if sk == null:
			return {}
		var i := _idx(nom)
		if i < 0:
			return {}
		# le repère du squelette dans celui du modèle (le fichier), hors du demi-tour et de l'échelle du corps
		var t := Transform3D()
		var n: Node = sk
		while n != inner and n != null:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var q := (t.basis.orthonormalized() * sk.get_bone_global_rest(i).basis.orthonormalized()).get_rotation_quaternion()
		var qm := q.inverse()
		return {"yaw": (qm * Vector3.UP).normalized(), "pitch": (qm * Vector3.RIGHT).normalized()}

	func _os(nom: String, axes) -> Dictionary:
		if sk == null or axes == null or (axes as Dictionary).is_empty():
			return {}
		var i := _idx(nom)
		if i < 0:
			return {}
		return {"i": i, "axes": axes, "base": sk.get_bone_pose_rotation(i), "on": false}

	func duree(cle: String) -> float:
		var c := clip(g, source(), cle)
		return c.length if c != null else 1.0

	func resoudre_cle(cle: String) -> String:
		return resoudre(g, source(), cle)

	func a_clip(cle: String) -> bool:
		return clip(g, source(), cle) != null

	## Joue la paire (corps entier ou bas, haut) : fondu de FADE, départ décalé pour un clip joué une fois.
	## Un clip relancé repart du début (le mélangeur de three.js repart à zéro sur reset()).
	func jouer(ca: String, cb, fondu: float, depart: float) -> void:
		var cbs: String = cb if cb != null else ""
		if ca != ka:
			ka = ca
			if clip(g, source(), ca) != null:
				a.play(ca, fondu)
				var t0 := 0.0
				if depart > 0 and ONCE.has(ca):
					t0 = minf(depart, a.current_animation_length - 0.02)
				a.seek(t0, true)
			else:
				a.stop()
		if cbs != kb:
			kb = cbs
			if cbs != "" and clip(g, source(), cbs) != null:
				b.play(cbs, fondu)
				b.seek(0.0, true)
			else:
				b.stop()
		a.speed_scale = 1.0

	## Oublie le clip en cours s'il est celui-là : le prochain jouer() le relance (un geste rejoué).
	func oublier(k: String) -> void:
		if ka == k or ka == k + "#haut" or ka == k + "#bas":
			ka = ""
		if kb == k or kb == k + "#haut":
			kb = ""

	## Accessoire rigide accroché à un os (accessory) : brassard, oreillette, toque, sacoche, plateau. Tailles
	## en mètres ; along = position le long de l'os (vers son premier enfant).
	func accessoire(os: String, genre: String, couleur: Color, o := {}) -> MeshInstance3D:
		if sk == null:
			return null
		var i := _idx(os)
		if i < 0:
			return null
		var m := MeshInstance3D.new()
		m.name = "pnj-acc"
		m.mesh = _maillage_acc(genre)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = couleur
		mat.roughness = 0.6
		mat.metallic = 0.0
		if genre == "band":
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var enfant := -1
		for c in sk.get_bone_children(i):
			enfant = c
			break
		var dir := sk.get_bone_rest(enfant).origin if enfant >= 0 else Vector3.UP
		var lon := dir.length()
		if lon < 1e-9:
			lon = 1.0
		dir = dir / lon if dir.length() > 1e-9 else Vector3.UP
		var ws := _echelle_os(i)
		var q := _de_vers(Vector3.UP, dir)
		if o.has("spin"):
			q = q * Quaternion(Vector3.UP, float(o.spin))
		var pos := dir * lon * float(o.get("along", 0.5))
		if o.has("off"):
			var off: Array = o.off
			pos += (q * Vector3(off[0], off[1], off[2])) * (1.0 / ws)
		var t: Array = o.get("size", [0.1, 0.1, 0.1])
		m.transform = Transform3D(Basis(q).scaled_local(Vector3(t[0], t[1], t[2]) / ws), pos)
		var ba := BoneAttachment3D.new()
		ba.name = "pnj-os-" + os
		sk.add_child(ba)
		ba.bone_idx = i
		ba.add_child(m)
		return m

	## L'échelle monde d'un os par rapport au corps (bone.getWorldScale, le corps à l'échelle 1).
	func _echelle_os(i: int) -> float:
		var t := sk.get_bone_global_pose(i)
		var n: Node = sk
		while n != null and n != root:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var e := t.basis.get_scale().x
		return e if e > 1e-9 else 1.0

	static func _de_vers(a: Vector3, b: Vector3) -> Quaternion:
		var d := a.dot(b)
		if d < -0.999999:
			var ax := Vector3.RIGHT.cross(a)
			if ax.length() < 1e-6:
				ax = Vector3.UP.cross(a)
			return Quaternion(ax.normalized(), PI)
		return Quaternion(a, b)

	static var _acc := {}

	static func _maillage_acc(genre: String) -> Mesh:
		if _acc.has(genre):
			return _acc[genre]
		var m: PrimitiveMesh
		if genre == "band" or genre == "disc":
			var c := CylinderMesh.new()
			c.top_radius = 1.0
			c.bottom_radius = 1.0
			c.height = 1.0
			c.radial_segments = 10 if genre == "band" else 14
			c.rings = 0
			if genre == "band":
				c.cap_top = false
				c.cap_bottom = false
			m = c
		else:
			m = BoxMesh.new()
			(m as BoxMesh).size = Vector3.ONE
		_acc[genre] = m
		return m

	## Chariot de fonds (cartOn) : enfant du corps, devant lui.
	func chariot() -> MeshInstance3D:
		var m := MeshInstance3D.new()
		m.name = "pnj-chariot"
		m.mesh = _maillage_chariot()
		m.position = Vector3(0, 0, -0.78)
		root.add_child(m)
		return m

	static var _chariot: ArrayMesh = null

	static func _maillage_chariot() -> ArrayMesh:
		if _chariot != null:
			return _chariot
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ajout := func(w: float, h: float, d: float, x: float, y: float, z: float, hex: String) -> void:
			var b := BoxMesh.new()
			b.size = Vector3(w, h, d)
			var ar := b.get_mesh_arrays()
			var P: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]
			var N: PackedVector3Array = ar[Mesh.ARRAY_NORMAL]
			var I: PackedInt32Array = ar[Mesh.ARRAY_INDEX]
			var c := Color(hex)
			for k in I:
				st.set_color(c)
				st.set_normal(N[k])
				st.add_vertex(P[k] + Vector3(x, y, z))
		ajout.call(0.62, 0.05, 0.9, 0, 0.2, 0, "#8d949c")
		ajout.call(0.62, 0.05, 0.9, 0, 0.62, 0, "#8d949c")
		for p in [[-0.29, -0.43], [0.29, -0.43], [-0.29, 0.43], [0.29, 0.43]]:
			ajout.call(0.04, 0.92, 0.04, p[0], 0.5, p[1], "#5c636b")
			ajout.call(0.07, 0.1, 0.07, p[0], 0.05, p[1], "#15171a")
		ajout.call(0.6, 0.04, 0.04, 0, 0.96, 0.43, "#5c636b")
		var boites := [[-0.15, -0.2], [0.15, -0.2], [-0.15, 0.14], [0.15, 0.14]]
		for i in boites.size():
			var p: Array = boites[i]
			ajout.call(0.26, 0.2, 0.3, p[0], 0.745, p[1], "#2f3b2a" if i % 2 else "#39472f")
		for p in boites:
			ajout.call(0.1, 0.03, 0.06, p[0], 0.86, p[1], "#d9a441")
		ajout.call(0.5, 0.22, 0.6, 0, 0.335, -0.05, "#23262b")
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.metallic = 0.2
		mat.roughness = 0.6
		st.set_material(mat)
		_chariot = st.commit()
		return _chariot

	func cadence(k: float) -> void:
		a.speed_scale = k

	func avancer(dt: float) -> void:
		a.advance(dt)
		if kb != "":
			b.advance(dt)
		# le lecteur vient d'écrire : la pose de la tête et du buste repart de là
		for o in [head, torso]:
			if not o.is_empty():
				o.base = sk.get_bone_pose_rotation(o.i)
				o.on = false

	## Tête et buste par-dessus le clip (applyBone).
	func os_tourner(o: Dictionary, yaw: float, pitch: float) -> void:
		if o.is_empty():
			return
		var actif := yaw > 0.002 or yaw < -0.002 or pitch > 0.002 or pitch < -0.002
		if not actif and not o.on:
			return
		if not actif:
			sk.set_bone_pose_rotation(o.i, o.base)
			o.on = false
			return
		var q: Quaternion = o.base * Quaternion(o.axes.yaw, yaw) * Quaternion(o.axes.pitch, pitch)
		sk.set_bone_pose_rotation(o.i, q)
		o.on = true
