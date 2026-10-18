extends Node
## La bourse (autoload « Bourse », docs/BOURSE.md) : la charge d'agent de change de Mme Vasseur, rue du
## Clain, derrière son seuil. On y prend position sur quatre valeurs réelles (le CAC 40, le S&P 500, le
## Nikkei, l'or), à la hausse ou à la baisse, avec un levier de 10 à 100.
##
## Les cours sont ceux des vraies places, en clôture quotidienne, relevés et gardés par la base
## (public.smarves_bourse, migration 20261019000000_smarves_bourse.sql) : tout le monde voit les mêmes.
## Les positions sont tenues par la base au nom du compte Pyramides : elles se lisent sur tous les
## appareils, et c'est la base qui dit quand un ordre est exécuté (à la clôture suivante), quand une
## position est liquidée et ce qu'elle rend. Le jeu ne fait que débiter la marge et créditer ce qui
## revient, une seule fois (smarves_bourse_encaisser), où que soit le joueur.
##
## L'argent : la marge et le courtage partent par Game.spend (ils comptent dans le total misé) ; ce que
## rend une position rentre dans les crédits, mais seul le bénéfice net compte dans le total gagné au
## jeu, sinon un aller-retour à plat ferait monter les seuils pour un pour cent de frais.

## Une lecture est arrivée, ou un ordre a changé quelque chose.
signal change
## Une position vient d'être encaissée : {position, rendu, garantie}.
signal encaissee(r: Dictionary)

const LEVIERS := [10, 25, 50, 100]
const MARGE_MIN := 100
const MARGE_MAX := 1000000
## Le courtage de Mme Vasseur, sur la marge, à l'ouverture.
const COURTAGE := 0.01
## Les frais de portage, sur l'exposition, par nuit.
const PORTAGE := 0.0002
## Sous cette part de la garantie, l'appel de marge ; à cette autre, la liquidation à la clôture.
const APPEL := 0.5
const LIQUIDATION := 0.2
const POSITIONS_MAX := 8
## Relire la cote au plus souvent toutes les deux minutes, et toutes les dix minutes en fond quand on a
## des positions (pour encaisser où que l'on soit).
const FRAICHEUR := 120.0
const FOND := 600.0

## Les valeurs, dans l'ordre de la cote : la place, son fuseau (décalage d'hiver, règle d'été), et ses
## heures d'ouverture et de clôture, à l'heure de la place.
const VALEURS := {
	"cac40": {"nom": "CAC 40", "place": "Paris", "ville": "de Paris", "ete": "europe", "hiver": 1, "ouverture": [9, 0], "cloture": [17, 35]},
	"sp500": {"nom": "S&P 500", "place": "New York", "ville": "de New York", "ete": "amerique", "hiver": -5, "ouverture": [9, 30], "cloture": [16, 0]},
	"nikkei": {"nom": "Nikkei 225", "place": "Tokyo", "ville": "de Tokyo", "ete": "", "hiver": 9, "ouverture": [9, 0], "cloture": [15, 30]},
	"or": {"nom": "L'or", "place": "New York", "ville": "de l'or", "ete": "amerique", "hiver": -5, "ouverture": [18, 0], "cloture": [17, 0]},
}
const ORDRE := ["cac40", "sp500", "nikkei", "or"]
## Le seuil vient du manifeste (lieu « bourse ») ; celui-ci sert hors du jeu.
const SEUIL := 7000

## « » tant que rien n'est lu, puis « lecture », « ok » ou « hors_ligne ».
var etat := ""
## La dernière lecture : {maintenant, indices: [{id, nom, place, prochaine, cours: [[jour, cloture]]}], positions}.
var donnees := {}
var _lu_a := -1000.0
var _fond := 0.0
var _essai := false
var _encaissements := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_essai = "--bourse-essai" in OS.get_cmdline_user_args()
	var agenda := get_node_or_null("/root/Agenda")
	if agenda != null:
		agenda.inscrire("bourse", rendez_vous)
	if _essai:
		_mise_en_scene()
		return
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	Compte.change.connect(func():
		if Compte.etat == "a_jour" and ouverte():
			lire(true))


