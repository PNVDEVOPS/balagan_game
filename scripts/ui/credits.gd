extends Control

@onready var label: RichTextLabel = $RichTextLabel

func _ready() -> void:
	label.text = ""
	_play_credits()

func _play_credits() -> void:
	await get_tree().create_timer(2.0).timeout
	label.text = "[center]В память о верных друзьях,\nкоторые остаются рядом.[/center]"
	await get_tree().create_timer(4.0).timeout
	label.text = "[center]Они ждут тебя.\n\n[Название приюта][/center]"
	await get_tree().create_timer(5.0).timeout
	label.text = "[center]БАЛАГАН\n\nСпасибо за игру.[/center]"
	await get_tree().create_timer(5.0).timeout
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		get_tree().quit()
