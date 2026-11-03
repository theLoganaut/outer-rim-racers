// Paints the drivable terrain strip into the track texture. The mesh carries, per vertex:
//   UV.x = 1024 * flags + lateral offset from the centreline   (flags = type + 7*(side+1) + 21*edge + 63*fume)
//   UV.y = distance along the track from the start line
// Zones by effective lateral distance: packed road | rough verge fading into the ground | rock wall.
// Two passes share this shader: the road surface (road_pass) and everything outside it.
shader_type canvas_item;

uniform bool road_pass = true;
uniform float tscale = 2.0;
uniform float half_w = 140.0;
uniform float verge_w = 130.0;
uniform float edge_amp = 14.0;
uniform float edge_k1 = 0.02;
uniform float edge_k2 = 0.05;
uniform float wall_w = 70.0;
uniform float track_len = 20000.0;
uniform vec4 split_a = vec4(0.0); // (s0, s1, D, unused): alternate routes
uniform vec4 split_b = vec4(0.0);
uniform vec4 road_a;
uniform vec4 road_b;
uniform vec4 road_speck;
uniform vec4 ground_a;
uniform vec4 ground_b;
uniform vec4 wall_col;
uniform vec4 wall_hi;

varying vec2 v_uv;

vec3 rgb(float r, float g, float b) {
	return vec3(r, g, b) / 255.0;
}

uint hash2(int x, int y) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return h ^ (h >> 16u);
}

void vertex() {
	v_uv = UV;
}

void fragment() {
	float code_f = floor((v_uv.x + 1024.0) / 2048.0);
	float lat = v_uv.x - 2048.0 * code_f;
	int code = int(code_f);
	float s = v_uv.y;
	float eo = edge_amp * 0.5 * (sin(s * edge_k1) + sin(s * edge_k2 + 1.7));
	float sm = mod(s, track_len);
	float off = 0.0;
	if (sm > split_a.x && sm < split_a.y) {
		float t = (sm - split_a.x) / (split_a.y - split_a.x);
		float u = clamp(min(t, 1.0 - t) / 0.3, 0.0, 1.0);
		off = max(off, split_a.z * u * u * (3.0 - 2.0 * u));
	}
	if (sm > split_b.x && sm < split_b.y) {
		float t = (sm - split_b.x) / (split_b.y - split_b.x);
		float u = clamp(min(t, 1.0 - t) / 0.3, 0.0, 1.0);
		off = max(off, split_b.z * u * u * (3.0 - 2.0 * u));
	}
	float lc = off > 0.0 ? lat - sign(lat) * off : lat;   // lateral position relative to the road we are on
	float ar = abs(lc) + eo;
	if (ar > half_w + verge_w + wall_w) discard;
	bool on_road = ar <= half_w;
	if (road_pass != on_road) discard;

	ivec2 p = ivec2(FRAGCOORD.xy * tscale);
	uint h = hash2(p.x, p.y);
	vec3 c;

	if (on_road) {
		int ht = code % 7;
		int side = (code / 7) % 3 - 1;
		bool fume = code >= 63;
		// worn, patchy surface with darker wheel ruts either side of the centre
		uint hb = hash2(p.x >> 4, p.y >> 4) & 3u;
		c = hb == 0u ? road_a.rgb : hb == 3u ? mix(road_a.rgb, road_b.rgb, 0.5) : road_b.rgb;
		float rut = abs(abs(lc) - 34.0);
		if (rut < 9.0) c = mix(c, road_speck.rgb, 0.45);
		if ((h & 15u) == 0u) c = road_speck.rgb;
		bool hz_here = ht != 0 && (side == 0 || (side > 0) == (lat > 0.0));
		if (hz_here && ht == 6) c = mix(c, road_speck.rgb, 0.35 + 0.3 * float((h >> 3u) & 1u));
		if (hz_here && ht >= 2 && ht <= 5) {
			if (ht == 2) {
				c = (h & 7u) == 0u ? vec3(1.0) : ((h >> 4u) & 1u) == 1u ? rgb(196.0, 232.0, 255.0) : rgb(168.0, 212.0, 240.0);
			} else if (ht == 3) {
				c = (h & 15u) == 0u ? rgb(232.0, 255.0, 80.0) : (h >> 4u) % 6u == 0u ? rgb(138.0, 168.0, 16.0) : rgb(184.0, 216.0, 24.0);
			} else if (ht == 4) {
				uint hl = hash2(p.x >> 3, p.y >> 3) & 3u;
				c = hl == 0u ? rgb(58.0, 20.0, 8.0) : hl == 1u ? rgb(255.0, 200.0, 72.0) : hl == 2u ? rgb(255.0, 138.0, 32.0) : rgb(232.0, 90.0, 16.0);
			} else if (ht == 5) {
				c = ((p.y + int(s)) & 7) < 1 ? rgb(154.0, 200.0, 255.0) : ((h >> 3u) & 1u) == 1u ? rgb(47.0, 108.0, 192.0) : rgb(90.0, 154.0, 232.0);
			}
		}
		if (fume) c = mix(c, rgb(154.0, 176.0, 48.0), 0.28);
		if (abs(s) < 20.0) { // start / finish strip
			if (((int(floor(lat / 20.0)) + int(floor(s / 20.0))) & 1) != 0) c = rgb(24.0, 24.0, 24.0);
			else c = vec3(1.0);
		}
	} else if (ar <= half_w + verge_w) {
		// rough verge: churned road material fading into the surrounding ground
		float t = (ar - half_w) / verge_w;
		vec3 g = ((p.x >> 5) + (p.y >> 5) & 1) == 1 ? ground_b.rgb : ground_a.rgb;
		uint hp = hash2(p.x >> 3, p.y >> 3) & 7u;
		vec3 base = mix(road_b.rgb, g, smoothstep(0.0, 0.7, t + (float(hp) - 3.5) * 0.04));
		c = base;
		if ((h & 7u) == 0u) c = mix(c, road_speck.rgb, 0.5);
		else if (hp == 0u && t > 0.3) c = mix(c, wall_col.rgb, 0.45); // stones and debris
	} else {
		// canyon / rock wall
		c = wall_col.rgb;
		if (ar < half_w + verge_w + 8.0) c = wall_hi.rgb;
		else if ((h & 15u) == 0u) c = wall_hi.rgb;
		else if (((p.x >> 3) + (p.y >> 4) & 3) == 0) c = mix(c, wall_hi.rgb, 0.2);
	}
	COLOR = vec4(c, 1.0);
}
