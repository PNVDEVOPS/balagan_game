shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 0.3) = 0.07;

float hash(vec2 p, float t) {
	return fract(sin(dot(p + fract(t * 0.31), vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float grain = hash(UV * 350.0, TIME);
	grain = (grain - 0.5) * strength;
	// Slight warm tint bias for filmic feel
	COLOR = vec4(grain * 1.05, grain, grain * 0.92, abs(grain) * 3.5);
}
