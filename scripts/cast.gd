class_name Cast
extends RefCounted
## Les fiches des habitants : qui est qui, de quelle espèce, habillé comment, dans quelle pose de fond.
##
## Règles de la famille (voir docs/PERSONNAGES.md) :
## - des humains de bande dessinée, en ligne claire : proportions d'adulte, yeux en point, aplats, contour noir ;
## - chacun se reconnaît à sa coupe, son nez, son chapeau et sa carrure ; « fur » est le teint de la peau ;
## - au village, les couleurs du Poitou (bleu de travail, brique, moutarde, vert bouteille) ;
## - au casino, le personnel en noir, blanc et or, les hôtesses en bordeaux, les clients en tenue de soirée ;
## - chaque personnage nommé a une silhouette qui se lit de dessus : un chapeau, une queue, une forme de corps.

# --- La palette --------------------------------------------------------------------------------
const NUIT := "#1d2a55"
const NOIR := "#16151b"
const BLANC := "#f4f1ea"
const OR := "#d4a443"
const BORDEAUX := "#7a1f30"
const BRIQUE := "#b8402e"
const MOUTARDE := "#d1a23a"
const BOUTEILLE := "#2e5a40"
const BLEU_TRAVAIL := "#2f5aa8"
const CREME := "#efe6d2"
const ANTHRACITE := "#3a3b44"
const TABAC := "#8b5a2b"

## Les teints et les cheveux (ligne claire : des aplats, pas de dégradés).
const PEAU := ["#f3d6bd", "#eac4a2", "#e0b08a", "#c99068", "#a8714c", "#f6e0cf"]
const ROUX := "#c8642e"
const CHEVEUX := ["#2a2420", "#4a3426", "#6a4a32", "#8a6a45", "#c8a050", "#9a4a2a", "#16141a", "#8a8278", "#c8c4bc", "#e8e2d8"]
const COUPES_H := ["court", "court", "raie", "gomina", "degarni", "chauve", "raie"]
const COUPES_F := ["permanente", "carre", "chignon", "brushing", "queue", "frange", "carre"]
const NEZ := ["rond", "rond", "patate", "long", "busque", "retrousse"]

const VILLAGE_TOPS := ["#2f5aa8", "#b8402e", "#d1a23a", "#2e5a40", "#7a1f30", "#efe6d2", "#4d6fa8", "#c96a3a", "#6b7d3a", "#8a7bb8", "#d98f9c", "#3d5a6e"]
const VILLAGE_LEGS := ["#2f4a80", "#6a4a32", "#55565e", "#c7b48f", "#3a3b44", "#4a5a3a"]
const SOIREE_MEN := ["#16151b", "#1d2a55", "#5a1424", "#efe6d2", "#2a3a2e", "#3a3b44"]
const SOIREE_WOMEN := ["#a3172b", "#16151b", "#1f6a52", "#24408f", "#c9a043", "#7a5aa0", "#d06a8a"]


