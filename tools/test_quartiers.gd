extends SceneTree
## Vérifie les quartiers enregistrés (scripts/socle/quartiers.gd) sans affichage :
## godot --headless --path . -s tools/test_quartiers.gd
## Le champ « quartiers » du manifeste se vérifie ; avant d'être enregistré, un quartier se bâtit par son
## script ; enregistré, il se lit dans un fil et revient le même, sans que son script ne tourne.

const TMP := "user://test_quartiers/"
const BATIR := """extends RefCounted
static var fois := 0
static func batir(r: Node3D) -> void:
	fois += 1
	for i in 20:
		var m := MeshInstance3D.new()
		m.name = "Maison%d" % i
		m.mesh = BoxMesh.new()
		m.position = Vector3(i * 8.0, 0, 0)
		r.add_child(m)
	var l := Label3D.new()
	l.text = "Rue du Château"
	r.add_child(l)
	var s := Node3D.new()
	s.name = "Sas_bas"
	s.position = Vector3(150.0, 0, 0)
	s.set_meta("rayon", 8.0)
	r.add_child(s)
"""

## Un quartier à 300 m à l'est, avec un sas vers le château à 150 m (au milieu).
const SAS := """extends RefCounted
static func batir(r: Node3D) -> void:
	for i in 10:
		var m := MeshInstance3D.new()
		m.name = "Immeuble%d" % i
		m.mesh = BoxMesh.new()
		m.position = Vector3(300.0 + i * 6.0, 0, 0)
		r.add_child(m)
	var s := Node3D.new()
	s.name = "Sas_chateau"
	s.position = Vector3(150.0, 0, 0)
	s.set_meta("rayon", 8.0)
	r.add_child(s)
"""

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	check(Quartiers.verifier(null).is_empty(), "sans champ « quartiers », rien à redire")
	check(Quartiers.verifier({"chateau": {"batir": "quartiers/chateau.gd", "scene": "quartiers/chateau.scn"}}).is_empty(), "un quartier bien déclaré passe")
	var e := Quartiers.verifier({"Chateau": {"batir": "res://x.gd"}, "bas": {"batir": "../x.gd", "scene": "bas.png", "lod": 1}, "pont": 3})
	check(e.size() == 6, "nom, chemins hors du dossier, extension, champ inconnu, valeur qui n'est pas un objet : %s" % str(e))
	check(not Commune.verifier_facultatifs({"quartiers": []}).is_empty(), "le manifeste refuse un champ « quartiers » mal formé")

	DirAccess.make_dir_recursive_absolute(TMP + "quartiers")
	var f := FileAccess.open(TMP + "quartiers/chateau.gd", FileAccess.WRITE)
	f.store_string(BATIR)
	f.close()
	DirAccess.remove_absolute(TMP + "quartiers/chateau.scn")
	var c := Commune.new()
	c.id = "essai_quartiers"
	c.chemin = TMP + "commune.json"
	c.data = {"quartiers": {"chateau": {"batir": "quartiers/chateau.gd"}}}
	var q := Quartiers.de(c)
	check(q.chateau.scene == TMP + "quartiers/chateau.scn", "la scène d'un quartier est par défaut quartiers/<nom>.scn")

	var lieu := Node3D.new()
	root.add_child(lieu)
	var bati: Node3D = await Quartiers.poser_de(lieu, c, "chateau")
	var script: GDScript = load(q.chateau.batir)
	check(bati != null and bati.get_child_count() == 22 and script.fois == 1, "pas encore enregistré, le quartier se bâtit par son script")
	check(Quartiers.enregistrer(bati, q.chateau.scene) == OK and FileAccess.file_exists(q.chateau.scene), "le quartier bâti s'enregistre")
	Quartiers.demander(c)
	var lu: Node3D = await Quartiers.poser_de(lieu, c, "chateau")
	check(lu != null and lu.scene_file_path == q.chateau.scene and script.fois == 1, "enregistré, il se lit dans un fil, sans rebâtir")
	check(lu.get_child_count() == 22 and (lu.get_node("Maison7") as MeshInstance3D).position.x == 56.0 and lu.find_children("*", "Label3D", true, false)[0].text == "Rue du Château", "il revient tel qu'il a été bâti")
	check(await Quartiers.poser_de(lieu, c, "inconnu") == null, "un quartier non déclaré ne se pose pas")
	await process_frame
	lieu.free()

	# Socle 1.26 : les champs centre, rayon et lointain ; la version lointaine ; la veille des sas.
	check(Quartiers.verifier({"a": {"batir": "quartiers/a.gd", "centre": [275, 215.5], "rayon": 180, "lointain": "quartiers/a_loin.scn"}}).is_empty(), "centre, rayon et lointain bien déclarés passent")
	e = Quartiers.verifier({"a": {"batir": "quartiers/a.gd", "centre": [1], "rayon": -3, "lointain": "a.png"}})
	check(e.size() == 3, "centre à un seul nombre, rayon négatif, lointain qui n'est pas une scène : %s" % str(e))
	f = FileAccess.open(TMP + "quartiers/sas.gd", FileAccess.WRITE)
	f.store_string(SAS)
	f.close()
	var c2 := Commune.new()
	c2.id = "essai_veille"
	c2.chemin = TMP + "commune.json"
	c2.data = {"quartiers": {
		"chateau": {"batir": "quartiers/chateau.gd", "centre": [0, 0], "rayon": 100},
		"bas": {"batir": "quartiers/sas.gd", "centre": [300, 0], "rayon": 100}}}
	var q2 := Quartiers.de(c2)
	check(q2.chateau.lointain == TMP + "quartiers/chateau_loin.scn" and q2.bas.centre == Vector2(300, 0) and q2.bas.rayon == 100.0 and q.chateau.rayon == 150.0, "lointain par défaut quartiers/<nom>_loin.scn, centre et rayon lus, rayon 150 m sans déclaration")
	DirAccess.remove_absolute(TMP + "quartiers/chateau_loin.scn")
	DirAccess.remove_absolute(TMP + "quartiers/bas_loin.scn")
	var ville := Node3D.new()
	root.add_child(ville)
	var plein: Node3D = await Quartiers.poser_de(ville, c2, "chateau")
	var el := Quartiers.enregistrer_lointain(plein, q2.chateau.lointain)
	check(el == OK and FileAccess.file_exists(q2.chateau.lointain) and plein.get_child_count() == 22, "la version lointaine s'enregistre, et le quartier plein garde ses nœuds")
	plein.free()
	var loin: Node3D = await Quartiers.lointain_de(ville, c2, "chateau")
	check(loin != null and loin.name == "chateau_loin" and loin.get_meta("quartier_loin") == "chateau" and loin.get_child_count() == 1 \
		and (loin.get_child(0) as MeshInstance3D).mesh.get_surface_count() == 1 and (loin.get_child(0) as MeshInstance3D).visibility_range_begin == 0.0, "enregistrée, la version lointaine se pose seule : vingt maisons fondues en un maillage, visible à toute distance")
	loin.free()
	var sans: Node3D = await Quartiers.lointain_de(ville, c2, "bas")
	check(sans != null and sans.get_child_count() == 1 and ville.get_child_count() == 1, "sans scène enregistrée, la version lointaine se bâtit et se fond sur place, sans laisser le quartier plein")
	sans.free()

	var joueur := Node3D.new()
	ville.add_child(joueur)
	var veille := Quartiers.veiller_de(ville, c2, joueur, "chateau")
	for i in 6:
		await process_frame
	check(veille.detailles.has("chateau") and not veille.detailles.has("bas") and veille.lointains.has("bas") and ville.get_node_or_null("bas_loin") != null, "au départ, le quartier du joueur en détail, l'autre au loin")
	joueur.position = Vector3(60, 0, 0)
	var v := veille.verifier()
	check(v == ["chateau"], "à 60 m du château, loin du sas, rien ne change")
	var hors := Node3D.new()
	ville.add_child(hors)
	var sas_hors := Node3D.new()
	sas_hors.name = "Sas_bas"
	sas_hors.position = Vector3(60, 0, 0)
	hors.add_child(sas_hors)
	check(veille.ajouter_sas(hors) == 1 and veille.voulus() == ["chateau", "bas"], "un sas déclaré hors des quartiers (la place de départ) compte comme les autres")
	hors.free()
	check(veille.voulus() == ["chateau"], "un sas déclaré puis retiré de l'arbre ne compte plus")
	joueur.position = Vector3(148, 0, 0)
	v = veille.verifier()
	for i in 6:
		await process_frame
	check(v == ["chateau", "bas"] and veille.detailles.has("bas") and not veille.lointains.has("bas") and ville.get_node_or_null("bas_loin") == null, "dans le sas, le quartier d'en face se pose en détail et sa version lointaine s'efface")
	joueur.position = Vector3(240, 0, 0)
	v = veille.verifier()
	for i in 6:
		await process_frame
	check(v == ["bas"] and veille.courant == "bas" and not veille.detailles.has("chateau") and veille.lointains.has("chateau") and ville.get_node_or_null("chateau_loin") != null, "sorti du sas côté bas, le château repasse au loin")
	ville.free()
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
