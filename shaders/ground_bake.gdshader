// Paints the open ground of the whole 4096x4096 track texture (one texel == one world unit).
shader_type canvas_item;

uniform vec3 ground_a;
uniform vec3 ground_b;
uniform float tscale = 2.0; // world units per texel
uniform int style; // 0 dunes, 1 snow, 2 acidrock, 3 jungle, 4 salt, 5 arena
uniform sampler2D noise1 : filter_nearest, repeat_disable;
uniform sampler2D noise2 : filter_nearest, repeat_disable;

vec3 rgb(float r, float g, float b) {
	return vec3(r, g, b) / 255.0;
}

uint hash2(int x, int y) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return h ^ (h >> 16u);
}

float lattice(sampler2D t, int x, int y) {
	return texelFetch(t, ivec2(x & 63, y & 63), 0).r;
}

// value noise on a 64x64 wrapped lattice
float vnoise(sampler2D t, float x, float y) {
	float fx0 = floor(x);
	float fy0 = floor(y);
	float fx = x - fx0;
	float fy = y - fy0;
	float sx = fx * fx * (3.0 - 2.0 * fx);
	float sy = fy * fy * (3.0 - 2.0 * fy);
	int xi = int(fx0);
	int yi = int(fy0);
	float a = lattice(t, xi, yi);
	float b = lattice(t, xi + 1, yi);
	float c = lattice(t, xi, yi + 1);
	float d = lattice(t, xi + 1, yi + 1);
	return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy;
}

void fragment() {
	int x = int(FRAGCOORD.x * tscale);
	int y = int(FRAGCOORD.y * tscale);
	uint h = hash2(x, y);
	int chk = ((x >> 5) + (y >> 5)) & 1;
	vec3 base = chk == 1 ? ground_b : ground_a;
	vec3 c = base;
	vec3 g_dark = base * (1.0 - 0.14);
	vec3 g_lite = base + (vec3(1.0) - base) * 0.12;
	float bx = float(x >> 2);
	float by = float(y >> 2);
	float a = vnoise(noise1, bx * 4.0 / 120.0 + 3.0, by * 4.0 / 120.0 + 7.0);
	float b = vnoise(noise2, bx * 4.0 / 40.0 + 11.0, by * 4.0 / 40.0 + 2.0);
	float da = abs(a - 0.5);
	if (style == 0) {
		if (a > 0.62) c = g_dark;
		else if (b > 0.7) c = g_lite;
		if ((h & 15u) == 0u) c = g_dark;
	} else if (style == 1) {
		if (da < 0.012) c = rgb(168.0, 188.0, 216.0);
		else if (b > 0.72) c = rgb(200.0, 216.0, 238.0);
		else if ((h & 31u) == 0u) c = vec3(1.0);
	} else if (style == 2) {
		if (da < 0.03) c = rgb(184.0, 208.0, 24.0);
		else if (da < 0.05) c = rgb(106.0, 122.0, 16.0);
		else if (b > 0.7) c = rgb(74.0, 74.0, 84.0);
		else if ((h & 15u) == 0u) c = g_lite;
	} else if (style == 3) {
		if (da < 0.04) c = rgb(58.0, 120.0, 192.0);
		else if (b > 0.64) c = rgb(30.0, 80.0, 40.0);
		else if ((h & 15u) == 0u) c = g_lite;
	} else if (style == 4) {
		if (da < 0.018) c = rgb(180.0, 64.0, 48.0);
		else if (b > 0.8) c = rgb(200.0, 80.0, 64.0);
		else if ((h & 31u) == 0u) c = vec3(1.0);
	} else if (style == 5) {
		if ((x & 63) < 2 || (y & 63) < 2) c = rgb(106.0, 90.0, 138.0);
		if (da < 0.008) c = rgb(64.0, 232.0, 255.0);
		else if ((h & 31u) == 0u) c = g_lite;
	}
	COLOR = vec4(c, 1.0);
}
