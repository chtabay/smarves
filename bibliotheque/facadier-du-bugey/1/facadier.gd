extends RefCounted
## Le façadier du Bugey : une maison de village en moellons calcaires, composée par type et graine. Le type fixe
## la silhouette (les étages, la largeur, la pente et la forme du toit, le rez-de-chaussée) ; la graine tire le
## reste (la pierre blonde, dorée ou grise, l'enduit d'une maison sur quatre, la couverture de tuile plate, de
## lauze ou d'ardoise, les volets de bois, persiennés ou de métal, les lucarnes, le balcon de bois, l'auvent, la
## lanterne, la vigne et les fleurs, les cheminées de pierre ou de brique). Repère : façade vers +Z, origine au pied
## de la façade, au milieu, le corps vers −Z ; en mètres.
##   load("res://bibliotheque/facadier-du-bugey/1/facadier.gd").maison(parent, Vector3.ZERO, "vigneronne", 4)
const Outils := preload("res://bibliotheque/facadier-du-bugey/1/outils.gd")

## Les types : les trois modules de rangée (R+2 au toit haut, R+1 au toit moyen, R+0 au toit bas), la maison
## bourgeoise, la ferme bugiste et sa grange, la maison vigneronne à escalier extérieur, la tour, la maison de
## village, le porche (la porte voûtée du bourg, ses bannières), la maison à pignon à redents et la chapelle.
const TYPES := ["r2", "r1", "r0", "bourgeoise", "ferme", "vigneronne", "tour", "village", "porche", "redents", "chapelle"]
## Pour chaque type : niveaux au-dessus du rez-de-chaussée, largeur (min, max), pente du toit (degrés),
## rez-de-chaussée, forme du toit.
const GABARITS := {
	"r2": [2, 7.5, 9.5, 46.0, "auto", "deux_pans"],
	"r1": [1, 7.0, 9.0, 40.0, "auto", "deux_pans"],
	"r0": [0, 6.5, 8.5, 33.0, "logis", "deux_pans"],
	"bourgeoise": [2, 10.0, 11.5, 38.0, "bourgeoise", "croupes"],
	"ferme": [1, 12.5, 14.5, 31.0, "grange", "deux_pans"],
	"vigneronne": [1, 8.2, 9.5, 37.0, "cave", "deux_pans"],
	"tour": [3, 4.4, 5.0, 58.0, "tour", "pyramide"],
	"village": [1, 6.0, 7.2, 40.0, "logis", "deux_pans"],
	"porche": [1, 7.6, 8.6, 44.0, "porche", "deux_pans"],
	"redents": [2, 7.4, 8.4, 50.0, "auto", "pignon"],
}
## Les calcaires du Bugey : la pierre blonde, dorée, grise, rousse ; et les enduits des maisons crépies.
const PIERRES := {"blonde": "e0cfa4", "calcaire": "d6c59c", "doree": "d2b17a", "grise": "c2b8a2", "rousse": "c9a476"}
const ENDUITS := {"ocre": "e2bf7a", "peche": "e6b58c", "creme": "e8d8b2", "sable": "dcc698"}
## Les couvertures : la tuile plate rouge et la vieillie, la lauze calcaire, la tuile mécanique, l'ardoise.
const COUVERTURES := {"tuile_rouge": ["c8583b", "a8452f"], "tuile_vieillie": ["9e5e40", "7f4b35"],
	"lauze": ["a6a092", "88837a"], "mecanique": ["d36b3c", "b3582e"], "ardoise": ["5a616e", "474e5a"]}
const VOLETS := ["6f8ea6", "8ea78c", "7a4b2f", "a9bcc6", "5f7d5a", "9b5b3d", "c9bfa6", "4f6f8f"]
const PORTES := ["6b4a32", "5a3a28", "4f6f8f", "7a2f2a", "5f7d5a", "8a6444"]
const TOILES := [["b8322c", "f3ead6"], ["4f8a4a", "f3ead6"], ["2f5f8f", "f3ead6"], ["d08a3a", "f3ead6"], ["b8322c", "b8322c"]]
const FLEURS := ["d04a8a", "e0605a", "b06ad0", "f2c14e", "f4f0e6", "e98a3a"]
const TAILLE := Color("e8dbb8")
const TAILLE_SOMBRE := Color("c9bb98")
const BOIS := Color("6b4a32")
const VERRE := Color("3f5268")
const FER := Color("2a2d30")
const SOMBRE := Color("2b2622")
const VERT := Color("5f9e33")
const TERRE_CUITE := Color("b8643f")

const RDC := 3.2
const ETAGE := 2.9


## Bâtit une maison sous parent, le pied de sa façade en p. Options, toutes facultatives : w et d (largeur et
## profondeur), niveaux, mur (« moellons » ou « enduit »), pierre (un nom de PIERRES ou un hexa), enduit (un nom
## d'ENDUITS ou un hexa), couverture (un nom de COUVERTURES), toit (« deux_pans », « croupes », « pyramide »,
## « pignon »), rdc (« logis », « boutique », « bourgeoise », « grange », « cave », « porche », « tour »), volets
## (« bois », « persiennes », « metal » ou « aucun »), volet (un hexa), balcon, auvent, lanterne, vigne, fleurs
## (vrai ou faux), lucarnes (un nombre), enseigne (le texte de la boutique), toile (deux hexas : le store),
## clocher (la chapelle : « tour » ou « mur »).
## Rend le nœud de la maison ; ses métadonnées : type, graine, w, d, hauteur (au faîte), porte (le seuil).
static func maison(parent: Node3D, p: Vector3, type: String, graine: int, opt := {}) -> Node3D:
	if not type in TYPES:
		type = "r1"
	var o := Outils.new(graine * 2654435 + TYPES.find(type) * 13)
	var r := o.rng
	var n := Node3D.new()
	n.name = "Maison"
	n.position = p
	parent.add_child(n)
	if type == "chapelle":
		return _chapelle(o, n, graine, opt)
	var g: Array = GABARITS[type]
	var w := float(opt.get("w", r.randf_range(g[1], g[2])))
	var d := float(opt.get("d", w if type == "tour" else r.randf_range(8.0, 9.5) + (1.5 if type == "ferme" else 0.0)))
	var niveaux := clampi(int(opt.get("niveaux", g[0])), 0, 4)
	var surcroit := 0.7 if niveaux <= 1 else 0.0
	var H := RDC + niveaux * ETAGE + surcroit
	var rdc := str(opt.get("rdc", g[4]))
	if rdc == "auto":
		rdc = "boutique" if r.randf() < 0.4 else "logis"
	var enduit_permis := not type in ["tour", "ferme", "porche"]
	var mur := str(opt.get("mur", "enduit" if enduit_permis and r.randf() < 0.25 else "moellons"))
	var pierre := _teinte(opt.get("pierre", PIERRES.keys()[r.randi() % PIERRES.size()]), PIERRES)
	var fond := pierre.darkened(0.16).lerp(Color("b8ab94"), 0.25)
	if mur == "enduit":
		fond = _teinte(opt.get("enduit", ENDUITS.keys()[r.randi() % ENDUITS.size()]), ENDUITS)
	var couv_nom := str(opt.get("couverture", _couverture(type, r)))
	if not COUVERTURES.has(couv_nom):
		couv_nom = "tuile_rouge"
	var couv: Array = (COUVERTURES[couv_nom] as Array).map(func(h): return Color(str(h)))
	var types_volets := ["bois", "bois", "bois", "persiennes", "metal"]
	var s := {
		"mur": mur,
		"pierre": pierre,
		"fond": fond,
		"volets": str(opt.get("volets", types_volets[r.randi() % types_volets.size()])),
		"volet": Color(str(opt.get("volet", VOLETS[r.randi() % VOLETS.size()]))),
		"bois": Color(PORTES[r.randi() % PORTES.size()]),
		"fleurs": bool(opt.get("fleurs", true)),
		"fleur": Color(FLEURS[r.randi() % FLEURS.size()]),
		"toile": opt.get("toile", TOILES[r.randi() % TOILES.size()]),
		"enseigne": str(opt.get("enseigne", "")),
		"balcon": bool(opt.get("balcon", niveaux >= 1 and r.randf() < 0.45 and type != "tour")),
		"auvent": bool(opt.get("auvent", r.randf() < 0.4)),
		"lanterne": bool(opt.get("lanterne", r.randf() < 0.35)),
		"chaines": mur == "enduit" or r.randf() < 0.55 or type in ["bourgeoise", "tour", "porche"],
		"couv": couv,
		"couv_nom": couv_nom,
		"trous": [],
		"saute": [],
	}
	if type == "tour":
		s.volets = "aucun"
	# le corps, le dos un peu plus sombre ; le soubassement enterré assied la maison sur un sol inégal
	o.boite(Transform3D(Basis(), Vector3(0, H * 0.5, -d * 0.5)), Vector3(w, H, d), [fond.darkened(0.05), fond.darkened(0.05), fond, fond, fond, fond.darkened(0.08)], Outils.DUR, true)
	o.boite(Transform3D(Basis(), Vector3(0, -0.15, -d * 0.5)), Vector3(w + 0.1, 0.32, d + 0.1), pierre.darkened(0.2))
	var forme := str(opt.get("toit", g[5]))
	var pente := deg_to_rad(float(g[3]))
	var hp := 0.0
	if forme == "deux_pans":
		hp = d * 0.5 * tan(pente) + 0.15
	var porte := _facade(o, w, niveaux, H, rdc, type, s, n)
	if forme == "pignon":
		_redents(o, w, H, pente, s)
	_mur(o, Transform3D(), w, 0.0, H, hp if forme == "pignon" else 0.0, s.trous, s)
	# les murs de côté, et leurs pignons ; le dos et ses jours
	var cotes := [Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w * 0.5, 0, -d * 0.5)), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-w * 0.5, 0, -d * 0.5))]
	for tc in cotes:
		_mur(o, tc, d, 0.0, H, hp, [], s)
	var dos := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -d))
	var trous_dos := []
	var nfd := clampi(int(w / 3.2), 1, 4)
	for e in niveaux + 1:
		for i in nfd:
			var x := -w * 0.5 + (i + 0.5) * w / nfd + r.randf_range(-0.3, 0.3)
			var y := 1.0 if e == 0 else RDC + (e - 1) * ETAGE + 0.8
			var pts := _baie(0.7, 1.0, "droite")
			var tf := dos * Transform3D(Basis(), Vector3(x, y, 0))
			o.profil(tf, pts, -0.02, 0.02, VERRE.darkened(0.2))
			_cadre(o, tf, pts, 0.12, 0.0, 0.1, TAILLE, TAILLE_SOMBRE)
			trous_dos.append(Rect2(x - 0.55, y - 0.2, 1.1, 1.4))
	_mur(o, dos, w, 0.0, H, hp if forme == "pignon" else 0.0, trous_dos, s)
	if s.chaines:
		_chaines(o, w, d, H, s)
	if opt.get("vigne", r.randf() < 0.45):
		_vigne(o, w, H, r, s)
	var faite := H
	var lucarnes := int(opt.get("lucarnes", {"r2": 1 + r.randi() % 2, "bourgeoise": 2, "porche": 1, "village": r.randi() % 2, "r1": 1 if r.randf() < 0.3 else 0}.get(type, 0)))
	match forme:
		"croupes":
			faite = _croupes(o, w, d, H, pente, s)
		"pyramide":
			faite = _pyramide(o, w, d, H, pente, s)
		"pignon":
			faite = _toit_pignon(o, w, d, H, pente, s)
		_:
			faite = _deux_pans(o, w, d, H, pente, s)
	if forme in ["deux_pans", "croupes"] and lucarnes > 0:
		var nf := clampi(int(round((w - 1.0) / 2.3)), 1, 5)
		var pas := (w - 1.2) / nf
		var choix := []
		if lucarnes == 1 or nf < 3:
			choix = [nf / 2]
		else:
			choix = [0, nf - 1] if nf <= 3 else [1, nf - 2]
		for i in choix:
			_lucarne(o, -w * 0.5 + 0.6 + pas * (i + 0.5), H, pente, s)
	# les cheminées : de pierre, ou couronnées de brique
	var brique := r.randf() < 0.35
	var nc := 1 if w < 7.0 or type == "tour" else 2
	if type != "tour":
		for i in nc:
			var x := (w * 0.5 - 0.7) * (1.0 if i == 0 else -1.0) * (1.0 if r.randf() < 0.5 else -1.0) if nc == 1 else (w * 0.5 - 0.7) * (1.0 if i == 0 else -1.0)
			var z := -d * 0.5 + (0.0 if forme != "pignon" else r.randf_range(-1.5, 1.5))
			if forme == "pignon":
				x = (w * 0.25) * (1.0 if i == 0 else -1.0)
				z = -d * 0.5 - 1.0 * i
			var y := _hauteur_toit(forme, x, z, w, d, H, pente)
			_cheminee(o, Vector3(x, y, z), brique, s)
	o.construire(n, "Corps")
	n.set_meta("type", type)
	n.set_meta("graine", graine)
	n.set_meta("w", w)
	n.set_meta("d", d)
	n.set_meta("hauteur", faite)
	n.set_meta("porte", porte)
	return n


