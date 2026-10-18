extends RefCounted
## Les adresses du village, toutes à vendre chez Maître Garnier : chaque façade de la rue du Clain, de
## la route du Bois et de la place a son numéro, et son acte au registre. Les rues sont lues dans
## l'agencement du village (village.gd, NORTH_ROW…) : une façade ajoutée là y gagne son adresse.
##
## Trois genres de biens : la maison particulière (un logement, qu'on habite ou qu'on loue, docs/SUITE.md
## section 3), les murs d'une boutique (le commerçant reste et paie son loyer), les murs d'un bâtiment
## public (la commune reste et paie, moins bien). Les cafés, les salles et le casino gardent leurs parts
## (Biens.CATALOGUE) : leur adresse renvoie à la part. Acheter les murs n'ouvre pas une porte : un lieu
## à seuil reste fermé avant son seuil, à qui qu'il soit.
##
## Numérotation : de la place vers les environs, impairs côté nord, pairs côté sud.

const VILLAGE := preload("res://scripts/village/village.gd")

## Les rues : où commence le premier numéro (abscisse, côté place) et vers où l'on s'éloigne.
const RUES := {
	"rue_du_clain": {"nom": "rue du Clain", "x": VILLAGE.CLAIN_X0 - 0.5, "dir": -1.0},
	"route_du_bois": {"nom": "route du Bois", "x": VILLAGE.BOIS.X0 + 0.5, "dir": 1.0},
}
## Ce qui a une porte à soi dans une rangée ; le reste (jardin, porche, ruelle, vide) n'est pas une adresse.
const BATIS := ["house", "pavillon", "garage", "ecole", "stade"]

