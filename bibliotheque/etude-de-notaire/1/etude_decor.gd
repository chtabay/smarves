extends "res://bibliotheque/etude-de-notaire/1/menuiserie.gd"
## Menuiserie de l'étude : géométrie partagée avec le bar, palette et mobilier propres.
const ETUDE_MATIERES := preload("res://bibliotheque/etude-de-notaire/1/etude_matieres.gdshader")

func _init(parent: Node3D) -> void:
	super(parent)
	for fiche in [["parquet","ae8257",0,.74],["bois","60442e",1,.58],["chene","936e47",1,.64],
		["pierre","c5baa0",2,.94],["enduit","d5cbb5",3,.95],["cuir_vert","354c40",5,.78],
		["cuir","77534b",5,.78],["tapis","6b3934",4,.96],["sauge","6b7963",3,.86]]:
		var m:=ShaderMaterial.new()
		m.shader=ETUDE_MATIERES
		m.set_shader_parameter("teinte",Color(fiche[1]))
		m.set_shader_parameter("motif",fiche[2])
		m.set_shader_parameter("rugosite",fiche[3])
		mat[fiche[0]]=m
	for fiche in [["papier","e5d6b3"],["encre","444b49"],["cire","853d38"],["ardoise","4b5960"],
		["lin","c3b99e"],["livre_rouge","70463e"],["livre_bleu","4c5e66"],["livre_olive","606044"],
		["laiton","ae8b53"],["creme","e7d9b7"],["plafond","c6beaa"],["feuillage","546845"]]:
		var m:=StandardMaterial3D.new()
		m.albedo_color=Color(fiche[1])
		m.roughness=.78
		if fiche[0]=="laiton":
			m.metallic=.55
			m.roughness=.42
		mat[fiche[0]]=m
	var vitre:=StandardMaterial3D.new()
	vitre.albedo_color=Color("b7c7bb")
	vitre.emission_enabled=true
	vitre.emission=Color("9daea7")
	vitre.emission_energy_multiplier=.46
	vitre.roughness=.7
	mat.vitre=vitre

func _ajouter(forme: String, p: Vector3, s: Vector3, m: String, rotation: Vector3) -> void:
	var cle:=forme+":"+m
	if not lots.has(cle): lots[cle]=[]
	# Dimensions exprimées dans le repère du meuble, puis orientation dans la pièce.
	lots[cle].append(Transform3D(Basis.from_euler(rotation)*Basis.from_scale(s),p))

func piece() -> void:
	b(Vector3(0,-.10,0),Vector3(12.4,.2,11.2),"parquet")
	solide(Vector3(0,-.14,0),Vector3(12.5,.28,11.3),"SolEtude")
	for x in [-6.3,6.3]:
		b(Vector3(x,1.9,0),Vector3(.2,3.8,11.4),"enduit")
		solide(Vector3(x,1.9,0),Vector3(.2,3.8,11.4),"MurEtude")
	for z in [-5.7,5.7]:
		b(Vector3(0,1.9,z),Vector3(12.8,3.8,.2),"pierre" if z<0 else "enduit")
		solide(Vector3(0,1.9,z),Vector3(12.8,3.8,.2),"MurEtude")
	b(Vector3(0,3.88,0),Vector3(12.8,.16,11.6),"plafond")
	for x in [-6.16,6.16]:
		b(Vector3(x,.61,0),Vector3(.07,1.22,11.2),"sauge")
		for y in [.12,1.19,1.28,3.54]: b(Vector3(x,y,0),Vector3(.13,.065,11.25),"bois")
		for i in 10:
			var z: float=-5.0+i*1.10
			for yy in [.32,.98]: b(Vector3(x*.998,yy,z),Vector3(.09,.025,.86),"chene")
			for zz in [-.43,.43]: b(Vector3(x*.998,.65,z+zz),Vector3(.09,.66,.025),"chene")
	for z in [-5.57,5.57]:
		b(Vector3(0,.60,z),Vector3(12.4,1.2,.07),"sauge")
		for y in [.12,1.19,1.28,3.54]: b(Vector3(0,y,z),Vector3(12.4,.065,.13),"bois")
	for x in [-4.1,0,4.1]: b(Vector3(x,3.70,0),Vector3(.13,.20,11.3),"chene")
	for z in [-3.1,1.5]: b(Vector3(0,3.72,z),Vector3(12.4,.14,.12),"chene")
	# Une travée ajourée sépare visuellement l'accueil du cabinet sans fermer l'allée.
	for x in [-5.8,-1.5]:
		b(Vector3(x,1.8,-.35),Vector3(.22,3.6,.26),"bois")
		for y in [.12,3.28]: b(Vector3(x,y,-.35),Vector3(.31,.10,.34),"chene")
		b(Vector3(x,1.55,-.188),Vector3(.10,2.9,.018),"chene")
		solide(Vector3(x,1.8,-.35),Vector3(.24,3.6,.26),"PoteauEtude")
	b(Vector3(-3.65,3.32,-.35),Vector3(4.5,.31,.32),"bois")
	for i in 12: b(Vector3(-5.65+i*.36,3.48,-.35),Vector3(.055,.32,.14),"chene")
	# Tapis de circulation, fins et sans collision : aucune marche dans l'étude.
	b(Vector3(1.8,.012,-1.9),Vector3(5.4,.018,5.0),"tapis")
	b(Vector3(-3.8,.012,2.7),Vector3(3.9,.018,3.6),"tapis")
	fenetre(Vector3(6.11,2.15,-1.9),-PI/2)
	fenetre(Vector3(-6.11,2.15,2.2),PI/2)
	porte()

