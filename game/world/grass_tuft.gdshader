shader_type spatial;
// Grass tufts: lit as if they were the ground they grow from (so their shaded
// sides don't go grey), darker at the root and lighter at the tip.
// Per-tuft colour comes from the MultiMesh instance colour.
render_mode cull_disabled;

uniform float root_shade : hint_range(0.0, 1.0) = 0.7;
uniform float tip_light : hint_range(1.0, 2.0) = 1.2;
// Half the blade height in local units (CylinderMesh is centred on its origin).
uniform float half_height = 0.16;

varying float height_fraction;

void vertex() {
	height_fraction = clamp(VERTEX.y / (half_height * 2.0) + 0.5, 0.0, 1.0);
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = COLOR.rgb * mix(root_shade, tip_light, height_fraction);
	ROUGHNESS = 1.0;
}
