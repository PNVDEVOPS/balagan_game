extends Node2D

const LOOP_MESSAGES: Array[String] = [
	"Дверь не поддаётся... Снаружи воет метель.",
	"Дверь не поддаётся. Снаружи — тишина. Метель стихла?",
	"Дверь заперта. На внешней стороне — что-то царапает.",
	"Дверь заперта. За ней — свет. Нужно закончить то, что начато."
]

func _ready() -> void:
	var door := get_node_or_null("DoorOutside")
	if door:
		var idx := clampi(GameManager.loop_state, 0, LOOP_MESSAGES.size() - 1)
		door.lock_message = LOOP_MESSAGES[idx]
	_apply_loop_visuals()

func _apply_loop_visuals() -> void:
	var scratch := get_node_or_null("LoopScratchMarks")
	if scratch:
		scratch.visible = GameManager.loop_state >= 2