func porte() -> void:
	b(Vector3(0,1.3,5.49),Vector3(1.65,2.6,.12),"bois")
	for x in [-.88,.88]: b(Vector3(x,1.36,5.39),Vector3(.13,2.72,.20),"chene")
	b(Vector3(0,2.73,5.39),Vector3(1.94,.13,.20),"chene")
	for x in [-.39,.39]:
		b(Vector3(x,.62,5.40),Vector3(.63,.85,.05),"chene")
		b(Vector3(x,1.78,5.40),Vector3(.62,1.13,.035),"vitre")
		b(Vector3(x,1.78,5.36),Vector3(.027,1.16,.04),"bois")
		b(Vector3(x,1.78,5.36),Vector3(.65,.027,.04),"bois")
	c(Vector3(.59,1.13,5.29),.065,.12,"laiton",Vector3(PI/2,0,0))
	b(Vector3(.49,1.13,5.22),Vector3(.24,.045,.045),"laiton")
	plaque("SORTIE",Vector3(0,2.97,5.38),Vector2(1.9,.30),PI)

func fenetre(p: Vector3, angle: float) -> void:
	var r:=Vector3(0,angle,0)
	var bas:=Basis.from_euler(r)
	b(p,Vector3(2.0,2.35,.08),"bois",r)
	b(p+bas*Vector3(0,0,.05),Vector3(1.76,2.10,.035),"vitre",r)
	for x in [-.94,0,.94]: b(p+bas*Vector3(x,0,.09),Vector3(.065,2.4,.08),"creme",r)
	for y in [-1.14,0,1.14]: b(p+bas*Vector3(0,y,.09),Vector3(2.0,.065,.08),"creme",r)
	b(p+Vector3(0,-1.22,0)+bas*Vector3(0,0,.2),Vector3(2.35,.12,.54),"pierre",r)
	# Rideaux de lin plissés : des ondulations en volume, pas un panneau opaque.
	for cote in [-1.0,1.0]:
		for i in 8:
			var x: float=cote*(1.04+i*.064)
			c(p+bas*Vector3(x,-.02,.19+sin(i*1.7)*.035),.095,2.48,"lin")
		b(p+bas*Vector3(cote*1.26,-.55,.22),Vector3(.43,.055,.05),"laiton",r)
	b(p+bas*Vector3(0,1.28,.16),Vector3(3.12,.09,.12),"bois",r)

