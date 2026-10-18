extends Node
## Le football de la Vienne (autoload « Football ») : une pyramide de divisions à huit clubs, à la
## Hattrick, qui lit les terrains du registre des structures (docs/SUITE.md, section 6). Toute commune
## qui déclare un terrain (« terrain_foot ») a un club, qui entre dans la division la plus basse à la
## saison suivante ; les places vides sont tenues par des clubs invités, des communes réelles de la
## Vienne sans paquet (jamais une commune développée : sans terrain, pas de club). Le premier de chaque groupe monte, les deux derniers descendent dans les deux
## groupes fils. Le championnat vit sur le calendrier réel : un match le dimanche à 15 h, quatorze
## journées puis une semaine de trêve et une de mercato, trois saisons par an. Un résultat ne dépend
## que d'une graine (saison, journée, clubs) et des consignes prises avant le coup d'envoi : tout le
## monde calcule le même, hors ligne : le match est joué minute par minute (FootMatch, repris du
## Vestiaire) avec les effectifs de la saison, et son score est le résultat officiel.
##
## Les consignes (formation, mentalité, pressing) sont la seule chose qu'un joueur change au
## championnat, et elles entrent dans la graine : pour que le résultat reste commun, elles sont tenues
## au serveur (fonctions public.smarves_consignes et smarves_consigne_poser, supabase/migrations) et
## lues au lancement. Une consigne posée sans compte reste « locale » : le jeu la garde, la montre
## comme telle, et l'envoie dès que le joueur se connecte, si le coup d'envoi n'est pas passé.

## La pyramide a changé (une saison s'est finie, un club est entré).
signal change

## L'effectif d'un club pour une saison : deux gardiens, six défenseurs, six milieux, quatre attaquants,
## tirés de la graine du club et de la saison ; des noms inventés, combinés sans viser personne.
const EFFECTIF := [["G", 2], ["D", 6], ["M", 6], ["A", 4]]
const PRENOMS := ["Adrien", "Alban", "Alexis", "Amaury", "Anselme", "Arno", "Aurèle", "Bastien", "Benoît", "Bertrand",
	"Bruno", "Cédric", "Célestin", "Clément", "Corentin", "Damien", "Denis", "Dorian", "Edgar", "Élie",
	"Émile", "Enzo", "Éric", "Étienne", "Fabien", "Félix", "Firmin", "Florent", "Gaël", "Gaspard",
	"Gilles", "Gustave", "Hugo", "Ilan", "Isaac", "Jasper", "Joachim", "Jonas", "Jules", "Kilian",
	"Léandre", "Léon", "Loïc", "Lucien", "Malo", "Marius", "Mathis", "Maxence", "Milo", "Nathan",
	"Nils", "Noé", "Octave", "Olivier", "Oscar", "Pablo", "Pascal", "Quentin", "Rafael", "Rémi",
	"Romain", "Ruben", "Sacha", "Samir", "Simon", "Stan", "Sylvain", "Théo", "Thibault", "Timéo",
	"Tristan", "Ugo", "Valentin", "Victor", "Willem", "Xavier", "Yanis", "Yohan", "Zacharie", "Ziad",
	"Kofi", "Moussa", "Idrissa", "Tomás", "Matteo", "Luka", "Jens", "Sören", "Iker", "Davide"]
const NOMS := ["Aubrac", "Barneville", "Belcastel", "Bérard", "Boisseau", "Brémond", "Carvin", "Castagné", "Chabrol", "Chauvelin",
	"Cordier", "Courtil", "Dalbret", "Daumas", "Delorme", "Desvignes", "Dorval", "Duclair", "Escoffier", "Faverge",
	"Fenouil", "Flamand", "Fourcade", "Gaillac", "Garrigou", "Gauvrit", "Guérande", "Hallier", "Hébrard", "Jaouen",
	"Joubert", "Kerlaz", "Labarthe", "Lacombe", "Lagarde", "Lamothe", "Larcher", "Lebrun", "Lemarié", "Loubière",
	"Malaurie", "Marceau", "Maréchal", "Mazière", "Méjean", "Montel", "Morvan", "Nadeau", "Navarre", "Noblet",
	"Ollivier", "Orsini", "Pagès", "Perrault", "Peyrol", "Pichon", "Plantier", "Quéré", "Rabier", "Raynal",
	"Renaudin", "Rivière", "Rochette", "Roustan", "Sabatier", "Saulnier", "Ségalen", "Solère", "Tardieu", "Tessier",
	"Thouvenel", "Trémolet", "Vachon", "Valette", "Vasseur", "Verdier", "Vidalenc", "Villard", "Yvinec", "Zaragoz",
	"Abadie", "Bakary", "Diarrao", "Ekwalla", "Fonsagrives", "Haddadi", "Kabila", "Mbango", "Ndoumbé", "Okafar",
	"Brandvold", "Halvard", "Iturbe", "Lindqvar", "Moravec", "Ostrovan", "Pellegrina", "Sandoret", "Torvik", "Valdemar"]

