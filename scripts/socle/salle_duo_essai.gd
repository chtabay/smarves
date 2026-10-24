class_name SalleDuoEssai
extends RefCounted
## Le faux serveur des salles à deux (socle 1.24), pour essayer une salle sans compte ni réseau : les mêmes
## règles que la fonction casino d'Addict (supabase/functions/casino/smarves-salles.js), recopiées ici. On
## le passe à SalleDuo par `essai`, avec le joueur qu'on fait jouer ; deux SalleDuo qui partagent le même
## faux serveur sont deux joueurs. Avec `fichier` (un chemin user://), l'état se garde dans un fichier
## JSON : deux fenêtres du jeu sur la même machine jouent alors ensemble.
##
## Ce qui diffère du vrai : les tarifs (`tarifs`, 100 et 1 000 sans réglage), et la sortie, que le vrai
## serveur rejoue avec le moteur du jeu de la salle. Ici, `valider` la juge (un Callable qui reçoit le
## carnet et la variante, et rend vrai si les gestes sortent) ; sans lui, tout carnet non vide sort.

const ATTENTE := 20.0
const ABSENT := 6.0
const REPRISE := 120.0
const APPARIE := 60.0
const CARNET_OCTETS := 32768
const PLAQUE := 50

var lignes := {}
var fichier := ""
## { "commune:salle:variante": {entree, prime} } ; sinon ENTREE et PRIME.
var tarifs := {}
var valider: Callable
## L'heure du faux serveur, en secondes : celle de la machine, sauf si un essai la règle (avancer le temps).
var maintenant := -1.0

const ENTREE := 100
const PRIME := 1000


func heure() -> float:
	return maintenant if maintenant >= 0.0 else Time.get_unix_time_from_system()


## Une demande, comme Compte.casino : {code, corps}. `joueur` : {id, nom}.
func appeler(joueur: Dictionary, action: String, args: Dictionary) -> Dictionary:
	_lire()
	var r := _jouer(joueur, action, args.duplicate(true))
	_ecrire()
	return r


static func membre_de(id: String) -> String:
	return ("smarves-lieu:" + id).sha256_text().left(12)


func _lire() -> void:
	if fichier != "" and FileAccess.file_exists(fichier):
		var d = JSON.parse_string(FileAccess.get_file_as_string(fichier))
		lignes = d if d is Dictionary else {}


func _ecrire() -> void:
	if fichier != "":
		var f := FileAccess.open(fichier, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(lignes))


static var _re := {}


static func _ok(motif: String, s: String) -> bool:
	if not _re.has(motif):
		_re[motif] = RegEx.create_from_string(motif)
	return (_re[motif] as RegEx).search(s) != null


func _tarif(cle: String) -> Dictionary:
	var t: Dictionary = tarifs.get(cle, {})
	return {"entree": int(t.get("entree", ENTREE)), "prime": int(t.get("prime", PRIME))}


func _cle(commune, salle, variante) -> String:
	if not _ok("^[a-z_][a-z0-9_]{0,47}$", str(commune)) or not _ok("^[a-z_][a-z0-9_]{0,47}$", str(salle)) \
			or not _ok("^[a-z0-9_]{1,24}$", str(variante)):
		return ""
	return "%s:%s:%s" % [commune, salle, variante]


func _hasard(n: int) -> String:
	var s := ""
	for i in n:
		s += "abcdefghijklmnopqrstuvwxyz0123456789"[randi() % 36]
	return s


static func _autre(r: String) -> String:
	return "B" if r == "A" else "A"


static func _role(S, pid: String) -> String:
	if S == null:
		return ""
	return "A" if S.A.pid == pid else ("B" if S.B.pid == pid else "")


static func _taille(v) -> int:
	return JSON.stringify(v).to_utf8_buffer().size()


func _constater(S: Dictionary, role: String, now: float) -> void:
	var p: Dictionary = S[role]
	if not p.parti and now - float(p.vu) > REPRISE:
		p.parti = true
	if p.parti and not S.fini:
		var o: Dictionary = S[_autre(role)]
		if o.paye and not o.parti and not o.report:
			o.report = true
	if S.A.parti and S.B.parti:
		S.ferme = true


func _encaisser(S: Dictionary, role: String, J: Dictionary) -> void:
	if S[role].report and not S[role].get("reporte", false):
		J.reports[S.cle] = int(J.reports.get(S.cle, 0)) + 1
		S[role].reporte = true
		S[role].paye = false


