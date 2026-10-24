extends SceneTree
## Les paquets de communes compilent-ils avec ce socle ? Chaque .pck d'un dossier est monté, et chacun
## de ses scripts chargé :
##   godot --headless --path . -s tools/verifier_paquets.gd -- <dossier des .pck>
## Un membre ajouté à une classe du socle (SalleJeu, Visite…) qu'une commune déclare déjà dans sa
## sous-classe l'empêche de compiler, et le lieu ne s'ouvre plus. À lancer avant de fusionner un
## changement du socle, sur les paquets du portail (https://pyramides2.vercel.app/api/communes).

var _n := 0
var fails := 0


func _lister(d: String, out: Array) -> void:
	var da := DirAccess.open(d)
	if da == null:
		return
	for f in da.get_files():
		if f.ends_with(".gd"):
			out.append(d.path_join(f))
	for s in da.get_directories():
		_lister(d.path_join(s), out)


func _process(_d: float) -> bool:
	_n += 1
	if _n != 2:
		return false
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Usage : -- <dossier des .pck>")
		quit(2)
		return true
	var dossier: String = args[0]
	for f in DirAccess.get_files_at(dossier):
		if not f.ends_with(".pck"):
			continue
		var id := f.get_basename()
		ProjectSettings.load_resource_pack(dossier.path_join(f), false)
		var fichiers := []
		_lister("res://communes/" + id, fichiers)
		var ko := 0
		for g in fichiers:
			var s = ResourceLoader.load(g, "", ResourceLoader.CACHE_MODE_IGNORE)
			if s == null or not (s as GDScript).can_instantiate():
				ko += 1
				print("   ÉCHEC   ", g)
		print("%s %s : %d scripts, %d en échec" % ["ok     " if ko == 0 else "ÉCHEC  ", id, fichiers.size(), ko])
		fails += ko
	print("Tout compile." if fails == 0 else "%d scripts ne compilent pas." % fails)
	quit(1 if fails else 0)
	return true
