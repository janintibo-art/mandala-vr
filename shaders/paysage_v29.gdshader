shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, fog_disabled;

uniform int world_index = 0;
uniform int layer_index = 0;
uniform vec4 land_color : source_color = vec4(0.05, 0.08, 0.14, 1.0);
uniform float alpha_base : hint_range(0.0, 1.0) = 0.3;
uniform float intensity : hint_range(0.0, 1.0) = 0.82;
uniform float motion : hint_range(0.0, 1.2) = 0.55;

varying vec3 ldir;

void vertex() {
	ldir = normalize(VERTEX);
}

float h1(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453123);
}

float onde(float u, float f, float phase) {
	return sin((u * f + phase) * 6.2831853);
}

float montagnes(float u, float layer) {
	float a = onde(u, 1.35 + layer * 0.22, 0.13);
	float b = onde(u, 3.1 + layer * 0.31, 0.57);
	float c = onde(u, 7.2, 0.91);
	return -0.18 + a * 0.055 + b * 0.038 + c * 0.016;
}

float dunes(float u, float layer) {
	return -0.19
		+ onde(u, 1.55 + layer * 0.15, 0.18) * 0.055
		+ onde(u, 3.05, 0.62) * 0.020;
}

float foret(float u, float layer) {
	float n = 34.0 - layer * 6.0;
	float x = u * n;
	float id = floor(x);
	float f = fract(x) - 0.5;
	float tri = max(0.0, 1.0 - abs(f) * 2.0);
	float hauteur = 0.055 + h1(id + layer * 17.0) * (0.13 + layer * 0.015);
	float arbre = pow(tri, 1.3) * hauteur;
	float sol = -0.22 + onde(u, 2.1, layer * 0.23) * 0.025;
	return sol + arbre;
}

float ville(float u, float layer) {
	float n = 42.0 - layer * 7.0;
	float id = floor(u * n);
	float h = h1(id + 13.0 * layer);
	float base = -0.22 + onde(u, 1.3, 0.1) * 0.014;
	return base + 0.035 + h * (0.11 + layer * 0.025);
}

float cristaux(float u, float layer) {
	float n = 18.0 - layer * 2.0;
	float x = u * n;
	float id = floor(x);
	float f = abs(fract(x) - 0.5) * 2.0;
	float pic = pow(max(0.0, 1.0 - f), 2.7);
	float h = 0.05 + h1(id + layer * 9.0) * (0.18 + layer * 0.025);
	return -0.22 + pic * h;
}

float cathedrale(float u, float layer) {
	float n = 14.0 - layer * 2.0;
	float x = u * n;
	float id = floor(x);
	float f = abs(fract(x) - 0.5) * 2.0;
	float tour = pow(max(0.0, 1.0 - f), 4.0);
	float h = 0.08 + h1(id + 3.0) * (0.14 + layer * 0.025);
	float base = -0.205 + onde(u, 2.0, 0.4) * 0.012;
	return base + tour * h;
}

float volcan(float u, float layer) {
	float base = montagnes(u, layer);
	float n = 9.0 - layer;
	float x = u * n;
	float f = abs(fract(x) - 0.5) * 2.0;
	float cone = pow(max(0.0, 1.0 - f), 1.8);
	return base + cone * (0.08 + layer * 0.025);
}

float iles(float u, float layer) {
	float n = 11.0 - layer;
	float x = u * n;
	float id = floor(x);
	float f = abs(fract(x) - 0.5) * 2.0;
	float dome = sqrt(max(0.0, 1.0 - f * f));
	float present = step(0.42, h1(id + 4.0));
	return -0.245 + dome * present * (0.035 + h1(id + 7.0) * 0.065);
}

float profil(float u, float layer, int monde) {
	if (monde == 6) {
		return ville(u, layer);
	}
	if (monde == 7) {
		return cathedrale(u, layer);
	}
	if (monde == 3 || monde == 8 || monde == 12 || monde == 17) {
		return foret(u, layer);
	}
	if (monde == 4 || monde == 13) {
		return iles(u, layer);
	}
	if (monde == 9) {
		return volcan(u, layer);
	}
	if (monde == 10 || monde == 16 || monde == 19) {
		return cristaux(u, layer);
	}
	if (monde == 14 || monde == 18) {
		return dunes(u, layer);
	}
	if (monde == 2 || monde == 11) {
		return cristaux(u, layer) * 0.88 - 0.018;
	}
	if (monde == 5) {
		return dunes(u, layer) + 0.025 * max(0.0, onde(u, 5.0, 0.1));
	}
	if (monde == 15) {
		return montagnes(u, layer) - 0.025;
	}
	return montagnes(u, layer);
}

void fragment() {
	vec3 d = normalize(ldir);
	float az = atan(d.x, d.z);
	float u = fract(az / 6.2831853 + 0.5);

	// Vie tres subtile : surtout eau, foret et mondes oniriques.
	float anime = 0.0;
	if (world_index == 4 || world_index == 13) {
		anime = sin(TIME * 0.22 * motion + u * 38.0) * 0.004;
	} else if (world_index == 3 || world_index == 8 || world_index == 12 || world_index == 17) {
		anime = sin(TIME * 0.13 * motion + u * 54.0) * 0.0025;
	} else if (world_index == 11 || world_index == 19) {
		anime = sin(TIME * 0.10 * motion + u * 17.0) * 0.004;
	}

	float h = profil(u, float(layer_index), world_index) + anime;

	// Silhouette pleine sous le relief, bord legerement adouci.
	float bord = 0.008 + float(layer_index) * 0.002;
	float masque = 1.0 - smoothstep(h - bord, h + bord, d.y);

	// Le bas devient plus dense ; proche de l'horizon il reste atmospherique.
	float bas = smoothstep(h + 0.08, -0.70, d.y);
	float a = masque * alpha_base * intensity;
	a *= mix(0.76, 1.0, bas);

	// Petites lumieres distantes dans certains environnements.
	float lumieres = 0.0;
	if (world_index == 6 || world_index == 7 || world_index == 8 || world_index == 12 || world_index == 17) {
		float cellules = 90.0 - float(layer_index) * 15.0;
		float id = floor(u * cellules);
		float local = abs(fract(u * cellules) - 0.5);
		float point = smoothstep(0.08, 0.0, local);
		float hasard = step(0.92, h1(id + float(world_index) * 21.0));
		float hauteur_point = h + 0.018 + h1(id + 5.0) * 0.055;
		float vertical = smoothstep(0.012, 0.0, abs(d.y - hauteur_point));
		lumieres = point * hasard * vertical * (0.55 + 0.45 * sin(TIME * 0.8 + id));
	}

	vec3 c = land_color.rgb;
	vec3 lumiere_col = vec3(0.85, 0.95, 1.0);
	if (world_index == 8 || world_index == 12) {
		lumiere_col = vec3(0.72, 1.0, 0.22);
	} else if (world_index == 17) {
		lumiere_col = vec3(1.0, 0.42, 0.66);
	} else if (world_index == 7) {
		lumiere_col = vec3(1.0, 0.70, 0.25);
	} else if (world_index == 6) {
		lumiere_col = vec3(0.20, 1.0, 0.45);
	}

	c += lumiere_col * lumieres * 0.75 * intensity;
	a = max(a, lumieres * 0.34 * intensity);

	ALBEDO = max(c, vec3(0.0));
	ALPHA = clamp(a, 0.0, 0.78);
}
