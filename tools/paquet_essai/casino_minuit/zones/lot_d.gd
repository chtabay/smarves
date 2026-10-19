extends RefCounted
## Les briques communes du lot D « Les coulisses » (js/zones/d-commun.js) : l'enveloppe des pièces du
## personnel (béton peint, lino, plafond brut), les portes d'acier et leurs chambranles, les réglettes
## fluorescentes, les chemins de câbles, la signalétique peinte (pochoirs jaunes, plaques), et le mobilier
## technique (tables inox, tabourets, rayonnages, chariots, palettes, casiers, écrans). Toutes bâtissent
## avec le kit (K) dans la zone en cours. Le sous-sol est au niveau Y : ses zones décalent leur nœud de Y,
## et bâtissent en hauteurs relatives à leur sol, comme le moteur web ; les places qu'elles notent pour les
## figurants (K.places) sont en coordonnées du casino.
## Les images de l'atlas du moteur web (écrans, affiches, pochoirs) sont rendues ici en aplats colorés
## et en inscriptions (K.texte).

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
## Le sol du sous-sol (niveau B1) et la hauteur sous plafond des coulisses.
const Y := -5.0
const H := 3.4
## Les pastilles d'aplat de l'atlas (SW de d-commun.js).
const SW := {
	"jaune": "#E8C21A", "noir": "#17191C", "blanc": "#E6E9EC", "rouge": "#B8222B", "vert": "#2F7A48", "bleu": "#2A5C9A",
	"orange": "#D9742A", "gris": "#8C9197", "grisF": "#4A4F55", "grisC": "#C4C9CF", "carton": "#B08A5A", "bois": "#9A7648",
	"billet": "#6E9A6A", "toile": "#C9B98A", "caout": "#26282C", "creme": "#D8CBB0", "bordeaux": "#7A0E18",
	"bleuNuit": "#1B2440", "vertLino": "#3F5A52", "violet": "#6A3C8A", "rose": "#C8506E", "casier": "#5E7F96",
	"porte": "#6F7C86", "blindee": "#5C646E", "battante": "#B9C0C8", "liege": "#A8845A", "affiche": "#F1EEE4",
	# Les pastilles lumineuses (version « l » du moteur web).
	"neon": "#DCEBFF", "ledV": "#4DFF8A", "ledR": "#FF3B30", "ledA": "#FFB347", "ecran": "#1E5A8A", "flamme": "#5AB0FF",
	"chaud": "#FFE2B8", "ecranCam": "#5D86B0", "ecranData": "#3FA77A", "ecranPlan": "#3FA7A0", "ecranCompte": "#C8A04A",
}
const LUM := ["neon", "ledV", "ledR", "ledA", "ecran", "flamme", "chaud", "ecranCam", "ecranData", "ecranPlan", "ecranCompte"]
## Les plaques (PLAQUES de d-commun.js) : texte, fond, lettres.
const PLAQUES := {
	"perso": ["RÉSERVÉ AU PERSONNEL", "#C89B45", "#17191C"], "acces": ["ACCÈS RÉGLEMENTÉ", "#B8222B", "#FFFFFF"],
	"deux": ["DEUX PERSONNES OBLIGATOIRES", "#E8C21A", "#17191C"], "video": ["ZONE SOUS VIDÉOSURVEILLANCE", "#2A5C9A", "#FFFFFF"],
	"scene": ["SOURIEZ, VOUS ENTREZ EN SCÈNE", "#F3EAD7", "#B8222B"], "badge": ["BADGE OBLIGATOIRE", "#2A5C9A", "#FFFFFF"],
	"mains": ["LAVEZ-VOUS LES MAINS", "#2A5C9A", "#FFFFFF"], "chariots": ["ATTENTION AUX CHARIOTS", "#E8C21A", "#17191C"],
	"rec": ["ENREGISTREMENT EN COURS", "#B8222B", "#FFFFFF"], "registre": ["REGISTRE DES MOUVEMENTS", "#E6E9EC", "#17191C"],
	"saisis": ["OBJETS SAISIS", "#E6E9EC", "#17191C"], "froid": ["CHAMBRE FROIDE", "#E6E9EC", "#2A5C9A"],
	"jetons": ["RÉSERVE DE JETONS", "#17191C", "#E8C21A"], "jour": ["COFFRES DE JOUR", "#17191C", "#E8C21A"],
	"passe": ["LE PASSE", "#17191C", "#FFFFFF"], "reception": ["RÉCEPTION MARCHANDISES", "#E6E9EC", "#17191C"],
	"fumer": ["DÉFENSE DE FUMER", "#B8222B", "#FFFFFF"], "coupe": ["PORTE COUPE-FEU", "#B8222B", "#FFFFFF"],
	"lingots": ["MÉTAUX PRÉCIEUX", "#17191C", "#E8C21A"], "perdu": ["SIGNAL PERDU", "#101418", "#FF3B30"],
	"direct": ["EN DIRECT", "#101418", "#4DFF8A"],
}
## Les portes du sous-sol (D.PORTES, cotes du MASTERPLAN § 5) : position, plan du mur (« x » : le mur est
## le plan x = cste), largeur, hauteur, genre, côté où s'ouvrent les vantaux (+1 : vers +x ou +z).
const PORTES := {
	"S03": {"x": 32.0, "z": 24.0, "plan": "x", "w": 1.6, "h": 2.2, "genre": "hublot", "sens": -1.0, "danger": true},
	"S04": {"x": 32.0, "z": 14.0, "plan": "x", "w": 2.0, "h": 2.4, "genre": "grille", "sens": 1.0, "danger": true},
	"S05": {"x": 26.0, "z": 18.0, "plan": "z", "w": 1.4, "h": 2.2, "genre": "blindee", "sens": 1.0, "danger": true},
	"S07": {"x": 32.0, "z": 3.0, "plan": "x", "w": 1.2, "h": 2.2, "genre": "blindee", "sens": -1.0, "danger": false},
	"S08": {"x": 20.0, "z": 0.0, "plan": "x", "w": 1.0, "h": 2.2, "genre": "porte", "sens": -1.0, "danger": false},
	"S09": {"x": 32.0, "z": -10.0, "plan": "x", "w": 1.4, "h": 2.2, "genre": "porte", "sens": -1.0, "danger": false},
	"S11": {"x": 32.0, "z": -23.0, "plan": "x", "w": 1.8, "h": 2.2, "genre": "battante", "sens": -1.0, "danger": false},
	"L15": {"x": 36.0, "z": 24.0, "plan": "x", "w": 1.4, "h": 2.2, "genre": "porte", "sens": -1.0, "danger": false},
	"L25": {"x": 36.0, "z": 2.0, "plan": "x", "w": 1.4, "h": 2.2, "genre": "porte", "sens": 1.0, "danger": false},
	"L14": {"x": 31.5, "z": 21.0, "plan": "z", "w": 1.2, "h": 2.2, "genre": "blindee", "sens": 1.0, "danger": true},
	"M12": {"x": 38.0, "z": -4.0, "plan": "z", "w": 1.2, "h": 2.2, "genre": "porte", "sens": -1.0, "danger": false},
}


