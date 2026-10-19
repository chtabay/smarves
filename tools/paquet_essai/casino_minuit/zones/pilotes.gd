extends RefCounted
## Les pilotes du lot F (js/zones/f-0-commun.js) : le concert de Minuit Live (C.lotF.concert : le programme des
## Lyres, le tempo, l'énergie de chaque morceau, l'entracte) et le combat de l'arène (C.lotF.arene : l'attente,
## douze rounds de trois minutes, la minute de repos, la décision, la cloche). Les zones (concert.gd, arene.gd)
## en montrent l'état ; les PNJ de la vague « vie » (pnj/vie.gd) le suivent. Les deux suivent l'horloge réelle,
## l'écart d'une image borné à 0,5 s, comme l'original.

const SETLIST := [
	{"titre": "Néons de Minuit", "artiste": "Les Lyres", "bpm": 124.0, "duree": 210.0, "couleurs": ["#FF4D8D", "#3DE0E0"], "style": "électro-pop"},
	{"titre": "Boulevard des Mirages", "artiste": "Les Lyres", "bpm": 102.0, "duree": 200.0, "couleurs": ["#FFC24A", "#FF3348"], "style": "funk"},
	{"titre": "Jackpot", "artiste": "Les Lyres", "bpm": 132.0, "duree": 190.0, "couleurs": ["#4DFF9A", "#FF4D8D"], "style": "disco"},
	{"titre": "Velours rouge", "artiste": "Les Lyres", "bpm": 72.0, "duree": 230.0, "couleurs": ["#FF3348", "#FFD9A8"], "style": "ballade"},
	{"titre": "Mise à tapis", "artiste": "Les Lyres", "bpm": 140.0, "duree": 200.0, "couleurs": ["#3D7BFF", "#FFFFFF"], "style": "rock"},
]

var concert := {
	"index": 0, "song": SETLIST[0], "bpm": SETLIST[0].bpm, "beat": 0, "bar": 0, "beatPos": 0.0, "phase": 0.0, "songTime": 0.0,
	"energy": 0.4, "state": "morceau", "playing": true, "ENTRACTE": 9.0,
}

var arene := {
	"titre": "Championnat du monde · poids moyens", "soiree": "Nuit des Champions",
	"rouge": {"nom": "Rafael « El Toro » Díaz", "court": "DÍAZ", "pays": "Mexique", "bilan": "27 V · 1 D"},
	"bleu": {"nom": "Marcus « Ice » Bell", "court": "BELL", "pays": "États-Unis", "bilan": "24 V · 0 D"},
	"rounds": 12, "roundLen": 180.0, "restLen": 60.0, "preLen": 30.0, "endLen": 45.0,
	"round": 0, "chrono": 30.0, "state": "attente", "auto": true, "rev": 0, "bellT": -99.0, "time": 0.0,
}

## Ceux qui écoutent : fn(nom, données) pour « concert:song », « concert:entracte », « concert:beat »,
## « boxe:round », « boxe:bell » (C.bus de l'original).
var ecoutes: Array = []

var _dernier := 0


func emettre(nom: String, d := {}) -> void:
	for f in ecoutes:
		f.call(nom, d)


## Chaque image : l'écart réel depuis la précédente (au plus 0,5 s).
func avancer() -> void:
	var t := Time.get_ticks_msec()
	var dt := 0.0 if _dernier == 0 else minf(0.5, (t - _dernier) / 1000.0)
	_dernier = t
	pas(dt)


func pas(dt: float) -> void:
	_concert(dt)
	_arene(dt)


# --- le concert -------------------------------------------------------------------------------------

func set_song(i: int) -> Dictionary:
	var CO := concert
	CO.index = posmod(i, SETLIST.size())
	CO.song = SETLIST[CO.index]
	CO.bpm = CO.song.bpm
	CO.songTime = 0.0
	CO.state = "morceau"
	CO.beatPos = floorf(CO.beatPos)
	emettre("concert:song", {"index": CO.index, "song": CO.song})
	return CO.song


func suivant() -> Dictionary:
	return set_song(concert.index + 1)


## L'énergie d'un morceau selon sa progression : intro, couplet, refrain, pont, dernier refrain, fin.
static func energy_at(k: float, style: String) -> float:
	var b := 0.55 if style == "ballade" else 1.0
	if k < 0.08:
		return 0.35 * b
	if k < 0.28:
		return 0.6 * b
	if k < 0.45:
		return 1.0 * b
	if k < 0.55:
		return 0.5 * b
	if k < 0.9:
		return 1.0 * b
	return 0.5 * b


func _concert(dt: float) -> void:
	var CO := concert
	if not CO.playing:
		return
	CO.songTime += dt
	if CO.state == "morceau":
		var k: float = CO.songTime / CO.song.duree
		CO.energy += (energy_at(k, CO.song.style) - CO.energy) * minf(1.0, dt * 2)
		if CO.songTime >= CO.song.duree:
			CO.state = "entracte"
			CO.songTime = 0.0
			emettre("concert:entracte", {"index": CO.index})
	else:
		CO.energy += (0.08 - CO.energy) * minf(1.0, dt * 1.5)
		if CO.songTime >= CO.ENTRACTE:
			suivant()
	var prev := floorf(CO.beatPos)
	CO.beatPos += dt * CO.bpm / 60.0
	CO.phase = CO.beatPos - floorf(CO.beatPos)
	if floorf(CO.beatPos) != prev and CO.state == "morceau":
		CO.beat += 1
		CO.bar = CO.beat % 4
		emettre("concert:beat", {"beat": CO.beat, "bar": CO.bar, "bpm": CO.bpm, "song": CO.song, "energy": CO.energy})


# --- l'arène ----------------------------------------------------------------------------------------

## La cloche : début d'un round (depuis l'attente ou le repos), fin d'un round, reprise après la décision.
func bell(kind := "") -> String:
	var AR := arene
	AR.bellT = AR.time
	if AR.state == "round":
		if AR.round >= AR.rounds:
			_etat("fin", AR.endLen)
			_ring("fin-combat")
		else:
			_etat("repos", AR.restLen)
			_ring(kind if kind != "" else "fin")
	elif AR.state == "fin":
		reset()
		_ring(kind if kind != "" else "reprise")
	else:
		AR.round = mini(AR.rounds, AR.round + 1)
		_etat("round", AR.roundLen)
		_ring(kind if kind != "" else "début")
	return AR.state


func reset() -> void:
	arene.round = 0
	_etat("attente", arene.preLen)


## « m:ss » du chrono.
func horloge() -> String:
	var s := maxi(0, ceili(arene.chrono))
	return "%d:%02d" % [s / 60, s % 60]


## L'invite de la cloche.
func invite_cloche() -> String:
	var AR := arene
	if AR.state == "round":
		return "Sonner la fin du round %d" % AR.round
	if AR.state == "fin":
		return "Sonner la reprise"
	return "Sonner le round %d" % mini(AR.rounds, AR.round + 1)


func _etat(state: String, t: float) -> void:
	arene.state = state
	arene.chrono = t
	arene.rev += 1
	emettre("boxe:round", {"round": arene.round, "state": state, "chrono": t, "rounds": arene.rounds})


func _ring(kind: String) -> void:
	emettre("boxe:bell", {"round": arene.round, "kind": kind, "state": arene.state})


func _arene(dt: float) -> void:
	var AR := arene
	AR.time += dt
	var avant := ceili(AR.chrono)
	AR.chrono = maxf(0.0, AR.chrono - dt)
	if ceili(AR.chrono) != avant:
		AR.rev += 1
	if AR.auto and AR.chrono <= 0:
		bell()
