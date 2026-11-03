## Renders a Track into a 4096x4096 texture on the GPU (ground, curbs, shortcut lanes, road).
## Replaces the reference's per-pixel CPU painting; the look is driven by shaders/*_bake.gdshader.
class_name TrackBaker
extends Node

const SIZE := int(Track.T / Track.TEXEL)
const STYLE_IDS := {"dunes": 0, "snow": 1, "acidrock": 2, "jungle": 3, "salt": 4, "arena": 5}
const CODE_BASE := 2048.0

var viewport: SubViewport
var _root: Node2D    # scaled so world units map to texels
var _ground: ColorRect
var _outer: MeshInstance2D
var _road: MeshInstance2D
var _shortcut_root: Node2D
var _ground_mat: ShaderMaterial
var _outer_mat: ShaderMaterial
var _road_mat: ShaderMaterial
var _shortcut_shader: Shader


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)

	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = load("res://shaders/ground_bake.gdshader")
	_root = Node2D.new()
	_root.scale = Vector2.ONE / Track.TEXEL
	viewport.add_child(_root)
	_ground = ColorRect.new()
	_ground.size = Vector2(Track.T, Track.T)
	_ground.material = _ground_mat
	_root.add_child(_ground)

	var road_shader: Shader = load("res://shaders/road_bake.gdshader")
	_outer_mat = ShaderMaterial.new()
	_outer_mat.shader = road_shader
	_outer_mat.set_shader_parameter("road_pass", false)
	_road_mat = ShaderMaterial.new()
	_road_mat.shader = road_shader
	_road_mat.set_shader_parameter("road_pass", true)

	_outer = MeshInstance2D.new()
	_outer.material = _outer_mat
	_root.add_child(_outer)
	_shortcut_root = Node2D.new()
	_root.add_child(_shortcut_root)
	_road = MeshInstance2D.new()
	_road.material = _road_mat
	_root.add_child(_road)
	_shortcut_shader = load("res://shaders/shortcut_bake.gdshader")


func texture() -> Texture2D:
	return viewport.get_texture()


static func _noise_tex(data: PackedFloat32Array) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(64, 64, false, Image.FORMAT_RF, data.to_byte_array()))


static func _split_vec(trk: Track, k: int) -> Vector4:
	if k >= trk.splits.size():
		return Vector4.ZERO
	var sp: Dictionary = trk.splits[k]
	return Vector4(sp.s0, sp.s1, sp.D, 0.0)


static func _mix(a: Color, b: Color, t: float) -> Color:
	return Color(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1.0)


## One quad per path segment so the per-segment flags stay constant across it.
static func _road_mesh(trk: Track) -> ArrayMesh:
	var n := trk.n
	var dmax := 0.0
	for sp in trk.splits:
		dmax = maxf(dmax, sp.D)
	var ext := trk.half + Track.VERGE + Track.WALL_W + dmax
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(n * 4)
	uvs.resize(n * 4)
	idx.resize(n * 6)
	for i in n:
		var j := (i + 1) % n
		var ni := Vector2(-trk.sin_a[i], trk.cos_a[i])
		var nj := Vector2(-trk.sin_a[j], trk.cos_a[j])
		var pi_ := trk.pts[i]
		var pj := trk.pts[j]
		var si := (i - n if i > n / 2 else i) * trk.dsa
		var side := trk.hz_side[i] + 1
		var code := trk.hz_type[i] + 7 * side + 21 * trk.hz_edge[i] + 63 * trk.fume[i]
		var base := code * CODE_BASE
		var o := i * 4
		verts[o] = pi_ - ni * ext
		verts[o + 1] = pi_ + ni * ext
		verts[o + 2] = pj - nj * ext
		verts[o + 3] = pj + nj * ext
		uvs[o] = Vector2(base - ext, si)
		uvs[o + 1] = Vector2(base + ext, si)
		uvs[o + 2] = Vector2(base - ext, si + trk.dsa)
		uvs[o + 3] = Vector2(base + ext, si + trk.dsa)
		var k := i * 6
		idx[k] = o
		idx[k + 1] = o + 1
		idx[k + 2] = o + 2
		idx[k + 3] = o + 1
		idx[k + 4] = o + 3
		idx[k + 5] = o + 2
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Paints the track; completes once the texture is ready to sample.
func bake(trk: Track) -> void:
	var pl: Dictionary = trk.planet
	var ga := Color.html(pl.ground[0])
	var gb := Color.html(pl.ground[1])
	_ground_mat.set_shader_parameter("ground_a", Vector3(ga.r, ga.g, ga.b))
	_ground_mat.set_shader_parameter("ground_b", Vector3(gb.r, gb.g, gb.b))
	_ground_mat.set_shader_parameter("style", STYLE_IDS[pl.groundStyle])
	_ground_mat.set_shader_parameter("noise1", _noise_tex(trk.noise1))
	_ground_mat.set_shader_parameter("noise2", _noise_tex(trk.noise2))

	var road_a := _mix(Color.html(pl.road[0]), Color.BLACK, 0.07)
	var road_b := _mix(Color.html(pl.road[1]), Color.WHITE, 0.07)
	var wall := _mix(ga, Color.BLACK, 0.55)
	var cols := {
		"half_w": trk.half,
		"verge_w": Track.VERGE,
		"edge_amp": Track.EDGE_AMP,
		"edge_k1": trk.edge_k1,
		"edge_k2": trk.edge_k2,
		"wall_w": Track.WALL_W,
		"track_len": trk.length,
		"split_a": _split_vec(trk, 0),
		"split_b": _split_vec(trk, 1),
		"road_a": road_a,
		"road_b": road_b,
		"road_speck": _mix(road_a, Color.BLACK, 0.25),
		"ground_a": ga,
		"ground_b": gb,
		"wall_col": wall,
		"wall_hi": _mix(wall, Color.WHITE, 0.22),
	}
	for k in cols:
		_outer_mat.set_shader_parameter(k, cols[k])
		_road_mat.set_shader_parameter(k, cols[k])
	var mesh := _road_mesh(trk)
	_outer.mesh = mesh
	_road.mesh = mesh

	for c in _shortcut_root.get_children():
		c.queue_free()
	for s in trk.shortcuts:
		var r := ColorRect.new()
		var lo: Vector2 = Vector2(minf(s.a.x, s.b.x), minf(s.a.y, s.b.y)) - Vector2.ONE * (Track.SHORTCUT_W + 2.0)
		var hi: Vector2 = Vector2(maxf(s.a.x, s.b.x), maxf(s.a.y, s.b.y)) + Vector2.ONE * (Track.SHORTCUT_W + 2.0)
		r.position = lo
		r.size = hi - lo
		var m := ShaderMaterial.new()
		m.shader = _shortcut_shader
		m.set_shader_parameter("seg_a", s.a)
		m.set_shader_parameter("seg_b", s.b)
		m.set_shader_parameter("lane_w", Track.SHORTCUT_W)
		r.material = m
		_shortcut_root.add_child(r)

	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
