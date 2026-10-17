extends Node
## Les biens du joueur (autoload « Biens ») : parts, maisons, tenues, véhicules, et ce qu'ils rapportent.
## Une maison se loue (elle verse sa rente) ou s'habite (elle n'en verse plus, mais compte double en
## standing, meubles en plus) : docs/SUITE.md, section 3.
## Au premier degré, posséder est la suite logique de gagner : le village vend ses parts, Maître Garnier
## signe, M. Brunet finance. Le temps se compte en mises, comme les intérêts : toutes les 20 mises,
## c'est « la recette » : chaque bien verse sa rente et coûte ses charges. Les rentes ne valent jamais
## tout à fait celles de la brochure, et rien de tout cela ne compte dans le total gagné au jeu.
## La fiche est dans docs/GESTION.md.

signal changed
## Un mot pour le joueur : la recette, une reprise de M. Brunet, une tournée (le carnet l'affiche).
signal note(text: String)

## Une recette toutes les 20 mises, au même rythme que les intérêts de M. Brunet.
const PERIOD := 20
## La recette réelle d'une part, comparée à la rente annoncée : tirée entre ces deux bornes à chaque fois.
const YIELD_MIN := 0.35
const YIELD_MAX := 1.0
## La recette suit l'animation du village, et l'animation, c'est le joueur : elle n'est pleine que si
## l'on a misé au moins ANIMATION crédits sur les 20 mises (25 par mise en moyenne).
const ANIMATION := 500
## Ce que Maître Garnier, Roger Fradin ou Raymonde reprennent d'un bien : 60 % du prix payé.
const RESALE := 0.6
## M. Brunet « allège le dossier » quand la dette dépasse ce seuil et trois fois la valeur des biens.
const REPRISE_DEBT := 10000
const REPRISE_RATIO := 4.0
const REPRISE_EVERY := 5   # recettes entre deux reprises
## La tournée générale au café : prix de base, plus un supplément par point de standing.
const TOURNEE_BASE := 120
const TOURNEE_PER_STANDING := 40