## Les façades nommées : id du lot → [nom, genre, qui cède, sa phrase, prix]. genre : « murs »
## (une boutique), « public » (la commune), ou un id du catalogue de Biens (la part existe déjà).
const NOMMEES := {
	"notaire": ["Les murs de l'étude de Maître Garnier", "murs", "Maître Garnier", "« Je resterai votre locataire, et votre notaire. Le loyer part le premier du mois, l'acte, lui, est déjà prêt. »", 9000],
	"poste": ["Les murs de la poste", "public", "Le receveur", "« Les PTT louent depuis 1931. Ils n'ont jamais eu un jour de retard, c'est le métier. »", 12000],
	"boucherie": ["Les murs de la boucherie Texier", "murs", "M. Texier", "« Je garde le pas-de-porte, vous gardez le loyer. Et un rôti le dimanche, entre nous. »", 6500],
	"lot_reserve": ["Les murs de la charge Vasseur & Cie", "murs", "Mme Vasseur", "« Mon bail court neuf ans. Les marchés, eux, courent beaucoup plus vite. »", 8000],
	"coiffure": ["Les murs de Gisèle Coiffure", "murs", "Gisèle", "« Le samedi, c'est complet jusqu'à midi. Le loyer, lui, ne bouge pas, c'est reposant. »", 5500],
	"couture": ["Les murs de l'atelier de Raymonde", "murs", "Raymonde", "« J'y suis depuis mes dix-neuf ans. Je ne bougerai pas, mais le loyer peut changer de poche. »", 5500],
	"pizzeria": ["Les murs de la Pizzeria du Clain", "murs", "Tonio", "« Le four à bois reste, moi aussi. Complet tous les soirs, le loyer tombe tous les mois. »", 6000],
	"epicerie": ["Les murs de l'Épicerie du Bourg", "murs", "Mme Pineau", "« Alimentation, primeurs, gaz. Et un loyer, maintenant, mais à vous. »", 6000],
	"fleurs": ["Les murs de Fleurs Odette", "murs", "Odette", "« Mariages, fêtes, deuils : il y a toujours une occasion. Pour le loyer aussi. »", 5000],
	"brocante": ["Les murs de la brocante Boutin", "murs", "Ginette Boutin", "« Tout s'achète, tout se revend. Les murs aussi, la preuve. »", 5500],
	"bibliotheque": ["Les murs de la bibliothèque municipale", "public", "Le conseil municipal", "« La commune reste locataire. Elle paie tard, mais elle paie, et elle prête des livres. »", 15000],
	"garage": ["Les murs du garage Fradin", "murs", "Roger Fradin", "« L'atelier, la fosse, la pompe. Je garde la clé, vous gardez le loyer. »", 9000],
	"pharmacie": ["Les murs de la pharmacie", "murs", "Le pharmacien", "« Une officine ne ferme jamais tout à fait. Le loyer non plus. »", 8500],
	"lot_bois": ["Le local de la route du Bois", "murs", "Maître Garnier", "« Vacant. Un commerce viendra, le loyer avec lui ; en attendant, c'est la commune qui l'occupe. »", 4500],
	"ecole": ["Les murs de l'école publique", "public", "Le conseil municipal", "« L'école reste l'école. La commune vous verse son loyer, et vous lui devez le respect. »", 25000],
	"stade": ["Le stade municipal", "etoile", "", "", 0],
}
## La place et ses abords, sur le plan du notaire (un schéma : chaque case assez grande pour son nom et son
## prix). id → [adresse, genre, qui cède, sa phrase, prix, nom de l'acte, étiquette, case] ; genre comme
## ci-dessus. La maison de la rue de l'Église est rapprochée de la place ; le Moulin et le stade sont aux
## deux bouts de la route.
const PLACE := {
	"maison_place": ["1, place de la Mairie", "maison_place", "", "", 0, "", "Maison de maître", Rect2(170, 135, 190, 80)],
	"adr_mairie": ["2, place de la Mairie", "public", "Le maire", "« La mairie reste la mairie, Monsieur. Le conseil vote votre loyer à l'unanimité, moins une voix. »", 40000, "Les murs de la mairie", "Mairie", Rect2(390, 135, 130, 85)],
	"adr_eglise": ["3, place de la Mairie", "public", "Le père Moreau", "« La paroisse reste locataire de la maison du Bon Dieu. Il paiera ; lui, au moins, on sait qu'il est solvable. »", 30000, "Les murs de l'église Saint-Félix", "Église", Rect2(540, 135, 120, 85)],
	"casino": ["4, place de la Mairie", "casino", "", "", 0, "", "Casino", Rect2(680, 135, 160, 110)],
	"chambre": ["5, place de la Mairie", "chambre", "", "", 0, "", "La chambre", Rect2(170, 230, 190, 80)],
	"smarvoise": ["5, place de la Mairie", "smarvoise", "", "", 0, "", "Café de la Place", Rect2(170, 325, 190, 80)],
	"fournil": ["6, place de la Mairie", "fournil", "", "", 0, "", "Boulangerie", Rect2(680, 265, 160, 110)],
	"comite": ["7, place de la Mairie", "comite", "", "", 0, "", "Salle Rabelais", Rect2(170, 420, 190, 80)],
	"adr_banque": ["8, place de la Mairie", "public", "M. Brunet", "« Le Crédit Smarvois locataire de son client : c'est une première, et je la finance volontiers. »", 50000, "Les murs du Crédit Smarvois", "Crédit Smarvois", Rect2(680, 395, 160, 85)],
	"maison": ["2, rue de l'Église", "maison", "", "", 0, "", "Rue de l'Église", Rect2(250, 15, 190, 85)],
	"cotes": ["Le Moulin des Dames", "cotes", "", "", 0, "", "← Moulin des Dames", Rect2(10, 535, 220, 75)],
	"etoile": ["Le stade municipal", "etoile", "", "", 0, "", "Stade municipal →", Rect2(770, 535, 220, 75)],
}