static func B():
	return load(LOT_B)


## Le nom de matière d'une pastille : un aplat mat, ou une lueur pour les pastilles lumineuses.
static func c(k: String) -> String:
	return ("lueur" if k in LUM else "aplat") + SW[k]


static func bx(K, k: String, w: float, h: float, d: float, x: float, y: float, z: float, ry := 0.0) -> void:
	K.box(c(k), w, h, d, x, y, z, ry)


static func cy(K, k: String, rh: float, rb: float, h: float, x: float, y: float, z: float, seg := 10, rx := 0.0, rz := 0.0) -> void:
	K.cyl(c(k), rh, rb, h, x, y, z, seg, rx, rz)


static func sp(K, k: String, r: float, x: float, y: float, z: float, sy := 1.0) -> void:
	K.sph(c(k), r, x, y, z, sy)


## Un pavé dans un repère r = [x, z, rot] (B.rbox), d'une pastille.
static func rbx(K, r: Array, k: String, w: float, h: float, d: float, lx: float, y: float, lz: float, lry := 0.0) -> void:
	B().rbox(K, r, c(k), w, h, d, lx, y, lz, lry)


## Un obstacle w × d centré au point local (lx, lz) d'un repère (addLocalBox).
static func robstacle(K, r: Array, lx0: float, lx1: float, lz0: float, lz1: float, h := 2.4) -> void:
	var p: Vector2 = B().loc(r, (lx0 + lx1) / 2.0, (lz0 + lz1) / 2.0)
	K.solide(absf(lx1 - lx0), h, absf(lz1 - lz0), p.x, h / 2.0, p.y, r[2])


# --- Enveloppe ---------------------------------------------------------------------------------------

