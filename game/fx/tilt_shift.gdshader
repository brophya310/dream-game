shader_type canvas_item;
// Miniature / diorama look (like the Link's Awakening remake): the middle band of
// the screen stays sharp and the top and bottom blur out.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// Where the sharp band sits, from 0 (top) to 1 (bottom).
uniform float focus_center : hint_range(0.0, 1.0) = 0.5;
// Half-height of the fully sharp band.
uniform float focus_half_height : hint_range(0.0, 0.5) = 0.18;
// How far the blur takes to reach full strength past the sharp band.
uniform float falloff : hint_range(0.01, 1.0) = 0.3;
// Blur radius in pixels at full strength.
uniform float blur_radius : hint_range(0.0, 8.0) = 2.5;
// A touch of extra colour in the blurred areas sells the toy-like look.
uniform float saturation_boost : hint_range(0.0, 0.5) = 0.08;

void fragment() {
	float distance_from_focus = abs(SCREEN_UV.y - focus_center);
	float amount = smoothstep(focus_half_height, focus_half_height + falloff, distance_from_focus);

	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	if (amount > 0.001) {
		vec2 step_uv = SCREEN_PIXEL_SIZE * blur_radius * amount;
		float lod = amount * 1.5;
		vec3 sum = vec3(0.0);
		// 3x3 taps on top of a slightly lower mip gives a soft, cheap blur.
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				sum += textureLod(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * step_uv, lod).rgb;
			}
		}
		color = mix(color, sum / 9.0, amount);
		float luma = dot(color, vec3(0.299, 0.587, 0.114));
		color = mix(vec3(luma), color, 1.0 + saturation_boost * amount);
	}
	COLOR = vec4(color, 1.0);
}
