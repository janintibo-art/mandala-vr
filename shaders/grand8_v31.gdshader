shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform float speed = 18.0;
uniform int cine = 0;
uniform int world_index = 0;

varying vec3 wpos;
varying float wave;

vec3 palette(float t) {
	vec3 a = vec3(0.52, 0.55, 0.60);
	vec3 b = vec3(0.48, 0.45, 0.40);
	vec3 c = vec3(1.00, 1.00, 1.00);
	vec3 d = vec3(0.05, 0.28, 0.62);
	return a + b * cos(6.2831853 * (c * t + d));
}

void vertex() {
	wpos = VERTEX;
	wave = UV.x;
}

void fragment() {
	float t = TIME * (0.05 + speed * 0.003);
	float monde = float(world_index) * 0.073;
	float mode = float(cine) * 0.11;

	vec3 col = palette(wave * 0.42 + t + monde + mode);

	float pulse = 0.72 + 0.28 * sin(TIME * (1.4 + speed * 0.025) + wave * 12.0);
	float bandes = 0.64 + 0.36 * pow(0.5 + 0.5 * sin(wave * 42.0 - TIME * 4.0), 4.0);

	if (cine == 3) {
		col = mix(col, vec3(0.82, 0.22, 1.0), 0.22);
	} else if (cine == 4) {
		col = mix(col, vec3(0.08, 0.62, 1.0), 0.26);
	} else if (cine == 5) {
		col = mix(col, vec3(1.0, 0.24, 0.42), 0.18);
	}

	float energie = pulse * bandes;
	ALBEDO = col * energie * 1.85;
	ALPHA = clamp(0.52 + energie * 0.48, 0.0, 1.0);
}
