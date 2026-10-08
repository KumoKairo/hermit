shader_type canvas_item;
// render_mode unshaded, blend_disabled;

uniform sampler2D palette : filter_nearest, repeat_disable;
uniform sampler2D indices : filter_nearest, repeat_disable;
uniform ivec2 frame_size = ivec2(1, 1);

void fragment() {
	ivec2 px = clamp(ivec2(UV / TEXTURE_PIXEL_SIZE), ivec2(0), frame_size - ivec2(1));
	ivec2 cell = px / 4;
	// belt and suspenders here - texelFetch ignores filtering and wrapping anyway
	vec4 e = round(texelFetch(indices, cell, 0) * 255.0);
	int idx = int(e.r) + int(e.g) * 256 + int(e.b) * 65536;
	// can be easily converted to a uniform or a hardcoded value (it's a hardcoded value on the GDscript side)
	// left as a calculated value here for robustness
	int per_row = textureSize(palette, 0).x / 4; 
	COLOR = texelFetch(palette, ivec2(idx % per_row, idx / per_row) * 4 + px - cell * 4, 0);
}