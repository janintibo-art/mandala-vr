shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float v12_qualite = 1.0;
uniform float v12_intensite = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grille(vec2 q, float largeur) {
	vec2 fw = max(fwidth(q), vec2(0.0001));
	vec2 g = abs(fract(q - 0.5) - 0.5) / fw;
	float d = min(g.x, g.y);
	return 1.0 - smoothstep(largeur, largeur + 1.0, d);
}

void fragment() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float dist = length(wpos.xz - cam.xz);
	float fade = clamp(1.0 - dist / 70.0, 0.0, 1.0);
	fade *= fade;

	float mineur = grille(wpos.xz * 0.5, 0.06);
	float majeur = grille(wpos.xz * 0.10, 0.10);

	// Axes principaux legerement plus lumineux : meilleure lecture de l'espace VR.
	vec2 afw = max(fwidth(wpos.xz), vec2(0.0001));
	float ax = 1.0 - smoothstep(0.0, afw.x * 2.0 + 0.035, abs(wpos.x));
	float az = 1.0 - smoothstep(0.0, afw.y * 2.0 + 0.035, abs(wpos.z));
	float axes = max(ax, az);

	float l = max(mineur * (0.28 + v12_qualite * 0.08), majeur * 0.72);
	l = max(l, axes * 0.85);

	vec3 c1 = vec3(0.10, 0.28, 0.58);
	vec3 c2 = vec3(0.18, 0.55, 0.78);
	vec3 col = mix(c1, c2, clamp(majeur + axes * 0.6, 0.0, 1.0));

	ALBEDO = col * v12_intensite;
	ALPHA = l * 0.62 * fade;
}