## Le catalogue. kind : « part » (rente), « maison » (loyer et standing), « tenue » (on n'en porte qu'une),
## « vehicule » (on n'en conduit qu'un). price : prix du premier ; growth : multiplicateur des suivants.
## rente et charge : par recette (20 mises), par exemplaire. gate : total gagné au jeu pour que le
## vendeur le propose (le seuil du lieu concerné ; les seuils eux-mêmes ne bougent pas).
const CATALOGUE := [
	# Chez Maître Garnier, notaire : les parts du village.
	{"id": "smarvoise", "kind": "part", "seller": "notaire", "name": "Une part de la Smarvoise",
		"price": 200, "growth": 1.5, "max": 5, "rente": 20, "charge": 0, "standing": 0, "gate": 0,
		"from": "Josiane", "blurb": "« Ma Smarvoise tourne tous les soirs. Avec une part, elle tourne aussi pour vous. »"},
	{"id": "cotes", "kind": "part", "seller": "notaire", "name": "Une part du tableau des cotes",
		"price": 500, "growth": 1.5, "max": 4, "rente": 50, "charge": 0, "standing": 0, "gate": 1000,
		"from": "Lucien", "blurb": "« Statistiquement, le bookmaker gagne toujours. Devenez le bookmaker. »"},
	{"id": "fournil", "kind": "part", "seller": "notaire", "name": "Une commandite au fournil",
		"price": 1200, "growth": 1.5, "max": 4, "rente": 120, "charge": 0, "standing": 0, "gate": 3000,
		"from": "Mme Ferrand", "blurb": "« Le pain se vend tous les jours. Les grilles aussi. »"},
	{"id": "comite", "kind": "part", "seller": "notaire", "name": "Une part du comité des fêtes",
		"price": 3000, "growth": 1.5, "max": 3, "rente": 300, "charge": 0, "standing": 1, "gate": 8000,
		"from": "M. Gaudin", "blurb": "« Rabelais aimait le jeu. Il aurait pris des parts, j'en suis certain. »"},
	{"id": "casino", "kind": "part", "seller": "notaire", "name": "Une action du Casino de Smarves",
		"price": 6000, "growth": 1.4, "max": 10, "rente": 600, "charge": 0, "standing": 1, "gate": 5000,
		"from": "Monsieur Armand", "blurb": "« La maison gagne toujours, Monsieur. Soyez la maison. »"},
	# Chez Maître Garnier aussi : les murs.
	{"id": "chambre", "kind": "maison", "seller": "notaire", "name": "La chambre au-dessus du café",
		"price": 800, "growth": 1.0, "max": 1, "rente": 80, "charge": 5, "standing": 1, "gate": 0, "lot": "chambre_cafe",
		"from": "Josiane", "blurb": "« Louée tous les samedis aux joueurs qui ratent le dernier car pour Poitiers. »"},
	{"id": "maison", "kind": "maison", "seller": "notaire", "name": "La maison de la rue de l'Église",
		"price": 5000, "growth": 1.0, "max": 1, "rente": 480, "charge": 40, "standing": 3, "gate": 3000, "lot": "maison_eglise",
		"from": "Maître Garnier", "blurb": "« Pierre de taille, jardin, vue sur le clocher. Un placement de père de famille. »"},
	{"id": "maison_place", "kind": "maison", "seller": "notaire", "name": "La maison de maître sur la place",
		"price": 20000, "growth": 1.0, "max": 1, "rente": 1900, "charge": 180, "standing": 6, "gate": 20000, "lot": "maison_place",
		"from": "Maître Garnier", "blurb": "« Les fenêtres donnent sur le casino. Vous verrez votre avenir depuis votre lit. »"},
	# Chez Raymonde, couture et retouches : on n'en porte qu'une à la fois.
	{"id": "dimanche", "kind": "tenue", "seller": "couture", "name": "Le costume du dimanche",
		"price": 250, "growth": 1.0, "max": 1, "rente": 0, "charge": 3, "standing": 1, "gate": 0,
		"color": Color(0.16, 0.26, 0.66), "from": "Raymonde", "blurb": "« Bleu roi. On vous prendra pour un homme qui gagne. »"},
	{"id": "trois_pieces", "kind": "tenue", "seller": "couture", "name": "Le trois-pièces prince-de-galles",
		"price": 900, "growth": 1.0, "max": 1, "rente": 0, "charge": 8, "standing": 2, "gate": 1000,
		"color": Color(0.5, 0.46, 0.4), "from": "Raymonde", "blurb": "« Le gilet, c'est pour ranger les jetons près du cœur. »"},
	{"id": "smoking", "kind": "tenue", "seller": "couture", "name": "Le smoking de soirée",
		"price": 3000, "growth": 1.0, "max": 1, "rente": 0, "charge": 20, "standing": 4, "gate": 5000,
		"color": Color(0.05, 0.05, 0.07), "from": "Raymonde", "blurb": "« Monsieur Armand reconnaît un smoking de chez Raymonde au premier coup d'œil. »"},
	# Au garage Fradin : on n'en conduit qu'un à la fois.
	{"id": "mobylette", "kind": "vehicule", "seller": "garage", "name": "La Mobylette bleue",
		"price": 500, "growth": 1.0, "max": 1, "rente": 0, "charge": 5, "standing": 1, "gate": 0,
		"model": "", "from": "Roger Fradin", "blurb": "« Deux temps, mélange à 5 %. Elle vous emmène au casino sans pédaler. »"},
	{"id": "deux_cv", "kind": "vehicule", "seller": "garage", "name": "La 2 CV",
		"price": 2200, "growth": 1.0, "max": 1, "rente": 0, "charge": 20, "standing": 3, "gate": 1000,
		"model": "res://assets/kaykit/city/car_hatchback.gltf", "from": "Roger Fradin", "blurb": "« La voiture de Dédé. Il l'a perdue au 421, je l'ai remise à neuf. »"},
	{"id": "ds", "kind": "vehicule", "seller": "garage", "name": "La DS 21",
		"price": 9000, "growth": 1.0, "max": 1, "rente": 0, "charge": 70, "standing": 6, "gate": 20000,
		"model": "res://assets/kaykit/city/car_sedan.gltf", "from": "Roger Fradin", "blurb": "« Suspension hydraulique. On ne sent plus les pavés, ni les pertes. »"},
]

