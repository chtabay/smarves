shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Le feuillage des arbres des rives, en dentelle : chaque touffe est une carte où le calcul dessine cinq à sept
// feuilles ; hors des feuilles la carte est percée, le ciel passe et l'ombre portée se tachette. UV.x porte la
// variante de la carte (sa partie entière), UV.y la forme des feuilles (sa partie entière : 0 la feuille deltoïde
// du peuplier, pointue et dentée, 1 la feuille en lance du saule) ; couleur par sommet (sRGB), souffle du vent
// pondéré par l'alpha, lumière qui traverse les feuilles.
uniform float souffle = .06;

void vertex() {
 vec3 monde = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
 float phase = monde.x * .31 + monde.z * .23;
 float vent = sin(TIME * .8 + phase) + sin(TIME * 1.37 + phase * 1.7) * .3;
 VERTEX.x += vent * souffle * COLOR.a;
 VERTEX.z += sin(TIME * .63 + phase) * souffle * .6 * COLOR.a;
}

float hasard(float n) {
 return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
 float k = floor(UV.x);
 float forme = floor(UV.y);
 vec2 l = vec2(fract(UV.x), fract(UV.y));
 float dedans = 1.;
 float nervure = 0.;
 float teinte = 1.;
 for (int i = 0; i < 7; i++) {
  float g = k * 17.31 + float(i) * 3.77;
  if (i >= 5 && hasard(g + .5) < .45) {
   continue;
  }
  vec2 c = vec2(.28, .28) + vec2(hasard(g), hasard(g + 1.3)) * .44;
  float ang = hasard(g + 2.1) * 6.2832;
  float taille = (forme < .5 ? .15 : .19) + hasard(g + 3.7) * .07;
  vec2 p = l - c;
  p = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * p / taille;
  float r = length(p);
  float th = atan(p.x, p.y);
  float lobes;
  if (forme < .5) {
   // le peuplier : un triangle aux côtés bombés, la pointe en haut, la base large, le bord finement denté
   lobes = .5 + .5 * pow(max(cos(th), 0.), 5.) + .16 * sin(min(abs(th), 2.2) * 1.43) + .025 * sin(th * 28.);
  } else {
   // le saule : une lance étroite, pointue aux deux bouts
   lobes = .95 / length(vec2(sin(th) * 3.4, cos(th)));
  }
  float d = r - lobes;
  if (d < dedans) {
   dedans = d;
   nervure = (1. - smoothstep(.0, .05, abs(p.x))) * step(.1, r);
   teinte = .88 + hasard(g + 5.9) * .24;
  }
 }
 if (dedans > 0.) {
  discard;
 }
 vec3 base = pow(COLOR.rgb, vec3(2.2)) * teinte;
 // le liseré sombre au bord de chaque feuille et les nervures plus claires : la dentelle se lit de près
 base *= mix(1., .8, smoothstep(-.1, 0., dedans));
 base = mix(base, base * 1.18, nervure * .5);
 ALBEDO = base;
 ROUGHNESS = .9;
 BACKLIGHT = ALBEDO * .85;
}