## Une rue sur le papier du plan : la chaussée au milieu, les façades nord au-dessus, sud au-dessous ;
## l'abscisse du monde aux deux bords du dessin, et ce qu'il y a à chaque bout.
const ROAD_BAND := Rect2(0, 275, 1000, 60)
const NORTH_BAND := Rect2(0, 60, 1000, 207)
const SOUTH_BAND := Rect2(0, 343, 1000, 207)
const STREET_X := Vector2(140, 860)
const END_LEFT := Rect2(8, 260, 124, 90)
const END_RIGHT := Rect2(868, 260, 124, 90)
const MONDE := {"rue_du_clain": Vector2(-50.0, -11.3), "route_du_bois": Vector2(11.3, 57.0)}

## Ce que dit Maître Garnier d'une maison particulière, tiré à son numéro.
const PHRASES_MAISON := [
	"« Volets refaits, toiture saine, la cave est sèche. Louée, elle se paie toute seule ; habitée, elle vous ressemble. »",
	"« Une maison de bourg, comme on n'en fait plus. Le voisin est discret, je l'ai vérifié. »",
	"« Le grenier est immense. On y range une vie entière, et ce que la vie vous rapporte au casino. »",
	"« La dernière occupante y a vécu soixante ans. Elle disait que la maison portait chance. »",
	"« Les fenêtres donnent sur la rue : vous verrez passer tout Smarves, et tout Smarves vous verra. »",
]
const PHRASES_PAVILLON := [
	"« Un pavillon des années soixante, avec son garage et sa haie de thuyas. Le calme, à deux pas du stade. »",
	"« Sous-sol complet, jardin clos. Le genre de maison où l'on reçoit le dimanche. »",
]

## Le nom court d'une façade sans enseigne, pour le plan.
const COURTS := {"notaire": "Étude Garnier", "garage": "Garage Fradin", "ecole": "École", "lot_reserve": "Vasseur & Cie",
	"lot_bois": "Local vacant", "stade": "Stade municipal", "poste": "La Poste", "bibliotheque": "Bibliothèque"}

static var _toutes: Array = []
static var _par_id := {}
static var _terrains: Array = []


## Toutes les adresses de la rue du Clain et de la route du Bois, dans l'ordre de la rue :
## [{id, rue, numero, nord, x0, x1, w, floors, lot, genre, nom, item}]. item : l'id du bien au catalogue.
static func rues() -> Array:
	if _toutes.is_empty():
		_recenser()
	return _toutes


static func adresse(item_id: String) -> Dictionary:
	if _toutes.is_empty():
		_recenser()
	return _par_id.get(item_id, {})


## Ce qui borde la rue sans être une adresse (jardins, porches, ruelles) : [{rue, nord, x0, x1, kind}].
static func terrains() -> Array:
	if _toutes.is_empty():
		_recenser()
	return _terrains


static func _recenser() -> void:
	for rue in ["rue_du_clain", "route_du_bois"]:
		var rangs := [[VILLAGE.NORTH_ROW, true], [VILLAGE.SOUTH_ROW, false]] if rue == "rue_du_clain" else [[VILLAGE.BOIS_NORTH, true], [VILLAGE.BOIS_SOUTH, false]]
		for rang in rangs:
			var x: float = RUES[rue].x
			var dir: float = RUES[rue].dir
			var numero := 1 if rang[1] else 2
			for spec in rang[0]:
				var kind: String = spec.get("kind", "house")
				var w: float = spec.w
				if spec.has("to"):
					w = absf(spec.to - x)
				var x0 := x
				x += dir * w
				if not kind in BATIS:
					if kind != "vide":
						_terrains.append({"rue": rue, "nord": rang[1], "x0": minf(x0, x), "x1": maxf(x0, x), "kind": kind})
					continue
				var a := {"rue": rue, "numero": numero, "nord": rang[1], "x0": minf(x0, x), "x1": maxf(x0, x), "w": w,
					"floors": int(spec.get("floors", 1)), "lot": str(spec.get("id", "")), "kind": kind}
				numero += 2
				_nommer(a, spec)
				_toutes.append(a)
				_par_id[a.item] = a


