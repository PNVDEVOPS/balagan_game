extends Node2D

enum KamylokState { COLD, BURNING, RITUAL_READY, RITUAL_ACTIVE }

var kamylok_state: KamylokState = KamylokState.COLD
var ritual_items: Array[String] = []
var _idle_subtitle_timer: float = 0.0
var _idle_subtitle_shown: bool = false
static var _back_trigger_count: int = 0
const CORRECT_ORDER: Array[String] = ["amulet", "doll", "earring"]
const ARTIFACT_NAMES: Dictionary = {
	"amulet": "харысхал",
	"doll": "куклу",
	"earring": "серёжку"
}
const HARYSHAL_TEX := "res://assets/ui/haryshal.png"
const QUEST_MUSIC := "res://assets/audio/Quest.mp3"        # тема главного зала
const SADNESS_MUSIC := "res://assets/audio/SadnessSorrow.mp3"  # при появлении Кыдааны
# Визуалы камелька: спрайт «4» — затухший (поленья), спрайт «3» — горящий.
const HEARTH_COLD_NODE := "4"
const HEARTH_LIT_NODE  := "3"

func _ready() -> void:
	_apply_loop_visuals()
	_setup_puzzle()
	_set_hearth_lit(GameManager.kamylok_lit)   # сначала затухший, после — горящий
	_add_back_zone()
	call_deferred("_refresh_lighting")

	# Тема главного зала (поверх эмбиента усадьбы). Гаснет при выходе из зала.
	if ResourceLoader.exists(QUEST_MUSIC):
		AudioManager.play_music(load(QUEST_MUSIC), 1.5)

	if _all_artifacts_collected():
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Зачем ты здесь?.", SubtitleManager.Pos.TOP_CENTER)

	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(func(body: Node2D):
			if not body.is_in_group("player"):
				return
			if not GameManager.artifacts_collected.has("amulet"):
				SubtitleManager.show_subtitle("Что-то не отпускает меня.", SubtitleManager.Pos.MID_LEFT)
				return
			AudioManager.stop_music(1.0)   # тема зала смолкает за порогом
			GameManager.change_room("door_right")
		)

func _setup_puzzle() -> void:
	var amulet_done := GameManager.artifacts_collected.has("amulet")

	if amulet_done:
		var amulet_node := get_node_or_null("AmuletPickable")
		if amulet_node:
			amulet_node.queue_free()
		kamylok_state = KamylokState.BURNING
		GameManager.puzzle_unblock_solved = true
	else:
		var amulet_node := get_node_or_null("AmuletPickable")
		if amulet_node:
			amulet_node.visible = false
			# Отключаем monitorable — иначе RayCast2D игрока находит амулет даже скрытым
			amulet_node.set_deferred("monitorable", false)
			amulet_node.picked_up.connect(func(_id): _on_amulet_picked_up())

	if _all_artifacts_collected():
		kamylok_state = KamylokState.RITUAL_READY

	var kamylok := get_node_or_null("Kamyolk")
	if kamylok:
		kamylok.examined.connect(_on_kamylok_examined)

	var riddle := get_node_or_null("RiddleKamyolk")
	if riddle:
		riddle.examined.connect(func():
			GameManager.mark_note_found("riddle_kamyolk")
			DialogueManager.start_dialogue("notes/riddle_kamyolk")
		)

	var poem := get_node_or_null("RitualPoem")
	if poem:
		poem.examined.connect(func():
			GameManager.mark_note_found("poem_ritual")
			DialogueManager.start_dialogue("notes/poem_ritual")
		)

	for note_data: Array in [
			["NoteEnv5", "notes/note_env_5", "note_env_5"],
			["NoteMother4", "notes/note_mother_4", "note_mother_4"]]:
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
	if kamylok_state == KamylokState.COLD:
		if not GameManager.puzzle_unblock_solved:
			DialogueManager.show_text("", "В золе под завалом что-то есть. Надо разобрать.")
			await DialogueManager.dialogue_finished
			_open_puzzle()
			return
		DialogueManager.show_text("", "Камелёк ждёт.")
		return
	if kamylok_state == KamylokState.BURNING:
		DialogueManager.show_text("", "Огонь горит. Тепло наконец.")
		return
	if kamylok_state == KamylokState.RITUAL_READY:
		DialogueManager.show_text("", "Пламя стало другим — тихое, почти прозрачное. Ждёт даров.")
		await DialogueManager.dialogue_finished
		kamylok_state = KamylokState.RITUAL_ACTIVE
		DialogueManager.show_text("", "Пламя ждёт.")

func _open_puzzle() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("freeze"):
		player.freeze()
	var puzzle := KlotskiPuzzle.new()
	add_child(puzzle)
	puzzle.puzzle_solved.connect(_on_puzzle_solved)
	puzzle.puzzle_closed.connect(func():
		var p := get_tree().get_first_node_in_group("player")
		if p and p.has_method("unfreeze"):
			p.unfreeze()
	)

