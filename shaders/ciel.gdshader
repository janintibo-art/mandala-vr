shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, depth_test_disabled, fog_disabled;

uniform vec3 haut : source_color = vec3(0.0, 0.0, 0.03);
uniform vec3 bas : source_color = vec3(0.02, 0.03, 0.08);
uniform float etoiles = 1.0;
uniform vec3 neb1 : source_color = vec3(0.5, 0.1, 0.6);
uniform vec3 neb2 : source_color = vec3(0.1, 0.3, 0.7);
uniform float neb = 0.0;
uniform float aurore = 0.0;
uniform float pluie = 0.0;
uniform float rayons = 0.0;
uniform float horizon = 0.0;
uniform vec3 horizon_col : source_color = vec3(1.0, 0.5, 0.3);

uniform float v12_detail = 1.0;
uniform float v12_vibrance = 1.08;
uniform float v12_lum = 1.04;

uniform int v13_monde = 0;
uniform float v13_intensite = 0.72;
uniform float v13_vitesse = 1.0;

varying vec3 dir;

void vertex() {
	dir = VERTEX;
}

float h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float n3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * n3(p);
		p *= 2.02;
		a *= 0.5;
	}
	return s;
}

vec3 vibrance(vec3 c, float v) {
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(l), c, v);
}

float halo_direction(vec3 d, vec3 cible, float puissance) {
	return pow(max(dot(d, normalize(cible)), 0.0), puissance);
}

