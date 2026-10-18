class_name Atelier
extends RefCounted
## L'atelier du socle : ce que le jeu prête aux communes pour construire leur scène, sous des noms qui ne
## bougent pas quand le code de Smarves change. Le catalogue est scripts/socle/atelier.json, que lit
## aussi le serveur MCP du kit (tools/mcp/kit_communes.py) ; le mode d'emploi est dans docs/COMMUNE.md,
## section « L'atelier du socle ».
##
## Rien de ceci ne part dans le paquet d'une commune : ce sont des ressources du jeu, déjà chez le joueur.
## Une commune qui s'en sert ne pèse que son propre code.

const CATALOGUE := "res://scripts/socle/atelier.json"
const FACADES := preload("res://scripts/village/facades.gd")
const MEUBLES := preload("res://scripts/meubles.gd")
const VILLAGER := preload("res://scripts/villager.gd")

static var _catalogue: Dictionary = {}


## Le catalogue entier (atelier.json), lu une fois.
static func catalogue() -> Dictionary:
	if _catalogue.is_empty():
		_catalogue = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
	return _catalogue


# --- Les modèles -----------------------------------------------------------------------------------

## Les familles de modèles : nature, ville, voitures, mobilier, restaurant, arcade, marche, salon.
static func familles() -> PackedStringArray:
	return PackedStringArray(catalogue().modeles.keys())


## Les modèles d'une famille, par nom (« tree_oak »), triés.
static func modeles(famille: String) -> PackedStringArray:
	var out := PackedStringArray()
	var f: Dictionary = catalogue().modeles.get(famille, {})
	if f.is_empty():
		return out
	var d := DirAccess.open(f.dossier)
	if d == null:
		return out
	for n in d.get_files():
		# Dans le jeu exporté, l'original est remplacé par son .import : on lit les deux.
		var nom := n.trim_suffix(".import").trim_suffix(".remap")
		if (nom.ends_with(".glb") or nom.ends_with(".gltf")) and not out.has(nom.get_basename()):
			out.append(nom.get_basename())
	out.sort()
	return out


## Le chemin d'un modèle « famille/nom » (« nature/tree_oak »), ou « » s'il n'existe pas.
static func chemin(id: String) -> String:
	var morceaux := id.split("/")
	if morceaux.size() != 2:
		return ""
	var f: Dictionary = catalogue().modeles.get(morceaux[0], {})
	if f.is_empty():
		return ""
	for ext in [".glb", ".gltf"]:
		var p: String = f.dossier + morceaux[1] + ext
		if ResourceLoader.exists(p):
			return p
	return ""


## Un modèle prêt à poser, pied au sol, nommé d'après lui. hauteur > 0 le met à cette hauteur (en unités
## du jeu : l'habitant mesure 0,7) ; sinon la hauteur conseillée de sa famille, sinon sa taille d'origine.
## Renvoie null si l'id est inconnu.
static func modele(id: String, hauteur := 0.0) -> Node3D:
	var p := chemin(id)
	if p == "":
		push_warning("Atelier : modèle inconnu « %s »" % id)
		return null
	var racine := Node3D.new()
	racine.name = id.get_file().to_pascal_case()
	var n: Node3D = (load(p) as PackedScene).instantiate()
	racine.add_child(n)
	if hauteur <= 0.0:
		hauteur = float(catalogue().modeles[id.get_slice("/", 0)].get("hauteur", 0.0))
	if hauteur > 0.0:
		var b := _boite(n, Transform3D.IDENTITY)
		if b.size.y > 0.001:
			n.scale = Vector3.ONE * (hauteur / b.size.y)
	return racine


static func _boite(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var vide := true
	var ici := xf * (n as Node3D).transform if n is Node3D else xf
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out = ici * (n as MeshInstance3D).mesh.get_aabb()
		vide = false
	for c in n.get_children():
		var b := _boite(c, ici)
		if b.size != Vector3.ZERO:
			out = b if vide else out.merge(b)
			vide = false
	return out


# --- Les maisons -----------------------------------------------------------------------------------

## Un atelier de façades posé sous parent : appeler house(xf, spec) autant de fois qu'il faut, puis
## commit(Atelier.matieres_maisons(), …). La graine fixe le tirage des teintes : la rue est la même à
## chaque visite. Voir atelier.json, « maisons », pour les champs de spec.
static func maisons(parent: Node3D, graine := 1) -> RefCounted:
	return FACADES.new(parent, Polices.texte(), graine)


## Les matières des maisons de Smarves : murs et encadrements en calcaire, tuiles canal, vitres.
static func matieres_maisons() -> Dictionary:
	var stone: Shader = load("res://shaders/village_stone.gdshader")
	var wall := ShaderMaterial.new()
	wall.shader = stone
	var trim := ShaderMaterial.new()
	trim.shader = stone
	var roof := ShaderMaterial.new()
	roof.shader = load("res://shaders/roof_tiles.gdshader")
	var glass := ShaderMaterial.new()
	glass.shader = load("res://shaders/window_glow.gdshader")
	glass.set_shader_parameter("energy", 1.6)
	return {"wall": wall, "trim": trim, "roof": roof, "glass": glass}


## Une rue d'un coup : [[Transform3D, spec], …] posées sous parent, en un seul maillage par matière.
static func rue(parent: Node3D, maisons_: Array, graine := 1, nom := "Maisons") -> void:
	var f = maisons(parent, graine)
	for m in maisons_:
		f.house(m[0], m[1])
	var mats := matieres_maisons()
	f.commit(mats, mats.glass, nom)


# --- Les figurants, les meubles --------------------------------------------------------------------

## Un habitant anonyme dessiné comme ceux de Smarves. pose : « idle », « sit » ou « walk » (avec route,
## deux points ou plus, en coordonnées du parent). tenue : « village » ou « soiree ». La graine fixe son
## allure : le même figurant d'une partie à l'autre. Le poser (position, rotation) avant add_child.
static func figurant(graine := 0, pose := "idle", tenue := "village", route: Array[Vector3] = []) -> Node3D:
	var v: Node3D = VILLAGER.new()
	v.name = "Figurant%d" % graine
	v.model_path = "figurant-%d" % graine
	v.pose = pose
	v.tenue = tenue
	v.route = route
	return v


## Un meuble de la brocante (atelier.json, « meubles ») : à l'échelle d'un intérieur, face vers +Z.
static func meuble(id: String) -> Node3D:
	if not id in catalogue().meubles.ids:
		push_warning("Atelier : meuble inconnu « %s »" % id)
		return null
	return MEUBLES.build(id)


# --- Les sons, les matières ------------------------------------------------------------------------

## Un bruitage du jeu (atelier.json, « sons ») : « chips », « card », « dice », « win »…
static func son(groupe: String, volume_db := 0.0) -> void:
	Sfx.play(groupe, volume_db)


## L'ambiance de fond : « village » ou « casino ».
static func ambiance(nom: String) -> void:
	Sfx.set_ambience(nom)


## Une matière du jeu (atelier.json, « matieres ») : pavés, eau, tapis, damas, marbre, feutre…
static func matiere(nom: String) -> ShaderMaterial:
	var p := str(catalogue().matieres.get(nom, ""))
	if p == "":
		push_warning("Atelier : matière inconnue « %s »" % nom)
		return null
	var m := ShaderMaterial.new()
	m.shader = load(p)
	return m
