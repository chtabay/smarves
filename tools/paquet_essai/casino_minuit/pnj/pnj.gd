extends Node3D
## Les PNJ de Casino Minuit, portés de js/npc.js (PNJ V2) : la population du casino sur ses niveaux. Les clients
## vivent de leurs besoins (jouer, boire, manger, se reposer, discuter, regarder, les toilettes, l'argent), le
## personnel tient son poste (croupiers, barmen, caissiers, cuisiniers, opérateurs, pianiste…), les vigiles font
## leur ronde, les serveurs prennent les commandes, les agents d'entretien nettoient, les convoyeurs font le circuit
## du cash avec leur chariot. Les embrouilles montent par paliers jusqu'aux coups ; la sécurité arrive et escorte
## l'agresseur. Le joueur peut frapper (F, ou clic gauche) : riposte, fuite, appel à la sécurité, poursuite,
## arrestation et amende en salle d'entretien.
##
## Tout vient des données de l'original (donnees/pnj_monde.json : stations, places, points, liaisons, ascenseurs,
## gabarits) et de son graphe de navigation (monde.gd, vérifié chemin pour chemin contre l'original) ; les sections
## et les noms suivent ceux de npc.js. Ce que le portage n'a pas : games.js (les PNJ font toujours semblant aux
## tables), les voix et les bruitages synthétisés, les écrans de surveillance. Les chemins se cherchent sur un fil à
## part (le graphe est le même ; la réponse arrive une image ou deux plus tard, comme quand l'original n'avait plus
## de budget de chemins dans l'image).

const BASE := "res://communes/casino_minuit/"
const PI2 := TAU

# ==================================================================================================
# 1. Réglages et données
# ==================================================================================================
var CFG := {
	"population": 120, "staffShare": 0.39, "seatShare": 0.3, "spawnEvery": [1.5, 5.0], "fightEvery": [110.0, 170.0],
	"provokeEvery": [240.0, 420.0], "courierEvery": [50.0, 100.0], "fine": 150, "playerHp": 100.0, "npcPunch": 14.0,
	"playerReach": 1.9, "nearSim": 34.0, "farEvery": 4, "pathsPerFrame": 1, "fullRate": 14, "bubbles": 10, "voice": true,
	"far": 38.0,
}

const NAMES_F := ["Camille", "Léa", "Manon", "Chloé", "Inès", "Jeanne", "Margaux", "Élise", "Clémence", "Aurélie", "Mathilde", "Sophie", "Lucie", "Agathe", "Juliette", "Noémie", "Solène", "Capucine", "Hélène", "Océane",
	"Nina", "Anaïs", "Zoé", "Louise", "Alice", "Rose", "Emma", "Jade", "Eva", "Sarah", "Marion", "Laura", "Pauline", "Céline", "Yasmine", "Fanny", "Irène", "Salomé", "Victoire", "Maud"]
const NAMES_M := ["Hugo", "Louis", "Jules", "Arthur", "Lucas", "Théo", "Antoine", "Maxime", "Étienne", "Bastien", "Gaspard", "Rémi", "Clément", "Adrien", "Victor", "Octave", "Mathieu", "Raphaël", "Félix", "Baptiste",
	"Nathan", "Paul", "Léon", "Samuel", "Marius", "Oscar", "Simon", "Quentin", "Tristan", "Yanis", "Karim", "Loïc", "Damien", "Fabrice", "Gilles", "Hervé", "Ismaël", "Joseph", "Kevin", "Noé"]
const TOPS := ["#7a1f2b", "#1f3a5f", "#2f5d50", "#c9a24a", "#e8e2d0", "#4a2d5e", "#24242a", "#b5482f", "#3c6e8f", "#cfcfd6", "#8c2f5a", "#5b6b2e", "#1d6a72", "#d98a9a", "#6b6f7a", "#234a2c"]
const BOTTOMS := ["#1b1b20", "#23283a", "#3a2f28", "#4b4b52", "#1d2b24", "#2c2230", "#6b6257", "#2a3550", "#54463a"]
const HAIRS := ["#2a1a10", "#0f0d0c", "#7a5a2a", "#b9952f", "#8c8c90", "#5c2a14", "#3b2b20", "#d9d2c4", "#6e1f1f"]
const SKINS := [1.0, 1.0, 1.0, 0.82, 0.66, 0.5, 1.08]
## Les matières que RE_TOP, RE_BOTTOM et RE_HAIR de npc.js désignent (par leur nom exact), et celles des modèles character62.
const RE_TOP := ["Shirt", "Shirt2", "Dress", "Jacket", "LightJacket", "Suit", "LimeGreen", "Purple", "Orange"]
const RE_BOTTOM := ["Pants", "LightBlue"]
const RE_HAIR := ["Hair", "Hair2", "Hair_Blond", "Hair_Brown"]
const RE_TOP62 := {"real-casual-man": ["White"], "real-casual-woman": ["White"], "real-hoodie-man": ["Purple"]}
const RE_BOT62 := {"real-casual-woman": ["Orange"]}

const LOOKS := {
	"dealer": [["dealer-businessman", null], ["dealer-woman-green", null], ["dealer-businessman", {"Suit": "#3a1220", "Tie": "#101010"}], ["dealer-woman-green", {"LimeGreen": "#6e1423"}]],
	"barman": [["dealer-businessman", {"Suit": "#2b2b33", "Tie": "#7a1420"}], ["dealer-woman-green", {"LimeGreen": "#23232a", "Gold": "#d9a441"}]],
	"guard": [["dealer-businessman", {"Suit": "#15171a", "Tie": "#15171a", "White": "#e8e8e8"}], ["man-suit", null], ["real-swat", {"Swat": "#1b1d20", "Swat_Black": "#101010"}], ["dealer-businessman", {"Suit": "#15171a", "Tie": "#15171a", "White": "#e8e8e8", "Skin": "#7a5a3c", "Hair": "#0f0d0c"}]],
	"waiter": [["dealer-businessman", {"Suit": "#f2f0ea", "Tie": "#101010", "Black": "#17181b"}], ["dealer-woman-green", {"LimeGreen": "#17181b", "Gold": "#e8e8e8"}]],
	"cook": [["dealer-businessman", {"Suit": "#f4f4f4", "Tie": "#f4f4f4", "Black": "#3a3a3a"}]],
	"cashier": [["dealer-woman-green", {"LimeGreen": "#7a1420", "Gold": "#d9a441"}], ["dealer-businessman", {"Suit": "#5a1220", "Tie": "#d9a441"}]],
	"desk": [["dealer-woman-green", {"LimeGreen": "#1f3a5f", "Gold": "#d9a441"}], ["dealer-businessman", {"Suit": "#1f2c44", "Tie": "#d9a441"}], ["woman-dress", {"Dress": "#1f2c44"}]],
	"floor": [["man-suit", null], ["dealer-businessman", {"Suit": "#2a2a30", "Tie": "#d9a441"}]],
	"operator": [["dealer-businessman", {"Suit": "#3b4350", "Tie": "#20242a", "White": "#b9c0c8"}], ["woman-casual", {"Shirt": "#3b4350", "Pants": "#20242a"}]],
	"counter": [["real-worker", {"Worker_Vest": "#3b4350", "Worker_Yellow": "#3b4350"}], ["dealer-businessman", {"Suit": "#3b4350", "Tie": "#3b4350", "White": "#b9c0c8"}]],
	"janitor": [["real-worker", {"Worker_Vest": "#2b4a6b", "Worker_Yellow": "#2b4a6b", "Brown": "#3a4046", "Brown2": "#2c3136"}]],
	"courier": [["real-swat", {"Swat": "#2f3b2a", "Swat_Black": "#1c2219"}], ["real-worker", {"Worker_Vest": "#20242a", "Worker_Yellow": "#20242a"}]],
	"pianist": [["man-suit", null]],
}
const TEMPERS := {
	"compulsif": {"w": 2.0, "play": 2.3, "eat": 0.6, "drink": 0.8, "relax": 0.4, "social": 0.4, "watch": 0.4, "heat": 0.5, "guts": 0.5, "persona": "flambeur"},
	"flaneur": {"w": 3.0, "play": 0.5, "eat": 1.0, "drink": 0.8, "relax": 1.4, "social": 1.0, "watch": 2.0, "heat": 0.2, "guts": 0.3, "persona": "prudent"},
	"fetard": {"w": 2.0, "play": 1.0, "eat": 0.8, "drink": 2.4, "relax": 0.6, "social": 1.8, "watch": 0.8, "heat": 0.8, "guts": 0.7, "persona": "flambeur"},
	"grincheux": {"w": 1.5, "play": 1.2, "eat": 0.9, "drink": 1.2, "relax": 0.8, "social": 0.3, "watch": 0.7, "heat": 1.6, "guts": 0.9, "persona": "superstitieux"},
	"prudent": {"w": 3.0, "play": 0.9, "eat": 1.1, "drink": 0.7, "relax": 1.2, "social": 0.9, "watch": 1.1, "heat": 0.15, "guts": 0.2, "persona": "prudent"},
	"bavard": {"w": 2.0, "play": 0.7, "eat": 1.0, "drink": 1.1, "relax": 1.0, "social": 2.5, "watch": 1.0, "heat": 0.4, "guts": 0.4, "persona": "superstitieux"},
}
const LINES := {
	"bousculade": [["Hé ! Regardez où vous allez !", "C'est vous qui m'êtes rentré dedans."], ["Vous m'avez bousculé !", "Mais pas du tout !"]],
	"mauvaise main": [["Tu portes la poisse, toi.", "Pardon ?!"], ["C'était MA carte !", "Apprends à jouer."]],
	"alcool": [["T'as renversé mon verre !", "T'as assez bu comme ça."], ["Qu'est-ce que t'as à me regarder ?", "Va cuver ailleurs."]],
	"place prise": [["C'était ma place !", "Fallait pas la quitter."], ["Cette machine est à moi.", "Y a pas ton nom dessus."]],
	"shove": ["Lâche-moi !", "Dégage !", "Me touche pas !", "Recule !"],
	"blow": ["Tiens !", "Prends ça !", "Tu l'as cherché !"],
	"hurt": ["Aïe !", "Ouch !", "Arrête !", "Ma mâchoire…"],
	"call": ["Sécurité !", "Appelez la sécurité !", "À l'aide !"],
	"guard": ["Sécurité ! On se calme !", "Ça suffit, messieurs-dames !", "On se sépare, tout de suite !"],
	"escort": ["Vous venez avec nous.", "Par ici, sans histoire.", "On va discuter au calme."],
	"escortOut": ["Vous sortez. Maintenant.", "La soirée est finie pour vous."],
	"filming": ["Je filme, je filme !", "Ça part sur les réseaux…", "Oh là là…"],
	"gawk": ["Oh !", "Non mais regardez-moi ça…", "Ils sont fous !", "Hé, ça va pas ?"],
	"victim": ["Merci… ça va aller.", "Quel malade…", "J'ai rien fait, moi !"],
	"order": ["Un steak, saignant.", "La carte, s'il vous plaît.", "Une salade et un verre de blanc.", "Le plat du jour."],
	"served": ["Merci !", "Ah, parfait.", "Ça a l'air bon."],
	"bill": ["L'addition, s'il vous plaît.", "On peut régler ?"],
	"waiter": ["Tout de suite.", "Et voici pour vous.", "Bon appétit !"],
	"bar": ["Un whisky, sans glace.", "La même chose.", "Un cocktail maison."],
	"provoke": ["Hé, toi ! Tu m'as regardé de travers ?", "T'as un problème, toi ?", "C'est toi qui as pris ma place tout à l'heure !"],
	"provoke2": ["Je te parle !", "Tu réponds pas ?", "Tu vas voir…"],
	"provokeEnd": ["C'est ça, dégage…", "Trouillard.", "Pfff."],
	"riposte": ["Tu vas le regretter !", "Ah tu veux jouer à ça ?", "Viens là !"],
	"flee": ["Au secours !", "Il est fou !", "Laissez-moi !"],
	"arrest": ["Sécurité ! Ne bougez plus !", "Vous, là ! On ne bouge plus !"],
	"cashier": ["Des jetons de 25, merci.", "Je voudrais encaisser.", "Vous prenez la carte ?"],
	"courier": ["Convoi de fonds, laissez passer.", "Reculez, s'il vous plaît."],
}
const GAME_TYPES := {"blackjack": 1, "craps": 1, "slot": 1}
const DECO_TYPES := {"roulette": 1, "baccarat": 1, "poker": 1, "wheel": 1, "slot-deco": 1}
const CAP := {"blackjack": 3, "craps": 4, "bar": 4, "slot": 1, "roulette": 3, "baccarat": 3, "poker": 4, "wheel": 2}
const ROUNDS := {"blackjack": [4, 10], "craps": [5, 14], "slot": [8, 24]}
const R_NPC := 0.27
const FADE := 0.25
const SEAT_BACK := 0.36
const SIT_TIME := 0.5
const BLOB_CAP := 160
## Les lieux à seuil du portage et les zones de l'original qu'ils ferment aux clients tant que le joueur ne les a pas
## ouverts : le personnel y garde son poste (comme dans les zones du personnel), les clients n'y vont pas.
const LIEUX_FERMES := {"hautes_limites": ["R-HL"], "lucullus": ["M-RESTAURANT"], "boutiques": ["M-BOUTIQUES"],
	"arene": ["F-ARENE", "F-ARENE-SALLE", "F-RING"], "concert": ["F-CONCERT", "F-CONCERT-SAS", "F-SCENE"]}

# --------------------------------------------------------------------------------------------------
# État du module
# --------------------------------------------------------------------------------------------------
var scene: Node3D
var M
var CORPS
var HUD
var ready_ := false
var now := 0.0
var frame := 0
var serial := 0
var target_pop := 0
var pop_auto := true
var spawn_t := 0.0
var templates := {}
var all: Array = []
var clients: Array = []
var staff: Array = []
var by_id := {}
var used_names := {}
var manifest_roles := {}
var log_ := {"crossWaits": 0, "acts": {}, "events": [], "fights": 0, "interventions": 0, "tours": 0, "arrests": 0, "stuck": 0, "pathFail": 0, "leaks": 0,
	"paths": 0, "pathFallback": 0, "elevVirtual": 0, "teleports": 0, "failBy": {}}
## Les ascenseurs de l'original (engine.js), leur état ; la cabine du décor suit E.y.
var elevators := {}
var elev_list: Array = []
## Le joueur vu des PNJ : position, niveau, mode (walk | seated), station et place, liaison.
var J := {"x": 0.0, "z": 0.0, "y": 0.0, "level": 0.0, "mode": "walk", "station": null, "seat": null, "link": null, "elevator": null}
## Pour les essais : les chemins cherchés dans l'image (sans fil), le joueur et la caméra posés à la main.
var synchrone := false
var essai := false
var _hors_scene := false
## Les lieux encore fermés aux clients (seuils de Smarves) : ni concert ni arène pour eux tant qu'ils le sont.
var lieux_fermes: Array = []


func note(k: String) -> void:
	log_.acts[k] = int(log_.acts.get(k, 0)) + 1


func event(type: String, d := {}) -> void:
	var e := {"t": snappedf(now, 0.1), "type": type}
	e.merge(d)
	log_.events.append(e)
	if log_.events.size() > 400:
		log_.events.pop_front()


static func rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


static func rr(r: Array) -> float:
	return rnd(r[0], r[1])


static func irnd(a: int, b: int) -> int:
	return floori(a + randf() * (b - a + 1))


static func pick(a: Array):
	return a[floori(randf() * a.size())]


static func ang_diff(a: float, b: float) -> float:
	var d := fmod(a - b, PI2)
	if d > PI:
		d -= PI2
	elif d < -PI:
		d += PI2
	return d


static func yaw_to(dx: float, dz: float) -> float:
	return atan2(-dx, -dz)