# --- Les personnages nommés ----------------------------------------------------------------------
const NAMED := {
	"joueur": {"species": "humain", "fur": PEAU[0], "hair": "raie", "hair_color": ROUX, "nose": "rond", "build": {"leg": 1.02},
		"top": "veste", "top_color": NUIT, "top2": CREME, "lapel": "#27366a", "buttons": OR,
		"legs": "pantalon", "legs_color": NUIT, "neck": "noeud", "neck_color": OR, "shoes": "#3a2418"},
	"inconnu": {"species": "humain", "fur": PEAU[1], "hair": "court", "hair_color": "#9a958c", "nose": "busque", "build": {"leg": 1.08, "torso": 1.06, "width": 0.92},
		"top": "trench", "top_color": "#3b3a40", "top2": "#d8d2c8",
		"legs": "pantalon", "legs_color": "#25242a", "neck": "noeud", "neck_color": OR,
		"hat": "feutre", "hat_color": "#1c1a20", "hat_band": BORDEAUX, "face": ["moustache"], "moustache": "#d8d2c8", "shoes": "#141318"},
	"josiane": {"species": "humain", "fur": PEAU[0], "hair": "permanente", "hair_color": "#e2c271", "nose": "retrousse", "build": {"belly": 1.2, "width": 1.06},
		"top": "robe", "top_color": "#d0607a", "skirt_len": 0.6, "sleeves": "courtes",
		"apron": true, "apron_color": "#fbf8f0", "neck": "collier",
		"lip": "#a3172b", "shoes": "#5a1424"},
	"dede": {"species": "humain", "fur": PEAU[2], "hair": "court", "hair_color": "#8a8278", "nose": "patate", "nose_red": 0.35, "build": {"belly": 1.4, "width": 1.14, "leg": 0.94}, "face": ["moustache"], "moustache": "#6a6258",
		"top": "veste", "top_color": "#3a2620", "top2": "#d9cfb0", "lapel": "#2a1a16",
		"legs": "pantalon", "legs_color": BLEU_TRAVAIL, "hat": "casquette", "hat_color": "#c0322e", "prop_r": "gobelet", "shoes": "#3a2a20"},
	"lucien": {"species": "humain", "fur": PEAU[1], "hair": "court", "hair_color": "#a8a298", "nose": "long", "build": {"leg": 1.08, "width": 0.86},
		"top": "gilet", "top_color": MOUTARDE, "top2": "#f4f1ea", "sleeves": "courtes",
		"legs": "pantalon", "legs_color": "#6a4a32", "hat": "canotier", "hat_color": "#e6c66e", "hat_band": "#2f5aa8", "face": ["lunettes"], "frame": "#2a2224",
		"prop_l": "carnet", "shoes": "#2a2224"},
	"brunet": {"species": "humain", "fur": PEAU[0], "hair": "raie", "hair_color": "#3a2a22", "nose": "long", "build": {"belly": 1.05},
		"top": "veste", "top_color": "#6a6b74", "top2": BLANC, "lapel": "#5a5b64",
		"legs": "pantalon", "legs_color": "#6a6b74", "neck": "cravate", "neck_color": "#9a1f30",
		"watch_chain": true, "prop_l": "mallette", "shoes": "#141318"},
	"ferrand": {"species": "humain", "fur": PEAU[0], "hair": "permanente", "hair_color": "#7a4a2e", "nose": "retrousse", "build": {"belly": 1.12},
		"top": "robe", "top_color": "#f6f3ec", "skirt_len": 0.55, "sleeves": "courtes",
		"apron": true, "apron_color": "#6f8fc8", "hat": "noeud_cheveux", "hat_color": "#6f8fc8", "prop_l": "baguette", "shoes": "#5a3a2a"},
	"gaudin": {"species": "humain", "fur": PEAU[2], "hair": "degarni", "hair_color": "#5a524c", "nose": "rond", "nose_red": 0.3, "build": {"belly": 1.32, "width": 1.1},
		"top": "veste", "top_color": BOUTEILLE, "top2": BLANC, "buttons": OR, "lapel": "#3a6a4e",
		"legs": "pantalon", "legs_color": CREME, "neck": "noeud", "neck_color": "#c0322e",
		"prop_r": "micro", "shoes": "#3a2418"},
	"gardien": {"species": "humain", "fur": PEAU[3], "hair": "court", "hair_color": "#8a8278", "nose": "patate", "build": {"width": 1.06, "belly": 1.12},
		"top": "veste", "top_color": "#56603c", "top2": "#d9cfb0", "lapel": "#4a5232",
		"legs": "pantalon", "legs_color": "#6a4a32", "hat": "chasse", "hat_color": "#3e4a2a", "hat_band": "#6a4a32", "feather": "#b8402e",
		"prop_r": "canne", "shoes": "#1f1a16"},
	"meunier": {"species": "humain", "fur": PEAU[0], "hair": "court", "hair_color": "#e8e2d8", "nose": "rond", "build": {"belly": 1.2, "leg": 0.95}, "face": ["moustache"], "moustache": "#e8e2d8",
		"top": "chemise", "top_color": "#3a64b0", "sleeves": "courtes",
		"legs": "pantalon", "legs_color": "#c7b48f", "apron": true, "apron_bib": true, "apron_color": "#d8c8a0", "hat": "casquette", "hat_color": "#e4ddd0", "shoes": "#3a2a20"},
	"castel": {"species": "humain", "fur": PEAU[1], "hair": "gomina", "hair_color": "#ece8e0", "nose": "busque", "build": {"leg": 1.1, "torso": 1.1, "width": 1.08},
		"top": "smoking", "top_color": "#f2eee4", "top2": BLANC, "lapel": "#e0dace",
		"legs": "pantalon", "legs_color": "#141318", "neck": "noeud", "neck_color": "#141318", "shoes": "#0e0d12"},
	"armand": {"species": "humain", "fur": PEAU[1], "hair": "gomina", "hair_color": "#16141a", "nose": "long", "build": {"leg": 1.08, "width": 0.92},
		"top": "queue_de_pie", "top_color": "#121116", "top2": "#f6f4ee", "buttons": OR,
		"legs": "pantalon", "legs_color": "#121116", "neck": "noeud", "neck_color": "#f6f4ee", "gloves": "#f6f4ee",
		"face": ["moustache"], "moustache": "#121116", "shoes": "#0e0d12"},
	"garnier": {"species": "humain", "fur": PEAU[0], "hair": "chauve", "hair_color": "#8a8278", "nose": "rond", "build": {"belly": 1.15},
		"top": "veste", "top_color": "#1b1a22", "top2": BLANC, "legs": "pantalon", "legs_color": "#1b1a22",
		"neck": "cravate", "neck_color": "#1b1a22", "face": ["lunettes"], "frame": OR, "prop_l": "mallette", "shoes": "#0e0d12"},
	"raymonde": {"species": "humain", "fur": PEAU[0], "hair": "carre", "hair_color": "#7a6a62", "nose": "retrousse", "build": {"belly": 1.06, "leg": 0.96},
		"top": "robe", "top_color": "#8a7bb8", "skirt_len": 0.62, "sleeves": "longues",
		"neck": "metre", "hat": "fleur", "hat_color": "#d06a8a", "hat_band": OR, "face": ["lunettes"], "frame": "#7a1f30",
		"shoes": "#5a1424"},
	"fradin": {"species": "humain", "fur": PEAU[2], "hair": "court", "hair_color": "#2e2622", "nose": "patate", "build": {"belly": 1.2, "width": 1.12}, "face": ["moustache"],
		"top": "veste", "top_color": BLEU_TRAVAIL, "top2": "#d9d2c0", "lapel": "#2a3e6e",
		"legs": "pantalon", "legs_color": BLEU_TRAVAIL, "hat": "casquette", "hat_color": "#2a3e6e", "prop_r": "cle", "shoes": "#2a2220"},
	"capucine": {"species": "humain", "fur": PEAU[0], "hair": "carre", "hair_color": "#1e1a1c", "nose": "retrousse", "build": {"leg": 1.08, "width": 0.9},
		"top": "robe", "top_color": "#1f6a52", "skirt_len": 0.85, "sleeves": "aucune", "gloves": "#f4f1ea",
		"neck": "collier", "hat": "cloche", "hat_color": "#174f3e", "hat_band": OR, "lip": "#a3172b", "prop_l": "sac", "bag_color": "#174f3e", "shoes": "#174f3e"},
	"chanteuse": {"species": "humain", "fur": PEAU[0], "hair": "brushing", "hair_color": "#f0dca0", "nose": "retrousse", "build": {"leg": 1.08, "width": 0.9},
		"top": "robe", "top_color": "#b01c2e", "skirt_len": 1.0, "sleeves": "aucune", "gloves": "#f4f1ea",
		"neck": "collier", "hat": "fleur", "hat_color": "#f4f1ea", "hat_band": OR, "lip": "#a3172b", "shoes": "#b01c2e"},
	"maitre-ceremonie": {"species": "humain", "fur": PEAU[1], "hair": "gomina", "hair_color": "#3a2e28", "nose": "rond",
		"build": {"leg": 1.05, "belly": 1.1}, "top": "queue_de_pie", "top_color": "#a01c28", "top2": BLANC, "buttons": OR,
		"legs": "pantalon", "legs_color": "#141318", "neck": "noeud", "neck_color": "#141318", "gloves": BLANC,
		"hat": "haut_de_forme", "hat_color": "#141318", "hat_band": "#a01c28", "prop_r": "canne", "shoes": "#0e0d12"},
	"baron-de-vasseur": {"species": "humain", "fur": PEAU[0], "hair": "raie", "hair_color": "#c8a050", "nose": "long", "build": {"leg": 1.1, "width": 0.9},
		"top": "veste", "top_color": "#5a5a64", "top2": BLANC, "lapel": "#4a4a54",
		"legs": "pantalon", "legs_color": "#3a3b44", "neck": "cravate", "neck_color": "#b8a070",
		"hat": "haut_de_forme", "hat_color": "#4a4a54", "hat_band": "#141318", "face": ["monocle", "moustache"], "moustache": "#4a3022",
		"prop_r": "canne", "shoes": "#0e0d12"},
	"baron": {"species": "humain", "fur": PEAU[0], "hair": "degarni", "hair_color": "#e8e4dc", "nose": "busque",
		"build": {"belly": 1.2, "leg": 0.95}, "top": "smoking", "top_color": "#141318", "top2": BLANC,
		"legs": "pantalon", "legs_color": "#141318", "neck": "noeud", "neck_color": "#141318",
		"hat": "haut_de_forme", "hat_color": "#141318", "hat_band": "#5a1424", "face": ["monocle", "moustache"], "moustache": "#efebe6",
		"prop_r": "canne", "shoes": "#0e0d12"},
	"le-commandant": {"species": "humain", "fur": PEAU[3], "hair": "court", "hair_color": "#d8d4cc", "nose": "rond",
		"build": {"belly": 1.15, "width": 1.05}, "top": "veste", "top_color": NUIT, "top2": BLANC, "buttons": OR,
		"legs": "pantalon", "legs_color": "#e8e2d4", "neck": "cravate", "neck_color": NUIT, "face": ["barbe", "moustache"], "moustache": "#c8c0b4", "shoes": "#141318"},
	"mme-duval": {"species": "humain", "fur": PEAU[0], "hair": "brushing", "hair_color": "#6a3a2a", "nose": "retrousse",
		"top": "robe", "top_color": "#7a5aa0", "skirt_len": 0.85, "neck": "collier",
		"lip": "#7a1f30", "prop_l": "sac", "bag_color": "#4a2a6a", "shoes": "#4a2a6a"},
	"teddy": {"species": "humain", "fur": PEAU[2], "hair": "gomina", "hair_color": "#c87a3a", "nose": "rond",
		"build": {"leg": 1.05}, "top": "veste", "top_color": "#f0ead8", "top2": "#a3172b", "lapel": "#e2dac4",
		"legs": "pantalon", "legs_color": "#16151b", "neck": "noeud", "neck_color": "#a3172b", "prop_r": "jetons", "shoes": "#f0ead8"},
	"comtesse-orlov": {"species": "humain", "fur": PEAU[0], "hair": "chignon", "hair_color": "#14121a", "nose": "busque", "build": {"leg": 1.1, "width": 0.9},
		"top": "robe", "top_color": "#16151b", "skirt_len": 1.0, "sleeves": "aucune", "gloves": "#16151b",
		"neck": "collier", "hat": "fleur", "hat_color": "#a3172b", "hat_band": "#16151b", "lip": "#a3172b", "prop_r": "cartes", "shoes": "#16151b"},
	"meuniere": {"species": "humain", "fur": PEAU[0], "hair": "chignon", "hair_color": "#9a8a78", "nose": "rond", "build": {"belly": 1.1},
		"top": "robe", "top_color": BRIQUE, "skirt_len": 0.6, "sleeves": "longues",
		"hat": "fichu", "hat_color": "#e8dcc0", "prop_r": "cartes", "shoes": "#3a2a20"},
	"gege": {"species": "humain", "fur": PEAU[2], "hair": "court", "hair_color": "#2a2420", "nose": "patate", "nose_red": 0.3, "build": {"belly": 1.25, "width": 1.08},
		"top": "pull", "top_color": "#7a1f30", "legs": "pantalon", "legs_color": "#2f4a80",
		"hat": "casquette", "hat_color": "#3a3b44", "prop_r": "jetons", "shoes": "#2a2220"},
	"ginette": {"species": "humain", "fur": PEAU[1], "hair": "permanente", "hair_color": "#a8a298", "nose": "busque", "build": {"belly": 1.1, "leg": 0.96},
		"top": "robe", "top_color": "#5f7f5a", "skirt_len": 0.62, "sleeves": "longues", "cuff": "#c8a050",
		"neck": "collier", "face": ["demi_lune"], "frame": OR, "prop_l": "sac", "bag_color": TABAC, "shoes": "#4a3426"},
	"docteur": {"species": "humain", "fur": PEAU[1], "hair": "degarni", "hair_color": "#d8d4cc", "nose": "long", "build": {"leg": 1.04, "width": 0.94},
		"top": "gilet", "top_color": "#5a5a64", "top2": BLANC,
		"legs": "pantalon", "legs_color": "#3a3b44", "neck": "noeud", "neck_color": BORDEAUX, "face": ["demi_lune", "moustache"], "moustache": "#eeeaf0", "prop_r": "cartes", "shoes": "#141318"},
}

