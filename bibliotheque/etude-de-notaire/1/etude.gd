extends Node3D
## L'étude de notaire de Cloué (1.6.2, MIT : voir LICENCE.txt), sans Cloué : une étude de 12,4 × 11,2 m, son
## accueil et son registre, le cabinet du notaire derrière une travée ajourée, la bibliothèque des archives,
## le cabinet à plans et le cadre du plan, le salon d'attente sous la fenêtre. Un clerc tient l'accueil et un
## client attend. Le socle branche le reste par les ancres de l'étude (Ancres.ETUDE) : le notaire à son
## bureau (Notaire, assis), le registre de l'accueil (Registre), l'enseigne, la plaque du bureau, le plan
## du registre de la commune, l'arrivée et la sortie. Une commune la nomme dans « notaire.modele ».

const DECOR := preload("res://bibliotheque/etude-de-notaire/1/etude_decor.gd")
const CRITTER := preload("res://scripts/critter.gd")
const PEOPLE_SCALE := 2.6

var atelier: RefCounted
var _clerc: Node3D
var _visiteur: Node3D
var _temps_geste := 0.0


func _ready() -> void:
	atelier = DECOR.new(self)
	_lumiere_etude()
	atelier.piece()
	atelier.accueil()
	atelier.carte_registre()
	_mobilier()
	_personnages()
	atelier.achever()
	_ancres()


func _ancre(nom: String, p: Vector3, angle := 0.0, metas := {}) -> Marker3D:
	var m := Marker3D.new()
	m.name = nom
	m.position = p
	m.rotation.y = angle
	for k in metas:
		m.set_meta(k, metas[k])
	add_child(m)
	return m


## Les ancres du contrat de l'étude : leur +Z regarde le visiteur.
func _ancres() -> void:
	_ancre("Arrivee", Vector3(0, 0.06, 4.15), PI)
	_ancre("Sortie", Vector3(0, 0, 5.17), PI)
	# Le notaire dans son fauteuil, derrière le bureau.
	_ancre("Notaire", Vector3(2.1, 0, -4.02), 0.0, {"assis": true})
	# L'accueil du clerc, où le registre est ouvert.
	_ancre("Registre", Vector3(-3.75, 0, 2.1))
	_ancre("Enseigne", Vector3(2.8, 3.39, -5.43), 0.0, {"hauteur": 0.2, "largeur": 3.1, "couleur": Color("263b32")})
	_ancre("Plaque", Vector3(2.1, 1.13, -1.995), 0.0, {"hauteur": 0.11, "largeur": 0.7, "couleur": Color("263b32")})
	_ancre("Plan", Vector3(-3.55, 2.15, -5.29))


func _lumiere_etude() -> void:
	var world := WorldEnvironment.new()
	world.name = "LumiereEtude"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("575c56")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c6c6b7")
	env.ambient_light_energy = .43
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	atelier.lumiere(Vector3(4.9, 2.5, -1.8), 1.55, 6.8, Color("d7e4d5"))
	atelier.lumiere(Vector3(-4.9, 2.5, 2.2), 1.25, 5.5, Color("e4ddc1"))
	# Le diffuseur éclaire le bureau vers le bas ; les fenêtres assurent le remplissage.
	var suspension_bureau := SpotLight3D.new()
	suspension_bureau.name = "LumiereSousSuspensionBureau"
	suspension_bureau.position = Vector3(1.8, 2.55, -2.3)
	suspension_bureau.rotation.x = -PI / 2
	suspension_bureau.light_color = Color("ffe0ae")
	suspension_bureau.light_energy = 1.15
	suspension_bureau.spot_range = 5.7
	suspension_bureau.spot_angle = 74.0
	suspension_bureau.spot_attenuation = 1.65
	suspension_bureau.light_size = .16
	suspension_bureau.shadow_blur = 1.5
	suspension_bureau.shadow_enabled = true
	add_child(suspension_bureau)
	atelier.lumiere(Vector3(-3.7, 2.85, 2.0), 1.1, 4.5, Color("ffe2b6"))
	atelier.lumiere(Vector3(-3.4, 2.8, -3.4), .95, 4.1, Color("ffe2b6"))
	atelier.lumiere(Vector3(3.6, 2.65, 3.3), .75, 3.8, Color("e3d9bd"))
	atelier.suspension(Vector3(1.8, 3.02, -2.3), .44, .53)
	atelier.suspension(Vector3(-3.7, 3.02, 2.0), .35, .53)
	atelier.suspension(Vector3(-3.4, 3.02, -3.4), .30, .53)


