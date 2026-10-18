extends RefCounted
## Les articles des commerces d'une commune (la structure « commerce », socle 1.4) : leur vérification,
## dans les mots du rapport du portail, et leurs fiches au catalogue de Biens. La boutique elle-même est
## une scène du socle (scripts/socle/commerce.gd) ; ce fichier n'a besoin d'aucun autoload.

const NOTAIRE := preload("res://scripts/socle/notaire.gd")
const GENRES := ["tenue", "vehicule", "meuble"]
## Où se pose un meuble chez soi (Biens, « slot »).
const EMPLACEMENTS := ["lit", "sol", "grand", "mur", "petit", "jardin"]
const CHAMPS_ARTICLE := ["id", "nom", "prix", "standing", "seuil", "max", "phrase", "couleur", "modele", "emplacement"]
const ARTICLES_MAX := 24
## Ce que dit le bon de commande, par genre : l'en-tête et le merci.
const BONS := {
	"tenue": ["Bon de commande  ·  sur mesure, livré le soir même", ["« Il vous va comme un gant. »", "« Avec ça, on vous ouvrira toutes les portes. »"]],
	"vehicule": ["Bon de commande  ·  le plein est fait", ["« Elle vous attend devant la porte. »", "« Rodage en douceur, hein. »"]],
	"meuble": ["Bon d'achat  ·  livré chez vous, posé où vous voulez", ["« Livré ce soir. Vous le poserez où vous voudrez. »", "« Une bonne affaire. »"]],
}


## Les fiches du catalogue de Biens qu'ajoutent les commerces de la commune, une par article.
static func fiches(c: Commune) -> Array:
	var out := []
	if c == null:
		return out
	for s in Structures.nettoyer(c.data.get("structures")):
		if s.type == "commerce":
			for a in s.articles:
				out.append(fiche(c, s, a))
	return out


## Un article au format du catalogue : une tenue ou un véhicule coûte des charges (un peu moins d'un
## centième du prix par recette), un meuble rien ; le standing vient de l'article, sinon du prix.
static func fiche(c: Commune, s: Dictionary, a: Dictionary) -> Dictionary:
	var genre := str(s.genre)
	var price := int(a.prix)
	var f := {"id": NOTAIRE.cle(c, str(a.id)), "kind": genre, "seller": "commerce", "commerce": "%s/%s" % [c.data.id, s.id],
		"commune": str(c.data.id), "name": str(a.nom), "price": price, "growth": 1.0, "max": int(a.get("max", 1)),
		"rente": 0, "charge": 0 if genre == "meuble" else int(round(price / 130.0)),
		"standing": int(a.get("standing", 1 + int(price / 2500))), "gate": int(a.get("seuil", 0)),
		"from": str(s.get("tenancier", s.nom)), "blurb": str(a.get("phrase", "")), "model": str(a.get("modele", ""))}
	if genre == "tenue":
		f.color = Color.html(str(a.get("couleur", "#2a3a6a")))
	elif genre == "meuble":
		f.slot = str(a.get("emplacement", "sol"))
	return f


## Les erreurs propres à un commerce (le genre et les articles), dans les mots du rapport du portail.
## « vus » garde les ids d'articles de toute la commune : deux commerces ne vendent pas le même id.
static func verifier(s: Dictionary, vus: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var id := str(s.get("id", ""))
	var genre := str(s.get("genre", ""))
	if s.has("genre") and not genre in GENRES:
		out.append("structure %s : genre inconnu « %s » (tenue, vehicule, meuble)" % [id, genre])
	if typeof(s.get("articles")) != TYPE_ARRAY:
		return out
	if s.articles.size() > ARTICLES_MAX:
		out.append("structure %s : %d articles au plus" % [id, ARTICLES_MAX])
	for a in s.articles:
		if typeof(a) != TYPE_DICTIONARY or str(a.get("id", "")) == "":
			out.append("structure %s : un article sans id" % id)
			continue
		var aid := str(a.id)
		var p := "structure %s : article %s" % [id, aid]
		if not aid.is_valid_identifier() or aid != aid.to_lower():
			out.append("%s : id invalide (minuscules, chiffres, _)" % p)
		elif vus.has(aid):
			out.append("%s en double" % p)
		vus[aid] = true
		for k in a:
			if not k in CHAMPS_ARTICLE:
				out.append("%s : champ inconnu « %s »" % [p, k])
		if typeof(a.get("nom")) != TYPE_STRING or str(a.nom).strip_edges() == "":
			out.append("%s : il lui faut un nom" % p)
		if not typeof(a.get("prix")) in [TYPE_INT, TYPE_FLOAT] or int(a.prix) <= 0:
			out.append("%s n'a pas de prix" % p)
		for k in ["standing", "seuil", "max"]:
			if a.has(k) and (not typeof(a[k]) in [TYPE_INT, TYPE_FLOAT] or float(a[k]) < 0 or float(a[k]) != floorf(a[k])):
				out.append("%s : « %s » est un nombre entier positif" % [p, k])
		for k in ["phrase", "couleur", "modele", "emplacement"]:
			if a.has(k) and typeof(a[k]) != TYPE_STRING:
				out.append("%s : « %s » est un texte" % [p, k])
		if typeof(a.get("couleur")) == TYPE_STRING and not Color.html_is_valid(a.couleur):
			out.append("%s : couleur « #rrggbb »" % p)
		if typeof(a.get("modele")) == TYPE_STRING and a.modele != "" and not str(a.modele).begins_with("res://"):
			out.append("%s : modele est un chemin res://" % p)
		if genre == "meuble":
			if str(a.get("modele", "")) == "":
				out.append("%s : un meuble a besoin d'un modele" % p)
			if typeof(a.get("emplacement")) == TYPE_STRING and not a.emplacement in EMPLACEMENTS:
				out.append("%s : emplacement inconnu « %s » (lit, sol, grand, mur, petit, jardin)" % [p, a.emplacement])
	return out
