shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform float intensite = 0.5;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wd = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vue = INV_VIEW_MATRIX[3].xyz - wp;
	vec3 cote = cross(wd, vue);
	float l = length(cote);
	if (l > 0.0001) {
		cote = cote / l;
	} else {
		cote = vec3(0.0, 1.0, 0.0);
	}
	wp += cote * UV.x * UV.y;
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	float a = 1.0 - UV.x * UV.x;
	a = a * a;
	ALBEDO = COLOR.rgb * intensite * a;
}
