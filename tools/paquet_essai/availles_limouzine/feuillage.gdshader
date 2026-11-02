shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Le feuillage du jardin du 10, en dentelle, à la manière des arbres d'ombrière de Toulouse et de Lyon : chaque
// touffe est une carte où le calcul dessine ses feuilles ; hors des feuilles la carte est percée, le ciel passe et
// l'ombre portée se tachette. UV.x porte la variante de la carte (sa partie entière), UV.y la forme (sa partie
// entière) : 0 la feuille ovale et pointue (charme, tilleul, hêtre, pommier, bouleau, arbustes), 1 la feuille lobée du
// chêne, 2 les rameaux d'aiguilles en peigne (épicéa, séquoia, if, cyprès), 3 les rosettes d'aiguilles du cèdre,
// 4 les fleurs à cinq pétales et cœur d'or. Couleur par sommet (sRGB), souffle du vent pondéré par l'alpha.
uniform float souffle = .035;

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
 float coeur = 0.;
 if (forme > 1.5 && forme < 2.5) {
  // trois ou quatre rameaux : un axe brun-vert et des aiguilles serrées en peigne, de part et d'autre
  for (int i = 0; i < 4; i++) {
   float g = k * 17.31 + float(i) * 3.77;
   vec2 a = vec2(.22) + vec2(hasard(g), hasard(g + 1.3)) * .56;
   float ang = hasard(g + 2.1) * 6.2832;
   vec2 dir = vec2(cos(ang), sin(ang));
   float lg = .32 + hasard(g + 3.7) * .26;
   vec2 p = l - a;
   float t = dot(p, dir);
   float s = dot(p, vec2(-dir.y, dir.x));
   if (abs(t) > lg * .5) {
    continue;
   }
   float larg = .085 * (1. - abs(t) / (lg * .5) * .55);
   float axe = abs(s) - .007;
   float aig = (abs(s) < larg && fract(t * 60. + abs(s) * 26.) < .5) ? -.5 : 1.;
   float d = min(axe, aig);
   if (d < dedans) {
    dedans = d;
    teinte = .85 + hasard(g + 5.9) * .3;
    nervure = axe < 0. ? 1. : 0.;
   }
  }
 } else if (forme > 2.5 && forme < 3.5) {
  // les rosettes du cèdre : des bouquets d'aiguilles courtes en étoile, serrés
  for (int i = 0; i < 16; i++) {
   float g = k * 13.7 + float(i) * 5.13;
   vec2 c = vec2(.12) + vec2(hasard(g), hasard(g + 1.3)) * .76;
   float taille = .06 + hasard(g + 3.7) * .04;
   vec2 p = (l - c) / taille;
   float r = length(p);
   if (r > 1.) {
    continue;
   }
   float th = atan(p.x, p.y) + hasard(g + 2.1) * 6.2832;
   float rayon = abs(sin(th * 9.5 + r * 2.));
   float d = (rayon > .35 || r < .25) ? -.5 : 1.;
   if (d < dedans) {
    dedans = d;
    teinte = .85 + hasard(g + 5.9) * .3;
   }
  }
 } else {
  // des feuilles (ovales, lobées) ou des fleurs, cinq à sept par carte
  for (int i = 0; i < 7; i++) {
   float g = k * 17.31 + float(i) * 3.77;
   if (i >= 5 && hasard(g + .5) < .45) {
    continue;
   }
   vec2 c = vec2(.28) + vec2(hasard(g), hasard(g + 1.3)) * .44;
   float ang = hasard(g + 2.1) * 6.2832;
   float taille = (forme > 3.5 ? .12 : .16) + hasard(g + 3.7) * .07;
   vec2 p = l - c;
   p = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * p / taille;
   float r = length(p);
   float th = atan(p.x, p.y);
   float lobes;
   if (forme < .5) {
    // ovale, pointue au bout, le bord à peine denté
    lobes = .95 / length(vec2(sin(th) * 1.9, cos(th))) * (1. + .03 * sin(th * 26.));
   } else if (forme < 1.5) {
    // le chêne : une feuille allongée aux lobes arrondis
    lobes = .95 / length(vec2(sin(th) * 1.5, cos(th))) * (.72 + .28 * abs(cos(th * 4.5)));
   } else {
    // une fleur à cinq pétales
    lobes = .5 + .5 * pow(abs(cos(th * 2.5)), .7);
   }
   float d = r - lobes;
   if (d < dedans) {
    dedans = d;
    nervure = forme < 3.5 ? (1. - smoothstep(.0, .05, abs(p.x))) * step(.1, r) : 0.;
    coeur = forme > 3.5 ? 1. - step(.22, r) : 0.;
    teinte = .88 + hasard(g + 5.9) * .24;
   }
  }
 }
 if (dedans > 0.) {
  discard;
 }
 vec3 base = pow(COLOR.rgb, vec3(2.2)) * teinte;
 // le liseré sombre au bord de chaque feuille et les nervures plus claires : la dentelle se lit de près
 base *= mix(1., .8, smoothstep(-.1, 0., dedans));
 base = mix(base, base * 1.18, nervure * .5);
 base = mix(base, vec3(.85, .62, .08), coeur);
 // Le feuillage s'éclaire de lui-même un peu : la lumière du ciel qui traverse et rebondit dans la couronne, que
 // l'ombre propre des cartes éteindrait, sinon, en noir au cœur des arbres.
 ALBEDO = min(base * 1.15, vec3(1.));
 ROUGHNESS = .9;
 BACKLIGHT = ALBEDO * .8;
 EMISSION = ALBEDO * .6;
}
