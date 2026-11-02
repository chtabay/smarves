extends Node
## Une Mobylette bleue dans chaque commune (autoload « Mobylettes », socle 1.31 ; Guillaume, 31 octobre 2026 :
## « l'ajout des mobylettes comme à Smarves devrait être disponible sur chaque map »). À l'arrivée dans la
## scène d'une commune greffée, le socle gare la Mobylette du socle (scripts/socle/mobylette.gd) à côté de
## l'habitant, sans que le paquet ait rien à coder. Les paquets déjà publiés en ont donc une aussi.
##
## Le socle n'en pose pas :
## - dans une commune qui a déjà les siennes (Belley, Lyon : une zone « interact » = « mobylette ») ;
## - dans un intérieur ou une salle (seule la scène du manifeste, `scene`, en reçoit une) ;
## - quand le manifeste dit `"mobylette": false`, ou la scène `var mobylette := false` ;
## - à Casino Minuit, qui n'est qu'un casino (SANS, pour le paquet déjà publié) ;
## - à Smarves, qui a ses véhicules du garage Fradin (scripts/village/conduite.gd).

const MOBYLETTE := preload("res://scripts/socle/mobylette.gd")
## Les communes publiées avant le champ `mobylette` du manifeste et qui n'en veulent pas.
const SANS := ["casino_minuit"]
## Les images à laisser à la scène après qu'elle s'est bâtie, le temps qu'elle pose son habitant.
const ATTENTE := 5

var _scene: Node = null
var _a_voir := false
var _images := 0


func _process(_delta: float) -> void:
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_a_voir = s != null
		_images = 0
	if not _a_voir or not is_instance_valid(s) or not s.is_inside_tree():
		return
	# Une scène qui se bâtit sur plusieurs images le dit (Chargement) : on attend qu'elle ait fini.
	var ch = s.get("chargement")
	if ch is float and ch < 1.0:
		return
	var p = s.get("player")
	if not (p is CharacterBody3D and is_instance_valid(p) and p.is_inside_tree()):
		return
	_images += 1
	if _images < ATTENTE:
		return
	_a_voir = false
	if voulue(s):
		s.add_child(MOBYLETTE.new(s))


## La scène `s` reçoit la Mobylette du socle (voir en tête).
func voulue(s: Node) -> bool:
	if s == null or not s is Node3D or s.has_method("set_fps"):
		return false
	var chemin := s.scene_file_path
	if not chemin.begins_with("res://communes/"):
		return false
	var id := chemin.trim_prefix("res://communes/").get_slice("/", 0)
	var c: Commune = Communes.commune(id)
	if c == null or id in SANS or chemin != str(c.data.get("scene", "")):
		return false
	if c.data.get("mobylette", true) == false or s.get("mobylette") == false:
		return false
	var p = s.get("player")
	if not (p is CharacterBody3D and p.has_signal("interact") and "body_height" in p):
		return false
	return not deja_garee(s)


## La commune a déjà ses Mobylettes (la sienne ou celle du socle).
static func deja_garee(s: Node) -> bool:
	if not s.get_tree().get_nodes_in_group("mobylettes").filter(func(n): return s.is_ancestor_of(n)).is_empty():
		return true
	for a in s.find_children("*", "Area3D", true, false):
		if str(a.get_meta("interact", "")) == "mobylette":
			return true
	return false
