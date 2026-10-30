shader_type spatial;
// Le matériau « dur » des briques de la bibliothèque (couleur par sommet, rugosité 0,88, diffusion de Burley),
// repris pour Belley avec une saturation sélective (verdict n° 24 : 76 contre 90 sur la planche) : les teintes
// franches (tuiles, volets, portes, fleurs) gagnent en saturation, les enduits et les pierres, peu chromatiques,
// restent sourds.
render_mode diffuse_burley;
uniform float gain = 1.0;

void fragment() {
 vec3 c = COLOR.rgb;
 float hi = max(c.r, max(c.g, c.b));
 float lo = min(c.r, min(c.g, c.b));
 float poids = smoothstep(.36, .5, hi - lo);
 float l = dot(c, vec3(.299, .587, .114));
 c = clamp(mix(c, l + (c - l) * gain, poids), 0., 1.);
 // Comme le matériau de la brique au rendu de compatibilité, mesuré : la couleur par sommet telle quelle.
 ALBEDO = c;
 ROUGHNESS = .88;
}
