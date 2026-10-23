shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 teinte : source_color = vec4(0.5,0.35,0.2,1.0);
uniform int motif = 0;
uniform float rugosite = 0.7;
varying vec3 lieu;
float h(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float bruit(vec2 p) {
  vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
  return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);
}
void vertex() { lieu=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
  float detail=1.0;
  if(motif==0) {
    vec2 p=lieu.xz;
    float rangee=floor(p.x/0.19);
    vec2 q=vec2(p.x/0.19,(p.y+mod(rangee,3.0)*0.47)/1.42);
    vec2 bord=min(fract(q),1.0-fract(q));
    vec2 aa=max(fwidth(q),vec2(0.001));
    float joint=1.0-min(smoothstep(0.008,0.008+aa.x,bord.x),smoothstep(0.004,0.004+aa.y,bord.y));
    detail=0.90+0.14*h(floor(q))-joint*0.12;
    float filtre=1.0-smoothstep(0.25,1.0,fwidth(p.x*95.0));
    detail+=sin(p.x*95.0+bruit(p*3.0)*4.0)*0.018*filtre;
  } else if(motif==1) {
    float onde=sin(UV.x*76.0+bruit(UV*vec2(6,3))*6.0);
    float filtre=1.0-smoothstep(0.25,1.2,fwidth(UV.x*76.0));
    detail=0.94+bruit(UV*vec2(14,2))*0.09+onde*0.025*filtre;
  } else if(motif==2) {
    vec2 q=vec2((lieu.x+lieu.z)*1.7,lieu.y*3.7);
    q.x+=mod(floor(q.y),2.0)*0.5;
    vec2 bord=min(fract(q),1.0-fract(q));
    float joint=1.0-min(smoothstep(0.013,0.025+fwidth(q.x),bord.x),smoothstep(0.012,0.024+fwidth(q.y),bord.y));
    detail=0.93+h(floor(q))*0.09-joint*0.075+bruit(lieu.xy*17.0)*0.025;
  } else if(motif==3) {
    detail=0.96+bruit(lieu.xy*3.0+lieu.z)*0.045;
  } else if(motif==4) {
    vec2 bord=min(UV,1.0-UV);
    float d=min(bord.x,bord.y);
    float filet=smoothstep(0.035,0.042,d)*(1.0-smoothstep(0.048,0.055,d));
    float bande=smoothstep(0.06,0.067,d)*(1.0-smoothstep(0.09,0.097,d));
    vec3 base=teinte.rgb*(0.94+0.06*bruit(UV*80.0));
    ALBEDO=mix(base,vec3(0.45,0.32,0.15),max(filet,bande*0.36));
  } else {
    detail=0.96+bruit(UV*75.0)*0.045;
  }
  if(motif!=4) ALBEDO=teinte.rgb*detail;
  ROUGHNESS=rugosite;
}
