shader_type spatial;
render_mode unshaded, cull_back;
// Superficie stellare «Reborn»: granulazione che ribolle, macchie e facole, rotazione, oscuramento al
// bordo. Il colore dipende dal tipo spettrale (A bianco-azzurro ... M rosso).

uniform vec3 base_color : source_color = vec3(1.0, 0.9, 0.6);
uniform vec3 hot_color : source_color = vec3(1.0, 1.0, 0.9);
uniform vec3 cool_color : source_color = vec3(0.8, 0.3, 0.1);
uniform float spin = 0.15;          // velocità di rotazione (radianti al secondo)
uniform float boil = 0.25;          // velocità del ribollire della superficie
uniform float spots = 0.5;          // quantità di macchie (0 = nessuna)
uniform float seed = 0.0;
uniform float energy = 1.8;

varying vec3 opos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1,0,0)), f.x),
		mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), f.x),
		mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 4.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	opos = normalize(VERTEX);
}

void fragment() {
	// rotazione intorno all'asse della stella
	float a = TIME * spin + seed * 6.2831;
	float c = cos(a);
	float s = sin(a);
	vec3 p = vec3(c * opos.x - s * opos.z, opos.y, s * opos.x + c * opos.z);
	float t = TIME * boil;
	// granulazione: celle che ribollono
	float g = fbm(p * 7.0 + vec3(seed * 13.0, t, -t * 0.7));
	float g2 = fbm(p * 18.0 - vec3(t * 1.3, seed * 7.0, t));
	float gran = 0.55 * g + 0.45 * g2;
	// macchie scure e facole chiare, a bande di latitudine
	float lat = 1.0 - abs(p.y);
	float sp = smoothstep(0.62, 0.78, fbm(p * 3.0 + vec3(seed * 5.0, t * 0.15, 0.0))) * smoothstep(0.3, 0.8, lat) * spots;
	vec3 col = mix(cool_color, hot_color, smoothstep(0.32, 0.72, gran));
	col = mix(col, base_color, 0.25);
	col = mix(col, cool_color * 0.35, sp);
	// oscuramento al bordo
	float mu = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float limb = 0.35 + 0.65 * pow(mu, 0.45);
	ALBEDO = col * limb * energy;
}
