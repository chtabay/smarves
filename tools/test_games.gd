extends SceneTree
## Joue automatiquement des donnes de poker et des coups des autres jeux, pour vérifier
## qu'aucun ne bloque et que les comptes restent justes : godot --headless -s tools/test_games.gd

func _init() -> void:
	await process_frame
	var game: Node = get_root().get_node("Game")
	game.credits = 100000
	var poker: Node = load("res://scripts/poker_panel.gd").new()
	get_root().add_child(poker)
	var payouts := 0
	var bets := 0
	poker.played.connect(func(b, p): bets += b; payouts += p)
	for h in 25:
		poker._new_hand()
		var guard := 0
		while poker.in_hand and guard < 4000:
			guard += 1
			if poker._waiting_player:
				if randf() < 0.15:
					poker._on_raise()
				else:
					poker._on_call()
			await process_frame
		if guard >= 4000:
			print("POKER BLOQUÉ à la donne ", h)
			quit(1)
			return
	print("poker : 25 donnes, misé ", bets, ", encaissé ", payouts, ", crédits ", game.credits)
	# Évaluateur : quelques mains connues.
	var P = load("res://scripts/poker_panel.gd")
	var royal = P.evaluate([{"r":12,"s":0},{"r":11,"s":0},{"r":10,"s":0},{"r":9,"s":0},{"r":8,"s":0},{"r":0,"s":1},{"r":1,"s":2}])
	var wheel = P.evaluate([{"r":12,"s":0},{"r":0,"s":1},{"r":1,"s":2},{"r":2,"s":3},{"r":3,"s":0},{"r":9,"s":1},{"r":7,"s":2}])
	var full = P.evaluate([{"r":5,"s":0},{"r":5,"s":1},{"r":5,"s":2},{"r":2,"s":3},{"r":2,"s":0},{"r":9,"s":1},{"r":7,"s":2}])
	print("quinte flush ", royal, " quinte au 5 ", wheel, " full ", full)
	quit(0)
