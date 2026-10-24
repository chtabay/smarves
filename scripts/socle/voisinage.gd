extends Node
## Le voisinage (autoload « Voisinage »), étape 2 du multi (docs/SUITE.md, section 4) : ce que les
## autres joueurs laissent dans le village sans y être en même temps. Le panneau de la mairie (le
## classement des placements, les petites annonces, les rendez-vous, qui est passé), les noms au-dessus
## des maisons qu'ils possèdent, leurs mots dans le livre d'or, et les passages dans les lieux.
##
## Tout se lit en un appel (public.smarves_village), à l'arrivée sur la place et à l'ouverture du
## panneau, au plus une fois par minute ; la lecture marche sans compte. Écrire (annonce, mot, passage,
## vitrine) demande d'être connecté (autoload Compte). Hors ligne, le village reste celui d'un joueur seul.

## Une lecture est arrivée (ou a échoué : voir etat).
signal lu

## Les rendez-vous des activités à plusieurs, à heure fixe (choix de Guillaume, 18 octobre 2026) :
## jour de la semaine (0 : dimanche), heure, minute, quoi, où. La table des Ambassadeurs est partagée
## tous les soirs entre les joueurs connectés (scripts/jeux/poker_multi.gd) : ces heures-là, on est sûr
## d'y trouver du monde. Passelourdin reste la partie clandestine du dernier seuil.
const RENDEZ_VOUS := [
	[5, 13, 30, "La partie de poker du vendredi", "la salle des Ambassadeurs du casino"],
	[0, 11, 0, "La partie de poker du dimanche", "la salle des Ambassadeurs du casino"],
]
const FRAICHEUR := 60.0

## « » tant que rien n'est lu, puis « lecture », « ok » ou « hors_ligne ».
var etat := ""
## La dernière lecture : {moi, classement, annonces, maisons, passages, mots}.
var donnees := {}
var _lu_a := -1000.0
var _vitrine_envoyee := ""
var _essai := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_essai = "--voisinage-essai" in OS.get_cmdline_user_args()
	if _essai:
		_mise_en_scene()
		return
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	# La vitrine part dès que la partie est au compte ; la lecture reprend avec le jeton.
	Compte.change.connect(func():
		if Compte.etat == "a_jour":
			envoyer_vitrine()
			if donnees.get("moi") == null:
				lire(true))


## Relit le voisinage s'il date de plus d'une minute (ou toujours, si forcer).
func lire(forcer := false) -> void:
	if _essai or etat == "lecture" or get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	if not forcer and Time.get_ticks_msec() / 1000.0 - _lu_a < FRAICHEUR and etat == "ok":
		return
	etat = "lecture"
	var r: Dictionary = await Compte.appeler("smarves_village", {})
	_lu_a = Time.get_ticks_msec() / 1000.0
	if r.code == 200 and r.corps is Dictionary:
		donnees = r.corps
		etat = "ok"
	else:
		etat = "hors_ligne"
	lu.emit()


## Le joueur entre dans un lieu : son nom y reste vingt-quatre heures pour les autres.
func passer(lieu: String) -> void:
	if Compte.connecte() and not _essai:
		Compte.appeler("smarves_passer", {"p_lieu": lieu})


## Ce que le joueur montre de sa partie : le total gagné, la dette, ses logements. Envoyée quand elle a changé.
func envoyer_vitrine() -> void:
	if not Compte.connecte() or _essai:
		return
	var corps := vitrine()
	var texte := JSON.stringify(corps)
	if texte == _vitrine_envoyee:
		return
	var r: Dictionary = await Compte.appeler("smarves_vitrine_ecrire", corps)
	if r.code == 200 and r.corps is Dictionary and r.corps.get("ok", false):
		_vitrine_envoyee = texte


static func vitrine() -> Dictionary:
	var logements := []
	for id in Biens.logements:
		var l: Dictionary = Biens.logements[id]
		logements.append({"lot": str(Biens.item(id).get("lot", id)), "habite": bool(l.get("habite", false)),
			"meubles": (l.get("meubles", {}) as Dictionary).size()})
	return {"p_gagne": Game.won, "p_dette": Game.debt, "p_logements": logements}


## {ok, message} : une petite annonce au panneau de la mairie.
func annoncer(texte: String) -> Dictionary:
	var r: Dictionary = await Compte.appeler("smarves_annoncer", {"p_texte": texte})
	var ok: bool = r.code == 200 and r.corps is Dictionary and r.corps.get("ok", false)
	if ok:
		lire(true)
	return {"ok": ok, "message": "Annonce affichée." if ok else _raison(r, {"jour": "Une annonce par jour : la vôtre est déjà au panneau.",
		"texte": "Une ligne de 120 caractères au plus, sans chevrons."})}


