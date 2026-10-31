extends SceneTree
## Vérifie la Mobylette du socle (scripts/socle/mobylette.gd, autoload Mobylettes) sur Ligugé, emballée ici en
## pack : godot --headless --path . -s tools/test_mobylette.gd -- --tactile
## Le socle en gare une à l'arrivée, à la taille de l'habitant ; on l'enfourche (E, ou le bouton au doigt), on va
## plus vite, assis sur la selle, V (ou le bouton) fait descendre et elle reste là. Pas de deuxième au retour,
## aucune quand le manifeste n'en veut pas ; le bouton tactile lit aussi les Mobylettes des paquets d'avant (Lyon).

const LIGUGE := "res://tools/paquet_essai/liguge/"
const TMP := "user://test_mobylette/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func attendre(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true
	var communes: Node = root.get_node("Communes")
	var tactile: Node = root.get_node("Tactile")
	var mobylettes: Node = root.get_node("Mobylettes")
	DirAccess.make_dir_recursive_absolute(TMP)
	communes.dossier_greffes = TMP
	var pk := PCKPacker.new()
	pk.pck_start(TMP + "liguge.pck")
	for f in ["commune.json", "commune.tscn", "liguge.gd"]:
		pk.add_file("res://communes/liguge/" + f, LIGUGE + f)
	pk.flush()
	check(communes.charger_pack(TMP + "liguge.pck") == "liguge", "Ligugé se greffe depuis son pack")
	check(communes.ouvrir("liguge"), "le pack s'ouvre")
	var c: Commune = communes.commune("liguge")
	change_scene_to_file(str(c.data.scene))
	await attendre(12)
	var s: Node3D = current_scene
	var p: CharacterBody3D = s.player
	var liste := get_nodes_in_group("mobylettes")
	check(liste.size() == 1, "le socle gare une Mobylette à l'arrivée de Ligugé (%d)" % liste.size())
	if liste.is_empty():
		_fin()
		return
	var m: Node = liste[0]
	var mob: Node3D = m.mob
	var d := mob.global_position.distance_to(p.global_position)
	check(d < m.PORTEE * p.body_height, "elle attend à portée de l'habitant (%.2f)" % d)
	check(absf(mob.global_position.y - p.global_position.y) < 0.2, "elle est posée au sol (%.2f / %.2f)" % [mob.global_position.y, p.global_position.y])
	check(is_equal_approx(mob.scale.x, 3.0 * p.body_height), "à la taille de l'habitant (×%.3f, ×2,1 comme à Lyon)" % mob.scale.x)
	check(not mobylettes.voulue(s), "une scène qui a sa Mobylette n'en reçoit pas une deuxième")

	# Au doigt : on se met devant elle, le bouton dit « enfourcher ».
	var vers := mob.global_position - p.global_position
	vers.y = 0.0
	p.global_position = mob.global_position - vers.normalized() * p.body_height * 0.6
	p.global_rotation.y = atan2(-vers.x, -vers.z)
	await attendre(4)
	check(p.focus_target == m._zone, "la Mobylette est sous la main de l'habitant")
	check(m._prompt.visible and m._prompt.text == "E : enfourcher la Mobylette bleue", "l'invite dit « E : enfourcher » (%s)" % m._prompt.text)
	if tactile.active:
		check(tactile._act.visible and tactile._act.text == "enfourcher la Mobylette bleue", "au doigt, un bouton « enfourcher la Mobylette bleue » (%s)" % tactile._act.text)
		tactile._on_act()
	else:
		p.interact.emit(m._zone)
	await attendre(2)
	check(m.monte and mob.get_parent() == p, "on est en selle")
	check(is_equal_approx(p.speed, 1.5 * m.ALLURE), "on va plus vite qu'à pied (%.2f)" % p.speed)
	check(p.assis and p.avatar.position.y > 0.1, "assis sur la selle (%.2f)" % p.avatar.position.y)
	check(m._prompt.text == "V : descendre de la Mobylette", "l'invite dit « V : descendre »")
	if tactile.active:
		check(tactile._act.visible and tactile._act.text == "descendre de la Mobylette", "au doigt, un bouton « descendre de la Mobylette » (%s)" % tactile._act.text)
	p.auto_move = Vector3(0, 0, -1)
	await create_timer(0.6).timeout
	p.auto_move = Vector3.ZERO
	var ici := p.global_position
	if tactile.active:
		tactile._on_act()
	else:
		m.descendre()
	await attendre(3)
	check(not m.monte and mob.get_parent() == s, "on met pied à terre")
	check(Vector2(mob.global_position.x - ici.x, mob.global_position.z - ici.z).length() < 0.05, "elle reste là où on l'a laissée")
	check(is_equal_approx(p.speed, 1.5) and not p.assis, "l'habitant reprend sa marche")

	# Pas de Mobylette quand le manifeste n'en veut pas, ni dans une commune sans habitant.
	c.data["mobylette"] = false
	for n in get_nodes_in_group("mobylettes"):
		n.remove_from_group("mobylettes")
	for a in s.find_children("*", "Area3D", true, false):
		if str(a.get_meta("interact", "")) == "mobylette":
			a.set_meta("interact", "ancienne")
	check(not mobylettes.voulue(s), "« mobylette » : false dans le manifeste, pas de Mobylette")
	c.data.erase("mobylette")
	check(mobylettes.voulue(s), "sans lui, la commune en reçoit une")

	# Une Mobylette d'un paquet d'avant le socle 1.31 (Lyon) : son invite, enfant de la scène, devient un bouton.
	if tactile.active:
		var gs := GDScript.new()
		gs.source_code = "extends Node\nvar _prompt: Label\n"
		gs.reload()
		var ancienne := Node.new()
		ancienne.set_script(gs)
		ancienne.name = "Mobylette1"
		var l := Label.new()
		l.text = "V : descendre de la Mobylette"
		ancienne.add_child(l)
		ancienne.set("_prompt", l)
		m._prompt.visible = false
		m.set_process(false)
		(m._zone.get_child(0) as CollisionShape3D).disabled = true
		s.add_child(ancienne)
		tactile._anciennes_attente = 0.0
		await attendre(2)
		check(tactile._invite(s) == l, "l'invite d'une Mobylette de Lyon est lue au doigt")
		check(tactile._act.visible and tactile._act.text == "descendre de la Mobylette", "et devient le bouton « descendre » (%s)" % tactile._act.text)
	_fin()


func _fin() -> void:
	print("Mobylette du socle : %s" % ("tout va bien" if fails == 0 else "%d échec(s)" % fails))
	quit(1 if fails > 0 else 0)
