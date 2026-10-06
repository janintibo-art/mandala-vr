shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform;

uniform vec3 boite = vec3(30.0, 14.0, 30.0);
uniform vec3 deriv = vec3(0.0, 0.03, 0.0);
uniform float taille = 0.03;
uniform vec4 couleur : source_color = vec4(0.7, 0.8, 1.0, 0.8);
uniform float v12_qualite = 1.0;
uniform float v12_intensite = 1.0;

varying float fondu;
varying float lumiere;

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 s = VERTEX;
	vec3 p = s * boite + deriv * TIME * UV2.y;
	p += vec3(sin(TIME * 0.3 + s.x * 40.0), cos(TIME * 0.27 + s.y * 40.0), sin(TIME * 0.21 + s.z * 40.0)) * 0.3;
	p = cam + (fract((p - cam) / boite + 0.5) - 0.5) * boite;
	float dist = length(p - cam);
	fondu = smoothstep(boite.x * 0.5, boite.x * 0.3, dist) * smoothstep(0.4, 1.2, dist);
	lumiere = COLOR.r;
	vec3 vc = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	float finesse = mix(0.92, 1.08, clamp(v12_qualite, 0.6, 1.3) / 1.3);
	vc.xy += UV * UV2.x * taille * finesse * (0.58 + dist * 0.12);
	VERTEX = vc;
}

void fragment() {
	float r = length(UV);
	float aa = max(fwidth(r) * 1.5, 0.002);
	float halo = 1.0 - smoothstep(0.16, 1.0 + aa, r);
	float coeur = 1.0 - smoothstep(0.0, 0.25 + aa, r);
	float a = halo * halo * 0.72 + coeur * (0.35 + 0.25 * v12_qualite);
	float variation = mix(0.72, 1.18, lumiere);
	vec3 col = couleur.rgb * variation;
	col = mix(col, vec3(1.0), coeur * 0.28);
	ALBEDO = col * a * couleur.a * fondu * v12_intensite;
}