const SELLERS := {
	"notaire": {"name": "L'étude de Maître Garnier", "host": "Maître Garnier", "scene": "res://scenes/notaire.tscn"},
	"couture": {"name": "Raymonde, couture et retouches", "host": "Raymonde", "scene": "res://scenes/couture.tscn"},
	"garage": {"name": "Le garage Fradin", "host": "Roger Fradin", "scene": "res://scenes/garage.tscn"},
}

const SAVE_PATH := "user://smarves_biens.save"

## Combien d'exemplaires de chaque bien on possède.
var owned := {}
## La tenue portée et le véhicule conduit (« » : aucun).
var worn := ""
var driven := ""
## Les logements possédés, par id du catalogue : {lot, habite, interieur, meubles {emplacement: id}, facade}.
## Les meubles achetés sont comptés dans owned comme les autres biens ; ici, seulement où ils sont posés.
var logements := {}
## Les trouvailles de l'exploration et les souvenirs de jeu : sans prix, ils ne se revendent ni ne se saisissent.
var trouvailles: Array = []
var tournees := 0
var reprises := 0
var recettes := 0
## La dernière recette, détaillée pour le carnet : [nom, versé, annoncé, charges].
var last_recette: Array = []
var last_net := 0
## Tout ce qu'ont versé les biens, et tout ce qu'ils ont coûté, depuis le début.
var total_rentes := 0
var total_charges := 0
var total_spent := 0

var _bets := 0
var _period_staked := 0
## L'animation de la dernière recette (1 : pleine).
var last_animation := 1.0
var _last_staked := 0
var _since_reprise := 0
var _busy := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load()
	_last_staked = Game.staked
	Game.changed.connect(_on_game_changed)
	changed.connect(_save)


# --- Le catalogue ----------------------------------------------------------------------------

static func item(id: String) -> Dictionary:
	for it in CATALOGUE:
		if it.id == id:
			return it
	return {}


## Le prix du n-ième exemplaire (0 : le premier).
static func price_of(id: String, n: int) -> int:
	var it := item(id)
	return int(round(it.price * pow(it.growth, n) / 10.0)) * 10


func count(id: String) -> int:
	return int(owned.get(id, 0))


func next_price(id: String) -> int:
	return price_of(id, count(id))


## Proposé par le vendeur : le lieu concerné est ouvert (sur le total gagné), et il en reste.
func available(id: String) -> bool:
	var it := item(id)
	return Game.won >= it.gate and count(id) < it.max


## Ce que le vendeur reprend du dernier exemplaire acheté.
func resale_of(id: String) -> int:
	if count(id) <= 0:
		return 0
	return int(round(price_of(id, count(id) - 1) * RESALE))


## La valeur des biens, au prix où on les reprendrait.
func value() -> int:
	var v := 0
	for id in owned:
		for n in count(id):
			v += int(round(price_of(id, n) * RESALE))
	return v


## Le standing : les maisons et les parts qui en donnent, plus la tenue portée et le véhicule conduit.
func standing() -> int:
	var s := 0
	for id in owned:
		var it := item(id)
		if it.kind in ["part", "maison"]:
			s += it.standing * count(id)
	var home := habite()
	if home != "":
		s += item(home).standing
		for slot in logements[home].meubles:
			s += int(item(str(logements[home].meubles[slot])).get("standing", 0))
	if worn != "":
		s += item(worn).standing
	if driven != "":
		s += item(driven).standing
	return s


func rente_annoncee() -> int:
	var r := 0
	for id in owned:
		if not is_habite(id):
			r += item(id).rente * count(id)
	return r


# --- Les logements : habiter ou louer --------------------------------------------------------

## Le logement habité (« » : on dort à l'hôtel du casino, chez Monsieur Armand).
func habite() -> String:
	for id in logements:
		if logements[id].habite:
			return id
	return ""


func is_habite(id: String) -> bool:
	return logements.has(id) and logements[id].habite


## On s'installe : le logement cesse d'être loué, l'ancien domicile se remet en location.
func habiter(id: String) -> void:
	if not logements.has(id):
		return
	for other in logements:
		logements[other].habite = other == id
	changed.emit()


func louer(id: String) -> void:
	if logements.has(id):
		logements[id].habite = false
		changed.emit()


