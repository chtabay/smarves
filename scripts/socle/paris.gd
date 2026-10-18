extends Node
## Les paris du comptoir (autoload « Paris », docs/SUITE.md section 6) : au Café de la Place, Josiane prend
## les paris sur la journée du championnat de la Vienne, à cote fixe. Un ticket porte un ou plusieurs
## matchs de la journée à venir (1, N ou 2 sur chacun) ; à plusieurs matchs, les cotes se multiplient.
## La mise part tout de suite (Game.spend : elle compte dans le total misé, comme à la machine), et le
## ticket se règle le dimanche à 17 h, deux heures après le coup d'envoi : le gain rentre par
## Game.cash_in et compte dans le total gagné au jeu, comme un jackpot.
##
## Les cotes ne dépendent que des forces des deux clubs pour la saison (Football.force), avec l'avantage
## du terrain et la marge de la maison : elles sont les mêmes chez tout le monde, sans serveur. Les
## tickets restent sur l'appareil, comme les consignes. La morale est celle du jeu : à la longue, la
## marge gagne, et la fenêtre le montre sans faire la leçon.

signal change

## Les mises qu'on pose d'un doigt, en crédits : des raccourcis, la mise est libre (MISE_MIN au moins,
## et pas plus que la bourse du joueur).
const MISES := [10, 20, 50, 100, 200]
const MISE_MIN := 1
## Ce que la maison garde sur chaque cote.
const MARGE := 0.12
## L'avantage du terrain, en points de force.
const DOMICILE := 4.0
## Le règlement : deux heures après le coup d'envoi, à 17 h.
const REGLEMENT := 2 * 3600
const FICHIER := "paris.json"
const ISSUES := ["1", "N", "2"]

## Les tickets, du plus ancien au plus récent : {s, j, n, g, choix {"dom|ext": "1"|"N"|"2"}, mise, cote, etat, gain, quand}.
## etat : « ouvert », « gagne », « perdu ».
var tickets: Array = []
## Tout ce qu'on a misé et repris au comptoir depuis le début.
var total_mise := 0
var total_gagne := 0
## Où lire et écrire ; un test le déplace. « » : rien n'est écrit.
var dossier := Communes.GREFFES


func _ready() -> void:
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	charger()
	# Le règlement tombe à l'heure, où que soit le joueur : une passe au lancement, puis toutes les minutes ;
	# la fiche du carnet l'annonce, et Josiane en reparle au café (les tickets pas encore « vus »).
	var minuteur := Timer.new()
	minuteur.wait_time = 60.0
	minuteur.autostart = true
	minuteur.timeout.connect(tic)
	add_child(minuteur)
	tic.call_deferred()
	# Une nouvelle partie (le total misé retombe) emporte les tickets avec le reste.
	var dernier := [Game.staked]
	Game.changed.connect(func():
		if Game.staked < dernier[0]:
			effacer()
			change.emit()
		dernier[0] = Game.staked)


static func foot() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Football")


# ---------------------------------------------------------------- les cotes

## Les chances d'un match d'après les forces (40 à 80) : [domicile, nul, extérieur], somme 1.
static func probabilites(force_dom: float, force_ext: float) -> Array:
	var d := (force_dom + DOMICILE - force_ext) / 10.0
	var p1 := clampf(0.42 + 0.09 * d, 0.1, 0.8)
	var pn := clampf(0.26 - 0.02 * absf(d), 0.12, 0.3)
	var p2 := maxf(1.0 - p1 - pn, 0.08)
	var somme := p1 + pn + p2
	return [p1 / somme, pn / somme, p2 / somme]


## Les cotes d'après les chances, marge de la maison déduite, au vingtième près, jamais sous 1,05.
static func cotes_de(p: Array) -> Array:
	var out: Array = []
	for x in p:
		out.append(maxf(1.05, floorf((1.0 - MARGE) / float(x) * 20.0) / 20.0))
	return out


## Les cotes d'un match : {"1": c, "N": c, "2": c}.
func cotes(s: int, dom: String, ext: String) -> Dictionary:
	var f := foot()
	var c := cotes_de(probabilites(f.force(dom, s), f.force(ext, s)))
	return {"1": c[0], "N": c[1], "2": c[2]}


## L'issue d'un score : 1, N ou 2.
static func issue(score: Array) -> String:
	if score.size() < 2 or score[0] == score[1]:
		return "N"
	return "1" if score[0] > score[1] else "2"


static func cle(dom: String, ext: String) -> String:
	return "%s|%s" % [dom, ext]


# ---------------------------------------------------------------- les tickets

