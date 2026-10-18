class_name BoursePanel
extends FootTableau
## La cote de Mme Vasseur : la fenêtre de la charge d'agent de change (docs/BOURSE.md). Les quatre valeurs
## et leur dernier cours, la séance et la semaine, la prochaine clôture ; les positions du joueur, leur
## valeur au dernier cours, l'appel de marge et le cours qui liquiderait ; et le guichet des ordres.
## Tout vient de l'autoload Bourse, et c'est la base qui tient les positions.
##
## Elle emprunte au tableau du dimanche son ardoise et ses petites pièces ; s'ouvre et se ferme comme
## lui (signal closed, Échap). La morale sort des chiffres : le bilan depuis le début, sous les positions.

## Mme Vasseur parle (une phrase pour la bulle de la scène).
signal spoke(text: String)

const HAUSSE := Color(0.55, 0.86, 0.52)
const BAISSE := Color(0.96, 0.46, 0.4)
const ROUGE := Color(0.96, 0.42, 0.36)
const MARGES := [100, 500, 1000, 5000, 20000]

## L'ordre en préparation : la valeur, le sens, le levier, la marge.
var ordre := {}
var _ligne_ordre: Label
var _saisie: SpinBox
var _occupe := false


static func bourse() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Bourse")


static func game() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Game")


static func compte() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Compte")


func _ready() -> void:
	_preparer()
	remplir(_colonne)
	bourse().change.connect(_relire)
	bourse().lire()


## La cote change sous les yeux (une lecture arrive) : on ne redessine que la cote, pas un ordre en cours.
func _relire() -> void:
	if is_inside_tree() and ordre.is_empty() and not _occupe:
		remplir(_colonne)


## Sur un téléphone, la fenêtre (centrée) laisse la barre du haut (le compteur, « Sortir ») et la
## réplique de Mme Vasseur en bas : 150 unités de chaque côté.
func _ajuster() -> void:
	if _fenetre == null or _colonne == null:
		return
	var maxi := _ecran() - Vector2(36, 300)
	var taille := _colonne.get_combined_minimum_size()
	_fenetre.custom_minimum_size = Vector2(minf(taille.x + 14.0, maxi.x), minf(taille.y, maxi.y))


func remplir(colonne: VBoxContainer) -> void:
	_vider(colonne)
	ordre = {}
	var b := bourse()
	var etroit := _etroit()
	colonne.add_child(_mot("V A S S E U R   &   C I E   ·   A G E N T   D E   C H A N G E", 12 if etroit else 13, DOUX))
	colonne.add_child(_mot("La cote", 26 if etroit else 32, CRAIE, Polices.titre()))
	if b.indices().is_empty():
		var t := "La cote arrive par le téléscripteur…" if b.etat == "lecture" or b.etat == "" else \
			"Le téléscripteur se tait : la cote ne passe pas sans réseau. Les positions restent tenues au compte."
		colonne.add_child(_mot(t, 16, DOUX, null, true))
	else:
		colonne.add_child(_mot("Cours de clôture des places réelles, les mêmes pour tous. Un ordre est exécuté à la clôture suivante de sa place.", 14, DOUX, null, true))
		for id in b.ORDRE:
			var i: Dictionary = b.indice(id)
			if not i.is_empty():
				colonne.add_child(_rangee_valeur(i))
	colonne.add_child(_filet())
	_positions(colonne)
	colonne.add_child(_filet())
	var bilan: Dictionary = b.bilan()
	if int(bilan.get("engage", 0)) > 0:
		colonne.add_child(_mot("Depuis le début : %s crédits engagés (marges, renforts, courtage), %s revenus." % [
			game().fmt(int(bilan.engage)), game().fmt(int(bilan.get("rendu", 0)))], 15, CRAIE, null, true))
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_END
	colonne.add_child(bas)
	bas.add_child(_bouton("Quitter le guichet  (Échap)", func(): closed.emit()))


