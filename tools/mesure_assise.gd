extends SceneTree
## L'assise des bâtiments d'une commune sur son relief (scripts/socle/assise.gd) : la commune s'ouvre comme chez
## un joueur (comme tools/parcours_commune.gd), puis chaque maison du façadier posée (un nœud qui porte les
## métadonnées w, d et type) est mesurée contre le terrain de la scène (sa fonction hauteur(x, z)) : de combien
## elle flotte au-dessus du point le plus bas de son emprise, si une assise la rattrape, et si le terrain monte
## plus haut que son égout (la maison enterrée). Sans rendu : --headless suffit.
##
##   godot --headless --path . -s tools/mesure_assise.gd -- <id> [--depuis=res://chemin/] [--repere=Ville] [--detail]
##   --repere   le nœud (chemin depuis la racine de la scène) dans le repère duquel hauteur(x, z) mesure le terrain :
##              la racine par défaut ; « Ville » pour Lyon, dont la ville est bâtie en mètres sous un nœud réduit
##
## Rend 1 si une maison flotte de plus de Assise.ECART_MIN sans assise. Les pieds de mur sont à lire (un mur mitoyen
## au-dessus d'un voisin plus bas part de son toit, pas du sol).

const TMP := "user://mesure_assise/"

func _init() -> void:
	await process_frame
	var id := ""
	var depuis := ""
	var detail := false
	var chemin_repere := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--depuis="):
			depuis = a.trim_prefix("--depuis=")
		elif a.begins_with("--repere="):
			chemin_repere = a.trim_prefix("--repere=")
		elif a == "--detail":
			detail = true
		elif not a.begins_with("--"):
			id = a
	if id == "":
		printerr("Usage : -- <id> [--depuis=res://chemin/]")
		quit(2)
		return
	if depuis == "":
		depuis = "res://communes/%s/" % id
	if not depuis.ends_with("/"):
		depuis += "/"
	DirAccess.make_dir_recursive_absolute(TMP)
	var pck := TMP + "%s.pck" % id
	var fichiers := {}
	_parcourir(depuis, depuis, "res://communes/%s/" % id, fichiers)
	var pk := PCKPacker.new()
	pk.pck_start(pck)
	for cible in fichiers:
		pk.add_file(cible, fichiers[cible])
	pk.flush()
	var communes: Node = root.get_node("Communes")
	communes.dossier_greffes = TMP
	var lu: String = communes.charger_pack(pck)
	if lu != "":
		id = lu
	var c: Commune = communes.commune(id)
	if c == null or not communes.ouvrir(id):
		printerr("« %s » ne s'ouvre pas : %s" % [id, str(communes.refus)])
		quit(2)
		return
	change_scene_to_file(str(c.data.scene))
	for i in 4:
		await process_frame
	var s: Node = current_scene
	if s == null or not s.has_method("hauteur"):
		printerr("La scène n'expose pas hauteur(x, z) : rien à mesurer.")
		quit(2)
		return
	var hauteur := Callable(s, "hauteur")
	var repere: Node3D = s.get_node(chemin_repere) if chemin_repere != "" else s
	var inverse := repere.global_transform.affine_inverse()
	var maisons := Assise.maisons(s)
	var flottent := 0
	var calees := 0
	var enterrees := 0
	var pire := 0.0
	var lignes := []
	for m: Node3D in maisons:
		var t := inverse * m.global_transform
		var sous := Assise.sol(hauteur, Assise.emprise(m, t))
		var ecart := t.origin.y - sous.x
		var assise := m.get_node_or_null("Assise") != null
		var egout := t.origin.y + float(m.get_meta("hauteur", 0.0)) * t.basis.y.length() * 0.6
		if sous.y > egout:
			enterrees += 1
		if ecart >= Assise.ECART_MIN:
			if assise:
				calees += 1
			else:
				flottent += 1
				pire = maxf(pire, ecart)
				lignes.append("  %s %s (%.1f, %.1f) : %.2f m de jour sous la maison" % [m.get_meta("type"), m.name, t.origin.x, t.origin.z, ecart])
	print("%s : %d maisons du façadier ; %d calées par leur assise, %d flottent encore (au pire %.2f m), %d enterrées au-delà de leur égout"
		% [c.nom, maisons.size(), calees, flottent, pire, enterrees])
	# les volumes : le pied de chaque mur des maillages « Murs… » (les volumes peints, murs seuls), contre le terrain sous lui
	var murs := []
	for n in s.find_children("*", "MeshInstance3D", true, false):
		var nom := String(n.name)
		if nom.begins_with("Murs") and n.mesh != null:
			murs.append(n)
	var pieds := 0
	var a_jour := 0
	var pire_mur := 0.0
	for mi: MeshInstance3D in murs:
		var tm := inverse * mi.global_transform
		for sf in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(sf)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var nt := (idx.size() if not idx.is_empty() else v.size()) / 3
			for k in nt:
				var p := []
				for j in 3:
					p.append(tm * v[idx[k * 3 + j] if not idx.is_empty() else k * 3 + j])
				var nrm: Vector3 = (p[2] - p[0]).cross(p[1] - p[0])
				if nrm.length() < 1e-6 or absf(nrm.normalized().y) > 0.1:
					continue
				var bas: float = minf(p[0].y, minf(p[1].y, p[2].y))
				var bord := p.filter(func(q): return q.y - bas < 0.01)
				if bord.size() != 2 or Vector2(bord[0].x, bord[0].z).distance_to(Vector2(bord[1].x, bord[1].z)) < 0.3:
					continue
				pieds += 1
				var ecart := -INF
				for j in 5:
					var q: Vector3 = bord[0].lerp(bord[1], (j + 0.5) / 5.0)
					ecart = maxf(ecart, q.y - float(hauteur.call(q.x, q.z)))
				# plus de 2 m au-dessus du sol, ce n'est pas un pied de mur : un mur mitoyen au-dessus du voisin,
				# une souche, une lucarne
				if ecart > 0.1 and ecart < 2.0:
					a_jour += 1
					pire_mur = maxf(pire_mur, ecart)
	# chaque mur est compté une fois par triangle de pied : un mur fait de deux triangles n'en a qu'un au pied. À
	# lire, sans faire échouer : un mur mitoyen qui monte au-dessus d'un voisin plus bas part de son toit, pas du sol
	print("%s : %d pieds de mur dans les volumes, %d laissent voir le jour (au pire %.2f m, sous 2 m)" % [c.nom, pieds, a_jour, pire_mur])
	if detail:
		lignes.sort()
		for l in lignes:
			print(l)
	quit(1 if flottent > 0 else 0)


func _parcourir(dossier: String, racine: String, cible: String, out: Dictionary) -> void:
	var d := DirAccess.open(dossier)
	for f in d.get_files():
		if f.ends_with(".md"):
			continue
		var chemin := dossier + f
		var dans_le_paquet := cible + chemin.trim_prefix(racine)
		if f.ends_with(".import"):
			out[dans_le_paquet] = chemin
			var cfg := ConfigFile.new()
			if cfg.load(chemin) == OK and cfg.has_section("remap"):
				for k in cfg.get_section_keys("remap"):
					var importe := str(cfg.get_value("remap", k))
					if k.begins_with("path") and FileAccess.file_exists(importe):
						out[importe] = importe
		elif not FileAccess.file_exists(chemin + ".import"):
			out[dans_le_paquet] = chemin
	for sub in d.get_directories():
		_parcourir(dossier + sub + "/", racine, cible, out)
