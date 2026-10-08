shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, fog_disabled;

uniform vec3 couleur = vec3(0.4, 0.8, 1.0);

void fragment() {
	float f = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	ALBEDO = couleur * 0.9;
	ALPHA = clamp(f * 0.85, 0.0, 1.0);
}
