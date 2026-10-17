extends Node
## Vérifie que le jeu produit vraiment du son : enregistre le bus Master et mesure le niveau.
## godot --path . res://tools/audio_check.tscn

func _ready() -> void:
	print("pilote audio : ", AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "?", " · sortie : ", AudioServer.output_device, " · périphériques : ", AudioServer.get_output_device_list())
	for i in AudioServer.bus_count:
		print("bus ", i, " ", AudioServer.get_bus_name(i), " vol ", AudioServer.get_bus_volume_db(i), " dB muet ", AudioServer.is_bus_mute(i), " envoie vers ", AudioServer.get_bus_send(i))
	var rec := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	rec.set_recording_active(true)
	Sfx.set_ambience("village")
	await get_tree().create_timer(1.5).timeout
	Sfx.play("chips", -9.0)
	Sfx.result(10, 200)
	await get_tree().create_timer(2.5).timeout
	rec.set_recording_active(false)
	var w := rec.get_recording()
	var data := w.data
	var peak := 0
	var sum := 0.0
	var n := data.size() / 2
	for i in range(0, data.size() - 1, 2):
		var v := data.decode_s16(i)
		peak = maxi(peak, absi(v))
		sum += float(v) * float(v)
	print("échantillons ", n, " · crête ", peak, " / 32767 · RMS ", sqrt(sum / maxf(n, 1)))
	get_tree().quit()
