extends SceneTree
## Le pilote d'un agent dans le bureau du club (remontée R-028, 23/11) :
## godot --headless --path . -s tools/test_pilote_bureau.gd
## Les listes déroulantes (formation, mentalité, pressing) montrent leurs choix comme des boutons ; les
## programmes d'entraînement sont des boutons ; un bouton refait par la page entre deux gestes (le marché
## qui se relit) se retrouve par son numéro et son texte.

const TMP := "user://test_pilote_bureau/"

var fails := 0
var P: Node


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func bouton(v: Dictionary, texte: String) -> Dictionary:
	for b in v.get("boutons", []):
		if str(b.texte) == texte or str(b.texte).begins_with(texte):
			return b
	return {}


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	create_timer(200.0).timeout.connect(func():
		print("ÉCHEC   trop long : l'essai s'arrête")
		quit(1))
	P = root.get_node("Pilote")
	var foot: Node = root.get_node("Football")
	var m: Node = root.get_node("Mercato")
	DirAccess.make_dir_recursive_absolute(TMP)
	foot.dossier = TMP
	m.dossier = TMP
	foot.effacer()
	m.effacer()
	var t: int = foot.coup_envoi(1, 3) + 3 * 86400 + 6 * 3600
	foot.regler_horloge(func(): return t)
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	var club := "smarves"
	foot.forcer_porteurs("vous:2", club)
	load("res://scripts/socle/foot_mercato.gd").demo(m, club)
	foot.renforts = m.renforts
	foot.oublier_effectifs()
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var b: Control = load("res://scripts/socle/bureau.gd").new()
	b.set("club", club)
	centre.add_child(b)
	await process_frame

	# La tactique : la formation est une liste ; un clic montre ses choix, un choix la change.
	b.call("aller", "tactique")
	await process_frame
	await process_frame
	var v: Dictionary = P.vue()
	var avant := str((b.get("compo") as Dictionary).formation)
	var liste := bouton(v, avant)
	check(not liste.is_empty() and liste.has("liste") and not liste.has("choisi"), "la formation se voit comme une liste à dérouler (%s)" % liste)
	var r: Dictionary = await P.geste({"geste": "cliquer", "quoi": str(liste.get("id", ""))})
	var choix: Array = r.vue.boutons.filter(func(x): return str(x.texte).begins_with("↳ "))
	check(r.ok and choix.size() == (load("res://scripts/socle/foot_match.gd").FORMATIONS as Dictionary).size(), "un clic montre ses %d choix (%s)" % [choix.size(), r.dit])
	var autre: Array = choix.filter(func(x): return not x.has("choisi"))
	check(choix.filter(func(x): return x.has("choisi")).size() == 1 and not autre.is_empty(), "  le choix en cours est marqué « choisi »")
	var vise := str(autre[0].texte).trim_prefix("↳ ") if not autre.is_empty() else ""
	r = await P.geste({"geste": "cliquer", "quoi": str(autre[0].id) if not autre.is_empty() else ""})
	check(r.ok and str((b.get("compo") as Dictionary).formation) == vise and bool(b.get("modifie")), "un choix change la formation : %s → %s" % [avant, (b.get("compo") as Dictionary).formation])
	check(r.vue.boutons.filter(func(x): return str(x.texte).begins_with("↳ ")).is_empty(), "  et la liste se referme")
	# La mentalité aussi.
	var ment := bouton(r.vue, "Mentalité")
	r = await P.geste({"geste": "cliquer", "quoi": str(ment.get("id", ""))})
	var mchoix: Array = r.vue.boutons.filter(func(x): return str(x.texte).begins_with("↳ ") and not x.has("choisi"))
	var m_avant := str((b.get("compo") as Dictionary).mentalite)
	r = await P.geste({"geste": "cliquer", "quoi": str(mchoix[0].id) if not mchoix.is_empty() else ""})
	check(r.ok and str((b.get("compo") as Dictionary).mentalite) != m_avant, "la mentalité se change de même (%s)" % r.dit)

	# L'entraînement : chaque programme est un bouton.
	b.call("aller", "entrainement")
	await process_frame
	await process_frame
	v = P.vue()
	var def := bouton(v, "Défense")
	var fin := bouton(v, "Finition")
	check(not def.is_empty() and not fin.is_empty() and not bouton(v, "Physique").is_empty(), "les programmes Défense, Finition, Physique sont des boutons")
	# Le marché se relit entre deux gestes : la page refait ses boutons ; « Défense » garde son numéro.
	var ancien: Node = b.find_child("Programme_defense", true, false)
	foot.change.emit()
	m.change.emit()
	for k in 4:
		await process_frame
	check(not is_instance_valid(ancien) or not ancien.is_inside_tree(), "  (la page s'est bien redessinée)")
	r = await P.geste({"geste": "cliquer", "quoi": str(def.get("id", ""))})
	check(r.ok and str(b.get("programme_choisi")) == "defense", "un bouton refait se retrouve par son numéro : Défense choisi (%s)" % r.dit)
	var poser := bouton(r.vue, "Poser le programme « Défense »")
	check(not poser.is_empty(), "  et « Poser le programme « Défense » » suit")
	r = await P.geste({"geste": "cliquer", "quoi": str(poser.get("id", ""))})
	var rr: Dictionary = foot.prochain_match(club)
	check(r.ok and str(foot.consigne_de(rr.s, rr.j, club).consigne.get("entrainement", "")) == "defense", "le programme Défense est posé pour la semaine")
	# Le clic ne part que sur le bouton visé : un autre posé par-dessus ne le reçoit pas à sa place.
	var vise_b: Button = b.find_child("Programme_physique", true, false)
	check(vise_b != null and P._sous_le_doigt(vise_b), "le pilote trouve le bouton sous le doigt")
	var cache := Button.new()
	cache.text = "Dividende"
	cache.position = vise_b.get_global_rect().position
	cache.size = vise_b.size
	var calque := CanvasLayer.new()
	calque.layer = 50
	root.add_child(calque)
	calque.add_child(cache)
	await process_frame
	var pris := [false]
	cache.pressed.connect(func(): pris[0] = true)
	check(not P._sous_le_doigt(vise_b), "  et voit qu'un autre bouton est par-dessus")
	v = P.vue()
	r = await P.geste({"geste": "cliquer", "quoi": str(bouton(v, "Physique").get("id", ""))})
	check(r.ok and str(b.get("programme_choisi")) == "physique" and not pris[0], "  le clic va au programme Physique, pas au bouton par-dessus")
	calque.queue_free()
	await process_frame
	# Un numéro dont le bouton a disparu, et qu'aucun autre ne remplace, reste refusé.
	v = P.vue()
	var fiche := bouton(v, "Finition")
	b.call("aller", "agenda")
	await process_frame
	r = await P.geste({"geste": "cliquer", "quoi": str(fiche.get("id", ""))})
	check(not r.ok or str(b.get("programme_choisi")) != "finition", "un bouton parti avec sa page n'est pas cliqué à l'aveugle")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
