class_name Tables
extends RefCounted
## Les tables du casino de Smarves, prêtées aux communes (socle 1.10, docs/COMMUNE.md, « Les tables du
## casino ») : les tables 3D du casino (scripts/jeux/*_3d.gd : la roulette et son cylindre, le blackjack
## et son sabot, la machine à vrais tambours, le craps, le baccara, le poker, la roue, le grand hasard),
## les panneaux de jeu (SalleJeu.JEUX) et leur habillage, et le geste du casino : on s'assoit, la caméra
## glisse jusqu'à la place, le panneau devient la barre basse. Ce sont les fichiers du casino, pas une
## copie : quand le casino change ses tables, toutes les communes les ont au prochain jeu.
##
## La salle de jeu du socle s'en sert (scripts/socle/salle_jeu.gd) ; une commune qui bâtit sa propre
## salle aussi :
##   var t := Tables.table("roulette")        # la table, place du joueur du côté +z
##   add_child(t)                              # posée dans la scène, avant de s'asseoir
##   var p := Tables.panneau("roulette")       # le panneau du jeu, celui du casino
##   p.played.connect(func(mise, gain): Game.cash_in(gain))
##   p.closed.connect(func(): Tables.lever(t); p.queue_free())
##   Tables.asseoir(t, p, player.camera, calque)   # calque : un Control plein écran habillé de Tables.theme()

const BARRE := preload("res://scripts/jeux/barre.gd")

## Les jeux qui ont une table 3D au casino, par nom de manifeste (Structures.JEUX). Le loto et les courses
## n'en ont pas : leur panneau s'ouvre au milieu de l'écran, habillé de theme().
const MODELES := {
	"machine": "res://scripts/jeux/slot_3d.gd",
	"blackjack": "res://scripts/jeux/blackjack_3d.gd",
	"roulette": "res://scripts/jeux/roulette_3d.gd",
	"craps": "res://scripts/jeux/craps_3d.gd",
	"baccara": "res://scripts/jeux/baccara_3d.gd",
	"poker": "res://scripts/jeux/poker_3d.gd",
	"des": "res://scripts/jeux/hasard_3d.gd",
	"roue": "res://scripts/jeux/roue_3d.gd",
}
## L'emprise au sol de chaque table (largeur en x, profondeur en z, en mètres), sans la place du joueur :
## pour la collision et pour ranger les tables.
const EMPRISE := {
	"machine": Vector2(0.75, 0.65), "blackjack": Vector2(2.8, 1.45), "roulette": Vector2(3.4, 1.5),
	"craps": Vector2(3.4, 1.76), "baccara": Vector2(3.22, 1.66), "poker": Vector2(3.2, 3.2),
	"des": Vector2(2.3, 1.4), "roue": Vector2(2.4, 1.6),
}


## Le jeu a-t-il une table 3D du casino ?
static func a_une_table(jeu: String) -> bool:
	return MODELES.has(jeu)


## Une table 3D du casino pour ce jeu (null pour le loto, les courses ou un jeu inconnu). La place du
## joueur est du côté +z de la table ; « titre » s'écrit au fronton de la machine ou du baccara.
## La table pose sa lampe ; une salle qui a déjà les siennes met with_lamp à false avant de l'ajouter.
static func table(jeu: String, titre := "") -> Node3D:
	if not MODELES.has(jeu):
		return null
	var t: Node3D = load(MODELES[jeu]).new()
	if titre != "" and "title" in t:
		t.title = titre.to_upper() if jeu == "baccara" else titre
	return t


## Le panneau du jeu, celui du casino de Smarves ; « titre » remplace son titre. Le panneau émet
## played(mise, gain) à chaque coup et closed quand on se lève : à la commune d'encaisser (Game.cash_in).
static func panneau(jeu: String, titre := "") -> PanelContainer:
	var jeux: Dictionary = load("res://scripts/socle/salle_jeu.gd").JEUX
	if not jeux.has(jeu):
		return null
	var p: PanelContainer = load(jeux[jeu].panneau).new()
	if "game" in p:
		p.game = Game
	if "mode" in p and jeu == "roue":
		p.mode = "roue"
	if titre != "" and "title" in p:
		p.title = titre
	return p


## S'asseoir à une table 3D déjà dans la scène : le panneau se lie à la table (les cartes, la bille et
## les dés partent sur le tapis), la caméra glisse du regard du joueur jusqu'à sa place, et le panneau
## devient la barre basse du calque (un Control plein écran, habillé de theme()). La souris est libérée.
static func asseoir(t: Node3D, p: Control, camera: Camera3D, calque: Control) -> void:
	t.attach(p)
	t.sit(camera)
	BARRE.dock(p, calque)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Se lever : la caméra revient au regard du joueur. Le panneau, lui, est à libérer par la salle.
static func lever(t: Node3D) -> void:
	if t != null and is_instance_valid(t):
		t.stand()


## L'habillage des fenêtres du casino de Smarves, à la manière d'Addict : laque sombre, filet d'or,
## angles arrondis, ombre portée ; boutons en pastille de 48 px de haut au moins, au doigt aussi.
## À poser sur le Control qui porte les panneaux (Control.theme).
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = Polices.texte()
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.03, 0.035, 0.93)
	panel.border_color = Color(0.89, 0.71, 0.35, 0.55)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(16)
	panel.set_content_margin_all(22)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 24
	panel.anti_aliasing = true
	t.set_stylebox("panel", "PanelContainer", panel)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color(0.14, 0.07, 0.04, 0.95), "hover": Color(0.28, 0.15, 0.06, 0.95),
			"pressed": Color(0.38, 0.22, 0.08, 1.0), "disabled": Color(0.07, 0.06, 0.06, 0.8),
			"focus": Color(0, 0, 0, 0)}[st]
		b.border_color = Color(0.85, 0.62, 0.3, 0.25 if st == "disabled" else 0.8)
		b.set_border_width_all(1)
		b.set_corner_radius_all(24)
		b.anti_aliasing = true
		b.content_margin_left = 20
		b.content_margin_right = 20
		b.content_margin_top = 11
		b.content_margin_bottom = 11
		if st == "focus":
			b.draw_center = false
			b.border_color = Color(0, 0, 0, 0)
		t.set_stylebox(st, "Button", b)
	t.set_color("font_color", "Button", Color(0.96, 0.8, 0.45))
	t.set_color("font_hover_color", "Button", Color(1, 0.92, 0.7))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.42))
	t.set_color("font_color", "Label", Color(0.9, 0.86, 0.8))
	return t
