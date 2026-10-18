extends SceneTree
## Vérifie le poker à plusieurs sans réseau : godot --headless --path . -s tools/test_poker_multi.gd
## La table rejoue une suite de vues du serveur (tools/fixtures/poker_multi_vues.json, tirée du moteur
## de la fonction casino, dépôt chtabay/addict) : places autour de la sienne, donnes, tableau,
## abattage, et les crédits qui suivent les mises et les gains sans qu'on prenne rien à l'entrée.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var G: Node = root.get_node("Game")
	var MULTI: GDScript = load("res://scripts/jeux/poker_multi.gd")
	var TABLE: GDScript = load("res://scripts/jeux/poker_3d.gd")
	var vues: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/poker_multi_vues.json"))
	G.saving_enabled = false
	G.credits = 20000
	var won0: int = G.won
	var root3d := Node3D.new()
	root.add_child(root3d)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	var table: Node3D = TABLE.new()
	root3d.add_child(table)
	var p: PanelContainer = MULTI.new()
	p.hors_ligne = true
	table.attach(p)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(p)
	table.sit(cam)
	var compte := {"donnes": 0, "tableau": 0, "abattages": 0, "places": 0}
	p.hand_started.connect(func(): compte.donnes += 1)
	p.board_dealt.connect(func(c: Array): compte.tableau += c.size())
	p.showdown.connect(func(_w, _s, _a): compte.abattages += 1)
	p.lineup_changed.connect(func(_pl): compte.places += 1)
	var staked0: int = G.staked
	for x in vues:
		p.appliquer(x.v, x.action)
		if x.action == "s-asseoir":
			check(G.credits == 20000, "s'asseoir ne prend rien aux crédits")
			# Bastien s'est assis le premier (place 0 du serveur) : Paulette prend la chaise du Commandant.
			check(p.seated and p.my_seat == 1, "assise à la place 1 du serveur")
			check(p.seats[5].name == "Bastien", "Bastien juste à sa droite")
			check(p.seats[1].name == "Mme Duval", "Mme Duval à sa gauche")
			var noms: Array = p.seats.map(func(s): return s.name)
			check(not "Le Commandant" in noms, "le Commandant s'est levé")
		if p.in_hand and compte.get("encart", 0) == 0:
			var l: Array = p.encart_lignes()
			compte.encart = l.size()
			check(l.size() == 7 and "pot" in l[0] and "Bastien" in "".join(l) and "(donneur)" in "".join(l), "l'encart dit la donne : pot, six chaises, le donneur (%d lignes)" % l.size())
		for _f in 3:
			await process_frame
	check(compte.donnes >= 2, "deux donnes suivies (%d)" % compte.donnes)
	check(compte.abattages >= 1, "au moins une fin de donne montrée (%d)" % compte.abattages)
	check(compte.tableau >= 3, "le tableau retourné (%d cartes)" % compte.tableau)
	check(compte.places >= 1, "les figurants placés")
	check(not p.seated, "levé après « partir »")
	var lignes: Array = p.encart_lignes()
	check(lignes.size() >= 1 and "Vos crédits" in lignes[0], "l'encart commence par ses crédits")
	# Deux donnes perdues, 100 puis 2 000 engagés : les mises sont parties des crédits au fil du jeu.
	check(G.credits == 20000 - 2100, "les mises sont parties des crédits au fil des donnes (%d)" % G.credits)
	check(G.staked == staked0 + 2100 and G.won == won0, "misé 2 100, rien gagné (%d, %d)" % [G.staked - staked0, G.won - won0])
	# Les places tournent autour de la sienne : assis en 3, la place 1 du serveur est à l'écran en 4.
	p.my_seat = 3
	check(p.rel(1) == 4 and p.rel(3) == 0 and p.rel(2) == 5, "les places tournent autour du joueur")
	var c: Dictionary = MULTI.carte({"r": "10", "s": "♦"})
	check(c.r == 8 and c.s == 2, "une carte du serveur se lit comme une carte du jeu")
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
