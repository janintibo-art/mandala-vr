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
	if (l > 0.0001) {
		cote = cote / l;
	} else {
		cote = vec3(0.0, 1.0, 0.0);
	}
	float sc = length(MODEL_MATRIX[0].xyz);
	float el = 1.0 + halo * 2.0;
	wp += cote * UV.x * UV.y * el * sc;
	wpos = wp;
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	float x = abs(UV.x);
	float el = 1.0 + halo * 2.0;
	float cr = 1.0 / el;
	float noyau = 1.0 - smoothstep(cr * 0.55, cr, x);
	float bord = 1.0 - x * x;
	float lueur = bord * bord * min(halo, 1.0) * 0.55;
	float a = max(noyau, lueur);
	vec3 c = effets_couleur(COLOR.rgb, noyau, wpos);
	ALBEDO = min(c * 0.9, vec3(1.0));
	ALPHA = clamp(a * COLOR.a * 1.4, 0.0, 1.0);
}
