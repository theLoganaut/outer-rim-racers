// A gravel lane (capsule around the segment a-b) with orange rails, painted over open ground.
shader_type canvas_item;

uniform vec2 seg_a;
uniform vec2 seg_b;
uniform float lane_w = 40.0;
uniform float tscale = 2.0;

uint hash2(int x, int y) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return h ^ (h >> 16u);
}

void fragment() {
	vec2 p = floor(FRAGCOORD.xy * tscale);
	vec2 ab = seg_b - seg_a;
	float t = clamp(dot(p - seg_a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	float dd = distance(p, seg_a + ab * t);
	if (dd > lane_w) discard;
	vec3 c;
	if (dd > lane_w - 4.0) c = vec3(200.0, 100.0, 30.0) / 255.0;
	else if ((hash2(int(p.x), int(p.y)) & 7u) == 0u) c = vec3(106.0, 92.0, 76.0) / 255.0;
	else c = vec3(138.0, 122.0, 104.0) / 255.0;
	COLOR = vec4(c, 1.0);
}
