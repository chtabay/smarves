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
	check(bati != null and bati.get_child_count() == 21 and script.fois == 1, "pas encore enregistré, le quartier se bâtit par son script")
	check(Quartiers.enregistrer(bati, q.chateau.scene) == OK and FileAccess.file_exists(q.chateau.scene), "le quartier bâti s'enregistre")
	Quartiers.demander(c)
	var lu: Node3D = await Quartiers.poser_de(lieu, c, "chateau")
	check(lu != null and lu.scene_file_path == q.chateau.scene and script.fois == 1, "enregistré, il se lit dans un fil, sans rebâtir")
	check(lu.get_child_count() == 21 and (lu.get_node("Maison7") as MeshInstance3D).position.x == 56.0 and lu.find_children("*", "Label3D", true, false)[0].text == "Rue du Château", "il revient tel qu'il a été bâti")
	check(await Quartiers.poser_de(lieu, c, "inconnu") == null, "un quartier non déclaré ne se pose pas")
	await process_frame
	lieu.free()
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
