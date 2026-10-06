shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform int style = 1;
uniform float intensity : hint_range(0.0, 1.0) = 0.78;
uniform vec4 tint : source_color = vec4(0.18, 0.72, 1.0, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 prism(float u) {
	return 0.55 + 0.45 * cos(6.2831853 * (u + vec3(0.00, 0.33, 0.67)));
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv - vec2(0.5);
	p.x *= 1.45;
	float r = length(p);
	float clear = clamp(progress, 0.0, 1.0);

	vec3 col = tint.rgb;
	float a = 0.0;

	if (style == 1) {
		// Fondu colore : opaque a 0, transparent a 1.
		a = pow(1.0 - clear, 1.35) * intensity;
		col = mix(vec3(0.01, 0.015, 0.035), tint.rgb, 0.30);

	} else if (style == 2) {
		// Flash doux : lumineux au debut puis disparition rapide.
		float f = pow(1.0 - clear, 2.2);
		a = f * intensity * 0.92;
		col = mix(tint.rgb, vec3(1.0), 0.72 + 0.20 * f);

	} else if (style == 3) {
		// Portail : revelation circulaire du centre vers l'exterieur.
		float rayon = mix(0.02, 1.08, smoothstep(0.0, 1.0, clear));
		float soft = 0.045;
		float dehors = smoothstep(rayon - soft, rayon + soft, r);
		float anneau = exp(-pow((r - rayon) / 0.040, 2.0));
		float pulse = 0.72 + 0.28 * sin(TIME * 7.0);
		a = clamp(dehors * 0.86 + anneau * 0.75 * pulse, 0.0, 1.0) * intensity;
		col = mix(vec3(0.01, 0.02, 0.05), tint.rgb * 1.35, clamp(anneau * 1.6, 0.0, 1.0));

	} else if (style == 4) {
		// Dissolution : les cellules lumineuses disparaissent progressivement.
		float n = noise2(uv * 18.0 + vec2(TIME * 0.08, -TIME * 0.05));
		float seuil = clear * 1.20 - 0.10;
		float cellule = 1.0 - smoothstep(seuil - 0.08, seuil + 0.08, n);
		float edge = 1.0 - smoothstep(0.02, 0.11, abs(n - seuil));
		a = clamp(cellule * 0.76 + edge * 0.42, 0.0, 1.0) * intensity;
		col = mix(vec3(0.015, 0.02, 0.045), tint.rgb * 1.55, edge);

	} else {
		// Prismatique : onde arc-en-ciel qui s'ouvre comme une lentille.
		float rayon = mix(0.0, 1.18, clear);
		float ring = exp(-pow((r - rayon) / 0.055, 2.0));
		float dehors = smoothstep(rayon - 0.03, rayon + 0.05, r);
		float ang = atan(p.y, p.x) / 6.2831853;
		vec3 pc = prism(ang + r * 0.65 - TIME * 0.10);
		a = clamp(dehors * 0.62 + ring * 0.90, 0.0, 1.0) * intensity;
		col = mix(vec3(0.015, 0.015, 0.045), pc * 1.25, clamp(ring * 1.4, 0.0, 1.0));
	}

	// Leger vignettage pour eviter une coupure trop plate en VR.
	float vignette = smoothstep(0.30, 0.86, r);
	a = clamp(a + vignette * (1.0 - clear) * 0.10 * intensity, 0.0, 1.0);

	ALBEDO = max(col, vec3(0.0));
	ALPHA = a;
}
