extends PanelContainer
## Le bureau de M. Brunet, conseiller du Crédit Smarvois. Il accorde tous les prêts, avec enthousiasme :
## au premier degré, le jeu est un investissement. Seuls les chiffres disent autre chose.
## Une autre commune prête le même guichet à sa banque (le champ « banque » de son manifeste) :
## de_commune(id) rend le panneau à son nom, avec son banquier, et la dette va à son prêteur.

signal closed

const PITCH := [
	"Vous avez parfaitement raison de vouloir préparer votre avenir.",
	"Le jeu, c'est le placement préféré des Smarvois. Regardez Josiane : toujours souriante.",
	"Un banquier qui refuse un prêt pour jouer ? Un loser. Pas au Crédit Smarvois.",
	"Plus la mise est importante, plus le gain potentiel est important. C'est mathématique.",
	"Votre profil est excellent. Je vous conseillerais même d'emprunter un peu plus.",
	"Les intérêts ? Une formalité, comparée à ce que vous allez gagner.",
]

## Les arguments d'un banquier d'ailleurs, quand sa banque n'écrit pas les siens (« repliques »).
const PITCH_SOCLE := [
	"Vous avez le profil d'un gagnant. Je le vois tout de suite, c'est mon métier.",
	"Le jeu est un placement comme un autre, en plus distrayant.",
	"Une banque qui ne prête pas, à quoi servirait-elle ? Je vous le demande.",
	"Les intérêts ? Ils se rembourseront tout seuls au prochain gros lot.",
]

## La banque d'une commune (champ « banque » du manifeste) ; vide : le Crédit Smarvois de M. Brunet.
var banque: Dictionary = {}
var _speech: Label
var _status: Label
var _amounts: HBoxContainer


## Le guichet de la banque de la commune « id », ou celui de M. Brunet si elle n'en déclare pas.
static func de_commune(id: String) -> PanelContainer:
	var p: PanelContainer = load("res://scripts/loan_panel.gd").new()
	var c: Commune = Communes.commune(id)
	if c and str(c.banque().get("preteur", "")) not in ["", Game.lender]:
		p.banque = c.banque()
	return p


func _preteur() -> String:
	return str(banque.get("preteur", ""))


func _banquier() -> String:
	return str(banque.get("banquier", "M. Brunet")) if not banque.is_empty() else "M. Brunet"


func _pitch() -> Array:
	if banque.is_empty():
		return PITCH
	var r: Array = banque.get("repliques", [])
	return r if not r.is_empty() else PITCH_SOCLE


func _ready() -> void:
	custom_minimum_size = Vector2(700, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var t := Label.new()
	t.text = str(banque.get("nom", "Crédit Smarvois"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	v.add_child(t)
	var sub := Label.new()
	sub.text = ("%s, conseiller  ·  « Investissez dans votre avenir »" % _banquier()) if banque.is_empty() else "%s, banquier" % _banquier()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	v.add_child(sub)
	_speech = Label.new()
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.custom_minimum_size = Vector2(640, 70)
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech.add_theme_font_size_override("font_size", 21)
	v.add_child(_speech)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 20)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(640, 0)
	_status.add_theme_color_override("font_color", Color(0.82, 0.8, 0.75))
	v.add_child(_status)
	_amounts = HBoxContainer.new()
	_amounts.alignment = BoxContainer.ALIGNMENT_CENTER
	_amounts.add_theme_constant_override("separation", 10)
	v.add_child(_amounts)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var repay := Button.new()
	repay.text = "Rembourser ce que je peux"
	repay.pressed.connect(_repay)
	row.add_child(repay)
	var leave := Button.new()
	leave.text = ("Merci, monsieur Brunet  (Échap)") if banque.is_empty() else "Merci, %s  (Échap)" % _banquier()
	leave.pressed.connect(func(): closed.emit())
	row.add_child(leave)
	_speech.text = "« Bonjour ! Asseyez-vous. Vous venez pour un projet d'investissement ? Excellent choix. »"
	if Biens.value() > 0:
		_speech.text = "« Bonjour ! Vos biens sont une garantie magnifique. Je peux faire beaucoup pour un propriétaire. »"
	_refresh()


## Les montants proposés grandissent avec la dette : plus on doit, plus on est un bon client.
func _offers() -> Array:
	var base := 500
	var dette := Game.debt if banque.is_empty() else Game.debt_of(_preteur())
	if dette > 0:
		base = maxi(500, int(dette / 2.0 / 500.0) * 500)
	# Un client qui a du standing (tenue, voiture, maisons) mérite des montants à sa hauteur.
	base = maxi(base, 500 * (1 + Biens.standing() / 2))
	return [base, base * 2, base * 5]


func _refresh() -> void:
	for c in _amounts.get_children():
		c.queue_free()
	for a in _offers():
		var b := Button.new()
		b.text = "Emprunter %s" % Game.fmt(a)
		b.pressed.connect(_borrow.bind(a))
		_amounts.add_child(b)
	_status.text = "Vos crédits : %s   ·   Vous devez : %s   ·   frais de dossier %d %%, intérêts %d %% toutes les %d mises" % [
		Game.fmt(Game.credits), Game.fmt(Game.debt if banque.is_empty() else Game.debt_of(_preteur())), int(Game.LOAN_FEE * 100), int(Game.INTEREST_RATE * 100), Game.INTEREST_EVERY]


func _borrow(amount: int) -> void:
	Game.borrow(amount, _preteur())
	var pitch := _pitch()
	var line: String = (PITCH[mini(Game.loans_taken - 1, PITCH.size() - 1)] if Game.loans_taken <= PITCH.size() else PITCH.pick_random()) if banque.is_empty() else str(pitch.pick_random())
	_speech.text = "« Accordé, %s crédits. %s »" % [Game.fmt(amount), line]
	_refresh()


func _repay() -> void:
	var paid := Game.repay(Game.credits, _preteur())
	if paid <= 0:
		_speech.text = "« Rembourser ? Gardez donc vos liquidités pour investir. C'est plus raisonnable. »"
	else:
		_speech.text = "« %s remboursés. Quelle rigueur ! Vous voilà prêt pour un nouveau projet. »" % Game.fmt(paid)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
