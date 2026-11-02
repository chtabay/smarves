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
	joueur.position = Vector3(300, 0, 115)
	check(veille.voulus() == ["bas"], "à 15 m au-delà du rayon, le quartier courant tient encore (marge)")
	joueur.position = Vector3(300, 0, 130)
	v = veille.verifier()
	for i in 6:
		await process_frame
	check(v == [] and veille.courant == "" and not veille.detailles.has("bas") and veille.lointains.has("bas"), "sorti du rayon et de sa marge, le quartier courant lâche : tout est au loin, la scène de la commune tient le décor")
	joueur.position = Vector3(300, 0, 50)
	check(veille.voulus() == ["bas"], "revenu dans le rayon, le quartier redevient courant")
	ville.free()

	# La version légère : sous un mètre, rien ; un maillage lourd devient sa boîte.
	var lourd := Node3D.new()
	lourd.name = "lourd"
	# la racine reçoit ses objets lointains (Chargement) à l'image suivante : pas ici, on fond tout de suite
	lourd.set_meta("sans_lointain", true)
	root.add_child(lourd)
	var sphere := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 5.0
	sm.height = 10.0
	sm.radial_segments = 128
	sm.rings = 64
	sphere.mesh = sm
	sphere.position = Vector3(0, 5, 0)
	lourd.add_child(sphere)
	var petit := MeshInstance3D.new()
	petit.mesh = BoxMesh.new()
	petit.mesh.size = Vector3(0.5, 0.5, 0.5)
	lourd.add_child(petit)
	var maison := MeshInstance3D.new()
	maison.mesh = BoxMesh.new()
	maison.mesh.size = Vector3(8, 6, 8)
	maison.position = Vector3(20, 3, 0)
	lourd.add_child(maison)
	# une brique qui a ses deux niveaux : le corps de près (fini à 40 m) et le corps lointain (commence à 40 m)
	var pres := MeshInstance3D.new()
	pres.mesh = sm
	pres.visibility_range_end = 40.0
	pres.position = Vector3(-20, 5, 0)
	lourd.add_child(pres)
	var loin_brique := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(8, 6, 8)
	loin_brique.mesh = pm
	loin_brique.visibility_range_begin = 40.0
	loin_brique.position = Vector3(-20, 3, 0)
	lourd.add_child(loin_brique)
	# un pan fondu de 100 m, lourd : trop grand pour une boîte, il reste tel quel
	var pan := MeshInstance3D.new()
	var pm2 := SphereMesh.new()
	pm2.radius = 50.0
	pm2.height = 100.0
	pm2.radial_segments = 64
	pm2.rings = 32
	pan.mesh = pm2
	pan.position = Vector3(200, 0, 0)
	lourd.add_child(pan)
	# une façade à shader : sa boîte prend un enduit simple, pas le shader
	var ouvragee := MeshInstance3D.new()
	ouvragee.mesh = sm
	ouvragee.material_override = ShaderMaterial.new()
	ouvragee.position = Vector3(40, 5, 0)
	lourd.add_child(ouvragee)
	# un volume de quartier : 3 000 sommets de quads disjoints, qui ne se simplifient pas ; il reste tel quel
	var quads := SurfaceTool.new()
	quads.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 500:
		var o := Vector3(80 + (i % 25) * 0.5, 0, 40 + (i / 25) * 0.5)
		for coin in [Vector3(0, 0, 0), Vector3(0.4, 0, 0), Vector3(0.4, 3, 0), Vector3(0, 0, 0), Vector3(0.4, 3, 0), Vector3(0, 3, 0)]:
			quads.set_normal(Vector3.BACK)
			quads.add_vertex(o + coin)
	var volume := MeshInstance3D.new()
	volume.mesh = quads.commit()
	lourd.add_child(volume)
	# les volumes d'un quartier (les Terreaux) : des murs de 6 à 10 m autour de 130 emprises, un pan de mur
	# par triangle, aux UV du shader des murs ; meshoptimizer saurait les réduire, mais il n'en ferait que des
	# pans crevés et aveugles (planche 43 de la rue Terme) : déjà au plus simple, ils restent entiers
	var murs := SurfaceTool.new()
	murs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 130:
		var o := Vector2(120 + (i % 13) * 12.0, 40 + (i / 13) * 12.0)
		var coins := [o, o + Vector2(8, 0), o + Vector2(8, 6), o + Vector2(0, 6)]
		for k in 4:
			var a: Vector2 = coins[k]
			var bout: Vector2 = coins[(k + 1) % 4]
			var n := Vector2(bout.y - a.y, a.x - bout.x).normalized()
			var pts := [Vector3(a.x, 0, a.y), Vector3(bout.x, 0, bout.y), Vector3(bout.x, 15, bout.y), Vector3(a.x, 15, a.y)]
			var uvs := [Vector2(0, 0), Vector2(2.5, 0), Vector2(2.5, 15), Vector2(0, 15)]
			for j in [0, 1, 2, 0, 2, 3]:
				murs.set_normal(Vector3(n.x, 0, n.y))
				murs.set_color(Color.BISQUE)
				murs.set_uv(uvs[j])
				murs.set_uv2(Vector2(15, i))
				murs.add_vertex(pts[j])
	var volumes := MeshInstance3D.new()
	volumes.name = "Volumes"
	volumes.mesh = murs.commit()
	volumes.material_override = ShaderMaterial.new()
	lourd.add_child(volumes)
	var leger := Quartiers.fondre(lourd)
	var sommets := 0
	var matieres := []
	for morceau in leger.get_children():
		var am: ArrayMesh = (morceau as MeshInstance3D).mesh
		for si in am.get_surface_count():
			matieres.append(am.surface_get_material(si))
			sommets += am.surface_get_array_len(si)
	var plein_sommets := 0
	for mi: MeshInstance3D in lourd.find_children("*", "MeshInstance3D", true, false):
		plein_sommets += Lointain._sommets(mi.mesh)
	var volumes_loin := 0
	for morceau in leger.get_children():
		var am: ArrayMesh = (morceau as MeshInstance3D).mesh
		for si in am.get_surface_count():
			if am.surface_get_material(si) == volumes.material_override:
				volumes_loin += am.surface_get_array_len(si)
	check(volumes_loin == 130 * 4 * 6, "version légère : les volumes d'un quartier, un pan de mur par triangle, restent entiers (%d sommets pour %d)" % [volumes_loin, 130 * 4 * 6])
	check(leger != null and matieres.any(func(m): return m is ShaderMaterial), "version légère : une façade à shader simplifiée garde son shader")
	check(sommets > 3000 + 3120 + 48 + Lointain._sommets(pm) and (sommets - volumes_loin) * 4 < plein_sommets - volumes_loin, "version légère : les maillages lourds sont simplifiés, pas mis en boîte, un volume de quads qui ne se simplifie pas reste entier (%d sommets pour %d), la caisse de 50 cm disparaît, la maison et le corps lointain de la brique restent" % [sommets, plein_sommets])
	leger.free()
	lourd.free()

	# Sous une ville réduite (Lyon : 1/2,4), la veille mesure toujours en mètres, dans le repère du parent.
	var reduite := Node3D.new()
	reduite.scale = Vector3.ONE / 2.4
	root.add_child(reduite)
	var j2 := Node3D.new()
	root.add_child(j2)
	var v2 := Quartiers.veiller_de(reduite, c2, j2, "chateau")
	for i in 6:
		await process_frame
	j2.position = Vector3(60, 0, 0) / 2.4
	check(v2.voulus() == ["chateau"], "ville réduite : à 60 m (25 unités) du château, le château reste courant")
	j2.position = Vector3(148, 0, 0) / 2.4
	check(v2.voulus() == ["chateau", "bas"], "ville réduite : dans le sas de 6 m, mesuré en mètres, le quartier d'en face est voulu")
	j2.position = Vector3(240, 0, 0) / 2.4
	check(v2.voulus() == ["bas"], "ville réduite : au-delà, le bas est courant et le château lâche")
	reduite.free()
	j2.free()

	# Une racine de quartier réduite par le quartier lui-même ne s'enregistre pas : à la pose sous le parent
	# réduit, elle le serait deux fois (Lyon 0.2.0, Saint-Paul à 1/U²).
	var deux_fois := Node3D.new()
	deux_fois.name = "deux_fois"
	deux_fois.scale = Vector3.ONE / 2.4
	root.add_child(deux_fois)
	var boite := MeshInstance3D.new()
	boite.mesh = BoxMesh.new()
	deux_fois.add_child(boite)
	DirAccess.remove_absolute(TMP + "quartiers/deux_fois.scn")
	check(Quartiers.enregistrer(deux_fois, TMP + "quartiers/deux_fois.scn") == ERR_INVALID_DATA and not FileAccess.file_exists(TMP + "quartiers/deux_fois.scn"), "une racine de quartier réduite est refusée à l'enregistrement")
	check(Quartiers.enregistrer_lointain(deux_fois, TMP + "quartiers/deux_fois_loin.scn") == ERR_INVALID_DATA, "sa version lointaine, qui reprend la transformation de la racine, aussi")
	deux_fois.scale = Vector3.ONE
	check(Quartiers.enregistrer(deux_fois, TMP + "quartiers/deux_fois.scn") == OK, "à l'échelle 1, la même racine s'enregistre")
	deux_fois.free()
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