## Le premier dimanche de la première saison, à 15 h locale, et la longueur d'une saison en semaines.
const EPOQUE := {"year": 2026, "month": 10, "day": 25}
const HEURE_COUP_ENVOI := 15
const JOURNEES := 14
const SEMAINES_PAR_SAISON := 16
const TAILLE := 8
const MONTENT := 1
const DESCENDENT := 2
## Le fichier de la pyramide (dans le dossier des greffes, à côté du catalogue).
const FICHIER := "football.json"

## Les noms d'un club invité, tirés de la graine de sa commune, et des paires de couleurs.
const NOMS_INVITES := ["Union sportive %s", "Étoile sportive %s", "Avenir %s", "Jeunesse sportive %s", "Football-club %s", "Espérance %s", "Entente sportive %s", "Olympique %s"]
const COULEURS := [["#1b3c8c", "#f2c94c"], ["#a3192e", "#ffffff"], ["#0f6b3f", "#ffffff"], ["#2a8fd1", "#0b2340"], ["#5b2a86", "#e6d8f5"],
	["#f07a1a", "#1a1a1a"], ["#111111", "#e8e8e8"], ["#7a1f3d", "#f4d6b0"], ["#e6c229", "#123a6b"], ["#2b2b2b", "#d23b2b"], ["#3d7a2a", "#f2e6c9"], ["#c8102e", "#0e2b5c"]]

## La saison en cours (1 au départ) et la pyramide : niveaux[n] est la liste des groupes du niveau n
## (le niveau 0 est le haut), un groupe est une liste d'ids de clubs. clubs : id -> {nom, court,
## couleurs, commune, insee, invite}. historique : [{saison, champion, montes, descendus}].
var saison := 1
var niveaux: Array = []
var clubs := {}
var historique: Array = []
## Les consignes prises avant un match : "saison/journee/club" -> {formation, mentalite, pressing}, toujours
## ces trois clés dans cet ordre (consigne()) : elles entrent telles quelles dans la graine.
var decisions := {}
## Les consignes de cet appareil que le serveur n'a pas encore : clé -> true. Le tableau le dit.
var locales := {}
## Qui a posé chaque consigne lue au serveur : clé -> nom du joueur.
var auteurs := {}
## « » tant que rien n'est lu, puis « lecture », « ok » ou « hors_ligne ».
var consignes_etat := ""
## Où lire et écrire la pyramide ; un test le déplace. « » : rien n'est écrit.
var dossier := Communes.GREFFES
var _horloge: Callable = Callable()
## Les matchs déjà joués et les effectifs déjà tirés, en mémoire : tout se recalcule à l'identique.
var _matchs := {}
var _effectifs := {}


func _ready() -> void:
	# Les tests et les captures partent d'une pyramide vide, sans toucher au fichier du joueur.
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	charger()
	Registre.change.connect(actualiser)
	actualiser()
	# Le compte (autoload Compte) arrive après Football dans l'arbre : on l'attend une image.
	(func():
		lire_consignes()
		var compte := _compte()
		if compte != null:
			compte.change.connect(func():
				if compte.etat == "a_jour" and not locales.is_empty():
					envoyer_locales())).call_deferred()


# ---------------------------------------------------------------- le calendrier réel

## Les secondes écoulées « maintenant », en temps local (un test remplace l'horloge).
func maintenant() -> int:
	if _horloge.is_valid():
		return _horloge.call()
	return int(Time.get_unix_time_from_system()) + Time.get_time_zone_from_system().bias * 60


