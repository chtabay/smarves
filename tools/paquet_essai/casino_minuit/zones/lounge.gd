extends RefCounted
## Lot B, zone M-LOUNGE (js/zones/b-lounge.js) : le lounge tamisé, son bar et sa scène de jazz. Rectangle
## [-40, -18] × [-12, 12] à la mezzanine (y = 6), 5 m sous plafond, ouvert sur la galerie par une baie de
## 15 m. Le bar au mur ouest, six salons de quatre places, la scène au sud-est (piano à queue, contrebasse,
## batterie). Liaisons : le jardin d'hiver (nord) et les toilettes de la mezzanine (porte, au sud).
## La zone est bâtie à plat puis posée à y = 6 ; les places des figurants sont rendues à leur vraie hauteur.

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const Y := 6.0
const H := 5.0
const B := {"x0": -40.0, "x1": -18.0, "z0": -12.0, "z1": 12.0}
const OUV := {"east": [{"at": -1.5, "w": 15.0, "h": 5.0}, {"at": 10.5, "w": 1.6, "h": 2.3}], "north": [{"at": -29.0, "w": 4.0, "h": 3.2}],
	"south": [{"at": -35.0, "w": 1.6, "h": 2.3}], "west": []}
const SX := -24.4
const SZ := 10.0
const SH := 0.3
const SALONS := [[-23.8, -7.8, PI / 2.0], [-29.4, -7.8, 0.0], [-23.8, -2.4, -PI / 2.0], [-29.4, -2.4, PI], [-23.8, 3.0, PI], [-29.4, 3.0, PI / 2.0]]


