shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float v = dot(uv * vec2(0.8, 0.9), uv * vec2(0.8, 0.9));
	v = smoothstep(0.2, 1.1, v);
	COLOR = vec4(0.0, 0.0, 0.0, v * strength);
}
