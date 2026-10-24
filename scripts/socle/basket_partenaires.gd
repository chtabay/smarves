extends "res://scripts/socle/basket_ecran.gd"
## Le mur des partenaires du club de basket, à l'entrée du grand hall (et à la table du conseil, dans la
## pièce du président) : ce qu'une vraie salle montre de ceux qui la financent (demande de Guillaume du
## 24 octobre 2026 : « les panneaux à l'entrée ne doivent pas être différents de ce qu'on trouverait dans
## une vraie salle, les achats de parts se font chez le notaire comme le reste »). Les porteurs
## d'obligations, du plus gros au plus petit, et le président en tête. On lit ; rien ne s'achète ici.

const DIRIGER := preload("res://scripts/socle/diriger.gd")


func remplir(col: VBoxContainer) -> void:
	var b := basket()
	_mot(col, "NOS PARTENAIRES", DOUX, 13)
	_mot(col, str(b.fiche(commune).nom).to_upper(), OR, 26)
	_filet(col)
	var a: Array = b.actionnaires(commune)
	if a.is_empty():
		_mot(col, "Votre nom ici : le club cherche ses premiers partenaires.", TEXTE, 18).name = "Vide"
	var dg: Dictionary = DIRIGER.dirigeant(b, commune)
	for i in a.size():
		var x: Dictionary = a[i]
		var president: bool = not dg.is_empty() and bool(x.moi) == bool(dg.moi) and (bool(x.moi) or str(x.nom) == str(dg.nom))
		var nom := "Vous" if bool(x.moi) else str(x.nom)
		# Le plus gros en grand, les autres de plus en plus petits, comme les plaques d'un vrai mur.
		var l := _mot(col, nom + ("  ·  président" if president else ""), OR if president else TEXTE, maxi(16, 30 - 3 * i))
		l.name = "Partenaire_%d" % (i + 1)
	_filet(col)
	_mot(col, "Les parts du club se signent chez %s." % str(preload("res://scripts/socle/notaire.gd").etude(Commune.smarves()).nom), DOUX, 14).name = "ChezLeNotaire"
	_fermer(col)
