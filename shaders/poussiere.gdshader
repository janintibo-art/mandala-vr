shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform vec3 boite = vec3(30.0, 14.0, 30.0);
uniform vec3 deriv = vec3(0.0, 0.03, 0.0);
uniform float taille = 0.03;
uniform vec4 couleur : source_color = vec4(0.7, 0.8, 1.0, 0.8);
uniform float v12_qualite = 1.0;
uniform float v12_intensite = 1.0;

uniform int v13_monde = 0;
uniform float v13_intensite = 0.72;
uniform float v13_vitesse = 1.0;

varying float fondu;
varying float lumiere;
varying float graine;

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 s = VERTEX;
	vec3 drift = deriv;
	float taille_monde = 1.0;

	if (v13_monde == 4) {
		drift *= 0.35;
		taille_monde = 1.20;
	} else if (v13_monde == 6) {
		drift = vec3(0.0, -0.20, 0.0);
		taille_monde = 0.72;
	} else if (v13_monde == 8) {
		drift = vec3(0.02, 0.06, 0.01);
		taille_monde = 1.25;
	} else if (v13_monde == 9) {
		drift = vec3(0.02, 0.42, 0.0);
		taille_monde = 0.78;
	} else if (v13_monde == 10) {
		drift = vec3(0.05, -0.16, 0.03);
		taille_monde = 1.05;
	} else if (v13_monde == 11) {
		drift = vec3(0.01, 0.045, 0.015);
		taille_monde = 1.15;
	}

	vec3 p = s * boite + drift * TIME * UV2.y * v13_vitesse;
	p += vec3(
		sin(TIME * 0.3 * v13_vitesse + s.x * 40.0),
		cos(TIME * 0.27 * v13_vitesse + s.y * 40.0),
		sin(TIME * 0.21 * v13_vitesse + s.z * 40.0)) * 0.3;

	p = cam + (fract((p - cam) / boite + 0.5) - 0.5) * boite;
	float dist = length(p - cam);
	fondu = smoothstep(boite.x * 0.5, boite.x * 0.3, dist) * smoothstep(0.4, 1.2, dist);
	lumiere = COLOR.r;
	graine = fract(s.x * 37.13 + s.y * 71.77 + s.z * 19.31);

	vec3 vc = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	float finesse = mix(0.92, 1.08, clamp(v12_qualite, 0.6, 1.3) / 1.3);
	vec2 taille_xy = UV * UV2.x * taille * finesse * taille_monde * (0.58 + dist * 0.12);
	if (v13_monde == 9) {
		taille_xy.y *= 1.65;
		taille_xy.x *= 0.72;
	}
	vc.xy += taille_xy;
	VERTEX = vc;
}

void fragment() {
	float r = length(UV);
	float aa = max(fwidth(r) * 1.5, 0.002);
	float halo = 1.0 - smoothstep(0.16, 1.0 + aa, r);
	float coeur = 1.0 - smoothstep(0.0, 0.25 + aa, r);
	float a = halo * halo * 0.72 + coeur * (0.35 + 0.25 * v12_qualite);

	vec3 col = couleur.rgb;
	float intens = v12_intensite * mix(0.82, 1.22, v13_intensite / 1.25);

	if (v13_monde == 4) {
		col *= vec3(0.45, 1.05, 1.28);
		intens *= 0.78 + 0.32 * sin(TIME * 0.8 * v13_vitesse + graine * 28.0);
	} else if (v13_monde == 6) {
		// Pixel carre pour le monde Code.
		float carre = 1.0 - smoothstep(0.64, 1.0, max(abs(UV.x), abs(UV.y)));
		a = carre * carre;
		col *= vec3(0.32, 1.35, 0.48);
	} else if (v13_monde == 8) {
		col *= vec3(1.08, 1.28, 0.35);
		intens *= 0.35 + 0.90 * pow(0.5 + 0.5 * sin(TIME * (1.3 + graine) * v13_vitesse + graine * 40.0), 3.0);
	} else if (v13_monde == 9) {
		col = mix(col, vec3(1.0, 0.18, 0.015), 0.78);
		intens *= 1.12;
	} else if (v13_monde == 10) {
		col = mix(col, vec3(0.72, 0.90, 1.0), 0.65);
		float croix = max(
			1.0 - smoothstep(0.06, 0.22, abs(UV.x)),
			1.0 - smoothstep(0.06, 0.22, abs(UV.y)));
		a = max(a * 0.65, croix * (1.0 - smoothstep(0.20, 1.0, r)) * 0.55);
	} else if (v13_monde == 11) {
		col = mix(col, vec3(1.0, 0.48, 0.88), 0.55);
		intens *= 0.75 + 0.25 * sin(TIME * 0.7 * v13_vitesse + graine * 30.0);
	}

	float variation = mix(0.72, 1.18, lumiere);
	col *= variation;
	col = mix(col, vec3(1.0), coeur * 0.28);

	ALBEDO = col * a * couleur.a * fondu * intens;
}
