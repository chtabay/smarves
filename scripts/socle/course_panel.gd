class_name CoursePanel
extends FootTableau
## Le programme d'une course cycliste (socle 1.28, autoload Cyclisme) : la fenêtre de la famille de l'ardoise
## que la commune ouvre où elle veut (à l'arche du départ, au comptoir de son sports bar). Le prochain départ et
## le parcours ; avant le départ, les engagés, leur profil et leurs deux cotes (gagnant, placé), la mise et le
## ticket ; pendant la course, l'état du direct ; la fiche de la dernière édition (le classement, les écarts,
## les abandons) ; les tickets et le bilan depuis le début. Elle s'ouvre et se ferme comme l'ardoise (closed,
## Échap). Une commune l'obtient par Cyclisme : CoursePanel.de(commune, id).

## La course : l'entrée du registre (Cyclisme.course).
var course: Dictionary = {}
## Le pari préparé : le dossard, « gagnant » ou « place », la mise.
var choix := {}
var mise := 20
## Qui prend les paris : le directeur de course (l'hôte du lieu de même id), ou le tenancier d'un comptoir.
var teneur := ""
var _ligne_etat: Label
var _depart := 0


## Le programme d'une course de commune, prêt à ajouter à une interface ; null si la course n'existe pas.
static func de(commune: String, id: String) -> CoursePanel:
	var e: Dictionary = cyclisme().course(commune, id)
	if e.is_empty():
		return null
	var p := CoursePanel.new()
	p.course = e
	return p


static func cyclisme() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Cyclisme")


func _ready() -> void:
	if teneur == "":
		teneur = _hote()
	_preparer()
	remplir(_colonne)


## L'hôte du lieu de même id que la course, sinon « Le directeur de course ».
func _hote() -> String:
	var c = communes().commune(str(course.get("commune", "")))
	for l in (c.lieux() if c != null else []):
		if str(l.get("id", "")) == str(course.get("id", "")):
			return str(l.get("hote", "Le directeur de course"))
	return "Le directeur de course"


func remplir(colonne: VBoxContainer) -> void:
	_vider(colonne)
	var cy := cyclisme()
	var t: int = cy.maintenant()
	_depart = cy.edition(course, t)
	var tours := int(cy.champ(course, "tours"))
	var longueur := float(cy.champ(course, "distance"))
	colonne.add_child(_mot("L A   C O U R S E   C Y C L I S T E", 13, DOUX))
	colonne.add_child(_mot(str(course.get("nom", "La course")), 26 if _etroit() else 32, CRAIE, Polices.titre(), _etroit()))
	colonne.add_child(_mot("%s à %s  ·  %s de %s km, %s km en tout  ·  parcours %s" % [
		date(_depart), _heure(_depart), "%d tours" % tours if tours > 1 else "un tour", _km(longueur), _km(longueur * tours),
		cy.RELIEFS_DITS.get(str(cy.champ(course, "relief")), "")], 16, CRAIE, null, true))
	var direct: Dictionary = cy.en_direct(course, t)
	if direct.etat == "avant":
		_engages(colonne)
	else:
		_direct(colonne, direct)
	colonne.add_child(_filet())
	_fiche(colonne, t)
	colonne.add_child(_filet())
	_tickets(colonne)
	var bas := _pied(colonne)
	if direct.etat == "avant":
		var b := _bouton("Jouer le ticket", func(): jouer())
		b.name = "Jouer"
		bas.add_child(b)
	bas.add_child(_bouton("Ranger le programme  (Échap)", func(): closed.emit()))


