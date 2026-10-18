extends Control
## Le lanceur du SDK des communes, à la place du village de Smarves : il inscrit les communes posées
## dans res://communes/<id>/ (celles qu'on développe) et ouvre celle qu'on choisit, comme le jeu le
## ferait chez un joueur qui l'a installée. « Revenir à Smarves » ramène ici.
## Lancer le projet (F5 dans Godot) ouvre ce lanceur ; « godot --path . -- --commune=<id> » ouvre
## directement la commune.

func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = Color(0.08, 0.07, 0.06)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var boite := VBoxContainer.new()
	boite.set_anchors_preset(Control.PRESET_CENTER)
	boite.add_theme_constant_override("separation", 14)
	add_child(boite)
	var titre := Label.new()
	titre.text = "Smarves — SDK des communes"
	titre.add_theme_font_override("font", Polices.titre())
	titre.add_theme_font_size_override("font_size", 40)
	boite.add_child(titre)
	var ids := communes_du_projet()
	var direct := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--commune="):
			direct = a.trim_prefix("--commune=")
	var aide := Label.new()
	aide.add_theme_font_override("font", Polices.texte())
	aide.text = "Les communes de res://communes/ :" if not ids.is_empty() else \
		"Aucune commune dans res://communes/. Copiez-y le kit de départ (voir LISEZMOI.md)."
	boite.add_child(aide)
	for id in ids:
		var c: Commune = Communes.commune(id)
		var b := Button.new()
		b.text = "%s (%s)%s" % [c.nom, id, "" if c.valide() else " — refusée : " + "; ".join(c.erreurs)]
		b.disabled = not c.valide()
		b.pressed.connect(func(): Communes.visiter(id))
		boite.add_child(b)
	if direct != "" and direct in ids:
		Communes.visiter.call_deferred(direct)


## Inscrit chaque dossier res://communes/<id>/ qui a un manifeste (sauf Smarves) et rend leurs ids.
static func communes_du_projet() -> Array:
	var out := []
	var d := DirAccess.open("res://communes/")
	if d == null:
		return out
	for id in d.get_directories():
		if id == Communes.ORIGINE or not FileAccess.file_exists("res://communes/%s/commune.json" % id):
			continue
		if Communes.commune(id) == null:
			Communes.charger_dossier("res://communes/" + id)
		if Communes.commune(id) != null:
			out.append(id)
	return out