func _process(delta: float) -> void:
	if _essai or etat == "lecture" or not ouverte() or not Compte.connecte():
		return
	_fond += delta
	if _fond >= FOND:
		_fond = 0.0
		if not positions().is_empty() or etat != "ok":
			lire(true)


## La charge est ouverte au joueur (son seuil, au manifeste de la commune d'origine).
func ouverte() -> bool:
	return Game.won >= seuil()


static func seuil() -> int:
	var c = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Communes")
	if c != null and c.origine() != null:
		for l in c.origine().lieux():
			if str(l.get("id", "")) == "bourse":
				return int(l.get("seuil", SEUIL))
	return SEUIL


# --- La lecture -----------------------------------------------------------------------------

## Relit la cote et les positions (au plus une fois toutes les deux minutes, sauf si forcer), puis
## encaisse ce qui a été soldé.
func lire(forcer := false) -> void:
	if _essai or etat == "lecture":
		return
	if not forcer and Time.get_ticks_msec() / 1000.0 - _lu_a < FRAICHEUR and etat == "ok":
		return
	etat = "lecture"
	var r: Dictionary = await Compte.appeler("smarves_bourse", {})
	_lu_a = Time.get_ticks_msec() / 1000.0
	if r.code == 200 and r.corps is Dictionary:
		donnees = r.corps
		etat = "ok"
	else:
		etat = "hors_ligne"
	change.emit()
	if etat == "ok":
		await _encaisser_tout()


func _encaisser_tout() -> void:
	for p in positions():
		if p.get("issue") != null and not bool(p.get("encaisse", false)):
			await encaisser(p)


## Encaisse une position soldée, liquidée ou annulée : la base ne la rend qu'une fois, à un seul appareil.
func encaisser(p: Dictionary) -> void:
	var id := int(p.id)
	if _encaissements.has(id):
		return
	_encaissements[id] = true
	var r: Dictionary = await Compte.appeler("smarves_bourse_encaisser", {"p_id": id})
	_encaissements.erase(id)
	if r.code != 200 or not r.corps is Dictionary:
		return
	p["encaisse"] = true
	if not bool(r.corps.get("ok", false)):
		change.emit()
		return
	var rendu := int(r.corps.get("rendu", 0))
	var garantie := int(r.corps.get("garantie", 0))
	crediter(rendu, garantie)
	var info := {"position": p, "rendu": rendu, "garantie": garantie}
	encaissee.emit(info)
	var carnet = get_tree().root.get_node_or_null("Carnet")
	if carnet != null:
		carnet.show_slip(phrase_encaissee(info))
	change.emit()


## Ce que rend une position : les crédits reviennent, et seul le bénéfice compte dans le total gagné.
static func crediter(rendu: int, garantie: int) -> void:
	var game = (Engine.get_main_loop() as SceneTree).root.get_node("Game")
	if rendu <= 0:
		return
	game.credits += rendu
	game.won += maxi(0, rendu - garantie)
	var b := bilan()
	b["rendu"] = int(b.get("rendu", 0)) + rendu
	game.changed.emit()


## Ce qu'on a engagé (marges, renforts, courtage) et ce qui est revenu depuis le début, gardé dans le
## tiroir de la commune d'origine pour suivre la partie d'un appareil à l'autre.
static func bilan() -> Dictionary:
	var game = (Engine.get_main_loop() as SceneTree).root.get_node("Game")
	var t: Dictionary = game.tiroir("smarves")
	if not t.has("bourse"):
		t["bourse"] = {"engage": 0, "rendu": 0}
	return t["bourse"]


func indices() -> Array:
	return donnees.get("indices", []) if donnees.get("indices") is Array else []


func indice(id: String) -> Dictionary:
	for i in indices():
		if str(i.id) == id:
			return i
	return {}


## null sans compte (la base ne sait pas qui lit), sinon les positions, les plus récentes d'abord.
func positions() -> Array:
	return donnees.get("positions", []) if donnees.get("positions") is Array else []


func ouvertes() -> Array:
	return positions().filter(func(p): return p.get("issue") == null)


