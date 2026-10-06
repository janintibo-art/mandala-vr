shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

// Gerbe de particules qui jaillit d'un point (rythme, son, dessin).
// COLOR.rgb = graines, UV = coin du quad (-1..1).
uniform vec3 centre = vec3(0.0);
uniform float age = 99.0;
uniform float force = 0.7;
uniform float vitesse = 5.0;

varying vec3 teinte;
varying float lum;

void vertex() {
	vec3 s = COLOR.rgb;
	float ph = s.x * 6.2831853;
	float ct = s.y * 2.0 - 1.0;
	float st = sqrt(max(1.0 - ct * ct, 0.0));
	vec3 d = vec3(st * cos(ph), ct, st * sin(ph));
	float sp = vitesse * (0.3 + 0.7 * s.z);
	float vie = 2.4;
	float a = clamp(age / vie, 0.0, 1.0);
	float dist = sp * (1.0 - exp(-age * 1.7)) / 1.7;
	vec3 p = centre + d * dist + vec3(0.0, -0.35 * age * age * s.z, 0.0);
	float dcam = length(INV_VIEW_MATRIX[3].xyz - p);
	float taille = 0.05 * (0.6 + s.z) * (1.0 - a * 0.6) * (1.0 + 0.16 * dcam);
	vec3 droite = INV_VIEW_MATRIX[0].xyz;
	vec3 haut = INV_VIEW_MATRIX[1].xyz;
	vec3 wp = p + (droite * UV.x + haut * UV.y) * taille;
	lum = force * (1.0 - a) * (1.0 - a) * step(age, vie);
	teinte = 0.5 + 0.5 * cos(6.2831853 * (s.y + vec3(0.0, 0.33, 0.67)));
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	float r = length(UV);
	float disque = 1.0 - smoothstep(0.55, 1.0, r);
	ALBEDO = teinte * lum * disque * 1.9;
}
