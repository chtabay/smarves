extends SceneTree
## Vérifie le journal intime de la fiche « Mon pensionnaire » (autoload Pensionnaire) sans réseau :
## godot --headless --path . -s tools/test_pensionnaire.gd
## Seuls les réveils faits, avec quelques lignes écrites, deviennent des pages ; datées à l'heure de Paris.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var P: Node = root.get_node("Pensionnaire")
	var t := 1761379200  # 25/10/2026 08h00 UTC
	var journal := [
		{"quand": t, "motif": "evenement:match:2026-10-25", "statut": "fait", "intime": "  J'ai eu peur du noir.  "},
		{"quand": t - 60, "motif": "evenement:match:2026-10-25", "statut": "fait", "intime": null},
		{"quand": t - 120, "motif": "evenement:match:2026-10-25", "statut": "fait"},
		{"quand": t - 180, "motif": "evenement:loto:2026-10-24", "statut": "erreur", "intime": "perdu"},
		{"quand": t - 240, "motif": "session", "statut": "fait", "intime": "Rien à dire."},
	]
	var pages: Array = P.entrees_intimes(journal, 3600)
	check(pages.size() == 2, "deux pages : ni réveil muet, ni erreur")
	check(pages[0].texte == "J'ai eu peur du noir.", "le texte, sans les blancs autour")
	check(pages[0].tete == "25/10 09h00 · match du dimanche", "daté à l'heure dite, avec l'événement")
	check(pages[1].tete.ends_with("passage au village"), "hors événement : un passage au village")
	check(P.entrees_intimes([], 0).is_empty(), "sans réveil, pas de page")
	print("%d échec(s)" % fails)
	quit(1 if fails else 0)