# --- Les ordres -------------------------------------------------------------------------------

## Ce que coûte l'ouverture : la marge et le courtage.
static func cout(marge: int) -> int:
	return marge + courtage(marge)


static func courtage(marge: int) -> int:
	return maxi(1, int(round(marge * COURTAGE)))


## Passe un ordre, exécuté à la clôture suivante de la place : {ok: true} ou {ok: false, raison} :
## « compte », « credits », « marge », « plein », « reseau ».
func ouvrir(id: String, sens: int, levier: int, marge: int) -> Dictionary:
	if not Compte.connecte() and not _essai:
		return {"ok": false, "raison": "compte"}
	if not VALEURS.has(id) or not LEVIERS.has(levier) or not sens in [-1, 1] or marge < MARGE_MIN or marge > MARGE_MAX:
		return {"ok": false, "raison": "marge"}
	if ouvertes().size() >= POSITIONS_MAX:
		return {"ok": false, "raison": "plein"}
	var total := cout(marge)
	var game = get_tree().root.get_node("Game")
	if not game.spend(total):
		return {"ok": false, "raison": "credits"}
	if _essai:
		return _essai_ouvrir(id, sens, levier, marge, total)
	var r: Dictionary = await Compte.appeler("smarves_bourse_ouvrir", {"p_indice": id, "p_sens": sens, "p_levier": levier, "p_marge": marge})
	if r.code != 200 or not r.corps is Dictionary or not bool(r.corps.get("ok", false)):
		_rendre(total)
		var raison := "reseau"
		if r.corps is Dictionary:
			raison = "compte" if r.corps.get("erreur", "") == "jeton" else str(r.corps.get("raison", "reseau"))
		return {"ok": false, "raison": raison}
	bilan()["engage"] = int(bilan().engage) + total
	game.changed.emit()
	_ranger(r.corps.position)
	return {"ok": true, "position": r.corps.position}


## Verse de quoi éloigner la liquidation : {ok: true} ou {ok: false, raison}.
func renflouer(p: Dictionary, montant: int) -> Dictionary:
	var game = get_tree().root.get_node("Game")
	if montant < 10:
		return {"ok": false, "raison": "marge"}
	if not game.spend(montant):
		return {"ok": false, "raison": "credits"}
	if _essai:
		p.garantie = int(p.garantie) + montant
		p.valeur = int(p.get("valeur", p.garantie)) + montant
		change.emit()
		return {"ok": true}
	var r: Dictionary = await Compte.appeler("smarves_bourse_renflouer", {"p_id": int(p.id), "p_montant": montant})
	if r.code != 200 or not r.corps is Dictionary or not bool(r.corps.get("ok", false)):
		_rendre(montant)
		lire(true)
		return {"ok": false, "raison": str(r.corps.get("raison", "reseau")) if r.corps is Dictionary else "reseau"}
	bilan()["engage"] = int(bilan().engage) + montant
	game.changed.emit()
	_ranger(r.corps.position)
	return {"ok": true}


## Demande le solde à la clôture suivante (ou annule un ordre pas encore exécuté, tout est rendu).
func solder(p: Dictionary) -> Dictionary:
	if _essai:
		p.solde_a = int(donnees.maintenant)
		p.execution = int(indice(str(p.indice)).get("prochaine", 0))
		change.emit()
		return {"ok": true}
	var r: Dictionary = await Compte.appeler("smarves_bourse_solder", {"p_id": int(p.id)})
	if r.code != 200 or not r.corps is Dictionary or not bool(r.corps.get("ok", false)):
		lire(true)
		return {"ok": false, "raison": str(r.corps.get("raison", "reseau")) if r.corps is Dictionary else "reseau"}
	_ranger(r.corps.position)
	if r.corps.position.get("issue") != null:
		await encaisser(r.corps.position)
	return {"ok": true}


## Rend une somme débitée pour un ordre que la base a refusé (elle ne compte plus dans le total misé).
func _rendre(montant: int) -> void:
	var game = get_tree().root.get_node("Game")
	game.credits += montant
	game.staked = maxi(0, game.staked - montant)
	game.changed.emit()


