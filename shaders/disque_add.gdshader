shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;
#include "res://shaders/effets.gdshaderinc"

varying vec3 wpos;

void vertex() {
	vec3 wc = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wpos = wc;
	float sc = length(MODEL_MATRIX[0].xyz);
	float el = 1.0 + halo * 1.5;
	vec3 vc = (VIEW_MATRIX * vec4(wc, 1.0)).xyz;
	vc.xy += UV * UV2.x * el * sc;
	VERTEX = vc;
}

void fragment() {
	float r = length(UV);
	if (r > 1.0) {
		discard;
	}
	float el = 1.0 + halo * 1.5;
	float cr = 1.0 / el;
	float noyau = 1.0 - smoothstep(cr * 0.6, cr, r);
	float bord = 1.0 - r;
	float lueur = bord * bord * min(halo, 1.0) * 0.7;
	float a = max(noyau, lueur);
	vec3 c = effets_couleur(COLOR.rgb, noyau, wpos);
	ALBEDO = c * gain_eff() * a * COLOR.a;
}
