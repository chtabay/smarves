extends RefCounted
## Lot B, zone R-WC-O (js/zones/b-wc-o.js) : les toilettes ouest. Rectangle [-40, -30] × [21, 30],
## rez-de-chaussée ; la porte (L08) donne sur le lobby. Mur-chicane derrière la porte, quatre lavabos sur
## son revers, six cabines au fond (deux portes ouvertes), une jardinière au palmier au milieu.

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const H := 3.4
const B := {"x0": -40.0, "x1": -30.0, "z0": 21.0, "z1": 30.0}
const OUV := {"east": [{"at": 25.5, "w": 1.6, "h": 2.3}]}


static func construire(K) -> void:
	var L = load(LOT_B)
	K.zone_debut("R-WC-O")
	K.plan("damier", B.x0, B.x1, B.z0, B.z1, 0)
	K.dalle(B.x0, B.x1, B.z0, B.z1)
	K.plan("plafond_bas", B.x0, B.x1, B.z0, B.z1, H, false)
	L.coque(K, B, H, "faience", OUV)
	L.habille(K, B, H, OUV, {"socle": "marbre_noir", "socle_h": 1.1, "pil": false, "corniche": false})
	L.toilettes(K, {"x": -30.2, "z": 25.5, "rot": PI / 2.0, "W": 9.0, "D": 9.8, "cabins": 6, "sinks": 4, "open": [1, 4], "H": H})
	L.disque(K, "marbre_noir", -35.4, 0.24, 25.5, 0.7, 0.48, 0.7)
	L.disque(K, "or", -35.4, 0.5, 25.5, 0.74, 0.04, 0.74)
	K.rond(-35.4, 25.5, 0.76)
	L.palmier(K, -35.4, 25.5, {"h": 2.9, "seed": 5, "collide": false, "pot": "marbre_noir"})
	for q in [[-35.4, 23.0], [-35.4, 28.0], [-31.0, 25.5]]:
		L.disque(K, "gorge", q[0], H - 0.015, q[1], 0.3, 0.02, 0.3)
	K.lumiere(-35.4, 2.9, 25.5, K.pal.lumiere, 1.3, 11.0)
	K.zone_fin()
