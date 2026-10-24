class_name SalleDuo
extends Node
## Une salle à deux d'une commune (socle 1.24, besoins B1 à B6 de Chauvigny) : on y joue à deux, la
## descente se paie et la prime ne se touche qu'une fois. Le serveur (la fonction casino d'Addict,
## supabase/functions/casino/smarves-salles.js) tient ce qu'un client ne doit pas décider seul :
## l'appariement, le salon et le nom secret de son canal, ce que coûte la descente, la prime (il rejoue les
## gestes de la partie avec le moteur du jeu), la plaque de la salle, les départs et la reprise.
##
## La commune la déclare dans son manifeste (structure « salle_duo », ses variantes), en pose une dans sa
## scène, et l'appelle :
##   var s := SalleDuo.new()
##   add_child(s)
##   s.apparie.connect(_sur_apparie)
##   s.rejoindre("chauvigny", "colaby", "lab1")
## SalleDuo fait passer Presences dans le salon de la partie dès l'appariement : les deux joueurs ne voient
## plus qu'eux, à 10 positions par seconde. Elle bat toutes les deux secondes ; un départ se voit chez
## l'autre en 6 s au plus (signal partenaire_parti, ou parti de Presences, tout de suite). L'argent passe
## par Argent : `entrer` retire la descente que dit le serveur, `sortir` ajoute la prime.
## Le mode d'emploi est dans docs/COMMUNE.md, « Les salles à deux ».

## Inscrit à l'attente d'une variante : personne encore.
signal attente(variante: String)
## Un partenaire est là : `vue` dit le salon, le rôle (A, le premier arrivé, tient la partie) et le
## partenaire ({nom, membre, paye, present, parti}).
signal apparie(vue: Dictionary)
## Chaque nouvelle vue du salon, à chaque battement.
signal vue_changee(vue: Dictionary)
## Les deux ont payé : la partie commence (ou reprend, avec vue.carnet, les gestes déjà joués).
signal partie(vue: Dictionary)
## Le partenaire ne bat plus depuis 6 s (une coupure ?) ; revenu ; parti pour de bon.
signal partenaire_absent(nom: String)
signal partenaire_revenu(nom: String)
signal partenaire_parti(nom: String)
## Une demande refusée ou perdue, en une phrase.
signal erreur(texte: String)

const BATTEMENT := 2.0

## "" (rien), "attente", "salon" (apparié), "partie" (les deux ont payé), "fini" (sortis), "ferme".
var etat := ""
var commune := ""
var salle := ""
var variante := ""
## La dernière vue du salon rendue par le serveur.
var vue := {}
## Le rôle de ce joueur dans le salon : "A" ou "B".
var role := ""
## Les gestes de la partie, que A envoie avec ses battements : un joueur qui revient les retrouve.
var carnet: Array = []
## Passer Presences dans le salon de la partie (vrai sans réglage).
var avec_presences := true
## Le faux serveur (SalleDuoEssai) et le joueur qu'on y fait jouer ({id, nom}) : sans compte ni réseau.
var essai: SalleDuoEssai
var joueur_essai := {}
## Poser l'argent dans la poche du joueur (Argent) ; faux, la commune s'en charge.
var avec_argent := true

var _attente := 0.0
var _en_cours := false
var _present := true
var _carnet_envoye := -1


## Les variantes d'une salle et leurs tarifs pour ce joueur : {ok, nom, variantes: {id: {nom, entree,
## prime, gagnee, reports}}, erreur}. `variantes` : celles du manifeste (le faux serveur s'en sert).
func fiche(c: String, s: String, variantes: Array = []) -> Dictionary:
	var r := await _appeler("salle.fiche", {"commune": c, "salle": s, "variantes": variantes})
	return {"ok": r.ok, "nom": r.corps.get("nom", ""), "variantes": r.corps.get("variantes", {}), "erreur": r.erreur}


## La plaque de la salle : [{noms: [A, B], variante, quand}], la plus récente en dernier.
func plaque(c: String, s: String) -> Array:
	var r := await _appeler("salle.plaque", {"commune": c, "salle": s})
	return r.corps.get("plaque", []) if r.ok else []


## Demande une partie de cette variante : on attend un partenaire (signal attente), ou on en trouve un
## (signal apparie). Revenir dans les deux minutes après une coupure rend le même salon.
func rejoindre(c: String, s: String, v: String) -> Dictionary:
	commune = c
	salle = s
	variante = v
	var r := await _appeler("salle.rejoindre", {"commune": c, "salle": s, "variante": v})
	if r.ok:
		_lire(r.corps)
	return r


## Paie sa descente : le serveur dit ce qu'elle coûte (0 si elle était reportée). {ok, cout, erreur}.
## Refusée si la poche n'y suffit pas.
func entrer() -> Dictionary:
	if not etat in ["salon", "partie", "fini"]:
		return {"ok": false, "cout": 0, "erreur": "Pas encore de partenaire."}
	var prix := int(vue.get("entree", 0))
	if avec_argent and not vue.get("moi", {}).get("paye", false) and _credits() < prix:
		return {"ok": false, "cout": 0, "erreur": "Il faut %d crédits pour descendre." % prix}
	var r := await _appeler("salle.entrer", {"salon": vue.get("salon", "")})
	if not r.ok:
		return {"ok": false, "cout": 0, "erreur": r.erreur}
	var cout := int(r.corps.get("cout", 0))
	if cout > 0 and avec_argent:
		_mouvement("%s:%s:descente" % [salle, variante], -cout)
	_lire(r.corps)
	return {"ok": true, "cout": cout, "erreur": ""}


