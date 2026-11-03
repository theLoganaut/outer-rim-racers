// Mode 7 ground: every screen pixel below the horizon is projected onto the baked track texture.
// Drawn on a 256x152 rect (screen rows HORIZON..H); UV maps 1:1 to its pixels.
shader_type canvas_item;

uniform sampler2D track_tex : filter_nearest, repeat_disable;
uniform vec2 cam_pos;
uniform vec2 cam_dir;        // (cos, sin) of the camera heading
uniform float cam_h = 80.0;
uniform float focal = 160.0;
uniform vec3 fog_rgb;
uniform float fog_start = 1600.0;
uniform float fog_range = 12000.0;
uniform float cave = 0.0;    // 0..1: darkens and tints towards cave rock
uniform vec3 ground_a;
uniform vec3 ground_b;

const float TEX_SIZE = 8192.0; // world size covered by the baked texture

void fragment() {
	float x = floor(UV.x * 256.0);
	float row = floor(UV.y * 152.0);
	float z = cam_h * focal / (row + 0.5);
	float sc = z / focal;
	vec2 right = vec2(-cam_dir.y, cam_dir.x);
	vec2 w = cam_pos + cam_dir * z + right * sc * (x - 128.0);
	vec3 c;
	if (w.x >= 0.0 && w.y >= 0.0 && w.x < TEX_SIZE && w.y < TEX_SIZE) {
		c = texture(track_tex, w / TEX_SIZE).rgb;
	} else {
		int chk = ((int(floor(w.x)) >> 5) + (int(floor(w.y)) >> 5)) & 1;
		c = chk == 1 ? ground_b : ground_a;
	}
	vec3 fogc = mix(fog_rgb, vec3(16.0, 12.0, 10.0) / 255.0, cave);
	if (cave > 0.02) c *= 1.0 - 0.55 * cave;
	float fog = clamp((z - fog_start) / fog_range, 0.0, 1.0);
	c = mix(c, fogc, floor(fog * 256.0) / 256.0);
	COLOR = vec4(c, 1.0);
}