static func _teinte(v, table: Dictionary) -> Color:
	var s := str(v)
	return Color(str(table.get(s, s)))


static func _couverture(type: String, r: RandomNumberGenerator) -> String:
	if type == "tour":
		return "tuile_rouge"
	if type == "bourgeoise":
		return ["tuile_vieillie", "ardoise"][r.randi() % 2]
	if type == "ferme":
		return ["tuile_vieillie", "lauze", "tuile_rouge"][r.randi() % 3]
	var t := r.randf()
	if t < 0.42:
		return "tuile_rouge"
	if t < 0.64:
		return "tuile_vieillie"
	if t < 0.8:
		return "ardoise"
	if t < 0.9:
		return "lauze"
	return "mecanique"


## La hauteur du toit au-dessus du point (x, z), pour y poser une cheminée.
static func _hauteur_toit(forme: String, x: float, z: float, w: float, d: float, H: float, pente: float) -> float:
	match forme:
		"pignon":
			return H + 0.15 + (w * 0.5 - absf(x)) * tan(pente)
		"croupes":
			return H + 0.15 + minf(d * 0.5 - absf(z + d * 0.5), w * 0.5 - absf(x)) * tan(pente)
	return H + 0.15 + (d * 0.5 - absf(z + d * 0.5)) * tan(pente)


## La façade, au repère de la maison (x en travers, y vers le haut, z vers la rue) : le rez-de-chaussée et les
## étages, leurs fenêtres aux volets ouverts, le balcon de bois, les jours de grenier. Rend le seuil de la porte.
static func _facade(o: Outils, w: float, niveaux: int, H: float, rdc: String, type: String, s: Dictionary, n: Node3D) -> Vector3:
	var r := o.rng
	var t := Transform3D()
	var nf := clampi(int(round((w - 1.0) / 2.3)), 1, 5)
	var pas := (w - 1.2) / nf
	var xs: Array[float] = []
	for i in nf:
		xs.append(-w * 0.5 + 0.6 + pas * (i + 0.5))
	var porte := Vector3(0, 0, 0.6)
	match rdc:
		"boutique":
			porte = _rdc_boutique(o, t, w, xs, s, n)
		"bourgeoise":
			porte = _rdc_bourgeoise(o, t, w, xs, s, n)
		"grange":
			porte = _rdc_grange(o, t, w, s)
		"cave":
			porte = _rdc_cave(o, t, w, s)
		"porche":
			porte = _rdc_porche(o, t, w, xs, s)
		"tour":
			porte = _porte(o, t, 0.0, s, "cintre", 1.0, 2.3)
		_:
			porte = _rdc_logis(o, t, xs, s)
	# les étages : les fenêtres alignées sur les travées, le balcon de bois au premier
	var ib := -1
	if s.balcon and niveaux >= 1:
		ib = nf / 2
	for e in niveaux:
		var y0 := RDC + e * ETAGE + 0.75
		var haute := 1.45 if e == 0 else 1.3
		for i in xs.size():
			var x: float = xs[i]
			if type == "tour":
				x += 0.35 * (1.0 if e % 2 == 0 else -1.0)
				_fenetre(o, t, Vector3(x, y0 + 0.2, 0), 0.6, 1.0, s, false, false)
				continue
			var saute := false
			for z in s.saute:
				var zone: Vector2 = z
				if e == 0 and x > zone.x - 0.6 and x < zone.y + 0.6:
					saute = true
			if saute:
				continue
			if e == 0 and i == ib:
				# la porte-fenêtre et son balcon de bois
				_fenetre(o, t, Vector3(x, RDC + 0.12, 0), 0.95, 2.15, s, true, false)
				_balcon_bois(o, t, Vector3(x, RDC + 0.1, 0), minf(pas + 0.6, 2.8), s)
				continue
			_fenetre(o, t, Vector3(x, y0, 0), 0.9, haute, s, true, s.fleurs and r.randf() < 0.4)
	# les jours de grenier, sous l'égout, quand il y a un surcroît
	if niveaux <= 1 and type != "tour":
		var y := H - 0.55
		for i in xs.size():
			if r.randf() < 0.6:
				var x: float = xs[i]
				o.boite(t * Transform3D(Basis(), Vector3(x, y, 0.01)), Vector3(0.42, 0.32, 0.02), SOMBRE)
				_cadre(o, t * Transform3D(Basis(), Vector3(x, y - 0.16, 0)), _baie(0.42, 0.32, "droite"), 0.1, 0.0, 0.08, TAILLE, TAILLE_SOMBRE)
				s.trous.append(Rect2(x - 0.4, y - 0.3, 0.8, 0.6))
	if type == "redents" or (type == "r2" and r.randf() < 0.4):
		# l'oculus, haut sur la façade ou dans le pignon
		var yo := H + 1.4 if type == "redents" else H - 0.65
		if type == "r2":
			yo = RDC + niveaux * ETAGE - 0.2
		if type == "redents" or ib < 0:
			_oculus(o, t, Vector3(0, yo, 0), 0.38, s)
	return porte


## Le rez-de-chaussée d'habitation : la porte (pleine, à imposte ou cintrée) sur une travée, ses fenêtres aux
## autres ; l'auvent de bois sur la porte, la lanterne à côté.
static func _rdc_logis(o: Outils, t: Transform3D, xs: Array[float], s: Dictionary) -> Vector3:
	var r := o.rng
	var ip := r.randi() % xs.size()
	if xs.size() == 3 and r.randf() < 0.5:
		ip = 1
	var formes := ["pleine", "imposte", "cintre"]
	var forme: String = formes[r.randi() % 3]
	var porte := _porte(o, t, xs[ip], s, forme)
	for i in xs.size():
		if i != ip:
			_fenetre(o, t, Vector3(xs[i], 0.95, 0), 0.9, 1.3, s, true, s.fleurs and r.randf() < 0.5)
	_details_porte(o, t, xs[ip], 2.35 if forme != "cintre" else 2.5, s)
	return porte


static func _details_porte(o: Outils, t: Transform3D, x: float, h: float, s: Dictionary) -> void:
	if s.auvent:
		_auvent(o, t, Vector3(x, h + 0.45, 0), 1.9, s)
	if s.lanterne:
		_lanterne(o, t, Vector3(x + 1.0, h - 0.1, 0))


## La boutique : une large baie surbaissée à claveaux, sa devanture de bois, la porte vitrée, l'enseigne et le store
## à bandes ; la porte du logis sur une autre travée, s'il en reste.
static func _rdc_boutique(o: Outils, t: Transform3D, w: float, xs: Array[float], s: Dictionary, n: Node3D) -> Vector3:
	var r := o.rng
	var ib := 0 if xs.size() < 3 else r.randi() % (xs.size() - 1)
	var deux := xs.size() >= 3
	var x: float = (xs[ib] + xs[ib + 1]) * 0.5 if deux else xs[ib]
	var l := minf((xs[1] - xs[0]) * (1.0 if deux else 0.0) + 1.9, 3.6) if xs.size() > 1 else minf(w - 2.0, 2.6)
	var h := 2.7
	var tf := t * Transform3D(Basis(), Vector3(x, 0.0, 0))
	var pts := _baie(l, h, "surbaisse", 0.35)
	var bois: Color = s.bois
	o.profil(tf, pts, -0.02, 0.02, bois)
	_claveaux(o, tf, l, h, "surbaisse", 0.35, 0.34)
	_cadre(o, tf, pts, 0.03, 0.0, 0.18, TAILLE, TAILLE_SOMBRE)
	# la devanture : vitrines à petits bois, soubassement, la porte vitrée au milieu
	var lv := (l - 1.1) * 0.5
	for cote in [-1.0, 1.0]:
		var xv: float = cote * (0.55 + lv * 0.5)
		o.boite(tf * Transform3D(Basis(), Vector3(xv, 1.45, 0.04)), Vector3(lv - 0.12, 1.5, 0.03), VERRE.lightened(0.15))
		o.boite(tf * Transform3D(Basis(), Vector3(xv, 0.38, 0.05)), Vector3(lv - 0.05, 0.62, 0.05), bois.darkened(0.15))
		for k in 2:
			o.boite(tf * Transform3D(Basis(), Vector3(xv - (lv - 0.12) * 0.5 + (k + 1) * (lv - 0.12) / 3.0, 1.45, 0.06)), Vector3(0.04, 1.5, 0.03), bois)
		o.boite(tf * Transform3D(Basis(), Vector3(xv, 1.45, 0.06)), Vector3(lv - 0.12, 0.04, 0.03), bois)
	o.boite(tf * Transform3D(Basis(), Vector3(0, 1.1, 0.04)), Vector3(0.9, 2.15, 0.03), bois.darkened(0.2))
	o.boite(tf * Transform3D(Basis(), Vector3(0, 1.3, 0.06)), Vector3(0.6, 1.4, 0.02), VERRE.lightened(0.18))
	o.boite(t * Transform3D(Basis(), Vector3(x, 0.08, 0.35)), Vector3(l + 0.4, 0.16, 0.5), TAILLE_SOMBRE)
	s.trous.append(Rect2(x - l * 0.5 - 0.5, -0.2, l + 1.0, h + 0.7))
	# l'enseigne peinte au-dessus de la baie, et l'enseigne de fer forgé en potence
	var y_ens := h + 0.55
	o.boite(t * Transform3D(Basis(), Vector3(x, y_ens, 0.06)), Vector3(l * 0.8, 0.45, 0.06), Color("efe4c8"))
	o.boite(t * Transform3D(Basis(), Vector3(x, y_ens, 0.05)), Vector3(l * 0.8 + 0.1, 0.55, 0.04), bois)
	s.trous.append(Rect2(x - l * 0.45, y_ens - 0.35, l * 0.9, 0.7))
	var texte: String = s.enseigne
	if texte != "":
		var lab := Label3D.new()
		lab.text = texte
		lab.font_size = 64
		lab.pixel_size = 0.0055
		lab.modulate = bois.darkened(0.2)
		lab.outline_size = 0
		lab.transform = t * Transform3D(Basis(), Vector3(x, y_ens, 0.1))
		n.add_child(lab)
	_store(o, t, Vector3(x, h + 0.12, 0), l + 0.2, s)
	var xp := x + (l * 0.5 + 0.6) * (1.0 if r.randf() < 0.5 else -1.0)
	_potence(o, t, Vector3(clampf(xp, -w * 0.5 + 0.5, w * 0.5 - 0.5), h + 0.9, 0), s)
	# la porte du logis, et les fenêtres des travées restantes
	var porte := t * Vector3(x, 0, 0.8)
	var reste := []
	for i in xs.size():
		var xi: float = xs[i]
		if absf(xi - x) > l * 0.5 + 0.7:
			reste.append(xi)
	if not reste.is_empty():
		var xl: float = reste[0] if absf(reste[0]) > absf(reste[reste.size() - 1]) else reste[reste.size() - 1]
		_porte(o, t, xl, s, "pleine")
		for xi in reste:
			if xi != xl:
				_fenetre(o, t, Vector3(xi, 0.95, 0), 0.9, 1.3, s, true, false)
	return porte