void fragment() {
	vec3 d = normalize(dir);
	float el = d.y;
	float az = atan(d.x, d.z);
	float t13 = TIME * v13_vitesse;
	float i13 = v13_intensite;

	vec3 col = mix(bas, haut, smoothstep(-0.38, 0.86, el));
	col += horizon_col * horizon * exp(-abs(el) * 5.4);

	if (etoiles > 0.0) {
		for (int k = 0; k < 2; k++) {
			float ech = 62.0 + float(k) * 74.0;
			vec3 p = d * ech;
			vec3 id = floor(p);
			float h = h31(id + float(k) * 13.0);
			float densite = 0.042 * etoiles * mix(0.78, 1.18, clamp(v12_detail, 0.0, 1.3) / 1.3);
			float thr = 1.0 - densite;
			if (h > thr) {
				vec3 cellule = fract(p) - 0.5;
				float dd = length(cellule);
				float tw = 0.72 + 0.28 * sin(TIME * (2.0 + float(k)) + h * 200.0);
				float lum = (h - thr) / max(1.0 - thr, 0.0001);
				float temp = h31(id + vec3(37.0, 17.0, 9.0));
				vec3 froid = vec3(0.62, 0.78, 1.0);
				vec3 chaud = vec3(1.0, 0.78, 0.55);
				vec3 sc = mix(froid, chaud, temp);
				sc = mix(sc, vec3(1.0), 0.45);
				col += sc * smoothstep(0.21, 0.0, dd) * tw * (0.42 + lum * 1.15);
			}
		}
	}

	if (neb > 0.0) {
		float n = fbm(d * 2.4 + vec3(0.0, TIME * 0.01, 0.0));
		float fil = n3(d * (7.0 + v12_detail * 3.0) + vec3(TIME * 0.003, 2.1, -1.7));
		float m = smoothstep(0.38, 0.85, n);
		m *= mix(0.80, 1.22, smoothstep(0.28, 0.78, fil));
		vec3 nc = mix(neb1, neb2, fbm(d * 1.6 + 5.0));
		col += nc * m * neb * (0.88 + v12_detail * 0.14);
	}

	if (aurore > 0.0) {
		float a_el = smoothstep(0.02, 0.3, el) * smoothstep(0.95, 0.5, el);
		float c = fbm(vec3(az * 2.2, el * 3.0 - TIME * 0.05, TIME * 0.06));
		float rideau = pow(smoothstep(0.34, 0.85, c), 1.4) * a_el;
		vec3 ac = mix(vec3(0.1, 1.0, 0.5), vec3(0.6, 0.3, 1.0), smoothstep(0.1, 0.7, el + c * 0.3));
		col += ac * rideau * aurore * (1.15 + v12_detail * 0.22);
	}

	if (pluie > 0.0) {
		float azn = az / 6.2831853 + 0.5;
		float cols = 110.0;
		float cx = floor(azn * cols);
		float fx = fract(azn * cols);
		float actif = step(0.3, h21(vec2(cx, 3.0)));
		float sp = 0.35 + h21(vec2(cx, 1.0)) * 1.2;
		float tt = el * 38.0 + TIME * sp * 5.0 + h21(vec2(cx, 7.0)) * 60.0;
		float cell = floor(tt);
		float fr = fract(tt);
		float cycle = 14.0;
		float pos = mod(cell, cycle) / cycle;
		float trail = pow(1.0 - pos, 3.0) * (1.0 - fr * 0.2);
		float glyph = step(0.42, h21(vec2(cx, cell + floor(TIME * 2.0 * sp))));
		float tete = step(0.93, 1.0 - pos);
		float cadre = step(0.12, fx) * step(fx, 0.88) * step(0.12, fr) * step(fr, 0.88);
		vec3 gc = mix(vec3(0.05, 0.95, 0.35), vec3(0.8, 1.0, 0.85), tete);
		col += gc * trail * glyph * actif * cadre * pluie * (0.80 + v12_detail * 0.12);
	}

	if (rayons > 0.0) {
		float b = pow(abs(sin(az * 6.0 + 0.7)), 14.0);
		b *= smoothstep(-0.1, 0.9, el) * (0.55 + 0.45 * n3(vec3(az * 3.0, el * 2.0, TIME * 0.1)));
		col += vec3(1.0, 0.78, 0.45) * b * rayons * (0.34 + v12_detail * 0.08);
	}

	if (i13 > 0.001) {
		if (v13_monde == 1) {
			vec3 bn = normalize(vec3(0.22, 0.86, 0.45));
			float bande = 1.0 - smoothstep(0.025, 0.21, abs(dot(d, bn)));
			float poussiere = fbm(d * 7.0 + vec3(0.0, t13 * 0.004, 0.0));
			col += vec3(0.15, 0.23, 0.48) * bande * (0.16 + poussiere * 0.36) * i13;
			vec3 sd = normalize(vec3(sin(t13 * 0.07), 0.22 + 0.16 * sin(t13 * 0.031), -0.82));
			float meteor = halo_direction(d, sd, 900.0);
			col += vec3(0.75, 0.88, 1.0) * meteor * 2.2 * i13;
		} else if (v13_monde == 2) {
			float f1 = fbm(d * 8.5 + vec3(t13 * 0.008, -1.7, 2.3));
			float f2 = fbm(d * 15.0 + vec3(-2.0, t13 * 0.005, 1.0));
			float filaments = smoothstep(0.56, 0.80, f1) * (0.5 + f2);
			vec3 fc = mix(vec3(0.35, 0.08, 0.75), vec3(0.05, 0.45, 1.0), f2);
			col += fc * filaments * 0.42 * i13;
		} else if (v13_monde == 3) {
			float r1 = sin(az * 7.0 + fbm(d * 5.0) * 5.0 + t13 * 0.09);
			float rideau2 = pow(max(r1, 0.0), 6.0);
			rideau2 *= smoothstep(0.02, 0.28, el) * smoothstep(0.88, 0.52, el);
			vec3 rc = mix(vec3(0.05, 1.0, 0.55), vec3(0.35, 0.35, 1.0), el);
			col += rc * rideau2 * 0.38 * i13;
		} else if (v13_monde == 4) {
			float ca = sin(d.x * 48.0 + t13 * 0.25 + sin(d.z * 17.0));
			ca *= sin(d.z * 43.0 - t13 * 0.21 + sin(d.x * 13.0));
			ca = pow(abs(ca), 9.0) * smoothstep(-0.35, 0.55, el);
			col += vec3(0.05, 0.45, 0.78) * ca * 0.34 * i13;
			float bio = h31(floor(d * 34.0 + vec3(0.0, t13 * 0.08, 0.0)));
			float bp = step(0.982, bio) * (0.5 + 0.5 * sin(t13 * 1.5 + bio * 50.0));
			col += vec3(0.15, 0.9, 1.0) * bp * 0.45 * i13;
		} else if (v13_monde == 5) {
			vec3 soleil_dir = normalize(vec3(-0.68, 0.10, -0.72));
			float sd2 = dot(d, soleil_dir);
			float disque = smoothstep(0.9988, 0.99965, sd2);
			float shalo = pow(max(sd2, 0.0), 96.0);
			col += vec3(1.0, 0.42, 0.12) * shalo * 0.85 * i13;
			col += vec3(1.0, 0.82, 0.42) * disque * 2.0 * i13;
			float nuage = fbm(d * 5.5 + vec3(t13 * 0.008, 2.0, 0.0));
			nuage = smoothstep(0.57, 0.78, nuage) * exp(-abs(el - 0.06) * 5.5);
			col += vec3(0.32, 0.09, 0.16) * nuage * 0.32 * i13;
		} else if (v13_monde == 6) {
			float gv = pow(abs(sin(az * 28.0)), 30.0);
			float gh = pow(abs(sin((el + t13 * 0.015) * 72.0)), 24.0);
			float zone = smoothstep(-0.45, 0.15, el) * smoothstep(0.88, 0.2, el);
			col += vec3(0.05, 0.7, 0.22) * (gv * 0.13 + gh * 0.08) * zone * i13;
		} else if (v13_monde == 7) {
			float arches = pow(abs(sin(az * 6.0)), 18.0);
			float zone_arches = smoothstep(-0.28, -0.02, el) * smoothstep(0.52, 0.10, el);
			col *= 1.0 - arches * zone_arches * 0.22 * i13;
			float rose = halo_direction(d, vec3(0.0, 0.22, -1.0), 55.0);
			float petals = 0.55 + 0.45 * cos(az * 12.0);
			col += vec3(1.0, 0.55, 0.16) * rose * petals * 0.48 * i13;
		} else if (v13_monde == 8) {
			vec3 p8 = d * 24.0;
			vec3 id8 = floor(p8);
			float h8 = h31(id8);
			float fire = step(0.968, h8);
			float pulse8 = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(t13 * (1.2 + h8 * 2.0) + h8 * 90.0), 3.0);
			float near8 = smoothstep(0.42, 0.02, length(fract(p8) - 0.5));
			col += vec3(0.72, 1.0, 0.16) * fire * pulse8 * near8 * 0.72 * i13;
		} else if (v13_monde == 9) {
			float chaleur = sin(az * 13.0 + fbm(d * 8.0 + vec3(0.0, t13 * 0.03, 0.0)) * 4.0);
			chaleur = pow(max(chaleur, 0.0), 8.0) * exp(-abs(el + 0.02) * 5.0);
			col += vec3(1.0, 0.16, 0.015) * chaleur * 0.35 * i13;
			vec3 p9 = d * 38.0 + vec3(0.0, -t13 * 0.28, 0.0);
			float e9 = h31(floor(p9));
			float ember = step(0.985, e9) * smoothstep(0.32, 0.03, length(fract(p9) - 0.5));
			col += vec3(1.0, 0.28, 0.025) * ember * 0.9 * i13;
		} else if (v13_monde == 10) {
			float pilier = pow(abs(sin(az * 16.0 + 0.4)), 36.0);
			pilier *= smoothstep(-0.18, 0.35, el) * smoothstep(0.9, 0.28, el);
			col += vec3(0.35, 0.75, 1.0) * pilier * 0.20 * i13;
			vec3 lune_dir = normalize(vec3(0.48, 0.34, -0.82));
			float lune = halo_direction(d, lune_dir, 650.0);
			float lune_halo = halo_direction(d, lune_dir, 45.0);
			col += vec3(0.58, 0.82, 1.0) * lune_halo * 0.18 * i13;
			col += vec3(0.92, 0.98, 1.0) * lune * 1.4 * i13;
		} else if (v13_monde == 11) {
			float ruban = sin(az * 4.0 + el * 9.0 + fbm(d * 4.0 + vec3(t13 * 0.01, 0.0, 0.0)) * 5.0);
			ruban = pow(max(ruban, 0.0), 7.0);
			vec3 pc = mix(vec3(1.0, 0.22, 0.58), vec3(0.42, 0.35, 1.0), 0.5 + 0.5 * sin(az * 2.0));
			col += pc * ruban * 0.26 * i13;
			float sparkle = h31(floor(d * 32.0 + vec3(t13 * 0.01)));
			sparkle = step(0.984, sparkle) * (0.5 + 0.5 * sin(t13 * 1.4 + sparkle * 80.0));
			col += vec3(1.0, 0.72, 0.95) * sparkle * 0.42 * i13;

		// -------------------------------------------------- v28 nouveaux fonds
		} else if (v13_monde == 12) {
			// Foret enchantee : silhouettes de cimes + lueurs vertes.
			float canopee = -0.12
				+ 0.085 * sin(az * 9.0)
				+ 0.045 * sin(az * 23.0 + 1.4)
				+ 0.022 * sin(az * 51.0);
			float arbres = 1.0 - smoothstep(canopee - 0.018, canopee + 0.018, el);
			col = mix(col, vec3(0.002, 0.018, 0.008), arbres * 0.72 * i13);
			float brume = smoothstep(0.38, 0.70, fbm(d * 5.0 + vec3(t13 * 0.004, 0.0, 0.0)));
			brume *= exp(-abs(el + 0.02) * 5.0);
			col += vec3(0.05, 0.30, 0.12) * brume * 0.26 * i13;

		} else if (v13_monde == 13) {
			// Ocean lunaire : lune, horizon et reflets ondulants.
			vec3 lune_dir13 = normalize(vec3(-0.42, 0.24, -0.86));
			float lune13 = halo_direction(d, lune_dir13, 780.0);
			float halo13 = halo_direction(d, lune_dir13, 48.0);
			col += vec3(0.72, 0.90, 1.0) * halo13 * 0.20 * i13;
			col += vec3(0.96, 0.99, 1.0) * lune13 * 1.55 * i13;
			float mer = 1.0 - smoothstep(-0.15, 0.08, el);
			float vagues = pow(abs(sin(az * 36.0 + t13 * 0.22 + sin(az * 7.0) * 2.0)), 15.0);
			col += vec3(0.08, 0.46, 0.68) * vagues * mer * 0.22 * i13;
			float reflet13 = pow(max(dot(d, lune_dir13), 0.0), 8.0) * mer;
			col += vec3(0.30, 0.78, 1.0) * reflet13 * 0.15 * i13;

		} else if (v13_monde == 14) {
			// Dunes violettes : trois horizons ondulants superposes.
			float d1 = -0.18 + 0.060 * sin(az * 2.0 + 0.4) + 0.025 * sin(az * 5.0);
			float d2 = -0.11 + 0.050 * sin(az * 2.7 + 2.0);
			float d3 = -0.04 + 0.035 * sin(az * 3.4 + 4.2);
			float m1 = 1.0 - smoothstep(d1 - 0.015, d1 + 0.015, el);
			float m2 = 1.0 - smoothstep(d2 - 0.015, d2 + 0.015, el);
			float m3 = 1.0 - smoothstep(d3 - 0.015, d3 + 0.015, el);
			col = mix(col, vec3(0.08, 0.018, 0.11), m3 * 0.32 * i13);
			col = mix(col, vec3(0.11, 0.022, 0.09), m2 * 0.38 * i13);
			col = mix(col, vec3(0.04, 0.008, 0.055), m1 * 0.62 * i13);

		} else if (v13_monde == 15) {
			// Brume zen : larges nappes lentes et soleil ivoire.
			float br15a = fbm(d * 3.2 + vec3(t13 * 0.006, 0.0, 0.0));
			float br15b = fbm(d * 6.5 + vec3(-t13 * 0.004, 2.0, 1.0));
			float nappes = smoothstep(0.43, 0.72, br15a) * (0.55 + br15b * 0.45);
			nappes *= smoothstep(-0.55, 0.25, el) * smoothstep(0.72, 0.10, el);
			col += vec3(0.22, 0.27, 0.34) * nappes * 0.22 * i13;
			vec3 soleil15 = normalize(vec3(0.62, 0.18, -0.76));
			float disque15 = halo_direction(d, soleil15, 520.0);
			col += vec3(0.92, 0.86, 0.72) * disque15 * 0.72 * i13;

		} else if (v13_monde == 16) {
			// Cristaux cosmiques : facettes et rais de lumiere froide.
			float fac1 = pow(abs(sin(az * 12.0 + el * 8.0)), 28.0);
			float fac2 = pow(abs(sin(az * 7.0 - el * 13.0 + 1.2)), 34.0);
			float zone16 = smoothstep(-0.35, 0.12, el) * smoothstep(0.92, 0.18, el);
			col += vec3(0.10, 0.58, 1.0) * fac1 * zone16 * 0.13 * i13;
			col += vec3(0.62, 0.28, 1.0) * fac2 * zone16 * 0.10 * i13;
			float coeur16 = halo_direction(d, vec3(0.0, 0.35, -1.0), 90.0);
			col += vec3(0.28, 0.72, 1.0) * coeur16 * 0.22 * i13;

		} else if (v13_monde == 17) {
			// Jardin sakura : lune rose et pluie de petales lointains.
			vec3 lune17d = normalize(vec3(0.36, 0.28, -0.89));
			float lune17 = halo_direction(d, lune17d, 620.0);
			float lune17h = halo_direction(d, lune17d, 42.0);
			col += vec3(1.0, 0.42, 0.68) * lune17h * 0.18 * i13;
			col += vec3(1.0, 0.78, 0.86) * lune17 * 1.15 * i13;
			vec3 pp17 = d * 31.0 + vec3(t13 * 0.055, -t13 * 0.12, 0.0);
			vec3 id17 = floor(pp17);
			float h17 = h31(id17);
			float petale17 = step(0.978, h17);
			float forme17 = smoothstep(0.38, 0.08, length((fract(pp17) - 0.5) * vec3(0.72, 1.3, 0.72)));
			col += vec3(1.0, 0.36, 0.64) * petale17 * forme17 * 0.52 * i13;

		} else if (v13_monde == 18) {
			// Soleil rouge : disque enorme, halo chaud et bandes nuageuses.
			vec3 sun18d = normalize(vec3(-0.58, 0.08, -0.81));
			float sun18 = halo_direction(d, sun18d, 310.0);
			float sun18h = halo_direction(d, sun18d, 35.0);
			col += vec3(1.0, 0.08, 0.015) * sun18h * 0.48 * i13;
			col += vec3(1.0, 0.56, 0.12) * sun18 * 1.75 * i13;
			float cloud18 = fbm(d * 6.2 + vec3(t13 * 0.014, 0.0, 0.0));
			cloud18 = smoothstep(0.56, 0.77, cloud18) * exp(-abs(el - 0.02) * 4.2);
			col = mix(col, vec3(0.16, 0.012, 0.018), cloud18 * 0.42 * i13);

		} else if (v13_monde == 19) {
			// Vortex profond : spirale froide autour d'un coeur noir.
			float angle19 = atan(d.y, d.x);
			float rayon19 = length(d.xy);
			float spiral19 = sin(angle19 * 5.0 + rayon19 * 26.0 - t13 * 0.45);
			spiral19 = pow(max(spiral19, 0.0), 7.0);
			float face19 = pow(max(-d.z, 0.0), 2.2);
			vec3 vc19 = mix(vec3(0.05, 0.18, 0.72), vec3(0.48, 0.08, 0.92), 0.5 + 0.5 * sin(angle19 * 2.0));
			col += vc19 * spiral19 * face19 * 0.38 * i13;
			float trou19 = halo_direction(d, vec3(0.0, 0.0, -1.0), 18.0);
			col *= 1.0 - trou19 * 0.42 * i13;
			float bord19 = halo_direction(d, vec3(0.0, 0.0, -1.0), 55.0);
			col += vec3(0.20, 0.34, 1.0) * bord19 * 0.18 * i13;
		}
	}

	float zenith = pow(max(el, 0.0), 3.0);
	col += haut * zenith * 0.16 * v12_detail;
	col = vibrance(col, v12_vibrance) * v12_lum;

	ALBEDO = max(col, vec3(0.0));
	ALPHA = 1.0;
}