## Ce qu'est l'adresse : une boutique, un bâtiment public, une maison ou un pavillon, et sa fiche.
static func _nommer(a: Dictionary, spec: Dictionary) -> void:
	var rue: String = RUES[a.rue].nom
	var ou := "%d, %s" % [a.numero, rue]
	var surface: float = a.w * maxi(1, a.floors)
	if NOMMEES.has(a.lot):
		var n: Array = NOMMEES[a.lot]
		a.nom = str(COURTS.get(a.lot, spec.get("shop", {}).get("name", n[0])))
		if not n[1] in ["murs", "public"]:
			# La part existe déjà au catalogue : l'adresse la montre, elle ne la double pas.
			a.genre = "part"
			a.item = str(n[1])
			return
		a.genre = n[1]
		a.item = "adr_" + a.lot
		a.fiche = {"nom": str(n[0]), "de": str(n[2]), "phrase": str(n[3]), "prix": int(n[4])}
		return
	var pavillon: bool = a.kind == "pavillon"
	a.genre = "maison"
	a.item = "adr_%s_%d" % ["clain" if a.rue == "rue_du_clain" else "bois", a.numero]
	a.nom = "n° %d" % a.numero
	# Le prix suit la façade et les étages ; un pavillon a son jardin et son garage.
	var price := int(round((1800.0 + 900.0 * surface + (1200.0 if pavillon else 0.0)) / 100.0)) * 100
	var interieur := "pavillon_v1" if pavillon else ("maisonnette_v1" if a.floors <= 1 else ("maison_v1" if a.floors == 2 else "maison_haute_v1"))
	var phrases: Array = PHRASES_PAVILLON if pavillon else PHRASES_MAISON
	var titre := "Le pavillon du %s" % ou if pavillon else "La maison du %s" % ou
	a.fiche = {"nom": titre, "de": "Maître Garnier", "phrase": str(phrases[a.numero % phrases.size()]), "prix": price, "interieur": interieur}


# --- Le registre du notaire (scripts/socle/notaire.gd), tel que le manifeste de Smarves le désigne -------

## Le registre de Smarves : la place en schéma, la rue du Clain et la route du Bois façade par façade.
static func registre() -> Dictionary:
	var quartiers := [_place()]
	var adresses := []
	for id in PLACE:
		var p: Array = PLACE[id]
		var a := {"id": id, "quartier": "place", "rect": p[7], "etiquette": p[6], "ligne": p[0]}
		if p[1] == "public":
			a.merge({"genre": "public", "nom": p[5], "de": p[2], "phrase": p[3], "prix": p[4]})
		else:
			a.genre = "part"
		adresses.append(a)
	for rue in RUES:
		quartiers.append(_rue(rue))
		for a in rues():
			if a.rue != rue:
				continue
			var ad := {"id": a.item, "quartier": rue, "rect": _street_box(rue, a.x0, a.x1, a.nord), "numero": a.numero,
				"etiquette": "" if a.genre == "maison" else str(a.nom), "ligne": "%d, %s" % [a.numero, RUES[rue].nom], "genre": a.genre}
			if a.has("fiche"):
				ad.merge(a.fiche)
			adresses.append(ad)
	# Le Moulin, au bout de la rue du Clain, comme au bout de la route sur la place.
	adresses.append({"id": "cotes", "quartier": "rue_du_clain", "rect": END_LEFT, "etiquette": "← Moulin des Dames", "ligne": "Le Moulin des Dames", "genre": "part"})
	return {"quartiers": quartiers, "adresses": adresses}