## Le rez-de-chaussée de la maison bourgeoise : la grande porte à imposte au milieu, sous sa corniche, les hautes
## fenêtres de part et d'autre, le cordon de pierre de taille au plancher.
static func _rdc_bourgeoise(o: Outils, t: Transform3D, w: float, xs: Array[float], s: Dictionary, n: Node3D) -> Vector3:
	var r := o.rng
	var mid := xs.size() / 2
	var porte := _porte(o, t, xs[mid] if xs.size() % 2 == 1 else 0.0, s, "imposte", 1.35, 2.7)
	var xp: float = xs[mid] if xs.size() % 2 == 1 else 0.0
	o.boite(t * Transform3D(Basis(), Vector3(xp, 3.2, 0.2)), Vector3(2.3, 0.18, 0.4), TAILLE)
	for cote in [-1.0, 1.0]:
		o.boite(t * Transform3D(Basis(), Vector3(xp + cote * 0.98, 1.55, 0.12)), Vector3(0.26, 3.1, 0.24), TAILLE)
	for i in xs.size():
		var x: float = xs[i]
		if absf(x - xp) > 0.8:
			_fenetre(o, t, Vector3(x, 0.85, 0), 0.95, 1.6, s, true, false)
	o.boite(t * Transform3D(Basis(), Vector3(0, RDC + 0.1, 0.07)), Vector3(w + 0.04, 0.22, 0.14), TAILLE)
	s.trous.append(Rect2(-w * 0.5, RDC - 0.05, w, 0.3))
	if s.lanterne:
		_lanterne(o, t, Vector3(xp - 1.4, 2.3, 0))
		_lanterne(o, t, Vector3(xp + 1.4, 2.3, 0))
	return porte


## La grange de la ferme bugiste : la grande porte charretière sous son arc de pierre, ses vantaux de planches,
## la trappe du fenil au-dessus ; le logis de l'autre côté, sa porte et sa fenêtre.
static func _rdc_grange(o: Outils, t: Transform3D, w: float, s: Dictionary) -> Vector3:
	var r := o.rng
	var cote := 1.0 if r.randf() < 0.5 else -1.0
	var l := 3.5
	var h := 3.9
	var xg := cote * (w * 0.5 - 0.9 - l * 0.5)
	var forme := "plein_cintre" if r.randf() < 0.5 else "surbaisse"
	var tf := t * Transform3D(Basis(), Vector3(xg, 0.0, 0))
	var pts := _baie(l, h, forme, 0.6)
	var bois := Color("7a5636")
	o.profil(tf, pts, -0.02, 0.02, bois)
	for k in int(l / 0.22):
		var x := -l * 0.5 + (k + 0.5) * l / int(l / 0.22)
		o.boite(tf * Transform3D(Basis(), Vector3(x, (h - 0.7) * 0.5, 0.03)), Vector3(0.025, h - 0.7, 0.02), bois.darkened(0.25))
	o.boite(tf * Transform3D(Basis(), Vector3(0, (h - 0.3) * 0.5, 0.04)), Vector3(0.06, h - 0.3, 0.04), bois.darkened(0.35))
	for y in [0.6, 2.0]:
		o.boite(tf * Transform3D(Basis(), Vector3(0, y, 0.05)), Vector3(l - 0.1, 0.14, 0.04), bois.darkened(0.15))
	# le portillon dans le vantail
	o.boite(tf * Transform3D(Basis(), Vector3(l * 0.25, 1.0, 0.06)), Vector3(0.8, 1.8, 0.02), bois.darkened(0.3))
	_claveaux(o, tf, l, h, forme, 0.6, 0.42)
	_cadre(o, tf, pts, 0.03, 0.0, 0.22, TAILLE, TAILLE_SOMBRE)
	s.trous.append(Rect2(xg - l * 0.5 - 0.6, -0.2, l + 1.2, h + 0.7))
	# la trappe du fenil, au-dessus
	var yf := RDC + ETAGE * 0.5 + 0.3
	var pf := _baie(1.2, 1.0, "droite")
	var tff := t * Transform3D(Basis(), Vector3(xg, yf, 0))
	o.profil(tff, pf, -0.02, 0.02, bois.darkened(0.1))
	for k in 5:
		o.boite(tff * Transform3D(Basis(), Vector3(-0.48 + k * 0.24, 0.5, 0.03)), Vector3(0.02, 1.0, 0.02), bois.darkened(0.3))
	_cadre(o, tff, pf, 0.16, 0.0, 0.14, Color("8a6444"), Color("6b4a32"))
	o.boite(t * Transform3D(Basis(), Vector3(xg, yf + 1.35, 0.5)), Vector3(0.14, 0.14, 1.0), Color("6b4a32"))
	o.cylindre(t * Transform3D(Basis(), Vector3(xg, yf + 0.7, 0.95)), 0.08, 0.08, 0.6, 6, Color("8a6444"))
	s.trous.append(Rect2(xg - 0.9, yf - 0.3, 1.8, 1.8))
	s.saute.append(Vector2(xg - l * 0.5, xg + l * 0.5))
	# le logis
	var xl := -cote * (w * 0.5 - 2.2)
	var porte := _porte(o, t, xl, s, "pleine")
	_fenetre(o, t, Vector3(xl + cote * 1.8, 0.95, 0), 0.9, 1.3, s, true, s.fleurs)
	_details_porte(o, t, xl, 2.35, s)
	return porte


## La maison vigneronne : la porte voûtée de la cave au rez-de-chaussée, l'escalier de pierre qui monte le long
## de la façade au logis de l'étage, son palier, son parapet et l'auvent sur la porte.
static func _rdc_cave(o: Outils, t: Transform3D, w: float, s: Dictionary) -> Vector3:
	var r := o.rng
	var pierre: Color = s.pierre
	var marche := 0.2
	var giron := 0.3
	var nb := int(RDC / marche)
	var lp := 1.5
	var x1 := w * 0.5 - 0.3
	var xp := x1 - lp
	var x0 := xp - nb * giron
	var prof := 1.15
	# l'échiffre plein sous les marches, et le palier
	var mass := PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, RDC), Vector2(xp, RDC), Vector2(x0, marche)])
	o.profil(t * Transform3D(Basis(), Vector3.ZERO), mass, 0.0, prof, [pierre.darkened(0.04), pierre.darkened(0.12)])
	for k in nb:
		var x := x0 + k * giron + giron * 0.5
		o.boite(t * Transform3D(Basis(), Vector3(x, (k + 1) * marche - 0.04, prof * 0.5 + 0.02)), Vector3(giron + 0.04, 0.08, prof + 0.04), TAILLE_SOMBRE)
	o.boite(t * Transform3D(Basis(), Vector3((xp + x1) * 0.5, RDC - 0.04, prof * 0.5 + 0.02)), Vector3(lp + 0.04, 0.1, prof + 0.06), TAILLE_SOMBRE)
	o.collisions.append([t * Transform3D(Basis(), Vector3((x0 + x1) * 0.5, RDC * 0.25, prof * 0.5)), Vector3(x1 - x0, RDC * 0.5, prof)])
	# le parapet de pierre, rampant, et son chaperon
	var par := PackedVector2Array([Vector2(x0, marche), Vector2(xp, RDC), Vector2(x1, RDC), Vector2(x1, RDC + 0.85), Vector2(xp, RDC + 0.85), Vector2(x0, marche + 0.85)])
	o.profil(t * Transform3D(Basis(), Vector3.ZERO), par, prof - 0.18, prof, pierre)
	var pente_r := (RDC - marche) / (xp - x0)
	var bornes := func(ya: float, yb: float) -> Vector2:
		return Vector2(x0 + maxf(0.0, (yb - marche - 0.85) / pente_r) + 0.03, x1 - 0.03)
	_mur(o, t * Transform3D(Basis(), Vector3(0, 0, prof)), w, 0.0, RDC + 0.8, 0.0, [], s, bornes)
	var rampe := Vector3(xp - x0, RDC - marche, 0)
	var lr := rampe.length()
	var ang := atan2(rampe.y, rampe.x)
	o.boite(t * Transform3D(Basis(Vector3.BACK, ang), Vector3((x0 + xp) * 0.5, (marche + RDC) * 0.5 + 0.9, prof - 0.09)), Vector3(lr, 0.1, 0.28), TAILLE)
	o.boite(t * Transform3D(Basis(), Vector3((xp + x1) * 0.5, RDC + 0.9, prof - 0.09)), Vector3(lp, 0.1, 0.28), TAILLE)
	if s.fleurs:
		for k in 3:
			var q := Vector3(xp + 0.3 + k * 0.45, RDC + 1.05, prof - 0.09)
			o.boite(t * Transform3D(Basis(), q), Vector3(0.24, 0.2, 0.24), TERRE_CUITE)
			o.boule(t * (q + Vector3(0, 0.22, 0)), Vector3(0.2, 0.16, 0.2), VERT, 0.25, Outils.FEUILLE, 0.06, 0.3)
			o.boule(t * (q + Vector3(0, 0.3, 0.05)), Vector3(0.12, 0.08, 0.12), s.fleur, 0.3, Outils.FEUILLE, 0.08, 0.3)
	# la porte du logis sur le palier, son auvent
	var xd := (xp + x1) * 0.5
	var tp := t * Transform3D(Basis(), Vector3(xd, RDC, 0))
	_porte(o, tp, 0.0, s, "pleine", 1.0, 2.1)
	_auvent(o, t, Vector3(xd, RDC + 2.55, 0), 2.1, s)
	s.saute.append(Vector2(xd - 0.6, xd + 0.6))
	# la porte de la cave, voûtée, à gauche de l'escalier ; une fenêtre basse sous l'escalier, sinon
	var xc := (x0 - w * 0.5) * 0.5
	if x0 - (-w * 0.5) < 2.0:
		xc = x0 + 1.2
	var lc := 1.5
	var tf := t * Transform3D(Basis(), Vector3(xc, 0.0, 0 if x0 - (-w * 0.5) >= 2.0 else prof))
	var pc := _baie(lc, 2.1, "surbaisse", 0.3)
	o.profil(tf, pc, -0.02, 0.02, Color("5a3a28"))
	for k in 6:
		o.boite(tf * Transform3D(Basis(), Vector3(-lc * 0.5 + (k + 0.5) * lc / 6.0, 0.9, 0.03)), Vector3(0.02, 1.8, 0.02), Color("3e281c"))
	_claveaux(o, tf, lc, 2.1, "surbaisse", 0.3, 0.3)
	_cadre(o, tf, pc, 0.03, 0.0, 0.16, TAILLE, TAILLE_SOMBRE)
	s.trous.append(Rect2(xc - lc * 0.5 - 0.45, -0.2, lc + 0.9, 2.8))
	# les tonneaux devant la cave
	for k in 2:
		var q := Vector3(xc + (k - 0.5) * 1.1 + (0.0 if x0 - (-w * 0.5) >= 2.0 else 0.0), 0, 0.55 + (0.0 if x0 - (-w * 0.5) >= 2.0 else prof))
		if x0 - (-w * 0.5) >= 2.0 or k == 0:
			o.cylindre(t * Transform3D(Basis(), q), 0.3, 0.3, 0.8, 10, Color("8a5a36"))
			for y in [0.12, 0.66]:
				o.cylindre(t * Transform3D(Basis(), q + Vector3(0, y, 0)), 0.315, 0.315, 0.05, 10, FER)
	return t * Vector3(x0 - 0.4, 0, prof * 0.5)


