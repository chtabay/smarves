extends SceneTree
## Vérifie le chemin d'une commune publiée, du catalogue du portail jusqu'à sa scène, sans affichage :
## godot --headless --path . -s tools/test_portail.gd
## Un petit serveur local (python3 -m http.server) tient lieu de portail : il sert un catalogue et le
## paquet d'essai (tools/paquet_essai/, La Villedieu-du-Clain), emballé ici comme le fait
## tools/emballer_commune.gd. Le jeu lit le catalogue, installe le paquet, l'inscrit, y entre ; un
## paquet dont l'empreinte ne correspond pas est refusé et effacé ; hors ligne, la liste reste.

const ESSAI := "res://tools/paquet_essai/la_villedieu_du_clain/"
const ID := "la_villedieu_du_clain"
const TMP := "user://test_portail/"
const PORT := 8765

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var communes: Node = root.get_node("Communes")
	DirAccess.make_dir_recursive_absolute(TMP + "srv")
	for f in [TMP + "communes/%s.pck" % ID, TMP + "communes/installees.json", TMP + "communes/catalogue.json"]:
		DirAccess.remove_absolute(f)
	communes.dossier_greffes = TMP + "communes/"

	var pk := PCKPacker.new()
	var paquet := TMP + "srv/%s-0.1.0.pck" % ID
	pk.pck_start(paquet)
	pk.add_file("res://communes/%s/commune.json" % ID, ESSAI + "commune.json")
	pk.add_file("res://communes/%s/commune.tscn" % ID, ESSAI + "commune.tscn")
	pk.flush()
	var sha := FileAccess.get_sha256(paquet)
	var base := "http://127.0.0.1:%d/" % PORT
	var entree := {"insee": "86290", "id": ID, "nom": "La Villedieu-du-Clain", "auteur": "Claude", "version": "0.1.0",
		"description": "Paquet d'essai.", "paquet": base + paquet.get_file(), "taille": FileAccess.get_file_as_bytes(paquet).size(),
		"sha256": sha, "publie_le": "2026-10-17T21:00:00Z"}
	var faux := entree.duplicate()
	faux.id = "faux"
	faux.insee = "86100"
	faux.sha256 = "0".repeat(64)
	var abime := entree.duplicate()
	abime.id = "abime"
	abime.insee = "79191"
	Portail.ecrire(TMP + "srv/catalogue.json", JSON.stringify({"format": 1, "communes": [entree, faux, abime]}))

	var srv := OS.create_process("python3", ["-m", "http.server", str(PORT), "--bind", "127.0.0.1", "--directory", ProjectSettings.globalize_path(TMP + "srv")])
	check(srv > 0, "le portail local démarre")
	await create_timer(1.5).timeout

	communes.lire_catalogue(base + "catalogue.json")
	await communes.catalogue_lu
	check(communes.catalogue_etat == "en_ligne", "le catalogue se lit (%s)" % communes.catalogue_etat)
	check(communes.publiees().map(func(e): return e.id) == [ID, "faux"], "seules les entrées valides sont gardées (hors de la Vienne : ignorée)")
	var carte: Array = communes.carte()
	var ville: Dictionary = carte.filter(func(e): return e.insee == "86290")[0]
	check(ville.publiee and not ville.cliquable, "sur la carte, la commune publiée n'est pas encore cliquable")
	check(FileAccess.file_exists(TMP + "communes/catalogue.json"), "la copie du catalogue est gardée pour le hors-ligne")

	communes.installer(ID)
	var r: Array = await communes.installee
	check(r[1], "le paquet publié s'installe : %s" % r[2])
	check(FileAccess.file_exists(TMP + "communes/%s.pck" % ID), "il est rangé sous communes/%s.pck" % ID)
	check(communes.installees() == [ID] and communes.installations.get(ID) == "0.1.0", "la commune est inscrite, version 0.1.0")
	ville = communes.carte().filter(func(e): return e.insee == "86290")[0]
	check(ville.cliquable and ville.id == ID, "elle devient cliquable à son code INSEE")

	communes.installer("faux")
	r = await communes.installee
	check(not r[1] and "ne correspond pas" in r[2], "un paquet dont l'empreinte ne correspond pas est refusé : %s" % r[2])
	check(not FileAccess.file_exists(TMP + "communes/faux.pck") and not FileAccess.file_exists(TMP + "communes/faux.pck.part"), "et rien n'en reste")

	OS.kill(srv)
	communes.lire_catalogue(base + "catalogue.json")
	await communes.catalogue_lu
	check(communes.catalogue_etat == "hors_ligne" and communes.publiees().size() == 2, "hors ligne, la dernière liste reste")

	check(communes.visiter(ID), "on y entre")
	await process_frame
	await process_frame
	var scene := current_scene
	check(scene != null and scene.name == "Commune" and (scene.get_node("Panneau") as Label3D).text == "La Villedieu-du-Clain", "sa scène s'ouvre depuis le paquet, sans erreur")
	check(communes._retour.visible, "le bouton « Revenir à Smarves » est posé")
	communes._bouton_retour(false)

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
