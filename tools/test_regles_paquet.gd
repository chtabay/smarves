extends SceneTree
## Vérifie les règles des paquets (tools/regles_paquet.gd) et la lecture des données compressées
## (Atelier.donnees), sans affichage : godot --headless --path . -s tools/test_regles_paquet.gd
## L'emballage d'un vrai dossier se vérifie à la main : tools/emballer_commune.gd -- <id> --depuis=…

const REGLES := preload("res://tools/regles_paquet.gd")
const TMP := "user://regles_paquet/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(TMP + "ecrans/")
	for f in ["grande.png", "petite.png", "ecrans/tableau.png", "pnj.json", "pnj.json.gz", "emballage.json", "jeton.png"]:
		DirAccess.remove_absolute(TMP + f)
	Image.create(512, 300, false, Image.FORMAT_RGB8).save_png(TMP + "grande.png")
	Image.create(200, 120, false, Image.FORMAT_RGB8).save_png(TMP + "petite.png")
	Image.create(1024, 512, false, Image.FORMAT_RGB8).save_png(TMP + "ecrans/tableau.png")

	# Les textures : au-delà de 256 px, sans perte, elles passent en WebP avec perte.
	check(REGLES.cote(TMP + "grande.png") == 512 and REGLES.cote(TMP + "petite.png") == 200, "le plus grand côté d'une image")
	check(REGLES.trop_lourde(512, "") and not REGLES.trop_lourde(200, ""), "une image de plus de 256 px sans réglage est trop lourde, pas une petite")
	var sans := "[remap]\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\ncompress/mode=0\nmipmaps/generate=true\n"
	check(REGLES.trop_lourde(512, sans), "réglée sans perte, elle est trop lourde")
	var avec := REGLES.import_avec_perte(sans)
	var cfg := ConfigFile.new()
	cfg.parse(avec)
	check(int(cfg.get_value("params", "compress/mode")) == 1 and is_equal_approx(float(cfg.get_value("params", "compress/lossy_quality")), 0.85)
		and bool(cfg.get_value("params", "mipmaps/generate")), "la conversion règle WebP avec perte (0,85) et garde le reste")
	check(not REGLES.trop_lourde(512, avec), "convertie, elle ne l'est plus")
	check(not REGLES.trop_lourde(512, sans.replace("compress/mode=0", "compress/mode=2")), "une texture compressée pour la carte graphique reste comme elle est")
	var neuve := ConfigFile.new()
	neuve.parse(REGLES.import_avec_perte(""))
	check(str(neuve.get_value("remap", "importer")) == "texture" and int(neuve.get_value("params", "compress/mode")) == 1, "une image sans .import en reçoit un, avec perte")

	# Les réglages de la commune : ce qu'elle garde sans perte.
	FileAccess.open(TMP + "emballage.json", FileAccess.WRITE).store_string(JSON.stringify({"sans_perte": ["ecrans/"]}))
	var r := REGLES.reglages(TMP)
	check(REGLES.sans_perte("ecrans/tableau.png", r) and not REGLES.sans_perte("grande.png", r) and REGLES.verifier_reglages(TMP).is_empty(), "emballage.json garde un dossier sans perte")
	FileAccess.open(TMP + "emballage.json", FileAccess.WRITE).store_string(JSON.stringify({"sans_perte": "ecrans/", "qualite": 1}))
	check(REGLES.verifier_reglages(TMP).size() == 2, "un emballage.json fautif : un champ inconnu, une liste attendue")
	FileAccess.open(TMP + "emballage.json", FileAccess.WRITE).store_string(JSON.stringify({"sans_perte": ["ecrans/"]}))

	# Les données : au-delà de 100 Ko, compressées ; Atelier.donnees lit l'une ou l'autre.
	var pnj := []
	for i in 3000:
		pnj.append({"nom": "Habitant %d" % i, "metier": "boulanger", "phrase": "Bonjour, la place est belle ce matin."})
	var texte := JSON.stringify(pnj)
	FileAccess.open(TMP + "pnj.json", FileAccess.WRITE).store_string(texte)
	check(texte.length() > REGLES.DONNEE_MAX, "des données de plus de 100 Ko")
	FileAccess.open(TMP + "jeton.png", FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(_un_fichier_du_jeu()))
	var rapport := REGLES.rapport(TMP, REGLES.index_du_jeu())
	var dit := func(debut: String) -> bool: return Array(rapport).any(func(l): return l.begins_with(debut))
	check(dit.call("grande.png : 512 px sans perte"), "le rapport dit la texture trop lourde : %s" % str(rapport))
	check(not dit.call("ecrans/") and not dit.call("petite.png"), "pas celle gardée sans perte, ni la petite")
	check(dit.call("pnj.json : ") and Array(rapport).any(func(l): return l.contains("à compresser")), "il dit les données à compresser")
	check(Array(rapport).any(func(l): return l.begins_with("jeton.png : déjà dans le jeu")), "il dit ce qui est déjà dans le jeu")
	check(_atelier().donnees(TMP + "pnj.json").size() == 3000, "Atelier.donnees lit le JSON en clair")
	var gz := texte.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	FileAccess.open(TMP + "pnj.json.gz", FileAccess.WRITE).store_buffer(gz)
	DirAccess.remove_absolute(TMP + "pnj.json")
	check(gz.size() < texte.length() / 10, "compressées, elles pèsent moins d'un dixième (%d octets)" % gz.size())
	var lu = _atelier().donnees(TMP + "pnj.json")
	check(typeof(lu) == TYPE_ARRAY and lu.size() == 3000 and lu[42].nom == "Habitant 42", "Atelier.donnees lit la version compressée sous le même nom")
	check(not Array(REGLES.rapport(TMP, {})).any(func(l): return l.begins_with("pnj.json")), "compressées, elles ne sont plus signalées")
	# Le gzip de la ligne de commande (gzip -9) se lit aussi.
	DirAccess.remove_absolute(TMP + "petit.json.gz")
	FileAccess.open(TMP + "petit.json", FileAccess.WRITE).store_string("{\"a\": 1}")
	if OS.execute("gzip", ["-9", ProjectSettings.globalize_path(TMP + "petit.json")]) == 0:
		check(int(_atelier().donnees(TMP + "petit.json").get("a", 0)) == 1, "un fichier fait par gzip -9 se lit")

	# La version, à la règle du portail : trois nombres, pas de « -beta » (retour de l'auteur de Chauvigny).
	check(REGLES.refus_version("0.2.0") == "" and REGLES.refus_version("10.0.12") == "", "une version à trois nombres passe")
	for v in ["0.2.0-beta", "0.2", "v1", "", "1.0.0 "]:
		check(REGLES.refus_version(v) != "", "« %s » est refusée, comme au portail" % v)
	# Les notes de travail restent chez l'auteur ; la licence et le mode d'emploi partent.
	for f in ["INTENTIONS.md", "plan-de-travail.md", "notes/critique.md"]:
		check(REGLES.note_de_travail(f), "%s ne part pas" % f)
	for f in ["LICENCE.md", "LIRE-MOI.md", "LISEZMOI.md", "commune.gd", "licence.txt"]:
		check(not REGLES.note_de_travail(f), "%s part" % f)

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


## Une image de l'atelier, pour la copier dans le dossier d'essai.
func _un_fichier_du_jeu() -> String:
	var index := REGLES.index_du_jeu()
	for md5 in index:
		if str(index[md5]).ends_with(".png"):
			return index[md5]
	return ""


## L'atelier, chargé une fois les autoloads en place (il nomme Sfx).
func _atelier() -> GDScript:
	return load("res://scripts/socle/atelier.gd")
