// Effets lumineux communs (reglables sans reconstruire les maillages)
uniform float gain = 0.55;
uniform float adapt = 1.0;
uniform float halo = 0.5;
uniform float coeur = 0.4;
uniform float scint = 0.0;
uniform float pulse = 0.0;
uniform float arc = 0.0;
uniform float vitesse_fx = 1.0;

vec3 decaler_teinte(vec3 c, float a) {
	const mat3 yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
	const mat3 rgb = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));
	vec3 y = yiq * c;
	float cs = cos(a);
	float sn = sin(a);
	y.yz = vec2(y.y * cs - y.z * sn, y.y * sn + y.z * cs);
	return max(rgb * y, vec3(0.0));
}

vec3 effets_couleur(vec3 c, float noyau, vec3 wp) {
	float t = TIME * vitesse_fx;
	if (arc > 0.0) {
		c = decaler_teinte(c, arc * (t * 0.8 + length(wp) * 0.35));
	}
	float g = 1.0 + pulse * 0.45 * sin(t * 2.2);
	if (scint > 0.0) {
		g *= 1.0 + scint * 0.6 * sin(t * 6.0 + dot(wp, vec3(12.9898, 78.233, 37.719)));
	}
	c = mix(c, vec3(1.0), coeur * noyau);
	return c * g;
}

float gain_eff() {
	return gain * adapt;
}