## La sortie : le serveur rejoue les gestes (`pas`, le carnet de la partie, sans réglage celui de A) et paie
## la prime si ce joueur ne l'a jamais touchée. {ok, montant, deja, erreur}.
func sortir(pas: Array = []) -> Dictionary:
	if not etat in ["partie", "fini"]:
		return {"ok": false, "montant": 0, "deja": false, "erreur": "La partie n'a pas commencé."}
	var r := await _appeler("salle.prime", {"salon": vue.get("salon", ""), "carnet": pas if not pas.is_empty() else carnet})
	if not r.ok:
		return {"ok": false, "montant": 0, "deja": false, "erreur": r.erreur}
	var montant := int(r.corps.get("montant", 0))
	if montant > 0 and avec_argent:
		_mouvement("%s:%s:prime" % [salle, variante], montant)
	_lire(r.corps)
	return {"ok": true, "montant": montant, "deja": bool(r.corps.get("deja", false)), "erreur": ""}


## Quitte l'attente ou le salon. Le partenaire le voit tout de suite et garde sa descente pour sa prochaine
## partie de la même variante (un report) ; celui qui part perd la sienne.
func quitter() -> void:
	if etat == "":
		return
	_fin()
	await _appeler("salle.quitter", {})


## Le joueur d'en face, tel que Presences le montre (son membre public) : null s'il n'est pas à portée.
func silhouette() -> Variant:
	var p := _presences()
	var m := str(vue.get("partenaire", {}).get("membre", ""))
	if p == null or m == "" or not p.presents.has(m):
		return null
	return p.presents[m].get("noeud")


func _process(delta: float) -> void:
	if etat == "" or etat == "ferme" or _en_cours:
		return
	_attente += delta
	if _attente < BATTEMENT:
		return
	_attente = 0.0
	if etat == "attente":
		var r := await _appeler("salle.rejoindre", {"commune": commune, "salle": salle, "variante": variante})
		if r.ok:
			_lire(r.corps)
		return
	var args := {"salon": vue.get("salon", "")}
	if role == "A" and carnet.size() != _carnet_envoye:
		args.carnet = carnet
		_carnet_envoye = carnet.size()
	var r := await _appeler("salle.battre", args)
	if r.ok:
		_lire(r.corps)


## La scène se ferme en pleine partie : on s'en va proprement, sans attendre la réponse.
func _exit_tree() -> void:
	if etat == "" or etat == "ferme":
		return
	_fin()
	if essai != null:
		essai.appeler(joueur_essai, "salle.quitter", {})
	elif get_tree().root.has_node("Compte"):
		get_tree().root.get_node("Compte").casino("salle.quitter", {})


func _lire(c: Dictionary) -> void:
	if c.get("ferme", false):
		_fin()
		etat = "ferme"
		return
	if c.get("attente", false):
		if etat != "attente":
			etat = "attente"
			attente.emit(variante)
		vue = c
		return
	if not c.has("salon"):
		return
	var avant := etat
	var etait_present := _present
	var etait_parti: bool = vue.get("partenaire", {}).get("parti", false)
	vue = c
	role = str(c.role)
	if c.get("carnet") is Array and role == "B":
		carnet = c.carnet
	if avant in ["", "attente"]:
		if c.get("carnet") is Array and role == "A":
			carnet = c.carnet
			_carnet_envoye = carnet.size()
		etat = "salon"
		_entrer_presences(str(c.canal))
		apparie.emit(c)
	if c.get("fini", false):
		etat = "fini"
	elif c.get("partie", false):
		if etat != "partie":
			etat = "partie"
			partie.emit(c)
	elif etat in ["partie", "fini"]:
		etat = "salon"
	vue_changee.emit(c)
	var o: Dictionary = c.get("partenaire", {})
	_present = bool(o.get("present", true))
	if o.get("parti", false):
		if not etait_parti:
			partenaire_parti.emit(str(o.get("nom", "")))
	elif etait_present and not _present:
		partenaire_absent.emit(str(o.get("nom", "")))
	elif not etait_present and _present:
		partenaire_revenu.emit(str(o.get("nom", "")))


func _fin() -> void:
	etat = ""
	role = ""
	_present = true
	var p := _presences()
	if p != null and avec_presences and vue.has("canal") and p.salon_id == str(vue.canal):
		p.salon("")


func _entrer_presences(canal: String) -> void:
	var p := _presences()
	if p != null and avec_presences:
		p.salon(canal)


## {ok, corps, erreur} : le vrai serveur par Compte, ou le faux.
func _appeler(action: String, args: Dictionary) -> Dictionary:
	_en_cours = true
	var r: Dictionary
	if essai != null:
		r = essai.appeler(joueur_essai, action, args)
	else:
		# Les autoloads se cherchent à l'appel : une classe se compile aussi hors du jeu (tests, outils).
		var compte: Node = get_tree().root.get_node_or_null("Compte") if is_inside_tree() else null
		r = await compte.casino(action, args) if compte != null else {"code": 0, "corps": null}
	_en_cours = false
	var corps = r.get("corps")
	if int(r.get("code", 0)) == 200 and corps is Dictionary:
		return {"ok": true, "corps": corps, "erreur": ""}
	var e := "hors ligne"
	if corps is Dictionary and corps.has("error"):
		e = str(corps.error)
	erreur.emit(e)
	return {"ok": false, "corps": {}, "erreur": e}


func _presences() -> Node:
	return get_tree().root.get_node_or_null("Presences") if is_inside_tree() else null


func _credits() -> int:
	var g: Node = get_tree().root.get_node_or_null("Game") if is_inside_tree() else null
	return int(g.credits) if g != null else 0


func _mouvement(motif: String, montant: int) -> void:
	var a: Node = get_tree().root.get_node_or_null("Argent") if is_inside_tree() else null
	if a != null:
		a.mouvement(commune, motif, montant)
