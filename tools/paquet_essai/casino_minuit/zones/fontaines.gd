extends RefCounted
## Lot E « dehors », zone X-FONTAINES (js/zones/e-fontaines.js) : les deux bassins devant la façade
## (8 ≤ |x| ≤ 58, z ∈ [40 ; 46,8]), margelles, balustrade côté trottoir, lanternes, et le spectacle des jets
## chorégraphié toutes les 2 min 30 (le premier 25 s après l'arrivée) : lever en vague, vagues, chenillard,
## rideau, crescendo jusqu'à 30 m, final. Les jets « fusées » sur l'axe et les « rameurs » qui oscillent de
## part et d'autre sont un seul MultiMesh. Le pupitre du programme (à l'angle de la promenade) annonce le
## prochain spectacle et le lance.

const LOT_E := "res://communes/casino_minuit/zones/lot_e.gd"
const PERIODE := 150.0
const SPECTACLE := 46.0
const PREMIER := 25.0
const YW := 0.3


static func construire(K) -> void:
	var E = load(LOT_E)
	var L: Dictionary = E.LAY
	K.zone_debut("X-FONTAINES")
	var z0: float = L.LAKE0
	var z1: float = L.LAKE1
	var zc := (z0 + z1) / 2.0
	var balustre: ArrayMesh = K.lathe([[0.07, 0.0], [0.1, 0.1], [0.055, 0.26], [0.09, 0.44], [0.055, 0.6], [0.08, 0.66]], 6)
	var bassins := []
	for s in [-1.0, 1.0]:
		var x0: float = -L.LAKE_OUT if s < 0 else L.LAKE_IN
		var x1: float = -L.LAKE_IN if s < 0 else L.LAKE_OUT
		bassins.append([s, x0, x1])
		var w := x1 - x0
		var cx := (x0 + x1) / 2.0
		K.box("laque_noire", w, 0.05, z1 - z0, cx, -0.4, zc)
		K.plan("eau_nuit", x0 + 0.5, x1 - 0.5, z0 + 0.5, z1 - 0.5, YW)
		# La margelle sur les quatre côtés, la balustrade côté trottoir et ses dés à lanterne.
		K.box("pierre", w, 0.55, 0.5, cx, 0.275, z0 + 0.25)
		K.box("pierre", w, 0.55, 0.5, cx, 0.275, z1 - 0.25)
		K.box("pierre", 0.5, 0.55, z1 - z0 - 1, x0 + 0.25, 0.275, zc)
		K.box("pierre", 0.5, 0.55, z1 - z0 - 1, x1 - 0.25, 0.275, zc)
		K.box("or", w, 0.04, 0.06, cx, 0.5, z0 + 0.52)
		K.box("or", w, 0.04, 0.06, cx, 0.5, z1 - 0.52)
		K.box("creme", w, 0.12, 0.42, cx, 0.61, z1 - 0.25)
		K.box("creme", w, 0.12, 0.46, cx, 1.33, z1 - 0.25)
		var x := x0 + 0.5
		while x <= x1 - 0.49:
			K.put("creme", balustre, K.xf(x, 0.67, z1 - 0.25))
			x += 0.42
		x = x0 + 0.5
		while x <= x1 - 0.4:
			K.box("creme", 0.5, 1.45, 0.5, x, 0.72, z1 - 0.25)
			K.box("or", 0.56, 0.06, 0.56, x, 1.47, z1 - 0.25)
			K.cyl("or", 0.04, 0.06, 1.1, x, 2.05, z1 - 0.25, 6)
			K.sph("lumiere", 0.2, x, 2.75, z1 - 0.25)
			K.cyl("or", 0.16, 0.06, 0.1, x, 2.97, z1 - 0.25, 6)
			x += (w - 1.0) / 5.0
		# Côté promenade, la balustrade de retour.
		var xi: float = x1 - 0.25 if s < 0 else x0 + 0.25
		K.box("creme", 0.42, 0.12, z1 - z0 - 1, xi, 0.61, zc)
		K.box("creme", 0.46, 0.12, z1 - z0 - 1, xi, 1.33, zc)
		var z := z0 + 0.6
		while z <= z1 - 0.59:
			K.put("creme", balustre, K.xf(xi, 0.67, z))
			z += 0.42
		for zz in [z0 + 0.25, z1 - 0.25]:
			K.box("creme", 0.5, 1.45, 0.5, xi, 0.72, zz)
			K.box("or", 0.56, 0.06, 0.56, xi, 1.47, zz)
			K.sph("or", 0.16, xi, 1.62, zz)
		K.obstacle(x0, x1, z0, z1, 0.0, 1.5)

	# --- les jets : « fusées » sur l'axe, « rameurs » de part et d'autre ---
	var jets := []
	for b in bassins:
		var s: float = b[0]
		for i in 24:
			var x: float = s * (L.LAKE_IN + 1.6 + i * 2.0)
			if absf(x - E.MARQ.x) < 3.2:
				continue
			jets.append([x, zc, 0, i, 0.0])
		for i in 12:
			for r in 2:
				var x: float = s * (L.LAKE_IN + 2.6 + i * 4.0)
				if absf(x - E.MARQ.x) < 3.4:
					continue
				jets.append([x, z0 + 1.6 if r == 0 else z1 - 1.6, 1, i * 2, -1.0 if r == 0 else 1.0])
	var n := jets.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 0.22
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	st.append_from(cyl, 0, Transform3D(Basis(), Vector3(0, 0.5, 0)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = n
	var mi := MultiMeshInstance3D.new()
	mi.name = "jets_fontaines"
	mi.multimesh = mm
	var jet: ShaderMaterial = (K.mat("jet") as ShaderMaterial).duplicate()
	jet.set_shader_parameter("force", 0.9)
	mi.material_override = jet
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-60, -1, 38), Vector3(120, 40, 10))
	K.zone.add_child(mi)
	var lumiere: OmniLight3D = K.lumiere(0, 9, zc, Color("#BFE6FF"), 0.6, 40.0)

	# --- la chorégraphie (target du moteur web) : hauteur et inclinaison du jet j à l'instant τ du spectacle ---
	var etat := {"en_cours": false, "prochain": PREMIER, "debut": PREMIER, "t": 0.0}
	var h := PackedFloat32Array()
	var ang := PackedFloat32Array()
	h.resize(n)
	ang.resize(n)
	var cible := func(j: int, tau: float, t: float) -> Vector2:
		var J: Array = jets[j]
		var rameur: bool = J[2] == 1
		var i: int = J[3]
		var rang: float = J[4]
		if tau < 0.0:
			return Vector2(0.25 if rameur else 0.7 + 0.25 * sin(t * 0.7 + i * 0.4), 0.0)
		if tau < 3.0:
			var k := clampf(tau * 1.4 - i * 0.05, 0.0, 1.0)
			return Vector2(2.0 * k if rameur else 4.0 * k, 0.0)
		if tau < 12.0:
			return Vector2(8.0, rang * 0.42 * sin(TAU * 0.6 * tau + i * 0.15)) if rameur else Vector2(6.0 + 5.0 * sin(2.4 * tau - i * 0.5), 0.0)
		if tau < 20.0:
			var ph := fposmod((tau - 12.0) * 6.0 - i, 24.0)
			var d := minf(ph, 24.0 - ph)
			return Vector2(3.0, rang * 0.3) if rameur else Vector2(2.0 + 17.0 * exp(-d * d / 1.6), 0.0)
		if tau < 30.0:
			return Vector2(12.0, rang * (0.15 + 0.45 * sin(TAU * 0.25 * (tau - 20.0)))) if rameur else Vector2(3.0, 0.0)
		if tau < 40.0:
			var beat := exp(-fmod(tau - 30.0, 1.25) * 3.0)
			var k := (tau - 30.0) / 10.0
			return Vector2(6.0 + 8.0 * k, rang * (0.25 + 0.3 * beat) * (1.0 if i % 4 < 2 else -1.0)) if rameur else Vector2(8.0 + 18.0 * k + 6.0 * beat, 0.0)
		if tau < 43.0:
			return Vector2(16.0, rang * 0.55) if rameur else Vector2(31.0, 0.0)
		return Vector2(0.2, 0.0)
	K.chaque_image(func(dt: float, t: float) -> void:
		dt = minf(dt, 0.05)
		etat.t = t
		var debut: float = etat.debut
		var tau0 := fposmod(t - debut, PERIODE)
		var on := t >= debut and tau0 < SPECTACLE
		var tau := tau0 if on else -1.0
		etat.en_cours = on
		etat.prochain = 0.0 if on else (debut - t if t < debut else PERIODE - tau0)
		# Les projecteurs : bleu, magenta, or, blanc.
		var c := Color(0.75, 0.9, 1.0)
		var li := 0.6
		if on:
			if tau < 12.0:
				c = Color(0.55, 0.8, 1.2)
			elif tau < 20.0:
				c = Color(1.1, 0.45, 1.0)
			elif tau < 30.0:
				c = Color(0.6, 0.95, 1.25)
			elif tau < 43.0:
				c = Color(1.25, 0.95, 0.55)
			else:
				c = Color(0.9, 0.9, 1.0)
			li = 1.6 + (1.0 if tau > 30.0 and tau < 43.0 else 0.0)
		jet.set_shader_parameter("teinte", Color(c.r * 0.7, c.g * 0.75, c.b * 0.8))
		lumiere.light_color = Color(c.r * 0.6, c.g * 0.6, c.b * 0.6)
		lumiere.light_energy = li
		for j in n:
			var g: Vector2 = cible.call(j, tau, t)
			var k := minf(1.0, dt * 5.0) if g.x > h[j] else minf(1.0, dt * 2.2)
			h[j] += (g.x - h[j]) * k
			ang[j] += (g.y - ang[j]) * minf(1.0, dt * 4.0)
			var J: Array = jets[j]
			var hh := maxf(0.05, h[j])
			var r: float = 0.16 + hh * 0.012 if J[2] == 1 else 0.14 + hh * 0.02
			mm.set_instance_transform(j, Transform3D(Basis(Vector3.BACK, ang[j]) * Basis.from_scale(Vector3(r, hh, r)), Vector3(J[0], YW, J[1]))))

	# --- les spectateurs (points « watch »), le pupitre du programme ---
	var regards := []
	for b in bassins:
		var s: float = b[0]
		for i in 12:
			var x: float = s * (L.LAKE_IN + 3.0 + i * 4.0)
			if absf(x - E.MARQ.x) < 3.0:
				continue
			regards.append([Vector3(x, 0, z1 + 0.75), 0.0])
		for i in 3:
			regards.append([Vector3(s * (L.LAKE_IN + 8.0 + i * 14.0), 0, z0 - 0.9), PI])
	K.places["e_fontaines"] = regards
	K.box("laque_noire", 0.5, 1.1, 0.4, L.LAKE_IN + 0.6, 0.55, z1 + 0.35)
	K.box("or", 0.56, 0.05, 0.46, L.LAKE_IN + 0.6, 1.12, z1 + 0.35)
	E.enseigne(K, "FONTAINES", "#BFEAFF", 1.6, 0.32, L.LAKE_IN + 0.6, 1.3, z1 + 0.56, 0, "bloc")
	var a: Area3D = K.interaction("fontaines", "Le spectacle des fontaines", L.LAKE_IN + 0.6, 1.2, z1 + 0.6, Vector3(1.6, 2.2, 1.4))
	a.set_meta("etat", etat)
	K.places["e_fontaines_etat"] = etat
	K.zone_fin()