## Une valeur de la cote : son nom et sa place, le dernier cours, la séance, la semaine, la courbe, et le
## guichet. Sur un téléphone, deux lignes.
func _rangee_valeur(i: Dictionary) -> Control:
	var b := bourse()
	var etroit := _etroit()
	var der: Array = b.dernier(i)
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10 if etroit else 18)
	bloc.add_child(h)
	var nom := _mot(str(i.nom), 18 if etroit else 20, CRAIE, Polices.gras())
	nom.custom_minimum_size.x = 120 if etroit else 150
	h.add_child(nom)
	var cours := _mot(nombre(float(der[1])) if not der.is_empty() else "–", 18 if etroit else 20, OR, Polices.gras())
	cours.custom_minimum_size.x = 100 if etroit else 120
	cours.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(cours)
	for n in [1, 5]:
		var v: float = b.variation(i, n)
		var l := _mot(pourcent(v) + ("" if n == 1 else " sem."), 15, HAUSSE if v >= 0.0 else BAISSE)
		l.custom_minimum_size.x = 76 if n == 1 else 110
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	if not etroit:
		h.add_child(_courbe(i, Vector2(150, 34)))
	var guichet := Control.new()
	guichet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(guichet)
	if compte_ouvert():
		var bt := _bouton("Passer un ordre", func(): ouvrir_ordre(str(i.id)), 14)
		bt.name = "Ordre_%s" % i.id
		h.add_child(bt)
	var info := "%s  ·  %s  ·  prochaine clôture %s" % [str(i.place), "dernier cours du %s" % jour(str(der[0])) if not der.is_empty() else "pas encore de cours",
		quand(_t(i.get("prochaine")))]
	bloc.add_child(_mot(info, 13, DOUX, null, etroit))
	return bloc


## Le joueur a un compte : la base sait à qui sont les positions.
func compte_ouvert() -> bool:
	return bourse()._essai or compte().connecte()


func _positions(colonne: VBoxContainer) -> void:
	var b := bourse()
	colonne.add_child(_mot("Vos positions", 22, CRAIE, Polices.gras()))
	if not compte_ouvert():
		colonne.add_child(_mot("Mme Vasseur ne tient de positions qu'au nom d'un compte Pyramides : connectez-vous depuis le menu (Échap), et vos positions se liront sur tous vos appareils.", 15, OR, null, true))
		return
	var ouvertes: Array = b.ouvertes()
	if ouvertes.is_empty():
		colonne.add_child(_mot("Aucune position ouverte. Choisissez une valeur à la cote pour passer un ordre.", 15, DOUX, null, true))
	for p in ouvertes:
		colonne.add_child(_rangee_position(p))
	var closes: Array = b.positions().filter(func(p): return p.get("issue") != null)
	if not closes.is_empty():
		colonne.add_child(_mot("Les dernières soldées", 16, CRAIE, Polices.gras()))
		for p in closes.slice(0, 5):
			colonne.add_child(_mot(_ligne_close(p), 14, DOUX, null, true))
	colonne.add_child(_mot("Tenues au compte Pyramides%s : la base exécute les ordres et liquide à la clôture, même quand le jeu est fermé." % (
		" de %s" % compte().nom if compte().nom != "" else ""), 13, DOUX, null, true))


