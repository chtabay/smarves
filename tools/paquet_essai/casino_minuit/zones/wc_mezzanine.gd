extends RefCounted
## Lot B, zone M-WC (js/zones/b-m-wc.js) : les toilettes de la mezzanine. Rectangle [-40, -30] × [12, 20]
## à y = 6 ; la porte (M08) donne sur le lounge. Mur-chicane derrière la porte, trois lavabos, quatre cabines.

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const Y := 6.0
const H := 3.2
const B := {"x0": -40.0, "x1": -30.0, "z0": 12.0, "z1": 20.0}
const OUV := {"north": [{"at": -35.0, "w": 1.6, "h": 2.3}]}


static func construire(K) -> void:
	var L = load(LOT_B)
	K.zone_debut("M-WC")
	K.zone.position.y = Y
	K.plan("damier", B.x0, B.x1, B.z0, B.z1, 0)
	K.dalle(B.x0, B.x1, B.z0, B.z1)
	K.plan("plafond_bas", B.x0, B.x1, B.z0, B.z1, H, false)
	L.coque(K, B, H, "faience", OUV)
	L.habille(K, B, H, OUV, {"socle": "marbre_noir", "socle_h": 1.1, "pil": false, "corniche": false})
	L.toilettes(K, {"x": -35.0, "z": 12.2, "rot": PI, "W": 10.0, "D": 7.8, "cabins": 4, "sinks": 3, "open": [2], "H": H})
	L.palmier(K, -39.1, 12.9, {"h": 2.7, "seed": 6, "pot": "marbre_noir"})
	L.palmier(K, -30.9, 12.9, {"h": 2.7, "seed": 8, "pot": "marbre_noir"})
	for q in [[-37.5, 16.2], [-32.5, 16.2], [-35.0, 12.9]]:
		L.disque(K, "gorge", q[0], H - 0.015, q[1], 0.3, 0.02, 0.3)
	K.lumiere(-35, 2.8, 16.2, K.pal.lumiere, 1.3, 11.0)
	K.zone_fin()