## Le porche : la porte voûtée du bourg sous la maison, le passage sombre, les claveaux et la clef, les bannières
## pendues de part et d'autre, les fenêtres de l'étage.
static func _rdc_porche(o: Outils, t: Transform3D, w: float, xs: Array[float], s: Dictionary) -> Vector3:
	var l := 3.4
	var h := 4.2
	var tf := t * Transform3D(Basis(), Vector3(0, 0, 0))
	var pts := _baie(l, h, "plein_cintre")
	o.profil(tf, pts, 0.0, 0.03, SOMBRE)
	_cadre(o, tf, pts, 0.02, 0.0, 0.42, TAILLE, TAILLE_SOMBRE.darkened(0.1))
	_claveaux(o, tf, l, h, "plein_cintre", 0.0, 0.55, 0.42)
	# le pavé du passage qui file sous la maison
	o.boite(t * Transform3D(Basis(), Vector3(0, 0.02, 0.2)), Vector3(l, 0.04, 0.4), Color("b8ab90"))
	s.trous.append(Rect2(-l * 0.5 - 0.8, -0.2, l + 1.6, h + 1.0))
	# les bannières, rouge et or, pendues à leurs hampes de fer
	for cote in [-1.0, 1.0]:
		var x: float = cote * (l * 0.5 + 0.95)
		var y := RDC + 0.6
		o.boite(t * Transform3D(Basis(), Vector3(x, y, 0.3)), Vector3(0.05, 0.05, 0.6), FER)
		o.boite(t * Transform3D(Basis(), Vector3(x, y, 0.58)), Vector3(0.9, 0.04, 0.04), FER)
		var ban := PackedVector2Array([Vector2(-0.38, 0), Vector2(0.38, 0), Vector2(0.38, -1.5), Vector2(0, -1.85), Vector2(-0.38, -1.5)])
		o.profil(t * Transform3D(Basis(), Vector3(x, y - 0.03, 0.58)), ban, -0.015, 0.015, Color("a8302a"))
		o.profil(t * Transform3D(Basis(), Vector3(x, y - 0.03, 0.58)), Outils.grossir(ban, 0.05), -0.008, 0.008, Color("e0b040"))
		o.boite(t * Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(x, y - 0.8, 0.6)), Vector3(0.32, 0.32, 0.03), Color("e0b040"))
		s.trous.append(Rect2(x - 0.6, y - 2.0, 1.2, 2.2))
	return t * Vector3(0, 0, 0.6)


## Une fenêtre du Bugey : rectangulaire, dans son encadrement de pierre de taille, l'appui saillant, le linteau
## monolithe, les petits bois ; les volets ouverts contre le mur (de bois à barres et écharpe, persiennés, ou de
## métal repliés) ; une jardinière fleurie sous l'appui.
static func _fenetre(o: Outils, t: Transform3D, p: Vector3, l: float, h: float, s: Dictionary, volets: bool, jardiniere: bool) -> void:
	var tf := t * Transform3D(Basis(), p)
	var pts := _baie(l, h, "droite")
	o.profil(tf, pts, -0.02, 0.02, VERRE)
	_cadre(o, tf, pts, 0.13, 0.0, 0.12, TAILLE, TAILLE_SOMBRE)
	var blanc := Color("efe9dc")
	o.boite(tf * Transform3D(Basis(), Vector3(0, h * 0.5, 0.04)), Vector3(0.05, h, 0.04), blanc)
	for k in 2 if h > 1.2 else 1:
		o.boite(tf * Transform3D(Basis(), Vector3(0, h * (0.36 + k * 0.3) if h > 1.2 else h * 0.5, 0.04)), Vector3(l, 0.04, 0.04), blanc)
	o.boite(tf * Transform3D(Basis(), Vector3(0, -0.06, 0.13)), Vector3(l + 0.42, 0.12, 0.26), TAILLE_SOMBRE.lightened(0.08))
	o.boite(tf * Transform3D(Basis(), Vector3(0, h + 0.13, 0.08)), Vector3(l + 0.5, 0.26, 0.16), TAILLE)
	var large := l * 0.5 + 0.2
	var kind: String = s.volets
	if volets and kind != "aucun":
		var vc: Color = s.volet
		for cote in [-1.0, 1.0]:
			var x: float = cote * (l * 0.5 + 0.14 + l * 0.25)
			var lv := l * 0.5
			o.boite(tf * Transform3D(Basis(), Vector3(x, h * 0.5, 0.06)), Vector3(lv, h, 0.04), vc)
			match kind:
				"persiennes":
					for k in int(h / 0.14):
						o.boite(tf * Transform3D(Basis(), Vector3(x, 0.08 + k * 0.14, 0.085)), Vector3(lv - 0.08, 0.025, 0.02), vc.darkened(0.18))
				"metal":
					for k in 4:
						o.boite(tf * Transform3D(Basis(), Vector3(x - lv * 0.5 + (k + 0.5) * lv / 4.0, h * 0.5, 0.085)), Vector3(0.03, h - 0.04, 0.02), vc.lightened(0.15))
				_:
					for k in 2:
						o.boite(tf * Transform3D(Basis(), Vector3(x - lv * 0.5 + (k + 1) * lv / 3.0, h * 0.5, 0.082)), Vector3(0.015, h, 0.012), vc.darkened(0.2))
					for y in [h * 0.18, h * 0.82]:
						o.boite(tf * Transform3D(Basis(), Vector3(x, y, 0.09)), Vector3(lv - 0.04, 0.09, 0.025), vc.darkened(0.1))
					var diag := Vector2(lv - 0.08, h * 0.64)
					o.boite(tf * Transform3D(Basis(Vector3.BACK, atan2(diag.y, diag.x) * cote), Vector3(x, h * 0.5, 0.09)), Vector3(diag.length(), 0.08, 0.025), vc.darkened(0.1))
			o.boite(tf * Transform3D(Basis(), Vector3(cote * (l * 0.5 + 0.1), h * 0.15, 0.06)), Vector3(0.08, 0.04, 0.06), FER)
		large = l + 0.4
	if jardiniere:
		o.boite(tf * Transform3D(Basis(), Vector3(0, 0.08, 0.32)), Vector3(l * 0.85, 0.2, 0.22), TERRE_CUITE)
		for i in 4:
			var q := Vector3(-l * 0.32 + i * l * 0.213, 0.24, 0.33)
			o.boule(tf * q, Vector3(0.16, 0.12, 0.13), VERT, 0.25, Outils.FEUILLE, 0.06, 0.2)
			o.boule(tf * (q + Vector3(0, 0.07, 0.04)), Vector3(0.1, 0.07, 0.09), s.fleur.lightened(o.rng.randf_range(-0.1, 0.12)), 0.3, Outils.FEUILLE, 0.08, 0.2)
			if i % 2 == 0:
				o.boule(tf * (q + Vector3(0.05, -0.25, 0.06)), Vector3(0.08, 0.22, 0.06), VERT.darkened(0.08), 0.3, Outils.FEUILLE, 0.05, 0.3)
	s.trous.append(Rect2(p.x - l * 0.5 - 0.3, p.y - 0.2, l + 0.6, h + 0.5))
	if large > l:
		s.trous.append(Rect2(p.x - l - 0.1, p.y + 0.02, l * 2.0 + 0.2, h - 0.04))


## Une porte : pleine (de planches), à imposte vitrée, ou cintrée ; son encadrement de pierre, le linteau ou la clef,
## la marche du seuil. Rend le seuil.
static func _porte(o: Outils, t: Transform3D, x: float, s: Dictionary, forme: String, l := 1.1, h := 2.25) -> Vector3:
	var tf := t * Transform3D(Basis(), Vector3(x, 0.15, 0))
	var pts := _baie(l, h, "plein_cintre" if forme == "cintre" else "droite")
	var bois: Color = s.bois
	o.profil(tf, pts, -0.02, 0.02, bois)
	var hp := h - (l * 0.5 if forme == "cintre" else 0.0)
	if forme == "imposte":
		hp = h - 0.55
		o.boite(tf * Transform3D(Basis(), Vector3(0, h - 0.27, 0.025)), Vector3(l - 0.12, 0.42, 0.02), VERRE.lightened(0.1))
		o.boite(tf * Transform3D(Basis(), Vector3(0, hp, 0.04)), Vector3(l, 0.1, 0.05), bois.darkened(0.2))
		o.boite(tf * Transform3D(Basis(), Vector3(0, h - 0.27, 0.04)), Vector3(0.04, 0.42, 0.03), bois.darkened(0.2))
	var nl := int(l / 0.17)
	for k in nl:
		o.boite(tf * Transform3D(Basis(), Vector3(-l * 0.5 + (k + 1) * l / (nl + 1), hp * 0.5, 0.03)), Vector3(0.018, hp, 0.015), bois.darkened(0.22))
	o.boite(tf * Transform3D(Basis(), Vector3(l * 0.32, 1.0, 0.05)), Vector3(0.06, 0.06, 0.05), Color("2a2a2a"))
	_cadre(o, tf, pts, 0.17, 0.0, 0.14, TAILLE, TAILLE_SOMBRE)
	if forme == "cintre":
		o.boite(tf * Transform3D(Basis(), Vector3(0, h + 0.12, 0.1)), Vector3(0.26, 0.32, 0.16), TAILLE.lightened(0.04))
	else:
		o.boite(tf * Transform3D(Basis(), Vector3(0, h + 0.14, 0.09)), Vector3(l + 0.6, 0.3, 0.18), TAILLE)
	o.boite(t * Transform3D(Basis(), Vector3(x, 0.075, 0.25)), Vector3(l + 0.6, 0.15, 0.5), TAILLE_SOMBRE)
	s.trous.append(Rect2(x - l * 0.5 - 0.45, -0.2, l + 0.9, h + 0.7))
	return t * Vector3(x, 0, 0.7)


## Les claveaux d'un arc (plein cintre ou surbaissé de flèche f) de largeur l et de hauteur h, en pierre de taille,
## la clef plus haute ; les piédroits harpés jusqu'à la naissance.
static func _claveaux(o: Outils, t: Transform3D, l: float, h: float, forme: String, f: float, e: float, z := 0.2) -> void:
	var R := l * 0.5
	var a0 := 0.0
	var a1 := PI
	if forme == "surbaisse":
		R = (l * l * 0.25 + f * f) / (2.0 * f)
		var a := asin(clampf(l * 0.5 / R, -1.0, 1.0))
		a0 = PI * 0.5 - a
		a1 = PI * 0.5 + a
	var c := Vector2(0, h - R)
	var n := maxi(5, int(round((a1 - a0) * (R + e * 0.5) / 0.32)))
	if n % 2 == 0:
		n += 1
	for k in n:
		var a := lerpf(a0, a1, (k + 0.5) / n)
		var dir := Vector2(cos(a), sin(a))
		var clef := k == n / 2
		var ek := e * (1.25 if clef else 1.0)
		var q := c + dir * (R + ek * 0.5)
		var tang := (a1 - a0) / n * (R + ek * 0.5)
		var col := TAILLE.darkened(0.06 if k % 2 == 0 else 0.0)
		o.boite(t * Transform3D(Basis(Vector3.BACK, a), Vector3(q.x, q.y, z * 0.5 + (0.03 if clef else 0.0))), Vector3(ek, tang - 0.03, z), col)
	# les piédroits
	var y := 0.0
	var k := 0
	var yn := c.y + R * sin(a0)
	while y < yn - 0.15:
		var hb := minf(0.42, yn - y)
		var lb := 0.5 if k % 2 == 0 else 0.32
		for cote in [-1.0, 1.0]:
			o.boite(t * Transform3D(Basis(), Vector3(cote * (l * 0.5 + lb * 0.5), y + hb * 0.5, z * 0.5)), Vector3(lb, hb - 0.03, z), TAILLE.darkened(0.03 * (k % 2)))
		y += hb
		k += 1


