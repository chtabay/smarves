extends RefCounted
## Les règles des jeux de table, à la manière d'Addict : un bouton « Règles » dans le panneau de chaque
## jeu (la barre basse à une table 3D, ou le panneau au milieu de l'écran) ouvre une fenêtre par-dessus
## la table, sur les règles du jeu en cours. Le coup en cours continue derrière ; Échap, le bouton
## Fermer ou un clic à côté referment la fenêtre sans quitter la table.
##
## Les textes suivent les panneaux (scripts/*_panel.gd, scripts/slot_machine.gd) : qui change un gain
## ou une règle là-bas change la phrase ici. Ils vivent avec les panneaux, si bien que les communes qui
## empruntent les tables du casino (Tables, socle 1.10) ont les règles avec. Seul le jeu en cours est
## expliqué : les jeux qu'on n'a pas encore ouverts restent à découvrir derrière leur seuil.

const BARRE := preload("res://scripts/jeux/barre.gd")

## Le nom du jeu en tête de la fenêtre, par nom de manifeste (SalleJeu.JEUX), plus la Boule du casino.
const NOMS := {
	"machine": "La machine à sous", "blackjack": "Blackjack", "roulette": "Roulette européenne",
	"craps": "Craps", "baccara": "Baccara", "poker": "Poker", "des": "Le Grand Hasard",
	"roue": "La roue de la fortune", "boule": "La Boule", "loto": "Le loto", "courses": "Les paris",
	"echecs": "Les échecs",
}


## Le bouton « Règles » d'un panneau : une pastille de la barre basse, ou un bouton ordinaire pour le
## panneau au milieu de l'écran. « jeu » choisit les règles (NOMS) ; le panneau donne ses tarifs.
static func bouton(panneau: Control, jeu: String, en_barre := true) -> Button:
	var b: Button = BARRE.pill("Règles") if en_barre else Button.new()
	b.text = "Règles"
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Les règles de ce jeu"
	b.pressed.connect(func(): ouvrir(panneau, jeu))
	return b


## Ouvre la fenêtre des règles par-dessus tout ; elle se ferme seule si le panneau quitte la scène.
static func ouvrir(panneau: Control, jeu: String) -> void:
	if panneau.has_meta("regles") and is_instance_valid(panneau.get_meta("regles")):
		return
	var f := Fenetre.new()
	f.layer = 98
	panneau.get_tree().root.add_child(f)
	var nom := str(NOMS.get(jeu, "Règles"))
	if jeu == "roue" and "mode" in panneau and panneau.mode == "boule":
		nom = NOMS.boule
	elif jeu == "baccara" and "commission" in panneau and not panneau.commission:
		nom = "Le Banco"
	f.construire(nom, texte(jeu, panneau), panneau.get_viewport().get_visible_rect().size)
	panneau.set_meta("regles", f)
	panneau.tree_exiting.connect(f.fermer)


