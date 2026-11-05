shader_type sky;
// Cielo «Reborn»: campo di stelle a più strati e nebulose rosa e viola, come la copertina rivista.

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = mix(mix(mix(hash13(i), hash13(i + vec3(1,0,0)), f.x),
		mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), f.x),
		mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), f.x), f.y), f.z);
	return n;
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float stars(vec3 d, float scale, float thr) {
	vec3 p = d * scale;
	vec3 c = floor(p);
	float h = hash13(c);
	if (h < thr) return 0.0;
	vec3 f = fract(p) - 0.5;
	vec3 o = vec3(hash13(c + 7.0), hash13(c + 13.0), hash13(c + 29.0)) - 0.5;
	float d2 = length(f - o * 0.6);
	return smoothstep(0.08, 0.0, d2) * (h - thr) / (1.0 - thr);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float n1 = fbm(d * 2.2 + vec3(3.0, 1.0, 7.0));
	float n2 = fbm(d * 4.5 + vec3(11.0, 5.0, 2.0));
	vec3 neb = vec3(0.0);
	neb += vec3(0.55, 0.12, 0.30) * smoothstep(0.45, 0.85, n1) * 0.55;
	neb += vec3(0.20, 0.10, 0.45) * smoothstep(0.5, 0.9, n2) * 0.45;
	neb += vec3(0.9, 0.55, 0.2) * pow(smoothstep(0.62, 0.95, n1 * n2 * 1.6), 2.0) * 0.25;
	// fascia galattica
	float band = exp(-pow(d.y * 3.2 + 0.3 * sin(d.x * 3.0), 2.0));
	neb += vec3(0.35, 0.28, 0.40) * band * fbm(d * 8.0) * 0.35;
	float s = stars(d, 180.0, 0.985) * 1.4 + stars(d, 420.0, 0.992) * 0.9 + stars(d, 90.0, 0.995) * 2.5;
	vec3 col = vec3(0.012, 0.008, 0.02) + neb + vec3(s) * vec3(1.0, 0.95, 0.9);
	COLOR = col;
}