## L'auvent de bois sur une porte : un pan de tuiles sur deux jambes de force, la panne et le chevronnage.
static func _auvent(o: Outils, t: Transform3D, p: Vector3, l: float, s: Dictionary) -> void:
	var couv: Array = s.couv
	var tf := t * Transform3D(Basis(), p)
	var avance := 1.0
	var pente := 0.5
	var bb := Basis(Vector3.RIGHT, pente)
	var c := Vector3(0, -sin(pente) * avance * 0.5, cos(pente) * avance * 0.5)
	o.boite(tf * Transform3D(bb, c + bb * Vector3(0, 0.05, 0)), Vector3(l, 0.08, avance + 0.1), couv[0])
	o.boite(tf * Transform3D(bb, c - bb * Vector3(0, 0.02, 0)), Vector3(l, 0.06, avance), BOIS.lightened(0.1))
	for k in 4:
		var f := (k + 0.5) / 4.0
		o.boite(tf * Transform3D(bb, bb * Vector3(0, 0.1, (f) * avance)), Vector3(l + 0.02, 0.04, 0.09), couv[1])
	var bas := Vector3(0, -sin(pente) * avance, cos(pente) * avance)
	o.boite(tf * Transform3D(Basis(), bas + Vector3(0, -0.1, -0.05)), Vector3(l + 0.1, 0.14, 0.12), BOIS)
	for cote in [-1.0, 1.0]:
		var a := Vector3(cote * (l * 0.5 - 0.15), -1.0, 0.02)
		var b := Vector3(cote * (l * 0.5 - 0.15), bas.y - 0.12, bas.z - 0.1)
		o.branche(tf * a, tf * b, 0.05, 0.05, BOIS, 4)
		o.branche(tf * Vector3(cote * (l * 0.5 - 0.15), -0.05, 0.02), tf * b, 0.05, 0.05, BOIS, 4)
	s.trous.append(Rect2(p.x - l * 0.5 - 0.1, p.y - 1.1, l + 0.2, 1.3))


## Le balcon de bois de l'étage : le plancher sur ses consoles, la balustrade de planches découpées, les fleurs.
static func _balcon_bois(o: Outils, t: Transform3D, p: Vector3, l: float, s: Dictionary) -> void:
	var tf := t * Transform3D(Basis(), p)
	var bois := BOIS.lightened(0.05)
	var prof := 0.85
	o.boite(tf * Transform3D(Basis(), Vector3(0, -0.06, prof * 0.5)), Vector3(l, 0.12, prof), bois)
	for k in 3:
		var x := -l * 0.5 + 0.2 + k * (l - 0.4) * 0.5
		o.boite(tf * Transform3D(Basis(), Vector3(x, -0.16, prof * 0.5)), Vector3(0.12, 0.12, prof), bois.darkened(0.15))
		o.branche(tf * Vector3(x, -0.85, 0.02), tf * Vector3(x, -0.18, prof * 0.8), 0.05, 0.05, bois.darkened(0.15), 4)
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0.92, prof - 0.04)), Vector3(l, 0.08, 0.1), bois)
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0.1, prof - 0.04)), Vector3(l, 0.06, 0.08), bois)
	var nb := int(l / 0.15)
	for i in nb + 1:
		o.boite(tf * Transform3D(Basis(), Vector3(-l * 0.5 + i * l / nb, 0.5, prof - 0.04)), Vector3(0.07, 0.8, 0.025), bois.lightened(0.05))
	for cote in [-1.0, 1.0]:
		o.boite(tf * Transform3D(Basis(), Vector3(cote * (l * 0.5 - 0.03), 0.92, prof * 0.5)), Vector3(0.08, 0.08, prof), bois)
		for i in 5:
			o.boite(tf * Transform3D(Basis(), Vector3(cote * (l * 0.5 - 0.03), 0.5, 0.1 + i * (prof - 0.15) / 4.0)), Vector3(0.025, 0.8, 0.07), bois.lightened(0.05))
	if s.fleurs:
		for i in int(l / 0.6):
			if o.rng.randf() < 0.7:
				var q := Vector3(-l * 0.5 + 0.3 + i * 0.6, 1.02, prof - 0.04)
				o.boule(tf * q, Vector3(0.24, 0.15, 0.15), VERT, 0.25, Outils.FEUILLE, 0.06, 0.2)
				o.boule(tf * (q + Vector3(0, 0.08, 0.06)), Vector3(0.15, 0.09, 0.1), s.fleur.lightened(o.rng.randf_range(-0.1, 0.1)), 0.3, Outils.FEUILLE, 0.08, 0.2)
				o.boule(tf * (q + Vector3(0.08, -0.35, 0.05)), Vector3(0.1, 0.3, 0.08), VERT.darkened(0.08), 0.3, Outils.FEUILLE, 0.05, 0.3)
	s.trous.append(Rect2(p.x - l * 0.5, p.y - 1.0, l, 2.0))


## Le store de la boutique : une toile à bandes en avancée, son lambrequin festonné.
static func _store(o: Outils, t: Transform3D, p: Vector3, l: float, s: Dictionary) -> void:
	var tf := t * Transform3D(Basis(), p)
	var toile: Array = (s.toile as Array).map(func(h): return Color(str(h)))
	var bandes := int(l / 0.45)
	var lt := l / bandes
	var avance := 1.3
	var pente := 0.4
	for i in bandes:
		var c: Color = toile[i % 2]
		var x := -l * 0.5 + (i + 0.5) * lt
		var bout := Vector3(x, -sin(pente) * avance, 0.12 + cos(pente) * avance)
		o.boite(tf * Transform3D(Basis(Vector3.RIGHT, pente), Vector3(x, -sin(pente) * avance * 0.5, 0.12 + cos(pente) * avance * 0.5)), Vector3(lt, 0.04, avance), c)
		o.profil(tf * Transform3D(Basis(), bout), Outils.arc(Vector2(0, 0), lt * 0.5, PI, TAU, 6), -0.01, 0.01, c)
		o.boite(tf * Transform3D(Basis(), bout + Vector3(0, -0.05, 0)), Vector3(lt, 0.12, 0.02), c)
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0.0, 0.1)), Vector3(l + 0.1, 0.1, 0.16), FER)
	for cote in [-1.0, 1.0]:
		o.branche(tf * Vector3(cote * l * 0.5, -0.6, 0.02), tf * Vector3(cote * l * 0.5, -sin(pente) * avance, 0.1 + cos(pente) * avance), 0.02, 0.02, FER, 4)


## L'enseigne de fer forgé en potence : la console à volute et le panneau peint qui pend, de champ.
static func _potence(o: Outils, t: Transform3D, p: Vector3, s: Dictionary) -> void:
	var tf := t * Transform3D(Basis(), p)
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0, 0.45)), Vector3(0.04, 0.04, 0.9), FER)
	o.branche(tf * Vector3(0, -0.4, 0.02), tf * Vector3(0, 0, 0.6), 0.015, 0.015, FER, 4)
	o.anneau(tf * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, -0.12, 0.3)), 0.1, 0.13, 0.03, 10, FER)
	o.boite(tf * Transform3D(Basis(), Vector3(0, -0.42, 0.55)), Vector3(0.04, 0.5, 0.6), s.bois)
	o.boite(tf * Transform3D(Basis(), Vector3(0, -0.42, 0.55)), Vector3(0.05, 0.36, 0.46), Color("e0b040"))
	for k in 2:
		o.boite(tf * Transform3D(Basis(), Vector3(0, -0.12, 0.33 + k * 0.44)), Vector3(0.012, 0.12, 0.012), FER)
	s.trous.append(Rect2(p.x - 0.3, p.y - 0.8, 0.6, 1.0))


## La lanterne murale : la console de fer, la cage à quatre vitres qui luit.
static func _lanterne(o: Outils, t: Transform3D, p: Vector3) -> void:
	var tf := t * Transform3D(Basis(), p)
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0, 0.03)), Vector3(0.14, 0.24, 0.06), FER)
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0.08, 0.2)), Vector3(0.03, 0.03, 0.34), FER)
	o.boite(tf * Transform3D(Basis(), Vector3(0, -0.12, 0.34)), Vector3(0.18, 0.26, 0.18), Color("ffd98a"), Outils.LUEUR)
	o.cylindre(tf * Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, 0.01, 0.34)), 0.16, 0.02, 0.14, 4, FER)
	o.boite(tf * Transform3D(Basis(), Vector3(0, -0.27, 0.34)), Vector3(0.2, 0.04, 0.2), FER)


## L'oculus : une baie ronde dans son anneau de pierre de taille.
static func _oculus(o: Outils, t: Transform3D, p: Vector3, rayon: float, s: Dictionary) -> void:
	var rond := Outils.arc(Vector2.ZERO, rayon, 0.0, TAU, 16)
	rond.remove_at(rond.size() - 1)
	var tf := t * Transform3D(Basis(), p)
	o.profil(tf, rond, -0.02, 0.02, VERRE)
	_cadre(o, tf, rond, 0.16, 0.0, 0.14, TAILLE, TAILLE_SOMBRE)
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0, 0.04)), Vector3(rayon * 2.0, 0.04, 0.03), Color("efe9dc"))
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0, 0.04)), Vector3(0.04, rayon * 2.0, 0.03), Color("efe9dc"))
	s.trous.append(Rect2(p.x - rayon - 0.25, p.y - rayon - 0.25, rayon * 2.0 + 0.5, rayon * 2.0 + 0.5))


## Un mur de moellons calcaires dans le repère t (x en travers, y vers le haut, z hors du mur) : des assises
## irrégulières de pierres de longueur et de teinte variées, en léger relief sur le joint clair ; jusqu'au pignon
## triangulaire de hauteur hp s'il y en a un. Les trous (Rect2) gardent les baies libres. Un mur enduit garde
## quelques pierres seulement, là où l'enduit est tombé.
static func _mur(o: Outils, t: Transform3D, w: float, y0: float, y1: float, hp: float, trous: Array, s: Dictionary, bornes := Callable()) -> void:
	var r := o.rng
	var base: Color = s.pierre
	var enduit: bool = s.mur == "enduit"
	var plaques := []
	if enduit:
		for k in 2 + r.randi() % 2:
			var cx := r.randf_range(-w * 0.4, w * 0.4)
			var cy := r.randf_range(y0 + 0.3, y1 - 0.5)
			plaques.append(Rect2(cx - r.randf_range(0.5, 0.9), cy - r.randf_range(0.3, 0.6), r.randf_range(1.0, 1.8), r.randf_range(0.6, 1.1)))
	var y := y0 + 0.03
	var haut := y1 + hp
	while y < haut - 0.15:
		var h := r.randf_range(0.2, 0.32)
		var lim := w * 0.5 - 0.02
		if hp > 0.0 and y + h > y1:
			lim = w * 0.5 * (1.0 - (y + h - y1) / hp) - 0.05
		if lim < 0.15:
			break
		var x := -lim
		var xmax := lim
		if bornes.is_valid():
			var b: Vector2 = bornes.call(y, y + h)
			x = b.x
			xmax = b.y
		while x < xmax - 0.08:
			var l := minf(r.randf_range(0.32, 0.85), xmax - x)
			var hh := h * r.randf_range(0.78, 1.0)
			var rc := Rect2(x, y, l, hh)
			var libre := r.randf() < 0.9
			if libre:
				for tr in trous:
					if (tr as Rect2).intersects(rc):
						libre = false
						break
			if libre and enduit:
				libre = false
				for pl in plaques:
					if (pl as Rect2).encloses(rc):
						libre = true
			if libre and l > 0.14:
				var c := base.lightened(r.randf_range(-0.1, 0.1))
				var tir := r.randf()
				if tir < 0.18:
					c = c.lerp(Color("b49d78"), 0.45)
				elif tir < 0.3:
					c = c.lerp(Color("eadfc8"), 0.4)
				var relief := r.randf_range(0.03, 0.06)
				o.boite(t * Transform3D(Basis(), Vector3(x + l * 0.5, y + hh * 0.5, relief * 0.5)), Vector3(l - 0.05, hh - 0.05, relief), c)
			x += l
		y += h


