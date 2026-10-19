extends RefCounted
## Le monde tel que le voient les PNJ de l'original (js/engine.js, partie « Obstacles par niveau » et « Navigation »,
## et js/npc.js, partie « Navigation multi-niveaux ») : dalles praticables, obstacles par niveau, graphe de navigation,
## A* et lissage. Les données viennent de l'original lui-même (donnees/pnj_monde.json, tools/minuit_decor/exporter_pnj.mjs) ;
## les calculs sont ceux de l'original, dans le même ordre, pour que les mêmes questions donnent les mêmes chemins.

const CELL := 2.0
const REACH := 1.6
const NAV_CLEAR := 0.3
const HCELL := 3.0

var donnees := {}
## id du niveau (float) → { id, y, name, walk, holes, links (les liaisons elles-mêmes), grid (ids des nœuds de flânerie) }
var niveaux := {}
var liste_niveaux: Array = []
var obstacles: Array = []
var liaisons: Array = []
var liaison_par_id := {}
var ascenseurs: Array = []
var zones: Array = []
var zone_par_id := {}
var points := {}
var stations: Array = []
var station_par_id := {}

## Les nœuds, en tableaux parallèles (rapides à lire), et les nœuds eux-mêmes (pour leurs marques : seat, point, link…).
var noeuds: Array = []
var nx := PackedFloat64Array()
var nz := PackedFloat64Array()
var ny := PackedFloat64Array()
var nl := PackedFloat64Array()
var aretes: Array = []
## Le graphe de l'original (engine.js : non orienté, coûts des liaisons et des ascenseurs) …
var adj: Array = []
## … et celui de npc.js (escalators à sens unique), avec les nœuds en zone du personnel.
var adj_pnj: Array = []
var noeud_personnel := PackedByteArray()
var zone_personnel := {}

var _seaux := {}
var _ot := PackedInt32Array()
var _of := PackedFloat64Array()
var _hash := {}


var zones_closes: Array = []


## zones_closes : les lieux fermés par un seuil du joueur, tenus pour des zones du personnel (les clients n'y vont
## pas, le personnel si).
func charger(chemin: String, closes := []) -> bool:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		push_error("[pnj] monde introuvable : " + chemin)
		return false
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		push_error("[pnj] monde illisible : " + chemin)
		return false
	return _depuis(d, closes)


## Un second monde sur les mêmes données (le fil des chemins : le cache de libre() s'écrit pendant les requêtes).
func donnees_de(autre) -> bool:
	return _depuis(autre.donnees.duplicate(true), autre.zones_closes)


func _depuis(d: Dictionary, closes: Array) -> bool:
	donnees = d
	zones_closes = closes.duplicate()
	for k in d.links:
		liaisons.append(k)
		liaison_par_id[k.id] = k
	for l in d.levels:
		var L := {"id": float(l.id), "y": float(l.y), "name": l.name, "walk": l.walk, "holes": l.holes, "links": [], "grid": l.grid}
		for id in l.links:
			L.links.append(liaison_par_id[id])
		niveaux[float(l.id)] = L
		liste_niveaux.append(float(l.id))
	liste_niveaux.sort()
	obstacles = d.colliders
	for c in obstacles:
		c.level = float(c.level)
	ascenseurs = d.elevators
	zones = d.zones
	for z in zones:
		z.level = float(z.level)
		zone_par_id[z.id] = z
	points = d.points
	stations = d.stations
	for st in stations:
		station_par_id[st.id] = st
	noeuds = d.nodes
	var n := noeuds.size()
	nx.resize(n); nz.resize(n); ny.resize(n); nl.resize(n)
	for i in n:
		var o: Dictionary = noeuds[i]
		o.level = float(o.level)
		nx[i] = o.x; nz[i] = o.z; ny[i] = o.y; nl[i] = o.level
		var k := _hk(o.level, o.x, o.z)
		if not _hash.has(k):
			_hash[k] = []
		_hash[k].append(i)
	aretes = d.edges
	_seaux_obstacles()
	_zones_du_personnel()
	_graphes()
	return true


func niveau_y(level: float) -> float:
	var L = niveaux.get(float(level))
	return float(L.y) if L != null else float(level) * 6.0


## Le niveau dont l'altitude est la plus proche de y (Z.levelAt).
func niveau_a(y: float) -> float:
	var best := 0.0
	var bd := 1e9
	for k in niveaux:
		var d := absf(float(niveaux[k].y) - y)
		if d < bd:
			bd = d
			best = k
	return best