static func construire(K) -> void:
	var L = load(LOT_B)
	K.zone_debut("M-LOUNGE")
	K.zone.position.y = Y

	# --- enveloppe : moquette « nuages », tentures de velours, laque noire, gorge rose ---
	K.plan("moquette_b", B.x0, B.x1, B.z0, B.z1, 0)
	K.dalle(B.x0, B.x1, B.z0, B.z1)
	K.plan("plafond_bas", B.x0, B.x1, B.z0, B.z1, H, false)
	L.coque(K, B, H, "velours", OUV)
	L.habille(K, B, H, OUV, {"socle": "laque_noire", "pil": 4.4, "pil_mat": "laque_noire", "gorge": "neon_rose",
		"skip": {"west": [{"at": 0.0, "w": 9.4}], "south": [{"at": -24.4, "w": 7.0}, {"at": -19.5, "w": 3.4}], "east": [{"at": 10.5, "w": 3.2}]}})
	L.encadre(K, "z", -12, -29, 4, 3.2, {"fronton": 0.8})
	L.enseigne(K, "JARDIN D'HIVER", -29, 3.78, -11.755, 0, 3.4, 0.5, "neon", "vert")
	L.enseigne(K, "LE LOUNGE · BAR", -29, 3.78, -12.245, PI, 3.4, 0.5, "neon", "rose")
	L.encadre(K, "z", 12, -35, 1.6, 2.3)
	L.porte_ouverte(K, -35, 11.8, 0, -1, 1.44, 2.22)
	L.enseigne(K, "Toilettes", -35, 2.78, 11.74, PI, 1.2, 0.3, "plaque")

	# --- le bar, arrière-bar contre le mur ouest, clients à l'est ---
	var bar: Dictionary = L.bar(K, -36.2, 0, PI / 2.0, 8.0, H)
	K.box("onyx", 0.02, 0.5, 7.6, -35.885, 0.5, 0)
	L.enseigne(K, "LE LOUNGE", -39.72, 3.75, 0, PI / 2.0, 5.2, 0.95, "neon", "rose")
	K.lumiere(-35.1, 2.6, 0, K.pal.ambre_chaud, 1.8, 11.0)
	var tabourets := []
	for p in bar.tabourets:
		tabourets.append([Vector3(p.x, Y + 0.76, p.y), PI / 2.0])
	K.places["lounge_bar"] = {"tabourets": tabourets, "barman": [bar.barman[0] + Vector3(0, Y, 0), bar.barman[1] + Vector3(0, Y, 0)]}

	# --- la scène de jazz (sud-est) : estrade, piano à queue, contrebasse, batterie, micro ; arche de néon ---
	K.box("laque_noire", 6, SH, 3.6, SX, SH / 2.0, SZ)
	K.box("or", 6.04, 0.03, 3.64, SX, SH + 0.005, SZ)
	K.box("bois_laque", 5.9, 0.02, 3.5, SX, SH + 0.02, SZ)
	K.box("gorge", 6, 0.04, 0.04, SX, 0.05, SZ - 1.83)
	K.obstacle(SX - 3.03, SX + 3.03, SZ - 1.83, 12, 0.0, SH)
	K.dalle(SX - 3.0, SX + 3.0, SZ - 1.8, 11.8, SH)
	var px := SX - 1.0
	var pz := SZ + 0.25
	K.box("laque_noire", 1.9, 0.3, 1.5, px, SH + 0.9, pz)
	K.box("laque_noire", 1.9, 0.03, 1.5, px, SH + 1.34, pz + 0.05, -0.42)
	K.box("porcelaine", 0.17, 0.03, 1.3, px - 1.03, SH + 0.8, pz)
	K.box("laque_noire", 0.22, 0.1, 1.5, px - 1.03, SH + 0.74, pz)
	for q in [[-0.8, -0.6], [-0.8, 0.6], [0.8, 0.0]]:
		K.box("laque_noire", 0.09, 0.76, 0.09, px + q[0], SH + 0.38, pz + q[1])
	K.box("capiton_rouge", 0.36, 0.08, 0.7, px - 1.5, SH + 0.5, pz)
	K.box("laque_noire", 0.3, 0.46, 0.62, px - 1.5, SH + 0.23, pz)
	K.places["lounge_piano"] = [[Vector3(px - 1.5, Y + SH + 0.54, pz), -PI / 2.0]]
	var bx := SX + 1.2
	var bz := SZ + 0.9
	L.boule(K, "bois_laque", K.xf(bx, SH + 0.62, bz, 0.12, 0.6, 0, 0.3, 0.5, 0.13))
	L.boule(K, "bois_laque", K.xf(bx, SH + 1.08, bz - 0.04, 0.12, 0.6, 0, 0.22, 0.3, 0.11))
	K.box("laque_noire", 0.05, 0.9, 0.04, bx, SH + 1.6, bz - 0.1, 0.6)
	var dx := SX + 2.1
	var dz := SZ - 0.2
	K.cyl("laque_rouge", 0.3, 0.3, 0.4, dx, SH + 0.32, dz, 12, PI / 2.0)
	K.cyl("or", 0.31, 0.31, 0.03, dx, SH + 0.32, dz - 0.2, 12, PI / 2.0)
	K.cyl("laque_rouge", 0.18, 0.18, 0.16, dx - 0.5, SH + 0.66, dz + 0.1, 10)
	K.cyl("laque_rouge", 0.22, 0.22, 0.3, dx + 0.5, SH + 0.4, dz + 0.3, 10)
	for q in [[-0.6, 1.15, -0.3], [0.65, 1.25, 0.0]]:
		K.cyl("or", 0.24, 0.24, 0.015, dx + q[0], SH + q[1], dz + q[2], 12)
		K.cyl("or", 0.01, 0.01, q[1], dx + q[0], SH + q[1] / 2.0, dz + q[2], 5)
	K.cyl("capiton_rouge", 0.16, 0.16, 0.06, dx, SH + 0.5, dz + 0.65, 8)
	K.cyl("laque_noire", 0.03, 0.1, 0.47, dx, SH + 0.235, dz + 0.65, 6)
	K.cyl("or", 0.012, 0.012, 1.4, SX + 0.3, SH + 0.7, SZ - 1.2, 6)
	K.cyl("or", 0.14, 0.16, 0.02, SX + 0.3, SH + 0.01, SZ - 1.2, 8)
	L.boule(K, "laque_noire", K.xf(SX + 0.3, SH + 1.43, SZ - 1.2, 0, 0, 0, 0.045, 0.06, 0.045))
	K.put("neon_rose", K._arc_or(2.9, 2.97, 0.05, 16), K.xf(SX, 1.5, 11.72, 0, PI))
	K.put("neon_ambre", K._arc_or(2.5, 2.55, 0.05, 14), K.xf(SX, 1.5, 11.73, 0, PI))
	for s in [-1.0, 1.0]:
		K.box("neon_rose", 0.07, 1.2, 0.05, SX + s * 2.935, 0.9, 11.72)
	L.enseigne(K, "JAZZ", SX, 2.75, 11.7, PI, 2.6, 0.95, "neon", "rose")
	for d in [-1.6, 1.6]:
		K.cyl("laque_noire", 0.1, 0.16, 0.26, SX + d, H - 0.25, SZ - 1.4, 8)
		L.disque(K, "ampoule", SX + d, H - 0.39, SZ - 1.33, 0.14, 0.01, 0.14)
	K.lumiere(SX, 3.3, SZ - 1.2, Color("#FFD0C0"), 1.6, 13.0)
	var public := []
	for i in 6:
		public.append([Vector3(SX - 2.75 + i * 1.1, Y, 6.9 - (i % 2) * 0.5), PI])
	K.places["lounge_jazz"] = public

	# --- six salons de quatre places : canapé, deux fauteuils, table basse à lampe, lanterne au-dessus ---
	var salons := []
	for i in SALONS.size():
		var q: Array = SALONS[i]
		for p in L.salon(K, q[0], q[1], q[2], [{"k": "sofa", "x": 0.0, "z": 1.3, "f": 0.0, "n": 2}, {"k": "fauteuil", "x": -0.72, "z": -1.3, "f": PI},
				{"k": "fauteuil", "x": 0.72, "z": -1.3, "f": PI}], {"mat": "velours_prune" if i % 2 else "capiton_rouge", "table": [0.0, 0.0, 0.48], "lampe": true}):
			salons.append([p[0] + Vector3(0, Y, 0), p[1]])
		K.lanterne(q[0], 3.1, q[1], 0.6, H - 3.55)
		L.disque(K, "moquette_d", q[0], 0.012, q[1], 1.75, 0.01, 1.75)
	K.places["lounge_salons"] = salons
	K.lumiere(-26.6, 2.4, -2.4, K.pal.ambre_chaud, 1.6, 12.0)

	# --- l'ascenseur (palier haut), les palmiers ---
	L.gaine(K, H)
	L.enseigne(K, "Ascenseur", -21.02, 3.0, 10.4, -PI / 2.0, 1.3, 0.3, "plaque")
	for q in [[-39.1, -11.1, 41], [-39.1, 11.1, 42], [-18.9, -11.0, 43], [-28.4, 11.2, 44]]:
		L.palmier(K, q[0], q[1], {"h": 3.2 if q[2] < 44 else 3.0, "seed": q[2]})
	K.zone_fin()
