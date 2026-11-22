extends SceneTree
## Vérifie sans affichage : godot --headless --path . -s tools/test_brocante_rangs.gd
## Chez Ginette Boutin (la brocante), un achat ne décale plus les boutons des autres objets : ce qu'on peut
## revendre vient en fin de liste (remontée R-027 : b5 était « Payer comptant » du lit avant un achat, et
## « Financer » de la lampe après).

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _boutons(n: Node) -> Array:
	var out: Array = []
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree() and not (b as Button).disabled and not (b as Button).is_queued_for_deletion():
			out.append((b as Button).text)
	return out


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true
	game.credits = 100000
	var panneau = load("res://scripts/shop_panel.gd").new()
	panneau.seller = "brocante"
	root.add_child(panneau)
	await process_frame
	panneau._refresh()
	await process_frame
	var avant := _boutons(panneau)
	var i_lampe := avant.find("Payer comptant")
	check(i_lampe >= 0 and not avant.any(func(t): return str(t).begins_with("Revendre")), "la vitrine de la brocante : rien à revendre encore")
	# On achète le premier objet comptant : les boutons des autres gardent leur rang.
	var biens: Node = root.get_node("Biens")
	panneau._buy(str(biens.catalogue().filter(func(it): return it.seller == "brocante" and it.gate == 0)[0].id), false)
	await process_frame
	await process_frame
	var apres := _boutons(panneau)
	var achats := avant.filter(func(t): return t in ["Payer comptant", "Financer"])
	check(apres.slice(0, achats.size()) == achats, "après un achat, les boutons d'achat gardent leur rang : %s" % str(apres.slice(0, achats.size())))
	var revendre := apres.filter(func(t): return str(t).begins_with("Revendre "))
	check(revendre.size() == 1 and apres.find(revendre[0]) == achats.size() and str(revendre[0]).begins_with("Revendre la "), "le bouton pour revendre vient après tous les achats, avec le nom de l'objet : %s" % str(revendre))
	check(apres.filter(func(t): return not str(t).begins_with("Revendre ")) == avant, "rien d'autre ne bouge : %s" % str(apres))
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