# --------------------------------------------------------------------------------------------------
# Obstacles par niveau (engine.js)
# --------------------------------------------------------------------------------------------------

func _seaux_obstacles() -> void:
	# Les obstacles en tableaux serrés : type (0 cercle, 1 segment, 2 boîte), puis six nombres chacun.
	var n := obstacles.size()
	_ot.resize(n)
	_of.resize(n * 6)
	_seaux = {}
	var tmp := {}
	for i in n:
		var c: Dictionary = obstacles[i]
		var x0: float; var x1: float; var z0: float; var z1: float
		var o := i * 6
		if c.t == "circle":
			_ot[i] = 0
			_of[o] = c.x; _of[o + 1] = c.z; _of[o + 2] = c.r
			x0 = c.x - c.r; x1 = c.x + c.r; z0 = c.z - c.r; z1 = c.z + c.r
		elif c.t == "seg":
			_ot[i] = 1
			_of[o] = c.x0; _of[o + 1] = c.z0; _of[o + 2] = c.x1; _of[o + 3] = c.z1; _of[o + 4] = c.r
			x0 = minf(c.x0, c.x1) - c.r; x1 = maxf(c.x0, c.x1) + c.r; z0 = minf(c.z0, c.z1) - c.r; z1 = maxf(c.z0, c.z1) + c.r
		else:
			_ot[i] = 2
			_of[o] = c.minX; _of[o + 1] = c.maxX; _of[o + 2] = c.minZ; _of[o + 3] = c.maxZ
			x0 = c.minX; x1 = c.maxX; z0 = c.minZ; z1 = c.maxZ
		if c.get("off", false):
			_ot[i] = -1
		var L: float = c.level
		if not tmp.has(L):
			tmp[L] = {}
		var b: Dictionary = tmp[L]
		for ix in range(floori((x0 - REACH) / CELL), floori((x1 + REACH) / CELL) + 1):
			for iz in range(floori((z0 - REACH) / CELL), floori((z1 + REACH) / CELL) + 1):
				var k := ix * 4096 + iz
				if not b.has(k):
					b[k] = PackedInt32Array()
				b[k].append(i)
	_seaux = tmp
	# dalles, trémies et emprises des liaisons, par niveau
	for l in niveaux:
		var L: Dictionary = niveaux[l]
		var w := PackedFloat64Array()
		for r in L.walk:
			w.append_array([r.x0, r.x1, r.z0, r.z1])
		var h := PackedFloat64Array()
		for r in L.holes:
			h.append_array([r.x0, r.x1, r.z0, r.z1])
		var k := PackedFloat64Array()
		for r in L.links:
			k.append_array([r.fx, r.fz, r.dx, r.dz, r.len, r.hw])
		L["_w"] = w
		L["_h"] = h
		L["_k"] = k


static func dist_a(c: Dictionary, x: float, z: float) -> float:
	if c.t == "circle":
		return _hypot(x - c.x, z - c.z) - c.r
	if c.t == "seg":
		var ex: float = c.x1 - c.x0
		var ez: float = c.z1 - c.z0
		var l2 := ex * ex + ez * ez
		var t := clampf(((x - c.x0) * ex + (z - c.z0) * ez) / l2, 0.0, 1.0) if l2 else 0.0
		return _hypot(x - c.x0 - ex * t, z - c.z0 - ez * t) - c.r
	var dx := maxf(maxf(c.minX - x, 0.0), x - c.maxX)
	var dz := maxf(maxf(c.minZ - z, 0.0), z - c.maxZ)
	if dx or dz:
		return _hypot(dx, dz)
	return -minf(minf(x - c.minX, c.maxX - x), minf(z - c.minZ, c.maxZ - z))


## La liaison (escalier, escalator, rampe) dont l'emprise couvre le point, ou null.
func dans_liaison(L: Dictionary, x: float, z: float):
	var i := _liaison_a(L, x, z)
	return L.links[i] if i >= 0 else null


func _liaison_a(L: Dictionary, x: float, z: float) -> int:
	var k: PackedFloat64Array = L._k
	for i in range(0, k.size(), 6):
		var t := ((x - k[i]) * k[i + 2] + (z - k[i + 1]) * k[i + 3]) / k[i + 4]
		var lat := (x - k[i]) * -k[i + 3] + (z - k[i + 1]) * k[i + 2]
		if t >= 0 and t <= 1 and absf(lat) <= k[i + 5]:
			return i / 6
	return -1