## Remplace l'horloge (essais) : une fonction qui rend des secondes locales, ou une Callable vide.
func regler_horloge(h: Callable) -> void:
	_horloge = h


## Le coup d'envoi de la journée j (1 à 14) de la saison s, en secondes locales.
static func coup_envoi(s: int, j: int) -> int:
	var semaine := (s - 1) * SEMAINES_PAR_SAISON + (j - 1)
	return Time.get_unix_time_from_datetime_dict({"year": EPOQUE.year, "month": EPOQUE.month, "day": EPOQUE.day,
		"hour": HEURE_COUP_ENVOI, "minute": 0, "second": 0}) + semaine * 7 * 86400


## Le début d'une saison : deux semaines avant son premier coup d'envoi (la trêve, puis le mercato,
## appartiennent à la saison qui s'ouvre : c'est là que les clubs nouveaux entrent).
static func debut(s: int) -> int:
	return coup_envoi(s, 1) - 2 * 7 * 86400


## La saison du calendrier à cet instant (1 avant l'époque), et la journée qui vient de se jouer
## (0 avant la première, 14 après la dernière).
static func saison_a(t: int) -> int:
	return maxi(1, 1 + int(floor(float(t - debut(1)) / (SEMAINES_PAR_SAISON * 7 * 86400))))


static func journee_jouee_a(t: int, s: int) -> int:
	var n := 0
	for j in range(1, JOURNEES + 1):
		if t >= coup_envoi(s, j):
			n = j
	return n


## Le prochain coup d'envoi après t : [saison, journee, secondes].
static func prochain_coup_envoi(t: int) -> Array:
	var s := saison_a(t)
	for j in range(1, JOURNEES + 1):
		if t < coup_envoi(s, j):
			return [s, j, coup_envoi(s, j)]
	return [s + 1, 1, coup_envoi(s + 1, 1)]


## Combien de journées de la saison en cours sont jouées, et où l'on en est (« treve » la semaine qui
## suit la dernière journée de la saison passée, « mercato » la semaine d'avant la première journée,
## « saison » sinon).
func journee_jouee() -> int:
	return journee_jouee_a(maintenant(), saison)


func periode() -> String:
	var t := maintenant()
	if saison_a(t) != saison:
		return "saison"
	var semaine := int(floor(float(t - debut(saison)) / (7 * 86400)))
	return "treve" if semaine == 0 else ("mercato" if semaine == 1 else "saison")


# ---------------------------------------------------------------- la pyramide

## Met la pyramide au jour du calendrier : chaque saison finie est close (montées, descentes), et les
## terrains nouveaux du registre reçoivent leur club à la saison suivante, tant qu'elle n'a pas
## commencé. À appeler à l'ouverture et quand le registre change ; sans effet si rien n'a bougé.
func actualiser() -> void:
	var bouge := false
	if niveaux.is_empty():
		_fonder()
		bouge = true
	var cible := saison_a(maintenant())
	while saison < cible:
		clore_saison()
		bouge = true
	if journee_jouee() == 0 and _accueillir():
		bouge = true
	if bouge:
		sauver()
		change.emit()


## Le premier groupe : les terrains du registre, complétés par des invités.
func _fonder() -> void:
	clubs = {}
	for e in Registre.de_type("terrain_foot"):
		_club_du_registre(e)
	var groupe: Array = clubs.keys()
	groupe.sort()
	niveaux = [[groupe]]
	_completer()


## Ferme la saison en cours : classements finaux, le premier de chaque groupe monte dans le groupe
## père, les deux derniers descendent dans les deux groupes fils. Puis la saison suivante s'ouvre.
func clore_saison() -> void:
	var finals := []
	for n in niveaux.size():
		var rangs := []
		for g in niveaux[n].size():
			rangs.append(classement(saison, n, g, JOURNEES).map(func(l): return l.club))
		finals.append(rangs)
	var champion: String = finals[0][0][0]
	var montes := []
	var descendus := []
	var suivants := []
	for n in niveaux.size():
		var groupes := []
		for g in niveaux[n].size():
			groupes.append(finals[n][g].duplicate())
		suivants.append(groupes)
	# Du bas vers le haut : les fils (niveau n+1, groupes 2g et 2g+1) envoient leur premier au père g,
	# le père envoie son 7e au fils 2g et son 8e au fils 2g+1.
	for n in range(niveaux.size() - 2, -1, -1):
		for g in niveaux[n].size():
			var pere: Array = suivants[n][g]
			for k in 2:
				var f: int = 2 * g + k
				if f >= suivants[n + 1].size():
					continue
				var fils: Array = suivants[n + 1][f]
				var monte: String = fils[0]
				var descend: String = pere[TAILLE - DESCENDENT + k]
				fils[0] = descend
				pere[TAILLE - DESCENDENT + k] = monte
				montes.append(monte)
				descendus.append(descend)
	historique.append({"saison": saison, "champion": champion, "montes": montes, "descendus": descendus})
	for n in suivants.size():
		for g in suivants[n].size():
			suivants[n][g].sort()
	niveaux = suivants
	saison += 1


