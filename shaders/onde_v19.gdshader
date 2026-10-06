shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled;

uniform vec4 tint : source_color = vec4(0.18, 0.72, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.8;
uniform float audio : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);

	float rayon = mix(0.12, 0.88, smoothstep(0.0, 1.0, progress));
	float ep = mix(0.095, 0.025, progress);
	float ring = exp(-pow((r - rayon) / ep, 2.0));

	float centre = exp(-r * r * 18.0) * (1.0 - progress) * 0.55;
	float fade = pow(1.0 - progress, 1.35);
	float energie = (ring + centre) * fade * intensity * (1.0 + audio * 0.65);

	vec3 c = mix(tint.rgb, vec3(1.0), (1.0 - progress) * 0.35);
	ALBEDO = c * energie * 2.2;
	ALPHA = clamp(energie, 0.0, 1.0);
}
