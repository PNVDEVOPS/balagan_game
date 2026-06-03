shader_type canvas_item;

uniform float breathe_speed : hint_range(0.1, 3.0) = 0.35;
uniform float breathe_amount : hint_range(0.0, 0.4) = 0.10;
uniform float flicker_speed : hint_range(0.5, 15.0) = 4.0;
uniform float flicker_amount : hint_range(0.0, 0.3) = 0.07;

float rand(float t) {
	return fract(sin(t * 127.1 + 0.3) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	float breathe = 1.0 - breathe_amount * (0.5 - 0.5 * cos(TIME * breathe_speed));
	float ft = floor(TIME * flicker_speed);
	float flicker = 1.0 - flicker_amount * step(0.88, rand(ft));

	COLOR = tex * (breathe * flicker);
}
