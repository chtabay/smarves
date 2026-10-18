extends SceneTree
## Vérifie le voisinage sans réseau : godot --headless --path . -s tools/test_voisinage.gd
## Les rendez-vous du panneau (le prochain vendredi, le prochain dimanche), les noms au-dessus des
## portes, l'heure à la craie, et la vitrine qu'un joueur montre aux autres.

## Chargés après les autoloads, qu'ils nomment (Game, Biens, Compte).
var VOISINAGE: GDScript
var VILLAGE: GDScript
var TABLEAU: GDScript

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	VOISINAGE = load("res://scripts/socle/voisinage.gd")
	VILLAGE = load("res://scripts/village/village.gd")
	TABLEAU = load("res://scripts/socle/tableau.gd")
	_rendez_vous()
	_noms()
	_heure()
	_vitrine()
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _rendez_vous() -> void:
	# Le vendredi 16 octobre 2026 à midi : le poker du vendredi d'abord, celui du dimanche ensuite.
	var rv: Array = VOISINAGE.prochains_rendez_vous(1792152000)
	check(rv.size() == 2, "deux rendez-vous par semaine")
	check(rv[0].quand == 1792157400 and rv[0].quoi.ends_with("vendredi"), "vendredi midi : le poker de 13 h 30 le jour même")
	check(rv[1].quand == 1792321200, "puis celui du dimanche à 11 h")
	# Le vendredi à 14 h : la partie est commencée, le prochain vendredi est dans une semaine.
	rv = VOISINAGE.prochains_rendez_vous(1792159200)
	check(rv[0].quand == 1792321200 and rv[1].quand == 1792762200, "vendredi 14 h : dimanche, puis le vendredi suivant")
	# Le dimanche à 10 h : celui du jour d'abord.
	rv = VOISINAGE.prochains_rendez_vous(1792317600)
	check(rv[0].quand == 1792321200, "dimanche 10 h : la partie de 11 h")


func _noms() -> void:
	var g := func(n): return {"nom": n}
	check(VILLAGE._noms([g.call("Paulette")]) == "Paulette", "un voisin")
	check(VILLAGE._noms([g.call("Paulette"), g.call("Bastien")]) == "Paulette et Bastien", "deux voisins")
	check(VILLAGE._noms([g.call("A"), g.call("B"), g.call("C")]) == "A, B et C", "trois voisins")
	check(VILLAGE._noms([g.call("A"), g.call("B"), g.call("C"), g.call("D"), g.call("E")]) == "A, B et 3 autres", "beaucoup de voisins")


func _heure() -> void:
	check(TABLEAU._heure(1792157400) == "13 h 30", "13 h 30 à la craie")
	check(TABLEAU._heure(1792321200) == "11 h", "11 h, sans minutes")


func _vitrine() -> void:
	var v: Dictionary = VOISINAGE.vitrine()
	check(v.has("p_gagne") and v.has("p_dette") and v.p_logements is Array, "la vitrine porte le gain, la dette et les logements")