## Les chaînes d'angle : de grosses pierres de taille harpées aux quatre coins, qui prennent sur deux faces.
static func _chaines(o: Outils, w: float, d: float, H: float, s: Dictionary) -> void:
	var r := o.rng
	for coin in [Vector2(-1, 0), Vector2(1, 0), Vector2(-1, -1), Vector2(1, -1)]:
		var y := 0.0
		var k := 0
		var cx: float = coin.x * w * 0.5
		var cz: float = coin.y * d
		var sz: float = 1.0 if coin.y == 0 else -1.0
		while y < H - 0.2:
			var hb := 0.34
			var a := 0.62 if k % 2 == 0 else 0.36
			var b := 0.36 if k % 2 == 0 else 0.62
			var col := TAILLE.darkened(r.randf_range(0.0, 0.08))
			o.boite(Transform3D(Basis(), Vector3(cx - coin.x * (a * 0.5 - 0.06), y + hb * 0.5, cz - sz * (b * 0.5 - 0.06))), Vector3(a, hb - 0.03, b), col)
			y += hb
			k += 1
	s.trous.append(Rect2(-w * 0.5, 0, 0.7, H))
	s.trous.append(Rect2(w * 0.5 - 0.7, 0, 0.7, H))


## La vigne qui grimpe d'un pied de façade et file sous l'égout ou sous les fenêtres de l'étage.
static func _vigne(o: Outils, w: float, H: float, r: RandomNumberGenerator, s: Dictionary) -> void:
	var cote := -1.0 if r.randf() < 0.5 else 1.0
	var x0 := cote * (w * 0.5 - 0.35)
	var haut := minf(H - 0.5, RDC + ETAGE * r.randf_range(0.5, 1.3))
	var y := 0.3
	o.branche(Vector3(x0, 0, 0.2), Vector3(x0, haut, 0.2), 0.05, 0.03, Color("6b4a32"), 5)
	while y < haut:
		var t := r.randf_range(0.16, 0.3)
		var ec := 0.15 + 0.35 * y / haut
		o.boule(Vector3(x0 + r.randf_range(-ec, ec), y, 0.26), Vector3(t, t * 0.8, 0.16), VERT.lightened(r.randf_range(-0.08, 0.15)), 0.3, Outils.FEUILLE, 0.1, 0.2)
		y += r.randf_range(0.14, 0.26)
	var x := x0
	for i in int(w * 0.45):
		x -= cote * r.randf_range(0.35, 0.55)
		if absf(x) > w * 0.5 - 0.3:
			break
		for k in 2:
			o.boule(Vector3(x + r.randf_range(-0.15, 0.15), haut - r.randf_range(0.0, 0.5), 0.26), Vector3(0.26, 0.2, 0.15), VERT.lightened(r.randf_range(-0.05, 0.12)), 0.3, Outils.FEUILLE, 0.1, 0.2)
		if r.randf() < 0.25:
			o.boule(Vector3(x, haut - 0.3, 0.45), Vector3(0.08, 0.12, 0.08), Color("4a3a6a"), 0.2, Outils.FEUILLE, 0.05, 0.2)


## Les rangs de couverture sur un pan (bas : le milieu de l'égout ; monte : vers le faîtage ; long : la longueur de
## l'égout, long2 celle du haut ; dir : le long de l'égout ; nrm : la normale du pan), selon la couverture.
static func _rangs(o: Outils, bas: Vector3, monte: Vector3, long: float, long2: float, dir: Vector3, nrm: Vector3, s: Dictionary) -> void:
	var r := o.rng
	var couv: Array = s.couv
	var nom: String = s.couv_nom
	var sp: float = {"tuile_rouge": 0.26, "tuile_vieillie": 0.26, "lauze": 0.36, "mecanique": 0.38, "ardoise": 0.2}.get(nom, 0.26)
	var ep: float = {"lauze": 0.07, "ardoise": 0.025, "mecanique": 0.05}.get(nom, 0.04)
	var nn := nrm.normalized()
	var bb := Basis(dir, nn, dir.cross(nn)).orthonormalized()
	var rangs := int(monte.length() / sp)
	for k in rangs:
		var f := (k + 0.5) / rangs
		var lk := lerpf(long, long2, f)
		var centre: Vector3 = bas + monte * f + nn * (ep * 0.5 + 0.01)
		if nom == "lauze":
			# des dalles de calcaire de longueurs et de teintes inégales
			var x := -lk * 0.5
			while x < lk * 0.5 - 0.1:
				var l := minf(r.randf_range(0.35, 0.8), lk * 0.5 - x)
				var c: Color = couv[0].lightened(r.randf_range(-0.1, 0.1))
				o.boite(Transform3D(bb, centre + dir * (x + l * 0.5)), Vector3(l - 0.04, ep, sp * 0.9), c)
				x += l
			continue
		o.boite(Transform3D(bb, centre), Vector3(lk, ep, 0.1), couv[1])
		if nom == "tuile_vieillie" or nom == "tuile_rouge":
			# des tuiles plus claires ou plus sombres, la mousse, par endroits
			for j in 2 + r.randi() % 3:
				var l := r.randf_range(0.4, 1.2)
				var x := r.randf_range(-lk * 0.5 + l * 0.5, lk * 0.5 - l * 0.5)
				var c: Color = couv[0].lightened(r.randf_range(-0.12, 0.1))
				if nom == "tuile_vieillie" and r.randf() < 0.3:
					c = c.lerp(Color("8a8a5a"), 0.4)
				o.boite(Transform3D(bb, bas + monte * (f - 0.5 / rangs) + nn * 0.012 + dir * x), Vector3(l, 0.02, sp * 0.8), c)
	if nom == "mecanique":
		var nr := int(long / 0.24)
		for i in nr:
			var x := -long * 0.5 + (i + 0.5) * long / nr
			if absf(x) > long2 * 0.5 + monte.length() * 0.0 and long2 < long:
				continue
			o.boite(Transform3D(bb, bas + monte * 0.5 + nn * 0.04 + dir * x), Vector3(0.05, 0.04, monte.length()), couv[1])


## Le toit à deux pans, le faîtage parallèle à la façade : le comble qui ferme les pignons, les pans couverts, les
## rives de bois, les chevrons apparents sous l'égout, la faîtière. Rend le faîte.
static func _deux_pans(o: Outils, w: float, d: float, H: float, pente: float, s: Dictionary) -> float:
	var couv: Array = s.couv
	var e := 0.6
	var rv := 0.35
	var tp := tan(pente)
	var y_mur := H + 0.15
	var y_e := y_mur - e * tp
	var zr := -d * 0.5
	var y_r := y_mur + d * 0.5 * tp
	var x0 := -w * 0.5 - rv
	var x1 := w * 0.5 + rv
	o.profil(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), PackedVector2Array([Vector2(0, H), Vector2(d, H), Vector2(d * 0.5, y_r - 0.16)]), -w * 0.5, w * 0.5, s.fond)
	var dessous := Color("6e5038")
	for sens in [1.0, -1.0]:
		var ze: float = e if sens > 0.0 else -d - e
		var a := Vector3(x0, y_e, ze)
		var b := Vector3(x1, y_e, ze)
		var c := Vector3(x1, y_r, zr)
		var dd := Vector3(x0, y_r, zr)
		var nrm := Vector3(0, 1, tp * sens).normalized()
		o.quad(a, b, c, dd, nrm, couv[0])
		var bas := Vector3(0, 0.12, 0)
		o.quad(a - bas, b - bas, c - bas, dd - bas, -nrm, dessous)
		_rangs(o, Vector3(0, y_e, ze), Vector3(0, y_r - y_e, zr - ze), x1 - x0, x1 - x0, Vector3.RIGHT, nrm, s)
		# la planche d'égout et les chevrons apparents
		o.boite(Transform3D(Basis(), Vector3(0, y_e - 0.12, ze)), Vector3(x1 - x0, 0.16, 0.05), dessous.darkened(0.1))
		var nch := int(w / 0.6)
		for i in nch + 1:
			var x := -w * 0.5 + i * w / nch
			var zc: float = (e * 0.5) * sens + (0.0 if sens > 0.0 else -d)
			o.boite(Transform3D(Basis(Vector3.RIGHT, pente * sens), Vector3(x, y_mur - 0.2 - e * 0.5 * tp, zc)), Vector3(0.09, 0.12, e / cos(pente)), dessous)
		# les rives
		var lr := Vector2(e + d * 0.5, y_r - y_e).length()
		for x in [x0, x1]:
			o.boite(Transform3D(Basis(Vector3.RIGHT, pente * sens), Vector3(x, (y_e + y_r) * 0.5 - 0.02, (ze + zr) * 0.5)), Vector3(0.06, 0.24, lr), dessous.darkened(0.1))
	var fait: Color = couv[1].darkened(0.08)
	o.branche(Vector3(x0 - 0.05, y_r + 0.02, zr), Vector3(x1 + 0.05, y_r + 0.02, zr), 0.13, 0.13, fait, 6)
	return y_r + 0.15


## Le toit à croupes de la maison bourgeoise : quatre pans sur des chevrons apparents. Rend le faîte.
static func _croupes(o: Outils, w: float, d: float, H: float, pente: float, s: Dictionary) -> float:
	var couv: Array = s.couv
	var e := 0.6
	var tp := tan(pente)
	var y0 := H + 0.15 - e * tp
	var x0 := -w * 0.5 - e
	var x1 := w * 0.5 + e
	var z0 := e
	var z1 := -d - e
	var demi := minf(x1 - x0, z0 - z1) * 0.5
	var sommet := y0 + demi * tp
	var cz := (z0 + z1) * 0.5
	var a := Vector3(x0 + demi, sommet, cz)
	var b := Vector3(x1 - demi, sommet, cz)
	var c00 := Vector3(x0, y0, z0)
	var c10 := Vector3(x1, y0, z0)
	var c11 := Vector3(x1, y0, z1)
	var c01 := Vector3(x0, y0, z1)
	var pans := [[c00, c10, b, a], [c11, c01, a, b], [c10, c11, b], [c01, c00, a]]
	var dessous := Color("6e5038")
	for pan in pans:
		var nrm: Vector3 = (pan[1] - pan[0]).cross(pan[2] - pan[0])
		if nrm.y < 0.0:
			nrm = -nrm
		var bas := Vector3(0, 0.12, 0)
		if pan.size() == 4:
			o.quad(pan[0], pan[1], pan[2], pan[3], nrm, couv[0])
			o.quad(pan[0] - bas, pan[1] - bas, pan[2] - bas, pan[3] - bas, -nrm, dessous)
		else:
			o.tri(pan[0], pan[1], pan[2], nrm, couv[0])
			o.tri(pan[0] - bas, pan[1] - bas, pan[2] - bas, -nrm, dessous)
		var m0: Vector3 = (pan[0] + pan[1]) * 0.5
		var haut: Vector3 = pan[2] if pan.size() == 3 else (pan[2] + pan[3]) * 0.5
		var long: float = (pan[1] - pan[0]).length()
		var long2: float = 0.0 if pan.size() == 3 else (pan[2] - pan[3]).length()
		_rangs(o, m0, haut - m0, long, long2, (pan[1] - pan[0]).normalized(), nrm, s)
		o.boite(Transform3D(Basis((pan[1] - pan[0]).normalized(), Vector3.UP, (pan[1] - pan[0]).normalized().cross(Vector3.UP)).orthonormalized(), m0 - Vector3(0, 0.12, 0)), Vector3(long, 0.16, 0.05), dessous.darkened(0.1))
	var fait: Color = couv[1].darkened(0.08)
	o.branche(a, b, 0.12, 0.12, fait, 6)
	for cc in [c00, c10, c11, c01]:
		var k: Vector3 = cc
		o.branche(k, a if k.distance_to(a) < k.distance_to(b) else b, 0.09, 0.09, fait, 5)
	for sens in [1.0, -1.0]:
		var nch := int(w / 0.6)
		for i in nch + 1:
			var x := -w * 0.5 + i * w / nch
			var zc: float = (e * 0.5) * sens + (0.0 if sens > 0.0 else -d)
			o.boite(Transform3D(Basis(Vector3.RIGHT, pente * sens), Vector3(x, H - 0.05 - e * 0.5 * tp, zc)), Vector3(0.09, 0.12, e / cos(pente)), dessous)
	return sommet