func _heure(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%d h" % d.hour if d.minute == 0 else "%d h %02d" % [d.hour, d.minute]


static func _km(m: float) -> String:
	return String.num(m / 1000.0, 1).replace(".", ",").trim_suffix(",0")


## Les engagés et leurs cotes, puis la mise.
func _engages(colonne: VBoxContainer) -> void:
	var cy := cyclisme()
	colonne.add_child(_mot("Gagnant : le premier sur la ligne. Placé : dans les trois premiers. Les paris ferment au départ.", 14, DOUX, null, true))
	var cotes: Dictionary = cy.cotes(course, _depart)
	for r in cy.engages(course, _depart):
		colonne.add_child(_rangee_coureur(r, cotes[int(r.num)]))
	colonne.add_child(_filet())
	colonne.add_child(_mot("La mise", 15, DOUX))
	var rang := HFlowContainer.new()
	rang.add_theme_constant_override("h_separation", 8)
	rang.add_theme_constant_override("v_separation", 6)
	colonne.add_child(rang)
	for v in cy.MISES:
		var b := _bouton("%d crédits" % v, func():
			mise = int(v)
			remplir(_colonne), 15)
		b.name = "Mise_%d" % v
		if mise == int(v):
			_allumer(b)
		rang.add_child(b)
	var champ := LineEdit.new()
	champ.name = "MiseLibre"
	champ.text = str(mise)
	champ.placeholder_text = "autre montant"
	champ.custom_minimum_size = Vector2(130, 0)
	champ.max_length = 9
	champ.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	champ.add_theme_font_size_override("font_size", 15)
	champ.add_theme_color_override("font_color", CRAIE)
	champ.add_theme_stylebox_override("normal", _boite(Color(0, 0, 0, 0.25), DOUX, 4, 8))
	champ.add_theme_stylebox_override("focus", _boite(Color(0, 0, 0, 0.25), OR, 4, 8))
	champ.text_changed.connect(func(tx: String): poser_mise(tx))
	champ.text_submitted.connect(func(_tx: String): jouer())
	rang.add_child(champ)
	_ligne_etat = _mot(_etat_texte(), 15, OR, null, true)
	colonne.add_child(_ligne_etat)


## Un coureur : son dossard dans sa couleur, son nom, son profil, et ses deux cotes à cocher.
func _rangee_coureur(r: Dictionary, c: Dictionary) -> Control:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 4)
	var dossard := _mot(" %d " % int(r.num), 15, Color(0.08, 0.08, 0.1), Polices.gras())
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(str(r.maillot))
	fond.set_corner_radius_all(3)
	dossard.add_theme_stylebox_override("normal", fond)
	dossard.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1) if Color(str(r.maillot)).get_luminance() > 0.45 else CRAIE)
	dossard.custom_minimum_size.x = 34
	dossard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(dossard)
	var nom := _mot("%s. %s" % [str(r.prenom).substr(0, 1), r.nom] if _etroit() else "%s %s" % [r.prenom, r.nom], 16, CRAIE, Polices.gras())
	nom.custom_minimum_size.x = 120 if _etroit() else 230
	h.add_child(nom)
	var p := _mot(cyclisme().profil(r), 13, DOUX)
	p.custom_minimum_size.x = 70 if _etroit() else 90
	h.add_child(p)
	for genre in ["gagnant", "place"]:
		var b := _bouton("%s  %.2f" % ["Gagnant" if genre == "gagnant" else "Placé", float(c[genre])], func():
			if int(choix.get("num", 0)) == int(r.num) and choix.get("genre", "") == genre:
				choix = {}
			else:
				choix = {"num": int(r.num), "genre": genre}
			remplir(_colonne), 14)
		b.name = "Choix_%d_%s" % [int(r.num), genre]
		if int(choix.get("num", 0)) == int(r.num) and choix.get("genre", "") == genre:
			_allumer(b)
		h.add_child(b)
	return h


func _allumer(b: Button) -> void:
	for etat in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(etat, _boite(Color(OR, 0.45), CRAIE, 4, 8))
	for ct in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(ct, CRAIE)


## Une mise tapée au clavier : les chiffres seulement, au moins un crédit.
func poser_mise(texte: String) -> void:
	var chiffres := ""
	for ch in texte:
		if ch >= "0" and ch <= "9":
			chiffres += ch
	mise = maxi(cyclisme().MISE_MIN, int(chiffres)) if chiffres != "" else cyclisme().MISE_MIN
	if _ligne_etat != null:
		_ligne_etat.text = _etat_texte()


func _etat_texte() -> String:
	if choix.is_empty():
		return "Rien de coché. Vous avez %s crédits." % Game.fmt(Game.credits)
	var c: float = cyclisme().cotes(course, _depart)[int(choix.num)][choix.genre]
	return "%s sur le n° %d %s, cote %.2f : %s crédits s'il passe." % [Game.fmt(mise), int(choix.num),
		"gagnant" if choix.genre == "gagnant" else "placé", c, Game.fmt(int(round(mise * c)))]


## Pose le ticket coché ; vrai s'il est pris.
func jouer() -> bool:
	if choix.is_empty():
		if _ligne_etat != null:
			_ligne_etat.text = "Cochez un coureur, gagnant ou placé."
		return false
	var r: Dictionary = cyclisme().parier(course, _depart, int(choix.num), str(choix.genre), mise)
	if r.ok:
		choix = {}
		remplir(_colonne)
		if _ligne_etat != null:
			_ligne_etat.text = "%s note le ticket : « Rendez-vous à l'arrivée. »" % teneur
		return true
	if _ligne_etat != null:
		_ligne_etat.text = {"credits": "Il vous manque des crédits pour cette mise.", "ferme": "Trop tard : le départ est donné.",
			"mise": "Une mise, c'est au moins un crédit."}.get(str(r.raison), "%s fait non de la tête." % teneur)
	return false


