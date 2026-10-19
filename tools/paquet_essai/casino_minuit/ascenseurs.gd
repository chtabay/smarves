extends RefCounted
## Les ascenseurs de l'original (js/engine.js : addElevator, updateElevators) : la cabine boisée qui suit sa
## hauteur, les deux vantaux d'acier de chaque palier qui s'écartent, le voyant vert quand ils sont ouverts, la
## porte qu'on ne traverse que cabine à quai, le bouton d'appel sur le palier et le tableau de bord dans la
## cabine. La marche des cabines est celle des PNJ (pnj/pnj.gd : update_elevators), qui les prennent aussi ;
## le joueur debout dans la cabine part avec elle.
##
## Les vantaux et le voyant viennent du décor exporté (nœuds « elevator-stop-<id> ») ; la cabine, que l'export
## laisse de côté, est refaite ici avec les matières de kit.js. Les parois des paliers sont les obstacles de
## l'original (donnees/pnj_monde.json, colliders « elevator » et « elevator-door »).

const H := 2.5
## Le voyant (MeshBasicMaterial de three.js r128, setHex : la valeur est prise telle quelle, en linéaire).
const VERT := Color(0x7d / 255.0, 1.0, 0xb0 / 255.0)
const ETEINT := Color(0x40 / 255.0, 0x20 / 255.0, 0x15 / 255.0)

var scene: Node3D
var K
var pnj
## id → { E, noeud (cabine), plancher (AnimatableBody3D), panneau (Area3D) }
var cabines := {}
## « id|niveau » → { S, vantaux [[nœud, côté]], voyant (matière), porte (CollisionShape3D), appel (Area3D) }
var arrets := {}


func _init(s: Node3D, kit, p) -> void:
	scene = s
	K = kit
	pnj = p


func poser() -> void:
	if pnj == null:
		return
	var racine := Node3D.new()
	racine.name = "Ascenseurs"
	scene.add_child(racine)
	for E in pnj.elev_list:
		_cabine(racine, E)
		for S in E.stops:
			_arret(racine, E, S)
	_parois(racine)
	_decor()


# --- la cabine (engine.js : la cabine suit E.y) ---------------------------------------------------

func _cabine(racine: Node3D, E: Dictionary) -> void:
	var w: float = E.w
	var d: float = E.d
	var cab := Node3D.new()
	cab.name = "elevator-" + E.id
	cab.position = Vector3(E.x, E.y, E.z)
	cab.rotation.y = E.facing
	racine.add_child(cab)
	var marbre := _std("#2b2430", 0.4, 0.1)
	var bois_sombre := _std("#3a1a12", 0.62, 0.05)
	var bois := _std("#6a2c1a", 0.55, 0.05)
	var laiton := _std("#d9a441", 0.36, 0.5, "#4a3410")
	var chrome := _std("#c4c8cf", 0.28, 0.7, "#26262c")
	var lueur := StandardMaterial3D.new()
	lueur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lueur.albedo_color = Color("#ffe2b4")
	K.lueurs.append([lueur, lueur.albedo_color, "albedo"])
	_box(cab, marbre, w, 0.06, d, 0, -0.03, 0)
	_box(cab, bois_sombre, w, 0.08, d, 0, H + 0.04, 0)
	_box(cab, bois, w, H, 0.05, 0, H / 2.0, d / 2.0 - 0.025)
	for s in [-1.0, 1.0]:
		_box(cab, bois, 0.05, H, d, s * (w / 2.0 - 0.025), H / 2.0, 0)
	_box(cab, lueur, w * 0.6, 0.02, d * 0.6, 0, H - 0.01, 0)
	_box(cab, laiton, w - 0.2, 0.05, 0.05, 0, 1.0, d / 2.0 - 0.09)
	for s in [-1.0, 1.0]:
		_box(cab, laiton, 0.05, 0.05, d - 0.3, s * (w / 2.0 - 0.09), 1.0, 0)
	_box(cab, chrome, 0.22, 0.4, 0.03, w / 2.0 - 0.06, 1.25, -d / 2.0 + 0.35, PI / 2.0)
	# le plancher qu'on foule : il porte le joueur d'un niveau à l'autre
	var pl := AnimatableBody3D.new()
	pl.name = "Plancher"
	pl.sync_to_physics = false
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(w, 0.06, d)
	f.shape = b
	f.position.y = -0.03
	pl.add_child(f)
	cab.add_child(pl)
	# le tableau de bord, dans la cabine
	var pn := Area3D.new()
	pn.name = "Panneau"
	pn.set_meta("interact", "ascenseur_panneau")
	pn.set_meta("ascenseur", E.id)
	pn.set_meta("prompt", "")
	pn.position.y = 1.2
	var fp := CollisionShape3D.new()
	var bp := BoxShape3D.new()
	bp.size = Vector3(w, 2.2, d)
	fp.shape = bp
	pn.add_child(fp)
	cab.add_child(pn)
	cabines[E.id] = {"E": E, "noeud": cab, "plancher": pl, "panneau": pn}


func _std(c: String, rugosite: float, metal: float, emissive := "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c)
	m.roughness = rugosite
	m.metallic = metal
	if emissive != "":
		m.emission_enabled = true
		m.emission = Color(emissive)
	return m


func _box(parent: Node3D, mat: Material, w: float, h: float, d: float, x: float, y: float, z: float, ry := 0.0) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(w, h, d)
	m.mesh = b
	m.material_override = mat
	m.position = Vector3(x, y, z)
	m.rotation.y = ry
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)


# --- un palier : le bouton d'appel ------------------------------------------------------------------

