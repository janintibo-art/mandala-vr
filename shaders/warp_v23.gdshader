shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

// Traînees de lumière qui filent vers toi : sensation de vitesse dans un tunnel.
// COLOR.rgb = graines aleatoires, UV = coin du quad (-1..1).
uniform vec3 cam = vec3(0.0);
uniform vec3 dir = vec3(0.0, 0.0, -1.0);
uniform float vitesse = 10.0;
uniform float force = 0.0;
uniform vec3 teinte : source_color = vec3(0.55, 0.8, 1.0);

varying float lum;

void vertex() {
	vec3 s = COLOR.rgb;
	vec3 u = normalize(cross(dir, abs(dir.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 v = cross(dir, u);
	float L = 70.0;
	float along = mod(s.z * L - TIME * vitesse, L) - 10.0;
	float ang = s.x * 6.2831853;
	float r = mix(1.1, 10.0, s.y * s.y);
	vec3 centre = cam + dir * along + (u * cos(ang) + v * sin(ang)) * r;
	float longueur = 0.12 + vitesse * 0.05;
	vec3 vue = INV_VIEW_MATRIX[3].xyz - centre;
	vec3 lat = cross(dir, vue);
	float ll = length(lat);
	lat = ll > 0.0001 ? lat / ll : u;
	vec3 wp = centre + dir * UV.y * longueur + lat * UV.x * 0.011 * (1.0 + s.y * 2.5);
	lum = force * smoothstep(-10.0, 4.0, along) * (1.0 - smoothstep(38.0, 60.0, along)) * (0.35 + 0.65 * s.y);
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
}

void fragment() {
	ALBEDO = teinte * lum * 1.3;
}
