shader_type canvas_item;
render_mode blend_mix;

// Стена тьмы (2D-хоррор-сайдскроллер).
// Сплошная почти-чёрная масса справа, рваный ОСЫПАЮЩИЙСЯ фронт слева (справа -> налево).
// Узел сам ползёт по экрану (position управляется из логики), поэтому шейдер статичен
// в UV — отдельная анимация progress не нужна. Фронт «дышит» через TIME.
//
// Применяется как ShaderMaterial к ColorRect стены. Логика движения/урона не трогается:
// фронт по UV (front_pos) совпадает с игровой координатой фронта.

// rect_size задаётся из кода — реальный размер ColorRect в пикселях (для КВАДРАТНЫХ пикселей).
uniform vec2  rect_size = vec2(2400.0, 100.0);
uniform float pixel_size : hint_range(2.0, 48.0) = 2.0;       // ребро «пикселя», px
uniform float front_pos : hint_range(0.0, 1.0) = 0.50;       // позиция фронта по UV.x (= edge/total)
uniform float edge_raggedness : hint_range(0.0, 0.6) = 0.05; // разброс фронта (рваность/осыпание) — меньше = короче языки
uniform float edge_width : hint_range(0.0, 0.4) = 0.0;       // ширина зоны фиолетового ореола (UV)
uniform float purple_intensity : hint_range(0.0, 1.0) = 0.01; // сила фиолетового (слабый, атмосферный)
uniform float noise_scale : hint_range(0.1, 8.0) = 0.5;       // масштаб шумового паттерна осыпания
uniform float shimmer_speed : hint_range(0.0, 4.0) = 1.7;     // скорость «дыхания» фронта
uniform float front_softness : hint_range(0.0, 0.08) = 0.015; // мерцание фронта во времени — меньше = пиксели не размазывает далеко

const vec3 DARK     = vec3(0.0, 0.0, 0.0);       // чистый чёрный — сплошная масса
const vec3 PURPLE_A = vec3(0.165, 0.039, 0.227); // #2A0A3A
const vec3 PURPLE_B = vec3(0.290, 0.102, 0.353); // #4A1A5A

// Дешёвый хеш блока -> [0,1)
float hash(vec2 p) {
	p = fract(p * 0.3183099 + vec2(0.71, 0.113));
	p *= 17.0;
	return fract(p.x * p.y * (p.x + p.y));
}

void fragment() {
	// — Квадратная пикселизация в пиксельном пространстве (без сглаживания) —
	vec2 px    = UV * rect_size;
	vec2 block = floor(px / pixel_size);
	vec2 puv   = (block * pixel_size) / rect_size;

	// — Шум на блок + лёгкое мерцание во времени (фронт «дышит») —
	float n     = hash(block * noise_scale);
	float flick = sin(TIME * shimmer_speed + hash(block + 4.0) * 6.2831853);
	// Порог фронта смещается шумом (рваность) и временем (мерцание).
	float thr   = front_pos + (n - 0.5) * edge_raggedness + flick * front_softness;

	// Сплошняк справа от порога, прозрачность слева. Двумерный шум по блокам даёт
	// рассыпающиеся квадратные пиксели и кляксы у фронта — пиксельный dissolve.
	float a = step(thr, puv.x);

	// — Цвет: тёмная масса + еле заметный фиолетовый ореол ТОЛЬКО на фронтовых пикселях —
	vec3 col = DARK;
	float prox = 1.0 - smoothstep(0.0, edge_width, puv.x - thr); // 1 у фронта, 0 вглубь массы
	prox = clamp(prox, 0.0, 1.0) * a;                            // только на существующих пикселях
	vec3 purple = mix(PURPLE_A, PURPLE_B, n);
	col = mix(col, purple, prox * purple_intensity);
	col += purple * prox * purple_intensity * 0.12;             // едва заметный подъём яркости на кромке

	COLOR = vec4(col, a);
}
