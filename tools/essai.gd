extends RefCounted
## La commune d'essai greffée pour les essais (tools/commune_essai) : son terrain fait un deuxième club au
## championnat, qui n'en compte que les inscrits. À appeler avant Football.actualiser() :
## load("res://tools/essai.gd").greffer(root). Rend l'id de la commune (« essai »), ou « » si la greffe échoue.

const ESSAI := "res://tools/commune_essai/"


static func greffer(root: Node, dossier := "user://essai_commune/") -> String:
	var communes: Node = root.get_node("Communes")
	if communes.commune("essai") != null:
		return "essai"
	DirAccess.make_dir_recursive_absolute(dossier)
	var pck := dossier.path_join("essai.pck")
	var pk := PCKPacker.new()
	pk.pck_start(pck)
	pk.add_file("res://communes/essai/commune.json", ESSAI + "commune.json")
	pk.add_file("res://communes/essai/commune.tscn", ESSAI + "commune.tscn")
	pk.flush()
	return communes.charger_pack(pck)


## Six communes de plus au catalogue, chacune avec un terrain : avec Smarves et la commune d'essai, une Division 1
## à huit clubs, pour les essais qui veulent une journée à quatre matchs. À appeler avant Football.actualiser().
static func completer(root: Node, inseeS := ["86133", "86290", "86015", "86009", "86062", "86100"]) -> void:
	var communes: Node = root.get_node("Communes")
	var entrees := []
	for i in inseeS.size():
		var c := Vienne.commune(inseeS[i])
		entrees.append({"insee": inseeS[i], "id": "c%d" % i, "nom": c.nom, "version": "0.1.0", "paquet": "https://exemple.fr/c%d.pck" % i,
			"taille": 1000, "sha256": "0".repeat(64), "structures": [{"type": "terrain_foot", "id": "stade", "nom": "Le stade", "club": "Le club de %s" % c.nom}]})
	communes.catalogue = Portail.entrees(JSON.stringify({"format": 1, "communes": entrees}))
	communes.catalogue_lu.emit()
