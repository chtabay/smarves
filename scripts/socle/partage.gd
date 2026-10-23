class_name Partage
extends RefCounted
## La petite table d'une commune, partagée entre tous les joueurs (socle 1.21, retour de l'auteur de
## Chauvigny) : une plaque des sorties, un livre d'or, un record du lieu. Chaque clé d'une commune tient
## une valeur JSON de 4 Ko au plus ; « ajouter » la tient en liste, les 50 dernières entrées, chacune signée
## du nom du joueur et datée par le serveur. Le serveur est la fonction casino d'Addict
## (supabase/functions/casino/smarves-communes.js) : il faut un compte connecté pour lire comme pour écrire.
##
## Chaque appel rend {ok, valeur, erreur} : ok faux sans compte, hors ligne ou sur un refus, avec la raison
## en une phrase dans erreur. Une commune garde alors ce qu'elle a (sa plaque locale) au lieu de bloquer.
## Le mode d'emploi est dans docs/COMMUNE.md, « La table partagée ».

const OCTETS := 4096
const LISTE := 50
const _ID := "^[a-z_][a-z0-9_]{0,47}$"
const _CLE := "^[a-z0-9_.-]{1,48}$"


## La valeur d'une clé (null si personne ne l'a encore écrite).
static func lire(commune: String, cle: String) -> Dictionary:
	return await _appel("commune.lire", commune, cle)


## Remplace la valeur d'une clé.
static func ecrire(commune: String, cle: String, valeur) -> Dictionary:
	return await _appel("commune.ecrire", commune, cle, valeur)


## Ajoute une entrée à la liste d'une clé : la liste rendue est [{de, quand, valeur}], la plus récente en
## dernier.
static func ajouter(commune: String, cle: String, valeur) -> Dictionary:
	return await _appel("commune.ajouter", commune, cle, valeur)


## Ce qui ne va pas dans une demande, avant de la poser (« » si elle passe) : les mêmes règles que le serveur.
static func refus(commune: String, cle: String, valeur = null) -> String:
	if RegEx.create_from_string(_ID).search(commune) == null:
		return "commune « %s » : l'identifiant du manifeste (minuscules, chiffres, « _ »)" % commune
	if RegEx.create_from_string(_CLE).search(cle) == null:
		return "clé « %s » : 1 à 48 caractères parmi a-z, 0-9, « _ », « . », « - »" % cle
	if JSON.stringify(valeur).to_utf8_buffer().size() > OCTETS:
		return "valeur trop lourde : %d octets au plus" % OCTETS
	return ""


static func _appel(action: String, commune: String, cle: String, valeur = null) -> Dictionary:
	var faute := refus(commune, cle, valeur)
	if faute != "":
		return {"ok": false, "valeur": null, "erreur": faute}
	var args := {"commune": commune, "cle": cle}
	if action != "commune.lire":
		args["valeur"] = valeur
	# L'autoload se cherche à l'appel : une classe se compile aussi hors du jeu (tests, outils).
	var compte: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Compte")
	if compte == null:
		return {"ok": false, "valeur": null, "erreur": "pas de compte dans ce programme"}
	var r: Dictionary = await compte.casino(action, args)
	return reponse(r)


## La réponse du serveur ({code, corps}) dans la forme rendue aux communes.
static func reponse(r: Dictionary) -> Dictionary:
	var corps = r.get("corps")
	if int(r.get("code", 0)) == 200 and typeof(corps) == TYPE_DICTIONARY:
		return {"ok": true, "valeur": corps.get("valeur"), "erreur": ""}
	var e := "hors ligne"
	if typeof(corps) == TYPE_DICTIONARY and corps.has("error"):
		e = str(corps.error)
	return {"ok": false, "valeur": null, "erreur": e}
