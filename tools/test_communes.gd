extends SceneTree
## Vérifie le socle des communes sans affichage : godot --headless --path . -s tools/test_communes.gd
## Le manifeste de Smarves redonne exactement les lieux et les salles d'avant ; une commune d'essai
## (tools/commune_essai/), emballée ici en pack .pck, se greffe et s'inscrit ; un pack qui voudrait
## écrire hors de son dossier est refusé, de même qu'un dossier dont le manifeste ment sur son id.

const ESSAI := "res://tools/commune_essai/"
const TMP := "user://test_communes/"

## Les lieux et les salles de Smarves. Depuis le 17 octobre, seuls les lieux qui ont une salle à eux gardent un jeu.
const PLACES_AVANT := [
	["cafe", 0, "Josiane"], ["casino", 0, "Monsieur Armand"], ["banque", 0, "M. Brunet"],
	["rabelais", 8000, "M. Gaudin"], ["stade", 3000, "Le président Chauvin"], ["moulin", 120000, "Le meunier"],
	["bourse", 7000, "Mme Vasseur"], ["gymnase", 10000, "M. Lacombe"],
]
const LOCKS_AVANT := [["ambassadeurs", 500], ["salon", 5000], ["loggia", 2000], ["musique", 10000], ["fetes", 25000], ["particuliers", 50000], ["cercle", 1000]]

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var communes: Node = root.get_node("Communes")
	var smarves: Commune = communes.origine()
	check(smarves != null and smarves.valide(), "Smarves est inscrite depuis son manifeste %s" % ("" if smarves == null else " ".join(smarves.erreurs)))
	check(communes.ordre == ["smarves"], "aucune greffe n'est chargée pendant un test")
	_smarves(smarves)
	DirAccess.make_dir_recursive_absolute(TMP)
	_pack_essai(communes)
	_pack_intrus(communes)
	_dossier_menteur(communes)
	_carte(communes)
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _smarves(c: Commune) -> void:
	# Chargés ici et non en preload : un script -s se compile avant que les autoloads existent.
	var places: Array = load("res://scripts/main.gd").PLACES
	check(places.size() == PLACES_AVANT.size(), "%d lieux à Smarves" % places.size())
	for i in mini(places.size(), PLACES_AVANT.size()):
		var p: Dictionary = places[i]
		var a: Array = PLACES_AVANT[i]
		check(p.id == a[0] and p.seuil == a[1] and typeof(p.seuil) == TYPE_INT and p.host == a[2] and p.name != "" and p.game != "",
			"lieu %s : seuil %d, %s" % [a[0], a[1], a[2]])
	check(places[3].get("accord", "") == "e" and not places[5].has("accord") and not places[0].has("accord"), "les accords (ouverte) suivent")
	# On ne joue plus dehors : chaque lieu de jeu a sa salle.
	for id in ["cafe", "casino", "rabelais", "moulin", "stade", "bourse", "gymnase"]:
		check(c.interieur(id) != "" and ResourceLoader.exists(c.interieur(id)), "le jeu de %s se joue dans sa salle" % id)
	var locks: Array = load("res://scripts/casino_interior.gd").LOCKS
	check(locks.size() == LOCKS_AVANT.size(), "%d salles fermées au casino" % locks.size())
	for i in mini(locks.size(), LOCKS_AVANT.size()):
		check(locks[i].id == LOCKS_AVANT[i][0] and locks[i].seuil == LOCKS_AVANT[i][1], "salle %s à %d" % LOCKS_AVANT[i])
	check(locks[4].get("on", "won") == "staked" and locks[0].get("on", "won") == "won", "la Salle des fêtes s'ouvre sur le total misé")
	check(c.preteur() == "smarves" and c.banque().banquier == "M. Brunet", "le prêteur de Smarves est M. Brunet, clé « smarves »")
	for k in c.data.interieurs:
		check(ResourceLoader.exists(c.interieur(k)), "l'intérieur %s existe (%s)" % [k, c.interieur(k)])
	for s in c.data.biens.vendeurs:
		check(root.get_node("Biens").SELLERS.has(s), "le vendeur %s est au catalogue de Biens" % s)
	var absents := []
	for n in c.data.personnages.nommes:
		if not Cast.NAMED.has(n):
			absents.append(n)
	check(absents.is_empty(), "les personnages nommés sont dans Cast.NAMED %s" % str(absents))


func _pack(path: String, fichiers: Dictionary) -> void:
	var pk := PCKPacker.new()
	pk.pck_start(path)
	for cible in fichiers:
		pk.add_file(cible, fichiers[cible])
	pk.flush()


