shader_type spatial;
render_mode unshaded;
// Ce qui luit sur la place (verre des lanternes, globe de la statue, fenêtres allumées) : la couleur par
// sommet (sRGB), un peu au-delà du blanc pour que la lueur porte.
uniform float energie = 1.6;
void fragment() {
 ALBEDO = pow(COLOR.rgb, vec3(2.2)) * energie;
}
