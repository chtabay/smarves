extends RefCounted
## Option installée localement ; aucune annonce, aucune dépendance réseau au Dessous.
## Le compte devra être prouvé par OAuth avec la portée reve_hindoue dans le jeu receveur.
const CONFIG := "user://reve_hindoue.cfg"
const MAX_AGE := 120

static func descriptor(subject: String, appearance: Dictionary, pensionnaire := "") -> Dictionary:
	return {"version": 1, "origin": "smarves", "created_at": int(Time.get_unix_time_from_system()),
		"nonce": Crypto.new().generate_random_bytes(24).hex_encode(), "expected_subject": subject.left(64),
		"appearance": appearance.duplicate(true), "pensionnaire": pensionnaire.left(64), "spawn": "porte_des_joints"}

static func available(config: ConfigFile) -> bool:
	var executable := str(config.get_value("installation", "executable", ""))
	return executable.is_absolute_path() and FileAccess.file_exists(executable)

static func launch(subject: String, appearance: Dictionary, pensionnaire := "") -> bool:
	var config := ConfigFile.new()
	if config.load(CONFIG) != OK or not available(config):
		return false
	var value := descriptor(subject, appearance, pensionnaire)
	var filename := "user://reve_passage_" + str(value.nonce) + ".json"
	var file := FileAccess.open(filename, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	file.close()
	var executable := str(config.get_value("installation", "executable"))
	var args: PackedStringArray = ["--", "--passage-file=" + ProjectSettings.globalize_path(filename)]
	var pid := OS.create_process(executable, args)
	if pid < 0:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
		return false
	# Smarves reste ouvert au Dessous : si le receveur échoue, la Porte fonctionne toujours.
	return true
