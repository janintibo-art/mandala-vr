shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;
#include "res://shaders/effets.gdshaderinc"

varying vec3 wpos;

void vertex() {
	vec3 wc = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (dome > 0.001) {
		wc = mix(wc, dome_map(wc - MODEL_MATRIX[3].xyz), dome);
	}
	wpos = wc;
	float sc = length(MODEL_MATRIX[0].xyz);
	float el = 1.0 + halo * 1.65;
	vec3 vc = (VIEW_MATRIX * vec4(wc, 1.0)).xyz;
	vc.xy += UV * UV2.x * el * sc;
	VERTEX = vc;
}

void fragment() {
	float r = length(UV);
	float aa = max(fwidth(r) * (1.5 / max(v12_finesse, 0.55)), 0.0015);
	if (r > 1.0 + aa) {
		discard;
	}
	float el = 1.0 + halo * 1.65;
	float cr = 1.0 / el;
	float noyau = 1.0 - smoothstep(cr * 0.56 - aa, cr + aa, r);
	float doux = 1.0 - smoothstep(0.30, 1.0 + aa, r);
	float lueur = doux * doux * min(halo, 1.0) * (0.50 + v12_profondeur * 0.20);
	float a = max(noyau, lueur);
	vec3 c = effets_couleur(COLOR.rgb, noyau, wpos);
	c *= 0.88 + noyau * v12_brillance * 0.18;
	ALBEDO = min(c, vec3(1.35));
	ALPHA = clamp(a * COLOR.a * 1.38, 0.0, 1.0);
}