## Le toit en pavillon de la tour : quatre pans raides en pointe, les rangs, l'épi de faîtage. Rend le faîte.
static func _pyramide(o: Outils, w: float, d: float, H: float, pente: float, s: Dictionary) -> float:
	var couv: Array = s.couv
	var e := 0.45
	var demi := w * 0.5 + e
	var R := demi * sqrt(2.0)
	var h := demi * tan(pente)
	var y0 := H + 0.15 - e * tan(pente) * 0.4
	var base := Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, y0, -d * 0.5))
	o.cylindre(base, R, 0.0, h, 4, couv[0])
	var rangs := int(h / 0.3)
	for k in rangs:
		var f := float(k) / rangs
		o.cylindre(base * Transform3D(Basis(), Vector3(0, f * h, 0)), R * (1.0 - f) + 0.025, R * (1.0 - f - 0.04 / h) + 0.02, 0.05, 4, couv[1], Outils.DUR, false)
	o.cylindre(base * Transform3D(Basis(), Vector3(0, h - 0.1, 0)), 0.08, 0.05, 0.6, 6, couv[1])
	o.boule(base * Vector3(0, h + 0.6, 0), Vector3(0.12, 0.12, 0.12), couv[1], 0.0, Outils.DUR, 0.0, 0.0)
	# la planche d'égout sous les quatre pans
	for i in 4:
		var bb := Basis(Vector3.UP, PI * 0.5 * i)
		o.boite(Transform3D(bb, Vector3(0, y0 - 0.1, -d * 0.5) + bb * Vector3(0, 0, demi)), Vector3(demi * 2.0, 0.16, 0.05), Color("5e4430"))
	return y0 + h + 0.7


## Le pignon à redents sur la rue : le mur monte en gradins au-dessus du toit, chaque gradin sous sa dalle de
## couronnement, et une souche au sommet.
static func _redents(o: Outils, w: float, H: float, pente: float, s: Dictionary) -> void:
	var hp := w * 0.5 * tan(pente) + 0.15
	var n := 4
	var sw := w * 0.5 / (n + 0.5)
	var pts := PackedVector2Array([Vector2(-w * 0.5, H)])
	for i in n:
		var y := H + (i + 1) * hp / (n + 0.5) + 0.35
		pts.append(Vector2(-w * 0.5 + i * sw, y))
		pts.append(Vector2(-w * 0.5 + (i + 1) * sw, y))
	var ys := H + hp + 0.5
	pts.append(Vector2(-sw * 0.5, ys))
	pts.append(Vector2(sw * 0.5, ys))
	for i in range(n - 1, -1, -1):
		var y := H + (i + 1) * hp / (n + 0.5) + 0.35
		pts.append(Vector2(w * 0.5 - (i + 1) * sw, y))
		pts.append(Vector2(w * 0.5 - i * sw, y))
	pts.append(Vector2(w * 0.5, H))
	o.profil(Transform3D(), _sans_doublons(pts), -0.7, 0.0, s.fond)
	# les dalles de couronnement des gradins
	for i in n:
		var y := H + (i + 1) * hp / (n + 0.5) + 0.35
		for cote in [-1.0, 1.0]:
			o.boite(Transform3D(Basis(), Vector3(cote * (w * 0.5 - (i + 0.5) * sw), y + 0.06, -0.35)), Vector3(sw + 0.12, 0.12, 0.86), TAILLE)
	o.boite(Transform3D(Basis(), Vector3(0, ys + 0.06, -0.35)), Vector3(sw + 0.14, 0.12, 0.86), TAILLE)
	o.boite(Transform3D(Basis(), Vector3(0, ys + 0.4, -0.35)), Vector3(0.5, 0.7, 0.5), TAILLE_SOMBRE)


## Le toit du pignon sur rue : deux pans, le faîtage perpendiculaire à la façade, derrière le pignon à redents ; le
## pignon arrière triangulaire. Rend le faîte.
static func _toit_pignon(o: Outils, w: float, d: float, H: float, pente: float, s: Dictionary) -> float:
	var couv: Array = s.couv
	var e := 0.55
	var tp := tan(pente)
	var y_mur := H + 0.15
	var y_e := y_mur - e * tp
	var y_r := y_mur + w * 0.5 * tp
	var z0 := -0.7
	var z1 := -d - 0.45
	o.profil(Transform3D(), PackedVector2Array([Vector2(-w * 0.5, H), Vector2(w * 0.5, H), Vector2(0, y_r - 0.16)]), -d, z0, s.fond)
	var dessous := Color("6e5038")
	for sens in [1.0, -1.0]:
		var xe: float = sens * (w * 0.5 + e)
		var a := Vector3(xe, y_e, z0)
		var b := Vector3(xe, y_e, z1)
		var c := Vector3(0, y_r, z1)
		var dd := Vector3(0, y_r, z0)
		var nrm := Vector3(tp * sens, 1, 0).normalized()
		o.quad(a, b, c, dd, nrm, couv[0])
		o.quad(a - Vector3(0, 0.12, 0), b - Vector3(0, 0.12, 0), c - Vector3(0, 0.12, 0), dd - Vector3(0, 0.12, 0), -nrm, dessous)
		_rangs(o, Vector3(xe, y_e, (z0 + z1) * 0.5), Vector3(-xe, y_r - y_e, 0), z0 - z1, z0 - z1, Vector3.FORWARD, nrm, s)
		o.boite(Transform3D(Basis(), Vector3(xe, y_e - 0.12, (z0 + z1) * 0.5)), Vector3(0.05, 0.16, z0 - z1), dessous.darkened(0.1))
	o.branche(Vector3(0, y_r + 0.02, z0), Vector3(0, y_r + 0.02, z1 - 0.05), 0.13, 0.13, couv[1].darkened(0.08), 6)
	return y_r + 0.6


## Une lucarne à fronton sur le pan avant : ses jouées, la fenêtre à petits bois, le petit toit à deux pans.
static func _lucarne(o: Outils, x: float, H: float, pente: float, s: Dictionary) -> void:
	var couv: Array = s.couv
	var tp := tan(pente)
	var y_mur := H + 0.15
	var zf := -0.45
	var yb := y_mur - zf * tp
	var yt := yb + 1.35
	var zb := -(yt - y_mur) / tp
	var lw := 1.3
	o.boite(Transform3D(Basis(), Vector3(x, (yb - 0.4 + yt) * 0.5, (zf + zb) * 0.5)), Vector3(lw, yt - yb + 0.4, zf - zb), s.fond)
	var tf := Transform3D(Basis(), Vector3(x, yb + 0.15, zf))
	var pts := _baie(0.72, 0.95, "droite")
	o.profil(tf, pts, -0.02, 0.02, VERRE)
	_cadre(o, tf, pts, 0.12, 0.0, 0.1, TAILLE, TAILLE_SOMBRE)
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0.475, 0.04)), Vector3(0.04, 0.95, 0.03), Color("efe9dc"))
	o.boite(tf * Transform3D(Basis(), Vector3(0, 0.5, 0.04)), Vector3(0.72, 0.04, 0.03), Color("efe9dc"))
	var tri := PackedVector2Array([Vector2(-lw * 0.5 - 0.22, 0), Vector2(lw * 0.5 + 0.22, 0), Vector2(0, 0.75)])
	o.profil(Transform3D(Basis(), Vector3(x, yt - 0.02, 0)), tri, zb - 0.3, zf + 0.2, [Color("8a6444"), couv[0]])
	o.branche(Vector3(x, yt + 0.75, zf + 0.2), Vector3(x, yt + 0.75, zb - 0.3), 0.07, 0.07, couv[1], 5)


## Une cheminée de pierre sur le toit, au point p (le pied sur le toit) ; couronnée de brique, ou d'une dalle.
static func _cheminee(o: Outils, p: Vector3, brique: bool, s: Dictionary) -> void:
	var h := 1.5
	var pierre: Color = s.pierre
	o.boite(Transform3D(Basis(), p + Vector3(0, h * 0.5 - 0.4, 0)), Vector3(0.75, h + 0.8, 0.6), pierre.darkened(0.05))
	if brique:
		o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.2, 0)), Vector3(0.78, 0.45, 0.63), Color("a8502e"))
		for k in 2:
			o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.05 + k * 0.2, 0)), Vector3(0.8, 0.03, 0.65), Color("8a3f25"))
	else:
		o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.05, 0)), Vector3(0.9, 0.1, 0.75), TAILLE)
		o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.25, 0)), Vector3(0.6, 0.3, 0.45), pierre.darkened(0.1))
		o.boite(Transform3D(Basis(), p + Vector3(0, h + 0.45, 0)), Vector3(0.95, 0.08, 0.8), TAILLE_SOMBRE)