## Ce que valent les meubles posés dans un logement, au prix de reprise.
func meubles_value(id: String) -> int:
	var v := 0
	if logements.has(id):
		for slot in logements[id].meubles:
			var m := item(str(logements[id].meubles[slot]))
			if not m.is_empty():
				v += int(round(m.price * RESALE))
	return v


func _new_logement(id: String) -> Dictionary:
	return {"lot": str(item(id).get("lot", "")), "habite": false, "interieur": id + "_v1", "meubles": {}, "facade": {}}


## Le logement quitte le joueur : les meubles posés et les trouvailles se décrochent.
func _drop_logement(id: String) -> void:
	logements.erase(id)


func charges() -> int:
	var c := 0
	for id in owned:
		var it := item(id)
		if it.kind in ["part", "maison"]:
			c += it.charge * count(id)
	if worn != "":
		c += item(worn).charge
	if driven != "":
		c += item(driven).charge
	return c


func outfit_color(default: Color) -> Color:
	return item(worn).color if worn != "" else default


func tournee_price() -> int:
	return TOURNEE_BASE + TOURNEE_PER_STANDING * standing()


## Le véhicule, prêt à poser (au garage, ou garé sur la place) : un modèle KayKit, ou la Mobylette,
## dessinée ici faute de deux-roues dans les packs. Roues au sol, à l'échelle des voitures KayKit (une 2 CV
## y mesure 0,8 : multiplier par 4,5 pour l'échelle d'un intérieur).
static func build_vehicle(id: String) -> Node3D:
	var it := item(id)
	if it.is_empty():
		return null
	if str(it.get("model", "")) != "":
		return load(it.model).instantiate()
	var root := Node3D.new()
	root.name = "Mobylette"
	var body := Node3D.new()
	body.scale = Vector3.ONE * 0.24
	root.add_child(body)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.2, 0.45, 0.85)
	blue.metallic = 0.3
	blue.roughness = 0.35
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.07)
	dark.roughness = 0.8
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.85, 0.85, 0.88)
	chrome.metallic = 1.0
	chrome.roughness = 0.2
	var seat := StandardMaterial3D.new()
	seat.albedo_color = Color(0.35, 0.2, 0.12)
	seat.roughness = 0.6
	var parts := [
		# [forme, taille, position, rotation x, matériau]
		["tore", Vector2(0.17, 0.25), Vector3(0, 0.25, 0.42), 0.0, dark],
		["tore", Vector2(0.17, 0.25), Vector3(0, 0.25, -0.42), 0.0, dark],
		["boite", Vector3(0.08, 0.08, 0.7), Vector3(0, 0.42, 0.0), -8.0, blue],
		["boite", Vector3(0.22, 0.22, 0.3), Vector3(0, 0.36, -0.12), 0.0, blue],
		["boite", Vector3(0.2, 0.06, 0.34), Vector3(0, 0.62, -0.22), 0.0, seat],
		["boite", Vector3(0.05, 0.6, 0.05), Vector3(0, 0.52, 0.36), -20.0, chrome],
		["boite", Vector3(0.5, 0.03, 0.03), Vector3(0, 0.82, 0.3), 0.0, chrome],
		["boite", Vector3(0.24, 0.05, 0.3), Vector3(0, 0.46, 0.42), 0.0, blue],
		["boite", Vector3(0.1, 0.1, 0.06), Vector3(0, 0.74, 0.36), 0.0, chrome],
		["boite", Vector3(0.18, 0.04, 0.26), Vector3(0, 0.48, -0.44), 0.0, blue],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		if p[0] == "tore":
			var t := TorusMesh.new()
			t.inner_radius = p[1].x
			t.outer_radius = p[1].y
			mi.mesh = t
			mi.rotation_degrees.z = 90.0
		else:
			var b := BoxMesh.new()
			b.size = p[1]
			mi.mesh = b
			mi.rotation_degrees.x = p[3]
		mi.material_override = p[4]
		mi.position = p[2]
		body.add_child(mi)
	return root


# --- Acheter, revendre -------------------------------------------------------------------------

## Achète un exemplaire. financed : M. Brunet avance le prix, frais de dossier compris dans la dette.
func buy(id: String, financed := false) -> bool:
	if not available(id):
		return false
	var price := next_price(id)
	if financed:
		Game.borrow(price)
	elif Game.credits < price:
		return false
	_busy = true
	Game.credits -= price
	_busy = false
	total_spent += price
	owned[id] = count(id) + 1
	var it := item(id)
	# La dernière tenue achetée se porte, le dernier véhicule se conduit.
	if it.kind == "tenue":
		worn = id
	elif it.kind == "vehicule":
		driven = id
	elif it.kind == "maison" and not logements.has(id):
		logements[id] = _new_logement(id)
	Game.changed.emit()
	changed.emit()
	return true


func sell(id: String) -> int:
	if count(id) <= 0:
		return 0
	var paid := resale_of(id)
	owned[id] = count(id) - 1
	if owned[id] <= 0:
		owned.erase(id)
		# Revendue par le joueur, la maison part vide : les meubles restent à lui, décrochés.
		_drop_logement(id)
		if worn == id:
			worn = _best_owned("tenue")
		if driven == id:
			driven = _best_owned("vehicule")
	_busy = true
	Game.credits += paid
	_busy = false
	Game.changed.emit()
	changed.emit()
	return paid


func wear(id: String) -> void:
	if count(id) > 0:
		if item(id).kind == "tenue":
			worn = id
		elif item(id).kind == "vehicule":
			driven = id
		changed.emit()


func _best_owned(kind: String) -> String:
	var best := ""
	for id in owned:
		var it := item(id)
		if it.kind == kind and (best == "" or it.standing > item(best).standing):
			best = id
	return best


## La tournée générale au café : Josiane remet une avance dans le tiroir, et toute la terrasse applaudit.
func offer_tournee() -> bool:
	var price := tournee_price()
	if Game.credits < price:
		return false
	_busy = true
	Game.credits -= price
	if Game.advances_left < Game.MAX_ADVANCES:
		Game.advances_left += 1
	_busy = false
	tournees += 1
	total_spent += price
	Game.changed.emit()
	changed.emit()
	return true


# --- La recette, toutes les 20 mises ---------------------------------------------------------

func _on_game_changed() -> void:
	if _busy:
		return
	if Game.staked < _last_staked:
		# Nouvelle partie : les biens repartent avec le reste.
		_wipe()
		return
	if Game.staked > _last_staked:
		_period_staked += Game.staked - _last_staked
		_last_staked = Game.staked
		_bets += 1
		if _bets >= PERIOD:
			_bets = 0
			_recette()


func _recette() -> void:
	if owned.is_empty() and worn == "" and driven == "":
		return
	recettes += 1
	last_recette = []
	var animation := minf(1.0, float(_period_staked) / ANIMATION)
	last_animation = animation
	_period_staked = 0
	var paid_total := 0
	for id in owned:
		var it := item(id)
		if it.rente <= 0 or is_habite(id):
			continue
		var announced: int = it.rente * count(id)
		var paid := int(round(announced * _rng.randf_range(YIELD_MIN, YIELD_MAX) * animation))
		paid_total += paid
		last_recette.append([it.name, paid, announced, it.charge * count(id)])
	var ch := charges()
	last_net = paid_total - ch
	total_rentes += paid_total
	total_charges += ch
	_busy = true
	Game.credits += last_net
	var text := "La recette : %s versés, %s de charges." % [Game.fmt(paid_total), Game.fmt(ch)]
	if Game.credits < 0:
		# Les charges impayées, M. Brunet les règle de lui-même : c'est ça, un vrai conseiller.
		Game.debt += -Game.credits
		text += " M. Brunet a réglé le reste : « Ne vous occupez de rien. »"
		Game.credits = 0
	_busy = false
	_since_reprise += 1
	# Une seule fiche : la reprise, s'il y en a une, s'écrit à la suite de la recette.
	var reprise := _maybe_reprise()
	if reprise != "":
		text += "\n" + reprise
	Game.changed.emit()
	changed.emit()
	note.emit(text)


## Quand la dette dépasse de loin la valeur des biens, M. Brunet reprend le plus beau, au prix de reprise,
## pour « alléger le dossier ». Il le présente comme un service, et c'en est un, à ses yeux.
func _maybe_reprise() -> String:
	if Game.debt < REPRISE_DEBT or _since_reprise < REPRISE_EVERY or owned.is_empty():
		return ""
	if Game.debt < REPRISE_RATIO * value():
		return ""
	# Une maison se reprend meublée, « c'est plus facile à revendre » : maison plus 60 % des meubles posés.
	var best := ""
	for id in owned:
		if best == "" or resale_of(id) + meubles_value(id) > resale_of(best) + meubles_value(best):
			best = id
	var amount := resale_of(best) + meubles_value(best)
	var name: String = item(best).name
	var carton := false
	var was_home := is_habite(best)
	if logements.has(best):
		for slot in logements[best].meubles:
			var m := str(logements[best].meubles[slot])
			if item(m).is_empty():
				carton = true   # une trouvaille ou un souvenir : elle reste au joueur
			elif count(m) > 0:
				owned[m] = count(m) - 1
				if owned[m] <= 0:
					owned.erase(m)
	owned[best] = count(best) - 1
	if owned[best] <= 0:
		owned.erase(best)
		_drop_logement(best)
		if worn == best:
			worn = _best_owned("tenue")
		if driven == best:
			driven = _best_owned("vehicule")
	Game.debt = maxi(0, Game.debt - amount)
	reprises += 1
	_since_reprise = 0
	var text := "M. Brunet a repris « %s » pour alléger votre dossier : %s de moins sur la dette. « Vous voilà plus léger pour investir. »" % [name, Game.fmt(amount)]
	if carton:
		text += " Un carton vous attend devant la porte : « Nous avons pris soin de vos effets personnels. »"
	if was_home:
		text += " Monsieur Armand vous garde une chambre à l'hôtel du casino."
	return text


# --- Sauvegarde : un fichier à part, qui ne touche pas à celui de la partie ---------------------

func _can_save() -> bool:
	return Game.saving_enabled and get_tree().get_script() == null and not "--capture" in " ".join(OS.get_cmdline_user_args())


func _save() -> void:
	if not _can_save():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"owned": owned, "worn": worn, "driven": driven, "bets": _bets, "period_staked": _period_staked,
		"tournees": tournees, "reprises": reprises, "recettes": recettes, "since_reprise": _since_reprise,
		"total_rentes": total_rentes, "total_charges": total_charges, "total_spent": total_spent,
		"logements": logements, "trouvailles": trouvailles}))