func plaque(t: String,p: Vector3,taille: Vector2,angle:=0.0) -> void:
	var r:=Vector3(0,angle,0)
	var bas:=Basis.from_euler(r)
	b(p,Vector3(taille.x+.04,taille.y+.04,.045),"bois",r)
	b(p+bas*Vector3(0,0,.026),Vector3(taille.x,taille.y,.018),"laiton",r)
	texte(t,p+bas*Vector3(0,0,.041),minf(.0018,taille.x/maxf(t.length(),1)/29.0),angle,Color("263b32"))

func bibliotheque(p: Vector3, largeur: float, hauteur:=3.1, angle:=0.0) -> void:
	var r:=Vector3(0,angle,0)
	var bas:=Basis.from_euler(r)
	b(p+bas*Vector3(0,hauteur*.5,-.18),Vector3(largeur,hauteur,.12),"bois",r)
	for x in [-largeur*.5,0,largeur*.5]: b(p+bas*Vector3(x,hauteur*.5,0),Vector3(.12,hauteur,.48),"chene",r)
	for y in [.08,.73,1.3,1.87,2.44,hauteur]: b(p+bas*Vector3(0,y,.02),Vector3(largeur+.16,.085,.54),"bois",r)
	b(p+bas*Vector3(0,hauteur+.09,.02),Vector3(largeur+.34,.11,.61),"chene",r)
	for ligne in 4:
		var y: float=.80+ligne*.57
		for i in int(largeur/.12)-2:
			var x: float=-largeur*.5+.20+i*.12
			if absf(x)<.14 or (i+ligne*3)%13==0: continue
			var haut: float=.31+float((i*7+ligne)%5)*.026
			var couleur: String=["livre_olive","livre_rouge","livre_bleu","bois"][(i+ligne)%4]
			b(p+bas*Vector3(x,y+haut*.5,.04),Vector3(.09,haut,.30),couleur,r)
			for dy in [-haut*.32,haut*.32]: b(p+bas*Vector3(x,y+haut*.5+dy,.194),Vector3(.075,.014,.007),"laiton",r)
			if i%3==0: b(p+bas*Vector3(x,y+haut*.55,.199),Vector3(.048,.09,.008),"papier",r)
	for x in [-largeur*.25,largeur*.25]:
		b(p+bas*Vector3(x,.39,.27),Vector3(largeur*.5-.15,.57,.045),"chene",r)
		b(p+bas*Vector3(x,.39,.30),Vector3(largeur*.5-.28,.40,.014),"bois",r)
		c(p+bas*Vector3(x+.17,.42,.33),.035,.07,"laiton",Vector3(PI/2,0,0))
	solide(p+Vector3(0,hauteur*.5,0),Vector3(largeur+.18,hauteur,.55) if absf(sin(angle))<.5 else Vector3(.55,hauteur,largeur+.18),"ArchivesEtude")

func bureau(p: Vector3) -> void:
	# Bureau à deux caissons et véritable vide pour les jambes.
	for x in [-1.02,1.02]:
		b(p+Vector3(x,.43,0),Vector3(.59,.80,1.10),"bois")
		b(p+Vector3(x,.07,0),Vector3(.67,.10,1.18),"chene")
		for y in [.25,.48,.71]:
			b(p+Vector3(x,y,.565),Vector3(.50,.185,.035),"chene")
			b(p+Vector3(x,y,.589),Vector3(.40,.12,.018),"bois")
			b(p+Vector3(x,y+.01,.615),Vector3(.15,.022,.026),"laiton")
		b(p+Vector3(x,.49,.59),Vector3(.04,.02,.015),"laiton")
		for xx in [-.28,.28]: b(p+Vector3(x+xx,.45,.57),Vector3(.035,.69,.03),"chene")
		for z in [-.57,.57]: b(p+Vector3(x,.82,z),Vector3(.64,.04,.055),"laiton")
	doux(p+Vector3(0,.92,0),Vector3(3.0,.15,1.40),"chene")
	b(p+Vector3(0,.855,0),Vector3(3.06,.04,1.43),"bois")
	b(p+Vector3(0,1.007,.02),Vector3(1.53,.019,.95),"cuir_vert")
	for x in [-.76,.76]: b(p+Vector3(x,1.019,.02),Vector3(.012,.006,.96),"laiton")
	livre_ouvert(p+Vector3(.12,1.035,.14),1.0)
	lampe_banquier(p+Vector3(-1.02,1.01,-.23))
	dossiers(p+Vector3(1.04,1.01,-.1),3)
	c(p+Vector3(.78,1.055,.40),.095,.055,"bois")
	c(p+Vector3(.78,1.12,.40),.045,.09,"bois",Vector3.ZERO,true)
	c(p+Vector3(.78,1.179,.40),.06,.035,"laiton")
	c(p+Vector3(.57,1.034,.45),.085,.008,"cire")
	b(p+Vector3(-.51,1.043,.36),Vector3(.012,.014,.25),"encre",Vector3(0,-.3,0))
	c(p+Vector3(-.63,1.07,.29),.095,.10,"encre")
	# La plaque du bureau reste muette : le socle y écrit le nom du notaire (ancre « Plaque »).
	plaque("",p+Vector3(0,1.13,.60),Vector2(.75,.18))
	solide(p+Vector3(0,.48,0),Vector3(3.0,.96,1.4),"BureauNotaire")

