class_name Cast
extends RefCounted
## Les fiches des habitants : qui est qui, de quelle espèce, habillé comment, dans quelle pose de fond.
##
## Règles de la famille (voir docs/PERSONNAGES.md) :
## - tout le monde est un petit animal à grosse tête ; seuls le joueur et l'Inconnu sont des renards ;
## - le pelage reste naturel (roux, miel, gris, crème) et ce sont les habits qui portent la couleur ;
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

const VILLAGE_TOPS := ["#2f5aa8", "#b8402e", "#d1a23a", "#2e5a40", "#7a1f30", "#efe6d2", "#4d6fa8", "#c96a3a", "#6b7d3a", "#8a7bb8", "#d98f9c", "#3d5a6e"]
const VILLAGE_LEGS := ["#2f4a80", "#6a4a32", "#55565e", "#c7b48f", "#3a3b44", "#4a5a3a"]
const SOIREE_MEN := ["#16151b", "#1d2a55", "#5a1424", "#efe6d2", "#2a3a2e", "#3a3b44"]
const SOIREE_WOMEN := ["#a3172b", "#16151b", "#1f6a52", "#24408f", "#c9a043", "#7a5aa0", "#d06a8a"]

const FURS := {
	"ours": [["#8a5a3c", "#d9b98a"], ["#c98b4a", "#f0d7a8"], ["#5e3b2a", "#b08a68"], ["#c7a27a", "#efe0c4"]],
	"lapin": [["#a8a3ad", "#efe9e4"], ["#f1ede6", "#ffffff"], ["#b98a62", "#efdcc4"], ["#d9c2a0", "#f6ecdc"]],
	"chat": [["#e0893f", "#f7e4c8"], ["#9c98a3", "#eeeaf0"], ["#efd9b5", "#fbf3e4"], ["#2e2a33", "#f2efe8"]],
	"souris": [["#b9b3ba", "#f4eee8"], ["#a88a72", "#efe2d2"], ["#efe9e2", "#ffffff"]],
	"chien": [["#d6b48a", "#f4e6d0", "#8b5e3c"], ["#8b5e3c", "#e3c8a4", "#4a3022"], ["#efe8de", "#ffffff", "#9a6a44"], ["#3a3232", "#c9905a", "#2a2222"]],
	"castor": [["#9a5b33", "#d9b08a", "#4a2f22"], ["#7a4a2a", "#c9a07a", "#3a2418"]],
	"blaireau": [["#8c8a92", "#f2f0ec", "#1f1d22"], ["#77757d", "#ecebe6", "#1a181c"]],
	"herisson": [["#b08a68", "#f0dcc0", "#4a3426"], ["#9a7a5c", "#ead6b8", "#3e2c20"]],
	"sanglier": [["#5e4434", "#8a6a55", "#2e2420"], ["#6e5040", "#9a7a62", "#33281f"]],
}
const VILLAGE_SPECIES := ["ours", "lapin", "chat", "souris", "chien", "castor", "blaireau", "herisson", "sanglier", "lapin", "chat", "ours"]