func _ranger(p: Dictionary) -> void:
	var liste := positions()
	for i in liste.size():
		if int(liste[i].id) == int(p.id):
			liste[i] = p
			change.emit()
			return
	liste.push_front(p)
	donnees["positions"] = liste
	change.emit()


# --- Les calculs, pour l'affichage -------------------------------------------------------------

## Le dernier cours connu d'une valeur : [jour, cloture], ou [] sans cours.
static func dernier(i: Dictionary) -> Array:
	var c: Array = i.get("cours", [])
	return c[c.size() - 1] if not c.is_empty() else []


## La variation entre le dernier cours et celui de n séances plus tôt, en part (0,012 pour +1,2 %).
static func variation(i: Dictionary, n := 1) -> float:
	var c: Array = i.get("cours", [])
	if c.size() <= n:
		return 0.0
	return float(c[c.size() - 1][1]) / float(c[c.size() - 1 - n][1]) - 1.0


## Le mouvement de la valeur qui liquide une position, en part : −1,6 % pour un levier de 50.
static func seuil_liquidation(levier: int) -> float:
	return -(1.0 - LIQUIDATION) / float(levier)


## Le gain ou la perte d'une position ouverte, en crédits, d'après sa valeur au dernier cours.
static func resultat(p: Dictionary) -> int:
	return int(p.get("valeur", p.get("garantie", 0))) - int(p.get("garantie", 0))


## L'appel de marge : la valeur est passée sous la moitié de la garantie.
static func en_appel(p: Dictionary) -> bool:
	return p.get("issue") == null and p.get("entree") != null and p.get("valeur") != null \
		and float(p.valeur) < APPEL * float(p.garantie)


## Une position telle qu'on la dit : « CAC 40 à la hausse, levier 50 ».
static func intitule(p: Dictionary) -> String:
	var v: Dictionary = VALEURS.get(str(p.indice), {"nom": str(p.indice)})
	return "%s à la %s, levier %d" % [v.nom, "hausse" if int(p.sens) > 0 else "baisse", int(p.levier)]


static func phrase_encaissee(info: Dictionary) -> String:
	var p: Dictionary = info.position
	var rendu: int = info.rendu
	var garantie: int = info.garantie
	var fmt := func(n: int) -> String: return (Engine.get_main_loop() as SceneTree).root.get_node("Game").fmt(n)
	match str(p.get("issue", "")):
		"liquidee":
			if rendu > 0:
				return "Mme Vasseur : %s liquidée à la clôture. Il vous en revient %s crédits sur %s." % [intitule(p), fmt.call(rendu), fmt.call(garantie)]
			return "Mme Vasseur : %s liquidée à la clôture. Il ne reste rien des %s crédits engagés." % [intitule(p), fmt.call(garantie)]
		"annulee":
			return "Mme Vasseur : ordre annulé, %s crédits vous sont rendus." % fmt.call(rendu)
	if rendu >= garantie:
		return "Mme Vasseur : %s soldée. %s crédits vous reviennent, dont %s de bénéfice." % [intitule(p), fmt.call(rendu), fmt.call(rendu - garantie)]
	return "Mme Vasseur : %s soldée. %s crédits vous reviennent sur %s engagés." % [intitule(p), fmt.call(rendu), fmt.call(garantie)]


# --- Le calendrier des places ----------------------------------------------------------------

## Le décalage d'une place à l'instant t (secondes Unix), en heures : l'heure d'été d'Europe (dernier
## dimanche de mars au dernier dimanche d'octobre, à 1 h UTC) et d'Amérique (deuxième dimanche de mars
## au premier dimanche de novembre, à 2 h locales).
static func decalage(id: String, t: int) -> int:
	var v: Dictionary = VALEURS[id]
	var d := Time.get_datetime_dict_from_unix_time(t)
	match str(v.ete):
		"europe":
			var debut := _dimanche(d.year, 3, -1) + 3600
			var fin := _dimanche(d.year, 10, -1) + 3600
			return int(v.hiver) + (1 if t >= debut and t < fin else 0)
		"amerique":
			var debut := _dimanche(d.year, 3, 2) + 7 * 3600
			var fin := _dimanche(d.year, 11, 1) + 6 * 3600
			return int(v.hiver) + (1 if t >= debut and t < fin else 0)
	return int(v.hiver)


