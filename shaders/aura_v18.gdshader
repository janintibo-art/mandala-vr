shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 tint : source_color = vec4(0.10, 0.78, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.72;
uniform float speed = 0.65;
uniform float show_aura = 1.0;
uniform float show_rings = 1.0;
uniform float show_sparks = 1.0;
uniform float breath = 1.0;
uniform int style = 1;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 prism(float u) {
	return 0.55 + 0.45 * cos(6.2831853 * (u + vec3(0.00, 0.33, 0.67)));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float t = TIME * speed;

	vec3 col = tint.rgb;
	if (style == 6) {
		col = prism(ang / 6.2831853 + t * 0.035);
	} else if (style == 2) {
		col = mix(tint.rgb, vec3(0.08, 0.65, 1.0), 0.5 + 0.5 * sin(ang * 2.0 + t * 0.7));
	} else if (style == 5) {
		col = mix(vec3(1.0, 0.28, 0.015), vec3(1.0, 0.88, 0.24), 0.5 + 0.5 * sin(ang * 3.0));
	}

	float e = 0.0;

	// Grand halo atmospherique autour du mandala.
	if (show_aura > 0.5) {
		float halo = exp(-pow((r - 0.70) / 0.22, 2.0));
		float centre = exp(-r * r * 2.8) * 0.08;
		float pulse = 0.88 + 0.12 * sin(t * 1.7);
		e += (halo * 0.22 + centre) * pulse;
	}

	// Trois anneaux tres fins, animes dans des sens differents.
	if (show_rings > 0.5) {
		float r1 = 0.73 + 0.012 * sin(t * 0.8);
		float r2 = 0.82 + 0.010 * sin(-t * 0.65 + 1.7);
		float r3 = 0.91 + 0.008 * sin(t * 0.52 + 3.1);
		float a1 = exp(-pow((r - r1) / 0.010, 2.0));
		float a2 = exp(-pow((r - r2) / 0.008, 2.0));
		float a3 = exp(-pow((r - r3) / 0.006, 2.0));
		float arcs = 0.58 + 0.42 * sin(ang * 9.0 - t * 1.2);
		e += (a1 * 0.22 + a2 * 0.18 + a3 * 0.13) * (0.72 + arcs * 0.28);
	}

	// Etincelles procedurales : aucune particule 3D supplementaire.
	if (show_sparks > 0.5) {
		vec2 cell = floor((p + 1.0) * 18.0);
		float h = hash21(cell);
		vec2 fp = fract((p + 1.0) * 18.0) - 0.5;
		float active = step(0.935, h);
		float rr = length(fp);
		float blink = pow(0.5 + 0.5 * sin(t * (2.0 + h * 3.0) + h * 80.0), 8.0);
		float zone = smoothstep(1.02, 0.52, r) * smoothstep(0.38, 0.58, r);
		e += active * smoothstep(0.18, 0.0, rr) * blink * zone * 0.46;
	}

	// La respiration agit comme un petit gain lumineux, en plus de l'echelle du quad.
	e *= mix(0.90, 1.10, clamp((breath - 0.92) / 0.16, 0.0, 1.0));
	e *= intensity;

	ALBEDO = col * e * 2.0;
	ALPHA = clamp(e, 0.0, 1.0);
}
