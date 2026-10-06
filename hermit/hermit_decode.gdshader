shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D palette : filter_nearest, repeat_disable;
uniform sampler2D indices : filter_nearest, repeat_disable;
uniform ivec2 frame_size = ivec2(1, 1);

void fragment() {
	ivec2 px = min(ivec2(UV * vec2(frame_size)), frame_size - ivec2(1));
	ivec2 cell = px / 4;
	vec4 e = round(texelFetch(indices, cell, 0) * 255.0);
	int idx = int(e.r) + int(e.g) * 256 + int(e.b) * 65536;
	int per_row = textureSize(palette, 0).x / 4;
	COLOR = texelFetch(palette, ivec2(idx % per_row, idx / per_row) * 4 + px - cell * 4, 0);
}