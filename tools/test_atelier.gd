extends SceneTree
## Vérifie l'atelier du socle sans affichage : godot --headless --path . -s tools/test_atelier.gd
## Chaque nom du catalogue (scripts/socle/atelier.json) mène à quelque chose : chaque famille a des
## modèles et le premier se pose pied au sol à la hauteur demandée, chaque meuble se construit, chaque
## matière a son shader, chaque son a son groupe, chaque tenue habille un figurant, une rue se bâtit.
## C'est la promesse faite aux communes : un nom du catalogue ne casse pas sans qu'on le voie ici.

const SFX := preload("res://scripts/sfx.gd")

## Chargé à l'exécution : l'atelier parle aux autoloads (Sfx, Biens), qu'un script -s ne voit pas encore
## quand il se compile.
var Atelier: GDScript
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	Atelier = load("res://scripts/socle/atelier.gd")
	var cat: Dictionary = Atelier.catalogue()
	check(int(cat.get("format", 0)) == 1, "le catalogue se lit (format 1)")
	var scene := Node3D.new()
	root.add_child(scene)

	for f in Atelier.familles():
		var noms: PackedStringArray = Atelier.modeles(f)
		check(noms.size() > 0, "la famille « %s » a %d modèles" % [f, noms.size()])
		if noms.is_empty():
			continue
		var id := "%s/%s" % [f, noms[0]]
		var m: Node3D = Atelier.modele(id, 1.0)
		check(m != null, "« %s » se pose" % id)
		if m:
			scene.add_child(m)
			var b: AABB = Atelier._boite(m, Transform3D.IDENTITY)
			check(absf(b.size.y - 1.0) < 0.02, "  à la hauteur demandée (%.2f)" % b.size.y)
	check(Atelier.modele("nature/rien_du_tout") == null, "un modèle inconnu rend null")

	for id in cat.meubles.ids:
		var n: Node3D = Atelier.meuble(id)
		check(n != null and n.get_child_count() > 0, "le meuble « %s » se construit" % id)
		if n:
			n.free()

	for nom in cat.matieres:
		var mat: ShaderMaterial = Atelier.matiere(nom)
		check(mat != null and mat.shader != null, "la matière « %s » a son shader" % nom)

	for g in cat.sons.groupes:
		check(SFX.GROUPS.has(g), "le son « %s » existe" % g)

	for tenue in cat.figurants.tenues:
		var v: Node3D = Atelier.figurant(7, "idle", tenue)
		scene.add_child(v)
		await process_frame
		check(v.get_child_count() > 0, "un figurant en tenue « %s » est habillé" % tenue)

	var rue := Node3D.new()
	scene.add_child(rue)
	Atelier.rue(rue, [[Transform3D.IDENTITY, {"w": 3.0, "d": 3.0, "floors": 2, "shop": {"name": "Essai"}}]], 3)
	var mailles := rue.find_children("*", "MeshInstance3D", true, false)
	check(mailles.size() > 0, "une rue se bâtit (%d maillages)" % mailles.size())

	scene.queue_free()
	print("\n%d échec(s)" % fails)
	quit(1 if fails else 0)
