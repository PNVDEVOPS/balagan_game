extends Control

@onready var label: RichTextLabel = $ScrollContainer/CreditsText

func _ready() -> void:
	label.text = _credits_text()
	await get_tree().process_frame
	_scroll_credits()

func _credits_text() -> String:
	return """[center][b]БАЛАГАН[/b]
Якутский фолк-хоррор
[/center]

[center]─────────────────────[/center]

[center]Геймдизайн · История · Программирование[/center]

[center][имя разработчика][/center]

[center]─────────────────────[/center]

[center]Музыка и звук[/center]
[center][placeholder — будет добавлено][/center]

[center]Визуальный стиль[/center]
[center][placeholder — спрайты и фоны][/center]

[center]─────────────────────[/center]

[center][b]Особая благодарность[/b][/center]

[center]Всем, кто помогал тестировать игру.[/center]
[center]Тем, кто давал советы и поддержку.[/center]

[center]─────────────────────[/center]

[center][b]При поддержке[/b][/center]

[center][Название приюта для животных][/center]
[center]Потому что каждый верный друг заслуживает дома.[/center]

[center]─────────────────────[/center]

[center][i]В память о верных друзьях,[/i][/center]
[center][i]которые остаются рядом.[/i][/center]

[center][i]Посвящается всем собакам,[/i][/center]
[center][i]которые ждут нас у двери.[/i][/center]

[center]─────────────────────[/center]

[center][b]КОНЕЦ[/b][/center]

[center]Спасибо за игру.[/center]
"""

func _scroll_credits() -> void:
	var scroll: ScrollContainer = $ScrollContainer
	scroll.scroll_vertical = 0
	await get_tree().process_frame
	var content_height: int = int(label.get_content_height())
	var viewport_height: int = 360
	var scroll_distance: int = maxi(content_height - viewport_height + 60, 200)
	var duration: float = clampf(scroll_distance / 30.0, 12.0, 30.0)

	var tween := create_tween()
	tween.tween_property(scroll, "scroll_vertical", scroll_distance, duration)
	await tween.finished
	await get_tree().create_timer(4.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
