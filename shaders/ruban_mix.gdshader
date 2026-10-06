shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;
#include "res://shaders/effets.gdshaderinc"

varying vec3 wpos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wd = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (dome > 0.001) {
		vec3 rel = wp - MODEL_MATRIX[3].xyz;
		vec3 pd = dome_map(rel);
		vec3 dd = normalize(dome_map(rel + wd * 0.05) - pd);
		wp = mix(wp, pd, dome);
		wd = normalize(mix(wd, dd, dome));
	}
	vec3 vue = INV_VIEW_MATRIX[3].xyz - wp;
	vec3 cote = cross(wd, vue);
	float l = length(cote);
	cote = l > 0.0001 ? cote / l : vec3(0.0, 1.0, 0.0);
	float sc = length(MODEL_MATRIX[0].xyz);
	float el = 1.0 + halo * 2.15;
	wp += cote * UV.x * UV.y * el * sc;
	wpos = wp;
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	float x = abs(UV.x);
	float el = 1.0 + halo * 2.15;
	float cr = 1.0 / el;
	float aa = max(fwidth(x) * (1.45 / max(v12_finesse, 0.55)), 0.0015);
	float noyau = 1.0 - smoothstep(cr * 0.52 - aa, cr + aa, x);
	float doux = 1.0 - smoothstep(0.48 - aa, 1.0, x);
	float lueur = doux * doux * min(halo, 1.0) * (0.40 + v12_profondeur * 0.18);
	float a = max(noyau, lueur);
	vec3 c = effets_couleur(COLOR.rgb, noyau, wpos);
	c *= 0.88 + noyau * v12_brillance * 0.16;
	ALBEDO = min(c, vec3(1.35));
	ALPHA = clamp(a * COLOR.a * 1.38, 0.0, 1.0);
}
