
shader_type canvas_item;
render_mode unshaded;

// Alpha value to apply with dithering
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
// Size of the dither matrix to use (2x2, 4x4, or 8x8)
uniform int bayer_size : hint_enum("2x2", "4x4", "8x8") = 1;

// Bayer matrix 2x2
const int bayer2[4] = {
	0, 2,
	3, 1
};

// Bayer matrix 4x4
const int bayer4[16] = {
	0, 8, 2, 10,
	12, 4, 14, 6,
	3, 11, 1, 9,
	15, 7, 13, 5
};

// Bayer matrix 8x8
const int bayer8[64] = {
	0, 32,  8, 40,  2, 34, 10, 42,
	48, 16, 56, 24, 50, 18, 58, 26,
	12, 44,  4, 36, 14, 46,  6, 38,
	60, 28, 52, 20, 62, 30, 54, 22,
	3, 35, 11, 43,  1, 33,  9, 41,
	51, 19, 59, 27, 49, 17, 57, 25,
	15, 47,  7, 39, 13, 45,  5, 37,
	63, 31, 55, 23, 61, 29, 53, 21
};

float get_bayer2(vec2 screen_coord) {
	int x = int(mod(screen_coord.x, 2.0));
	int y = int(mod(screen_coord.y, 2.0));
	int index = y * 2 + x;
	return (float(bayer2[index]) + 0.5) / 4.0;
}

float get_bayer4(vec2 screen_coord) {
	int x = int(mod(screen_coord.x, 4.0));
	int y = int(mod(screen_coord.y, 4.0));
	int index = y * 4 + x;
	return (float(bayer4[index]) + 0.5) / 16.0;
}

float get_bayer8(vec2 screen_coord) {
	int x = int(mod(screen_coord.x, 8.0));
	int y = int(mod(screen_coord.y, 8.0));
	int index = y * 8 + x;
	return (float(bayer8[index]) + 0.5) / 64.0;
}

float get_dither_threshold(vec2 screen_coord) {
	if (bayer_size == 0) {
		return get_bayer2(screen_coord);
	} else if (bayer_size == 1) {
		return get_bayer4(screen_coord);
	} else {
		return get_bayer8(screen_coord);
	}
}

void fragment() {
	// Sample the sprite's built-in texture
	vec4 c = texture(TEXTURE, UV) * COLOR;
	
	// Calculate final alpha (texture alpha * modulate * uniform)
	float a = c.a * opacity;
	
	// Use texture-space coordinates for dither pattern
	// This locks the pattern to texture pixels, preventing drift when zooming
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	ivec2 tex_pixel = ivec2(floor(UV * tex_size));
	float threshold = get_dither_threshold(vec2(tex_pixel));
	
	// If alpha is below threshold, discard for dithered transparency
	if (a < threshold) discard;
	
	// Keep it fully opaque where it survives (classic hashed transparency look)
	c.a = 1.0;
	COLOR = c;
}