func praticable(L: Dictionary, x: float, z: float) -> bool:
	if _liaison_a(L, x, z) >= 0:
		return true
	var w: PackedFloat64Array = L._w
	var ok := false
	for i in range(0, w.size(), 4):
		if x >= w[i] and x <= w[i + 1] and z >= w[i + 2] and z <= w[i + 3]:
			ok = true
			break
	if not ok:
		return false
	var h: PackedFloat64Array = L._h
	for i in range(0, h.size(), 4):
		if x > h[i] and x < h[i + 1] and z > h[i + 2] and z < h[i + 3]:
			return false
	return true


## Distance signée au bord de l'obstacle le plus proche, plafonnée à REACH ; -1 hors surface praticable (clearanceAt).
## Les obstacles exportés sont ceux que voit la navigation (nav ≠ false).
func degagement(level: float, x: float, z: float) -> float:
	var L = niveaux.get(level)
	if L == null:
		return -1.0
	# praticable(), déroulée : c'est la question la plus posée de toute la navigation
	var k: PackedFloat64Array = L._k
	var dedans := false
	for i in range(0, k.size(), 6):
		var t := ((x - k[i]) * k[i + 2] + (z - k[i + 1]) * k[i + 3]) / k[i + 4]
		if t >= 0 and t <= 1 and absf((x - k[i]) * -k[i + 3] + (z - k[i + 1]) * k[i + 2]) <= k[i + 5]:
			dedans = true
			break
	if not dedans:
		var w: PackedFloat64Array = L._w
		for i in range(0, w.size(), 4):
			if x >= w[i] and x <= w[i + 1] and z >= w[i + 2] and z <= w[i + 3]:
				dedans = true
				break
		if not dedans:
			return -1.0
		var h: PackedFloat64Array = L._h
		for i in range(0, h.size(), 4):
			if x > h[i] and x < h[i + 1] and z > h[i + 2] and z < h[i + 3]:
				return -1.0
	var best := REACH
	var b = _seaux.get(level)
	if b == null:
		return best
	var liste = b.get(floori(x / CELL) * 4096 + floori(z / CELL))
	if liste == null:
		return best
	var f := _of
	# les distances comme Math.hypot de V8 (voir _hypot), déroulées
	for i in liste:
		var t := _ot[i]
		if t < 0:
			continue
		var o: int = i * 6
		var a: float
		var c: float
		var r := 0.0
		var dedans_boite := false
		if t == 0:
			a = absf(x - f[o])
			c = absf(z - f[o + 1])
			r = f[o + 2]
		elif t == 1:
			var ex := f[o + 2] - f[o]
			var ez := f[o + 3] - f[o + 1]
			var l2 := ex * ex + ez * ez
			var u := 0.0
			if l2:
				u = clampf(((x - f[o]) * ex + (z - f[o + 1]) * ez) / l2, 0.0, 1.0)
			a = absf(x - f[o] - ex * u)
			c = absf(z - f[o + 1] - ez * u)
			r = f[o + 4]
		else:
			a = maxf(maxf(f[o] - x, 0.0), x - f[o + 1])
			c = maxf(maxf(f[o + 2] - z, 0.0), z - f[o + 3])
			dedans_boite = not (a or c)
		var d: float
		if dedans_boite:
			d = -minf(minf(x - f[o], f[o + 1] - x), minf(z - f[o + 2], f[o + 3] - z))
		else:
			var m := maxf(a, c)
			if m == 0.0:
				d = -r
			else:
				var p := a / m
				var q := c / m
				d = sqrt(p * p + q * q) * m - r
		if d < best:
			best = d
	return best


# --------------------------------------------------------------------------------------------------
# Navigation (engine.js)
# --------------------------------------------------------------------------------------------------

## Les distances comme Math.hypot de V8 (normalisées par le plus grand terme, somme compensée), au dernier bit
## près : l'A* départage les chemins de même longueur sur ces valeurs. Vector2 et Vector3 calculent en simple précision.
static func _hypot(a: float, b: float) -> float:
	a = absf(a)
	b = absf(b)
	var m := maxf(a, b)
	if m == 0.0:
		return 0.0
	var x := a / m
	var y := b / m
	var s1 := x * x
	var s2 := y * y
	var pre := s1 + s2
	return sqrt(pre) * m


