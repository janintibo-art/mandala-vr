// Effets lumineux communs (reglables sans reconstruire les maillages)
uniform float gain = 0.55;
uniform float adapt = 1.0;
uniform float halo = 0.5;
uniform float coeur = 0.4;
uniform float scint = 0.0;
uniform float pulse = 0.0;
uniform float arc = 0.0;
uniform float vitesse_fx = 1.0;

// Mandala VR v12 : finition graphique. Ces reglages sont modifies en direct
// par v12_manager.gd sans reconstruire les maillages.
uniform float v12_finesse = 1.0;
uniform float v12_profondeur = 0.45;
uniform float v12_vibrance = 1.08;
uniform float v12_brillance = 0.45;

vec3 decaler_teinte(vec3 c, float a) {
	const mat3 yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
	const mat3 rgb = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));
	vec3 y = yiq * c;
	float cs = cos(a);
	float sn = sin(a);
	y.yz = vec2(y.y * cs - y.z * sn, y.y * sn + y.z * cs);
	return max(rgb * y, vec3(0.0));
}

vec3 v12_finition(vec3 c, float noyau, vec3 wp) {
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(lum), c, v12_vibrance);
	float relief = 0.96 + v12_profondeur * 0.08 *
		(0.5 + 0.5 * sin(dot(wp, vec3(1.17, 1.73, 2.11))));
	c *= relief;
	c += vec3(1.0) * noyau * v12_brillance * 0.20;
	return max(c, vec3(0.0));
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
	return v12_finition(c * g, noyau, wp);
}

float gain_eff() {
	return gain * adapt;
}

// Projection en dome autour du spectateur (0 = plan, 1 = dome)
uniform float dome = 0.0;
uniform vec3 dome_c = vec3(0.0);
uniform float dome_r = 7.0;
uniform float dome_ang = 1.9;
uniform mat3 dome_b;

vec3 dome_map(vec3 rel) {
	float r = length(rel.xy);
	float th = min(r / 6.0 * dome_ang, 3.0);
	float ph = atan(rel.y, rel.x);
	vec3 d = vec3(sin(th) * cos(ph), sin(th) * sin(ph), -cos(th));
	return dome_c + (dome_b * d) * (dome_r + rel.z);
}
