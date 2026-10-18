class_name BarreProgres
extends Control
## La barre d'un téléchargement de commune (Communes.progression), qui avance d'elle-même, jeu en
## pause compris. La bienvenue, la carte et le carnet posent la même.

var id := ""
var couleur := Color(0.35, 0.8, 0.75)


static func pour(commune: String, teinte := Color(0.35, 0.8, 0.75), largeur := 220.0) -> BarreProgres:
	var b := BarreProgres.new()
	b.id = commune
	b.couleur = teinte
	b.custom_minimum_size = Vector2(largeur, 8)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(couleur, 0.18))
	var k := Communes.progression(id)
	if k > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * k, size.y)), couleur)
	else:
		# Pas encore de taille connue : un reflet qui glisse dit que ça travaille.
		var t := fmod(Time.get_ticks_msec() / 900.0, 1.0)
		draw_rect(Rect2(Vector2(size.x * t * 0.75, 0), Vector2(size.x * 0.25, size.y)), Color(couleur, 0.6))