## Les terrains du registre qui n'ont pas encore de club : un club chacun, dans la division la plus
## basse, à la place d'un invité ; quand il n'y a plus d'invité en bas, un niveau s'ouvre dessous.
## Un club dont la commune a disparu du registre reste : on ne raye pas un club du jour au lendemain.
func _accueillir() -> bool:
	var bouge := false
	for e in Registre.de_type("terrain_foot"):
		if clubs.has(e.commune):
			continue
		_club_du_registre(e)
		# Sa commune était invitée : le club de plein droit prend sa place, où qu'elle soit.
		var invite: String = "invite_" + str(e.insee)
		if clubs.has(invite):
			var p: Array = place_de(invite)
			var g: Array = niveaux[p[0]][p[1]]
			g[g.find(invite)] = e.commune
			clubs.erase(invite)
			bouge = true
			continue
		var place := _place_libre()
		if place.is_empty():
			niveaux.append([])
			for g in 1 << (niveaux.size() - 1):
				niveaux[-1].append([])
			place = _place_libre()
		var groupe: Array = niveaux[-1][place.groupe]
		if place.has("invite"):
			groupe[groupe.find(place.invite)] = e.commune
			clubs.erase(place.invite)
		else:
			groupe.append(e.commune)
		bouge = true
	if bouge:
		_completer()
		for n in niveaux.size():
			for g in niveaux[n]:
				g.sort()
	return bouge


## Une place pour un club nouveau au dernier niveau : un groupe incomplet, sinon un invité à remplacer.
func _place_libre() -> Dictionary:
	for g in niveaux[-1].size():
		if niveaux[-1][g].size() < TAILLE:
			return {"groupe": g}
	for g in niveaux[-1].size():
		for id in niveaux[-1][g]:
			if clubs[id].invite:
				return {"groupe": g, "invite": id}
	return {}


## Remplit chaque groupe à huit avec des invités : les communes réelles sans club les plus proches
## du centre des clubs du groupe (ou de Smarves, pour un groupe vide), dans un ordre stable.
func _completer() -> void:
	var prises := {}
	for id in clubs:
		prises[clubs[id].insee] = true
	for n in niveaux.size():
		for g in niveaux[n].size():
			var groupe: Array = niveaux[n][g]
			var centre := Vienne.centre(Communes.origine().insee) if Communes.origine() else Vector2.ZERO
			if not groupe.is_empty():
				centre = Vector2.ZERO
				for id in groupe:
					centre += Vienne.centre(clubs[id].insee)
				centre /= groupe.size()
			var candidates := Vienne.communes().filter(func(c): return not prises.has(str(c.insee)) and str(c.insee) != "86194" and Communes.par_insee(str(c.insee)) == null)
			candidates.sort_custom(func(a, b):
				var da: float = Vector2(a.centre[0], a.centre[1]).distance_squared_to(centre)
				var db: float = Vector2(b.centre[0], b.centre[1]).distance_squared_to(centre)
				return da < db if da != db else str(a.insee) < str(b.insee))
			var k := 0
			while groupe.size() < TAILLE and k < candidates.size():
				var id := _inviter(candidates[k])
				prises[str(candidates[k].insee)] = true
				groupe.append(id)
				k += 1