static func _hypot3(a: float, b: float, c: float) -> float:
	a = absf(a)
	b = absf(b)
	c = absf(c)
	var m := maxf(maxf(a, b), c)
	if m == 0.0:
		return 0.0
	var sum := 0.0
	var comp := 0.0
	for v in [a, b, c]:
		var n: float = v / m
		var summand := n * n - comp
		var pre := sum + summand
		comp = (pre - sum) - summand
		sum = pre
	return sqrt(sum) * m


func _hk(level: float, x: float, z: float) -> String:
	return "%s:%d,%d" % [level, floori(x / HCELL), floori(z / HCELL)]


## La ligne de a à b garde-t-elle `clear` de dégagement tous les 12 cm (segClear) ? Le calcul de degagement() y est
## déroulé, avec le niveau et la case lus une fois : c'est le cœur du lissage des chemins.
func libre(a: Dictionary, b: Dictionary, clear := NAV_CLEAR, level := 0.0) -> bool:
	var ax: float = a.x
	var az: float = a.z
	var bx: float = b.x
	var bz: float = b.z
	var d := _hypot(bx - ax, bz - az)
	var n := maxi(1, ceili(d / 0.12))
	var L = niveaux.get(level)
	if L == null:
		return false
	var k: PackedFloat64Array = L._k
	var w: PackedFloat64Array = L._w
	var h: PackedFloat64Array = L._h
	var ks := k.size()
	var ws := w.size()
	var hs := h.size()
	var seaux = _seaux.get(level)
	var f := _of
	var cle := -2147483648
	var liste := PackedInt32Array()
	for s in n + 1:
		var tt := float(s) / n
		var x := ax + (bx - ax) * tt
		var z := az + (bz - az) * tt
		var dedans := false
		for i in range(0, ks, 6):
			var t := ((x - k[i]) * k[i + 2] + (z - k[i + 1]) * k[i + 3]) / k[i + 4]
			if t >= 0 and t <= 1 and absf((x - k[i]) * -k[i + 3] + (z - k[i + 1]) * k[i + 2]) <= k[i + 5]:
				dedans = true
				break
		if not dedans:
			for i in range(0, ws, 4):
				if x >= w[i] and x <= w[i + 1] and z >= w[i + 2] and z <= w[i + 3]:
					dedans = true
					break
			if not dedans:
				return false
			for i in range(0, hs, 4):
				if x > h[i] and x < h[i + 1] and z > h[i + 2] and z < h[i + 3]:
					return false
		if seaux == null:
			if REACH < clear:
				return false
			continue
		var c2 := floori(x / CELL) * 4096 + floori(z / CELL)
		if c2 != cle:
			cle = c2
			var l2 = seaux.get(c2)
			liste = l2 if l2 != null else PackedInt32Array()
		var best := REACH
		for i in liste:
			var ty := _ot[i]
			if ty < 0:
				continue
			var o: int = i * 6
			var p: float
			var q: float
			var r := 0.0
			var boite := false
			if ty == 0:
				p = absf(x - f[o])
				q = absf(z - f[o + 1])
				r = f[o + 2]
			elif ty == 1:
				var ex := f[o + 2] - f[o]
				var ez := f[o + 3] - f[o + 1]
				var e2 := ex * ex + ez * ez
				var u := 0.0
				if e2:
					u = clampf(((x - f[o]) * ex + (z - f[o + 1]) * ez) / e2, 0.0, 1.0)
				p = absf(x - f[o] - ex * u)
				q = absf(z - f[o + 1] - ez * u)
				r = f[o + 4]
			else:
				p = maxf(maxf(f[o] - x, 0.0), x - f[o + 1])
				q = maxf(maxf(f[o + 2] - z, 0.0), z - f[o + 3])
				boite = not (p or q)
			var dd: float
			if boite:
				dd = -minf(minf(x - f[o], f[o + 1] - x), minf(z - f[o + 2], f[o + 3] - z))
			else:
				var m := maxf(p, q)
				if m == 0.0:
					dd = -r
				else:
					var pp := p / m
					var qq := q / m
					dd = sqrt(pp * pp + qq * qq) * m - r
			if dd < best:
				best = dd
				if best < clear:
					return false
		if best < clear:
			return false
	return true


