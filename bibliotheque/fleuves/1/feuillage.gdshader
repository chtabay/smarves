shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Ce qui bouge dans les fleuves : les roseaux et les touffes au vent (couleur par sommet, souffle pondéré par
// l'alpha), et l'eau. Un sommet d'eau porte UV.y ≥ 500 (≥ 3000 quand elle dort, dans une lône). Ses motifs se
// calculent sur la place du sommet dans le monde, le long de l'axe x du module (le courant) et en travers : deux
// modules posés bout à bout se raccordent sans couture. L'eau ondule doucement, des traînées claires filent avec
// le courant, le soleil y pique des reflets.
uniform float souffle = .08;
uniform float courant = 1.1;
varying float eau;
varying vec2 lieu;

float hasard(vec2 p) {
 return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float bruit(vec2 p) {
 vec2 i = floor(p);
 vec2 f = fract(p);
 f = f * f * (3. - 2. * f);
 return mix(mix(hasard(i), hasard(i + vec2(1., 0.)), f.x), mix(hasard(i + vec2(0., 1.)), hasard(i + vec2(1., 1.)), f.x), f.y);
}

void vertex() {
 eau = UV.y >= 500. ? (UV.y >= 3000. ? 2. : 1.) : 0.;
 vec3 monde = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
 lieu = vec2(dot(monde, normalize(MODEL_MATRIX[0].xyz)), dot(monde, normalize(MODEL_MATRIX[2].xyz)));
 if (eau > .5) {
  float t = TIME * (eau > 1.5 ? .25 : 1.);
  VERTEX.y += (sin(lieu.x * .35 - t * 1.6) * .05 + sin(lieu.y * .5 + t * 1.1) * .03) * (eau > 1.5 ? .3 : 1.);
 } else {
  float phase = monde.x * .31 + monde.z * .23;
  float vent = sin(TIME * .8 + phase) + sin(TIME * 1.37 + phase * 1.7) * .3;
  VERTEX.x += vent * souffle * COLOR.a;
  VERTEX.z += sin(TIME * .63 + phase) * souffle * .6 * COLOR.a;
 }
}

void fragment() {
 vec3 base = pow(COLOR.rgb, vec3(2.2));
 if (eau > .5) {
  float dort = eau > 1.5 ? 1. : 0.;
  vec2 p = lieu;
  float file = TIME * courant * (1. - dort * .95);
  // les traînées : un bruit étiré le long du courant, qui glisse vers +x
  float tr = bruit(vec2((p.x - file * 3.) * .08, p.y * .9));
  tr = smoothstep(.72, .9, tr) * (1. - dort * .7);
  float moire = bruit(vec2((p.x - file * 1.5) * .3, p.y * .3)) * .5 + bruit(p * .9 + vec2(-file, file * .3)) * .5;
  base *= .9 + moire * .2;
  base = mix(base, base * 1.6 + vec3(.04, .05, .05), tr * .5);
  ALBEDO = base;
  ROUGHNESS = .3 + moire * .12;
  SPECULAR = .35;
  // une normale qui frémit, pour que les reflets scintillent
  vec3 n = normalize(vec3((moire - .5) * .25, 1., (bruit(p * 1.7 + file) - .5) * .25));
  NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.)).xyz);
 } else {
  ALBEDO = base;
  ROUGHNESS = .95;
  SPECULAR = 0.;
  BACKLIGHT = ALBEDO * .35;
 }
}