func livre_ouvert(p: Vector3,taille: float) -> void:
	b(p,Vector3(.68,.045,.46)*taille,"bois")
	for cote in [-1.0,1.0]:
		b(p+Vector3(cote*.168,.028,0)*taille,Vector3(.325,.026,.43)*taille,"papier",Vector3(0,0,cote*.025))
		for i in 7:
			b(p+Vector3(cote*.17,.047,-.145+i*.044)*taille,Vector3((.20 if i%3==0 else .245)*taille,.002,.003*taille),"encre")
	b(p+Vector3(.04,.051,.03)*taille,Vector3(.018,.004,.47)*taille,"cire")

func dossiers(p: Vector3,n: int) -> void:
	for i in n:
		var r:=Vector3(0,(i%3-1)*.09,0)
		b(p+Vector3(0,.025+i*.055,0),Vector3(.40,.048,.28),"papier",r)
		b(p+Vector3(0,.05+i*.055,0),Vector3(.43,.012,.30),"livre_olive" if i%2==0 else "livre_rouge",r)
		b(p+Vector3(.11,.058+i*.055,0),Vector3(.012,.004,.31),"lin",r)

func lampe_banquier(p: Vector3) -> void:
	c(p+Vector3(0,.035,0),.32,.065,"laiton")
	c(p+Vector3(0,.20,0),.028,.32,"laiton")
	b(p+Vector3(0,.35,.08),Vector3(.27,.025,.025),"laiton")
	doux(p+Vector3(0,.43,.12),Vector3(.45,.19,.27),"cuir_vert")
	b(p+Vector3(0,.328,.12),Vector3(.37,.015,.21),"led")
	# Spot posé directement dans le repère de l'étude, sans helper global/local ambigu.
	var l:=SpotLight3D.new()
	l.position=p+Vector3(0,.34,.12)
	l.rotation_degrees=Vector3(-90,0,0)
	l.light_color=Color("ffe4a4")
	l.light_energy=1.6
	l.spot_range=2.6
	l.spot_angle=66
	l.spot_attenuation=1.3
	racine.add_child(l)

func accueil() -> void:
	var p:=Vector3(-3.75,0,2.1)
	b(p+Vector3(0,.48,0),Vector3(2.45,.96,.72),"sauge")
	for x in [-1.12,0,1.12]: b(p+Vector3(x,.5,.38),Vector3(.055,.84,.035),"chene")
	for y in [.12,.89]: b(p+Vector3(0,y,.39),Vector3(2.33,.04,.03),"chene")
	doux(p+Vector3(0,1.0,0),Vector3(2.62,.11,.9),"chene")
	b(p+Vector3(0,1.06,0),Vector3(1.1,.016,.63),"cuir_vert")
	livre_ouvert(p+Vector3(.20,1.09,.06),.93)
	dossiers(p+Vector3(-.83,1.065,-.03),2)
	plaque("LE REGISTRE",p+Vector3(0,.62,.42),Vector2(1.58,.21))
	solide(p+Vector3(0,.53,0),Vector3(2.63,1.06,.91),"ComptoirEtude")
	b(Vector3(-3.75,.48,.77),Vector3(2.6,.96,.48),"bois")
	b(Vector3(-3.75,1.0,.77),Vector3(2.7,.09,.54),"chene")
	for x in [-4.58,-3.75,-2.92]:
		dossiers(Vector3(x,1.065,.77),2)
		b(Vector3(x,.5,1.03),Vector3(.68,.68,.03),"chene")
		c(Vector3(x,.59,1.07),.036,.05,"laiton",Vector3(PI/2,0,0))

