shader_type canvas_item;
render_mode unshaded;

// PS1-стиль на ВЕСЬ кадр: жёсткая пикселизация до фиксированного «PS1-разрешения»
// (не зависит от размера окна) + лёгкое снижение глубины цвета. Без шумного дизеринга,
// чтобы не рябило в глазах. Вешается на полноэкранный ColorRect в HUD ниже виньетки/шума.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float target_width : hint_range(160.0, 960.0) = 320.0; // целевая ширина в «пикселях» (меньше = крупнее пиксель)
uniform float color_levels : hint_range(8.0, 64.0) = 48.0;     // ступеней цвета на канал (меньше = сильнее бандинг)
uniform float dither : hint_range(0.0, 1.0) = 0.0;             // опциональный дизеринг (0 = выкл, без ряби)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// — Пикселизация в фиксированную сетку target_width x (по аспекту экрана) —
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;   // ширина/высота
	vec2 res     = vec2(target_width, max(1.0, floor(target_width / aspect)));
	vec2 block   = floor(SCREEN_UV * res);
	vec2 suv     = (block + 0.5) / res;
	vec3 col     = texture(screen_tex, suv).rgb;

	// — Снижение глубины цвета (стабильное, без мерцания) —
	if (dither > 0.0) {
		col += (hash(block) - 0.5) * dither / color_levels;
	}
	col = floor(col * color_levels + 0.5) / color_levels;

	COLOR = vec4(col, 1.0);
}
