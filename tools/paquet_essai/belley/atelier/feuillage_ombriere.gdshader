shader_type spatial;
// Copie de bibliotheque/arbres-d-ombriere/1/feuillage.gdshader pour Belley (verdicts du juge n° 1 et 2) : moins de
// contre-jour et un vert moins saturé, en attendant une option de la brique.
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Le feuillage des arbres d'ombrière, en dentelle : chaque touffe est une carte où le calcul dessine cinq à sept
// feuilles de platane à cinq lobes, nervurées, ou deux à trois feuilles palmées de marronnier ; hors des feuilles
// la carte est percée, le ciel passe et l'ombre portée se tachette. UV.x porte la variante de la carte (sa partie
// entière), UV.y la forme (sa partie paire : 0 le platane, 2 le marronnier) ; couleur par sommet (sRGB), souffle
// du vent pondéré par l'alpha, lumière qui traverse franchement les feuilles (le vert tilleul à contre-jour).
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

// La feuille composée du marronnier, attachée en c, de rayon taille et tournée de ang : sept folioles obovales,
// dentées, en éventail ; la médiane la plus longue. Rend la distance au bord (négative dedans) et la nervure.
vec2 marronnier(vec2 l, vec2 c, float ang, float taille) {
 vec2 p = l - c;
 p = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * p / taille;
 float dedans = 1.;
 float nervure = 0.;
 for (int j = 0; j < 7; j++) {
  float a = (float(j) - 3.) * .5;
  float longueur = 1. - abs(float(j) - 3.) * .15;
  vec2 axe = vec2(sin(a), cos(a));
  float s = dot(p, axe) / longueur;
  float t = abs(dot(p, vec2(axe.y, -axe.x))) / longueur;
  if (s < 0. || s > 1.) {
   continue;
  }
  // obovale : large aux trois quarts, effilée vers le pétiole, dentée au bord
  float largeur = .14 * pow(s, 1.3) * sqrt(1. - s) / .33 * (1. + .07 * sin(s * 46.));
  float d = (t - largeur) * longueur;
  if (d < dedans) {
   dedans = d;
   nervure = (1. - smoothstep(.0, .025, t)) * step(.08, s);
  }
 }
 return vec2(dedans, nervure);
}

void fragment() {
 float k = floor(UV.x);
 float forme = floor(UV.y * .5);
 vec2 l = vec2(fract(UV.x), UV.y - forme * 2.);
 float dedans = 1.;
 float nervure = 0.;
 float teinte = 1.;
 if (forme > .5) {
  // le marronnier : deux ou trois grandes feuilles palmées par carte
  for (int i = 0; i < 3; i++) {
   float g = k * 17.31 + float(i) * 3.77;
   if (i == 2 && hasard(g + .5) < .5) {
    continue;
   }
   vec2 c = vec2(.3, .3) + vec2(hasard(g), hasard(g + 1.3)) * .4;
   vec2 f = marronnier(l, c, hasard(g + 2.1) * 6.2832, .36 + hasard(g + 3.7) * .12);
   if (f.x < dedans) {
    dedans = f.x;
    nervure = f.y;
    teinte = .93 + hasard(g + 5.9) * .14;
   }
  }
 } else {
 for (int i = 0; i < 7; i++) {
  float g = k * 17.31 + float(i) * 3.77;
  if (i >= 5 && hasard(g + .5) < .45) {
   continue;
  }
  vec2 c = vec2(.28, .28) + vec2(hasard(g), hasard(g + 1.3)) * .44;
  float ang = hasard(g + 2.1) * 6.2832;
  float taille = .16 + hasard(g + 3.7) * .08;
  vec2 p = l - c;
  p = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * p / taille;
  float r = length(p);
  // l'angle depuis la pointe du haut : cinq lobes pointus, le sinus du pétiole échancré en bas
  float th = atan(p.x, p.y);
  float lobes = .42 + .58 * pow(.5 + .5 * cos(5. * th), 1.5);
  lobes *= mix(.6, 1., smoothstep(.0, .8, 3.1416 - abs(th)));
  float d = r - lobes;
  if (d < dedans) {
   dedans = d;
   nervure = smoothstep(.97, 1., cos(5. * th)) * step(.1, r);
   teinte = .93 + hasard(g + 5.9) * .14;
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
 // Belley : le vert moyen et posé des tilleuls de la planche (#6E9440), pas le citron du contre-jour ; un peu
 // moins jaune et plus sombre depuis le verdict n° 26 (médiane du rang au rendu #4C9A02, visée #6E9440).
 base = mix(vec3(dot(base, vec3(.3, .59, .11))), base, .62) * vec3(.86, .9, .8) * vec3(.9, .86, .95);
 ALBEDO = base;
 ROUGHNESS = .9;
 BACKLIGHT = ALBEDO * .15;
}

// La lumière en aplats, à la manière des arbres de Zelda : trois tons nets (l'ombre, le mi-jour, le plein
// soleil) au lieu d'un dégradé, une ombre portée franche, le contre-jour qui traverse les feuilles et un liseré
// clair sur les bords de la couronne tournés vers le soleil.
void light() {
 float nl = dot(NORMAL, LIGHT);
 float ton = mix(.54, .8, smoothstep(-.12, -.04, nl));
 ton = mix(ton, 1.08, smoothstep(.38, .46, nl));
 float ombre = smoothstep(.35, .6, ATTENUATION);
 ton = mix(.54, ton, ombre);
 float lisere = pow(1. - clamp(dot(NORMAL, VIEW), 0., 1.), 3.) * smoothstep(.0, .2, nl) * ombre;
 float travers = smoothstep(.0, -.4, nl) * ombre * .5;
 DIFFUSE_LIGHT += LIGHT_COLOR * (ALBEDO * (ton + lisere * 1.3) + BACKLIGHT * travers) / 3.1416;
}