func _mobilier() -> void:
	atelier.bibliotheque(Vector3(-5.80,0,-2.65),3.85,3.04,PI/2)
	atelier.bibliotheque(Vector3(2.95,0,-5.29),4.85,3.07)
	atelier.bureau(Vector3(2.1,0,-2.65))
	atelier.fauteuil_etude(Vector3(2.1,0,-4.02),0,true)
	atelier.fauteuil_etude(Vector3(.85,0,-.95),PI)
	atelier.fauteuil_etude(Vector3(3.35,0,-.95),PI)
	# Salon d'attente orienté vers le centre et posé dans la lumière de la fenêtre.
	atelier.fauteuil_etude(Vector3(5.14,0,2.0),-PI/2)
	atelier.fauteuil_etude(Vector3(5.14,0,3.55),-PI/2)
	atelier.doux(Vector3(4.05,.49,2.78),Vector3(.92,.08,1.05),"chene")
	for x in [-.32,.32]:
		for z in [-.38,.38]: atelier.c(Vector3(4.05+x,.24,2.78+z),.04,.48,"bois")
	atelier.solide(Vector3(4.05,.25,2.78),Vector3(.94,.50,1.07),"GueridonAttente")
	atelier.dossiers(Vector3(4.05,.54,2.78),1)
	atelier.plante(Vector3(5.18,0,4.70),1.0)
	atelier.plante(Vector3(-5.45,0,-4.8),.9)
	# Cabinet à plans sous la carte : tiroirs larges, étiquettes et poignées de laiton.
	atelier.b(Vector3(-3.55,.52,-4.94),Vector3(3.7,1.04,.90),"bois")
	atelier.doux(Vector3(-3.55,1.09,-4.94),Vector3(3.86,.13,1.0),"chene")
	for i in 5:
		var y: float=.20+i*.174
		atelier.b(Vector3(-3.55,y,-4.47),Vector3(3.48,.137,.033),"chene")
		for x in [-4.55,-2.55]: atelier.b(Vector3(x,y,-4.43),Vector3(.22,.027,.045),"laiton")
		atelier.b(Vector3(-3.55,y,-4.44),Vector3(.38,.075,.018),"laiton")
		atelier.b(Vector3(-3.55,y,-4.425),Vector3(.30,.05,.007),"papier")
	atelier.solide(Vector3(-3.55,.56,-4.94),Vector3(3.86,1.12,1.0),"CabinetPlans")
	atelier.dossiers(Vector3(-4.7,1.16,-4.82),3)
	# Table de lecture basse et tapis dans l'alcôve des archives.
	atelier.b(Vector3(-3.4,.014,-2.5),Vector3(3.3,.018,2.6),"tapis")
	atelier.doux(Vector3(-3.4,.78,-2.5),Vector3(1.65,.10,.95),"chene")
	for x in [-.64,.64]:
		for z in [-.31,.31]: atelier.c(Vector3(-3.4+x,.39,-2.5+z),.065,.78,"bois")
	atelier.livre_ouvert(Vector3(-3.4,.85,-2.5),1.0)
	atelier.solide(Vector3(-3.4,.41,-2.5),Vector3(1.7,.82,1.0),"TableLecture")
	atelier.fauteuil_etude(Vector3(-3.4,0,-1.45),PI)
	# L'enseigne reste muette : le socle y écrit le nom de l'étude (ancre « Enseigne »).
	atelier.plaque("",Vector3(2.8,3.39,-5.48),Vector2(3.28,.27))
	atelier.plaque("ACCUEIL",Vector3(-3.75,3.32,-.16),Vector2(1.05,.24))
	atelier.plaque("ARCHIVES",Vector3(-5.51,3.14,-2.65),Vector2(1.72,.20),PI/2)


## Le clerc derrière l'accueil et un client qui attend au salon : des figurants, sans rôle.
func _personnages() -> void:
	_clerc=_personne(428,Vector3(-3.75,0,1.28),0,false,"bar","#aa9d7f")
	_visiteur=_personne(429,Vector3(5.14,0,3.55),-PI/2,true,"sit","#6c655c")

func _personne(graine: int,p: Vector3,angle: float,assis: bool,repos: String,couleur: String) -> Node3D:
	var f:=CRITTER.new()
	f.randomize_look(graine)
	f.look=f.look.duplicate(true)
	f.look.top_color=couleur
	f.look.legs_color="#45433e"
	f.look.hat=""
	f.look.apron=false
	f.scale=Vector3.ONE*PEOPLE_SCALE
	f.idle_anim=repos
	f.sit_anim=repos
	f.position=p
	f.rotation.y=angle
	add_child(f)
	if assis:
		f.pose=2
		f.position.y=.53-float(f.get("_seat"))*PEOPLE_SCALE+.04
	return f

func _process(delta: float) -> void:
	_temps_geste+=delta
	if _temps_geste>14.0:
		_temps_geste=0.0
		_clerc.gesture("look_watch")
		_visiteur.gesture("scratch")