func _rangee_position(p: Dictionary) -> Control:
	var b := bourse()
	var etroit := _etroit()
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", 2)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	bloc.add_child(h)
	var titre := _mot(b.intitule(p), 17, CRAIE, Polices.gras(), etroit)
	if etroit:
		titre.custom_minimum_size.x = _large() * 0.55
	h.add_child(titre)
	var vide := Control.new()
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(vide)
	var garantie := int(p.garantie)
	var exposition := int(p.marge) * int(p.levier)
	if p.get("entree") == null:
		h.add_child(_mot("%s cr. engagés" % game().fmt(garantie), 16, OR, Polices.gras()))
		bloc.add_child(_mot("Ordre transmis : exécuté à la clôture %s, %s." % [b.VALEURS[str(p.indice)].ville, quand(_t(p.get("execution")))], 14, DOUX, null, true))
	else:
		var r: int = b.resultat(p)
		h.add_child(_mot("%s cr." % game().fmt(int(p.valeur)), 16, OR, Polices.gras()))
		var l := _mot("%s%s (%s)" % ["+" if r >= 0 else "−", game().fmt(absi(r)), pourcent(float(r) / maxf(1.0, garantie))], 15, HAUSSE if r >= 0 else BAISSE)
		h.add_child(l)
		var i: Dictionary = b.indice(str(p.indice))
		bloc.add_child(_mot("Garantie %s  ·  exposition %s  ·  entrée %s le %s  ·  liquidée vers %s" % [game().fmt(garantie), game().fmt(exposition),
			nombre(float(p.entree)), jour(str(p.entree_jour)), nombre(cours_liquidation(p, i))], 13, DOUX, null, etroit))
		if p.get("solde_a") != null:
			bloc.add_child(_mot("Solde demandé : exécuté à la clôture %s, %s." % [b.VALEURS[str(p.indice)].ville, quand(_t(p.get("execution")))], 14, OR, null, true))
		elif b.en_appel(p):
			bloc.add_child(_mot("Appel de marge : la position a perdu plus de la moitié de sa garantie. Renflouez avant la clôture, sinon elle sera soldée sous 20 %.", 14, ROUGE, Polices.gras(), true))
	if p.get("solde_a") == null:
		var boutons := HFlowContainer.new()
		boutons.add_theme_constant_override("h_separation", 10)
		boutons.add_theme_constant_override("v_separation", 6)
		bloc.add_child(boutons)
		if p.get("entree") != null:
			var renfort := maxi(10, int(p.marge) / 2)
			var br := _bouton("Renflouer de %s" % game().fmt(renfort), func(): _agir(func(): return await b.renflouer(p, renfort)), 13)
			br.name = "Renflouer_%s" % p.id
			br.disabled = game().credits < renfort
			boutons.add_child(br)
		var bs := _bouton("Solder à la clôture" if p.get("entree") != null else "Annuler l'ordre", func(): _agir(func(): return await b.solder(p)), 13)
		bs.name = "Solder_%s" % p.id
		boutons.add_child(bs)
	return bloc


## Le cours de la valeur auquel la position serait liquidée, frais de portage d'aujourd'hui compris.
func cours_liquidation(p: Dictionary, i: Dictionary) -> float:
	var b := bourse()
	var g := float(p.garantie)
	var e := float(p.marge) * float(p.levier)
	var der: Array = b.dernier(i)
	var nuits := 0
	if not der.is_empty():
		nuits = maxi(0, int((Time.get_unix_time_from_datetime_string(str(der[0])) - Time.get_unix_time_from_datetime_string(str(p.entree_jour))) / 86400))
	var portage: float = e * b.PORTAGE * nuits
	return float(p.entree) * (1.0 + int(p.sens) * (portage - (1.0 - b.LIQUIDATION) * g) / e)


func _ligne_close(p: Dictionary) -> String:
	var b := bourse()
	var g := int(p.garantie)
	var rendu := int(p.get("rendu", 0) if p.get("rendu") != null else 0)
	match str(p.issue):
		"annulee":
			return "%s : ordre annulé, %s rendus." % [b.intitule(p), game().fmt(rendu)]
		"liquidee":
			return "%s : liquidée le %s, %s revenus sur %s." % [b.intitule(p), jour(str(p.sortie_jour)), game().fmt(rendu), game().fmt(g)]
	return "%s : soldée le %s, %s revenus sur %s." % [b.intitule(p), jour(str(p.sortie_jour)), game().fmt(rendu), game().fmt(g)]


## Un geste au guichet, attendu : les boutons ne répondent qu'une fois.
func _agir(geste: Callable) -> void:
	if _occupe:
		return
	_occupe = true
	var r: Dictionary = await geste.call()
	_occupe = false
	if not bool(r.get("ok", false)):
		spoke.emit(raison(str(r.get("raison", ""))))
	if is_inside_tree():
		remplir(_colonne)


static func raison(r: String) -> String:
	match r:
		"credits":
			return "« Vos crédits n'y suffisent pas. M. Brunet, en face, prête à tout le monde, paraît-il. »"
		"plein":
			return "« Huit positions à la fois, c'est le maximum que je tienne pour un client. »"
		"compte":
			return "« Il me faut votre compte Pyramides : je ne tiens rien au porteur. »"
		"close":
			return "« Cette position est déjà soldée, ou en passe de l'être. »"
		"marge":
			return "« La marge va de 100 crédits à un million. »"
	return "« Le téléscripteur ne répond pas. Rien n'est parti : vos crédits vous sont rendus. »"