# --- Les personnages nommés ----------------------------------------------------------------------
const NAMED := {
	"joueur": {"species": "renard", "fur": "#ea7a32", "fur2": "#f6ead8", "accent": "#3a2418",
		"build": {"head": 1.04, "leg": 1.0}, "top": "veste", "top_color": NUIT, "top2": CREME, "lapel": "#27366a", "buttons": OR,
		"legs": "pantalon", "legs_color": NUIT, "neck": "noeud", "neck_color": OR, "shoes": "#3a2418"},
	"inconnu": {"species": "renard", "fur": "#a8603a", "fur2": "#ddd3c6", "accent": "#26201c", "brow": "#cfc8bd",
		"build": {"leg": 1.14, "torso": 1.12, "width": 0.96, "head": 0.94}, "top": "trench", "top_color": "#3b3a40", "top2": "#d8d2c8",
		"legs": "pantalon", "legs_color": "#25242a", "neck": "cravate", "neck_color": BORDEAUX,
		"hat": "feutre", "hat_color": "#1c1a20", "hat_band": BORDEAUX, "face": ["moustache"], "moustache": "#d8d2c8", "shoes": "#141318", "eyes": 0.9},
	"josiane": {"species": "chat", "fur": "#f1d3a8", "fur2": "#fbf1e2", "accent": "#c97a45",
		"build": {"belly": 1.18, "width": 1.05}, "top": "robe", "top_color": BRIQUE, "skirt_len": 0.6, "sleeves": "courtes",
		"apron": true, "apron_color": "#fbf8f0", "neck": "collier", "hat": "chignon", "hat_color": "#c97a45", "hat_band": "#e8c8a0",
		"face": ["cils"], "lip": "#a3172b", "shoes": "#5a1424"},
	"dede": {"species": "ours", "fur": "#8a5a3c", "fur2": "#d9b98a",
		"build": {"belly": 1.38, "width": 1.12, "leg": 0.92}, "top": "mariniere", "top_color": "#22305e", "top2": "#f2efe6",
		"legs": "pantalon", "legs_color": BLEU_TRAVAIL, "hat": "beret", "hat_color": "#1f1d24", "prop_r": "gobelet", "shoes": "#3a2a20"},
	"lucien": {"species": "lapin", "fur": "#a8a3ad", "fur2": "#efe9e4", "pink": "#eea0aa",
		"build": {"leg": 1.1, "width": 0.88, "torso": 1.05}, "top": "gilet", "top_color": MOUTARDE, "top2": "#f4f1ea", "sleeves": "courtes",
		"legs": "pantalon", "legs_color": "#6a4a32", "hat": "casquette", "hat_color": "#8b6a45", "face": ["lunettes"], "frame": "#2a2224",
		"prop_l": "carnet", "shoes": "#2a2224"},
	"brunet": {"species": "castor", "fur": "#9a5b33", "fur2": "#d9b08a", "accent": "#4a2f22",
		"build": {"belly": 1.25, "width": 1.06}, "top": "veste", "top_color": ANTHRACITE, "top2": BLANC, "lapel": "#4a4b56",
		"legs": "pantalon", "legs_color": ANTHRACITE, "neck": "cravate", "neck_color": "#9a1f30", "face": ["demi_lune"],
		"watch_chain": true, "prop_l": "mallette", "shoes": "#141318"},
	"ferrand": {"species": "souris", "fur": "#c8c2c8", "fur2": "#f4eee8", "pink": "#f0a0aa",
		"build": {"leg": 0.9, "head": 1.04, "belly": 1.1}, "top": "robe", "top_color": "#6f8fc8", "skirt_len": 0.55, "sleeves": "courtes",
		"apron": true, "apron_color": "#fbf8f0", "hat": "noeud_cheveux", "hat_color": "#fbf8f0", "face": ["cils"], "prop_l": "baguette", "shoes": "#5a3a2a"},
	"gaudin": {"species": "ours", "fur": "#c98b4a", "fur2": "#f0d7a8",
		"build": {"belly": 1.3, "width": 1.1}, "top": "veste", "top_color": BOUTEILLE, "top2": BLANC, "buttons": OR, "lapel": "#3a6a4e",
		"legs": "pantalon", "legs_color": CREME, "neck": "noeud", "neck_color": "#c0322e",
		"hat": "canotier", "hat_color": "#e6c66e", "hat_band": "#c0322e", "prop_r": "micro", "shoes": "#3a2418"},
	"gardien": {"species": "sanglier", "fur": "#5e4434", "fur2": "#8a6a55", "accent": "#2e2420", "pink": "#c98a7a",
		"build": {"width": 1.15, "belly": 1.18}, "top": "veste", "top_color": "#56603c", "top2": "#d9cfb0", "lapel": "#4a5232",
		"legs": "pantalon", "legs_color": "#6a4a32", "hat": "chasse", "hat_color": "#3e4a2a", "hat_band": "#6a4a32", "feather": "#b8402e",
		"prop_r": "canne", "shoes": "#1f1a16"},
	"meunier": {"species": "herisson", "fur": "#b08a68", "fur2": "#f0dcc0", "accent": "#4a3426",
		"build": {"belly": 1.2, "leg": 0.92}, "top": "chemise", "top_color": "#3a64b0", "sleeves": "courtes",
		"legs": "pantalon", "legs_color": "#c7b48f", "apron": true, "apron_bib": true, "apron_color": "#f6f2ea", "hat": "bonnet", "hat_color": "#f6f2ea", "shoes": "#3a2a20"},
	"castel": {"species": "ours", "fur": "#f3f1ea", "fur2": "#fbfaf6", "brow": "#b8b4aa",
		"build": {"leg": 1.15, "torso": 1.12, "width": 1.16, "head": 0.97}, "top": "smoking", "top_color": "#141318", "top2": BLANC, "lapel": "#2c2a33",
		"legs": "pantalon", "legs_color": "#141318", "neck": "noeud", "neck_color": "#141318", "shoes": "#0e0d12"},
	"armand": {"species": "chat", "fur": "#26232b", "fur2": "#f2efe8", "masque_clair": true, "brow": "#5a5560",
		"build": {"leg": 1.08, "width": 0.94}, "top": "queue_de_pie", "top_color": "#121116", "top2": "#f6f4ee", "buttons": OR,
		"legs": "pantalon", "legs_color": "#121116", "neck": "noeud", "neck_color": "#f6f4ee", "gloves": "#f6f4ee",
		"face": ["moustache"], "moustache": "#121116", "shoes": "#0e0d12"},
	"garnier": {"species": "blaireau", "fur": "#8c8a92", "fur2": "#f2f0ec", "accent": "#1f1d22",
		"build": {"belly": 1.12}, "top": "veste", "top_color": "#1b1a22", "top2": BLANC, "legs": "pantalon", "legs_color": "#1b1a22",
		"neck": "cravate", "neck_color": "#1b1a22", "face": ["lunettes"], "frame": OR, "prop_l": "mallette", "shoes": "#0e0d12"},
	"raymonde": {"species": "lapin", "fur": "#f1ede6", "fur2": "#ffffff", "pink": "#f0a0aa",
		"build": {"belly": 1.08}, "top": "robe", "top_color": "#8a7bb8", "skirt_len": 0.62, "sleeves": "longues",
		"neck": "collier", "neck_color": "#e8c8d0", "hat": "fleur", "hat_color": "#d06a8a", "hat_band": OR, "face": ["lunettes", "cils"], "frame": "#7a1f30",
		"shoes": "#5a1424"},
	"capucine": {"species": "lapin", "fur": "#b98a62", "fur2": "#efdcc4", "pink": "#eea0aa",
		"build": {"leg": 1.08, "width": 0.92}, "top": "robe", "top_color": "#1f6a52", "skirt_len": 0.85, "sleeves": "aucune", "gloves": "#f4f1ea",
		"neck": "collier", "hat": "cloche", "hat_color": "#174f3e", "hat_band": OR, "face": ["cils"], "lip": "#a3172b", "prop_l": "sac", "bag_color": "#174f3e", "shoes": "#174f3e"},
	"chanteuse": {"species": "chat", "fur": "#efd9b5", "fur2": "#fbf3e4", "accent": "#c98a5a",
		"top": "robe", "top_color": "#b01c2e", "skirt_len": 1.0, "sleeves": "aucune", "gloves": "#f4f1ea",
		"neck": "collier", "hat": "fleur", "hat_color": "#f4f1ea", "hat_band": OR, "face": ["cils"], "lip": "#a3172b", "shoes": "#b01c2e"},
	"maitre-ceremonie": {"species": "chien", "fur": "#d6b48a", "fur2": "#f4e6d0", "accent": "#8b5e3c",
		"build": {"leg": 1.05, "belly": 1.1}, "top": "queue_de_pie", "top_color": "#a01c28", "top2": BLANC, "buttons": OR,
		"legs": "pantalon", "legs_color": "#141318", "neck": "noeud", "neck_color": "#141318", "gloves": BLANC,
		"hat": "haut_de_forme", "hat_color": "#141318", "hat_band": "#a01c28", "prop_r": "canne", "shoes": "#0e0d12"},
	"baron-de-vasseur": {"species": "chien", "fur": "#8b5e3c", "fur2": "#e3c8a4", "accent": "#4a3022",
		"build": {"leg": 1.06, "width": 0.98}, "top": "veste", "top_color": "#5a5a64", "top2": BLANC, "lapel": "#4a4a54",
		"legs": "pantalon", "legs_color": "#3a3b44", "neck": "cravate", "neck_color": "#b8a070",
		"hat": "haut_de_forme", "hat_color": "#4a4a54", "hat_band": "#141318", "face": ["monocle", "moustache"], "moustache": "#4a3022",
		"prop_r": "canne", "shoes": "#0e0d12"},
	"baron": {"species": "chien", "fur": "#bdb6ae", "fur2": "#efebe6", "accent": "#7a7068", "brow": "#efebe6",
		"build": {"belly": 1.2, "leg": 0.95}, "top": "smoking", "top_color": "#141318", "top2": BLANC,
		"legs": "pantalon", "legs_color": "#141318", "neck": "noeud", "neck_color": "#141318",
		"hat": "haut_de_forme", "hat_color": "#141318", "hat_band": "#5a1424", "face": ["monocle", "moustache"], "moustache": "#efebe6",
		"prop_r": "canne", "shoes": "#0e0d12"},
	"le-commandant": {"species": "chien", "fur": "#efe8de", "fur2": "#ffffff", "accent": "#9a6a44",
		"build": {"belly": 1.15, "width": 1.05}, "top": "veste", "top_color": NUIT, "top2": BLANC, "buttons": OR,
		"legs": "pantalon", "legs_color": "#e8e2d4", "neck": "cravate", "neck_color": NUIT, "face": ["moustache"], "moustache": "#c8c0b4", "shoes": "#141318"},
	"mme-duval": {"species": "chat", "fur": "#9c98a3", "fur2": "#eeeaf0",
		"top": "robe", "top_color": "#7a5aa0", "skirt_len": 0.85, "neck": "collier", "hat": "chignon", "hat_color": "#7c7883", "hat_band": OR,
		"face": ["cils"], "lip": "#7a1f30", "prop_l": "sac", "bag_color": "#4a2a6a", "shoes": "#4a2a6a"},
	"teddy": {"species": "ours", "fur": "#c7a27a", "fur2": "#efe0c4",
		"build": {"leg": 1.05}, "top": "veste", "top_color": "#f0ead8", "top2": "#a3172b", "lapel": "#e2dac4",
		"legs": "pantalon", "legs_color": "#16151b", "neck": "noeud", "neck_color": "#a3172b", "prop_r": "jetons", "shoes": "#f0ead8"},
	"comtesse-orlov": {"species": "lapin", "fur": "#f1ede6", "fur2": "#ffffff", "pink": "#eea0aa",
		"build": {"leg": 1.1, "width": 0.9}, "top": "robe", "top_color": "#16151b", "skirt_len": 1.0, "sleeves": "aucune", "gloves": "#16151b",
		"neck": "collier", "hat": "fleur", "hat_color": "#a3172b", "hat_band": "#16151b", "face": ["cils"], "lip": "#a3172b", "prop_r": "cartes", "shoes": "#16151b"},
	"meuniere": {"species": "herisson", "fur": "#9a7a5c", "fur2": "#ead6b8", "accent": "#3e2c20",
		"build": {"belly": 1.1}, "top": "robe", "top_color": BRIQUE, "skirt_len": 0.6, "sleeves": "longues",
		"hat": "fichu", "hat_color": "#e8dcc0", "face": ["cils"], "prop_r": "cartes", "shoes": "#3a2a20"},
	"gege": {"species": "ours", "fur": "#5e3b2a", "fur2": "#b08a68",
		"build": {"belly": 1.25, "width": 1.08}, "top": "pull", "top_color": "#7a1f30", "legs": "pantalon", "legs_color": "#2f4a80",
		"hat": "casquette", "hat_color": "#3a3b44", "prop_r": "jetons", "shoes": "#2a2220"},
	"docteur": {"species": "chat", "fur": "#9c98a3", "fur2": "#eeeaf0", "brow": "#eeeaf0",
		"build": {"leg": 1.04, "width": 0.94}, "top": "gilet", "top_color": "#5a5a64", "top2": BLANC,
		"legs": "pantalon", "legs_color": "#3a3b44", "neck": "noeud", "neck_color": BORDEAUX, "face": ["demi_lune", "moustache"], "moustache": "#eeeaf0", "prop_r": "cartes", "shoes": "#141318"},
}

