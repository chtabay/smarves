extends SceneTree
## Vérifie les structures et leur registre sans affichage : godot --headless --path . -s tools/test_structures.gd
## Le vocabulaire (Structures) refuse ce qu'un paquet ne doit pas déclarer ; les manifestes sans
## structures restent valides ; Smarves n'inscrit que son stade ; la commune d'essai (tools/commune_essai/), emballée en pack, inscrit sa
## halte et son stade au registre ; une commune seulement publiée au catalogue y paraît aussi, non
## installée ; la gare mène aux autres gares, la plus proche d'abord.

const ESSAI := "res://tools/commune_essai/"
const TMP := "user://test_structures/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var communes: Node = root.get_node("Communes")
	var registre: Node = root.get_node("Registre")
	_vocabulaire()
	_manifestes()
	DirAccess.make_dir_recursive_absolute(TMP)
	check(registre.entrees.size() == 1 and registre.structure("smarves/stade").champs.club == "L'Étoile de Smarves",
		"Smarves seule : le registre n'a que son stade (%d)" % registre.entrees.size())
	var annonces := [0]
	registre.change.connect(func(): annonces[0] += 1)

	var pck := TMP + "essai.pck"
	var pk := PCKPacker.new()
	pk.pck_start(pck)
	pk.add_file("res://communes/essai/commune.json", ESSAI + "commune.json")
	pk.add_file("res://communes/essai/commune.tscn", ESSAI + "commune.tscn")
	pk.flush()
	check(communes.charger_pack(pck) == "essai", "la commune d'essai se greffe avec ses structures %s" % str(communes.refus))
	check(annonces[0] >= 1, "le registre se reconstruit à l'inscription")
	var gare: Dictionary = registre.structure("essai/gare")
	check(gare.get("type") == "gare" and gare.get("installee") == true and gare.get("insee") == "86113" and gare.get("nom") == "La halte d'essai",
		"la halte d'essai est au registre, installée : %s" % str(gare))
	var stade: Dictionary = registre.structure("essai/stade")
	check(stade.get("champs", {}).get("club") == "Union sportive d'essai" and stade.champs.couleurs == ["#1b3c8c", "#f2c94c"],
		"le stade porte son club et ses couleurs")
	check(registre.de_commune("essai").size() == 2 and registre.de_type("terrain_foot").size() == 2, "deux structures d'essai, deux terrains avec celui de Smarves")

	# Le catalogue : une commune publiée, pas installée, avec une gare ; une structure fautive est écartée sans bruit.
	var catalogue := {"format": 1, "communes": [
		_entree("86133", "liguge", [{"type": "gare", "id": "gare", "nom": "La gare de Ligugé", "noeud": "Gare"},
			{"type": "piscine", "id": "piscine", "nom": "La piscine"}]),
		_entree("86015", "availles_limouzine", [{"type": "gare", "id": "gare", "nom": "La gare d'Availles"}]),
		# Une copie au catalogue de la commune déjà installée : l'installée l'emporte, pas de doublon.
		_entree("86113", "essai", [{"type": "gare", "id": "autre", "nom": "Une autre halte"}]),
	]}
	communes.catalogue = Portail.entrees(JSON.stringify(catalogue))
	check(communes.catalogue[0].structures.size() == 1, "le portail écarte une structure inconnue de ce socle")
	communes.catalogue_lu.emit()
	var lig: Dictionary = registre.structure("liguge/gare")
	check(not lig.is_empty() and lig.installee == false and lig.commune_nom == "Ligugé", "la gare de Ligugé, publiée, est au registre sans être installée")
	check(registre.structure("essai/autre").is_empty(), "la commune installée l'emporte sur sa copie au catalogue")
	check(registre.de_type("gare", true).size() == 1 and registre.de_type("gare").size() == 3, "trois gares, dont une où l'on peut aller")
	var r: Array = registre.relies("essai/gare")
	check(r.size() == 2 and r[0].commune == "liguge" and r[1].commune == "availles_limouzine",
		"la halte d'essai mène aux autres gares, la plus proche d'abord : %s" % str(r.map(func(x): return x.commune)))
	check(registre.relies("essai/stade").is_empty(), "un terrain ne relie rien : c'est le championnat qui le lit")

	# La scène place la structure : le nœud nommé dans le manifeste.
	check(communes.ouvrir("essai"), "la commune d'essai s'ouvre")
	var scene: Node = load("res://communes/essai/commune.tscn").instantiate()
	var n: Node = registre.noeud(scene, stade)
	check(n is Node3D and n.position == Vector3(8, 0, 4), "le stade est posé dans la scène par son nœud « Terrain »")
	scene.free()

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _entree(insee: String, id: String, structures: Array) -> Dictionary:
	return {"insee": insee, "id": id, "nom": Vienne.commune(insee).nom, "version": "0.1.0", "paquet": "https://exemple.fr/%s.pck" % id,
		"taille": 1000, "sha256": "0".repeat(64), "structures": structures}