## Une pièce des coulisses (D.coque) : sol de lino où l'on marche, cloisons de béton peint percées de leurs
## ouvertures (ouv[côté] = [{at, w, h}], at absolu ; false : pas de cloison), plafond brut à h.
## o : sol (« lino », false), mur (« beton »), plafond (true), soubassement (true : bande peinte de 1,2 m).
static func coque(K, b: Dictionary, h: float, ouv: Dictionary, o := {}) -> void:
	var sol = o.get("sol", "lino")
	if sol is String:
		K.plan(sol, b.x0, b.x1, b.z0, b.z1, 0.0)
		K.dalle(b.x0, b.x1, b.z0, b.z1, 0.0)
	var mur: String = o.get("mur", "beton")
	var e := 0.1
	var cotes := {
		"north": [b.x0, b.z0 + e, b.x1, b.z0 + e, 0.0, 1.0, b.x0],
		"south": [b.x0, b.z1 - e, b.x1, b.z1 - e, 0.0, -1.0, b.x0],
		"west": [b.x0 + e, b.z0, b.x0 + e, b.z1, 1.0, 0.0, b.z0],
		"east": [b.x1 - e, b.z0, b.x1 - e, b.z1, -1.0, 0.0, b.z0],
	}
	for cote in cotes:
		var ops = ouv.get(cote, [])
		if ops is bool:
			continue
		var t: Array = cotes[cote]
		mur_d(K, t[0], t[1], t[2], t[3], h, t[4], t[5], ops, t[6], mur, o.get("soubassement", mur == "beton"))
	if o.get("plafond", true):
		K.plan("brut", b.x0, b.x1, b.z0, b.z1, h, false)


## Une cloison de b (x0, z0) à (x1, z1), parement de normale (nx, nz), percée d'ouvertures à abscisses
## absolues (comptées depuis a0, la coordonnée de son départ) ; avec sa bande de soubassement vert lino
## et son filet jaune (la texture des couloirs du moteur web), interrompus aux ouvertures.
static func mur_d(K, x0: float, z0: float, x1: float, z1: float, h: float, nx: float, nz: float, ops: Array, a0: float, mur := "beton", soubassement := true) -> void:
	var loc := []
	for op in ops:
		loc.append({"at": op.at - a0, "w": op.w, "h": op.get("h", 2.2)})
	K.mur(x0, z0, x1, z1, h, nx, nz, loc, mur, 0.0, false)
	if not soubassement:
		return
	var l := Vector2(x1 - x0, z1 - z0).length()
	var ux := (x1 - x0) / l
	var uz := (z1 - z0) / l
	var ry := atan2(-uz, ux)
	for p in B().pleins(0.0, l, loc):
		var m: float = (p[0] + p[1]) / 2.0
		var px := x0 + ux * m + nx * 0.104
		var pz := z0 + uz * m + nz * 0.104
		K.box(c("vertLino"), p[1] - p[0], 1.2, 0.008, px, 0.6, pz, ry)
		K.box(c("jaune"), p[1] - p[0], 0.06, 0.01, px, 1.23, pz, ry)