## Qui parle → quelle fiche.
const BY_SPEAKER := {"josiane": "josiane", "dede": "dede", "lucien": "lucien", "brunet": "brunet", "ferrand": "ferrand",
	"gaudin": "gaudin", "gardien": "gardien", "meunier": "meunier", "inconnu": "inconnu", "armand": "armand", "castel": "castel",
	"garnier": "garnier", "raymonde": "raymonde"}
## Identifiants de modèle (anciens noms de fichiers ou noms de rôle) → fiche.
const BY_MODEL := {"m-brunet": "brunet", "gardien-du-bois": "gardien", "portier-salon": "armand", "m-castel": "castel",
	"maitre-garnier": "garnier", "mme-ferrand": "ferrand", "m-gaudin": "gaudin", "capucine-varenne": "capucine",
	"passelourdin-0": "garnier", "passelourdin-1": "meuniere", "passelourdin-2": "inconnu", "passelourdin-3": "gege", "passelourdin-4": "docteur"}

## Tenues du joueur (le fil Gestion de la ville les vend ; M. Brunet prête davantage aux clients bien habillés).
const PLAYER_OUTFITS := {
	"costume": {},
	"smoking": {"top": "smoking", "top_color": "#141318", "top2": BLANC, "lapel": "#2c2a33", "legs_color": "#141318", "neck_color": "#141318", "buttons": "#2c2a33"},
	"trois_pieces": {"top_color": "#4a4b56", "lapel": "#5a5b66", "legs_color": "#4a4b56", "neck": "cravate", "neck_color": BORDEAUX, "watch_chain": true},
	"canotier": {"top_color": CREME, "lapel": "#e2d8c0", "top2": BLANC, "legs_color": CREME, "neck_color": "#c0322e", "hat": "canotier", "hat_color": "#e6c66e", "hat_band": NUIT},
	"velours": {"top_color": "#5a1424", "lapel": "#6e1f30", "top2": BLANC, "legs_color": "#16151b", "neck_color": "#16151b"},
	"haut_de_forme": {"top": "queue_de_pie", "top_color": "#141318", "top2": BLANC, "legs_color": "#141318", "neck_color": BLANC, "gloves": BLANC, "hat": "haut_de_forme", "hat_color": "#141318", "hat_band": OR},
}