func _graphes() -> void:
	var n := noeuds.size()
	adj = []
	adj_pnj = []
	adj.resize(n)
	adj_pnj.resize(n)
	noeud_personnel.resize(n)
	for i in n:
		adj[i] = []
		adj_pnj[i] = []
		noeud_personnel[i] = 1 if est_personnel(nx[i], nz[i], nl[i]) else 0
	var par_paire := {}
	for k in liaisons:
		par_paire[Vector2i(k.nodes[0], k.nodes[1])] = k
	var asc_paire := {}
	for E in ascenseurs:
		for i in E.stops.size():
			for j in range(i + 1, E.stops.size()):
				var a = E.stops[i].navNode
				var b = E.stops[j].navNode
				if a != null and b != null:
					asc_paire[Vector2i(a, b)] = E
	for e in aretes:
		var a := int(e[0])
		var b := int(e[1])
		var k = par_paire.get(Vector2i(a, b))
		var E = asc_paire.get(Vector2i(a, b))
		# engine.js : la liaison et l'ascenseur ont leur coût, le reste la distance à plat
		var d: float
		var via = null
		if k != null:
			d = float(k.length) + 1.2
			via = {"type": k.type, "id": k.id}
		elif E != null:
			d = 8.0 + absf(ny[a] - ny[b]) * 1.2
			via = {"type": "elevator", "id": E.id}
		else:
			d = _hypot(nx[a] - nx[b], nz[a] - nz[b])
		adj[a].append([b, d, via])
		adj[b].append([a, d, via])
		# npc.js navGraph : même graphe, escalators dans leur sens
		if nl[a] == nl[b]:
			var dd := _hypot(nx[a] - nx[b], nz[a] - nz[b])
			adj_pnj[a].append([b, dd, null])
			adj_pnj[b].append([a, dd, null])
			continue
		var la = noeuds[a].get("link")
		if la != null and la == noeuds[b].get("link"):
			var L = liaison_par_id.get(la)
			if L == null:
				continue
			var lo := a if nl[a] == float(L.a) else b
			var hi := b if lo == a else a
			var v := {"type": L.type, "id": L.id}
			var dl := float(L.length) + 1.2
			if not (L.type == "escalator" and float(L.speed) < 0):
				adj_pnj[lo].append([hi, dl, v])
			if not (L.type == "escalator" and float(L.speed) > 0):
				adj_pnj[hi].append([lo, dl, v])
			continue
		var EE = null
		for x in ascenseurs:
			var sa := false
			var sb := false
			for s in x.stops:
				if s.navNode == a: sa = true
				if s.navNode == b: sb = true
			if sa and sb:
				EE = x
				break
		if EE != null:
			var de := 8.0 + absf(ny[a] - ny[b]) * 1.2
			var ve := {"type": "elevator", "id": EE.id}
			adj_pnj[a].append([b, de, ve])
			adj_pnj[b].append([a, de, ve])


## Le nœud le plus proche que l'on rejoint en ligne droite (nearest).
func proche(p: Dictionary, max_try := 14, level := 0.0):
	var cand: Array = []
	var rad := 1
	while rad <= 4 and cand.size() < 6:
		cand.clear()
		var cx := floori(p.x / HCELL)
		var cz := floori(p.z / HCELL)
		for i in range(cx - rad, cx + rad + 1):
			for j in range(cz - rad, cz + rad + 1):
				var a = _hash.get("%s:%d,%d" % [level, i, j])
				if a != null:
					cand.append_array(a)
		rad += 1
	if cand.is_empty():
		for i in noeuds.size():
			if nl[i] == level:
				cand.append(i)
		if cand.is_empty():
			return -1
	# tri stable par distance (Array.prototype.sort l'est)
	var ordre: Array = []
	for r in cand.size():
		ordre.append([_hypot(nx[cand[r]] - p.x, nz[cand[r]] - p.z), r, cand[r]])
	ordre.sort_custom(func(u, v): return u[0] < v[0] or (u[0] == v[0] and u[1] < v[1]))
	for i in mini(ordre.size(), max_try if max_try else 14):
		if ordre[i][0] < 1e-3 or libre(p, _pt(ordre[i][2]), 0.22, level):
			return ordre[i][2]
	return ordre[0][2]


func _pt(i: int) -> Dictionary:
	return {"x": nx[i], "z": nz[i], "y": ny[i], "level": nl[i]}