func _pack_essai(communes: Node) -> void:
	var pck := TMP + "essai.pck"
	_pack(pck, {"res://communes/essai/commune.json": ESSAI + "commune.json", "res://communes/essai/commune.tscn": ESSAI + "commune.tscn"})
	var liste = communes.lister_pack(pck)
	check(liste != null and liste.size() == 2, "le pack d'essai se lit : %s" % str(liste))
	var vu := []
	communes.inscrite.connect(func(id): vu.append(id))
	check(communes.charger_pack(pck) == "essai", "le pack d'essai se greffe %s" % str(communes.refus))
	var c: Commune = communes.commune("essai")
	check(c != null and c.nom == "La commune d'essai" and c.preteur() == "essai", "son manifeste est lu : nom, prêteur")
	check(vu == ["essai"], "le signal inscrite annonce la greffe")
	check(c != null and c.lieux()[0].seuil == 40000, "ses lieux ont leur seuil")
	check(c != null and not c.montee and not ResourceLoader.exists("res://communes/essai/commune.tscn"), "le pack n'est pas monté tant qu'on n'y entre pas")
	check(communes.ouvrir("essai") and c.montee, "on y entre : le pack se monte à la demande")
	var scene: PackedScene = load("res://communes/essai/commune.tscn")
	var n: Node = scene.instantiate() if scene else null
	check(n != null and n.get_node("Panneau") is Label3D, "sa scène se charge depuis le pack")
	if n:
		n.free()
	check(communes.charger_pack(pck) == "", "le même pack n'est pas greffé deux fois")


func _pack_intrus(communes: Node) -> void:
	var avant := FileAccess.get_file_as_string("res://scripts/game_state.gd")
	var pck := TMP + "intrus.pck"
	FileAccess.open(TMP + "faux.gd", FileAccess.WRITE).store_string("extends Node\n")
	FileAccess.open(TMP + "intrus.json", FileAccess.WRITE).store_string(FileAccess.get_file_as_string(ESSAI + "commune.json").replace("\"essai\"", "\"intrus\""))
	_pack(pck, {"res://communes/intrus/commune.json": TMP + "intrus.json", "res://scripts/game_state.gd": TMP + "faux.gd"})
	var nb: int = communes.refus.size()
	check(communes.charger_pack(pck) == "" and communes.commune("intrus") == null, "un pack qui écrit hors de son dossier est refusé")
	check(communes.refus.size() == nb + 1 and "hors de" in communes.refus[-1][1], "la raison du refus est gardée")
	check(FileAccess.get_file_as_string("res://scripts/game_state.gd") == avant, "le script du jeu est intact")
	_pack(TMP + "natif.pck", {"res://communes/natif/commune.json": TMP + "intrus.json", "res://communes/natif/natif.gdextension": TMP + "faux.gd"})
	check(communes.charger_pack(TMP + "natif.pck") == "" and "natif" in communes.refus[-1][1], "un pack avec du code natif (GDExtension) est refusé")
	FileAccess.open(TMP + "abime.pck", FileAccess.WRITE).store_string("GDPC n'importe quoi")
	check(communes.charger_pack(TMP + "abime.pck") == "", "un pack abîmé est refusé")


func _dossier_menteur(communes: Node) -> void:
	var dir := TMP + "menteur/"
	DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(dir + "commune.json", FileAccess.WRITE).store_string(FileAccess.get_file_as_string(ESSAI + "commune.json").replace("\"essai\"", "\"autre\""))
	check(communes.charger_dossier(dir) == "", "un dossier dont le manifeste ment sur son id est refusé")
	var bon := TMP + "dossier/"
	DirAccess.make_dir_recursive_absolute(bon)
	var json := FileAccess.get_file_as_string(ESSAI + "commune.json").replace("\"essai\"", "\"dossier\"")
	FileAccess.open(bon + "commune.json", FileAccess.WRITE).store_string(json)
	check(communes.charger_dossier(bon) == "" and "déjà développée" in communes.refus[-1][1], "une deuxième commune au même code INSEE est refusée")
	FileAccess.open(bon + "commune.json", FileAccess.WRITE).store_string(json.replace("86113", "86100"))
	check(communes.charger_dossier(bon) == "dossier", "une commune en dossier sous user:// s'inscrit %s" % str(communes.refus.slice(-1)))
	var faux := TMP + "faux_insee/"
	DirAccess.make_dir_recursive_absolute(faux)
	FileAccess.open(faux + "commune.json", FileAccess.WRITE).store_string(json.replace("\"dossier\"", "\"faux_insee\"").replace("86113", "79191"))
	check(communes.charger_dossier(faux) == "" and "INSEE" in communes.refus[-1][1], "un code INSEE hors de la Vienne est refusé")


## La carte : toutes les communes réelles à leur place, cliquables seulement une fois développées.
func _carte(communes: Node) -> void:
	var carte: Array = communes.carte()
	check(carte.size() == 265, "la carte compte les %d communes actuelles de la Vienne" % carte.size())
	var par := {}
	for e in carte:
		par[e.insee] = e
	var sm: Dictionary = par.get("86263", {})
	check(sm.get("nom") == "Smarves" and sm.cliquable and sm.id == "smarves", "Smarves (86263) est cliquable")
	check(sm.centre.distance_to(Vector2(0.357, 46.511)) < 0.02 and sm.contour.size() >= 1, "Smarves est à sa place, au sud de Poitiers (%s)" % str(sm.centre))
	check(not par["86194"].cliquable and par["86194"].nom == "Poitiers", "Poitiers est sur la carte, pas cliquable")
	check(par["86113"].cliquable and par["86113"].id == "essai", "la commune greffée devient cliquable à son code INSEE")
	var n := 0
	for e in carte:
		if e.cliquable:
			n += 1
	check(n == communes.communes.size(), "seules les communes développées sont cliquables (%d)" % n)