func _inviter(c: Dictionary) -> String:
	var insee := str(c.insee)
	var id := "invite_" + insee
	var h := Hasard.depuis(Hasard.graine("invite/" + insee))
	var nom: String = str(c.nom)
	var patron: String = NOMS_INVITES[h.entier(0, NOMS_INVITES.size() - 1)]
	var complement := ("d'%s" if nom.left(1).to_lower() in ["a", "e", "i", "o", "u", "y", "é", "h"] else "de %s") % nom
	var mots := PackedStringArray()
	for m in nom.replace("-", " ").split(" ", false):
		mots.append(m.left(1).to_upper())
	clubs[id] = {"nom": patron % complement, "court": "".join(mots).left(3).rpad(3, "V") if mots.size() < 3 else "".join(mots).left(3),
		"couleurs": COULEURS[h.entier(0, COULEURS.size() - 1)], "commune": "", "insee": insee, "invite": true}
	return id


func _club_du_registre(e: Dictionary) -> void:
	var champs: Dictionary = e.champs
	var nom := str(champs.get("club", e.nom))
	var court := str(champs.get("court", ""))
	if court == "":
		for m in nom.replace("-", " ").replace("'", " ").split(" ", false):
			if m.length() > 2:
				court += m.left(1).to_upper()
		court = court.left(3)
	var couleurs: Array = champs.get("couleurs", COULEURS[Hasard.graine(e.commune) % COULEURS.size()])
	clubs[e.commune] = {"nom": nom, "court": court, "couleurs": couleurs, "commune": e.commune, "insee": e.insee, "invite": false, "stade": str(champs.get("stade", e.nom))}


## Les terrains du registre qui attendent la prochaine saison pour avoir leur club : [commune].
func en_attente() -> Array:
	return Registre.de_type("terrain_foot").map(func(e): return e.commune).filter(func(c): return not clubs.has(c) or clubs[c].invite)


## Le niveau et le groupe d'un club : [n, g], ou [] s'il n'est pas dans la pyramide.
func place_de(club: String) -> Array:
	for n in niveaux.size():
		for g in niveaux[n].size():
			if niveaux[n][g].has(club):
				return [n, g]
	return []


## Le nom d'une division : « Division 1 », « Division 2, groupe B ».
static func nom_division(n: int, g: int) -> String:
	return "Division %d" % (n + 1) if n == 0 else "Division %d, groupe %s" % [n + 1, char(65 + g)]


# ---------------------------------------------------------------- le calendrier d'un groupe

## Les quatorze journées d'un groupe : [{dom, ext}] par journée, aller puis retour (méthode du cercle,
## comme le Vestiaire), dans un ordre tiré de la graine de la saison et du groupe.
static func calendrier(s: int, groupe: Array, n: int, g: int) -> Array:
	var h := Hasard.depuis(Hasard.graine("calendrier/%d/%d/%d" % [s, n, g]))
	var equipes := h.melanger(groupe)
	if equipes.size() % 2 == 1:
		equipes.append("")
	var taille := equipes.size()
	var aller := []
	var tour := equipes.duplicate()
	for j in taille - 1:
		var journee := []
		for k in taille / 2:
			var a: String = tour[k]
			var b: String = tour[taille - 1 - k]
			if a == "" or b == "":
				continue
			var inverse := (j % 2 == 1) if k == 0 else (k % 2 == 1)
			journee.append({"dom": b, "ext": a} if inverse else {"dom": a, "ext": b})
		aller.append(journee)
		tour.insert(1, tour.pop_back())
	var out := aller.duplicate(true)
	for journee in aller:
		out.append(journee.map(func(m): return {"dom": m.ext, "ext": m.dom}))
	return out


## Les matchs de la journée j du groupe (n, g) de la saison s, avec leur score s'ils sont joués
## (joues : combien de journées compter ; par défaut celles que le calendrier réel a passées).
func journee(s: int, n: int, g: int, j: int, joues := -1) -> Array:
	if joues < 0:
		joues = journee_jouee() if s == saison else (JOURNEES if s < saison else 0)
	var cal := calendrier(s, niveaux[n][g], n, g)
	var out := []
	for m in cal[j - 1]:
		var r := {"dom": m.dom, "ext": m.ext, "score": []}
		if j <= joues:
			r.score = resultat(s, j, m.dom, m.ext)
		out.append(r)
	return out