## A* en tas binaire, tel quel (pour départager les égalités comme l'original).
func _astar(s: int, e: int, graphe: Array, personnel_ok := true):
	var N := noeuds.size()
	var g := PackedFloat64Array()
	g.resize(N); g.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(N); prev.fill(-1)
	var via: Array = []
	via.resize(N)
	var done := PackedByteArray()
	done.resize(N)
	var heap := PackedInt32Array()
	var hf := PackedFloat64Array()
	var ex := nx[e]; var ez := nz[e]; var ey := ny[e]
	var h := func(i: int) -> float: return _hypot3(nx[i] - ex, nz[i] - ez, ny[i] - ey)
	g[s] = 0.0
	_push(heap, hf, s, h.call(s))
	var found := false
	while heap.size():
		var u := _pop(heap, hf)
		if u == e:
			found = true
			break
		if done[u]:
			continue
		done[u] = 1
		for ed in graphe[u]:
			var v: int = ed[0]
			if not personnel_ok and noeud_personnel[v] and v != e:
				continue
			var ng: float = g[u] + ed[1]
			if ng < g[v]:
				g[v] = ng
				prev[v] = u
				via[v] = ed[2]
				_push(heap, hf, v, ng + h.call(v))
	if not found:
		return null
	var chain: Array = []
	var u := e
	while u != -1:
		var c := _pt(u)
		c["_via"] = via[u] if prev[u] != -1 else null
		chain.append(c)
		u = prev[u]
	chain.reverse()
	for i in range(chain.size() - 1, 0, -1):
		if chain[i]._via != null:
			chain[i - 1]["link"] = {"type": chain[i]._via.type, "id": chain[i]._via.id, "toLevel": chain[i].level}
	for c in chain:
		c.erase("_via")
	return chain


static func _push(heap: PackedInt32Array, hf: PackedFloat64Array, id: int, f: float) -> void:
	var i := heap.size()
	heap.append(id)
	hf.append(f)
	while i > 0:
		var p := (i - 1) >> 1
		if hf[p] <= f:
			break
		heap[i] = heap[p]
		hf[i] = hf[p]
		i = p
	heap[i] = id
	hf[i] = f


static func _pop(heap: PackedInt32Array, hf: PackedFloat64Array) -> int:
	var top := heap[0]
	var n := heap.size() - 1
	var lid := heap[n]
	var lf := hf[n]
	heap.resize(n)
	hf.resize(n)
	if n:
		var i := 0
		while true:
			var c := 2 * i + 1
			if c >= n:
				break
			if c + 1 < n and hf[c + 1] < hf[c]:
				c += 1
			if hf[c] >= lf:
				break
			heap[i] = heap[c]
			hf[i] = hf[c]
			i = c
		heap[i] = lid
		hf[i] = lf
	return top


## Lissage par tronçon de même niveau : on saute les points intermédiaires visibles, sans traverser une liaison.
func _lisser(pts: Array) -> Array:
	var out: Array = [pts[0]]
	var i := 0
	while i < pts.size() - 1:
		if pts[i].has("link"):
			out.append(pts[i + 1])
			i += 1
			continue
		var stop := i + 1
		while stop < pts.size() - 1 and not pts[stop].has("link") and pts[stop].level == pts[i].level:
			stop += 1
		if pts[stop].level != pts[i].level:
			stop -= 1
		var j := maxi(i + 1, stop)
		while j > i + 1 and not libre(pts[i], pts[j], NAV_CLEAR, pts[i].level):
			j -= 1
		if _hypot(pts[j].x - pts[i].x, pts[j].z - pts[i].z) > 1e-3 or pts[j].has("link"):
			out.append(pts[j])
		i = j
	return out


## Le chemin de l'original (nav.findPath) : [{ x, z, y, level, link? }], [] si aucun.
func chemin(from: Dictionary, to: Dictionary) -> Array:
	var la := float(from.level)
	var lb := float(to.level)
	var a := {"x": float(from.x), "z": float(from.z), "level": la, "y": niveau_y(la)}
	var b := {"x": float(to.x), "z": float(to.z), "level": lb, "y": niveau_y(lb)}
	if la == lb:
		if _hypot(a.x - b.x, a.z - b.z) < 1e-3:
			return [b]
		if libre(a, b, NAV_CLEAR, la):
			return [a, b]
	var s = proche(a, 14, la)
	var e = proche(b, 14, lb)
	if s < 0 or e < 0:
		return []
	var chain = _astar(s, e, adj)
	if chain == null:
		return []
	return _lisser([a] + chain + [b])


