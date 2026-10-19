extends RefCounted
## Lot E « dehors », zone X-STRIP (js/zones/e-strip.js) : le Las Vegas Strip de nuit devant le casino.
## Rectangle x ∈ [-120, 120], z ∈ [30, 90], niveau 0. Du nord au sud : la façade du Casino Minuit (z = 30) et sa
## porte-cochère, les bassins aux fontaines dansantes, le trottoir (jusqu'à z = 52), Las Vegas Boulevard (six
## voies, terre-plein à palmiers, z ∈ [52, 76]), le trottoir d'en face (z ∈ [76, 90]) et ses façades, dont
## l'entrée de l'arène (porte de 6 m centrée en x = 0). Cette zone pose le ciel, les sols praticables, les bords
## du Strip et les circuits des promeneurs ; les parties (façade, fontaines, boulevard, en face) sont des zones
## à part, pour que chacune fusionne ses formes.

const LOT_E := "res://communes/casino_minuit/zones/lot_e.gd"


static func construire(K) -> void:
	var E = load(LOT_E)
	var L: Dictionary = E.LAY
	K.zone_debut("X-STRIP")

	# --- le ciel : une sphère vue de l'intérieur, que la scène garde centrée sur la caméra ---
	var s := SphereMesh.new()
	s.radius = 600.0
	s.height = 1200.0
	s.radial_segments = 32
	s.rings = 16
	var ciel := MeshInstance3D.new()
	ciel.name = "ciel_nuit"
	ciel.mesh = s
	ciel.material_override = K.mat("nuit")
	ciel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ciel.extra_cull_margin = 16384.0
	K.zone.add_child(ciel)

	# --- dalles praticables : le parvis et le trottoir côté casino, la chaussée (sous les voitures, que le
	# joueur n'atteint que par le plateau du passage piéton), le plateau, le trottoir d'en face ---
	K.dalle(-L.X1, L.X1, L.FACADE, L.CURB0, 0.0)
	K.dalle(-L.X1, L.X1, L.CURB0, L.CURB1, L.ROAD_Y)
	K.dalle(-L.CROSS, L.CROSS, L.CURB0, L.CURB1, 0.0)
	K.dalle(-L.X1, L.X1, L.CURB1, L.ARENA, 0.0)

	# --- les bords : la chaussée hors du passage (on ne traverse qu'au feu), les côtés du plateau, les
	# barrières de chantier au bout des trottoirs, le pied des façades d'en face hors de l'arène ---
	for z in [L.CURB0 + 0.1, L.CURB1 - 0.1]:
		K.obstacle(-L.X1, -L.CROSS, z - 0.1, z + 0.1, 0.0, 1.4)
		K.obstacle(L.CROSS, L.X1, z - 0.1, z + 0.1, 0.0, 1.4)
	for sg in [-1.0, 1.0]:
		K.segment(sg * (L.CROSS + 0.05), L.CURB0, sg * (L.CROSS + 0.05), L.CURB1, 0.1, -0.15, 1.6)
		K.obstacle(sg * L.XEND + sg * 0.1, sg * L.XEND + sg * 0.5, L.FACADE, L.ARENA, -0.2, 2.0)
		K.obstacle(sg * 30.0, sg * L.X1, L.OPP, L.ARENA + 0.4, 0.0, 6.0)

	# --- les circuits des promeneurs (points « walk » de e-strip.js), aller sur une file, retour sur l'autre ---
	var casino := []
	var enface := []
	var x := -112.0
	while x <= 112.1:
		casino.append(Vector3(x, 0, 48.5))
		enface.append(Vector3(x, 0, 80.2))
		x += 8.0
	var retour_c := []
	var retour_e := []
	for p in casino:
		retour_c.push_front(Vector3(p.x, 0, 49.6))
	for p in enface:
		retour_e.push_front(Vector3(p.x, 0, 81.0))
	K.places["e_promenade_casino"] = casino + retour_c
	K.places["e_promenade_enface"] = enface + retour_e
	K.zone_fin()