## Le classement du groupe (n, g) de la saison s après « joues » journées : [{club, j, g, n, p, bp, bc,
## diff, pts}], le meilleur d'abord (points, différence, buts marqués, puis l'id).
func classement(s: int, n: int, g: int, joues := -1) -> Array:
	if joues < 0:
		joues = journee_jouee() if s == saison else (JOURNEES if s < saison else 0)
	var lignes := {}
	for id in niveaux[n][g]:
		lignes[id] = {"club": id, "j": 0, "g": 0, "n": 0, "p": 0, "bp": 0, "bc": 0, "diff": 0, "pts": 0}
	for j in range(1, joues + 1):
		for m in journee(s, n, g, j, joues):
			var a: int = m.score[0]
			var b: int = m.score[1]
			var d: Dictionary = lignes[m.dom]
			var e: Dictionary = lignes[m.ext]
			d.j += 1
			e.j += 1
			d.bp += a
			d.bc += b
			e.bp += b
			e.bc += a
			if a > b:
				d.g += 1
				e.p += 1
				d.pts += 3
			elif a < b:
				e.g += 1
				d.p += 1
				e.pts += 3
			else:
				d.n += 1
				e.n += 1
				d.pts += 1
				e.pts += 1
	var out: Array = lignes.values()
	for l in out:
		l.diff = l.bp - l.bc
	out.sort_custom(func(x, y):
		if x.pts != y.pts:
			return x.pts > y.pts
		if x.diff != y.diff:
			return x.diff > y.diff
		if x.bp != y.bp:
			return x.bp > y.bp
		return x.club < y.club)
	return out


# ---------------------------------------------------------------- le résultat d'un match

## La force d'un club pour une saison (40 à 80) : tirée de la graine du club et de la saison, en
## attendant les effectifs et les tactiques repris de Zeus.
func force(club: String, s: int) -> float:
	var h := Hasard.depuis(Hasard.graine("force/%d/%s" % [s, club]))
	return clampf(h.normal(60.0, 8.0), 40.0, 80.0)


## L'effectif d'un club pour une saison : {id: {prenom, nom, poste, age, note, condition, moral, competences}}, les
## notes autour de la force du club (les premiers de chaque poste un peu au-dessus, les autres un peu en
## dessous), et les sept compétences de chacun (FootMatch.COMPETENCES) autour de sa note.
func effectif(club: String, s: int) -> Dictionary:
	var cle := "%d/%s" % [s, club]
	if _effectifs.has(cle):
		return _effectifs[cle]
	var h := Hasard.depuis(Hasard.graine("effectif/" + cle))
	var niveau := force(club, s)
	var out := {}
	var n := 0
	for ligne in EFFECTIF:
		var poste: String = ligne[0]
		var titulaires: int = 1 if poste == "G" else (2 if poste == "A" else 4)
		for k in ligne[1]:
			n += 1
			var age: int = clampi(int(roundf(h.normal(26.0, 4.0))), 17, 36)
			var bonus := 3.0 if k < titulaires else -3.0
			var id := "%s/%d" % [club, n]
			var j := {"prenom": h.choix(PRENOMS), "nom": h.choix(NOMS), "poste": poste, "age": age,
				"note": clampi(int(roundf(h.normal(niveau + bonus, 5.0))), 35, 92), "condition": 100, "moral": 70}
			# Ses sept compétences, d'un tirage à part pour laisser les noms et les notes où ils sont.
			j.competences = FootMatch.tirer_competences(j, Hasard.depuis(Hasard.graine("competences/%s/%s" % [cle, id])))
			out[id] = j
	_effectifs[cle] = out
	return out


## La rencontre de la journée j de la saison s, jouée d'une traite minute par minute (FootMatch) et gardé en
## mémoire : la graine ne dépend que de la saison, de la journée, des deux clubs et des décisions prises
## avant le coup d'envoi (decider), donc tout le monde voit le même match.
func rencontre(s: int, j: int, dom: String, ext: String) -> Dictionary:
	var cle := "match/%d/%d/%s/%s" % [s, j, dom, ext]
	for c in [dom, ext]:
		var d: Dictionary = decisions.get("%d/%d/%s" % [s, j, c], {})
		if not d.is_empty():
			cle += "|%s:%s" % [c, JSON.stringify(d)]
	if _matchs.has(cle):
		return _matchs[cle]
	var direct := rencontre_en_direct(s, j, dom, ext)
	FootMatch.simuler(direct.etat, direct.joueurs, direct.hasard)
	_matchs[cle] = direct.etat
	return direct.etat