## Le chemin d'un PNJ (npc.js route) : celui de l'original, refait sur le graphe à sens uniques et sans les zones
## du personnel quand il prend un escalator à contresens ou fait passer un client chez le personnel.
func route(from: Dictionary, to: Dictionary, personnel_ok: bool):
	var p := chemin(from, to)
	if p.size() and not _viole(p, personnel_ok):
		return p
	var la := float(from.level)
	var lb := float(to.level)
	var s = proche(from, 14, la)
	var e = proche(to, 14, lb)
	if s < 0 or e < 0:
		return null
	var chain = _astar(s, e, adj_pnj, personnel_ok)
	if chain == null:
		return null
	var a := {"x": float(from.x), "z": float(from.z), "level": la, "y": niveau_y(la)}
	var b := {"x": float(to.x), "z": float(to.z), "level": lb, "y": niveau_y(lb)}
	var out := _lisser([a] + chain + [b])
	return out if out.size() else null


func _viole(path: Array, personnel_ok: bool) -> bool:
	for i in path.size():
		var p: Dictionary = path[i]
		if p.has("link") and p.link.type == "escalator":
			var L = liaison_par_id.get(p.link.id)
			if L != null and float(L.speed) and ((float(L.speed) > 0) != (float(p.link.toLevel) == float(L.b))):
				return true
		if not personnel_ok and i > 0 and est_personnel(p.x, p.z, p.level):
			return true
	return false


## Un point de flânerie : un nœud du treillis du niveau (randomPoint). `alea` tire dans [0, 1[.
func point_au_hasard(level: float, alea: float) -> Dictionary:
	var L = niveaux.get(level)
	var g: Array = L.grid if L != null else []
	if g.is_empty():
		return {"x": 0.0, "z": 0.0, "level": level, "y": 0.0}
	var i: int = g[floori(alea * g.size())]
	return _pt(i)


# --------------------------------------------------------------------------------------------------
# Zones (engine.js zoneAt, npc.js zones du personnel)
# --------------------------------------------------------------------------------------------------

func zone_a(x: float, z: float, level: float):
	var best = null
	var ba := 1e12
	var near = null
	var nd := 1e12
	for zn in zones:
		if zn.level != level:
			continue
		var b: Dictionary = zn.bounds
		var dx := maxf(maxf(b.x0 - x, 0.0), x - b.x1)
		var dz := maxf(maxf(b.z0 - z, 0.0), z - b.z1)
		if not dx and not dz:
			var ar: float = (b.x1 - b.x0) * (b.z1 - b.z0)
			if ar < ba:
				ba = ar
				best = zn
		else:
			var d := _hypot(dx, dz)
			if d < nd:
				nd = d
				near = zn
	return best if best != null else near


func zone_de(x: float, z: float, level: float) -> String:
	var zn = zone_a(x, z, level)
	return zn.id if zn != null else ""


func est_personnel(x: float, z: float, level: float) -> bool:
	return zone_personnel.has(zone_de(x, z, level))


func _zones_du_personnel() -> void:
	var sz := zone_personnel
	for id in zones_closes:
		sz[id] = 1
	for zn in zones:
		if zn.scene == "coulisses":
			sz[zn.id] = 1
	for p in points.get("door", []):
		if p.get("staff", false) and p.has("to"):
			sz[p.to] = 1
	for it in donnees.doors:
		if "staff" in it.tags and it.get("zone"):
			sz[it.zone] = 1
	for _pass in 3:
		for zn in zones:
			if sz.has(zn.id):
				continue
			var portes := 0
			for p in points.get("door", []):
				if zone_de(p.x, p.z, float(p.level)) == zn.id or p.get("to") == zn.id:
					portes += 1
			var lks: Array = []
			for k in liaisons:
				if k.zone == zn.id or zone_de(k.fx - k.dx, k.fz - k.dz, float(k.a)) == zn.id or zone_de(k.tx + k.dx, k.tz + k.dz, float(k.b)) == zn.id:
					lks.append(k)
			if portes or lks.is_empty():
				continue
			var tous := true
			for k in lks:
				var za := zone_de(k.fx - k.dx, k.fz - k.dz, float(k.a))
				var zb := zone_de(k.tx + k.dx, k.tz + k.dz, float(k.b))
				if not sz.has(zb if za == zn.id else za):
					tous = false
					break
			if tous:
				sz[zn.id] = 1
