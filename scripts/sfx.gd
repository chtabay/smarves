extends Node
## Le son de Smarves (autoload « Sfx ») : bruitages de jeu tirés des packs Kenney, et ambiances
## synthétisées à la volée (murmure de la foule, grillons de la place, musique de salon du casino).
## Par-dessus, la musique du lieu (Sfx.musique) : un thème du socle par type de lieu, synthétisé dans le
## dépôt (assets/audio/musique/, composés par tools/musiques.py), sur le bus Ambiance, assez bas pour
## laisser les bruitages devant. Deux lecteurs se passent le relais en fondu enchaîné, et chaque thème
## reprend là où on l'avait laissé. La ville est en couches qui tournent ensemble : elle s'étoffe à
## mesure que le joueur gagne (COUCHES).

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
## Les thèmes du socle : la place (jazz-funk de grande ville, en trois couches), l'écran titre et les
## menus, les environs (musique de feu de camp). Un thème en liste est fait de couches de même longueur.
const MUSIQUES := {
	"ville": [
		"res://assets/audio/musique/ville_fond.ogg",
		"res://assets/audio/musique/ville_cuivres.ogg",
		"res://assets/audio/musique/ville_chant.ogg",
	],
	"titre": "res://assets/audio/musique/titre.ogg",
	"environs": "res://assets/audio/musique/environs.ogg",
}
## Le total gagné au jeu à partir duquel chaque couche d'un thème joue : le fond toujours, les cuivres
## et les cordes à 1 000, le chant à 10 000 (l'ouverture du Salon de musique).
const COUCHES := {"ville": [0, 1000, 10000]}
const MUSIQUE_DB := -15.0
const SILENCE_DB := -60.0
## Les secondes du fondu enchaîné : le nouveau thème monte en FONDU, l'ancien descend un peu plus vite.
const FONDU := 2.5
const FONDU_SORTIE := 1.2

var ambience := ""
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _gen: AudioStreamGenerator
var _gen_player: AudioStreamPlayer
## Le thème qu'on entend (ou qui monte) : un nom de MUSIQUES, un chemin res:// vers un .ogg, ou "".
var musique_courante := ""
var _lecteurs: Array[AudioStreamPlayer] = []
var _fondus: Array = [null, null]
var _actif := 0
## Où chaque thème en était quand on l'a quitté, en secondes.
var _positions := {}
var _flux := {}
## Combien de couches du thème en cours jouent.
var couches := 0
var _couches_pas := 0.0
var _fondu_couches: Tween
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
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Ambiance"
		m.volume_db = SILENCE_DB
		add_child(m)
		_lecteurs.append(m)
	_calculer_d_avance()


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
## Village : un murmure lointain, quelques rafales de vent, et la musique de la ville. Casino : la rumeur
## de la salle et un piano-bar très bas, sans autre musique.
func set_ambience(kind: String) -> void:
	if kind == ambience and _gen_player.playing:
		return
	ambience = kind
	if not _loops.has(kind):
		_loops[kind] = _boucle(kind)
	_gen_player.stream = _loops[kind]
	_gen_player.play()
	musique("ville" if kind == "village" else "")


## La musique du lieu : un thème du socle (« ville », « titre », « environs »), le chemin res:// d'une
## boucle .ogg, ou "" pour le silence. Le thème d'avant descend pendant que le nouveau monte ; un thème
## qu'on retrouve reprend là où on l'avait quitté. Redemander le thème en cours ne fait rien.
func musique(nom: String, fondu := FONDU) -> void:
	if nom == musique_courante:
		return
	var flux: AudioStream = null
	if nom != "":
		flux = _flux_de(nom)
		if flux == null:
			push_warning("Sfx : musique inconnue « %s »" % nom)
			return
	_eteindre(_actif, minf(fondu, FONDU_SORTIE))
	musique_courante = nom
	if flux == null:
		return
	_actif = 1 - _actif
	var p := _lecteurs[_actif]
	_eteindre(_actif, 0.0)
	p.stream = flux
	p.set_meta("theme", nom)
	p.volume_db = SILENCE_DB
	_poser_couches(0.0)
	p.play(fmod(float(_positions.get(nom, 0.0)), maxf(flux.get_length(), 0.001)))
	_fondus[_actif] = create_tween()
	_fondus[_actif].tween_property(p, "volume_db", MUSIQUE_DB, fondu)


func _flux_de(nom: String) -> AudioStream:
	if _flux.has(nom):
		return _flux[nom]
	var source = MUSIQUES.get(nom, nom if nom.begins_with("res://") else "")
	var flux: AudioStream = null
	if source is Array:
		# Les couches tournent ensemble, chacune avec son volume (_poser_couches).
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = source.size()
		for i in source.size():
			var c := _boucle_de(source[i])
			if c == null:
				return null
			sync.set_sync_stream(i, c)
			sync.set_sync_stream_volume(i, SILENCE_DB)
		flux = sync
	else:
		flux = _boucle_de(str(source))
	if flux:
		_flux[nom] = flux
	return flux


