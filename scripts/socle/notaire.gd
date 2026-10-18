extends RefCounted
## L'étude du notaire d'une commune : qui la tient, et son registre, toutes les adresses à vendre posées
## sur un plan par quartiers. Rien ici n'est propre à Smarves : la commune déclare son notaire dans le
## champ « notaire » de son manifeste, et le plan de l'étude (carte_biens.gd) se dessine depuis ces
## données. La notice est dans docs/COMMUNE.md, section « Le notaire ».
##
##   "notaire": {
##     "nom": "Maître Garnier", "etude": "L'étude de Maître Garnier",
##     "titre": "Étude de Maître Garnier, notaire à Smarves",
##     "registre": {"source": "res://…/adresses.gd"}      ← un script qui rend le registre (static func registre())
##              ou {"quartiers": [...], "adresses": [...]} ← le registre écrit dans le manifeste
##   }
##
## Un quartier : {id, nom, style (« plan » ou « rue »), decor, textes, liens}, sur un papier de 1000 × 620.
##   decor : [{forme « rect », rect [x, y, l, h], teinte}] ou [{forme « rond », centre [x, y], rayon, teinte}] ;
##           teinte : place, route, chemin, jardin, cour, fond.
##   textes : [{texte, rect, taille, centre}] ; liens : [{rect, vers (un quartier), texte}].
## Une adresse : {id, quartier, rect, etiquette, numero, ligne, genre, …}. genre : « maison » (un logement
## qu'on habite ou qu'on loue), « murs » (une boutique : le commerçant reste et paie), « public » (la
## commune reste et paie), ou « part » (id renvoie à un bien déjà au catalogue). Les trois premiers
## portent leur fiche : nom, prix, de (qui cède), phrase, et pour une maison interieur (un gabarit de
## Biens) ; standing est facultatif.

const PAPIER := Vector2(1000.0, 620.0)
const GENRES := ["maison", "murs", "public", "part"]

static var _registres := {}


## Qui tient l'étude : {nom, etude, titre}, avec des valeurs par défaut pour une commune qui n'en dit rien.
static func etude(c: Commune) -> Dictionary:
	var n: Dictionary = c.data.get("notaire", {}) if c != null else {}
	var nom := str(n.get("nom", "Le notaire"))
	var commune_nom := str(c.data.get("nom", "")) if c != null else ""
	return {"nom": nom, "etude": str(n.get("etude", "L'étude de %s" % nom)),
		"titre": str(n.get("titre", "Étude de %s, notaire à %s" % [nom, commune_nom]))}


## Le registre de la commune, lu une fois : {quartiers: [...], adresses: [...]}, rects en Rect2.
static func registre(c: Commune) -> Dictionary:
	if c == null:
		return {"quartiers": [], "adresses": []}
	var key := str(c.data.get("id", ""))
	if _registres.has(key):
		return _registres[key]
	var r: Variant = c.data.get("notaire", {}).get("registre", {})
	var brut := {}
	if typeof(r) == TYPE_DICTIONARY and r.has("source"):
		var s: Variant = load(str(r.source))
		if s != null:
			brut = s.registre()
	elif typeof(r) == TYPE_DICTIONARY:
		brut = r
	var reg := {"quartiers": [], "adresses": []}
	for q in brut.get("quartiers", []):
		reg.quartiers.append(_quartier(q))
	for a in brut.get("adresses", []):
		var ad: Dictionary = a.duplicate()
		ad.rect = _rect(a.get("rect"))
		ad.etiquette = str(a.get("etiquette", a.get("nom", "")))
		ad.numero = int(a.get("numero", 0))
		ad.ligne = str(a.get("ligne", ""))
		reg.adresses.append(ad)
	_registres[key] = reg
	return reg


## Les fiches du catalogue que le registre ajoute : une par adresse qui n'est pas déjà une part.
static func fiches(c: Commune) -> Array:
	var out := []
	var nom: String = etude(c).nom
	for a in registre(c).adresses:
		if str(a.genre) != "part":
			out.append(fiche(a, nom))
	return out


