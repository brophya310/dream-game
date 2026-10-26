shader_type spatial;
// Placeholder library floor: wooden planks with grass growing through in patches.
// Worked out from world position and snapped to the 32-pixels-per-unit grid.

uniform vec3 wood_a : source_color = vec3(0.43, 0.29, 0.19);
uniform vec3 wood_b : source_color = vec3(0.38, 0.25, 0.16);
uniform vec3 seam : source_color = vec3(0.25, 0.16, 0.11);
uniform vec3 grass_a : source_color = vec3(0.36, 0.55, 0.27);
uniform vec3 grass_b : source_color = vec3(0.29, 0.47, 0.24);
uniform float plank_width = 0.5;
uniform float board_length = 2.5;
uniform vec3 grass_edge : source_color = vec3(0.22, 0.36, 0.2);
uniform float grass_amount : hint_range(0.0, 1.0) = 0.36;
uniform float pixels_per_unit = 32.0;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float px = 1.0 / pixels_per_unit;
	vec2 p = floor(world_position.xz * pixels_per_unit) * px;

	float plank = floor(p.x / plank_width);
	float along = p.y + hash(vec2(plank, 3.0)) * board_length;
	float board = floor(along / board_length);
	vec3 color = mix(wood_a, wood_b, hash(vec2(plank, board)));
	bool side_seam = fract(p.x / plank_width) < px / plank_width;
	bool end_seam = fract(along / board_length) < px / board_length;
	if (side_seam || end_seam) {
		color = seam;
	}

	float grass = value_noise(p * 0.5) * 0.65 + value_noise(p * 2.0) * 0.35;
	float threshold = 1.0 - grass_amount;
	if (grass > threshold) {
		color = mix(grass_a, grass_b, step(0.55, value_noise(p * 5.0)));
		// Scattered single-pixel blades so the grass has texture.
		float speck = hash(p * pixels_per_unit);
		if (speck > 0.94) {
			color = grass_edge;
		} else if (speck > 0.9) {
			color = grass_a * 1.18;
		}
		// A darker rim where the grass meets the boards.
		if (grass < threshold + 0.025) {
			color = grass_edge;
		}
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
}
