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
	# Deux bus, réglables séparément dans le menu : l'ambiance et les bruitages.
	for bus in ["Ambiance", "Bruitages"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for k in GROUPS:
		var list: Array = []
		for path in GROUPS[k]:
			var s = load("res://assets/audio/%s.ogg" % path)
			if s:
				list.append(s)
		_streams[k] = list
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Bruitages"
		add_child(p)
		_players.append(p)
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = RATE
	_gen.buffer_length = 0.25
	_gen_player = AudioStreamPlayer.new()
	_gen_player.stream = _gen
	_gen_player.volume_db = 0.0
	_gen_player.bus = "Ambiance"
	add_child(_gen_player)


func play(group: String, volume_db := 0.0, pitch := 1.0) -> void:
	var list: Array = _streams.get(group, [])
	if list.is_empty():
		return
	for p in _players:
		if not p.playing:
			p.stream = list.pick_random()
			p.volume_db = volume_db + 3.0
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


## Les ambiances sont calculées une fois, en boucles de seize secondes : plus de crépitements ni de bips.
## Village : un murmure lointain et le vent. Casino : la rumeur de la salle et un piano-bar très bas.
func set_ambience(kind: String) -> void:
	if kind == ambience and _gen_player.playing:
		return
	ambience = kind
	if not _loops.has(kind):
		_loops[kind] = _render_loop(kind)
	_gen_player.stream = _loops[kind]
	_gen_player.play()


var _loops := {}


func _render_loop(kind: String) -> AudioStreamWAV:
	var seconds := 16.0
	var n := int(RATE * seconds)
	# Quelques images de plus après la fin de la boucle : le mélangeur lit un peu au-delà de loop_end
	# pour interpoler, et sur Android ce dépassement tombait sur une page interdite (plantage à 20 s).
	var marge := 256
	var data := PackedByteArray()
	data.resize((n + marge) * 4)
	var lp1 := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := i / RATE
		var white := rng.randf() * 2.0 - 1.0
		lp1 += (white - lp1) * 0.03
		lp2 += (lp1 - lp2) * 0.06
		lp3 += (white - lp3) * 0.004
		# Fondu aux deux bouts pour une boucle sans couture.
		var edge := minf(1.0, minf(t, seconds - t) / 0.5)
		var swell := 0.6 + 0.4 * sin(TAU * t / seconds) * sin(TAU * 3.0 * t / seconds)
		var v := 0.0
		if kind == "village":
			v = lp2 * 1.6 * swell + lp3 * 3.0
		else:
			var bar := int(t / 4.0) % CHORDS.size()
			var local := fmod(t, 4.0)
			var env := minf(local * 3.0, 1.0) * exp(-local * 0.6)
			var pad := 0.0
			for note in CHORDS[bar]:
				var f := 440.0 * pow(2.0, (note - 69) / 12.0)
				pad += sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.1
			var bass := sin(TAU * 440.0 * pow(2.0, (CHORDS[bar][0] - 12 - 69) / 12.0) * t) * 0.6
			v = lp2 * 1.8 * swell + (pad * 0.07 + bass * 0.09) * env
		var sample := int(clampf(v * edge, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 4, sample)
		data.encode_s16(i * 4 + 2, sample)
	# La marge reprend le début de la boucle, pour rester sans couture.
	for j in marge:
		data.encode_s16((n + j) * 4, data.decode_s16(j * 4))
		data.encode_s16((n + j) * 4 + 2, data.decode_s16(j * 4 + 2))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = true
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


func _process(delta: float) -> void:
	if ambience == "casino":
		_clink_timer -= delta
		if _clink_timer <= 0.0:
			_clink_timer = randf_range(1.5, 5.0)
			play(["chips", "card", "chips_win", "dice"].pick_random(), randf_range(-30.0, -22.0))