func _arret(racine: Node3D, E: Dictionary, S: Dictionary) -> void:
	var a := Area3D.new()
	a.name = "Appel-%s-%d" % [E.id, int(S.level)]
	a.set_meta("interact", "ascenseur_appel")
	a.set_meta("ascenseur", E.id)
	a.set_meta("niveau", S.level)
	a.set_meta("prompt", "Appeler l'ascenseur")
	a.position = Vector3(S.outside.x, S.y + 1.2, S.outside.z)
	var f := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.0
	f.shape = sp
	a.add_child(f)
	racine.add_child(a)
	arrets["%s|%d" % [E.id, int(S.level)]] = {"E": E, "S": S, "vantaux": [], "voyant": null, "porte": null, "appel": a}


# --- les parois des paliers et leurs portes (obstacles de l'original) --------------------------------

func _parois(racine: Node3D) -> void:
	var corps := StaticBody3D.new()
	corps.name = "Parois"
	racine.add_child(corps)
	for c in pnj.M.obstacles:
		var tag := str(c.get("tag", ""))
		if tag != "elevator" and tag != "elevator-door":
			continue
		var y: float = pnj.M.niveau_y(c.level)
		var ax: float = c.x0
		var az: float = c.z0
		var bx: float = c.x1
		var bz: float = c.z1
		var l := Vector2(bx - ax, bz - az).length()
		var f := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(l + 2.0 * float(c.r), 2.4, 2.0 * float(c.r))
		f.shape = b
		f.position = Vector3((ax + bx) / 2.0, y + 1.2, (az + bz) / 2.0)
		f.rotation.y = atan2(-(bz - az), bx - ax)
		corps.add_child(f)
		if tag == "elevator-door":
			# la porte de quel arrêt : celui dont le seuil est au milieu du segment
			for k in arrets:
				var A: Dictionary = arrets[k]
				if float(A.S.level) == float(c.level) and Vector2(A.S.doorAt.x - (ax + bx) / 2.0, A.S.doorAt.z - (az + bz) / 2.0).length() < 0.3:
					A.porte = f


# --- les vantaux et le voyant du décor exporté --------------------------------------------------------

func _decor() -> void:
	for g in scene.find_children("elevator-stop-*", "Node3D", true, false):
		var id := str(g.name).trim_prefix("elevator-stop-")
		# « elevator-stop-ASC-A2 » quand Godot a dû renommer un double
		var E = null
		for x in pnj.elev_list:
			if id.begins_with(x.id):
				E = x
		if E == null:
			continue
		var y: float = (g as Node3D).global_position.y
		var best = null
		for S in E.stops:
			if best == null or absf(S.y - y) < absf(best.y - y):
				best = S
		var A = arrets.get("%s|%d" % [E.id, int(best.level)])
		if A == null:
			continue
		for m in g.get_children():
			if not m is MeshInstance3D:
				continue
			if str(m.name).begins_with("elevator-leaf"):
				A.vantaux.append([m, signf((m as Node3D).position.x)])
			else:
				var mat := StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.albedo_color = ETEINT.linear_to_srgb()
				(m as MeshInstance3D).material_override = mat
				A.voyant = mat


# --- chaque image (appelé par pnj.update_elevators) ---------------------------------------------------

func animer() -> void:
	var p: CharacterBody3D = scene.player
	for id in cabines:
		var C: Dictionary = cabines[id]
		var E: Dictionary = C.E
		var cab: Node3D = C.noeud
		cab.position.y = E.y
		var vue := false
		for S in E.stops:
			if scene.zone_montree(S.zone):
				vue = true
		cab.visible = vue
		# le tableau de bord : cabine à quai, le joueur dedans
		var ok: bool = E.state == "idle" and E.stops.size() > 1 and p != null and pnj.elev_contains(E, p.global_position.x, p.global_position.z) \
			and absf(p.global_position.y - E.y) < 1.0
		var pn: Area3D = C.panneau
		pn.collision_layer = 1 if ok else 0
		if ok:
			var n: Dictionary = pnj.elev_next(E)
			pn.set_meta("prompt", "Ascenseur : %s — %s" % ["monter" if n.y > E.cur.y else "descendre", n.name])
		# le joueur qui monte ou descend reste sur le plancher
		if E.rider and p != null and p.global_position.y < E.y - 0.05:
			p.global_position.y = E.y + 0.02
			p.velocity.y = 0.0
	for k in arrets:
		var A: Dictionary = arrets[k]
		var E: Dictionary = A.E
		var S: Dictionary = A.S
		var dw: float = S.dw
		for v in A.vantaux:
			(v[0] as Node3D).position.x = v[1] * (dw / 4.0 + S.k * dw / 2.0)
		if A.voyant != null:
			(A.voyant as StandardMaterial3D).albedo_color = (VERT if S.k > 0.5 else ETEINT).linear_to_srgb()
		if A.porte != null:
			(A.porte as CollisionShape3D).disabled = S.k > 0.6
		var appel: Area3D = A.appel
		var actif: bool = not (E.state == "idle" and E.cur == S)
		appel.collision_layer = 1 if actif else 0
		appel.set_meta("prompt", "Appeler l'ascenseur" if E.state == "idle" else "L'ascenseur arrive…")


## Le bouton d'appel ou le tableau de bord.
func utiliser(cible: Node) -> void:
	var E = pnj.elevators.get(str(cible.get_meta("ascenseur", "")))
	if E == null:
		return
	if str(cible.get_meta("interact")) == "ascenseur_appel":
		pnj.elev_go(E, cible.get_meta("niveau"))
	else:
		pnj.elev_go(E, pnj.elev_next(E).level)
