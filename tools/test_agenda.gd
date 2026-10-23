extends SceneTree
## Vérifie l'agenda de la semaine sans affichage : godot --headless --path . -s tools/test_agenda.gd
## Le dimanche 18 octobre 2026 au soir : le tournoi fermé du mercredi, la partie de poker du vendredi,
## le loto du samedi, puis le dimanche 25 la partie de 11 h, le premier match de l'Étoile à 15 h et la
## mercato (les dernières enchères du samedi soir, seize joueurs mis en vente le dimanche à 17 h) ; le règlement des paris quand un ticket est ouvert ; une activité qui inscrit
## ses rendez-vous remplace la lecture d'ici ; le carnet déplie la semaine.

const TMP := "user://test_agenda/"

var fails := 0
var t := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


static func local(y: int, mo: int, d: int, h: int, mi := 0) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": y, "month": mo, "day": d, "hour": h, "minute": mi, "second": 0})


func _init() -> void:
	await process_frame
	var foot: Node = root.get_node("Football")
	var agenda: Node = root.get_node("Agenda")
	var paris: Node = root.get_node("Paris")
	DirAccess.make_dir_recursive_absolute(TMP)
	foot.dossier = TMP
	foot.effacer()
	paris.dossier = ""
	paris.effacer()
	t = local(2026, 10, 18, 20)
	foot.regler_horloge(func(): return t)
	# Un deuxième club au championnat : la commune d'essai et son terrain.
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()

	# Les dates à la française.
	check(agenda.date(local(2026, 10, 21, 20, 30)) == "mercredi 21 octobre", "mercredi 21 octobre")
	check(agenda.heure(local(2026, 10, 21, 20, 30)) == "20 h 30" and agenda.heure(local(2026, 10, 25, 15)) == "15 h", "20 h 30, 15 h")
	check(agenda.date(local(2026, 11, 1, 11)) == "dimanche 1er novembre", "le 1er du mois")
	check(agenda.jour_relatif(local(2026, 10, 19, 9), t) == "demain", "demain")

	# Les jours de la semaine : le samedi qui vient, et le samedi d'après.
	var sam: Array = agenda.occurrences(6, 20, 30, t, t + 14 * 86400)
	check(sam == [local(2026, 10, 24, 20, 30), local(2026, 10, 31, 20, 30)], "deux samedis en quinze jours")
	check(agenda.occurrences(0, 11, 0, local(2026, 10, 25, 11), local(2026, 10, 25, 12)) == [local(2026, 10, 25, 11)], "un rendez-vous à l'instant même compte")

	# La semaine du dimanche 18 au soir.
	var s: Array = agenda.semaine()
	var titres: Array = s.map(func(r): return r.titre)
	print("        ", titres)
	check(s.size() == 7, "sept rendez-vous dans la semaine")
	check(s[0].titre == "Le tournoi fermé de poker" and s[0].quand == local(2026, 10, 21, 20, 30) and s[0].annonce, "d'abord le tournoi fermé, mercredi 20 h 30, annoncé")
	check(s[1].titre == "La partie de poker du vendredi" and s[1].quand == local(2026, 10, 23, 13, 30), "puis le poker du vendredi, celui du panneau")
	check(s[2].titre == "Le grand tirage du samedi" and s[2].quand == local(2026, 10, 24, 20, 30) and s[2].lieu.contains("Rabelais"), "le loto du samedi soir, salle Rabelais")
	check(s[4].quand == local(2026, 10, 25, 11), "dimanche 11 h, la partie de poker")
	var match_: Array = s.filter(func(r): return r.activite == "football")
	check(match_.size() == 1 and match_[0].quand == local(2026, 10, 25, 15) and not match_[0].annonce, "le match du dimanche 25 à 15 h, pour de vrai")
	check(match_.size() == 1 and match_[0].titre.contains("–") and match_[0].titre.contains(foot.clubs.smarves.nom), "c'est le match du club de Smarves : %s" % (match_[0].titre if match_.size() else ""))
	var mercato: Array = s.filter(func(r): return r.activite == "mercato")
	check(mercato.size() == 2 and mercato[0].titre == "Dernières enchères de la semaine" and mercato[0].quand == local(2026, 10, 24, 22),
		"les dernières enchères de la semaine, samedi 22 h")
	check(mercato.size() == 2 and mercato[1].titre == "Quarante joueurs mis aux enchères" and mercato[1].quand == local(2026, 10, 25, 17),
		"seize joueurs mis aux enchères dimanche à 17 h")
	check(agenda.prochains(3).size() == 3 and agenda.prochains(3)[0].titre == "Le tournoi fermé de poker", "les trois prochains, pour la page du carnet")

	# Pendant le tournoi : il est en cours, et reste en tête.
	t = local(2026, 10, 21, 21)
	s = agenda.semaine()
	check(s[0].titre == "Le tournoi fermé de poker" and agenda.en_cours(s[0], t), "mercredi 21 h : le tournoi est en cours")
	check(s.filter(func(r): return r.activite == "poker" and r.titre.contains("tournoi")).size() == 2 and s[-1].quand < local(2026, 10, 29, 0),
		"et celui du mercredi suivant ferme la semaine, jusqu'au 28 au soir")

	# Un ticket ouvert : son règlement le dimanche à 17 h.
	t = local(2026, 10, 22, 12)
	paris.tickets.append({"s": 1, "j": 1, "n": 0, "g": 0, "choix": {}, "mise": 10, "cote": 2.0, "etat": "ouvert", "gain": 0, "quand": t})
	var reg: Array = agenda.semaine().filter(func(r): return r.activite == "paris")
	check(reg.size() == 1 and reg[0].quand == local(2026, 10, 25, 17) and reg[0].titre == "Règlement de votre ticket", "le ticket se règle dimanche à 17 h")
	paris.effacer()

	# Une activité inscrit ses rendez-vous : elle remplace la lecture d'ici.
	agenda.inscrire("mercato", func(a, b):
		return [{"quoi": "Fin des enchères du mercato", "ou": "au stade municipal", "quand": local(2026, 10, 24, 18), "activite": "mercato"}])
	s = agenda.semaine()
	check(s.filter(func(r): return r.activite == "mercato").map(func(r): return r.titre) == ["Fin des enchères du mercato"], "une source inscrite remplace la lecture d'ici")
	check(s.all(func(r): return r.id != "" and r.has("duree") and r.has("annonce")), "un rendez-vous inscrit est complété")
	agenda.retirer("mercato")
	check(agenda.semaine().any(func(r): return r.titre == "Dernières enchères de la semaine"), "retiré, la lecture d'ici revient")

	# Le carnet : la page de droite et la feuille de la semaine se remplissent sans erreur.
	t = local(2026, 10, 18, 20)
	var carnet: Node = root.get_node("Carnet")
	carnet.call("_show_sheet", true, "agenda")
	await process_frame
	var sheet: Control = carnet.get("_sheet")
	check(sheet.visible and _texte(carnet.get("_sheet_box")).contains("Le grand tirage du samedi"), "la feuille de la semaine montre le loto")
	check(_texte(carnet.get("_sheet_box")).contains("Mercredi 21 octobre"), "un jour par paragraphe")
	check(_texte(carnet.get("_sheet_box")).contains("Ambassadeurs"), "en bas, ce qui se joue tous les jours : le poker des Ambassadeurs")
	carnet.call("_show_sheet", false, "agenda")
	await process_frame
	carnet.call("ouvrir_onglet", "aujourdhui")
	await process_frame
	check(_texte(carnet.get("_right")).contains("Prochains rendez-vous\n"), "« Aujourd'hui » : la page de droite dit les prochains rendez-vous")

	foot.regler_horloge(Callable())
	foot.effacer()
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _texte(n: Node) -> String:
	var out := ""
	for c in n.get_children():
		if c is Label:
			out += c.text + "\n"
		elif c is Button:
			out += c.text + "\n"
		out += _texte(c)
	return out