func _quitter_salon(S, role: String, J: Dictionary, now: float) -> void:
	if S == null:
		return
	_constater(S, _autre(role), now)
	_encaisser(S, role, J)
	S[role].parti = true
	_constater(S, role, now)
	if J.place is Dictionary and J.place.get("salon", "") == S.id:
		J.place = null


func _vue(S: Dictionary, role: String, now: float, J: Dictionary) -> Dictionary:
	var o: Dictionary = S[_autre(role)]
	var t := _tarif(S.cle)
	return {
		"salon": S.id, "canal": S.canal, "role": role, "commune": S.commune, "salle": S.salle, "variante": S.variante,
		"entree": t.entree, "prime": t.prime, "deja_gagnee": J.primes.has(S.cle),
		"moi": {"paye": S[role].paye},
		"partenaire": {"nom": o.nom, "membre": o.membre, "paye": o.paye, "parti": o.parti,
			"present": not o.parti and now - float(o.vu) <= ABSENT},
		"partie": S.A.paye and S.B.paye and not S.fini, "fini": S.fini, "carnet": S.carnet,
	}


func _erreur(code: int, texte: String) -> Dictionary:
	return {"code": code, "corps": {"error": texte}}


func _jouer(joueur: Dictionary, action: String, args: Dictionary) -> Dictionary:
	var now := heure()
	var pid := str(joueur.id)
	var nom := str(joueur.get("nom", "Joueur"))
	var jid := "duo:joueur:" + pid
	var J: Dictionary = lignes.get(jid, {"place": null, "primes": {}, "reports": {}})
	lignes[jid] = J

	if action == "salle.fiche" or action == "salle.plaque":
		var base := "%s:%s" % [args.get("commune", ""), args.get("salle", "")]
		if action == "salle.plaque":
			return {"code": 200, "corps": {"plaque": lignes.get("duo:plaque:" + base, {"liste": []}).liste}}
		var variantes := {}
		for v in args.get("variantes", []):
			var cle := base + ":" + str(v)
			var t := _tarif(cle)
			variantes[v] = {"nom": str(v), "entree": t.entree, "prime": t.prime, "gagnee": J.primes.has(cle), "reports": int(J.reports.get(cle, 0))}
		return {"code": 200, "corps": {"nom": str(args.get("salle", "")), "variantes": variantes, "place": J.place}}

	# Les lignes, comme lignesSalle : l'attente demandée (ou celle où l'on est), puis le salon.
	var cle_demandee := _cle(args.get("commune"), args.get("salle"), args.get("variante")) if action == "salle.rejoindre" else ""
	var qcle := cle_demandee
	if qcle == "" and J.place is Dictionary and J.place.has("attente") and action in ["salle.quitter", "salle.rejoindre"]:
		qcle = J.place.attente
	var Q = null
	if qcle != "":
		Q = lignes.get("duo:attente:" + qcle, {"file": [], "apparies": {}})
		lignes["duo:attente:" + qcle] = Q
	var sid := str(args.get("salon", ""))
	if not _ok("^[a-z0-9]{24}$", sid):
		sid = J.place.get("salon", "") if J.place is Dictionary else ""
		if sid == "" and Q != null and Q.apparies.has(pid):
			sid = Q.apparies[pid].salon
	var S = lignes.get("duo:salon:" + sid) if sid != "" else null
	var role := _role(S, pid)
	if role == "":
		S = null
	if S != null:
		_constater(S, _autre(role), now)

	if action == "salle.rejoindre":
		if cle_demandee == "":
			return _erreur(404, "Salle inconnue.")
		if S != null and S.cle == cle_demandee and not S.ferme and not S[role].parti:
			S[role].vu = now
			_encaisser(S, role, J)
			J.place = {"salon": S.id}
			Q.apparies.erase(pid)
			Q.file = Q.file.filter(func(x): return x.pid != pid)
			return {"code": 200, "corps": _vue(S, role, now, J)}
		if S != null:
			_quitter_salon(S, role, J, now)
		for k in Q.apparies.keys():
			if now - float(Q.apparies[k].quand) > APPARIE:
				Q.apparies.erase(k)
		Q.file = Q.file.filter(func(x): return x.pid != pid and now - float(x.vu) <= ATTENTE)
		var parts: PackedStringArray = cle_demandee.split(":")
		if not Q.file.is_empty():
			var a: Dictionary = Q.file.pop_front()
			var joueur_de := func(p: Dictionary) -> Dictionary:
				return {"pid": p.pid, "nom": p.nom, "membre": p.membre, "vu": now, "paye": false, "prime": false, "parti": false, "report": false}
			var N := {"id": _hasard(24), "canal": _hasard(32), "cle": cle_demandee, "commune": parts[0], "salle": parts[1],
				"variante": parts[2], "cree": now, "A": joueur_de.call(a),
				"B": joueur_de.call({"pid": pid, "nom": nom, "membre": membre_de(pid)}),
				"carnet": null, "fini": false, "grave": false, "ferme": false}
			lignes["duo:salon:" + N.id] = N
			Q.apparies[a.pid] = {"salon": N.id, "quand": now}
			J.place = {"salon": N.id}
			return {"code": 200, "corps": _vue(N, "B", now, J)}
		Q.file.append({"pid": pid, "nom": nom, "membre": membre_de(pid), "vu": now})
		J.place = {"attente": cle_demandee}
		var t := _tarif(cle_demandee)
		return {"code": 200, "corps": {"attente": true, "variante": parts[2], "entree": t.entree, "prime": t.prime, "deja_gagnee": J.primes.has(cle_demandee)}}

	if action == "salle.quitter":
		if J.place is Dictionary and J.place.has("attente") and Q != null:
			Q.file = Q.file.filter(func(x): return x.pid != pid)
		if S != null:
			_quitter_salon(S, role, J, now)
		J.place = null
		return {"code": 200, "corps": {"ok": true, "reports": J.reports}}

	if S == null:
		return _erreur(404, "Vous n’êtes pas dans ce salon.")
	var t := _tarif(S.cle)

	if action == "salle.battre":
		if S[role].parti or S.ferme:
			return {"code": 200, "corps": {"ferme": true}}
		S[role].vu = now
		J.place = {"salon": S.id}
		_encaisser(S, role, J)
		if role == "A" and args.has("carnet"):
			if _taille(args.carnet) > CARNET_OCTETS:
				return _erreur(413, "Le carnet est trop long.")
			S.carnet = args.carnet
		return {"code": 200, "corps": _vue(S, role, now, J)}

	if action == "salle.entrer":
		if S[role].parti or S.ferme:
			return _erreur(409, "Ce salon est fermé.")
		S[role].vu = now
		_encaisser(S, role, J)
		if S.fini:
			S.fini = false
			S.grave = false
			S.carnet = null
			for r in ["A", "B"]:
				S[r].paye = false
				S[r].prime = false
		var cout := 0
		if not S[role].paye:
			if int(J.reports.get(S.cle, 0)) > 0:
				J.reports[S.cle] = int(J.reports[S.cle]) - 1
				if J.reports[S.cle] == 0:
					J.reports.erase(S.cle)
			else:
				cout = t.entree
			S[role].paye = true
		var v := _vue(S, role, now, J)
		v.cout = cout
		return {"code": 200, "corps": v}

	if action == "salle.prime":
		if not S.A.paye or not S.B.paye:
			return _erreur(409, "La partie n’a pas commencé.")
		var carnet = args.get("carnet")
		if _taille(carnet) > CARNET_OCTETS:
			return _erreur(413, "Le carnet est trop long.")
		var sort: bool = valider.call(carnet, S.variante) if valider.is_valid() else (carnet is Array and not carnet.is_empty())
		if not sort:
			return _erreur(422, "Le serveur n’a pas retrouvé la sortie dans ces gestes.")
		S[role].vu = now
		S.fini = true
		var deja: bool = J.primes.has(S.cle) or S[role].prime
		var montant := 0 if deja else int(t.prime)
		if not deja:
			J.primes[S.cle] = now
		S[role].prime = true
		if not S.grave and montant > 0:
			S.grave = true
			var pl := "duo:plaque:%s:%s" % [S.commune, S.salle]
			var liste: Array = lignes.get(pl, {"liste": []}).liste
			liste.append({"noms": [S.A.nom, S.B.nom], "variante": S.variante, "quand": now})
			lignes[pl] = {"liste": liste.slice(-PLAQUE)}
		var v := _vue(S, role, now, J)
		v.merge({"paye": montant > 0, "deja": deja, "montant": montant})
		return {"code": 200, "corps": v}

	return _erreur(400, "Action inconnue.")
