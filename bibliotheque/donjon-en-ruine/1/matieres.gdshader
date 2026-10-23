shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// La matière commune de Chauvigny (adaptée de celle de Civaux, MIT) : une teinte, un « genre » qui dessine le relief de la surface en
// procédural (pierre appareillée, enduit, tuile, bois, pavé, béton strié, acier, moellon, ardoise…),
// et une découpe pour la vue de dessus (les murs entre la caméra et l'habitant s'effacent).
uniform vec4 teinte : source_color = vec4(.8,.74,.62,1.);
uniform int genre = 0;
uniform float rugosite = .88;
uniform float metal = 0.;
// Les géométries fusionnées portent leur teinte dans les sommets (en sRGB) : un seul matériau par genre.
uniform bool teinte_sommets = false;
uniform float cut_on = 0.;
uniform vec3 cut_from = vec3(0.);
uniform vec3 cut_to = vec3(0.);
varying vec3 monde;
varying vec3 normale_monde;
float h(vec2 p){vec3 p3=fract(vec3(p.xyx)*.1031);p3+=dot(p3,p3.yzx+33.33);return fract((p3.x+p3.y)*p3.z);}
float bruit(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1.,0.)),f.x),mix(h(i+vec2(0.,1.)),h(i+vec2(1.)),f.x),f.y);}
void vertex(){monde=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;normale_monde=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 if(cut_on>.5){
  vec3 ab=cut_to-cut_from;float l2=max(dot(ab,ab),1e-4);
  float t=clamp(dot(monde-cut_from,ab)/l2,0.,1.);
  vec3 proche=cut_from+ab*t;
  float d=distance(monde,proche);
  if(t<.93&&t>.02&&d<1.0&&monde.y>cut_to.y+.2){
   // Un pointillé d'écran, pour que la découpe se lise comme une transparence.
   if(mod(floor(FRAGCOORD.x*.5)+floor(FRAGCOORD.y*.5),2.)<1.) discard;
  }
 }
 vec3 n=abs(normalize(normale_monde));
 vec2 q=n.y>.7?monde.xz:(n.x>n.z?monde.zy:monde.xy);
 float grain=bruit(q*17.);
 float patine=bruit(q*.36);
 float detail=.95+grain*.05;
 vec3 teinte7=vec3(1.);
 if(genre==1){ // pierre de taille appareillée
  vec2 p=q*vec2(1.85,4.1);
  p.x+=h(vec2(floor(p.y),2.))*1.8;
  vec2 f=fract(p);float bord=min(min(f.x,1.-f.x),min(f.y,1.-f.y));
  float aa=max(fwidth(p.x),fwidth(p.y));
  float joint=1.-smoothstep(.016,.047+aa,bord);
  detail=.89+h(floor(p))*.17+patine*.045+grain*.035-joint*.11;
 }else if(genre==2){ // enduit
  detail=.92+patine*.09+grain*.035;
 }else if(genre==3){ // tuile canal
  vec2 p=q*vec2(4.2,5.8);p.x+=mod(floor(p.y),2.)*.5;
  float courbe=sin(fract(p.x)*3.14159);
  float aa=max(fwidth(p.x),fwidth(p.y));
  float rive=1.-smoothstep(.018,.075+aa,fract(p.y));
  detail=.84+h(floor(p))*.15+courbe*.08-rive*.10+grain*.03;
 }else if(genre==4){ // bois
  detail=.86+bruit(q*vec2(22.,1.2))*.17+grain*.03;
 }else if(genre==5){ // pavé
  vec2 p=monde.xz*vec2(3.1,4.);p.x+=mod(floor(p.y),2.)*.5;
  vec2 f=fract(p);float bord=min(min(f.x,1.-f.x),min(f.y,1.-f.y));
  float aa=max(fwidth(p.x),fwidth(p.y));
  detail=.87+h(floor(p))*.17-(1.-smoothstep(.012,.045+aa,bord))*.11+grain*.035;
 }else if(genre==6){ // béton de la centrale : stries verticales, coulures, bas verdi
  float strie=bruit(vec2(q.x*9.,q.y*.25))*.5+bruit(vec2(q.x*31.,q.y*.9))*.5;
  float coulure=smoothstep(.55,.9,bruit(vec2(q.x*2.1,q.y*.08)))*(1.-smoothstep(.0,.5,fract(q.y*.02)))*.5;
  float banc=1.-smoothstep(.0,.06,abs(fract(monde.y*.15)-.5)*2.-.9);
  float pied=1.-smoothstep(2.,16.,monde.y);
  detail=.90+strie*.09+patine*.04-coulure*.12-banc*.05-pied*.18*bruit(q*1.3);
  }else if(genre==7){ // moellon de calcaire (reprise 0.2 : il se lisait en brique) : des pierres inégales en
  // assises ondulées, de longueurs différentes d'une assise à l'autre, bombées, aux joints de chaux fins ;
  // une pierre sur deux tire vers le gris froid, l'autre vers l'ocre
  float ond=(bruit(vec2(q.x*.55,7.))-.5)*.7;
  float py=q.y*3.3+ond;
  float rang=floor(py);
  float lg=mix(1.3,2.7,h(vec2(rang,11.)));
  vec2 p=vec2(q.x*lg+h(vec2(rang,4.))*3.,py);
  p+=vec2(bruit(q*4.3),bruit(q*3.7+3.))*.22-.11;
  vec2 cel=floor(p);
  vec2 f=fract(p);
  float bord=min(min(f.x,1.-f.x),min(f.y,1.-f.y)*1.5);
  float aa=max(fwidth(p.x),fwidth(p.y));
  float joint=1.-smoothstep(.02,.07+aa,bord);
  float bombe=smoothstep(.0,.3,bord);
  detail=.80+h(cel+vec2(rang*.37,1.7))*.24+grain*.05+patine*.05+bombe*.04-joint*.07;
  teinte7=mix(vec3(.88,.94,1.05),vec3(1.0,.97,.91),h(cel+vec2(5.3,rang)));
 }else if(genre==8){ // acier galvanisé, zinc
  float seam=1.-smoothstep(.018,.045+fwidth(q.x)*2.,min(fract(q.x*1.8),1.-fract(q.x*1.8)));
  detail=.84+patine*.16+grain*.035-seam*.14;
 }else if(genre==9){ // ardoise
  vec2 p=q*vec2(3.4,6.5);p.x+=mod(floor(p.y),2.)*.5;
  vec2 f=fract(p);
  float aa=max(fwidth(p.x),fwidth(p.y));
  float rive=1.-smoothstep(.02,.08+aa,f.y);
  float cote=1.-smoothstep(.01,.04+aa,min(f.x,1.-f.x));
  detail=.86+h(floor(p))*.12-rive*.14-cote*.08+grain*.03;
 }else if(genre==10){ // calcaire des sarcophages : lichens, cassures, mousse au pied
  float lichen=smoothstep(.62,.82,bruit(q*2.3+vec2(7.)))*.5+smoothstep(.7,.9,bruit(q*5.1))*.3;
  float mousse=(1.-smoothstep(.0,.5,monde.y-floor(monde.y/100.)*100.))*0.;
  detail=.88+patine*.1+grain*.06-lichen*.14;
 }else if(genre==11){ // caillebotis / grille
  vec2 p=q*8.;vec2 f=fract(p);
  float aa=max(fwidth(p.x),fwidth(p.y));
  float trou=smoothstep(.18-aa,.22,min(f.x,1.-f.x))*smoothstep(.18-aa,.22,min(f.y,1.-f.y));
  detail=.6+trou*.4+grain*.03;
 }else if(genre==12){ // goudron
  detail=.9+grain*.08+patine*.04;
 }else if(genre==14){ // calcaire de ruine et de falaise : strates, lichen, érosion, pied sombre
  float strate=sin(monde.y*2.6+bruit(monde.xz*.3)*3.)*.5+.5;
  float lichen=smoothstep(.58,.8,bruit(q*1.7+vec2(5.)))*.55+smoothstep(.72,.9,bruit(q*6.3))*.25;
  float erosion=bruit(q*vec2(2.2,.7));
  detail=.86+strate*.09+patine*.05+grain*.05-lichen*.16-erosion*.06;
 }else if(genre==15){ // pierre de taille fine (chaînes, encadrements, voussoirs) : joints serrés
  vec2 p=q*vec2(2.6,5.2);
  p.x+=h(vec2(floor(p.y),9.))*1.3;
  vec2 f=fract(p);float bord=min(min(f.x,1.-f.x),min(f.y,1.-f.y));
  float aa=max(fwidth(p.x),fwidth(p.y));
  float joint=1.-smoothstep(.012,.035+aa,bord);
  detail=.93+h(floor(p))*.08+grain*.025-joint*.08;
 }else if(genre==13){ // gravier / terre battue
  vec2 c=monde.xz*7.;vec2 f=fract(c)-.5;
  float galet=1.-smoothstep(.2,.42,length(f));
  detail=.86+h(floor(c))*.1+galet*.1+grain*.04;
 }
 vec3 base=teinte.rgb;
 if(teinte_sommets){vec3 c=COLOR.rgb;base*=mix(c/12.92,pow((c+.055)/1.055,vec3(2.4)),step(vec3(.04045),c));}
 ALBEDO=base*detail*teinte7;
 ROUGHNESS=rugosite;
 METALLIC=metal;
 SPECULAR=.28;
}
