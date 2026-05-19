extends Node2D

enum KamylokState { COLD, BURNING, RITUAL_READY, RITUAL_ACTIVE }

static var _wake_up_shown: bool = false

var kamylok_state: KamylokState = KamylokState.COLD
var ritual_items: Array[String] = []
const CORRECT_ORDER: Array[String] = ["amulet", "doll", "earring"]
const ARTIFACT_NAMES: Dictionary = {
	"amulet": "амулет",
	"doll": "куклу",
	"earring": "серёжку"
}

func _ready() -> void:
	if not _wake_up_shown and ChapterManager.current_chapter == ChapterManager.Chapter.BALAGAN \
			and GameManager.artifacts_collected.is_empty():
		_wake_up_shown = true
		await get_tree().process_frame
		await get_tree().process_frame
		DialogueManager.start_dialogue("chapter2_balagan/wake_up")

	_apply_loop_visuals()
	_setup_puzzle()

func _setup_puzzle() -> void:
	var amulet_done := GameManager.artifacts_collected.has("amulet")

	if amulet_done:
		for node_name in ["KeyPickable", "ChestAmulet", "AmuletPickable", "WoodPickable"]:
			var n = get_node_or_null(node_name)
			if n:
				n.queue_free()
		kamylok_state = KamylokState.BURNING

	if _all_artifacts_collected():
		kamylok_state = KamylokState.RITUAL_READY

	var kamylok := get_node_or_null("Kamyolk")
	if kamylok:
		kamylok.examined.connect(_on_kamylok_examined)

	var riddle := get_node_or_null("RiddleKamyolk")
	if riddle:
		riddle.examined.connect(func(): DialogueManager.start_dialogue("notes/riddle_kamyolk"))

	if not amulet_done:
		var chest := get_node_or_null("ChestAmulet")
		if chest:
			chest.item_used.connect(_on_chest_used)
		var amulet := get_node_or_null("AmuletPickable")
		if amulet:
			amulet.picked_up.connect(func(_id): _on_amulet_picked_up())

	var poem := get_node_or_null("RitualPoem")
	if poem:
		poem.examined.connect(func(): DialogueManager.start_dialogue("notes/poem_ritual"))

	var note1 := get_node_or_null("NoteAiyyna1")
	if note1:
		note1.examined.connect(func(): DialogueManager.start_dialogue("notes/note_aiyyna_1"))

func _all_artifacts_collected() -> bool:
	for id in ["amulet", "doll", "earring"]:
		if not GameManager.artifacts_collected.has(id):
			return false
	return true

func _apply_loop_visuals() -> void:
	var ls := GameManager.loop_state
	var fallen := get_node_or_null("LoopFallenPicture")
	if fallen:
		fallen.visible = ls >= 1
	var wall_text := get_node_or_null("LoopWallText")
	if wall_text:
		wall_text.visible = ls >= 2

func _on_kamylok_examined() -> void:
	match kamylok_state:
		KamylokState.COLD:
			if Inventory.has_item("firewood"):
				Inventory.remove_item("firewood")
				kamylok_state = KamylokState.BURNING
				_fire_lit()
			else:
				DialogueManager.show_text("", "Камелёк потух. Угли холодные. Нужно чем-то разжечь.")
		KamylokState.BURNING:
			DialogueManager.show_text("", "Огонь горит ровно. Среди углей что-то поблёскивает.")
		KamylokState.RITUAL_READY:
			kamylok_state = KamylokState.RITUAL_ACTIVE
			DialogueManager.show_text("", "Пламя вспыхивает ярче. Три дара при тебе.\nВыбери предмет в инвентаре (I), потом подойди к огню снова — в нужном порядке.")
		KamylokState.RITUAL_ACTIVE:
			_place_ritual_artifact()

func _fire_lit() -> void:
	DialogueManager.show_text("", "Ты бросаешь дрова. Огонь занимается медленно, потом ярко — камелёк снова живёт.")
	await DialogueManager.dialogue_finished
	var key := get_node_or_null("KeyPickable")
	if key:
		key.visible = true
		key.set_deferred("monitoring", true)
	DialogueManager.show_text("", "Среди углей что-то поблёскивает. Можно достать.")

func _on_chest_used() -> void:
	var amulet := get_node_or_null("AmuletPickable")
	if amulet:
		amulet.visible = true
		amulet.set_deferred("monitoring", true)

func _on_amulet_picked_up() -> void:
	GameManager.collect_artifact("amulet")
	_trigger_flashback("notes/artifact_amulet")

func _place_ritual_artifact() -> void:
	var selected := Inventory.selected_item
	if selected.is_empty() or not CORRECT_ORDER.has(selected):
		DialogueManager.show_text("", "Открой инвентарь (I), выбери один из трёх даров, затем подойди к камельку.")
		return
	if ritual_items.has(selected):
		DialogueManager.show_text("", "Этот дар уже в огне.")
		return

	ritual_items.append(selected)
	Inventory.remove_item(selected)
	var count := ritual_items.size()
	DialogueManager.show_text("", "Ты кладёшь %s в огонь. (%d из 3)" % [ARTIFACT_NAMES.get(selected, selected), count])
	await DialogueManager.dialogue_finished

	if count >= 3:
		_complete_ritual()

func _complete_ritual() -> void:
	if ritual_items == CORRECT_ORDER:
		DialogueManager.show_text("", "Пламя вспыхивает белым. Стены перестают дрожать. Что-то освобождается.")
		await DialogueManager.dialogue_finished
		GameManager.start_finale("good")
	else:
		DialogueManager.show_text("", "Огонь гаснет. Тишина становится абсолютной.")
		await DialogueManager.dialogue_finished
		GameManager.start_finale("bad")

func _trigger_flashback(dialogue_key: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	if fl:
		fl.scripted_off()
	var bg := $Background as ColorRect
	var original_color := bg.color
	var tween := create_tween()
	tween.tween_property(bg, "color", Color(0.24, 0.17, 0.1), 1.0)
	await tween.finished
	await get_tree().create_timer(2.0).timeout
	DialogueManager.start_dialogue(dialogue_key)
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", original_color, 1.0)
	await tween.finished
	if fl:
		fl.scripted_on()