func _on_puzzle_solved(_moves: int) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("unfreeze"):
		player.unfreeze()
	GameManager.puzzle_unblock_solved = true
	var amulet_node := get_node_or_null("AmuletPickable")
	if amulet_node:
		amulet_node.queue_free()
	# 1) подбор артефакта (харысхал)
	DialogueManager.show_text("", "В шкатулке что-то лежит.")
	await DialogueManager.dialogue_finished
	GameManager.collect_artifact("amulet")
	# Попап о получении харысхала (картинка-амулет)
	var hary_tex: Texture2D = load(HARYSHAL_TEX) if ResourceLoader.exists(HARYSHAL_TEX) else null
	ItemPopup.show_item("Харысхал", "Подвесной амулет, тёплая на ощупь — будто жила в огне все эти годы.", hary_tex)
	await get_tree().create_timer(3.0).timeout   # дать рассмотреть попап
	# 2) огонь зажигается (затухший камелёк → горящий)
	await _ignite_kamyolk()
	# 3) появляется Кыдаана + конец демо
	await _demo_amulet_sequence()

func _fire_lit() -> void:
	DialogueManager.show_text("", "Огонь занимается медленно, потом вспыхивает, освещая зал.")
	await DialogueManager.dialogue_finished
	await get_tree().create_timer(2.0).timeout

# Переключает визуал камелька: затухший (поленья) ↔ горящий.
# Горящий ставим ровно на место затухшего — огонь зажигается в том же очаге (без сдвига).
func _set_hearth_lit(lit: bool) -> void:
	var cold := get_node_or_null(HEARTH_COLD_NODE)
	var hot := get_node_or_null(HEARTH_LIT_NODE)
	if cold and hot:
		hot.position = cold.position
	if cold:
		cold.visible = not lit
	if hot:
		hot.visible = lit

# Камелёк вспыхивает после подбора харысхала — освещает зал, лампа больше не нужна
func _ignite_kamyolk() -> void:
	GameManager.kamylok_lit = true
	_set_hearth_lit(true)                       # затухший камелёк → горящий
	if Inventory.has_item("oil_lamp"):
		Inventory.remove_item("oil_lamp")
	DialogueManager.show_text("", "Камелёк вспыхивает сам — пламя встаёт высоко, тепло и свет заполняют зал.")
	var mod := get_tree().current_scene.get_node_or_null("RoomModulate")
	if mod:
		var tween := create_tween()
		tween.tween_property(mod, "color", Color(1, 1, 1), 1.2)
	await DialogueManager.dialogue_finished

# При входе в уже освещённый зал — сразу полный свет
func _refresh_lighting() -> void:
	if not GameManager.kamylok_lit:
		return
	# Ждём, пока переход создаст RoomModulate и затемнит зал, потом осветляем
	await get_tree().create_timer(0.2).timeout
	var mod := get_tree().current_scene.get_node_or_null("RoomModulate")
	if mod:
		(mod as CanvasModulate).color = Color(1, 1, 1)

func _on_amulet_picked_up() -> void:
	GameManager.collect_artifact("amulet")
	DialogueManager.show_text("", "Харысхал. Подвесной амулет, тёплая на ощупь — будто жила в огне все эти годы.")
	await DialogueManager.dialogue_finished
	await _demo_amulet_sequence()

func _demo_amulet_sequence() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("freeze"):
		player.freeze()

	# Скорбная тема при появлении Кыдааны (перекрывает тему зала)
	if ResourceLoader.exists(SADNESS_MUSIC):
		AudioManager.play_music(load(SADNESS_MUSIC), 1.5)

	# Атмосфера как в тёмных комнатах: зум, плёночный шум, виньетка
	_kydaana_atmosphere(player)

	# Кыдаана возникает справа от персонажа — проигрываем анимацию появления
	var ky := _spawn_kydaana(player)
	var tw_in := create_tween()
	tw_in.tween_property(ky, "modulate:a", 1.0, 0.4)
	ky.play("appear")
	if ky.sprite_frames and ky.sprite_frames.get_frame_count("appear") > 0:
		await ky.animation_finished
	else:
		await get_tree().create_timer(1.2).timeout
	ky.play("idle")

	# Небольшая задержка после отрисовки появления — потом реплика
	await get_tree().create_timer(0.7).timeout

	# Диалог Кыдааны (текст в chapter2_balagan.json → kydaana_demo_end)
	DialogueManager.start_dialogue("chapter2_balagan/kydaana_demo_end")
	await DialogueManager.dialogue_finished

	# Кыдаана растворяется
	var tw_out := create_tween()
	tw_out.tween_property(ky, "modulate:a", 0.0, 1.5)
	await tw_out.finished
	ky.queue_free()

	# Карточка «Конец демоверсии»
	await _show_demo_end_card()

