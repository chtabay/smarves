extends SceneTree
## Les PNJ de Casino Minuit, fidèles à l'original : godot --headless --path . -s tools/test_minuit_pnj.gd
## Le monde des PNJ (pnj/monde.gd) répond comme l'original (js/engine.js, js/npc.js) aux questions gardées par
## tools/minuit_decor/exporter_pnj.mjs dans minuit_decor/pnj_verif.json : dégagement au bord des obstacles, zone
## d'un point, zones du personnel, nœud le plus proche, chemin d'un point à un autre sur trois niveaux.

const BASE := "res://tools/paquet_essai/casino_minuit/"
const VERIF := "res://tools/minuit_decor/pnj_verif.json"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	var monde = load(BASE + "pnj/monde.gd").new()
	var t0 := Time.get_ticks_msec()
	check(monde.charger(BASE + "donnees/pnj_monde.json"), "le monde des PNJ se charge")
	print("        chargé en %d ms" % (Time.get_ticks_msec() - t0))
	var v: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VERIF))
	var bad := []
	for c in v.clearance:
		var d: float = monde.degagement(float(c[2]), c[0], c[1])
		if absf(snappedf(d, 0.0001) - float(c[3])) > 2e-4:
			bad.append([c, d])
	check(bad.is_empty(), "dégagement : %d points comme l'original %s" % [v.clearance.size(), str(bad.slice(0, 3))])
	bad = []
	for c in v.zones:
		var z: String = monde.zone_de(c[0], c[1], float(c[2]))
		if z != c[3]:
			bad.append([c, z])
	check(bad.is_empty(), "zone d'un point : %d points comme l'original %s" % [v.zones.size(), str(bad.slice(0, 3))])
	var sz: Array = monde.zone_personnel.keys()
	sz.sort()
	check(sz == v.staffZone, "zones du personnel comme l'original %s / %s" % [str(sz), str(v.staffZone)])
	bad = []
	for c in v.nearest:
		var n: int = monde.proche({"x": c[0], "z": c[1]}, 14, float(c[2]))
		if n != int(c[3]):
			bad.append([c, n])
	check(bad.is_empty(), "nœud le plus proche : %d points comme l'original %s" % [v.nearest.size(), str(bad.slice(0, 3))])
	bad = []
	t0 = Time.get_ticks_msec()
	for c in v.paths:
		var p: Array = monde.chemin(c.from, c.to)
		if not _meme(p, c.path):
			bad.append({"de": c.from, "a": c.to, "port": p.size(), "original": c.path.size()})
	print("        %d chemins en %d ms" % [v.paths.size(), Time.get_ticks_msec() - t0])
	check(bad.is_empty(), "chemins : %d trajets comme l'original %s" % [v.paths.size(), str(bad.slice(0, 2))])
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _meme(p: Array, q: Array) -> bool:
	if p.size() != q.size():
		return false
	for i in p.size():
		var a: Dictionary = p[i]
		var b: Dictionary = q[i]
		if absf(a.x - b.x) > 2e-4 or absf(a.z - b.z) > 2e-4 or float(a.level) != float(b.level):
			return false
		if a.has("link") != b.has("link"):
			return false
		if a.has("link") and (a.link.id != b.link.id or float(a.link.toLevel) != float(b.link.toLevel)):
			return false
	return true