## Qui parle → quelle fiche.
const BY_SPEAKER := {"josiane": "josiane", "dede": "dede", "lucien": "lucien", "brunet": "brunet", "ferrand": "ferrand",
	"gaudin": "gaudin", "gardien": "gardien", "meunier": "meunier", "inconnu": "inconnu", "armand": "armand", "castel": "castel",
	"garnier": "garnier", "raymonde": "raymonde", "fradin": "fradin", "ginette": "ginette"}
## Identifiants de modèle (anciens noms de fichiers ou noms de rôle) → fiche.
const BY_MODEL := {"m-brunet": "brunet", "gardien-du-bois": "gardien", "portier-salon": "armand", "m-castel": "castel",
	"maitre-garnier": "garnier", "mme-ferrand": "ferrand", "m-gaudin": "gaudin", "capucine-varenne": "capucine",
	"passelourdin-0": "garnier", "passelourdin-1": "meuniere", "passelourdin-2": "inconnu", "passelourdin-3": "gege", "passelourdin-4": "docteur", "ginette-boutin": "ginette"}

## Tenues du joueur (le fil Gestion de la ville les vend ; M. Brunet prête davantage aux clients bien habillés).
const PLAYER_OUTFITS := {
	"costume": {},
	"smoking": {"top": "smoking", "top_color": "#141318", "top2": BLANC, "lapel": "#2c2a33", "legs_color": "#141318", "neck_color": "#141318", "buttons": "#2c2a33"},
	# Les trois tenues de chez Raymonde (Biens : dimanche, trois_pieces, smoking).
	"dimanche": {"top_color": "#2a44a8", "lapel": "#22389a", "legs_color": "#2a44a8", "neck_color": BLANC},
	"trois_pieces": {"top_color": "#7d7566", "lapel": "#6a6356", "legs_color": "#7d7566", "neck": "cravate", "neck_color": BORDEAUX, "watch_chain": true},
	"canotier": {"top_color": CREME, "lapel": "#e2d8c0", "top2": BLANC, "legs_color": CREME, "neck_color": "#c0322e", "hat": "canotier", "hat_color": "#e6c66e", "hat_band": NUIT},
	"velours": {"top_color": "#5a1424", "lapel": "#6e1f30", "top2": BLANC, "legs_color": "#16151b", "neck_color": "#16151b"},
	"haut_de_forme": {"top": "queue_de_pie", "top_color": "#141318", "top2": BLANC, "legs_color": "#141318", "neck_color": BLANC, "gloves": BLANC, "hat": "haut_de_forme", "hat_color": "#141318", "hat_band": OR},
}


