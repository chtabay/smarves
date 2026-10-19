shader_type spatial;
render_mode unshaded, cull_disabled;
// Casino Minuit : le ciel nocturne de la verrière du jardin d'hiver, étoilé, la lune dans un coin.
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vec2(wpos.x, wpos.z) * 3.0;
	vec2 i = floor(p);
	vec2 f = fract(p) - 0.5;
	float h = hash(i);
	float etoile = step(0.93, h) * smoothstep(0.12, 0.0, length(f + (vec2(hash(i + 7.0), hash(i + 13.0)) - 0.5) * 0.6));
	float scint = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
	vec3 fond = mix(vec3(0.07, 0.1, 0.27), vec3(0.16, 0.24, 0.48), clamp(1.0 - (wpos.y - 10.0) / 3.0, 0.0, 1.0));
	vec2 lune = vec2(wpos.x + 34.0, wpos.z + 23.0);
	float l = smoothstep(0.75, 0.68, length(lune)) * (1.0 - smoothstep(0.66, 0.6, length(lune + vec2(0.35, -0.15))));
	float halo = 0.25 * smoothstep(3.0, 0.6, length(lune));
	ALBEDO = fond + vec3(1.0, 0.95, 0.82) * (etoile * scint + l) + vec3(1.0, 0.95, 0.84) * halo;
}
