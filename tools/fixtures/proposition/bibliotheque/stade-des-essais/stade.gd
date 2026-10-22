extends Node3D
## Le plus petit décor de stade qui tienne le contrat d'ancres (scripts/socle/ancres.gd) : une dalle, et
## les ancres requises. Proposé à la bibliothèque par la commune d'essai des propositions.

const ANCRES := {
	"Pelouse": [Vector3.ZERO, 0.0], "Arrivee": [Vector3(-24, 0, 0), PI / 2.0], "Sortie": [Vector3(-26, 0, 0), PI / 2.0],
	"Tableau": [Vector3(0, 4, 17), PI], "President": [Vector3(6, 0, -16), 0.0], "Bureau": [Vector3(-6, 0, -16), 0.0],
	"Panneau": [Vector3(-22, 0, -4), PI / 2.0],
}


func _ready() -> void:
	var dalle := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(60, 0.2, 44)
	dalle.mesh = b
	dalle.position.y = -0.12
	add_child(dalle)
	for nom in ANCRES:
		var m := Marker3D.new()
		m.name = nom
		m.position = ANCRES[nom][0]
		m.rotation.y = ANCRES[nom][1]
		add_child(m)