func _boucle_de(chemin: String) -> AudioStream:
	var flux: AudioStream = load(chemin) if chemin != "" and ResourceLoader.exists(chemin) else null
	if flux is AudioStreamOggVorbis:
		flux.loop = true
	elif flux is AudioStreamWAV and flux.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		flux = null
	return flux


## Les couches qui jouent pour un total gagné : le nombre de seuils de COUCHES[nom] atteints (0 si le
## thème n'est pas en couches).
static func couches_pour(nom: String, gagne: int) -> int:
	var seuils: Array = COUCHES.get(nom, [])
	var n := 0
	for s in seuils:
		if gagne >= s:
			n += 1
	return n


## Met les couches du thème en cours au volume que veut la partie, en `duree` secondes.
func _poser_couches(duree: float) -> void:
	var flux = _flux.get(musique_courante)
	if not (flux is AudioStreamSynchronized):
		couches = 0
		return
	var game = get_node_or_null("/root/Game")
	var voulu := maxi(1, couches_pour(musique_courante, int(game.won) if game else 0))
	if voulu == couches and duree > 0.0:
		return
	couches = voulu
	if _fondu_couches:
		_fondu_couches.kill()
		_fondu_couches = null
	if duree > 0.0:
		_fondu_couches = create_tween().set_parallel()
	for i in flux.stream_count:
		var cible := 0.0 if i < voulu else SILENCE_DB
		if duree <= 0.0:
			flux.set_sync_stream_volume(i, cible)
		else:
			_fondu_couches.tween_method(func(v: float): flux.set_sync_stream_volume(i, v), flux.get_sync_stream_volume(i), cible, duree)


## Fait descendre un lecteur (en `duree` secondes, ou tout de suite) et retient où en était son thème.
func _eteindre(i: int, duree: float) -> void:
	var p := _lecteurs[i]
	if _fondus[i]:
		_fondus[i].kill()
		_fondus[i] = null
	if not p.playing:
		return
	var theme := str(p.get_meta("theme", ""))
	if duree <= 0.0:
		_positions[theme] = p.get_playback_position()
		p.stop()
		return
	_fondus[i] = create_tween()
	_fondus[i].tween_property(p, "volume_db", SILENCE_DB, duree)
	_fondus[i].tween_callback(func():
		_positions[theme] = p.get_playback_position()
		p.stop())


var _loops := {}
## Les deux boucles se calculent dès le lancement, dans des fils à part : trois cent cinquante mille
## échantillons en GDScript prenaient près d'une seconde au premier passage sur la place puis au
## casino (davantage sur téléphone), pendant le chargement du lieu.
var _calculs := {}
var _donnees := {}
var _verrou := Mutex.new()


func _calculer_d_avance() -> void:
	for kind in ["village", "casino"]:
		_calculs[kind] = WorkerThreadPool.add_task(_calculer.bind(kind), false, "Ambiance " + kind)


func _calculer(kind: String) -> void:
	var data := _render_data(kind)
	_verrou.lock()
	_donnees[kind] = data
	_verrou.unlock()


func _boucle(kind: String) -> AudioStreamWAV:
	if _calculs.has(kind):
		WorkerThreadPool.wait_for_task_completion(_calculs[kind])
		_calculs.erase(kind)
	_verrou.lock()
	var data: PackedByteArray = _donnees.get(kind, PackedByteArray())
	_donnees.erase(kind)
	_verrou.unlock()
	if data.is_empty():
		data = _render_data(kind)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = true
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = int(RATE * 16.0)
	return w


func _render_data(kind: String) -> PackedByteArray:
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
			# Le vent ne souffle plus en continu : un fond très bas, et une rafale par boucle.
			var rafale := pow(0.5 + 0.5 * sin(TAU * t / seconds - 1.2), 4.0)
			v = lp2 * (0.35 + 1.1 * rafale) * swell + lp3 * 1.0
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
	return data


func _process(delta: float) -> void:
	# Une couche de plus quand la partie passe un seuil : elle entre en fondu, sur la mesure qui joue.
	_couches_pas -= delta
	if _couches_pas <= 0.0:
		_couches_pas = 1.0
		_poser_couches(4.0)
	if ambience == "casino":
		_clink_timer -= delta
		if _clink_timer <= 0.0:
			_clink_timer = randf_range(1.5, 5.0)
			play(["chips", "card", "chips_win", "dice"].pick_random(), randf_range(-30.0, -22.0))


func _exit_tree() -> void:
	for kind in _calculs:
		WorkerThreadPool.wait_for_task_completion(_calculs[kind])
	_calculs.clear()
	for i in _lecteurs.size():
		if _fondus[i]:
			_fondus[i].kill()
		_lecteurs[i].stop()
		_lecteurs[i].stream = null