## Un bloc de béton brut x0..x1 × y0..y1 × z0..z1 (D.bloc), avec sa collision si solide.
static func bloc(K, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, solide := true, nom_mat := "brut") -> void:
	var w := absf(x1 - x0)
	var hh := absf(y1 - y0)
	var d := absf(z1 - z0)
	K.box(nom_mat, w, hh, d, (x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
	if solide:
		K.solide(w, hh, d, (x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)


# --- Portes ------------------------------------------------------------------------------------------

## L'encadrement d'une porte (D.cadre) : chambranle d'acier sur l'épaisseur du mur, seuil, bandes de
## danger de part et d'autre si la porte est sous contrôle.
static func cadre(K, x: float, z: float, plan: String, w: float, h: float, danger := false) -> void:
	var ry := PI / 2.0 if plan == "x" else 0.0
	var r := [x, z, ry]
	var jw := 0.09
	for s in [-1.0, 1.0]:
		B().rbox(K, r, "acier", jw, h + jw, 0.46, s * (w / 2.0 + jw / 2.0), (h + jw) / 2.0, 0.0)
	B().rbox(K, r, "acier", w + 2.0 * jw, jw, 0.46, 0.0, h + jw / 2.0, 0.0)
	rbx(K, r, "grisF", w, 0.012, 0.44, 0.0, 0.006, 0.0)
	if danger:
		for f in [-1.0, 1.0]:
			for s in [-1.0, 1.0]:
				for k in 4:
					rbx(K, r, "jaune" if k % 2 == 0 else "noir", 0.14, h / 4.0, 0.01, s * (w / 2.0 + jw + 0.08), h / 8.0 + k * h / 4.0, f * 0.212)


## Une porte du lot D (D.porte) : son encadrement, et ses vantaux ouverts contre le tableau du côté sens,
## sauf ferme (alors : clos, avec sa collision). genre : « porte » (acier), « hublot », « blindee »,
## « battante » (double, à hublots), « grille » (coulissante, rangée dans le mur).
static func porte(K, id: String, ferme := false) -> void:
	var o: Dictionary = PORTES[id]
	var w: float = o.w
	var h: float = o.h
	var x: float = o.x
	var z: float = o.z
	cadre(K, x, z, o.plan, w, h, o.danger)
	var ry := PI / 2.0 if o.plan == "x" else 0.0
	var r := [x, z, ry]
	var genre: String = o.genre
	if genre == "grille":
		# Rangée dans l'épaisseur du mur, à côté de la baie : on n'en voit que le bord et la poignée.
		for i in 15:
			B().rbox(K, r, "acier", 0.03, h - 0.1, 0.03, w / 2.0 + 0.2 + i * 0.13, h / 2.0, 0.0)
		for yy in [0.06, h * 0.5, h - 0.06]:
			B().rbox(K, r, "acier", 2.0, 0.07, 0.05, w / 2.0 + 1.1, yy, 0.0)
		return
	var vantaux := [[w, -w / 2.0, 1.0]] if genre != "battante" else [[w / 2.0, -w / 2.0, 1.0], [w / 2.0, w / 2.0, -1.0]]
	var sens: float = o.sens
	var teinte: String = genre if genre in ["blindee", "battante"] else "porte"
	for v in vantaux:
		var lw: float = v[0]
		var hx: float = v[1]
		var dir: float = v[2]
		if ferme:
			rbx(K, r, teinte, lw, h, 0.05, hx + dir * lw / 2.0, h / 2.0, 0.0)
			continue
		# Ouvert à 90° : le vantail se range perpendiculaire au mur, contre le tableau, côté sens.
		var lz := sens * (0.2 + lw / 2.0)
		var lx := hx + dir * 0.03
		rbx(K, r, teinte, 0.05, h, lw, lx, h / 2.0, lz)
		rbx(K, r, "jaune", 0.052, 0.12, lw, lx, 0.07, lz)
		B().rbox(K, r, "acier", 0.08, 0.04, 0.12, lx - dir * 0.05, 1.05, lz + sens * (lw / 2.0 - 0.12))
		if genre in ["hublot", "battante"]:
			var p: Vector2 = B().loc(r, lx - dir * 0.028, lz)
			var rx := PI / 2.0 if o.plan == "x" else 0.0
			cy(K, "noir", 0.15, 0.15, 0.06, p.x, h * 0.73, p.y, 16, rx, PI / 2.0 - rx)
		robstacle(K, r, lx - 0.04, lx + 0.04, lz - lw / 2.0, lz + lw / 2.0)
	if ferme:
		K.solide(w, h, 0.3, x, h / 2.0, z, ry)


# --- Lumière, réseaux, signalétique --------------------------------------------------------------------

## Une réglette fluorescente au plafond (D.neon) : boîtier blanc, deux tubes qui luisent.
static func neon(K, x: float, z: float, axe := "z", l := 1.5, y := H - 0.07) -> void:
	var ax := axe == "x"
	bx(K, "blanc", l + 0.1 if ax else 0.2, 0.06, 0.2 if ax else l + 0.1, x, y, z)
	for s in [-1.0, 1.0]:
		bx(K, "neon", l if ax else 0.05, 0.045, 0.05 if ax else l, x + (0.0 if ax else s * 0.045), y - 0.05, z + (s * 0.045 if ax else 0.0))


## Une suspension industrielle (D.lampe) : abat-jour noir, disque lumineux.
static func lampe(K, x: float, z: float, y := 3.0, haut := H, k := "chaud") -> void:
	cy(K, "noir", 0.012, 0.012, maxf(0.05, haut - y - 0.2), x, (haut + y + 0.2) / 2.0, z, 5)
	cy(K, "noir", 0.1, 0.34, 0.22, x, y + 0.11, z, 12)
	cy(K, k, 0.3, 0.3, 0.02, x, y + 0.012, z, 12)


## Le chemin de câbles et les tuyaux au plafond (D.reseaux), le long de z (x fixe) ou de x (z fixe).
static func reseaux(K, axe: String, fixe: float, a: float, b: float, y := H - 0.24, rouge := true) -> void:
	var l := absf(b - a)
	var m := (a + b) / 2.0
	var ax := axe == "x"
	var pos := func(d: float, yy: float) -> Vector3: return Vector3(m, yy, fixe + d) if ax else Vector3(fixe + d, yy, m)
	var p: Vector3 = pos.call(0.0, y)
	bx(K, "grisF", l if ax else 0.3, 0.05, 0.3 if ax else l, p.x, p.y, p.z)
	for s in [-1.0, 1.0]:
		var q: Vector3 = pos.call(s * 0.15, y + 0.04)
		K.box("acier", l if ax else 0.02, 0.06, 0.02 if ax else l, q.x, q.y, q.z)
	for k in [["grisC", 0.07, 0.35, 0.09], ["noir", 0.03, 0.22, 0.04]]:
		var q: Vector3 = pos.call(k[2], y + 0.14)
		cy(K, k[0], k[1], k[1], l, q.x, q.y, q.z, 8, PI / 2.0 if not ax else 0.0, PI / 2.0 if ax else 0.0)
	if rouge:
		var q: Vector3 = pos.call(-0.38, y + 0.12)
		cy(K, "rouge", 0.045, 0.045, l, q.x, q.y, q.z, 8, PI / 2.0 if not ax else 0.0, PI / 2.0 if ax else 0.0)


## Un pochoir peint en jaune (« COMPTAGE », « B1 »…), de hauteur h, lu depuis ry.
static func pochoir(K, t: String, x: float, y: float, z: float, ry: float, h: float) -> void:
	K.texte(t, maxf(0.6, t.length() * h * 0.75), h, x + sin(ry) * 0.006, y, z + cos(ry) * 0.006, ry, "grave", Color(SW.jaune))


## Un pochoir peint au sol, lu en arrivant depuis la direction ry.
static func pochoir_sol(K, t: String, x: float, z: float, ry: float, h: float) -> void:
	var l: Label3D = K.texte(t, maxf(0.6, t.length() * h * 0.75), h, x, 0.008, z, 0.0, "grave", Color(SW.jaune))
	l.rotation = Vector3(-PI / 2.0, ry, 0.0)


## Une plaque (D.plaque) : fond plein, inscription, largeur w ; lue depuis ry.
static func plaque(K, k: String, x: float, y: float, z: float, ry: float, w: float) -> void:
	var p: Array = PLAQUES[k]
	var hh := w * 36.0 / 236.0
	K.box("aplat" + p[1], w, hh, 0.012, x + sin(ry) * 0.006, y, z + cos(ry) * 0.006, ry)
	K.texte(p[0], w * 0.92, hh * 0.55, x + sin(ry) * 0.014, y, z + cos(ry) * 0.014, ry, "grave", Color(p[2]))


## Un panneau plat (affiche, planning, tableau blanc, liège) : un fond, une bande de titre.
static func affiche(K, fond: String, bande: String, w: float, h: float, x: float, y: float, z: float, ry: float) -> void:
	K.box(c(fond), w, h, 0.012, x + sin(ry) * 0.006, y, z + cos(ry) * 0.006, ry)
	if bande != "":
		K.box(c(bande), w, h * 0.15, 0.014, x + sin(ry) * 0.008, y + h * 0.425, z + cos(ry) * 0.008, ry)


## Un écran plat (D.ecran) sur son pied, regardé depuis ry : cadre noir, image qui luit.
static func ecran(K, k: String, x: float, y: float, z: float, ry: float, w := 0.5, pied := true) -> void:
	var hh := w * 9.0 / 16.0
	var sx := sin(ry)
	var cz := cos(ry)
	bx(K, "noir", w + 0.04, hh + 0.04, 0.03, x, y, z, ry)
	bx(K, k, w, hh, 0.006, x + sx * 0.017, y, z + cz * 0.017, ry)
	if pied:
		bx(K, "noir", 0.05, 0.14, 0.03, x - sx * 0.02, y - hh / 2.0 - 0.06, z - cz * 0.02, ry)
		bx(K, "noir", 0.2, 0.015, 0.14, x - sx * 0.02, y - hh / 2.0 - 0.125, z - cz * 0.02, ry)


## Un dôme de caméra sous plafond (D.dome).
static func dome(K, x: float, y: float, z: float) -> void:
	cy(K, "blanc", 0.11, 0.11, 0.04, x, y - 0.02, z, 10)
	sp(K, "noir", 0.09, x, y - 0.04, z)
	bx(K, "ledR", 0.012, 0.012, 0.012, x, y - 0.1, z + 0.07)


## Un extincteur sur son support mural (D.extincteur), le mur de normale ry.
static func extincteur(K, x: float, z: float, ry: float) -> void:
	var px := x + sin(ry) * 0.11
	var pz := z + cos(ry) * 0.11
	cy(K, "rouge", 0.075, 0.075, 0.46, px, 0.62, pz, 10)
	sp(K, "rouge", 0.075, px, 0.85, pz, 0.7)
	cy(K, "noir", 0.022, 0.03, 0.09, px, 0.93, pz, 6)
	bx(K, "grisF", 0.16, 0.03, 0.04, x + sin(ry) * 0.03, 0.4, z + cos(ry) * 0.03, ry)


## Le bloc « sortie » vert lumineux (D.sortie).
static func sortie(K, x: float, y: float, z: float, ry: float) -> void:
	bx(K, "noir", 0.54, 0.26, 0.03, x + sin(ry) * 0.015, y, z + cos(ry) * 0.015, ry)
	bx(K, "ledV", 0.5, 0.21, 0.006, x + sin(ry) * 0.032, y, z + cos(ry) * 0.032, ry)


## Une armoire électrique murale (D.armoire).
static func armoire(K, x: float, z: float, ry: float, w := 0.7, h := 1.1, y := 1.25) -> void:
	bx(K, "gris", w, h, 0.22, x + sin(ry) * 0.11, y, z + cos(ry) * 0.11, ry)
	bx(K, "grisC", w - 0.06, h - 0.06, 0.006, x + sin(ry) * 0.223, y, z + cos(ry) * 0.223, ry)


## Une bande peinte au sol de A à B (D.ligne), de largeur w.
static func ligne(K, k: String, ax: float, az: float, bxx: float, bz: float, w := 0.1) -> void:
	var l := Vector2(bxx - ax, bz - az).length()
	bx(K, k, w, 0.004, l, (ax + bxx) / 2.0, 0.004, (az + bz) / 2.0, atan2(bxx - ax, bz - az))


## Des hachures jaunes et noires au sol, w × d centrées en (x, z), le long de x (ry = 0) ou de z.
static func hachure_sol(K, w: float, d: float, n: int, x: float, z: float, ry := 0.0) -> void:
	for i in n:
		var u := -w / 2.0 + (i + 0.5) * w / n
		bx(K, "jaune" if i % 2 == 0 else "noir", w / n, 0.004, d, x + cos(ry) * u, 0.005, z - sin(ry) * u, ry)


# --- Mobilier technique ------------------------------------------------------------------------------

## Une table inox w × d (D.tableInox) : plateau à h, piétement, tablette basse ; sa collision.
static func table_inox(K, x: float, z: float, w: float, d: float, ry := 0.0, h := 0.9, tablette := true, collision := true) -> void:
	var r := [x, z, ry]
	B().rbox(K, r, "acier", w, 0.05, d, 0.0, h - 0.025, 0.0)
	if tablette:
		B().rbox(K, r, "acier", w - 0.1, 0.025, d - 0.1, 0.0, 0.22, 0.0)
	for p in [[-1.0, -1.0], [1.0, -1.0], [-1.0, 1.0], [1.0, 1.0]]:
		B().rbox(K, r, "acier", 0.05, h - 0.05, 0.05, p[0] * (w / 2.0 - 0.05), (h - 0.05) / 2.0, p[1] * (d / 2.0 - 0.05))
	if collision:
		robstacle(K, r, -w / 2.0, w / 2.0, -d / 2.0, d / 2.0, h)


## Un tabouret ou une chaise de bureau (D.siege), assise à sh ; le dossier derrière l'occupant (ry).
static func siege(K, x: float, z: float, ry: float, sh := 0.5, dos := true) -> void:
	cy(K, "grisF", 0.025, 0.025, sh - 0.06, x, (sh - 0.06) / 2.0, z, 6)
	cy(K, "grisF", 0.2, 0.22, 0.025, x, 0.013, z, 5)
	cy(K, "caout", 0.2, 0.19, 0.07, x, sh - 0.035, z, 10)
	if dos:
		bx(K, "caout", 0.38, 0.36, 0.05, x + sin(ry) * 0.2, sh + 0.28, z + cos(ry) * 0.2, ry)


## Un rayonnage métallique (D.rayonnage) : n travées de bay le long de x local, profondeur d, hauteur h,
## niveaux ; charge.call(i, niveau, y, cx) remplit, dans le repère du rayonnage (rendu en premier argument).
static func rayonnage(K, x: float, z: float, ry: float, n: int, bay: float, d: float, h: float, niveaux: int, charge = null) -> Array:
	var r := [x, z, ry]
	var W := n * bay
	for i in n + 1:
		for s in [-1.0, 1.0]:
			B().rbox(K, r, "acier", 0.04, h, 0.04, -W / 2.0 + i * bay, h / 2.0, s * (d / 2.0 - 0.02))
	for l in niveaux:
		var y := 0.15 + l * (h - 0.25) / maxf(1.0, niveaux - 1.0)
		B().rbox(K, r, "acier", W, 0.03, d, 0.0, y, 0.0)
		if charge != null:
			for i in n:
				charge.call(r, i, l, y + 0.015, -W / 2.0 + (i + 0.5) * bay)
	robstacle(K, r, -W / 2.0, W / 2.0, -d / 2.0, d / 2.0)
	return r


## Une palette de bois (D.palette) dans le repère rendu.
static func palette(K, x: float, z: float, ry := 0.0) -> Array:
	var r := [x, z, ry]
	for dz in [-0.42, -0.14, 0.14, 0.42]:
		rbx(K, r, "bois", 1.2, 0.022, 0.2, 0.0, 0.13, dz)
	for dx in [-0.5, 0.0, 0.5]:
		rbx(K, r, "bois", 0.1, 0.09, 1.0, dx, 0.07, 0.0)
	robstacle(K, r, -0.62, 0.62, -0.52, 0.52)
	return r


## Un carton (D.carton), sa face imprimée en bande.
static func carton(K, r: Array, w: float, h: float, d: float, lx: float, y: float, lz: float, lry := 0.0) -> void:
	rbx(K, r, "carton", w, h, d, lx, y, lz, lry)
	rbx(K, r, "noir", w * 0.5, 0.03, d + 0.004, lx, y + h * 0.2, lz, lry)


## Un chariot (D.chariot) : « fonds » (cage de transport de fonds), « linge », « plateau » (charge :
## [[pastille, w, h, d, lx, y, lz]]).
static func chariot(K, x: float, z: float, ry: float, genre: String, charge := []) -> void:
	var r := [x, z, ry]
	for p in [[-0.32, -0.5], [0.32, -0.5], [-0.32, 0.5], [0.32, 0.5]]:
		var q: Vector2 = B().loc(r, p[0], p[1])
		cy(K, "caout", 0.07, 0.07, 0.05, q.x, 0.07, q.y, 8, 0.0, PI / 2.0)
	B().rbox(K, r, "acier", 0.78, 0.04, 1.16, 0.0, 0.16, 0.0)
	if genre == "fonds":
		for p in [[-0.37, -0.56], [0.37, -0.56], [-0.37, 0.56], [0.37, 0.56]]:
			B().rbox(K, r, "acier", 0.035, 1.05, 0.035, p[0], 0.7, p[1])
		B().rbox(K, r, "acier", 0.78, 0.035, 1.16, 0.0, 1.22, 0.0)
		B().rbox(K, r, "acier", 0.74, 0.02, 1.12, 0.0, 0.68, 0.0)
		for s in [-1.0, 1.0]:
			for k in 5:
				B().rbox(K, r, "acier", 0.012, 1.0, 0.012, s * 0.38, 0.7, -0.5 + k * 0.25)
		for p in [[-0.2, 0.2, -0.3], [0.18, 0.2, -0.28], [-0.18, 0.2, 0.1], [0.2, 0.2, 0.12], [-0.2, 0.72, -0.3], [0.18, 0.72, 0.05]]:
			rbx(K, r, "noir", 0.3, 0.2, 0.34, p[0], p[1] + 0.1, p[2])
			rbx(K, r, "jaune", 0.14, 0.07, 0.01, p[0], p[1] + 0.12, p[2] + 0.172)
	elif genre == "linge":
		rbx(K, r, "bleu", 0.74, 0.66, 1.1, 0.0, 0.52, 0.0)
		rbx(K, r, "blanc", 0.66, 0.1, 1.0, 0.0, 0.88, 0.0)
	else:
		for p in [[-0.37, -0.56], [0.37, -0.56], [-0.37, 0.56], [0.37, 0.56]]:
			B().rbox(K, r, "acier", 0.03, 0.82, 0.03, p[0], 0.58, p[1])
		B().rbox(K, r, "acier", 0.78, 0.03, 1.16, 0.0, 0.56, 0.0)
		B().rbox(K, r, "acier", 0.78, 0.03, 1.16, 0.0, 0.98, 0.0)
		for l in charge:
			rbx(K, r, l[0], l[1], l[2], l[3], l[4], l[5], l[6])
	robstacle(K, r, -0.42, 0.42, -0.62, 0.62, 1.3)


## Une rangée de n casiers (D.casiers) le long de x local, portes vers +z local ; sa collision.
static func casiers(K, x: float, z: float, ry: float, n: int) -> void:
	var r := [x, z, ry]
	var W := n * 0.4
	rbx(K, r, "grisF", W, 0.1, 0.48, 0.0, 0.05, 0.0)
	rbx(K, r, "casier", W, 1.84, 0.5, 0.0, 1.02, 0.0)
	rbx(K, r, "grisF", W + 0.02, 0.03, 0.52, 0.0, 1.955, 0.0)
	for i in n:
		var lx := -W / 2.0 + 0.2 + i * 0.4
		rbx(K, r, "noir", 0.012, 1.8, 0.006, lx - 0.196, 1.02, 0.253)
		rbx(K, r, "grisC", 0.03, 0.12, 0.012, lx + 0.12, 1.0, 0.255)
		for k in 3:
			rbx(K, r, "grisF", 0.2, 0.012, 0.006, lx, 1.7 - k * 0.04, 0.253)
	robstacle(K, r, -W / 2.0, W / 2.0, -0.25, 0.25)


## Une table de cantine 1,2 × 0,75 et ses quatre chaises coques (D.tablePause) ; rend les quatre places
## [Vector3 assise, f], en coordonnées locales à la zone.
static func table_pause(K, x: float, z: float, rot: float, teinte := "") -> Array:
	var r := [x, z, rot]
	var places := []
	rbx(K, r, "creme", 1.2, 0.04, 0.75, 0.0, 0.74, 0.0)
	for p in [[-0.5, -0.28], [0.5, -0.28], [-0.5, 0.28], [0.5, 0.28]]:
		rbx(K, r, "grisF", 0.04, 0.72, 0.04, p[0], 0.36, p[1])
	var i := 0
	for ch in [[-0.3, 0.68, 0.0], [0.3, 0.68, 0.0], [-0.3, -0.68, PI], [0.3, -0.68, PI]]:
		var k := teinte if teinte != "" else ("orange" if i % 2 else "bleu")
		var s := 1.0 if ch[1] > 0 else -1.0
		rbx(K, r, k, 0.4, 0.04, 0.4, ch[0], 0.45, ch[1])
		rbx(K, r, k, 0.4, 0.36, 0.04, ch[0], 0.7, ch[1] + s * 0.2)
		for l in [[-0.17, -0.17], [0.17, -0.17], [-0.17, 0.17], [0.17, 0.17]]:
			rbx(K, r, "grisF", 0.025, 0.44, 0.025, ch[0] + l[0], 0.22, ch[1] + l[1])
		var q: Vector2 = B().loc(r, ch[0], ch[1])
		places.append([Vector3(q.x, 0.47, q.y), rot + ch[2]])
		i += 1
	cy(K, "blanc", 0.045, 0.04, 0.09, x + 0.2, 0.805, z + 0.1, 8)
	robstacle(K, r, -0.6, 0.6, -0.38, 0.38, 0.76)
	return places


## Une liasse de billets en tas (D.pileLiasses) : nx × ny × nz briques vertes à bande crème.
static func liasses(K, x: float, y: float, z: float, nx: int, ny: int, nz: int, ry := 0.0) -> void:
	var r := [x, z, ry]
	var w := nx * 0.16
	var d := nz * 0.07
	var hh := ny * 0.018
	rbx(K, r, "billet", w, hh, d, 0.0, y + hh / 2.0, 0.0)
	for i in nx:
		rbx(K, r, "creme", 0.04, hh + 0.002, d + 0.002, -w / 2.0 + 0.08 + i * 0.16, y + hh / 2.0, 0.0)


## Une place pour un figurant, notée dans K.places[cle] en coordonnées du casino (sous-sol : + Y).
static func place(K, cle: String, x: float, y: float, z: float, f: float, dy := Y) -> void:
	if not K.places.has(cle):
		K.places[cle] = []
	K.places[cle].append([Vector3(x, y + dy, z), f])
