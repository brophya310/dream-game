shader_type spatial;
// A crisp oval shadow under sprite characters (billboard sprites can't cast real shadows).
// Also the base for "shadow-first" aerial threats: grow it and sharpen it before they drop in.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 shadow_color : source_color = vec4(0.06, 0.03, 0.10, 0.45);
// 0 = hard pixel edge, higher = softer.
uniform float softness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float edge = softness > 0.0 ? 1.0 - smoothstep(1.0 - softness, 1.0, d) : step(d, 1.0);
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * edge;
}