## La fiche du joueur dans une tenue.
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


static func _fur(rng: RandomNumberGenerator, species: String) -> Dictionary:
	var opts: Array = FURS[species]
	var f: Array = opts[rng.randi() % opts.size()]
	var d := {"species": species, "fur": f[0], "fur2": f[1]}
	if f.size() > 2:
		d.accent = f[2]
	if species == "chat" and f[0] == "#2e2a33":
		d.masque_clair = true
	return d


static func _pick(rng: RandomNumberGenerator, a: Array) -> Variant:
	return a[rng.randi() % a.size()]


## Un habitant du village, en habits du samedi soir.
static func _villager(rng: RandomNumberGenerator, female: bool, pose: String) -> Dictionary:
	var d := _fur(rng, _pick(rng, VILLAGE_SPECIES))
	d.build = {"belly": rng.randf_range(0.92, 1.3), "leg": rng.randf_range(0.92, 1.08), "width": rng.randf_range(0.94, 1.08)}
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
		d.face = ["cils"]
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
	var d := _fur(rng, _pick(rng, VILLAGE_SPECIES))
	d.build = {"belly": rng.randf_range(0.92, 1.25), "leg": rng.randf_range(0.98, 1.1), "width": rng.randf_range(0.94, 1.05)}
	if female:
		d.top = "robe"
		d.top_color = _pick(rng, SOIREE_WOMEN)
		d.skirt_len = rng.randf_range(0.8, 1.0)
		d.sleeves = _pick(rng, ["aucune", "aucune", "longues"])
		d.neck = "collier"
		d.hat = _pick(rng, ["chignon", "fleur", "", "noeud_cheveux"])
		d.hat_color = _pick(rng, ["#16151b", "#f4f1ea", "#a3172b", OR])
		d.hat_band = OR
		d.face = ["cils"]
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
	var species: String = _pick(rng, ["chat", "lapin", "souris", "chien", "ours", "castor", "blaireau"])
	var d := _fur(rng, species)
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
			d.hat = "chignon"
			d.hat_color = Color(d.fur).darkened(0.25).to_html(false)
			d.hat_band = OR
			d.face = ["cils"]
		if id == "mlle-solange":
			d.neck = "collier"
		if id == "chef-de-partie" or id == "boxman":
			d.top = "smoking"
			d.lapel = "#2c2a33"
		out.idle = "stand_table"
		out.role = "croupier"
		out.fidgets = ["nod", "rake"]
	elif id.begins_with("hotesse"):
		d = _fur(rng, "chat") if id.ends_with("1") else _fur(rng, "lapin")
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
		d.face = ["cils"]
		d.shoes = BORDEAUX
		out.fidgets = ["nod", "wave", "bow"]
	elif id == "preposee-vestiaire":
		d = _fur(rng, "souris")
		d.top = "robe"
		d.top_color = "#16151b"
		d.skirt_len = 0.6
		d.apron = true
		d.apron_bib = false
		d.apron_color = BLANC
		d.hat = "noeud_cheveux"
		d.hat_color = BLANC
		d.neck = "collier"
		d.face = ["cils"]
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
	var sp := species if FURS.has(species) or species == "renard" else "ours"
	if sp == "renard":
		var p := player()
		p.top_color = outfit.to_html(false)
		p.legs_color = outfit.to_html(false)
		return p
	var d := {"species": sp, "fur": fur.to_html(false), "top": "veste", "top_color": outfit.to_html(false), "legs": "pantalon",
		"legs_color": outfit.darkened(0.3).to_html(false)}
	match accessory:
		"noeud": d.neck = "noeud"
		"cravate":
			d.neck = "cravate"
			d.neck_color = BORDEAUX
		"collier": d.neck = "collier"
		"chapeau": d.hat = "haut_de_forme"
	return d
