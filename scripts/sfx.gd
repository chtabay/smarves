extends Node
## Le son de Smarves (autoload « Sfx ») : bruitages de jeu tirés des packs Kenney, et ambiances
## synthétisées à la volée (murmure de la foule, grillons de la place, musique de salon du casino).

const GROUPS := {
	"chips": ["casino/chip-lay-1", "casino/chip-lay-2", "casino/chip-lay-3", "casino/chips-stack-1", "casino/chips-stack-3"],
	"chips_win": ["casino/chips-collide-1", "casino/chips-collide-2", "casino/chips-collide-3", "casino/chips-handle-2"],
	"card": ["casino/card-place-1", "casino/card-place-2", "casino/card-place-3", "casino/card-slide-1", "casino/card-slide-4"],
	"shuffle": ["casino/card-shuffle"],
	"dice": ["casino/dice-throw-1", "casino/dice-throw-2", "casino/dice-throw-3"],
	"shake": ["casino/dice-shake-1", "casino/dice-shake-2", "casino/dice-shake-3"],
	"click": ["ui/click1", "ui/click3"],
	"tick": ["ui/switch2", "ui/switch7"],
	"lose": ["ui/switch33"],
	"win": ["jingles/jingles_PIZZI01", "jingles/jingles_PIZZI04", "jingles/jingles_PIZZI07"],
	"big_win": ["jingles/jingles_SAX03", "jingles/jingles_SAX07", "jingles/jingles_SAX10", "jingles/jingles_SAX15"],
}
const RATE := 22050.0

var ambience := ""
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _gen: AudioStreamGenerator
var _gen_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _t := 0.0
var _noise := 0.0
var _noise2 := 0.0
var _chirp := 0.0
var _chord := 0
var _clink_timer := 2.0
const CHORDS := [[57, 60, 64, 67], [50, 53, 57, 60], [55, 59, 62, 65], [48, 52, 55, 59]]  # Am7 Dm7 G7 Cmaj7


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in GROUPS:
		var list: Array = []
		for path in GROUPS[k]:
			var s = load("res://assets/audio/%s.ogg" % path)
			if s:
				list.append(s)
		_streams[k] = list
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = RATE
	_gen.buffer_length = 0.25
	_gen_player = AudioStreamPlayer.new()
	_gen_player.stream = _gen
	_gen_player.volume_db = -8.0
	add_child(_gen_player)


func play(group: String, volume_db := 0.0, pitch := 1.0) -> void:
	var list: Array = _streams.get(group, [])
	if list.is_empty():
		return
	for p in _players:
		if not p.playing:
			p.stream = list.pick_random()
			p.volume_db = volume_db
			p.pitch_scale = pitch * randf_range(0.96, 1.04)
			p.play()
			return


## Le son d'un coup joué : jetons et fanfare si l'on gagne, petit déclic sec si l'on perd.
func result(bet: int, payout: int) -> void:
	if payout <= 0:
		play("lose", -10.0)
	elif payout >= bet * 10 and payout > 0:
		play("big_win", -2.0)
		play("chips_win", -4.0)
	else:
		play("win", -6.0)
		play("chips_win", -6.0)


func set_ambience(kind: String) -> void:
	ambience = kind
	if not _gen_player.playing:
		_gen_player.play()
		_playback = _gen_player.get_stream_playback()


func _process(delta: float) -> void:
	if ambience == "" or _playback == null:
		return
	if ambience == "casino":
		_clink_timer -= delta
		if _clink_timer <= 0.0:
			_clink_timer = randf_range(1.5, 5.0)
			play(["chips", "card", "chips_win", "dice"].pick_random(), randf_range(-30.0, -22.0))
	var frames := _playback.get_frames_available()
	for i in frames:
		_playback.push_frame(Vector2.ONE * _sample())


func _sample() -> float:
	_t += 1.0 / RATE
	# Un murmure : du bruit très filtré, qui enfle et retombe doucement.
	var white := randf() * 2.0 - 1.0
	_noise += (white - _noise) * 0.02
	_noise2 += (_noise - _noise2) * 0.05
	var swell := 0.55 + 0.45 * sin(_t * 0.37) * sin(_t * 0.11)
	var murmur := _noise2 * 2.2 * swell
	if ambience == "village":
		# Des grillons : des salves brèves et aiguës, irrégulières.
		var gate := 1.0 if fmod(_t * 7.3, 1.0) < 0.35 and sin(_t * 0.9) > -0.2 else 0.0
		_chirp = lerpf(_chirp, gate, 0.002)
		var cricket := sin(_t * TAU * 4200.0) * _chirp * 0.05
		return murmur * 0.35 + cricket
	# Au casino : le murmure de la salle et un piano-bar de quatre accords, très bas.
	var bar := int(_t / 4.0) % CHORDS.size()
	var local := fmod(_t, 4.0)
	var env := minf(local * 2.0, 1.0) * exp(-local * 0.5)
	var pad := 0.0
	for n in CHORDS[bar]:
		var f := 440.0 * pow(2.0, (n - 69) / 12.0)
		pad += sin(_t * TAU * f) * 0.5 + sin(_t * TAU * f * 2.0) * 0.12
	var bass := sin(_t * TAU * 440.0 * pow(2.0, (CHORDS[bar][0] - 12 - 69) / 12.0)) * 0.6
	return murmur * 0.6 + (pad * 0.035 + bass * 0.05) * env