## {ok, message} : un mot dans le livre d'or d'un autre joueur, à la porte d'un logement qu'il possède.
func laisser_mot(pour: String, lot: String, texte: String) -> Dictionary:
	var r: Dictionary = await Compte.appeler("smarves_mot_laisser", {"p_pour": pour, "p_lot": lot, "p_texte": texte})
	var ok: bool = r.code == 200 and r.corps is Dictionary and r.corps.get("ok", false)
	return {"ok": ok, "message": "Votre mot est glissé sous la porte." if ok else _raison(r, {"heure": "Trois mots par heure : la boîte aux lettres déborde.",
		"texte": "Un mot de 200 caractères au plus, sans chevrons.", "porte": "Ce joueur n'habite plus ici."})}


func _raison(r: Dictionary, raisons: Dictionary) -> String:
	if r.code == 0:
		return "Hors ligne : rien n'est parti."
	if r.corps is Dictionary and r.corps.get("erreur", "") == "jeton":
		return "La connexion a expiré : reconnectez-vous dans les réglages."
	return raisons.get(str(r.corps.get("raison", "")) if r.corps is Dictionary else "", "Le panneau n'a pas pris votre texte.")


## Les autres joueurs qui possèdent ce lot : [{id, nom, habite, meubles}], le plus récent d'abord.
func voisins(lot: String) -> Array:
	var moi = donnees.get("moi")
	return (donnees.get("maisons", {}).get(lot, []) as Array).filter(func(g): return g.get("id") != moi)


func mots() -> Array:
	return donnees.get("mots", [])


func classement() -> Array:
	return donnees.get("classement", [])


func annonces() -> Array:
	return donnees.get("annonces", [])


## {lieu: [noms]}, sans le joueur lui-même.
func passages() -> Dictionary:
	return donnees.get("passages", {})


## Les prochains rendez-vous, du plus proche au plus lointain : [{quoi, ou, quand (secondes Unix, heure locale)}].
static func prochains_rendez_vous(maintenant := -1) -> Array:
	var t := maintenant if maintenant >= 0 else int(Time.get_unix_time_from_system()) + _decalage()
	var jour := int(floor(t / 86400.0))
	var semaine := (jour + 4) % 7  # le 1er janvier 1970 était un jeudi
	var out := []
	for rv in RENDEZ_VOUS:
		var dans := (int(rv[0]) - semaine + 7) % 7
		var quand: int = (jour + dans) * 86400 + int(rv[1]) * 3600 + int(rv[2]) * 60
		if quand < t:
			quand += 7 * 86400
		out.append({"quoi": rv[3], "ou": rv[4], "quand": quand})
	out.sort_custom(func(a, b): return a.quand < b.quand)
	return out


static func _decalage() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## Les captures montrent un village peuplé, sans réseau.
func _mise_en_scene() -> void:
	var maintenant := int(Time.get_unix_time_from_system())
	donnees = {"moi": "essai",
		"classement": [{"nom": "Paulette", "gagne": 412300}, {"nom": "Guillaume", "gagne": 96200}, {"nom": "Bastien", "gagne": 40150},
			{"nom": "Maëlle", "gagne": 12800}, {"nom": "Rodolphe", "gagne": 3100}],
		"annonces": [{"nom": "Paulette", "texte": "Échange deux fauteuils crapaud contre un tuyau sur la roulette. Sérieux uniquement.", "quand": maintenant - 3 * 3600},
			{"nom": "Bastien", "texte": "Qui a vu la clef de la cabane du gardien ? Je paie la tournée.", "quand": maintenant - 26 * 3600},
			{"nom": "Maëlle", "texte": "Cherche colocataire pour la chambre au-dessus du café, joueur discret.", "quand": maintenant - 50 * 3600}],
		"maisons": {"maison_place": [{"id": "p", "nom": "Paulette", "habite": true, "meubles": 9}, {"id": "b", "nom": "Bastien", "habite": false, "meubles": 2}],
			"chambre_cafe": [{"id": "m", "nom": "Maëlle", "habite": true, "meubles": 3}]},
		"passages": {"cafe": ["Paulette", "Bastien"], "casino": ["Paulette"], "bois": ["Maëlle"]},
		"mots": [{"nom": "Paulette", "lot": "maison_place", "texte": "Jolie maison ! Les volets mériteraient un coup de peinture.", "quand": maintenant - 5400}]}
	etat = "ok"