## Le même match, prêt pour le coup d'envoi et pas encore joué : {etat, joueurs, hasard}. Le stade le fait
## avancer minute par minute (FootMatch.avancer) et retombe sur le score de rencontre().
func rencontre_en_direct(s: int, j: int, dom: String, ext: String) -> Dictionary:
	var cle := "match/%d/%d/%s/%s" % [s, j, dom, ext]
	for c in [dom, ext]:
		var d: Dictionary = decisions.get("%d/%d/%s" % [s, j, c], {})
		if not d.is_empty():
			cle += "|%s:%s" % [c, JSON.stringify(d)]
	var joueurs := {}
	joueurs.merge(effectif(dom, s))
	joueurs.merge(effectif(ext, s))
	var h := Hasard.depuis(Hasard.graine(cle))
	return {"etat": FootMatch.creer(_equipe(s, j, dom, joueurs), _equipe(s, j, ext, joueurs), joueurs, h), "joueurs": joueurs, "hasard": h}


## Ce que FootMatch attend d'un club : son identité, sa tactique du jour (les décisions) et son effectif.
func _equipe(s: int, j: int, club: String, joueurs: Dictionary) -> Dictionary:
	var c: Dictionary = clubs[club]
	var d: Dictionary = decisions.get("%d/%d/%s" % [s, j, club], {})
	var ids: Array = joueurs.keys().filter(func(id): return str(id).begins_with(club + "/"))
	return {"id": club, "nom": c.nom, "court": c.court, "stade": str(c.get("stade", "le stade %s" % _de(c.nom))),
		"formation": str(d.get("formation", "4-4-2")) if FootMatch.FORMATIONS.has(str(d.get("formation", ""))) else "4-4-2",
		"mentalite": str(d.get("mentalite", "equilibree")) if FootMatch.MENTALITES.has(str(d.get("mentalite", ""))) else "equilibree",
		"pressing": str(d.get("pressing", "normal")) if FootMatch.PRESSINGS.has(str(d.get("pressing", ""))) else "normal",
		"effectif": ids}


## « de l'Étoile », « d'Avenir », « de Jeunesse »…
static func _de(nom: String) -> String:
	return ("d'%s" if nom.left(1).to_lower() in ["a", "e", "i", "o", "u", "y", "é", "h"] else "de %s") % nom


## Le score d'un match, le même pour tout le monde : celui du match joué minute par minute.
func resultat(s: int, j: int, dom: String, ext: String) -> Array:
	return (rencontre(s, j, dom, ext).score as Array).duplicate()


## Une consigne prise avant un match (la tactique du dimanche) ; sans effet sur un match déjà joué.
## Elle vaut tout de suite ici, et part au serveur si le joueur est connecté ; sinon elle reste locale.
func decider(s: int, j: int, club: String, d: Dictionary) -> bool:
	if s < saison or (s == saison and j <= journee_jouee()):
		return false
	var cle := "%d/%d/%s" % [s, j, club]
	decisions[cle] = consigne(d)
	locales[cle] = true
	auteurs.erase(cle)
	sauver()
	change.emit()
	envoyer_locales()
	return true


## Une consigne propre : les trois clés, dans le même ordre partout, les valeurs inconnues ramenées au défaut.
static func consigne(d: Dictionary) -> Dictionary:
	return {"formation": str(d.get("formation", "")) if FootMatch.FORMATIONS.has(str(d.get("formation", ""))) else "4-4-2",
		"mentalite": str(d.get("mentalite", "")) if FootMatch.MENTALITES.has(str(d.get("mentalite", ""))) else "equilibree",
		"pressing": str(d.get("pressing", "")) if FootMatch.PRESSINGS.has(str(d.get("pressing", ""))) else "normal"}


## La consigne d'un club pour une journée, et d'où elle vient : {consigne, etat, par}, etat « aucune »,
## « locale » (sur cet appareil seulement) ou « commune » (au serveur, par le joueur nommé).
func consigne_de(s: int, j: int, club: String) -> Dictionary:
	var cle := "%d/%d/%s" % [s, j, club]
	if not decisions.has(cle):
		return {"consigne": consigne({}), "etat": "aucune", "par": ""}
	return {"consigne": decisions[cle], "etat": "locale" if locales.has(cle) else "commune", "par": str(auteurs.get(cle, ""))}


