class_name ChargeCommune
extends "res://scripts/village/charge.gd"
## La charge d'agent de change d'une commune, prêtée par le socle : la structure « charge » du manifeste
## (socle 1.27, docs/COMMUNE.md, « La charge d'agent de change »). La commune nomme son agent, ses paroles et
## son enseigne ; le socle bâtit la charge de Mme Vasseur (le tableau de la cote, les horloges, le
## téléscripteur, le guichet) et y tient la même bourse : les mêmes cours, relevés au serveur, les mêmes
## positions au compte Pyramides, le même bilan (autoload Bourse, docs/BOURSE.md). Une position prise ici
## se lit et se solde aussi chez Mme Vasseur, et inversement. La commune ouvre sa charge depuis sa scène par
## ChargeCommune.ouvrir("<commune>", "<id de la structure>") ; le lieu du manifeste de même id lui donne
## son seuil.
## Capture : godot --path . res://scenes/charge.tscn -- --commune=<id> --charge=<id> --capture=sortie.png
## [--bourse-essai] [--open=cote] [--ordre=cac40]

const REPLIQUES := ["« Ici, on ne joue pas : on prend position. »",
	"« Je vous exécute à la clôture. Personne ne connaît son prix d'avance, pas même moi. »",
	"« Au levier 100, un pour cent fait toute la différence. Dans un sens ou dans l'autre. »",
	"« Un appel de marge, ce n'est pas une menace. C'est une politesse. »"]

## Ce que la prochaine charge doit ouvrir (posé par ouvrir(), lu au _ready).
static var _prochaine: Array = []

var commune := ""
var structure: Dictionary = {}


## Ouvre la charge « id » de la commune. Rend false sans rien faire si la structure n'existe pas, ou si le
## lieu du manifeste qui porte le même id n'est pas encore ouvert (son seuil de gagné au jeu).
static func ouvrir(id_commune: String, id: String) -> bool:
	if not ouverte(id_commune, id):
		return false
	_prochaine = [id_commune, id]
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Chargement.lieu("res://scenes/charge.tscn")
	return true


## La charge existe et son seuil est atteint (sans lieu du même id dans le manifeste, elle est ouverte).
static func ouverte(id_commune: String, id: String) -> bool:
	if _entree(id_commune, id).is_empty():
		return false
	return Game.won >= seuil(id_commune, id)


## Le seuil de gagné au jeu qui ouvre la charge : celui du lieu de même id, sinon 0.
static func seuil(id_commune: String, id: String) -> int:
	var c: Commune = Communes.commune(id_commune)
	if c == null:
		return 0
	for l in c.lieux():
		if str(l.get("id", "")) == id:
			return int(l.get("seuil", 0))
	return 0


static func _entree(id_commune: String, id: String) -> Dictionary:
	for e in Registre.de_commune(id_commune):
		if e.type == "charge" and e.id == id:
			return e
	return {}


func _ready() -> void:
	if _prochaine.size() == 2:
		commune = _prochaine[0]
		structure = _entree(_prochaine[0], _prochaine[1])
		_prochaine = []
	var id := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--commune="):
			commune = arg.trim_prefix("--commune=")
		elif arg.begins_with("--charge="):
			id = arg.trim_prefix("--charge=")
	if id != "":
		# En capture, une commune en clair sous communes/ (le SDK, un clone) se greffe d'elle-même.
		if Communes.commune(commune) == null and FileAccess.file_exists("res://communes/%s/commune.json" % commune):
			Communes.charger_dossier("res://communes/" + commune)
		structure = _entree(commune, id)
	var champs: Dictionary = structure.get("champs", {})
	hote = Bourse.agent_de(structure)
	nom = str(structure.get("nom", "La charge d'agent de change"))
	var lignes: Array = champs.get("repliques", [])
	paroles = lignes if not lignes.is_empty() else REPLIQUES
	enseigne = str(champs.get("enseigne", "%s & Cie" % hote))
	if not structure.is_empty():
		Bourse.passer_chez(hote, Bourse.lieu_de(structure))
	super()
	# L'enseigne de la charge, en lettres d'or sur le devant du guichet.
	_label3d(enseigne.to_upper(), Vector3(KX, 0.78, -D / 2.0 + 2.46), 40, Color(0.95, 0.82, 0.5)).shaded = false


## Un habitant tiré de la graine de la structure : le même agent d'une partie à l'autre.
func _visage(c: Node3D) -> void:
	c.randomize_look(int(structure.get("champs", {}).get("graine", hash(hote))))


## La porte ramène dans la commune, devant la porte de la charge (lot, sinon l'id de la structure).
func _sortir() -> void:
	Game.return_point = str(structure.get("lot", "")) if str(structure.get("lot", "")) != "" else str(structure.get("id", ""))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var c: Commune = Communes.commune(commune)
	Chargement.changer(str(c.data.scene) if c else "res://scenes/main.tscn")
