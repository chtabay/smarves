extends PanelContainer
## La salle du poker à plusieurs, façon lobby : les trois tables de Minuit avec leurs joueurs et leurs
## chaises libres (la fonction casino, action « salle »), une chaise à prendre d'un clic, et la liste
## d'attente quand toutes sont pleines. Inscrit, on renouvelle sa place à chaque relecture ; dès qu'une
## chaise est à son rang, le croupier appelle et la table s'ouvre (signal `asseoir`).

signal asseoir(table_id: String)
signal closed

const BARRE := preload("res://scripts/jeux/barre.gd")
const RELIRE := 2.0

## La table d'où l'on a ouvert la salle (toute table du casino convient pour la lire).
var table_ref := "minuit:poker-1"
var inscrit := false
var vue := {}
## Pour les essais : la vue est posée à la main, sans réseau.
var hors_ligne := false
var _liste: VBoxContainer
var _etat: Label
var _attendre: Button
var _minuteur: Timer
var _busy := false


func _ready() -> void:
	BARRE.style(self)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(560, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(BARRE.label("Casino Minuit · la salle du poker", 26, BARRE.GOLD))
	v.add_child(BARRE.label("Hold'em sans limite, blindes 25/50, six joueurs par table, les habitués aux chaises libres.", 16, BARRE.MUTED))
	v.add_child(BARRE.separator())
	_liste = VBoxContainer.new()
	_liste.add_theme_constant_override("separation", 8)
	v.add_child(_liste)
	_etat = BARRE.label("", 16, BARRE.MUTED)
	_etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_etat)
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_END
	bas.add_theme_constant_override("separation", 10)
	v.add_child(bas)
	_attendre = BARRE.pill("Attendre une chaise")
	_attendre.pressed.connect(_basculer_attente)
	bas.add_child(_attendre)
	var fermer := BARRE.pill("Fermer")
	fermer.pressed.connect(fermer_salle)
	bas.add_child(fermer)
	_minuteur = Timer.new()
	_minuteur.wait_time = RELIRE
	_minuteur.autostart = not hors_ligne
	_minuteur.timeout.connect(_relire)
	add_child(_minuteur)
	if hors_ligne:
		montrer(vue)
	else:
		_etat.text = "Le croupier consulte le tableau des tables…"
		_relire()


func _relire() -> void:
	if _busy or hors_ligne:
		return
	_busy = true
	var r: Dictionary = await Compte.casino("attendre" if inscrit else "salle", {"table": table_ref})
	_busy = false
	if not is_inside_tree():
		return
	if r.code != 200 or not r.corps is Dictionary or r.corps.has("error"):
		_etat.text = str(r.corps.error) if r.corps is Dictionary and r.corps.has("error") else "Le casino ne répond pas. Vérifiez la connexion à Internet."
		return
	montrer(r.corps)


## Montre une vue de la salle ; inscrit et à son rang, on est appelé à la table qui a la chaise.
func montrer(v: Dictionary) -> void:
	vue = v
	for c in _liste.get_children():
		c.queue_free()
	for t in v.get("tables", []):
		_liste.add_child(_ligne(t))
	var att: Dictionary = v.get("attente", {})
	var rang = att.get("rang")
	inscrit = rang != null
	var appel := appelee(v)
	if inscrit and appel != "":
		_etat.text = "Le croupier vous appelle : %s." % nom(v, appel)
		_partir_vers(appel)
		return
	if inscrit:
		_etat.text = "Vous êtes %s sur la liste d'attente. Le croupier vous appelle dès qu'une chaise se libère." % ("le premier" if int(rang) == 1 else "le %de" % int(rang))
	elif complete(v):
		var n := int(att.get("longueur", 0))
		_etat.text = "Toutes les tables sont pleines%s. Inscrivez-vous : la première chaise libre sera pour vous ou pour qui attend avant vous." % ("" if n == 0 else ", %d joueur%s attend%s" % [n, "s" if n > 1 else "", "ent" if n > 1 else ""])
	else:
		_etat.text = "Choisissez votre table."
	_attendre.visible = inscrit or complete(v)
	_attendre.text = "Ne plus attendre" if inscrit else "Attendre une chaise"


func _ligne(t: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var g := VBoxContainer.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(g)
	var libres := int(t.get("libres", 0))
	var places := "complète" if libres == 0 else "%d chaise%s libre%s" % [libres, "s" if libres > 1 else "", "s" if libres > 1 else ""]
	g.add_child(BARRE.label("%s · %s" % [t.get("nom", ""), places], 20, BARRE.CREAM))
	var j: Array = t.get("joueurs", [])
	g.add_child(BARRE.label("Les habitués, en attendant des joueurs." if j.is_empty() else ", ".join(j), 15, BARRE.MUTED))
	if t.get("moi", false) or (libres > 0 and not inscrit):
		var b := BARRE.pill("Revenir" if t.get("moi", false) else "S'asseoir")
		var id := str(t.id)
		b.pressed.connect(func(): _partir_vers(id))
		h.add_child(b)
	return h


func _basculer_attente() -> void:
	if hors_ligne:
		return
	while _busy:
		await get_tree().process_frame
	_busy = true
	var r: Dictionary = await Compte.casino("ne-plus-attendre" if inscrit else "attendre", {"table": table_ref})
	_busy = false
	if is_inside_tree() and r.code == 200 and r.corps is Dictionary and not r.corps.has("error"):
		montrer(r.corps)


func _partir_vers(id: String) -> void:
	_minuteur.stop()
	asseoir.emit(id)


func fermer_salle() -> void:
	_minuteur.stop()
	if inscrit and not hors_ligne:
		await Compte.casino("ne-plus-attendre", {"table": table_ref})
	closed.emit()


## Toutes les tables pleines, et aucune n'est la sienne.
static func complete(v: Dictionary) -> bool:
	for t in v.get("tables", []):
		if int(t.get("libres", 0)) > 0 or t.get("moi", false):
			return false
	return true


## La table où l'inscrit a une chaise : celle dont les chaises libres couvrent son rang.
static func appelee(v: Dictionary) -> String:
	var rang = v.get("attente", {}).get("rang")
	if rang == null:
		return ""
	for t in v.get("tables", []):
		if int(t.get("libres", 0)) >= int(rang):
			return str(t.id)
	return ""


## Une table pleine renvoie à celle qui se remplit : la plus garnie de joueurs qui a encore une chaise.
## Vide si toutes sont pleines (ou si quelqu'un attend : les chaises sont à la liste).
static func vers(v: Dictionary, sauf := "") -> String:
	if int(v.get("attente", {}).get("longueur", 0)) > 0:
		return ""
	var best := ""
	var plus := -1
	for t in v.get("tables", []):
		if str(t.id) == sauf or int(t.get("libres", 0)) <= 0:
			continue
		var n := (t.get("joueurs", []) as Array).size()
		if n > plus:
			plus = n
			best = str(t.id)
	return best


static func nom(v: Dictionary, id: String) -> String:
	for t in v.get("tables", []):
		if str(t.id) == id:
			return str(t.get("nom", id))
	return id


static func table_de(v: Dictionary, id: String) -> Dictionary:
	for t in v.get("tables", []):
		if str(t.id) == id:
			return t
	return {}
