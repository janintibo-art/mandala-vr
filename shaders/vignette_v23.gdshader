shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_test_disabled, depth_draw_never;

// Bord assombri de confort : une sphere autour de la tete, noire en peripherie.
uniform float force : hint_range(0.0, 1.0) = 0.0;

varying vec3 loc;

void vertex() {
	loc = VERTEX;
}

void fragment() {
	vec3 d = normalize(loc);
	float ang = acos(clamp(-d.z, -1.0, 1.0));
	float lim = mix(1.5, 0.40, clamp(force, 0.0, 1.0));
	float a = smoothstep(lim, lim + 0.55, ang) * min(force * 1.8, 1.0);
	ALBEDO = vec3(0.0);
	ALPHA = a;
}