## Les règles d'un jeu, en BBCode : des titres, des paragraphes et des tableaux de gains.
## Les tarifs qui varient d'une table à l'autre (blindes du poker, commission du baccara, roue ou
## Boule) sont lus sur le panneau.
static func texte(jeu: String, p: Object = null) -> String:
	var mode := str(p.get("mode")) if p != null and "mode" in p else ""
	if jeu == "roue" and mode == "boule":
		jeu = "boule"
	match jeu:
		"machine":
			return _bloc([
				["Trois rouleaux, une ligne", "Choisissez la mise avec les jetons (touches 1 à 5), puis tirez le bras (Espace). Trois symboles identiques sur la ligne paient un multiple de la mise."],
				[[["7  7  7", "400 fois la mise"], ["★  ★  ★", "150 fois"], ["♣  ♣  ♣", "60 fois"], ["♥  ♥  ♥", "25 fois"],
					["♦  ♦  ♦", "15 fois"], ["♠  ♠  ♠", "10 fois"], ["Deux 7", "2 fois"]]],
				["Les rouleaux", "Le 7 est le plus rare sur chaque rouleau, le pique le plus courant."],
			])
		"blackjack":
			return _bloc([
				["Le but", "S'approcher de 21 sans le dépasser et battre la main du croupier. Les figures valent 10, l'as vaut 1 ou 11."],
				["Déroulement", "Choisissez la mise (touches 1 à 5), puis distribuez (Espace). Vous recevez deux cartes, le croupier une visible et une cachée. Tirez une carte (C), restez (R), ou doublez (D) sur vos deux premières cartes : la mise double et vous recevez une seule carte de plus."],
				[[["Blackjack (as et 10 ou figure d'entrée)", "3 contre 2"], ["Main gagnante", "1 contre 1"],
					["Égalité", "mise rendue"], ["Plus de 21", "perdu"]]],
				["La table", "Sabot de 6 jeux. Le croupier tire jusqu'à 16 et reste sur tout 17. Ni partage ni assurance."],
			])
		"roulette":
			return _bloc([
				["Un seul zéro", "37 numéros, de 0 à 36. Choisissez le jeton (touches 1 à 5), posez-le sur le tapis, puis lancez la bille (Espace). Toutes les mises se règlent sur le numéro sorti."],
				[[["Plein (un numéro, le 0 compris)", "35 contre 1"], ["Douzaine, colonne", "2 contre 1"],
					["Rouge, noir, pair, impair, 1 à 18, 19 à 36", "1 contre 1"]]],
				["Le zéro", "Il fait perdre les chances simples, les douzaines et les colonnes : seul le plein sur le 0 gagne. Retirer reprend les mises avant le lancer."],
			])
		"craps":
			return _bloc([
				["Le premier lancer", "La Pass Line et le Don't Pass se misent avant qu'un point soit établi. 7 ou 11 : la Pass Line gagne. 2, 3 ou 12 : elle perd ; le Don't Pass gagne sur 2 ou 3, et le 12 lui est rendu. Tout autre total devient le point."],
				["Le point", "On relance jusqu'à refaire le point (la Pass Line gagne, le Don't Pass perd) ou sortir un 7, le seven out (l'inverse)."],
				[[["Pass Line, Don't Pass", "1 contre 1"], ["Field, un lancer : 3, 4, 9, 10, 11", "1 contre 1"],
					["Field : 2", "2 contre 1"], ["Field : 12", "3 contre 1"],
					["Place 6, Place 8 (la mise reste posée)", "7 contre 6"], ["Any Seven, un lancer", "4 contre 1"],
					["Any Craps (2, 3 ou 12), un lancer", "7 contre 1"]]],
				["Les Place", "Elles ne travaillent que pendant un point et perdent au seven out. Jetons avec les touches 1 à 4, dés lancés avec Espace."],
			])
		"baccara":
			var commission: bool = p == null or not ("commission" in p) or bool(p.get("commission"))
			return _bloc([
				["Le but", "On parie sur la main du Joueur ou sur celle du Banquier, pas sur soi. La main la plus proche de 9 gagne : l'as vaut 1, le 10 et les figures 0, et seules les unités comptent (7 + 8 = 15 vaut 5). Un 8 ou un 9 en deux cartes est un naturel : personne ne tire."],
				["Déroulement", "Posez vos plaques (touches 1 à 4), puis distribuez (Espace). Deux cartes à chaque main ; les troisièmes cartes suivent un tableau fixe : vous n'avez rien à décider."],
				[[["Banquier", "1 contre 1 moins 5 %" if commission else "1 contre 1, sans commission"], ["Joueur", "1 contre 1"],
					["Égalité (Joueur et Banquier rendus)", "8 contre 1"]]],
				["Le tableau de tirage", "Le Joueur tire avec 0 à 5 et reste avec 6 ou 7. Le Banquier tire avec 0 à 2 ; avec 3, sauf sur un 8 du Joueur ; avec 4, sur 2 à 7 ; avec 5, sur 4 à 7 ; avec 6, sur 6 ou 7 ; il reste avec 7. Si le Joueur est resté, le Banquier tire avec 0 à 5. Sabot de 8 jeux."],
			])
		"poker":
			var sb: int = int(p.get("SB")) if p != null and "SB" in p else 25
			var bb: int = int(p.get("BB")) if p != null and "BB" in p else 50
			var cap: int = int(p.get("CAP")) if p != null and "CAP" in p else 2000
			var multi: bool = p != null and "srv" in p
			return _bloc([
				["Le but", "Texas Hold'em. Chacun reçoit deux cartes cachées ; cinq cartes communes s'ouvrent au milieu : trois au flop, une au turn, une à la rivière. La meilleure main de cinq cartes, prises parmi ses deux et les cinq du tableau, remporte le pot. Ou bien tous les autres se sont couchés."],
				["Les enchères", "Sans limite, petite et grosse blinde de %s et %s. À votre tour : parler ou suivre, se coucher, ou relancer du montant choisi avec − et +. Personne ne met plus de %s crédits dans une donne." % [Game.fmt(sb), Game.fmt(bb), Game.fmt(cap)]],
				[[["Quinte flush", "cinq cartes de suite, même couleur"], ["Carré", "quatre cartes de même valeur"],
					["Full", "un brelan et une paire"], ["Couleur", "cinq cartes de même couleur"],
					["Quinte", "cinq cartes de suite (l'as en haut ou en bas)"], ["Brelan", "trois cartes de même valeur"],
					["Deux paires, paire", "puis la carte la plus haute"], ["Hauteur", "la carte la plus haute"]]],
				["La table", "Six places, tenues par les habitués quand personne ne les prend. La maison prend 5 % du pot quand le flop a été servi, 100 au plus. "
					+ ("Les joueurs connectés s'assoient à la même table et prennent la chaise d'un habitué. Sans réponse au bout de 25 secondes, c'est parole si l'on peut, sinon on se couche. Se lever en pleine donne, c'est se coucher." if multi
					else "On ne se lève qu'une fois la donne finie (ou en se couchant).")],
			])
		"des":
			return _bloc([
				["Trois dés", "Posez vos jetons (touches 1 à 4) sur les numéros ou les cases, puis lancez les dés (Espace)."],
				[[["Un numéro, sur un dé", "1 contre 1"], ["Un numéro, sur deux dés", "2 contre 1"], ["Un numéro, sur trois dés", "3 contre 1"],
					["Petit (total de 4 à 10)", "1 contre 1"], ["Grand (total de 11 à 17)", "1 contre 1"], ["N'importe quel triple", "30 contre 1"]]],
				["Le triple", "Trois dés pareils font perdre le Petit et le Grand."],
			])
		"roue":
			return _bloc([
				["54 cases", "Posez vos jetons (touches 1 à 4) sur une ou plusieurs valeurs, puis lancez la roue (Espace). La case où elle s'arrête paie les mises posées sur sa valeur ; les autres sont perdues."],
				[[["1 (24 cases)", "1 contre 1"], ["2 (15 cases)", "2 contre 1"], ["5 (7 cases)", "5 contre 1"],
					["10 (4 cases)", "10 contre 1"], ["20 (2 cases)", "20 contre 1"], ["Joker, Étoile (une case chacun)", "40 contre 1"]]],
			])
		"boule":
			return _bloc([
				["Neuf numéros", "La boule s'arrête sur un numéro de 1 à 9. Posez vos jetons (touches 1 à 4), puis lancez la boule (Espace)."],
				[[["Un numéro", "7 contre 1"], ["Rouge (1, 3, 6, 8), noir (2, 4, 7, 9)", "1 contre 1"],
					["Pair, impair", "1 contre 1"], ["Manque (1 à 4), passe (6 à 9)", "1 contre 1"]]],
				["Le 5", "Jaune, il est à la maison : il fait perdre toutes les chances simples. Seul le plein sur le 5 gagne."],
			])
		"loto":
			return _bloc([
				["Le tirage", "Cochez jusqu'à 5 numéros sur 30, choisissez la mise, puis lancez le tirage (Espace) : 10 numéros sortent. Le gain dépend des numéros trouvés."],
				[[["2 numéros", "mise rendue"], ["3 numéros", "4 fois la mise"], ["4 numéros", "20 fois"], ["5 numéros", "120 fois"]]],
			])
		"echecs":
			return _bloc([
				["Le but", "Mettre le roi adverse en échec et mat : il est attaqué et ne peut plus s'échapper. Les blancs jouent le premier coup, puis chacun joue à son tour."],
				["Jouer un coup", "Cliquez une pièce, puis sa case d'arrivée, ou faites-la glisser. Les points gris montrent les cases permises, le cercle gris une prise. Le dernier coup est surligné en jaune, le roi en échec en rouge."],
				["Les règles complètes", "Le roque, la prise en passant et la promotion (on choisit la pièce sur la case d'arrivée) sont permis. La partie est nulle sur un pat, une triple répétition, cinquante coups sans prise ni pion poussé, ou s'il ne reste pas de quoi mater."],
				["La pendule", "Chacun a son temps, cinq minutes par défaut ; le sien court quand on a le trait. Qui n'a plus de temps perd, sauf si l'adversaire n'a plus de quoi mater : la partie est alors nulle."],
				["Contre un robot ou un joueur", "Au fond du Cercle, un robot attend à chaque table, de Novice à Expert : on s'assied en face pour jouer seul contre lui. Les tables de devant sont vides : on y joue contre un autre joueur, qui vient s'asseoir en face. Les deux fixent la cadence, les couleurs et la mise, et la partie commence quand chacun a accepté. On peut proposer la nulle, abandonner, puis demander la revanche, couleurs inversées."],
				["Les mises", "On joue pour l'honneur ou pour une mise de 50 à 1 000 crédits, posée au début. Une nulle rend la mise. Se lever pendant la partie, c'est abandonner."],
				[[["Victoire contre Pierrot (Novice)", "1,2 fois la mise"], ["Contre Basile (Débutant)", "1,5 fois"], ["Contre Madame Ferrand (Amateur)", "2 fois"],
					["Contre le docteur Ostrowski (Confirmé)", "3 fois"], ["Contre Madame Lacroix (Expert)", "5 fois"], ["Contre un joueur", "les deux mises"]]],
			])
		"courses":
			return _bloc([
				["Les cotes", "Chaque concurrent a sa cote, écrite à côté de son nom. Choisissez la mise et votre concurrent : s'il gagne, vous encaissez votre mise et la mise multipliée par la cote (une cote de 3 paie 3 contre 1)."],
				["La marge", "Les chances réelles sont un peu plus faibles que ce que la cote promet : c'est la part de l'organisateur, comme au PMU."],
			])
	return ""


