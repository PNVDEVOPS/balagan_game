extends Node2D

enum KamylokState { COLD, BURNING, RITUAL_READY, RITUAL_ACTIVE }

var _wake_up_shown: bool = false

var kamylok_state: KamylokState = KamylokState.COLD
var ritual_items: Array[String] = []
var _idle_subtitle_timer: float = 0.0
var _idle_subtitle_shown: bool = false
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

	if _all_artifacts_collected():
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Ты дошёл.", SubtitleManager.Pos.TOP_CENTER)

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

	# Кыдаана note 1 — with fallback for old scene node name
	var note1 := get_node_or_null("NoteKydaana1")
	if not note1:
		note1 = get_node_or_null("NoteAiyyna1")
	if note1:
		note1.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_kydaana_1")
			GameManager.mark_note_found("note_kydaana_1")
		)

	# Env notes
	for note_data: Array in [
			["NoteEnv1", "notes/note_env_1", "note_env_1"],
			["NoteEnv4", "notes/note_env_4", "note_env_4"],
			["NoteEnv5", "notes/note_env_5", "note_env_5"]]:
		var note := get_node_or_null(note_data[0])
		var key: String = note_data[1]
		var note_id: String = note_data[2]
		if note:
			note.examined.connect(func():
				DialogueManager.start_dialogue(key)
				GameManager.mark_note_found(note_id)
			)

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
	if kamylok_state == KamylokState.RITUAL_ACTIVE:
		_place_ritual_artifact()
		return
	match kamylok_state:
		KamylokState.COLD:
			DialogueManager.show_text("", "Железная печь с чугунным поддувалом. Угли холодные — давно не топили.\n\nВнешняя сторона кована якутским узором. Тонкая работа, старая.")
		KamylokState.BURNING:
			DialogueManager.show_text("", "Огонь горит ровно, жарко. Среди угля — что-то поблёскивает.")
		KamylokState.RITUAL_READY:
			DialogueManager.show_text("", "Пламя стало другим — тихое, почти прозрачное. Ждёт даров.")
	await DialogueManager.dialogue_finished
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
			DialogueManager.show_text("", "Пламя ждёт.")

func _fire_lit() -> void:
	DialogueManager.show_text("", "Ты бросаешь дрова. Огонь занимается медленно, потом ярко — камелёк снова живёт.")
	await DialogueManager.dialogue_finished
	var key := get_node_or_null("KeyPickable")
	if key:
		key.visible = true
		key.set_deferred("monitoring", true)
	DialogueManager.show_text("", "Среди углей что-то поблёскивает. Можно достать.")

func _on_chest_used() -> void:
	DialogueManager.show_text("", "Внутри — что-то завёрнуто в старую кожу. Тяжёлое. Тёплое на ощупь.\n\nПтичьи кости на нити. Старый. Очень старый.")
	await DialogueManager.dialogue_finished
	var amulet := get_node_or_null("AmuletPickable")
	if amulet:
		amulet.visible = true
		amulet.set_deferred("monitoring", true)

func _on_amulet_picked_up() -> void:
	GameManager.collect_artifact("amulet")
	await _trigger_flashback("notes/artifact_amulet")
	_show_kydaana_silhouette()

func _show_kydaana_silhouette() -> void:
	var silhouette := Sprite2D.new()
	var tex_path := "res://assets/sprites/spirit_placeholder.png"
	if ResourceLoader.exists(tex_path):
		silhouette.texture = load(tex_path)
	silhouette.modulate = Color(0.05, 0.02, 0.1, 0.0)
	silhouette.position = Vector2(520, 260)
	silhouette.scale = Vector2(1.2, 1.5)
	add_child(silhouette)

	var tw := create_tween()
	tw.tween_property(silhouette, "modulate:a", 0.8, 1.5)
	tw.tween_interval(3.5)
	tw.tween_property(silhouette, "modulate:a", 0.0, 1.5)
	await tw.finished
	silhouette.queue_free()

	SubtitleManager.show_subtitle("Ты видел меня.", SubtitleManager.Pos.TOP_RIGHT)

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
		var bg := get_node_or_null("Background") as ColorRect
		if bg:
			var tween := create_tween()
			tween.tween_property(bg, "color", Color(1.0, 0.95, 0.8), 0.8)
			await tween.finished
		DialogueManager.show_text("", "Пламя вспыхивает белым. Стены перестают дрожать. Что-то освобождается.")
		await DialogueManager.dialogue_finished
		SubtitleManager.show_subtitle("Я не думала что кто-то придёт.", SubtitleManager.Pos.BOTTOM_CENTER)
		await get_tree().create_timer(4.0).timeout
		GameManager.start_finale("good")
	else:
		DialogueManager.show_text("", "Огонь гаснет. Тишина становится абсолютной.")
		await DialogueManager.dialogue_finished
		GameManager.start_finale("bad")

func _process(delta: float) -> void:
	if _idle_subtitle_shown:
		return
	_idle_subtitle_timer += delta
	if _idle_subtitle_timer >= 10.0:
		_idle_subtitle_shown = true
		SubtitleManager.show_subtitle("Зачем ты здесь стоишь?", SubtitleManager.Pos.MID_RIGHT)

func _trigger_flashback(dialogue_key: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	if fl:
		fl.scripted_off()
	var bg := get_node_or_null("Background") as ColorRect
	var original_color := bg.color if bg else Color.BLACK
	if bg:
		var tween := create_tween()
		tween.tween_property(bg, "color", Color(0.24, 0.17, 0.1), 1.0)
		await tween.finished
	await get_tree().create_timer(2.0).timeout
	DialogueManager.start_dialogue(dialogue_key)
	await DialogueManager.dialogue_finished
	if bg:
		var tween := create_tween()
		tween.tween_property(bg, "color", original_color, 1.0)
		await tween.finished
	if fl:
		fl.scripted_on()
