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

void fragment() {
	vec3 d = normalize(dir);
	float el = d.y;
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
		float az = atan(d.x, d.z);
		float a_el = smoothstep(0.02, 0.3, el) * smoothstep(0.95, 0.5, el);
		float c = fbm(vec3(az * 2.2, el * 3.0 - TIME * 0.05, TIME * 0.06));
		float rideau = pow(smoothstep(0.34, 0.85, c), 1.4) * a_el;
		vec3 ac = mix(vec3(0.1, 1.0, 0.5), vec3(0.6, 0.3, 1.0), smoothstep(0.1, 0.7, el + c * 0.3));
		col += ac * rideau * aurore * (1.15 + v12_detail * 0.22);
	}

	if (pluie > 0.0) {
		float az = atan(d.x, d.z) / 6.2831853 + 0.5;
		float cols = 110.0;
		float cx = floor(az * cols);
		float fx = fract(az * cols);
		float actif = step(0.3, h21(vec2(cx, 3.0)));
		float sp = 0.35 + h21(vec2(cx, 1.0)) * 1.2;
		float t = el * 38.0 + TIME * sp * 5.0 + h21(vec2(cx, 7.0)) * 60.0;
		float cell = floor(t);
		float fr = fract(t);
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
		float az = atan(d.x, d.z);
		float b = pow(abs(sin(az * 6.0 + 0.7)), 14.0);
		b *= smoothstep(-0.1, 0.9, el) * (0.55 + 0.45 * n3(vec3(az * 3.0, el * 2.0, TIME * 0.1)));
		col += vec3(1.0, 0.78, 0.45) * b * rayons * (0.34 + v12_detail * 0.08);
	}

	// Leger halo atmospherique au zenith : donne du volume sans fog volumetrique.
	float zenith = pow(max(el, 0.0), 3.0);
	col += haut * zenith * 0.16 * v12_detail;
	col = vibrance(col, v12_vibrance) * v12_lum;

	ALBEDO = max(col, vec3(0.0));
	ALPHA = 1.0;
}
