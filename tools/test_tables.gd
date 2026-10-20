extends SceneTree
## Vérifie qu'une commune inscrit ses propres jeux à côté de ceux du casino (socle 1.12, Tables.inscrire) :
## godot --headless --path . -s tools/test_tables.gd
## Un jeu inscrit se pose, se joue et entre dans une salle de jeu du socle comme un jeu du casino ; un nom
## mal écrit ou un panneau introuvable est refusé ; aucun jeu du socle ne peut être remplacé.

var Tables: GDScript
var Structures: GDScript
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	Tables = load("res://scripts/socle/tables.gd")
	Structures = load("res://scripts/socle/structures.gd")
	var socle: PackedStringArray = Tables.jeux()

	check(Tables.inscrire("essai:grand_hasard", {"panneau": "res://scripts/dice_panel.gd", "modele": "res://scripts/jeux/hasard_3d.gd",
		"emprise": Vector2(2.3, 1.4), "invite": "jouer au grand hasard", "titre": "Le grand hasard"}), "un jeu de commune s'inscrit")
	check(Tables.inscrire("essai:cartes", {"panneau": "res://scripts/blackjack_panel.gd"}), "un jeu sans table 3D s'inscrit aussi")
	check("essai:grand_hasard" in Tables.jeux() and Tables.jeux().size() == socle.size() + 2, "les jeux inscrits s'ajoutent à ceux du socle")
	check(Tables.a_une_table("essai:grand_hasard") and not Tables.a_une_table("essai:cartes"), "seul le jeu qui donne un modèle a une table 3D")
	check(Tables.emprise("essai:grand_hasard") == Vector2(2.3, 1.4), "l'emprise inscrite est rendue")
	check(Tables.fiche("essai:grand_hasard").titre == "Le grand hasard", "la fiche inscrite est rendue")

	var t: Node3D = Tables.table("essai:grand_hasard")
	check(t != null and t.has_method("attach"), "la table 3D du jeu inscrit se pose")
	var p: PanelContainer = Tables.panneau("essai:grand_hasard", "Grand hasard")
	check(p != null and p.has_signal("played"), "le panneau du jeu inscrit s'ouvre")
	if t:
		t.free()
	if p:
		p.free()

	# Les refus : nom sans commune, majuscules, panneau ou modèle introuvable, et pas de remplacement du socle.
	check(not Tables.inscrire("poker", {"panneau": "res://scripts/dice_panel.gd"}), "un jeu du socle ne se remplace pas (« poker » refusé)")
	check(not Tables.inscrire("Essai:Jeu", {"panneau": "res://scripts/dice_panel.gd"}), "un nom en majuscules est refusé")
	check(not Tables.inscrire("essai:rien", {"panneau": "res://communes/essai/rien.gd"}), "un panneau introuvable est refusé")
	check(not Tables.inscrire("essai:faux", {"panneau": "res://scripts/dice_panel.gd", "modele": "res://nulle_part.gd"}), "un modèle introuvable est refusé")
	check(Tables.fiche("poker").panneau == "res://scripts/poker_panel.gd", "le poker du socle reste celui du casino")

	# Le manifeste : une salle de jeu peut nommer un jeu de commune, « <commune>:<nom> », pas un nom inconnu.
	var ok: PackedStringArray = Structures.verifier([{"type": "salle_jeu", "id": "s", "nom": "S", "jeux": ["poker", "essai:grand_hasard"]}])
	check(ok.is_empty(), "une salle de jeu nomme un jeu de commune : %s" % [ok])
	var ko: PackedStringArray = Structures.verifier([{"type": "salle_jeu", "id": "s", "nom": "S", "jeux": ["bonneteau", "Essai:X"]}])
	check(ko.size() == 2, "un jeu inconnu sans commune est refusé : %s" % [ko])

	print("\n%d échec(s)" % fails)
	quit(1 if fails else 0)
