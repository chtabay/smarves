extends SceneTree
## Captures du Dôme de Minuit, la salle de basket de Casino Minuit (tools/paquet_essai/casino_minuit/basket/),
## emballé ici comme dans capture_stade_minuit.gd : godot --path . -s tools/capture_dome_minuit.gd --
## --capture=sortie.png [--at=x,z,lacet,tangage[,y]] [--match] [--bureau] (les options de la salle du socle).

const SOURCE := "res://tools/paquet_essai/casino_minuit/"
const TMP := "user://capture_dome_minuit/"


func _init() -> void:
	await process_frame
	var communes: Node = root.get_node("Communes")
	DirAccess.make_dir_recursive_absolute(TMP)
	communes.dossier_greffes = TMP
	var pck := TMP + "casino_minuit.pck"
	var pk := PCKPacker.new()
	pk.pck_start(pck)
	_emballer(pk, SOURCE, SOURCE)
	pk.flush()
	if communes.charger_pack(pck) != "casino_minuit":
		push_error("Casino Minuit ne se greffe pas : %s" % str(communes.refus))
		quit(1)
		return
	root.get_node("Game").welcomed = true
	communes.ouvrir("casino_minuit")
	var salle = load("res://scripts/village/salle_basket.gd")
	salle.prochaine_commune = "casino_minuit"
	change_scene_to_file("res://communes/casino_minuit/basket/dome.tscn")


func _emballer(pk: PCKPacker, dossier: String, racine: String) -> void:
	var d := DirAccess.open(dossier)
	for f in d.get_files():
		if not f.ends_with(".uid"):
			pk.add_file("res://communes/casino_minuit/" + (dossier + f).trim_prefix(racine), dossier + f)
	for sous in d.get_directories():
		_emballer(pk, dossier + sous + "/", racine)