func _load() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			return
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var o = data.get("owned", {})
	if typeof(o) == TYPE_DICTIONARY:
		for id in o:
			if not item(id).is_empty() and int(o[id]) > 0:
				owned[id] = int(o[id])
	var l = data.get("logements", {})
	if typeof(l) == TYPE_DICTIONARY:
		for id in l:
			if count(id) > 0 and typeof(l[id]) == TYPE_DICTIONARY:
				var home := _new_logement(id)
				home.habite = bool(l[id].get("habite", false))
				for key in ["interieur"]:
					home[key] = str(l[id].get(key, home[key]))
				for key in ["meubles", "facade"]:
					if typeof(l[id].get(key)) == TYPE_DICTIONARY:
						home[key] = l[id][key]
				logements[id] = home
	# Les maisons achetées avant les logements : louées, vides.
	for id in owned:
		if item(id).kind == "maison" and not logements.has(id):
			logements[id] = _new_logement(id)
	var t = data.get("trouvailles", [])
	if typeof(t) == TYPE_ARRAY:
		trouvailles = t
	worn = str(data.get("worn", ""))
	driven = str(data.get("driven", ""))
	if count(worn) <= 0:
		worn = ""
	if count(driven) <= 0:
		driven = ""
	_bets = int(data.get("bets", 0))
	_period_staked = int(data.get("period_staked", 0))
	tournees = int(data.get("tournees", 0))
	reprises = int(data.get("reprises", 0))
	recettes = int(data.get("recettes", 0))
	_since_reprise = int(data.get("since_reprise", 0))
	total_rentes = int(data.get("total_rentes", 0))
	total_charges = int(data.get("total_charges", 0))
	total_spent = int(data.get("total_spent", 0))


func _wipe() -> void:
	owned = {}
	logements = {}
	trouvailles = []
	worn = ""
	driven = ""
	tournees = 0
	reprises = 0
	recettes = 0
	last_recette = []
	last_net = 0
	total_rentes = 0
	total_charges = 0
	total_spent = 0
	_bets = 0
	_period_staked = 0
	_since_reprise = 0
	_last_staked = Game.staked
	if _can_save() and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	changed.emit()
