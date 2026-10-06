// Effets lumineux communs (reglables sans reconstruire les maillages)
uniform float gain = 0.55;
uniform float adapt = 1.0;
uniform float halo = 0.5;
uniform float coeur = 0.4;
uniform float scint = 0.0;
uniform float pulse = 0.0;
uniform float arc = 0.0;
uniform float vitesse_fx = 1.0;

// Mandala VR v12 : finition graphique.
uniform float v12_finesse = 1.0;
uniform float v12_profondeur = 0.45;
uniform float v12_vibrance = 1.08;
uniform float v12_brillance = 0.45;

// Mandala VR v14 : materiaux proceduraux, sans texture supplementaire.
uniform int v14_style = 1;
uniform float v14_force = 0.68;
uniform float v14_halo_layers = 0.62;
uniform float v14_depth = 0.52;
uniform float v14_spark = 0.28;
uniform float v14_speed = 0.85;

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

float v14_hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

vec3 v14_palette_prisme(float u) {
	return 0.55 + 0.45 * cos(6.2831853 * (u + vec3(0.00, 0.33, 0.67)));
}

vec3 v14_materiau(vec3 c, float noyau, float bord, vec3 wp) {
	if (v14_style == 0 || v14_force <= 0.001) {
		return c;
	}

	float t = TIME * v14_speed;
	float radial = length(wp.xy);
	float phase = radial * 0.32 + wp.z * 1.9 + t;
	float f = clamp(v14_force, 0.0, 1.25);

	if (v14_style == 1) {
		// Neon : couleur originale preservee, coeur blanc et bord sature.
		float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
		vec3 sat = mix(vec3(lum), c, 1.28);
		c = mix(c, sat, 0.55 * f);
		c = mix(c, vec3(1.0), noyau * (0.22 + 0.30 * f));
		c *= 1.0 + bord * 0.16 * f;
	} else if (v14_style == 2) {
		// Plasma : teinte mouvante et energie interne.
		float vague = 0.5 + 0.5 * sin(phase * 1.7 + sin(phase * 0.53));
		vec3 pcol = v14_palette_prisme(vague + radial * 0.025);
		c = mix(c, pcol, (0.30 + 0.34 * vague) * f);
		c *= 0.88 + 0.34 * (0.5 + 0.5 * sin(phase * 2.3)) * f;
		c = mix(c, vec3(1.0), noyau * 0.34 * f);
	} else if (v14_style == 3) {
		// Cristal : froid, reflets blancs et irisations discretes.
		float facette = 0.5 + 0.5 * sin(radial * 2.2 - wp.z * 4.0 + t * 0.22);
		vec3 glace = mix(vec3(0.36, 0.68, 1.0), vec3(0.86, 0.62, 1.0), facette);
		c = mix(c, glace * max(dot(c, vec3(0.333)), 0.28), 0.42 * f);
		float reflet = pow(0.5 + 0.5 * sin(radial * 3.7 + t * 0.18), 8.0);
		c += vec3(0.72, 0.90, 1.0) * reflet * (0.12 + noyau * 0.25) * f;
		c = mix(c, vec3(1.0), noyau * 0.38 * f);
	} else if (v14_style == 4) {
		// Hologramme : cyan/magenta, lignes fines et leger flicker.
		float scan = 0.5 + 0.5 * sin((wp.y + wp.x * 0.17) * 22.0 - t * 5.0);
		vec3 holo = mix(vec3(0.05, 0.95, 1.0), vec3(1.0, 0.08, 0.82), 0.5 + 0.5 * sin(phase * 0.8));
		c = mix(c, holo, 0.48 * f);
		c *= 0.82 + scan * 0.34 * f;
		float flick = step(0.985, v14_hash(floor(wp * 7.0) + floor(t * 5.0)));
		c += holo * flick * 0.45 * f;
	} else if (v14_style == 5) {
		// Or : remappage chaud avec coeur ivoire.
		float lum = max(dot(c, vec3(0.2126, 0.7152, 0.0722)), 0.12);
		vec3 sombre = vec3(0.23, 0.055, 0.006);
		vec3 or1 = vec3(1.00, 0.48, 0.035);
		vec3 or2 = vec3(1.00, 0.90, 0.42);
		vec3 gold = mix(sombre, or1, smoothstep(0.08, 0.62, lum));
		gold = mix(gold, or2, smoothstep(0.55, 1.0, lum + noyau * 0.35));
		c = mix(c, gold, 0.72 * f);
		c = mix(c, vec3(1.0, 0.94, 0.72), noyau * 0.34 * f);
	} else if (v14_style == 6) {
		// Prismatique : arc-en-ciel spatial, mais conserve une partie de la palette.
		float u = radial * 0.055 + atan(wp.y, wp.x) / 6.2831853 + t * 0.055;
		vec3 pr = v14_palette_prisme(u);
		c = mix(c, pr, 0.54 * f);
		c = mix(c, vec3(1.0), noyau * 0.24 * f);
	}

	// Faux relief lumineux commun a tous les materiaux.
	float profondeur = 0.5 + 0.5 * sin(radial * 0.72 + wp.z * 2.8 - t * 0.18);
	c *= 1.0 + (profondeur - 0.5) * v14_depth * 0.24;

	if (v14_spark > 0.001) {
		float n = v14_hash(floor(wp * 11.0));
		float e = step(1.0 - v14_spark * 0.035, n);
		float blink = pow(0.5 + 0.5 * sin(t * 4.0 + n * 60.0), 10.0);
		c += vec3(1.0) * e * blink * 0.55 * f;
	}

	return max(c, vec3(0.0));
}

float v14_halo_mult(float coord, float core_radius) {
	if (v14_halo_layers <= 0.001) {
		return 0.0;
	}
	float x = abs(coord);
	float h1 = exp(-x * 3.6) * 0.34;
	float h2 = exp(-x * 8.5) * 0.22;
	float anneau = exp(-pow((x - core_radius * 1.55) * 7.0, 2.0)) * 0.16;
	return (h1 + h2 + anneau) * v14_halo_layers * v14_force;
}

float v14_disque_halo(float r, float core_radius) {
	if (v14_halo_layers <= 0.001) {
		return 0.0;
	}
	float h1 = exp(-r * 3.3) * 0.35;
	float h2 = exp(-r * 8.2) * 0.22;
	float anneau = exp(-pow((r - core_radius * 1.55) * 6.8, 2.0)) * 0.16;
	return (h1 + h2 + anneau) * v14_halo_layers * v14_force;
}

vec3 effets_couleur(vec3 c, float noyau, float bord, vec3 wp) {
	float t = TIME * vitesse_fx;
	if (arc > 0.0) {
		c = decaler_teinte(c, arc * (t * 0.8 + length(wp) * 0.35));
	}
	float g = 1.0 + pulse * 0.45 * sin(t * 2.2);
	if (scint > 0.0) {
		g *= 1.0 + scint * 0.6 * sin(t * 6.0 + dot(wp, vec3(12.9898, 78.233, 37.719)));
	}
	c = mix(c, vec3(1.0), coeur * noyau * 0.65);
	c = v12_finition(c * g, noyau, wp);
	return v14_materiau(c, noyau, bord, wp);
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