# ---------------------------------------------------------------- le guichet des ordres

## Prépare un ordre sur une valeur : le sens, le levier, la marge, et ce que cela engage.
func ouvrir_ordre(id: String) -> void:
	var b := bourse()
	ordre = {"indice": id, "sens": 1, "levier": 25, "marge": clampi(1000, b.MARGE_MIN, maxi(b.MARGE_MIN, game().credits))}
	_dessiner_ordre()


func _dessiner_ordre() -> void:
	_vider(_colonne)
	var b := bourse()
	var etroit := _etroit()
	var i: Dictionary = b.indice(str(ordre.indice))
	var v: Dictionary = b.VALEURS[str(ordre.indice)]
	var der: Array = b.dernier(i)
	_colonne.add_child(_mot("L E   G U I C H E T   D E S   O R D R E S", 12 if etroit else 13, DOUX))
	_colonne.add_child(_mot("Un ordre sur le %s" % v.nom if str(ordre.indice) != "or" else "Un ordre sur l'or", 24 if etroit else 30, CRAIE, Polices.titre(), etroit))
	_colonne.add_child(_mot("Dernier cours %s (%s)  ·  exécuté à la clôture %s, %s" % [nombre(float(der[1])) if not der.is_empty() else "–",
		jour(str(der[0])) if not der.is_empty() else "–", v.ville, quand(_t(i.get("prochaine")))], 15, DOUX, null, true))
	_rangee_choix("Le sens", [["À la hausse", 1], ["À la baisse", -1]], "sens")
	var leviers := []
	for l in b.LEVIERS:
		leviers.append(["× %d" % l, l])
	_rangee_choix("Le levier", leviers, "levier")
	var marges := []
	for m in MARGES:
		if m <= maxi(b.MARGE_MIN, game().credits):
			marges.append([game().fmt(m), m])
	_rangee_choix("La marge", marges, "marge")
	var libre := HBoxContainer.new()
	libre.add_theme_constant_override("separation", 10)
	_colonne.add_child(libre)
	libre.add_child(_mot("ou la somme de votre choix :", 14, DOUX))
	_saisie = SpinBox.new()
	_saisie.name = "Marge"
	_saisie.min_value = b.MARGE_MIN
	_saisie.max_value = maxi(b.MARGE_MIN, mini(b.MARGE_MAX, game().credits))
	_saisie.step = 50
	_saisie.value = int(ordre.marge)
	_saisie.custom_minimum_size.x = 150
	_saisie.value_changed.connect(func(x):
		ordre.marge = int(x)
		_ligne_ordre.text = resume_ordre())
	libre.add_child(_saisie)
	_colonne.add_child(_filet())
	_ligne_ordre = _mot(resume_ordre(), 15, OR, null, true)
	_colonne.add_child(_ligne_ordre)
	_colonne.add_child(_mot("Courtage : 1 % de la marge. Portage : 0,02 % de l'exposition par nuit. Sous la moitié de la garantie, l'appel de marge ; à 20 %, la position est soldée à la clôture, jamais en dette.", 13, DOUX, null, true))
	var bas := HFlowContainer.new()
	bas.alignment = FlowContainer.ALIGNMENT_END
	bas.add_theme_constant_override("h_separation", 10)
	bas.add_theme_constant_override("v_separation", 6)
	_colonne.add_child(bas)
	bas.add_child(_bouton("Retour à la cote", func(): remplir(_colonne)))
	var go := _bouton("Passer l'ordre  (%s crédits)" % game().fmt(b.cout(int(ordre.marge))), func(): passer())
	go.name = "Passer"
	go.disabled = game().credits < b.cout(int(ordre.marge))
	bas.add_child(go)


## Ce que l'ordre engage, en une phrase : l'exposition, ce que vaut un pour cent, et où il serait liquidé.
func resume_ordre() -> String:
	var b := bourse()
	var marge := int(ordre.marge)
	var levier := int(ordre.levier)
	var e := marge * levier
	var liq: float = b.seuil_liquidation(levier) * 100.0
	return "Exposition %s crédits : chaque %s de %s vaut %s crédits. Liquidée si la valeur %s de %s %%." % [
		game().fmt(e), "point de pour cent", "hausse" if int(ordre.sens) > 0 else "baisse", game().fmt(e / 100),
		"baisse" if int(ordre.sens) > 0 else "monte", virgule(absf(liq), 1)]


