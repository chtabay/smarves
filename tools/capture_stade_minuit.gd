extends SceneTree
## Captures du stade de la Fortune de Casino Minuit (tools/paquet_essai/casino_minuit/stade/), emballé ici comme
## dans capture_minuit.gd : godot --path . -s tools/capture_stade_minuit.gd -- --capture=sortie.png
## [--at=x,z,lacet,tangage] [--y=hauteur] [--attendre=s] [--journee=n --minute=m]
## Sans --at, le visiteur à la station de taxis du parvis ; la scène du stade prend la capture elle-même.

const SOURCE := "res://tools/paquet_essai/casino_minuit/"
const TMP := "user://capture_stade_minuit/"


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
	root.get_node("Football").ouvrir_stade("casino_minuit")


func _emballer(pk: PCKPacker, dossier: String, racine: String) -> void:
	var d := DirAccess.open(dossier)
	for f in d.get_files():
		if not f.ends_with(".uid"):
			pk.add_file("res://communes/casino_minuit/" + (dossier + f).trim_prefix(racine), dossier + f)
	for sous in d.get_directories():
		_emballer(pk, dossier + sous + "/", racine)
