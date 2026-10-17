@tool
extends EditorPlugin
## À chaque export, range dans le paquet res://version.json : le commit construit, lu dans .git, et
## la date. Le jeu le compare à l'étiquette « derniere-version » de GitHub (autoload Version). Le
## fichier n'existe que dans les exports : lancé depuis l'éditeur, le jeu ne se croit jamais en retard.

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = Estampille.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)


class Estampille extends EditorExportPlugin:
	func _get_name() -> String:
		return "SmarvesVersion"

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		var commit := Estampille.commit()
		if commit == "":
			push_warning("Smarves · version : commit introuvable dans .git, pas d'estampille.")
			return
		var texte := JSON.stringify({"commit": commit, "date": Time.get_datetime_string_from_system(true)})
		add_file("res://version.json", texte.to_utf8_buffer(), false)

	## Le commit de HEAD : détaché (le SHA lui-même), ou une branche, en fichier ou dans packed-refs.
	static func commit() -> String:
		var git := ProjectSettings.globalize_path("res://").path_join(".git")
		var head := FileAccess.get_file_as_string(git.path_join("HEAD")).strip_edges()
		if not head.begins_with("ref: "):
			return head if head.length() == 40 else ""
		var ref := head.trim_prefix("ref: ")
		var loose := FileAccess.get_file_as_string(git.path_join(ref)).strip_edges()
		if loose.length() == 40:
			return loose
		for ligne in FileAccess.get_file_as_string(git.path_join("packed-refs")).split("\n"):
			if ligne.ends_with(" " + ref):
				return ligne.get_slice(" ", 0)
		return ""