func _rangee_choix(titre: String, options: Array, cle: String) -> void:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 6)
	_colonne.add_child(h)
	var t := _mot(titre, 15, CRAIE, Polices.gras())
	t.custom_minimum_size.x = 100
	h.add_child(t)
	for o in options:
		var actif: bool = ordre.get(cle) == o[1]
		var bt := _bouton(str(o[0]), func():
			ordre[cle] = o[1]
			_dessiner_ordre(), 14)
		bt.name = "%s_%s" % [cle, str(o[1])]
		if actif:
			var s := _boite(Color(OR, 0.55), OR, 4, 8)
			s.content_margin_left = 18
			s.content_margin_right = 18
			for etat in ["normal", "hover", "pressed", "focus"]:
				bt.add_theme_stylebox_override(etat, s)
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				bt.add_theme_color_override(c, Color(0.1, 0.1, 0.08))
		h.add_child(bt)


func passer() -> void:
	if _occupe:
		return
	_occupe = true
	var r: Dictionary = await bourse().ouvrir(str(ordre.indice), int(ordre.sens), int(ordre.levier), int(ordre.marge))
	_occupe = false
	if r.ok:
		spoke.emit("« C'est noté. L'ordre part au téléscripteur : vous aurez le cours de clôture. »")
	else:
		spoke.emit(raison(str(r.get("raison", ""))))
	if is_inside_tree():
		remplir(_colonne)


# ---------------------------------------------------------------- les écritures

## La courbe des trente dernières séances, à la craie.
func _courbe(i: Dictionary, taille: Vector2) -> Control:
	var c := Courbe.new()
	var cours: Array = i.get("cours", [])
	for k in range(maxi(0, cours.size() - 30), cours.size()):
		c.points.append(float(cours[k][1]))
	c.custom_minimum_size = taille
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


class Courbe extends Control:
	var points: Array = []

	func _draw() -> void:
		if points.size() < 2:
			return
		var lo: float = points.min()
		var hi: float = points.max()
		var ecart := maxf(hi - lo, 0.0001)
		var pts := PackedVector2Array()
		for k in points.size():
			pts.append(Vector2(size.x * k / float(points.size() - 1), size.y - 2.0 - (size.y - 4.0) * (float(points[k]) - lo) / ecart))
		var haut: bool = points[points.size() - 1] >= points[0]
		draw_polyline(pts, Color(0.55, 0.86, 0.52, 0.9) if haut else Color(0.96, 0.46, 0.4, 0.9), 2.0, true)
		draw_circle(pts[pts.size() - 1], 3.0, Color(0.96, 0.8, 0.45))


## 7 956,7 : un cours, au dixième, l'espace entre les milliers.
static func nombre(x: float) -> String:
	return virgule(x, 1)


static func virgule(x: float, decimales: int) -> String:
	var signe := "−" if x < 0.0 else ""
	x = absf(x)
	var entier := int(floor(x))
	var reste := int(round((x - entier) * pow(10, decimales)))
	if reste >= int(pow(10, decimales)):
		entier += 1
		reste = 0
	var s := signe + Game.fmt(entier)
	if decimales > 0:
		s += "," + str(reste).pad_zeros(decimales)
	return s


## +1,24 % : une variation, signée.
static func pourcent(v: float) -> String:
	return ("+" if v >= 0.0 else "−") + virgule(absf(v) * 100.0, 2) + " %"


## « 16 oct. » pour un jour « 2026-10-16 ».
static func jour(d: String) -> String:
	var p := d.split("-")
	if p.size() < 3:
		return d
	return "%d %s" % [int(p[2]), ["janv.", "févr.", "mars", "avril", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."][int(p[1]) - 1]]


static func _t(x) -> int:
	return int(x) if x != null else 0


## « lundi 19 octobre à 17 h 35 » pour un instant en secondes Unix, à l'heure de l'appareil.
static func quand(t: int) -> String:
	if t <= 0:
		return "à venir"
	var l := t + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(l)
	return "%s à %d h%s" % [date(l), d.hour, "" if d.minute == 0 else " %02d" % d.minute]
