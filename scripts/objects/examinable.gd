extends Interactable

signal examined()

@export_multiline var examine_text: String = ""

# Иконка-глаз: всегда висит полупрозрачной, при приближении игрока — непрозрачной.
const ICON_NEAR_DIST := 30.0     # ближе этого (почти вплотную) — alpha 1.0
const ICON_FAR_DIST  := 90.0     # дальше этого — тусклый ICON_FAR_ALPHA
const ICON_FAR_ALPHA := 0.2      # прозрачность в покое

@onready var _icon: Node2D = get_node_or_null("ExamineIcon")
@onready var _icon_key: Label = get_node_or_null("ExamineIcon/Key")
var _player: Node2D = null

func _ready() -> void:
	super._ready()
	interaction_type = Type.EXAMINABLE

func _process(_delta: float) -> void:
	if _icon == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	# Прозрачность плавно растёт по мере приближения игрока.
	var d := global_position.distance_to(_player.global_position)
	var t := clampf(inverse_lerp(ICON_FAR_DIST, ICON_NEAR_DIST, d), 0.0, 1.0)
	_icon.modulate.a = lerpf(ICON_FAR_ALPHA, 1.0, t)
	# Подсказка [E] — только когда именно этот объект в фокусе луча игрока.
	if _icon_key:
		_icon_key.visible = _player.get("nearest_interactable") == self

func interact(_player_node: CharacterBody2D) -> void:
	# Сначала emit — room-логика может запустить NotePopup или start_dialogue
	examined.emit()
	# show_text только если обработчик не открыл своё окно
	if not examine_text.is_empty() and not DialogueManager.is_active:
		DialogueManager.show_text("", examine_text)
