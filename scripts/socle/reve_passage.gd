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

static func human_arguments(config: ConfigFile, path: String) -> PackedStringArray:
	var args: PackedStringArray = ["--", "--passage-file=" + path]
	var server_url := str(config.get_value("installation", "server_url", ""))
	if server_url.begins_with("wss://"):
		args.append("--join=" + server_url)
		var ca := str(config.get_value("installation", "tls_ca", ""))
		if not ca.is_empty(): args.append("--tls-ca=" + ca)
	return args

static func launch(subject: String, appearance: Dictionary, pensionnaire := "") -> bool:
	var config := ConfigFile.new()
	if config.load(CONFIG) != OK or not available(config):
		return false
	if pensionnaire.is_empty():
		pensionnaire = OS.get_environment("SMARVES_PENSIONNAIRE")
	var value := descriptor(subject, appearance, pensionnaire)
	var filename := "user://reve_passage_" + str(value.nonce) + ".json"
	var file := FileAccess.open(filename, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	file.close()
	var executable := str(config.get_value("installation", "executable"))
	if not pensionnaire.is_empty() and not OS.get_environment("SMARVES_PILOTE_JETON").is_empty():
		var server_url := str(config.get_value("installation", "server_url", ""))
		if not server_url.begins_with("wss://"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
			return false
		# Le pilote prend le relais à la frontière de son prochain geste, sans deux lecteurs de commandes.
		(Engine.get_main_loop() as SceneTree).root.set_meta("reve_pilot_handoff", {"executable":executable,"path":ProjectSettings.globalize_path(filename),"server_url":server_url,"ca":str(config.get_value("installation","tls_ca",""))})
		return true
	var args := human_arguments(config, ProjectSettings.globalize_path(filename))
	var pid := OS.create_process(executable, args)
	if pid < 0:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
		return false
	# Smarves reste ouvert au Dessous : si le receveur échoue, la Porte fonctionne toujours.
	return true


## Appelé entre deux gestes par le pilote réseau. Les secrets restent dans l'environnement hérité.
static func transfer_pilot(owner: Node) -> bool:
	var tree := owner.get_tree()
	if not tree.root.has_meta("reve_pilot_handoff"):
		return false
	var handoff: Dictionary = tree.root.get_meta("reve_pilot_handoff")
	tree.root.remove_meta("reve_pilot_handoff")
	var previous_url := OS.get_environment("REVE_SERVER_URL")
	var previous_ca := OS.get_environment("REVE_TLS_CA")
	OS.set_environment("REVE_SERVER_URL",str(handoff.server_url))
	OS.set_environment("REVE_TLS_CA",str(handoff.ca))
	var pid := OS.create_process(str(handoff.executable),["--headless","--","--pensionnaire","--passage-file="+str(handoff.path)])
	OS.set_environment("REVE_SERVER_URL",previous_url)
	OS.set_environment("REVE_TLS_CA",previous_ca)
	if pid < 0:
		DirAccess.remove_absolute(str(handoff.path))
		return false
	var deadline := Time.get_ticks_msec()+30000
	var ready := str(handoff.path)+".ready"
	while not FileAccess.file_exists(ready) and OS.is_process_running(pid) and Time.get_ticks_msec()<deadline:
		await tree.create_timer(0.1).timeout
	if not FileAccess.file_exists(ready):
		if OS.is_process_running(pid): OS.kill(pid)
		DirAccess.remove_absolute(str(handoff.path))
		return false
	DirAccess.remove_absolute(ready)
	# Garder la tâche parente vivante : GitHub ne doit pas tuer le Rêve comme processus orphelin.
	while OS.is_process_running(pid):
		await tree.create_timer(1.0).timeout
	return true