func fauteuil_etude(p: Vector3,angle: float,haut:=false) -> void:
	var r:=Vector3(0,angle,0)
	var bas:=Basis.from_euler(r)
	for x in [-.28,.28]:
		for z in [-.25,.25]: c(p+bas*Vector3(x,.22,z),.055,.44,"bois")
	doux(p+Vector3(0,.48,0),Vector3(.72,.17,.69),"cuir_vert",r)
	doux(p+bas*Vector3(0,.92 if haut else .85,-.30),Vector3(.70,.88 if haut else .63,.13),"cuir_vert",r)
	for x in [-.36,.36]:
		b(p+bas*Vector3(x,.56,.10),Vector3(.045,.45,.045),"bois",r)
		doux(p+bas*Vector3(x,.75,0),Vector3(.09,.08,.66),"chene",r)
	for x in [-.22,0,.22]:
		for y in [.82,1.03] if haut else [.79]: c(p+bas*Vector3(x,y,-.223),.021,.013,"laiton",Vector3(PI/2,0,0))
	solide(p+Vector3(0,.57,0),Vector3(.80,1.14,.77),"FauteuilEtude")

## Le cadre du plan, contre le mur du fond : le socle y dessine le registre de la commune (ancre « Plan »).
func carte_registre() -> void:
	var p:=Vector3(-3.55,2.15,-5.38)
	b(p,Vector3(3.85,2.25,.14),"bois")
	b(p+Vector3(0,0,.077),Vector3(3.59,1.99,.025),"papier")
	for x in [-1.85,1.85]: b(p+Vector3(x,0,.09),Vector3(.045,2.13,.04),"laiton")
	for y in [-1.07,1.07]: b(p+Vector3(0,y,.09),Vector3(3.70,.045,.04),"laiton")
	texte("LES ADRESSES DU REGISTRE",p+Vector3(0,-.87,.11),.0011,0,Color("665b43"))

func plante(p: Vector3,hauteur:=.8) -> void:
	c(p+Vector3(0,.18,0),.38,.36,"pierre",Vector3.ZERO,true)
	c(p+Vector3(0,.36,0),.36,.035,"bois")
	for i in 9:
		var a: float=i*TAU/9
		var mesh:=SphereMesh.new()
		mesh.radius=.11
		mesh.height=.22
		mesh.radial_segments=8
		mesh.rings=4
		var n:=MeshInstance3D.new()
		n.mesh=mesh
		n.material_override=mat.feuillage
		n.position=p+Vector3(cos(a)*.18,.48+float(i%3)*hauteur*.23,sin(a)*.18)
		n.scale=Vector3(.55,hauteur*2.4,1.0)
		n.rotation=Vector3(.3*cos(a),-a,.4*sin(a))
		racine.add_child(n)

func suspension(p: Vector3,rayon:=.42,fil:=.6) -> void:
	c(p+Vector3(0,fil*.5+.1,0),.018,fil,"laiton")
	c(p,rayon*2,.35,"lin",Vector3.ZERO,true)
	c(p+Vector3(0,-.18,0),rayon*2.03,.025,"laiton")
	c(p+Vector3(0,-.196,0),rayon*1.84,.013,"led")
	for i in 12:
		var a: float=i*TAU/12
		b(p+Vector3(cos(a)*rayon*.8,.01,sin(a)*rayon*.8),Vector3(.013,.32,.013),"laiton")
