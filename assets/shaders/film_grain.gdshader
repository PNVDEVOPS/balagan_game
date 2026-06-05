shader_type canvas_item;
render_mode unshaded;

// «Телевизорный» шум: разрежённые жёсткие точки, пересыпаются fps раз/сек.
// Хеш без sin (Hoskins) + пересев по кадру -> по-настоящему хаотично, без видимых паттернов.

uniform float strength : hint_range(0.0, 0.3) = 0.05;
uniform float density : hint_range(80.0, 640.0) = 260.0;  // плотность точек по ширине
uniform float fps : hint_range(8.0, 60.0) = 30.0;         // частота пересыпания (выше = хаотичнее)
uniform float coverage : hint_range(0.0, 1.0) = 0.35;     // доля экрана с шумом

// Хеш-без-синуса: каждый блок+кадр даёт независимое случайное значение.
float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	float frame = floor(TIME * fps);
	vec2 cell = floor(UV * vec2(density, density * 0.75));
	// Само значение точки и её «включённость» — два независимых случайных потока на кадр.
	float n    = hash3(vec3(cell, frame));
	float g    = hash3(vec3(cell, frame) * 1.7 + 5.0);
	float gate = step(1.0 - coverage, g);
	float v = (n - 0.5) * gate * strength * 2.0;
	COLOR = vec4(v, v, v, abs(v) * 4.0);
}