static func ease_(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


static func dist(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func has_tag(o, t: String) -> bool:
	return o != null and o.has("tags") and t in o.tags


static func any_tag(o, re: RegEx) -> bool:
	if o == null or not o.has("tags"):
		return false
	for t in o.tags:
		if re.search(str(t)) != null:
			return true
	return false


func turn(n: Dictionary, target: float, rate: float, dt: float) -> float:
	var d := ang_diff(target, n.yaw)
	var m := rate * dt
	n.yaw += m if d > m else (-m if d < -m else d)
	return -d if d < 0 else d


## Tirage pondéré.
static func wpick(items: Array, wf: Callable):
	var tot := 0.0
	var ws: Array = []
	for it in items:
		var w := maxf(0.0, float(wf.call(it)))
		tot += w
		ws.append(w)
	if tot <= 0.0:
		return null
	var r := randf() * tot
	for i in items.size():
		r -= ws[i]
		if r <= 0.0:
			return items[i]
	return items[items.size() - 1]


static func _re(s: String) -> RegEx:
	var r := RegEx.new()
	r.compile(s)
	return r


var RE_INTERPELLE := _re("^(interpelle|cellule)$")
var RE_CAISSE := _re("^(caisse|change|argent)$")
var RE_BOUTIQUE := _re("boutique|vente|shop|vitrine")
var RE_ECRANS := _re("^(écrans|ecrans|match)$")
var RE_MANGE := _re("mange-debout|discuter")
var RE_VITRINE := _re("vitrine|boutique")
var RE_CLIENT_TPL := _re("^dealer-|real-swat|real-worker|man-suit")


# ==================================================================================================
# Mise en place
# ==================================================================================================

## La scène de la commune (minuit.gd) : le joueur, la caméra, les zones montrées. `fermes` : les lieux à seuil fermés.
func preparer(s: Node3D, fermes: Array = []) -> bool:
	scene = s
	name = "PNJ"
	M = load(BASE + "pnj/monde.gd").new()
	var zc: Array = []
	for l in fermes:
		zc.append_array(LIEUX_FERMES.get(l, []))
	lieux_fermes = fermes.duplicate()
	if not M.charger(BASE + "donnees/pnj_monde.json", zc):
		return false
	CORPS = load(BASE + "pnj/corps.gd")
	for t in M.donnees.templates:
		templates[t.name] = t
		t.uses = 0
	manifest_roles = M.donnees.get("roles", {})
	for st in M.stations:
		for se in st.seats:
			se.occupant = null
			se._bad = 0
	_ascenseurs()
	_fil_demarrer()
	return true


func _ready() -> void:
	if scene == null:
		return
	HUD = load(BASE + "pnj/hud.gd").new()
	HUD.preparer(self)
	add_child(HUD)
	_rendu_preparer()
	start()


func _exit_tree() -> void:
	_fil_arreter()


# ==================================================================================================
# 3. Animation (corps.gd tient les clips ; ici, ce que le PNJ joue)
# ==================================================================================================
const ONCE := {"sitNative": 1, "sitNative#bas": 1, "fall": 1, "death": 1}
const SIT_UPPER := {"talk": 1, "eat": 1, "drink": 1, "phone": 1, "clap": 1, "interact": 1, "yes": 1, "no": 1, "foldArms": 1, "wave": 1, "railCall": 1}


func resolve_key(n: Dictionary, key: String) -> String:
	return n.corps.resoudre_cle(key)


func refresh_anim(n: Dictionary, fade = null) -> void:
	var seated: bool = n.seatState == "sitIn" or n.seatState == "seated" or (n.seatState == "standUp" and n.sitK > 0.3)
	var sitting: bool = seated and n.seat != null and n.seat.get("sit", false)
	var a := ""
	var b = null
	var start_at := 0.0
	var g = n.gest.key if n.gest != null else null
	if n.down:
		a = resolve_key(n, "fall")
		start_at = 99.0 if n.downHeld else 0.0
	elif sitting:
		var up = g if g != null else (n.base if SIT_UPPER.has(n.base) else null)
		a = n.tpl.sitKey
		start_at = 0.0 if n.seatState == "sitIn" else 1.2
		if up != null:
			var ru := resolve_key(n, up)
			if n.corps.a_clip(ru) and ru != "idle":
				a = n.tpl.sitKey + "#bas"
				b = ru + "#haut"
	elif g != null:
		a = g
	elif n.moveAnim != null:
		a = resolve_key(n, n.moveAnim)
	else:
		a = resolve_key(n, n.base)
	var key := a + "|" + str(b)
	if key == n.animKey:
		return
	n.animKey = key
	var f: float = (FADE if fade == null else float(fade)) if n.visible else 0.0
	n.corps.jouer(a, b, f, start_at)
	n.animDirty = true


func set_base(n: Dictionary, key: String, fade = null) -> void:
	if n.base != key:
		n.base = key
		refresh_anim(n, fade)


func set_move(n: Dictionary, key) -> void:
	if n.moveAnim != key:
		n.moveAnim = key
		refresh_anim(n)


## Geste ponctuel : joue `key` pendant dur secondes (défaut : durée du clip), puis revient à la pose de base.
func gesture(n: Dictionary, key: String, dur := 0.0, fade = null) -> float:
	var k := resolve_key(n, key)
	if not n.corps.a_clip(k) or k == "idle":
		return 0.0
	var d := dur if dur else maxf(0.3, n.corps.duree(k) - 0.12)
	n.gest = {"key": k, "until": now + d}
	n.animKey = ""
	n.corps.oublier(k)
	refresh_anim(n, 0.15 if fade == null else fade)
	return d


func clip_dur(n: Dictionary, key: String) -> float:
	return n.corps.duree(resolve_key(n, key))


func tick_gesture(n: Dictionary) -> void:
	if n.gest != null and now >= n.gest.until:
		n.gest = null
		refresh_anim(n)


func look_at_(n: Dictionary, x: float, z: float, pitch := 0.0, hold := 0.0) -> void:
	n.lookYawT = clampf(ang_diff(yaw_to(x - n.x, z - n.z), n.yaw), -1.05, 1.05)
	n.lookPitchT = pitch
	n.lookHold = hold if hold else 1.5


func lean_pulse(n: Dictionary, amount: float, hold := 0.0) -> void:
	n.leanT = amount
	n.leanHold = hold if hold else 0.6


func face(n: Dictionary, x: float, z: float, dt: float, rate := 0.0) -> float:
	return turn(n, yaw_to(x - n.x, z - n.z), rate if rate else 5.0, dt)


# ==================================================================================================
# 4. Lecture du monde : stations, points, files, zones du personnel
# ==================================================================================================
var world := {"use": {}, "lines": {}, "staffZone": {}, "exits": [], "brawl": [], "pairs": [], "publicLevels": [], "seats": 0, "detain": null, "pass": [], "cams": []}


func zone_of(x: float, z: float, level: float) -> String:
	return M.zone_de(x, z, level)


func is_staff_zone(x: float, z: float, level: float) -> bool:
	return world.staffZone.has(zone_of(x, z, level))


func station(id) -> Variant:
	return M.station_par_id.get(id)


## À quoi sert une station pour un client (null = pas pour lui).
func use_of(st: Dictionary):
	if st.seats.is_empty() or st.closed:
		return null
	var t: String = st.type
	if t == "work" or t == "staff" or has_tag(st, "personnel") or world.staffZone.has(st.zone):
		return "staff"
	if any_tag(st, RE_INTERPELLE):
		return "detain"
	if GAME_TYPES.has(t):
		return "play"
	if DECO_TYPES.has(t):
		return "deco"
	match t:
		"bar": return "drink"
		"dining", "restaurant": return "eat"
		"toilet": return "toilet"
		"sink": return "sink"
		"atm", "vending": return "atm"
		"counter": return "cashier" if any_tag(st, RE_CAISSE) else ("shop" if any_tag(st, RE_BOUTIQUE) else "desk")
		"lounge": return "match" if any_tag(st, RE_ECRANS) else "relax"
		"bench": return "relax"
		"stand": return "standup" if any_tag(st, RE_MANGE) else ("shop" if any_tag(st, RE_VITRINE) else "watch")
	return "relax" if st.seats[0].get("sit", false) else "watch"


func pts(kind: String) -> Array:
	return M.points.get(kind, [])


func index_world() -> void:
	world.staffZone = M.zone_personnel
	for k in M.points:
		for p in M.points[k]:
			p._zone = zone_of(p.x, p.z, p.level)
			p._occ = null
	var use := {}
	world.use = use
	world.seats = 0
	for st in M.stations:
		var u = use_of(st)
		st._use = u
		st._line = null
		st._staffNpc = null
		if u == null:
			continue
		if not use.has(u):
			use[u] = []
		use[u].append(st)
		if u != "staff" and u != "detain" and u != "sink":
			world.seats += st.seats.size()
	# files d'attente : points « queue » regroupés par file (line) ou par station
	var lines := {}
	world.lines = lines
	for p in pts("queue"):
		var id = p.get("line", p.get("station", "+".join(p.stations) if p.has("stations") else null))
		if id == null:
			continue
		if not lines.has(id):
			lines[id] = {"id": id, "slots": [], "stations": [], "members": []}
		var L: Dictionary = lines[id]
		L.slots.append(p)
		var sids: Array = p.stations if p.has("stations") else ([p.station] if p.has("station") else [])
		for sid in sids:
			var st = station(sid)
			if st != null and not st in L.stations:
				L.stations.append(st)
	for id in lines:
		var L: Dictionary = lines[id]
		var cle := func(a): return float(a.get("rank", a.get("order", 0)))
		_tri_stable(L.slots, func(a, b): return cle.call(a) < cle.call(b))
		for st in L.stations:
			st._line = L
	# sorties, zones d'embrouille, paires de discussion, niveaux publics
	world.exits = pts("door").filter(func(p): return p.get("exit", false))
	if world.exits.is_empty():
		for p in M.donnees.spawns:
			world.exits.append({"x": p.x, "z": p.z, "level": p.level})
	world.brawl = pts("brawl") + pts("embrouille")
	var pairs := {}
	var order: Array = []
	world.pairs = []
	for p in pts("chat"):
		if has_tag(p, "personnel") or world.staffZone.has(p._zone):
			continue
		if p.has("pair"):
			var k := "p" + str(p.pair)
			if not pairs.has(k):
				pairs[k] = []
				order.append(k)
			pairs[k].append(p)
		else:
			p._solo = true
	for k in order:
		if pairs[k].size() >= 2:
			world.pairs.append(pairs[k])
		else:
			pairs[k][0]._solo = true
	# points de discussion sans paire déclarée : appariés au plus proche à moins de 2 m
	var solo: Array = pts("chat").filter(func(p): return p.get("_solo", false))
	for p in solo:
		if p.get("_paired", false):
			continue
		var best = null
		var bd := 2.2
		for q in solo:
			if q != p and not q.get("_paired", false) and q.level == p.level:
				var d := dist(p, q)
				if d < bd:
					bd = d
					best = q
		if best != null:
			p._paired = true
			best._paired = true
			world.pairs.append([p, best])
	var lv := {}
	var lv_order: Array = []
	for zn in M.zones:
		if not world.staffZone.has(zn.id) and zn.bounds != null and zn.bounds.has("x0"):
			if not lv.has(zn.level):
				lv[zn.level] = 0.0
				lv_order.append(zn.level)
			lv[zn.level] += (zn.bounds.x1 - zn.bounds.x0) * (zn.bounds.z1 - zn.bounds.z0)
	world.publicLevels = []
	for l in lv_order:
		var g: Array = M.niveaux[l].grid if M.niveaux.has(l) else []
		if not g.is_empty():
			world.publicLevels.append({"level": l, "area": lv[l]})
	if world.publicLevels.is_empty():
		world.publicLevels = [{"level": 0.0, "area": 1.0}]
	# salle d'entretien : point « detain », sinon banc « interpelle »
	var dps: Array = pts("detain")
	var dss: Array = use.get("detain", [])
	if not dps.is_empty():
		var dp: Dictionary = dps[0]
		world.detain = {"x": dp.x, "z": dp.z, "level": dp.level, "station": station(dp.station) if dp.has("station") else (dss[0] if dss.size() else null)}
	elif not dss.is_empty():
		var ds: Dictionary = dss[0]
		world.detain = {"x": ds.seats[0].approach.x, "z": ds.seats[0].approach.z, "level": ds.level, "station": ds}
	else:
		world.detain = null
	world.pass = pts("service").filter(func(p): return not p.has("station"))
	world.cams = M.donnees.get("cameras", [])


func random_public_point(level: float, near = null, max_d := 0.0):
	for i in 12:
		var p: Dictionary = M.point_au_hasard(level, randf())
		if M.degagement(level, p.x, p.z) < 0.8 or is_staff_zone(p.x, p.z, level):
			continue
		if near != null and max_d and dist(p, near) > max_d:
			continue
		return {"x": p.x, "z": p.z, "level": level}
	return null


## Un point est-il sous l'œil d'une caméra de surveillance ? (même zone, ou à portée dans son champ)
func on_camera(x: float, z: float, level: float):
	var zid := zone_of(x, z, level)
	for c in world.cams:
		if float(c.get("level", 0)) != level:
			continue
		if c.get("zone", "") == zid:
			return c
		var dx: float = x - c.x
		var dz: float = z - c.z
		var d := Vector2(dx, dz).length()
		if d < 20 and c.has("yaw") and absf(ang_diff(yaw_to(dx, dz), c.yaw)) < 0.8:
			return c
	return null


static func _tri_stable(a: Array, inf: Callable) -> void:
	# Array.prototype.sort est stable ; sort_custom ne l'est pas : on départage par le rang d'origine.
	var tmp: Array = []
	for i in a.size():
		tmp.append([a[i], i])
	tmp.sort_custom(func(u, v): return inf.call(u[0], v[0]) or (not inf.call(v[0], u[0]) and u[1] < v[1]))
	for i in a.size():
		a[i] = tmp[i][0]


# ==================================================================================================
# 5. Navigation multi-niveaux
# ==================================================================================================
var paths_left := 0


## Le chemin de l'original (nav.findPath), refait sans les escalators à contresens et sans les zones du
## personnel pour un client (monde.route). Sur le fil des chemins, sauf en essai synchrone.
func _demander(n: Dictionary, v: Dictionary) -> void:
	log_.paths += 1
	var from := {"x": n.x, "z": n.z, "level": n.level}
	var ok: bool = n.kind != "client" or n.staffPass
	if synchrone:
		v.res = M.route(from, v.to, ok)
		v.has_res = true
		return
	_fil_demande(v, from, v.to, ok, v.urgent)


func link_by_id(id):
	return M.liaison_par_id.get(id)


## Grille d'évitement : corps debout par niveau, cases de 2 m, refaite à chaque image.
var grid := {}
var grid_list: Array = []


static func gkey(level: float, x: float, z: float) -> int:
	return int(level * 2 + 8) * 1048576 + (floori(x / 2) + 256) * 1024 + (floori(z / 2) + 256)


func build_grid() -> void:
	for a in grid_list:
		a.clear()
	for n in all:
		if n.hidden or (n.sitK > 0.5 and n.seat != null and n.seat.get("sit", false)):
			continue
		var k := gkey(n.level, n.x, n.z)
		var a = grid.get(k)
		if a == null:
			a = []
			grid[k] = a
			grid_list.append(a)
		a.append(n)


func neighbours(level: float, x: float, z: float) -> Array:
	var out: Array = []
	for i in range(-1, 2):
		for j in range(-1, 2):
			var a = grid.get(gkey(level, x + i * 2, z + j * 2))
			if a != null:
				out.append_array(a)
	return out


var av_lat := 0.0
var av_slow := 1.0


func avoid_one(n: Dictionary, ox: float, oz: float, moving: bool, ux: float, uz: float, senior: bool, range_: float) -> void:
	var dx: float = ox - n.x
	var dz: float = oz - n.z
	var d2 := dx * dx + dz * dz
	if d2 > range_ * range_ or d2 < 1e-6:
		return
	var d := sqrt(d2)
	var ahead := (dx * ux + dz * uz) / d
	if ahead < 0.15:
		return
	var side := dx * -uz + dz * ux
	var k := (range_ - d) / range_ * ahead
	av_lat += (-1.0 if side > 0.02 else 1.0) * k * 1.6
	if d < 0.62 and ahead > 0.5:
		var s := maxf(0.2 if (moving and not senior) else 0.55, (d - 0.3) / 0.32)
		if s < av_slow:
			av_slow = s


## Lance un déplacement. to : { x, z, level } ; o : { run, speed, stop, urgent }.
func go_to(n: Dictionary, to: Dictionary, o := {}) -> bool:
	n.nav = {"to": {"x": float(to.x), "z": float(to.z), "level": float(to.get("level", n.level))}, "path": null, "pi": 0, "run": o.get("run", false),
		"speed": float(o.get("speed", 0.0)), "stop": float(o.get("stop", 0.0)), "urgent": o.get("urgent", false), "state": "plan", "stuckT": 0.0,
		"stuckN": 0, "px": n.x, "pz": n.z, "ghost": 0.0, "repathAt": 0.0, "link": null, "elev": null, "t": 0.0, "req": false, "res": null, "has_res": false}
	return true


func stop_nav(n: Dictionary) -> bool:
	if n.nav != null and (n.nav.link != null or n.nav.elev != null):
		return false
	n.nav = null
	set_move(n, null)
	return true


func interruptible(n: Dictionary) -> bool:
	return not (n.nav != null and (n.nav.link != null or n.nav.elev != null)) and not n.down


func nav_speed(n: Dictionary, v: Dictionary) -> float:
	return v.speed if v.speed else n.speed * (2.5 if v.run else 1.0)


func move_key(n: Dictionary, v: Dictionary) -> String:
	return "run" if v.run else ("carry" if n.carry else "walk")


func set_walk_rate(n: Dictionary, k: float) -> void:
	n.corps.cadence(clampf(k, 0.35, 1.7))


## Avance le long du chemin. Renvoie « go », « done » ou « fail ».
func step_nav(n: Dictionary, dt: float) -> String:
	var v = n.nav
	if v == null:
		return "done"
	if v.state == "plan":
		if not v.req:
			if paths_left <= 0 and not v.urgent:
				return "go"
			paths_left -= 1
			v.req = true
			v.has_res = false
			_demander(n, v)
		if not v.has_res:
			return "go"
		var p = v.res
		v.req = false
		v.has_res = false
		v.res = null
		if p == null or (p as Array).is_empty():
			log_.pathFail += 1
			var k: String = (n.beh.type if n.beh != null else "?") + " → " + zone_of(v.to.x, v.to.z, v.to.level) + " depuis " + zone_of(n.x, n.z, n.level)
			log_.failBy[k] = int(log_.failBy.get(k, 0)) + 1
			n.nav = null
			set_move(n, null)
			# filet : un client qui n'arrive plus nulle part est remis sur le graphe et s'en va
			n.failN += 1
			if n.kind == "client" and n.failN >= 6 and n.failN % 6 == 0:
				unstick(n)
				n.staffPass = true
				n.retire = true
				event("lost", {"id": n.id})
			return "fail"
		v.path = p
		v.pi = 1 if p.size() > 1 else 0
		v.state = "walk"
		n.failN = 0
		if p.size() > 1 and p[0].has("link") and Vector2(p[0].x - n.x, p[0].z - n.z).length() < 0.15:
			start_link(n, v, p[0], p[1])
	if v.elev != null:
		return step_elevator(n, v, dt)
	if v.link != null:
		return step_link(n, v, dt)
	var path: Array = v.path
	var last := path.size() - 1
	var w: Dictionary = path[v.pi]
	var dx: float = w.x - n.x
	var dz: float = w.z - n.z
	var d := sqrt(dx * dx + dz * dz)
	while d < 0.12:
		if w.has("link") and v.pi < last:
			v.pi += 1
			start_link(n, v, w, path[v.pi])
			return "go"
		if v.pi >= last:
			n.nav = null
			set_move(n, null)
			return "done"
		v.pi += 1
		w = path[v.pi]
		dx = w.x - n.x
		dz = w.z - n.z
		d = sqrt(dx * dx + dz * dz)
	if v.stop and v.pi == last and d <= v.stop:
		n.nav = null
		set_move(n, null)
		return "done"
	set_move(n, move_key(n, v))
	var ux := dx / d
	var uz := dz / d
	var is_last: bool = v.pi == last and not w.has("link")
	var sp := nav_speed(n, v)
	# passage piéton du Strip : on n'engage pas la chaussée sans le bonhomme blanc
	if crossing_hold(n, ux, uz):
		if not n.waitCross:
			n.waitCross = true
			log_.crossWaits += 1
		set_move(n, null)
		turn(n, yaw_to(ux, uz), 4, dt)
		n.speedK = 0.0
		v.stuckT = 0.0
		v.px = n.x
		v.pz = n.z
		return "go"
	n.waitCross = false
	var err := turn(n, yaw_to(ux, uz), 9.0 if v.run else 5.5, dt)
	var k := 0.08 if err > 1.3 else (0.55 if err > 0.6 else 1.0)
	av_lat = 0.0
	av_slow = 1.0
	if v.ghost > 0:
		v.ghost -= dt
	elif n.near:
		for o in neighbours(n.level, n.x, n.z):
			if o != n and not o.down and o.follow != n and n.follow != o:
				avoid_one(n, o.x, o.z, o.nav != null, ux, uz, n.rank > o.rank or (n.rank == o.rank and n.slotId < o.slotId), 0.95)
		if J.mode == "walk" and J.level == n.level and n.chase != "player":
			avoid_one(n, J.x, J.z, false, ux, uz, false, 1.15)
	k *= av_slow
	var step := sp * k * dt
	if step > d:
		step = d
	var nx: float = n.x + ux * step
	var nz: float = n.z + uz * step
	if av_lat != 0.0 and not (is_last and d < 0.5):
		var lat := clampf(av_lat, -1, 1) * sp * 0.55 * dt
		var lx := nx - uz * lat
		var lz := nz + ux * lat
		if M.degagement(n.level, lx, lz) >= 0.26:
			nx = lx
			nz = lz
	var c1: float = M.degagement(n.level, nx, nz)
	if c1 >= 0.24 or c1 >= M.degagement(n.level, n.x, n.z):
		n.x = nx
		n.z = nz
		n.speedK = k
	else:
		# écarté du tracé par un évitement : on ne coupe pas le coin, on repart d'un chemin propre
		n.speedK = 0.2
		if now >= v.repathAt:
			v.repathAt = now + 1
			v.state = "plan"
			return "go"
		if c1 >= 0.12:
			n.x = nx
			n.z = nz
			n.speedK = k
	set_walk_rate(n, clampf(sp * n.speedK / (n.natural * 2.5), 0.6, 1.6) if v.run else n.speedK * sp / n.natural)
	# blocage : on recalcule, puis on passe en force (sans évitement), puis on renonce
	v.stuckT += dt
	if v.stuckT >= 2.2:
		var moved := Vector2(n.x - v.px, n.z - v.pz).length()
		v.stuckT = 0.0
		v.px = n.x
		v.pz = n.z
		if moved < 0.3 * minf(1.0, sp):
			v.stuckN += 1
			if v.stuckN == 1:
				v.state = "plan"
			elif v.stuckN <= 3:
				v.ghost = 3.0
			else:
				log_.stuck += 1
				unstick(n)
				n.nav = null
				set_move(n, null)
				return "fail"
		else:
			v.stuckN = 0
	return "go"


## Feux du Strip (boulevard.gd : K.places.e_feux, plan C.lotE.LAY) : vrai = le pas suivant entrerait sur une chaussée
## alors que les piétons n'ont pas le vert franc.
func crossing_hold(n: Dictionary, ux: float, uz: float) -> bool:
	if n.level != 0.0:
		return false
	var L = M.donnees.get("lay")
	var T = _feux()
	if L == null or T == null:
		return false
	var hw: float = L.CROSS + 0.35
	if n.x > hw + 1.5 or n.x < -hw - 1.5 or n.z < L.CURB0 - 1.5 or n.z > L.CURB1 + 1.5:
		return false
	if _bande(L, hw, n.x, n.z):
		return false
	if not _bande(L, hw, n.x + ux * 0.55, n.z + uz * 0.55):
		return false
	var t: float = T.t
	var ped_walk: bool = t >= 40.0 and t < 60.0
	return not (ped_walk and T.phase != "clignotant")


static func _bande(L: Dictionary, hw: float, x: float, z: float) -> bool:
	return x <= hw and x >= -hw and ((z > L.CURB0 and z < L.MED0) or (z > L.MED1 and z < L.CURB1))


func _feux():
	if scene == null or not "K" in scene or scene.K == null:
		return null
	var f = scene.K.places.get("e_feux")
	return f[0] if f is Array and f.size() else null


## Dernier recours : replacer le PNJ sur le nœud de navigation dégagé le plus proche de son niveau.
func unstick(n: Dictionary) -> void:
	var i: int = M.proche({"x": n.x, "z": n.z}, 20, n.level)
	if i >= 0:
		n.x = M.nx[i]
		n.z = M.nz[i]
		n.y = M.niveau_y(n.level)
		log_.teleports += 1
		event("unstick", {"id": n.id, "x": snappedf(n.x, 0.1), "z": snappedf(n.z, 0.1), "level": n.level})


# --- escaliers et escalators : ligne droite de bouche à bouche, altitude interpolée, file de droite ---
func start_link(n: Dictionary, v: Dictionary, from: Dictionary, to: Dictionary) -> void:
	var lk: Dictionary = from.link
	if lk.type == "elevator":
		var E = elevators.get(lk.id)
		if E != null and elev_stop(E, n.level) != null and elev_stop(E, lk.toLevel) != null:
			v.elev = {"E": E, "from": n.level, "to": float(lk.toLevel), "phase": "call", "t": 0.0, "virt": false}
			set_move(n, null)
			return
		n.level = float(lk.toLevel)
		n.y = M.niveau_y(n.level)
		n.x = to.x
		n.z = to.z
		return
	var L = link_by_id(lk.id)
	var len_ := Vector2(to.x - n.x, to.z - n.z).length()
	if not len_:
		len_ = 1.0
	var ux: float = (to.x - n.x) / len_
	var uz: float = (to.z - n.z) / len_
	v.link = {"L": L, "ax": n.x, "az": n.z, "bx": to.x, "bz": to.z, "toLevel": float(lk.toLevel), "s": 0.0, "len": len_, "ux": ux, "uz": uz,
		"lane": maxf(0.0, minf(L.hw - 0.45, 0.6)) * (0.55 + (n.slotId % 5) * 0.11) if L != null else 0.0}


static func link_y(L: Dictionary, x: float, z: float) -> Vector2:
	var t := clampf(((x - L.fx) * L.dx + (z - L.fz) * L.dz) / L.len, 0.0, 1.0)
	return Vector2(L.ya + (L.yb - L.ya) * t, t)


func step_link(n: Dictionary, v: Dictionary, dt: float) -> String:
	var k: Dictionary = v.link
	var L = k.L
	var esc: bool = L != null and L.type == "escalator" and float(L.get("speed", 0.0)) != 0.0
	var sp: float = absf(L.speed) if esc else nav_speed(n, v) * (0.7 if v.run else 0.82)
	# quelqu'un juste devant dans la même file : on ralentit
	if n.near:
		for o in neighbours(n.level, n.x, n.z):
			if o != n and o.nav != null and o.nav.link != null and o.nav.link.L == L:
				var dx: float = o.x - n.x
				var dz: float = o.z - n.z
				var a: float = dx * k.ux + dz * k.uz
				if a > 0.05 and a < 0.7 and absf(dx * -k.uz + dz * k.ux) < 0.4:
					sp *= 0.25
	k.s = minf(k.len, k.s + sp * dt)
	var u: float = k.s / k.len
	var w: float = minf(1.0, minf(k.s / 1.0, (k.len - k.s) / 1.0))
	var lat: float = k.lane * maxf(0.0, w)
	n.x = k.ax + (k.bx - k.ax) * u - k.uz * lat
	n.z = k.az + (k.bz - k.az) * u + k.ux * lat
	turn(n, yaw_to(k.ux, k.uz), 6, dt)
	if L != null:
		var r := link_y(L, n.x, n.z)
		n.y = r.x
		n.level = float(L.a) if r.y < 0.5 else float(L.b)
	if esc:
		set_move(n, null)
	else:
		set_move(n, move_key(n, v))
		set_walk_rate(n, 0.85)
	if k.s >= k.len - 1e-4:
		n.x = k.bx
		n.z = k.bz
		n.level = k.toLevel
		n.y = M.niveau_y(n.level)
		v.link = null
		v.stuckT = 0.0
		v.px = n.x
		v.pz = n.z
	return "go"


# --- ascenseur : appeler, attendre la cabine, entrer, choisir l'étage, sortir. Délais de garde : trajet « virtuel ». ---
func straight(n: Dictionary, tx: float, tz: float, dt: float, sp := 0.0) -> bool:
	var dx: float = tx - n.x
	var dz: float = tz - n.z
	var d := sqrt(dx * dx + dz * dz)
	if d < 0.03:
		n.x = tx
		n.z = tz
		return true
	var err := turn(n, yaw_to(dx, dz), 6, dt)
	var k := 0.05 if err > 1.2 else (0.5 if err > 0.5 else 0.9)
	var step := minf(d, (sp if sp else n.speed) * k * dt)
	n.x += dx / d * step
	n.z += dz / d * step
	n.speedK = k
	set_walk_rate(n, k)
	return d - step < 0.03


func step_elevator(n: Dictionary, v: Dictionary, dt: float) -> String:
	var e: Dictionary = v.elev
	var E: Dictionary = e.E
	var s_from: Dictionary = elev_stop(E, e.from)
	var s_to: Dictionary = elev_stop(E, e.to)
	e.t += dt
	if e.phase == "call":
		set_move(n, null)
		face(n, s_from.doorAt.x, s_from.doorAt.z, dt)
		if E.state == "idle" and elev_level(E) == e.from and elev_door_open(E, e.from):
			e.phase = "enter"
			e.t = 0.0
		else:
			if E.state == "idle" and elev_level(E) != e.from:
				elev_go(E, e.from)
			if e.t > 16:
				e.virt = true
				e.phase = "enter"
				e.t = 0.0
				log_.elevVirtual += 1
	elif e.phase == "enter":
		set_move(n, move_key(n, v))
		var ox = ((n.slotId % 3) - 1) * 0.45
		var oz = (((n.slotId >> 2) % 3) - 1) * 0.35
		if straight(n, s_from.inside.x + ox, s_from.inside.z + oz, dt) or e.t > 8:
			e.phase = "ride"
			e.t = 0.0
			set_move(n, null)
			if not e.virt and E.state == "idle":
				elev_go(E, e.to)
	elif e.phase == "ride":
		n.inElev = E
		face(n, s_from.doorAt.x, s_from.doorAt.z, dt)
		if e.virt:
			var k := clampf(e.t / 4.0, 0.0, 1.0)
			n.y = s_from.y + (s_to.y - s_from.y) * ease_(k)
			if k >= 1:
				n.level = e.to
				n.y = s_to.y
				e.phase = "exit"
				e.t = 0.0
		else:
			n.y = E.y
			if E.state == "moving" and E.t >= 0.5 and E.dest != null:
				n.level = float(E.dest.level)
			if E.state == "idle" and elev_level(E) == e.to:
				if elev_door_open(E, e.to):
					n.level = e.to
					n.y = s_to.y
					e.phase = "exit"
					e.t = 0.0
			elif E.state == "idle":
				elev_go(E, e.to)
			if e.t > 24:
				e.virt = true
				log_.elevVirtual += 1
				n.level = e.to
				n.y = s_to.y
				e.phase = "exit"
				e.t = 0.0
	else:
		n.inElev = null
		set_move(n, move_key(n, v))
		var w: Dictionary = v.path[v.pi]
		if straight(n, w.x, w.z, dt) or e.t > 8:
			n.x = w.x
			n.z = w.z
			n.level = e.to
			n.y = s_to.y
			v.elev = null
			v.stuckT = 0.0
			v.px = n.x
			v.pz = n.z
	return "go"


# --- suivre quelqu'un sur sa trace (escorte, équipier du convoyeur) ---
func leave_trail(n: Dictionary) -> void:
	if n.trail == null:
		n.trail = []
	var tr: Array = n.trail
	var l = tr[tr.size() - 1] if tr.size() else null
	if l == null or Vector2(l.x - n.x, l.z - n.z).length() > 0.22 or l.level != n.level or absf(l.y - n.y) > 0.3:
		tr.append({"x": n.x, "z": n.z, "y": n.y, "level": n.level, "link": n.nav != null and (n.nav.link != null or n.nav.elev != null)})
		if tr.size() > 48:
			tr.pop_front()


func follow_step(n: Dictionary, leader: Dictionary, back: float, side: float, dt: float) -> void:
	var tr = leader.trail
	var tx: float = leader.x
	var tz: float = leader.z
	var ty: float = leader.y
	var tl: float = leader.level
	var on_link: bool = leader.nav != null and (leader.nav.link != null or leader.nav.elev != null)
	if tr != null and tr.size():
		var acc := Vector2(leader.x - tr[tr.size() - 1].x, leader.z - tr[tr.size() - 1].z).length()
		var i: int = tr.size() - 1
		while i > 0 and acc < back:
			acc += Vector2(tr[i].x - tr[i - 1].x, tr[i].z - tr[i - 1].z).length()
			i -= 1
		var p: Dictionary = tr[i]
		tx = p.x
		tz = p.z
		ty = p.y
		tl = p.level
		on_link = p.link
	# décalage latéral (droite du meneur) si la place le permet
	if side:
		var sx := cos(leader.yaw) * side
		var sz := -sin(leader.yaw) * side
		if (absf(side) < 0.4) if on_link else (M.degagement(tl, tx + sx, tz + sz) >= 0.28):
			tx += sx
			tz += sz
	var dx: float = tx - n.x
	var dz: float = tz - n.z
	var d := Vector2(dx, dz).length()
	if d > 7 or (tl != n.level and d > 3 and not on_link):
		n.x = tx
		n.z = tz
		n.y = ty
		n.level = tl
		log_.teleports += 1
		return
	n.level = tl
	if leader.inElev != null and d < 3:
		n.y = leader.y
	else:
		n.y += (ty - n.y) * minf(1.0, dt * 8)
	if d < 0.12:
		set_move(n, null)
		turn(n, leader.yaw, 4, dt)
		return
	var sp := minf(d / maxf(dt, 1e-3), maxf(leader.speed, n.speed) * (2.2 if d > 1.2 else 1.15))
	turn(n, yaw_to(dx, dz) if d > 0.4 else leader.yaw, 7, dt)
	var step := minf(d, sp * dt)
	n.x += dx / d * step
	n.z += dz / d * step
	set_move(n, "run" if d > 2.5 else ("carry" if n.carry else "walk"))
	set_walk_rate(n, clampf(sp / n.natural, 0.5, 1.5))


# ==================================================================================================
# 6. Places
# ==================================================================================================
func claim_seat(st: Dictionary, index: int, who) -> bool:
	if index < 0 or index >= st.seats.size():
		return false
	var seat: Dictionary = st.seats[index]
	if seat.occupant != null:
		return false
	seat.occupant = who
	return true


func release_seat(st: Dictionary, index: int) -> void:
	if index < 0 or index >= st.seats.size():
		return
	st.seats[index].occupant = null


func npc_count(st: Dictionary) -> int:
	var c := 0
	for s in st.seats:
		if s.occupant != null and s.occupant != "player":
			c += 1
	return c


func free_count(st: Dictionary) -> int:
	var c := 0
	for s in st.seats:
		if s.occupant == null:
			c += 1
	return c


func player_station():
	return J.station if J.mode == "seated" else null


func free_seat(st: Dictionary):
	var free: Array = st.seats.filter(func(s): return s.occupant == null and not s._bad > 1)
	if free.is_empty():
		return null
	# à une table, de préférence à côté de quelqu'un
	var n_s: Array = free.filter(func(s):
		var i: int = int(s.index)
		return (i - 1 >= 0 and i - 1 < st.seats.size() and st.seats[i - 1].occupant != null) or (i + 1 < st.seats.size() and st.seats[i + 1].occupant != null))
	return pick(n_s) if n_s.size() and randf() < 0.6 else pick(free)


func claim(n: Dictionary, st: Dictionary, seat: Dictionary) -> bool:
	if not claim_seat(st, int(seat.index), n.id):
		return false
	n.station = st
	n.seat = seat
	return true


func unclaim(n: Dictionary) -> void:
	if n.seat != null and n.station != null and n.seat.occupant == n.id:
		release_seat(n.station, int(n.seat.index))
	n.station = null
	n.seat = null
	n.seatState = null
	n.sitK = 0.0
	if n.hidden and n.kind != "extra":
		n.hidden = false


## Où le PNJ s'arrête avant de s'asseoir : juste derrière l'assise.
static func seat_stop(seat: Dictionary) -> Vector2:
	var k := SEAT_BACK if seat.get("sit", false) else 0.0
	return Vector2(seat.position.x + sin(seat.facing) * k, seat.position.z + cos(seat.facing) * k)


## Depuis le point d'approche : rejoindre la place et s'installer.
func begin_sit(n: Dictionary) -> void:
	var p := seat_stop(n.seat)
	n.tx = p.x
	n.tz = p.y
	n.seatState = "toSeat"
	n.seatT = 0.0
	n.level = float(n.station.level)
	n.y = M.niveau_y(n.level)
	set_move(n, "carry" if n.carry else "walk")


func begin_stand(n: Dictionary, fast := false) -> void:
	if n.seatState == "toSeat" or n.seatState == null:
		unclaim(n)
		set_move(n, null)
		return
	if n.seatState == "standUp" or n.seatState == "fromSeat":
		return
	n.seatState = "standUp"
	n.seatT = 0.0
	n.standFast = fast
	n.gest = null
	n.lookYawT = 0.0
	n.lookPitchT = 0.0
	n.leanT = 0.0
	if n.hidden and n.kind != "extra":
		n.hidden = false
	if n.seat.get("sit", false) and not fast:
		gesture(n, "stand", 0.8)
	else:
		refresh_anim(n)


## Fait avancer l'installation / le lever ; renvoie l'état courant (null = libre).
func seat_step(n: Dictionary, dt: float):
	var seat = n.seat
	if n.seatState == null:
		return null
	n.seatT += dt
	if n.seatState == "fromSeat":
		if straight(n, n.tx, n.tz, dt) or n.seatT > 4:
			n.seatState = null
			set_move(n, null)
		return n.seatState
	if seat == null:
		n.seatState = null
		return null
	match n.seatState:
		"toSeat":
			if straight(n, n.tx, n.tz, dt) or n.seatT > 6:
				set_move(n, null)
				if seat.get("sit", false):
					n.seatState = "sitIn"
					n.seatT = 0.0
					refresh_anim(n)
				else:
					n.seatState = "seated"
					n.seatT = 0.0
					n.x = n.tx
					n.z = n.tz
		"sitIn":
			turn(n, seat.facing, 5, dt)
			var k0 := maxf(0.0, n.seatT - 0.12) / SIT_TIME
			n.sitK = 1.0 if k0 > 1 else k0
			var e := ease_(n.sitK)
			n.x = n.tx + (seat.position.x - n.tx) * e
			n.z = n.tz + (seat.position.z - n.tz) * e
			if n.seatT >= SIT_TIME + 0.3:
				n.sitK = 1.0
				n.x = seat.position.x
				n.z = seat.position.z
				n.yaw = seat.facing
				n.seatState = "seated"
				n.seatT = 0.0
				if n.station.type == "toilet":
					n.hidden = true
				refresh_anim(n)
		"seated":
			if not seat.get("sit", false):
				turn(n, seat.facing, 4, dt)
		"standUp":
			var T := 0.25 if n.standFast else SIT_TIME
			var finir := true
			if seat.get("sit", false):
				var k1: float = 1.0 - n.seatT / T
				n.sitK = 0.0 if k1 < 0 else k1
				var e := ease_(n.sitK)
				var p := seat_stop(seat)
				n.x = p.x + (seat.position.x - p.x) * e
				n.z = p.y + (seat.position.z - p.y) * e
				if n.seatT < (0.3 if n.standFast else 0.85):
					finir = false
				else:
					n.sitK = 0.0
			if finir:
				var st: Dictionary = n.station
				var i: int = int(seat.index)
				n.lastStation = st
				n.tx = seat.approach.x
				n.tz = seat.approach.z
				if seat.occupant == n.id:
					release_seat(st, i)
				n.station = null
				n.seat = null
				n.seatState = "fromSeat"
				n.seatT = 0.0
				n.gest = null
				set_move(n, "walk")
	return n.seatState


# ==================================================================================================
# 7. Comportements : cadre commun
# ==================================================================================================
## Un PNJ a un comportement courant n.beh = { type, phase, t, … } ; BEH[type] = { enter, step → vrai quand c'est fini,
## exit }. Les réservations (place, points, file, discussion) sont rendues par end_beh.
var BEH := {}


func _beh(type: String, enter = null, step = null, exit_ = null) -> void:
	BEH[type] = {"enter": enter, "step": step, "exit": exit_}


func set_beh(n: Dictionary, type: String, data := {}) -> Dictionary:
	if n.beh != null:
		end_beh(n)
	var b := {"type": type, "phase": 0, "t": 0.0}
	b.merge(data, true)
	n.beh = b
	n.state = type
	note(type if n.kind == "client" else n.role + ":" + type)
	var def: Dictionary = BEH[type]
	if def.enter != null:
		def.enter.call(n, b)
	return b


func free_points(n: Dictionary) -> void:
	for p in n.points:
		if p._occ == n.id:
			p._occ = null
	n.points.clear()


func take_point(n: Dictionary, p: Dictionary) -> bool:
	if p.get("_occ") != null and p._occ != n.id and by_id.has(p._occ):
		return false
	p._occ = n.id
	if not p in n.points:
		n.points.append(p)
	return true


func leave_line(n: Dictionary) -> void:
	if n.line != null:
		n.line.members.erase(n)
		n.line = null


func leave_conv(n: Dictionary) -> void:
	var c = n.conv
	if c == null:
		return
	n.conv = null
	c.members.erase(n)
	if c.members.size() < 2:
		c.over = true


func end_beh(n: Dictionary) -> void:
	var b = n.beh
	if b == null:
		return
	n.beh = null
	var def = BEH.get(b.type)
	if def != null and def.exit != null:
		def.exit.call(n, b)
	free_points(n)
	leave_line(n)
	leave_conv(n)
	if n.nav != null and n.nav.link == null and n.nav.elev == null:
		n.nav = null
		set_move(n, null)
	n.follow = null


func next_(n: Dictionary) -> void:
	if n.gone:
		return
	if n.kind == "client":
		set_beh(n, "decide")
	elif n.job != null:
		n.job.call(n)
	else:
		set_beh(n, "post")


## Coupe ce que fait le PNJ pour lui faire faire autre chose (jamais sur un escalier ni dans un ascenseur).
func interrupt(n: Dictionary, type: String, data := {}) -> bool:
	if not interruptible(n) or n.gone:
		return false
	end_beh(n)
	n.nav = null
	set_move(n, null)
	if n.seatState != null:
		set_beh(n, "getup", {"then": type, "data": data})
	else:
		set_beh(n, type, data)
	return true


func _beh_communs() -> void:
	_beh("getup", func(n, _b): begin_stand(n, true),
		func(n, b, dt):
			if seat_step(n, dt) != null:
				return false
			n.beh = null
			set_beh(n, b.then, b.data)
			return false)
	# attendre sur place : { dur, base }
	_beh("pause", func(n, b):
			set_base(n, b.get("base", "idle"))
			if not b.has("dur"):
				b.dur = rnd(2, 6)
			n.lookYawT = rnd(-0.7, 0.7)
			n.lookHold = b.dur,
		func(_n, b, _dt): return b.t >= b.dur,
		func(n, _b): set_base(n, "idle"))


# --- bulles et voix (cosmétique : jamais de décision qui en dépende) ---
func voice(_n: Dictionary, _mood := "calm", _dur := 1.6) -> void:
	pass


func sfx(_name: String, _n = null) -> void:
	pass


func speak(n: Dictionary, text: String, mood := "calm", dur := 0.0) -> void:
	say(n, text, dur)
	voice(n, mood, minf(2.6, 0.6 + text.length() * 0.05))


# ==================================================================================================
# 8. Clients : besoins, choix d'activité, activités
# ==================================================================================================
const NEED_RATE := {"play": 1.0 / 80, "hunger": 1.0 / 520, "thirst": 1.0 / 280, "bladder": 1.0 / 1100, "fatigue": 1.0 / 240, "social": 1.0 / 190, "curiosity": 1.0 / 150}


func base_npc(kind: String, role: String, tpl: Dictionary, teintes: Dictionary) -> Dictionary:
	serial += 1
	var gab: Dictionary = CORPS.gabarit(tpl)
	var c = CORPS.Corps.new(gab, teintes)
	var n := {
		"id": "npc-%d" % serial, "kind": kind, "role": role, "name": pick_name(tpl.female), "tpl": tpl, "model": tpl.name, "corps": c, "root": c.root,
		"x": 0.0, "z": 0.0, "y": 0.0, "level": 0.0, "yaw": 0.0, "state": "idle", "station": null, "seat": null,
		"sitK": 0.0, "seatState": null, "seatT": 0.0, "speedK": 1.0, "pace": 1.0, "natural": float(tpl.natural), "speed": float(tpl.natural),
		"visible": false, "zvis": false, "inScene": false, "cctvT": -9.0, "d2": 1e9, "mixAcc": 0.0, "slot": serial % 8, "slotId": serial,
		"rank": 1 if kind == "client" else 2, "simAcc": 0.0, "near": true, "moveAnim": null,
		"lookYaw": 0.0, "lookPitch": 0.0, "lookYawT": 0.0, "lookPitchT": 0.0, "lookHold": 0.0, "lean": 0.0, "leanT": 0.0, "leanHold": 0.0,
		"base": "idle", "gest": null, "animKey": "", "animDirty": true,
		"nav": null, "beh": null, "label": null, "hp": 3, "down": false, "downHeld": false, "downUntil": 0.0, "downT": 0.0, "hidden": false,
		"points": [], "line": null, "conv": null, "fight": null, "hostile": false, "hostileT": -99.0, "firstBlow": false, "hitByPlayerT": 0.0,
		"tx": 0.0, "tz": 0.0, "standFast": false, "lastStation": null, "waitCross": false, "failN": 0, "staffPass": false, "retire": false,
		"gone": false, "follow": null, "trail": null, "trailOn": false, "carry": false, "inElev": null, "joined": false, "meal": null, "glanceT": 0.0,
		"chase": null, "sx": 0.0, "sz": 0.0, "patrolI": 0, "post": null, "job": null, "table": null, "lastEvt": -100.0, "fakeT": 0.0, "wait": 0.0,
		"postSeat": false, "tray": null, "cart": null, "bag": null, "accs": [], "zLevel": -99.0, "mood": 0.7, "guts": 0.2, "heat": 0.0,
		"needs": null, "T": null, "temper": null, "drunk": 0.0, "sore": -99.0, "pref": null, "participant": null, "visits": 0, "maxVisits": 0,
		"lastUse": "", "forceStation": null, "afterToilet": null, "bornT": now, "kindLabel": "", "anim": null, "pose": null, "proxyOf": null,
		"venue": null, "vs": null,
	}
	c.root.visible = false
	add_child(c.root)
	all.append(n)
	by_id[n.id] = n
	return n


func pick_name(female: bool) -> String:
	var pool: Array = NAMES_F if female else NAMES_M
	for i in 14:
		var c: String = pick(pool)
		if not used_names.has(c):
			used_names[c] = 1
			return c
	return pick(pool)


## Les teintes d'un client (clientTint) : le premier exemplaire d'un modèle garde ses couleurs.
func client_tint(tpl: Dictionary) -> Dictionary:
	tpl.uses += 1
	var skin: float = 1.0 if tpl.uses <= 1 else pick(SKINS)
	if tpl.uses == 1:
		return {}
	var out := {}
	var top := Color(pick(TOPS))
	var bottom := Color(pick(BOTTOMS))
	var hair = Color(pick(HAIRS)) if randf() < 0.7 else null
	var tops: Array = RE_TOP if tpl.human else RE_TOP62.get(tpl.name, [])
	var bots: Array = RE_BOTTOM if tpl.human else RE_BOT62.get(tpl.name, ["LightBlue"])
	for m in tops:
		out[m] = top
	for m in bots:
		if not out.has(m):
			out[m] = bottom
	if hair != null:
		for m in RE_HAIR:
			if not out.has(m):
				out[m] = hair
	if skin != 1.0:
		out["Skin*"] = skin
	return out


## Les teintes d'un rôle (roleTint) : celles de la tenue, sinon celles du manifeste pour ce modèle.
func role_tint(role: String, tpl_name: String, by) -> Dictionary:
	var mr = manifest_roles.get(role)
	var mt = mr.get("tints", {}).get("assets/characters/" + tpl_name + ".glb") if mr is Dictionary else null
	var out := {}
	if mt is Dictionary and by == null:
		for k in mt:
			out[k] = Color(mt[k])
	if by is Dictionary:
		for k in by:
			out[k] = Color(by[k])
	return out


func create_client():
	var pool: Array = []
	for k in templates:
		if RE_CLIENT_TPL.search(k) == null:
			pool.append(templates[k])
	if pool.is_empty():
		return null
	var tpl: Dictionary = wpick(pool, func(t): return 1.0 / (1 + t.uses))
	var n := base_npc("client", "client", tpl, client_tint(tpl))
	var tk: String = wpick(TEMPERS.keys(), func(k): return TEMPERS[k].w)
	var T: Dictionary = TEMPERS[tk]
	n.temper = tk
	n.T = T
	n.pace = rnd(0.8, 1.02)
	n.speed = n.natural * n.pace
	n.needs = {"play": rnd(0.2, 0.9), "hunger": rnd(0, 0.6), "thirst": rnd(0, 0.7), "bladder": rnd(0, 0.45), "fatigue": rnd(0, 0.4), "social": rnd(0, 0.7), "curiosity": rnd(0.1, 0.8)}
	n.mood = rnd(0.45, 0.9)
	n.drunk = 0.0
	n.sore = -99.0
	n.heat = T.heat * rnd(0.6, 1.3)
	n.guts = clampf(T.guts * rnd(0.6, 1.4), 0, 1)
	n.pref = {"blackjack": rnd(0.4, 1.6), "craps": rnd(0.4, 1.6), "slot": rnd(0.4, 1.6), "deco": rnd(0.5, 1.4)}
	n.participant = {"id": n.id, "name": n.name, "isPlayer": false, "bankroll": roundi(rnd(200, 1500) / 10) * 10, "persona": T.persona}
	n.visits = 0
	n.maxVisits = irnd(5, 12)
	n.lastStation = null
	n.lastUse = ""
	n.forceStation = null
	n.retire = false
	n.bornT = now
	n.hp = 3
	n.wait = 0.0
	clients.append(n)
	return n


func remove_npc(n: Dictionary) -> void:
	if n.gone:
		return
	end_beh(n)
	n.gone = true
	n.nav = null
	if n.seat != null and n.station != null:
		unclaim(n)
	_bulle_retirer(n)
	used_names.erase(n.name)
	by_id.erase(n.id)
	clients.erase(n)
	staff.erase(n)
	all.erase(n)
	(n.root as Node).queue_free()


# --- quelles stations sont ouvertes à un client ---
func open_(st: Dictionary) -> bool:
	return not (st.has("staff") and st.type != "bar" and st._use != "eat" and st._use != "staff" and st.type != "counter" and st._staffNpc == null) \
		and not (st.type == "counter" and st.has("staff") and st._staffNpc == null)


func en_route(st: Dictionary) -> bool:
	for n in clients:
		if n.station == st and n.seatState != "seated":
			return true
	return false


func eligible(st: Dictionary, for_player_table: bool) -> bool:
	if not open_(st):
		return false
	var free := free_count(st)
	if not free:
		return false
	if st.seats.size() > 2 and free <= 1:
		return false
	if npc_count(st) >= int(CAP.get(st.type, st.seats.size())):
		return false
	if for_player_table and en_route(st):
		return false
	return true


func far_k(n: Dictionary, st: Dictionary) -> float:
	return 1.0 / (1.0 + (Vector2(st.position.x - n.x, st.position.z - n.z).length() + absf(M.niveau_y(st.level) - n.y) * 4) / 28.0)


func choose_play(n: Dictionary):
	var ps = player_station()
	var slots: Array = world.use.get("play", []).filter(func(s): return s.type == "slot")
	var max_slots := maxi(3, roundi(slots.size() * 0.6))
	var slots_used := 0
	for st in slots:
		if npc_count(st):
			slots_used += 1
	var cands: Array = []
	for st in world.use.get("play", []) + world.use.get("deco", []):
		if not eligible(st, st == ps):
			continue
		if st.type == "slot" and slots_used >= max_slots:
			continue
		var k := npc_count(st)
		var w: float = (0.12 if st == n.lastStation else 1.0) * far_k(n, st) * float(n.pref.get(st.type, n.pref.deco))
		if st.type != "slot" and st.type != "slot-deco":
			w *= 1 + 0.45 * mini(k, 2)
		else:
			w *= 0.45 if st.type == "slot-deco" else 0.9
		if st == ps and k < 2:
			w *= 8
		cands.append({"st": st, "w": w})
	var c = wpick(cands, func(x): return x.w)
	if c == null:
		return null
	var seat = free_seat(c.st)
	return {"st": c.st, "seat": seat} if seat != null else null


func choose_of(n: Dictionary, use: String, filter = null):
	var list: Array = world.use.get(use, []).filter(func(st): return free_count(st) > 0 and open_(st) and (filter == null or filter.call(st)))
	var st = wpick(list, func(s): return far_k(n, s) * (0.2 if s == n.lastStation else 1.0) * (((1.6 if n.T.social > 1 else 0.5) if npc_count(s) else 1.0) if (use == "eat" or use == "relax") else 1.0))
	if st == null:
		return null
	var seat = free_seat(st)
	return {"st": st, "seat": seat} if seat != null else null


func use_station(n: Dictionary, c, extra := {}) -> bool:
	if c == null or not claim(n, c.st, c.seat):
		return false
	var d := {"st": c.st, "seat": c.seat, "use": c.st._use}
	d.merge(extra, true)
	set_beh(n, "use", d)
	return true


# --- décision : le besoin le plus pressant parmi ce que le casino offre ---
func tick_needs(n: Dictionary, dt: float) -> void:
	var N: Dictionary = n.needs
	var T: Dictionary = n.T
	N.play += NEED_RATE.play * T.play * dt
	N.hunger += NEED_RATE.hunger * T.eat * dt
	N.thirst += NEED_RATE.thirst * T.drink * dt
	N.bladder += NEED_RATE.bladder * (1 + n.drunk) * dt
	N.fatigue += NEED_RATE.fatigue * (1.5 if n.nav != null else 0.6) * dt
	N.social += NEED_RATE.social * T.social * dt
	N.curiosity += NEED_RATE.curiosity * T.watch * dt
	if n.drunk > 0:
		n.drunk = maxf(0.0, n.drunk - dt / 420)
	if n.mood < 0.6:
		n.mood += dt / 600


func _beh_clients() -> void:
	_beh("decide", func(n, b):
			set_base(n, "idle")
			b.wait = n.wait if n.wait else rnd(0.2, 1.2)
			n.wait = 0.0,
		func(n, b, _dt):
			if b.t < b.wait:
				return false
			decide(n)
			if n.beh == b:
				b.t = 0.0
				b.wait = rnd(1, 2.5)
			return false)
	_beh("use", _use_enter, _use_step, _use_exit)
	_beh("spot", func(n, b):
			b.dur = rnd(10, 28)
			b.watching = b.p.get("station")
			go_to(n, b.p),
		func(n, b, dt):
			if b.phase == 0:
				var r := step_nav(n, dt)
				if r == "fail":
					return true
				if r == "done":
					b.phase = 1
					b.t = 0.0
					set_base(n, "phone" if b.kind == "wait" and randf() < 0.4 else ("foldArms" if randf() < 0.35 else "idle"))
					note("point:" + b.kind)
				return false
			var p: Dictionary = b.p
			if p.has("look"):
				face(n, p.look.x, p.look.z, dt, 4)
			elif p.has("facing"):
				turn(n, p.facing, 4, dt)
			n.needs.curiosity = maxf(0.0, n.needs.curiosity - dt / 18)
			return b.t >= b.dur,
		func(n, _b): set_base(n, "idle"))
	_beh("wander", func(n, b):
			var lv: Array = world.publicLevels
			var L: float = n.level if randf() < 0.78 and lv.any(func(l): return l.level == n.level) else (wpick(lv, func(l): return l.area) if wpick(lv, func(l): return l.area) != null else lv[0]).level
			var p = random_public_point(L)
			if p == null:
				p = random_public_point(n.level)
			if p == null:
				b.phase = 2
				b.dur = 2.0
				return
			go_to(n, p),
		func(n, b, dt):
			if b.phase == 0:
				var r := step_nav(n, dt)
				if r == "fail":
					return true
				if r == "done":
					b.phase = 1
					b.t = 0.0
					b.dur = rnd(2, 6)
					set_base(n, "idle")
					n.lookYawT = rnd(-0.7, 0.7)
					n.lookHold = b.dur
				return false
			return b.t >= b.get("dur", 2.0))
	_beh("phone", func(n, b):
			b.dur = rnd(8, 18)
			set_base(n, "phone")
			voice(n, "calm", 2)
			b.vT = rnd(3, 6),
		func(n, b, dt):
			b.vT -= dt
			if b.vT <= 0:
				b.vT = rnd(3, 6)
				voice(n, "calm", 2)
			return b.t >= b.dur,
		func(n, _b): set_base(n, "idle"))
	_beh("leave", func(n, b):
			var ex = wpick(world.exits, func(e): return 1.0 / (1 + dist(e, n) / 20))
			if ex == null and world.exits.size():
				ex = world.exits[0]
			b.ex = ex
			if ex != null:
				go_to(n, ex),
		func(n, b, dt):
			if b.ex == null:
				remove_npc(n)
				return false
			var r := step_nav(n, dt)
			if r == "fail":
				b.phase += 1
			if r == "done" or (r == "fail" and b.phase > 3) or b.t > 240:
				note("sortie")
				remove_npc(n)
				return false
			if r == "fail":
				b.t = maxf(b.t, 1.0)
				go_to(n, b.ex, {"urgent": true})
			return false)
	_beh("chat", func(n, b):
			var c: Dictionary = b.conv
			c.members.append(n)
			n.conv = c
			if not b.p.get("_temp", false):
				take_point(n, b.p)
			go_to(n, b.p),
		_chat_step, func(n, _b): set_base(n, "idle"))
	_beh("queue", func(n, b):
			b.line.members.append(n)
			n.line = b.line
			b.slot = -1
			note("file"),
		_queue_step, func(n, _b): set_base(n, "idle"))


func decide(n: Dictionary) -> void:
	var N: Dictionary = n.needs
	var U: Dictionary = world.use
	if n.retire or n.visits >= n.maxVisits or n.mood < 0.08:
		set_beh(n, "leave")
		return
	if n.forceStation != null:
		var st: Dictionary = n.forceStation
		n.forceStation = null
		if free_count(st) > 1 and open_(st):
			var s = free_seat(st)
			if s != null and use_station(n, {"st": st, "seat": s}):
				return
	if n.afterToilet != null:
		var z = n.afterToilet
		n.afterToilet = null
		if use_station(n, choose_of(n, "sink", func(st): return st.zone == z)):
			return
	var opts: Array = []
	var add := func(k: String, score: float, fn: Callable):
		if score > 0:
			opts.append({"k": k, "score": score * rnd(0.75, 1.25) * (0.55 if k == n.lastUse else 1.0), "fn": fn})
	var broke: bool = n.participant.bankroll < 60
	if broke:
		add.call("money", 1.6, func(): return (U.has("atm") and randf() < 0.6 and use_station(n, choose_of(n, "atm"))) or join_line(n, "cashier") or use_station(n, choose_of(n, "atm")))
	elif n.participant.bankroll > 1800 or randf() < 0.04:
		add.call("money", 0.5, func(): return join_line(n, "cashier"))
	if not broke:
		add.call("play", N.play, func(): return use_station(n, choose_play(n)))
	if N.bladder > 0.6:
		add.call("toilet", N.bladder * (3.0 if N.bladder > 0.9 else 1.2), func(): return use_station(n, choose_of(n, "toilet")))
	if N.hunger > 0.45:
		add.call("eat", N.hunger * 1.1, func(): return use_station(n, choose_of(n, "eat")))
	if N.thirst > 0.4:
		add.call("drink", N.thirst, func(): return use_station(n, choose_of(n, "drink")))
	if N.fatigue > 0.35:
		add.call("relax", N.fatigue * 1.1, func(): return use_station(n, choose_of(n, "relax")))
	if N.social > 0.4:
		add.call("chat", N.social * 0.95, func(): return start_chat(n) or use_station(n, choose_of(n, "standup")))
	if N.curiosity > 0.35:
		add.call("watch", N.curiosity * 0.8, func(): return (randf() < 0.25 and go_spot(n, "wait")) or go_spot(n, "watch") or use_station(n, choose_of(n, "watch")) or go_spot(n, "wait"))
		if U.has("match"):
			add.call("match", N.curiosity * 0.6 * n.T.watch, func(): return use_station(n, choose_of(n, "match")))
		if U.has("shop") or U.has("desk"):
			add.call("shop", N.curiosity * 0.6, func(): return join_line(n, "shop" if randf() < 0.5 and U.has("shop") else "desk") or use_station(n, choose_of(n, "shop" if U.has("shop") else "desk")))
	if U.has("atm") and not broke:
		add.call("atm", 0.2, func(): return use_station(n, choose_of(n, "atm")))
	add.call("phone", 0.3, func():
		set_beh(n, "phone")
		return true)
	add.call("wander", 0.38, func():
		set_beh(n, "wander")
		return true)
	# destinations ajoutées par les extensions (npc-vie)
	for f in ext_decide:
		f.call(n, add)
	# tirage pondéré (le plus pressant gagne le plus souvent) ; une envie pressante passe d'office
	var i := 0
	while i < 4 and opts.size():
		var o = null
		if i == 0:
			for x in opts:
				if x.score > 2:
					o = x
					break
		if o == null:
			o = wpick(opts, func(x): return x.score * x.score)
		opts.erase(o)
		var ok: bool = o.fn.call()
		if ok:
			n.lastUse = o.k
			return
		i += 1
	if n.beh != null and n.beh.type == "decide":
		set_beh(n, "wander")


# --- utiliser une station : y aller, s'installer, y rester, repartir ---
const STAY := {"play": [70, 200], "deco": [50, 150], "drink": [35, 90], "eat": [60, 110], "toilet": [8, 20], "sink": [4, 7], "relax": [30, 90], "match": [50, 140],
	"atm": [5, 9], "cashier": [7, 12], "desk": [7, 14], "shop": [8, 16], "standup": [20, 50], "watch": [10, 30]}


func _use_enter(n: Dictionary, b: Dictionary) -> void:
	var d: Array = STAY.get(b.use, STAY.watch)
	if not b.get("stay"):
		b.stay = rnd(d[0], d[1]) * (0.7 if b.st.type == "slot" or b.st.type == "slot-deco" else 1.0)
	b.sub = 0
	b.fakeT = rnd(3, 8)
	b.rounds = 0
	b.joined = false
	b.guard = 0.0
	b.leave = false
	b.paid = false
	b.phoneT = 0.0
	var r = ROUNDS.get(b.st.type)
	b.roundsMax = irnd(r[0], r[1]) if r != null else 0
	go_to(n, {"x": b.seat.approach.x, "z": b.seat.approach.z, "level": b.st.level})


func _use_step(n: Dictionary, b: Dictionary, dt: float) -> bool:
	match b.phase:
		0:
			var r := step_nav(n, dt)
			if r == "fail":
				b.seat._bad = b.seat._bad + 1
				return true
			if r == "done":
				begin_sit(n)
				b.phase = 1
			return false
		1:
			if seat_step(n, dt) == "seated":
				b.phase = 2
				b.t = 0.0
				n.visits += 1
				on_seated(n, b)
			return false
		2:
			seat_step(n, dt)
			use_tick(n, b, dt)
			if n.retire or b.leave or b.t >= b.stay or (b.roundsMax and b.rounds >= b.roundsMax):
				ask_leave(n, b)
			return false
		3:
			seat_step(n, dt)
			b.guard -= dt
			if b.guard <= 0:
				b.joined = false
				n.joined = false
				b.phase = 4
				on_leave_seat(n, b)
				begin_stand(n)
			return false
	return seat_step(n, dt) == null


func _use_exit(n: Dictionary, b: Dictionary) -> void:
	n.joined = false
	n.meal = null
	if n.seat != null and (b.phase < 1 or n.seatState == "toSeat"):
		unclaim(n)
	set_base(n, "idle")


func on_seated(n: Dictionary, b: Dictionary) -> void:
	var st: Dictionary = b.st
	var N: Dictionary = n.needs
	event("use", {"id": n.id, "use": b.use, "st": st.id})
	note("use:" + str(b.use))
	match b.use:
		"play":
			# sans games.js, les PNJ ne rejoignent pas la partie : ils font semblant (useTick)
			N.play = 0.0
			b.joined = false
			n.joined = false
		"deco":
			N.play = 0.0
		"drink":
			var bm = st._staffNpc
			if bm != null and bm.role == "barman":
				barman_serve(bm, b.seat)
			b.sub = 0
			b.fakeT = rnd(2, 4)
			if randf() < 0.5:
				speak(n, pick(LINES.bar))
		"eat":
			n.meal = {"state": "want", "t": 0.0, "st": st, "seat": b.seat, "asked": false, "eatT": 0.0, "cook": 10.0, "w1": null, "w2": null, "w3": null}
			b.stay = 400.0
		"toilet":
			N.bladder = 0.0
		"relax":
			set_base(n, "idle")
		"atm", "sink":
			set_base(n, "interact")
		"cashier", "desk", "shop":
			set_base(n, "talk")
			if b.use == "cashier":
				speak(n, pick(LINES.cashier))
			var s = st._staffNpc
			if s != null:
				s.lookAtT = now
				look_at_(s, n.x, n.z, 0, 4)
				if s.gest == null:
					gesture(s, "talk", 3)
		"watch", "standup":
			var top = st.anchors.get("top") if st.has("anchors") else null
			if top != null:
				look_at_(n, top.x, top.z, 0.1, 3)


func seat_mates(n: Dictionary) -> Array:
	var st = n.station
	var out: Array = []
	if st == null:
		return out
	for s in st.seats:
		var o = s.occupant
		if o != null and o != n.id and o != "player" and by_id.has(o) and by_id[o].seatState == "seated":
			out.append(by_id[o])
	return out


func use_tick(n: Dictionary, b: Dictionary, dt: float) -> void:
	var N: Dictionary = n.needs
	var st: Dictionary = b.st
	b.fakeT -= dt
	# regards : par défaut vers le jeu, de temps en temps ailleurs
	n.glanceT -= dt
	if n.glanceT <= 0:
		n.glanceT = rnd(3, 9)
		if n.lookHold <= 0:
			n.lookYawT = rnd(-0.75, 0.75)
			n.lookPitchT = rnd(-0.05, 0.15)
			n.lookHold = rnd(0.8, 2.2)
	match b.use:
		"play":
			if not b.joined and b.fakeT <= 0:
				b.fakeT = rnd(4, 10)
				var r := randf()
				if r < 0.14:
					gesture(n, "clap")
				elif r < 0.6:
					lean_pulse(n, 0.16, 0.7)
					n.lookYawT = 0.0
					n.lookPitchT = 0.3
					n.lookHold = 1.0
				b.rounds += 1
		"deco":
			if b.fakeT <= 0:
				b.fakeT = rnd(5, 11)
				b.rounds += 1
				var r := randf()
				var d = st._staffNpc
				if d != null and randf() < 0.5:
					staff_gesture(d, "interact")
				if st.get("spin", false) and randf() < 0.6:
					_tourner(st)
				if r < 0.2:
					gesture(n, "clap")
					n.mood = minf(1.0, n.mood + 0.08)
					n.participant.bankroll += irnd(20, 120)
				elif r < 0.55:
					lean_pulse(n, 0.18, 0.7)
					n.lookYawT = 0.0
					n.lookPitchT = 0.32
					n.lookHold = 1.0
				elif r < 0.75:
					n.mood -= 0.05 * (1 + n.heat)
					n.sore = now
					n.participant.bankroll = maxi(0, n.participant.bankroll - irnd(20, 90))
					if randf() < 0.3:
						gesture(n, "no", 1.6)
		"drink":
			if b.fakeT <= 0:
				b.fakeT = rnd(6, 13)
				gesture(n, "drink")
				N.thirst = maxf(0.0, N.thirst - 0.4)
				n.drunk = minf(1.0, n.drunk + 0.07 * (2.0 if n.temper == "fetard" else 1.0))
				N.bladder += 0.05
				chatter(n, 0.35)
		"eat":
			meal_tick(n, b, dt)
		"relax", "standup", "match", "watch":
			N.fatigue = maxf(0.0, N.fatigue - dt / 25)
			N.curiosity = maxf(0.0, N.curiosity - dt / 30)
			if b.fakeT <= 0:
				b.fakeT = rnd(5, 12)
				if b.use == "match":
					var r := randf()
					if r < 0.18:
						gesture(n, "clap")
						if randf() < 0.3:
							speak(n, pick(["Allez !", "Ouiii !", "But !"]), "happy")
					elif r < 0.3:
						gesture(n, "no", 1.6)
						n.mood -= 0.03 * n.heat
						n.sore = now
				elif not chatter(n, 0.6) and randf() < 0.25 and b.use != "watch":
					set_base(n, "phone")
					b.phoneT = now + rnd(6, 12)
				elif b.use == "standup" and randf() < 0.4:
					gesture(n, "drink")
			if b.phoneT and now > b.phoneT:
				b.phoneT = 0.0
				set_base(n, "idle")
		"atm":
			if b.t > 3 and not b.paid:
				b.paid = true
				n.participant.bankroll += irnd(2, 6) * 100
		"cashier":
			if b.t > 4 and not b.paid:
				b.paid = true
				n.participant.bankroll = clampi(n.participant.bankroll + irnd(-2, 5) * 100, 200, 2500)
		"desk", "shop":
			n.needs.curiosity = maxf(0.0, N.curiosity - dt / 10)


## La roue de la station (st.spin de l'original) : decor.gd fait tourner la roue des hautes limites et la roue de la fortune.
func _tourner(st: Dictionary) -> void:
	if scene != null and "_decor_" in scene and scene._decor_ != null and scene._decor_.has_method("lancer_roue"):
		scene._decor_.lancer_roue(st.id)


## Bavardage assis ou accoudé avec les voisins de station.
func chatter(n: Dictionary, p: float) -> bool:
	if randf() > p * (0.5 + n.T.social * 0.4):
		return false
	var mates := seat_mates(n)
	if mates.is_empty():
		return false
	var o: Dictionary = pick(mates)
	var d := rnd(2.2, 4.5)
	gesture(n, "talk", d)
	look_at_(n, o.x, o.z, 0, d)
	look_at_(o, n.x, n.z, 0, d)
	voice(n, "happy" if n.drunk > 0.5 else "calm", d)
	n.needs.social = maxf(0.0, n.needs.social - 0.25)
	if o.needs != null:
		o.needs.social = maxf(0.0, o.needs.social - 0.15)
	note("chat-assis")
	return true


## Repas : commande → le serveur apporte → on mange → addition. Sans serveur disponible, délais de garde.
func meal_tick(n: Dictionary, b: Dictionary, dt: float) -> void:
	var m = n.meal
	if m == null:
		b.leave = true
		return
	m.t += dt
	match m.state:
		"want":
			if not m.asked:
				m.asked = true
				gesture(n, "railCall", 2)
			if m.t > 50:
				m.state = "served"
				m.t = 0.0
		"ordered":
			if m.t > 70:
				m.state = "served"
				m.t = 0.0
			elif b.fakeT <= 0:
				b.fakeT = rnd(5, 10)
				chatter(n, 0.7)
		"served":
			if not m.eatT:
				m.eatT = rnd(25, 45)
				m.t = 0.0
				note("repas")
				event("meal", {"id": n.id, "st": b.st.id})
			if b.fakeT <= 0:
				b.fakeT = rnd(3.5, 6)
				if not chatter(n, 0.25):
					gesture(n, "eat")
				n.needs.hunger = maxf(0.0, n.needs.hunger - 0.2)
			if m.t > m.eatT:
				m.state = "bill"
				m.t = 0.0
				n.needs.hunger = 0.0
				n.needs.thirst *= 0.4
				if n.visible:
					speak(n, pick(LINES.bill))
				gesture(n, "railCall", 2)
		"bill":
			if m.t > 35:
				m.state = "paid"
		"paid":
			n.participant.bankroll = maxi(0, n.participant.bankroll - irnd(3, 9) * 10)
			n.mood = minf(1.0, n.mood + 0.1)
			n.meal = null
			b.leave = true
			note("addition")


func ask_leave(n: Dictionary, b: Dictionary) -> void:
	if b.phase != 2:
		return
	b.phase = 4
	on_leave_seat(n, b)
	begin_stand(n)


func on_leave_seat(n: Dictionary, b: Dictionary) -> void:
	n.joined = false
	b.joined = false
	if b.use == "toilet":
		n.afterToilet = b.st.zone
	if b.use == "sink":
		note("lavabo")
	set_base(n, "idle")


## Un coup joué par le joueur à une table (tables.gd) : le croupier s'anime, un gain fait parfois applaudir les voisins
## au craps et les badauds (onGameEvent, quand le gagnant n'est pas un PNJ).
func evenement_jeu(e: Dictionary) -> void:
	if not ready_:
		return
	var st = station(e.get("stationId", ""))
	var d = st._staffNpc if st != null else null
	if d != null and (e.type == "round:start" or e.type == "round:end" or e.type == "result"):
		d.lastEvt = now
		staff_gesture(d, "interact")
	if e.type == "result" and float(e.get("amount", 0)) > 0 and st != null:
		for o in clients:
			if ((o.station == st and o.seatState == "seated" and st.type == "craps") or (o.beh != null and o.beh.get("watching") == st.id)) and randf() < 0.25:
				gesture(o, "clap")


# Table du joueur : 1 à 2 PNJ le rejoignent dans la minute, un à la fois.
var player_join = null


func idle_client(n: Dictionary) -> bool:
	return n.beh != null and n.beh.type in ["decide", "wander", "pause", "phone", "spot"] and interruptible(n) and not n.retire and n.fight == null


func recruit(st: Dictionary, want: int) -> bool:
	if npc_count(st) >= want or en_route(st) or free_count(st) <= 1 or npc_count(st) >= int(CAP.get(st.type, 1)):
		return true
	var best = null
	var bd := 1e9
	for n in clients:
		if not idle_client(n) or n.participant.bankroll < 60:
			continue
		var d := Vector2(n.x - st.position.x, n.z - st.position.z).length() + absf(n.y - M.niveau_y(st.level)) * 5
		if d < bd:
			bd = d
			best = n
	if best != null:
		var s = free_seat(st)
		if s != null and claim(best, st, s):
			if best.visits >= best.maxVisits:
				best.maxVisits = best.visits + 1
			best.station = null
			best.seat = null
			s.occupant = null
			return interrupt(best, "decide") and use_station(best, {"st": st, "seat": s})
		return false
	# personne de disponible : quelqu'un quitte le bar ou sa machine pour venir
	for n in clients:
		var b = n.beh
		if b != null and b.type == "use" and b.phase == 2 and n.station != st and n.station != null and (b.use == "drink" or n.station.type == "slot" or b.use == "relax") and b.t > 8 and not n.retire and absf(n.y - M.niveau_y(st.level)) < 1:
			n.forceStation = st
			if n.visits >= n.maxVisits:
				n.maxVisits = n.visits + 1
			b.leave = true
			return false
	return false


## Le joueur s'assoit à une place (tables.gd) : réservée à son nom, comme C.claimSeat(…, 'player').
func asseoir_joueur(station_id: String, index: int) -> bool:
	var st = station(station_id)
	if st == null:
		return true
	if J.mode == "seated":
		lever_joueur()
	var s = st.seats[index] if index >= 0 and index < st.seats.size() else null
	if s == null:
		return true
	if s.occupant != null and s.occupant != "player":
		return false
	s.occupant = "player"
	J.mode = "seated"
	J.station = st
	J.seat = s
	on_player_sit(st, s)
	return true


func lever_joueur() -> void:
	if J.mode != "seated":
		return
	var st: Dictionary = J.station
	release_seat(st, int(J.seat.index))
	J.mode = "walk"
	J.station = null
	J.seat = null
	player_join = null


## La place libre d'une station la plus proche d'un point, -1 si toutes sont prises (les tables du portage s'y fient).
func place_libre(station_id: String, x: float, z: float) -> int:
	var st = station(station_id)
	if st == null:
		return -2
	var best := -1
	var bd := 1e9
	for s in st.seats:
		if s.occupant != null:
			continue
		var d := Vector2(s.position.x - x, s.position.z - z).length()
		if d < bd:
			bd = d
			best = int(s.index)
	return best


func on_player_sit(st: Dictionary, seat: Dictionary) -> void:
	var s = st._staffNpc
	if s != null:
		if s.role == "barman":
			barman_serve(s, seat)
		else:
			staff_gesture(s, "wave")
	if st.seats.size() < 2 or not (st._use == "play" or st._use == "deco" or st._use == "drink"):
		player_join = null
		return
	player_join = {"station": st, "base": npc_count(st), "t": [now + rnd(4, 10), now + rnd(24, 44)], "step": 0, "second": randf() < 0.65}


# --- aller se poster à un point (regarder, attendre) ---
func go_spot(n: Dictionary, kind: String) -> bool:
	var ps: Array = pts(kind).filter(func(p): return p.get("_occ") == null and not world.staffZone.has(p._zone) and not has_tag(p, "personnel"))
	var p = wpick(ps, func(q): return 1.0 / (1 + (dist(q, n) + absf(M.niveau_y(q.level) - n.y) * 4) / 22))
	if p == null or not take_point(n, p):
		return false
	set_beh(n, "spot", {"p": p, "kind": kind})
	return true


# --- discuter à deux ou trois : on se fait face, on parle à tour de rôle ---
var convs: Array = []


func start_chat(n: Dictionary) -> bool:
	# rejoindre une discussion voisine s'il reste de la place
	for c in convs:
		if c.over or c.members.size() != 2 or c.level != n.level or Vector2(c.x - n.x, c.z - n.z).length() > 18 or randf() < 0.5:
			continue
		var a: Dictionary = c.pts[0]
		var bq: Dictionary = c.pts[1]
		var px: float = -(bq.z - a.z)
		var pz: float = bq.x - a.x
		var l := Vector2(px, pz).length()
		if not l:
			l = 1.0
		for s in [1.0, -1.0]:
			var x: float = c.x + px / l * 0.95 * s
			var z: float = c.z + pz / l * 0.95 * s
			if M.degagement(c.level, x, z) >= 0.35:
				var p := {"x": x, "z": z, "level": c.level, "kind": "chat", "_temp": true, "_occ": null}
				c.pts.append(p)
				set_beh(n, "chat", {"conv": c, "p": p})
				return true
	var free: Array = world.pairs.filter(func(pr): return pr[0].get("_occ") == null and pr[1].get("_occ") == null)
	var pr = wpick(free, func(q): return 1.0 / (1 + (dist(q[0], n) + absf(M.niveau_y(q[0].level) - n.y) * 4) / 18))
	if pr == null:
		return false
	# un interlocuteur disponible, pas trop loin
	var mate = null
	var bd := 60.0
	for o in clients:
		if o == n or not idle_client(o) or o.needs.social < 0.15:
			continue
		var d := dist(o, pr[1]) + absf(o.y - M.niveau_y(pr[1].level)) * 5
		if d < bd:
			bd = d
			mate = o
	if mate == null:
		return false
	var c := {"members": [], "pts": [pr[0], pr[1]], "x": (pr[0].x + pr[1].x) / 2, "z": (pr[0].z + pr[1].z) / 2, "level": pr[0].level, "t": 0.0, "dur": rnd(22, 50),
		"speaker": null, "switchAt": 0.0, "over": false, "started": false}
	convs.append(c)
	take_point(n, pr[0])
	if not interrupt(mate, "chat", {"conv": c, "p": pr[1]}):
		c.over = true
		free_points(n)
		return false
	set_beh(n, "chat", {"conv": c, "p": pr[0]})
	return true


func _chat_step(n: Dictionary, b: Dictionary, dt: float) -> bool:
	var c: Dictionary = b.conv
	if c.over:
		return true
	if b.phase == 0:
		var r := step_nav(n, dt)
		if r == "fail":
			return true
		if r == "done":
			b.phase = 1
			b.t = 0.0
			set_base(n, "idle")
		if b.t > 60:
			return true
		return false
	face(n, c.x + (c.x - n.x) * 0.01, c.z + (c.z - n.z) * 0.01, dt, 4)
	var here: Array = c.members.filter(func(m): return m.beh != null and m.beh.type == "chat" and m.beh.phase == 1)
	if here.size() < 2:
		return b.t > 40
	if not c.started:
		c.started = true
		c.t = 0.0
		note("discussion")
		event("chat", {"n": here.size(), "zone": zone_of(c.x, c.z, c.level)})
	if here[0] == n:
		# un seul membre fait tourner la discussion
		c.t += dt
		if c.t >= c.switchAt:
			var prev = c.speaker
			var autres: Array = here.filter(func(m): return m != prev)
			c.speaker = pick(autres) if autres.size() else here[0]
			c.switchAt = c.t + rnd(2.6, 5.5)
			for m in here:
				if m == c.speaker:
					set_base(m, "talk")
					voice(m, "happy" if m.mood > 0.6 else "calm", 2.4)
				else:
					set_base(m, "idle")
					look_at_(m, c.speaker.x, c.speaker.z, 0, 3)
					if randf() < 0.35:
						gesture(m, "yes" if randf() < 0.7 else "no", 1.8)
		if c.t >= c.dur:
			c.over = true
	n.needs.social = maxf(0.0, n.needs.social - dt / 20)
	n.mood = minf(1.0, n.mood + dt / 300)
	return false


# --- faire la queue à un guichet (caisse, réception, billetterie, boutique) ---
func join_line(n: Dictionary, use: String) -> bool:
	var sts: Array = world.use.get(use, []).filter(func(st): return open_(st))
	if sts.is_empty():
		return false
	var st = wpick(sts, func(s): return far_k(n, s) / (1 + (s._line.members.size() if s._line != null else npc_count(s) * 2)))
	if st == null:
		return false
	var L = st._line
	if L == null:
		var seat = free_seat(st)
		return use_station(n, {"st": st, "seat": seat}) if seat != null else false
	if L.members.size() >= L.slots.size() + 2:
		return false
	set_beh(n, "queue", {"line": L, "use": use})
	return true


func _queue_step(n: Dictionary, b: Dictionary, dt: float) -> bool:
	var L: Dictionary = b.line
	var i: int = L.members.find(n)
	if i < 0:
		return true
	if i == 0 and (b.slot == 0 or L.slots.is_empty() or b.t > 25):
		var sts: Array = L.stations.filter(func(st): return open_(st) and free_count(st) > 0)
		if sts.size():
			var st: Dictionary = wpick(sts, func(s): return 1.0 / (1 + dist(s.position, n)))
			var seat = free_seat(st)
			if seat != null and claim(n, st, seat):
				n.station = null
				n.seat = null
				seat.occupant = null
				n.beh = null
				leave_line(n)
				free_points(n)
				n.nav = null
				use_station(n, {"st": st, "seat": seat})
				return false
	var k := mini(i, L.slots.size() - 1)
	var p = L.slots[k] if k >= 0 else null
	if p == null:
		return b.t > 30
	var fa: float = p.get("facing", 0.0)
	var tx: float = p.x - (sin(fa) * -0.8 * (i - k) if i > k else 0.0)
	var tz: float = p.z - (cos(fa) * -0.8 * (i - k) if i > k else 0.0)
	if n.nav != null:
		var r := step_nav(n, dt)
		if r == "fail":
			return true
		if r == "done":
			b.slot = i
	elif Vector2(tx - n.x, tz - n.z).length() > 0.3 or n.level != p.level:
		var goal := "%d:%d" % [k, i]
		if b.get("goal", "") != goal:
			b.goal = goal
			go_to(n, {"x": tx, "z": tz, "level": p.level})
		elif straight(n, tx, tz, dt):
			set_move(n, null)
			b.slot = i
		else:
			set_move(n, "walk")
	else:
		set_move(n, null)
		b.slot = i
		if p.has("facing"):
			turn(n, p.facing, 4, dt)
		if not b.get("idleT", 0.0) or now > b.idleT:
			b.idleT = now + rnd(5, 11)
			set_base(n, "foldArms" if randf() < 0.3 else ("phone" if randf() < 0.2 else "idle"))
	if b.t > 150:
		n.mood -= 0.1
		return true
	return false


# ==================================================================================================
# 9. Personnel
# ==================================================================================================
var ROLE_OF := [[_re("(?i)vigile|garde|s[ée]curit"), "guard"], [_re("(?i)caiss|change|jetons|billets"), "cashier"], [_re("(?i)chef de table|liste|pupitre"), "floor"],
	[_re("(?i)cuisin|chef|plonge|chaud|froid"), "cook"], [_re("(?i)surveillance"), "operator"], [_re("(?i)comptage"), "counter"], [_re("(?i)pianiste|musique"), "pianist"]]
const PRIO := {"guard": [0.0, 0.35], "patrol": [0.2, 0.4], "dealer": [1.0, 0.02], "barman": [1.0, 0.05], "waiter": [1.5, 1.2], "courier": [1.2, 0.01], "cashier": [1.8, 0.9],
	"decoDealer": [2.1, 0.32], "desk": [2.6, 0.55], "floor": [2.8, 1.5], "cook": [2.9, 0.7], "operator": [2.4, 0.9], "counter": [3.0, 0.9], "pianist": [3.4, 1.0], "janitor": [3.3, 2.2]}
const KIND_OF := {"dealer": "dealer", "decoDealer": "dealer", "barman": "barman"}


func role_from(text: String) -> String:
	for r in ROLE_OF:
		if r[0].search(text) != null:
			return r[1]
	return "desk"


func list_posts() -> Array:
	var posts: Array = []
	var count := {}
	var add := func(p: Dictionary) -> Dictionary:
		for q in posts:
			if q.level == p.level and not q.has("route") and not p.has("route") and Vector2(q.x - p.x, q.z - p.z).length() < 0.75:
				if q.get("st") == null and p.get("st") != null:
					q.st = p.st
					q.seat = p.seat
				if p.get("fromPoint", false):
					q.role = q.role if p.role == "desk" else p.role
					if p.has("facing") and q.get("seat") == null:
						q.facing = p.facing
				if p.get("table") != null:
					q.table = p.table
					q.role = p.role
				return q
		posts.append(p)
		return p
	for st in M.stations:
		if st.closed or st.seats.is_empty():
			continue
		if st.has("staff") and (GAME_TYPES.has(st.type) or DECO_TYPES.has(st.type)):
			add.call({"x": st.staff.position.x, "z": st.staff.position.z, "level": st.level, "facing": st.staff.facing, "role": "dealer" if GAME_TYPES.has(st.type) else "decoDealer", "table": st})
		elif st.has("staff") and st.type == "bar":
			add.call({"x": st.staff.position.x, "z": st.staff.position.z, "level": st.level, "facing": st.staff.facing, "role": "barman", "table": st})
		elif st.type == "work" or st.type == "staff":
			for seat in st.seats:
				var o = by_id.get(seat.occupant) if seat.occupant != null else null
				if o != null and o.kind == "extra":
					continue
				add.call({"x": seat.position.x, "z": seat.position.z, "level": st.level, "facing": seat.facing, "role": role_from(st.id + " " + " ".join(PackedStringArray(st.tags))),
					"st": st, "seat": seat, "busy": has_tag(st, "occupe")})
	for p in pts("staff"):
		var d := {"x": p.x, "z": p.z, "level": p.level, "role": role_from(str(p.get("role", "")) + " " + " ".join(PackedStringArray(p.get("tags", [])))), "fromPoint": true, "fixed": p.get("fixed", false)}
		if p.has("facing"):
			d.facing = p.facing
		add.call(d)
	var routes := {}
	var r_order: Array = []
	for p in pts("guard") + pts("patrol"):
		var id = p.get("post", p.get("id"))
		if p.has("order") and id != null:
			if not routes.has(id):
				routes[id] = []
				r_order.append(id)
			routes[id].append(p)
		else:
			var d := {"x": p.x, "z": p.z, "level": p.level, "role": "guard", "fromPoint": true}
			if p.has("facing"):
				d.facing = p.facing
			add.call(d)
	for id in r_order:
		var r: Array = routes[id]
		_tri_stable(r, func(a, b): return a.order < b.order)
		if r.size() >= 2:
			posts.append({"x": r[0].x, "z": r[0].z, "level": r[0].level, "role": "guard", "route": r, "patrol": true})
		else:
			var d := {"x": r[0].x, "z": r[0].z, "level": r[0].level, "role": "guard", "fromPoint": true}
			if r[0].has("facing"):
				d.facing = r[0].facing
			add.call(d)
	# rôles sans poste fixe
	var eats: Array = world.use.get("eat", []).filter(func(st): return not world.staffZone.has(st.zone))
	if eats.size():
		var lv: Dictionary = eats[0]
		for i in 2:
			posts.append({"role": "waiter", "roam": true, "level": lv.level, "x": lv.position.x, "z": lv.position.z})
	var circuit := cash_circuit()
	if circuit.main.size() >= 2:
		posts.append({"role": "courier", "roam": true, "lead": true})
		posts.append({"role": "courier", "roam": true})
	for i in 2:
		posts.append({"role": "janitor", "roam": true})
	# priorité : chaque rôle a une base et un pas
	for p in posts:
		var key: String = "patrol" if p.get("patrol", false) else p.role
		var pr: Array = PRIO.get(key, PRIO.desk)
		count[key] = int(count.get(key, 0)) + 1
		p.prio = pr[0] + pr[1] * (count[key] - 1) - (0.5 if p.get("busy", false) else 0.0)
	_tri_stable(posts, func(a, b): return a.prio < b.prio)
	return posts


func create_staff(post: Dictionary):
	var role: String = "dealer" if post.role == "decoDealer" else post.role
	var looks: Array = LOOKS.get(role, LOOKS.desk).filter(func(l): return templates.has(l[0]))
	if looks.is_empty():
		return null
	var idx: int = staff.filter(func(s): return s.role == role).size()
	var look: Array = looks[idx % looks.size()]
	var tpl: Dictionary = templates[look[0]]
	var n := base_npc("staff", role, tpl, role_tint(role, tpl.name, look[1]))
	n.kindLabel = KIND_OF.get(post.role, role)
	n.post = post
	post.npc = n
	n.pace = 1.0
	n.speed = n.natural
	n.hp = 7 if role == "guard" else 3
	n.guts = 1.0 if role == "guard" else 0.2
	n.heat = 0.0
	n.mood = 0.7
	n.lastEvt = -100.0
	n.fakeT = rnd(3, 8)
	n.wait = rnd(8, 20)
	var hand: String = "PalmR" if tpl.human else "WristR"
	if role == "guard":
		n.corps.accessoire("UpperArmL", "band", Color("#f2c230"), {"along": 0.45, "size": [0.068, 0.075, 0.068]})
		n.corps.accessoire("Head", "box", Color("#101010"), {"along": 0.42, "off": [-0.082, 0, 0.0], "size": [0.022, 0.05, 0.035]})
		n.rank = 3
	elif role == "cook":
		n.corps.accessoire("Head", "disc", Color("#f6f6f2"), {"along": 1.25, "size": [0.095, 0.2, 0.095]})
	elif role == "courier":
		n.corps.accessoire("UpperArmL", "band", Color("#d9a441"), {"along": 0.45, "size": [0.068, 0.06, 0.068]})
		n.rank = 3
	elif role == "waiter":
		n.tray = n.corps.accessoire(hand, "disc", Color("#d8d8d8"), {"along": 1.1, "size": [0.17, 0.018, 0.17]})
		if n.tray != null:
			n.tray.visible = false
	if post.get("table") != null:
		post.table._staffNpc = n
		n.station = null
		n.table = post.table
	# guichets tenus par ce poste : `serves` de la station de travail, ou place `staff` du guichet au même endroit
	for st in M.stations:
		if st.type == "counter" and st.has("staff"):
			var sert: bool = post.get("st") != null and post.st.has("serves") and st.id in post.st.serves
			if sert or (post.get("level") != null and float(st.level) == float(post.level) and Vector2(st.staff.position.x - post.x, st.staff.position.z - post.z).length() < 0.9):
				st._staffNpc = n
	staff.append(n)
	n.job = STAFF_JOB.get(role, STAFF_JOB.desk)
	# mise en place directe au poste (les clients, eux, entrent par la porte)
	if post.get("roam", false):
		var p = null
		if role == "courier":
			var c := cash_circuit()
			var h: Dictionary = c.main[c.main.size() - 1]
			p = {"x": h.x + (0.0 if post.get("lead", false) else 0.9), "z": h.z + (0.0 if post.get("lead", false) else 0.6), "level": h.level}
		elif role == "waiter" and world.pass.size():
			var q: Dictionary = world.pass[idx % world.pass.size()]
			p = {"x": q.x, "z": q.z, "level": q.level}
		elif post.has("x"):
			p = random_public_point(post.level, post, 9)
		if p == null:
			var lv = wpick(world.publicLevels, func(l): return l.area)
			p = random_public_point(lv.level)
		if p == null:
			var s0: Dictionary = M.donnees.spawns[0]
			p = {"x": s0.x, "z": s0.z, "level": 0.0}
		n.x = p.x
		n.z = p.z
		n.level = p.level
	else:
		n.x = post.x
		n.z = post.z
		n.level = post.level
		n.yaw = post.get("facing", 0.0)
	n.y = M.niveau_y(n.level)
	if post.get("seat") != null and post.get("st") != null and post.seat.get("sit", false) and claim(n, post.st, post.seat):
		n.seatState = "seated"
		n.sitK = 1.0
		n.yaw = post.seat.facing
		n.x = post.seat.position.x
		n.z = post.seat.position.z
	elif post.get("seat") != null and post.get("st") != null:
		claim(n, post.st, post.seat)
		n.seatState = null
		n.postSeat = true
	n.job.call(n)
	return n


func staff_gesture(n, key: String, dur := 0.0) -> void:
	if n == null or n.gest != null or n.beh == null or n.beh.type != "post":
		return
	gesture(n, key, dur)


static func table_busy(st: Dictionary) -> bool:
	for s in st.seats:
		if s.occupant != null:
			return true
	return false


func barman_serve(b: Dictionary, seat) -> void:
	var st = b.table
	var w = st.anchors.get("staffWalk") if st != null and st.has("anchors") else null
	if w == null or b.beh == null or b.beh.type != "post" or b.beh.get("walk") != null:
		return
	var ax: float = w[0].x
	var az: float = w[0].z
	var bx: float = w[1].x - ax
	var bz: float = w[1].z - az
	var l2 := bx * bx + bz * bz
	if not l2:
		l2 = 1.0
	var t: float = ((seat.position.x - ax) * bx + (seat.position.z - az) * bz) / l2 if seat != null else randf()
	t = clampf(t, 0, 1)
	var tx := ax + bx * t
	var tz := az + bz * t
	if Vector2(tx - b.x, tz - b.z).length() < 0.25:
		if seat != null:
			staff_gesture(b, "interact")
		return
	b.beh.walk = {"x": tx, "z": tz, "serve": seat != null}


func table_spot(st: Dictionary, seat: Dictionary) -> Dictionary:
	for p in pts("service"):
		if p.get("station") == st.id:
			return {"x": p.x, "z": p.z, "level": p.level}
	if st.has("staff"):
		return {"x": st.staff.position.x, "z": st.staff.position.z, "level": st.level}
	return {"x": seat.approach.x, "z": seat.approach.z, "level": st.level}


func waiter_job(_w: Dictionary):
	var best = null
	var bs := 0.0
	for c in clients:
		var m = c.meal
		if m == null or c.seatState != "seated" or world.staffZone.has(m.st.zone):
			continue
		var kind = null
		var s := 0.0
		if m.state == "want" and m.w1 == null:
			kind = "order"
			s = 2 + m.t / 10
		elif m.state == "ordered" and m.w2 == null and m.t > m.cook:
			kind = "deliver"
			s = 3 + m.t / 10
		elif m.state == "bill" and m.w3 == null:
			kind = "bill"
			s = 1.5 + m.t / 10
		if kind != null and s > bs:
			bs = s
			best = {"c": c, "m": m, "kind": kind}
	return best


# --- convoyeurs : le circuit du cash de bout en bout, à deux, avec le chariot ---
static func _ord(p: Dictionary):
	if p.has("ordre"):
		return float(p.ordre)
	if p.has("order"):
		return float(p.order)
	if p.has("step") and (p.step is float or p.step is int):
		return float(p.step)
	return null


func cash_circuit() -> Dictionary:
	var ps: Array = pts("cash")
	var main: Array = ps.filter(func(p): return _ord(p) != null)
	_tri_stable(main, func(a, b): return _ord(a) < _ord(b))
	# doublons d'étape : on garde le premier
	var m2: Array = []
	for p in main:
		if not m2.any(func(q): return q.level == p.level and Vector2(q.x - p.x, q.z - p.z).length() < 1.6):
			m2.append(p)
	var extra: Array = ps.filter(func(p): return _ord(p) == null and not m2.any(func(q): return q.level == p.level and Vector2(q.x - p.x, q.z - p.z).length() < 1.6))
	return {"main": m2, "extra": extra}


var courier := {"nextT": 60.0, "lead": null, "mate": null, "active": false}


func cart_on(n: Dictionary, on: bool) -> void:
	if on and n.cart == null:
		n.cart = n.corps.chariot()
	if n.cart != null:
		n.cart.visible = on
	n.carry = on


## Vers l'étape suivante ; si l'étape courante nomme un ascenseur et que la suivante est à un autre niveau, on le prend d'office.
func go_cash(n: Dictionary, b: Dictionary, retry := false) -> void:
	var p: Dictionary = b.list[b.i]
	var prev = b.list[b.i - 1] if b.i > 0 else null
	var eid = prev.get("ascenseur", prev.get("elevator")) if prev != null else null
	var E = elevators.get(eid) if eid != null else null
	if not retry and E != null and p.level != n.level and elev_stop(E, n.level) != null and elev_stop(E, p.level) != null \
			and Vector2(elev_stop(E, n.level).outside.x - n.x, elev_stop(E, n.level).outside.z - n.z).length() < 4:
		var o: Dictionary = elev_stop(E, p.level).outside
		var y: float = M.niveau_y(p.level)
		n.nav = {"to": {"x": p.x, "z": p.z, "level": p.level}, "path": [{"x": n.x, "z": n.z, "level": n.level, "y": n.y, "link": {"type": "elevator", "id": eid, "toLevel": p.level}},
			{"x": o.x, "z": o.z, "level": p.level, "y": y}, {"x": p.x, "z": p.z, "level": p.level, "y": y}], "pi": 1,
			"run": false, "speed": 0.0, "stop": 0.0, "urgent": true, "state": "walk", "stuckT": 0.0, "stuckN": 0, "px": n.x, "pz": n.z, "ghost": 0.0, "repathAt": 0.0,
			"link": null, "elev": null, "t": 0.0, "req": false, "res": null, "has_res": false}
		start_link(n, n.nav, n.nav.path[0], n.nav.path[1])
		event("courier:elevator", {"id": eid, "to": p.level})
		return
	go_to(n, p, {"urgent": true})


var STAFF_JOB := {}


func _beh_personnel() -> void:
	var post := func(n): set_beh(n, "post")
	for r in ["desk", "dealer", "barman", "cashier", "floor", "cook", "operator", "counter", "pianist"]:
		STAFF_JOB[r] = post
	STAFF_JOB.guard = func(n):
		var p: Dictionary = n.post
		if p.get("patrol", false):
			var q: Dictionary = p.route[n.patrolI]
			set_beh(n, "patrol" if Vector2(n.x - q.x, n.z - q.z).length() < 30 and n.level == p.level else "toPost")
		else:
			set_beh(n, "toPost" if Vector2(n.x - p.x, n.z - p.z).length() > 0.5 or n.level != p.level else "post")
	STAFF_JOB.waiter = func(n): set_beh(n, "waiter")
	STAFF_JOB.janitor = func(n): set_beh(n, "janitor" if randf() < 0.8 else "pause")
	STAFF_JOB.courier = func(n): set_beh(n, "courier")
	_beh("post", func(n, b):
			var p = n.post
			b.home = p != null and not p.get("roam", false)
			b.walk = null
			set_base(n, "foldArms" if n.role == "guard" else "idle")
			b.glance = rnd(2, 6),
		_post_step)
	_beh("toPost", func(n, b):
			var p = n.post
			if p == null or p.get("roam", false):
				b.none = true
				return
			b.none = false
			if p.get("patrol", false):
				go_to(n, p.route[0])
			elif p.get("seat") != null and p.seat.get("sit", false):
				go_to(n, {"x": p.seat.approach.x, "z": p.seat.approach.z, "level": p.level})
			else:
				go_to(n, p),
		func(n, b, dt):
			if b.none:
				return true
			var r := step_nav(n, dt)
			if r == "go":
				return b.t > 240
			if r == "fail":
				b.phase += 1
				if b.phase <= 2:
					go_to(n, n.post, {"urgent": true})
					return false
				var p: Dictionary = n.post
				n.x = p.x
				n.z = p.z
				n.level = p.level
				n.y = M.niveau_y(p.level)
				log_.teleports += 1
			n.beh = null
			set_beh(n, "patrol" if n.post.get("patrol", false) else "post")
			return false)
	# --- ronde de vigile ---
	_beh("patrol", func(n, b):
			b.i = n.patrolI
			set_base(n, "idle")
			go_to(n, n.post.route[b.i]),
		func(n, b, dt):
			var r: Array = n.post.route
			if b.phase == 0:
				var s := step_nav(n, dt)
				if s == "done" or s == "fail":
					b.phase = 1
					b.t = 0.0
					b.dur = rnd(3, 7)
					n.lookYawT = rnd(-0.9, 0.9)
					n.lookHold = b.dur
				return false
			if b.t >= b.dur:
				b.i = (b.i + 1) % r.size()
				n.patrolI = b.i
				b.phase = 0
				go_to(n, r[b.i])
				note("guard:ronde")
			return false)
	_beh("waiter", func(n, b):
			var h: Dictionary = world.pass[n.slotId % world.pass.size()] if world.pass.size() else n.post
			b.home = {"x": h.x, "z": h.z, "level": h.level, "facing": h.get("facing")}
			b.scan = 0.0
			b.job = null
			b.pick = false
			set_base(n, "idle"),
		_waiter_step,
		func(n, _b):
			n.carry = false
			if n.tray != null:
				n.tray.visible = false)
	# --- agent d'entretien : va d'un point à l'autre, s'agenouille, nettoie ---
	_beh("janitor", func(n, b):
			var lv: Array = world.publicLevels
			var l = wpick(lv, func(x): return x.area)
			var p = random_public_point((l if l != null else lv[0]).level)
			if p != null:
				go_to(n, p)
			else:
				b.phase = 1,
		func(n, b, dt):
			if b.phase == 0:
				var r := step_nav(n, dt)
				if r == "go":
					return false
				b.phase = 1
				b.t = 0.0
				b.dur = rnd(5, 9)
				set_base(n, "fixKneel")
				note("janitor:nettoie")
				return false
			if b.t >= b.get("dur", 3.0):
				set_base(n, "idle")
				return true
			return false,
		func(n, _b): set_base(n, "idle"))
	_beh("courier", func(n, b):
			var c := cash_circuit()
			b.c = c
			b.mate = false
			if not n.post.get("lead", false):
				b.mate = true
				return
			courier.lead = n
			b.wait = true
			set_base(n, "idle")
			cart_on(n, true)
			n.trailOn = true,
		_courier_step,
		func(n, _b):
			if n.post.get("lead", false):
				courier.active = false)


func _post_step(n: Dictionary, b: Dictionary, dt: float) -> bool:
	var p = n.post
	var role: String = n.role
	if n.seatState != null:
		seat_step(n, dt)
	if b.walk != null:
		# le barman longe son comptoir
		set_move(n, "walk")
		if straight(n, b.walk.x, b.walk.z, dt):
			set_move(n, null)
			var s: bool = b.walk.serve
			b.walk = null
			if s:
				gesture(n, "interact")
			n.wait = rnd(10, 26)
		return false
	if b.home and p.get("seat") != null and p.seat.get("sit", false) and p.get("st") != null:
		# poste assis : on s'y rassoit dès que possible
		if n.seatState == null and alarm.until <= now:
			set_base(n, "idle")
			if Vector2(n.x - p.seat.approach.x, n.z - p.seat.approach.z).length() > 1.5 or n.level != p.level:
				set_beh(n, "toPost")
				return false
			if p.seat.occupant == null and claim(n, p.st, p.seat):
				begin_sit(n)
	elif b.home and n.seatState == null and (Vector2(n.x - p.x, n.z - p.z).length() > 0.5 or n.level != p.level) and role != "barman":
		set_beh(n, "toPost")
		return false
	if n.seatState == null and p != null and p.has("facing") and role != "barman":
		turn(n, p.facing, 4, dt)
	elif role == "barman" and n.table != null:
		turn(n, n.table.staff.facing, 4, dt)
	b.glance -= dt
	if b.glance <= 0:
		b.glance = rnd(3, 8)
		if n.lookHold <= 0:
			n.lookYawT = rnd(-0.7, 0.7)
			n.lookPitchT = 0.2 if n.table != null and table_busy(n.table) else 0.0
			n.lookHold = rnd(1, 2.5)
	n.fakeT -= dt
	match role:
		"barman":
			n.wait -= dt
			if n.wait <= 0 and n.gest == null:
				n.wait = rnd(12, 30)
				barman_serve(n, null)
		"dealer":
			if n.table != null and now - n.lastEvt > 10 and table_busy(n.table) and n.fakeT <= 0:
				n.fakeT = rnd(5, 11)
				gesture(n, "interact")
		"cook", "counter", "pianist":
			if n.fakeT <= 0:
				n.fakeT = rnd(3, 7)
				gesture(n, "pickUpTable" if role == "cook" and randf() < 0.3 else "interact")
		"operator":
			if alarm.until > now:
				if n.seatState == "seated":
					begin_stand(n)
				elif n.seatState == null:
					set_base(n, "railCall")
			elif n.fakeT <= 0 and n.seatState == "seated":
				n.fakeT = rnd(4, 10)
				gesture(n, "interact")
		"guard":
			if n.fakeT <= 0:
				n.fakeT = rnd(9, 20)
				if randf() < 0.3:
					gesture(n, "phone", 2.5)
		_:
			if n.fakeT <= 0:
				n.fakeT = rnd(7, 15)
				if randf() < 0.4:
					gesture(n, "interact")
	return false


func _waiter_step(n: Dictionary, b: Dictionary, dt: float) -> bool:
	var j = b.job
	match b.phase:
		0:
			# au passe : attendre une tâche
			if Vector2(n.x - b.home.x, n.z - b.home.z).length() > 0.6 or n.level != b.home.level:
				if n.nav == null:
					go_to(n, b.home)
				if step_nav(n, dt) == "fail":
					n.nav = null
					b.home = {"x": n.x, "z": n.z, "level": n.level, "facing": null}
			elif b.home.facing != null:
				turn(n, b.home.facing, 4, dt)
			b.scan -= dt
			if b.scan <= 0 and interruptible(n):
				b.scan = 1.2
				var job = waiter_job(n)
				if job != null:
					b.job = job
					job.m[{"order": "w1", "deliver": "w2", "bill": "w3"}[job.kind]] = n.id
					if job.kind == "deliver":
						b.phase = 1
						b.t = 0.0
						n.nav = null
					else:
						b.phase = 2
						n.nav = null
						n.carry = false
						go_to(n, table_spot(job.m.st, job.m.seat))
			return false
		1:
			# prendre l'assiette au passe
			if Vector2(n.x - b.home.x, n.z - b.home.z).length() > 0.6:
				if n.nav == null:
					go_to(n, b.home)
				step_nav(n, dt)
				if n.nav != null:
					return false
			if not b.pick:
				b.pick = true
				b.t = 0.0
				gesture(n, "pickUpTable", 1.2)
			if b.t > 1.2:
				b.pick = false
				n.carry = true
				if n.tray != null:
					n.tray.visible = true
				b.phase = 2
				go_to(n, table_spot(j.m.st, j.m.seat))
				note("waiter:service")
			return false
		2:
			# vers la table
			var r := step_nav(n, dt)
			if r == "go":
				if j.c.gone or j.c.meal != j.m:
					b.phase = 4
				return false
			b.phase = 3
			b.t = 0.0
			if j.c.gone or j.c.meal != j.m:
				b.phase = 4
				return false
			face(n, j.c.x, j.c.z, 1, 20)
			if j.kind == "order":
				gesture(n, "talk", 2.5)
				if j.c.visible:
					speak(j.c, pick(LINES.order))
				look_at_(j.c, n.x, n.z, 0, 3)
			elif j.kind == "deliver":
				gesture(n, "interact", 1.5)
				if n.visible:
					speak(n, pick(LINES.waiter))
			else:
				gesture(n, "talk", 2)
			return false
		3:
			# à la table
			if b.t < (1.6 if j.kind == "deliver" else 2.8):
				return false
			if j.c.meal == j.m:
				if j.kind == "order":
					j.m.state = "ordered"
					j.m.t = 0.0
					j.m.cook = rnd(8, 16)
					note("commande")
				elif j.kind == "deliver":
					j.m.state = "served"
					j.m.t = 0.0
					if j.c.visible and randf() < 0.5:
						speak(j.c, pick(LINES.served), "happy")
				else:
					j.m.state = "paid"
			b.phase = 4
			return false
	n.carry = false
	if n.tray != null:
		n.tray.visible = false
	b.job = null
	b.phase = 0
	b.scan = 0.3
	n.nav = null
	set_move(n, null)
	return false


func _courier_step(n: Dictionary, b: Dictionary, dt: float) -> bool:
	if b.mate:
		# l'équipier suit le chariot, deux pas derrière
		var L = courier.lead
		if L == null or L.gone:
			set_move(n, null)
			return false
		if n.bag == null:
			n.bag = n.corps.accessoire("PalmR" if n.tpl.human else "WristR", "box", Color("#2a1d12"), {"along": 1.9, "size": [0.1, 0.26, 0.34]})
		if courier.active or Vector2(n.x - L.x, n.z - L.z).length() > 2.2 or n.level != L.level:
			follow_step(n, L, 1.35, -0.45, dt)
		else:
			set_move(n, null)
			n.lookYawT = sin(now * 0.4 + 1) * 0.8
			n.lookHold = 1.0
		return false
	var c: Dictionary = b.c
	if b.wait:
		if now < courier.nextT or c.main.is_empty():
			return false
		b.wait = false
		courier.active = true
		b.list = []
		# collecte : une ou deux tables au passage, puis le circuit dans l'ordre
		var ex: Array = c.extra.duplicate()
		ex.shuffle()
		for p in ex.slice(0, 2):
			b.list.append(p)
		for p in c.main:
			b.list.append(p)
		b.i = 0
		b.phase = 0
		b.started = now
		b.fails = 0
		b.said = false
		event("courier:start", {"stops": b.list.size()})
		note("courier:tournee")
		go_cash(n, b)
		return false
	if b.phase == 0:
		var r := step_nav(n, dt)
		if r == "go":
			if n.visible and n.near and not b.said and randf() < 0.002:
				b.said = true
				speak(n, pick(LINES.courier))
			return false
		if r == "fail":
			b.fails += 1
			if b.fails < 3:
				go_cash(n, b, true)
				return false
			event("courier:skip", {"i": b.i})
		var p: Dictionary = b.list[b.i]
		b.phase = 1
		b.t = 0.0
		b.dur = minf(12.0, float(p.attente)) if p.has("attente") else (rnd(3, 5) if p.has("station") or p.has("step") or p.has("role") else 0.4)
		if b.dur > 1:
			gesture(n, "pickUpTable", 1.2)
			if p.has("regard"):
				face(n, p.regard.x, p.regard.z, 1, 20)
		return false
	if b.t < b.dur:
		return false
	b.i += 1
	b.fails = 0
	if b.i >= b.list.size():
		log_.tours += 1
		courier.active = false
		courier.nextT = now + rr(CFG.courierEvery)
		b.wait = true
		event("courier:done", {"dur": roundf(now - b.started)})
		return false
	b.phase = 0
	go_cash(n, b)
	return false


# ==================================================================================================
# 10. Embrouilles, bagarres, sécurité
# ==================================================================================================
var alarm := {"until": 0.0}
var fights: Array = []
var fight_t := 70.0
var fight_retry := 0
var timers: Array = []


func free_client(n: Dictionary) -> bool:
	if n.kind != "client" or n.gone or n.fight != null or n.down or n.retire or not interruptible(n) or n.beh == null:
		return false
	var b: Dictionary = n.beh
	return idle_client(n) or b.type == "chat" or b.type == "queue" or (b.type == "use" and not n.joined and b.phase == 2 and b.use != "toilet" and b.use != "eat") or (b.type == "use" and b.phase == 0)


func in_brawl_area(n: Dictionary) -> bool:
	if world.brawl.is_empty():
		return not is_staff_zone(n.x, n.z, n.level)
	for p in world.brawl:
		if p.level == n.level and Vector2(p.x - n.x, p.z - n.z).length() < maxf(9.0, float(p.get("radius", 3)) * 3):
			return true
	return false


func cause_of(a: Dictionary, b: Dictionary) -> String:
	var ba: Dictionary = a.beh if a.beh != null else {}
	if a.drunk > 0.25 or ba.get("use") == "drink" or ba.get("use") == "standup":
		return "alcool"
	if now - a.sore < 90:
		return "mauvaise main"
	if (ba.get("type") == "use" and ba.get("phase") == 0) or (b.beh != null and b.beh.type == "use" and b.beh.get("use") in ["deco", "play", "relax"]):
		return "place prise"
	return "bousculade"


func pick_fight(anywhere: bool):
	var pool: Array = clients.filter(func(n): return free_client(n) and not is_staff_zone(n.x, n.z, n.level) and not _clos(n))
	var cand: Array = pool.filter(func(n): return anywhere or in_brawl_area(n))
	var a = wpick(cand, func(n): return (0.15 + n.heat) * (3.0 if now - n.sore < 90 else 1.0) * (1 + 2 * n.drunk) * (1.3 - n.mood) * (5.0 if n.zvis else 1.0))
	if a == null:
		return null
	var b = null
	var bd := 12.0
	for o in pool:
		if o == a or o.level != a.level:
			continue
		var d := dist(a, o)
		if d < bd and d > 0.4:
			bd = d
			b = o
	return [a, b] if b != null else null


func _clos(n: Dictionary) -> bool:
	var zn = M.zone_a(n.x, n.z, n.level)
	return zn != null and zn.enclosed


func start_fight(a, b, cause = null):
	if a == null or b == null or a == b or a.fight != null or b.fight != null or not interruptible(a) or not interruptible(b):
		return null
	var f := {"a": a, "b": b, "cause": cause if cause != null else cause_of(a, b), "phase": "approach", "t": 0.0, "x": b.x, "z": b.z, "level": b.level, "bystanders": [], "guards": [],
		"detected": false, "detectAt": 0.0, "scan": 0.0, "lines": null, "over": false, "blows": 0, "next": 0.0, "pending": null, "called": false, "arrived": 0,
		"player": false, "force": false, "ended": false, "downed": null, "how": "", "noGuard": 0.0, "replan": 0.0, "dur": 0.0, "step": 0, "turn": 0}
	f.lines = pick(LINES.get(f.cause, LINES.bousculade))
	if not interrupt(b, "fight", {"f": f, "me": "b"}):
		return null
	if not interrupt(a, "fight", {"f": f, "me": "a"}):
		next_(b)
		return null
	a.fight = f
	b.fight = f
	a.hp = 3
	b.hp = 3
	fights.append(f)
	log_.fights += 1
	event("fight", {"a": a.id, "b": b.id, "cause": f.cause, "zone": zone_of(f.x, f.z, f.level)})
	note("embrouille")
	return f


func guard_sees(x: float, z: float, level: float):
	for g in staff:
		if g.role != "guard" or g.level != level or g.down:
			continue
		var d := Vector2(g.x - x, g.z - z).length()
		if d < 16 and (d < 3 or M.libre({"x": g.x, "z": g.z}, {"x": x, "z": z}, 0.02, level)):
			return g
	return null


func guard_free(g: Dictionary) -> bool:
	return g.role == "guard" and not g.gone and not g.down and interruptible(g) and g.beh != null and g.beh.type in ["post", "patrol", "toPost"]


func pick_guards(x: float, z: float, level: float, count: int) -> Array:
	var c: Array = []
	for g in staff:
		if guard_free(g):
			c.append({"g": g, "d": Vector2(g.x - x, g.z - z).length() + absf(g.y - M.niveau_y(level)) * 6})
	_tri_stable(c, func(p, q): return p.d < q.d)
	var out: Array = []
	var entrance := 0
	for g in staff:
		if g.role == "guard" and g.post != null and not g.post.has("entrance"):
			var e := false
			if not g.post.get("patrol", false):
				for ex in world.exits:
					if float(ex.get("level", 0)) == g.post.level and Vector2(ex.x - g.post.x, ex.z - g.post.z).length() < 9:
						e = true
						break
			g.post.entrance = e
	# les vigiles de l'entrée ne la laissent jamais vide : un seul d'entre eux peut partir
	var n_entrance: int = staff.filter(func(g): return g.role == "guard" and g.post != null and g.post.get("entrance", false) and g.beh != null and g.beh.type == "post").size()
	for i in c.size():
		if out.size() >= count:
			break
		var g: Dictionary = c[i].g
		if g.post != null and g.post.get("entrance", false):
			if entrance >= n_entrance - 1:
				continue
			entrance += 1
		out.append(g)
	return out


func dispatch(f: Dictionary) -> void:
	alarm.until = now + 45
	var gs := pick_guards(f.x, f.z, f.level, 2)
	for i in gs.size():
		if interrupt(gs[i], "respond", {"f": f, "i": i}):
			f.guards.append(gs[i])
	f.detected = true
	event("security", {"guards": f.guards.size(), "how": f.how if f.how else "?", "zone": zone_of(f.x, f.z, f.level)})
	if f.guards.size():
		sfx("radio", f.guards[0])
	else:
		f.noGuard = now + 12


func recruit_bystanders(f: Dictionary) -> void:
	var k := 0
	var pool: Array = clients.filter(func(o): return o.fight == null and o.level == f.level and Vector2(o.x - f.x, o.z - f.z).length() < 11 and free_client(o))
	_tri_stable(pool, func(p, q): return dist(p, f) < dist(q, f))
	for o in pool:
		if k >= 5:
			break
		for tries in 6:
			var a: float = fmod(k * 1.25 + tries * 0.7 + f.t, PI2)
			var r := rnd(2.7, 3.5)
			var x: float = f.x + sin(a) * r
			var z: float = f.z + cos(a) * r
			if M.degagement(f.level, x, z) < 0.4 or f.bystanders.any(func(s): return Vector2(s.sx - x, s.sz - z).length() < 0.8):
				continue
			if interrupt(o, "spectate", {"f": f, "x": x, "z": z}):
				o.sx = x
				o.sz = z
				f.bystanders.append(o)
				k += 1
			break
	# les autres tournent la tête
	for o in clients:
		if o.fight == null and o.level == f.level and o.beh != null and o.beh.type != "spectate" and Vector2(o.x - f.x, o.z - f.z).length() < 9:
			look_at_(o, f.x, f.z, 0, 4)


func shove_back(n: Dictionary, fx: float, fz: float, d: float) -> void:
	var dx: float = n.x - fx
	var dz: float = n.z - fz
	var l := Vector2(dx, dz).length()
	if not l:
		l = 1.0
	var x: float = n.x + dx / l * d
	var z: float = n.z + dz / l * d
	if M.degagement(n.level, x, z) >= 0.3:
		n.x = x
		n.z = z


func knock_down(n: Dictionary, dur := 0.0) -> void:
	n.down = true
	n.downHeld = false
	n.downUntil = now + (dur if dur else rnd(8, 12))
	n.gest = null
	n.animKey = ""
	set_move(n, null)
	refresh_anim(n, 0.1)
	sfx("fall", n)
	n.downT = now


func get_up(n: Dictionary) -> float:
	if not n.down:
		return 0.0
	n.down = false
	n.downHeld = false
	n.hp = maxi(n.hp, 1)
	var d := gesture(n, "getup", 0.0, 0.2)
	return d if d else 0.5


func strike(att: Dictionary, tgt: Dictionary, f: Dictionary) -> void:
	var key: String = pick(["punch", "punch", "punchJab", "punchCross", "hook", "kick", "kickLeft"])
	gesture(att, key, minf(1.0, clip_dur(att, key)))
	if randf() < 0.4:
		speak(att, pick(LINES.blow), "angry")
	f.pending = {"at": now + 0.3, "att": att, "tgt": tgt}


func land(f: Dictionary) -> void:
	var p: Dictionary = f.pending
	f.pending = null
	var tgt: Dictionary = p.tgt
	var att: Dictionary = p.att
	if tgt.down or tgt.gone:
		return
	tgt.hp -= 1
	f.blows += 1
	sfx("punch", tgt)
	shove_back(tgt, att.x, att.z, 0.18)
	if tgt.hp <= 0:
		knock_down(tgt, 60)
		f.downed = tgt
		event("ko", {"id": tgt.id})
	else:
		gesture(tgt, "hit" if randf() < 0.5 else ("hitChest" if randf() < 0.5 else "knockback"))
		if randf() < 0.5:
			speak(tgt, pick(LINES.hurt), "shout")


func end_fight(f: Dictionary, why: String) -> void:
	if f.ended:
		return
	f.ended = true
	f.over = true
	fights.erase(f)
	for n in [f.a, f.b]:
		if n is Dictionary and n.fight == f:
			n.fight = null
	for g in f.guards:
		if g.beh != null and g.beh.type == "respond" and g.beh.f == f:
			g.beh = null
			next_(g)
	event("fight:end", {"why": why, "blows": f.blows})
	fight_t = now + rr(CFG.fightEvery)


## La victime (ou le perdant resté seul) se relève et reprend sa soirée.
func recover(n, line := false) -> void:
	if not n is Dictionary or n.gone:
		return
	n.fight = null
	var d := get_up(n) if n.down else 0.0
	n.mood = maxf(0.1, n.mood - 0.25)
	n.hp = 3
	n.beh = null
	set_beh(n, "pause", {"dur": d + rnd(2, 4)})
	if line:
		set_timeout_sim(d + 0.4, func():
			if not n.gone:
				speak(n, pick(LINES.victim)))
	if randf() < 0.4:
		n.retire = true


func set_timeout_sim(d: float, fn: Callable) -> void:
	timers.append({"at": now + d, "fn": fn})


func step_fight(f: Dictionary, dt: float) -> void:
	var a: Dictionary = f.a
	var b = f.b
	f.t += dt
	if a.gone or (b is Dictionary and b.gone):
		if b is Dictionary and not b.gone:
			recover(b)
		if not a.gone:
			recover(a)
		end_fight(f, "parti")
		return
	if f.pending != null and now >= f.pending.at:
		land(f)
	if f.player:
		f.x = a.x
		f.z = a.z
		f.level = a.level
	var d := 0.0 if not b is Dictionary else dist(a, b)
	match f.phase:
		"approach":
			if a.nav == null or now > f.replan:
				f.replan = now + 1
				go_to(a, {"x": b.x, "z": b.z, "level": b.level}, {"stop": 1.0, "urgent": true})
			var r := step_nav(a, dt)
			if d < 4:
				face(b, a.x, a.z, dt)
			if d < 1.15 or (r == "done" and d < 1.8):
				a.nav = null
				set_move(a, null)
				f.phase = "words"
				f.t = 0.0
				f.dur = rnd(5, 7.5)
				f.step = 0
			elif r == "fail" or f.t > 30:
				next0(a)
				next0(b)
				end_fight(f, "inaccessible")
		"words":
			face(a, b.x, b.z, dt)
			face(b, a.x, a.z, dt)
			f.x = (a.x + b.x) / 2
			f.z = (a.z + b.z) / 2
			if f.step == 0 and f.t > 0.3:
				f.step = 1
				set_base(a, "talk")
				speak(a, f.lines[0], "angry", 3)
			elif f.step == 1 and f.t > 2.4:
				f.step = 2
				set_base(a, "idle")
				set_base(b, "talk")
				speak(b, f.lines[1], "angry", 3)
			elif f.step == 2 and f.t > 4.3:
				f.step = 3
				set_base(b, "idle")
				gesture(a, "no", 1.6)
				voice(a, "shout", 1.5)
			if f.t > f.dur:
				f.phase = "shove"
				f.t = 0.0
				f.step = 0
				set_base(a, "idle")
				set_base(b, "idle")
		"shove":
			face(a, b.x, b.z, dt)
			face(b, a.x, a.z, dt)
			if f.step == 0:
				f.step = 1
				gesture(a, "throw", 0.9)
				voice(a, "shout", 1)
				recruit_bystanders(f)
			elif f.step == 1 and f.t > 0.4:
				f.step = 2
				gesture(b, "knockback")
				shove_back(b, a.x, a.z, 0.55)
				speak(b, pick(LINES.shove), "shout")
				sfx("gasp", b)
			if f.t > 2.4:
				if not f.force and a.heat < 0.5 and randf() < 0.3:
					f.phase = "cool"
					f.t = 0.0
					speak(a, pick(LINES.provokeEnd), "angry")
				else:
					f.phase = "blows"
					f.t = 0.0
					f.next = now + 0.4
					f.turn = 0
					note("bagarre")
		"blows":
			f.x = (a.x + b.x) / 2
			f.z = (a.z + b.z) / 2
			if not a.down:
				face(a, b.x, b.z, dt, 8)
			if not b.down:
				face(b, a.x, a.z, dt, 8)
			if not a.down and not b.down and d > 1.25:
				var k := minf(1.0, dt * 2)
				var x: float = a.x + (b.x - a.x) * k * 0.3
				var z: float = a.z + (b.z - a.z) * k * 0.3
				if M.degagement(a.level, x, z) > 0.3:
					a.x = x
					a.z = z
			if f.downed != null:
				f.phase = "aftermath"
				f.t = 0.0
				var w: Dictionary = b if f.downed == a else a
				set_base(w, "idle")
				gesture(w, "yes", 1.6)
			else:
				if now >= f.next and f.pending == null:
					var b_fights: bool = b.guts > 0.3
					var tour: int = f.turn
					f.turn += 1
					var att: Dictionary = b if (tour % 3 == 2 and b_fights) or (b_fights and randf() < 0.3) else a
					strike(att, b if att == a else a, f)
					f.next = now + rnd(1.0, 1.7)
					if not b_fights and b.gest == null:
						set_base(b, "cower")
				if f.t > 26:
					f.phase = "aftermath"
					f.t = 0.0
		"cool":
			if f.t > 2:
				f.over = true
				next0(a)
				next0(b)
				end_fight(f, "calmés")
			return
		"aftermath":
			# un fautif au sol ou à bout de souffle : on attend la sécurité
			if f.t > 22 and not f.detected:
				f.how = "témoin"
				dispatch(f)
			if f.t > 45 and f.arrived == 0:
				f.over = true
				recover(b, true)
				a.retire = true
				recover(a)
				end_fight(f, "personne")
				return
		"player":
			# un PNJ s'en prend au joueur : seuls la détection et l'envoi comptent ici
			if a.beh == null or not a.beh.type in ["combat", "provoke", "ko", "held"]:
				end_fight(f, "fini")
				return
			if f.t > 60:
				end_fight(f, "durée")
				return
		"separate":
			if f.t > 2.6 or f.arrived >= maxi(1, f.guards.size()):
				if f.t > 1.2:
					escort_out(f)
	if f.ended:
		return
	# détection : vigile en vue (rapide), caméra (appel radio), sinon un témoin appelle
	if not f.detected and (f.phase in ["shove", "blows", "aftermath", "player"] or (f.phase == "words" and f.t > 2)):
		if not f.detectAt:
			f.scan -= dt
			if f.scan <= 0:
				f.scan = 0.5
				if guard_sees(f.x, f.z, f.level) != null:
					f.detectAt = now + rnd(0.8, 1.8)
					f.how = "vigile"
				elif f.phase != "words" and on_camera(f.x, f.z, f.level) != null:
					f.detectAt = now + rnd(3.5, 6)
					f.how = "caméra"
				elif (f.phase == "blows" and f.t > 7) or (f.phase == "player" and f.t > 6):
					f.detectAt = now + rnd(4, 7)
					f.how = "témoin"
					var w = null
					for o in f.bystanders:
						if o.beh != null and o.beh.type == "spectate":
							w = o
							break
					if w == null and b is Dictionary and not b.down:
						w = b
					if w != null:
						speak(w, pick(LINES.call), "shout")
		elif now >= f.detectAt:
			dispatch(f)
	if f.detected and f.noGuard and now > f.noGuard and f.arrived == 0:
		f.noGuard = 0.0
		f.detected = false
		f.detectAt = now + 8


func next0(n) -> void:
	if n is Dictionary and not n.gone:
		n.fight = null
		n.beh = null
		next_(n)


func separate(f: Dictionary) -> void:
	f.pending = null
	f.phase = "separate"
	f.t = 0.0
	var a: Dictionary = f.a
	var b = f.b
	if a.beh != null and (a.beh.type == "combat" or a.beh.type == "provoke"):
		a.beh = null
		set_beh(a, "held", {"f": f})
	for n in [a, b]:
		if n is Dictionary and not n.down:
			n.gest = null
			set_base(n, "idle" if n == a else "cower")
	if a.down:
		set_timeout_sim(0.6, func(): get_up(a))


## L'escorte de l'agresseur : en salle d'entretien, ou dehors.
func escort_out(f: Dictionary) -> void:
	var a: Dictionary = f.a
	var b = f.b
	f.over = true
	var hard: bool = f.blows > 0 or f.player
	var to_room: bool = world.detain != null and (randf() < 0.75 if hard else randf() < 0.3)
	var dest: Dictionary
	if to_room:
		dest = {"x": world.detain.x, "z": world.detain.z, "level": world.detain.level, "room": true}
	else:
		var ex = wpick(world.exits, func(e): return 1.0 / (1 + dist(e, a) / 20))
		if ex == null:
			ex = world.exits[0]
		dest = {"x": ex.x, "z": ex.z, "level": float(ex.get("level", 0)), "room": false}
	var gs: Array = f.guards.filter(func(g): return not g.gone)
	if a.down:
		get_up(a)
	a.fight = null
	a.staffPass = true
	a.trail = []
	a.trailOn = true
	a.beh = null
	a.retire = true
	set_beh(a, "escorted", {"dest": dest, "guards": gs, "f": f})
	for i in gs.size():
		gs[i].beh = null
		set_beh(gs[i], "escort", {"who": a, "side": -0.5 if i else 0.5, "back": 0.25 + i * 0.05})
	if gs.size():
		speak(gs[0], pick(LINES.escort if to_room else LINES.escortOut), "angry")
	log_.arrests += 1
	event("arrest", {"id": a.id, "to": "entretien" if to_room else "sortie", "guards": gs.size(), "victim": "joueur" if not b is Dictionary else b.id})
	if not b is Dictionary:
		toast("La sécurité emmène [b]%s[/b]. Vous n'avez fait que vous défendre." % a.name)
		P.attackers.erase(a)
	else:
		recover(b, true)
	end_fight(f, "sécurité")


func _beh_bagarres() -> void:
	# piloté par step_fight
	_beh("fight", null, func(_n, _b, _dt): return false, func(n, _b): set_base(n, "idle"))
	_beh("spectate", func(n, b):
			go_to(n, {"x": b.x, "z": b.z, "level": b.f.level})
			b.style = "cower" if n.guts < 0.25 else ("phone" if randf() < 0.45 else ("foldArms" if randf() < 0.5 else "idle"))
			b.end = 0.0
			note("badaud"),
		func(n, b, dt):
			var f: Dictionary = b.f
			if b.phase == 0:
				var r := step_nav(n, dt)
				if r != "go":
					b.phase = 1
					b.t = 0.0
					set_base(n, b.style)
					if b.style == "phone":
						note("filme")
						if randf() < 0.6:
							say(n, pick(LINES.filming))
					elif randf() < 0.5:
						speak(n, pick(LINES.gawk), "shout")
			else:
				face(n, f.x, f.z, dt, 4)
			if f.over:
				if not b.end:
					b.end = now + rnd(1.5, 4)
				if now > b.end:
					n.mood -= 0.03
					return true
			return b.t > 120,
		func(n, _b): set_base(n, "idle"))
	# --- vigile qui accourt ---
	_beh("respond", func(n, b):
			n.rank = 4
			b.fails = 0
			go_to(n, {"x": b.f.x, "z": b.f.z, "level": b.f.level}, {"run": true, "stop": 1.5, "urgent": true})
			b.re = now + 1.2,
		func(n, b, dt):
			var f: Dictionary = b.f
			if f.ended:
				return true
			if b.phase == 0:
				if now > b.re and (n.nav == null or Vector2(n.nav.to.x - f.x, n.nav.to.z - f.z).length() > 1.5):
					b.re = now + 1.2
					if stop_nav(n) or n.nav == null:
						go_to(n, {"x": f.x, "z": f.z, "level": f.level}, {"run": true, "stop": 1.5, "urgent": true})
				var r := step_nav(n, dt)
				var d := Vector2(n.x - f.x, n.z - f.z).length()
				var echec := false
				if r == "fail":
					b.fails += 1
					echec = b.fails > 3
				if (r == "done" or (d < 1.9 and n.level == f.level and interruptible(n))) or echec or b.t > 90:
					if r == "fail" or b.t > 90:
						var i: int = M.proche({"x": f.x, "z": f.z}, 14, f.level)
						if i >= 0:
							n.x = M.nx[i]
							n.z = M.nz[i]
							n.level = f.level
							n.y = M.niveau_y(f.level)
							log_.teleports += 1
					n.nav = null
					set_move(n, null)
					b.phase = 1
					b.t = 0.0
					f.arrived += 1
					if f.arrived == 1:
						log_.interventions += 1
						speak(n, pick(LINES.guard), "shout")
						sfx("whistle", n)
						separate(f)
						note("guard:intervention")
				elif r == "fail":
					go_to(n, {"x": f.x, "z": f.z, "level": f.level}, {"run": true, "stop": 1.5, "urgent": true})
				return false
			face(n, f.x, f.z, dt, 6)
			return false,
		func(n, _b): n.rank = 3)
	_beh("held", null, func(_n, b, _dt): return b.t > 30)
	_beh("escorted", func(n, b):
			n.speed = n.natural * 0.82
			set_base(n, "idle")
			b.retry = false
			b.lagT = 0.0
			go_to(n, b.dest, {"urgent": true})
			note("escorte"),
		_escorted_step,
		func(n, _b):
			n.trailOn = false
			if n.seat != null and n.seatState != null:
				unclaim(n))
	_beh("escort", func(n, b):
			n.rank = 4
			b.said = false
			set_base(n, "idle"),
		func(n, b, dt):
			var w: Dictionary = b.who
			if w.gone or w.beh == null or w.beh.type != "escorted":
				return true
			if w.beh.phase >= 1:
				if b.side < 0 or w.beh.phase >= 2:
					return true
				set_move(n, null)
				face(n, w.x, w.z, dt)
				if not b.said and w.beh.t > 3:
					b.said = true
					set_base(n, "talk")
					voice(n, "angry", 2.5)
				return false
			n.follow = w
			follow_step(n, w, b.back, b.side, dt)
			return false,
		func(n, _b):
			n.rank = 3
			n.follow = null
			set_base(n, "idle")
			set_move(n, null))
	_beh("ko", func(n, b):
			b.up = 0.0
			if not n.down:
				knock_down(n, b.get("dur", 0.0)),
		func(n, b, _dt):
			if n.down and now >= n.downUntil:
				b.up = now + get_up(n)
			if not n.down and b.up and now >= b.up:
				if n.kind == "client":
					n.retire = true
					n.mood = 0.1
				return true
			if not n.down and not b.up:
				return true
			return false,
		func(n, _b):
			n.down = false
			n.downHeld = false
			n.hp = 3
			refresh_anim(n))


func _escorted_step(n: Dictionary, b: Dictionary, dt: float) -> bool:
	leave_trail(n)
	if b.phase == 0:
		# on attend les vigiles avant l'ascenseur et quand ils décrochent
		var lag: bool = b.guards.any(func(g): return not g.gone and g.beh != null and g.beh.type == "escort" and (Vector2(g.x - n.x, g.z - n.z).length() > 2.6 or g.level != n.level) and not (n.nav != null and (n.nav.link != null or n.nav.elev != null)))
		if lag and b.t < 200:
			set_move(n, null)
			b.lagT += dt
			if b.lagT < 4:
				return false
		else:
			b.lagT = 0.0
		var r := step_nav(n, dt)
		if r == "go":
			if b.t > 320:
				remove_npc(n)
			return false
		if r == "fail" and not b.retry:
			b.retry = true
			if b.dest.room:
				var ex: Dictionary = world.exits[0]
				b.dest = {"x": ex.x, "z": ex.z, "level": float(ex.get("level", 0)), "room": false}
			go_to(n, b.dest, {"urgent": true})
			return false
		if not b.dest.room or r == "fail":
			note("expulsé")
			event("expelled", {"id": n.id})
			remove_npc(n)
			return false
		# salle d'entretien : on s'assoit sur le banc, un vigile reste
		b.phase = 1
		b.t = 0.0
		b.hold = rnd(22, 36)
		note("entretien")
		event("detained", {"id": n.id})
		var st = world.detain.station
		var seat = free_seat(st) if st != null else null
		if seat != null and claim(n, st, seat):
			n.x = seat.approach.x
			n.z = seat.approach.z
			begin_sit(n)
		return false
	if n.seatState != null:
		seat_step(n, dt)
	if b.phase == 1 and b.t > b.hold:
		b.phase = 2
		if n.seatState != null:
			begin_stand(n)
	if b.phase == 2 and n.seatState == null:
		n.speed = n.natural
		n.beh = null
		set_beh(n, "leave")
	return false


func fights_tick(dt: float) -> void:
	for i in range(fights.size() - 1, -1, -1):
		if i < fights.size():
			step_fight(fights[i], dt)
	for i in range(timers.size() - 1, -1, -1):
		if i < timers.size() and now >= timers[i].at:
			var t: Dictionary = timers[i]
			timers.remove_at(i)
			t.fn.call()
	if now >= fight_t and not fights.any(func(f): return not f.player):
		var pr = pick_fight(fight_retry >= 3)
		if pr != null and start_fight(pr[0], pr[1]) != null:
			fight_retry = 0
		else:
			fight_retry += 1
			fight_t = now + 6


# ==================================================================================================
# 11. Le joueur : frapper, encaisser, se faire arrêter
# ==================================================================================================
var P := {"hp": 100.0, "hitT": -99.0, "busy": false, "wanted": null, "offenses": 0, "fist": 0.0, "kick": 0.0, "attackers": [], "provokeT": 200.0, "veil": 0.0,
	"unseen": null}
var _poussee := Vector2.ZERO
var _etourdi := 0.0
var _gele := false
var _action_t := 0.0


func player_pos() -> Dictionary:
	return {"x": J.x, "z": J.z, "level": J.level}


func flash(k: float) -> void:
	P.veil = maxf(P.veil, k)


func toast(t: String) -> void:
	if scene != null and scene.has_method("_dire"):
		scene._dire(t.replace("[b]", "").replace("[/b]", ""))


## Pousse le joueur (m/s, amorti en ~0,4 s), comme player.impulse.
func impulse(vx: float, vz: float) -> void:
	_poussee += Vector2(vx, vz)


## Bloque déplacement, action et interaction pendant sec secondes ; stun(0) lève le blocage.
func stun(sec: float) -> void:
	_etourdi = maxf(_etourdi, sec) if sec > 0 else 0.0


## Ce que le joueur vise à moins de 2 m (aim) : le PNJ le mieux placé devant lui.
func aim():
	var p = scene.player if scene != null else null
	if p == null:
		return null
	var fwd: Vector3 = -(p as Node3D).global_basis.z
	var fx := fwd.x
	var fz := fwd.z
	var fl := Vector2(fx, fz).length()
	if fl > 1e-6:
		fx /= fl
		fz /= fl
	var best = null
	var bs := 1e9
	for n in all:
		if n.level != J.level or n.hidden:
			continue
		var dx: float = n.x - J.x
		var dz: float = n.z - J.z
		var d := Vector2(dx, dz).length()
		if d > 2:
			continue
		var dot := 1.0 if d < 0.5 else (dx * fx + dz * fz) / d
		if dot < 0.55:
			continue
		var s := d + (1 - dot) * 2.5
		if s < bs:
			bs = s
			best = {"n": n, "distance": d}
	return best


## L'action du joueur (F, clic gauche) : frapper ce qu'il vise.
func action() -> bool:
	if not ready_ or P.busy or J.mode != "walk" or _etourdi > 0 or _action_t > 0:
		return false
	_action_t = 0.25
	P.fist = 0.3
	P.kick = 0.05
	var t = aim()
	if t == null or t.n.gone or t.distance > CFG.playerReach:
		sfx("whoosh", "player")
		return true
	player_hits(t.n)
	return true


func player_hits(n: Dictionary) -> void:
	var pp := player_pos()
	sfx("punch", n)
	event("player:punch", {"id": n.id, "role": n.role})
	var defending: bool = n.hostile and now - n.hostileT < 40
	n.hitByPlayerT = now
	if n.down:
		return
	n.hp -= 1
	if n.seatState == null and interruptible(n):
		shove_back(n, pp.x, pp.z, 0.3)
	look_at_(n, pp.x, pp.z, 0, 2)
	if not defending:
		# le joueur frappe le premier : faute, aggravée contre un employé ou un vigile
		var sev := 3 if n.role == "guard" else (2 if n.kind == "staff" else 1)
		var seen = n if n.role == "guard" else guard_sees(pp.x, pp.z, pp.level)
		var cam = on_camera(pp.x, pp.z, pp.level)
		if seen != null or cam != null:
			wanted(sev, "vigile" if seen != null else "caméra", n)
		else:
			P.unseen = {"sev": sev, "n": n, "at": now}
		for o in clients.duplicate():
			if o != n and o.level == n.level and Vector2(o.x - n.x, o.z - n.z).length() < 8 and o.fight == null:
				look_at_(o, n.x, n.z, 0, 3)
				if idle_client(o) and o.guts < 0.3 and randf() < 0.5:
					interrupt(o, "flee", {"from": pp})
	if n.hp <= 0:
		if interruptible(n):
			var f = n.fight
			if f != null and f.player:
				end_fight(f, "ko")
			interrupt(n, "ko", {"dur": rnd(8, 12)})
			P.attackers.erase(n)
			event("ko", {"id": n.id, "by": "player"})
		return
	gesture(n, "hit" if randf() < 0.5 else "hitChest")
	speak(n, pick(LINES.hurt), "shout")
	if n.beh != null and n.beh.type in ["combat", "provoke", "chase", "escort", "respond"]:
		if n.beh.type == "provoke":
			n.beh = null
			set_beh(n, "combat", {"hits": 4})
		return
	# réaction selon le tempérament : riposter, fuir, appeler la sécurité
	var r := randf()
	if n.role == "guard":
		if interrupt(n, "combat", {"hits": 6}):
			speak(n, pick(LINES.arrest), "shout")
	elif n.kind == "client" and r < n.guts * 0.85:
		if interrupt(n, "combat", {"hits": irnd(3, 6)}):
			set_timeout_sim(0.7, func():
				if not n.gone:
					speak(n, pick(LINES.riposte), "angry"))
			note("riposte")
	elif r < 0.6 or n.kind == "staff":
		if interrupt(n, "callSec", {"from": pp}):
			note("appel")
	elif interrupt(n, "flee", {"from": pp}):
		note("fuite")


## Le joueur est recherché : deux vigiles le poursuivent.
func wanted(sev: int, how: String, victim = null) -> void:
	if P.busy:
		return
	var first: bool = P.wanted == null
	P.wanted = {"sev": maxi(sev, P.wanted.sev if P.wanted != null else 0), "until": now + 75, "how": how, "victim": victim.role if victim != null else ""}
	alarm.until = now + 45
	if first:
		P.offenses += 1
		event("wanted", {"sev": sev, "how": how})
		toast("Une caméra vous a filmé. La sécurité arrive." if how == "caméra" else ("Quelqu'un a appelé la sécurité. Elle arrive." if how == "appel" else "Un vigile vous a vu. La sécurité arrive."))
	var pp := player_pos()
	var have: int = staff.filter(func(g): return g.beh != null and g.beh.type == "chase").size()
	if have < 2:
		for g in pick_guards(pp.x, pp.z, pp.level, 2 - have):
			if interrupt(g, "chase"):
				sfx("radio", g)
	if victim != null and victim.role == "guard" and victim.beh != null and victim.beh.type != "chase" and victim.beh.type != "combat" and not victim.down:
		interrupt(victim, "chase")


func hurt_player(n: Dictionary, dmg: float, shove := false) -> void:
	var dx: float = J.x - n.x
	var dz: float = J.z - n.z
	var l := Vector2(dx, dz).length()
	if not l:
		l = 1.0
	if P.busy:
		return
	if not (n.hitByPlayerT and now - n.hitByPlayerT < 40) or n.firstBlow:
		n.firstBlow = true
	n.hostile = true
	n.hostileT = now
	if not n in P.attackers:
		P.attackers.append(n)
	impulse(dx / l * (2.8 if shove else 3.4), dz / l * (2.8 if shove else 3.4))
	if not shove:
		stun(0.28)
		P.hp -= dmg
		P.hitT = now
		flash(0.85)
		sfx("punch", "player")
	else:
		flash(0.3)
		sfx("gasp", "player")
	event("player:hit", {"by": n.id, "dmg": 0 if shove else dmg, "hp": roundi(P.hp)})
	# agression contre le joueur : la sécurité s'en mêle si quelqu'un voit
	if n.firstBlow and n.role != "guard" and n.fight == null and not shove:
		var f := {"a": n, "b": "player", "player": true, "cause": "agression", "phase": "player", "t": 0.0, "x": n.x, "z": n.z, "level": n.level, "bystanders": [], "guards": [],
			"detected": false, "detectAt": 0.0, "scan": 0.0, "over": false, "blows": 1, "arrived": 0, "pending": null, "ended": false, "downed": null, "how": "", "noGuard": 0.0,
			"force": false, "lines": null, "next": 0.0, "replan": 0.0, "dur": 0.0, "step": 0, "turn": 0}
		n.fight = f
		fights.append(f)
		log_.fights += 1
		event("fight", {"a": n.id, "b": "joueur", "cause": "agression"})
	if P.hp <= 0:
		player_ko(n)


## La salle d'entretien, au sous-sol ; tant que les coulisses sont fermées au joueur, l'entrée du casino.
func to_room() -> bool:
	lever_joueur()
	var d = world.detain
	if d != null and _coulisses_ouvertes():
		var i: int = M.proche({"x": d.x, "z": d.z}, 14, d.level)
		var x: float = M.nx[i] if i >= 0 else d.x
		var z: float = M.nz[i] if i >= 0 else d.z
		_teleporter(x, z, d.level)
		return true
	var s: Dictionary = M.donnees.spawns[M.donnees.spawns.size() - 1]
	_teleporter(s.x, s.z, s.level)
	return false


func _coulisses_ouvertes() -> bool:
	return scene != null and scene.has_method("_seuil") and Game.won >= scene._seuil("coulisses")


func _teleporter(x: float, z: float, level: float) -> void:
	var p = scene.player if scene != null else null
	if p == null:
		return
	p.global_position = Vector3(x, M.niveau_y(level) + 0.05, z)
	p.velocity = Vector3.ZERO
	_poussee = Vector2.ZERO
	J.x = x
	J.z = z
	J.level = level


func calm() -> void:
	for n in P.attackers.duplicate():
		if not n.gone and n.beh != null and n.beh.type == "combat":
			n.beh = null
			next_(n)
		n.hostile = false
	P.attackers.clear()
	for g in staff:
		if g.beh != null and g.beh.type == "chase":
			g.beh = null
			next_(g)
	for f in fights.filter(func(f): return f.player):
		end_fight(f, "joueur parti")


func fine_of(sev: int) -> int:
	return int(CFG.fine) * sev + 100 * maxi(0, P.offenses - 1)


## L'amende, prélevée sur les crédits du joueur (tout ce qu'il lui reste au plus).
func _payer(fine: int) -> int:
	var paid := mini(Game.credits, fine)
	if paid > 0:
		Game.credits -= paid
		Game.changed.emit()
	return paid


func player_ko(by) -> void:
	if P.busy:
		return
	P.busy = true
	stun(9)
	event("player:ko", {"by": by.id if by != null else null})
	var fine := fine_of(P.wanted.sev) if P.wanted != null else 0
	HUD.fondu(1, 0.9, "")
	set_timeout_real(1.1, func():
		var room := to_room()
		calm()
		var paid := _payer(fine) if fine else 0
		P.hp = 60.0
		P.wanted = null
		HUD.message("K.-O.", "Vous reprenez connaissance %s.%s" % ["en [color=#d9a441]salle d'entretien[/color], au sous-sol" if room else "près de l'entrée",
			("\nAmende de [color=#d9a441]%d[/color] prélevée pour avoir frappé le premier." % paid) if paid else ""])
		set_timeout_real(3.2, func():
			HUD.fondu(0, 1.2)
			stun(0)
			P.busy = false))


func arrest(g: Dictionary) -> void:
	if P.busy:
		return
	P.busy = true
	stun(9)
	var w: Dictionary = P.wanted if P.wanted != null else {"sev": 1}
	var fine := fine_of(w.sev)
	speak(g, pick(LINES.arrest), "shout")
	sfx("whistle", g)
	event("player:arrested", {"fine": fine, "sev": w.sev})
	set_timeout_real(1.3, func(): HUD.fondu(1, 0.7, ""))
	set_timeout_real(2.2, func():
		var room := to_room()
		calm()
		var paid := _payer(fine)
		log_.arrests += 1
		# les deux vigiles sont dans la pièce au réveil
		var pp := player_pos()
		var k := 0
		for s in staff:
			if s.role == "guard" and k < 2 and guard_free(s) and room and s.post != null and not s.post.get("entrance", false):
				var a := 0.9 if k else -0.9
				var x: float = pp.x + sin(a) * 1.5
				var z: float = pp.z - cos(a) * 1.5
				if M.degagement(pp.level, x, z) > 0.3:
					s.x = x
					s.z = z
					s.level = pp.level
					s.y = M.niveau_y(pp.level)
					s.yaw = yaw_to(pp.x - x, pp.z - z)
					k += 1
					s.beh = null
					set_beh(s, "pause", {"dur": 8.0, "base": "foldArms"})
		var quoi := "Vous avez frappé un vigile. " if w.sev >= 3 else ("Vous avez frappé un employé. " if w.sev == 2 else "Vous avez frappé le premier. ")
		HUD.message("Salle d'entretien" if room else "Reconduit à l'entrée", quoi + "Amende de [color=#d9a441]%d[/color] prélevée sur vos crédits%s.\nVous êtes relâché." % [paid, " (tout ce qu'il vous restait)" if paid < fine else ""])
		P.wanted = null
		P.hp = maxf(P.hp, 60.0)
		set_timeout_real(3.6, func():
			HUD.fondu(0, 1.2)
			stun(0)
			P.busy = false
			toast("Vous êtes libre. Tenez-vous tranquille.")))


## Minuteries en temps réel (fondus) : comptées sur l'horloge murale, pas sur la simulation.
var real_timers: Array = []


func set_timeout_real(sec: float, fn: Callable) -> void:
	real_timers.append({"at": Time.get_ticks_msec() / 1000.0 + sec, "fn": fn})


func _beh_joueur() -> void:
	# --- un PNJ se bat contre le joueur ---
	_beh("combat", func(n, b):
			if not b.get("hits"):
				b.hits = 4
			b.next = now + rnd(0.5, 0.9)
			b.re = 0.0
			b.far = 0.0
			b.swing = 0.0
			n.hostile = true
			n.hostileT = now
			n.rank = 4
			set_base(n, "idle")
			if not n in P.attackers:
				P.attackers.append(n),
		func(n, b, dt):
			var pp := player_pos()
			var d := Vector2(pp.x - n.x, pp.z - n.z).length()
			var same: bool = pp.level == n.level
			if P.busy or b.hits <= 0 or b.t > 45 or J.mode != "walk":
				return true
			if d > 14 or not same:
				b.far += dt
				if b.far > 6:
					if n.kind == "client" and n.visible:
						speak(n, pick(LINES.provokeEnd), "angry")
					return true
			else:
				b.far = 0.0
			if b.swing and now >= b.swing:
				b.swing = 0.0
				if d < 1.75 and same:
					hurt_player(n, CFG.npcPunch * (1.3 if n.role == "guard" else 1.0))
					b.hits -= 1
			if d > 1.3 or not same:
				if now > b.re:
					b.re = now + 0.5
					if interruptible(n):
						go_to(n, pp, {"run": d > 5, "stop": 1.1, "urgent": true, "speed": 5.2 if n.role == "guard" else (4.4 if d > 5 else 0.0)})
				if n.nav != null:
					step_nav(n, dt)
			else:
				if n.nav != null and interruptible(n):
					n.nav = null
					set_move(n, null)
				face(n, pp.x, pp.z, dt, 9)
				if now >= b.next and not b.swing and n.gest == null:
					var k: String = pick(["punch", "punchJab", "punchCross", "hook"])
					gesture(n, k, minf(0.9, clip_dur(n, k)))
					b.swing = now + 0.3
					b.next = now + rnd(1.1, 1.8)
			n.hostileT = now
			return false,
		func(n, _b):
			n.rank = 1 if n.kind == "client" else 3
			P.attackers.erase(n)
			if n.role == "guard" and P.wanted != null and not P.busy and not n.down:
				set_timeout_sim(0.1, func():
					if not n.gone and not n.down and P.wanted != null and interruptible(n):
						interrupt(n, "chase")))
	_beh("flee", func(n, b):
			var best = null
			var bd := 0.0
			for i in 8:
				var p = random_public_point(n.level)
				if p != null:
					var d := dist(p, b.from)
					if d > bd:
						bd = d
						best = p
			if best != null:
				go_to(n, best, {"run": true, "urgent": true})
			else:
				b.phase = 1
			if n.visible:
				speak(n, pick(LINES.flee), "shout"),
		func(n, b, dt):
			if b.phase == 0:
				if step_nav(n, dt) != "go":
					b.phase = 1
					b.t = 0.0
					set_base(n, "cower")
				return b.t > 40
			return b.t > rnd(5, 8),
		func(n, _b):
			set_base(n, "idle")
			n.mood -= 0.2)
	_beh("callSec", func(n, b):
			speak(n, pick(LINES.call), "shout")
			var pp: Dictionary = b.from
			var dx: float = n.x - pp.x
			var dz: float = n.z - pp.z
			var l := Vector2(dx, dz).length()
			if not l:
				l = 1.0
			var t := {"x": n.x + dx / l * 3.5, "z": n.z + dz / l * 3.5, "level": n.level}
			if M.degagement(n.level, t.x, t.z) > 0.4 and M.libre(n, t, 0.3, n.level):
				go_to(n, t, {"run": true, "urgent": true}),
		func(n, b, dt):
			if n.nav != null:
				step_nav(n, dt)
				return false
			var pp := player_pos()
			face(n, pp.x, pp.z, dt)
			if b.phase == 0:
				b.phase = 1
				b.t = 0.0
				set_base(n, "phone")
			if b.phase == 1 and b.t > 3.5:
				b.phase = 2
				if P.wanted == null and not P.busy and not n.hostile:
					var u = P.unseen
					wanted(u.sev if u != null and u.n == n else (2 if n.kind == "staff" else 1), "appel", n)
			return b.t > 9,
		func(n, _b): set_base(n, "idle"))
	# --- vigile qui poursuit le joueur ---
	_beh("chase", func(n, b):
			n.rank = 4
			n.chase = "player"
			b.re = 0.0
			b.said = false
			note("guard:poursuite"),
		func(n, b, dt):
			var pp := player_pos()
			var d := Vector2(pp.x - n.x, pp.z - n.z).length()
			var same: bool = pp.level == n.level
			if P.wanted == null or P.busy:
				return true
			if now > P.wanted.until:
				P.wanted = null
				toast("La sécurité a perdu votre trace.")
				return true
			if d < 1.45 and same and interruptible(n):
				n.nav = null
				set_move(n, null)
				arrest(n)
				return true
			if now > b.re and interruptible(n):
				b.re = now + 0.45
				go_to(n, pp, {"run": true, "stop": 1.1, "urgent": true, "speed": 5.4})
			if n.nav != null:
				if step_nav(n, dt) == "fail":
					b.re = 0.0
			if b.t > 3 and not b.said and d < 9:
				b.said = true
				speak(n, pick(LINES.arrest), "shout")
			return false,
		func(n, _b):
			n.rank = 3
			n.chase = null
			if n.nav != null and interruptible(n):
				n.nav = null
				set_move(n, null))
	_beh("provoke", func(n, b):
			b.re = 0.0
			n.rank = 4
			note("provocation"),
		func(n, b, dt):
			var pp := player_pos()
			var d := Vector2(pp.x - n.x, pp.z - n.z).length()
			var same: bool = pp.level == n.level
			if P.busy or J.mode != "walk":
				return true
			if b.phase == 0:
				if d < 1.5 and same and interruptible(n):
					n.nav = null
					set_move(n, null)
					b.phase = 1
					b.t = 0.0
					speak(n, pick(LINES.provoke), "angry", 3)
					set_base(n, "talk")
					return false
				if now > b.re and interruptible(n):
					b.re = now + 0.6
					go_to(n, pp, {"stop": 1.2, "urgent": true, "speed": 3.6 if d > 4 else 0.0, "run": d > 4})
				if n.nav != null:
					step_nav(n, dt)
				return b.t > 30
			face(n, pp.x, pp.z, dt, 8)
			if b.phase == 1 and b.t > 2.2:
				if d > 3.2 or not same:
					b.phase = 0
					b.t = 22.0
					return false
				b.phase = 2
				b.t = 0.0
				set_base(n, "idle")
				gesture(n, "throw", 0.9)
				set_timeout_sim(0.35, func():
					if not n.gone and n.beh == b and not P.busy:
						hurt_player(n, 0, true))
			elif b.phase == 2 and b.t > 3:
				if d > 5 or not same:
					speak(n, pick(LINES.provokeEnd), "angry")
					n.mood -= 0.1
					return true
				speak(n, pick(LINES.provoke2), "shout")
				n.firstBlow = true
				n.beh = null
				set_beh(n, "combat", {"hits": irnd(3, 4)})
			return false,
		func(n, _b):
			n.rank = 1
			set_base(n, "idle"))


func pick_provoker():
	var pp := player_pos()
	var c: Array = clients.filter(func(n): return idle_client(n) and n.level == pp.level and Vector2(n.x - pp.x, n.z - pp.z).length() < 28)
	return wpick(c, func(n): return (0.2 + n.heat + n.drunk) / (1 + Vector2(n.x - pp.x, n.z - pp.z).length() / 8))


func provoke(n = null):
	if not ready_ or P.busy or J.mode != "walk":
		return null
	if n == null:
		n = pick_provoker()
	if n == null or not interrupt(n, "provoke"):
		return null
	event("provoke", {"id": n.id})
	return n


func player_tick(dt: float, rdt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in range(real_timers.size() - 1, -1, -1):
		if i < real_timers.size() and t >= real_timers[i].at:
			var x: Dictionary = real_timers[i]
			real_timers.remove_at(i)
			x.fn.call()
	if P.fist > 0:
		P.fist = maxf(0.0, P.fist - rdt)
	if P.kick > 0:
		var d := minf(P.kick, rdt * 0.35)
		P.kick -= d
		if not P.busy:
			_regard(d if P.fist > 0.15 else -d * 0.6)
		if P.kick < 1e-4:
			P.kick = 0.0
	# santé : régénération lente hors combat
	if not P.busy and P.hp < CFG.playerHp and now - P.hitT > 8:
		P.hp = minf(CFG.playerHp, P.hp + dt * 3)
	if P.unseen != null and now - P.unseen.at > 20:
		P.unseen = null
	for n in all:
		if n.hostile and now - n.hostileT > 40:
			n.hostile = false
			n.firstBlow = false
	# un fauteur de trouble de temps en temps
	if now >= P.provokeT:
		var in_public: bool = J.mode == "walk" and not _joueur_gele() and not is_staff_zone(J.x, J.z, J.level) and P.wanted == null and P.attackers.is_empty() and J.link == null and J.elevator == null
		if in_public and provoke() != null:
			P.provokeT = now + rr(CFG.provokeEvery)
		else:
			P.provokeT = now + 10
	P.veil = maxf(0.0, P.veil - rdt * 1.6)


## Le joueur est-il tenu hors du jeu (un panneau de table ouvert, la carte…) ? Alors W.isEnabled() est faux.
func _joueur_gele() -> bool:
	var p = scene.player if scene != null else null
	return p != null and p.frozen and not _gele


## Le petit recul du regard quand on frappe (vue à la première personne).
func _regard(d: float) -> void:
	var p = scene.player if scene != null else null
	if p == null or p.follow_camera != null and p.follow_camera.current:
		return
	var pitch: float = p.get("_pitch") + d
	p.set("_pitch", pitch)
	p.camera.rotation.x = pitch


## Le joueur, chaque image : sa place pour les PNJ, la poussée et l'étourdissement.
func _joueur(dt: float) -> void:
	var p = scene.player if scene != null else null
	if p == null:
		return
	var g: Vector3 = (p as Node3D).global_position
	J.x = g.x
	J.z = g.z
	J.y = g.y
	J.level = M.niveau_a(g.y) if not essai else J.level
	J.link = null
	# sur un escalier, un escalator ou une rampe : dans l'emprise d'une liaison du niveau, hors de son sol
	var Lv = M.niveaux.get(J.level)
	if Lv != null and absf(M.niveau_y(J.level) - g.y) > 0.15:
		J.link = M.dans_liaison(Lv, J.x, J.z)
	if _action_t > 0:
		_action_t -= dt
	if _etourdi > 0:
		_etourdi = maxf(0.0, _etourdi - dt)
		if not p.frozen:
			p.frozen = true
			_gele = true
	elif _gele:
		_gele = false
		p.frozen = false
	if _poussee.length() > 0.0:
		if p is CharacterBody3D:
			(p as CharacterBody3D).move_and_collide(Vector3(_poussee.x, 0, _poussee.y) * dt)
		var damp := exp(-dt * 5)
		_poussee *= damp
		if absf(_poussee.x) + absf(_poussee.y) < 0.02:
			_poussee = Vector2.ZERO


func _unhandled_input(e: InputEvent) -> void:
	if not ready_ or scene == null or scene.player == null:
		return
	var p = scene.player
	if p.frozen:
		return
	var frappe := false
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F:
		frappe = true
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and p.focus_target == null and p.follow_camera == null:
		frappe = true
	if frappe and action():
		get_viewport().set_input_as_handled()


## L'invite d'action : « F : frapper » quand on vise un PNJ et rien d'autre.
var _invite_t := -1.0
var _invite_txt := ""


## L'indication sous le réticule (engine.js) : ce que fait le clic gauche sur ce qui est visé, à 5 Hz.
func invite() -> String:
	var t := Time.get_ticks_msec() / 1000.0
	if t - _invite_t < 0.2:
		return _invite_txt
	_invite_t = t
	_invite_txt = ""
	if ready_ and not P.busy and J.mode == "walk" and J.link == null and J.elevator == null and not _joueur_gele() and aim() != null:
		_invite_txt = ("Action" if DisplayServer.is_touchscreen_available() else "Clic gauche ou F") + " : frapper"
	return _invite_txt


# ==================================================================================================
# 12. Rendu : visibilité par zone, cadence d'animation, bulles, ombres
# ==================================================================================================
var _blobs: MultiMeshInstance3D
var _bulles: Array = []
var _mat_bulle: Shader
var full_r2 := 144.0
var full_n := 0
var mix_count := 0
var vis_dirty := false
var last_vis := ""
var _cam_pos := Vector3.ZERO


func _rendu_preparer() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := PlaneMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.6))
	g.add_point(0.55, Color(0, 0, 0, 0.3))
	g.set_color(g.get_point_count() - 1, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	m.albedo_texture = gt
	m.render_priority = -1
	q.material = m
	mm.mesh = q
	mm.instance_count = BLOB_CAP
	mm.visible_instance_count = 0
	_blobs = MultiMeshInstance3D.new()
	_blobs.name = "Ombres"
	_blobs.multimesh = mm
	_blobs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blobs)
	_mat_bulle = load(BASE + "pnj/bulle.gdshader")


func _place(n: Dictionary) -> void:
	var root: Node3D = n.root
	root.position = Vector3(n.x, n.y, n.z)
	root.rotation.y = n.yaw
	var seat = n.seat
	var inner: Node3D = n.corps.inner
	if n.sitK > 0 and seat != null and seat.get("sit", false):
		var e := ease_(n.sitK)
		inner.position.y = e * (float(seat.get("seatHeight", 0.45)) - float(n.tpl.seatH))
		inner.position.z = e * float(n.tpl.hipsZ)
	elif inner.position.y != 0 or inner.position.z != 0:
		inner.position.y = 0
		inner.position.z = 0


## Une zone de l'original est-elle montrée ? (Z.isVisibleAt : la zone active) — la scène sait ce qu'elle montre.
func _zone_active(x: float, z: float, level: float) -> bool:
	if scene == null or not scene.has_method("zone_montree"):
		return true
	var zn = M.zone_a(x, z, level)
	return zn == null or scene.zone_montree(zn.id)


func _dans_cadre(cam: Camera3D, c: Vector3, r: float) -> bool:
	for pl in cam.get_frustum():
		if pl.distance_to(c) > r:
			return false
	return true


func render(n: Dictionary, dt: float, ps, cam: Camera3D) -> void:
	_place(n)
	if vis_dirty or ((frame + n.slot) & 3) == 0 or n.zLevel != n.level:
		n.zLevel = n.level
		n.zvis = not n.hidden and _zone_active(n.x, n.z, n.level)
	var dx: float = n.x - _cam_pos.x
	var dz: float = n.z - _cam_pos.z
	var dy: float = n.y - _cam_pos.y + 1.6
	var d2 := dx * dx + dz * dz + dy * dy
	n.d2 = d2
	var vis := false
	var far: float = CFG.far
	if n.zvis and not n.hidden and d2 < far * far and cam != null:
		vis = _dans_cadre(cam, Vector3(n.x, n.y + 0.95, n.z), 1.25)
	if vis != n.visible:
		n.visible = vis
		(n.root as Node3D).visible = vis
		if vis:
			n.animDirty = true
	if not vis:
		if n.label != null and n.label.visible:
			n.label.visible = false
		n.mixAcc = 0.0
		return
	if d2 < full_r2:
		full_n += 1
	if n.anim != null:
		n.anim.call(n, dt)
	# lecteurs : cadence selon la distance (1, 2, 4 ou 8 images)
	n.mixAcc += dt
	var every := 1 if d2 < full_r2 else (2 if d2 < 625 else (4 if d2 < 2025 else 8))
	if n.animDirty or every == 1 or (frame + n.slot) % every == 0:
		n.corps.avancer(minf(n.mixAcc, 0.4))
		n.mixAcc = 0.0
		n.animDirty = false
		mix_count += 1
		if n.pose != null:
			n.pose.call(n)
		if n.down and not n.downHeld and now - n.downT > 3:
			n.downHeld = true
	# tête et buste (par-dessus le clip)
	if n.lookHold > 0:
		n.lookHold -= dt
		if n.lookHold <= 0:
			n.lookYawT = 0.0
			n.lookPitchT = 0.22 if n.seatState == "seated" and n.station != null and n.station.type == "blackjack" else 0.0
	if n.leanHold > 0:
		n.leanHold -= dt
		if n.leanHold <= 0:
			n.leanT = 0.0
	var k := 1.0 if dt * 5 > 1 else dt * 5
	n.lookYaw += (n.lookYawT - n.lookYaw) * k
	n.lookPitch += (n.lookPitchT - n.lookPitch) * k
	n.lean += (n.leanT - n.lean) * k
	if d2 < 900 and not n.down:
		n.corps.os_tourner(n.corps.head, n.lookYaw, n.lookPitch)
		n.corps.os_tourner(n.corps.torso, 0, n.lean)
	# étiquette : seulement à la table du joueur
	var show: bool = ps != null and n.kind == "client" and n.station == ps and n.seatState == "seated"
	if show:
		if n.label == null:
			n.label = _etiquette(n)
		n.label.visible = true
	elif n.label != null and n.label.visible:
		n.label.visible = false


## Un panneau à texte (bulle ou étiquette de nom) : le fond dessiné par bulle.gdshader, le texte par un Label3D.
func _panneau(texte: String, largeur_px: float, canvas: Vector2, rect: Rect2, rayon: float, queue: bool, fond: Color, trait_: Color, trait_px: float, couleur: Color, taille: int, echelle: Vector2) -> Node3D:
	var n := Node3D.new()
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = echelle
	q.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = _mat_bulle
	m.set_shader_parameter("canvas", canvas)
	m.set_shader_parameter("rect", Vector4(rect.position.x, rect.position.y, rect.end.x, rect.end.y))
	m.set_shader_parameter("rayon", rayon)
	m.set_shader_parameter("queue", queue)
	m.set_shader_parameter("fond", fond)
	m.set_shader_parameter("trait_", trait_)
	m.set_shader_parameter("trait_px", trait_px)
	m.set_shader_parameter("opacite", 1.0)
	m.render_priority = 6
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(q)
	var l := Label3D.new()
	l.text = texte
	l.font = _police()
	l.font_size = taille
	l.pixel_size = echelle.x / canvas.x
	l.modulate = couleur
	l.outline_size = 0
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.render_priority = 7
	l.double_sided = true
	l.width = largeur_px
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	# le texte centré au milieu de la bulle (fillText, textBaseline middle), décalé dans le plan de la vue
	l.offset = Vector2(0, canvas.y / 2.0 - ((rect.position.y + rect.end.y) / 2.0 + 1.0))
	n.add_child(l)
	n.set_meta("quad", m)
	n.set_meta("label", l)
	return n


var _barlow: Font = null


## Barlow 600, la police des bulles et des étiquettes de l'original (secours : celle du jeu).
func _police() -> Font:
	if _barlow == null:
		var f = load(BASE + "decor/polices/barlow-600.woff2")
		if f is FontFile:
			(f as FontFile).fallbacks = [Polices.texte()]
			_barlow = f
		else:
			_barlow = Polices.texte()
	return _barlow


func _largeur(texte: String, taille: int) -> float:
	return _police().get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x


func _etiquette(n: Dictionary) -> Node3D:
	var tw := minf(236, _largeur(n.name, 34) + 36)
	var x0 := (256 - tw) / 2
	var e := _panneau(n.name, tw, Vector2(256, 64), Rect2(x0, 8, tw, 48), 22, false, Color(21 / 255.0, 18 / 255.0, 27 / 255.0, 0.84), Color("#8f6c2c"), 2.0, Color("#f3ead7"), 34, Vector2(0.46, 0.115))
	e.position = Vector3(0, 1.98, 0)
	(n.root as Node3D).add_child(e)
	return e


## Bulles : une réserve de panneaux, une par PNJ au plus.
func say(n: Dictionary, text: String, dur := 0.0) -> void:
	if n.gone or text == "" or not n.zvis or n.d2 > 34 * 34 or _hors_scene:
		return
	var b = null
	for x in _bulles:
		if x.n == n:
			b = x
			break
	if b == null:
		for x in _bulles:
			if x.n == null:
				b = x
				break
	if b == null and _bulles.size() >= int(CFG.bubbles):
		b = _bulles[0]
		for q in _bulles:
			if q.until < b.until:
				b = q
	if b != null and b.node != null:
		b.node.queue_free()
	if b == null:
		b = {"node": null, "n": null, "until": 0.0, "born": 0.0}
		_bulles.append(b)
	var tw := minf(492, _largeur(text, 30) + 40)
	var x0 := (512 - tw) / 2
	b.node = _panneau(text, tw, Vector2(512, 96), Rect2(x0, 8, tw, 58), 20, true, Color(243 / 255.0, 234 / 255.0, 215 / 255.0, 0.95), Color("#8f6c2c"), 2.5, Color("#15121b"), 30, Vector2(1.5, 0.28))
	add_child(b.node)
	b.n = n
	b.until = now + (dur if dur else clampf(1.6 + text.length() * 0.055, 2, 4.2))
	b.born = now


func _bulle_retirer(n: Dictionary) -> void:
	for b in _bulles:
		if b.n == n:
			b.n = null
			if b.node != null:
				b.node.queue_free()
				b.node = null


func tick_bubbles() -> void:
	for b in _bulles:
		if b.n == null:
			continue
		var n: Dictionary = b.n
		if now >= b.until or n.gone or not n.zvis:
			b.n = null
			if b.node != null:
				b.node.queue_free()
				b.node = null
			continue
		var k := minf(1.0, minf((now - b.born) / 0.15, (b.until - now) / 0.25))
		(b.node.get_meta("quad") as ShaderMaterial).set_shader_parameter("opacite", k)
		(b.node.get_meta("label") as Label3D).modulate.a = k
		b.node.position = Vector3(n.x, n.y + (0.9 if n.down else (1.75 if n.sitK > 0.5 else 2.12)), n.z)


# ==================================================================================================
# Ascenseurs (engine.js : addElevator, updateElevators)
# ==================================================================================================
func _ascenseurs() -> void:
	for o in M.ascenseurs:
		var E := {"id": o.id, "x": o.x, "z": o.z, "w": o.w, "d": o.d, "facing": o.facing, "label": o.label, "stops": [], "state": "idle", "cur": null, "dest": null,
			"pending": null, "t": 0.0, "y": 0.0, "y0": 0.0, "dur": 0.0, "rider": false}
		for s in o.stops:
			E.stops.append({"level": float(s.level), "y": float(s.y), "zone": s.zone, "name": s.name, "k": 0.0, "outside": s.outside, "inside": s.inside, "doorAt": s.doorAt,
				"dw": s.dw, "navNode": s.navNode})
		_tri_stable(E.stops, func(p, q): return p.y < q.y)
		E.cur = elev_stop(E, float(o.cur)) if o.cur != null else E.stops[0]
		if E.cur == null:
			E.cur = E.stops[0]
		E.y = E.cur.y
		elevators[o.id] = E
		elev_list.append(E)


func elev_stop(E: Dictionary, level):
	for s in E.stops:
		if s.level == float(level):
			return s
	return null


func elev_level(E: Dictionary):
	return E.cur.level if E.cur != null else null


func elev_go(E: Dictionary, level) -> bool:
	var s = elev_stop(E, level)
	if s == null:
		return false
	if E.state == "idle":
		if E.cur == s:
			return true
		E.dest = s
		E.state = "closing"
		E.t = 0.0
	else:
		E.pending = s
	return true


## Le point (x, z) est-il dans la cabine, à m près de ses parois (contains) ?
func elev_contains(E: Dictionary, x: float, z: float, m := 0.0) -> bool:
	var sf := sin(float(E.facing))
	var cf := cos(float(E.facing))
	var lx: float = (x - E.x) * cf - (z - E.z) * sf
	var lz: float = (x - E.x) * sf + (z - E.z) * cf
	return absf(lx) <= E.w / 2.0 - m and absf(lz) <= E.d / 2.0 - m


## L'arrêt suivant (nextStop) : celui du dessus, sinon celui du dessous.
func elev_next(E: Dictionary) -> Dictionary:
	var i: int = E.stops.find(E.cur)
	if i + 1 < E.stops.size():
		return E.stops[i + 1]
	if i - 1 >= 0:
		return E.stops[i - 1]
	return E.cur


func elev_door_open(E: Dictionary, level) -> bool:
	var s = elev_stop(E, level)
	return s != null and s.k > 0.6


func update_elevators(dt: float) -> void:
	for E in elev_list:
		if E.state == "closing":
			if E.cur.k <= 0.02:
				E.state = "moving"
				E.t = 0.0
				E.y0 = E.cur.y
				E.dur = maxf(1.8, absf(E.dest.y - E.cur.y) / 2.2)
				# le joueur dans la cabine part avec elle
				E.rider = not essai and J.mode == "walk" and J.link == null and J.level == E.cur.level and elev_contains(E, J.x, J.z)
				if E.rider:
					J.elevator = E
		elif E.state == "moving":
			E.t = minf(1.0, E.t + dt / E.dur)
			E.y = E.y0 + (E.dest.y - E.y0) * ease_(E.t)
			if E.t >= 1:
				E.cur = E.dest
				E.dest = null
				E.y = E.cur.y
				E.state = "idle"
				if E.rider:
					E.rider = false
					J.elevator = null
				if E.pending != null:
					var p: Dictionary = E.pending
					E.pending = null
					if p != E.cur:
						elev_go(E, p.level)
		for S in E.stops:
			var open: float = 1.0 if E.state == "idle" and E.cur == S else 0.0
			if S.k != open:
				S.k += signf(open - S.k) * minf(absf(open - S.k), dt * 1.7)
	if scene != null and scene.has_method("ascenseurs_animer"):
		scene.ascenseurs_animer(elevators)


# ==================================================================================================
# 13. Population, boucle, API
# ==================================================================================================
var client_target := 0
var staff_target := 0
var ext_decide: Array = []
var ext_tick: Array = []
var ext_start: Array = []
## La vague « vie » (pnj/vie.gd) : le Strip, le concert, l'arène.
var vie = null
const HOT := {"respond": 1, "chase": 1, "combat": 1, "provoke": 1, "escort": 1, "escorted": 1, "fight": 1, "spectate": 1, "ko": 1, "held": 1, "flee": 1, "callSec": 1, "getup": 1}


func compute_targets() -> void:
	staff_target = roundi(target_pop * CFG.staffShare)
	var posts: Array = list_posts().filter(func(p): return p.get("npc") == null)
	for p in posts:
		if staff.size() >= staff_target:
			break
		create_staff(p)
	client_target = maxi(0, mini(target_pop - staff.size(), roundi(world.seats * CFG.seatShare)))


func spawn_ok(p: Dictionary) -> bool:
	for o in neighbours(float(p.get("level", 0)), p.x, p.z):
		if Vector2(o.x - p.x, o.z - p.z).length() < 0.8:
			return false
	if J.level == float(p.get("level", 0)) and Vector2(J.x - p.x, J.z - p.z).length() < 1.0:
		return false
	return true


func spawn_at_door() -> bool:
	var ps: Array = M.donnees.spawns
	if ps.is_empty():
		return spawn_in_place()
	var p = null
	var o := irnd(0, ps.size() - 1)
	for i in ps.size():
		var c: Dictionary = ps[(i + o) % ps.size()]
		if spawn_ok(c):
			p = c
			break
	if p == null:
		return false
	var n = create_client()
	if n == null:
		return false
	n.x = p.x
	n.z = p.z
	n.level = float(p.get("level", 0))
	n.y = M.niveau_y(n.level)
	n.yaw = 0.0
	n.wait = rnd(0.2, 0.8)
	set_beh(n, "decide")
	note("entrée")
	return true


func spawn_in_place() -> bool:
	var lv = wpick(world.publicLevels, func(l): return l.area)
	if lv == null:
		lv = world.publicLevels[0]
	var p = random_public_point(lv.level)
	if p == null:
		p = random_public_point(0.0)
	if p == null:
		return false
	var n = create_client()
	if n == null:
		return false
	n.x = p.x
	n.z = p.z
	n.level = p.level
	n.y = M.niveau_y(n.level)
	n.yaw = rnd(-PI, PI)
	n.wait = rnd(0.2, 6)
	n.visits = irnd(0, 3)
	set_beh(n, "decide")
	return true


func active() -> int:
	var c := 0
	for n in clients:
		if not n.retire:
			c += 1
	return c


func population() -> void:
	var a := active()
	if a < client_target and now >= spawn_t:
		spawn_t = now + (rr(CFG.spawnEvery) if spawn_at_door() else 1.0)
	elif a > client_target:
		var c: Array = clients.filter(func(x): return not x.retire)
		var n = null
		for x in c:
			if idle_client(x):
				n = x
				break
		if n == null and c.size():
			n = c[0]
		if n != null:
			n.retire = true
	if player_join != null:
		var pj: Dictionary = player_join
		if player_station() != pj.station:
			player_join = null
		elif pj.step < 2 and now >= pj.t[pj.step]:
			if pj.step == 1 and not pj.second:
				pj.step = 2
			elif recruit(pj.station, pj.base + pj.step + 1):
				pj.step += 1
			else:
				pj.t[pj.step] = now + 2.5


func step_npc(n: Dictionary, dt: float) -> void:
	tick_gesture(n)
	if n.kind == "client":
		tick_needs(n, dt)
	if n.trailOn:
		leave_trail(n)
	var b = n.beh
	if b == null:
		next_(n)
		return
	b.t += dt
	var done: bool = BEH[b.type].step.call(n, b, dt)
	if n.gone:
		return
	if done and n.beh == b:
		end_beh(n)
	if n.beh == null:
		next_(n)


var _reel := 0.0


func update(dt: float) -> void:
	if not ready_ or dt <= 0:
		return
	var t0 := Time.get_ticks_usec() / 1e6
	var rdt := minf(0.1, maxf(0.0, t0 - _reel))
	_reel = t0
	now += dt
	frame += 1
	paths_left = int(CFG.pathsPerFrame)
	_fil_recevoir()
	if not essai:
		_joueur(dt)
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		_cam_pos = cam.global_position
	build_grid()
	for f in ext_tick:
		f.call(dt)
	population()
	update_elevators(dt)
	var R2: float = CFG.nearSim * CFG.nearSim
	for i in range(all.size() - 1, -1, -1):
		if i >= all.size():
			continue
		var n: Dictionary = all[i]
		n.simAcc += dt
		var dx: float = n.x - J.x
		var dz: float = n.z - J.z
		n.near = n.zvis or (dx * dx + dz * dz < R2 and absf(n.y - J.y) < 4) or n.fight != null or (n.beh != null and HOT.has(n.beh.type)) or now - n.cctvT < 2 or n.trailOn or n.follow != null
		if n.near or (frame + n.slot) % int(CFG.farEvery) == 0:
			var d: float = n.simAcc
			n.simAcc = 0.0
			step_npc(n, d)
	fights_tick(dt)
	player_tick(dt, rdt)
	for i in range(convs.size() - 1, -1, -1):
		if convs[i].over and convs[i].members.is_empty():
			convs.remove_at(i)
	if _hors_scene:
		return
	# rendu
	var ps = player_station()
	mix_count = 0
	full_n = 0
	var vz := "%s|%s" % [zone_of(J.x, J.z, J.level), J.level]
	vis_dirty = vz != last_vis
	last_vis = vz
	var bc := 0
	var mm: MultiMesh = _blobs.multimesh
	for n in all:
		render(n, dt, ps, cam)
		if n.visible and bc < BLOB_CAP and n.inElev == null:
			var s := 1.3 if n.down else (0.6 if n.sitK > 0.5 else 0.82)
			mm.set_instance_transform(bc, Transform3D(Basis.from_scale(Vector3(s, 1, s)), Vector3(n.x, n.y + 0.021, n.z)))
			bc += 1
	mm.visible_instance_count = bc
	if full_n > CFG.fullRate:
		full_r2 = maxf(4.0, full_r2 * 0.85)
	elif full_n < CFG.fullRate - 2 and full_r2 < 144:
		full_r2 = minf(144.0, full_r2 * 1.08)
	tick_bubbles()
	if HUD != null:
		HUD.chaque_image(rdt)


func _process(dt: float) -> void:
	update(dt)


func start() -> void:
	_beh_communs()
	_beh_clients()
	_beh_personnel()
	_beh_bagarres()
	_beh_joueur()
	index_world()
	if pop_auto:
		target_pop = int(CFG.population)
	if not essai:
		_joueur(0.0)
	computeTargets_()
	# le casino est déjà en marche à l'ouverture : la plupart des clients sont sur place, les autres entrent par la porte
	var k := roundi(client_target * 0.85)
	for i in k:
		spawn_in_place()
	if vie == null and not _hors_scene:
		vie = load(BASE + "pnj/vie.gd").new(self, scene)
	for f in ext_start:
		f.call()
	spawn_t = now + 1.5
	fight_t = now + rnd(45, 80)
	P.provokeT = now + rr(CFG.provokeEvery) * 0.6
	courier.nextT = now + rnd(25, 45)
	P.hp = CFG.playerHp
	ready_ = true
	_reel = Time.get_ticks_usec() / 1e6


func computeTargets_() -> void:
	compute_targets()


## Avance la simulation de sec secondes sans rendu (essais).
func simulate(sec: float, step := 1.0 / 30) -> float:
	if not ready_:
		return 0.0
	var t := 0.0
	while t < sec:
		update(step)
		t += step
	return now


## Contrôle d'intégrité pour les essais : PNJ dans un obstacle, places et points orphelins.
func check() -> Dictionary:
	var bad: Array = []
	var leaks: Array = []
	for n in all:
		if n.hidden or n.proxyOf != null or (n.seatState != null and n.seatState != "fromSeat") or (n.nav != null and (n.nav.link != null or n.nav.elev != null)) or n.inElev != null or (n.beh != null and n.beh.type == "post" and n.nav == null):
			continue
		var c: float = M.degagement(n.level, n.x, n.z)
		if c < 0.02:
			bad.append({"id": n.id, "role": n.role, "beh": n.beh.type if n.beh != null else null, "x": snappedf(n.x, 0.01), "z": snappedf(n.z, 0.01), "level": n.level, "clearance": snappedf(c, 0.01), "zone": zone_of(n.x, n.z, n.level)})
	for st in M.stations:
		for s in st.seats:
			var o = s.occupant
			if o != null and o != "player":
				var n = by_id.get(o)
				if n == null:
					leaks.append("place %s#%d tenue par %s (disparu)" % [st.id, s.index, o])
				elif n.seat != s:
					leaks.append("place %s#%d tenue par %s qui est ailleurs (%s)" % [st.id, s.index, o, n.beh.type if n.beh != null else "?"])
	for n in all:
		if n.seat != null and n.seat.occupant != n.id:
			leaks.append("%s croit tenir %s#%d" % [n.id, n.station.id if n.station != null else "?", n.seat.index])
	for k in M.points:
		for p in M.points[k]:
			if p.get("_occ") != null:
				var n = by_id.get(p._occ)
				if n == null or not p in n.points:
					leaks.append("point %s %s tenu par %s" % [k, p.get("zone", ""), p._occ])
	for id in world.lines:
		for m in world.lines[id].members:
			if m.gone or m.line != world.lines[id]:
				leaks.append("file %s : %s" % [id, m.id])
	return {"inObstacle": bad, "leaks": leaks}


func stats() -> Dictionary:
	var vis := 0
	var roles := {}
	for n in all:
		if n.visible:
			vis += 1
		roles[n.role] = int(roles.get(n.role, 0)) + 1
	return {"ready": ready_, "total": all.size(), "clients": clients.size(), "staff": staff.size(), "target": target_pop, "clientTarget": client_target, "staffTarget": staff_target,
		"roles": roles, "visible": vis, "seats": world.seats, "fights": fights.size(), "simTime": snappedf(now, 0.1), "mix": mix_count}


## Force une embrouille entre deux PNJ ; sans argument : la paire la mieux placée près du joueur.
func spawn_fight(a = null, b = null, o := {}):
	if not ready_:
		return null
	if a is String:
		a = by_id.get(a)
	if b is String:
		b = by_id.get(b)
	if a == null or b == null:
		var pp := player_pos()
		var pool: Array = clients.filter(func(n): return free_client(n) and not is_staff_zone(n.x, n.z, n.level))
		var cle := func(n): return Vector2(n.x - pp.x, n.z - pp.z).length() + absf(n.level - pp.level) * 40
		_tri_stable(pool, func(p, q): return cle.call(p) < cle.call(q))
		if a == null:
			a = pool[0] if pool.size() else null
		if a == null:
			return null
		var autres: Array = pool.filter(func(n): return n != a and n.level == a.level)
		_tri_stable(autres, func(p, q): return dist(p, a) < dist(q, a))
		b = autres[0] if autres.size() else null
	var f = start_fight(a, b, o.get("cause"))
	if f == null:
		return null
	f.force = not o.get("mayCool", false)
	return f


func send_courier() -> bool:
	if not ready_ or courier.lead == null:
		return false
	if courier.active:
		return true
	courier.nextT = now
	return true


# --------------------------------------------------------------------------------------------------
# Le fil des chemins : un monde à lui (monde.gd n'est pas fait pour deux fils), une file, les réponses
# --------------------------------------------------------------------------------------------------
var _fil: Thread
var _fil_monde
var _fil_mutex := Mutex.new()
var _fil_sem := Semaphore.new()
var _fil_file: Array = []
var _fil_rendus: Array = []
var _fil_fin := false
var _fil_attente := {}
var _fil_serie := 0


func _fil_demarrer() -> void:
	if synchrone:
		return
	_fil_monde = load(BASE + "pnj/monde.gd").new()
	_fil_monde.donnees_de(M)
	_fil = Thread.new()
	_fil.start(_fil_boucle)


func _fil_arreter() -> void:
	if _fil == null:
		return
	_fil_mutex.lock()
	_fil_fin = true
	_fil_mutex.unlock()
	_fil_sem.post()
	_fil.wait_to_finish()
	_fil = null


func _fil_demande(v: Dictionary, from: Dictionary, to: Dictionary, ok: bool, urgent: bool) -> void:
	if _fil == null:
		v.res = M.route(from, to, ok)
		v.has_res = true
		return
	_fil_serie += 1
	_fil_attente[_fil_serie] = v
	_fil_mutex.lock()
	var r := [_fil_serie, from, to.duplicate(), ok]
	if urgent:
		_fil_file.push_front(r)
	else:
		_fil_file.append(r)
	_fil_mutex.unlock()
	_fil_sem.post()


func _fil_boucle() -> void:
	while true:
		_fil_sem.wait()
		_fil_mutex.lock()
		if _fil_fin:
			_fil_mutex.unlock()
			return
		var r = _fil_file.pop_front() if _fil_file.size() else null
		_fil_mutex.unlock()
		if r == null:
			continue
		var p = _fil_monde.route(r[1], r[2], r[3])
		_fil_mutex.lock()
		_fil_rendus.append([r[0], p])
		_fil_mutex.unlock()


func _fil_recevoir() -> void:
	if _fil == null:
		return
	_fil_mutex.lock()
	var rendus := _fil_rendus
	_fil_rendus = []
	_fil_mutex.unlock()
	for r in rendus:
		var v = _fil_attente.get(r[0])
		if v == null:
			continue
		_fil_attente.erase(r[0])
		v.res = r[1]
		v.has_res = true


## Les chemins en attente (essais) : vrai quand le fil a tout rendu.
func chemins_rendus() -> bool:
	_fil_mutex.lock()
	var vide: bool = _fil_file.is_empty()
	_fil_mutex.unlock()
	return vide and _fil_attente.is_empty()