## Une fiche au format du catalogue de Biens. La rente annoncée vaut 10 % du prix par recette (8 % quand
## c'est la commune qui paie), les charges un peu moins d'un centième.
static func fiche(a: Dictionary, notaire := "Le notaire") -> Dictionary:
	var genre := str(a.genre)
	var price := int(a.get("prix", 0))
	var publique := genre == "public"
	var standing := int(a.get("standing", (1 + int(price / 4000)) if genre == "maison" else (2 if publique else 1) + int(price >= 20000)))
	var f := {"id": str(a.id), "kind": "maison" if genre == "maison" else "murs", "seller": "notaire", "name": str(a.get("nom", a.etiquette)),
		"price": price, "growth": 1.0, "max": 1, "rente": int(round(price * (0.08 if publique else 0.1) / 10.0)) * 10,
		"charge": int(round(price / 120.0)), "standing": standing, "gate": int(a.get("seuil", 0)),
		"from": str(a.get("de", notaire)), "blurb": str(a.get("phrase", "")), "adresse": str(a.ligne)}
	if genre == "maison":
		f.lot = str(a.get("lot", a.id))
		f.interieur = str(a.get("interieur", "maison_v1"))
	return f


static func adresse(c: Commune, id: String) -> Dictionary:
	for a in registre(c).adresses:
		if str(a.id) == id:
			return a
	return {}


static func quartier_of(c: Commune, id: String) -> String:
	var a := adresse(c, id)
	return str(a.get("quartier", ""))


## Les erreurs d'un champ « notaire » écrit dans un manifeste (absent : aucune).
static func verifier(n: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if n == null:
		return out
	if typeof(n) != TYPE_DICTIONARY:
		out.append("« notaire » doit être un objet (nom, etude, registre)")
		return out
	var r: Variant = n.get("registre", {})
	if typeof(r) != TYPE_DICTIONARY:
		out.append("notaire.registre doit être un objet")
		return out
	if r.has("source"):
		return out
	var quartiers := {}
	for q in r.get("quartiers", []):
		if typeof(q) != TYPE_DICTIONARY or str(q.get("id", "")) == "":
			out.append("notaire.registre : un quartier sans id")
			continue
		quartiers[str(q.id)] = true
	for a in r.get("adresses", []):
		if typeof(a) != TYPE_DICTIONARY or str(a.get("id", "")) == "":
			out.append("notaire.registre : une adresse sans id")
			continue
		if not quartiers.has(str(a.get("quartier", ""))):
			out.append("l'adresse %s est dans un quartier inconnu" % a.id)
		if not str(a.get("genre", "")) in GENRES:
			out.append("l'adresse %s : genre inconnu (maison, murs, public ou part)" % a.id)
		elif str(a.genre) != "part" and int(a.get("prix", 0)) <= 0:
			out.append("l'adresse %s n'a pas de prix" % a.id)
		if typeof(a.get("rect")) != TYPE_ARRAY or a.rect.size() != 4:
			out.append("l'adresse %s : rect doit être [x, y, largeur, hauteur]" % a.id)
	return out


static func _quartier(q: Dictionary) -> Dictionary:
	var out := {"id": str(q.get("id", "")), "nom": str(q.get("nom", "")), "style": str(q.get("style", "plan")),
		"decor": [], "textes": [], "liens": []}
	for d in q.get("decor", []):
		if str(d.get("forme", "rect")) == "rond":
			var c: Array = d.get("centre", [0, 0])
			out.decor.append({"forme": "rond", "centre": Vector2(c[0], c[1]), "rayon": float(d.get("rayon", 10)), "teinte": str(d.get("teinte", "route"))})
		else:
			out.decor.append({"forme": "rect", "rect": _rect(d.get("rect")), "teinte": str(d.get("teinte", "place"))})
	for t in q.get("textes", []):
		out.textes.append({"texte": str(t.get("texte", "")), "rect": _rect(t.get("rect")), "taille": int(t.get("taille", 18)), "centre": bool(t.get("centre", true))})
	for l in q.get("liens", []):
		out.liens.append({"rect": _rect(l.get("rect")), "vers": str(l.get("vers", "")), "texte": str(l.get("texte", ""))})
	return out


static func _rect(v: Variant) -> Rect2:
	if v is Rect2:
		return v
	if typeof(v) == TYPE_ARRAY and v.size() == 4:
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return Rect2()
