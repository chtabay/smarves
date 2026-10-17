extends SceneTree
## Vérifie la comparaison des versions, sans réseau : godot --headless --path . -s tools/test_version.gd
## Une réponse de GitHub (les commits de l'étiquette « derniere-version ») est confrontée au commit
## local : à jour, en retard (avec les nouveautés depuis), ou si loin que le commit local n'y est plus.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _commit(sha: String, message: String) -> Dictionary:
	return {"sha": sha, "commit": {"message": message}}


func _init() -> void:
	await process_frame
	var v: Node = root.get_node("Version")
	check(v.etat == "", "aucune lecture sans estampille ni sous -s")
	var commits := [
		_commit("c".repeat(40), "Bienvenue : la direction « La Vienne » (#70)\n\nCorps du message."),
		_commit("b".repeat(40), "Merge branch 'main' into x"),
		_commit("a".repeat(40), "Place : l'encart se replie (#68)"),
		_commit("9".repeat(40), "Plus ancien"),
	]
	v.locale = "c".repeat(40)
	v.comparer(commits)
	check(v.etat == "a_jour" and not v.disponible(), "même commit : à jour")
	v.locale = "9".repeat(40)
	v.comparer(commits)
	check(v.disponible() and v.distante == "c".repeat(40), "commit plus ancien : nouvelle version")
	check(v.nouveautes == ["Bienvenue : la direction « La Vienne »", "Place : l'encart se replie"],
		"nouveautés : titres seuls, sans numéro de PR ni fusion, arrêtées au commit local")
	v.locale = "0".repeat(40)
	v.comparer(commits)
	check(v.disponible() and v.nouveautes.size() == 3, "commit local hors de la liste : tout est nouveau")
	check(v.adresse_telechargement().begins_with("https://github.com/chtabay/smarves/releases/"), "téléchargement sur la Release")
	print("\n%s" % ("TOUT EST BON" if fails == 0 else "%d ÉCHEC(S)" % fails))
	quit(1 if fails else 0)
