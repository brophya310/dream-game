shader_type spatial;
// Footprints drawn by FootprintTrail. The texture is a row of square frames; each
// print picks its frame from INSTANCE_CUSTOM.x and fades out with its colour's alpha.
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D prints : source_color, filter_nearest;
uniform float frames = 2.0;
uniform vec4 tint : source_color = vec4(0.16, 0.1, 0.06, 0.5);

varying flat float frame;
varying float fade;

void vertex() {
	frame = INSTANCE_CUSTOM.x;
	fade = COLOR.a;
}

void fragment() {
	float coverage = texture(prints, vec2((UV.x + frame) / frames, UV.y)).a;
	ALBEDO = tint.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = tint.a * coverage * fade;
}