## Le n-ième dimanche d'un mois (−1 : le dernier), à minuit UTC, en secondes Unix.
static func _dimanche(an: int, mois: int, n: int) -> int:
	if n < 0:
		var fin := Time.get_unix_time_from_datetime_dict({"year": an + (1 if mois == 12 else 0), "month": 1 if mois == 12 else mois + 1, "day": 1}) - 86400
		var jd := Time.get_datetime_dict_from_unix_time(fin)
		return fin - int(jd.weekday) * 86400
	var debut := Time.get_unix_time_from_datetime_dict({"year": an, "month": mois, "day": 1})
	var j0 := int(Time.get_datetime_dict_from_unix_time(debut).weekday)
	return debut + ((7 - j0) % 7) * 86400 + (n - 1) * 7 * 86400


## L'instant (secondes Unix) d'une heure de la place, le jour de la place qui contient t.
static func heure_de_place(id: String, t: int, hm: Array) -> int:
	var dec := decalage(id, t)
	var jour := int(floor((t + dec * 3600) / 86400.0))
	var u: int = jour * 86400 + int(hm[0]) * 3600 + int(hm[1]) * 60 - dec * 3600
	# Le décalage du jour même (un changement d'heure dans la nuit).
	return u + (dec - decalage(id, u)) * 3600


## Les séances d'une place entre deux instants (secondes Unix) : [{quand, quoi}] pour l'ouverture et la clôture.
static func seances(id: String, de: int, a: int) -> Array:
	var v: Dictionary = VALEURS[id]
	var out := []
	var t := de - 86400
	while t <= a + 86400:
		var dec := decalage(id, t)
		var jour_semaine := (int(floor((t + dec * 3600) / 86400.0)) + 4) % 7
		if jour_semaine != 0 and jour_semaine != 6:
			for k in ["ouverture", "cloture"]:
				var u := heure_de_place(id, t, v[k])
				# L'or rouvre la veille au soir : son ouverture du lundi est le dimanche à 18 h.
				if k == "ouverture" and id == "or":
					u -= 86400
				if u >= de and u < a:
					out.append({"quand": u, "quoi": k})
		t += 86400
	out.sort_custom(func(x, y): return x.quand < y.quand)
	return out


## Les rendez-vous de la bourse pour l'agenda (docs/ACTIVITES.md, brique 1), entre deux instants en
## secondes locales, une fois la charge ouverte : la séance de Paris chaque jour ouvré, et la clôture
## des autres places où l'on a une position ou un ordre en cours. Au format de l'Agenda.
func rendez_vous(de: int, a: int) -> Array:
	if not ouverte():
		return []
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var suivies := {"cac40": true}
	for p in ouvertes():
		suivies[str(p.indice)] = true
	var out := []
	for id in ORDRE:
		if not suivies.has(id):
			continue
		var v: Dictionary = VALEURS[id]
		var ouvre := -1
		for s in seances(id, de - bias - 86400, a - bias):
			if s.quoi == "ouverture":
				ouvre = s.quand
				continue
			var cloture: int = s.quand + bias
			var rv := {"id": "bourse@%s/%d" % [id, s.quand], "activite": "bourse", "annonce": false,
				"lieu": "la charge de Mme Vasseur, rue du Clain"}
			if id == "cac40":
				var debut: int = (ouvre if ouvre >= 0 else s.quand) + bias
				rv.merge({"titre": "La séance de la Bourse de Paris", "quand": debut, "duree": cloture - debut,
					"detail": "Les ordres sur le CAC 40 s'exécutent à la clôture, à 17 h 35, comme les liquidations."})
			else:
				rv.merge({"titre": "Clôture %s (%s)" % [v.ville, v.nom], "quand": cloture, "duree": 900,
					"detail": "Vous y tenez une position : elle se règle sur ce cours, ou se liquide."})
			ouvre = -1
			if rv.quand + rv.duree > de and rv.quand < a:
				out.append(rv)
	out.sort_custom(func(x, y): return x.quand < y.quand)
	return out


