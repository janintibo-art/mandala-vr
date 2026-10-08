shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

// Planete mandala : bandes ondulees, calotte polaire en petales, anneaux fins,
// meridiens lumineux, halo de bord.
uniform vec3 c1 = vec3(0.2, 0.7, 1.0);
uniform vec3 c2 = vec3(0.7, 0.3, 1.0);
uniform vec3 c3 = vec3(1.0, 0.7, 0.3);
uniform float graine = 0.0;

varying vec3 loc;

void vertex() {
	loc = VERTEX;
}

void fragment() {
	vec3 n = normalize(loc);
	float lon = atan(n.z, n.x);
	float lat = asin(clamp(n.y, -1.0, 1.0));
	float t = TIME * 0.15;
	float bandes = 0.5 + 0.5 * sin(lat * (9.0 + graine * 2.0) + sin(lon * 3.0 + t * 2.0) * 0.8);
	float pr = acos(abs(n.y));
	float petales = abs(sin(lon * (6.0 + graine) + t));
	float cap = smoothstep(0.75, 0.0, pr) * smoothstep(0.30, 0.95, petales);
	float fins = smoothstep(0.88, 1.0, sin(pr * 26.0)) * (1.0 - smoothstep(0.0, 1.25, pr));
	float mer = smoothstep(0.97, 1.0, abs(sin(lon * 12.0 + t)));
	vec3 col = mix(c1, c2, bandes) * 0.75;
	col = mix(col, c3, cap * 0.85);
	col += c3 * fins * 0.45;
	col += c1 * mer * 0.22;
	float lum = 0.50 + 0.50 * max(dot(normalize(NORMAL), normalize(vec3(-0.45, 0.5, 0.75))), 0.0);
	float f = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.6);
	ALBEDO = col * lum + mix(c1, c3, 0.5) * f * 0.7;
}