## Pendant la course : le tour, la tête, l'écart, et les cinq premiers du moment.
func _direct(colonne: VBoxContainer, d: Dictionary) -> void:
	var cy := cyclisme()
	var par_num := {}
	for r in cy.engages(course, _depart):
		par_num[int(r.num)] = r
	if d.etat == "course":
		var tete: Dictionary = par_num.get(int(d.tete), {})
		colonne.add_child(_mot("En course : tour %d sur %d. En tête, le n° %d, %s %s%s." % [int(d.tour), int(d.tours), int(d.tete),
			tete.get("prenom", ""), tete.get("nom", ""), ", %d s devant le peloton" % int(d.ecart) if int(d.ecart) >= 3 else ", dans le peloton"],
			17, OR, null, true))
		colonne.add_child(_mot("Les paris sont fermés : la course est partie.", 14, DOUX, null, true))
		var k := 0
		for num in d.classement:
			k += 1
			if k > 5:
				break
			var r: Dictionary = par_num.get(int(num), {})
			colonne.add_child(_mot("%d.  n° %d  %s %s" % [k, int(num), r.get("prenom", ""), r.get("nom", "")], 15, CRAIE))
	else:
		colonne.add_child(_mot("La course est arrivée : les tickets se règlent dix minutes après le dernier coureur.", 16, OR, null, true))


## La fiche de la dernière édition courue : le podium et les dix premiers, leurs écarts, les abandons.
func _fiche(colonne: VBoxContainer, t: int) -> void:
	var cy := cyclisme()
	var derniere: int = cy.dernier_depart(course, t)
	if t < cy.fin(course, derniere):
		derniere = cy.dernier_depart(course, derniere - 1)
	var res: Dictionary = cy.resultat(course, derniere)
	var par_num := {}
	for r in cy.engages(course, derniere):
		par_num[int(r.num)] = r
	colonne.add_child(_mot("L'édition du %s" % date(derniere), 17, CRAIE, Polices.gras()))
	var tete: float = res.temps.get(res.ordre[0], 0.0) if not res.ordre.is_empty() else 0.0
	var k := 0
	for num in res.ordre:
		k += 1
		if k > 10:
			break
		var r: Dictionary = par_num.get(int(num), {})
		var ecart := "%d h %02d min %02d s" % [int(tete) / 3600, (int(tete) / 60) % 60, int(tete) % 60] if k == 1 else \
			("m.t." if bool(res.groupe.get(num, false)) else "à %s" % _duree(float(res.temps[num]) - tete))
		if k == 1 and int(tete) < 3600:
			ecart = "%d min %02d s" % [int(tete) / 60, int(tete) % 60]
		colonne.add_child(_mot("%d.  n° %d  %s %s  ·  %s" % [k, int(num), r.get("prenom", ""), r.get("nom", ""), ecart], 15,
			OR if k <= 3 else CRAIE))
	var notes := []
	for num in res.abandons:
		notes.append("abandon du n° %d au tour %d" % [int(num), int(res.abandons[num])])
	for num in res.crevaisons:
		notes.append("crevaison du n° %d au tour %d" % [int(num), int(res.crevaisons[num])])
	if not notes.is_empty():
		var tx := "; ".join(notes) + "."
		colonne.add_child(_mot(tx.substr(0, 1).to_upper() + tx.substr(1), 14, DOUX, null, true))


static func _duree(s: float) -> String:
	var n := int(round(s))
	return "%d s" % n if n < 60 else "%d min %02d s" % [n / 60, n % 60]


## Les tickets de cette course, les derniers d'abord, et le bilan de toutes les courses.
func _tickets(colonne: VBoxContainer) -> void:
	var cy := cyclisme()
	var liste: Array = cy.tickets.filter(func(tk): return tk.commune == course.commune and tk.course == course.id)
	liste.reverse()
	var montres := 0
	for tk in liste:
		if montres >= 5:
			break
		montres += 1
		var sort: String = {"ouvert": "ouvert, réglé à l'arrivée", "gagne": "gagné : %s crédits" % Game.fmt(int(tk.gain)), "perdu": "perdu"}.get(str(tk.etat), "")
		colonne.add_child(_mot("%s  ·  n° %d %s  ·  %s à %.2f  ·  %s" % [date(int(tk.depart)), int(tk.num), "gagnant" if tk.genre == "gagnant" else "placé",
			Game.fmt(int(tk.mise)), float(tk.cote), sort], 14, OR if tk.etat == "gagne" else (CRAIE if tk.etat == "ouvert" else DOUX), null, true))
	var b: Dictionary = cy.bilan()
	if b.tickets == 0:
		colonne.add_child(_mot("Pas encore de ticket. %s : « Un coureur, ça se regarde monter avant de se jouer. »" % teneur, 14, DOUX, null, true))
	else:
		colonne.add_child(_mot("Depuis le début, sur les courses : %d ticket%s, %s misés, %s repris." % [b.tickets, "s" if b.tickets > 1 else "",
			Game.fmt(int(b.mise)), Game.fmt(int(b.gagne))], 14, DOUX, null, true))
