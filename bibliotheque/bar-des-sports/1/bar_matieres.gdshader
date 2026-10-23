shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 teinte : source_color = vec4(0.3, 0.13, 0.055, 1.0);
uniform int motif = 0;
uniform float rugosite = 0.65;
varying vec3 p_local;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float n(vec2 p) {
  vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
  return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);
}
void vertex() { p_local = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
  float v = 1.0;
  float r = rugosite;
  if (motif == 0) {
    // Parquet longues lames, joints décalés : la texture respecte les mètres du lieu.
    vec2 q=p_local.xz; float rang=floor(q.x/0.19); float z=q.y+mod(rang,3.0)*0.94;
    vec2 planche=vec2(rang,floor(z/2.85));
    float joint=min(min(fract(q.x/0.19),1.0-fract(q.x/0.19))*0.19,min(fract(z/2.85),1.0-fract(z/2.85))*2.85);
    float grain=mix(0.5,n(vec2(q.x*85.0+sin(q.y*0.6)*0.5,q.y*1.2)),1.0-smoothstep(0.25,0.9,fwidth(q.x*85.0)));
    float filament=sin(q.x*500.0+sin(q.y*0.45)*3.0+grain*3.5)*0.035*(1.0-smoothstep(0.7,2.5,fwidth(q.x*500.0)));
    float aa=max(0.002,fwidth(joint));
    v=(0.86+h(planche)*0.23+grain*0.14+filament)*mix(0.62,1.0,smoothstep(0.001-aa,0.0025+aa,joint));
    r=0.52+grain*0.17;
  } else if (motif == 1) {
    // Noyer des menuiseries : veinage discret, sans répétition de photos.
    float grain=mix(0.5,n(vec2(UV.x*70.0,UV.y*3.0)),1.0-smoothstep(0.3,1.0,fwidth(UV.x*70.0)));
    v=0.84+grain*0.28+sin(UV.x*260.0+grain*4.0)*0.045*(1.0-smoothstep(0.7,2.5,fwidth(UV.x*260.0)));
  } else if (motif == 2) {
    // Brique de récupération à joints fins.
    vec2 q=vec2(p_local.x+p_local.z,p_local.y); q*=vec2(2.8,8.0);
    q.x+=mod(floor(q.y),2.0)*0.5;
    vec2 cell=floor(q), f=fract(q);
    float bord=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
    v=mix(0.67,0.85+h(cell)*0.22,smoothstep(0.014,0.04,bord));
    v*=0.93+n(q*15.0)*0.12;
  } else {
    // Cuir : variation microscopique, les coutures sont de vraies géométries.
    float detail=1.0-smoothstep(0.3,1.0,length(fwidth(UV*240.0)));
    v=0.93+mix(0.5,n(UV*240.0),detail)*0.13;
    r=0.62+mix(0.5,n(UV*150.0),detail)*0.18;
  }
  ALBEDO=teinte.rgb*v;
  ROUGHNESS=r;
}