## Assemble les morceaux : [titre, paragraphe] ou [[[libellé, gain], ...]] pour un tableau de gains.
static func _bloc(parts: Array) -> String:
	var out := PackedStringArray()
	for part in parts:
		if part.size() == 1:
			var t := "[table=2]"
			for row in part[0]:
				t += "[cell padding=0,3,28,3][color=#%s]%s[/color][/cell][cell padding=0,3,0,3][b][color=#%s]%s[/color][/b][/cell]" % [
					BARRE.CREAM.to_html(false), row[0], BARRE.GOLD.to_html(false), row[1]]
			out.append(t + "[/table]")
		else:
			out.append("[font_size=24][b][color=#%s]%s[/color][/b][/font_size]\n%s" % [BARRE.GOLD.to_html(false), part[0], part[1]])
	return "\n\n".join(out)



## La fenêtre : un voile sur la table, la carte des règles au milieu, qui défile au doigt aussi.
class Fenetre extends CanvasLayer:
	var _ferme := false

	func construire(titre: String, bbcode: String, ecran: Vector2) -> void:
		var voile := ColorRect.new()
		voile.color = Color(0, 0, 0, 0.55)
		voile.set_anchors_preset(Control.PRESET_FULL_RECT)
		voile.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				fermer())
		add_child(voile)
		var centre := CenterContainer.new()
		centre.set_anchors_preset(Control.PRESET_FULL_RECT)
		centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(centre)
		var carte := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.03, 0.035, 0.97)
		sb.border_color = Color(BARRE.GOLD, 0.55)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(16)
		sb.set_content_margin_all(22)
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 24
		sb.anti_aliasing = true
		carte.add_theme_stylebox_override("panel", sb)
		carte.custom_minimum_size = Vector2(minf(780.0, ecran.x - 32.0), minf(640.0, ecran.y - 48.0))
		centre.add_child(carte)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 12)
		carte.add_child(v)
		var tete := HBoxContainer.new()
		tete.add_theme_constant_override("separation", 12)
		v.add_child(tete)
		var t := Label.new()
		t.text = titre
		t.add_theme_font_override("font", BARRE.KIT.serif())
		t.add_theme_font_size_override("font_size", 28)
		t.add_theme_color_override("font_color", BARRE.GOLD)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tete.add_child(t)
		var fermer_b := BARRE.pill("Fermer  (Échap)")
		fermer_b.pressed.connect(fermer)
		tete.add_child(fermer_b)
		var filet := ColorRect.new()
		filet.color = Color(BARRE.GOLD, 0.25)
		filet.custom_minimum_size = Vector2(0, 1)
		v.add_child(filet)
		var defile := ScrollContainer.new()
		defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(defile)
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		r.add_theme_font_override("normal_font", Polices.texte())
		r.add_theme_font_override("bold_font", Polices.gras())
		for k in ["normal_font_size", "bold_font_size"]:
			r.add_theme_font_size_override(k, 20)
		r.add_theme_color_override("default_color", BARRE.CREAM)
		r.add_theme_constant_override("line_separation", 4)
		r.text = bbcode
		defile.add_child(r)

	## Échap referme la fenêtre, pas la table ; les autres touches ne jouent pas derrière elle.
	func _input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			fermer()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey:
			get_viewport().set_input_as_handled()

	func fermer() -> void:
		if _ferme:
			return
		_ferme = true
		queue_free()
