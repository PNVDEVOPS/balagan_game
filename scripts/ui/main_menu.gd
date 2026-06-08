extends Control

const MENU_MUSIC := "res://assets/audio/menu_theme.mp3"
const MUSIC_VOLUME_DB := -12.0     # ← ГРОМКОСТЬ музыки меню (тише = более отрицательное число)
const MUSIC_FADE_IN   := 2      # плавное появление при входе в меню, сек
const MUSIC_FADE_OUT  := 0.9      # плавное затухание при выходе из меню, сек
const MUSIC_SILENT_DB := -60.0    # уровень «тишины» для фейдов

var _music: AudioStreamPlayer

func _ready() -> void:
	$Buttons/ContinueBtn.disabled = not SaveManager.has_save()
	_update_note_counter()
	$Buttons/NewGameBtn.pressed.connect(_on_new_game_pressed)
	$Buttons/ContinueBtn.pressed.connect(_on_continue_pressed)
	$Buttons/SettingsBtn.pressed.connect(_on_settings_pressed)
	$Buttons/QuitBtn.pressed.connect(_on_quit_pressed)
	$Buttons/NewGameBtn.grab_focus()
	_start_menu_music()

# Зацикленная музыка меню с плавным появлением. Узел — ребёнок меню.
func _start_menu_music() -> void:
	if not ResourceLoader.exists(MENU_MUSIC):
		return
	var stream: AudioStream = load(MENU_MUSIC)
	if stream is AudioStreamMP3:
		stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.bus = "Master"
	_music.volume_db = MUSIC_SILENT_DB        # стартуем с тишины и плавно поднимаем
	add_child(_music)
	_music.play()
	# Надёжный луп: повторяем по сигналу finished (не полагаясь на stream.loop).
	_music.finished.connect(_music.play)
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE_IN)

# Плавно гасит музыку перед сменой сцены и ждёт окончания фейда.
func _fade_out_music() -> void:
	if not _music or not _music.playing:
		return
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", MUSIC_SILENT_DB, MUSIC_FADE_OUT)
	await tw.finished

func _update_note_counter() -> void:
	var label := get_node_or_null("NoteCounterLabel")
	if label:
		var count: int = GameManager.notes_found.size()
		label.text = "Записки: %d / %d" % [count, GameManager.TOTAL_NOTES]

func _on_new_game_pressed() -> void:
	_disable_buttons()
	await _fade_out_music()
	SaveManager.delete_save()
	GameManager.artifacts_collected.clear()
	GameManager.notes_found.clear()
	GameManager.loop_state = 0
	GameManager.escape_attempts = 0
	GameManager.ritual_result = ""
	GameManager.puzzle_unblock_solved = false
	GameManager.lamp_needed = false
	GameManager.kamylok_lit = false
	Inventory.items.clear()
	Inventory.selected_item = ""
	GameManager.transition_count = 0
	GameManager._load_room_graph()
	ChapterManager.current_chapter = ChapterManager.Chapter.ROAD
	ChapterManager.start_chapter(ChapterManager.Chapter.ROAD)

func _on_continue_pressed() -> void:
	_disable_buttons()
	if SaveManager.load_game():
		var scene_path := GameManager.get_room_scene(GameManager.current_room)
		if scene_path.is_empty():
			scene_path = "res://scenes/rooms/room_main_hall.tscn"
		await _fade_out_music()
		get_tree().change_scene_to_file(scene_path)
	else:
		_enable_buttons()

func _on_settings_pressed() -> void:
	await _fade_out_music()
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")

func _on_quit_pressed() -> void:
	await _fade_out_music()
	get_tree().quit()

func _disable_buttons() -> void:
	for btn in $Buttons.get_children():
		btn.disabled = true

func _enable_buttons() -> void:
	$Buttons/NewGameBtn.disabled = false
	$Buttons/ContinueBtn.disabled = not SaveManager.has_save()
	$Buttons/SettingsBtn.disabled = false
	$Buttons/QuitBtn.disabled = false