func _vocabulaire() -> void:
	var bon := [
		{"type": "gare", "id": "gare", "nom": "La gare"},
		{"type": "arret_car", "id": "arret", "nom": "L'arrêt de la place", "noeud": "Arret", "lot": "place"},
		{"type": "terrain_foot", "id": "stade", "nom": "Le stade", "club": "L'Étoile", "couleurs": ["#ffffff", "#000000"]},
	]
	check(Structures.verifier(bon).is_empty(), "une gare, un arrêt de car et un terrain se déclarent %s" % str(Structures.verifier(bon)))
	check(Structures.verifier(null).is_empty() and Structures.verifier([]).is_empty(), "pas de structures : rien à redire")
	var cas := [
		["une structure vide", [{}], "type de structure inconnu"],
		["une piscine", [{"type": "piscine", "id": "p", "nom": "La piscine"}], "inconnu"],
		["deux gares", [{"type": "gare", "id": "a", "nom": "A"}, {"type": "gare", "id": "b", "nom": "B"}], "une seule"],
		["un id en double", [{"type": "gare", "id": "a", "nom": "A"}, {"type": "arret_car", "id": "a", "nom": "B"}], "en double"],
		["un id invalide", [{"type": "gare", "id": "La Gare", "nom": "A"}], "id invalide"],
		["sans nom", [{"type": "gare", "id": "g"}], "nom"],
		["un terrain sans club", [{"type": "terrain_foot", "id": "s", "nom": "Le stade"}], "« club »"],
		["une couleur fausse", [{"type": "terrain_foot", "id": "s", "nom": "S", "club": "C", "couleurs": ["bleu"]}], "couleurs"],
		["un champ inconnu", [{"type": "gare", "id": "g", "nom": "G", "voies": 3}], "champ inconnu"],
		["un champ du mauvais type", [{"type": "gare", "id": "g", "nom": "G", "noeud": 3}], "bon type"],
	]
	for c in cas:
		var e := Structures.verifier(c[1])
		check(not e.is_empty() and " ".join(e).contains(c[2]), "refusé : %s (%s)" % [c[0], " ".join(e)])
	check(not Structures.verifier("gare").is_empty(), "refusé : « structures » qui n'est pas une liste")


func _manifestes() -> void:
	check(Commune.smarves().valide() and Commune.smarves().structures().size() == 1, "le manifeste de Smarves reste valide, avec son stade")
	for id in ["liguge", "la_villedieu_du_clain", "availles_limouzine"]:
		var t := FileAccess.get_file_as_string("res://tools/paquet_essai/%s/commune.json" % id)
		var c := Commune.depuis_texte(t, "res://communes/%s/commune.json" % id, "essai.pck")
		check(c.valide(), "le paquet %s, sans structures, reste valide %s" % [id, " ".join(c.erreurs)])
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/paquet_essai/liguge/commune.json"))
	m["structures"] = [{"type": "terrain_foot", "id": "stade", "nom": "Le stade"}]
	var c := Commune.depuis_texte(JSON.stringify(m), "res://communes/liguge/commune.json", "essai.pck")
	check(not c.valide() and " ".join(c.erreurs).contains("club"), "un manifeste aux structures fautives est refusé")
