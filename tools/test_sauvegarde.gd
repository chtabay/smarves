extends SceneTree
## Vérifie la sauvegarde en tiroirs sans affichage : godot --headless --path . -s tools/test_sauvegarde.gd
## Une partie à l'ancien format (un seul fichier smarves.save) migre sans perte vers le socle et le tiroir
## de Smarves, se relit à l'identique, et la dette se tient par prêteur. Tout se passe dans
## user://test_tiroirs/ ; le fichier des biens, qui ne bouge pas, est relu puis remis tel quel.

const SAUVEGARDE := preload("res://scripts/socle/sauvegarde.gd")
const DIR := "user://test_tiroirs/"

const ANCIENNE := {"credits": 4321, "won": 12345, "staked": 67890, "advances_left": 1, "debt": 4297,
	"loans_taken": 3, "peak": 9000, "welcomed": true}

var fails := 0
var game: Node


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	game = root.get_node("Game")
	game.saving_enabled = false
	_vider()
	_migration()
	_preteurs()
	_interets()
	_biens()
	_vider()
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _vider() -> void:
	SAUVEGARDE.effacer(DIR)
	if FileAccess.file_exists(DIR + "smarves.save.ancien"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "smarves.save.ancien"))
	DirAccess.make_dir_recursive_absolute(DIR)


## Une partie neuve en mémoire, comme au lancement.
func _neuve() -> void:
	game.credits = game.START_CREDITS
	game.won = 0
	game.staked = 0
	game.advances_left = game.MAX_ADVANCES
	game.debts = {}
	game.tiroirs = {}
	game.loans_taken = 0
	game.peak_credits = game.START_CREDITS
	game.welcomed = false


func _comme_avant(quoi: String) -> void:
	check(game.credits == 4321 and game.won == 12345 and game.staked == 67890, "%s : crédits, gagné, misé" % quoi)
	check(game.advances_left == 1 and game.loans_taken == 3 and game.peak_credits == 9000 and game.welcomed, "%s : avances, prêts, pic, accueil" % quoi)
	check(game.debt == 4297 and game.debt_of("smarves") == 4297 and game.debts.size() == 1, "%s : 4 297 dus au Crédit Smarvois" % quoi)


func _migration() -> void:
	FileAccess.open(DIR + "smarves.save", FileAccess.WRITE).store_string(JSON.stringify(ANCIENNE))
	_neuve()
	check(SAUVEGARDE.charger(game, DIR) == "migree", "l'ancien fichier est lu et migré")
	_comme_avant("après migration")
	check(FileAccess.file_exists(DIR + "socle.save") and FileAccess.file_exists(DIR + "communes/smarves.save"), "le socle et le tiroir de Smarves sont écrits")
	check(not FileAccess.file_exists(DIR + "smarves.save") and FileAccess.file_exists(DIR + "smarves.save.ancien"), "l'ancien fichier est gardé à côté, sous .ancien")
	var socle = JSON.parse_string(FileAccess.get_file_as_string(DIR + "socle.save"))
	check(socle.format == 1 and int(socle.bourse) == 4321 and int(socle.gagne) == 12345 and int(socle.dettes.smarves) == 4297, "le socle tient la bourse, la clé et la dette par prêteur")
	var tiroir = JSON.parse_string(FileAccess.get_file_as_string(DIR + "communes/smarves.save"))
	check(tiroir.commune == "smarves" and int(tiroir.tiroir.avances) == 1 and int(tiroir.tiroir.prets) == 3 and tiroir.tiroir.accueil == true, "le tiroir de Smarves tient les avances, les prêts et l'accueil")
	check(not tiroir.tiroir.has("credits") and not socle.has("welcomed"), "rien n'est rangé en double")
	_neuve()
	check(SAUVEGARDE.charger(game, DIR) == "tiroirs", "au lancement suivant, on lit les tiroirs")
	_comme_avant("relu des tiroirs")
	# Un ancien fichier qui reparaîtrait (copie à la main) ne passe plus devant les tiroirs.
	FileAccess.open(DIR + "smarves.save", FileAccess.WRITE).store_string(JSON.stringify({"credits": 1}))
	_neuve()
	check(SAUVEGARDE.charger(game, DIR) == "tiroirs" and game.credits == 4321, "les tiroirs l'emportent sur un ancien fichier")
	_vider()
	_neuve()
	check(SAUVEGARDE.charger(game, DIR) == "" and game.credits == game.START_CREDITS, "sans rien, on part du pécule")


func _preteurs() -> void:
	_neuve()
	game.credits = 0
	game.borrow(1000)
	game.borrow(2000, "essai")
	check(game.debt_of("smarves") == 1050 and game.debt_of("essai") == 2100 and game.debt == 3150, "chaque prêteur a sa dette, frais compris ; le total les additionne")
	game.debt += 100
	check(game.debt_of("smarves") == 1150 and game.debt_of("essai") == 2100, "Game.debt += va au prêteur de Smarves, comme avant")
	game.debt = game.debt - 1500
	check(game.debt_of("smarves") == 0 and game.debt_of("essai") == 1750 and game.debt == 1750, "une baisse plus grande que la dette smarvoise passe au prêteur suivant")
	game.tiroir("essai")["visites"] = 2
	SAUVEGARDE.ecrire(game, DIR)
	_neuve()
	SAUVEGARDE.charger(game, DIR)
	check(game.debts == {"essai": 1750} and int(game.tiroir("essai").get("visites", 0)) == 2, "dettes et tiroir d'une autre commune se relisent")
	check(game.repay(500, "essai") == 500 and game.debt_of("essai") == 1250, "on rembourse un prêteur nommé")
	game.debt = 0
	check(game.debts.is_empty(), "Game.debt = 0 solde tous les prêteurs")


func _interets() -> void:
	_neuve()
	game.credits = 100000
	game.debts = {"smarves": 1000, "essai": 2000}
	for i in game.INTEREST_EVERY:
		game.spend(10)
	check(game.debt_of("smarves") == 1030 and game.debt_of("essai") == 2060, "les intérêts courent pour chaque prêteur (3 % toutes les 20 mises)")


## Le fichier des biens ne bouge pas : il se relit à l'ancien format, puis la vraie partie est remise.
func _biens() -> void:
	var biens: Node = root.get_node("Biens")
	var path: String = biens.SAVE_PATH
	var garde = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify({"owned": {"smarvoise": 2, "dimanche": 1}, "worn": "dimanche",
		"driven": "", "bets": 7, "period_staked": 140, "tournees": 1, "reprises": 0, "recettes": 4, "since_reprise": 4,
		"total_rentes": 120, "total_charges": 12, "total_spent": 650}))
	biens.owned = {}
	biens._load()
	check(biens.count("smarvoise") == 2 and biens.worn == "dimanche" and biens.recettes == 4 and biens.total_spent == 650, "smarves_biens.save à l'ancien format se relit sans perte")
	if garde == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	else:
		FileAccess.open(path, FileAccess.WRITE).store_string(garde)