## Le prochain match d'un club : {s, j, dom, ext, quand}, ou {} si la saison qui vient n'est pas tirée.
func prochain_match(club: String) -> Dictionary:
	var pce := prochain_coup_envoi(maintenant())
	var s: int = pce[0]
	var j: int = pce[1]
	if s != saison:
		return {}
	var place := place_de(club)
	if place.is_empty():
		return {}
	for m in journee(s, place[0], place[1], j, 0):
		if m.dom == club or m.ext == club:
			return {"s": s, "j": j, "dom": m.dom, "ext": m.ext, "quand": pce[2]}
	return {}


## Les consignes lues au serveur : elles l'emportent sur celles d'ici, et une consigne locale que le
## serveur porte aussi cesse d'être locale. Vrai si quelque chose a changé.
func appliquer_consignes(liste: Array) -> bool:
	var bouge := false
	for c in liste:
		if not c is Dictionary or not c.has("club"):
			continue
		var cle := "%d/%d/%s" % [int(c.get("saison", 0)), int(c.get("journee", 0)), str(c.club)]
		var d := consigne(c)
		if decisions.get(cle) != d or locales.has(cle):
			bouge = true
		decisions[cle] = d
		locales.erase(cle)
		auteurs[cle] = str(c.get("par", ""))
	if bouge:
		sauver()
		change.emit()
	return bouge


## Relit toutes les consignes au serveur (sans compte aussi), puis envoie celles d'ici qui manquent.
func lire_consignes() -> void:
	var compte := _compte()
	if compte == null or consignes_etat == "lecture" or get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	consignes_etat = "lecture"
	var r: Dictionary = await compte.appeler("smarves_consignes", {})
	if r.code == 200 and r.corps is Array:
		consignes_etat = "ok"
		appliquer_consignes(r.corps)
		envoyer_locales()
	else:
		consignes_etat = "hors_ligne"


## Envoie au serveur les consignes locales encore à venir ; celles dont le match est passé sont retirées
## (le serveur ne les a pas : elles n'ont compté pour personne).
func envoyer_locales() -> void:
	var compte := _compte()
	if compte == null or not compte.connecte() or get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	for cle in locales.keys():
		var p: PackedStringArray = str(cle).split("/")
		var d: Dictionary = decisions.get(cle, {})
		var r: Dictionary = await compte.appeler("smarves_consigne_poser", {"p_saison": int(p[0]), "p_journee": int(p[1]), "p_club": p[2],
			"p_formation": d.get("formation", "4-4-2"), "p_mentalite": d.get("mentalite", "equilibree"), "p_pressing": d.get("pressing", "normal")})
		if r.code == 200 and r.corps is Dictionary:
			if r.corps.get("ok", false):
				locales.erase(cle)
				auteurs[cle] = compte.nom
			elif r.corps.get("raison", "") == "joue":
				locales.erase(cle)
				decisions.erase(cle)
			sauver()
			change.emit()


func _compte() -> Node:
	return get_node_or_null("/root/Compte")


# ---------------------------------------------------------------- la sauvegarde

func charger() -> void:
	if dossier == "":
		return
	var lu = Portail.lire_json(dossier.path_join(FICHIER))
	if lu is Dictionary and lu.has("niveaux") and lu.has("clubs"):
		saison = int(lu.get("saison", 1))
		niveaux = lu.niveaux
		clubs = lu.clubs
		historique = lu.get("historique", [])
		decisions = lu.get("decisions", {})
		locales = lu.get("locales", {})
		auteurs = lu.get("auteurs", {})


func sauver() -> void:
	if dossier == "":
		return
	Portail.ecrire(dossier.path_join(FICHIER), JSON.stringify({"saison": saison, "niveaux": niveaux, "clubs": clubs, "historique": historique, "decisions": decisions, "locales": locales, "auteurs": auteurs}))


## Repart de rien (essais, nouvelle partie) : la pyramide se refonde au prochain actualiser().
func effacer() -> void:
	saison = 1
	niveaux = []
	clubs = {}
	historique = []
	decisions = {}
	locales = {}
	auteurs = {}
	_matchs = {}
	_effectifs = {}
	if dossier != "":
		DirAccess.remove_absolute(dossier.path_join(FICHIER))