## La chapelle : une nef de moellons sous un toit de tuile, la façade à pignon, le portail en plein cintre à claveaux
## et l'oculus ; le clocher carré à baies géminées sous sa flèche d'ardoise et sa croix, ou le clocher-mur et sa
## cloche sur le pignon.
static func _chapelle(o: Outils, n: Node3D, graine: int, opt: Dictionary) -> Node3D:
	var r := o.rng
	var pierre := _teinte(opt.get("pierre", "calcaire"), PIERRES)
	var w := float(opt.get("w", 7.0))
	var d := float(opt.get("d", 11.0))
	var H := 5.6
	var pente := deg_to_rad(42.0)
	var couv_nom := str(opt.get("couverture", "tuile_vieillie"))
	var s := {"mur": "moellons", "pierre": pierre, "fond": pierre.darkened(0.16).lerp(Color("b8ab94"), 0.25), "volets": "aucun",
		"volet": Color.WHITE, "bois": Color("5a3a28"), "fleurs": true, "fleur": Color(FLEURS[0]), "couv": (COUVERTURES[couv_nom] as Array).map(func(h): return Color(str(h))),
		"couv_nom": couv_nom, "trous": [], "saute": []}
	var fond: Color = s.fond
	o.boite(Transform3D(Basis(), Vector3(0, H * 0.5, -d * 0.5)), Vector3(w, H, d), [fond.darkened(0.05), fond.darkened(0.05), fond, fond, fond, fond.darkened(0.08)], Outils.DUR, true)
	o.boite(Transform3D(Basis(), Vector3(0, -0.15, -d * 0.5)), Vector3(w + 0.1, 0.32, d + 0.1), pierre.darkened(0.2))
	var hp := w * 0.5 * tan(pente) + 0.15
	# le pignon de façade, dressé au-dessus du toit, et son chaperon
	var pignon := PackedVector2Array([Vector2(-w * 0.5, H), Vector2(w * 0.5, H), Vector2(0, H + hp + 0.25)])
	o.profil(Transform3D(), pignon, -0.7, 0.0, fond)
	var ang := atan2(hp + 0.25, w * 0.5)
	var lc := Vector2(w * 0.5, hp + 0.25).length()
	for cote in [-1.0, 1.0]:
		o.boite(Transform3D(Basis(Vector3.BACK, -cote * ang), Vector3(cote * w * 0.25, H + (hp + 0.25) * 0.5 + 0.08, -0.33)), Vector3(lc + 0.1, 0.16, 0.8), TAILLE)
	_toit_pignon(o, w, d, H, pente, s)
	# le portail, l'emmarchement, l'oculus
	var l := 1.8
	var hpo := 3.2
	var tf := Transform3D()
	var pts := _baie(l, hpo, "plein_cintre")
	o.profil(tf, pts, -0.02, 0.02, Color("5a3a28"))
	for k in 8:
		o.boite(tf * Transform3D(Basis(), Vector3(-l * 0.5 + (k + 0.5) * l / 8.0, (hpo - l * 0.5) * 0.5, 0.03)), Vector3(0.02, hpo - l * 0.5, 0.02), Color("3e281c"))
	_claveaux(o, tf, l, hpo, "plein_cintre", 0.0, 0.42, 0.26)
	_cadre(o, tf, pts, 0.03, 0.0, 0.26, TAILLE, TAILLE_SOMBRE)
	s.trous.append(Rect2(-l * 0.5 - 0.6, -0.2, l + 1.2, hpo + 0.8))
	for k in 3:
		o.boite(Transform3D(Basis(), Vector3(0, 0.08 + k * 0.16, 1.0 - k * 0.28)), Vector3(3.4 - k * 0.5, 0.16, 0.56), TAILLE_SOMBRE)
	_oculus(o, tf, Vector3(0, H + 0.9, 0), 0.55, s)
	_mur(o, Transform3D(), w, 0.0, H, hp, s.trous, s)
	for tc in [Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w * 0.5, 0, -d * 0.5)), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-w * 0.5, 0, -d * 0.5))]:
		var trous := []
		for k in 3:
			var x := -d * 0.5 + 2.2 + k * 3.2
			var tb: Transform3D = tc * Transform3D(Basis(), Vector3(x, 2.0, 0))
			var pf := _baie(0.7, 2.0, "plein_cintre")
			o.profil(tb, pf, -0.02, 0.02, VERRE)
			_cadre(o, tb, pf, 0.15, 0.0, 0.14, TAILLE, TAILLE_SOMBRE)
			trous.append(Rect2(x - 0.6, 1.8, 1.2, 2.5))
		_mur(o, tc, d, 0.0, H, 0.0, trous, s)
	_mur(o, Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -d)), w, 0.0, H, hp, [], s)
	_chaines(o, w, d, H, s)
	var haut := H + hp + 0.5
	if str(opt.get("clocher", "tour" if r.randf() < 0.6 else "mur")) == "mur":
		# le clocher-mur : le pignon prolongé, percé d'une arcade, la cloche
		var cm := PackedVector2Array([Vector2(-0.9, 0), Vector2(0.9, 0), Vector2(0.9, 1.9), Vector2(0, 2.6), Vector2(-0.9, 1.9)])
		var tc := Transform3D(Basis(), Vector3(0, H + hp + 0.1, 0))
		o.profil(tc, cm, -0.6, 0.0, fond)
		var arche := _baie(0.8, 1.5, "plein_cintre")
		o.profil(tc * Transform3D(Basis(), Vector3(0, 0.3, 0)), arche, 0.0, 0.02, SOMBRE)
		_cadre(o, tc * Transform3D(Basis(), Vector3(0, 0.3, 0)), arche, 0.1, 0.0, 0.08, TAILLE, TAILLE_SOMBRE)
		o.cylindre(tc * Transform3D(Basis(), Vector3(0, 0.7, -0.15)), 0.3, 0.16, 0.5, 10, Color("8a6a2a"))
		o.boite(tc * Transform3D(Basis(), Vector3(0, 2.75, -0.3)), Vector3(0.05, 0.6, 0.05), FER)
		o.boite(tc * Transform3D(Basis(), Vector3(0, 2.85, -0.3)), Vector3(0.35, 0.05, 0.05), FER)
		haut = H + hp + 3.5
	else:
		# le clocher carré, à droite de la façade, et sa flèche d'ardoise
		var cx := w * 0.5 + 1.5
		var cz := -1.7
		var cw := 3.2
		var hc := 12.5
		o.boite(Transform3D(Basis(), Vector3(cx, hc * 0.5, cz)), Vector3(cw, hc, cw), fond, Outils.DUR, true)
		o.boite(Transform3D(Basis(), Vector3(cx, -0.15, cz)), Vector3(cw + 0.1, 0.32, cw + 0.1), pierre.darkened(0.2))
		var faces := [Transform3D(Basis(), Vector3(cx, 0, cz + cw * 0.5)), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cx + cw * 0.5, 0, cz)),
			Transform3D(Basis(Vector3.UP, PI), Vector3(cx, 0, cz - cw * 0.5)), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(cx - cw * 0.5, 0, cz))]
		for tfc in faces:
			var tc: Transform3D = tfc
			var trous := []
			for cote in [-1.0, 1.0]:
				var tb := tc * Transform3D(Basis(), Vector3(cote * 0.5, hc - 3.0, 0))
				var pf := _baie(0.6, 1.9, "plein_cintre")
				o.profil(tb, pf, -0.02, 0.02, SOMBRE)
				_cadre(o, tb, pf, 0.1, 0.0, 0.12, TAILLE, TAILLE_SOMBRE)
			trous.append(Rect2(-1.1, hc - 3.3, 2.2, 2.6))
			var tb2 := tc * Transform3D(Basis(), Vector3(0, hc * 0.45, 0))
			o.profil(tb2, _baie(0.25, 0.9, "droite"), -0.02, 0.02, SOMBRE)
			trous.append(Rect2(-0.4, hc * 0.45 - 0.2, 0.8, 1.3))
			o.boite(tc * Transform3D(Basis(), Vector3(0, hc - 3.25, 0.06)), Vector3(cw + 0.1, 0.14, 0.14), TAILLE)
			trous.append(Rect2(-cw * 0.5, hc - 3.4, cw, 0.3))
			trous.append(Rect2(-cw * 0.5, 0, 0.55, hc))
			trous.append(Rect2(cw * 0.5 - 0.55, 0, 0.55, hc))
			if tc.origin.z > cz + 0.1 or tc.origin.x > cx + 0.1:
				_mur(o, tc, cw, 0.0, hc, 0.0, trous, s)
		for k in 4:
			var bb := Basis(Vector3.UP, PI * 0.5 * k)
			var y := 0.0
			var j := 0
			while y < hc - 0.2:
				var a := 0.55 if j % 2 == 0 else 0.34
				o.boite(Transform3D(bb, Vector3(cx, y + 0.17, cz) + bb * Vector3(cw * 0.5 - a * 0.5 + 0.05, 0, cw * 0.5 - 0.17 + 0.05)), Vector3(a, 0.31, 0.34), TAILLE.darkened(0.04 * (j % 2)))
				y += 0.34
				j += 1
		var ard: Array = (COUVERTURES["ardoise"] as Array).map(func(h): return Color(str(h)))
		var Rf := (cw * 0.5 + 0.3) * sqrt(2.0)
		var hf := 5.5
		var bf := Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(cx, hc, cz))
		o.cylindre(bf, Rf, 0.0, hf, 4, ard[0])
		for k in int(hf / 0.3):
			var f := float(k) / int(hf / 0.3)
			o.cylindre(bf * Transform3D(Basis(), Vector3(0, f * hf, 0)), Rf * (1.0 - f) + 0.02, Rf * (1.0 - f - 0.01) + 0.015, 0.04, 4, ard[1], Outils.DUR, false)
		o.boite(Transform3D(Basis(), Vector3(cx, hc + hf + 0.4, cz)), Vector3(0.06, 1.0, 0.06), FER)
		o.boite(Transform3D(Basis(), Vector3(cx, hc + hf + 0.6, cz)), Vector3(0.5, 0.06, 0.06), FER)
		haut = hc + hf + 1.0
		w += 3.2
	o.construire(n, "Corps")
	n.set_meta("type", "chapelle")
	n.set_meta("graine", graine)
	n.set_meta("w", w)
	n.set_meta("d", d)
	n.set_meta("hauteur", haut)
	n.set_meta("porte", Vector3(0, 0, 1.3))
	return n


## Le contour d'une baie de largeur l et de hauteur h (au sommet) : droite, en plein cintre, ou surbaissée de
## flèche f.
static func _baie(l: float, h: float, forme: String, f := 0.25) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(l * 0.5, 0)])
	match forme:
		"plein_cintre":
			var r := l * 0.5
			pts.append(Vector2(l * 0.5, h - r))
			pts.append_array(Outils.arc(Vector2(0, h - r), r, 0.0, PI, 12))
			pts.append(Vector2(-l * 0.5, h - r))
		"surbaisse":
			var R := (l * l * 0.25 + f * f) / (2.0 * f)
			var c := Vector2(0, h - R)
			var a := asin(l * 0.5 / R)
			pts.append(Vector2(l * 0.5, h - f))
			pts.append_array(Outils.arc(c, R, PI * 0.5 - a, PI * 0.5 + a, 10))
		_:
			pts.append(Vector2(l * 0.5, h))
			pts.append(Vector2(-l * 0.5, h))
	pts.append(Vector2(-l * 0.5, 0))
	return _sans_doublons(pts)


static func _sans_doublons(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		if out.is_empty() or out[out.size() - 1].distance_to(q) > 1e-4:
			out.append(q)
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) < 1e-4:
		out.remove_at(out.size() - 1)
	return out


## L'encadrement d'une baie (contour convexe pts) : une face de largeur e en avant, de z0 à z1, ses flancs
## extérieurs, et les tableaux intérieurs qui descendent jusqu'au verre (col_tableau, plus sombre).
static func _cadre(o: Outils, t: Transform3D, pts: PackedVector2Array, e: float, z0: float, z1: float, col: Color, col_tableau: Color) -> void:
	pts = _sans_doublons(pts)
	if Geometry2D.is_polygon_clockwise(pts):
		pts.reverse()
	var n := pts.size()
	var ext := PackedVector2Array()
	for i in n:
		var a := pts[(i - 1 + n) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		var n1 := Vector2(b.y - a.y, a.x - b.x).normalized()
		var n2 := Vector2(c.y - b.y, b.x - c.x).normalized()
		var m := (n1 + n2).normalized()
		ext.append(b + m * e / maxf(m.dot(n1), 0.35))
	for i in n:
		var j := (i + 1) % n
		var a := pts[i]
		var b := pts[j]
		var ea := ext[i]
		var eb := ext[j]
		var dehors := Vector3(b.y - a.y, a.x - b.x, 0)
		o.quad(t * Vector3(a.x, a.y, z1), t * Vector3(b.x, b.y, z1), t * Vector3(eb.x, eb.y, z1), t * Vector3(ea.x, ea.y, z1), t.basis * Vector3(0, 0, 1), col)
		o.quad(t * Vector3(ea.x, ea.y, z0), t * Vector3(eb.x, eb.y, z0), t * Vector3(eb.x, eb.y, z1), t * Vector3(ea.x, ea.y, z1), t.basis * dehors, col.darkened(0.04))
		o.quad(t * Vector3(a.x, a.y, z0), t * Vector3(b.x, b.y, z0), t * Vector3(b.x, b.y, z1), t * Vector3(a.x, a.y, z1), t.basis * -dehors, col_tableau)
