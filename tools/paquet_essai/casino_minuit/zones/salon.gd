extends RefCounted
## Lot B, zone R-SALON (js/zones/b-salon.js) : le coin calme attenant au lobby. Rectangle [-40, -30] ×
## [12, 21], rez-de-chaussée. Pièces maîtresses : le mur d'eau sur marbre noir (mur ouest, dans l'axe de
## la baie du lobby) et la cheminée aux flammes vives (mur sud, dans l'axe de la baie des machines).

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const H := 5.4
const B := {"x0": -40.0, "x1": -30.0, "z0": 12.0, "z1": 21.0}
const OUV := {"north": [{"at": -35.0, "w": 3.0, "h": 3.0}], "east": [{"at": 16.5, "w": 5.0, "h": 3.4}], "south": [], "west": []}
const FX := -34.0
const FZ := 20.8


static func construire(K) -> void:
	var L = load(LOT_B)
	K.zone_debut("R-SALON")
	K.plan("moquette_d", B.x0, B.x1, B.z0, B.z1, 0)
	K.dalle(B.x0, B.x1, B.z0, B.z1)
	K.plan("plafond_bas", B.x0, B.x1, B.z0, B.z1, H, false)
	L.coque(K, B, H, "bois_laque", OUV)
	L.habille(K, B, H, OUV, {"socle": "marbre_noir", "pil": 4.6, "pil_mat": "laque_noire",
		"skip": {"west": [{"at": 16.5, "w": 5.6}], "south": [{"at": -34.0, "w": 4.0}, {"at": -38.0, "w": 3.4}], "north": [{"at": -38.0, "w": 3.0}, {"at": -31.8, "w": 3.0}]}})

	# --- le mur d'eau : une dalle de marbre noir de 4,4 × 3,6 m, une nappe qui ruisselle, le bac ---
	K.box("marbre_noir", 0.14, 3.7, 4.5, -39.73, 2.1, 16.5)
	for s in [-1.0, 1.0]:
		K.box("laque_noire", 0.34, 4.2, 0.34, -39.63, 2.1, 16.5 + s * 2.42)
		K.box("or", 0.38, 0.1, 0.38, -39.63, 4.25, 16.5 + s * 2.42)
		K.box("or", 0.38, 0.1, 0.38, -39.63, 0.05, 16.5 + s * 2.42)
	K.box("laque_noire", 0.5, 0.3, 5.2, -39.55, 4.3, 16.5)
	K.box("or", 0.54, 0.05, 5.24, -39.55, 4.47, 16.5)
	K.box("gorge", 0.05, 0.05, 4.4, -39.55, 4.12, 16.5)
	K.box("marbre_noir", 0.62, 0.42, 4.9, -39.49, 0.21, 16.5)
	K.box("or", 0.03, 0.04, 4.9, -39.17, 0.36, 16.5)
	K.plan("eau", -39.76, -39.22, 14.15, 18.85, 0.435)
	var nappe := QuadMesh.new()
	nappe.size = Vector2(4.4, 3.7)
	K.put("jet", nappe, K.xf(-39.64, 0.44 + 1.85, 16.5, 0, PI / 2.0))
	K.obstacle(-39.8, -39.16, 14, 19)

	# --- la cheminée (mur sud) : manteau de marbre rouge, foyer, trumeau à miroir, flammes vives ---
	for s in [-1.0, 1.0]:
		K.box("marbre_rouge", 0.42, 1.55, 0.5, FX + s * 1.16, 0.775, FZ - 0.25)
		K.box("or", 0.46, 0.08, 0.54, FX + s * 1.16, 1.55, FZ - 0.25)
	K.box("marbre_rouge", 2.74, 0.4, 0.5, FX, 1.79, FZ - 0.25)
	K.box("marbre_noir", 3.1, 0.08, 0.66, FX, 2.03, FZ - 0.3)
	K.box("laque_noire", 1.9, 1.55, 0.06, FX, 0.775, FZ - 0.04)
	K.box("marbre_noir", 2.9, 0.06, 1.0, FX, 0.03, FZ - 0.5)
	K.box("or", 1.7, 0.5, 0.03, FX, 0.25, FZ - 0.5)
	K.box("laque_noire", 1.64, 0.44, 0.035, FX, 0.25, FZ - 0.5)
	for i in 2:
		K.cyl("tronc", 0.09, 0.1, 0.9, FX + [-0.14, 0.12][i], 0.14 + i * 0.14, FZ - 0.26, 6, 0, PI / 2.0)
	K.box("gorge", 1.3, 0.05, 0.3, FX, 0.065, FZ - 0.28)
	K.box("miroir", 2.0, 1.7, 0.03, FX, 3.15, FZ - 0.02)
	for q in [[2.16, 0.1, 0.0, 4.05], [2.16, 0.1, 0.0, 2.25], [0.1, 1.9, -1.05, 3.15], [0.1, 1.9, 1.05, 3.15]]:
		K.box("or", q[0], q[1], 0.06, FX + q[2], q[3], FZ - 0.03)
	L.lampe(K, FX - 1.25, 2.07, FZ - 0.3, 0.9)
	L.lampe(K, FX + 1.25, 2.07, FZ - 0.3, 0.9)
	K.obstacle(FX - 1.45, FX + 1.45, FZ - 0.6, 21)
	var flammes := Node3D.new()
	flammes.name = "Flammes"
	flammes.position = Vector3(FX, 0.1, FZ - 0.42)
	K.zone.add_child(flammes)
	for q in [[1.5, 1.0, 0.0], [1.2, 0.85, 0.12], [0.9, 0.7, -0.1]]:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(q[0], q[1])
		qm.center_offset = Vector3(q[2], q[1] / 2.0, 0)
		mi.mesh = qm
		mi.material_override = K.mat("flamme")
		flammes.add_child(mi)
	var feu = K.lumiere(FX, 1.1, FZ - 1.3, K.pal.ambre_chaud, 1.7, 11.0)
	K.chaque_image(func(_dt, t):
		var k := 0.5 * sin(t * 9.1) + 0.3 * sin(t * 14.3 + 1.0) + 0.2 * sin(t * 5.7 + 2.0)
		flammes.scale.y = 1.0 + 0.12 * k
		feu.light_energy = 1.7 + 0.35 * k)

	# --- trois salons et un banc : devant la cheminée, face à face près du mur d'eau, en angle ---
	var places := []
	places.append_array(L.salon(K, FX, 17.55, PI, [{"k": "sofa", "x": 0.0, "z": 0.0, "f": 0.0, "n": 2}, {"k": "fauteuil", "x": 1.85, "z": -1.5, "f": PI / 2.0},
		{"k": "fauteuil", "x": -1.85, "z": -1.5, "f": -PI / 2.0}], {"mat": "cuir", "table": [0.0, -1.55, 0.5]}))
	places.append_array(L.salon(K, -37.95, 12.85, PI, [{"k": "sofa", "x": 0.0, "z": 0.0, "f": 0.0, "n": 2}, {"k": "sofa", "x": 0.0, "z": -2.9, "f": PI, "n": 2}],
		{"mat": "cuir", "table": [0.0, -1.45, 0.4], "lampe": true}))
	places.append_array(L.salon(K, -38.4, 19.7, 0.0, [{"k": "sofa", "x": -0.9, "z": -0.15, "f": -PI / 2.0, "n": 2}, {"k": "sofa", "x": 0.8, "z": 0.65, "f": 0.0, "n": 2}],
		{"mat": "cuir", "table": [0.75, -1.05, 0.38], "lampe": true}))
	places.append_array(L.salon(K, -31.2, 20.45, 0.0, [{"k": "banc", "x": 0.0, "z": 0.0, "f": 0.0, "n": 2, "w": 1.5}], {"banc_mat": "marbre_noir"}))
	K.places["salon"] = places

	# --- la bibliothèque (mur nord), le lustre, un palmier ---
	K.box("laque_noire", 2.9, 3.0, 0.4, -31.85, 1.5, 12.4)
	K.obstacle(-33.3, -30.4, 12.2, 12.62)
	for j in 4:
		K.box("gorge", 2.6, 0.5, 0.02, -31.85, 0.75 + j * 0.62, 12.6)
		K.box("or", 2.7, 0.03, 0.06, -31.85, 0.46 + j * 0.62, 12.62)
		for i in 12:
			if (i * 5 + j * 3) % 11 > 1:
				var hh := 0.3 + ((i * 7 + j) % 4) * 0.04
				K.box(["marbre_rouge", "laque_noire", "or", "bois_laque"][(i + j * 2) % 4], 0.13, hh, 0.2, -33.05 + i * 0.218, 0.48 + j * 0.62 + hh / 2.0, 12.68)
	L.lustre(K, -34.4, 3.7, 15.6, H, 0.85, 10, 0.9)
	L.palmier(K, -39.2, 13.0, {"h": 3.0, "seed": 12, "collide": false})
	K.zone_fin()
