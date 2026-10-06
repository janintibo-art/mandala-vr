shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = wpos.xz * 0.5;
	vec2 g = abs(fract(q - 0.5) - 0.5) / max(fwidth(q), vec2(0.0001));
	float l = 1.0 - min(min(g.x, g.y), 1.0);
	float dist = length(wpos.xz - INV_VIEW_MATRIX[3].xz);
	float fade = clamp(1.0 - dist / 60.0, 0.0, 1.0);
	ALBEDO = vec3(0.18, 0.3, 0.6);
	ALPHA = l * 0.55 * fade * fade;
}
