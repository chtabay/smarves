extends SceneTree
## Vérifie la musique des lieux (Sfx.musique) sans affichage : godot --headless --path . -s tools/test_musique.gd
## Les thèmes du socle se chargent et bouclent, leur crédit est prêt pour l'écran titre ; un thème monte pendant que l'autre descend, puis s'arrête ;
## redemander le thème en cours ne fait rien ; un thème inconnu est ignoré ; le casino fait taire la musique
## et le village ramène la ville ; un thème retrouvé reprend où il en était ; la place et les trois socles
## des environs ont chacun leur thème.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_lancer.call_deferred()


func _attendre(s: float) -> void:
	await create_timer(s).timeout


func _jouent(sfx: Node) -> Array:
	var out := []
	for p in sfx._lecteurs:
		if p.playing:
			out.append(str(p.get_meta("theme", "")))
	return out


func _lancer() -> void:
	var sfx: Node = root.get_node("Sfx")
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.won = 0
	for nom in sfx.MUSIQUES:
		var c: String = sfx.MUSIQUES[nom]
		var flux = load(c)
		check(flux is AudioStreamOggVorbis and flux.get_length() > 40.0, "« %s » se charge (%.1f s)" % [c.get_file(), flux.get_length() if flux else 0.0])
		var f = sfx._flux_de(nom)
		check(f is AudioStreamOggVorbis and f.loop, "le thème « %s » boucle" % nom)
	check(sfx.CREDIT_MUSIQUE.contains("Kevin MacLeod") and sfx.CREDIT_MUSIQUE.contains("BY 4.0"), "le crédit de la musique est prêt pour l'écran titre")

	sfx.musique("titre")
	check(sfx.musique_courante == "titre" and _jouent(sfx) == ["titre"], "l'écran titre a son thème")
	await _attendre(sfx.FONDU + 0.4)
	var actif: AudioStreamPlayer = sfx._lecteurs[sfx._actif]
	check(is_equal_approx(actif.volume_db, sfx.MUSIQUE_DB), "le thème est monté à %.0f dB (%.1f)" % [sfx.MUSIQUE_DB, actif.volume_db])

	sfx.musique("ville")
	var deux := _jouent(sfx)
	deux.sort()
	check(deux == ["titre", "ville"], "pendant le fondu, l'un descend et l'autre monte (%s)" % [deux])
	await _attendre(sfx.FONDU + 0.4)
	check(_jouent(sfx) == ["ville"], "après le fondu, seule la ville joue (%s)" % [_jouent(sfx)])
	check(sfx._positions.has("titre"), "on retient où en était le thème de l'écran titre")

	var lecteur: AudioStreamPlayer = sfx._lecteurs[sfx._actif]
	sfx.musique("ville")
	check(sfx._lecteurs[sfx._actif] == lecteur and _jouent(sfx) == ["ville"], "redemander la ville ne relance rien")

	sfx.musique("pas_un_theme")
	check(sfx.musique_courante == "ville", "un thème inconnu est ignoré")

	sfx._positions["environs"] = 12.0
	sfx.musique("environs", 0.2)
	await _attendre(0.1)
	var env: AudioStreamPlayer = sfx._lecteurs[sfx._actif]
	check(env.get_meta("theme") == "environs" and env.get_playback_position() >= 11.9, "un thème retrouvé reprend où il en était (%.1f s)" % env.get_playback_position())

	sfx.set_ambience("casino")
	check(sfx.musique_courante == "", "au casino, la musique se tait")
	await _attendre(sfx.FONDU_SORTIE + 0.4)
	check(_jouent(sfx).is_empty(), "après le fondu, plus rien ne joue (%s)" % [_jouent(sfx)])
	sfx.set_ambience("village")
	check(sfx.musique_courante == "ville", "revenir au village ramène la ville")

	var main: GDScript = load("res://scripts/main.gd")
	check(main.lieu_des_environs(Vector3.ZERO) == "", "la place de la Mairie n'est pas aux environs")
	check(main.lieu_des_environs(Vector3(35, 0, 0)) == "", "la rue entre la place et le bois non plus")
	check(main.lieu_des_environs(Vector3(72, 0, 3)) == "bois", "le bois de Saint-Pierre est aux environs")
	check(main.lieu_des_environs(Vector3(-68, 0, -2)) == "moulin", "le Moulin des Dames aussi")
	check(main.lieu_des_environs(Vector3(4, 0, -74)) == "passelourdin", "et les rochers de Passelourdin")

	print("\n%s" % ("tout est bon" if fails == 0 else "%d échec(s)" % fails))
	quit(1 if fails else 0)