# Строит кадры Кыдааны из PNG: appear (одноразово) → idle (цикл)
func _build_kydaana_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("appear")
	sf.set_animation_loop("appear", false)
	sf.set_animation_speed("appear", 9.0)
	for i in range(1, 12):
		var ap := "res://assets/sprites/kydaana/appear/%d.png" % i
		if ResourceLoader.exists(ap):
			sf.add_frame("appear", load(ap))
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 2.0)
	for i in range(1, 3):
		var ip := "res://assets/sprites/kydaana/idle/%d.png" % i
		if ResourceLoader.exists(ip):
			sf.add_frame("idle", load(ip))
	return sf

func _spawn_kydaana(player: Node) -> AnimatedSprite2D:
	var ky := AnimatedSprite2D.new()
	ky.sprite_frames = _build_kydaana_frames()
	ky.z_index = 40
	ky.centered = true
	# Кадр 1000x1253; масштаб 0.18 → ~180x225. Ставим справа, ступни у пола (y≈262).
	# Кадр 1000x1253. Масштаб подобран так, чтобы рост был вровень с игроком (~72px).
	const KY_SCALE := 0.13
	const FLOOR_Y := 262.0
	var px: float = player.global_position.x if player else 806.0
	ky.scale = Vector2(KY_SCALE, KY_SCALE)
	ky.modulate = Color(1, 1, 1, 0)
	add_child(ky)
	# Ставим справа от игрока, ступни у пола.
	ky.global_position = Vector2(px + 130.0, FLOOR_Y - (1253.0 * KY_SCALE) * 0.5)
	return ky

# Зум камеры + усиление виньетки и плёночного шума (как в room_corridor_dark)
func _kydaana_atmosphere(player: Node) -> void:
	var cam: Camera2D = player.get_node_or_null("Camera2D") if player else null
	if cam:
		var tw := create_tween()
		tw.tween_property(cam, "zoom", Vector2(1.12, 1.12), 1.2)
	var hud := get_node_or_null("HUD")
	if not hud:
		return
	var v := hud.get_node_or_null("Vignette")
	if v and v.material is ShaderMaterial:
		var vm: ShaderMaterial = v.material.duplicate()
		v.material = vm
		var tw2 := create_tween()
		tw2.tween_method(func(s: float): vm.set_shader_parameter("strength", s), 0.38, 0.85, 1.2)
	var g := hud.get_node_or_null("Grain")
	if g and g.material is ShaderMaterial:
		var gm: ShaderMaterial = g.material.duplicate()
		g.material = gm
		var tw3 := create_tween()
		tw3.tween_method(func(s: float): gm.set_shader_parameter("strength", s), 0.06, 0.16, 1.2)

func _show_demo_end_card() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	get_tree().current_scene.add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var tw_fade := create_tween()
	tw_fade.tween_property(bg, "color:a", 1.0, 1.5)
	await tw_fade.finished

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "КОНЕЦ ДЕМОВЕРСИИ"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.85, 0.75, 0.55, 0.0)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Спасибо за игру."
	sub.add_theme_font_size_override("font_size", 14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(0.6, 0.55, 0.45, 0.0)
	vbox.add_child(sub)

	var tw_text := create_tween()
	tw_text.tween_property(title, "modulate:a", 1.0, 1.0)
	tw_text.parallel().tween_property(sub, "modulate:a", 1.0, 1.0)
	await tw_text.finished

	await get_tree().create_timer(4.0).timeout
	# Глушим игровую музыку/эмбиент и просим меню открыться без музыки.
	AudioManager.stop_music(0.6)
	AudioManager.stop_ambient(0.6)
	GameManager.suppress_menu_music = true
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

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

func _add_back_zone() -> void:
	var area := Area2D.new()
	area.name = "BackZone"
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 400)
	shape.position = Vector2(0, 180)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_back_zone)

func _on_back_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_back_trigger_count += 1
	DialogueManager.show_text("", _get_loop_text(_back_trigger_count))
	await DialogueManager.dialogue_finished
	AudioManager.stop_music(1.0)
	GameManager.change_room("door_exit")

func _get_loop_text(count: int) -> String:
	match count:
		1: return "Снова здесь. Что-то не пускает."
		2: return "Та же дверь. Тот же коридор."
		_: return "Я хожу по кругу."

func _process(delta: float) -> void:
	if _idle_subtitle_shown:
		return
	_idle_subtitle_timer += delta
	if _idle_subtitle_timer >= 10.0:
		_idle_subtitle_shown = true
		SubtitleManager.show_subtitle("Холодно.", SubtitleManager.Pos.MID_RIGHT)