## La fiche du joueur dans une tenue.
## outfit : une clé de PLAYER_OUTFITS, ou la tenue portée (Biens.worn) ; « » ou inconnue = le costume bleu nuit.
static func player(outfit := "costume") -> Dictionary:
	return NAMED.joueur.merged(PLAYER_OUTFITS.get(outfit, {}), true)


## Tout ce qu'il faut pour habiller et animer un habitant : {look, idle, sit, role, fidgets}.
## id est le nom de modèle donné par la scène (« croupier-roulette », « character-male-b.glb », « m-brunet »…).
static func resolve(id: String, speaker: String, accessory: String, seed_value: int, pose: String, in_casino: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var key := ""
	if id == "joueur":
		return {"look": player(), "idle": "idle", "sit": "sit", "role": "public", "fidgets": []}
	if BY_SPEAKER.has(speaker):
		key = BY_SPEAKER[speaker]
	elif BY_MODEL.has(id):
		key = BY_MODEL[id]
	elif NAMED.has(id):
		key = id
	var out := {"idle": "idle", "sit": "sit", "role": "public", "fidgets": ["scratch", "look_watch", "shrug", "nod"]}
	if key != "":
		out.look = NAMED[key].duplicate(true)
		match key:
			"brunet", "castel", "armand", "garnier":
				out.idle = "attentive"
				out.role = "staff"
				out.fidgets = ["nod", "look_watch"]
			"josiane":
				out.fidgets = ["wave", "talk", "nod"]
			"dede":
				out.fidgets = ["shrug", "scratch", "talk"]
			"lucien":
				out.fidgets = ["look_watch", "scratch", "point"]
			"gaudin":
				out.fidgets = ["talk", "point", "wave"]
			"chanteuse":
				out.idle = "sing"
				out.fidgets = []
			"maitre-ceremonie":
				out.idle = "attentive"
				out.role = "staff"
				out.fidgets = ["bow", "point"]
		return out
	# Le personnel du casino, reconnaissable à sa tenue plus qu'à son espèce.
	var staff := _staff(id, rng)
	if not staff.is_empty():
		return staff
	if id.begins_with("diner") or id.begins_with("invite") or (in_casino and rng.randf() < 0.7):
		out.look = _soiree(rng, _is_female(id, rng), pose)
		out.sit = "sit_table" if id.begins_with("diner") else "sit"
		out.fidgets = ["talk", "nod", "drink", "look_watch"] if out.look.get("prop_r", "") == "verre" else ["talk", "nod", "look_watch", "clap"]
	else:
		out.look = _villager(rng, _is_female(id, rng), pose)
		if out.look.get("prop_r", "") == "verre":
			out.fidgets = ["drink", "talk", "nod"]
	if pose == "idle" and rng.randf() < 0.25:
		out.idle = "behind_back"
	return out


static func _is_female(id: String, rng: RandomNumberGenerator) -> bool:
	if "female" in id or id.ends_with("euse") or id.contains("euse-") or id.begins_with("invitee") or id.begins_with("mme"):
		return true
	if "male" in id or id.begins_with("parieur") or id.begins_with("invite-"):
		return false
	return rng.randf() < 0.5


## Un visage tiré au hasard : teint, coupe, couleur de cheveux, nez ; l'âge se lit aux cheveux gris.
static func _face(rng: RandomNumberGenerator, female: bool, ages := true) -> Dictionary:
	var d := {"species": "humain", "fur": _pick(rng, PEAU), "nose": _pick(rng, NEZ)}
	# Les cheveux gris restent plus foncés que la peau, sinon de loin la tête paraît chauve.
	var old := ages and rng.randf() < 0.3
	d.hair_color = _pick(rng, ["#6a6560", "#8a8278", "#a8a298"]) if old else _pick(rng, CHEVEUX.slice(0, 7))
	d.hair = _pick(rng, COUPES_F) if female else _pick(rng, COUPES_H if old else COUPES_H.slice(0, 4))
	if not female and rng.randf() < 0.25:
		d.face = [_pick(rng, ["moustache", "moustache", "favoris", "barbe"])]
	if rng.randf() < 0.2:
		d.nose_red = rng.randf_range(0.2, 0.4)
	return d


static func _pick(rng: RandomNumberGenerator, a: Array) -> Variant:
	return a[rng.randi() % a.size()]


## Un habitant du village, en habits du samedi soir.
static func _villager(rng: RandomNumberGenerator, female: bool, pose: String) -> Dictionary:
	var d := _face(rng, female)
	d.build = {"belly": rng.randf_range(0.92, 1.3), "leg": rng.randf_range(0.94, 1.06), "width": rng.randf_range(0.94, 1.08)}
	d.shoes = _pick(rng, ["#3a2418", "#1f1d24", "#5a3a2a", "#2a2224"])
	if female:
		d.top = "robe" if rng.randf() < 0.7 else "pull"
		d.top_color = _pick(rng, VILLAGE_TOPS)
		d.sleeves = _pick(rng, ["courtes", "longues"])
		d.skirt_len = rng.randf_range(0.5, 0.7)
		if d.top == "pull":
			d.skirt = true
			d.skirt_color = _pick(rng, VILLAGE_LEGS)
		if rng.randf() < 0.35:
			d.apron = true
			d.apron_bib = rng.randf() < 0.5
			d.apron_color = _pick(rng, ["#fbf8f0", "#e8d8b8", "#d98f9c"])
		d.hat = _pick(rng, ["", "", "fleur", "chignon", "fichu", "noeud_cheveux"])
		d.hat_color = _pick(rng, ["#d06a8a", "#fbf8f0", "#b8402e", "#d1a23a", "#7a5a40"])
		d.hat_band = _pick(rng, [OR, "#fbf8f0"])
		if rng.randf() < 0.4:
			d.neck = _pick(rng, ["collier", "foulard"])
			d.neck_color = _pick(rng, ["#f4f1ea", "#b8402e", "#2f5aa8"])
		d.face = []
		if rng.randf() < 0.2:
			d.face.append("lunettes")
		if rng.randf() < 0.15:
			d.prop_l = "sac"
			d.bag_color = _pick(rng, ["#7a1f30", "#3a2418", "#2e5a40"])
	else:
		d.top = _pick(rng, ["chemise", "chemise", "pull", "gilet", "mariniere", "veste"])
		d.top_color = _pick(rng, VILLAGE_TOPS) if d.top != "mariniere" else "#22305e"
		d.top2 = _pick(rng, ["#f4f1ea", "#dfe6f0", "#efe6d2"])
		d.sleeves = "courtes" if d.top == "chemise" and rng.randf() < 0.4 else "longues"
		d.legs = "pantalon"
		d.legs_color = _pick(rng, VILLAGE_LEGS)
		d.hat = _pick(rng, ["", "", "beret", "casquette", "casquette", "canotier"])
		d.hat_color = _pick(rng, ["#1f1d24", "#8b6a45", "#3a3b44", "#2f4a80"]) if d.hat != "canotier" else "#e6c66e"
		d.hat_band = _pick(rng, ["#7a1f30", "#1d2a55"])
		if rng.randf() < 0.2:
			d.neck = "foulard"
			d.neck_color = _pick(rng, ["#b8402e", "#d1a23a", "#2f5aa8"])
		if rng.randf() < 0.15:
			d.face = [_pick(rng, ["moustache", "lunettes"])]
	if pose == "sit" and rng.randf() < 0.6:
		d.prop_r = "verre"
	elif rng.randf() < 0.08:
		d.prop_l = "baguette"
	return d


## Un client du casino, en tenue de soirée.
static func _soiree(rng: RandomNumberGenerator, female: bool, pose: String) -> Dictionary:
	var d := _face(rng, female)
	d.build = {"belly": rng.randf_range(0.92, 1.25), "leg": rng.randf_range(0.98, 1.08), "width": rng.randf_range(0.94, 1.05)}
	if female:
		d.top = "robe"
		d.top_color = _pick(rng, SOIREE_WOMEN)
		d.skirt_len = rng.randf_range(0.8, 1.0)
		d.sleeves = _pick(rng, ["aucune", "aucune", "longues"])
		d.neck = "collier"
		d.hat = _pick(rng, ["chignon", "fleur", "", "noeud_cheveux"])
		d.hat_color = _pick(rng, ["#16151b", "#f4f1ea", "#a3172b", OR])
		d.hat_band = OR
		d.face = []
		d.lip = "#a3172b"
		d.shoes = d.top_color
		if rng.randf() < 0.3:
			d.gloves = _pick(rng, ["#f4f1ea", "#16151b"])
		if rng.randf() < 0.35:
			d.prop_l = "sac"
			d.bag_color = _pick(rng, [OR, "#16151b", BORDEAUX])
	else:
		d.top = _pick(rng, ["smoking", "smoking", "veste"])
		d.top_color = _pick(rng, SOIREE_MEN)
		d.top2 = BLANC
		d.legs = "pantalon"
		d.legs_color = "#16151b" if d.top_color != "#1d2a55" else "#1d2a55"
		d.neck = _pick(rng, ["noeud", "noeud", "cravate"])
		d.neck_color = _pick(rng, ["#16151b", "#16151b", BORDEAUX, OR])
		d.shoes = "#0e0d12"
		if rng.randf() < 0.15:
			d.face = [_pick(rng, ["moustache", "monocle", "lunettes"])]
	if pose == "sit" or rng.randf() < 0.3:
		d.prop_r = "verre"
	elif rng.randf() < 0.3:
		d.prop_r = "jetons"
	return d


## Le personnel du casino.
static func _staff(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var croupier := id.begins_with("croupi") or id in ["stickman", "boxman", "mlle-solange", "chef-de-partie"]
	var female := id.begins_with("croupiere") or id == "mlle-solange" or id.begins_with("hotesse") or id == "preposee-vestiaire"
	var d := _face(rng, female, false)
	d.shoes = "#0e0d12"
	var out := {"idle": "attentive", "sit": "sit", "role": "staff", "fidgets": ["nod", "look_watch"]}
	if croupier:
		d.top = "gilet"
		d.top_color = "#16151b"
		d.top2 = BLANC
		d.buttons = OR
		d.legs = "pantalon"
		d.legs_color = "#16151b"
		d.neck = "noeud"
		d.neck_color = "#16151b"
		d.badge = true
		if id.begins_with("croupiere") or id == "mlle-solange":
			d.hair = "chignon"
		if id == "mlle-solange":
			d.neck = "collier"
		if id == "chef-de-partie" or id == "boxman":
			d.top = "smoking"
			d.lapel = "#2c2a33"
		out.idle = "stand_table"
		out.role = "croupier"
		out.fidgets = ["nod", "rake"]
	elif id.begins_with("hotesse"):
		d.hair = "chignon" if id.ends_with("1") else "carre"
		d.top = "robe"
		d.top_color = BORDEAUX
		d.skirt_len = 0.6
		d.sleeves = "longues"
		d.cuff = OR
		d.buttons = OR
		d.neck = "foulard"
		d.neck_color = OR
		d.hat = "calot"
		d.hat_color = BORDEAUX
		d.hat_band = OR
		d.face = []
		d.shoes = BORDEAUX
		out.fidgets = ["nod", "wave", "bow"]
	elif id == "preposee-vestiaire":
		d.hair = "chignon"
		d.top = "robe"
		d.top_color = "#16151b"
		d.skirt_len = 0.6
		d.apron = true
		d.apron_bib = false
		d.apron_color = BLANC
		d.hat = "noeud_cheveux"
		d.hat_color = BLANC
		d.neck = "collier"
		d.face = []
	elif id == "caissier":
		d.top = "gilet"
		d.top_color = "#4a4b56"
		d.top2 = BLANC
		d.sleeves = "courtes"
		d.legs = "pantalon"
		d.legs_color = "#16151b"
		d.neck = "noeud"
		d.neck_color = BORDEAUX
		d.hat = "visiere"
		d.hat_color = "#2e8a5a"
		d.hat_band = "#1e5a3a"
		d.face = ["lunettes"]
		out.fidgets = ["nod", "look_watch", "scratch"]
	elif id.begins_with("barman"):
		d.top = "gilet"
		d.top_color = BORDEAUX
		d.top2 = BLANC
		d.buttons = OR
		d.legs = "pantalon"
		d.legs_color = "#16151b"
		d.neck = "noeud"
		d.neck_color = "#16151b"
		d.apron = true
		d.apron_bib = false
		d.apron_color = "#16151b"
		out.idle = "bar"
		out.fidgets = ["nod", "talk"]
	elif id.begins_with("pianiste"):
		d.top = "queue_de_pie"
		d.top_color = "#141318"
		d.top2 = BLANC
		d.legs = "pantalon"
		d.legs_color = "#141318"
		d.neck = "noeud"
		d.neck_color = BLANC
		out.sit = "piano"
		out.fidgets = []
	else:
		return {}
	out.look = d
	return out


## Pour l'ancien code qui fabriquait un habitant à la main (espèce, pelage, tenue, accessoire).
static func from_legacy(species: String, fur: Color, outfit: Color, accessory: String) -> Dictionary:
	if species == "renard":
		var p := player()
		p.top_color = outfit.to_html(false)
		p.legs_color = outfit.to_html(false)
		return p
	var d := {"species": "humain", "fur": PEAU[0], "hair": "court", "top": "veste", "top_color": outfit.to_html(false), "legs": "pantalon",
		"legs_color": outfit.darkened(0.3).to_html(false)}
	match accessory:
		"noeud": d.neck = "noeud"
		"cravate":
			d.neck = "cravate"
			d.neck_color = BORDEAUX
		"collier": d.neck = "collier"
		"chapeau": d.hat = "haut_de_forme"
	return d
