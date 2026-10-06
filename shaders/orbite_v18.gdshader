shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 tint : source_color = vec4(0.10, 0.78, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.72;
uniform float pulse = 1.0;
uniform int style = 1;

// v19
uniform float reactive : hint_range(0.0, 1.0) = 0.0;
uniform float draw_flash : hint_range(0.0, 1.0) = 0.0;

vec3 prism(float u) {
	return 0.55 + 0.45 * cos(6.2831853 * (u + vec3(0.00, 0.33, 0.67)));
}

void fragment() {
	vec3 c = tint.rgb;
	if (style == 6) {
		c = prism(TIME * 0.06 + UV.x * 0.25);
	} else if (style == 3) {
		c = mix(c, vec3(1.0), 0.42);
	} else if (style == 5) {
		c = mix(c, vec3(1.0, 0.92, 0.58), 0.38);
	}

	float gain = intensity * mix(0.88, 1.12, clamp((pulse - 0.92) / 0.16, 0.0, 1.0));
	gain *= 1.0 + reactive * 0.75 + draw_flash * 0.48;
	c = mix(c, vec3(1.0), clamp(draw_flash * 0.30, 0.0, 0.30));

	ALBEDO = c * (1.25 + gain * 1.65);
	ALPHA = clamp(0.55 + gain * 0.45, 0.0, 1.0);
}