# --- Les captures -----------------------------------------------------------------------------

func _essai_ouvrir(id: String, sens: int, levier: int, marge: int, total: int) -> Dictionary:
	var p := {"id": 100 + positions().size(), "indice": id, "sens": sens, "levier": levier, "marge": marge, "garantie": marge,
		"ordre_a": int(donnees.maintenant), "entree_jour": null, "entree": null, "solde_a": null, "issue": null,
		"rendu": null, "encaisse": false, "valeur": null, "execution": int(indice(id).get("prochaine", 0))}
	bilan()["engage"] = int(bilan().engage) + total
	_ranger(p)
	return {"ok": true, "position": p}


## Une cote et des positions pour les captures, sans réseau : les vraies clôtures de mi-octobre 2026.
func _mise_en_scene() -> void:
	var maintenant := int(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 19, "hour": 12, "minute": 40}))
	var series := {
		"cac40": [7738.2, 7802.9, 7871.5, 7944.1, 7990.6, 8035.9, 7964.5, 7835.3, 7897.2, 7834.1, 7865.1, 7769.2, 7729.7, 7803.3, 7832.9, 7827.6, 7873.1, 7934.7, 7956.7],
		"sp500": [7702.1, 7745.6, 7790.3, 7811.0, 7836.4, 7801.9, 7766.0, 7790.2, 7746.1, 7773.9, 7818.9, 7801.8, 7765.4, 7811.5, 7807.2, 7805.5, 7718.9, 7744.1, 7659.4],
		"nikkei": [66510.0, 67120.4, 67802.6, 68011.9, 67655.2, 68309.5, 68309.5, 68309.5, 68309.5, 69946.9, 70684.0, 70035.7, 69042.1, 69030.9, 67777.5, 67744.3, 64425.9, 64425.9, 65324.3],
		"or": [4012.4, 4035.8, 4061.0, 4088.3, 4102.6, 4120.9, 4098.2, 4111.5, 4126.0, 4133.4, 4140.7, 4140.7, 4157.0, 4216.3, 4190.6, 4177.3, 4107.9, 4170.1, 4181.1],
	}
	var jours := []
	var t := maintenant - 86400 * 3
	while jours.size() < 19:
		var w := int(Time.get_datetime_dict_from_unix_time(t).weekday)
		if w != 0 and w != 6:
			jours.push_front(Time.get_date_string_from_unix_time(t))
		t -= 86400
	var liste := []
	for id in ORDRE:
		var cours := []
		for k in jours.size():
			cours.append([jours[k], series[id][k]])
		var prochaine := heure_de_place(id, maintenant, VALEURS[id].cloture)
		if prochaine <= maintenant:
			prochaine = heure_de_place(id, maintenant + 86400, VALEURS[id].cloture)
		liste.append({"id": id, "nom": VALEURS[id].nom, "place": VALEURS[id].place, "prochaine": prochaine, "cours": cours})
	donnees = {"maintenant": maintenant, "indices": liste, "positions": [
		{"id": 3, "indice": "cac40", "sens": 1, "levier": 50, "marge": 2000, "garantie": 2000, "ordre_a": maintenant - 6 * 86400,
			"entree_jour": jours[13], "entree": 7803.3, "solde_a": null, "issue": null, "rendu": null, "encaisse": false,
			"valeur": 3810, "execution": null},
		{"id": 2, "indice": "nikkei", "sens": 1, "levier": 10, "marge": 1000, "garantie": 1000, "ordre_a": maintenant - 8 * 86400,
			"entree_jour": jours[13], "entree": 69030.9, "solde_a": null, "issue": null, "rendu": null, "encaisse": false,
			"valeur": 453, "execution": null},
		{"id": 1, "indice": "or", "sens": -1, "levier": 10, "marge": 500, "garantie": 500, "ordre_a": maintenant - 3600,
			"entree_jour": null, "entree": null, "solde_a": null, "issue": null, "rendu": null, "encaisse": false,
			"valeur": null, "execution": int(liste[3].prochaine)},
	]}
	etat = "ok"