static func _place() -> Dictionary:
	return {"id": "place", "nom": "La place", "style": "plan",
		"decor": [{"forme": "rect", "rect": Rect2(150, 120, 710, 400), "teinte": "place"},
			{"forme": "rect", "rect": Rect2(0, 530, 1000, 70), "teinte": "route"},
			{"forme": "rect", "rect": Rect2(470, 0, 60, 120), "teinte": "chemin"}],
		"textes": [{"texte": "La place de la Mairie", "rect": Rect2(390, 240, 270, 280), "taille": 24},
			{"texte": "Route de Poitiers", "rect": Rect2(250, 540, 500, 50), "taille": 22},
			{"texte": "Chemin de Passelourdin ↑", "rect": Rect2(545, 20, 300, 60), "taille": 22, "centre": false}]}


static func _rue(rue: String) -> Dictionary:
	var nom: String = RUES[rue].nom
	var q := {"id": rue, "nom": "La " + nom, "style": "rue",
		"decor": [{"forme": "rect", "rect": Rect2(STREET_X.x - 6, NORTH_BAND.position.y - 6, STREET_X.y - STREET_X.x + 12, SOUTH_BAND.end.y - NORTH_BAND.position.y + 12), "teinte": "fond"},
			{"forme": "rect", "rect": ROAD_BAND, "teinte": "route"}],
		"textes": [{"texte": nom.left(1).to_upper() + nom.substr(1), "rect": Rect2(300, ROAD_BAND.position.y, 400, ROAD_BAND.size.y), "taille": 24},
			{"texte": "côté impair", "rect": Rect2(STREET_X.x, 20, 300, 36), "taille": 17, "centre": false},
			{"texte": "côté pair", "rect": Rect2(STREET_X.x, 556, 300, 36), "taille": 17, "centre": false}],
		"liens": []}
	for t in terrains():
		if t.rue != rue:
			continue
		var r := _street_box(rue, t.x0, t.x1, t.nord)
		q.decor.append({"forme": "rect", "rect": r, "teinte": "jardin" if t.kind == "jardin" else "cour"})
		if t.kind == "ruelle":
			q.textes.append({"texte": "ruelle", "rect": r, "taille": 14})
	if rue == "rue_du_clain":
		q.liens.append({"rect": END_RIGHT, "vers": "place", "texte": "La place →"})
	else:
		q.liens.append({"rect": END_LEFT, "vers": "place", "texte": "← La place"})
		q.textes.append({"texte": "Le bois →", "rect": END_RIGHT, "taille": 18})
		# Le rond-point du vieux chêne, dans le vide que lui laissent les deux rangées.
		var m: Vector2 = MONDE[rue]
		var per_m := (STREET_X.y - STREET_X.x) / (m.y - m.x)
		var x := STREET_X.x + (VILLAGE.BOIS.ROND_X - m.x) * per_m
		var c := Vector2(x, ROAD_BAND.get_center().y)
		q.decor.append({"forme": "rond", "centre": [c.x, c.y], "rayon": (VILLAGE.BOIS.RING_R + 0.6) * per_m, "teinte": "route"})
		q.decor.append({"forme": "rond", "centre": [c.x, c.y], "rayon": (VILLAGE.BOIS.RING_R + 0.6) * per_m * 0.45, "teinte": "jardin"})
		q.textes.append({"texte": "rond-point", "rect": Rect2(x - 3.0 * per_m, 150, 6.0 * per_m, 40), "taille": 15})
		q.textes.append({"texte": "du vieux chêne", "rect": Rect2(x - 3.0 * per_m, 185, 6.0 * per_m, 40), "taille": 15})
	return q


## La case d'une façade : sa largeur à l'échelle de la rue, la place à droite pour la rue du Clain (on
## part vers l'ouest), à gauche pour la route du Bois.
static func _street_box(rue: String, x0: float, x1: float, north: bool) -> Rect2:
	var m: Vector2 = MONDE[rue]
	var span := STREET_X.y - STREET_X.x
	var a := STREET_X.x + (x0 - m.x) / (m.y - m.x) * span
	var b := STREET_X.x + (x1 - m.x) / (m.y - m.x) * span
	var band := NORTH_BAND if north else SOUTH_BAND
	return Rect2(a + 1.5, band.position.y, b - a - 3.0, band.size.y)