## Pose un ticket sur la journée j de la saison s, dans la division [n, g] : choix {"dom|ext": issue}, une
## entrée par match coché ; la mise, libre, part tout de suite. {ok: true, ticket} ou {ok: false, raison} :
## « vide », « mise » (moins de MISE_MIN), « joue » (le coup d'envoi est donné), « credits ».
func parier(s: int, j: int, n: int, g: int, choix: Dictionary, mise: int) -> Dictionary:
	var f := foot()
	if choix.is_empty():
		return {"ok": false, "raison": "vide"}
	if mise < MISE_MIN:
		return {"ok": false, "raison": "mise"}
	if f.maintenant() >= f.coup_envoi(s, j):
		return {"ok": false, "raison": "joue"}
	var cote := 1.0
	var propre := {}
	for k in choix:
		var p: PackedStringArray = str(k).split("|")
		if p.size() != 2 or not ISSUES.has(str(choix[k])):
			return {"ok": false, "raison": "vide"}
		cote *= float(cotes(s, p[0], p[1])[str(choix[k])])
		propre[str(k)] = str(choix[k])
	if not Game.spend(mise):
		return {"ok": false, "raison": "credits"}
	var t := {"s": s, "j": j, "n": n, "g": g, "choix": propre, "mise": mise, "cote": snappedf(cote, 0.01),
		"etat": "ouvert", "gain": 0, "quand": f.maintenant()}
	tickets.append(t)
	total_mise += mise
	sauver()
	change.emit()
	return {"ok": true, "ticket": t}


## Les tickets encore ouverts.
func ouverts() -> Array:
	return tickets.filter(func(t): return t.etat == "ouvert")


## Règle les tickets dont le dimanche est passé (17 h) ; rend ceux qui viennent de l'être. Le gain d'un
## ticket gagnant rentre dans les crédits et dans le total gagné au jeu.
func regler() -> Array:
	var f := foot()
	var regles: Array = []
	for t in tickets:
		if t.etat != "ouvert" or f.maintenant() < f.coup_envoi(int(t.s), int(t.j)) + REGLEMENT:
			continue
		var gagne := true
		for k in t.choix:
			var p: PackedStringArray = str(k).split("|")
			if issue(f.resultat(int(t.s), int(t.j), p[0], p[1])) != str(t.choix[k]):
				gagne = false
				break
		if gagne:
			t.gain = int(round(int(t.mise) * float(t.cote)))
			t.etat = "gagne"
			total_gagne += int(t.gain)
			Game.cash_in(int(t.gain))
		else:
			t.etat = "perdu"
		regles.append(t)
	if not regles.is_empty():
		sauver()
		change.emit()
	return regles


## Règle ce qui est à régler et l'annonce par la fiche du carnet.
func tic() -> void:
	var carnet: Node = get_tree().root.get_node_or_null("Carnet")
	for t in regler():
		if carnet != null:
			carnet.show_slip("Ticket de la journée %d : %s." % [int(t.j), "gagné, %s crédits" % Game.fmt(int(t.gain)) if t.etat == "gagne" else "perdu"])


## Les tickets réglés dont Josiane n'a pas encore parlé au comptoir ; les marque vus.
func non_vus() -> Array:
	var out: Array = []
	for t in tickets:
		if t.etat != "ouvert" and not bool(t.get("vu", false)):
			t.vu = true
			out.append(t)
	if not out.is_empty():
		sauver()
	return out


## Le bilan du comptoir, pour la fenêtre : {mise, gagne, tickets, gagnes}.
func bilan() -> Dictionary:
	var g := 0
	for t in tickets:
		if t.etat == "gagne":
			g += 1
	return {"mise": total_mise, "gagne": total_gagne, "tickets": tickets.size(), "gagnes": g}


# ---------------------------------------------------------------- la sauvegarde

func charger() -> void:
	if dossier == "":
		return
	var lu = Portail.lire_json(dossier.path_join(FICHIER))
	if lu is Dictionary and lu.has("tickets"):
		tickets = lu.tickets
		total_mise = int(lu.get("total_mise", 0))
		total_gagne = int(lu.get("total_gagne", 0))


func sauver() -> void:
	if dossier == "":
		return
	Portail.ecrire(dossier.path_join(FICHIER), JSON.stringify({"tickets": tickets, "total_mise": total_mise, "total_gagne": total_gagne}))


## Repart de rien (essais, nouvelle partie).
func effacer() -> void:
	tickets = []
	total_mise = 0
	total_gagne = 0
	if dossier != "":
		DirAccess.remove_absolute(dossier.path_join(FICHIER))
